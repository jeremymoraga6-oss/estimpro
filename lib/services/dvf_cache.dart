import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Une entrée relue depuis le cache disque.
class DvfCacheEntry {
  final dynamic data;
  final DateTime date;
  const DvfCacheEntry(this.data, this.date);

  /// Âge de l'entrée.
  Duration get age => DateTime.now().difference(date);

  /// Au-delà de [DvfDiskCache.fraicheur], l'entrée reste utilisable mais on
  /// tente d'abord le réseau.
  bool get perime => age > DvfDiskCache.fraicheur;
}

/// Cache disque des données DVF.
///
/// Les données DVF ne sont republiées que quelques fois par an : rien
/// n'oblige à les retélécharger à chaque lancement. Les garder sur disque
/// permet surtout de continuer à estimer **sans réseau** — situation courante
/// en fond de vallée ou dans un chalet isolé.
///
/// Stratégie appliquée par les appelants :
/// 1. entrée fraîche (< [fraicheur]) → servie directement, aucun appel réseau ;
/// 2. entrée périmée ou absente → tentative réseau ;
/// 3. réseau en échec → on ressert l'entrée périmée plutôt que rien, en le
///    signalant à l'utilisateur.
///
/// Aucune donnée personnelle ici : uniquement des ventes publiques DVF.
class DvfDiskCache {
  static const _dirName = 'dvf_cache';

  /// Durée au-delà de laquelle on retente le réseau.
  static const fraicheur = Duration(days: 30);

  /// Nombre maximum de communes conservées (les plus anciennes sont purgées).
  static const _maxEntries = 60;

  static Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final d = Directory('${base.path}/$_dirName');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  static String _safeKey(String key) =>
      key.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

  static Future<File> _fileFor(String key) async =>
      File('${(await _dir()).path}/${_safeKey(key)}.json');

  /// Relit une entrée. `null` si absente ou illisible.
  static Future<DvfCacheEntry?> read(String key) async {
    try {
      final f = await _fileFor(key);
      if (!await f.exists()) return null;
      final m = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      final ts = DateTime.tryParse(m['date'] as String? ?? '');
      if (ts == null) return null;
      return DvfCacheEntry(m['data'], ts);
    } catch (e) {
      debugPrint('[DvfCache] lecture $key : $e');
      return null;
    }
  }

  /// Écrit une entrée (temporaire + rename, comme la base estimations).
  static Future<void> write(String key, Object data) async {
    try {
      final f = await _fileFor(key);
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(
        jsonEncode({'date': DateTime.now().toIso8601String(), 'data': data}),
        flush: true,
      );
      await tmp.rename(f.path);
      await _prune();
    } catch (e) {
      debugPrint('[DvfCache] écriture $key : $e');
    }
  }

  /// Garde les [_maxEntries] fichiers les plus récents.
  static Future<void> _prune() async {
    try {
      final files = (await _dir())
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList();
      if (files.length <= _maxEntries) return;
      files.sort((a, b) => a.statSync().modified.compareTo(b.statSync().modified));
      for (final f in files.take(files.length - _maxEntries)) {
        try {
          await f.delete();
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[DvfCache] purge : $e');
    }
  }

  /// Nombre de communes en cache et poids total, pour l'affichage réglages.
  static Future<({int entrees, int octets})> stats() async {
    try {
      final files = (await _dir())
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList();
      var total = 0;
      for (final f in files) {
        total += f.statSync().size;
      }
      return (entrees: files.length, octets: total);
    } catch (_) {
      return (entrees: 0, octets: 0);
    }
  }

  static Future<void> clear() async {
    try {
      final d = await _dir();
      if (await d.exists()) await d.delete(recursive: true);
    } catch (e) {
      debugPrint('[DvfCache] vidage : $e');
    }
  }
}
