import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/features/scanner/presentation/widgets/dynamic_scanner_overlay.dart';

void main() {
  group('DynamicScannerOverlay — ManaBox Holographic Neon Aesthetic', () {
    testWidgets('renders 3-tier box shadow glow and luminous interior in tracking state', (tester) async {
      const bounds = Rect.fromLTWH(40, 80, 260, 360);
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

      final containerFinder = find.byKey(const Key('dynamic_scanner_bounding_container'));
      expect(containerFinder, findsOneWidget);

      final container = tester.widget<AnimatedContainer>(containerFinder);
      final decoration = container.decoration as BoxDecoration;

      // 1. Interior luminous tint (0.03 cyan)
      expect(decoration.color, isNotNull);
      final interiorColor = decoration.color!;
      expect(interiorColor.r, closeTo(AppColors.accentCyan.r, 0.05));
      expect(interiorColor.a, closeTo(0.03, 0.015));

      // 2. Border styling (accentCyan, width 1.6, radius 12)
      expect(decoration.borderRadius, equals(BorderRadius.circular(12)));
      final border = decoration.border as Border;
      expect(border.top.color.r, closeTo(AppColors.accentCyan.r, 0.05));
      expect(border.top.color.a, closeTo(0.70, 0.05));
      expect(border.top.width, equals(1.6));

      // 3. Three-tier holographic neon box shadow glow
      expect(decoration.boxShadow, isNotNull);
      final shadows = decoration.boxShadow!;
      expect(shadows.length, equals(3));

      // Tier 1: Core sharp neon intensity (blur: 10, spread: 1.5, alpha: 0.50)
      expect(shadows[0].blurRadius, equals(10.0));
      expect(shadows[0].spreadRadius, equals(1.5));
      expect(shadows[0].color.a, closeTo(0.50, 0.05));

      // Tier 2: Mid-range holographic halo (blur: 22, spread: 2.5, alpha: 0.28)
      expect(shadows[1].blurRadius, equals(22.0));
      expect(shadows[1].spreadRadius, equals(2.5));
      expect(shadows[1].color.a, closeTo(0.28, 0.05));

      // Tier 3: Atmospheric dispersion glow (blur: 36, spread: 3.0, alpha: 0.12)
      expect(shadows[2].blurRadius, equals(36.0));
      expect(shadows[2].spreadRadius, equals(3.0));
      expect(shadows[2].color.a, closeTo(0.12, 0.05));
    });

    testWidgets('renders elevated green flash 3-tier glow on match confirmation', (tester) async {
      const bounds = Rect.fromLTWH(40, 80, 260, 360);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DynamicScannerOverlay(
              cardBounds: bounds,
              isGreenFlash: true,
              isPaused: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final containerFinder = find.byKey(const Key('dynamic_scanner_bounding_container'));
      expect(containerFinder, findsOneWidget);

      final container = tester.widget<AnimatedContainer>(containerFinder);
      final decoration = container.decoration as BoxDecoration;

      // 1. Interior luminous tint elevated to 0.08 emerald
      expect(decoration.color, isNotNull);
      final interiorColor = decoration.color!;
      expect(interiorColor.r, closeTo(AppColors.accentEmerald.r, 0.05));
      expect(interiorColor.a, closeTo(0.08, 0.02));

      // 2. Border styling (accentEmerald, width 2.8, alpha 0.95)
      final border = decoration.border as Border;
      expect(border.top.color.r, closeTo(AppColors.accentEmerald.r, 0.05));
      expect(border.top.color.a, closeTo(0.95, 0.05));
      expect(border.top.width, equals(2.8));

      // 3. Elevated 3-tier box shadow glow
      final shadows = decoration.boxShadow!;
      expect(shadows.length, equals(3));

      // Tier 1 on green flash (blur: 12, spread: 2.0, alpha: 0.85)
      expect(shadows[0].blurRadius, equals(12.0));
      expect(shadows[0].spreadRadius, equals(2.0));
      expect(shadows[0].color.a, closeTo(0.85, 0.05));

      // Tier 2 on green flash (blur: 26, spread: 3.0, alpha: 0.60)
      expect(shadows[1].blurRadius, equals(26.0));
      expect(shadows[1].spreadRadius, equals(3.0));
      expect(shadows[1].color.a, closeTo(0.60, 0.05));

      // Tier 3 on green flash (blur: 48, spread: 5.0, alpha: 0.40)
      expect(shadows[2].blurRadius, equals(48.0));
      expect(shadows[2].spreadRadius, equals(5.0));
      expect(shadows[2].color.a, closeTo(0.40, 0.05));
    });

    testWidgets('switches to accentAmber battery-saver state when isPaused is true', (tester) async {
      const bounds = Rect.fromLTWH(50, 100, 200, 300);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DynamicScannerOverlay(
              cardBounds: bounds,
              isGreenFlash: false,
              isPaused: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final container = tester.widget<AnimatedContainer>(
        find.byKey(const Key('dynamic_scanner_bounding_container')),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color!.r, closeTo(AppColors.accentAmber.r, 0.05));
      final border = decoration.border as Border;
      expect(border.top.color.r, closeTo(AppColors.accentAmber.r, 0.05));
    });
  });

  group('DynamicScannerOverlay — Smooth Snapping & Decay Retention', () {
    testWidgets('smoothly morphs active bounds with TweenAnimationBuilder over 180ms', (tester) async {
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
      await tester.pumpAndSettle();

      // Check initial position of top-left corner
      final initialTl = tester.getTopLeft(find.byKey(const Key('corner_bracket_tl')));
      expect(initialTl.dx, closeTo(50.0, 1.0));
      expect(initialTl.dy, closeTo(80.0, 1.0));

      // Shift bounds significantly
      boundsNotifier.value = const Rect.fromLTWH(150, 180, 280, 400);
      await tester.pump(); // Start animation

      // At 90ms (halfway through 180ms cubic ease), position should be interpolated
      await tester.pump(const Duration(milliseconds: 90));
      final midTl = tester.getTopLeft(find.byKey(const Key('corner_bracket_tl')));
      expect(midTl.dx, greaterThan(50.0));
      expect(midTl.dx, lessThan(150.0));
      expect(midTl.dy, greaterThan(80.0));
      expect(midTl.dy, lessThan(180.0));

      // At 180ms+, position reaches destination
      await tester.pump(const Duration(milliseconds: 100));
      final finalTl = tester.getTopLeft(find.byKey(const Key('corner_bracket_tl')));
      expect(finalTl.dx, closeTo(150.0, 1.0));
      expect(finalTl.dy, closeTo(180.0, 1.0));
    });

    testWidgets('retains _lastNonNullBounds while opacity decays instead of collapsing to (0,0)', (tester) async {
      final boundsNotifier = ValueNotifier<Rect?>(const Rect.fromLTWH(60, 120, 240, 340));
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

      // Drop card bounds (frame loss or occlusion)
      boundsNotifier.value = null;
      await tester.pump(); // Trigger update

      // 200ms into the 700ms decay window:
      await tester.pump(const Duration(milliseconds: 200));

      // Overlay is still present and decaying in opacity
      final animatedOpacity = tester.widget<AnimatedOpacity>(
        find.byKey(const Key('dynamic_scanner_overlay')),
      );
      expect(animatedOpacity.opacity, equals(0.0)); // target opacity is 0.0

      // The corner bracket remains anchored to the last non-null bounds!
      final tl = tester.getTopLeft(find.byKey(const Key('corner_bracket_tl')));
      expect(tl.dx, closeTo(60.0, 1.0));
      expect(tl.dy, closeTo(120.0, 1.0));
    });

    testWidgets('handles initial null cardBounds gracefully with empty placeholder', (tester) async {
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
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('dynamic_scanner_overlay_empty')), findsOneWidget);
      expect(find.byKey(const Key('dynamic_scanner_overlay')), findsNothing);
    });
  });

  group('DynamicScannerOverlay — Asymmetric Opacity Cadence (150ms In / 700ms Decay)', () {
    testWidgets('configures AnimatedOpacity duration to 150ms on appearance and 700ms on decay', (tester) async {
      final boundsNotifier = ValueNotifier<Rect?>(const Rect.fromLTWH(50, 100, 200, 300));
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

      // When visible: duration must be 150ms
      var animatedOpacity = tester.widget<AnimatedOpacity>(
        find.byKey(const Key('dynamic_scanner_overlay')),
      );
      expect(animatedOpacity.duration, equals(const Duration(milliseconds: 150)));
      expect(animatedOpacity.opacity, equals(1.0));

      // Now set bounds to null
      boundsNotifier.value = null;
      await tester.pump();

      // When fading out: duration must be 700ms
      animatedOpacity = tester.widget<AnimatedOpacity>(
        find.byKey(const Key('dynamic_scanner_overlay')),
      );
      expect(animatedOpacity.duration, equals(const Duration(milliseconds: 700)));
      expect(animatedOpacity.opacity, equals(0.0));
    });
  });

  group('DynamicScannerOverlay — Corner Brackets & Curvature', () {
    testWidgets('renders all 4 corner brackets hugging the bounding container with round caps', (tester) async {
      const bounds = Rect.fromLTWH(50, 100, 300, 420);
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
      final trFinder = find.byKey(const Key('corner_bracket_tr'));
      final blFinder = find.byKey(const Key('corner_bracket_bl'));
      final brFinder = find.byKey(const Key('corner_bracket_br'));

      expect(tlFinder, findsOneWidget);
      expect(trFinder, findsOneWidget);
      expect(blFinder, findsOneWidget);
      expect(brFinder, findsOneWidget);

      // Verify custom painter is instantiated with cornerRadius: 10.0
      final tlCustomPaint = tester.widget<CustomPaint>(tlFinder);
      expect(tlCustomPaint.painter, isNotNull);

      // Check corner bracket sizes (clamped to 28 for large cards)
      final tlSize = tester.getSize(tlFinder);
      expect(tlSize.width, equals(28.0));
      expect(tlSize.height, equals(28.0));
    });

    testWidgets('paints all 4 corner geometries without clipping or errors', (tester) async {
      const bounds = Rect.fromLTWH(40, 60, 240, 340);
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

      // Trigger painting of all widgets onto the canvas
      final customPaints = tester.widgetList<CustomPaint>(find.byType(CustomPaint));
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      for (final cp in customPaints) {
        if (cp.painter != null) {
          cp.painter!.paint(canvas, const Size(28, 28));
        }
      }

      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });

    testWidgets('increases corner stroke thickness on match flash (3.0 -> 3.5)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DynamicScannerOverlay(
              cardBounds: Rect.fromLTWH(50, 100, 200, 300),
              isGreenFlash: true,
              isPaused: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tlFinder = find.byKey(const Key('corner_bracket_tl'));
      expect(tlFinder, findsOneWidget);
    });
  });

  group('DynamicScannerOverlay — Bounded Sweeping Laser', () {
    testWidgets('sweeps laser scan line within dynamic card bounds', (tester) async {
      final controller = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(seconds: 1),
      )..value = 0.5;
      addTearDown(controller.dispose);

      const bounds = Rect.fromLTWH(50, 100, 240, 360);
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

      final laserFinder = find.byKey(const Key('bounded_laser_scan_line'));
      expect(laserFinder, findsOneWidget);

      final laserRect = tester.getRect(laserFinder);
      // Laser horizontal position should be bounded inside the card bounds (left + 4, width - 8)
      expect(laserRect.left, equals(bounds.left + 4.0));
      expect(laserRect.width, equals(bounds.width - 8.0));

      // At value 0.5, laser Y should be in the vertical middle of the card
      final expectedY = bounds.top + (bounds.height * 0.5) - 1.25;
      expect(laserRect.top, closeTo(expectedY, 1.0));
    });

    testWidgets('hides laser scan line when isPaused is true to conserve energy', (tester) async {
      final controller = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(seconds: 1),
      )..value = 0.5;
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DynamicScannerOverlay(
              cardBounds: const Rect.fromLTWH(50, 100, 240, 360),
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
}
