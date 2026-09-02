import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dvf_cache.dart';
import 'geo_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Statistiques agrégées DVF par commune  (Tabular API data.gouv.fr)
// Source : https://www.data.gouv.fr/datasets/statistiques-dvf/
// Ressource : 851d342f-9c96-41c1-924a-11a7a7aae8a6
// ─────────────────────────────────────────────────────────────────────────────

/// Tendance de marché calculée depuis les transactions DVF d'une commune.
class DvfTrend {
  final double tauxAnnuelPct;   // borné ±6%/an
  final int anneeDebut;
  final int anneeFin;
  final int nbVentesUtilisees;
  final Map<int, double> medianesParAnnee;
  const DvfTrend({
    required this.tauxAnnuelPct,
    required this.anneeDebut,
    required this.anneeFin,
    required this.nbVentesUtilisees,
    required this.medianesParAnnee,
  });
  bool get isValid => tauxAnnuelPct != 0 || medianesParAnnee.length >= 2;
}

class DvfCommuneStats {
  final String codeGeo;
  final String libelleGeo;

  // Appartements
  final int? nbVentesAppartement;
  final int? moyPrixM2Appartement;
  final int? medPrixM2Appartement;

  // Maisons
  final int? nbVentesMaison;
  final int? moyPrixM2Maison;
  final int? medPrixM2Maison;

  // Maisons + appartements combinés
  final int? nbVentesTotal;
  final int? moyPrixM2Total;
  final int? medPrixM2Total;

  const DvfCommuneStats({
    required this.codeGeo,
    required this.libelleGeo,
    this.nbVentesAppartement,
    this.moyPrixM2Appartement,
    this.medPrixM2Appartement,
    this.nbVentesMaison,
    this.moyPrixM2Maison,
    this.medPrixM2Maison,
    this.nbVentesTotal,
    this.moyPrixM2Total,
    this.medPrixM2Total,
  });

  factory DvfCommuneStats.fromJson(Map<String, dynamic> j) => DvfCommuneStats(
        codeGeo: j['code_geo']?.toString() ?? '',
        libelleGeo: j['libelle_geo']?.toString() ?? '',
        nbVentesAppartement: _n(j['nb_ventes_whole_appartement']),
        moyPrixM2Appartement: _n(j['moy_prix_m2_whole_appartement']),
        medPrixM2Appartement: _n(j['med_prix_m2_whole_appartement']),
        nbVentesMaison: _n(j['nb_ventes_whole_maison']),
        moyPrixM2Maison: _n(j['moy_prix_m2_whole_maison']),
        medPrixM2Maison: _n(j['med_prix_m2_whole_maison']),
        nbVentesTotal: _n(j['nb_ventes_whole_apt_maison']),
        moyPrixM2Total: _n(j['moy_prix_m2_whole_apt_maison']),
        medPrixM2Total: _n(j['med_prix_m2_whole_apt_maison']),
      );

  static int? _n(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.round();
    return int.tryParse(v.toString());
  }

  bool get hasAppartement =>
      moyPrixM2Appartement != null && moyPrixM2Appartement! > 0;
  bool get hasMaison => moyPrixM2Maison != null && moyPrixM2Maison! > 0;
  bool get hasData => hasAppartement || hasMaison;
}

/// Accès aux statistiques agrégées DVF par commune via la Tabular API
/// data.gouv.fr. Résultats mis en cache en mémoire pour la session.
class DvfCommuneStatsService {
  static const _resourceId = '851d342f-9c96-41c1-924a-11a7a7aae8a6';
  static const _base =
      'https://tabular-api.data.gouv.fr/api/resources/$_resourceId/data/';

  static final _cache = <String, DvfCommuneStats?>{};

