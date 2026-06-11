import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../models/vendeur_note.dart';
import 'ai_client.dart';
import 'app_settings.dart';

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

const _kExtractPrompt = '''Tu es un assistant pour agent immobilier qui visite un bien.
Extrait UNIQUEMENT les caractéristiques OBJECTIVES du bien depuis la description.
Réponds en JSON strict (rien d'autre, pas de markdown), avec ces clés (toutes optionnelles — n'inclus que ce qui est clairement mentionné) :

{
  "vue_degagee": true|false,         // vue claire mentionnée (montagne, lac, dégagement)
  "etat_general": 1|2|3|4,           // 1=très mauvais, 2=moyen/à rafraîchir, 3=bon, 4=excellent/refait à neuf
  "note_cuisine": 1|2|3|4,           // état/équipement cuisine
  "note_sol": 1|2|3|4,                // état/qualité des sols
  "note_sdb": 1|2|3|4,                // état salle de bain
  "note_fenetres": 1|2|3|4,           // double vitrage, état menuiseries
  "note_chauffage": 1|2|3|4,          // type+état chauffage
  "dpe_classe": "A"|"B"|"C"|"D"|"E"|"F"|"G",  // si classe explicitement mentionnée
  "orientations": ["S","SE","O"...],  // orientations mentionnées (N, NE, E, SE, S, SO, O, NO)
  "points_forts": ["...", "..."],     // arguments commerciaux
  "points_faibles": ["...", "..."],   // axes à mentionner pour la vente
  "travaux_a_prevoir": "résumé",      // courte phrase sur les travaux nécessaires
  "ajust_environnement": -12|-9|-6|-3|0,  // % décote nuisances (route, voie ferrée, industrie)
  "pieces_surfaces": [               // dictée pièce par pièce : une entrée par pièce mentionnée avec sa surface
    {"nom": "Séjour", "surface": 28},
    {"nom": "Cuisine", "surface": 12}
  ]
}

Pour "pieces_surfaces" : capture chaque pièce nommée par l'agent avec sa surface en m² si elle est mentionnée (ex: "séjour de 28 mètres carrés", "chambre 1 de 14m²"). Mets "surface": null si la surface n'est pas précisée. N'invente jamais de surface. Utilise des noms de pièces clairs et capitalisés (Séjour, Cuisine, Chambre 1, Salle de bain, WC, Bureau, Dressing, Entrée, Garage…). Si aucune pièce n'est détaillée, n'inclus PAS la clé.

Si une info n'est pas claire dans le texte, n'inclus PAS la clé.''';

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

    if (transcription.isEmpty || AppSettings.instance.anthropicKey.isEmpty) return base;

    try {
      final raw = await AiClient.instance.callStructured(
        systemPrompt: _kSystemPrompt,
        userContent: transcription,
        maxTokens: 1024,
      );
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

  /// Extrait les caractéristiques du BIEN depuis une note vocale ou texte libre.
  /// Retourne null si pas de clé API ou erreur — null = "aucune extraction".
  /// Sinon retourne un BienExtraction prêt à appliquer aux champs de l'estimation.
  Future<BienExtraction?> extractBienFields(String text) async {
    if (text.isEmpty || AppSettings.instance.anthropicKey.isEmpty) return null;

    try {
      final j = await AiClient.instance.callStructured(
        systemPrompt: _kExtractPrompt,
        userContent: text,
        maxTokens: 1024,
      );
      return BienExtraction(
        vueDegagee: j['vue_degagee'] as bool?,
        etatGeneral: _intRange(j['etat_general'], 1, 4),
        noteCuisine: _intRange(j['note_cuisine'], 1, 4),
        noteSol: _intRange(j['note_sol'], 1, 4),
        noteSdb: _intRange(j['note_sdb'], 1, 4),
        noteFenetres: _intRange(j['note_fenetres'], 1, 4),
        noteChauffage: _intRange(j['note_chauffage'], 1, 4),
        dpeClasse: (j['dpe_classe'] as String?)?.toUpperCase(),
        orientations: _toStrList(j['orientations']),
        pointsForts: _toStrList(j['points_forts']),
        pointsFaibles: _toStrList(j['points_faibles']),
        travauxAPrevoir: j['travaux_a_prevoir']?.toString(),
        ajustEnvironnement: (j['ajust_environnement'] as num?)?.toDouble(),
        piecesSurfaces: _toPieces(j['pieces_surfaces']),
      );
    } catch (e) {
      debugPrint('[Voice] extractBien exception: $e');
      return null;
    }
  }

  int? _intRange(dynamic v, int min, int max) {
    if (v == null) return null;
    final n = v is int ? v : int.tryParse(v.toString());
    if (n == null) return null;
    return n.clamp(min, max);
  }

  /// Parse la liste pièce par pièce : [{nom, surface}] en filtrant les entrées invalides.
  List<Map<String, dynamic>> _toPieces(dynamic v) {
    if (v is! List) return const [];
    final out = <Map<String, dynamic>>[];
    for (final item in v) {
      if (item is! Map) continue;
      final nom = item['nom']?.toString().trim();
      if (nom == null || nom.isEmpty) continue;
      final surfaceRaw = item['surface'];
      double? surface;
      if (surfaceRaw is num) {
        surface = surfaceRaw.toDouble();
      } else if (surfaceRaw != null) {
        surface = double.tryParse(surfaceRaw.toString().replaceAll(',', '.'));
      }
      out.add({'nom': nom, if (surface != null && surface > 0) 'surface': surface});
    }
    return out;
  }
}

