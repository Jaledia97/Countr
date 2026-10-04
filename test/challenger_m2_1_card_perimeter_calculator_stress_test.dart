import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:countr/features/scanner/domain/card_perimeter_calculator.dart';

void main() {
  group('Empirical Challenger M2-1: smoothRect Invariant & Stress Tests', () {
    test('smoothRect with previous == null returns current unconditionally', () {
      const rect = Rect.fromLTRB(10.5, 20.25, 110.75, 220.5);
      final result = CardPerimeterCalculator.smoothRect(null, rect);
      expect(result, equals(rect));
    });

    test('smoothRect zero displacement produces exact identity without drift', () {
      const rect = Rect.fromLTWH(100.0, 150.0, 200.0, 300.0);
      final result = CardPerimeterCalculator.smoothRect(rect, rect);
      expect(result.left, equals(rect.left));
      expect(result.top, equals(rect.top));
      expect(result.right, equals(rect.right));
      expect(result.bottom, equals(rect.bottom));
      expect(result.width, equals(rect.width));
      expect(result.height, equals(rect.height));
    });

    test('smoothRect damping under small displacement: strictly applies alpha = 0.40', () {
      // Displacements from 1px to 60px in multiple directions
      final testDeltas = [
        const Offset(1.0, 0.0), // 1px horizontal
        const Offset(0.0, 5.0), // 5px vertical
        const Offset(10.0, 10.0), // ~14.14px diagonal
        const Offset(-20.0, 15.0), // 25px negative diagonal
        const Offset(36.0, 48.0), // exactly 60.0px (3-4-5 triangle: sqrt(36^2 + 48^2) = 60.0)
        const Offset(0.0, 59.99), // 59.99px vertical
      ];

      const prev = Rect.fromLTWH(200.0, 200.0, 150.0, 250.0);

      for (final delta in testDeltas) {
        final current = Rect.fromLTWH(
          prev.left + delta.dx,
          prev.top + delta.dy,
          prev.width,
          prev.height,
        );

        final distance = delta.distance;
        expect(distance, lessThanOrEqualTo(60.0));

        final smoothed = CardPerimeterCalculator.smoothRect(prev, current);

        final expectedLeft = prev.left + delta.dx * 0.40;
        final expectedTop = prev.top + delta.dy * 0.40;

        expect(
          smoothed.left,
          closeTo(expectedLeft, 1e-6),
          reason: 'Expected 0.40 damping at distance $distance for dx=${delta.dx}',
        );
        expect(
          smoothed.top,
          closeTo(expectedTop, 1e-6),
          reason: 'Expected 0.40 damping at distance $distance for dy=${delta.dy}',
        );
        expect(smoothed.width, closeTo(prev.width, 1e-6));
        expect(smoothed.height, closeTo(prev.height, 1e-6));
      }
    });

    test('smoothRect snapping under large displacement: strictly applies effectiveAlpha = 0.85', () {
      // Displacements > 60px
      final testDeltas = [
        const Offset(36.01, 48.01), // > 60.0px (~60.017px)
        const Offset(60.1, 0.0), // 60.1px
        const Offset(100.0, 0.0), // 100px
        const Offset(-80.0, -90.0), // ~120.4px
        const Offset(400.0, 300.0), // 500px large jump
      ];

      const prev = Rect.fromLTWH(100.0, 100.0, 180.0, 260.0);

      for (final delta in testDeltas) {
        final current = Rect.fromLTWH(
          prev.left + delta.dx,
          prev.top + delta.dy,
          prev.width,
          prev.height,
        );

        final distance = delta.distance;
        expect(distance, greaterThan(60.0));

        final smoothed = CardPerimeterCalculator.smoothRect(prev, current);

        final expectedLeft = prev.left + delta.dx * 0.85;
        final expectedTop = prev.top + delta.dy * 0.85;

        expect(
          smoothed.left,
          closeTo(expectedLeft, 1e-6),
          reason: 'Expected 0.85 fast snap at distance $distance for dx=${delta.dx}',
        );
        expect(
          smoothed.top,
          closeTo(expectedTop, 1e-6),
          reason: 'Expected 0.85 fast snap at distance $distance for dy=${delta.dy}',
        );
      }
    });

    test('smoothRect threshold transition discontinuity exactly at 60.0px', () {
      const prev = Rect.fromLTWH(100.0, 100.0, 200.0, 300.0);

      // 60.000000000 -> distance is <= 60.0 -> uses alpha = 0.40
      final atBoundary = Rect.fromLTWH(160.0, 100.0, 200.0, 300.0);
      final smoothedAt = CardPerimeterCalculator.smoothRect(prev, atBoundary);
      expect(smoothedAt.left, closeTo(100.0 + 60.0 * 0.40, 1e-6)); // 124.0

      // 60.001 -> distance > 60.0 -> uses effectiveAlpha = 0.85
      final pastBoundary = Rect.fromLTWH(160.001, 100.0, 200.0, 300.0);
      final smoothedPast = CardPerimeterCalculator.smoothRect(prev, pastBoundary);
      expect(smoothedPast.left, closeTo(100.0 + 60.001 * 0.85, 1e-4)); // ~151.00085
    });

    test('smoothRect multi-frame simulation: noise damping vs step response convergence', () {
      // 1. Noise simulation: stationary card at (100, 100) with ±5px jitter across 30 frames
      const truePosition = Rect.fromLTWH(100.0, 100.0, 200.0, 300.0);
      final rng = math.Random(42);
      Rect state = truePosition;

      double rawTotalDeviation = 0.0;
      double smoothedTotalDeviation = 0.0;

      for (int i = 0; i < 50; i++) {
        final jitterX = (rng.nextDouble() - 0.5) * 10.0; // [-5.0, 5.0]
        final jitterY = (rng.nextDouble() - 0.5) * 10.0; // [-5.0, 5.0]
        final noisyCurrent = Rect.fromLTWH(
          truePosition.left + jitterX,
          truePosition.top + jitterY,
          truePosition.width,
          truePosition.height,
        );

        state = CardPerimeterCalculator.smoothRect(state, noisyCurrent);

        rawTotalDeviation += math.sqrt(jitterX * jitterX + jitterY * jitterY);
        smoothedTotalDeviation += (state.topLeft - truePosition.topLeft).distance;
      }

      // Smoothed deviation must be significantly lower than raw noise
      expect(
        smoothedTotalDeviation / 50,
        lessThan(rawTotalDeviation / 50 * 0.65),
        reason: 'Smoothing must suppress high-frequency jitter variance',
      );

      // 2. Step response: sudden move by 200px (displacement > 60px)
      const targetPos = Rect.fromLTWH(300.0, 300.0, 200.0, 300.0);
      final preStepDistance = (state.topLeft - targetPos.topLeft).distance;
      expect(preStepDistance, greaterThan(60.0));

      // Frame 1: fast snap covers 85%, leaving exactly (1 - 0.85) = 15% distance
      state = CardPerimeterCalculator.smoothRect(state, targetPos);
      final remainingDist1 = (state.topLeft - targetPos.topLeft).distance;
      expect(remainingDist1, closeTo(preStepDistance * 0.15, 1e-4));
      expect(remainingDist1, lessThan(45.0));

      // Frame 2: remaining distance is ~42px (which is <= 60px), so it applies alpha = 0.40 damping
      state = CardPerimeterCalculator.smoothRect(state, targetPos);
      final remainingDist2 = (state.topLeft - targetPos.topLeft).distance;
      expect(remainingDist2, closeTo(remainingDist1 * 0.60, 1e-4));
      expect(remainingDist2, lessThan(26.0));
    });

    test('smoothRect behavior when card scales with fixed topLeft (stress angle)', () {
      // If topLeft stays at (100, 100) while size expands from 50x50 to 300x450
      const prev = Rect.fromLTWH(100.0, 100.0, 50.0, 50.0);
      const current = Rect.fromLTWH(100.0, 100.0, 300.0, 450.0);

      final smoothed = CardPerimeterCalculator.smoothRect(prev, current);
      // Because distance is based on topLeft, distance = 0 <= 60 -> effectiveAlpha is 0.40
      expect(smoothed.topLeft, equals(const Offset(100.0, 100.0)));
      expect(smoothed.width, closeTo(50.0 + (300.0 - 50.0) * 0.40, 1e-6)); // 150.0
      expect(smoothed.height, closeTo(50.0 + (450.0 - 50.0) * 0.40, 1e-6)); // 210.0
    });
  });

  group('Empirical Challenger M2-1: rotateImageRect & unrotateRectToRawSensor Lossless Identity', () {
    final rotations = [
      InputImageRotation.rotation0deg,
      InputImageRotation.rotation90deg,
      InputImageRotation.rotation180deg,
      InputImageRotation.rotation270deg,
      null,
    ];

    final aspectRatios = <String, Size>{
      'Landscape 16:9 HD': const Size(1920, 1080),
      'Landscape 4:3 SD': const Size(640, 480),
      'Landscape 4:3 HiRes': const Size(4032, 3024),
      'Portrait 9:16 Mobile': const Size(1080, 1920),
      'Portrait 20:9 Tall': const Size(1080, 2400),
      'Portrait 4:3': const Size(768, 1024),
      'Square 1:1': const Size(1000, 1000),
      'Ultrawide 21:9': const Size(2560, 1080),
      'Extreme Ribbon Tall': const Size(200, 3800),
      'Extreme Ribbon Wide': const Size(3800, 200),
      'Subpixel Float Sensor': const Size(1080.5, 1920.75),
    };

    for (final rot in rotations) {
      final rotName = rot?.name ?? 'null (0deg implicit)';

      test('Round-trip identity: raw -> rotate -> unrotate under $rotName across all aspect ratios', () {
        for (final entry in aspectRatios.entries) {
          final sizeName = entry.key;
          final rawSize = entry.value;

          // Test diverse rect topologies:
          final testRects = [
            // Center typical card rect
            Rect.fromLTWH(
              rawSize.width * 0.25,
              rawSize.height * 0.25,
              rawSize.width * 0.4,
              rawSize.height * 0.5,
            ),
            // Origin corner (0,0)
            Rect.fromLTWH(0.0, 0.0, rawSize.width * 0.3, rawSize.height * 0.3),
            // Bottom-right corner touching boundary
            Rect.fromLTRB(
              rawSize.width * 0.6,
              rawSize.height * 0.6,
              rawSize.width,
              rawSize.height,
            ),
            // Full frame
            Rect.fromLTWH(0.0, 0.0, rawSize.width, rawSize.height),
            // Thin sliver (1px)
            Rect.fromLTWH(rawSize.width * 0.5, rawSize.height * 0.5, 1.0, 1.0),
            // Arbitrary sub-pixel floating coordinates
            Rect.fromLTRB(17.345, 23.891, rawSize.width - 15.67, rawSize.height - 11.23),
          ];

          for (final rawRect in testRects) {
            final (uprightRect, uprightSize) = CardPerimeterCalculator.rotateImageRect(
              imageRect: rawRect,
              imageSize: rawSize,
              rotation: rot,
            );

            // Upright rect dimensions check
            if (rot == InputImageRotation.rotation90deg ||
                rot == InputImageRotation.rotation270deg) {
              expect(
                uprightSize,
                Size(rawSize.height, rawSize.width),
                reason: '$rotName must swap dimensions for $sizeName',
              );
              expect(
                uprightRect.width,
                closeTo(rawRect.height, 1e-5),
                reason: 'Rotated width must match raw height for $sizeName',
              );
              expect(
                uprightRect.height,
                closeTo(rawRect.width, 1e-5),
                reason: 'Rotated height must match raw width for $sizeName',
              );
            } else {
              expect(
                uprightSize,
                rawSize,
                reason: '$rotName must maintain dimensions for $sizeName',
              );
              expect(
                uprightRect.width,
                closeTo(rawRect.width, 1e-5),
                reason: 'Rotated width must match raw width for $sizeName',
              );
              expect(
                uprightRect.height,
                closeTo(rawRect.height, 1e-5),
                reason: 'Rotated height must match raw height for $sizeName',
              );
            }

            // Unrotate back to raw
            final restored = CardPerimeterCalculator.unrotateRectToRawSensor(
              uprightRect,
              rawSize,
              rot,
            );

            expect(
              restored.left,
              closeTo(rawRect.left, 1e-6),
              reason: 'Round-trip left mismatch for $sizeName under $rotName',
            );
            expect(
              restored.top,
              closeTo(rawRect.top, 1e-6),
              reason: 'Round-trip top mismatch for $sizeName under $rotName',
            );
            expect(
              restored.right,
              closeTo(rawRect.right, 1e-6),
              reason: 'Round-trip right mismatch for $sizeName under $rotName',
            );
            expect(
              restored.bottom,
              closeTo(rawRect.bottom, 1e-6),
              reason: 'Round-trip bottom mismatch for $sizeName under $rotName',
            );
          }
        }
      });

      test('Reverse round-trip identity: upright -> unrotate -> rotate under $rotName', () {
        for (final entry in aspectRatios.entries) {
          final sizeName = entry.key;
          final rawSize = entry.value;

          final uprightSize = CardPerimeterCalculator.getUprightImageSize(
            rawSize: rawSize,
            rotation: rot,
          );

          final testUprightRects = [
            Rect.fromLTWH(
              uprightSize.width * 0.2,
              uprightSize.height * 0.2,
              uprightSize.width * 0.5,
              uprightSize.height * 0.6,
            ),
            Rect.fromLTWH(0.0, 0.0, uprightSize.width, uprightSize.height),
            Rect.fromLTRB(10.123, 20.456, uprightSize.width - 5.0, uprightSize.height - 12.0),
          ];

          for (final uprightRect in testUprightRects) {
            // Unrotate to raw
            final rawRestored = CardPerimeterCalculator.unrotateRectToRawSensor(
              uprightRect,
              rawSize,
              rot,
            );

            // Rotate back to upright
            final (rotUpright, rotSize) = CardPerimeterCalculator.rotateImageRect(
              imageRect: rawRestored,
              imageSize: rawSize,
              rotation: rot,
            );

            expect(rotSize, uprightSize);
            expect(
              rotUpright.left,
              closeTo(uprightRect.left, 1e-6),
              reason: 'Reverse round-trip left mismatch for $sizeName under $rotName',
            );
            expect(
              rotUpright.top,
              closeTo(uprightRect.top, 1e-6),
              reason: 'Reverse round-trip top mismatch for $sizeName under $rotName',
            );
            expect(
              rotUpright.right,
              closeTo(uprightRect.right, 1e-6),
              reason: 'Reverse round-trip right mismatch for $sizeName under $rotName',
            );
            expect(
              rotUpright.bottom,
              closeTo(uprightRect.bottom, 1e-6),
              reason: 'Reverse round-trip bottom mismatch for $sizeName under $rotName',
            );
          }
        }
      });
    }

    test('Randomized Fuzz Testing: 1,000 arbitrary rectangles round-trip losslessly', () {
      final rng = math.Random(1337);

      for (int i = 0; i < 1000; i++) {
        final rawW = 100.0 + rng.nextDouble() * 3900.0;
        final rawH = 100.0 + rng.nextDouble() * 3900.0;
        final rawSize = Size(rawW, rawH);

        final x1 = rng.nextDouble() * rawW;
        final x2 = rng.nextDouble() * rawW;
        final y1 = rng.nextDouble() * rawH;
        final y2 = rng.nextDouble() * rawH;

        final rawRect = Rect.fromLTRB(
          math.min(x1, x2),
          math.min(y1, y2),
          math.max(x1, x2) + 0.1, // Ensure non-zero width
          math.max(y1, y2) + 0.1, // Ensure non-zero height
        );

        final rotIdx = rng.nextInt(5);
        final rot = rotIdx == 4 ? null : rotations[rotIdx];

        final (upright, _) = CardPerimeterCalculator.rotateImageRect(
          imageRect: rawRect,
          imageSize: rawSize,
          rotation: rot,
        );

        final restored = CardPerimeterCalculator.unrotateRectToRawSensor(
          upright,
          rawSize,
          rot,
        );

        expect(restored.left, closeTo(rawRect.left, 1e-6));
        expect(restored.top, closeTo(rawRect.top, 1e-6));
        expect(restored.right, closeTo(rawRect.right, 1e-6));
        expect(restored.bottom, closeTo(rawRect.bottom, 1e-6));
      }
    });

    test('Defensive robustness against empty or invalid dimensions', () {
      const sampleRect = Rect.fromLTWH(10, 20, 30, 40);

      // Zero and negative sizes
      for (final badSize in [
        Size.zero,
        const Size(-100, 200),
        const Size(200, -100),
        const Size(-50, -50),
      ]) {
        for (final rot in rotations) {
          final (rotRect, rotSize) = CardPerimeterCalculator.rotateImageRect(
            imageRect: sampleRect,
            imageSize: badSize,
            rotation: rot,
          );
          expect(rotRect, sampleRect);
          expect(rotSize, badSize);

          final unrotRect = CardPerimeterCalculator.unrotateRectToRawSensor(
            sampleRect,
            badSize,
            rot,
          );
          expect(unrotRect, sampleRect);
        }
      }
    });
  });

  group('Empirical Challenger M2-1: mapImageRectToScreen Stress & Boundaries', () {
    test('all BoxFit modes behave deterministically with extreme aspect differences', () {
      // Very wide camera image (1920 x 800) displayed on very tall phone screen (400 x 900)
      const imageSize = Size(1920, 800);
      const screenSize = Size(400, 900);
      const cardRect = Rect.fromLTWH(400, 200, 600, 400);

      // BoxFit.cover: scale = max(400/1920, 900/800) = max(0.20833, 1.125) = 1.125
      final cover = CardPerimeterCalculator.mapImageRectToScreen(
        imageRect: cardRect,
        imageSize: imageSize,
        screenSize: screenSize,
        fit: BoxFit.cover,
      );
      expect(cover.width, closeTo(600 * 1.125, 1e-4));
      expect(cover.height, closeTo(400 * 1.125, 1e-4));

      // BoxFit.contain: scale = min(400/1920, 900/800) = 400/1920 = 0.208333
      final contain = CardPerimeterCalculator.mapImageRectToScreen(
        imageRect: cardRect,
        imageSize: imageSize,
        screenSize: screenSize,
        fit: BoxFit.contain,
      );
      expect(contain.width, closeTo(600 * (400 / 1920), 1e-4));
      expect(contain.height, closeTo(400 * (400 / 1920), 1e-4));

      // BoxFit.fitWidth: scale = 400 / 1920
      final fitWidth = CardPerimeterCalculator.mapImageRectToScreen(
        imageRect: cardRect,
        imageSize: imageSize,
        screenSize: screenSize,
        fit: BoxFit.fitWidth,
      );
      expect(fitWidth.width, closeTo(600 * (400 / 1920), 1e-4));

      // BoxFit.fitHeight: scale = 900 / 800 = 1.125
      final fitHeight = CardPerimeterCalculator.mapImageRectToScreen(
        imageRect: cardRect,
        imageSize: imageSize,
        screenSize: screenSize,
        fit: BoxFit.fitHeight,
      );
      expect(fitHeight.width, closeTo(600 * 1.125, 1e-4));
    });

    test('clampToScreen strictly binds coordinates to visible screen viewport', () {
      const imageSize = Size(1000, 1000);
      const screenSize = Size(400, 800);
      // Rect extending outside image bounds
      const overflowingRect = Rect.fromLTRB(-500, -200, 2000, 3000);

      final clamped = CardPerimeterCalculator.mapImageRectToScreen(
        imageRect: overflowingRect,
        imageSize: imageSize,
        screenSize: screenSize,
        fit: BoxFit.cover,
        clampToScreen: true,
      );

      expect(clamped.left, greaterThanOrEqualTo(0.0));
      expect(clamped.top, greaterThanOrEqualTo(0.0));
      expect(clamped.right, lessThanOrEqualTo(screenSize.width));
      expect(clamped.bottom, lessThanOrEqualTo(screenSize.height));
    });
  });

  group('Empirical Challenger M2-1: calculatePerimeter Stress & Oracles', () {
    TextBlock makeBlock(Rect box) {
      return TextBlock(
        text: 'OCR Block',
        lines: const [],
        boundingBox: box,
        recognizedLanguages: const [],
        cornerPoints: const [],
      );
    }

    test('exact enclosing bounding box and mathematical padding verification', () {
      final blocks = [
        makeBlock(const Rect.fromLTWH(100, 200, 50, 40)), // right=150, bottom=240
        makeBlock(const Rect.fromLTWH(300, 150, 100, 20)), // right=400, bottom=170
        makeBlock(const Rect.fromLTWH(80, 500, 40, 100)), // right=120, bottom=600
      ];

      // minLeft = 80, minTop = 150, maxRight = 400, maxBottom = 600
      // rawWidth = 320, rawHeight = 450
      // padXPercent = 0.05, padYPercent = 0.10
      // padX = 320 * 0.05 = 16, padY = 450 * 0.10 = 45
      // expected: left = 80 - 16 = 64, top = 150 - 45 = 105, right = 400 + 16 = 416, bottom = 600 + 45 = 645
      final perimeter = CardPerimeterCalculator.calculatePerimeter(
        blocks,
        padXPercent: 0.05,
        padYPercent: 0.10,
        imageSize: const Size(1000, 1000),
      );

      expect(perimeter, isNotNull);
      expect(perimeter!.left, equals(64.0));
      expect(perimeter.top, equals(105.0));
      expect(perimeter.right, equals(416.0));
      expect(perimeter.bottom, equals(645.0));
    });

    test('blocks completely out of imageSize bounds return null safely', () {
      final outBlocks = [
        makeBlock(const Rect.fromLTWH(1200, 1500, 200, 200)),
      ];
      final res = CardPerimeterCalculator.calculatePerimeter(
        outBlocks,
        imageSize: const Size(1000, 1000),
      );
      expect(res, isNull);
    });

    test('all invalid or degenerate blocks return null', () {
      final badBlocks = [
        makeBlock(const Rect.fromLTWH(10, 10, -5, 20)),
        makeBlock(const Rect.fromLTWH(10, 10, 20, 0)),
        makeBlock(const Rect.fromLTWH(10, 10, 0, 0)),
      ];
      expect(CardPerimeterCalculator.calculatePerimeter(badBlocks), isNull);
    });
  });

  group('Empirical Challenger M2-1: Area Conservation & Geometric Invariants', () {
    test('rotateImageRect preserves exact area across all rotations', () {
      const rawSize = Size(1920, 1080);
      const rawRect = Rect.fromLTWH(123.4, 567.8, 345.6, 234.5);
      final rawArea = rawRect.width * rawRect.height;

      for (final rot in [
        InputImageRotation.rotation0deg,
        InputImageRotation.rotation90deg,
        InputImageRotation.rotation180deg,
        InputImageRotation.rotation270deg,
        null,
      ]) {
        final (upright, _) = CardPerimeterCalculator.rotateImageRect(
          imageRect: rawRect,
          imageSize: rawSize,
          rotation: rot,
        );
        final rotArea = upright.width * upright.height;
        expect(
          rotArea,
          closeTo(rawArea, 1e-6),
          reason: 'Area must be strictly conserved under ${rot?.name}',
        );
      }
    });

    test('smoothRect parameter extremes: alpha 0.0 frozen, alpha 1.0 immediate', () {
      const prev = Rect.fromLTWH(100, 100, 200, 200);
      const current = Rect.fromLTWH(130, 130, 200, 200); // 42.4px displacement <= 60px

      final frozen = CardPerimeterCalculator.smoothRect(prev, current, alpha: 0.0);
      expect(frozen, equals(prev));

      final instant = CardPerimeterCalculator.smoothRect(prev, current, alpha: 1.0);
      expect(instant, equals(current));
    });

    test('smoothRect harmonic oscillation suppression', () {
      // Alternating ±10px jitter around (100, 100)
      const center = Rect.fromLTWH(100, 100, 200, 300);
      Rect state = center;

      for (int i = 0; i < 20; i++) {
        final offset = (i % 2 == 0) ? 10.0 : -10.0;
        final current = Rect.fromLTWH(100 + offset, 100, 200, 300);
        state = CardPerimeterCalculator.smoothRect(state, current);
      }

      // After alternating, the smoothed state must be tightly bound near center (deviation < 4px)
      expect((state.topLeft - center.topLeft).distance, lessThan(4.0));
    });
  });
}

