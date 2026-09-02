import 'package:flutter_test/flutter_test.dart';
import 'package:estimpro/services/dvf_service.dart';
import 'package:estimpro/services/dvf_cache.dart';

/// Sérialisation du cache DVF : logique pure, sans accès disque.
void main() {
  group('DvfTransaction — aller-retour cache', () {
    const tx = DvfTransaction(
      dateMutation: '2025-04-12',
      valeurFonciere: 385000,
      adresse: '12 route des Alpes',
      codeCommune: '74256',
      nomCommune: 'Reignier-Ésery',
      typeLocal: 'Maison',
      surfaceReelleBati: 110,
      latitude: 46.1322,
      longitude: 6.2861,
    );

    test('conserve tous les champs', () {
      final r = DvfTransaction.fromCacheJson(tx.toCacheJson());
      expect(r.dateMutation, tx.dateMutation);
      expect(r.valeurFonciere, tx.valeurFonciere);
      expect(r.adresse, tx.adresse);
      expect(r.codeCommune, tx.codeCommune);
      expect(r.nomCommune, tx.nomCommune);
      expect(r.typeLocal, tx.typeLocal);
      expect(r.surfaceReelleBati, tx.surfaceReelleBati);
      expect(r.latitude, tx.latitude);
      expect(r.longitude, tx.longitude);
    });

    test('distanceKm n\'est pas persistée (dépend du bien estimé)', () {
      final avecDistance = tx.withDistance(3.2);
      expect(avecDistance.distanceKm, 3.2);
      expect(DvfTransaction.fromCacheJson(avecDistance.toCacheJson()).distanceKm, isNull);
    });

    test('tolère un JSON incomplet sans lever d\'exception', () {
      final r = DvfTransaction.fromCacheJson({'d': '2024-01-01'});
      expect(r.dateMutation, '2024-01-01');
      expect(r.valeurFonciere, 0);
      expect(r.surfaceReelleBati, 0);
    });

    test('accepte des entiers là où des doubles sont attendus', () {
      final r = DvfTransaction.fromCacheJson({'v': 250000, 's': 90, 'lat': 46, 'lon': 6});
      expect(r.valeurFonciere, 250000.0);
      expect(r.surfaceReelleBati, 90.0);
      expect(r.latitude, 46.0);
    });
  });

  group('DvfCacheEntry — fraîcheur', () {
    test('entrée du jour : fraîche', () {
      final e = DvfCacheEntry([], DateTime.now());
      expect(e.perime, isFalse);
    });

    test('entrée juste avant la limite : encore fraîche', () {
      final e = DvfCacheEntry([], DateTime.now().subtract(const Duration(days: 29)));
      expect(e.perime, isFalse);
    });

    test('entrée au-delà de la limite : périmée', () {
      final e = DvfCacheEntry([], DateTime.now().subtract(const Duration(days: 31)));
      expect(e.perime, isTrue);
    });
  });

  group('DvfFetchResult — message de fraîcheur', () {
    DvfFetchResult res({DateTime? dateCache, bool secours = false}) => DvfFetchResult(
          transactions: const [],
          codeInsee: '74256',
          urlUtilisee: '',
          nombreBrut: 0,
          dateCache: dateCache,
          modeSecours: secours,
        );

    test('données réseau : aucun avertissement', () {
      expect(res().avertissementFraicheur, isNull);
    });

    test('cache normal : mentionne le cache, pas le réseau', () {
      final m = res(dateCache: DateTime.now().subtract(const Duration(days: 3)))
          .avertissementFraicheur!;
      expect(m, contains('cache'));
      expect(m, contains('3 jours'));
      expect(m.toLowerCase(), isNot(contains('indisponible')));
    });

    test('mode secours : signale explicitement le réseau', () {
      final m = res(dateCache: DateTime.now().subtract(const Duration(days: 40)), secours: true)
          .avertissementFraicheur!;
      expect(m, contains('Réseau indisponible'));
      expect(m, contains('40 jours'));
    });

    test('accorde correctement hier et aujourd\'hui', () {
      expect(res(dateCache: DateTime.now()).avertissementFraicheur, contains("aujourd'hui"));
      expect(
        res(dateCache: DateTime.now().subtract(const Duration(days: 1, hours: 1)))
            .avertissementFraicheur,
        contains('hier'),
      );
    });
  });
}
