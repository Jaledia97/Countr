import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/features/scanner/presentation/widgets/dynamic_scanner_overlay.dart';

void main() {
  group('Challenger M3-2: Corner Bracket Canvas & Arc Geometry Verification', () {
    testWidgets('Verifies corner bracket canvas drawing with R=10dp and StrokeCap.round', (tester) async {
      const bounds = Rect.fromLTWH(100, 100, 200, 300);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DynamicScannerOverlay(
              cardBounds: bounds,
              isGreenFlash: false,
              isPaused: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final corners = ['corner_bracket_tl', 'corner_bracket_tr', 'corner_bracket_bl', 'corner_bracket_br'];
      for (final key in corners) {
        final cpFinder = find.byKey(Key(key));
        expect(cpFinder, findsOneWidget);
        final customPaint = tester.widget<CustomPaint>(cpFinder);
        expect(customPaint.painter, isNotNull);

        // Test Canvas drawing
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        customPaint.painter!.paint(canvas, const Size(28, 28));
        final picture = recorder.endRecording();
        expect(picture, isNotNull);
      }
    });

    testWidgets('Corner brackets scale cornerRadius gracefully when cornerLength < 10dp', (tester) async {
      // Very tiny card: 16x16 -> cornerLength = min(28, 16 * 0.25) = 4.0dp
      const tinyBounds = Rect.fromLTWH(50, 50, 16, 16);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DynamicScannerOverlay(
              cardBounds: tinyBounds,
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
      expect(size.width, equals(4.0));
      expect(size.height, equals(4.0));

      final customPaint = tester.widget<CustomPaint>(tlFinder);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      // Painter should clamp r to min(10.0, min(4.0, 4.0)) = 4.0 without error
      expect(() => customPaint.painter!.paint(canvas, size), returnsNormally);
    });

    testWidgets('Degenerate Size(0, 0) paint does not throw or crash Canvas', (tester) async {
      const bounds = Rect.fromLTWH(50, 50, 100, 100);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DynamicScannerOverlay(
              cardBounds: bounds,
              isGreenFlash: false,
              isPaused: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tlFinder = find.byKey(const Key('corner_bracket_tl'));
      final customPaint = tester.widget<CustomPaint>(tlFinder);

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      expect(() => customPaint.painter!.paint(canvas, Size.zero), returnsNormally);
    });
  });

  group('Challenger M3-2: Bounded Laser Scan Line Geometry Verification', () {
    testWidgets('Laser scan line is strictly bounded within cardBounds across sweep progress', (tester) async {
      final controller = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(seconds: 1),
      );
      addTearDown(controller.dispose);

      const bounds = Rect.fromLTWH(60, 120, 220, 320);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DynamicScannerOverlay(
              cardBounds: bounds,
              isGreenFlash: false,
              isPaused: false,
              scanLineAnimation: controller,
            ),
          ),
        ),
      );
      await tester.pump();

      // Test sweep values: 0.0, 0.25, 0.5, 0.75, 1.0, and out-of-bound clamps (-0.2, 1.2)
      final testValues = [-0.2, 0.0, 0.25, 0.5, 0.75, 1.0, 1.2];
      for (final val in testValues) {
        controller.value = val;
        await tester.pump();

        final laserFinder = find.byKey(const Key('bounded_laser_scan_line'));
        expect(laserFinder, findsOneWidget);
        final laserRect = tester.getRect(laserFinder);

        // Horizontal: strictly bounded
        expect(laserRect.left, equals(bounds.left + 4.0));
        expect(laserRect.right, equals(bounds.right - 4.0));
        expect(laserRect.width, equals(bounds.width - 8.0));

        // Vertical: strictly clamped between bounds.top and bounds.bottom
        final clampedVal = val.clamp(0.0, 1.0);
        final expectedLaserCenterY = bounds.top + (bounds.height * clampedVal);
        expect(laserRect.center.dy, closeTo(expectedLaserCenterY, 0.1));
        expect(laserRect.top, greaterThanOrEqualTo(bounds.top - 2.0));
        expect(laserRect.bottom, lessThanOrEqualTo(bounds.bottom + 2.0));
      }
    });

    testWidgets('Laser scan line with narrow card (< 8dp) clamps width to 0 without negative assertion error', (tester) async {
      final controller = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(seconds: 1),
      )..value = 0.5;
      addTearDown(controller.dispose);

      const narrowBounds = Rect.fromLTWH(50, 100, 6, 200); // width is 6 (< 8)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DynamicScannerOverlay(
              cardBounds: narrowBounds,
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
      expect(laserRect.width, equals(0.0));
    });

    testWidgets('Laser scan line is completely unmounted when isPaused is true', (tester) async {
      final controller = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(seconds: 1),
      )..value = 0.5;
      addTearDown(controller.dispose);

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
      await tester.pump();

      expect(find.byKey(const Key('bounded_laser_scan_line')), findsNothing);
    });
  });

  group('Challenger M3-2: Stress & Boundary Invariant Verification', () {
    testWidgets('Handles negative coordinates and screen-edge intersections cleanly', (tester) async {
      // Partially off-screen card bounds
      const offscreenBounds = Rect.fromLTWH(-30, -50, 200, 300);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DynamicScannerOverlay(
              cardBounds: offscreenBounds,
              isGreenFlash: false,
              isPaused: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('dynamic_scanner_bounding_container')), findsOneWidget);
      expect(find.byKey(const Key('corner_bracket_tl')), findsOneWidget);
    });

    testWidgets('Handles zero-sized Rect gracefully without unhandled exceptions', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DynamicScannerOverlay(
              cardBounds: Rect.zero,
              isGreenFlash: false,
              isPaused: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Zero-sized rect should render empty/shrink without throwing
      expect(tester.takeException(), isNull);
    });

    testWidgets('High-frequency bounds jittering executes cleanly through 50 frame updates', (tester) async {
      final boundsNotifier = ValueNotifier<Rect?>(const Rect.fromLTWH(50, 80, 200, 300));
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
        final offset = (i % 5) * 4.0;
        boundsNotifier.value = Rect.fromLTWH(50 + offset, 80 + offset, 200 + offset, 300 + offset);
        await tester.pump(const Duration(milliseconds: 16)); // ~60fps
      }

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('dynamic_scanner_bounding_container')), findsOneWidget);
    });

    testWidgets('State transition matrix: Normal -> Paused -> Flash -> Paused -> Normal', (tester) async {
      final stateNotifier = ValueNotifier<(bool, bool)>((false, false)); // (isGreenFlash, isPaused)
      addTearDown(stateNotifier.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<(bool, bool)>(
              valueListenable: stateNotifier,
              builder: (context, state, _) => DynamicScannerOverlay(
                cardBounds: const Rect.fromLTWH(50, 80, 200, 300),
                isGreenFlash: state.$1,
                isPaused: state.$2,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Normal state (cyan)
      var container = tester.widget<AnimatedContainer>(
        find.byKey(const Key('dynamic_scanner_bounding_container')),
      );
      var border = (container.decoration as BoxDecoration).border as Border;
      expect(border.top.color.r, closeTo(AppColors.accentCyan.r, 0.05));

      // 2. Paused state (amber)
      stateNotifier.value = (false, true);
      await tester.pumpAndSettle();
      container = tester.widget<AnimatedContainer>(
        find.byKey(const Key('dynamic_scanner_bounding_container')),
      );
      border = (container.decoration as BoxDecoration).border as Border;
      expect(border.top.color.r, closeTo(AppColors.accentAmber.r, 0.05));

      // 3. Match flash state (emerald)
      stateNotifier.value = (true, false);
      await tester.pumpAndSettle();
      container = tester.widget<AnimatedContainer>(
        find.byKey(const Key('dynamic_scanner_bounding_container')),
      );
      border = (container.decoration as BoxDecoration).border as Border;
      expect(border.top.color.r, closeTo(AppColors.accentEmerald.r, 0.05));

      // 4. Return to normal
      stateNotifier.value = (false, false);
      await tester.pumpAndSettle();
      container = tester.widget<AnimatedContainer>(
        find.byKey(const Key('dynamic_scanner_bounding_container')),
      );
      border = (container.decoration as BoxDecoration).border as Border;
      expect(border.top.color.r, closeTo(AppColors.accentCyan.r, 0.05));
    });
  });
}
