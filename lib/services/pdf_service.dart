import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/estimation.dart';

class PdfService {
  Future<File> generate(Estimation e) async {
    final doc = pw.Document();
    final price = e.prixFinal > 0 ? e.prixFinal : e.prixCalcule;

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (ctx) => _header(e),
      footer: (ctx) => _footer(ctx),
      build: (ctx) => [
        _titleSection(e, price),
        pw.SizedBox(height: 20),
        _infoSection(e),
        pw.SizedBox(height: 20),
        _descSection(e),
        pw.SizedBox(height: 20),
        _etatSection(e),
        pw.SizedBox(height: 20),
        _marcheSection(e),
        pw.SizedBox(height: 20),
        _estimationSection(e, price),
        if (e.conclusion.isNotEmpty) ...[
          pw.SizedBox(height: 20),
          _conclusionSection(e),
        ],
      ],
    ));

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/${e.reference}.pdf');
    await file.writeAsBytes(await doc.save());

    await Printing.sharePdf(bytes: await doc.save(), filename: '${e.reference}.pdf');
    return file;
  }

  Future<void> sendByEmail(Estimation e) async {
    final price = e.prixFinal > 0 ? e.prixFinal : e.prixCalcule;
    final priceStr = '${price.round().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')} €';
    final subject = Uri.encodeComponent('Estimation ${e.reference} — ${priceStr}');
    final body = Uri.encodeComponent(
      'Bonjour,\n\nVeuillez trouver ci-joint le rapport d\'estimation pour le bien référencé ${e.reference}.\n\nValeur estimée : $priceStr\n\nCordialement,\nJérémy Moraga\nFaucigny Immobilier by Efficity',
    );
    final uri = Uri.parse('mailto:?subject=$subject&body=$body');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  pw.Widget _header(Estimation e) => pw.Column(children: [
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('FAUCIGNY IMMOBILIER', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
            pw.Text('by Efficity', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
          ]),
          pw.Text('RAPPORT D\'ESTIMATION', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700, letterSpacing: 1.0)),
        ]),
        pw.SizedBox(height: 8),
        pw.Container(height: 2, color: const PdfColor.fromInt(0xFFC9A84C)),
        pw.SizedBox(height: 8),
      ]);

  pw.Widget _footer(pw.Context ctx) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text('Jérémy Moraga — Faucigny Immobilier by Efficity', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
        pw.Text('Page ${ctx.pageNumber} / ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
      ]);

  pw.Widget _titleSection(Estimation e, double price) {
    final priceStr = '${price.round().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')} €';
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(color: const PdfColor.fromInt(0xFF7CB342), borderRadius: pw.BorderRadius.circular(8)),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text('Réf. ${e.reference}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.white)),
        pw.SizedBox(height: 4),
        pw.Text(priceStr, style: pw.TextStyle(fontSize: 32, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
        pw.SizedBox(height: 4),
        pw.Text('${e.prixMoyen.round()} €/m² · ${e.surfaceHabitable} m²', style: const pw.TextStyle(fontSize: 11, color: PdfColors.white)),
      ]),
    );
  }

  pw.Widget _infoSection(Estimation e) => _card('INFORMATIONS GÉNÉRALES', [
        _row('Type', '${e.typeId[0].toUpperCase()}${e.typeId.substring(1)}'),
        _row('Motif', e.motif),
        _row('Propriétaire', e.proprietaireNom),
        _row('Téléphone', e.proprietaireTel),
        _row('Email', e.proprietaireEmail),
        _row('Date de visite', _fmtDate(e.dateVisite)),
      ]);

  pw.Widget _descSection(Estimation e) => _card('DESCRIPTION DU BIEN', [
        _row('Surface habitable', '${e.surfaceHabitable} m²'),
        _row('Surface terrain', '${e.surfaceTerrain} m²'),
        _row('Pièces', '${e.pieces}'),
        _row('Chambres', '${e.chambres}'),
        _row('Année construction', e.anneeConstruction),
        _row('État général', ['À rénover','Travaux','Bon état','Très bon','Neuf'][e.etatGeneral.clamp(0, 4)]),
        _row('Orientation', e.orientations.join(', ')),
        _row('Vue', e.vues.join(', ')),
        _row('DPE', 'Classe ${e.dpeClasse}'),
        _row('Chauffage', e.chauffageType),
      ]);

  pw.Widget _etatSection(Estimation e) => _card('ÉTAT & ÉQUIPEMENTS', [
        _row('Façade', e.facade),
        _row('Toiture', e.toiture),
        _row('Menuiseries', e.menuiseriesType.join(', ')),
        _row('Vitrage', e.vitrage.join(', ')),
        _row('Chauffage', '${e.chauffageType} · ${e.chauffageEtat} · ${e.anneeChaudiere}'),
        _row('Électricité', e.electricite),
        _row('Isolation', e.isolation),
      ]);

  pw.Widget _marcheSection(Estimation e) => _card('ANALYSE DU MARCHÉ DVF', [
        _row('Prix médian', '${e.prixMoyen.round()} €/m²'),
        _row('Comparables', '${e.comparables.length} ventes'),
        ...e.comparables.map((c) => _row('  • ${c['addr'] ?? ''}', '${(c['prixM2'] as num?)?.round()} €/m²')),
      ]);

  pw.Widget _estimationSection(Estimation e, double price) {
    final low = e.fourchetteBasse > 0 ? e.fourchetteBasse : price * 0.95;
    final high = e.fourchetteHaute > 0 ? e.fourchetteHaute : price * 1.05;
    fmt(double v) => '${v.round().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')} €';
    return _card('ESTIMATION', [
      _row('Vue dégagée', '${e.ajustVue >= 0 ? '+' : ''}${e.ajustVue.toStringAsFixed(1)}%'),
      _row('État / Rénovation', '${e.ajustEtat >= 0 ? '+' : ''}${e.ajustEtat.toStringAsFixed(1)}%'),
      _row('Performance DPE', '${e.ajustDpe >= 0 ? '+' : ''}${e.ajustDpe.toStringAsFixed(1)}%'),
      if (e.ajustTravaux > 0) _row('Travaux', '−${fmt(e.ajustTravaux.toDouble())}'),
      _row('Valeur estimée', fmt(price), bold: true),
      _row('Fourchette', '${fmt(low)} — ${fmt(high)}'),
      _row('Validité', _fmtDate(e.validiteJusquau)),
    ]);
  }

  pw.Widget _conclusionSection(Estimation e) => _card('CONCLUSION', [
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 4),
          child: pw.Text(e.conclusion, style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey800)),
        ),
      ]);

  pw.Widget _card(String title, List<pw.Widget> rows) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF7CB342), letterSpacing: 0.5)),
          pw.SizedBox(height: 6),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: pw.BorderRadius.circular(6)),
            child: pw.Column(children: rows),
          ),
        ],
      );

  pw.Widget _row(String label, String value, {bool bold = false}) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: PdfColors.grey900)),
        ]),
      );

  String _fmtDate(DateTime d) {
    const months = ['janvier','février','mars','avril','mai','juin','juillet','août','septembre','octobre','novembre','décembre'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}
