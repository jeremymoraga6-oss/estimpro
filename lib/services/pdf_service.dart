import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart';
import '../models/estimation.dart';
import '../models/vendeur_note.dart';
import 'georisques_service.dart';
import '../screens/section6_screen.dart' show requiredDocs;

const _kGreen      = PdfColor.fromInt(0xFF4CAF50);
const _kLightGreen = PdfColor.fromInt(0xFFE8F5E9);
const _kCharcoal   = PdfColor.fromInt(0xFF2C3E50);

class PdfService {
  pw.MemoryImage? _logoImage;
  pw.MemoryImage? _agenceImage;

  Future<void> _loadAssets() async {
    try {
      final data = await rootBundle.load('assets/images/logo.png');
      _logoImage = pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {}
    try {
      final data = await rootBundle.load('assets/images/agence.jpg');
      _agenceImage = pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {}
  }

  Future<File> generateFile(Estimation e) async {
    await _loadAssets();
    final doc = pw.Document();
    final price = e.prixFinal > 0 ? e.prixFinal : e.prixCalcule;

    doc.addPage(_buildCoverPage(e, price));
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
        _chargesSection(e),
        pw.SizedBox(height: 20),
        _diagnosticsSection(e),
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
        pw.SizedBox(height: 20),
        _plusValueSection(e),
        pw.SizedBox(height: 20),
        _documentsSection(e),
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

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${e.reference}.pdf');
    await file.writeAsBytes(await doc.save());
    return file;
  }

  Future<File> generate(Estimation e) async {
    await _loadAssets();
    final doc = pw.Document();
    final price = e.prixFinal > 0 ? e.prixFinal : e.prixCalcule;

    doc.addPage(_buildCoverPage(e, price));
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
        _chargesSection(e),
        pw.SizedBox(height: 20),
        _diagnosticsSection(e),
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
        pw.SizedBox(height: 20),
        _plusValueSection(e),
        pw.SizedBox(height: 20),
        _documentsSection(e),
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
    final file = await generate(e);
    final price = e.prixFinal > 0 ? e.prixFinal : e.prixCalcule;
    final priceStr = _fmtPrice(price);
    final subject = 'Estimation ${e.reference} — $priceStr';
    final body = 'Bonjour,\n\nVeuillez trouver ci-joint le rapport d\'estimation pour le bien référencé ${e.reference}.\n\nValeur estimée : $priceStr\nPrix de mandat : ${_fmtPrice(e.prixMandat)}\n\nCordialement,\nJérémy Moraga\nFaucigny Immobilier by Efficity';
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      subject: subject,
      text: body,
    );
  }

  // ── Page de garde ───────────────────────────────────────────────────────────

  pw.Page _buildCoverPage(Estimation e, double price) {
    final low  = e.fourchetteBasse > 0 ? e.fourchetteBasse : price * 0.95;
    final high = e.fourchetteHaute > 0 ? e.fourchetteHaute : price * 1.05;
    final typeLabel = e.typeId.isNotEmpty
        ? '${e.typeId[0].toUpperCase()}${e.typeId.substring(1)}'
        : 'Bien';

    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // ── Bandeau vert supérieur ──────────────────────────────────
          pw.Container(
            color: _kGreen,
            padding: const pw.EdgeInsets.fromLTRB(44, 36, 44, 30),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (_logoImage != null)
                  pw.Container(
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: pw.Image(_logoImage!, height: 55, fit: pw.BoxFit.contain),
                  )
                else ...[
                  pw.Text('FAUCIGNY IMMOBILIER',
                      style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                          letterSpacing: 1.5)),
                  pw.SizedBox(height: 3),
                  pw.Text('by Efficity',
                      style: const pw.TextStyle(fontSize: 12, color: PdfColors.white)),
                ],
                pw.SizedBox(height: 22),
                pw.Container(height: 1, color: PdfColors.white),
                pw.SizedBox(height: 14),
                pw.Text('RAPPORT D\'ESTIMATION',
                    style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                        letterSpacing: 2.5)),
                pw.Text('IMMOBILIERE',
                    style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                        letterSpacing: 2.5)),
              ],
            ),
          ),

          // ── Corps blanc ─────────────────────────────────────────────
          pw.Expanded(
            child: pw.Container(
              color: PdfColors.white,
              padding: const pw.EdgeInsets.fromLTRB(44, 36, 44, 28),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Adresse
                  pw.Text('BIEN ESTIME',
                      style: const pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.grey,
                          letterSpacing: 1.2)),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    e.adresseComplete.isNotEmpty
                        ? e.adresseComplete
                        : 'Adresse non renseignée',
                    style: pw.TextStyle(
                        fontSize: 17,
                        fontWeight: pw.FontWeight.bold,
                        color: _kCharcoal),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    '$typeLabel — ${e.surfaceHabitable} m² — ${e.pieces} pièce${e.pieces > 1 ? 's' : ''}',
                    style: const pw.TextStyle(
                        fontSize: 11, color: PdfColors.grey700),
                  ),
                  pw.SizedBox(height: 28),

                  // Encadré prix
                  pw.Container(
                    padding: const pw.EdgeInsets.all(20),
                    decoration: pw.BoxDecoration(
                      color: _kLightGreen,
                      borderRadius: pw.BorderRadius.circular(8),
                      border: pw.Border.all(color: _kGreen, width: 1.5),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Valeur estimée (net vendeur)',
                            style: const pw.TextStyle(
                                fontSize: 9, color: PdfColors.grey700)),
                        pw.SizedBox(height: 8),
                        pw.Text(_fmtPrice(price),
                            style: pw.TextStyle(
                                fontSize: 34,
                                fontWeight: pw.FontWeight.bold,
                                color: _kGreen)),
                        pw.SizedBox(height: 10),
                        pw.Container(
                            height: 0.5, color: const PdfColor.fromInt(0xFFB2DFDB)),
                        pw.SizedBox(height: 10),
                        pw.Row(children: [
                          pw.Text('Fourchette :  ',
                              style: const pw.TextStyle(
                                  fontSize: 9, color: PdfColors.grey700)),
                          pw.Text(
                              '${_fmtPrice(low)}  —  ${_fmtPrice(high)}',
                              style: pw.TextStyle(
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold,
                                  color: _kCharcoal)),
                        ]),
                        pw.SizedBox(height: 5),
                        pw.Row(children: [
                          pw.Text('Prix de mandat :  ',
                              style: const pw.TextStyle(
                                  fontSize: 9, color: PdfColors.grey700)),
                          pw.Text(_fmtPrice(e.prixMandat),
                              style: pw.TextStyle(
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold,
                                  color: _kCharcoal)),
                        ]),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 24),

                  // Métriques clés
                  pw.Row(children: [
                    _metricBox('${e.prixMoyen.round()} EUR/m2', 'Marché local'),
                    pw.SizedBox(width: 8),
                    _metricBox('${e.surfaceHabitable} m2', 'Surface hab.'),
                    pw.SizedBox(width: 8),
                    _metricBox(
                        e.anneeConstruction.isNotEmpty
                            ? e.anneeConstruction
                            : 'N/A',
                        'Construction'),
                    pw.SizedBox(width: 8),
                    _metricBox('DPE ${e.dpeClasse}', 'Energie'),
                  ]),
                  pw.SizedBox(height: 28),

                  // Référence + dates
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      _refBadge('Ref. ${e.reference}'),
                      _refBadge('Visite : ${_fmtDate(e.dateVisite)}'),
                      _refBadge('Validite : ${_fmtDate(e.validiteJusquau)}'),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Bandeau footer sombre avec photo agence ─────────────────
          pw.SizedBox(
            height: 90,
            child: pw.Container(
              color: _kCharcoal,
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Expanded(
                    child: pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 44, vertical: 18),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        children: [
                          pw.Text('Jeremy Moraga',
                              style: pw.TextStyle(
                                  fontSize: 12,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.white)),
                          pw.SizedBox(height: 3),
                          pw.Text(
                              'Faucigny Immobilier — 06 68 03 64 03',
                              style: const pw.TextStyle(
                                  fontSize: 8, color: PdfColors.grey)),
                          pw.SizedBox(height: 6),
                          pw.Text('Document confidentiel',
                              style: const pw.TextStyle(
                                  fontSize: 7, color: PdfColors.grey)),
                        ],
                      ),
                    ),
                  ),
                  if (_agenceImage != null)
                    pw.SizedBox(
                      width: 200,
                      child: pw.Image(_agenceImage!, fit: pw.BoxFit.cover),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _metricBox(String value, String label) => pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: pw.BoxDecoration(
            color: const PdfColor.fromInt(0xFFF5F5F5),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(value,
                  style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: _kCharcoal)),
              pw.SizedBox(height: 3),
              pw.Text(label,
                  style: const pw.TextStyle(
                      fontSize: 7, color: PdfColors.grey600)),
            ],
          ),
        ),
      );

  pw.Widget _refBadge(String text) => pw.Container(
        padding:
            const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Text(text,
            style:
                const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
      );

  // ── En-tête de chaque page ──────────────────────────────────────────────────

  pw.Widget _header(Estimation e) => pw.Column(children: [
        pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (_logoImage != null)
                pw.SizedBox(
                  height: 26,
                  child: pw.Image(_logoImage!, fit: pw.BoxFit.contain),
                )
              else
                pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('FAUCIGNY IMMOBILIER',
                          style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                              color: _kGreen)),
                      pw.Text('by Efficity',
                          style: const pw.TextStyle(
                              fontSize: 8, color: PdfColors.grey)),
                    ]),
              pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      e.adresseComplete.isNotEmpty
                          ? e.adresseComplete
                          : 'Rapport d\'estimation',
                      style: const pw.TextStyle(
                          fontSize: 8, color: PdfColors.grey700),
                    ),
                    pw.Text('Réf. ${e.reference}',
                        style: const pw.TextStyle(
                            fontSize: 8, color: PdfColors.grey)),
                  ]),
            ]),
        pw.SizedBox(height: 6),
        pw.Container(height: 1.5, color: _kGreen),
        pw.SizedBox(height: 8),
      ]);

  pw.Widget _footer(pw.Context ctx) =>
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text('Jérémy Moraga — Faucigny Immobilier by Efficity',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
        pw.Text('Page ${ctx.pageNumber} / ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
      ]);

  // ── Sections ────────────────────────────────────────────────────────────────

  pw.Widget _titleSection(Estimation e, double price) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
          color: _kGreen, borderRadius: pw.BorderRadius.circular(8)),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('Réf. ${e.reference}',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.white)),
            pw.SizedBox(height: 4),
            pw.Text(_fmtPrice(price),
                style: pw.TextStyle(
                    fontSize: 28,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white)),
            pw.SizedBox(height: 2),
            pw.Text(
                'Net vendeur — mandat : ${_fmtPrice(e.prixMandat)}',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.white)),
          ]),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text('${e.prixMoyen.round()} EUR/m²',
                style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white)),
            pw.Text('${e.surfaceHabitable} m² habitables',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.white)),
          ]),
        ],
      ),
    );
  }

  pw.Widget _infoSection(Estimation e) => _card('INFORMATIONS GENERALES', [
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
        _row('État général',
            ['A rénover', 'Travaux', 'Bon état', 'Très bon', 'Neuf'][e.etatGeneral.clamp(0, 4)]),
        _row('Orientation', e.orientations.join(', ')),
        _row('Vue', e.vues.join(', ')),
        _row('DPE', e.dpeClasse == 'NC' ? 'Non communiqué (!)' : 'Classe ${e.dpeClasse}'),
        _row('Chauffage', e.chauffageType),
      ]);

  pw.Widget _etatSection(Estimation e) {
    final rows = <pw.Widget>[
      _row('Facade', e.facade),
      _row('Toiture', e.toiture),
      _row('Menuiseries', e.menuiseriesType.join(', ')),
      _row('Vitrage', e.vitrage.join(', ')),
      _row('Chauffage', '${e.chauffageType} . ${e.chauffageEtat} . ${e.anneeChaudiere}'),
      _row('Electricite', e.electricite),
      _row('Isolation', e.isolation),
      _row('Occupation', e.libreOccupation ? 'Libre' : 'Loue'),
    ];
    if (!e.libreOccupation) {
      if (e.loyerMensuel > 0)
        rows.add(_row('Loyer mensuel',
            '${e.loyerMensuel} EUR/mois (bail ${e.typeBail})'));
      if (e.dateFinBail.isNotEmpty)
        rows.add(_row('Fin du bail', e.dateFinBail));
      if (e.congeLocataire)
        rows.add(_row('Conge locataire', 'Oui - bien libre a echeance'));
    }
    return _card('ETAT & EQUIPEMENTS', rows);
  }

  pw.Widget _chargesSection(Estimation e) {
    fmtTax(int v) => v > 0
        ? '${v.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')} EUR/an'
        : 'Non renseigne';
    final rows = <pw.Widget>[
      _row('Taxe fonciere', fmtTax(e.taxeFonciere)),
    ];
    if (e.typeId == 'appartement') {
      rows.add(_row('Charges copropriete', fmtTax(e.chargesCopro)));
      if (e.chargesCopro > 0) {
        rows.add(_row('  dont mensuel',
            '~${(e.chargesCopro / 12).round()} EUR/mois'));
      }
    }
    final total =
        e.taxeFonciere + (e.typeId == 'appartement' ? e.chargesCopro : 0);
    if (total > 0) rows.add(_row('Total annuel', fmtTax(total), bold: true));
    return _card('CHARGES & IMPOTS ANNUELS', rows);
  }

  pw.Widget _diagnosticsSection(Estimation e) {
    const labels = {
      'dpe': 'DPE',
      'carrez': 'Loi Carrez',
      'amiante': 'Amiante',
      'electricite': 'Electricite',
      'gaz': 'Gaz',
      'plomb': 'Plomb',
      'termites': 'Termites',
      'erp': 'ERP',
      'assainissement': 'Assainissement',
      'radon': 'Radon',
      'bruit': 'Bruit aerodrome',
      'dgt': 'DGT (copro)',
    };
    final filled = e.diagnostics.entries
        .where((en) => (en.value['statut'] ?? '').isNotEmpty)
        .toList();
    if (filled.isEmpty)
      return _card('DIAGNOSTICS', [_row('Statut', 'Non renseignes')]);
    final rows = filled.map((en) {
      final label = labels[en.key] ?? en.key;
      final statut = en.value['statut'] ?? '';
      final date = en.value['date'] ?? '';
      final statutLabel = statut == 'valide'
          ? 'Valide'
          : statut == 'a_refaire'
              ? 'A refaire'
              : 'N/A';
      final value = date.isNotEmpty ? '$statutLabel ($date)' : statutLabel;
      return _row(label, value, bold: statut == 'a_refaire');
    }).toList();
    return _card('DIAGNOSTICS', rows);
  }

  pw.Widget _marcheSection(Estimation e) {
    final fmt =
        (double v) => '${v.round().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')} EUR';
    final fmtM2 = (double v) => '${v.round()} EUR/m²';

    final rows = <pw.Widget>[];

    if (e.comparables.isNotEmpty) {
      rows.add(pw.Container(
        color: const PdfColor.fromInt(0xFFF0F4F0),
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: pw.Row(children: [
          pw.Expanded(
              flex: 3,
              child: pw.Text('Adresse',
                  style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey700))),
          pw.Expanded(
              flex: 2,
              child: pw.Text('Type / Surface',
                  style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey700))),
          pw.SizedBox(
              width: 60,
              child: pw.Text('Date vente',
                  style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey700))),
          pw.SizedBox(
              width: 70,
              child: pw.Text('Prix total',
                  style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey700),
                  textAlign: pw.TextAlign.right)),
          pw.SizedBox(
              width: 55,
              child: pw.Text('Prix/m²',
                  style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey700),
                  textAlign: pw.TextAlign.right)),
        ]),
      ));

      for (int i = 0; i < e.comparables.length; i++) {
        final c = e.comparables[i];
        final isLocal = (c['source'] as String?) == 'local';
        final bgColor =
            i.isOdd ? const PdfColor.fromInt(0xFFFAFAFA) : PdfColors.white;

        rows.add(pw.Container(
          color: bgColor,
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          child: pw.Row(children: [
            pw.Expanded(
                flex: 3,
                child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        (c['addr'] as String?)?.isNotEmpty == true
                            ? c['addr'] as String
                            : '—',
                        style: const pw.TextStyle(
                            fontSize: 8, color: PdfColors.grey900),
                        overflow: pw.TextOverflow.clip,
                        maxLines: 2,
                      ),
                      if (isLocal)
                        pw.Text('Ma base locale',
                            style: const pw.TextStyle(
                                fontSize: 7,
                                color: PdfColor.fromInt(0xFF7B1FA2))),
                    ])),
            pw.Expanded(
                flex: 2,
                child: pw.Text(
                  (c['desc'] as String?) ?? '—',
                  style: const pw.TextStyle(
                      fontSize: 8, color: PdfColors.grey700),
                )),
            pw.SizedBox(
                width: 60,
                child: pw.Text(
                  (c['date'] as String?) ?? '—',
                  style: const pw.TextStyle(
                      fontSize: 8, color: PdfColors.grey700),
                )),
            pw.SizedBox(
                width: 70,
                child: pw.Text(
                  c['prix'] != null
                      ? fmt((c['prix'] as num).toDouble())
                      : '—',
                  style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey900),
                  textAlign: pw.TextAlign.right,
                )),
            pw.SizedBox(
                width: 55,
                child: pw.Text(
                  c['prixM2'] != null
                      ? fmtM2((c['prixM2'] as num).toDouble())
                      : '—',
                  style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: _kGreen),
                  textAlign: pw.TextAlign.right,
                )),
          ]),
        ));
      }

      rows.add(pw.SizedBox(height: 10));
    }

    rows.add(_row('Médiane DVF (${e.comparables.length} ventes)',
        fmtM2(e.prixMoyen),
        bold: true));
    if (e.prixPricehubble > 0) {
      rows.add(_row(
        'PriceHubble (pondération ${e.ponderationPh}%)',
        fmt(e.prixPricehubble),
      ));
    }
    if (e.prixAnnonces > 0) {
      rows.add(_row(
        'Annonces portails (pondération ${e.ponderationAnnonces}%)',
        fmt(e.prixAnnonces),
      ));
    }

    rows.add(pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6),
      child: pw.Container(height: 0.5, color: PdfColors.grey300),
    ));

    rows.add(_row(
      'Prix fondamental retenu (pondéré)',
      fmtM2(e.prixFondamentalM2),
      bold: true,
    ));

    return _card('ANALYSE DU MARCHE — REFERENCES DVF', rows);
  }

  pw.Widget _prestationsSection(Estimation e) {
    score(int n) => '$n/4';
    fmt(double v) => '${v.round().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')} EUR';
    final coeff = e.coefficientPrestations;
    final impact =
        e.prixM2Retenu * e.surfaceHabitable - e.prixMoyen * e.surfaceHabitable;

    return _card('QUALITE DES PRESTATIONS', [
      _row('Cuisine', score(e.noteCuisine)),
      _row('Sol', score(e.noteSol)),
      _row('Salle de bain / Eau', score(e.noteSdb)),
      _row('Fenêtres / Menuiseries', score(e.noteFenetres)),
      _row('Chauffage', score(e.noteChauffage)),
      _row('Etat général', score(e.noteEtatPrestation)),
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 6),
        child: pw.Container(height: 0.5, color: PdfColors.grey300),
      ),
      _row('Score pondéré', '${e.scorePrestations.toStringAsFixed(1)}/4',
          bold: true),
      _row('Ajustement',
          '${coeff >= 0 ? '+' : ''}${coeff.toInt()}% — ${e.labelCoefficientPrestations}'),
      _row('Prix m² médian DVF', '${e.prixMoyen.round()} EUR/m²'),
      _row('Prix m² retenu', '${e.prixM2Retenu.round()} EUR/m²', bold: true),
      _row('Impact sur la valeur',
          '${impact >= 0 ? '+' : ''}${fmt(impact)}'),
    ]);
  }

  pw.Widget _estimationSection(Estimation e, double price) {
    final low = e.fourchetteBasse > 0 ? e.fourchetteBasse : price * 0.95;
    final high = e.fourchetteHaute > 0 ? e.fourchetteHaute : price * 1.05;
    fmt(double v) => '${v.round().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')} EUR';
    return _card('ESTIMATION', [
      _row('Vue dégagée',
          '${e.ajustVue >= 0 ? '+' : ''}${e.ajustVue.toStringAsFixed(1)}%'),
      _row('Etat / Rénovation',
          '${e.ajustEtat >= 0 ? '+' : ''}${e.ajustEtat.toStringAsFixed(1)}%'),
      _row('Performance DPE (${e.dpeClasse})',
          '${e.ajustDpe >= 0 ? '+' : ''}${e.ajustDpe.toStringAsFixed(1)}%'),
      if (e.ajustExposition != 0)
        _row('Exposition (${e.orientations.join('/')})',
            '${e.ajustExposition >= 0 ? '+' : ''}${e.ajustExposition.toStringAsFixed(1)}%'),
      if (e.ajustEnvironnement != 0)
        _row('Environnement / Nuisances',
            '${e.ajustEnvironnement.toStringAsFixed(1)}%'),
      if (e.ajustParking < 0)
        _row('Sans stationnement', '-${fmt((-e.ajustParking).toDouble())}'),
      if (e.ajustParking > 0)
        _row('Parking supplémentaire', '+${fmt(e.ajustParking.toDouble())}'),
      if (e.ajustPiscine > 0)
        _row('Prime piscine', '+${fmt(e.ajustPiscine.toDouble())}'),
      if (e.ajustTravaux > 0)
        _row('Travaux', '-${fmt(e.ajustTravaux.toDouble())}'),
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 6),
        child: pw.Container(height: 0.5, color: PdfColors.grey300),
      ),
      _row('Valeur estimée (net vendeur)', fmt(price), bold: true),
      _row('Prix de mandat (+${e.margeNegociation.toInt()}%)',
          fmt(e.prixMandat),
          bold: true),
      _row('Fourchette', '${fmt(low)} — ${fmt(high)}'),
      _row('Validité', _fmtDate(e.validiteJusquau)),
    ]);
  }

  pw.Widget _risquesSection(GeorisquesData r) {
    final rows = <pw.Widget>[];

    rows.add(_row('Niveau sismique',
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
          r.risquesNaturels.map((s) => '- $s').join('\n')));
    }
    if (r.risquesTechnologiques.isNotEmpty) {
      rows.add(_row('Risques technologiques',
          r.risquesTechnologiques.map((s) => '- $s').join('\n')));
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
    if (n.motivationVente.isNotEmpty)
      rows.add(_row('Motivation vente', n.motivationVente));
    if (n.delaiSouhaite.isNotEmpty)
      rows.add(_row('Délai souhaité', n.delaiSouhaite));
    if (n.prixSouhaite.isNotEmpty)
      rows.add(_row('Prix souhaité', n.prixSouhaite));
    if (n.travauxDeclares.isNotEmpty)
      rows.add(_row('Travaux déclarés', n.travauxDeclares));
    if (n.situationPersonnelle.isNotEmpty)
      rows.add(_row('Situation', n.situationPersonnelle));
    if (n.pointsForts.isNotEmpty) {
      rows.add(
          _row('Points forts', n.pointsForts.map((s) => '- $s').join('\n')));
    }
    if (n.pointsFaibles.isNotEmpty) {
      rows.add(_row(
          'Points faibles', n.pointsFaibles.map((s) => '- $s').join('\n')));
    }
    if (rows.isEmpty && n.transcription.isNotEmpty) {
      rows.add(pw.Padding(
        padding: const pw.EdgeInsets.only(top: 4),
        child: pw.Text(n.transcription,
            style: const pw.TextStyle(
                fontSize: 10, color: PdfColors.grey800)),
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
            child: pw.Image(pw.MemoryImage(bytes),
                fit: pw.BoxFit.cover, height: 160),
          ),
        ));
      } catch (_) {}
    }
    if (images.isEmpty) return pw.SizedBox();

    final rows = <pw.Widget>[];
    for (var i = 0; i < images.length; i += 2) {
      rows.add(pw.Row(children: [
        images[i],
        if (i + 1 < images.length)
          images[i + 1]
        else
          pw.Expanded(child: pw.SizedBox()),
      ]));
      if (i + 2 < images.length) rows.add(pw.SizedBox(height: 4));
    }
    return _card('PHOTOS DU BIEN', rows);
  }

  pw.Widget _plusValueSection(Estimation e) {
    fmt(double v) => _fmtPrice(v);
    if (e.residencePrincipale) {
      return _card('PLUS-VALUE', [
        _row('Residence', 'Principale - Exoneration totale', bold: true)
      ]);
    }
    if (e.prixAchat == 0 || e.anneeAchat == 0 || e.prixFinal == 0) {
      return _card('PLUS-VALUE', [
        _row('Situation', 'Residence secondaire - donnees manquantes')
      ]);
    }
    final ans = (DateTime.now().year - e.anneeAchat).clamp(0, 50);
    final fraisAcq = (e.prixAchat * 0.075).round();
    final prixRevient = e.prixAchat + fraisAcq;
    final pvBrute = e.prixFinal - prixRevient;
    if (pvBrute <= 0) {
      return _card('PLUS-VALUE',
          [_row('Situation', 'Moins-value - aucune imposition')]);
    }
    double abIR(int a) {
      if (a <= 5) return 0;
      if (a <= 21) return (a - 5) * 6.0;
      if (a == 22) return 100;
      return 100;
    }

    double abPS(int a) {
      if (a <= 5) return 0;
      if (a <= 21) return (a - 5) * 1.65;
      if (a == 22) return (16 * 1.65) + 1.60;
      if (a <= 30) return (16 * 1.65 + 1.60) + (a - 22) * 9.0;
      return 100;
    }

    final ai = abIR(ans).clamp(0.0, 100.0);
    final ap = abPS(ans).clamp(0.0, 100.0);
    final impot = pvBrute * (1 - ai / 100) * 0.19 +
        pvBrute * (1 - ap / 100) * 0.172;
    return _card('PLUS-VALUE (residence secondaire)', [
      _row('Annees de detention', '$ans ans'),
      _row('Prix de revient (achat + frais 7.5%)',
          fmt(prixRevient.toDouble())),
      _row('Plus-value brute', fmt(pvBrute.toDouble()), bold: true),
      _row('Abattement IR / PS',
          '${ai.toStringAsFixed(0)}% / ${ap.toStringAsFixed(0)}%'),
      _row('Imposition estimee (IR 19% + PS 17.2%)', fmt(impot), bold: true),
      if (ai >= 100 && ap >= 100) _row('Statut', 'Exoneration totale'),
    ]);
  }

  pw.Widget _documentsSection(Estimation e) {
    final docs = requiredDocs(e);
    final checked = e.documentsChecked;
    final rows = docs.map((doc) {
      final id = doc['id']!;
      final isChecked = checked[id] == true;
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(children: [
          pw.Container(
            width: 12,
            height: 12,
            decoration: pw.BoxDecoration(
              color: isChecked ? _kGreen : PdfColors.white,
              border: pw.Border.all(
                  color:
                      isChecked ? _kGreen : PdfColors.grey400,
                  width: 1),
              borderRadius: pw.BorderRadius.circular(2),
            ),
            child: isChecked
                ? pw.Center(
                    child: pw.Text('v',
                        style: pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.white,
                            fontWeight: pw.FontWeight.bold)))
                : null,
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
              child: pw.Text(
            doc['label']!,
            style: pw.TextStyle(
              fontSize: 10,
              color:
                  isChecked ? PdfColors.grey500 : PdfColors.grey900,
              decoration: isChecked
                  ? pw.TextDecoration.lineThrough
                  : null,
            ),
          )),
        ]),
      );
    }).toList();
    final nbOk =
        docs.where((d) => checked[d['id']] == true).length;
    return _card(
        'DOCUMENTS A REUNIR (${nbOk}/${docs.length} collectes)', rows);
  }

  pw.Widget _conclusionSection(Estimation e) => _card('CONCLUSION', [
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 4),
          child: pw.Text(e.conclusion,
              style: const pw.TextStyle(
                  fontSize: 11, color: PdfColors.grey800)),
        ),
      ]);

  // ── Composants UI ───────────────────────────────────────────────────────────

  pw.Widget _card(String title, List<pw.Widget> rows) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: pw.BoxDecoration(
              color: _kGreen,
              borderRadius: const pw.BorderRadius.only(
                topLeft: pw.Radius.circular(6),
                topRight: pw.Radius.circular(6),
              ),
            ),
            child: pw.Text(title,
                style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                    letterSpacing: 0.8)),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.fromLTRB(12, 10, 12, 6),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
              borderRadius: const pw.BorderRadius.only(
                bottomLeft: pw.Radius.circular(6),
                bottomRight: pw.Radius.circular(6),
              ),
            ),
            child: pw.Column(children: rows),
          ),
        ],
      );

  pw.Widget _row(String label, String value, {bool bold = false}) =>
      pw.Container(
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            bottom: pw.BorderSide(
                color: PdfColor.fromInt(0xFFF0F0F0), width: 0.5),
          ),
        ),
        padding: const pw.EdgeInsets.symmetric(vertical: 5),
        child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(label,
                  style: const pw.TextStyle(
                      fontSize: 10, color: PdfColors.grey700)),
              pw.Flexible(
                  child: pw.Text(value,
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: bold
                            ? pw.FontWeight.bold
                            : pw.FontWeight.normal,
                        color: bold ? _kGreen : _kCharcoal,
                      ),
                      textAlign: pw.TextAlign.right)),
            ]),
      );

  // ── Helpers ─────────────────────────────────────────────────────────────────

  String _fmtPrice(double v) =>
      '${v.round().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')} EUR';

  String _fmtDate(DateTime d) {
    const months = [
      'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
      'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}
