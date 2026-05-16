import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'geo_service.dart';

class DvfTransaction {
  final String dateMutation;
  final double valeurFonciere;
  final String adresse;
  final String codeCommune;
  final String nomCommune;
  final String typeLocal;
  final double surfaceReelleBati;
  final double latitude;
  final double longitude;
  final double? distanceKm; // distance au bien estimé (null si pas de rayon)

  const DvfTransaction({
    required this.dateMutation,
    required this.valeurFonciere,
    required this.adresse,
    required this.codeCommune,
    required this.nomCommune,
    required this.typeLocal,
    required this.surfaceReelleBati,
    this.latitude = 0,
    this.longitude = 0,
    this.distanceKm,
  });

  DvfTransaction withDistance(double km) => DvfTransaction(
        dateMutation: dateMutation,
        valeurFonciere: valeurFonciere,
        adresse: adresse,
        codeCommune: codeCommune,
        nomCommune: nomCommune,
        typeLocal: typeLocal,
        surfaceReelleBati: surfaceReelleBati,
        latitude: latitude,
        longitude: longitude,
        distanceKm: km,
      );

  double get prixM2 =>
      surfaceReelleBati > 0 ? valeurFonciere / surfaceReelleBati : 0;
  String get formattedDate => _fmtDate(dateMutation);

