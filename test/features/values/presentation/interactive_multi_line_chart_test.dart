import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/state/settings_state.dart';
import 'package:countr/features/values/presentation/widgets/interactive_multi_line_chart.dart';

void main() {
  group('InteractiveMultiLineChart Widget Tests', () {
    Widget buildTestWidget({
      MultiLineChartData? data,
      bool isPrivacyMode = false,
      AppCurrency currency = AppCurrency.usd,
    }) {
      return ProviderScope(
        overrides: [
          privacyModeProvider.overrideWith((ref) => isPrivacyMode),
          baseCurrencyProvider.overrideWith((ref) => currency),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: InteractiveMultiLineChart(
                  data: data,
                  isPrivacyMode: isPrivacyMode,
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('TC-CHART-01: renders chart container, canvas, 5 horizons, and all vendor chips', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('interactive_multi_line_chart_container')), findsOneWidget);
      expect(find.byKey(const Key('multi_line_chart_canvas')), findsOneWidget);

      // Verify all 5 time horizons
      for (final h in ['7D', '30D', '90D', '1Y', 'ALL']) {
        expect(find.byKey(Key('chart_horizon_$h')), findsOneWidget);
      }

      // Verify pinned trimmed average and 5 vendor chips
      expect(find.text('Trimmed Avg'), findsWidgets);
      expect(find.byKey(const Key('vendor_toggle_tcgplayer')), findsOneWidget);
      expect(find.byKey(const Key('vendor_toggle_cardmarket')), findsOneWidget);
      expect(find.byKey(const Key('vendor_toggle_ebay')), findsOneWidget);
      expect(find.byKey(const Key('vendor_toggle_card_kingdom')), findsOneWidget);
      expect(find.byKey(const Key('vendor_toggle_manapool')), findsOneWidget);
    });

    testWidgets('TC-CHART-02: toggling time horizons updates selected state', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Tap 90D
      await tester.tap(find.byKey(const Key('chart_horizon_90D')));
      await tester.pumpAndSettle();
      expect(find.text('90 Days'), findsOneWidget);

      // Tap 1Y
      await tester.tap(find.byKey(const Key('chart_horizon_1Y')));
      await tester.pumpAndSettle();
      expect(find.text('1 Year'), findsOneWidget);

      // Tap ALL
      await tester.tap(find.byKey(const Key('chart_horizon_ALL')));
      await tester.pumpAndSettle();
      expect(find.text('All Time'), findsOneWidget);
    });

    testWidgets('TC-CHART-03: toggling vendor chips updates active series in painter', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final customPaintFinder = find.byKey(const Key('multi_line_chart_canvas'));
      CustomPaint customPaint = tester.widget(customPaintFinder);
      MultiLineChartPainter painter = customPaint.painter as MultiLineChartPainter;
      expect(painter.activeVendors.contains(MarketVendor.tcgplayer), isTrue);

      // Tap TCGplayer chip to toggle off
      await tester.tap(find.byKey(const Key('vendor_toggle_tcgplayer')));
      await tester.pumpAndSettle();

      customPaint = tester.widget(customPaintFinder);
      painter = customPaint.painter as MultiLineChartPainter;
      expect(painter.activeVendors.contains(MarketVendor.tcgplayer), isFalse);

      // Tap again to toggle back on
      await tester.tap(find.byKey(const Key('vendor_toggle_tcgplayer')));
      await tester.pumpAndSettle();

      customPaint = tester.widget(customPaintFinder);
      painter = customPaint.painter as MultiLineChartPainter;
      expect(painter.activeVendors.contains(MarketVendor.tcgplayer), isTrue);
    });

    testWidgets('TC-CHART-04 & 05: scrub gesture reveals crosshair and glassmorphic tooltip card', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('chart_tooltip_card')), findsNothing);

      final gestureFinder = find.byKey(const Key('chart_gesture_detector'));
      final center = tester.getCenter(gestureFinder);

      // Simulate pan down
      final gesture = await tester.startGesture(center);
      await tester.pump();

      expect(find.byKey(const Key('chart_tooltip_card')), findsOneWidget);

      // Move pan
      await gesture.moveTo(Offset(center.dx + 40, center.dy));
      await tester.pump();
      expect(find.byKey(const Key('chart_tooltip_card')), findsOneWidget);

      // Release pan
      await gesture.up();
      await tester.pump();
      expect(find.byKey(const Key('chart_tooltip_card')), findsNothing);
    });

    testWidgets('TC-CHART-07: renders with zero overflows on narrow 320px viewport', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('interactive_multi_line_chart_container')), findsOneWidget);
    });

    testWidgets('TC-CHART-08: masks prices to **** when privacy mode is active', (tester) async {
      await tester.pumpWidget(buildTestWidget(isPrivacyMode: true));
      await tester.pumpAndSettle();

      // Tooltip scrubbing should show ****
      final gestureFinder = find.byKey(const Key('chart_gesture_detector'));
      final center = tester.getCenter(gestureFinder);

      final gesture = await tester.startGesture(center);
      await tester.pump();

      expect(find.byKey(const Key('chart_tooltip_card')), findsOneWidget);
      expect(find.text('****'), findsWidgets);

      await gesture.up();
      await tester.pump();
    });

    testWidgets('TC-CHART-09: handles flat pricing gracefully without division-by-zero crash', (tester) async {
      final now = DateTime.now();
      final flatPoints = List.generate(
        10,
        (i) => ChartPoint(timestamp: now.subtract(Duration(days: 10 - i)), price: 20.0),
      );

      final flatData = MultiLineChartData(
        horizon: ChartTimeHorizon.thirtyDays,
        currency: AppCurrency.usd,
        trimmedAverage: ChartSeries(
          id: 'trimmed',
          label: 'Trimmed Avg',
          color: AppColors.accentCyan,
          points: flatPoints,
        ),
        vendorSeries: {},
      );

      await tester.pumpWidget(buildTestWidget(data: flatData));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('multi_line_chart_canvas')), findsOneWidget);
    });
  });
}