/// Extraction structurée des champs du BIEN depuis une note libre.
class BienExtraction {
  final bool? vueDegagee;
  final int? etatGeneral;
  final int? noteCuisine;
  final int? noteSol;
  final int? noteSdb;
  final int? noteFenetres;
  final int? noteChauffage;
  final String? dpeClasse;
  final List<String> orientations;
  final List<String> pointsForts;
  final List<String> pointsFaibles;
  final String? travauxAPrevoir;
  final double? ajustEnvironnement;

  /// Dictée pièce par pièce : [{nom, surface?}]
  final List<Map<String, dynamic>> piecesSurfaces;

  const BienExtraction({
    this.vueDegagee,
    this.etatGeneral,
    this.noteCuisine,
    this.noteSol,
    this.noteSdb,
    this.noteFenetres,
    this.noteChauffage,
    this.dpeClasse,
    this.orientations = const [],
    this.pointsForts = const [],
    this.pointsFaibles = const [],
    this.travauxAPrevoir,
    this.ajustEnvironnement,
    this.piecesSurfaces = const [],
  });

  /// Vrai si l'extraction contient au moins une donnée utilisable
  bool get hasData =>
      vueDegagee != null ||
      etatGeneral != null ||
      noteCuisine != null ||
      noteSol != null ||
      noteSdb != null ||
      noteFenetres != null ||
      noteChauffage != null ||
      dpeClasse != null ||
      orientations.isNotEmpty ||
      pointsForts.isNotEmpty ||
      pointsFaibles.isNotEmpty ||
      (travauxAPrevoir?.isNotEmpty ?? false) ||
      ajustEnvironnement != null ||
      piecesSurfaces.isNotEmpty;

  /// Liste des champs détectés pour preview dans l'UI
  List<String> get detectedFields {
    final list = <String>[];
    if (vueDegagee == true) list.add('Vue dégagée');
    if (etatGeneral != null) list.add('État général : $etatGeneral/4');
    if (noteCuisine != null) list.add('Cuisine : $noteCuisine/4');
    if (noteSol != null) list.add('Sol : $noteSol/4');
    if (noteSdb != null) list.add('SDB : $noteSdb/4');
    if (noteFenetres != null) list.add('Fenêtres : $noteFenetres/4');
    if (noteChauffage != null) list.add('Chauffage : $noteChauffage/4');
    if (dpeClasse != null) list.add('DPE : $dpeClasse');
    if (orientations.isNotEmpty) list.add('Orientation : ${orientations.join("/")}');
    if (ajustEnvironnement != null) list.add('Nuisances : ${ajustEnvironnement!.toInt()}%');
    if (pointsForts.isNotEmpty) list.add('${pointsForts.length} point(s) fort(s)');
    if (pointsFaibles.isNotEmpty) list.add('${pointsFaibles.length} point(s) faible(s)');
    if (travauxAPrevoir?.isNotEmpty ?? false) list.add('Travaux à prévoir');
    if (piecesSurfaces.isNotEmpty) {
      final withSurface = piecesSurfaces.where((p) => p['surface'] != null).length;
      list.add('${piecesSurfaces.length} pièce(s)'
          '${withSurface > 0 ? ' · $withSurface avec surface' : ''}');
    }
    return list;
  }
}
