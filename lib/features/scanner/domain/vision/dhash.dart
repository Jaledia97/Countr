import 'dart:typed_data';

class DHash {
  /// Computes a 64-bit dHash of the provided grayscale image buffer.
  /// Assumes the [grayscalePixels] is already resized to 9x8.
  /// Compares adjacent horizontal pixels to generate an unsigned 64-bit integer.
  static int calculate(Uint8List grayscalePixels) {
    if (grayscalePixels.length < 72) return 0;
    int hash = 0;
    int bitIndex = 0;

    for (int y = 0; y < 8; y++) {
      for (int x = 0; x < 8; x++) {
        final leftIndex = y * 9 + x;
        final rightIndex = y * 9 + (x + 1);
        final leftPixel = grayscalePixels[leftIndex];
        final rightPixel = grayscalePixels[rightIndex];

        if (leftPixel < rightPixel) {
          hash |= (1 << bitIndex);
        }
        bitIndex++;
      }
    }

    return hash;
  }

  /// Hamming Distance Calculator using Brian Kernighan's bit-count algorithm.
  static int hammingDistance(int hash1, int hash2) {
    int x = hash1 ^ hash2;
    int setBits = 0;

    while (x != 0) {
      x &= (x - 1);
      setBits++;
    }

    return setBits;
  }
}
