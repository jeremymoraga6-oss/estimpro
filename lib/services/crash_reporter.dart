import 'dart:async';
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
  }) async {
    try {
      final file = await _logFile();
      final entry = StringBuffer()
        ..writeln('═══════════════════════════════════════════════')
        ..writeln('[${DateTime.now().toIso8601String()}] $type')
        ..writeln('Error: $error');
      if (context.isNotEmpty) entry.writeln('Context: $context');
      if (stack.isNotEmpty) {
        entry
          ..writeln('Stack:')
          ..writeln(stack);
      }
      entry.writeln();

      // Tronque si trop gros
      var existing = '';
      if (await file.exists()) {
        final size = await file.length();
        if (size < _maxBytes) {
          existing = await file.readAsString();
        } else {
          // Garde la moitié la plus récente
          final raw = await file.readAsString();
          existing = raw.substring(raw.length ~/ 2);
        }
      }
      await file.writeAsString(existing + entry.toString());
      debugPrint('[CrashReporter] logged $type');
    } catch (e) {
      debugPrint('[CrashReporter] failed: $e');
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
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_filename');
  }
}
