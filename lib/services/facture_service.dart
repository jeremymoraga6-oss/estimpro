import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import '../models/facture.dart';

// ── Infos fixes émetteur ─────────────────────────────────────────────────────
const _kNom      = 'Jeremy Moraga Efficity';
const _kAdresse  = '186 Rue de la Gare';
const _kVille    = '74930 Reignier Esery';
const _kTel      = '0668036403';
const _kSiret    = '94437073300015';
const _kIban     = 'FR7631233123450076426761128';
const _kBic      = 'TRBKFRPPXXX';
const _kMentions =
    'Jeremy Moraga - EI - est Agent Commercial mandataire en immobilier, immatricule au '
    'Registre Special des Agents Commerciaux du Tribunal de Commerce de Thonon-les-Bains '
    'sous le n 944370733. Siege social du mandant : effiCity, 48 avenue de Villiers - '
    '75017 PARIS - Societe par Actions Simplifiee, societe au capital de 132 373,05 euros, '
    'immatriculee au RCS Paris 497 617 746 et titulaire de la Carte professionnelle '
    'CPI 7501 2015 000 002 025 - CCI Paris IDF - '
    'Caisse de Garantie : GALIAN Assurances 89 rue de la Boetie 75008 Paris';

const _kGreen   = PdfColor.fromInt(0xFF4CAF50);
const _kCharcoal = PdfColor.fromInt(0xFF2C3E50);

class FactureService {
  static const _fileName = 'factures.json';

  // ── Persistance ─────────────────────────────────────────────────────────────

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<List<Facture>> loadAll() async {
    try {
      final f = await _file();
      if (!f.existsSync()) return [];
      final list = jsonDecode(f.readAsStringSync()) as List;
      return list.map((m) => Facture.fromMap(m as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('[FactureService] loadAll error: $e');
      return [];
    }
  }

  Future<Facture?> forEstimation(String estimationId) async {
    final all = await loadAll();
    try {
      return all.lastWhere((f) => f.estimationId == estimationId);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(Facture facture) async {
    final all = await loadAll();
    final idx = all.indexWhere((f) => f.id == facture.id);
    if (idx >= 0) {
      all[idx] = facture;
    } else {
      all.add(facture);
    }
    final f = await _file();
    f.writeAsStringSync(jsonEncode(all.map((e) => e.toMap()).toList()));
  }

  // ── Numérotation ─────────────────────────────────────────────────────────────

  Future<String> nextNumero() async {
    final year = DateTime.now().year;
    final all = await loadAll();
    final sameYear = all.where((f) => f.numero.startsWith('$year-')).toList();
    int last = 0;
    for (final f in sameYear) {
      final parts = f.numero.split('-');
      if (parts.length == 2) {
        final n = int.tryParse(parts[1]) ?? 0;
        if (n > last) last = n;
      }
    }
    final next = (last + 1).toString().padLeft(3, '0');
    return '$year-$next';
  }

  // ── Création ─────────────────────────────────────────────────────────────────

  Future<Facture> create({
    required String estimationId,
    required String clientNom,
    required String clientAdresse,
    required String clientVille,
    required double montantTtc,
  }) async {
    final ht = double.parse((montantTtc / 1.20).toStringAsFixed(2));
    final facture = Facture(
      id: const Uuid().v4(),
      numero: await nextNumero(),
      date: DateTime.now(),
      estimationId: estimationId,
      clientNom: clientNom,
      clientAdresse: clientAdresse,
      clientVille: clientVille,
      montantHT: ht,
    );
    await save(facture);
    return facture;
  }

  // ── PDF ───────────────────────────────────────────────────────────────────────

  Future<File> generatePdf(Facture f) async {
    pw.MemoryImage? logoImage;
    try {
      final data = await rootBundle.load('assets/images/logo.png');
      logoImage = pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {}

    final doc = pw.Document();

    // Page 1 — Facture
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(44, 44, 44, 44),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // En-tête
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('FACTURE',
                    style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: _kCharcoal)),
                pw.SizedBox(height: 4),
                pw.Text('N° : ${f.numero}',
                    style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _kCharcoal)),
                pw.Text('Date : ${_fmtDate(f.date)}',
                    style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
              ]),
              if (logoImage != null)
                pw.SizedBox(
                  height: 55,
                  child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                ),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Container(height: 1.5, color: _kGreen),
          pw.SizedBox(height: 20),

          // Émetteur + Client côte à côte
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('Emetteur :',
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _kCharcoal)),
                  pw.SizedBox(height: 5),
                  pw.Text(_kNom, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
                  pw.Text(_kAdresse, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
                  pw.Text(_kVille, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
                  pw.Text('Tel. : $_kTel', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
                  pw.SizedBox(height: 5),
                  pw.Text('SIRET : $_kSiret', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                ]),
              ),
              pw.SizedBox(width: 30),
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: const PdfColor.fromInt(0xFFF5F5F5),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text('Client :',
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _kCharcoal)),
                    pw.SizedBox(height: 5),
                    pw.Text(f.clientNom, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900)),
                    if (f.clientAdresse.isNotEmpty)
                      pw.Text(f.clientAdresse, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
                    if (f.clientVille.isNotEmpty)
                      pw.Text(f.clientVille, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
                  ]),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 24),

          // Objet
          pw.Text('Objet : ${f.objet}',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _kCharcoal)),
          pw.SizedBox(height: 16),

