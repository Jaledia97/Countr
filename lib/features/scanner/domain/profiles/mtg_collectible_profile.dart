import 'dart:math';
import 'collectible_profile.dart';

class MtgCollectibleProfile extends CollectibleProfile {
  @override
  String get collectionType => 'mtg';

  @override
  Rectangle<int> get artCropBounds => const Rectangle(10, 10, 80, 45); // Relative percentages

  @override
  bool get enableBarcodeScanning => false;

  @override
  String? extractCollectorNumber(String ocrText) {
    final match = RegExp(r'\b\d{1,4}\s*/\s*\d{1,4}\b').firstMatch(ocrText);
    return match?.group(0)?.replaceAll(' ', '');
  }

  @override
  String? extractTitle(String ocrText) {
    final lines = ocrText.split('\n').where((l) => l.trim().isNotEmpty);
    for (final line in lines) {
      final trimmed = line.trim();
      // Skip collector number lines (including rarity suffix like "001/292 M"), bottom metadata lines like "M10 • EN", or artist/copyright lines
      if (RegExp(r'^\d{1,4}\s*/\s*\d{1,4}', caseSensitive: false).hasMatch(trimmed) ||
          RegExp(r'^[A-Z0-9]{3,5}\s*[•·\-\*]\s*[A-Z]{2}', caseSensitive: false).hasMatch(trimmed) ||
          RegExp(r'^(?:Illus\.?|©|\(C\)|TM\b)', caseSensitive: false).hasMatch(trimmed)) {
        continue;
      }
      final sanitized = sanitizeTitle(trimmed);
      if (sanitized.isNotEmpty) {
        return sanitized;
      }
    }
    return null;
  }
}
