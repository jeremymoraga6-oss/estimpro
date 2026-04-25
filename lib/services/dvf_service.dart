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

  /// Parse a DVF+ Cerema open-data mutation record.
  /// Fields: datemut, valeurfonc, sbati, libtypbien, l_codinsee, libinsee, l_nomvoie
  factory DvfTransaction.fromCerema(Map<String, dynamic> j) {
    // Commune code — l_codinsee is a list (one mutation can span multiple communes)
    final codeInseeRaw = j['l_codinsee'];
    final codeInsee = (codeInseeRaw is List && codeInseeRaw.isNotEmpty)
        ? codeInseeRaw.first?.toString() ?? ''
        : j['codinsee']?.toString() ?? '';

    // Commune name
    final libnomRaw = j['l_libinsee'];
    final libNom = j['libinsee']?.toString() ??
        ((libnomRaw is List && libnomRaw.isNotEmpty)
            ? libnomRaw.first?.toString() ?? ''
            : '');

    // Street name — l_nomvoie is a list per mutation
    final nomVoieRaw = j['l_nomvoie'];
    final nomVoie = (nomVoieRaw is List && nomVoieRaw.isNotEmpty)
        ? nomVoieRaw.first?.toString() ?? ''
        : '';

    // Date — DVF+ stores as YYYYMMDD integer or YYYY-MM-DD string
    var datemut = j['datemut']?.toString() ?? '';
    if (datemut.length == 8 && !datemut.contains('-')) {
      datemut =
          '${datemut.substring(0, 4)}-${datemut.substring(4, 6)}-${datemut.substring(6, 8)}';
    }

    return DvfTransaction(
      dateMutation: datemut,
      valeurFonciere: _parseDouble(j['valeurfonc']),
      adresse: nomVoie,
      codeCommune: codeInsee,
      nomCommune: libNom,
      typeLocal: j['libtypbien']?.toString() ?? '',
      surfaceReelleBati: _parseDouble(j['sbati']),
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
  // Cerema DVF+ open-data API — maintained by Cerema & DGALN
  static const _baseUrl = 'https://apidf-preprod.cerema.fr';
  static const _endpoint = '/dvf_opendata/mutations/';

  /// Fetches DVF+ transactions for a single INSEE code.
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
      'codinsee': codeInsee,
      'page_size': '200',
    };
    if (typeLocal != null) params['libtypbien'] = typeLocal;

    final uri =
        Uri.parse('$_baseUrl$_endpoint').replace(queryParameters: params);
    final urlStr = uri.toString();
    debugPrint('[DVF] GET $urlStr');

    try {
      final resp = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 20));

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
      // Cerema DRF API returns { count: N, next: ..., results: [...] }
      final raw =
          (body['results'] ?? body['data']) as List<dynamic>? ?? [];
      final nombreBrut =
          (body['count'] as num?)?.toInt() ?? raw.length;
      debugPrint('[DVF] résultats bruts : $nombreBrut');

      var results = raw
          .map((item) =>
              DvfTransaction.fromCerema(item as Map<String, dynamic>))
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
