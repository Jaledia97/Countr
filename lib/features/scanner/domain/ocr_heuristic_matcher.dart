import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Representation of structured card information extracted from raw OCR text.
class OcrScanResult {
  final List<String> candidateNames;
  final String? collectorNumber;
  final String? setCode;
  final String? totalInSet;
  final List<String> allLines;

  const OcrScanResult({
    required this.candidateNames,
    this.collectorNumber,
    this.setCode,
    this.totalInSet,
    this.allLines = const [],
  });

  String? get primaryName =>
      candidateNames.isNotEmpty ? candidateNames.first : null;

  @override
  String toString() {
    return 'OcrScanResult(primaryName: $primaryName, collector: $collectorNumber, set: $setCode, total: $totalInSet)';
  }
}

/// Heuristic parser that extracts card titles, set codes, and collector numbers
/// from on-device ML Kit OCR output.
class OcrHeuristicMatcher {
  // Regex pattern for collector numbers like "123/250" or "045/185"
  static final RegExp _fractionPattern =
      RegExp(r'\b(\d{1,4})\s*[/]\s*(\d{1,4})\b');

  // Regex pattern for set code + number like "SV01-151", "ST-01", "OP01-001"
  static final RegExp _setDashNumberPattern =
      RegExp(r'\b([A-Za-z0-9]{2,5})\s*[-–—]\s*(\d{1,4})\b');

  // Regex pattern for "#123", "No. 25", "NO. 004"
  static final RegExp _hashOrNoPattern =
      RegExp(r'\b(?:NO\.?|#)\s*(\d{1,4})\b', caseSensitive: false);

  // Common card UI and card-type text noise to ignore when selecting candidate card titles
  static final Set<String> _ignoredNameTokens = {
    'hp',
    'basic',
    'stage',
    'stage 1',
    'stage 2',
    'vstar',
    'vmax',
    'ex',
    'gx',
    'trainer',
    'supporter',
    'item',
    'stadium',
    'energy',
    'creature',
    'instant',
    'sorcery',
    'enchantment',
    'artifact',
    'planeswalker',
    'land',
    'legendary',
    'token',
    'wizards',
    'coast',
    'nintendo',
    'creatures',
    'gamefreak',
    'illus',
    'illustrator',
  };

  /// Strips ALL punctuation (quotes, commas, hyphens, etc.) from input,
  /// leaving only alphanumeric characters and spaces, and lowercases everything.
  static String sanitizeText(String input) {
    return input
        .replaceAll(RegExp(r"[^\w\s]"), '') // Strip all punctuation & symbols
        .replaceAll(RegExp(r'\s+'), ' ')    // Collapse multiple whitespace
        .trim()
        .toLowerCase();
  }

