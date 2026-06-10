import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

/// Labels courts des sections (index 0-based = step).
const kSectionLabels = [
  'Vendeur',   // step 0 / section1
  'Bien',      // step 1 / section2
  'Annexes',   // step 2 / section3
  'État',      // step 3 / section4
  'Marché',    // step 4 / section5
  'Estim.',    // step 5 / section6
  'Photos',    // step 6 / section7
];

/// Couleurs pastel associées à chaque section.
const kSectionColors = [
  Color(0xFF4CAF50), // Vendeur  — vert
  Color(0xFF2196F3), // Bien     — bleu
  Color(0xFF9C27B0), // Annexes  — violet
  Color(0xFFFF9800), // État     — orange
  Color(0xFF00BCD4), // Marché   — cyan
  Color(0xFFF44336), // Estim.   — rouge
  Color(0xFF795548), // Photos   — marron
];

/// Une entrée du carnet de visite global.
class CarnetNote {
  final String id;
  final DateTime timestamp;

  /// 'section1'..'section7' (1-indexé), '' pour note sans contexte.
  final String sectionOrigine;

  final String texte;

  /// JSON sérialisé des strokes : List<List<{x,y}>>.
  /// null = pas de croquis.
  final String? strokesJson;

  const CarnetNote({
    required this.id,
    required this.timestamp,
    required this.sectionOrigine,
    this.texte = '',
    this.strokesJson,
  });

  bool get hasText => texte.isNotEmpty;
  bool get hasSketch => strokesJson != null && strokesJson!.length > 2;

  /// Index 0-based de la section (pour labels/couleurs), -1 si inconnu.
  int get sectionIndex {
    final m = RegExp(r'section(\d)$').firstMatch(sectionOrigine);
    if (m == null) return -1;
    return (int.tryParse(m.group(1)!) ?? 1) - 1;
  }

  String get sectionLabel {
    final i = sectionIndex;
    if (i < 0 || i >= kSectionLabels.length) return sectionOrigine;
    return kSectionLabels[i];
  }

  Color get sectionColor {
    final i = sectionIndex;
    if (i < 0 || i >= kSectionColors.length) return const Color(0xFF607D8B);
    return kSectionColors[i];
  }

  /// Désérialise les strokes pour affichage dans un CustomPainter.
  List<List<Offset>> get strokes {
    if (!hasSketch) return [];
    try {
      final data = jsonDecode(strokesJson!) as List;
      return data
          .map<List<Offset>>((stroke) => (stroke as List)
              .map<Offset>((p) {
                final mp = p as Map;
                return Offset(
                  (mp['x'] as num).toDouble(),
                  (mp['y'] as num).toDouble(),
                );
              })
              .toList())
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Sérialise les strokes (retourne null si vide).
  static String? strokesToJson(List<List<Offset>> strokes) {
    if (strokes.isEmpty) return null;
    final data = strokes
        .map((s) => s.map((p) => {'x': p.dx, 'y': p.dy}).toList())
        .toList();
    return jsonEncode(data);
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'sectionOrigine': sectionOrigine,
        'texte': texte,
        if (strokesJson != null) 'strokesJson': strokesJson,
      };

  factory CarnetNote.fromMap(Map<String, dynamic> m) => CarnetNote(
        id: m['id'] as String? ?? const Uuid().v4(),
        timestamp:
            DateTime.tryParse(m['timestamp'] as String? ?? '') ?? DateTime.now(),
        sectionOrigine: m['sectionOrigine'] as String? ?? '',
        texte: m['texte'] as String? ?? '',
        strokesJson: m['strokesJson'] as String?,
      );

  CarnetNote copyWithTexte(String newTexte) => CarnetNote(
        id: id,
        timestamp: timestamp,
        sectionOrigine: sectionOrigine,
        texte: newTexte,
        strokesJson: strokesJson,
      );
}
