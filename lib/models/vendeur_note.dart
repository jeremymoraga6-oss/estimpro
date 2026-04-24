import 'dart:convert';

class VendeurNote {
  final String transcription;
  final String motivationVente;
  final String delaiSouhaite;
  final String prixSouhaite;
  final String travauxDeclares;
  final List<String> pointsForts;
  final List<String> pointsFaibles;
  final String situationPersonnelle;
  final DateTime dateCapture;
  final String? audioPath;

  const VendeurNote({
    required this.transcription,
    this.motivationVente = '',
    this.delaiSouhaite = '',
    this.prixSouhaite = '',
    this.travauxDeclares = '',
    this.pointsForts = const [],
    this.pointsFaibles = const [],
    this.situationPersonnelle = '',
    required this.dateCapture,
    this.audioPath,
  });

  bool get hasStructuredData =>
      motivationVente.isNotEmpty ||
      delaiSouhaite.isNotEmpty ||
      prixSouhaite.isNotEmpty ||
      pointsForts.isNotEmpty ||
      pointsFaibles.isNotEmpty;

  Map<String, dynamic> toMap() => {
        'transcription': transcription,
        'motivationVente': motivationVente,
        'delaiSouhaite': delaiSouhaite,
        'prixSouhaite': prixSouhaite,
        'travauxDeclares': travauxDeclares,
        'pointsForts': jsonEncode(pointsForts),
        'pointsFaibles': jsonEncode(pointsFaibles),
        'situationPersonnelle': situationPersonnelle,
        'dateCapture': dateCapture.toIso8601String(),
        'audioPath': audioPath,
      };

  factory VendeurNote.fromMap(Map<String, dynamic> m) => VendeurNote(
        transcription: m['transcription'] as String? ?? '',
        motivationVente: m['motivationVente'] as String? ?? '',
        delaiSouhaite: m['delaiSouhaite'] as String? ?? '',
        prixSouhaite: m['prixSouhaite'] as String? ?? '',
        travauxDeclares: m['travauxDeclares'] as String? ?? '',
        pointsForts: m['pointsForts'] != null
            ? List<String>.from(jsonDecode(m['pointsForts'] as String))
            : [],
        pointsFaibles: m['pointsFaibles'] != null
            ? List<String>.from(jsonDecode(m['pointsFaibles'] as String))
            : [],
        situationPersonnelle: m['situationPersonnelle'] as String? ?? '',
        dateCapture: DateTime.parse(
            m['dateCapture'] as String? ?? DateTime.now().toIso8601String()),
        audioPath: m['audioPath'] as String?,
      );

  VendeurNote copyWithStructure({
    String? motivationVente,
    String? delaiSouhaite,
    String? prixSouhaite,
    String? travauxDeclares,
    List<String>? pointsForts,
    List<String>? pointsFaibles,
    String? situationPersonnelle,
  }) =>
      VendeurNote(
        transcription: transcription,
        motivationVente: motivationVente ?? this.motivationVente,
        delaiSouhaite: delaiSouhaite ?? this.delaiSouhaite,
        prixSouhaite: prixSouhaite ?? this.prixSouhaite,
        travauxDeclares: travauxDeclares ?? this.travauxDeclares,
        pointsForts: pointsForts ?? this.pointsForts,
        pointsFaibles: pointsFaibles ?? this.pointsFaibles,
        situationPersonnelle: situationPersonnelle ?? this.situationPersonnelle,
        dateCapture: dateCapture,
        audioPath: audioPath,
      );
}
