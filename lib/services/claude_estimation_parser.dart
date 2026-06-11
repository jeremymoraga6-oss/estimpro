import 'package:flutter/foundation.dart';
import 'ai_client.dart';
import 'app_settings.dart';

/// Parses free-form text produced by Claude (the AI assistant) describing
/// a property estimation. Works with the structured "ESTIMATION CLAUDE" format
/// and also with looser conversational outputs.
///
/// Recommended prompt to give Claude:
/// "Donne-moi l'estimation au format ESTIMATION CLAUDE avec ces champs :
/// Adresse, Type, Surface, DPE, Prix estimé, Fourchette, Commune, Code INSEE,
/// Date, Notes."
class ClaudeEstimationResult {
  final String adresse;
  final String commune;
  final String codeInsee;
  final String typeId; // maison | appartement | chalet | terrain
  final int surface;
  final String dpeClasse;
  final int prixEstime;
  final int fourchetteBasse;
  final int fourchetteHaute;
  final DateTime? dateVente;
  final String notes;

  const ClaudeEstimationResult({
    required this.adresse,
    required this.commune,
    required this.codeInsee,
    required this.typeId,
    required this.surface,
    required this.dpeClasse,
    required this.prixEstime,
    required this.fourchetteBasse,
    required this.fourchetteHaute,
    required this.dateVente,
    required this.notes,
  });

  bool get hasRange => fourchetteBasse > 0 && fourchetteHaute > 0;
}

