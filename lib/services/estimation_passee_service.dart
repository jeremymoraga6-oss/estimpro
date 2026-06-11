import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/estimation_passee.dart';

class EstimationPasseeService {
  static final EstimationPasseeService _instance = EstimationPasseeService._internal();
  factory EstimationPasseeService() => _instance;
  EstimationPasseeService._internal();

  Future<File> get _file async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/estimations_passees.json');
  }

  Future<List<EstimationPassee>> loadAll() async {
    try {
      final f = await _file;
      if (!await f.exists()) return [];
      final data = jsonDecode(await f.readAsString()) as List;
      return data
          .map((m) => EstimationPassee.fromMap(Map<String, dynamic>.from(m)))
          .toList();
    } catch (e) {
      debugPrint('[EstimPassee] load error: $e');
      return [];
    }
  }

  Future<void> save(EstimationPassee ep) async {
    final all = await loadAll();
    final idx = all.indexWhere((x) => x.id == ep.id);
    if (idx >= 0) {
      all[idx] = ep;
    } else {
      all.insert(0, ep);
    }
    try {
      final f = await _file;
      await f.writeAsString(jsonEncode(all.map((x) => x.toMap()).toList()));
    } catch (e) {
      debugPrint('[EstimPassee] save error: $e');
    }
  }

  Future<void> delete(String id) async {
    final all = await loadAll();
    all.removeWhere((x) => x.id == id);
    try {
      final f = await _file;
      await f.writeAsString(jsonEncode(all.map((x) => x.toMap()).toList()));
    } catch (e) {
      debugPrint('[EstimPassee] delete error: $e');
    }
  }
}
