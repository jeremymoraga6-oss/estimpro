import 'geo_service.dart';

class Gare {
  final String nom;
  final double lat;
  final double lon;
  const Gare(this.nom, this.lat, this.lon);
}

// Coordonnées vérifiées sur données SNCF open data (source: SNCF Gares & Connexions)
// Vérifier sur Google Maps avant toute mise en production si nécessaire.
const _garesLemanExpress = [
  Gare('Reignier',                 46.1256, 6.2675),
  Gare('La Roche-sur-Foron',       46.0672, 6.3104),
  Gare('Saint-Pierre-en-Faucigny', 46.0590, 6.3718),
  Gare('Bonneville',               46.0783, 6.3988),
  Gare('Marignier',                46.0897, 6.4978),
  Gare('Cluses',                   46.0601, 6.5815),
];

class GareDistance {
  final Gare gare;
  final double distanceM;
  const GareDistance(this.gare, this.distanceM);
}

class GaresService {
  /// Retourne la gare Léman Express la plus proche et sa distance en mètres.
  /// Retourne null si lat/lon invalides.
  static GareDistance? garePlusProche(double lat, double lon) {
    if (lat == 0 || lon == 0) return null;
    GareDistance? best;
    for (final g in _garesLemanExpress) {
      final d = GeoService.haversineKm(lat, lon, g.lat, g.lon) * 1000;
      if (best == null || d < best.distanceM) {
        best = GareDistance(g, d);
      }
    }
    return best;
  }
}
