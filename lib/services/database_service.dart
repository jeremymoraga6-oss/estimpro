import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/estimation.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Future<File> get _file async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/estimations.json');
  }

  Future<List<Estimation>> loadAll() async {
    try {
      final f = await _file;
      if (!await f.exists()) return [];
      final data = jsonDecode(await f.readAsString()) as List;
      return data.map((m) => Estimation.fromMap(Map<String, dynamic>.from(m))).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } catch (_) {
      return [];
    }
  }

  Future<void> saveEstimation(Estimation e) async {
    final all = await loadAll();
    final idx = all.indexWhere((x) => x.id == e.id);
    if (idx >= 0) {
      all[idx] = e;
    } else {
      all.insert(0, e);
    }
    final f = await _file;
    await f.writeAsString(jsonEncode(all.map((x) => x.toMap()).toList()));
  }

  Future<Estimation?> loadById(String id) async {
    final all = await loadAll();
    try {
      return all.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> delete(String id) async {
    final all = await loadAll();
    all.removeWhere((e) => e.id == id);
    final f = await _file;
    await f.writeAsString(jsonEncode(all.map((x) => x.toMap()).toList()));
  }
}
