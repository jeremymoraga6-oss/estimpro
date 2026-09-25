import 'package:flutter_test/flutter_test.dart';
import 'package:estimpro/models/estimation.dart';

/// Tests du moteur de calcul : logique pure, sans widget ni I/O.
///
/// Couvre les règles corrigées le 15/06/2026 (hiérarchie d'occupation,
/// frais de notaire exacts, prime terrain, cumul d'ajustements).
Estimation _bien({
  String typeId = 'maison',
  bool libreOccupation = true,
  String typeBail = 'Vide',
  String dateFinBail = '',
  bool congeLocataire = false,
  int surfaceTerrain = 0,
  int terrainConstructibleM2 = 0,
  bool parcelleDivisible = false,
}) {
  final now = DateTime(2026, 6, 15);
  return Estimation(
    id: 'test-id',
    reference: 'EST-TEST',
    createdAt: now,
    updatedAt: now,
    dateVisite: now,
    typeId: typeId,
    libreOccupation: libreOccupation,
    typeBail: typeBail,
    dateFinBail: dateFinBail,
    congeLocataire: congeLocataire,
    surfaceTerrain: surfaceTerrain,
    terrainConstructibleM2: terrainConstructibleM2,
    parcelleDivisible: parcelleDivisible,
  );
}

void main() {
  group('decoteOccupation — hiérarchie', () {
    test('bien libre : aucune décote', () {
      expect(_bien().decoteOccupation, 0.0);
    });

    test('bail commercial : -25 %, prioritaire sur tout le reste', () {
      final e = _bien(
        libreOccupation: false,
        typeBail: 'Commercial',
        congeLocataire: true,
        dateFinBail: '01/2026',
      );
      expect(e.decoteOccupation, -25.0);
    });

    test('congé donné : -3 %, sans condition de date', () {
      // Bail se terminant dans longtemps : le congé prime malgré tout.
      final e = _bien(
        libreOccupation: false,
        congeLocataire: true,
        dateFinBail: '01/2030',
      );
      expect(e.decoteOccupation, -3.0);
    });

    test('congé donné sur bail meublé : -3 % (le congé prime)', () {
      final e = _bien(
        libreOccupation: false,
        typeBail: 'Meublé',
        congeLocataire: true,
      );
      expect(e.decoteOccupation, -3.0);
    });

    test('fin de bail sous 12 mois : -6 %', () {
      final e = _bien(libreOccupation: false, dateFinBail: '01/2027');
      expect(e.decoteOccupation, -6.0);
    });

    test('fin de bail lointaine : retombe sur le bail vide, -12 %', () {
      final e = _bien(libreOccupation: false, dateFinBail: '01/2030');
      expect(e.decoteOccupation, -12.0);
    });

    test('date de bail malformée : ignorée, -12 %', () {
      final e = _bien(libreOccupation: false, dateFinBail: 'bientôt');
      expect(e.decoteOccupation, -12.0);
    });

    test('bail meublé : -8 %', () {
      final e = _bien(libreOccupation: false, typeBail: 'Meublé');
      expect(e.decoteOccupation, -8.0);
    });

    test('bail vide standard : -12 %', () {
      expect(_bien(libreOccupation: false).decoteOccupation, -12.0);
    });
  });

  group('labelOccupation — cohérent avec decoteOccupation', () {
    test('libre', () {
      expect(_bien().labelOccupation, 'Bien libre');
    });

    test('chaque cas affiche le pourcentage réellement appliqué', () {
      final cas = [
        _bien(libreOccupation: false, typeBail: 'Commercial'),
        _bien(libreOccupation: false, congeLocataire: true),
        _bien(libreOccupation: false, dateFinBail: '01/2027'),
        _bien(libreOccupation: false, typeBail: 'Meublé'),
        _bien(libreOccupation: false),
      ];
      for (final e in cas) {
        expect(
          e.labelOccupation,
          contains('${e.decoteOccupation.toInt()}%'),
          reason: 'libellé désynchronisé pour ${e.typeBail}',
        );
      }
    });

    test('fin de bail proche est bien nommée (pas confondue avec meublé)', () {
      final e = _bien(
        libreOccupation: false,
        typeBail: 'Meublé',
        dateFinBail: '01/2027',
      );
      expect(e.decoteOccupation, -6.0);
      expect(e.labelOccupation, 'Fin bail ≤ 12 mois (-6%)');
    });
  });

  group('calcFraisNotaire — régime ancien', () {
    test('prix nul ou négatif : zéro', () {
      expect(Estimation.calcFraisNotaire(0), 0);
      expect(Estimation.calcFraisNotaire(-1000), 0);
    });

    test('reste dans une fourchette réaliste de 7 à 9 %', () {
      for (final prix in [150000.0, 250000.0, 350000.0, 500000.0, 900000.0]) {
        final taux = Estimation.calcFraisNotaire(prix) / prix * 100;
        expect(taux, greaterThan(7.0), reason: '$prix € → $taux %');
        expect(taux, lessThan(9.0), reason: '$prix € → $taux %');
      }
    });

    test('croissant avec le prix', () {
      var precedent = 0.0;
      for (final prix in [100000.0, 200000.0, 400000.0, 800000.0]) {
        final frais = Estimation.calcFraisNotaire(prix);
        expect(frais, greaterThan(precedent));
        precedent = frais;
      }
    });

    test('le taux décroît avec le prix (émoluments dégressifs)', () {
      final tauxPetit = Estimation.calcFraisNotaire(100000) / 100000;
      final tauxGros = Estimation.calcFraisNotaire(800000) / 800000;
      expect(tauxGros, lessThan(tauxPetit));
    });

    test('inclut au minimum les DMTO et les débours', () {
      const prix = 300000.0;
      const plancher = prix * 0.0632 + 1300;
      expect(Estimation.calcFraisNotaire(prix), greaterThan(plancher));
    });
  });

  group('coût du crédit', () {
    test('mensualité d\'un prêt amortissable — valeurs de référence', () {
      // Vérifiées independamment : 200 000 € à 3,7 % sur 20 ans = 1 180,58 €/mois
      expect(Estimation.mensualiteCredit(200000, 3.7, 20), closeTo(1180.58, 0.05));
      expect(Estimation.mensualiteCredit(300000, 3.5, 25), closeTo(1501.87, 0.05));
    });

    test('taux nul : simple division du capital', () {
      expect(Estimation.mensualiteCredit(150000, 0, 15), closeTo(833.33, 0.01));
      expect(Estimation.interetsCredit(150000, 0, 15), closeTo(0, 0.01));
    });

    test('capital ou durée nuls : zéro, pas de division par zéro', () {
      expect(Estimation.mensualiteCredit(0, 3.7, 20), 0);
      expect(Estimation.mensualiteCredit(-5000, 3.7, 20), 0);
      expect(Estimation.mensualiteCredit(200000, 3.7, 0), 0);
      expect(Estimation.interetsCredit(0, 3.7, 20), 0);
      expect(Estimation.assuranceCredit(0, 0.34, 20), 0);
    });

    test('intérêts = somme des mensualités moins le capital', () {
      expect(Estimation.interetsCredit(200000, 3.7, 20), closeTo(83338.95, 1));
      expect(Estimation.interetsCredit(300000, 3.5, 25), closeTo(150561.21, 1));
    });

    test('intérêts croissants avec le taux et avec la durée', () {
      final bas = Estimation.interetsCredit(200000, 2.0, 20);
      final haut = Estimation.interetsCredit(200000, 5.0, 20);
      expect(haut, greaterThan(bas));

      final court = Estimation.interetsCredit(200000, 3.7, 15);
      final long = Estimation.interetsCredit(200000, 3.7, 25);
      expect(long, greaterThan(court));
    });

    test('assurance assise sur le capital initial', () {
      expect(Estimation.assuranceCredit(200000, 0.34, 20), closeTo(13600, 0.01));
      // Proportionnelle a la duree comme au taux
      expect(Estimation.assuranceCredit(200000, 0.34, 10), closeTo(6800, 0.01));
      expect(Estimation.assuranceCredit(200000, 0.68, 20), closeTo(27200, 0.01));
    });

    test('taux d\'assurance nul : aucune cotisation', () {
      expect(Estimation.assuranceCredit(200000, 0, 20), 0);
    });
  });

  group('pouvoir d\'achat acquéreur', () {
    test('capitalFinancable est l\'inverse exact de mensualiteCredit', () {
      final m = Estimation.mensualiteCredit(200000, 3.7, 20);
      expect(Estimation.capitalFinancable(m, 3.7, 20), closeTo(200000, 0.5));
    });

    test('la hausse des taux ampute le pouvoir d\'achat', () {
      // Meme mensualite, meme duree : seul le taux change.
      const m = 1180.58;
      final en2021 = Estimation.capitalFinancable(m, 1.2, 20);
      final aujourdhui = Estimation.capitalFinancable(m, 3.7, 20);
      expect(en2021, closeTo(251792, 5));
      expect(aujourdhui, closeTo(200000, 5));
      final perte = (1 - aujourdhui / en2021) * 100;
      expect(perte, closeTo(20.6, 0.2));
    });

    test('taux nul : capital = mensualité × nombre de mois', () {
      expect(Estimation.capitalFinancable(1000, 0, 20), closeTo(240000, 0.01));
    });

    test('mensualité ou durée nulles : zéro', () {
      expect(Estimation.capitalFinancable(0, 3.7, 20), 0);
      expect(Estimation.capitalFinancable(-100, 3.7, 20), 0);
      expect(Estimation.capitalFinancable(1000, 3.7, 0), 0);
    });

    test('revenu nécessaire : mensualité rapportée au plafond HCSF de 35 %', () {
      expect(Estimation.revenuNecessaire(1180.58), closeTo(3373.09, 0.05));
      expect(Estimation.revenuNecessaire(0), 0);
      // Une mensualite de 35 % du revenu correspond exactement au plafond
      expect(Estimation.revenuNecessaire(3500 * 0.35), closeTo(3500, 0.01));
    });
  });

  group('primeTerrain', () {
    test('appartement : jamais de prime', () {
      final e = _bien(typeId: 'appartement', surfaceTerrain: 2000);
      expect(e.primeTerrain, 0);
    });

    test('terrain nu : pas de prime (déjà dans le prix au m²)', () {
      final e = _bien(typeId: 'terrain', surfaceTerrain: 2000);
      expect(e.primeTerrain, 0);
    });

    test('sous le seuil de 500 m² : pas de prime', () {
      expect(_bien(surfaceTerrain: 500).primeTerrain, 0);
      expect(_bien(surfaceTerrain: 300).primeTerrain, 0);
    });

    test('excédent non constructible : 8 €/m²', () {
      final e = _bien(surfaceTerrain: 1500);
      expect(e.primeTerrain, 1000 * 8.0);
    });

    test('excédent constructible : 100 €/m²', () {
      final e = _bien(surfaceTerrain: 1500, terrainConstructibleM2: 400);
      expect(e.primeTerrain, 400 * 100.0 + 600 * 8.0);
    });

    test('parcelle divisible : 280 €/m² sur la part constructible', () {
      final e = _bien(
        surfaceTerrain: 1500,
        terrainConstructibleM2: 400,
        parcelleDivisible: true,
      );
      expect(e.primeTerrain, 400 * 280.0 + 600 * 8.0);
    });

    test('constructible déclaré au-delà de l\'excédent : plafonné', () {
      // 2000 m² déclarés constructibles mais seulement 1000 m² d'excédent.
      final e = _bien(surfaceTerrain: 1500, terrainConstructibleM2: 2000);
      expect(e.primeTerrain, 1000 * 100.0);
    });
  });

  group('fourchettePctAuto', () {
    test('sans comparables : fourchette large (8 %)', () {
      expect(_bien().fourchettePctAuto, 8);
    });
  });

  group('totalPctAjustements', () {
    test('bien neutre et libre : seule la conjoncture s\'applique', () {
      final e = _bien();
      // Le modèle applique -1 % de conjoncture par défaut : c'est voulu, et
      // c'est le seul ajustement actif sur un bien sans caractéristique
      // particulière. Si un autre poste devient non nul par défaut, ce test
      // le signale.
      expect(e.ajustConjoncture, -1.0);
      expect(e.totalPctAjustements, e.ajustConjoncture);
    });

    test('la décote d\'occupation est bien intégrée au cumul', () {
      final libre = _bien();
      final loue = _bien(libreOccupation: false);
      expect(
        loue.totalPctAjustements - libre.totalPctAjustements,
        -12.0,
      );
    });
  });
}
