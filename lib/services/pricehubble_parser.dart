import 'dart:io';
import 'package:pdfrx/pdfrx.dart';

class PricehubbleResult {
  final double prixEstime;
  final double fourchetteBasse;
  final double fourchetteHaute;
  final double prixM2;
  final int surface;
  final String adresse;

  const PricehubbleResult({
    required this.prixEstime,
    required this.fourchetteBasse,
    required this.fourchetteHaute,
    required this.prixM2,
    required this.surface,
    required this.adresse,
  });

  bool get hasRange => fourchetteBasse > 0 && fourchetteHaute > 0;
}

class PricehubbleParser {
  /// Opens a PDF file, extracts all text, and parses PriceHubble fields.
  static Future<PricehubbleResult?> parseFile(String path) async {
    String rawText = '';
    try {
      final doc = await PdfDocument.openFile(path);
      final buf = StringBuffer();
      for (final page in doc.pages) {
        try {
          final text = await page.loadText();
          buf.write(text.fullText);
          buf.write('\n');
        } catch (_) {
          // Skip pages that fail to extract text (scanned pages, etc.)
        }
      }
      rawText = buf.toString();
    } catch (_) {
      // pdfrx failed to open — fall back to raw byte parsing
      rawText = _extractRawText(path);
    }
    if (rawText.isEmpty) return null;
    return parseText(rawText);
  }

  /// Fallback: extract printable ASCII text directly from PDF bytes.
  /// Works on uncompressed text streams only, but catches simple cases.
  static String _extractRawText(String path) {
    try {
      final bytes = File(path).readAsBytesSync();
      final buf = StringBuffer();
      // Extract content between parentheses (PDF text string objects)
      bool inStr = false;
      for (int i = 0; i < bytes.length; i++) {
        final b = bytes[i];
        if (!inStr && b == 40) { inStr = true; continue; } // '('
        if (inStr && b == 41) { inStr = false; buf.write(' '); continue; } // ')'
        if (inStr && b >= 32 && b < 127) buf.writeCharCode(b);
      }
      return buf.toString();
    } catch (_) {
      return '';
    }
  }

  /// Parses raw text extracted from a PriceHubble report.
  static PricehubbleResult? parseText(String text) {
    final t = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    double? prixEstime;
    double? fourchetteBasse;
    double? fourchetteHaute;
    double? prixM2;
    int? surface;
    String adresse = '';

    // --- Prix estimé central ---
    // PriceHubble layouts seen in the wild:
    //   "Valeur vénale estimée\n450 000 €"
    //   "Estimation de la valeur\n450 000 €"
    //   "Valeur estimée : 450 000 €"
    final centralPatterns = [
      RegExp(r'[Vv]aleur\s+v[eé]nale\s+estim[ée]e?\s*[:\n]\s*([\d\s ]+)\s*€', dotAll: true),
      RegExp(r'[Ee]stimation\s+de\s+la\s+valeur\s*[:\n]\s*([\d\s ]+)\s*€', dotAll: true),
      RegExp(r'[Vv]aleur\s+estim[ée]e?\s*[:\n]\s*([\d\s ]+)\s*€', dotAll: true),
      RegExp(r'[Pp]rix\s+estim[ée]\s*[:\n]\s*([\d\s ]+)\s*€', dotAll: true),
    ];
    for (final re in centralPatterns) {
      final m = re.firstMatch(t);
      if (m != null) {
        final v = _parseNum(m.group(1)!);
        if (v != null && v >= 30000) { prixEstime = v; break; }
      }
    }

    // --- Fourchette ---
    // "De 420 000 € à 480 000 €"  /  "Entre … et …"  /  "420 000 € – 480 000 €"
    final fourchettePatterns = [
      RegExp(r'[Dd]e\s+([\d\s ]+)\s*€\s+[àa]\s+([\d\s ]+)\s*€'),
      RegExp(r'[Ee]ntre\s+([\d\s ]+)\s*€\s+et\s+([\d\s ]+)\s*€'),
      RegExp(r'([\d\s ]{5,12})\s*€\s*[–—\-]\s*([\d\s ]{5,12})\s*€'),
    ];
    for (final re in fourchettePatterns) {
      final m = re.firstMatch(t);
      if (m != null) {
        final lo = _parseNum(m.group(1)!);
        final hi = _parseNum(m.group(2)!);
        if (lo != null && hi != null && lo >= 30000 && hi > lo) {
          fourchetteBasse = lo;
          fourchetteHaute = hi;
          break;
        }
      }
    }

    // Derive central from range if not found yet
    if (prixEstime == null && fourchetteBasse != null && fourchetteHaute != null) {
      prixEstime = (fourchetteBasse + fourchetteHaute) / 2;
    }

    // Last-resort: any large price-looking number ≥ 5 digits on its own line
    if (prixEstime == null) {
      final fallback = RegExp(r'(?:^|\n)\s*([\d][\d\s ]{4,9})\s*€', multiLine: true);
      for (final m in fallback.allMatches(t)) {
        final v = _parseNum(m.group(1)!);
        if (v != null && v >= 50000 && v <= 10000000) { prixEstime = v; break; }
      }
    }

    // --- Prix / m² ---
    final m2Patterns = [
      RegExp(r'([\d\s ]+)\s*€\s*/\s*m[²2²]'),
      RegExp(r'[Pp]rix\s+au\s+m[²2]\s*[:\n]?\s*([\d\s ]+)\s*€'),
    ];
    for (final re in m2Patterns) {
      final m = re.firstMatch(t);
      if (m != null) {
        final v = _parseNum(m.group(1)!);
        if (v != null && v > 0) { prixM2 = v; break; }
      }
    }

    // --- Surface ---
    final surfPatterns = [
      RegExp(r'[Ss]urface\s+(?:habitable|carrez|loi\s+carrez)?\s*[:\n]?\s*([\d]+)\s*m[²2]'),
      RegExp(r'([\d]+)\s*m[²2]\s+(?:habitables?|carrez)'),
    ];
    for (final re in surfPatterns) {
      final m = re.firstMatch(t);
      if (m != null) {
        final v = int.tryParse(m.group(1)!.trim());
        if (v != null && v > 0) { surface = v; break; }
      }
    }

    // Derive prixM2 from price + surface if still missing
    if (prixM2 == null && prixEstime != null && surface != null && surface > 0) {
      prixM2 = prixEstime / surface;
    }

    // --- Adresse (best-effort) ---
    final addrRe = RegExp(
        r'\d+[,\s]+(?:[Rr]ue|[Aa]venue|[Bb]oulevard|[Cc]hemin|[Ii]mpasse|[Aa]llée)\s+[\w\s\-]+',
    );
    final addrM = addrRe.firstMatch(t);
    if (addrM != null) adresse = addrM.group(0)?.trim() ?? '';

    if (prixEstime == null || prixEstime <= 0) return null;

    return PricehubbleResult(
      prixEstime: prixEstime,
      fourchetteBasse: fourchetteBasse ?? 0,
      fourchetteHaute: fourchetteHaute ?? 0,
      prixM2: prixM2 ?? 0,
      surface: surface ?? 0,
      adresse: adresse,
    );
  }

  // Strips spaces (including non-breaking  ) then parses as double.
  static double? _parseNum(String s) {
    final clean = s.replaceAll(RegExp(r'[\s ]'), '').replaceAll(',', '.');
    return double.tryParse(clean);
  }
}
