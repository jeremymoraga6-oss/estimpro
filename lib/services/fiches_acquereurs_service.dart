import 'dart:io';
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
        .where((f) => f.path.toLowerCase().endsWith('.html'))
        .toList()
      ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
  }

  Future<File> saveFiche(String sourcePath, String name) async {
    final folder = await _getFolder();
    final safeName = name.endsWith('.html') ? name : '$name.html';
    final dest = File('${folder.path}/$safeName');
    return File(sourcePath).copy(dest.path);
  }

  Future<void> deleteFiche(File file) async {
    if (await file.exists()) await file.delete();
  }
}
