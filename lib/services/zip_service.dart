import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/estimation.dart';
import 'pdf_service.dart';

class ZipService {
  Future<void> exportDossier(Estimation e) async {
    final dir = await getTemporaryDirectory();

    // Génère le PDF (sans ouvrir)
    final pdfFile = await PdfService().generateFile(e);

    // Crée l'archive ZIP
    final encoder = ZipFileEncoder();
    final zipPath = '${dir.path}/${e.reference}_dossier.zip';
    encoder.create(zipPath);

    // Ajoute le PDF
    encoder.addFile(pdfFile, '${e.reference}.pdf');

    // Ajoute les photos existantes
    int photoIdx = 1;
    for (final path in e.photosPaths) {
      final file = File(path);
      if (await file.exists()) {
        final ext = path.contains('.') ? path.split('.').last : 'jpg';
        encoder.addFile(file, 'photos/photo_$photoIdx.$ext');
        photoIdx++;
      }
    }

    encoder.close();

    await Share.shareXFiles(
      [XFile(zipPath, mimeType: 'application/zip')],
      text: 'Dossier estimation ${e.reference} — ${e.proprietaireNom.isEmpty ? e.typeId : e.proprietaireNom}',
      subject: 'EstimPro — Dossier ${e.reference}',
    );
  }
}
