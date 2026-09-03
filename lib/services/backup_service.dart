import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Résultat d'une importation de sauvegarde.
class BackupResult {
  final int estimationsAdded;
  final int estimationsUpdated;
  final int baseLocaleAdded;
  final int baseLocaleUpdated;

  const BackupResult({
    required this.estimationsAdded,
    required this.estimationsUpdated,
    required this.baseLocaleAdded,
    required this.baseLocaleUpdated,
  });

  bool get hasChanges =>
      estimationsAdded > 0 ||
      estimationsUpdated > 0 ||
      baseLocaleAdded > 0 ||
      baseLocaleUpdated > 0;

  @override
  String toString() {
    final parts = <String>[];
    if (estimationsAdded > 0) {
      parts.add('$estimationsAdded estimation${estimationsAdded > 1 ? 's' : ''} ajoutée${estimationsAdded > 1 ? 's' : ''}');
    }
    if (estimationsUpdated > 0) {
      parts.add('$estimationsUpdated estimation${estimationsUpdated > 1 ? 's' : ''} mise${estimationsUpdated > 1 ? 's' : ''} à jour');
    }
    if (baseLocaleAdded > 0) {
      parts.add('$baseLocaleAdded référence${baseLocaleAdded > 1 ? 's' : ''} locale${baseLocaleAdded > 1 ? 's' : ''} ajoutée${baseLocaleAdded > 1 ? 's' : ''}');
    }
    if (baseLocaleUpdated > 0) {
      parts.add('$baseLocaleUpdated référence${baseLocaleUpdated > 1 ? 's' : ''} locale${baseLocaleUpdated > 1 ? 's' : ''} mise${baseLocaleUpdated > 1 ? 's' : ''} à jour');
    }
    if (parts.isEmpty) return 'Aucune modification — données déjà à jour.';
    return '${parts.join(', ')}.';
  }
}

class BackupService {
  // ── Export ──────────────────────────────────────────────────────────────────

  /// Exporte estimations + base_locale + settings (SANS clé API) dans un zip
  /// daté, puis partage via la share sheet.
  /// Retourne le chemin du zip créé, ou null en cas d'erreur.
  static Future<String?> exportBackup() async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final tmpDir = await getTemporaryDirectory();
      final now = DateTime.now();

      final datePart =
          '${now.year.toString().padLeft(4, '0')}'
          '${now.month.toString().padLeft(2, '0')}'
          '${now.day.toString().padLeft(2, '0')}'
          '_'
          '${now.hour.toString().padLeft(2, '0')}'
          '${now.minute.toString().padLeft(2, '0')}';

      final zipPath = '${tmpDir.path}/estimpro_backup_$datePart.zip';

      // Lire les fichiers source
      final estimationsFile = File('${docsDir.path}/estimations.json');
      final baseLocaleFile = File('${docsDir.path}/base_locale.json');
      final settingsFile = File('${docsDir.path}/settings.json');

      final estimationsContent = await estimationsFile.exists()
          ? await estimationsFile.readAsString()
          : '[]';

      final baseLocaleContent = await baseLocaleFile.exists()
          ? await baseLocaleFile.readAsString()
          : '[]';

      // Settings : retirer la clé anthropicKey avant export
      String settingsContent = '{}';
      if (await settingsFile.exists()) {
        try {
          final raw = await settingsFile.readAsString();
          final Map<String, dynamic> settingsMap =
              Map<String, dynamic>.from(jsonDecode(raw) as Map);
          settingsMap['anthropicKey'] = '';
          settingsContent = jsonEncode(settingsMap);
        } catch (_) {
          settingsContent = '{}';
        }
      }

      // Métadonnées de la sauvegarde
      final metaContent = jsonEncode({
        'version': 1,
        'exportedAt': now.toIso8601String(),
        'appVersion': '1.3.1',
      });

      // Zip construit en mémoire : pas de fichiers temporaires intermédiaires.
      final arch = Archive();

      void addString(String name, String content) {
        final bytes = utf8.encode(content);
        arch.addFile(ArchiveFile(name, bytes.length, bytes));
      }

