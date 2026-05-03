import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Données IAL (Etat des Risques) issues de l'API Géorisques.
class GeorisquesData {
  final String codeInsee;
  final String niveauSismique;       // "1" (très faible) à "5" (forte)
  final String potentielRadon;       // "Faible" / "Moyen" / "Important"
  final String niveauArgile;         // "Faible" / "Moyen" / "Fort"
  final List<String> risquesNaturels;       // libellés (Inondation, Mouvement de terrain…)
  final List<String> risquesTechnologiques; // ICPE, transport matières dangereuses…
  final int nbCatnat;                // nombre d'arrêtés de cat. nat.
  final String urlConsulte;
  final String? erreur;

  const GeorisquesData({
    required this.codeInsee,
    this.niveauSismique = '',
    this.potentielRadon = '',
    this.niveauArgile = '',
    this.risquesNaturels = const [],
    this.risquesTechnologiques = const [],
    this.nbCatnat = 0,
    this.urlConsulte = '',
    this.erreur,
  });

  bool get hasData =>
      niveauSismique.isNotEmpty ||
      potentielRadon.isNotEmpty ||
      niveauArgile.isNotEmpty ||
      risquesNaturels.isNotEmpty ||
      risquesTechnologiques.isNotEmpty;

  Map<String, dynamic> toMap() => {
        'codeInsee': codeInsee,
        'niveauSismique': niveauSismique,
        'potentielRadon': potentielRadon,
        'niveauArgile': niveauArgile,
        'risquesNaturels': risquesNaturels,
        'risquesTechnologiques': risquesTechnologiques,
        'nbCatnat': nbCatnat,
        'urlConsulte': urlConsulte,
      };

  factory GeorisquesData.fromMap(Map<String, dynamic> m) => GeorisquesData(
        codeInsee: m['codeInsee'] as String? ?? '',
        niveauSismique: m['niveauSismique'] as String? ?? '',
        potentielRadon: m['potentielRadon'] as String? ?? '',
        niveauArgile: m['niveauArgile'] as String? ?? '',
        risquesNaturels:
            List<String>.from((m['risquesNaturels'] as List?) ?? []),
        risquesTechnologiques:
            List<String>.from((m['risquesTechnologiques'] as List?) ?? []),
        nbCatnat: (m['nbCatnat'] as num?)?.toInt() ?? 0,
        urlConsulte: m['urlConsulte'] as String? ?? '',
      );
}

class GeorisquesService {
  static const _base = 'https://www.georisques.gouv.fr/api/v1';

  Future<GeorisquesData> fetch({
    required String codeInsee,
    double? latitude,
    double? longitude,
  }) async {
    if (codeInsee.isEmpty) {
      return GeorisquesData(
          codeInsee: '', erreur: 'Code INSEE manquant');
    }

    debugPrint('[Georisques] fetch INSEE=$codeInsee lat=$latitude lon=$longitude');

    final hasLatLon =
        latitude != null && longitude != null && latitude != 0 && longitude != 0;

    final results = await Future.wait<dynamic>([
      _fetchSismique(codeInsee),
      _fetchRadon(codeInsee),
      _fetchRisques(codeInsee),
      _fetchCatnat(codeInsee),
      hasLatLon ? _fetchArgile(latitude, longitude) : Future.value(''),
    ]);

    final sismique = results[0] as String;
    final radon = results[1] as String;
    final risquesPair = results[2] as _RisquesPair;
    final nbCatnat = results[3] as int;
    final argile = results[4] as String;

    return GeorisquesData(
      codeInsee: codeInsee,
      niveauSismique: sismique,
      potentielRadon: radon,
      niveauArgile: argile,
      risquesNaturels: risquesPair.naturels,
      risquesTechnologiques: risquesPair.technologiques,
      nbCatnat: nbCatnat,
      urlConsulte:
          'https://www.georisques.gouv.fr/mes-risques/connaitre-les-risques-pres-de-chez-moi/rapport?codeInsee=$codeInsee',
    );
  }

  // ── Sismicité (zone 1-5) ────────────────────────────────────────────────