          // Tableau des prestations
          pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(children: [
              // En-tête tableau
              pw.Container(
                color: _kGreen,
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: pw.Row(children: [
                  pw.Expanded(child: pw.Text('Designation',
                      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white))),
                  pw.SizedBox(width: 40, child: pw.Text('Qte',
                      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                      textAlign: pw.TextAlign.center)),
                  pw.SizedBox(width: 80, child: pw.Text('Prix unit. HT',
                      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                      textAlign: pw.TextAlign.right)),
                  pw.SizedBox(width: 80, child: pw.Text('Total TTC',
                      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                      textAlign: pw.TextAlign.right)),
                ]),
              ),
              // Ligne prestation
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: pw.Row(children: [
                  pw.Expanded(child: pw.Text('Honoraires Estimation Immobiliere.',
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey900))),
                  pw.SizedBox(width: 40, child: pw.Text('1',
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey900),
                      textAlign: pw.TextAlign.center)),
                  pw.SizedBox(width: 80, child: pw.Text('${_fmtMontant(f.montantHT)} EUR',
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey900),
                      textAlign: pw.TextAlign.right)),
                  pw.SizedBox(width: 80, child: pw.Text('${_fmtMontant(f.montantTtc)} EUR',
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _kCharcoal),
                      textAlign: pw.TextAlign.right)),
                ]),
              ),
            ]),
          ),
          pw.SizedBox(height: 16),

          // Totaux
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Row(children: [
                pw.Text('Total HT : ', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                pw.SizedBox(width: 60, child: pw.Text('${_fmtMontant(f.montantHT)} EUR',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey900),
                    textAlign: pw.TextAlign.right)),
              ]),
              pw.SizedBox(height: 4),
              pw.Row(children: [
                pw.Text('TVA (${f.tauxTva.toInt()} %) : ', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                pw.SizedBox(width: 60, child: pw.Text('${_fmtMontant(f.montantTva)} EUR',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey900),
                    textAlign: pw.TextAlign.right)),
              ]),
              pw.SizedBox(height: 6),
              pw.Container(height: 0.5, width: 200, color: _kGreen),
              pw.SizedBox(height: 6),
              pw.Row(children: [
                pw.Text('Total TTC : ', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _kCharcoal)),
                pw.SizedBox(width: 60, child: pw.Text('${_fmtMontant(f.montantTtc)} EUR',
                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _kGreen),
                    textAlign: pw.TextAlign.right)),
              ]),
            ]),
          ]),
          pw.SizedBox(height: 24),
          pw.Container(height: 0.5, color: PdfColors.grey300),
          pw.SizedBox(height: 16),

          // Conditions de paiement
          pw.Text('Conditions de paiement :',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _kCharcoal)),
          pw.SizedBox(height: 5),
          pw.Text('Paiement comptant a reception - par virement bancaire',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          pw.SizedBox(height: 10),
          pw.Text('Coordonnees bancaires :',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          pw.SizedBox(height: 4),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: const PdfColor.fromInt(0xFFF0F4F0),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('IBAN : $_kIban',
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _kCharcoal)),
              pw.SizedBox(height: 3),
              pw.Text('BIC : $_kBic',
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _kCharcoal)),
            ]),
          ),
        ],
      ),
    ));

    // Page 2 — Mentions légales
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(44),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(height: 1.5, color: _kGreen),
          pw.SizedBox(height: 20),
          pw.Text(_kMentions,
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800, lineSpacing: 1.5)),
        ],
      ),
    ));

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/facture_${f.numero.replaceAll('-', '_')}.pdf');
    await file.writeAsBytes(await doc.save());
    return file;
  }

  Future<void> openOrShare(Facture f) async {
    final file = await generatePdf(f);
    final result = await OpenFile.open(file.path);
    if (result.type != ResultType.done) {
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        subject: 'Facture ${f.numero} - ${f.clientNom}',
      );
    }
  }

  Future<void> shareByEmail(Facture f) async {
    final file = await generatePdf(f);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      subject: 'Facture ${f.numero} — Estimation immobiliere',
      text: 'Bonjour,\n\nVeuillez trouver ci-joint la facture n° ${f.numero} '
          'd\'un montant de ${_fmtMontant(f.montantTtc)} EUR TTC.\n\n'
          'Cordialement,\nJeremy Moraga\nFaucigny Immobilier',
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  static String _fmtDate(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year}';
  }

  static String _fmtMontant(double v) {
    final parts = v.toStringAsFixed(2).split('.');
    final euros = parts[0].replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
    return '$euros,${parts[1]}';
  }
}
