import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:estimpro/models/estimation.dart';
import 'package:estimpro/services/database_service.dart';

/// Tests de la persistance — le code qui pouvait effacer toutes les
/// estimations sans avertir.
///
/// Trois garanties sont vérifiées ici :
/// 1. un fichier illisible est mis en quarantaine, jamais écrasé ;
/// 2. l'écriture est atomique (temporaire + rename) ;
/// 3. deux sauvegardes concurrentes ne s'écrasent pas mutuellement.
void main() {
  late Directory tmp;
  final db = DatabaseService();

  Estimation bien(String id, {DateTime? updated}) {
    final now = updated ?? DateTime(2026, 9, 2);
    return Estimation(
      id: id,
      reference: 'EST-$id',
      createdAt: now,
      updatedAt: now,
      dateVisite: now,
    );
  }

  File fichier() => File('${tmp.path}/estimations.json');

  List<File> quarantaines() => tmp
      .listSync()
      .whereType<File>()
      .where((f) => f.path.contains('.corrupt-'))
      .toList();

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('estimpro_db_test');
    DatabaseService.directoryOverride = tmp;
    DatabaseService.lastCorruption = null;
  });

  tearDown(() {
    DatabaseService.directoryOverride = null;
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  group('lecture', () {
    test('fichier absent : liste vide, aucune erreur', () async {
      expect(await db.loadAll(), isEmpty);
    });

    test('fichier vide : liste vide', () async {
      await fichier().writeAsString('');
      expect(await db.loadAll(), isEmpty);
    });

    test('aller-retour : ce qui est écrit est relu', () async {
      await db.saveEstimation(bien('a'));
      final lu = await db.loadAll();
      expect(lu, hasLength(1));
      expect(lu.first.id, 'a');
      expect(lu.first.reference, 'EST-a');
    });

    test('tri par date de mise à jour décroissante', () async {
      await db.saveEstimation(bien('vieux', updated: DateTime(2026, 1, 1)));
      await db.saveEstimation(bien('recent', updated: DateTime(2026, 8, 1)));
      final lu = await db.loadAll();
      expect(lu.map((e) => e.id).toList(), ['recent', 'vieux']);
    });
  });

  group('corruption — aucune destruction silencieuse', () {
    test('JSON illisible : mis en quarantaine, pas supprimé', () async {
      await fichier().writeAsString('{ ceci n est pas du JSON');

      final lu = await db.loadAll();

      expect(lu, isEmpty, reason: 'la lecture doit dégrader proprement');
      final q = quarantaines();
      expect(q, hasLength(1), reason: 'le fichier fautif doit être conservé');
      expect(q.first.readAsStringSync(), '{ ceci n est pas du JSON');
      expect(DatabaseService.lastCorruption, isNotNull,
          reason: 'la corruption doit être signalable à l\'utilisateur');
    });

    test('sauvegarde après corruption : les données d\'origine survivent',
        () async {
      // Scénario réel : le fichier est corrompu, l'app redémarre et
      // enregistre une nouvelle estimation. L'ancien contenu ne doit pas
      // disparaître pour autant.
      await fichier().writeAsString('][ corrompu');

      await db.saveEstimation(bien('nouveau'));

      expect(quarantaines(), hasLength(1));
      expect(quarantaines().first.readAsStringSync(), '][ corrompu');
      final lu = await db.loadAll();
      expect(lu.map((e) => e.id), ['nouveau']);
    });

    test('JSON valide mais structure inattendue : quarantaine aussi', () async {
      await fichier().writeAsString(jsonEncode({'pas': 'une liste'}));
      expect(await db.loadAll(), isEmpty);
      expect(quarantaines(), hasLength(1));
    });
  });

  group('écriture atomique', () {
    test('aucun fichier temporaire ne subsiste', () async {
      await db.saveEstimation(bien('a'));
      final restes =
          tmp.listSync().where((f) => f.path.endsWith('.tmp')).toList();
      expect(restes, isEmpty);
    });

    test('le fichier final est du JSON relisible', () async {
      await db.saveEstimation(bien('a'));
      final brut = jsonDecode(await fichier().readAsString());
      expect(brut, isA<List>());
      expect((brut as List).single['id'], 'a');
    });
  });

  group('écritures concurrentes', () {
    test('20 sauvegardes en parallèle : aucune perdue', () async {
      // Sans sérialisation, ces read-modify-write s'entrelacent et la
      // plupart des estimations disparaissent.
      await Future.wait([
        for (var i = 0; i < 20; i++) db.saveEstimation(bien('id$i')),
      ]);

      final lu = await db.loadAll();
      expect(lu, hasLength(20));
      expect(lu.map((e) => e.id).toSet(),
          {for (var i = 0; i < 20; i++) 'id$i'});
    });

    test('suppressions et sauvegardes mêlées restent cohérentes', () async {
      await Future.wait([
        for (var i = 0; i < 10; i++) db.saveEstimation(bien('id$i')),
      ]);

      await Future.wait([
        db.delete('id0'),
        db.saveEstimation(bien('id10')),
        db.delete('id1'),
      ]);

      final ids = (await db.loadAll()).map((e) => e.id).toSet();
      expect(ids, isNot(contains('id0')));
      expect(ids, isNot(contains('id1')));
      expect(ids, contains('id10'));
      expect(ids, hasLength(9));
    });
  });

  group('mise à jour et suppression', () {
    test('ré-enregistrer un même id remplace au lieu de dupliquer', () async {
      await db.saveEstimation(bien('a'));
      await db.saveEstimation(
          bien('a', updated: DateTime(2026, 12, 25)).copyWith(commune: 'Bonne'));

      final lu = await db.loadAll();
      expect(lu, hasLength(1));
      expect(lu.first.commune, 'Bonne');
    });

    test('supprimer un id absent ne casse rien', () async {
      await db.saveEstimation(bien('a'));
      await db.delete('inexistant');
      expect(await db.loadAll(), hasLength(1));
    });

    test('loadById retrouve, ou renvoie null', () async {
      await db.saveEstimation(bien('a'));
      expect((await db.loadById('a'))?.reference, 'EST-a');
      expect(await db.loadById('zzz'), isNull);
    });
  });
}
