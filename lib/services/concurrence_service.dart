import '../models/estimation.dart';

/// Génère des deep-links pré-filtrés vers les principaux portails immobiliers
/// pour consulter les annonces concurrentes dans le secteur d'un bien estimé.
///
/// Critères utilisés :
/// - Localisation : commune + code postal
/// - Type de bien : maison / appartement
/// - Surface : ±20% autour de la surface habitable
/// - Prix : ±20% autour du prix estimé (si calculé)
///
/// Aucune donnée n'est récupérée — l'utilisateur consulte les annonces
/// directement sur le portail (app native si installée, sinon navigateur).
class ConcurrenceService {
  /// Convertit "Saint-Pierre-en-Faucigny" → "saint-pierre-en-faucigny"
  static String _slug(String commune) {
    return commune
        .toLowerCase()
        .replaceAll(RegExp(r'[àáâãäå]'), 'a')
        .replaceAll(RegExp(r'[èéêë]'), 'e')
        .replaceAll(RegExp(r'[ìíîï]'), 'i')
        .replaceAll(RegExp(r'[òóôõö]'), 'o')
        .replaceAll(RegExp(r'[ùúûü]'), 'u')
        .replaceAll(RegExp(r'[ç]'), 'c')
        .replaceAll(RegExp(r"[\s']+"), '-')
        .replaceAll(RegExp(r'[^a-z0-9-]'), '');
  }

  static int _round1k(double v) => (v / 1000).round() * 1000;

  static ({int smin, int smax}) _surfaceRange(Estimation e) {
    final s = e.surfaceHabitable;
    if (s <= 0) return (smin: 0, smax: 9999);
    return (smin: (s * 0.8).round(), smax: (s * 1.2).round());
  }

  static ({int pmin, int pmax})? _prixRange(Estimation e) {
    final p = e.prixCalcule;
    if (p <= 0) return null;
    return (pmin: _round1k(p * 0.8), pmax: _round1k(p * 1.2));
  }

  static bool canQuery(Estimation e) =>
      e.codePostal.isNotEmpty &&
      e.commune.isNotEmpty &&
      e.surfaceHabitable > 0 &&
      e.typeId != 'terrain';

  /// LeBonCoin — categorie 9 = immobilier vente
  /// real_estate_type : 1=maison, 2=appartement, 3=terrain, 4=parking, 5=autres
  static String leboncoin(Estimation e) {
    final loc = '${_slug(e.commune)}_${e.codePostal}';
    final r = _surfaceRange(e);
    final type = e.typeId == 'appartement' ? '2' : '1';
    var url = 'https://www.leboncoin.fr/recherche?category=9'
        '&locations=$loc'
        '&real_estate_type=$type'
        '&square=${r.smin}-${r.smax}';
    final p = _prixRange(e);
    if (p != null) url += '&price=${p.pmin}-${p.pmax}';
    return url;
  }

  /// SeLoger — projects=2 (achat), types : 1=appartement, 2=maison
  static String seloger(Estimation e) {
    final r = _surfaceRange(e);
    final types = e.typeId == 'appartement' ? '1' : '2';
    final places = Uri.encodeComponent('[{"cp":"${e.codePostal}"}]');
    var url = 'https://www.seloger.com/list.htm?projects=2'
        '&types=$types'
        '&places=$places'
        '&surface=${r.smin}/${r.smax}'
        '&enterprise=0'
        '&qsVersion=1.0';
    final p = _prixRange(e);
    if (p != null) url += '&price=${p.pmin}/${p.pmax}';
    return url;
  }

  /// Bien'Ici — slug-cp dans le path
  static String bienici(Estimation e) {
    final slug = _slug(e.commune);
    final r = _surfaceRange(e);
    final type = e.typeId == 'appartement' ? 'appartement' : 'maison';
    var url = 'https://www.bienici.com/recherche/achat/$slug-${e.codePostal}'
        '?surface-min=${r.smin}'
        '&surface-max=${r.smax}'
        '&type=$type';
    final p = _prixRange(e);
    if (p != null) url += '&prix-max=${p.pmax}';
    return url;
  }

  /// ParuVendu — tt=1 (vente), tbMai/tbApp selon type
  static String paruvendu(Estimation e) {
    final r = _surfaceRange(e);
    final apt = e.typeId == 'appartement' ? '&tbApp=1' : '&tbMai=1';
    return 'https://www.paruvendu.fr/immobilier/annonceimmofo/liste/listeAnnonces'
        '?lo=${e.codePostal}'
        '&tt=1$apt'
        '&sufmin=${r.smin}'
        '&sufmax=${r.smax}';
  }

  /// Liste complète des portails avec leur URL pour un bien donné
  static List<ConcurrencePortail> allPortails(Estimation e) => [
        ConcurrencePortail(
          nom: 'Leboncoin',
          couleur: 0xFFEC5A13,
          url: leboncoin(e),
          description: 'Le plus de volume · particuliers',
        ),
        ConcurrencePortail(
          nom: 'SeLoger',
          couleur: 0xFFE2001A,
          url: seloger(e),
          description: 'Annonces agences · standard marché',
        ),
        ConcurrencePortail(
          nom: "Bien'Ici",
          couleur: 0xFF00A98F,
          url: bienici(e),
          description: 'Carte interactive · photos HD',
        ),
        ConcurrencePortail(
          nom: 'ParuVendu',
          couleur: 0xFF003C8F,
          url: paruvendu(e),
          description: 'Particuliers · annonces locales',
        ),
      ];
}

class ConcurrencePortail {
  final String nom;
  final int couleur;
  final String url;
  final String description;
  const ConcurrencePortail({
    required this.nom,
    required this.couleur,
    required this.url,
    required this.description,
  });
}
