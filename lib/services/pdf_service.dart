import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/estimation.dart';
import '../models/vendeur_note.dart';
import 'georisques_service.dart';

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
        _prestationsSection(e),
        pw.SizedBox(height: 20),
        _estimationSection(e, price),
        if (e.risques != null && e.risques!.hasData) ...[
          pw.SizedBox(height: 20),
          _risquesSection(e.risques!),
        ],
        if (e.conclusion.isNotEmpty) ...[
          pw.SizedBox(height: 20),
          _conclusionSection(e),
        ],
        if (e.photosPaths.isNotEmpty) ...[
          pw.SizedBox(height: 20),
          _photosSection(e),
        ],
        if (e.notesVendeur != null) ...[
          pw.SizedBox(height: 20),
          _notesVendeurSection(e.notesVendeur!),
        ],
      ],
    ));

    // Stockage dans le cache (couvert par cache-path du FileProvider)
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${e.reference}.pdf');
    await file.writeAsBytes(await doc.save());

    debugPrint('[PdfService] PDF généré : ${file.path}');
    debugPrint('[PdfService] Fichier existe : ${file.existsSync()} — taille : ${file.lengthSync()} octets');

    final result = await OpenFile.open(file.path);
    if (result.type != ResultType.done) {
      debugPrint('[PdfService] Erreur ouverture : ${result.message}');
    }

    return file;
  }

  Future<void> sendByEmail(Estimation e) async {
    final price = e.prixFinal > 0 ? e.prixFinal : e.prixCalcule;
    final priceStr = '${price.round().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')} €';
    final subject = Uri.encodeComponent('Estimation ${e.reference} — $priceStr');
    final body = Uri.encodeComponent(
      'Bonjour,\n\nVeuillez trouver ci-joint le rapport d\'estimation pour le bien référencé ${e.reference}.\n\nValeur estimée : $priceStr\n\nCordialement,\nJérémy Moraga\nFaucigny Immobilier by Efficity',
    );
    final uri = Uri.parse('mailto:?subject=$subject&body=$body');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
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
        _row('DPE', e.dpeClasse == 'NC' ? 'Non communiqué ⚠️' : 'Classe ${e.dpeClasse}'),
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

  pw.Widget _prestationsSection(Estimation e) {
    String stars(int n) => '${'★' * n}${'☆' * (4 - n)}';
    fmt(double v) => '${v.round().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')} €';
    final coeff = e.coefficientPrestations;
    final impact = e.prixM2Retenu * e.surfaceHabitable - e.prixMoyen * e.surfaceHabitable;

    return _card('QUALITÉ DES PRESTATIONS', [
      _row('Cuisine',              '${stars(e.noteCuisine)} (${e.noteCuisine}/4)'),
      _row('Sol',                  '${stars(e.noteSol)} (${e.noteSol}/4)'),
      _row('Salle de bain / Eau',  '${stars(e.noteSdb)} (${e.noteSdb}/4)'),
      _row('Fenêtres / Menuiseries','${stars(e.noteFenetres)} (${e.noteFenetres}/4)'),
      _row('Chauffage',            '${stars(e.noteChauffage)} (${e.noteChauffage}/4)'),
      _row('État général',         '${stars(e.noteEtatPrestation)} (${e.noteEtatPrestation}/4)'),
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 6),
        child: pw.Container(height: 0.5, color: PdfColors.grey300),
      ),
      _row('Score pondéré', '${e.scorePrestations.toStringAsFixed(1)}/4', bold: true),
      _row('Ajustement', '${coeff >= 0 ? '+' : ''}${coeff.toInt()}% — ${e.labelCoefficientPrestations}'),
      _row('Prix m² médian DVF', '${e.prixMoyen.round()} €/m²'),
      _row('Prix m² retenu', '${e.prixM2Retenu.round()} €/m²', bold: true),
      _row('Impact sur la valeur', '${impact >= 0 ? '+' : ''}${fmt(impact)}'),
    ]);
  }

  pw.Widget _estimationSection(Estimation e, double price) {
    final low = e.fourchetteBasse > 0 ? e.fourchetteBasse : price * 0.95;
    final high = e.fourchetteHaute > 0 ? e.fourchetteHaute : price * 1.05;
    fmt(double v) => '${v.round().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')} €';
    return _card('ESTIMATION', [
      _row('Vue dégagée', '${e.ajustVue >= 0 ? '+' : ''}${e.ajustVue.toStringAsFixed(1)}%'),
      _row('État / Rénovation', '${e.ajustEtat >= 0 ? '+' : ''}${e.ajustEtat.toStringAsFixed(1)}%'),
      _row('Performance DPE (${e.dpeClasse})', '${e.ajustDpe >= 0 ? '+' : ''}${e.ajustDpe.toStringAsFixed(1)}%'),
      if (e.ajustExposition != 0)
        _row('Exposition (${e.orientations.join('/')})', '${e.ajustExposition >= 0 ? '+' : ''}${e.ajustExposition.toStringAsFixed(1)}%'),
      if (e.ajustEnvironnement != 0)
        _row('Environnement / Nuisances', '${e.ajustEnvironnement.toStringAsFixed(1)}%'),
      if (e.ajustParking < 0) _row('Sans stationnement', '−${fmt((-e.ajustParking).toDouble())}'),
      if (e.ajustParking > 0) _row('Parking supplémentaire', '+${fmt(e.ajustParking.toDouble())}'),
      if (e.ajustPiscine > 0) _row('Prime piscine', '+${fmt(e.ajustPiscine.toDouble())}'),
      if (e.ajustTravaux > 0) _row('Travaux', '−${fmt(e.ajustTravaux.toDouble())}'),
      _row('Valeur estimée (net vendeur)', fmt(price), bold: true),
      _row('Prix de mandat (+${e.margeNegociation.toInt()}%)', fmt(e.prixMandat), bold: true),
      _row('Fourchette', '${fmt(low)} — ${fmt(high)}'),
      _row('Validité', _fmtDate(e.validiteJusquau)),
    ]);
  }

  pw.Widget _risquesSection(GeorisquesData r) {
    final rows = <pw.Widget>[];

    rows.add(_row(
        'Niveau sismique',
        r.niveauSismique.isEmpty ? '—' : 'Zone ${r.niveauSismique} / 5',
        bold: true));
    rows.add(_row('Potentiel radon',
        r.potentielRadon.isEmpty ? '—' : r.potentielRadon));
    rows.add(_row('Retrait-gonflement argile (RGA)',
        r.niveauArgile.isEmpty ? '—' : r.niveauArgile));

    if (r.risquesNaturels.isNotEmpty) {
      rows.add(pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 6),
        child: pw.Container(height: 0.5, color: PdfColors.grey300),
      ));
      rows.add(_row('Risques naturels recensés',
          r.risquesNaturels.map((s) => '• $s').join('\n')));
    }
    if (r.risquesTechnologiques.isNotEmpty) {
      rows.add(_row('Risques technologiques',
          r.risquesTechnologiques.map((s) => '• $s').join('\n')));
    }
    if (r.nbCatnat > 0) {
      rows.add(_row('Arrêtés Cat. Nat. recensés', '${r.nbCatnat}'));
    }

    rows.add(pw.SizedBox(height: 6));
    rows.add(pw.Text(
      'Information transmise au futur acquéreur — obligation IAL (Code de l\'environnement art. L.125-5). Source : Géorisques (officiel).',
      style: const pw.TextStyle(
          fontSize: 8, color: PdfColors.grey600, lineSpacing: 1.3),
    ));

    return _card('RISQUES NATURELS & TECHNOLOGIQUES (IAL)', rows);
  }

  pw.Widget _notesVendeurSection(VendeurNote n) {
    final rows = <pw.Widget>[];
    if (n.motivationVente.isNotEmpty) rows.add(_row('Motivation vente', n.motivationVente));
    if (n.delaiSouhaite.isNotEmpty)   rows.add(_row('Délai souhaité', n.delaiSouhaite));
    if (n.prixSouhaite.isNotEmpty)    rows.add(_row('Prix souhaité', n.prixSouhaite));
    if (n.travauxDeclares.isNotEmpty) rows.add(_row('Travaux déclarés', n.travauxDeclares));
    if (n.situationPersonnelle.isNotEmpty) rows.add(_row('Situation', n.situationPersonnelle));
    if (n.pointsForts.isNotEmpty) {
      rows.add(_row('Points forts', n.pointsForts.map((s) => '• $s').join('\n')));
    }
    if (n.pointsFaibles.isNotEmpty) {
      rows.add(_row('Points faibles', n.pointsFaibles.map((s) => '• $s').join('\n')));
    }
    if (rows.isEmpty && n.transcription.isNotEmpty) {
      rows.add(pw.Padding(
        padding: const pw.EdgeInsets.only(top: 4),
        child: pw.Text(n.transcription,
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
      ));
    }
    if (rows.isEmpty) return pw.SizedBox();
    return _card('NOTES VENDEUR', rows);
  }

  pw.Widget _photosSection(Estimation e) {
    final images = <pw.Widget>[];
    for (final path in e.photosPaths) {
      try {
        final bytes = File(path).readAsBytesSync();
        images.add(pw.Expanded(
          child: pw.Container(
            margin: const pw.EdgeInsets.all(3),
            child: pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.cover, height: 160),
          ),
        ));
      } catch (_) {}
    }
    if (images.isEmpty) return pw.SizedBox();

    final rows = <pw.Widget>[];
    for (var i = 0; i < images.length; i += 2) {
      rows.add(pw.Row(children: [
        images[i],
        if (i + 1 < images.length) images[i + 1] else pw.Expanded(child: pw.SizedBox()),
      ]));
      if (i + 2 < images.length) rows.add(pw.SizedBox(height: 4));
    }
    return _card('PHOTOS DU BIEN', rows);
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
