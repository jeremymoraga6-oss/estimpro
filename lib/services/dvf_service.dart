import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class DvfTransaction {
  final String dateMutation;
  final double valeurFonciere;
  final String adresse;
  final String codeCommune;
  final String nomCommune;
  final String typeLocal;
  final double surfaceReelleBati;

  const DvfTransaction({
    required this.dateMutation,
    required this.valeurFonciere,
    required this.adresse,
    required this.codeCommune,
    required this.nomCommune,
    required this.typeLocal,
    required this.surfaceReelleBati,
  });

  double get prixM2 =>
      surfaceReelleBati > 0 ? valeurFonciere / surfaceReelleBati : 0;
  String get formattedDate => _fmtDate(dateMutation);

  Map<String, dynamic> toComparable() => {
        'addr': adresse.isNotEmpty ? adresse : nomCommune,
        'desc': '$typeLocal · ${surfaceReelleBati.round()} m² · $nomCommune',
        'date': _fmtDate(dateMutation),
        'prix': valeurFonciere,
        'prixM2': prixM2.roundToDouble(),
      };

  static String _fmtDate(String iso) {
    if (iso.length < 7) return iso;
    const months = [
      '', 'jan.', 'fév.', 'mar.', 'avr.', 'mai', 'juin',
      'juil.', 'août', 'sep.', 'oct.', 'nov.', 'déc.'
    ];
    final parts = iso.split('-');
    final month = int.tryParse(parts[1]) ?? 1;
    return '${months[month]} ${parts[0]}';
  }

  /// Parse a DVF géolocalisées record (tabular-api or api.cquest.org format).
  factory DvfTransaction.fromTabular(Map<String, dynamic> j) {
    final addrParts = [
      j['adresse_numero']?.toString(),
      j['adresse_nom_voie']?.toString(),
    ].where((v) => v != null && v.isNotEmpty);
    return DvfTransaction(
      dateMutation: j['date_mutation'] as String? ?? '',
      valeurFonciere: _parseDouble(j['valeur_fonciere']),
      adresse: addrParts.join(' '),
      codeCommune: j['code_commune']?.toString() ?? '',
      nomCommune: j['nom_commune']?.toString() ??
          j['commune']?.toString() ?? '',
      typeLocal: j['type_local']?.toString() ?? '',
      surfaceReelleBati: _parseDouble(j['surface_reelle_bati']),
    );
  }

  static double _parseDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(',', '.')) ?? 0;
  }
}

/// Debug info returned alongside the transactions.
class DvfFetchResult {
  final List<DvfTransaction> transactions;
  final String codeInsee;
  final String urlUtilisee;
  final int nombreBrut;
  final String? erreur;

  const DvfFetchResult({
    required this.transactions,
    required this.codeInsee,
    required this.urlUtilisee,
    required this.nombreBrut,
    this.erreur,
  });
}

class DvfService {
  // api.cquest.org — micro-API DVF, même champs que DVF géolocalisées
  static const _cquestBase = 'https://api.cquest.org/dvf';

  // Fallback : tabular-api data.gouv.fr — resource ID découvert dynamiquement
  static const _tabularBase = 'https://tabular-api.data.gouv.fr/api/resources/';
  static const _catalogUrl =
      'https://www.data.gouv.fr/api/1/datasets/demandes-de-valeurs-foncieres-geolocalisees/';
  static String? _cachedResourceId;

  /// Fetches DVF transactions for a single INSEE code.
  /// Tries api.cquest.org first, then tabular-api as fallback.
  Future<DvfFetchResult> fetch({
    required String codeInsee,
    String? typeLocal,
    double? surface,
  }) async {
    if (codeInsee.isEmpty) {
      return DvfFetchResult(
        transactions: [],
        codeInsee: codeInsee,
        urlUtilisee: '',
        nombreBrut: 0,
        erreur: 'Code INSEE manquant — renseignez l\'adresse en étape 1.',
      );
    }

    // --- Source 1 : api.cquest.org ---
    final cquestResult = await _fetchCquest(codeInsee, typeLocal);
    if (cquestResult != null) {
      return _applyFilters(cquestResult, surface);
    }

    // --- Source 2 : tabular-api.data.gouv.fr (resource ID dynamique) ---
    return _fetchTabular(codeInsee, typeLocal, surface);
  }

  // ── api.cquest.org ──────────────────────────────────────────────────────

  Future<_RawResult?> _fetchCquest(String codeInsee, String? typeLocal) async {
    final params = <String, String>{'code_commune': codeInsee};
    if (typeLocal != null) params['type_local'] = typeLocal;

    final uri = Uri.parse(_cquestBase).replace(queryParameters: params);
    final urlStr = uri.toString();
    debugPrint('[DVF/cquest] GET $urlStr');

    try {
      final resp = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));
      debugPrint('[DVF/cquest] status ${resp.statusCode}');

