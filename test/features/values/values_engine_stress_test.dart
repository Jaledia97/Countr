// Copyright (c) 2026 Countr. All rights reserved.
// Empirical Adversarial Stress Test Suite for Milestone 3:
// Collector & Investor Values Engine Mathematical Core & Domain Models.

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:countr/core/state/settings_state.dart';
import 'package:countr/features/values/domain/exchange_rate_service.dart';
import 'package:countr/features/values/domain/models/financial_analytics.dart';
import 'package:countr/features/values/domain/models/market_price_quote.dart';
import 'package:countr/features/values/domain/services/trimmed_average_calculator.dart';
import 'package:countr/features/values/domain/trimmed_market_average_calculator.dart';
import 'package:countr/features/values/presentation/widgets/fifty_two_week_range_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    ExchangeRateService.resetToDefaults();
  });

  tearDown(() {
    ExchangeRateService.resetToDefaults();
  });

  // ===========================================================================
  // 1. FLOOR ANOMALY REJECTION ORACLES
  // ===========================================================================
  group('Adversarial Oracle 1: Floor Anomaly Rejection Math & Boundaries', () {
    test('Boundary Oracle: Strict 0.02001 threshold partition', () {
      // Exactly at canonical minimumFloorPrice (0.02) -> must be discarded
      expect(TrimmedAverageCalculator.isFloorAnomaly(0.02), isTrue);
      expect(TrimmedAverageCalculator.isFloorAnomaly(0.02000), isTrue);

      // Exactly at floorAnomalyThreshold (0.02001) -> discarded (<= threshold)
      expect(TrimmedAverageCalculator.isFloorAnomaly(0.02001), isTrue);

      // Sub-micro above floor threshold -> must be PRESERVED
      expect(TrimmedAverageCalculator.isFloorAnomaly(0.020010000000000005), isFalse);
      expect(TrimmedAverageCalculator.isFloorAnomaly(0.020011), isFalse);
      expect(TrimmedAverageCalculator.isFloorAnomaly(0.021), isFalse);
      expect(TrimmedAverageCalculator.isFloorAnomaly(0.03), isFalse);

      // Sub-floor pennies -> discarded
      expect(TrimmedAverageCalculator.isFloorAnomaly(0.019999), isTrue);
      expect(TrimmedAverageCalculator.isFloorAnomaly(0.01), isTrue);
      expect(TrimmedAverageCalculator.isFloorAnomaly(0.005), isTrue);
      expect(TrimmedAverageCalculator.isFloorAnomaly(0.0001), isTrue);
      expect(TrimmedAverageCalculator.isFloorAnomaly(1e-15), isTrue);
    });

    test('Zero, Negative, Non-Finite & Subnormal Floor Anomaly Oracle', () {
      final invalidValues = [
        0.0,
        -0.0,
        -0.0000001,
        -0.02,
        -1.0,
        -99999.0,
        double.nan,
        double.infinity,
        double.negativeInfinity,
      ];

      for (final val in invalidValues) {
        expect(
          TrimmedAverageCalculator.isFloorAnomaly(val),
          isTrue,
          reason: 'isFloorAnomaly must return true for $val',
        );

        // Verify MarketPriceQuote floor anomaly evaluation
        final quote = MarketPriceQuote(
          vendor: 'test',
          quoteType: MarketQuoteType.market,
          rawAmount: val,
          currency: AppCurrency.usd,
          convertedAmount: val,
          baseCurrency: AppCurrency.usd,
          timestamp: DateTime.now(),
        );
        expect(
          quote.isFloorAnomaly(),
          isTrue,
          reason: 'MarketPriceQuote.isFloorAnomaly must return true for $val',
        );
      }
    });

    test('High-Level Anomaly Filtering Oracle: computeTrimmedAverage filters corrupt entries', () {
      final corruptQuotes = {
        'corrupt_zero': 0.0,
        'corrupt_neg': -15.0,
        'corrupt_nan': double.nan,
        'corrupt_inf': double.infinity,
        'corrupt_neg_inf': double.negativeInfinity,
        'floor_0_01': 0.01,
        'floor_0_02': 0.02,
        'floor_0_02001': 0.02001,
        'valid_single': 100.0,
      };

      final currencies = {
        for (final k in corruptQuotes.keys) k: AppCurrency.usd,
      };

      final result = TrimmedAverageCalculator.computeTrimmedAverage(
        rawQuotes: corruptQuotes,
        vendorCurrencies: currencies,
        targetCurrency: AppCurrency.usd,
      );

      // Only 'valid_single' (100.0) should survive
      expect(result, equals(100.0));
    });

    test('Multi-Currency Floor Anomaly Conversion Interaction', () {
      // 0.015 EUR in USD: 0.015 / 0.92 = 0.0163 USD <= 0.02001 -> discarded
      // 0.025 EUR in USD: 0.025 / 0.92 = 0.02717 USD > 0.02001 -> accepted
      final mixedQuotes = {
        'cheap_eur': 0.015,
        'valid_eur': 0.025,
      };
      final currencies = {
        'cheap_eur': AppCurrency.eur,
        'valid_eur': AppCurrency.eur,
      };

      final result = TrimmedAverageCalculator.computeTrimmedAverage(
        rawQuotes: mixedQuotes,
        vendorCurrencies: currencies,
        targetCurrency: AppCurrency.usd,
      );

      expect(result, closeTo(0.025 / 0.92, 1e-6));
    });

    test('All-Anomaly Dataset Oracle: Returns null without crashing', () {
      final allAnomalies = {
        'q1': 0.0,
        'q2': 0.01,
        'q3': -5.0,
        'q4': double.nan,
        'q5': 0.02,
      };
      final currencies = {
        for (final k in allAnomalies.keys) k: AppCurrency.usd,
      };

      final result = TrimmedAverageCalculator.computeTrimmedAverage(
        rawQuotes: allAnomalies,
        vendorCurrencies: currencies,
        targetCurrency: AppCurrency.usd,
      );

      expect(result, isNull);
    });
  });

  // ===========================================================================
  // 2. OUTLIER TRIMMING ACROSS SAMPLE SIZES (N=0, 1, 2, 3, 4, 5, 9, 10, 20, 100)
  // ===========================================================================
  group('Adversarial Oracle 2: Trimming Across Sample Sizes (N=0..100)', () {
    test('N = 0: Returns fallback invariant', () {
      expect(TrimmedAverageCalculator.computeTrimmedMean([], fallback: 0.0), equals(0.0));
      expect(TrimmedAverageCalculator.computeTrimmedMean([], fallback: 99.9), equals(99.9));
    });

    test('N = 1: Returns single element invariant', () {
      for (final p in [0.05, 1.25, 42.0, 1000.0, 50000.0]) {
        expect(TrimmedAverageCalculator.computeTrimmedMean([p]), equals(p));
      }
    });

    test('N = 2: Returns exact arithmetic midpoint invariant', () {
      expect(TrimmedAverageCalculator.computeTrimmedMean([10.0, 20.0]), equals(15.0));
      expect(TrimmedAverageCalculator.computeTrimmedMean([0.50, 1.50]), equals(1.00));
      expect(TrimmedAverageCalculator.computeTrimmedMean([100.0, 1000.0]), equals(550.0));
    });

    test('N = 3: Un-trimmed arithmetic mean invariant (k = 0)', () {
      // [10, 20, 30] -> (10 + 20 + 30) / 3 = 20.0
      expect(TrimmedAverageCalculator.computeTrimmedMean([10.0, 20.0, 30.0]), equals(20.0));

      // With severe outlier: [1.0, 10.0, 100.0] -> 111 / 3 = 37.0 (untrimmed for N=3)
      expect(TrimmedAverageCalculator.computeTrimmedMean([1.0, 10.0, 100.0]), equals(37.0));
    });

    test('N = 4: Un-trimmed arithmetic mean invariant (k = 0)', () {
      // [10, 20, 30, 40] -> 100 / 4 = 25.0
      expect(TrimmedAverageCalculator.computeTrimmedMean([10.0, 20.0, 30.0, 40.0]), equals(25.0));

      // [2.0, 4.0, 6.0, 8.0] -> 20 / 4 = 5.0
      expect(TrimmedAverageCalculator.computeTrimmedMean([2.0, 4.0, 6.0, 8.0]), equals(5.0));
    });

    test('N = 5: Trims 1 lowest and 1 highest (k = 1), averages middle 3', () {
      // [1.0, 10.0, 10.0, 10.0, 1000.0]
      // Trims 1.0 and 1000.0, leaves [10, 10, 10], mean = 10.0
      final result = TrimmedAverageCalculator.computeTrimmedMean([1.0, 10.0, 10.0, 10.0, 1000.0]);
      expect(result, equals(10.0));
    });

    test('N = 9: Trims 1 lowest and 1 highest (k = 1), averages middle 7', () {
      // Quotes: [0.5, 10, 11, 12, 13, 14, 15, 16, 999.0]
      // Trims 0.5 and 999.0.
      // Middle 7: [10, 11, 12, 13, 14, 15, 16], sum = 91, mean = 91 / 7 = 13.0
      final quotes = [0.5, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 999.0];
      final result = TrimmedAverageCalculator.computeTrimmedMean(quotes);
      expect(result, equals(13.0));
    });

    test('N = 10: Trims floor(0.10 * 10) = 1 from each end, averages middle 8', () {
      // Quotes: [0.1, 2, 3, 4, 5, 6, 7, 8, 9, 500.0]
      // Trims 0.1 and 500.0.
      // Middle 8: 2 + 3 + 4 + 5 + 6 + 7 + 8 + 9 = 44, mean = 44 / 8 = 5.5
      final quotes = [0.1, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 500.0];
      final result = TrimmedAverageCalculator.computeTrimmedMean(quotes);
      expect(result, equals(5.5));
    });

    test('N = 19: Trims floor(0.10 * 19) = 1 from each end, averages middle 17', () {
      // 19 quotes from 1.0 to 19.0.
      // Trims 1.0 and 19.0. Remaining 17: 2..18.
      // Sum = 170. Mean = 170 / 17 = 10.0.
      final quotes = List<double>.generate(19, (i) => (i + 1).toDouble());
      final result = TrimmedAverageCalculator.computeTrimmedMean(quotes);
      expect(result, equals(10.0));
    });

    test('N = 20: Trims floor(0.10 * 20) = 2 from each end, averages middle 16', () {
      // 20 quotes from 1.0 to 20.0.
      // Trims lowest 2 (1, 2) and highest 2 (19, 20).
      // Remaining 16: 3..18. Sum(3..18) = 168. Mean = 168 / 16 = 10.5.
      final quotes = List<double>.generate(20, (i) => (i + 1).toDouble());
      final result = TrimmedAverageCalculator.computeTrimmedMean(quotes);
      expect(result, equals(10.5));
    });

    test('N = 100: Trims floor(0.10 * 100) = 10 from each end, averages middle 80', () {
      // 100 quotes: 10 extreme low (0.05), 80 normal (50.0), 10 extreme high (10000.0)
      final quotes = <double>[
        ...List.filled(10, 0.05),
        ...List.filled(80, 50.0),
        ...List.filled(10, 10000.0),
      ];

      final result = TrimmedAverageCalculator.computeTrimmedMean(quotes);
      expect(result, equals(50.0));
    });

    test('Mathematical Invariant: Identical quotes always return exact quote value for any N', () {
      for (final n in [1, 2, 3, 4, 5, 9, 10, 20, 50, 100]) {
        for (final p in [0.03, 1.0, 25.5, 99.99, 1000.0]) {
          final quotes = List<double>.filled(n, p);
          expect(
            TrimmedAverageCalculator.computeTrimmedMean(quotes),
            closeTo(p, 1e-9),
            reason: 'Identical quotes of $p with N=$n must yield $p',
          );
        }
      }
    });

    test('Mathematical Invariant: Permutation Invariance (Order Independence)', () {
      final base = [0.05, 12.0, 14.5, 16.0, 18.0, 20.0, 22.0, 24.0, 26.0, 950.0];
      final oracleMean = TrimmedAverageCalculator.computeTrimmedMean(base);

      final rng = Random(12345);
      for (int i = 0; i < 20; i++) {
        final shuffled = List<double>.of(base)..shuffle(rng);
        expect(
          TrimmedAverageCalculator.computeTrimmedMean(shuffled),
          closeTo(oracleMean, 1e-9),
          reason: 'Permutation should not change trimmed mean',
        );
      }
    });
  });

  // ===========================================================================
  // 3. SYMMETRICAL TRIMMING ACCURACY WITH EXTREME OUTLIERS
  // ===========================================================================
  group('Adversarial Oracle 3: Symmetrical Trimming with Extreme Outliers', () {
    test(r'Extreme Bilateral Outliers: $0.03 vs $1,000,000.00 on N = 5', () {
      // 5 quotes: [0.03, 25.0, 25.0, 25.0, 1000000.0]
      // 0.03 is > 0.02001 so it is a valid quote, not a floor anomaly.
      // Symmetrical trimming must eliminate BOTH 0.03 and 1,000,000.00.
      final quotes = [0.03, 25.0, 25.0, 25.0, 1000000.0];
      final result = TrimmedAverageCalculator.computeTrimmedMean(quotes);

      expect(
        result,
        equals(25.0),
        reason: 'Symmetrical trimming on N=5 must discard both 0.03 and 1,000,000.00, yielding exactly 25.0',
      );
    });

    test(r'Extreme Bilateral Multi-Outliers: 2 low ($0.03, $0.04) and 2 high ($500k, $1M) on N = 20', () {
      final quotes = <double>[
        0.03,
        0.04,
        ...List.filled(16, 75.0),
        500000.0,
        1000000.0,
      ];

      // N=20 -> k = floor(0.10 * 20) = 2.
      // Discards the 2 lowest (0.03, 0.04) and the 2 highest (500k, 1M).
      // Remaining 16 quotes are all 75.0 -> mean must strictly be 75.0.
      final result = TrimmedAverageCalculator.computeTrimmedMean(quotes);
      expect(result, equals(75.0));
    });

    test('Extreme Asymmetric Outlier Defense on N = 5', () {
      // Single massive spike: [10.0, 10.0, 10.0, 10.0, 10000000.0]
      // Trims one 10.0 from bottom and 10,000,000.0 from top.
      // Remaining three are 10.0 -> average = 10.0.
      final quotes = [10.0, 10.0, 10.0, 10.0, 10000000.0];
      final result = TrimmedAverageCalculator.computeTrimmedMean(quotes);
      expect(result, equals(10.0));
    });
  });

  // ===========================================================================
  // 4. MULTI-CURRENCY NORMALIZATION ACROSS USD, EUR, GBP, CAD
  // ===========================================================================
  group('Adversarial Oracle 4: Multi-Currency Normalization Invariants', () {
    test('All 16 Pairwise Currency Combinations Invariant', () {
      const currencies = AppCurrency.values;
      const baseAmount = 100.0;

      for (final from in currencies) {
        for (final to in currencies) {
          final rate = ExchangeRateService.getRate(from: from, to: to);
          final converted = ExchangeRateService.convert(baseAmount, from: from, to: to);

          expect(rate, greaterThan(0.0));
          expect(rate.isFinite, isTrue);
          expect(converted, equals(baseAmount * rate));

          if (from == to) {
            expect(rate, equals(1.0));
            expect(converted, equals(baseAmount));
          } else {
            // Inverse rate consistency: rate(A->B) * rate(B->A) == 1.0
            final inverseRate = ExchangeRateService.getRate(from: to, to: from);
            expect(rate * inverseRate, closeTo(1.0, 1e-12));
          }
        }
      }
    });

    test('Harmonized Multi-Vendor Conversion: 5 vendors in 4 currencies normalize identically', () {
      // Based on baseline rates:
      // USD: 1.0000
      // EUR: 0.9200
      // GBP: 0.7850
      // CAD: 1.3600
      final rawQuotes = {
        'tcgplayer': 100.0, // USD
        'cardmarket': 92.0, // EUR (= 100 USD)
        'ebay': 100.0, // USD
        'magicmadhouse': 78.50, // GBP (= 100 USD)
        'face2face': 136.0, // CAD (= 100 USD)
      };

      final vendorCurrencies = {
        'tcgplayer': AppCurrency.usd,
        'cardmarket': AppCurrency.eur,
        'ebay': AppCurrency.usd,
        'magicmadhouse': AppCurrency.gbp,
        'face2face': AppCurrency.cad,
      };

      // 1. Target USD
      final avgUsd = TrimmedAverageCalculator.computeTrimmedAverage(
        rawQuotes: rawQuotes,
        vendorCurrencies: vendorCurrencies,
        targetCurrency: AppCurrency.usd,
      );
      expect(avgUsd, closeTo(100.0, 1e-4));

      // 2. Target EUR
      final avgEur = TrimmedAverageCalculator.computeTrimmedAverage(
        rawQuotes: rawQuotes,
        vendorCurrencies: vendorCurrencies,
        targetCurrency: AppCurrency.eur,
      );
      expect(avgEur, closeTo(92.0, 1e-4));

      // 3. Target GBP
      final avgGbp = TrimmedAverageCalculator.computeTrimmedAverage(
        rawQuotes: rawQuotes,
        vendorCurrencies: vendorCurrencies,
        targetCurrency: AppCurrency.gbp,
      );
      expect(avgGbp, closeTo(78.50, 1e-4));

      // 4. Target CAD
      final avgCad = TrimmedAverageCalculator.computeTrimmedAverage(
        rawQuotes: rawQuotes,
        vendorCurrencies: vendorCurrencies,
        targetCurrency: AppCurrency.cad,
      );
      expect(avgCad, closeTo(136.0, 1e-4));
    });

    test('Non-Finite and Negative Currency Inputs Handled Defensively', () {
      expect(ExchangeRateService.convert(-100.0, from: AppCurrency.usd, to: AppCurrency.eur), equals(0.0));
      expect(ExchangeRateService.convert(0.0, from: AppCurrency.usd, to: AppCurrency.eur), equals(0.0));
      expect(ExchangeRateService.convert(double.nan, from: AppCurrency.usd, to: AppCurrency.eur), equals(0.0));
      expect(ExchangeRateService.convert(double.infinity, from: AppCurrency.usd, to: AppCurrency.eur), equals(0.0));
      expect(ExchangeRateService.convert(double.negativeInfinity, from: AppCurrency.usd, to: AppCurrency.eur), equals(0.0));
    });
  });

  // ===========================================================================
  // 5. PnL CALCULATIONS & STRESS ORACLES
  // ===========================================================================
  group('Adversarial Oracle 5: PnL Calculations & Edge Cases', () {
    test('Zero Cost Basis Defense: percentageReturn is strictly 0.0% and no NaN/Inf', () {
      final pnl = PnLResult.calculate(
        costBasisPerUnit: 0.0,
        marketPricePerUnit: 250.0,
        quantity: 1,
        currency: AppCurrency.usd,
      );

      expect(pnl.costBasis, equals(0.0));
      expect(pnl.marketValue, equals(250.0));
      expect(pnl.dollarReturn, equals(250.0));
      expect(pnl.percentageReturn, equals(0.0));
      expect(pnl.percentageReturn.isNaN, isFalse);
      expect(pnl.percentageReturn.isInfinite, isFalse);
      expect(pnl.isProfit, isTrue);
      expect(pnl.isLoss, isFalse);
      expect(pnl.isNeutral, isFalse);
      expect(pnl.formatReturn(isPrivacyMode: false), equals(r'+$250.00 (+0.0%)'));
    });

    test('Negative Purchase Price Defense: Clamped to 0.0 without crash or inverted returns', () {
      final pnl = PnLResult.calculate(
        costBasisPerUnit: -50.0,
        marketPricePerUnit: 100.0,
        quantity: 1,
        currency: AppCurrency.usd,
      );

      expect(pnl.costBasis, equals(0.0));
      expect(pnl.unitCostBasis, equals(0.0));
      expect(pnl.marketValue, equals(100.0));
      expect(pnl.dollarReturn, equals(100.0));
      expect(pnl.percentageReturn, equals(0.0));
      expect(pnl.isProfit, isTrue);
    });

    test('Negative Market Price Defense: Clamped to 0.0', () {
      final pnl = PnLResult.calculate(
        costBasisPerUnit: 50.0,
        marketPricePerUnit: -100.0,
        quantity: 1,
        currency: AppCurrency.usd,
      );

      expect(pnl.unitMarketPrice, equals(0.0));
      expect(pnl.marketValue, equals(0.0));
      expect(pnl.dollarReturn, equals(-50.0));
      expect(pnl.percentageReturn, equals(-100.0));
      expect(pnl.isProfit, isFalse);
      expect(pnl.isLoss, isTrue);
    });

    test('Huge Profit Return: Multi-million dollar return handles formatting cleanly', () {
      final pnl = PnLResult.calculate(
        costBasisPerUnit: 0.01,
        marketPricePerUnit: 1000000.0,
        quantity: 1,
        currency: AppCurrency.usd,
      );

      expect(pnl.dollarReturn, equals(999999.99));
      expect(pnl.percentageReturn, closeTo(9999999900.0, 1.0));
      expect(pnl.isProfit, isTrue);

      final formatted = pnl.formatReturn(isPrivacyMode: false);
      expect(formatted, contains(r'+$999999.99'));
      expect(formatted, contains('%'));
      expect(formatted.contains('NaN'), isFalse);
      expect(formatted.contains('Infinity'), isFalse);
    });

    test('Complete Loss Return: 100% loss', () {
      final pnl = PnLResult.calculate(
        costBasisPerUnit: 100.0,
        marketPricePerUnit: 0.0,
        quantity: 5,
        currency: AppCurrency.usd,
      );

      expect(pnl.costBasis, equals(500.0));
      expect(pnl.marketValue, equals(0.0));
      expect(pnl.dollarReturn, equals(-500.0));
      expect(pnl.percentageReturn, equals(-100.0));
      expect(pnl.isLoss, isTrue);
      expect(pnl.formatReturn(isPrivacyMode: false), equals(r'-$500.00 (-100.0%)'));
    });

    test('Quantity Scaling Invariant: Percentage return is invariant to quantity for Q >= 1', () {
      const unitCost = 25.0;
      const unitMarket = 75.0;

      final pnlUnit = PnLResult.calculate(
        costBasisPerUnit: unitCost,
        marketPricePerUnit: unitMarket,
        quantity: 1,
        currency: AppCurrency.usd,
      );

      for (final q in [1, 2, 5, 10, 100, 10000]) {
        final pnlQ = PnLResult.calculate(
          costBasisPerUnit: unitCost,
          marketPricePerUnit: unitMarket,
          quantity: q,
          currency: AppCurrency.usd,
        );

        expect(
          pnlQ.percentageReturn,
          equals(pnlUnit.percentageReturn),
          reason: 'Percentage return must be invariant across quantity ($q)',
        );
        expect(pnlQ.costBasis, equals(unitCost * q));
        expect(pnlQ.marketValue, equals(unitMarket * q));
        expect(pnlQ.dollarReturn, equals(pnlUnit.dollarReturn * q));
      }
    });

    test('Non-Positive Quantity Defense: Quantity <= 0 defaults to 1', () {
      final pnlZeroQty = PnLResult.calculate(
        costBasisPerUnit: 10.0,
        marketPricePerUnit: 20.0,
        quantity: 0,
        currency: AppCurrency.usd,
      );
      expect(pnlZeroQty.quantity, equals(1));
      expect(pnlZeroQty.costBasis, equals(10.0));

      final pnlNegQty = PnLResult.calculate(
        costBasisPerUnit: 10.0,
        marketPricePerUnit: 20.0,
        quantity: -5,
        currency: AppCurrency.usd,
      );
      expect(pnlNegQty.quantity, equals(1));
    });
  });

  // ===========================================================================
  // 6. 52-WEEK RANGE BAR DEFENSES
  // ===========================================================================
  group('Adversarial Oracle 6: 52-Week Range Bar Defenses', () {
    test('Anomaly Defense: low > high automatically rectifies and prevents negative span', () {
      // low = 50.0, high = 20.0 (corrupt inverted range)
      final range = FiftyTwoWeekRange.calculate(
        low52: 50.0,
        high52: 20.0,
        currentPrice: 35.0,
        currency: AppCurrency.usd,
      );

      // cleanHigh is clamped to cleanLow (50.0)
      expect(range.low52, equals(50.0));
      expect(range.high52, equals(50.0));
      // rangeSpan becomes 0.0 -> returns neutral midpoint 0.5
      expect(range.rangePosition, equals(0.5));
      expect(range.percentileLabel, equals('50%'));
    });

    test('Zero-Span Defense: low == high == current sets neutral 0.5 position', () {
      final range = FiftyTwoWeekRange.calculate(
        low52: 42.0,
        high52: 42.0,
        currentPrice: 42.0,
        currency: AppCurrency.usd,
      );

      expect(range.rangePosition, equals(0.5));
      expect(range.percentileLabel, equals('50%'));
      expect(range.rangePosition.isNaN, isFalse);
      expect(range.rangePosition.isInfinite, isFalse);
    });

    test('Boundary Clamping: currentPrice outside [low52, high52] clamped strictly to [0.0..1.0]', () {
      // Current below low
      final below = FiftyTwoWeekRange.calculate(
        low52: 20.0,
        high52: 80.0,
        currentPrice: 5.0,
        currency: AppCurrency.usd,
      );
      expect(below.rangePosition, equals(0.0));
      expect(below.percentileLabel, equals('0%'));

      // Current above high
      final above = FiftyTwoWeekRange.calculate(
        low52: 20.0,
        high52: 80.0,
        currentPrice: 150.0,
        currency: AppCurrency.usd,
      );
      expect(above.rangePosition, equals(1.0));
      expect(above.percentileLabel, equals('100%'));
    });

    test('Non-Finite Inputs Defense: NaN and Inf sanitized', () {
      final range = FiftyTwoWeekRange.calculate(
        low52: double.nan,
        high52: double.infinity,
        currentPrice: double.negativeInfinity,
        currency: AppCurrency.usd,
      );

      expect(range.low52, equals(0.0));
      expect(range.high52, equals(0.0));
      expect(range.currentPrice, equals(0.0));
      expect(range.rangePosition, equals(0.5));
      expect(range.percentileLabel, equals('50%'));
    });

    testWidgets('Widget Rendering Oracle: FiftyTwoWeekRangeBar with low > high anomaly', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: FiftyTwoWeekRangeBar(
                low52: 100.0,
                high52: 20.0, // inverted
                currentPrice: 50.0,
                currency: AppCurrency.usd,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('fifty_two_week_range_bar')), findsOneWidget);
      expect(find.byKey(const Key('range_slider_thumb')), findsOneWidget);
      expect(find.text('50% of Range'), findsOneWidget);
    });
  });

  // ===========================================================================
  // 7. LIQUIDITY HAIRCUTS & TIERED RATIO BOUNDARIES
  // ===========================================================================
  group('Adversarial Oracle 7: Liquidity Haircuts Tiered Ratio Boundaries', () {
    // Tiers:
    // P >= 50.00 -> 70% (High liquidity)
    // 10.00 <= P < 50.00 -> 60% (High liquidity if P >= 5.0)
    // 2.00 <= P < 10.00 -> 45% (High if P >= 5.0, Moderate if 2.0 <= P < 5.0)
    // P < 2.00 -> 25% (Low liquidity)

    test(r'Boundary: $50.00 exact vs $49.99', () {
      // 50.00 -> 70% ratio
      final at50 = LiquidityAnalysis.calculate(
        marketPrice: 50.00,
        currency: AppCurrency.usd,
      );
      expect(at50.replacementValue, equals(50.00));
      expect(at50.cashOutValue, closeTo(35.00, 1e-4));
      expect(at50.realizationRate, closeTo(70.0, 1e-4));
      expect(at50.liquidityTag, equals(LiquidityTag.high));

      // 49.99 -> 60% ratio
      final below50 = LiquidityAnalysis.calculate(
        marketPrice: 49.99,
        currency: AppCurrency.usd,
      );
      expect(below50.replacementValue, equals(49.99));
      expect(below50.cashOutValue, closeTo(29.994, 1e-4));
      expect(below50.realizationRate, closeTo(60.0, 1e-4));
      expect(below50.liquidityTag, equals(LiquidityTag.high));
    });

    test(r'Boundary: $10.00 exact vs $9.99', () {
      // 10.00 -> 60% ratio
      final at10 = LiquidityAnalysis.calculate(
        marketPrice: 10.00,
        currency: AppCurrency.usd,
      );
      expect(at10.replacementValue, equals(10.00));
      expect(at10.cashOutValue, closeTo(6.00, 1e-4));
      expect(at10.realizationRate, closeTo(60.0, 1e-4));
      expect(at10.liquidityTag, equals(LiquidityTag.high));

      // 9.99 -> 45% ratio, High tag (>= 5.0)
      final below10 = LiquidityAnalysis.calculate(
        marketPrice: 9.99,
        currency: AppCurrency.usd,
      );
      expect(below10.replacementValue, equals(9.99));
      expect(below10.cashOutValue, closeTo(4.4955, 1e-4));
      expect(below10.realizationRate, closeTo(45.0, 1e-4));
      expect(below10.liquidityTag, equals(LiquidityTag.high));
    });

    test(r'Boundary: $5.00 exact vs $4.99 (Tag Transition)', () {
      // 5.00 -> 45% ratio, HIGH tag
      final at5 = LiquidityAnalysis.calculate(
        marketPrice: 5.00,
        currency: AppCurrency.usd,
      );
      expect(at5.liquidityTag, equals(LiquidityTag.high));
      expect(at5.realizationRate, closeTo(45.0, 1e-4));

      // 4.99 -> 45% ratio, MODERATE tag
      final below5 = LiquidityAnalysis.calculate(
        marketPrice: 4.99,
        currency: AppCurrency.usd,
      );
      expect(below5.liquidityTag, equals(LiquidityTag.moderate));
      expect(below5.realizationRate, closeTo(45.0, 1e-4));
    });

    test(r'Boundary: $2.00 exact vs $1.99', () {
      // 2.00 -> 45% ratio, MODERATE tag
      final at2 = LiquidityAnalysis.calculate(
        marketPrice: 2.00,
        currency: AppCurrency.usd,
      );
      expect(at2.replacementValue, equals(2.00));
      expect(at2.cashOutValue, closeTo(0.90, 1e-4));
      expect(at2.realizationRate, closeTo(45.0, 1e-4));
      expect(at2.liquidityTag, equals(LiquidityTag.moderate));

      // 1.99 -> 25% ratio, LOW tag
      final below2 = LiquidityAnalysis.calculate(
        marketPrice: 1.99,
        currency: AppCurrency.usd,
      );
      expect(below2.replacementValue, equals(1.99));
      expect(below2.cashOutValue, closeTo(0.4975, 1e-4));
      expect(below2.realizationRate, closeTo(25.0, 1e-4));
      expect(below2.liquidityTag, equals(LiquidityTag.low));
    });

    test(r'Bulk Boundary: $0.05 and $0.00 Zero Price Defense', () {
      final penny = LiquidityAnalysis.calculate(
        marketPrice: 0.05,
        currency: AppCurrency.usd,
      );
      expect(penny.cashOutValue, closeTo(0.0125, 1e-4));
      expect(penny.realizationRate, closeTo(25.0, 1e-4));
      expect(penny.liquidityTag, equals(LiquidityTag.low));

      final zero = LiquidityAnalysis.calculate(
        marketPrice: 0.0,
        currency: AppCurrency.usd,
      );
      expect(zero.replacementValue, equals(0.0));
      expect(zero.cashOutValue, equals(0.0));
      expect(zero.realizationRate, equals(0.0));
      expect(zero.realizationRate.isNaN, isFalse);
      expect(zero.liquidityTag, equals(LiquidityTag.low));
    });

    test('Explicit Buylist Price Edge Cases', () {
      // Buylist above retail (e.g. hot spike buylist arbitrage)
      final hotCard = LiquidityAnalysis.calculate(
        marketPrice: 100.0,
        explicitBuylistPrice: 120.0,
        currency: AppCurrency.usd,
      );
      expect(hotCard.cashOutValue, equals(120.0));
      expect(hotCard.realizationRate, equals(120.0));

      // Explicit buylist <= 0 -> falls back to tiered ratio haircut
      final zeroBuylist = LiquidityAnalysis.calculate(
        marketPrice: 100.0,
        explicitBuylistPrice: 0.0,
        currency: AppCurrency.usd,
      );
      expect(zeroBuylist.cashOutValue, equals(70.0)); // 70% haircut
      expect(zeroBuylist.realizationRate, equals(70.0));
    });
  });

  // ===========================================================================
  // 8. ADVERSARIAL MONTE CARLO FUZZING & PROPERTY HARNESS (1,000 ITERATIONS)
  // ===========================================================================
  group('Adversarial Oracle 8: Monte Carlo Fuzzing & Invariant Suite', () {
    test('Monte Carlo Fuzz Harness: 1,000 randomized TrimmedAverage calculations never violate invariants', () {
      final rng = Random(8888);
      const iterations = 1000;
      final currencies = AppCurrency.values;

      for (int i = 0; i < iterations; i++) {
        final sampleSize = rng.nextInt(35); // 0 to 34 quotes
        final targetCurrency = currencies[rng.nextInt(currencies.length)];

        final quotes = <String, double>{};
        final vendorCurrencies = <String, AppCurrency>{};

        for (int q = 0; q < sampleSize; q++) {
          final vendor = 'vendor_$q';
          vendorCurrencies[vendor] = currencies[rng.nextInt(currencies.length)];

          // Inject edge cases: zero, neg, nan, inf, micro, normal, huge
          final kind = rng.nextInt(7);
          switch (kind) {
            case 0:
              quotes[vendor] = 0.0;
              break;
            case 1:
              quotes[vendor] = -rng.nextDouble() * 100.0;
              break;
            case 2:
              quotes[vendor] = double.nan;
              break;
            case 3:
              quotes[vendor] = rng.nextBool() ? double.infinity : double.negativeInfinity;
              break;
            case 4:
              quotes[vendor] = rng.nextDouble() * 0.02; // floor anomaly
              break;
            case 5:
              quotes[vendor] = 0.021 + rng.nextDouble() * 1000.0; // valid
              break;
            case 6:
              quotes[vendor] = 10000.0 + rng.nextDouble() * 1000000.0; // extreme high
              break;
          }
        }

        final result = TrimmedAverageCalculator.computeTrimmedAverage(
          rawQuotes: quotes,
          vendorCurrencies: vendorCurrencies,
          targetCurrency: targetCurrency,
        );

        if (result != null) {
          expect(result.isFinite, isTrue);
          expect(result.isNaN, isFalse);
          expect(
            result,
            greaterThan(0.02001),
            reason: 'Surviving trimmed average must strictly exceed floor threshold',
          );
        }
      }
    });

    test('Monte Carlo Fuzz Harness: 1,000 randomized PnL computations satisfy finite bounds', () {
      final rng = Random(7777);
      const iterations = 1000;
      final currencies = AppCurrency.values;

      for (int i = 0; i < iterations; i++) {
        final currency = currencies[rng.nextInt(currencies.length)];
        final cost = (rng.nextDouble() * 2000.0) - 200.0; // may be negative
        final market = (rng.nextDouble() * 2000.0) - 100.0;
        final qty = rng.nextInt(20) - 5; // may be non-positive

        final pnl = PnLResult.calculate(
          costBasisPerUnit: cost,
          marketPricePerUnit: market,
          quantity: qty,
          currency: currency,
        );

        expect(pnl.costBasis.isFinite, isTrue);
        expect(pnl.marketValue.isFinite, isTrue);
        expect(pnl.dollarReturn.isFinite, isTrue);
        expect(pnl.percentageReturn.isFinite, isTrue);
        expect(pnl.percentageReturn.isNaN, isFalse);
        expect(pnl.quantity, greaterThanOrEqualTo(1));

        final formatted = pnl.formatReturn(isPrivacyMode: rng.nextBool());
        expect(formatted, isNotEmpty);
        expect(formatted.contains('NaN'), isFalse);
        expect(formatted.contains('Infinity'), isFalse);
      }
    });

    test('Monte Carlo Fuzz Harness: 1,000 randomized 52W range calculations strictly stay in [0.0..1.0]', () {
      final rng = Random(6666);
      const iterations = 1000;
      final currencies = AppCurrency.values;

      for (int i = 0; i < iterations; i++) {
        final currency = currencies[rng.nextInt(currencies.length)];
        final low = (rng.nextDouble() * 500.0) - 50.0;
        final high = (rng.nextDouble() * 500.0) - 50.0;
        final current = (rng.nextDouble() * 500.0) - 50.0;

        final range = FiftyTwoWeekRange.calculate(
          low52: low,
          high52: high,
          currentPrice: current,
          currency: currency,
        );

        expect(range.rangePosition, greaterThanOrEqualTo(0.0));
        expect(range.rangePosition, lessThanOrEqualTo(1.0));
        expect(range.rangePosition.isNaN, isFalse);
        expect(range.low52, lessThanOrEqualTo(range.high52));
        expect(range.percentileLabel, isNotEmpty);
      }
    });

    test('Monte Carlo Fuzz Harness: 1,000 randomized LiquidityAnalysis calculations satisfy invariant properties', () {
      final rng = Random(5555);
      const iterations = 1000;
      final currencies = AppCurrency.values;

      for (int i = 0; i < iterations; i++) {
        final currency = currencies[rng.nextInt(currencies.length)];
        final price = (rng.nextDouble() * 500.0) - 20.0;
        final buylist = rng.nextBool() ? ((rng.nextDouble() * 500.0) - 10.0) : null;
        final qty = rng.nextInt(10) - 2;

        final analysis = LiquidityAnalysis.calculate(
          marketPrice: price,
          explicitBuylistPrice: buylist,
          quantity: qty,
          currency: currency,
          isReservedList: rng.nextBool(),
        );

        expect(analysis.replacementValue.isFinite, isTrue);
        expect(analysis.cashOutValue.isFinite, isTrue);
        expect(analysis.realizationRate.isFinite, isTrue);
        expect(analysis.realizationRate.isNaN, isFalse);
        expect(analysis.replacementValue, greaterThanOrEqualTo(0.0));
        expect(analysis.cashOutValue, greaterThanOrEqualTo(0.0));
      }
    });
  });
}
