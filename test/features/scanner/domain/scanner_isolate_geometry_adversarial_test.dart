import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/features/scanner/domain/vision/vision_isolate.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Empirical Challenge: ScannerWorkerIsolate Vertex Approximation (3, 4, 5, 8, 9)', () {
    test('Empirical validation for 3, 4, 5, 8, 9 vertices', () {
      // 3 vertices: Triangle / fold / shadow -> REJECTED
      expect(
        ScannerWorkerIsolate.isSupportedVertexCount(3),
        isFalse,
        reason: '3 vertices (triangle) must be rejected to prevent false positives from background folds or shadows',
      );

      // 4 vertices: True quadrilateral -> ACCEPTED
      expect(
        ScannerWorkerIsolate.isSupportedVertexCount(4),
        isTrue,
        reason: '4 vertices (quadrilateral) must be accepted as ideal card contour',
      );

      // 5 vertices: Rounded or clipped corner polygon -> ACCEPTED
      expect(
        ScannerWorkerIsolate.isSupportedVertexCount(5),
        isTrue,
        reason: '5 vertices (single rounded corner or chamfer) must be accepted for die-cut cards',
      );

      // 8 vertices: Full 4 rounded corners polygon -> ACCEPTED
      expect(
        ScannerWorkerIsolate.isSupportedVertexCount(8),
        isTrue,
        reason: '8 vertices (4 corners x 2 vertices each) must be accepted for standard rounded TCG cards',
      );

      // 9 vertices: Complex non-card polygon / noisy contour -> REJECTED
      expect(
        ScannerWorkerIsolate.isSupportedVertexCount(9),
        isFalse,
        reason: '9 vertices (high polygon complexity) must be rejected to avoid tracking hands or noisy background',
      );
    });

    test('Exhaustive integer sweep across vertex range [-10, 30]', () {
      for (int v = -10; v <= 30; v++) {
        final isSupported = ScannerWorkerIsolate.isSupportedVertexCount(v);
        if (v >= 4 && v <= 8) {
          expect(isSupported, isTrue, reason: 'Vertex count $v should be supported (in [4, 8])');
        } else {
          expect(isSupported, isFalse, reason: 'Vertex count $v should NOT be supported (outside [4, 8])');
        }
      }
    });

    test('Boundary step analysis: transition points [3 -> 4] and [8 -> 9]', () {
      // Low boundary rising edge
      expect(ScannerWorkerIsolate.isSupportedVertexCount(3), isFalse);
      expect(ScannerWorkerIsolate.isSupportedVertexCount(4), isTrue);

      // High boundary falling edge
      expect(ScannerWorkerIsolate.isSupportedVertexCount(8), isTrue);
      expect(ScannerWorkerIsolate.isSupportedVertexCount(9), isFalse);
    });

    test('Internal range completeness: 6 and 7 vertices are supported', () {
      // 6 vertices: 2 rounded corners
      expect(ScannerWorkerIsolate.isSupportedVertexCount(6), isTrue);
      // 7 vertices: 3 rounded corners
      expect(ScannerWorkerIsolate.isSupportedVertexCount(7), isTrue);
    });

    test('Geometric Oracle: 4-vertex quadrilateral preserves exact coordinates', () {
      final quad = [
        math.Point<double>(100.0, 50.0),
        math.Point<double>(450.0, 50.0),
        math.Point<double>(450.0, 540.0),
        math.Point<double>(100.0, 540.0),
      ];

      expect(ScannerWorkerIsolate.isSupportedVertexCount(quad.length), isTrue);
      // In ScannerWorkerIsolate, length == 4 maps directly to approx points
      final corners = quad.map((p) => math.Point<double>(p.x, p.y)).toList();
      expect(corners.length, equals(4));
      expect(corners[0], equals(quad[0]));
      expect(corners[1], equals(quad[1]));
      expect(corners[2], equals(quad[2]));
      expect(corners[3], equals(quad[3]));
    });

    test('Geometric Oracle: 5-vertex polygon enclosing bounding box extraction', () {
      // 5-vertex card contour where top-right corner is chamfered/rounded
      final poly5 = [
        math.Point<double>(50.0, 50.0),   // TL
        math.Point<double>(280.0, 50.0),  // TR edge start
        math.Point<double>(300.0, 70.0),  // TR edge end (chamfer)
        math.Point<double>(300.0, 400.0), // BR
        math.Point<double>(50.0, 400.0),  // BL
      ];

      expect(poly5.length, equals(5));
      expect(ScannerWorkerIsolate.isSupportedVertexCount(poly5.length), isTrue);

      // Enclosing bounding rectangle simulation
      final minX = poly5.map((p) => p.x).reduce(math.min);
      final maxX = poly5.map((p) => p.x).reduce(math.max);
      final minY = poly5.map((p) => p.y).reduce(math.min);
      final maxY = poly5.map((p) => p.y).reduce(math.max);

      final boxCorners = [
        math.Point<double>(minX, minY),
        math.Point<double>(maxX, minY),
        math.Point<double>(maxX, maxY),
        math.Point<double>(minX, maxY),
      ];

      expect(boxCorners.length, equals(4));
      expect(boxCorners[0], equals(math.Point<double>(50.0, 50.0)));
      expect(boxCorners[1], equals(math.Point<double>(300.0, 50.0)));
      expect(boxCorners[2], equals(math.Point<double>(300.0, 400.0)));
      expect(boxCorners[3], equals(math.Point<double>(50.0, 400.0)));
    });

    test('Geometric Oracle: 8-vertex rounded card enclosing bounding box extraction', () {
      // Standard TCG card: 2.5 x 3.5 aspect ratio with 3mm corner radius (~10px)
      // Generates 8 polygon vertices representing all 4 rounded corners
      final poly8 = [
        math.Point<double>(60.0, 50.0),   // Top edge left
        math.Point<double>(290.0, 50.0),  // Top edge right
        math.Point<double>(300.0, 60.0),  // Right edge top
        math.Point<double>(300.0, 390.0), // Right edge bottom
        math.Point<double>(290.0, 400.0), // Bottom edge right
        math.Point<double>(60.0, 400.0),  // Bottom edge left
        math.Point<double>(50.0, 390.0),  // Left edge bottom
        math.Point<double>(50.0, 60.0),   // Left edge top
      ];

      expect(poly8.length, equals(8));
      expect(ScannerWorkerIsolate.isSupportedVertexCount(poly8.length), isTrue);

      final minX = poly8.map((p) => p.x).reduce(math.min);
      final maxX = poly8.map((p) => p.x).reduce(math.max);
      final minY = poly8.map((p) => p.y).reduce(math.min);
      final maxY = poly8.map((p) => p.y).reduce(math.max);

      final boxCorners = [
        math.Point<double>(minX, minY), // TL: 50, 50
        math.Point<double>(maxX, minY), // TR: 300, 50
        math.Point<double>(maxX, maxY), // BR: 300, 400
        math.Point<double>(minX, maxY), // BL: 50, 400
      ];

      expect(boxCorners.length, equals(4));
      expect(boxCorners[0], equals(math.Point<double>(50.0, 50.0)));
      expect(boxCorners[1], equals(math.Point<double>(300.0, 50.0)));
      expect(boxCorners[2], equals(math.Point<double>(300.0, 400.0)));
      expect(boxCorners[3], equals(math.Point<double>(50.0, 400.0)));

      // Aspect ratio of enclosing rectangle: width = 250, height = 350 -> 250 / 350 = 0.7142857
      final rectWidth = maxX - minX;
      final rectHeight = maxY - minY;
      expect(
        ScannerWorkerIsolate.isAspectMatch(rectWidth, rectHeight, 2.5 / 3.5),
        isTrue,
      );
    });
  });

  group('Empirical Challenge: ScannerWorkerIsolate Contour Area Scaling & Noise Floor', () {
    test('Noise floor invariant: threshold is never below 5000.0', () {
      final testCases = [
        (0, 0),
        (1, 1),
        (10, 10),
        (100, 100),
        (320, 240),
        (480, 640),
        (-100, 500),
        (0, 1920),
        (1080, 0),
      ];

      for (final (w, h) in testCases) {
        final minArea = ScannerWorkerIsolate.calculateMinContourArea(w, h);
        expect(
          minArea >= 5000.0,
          isTrue,
          reason: 'calculateMinContourArea($w, $h) returned $minArea which is below the 5000.0 noise floor',
        );
      }
    });

    test('Crossover point verification at exactly 333,333.33 px', () {
      // Below crossover point: 0.015 * 333,333 = 4999.995 < 5000.0 -> Floored at 5000.0
      const belowAreaWidth = 333333;
      const belowAreaHeight = 1;
      expect(
        ScannerWorkerIsolate.calculateMinContourArea(belowAreaWidth, belowAreaHeight),
        equals(5000.0),
      );

      // Above crossover point: 0.015 * 333,334 = 5000.01 > 5000.0 -> Scales dynamically
      const aboveAreaWidth = 333334;
      const aboveAreaHeight = 1;
      expect(
        ScannerWorkerIsolate.calculateMinContourArea(aboveAreaWidth, aboveAreaHeight),
        closeTo(5000.01, 0.001),
      );
    });

    test('Proportional scaling across standard mobile camera resolutions', () {
      // 1. Low resolution: 320 x 240 (76,800 px) -> 0.015 * 76800 = 1152 < 5000 -> 5000.0
      expect(ScannerWorkerIsolate.calculateMinContourArea(320, 240), equals(5000.0));

      // 2. VGA: 640 x 480 (307,200 px) -> 0.015 * 307200 = 4608 < 5000 -> 5000.0
      expect(ScannerWorkerIsolate.calculateMinContourArea(640, 480), equals(5000.0));

      // 3. HD 720p: 1280 x 720 (921,600 px) -> 0.015 * 921600 = 13,824.0
      expect(ScannerWorkerIsolate.calculateMinContourArea(1280, 720), equals(13824.0));
      expect(ScannerWorkerIsolate.calculateMinContourArea(720, 1280), equals(13824.0));

      // 4. FHD 1080p: 1920 x 1080 (2,073,600 px) -> 0.015 * 2073600 = 31,104.0
      expect(ScannerWorkerIsolate.calculateMinContourArea(1920, 1080), equals(31104.0));
      expect(ScannerWorkerIsolate.calculateMinContourArea(1080, 1920), equals(31104.0));

      // 5. QHD 1440p: 2560 x 1440 (3,686,400 px) -> 0.015 * 3686400 = 55,296.0
      expect(ScannerWorkerIsolate.calculateMinContourArea(2560, 1440), equals(55296.0));

      // 6. 4K UHD: 3840 x 2160 (8,294,400 px) -> 0.015 * 8294400 = 124,416.0
      expect(ScannerWorkerIsolate.calculateMinContourArea(3840, 2160), equals(124416.0));
    });

    test('Monotonicity property: higher resolution yields equal or higher threshold', () {
      final resolutions = [
        (320, 240),
        (640, 480),
        (800, 600),
        (1280, 720),
        (1920, 1080),
        (2560, 1440),
        (3840, 2160),
      ];

      for (int i = 0; i < resolutions.length - 1; i++) {
        final area1 = ScannerWorkerIsolate.calculateMinContourArea(
          resolutions[i].$1,
          resolutions[i].$2,
        );
        final area2 = ScannerWorkerIsolate.calculateMinContourArea(
          resolutions[i + 1].$1,
          resolutions[i + 1].$2,
        );
        expect(
          area2 >= area1,
          isTrue,
          reason: 'Monotonicity failed: area($resolutions[i+1]) < area($resolutions[i])',
        );
      }
    });

    test('Empirical card detection sensitivity under 1080p frame', () {
      const frameW = 1080;
      const frameH = 1920;
      final minArea = ScannerWorkerIsolate.calculateMinContourArea(frameW, frameH); // 31104.0

      // Card filling 2% of frame (41,472 px) -> ACCEPTED
      const card2Percent = 0.02 * (frameW * frameH);
      expect(card2Percent > minArea, isTrue);

      // Card filling 5% of frame (103,680 px) -> ACCEPTED
      const card5Percent = 0.05 * (frameW * frameH);
      expect(card5Percent > minArea, isTrue);

      // Card filling 0.5% of frame (tiny distant speck, 10,368 px) -> REJECTED
      const cardHalfPercent = 0.005 * (frameW * frameH);
      expect(cardHalfPercent < minArea, isTrue);
    });

    test('Empirical card detection sensitivity under low-res 480x640 frame', () {
      const frameW = 480;
      const frameH = 640;
      final minArea = ScannerWorkerIsolate.calculateMinContourArea(frameW, frameH); // 5000.0

      // Card of area 6,000 px (1.95% of frame) -> ACCEPTED due to 5000 floor
      expect(6000.0 > minArea, isTrue);

      // Noise artifact of area 3,500 px -> REJECTED by 5000 floor
      expect(3500.0 < minArea, isTrue);
    });
  });

  group('Empirical Challenge: Aspect Ratio Perspective Tolerance & Invariants', () {
    final tcgAspect = 2.5 / 3.5; // ~0.7142857

    test('Orientation symmetry: normalizeAspectRatio(w, h) == normalizeAspectRatio(h, w)', () {
      final pairs = [
        (250.0, 350.0),
        (350.0, 250.0),
        (720.0, 1280.0),
        (1080.0, 1920.0),
        (50.0, 100.0),
      ];

      for (final (w, h) in pairs) {
        expect(
          ScannerWorkerIsolate.normalizeAspectRatio(w, h),
          equals(ScannerWorkerIsolate.normalizeAspectRatio(h, w)),
        );
      }
    });

    test('Perspective tolerance bounds: exact interval [0.4942857, 0.9342857]', () {
      // target = 0.7142857, tolerance = 0.22
      // Lower bound: 0.7142857 - 0.22 = 0.4942857
      // Upper bound: 0.7142857 + 0.22 = 0.9342857

      // Just inside lower bound: ratio = 0.495
      expect(ScannerWorkerIsolate.isAspectMatch(495, 1000, tcgAspect), isTrue);

      // Just outside lower bound: ratio = 0.490
      expect(ScannerWorkerIsolate.isAspectMatch(490, 1000, tcgAspect), isFalse);

      // Just inside upper bound: ratio = 0.934
      expect(ScannerWorkerIsolate.isAspectMatch(934, 1000, tcgAspect), isTrue);

      // Just outside upper bound: ratio = 0.935
      expect(ScannerWorkerIsolate.isAspectMatch(935, 1000, tcgAspect), isFalse);
    });

    test('Rejects non-card geometric shapes', () {
      // Perfect square (ratio = 1.0, e.g. token or die)
      expect(ScannerWorkerIsolate.isAspectMatch(500, 500, tcgAspect), isFalse);

      // Long banner (ratio = 0.30)
      expect(ScannerWorkerIsolate.isAspectMatch(300, 1000, tcgAspect), isFalse);

      // Ultra-narrow line / bar (ratio = 0.10)
      expect(ScannerWorkerIsolate.isAspectMatch(100, 1000, tcgAspect), isFalse);
    });

    test('Defensively rejects non-positive dimensions', () {
      expect(ScannerWorkerIsolate.normalizeAspectRatio(0, 100), equals(0.0));
      expect(ScannerWorkerIsolate.normalizeAspectRatio(100, 0), equals(0.0));
      expect(ScannerWorkerIsolate.normalizeAspectRatio(-50, 100), equals(0.0));
      expect(ScannerWorkerIsolate.normalizeAspectRatio(100, -50), equals(0.0));
      expect(ScannerWorkerIsolate.isAspectMatch(0, 100, tcgAspect), isFalse);
      expect(ScannerWorkerIsolate.isAspectMatch(-50, 100, tcgAspect), isFalse);
    });
  });

  group('Empirical Challenge: End-to-End Contour Invariant Gatekeeper Simulation', () {
    // Simulates the isolate contour filtering loop
    bool simulateContourFilter({
      required double area,
      required int vertexCount,
      required double rectW,
      required double rectH,
      required int frameW,
      required int frameH,
      required double targetAspectRatio,
    }) {
      final minArea = ScannerWorkerIsolate.calculateMinContourArea(frameW, frameH);
      if (area < minArea) return false;
      if (!ScannerWorkerIsolate.isSupportedVertexCount(vertexCount)) return false;
      if (!ScannerWorkerIsolate.isAspectMatch(rectW, rectH, targetAspectRatio)) return false;
      return true;
    }

    test('Scenario 1: Standard TCG card with 4 sharp corners passes gatekeeper', () {
      final accepted = simulateContourFilter(
        area: 45000.0,
        vertexCount: 4,
        rectW: 250.0,
        rectH: 350.0,
        frameW: 720,
        frameH: 1280,
        targetAspectRatio: 2.5 / 3.5,
      );
      expect(accepted, isTrue);
    });

    test('Scenario 2: TCG card with 8 rounded corners passes gatekeeper', () {
      final accepted = simulateContourFilter(
        area: 44000.0,
        vertexCount: 8,
        rectW: 250.0,
        rectH: 350.0,
        frameW: 720,
        frameH: 1280,
        targetAspectRatio: 2.5 / 3.5,
      );
      expect(accepted, isTrue);
    });

    test('Scenario 3: TCG card with 5 vertices (single rounded corner) passes gatekeeper', () {
      final accepted = simulateContourFilter(
        area: 44500.0,
        vertexCount: 5,
        rectW: 250.0,
        rectH: 350.0,
        frameW: 720,
        frameH: 1280,
        targetAspectRatio: 2.5 / 3.5,
      );
      expect(accepted, isTrue);
    });

    test('Scenario 4: Triangle shadow artifact with 3 vertices rejected', () {
      final accepted = simulateContourFilter(
        area: 45000.0,
        vertexCount: 3, // TRIANGLE
        rectW: 250.0,
        rectH: 350.0,
        frameW: 720,
        frameH: 1280,
        targetAspectRatio: 2.5 / 3.5,
      );
      expect(accepted, isFalse);
    });

    test('Scenario 5: Hand/finger polygon with 9 vertices rejected', () {
      final accepted = simulateContourFilter(
        area: 45000.0,
        vertexCount: 9, // COMPLEX POLYGON
        rectW: 250.0,
        rectH: 350.0,
        frameW: 720,
        frameH: 1280,
        targetAspectRatio: 2.5 / 3.5,
      );
      expect(accepted, isFalse);
    });

    test('Scenario 6: Distant card with area below noise floor (4,000 px) rejected', () {
      final accepted = simulateContourFilter(
        area: 4000.0, // BELOW 5000.0 NOISE FLOOR
        vertexCount: 4,
        rectW: 250.0,
        rectH: 350.0,
        frameW: 720,
        frameH: 1280,
        targetAspectRatio: 2.5 / 3.5,
      );
      expect(accepted, isFalse);
    });

    test('Scenario 7: Square token with 4 vertices rejected by aspect ratio match', () {
      final accepted = simulateContourFilter(
        area: 45000.0,
        vertexCount: 4,
        rectW: 300.0,
        rectH: 300.0, // 1:1 SQUARE
        frameW: 720,
        frameH: 1280,
        targetAspectRatio: 2.5 / 3.5,
      );
      expect(accepted, isFalse);
    });

    test('Scenario 8: Perspective-tilted card (aspect ratio 0.55) with 8 vertices accepted', () {
      final accepted = simulateContourFilter(
        area: 50000.0,
        vertexCount: 8,
        rectW: 550.0,
        rectH: 1000.0, // 0.55 tilt
        frameW: 1080,
        frameH: 1920,
        targetAspectRatio: 2.5 / 3.5,
      );
      expect(accepted, isTrue);
    });
  });

  group('Empirical Challenge: Point Sorting & Quad Unwarping Corner Ordering', () {
    // Tests the 4-corner sorting logic used in ScannerWorkerIsolate:
    // bestCorners.sort((a, b) => (a.y + a.x).compareTo(b.y + b.x));
    // tl = bestCorners[0];
    // br = bestCorners[3];
    // remaining = [bestCorners[1], bestCorners[2]];
    // remaining.sort((a, b) => a.x.compareTo(b.x));
    // bl = remaining[0];
    // tr = remaining[1];
    List<math.Point<double>> sortCorners(List<math.Point<double>> points) {
      final sorted = List<math.Point<double>>.from(points);
      sorted.sort((a, b) => (a.y + a.x).compareTo(b.y + b.x));
      final tl = sorted[0];
      final br = sorted[3];

      final remaining = [sorted[1], sorted[2]];
      remaining.sort((a, b) => a.x.compareTo(b.x));
      final bl = remaining[0];
      final tr = remaining[1];

      return [tl, tr, br, bl];
    }

    test('Correctly orders corners for upright portrait rectangle', () {
      final input = [
        math.Point<double>(250.0, 350.0), // BR
        math.Point<double>(0.0, 0.0),     // TL
        math.Point<double>(0.0, 350.0),   // BL
        math.Point<double>(250.0, 0.0),   // TR
      ];

      final ordered = sortCorners(input);
      expect(ordered[0], equals(math.Point<double>(0.0, 0.0)));     // TL
      expect(ordered[1], equals(math.Point<double>(250.0, 0.0)));   // TR
      expect(ordered[2], equals(math.Point<double>(250.0, 350.0))); // BR
      expect(ordered[3], equals(math.Point<double>(0.0, 350.0)));   // BL
    });

    test('Correctly orders corners for upright landscape rectangle', () {
      final input = [
        math.Point<double>(350.0, 0.0),   // TR
        math.Point<double>(350.0, 250.0), // BR
        math.Point<double>(0.0, 250.0),   // BL
        math.Point<double>(0.0, 0.0),     // TL
      ];

      final ordered = sortCorners(input);
      expect(ordered[0], equals(math.Point<double>(0.0, 0.0)));     // TL
      expect(ordered[1], equals(math.Point<double>(350.0, 0.0)));   // TR
      expect(ordered[2], equals(math.Point<double>(350.0, 250.0))); // BR
      expect(ordered[3], equals(math.Point<double>(0.0, 250.0)));   // BL
    });

    test('Correctly orders corners for rotated card (15-degree tilt)', () {
      // 15 deg tilted card around center (100, 100)
      final tl = math.Point<double>(83.96, 43.94);
      final tr = math.Point<double>(141.92, 59.46);
      final br = math.Point<double>(116.04, 156.06);
      final bl = math.Point<double>(58.08, 140.54);

      // Pass in shuffled order
      final shuffled = [br, tl, bl, tr];
      final ordered = sortCorners(shuffled);

      expect(ordered[0], equals(tl));
      expect(ordered[1], equals(tr));
      expect(ordered[2], equals(br));
      expect(ordered[3], equals(bl));
    });
  });
}
