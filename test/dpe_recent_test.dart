import 'package:flutter_test/flutter_test.dart';
import 'package:estimpro/models/dpe_recent.dart';

/// Lecture des diagnostics ADEME — logique pure, sans réseau.
///
/// Les exemples reprennent la structure réellement renvoyée par l'API
/// (data.ademe.fr, jeu dpe03existant), relevée sur des DPE de Marignier.
void main() {
  Map<String, dynamic> ligneAdeme({
    String? date = '2026-11-10',
    String geo = '46.07763598940416,6.467695947086561',
    dynamic surface = 89.3,
  }) =>
      {
        'date_etablissement_dpe': date,
        'adresse_ban': "95 Rue de la grange de l'île 74970 Marignier",
        'nom_commune_ban': 'Marignier',
        'etiquette_dpe': 'D',
        'surface_habitable_logement': surface,
        'type_batiment': 'maison',
        '_geopoint': geo,
      };

  group('lecture d\'une ligne ADEME', () {
    test('tous les champs sont repris', () {
      final d = DpeRecent.fromAdeme(ligneAdeme())!;
      expect(d.commune, 'Marignier');
      expect(d.etiquette, 'D');
      expect(d.surface, 89.3);
      expect(d.typeBatiment, 'maison');
      expect(d.date, DateTime(2026, 11, 10));
      expect(d.adresse, contains('grange de'));
    });

    test('_geopoint est découpé en latitude puis longitude', () {
      final d = DpeRecent.fromAdeme(ligneAdeme())!;
      expect(d.latitude, closeTo(46.0776, 0.001));
      expect(d.longitude, closeTo(6.4677, 0.001));
      expect(d.aCoordonnees, isTrue);
    });

    test('sans date : écarté, sa fraîcheur est tout l\'intérêt', () {
      expect(DpeRecent.fromAdeme(ligneAdeme(date: null)), isNull);
      expect(DpeRecent.fromAdeme(ligneAdeme(date: 'pas une date')), isNull);
    });

    test('_geopoint absent ou malformé : pas de coordonnées, pas de plantage', () {
      final d = DpeRecent.fromAdeme(ligneAdeme(geo: ''))!;
      expect(d.aCoordonnees, isFalse);
      expect(DpeRecent.fromAdeme(ligneAdeme(geo: 'n/a'))!.aCoordonnees, isFalse);
    });

    test('surface en texte ou absente : tolérée', () {
      expect(DpeRecent.fromAdeme(ligneAdeme(surface: '118'))!.surface, 118);
      expect(DpeRecent.fromAdeme(ligneAdeme(surface: null))!.surface, 0);
    });

    test('étiquette normalisée en majuscule', () {
      final l = ligneAdeme()..['etiquette_dpe'] = 'f';
      expect(DpeRecent.fromAdeme(l)!.etiquette, 'F');
    });

    test('ligne quasiment vide : ne lève pas, hors la date manquante', () {
      expect(DpeRecent.fromAdeme({'date_etablissement_dpe': '2026-01-05'})
          ?.commune, '');
    });
  });

  group('ancienneté', () {
    DpeRecent ilYa(int jours) => DpeRecent(
          adresse: '',
          commune: '',
          date: DateTime.now().subtract(Duration(days: jours)),
        );

    test('libellé en jours puis en mois', () {
      expect(ilYa(0).libelleAge, "aujourd'hui");
      expect(ilYa(1).libelleAge, 'hier');
      expect(ilYa(12).libelleAge, 'il y a 12 jours');
      expect(ilYa(35).libelleAge, 'il y a 1 mois');
      expect(ilYa(180).libelleAge, 'il y a 6 mois');
    });

    test('ageJours reflète la distance à aujourd\'hui', () {
      expect(ilYa(45).ageJours, closeTo(45, 1));
    });
  });

  group('aller-retour cache', () {
    test('tous les champs survivent', () {
      final o = DpeRecent.fromAdeme(ligneAdeme())!;
      final r = DpeRecent.fromCacheJson(o.toCacheJson())!;
      expect(r.adresse, o.adresse);
      expect(r.commune, o.commune);
      expect(r.date, o.date);
      expect(r.etiquette, o.etiquette);
      expect(r.surface, o.surface);
      expect(r.typeBatiment, o.typeBatiment);
      expect(r.latitude, o.latitude);
      expect(r.longitude, o.longitude);
    });

    test('entrée de cache sans date : écartée', () {
      expect(DpeRecent.fromCacheJson({'a': 'x'}), isNull);
    });
  });
}
