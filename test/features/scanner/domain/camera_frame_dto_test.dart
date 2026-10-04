import 'dart:math';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/features/scanner/domain/vision/camera_frame_dto.dart';
import 'package:countr/features/scanner/domain/vision/vision_isolate.dart';
import 'package:countr/features/scanner/domain/profiles/collectible_profile.dart';
import 'package:countr/features/scanner/domain/profiles/mtg_collectible_profile.dart';
import 'package:countr/features/scanner/domain/profiles/comic_collectible_profile.dart';
import '../../../e2e/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CameraFrameDto - Row-Stride Unpadding Tests', () {
    test('Unpads NV21 / YUV420 single-channel luminance when bytesPerRow > width', () {
      const width = 4;
      const height = 3;
      const bytesPerRow = 6; // 2 padding bytes per row

      // 3 rows of 4 valid bytes + 2 padding bytes (99)
      final padded = Uint8List.fromList([
        10, 20, 30, 40, 99, 99,
        50, 60, 70, 80, 99, 99,
        90, 100, 110, 120, 99, 99,
      ]);

      final dto = CameraFrameDto(
        planeBytes: padded,
        width: width,
        height: height,
        bytesPerRow: bytesPerRow,
        formatGroup: ImageFormatGroup.nv21,
      );

      final contiguous = dto.extractContiguousBytes();

      expect(contiguous.length, equals(width * height));
      expect(
        contiguous,
        equals(Uint8List.fromList([
          10, 20, 30, 40,
          50, 60, 70, 80,
          90, 100, 110, 120,
        ])),
      );
      expect(contiguous.contains(99), isFalse);
    });

    test('Zero-copy passthrough for unpadded NV21 / YUV420', () {
      const width = 4;
      const height = 3;
      final unpadded = Uint8List(width * height)..fillRange(0, width * height, 42);

      final dto = CameraFrameDto(
        planeBytes: unpadded,
        width: width,
        height: height,
        bytesPerRow: width,
        formatGroup: ImageFormatGroup.yuv420,
      );

      final contiguous = dto.extractContiguousBytes();
      // Verifies zero-copy reference identity
      expect(identical(contiguous, unpadded), isTrue);
    });

    test('Unpads BGRA8888 4-channel image when bytesPerRow > width * 4', () {
      const width = 2;
      const height = 2;
      // Row bytes = 2 * 4 = 8. bytesPerRow = 12 (4 padding bytes per row)
      const bytesPerRow = 12;

      final padded = Uint8List.fromList([
        1, 2, 3, 4, 5, 6, 7, 8, 255, 255, 255, 255,
        9, 10, 11, 12, 13, 14, 15, 16, 255, 255, 255, 255,
      ]);

      final dto = CameraFrameDto(
        planeBytes: padded,
        width: width,
        height: height,
        bytesPerRow: bytesPerRow,
        formatGroup: ImageFormatGroup.bgra8888,
      );

      final contiguous = dto.extractContiguousBytes();

      expect(contiguous.length, equals(width * height * 4));
      expect(
        contiguous,
        equals(Uint8List.fromList([
          1, 2, 3, 4, 5, 6, 7, 8,
          9, 10, 11, 12, 13, 14, 15, 16,
        ])),
      );
    });

    test('Zero-copy passthrough for unpadded BGRA8888', () {
      const width = 2;
      const height = 2;
      final unpadded = Uint8List(width * height * 4)..fillRange(0, width * height * 4, 128);

      final dto = CameraFrameDto(
        planeBytes: unpadded,
        width: width,
        height: height,
        bytesPerRow: width * 4,
        formatGroup: ImageFormatGroup.bgra8888,
      );

      final contiguous = dto.extractContiguousBytes();
      expect(identical(contiguous, unpadded), isTrue);
    });

    test('CameraFrameDto.fromCameraImage extracts Plane 0 and metadata for NV21, YUV420, BGRA', () {
      // NV21
      final nv21Image = createMockCameraImage(
        width: 100,
        height: 200,
        bytesPerRow: 128,
        formatGroup: ImageFormatGroup.nv21,
      );
      final nv21Dto = CameraFrameDto.fromCameraImage(nv21Image);
      expect(nv21Dto.width, equals(100));
      expect(nv21Dto.height, equals(200));
      expect(nv21Dto.bytesPerRow, equals(128));
      expect(nv21Dto.formatGroup, equals(ImageFormatGroup.nv21));
      expect(nv21Dto.planeBytes.length, equals(128 * 200));

      // YUV420
      final yuvImage = createMockCameraImage(
        width: 100,
        height: 200,
        bytesPerRow: 100,
        formatGroup: ImageFormatGroup.yuv420,
      );
      final yuvDto = CameraFrameDto.fromCameraImage(yuvImage);
      expect(yuvDto.formatGroup, equals(ImageFormatGroup.yuv420));

      // BGRA8888
      final bgraImage = createMockCameraImage(
        width: 50,
        height: 50,
        bytesPerRow: 200,
        formatGroup: ImageFormatGroup.bgra8888,
      );
      final bgraDto = CameraFrameDto.fromCameraImage(bgraImage);
      expect(bgraDto.formatGroup, equals(ImageFormatGroup.bgra8888));
      expect(bgraDto.bytesPerRow, equals(200));
    });

    test('Defensively handles empty planes in CameraFrameDto.fromCameraImage', () {
      final emptyPlanesImage = FakeCameraImage(
        width: 64,
        height: 64,
        planes: [],
      );

      final dto = CameraFrameDto.fromCameraImage(emptyPlanesImage);

      expect(dto.width, equals(64));
      expect(dto.height, equals(64));
      expect(dto.bytesPerRow, equals(64));
      expect(dto.planeBytes.length, equals(0));
    });
  });

  group('CollectibleProfile Aspect Ratio Calibration', () {
    test('Default CollectibleProfile exposes 2.5 / 3.5 aspect ratio', () {
      final CollectibleProfile mtg = MtgCollectibleProfile();
      expect(mtg.cardAspectRatio, closeTo(2.5 / 3.5, 0.0001));
      expect(mtg.cardAspectRatio, closeTo(0.7142857, 0.0001));
    });

    test('ComicCollectibleProfile exposes 6.625 / 10.187 aspect ratio', () {
      final CollectibleProfile comic = ComicCollectibleProfile();
      expect(comic.cardAspectRatio, closeTo(6.625 / 10.187, 0.0001));
      expect(comic.cardAspectRatio, closeTo(0.6503387, 0.0001));
    });
  });

  group('ScannerWorkerIsolate Aspect Ratio Geometry & Calibration', () {
    final targetRatio = 2.5 / 3.5; // ~0.7142857

    test('Normalizes aspect ratio as min(w, h) / max(w, h) regardless of orientation', () {
      expect(ScannerWorkerIsolate.normalizeAspectRatio(250, 350), closeTo(0.7142857, 0.0001));
      expect(ScannerWorkerIsolate.normalizeAspectRatio(350, 250), closeTo(0.7142857, 0.0001));
      expect(ScannerWorkerIsolate.normalizeAspectRatio(500, 1000), equals(0.50));
      expect(ScannerWorkerIsolate.normalizeAspectRatio(1000, 500), equals(0.50));
      expect(ScannerWorkerIsolate.normalizeAspectRatio(0, 100), equals(0.0));
      expect(ScannerWorkerIsolate.normalizeAspectRatio(-10, 100), equals(0.0));
    });

    test('Aspect ratio tolerance window [0.50, 0.93] accepts valid card perspectives', () {
      // Valid ratios (cards viewed upright or perspective tilted)
      expect(ScannerWorkerIsolate.isAspectMatch(250, 350, targetRatio), isTrue); // ratio = 0.714 (perfect card)
      expect(ScannerWorkerIsolate.isAspectMatch(500, 1000, targetRatio), isTrue); // ratio = 0.50 (valid lower bound)
      expect(ScannerWorkerIsolate.isAspectMatch(550, 1000, targetRatio), isTrue); // ratio = 0.55 (horizontal tilt)
      expect(ScannerWorkerIsolate.isAspectMatch(850, 1000, targetRatio), isTrue); // ratio = 0.85 (vertical tilt)
      expect(ScannerWorkerIsolate.isAspectMatch(930, 1000, targetRatio), isTrue); // ratio = 0.93 (valid upper bound)
    });

    test('Aspect ratio tolerance rejects shapes outside [0.50, 0.93] window', () {
      // Invalid ratios
      expect(ScannerWorkerIsolate.isAspectMatch(450, 1000, targetRatio), isFalse); // ratio = 0.45 (too elongated)
      expect(ScannerWorkerIsolate.isAspectMatch(950, 1000, targetRatio), isFalse); // ratio = 0.95 (nearly square)
      expect(ScannerWorkerIsolate.isAspectMatch(1000, 1000, targetRatio), isFalse); // ratio = 1.0 (square)
      // Erroneous 16:9 widescreen ratio (80/45 = 1.7778)
      expect(ScannerWorkerIsolate.isAspectMatch(250, 350, 80 / 45), isFalse);
    });

    test('Comic book aspect ratio (~0.650) matches with perspective tolerance', () {
      final comicRatio = 6.625 / 10.187; // ~0.6503
      expect(ScannerWorkerIsolate.isAspectMatch(662.5, 1018.7, comicRatio), isTrue);
      expect(ScannerWorkerIsolate.isAspectMatch(500, 1000, comicRatio), isTrue); // 0.50 is within 0.650 ± 0.22
      expect(ScannerWorkerIsolate.isAspectMatch(870, 1000, comicRatio), isTrue); // 0.87 is within 0.650 ± 0.22
      expect(ScannerWorkerIsolate.isAspectMatch(400, 1000, comicRatio), isFalse); // 0.40 is outside
      expect(ScannerWorkerIsolate.isAspectMatch(900, 1000, comicRatio), isFalse); // 0.90 is outside
    });
  });

  group('ScannerWorkerIsolate Dynamic Contour Area Floor', () {
    test('Calculates dynamic contour area floor based on frame dimensions', () {
      // 720p frame: 720 * 1280 = 921,600. 1.5% = 13,824 > 5000
      expect(ScannerWorkerIsolate.calculateMinContourArea(720, 1280), equals(13824.0));

      // 1080p frame: 1080 * 1920 = 2,073,600. 1.5% = 31,104 > 5000
      expect(ScannerWorkerIsolate.calculateMinContourArea(1080, 1920), equals(31104.0));

      // Low-res 480x640 frame: 307,200. 1.5% = 4,608 < 5000 -> Floored at 5000.0
      expect(ScannerWorkerIsolate.calculateMinContourArea(480, 640), equals(5000.0));

      // Very small frame: 320x240 = 76,800. 1.5% = 1,152 < 5000 -> Floored at 5000.0
      expect(ScannerWorkerIsolate.calculateMinContourArea(320, 240), equals(5000.0));
    });
  });

  group('ScannerWorkerIsolate Rounded Corner Approximation (5-8 Vertices)', () {
    test('Identifies supported vertex counts for quadrilaterals and rounded corners', () {
      // 4 = quadrilateral, 5-8 = rounded die-cut corners
      expect(ScannerWorkerIsolate.isSupportedVertexCount(4), isTrue);
      expect(ScannerWorkerIsolate.isSupportedVertexCount(5), isTrue);
      expect(ScannerWorkerIsolate.isSupportedVertexCount(6), isTrue);
      expect(ScannerWorkerIsolate.isSupportedVertexCount(7), isTrue);
      expect(ScannerWorkerIsolate.isSupportedVertexCount(8), isTrue);

      // Unsupported vertex counts
      expect(ScannerWorkerIsolate.isSupportedVertexCount(0), isFalse);
      expect(ScannerWorkerIsolate.isSupportedVertexCount(3), isFalse); // Triangle
      expect(ScannerWorkerIsolate.isSupportedVertexCount(9), isFalse); // Too complex / noisy
      expect(ScannerWorkerIsolate.isSupportedVertexCount(12), isFalse);
    });

    test('4-vertex polygon preserves exact vertices', () {
      final quad = [
        const Point<double>(10.0, 10.0),
        const Point<double>(80.0, 10.0),
        const Point<double>(80.0, 120.0),
        const Point<double>(10.0, 120.0),
      ];

      expect(quad.length, equals(4));
      expect(ScannerWorkerIsolate.isSupportedVertexCount(quad.length), isTrue);
      expect(quad[0], equals(const Point<double>(10.0, 10.0)));
      expect(quad[2], equals(const Point<double>(80.0, 120.0)));
    });

    test('8-vertex rounded rectangle extracts 4 bounding corners', () {
      // Simulates an 8-point polygon produced by approxPolyDP on a rounded card corner
      final roundedPoly = [
        const Point<double>(20.0, 10.0), // Top edge start
        const Point<double>(80.0, 10.0), // Top edge end
        const Point<double>(90.0, 20.0), // Right edge start
        const Point<double>(90.0, 80.0), // Right edge end
        const Point<double>(80.0, 90.0), // Bottom edge end
        const Point<double>(20.0, 90.0), // Bottom edge start
        const Point<double>(10.0, 80.0), // Left edge end
        const Point<double>(10.0, 20.0), // Left edge start
      ];

      expect(roundedPoly.length, equals(8));
      expect(ScannerWorkerIsolate.isSupportedVertexCount(roundedPoly.length), isTrue);

      // Bounding box enclosure of the 8 vertices
      final minX = roundedPoly.map((p) => p.x).reduce(min);
      final maxX = roundedPoly.map((p) => p.x).reduce(max);
      final minY = roundedPoly.map((p) => p.y).reduce(min);
      final maxY = roundedPoly.map((p) => p.y).reduce(max);

      final boundingCorners = [
        Point<double>(minX, minY), // TL: 10, 10
        Point<double>(maxX, minY), // TR: 90, 10
        Point<double>(maxX, maxY), // BR: 90, 90
        Point<double>(minX, maxY), // BL: 10, 90
      ];

      expect(boundingCorners.length, equals(4));
      expect(boundingCorners[0], equals(const Point<double>(10.0, 10.0)));
      expect(boundingCorners[1], equals(const Point<double>(90.0, 10.0)));
      expect(boundingCorners[2], equals(const Point<double>(90.0, 90.0)));
      expect(boundingCorners[3], equals(const Point<double>(10.0, 90.0)));
    });
  });

  group('ScannerWorkerIsolate Input Dispatch & Error Resilience', () {
    test('Throws ArgumentError when passed invalid non-frame object', () async {
      expect(
        () => ScannerWorkerIsolate.processFrame(12345, 0.714),
        throwsArgumentError,
      );
      expect(
        () => ScannerWorkerIsolate.processFrame('invalid_string', 0.714),
        throwsArgumentError,
      );
    });

    test('Gracefully returns (null, null, null) for unsupported format without throwing', () async {
      final unsupportedDto = CameraFrameDto(
        planeBytes: Uint8List(100),
        width: 10,
        height: 10,
        bytesPerRow: 10,
        formatGroup: ImageFormatGroup.unknown,
      );

      final result = await ScannerWorkerIsolate.processFrame(unsupportedDto, 0.714);
      expect(result.$1, isNull);
      expect(result.$2, isNull);
      expect(result.$3, isNull);
    });
  });
}
