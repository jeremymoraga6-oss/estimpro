import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/dpe_recent.dart';
import 'dvf_cache.dart';

/// Résultat d'une interrogation des DPE récents du secteur.
class DpeMarcheResult {
  final List<DpeRecent> dpe;

  /// Date de la donnée si elle vient du cache disque (null = réseau frais).
  final DateTime? dateCache;

  /// Vrai si le réseau a échoué et qu'une entrée datée a pris le relais.
  final bool modeSecours;

  final String? erreur;

  const DpeMarcheResult({
    this.dpe = const [],
    this.dateCache,
    this.modeSecours = false,
    this.erreur,
  });
}

/// Biens susceptibles d'arriver sur le marché, détectés via les DPE récents.
///
/// Un DPE est obligatoire pour mettre un logement en vente ou en location.
/// Un diagnostic fraîchement établi signale donc, le plus souvent, un bien qui
/// s'apprête à être commercialisé — bien avant qu'il n'apparaisse dans DVF,
/// qui ne recense que les ventes **déjà signées**, avec plusieurs mois de
/// retard de publication.
///
/// Les portails d'annonces (LeBonCoin, SeLoger) n'exposent aucune API publique
/// et interdisent l'extraction automatique : cette source ouverte est la seule
/// voie propre pour anticiper la concurrence à venir sur un secteur.
///
/// Limite à assumer dans l'interface : un DPE n'est pas une mise en vente. Il
/// peut concerner une location, un projet abandonné, ou le renouvellement d'un
/// diagnostic périmé. Et aucun prix n'y figure.
class DpeMarcheService {
  static const _base =
      'https://data.ademe.fr/data-fair/api/v1/datasets/dpe03existant/lines';

  static const _champs =
      'date_etablissement_dpe,adresse_ban,nom_commune_ban,etiquette_dpe,'
      'surface_habitable_logement,type_batiment,_geopoint';

  /// Au-delà, on retente le réseau. Les DPE sont publiés en continu, mais une
  /// semaine de décalage ne change rien à une analyse de secteur.
  static const fraicheur = Duration(days: 7);

  /// Fenêtre par défaut : un diagnostic de plus d'un an n'annonce plus grand
  /// chose, le bien est soit vendu soit retiré.
  static const moisParDefaut = 12;

  /// Interroge les DPE établis dans les [moisAnterieurs] derniers mois, dans
  /// un rayon de [rayonKm] autour du point donné.
  ///
  /// Même stratégie que le cache DVF : entrée fraîche servie directement,
  /// sinon réseau, et en cas d'échec réseau on ressert l'entrée périmée
  /// plutôt que rien.
  Future<DpeMarcheResult> fetch({
    required double latitude,
    required double longitude,
    double rayonKm = 3,
    int moisAnterieurs = moisParDefaut,
    int limite = 200,
    bool forceReseau = false,
  }) async {
    if (latitude == 0 || longitude == 0) {
      return const DpeMarcheResult(
        erreur: 'Position du bien inconnue — renseignez l\'adresse en étape 1.',
      );
    }

    // Clé arrondie à ~100 m : deux biens voisins partagent le même cache
    // plutôt que d'en créer un par estimation.
    final cle = 'dpe_${latitude.toStringAsFixed(3)}_'
        '${longitude.toStringAsFixed(3)}_${rayonKm}_$moisAnterieurs';
    final cache = await DvfDiskCache.read(cle);

    List<DpeRecent> depuisCache(dynamic data) => (data as List? ?? [])
        .map((m) => DpeRecent.fromCacheJson(Map<String, dynamic>.from(m as Map)))
        .whereType<DpeRecent>()
        .toList();

    final fraisCache =
        cache != null && cache.age < fraicheur && !forceReseau;
    if (fraisCache) {
      final liste = depuisCache(cache.data);
      debugPrint('[DPE] ${liste.length} diagnostics servis du cache');
      return DpeMarcheResult(dpe: liste, dateCache: cache.date);
    }

    DpeMarcheResult secours(String motif) {
      if (cache == null) return DpeMarcheResult(erreur: motif);
      final liste = depuisCache(cache.data);
      debugPrint('[DPE] réseau KO ($motif) → cache du ${cache.date}');
      return DpeMarcheResult(
        dpe: liste,
        dateCache: cache.date,
        modeSecours: true,
      );
    }

    try {
      final depuis = DateTime.now().subtract(Duration(days: moisAnterieurs * 30));
      final uri = Uri.parse(_base).replace(queryParameters: {
        'geo_distance': '$longitude,$latitude,${(rayonKm * 1000).round()}',
        'qs': 'date_etablissement_dpe:[${_jour(depuis)} TO *]',
        'select': _champs,
        'sort': '-date_etablissement_dpe',
        'size': limite.toString(),
      });

      final resp = await http.get(uri).timeout(const Duration(seconds: 12));
      if (resp.statusCode != 200) {
        return secours('HTTP ${resp.statusCode}');
      }

      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final lignes = (body['results'] as List?) ?? [];
      final liste = lignes
          .map((l) => DpeRecent.fromAdeme(Map<String, dynamic>.from(l as Map)))
          .whereType<DpeRecent>()
          .where((d) => d.aCoordonnees)
          .toList();

      debugPrint('[DPE] ${liste.length} diagnostics récents dans $rayonKm km');

      // Ne jamais écraser le cache par une réponse vide : une API
      // temporairement muette ne doit pas effacer un relevé valide.
      if (liste.isNotEmpty) {
        await DvfDiskCache.write(
            cle, liste.map((d) => d.toCacheJson()).toList());
      }
      return DpeMarcheResult(dpe: liste);
    } catch (e) {
      debugPrint('[DPE] exception : $e');
      return secours(e.toString());
    }
  }

  static String _jour(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
