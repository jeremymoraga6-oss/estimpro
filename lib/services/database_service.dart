import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/estimation.dart';

/// Persistance des estimations (fichier JSON unique).
///
/// Garanties :
/// - **Écriture atomique** : on écrit dans un `.tmp` puis on `rename()`. Un kill
///   de l'app en cours d'écriture laisse l'ancien fichier intact au lieu d'un
///   fichier tronqué.
/// - **Aucune destruction silencieuse** : un JSON illisible est mis en
///   quarantaine (`.corrupt-<timestamp>`) avant toute réécriture. Les données
///   restent récupérables et [lastCorruption] permet d'alerter l'utilisateur.
/// - **Écritures sérialisées** : deux sauvegardes concurrentes ne peuvent plus
///   s'entrelacer (read-modify-write) et s'écraser mutuellement.
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  /// Chemin du dernier fichier mis en quarantaine, si corruption détectée.
  /// Non nul = des données ont été isolées et méritent d'être signalées.
  static String? lastCorruption;

  /// Redirige le stockage vers un autre dossier — réservé aux tests, qui
  /// n'ont pas accès au répertoire documents de l'app.
  @visibleForTesting
  static Directory? directoryOverride;

  Future<File> get _file async {
    final dir = directoryOverride ?? await getApplicationDocumentsDirectory();
    return File('${dir.path}/estimations.json');
  }

  // ── Sérialisation des écritures ────────────────────────────────────────────

  Future<void> _queue = Future<void>.value();

  /// Enchaîne [action] derrière les écritures déjà en cours.
  Future<T> _serialized<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _queue = _queue.then((_) async {
      try {
        completer.complete(await action());
      } catch (e, s) {
        completer.completeError(e, s);
      }
    });
    return completer.future;
  }

  // ── Lecture ────────────────────────────────────────────────────────────────

  /// Décode le fichier. Lève une exception si le contenu est illisible —
  /// c'est volontaire : l'appelant doit décider quoi faire, jamais écraser.
  Future<List<Estimation>> _decode(File f) async {
    if (!await f.exists()) return [];
    final raw = await f.readAsString();
    if (raw.trim().isEmpty) return [];
    final data = jsonDecode(raw) as List;
    return data
        .map((m) => Estimation.fromMap(Map<String, dynamic>.from(m)))
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  /// Met le fichier fautif de côté au lieu de le perdre, puis repart à vide.
  Future<void> _quarantine(File f, Object error) async {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final dest = '${f.path}.corrupt-$stamp';
    try {
      await f.rename(dest);
      lastCorruption = dest;
      debugPrint('[DB] fichier illisible ($error) — mis en quarantaine : $dest');
    } catch (e) {
      debugPrint('[DB] quarantaine impossible : $e');
    }
  }

  /// Charge toutes les estimations.
  ///
  /// Renvoie `[]` si le fichier est absent **ou** illisible — mais dans ce
  /// second cas le fichier d'origine est préalablement mis en quarantaine,
  /// jamais écrasé.
  Future<List<Estimation>> loadAll() async {
    final f = await _file;
    try {
      return await _decode(f);
    } catch (e) {
      await _quarantine(f, e);
      return [];
    }
  }

  Future<Estimation?> loadById(String id) async {
    final all = await loadAll();
    for (final e in all) {
      if (e.id == id) return e;
    }
    return null;
  }

  // ── Écriture ───────────────────────────────────────────────────────────────

  /// Écrit via fichier temporaire + `rename()` (atomique sur le même volume).
  Future<void> _writeAtomic(File f, List<Estimation> all) async {
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(
      jsonEncode(all.map((x) => x.toMap()).toList()),
      flush: true,
    );
    await tmp.rename(f.path);
  }

  /// Lit la liste courante en vue d'une modification, en mettant le fichier
  /// en quarantaine s'il est illisible (pour ne rien détruire).
  Future<List<Estimation>> _readForUpdate(File f) async {
    try {
      return await _decode(f);
    } catch (e) {
      await _quarantine(f, e);
      return [];
    }
  }

  Future<void> saveEstimation(Estimation e) => _serialized(() async {
        final f = await _file;
        final all = await _readForUpdate(f);
        final idx = all.indexWhere((x) => x.id == e.id);
        if (idx >= 0) {
          all[idx] = e;
        } else {
          all.insert(0, e);
        }
        await _writeAtomic(f, all);
      });

  Future<void> delete(String id) => _serialized(() async {
        final f = await _file;
        final all = await _readForUpdate(f);
        all.removeWhere((e) => e.id == id);
        await _writeAtomic(f, all);
      });
}
