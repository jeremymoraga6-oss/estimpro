import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Stockage local des réglages de l'app (clé API Anthropic, etc.).
/// Fichier JSON dans le répertoire documents de l'app — pas exporté,
/// pas synchronisé, propre à l'appareil.
class AppSettings {
  AppSettings._();
  static final AppSettings instance = AppSettings._();

  String _anthropicKey = '';
  bool _loaded = false;

  Future<File> get _file async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/settings.json');
  }

  Future<void> load() async {
    if (_loaded) return;
    try {
      final f = await _file;
      if (!await f.exists()) {
        _loaded = true;
        return;
      }
      final data = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      _anthropicKey = (data['anthropicKey'] as String?) ?? '';
    } catch (e) {
      debugPrint('[Settings] load error: $e');
    }
    _loaded = true;
  }

  Future<void> save() async {
    try {
      final f = await _file;
      await f.writeAsString(jsonEncode({'anthropicKey': _anthropicKey}));
    } catch (e) {
      debugPrint('[Settings] save error: $e');
    }
  }

  String get anthropicKey => _anthropicKey;

  Future<void> setAnthropicKey(String key) async {
    _anthropicKey = key.trim();
    await save();
  }

  bool get hasAnthropicKey => _anthropicKey.isNotEmpty;
}