      addString('estimations.json', estimationsContent);
      addString('base_locale.json', baseLocaleContent);
      addString('settings.json', settingsContent);
      addString('backup_meta.json', metaContent);

      final zipBytes = ZipEncoder().encode(arch);
      if (zipBytes == null) return null;

      final zipFile = File(zipPath);
      await zipFile.writeAsBytes(zipBytes);

      // Partager
      final dateLabel =
          '${now.year.toString().padLeft(4, '0')}'
          '${now.month.toString().padLeft(2, '0')}'
          '${now.day.toString().padLeft(2, '0')}';

      await Share.shareXFiles(
        [XFile(zipPath, mimeType: 'application/zip')],
        text: 'Sauvegarde EstimPro $dateLabel',
        subject: 'EstimPro — Sauvegarde $dateLabel',
      );

      return zipPath;
    } catch (_) {
      return null;
    }
  }

  // ── Import ──────────────────────────────────────────────────────────────────

  /// Importe depuis un zip sélectionné par l'utilisateur via FilePicker.
  /// Fusionne intelligemment les données (priorité à la version la plus récente).
  /// Retourne un [BackupResult] décrivant les changements, ou null en cas d'erreur.
  static Future<BackupResult?> importBackup() async {
    try {
      // 1. Sélectionner le fichier zip
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );
      if (result == null || result.files.isEmpty) return null;

      final pickedPath = result.files.single.path;
      if (pickedPath == null) return null;

      final zipFile = File(pickedPath);
      if (!await zipFile.exists()) return null;

      // 2. Décoder le zip
      final bytes = await zipFile.readAsBytes();
      final Archive archive;
      try {
        archive = ZipDecoder().decodeBytes(bytes);
      } catch (_) {
        return null;
      }

      // Extraire le contenu des fichiers du zip
      String? estimationsJson;
      String? baseLocaleJson;
      String? settingsJson;

      for (final file in archive) {
        if (!file.isFile) continue;
        final content = utf8.decode(file.content as List<int>, allowMalformed: true);
        switch (file.name) {
          case 'estimations.json':
            estimationsJson = content;
            break;
          case 'base_locale.json':
            baseLocaleJson = content;
            break;
          case 'settings.json':
            settingsJson = content;
            break;
        }
      }

      final docsDir = await getApplicationDocumentsDirectory();

      // 3. Fusionner les estimations
      int estimationsAdded = 0;
      int estimationsUpdated = 0;

      if (estimationsJson != null) {
        try {
          final backupList = (jsonDecode(estimationsJson) as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();

          // Charger les estimations locales actuelles
          final localFile = File('${docsDir.path}/estimations.json');
          List<Map<String, dynamic>> localList = [];
          if (await localFile.exists()) {
            try {
              localList = (jsonDecode(await localFile.readAsString()) as List)
                  .map((e) => Map<String, dynamic>.from(e as Map))
                  .toList();
            } catch (_) {
              localList = [];
            }
          }

          // Index local par id
          final localById = <String, Map<String, dynamic>>{};
          for (final item in localList) {
            final id = item['id'] as String?;
            if (id != null) localById[id] = item;
          }

          for (final backupItem in backupList) {
            final id = backupItem['id'] as String?;
            if (id == null) continue;

            final backupUpdatedAtStr = backupItem['updatedAt'] as String?;
            final backupUpdatedAt = backupUpdatedAtStr != null
                ? DateTime.tryParse(backupUpdatedAtStr)
                : null;

            if (!localById.containsKey(id)) {
              // Pas dans la base locale : ajouter
              localById[id] = backupItem;
              estimationsAdded++;
            } else {
              // Déjà présent : comparer updatedAt
              final localItem = localById[id]!;
              final localUpdatedAtStr = localItem['updatedAt'] as String?;
              final localUpdatedAt = localUpdatedAtStr != null
                  ? DateTime.tryParse(localUpdatedAtStr)
                  : null;

              if (backupUpdatedAt != null &&
                  (localUpdatedAt == null ||
                      backupUpdatedAt.isAfter(localUpdatedAt))) {
                localById[id] = backupItem;
                estimationsUpdated++;
              }
            }
          }

          // Sauvegarder le résultat fusionné (trié par updatedAt décroissant)
          final merged = localById.values.toList()
            ..sort((a, b) {
              final aStr = a['updatedAt'] as String? ?? '';
              final bStr = b['updatedAt'] as String? ?? '';
              return bStr.compareTo(aStr);
            });

          await localFile.writeAsString(jsonEncode(merged));
        } catch (_) {
          // Fusion estimations échouée — on continue avec les autres
        }
      }

      // 4. Fusionner la base locale
      int baseLocaleAdded = 0;
      int baseLocaleUpdated = 0;

      if (baseLocaleJson != null) {
        try {
          final backupList = (jsonDecode(baseLocaleJson) as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();

          final localFile = File('${docsDir.path}/base_locale.json');
          List<Map<String, dynamic>> localList = [];
          if (await localFile.exists()) {
            try {
              localList = (jsonDecode(await localFile.readAsString()) as List)
                  .map((e) => Map<String, dynamic>.from(e as Map))
                  .toList();
            } catch (_) {
              localList = [];
            }
          }

          // Index local par id
          final localById = <String, Map<String, dynamic>>{};
          for (final item in localList) {
            final id = item['id'] as String?;
            if (id != null) localById[id] = item;
          }

          for (final backupItem in backupList) {
            final id = backupItem['id'] as String?;
            if (id == null) continue;

            final backupDateVenteStr = backupItem['dateVente'] as String? ?? '';

            if (!localById.containsKey(id)) {
              localById[id] = backupItem;
              baseLocaleAdded++;
            } else {
              // Comparer dateVente lexicographiquement (ISO8601 — suffisant)
              final localItem = localById[id]!;
              final localDateVenteStr = localItem['dateVente'] as String? ?? '';

              if (backupDateVenteStr.compareTo(localDateVenteStr) > 0) {
                localById[id] = backupItem;
                baseLocaleUpdated++;
              }
            }
          }

          // Sauvegarder la base locale fusionnée (triée par dateVente décroissante)
          final merged = localById.values.toList()
            ..sort((a, b) {
              final aStr = a['dateVente'] as String? ?? '';
              final bStr = b['dateVente'] as String? ?? '';
              return bStr.compareTo(aStr);
            });

          await localFile.writeAsString(jsonEncode(merged));
        } catch (_) {
          // Fusion base locale échouée — on continue
        }
      }

      // 5. Fusionner les settings (sans écraser anthropicKey)
      if (settingsJson != null) {
        try {
          final backupSettings =
              Map<String, dynamic>.from(jsonDecode(settingsJson) as Map);

          final localFile = File('${docsDir.path}/settings.json');
          Map<String, dynamic> localSettings = {};
          if (await localFile.exists()) {
            try {
              localSettings = Map<String, dynamic>.from(
                  jsonDecode(await localFile.readAsString()) as Map);
            } catch (_) {
              localSettings = {};
            }
          }

          // Conserver la clé API locale
          final localKey = localSettings['anthropicKey'];

          // Fusionner les clés du backup dans les settings locaux
          for (final entry in backupSettings.entries) {
            if (entry.key == 'anthropicKey') continue;
            localSettings[entry.key] = entry.value;
          }

          // Restaurer la clé locale (ne jamais l'écraser)
          if (localKey != null) {
            localSettings['anthropicKey'] = localKey;
          }

          await localFile.writeAsString(jsonEncode(localSettings));
        } catch (_) {
          // Fusion settings échouée — on continue
        }
      }

      return BackupResult(
        estimationsAdded: estimationsAdded,
        estimationsUpdated: estimationsUpdated,
        baseLocaleAdded: baseLocaleAdded,
        baseLocaleUpdated: baseLocaleUpdated,
      );
    } catch (_) {
      return null;
    }
  }
}
