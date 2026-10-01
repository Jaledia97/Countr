import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/decks/data/mock_deck_data.dart';
import 'package:countr/features/decks/domain/models/deck_item_with_card.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/decks/presentation/screens/deck_builder_screen.dart';
import 'package:countr/features/hydration/data/services/scryfall_service.dart';
import 'package:countr/features/hydration/presentation/providers/hydration_providers.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/screens/vault_screen.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';
import 'package:countr/features/values/domain/models/financial_analytics.dart';
import 'package:countr/features/values/domain/services/deck_values_calculator.dart';
import 'package:countr/features/values/domain/services/pareto_distribution_calculator.dart';
import 'package:countr/features/values/domain/services/trimmed_average_calculator.dart';
import 'package:countr/features/values/presentation/widgets/condition_treatment_matrix_widget.dart';
import 'package:countr/features/values/presentation/widgets/cost_basis_pnl_widget.dart';
import 'package:countr/features/values/presentation/widgets/fifty_two_week_range_bar.dart';
import 'package:countr/features/values/presentation/widgets/interactive_multi_line_chart.dart';
import 'package:countr/features/values/presentation/widgets/liquidity_reality_check_widget.dart';
import 'package:countr/features/values/presentation/widgets/locked_values_view.dart';
import 'package:countr/features/values/presentation/widgets/market_spread_table_widget.dart';
import 'package:countr/features/values/presentation/widgets/pareto_distribution_widget.dart';

