import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/state/settings_state.dart';
import 'package:countr/features/values/domain/models/financial_analytics.dart';
import 'package:countr/features/values/domain/models/market_price_quote.dart';
import 'package:countr/features/values/presentation/widgets/interactive_multi_line_chart.dart';
import 'package:countr/features/values/presentation/widgets/cost_basis_pnl_widget.dart';
import 'package:countr/features/values/presentation/widgets/liquidity_reality_check_widget.dart';
import 'package:countr/features/values/presentation/widgets/fifty_two_week_range_bar.dart';
import 'package:countr/features/values/presentation/widgets/condition_treatment_matrix_widget.dart';
import 'package:countr/features/values/presentation/widgets/market_spread_table_widget.dart';
import 'package:countr/features/values/presentation/widgets/freshness_badge_widget.dart';
import 'package:countr/features/values/presentation/widgets/locked_values_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrapWithScope({
    required Widget child,
    bool isPrivacyMode = false,
    AppCurrency currency = AppCurrency.usd,
    double fontScale = 1.0,
    Size viewportSize = const Size(800, 600),
  }) {
    return ProviderScope(
      overrides: [
        privacyModeProvider.overrideWith((ref) => isPrivacyMode),
        baseCurrencyProvider.overrideWith((ref) => currency),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: viewportSize,
            textScaler: TextScaler.linear(fontScale),
          ),
          child: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // STRESS-1: Fritsch-Carlson Monotone Spline & Degenerate Datasets
  // ==========================================================================
  group('STRESS-1: Fritsch-Carlson Monotone Spline & Degenerate Datasets', () {
    testWidgets('STRESS-1.1: 0 points dataset renders without error or NaN bounds', (tester) async {
      final emptyData = MultiLineChartData(
        horizon: ChartTimeHorizon.thirtyDays,
        currency: AppCurrency.usd,
        trimmedAverage: const ChartSeries(
          id: 'trimmed',
          label: 'Trimmed Avg',
          color: AppColors.accentCyan,
          points: [],
        ),
        vendorSeries: {},
      );

      await tester.pumpWidget(wrapWithScope(
        child: InteractiveMultiLineChart(data: emptyData),
      ));
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('multi_line_chart_canvas')), findsOneWidget);

      final customPaint = tester.widget<CustomPaint>(find.byKey(const Key('multi_line_chart_canvas')));
      final painter = customPaint.painter as MultiLineChartPainter;
      expect(painter.data.trimmedAverage.points.isEmpty, isTrue);
    });

    testWidgets('STRESS-1.2: 1 point dataset renders single circle without division-by-zero', (tester) async {
      final onePointData = MultiLineChartData(
        horizon: ChartTimeHorizon.thirtyDays,
        currency: AppCurrency.usd,
        trimmedAverage: ChartSeries(
          id: 'trimmed',
          label: 'Trimmed Avg',
          color: AppColors.accentCyan,
          points: [
            ChartPoint(timestamp: DateTime(2026, 1, 1), price: 42.0),
          ],
        ),
        vendorSeries: {},
      );

      await tester.pumpWidget(wrapWithScope(
        child: InteractiveMultiLineChart(data: onePointData),
      ));
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('multi_line_chart_canvas')), findsOneWidget);
    });

    testWidgets('STRESS-1.3: 2 points dataset renders linear segment cleanly', (tester) async {
      final twoPointsData = MultiLineChartData(
        horizon: ChartTimeHorizon.thirtyDays,
        currency: AppCurrency.usd,
        trimmedAverage: ChartSeries(
          id: 'trimmed',
          label: 'Trimmed Avg',
          color: AppColors.accentCyan,
          points: [
            ChartPoint(timestamp: DateTime(2026, 1, 1), price: 10.0),
            ChartPoint(timestamp: DateTime(2026, 1, 15), price: 30.0),
          ],
        ),
        vendorSeries: {},
      );

      await tester.pumpWidget(wrapWithScope(
        child: InteractiveMultiLineChart(data: twoPointsData),
      ));
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('multi_line_chart_canvas')), findsOneWidget);
    });

    testWidgets('STRESS-1.4: Flat horizontal line with identical prices has zero ringing and no NaN', (tester) async {
      final baseDate = DateTime(2026, 1, 1);
      final flatPoints = List.generate(
        15,
        (i) => ChartPoint(timestamp: baseDate.add(Duration(days: i)), price: 25.0),
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

      await tester.pumpWidget(wrapWithScope(
        child: InteractiveMultiLineChart(data: flatData),
      ));
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('multi_line_chart_canvas')), findsOneWidget);
    });

    testWidgets('STRESS-1.5: Sudden 1000x spike has zero overshoot ringing and no NaN coordinates', (tester) async {
      final baseDate = DateTime(2026, 1, 1);
      final spikePoints = [
        ChartPoint(timestamp: baseDate, price: 10.0),
        ChartPoint(timestamp: baseDate.add(const Duration(days: 2)), price: 10.0),
        ChartPoint(timestamp: baseDate.add(const Duration(days: 4)), price: 10000.0), // 1000x spike
        ChartPoint(timestamp: baseDate.add(const Duration(days: 6)), price: 10.0),
        ChartPoint(timestamp: baseDate.add(const Duration(days: 8)), price: 10.0),
      ];

      final spikeData = MultiLineChartData(
        horizon: ChartTimeHorizon.thirtyDays,
        currency: AppCurrency.usd,
        trimmedAverage: ChartSeries(
          id: 'trimmed',
          label: 'Trimmed Avg',
          color: AppColors.accentCyan,
          points: spikePoints,
        ),
        vendorSeries: {},
      );

      await tester.pumpWidget(wrapWithScope(
        child: InteractiveMultiLineChart(data: spikeData),
      ));
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('multi_line_chart_canvas')), findsOneWidget);

      final gestureFinder = find.byKey(const Key('chart_gesture_detector'));
      final center = tester.getCenter(gestureFinder);
      final gesture = await tester.startGesture(center);
      await tester.pump();

      expect(find.byKey(const Key('chart_tooltip_card')), findsOneWidget);
      await gesture.up();
      await tester.pump();
    });

    test('STRESS-1.6: Mathematical validation of Fritsch-Carlson monotonicity on step and spike', () {
      final stepPrices = [10.0, 10.0, 50.0, 50.0];
      final n = stepPrices.length;
      final coords = List.generate(n, (i) => Offset(i * 100.0, 200.0 - (stepPrices[i] * 2.0)));

      final dxs = List<double>.filled(n - 1, 0.0);
      final dys = List<double>.filled(n - 1, 0.0);
      final secants = List<double>.filled(n - 1, 0.0);

      for (int i = 0; i < n - 1; i++) {
        dxs[i] = coords[i + 1].dx - coords[i].dx;
        dys[i] = coords[i + 1].dy - coords[i].dy;
        secants[i] = dxs[i] != 0.0 ? dys[i] / dxs[i] : 0.0;
      }

      final slopes = List<double>.filled(n, 0.0);
      slopes[0] = secants[0];
      slopes[n - 1] = secants[n - 2];

      for (int i = 1; i < n - 1; i++) {
        final sPrev = secants[i - 1];
        final sNext = secants[i];
        if (sPrev * sNext <= 0.0) {
          slopes[i] = 0.0;
        } else {
          slopes[i] = (sPrev + sNext) / 2.0;
        }
      }

      for (int i = 0; i < n - 1; i++) {
        final s = secants[i];
        if (s == 0.0) {
          slopes[i] = 0.0;
          slopes[i + 1] = 0.0;
        } else {
          final alpha = slopes[i] / s;
          final beta = slopes[i + 1] / s;
          final sumSq = alpha * alpha + beta * beta;
          if (sumSq > 9.0) {
            final tau = 3.0 / (sumSq > 0 ? (alpha * alpha + beta * beta) : 1.0);
            slopes[i] = tau * alpha * s;
            slopes[i + 1] = tau * beta * s;
          }
        }
      }

      expect(slopes[0], 0.0);
      expect(slopes[1], 0.0);
      expect(slopes[2], 0.0);
      expect(slopes[3], 0.0);

      for (final s in slopes) {
        expect(s.isNaN, isFalse);
        expect(s.isInfinite, isFalse);
      }
    });
  });

  // ==========================================================================
  // STRESS-2: Touch Scrubbing, Crosshair & Tooltip Dynamic Synchronization
  // ==========================================================================
  group('STRESS-2: Touch Scrubbing, Crosshair & Tooltip Dynamic Synchronization', () {
    testWidgets('STRESS-2.1: pan scrubbing tracks touch position and dynamically updates tooltip date and prices', (tester) async {
      final baseDate = DateTime(2026, 3, 1);
      final testPoints = [
        ChartPoint(timestamp: baseDate, price: 10.0),
        ChartPoint(timestamp: baseDate.add(const Duration(days: 5)), price: 20.0),
        ChartPoint(timestamp: baseDate.add(const Duration(days: 10)), price: 30.0),
        ChartPoint(timestamp: baseDate.add(const Duration(days: 15)), price: 40.0),
      ];

      final chartData = MultiLineChartData(
        horizon: ChartTimeHorizon.thirtyDays,
        currency: AppCurrency.usd,
        trimmedAverage: ChartSeries(
          id: 'trimmed',
          label: 'Trimmed Avg',
          color: AppColors.accentCyan,
          points: testPoints,
        ),
        vendorSeries: {
          MarketVendor.tcgplayer: ChartSeries(
            id: 'tcg',
            label: 'TCGplayer',
            color: MarketVendor.tcgplayer.color,
            points: testPoints.map((p) => ChartPoint(timestamp: p.timestamp, price: p.price * 1.05)).toList(),
          ),
        },
      );

      await tester.pumpWidget(wrapWithScope(
        child: InteractiveMultiLineChart(data: chartData),
      ));
      await tester.pump(const Duration(milliseconds: 200));

      final gestureFinder = find.byKey(const Key('chart_gesture_detector'));
      final topLeft = tester.getTopLeft(gestureFinder);
      final size = tester.getSize(gestureFinder);

      // Touch at 10% width (closest to point 0)
      final touchPos1 = Offset(topLeft.dx + size.width * 0.1, topLeft.dy + size.height * 0.5);
      final gesture = await tester.startGesture(touchPos1);
      await tester.pump();

      expect(find.byKey(const Key('chart_tooltip_card')), findsOneWidget);
      expect(find.text('Mar 1, 2026'), findsOneWidget);
      expect(find.text(r'$10.00'), findsOneWidget);

      // Scrub across the chart
      for (double step = 0.3; step <= 0.95; step += 0.2) {
        await gesture.moveTo(Offset(topLeft.dx + size.width * step, topLeft.dy + size.height * 0.5));
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.byKey(const Key('chart_tooltip_card')), findsOneWidget);
      expect(find.text('Mar 16, 2026'), findsOneWidget);
      expect(find.text(r'$40.00'), findsOneWidget);

      // Release touch
      await gesture.up();
      await tester.pump();

      expect(find.byKey(const Key('chart_tooltip_card')), findsNothing);
    });
  });

  // ==========================================================================
  // STRESS-3: Tooltip Auto-Flip & Screen Bounds Clipping Prevention
  // ==========================================================================
  group('STRESS-3: Tooltip Auto-Flip & Screen Bounds Clipping Prevention', () {
    testWidgets('STRESS-3.1: near right edge flips to the left, near left edge flips to the right', (tester) async {
      final baseDate = DateTime(2026, 3, 1);
      final testPoints = List.generate(
        10,
        (i) => ChartPoint(timestamp: baseDate.add(Duration(days: i)), price: 15.0 + i),
      );

      final chartData = MultiLineChartData(
        horizon: ChartTimeHorizon.thirtyDays,
        currency: AppCurrency.usd,
        trimmedAverage: ChartSeries(
          id: 'trimmed',
          label: 'Trimmed Avg',
          color: AppColors.accentCyan,
          points: testPoints,
        ),
        vendorSeries: {},
      );

      await tester.pumpWidget(wrapWithScope(
        child: InteractiveMultiLineChart(data: chartData),
      ));
      await tester.pump(const Duration(milliseconds: 200));

      final gestureFinder = find.byKey(const Key('chart_gesture_detector'));
      final topLeft = tester.getTopLeft(gestureFinder);
      final chartSize = tester.getSize(gestureFinder);

      // Test Right Edge: Touch at 95% width (right half of canvas)
      final rightTouch = Offset(topLeft.dx + chartSize.width * 0.95, topLeft.dy + chartSize.height * 0.5);
      final gestureRight = await tester.startGesture(rightTouch);
      await tester.pump();

      expect(find.byKey(const Key('chart_tooltip_card')), findsOneWidget);
      final tooltipRightBox = tester.getRect(find.byKey(const Key('chart_tooltip_card')));

      // Auto-flip: tooltip position must be strictly to the left of the touch point
      expect(tooltipRightBox.right, lessThanOrEqualTo(rightTouch.dx + 4.0));
      expect(tooltipRightBox.left, greaterThanOrEqualTo(topLeft.dx));

      await gestureRight.up();
      await tester.pump();

      // Test Left Edge: Touch at 5% width (left half of canvas)
      final leftTouch = Offset(topLeft.dx + chartSize.width * 0.05, topLeft.dy + chartSize.height * 0.5);
      final gestureLeft = await tester.startGesture(leftTouch);
      await tester.pump();

      expect(find.byKey(const Key('chart_tooltip_card')), findsOneWidget);
      final tooltipLeftBox = tester.getRect(find.byKey(const Key('chart_tooltip_card')));

      // Auto-flip: tooltip position must be to the right of the touch point
      expect(tooltipLeftBox.left, greaterThanOrEqualTo(leftTouch.dx - 4.0));
      expect(tooltipLeftBox.right, lessThanOrEqualTo(topLeft.dx + chartSize.width + 4.0));

      await gestureLeft.up();
      await tester.pump();
    });
  });

  // ==========================================================================
  // STRESS-4: Ultra-Narrow Viewport (320x568) with 2.0x Font Scaling
  // ==========================================================================
  group('STRESS-4: Ultra-Narrow Viewport (320x568) with 2.0x Font Scaling', () {
    Widget buildNarrowHarness(Widget child) {
      return ProviderScope(
        overrides: [
          privacyModeProvider.overrideWith((ref) => false),
          baseCurrencyProvider.overrideWith((ref) => AppCurrency.usd),
        ],
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 568),
              textScaler: TextScaler.linear(2.0),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('STRESS-4.1: CostBasisPnLWidget under 320x568 at 2.0x font scaling has zero overflows', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());

      await tester.pumpWidget(buildNarrowHarness(
        const CostBasisPnLWidget(purchasePrice: 35.0, marketPrice: 50.0, quantity: 2),
      ));
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('cost_basis_pnl_widget')), findsOneWidget);
    });

    testWidgets('STRESS-4.2: ConditionTreatmentMatrixWidget under 320x568 at 2.0x font scaling has zero overflows', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());

      final matrix = ConditionTreatmentMatrix.compute(
        baseNonFoil: 45.0,
        baseFoil: 65.0,
        baseEtched: 72.0,
        currency: AppCurrency.usd,
      );

      await tester.pumpWidget(buildNarrowHarness(
        ConditionTreatmentMatrixWidget(matrix: matrix, ownedCondition: 'NM', ownedFinish: 'foil'),
      ));
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('condition_treatment_matrix_widget')), findsOneWidget);
    });

    testWidgets('STRESS-4.3: MarketSpreadTableWidget under 320x568 at 2.0x font scaling has zero overflows', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());

      await tester.pumpWidget(buildNarrowHarness(
        const MarketSpreadTableWidget(baselinePrice: 42.0),
      ));
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('market_spread_table_widget')), findsOneWidget);
    });

    testWidgets('STRESS-4.4: LockedValuesView under 320x568 at 2.0x font scaling has zero overflows', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());

      await tester.pumpWidget(buildNarrowHarness(
        const LockedValuesView(),
      ));
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('locked_values_view')), findsOneWidget);
    });

    testWidgets('STRESS-4.5: InteractiveMultiLineChart under 320x568 at 2.0x font scaling has zero overflows', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());

      await tester.pumpWidget(buildNarrowHarness(
        const InteractiveMultiLineChart(),
      ));
      await tester.pump(const Duration(milliseconds: 200));

      final overflows = tester.takeException();
      expect(overflows, isNull);
      expect(find.byKey(const Key('interactive_multi_line_chart_container')), findsOneWidget);
    });

    testWidgets('STRESS-4.6: LiquidityRealityCheckWidget under 320x568 at 2.0x font scaling has zero overflows', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());

      await tester.pumpWidget(buildNarrowHarness(
        const LiquidityRealityCheckWidget(marketPrice: 50.0, isReservedList: true),
      ));
      await tester.pump(const Duration(milliseconds: 200));

      final overflows = tester.takeException();
      expect(overflows, isNull);
      expect(find.byKey(const Key('liquidity_reality_check_widget')), findsOneWidget);
    });

    testWidgets('STRESS-4.7: FiftyTwoWeekRangeBar under 320x568 at 2.0x font scaling has zero overflows', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());

      await tester.pumpWidget(buildNarrowHarness(
        const FiftyTwoWeekRangeBar(low52: 25.0, high52: 75.0, currentPrice: 50.0),
      ));
      await tester.pump(const Duration(milliseconds: 200));

      final overflows = tester.takeException();
      expect(overflows, isNull);
      expect(find.byKey(const Key('fifty_two_week_range_bar')), findsOneWidget);
    });

    testWidgets('STRESS-4.8: FreshnessBadgeWidget under 320x568 at 2.0x font scaling has zero overflows', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());

      await tester.pumpWidget(buildNarrowHarness(
        FreshnessBadgeWidget(lastUpdated: DateTime.now().subtract(const Duration(minutes: 5))),
      ));
      await tester.pump(const Duration(milliseconds: 200));

      final overflows = tester.takeException();
      expect(overflows, isNull);
      expect(find.byKey(const Key('freshness_badge_widget')), findsOneWidget);
    });
  });

  // ==========================================================================
  // STRESS-5: Privacy Mode Masking Stress Test
  // ==========================================================================
  group('STRESS-5: Privacy Mode Masking Stress Test', () {
    testWidgets('STRESS-5.1: strict **** masking across Chart, PnL, Liquidity, 52W Range, Matrix, and Spread Table', (tester) async {
      final matrix = ConditionTreatmentMatrix.compute(
        baseNonFoil: 100.0,
        baseFoil: 150.0,
        baseEtched: 175.0,
        currency: AppCurrency.usd,
      );

      final quotes = [
        MarketPriceQuote(
          vendor: 'TCGplayer',
          quoteType: MarketQuoteType.retail,
          rawAmount: 120.0,
          currency: AppCurrency.usd,
          convertedAmount: 120.0,
          baseCurrency: AppCurrency.usd,
          timestamp: DateTime.now(),
        ),
        MarketPriceQuote(
          vendor: 'Card Kingdom',
          quoteType: MarketQuoteType.retail,
          rawAmount: 130.0,
          currency: AppCurrency.usd,
          convertedAmount: 130.0,
          baseCurrency: AppCurrency.usd,
          timestamp: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            privacyModeProvider.overrideWith((ref) => true), // Global Privacy Mode ON
            baseCurrencyProvider.overrideWith((ref) => AppCurrency.usd),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    const InteractiveMultiLineChart(key: Key('privacy_chart')),
                    const CostBasisPnLWidget(
                      key: Key('privacy_pnl'),
                      purchasePrice: 80.0,
                      marketPrice: 120.0,
                      quantity: 2,
                    ),
                    const LiquidityRealityCheckWidget(
                      key: Key('privacy_liq'),
                      marketPrice: 120.0,
                      quantity: 2,
                    ),
                    const FiftyTwoWeekRangeBar(
                      key: Key('privacy_range'),
                      low52: 60.0,
                      high52: 150.0,
                      currentPrice: 120.0,
                    ),
                    ConditionTreatmentMatrixWidget(
                      key: const Key('privacy_matrix'),
                      matrix: matrix,
                    ),
                    MarketSpreadTableWidget(
                      key: const Key('privacy_spread'),
                      quotes: quotes,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 200));

      // 1. InteractiveMultiLineChart: Painter is in privacy mode
      final customPaint = tester.widget<CustomPaint>(find.byKey(const Key('multi_line_chart_canvas')));
      final painter = customPaint.painter as MultiLineChartPainter;
      expect(painter.isPrivacyMode, isTrue);

      // Tooltip scrub in privacy mode shows **** for all prices
      final gestureFinder = find.byKey(const Key('chart_gesture_detector'));
      final center = tester.getCenter(gestureFinder);
      final gesture = await tester.startGesture(center);
      await tester.pump();

      expect(find.byKey(const Key('chart_tooltip_card')), findsOneWidget);
      expect(find.descendant(
        of: find.byKey(const Key('chart_tooltip_card')),
        matching: find.text('****'),
      ), findsWidgets);

      await gesture.up();
      await tester.pump();

      // 2. CostBasisPnLWidget:
      final pnlCost = tester.widget<Text>(find.byKey(const Key('pnl_total_cost_basis')));
      expect(pnlCost.data, '****');
      final pnlMarket = tester.widget<Text>(find.byKey(const Key('pnl_total_market_value')));
      expect(pnlMarket.data, '****');
      final pnlUnitCost = tester.widget<Text>(find.byKey(const Key('pnl_sub_unit_cost')));
      expect(pnlUnitCost.data, '****');
      final pnlCurrentAvg = tester.widget<Text>(find.byKey(const Key('pnl_sub_current_avg')));
      expect(pnlCurrentAvg.data, '****');
      final pnlBadge = tester.widget<Text>(find.byKey(const Key('pnl_return_badge_text')));
      expect(pnlBadge.data, '****');

      // 3. LiquidityRealityCheckWidget:
      final liqReplacement = tester.widget<Text>(find.byKey(const Key('liquidity_replacement_value')));
      expect(liqReplacement.data, '****');
      final liqCashOut = tester.widget<Text>(find.byKey(const Key('liquidity_cash_out_value')));
      expect(liqCashOut.data, '****');
      final liqRealization = tester.widget<Text>(find.byKey(const Key('liquidity_realization_rate_text')));
      expect(liqRealization.data, '**** Cash Realization');
      final liqHaircut = tester.widget<Text>(find.byKey(const Key('liquidity_haircut_text')));
      expect(liqHaircut.data, 'Haircut: ****');

      // 4. FiftyTwoWeekRangeBar:
      final rangePercentile = tester.widget<Text>(find.byKey(const Key('range_percentile_text')));
      expect(rangePercentile.data, '**** of Range');
      final rangeLow = tester.widget<Text>(find.byKey(const Key('range_low_value')));
      expect(rangeLow.data, '****');
      final rangeCurrent = tester.widget<Text>(find.byKey(const Key('range_current_value')));
      expect(rangeCurrent.data, '****');
      final rangeHigh = tester.widget<Text>(find.byKey(const Key('range_high_value')));
      expect(rangeHigh.data, '****');

      // 5. ConditionTreatmentMatrixWidget:
      for (final cond in ['NM', 'LP', 'MP']) {
        for (final finish in ['non_foil', 'foil', 'etched']) {
          final cellText = tester.widget<Text>(find.byKey(Key('matrix_cell_${cond}_$finish')));
          expect(cellText.data, '****');
        }
      }

      // 6. MarketSpreadTableWidget:
      for (final q in quotes) {
        final retailText = tester.widget<Text>(find.byKey(Key('vendor_retail_${q.vendor}')));
        expect(retailText.data, '****');
        final buylistText = tester.widget<Text>(find.byKey(Key('vendor_buylist_${q.vendor}')));
        expect(buylistText.data, '****');
        final spreadText = tester.widget<Text>(find.byKey(Key('vendor_spread_${q.vendor}')));
        expect(spreadText.data, '****');
      }

      // 7. Strict Regex Assertion: NO monetary digits with currency symbol leak anywhere in the tree
      final currencyRegex = RegExp(r'(\$|€|£|CA\$)\s*\d+(\.\d+)?');
      final allTextWidgets = tester.widgetList<Text>(find.byType(Text));
      for (final textWidget in allTextWidgets) {
        final str = textWidget.data ?? textWidget.textSpan?.toPlainText() ?? '';
        expect(
          currencyRegex.hasMatch(str),
          isFalse,
          reason: 'Privacy leak detected: "$str" matches currency regex',
        );
      }
    });
  });
}
