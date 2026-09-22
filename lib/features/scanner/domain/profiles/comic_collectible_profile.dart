import 'dart:math';
import 'collectible_profile.dart';

class ComicCollectibleProfile extends CollectibleProfile {
  @override
  String get collectionType => 'comics';

  @override
  Rectangle<int> get artCropBounds => const Rectangle(0, 0, 100, 100); // Full cover

  @override
  bool get enableBarcodeScanning => true; // Direct Market barcodes

  @override
  String? extractCollectorNumber(String ocrText) {
    // Matches #123, # 123, No. 123, Issue 123, or #123/250
    final match = RegExp(r'(?:#|No\.?|Issue)\s*(\d+)', caseSensitive: false).firstMatch(ocrText);
    return match?.group(1);
  }

  @override
  String? extractTitle(String ocrText) {
    final lines = ocrText.split('\n').where((l) => l.trim().isNotEmpty);
    for (final line in lines) {
      final trimmed = line.trim();
      // Skip corner box issue number lines (e.g. "#300", "#300 $1.50", "No. 12", "Issue 5"), fraction numbers, or barcodes
      if (RegExp(r'^(?:#|No\.?|Issue)\s*\d+', caseSensitive: false).hasMatch(trimmed) ||
          RegExp(r'^\d{1,4}\s*/\s*\d{1,4}').hasMatch(trimmed) ||
          RegExp(r'^\d{12,13}$').hasMatch(trimmed)) {
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
