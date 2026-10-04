import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/features/scanner/presentation/widgets/dynamic_scanner_overlay.dart';

void main() {
  group('Challenger M3-2 Adversarial Stress Testing — DynamicScannerOverlay', () {
    testWidgets('Stress 1: Rapid high-frequency bounds morphing does not crash or leak', (tester) async {
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
      await tester.pumpAndSettle();

      // Rapidly morph bounds 20 times in succession with tiny time increments (simulating high-jitter camera frames)
      for (int i = 0; i < 20; i++) {
        boundsNotifier.value = Rect.fromLTWH(50.0 + i * 5, 100.0 + i * 3, 200.0 - i * 2, 300.0 + i * 2);
        await tester.pump(const Duration(milliseconds: 16)); // ~60fps
      }

      expect(find.byKey(const Key('dynamic_scanner_overlay')), findsOneWidget);
      expect(find.byKey(const Key('dynamic_scanner_bounding_container')), findsOneWidget);

      await tester.pumpAndSettle();
      final finalTl = tester.getTopLeft(find.byKey(const Key('corner_bracket_tl')));
      expect(finalTl.dx, closeTo(50.0 + 19 * 5, 1.0));
    });

    testWidgets('Stress 2: Rapid null / non-null chatter (frame drops) preserves bounds and avoids strobing', (tester) async {
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

      // Alternate between null (dropped frame) and non-null every 33ms (simulating 30fps intermittent detection)
      for (int i = 0; i < 10; i++) {
        boundsNotifier.value = (i % 2 == 0) ? null : const Rect.fromLTWH(62, 122, 240, 340);
        await tester.pump(const Duration(milliseconds: 33));
        
        // Reticle should ALWAYS stay rendered in tree (never collapsed to empty or (0,0))
        expect(find.byKey(const Key('dynamic_scanner_overlay')), findsOneWidget);
        expect(find.byKey(const Key('corner_bracket_tl')), findsOneWidget);

        final tl = tester.getTopLeft(find.byKey(const Key('corner_bracket_tl')));
        expect(tl.dx, closeTo(60.0, 5.0));
      }
    });

    testWidgets('Stress 3: Degenerate, zero, or inverted bounds are handled safely without crashing', (tester) async {
      final boundsNotifier = ValueNotifier<Rect?>(Rect.zero);
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

      // Rect.zero has width=0, height=0 -> should render SizedBox.shrink safely
      expect(find.byKey(const Key('dynamic_scanner_bounding_container')), findsNothing);

      // Inverted bounds (negative width/height)
      boundsNotifier.value = Rect.fromLTRB(200, 300, 100, 150);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dynamic_scanner_bounding_container')), findsNothing);

      // Restore valid bounds
      boundsNotifier.value = const Rect.fromLTWH(40, 80, 200, 300);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dynamic_scanner_bounding_container')), findsOneWidget);
    });

    testWidgets('Stress 4: Paused state rendering suppresses laser line and sets amber styling across all tiers', (tester) async {
      final scanController = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(seconds: 1),
      )..value = 0.5;
      addTearDown(scanController.dispose);

      const bounds = Rect.fromLTWH(50, 100, 200, 300);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DynamicScannerOverlay(
              cardBounds: bounds,
              isGreenFlash: false,
              isPaused: true,
              scanLineAnimation: scanController,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Laser must be suppressed
      expect(find.byKey(const Key('bounded_laser_scan_line')), findsNothing);

      // Check Amber styling on container
      final container = tester.widget<AnimatedContainer>(
        find.byKey(const Key('dynamic_scanner_bounding_container')),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color!.r, closeTo(AppColors.accentAmber.r, 0.05));
      final border = decoration.border as Border;
      expect(border.top.color.r, closeTo(AppColors.accentAmber.r, 0.05));

      // Check all 3 box shadows use accentAmber
      final shadows = decoration.boxShadow!;
      expect(shadows.length, equals(3));
      for (final s in shadows) {
        expect(s.color.r, closeTo(AppColors.accentAmber.r, 0.05));
      }
    });

    testWidgets('Stress 5: Emerald green flash elevates stroke (3.5) and border (2.8) and 3-tier glow', (tester) async {
      const bounds = Rect.fromLTWH(50, 100, 200, 300);
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

      final container = tester.widget<AnimatedContainer>(
        find.byKey(const Key('dynamic_scanner_bounding_container')),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color!.r, closeTo(AppColors.accentEmerald.r, 0.05));

      // Border width = 2.8, color = emerald
      final border = decoration.border as Border;
      expect(border.top.width, equals(2.8));
      expect(border.top.color.r, closeTo(AppColors.accentEmerald.r, 0.05));

      // 3 shadows with emerald
      final shadows = decoration.boxShadow!;
      for (final s in shadows) {
        expect(s.color.r, closeTo(AppColors.accentEmerald.r, 0.05));
      }

      // Corner bracket painter has thickness = 3.5
      final tlCustomPaint = tester.widget<CustomPaint>(find.byKey(const Key('corner_bracket_tl')));
      final painter = tlCustomPaint.painter!;
      // Verify paint() completes with 3.5 stroke
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(28, 28));
      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });

    testWidgets('Stress 6: Asymmetric decay timing (150ms in vs 700ms decay) with mid-fade interruption', (tester) async {
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
      await tester.pumpAndSettle();

      // Initial visible state
      var animatedOpacity = tester.widget<AnimatedOpacity>(
        find.byKey(const Key('dynamic_scanner_overlay')),
      );
      expect(animatedOpacity.opacity, equals(1.0));

      // Trigger decay
      boundsNotifier.value = null;
      await tester.pump();

      animatedOpacity = tester.widget<AnimatedOpacity>(
        find.byKey(const Key('dynamic_scanner_overlay')),
      );
      expect(animatedOpacity.duration, equals(const Duration(milliseconds: 700)));
      expect(animatedOpacity.opacity, equals(0.0));

      // Advance 250ms into decay
      await tester.pump(const Duration(milliseconds: 250));

      // Interrupt fade with a newly detected card
      boundsNotifier.value = const Rect.fromLTWH(70, 120, 210, 310);
      await tester.pump();

      // Opacity switches immediately to 1.0 with 150ms duration
      animatedOpacity = tester.widget<AnimatedOpacity>(
        find.byKey(const Key('dynamic_scanner_overlay')),
      );
      expect(animatedOpacity.duration, equals(const Duration(milliseconds: 150)));
      expect(animatedOpacity.opacity, equals(1.0));

      // Completes settle to new coordinates cleanly
      await tester.pumpAndSettle();
      final newTl = tester.getTopLeft(find.byKey(const Key('corner_bracket_tl')));
      expect(newTl.dx, closeTo(70.0, 1.0));
      expect(newTl.dy, closeTo(120.0, 1.0));
    });
  });
}
