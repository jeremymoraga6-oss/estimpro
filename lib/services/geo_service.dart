import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class NearbyCommune {
  final String code; // INSEE
  final String nom;
  final double centerLat;
  final double centerLon;
  final double distanceKm; // distance from query point to commune center

  const NearbyCommune({
    required this.code,
    required this.nom,
    required this.centerLat,
    required this.centerLon,
    required this.distanceKm,
  });
}

/// Fournit les communes voisines à partir des coordonnées du bien
/// (api officielle geo.api.gouv.fr — pas d'auth, pas de quota).
class GeoService {
  static const _base = 'https://geo.api.gouv.fr';
  // Cache simple : dep → liste de communes (centres). Évite les refetch.
  static final Map<String, List<NearbyCommune>> _cache = {};

  /// Distance Haversine en km entre deux points lat/lon.
  static double haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  /// Liste les communes du département, triées par distance au point fourni.
  Future<List<NearbyCommune>> communesInDept({
    required String dep,
    required double lat,
    required double lon,
  }) async {
    final cached = _cache[dep];
    if (cached != null) {
      return _withDistance(cached, lat, lon);
    }

    final uri = Uri.parse('$_base/communes').replace(queryParameters: {
      'codeDepartement': dep,
      'fields': 'code,nom,centre',
      'format': 'json',
      'geometry': 'centre',
    });
    debugPrint('[Geo] GET $uri');

    try {
      final resp = await http.get(uri).timeout(const Duration(seconds: 12));
      if (resp.statusCode != 200) {
        debugPrint('[Geo] HTTP ${resp.statusCode}');
        return const [];
      }
      final list = jsonDecode(resp.body) as List;
      final communes = <NearbyCommune>[];
      for (final j in list) {
        if (j is! Map<String, dynamic>) continue;
        final coords = j['centre']?['coordinates'] as List?;
        if (coords == null || coords.length != 2) continue;
        final clon = (coords[0] as num).toDouble();
        final clat = (coords[1] as num).toDouble();
        communes.add(NearbyCommune(
          code: j['code']?.toString() ?? '',
          nom: j['nom']?.toString() ?? '',
          centerLat: clat,
          centerLon: clon,
          distanceKm: 0, // recalculé dans _withDistance
        ));
      }
      _cache[dep] = communes;
      debugPrint('[Geo] dep $dep → ${communes.length} communes en cache');
      return _withDistance(communes, lat, lon);
    } catch (e) {
      debugPrint('[Geo] error: $e');
      return const [];
    }
  }

  List<NearbyCommune> _withDistance(
      List<NearbyCommune> source, double lat, double lon) {
    final out = source
        .map((c) => NearbyCommune(
              code: c.code,
              nom: c.nom,
              centerLat: c.centerLat,
              centerLon: c.centerLon,
              distanceKm: haversineKm(lat, lon, c.centerLat, c.centerLon),
            ))
        .toList();
    out.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return out;
  }
}
