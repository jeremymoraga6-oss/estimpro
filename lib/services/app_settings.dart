import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

/// Stockage local des réglages de l'app.
///
/// La clé API Anthropic est stockée dans le Keystore Android / Keychain iOS
/// via [FlutterSecureStorage]. Les autres préférences (dvfCacheVersion, etc.)
/// restent dans un fichier JSON dans le répertoire documents.
///
/// Migration silencieuse : si l'ancien JSON contient encore `anthropicKey`,
/// la valeur est copiée dans le stockage sécurisé puis retirée du JSON.
class AppSettings {
  AppSettings._();
  static final AppSettings instance = AppSettings._();

  // ── Stockage sécurisé ─────────────────────────────────────────────────────
  static const _kApiKeyId = 'anthropic_api_key';
  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // ── État ──────────────────────────────────────────────────────────────────
  String _anthropicKey = '';
  int _dvfCacheVersion = 0;
  bool _loaded = false;

  // ── Fichier JSON (préférences non-sensibles) ──────────────────────────────
  Future<File> get _file async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/settings.json');
  }

  // ── Chargement ────────────────────────────────────────────────────────────

  Future<void> load() async {
    if (_loaded) return;
    try {
      final f = await _file;
      Map<String, dynamic> data = {};
      if (await f.exists()) {
        try {
          data = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        } catch (_) {
          // JSON corrompu — on repart de zéro
        }
      }

      _dvfCacheVersion = (data['dvfCacheVersion'] as int?) ?? 0;

      // 1. Lire la clé depuis le stockage sécurisé
      _anthropicKey = await _secure.read(key: _kApiKeyId) ?? '';

      // 2. Migration silencieuse : ancien JSON → stockage sécurisé
      final legacyKey = (data['anthropicKey'] as String?) ?? '';
      if (legacyKey.isNotEmpty && _anthropicKey.isEmpty) {
        _anthropicKey = legacyKey;
        await _secure.write(key: _kApiKeyId, value: legacyKey);
        debugPrint('[Settings] migrated API key to secure storage');
      }

      // 3. Nettoyer la clé du JSON si elle y figure encore
      if (data.containsKey('anthropicKey')) {
        data.remove('anthropicKey');
        await f.writeAsString(jsonEncode(data));
      }
    } catch (e) {
      debugPrint('[Settings] load error: $e');
    }
    _loaded = true;
  }

  // ── Sauvegarde (préférences non-sensibles uniquement) ─────────────────────

  Future<void> save() async {
    try {
      final f = await _file;
      // Ne stocke PAS la clé API dans le JSON
      await f.writeAsString(jsonEncode({
        'dvfCacheVersion': _dvfCacheVersion,
      }));
    } catch (e) {
      debugPrint('[Settings] save error: $e');
    }
  }

  // ── Clé API Anthropic ─────────────────────────────────────────────────────

  String get anthropicKey => _anthropicKey;

  Future<void> setAnthropicKey(String key) async {
    _anthropicKey = key.trim();
    try {
      if (_anthropicKey.isEmpty) {
        await _secure.delete(key: _kApiKeyId);
      } else {
        await _secure.write(key: _kApiKeyId, value: _anthropicKey);
      }
    } catch (e) {
      debugPrint('[Settings] secure storage write error: $e');
    }
    // Pas d'appel à save() — la clé n'est plus dans le JSON
  }

  bool get hasAnthropicKey => _anthropicKey.isNotEmpty;

  // ── Cache DVF ─────────────────────────────────────────────────────────────

  int get dvfCacheVersion => _dvfCacheVersion;

  Future<void> setDvfCacheVersion(int v) async {
    _dvfCacheVersion = v;
    await save();
  }
}
