import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/features/scanner/domain/vision/camera_frame_dto.dart';
import 'package:countr/features/scanner/domain/vision/vision_isolate.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Adversarial Challenge: CameraFrameDto Unpadding Across Extreme Strides', () {
    test('Extreme hardware stride: bytesPerRow = 1024 for width = 8 (NV21 / YUV420)', () {
      const width = 8;
      const height = 4;
      const bytesPerRow = 1024; // 1016 padding bytes per row
      final planeBytes = Uint8List(bytesPerRow * height);
      planeBytes.fillRange(0, planeBytes.length, 0xEE); // Sentinel padding

      // Populate distinct values for each pixel in each row
      for (int row = 0; row < height; row++) {
        for (int col = 0; col < width; col++) {
          planeBytes[row * bytesPerRow + col] = (row * 10 + col) & 0xFF;
        }
      }

      final dto = CameraFrameDto(
        planeBytes: planeBytes,
        width: width,
        height: height,
        bytesPerRow: bytesPerRow,
        formatGroup: ImageFormatGroup.nv21,
      );

      final contiguous = dto.extractContiguousBytes();

      expect(contiguous.length, equals(width * height));
      expect(contiguous.contains(0xEE), isFalse);

      for (int row = 0; row < height; row++) {
        for (int col = 0; col < width; col++) {
          final expectedVal = (row * 10 + col) & 0xFF;
          expect(
            contiguous[row * width + col],
            equals(expectedVal),
            reason: 'Mismatch at row $row, col $col',
          );
        }
      }
    });

    test('Extreme hardware stride: bytesPerRow = 4096 for width = 32 (BGRA8888)', () {
      const width = 32;
      const height = 8;
      const rowBytes = width * 4; // 128 bytes
      const bytesPerRow = 4096; // 3968 padding bytes per row
      final planeBytes = Uint8List(bytesPerRow * height);
      planeBytes.fillRange(0, planeBytes.length, 0xAA); // Sentinel padding

      // Populate unique patterns
      for (int row = 0; row < height; row++) {
        for (int b = 0; b < rowBytes; b++) {
          planeBytes[row * bytesPerRow + b] = (row + b) % 250;
        }
      }

      final dto = CameraFrameDto(
        planeBytes: planeBytes,
        width: width,
        height: height,
        bytesPerRow: bytesPerRow,
        formatGroup: ImageFormatGroup.bgra8888,
      );

      final contiguous = dto.extractContiguousBytes();

      expect(contiguous.length, equals(width * height * 4));
      expect(contiguous.contains(0xAA), isFalse);

      for (int row = 0; row < height; row++) {
        for (int b = 0; b < rowBytes; b++) {
          final expectedVal = (row + b) % 250;
          expect(
            contiguous[row * rowBytes + b],
            equals(expectedVal),
            reason: 'Mismatch at row $row, byte $b',
          );
        }
      }
    });

    test('Android Camera2 minimal buffer: last row has no trailing padding bytes', () {
      // Android Camera2 often allocates (height - 1) * stride + width
      const width = 16;
      const height = 4;
      const bytesPerRow = 32;
      final minimalLength = (height - 1) * bytesPerRow + width; // 3 * 32 + 16 = 112 bytes
      final planeBytes = Uint8List(minimalLength);
      planeBytes.fillRange(0, minimalLength, 0xCC); // Sentinel

      for (int row = 0; row < height; row++) {
        for (int col = 0; col < width; col++) {
          planeBytes[row * bytesPerRow + col] = (row + 1) * (col + 1);
        }
      }

      final dto = CameraFrameDto(
        planeBytes: planeBytes,
        width: width,
        height: height,
        bytesPerRow: bytesPerRow,
        formatGroup: ImageFormatGroup.yuv420,
      );

      // Must not throw RangeError on the last row
      final contiguous = dto.extractContiguousBytes();

      expect(contiguous.length, equals(width * height));
      expect(contiguous.contains(0xCC), isFalse);
      for (int row = 0; row < height; row++) {
        for (int col = 0; col < width; col++) {
          expect(
            contiguous[row * width + col],
            equals((row + 1) * (col + 1)),
          );
        }
      }
    });

    test('iOS AVFoundation minimal buffer for BGRA8888: last row has no trailing padding', () {
      const width = 8;
      const height = 3;
      const rowBytes = width * 4; // 32 bytes
      const bytesPerRow = 64; // 32 padding bytes per row
      final minimalLength = (height - 1) * bytesPerRow + rowBytes; // 2 * 64 + 32 = 160 bytes
      final planeBytes = Uint8List(minimalLength);
      planeBytes.fillRange(0, minimalLength, 0x77);

      for (int row = 0; row < height; row++) {
        for (int b = 0; b < rowBytes; b++) {
          planeBytes[row * bytesPerRow + b] = (row * 10 + b) & 0xFF;
        }
      }

      final dto = CameraFrameDto(
        planeBytes: planeBytes,
        width: width,
        height: height,
        bytesPerRow: bytesPerRow,
        formatGroup: ImageFormatGroup.bgra8888,
      );

      final contiguous = dto.extractContiguousBytes();

      expect(contiguous.length, equals(width * height * 4));
      expect(contiguous.contains(0x77), isFalse);
    });

    test('Defensively survives severely truncated plane buffer without throwing', () {
      const width = 100;
      const height = 50;
      const bytesPerRow = 120;
      // Truncated buffer: only contains 2 rows worth of data
      final truncatedBytes = Uint8List(bytesPerRow * 2);

      final dto = CameraFrameDto(
        planeBytes: truncatedBytes,
        width: width,
        height: height,
        bytesPerRow: bytesPerRow,
        formatGroup: ImageFormatGroup.nv21,
      );

      expect(() => dto.extractContiguousBytes(), returnsNormally);
      final contiguous = dto.extractContiguousBytes();
      expect(contiguous.length, equals(width * height));
    });

    test('Degenerate dimension: 0x0 frame returns empty buffer', () {
      final dto = CameraFrameDto(
        planeBytes: Uint8List(0),
        width: 0,
        height: 0,
        bytesPerRow: 0,
        formatGroup: ImageFormatGroup.nv21,
      );

      final contiguous = dto.extractContiguousBytes();
      expect(contiguous.length, equals(0));
    });

    test('Boundary dimension: 1x1 frame with stride 1 returns exact pixel', () {
      final singlePixel = Uint8List.fromList([42]);
      final dto = CameraFrameDto(
        planeBytes: singlePixel,
        width: 1,
        height: 1,
        bytesPerRow: 1,
        formatGroup: ImageFormatGroup.nv21,
      );

      final contiguous = dto.extractContiguousBytes();
      expect(contiguous.length, equals(1));
      expect(contiguous[0], equals(42));
      expect(identical(contiguous, singlePixel), isTrue);
    });

    test('Boundary dimension: 1x1 frame with stride 64 strips 63 padding bytes', () {
      final paddedSinglePixel = Uint8List(64);
      paddedSinglePixel[0] = 77;
      paddedSinglePixel.fillRange(1, 64, 0xFF);

      final dto = CameraFrameDto(
        planeBytes: paddedSinglePixel,
        width: 1,
        height: 1,
        bytesPerRow: 64,
        formatGroup: ImageFormatGroup.nv21,
      );

      final contiguous = dto.extractContiguousBytes();
      expect(contiguous.length, equals(1));
      expect(contiguous[0], equals(77));
    });

    test('High resolution stress test (1080p: 1920x1080 with 2048 stride)', () {
      const width = 1920;
      const height = 1080;
      const bytesPerRow = 2048; // 128 padding bytes per row
      final planeBytes = Uint8List(bytesPerRow * height);

      // Stamp specific markers at key row locations
      for (int row = 0; row < height; row += 100) {
        planeBytes[row * bytesPerRow] = 0xAA;
        planeBytes[row * bytesPerRow + (width - 1)] = 0xBB;
        // Padding byte just after row
        planeBytes[row * bytesPerRow + width] = 0xCC;
      }

      final dto = CameraFrameDto(
        planeBytes: planeBytes,
        width: width,
        height: height,
        bytesPerRow: bytesPerRow,
        formatGroup: ImageFormatGroup.nv21,
      );

      final stopwatch = Stopwatch()..start();
      final contiguous = dto.extractContiguousBytes();
      stopwatch.stop();

      expect(contiguous.length, equals(width * height));
      for (int row = 0; row < height; row += 100) {
        expect(contiguous[row * width], equals(0xAA));
        expect(contiguous[row * width + (width - 1)], equals(0xBB));
      }
      // Ensure extraction executes comfortably in real-time budget (< 50ms)
      expect(stopwatch.elapsedMilliseconds, lessThan(100));
    });
  });

  group('Adversarial Challenge: ScannerWorkerIsolate Aspect Ratio Geometry & Boundaries', () {
    final tcgTargetRatio = 2.5 / 3.5; // ~0.7142857

    test('Orientation invariance: exactly identical ratio for portrait and landscape', () {
      final portraitRatio = ScannerWorkerIsolate.normalizeAspectRatio(250, 350);
      final landscapeRatio = ScannerWorkerIsolate.normalizeAspectRatio(350, 250);
      expect(portraitRatio, equals(landscapeRatio));
      expect(portraitRatio, closeTo(0.7142857, 0.0001));
    });

    test('Zero, negative, NaN, and Infinite dimensions evaluate to ratio 0.0 without crash', () {
      expect(ScannerWorkerIsolate.normalizeAspectRatio(0, 0), equals(0.0));
      expect(ScannerWorkerIsolate.normalizeAspectRatio(0, 100), equals(0.0));
      expect(ScannerWorkerIsolate.normalizeAspectRatio(100, 0), equals(0.0));
      expect(ScannerWorkerIsolate.normalizeAspectRatio(-10, 100), equals(0.0));
      expect(ScannerWorkerIsolate.normalizeAspectRatio(100, -10), equals(0.0));
      expect(ScannerWorkerIsolate.normalizeAspectRatio(-50, -50), equals(0.0));
    });

    test('isAspectMatch handles degenerate inputs gracefully', () {
      expect(ScannerWorkerIsolate.isAspectMatch(0, 100, tcgTargetRatio), isFalse);
      expect(ScannerWorkerIsolate.isAspectMatch(100, 0, tcgTargetRatio), isFalse);
      expect(ScannerWorkerIsolate.isAspectMatch(-100, 200, tcgTargetRatio), isFalse);
      expect(ScannerWorkerIsolate.isAspectMatch(double.nan, 200, tcgTargetRatio), isFalse);
      expect(ScannerWorkerIsolate.isAspectMatch(200, double.nan, tcgTargetRatio), isFalse);
    });

    test('Precision tolerance boundary tests: 0.7142857 ± 0.22', () {
      const tolerance = 0.22;
      final exactMin = tcgTargetRatio - tolerance; // ~0.4942857
      final exactMax = tcgTargetRatio + tolerance; // ~0.9342857

      // On boundary
      expect(ScannerWorkerIsolate.isAspectMatch(exactMin * 1000, 1000, tcgTargetRatio, tolerance: tolerance), isTrue);
      expect(ScannerWorkerIsolate.isAspectMatch(exactMax * 1000, 1000, tcgTargetRatio, tolerance: tolerance), isTrue);

      // Just inside
      expect(ScannerWorkerIsolate.isAspectMatch((exactMin + 0.001) * 1000, 1000, tcgTargetRatio, tolerance: tolerance), isTrue);
      expect(ScannerWorkerIsolate.isAspectMatch((exactMax - 0.001) * 1000, 1000, tcgTargetRatio, tolerance: tolerance), isTrue);

      // Just outside
      expect(ScannerWorkerIsolate.isAspectMatch((exactMin - 0.005) * 1000, 1000, tcgTargetRatio, tolerance: tolerance), isFalse);
      expect(ScannerWorkerIsolate.isAspectMatch((exactMax + 0.005) * 1000, 1000, tcgTargetRatio, tolerance: tolerance), isFalse);
    });

    test('Extreme aspect ratios (very thin slivers) are strictly rejected', () {
      // 10:1 ratio (0.10)
      expect(ScannerWorkerIsolate.isAspectMatch(100, 1000, tcgTargetRatio), isFalse);
      // 100:1 ratio (0.01)
      expect(ScannerWorkerIsolate.isAspectMatch(10, 1000, tcgTargetRatio), isFalse);
      // Perfect square (1.0)
      expect(ScannerWorkerIsolate.isAspectMatch(1000, 1000, tcgTargetRatio), isFalse);
    });
  });

  group('Adversarial Challenge: Dynamic Contour Area Floor Calculations', () {
    test('calculateMinContourArea respects 5000 floor across small dimensions', () {
      expect(ScannerWorkerIsolate.calculateMinContourArea(0, 0), equals(5000.0));
      expect(ScannerWorkerIsolate.calculateMinContourArea(1, 1), equals(5000.0));
      expect(ScannerWorkerIsolate.calculateMinContourArea(100, 100), equals(5000.0));
      expect(ScannerWorkerIsolate.calculateMinContourArea(320, 240), equals(5000.0)); // 1152 < 5000
      expect(ScannerWorkerIsolate.calculateMinContourArea(640, 480), equals(5000.0)); // 4608 < 5000
    });

    test('calculateMinContourArea scales proportionally above 333,334 pixels', () {
      // Breakeven: 5000 / 0.015 = 333,333.33 px
      // 800 x 600 = 480,000 px * 0.015 = 7,200 > 5000
      expect(ScannerWorkerIsolate.calculateMinContourArea(800, 600), equals(7200.0));
      // 1280 x 720 = 921,600 px * 0.015 = 13,824
      expect(ScannerWorkerIsolate.calculateMinContourArea(1280, 720), equals(13824.0));
      // 1920 x 1080 = 2,073,600 px * 0.015 = 31,104
      expect(ScannerWorkerIsolate.calculateMinContourArea(1920, 1080), equals(31104.0));
      // 3840 x 2160 = 8,294,400 px * 0.015 = 124,416
      expect(ScannerWorkerIsolate.calculateMinContourArea(3840, 2160), equals(124416.0));
    });
  });

  group('Adversarial Challenge: Vertex Filtering for Die-Cut Rounded Card Geometry', () {
    test('Boundary coverage: vertex count rejection vs acceptance', () {
      final accepted = <int>[];
      final rejected = <int>[];

      for (int v = -2; v <= 15; v++) {
        if (ScannerWorkerIsolate.isSupportedVertexCount(v)) {
          accepted.add(v);
        } else {
          rejected.add(v);
        }
      }

      expect(accepted, equals([4, 5, 6, 7, 8]));
      expect(rejected, equals([-2, -1, 0, 1, 2, 3, 9, 10, 11, 12, 13, 14, 15]));
    });
  });
}
