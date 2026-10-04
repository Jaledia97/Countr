import 'dart:math' as math;
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/features/scanner/domain/card_perimeter_calculator.dart';
import 'package:countr/features/scanner/domain/vision/camera_frame_dto.dart';
import 'package:countr/features/scanner/presentation/widgets/dynamic_scanner_overlay.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // =========================================================================
  // TASK 1: NV21 STRIDE PADDING WITH IRREGULAR HARDWARE STRIDES
  // =========================================================================
  group('Challenger M4-2 (Task 1): NV21 Irregular Hardware Stride Empirical Verification', () {
    test('Android 1080p camera: irregular hardware stride 1088 vs 1080 (Qualcomm 16-byte alignment)', () {
      const width = 1080;
      const height = 1920;
      const bytesPerRow = 1088; // 8 padding bytes per row
      final totalPaddedBytes = bytesPerRow * height;

      // Allocate buffer with synthetic 2D signal in [0, 200] and sentinel 255 for padding
      final paddedBuffer = Uint8List(totalPaddedBytes);
      const sentinel = 255;

      for (int r = 0; r < height; r++) {
        final rowOffset = r * bytesPerRow;
        for (int c = 0; c < width; c++) {
          // Synthetic deterministic 2D pixel signal in range [0, 200]
          paddedBuffer[rowOffset + c] = (c * 17 + r * 31) % 201;
        }
        // Sentinel padding bytes strictly set to 255
        for (int p = width; p < bytesPerRow; p++) {
          paddedBuffer[rowOffset + p] = sentinel;
        }
      }

      final dto = CameraFrameDto(
        planeBytes: paddedBuffer,
        width: width,
        height: height,
        bytesPerRow: bytesPerRow,
        formatGroup: ImageFormatGroup.nv21,
      );

      final contiguous = dto.extractContiguousBytes();

      // Invariant 1: Contiguous buffer length matches exact width * height
      expect(contiguous.length, equals(width * height));

      // Invariant 2: Every pixel in contiguous buffer matches the exact (x, y) signal
      bool hasMismatch = false;
      int mismatchRow = -1;
      int mismatchCol = -1;

      for (int r = 0; r < height; r++) {
        final contiguousRowOffset = r * width;
        for (int c = 0; c < width; c++) {
          final expected = (c * 17 + r * 31) % 201;
          final actual = contiguous[contiguousRowOffset + c];
          if (actual != expected) {
            hasMismatch = true;
            mismatchRow = r;
            mismatchCol = c;
            break;
          }
        }
        if (hasMismatch) break;
      }

      expect(hasMismatch, isFalse,
          reason: 'Pixel signal corrupted at row $mismatchRow, col $mismatchCol due to stride misalignment');

      // Invariant 3: Zero sentinel padding bytes leaked into contiguous buffer
      expect(contiguous.contains(sentinel), isFalse,
          reason: 'Stride padding bytes (0xEE) leaked into contiguous luminance buffer');
    });

    test('Qualcomm/Snapdragon 64-byte alignment: 1080p with stride 1152 (72 padding bytes per row)', () {
      const width = 1080;
      const height = 1920;
      const bytesPerRow = 1152;
      final paddedBuffer = Uint8List(bytesPerRow * height);

      for (int r = 0; r < height; r++) {
        final rowOffset = r * bytesPerRow;
        for (int c = 0; c < width; c++) {
          paddedBuffer[rowOffset + c] = (c ^ r) & 0xFF;
        }
        for (int p = width; p < bytesPerRow; p++) {
          paddedBuffer[rowOffset + p] = 0xFE;
        }
      }

      final dto = CameraFrameDto(
        planeBytes: paddedBuffer,
        width: width,
        height: height,
        bytesPerRow: bytesPerRow,
        formatGroup: ImageFormatGroup.nv21,
      );

      final contiguous = dto.extractContiguousBytes();
      expect(contiguous.length, equals(width * height));

      // Spot-check coordinates across corners, edges, and center
      final spotChecks = [
        const math.Point(0, 0),
        const math.Point(1079, 0),
        const math.Point(0, 1919),
        const math.Point(1079, 1919),
        const math.Point(540, 960),
        const math.Point(1078, 500),
      ];

      for (final pt in spotChecks) {
        final expected = (pt.x ^ pt.y) & 0xFF;
        final actual = contiguous[pt.y * width + pt.x];
        expect(actual, equals(expected), reason: 'Spot-check failed at ($pt.x, $pt.y)');
      }
    });

    test('Heavy GPU texture alignment: 1080p with stride 2048 (968 padding bytes per row)', () {
      const width = 1080;
      const height = 100; // 100 rows to test heavy padding without excessive memory
      const bytesPerRow = 2048;
      final paddedBuffer = Uint8List(bytesPerRow * height);

      for (int r = 0; r < height; r++) {
        final rowOffset = r * bytesPerRow;
        paddedBuffer[rowOffset] = (r + 1) & 0xFF; // First pixel of row
        paddedBuffer[rowOffset + width - 1] = (r + 2) & 0xFF; // Last pixel of row
      }

      final dto = CameraFrameDto(
        planeBytes: paddedBuffer,
        width: width,
        height: height,
        bytesPerRow: bytesPerRow,
        formatGroup: ImageFormatGroup.nv21,
      );

      final contiguous = dto.extractContiguousBytes();
      expect(contiguous.length, equals(width * height));

      for (int r = 0; r < height; r++) {
        expect(contiguous[r * width], equals((r + 1) & 0xFF));
        expect(contiguous[r * width + width - 1], equals((r + 2) & 0xFF));
      }
    });

    test('Android Camera2 truncated trailing row: buffer omits padding on last row', () {
      const width = 1080;
      const height = 1920;
      const bytesPerRow = 1088;
      // Some Android devices allocate exactly (height - 1) * bytesPerRow + width
      final truncatedLength = (height - 1) * bytesPerRow + width;
      final truncatedBuffer = Uint8List(truncatedLength);

      // Mark the very last valid pixel
      truncatedBuffer[truncatedLength - 1] = 0xAA;

      final dto = CameraFrameDto(
        planeBytes: truncatedBuffer,
        width: width,
        height: height,
        bytesPerRow: bytesPerRow,
        formatGroup: ImageFormatGroup.nv21,
      );

      // Must NOT throw RangeError or index out of bounds
      final contiguous = dto.extractContiguousBytes();
      expect(contiguous.length, equals(width * height));
      expect(contiguous.last, equals(0xAA));
    });

    test('Zero-copy passthrough optimization verification', () {
      const width = 1080;
      const height = 1920;
      final unpaddedBuffer = Uint8List(width * height);

      final dtoNv21 = CameraFrameDto(
        planeBytes: unpaddedBuffer,
        width: width,
        height: height,
        bytesPerRow: width,
        formatGroup: ImageFormatGroup.nv21,
      );

      final contiguousNv21 = dtoNv21.extractContiguousBytes();
      // Zero-copy reference equality
      expect(identical(contiguousNv21, unpaddedBuffer), isTrue);

      final dtoYuv420 = CameraFrameDto(
        planeBytes: unpaddedBuffer,
        width: width,
        height: height,
        bytesPerRow: width,
        formatGroup: ImageFormatGroup.yuv420,
      );
      expect(identical(dtoYuv420.extractContiguousBytes(), unpaddedBuffer), isTrue);

      // Padded buffer MUST NOT be identical (requires copy)
      final paddedBuffer = Uint8List(1088 * 1920);
      final dtoPadded = CameraFrameDto(
        planeBytes: paddedBuffer,
        width: width,
        height: height,
        bytesPerRow: 1088,
        formatGroup: ImageFormatGroup.nv21,
      );
      expect(identical(dtoPadded.extractContiguousBytes(), paddedBuffer), isFalse);
    });

    test('Defensive robustness against degenerate or invalid frame parameters', () {
      // 1x1 image with 64-byte stride
      final tinyPadded = Uint8List(64)..[0] = 42;
      final dtoTiny = CameraFrameDto(
        planeBytes: tinyPadded,
        width: 1,
        height: 1,
        bytesPerRow: 64,
        formatGroup: ImageFormatGroup.nv21,
      );
      final contTiny = dtoTiny.extractContiguousBytes();
      expect(contTiny.length, equals(1));
      expect(contTiny[0], equals(42));

      // bytesPerRow <= 0 fallback to width
      final dtoZeroStride = CameraFrameDto(
        planeBytes: Uint8List(100),
        width: 10,
        height: 10,
        bytesPerRow: 0,
        formatGroup: ImageFormatGroup.nv21,
      );
      expect(dtoZeroStride.extractContiguousBytes().length, equals(100));

      // Empty plane bytes
      final dtoEmpty = CameraFrameDto(
        planeBytes: Uint8List(0),
        width: 10,
        height: 10,
        bytesPerRow: 10,
        formatGroup: ImageFormatGroup.nv21,
      );
      expect(dtoEmpty.extractContiguousBytes().length, equals(100));
    });

    test('Throughput stress harness: 60 consecutive 1080p frames with stride 1088', () {
      const width = 1080;
      const height = 1920;
      const bytesPerRow = 1088;
      final paddedBuffer = Uint8List(bytesPerRow * height);

      final dto = CameraFrameDto(
        planeBytes: paddedBuffer,
        width: width,
        height: height,
        bytesPerRow: bytesPerRow,
        formatGroup: ImageFormatGroup.nv21,
      );

      final stopwatch = Stopwatch()..start();
      for (int i = 0; i < 60; i++) {
        final contiguous = dto.extractContiguousBytes();
        expect(contiguous.length, equals(width * height));
      }
      stopwatch.stop();

      final elapsedMs = stopwatch.elapsedMilliseconds;
      // In modern Dart VM, 60 frames of 2MB extraction should comfortably execute within 1500ms (<25ms/frame)
      expect(elapsedMs, lessThan(3000),
          reason: '60-frame stride extraction took ${elapsedMs}ms, exceeding performance threshold');
    });
  });

  // =========================================================================
  // TASK 2: SENSOR ORIENTATION TRANSFORMATIONS AND SCREEN MAPPING
  // =========================================================================
  group('Challenger M4-2 (Task 2): Sensor Orientation & Screen Mapping Empirical Verification', () {
    // Mathematical Oracle for Image Rotation
    Rect rotateRectOracle(Rect rect, Size size, InputImageRotation? rotation) {
      if (size.width <= 0 || size.height <= 0) return rect;

      Offset rotatePoint(Offset p) {
        switch (rotation) {
          case InputImageRotation.rotation90deg:
            return Offset(size.height - p.dy, p.dx);
          case InputImageRotation.rotation180deg:
            return Offset(size.width - p.dx, size.height - p.dy);
          case InputImageRotation.rotation270deg:
            return Offset(p.dy, size.width - p.dx);
          case InputImageRotation.rotation0deg:
          case null:
            return p;
        }
      }

      final p1 = rotatePoint(rect.topLeft);
      final p2 = rotatePoint(rect.topRight);
      final p3 = rotatePoint(rect.bottomRight);
      final p4 = rotatePoint(rect.bottomLeft);

      final xs = [p1.dx, p2.dx, p3.dx, p4.dx];
      final ys = [p1.dy, p2.dy, p3.dy, p4.dy];

      return Rect.fromLTRB(
        xs.reduce(math.min),
        ys.reduce(math.min),
        xs.reduce(math.max),
        ys.reduce(math.max),
      );
    }

    test('Mathematical Oracle Equivalence: rotateImageRect matches corner-point transformation oracle', () {
      final testSizes = [
        const Size(1920, 1080), // Standard landscape sensor
        const Size(1080, 1920), // Upright portrait sensor
        const Size(4032, 3024), // 4:3 12MP sensor
        const Size(640, 480),   // VGA sensor
      ];

      final testRotations = [
        InputImageRotation.rotation0deg,
        InputImageRotation.rotation90deg,
        InputImageRotation.rotation180deg,
        InputImageRotation.rotation270deg,
        null,
      ];

      for (final size in testSizes) {
        final sampleRects = [
          Rect.fromLTWH(size.width * 0.1, size.height * 0.1, size.width * 0.3, size.height * 0.5),
          Rect.fromLTWH(0, 0, size.width * 0.4, size.height * 0.4),
          Rect.fromLTRB(size.width * 0.5, size.height * 0.5, size.width, size.height),
          Rect.fromLTWH(size.width * 0.25, size.height * 0.25, size.width * 0.5, size.height * 0.5),
        ];

        for (final rect in sampleRects) {
          for (final rot in testRotations) {
            final (actualUprightRect, actualUprightSize) = CardPerimeterCalculator.rotateImageRect(
              imageRect: rect,
              imageSize: size,
              rotation: rot,
            );

            final expectedRect = rotateRectOracle(rect, size, rot);
            final expectedSize = (rot == InputImageRotation.rotation90deg ||
                    rot == InputImageRotation.rotation270deg)
                ? Size(size.height, size.width)
                : size;

            expect(actualUprightSize, equals(expectedSize),
                reason: 'Upright size mismatch for $size under ${rot?.name}');
            expect(actualUprightRect.left, closeTo(expectedRect.left, 1e-4));
            expect(actualUprightRect.top, closeTo(expectedRect.top, 1e-4));
            expect(actualUprightRect.right, closeTo(expectedRect.right, 1e-4));
            expect(actualUprightRect.bottom, closeTo(expectedRect.bottom, 1e-4));
          }
        }
      }
    });

    test('4-Rotation Cycloid Invariant: 4x 90deg sequential rotations return to original rect', () {
      const sensorSize = Size(1920, 1080);
      const originalRect = Rect.fromLTWH(200, 150, 400, 600);

      // Step 1: 90 deg
      var (currentRect, currentSize) = CardPerimeterCalculator.rotateImageRect(
        imageRect: originalRect,
        imageSize: sensorSize,
        rotation: InputImageRotation.rotation90deg,
      );
      expect(currentSize, equals(const Size(1080, 1920)));

      // Step 2: 90 deg -> 180 deg
      (currentRect, currentSize) = CardPerimeterCalculator.rotateImageRect(
        imageRect: currentRect,
        imageSize: currentSize,
        rotation: InputImageRotation.rotation90deg,
      );
      expect(currentSize, equals(sensorSize));

      // Step 3: 90 deg -> 270 deg
      (currentRect, currentSize) = CardPerimeterCalculator.rotateImageRect(
        imageRect: currentRect,
        imageSize: currentSize,
        rotation: InputImageRotation.rotation90deg,
      );
      expect(currentSize, equals(const Size(1080, 1920)));

      // Step 4: 90 deg -> 360/0 deg
      (currentRect, currentSize) = CardPerimeterCalculator.rotateImageRect(
        imageRect: currentRect,
        imageSize: currentSize,
        rotation: InputImageRotation.rotation90deg,
      );
      expect(currentSize, equals(sensorSize));

      expect(currentRect.left, closeTo(originalRect.left, 1e-4));
      expect(currentRect.top, closeTo(originalRect.top, 1e-4));
      expect(currentRect.right, closeTo(originalRect.right, 1e-4));
      expect(currentRect.bottom, closeTo(originalRect.bottom, 1e-4));
    });

    test('Lossless Round-Trip Invertibility: unrotateRectToRawSensor restores exact coordinates for all 4 angles', () {
      const sensorSize = Size(1920, 1080);
      const originalRect = Rect.fromLTWH(150.5, 230.75, 520.25, 340.5);

      for (final rot in [
        InputImageRotation.rotation0deg,
        InputImageRotation.rotation90deg,
        InputImageRotation.rotation180deg,
        InputImageRotation.rotation270deg,
      ]) {
        final (uprightRect, _) = CardPerimeterCalculator.rotateImageRect(
          imageRect: originalRect,
          imageSize: sensorSize,
          rotation: rot,
        );

        final restored = CardPerimeterCalculator.unrotateRectToRawSensor(
          uprightRect,
          sensorSize,
          rot,
        );

        expect(restored.left, closeTo(originalRect.left, 1e-4),
            reason: 'Left unrotate mismatch for ${rot.name}');
        expect(restored.top, closeTo(originalRect.top, 1e-4),
            reason: 'Top unrotate mismatch for ${rot.name}');
        expect(restored.right, closeTo(originalRect.right, 1e-4),
            reason: 'Right unrotate mismatch for ${rot.name}');
        expect(restored.bottom, closeTo(originalRect.bottom, 1e-4),
            reason: 'Bottom unrotate mismatch for ${rot.name}');
      }
    });

    test('Screen Mapping: Image Center Maps to Screen Center across all display viewports', () {
      // 1080p upright image: 1080 x 1920
      const uprightSize = Size(1080, 1920);
      final centerPointRect = Rect.fromCenter(
        center: const Offset(540, 960),
        width: 100,
        height: 100,
      );

      final screenViewports = [
        const Size(390, 844),  // iPhone 14/15 (19.5:9)
        const Size(412, 915),  // Pixel 8 (20:9)
        const Size(768, 1024), // iPad (4:3)
        const Size(1000, 1000),// Square / Foldable
        const Size(844, 390),  // Landscape mode
      ];

      for (final screen in screenViewports) {
        final mapped = CardPerimeterCalculator.mapImageRectToScreen(
          imageRect: centerPointRect,
          imageSize: uprightSize,
          screenSize: screen,
          fit: BoxFit.cover,
        );

        final screenCenter = Offset(screen.width / 2.0, screen.height / 2.0);
        expect(mapped.center.dx, closeTo(screenCenter.dx, 1e-4),
            reason: 'Mapped horizontal center mismatch for screen $screen');
        expect(mapped.center.dy, closeTo(screenCenter.dy, 1e-4),
            reason: 'Mapped vertical center mismatch for screen $screen');
      }
    });

    test('Screen Mapping: Aspect Ratio Preservation under uniform scaling', () {
      const uprightSize = Size(1080, 1920);
      const cardRect = Rect.fromLTWH(100, 200, 300, 420); // ratio = 300 / 420 = 0.7142857

      final screenViewports = [
        const Size(390, 844),
        const Size(768, 1024),
        const Size(844, 390),
      ];

      for (final screen in screenViewports) {
        for (final fit in [BoxFit.cover, BoxFit.contain, BoxFit.fitWidth, BoxFit.fitHeight]) {
          final mapped = CardPerimeterCalculator.mapImageRectToScreen(
            imageRect: cardRect,
            imageSize: uprightSize,
            screenSize: screen,
            fit: fit,
          );

          final originalRatio = cardRect.width / cardRect.height;
          final mappedRatio = mapped.width / mapped.height;

          expect(mappedRatio, closeTo(originalRatio, 1e-4),
              reason: 'Aspect ratio distortion under fit $fit on screen $screen');
        }
      }
    });

    test('Screen Mapping: Clamping strictly confines off-screen boundaries', () {
      const uprightSize = Size(1000, 1000);
      const screen = Size(400, 800);
      const overflowingRect = Rect.fromLTRB(-200, -100, 1200, 1500);

      final clamped = CardPerimeterCalculator.mapImageRectToScreen(
        imageRect: overflowingRect,
        imageSize: uprightSize,
        screenSize: screen,
        fit: BoxFit.cover,
        clampToScreen: true,
      );

      expect(clamped.left, greaterThanOrEqualTo(0.0));
      expect(clamped.top, greaterThanOrEqualTo(0.0));
      expect(clamped.right, lessThanOrEqualTo(screen.width));
      expect(clamped.bottom, lessThanOrEqualTo(screen.height));
    });
  });

  // =========================================================================
  // TASK 3: MANABOX RETICLE VISUAL PROPERTIES UNDER RAPID CONTAINER RESIZING AND NULL TRANSITIONS
  // =========================================================================
  group('Challenger M4-2 (Task 3): ManaBox Reticle Rapid Resizing & Null Transitions Empirical Verification', () {
    testWidgets('Full Null -> NonNull -> Null -> NonNull lifecycle with 150ms entrance / 700ms decay', (tester) async {
      final boundsNotifier = ValueNotifier<Rect?>(null);
      addTearDown(boundsNotifier.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<Rect?>(
              valueListenable: boundsNotifier,
              builder: (context, bounds, _) => DynamicScannerOverlay(
                cardBounds: bounds,
                isGreenFlash: false,
                isPaused: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Initial Null state: renders empty shrink widget
      expect(find.byKey(const Key('dynamic_scanner_overlay_empty')), findsOneWidget);
      expect(find.byKey(const Key('dynamic_scanner_overlay')), findsNothing);

      // 2. Card enters: NonNull
      boundsNotifier.value = const Rect.fromLTWH(80, 120, 240, 340);
      await tester.pump(); // Start entrance

      expect(find.byKey(const Key('dynamic_scanner_overlay')), findsOneWidget);
      var opacityWidget = tester.widget<AnimatedOpacity>(
        find.byKey(const Key('dynamic_scanner_overlay')),
      );
      expect(opacityWidget.duration, equals(const Duration(milliseconds: 150)));
      expect(opacityWidget.opacity, equals(1.0));

      // Settle entrance
      await tester.pumpAndSettle();
      var tl = tester.getTopLeft(find.byKey(const Key('corner_bracket_tl')));
      expect(tl.dx, closeTo(80.0, 1.0));
      expect(tl.dy, closeTo(120.0, 1.0));

      // 3. Card lost: transition to Null
      boundsNotifier.value = null;
      await tester.pump(); // Trigger decay

      // Opacity duration switches to 700ms decay
      opacityWidget = tester.widget<AnimatedOpacity>(
        find.byKey(const Key('dynamic_scanner_overlay')),
      );
      expect(opacityWidget.duration, equals(const Duration(milliseconds: 700)));
      expect(opacityWidget.opacity, equals(0.0));

      // 250ms into decay: bracket is STILL rendered at last known bounds!
      await tester.pump(const Duration(milliseconds: 250));
      tl = tester.getTopLeft(find.byKey(const Key('corner_bracket_tl')));
      expect(tl.dx, closeTo(80.0, 1.0));
      expect(tl.dy, closeTo(120.0, 1.0));

      // 4. Card reappears mid-decay at new bounds
      boundsNotifier.value = const Rect.fromLTWH(140, 180, 260, 360);
      await tester.pump();

      opacityWidget = tester.widget<AnimatedOpacity>(
        find.byKey(const Key('dynamic_scanner_overlay')),
      );
      // Immediately switches back to 150ms entrance
      expect(opacityWidget.duration, equals(const Duration(milliseconds: 150)));
      expect(opacityWidget.opacity, equals(1.0));

      // Let TweenAnimationBuilder morph smoothly
      await tester.pumpAndSettle();
      tl = tester.getTopLeft(find.byKey(const Key('corner_bracket_tl')));
      expect(tl.dx, closeTo(140.0, 1.0));
      expect(tl.dy, closeTo(180.0, 1.0));

      // 5. Final decay after card leaves permanently
      boundsNotifier.value = null;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));
      // Opacity finishes decay cleanly
      expect(tester.takeException(), isNull);
    });

    testWidgets('Rapid null flickering stress test: 50 frame alternations between null and valid rect', (tester) async {
      final boundsNotifier = ValueNotifier<Rect?>(null);
      addTearDown(boundsNotifier.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<Rect?>(
              valueListenable: boundsNotifier,
              builder: (context, bounds, _) => DynamicScannerOverlay(
                cardBounds: bounds,
                isGreenFlash: false,
                isPaused: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      for (int i = 0; i < 50; i++) {
        boundsNotifier.value = (i % 2 == 0)
            ? Rect.fromLTWH(50.0 + i, 80.0 + i, 200, 300)
            : null;
        await tester.pump(const Duration(milliseconds: 16)); // 60 FPS frame step
      }

      expect(tester.takeException(), isNull,
          reason: 'Rapid null flickering caused an exception');
    });

    testWidgets('Rapid container resizing across extreme phone, tablet, and foldable viewports', (tester) async {
      final containerSizeNotifier = ValueNotifier<Size>(const Size(390, 844));
      addTearDown(containerSizeNotifier.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<Size>(
              valueListenable: containerSizeNotifier,
              builder: (context, size, _) => SizedBox(
                width: size.width,
                height: size.height,
                child: const DynamicScannerOverlay(
                  cardBounds: Rect.fromLTWH(40, 80, 200, 300),
                  isGreenFlash: false,
                  isPaused: false,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final sizes = [
        const Size(844, 390),  // Landscape phone
        const Size(768, 1024), // iPad / Tablet
        const Size(1812, 2176),// Unfolded large foldable
        const Size(100, 100),  // Mini thumbnail container
        const Size(360, 800),  // Standard Android
      ];

      for (final sz in sizes) {
        containerSizeNotifier.value = sz;
        await tester.pump(const Duration(milliseconds: 50));
        expect(tester.takeException(), isNull,
            reason: 'Container resize to $sz threw an unhandled exception');
        expect(find.byKey(const Key('dynamic_scanner_bounding_container')), findsOneWidget);
      }
    });

    testWidgets('Degenerate rect handling: zero width, negative width, or empty bounds', (tester) async {
      final degenerateBounds = [
        const Rect.fromLTWH(100, 100, 0, 200),   // Zero width
        const Rect.fromLTWH(100, 100, 200, 0),   // Zero height
        const Rect.fromLTWH(100, 100, -50, 100), // Negative width
        const Rect.fromLTWH(100, 100, 100, -50), // Negative height
        Rect.zero,
      ];

      for (final badRect in degenerateBounds) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DynamicScannerOverlay(
                cardBounds: badRect,
                isGreenFlash: false,
                isPaused: false,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Must not throw or crash Canvas
        expect(tester.takeException(), isNull,
            reason: 'Degenerate rect $badRect caused an exception');
      }
    });

    testWidgets('Extreme card size handling: bounds larger than screen clamp corner length to 28dp', (tester) async {
      const giantBounds = Rect.fromLTWH(0, 0, 5000, 8000);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DynamicScannerOverlay(
              cardBounds: giantBounds,
              isGreenFlash: false,
              isPaused: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tlFinder = find.byKey(const Key('corner_bracket_tl'));
      expect(tlFinder, findsOneWidget);

      final size = tester.getSize(tlFinder);
      // cornerLength = min(28.0, min(w, h) * 0.25) -> strictly 28.0
      expect(size.width, equals(28.0));
      expect(size.height, equals(28.0));
    });

    testWidgets('Bounded laser scan line resilience when card width < 8dp', (tester) async {
      final controller = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(seconds: 1),
      )..value = 0.5;
      addTearDown(controller.dispose);

      // Card narrower than 8dp (e.g. 5dp)
      const tinyWidthBounds = Rect.fromLTWH(50, 100, 5, 200);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DynamicScannerOverlay(
              cardBounds: tinyWidthBounds,
              isGreenFlash: false,
              isPaused: false,
              scanLineAnimation: controller,
            ),
          ),
        ),
      );
      await tester.pump();

      final laserFinder = find.byKey(const Key('bounded_laser_scan_line'));
      expect(laserFinder, findsOneWidget);
      final laserRect = tester.getRect(laserFinder);
      // laserWidth = max(0.0, currentRect.width - 8.0) -> clamped to 0.0 without error
      expect(laserRect.width, equals(0.0));
    });

    testWidgets('Full State Matrix Verification: (Normal, Paused, Match Flash, Paused Match Flash)', (tester) async {
      final stateNotifier = ValueNotifier<(bool, bool)>((false, false)); // (isGreenFlash, isPaused)
      addTearDown(stateNotifier.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<(bool, bool)>(
              valueListenable: stateNotifier,
              builder: (context, state, _) => DynamicScannerOverlay(
                cardBounds: const Rect.fromLTWH(60, 100, 240, 340),
                isGreenFlash: state.$1,
                isPaused: state.$2,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // State 1: Normal Active Tracking
      var container = tester.widget<AnimatedContainer>(
        find.byKey(const Key('dynamic_scanner_bounding_container')),
      );
      var border = (container.decoration as BoxDecoration).border as Border;
      expect(border.top.color.r, closeTo(AppColors.accentCyan.r, 0.05));
      expect(border.top.width, equals(1.6));

      // State 2: Confirmed Match Flash
      stateNotifier.value = (true, false);
      await tester.pumpAndSettle();
      container = tester.widget<AnimatedContainer>(
        find.byKey(const Key('dynamic_scanner_bounding_container')),
      );
      border = (container.decoration as BoxDecoration).border as Border;
      expect(border.top.color.r, closeTo(AppColors.accentEmerald.r, 0.05));
      expect(border.top.width, equals(2.8));

      // State 3: Battery-Saver Paused
      stateNotifier.value = (false, true);
      await tester.pumpAndSettle();
      container = tester.widget<AnimatedContainer>(
        find.byKey(const Key('dynamic_scanner_bounding_container')),
      );
      border = (container.decoration as BoxDecoration).border as Border;
      expect(border.top.color.r, closeTo(AppColors.accentAmber.r, 0.05));

      // State 4: Paused during flash (battery saver priority)
      stateNotifier.value = (true, true);
      await tester.pumpAndSettle();
      container = tester.widget<AnimatedContainer>(
        find.byKey(const Key('dynamic_scanner_bounding_container')),
      );
      border = (container.decoration as BoxDecoration).border as Border;
      // Paused state takes precedence for power conservation
      expect(border.top.color.r, closeTo(AppColors.accentAmber.r, 0.05));
    });
  });
}