  /// Récupère les stats pour une commune par code INSEE.
  ///
  /// Cache mémoire pour la session, puis cache disque : les stats restent
  /// disponibles sans réseau une fois la commune consultée.
  static Future<DvfCommuneStats?> fetchByCodeInsee(String codeInsee) async {
    if (codeInsee.isEmpty) return null;
    if (_cache.containsKey(codeInsee)) return _cache[codeInsee];

    final cacheKey = 'stats_$codeInsee';
    final cached = await DvfDiskCache.read(cacheKey);
    if (cached != null && !cached.perime && cached.data is Map) {
      final stats = DvfCommuneStats.fromJson(
          Map<String, dynamic>.from(cached.data as Map));
      _cache[codeInsee] = stats;
      return stats;
    }

    /// Sans réseau, une stat datée vaut mieux qu'une absence de prix au m².
    DvfCommuneStats? secours() {
      if (cached == null || cached.data is! Map) return null;
      final stats = DvfCommuneStats.fromJson(
          Map<String, dynamic>.from(cached.data as Map));
      _cache[codeInsee] = stats;
      debugPrint('[DVF stats] $codeInsee servi du cache de secours');
      return stats;
    }

    try {
      final uri = Uri.parse(_base).replace(queryParameters: {
        'code_geo__exact': codeInsee,
        'page_size': '1',
      });
      final resp =
          await http.get(uri).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return secours();
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final data = body['data'] as List?;
      if (data == null || data.isEmpty) {
        // Commune réellement absente du jeu DVF : on mémorise l'absence.
        final s = secours();
        if (s == null) _cache[codeInsee] = null;
        return s;
      }
      final raw = data.first as Map<String, dynamic>;
      final stats = DvfCommuneStats.fromJson(raw);
      _cache[codeInsee] = stats;
      await DvfDiskCache.write(cacheKey, raw);
      return stats;
    } catch (e) {
      debugPrint('[DVF stats] fetchByCodeInsee error: $e');
      return secours();
    }
  }

  /// Recherche des communes par nom (retourne jusqu'à [limit] résultats).
  static Future<List<DvfCommuneStats>> searchByName(
      String name, {int limit = 12}) async {
    if (name.trim().length < 2) return [];
    try {
      final uri = Uri.parse(_base).replace(queryParameters: {
        'libelle_geo__contains': name.trim(),
        'echelle_geo__exact': 'commune',
        'page_size': limit.toString(),
      });
      final resp =
          await http.get(uri).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return [];
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final data = (body['data'] as List?) ?? [];
      return data
          .map((d) => DvfCommuneStats.fromJson(d as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[DVF stats] searchByName error: $e');
      return [];
    }
  }

  static void clearCache() => _cache.clear();
}

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

  /// Sérialisation pour le cache disque. `distanceKm` est volontairement omis :
  /// il dépend du bien estimé, pas de la transaction, et est recalculé.
  Map<String, dynamic> toCacheJson() => {
        'd': dateMutation,
        'v': valeurFonciere,
        'a': adresse,
        'cc': codeCommune,
        'nc': nomCommune,
        'tl': typeLocal,
        's': surfaceReelleBati,
        'lat': latitude,
        'lon': longitude,
      };

  factory DvfTransaction.fromCacheJson(Map<String, dynamic> j) =>
      DvfTransaction(
        dateMutation: j['d'] as String? ?? '',
        valeurFonciere: (j['v'] as num?)?.toDouble() ?? 0,
        adresse: j['a'] as String? ?? '',
        codeCommune: j['cc'] as String? ?? '',
        nomCommune: j['nc'] as String? ?? '',
        typeLocal: j['tl'] as String? ?? '',
        surfaceReelleBati: (j['s'] as num?)?.toDouble() ?? 0,
        latitude: (j['lat'] as num?)?.toDouble() ?? 0,
        longitude: (j['lon'] as num?)?.toDouble() ?? 0,
      );

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
        'dateIso': dateMutation,
        'prix': valeurFonciere,
        'prixM2': prixM2.roundToDouble(),
        if (latitude != 0 && longitude != 0) 'lat': latitude,
        if (latitude != 0 && longitude != 0) 'lon': longitude,
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
  final DvfTrend? trend;

  /// Date de la donnée la plus ancienne servie depuis le cache disque.
  /// `null` = tout provient du réseau.
  final DateTime? dateCache;

  /// Vrai si le réseau était injoignable et que des données en cache,
  /// éventuellement datées, ont pris le relais.
  final bool modeSecours;

  const DvfFetchResult({
    required this.transactions,
    required this.codeInsee,
    required this.urlUtilisee,
    required this.nombreBrut,
    this.erreur,
    this.trend,
    this.dateCache,
    this.modeSecours = false,
  });

  /// Message court à afficher quand les données ne sortent pas du réseau.
  String? get avertissementFraicheur {
    if (dateCache == null) return null;
    final j = DateTime.now().difference(dateCache!).inDays;
    final anciennete = j <= 0
        ? "aujourd'hui"
        : j == 1
            ? 'hier'
            : 'il y a $j jours';
    return modeSecours
        ? 'Réseau indisponible — données DVF enregistrées $anciennete.'
        : 'Données DVF en cache, enregistrées $anciennete.';
  }
}

/// Source DVF : fichiers CSV statiques par commune publiés par Etalab sur
/// files.data.gouv.fr/geo-dvf/. URL stable, mise à jour 2x/an, sans auth.
///
/// Pattern : .../latest/csv/{année}/communes/{dep}/{insee}.csv
class DvfService {
  static const _base = 'https://files.data.gouv.fr/geo-dvf/latest/csv';

