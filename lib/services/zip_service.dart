import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/estimation.dart';
import 'pdf_service.dart';

class ZipService {
  Future<void> exportDossier(Estimation e) async {
    final dir = await getTemporaryDirectory();

    final pdfFile = await PdfService().generateFile(e);

    final archive = Archive();

    // Ajoute le PDF
    final pdfBytes = await pdfFile.readAsBytes();
    archive.addFile(ArchiveFile('${e.reference}.pdf', pdfBytes.length, pdfBytes));

    // Ajoute les photos existantes
    int photoIdx = 1;
    for (final path in e.photosPaths) {
      final file = File(path);
      if (await file.exists()) {
        final ext = path.contains('.') ? path.split('.').last : 'jpg';
        final bytes = await file.readAsBytes();
        archive.addFile(ArchiveFile('photos/photo_$photoIdx.$ext', bytes.length, bytes));
        photoIdx++;
      }
    }

    final zipBytes = ZipEncoder().encode(archive);
    final zipPath = '${dir.path}/${e.reference}_dossier.zip';
    await File(zipPath).writeAsBytes(zipBytes!);

    await Share.shareXFiles(
      [XFile(zipPath, mimeType: 'application/zip')],
      text: 'Dossier estimation ${e.reference} — ${e.proprietaireNom.isEmpty ? e.typeId : e.proprietaireNom}',
      subject: 'EstimPro — Dossier ${e.reference}',
    );
  }
}
