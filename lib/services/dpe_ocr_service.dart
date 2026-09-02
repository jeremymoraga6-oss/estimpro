import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Résultat d'extraction OCR d'un diagnostic DPE.
class DpeOcrResult {
  final String? classeEnergie; // 'A' à 'G' ou null
  final String? classeGes;     // 'A' à 'G' ou null
  final int? consoKwh;         // kWh/m²/an
  final int? emissionsGes;     // kg CO2/m²/an
  final String rawText;        // texte brut OCR (pour debug)
  final double confidence;     // 0.0 - 1.0

  const DpeOcrResult({
    this.classeEnergie,
    this.classeGes,
    this.consoKwh,
    this.emissionsGes,
    required this.rawText,
    required this.confidence,
  });

  bool get hasData =>
      classeEnergie != null ||
      classeGes != null ||
      consoKwh != null ||
      emissionsGes != null;
}

/// Service d'OCR pour diagnostics DPE.
///
/// Utilise Google ML Kit (on-device, gratuit, fonctionne hors ligne).
/// Parse le texte brut pour identifier :
///   - Consommation en kWh/m²/an → déduit la classe énergie
///   - Émissions en kg CO2/m²/an → déduit la classe GES
///   - Détection directe d'une classe écrite (ex: "Classe : C")
class DpeOcrService {
  // Seuils légaux DPE (depuis juillet 2021)
  // Consommation kWh/m²/an
  static String _classeFromKwh(int kwh) {
    if (kwh <= 70) return 'A';
    if (kwh <= 110) return 'B';
    if (kwh <= 180) return 'C';
    if (kwh <= 250) return 'D';
    if (kwh <= 330) return 'E';
    if (kwh <= 420) return 'F';
    return 'G';
  }

  // Émissions kg CO2/m²/an
  static String _classeFromGes(int co2) {
    if (co2 <= 6) return 'A';
    if (co2 <= 11) return 'B';
    if (co2 <= 30) return 'C';
    if (co2 <= 50) return 'D';
    if (co2 <= 70) return 'E';
    if (co2 <= 100) return 'F';
    return 'G';
  }

  Future<DpeOcrResult> extractFromImage(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final input = InputImage.fromFilePath(imagePath);
      final result = await recognizer.processImage(input);
      final text = result.text;

      debugPrint('[DPE-OCR] ${text.length} chars extracted');
      return _parse(text);
    } catch (e) {
      debugPrint('[DPE-OCR] error: $e');
      return const DpeOcrResult(rawText: '', confidence: 0, );
    } finally {
      await recognizer.close();
    }
  }

  DpeOcrResult _parse(String text) {
    final lower = text.toLowerCase();
    int score = 0; // signaux trouvés → confiance

    // 1. Conso kWh : recherche "XXX kWh" (1-4 chiffres)
    //    Évite "kWhep" qui désigne énergie primaire (peut être valide aussi)
    int? kwh;
    final kwhMatch = RegExp(r'(\d{2,4})\s*kwh', caseSensitive: false).firstMatch(lower);
    if (kwhMatch != null) {
      final v = int.tryParse(kwhMatch.group(1)!);
      if (v != null && v >= 30 && v <= 999) {
        kwh = v;
        score++;
      }
    }

    // 2. Émissions kg CO2 : recherche "XX kg CO2" ou "XX kgCO2"
    int? co2;
    final co2Match = RegExp(
      r'(\d{1,3})\s*kg\s*(?:eq\.?\s*)?co\s?2',
      caseSensitive: false,
    ).firstMatch(lower);
    if (co2Match != null) {
      final v = int.tryParse(co2Match.group(1)!);
      if (v != null && v >= 1 && v <= 200) {
        co2 = v;
        score++;
      }
    }

    // 3. Classe écrite explicitement : "classe énergie : C", "étiquette : D"
    String? classeEnergie;
    final classEnerMatch = RegExp(
      r'(?:classe|étiquette|etiquette)\s*(?:énergie|energie|énergétique|energetique)?\s*[:=\s]\s*([A-G])\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (classEnerMatch != null) {
      classeEnergie = classEnerMatch.group(1)!.toUpperCase();
      score += 2; // signal fort
    }

    String? classeGes;
    final classGesMatch = RegExp(
      r'(?:classe|étiquette|etiquette)\s*(?:climat|ges|gaz|émissions|emissions)\s*[:=\s]\s*([A-G])\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (classGesMatch != null) {
      classeGes = classGesMatch.group(1)!.toUpperCase();
      score += 2;
    }

    // 4. Fallback : déduit la classe depuis les valeurs numériques
    classeEnergie ??= kwh != null ? _classeFromKwh(kwh) : null;
    classeGes ??= co2 != null ? _classeFromGes(co2) : null;

    // Confiance : 0.3 par signal trouvé, plafonnée à 0.9
    final confidence = (score * 0.3).clamp(0.0, 0.9);

    return DpeOcrResult(
      classeEnergie: classeEnergie,
      classeGes: classeGes,
      consoKwh: kwh,
      emissionsGes: co2,
      rawText: text,
      confidence: confidence,
    );
  }
}
