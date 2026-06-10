import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/reference_locale.dart';

/// Résultat de la calibration automatique — source unique de vérité.
class CalibrationSuggestion {
  /// Correction en % à intégrer dans `ajustCalibration` (clamped ±5 %, arrondi 0,5 %).
  final double delta;

  /// Nombre de ventes retenues pour le calcul (après filtrage outliers).
  final int nbVentes;

  /// 'commune' | 'globale' | '' (pas de données).
  final String scope;

  /// Prix m² médian de la base (commune ou globale, toutes ventes).
  final double prixM2Median;

  const CalibrationSuggestion({
    required this.delta,
    required this.nbVentes,
    required this.scope,
    required this.prixM2Median,
  });

  bool get hasData => nbVentes > 0;
}

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

  // ── Calibration automatique ──────────────────────────────────────────────────

  /// Calcule une suggestion de calibration basée sur la médiane des écarts
  /// estimé/vendu de la base locale.
  ///
  /// Algorithme :
  ///  1. Tente d'abord les ventes de la commune [codeInsee] (min 3).
  ///  2. Fallback sur toute la base si pas assez de données.
  ///  3. Filtre les outliers : |ecartPct| > 20 %.
  ///  4. Calcule la médiane (robustesse vs outliers résiduels).
  ///  5. Clamp ±5 %, arrondi au 0,5 % le plus proche.
  Future<CalibrationSuggestion> getSuggestion(String codeInsee) async {
    List<ReferenceLocale> eligible = [];
    String scope = '';

    // Filtre : ventes avec estimation et sans outlier grossier
    List<ReferenceLocale> _eligible(List<ReferenceLocale> src) => src
        .where((r) => r.hasEstime && r.ecartPct.abs() <= 20)
        .toList();

    if (codeInsee.isNotEmpty) {
      final communeRefs = await loadByCommune(codeInsee);
      final e = _eligible(communeRefs);
      if (e.length >= 3) { eligible = e; scope = 'commune'; }
    }

    if (eligible.isEmpty) {
      final allRefs = await loadAll();
      final e = _eligible(allRefs);
      if (e.isNotEmpty) { eligible = e; scope = 'globale'; }
    }

    // Calcul du prix m² médian (toutes ventes, pas seulement celles avec estim)
    final allScope = scope == 'commune'
        ? await loadByCommune(codeInsee)
        : await loadAll();
    final prixM2List = allScope.map((r) => r.prixM2).where((p) => p > 0).toList()..sort();
    final prixM2Med = _medianSorted(prixM2List);

    if (eligible.isEmpty) {
      return CalibrationSuggestion(
        delta: 0,
        nbVentes: allScope.length,  // affiche le nb total même sans données estim
        scope: '',
        prixM2Median: prixM2Med,
      );
    }

    // Médiane des écarts
    final ecarts = eligible.map((r) => r.ecartPct).toList()..sort();
    final medianEcart = _medianSorted(ecarts);

    // Clamp ±5 %, arrondi au 0,5 % le plus proche
    final rawDelta = medianEcart.clamp(-5.0, 5.0);
    final delta = (rawDelta * 2).round() / 2.0;

    return CalibrationSuggestion(
      delta: delta,
      nbVentes: eligible.length,
      scope: scope,
      prixM2Median: prixM2Med,
    );
  }

  static double _medianSorted(List<double> sorted) {
    if (sorted.isEmpty) return 0;
    final n = sorted.length;
    return n.isOdd ? sorted[n ~/ 2] : (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) / 2;
  }
}