class ClaudeEstimationParser {
  static ClaudeEstimationResult? parse(String text) {
    if (text.trim().isEmpty) return null;
    final t = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    // ── Adresse ──────────────────────────────────────────────────────
    String adresse = '';
    final adresseRe = RegExp(r'[Aa]dresse\s*[:\-]\s*(.+)', multiLine: true);
    final adresseM = adresseRe.firstMatch(t);
    if (adresseM != null) {
      adresse = adresseM.group(1)!.trim().replaceAll(RegExp(r'\s*\|.*'), '');
    }

    // ── Commune ───────────────────────────────────────────────────────
    String commune = '';
    final communeRe = RegExp(r'[Cc]ommune\s*[:\-]\s*([\w\s\-éèêëàâùûüîïôçÉÈÊËÀÂÙÛÜÎÏÔÇ]+)', multiLine: true);
    final communeM = communeRe.firstMatch(t);
    if (communeM != null) {
      commune = communeM.group(1)!.trim().replaceAll(RegExp(r'\s*\|.*'), '').trim();
    }
    // Also try to extract from adresse (last part after last comma is often "XXXXX Commune")
    if (commune.isEmpty && adresse.isNotEmpty) {
      final codeVille = RegExp(r'\b(\d{5})\s+([\w\s\-éèêëàâùûüîïôçÉÈÊËÀÂÙÛÜÎÏÔÇ]+)$');
      final cv = codeVille.firstMatch(adresse);
      if (cv != null) commune = cv.group(2)!.trim();
    }

    // ── Code INSEE ────────────────────────────────────────────────────
    String codeInsee = '';
    final inseeRe = RegExp(r'[Cc]ode\s+[Ii][Nn][Ss][Ee][Ee]\s*[:\-]\s*(\d{5})', multiLine: true);
    final inseeM = inseeRe.firstMatch(t);
    if (inseeM != null) codeInsee = inseeM.group(1)!.trim();
    // Fallback: postal code in adresse
    if (codeInsee.isEmpty) {
      final cpRe = RegExp(r'\b(7[0-9]\d{3}|0[1-9]\d{3}|[1-9]\d{4})\b');
      final cpM = cpRe.firstMatch(adresse.isNotEmpty ? adresse : t);
      if (cpM != null) codeInsee = cpM.group(1)!;
    }

    // ── Type de bien ──────────────────────────────────────────────────
    String typeId = 'maison';
    final typeMap = {
      'appartement': 'appartement',
      'appart': 'appartement',
      'chalet': 'chalet',
      'terrain': 'terrain',
      'maison': 'maison',
      'villa': 'maison',
      'pavillon': 'maison',
    };
    final typeRe = RegExp(r'[Tt]ype\s*[:\-]\s*([\w]+)', multiLine: true);
    final typeM = typeRe.firstMatch(t);
    if (typeM != null) {
      final raw = typeM.group(1)!.toLowerCase();
      typeId = typeMap[raw] ?? 'maison';
    } else {
      for (final entry in typeMap.entries) {
        if (t.toLowerCase().contains(entry.key)) {
          typeId = entry.value;
          break;
        }
      }
    }

    // ── Surface ───────────────────────────────────────────────────────
    int surface = 0;
    final surfaceRe = RegExp(r'[Ss]urface\s*[:\-]?\s*(\d+)\s*m[²2]');
    final surfaceM = surfaceRe.firstMatch(t);
    if (surfaceM != null) {
      surface = int.tryParse(surfaceM.group(1)!) ?? 0;
    } else {
      // Fallback: standalone "XX m²" or "XX m2"
      final s2 = RegExp(r'\b(\d{2,4})\s*m[²2²]');
      final s2m = s2.firstMatch(t);
      if (s2m != null) surface = int.tryParse(s2m.group(1)!) ?? 0;
    }

    // ── DPE ───────────────────────────────────────────────────────────
    String dpeClasse = 'D';
    final dpeRe = RegExp(r'[Dd][Pp][Ee]\s*[:\-]?\s*([A-GNC]{1,2})(?:\s|$|\|)', multiLine: true);
    final dpeM = dpeRe.firstMatch(t);
    if (dpeM != null) {
      final d = dpeM.group(1)!.toUpperCase();
      if (['A', 'B', 'C', 'D', 'E', 'F', 'G', 'NC'].contains(d)) dpeClasse = d;
    }

    // ── Prix estimé ───────────────────────────────────────────────────
    int prixEstime = 0;
    final prixPatterns = [
      RegExp(r'[Pp]rix\s+estim[ée]\s*[:\-]\s*([\d\s ]+)\s*€'),
      RegExp(r'[Ee]stimation\s*[:\-]\s*([\d\s ]+)\s*€'),
      RegExp(r'[Vv]aleur\s+estim[ée]e?\s*[:\-]\s*([\d\s ]+)\s*€'),
      RegExp(r'[Vv]aleur\s*[:\-]\s*([\d\s ]+)\s*€'),
      // Fallback: any large price not preceded by "fourchette"
      RegExp(r'(?<!fourchette[^\n]{0,20})([\d][\d\s ]{4,9})\s*€'),
    ];
    for (final re in prixPatterns) {
      final m = re.firstMatch(t);
      if (m != null) {
        final v = _parseNum(m.group(1)!);
        if (v != null && v >= 30000) { prixEstime = v.round(); break; }
      }
    }

    // ── Fourchette ────────────────────────────────────────────────────
    int fourchetteBasse = 0;
    int fourchetteHaute = 0;
    final fourchettePatterns = [
      RegExp(r'[Ff]ourchette\s*[:\-]?\s*([\d\s ]+)\s*€\s*[–—\-]\s*([\d\s ]+)\s*€'),
      RegExp(r'[Dd]e\s+([\d\s ]+)\s*€\s+[àa]\s+([\d\s ]+)\s*€'),
      RegExp(r'[Ee]ntre\s+([\d\s ]+)\s*€\s+et\s+([\d\s ]+)\s*€'),
    ];
    for (final re in fourchettePatterns) {
      final m = re.firstMatch(t);
      if (m != null) {
        final lo = _parseNum(m.group(1)!);
        final hi = _parseNum(m.group(2)!);
        if (lo != null && hi != null && lo >= 30000 && hi > lo) {
          fourchetteBasse = lo.round();
          fourchetteHaute = hi.round();
          break;
        }
      }
    }
    // If no explicit prix estimé but we have a range, derive the midpoint
    if (prixEstime == 0 && fourchetteBasse > 0 && fourchetteHaute > 0) {
      prixEstime = ((fourchetteBasse + fourchetteHaute) / 2).round();
    }

    // ── Date ──────────────────────────────────────────────────────────
    DateTime? dateVente;
    final dateRe = RegExp(r'[Dd]ate\s*[:\-]\s*(\d{1,2})[/\-](\d{1,2})[/\-](\d{4})');
    final dateM = dateRe.firstMatch(t);
    if (dateM != null) {
      final day = int.tryParse(dateM.group(1)!) ?? 1;
      final month = int.tryParse(dateM.group(2)!) ?? 1;
      final year = int.tryParse(dateM.group(3)!) ?? DateTime.now().year;
      dateVente = DateTime(year, month, day);
    }

    // ── Notes ─────────────────────────────────────────────────────────
    String notes = '';
    final notesRe = RegExp(r'[Nn]otes?\s*[:\-]\s*(.+?)(?:\n[A-Z]|\n\n|$)', dotAll: true);
    final notesM = notesRe.firstMatch(t);
    if (notesM != null) notes = notesM.group(1)!.trim();

    // Must have at least a price
    if (prixEstime <= 0) return null;

    return ClaudeEstimationResult(
      adresse: adresse,
      commune: commune,
      codeInsee: codeInsee,
      typeId: typeId,
      surface: surface,
      dpeClasse: dpeClasse,
      prixEstime: prixEstime,
      fourchetteBasse: fourchetteBasse,
      fourchetteHaute: fourchetteHaute,
      dateVente: dateVente,
      notes: notes,
    );
  }

