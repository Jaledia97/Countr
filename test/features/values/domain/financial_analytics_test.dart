import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/state/settings_state.dart';
import 'package:countr/features/values/domain/models/financial_analytics.dart';
import 'package:countr/features/values/domain/models/market_price_quote.dart';

void main() {
  group('PnLResult Financial Analytics', () {
    test('PNL-1.1: Calculates profit accurately with positive dollar and percentage returns', () {
      final pnl = PnLResult.calculate(
        costBasisPerUnit: 10.0,
        marketPricePerUnit: 15.0,
        quantity: 2,
        currency: AppCurrency.usd,
      );

      expect(pnl.costBasis, 20.0);
      expect(pnl.marketValue, 30.0);
      expect(pnl.dollarReturn, 10.0);
      expect(pnl.percentageReturn, 50.0);
      expect(pnl.isProfit, isTrue);
      expect(pnl.isLoss, isFalse);
      expect(pnl.isNeutral, isFalse);
    });

    test('PNL-1.2: Calculates loss accurately with negative dollar and percentage returns', () {
      final pnl = PnLResult.calculate(
        costBasisPerUnit: 20.0,
        marketPricePerUnit: 15.0,
        quantity: 1,
        currency: AppCurrency.usd,
      );

      expect(pnl.costBasis, 20.0);
      expect(pnl.marketValue, 15.0);
      expect(pnl.dollarReturn, -5.0);
      expect(pnl.percentageReturn, -25.0);
      expect(pnl.isProfit, isFalse);
      expect(pnl.isLoss, isTrue);
      expect(pnl.isNeutral, isFalse);
    });

    test('PNL-1.3: Handles break-even neutral return', () {
      final pnl = PnLResult.calculate(
        costBasisPerUnit: 25.0,
        marketPricePerUnit: 25.0,
        quantity: 3,
        currency: AppCurrency.usd,
      );

      expect(pnl.dollarReturn, 0.0);
      expect(pnl.percentageReturn, 0.0);
      expect(pnl.isProfit, isFalse);
      expect(pnl.isLoss, isFalse);
      expect(pnl.isNeutral, isTrue);
    });

    test('PNL-1.4: Zero cost basis defense prevents division-by-zero and sets percentage to 0.0%', () {
      final pnl = PnLResult.calculate(
        costBasisPerUnit: 0.0,
        marketPricePerUnit: 50.0,
        quantity: 1,
        currency: AppCurrency.usd,
      );

      expect(pnl.costBasis, 0.0);
      expect(pnl.marketValue, 50.0);
      expect(pnl.dollarReturn, 50.0);
      expect(pnl.percentageReturn, 0.0);
      expect(pnl.percentageReturn.isNaN, isFalse);
      expect(pnl.percentageReturn.isInfinite, isFalse);
    });

    test('PNL-1.5: JSON round-trip serialization and deserialization', () {
      final original = PnLResult.calculate(
        costBasisPerUnit: 12.0,
        marketPricePerUnit: 18.0,
        quantity: 4,
        currency: AppCurrency.eur,
      );

      final json = original.toJson();
      final revived = PnLResult.fromJson(json);

      expect(revived, equals(original));
      expect(revived.currency, AppCurrency.eur);
      expect(revived.dollarReturn, 24.0);
    });

    test('PNL-1.6: formatReturn respects privacy mode and layout ordering', () {
      final pnl = PnLResult.calculate(
        costBasisPerUnit: 10.0,
        marketPricePerUnit: 15.0,
        quantity: 1,
        currency: AppCurrency.usd,
      );

      expect(pnl.formatReturn(isPrivacyMode: true), '****');
      expect(pnl.formatReturn(isPrivacyMode: false, amountFirst: true), r'+$5.00 (+50.0%)');
      expect(pnl.formatReturn(isPrivacyMode: false, amountFirst: false), r'+50.0% (+$5.00)');
    });
  });

  group('FiftyTwoWeekRange Financial Analytics', () {
    test('52W-2.1: Normalized position computation within standard bounds', () {
      final range = FiftyTwoWeekRange.calculate(
        low52: 10.0,
        high52: 20.0,
        currentPrice: 15.0,
        currency: AppCurrency.usd,
      );

      expect(range.rangePosition, 0.5);
      expect(range.percentileLabel, '50%');
    });

    test('52W-2.2: Clamps current price at boundaries', () {
      final lowRange = FiftyTwoWeekRange.calculate(
        low52: 10.0,
        high52: 20.0,
        currentPrice: 5.0, // below low
        currency: AppCurrency.usd,
      );
      expect(lowRange.rangePosition, 0.0);
      expect(lowRange.percentileLabel, '0%');

      final highRange = FiftyTwoWeekRange.calculate(
        low52: 10.0,
        high52: 20.0,
        currentPrice: 30.0, // above high
        currency: AppCurrency.usd,
      );
      expect(highRange.rangePosition, 1.0);
      expect(highRange.percentileLabel, '100%');
    });

    test('52W-2.3: Zero-span defense sets neutral 0.5 position when high equals low', () {
      final zeroSpan = FiftyTwoWeekRange.calculate(
        low52: 15.0,
        high52: 15.0,
        currentPrice: 15.0,
        currency: AppCurrency.usd,
      );

      expect(zeroSpan.rangePosition, 0.5);
      expect(zeroSpan.percentileLabel, '50%');
    });

    test('52W-2.4: JSON round-trip serialization and deserialization', () {
      final original = FiftyTwoWeekRange.calculate(
        low52: 20.0,
        high52: 100.0,
        currentPrice: 80.0,
        currency: AppCurrency.gbp,
      );

      final json = original.toJson();
      final revived = FiftyTwoWeekRange.fromJson(json);

      expect(revived, equals(original));
      expect(revived.currency, AppCurrency.gbp);
      expect(revived.rangePosition, 0.75);
    });
  });

  group('LiquidityAnalysis Financial Analytics', () {
    test(r'LIQ-3.1: Premium staple tier (>= $50.00) applies 70% buylist haircut and high liquidity', () {
      final analysis = LiquidityAnalysis.calculate(
        marketPrice: 100.0,
        quantity: 1,
        currency: AppCurrency.usd,
      );

      expect(analysis.replacementValue, 100.0);
      expect(analysis.cashOutValue, 70.0);
      expect(analysis.realizationRate, 70.0);
      expect(analysis.liquidityTag, LiquidityTag.high);
      expect(analysis.isReservedList, isFalse);
    });

    test(r'LIQ-3.2: Mid-tier ($10.00 <= P < $50.00) applies 60% buylist haircut', () {
      final analysis = LiquidityAnalysis.calculate(
        marketPrice: 20.0,
        quantity: 1,
        currency: AppCurrency.usd,
      );

      expect(analysis.replacementValue, 20.0);
      expect(analysis.cashOutValue, 12.0);
      expect(analysis.realizationRate, 60.0);
      expect(analysis.liquidityTag, LiquidityTag.high);
    });

    test(r'LIQ-3.3: Low-tier ($2.00 <= P < $10.00) applies 45% haircut and moderate liquidity', () {
      final analysis = LiquidityAnalysis.calculate(
        marketPrice: 4.0,
        quantity: 2,
        currency: AppCurrency.usd,
      );

      expect(analysis.replacementValue, 8.0);
      expect(analysis.cashOutValue, closeTo(3.6, 0.001));
      expect(analysis.realizationRate, 45.0);
      expect(analysis.liquidityTag, LiquidityTag.moderate);
    });

    test(r'LIQ-3.4: Bulk tier (< $2.00) applies 25% haircut and low liquidity', () {
      final analysis = LiquidityAnalysis.calculate(
        marketPrice: 1.0,
        quantity: 1,
        currency: AppCurrency.usd,
      );

      expect(analysis.replacementValue, 1.0);
      expect(analysis.cashOutValue, 0.25);
      expect(analysis.realizationRate, 25.0);
      expect(analysis.liquidityTag, LiquidityTag.low);
    });

    test('LIQ-3.5: Explicit buylist price overrides heuristic ratio', () {
      final analysis = LiquidityAnalysis.calculate(
        marketPrice: 100.0,
        explicitBuylistPrice: 85.0,
        quantity: 1,
        currency: AppCurrency.usd,
      );

      expect(analysis.cashOutValue, 85.0);
      expect(analysis.realizationRate, 85.0);
    });

    test('LIQ-3.6: Reserved list flag is preserved across calculations and JSON serialization', () {
      final analysis = LiquidityAnalysis.calculate(
        marketPrice: 500.0,
        quantity: 1,
        isReservedList: true,
        currency: AppCurrency.usd,
      );

      expect(analysis.isReservedList, isTrue);

      final json = analysis.toJson();
      final revived = LiquidityAnalysis.fromJson(json);

      expect(revived.isReservedList, isTrue);
      expect(revived.liquidityTag, LiquidityTag.high);
    });
  });

  group('ConditionTreatmentMatrix Financial Analytics', () {
    test('MAT-4.1: Computes full 3x3 pricing grid from baseline NM non-foil', () {
      final matrix = ConditionTreatmentMatrix.compute(
        baseNonFoil: 100.0,
        baseFoil: 150.0,
        baseEtched: 180.0,
        currency: AppCurrency.usd,
      );

      // NM
      expect(matrix.getPrice('NM', 'non_foil'), 100.0);
      expect(matrix.getPrice('NM', 'foil'), 150.0);
      expect(matrix.getPrice('NM', 'etched'), 180.0);

      // LP (88% non-foil, 85% foil/etched)
      expect(matrix.getPrice('LP', 'non_foil'), 88.0);
      expect(matrix.getPrice('LP', 'foil'), 127.5);
      expect(matrix.getPrice('LP', 'etched'), 153.0);

      // MP (72% non-foil, 70% foil/etched)
      expect(matrix.getPrice('MP', 'non_foil'), 72.0);
      expect(matrix.getPrice('MP', 'foil'), 105.0);
      expect(matrix.getPrice('MP', 'etched'), closeTo(126.0, 0.001));
    });

    test('MAT-4.2: Computes automatic fallback foil and etched multipliers when unprovided', () {
      final matrix = ConditionTreatmentMatrix.compute(
        baseNonFoil: 10.0,
        baseFoil: 0.0,
        baseEtched: 0.0,
        currency: AppCurrency.usd,
      );

      // Foil defaults to 1.4x (14.0), etched defaults to foil * 1.1x (15.4)
      expect(matrix.getPrice('NM', 'non_foil'), 10.0);
      expect(matrix.getPrice('NM', 'foil'), 14.0);
      expect(matrix.getPrice('NM', 'etched'), closeTo(15.4, 0.001));
    });

    test('MAT-4.3: JSON round-trip serialization and deserialization', () {
      final original = ConditionTreatmentMatrix.compute(
        baseNonFoil: 25.0,
        baseFoil: 40.0,
        baseEtched: 50.0,
        currency: AppCurrency.cad,
      );

      final json = original.toJson();
      final revived = ConditionTreatmentMatrix.fromJson(json);

      expect(revived.getPrice('NM', 'non_foil'), 25.0);
      expect(revived.currency, AppCurrency.cad);
    });
  });

  group('MarketPriceQuote and MarketSpreadSummary', () {
    test('MPS-5.1: MarketPriceQuote.fromRaw normalizes foreign currency', () {
      final quote = MarketPriceQuote.fromRaw(
        vendor: 'Cardmarket',
        quoteType: MarketQuoteType.retail,
        rawAmount: 92.0,
        currency: AppCurrency.eur,
        baseCurrency: AppCurrency.usd,
      );

      expect(quote.vendor, 'Cardmarket');
      expect(quote.quoteType, MarketQuoteType.retail);
      expect(quote.rawAmount, 92.0);
      expect(quote.convertedAmount, closeTo(100.0, 0.001));
      expect(quote.isValid, isTrue);
      expect(quote.isFloorAnomaly(), isFalse);
    });

    test('MPS-5.2: Identifies floor anomalies in quotes', () {
      final floorQuote = MarketPriceQuote.fromRaw(
        vendor: 'PennyMarket',
        quoteType: MarketQuoteType.market,
        rawAmount: 0.02,
        currency: AppCurrency.usd,
        baseCurrency: AppCurrency.usd,
      );

      expect(floorQuote.isFloorAnomaly(), isTrue);

      final validQuote = MarketPriceQuote.fromRaw(
        vendor: 'ValidMarket',
        quoteType: MarketQuoteType.market,
        rawAmount: 0.03,
        currency: AppCurrency.usd,
        baseCurrency: AppCurrency.usd,
      );

      expect(validQuote.isFloorAnomaly(), isFalse);
    });

    test('MPS-5.3: MarketSpreadSummary extracts lowest retail and highest buylist', () {
      final quotes = [
        MarketPriceQuote.fromRaw(
          vendor: 'TCGplayer',
          quoteType: MarketQuoteType.retail,
          rawAmount: 20.0,
          currency: AppCurrency.usd,
          baseCurrency: AppCurrency.usd,
        ),
        MarketPriceQuote.fromRaw(
          vendor: 'Card Kingdom',
          quoteType: MarketQuoteType.retail,
          rawAmount: 22.0,
          currency: AppCurrency.usd,
          baseCurrency: AppCurrency.usd,
        ),
        MarketPriceQuote.fromRaw(
          vendor: 'CK Buylist',
          quoteType: MarketQuoteType.buylist,
          rawAmount: 14.0,
          currency: AppCurrency.usd,
          baseCurrency: AppCurrency.usd,
        ),
        MarketPriceQuote.fromRaw(
          vendor: 'TCG Buylist',
          quoteType: MarketQuoteType.buylist,
          rawAmount: 12.0,
          currency: AppCurrency.usd,
          baseCurrency: AppCurrency.usd,
        ),
        // Floor anomaly to be filtered out
        MarketPriceQuote.fromRaw(
          vendor: 'JunkBot',
          quoteType: MarketQuoteType.retail,
          rawAmount: 0.01,
          currency: AppCurrency.usd,
          baseCurrency: AppCurrency.usd,
        ),
      ];

      final summary = MarketSpreadSummary.fromQuotes(quotes);

      expect(summary.lowestRetail?.vendor, 'TCGplayer');
      expect(summary.lowestRetail?.convertedAmount, 20.0);
      expect(summary.highestBuylist?.vendor, 'CK Buylist');
      expect(summary.highestBuylist?.convertedAmount, 14.0);
      expect(summary.spreadAmount, 6.0); // 20.0 - 14.0
      expect(summary.spreadPercentage, closeTo(30.0, 0.001)); // (6 / 20) * 100
      expect(summary.quotes.length, 4); // JunkBot filtered out
    });
  });
}