  /// Calcule la tendance annuelle du marché à partir d'une liste de
  /// transactions AVANT filtrage surface/rayon, pour maximiser l'échantillon.
  static DvfTrend? computeTrend(List<DvfTransaction> txs) {
    double? medianOf(List<double> v) {
      if (v.isEmpty) return null;
      final s = List<double>.from(v)..sort();
      final m = s.length ~/ 2;
      return s.length.isOdd ? s[m] : (s[m - 1] + s[m]) / 2;
    }
    // Regroupe les prix m² plausibles par année de mutation
    final byYear = <int, List<double>>{};
    for (final t in txs) {
      final y = int.tryParse(t.dateMutation.split('-').first);
      if (y == null) continue;
      final p = t.prixM2;
      if (p < 800 || p > 12000) continue; // aberrants DVF
      byYear.putIfAbsent(y, () => []).add(p);
    }
    // Années valides : ≥ 8 ventes
    final valides = <int, double>{};
    var nbVentes = 0;
    byYear.forEach((y, prices) {
      if (prices.length >= 8) {
        valides[y] = medianOf(prices)!;
        nbVentes += prices.length;
      }
    });
    if (valides.length < 2) return null;
    final years = valides.keys.toList()..sort();
    final y0 = years.first, y1 = years.last;
    if (y1 - y0 < 1) return null;
    final cagr =
        (math.pow(valides[y1]! / valides[y0]!, 1.0 / (y1 - y0)) - 1) * 100;
    return DvfTrend(
      tauxAnnuelPct: cagr.clamp(-6.0, 6.0).toDouble(),
      anneeDebut: y0,
      anneeFin: y1,
      nbVentesUtilisees: nbVentes,
      medianesParAnnee: valides,
    );
  }

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
    bool forceReseau = false,
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
      const buffer = 5.0;
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

    // Couvre une fenêtre de 5 ans (l'API Etalab a parfois 6-12 mois de retard
    // sur les dernières ventes, donc on remonte plus loin pour avoir du volume)
    final now = DateTime.now();
    final years = [
      now.year, now.year - 1, now.year - 2, now.year - 3, now.year - 4,
    ];

    debugPrint('[DVF] INSEE=$codeInsee dep=$dep years=$years communes=${communeCodes.length}');

    // Construit l'URL d'exemple pour le debug
    final firstUrl = '$_base/${years.first}/communes/$dep/$codeInsee.csv';

    // L'API dvf-api.data.gouv.fr renvoie toutes les années pour une commune
    // d'un coup (pas de filtre année côté API). On fait donc 1 seul appel
    // par commune, et le cutoff date filtre les transactions trop anciennes.
    final tasks = <Future<_YearResult>>[];
    for (final c in communeCodes) {
      tasks.add(_fetchYear(
          year: 0,
          dep: _depFromInsee(c),
          codeInsee: c,
          forceReseau: forceReseau));
    }
    final results = await Future.wait(tasks);

    final allRows = <DvfTransaction>[];
    var totalBrut = 0;
    final errors = <String>[];
    DateTime? dateCache;
    var modeSecours = false;

    for (final r in results) {
      totalBrut += r.count;
      allRows.addAll(r.transactions);
      if (r.error != null) errors.add(r.error!);
      if (r.secours) modeSecours = true;
      // On retient la donnée la plus ancienne : c'est elle qui qualifie
      // la fraîcheur de l'ensemble.
      if (r.dateCache != null &&
          (dateCache == null || r.dateCache!.isBefore(dateCache))) {
        dateCache = r.dateCache;
      }
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
        trend: null,
      );
    }

    // Filtre 1 — données valides
    var filtered = allRows
        .where((tx) => tx.valeurFonciere > 0 && tx.surfaceReelleBati > 0)
        .toList();

    // Filtre 2 — date < 3 ans
    // Fenêtre 5 ans : couvre 2022-2026 en mai 2026.
    final cutoff = DateTime.now().subtract(const Duration(days: 5 * 365));
    filtered = filtered.where((tx) {
      if (tx.dateMutation.isEmpty) return true;
      try {
        return DateTime.parse(tx.dateMutation).isAfter(cutoff);
      } catch (_) {
        return true;
      }
    }).toList();