  Map<String, dynamic> toComparable() => {
        'addr': adresse.isNotEmpty ? adresse : nomCommune,
        'desc': '$typeLocal · ${surfaceReelleBati.round()} m² · $nomCommune'
            '${distanceKm != null ? ' · ${distanceKm!.toStringAsFixed(1)} km' : ''}',
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

  factory DvfTransaction.fromCsvRow(Map<String, String> r) {
    final addrParts = [
      r['adresse_numero'],
      r['adresse_nom_voie'],
    ].where((v) => v != null && v.isNotEmpty);
    return DvfTransaction(
      dateMutation: r['date_mutation'] ?? '',
      valeurFonciere: _parseDouble(r['valeur_fonciere']),
      adresse: addrParts.join(' '),
      codeCommune: r['code_commune'] ?? '',
      nomCommune: r['nom_commune'] ?? '',
      typeLocal: r['type_local'] ?? '',
      surfaceReelleBati: _parseDouble(r['surface_reelle_bati']),
      latitude: _parseDouble(r['latitude']),
      longitude: _parseDouble(r['longitude']),
    );
  }

  static double _parseDouble(String? v) {
    if (v == null || v.isEmpty) return 0;
    return double.tryParse(v.replaceAll(',', '.')) ?? 0;
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

/// Source DVF : fichiers CSV statiques par commune publiés par Etalab sur
/// files.data.gouv.fr/geo-dvf/. URL stable, mise à jour 2x/an, sans auth.
///
/// Pattern : .../latest/csv/{année}/communes/{dep}/{insee}.csv
class DvfService {
  static const _base = 'https://files.data.gouv.fr/geo-dvf/latest/csv';

  /// Fetch DVF transactions for a commune across the last 3-4 years,
  /// with optional surface (±30%), type, and radius (km) filtering.
  ///
  /// If [radiusKm] is set with [latitude]/[longitude], the search expands to
  /// neighboring communes whose center is within radius+5km, then each
  /// transaction is filtered by exact Haversine distance.
  Future<DvfFetchResult> fetch({
    required String codeInsee,
    String? typeLocal,
    double? surface,
    double? radiusKm,
    double? latitude,
    double? longitude,
  }) async {
    if (codeInsee.isEmpty) {
      return const DvfFetchResult(
        transactions: [],
        codeInsee: '',
        urlUtilisee: '',
        nombreBrut: 0,
        erreur: 'Code INSEE manquant — renseignez l\'adresse en étape 1.',
      );
    }

    final dep = _depFromInsee(codeInsee);
    if (dep.isEmpty) {
      return DvfFetchResult(
        transactions: [],
        codeInsee: codeInsee,
        urlUtilisee: '',
        nombreBrut: 0,
        erreur: 'Code département introuvable depuis INSEE $codeInsee',
      );
    }

    // Détermine la liste des communes à interroger
    final useRadius = radiusKm != null &&
        radiusKm > 0 &&
        latitude != null &&
        longitude != null &&
        latitude != 0 &&
        longitude != 0;

    final communeCodes = <String>[codeInsee];
    if (useRadius) {
      final nearby = await GeoService()
          .communesInDept(dep: dep, lat: latitude, lon: longitude);
      // Buffer de 5 km : les communes peuvent s'étendre au-delà de leur centre
      final buffer = 5.0;
      // Limite à 25 communes max pour ne pas exploser le nombre de requêtes
      final filtered = nearby
          .where((c) => c.distanceKm <= radiusKm + buffer)
          .take(25)
          .map((c) => c.code)
          .toSet();
      filtered.add(codeInsee); // toujours inclure la commune de base
      communeCodes
        ..clear()
        ..addAll(filtered);
      debugPrint('[DVF] rayon ${radiusKm}km → ${communeCodes.length} communes');
    }

    // Couvre la fenêtre 3 ans + buffer (le filtre de date final s'occupe du reste)
    final now = DateTime.now();
    final years = [now.year, now.year - 1, now.year - 2, now.year - 3];

    debugPrint('[DVF] INSEE=$codeInsee dep=$dep years=$years communes=${communeCodes.length}');

    // Construit l'URL d'exemple pour le debug
    final firstUrl = '$_base/${years.first}/communes/$dep/$codeInsee.csv';

    // Fetch all (commune × year) pairs in parallel
    final tasks = <Future<_YearResult>>[];
    for (final c in communeCodes) {
      final cdep = _depFromInsee(c);
      for (final y in years) {
        tasks.add(_fetchYear(year: y, dep: cdep, codeInsee: c));
      }
    }
    final results = await Future.wait(tasks);

    final allRows = <DvfTransaction>[];
    var totalBrut = 0;
    final errors = <String>[];

    for (final r in results) {
      totalBrut += r.count;
      allRows.addAll(r.transactions);
      if (r.error != null) errors.add(r.error!);
    }

    if (allRows.isEmpty &&
        errors.isNotEmpty &&
        errors.length == tasks.length) {
      return DvfFetchResult(
        transactions: [],
        codeInsee: codeInsee,
        urlUtilisee: firstUrl,
        nombreBrut: 0,
        erreur: errors.first,
      );
    }

    // Filtre 1 — données valides
    var filtered = allRows
        .where((tx) => tx.valeurFonciere > 0 && tx.surfaceReelleBati > 0)
        .toList();

    // Filtre 2 — date < 3 ans
    final cutoff = DateTime.now().subtract(const Duration(days: 3 * 365));
    filtered = filtered.where((tx) {
      if (tx.dateMutation.isEmpty) return true;
      try {
        return DateTime.parse(tx.dateMutation).isAfter(cutoff);
      } catch (_) {
        return true;
      }
    }).toList();

    // Filtre 3 — type
    if (typeLocal != null && typeLocal.isNotEmpty) {
      filtered = filtered
          .where((tx) =>
              tx.typeLocal.toLowerCase() == typeLocal.toLowerCase())
          .toList();
    }

    // Filtre 4 — surface ±30%
    if (surface != null && surface > 0) {
      final lo = surface * 0.70;
      final hi = surface * 1.30;
      filtered = filtered
          .where((tx) =>
              tx.surfaceReelleBati >= lo && tx.surfaceReelleBati <= hi)
          .toList();
    }

    // Filtre 5 — distance exacte au bien (et calcule la distance par tx)
    if (useRadius) {
      final withDist = <DvfTransaction>[];
      for (final tx in filtered) {
        if (tx.latitude == 0 || tx.longitude == 0) continue;
        final d = GeoService.haversineKm(
            latitude, longitude, tx.latitude, tx.longitude);
        if (d <= radiusKm) withDist.add(tx.withDistance(d));
      }
      filtered = withDist;
      filtered.sort((a, b) => (a.distanceKm ?? 0).compareTo(b.distanceKm ?? 0));
    } else {
      filtered.sort((a, b) => b.dateMutation.compareTo(a.dateMutation));
    }

    debugPrint('[DVF] brut=$totalBrut → après filtres=${filtered.length}');

    return DvfFetchResult(
      transactions: filtered,
      codeInsee: codeInsee,
      urlUtilisee: firstUrl,
      nombreBrut: totalBrut,
    );
  }

  Future<_YearResult> _fetchYear({
    required int year,
    required String dep,
    required String codeInsee,
  }) async {
    final url = '$_base/$year/communes/$dep/$codeInsee.csv';
    try {
      final resp = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode == 404) {
        // Année pas encore publiée — pas une erreur
        debugPrint('[DVF] $year : 404 (pas encore publié)');
        return _YearResult.empty();
      }
      if (resp.statusCode != 200) {
        return _YearResult(error: 'HTTP ${resp.statusCode} sur $year');
      }
      final rows = _parseCsv(resp.body);
      final txs = rows.map(DvfTransaction.fromCsvRow).toList();
      debugPrint('[DVF] $year : ${txs.length} ventes');
      return _YearResult(transactions: txs, count: txs.length);
    } catch (e) {
      debugPrint('[DVF] $year exception : $e');
      return _YearResult(error: e.toString());
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _depFromInsee(String insee) {
    if (insee.length < 2) return '';
    // Corse : 2A001 → "2A", 2B033 → "2B"
    final two = insee.substring(0, 2);
    if (two == '2A' || two == '2B') return two;
    // DOM 5 chiffres : 971xx, 972xx… 976xx → dep = 971-976
    if (insee.startsWith('97') || insee.startsWith('98')) {
      return insee.substring(0, 3);
    }
    return two;
  }

  /// Mini-parser CSV RFC-4180 (gère les guillemets et "" échappés).
  /// DVF utilise la virgule comme séparateur.
  List<Map<String, String>> _parseCsv(String body) {
    final lines = _splitCsvLines(body);
    if (lines.isEmpty) return const [];
    final headers = _parseLine(lines[0]);
    final rows = <Map<String, String>>[];
    for (var i = 1; i < lines.length; i++) {
      final line = lines[i];
      if (line.isEmpty) continue;
      final values = _parseLine(line);
      final map = <String, String>{};
      for (var j = 0; j < headers.length; j++) {
        map[headers[j]] = j < values.length ? values[j] : '';
      }
      rows.add(map);
    }
    return rows;
  }

  /// Split body on actual line breaks (in DVF, no embedded CRLF in fields).
  List<String> _splitCsvLines(String body) {
    final out = <String>[];
    final buf = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < body.length; i++) {
      final c = body[i];
      if (c == '"') {
        inQuotes = !inQuotes;
        buf.write(c);
      } else if (!inQuotes && (c == '\n' || c == '\r')) {
        // Ignore \r, finalize on \n
        if (c == '\n') {
          out.add(buf.toString());
          buf.clear();
        }
      } else {
        buf.write(c);
      }
    }
    if (buf.isNotEmpty) out.add(buf.toString());
    return out;
  }

  List<String> _parseLine(String line) {
    final result = <String>[];
    final buf = StringBuffer();
    var inQuotes = false;
    var i = 0;
    while (i < line.length) {
      final c = line[i];
      if (inQuotes) {
        if (c == '"') {
          if (i + 1 < line.length && line[i + 1] == '"') {
            buf.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          buf.write(c);
        }
      } else {
        if (c == ',') {
          result.add(buf.toString());
          buf.clear();
        } else if (c == '"' && buf.isEmpty) {
          inQuotes = true;
        } else {
          buf.write(c);
        }
      }
      i++;
    }
    result.add(buf.toString());
    return result;
  }
}

class _YearResult {
  final List<DvfTransaction> transactions;
  final int count;
  final String? error;

  _YearResult({
    this.transactions = const [],
    this.count = 0,
    this.error,
  });

  factory _YearResult.empty() => _YearResult();
}
