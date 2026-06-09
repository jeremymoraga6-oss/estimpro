import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

class FichesAcquereursService {
  Future<Directory> _getFolder() async {
    final base = await getApplicationDocumentsDirectory();
    final folder = Directory('${base.path}/fiches_acquereurs');
    if (!await folder.exists()) await folder.create(recursive: true);
    return folder;
  }

  Future<List<File>> listFiches() async {
    final folder = await _getFolder();
    final files = await folder.list().toList();
    return files
        .whereType<File>()
        .where((f) {
          final p = f.path.toLowerCase();
          return p.endsWith('.pdf') || p.endsWith('.html');
        })
        .toList()
      ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
  }

  /// Sauvegarde depuis un chemin fichier (path disponible).
  Future<File> saveFiche(String sourcePath, String name) async {
    final folder = await _getFolder();
    final dest = File('${folder.path}/$name');
    return File(sourcePath).copy(dest.path);
  }

  /// Sauvegarde depuis des bytes (content URI Android — path peut être null).
  Future<File> saveFicheBytes(Uint8List bytes, String name) async {
    final folder = await _getFolder();
    final dest = File('${folder.path}/$name');
    return dest.writeAsBytes(bytes);
  }

  Future<void> deleteFiche(File file) async {
    if (await file.exists()) await file.delete();
  }
}
