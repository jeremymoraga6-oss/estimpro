import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Cache local pour les fichiers CSV DVF par commune+année.
/// Stocké dans le répertoire documents de l'app, valable 30 jours.
///
/// Permet de :
///   1. Réduire les appels réseau (gain perf + data mobile)
///   2. Fonctionner hors-ligne en RDV terrain (refresh des données déjà vues)
///   3. Servir de filet de sécurité si files.data.gouv.fr est down
class DvfCache {
  static const _ttl = Duration(days: 30);

  Future<Directory> get _dir async {
    final docs = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${docs.path}/dvf_cache');
    if (!await cacheDir.exists()) await cacheDir.create(recursive: true);
    return cacheDir;
  }

  String _key(int year, String dep, String insee) => '${year}_${dep}_$insee';

  Future<String?> read(int year, String dep, String insee) async {
    try {
      final f = File('${(await _dir).path}/${_key(year, dep, insee)}.csv');
      if (!await f.exists()) return null;
      final stat = await f.stat();
      // Toujours retourner si les données sont là, mais signale l'âge via debugPrint
      final age = DateTime.now().difference(stat.modified);
      if (age > _ttl) {
        debugPrint('[DVF-cache] expiré (${age.inDays}j) — réutilisé en fallback uniquement');
        return null; // expiré : ne pas servir directement, lecture explicite via readStale
      }
      debugPrint('[DVF-cache] HIT $year/$dep/$insee (${age.inHours}h)');
      return await f.readAsString();
    } catch (_) {
      return null;
    }
  }

  /// Lecture du cache même expiré — utilisé en fallback si le réseau échoue
  Future<String?> readStale(int year, String dep, String insee) async {
    try {
      final f = File('${(await _dir).path}/${_key(year, dep, insee)}.csv');
      if (!await f.exists()) return null;
      final stat = await f.stat();
      final age = DateTime.now().difference(stat.modified);
      debugPrint('[DVF-cache] STALE HIT $year/$dep/$insee (${age.inDays}j)');
      return await f.readAsString();
    } catch (_) {
      return null;
    }
  }

  Future<void> write(int year, String dep, String insee, String csv) async {
    try {
      final f = File('${(await _dir).path}/${_key(year, dep, insee)}.csv');
      await f.writeAsString(csv);
      debugPrint('[DVF-cache] WRITE $year/$dep/$insee (${csv.length} bytes)');
    } catch (e) {
      debugPrint('[DVF-cache] write error: $e');
    }
  }

  /// Nettoie les fichiers de plus de 90 jours pour ne pas remplir le disque
  Future<void> cleanup() async {
    try {
      final dir = await _dir;
      final cutoff = DateTime.now().subtract(const Duration(days: 90));
      int deleted = 0;
      await for (final entity in dir.list()) {
        if (entity is File) {
          final stat = await entity.stat();
          if (stat.modified.isBefore(cutoff)) {
            await entity.delete();
            deleted++;
          }
        }
      }
      if (deleted > 0) debugPrint('[DVF-cache] cleanup: $deleted fichiers > 90j supprimés');
    } catch (_) {}
  }

  /// Taille totale du cache en MB (pour info utilisateur)
  Future<double> sizeMB() async {
    try {
      final dir = await _dir;
      int bytes = 0;
      await for (final entity in dir.list()) {
        if (entity is File) {
          bytes += (await entity.stat()).size;
        }
      }
      return bytes / (1024 * 1024);
    } catch (_) {
      return 0;
    }
  }
}
