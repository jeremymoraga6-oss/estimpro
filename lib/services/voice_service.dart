import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../models/vendeur_note.dart';

// Set your Anthropic API key here before building
const _kAnthropicKey = '';

const _kSystemPrompt = '''Tu es un assistant pour agent immobilier.
Extrait de cette note vocale les informations suivantes en JSON :
- motivation_vente (raison de la vente)
- delai_souhaite (délai de vente souhaité)
- prix_souhaite (prix demandé par le vendeur)
- travaux_declares (travaux mentionnés)
- points_forts (atouts mentionnés par le vendeur, tableau)
- points_faibles (problèmes mentionnés, tableau)
- situation_personnelle (infos personnelles utiles)
Réponds uniquement en JSON, rien d'autre.''';

class VoiceService {
  VoiceService._();
  static final instance = VoiceService._();

  final _speech = SpeechToText();
  final _recorder = AudioRecorder();

  bool _speechReady = false;
  bool _isRecording = false;
  String _partialText = '';

  bool get isRecording => _isRecording;

  Future<bool> init() async {
    _speechReady = await _speech.initialize(
      onError: (e) => debugPrint('[Voice] speech error: $e'),
      onStatus: (s) => debugPrint('[Voice] speech status: $s'),
    );
    return _speechReady;
  }

  /// Starts recording audio + live speech recognition.
  /// [onPartial] called on each partial result.
  Future<void> start({required ValueChanged<String> onPartial}) async {
    if (_isRecording) return;
    _isRecording = true;
    _partialText = '';

    // Audio file recording
    try {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/note_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
    } catch (e) {
      debugPrint('[Voice] recorder error (best-effort): $e');
    }

    // Live speech recognition
    if (_speechReady) {
      await _speech.listen(
        onResult: (result) {
          _partialText = result.recognizedWords;
          onPartial(_partialText);
        },
        localeId: 'fr_FR',
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: false,
          listenMode: ListenMode.dictation,
        ),
      );
    }
  }

  /// Stops recording. Returns (transcription, audioPath).
  Future<(String, String?)> stop() async {
    _isRecording = false;
    String? audioPath;

    await _speech.stop();

    try {
      audioPath = await _recorder.stop();
    } catch (e) {
      debugPrint('[Voice] recorder stop error: $e');
    }

    return (_partialText.trim(), audioPath);
  }

  Future<void> dispose() async {
    await _speech.cancel();
    await _recorder.dispose();
  }

  /// Sends transcription to Claude and returns a structured VendeurNote.
  Future<VendeurNote> structureWithClaude(
      String transcription, String? audioPath) async {
    final base = VendeurNote(
      transcription: transcription,
      dateCapture: DateTime.now(),
      audioPath: audioPath,
    );

    if (transcription.isEmpty || _kAnthropicKey.isEmpty) return base;

    try {
      final resp = await http
          .post(
            Uri.parse('https://api.anthropic.com/v1/messages'),
            headers: {
              'x-api-key': _kAnthropicKey,
              'anthropic-version': '2023-06-01',
              'content-type': 'application/json',
            },
            body: jsonEncode({
              'model': 'claude-sonnet-4-6',
              'max_tokens': 1024,
              'system': _kSystemPrompt,
              'messages': [
                {'role': 'user', 'content': transcription}
              ],
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (resp.statusCode != 200) {
        debugPrint('[Voice] Claude API error ${resp.statusCode}: ${resp.body}');
        return base;
      }

      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final text = (body['content'] as List).first['text'] as String;
      final raw = jsonDecode(text) as Map<String, dynamic>;

      return base.copyWithStructure(
        motivationVente: raw['motivation_vente']?.toString() ?? '',
        delaiSouhaite: raw['delai_souhaite']?.toString() ?? '',
        prixSouhaite: raw['prix_souhaite']?.toString() ?? '',
        travauxDeclares: raw['travaux_declares']?.toString() ?? '',
        pointsForts: _toStrList(raw['points_forts']),
        pointsFaibles: _toStrList(raw['points_faibles']),
        situationPersonnelle: raw['situation_personnelle']?.toString() ?? '',
      );
    } catch (e) {
      debugPrint('[Voice] Claude structuring error: $e');
      return base;
    }
  }

  List<String> _toStrList(dynamic v) {
    if (v == null) return [];
    if (v is List) return v.map((e) => e.toString()).toList();
    return [v.toString()];
  }
}
