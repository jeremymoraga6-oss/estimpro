import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:estimpro/services/crash_reporter.dart';

/// Journal d'erreurs — le comportement en écriture.
///
/// L'implémentation d'origine relisait le fichier entier puis le réécrivait à
/// chaque erreur. Une erreur de build() se répétant à chaque frame, cela
/// signifiait relire et réécrire 256 Ko soixante fois par seconde, et deux
/// écritures concurrentes s'écrasaient mutuellement.
void main() {
  late Directory tmp;

  File journal() => File('${tmp.path}/crash_log.txt');

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('estimpro_crash_test');
    CrashReporter.directoryOverride = tmp;
  });

  tearDown(() {
    CrashReporter.directoryOverride = null;
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  group('écriture', () {
    test('première entrée : le journal est créé', () async {
      await CrashReporter.logEvent('Test', 'première erreur');
      expect(journal().existsSync(), isTrue);
      expect(await CrashReporter.readLog(), contains('première erreur'));
    });

    test('les entrées successives s\'ajoutent, aucune n\'écrase l\'autre', () async {
      await CrashReporter.logEvent('Test', 'erreur A');
      await CrashReporter.logEvent('Test', 'erreur B');
      await CrashReporter.logEvent('Test', 'erreur C');

      final log = await CrashReporter.readLog();
      expect(log, contains('erreur A'));
      expect(log, contains('erreur B'));
      expect(log, contains('erreur C'));
      // Ordre chronologique conservé
      expect(log.indexOf('erreur A'), lessThan(log.indexOf('erreur C')));
    });

    test('30 écritures concurrentes : aucune perdue', () async {
      // Le cas qui cassait : en lecture-réécriture, la plupart de ces entrées
      // disparaissaient. En mode append, chacune s'ajoute.
      await Future.wait([
        for (var i = 0; i < 30; i++)
          CrashReporter.logEvent('Boucle', 'occurrence-$i'),
      ]);

      final log = await CrashReporter.readLog();
      for (var i = 0; i < 30; i++) {
        expect(log, contains('occurrence-$i'), reason: 'entrée $i perdue');
      }
    });

    test('le contexte et la pile sont repris quand ils existent', () async {
      await CrashReporter.logEvent('Manuel', 'message simple');
      final log = await CrashReporter.readLog();
      expect(log, contains('Manuel'));
      expect(log, contains('Error: message simple'));
    });
  });

  group('rotation', () {
    test('sous la taille max : rien n\'est tronqué', () async {
      for (var i = 0; i < 20; i++) {
        await CrashReporter.logEvent('Petit', 'entrée-$i');
      }
      final log = await CrashReporter.readLog();
      expect(log, contains('entrée-0'));
      expect(log, contains('entrée-19'));
    });

    test('au-delà de la taille max : les entrées récentes survivent', () async {
      // Pré-remplit au-delà du seuil de 256 Ko.
      final gros = StringBuffer();
      for (var i = 0; i < 4000; i++) {
        gros
          ..writeln('═══════════════════════════════════════════════')
          ..writeln('[2026-01-01T00:00:00.000] Ancien')
          ..writeln('Error: vieille-entrée-$i')
          ..writeln();
      }
      await journal().writeAsString(gros.toString());
      expect(await journal().length(), greaterThan(256 * 1024));

      await CrashReporter.logEvent('Neuf', 'entrée-la-plus-recente');

      final log = await CrashReporter.readLog();
      expect(log, contains('entrée-la-plus-recente'),
          reason: 'la nouvelle entrée doit toujours être écrite');
      expect(await journal().length(), lessThan(256 * 1024),
          reason: 'le journal doit avoir été tronqué');
      expect(log, isNot(contains('vieille-entrée-0')),
          reason: 'la moitié la plus ancienne est supprimée');
      expect(log, contains('vieille-entrée-3999'),
          reason: 'la moitié la plus récente est conservée');
    });

    test('la troncature coupe sur une frontière d\'entrée', () async {
      final gros = StringBuffer();
      for (var i = 0; i < 4000; i++) {
        gros
          ..writeln('═══════════════════════════════════════════════')
          ..writeln('[2026-01-01T00:00:00.000] Ancien')
          ..writeln('Error: entrée-$i')
          ..writeln();
      }
      await journal().writeAsString(gros.toString());
      await CrashReporter.logEvent('Neuf', 'déclencheur');

      final log = await CrashReporter.readLog();
      // Pas de trace amputée en tête : le journal démarre sur un séparateur.
      expect(log.startsWith('═══'), isTrue);
    });
  });

  group('lecture et purge', () {
    test('journal absent : chaîne vide, pas d\'exception', () async {
      expect(await CrashReporter.readLog(), isEmpty);
    });

    test('clear supprime le journal', () async {
      await CrashReporter.logEvent('Test', 'à effacer');
      expect(journal().existsSync(), isTrue);
      await CrashReporter.clear();
      expect(journal().existsSync(), isFalse);
      expect(await CrashReporter.readLog(), isEmpty);
    });
  });
}
