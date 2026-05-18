import 'dart:io';
import 'package:path_provider/path_provider.dart';

class PriceHubbleFolderService {
  Future<Directory> _getFolder() async {
    final base = await getApplicationDocumentsDirectory();
    final folder = Directory('${base.path}/pricehubble');
    if (!await folder.exists()) await folder.create(recursive: true);
    return folder;
  }

  Future<List<File>> listPdfs() async {
    final folder = await _getFolder();
    final files = await folder.list().toList();
    return files
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.pdf'))
        .toList()
      ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
  }

  Future<File> savePdf(String sourcePath, String name) async {
    final folder = await _getFolder();
    final dest = File('${folder.path}/$name');
    return File(sourcePath).copy(dest.path);
  }

  Future<void> deletePdf(File file) async {
    if (await file.exists()) await file.delete();
  }

  Future<String> getFolderPath() async {
    return (await _getFolder()).path;
  }
}
