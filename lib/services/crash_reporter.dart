import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

/// Logger d'erreurs local — capture les exceptions Flutter et les écrit dans
/// un fichier consultable / partageable depuis le profil.
///
/// Pas de dépendance Firebase : tout reste sur l'appareil, l'agent décide
/// quand envoyer le rapport (RGPD-friendly).
class CrashReporter {
  static const _filename = 'crash_log.txt';
  static const _maxBytes = 256 * 1024; // 256 Ko, on tronque ensuite
  static const _separateur = '═══════════════════════════════════════════════';

  /// Redirige le journal vers un autre dossier — réservé aux tests.
  @visibleForTesting
  static Directory? directoryOverride;

  // File d'écriture. `writeAsString` en mode append perd des entrées dès que
  // deux appels se chevauchent — vérifié : 30 appels concurrents ne laissent
  // qu'une seule ligne. Or c'est exactement le cas d'usage du journal, une
  // erreur de build() se répétant à chaque frame. On sérialise donc, comme
  // pour la base des estimations.
  static Future<void> _queue = Future<void>.value();

  static Future<void> _serialized(Future<void> Function() action) {
    final completer = Completer<void>();
    _queue = _queue.then((_) async {
      try {
        await action();
        completer.complete();
      } catch (e, s) {
        completer.completeError(e, s);
      }
    });
    return completer.future;
  }

  /// À appeler depuis main() avant runApp().
  /// Wrappe l'app dans une zone protégée et installe les hooks d'erreur.
  static void install(void Function() runner) {
    WidgetsFlutterBinding.ensureInitialized();

    // Erreurs framework Flutter (build, layout, paint…)
    final defaultOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      defaultOnError?.call(details);
      _logSync(
        type: 'FlutterError',
        error: details.exceptionAsString(),
        stack: details.stack?.toString() ?? '',
        context: details.context?.toString() ?? '',
      );
    };

    // Erreurs natives platform (canal de plateforme)
    PlatformDispatcher.instance.onError = (error, stack) {
      _logSync(
        type: 'PlatformError',
        error: error.toString(),
        stack: stack.toString(),
      );
      return true;
    };

    // Toutes les erreurs async non capturées
    runZonedGuarded(runner, (error, stack) {
      _logSync(
        type: 'ZoneError',
        error: error.toString(),
        stack: stack.toString(),
      );
    });
  }

  /// Log synchrone (utilisé depuis les handlers, sans await).
  static void _logSync({
    required String type,
    required String error,
    String stack = '',
    String context = '',
  }) {
    // Fire-and-forget — on ne veut surtout pas bloquer l'erreur
    _writeLog(type: type, error: error, stack: stack, context: context)
        .catchError((e) {
      debugPrint('[CrashReporter] write failed: $e');
    });
  }

  static Future<void> _writeLog({
    required String type,
    required String error,
    String stack = '',
    String context = '',
  }) =>
      _serialized(() async {
    try {
      final file = await _logFile();
      final entry = StringBuffer()
        ..writeln(_separateur)
        ..writeln('[${DateTime.now().toIso8601String()}] $type')
        ..writeln('Error: $error');
      if (context.isNotEmpty) entry.writeln('Context: $context');
      if (stack.isNotEmpty) {
        entry
          ..writeln('Stack:')
          ..writeln(stack);
      }
      entry.writeln();

      // Rotation, opération rare : seulement quand le fichier dépasse la
      // taille max, au lieu d'une relecture complète à chaque écriture.
      if (await file.exists() && await file.length() > _maxBytes) {
        await _rotate(file);
      }

      // Ajout en fin de fichier plutôt que relecture puis réécriture
      // intégrale : une erreur de build() se répétant à chaque frame,
      // l'ancienne approche réécrivait 256 Ko soixante fois par seconde.
      // La file d'écriture ci-dessus garantit qu'aucune entrée ne se perd.
      await file.writeAsString(
        entry.toString(),
        mode: FileMode.append,
        flush: true,
      );
      debugPrint('[CrashReporter] logged $type');
    } catch (e) {
      debugPrint('[CrashReporter] failed: $e');
    }
  });

  /// Ne conserve que la fin du journal, en coupant sur une frontière d'entrée
  /// pour ne pas laisser une trace amputée en tête.
  ///
  /// Le raisonnement est en **octets** : le séparateur est composé de « ═ »,
  /// qui pèse 3 octets par caractère. Couper à la moitié des caractères
  /// laissait un fichier encore largement au-dessus du plafond.
  static Future<void> _rotate(File file) async {
    try {
      final raw = await file.readAsString();
      final bytes = utf8.encode(raw);
      const cible = _maxBytes ~/ 2;
      if (bytes.length <= cible) return;

      var queue = utf8.decode(
        bytes.sublist(bytes.length - cible),
        allowMalformed: true,
      );
      final frontiere = queue.indexOf(_separateur);
      if (frontiere != -1) queue = queue.substring(frontiere);

      await file.writeAsString(queue, flush: true);
      debugPrint('[CrashReporter] journal tronqué : '
          '${bytes.length} → ${utf8.encode(queue).length} octets');
    } catch (e) {
      debugPrint('[CrashReporter] rotation impossible : $e');
    }
  }

  /// Log manuel d'un événement (utile pour tracer des cas edge sans crash).
  static Future<void> logEvent(String type, String message) =>
      _writeLog(type: type, error: message);

  /// Lit le contenu complet du log (pour affichage / partage).
  static Future<String> readLog() async {
    try {
      final file = await _logFile();
      if (!await file.exists()) return '';
      return await file.readAsString();
    } catch (_) {
      return '';
    }
  }

  /// Vide le log.
  static Future<void> clear() async {
    try {
      final file = await _logFile();
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  static Future<File> _logFile() async {
    final dir = directoryOverride ?? await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_filename');
  }
}