    // Tendance marché — calculée avant filtres type/surface/rayon (max d'échantillon)
    final trend = DvfService.computeTrend(filtered);

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
      trend: trend,
      dateCache: dateCache,
      modeSecours: modeSecours,
    );
  }

  Future<_YearResult> _fetchYear({
    required int year,
    required String dep,
    required String codeInsee,
    bool forceReseau = false,
  }) async {
    // Source officielle Etalab via dvf-api.data.gouv.fr — API JSON utilisée
    // par app.dvf.etalab.gouv.fr. Plus fiable que files.data.gouv.fr qui passe
    // par un bucket S3 OVH avec problèmes de permissions intermittentes.

    // Cache disque : les ventes DVF d'une commune ne bougent que quelques fois
    // par an. Une entrée fraîche évite jusqu'à 50 requêtes réseau, et une
    // entrée périmée sert de secours quand il n'y a pas de réseau du tout.
    final cacheKey = 'tx_$codeInsee';
    final cached = await DvfDiskCache.read(cacheKey);

    List<DvfTransaction> depuisCache(DvfCacheEntry e) =>
        (e.data as List? ?? [])
            .map((m) =>
                DvfTransaction.fromCacheJson(Map<String, dynamic>.from(m as Map)))
            .toList();

    if (cached != null && !cached.perime && !forceReseau) {
      final txs = depuisCache(cached);
      debugPrint('[DVF] $codeInsee servi du cache (${txs.length} ventes)');
      return _YearResult(
        transactions: txs,
        count: txs.length,
        dateCache: cached.date,
      );
    }

    // Réseau indisponible : mieux vaut une donnée datée que rien du tout.
    _YearResult secoursCache(String motif) {
      if (cached == null) return _YearResult(error: motif);
      final txs = depuisCache(cached);
      debugPrint('[DVF] $codeInsee réseau KO ($motif) → cache du ${cached.date}');
      return _YearResult(
        transactions: txs,
        count: txs.length,
        dateCache: cached.date,
        secours: true,
      );
    }

    final txs = <DvfTransaction>[];
    try {
      // Pagination 20 résultats/page → on récupère jusqu'à 1000 résultats max
      // (50 pages) pour couvrir toutes les années même sur grosses communes.
      for (int page = 1; page <= 50; page++) {
        final url = 'https://dvf-api.data.gouv.fr/dvf?com=$codeInsee&page=$page';
        final resp = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 15));
        if (resp.statusCode != 200) {
          if (page == 1) {
            return secoursCache('HTTP ${resp.statusCode} sur $year');
          }
          break; // arrêt si fin de pagination (404 typique)
        }
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        final data = (body['data'] as List?) ?? [];
        if (data.isEmpty) break;
        for (final r in data) {
          final m = r as Map<String, dynamic>;
          final date = (m['date_mutation'] as String?) ?? '';
          // Filtre année uniquement si year > 0 (sentinel 0 = toutes années)
          if (year > 0 && date.length >= 4 && date.substring(0, 4) != year.toString()) continue;
          // Filtre nature : on ne garde que les ventes
          final nature = (m['nature_mutation'] as String?) ?? '';
          if (!nature.toLowerCase().contains('vente')) continue;
          txs.add(DvfTransaction(
            dateMutation: date,
            valeurFonciere: _numAsDouble(m['valeur_fonciere']),
            adresse: [m['adresse_numero'], m['adresse_nom_voie']]
                .where((v) => v != null && v.toString().isNotEmpty)
                .join(' '),
            codeCommune: (m['code_commune'] as String?) ?? codeInsee,
            nomCommune: (m['nom_commune'] as String?) ?? '',
            typeLocal: (m['type_local'] as String?) ?? '',
            surfaceReelleBati: _numAsDouble(m['surface_reelle_bati']),
            latitude: _numAsDouble(m['latitude']),
            longitude: _numAsDouble(m['longitude']),
          ));
        }
        if (data.length < 20) break; // dernière page
      }
      debugPrint('[DVF] $year etalab API : ${txs.length} ventes');
      // On ne remplace le cache que par une réponse non vide : une commune
      // temporairement vide côté API ne doit pas effacer un historique valide.
      if (txs.isNotEmpty) {
        await DvfDiskCache.write(
            cacheKey, txs.map((t) => t.toCacheJson()).toList());
      }
      return _YearResult(transactions: txs, count: txs.length);
    } catch (e) {
      debugPrint('[DVF] $year etalab API exception : $e');
      return secoursCache(e.toString());
    }
  }

  static double _numAsDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(',', '.')) ?? 0;
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

  /// Split body on actual line breaks (in DVF, no embedded CRLF in fields).

}

class _YearResult {
  final List<DvfTransaction> transactions;
  final int count;
  final String? error;

  /// Date de la donnée si elle vient du cache disque (null = fraîchement
  /// téléchargée).
  final DateTime? dateCache;

  /// Vrai si le réseau a échoué et qu'on a resservi une entrée périmée.
  final bool secours;

  _YearResult({
    this.transactions = const [],
    this.count = 0,
    this.error,
    this.dateCache,
    this.secours = false,
  });

}