      if (resp.statusCode != 200) {
        debugPrint('[DVF/cquest] échec HTTP ${resp.statusCode}');
        return null;
      }

      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      // cquest renvoie { nb_resultats: N, resultats: [...] }
      final raw = (body['resultats']) as List<dynamic>? ?? [];
      final count = (body['nb_resultats'] as num?)?.toInt() ?? raw.length;

      final txs = raw
          .map((item) =>
              DvfTransaction.fromTabular(item as Map<String, dynamic>))
          .toList();

      return _RawResult(transactions: txs, nombreBrut: count, url: urlStr);
    } catch (e) {
      debugPrint('[DVF/cquest] exception : $e');
      return null;
    }
  }

  // ── tabular-api (fallback) ───────────────────────────────────────────────

  Future<DvfFetchResult> _fetchTabular(
      String codeInsee, String? typeLocal, double? surface) async {
    final resourceId = await _resolveResourceId();
    if (resourceId == null) {
      return DvfFetchResult(
        transactions: [],
        codeInsee: codeInsee,
        urlUtilisee: _cquestBase,
        nombreBrut: 0,
        erreur: 'Aucune source DVF disponible (cquest indisponible, resource ID introuvable)',
      );
    }

    final params = <String, String>{
      'code_commune__exact': codeInsee,
      'page_size': '100',
    };
    if (typeLocal != null) params['type_local__exact'] = typeLocal;

    final uri = Uri.parse('$_tabularBase$resourceId/data/')
        .replace(queryParameters: params);
    final urlStr = uri.toString();
    debugPrint('[DVF/tabular] GET $urlStr');

    try {
      final resp =
          await http.get(uri).timeout(const Duration(seconds: 20));
      debugPrint('[DVF/tabular] status ${resp.statusCode}');

      if (resp.statusCode != 200) {
        _cachedResourceId = null; // invalide le cache si 404
        return DvfFetchResult(
          transactions: [],
          codeInsee: codeInsee,
          urlUtilisee: urlStr,
          nombreBrut: 0,
          erreur: 'HTTP ${resp.statusCode}',
        );
      }

      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final raw = (body['data'] ?? body['results']) as List<dynamic>? ?? [];
      final nombreBrut = raw.length;

      final txs = raw
          .map((item) =>
              DvfTransaction.fromTabular(item as Map<String, dynamic>))
          .toList();

      return _applyFilters(
        _RawResult(transactions: txs, nombreBrut: nombreBrut, url: urlStr),
        surface,
      );
    } catch (e) {
      debugPrint('[DVF/tabular] exception : $e');
      return DvfFetchResult(
        transactions: [],
        codeInsee: codeInsee,
        urlUtilisee: urlStr,
        nombreBrut: 0,
        erreur: e.toString(),
      );
    }
  }

  /// Discovers the current tabular-api resource ID from the data.gouv.fr catalog.
  Future<String?> _resolveResourceId() async {
    if (_cachedResourceId != null) return _cachedResourceId;
    try {
      final resp = await http
          .get(Uri.parse(_catalogUrl))
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return null;
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final resources = (body['resources'] as List<dynamic>?) ?? [];
      // Cherche le premier CSV (le plus récent uploadé en premier)
      for (final r in resources) {
        final fmt = r['format']?.toString().toLowerCase() ?? '';
        if (fmt == 'csv') {
          _cachedResourceId = r['id']?.toString();
          debugPrint('[DVF/tabular] resource ID découvert : $_cachedResourceId');
          return _cachedResourceId;
        }
      }
    } catch (e) {
      debugPrint('[DVF/tabular] catalog error : $e');
    }
    return null;
  }

  // ── filtres communs ──────────────────────────────────────────────────────

  DvfFetchResult _applyFilters(_RawResult raw, double? surface) {
    var results = raw.transactions
        .where((tx) => tx.valeurFonciere > 0 && tx.surfaceReelleBati > 0)
        .toList();

    final cutoff = DateTime.now().subtract(const Duration(days: 3 * 365));
    results = results.where((tx) {
      if (tx.dateMutation.isEmpty) return true;
      try {
        return DateTime.parse(tx.dateMutation).isAfter(cutoff);
      } catch (_) {
        return true;
      }
    }).toList();

    if (surface != null && surface > 0) {
      final lo = surface * 0.70;
      final hi = surface * 1.30;
      results = results
          .where((tx) =>
              tx.surfaceReelleBati >= lo && tx.surfaceReelleBati <= hi)
          .toList();
    }

    results.sort((a, b) => b.dateMutation.compareTo(a.dateMutation));

    debugPrint('[DVF] après filtres : ${results.length}');

    return DvfFetchResult(
      transactions: results,
      codeInsee: results.isNotEmpty ? results.first.codeCommune : '',
      urlUtilisee: raw.url,
      nombreBrut: raw.nombreBrut,
    );
  }
}

class _RawResult {
  final List<DvfTransaction> transactions;
  final int nombreBrut;
  final String url;
  _RawResult(
      {required this.transactions,
      required this.nombreBrut,
      required this.url});
}
