import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/reference_locale.dart';

class BaseLocaleService {
  static final BaseLocaleService _instance = BaseLocaleService._internal();
  factory BaseLocaleService() => _instance;
  BaseLocaleService._internal();

  Future<File> get _file async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/base_locale.json');
  }

  Future<List<ReferenceLocale>> loadAll() async {
    try {
      final f = await _file;
      if (!await f.exists()) return [];
      final data = jsonDecode(await f.readAsString()) as List;
      return data
          .map((m) => ReferenceLocale.fromMap(Map<String, dynamic>.from(m)))
          .toList()
        ..sort((a, b) => b.dateVente.compareTo(a.dateVente));
    } catch (_) {
      return [];
    }
  }

  Future<void> save(ReferenceLocale r) async {
    final all = await loadAll();
    final idx = all.indexWhere((x) => x.id == r.id);
    if (idx >= 0) {
      all[idx] = r;
    } else {
      all.insert(0, r);
    }
    final f = await _file;
    await f.writeAsString(
        jsonEncode(all.map((x) => x.toMap()).toList()));
  }

  Future<void> delete(String id) async {
    final all = await loadAll();
    all.removeWhere((x) => x.id == id);
    final f = await _file;
    await f.writeAsString(
        jsonEncode(all.map((x) => x.toMap()).toList()));
  }

  Future<List<ReferenceLocale>> loadByCommune(String codeInsee) async {
    final all = await loadAll();
    if (codeInsee.isEmpty) return all;
    return all.where((r) => r.codeInsee == codeInsee).toList();
  }

  /// Stats de calibration pour une commune :
  /// {count, countWithEstime, ecartMoyen (%), prixM2Moyen}
  Future<Map<String, dynamic>> getCalibration(String codeInsee) async {
    final refs = await loadByCommune(codeInsee);
    final withEstime = refs.where((r) => r.hasEstime).toList();

    final prixM2List = refs.map((r) => r.prixM2).where((p) => p > 0).toList();
    final prixM2Moyen = prixM2List.isNotEmpty
        ? prixM2List.reduce((a, b) => a + b) / prixM2List.length
        : 0.0;

    if (withEstime.isEmpty) {
      return {
        'count': refs.length,
        'countWithEstime': 0,
        'ecartMoyen': 0.0,
        'prixM2Moyen': prixM2Moyen,
      };
    }

    final ecartMoyen = withEstime.map((r) => r.ecartPct).reduce((a, b) => a + b) /
        withEstime.length;

    return {
      'count': refs.length,
      'countWithEstime': withEstime.length,
      'ecartMoyen': ecartMoyen,
      'prixM2Moyen': prixM2Moyen,
    };
  }
}
