import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'app_settings.dart';

/// Exception levée quand la réponse IA ne peut pas être parsée en JSON valide
/// après 2 tentatives consécutives.
class AiParseException implements Exception {
  final String message;
  final String rawResponse;
  const AiParseException(this.message, {required this.rawResponse});

  @override
  String toString() => 'AiParseException: $message';
}

/// Client IA centralisé pour les appels à l'API Claude Messages.
///
/// Fonctionnalités :
/// - Retry automatique (1 fois) sur échec de parsing JSON, avec injection
///   du contexte d'erreur dans le system prompt.
/// - [AiParseException] levée après 2 échecs successifs de parsing.
/// - Timeout 45 s.
/// - Erreurs HTTP explicites (401, 429, 529/503, autre).
/// - Support vision : passe [imageBase64] + [imageMimeType] pour les appels
///   multipart (ex: analyse de façade).
/// - Clé absente → [Exception] avec message guidant vers Profil.
class AiClient {
  AiClient._();
  static final AiClient instance = AiClient._();

  static const _endpoint = 'https://api.anthropic.com/v1/messages';
  static const _model = 'claude-sonnet-4-6';
  static const _apiVersion = '2023-06-01';

  /// Appelle Claude et retourne le JSON parsé en [Map<String, dynamic>].
  ///
  /// [systemPrompt] : instruction système (peut être vide pour les appels
  ///   multipart où le prompt est dans [userContent]).
  /// [userContent] : texte utilisateur (ou prompt principal pour les appels vision).
  /// [maxTokens] : limite de tokens en sortie (défaut 1500).
  /// [imageBase64] / [imageMimeType] : activent le mode vision (message multipart).
  ///
  /// Throws [AiParseException] après 2 tentatives de parsing JSON infructueuses.
  /// Throws [Exception] sur erreur HTTP (401, 429, 529/503, autre) ou réseau.
  Future<Map<String, dynamic>> callStructured({
    required String systemPrompt,
    required String userContent,
    int maxTokens = 1500,
    String? imageBase64,
    String? imageMimeType,
  }) async {
    final key = AppSettings.instance.anthropicKey;
    if (key.isEmpty) {
      throw Exception('Clé API Anthropic manquante. Configure-la dans Profil.');
    }

    final userMsg = _buildUserMessage(userContent, imageBase64, imageMimeType);

    String? lastRaw;
    String? parseError;

    for (int attempt = 0; attempt < 2; attempt++) {
      final sysPrompt = attempt == 0
          ? systemPrompt
          : _withRetryContext(systemPrompt, parseError);

      final Map<String, dynamic> requestBody = {
        'model': _model,
        'max_tokens': maxTokens,
        'messages': [
          {'role': 'user', 'content': userMsg},
        ],
      };
      if (sysPrompt.isNotEmpty) requestBody['system'] = sysPrompt;

      final http.Response resp;
      try {
        resp = await http
            .post(
              Uri.parse(_endpoint),
              headers: {
                'x-api-key': key,
                'anthropic-version': _apiVersion,
                'content-type': 'application/json',
              },
              body: jsonEncode(requestBody),
            )
            .timeout(const Duration(seconds: 45));
      } catch (e) {
        // Timeout ou erreur réseau — non retryable
        throw Exception('Erreur réseau : $e');
      }

      // Erreurs HTTP — non retryables (pas la peine de réessayer)
      if (resp.statusCode == 401) {
        throw Exception('Clé API invalide. Vérifie-la dans Profil.');
      }
      if (resp.statusCode == 429) {
        throw Exception('Quota API atteint. Attends quelques secondes.');
      }
      if (resp.statusCode == 529 || resp.statusCode == 503) {
        throw Exception('API Anthropic surchargée. Réessaie dans quelques secondes.');
      }
      if (resp.statusCode != 200) {
        throw Exception('Erreur API (${resp.statusCode})');
      }

      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      lastRaw = (body['content'] as List).first['text'] as String;
      final clean = _stripMarkdown(lastRaw!);

      try {
        return jsonDecode(clean) as Map<String, dynamic>;
      } on FormatException catch (e) {
        parseError = e.toString();
        debugPrint('[AiClient] parse error (attempt ${attempt + 1}): $e\nRaw: $lastRaw');
        if (attempt == 1) {
          throw AiParseException(
            'JSON invalide après 2 tentatives : $e',
            rawResponse: lastRaw,
          );
        }
        // Attempt 0 → continue vers attempt 1 avec contexte d'erreur injecté
      }
    }

    // Ne devrait jamais être atteint
    throw AiParseException('Échec après 2 tentatives', rawResponse: lastRaw ?? '');
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Construit le contenu du message utilisateur.
  /// - Sans image : retourne le texte directement (string).
  /// - Avec image : retourne un tableau multipart [image, text].
  dynamic _buildUserMessage(
    String text,
    String? imageBase64,
    String? imageMimeType,
  ) {
    if (imageBase64 == null || imageMimeType == null) {
      return text;
    }
    return [
      {
        'type': 'image',
        'source': {
          'type': 'base64',
          'media_type': imageMimeType,
          'data': imageBase64,
        },
      },
      {
        'type': 'text',
        'text': text,
      },
    ];
  }

  /// Injecte le contexte d'erreur de parsing dans le system prompt pour le retry.
  static String _withRetryContext(String sysPrompt, String? error) {
    if (error == null) return sysPrompt;
    final hint = '[INSTRUCTION IMPÉRATIVE : ta réponse précédente n\'était pas du '
        'JSON valide ($error). Réponds UNIQUEMENT avec un objet JSON valide, '
        'sans texte autour ni markdown.]';
    return sysPrompt.isEmpty ? hint : '$sysPrompt\n\n$hint';
  }

  /// Retire les balises markdown ` ```json ... ``` ` si présentes.
  static String _stripMarkdown(String raw) =>
      raw.replaceAll(RegExp(r'^```(?:json)?\s*|\s*```$', multiLine: true), '').trim();
}
