/// Un diagnostic de performance énergétique récemment établi dans le secteur.
///
/// Un DPE est obligatoire pour mettre un logement en vente ou en location :
/// un DPE fraîchement réalisé signale donc, dans la majorité des cas, un bien
/// qui s'apprête à arriver sur le marché.
///
/// C'est un **signal, pas un fait** : le diagnostic peut avoir été fait pour
/// une mise en location, pour un projet de vente abandonné, ou simplement pour
/// renouveler un DPE périmé. L'interface doit le présenter comme tel.
///
/// Source : base ADEME des DPE logements existants (open data, mise à jour
/// quotidienne). Aucun prix n'y figure.
class DpeRecent {
  final String adresse;
  final String commune;
  final DateTime date;

  /// Étiquette énergie (A à G), vide si non renseignée.
  final String etiquette;

  /// Surface habitable en m², 0 si inconnue.
  final double surface;

  /// 'maison', 'appartement' ou 'immeuble'.
  final String typeBatiment;

  final double latitude;
  final double longitude;

  const DpeRecent({
    required this.adresse,
    required this.commune,
    required this.date,
    this.etiquette = '',
    this.surface = 0,
    this.typeBatiment = '',
    this.latitude = 0,
    this.longitude = 0,
  });

  bool get aCoordonnees => latitude != 0 && longitude != 0;

  /// Ancienneté du diagnostic, en jours.
  int get ageJours => DateTime.now().difference(date).inDays;

  /// Libellé court pour l'affichage carte.
  String get libelleAge {
    final j = ageJours;
    if (j <= 0) return "aujourd'hui";
    if (j == 1) return 'hier';
    if (j < 30) return 'il y a $j jours';
    final mois = (j / 30).round();
    return mois <= 1 ? 'il y a 1 mois' : 'il y a $mois mois';
  }

  /// Construit depuis une ligne de l'API ADEME.
  ///
  /// Renvoie null si l'enregistrement est inexploitable : sans date, il est
  /// impossible de juger de sa fraîcheur, ce qui est tout l'intérêt ici.
  static DpeRecent? fromAdeme(Map<String, dynamic> j) {
    final brut = j['date_etablissement_dpe']?.toString() ?? '';
    final date = DateTime.tryParse(brut);
    if (date == null) return null;

    // _geopoint arrive au format "lat,lon".
    double lat = 0, lon = 0;
    final geo = j['_geopoint']?.toString() ?? '';
    final parts = geo.split(',');
    if (parts.length == 2) {
      lat = double.tryParse(parts[0].trim()) ?? 0;
      lon = double.tryParse(parts[1].trim()) ?? 0;
    }

    return DpeRecent(
      adresse: (j['adresse_ban'] ?? j['adresse_brut'] ?? '').toString().trim(),
      commune: (j['nom_commune_ban'] ?? j['nom_commune_brut'] ?? '').toString().trim(),
      date: date,
      etiquette: (j['etiquette_dpe'] ?? '').toString().trim().toUpperCase(),
      surface: _versDouble(j['surface_habitable_logement']),
      typeBatiment: (j['type_batiment'] ?? '').toString().trim().toLowerCase(),
      latitude: lat,
      longitude: lon,
    );
  }

  static double _versDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  // ── Sérialisation pour le cache disque ────────────────────────────────────

  Map<String, dynamic> toCacheJson() => {
        'a': adresse,
        'c': commune,
        'd': date.toIso8601String(),
        'e': etiquette,
        's': surface,
        't': typeBatiment,
        'lat': latitude,
        'lon': longitude,
      };

  static DpeRecent? fromCacheJson(Map<String, dynamic> j) {
    final date = DateTime.tryParse(j['d']?.toString() ?? '');
    if (date == null) return null;
    return DpeRecent(
      adresse: j['a']?.toString() ?? '',
      commune: j['c']?.toString() ?? '',
      date: date,
      etiquette: j['e']?.toString() ?? '',
      surface: _versDouble(j['s']),
      typeBatiment: j['t']?.toString() ?? '',
      latitude: _versDouble(j['lat']),
      longitude: _versDouble(j['lon']),
    );
  }
}
