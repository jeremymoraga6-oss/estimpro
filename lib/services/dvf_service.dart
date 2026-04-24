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
  // Tabular API — resource DVF data.gouv.fr
  static const _tabularBase =
      'https://tabular-api.data.gouv.fr/api/resources/'
      '90a98de0-f562-4328-aa16-fe0dd1dca60f/data/';

  /// Fetches DVF transactions for a single INSEE code.
  /// Applies surface filter (±30%) and date filter (< 3 ans) after fetch.
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

    final params = <String, String>{
      'code_commune__exact': codeInsee,
      'page_size': '100',
    };
    if (typeLocal != null) params['type_local__exact'] = typeLocal;

    final uri = Uri.parse(_tabularBase).replace(queryParameters: params);
    final urlStr = uri.toString();
    debugPrint('[DVF] GET $urlStr');

    try {
      final resp =
          await http.get(uri).timeout(const Duration(seconds: 20));

      debugPrint('[DVF] status ${resp.statusCode}');

      if (resp.statusCode != 200) {
        return DvfFetchResult(
          transactions: [],
          codeInsee: codeInsee,
          urlUtilisee: urlStr,
          nombreBrut: 0,
          erreur: 'HTTP ${resp.statusCode}',
        );
      }

      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      // tabular-api returns { data: [...] } or { results: [...] }
      final raw = (body['data'] ?? body['results']) as List<dynamic>? ?? [];
      final nombreBrut = raw.length;
      debugPrint('[DVF] résultats bruts : $nombreBrut');

      var results = raw
          .map((item) =>
              DvfTransaction.fromTabular(item as Map<String, dynamic>))
          .where((tx) => tx.valeurFonciere > 0 && tx.surfaceReelleBati > 0)
          .toList();

      // Date filter — keep last 3 years
      final cutoff = DateTime.now().subtract(const Duration(days: 3 * 365));
      results = results.where((tx) {
        if (tx.dateMutation.isEmpty) return true;
        try {
          return DateTime.parse(tx.dateMutation).isAfter(cutoff);
        } catch (_) {
          return true;
        }
      }).toList();

      // Surface filter ±30%
      if (surface != null && surface > 0) {
        final lo = surface * 0.70;
        final hi = surface * 1.30;
        results = results
            .where((tx) =>
                tx.surfaceReelleBati >= lo && tx.surfaceReelleBati <= hi)
            .toList();
      }

      // Sort by date descending
      results.sort((a, b) => b.dateMutation.compareTo(a.dateMutation));

      debugPrint('[DVF] après filtres : ${results.length}');

      return DvfFetchResult(
        transactions: results,
        codeInsee: codeInsee,
        urlUtilisee: urlStr,
        nombreBrut: nombreBrut,
      );
    } catch (e) {
      debugPrint('[DVF] exception : $e');
      return DvfFetchResult(
        transactions: [],
        codeInsee: codeInsee,
        urlUtilisee: urlStr,
        nombreBrut: 0,
        erreur: e.toString(),
      );
    }
  }
}
