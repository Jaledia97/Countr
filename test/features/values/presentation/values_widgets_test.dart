import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/state/settings_state.dart';
import 'package:countr/features/values/domain/models/financial_analytics.dart';
import 'package:countr/features/values/domain/models/market_price_quote.dart';
import 'package:countr/features/values/presentation/widgets/cost_basis_pnl_widget.dart';
import 'package:countr/features/values/presentation/widgets/liquidity_reality_check_widget.dart';
import 'package:countr/features/values/presentation/widgets/fifty_two_week_range_bar.dart';
import 'package:countr/features/values/presentation/widgets/condition_treatment_matrix_widget.dart';
import 'package:countr/features/values/presentation/widgets/market_spread_table_widget.dart';
import 'package:countr/features/values/presentation/widgets/freshness_badge_widget.dart';

void main() {
  Widget wrapWithTheme(
    Widget child, {
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
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  group('CostBasisPnLWidget Tests', () {
    testWidgets('TC-PNL-01: renders profit state with emerald styling and positive returns', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const CostBasisPnLWidget(
            purchasePrice: 50.0,
            marketPrice: 75.0,
            quantity: 2,
            currency: AppCurrency.usd,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cost_basis_pnl_widget')), findsOneWidget);
      expect(find.byKey(const Key('pnl_return_badge')), findsOneWidget);
      expect(find.text(r'+$50.00 (+50.0%)'), findsOneWidget);
      expect(find.text(r'$100.00'), findsOneWidget); // Total cost basis (2 * 50)
      expect(find.text(r'$150.00'), findsOneWidget); // Total market value (2 * 75)
    });

    testWidgets('TC-PNL-02: renders loss state with rose styling and negative returns', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const CostBasisPnLWidget(
            purchasePrice: 100.0,
            marketPrice: 60.0,
            quantity: 1,
            currency: AppCurrency.usd,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cost_basis_pnl_widget')), findsOneWidget);
      expect(find.text(r'-$40.00 (-40.0%)'), findsOneWidget);
      expect(find.text(r'$100.00'), findsWidgets);
      expect(find.text(r'$60.00'), findsWidgets);
    });

    testWidgets('TC-PNL-03: handles zero cost basis gracefully without NaN or infinity', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const CostBasisPnLWidget(
            purchasePrice: 0.0,
            marketPrice: 25.0,
            quantity: 1,
            currency: AppCurrency.usd,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cost_basis_pnl_widget')), findsOneWidget);
      expect(find.text(r'+$25.00 (+0.0%)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('TC-PNL-04: masks financial values when privacy mode is active', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const CostBasisPnLWidget(
            purchasePrice: 50.0,
            marketPrice: 75.0,
            quantity: 2,
            isPrivacyMode: true,
          ),
          isPrivacyMode: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('****'), findsWidgets);
      // Raw currency amounts should not appear
      expect(find.text(r'$100.00'), findsNothing);
      expect(find.text(r'$150.00'), findsNothing);
    });

    testWidgets('TC-PNL-05: renders with zero overflows on narrow 320px viewport', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        wrapWithTheme(
          const CostBasisPnLWidget(
            purchasePrice: 125.50,
            marketPrice: 234.75,
            quantity: 4,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('cost_basis_pnl_widget')), findsOneWidget);
    });
  });

  group('LiquidityRealityCheckWidget Tests', () {
    testWidgets('TC-LIQ-01: renders replacement value, cash out value, and High liquidity tag', (tester) async {
      final analysis = LiquidityAnalysis.calculate(
        marketPrice: 100.0,
        quantity: 1,
        currency: AppCurrency.usd,
        explicitBuylistPrice: 70.0,
      );

      await tester.pumpWidget(
        wrapWithTheme(
          LiquidityRealityCheckWidget.fromAnalysis(analysis),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('liquidity_reality_check_widget')), findsOneWidget);
      expect(find.text('HIGH LIQUIDITY'), findsOneWidget);
      expect(find.text('70% Cash Realization'), findsOneWidget); // Realization rate
      expect(find.text(r'$100.00'), findsOneWidget); // Replacement value
      expect(find.text(r'$70.00'), findsOneWidget); // Cash out value
      expect(find.byKey(const Key('reserved_list_warning_badge')), findsNothing);
    });

    testWidgets('TC-LIQ-02: renders Moderate and Low liquidity tags correctly', (tester) async {
      // Moderate (marketPrice: 3.50 -> between 2.0 and 5.0)
      final moderate = LiquidityAnalysis.calculate(
        marketPrice: 3.50,
        quantity: 1,
        currency: AppCurrency.usd,
        explicitBuylistPrice: 2.00,
      );

      await tester.pumpWidget(
        wrapWithTheme(
          LiquidityRealityCheckWidget.fromAnalysis(moderate),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('MODERATE LIQUIDITY'), findsOneWidget);

      // Low (marketPrice: 1.00 -> < 2.0)
      final low = LiquidityAnalysis.calculate(
        marketPrice: 1.00,
        quantity: 1,
        currency: AppCurrency.usd,
        explicitBuylistPrice: 0.30,
      );

      await tester.pumpWidget(
        wrapWithTheme(
          LiquidityRealityCheckWidget.fromAnalysis(low),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('LOW LIQUIDITY'), findsOneWidget);
    });

    testWidgets('TC-LIQ-03: renders Reserved List warning badge when isReservedList is true', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const LiquidityRealityCheckWidget(
            marketPrice: 500.0,
            isReservedList: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('reserved_list_warning_badge')), findsOneWidget);
      expect(find.text('RESERVED LIST CARD'), findsOneWidget);
    });

    testWidgets('TC-LIQ-04: masks financial values when privacy mode is active', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const LiquidityRealityCheckWidget(
            marketPrice: 100.0,
            isPrivacyMode: true,
          ),
          isPrivacyMode: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('****'), findsWidgets);
    });

    testWidgets('TC-LIQ-05: renders with zero overflows on narrow 320px viewport', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        wrapWithTheme(
          const LiquidityRealityCheckWidget(
            marketPrice: 250.0,
            isReservedList: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('liquidity_reality_check_widget')), findsOneWidget);
    });
  });

  group('FiftyTwoWeekRangeBar Tests', () {
    testWidgets('TC-RANGE-01: renders 52W low, current, high, and slider thumb', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const FiftyTwoWeekRangeBar(
            low52: 10.0,
            high52: 50.0,
            currentPrice: 30.0,
            currency: AppCurrency.usd,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('fifty_two_week_range_bar')), findsOneWidget);
      expect(find.byKey(const Key('range_slider_thumb')), findsOneWidget);
      expect(find.text('50% of Range'), findsOneWidget); // 50th percentile
      expect(find.text(r'$10.00'), findsOneWidget);
      expect(find.text(r'$30.00'), findsOneWidget);
      expect(find.text(r'$50.00'), findsOneWidget);
    });

    testWidgets('TC-RANGE-02: zero-span defense places thumb at center without division by zero', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const FiftyTwoWeekRangeBar(
            low52: 25.0,
            high52: 25.0,
            currentPrice: 25.0,
            currency: AppCurrency.usd,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('range_slider_thumb')), findsOneWidget);
      expect(find.text('50% of Range'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('TC-RANGE-03: masks prices in privacy mode', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const FiftyTwoWeekRangeBar(
            low52: 10.0,
            high52: 50.0,
            currentPrice: 30.0,
            isPrivacyMode: true,
          ),
          isPrivacyMode: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('****'), findsWidgets);
      expect(find.text(r'$10.00'), findsNothing);
      expect(find.text(r'$30.00'), findsNothing);
      expect(find.text(r'$50.00'), findsNothing);
    });

    testWidgets('TC-RANGE-04: renders with zero overflows on narrow 320px viewport', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        wrapWithTheme(
          const FiftyTwoWeekRangeBar(
            low52: 12.34,
            high52: 56.78,
            currentPrice: 34.56,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('fifty_two_week_range_bar')), findsOneWidget);
    });
  });

  group('ConditionTreatmentMatrixWidget Tests', () {
    testWidgets('TC-MAT-01: renders 3x3 grid and highlights owned card with CURRENT badge', (tester) async {
      final matrix = ConditionTreatmentMatrix.compute(
        baseNonFoil: 100.0,
        baseFoil: 140.0,
        baseEtched: 154.0,
        currency: AppCurrency.usd,
      );

      await tester.pumpWidget(
        wrapWithTheme(
          ConditionTreatmentMatrixWidget(
            matrix: matrix,
            ownedCondition: 'NM',
            ownedFinish: 'foil',
            currency: AppCurrency.usd,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('condition_treatment_matrix_widget')), findsOneWidget);
      expect(find.byKey(const Key('matrix_cell_NM_foil')), findsOneWidget);
      expect(find.byKey(const Key('matrix_badge_current_NM_foil')), findsOneWidget);
      expect(find.text('CURRENT'), findsOneWidget);
    });

    testWidgets('TC-MAT-02: fires onCellSelected callback when cell is tapped', (tester) async {
      String? selectedCond;
      String? selectedFinish;
      double? selectedPrice;

      final matrix = ConditionTreatmentMatrix.compute(
        baseNonFoil: 100.0,
        baseFoil: 140.0,
        baseEtched: 154.0,
        currency: AppCurrency.usd,
      );

      await tester.pumpWidget(
        wrapWithTheme(
          ConditionTreatmentMatrixWidget(
            matrix: matrix,
            ownedCondition: 'NM',
            ownedFinish: 'non_foil',
            onCellSelected: (cond, finish, price) {
              selectedCond = cond;
              selectedFinish = finish;
              selectedPrice = price;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap LP Foil cell
      final lpFoilCell = find.byKey(const Key('matrix_cell_LP_foil'));
      expect(lpFoilCell, findsOneWidget);
      await tester.tap(lpFoilCell);
      await tester.pumpAndSettle();

      expect(selectedCond, 'LP');
      expect(selectedFinish, 'foil');
      expect(selectedPrice, closeTo(140.0 * 0.85, 0.01));
    });

    testWidgets('TC-MAT-03: masks grid prices when privacy mode is active', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const ConditionTreatmentMatrixWidget(
            baseNonFoil: 100.0,
            baseFoil: 140.0,
            baseEtched: 154.0,
            isPrivacyMode: true,
          ),
          isPrivacyMode: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('****'), findsWidgets);
    });

    testWidgets('TC-MAT-04: renders with zero overflows on narrow 320px viewport', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        wrapWithTheme(
          const ConditionTreatmentMatrixWidget(
            baseNonFoil: 100.0,
            baseFoil: 140.0,
            baseEtched: 154.0,
            ownedCondition: 'LP',
            ownedFinish: 'etched',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('condition_treatment_matrix_widget')), findsOneWidget);
    });
  });

  group('MarketSpreadTableWidget Tests', () {
    testWidgets('TC-SPREAD-01: renders vendor rows and badges for lowest retail and highest buylist', (tester) async {
      final now = DateTime.now();
      final quotes = [
        MarketPriceQuote(
          vendor: 'TCGplayer',
          quoteType: MarketQuoteType.retail,
          rawAmount: 20.0,
          currency: AppCurrency.usd,
          convertedAmount: 20.0,
          baseCurrency: AppCurrency.usd,
          timestamp: now,
        ),
        MarketPriceQuote(
          vendor: 'Card Kingdom',
          quoteType: MarketQuoteType.retail,
          rawAmount: 24.0,
          currency: AppCurrency.usd,
          convertedAmount: 24.0,
          baseCurrency: AppCurrency.usd,
          timestamp: now,
        ),
        MarketPriceQuote(
          vendor: 'Cardmarket',
          quoteType: MarketQuoteType.retail,
          rawAmount: 18.0,
          currency: AppCurrency.eur,
          convertedAmount: 18.0,
          baseCurrency: AppCurrency.usd,
          timestamp: now,
        ),
      ];

      await tester.pumpWidget(
        wrapWithTheme(
          MarketSpreadTableWidget(
            quotes: quotes,
            currency: AppCurrency.usd,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('market_spread_table_widget')), findsOneWidget);
      expect(find.byKey(const Key('vendor_name_TCGplayer')), findsOneWidget);
      expect(find.byKey(const Key('vendor_name_Card Kingdom')), findsOneWidget);
      expect(find.byKey(const Key('vendor_name_Cardmarket')), findsOneWidget);

      // Cardmarket should have lowest retail badge
      expect(find.byKey(const Key('lowest_retail_badge_Cardmarket')), findsOneWidget);
      // Card Kingdom should have highest buylist badge
      expect(find.byKey(const Key('highest_buylist_badge_Card Kingdom')), findsOneWidget);
    });

    testWidgets('TC-SPREAD-02: masks prices when privacy mode is active', (tester) async {
      await tester.pumpWidget(
        wrapWithTheme(
          const MarketSpreadTableWidget(
            baselinePrice: 25.0,
            isPrivacyMode: true,
          ),
          isPrivacyMode: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('****'), findsWidgets);
    });

    testWidgets('TC-SPREAD-03: renders with zero overflows on narrow 320px viewport', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        wrapWithTheme(
          const MarketSpreadTableWidget(
            baselinePrice: 42.0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('market_spread_table_widget')), findsOneWidget);
    });
  });

  group('FreshnessBadgeWidget Tests', () {
    testWidgets('TC-FRESH-01: renders pulsing dot and relative time formatting', (tester) async {
      final justNow = DateTime.now().subtract(const Duration(seconds: 10));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FreshnessBadgeWidget(lastUpdated: justNow),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('freshness_badge_widget')), findsOneWidget);
      expect(find.text('Updated just now'), findsOneWidget);
    });

    testWidgets('TC-FRESH-02: formats minutes, hours, and days relative timestamps', (tester) async {
      final now = DateTime.now();

      // 15 minutes ago
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FreshnessBadgeWidget(
              lastUpdated: now.subtract(const Duration(minutes: 15)),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Updated 15m ago'), findsOneWidget);

      // 4 hours ago
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FreshnessBadgeWidget(
              lastUpdated: now.subtract(const Duration(hours: 4)),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Updated 4h ago'), findsOneWidget);

      // 2 days ago
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FreshnessBadgeWidget(
              lastUpdated: now.subtract(const Duration(days: 2)),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Updated 2d ago'), findsOneWidget);
    });

    testWidgets('TC-FRESH-03: displays custom label override and responds to onTap', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FreshnessBadgeWidget(
              customLabel: 'Custom Live Feed',
              onTap: () {
                tapped = true;
              },
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Custom Live Feed'), findsOneWidget);

      await tester.tap(find.byKey(const Key('freshness_badge_widget')));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('TC-FRESH-04: renders with zero overflows on narrow 320px viewport', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FreshnessBadgeWidget(
              lastUpdated: DateTime.now().subtract(const Duration(hours: 1)),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('freshness_badge_widget')), findsOneWidget);
    });
  });
}