  /// Extracts individual lines from ML Kit [RecognizedText] blocks,
  /// strips all punctuation, lowercases them, and filters out noise lines (< 3 characters).
  /// Never concatenates the entire OCR RecognizedText into one giant string.
  static List<String> extractCleanedLines(RecognizedText recognizedText) {
    final cleaned = <String>[];
    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        final sanitized = sanitizeText(line.text);
        if (sanitized.length >= 3 && !cleaned.contains(sanitized)) {
          cleaned.add(sanitized);
        }
      }
    }
    return cleaned;
  }

  /// Sanitizes a flat list of raw text lines into clean alphanumeric lines.
  static List<String> sanitizeLines(List<String> rawLines) {
    final cleaned = <String>[];
    for (final line in rawLines) {
      final sanitized = sanitizeText(line);
      if (sanitized.length >= 3 && !cleaned.contains(sanitized)) {
        cleaned.add(sanitized);
      }
    }
    return cleaned;
  }

  /// Parses an ML Kit [RecognizedText] object, leveraging bounding box positions.
  static OcrScanResult parseRecognizedText(RecognizedText recognizedText) {
    if (recognizedText.blocks.isEmpty) {
      return const OcrScanResult(candidateNames: []);
    }

    // Collect all lines with vertical bounding information
    final List<({String text, double top, double bottom})> positionedLines = [];
    final List<String> rawLines = [];

    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        final clean = line.text.trim();
        if (clean.isNotEmpty) {
          rawLines.add(clean);
          positionedLines.add((
            text: clean,
            top: line.boundingBox.top,
            bottom: line.boundingBox.bottom,
          ));
        }
      }
    }

    // Sort by vertical position (top of card first)
    positionedLines.sort((a, b) => a.top.compareTo(b.top));

    return parseLines(rawLines, orderedByTop: positionedLines.map((e) => e.text).toList());
  }

  /// Parses a flat list of text lines, with optional top-down ordering.
  static OcrScanResult parseLines(List<String> lines, {List<String>? orderedByTop}) {
    final candidateNames = <String>[];
    String? collectorNumber;
    String? setCode;
    String? totalInSet;

    final nameSource = orderedByTop ?? lines;

    // 1. Extract Collector Number & Set Code across all lines
    for (final line in lines) {
      // Check for Fraction pattern: "123/250"
      final fractionMatch = _fractionPattern.firstMatch(line);
      if (fractionMatch != null && collectorNumber == null) {
        collectorNumber = fractionMatch.group(1);
        totalInSet = fractionMatch.group(2);
      }

      // Check for Set Dash Number pattern: "SV01-151"
      final setDashMatch = _setDashNumberPattern.firstMatch(line);
      if (setDashMatch != null) {
        setCode ??= setDashMatch.group(1)?.toUpperCase();
        collectorNumber ??= setDashMatch.group(2);
      }

      // Check for "#123" or "No. 25"
      final hashMatch = _hashOrNoPattern.firstMatch(line);
      if (hashMatch != null && collectorNumber == null) {
        collectorNumber = hashMatch.group(1);
      }
    }

    // 2. Extract Candidate Card Names from top lines
    for (final line in nameSource) {
      final sanitized = _sanitizeCardName(line);
      if (sanitized != null && sanitized.isNotEmpty) {
        if (!candidateNames.contains(sanitized)) {
          candidateNames.add(sanitized);
        }
      }
      if (candidateNames.length >= 4) break;
    }

    return OcrScanResult(
      candidateNames: candidateNames,
      collectorNumber: collectorNumber,
      setCode: setCode,
      totalInSet: totalInSet,
      allLines: lines,
    );
  }

  /// Cleans and validates a text line as a possible card name.
  static String? _sanitizeCardName(String text) {
    var cleaned = text.trim();

    // Strip leading/trailing non-alphanumeric (keep spaces, apostrophes, hyphens)
    cleaned = cleaned.replaceAll(RegExp(r'^[^a-zA-Z0-9]+|[^a-zA-Z0-9]+$'), '');

    // Strip out common OCR artifacts like pipes, copyright symbols, etc.
    cleaned = cleaned.replaceAll(RegExp(r'[|©®™~_{}\\]'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (cleaned.length < 2) return null;

    // Check if purely numeric
    if (RegExp(r'^\d+$').hasMatch(cleaned)) return null;

    // Check if stat box like "5/5" or "10/10"
    if (RegExp(r'^\d+\s*/\s*\d+$').hasMatch(cleaned)) return null;

    final lower = cleaned.toLowerCase();

    // Check against copyright and publisher lines
    if (lower.contains('wizards of the coast') ||
        lower.contains('gamefreak') ||
        lower.contains('nintendo') ||
        lower.contains('creatures inc') ||
        lower.contains('illus.') ||
        lower.contains('illustrator')) {
      return null;
    }

    // Check if line is a card type line (e.g. "Creature — Dragon", "Instant", "Sorcery")
    if (lower.startsWith('creature') ||
        lower.startsWith('legendary creature') ||
        lower.startsWith('instant') ||
        lower.startsWith('sorcery') ||
        lower.startsWith('enchantment') ||
        lower.startsWith('artifact —') ||
        lower.startsWith('planeswalker') ||
        lower.startsWith('basic land')) {
      return null;
    }

    // Check against ignored exact tokens
    if (_ignoredNameTokens.contains(lower)) return null;

    // If starts with "HP" followed by number (e.g. "HP 120"), ignore
    if (RegExp(r'^hp\s*\d+', caseSensitive: false).hasMatch(lower)) return null;

    return cleaned;
  }
}