import 'features/decks/deck_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Multi-currency regex checking for unredacted financial leakage:
  // Matches $, €, £, CA$ followed by numeric values (e.g. $10, €25.50, CA$99.00)
  final currencyRegex = RegExp(r'(\$|€|£|CA\$)\s*\d+(\.\d+)?');

  void assertZeroPrivacyLeaks(WidgetTester tester, {String contextLabel = ''}) {
    final textWidgets = tester.widgetList<Text>(find.byType(Text));
    for (final text in textWidgets) {
      final data = text.data;
      if (data != null) {
        final match = currencyRegex.firstMatch(data);
        expect(
          match,
          isNull,
          reason: 'Privacy leak detected in Text widget ($contextLabel): "$data"',
        );
      }
      final textSpan = text.textSpan;
      if (textSpan != null) {
        final plain = textSpan.toPlainText();
        final match = currencyRegex.firstMatch(plain);
        expect(
          match,
          isNull,
          reason: 'Privacy leak detected in Text.textSpan ($contextLabel): "$plain"',
        );
      }
    }

    final richTextWidgets = tester.widgetList<RichText>(find.byType(RichText));
    for (final rich in richTextWidgets) {
      final plain = rich.text.toPlainText();
      final match = currencyRegex.firstMatch(plain);
      expect(
        match,
        isNull,
        reason: 'Privacy leak detected in RichText widget ($contextLabel): "$plain"',
      );
    }
  }

  late AppDatabase testDb;
  late ScryfallService mockScryfall;

  setUp(() async {
    testDb = AppDatabase(NativeDatabase.memory());
    await testDb.vaultDao.clearAllItems();
    await testDb.vaultDao.seedDatabase();

    mockScryfall = ScryfallService(
      client: MockClient((request) async {
        return http.Response(jsonEncode({'object': 'list', 'data': []}), 200);
      }),
    );
  });

  tearDown(() async {
    await testDb.close();
  });

  VaultItem createTestCard({
    String id = 'card-adv-test-1',
    String name = 'Mox Diamond',
    String setCode = 'STH',
    double price = 650.0,
    int quantity = 1,
    double acquiredPrice = 300.0,
    String condition = 'NM',
  }) {
    return VaultItem(
      id: id,
      collectionType: 'mtg',
      name: name,
      setOrSeries: setCode.toUpperCase(),
      imageUrl: 'https://cards.scryfall.io/normal/front/mox_diamond.jpg',
      acquiredPrice: acquiredPrice,
      purchasePrice: acquiredPrice,
      acquiredDate: DateTime(2023, 5, 20),
      dateObtained: DateTime(2023, 5, 20),
      quantity: quantity,
      condition: condition,
      protectionStatus: 'Sleeved',
      binderPage: 1,
      binderSlot: 'A1',
      notes: 'Reserved List staple',
      personalNotes: 'Reserved List staple',
      isGraded: false,
      isAltered: false,
      isMisprint: false,
      isSigned: false, isDeleted: false,
      currentMarketPrice: price,
      lastPriceUpdate: DateTime(2026, 9, 24),
      dynamicData: jsonEncode({
        'collector_number': '138',
        'set': setCode.toLowerCase(),
        'artist': 'Dan Frazier',
        'finishes': ['nonfoil'],
        'oracle_text': 'Discard a land card: Add one mana of any color.',
        'cached_rulings': [],
      }),
    );
  }

  // ==========================================================================
  // GROUP 1: Fritsch-Carlson Monotone Cubic Spline Boundary Conditions
  // ==========================================================================
  group('GROUP 1: Fritsch-Carlson Monotone Cubic Spline Boundary Conditions', () {
    /// Pure mathematical evaluator mirroring `_buildSplinePath` in InteractiveMultiLineChart
    Path buildFritschCarlsonPath(List<Offset> coords) {
      final path = Path();
      if (coords.isEmpty) return path;
      final n = coords.length;
      path.moveTo(coords[0].dx, coords[0].dy);
      if (n == 2) {
        path.lineTo(coords[1].dx, coords[1].dy);
        return path;
      }

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
          if (alpha < 0.0) slopes[i] = 0.0;
          if (beta < 0.0) slopes[i + 1] = 0.0;
          final sumSq = alpha * alpha + beta * beta;
          if (sumSq > 9.0) {
            final tau = 3.0 / math.sqrt(sumSq);
            slopes[i] = tau * alpha * s;
            slopes[i + 1] = tau * beta * s;
          }
        }
      }

      for (int i = 0; i < n - 1; i++) {
        final cur = coords[i];
        final next = coords[i + 1];
        final dx = dxs[i];
        final cp1 = Offset(cur.dx + dx / 3.0, cur.dy + slopes[i] * dx / 3.0);
        final cp2 = Offset(next.dx - dx / 3.0, next.dy - slopes[i + 1] * dx / 3.0);
        path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, next.dx, next.dy);
      }
      return path;
    }

    test('1.1: Strictly monotonic increasing dataset produces zero overshoot and NaN-free coordinates', () {
      final yValues = [10.0, 20.0, 35.0, 60.0, 100.0, 175.0, 250.0];
      final coords = List.generate(
        yValues.length,
        (i) => Offset(i * 50.0, yValues[i]),
      );

      final path = buildFritschCarlsonPath(coords);
      final metrics = path.computeMetrics().toList();
      expect(metrics.isNotEmpty, isTrue);

      final metric = metrics.first;
      const samples = 100;
      double prevY = yValues.first;

      for (int s = 0; s <= samples; s++) {
        final dist = (metric.length * s) / samples;
        final tangent = metric.getTangentForOffset(dist);
        expect(tangent, isNotNull);
        final pos = tangent!.position;

        expect(pos.dx.isNaN, isFalse);
        expect(pos.dx.isInfinite, isFalse);
        expect(pos.dy.isNaN, isFalse);
        expect(pos.dy.isInfinite, isFalse);

        // Strict monotonicity check: y cannot decrease
        expect(pos.dy, greaterThanOrEqualTo(prevY - 0.001));
        // Strict boundary check: y cannot exceed bounds
        expect(pos.dy, greaterThanOrEqualTo(yValues.first - 0.001));
        expect(pos.dy, lessThanOrEqualTo(yValues.last + 0.001));
        prevY = pos.dy;
      }
    });

    test('1.2: Strictly monotonic decreasing dataset produces zero overshoot and zero negative dip', () {
      final yValues = [500.0, 350.0, 220.0, 140.0, 75.0, 30.0, 5.0];
      final coords = List.generate(
        yValues.length,
        (i) => Offset(i * 50.0, yValues[i]),
      );

      final path = buildFritschCarlsonPath(coords);
      final metric = path.computeMetrics().first;
      const samples = 100;
      double prevY = yValues.first;

      for (int s = 0; s <= samples; s++) {
        final dist = (metric.length * s) / samples;
        final tangent = metric.getTangentForOffset(dist);
        expect(tangent, isNotNull);
        final pos = tangent!.position;

        expect(pos.dx.isNaN, isFalse);
        expect(pos.dy.isNaN, isFalse);
        expect(pos.dy, lessThanOrEqualTo(prevY + 0.001));
        expect(pos.dy, lessThanOrEqualTo(yValues.first + 0.001));
        expect(pos.dy, greaterThanOrEqualTo(yValues.last - 0.001));
        prevY = pos.dy;
      }
    });

    test('1.3: Flat horizontal line produces identical Y-coordinates and zero artificial ringing', () {
      const flatY = 42.0;
      final coords = List.generate(
        15,
        (i) => Offset(i * 30.0, flatY),
      );

      final path = buildFritschCarlsonPath(coords);
      final metric = path.computeMetrics().first;

      for (int s = 0; s <= 50; s++) {
        final dist = (metric.length * s) / 50;
        final pos = metric.getTangentForOffset(dist)!.position;
        expect(pos.dy, closeTo(flatY, 1e-6));
        expect(pos.dx.isNaN, isFalse);
        expect(pos.dy.isNaN, isFalse);
      }
    });

    test('1.4: 2-point dataset renders direct linear segment with zero overshoot', () {
      final coords = [const Offset(0, 10.0), const Offset(100, 90.0)];
      final path = buildFritschCarlsonPath(coords);
      final metric = path.computeMetrics().first;

      for (int s = 0; s <= 20; s++) {
        final dist = (metric.length * s) / 20;
        final pos = metric.getTangentForOffset(dist)!.position;
        expect(pos.dy, greaterThanOrEqualTo(10.0 - 0.001));
        expect(pos.dy, lessThanOrEqualTo(90.0 + 0.001));
        expect(pos.dx.isNaN, isFalse);
        expect(pos.dy.isNaN, isFalse);
      }
    });

    test('1.5: Sudden 1,000,000x step function has zero overshoot and completely flat boundaries', () {
      // Step up: [1.0, 1.0, 1000000.0, 1000000.0]
      final stepUpCoords = [
        const Offset(0, 1.0),
        const Offset(50, 1.0),
        const Offset(100, 1000000.0),
        const Offset(150, 1000000.0),
      ];

      final pathUp = buildFritschCarlsonPath(stepUpCoords);
      final metricUp = pathUp.computeMetrics().first;

      for (int s = 0; s <= 100; s++) {
        final dist = (metricUp.length * s) / 100;
        final pos = metricUp.getTangentForOffset(dist)!.position;
        expect(pos.dy, greaterThanOrEqualTo(1.0 - 1e-4));
        expect(pos.dy, lessThanOrEqualTo(1000000.0 + 1e-4));
        expect(pos.dx.isNaN, isFalse);
        expect(pos.dy.isNaN, isFalse);
      }

      // Step down: [1000000.0, 1000000.0, 1.0, 1.0]
      final stepDownCoords = [
        const Offset(0, 1000000.0),
        const Offset(50, 1000000.0),
        const Offset(100, 1.0),
        const Offset(150, 1.0),
      ];

      final pathDown = buildFritschCarlsonPath(stepDownCoords);
      final metricDown = pathDown.computeMetrics().first;

      for (int s = 0; s <= 100; s++) {
        final dist = (metricDown.length * s) / 100;
        final pos = metricDown.getTangentForOffset(dist)!.position;
        expect(pos.dy, lessThanOrEqualTo(1000000.0 + 1e-4));
        expect(pos.dy, greaterThanOrEqualTo(1.0 - 1e-4));
        expect(pos.dx.isNaN, isFalse);
        expect(pos.dy.isNaN, isFalse);
      }
    });

    testWidgets('1.6: InteractiveMultiLineChart renders 1,000,000x step dataset cleanly', (tester) async {
      final baseDate = DateTime(2026, 1, 1);
      final stepData = MultiLineChartData(
        horizon: ChartTimeHorizon.thirtyDays,
        currency: AppCurrency.usd,
        trimmedAverage: ChartSeries(
          id: 'step_test',
          label: 'Step Curve',
          color: AppColors.accentCyan,
          points: [
            ChartPoint(timestamp: baseDate, price: 1.0),
            ChartPoint(timestamp: baseDate.add(const Duration(days: 5)), price: 1.0),
            ChartPoint(timestamp: baseDate.add(const Duration(days: 10)), price: 1000000.0),
            ChartPoint(timestamp: baseDate.add(const Duration(days: 15)), price: 1000000.0),
          ],
        ),
        vendorSeries: {},
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: InteractiveMultiLineChart(data: stepData),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('multi_line_chart_canvas')), findsOneWidget);
    });
  });

  // ==========================================================================
  // GROUP 2: Trimmed Average Calculation Hardening
  // ==========================================================================
  group('GROUP 2: Trimmed Average Calculation Hardening', () {
    test('2.1: Symmetrical trimming across N = 5, 9, 10, 50, 100 quotes', () {
      // N = 5: k = 1, trims lowest 1 and highest 1. Slices 3 middle.
      final prices5 = [0.05, 10.0, 10.0, 10.0, 500000.0];
      final res5 = TrimmedAverageCalculator.computeTrimmedMean(prices5);
      expect(res5, equals(10.0));

      // N = 9: 5 <= N < 10 rule: k = 1, trims lowest 1 and highest 1. Slices 7 middle.
      final prices9 = [0.03, 5.0, 10.0, 10.0, 10.0, 10.0, 10.0, 15.0, 999999.0];
      final res9 = TrimmedAverageCalculator.computeTrimmedMean(prices9);
      expect(res9, equals(10.0)); // (5 + 10*5 + 15) / 7 = 70 / 7 = 10.0

      // N = 10: k = floor(0.10 * 10) = 1, trims lowest 1 and highest 1. Slices 8 middle.
      final prices10 = [0.04, 20.0, 20.0, 20.0, 20.0, 20.0, 20.0, 20.0, 20.0, 1000000.0];
      final res10 = TrimmedAverageCalculator.computeTrimmedMean(prices10);
      expect(res10, equals(20.0));

      // N = 50: k = floor(0.10 * 50) = 5, trims lowest 5 and highest 5. Slices 40 middle.
      final prices50 = <double>[
        ...List.filled(5, 0.03),
        ...List.filled(40, 50.0),
        ...List.filled(5, 100000.0),
      ];
      final res50 = TrimmedAverageCalculator.computeTrimmedMean(prices50);
      expect(res50, equals(50.0));

      // N = 100: k = floor(0.10 * 100) = 10, trims lowest 10 and highest 10. Slices 80 middle.
      final prices100 = <double>[
        ...List.filled(10, 0.03),
        ...List.filled(80, 100.0),
        ...List.filled(10, 999999.0),
      ];
      final res100 = TrimmedAverageCalculator.computeTrimmedMean(prices100);
      expect(res100, equals(100.0));
    });

    test('2.2: Extreme outlier sets are safely trimmed without corrupting mean', () {
      final quotes = {
        'v1': 0.03, // Low outlier
        'v2': 25.0,
        'v3': 25.0,
        'v4': 25.0,
        'v5': 10000000.0, // High outlier ($10M)
      };
      final currencies = {
        'v1': AppCurrency.usd,
        'v2': AppCurrency.usd,
        'v3': AppCurrency.usd,
        'v4': AppCurrency.usd,
        'v5': AppCurrency.usd,
      };

      final avg = TrimmedAverageCalculator.computeTrimmedAverage(
        rawQuotes: quotes,
        vendorCurrencies: currencies,
        targetCurrency: AppCurrency.usd,
      );

      expect(avg, isNotNull);
      expect(avg, equals(25.0));
    });

    test('2.3: Rejects negative prices, NaN prices, infinite prices, and zero prices', () {
      final invalidQuotes = {
        'neg1': -100.0,
        'neg2': -0.0001,
        'zero1': 0.0,
        'zero2': -0.0,
        'nan': double.nan,
        'inf': double.infinity,
        'neg_inf': double.negativeInfinity,
      };
      final currMap = invalidQuotes.map((k, _) => MapEntry(k, AppCurrency.usd));

      final result = TrimmedAverageCalculator.computeTrimmedAverage(
        rawQuotes: invalidQuotes,
        vendorCurrencies: currMap,
        targetCurrency: AppCurrency.usd,
      );

      expect(result, isNull);

      // Mix with one valid quote
      final mixedQuotes = Map<String, double>.from(invalidQuotes)..['valid'] = 45.0;
      final mixedCurr = Map<String, AppCurrency>.from(currMap)..['valid'] = AppCurrency.usd;

      final mixedResult = TrimmedAverageCalculator.computeTrimmedAverage(
        rawQuotes: mixedQuotes,
        vendorCurrencies: mixedCurr,
        targetCurrency: AppCurrency.usd,
      );

      expect(mixedResult, equals(45.0));
    });

    test('2.4: Floor anomaly threshold strictly handles \$0.02001 boundary', () {
      // Exactly 0.02000 is discarded
      expect(TrimmedAverageCalculator.isFloorAnomaly(0.02000), isTrue);

      // Exactly 0.02001 is discarded
      expect(TrimmedAverageCalculator.isFloorAnomaly(0.02001), isTrue);

      // 0.020011 is preserved (> 0.02001)
      expect(TrimmedAverageCalculator.isFloorAnomaly(0.020011), isFalse);

      // 0.02002 is preserved
      expect(TrimmedAverageCalculator.isFloorAnomaly(0.02002), isFalse);

      // 0.021 is preserved
      expect(TrimmedAverageCalculator.isFloorAnomaly(0.02100), isFalse);

      // End-to-end computeTrimmedAverage boundary check:
      final boundaryQuotes = {
        'discard1': 0.02000,
        'discard2': 0.02001,
        'keep1': 0.02002,
        'keep2': 0.02004,
      };
      final currencies = boundaryQuotes.map((k, _) => MapEntry(k, AppCurrency.usd));

      final avg = TrimmedAverageCalculator.computeTrimmedAverage(
        rawQuotes: boundaryQuotes,
        vendorCurrencies: currencies,
        targetCurrency: AppCurrency.usd,
      );

      expect(avg, isNotNull);
      expect(avg, closeTo(0.02003, 1e-5));
    });
  });

  // ==========================================================================
  // GROUP 3: Pareto Concentration Math & Boundary Handling
  // ==========================================================================
  group('GROUP 3: Pareto Concentration Math & Boundary Handling', () {
    test('3.1: Decks with 0 cards return empty result and clean zero state', () {
      final summary = DeckValuesCalculator.calculate(
        deckId: 'empty-deck',
        items: const [],
        currency: AppCurrency.usd,
      );

      expect(summary.totalMarketValue, equals(0.0));
      expect(summary.totalCostBasis, equals(0.0));
      expect(summary.dollarReturn, equals(0.0));
      expect(summary.percentageReturn, equals(0.0));
      expect(summary.paretoConcentration, equals(0.0));
      expect(summary.heavyHitters.isEmpty, isTrue);
      expect(summary.paretoHeadline, contains('No cards in deck'));

      final paretoResult = ParetoDistributionCalculator.calculate(
        cards: const [],
        currency: AppCurrency.usd,
      );

      expect(paretoResult.isEmpty, isTrue);
      expect(paretoResult.concentrationPercentage, equals(0.0));
      expect(paretoResult.topCards.isEmpty, isTrue);
      expect(paretoResult.getHeadline(), equals('No cards in deck to calculate concentration.'));
    });

    test('3.2: Decks with 1 card calculate 100.0% concentration and singular headline', () {
      final card = ParetoCardInput(
        id: 'solo-1',
        name: 'The One Ring',
        setCode: 'LTR',
        quantity: 1,
        unitPrice: 150.0,
      );

      final result = ParetoDistributionCalculator.calculate(
        cards: [card],
        currency: AppCurrency.usd,
      );

      expect(result.totalDeckValue, equals(150.0));
      expect(result.topCardsValue, equals(150.0));
      expect(result.concentrationPercentage, equals(100.0));
      expect(result.topK, equals(1));
      expect(result.topCards.length, equals(1));
      expect(result.topCards.first.percentageShare, equals(100.0));
      expect(result.topCards.first.weightRatio, equals(1.0));
      expect(
        result.getHeadline(),
        equals("The top card represents 100.0% of this deck's total value."),
      );
    });

    test('3.3: Decks with 100 identical cards handle concentration and deterministic sorting', () {
      // 100 unique cards with identical price ($5.00 each)
      final identicalCards = List.generate(
        100,
        (i) => ParetoCardInput(
          id: 'card-$i',
          name: 'Card ${i.toString().padLeft(3, '0')}',
          setCode: 'TST',
          quantity: 1,
          unitPrice: 5.0,
        ),
      );

      final result = ParetoDistributionCalculator.calculate(
        cards: identicalCards,
        targetK: 5,
        currency: AppCurrency.usd,
      );

      expect(result.totalDeckValue, equals(500.0));
      expect(result.totalUniqueCards, equals(100));
      expect(result.totalCardCount, equals(100));
      expect(result.topK, equals(5));
      expect(result.topCardsValue, equals(25.0)); // 5 * $5
      expect(result.concentrationPercentage, equals(5.0)); // (25 / 500) * 100 = 5.0%
      expect(
        result.getHeadline(),
        equals("The top 5 cards represent 5.0% of this deck's total value."),
      );

      // Deterministic tie-breaking verification: sorted alphabetically by name
      expect(result.topCards[0].name, equals('Card 000'));
      expect(result.topCards[1].name, equals('Card 001'));
      expect(result.topCards[2].name, equals('Card 002'));
      expect(result.topCards[3].name, equals('Card 003'));
      expect(result.topCards[4].name, equals('Card 004'));
    });

    test('3.4: 1 card having 99.9% value clamps weight ratio without overflow or NaN', () {
      final cards = [
        const ParetoCardInput(
          id: 'lotus',
          name: 'Black Lotus',
          setCode: 'LEA',
          quantity: 1,
          unitPrice: 99900.0,
        ),
        ...List.generate(
          99,
          (i) => ParetoCardInput(
            id: 'bulk-$i',
            name: 'Forest $i',
            quantity: 1,
            unitPrice: 1.0,
          ),
        ),
      ];

      final result = ParetoDistributionCalculator.calculate(
        cards: cards,
        targetK: 5,
        currency: AppCurrency.usd,
      );

      // Total = 99900 + 99 = 99999
      expect(result.totalDeckValue, equals(99999.0));
      final lotus = result.topCards.first;
      expect(lotus.name, equals('Black Lotus'));
      expect(lotus.percentageShare, closeTo(99.9, 0.1));
      expect(lotus.weightRatio, lessThanOrEqualTo(1.0));
      expect(lotus.weightRatio, greaterThan(0.99));
      expect(result.concentrationPercentage, closeTo(99.9, 0.1));
    });

    test('3.5: Cards with 0 cost basis strictly defend against division-by-zero', () {
      final pnl = PnLResult.calculate(
        costBasisPerUnit: 0.0,
        marketPricePerUnit: 120.0,
        quantity: 2,
        currency: AppCurrency.usd,
      );

      expect(pnl.costBasis, equals(0.0));
      expect(pnl.marketValue, equals(240.0));
      expect(pnl.dollarReturn, equals(240.0));
      expect(pnl.percentageReturn, equals(0.0)); // Strictly 0.0%, no NaN or Infinity
      expect(pnl.isProfit, isTrue);
      expect(pnl.isLoss, isFalse);
      expect(pnl.formatReturn(isPrivacyMode: false), equals(r'+$240.00 (+0.0%)'));

      // Deck level with zero cost basis
      final deckSummary = DeckValuesCalculator.calculate(
        deckId: 'zero-cost-deck',
        items: [
          DeckItemWithCard.fromMap({
            'id': 'item-1',
            'name': 'Sol Ring',
            'set_or_series': 'CMM',
            'deck_quantity': 1,
            'purchase_price': 0.0,
            'acquired_price': 0.0,
            'current_market_price': 50.0,
            'board_zone': 'Mainboard',
          }),
        ],
        currency: AppCurrency.usd,
      );

      expect(deckSummary.totalCostBasis, equals(0.0));
      expect(deckSummary.totalMarketValue, equals(50.0));
      expect(deckSummary.dollarReturn, equals(50.0));
      expect(deckSummary.percentageReturn, equals(0.0));
      expect(deckSummary.percentageReturn.isNaN, isFalse);
      expect(deckSummary.percentageReturn.isInfinite, isFalse);
    });
  });

  // ==========================================================================
  // GROUP 4: Viewport Constraint Hardening (320x568 at 2.0x font scaling)
  // ==========================================================================
  group('GROUP 4: Viewport Constraint Hardening (320x568 @ 2.0x)', () {
    const narrowSize = Size(320, 568);
    const extremeScaler = TextScaler.linear(2.0);

    testWidgets('4.1: DeckBuilderScreen Values tab renders with ZERO overflows on 320x568 @ 2.0x font scaling', (tester) async {
      tester.view.physicalSize = narrowSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final testDeck = createTestDeck(
        id: 'deck-adv-viewport',
        name: 'Adversarial Deck',
      );

      final mockItems = MockDeckData.getDeckItems(testDeck.id)
          .map<Map<String, dynamic>>(DeckItemWithCard.fromMap)
          .toList();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deckItemsProvider(testDeck.id).overrideWith(
              (ref) => Stream.value(mockItems),
            ),
            privacyModeProvider.overrideWith((ref) => false),
            baseCurrencyProvider.overrideWith((ref) => AppCurrency.usd),
          ],
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: narrowSize,
                textScaler: extremeScaler,
              ),
              child: DeckBuilderScreen(deck: testDeck),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Values tab
      final valuesTab = find.byKey(const Key('deck_builder_tab_values'));
      expect(valuesTab, findsOneWidget);
      await tester.tap(valuesTab);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'Zero RenderFlex overflows in DeckBuilderScreen Values tab');
      expect(find.byKey(const Key('deck_values_aggregate_card')), findsOneWidget);

      // Scroll down in narrow 320x568 @ 2.0x viewport to reveal Pareto widget and zone breakdown
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pareto_distribution_widget')), findsOneWidget);

      // Deep scroll to exercise zone breakdown at 2.0x font scaling
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'Zero overflows after deep scroll in DeckBuilderScreen Values tab');
    });

    testWidgets('4.2: CardDetailSheet Values tab renders all 7 components with ZERO overflows on 320x568 @ 2.0x font scaling', (tester) async {
      tester.view.physicalSize = narrowSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final testCard = createTestCard();
      await testDb.into(testDb.vaultItems).insert(testCard);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(testDb),
            vaultDaoProvider.overrideWithValue(testDb.vaultDao),
            scryfallServiceProvider.overrideWithValue(mockScryfall),
            privacyModeProvider.overrideWith((ref) => false),
            baseCurrencyProvider.overrideWith((ref) => AppCurrency.usd),
          ],
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: narrowSize,
                textScaler: extremeScaler,
              ),
              child: Scaffold(
                body: CardDetailSheet(
                  item: testCard,
                  fetchOnlinePrintings: false,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Values tab
      final valuesTab = find.byKey(const Key('card_detail_tab_values'));
      expect(valuesTab, findsOneWidget);
      await tester.tap(valuesTab);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'Zero overflows initially in CardDetailSheet Values tab');

      // Scroll through each section to ensure zero overflows across all 7 widgets
      for (int i = 0; i < 4; i++) {
        await tester.drag(find.byType(ListView), const Offset(0, -350));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Zero overflows during scroll step $i in CardDetailSheet Values tab');
      }
    });

    testWidgets('4.3: VaultScreen portfolio summary renders with ZERO overflows on 320x568 @ 2.0x font scaling', (tester) async {
      tester.view.physicalSize = narrowSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const summary = VaultPortfolioSummary(
        totalMarketValue: 85240.50,
        totalCostBasis: 42100.00,
        totalProfitLoss: 43140.50,
        profitLossPercentage: 102.47,
        totalItemCount: 1420,
        uniqueCardCount: 980,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(testDb),
            vaultDaoProvider.overrideWithValue(testDb.vaultDao),
            scryfallServiceProvider.overrideWithValue(mockScryfall),
            vaultPortfolioSummaryProvider.overrideWithValue(summary),
            privacyModeProvider.overrideWith((ref) => false),
            baseCurrencyProvider.overrideWith((ref) => AppCurrency.usd),
            activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
          ],
          child: const MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: narrowSize,
                textScaler: extremeScaler,
              ),
              child: VaultScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'Zero overflows in VaultScreen portfolio summary on 320x568 @ 2.0x');
      expect(find.byKey(const Key('vault_portfolio_summary_card')), findsOneWidget);
    });
  });

  // ==========================================================================
  // GROUP 5: Privacy Mode Leakage Scan Across All Surfaces
  // ==========================================================================
  group('GROUP 5: Privacy Mode Leakage Scan Across All Surfaces', () {
    testWidgets('5.1: DeckBuilderScreen Values tab renders LockedValuesView and zero privacy leaks', (tester) async {
      final testDeck = createTestDeck(
        id: 'deck-adv-privacy',
        name: 'Privacy Scan Deck',
      );

      final mockItems = MockDeckData.getDeckItems(testDeck.id)
          .map<Map<String, dynamic>>(DeckItemWithCard.fromMap)
          .toList();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deckItemsProvider(testDeck.id).overrideWith(
              (ref) => Stream.value(mockItems),
            ),
            privacyModeProvider.overrideWith((ref) => true), // Privacy ON
            baseCurrencyProvider.overrideWith((ref) => AppCurrency.usd),
          ],
          child: MaterialApp(
            home: DeckBuilderScreen(deck: testDeck),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Values tab
      await tester.tap(find.byKey(const Key('deck_builder_tab_values')));
      await tester.pumpAndSettle();

      // Must render LockedValuesView
      expect(find.byType(LockedValuesView), findsOneWidget);
      expect(find.byKey(const Key('deck_values_aggregate_card')), findsNothing);

      // Deep privacy scan
      assertZeroPrivacyLeaks(tester, contextLabel: 'DeckBuilderScreen Values tab');
    });

    testWidgets('5.2: CardDetailSheet Values tab renders LockedValuesView and zero privacy leaks', (tester) async {
      final testCard = createTestCard(price: 1250.0);
      await testDb.into(testDb.vaultItems).insert(testCard);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(testDb),
            vaultDaoProvider.overrideWithValue(testDb.vaultDao),
            scryfallServiceProvider.overrideWithValue(mockScryfall),
            privacyModeProvider.overrideWith((ref) => true), // Privacy ON
            baseCurrencyProvider.overrideWith((ref) => AppCurrency.usd),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: CardDetailSheet(
                item: testCard,
                fetchOnlinePrintings: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Values tab
      await tester.tap(find.byKey(const Key('card_detail_tab_values')));
      await tester.pumpAndSettle();

      expect(find.byType(LockedValuesView), findsOneWidget);
      expect(find.byKey(const Key('card_detail_values_locked_container')), findsOneWidget);

      // Deep privacy scan
      assertZeroPrivacyLeaks(tester, contextLabel: 'CardDetailSheet Values tab');
    });

    testWidgets('5.3: Individual Values engine widgets redact all numbers to **** with zero leakage', (tester) async {
      Widget wrapWithPrivacy(Widget child) {
        return ProviderScope(
          overrides: [
            privacyModeProvider.overrideWith((ref) => true),
            baseCurrencyProvider.overrideWith((ref) => AppCurrency.usd),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: child),
            ),
          ),
        );
      }

      // 1. CostBasisPnLWidget
      await tester.pumpWidget(wrapWithPrivacy(
        const CostBasisPnLWidget(purchasePrice: 200.0, marketPrice: 450.0, isPrivacyMode: true),
      ));
      await tester.pumpAndSettle();
      assertZeroPrivacyLeaks(tester, contextLabel: 'CostBasisPnLWidget in privacy mode');
      expect(find.text('****'), findsWidgets);

      // 2. LiquidityRealityCheckWidget
      await tester.pumpWidget(wrapWithPrivacy(
        const LiquidityRealityCheckWidget(marketPrice: 350.0, isPrivacyMode: true),
      ));
      await tester.pumpAndSettle();
      assertZeroPrivacyLeaks(tester, contextLabel: 'LiquidityRealityCheckWidget in privacy mode');

      // 3. FiftyTwoWeekRangeBar
      await tester.pumpWidget(wrapWithPrivacy(
        const FiftyTwoWeekRangeBar(low52: 50.0, high52: 120.0, currentPrice: 95.0, isPrivacyMode: true),
      ));
      await tester.pumpAndSettle();
      assertZeroPrivacyLeaks(tester, contextLabel: 'FiftyTwoWeekRangeBar in privacy mode');

      // 4. ConditionTreatmentMatrixWidget
      await tester.pumpWidget(wrapWithPrivacy(
        const ConditionTreatmentMatrixWidget(baseNonFoil: 30.0, isPrivacyMode: true),
      ));
      await tester.pumpAndSettle();
      assertZeroPrivacyLeaks(tester, contextLabel: 'ConditionTreatmentMatrixWidget in privacy mode');

      // 5. MarketSpreadTableWidget
      await tester.pumpWidget(wrapWithPrivacy(
        const MarketSpreadTableWidget(baselinePrice: 75.0, isPrivacyMode: true),
      ));
      await tester.pumpAndSettle();
      assertZeroPrivacyLeaks(tester, contextLabel: 'MarketSpreadTableWidget in privacy mode');

      // 6. ParetoDistributionWidget
      final mockPareto = ParetoDistributionCalculator.calculate(
        cards: [
          const ParetoCardInput(id: '1', name: 'Lotus', unitPrice: 5000.0, quantity: 1),
          const ParetoCardInput(id: '2', name: 'Mox', unitPrice: 2500.0, quantity: 1),
        ],
      );
      await tester.pumpWidget(wrapWithPrivacy(
        ParetoDistributionWidget(result: mockPareto, isPrivacyMode: true),
      ));
      await tester.pumpAndSettle();
      assertZeroPrivacyLeaks(tester, contextLabel: 'ParetoDistributionWidget in privacy mode');
      expect(find.textContaining('****'), findsWidgets);
    });

    testWidgets('5.4: VaultScreen portfolio summary completely masks market value and returns under Privacy Mode', (tester) async {
      const summary = VaultPortfolioSummary(
        totalMarketValue: 120500.0,
        totalCostBasis: 55000.0,
        totalProfitLoss: 65500.0,
        profitLossPercentage: 119.09,
        totalItemCount: 450,
        uniqueCardCount: 300,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(testDb),
            vaultDaoProvider.overrideWithValue(testDb.vaultDao),
            scryfallServiceProvider.overrideWithValue(mockScryfall),
            vaultPortfolioSummaryProvider.overrideWithValue(summary),
            privacyModeProvider.overrideWith((ref) => true), // Privacy ON
            baseCurrencyProvider.overrideWith((ref) => AppCurrency.usd),
            activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
          ],
          child: const MaterialApp(
            home: VaultScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      assertZeroPrivacyLeaks(tester, contextLabel: 'VaultScreen portfolio summary under privacy mode');
      expect(find.text('****'), findsWidgets);
      expect(find.text(r'$120,500.00'), findsNothing);
    });

    testWidgets('5.5: Dynamic privacy toggle immediately transitions between unlocked and locked state', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final container = ProviderContainer(
        overrides: [
          privacyModeProvider.overrideWith((ref) => false),
          baseCurrencyProvider.overrideWith((ref) => AppCurrency.usd),
        ],
      );
      addTearDown(container.dispose);

      final testCard = createTestCard(price: 450.0);
      await testDb.into(testDb.vaultItems).insert(testCard);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: CardDetailSheet(
                item: testCard,
                fetchOnlinePrintings: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Values tab while privacy is OFF
      await tester.tap(find.byKey(const Key('card_detail_tab_values')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('market_valuation_header')), findsOneWidget);
      expect(find.byType(LockedValuesView), findsNothing);

      // Now toggle Privacy Mode ON dynamically
      container.read(privacyModeProvider.notifier).state = true;
      await tester.pumpAndSettle();

      // Immediately shows LockedValuesView and 0 privacy leaks
      expect(find.byType(LockedValuesView), findsOneWidget);
      assertZeroPrivacyLeaks(tester, contextLabel: 'Dynamic privacy toggle locked state');

      // Tap unlock button on LockedValuesView
      final unlockBtn = find.byKey(const Key('locked_values_disable_privacy_button'));
      expect(unlockBtn, findsOneWidget);
      await tester.tap(unlockBtn);
      await tester.pumpAndSettle();

      // Privacy should now be OFF again
      expect(container.read(privacyModeProvider), isFalse);
      expect(find.byKey(const Key('market_valuation_header')), findsOneWidget);
      expect(find.byType(LockedValuesView), findsNothing);
    });
  });
}
