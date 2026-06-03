import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'app_settings.dart';
import 'package:http/http.dart' as http;

/// Résultat de la détection des matériaux de construction par vision IA.
class MateriauxResult {
  /// État de la façade : 'Bon' | 'Moyen' | 'À refaire'
  final String? facade;

  /// État de la toiture : 'Bon' | 'Moyen' | 'À refaire'
  final String? toiture;

  /// Types de menuiseries détectés : sous-ensemble de ['PVC', 'Bois', 'Alu', 'Mixte']
  final List<String> menuiseriesType;

  /// Vitrage estimé : sous-ensemble de ['Simple', 'Double', 'Triple']
  final List<String> vitrage;

  /// Matériau de façade en clair (ex: "enduit crépi", "pierre apparente", "brique")
  final String? facadeMatiere;

  /// Matériau de toiture en clair (ex: "tuiles plates", "ardoises", "zinc")
  final String? toitureMatiere;

  /// Réponse brute du modèle (pour debug)
  final String rawResponse;

  const MateriauxResult({
    this.facade,
    this.toiture,
    required this.menuiseriesType,
    required this.vitrage,
    this.facadeMatiere,
    this.toitureMatiere,
    required this.rawResponse,
  });

  bool get hasData =>
      facade != null ||
      toiture != null ||
      menuiseriesType.isNotEmpty ||
      vitrage.isNotEmpty;
}

/// Service de détection des matériaux de construction via Claude Vision.
///
/// Envoie une photo de la façade à l'API Claude Messages avec un message
/// structuré. Requiert une clé Anthropic dans AppSettings.
class MateriauxScanService {
  static const _endpoint = 'https://api.anthropic.com/v1/messages';
  static const _model = 'claude-sonnet-4-6';

  static const _prompt = '''Tu es un expert en estimation immobilière pour des maisons individuelles en France.
Analyse cette photo de l'extérieur de la maison et identifie les matériaux visibles.
Réponds UNIQUEMENT en JSON strict (aucun texte autour, pas de markdown).

{
  "facade_etat": "Bon" | "Moyen" | "À refaire",
  "facade_matiere": "description courte du matériau visible (ex: enduit crépi, pierre naturelle, brique, bardage bois, bardage métal)",
  "toiture_etat": "Bon" | "Moyen" | "À refaire" | null,
  "toiture_matiere": "description courte si visible (ex: tuiles plates terre cuite, ardoises naturelles, zinc, bac acier, toiture terrasse)" | null,
  "menuiseries_type": ["PVC"] | ["Bois"] | ["Alu"] | ["Mixte"] | [],
  "vitrage_estime": ["Double"] | ["Simple"] | [],
  "notes": "observation courte si utile (optionnel)" | null
}

Règles :
- facade_etat : "Bon" = propre, sans fissures ; "Moyen" = traces, légères fissures ou peinture vieillie ; "À refaire" = fissures importantes, ravalement nécessaire
- toiture_etat : "Bon" = aspect soigné, pas de tuile manquante visible ; "Moyen" = quelques irrégularités ; "À refaire" = dégâts visibles, mousse importante
- menuiseries_type : déduis depuis la couleur et le profil des fenêtres visibles (PVC blanc généralement, Alu gris métallique, Bois teinte naturelle/peinte)
- vitrage_estime : "Double" si les fenêtres semblent récentes (post-2000) ou ont des profilés épais ; "Simple" si très anciennes ; si incertain, laisse []
- Si la toiture n'est pas du tout visible, mets null pour les champs toiture
- Sois concis, factuel, ne devine pas ce qui n'est pas visible''';

  Future<MateriauxResult> analyzeImage(String imagePath) async {
    final key = AppSettings.instance.anthropicKey;
    if (key.isEmpty) {
      return MateriauxResult(
        menuiseriesType: const [],
        vitrage: const [],
        rawResponse: 'no_api_key',
      );
    }

    // Lecture + encodage base64 de l'image
    final bytes = await File(imagePath).readAsBytes();
    final b64 = base64Encode(bytes);

    // Détermination du type MIME depuis l'extension
    final ext = imagePath.split('.').last.toLowerCase();
    final mimeType = ext == 'png'
        ? 'image/png'
        : ext == 'webp'
            ? 'image/webp'
            : 'image/jpeg';

    try {
      final resp = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'x-api-key': key,
              'anthropic-version': '2023-06-01',
              'content-type': 'application/json',
            },
            body: jsonEncode({
              'model': _model,
              'max_tokens': 512,
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {
                      'type': 'image',
                      'source': {
                        'type': 'base64',
                        'media_type': mimeType,
                        'data': b64,
                      },
                    },
                    {
                      'type': 'text',
                      'text': _prompt,
                    },
                  ],
                },
              ],
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (resp.statusCode != 200) {
        debugPrint('[Materiaux] API error ${resp.statusCode}: ${resp.body}');
        return MateriauxResult(
          menuiseriesType: const [],
          vitrage: const [],
          rawResponse: resp.body,
        );
      }

      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final raw = (body['content'] as List).first['text'] as String;

      // Tolérance markdown : retire ```json ... ```
      final clean =
          raw.replaceAll(RegExp(r'^```(?:json)?\s*|\s*```$', multiLine: true), '').trim();

      debugPrint('[Materiaux] raw JSON: $clean');

      final j = jsonDecode(clean) as Map<String, dynamic>;
      return _parse(j, clean);
    } catch (e) {
      debugPrint('[Materiaux] error: $e');
      return MateriauxResult(
        menuiseriesType: const [],
        vitrage: const [],
        rawResponse: e.toString(),
      );
    }
  }

  MateriauxResult _parse(Map<String, dynamic> j, String raw) {
    // facade_etat — valide uniquement si c'est l'une des 3 valeurs attendues
    final facadeEtatRaw = j['facade_etat']?.toString();
    final facadeEtat = _mapEtat(facadeEtatRaw);

    final toitureEtatRaw = j['toiture_etat']?.toString();
    final toitureEtat = _mapEtat(toitureEtatRaw);

    // menuiseries_type — filtre sur valeurs valides
    final menuRaw = j['menuiseries_type'];
    final menuiseriesType = _toStringList(menuRaw)
        .where((v) => const ['PVC', 'Bois', 'Alu', 'Mixte'].contains(v))
        .toList();

    // vitrage_estime — filtre sur valeurs valides
    final vitrageRaw = j['vitrage_estime'];
    final vitrage = _toStringList(vitrageRaw)
        .where((v) => const ['Simple', 'Double', 'Triple'].contains(v))
        .toList();

    return MateriauxResult(
      facade: facadeEtat,
      toiture: toitureEtat,
      menuiseriesType: menuiseriesType,
      vitrage: vitrage,
      facadeMatiere: j['facade_matiere']?.toString(),
      toitureMatiere: j['toiture_matiere']?.toString(),
      rawResponse: raw,
    );
  }

  /// Mappe une chaîne vers l'une des 3 valeurs PillSelector ('Bon'/'Moyen'/'À refaire').
  String? _mapEtat(String? v) {
    if (v == null || v == 'null') return null;
    if (v == 'Bon') return 'Bon';
    if (v == 'Moyen') return 'Moyen';
    if (v == 'À refaire' || v == 'A refaire') return 'À refaire';
    return null;
  }

  List<String> _toStringList(dynamic v) {
    if (v == null) return [];
    if (v is List) return v.map((e) => e.toString()).toList();
    return [];
  }
}