  static double? _parseNum(String s) {
    final clean = s.replaceAll(RegExp(r'[\s ]'), '').replaceAll(',', '.');
    return double.tryParse(clean);
  }

  // ── Variante IA (avec fallback regex) ────────────────────────────────────

  static const _kSystemPrompt = '''Tu es un assistant pour agent immobilier.
Extrais les champs suivants du texte fourni et réponds UNIQUEMENT en JSON strict (pas de markdown) :
{
  "adresse": "...",
  "commune": "...",
  "code_insee": "XXXXX",
  "type_id": "maison"|"appartement"|"chalet"|"terrain",
  "surface": 120,
  "dpe_classe": "A"|"B"|"C"|"D"|"E"|"F"|"G"|"NC",
  "prix_estime": 280000,
  "fourchette_basse": 260000,
  "fourchette_haute": 300000,
  "date": "JJ/MM/AAAA",
  "notes": "..."
}
N'inclus que les champs présents dans le texte. prix_estime est obligatoire.''';

  /// Variante asynchrone qui tente d'abord l'IA (si clé disponible), puis se
  /// rabat sur le parsing regex. Loggue "[Parser] mode dégradé" si regex seul.
  static Future<ClaudeEstimationResult?> parseAsync(String text) async {
    if (text.trim().isEmpty) return null;

    // Tentative IA
    if (AppSettings.instance.hasAnthropicKey) {
      try {
        final j = await AiClient.instance.callStructured(
          systemPrompt: _kSystemPrompt,
          userContent: text,
          maxTokens: 512,
        );

        final prixRaw = j['prix_estime'];
        final prix = prixRaw is num
            ? prixRaw.round()
            : int.tryParse(prixRaw?.toString() ?? '') ?? 0;
        if (prix <= 0) throw const FormatException('prix_estime manquant');

        final foBasse = (j['fourchette_basse'] as num?)?.round() ?? 0;
        final foHaute = (j['fourchette_haute'] as num?)?.round() ?? 0;
        final surfaceRaw = j['surface'];
        final surface = surfaceRaw is num
            ? surfaceRaw.round()
            : int.tryParse(surfaceRaw?.toString() ?? '') ?? 0;

        return ClaudeEstimationResult(
          adresse: j['adresse']?.toString() ?? '',
          commune: j['commune']?.toString() ?? '',
          codeInsee: j['code_insee']?.toString() ?? '',
          typeId: _normalizeTypeId(j['type_id']?.toString()),
          surface: surface,
          dpeClasse: (j['dpe_classe']?.toString().toUpperCase()) ?? 'D',
          prixEstime: prix,
          fourchetteBasse: foBasse,
          fourchetteHaute: foHaute,
          dateVente: _parseDate(j['date']?.toString()),
          notes: j['notes']?.toString() ?? '',
        );
      } catch (e) {
        debugPrint('[Parser] AI extraction failed, fallback to regex: $e');
      }
    }

    debugPrint('[Parser] mode dégradé (regex)');
    return parse(text);
  }

  static String _normalizeTypeId(String? raw) {
    if (raw == null) return 'maison';
    const map = {
      'appartement': 'appartement',
      'chalet': 'chalet',
      'terrain': 'terrain',
      'maison': 'maison',
    };
    return map[raw.toLowerCase()] ?? 'maison';
  }

  static DateTime? _parseDate(String? s) {
    if (s == null || s.isEmpty) return null;
    final parts = s.split(RegExp(r'[/\-]'));
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    return DateTime(year, month, day);
  }
}
