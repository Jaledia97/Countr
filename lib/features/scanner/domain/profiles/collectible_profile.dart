import 'dart:math';

abstract class CollectibleProfile {
  /// Defines the collection type this profile targets (e.g. 'mtg', 'comics').
  /// If null, matches across all collection types.
  String? get collectionType => null;

  /// Physical aspect ratio of the collectible (width / height, where width < height).
  /// For standard trading cards (2.5" x 3.5"), this is 2.5 / 3.5 ≈ 0.714.
  double get cardAspectRatio => 2.5 / 3.5;

  /// Defines the aspect ratio or bounds for cropping the art window.
  Rectangle<int> get artCropBounds;

  /// Whether barcode scanning (Tier 0) is enabled for this profile.
  bool get enableBarcodeScanning;

  /// Extracts the collector number (e.g., "123/250" or "045") from OCR text.
  String? extractCollectorNumber(String ocrText);

  /// Cleans and extracts the title from the OCR block.
  String? extractTitle(String ocrText);
  
  /// Helper to sanitize title strings
  String sanitizeTitle(String rawTitle) {
    return rawTitle.replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '').trim().toLowerCase();
  }
}
