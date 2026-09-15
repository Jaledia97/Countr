import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/scanner/domain/card_perimeter_calculator.dart';
import 'package:countr/features/scanner/presentation/screens/scanner_modal.dart';
import 'package:countr/features/scanner/presentation/widgets/dynamic_scanner_overlay.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';

void main() {
  TextBlock createBlock(Rect boundingBox, {String text = 'Card Text'}) {
    return TextBlock(
      text: text,
      lines: const [],
      boundingBox: boundingBox,
      recognizedLanguages: const [],
      cornerPoints: const [],
    );
  }

  group('CardPerimeterCalculator.calculatePerimeter', () {
    test('returns null when block list is empty', () {
      final perimeter = CardPerimeterCalculator.calculatePerimeter([]);
      expect(perimeter, isNull);
    });

    test('returns null when all blocks have zero or negative dimensions', () {
      final blocks = [
        createBlock(const Rect.fromLTWH(10, 10, 0, 50)),
        createBlock(const Rect.fromLTWH(20, 20, 50, 0)),
        createBlock(const Rect.fromLTWH(30, 30, -5, -5)),
      ];
      final perimeter = CardPerimeterCalculator.calculatePerimeter(blocks);
      expect(perimeter, isNull);
    });

    test('calculates single block perimeter with default padding (8% x, 12% y)', () {
      // Box: left: 100, top: 100, width: 200, height: 300
      // rawWidth = 200, padX = 200 * 0.08 = 16
      // rawHeight = 300, padY = 300 * 0.12 = 36
      final blocks = [
        createBlock(const Rect.fromLTWH(100, 100, 200, 300)),
      ];
      final perimeter = CardPerimeterCalculator.calculatePerimeter(blocks);

      expect(perimeter, isNotNull);
      expect(perimeter!.left, 84.0);
      expect(perimeter.top, 64.0);
      expect(perimeter.right, 316.0);
      expect(perimeter.bottom, 436.0);
      expect(perimeter.width, 232.0);
      expect(perimeter.height, 372.0);
    });

    test('calculates enclosing bounding perimeter across multiple blocks', () {
      // Block 1: left 50, top 60, right 150, bottom 90
      // Block 2: left 80, top 200, right 200, bottom 240
      // Enclosing: minLeft = 50, minTop = 60, maxRight = 200, maxBottom = 240
      // rawWidth = 150, rawHeight = 180
      // padX = 150 * 0.10 = 15, padY = 180 * 0.10 = 18
      final blocks = [
        createBlock(const Rect.fromLTWH(50, 60, 100, 30)),
        createBlock(const Rect.fromLTWH(80, 200, 120, 40)),
      ];

      final perimeter = CardPerimeterCalculator.calculatePerimeter(
        blocks,
        padXPercent: 0.10,
        padYPercent: 0.10,
      );

      expect(perimeter, isNotNull);
      expect(perimeter!.left, 35.0);
      expect(perimeter.top, 42.0);
      expect(perimeter.right, 215.0);
      expect(perimeter.bottom, 258.0);
    });

    test('clamps perimeter to imageSize boundaries', () {
      // Block positioned close to the origin (5, 5) with width 100, height 100
      // padX = 8, padY = 12
      // Unclamped left = -3, top = -7 -> clamped to 0.0, 0.0
      // Block near bottom right on 200x200 image
      final blocks = [
        createBlock(const Rect.fromLTWH(5, 5, 190, 190)),
      ];

      final perimeter = CardPerimeterCalculator.calculatePerimeter(
        blocks,
        imageSize: const Size(200, 200),
      );

      expect(perimeter, isNotNull);
      expect(perimeter!.left, 0.0);
      expect(perimeter.top, 0.0);
      expect(perimeter.right, 200.0);
      expect(perimeter.bottom, 200.0);
    });

    test('ignores blocks with zero area while calculating valid blocks', () {
      final blocks = [
        createBlock(const Rect.fromLTWH(0, 0, 0, 0)),
        createBlock(const Rect.fromLTWH(100, 100, 100, 100)),
      ];

      final perimeter = CardPerimeterCalculator.calculatePerimeter(
        blocks,
        padXPercent: 0.0,
        padYPercent: 0.0,
      );

      expect(perimeter, isNotNull);
      expect(perimeter!.left, 100.0);
      expect(perimeter.top, 100.0);
      expect(perimeter.right, 200.0);
      expect(perimeter.bottom, 200.0);
    });
  });

  group('CardPerimeterCalculator.mapImageRectToScreen', () {
    test('maps image coordinates to screen with BoxFit.cover (uniform aspect)', () {
      // imageSize: 1000 x 2000, screenSize: 500 x 1000 -> scale = 0.5, offsets = 0, 0
      final imageRect = const Rect.fromLTWH(100, 200, 400, 600);
      final mapped = CardPerimeterCalculator.mapImageRectToScreen(
        imageRect: imageRect,
        imageSize: const Size(1000, 2000),
        screenSize: const Size(500, 1000),
        fit: BoxFit.cover,
      );

      expect(mapped.left, 50.0);
      expect(mapped.top, 100.0);
      expect(mapped.width, 200.0);
      expect(mapped.height, 300.0);
    });

    test('maps image coordinates with BoxFit.cover and horizontal centering offset', () {
      // imageSize: 1000 x 1000, screenSize: 400 x 800
      // scale = max(400/1000, 800/1000) = 0.8
      // scaledWidth = 800, scaledHeight = 800
      // offsetX = (400 - 800) / 2 = -200, offsetY = (800 - 800) / 2 = 0
      // imageRect: left 250, top 100, width 500, height 500
      // screen left = 250 * 0.8 - 200 = 0.0
      // screen top = 100 * 0.8 + 0 = 80.0
      // screen width = 500 * 0.8 = 400.0
      // screen height = 500 * 0.8 = 400.0
      final imageRect = const Rect.fromLTWH(250, 100, 500, 500);
      final mapped = CardPerimeterCalculator.mapImageRectToScreen(
        imageRect: imageRect,
        imageSize: const Size(1000, 1000),
        screenSize: const Size(400, 800),
        fit: BoxFit.cover,
      );

      expect(mapped.left, 0.0);
      expect(mapped.top, 80.0);
      expect(mapped.width, 400.0);
      expect(mapped.height, 400.0);
    });

    test('maps image coordinates with BoxFit.contain and vertical centering offset', () {
      // imageSize: 1000 x 1000, screenSize: 400 x 800
      // scale = min(400/1000, 800/1000) = 0.4
      // scaledWidth = 400, scaledHeight = 400
      // offsetX = 0, offsetY = (800 - 400) / 2 = 200
      // imageRect: left 100, top 100, width 200, height 200
      // screen left = 100 * 0.4 + 0 = 40.0
      // screen top = 100 * 0.4 + 200 = 240.0
      final imageRect = const Rect.fromLTWH(100, 100, 200, 200);
      final mapped = CardPerimeterCalculator.mapImageRectToScreen(
        imageRect: imageRect,
        imageSize: const Size(1000, 1000),
        screenSize: const Size(400, 800),
        fit: BoxFit.contain,
      );

      expect(mapped.left, 40.0);
      expect(mapped.top, 240.0);
      expect(mapped.width, 80.0);
      expect(mapped.height, 80.0);
    });

    test('clamps mapped coordinates to screen bounds when clampToScreen is true', () {
      final imageRect = const Rect.fromLTWH(0, 0, 500, 500);
      final mapped = CardPerimeterCalculator.mapImageRectToScreen(
        imageRect: imageRect,
        imageSize: const Size(1000, 1000),
        screenSize: const Size(400, 800),
        fit: BoxFit.cover,
        clampToScreen: true,
      );

      expect(mapped.left, 0.0);
      expect(mapped.right, lessThanOrEqualTo(400.0));
      expect(mapped.top, 0.0);
      expect(mapped.bottom, lessThanOrEqualTo(800.0));
    });

    test('returns original imageRect if imageSize or screenSize is zero', () {
      const rect = Rect.fromLTWH(10, 20, 30, 40);
      final mapped = CardPerimeterCalculator.mapImageRectToScreen(
        imageRect: rect,
        imageSize: Size.zero,
        screenSize: const Size(400, 800),
      );
      expect(mapped, rect);
    });
  });

  group('CardPerimeterCalculator.getUprightImageSize', () {
    const raw = Size(1920, 1080);

    test('returns original dimensions for rotation0deg and rotation180deg', () {
      expect(
        CardPerimeterCalculator.getUprightImageSize(
          rawSize: raw,
          rotation: InputImageRotation.rotation0deg,
        ),
        raw,
      );
      expect(
        CardPerimeterCalculator.getUprightImageSize(
          rawSize: raw,
          rotation: InputImageRotation.rotation180deg,
        ),
        raw,
      );
      expect(
        CardPerimeterCalculator.getUprightImageSize(
          rawSize: raw,
          rotation: null,
        ),
        raw,
      );
    });

    test('swaps width and height for rotation90deg and rotation270deg', () {
      const upright = Size(1080, 1920);
      expect(
        CardPerimeterCalculator.getUprightImageSize(
          rawSize: raw,
          rotation: InputImageRotation.rotation90deg,
        ),
        upright,
      );
      expect(
        CardPerimeterCalculator.getUprightImageSize(
          rawSize: raw,
          rotation: InputImageRotation.rotation270deg,
        ),
        upright,
      );
    });
  });

  group('CardPerimeterCalculator.clampRectToScreen', () {
    test('clamps negative and overflowing coordinates to screen dimensions', () {
      const screen = Size(400, 800);
      const outOfBounds = Rect.fromLTRB(-50, -20, 450, 900);

      final clamped = CardPerimeterCalculator.clampRectToScreen(outOfBounds, screen);

      expect(clamped.left, 0.0);
      expect(clamped.top, 0.0);
      expect(clamped.right, 400.0);
      expect(clamped.bottom, 800.0);
    });
  });

  group('DynamicScannerOverlay Widget Tests', () {
    testWidgets('renders empty shrink widget when cardBounds is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DynamicScannerOverlay(
              cardBounds: null,
              isGreenFlash: false,
              isPaused: false,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('dynamic_scanner_overlay_empty')), findsOneWidget);
      expect(find.byKey(const Key('corner_bracket_tl')), findsNothing);
    });

    testWidgets('renders 4 corner brackets when cardBounds are provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DynamicScannerOverlay(
              cardBounds: Rect.fromLTWH(50, 100, 200, 300),
              isGreenFlash: false,
              isPaused: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('corner_bracket_tl')), findsOneWidget);
      expect(find.byKey(const Key('corner_bracket_tr')), findsOneWidget);
      expect(find.byKey(const Key('corner_bracket_bl')), findsOneWidget);
      expect(find.byKey(const Key('corner_bracket_br')), findsOneWidget);
    });

    testWidgets('renders bounded laser scan line when active and animation supplied', (tester) async {
      final controller = AnimationController(
        vsync: const TestVSync(),
        value: 0.5,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DynamicScannerOverlay(
              cardBounds: const Rect.fromLTWH(50, 100, 200, 300),
              isGreenFlash: false,
              isPaused: false,
              scanLineAnimation: controller,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('bounded_laser_scan_line')), findsOneWidget);
      controller.dispose();
    });

    testWidgets('hides laser scan line when scanner is paused', (tester) async {
      final controller = AnimationController(
        vsync: const TestVSync(),
        value: 0.5,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DynamicScannerOverlay(
              cardBounds: const Rect.fromLTWH(50, 100, 200, 300),
              isGreenFlash: false,
              isPaused: true,
              scanLineAnimation: controller,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('bounded_laser_scan_line')), findsNothing);
      controller.dispose();
    });
  });

  group('ScannerModal Dynamic UX & Testing Hooks', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await db.vaultDao.clearAllItems();
    });

    tearDown(() async {
      await db.close();
    });

    Widget createTestWidget(Widget child) {
      return ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
        ],
        child: MaterialApp(
          home: child,
        ),
      );
    }

    testWidgets('ScannerModal renders DynamicScannerOverlay without static 0.70 reticle', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestWidget(const ScannerModal()));
      await tester.pump(const Duration(milliseconds: 300));

      // 1. DynamicScannerOverlay is present
      expect(find.byType(DynamicScannerOverlay), findsOneWidget);

      // 2. Static AspectRatio 0.70 is NOT present
      final aspectRatios = tester.widgetList<AspectRatio>(find.byType(AspectRatio));
      final hasStatic070Reticle = aspectRatios.any((ar) => (ar.aspectRatio - 0.70).abs() < 0.001);
      expect(hasStatic070Reticle, isFalse, reason: 'Static 0.70 reticle must be eliminated');

      // 3. Testing hooks on state
      final state = tester.state(find.byType(ScannerModal)) as dynamic;
      expect(state.frameCount, 0);
      expect(state.isProcessing, isFalse);
      expect(state.detectedCardBounds, isNull);

      // 4. Simulate detected card bounds snaps overlay
      state.simulateDetectedBounds(const Rect.fromLTWH(60, 120, 240, 360));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(state.detectedCardBounds, const Rect.fromLTWH(60, 120, 240, 360));
      expect(find.byKey(const Key('corner_bracket_tl')), findsOneWidget);

      // Cleanup
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });
  });
}