  Future<String> _fetchSismique(String codeInsee) async {
    try {
      final uri = Uri.parse('$_base/zonage_sismique')
          .replace(queryParameters: {'code_insee': codeInsee});
      final resp = await http.get(uri).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return '';
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final data = (body['data'] as List?) ?? [];
      if (data.isEmpty) return '';
      final first = data.first as Map<String, dynamic>;
      return first['zone_sismicite']?.toString() ?? '';
    } catch (e) {
      debugPrint('[Georisques] sismique error: $e');
      return '';
    }
  }

  // ── Radon (potentiel 1-3) ───────────────────────────────────────────────

  Future<String> _fetchRadon(String codeInsee) async {
    try {
      final uri = Uri.parse('$_base/radon')
          .replace(queryParameters: {'code_insee': codeInsee});
      final resp = await http.get(uri).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return '';
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final data = (body['data'] as List?) ?? [];
      if (data.isEmpty) return '';
      final first = data.first as Map<String, dynamic>;
      final classe = (first['classe_potentiel'] as num?)?.toInt() ?? 0;
      switch (classe) {
        case 1:
          return 'Faible';
        case 2:
          return 'Moyen';
        case 3:
          return 'Important';
        default:
          return first['libelle_classe']?.toString() ?? '';
      }
    } catch (e) {
      debugPrint('[Georisques] radon error: $e');
      return '';
    }
  }

  // ── Argile (retrait-gonflement, par lat/lon) ────────────────────────────

  Future<String> _fetchArgile(double lat, double lon) async {
    try {
      final uri = Uri.parse('$_base/rga').replace(queryParameters: {
        'latlon': '$lon,$lat',
        'rayon': '500',
      });
      final resp = await http.get(uri).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return '';
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final data = (body['data'] as List?) ?? [];
      if (data.isEmpty) return '';
      final first = data.first as Map<String, dynamic>;
      return first['exposition']?.toString() ??
          first['libelle_exposition']?.toString() ??
          '';
    } catch (e) {
      debugPrint('[Georisques] argile error: $e');
      return '';
    }
  }

  // ── Tous les risques (PPRN + ICPE + autres) ─────────────────────────────

  Future<_RisquesPair> _fetchRisques(String codeInsee) async {
    try {
      final uri = Uri.parse('$_base/gaspar/risques').replace(queryParameters: {
        'code_insee': codeInsee,
        'page_size': '50',
      });
      final resp = await http.get(uri).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return const _RisquesPair([], []);
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final data = (body['data'] as List?) ?? [];

      final naturels = <String>{};
      final tech = <String>{};
      for (final item in data) {
        if (item is! Map<String, dynamic>) continue;
        final libelle = item['libelle_risque_long']?.toString() ??
            item['libelle_risque']?.toString() ??
            '';
        if (libelle.isEmpty) continue;
        final type = item['type_risque']?.toString().toLowerCase() ?? '';
        // Heuristique : technologique si type contient "techno" ou "industriel"
        final lower = libelle.toLowerCase();
        final isTech = type.contains('techno') ||
            type.contains('industriel') ||
            lower.contains('industriel') ||
            lower.contains('nucléaire') ||
            lower.contains('transport') ||
            lower.contains('matières');
        if (isTech) {
          tech.add(libelle);
        } else {
          naturels.add(libelle);
        }
      }
      return _RisquesPair(naturels.toList()..sort(), tech.toList()..sort());
    } catch (e) {
      debugPrint('[Georisques] risques error: $e');
      return const _RisquesPair([], []);
    }
  }

  // ── Arrêtés Cat. Nat. ───────────────────────────────────────────────────

  Future<int> _fetchCatnat(String codeInsee) async {
    try {
      final uri = Uri.parse('$_base/gaspar/catnat').replace(queryParameters: {
        'code_insee': codeInsee,
        'page_size': '1',
      });
      final resp = await http.get(uri).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return 0;
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      return (body['total'] as num?)?.toInt() ??
          ((body['data'] as List?)?.length ?? 0);
    } catch (e) {
      debugPrint('[Georisques] catnat error: $e');
      return 0;
    }
  }
}

class _RisquesPair {
  final List<String> naturels;
  final List<String> technologiques;
  const _RisquesPair(this.naturels, this.technologiques);
}
