import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/state/settings_state.dart';
import 'package:countr/features/values/domain/services/trimmed_average_calculator.dart';
import 'package:countr/features/values/domain/trimmed_market_average_calculator.dart';

void main() {
  group('TrimmedAverageCalculator - Anomaly Filtering', () {
    test('TAC-1.1: Exact floor boundary (0.020000) is discarded as a floor anomaly', () {
      expect(TrimmedAverageCalculator.isFloorAnomaly(0.020000), isTrue);

      final quotes = {'penny': 0.020000, 'valid': 10.0};
      final currencies = {'penny': AppCurrency.usd, 'valid': AppCurrency.usd};

      final avg = TrimmedAverageCalculator.computeTrimmedAverage(
        rawQuotes: quotes,
        vendorCurrencies: currencies,
        targetCurrency: AppCurrency.usd,
      );

      expect(avg, 10.0);
    });

    test('TAC-1.2: Prices below floor (< 0.02) are discarded', () {
      expect(TrimmedAverageCalculator.isFloorAnomaly(0.01999), isTrue);
      expect(TrimmedAverageCalculator.isFloorAnomaly(0.005), isTrue);

      final quotes = {'junk': 0.015, 'good': 15.0};
      final currencies = {'junk': AppCurrency.usd, 'good': AppCurrency.usd};

      final avg = TrimmedAverageCalculator.computeTrimmedAverage(
        rawQuotes: quotes,
        vendorCurrencies: currencies,
        targetCurrency: AppCurrency.usd,
      );

      expect(avg, 15.0);
    });

    test('TAC-1.3: Quotes just above floor (0.021000) are preserved', () {
      expect(TrimmedAverageCalculator.isFloorAnomaly(0.021), isFalse);

      final quotes = {'q1': 0.021, 'q2': 0.029};
      final currencies = {'q1': AppCurrency.usd, 'q2': AppCurrency.usd};

      final avg = TrimmedAverageCalculator.computeTrimmedAverage(
        rawQuotes: quotes,
        vendorCurrencies: currencies,
        targetCurrency: AppCurrency.usd,
      );

      expect(avg, closeTo(0.025, 0.0001));
    });

    test('TAC-1.4: Zero prices (0.00) are rejected', () {
      expect(TrimmedAverageCalculator.isFloorAnomaly(0.0), isTrue);

      final quotes = {'zero': 0.0, 'valid': 20.0};
      final currencies = {'zero': AppCurrency.usd, 'valid': AppCurrency.usd};

      final avg = TrimmedAverageCalculator.computeTrimmedAverage(
        rawQuotes: quotes,
        vendorCurrencies: currencies,
        targetCurrency: AppCurrency.usd,
      );

      expect(avg, 20.0);
    });

    test('TAC-1.5: Negative prices are rejected', () {
      expect(TrimmedAverageCalculator.isFloorAnomaly(-5.0), isTrue);
      expect(TrimmedAverageCalculator.isFloorAnomaly(-0.01), isTrue);

      final quotes = {'neg1': -5.0, 'neg2': -0.01, 'pos': 12.0};
      final currencies = {
        'neg1': AppCurrency.usd,
        'neg2': AppCurrency.usd,
        'pos': AppCurrency.usd,
      };

      final avg = TrimmedAverageCalculator.computeTrimmedAverage(
        rawQuotes: quotes,
        vendorCurrencies: currencies,
        targetCurrency: AppCurrency.usd,
      );

      expect(avg, 12.0);
    });

    test('TAC-1.6: Non-finite values (NaN, Infinity, -Infinity) are rejected', () {
      expect(TrimmedAverageCalculator.isFloorAnomaly(double.nan), isTrue);
      expect(TrimmedAverageCalculator.isFloorAnomaly(double.infinity), isTrue);
      expect(TrimmedAverageCalculator.isFloorAnomaly(double.negativeInfinity), isTrue);

      final quotes = {
        'nan': double.nan,
        'inf': double.infinity,
        'neg_inf': double.negativeInfinity,
        'valid': 8.0,
      };
      final currencies = {
        'nan': AppCurrency.usd,
        'inf': AppCurrency.usd,
        'neg_inf': AppCurrency.usd,
        'valid': AppCurrency.usd,
      };

      final avg = TrimmedAverageCalculator.computeTrimmedAverage(
        rawQuotes: quotes,
        vendorCurrencies: currencies,
        targetCurrency: AppCurrency.usd,
      );

      expect(avg, 8.0);
    });

    test('TAC-1.7: Foreign currency converting below floor is discarded', () {
      // 0.015 EUR in USD (1 EUR ≈ 1.087 USD => ~0.0163 USD <= 0.02)
      final quotes = {'cardmarket_bulk': 0.015, 'cardmarket_valid': 10.0};
      final currencies = {
        'cardmarket_bulk': AppCurrency.eur,
        'cardmarket_valid': AppCurrency.eur,
      };

      final avg = TrimmedAverageCalculator.computeTrimmedAverage(
        rawQuotes: quotes,
        vendorCurrencies: currencies,
        targetCurrency: AppCurrency.usd,
      );

      // Only cardmarket_valid converts: 10.0 EUR / 0.92 = 10.869565 USD
      expect(avg, closeTo(10.869565, 0.001));
    });
  });

  group('TrimmedAverageCalculator - Symmetrical Outlier Trimming Rules', () {
    test('TAC-2.1: N = 0 returns null for computeTrimmedAverage and fallback for computeTrimmedMean', () {
      final avg = TrimmedAverageCalculator.computeTrimmedAverage(
        rawQuotes: {'junk1': 0.01, 'junk2': 0.02},
        vendorCurrencies: {'junk1': AppCurrency.usd, 'junk2': AppCurrency.usd},
        targetCurrency: AppCurrency.usd,
      );
      expect(avg, isNull);

      final mean = TrimmedAverageCalculator.computeTrimmedMean([], fallback: 42.0);
      expect(mean, 42.0);
    });

    test('TAC-2.2: N = 1 returns the exact single quote', () {
      final mean = TrimmedAverageCalculator.computeTrimmedMean([42.50]);
      expect(mean, 42.50);

      final avg = TrimmedAverageCalculator.computeTrimmedAverage(
        rawQuotes: {'single': 42.50},
        vendorCurrencies: {'single': AppCurrency.usd},
        targetCurrency: AppCurrency.usd,
      );
      expect(avg, 42.50);
    });

    test('TAC-2.3: N = 2 returns arithmetic midpoint', () {
      final mean = TrimmedAverageCalculator.computeTrimmedMean([10.0, 20.0]);
      expect(mean, 15.0);
    });

    test('TAC-2.4: N = 3 returns un-trimmed arithmetic mean', () {
      final mean = TrimmedAverageCalculator.computeTrimmedMean([10.0, 20.0, 30.0]);
      expect(mean, 20.0);
    });

    test('TAC-2.5: N = 4 returns un-trimmed arithmetic mean', () {
      final mean = TrimmedAverageCalculator.computeTrimmedMean([10.0, 20.0, 30.0, 40.0]);
      expect(mean, 25.0);
    });

    test('TAC-2.6: N = 5 trims 1 lowest and 1 highest outlier (k = 1)', () {
      // 5 quotes: [5.0, 10.0, 12.0, 14.0, 100.0]
      // Trims 5.0 and 100.0, averages [10.0, 12.0, 14.0] = 36.0 / 3 = 12.0
      final mean = TrimmedAverageCalculator.computeTrimmedMean([5.0, 10.0, 12.0, 14.0, 100.0]);
      expect(mean, 12.0);
    });

    test('TAC-2.7: N = 6 trims 1 lowest and 1 highest (k = 1)', () {
      // [2.0, 10.0, 12.0, 14.0, 16.0, 90.0] -> trims 2.0 and 90.0
      // middle: [10.0, 12.0, 14.0, 16.0] sum = 52.0 / 4 = 13.0
      final mean = TrimmedAverageCalculator.computeTrimmedMean([2.0, 10.0, 12.0, 14.0, 16.0, 90.0]);
      expect(mean, 13.0);
    });

    test('TAC-2.8: N = 9 trims 1 lowest and 1 highest (k = 1)', () {
      // 9 items: [1, 10, 11, 12, 13, 14, 15, 16, 100]
      // trims 1 and 100, remaining 7 items: sum = 91 / 7 = 13.0
      final prices = [1.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 100.0];
      final mean = TrimmedAverageCalculator.computeTrimmedMean(prices);
      expect(mean, 13.0);
    });

    test('TAC-2.9: N = 10 trims floor(0.10 * 10) = 1 from each end', () {
      // 10 items: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
      // trims 1 and 10, remaining 8 items: 2..9 sum = 44 / 8 = 5.5
      final prices = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0];
      final mean = TrimmedAverageCalculator.computeTrimmedMean(prices);
      expect(mean, 5.5);
    });

    test('TAC-2.10: N = 20 trims floor(0.10 * 20) = 2 from each end', () {
      // 20 items from 1.0 to 20.0
      // trims 1.0, 2.0 and 19.0, 20.0. Remaining 16 items: 3..18
      // sum(3..18) = 168 / 16 = 10.5
      final prices = List<double>.generate(20, (i) => (i + 1).toDouble());
      final mean = TrimmedAverageCalculator.computeTrimmedMean(prices);
      expect(mean, 10.5);
    });
  });

  group('TrimmedAverageCalculator - Scryfall Payload Ingestion', () {
    test('TAC-3.1: Extracts and converts quotes from standard Scryfall prices map', () {
      final payload = {
        'prices': {
          'usd': '12.50',
          'usd_foil': '25.00',
          'eur': '10.00',
          'eur_foil': '20.00',
        }
      };

      final quotes = TrimmedAverageCalculator.extractQuotesFromPayload(
        payload,
        targetCurrency: AppCurrency.usd,
      );

      expect(quotes.length, 4);
      expect(quotes[0].vendor, 'TCGplayer Market');
      expect(quotes[0].rawAmount, 12.50);
      expect(quotes[0].convertedAmount, 12.50);

      // Cardmarket EUR quote normalized to USD
      final cmQuote = quotes.firstWhere((q) => q.vendor == 'Cardmarket Trend');
      expect(cmQuote.rawAmount, 10.00);
      expect(cmQuote.currency, AppCurrency.eur);
      expect(cmQuote.convertedAmount, closeTo(10.8695, 0.001));
    });

    test('TAC-3.2: Handles null, empty, or unparseable Scryfall values gracefully', () {
      final payload = {
        'prices': {
          'usd': null,
          'usd_foil': '',
          'eur': 'invalid_string',
          'eur_foil': '0.00',
        }
      };

      final quotes = TrimmedAverageCalculator.extractQuotesFromPayload(
        payload,
        targetCurrency: AppCurrency.usd,
      );

      expect(quotes, isEmpty);

      final avg = TrimmedAverageCalculator.computeFromPayload(
        payload,
        targetCurrency: AppCurrency.usd,
        fallback: 5.0,
      );
      expect(avg, 5.0);
    });

    test('TAC-3.3: Handles malformed JSON strings without throwing', () {
      final quotes = TrimmedAverageCalculator.extractQuotesFromPayload(
        'not a valid json {[[',
        targetCurrency: AppCurrency.usd,
      );
      expect(quotes, isEmpty);
    });

    test('TAC-3.4: Extracts prices from double-sided cards (card_faces[0].prices)', () {
      final payload = {
        'card_faces': [
          {
            'prices': {
              'usd': '34.50',
              'eur': '28.00',
            }
          }
        ]
      };

      final quotes = TrimmedAverageCalculator.extractQuotesFromPayload(
        payload,
        targetCurrency: AppCurrency.usd,
      );

      expect(quotes.length, 2);
      expect(quotes[0].rawAmount, 34.50);
    });
  });

  group('TrimmedMarketAverageCalculator - Contract Alias Compliance', () {
    test('TAC-4.1: TrimmedMarketAverageCalculator matches PROJECT.md contract', () {
      expect(TrimmedMarketAverageCalculator.minimumFloorPrice, 0.02);

      final quotes = {
        'tcgplayer': 100.0,
        'cardmarket': 92.0, // 92 EUR = 100 USD
        'ebay': 102.0,
        'card_kingdom': 98.0,
        'manapool': 100.0,
      };

      final currencies = {
        'tcgplayer': AppCurrency.usd,
        'cardmarket': AppCurrency.eur,
        'ebay': AppCurrency.usd,
        'card_kingdom': AppCurrency.usd,
        'manapool': AppCurrency.usd,
      };

      final avg = TrimmedMarketAverageCalculator.computeTrimmedAverage(
        rawQuotes: quotes,
        vendorCurrencies: currencies,
        targetCurrency: AppCurrency.usd,
      );

      // 5 quotes all normalized to ~100 USD:
      // [98.0, 100.0, 100.0, 100.0, 102.0]
      // trims 98.0 and 102.0, averages three 100.0 quotes = 100.0
      expect(avg, closeTo(100.0, 0.01));
    });
  });

  group('TrimmedAverageCalculator - Finish-Aware Pricing (Milestone 3 R6)', () {
    final mixedPayload = {
      'prices': {
        'usd': '1.50',
        'usd_foil': '25.00',
        'usd_etched': '30.00',
        'eur': '1.38', // 1.38 EUR / 0.92 = 1.50 USD
        'eur_foil': '23.00', // 23.00 EUR / 0.92 = 25.00 USD
      }
    };

    test('TAC-5.1: Nonfoil finish only extracts nonfoil quotes (usd, eur)', () {
      final quotes = TrimmedAverageCalculator.extractQuotesFromPayload(
        mixedPayload,
        targetCurrency: AppCurrency.usd,
        finish: 'nonfoil',
      );

      expect(quotes.length, 2);
      expect(quotes.map((q) => q.vendor), containsAll(['TCGplayer Market', 'Cardmarket Trend']));
      expect(quotes.any((q) => q.vendor.contains('Foil') || q.vendor.contains('Etched')), isFalse);
    });

    test('TAC-5.2: Foil finish only extracts foil quotes (usd_foil, usd_etched, eur_foil)', () {
      final quotes = TrimmedAverageCalculator.extractQuotesFromPayload(
        mixedPayload,
        targetCurrency: AppCurrency.usd,
        finish: 'foil',
      );

      expect(quotes.length, 3);
      expect(quotes.map((q) => q.vendor), containsAll(['TCGplayer Foil', 'TCGplayer Etched', 'Cardmarket Foil']));
      expect(quotes.any((q) => q.vendor == 'TCGplayer Market' || q.vendor == 'Cardmarket Trend'), isFalse);
    });

    test('TAC-5.3: Etched finish extracts foil and etched quotes', () {
      final quotes = TrimmedAverageCalculator.extractQuotesFromPayload(
        mixedPayload,
        targetCurrency: AppCurrency.usd,
        finish: 'etched',
      );

      expect(quotes.length, 3);
      expect(quotes.map((q) => q.vendor), containsAll(['TCGplayer Foil', 'TCGplayer Etched', 'Cardmarket Foil']));
    });

    test('TAC-5.4: Null finish extracts all 5 quotes for backward compatibility', () {
      final quotes = TrimmedAverageCalculator.extractQuotesFromPayload(
        mixedPayload,
        targetCurrency: AppCurrency.usd,
        finish: null,
      );

      expect(quotes.length, 5);
    });

    test('TAC-5.5: computeFromPayload strictly isolates nonfoil and foil averages', () {
      final nonfoilAvg = TrimmedAverageCalculator.computeFromPayload(
        mixedPayload,
        targetCurrency: AppCurrency.usd,
        finish: 'nonfoil',
      );
      final foilAvg = TrimmedAverageCalculator.computeFromPayload(
        mixedPayload,
        targetCurrency: AppCurrency.usd,
        finish: 'foil',
      );

      // Nonfoil: 1.50 USD and 1.38 EUR (1.50 USD) -> average = 1.50
      expect(nonfoilAvg, closeTo(1.50, 0.01));

      // Foil: 25.00, 30.00, 25.00 -> 3 quotes arithmetic mean = 26.666...
      expect(foilAvg, greaterThan(24.0));
      expect(foilAvg, lessThan(31.0));
    });

    test('TAC-5.6: Nonfoil card with only foil prices returns fallback (never mixes foil prices)', () {
      final foilOnlyPayload = {
        'prices': {
          'usd_foil': '45.00',
          'eur_foil': '40.00',
        }
      };

      final quotes = TrimmedAverageCalculator.extractQuotesFromPayload(
        foilOnlyPayload,
        targetCurrency: AppCurrency.usd,
        finish: 'nonfoil',
      );
      expect(quotes, isEmpty);

      final avg = TrimmedAverageCalculator.computeFromPayload(
        foilOnlyPayload,
        targetCurrency: AppCurrency.usd,
        finish: 'nonfoil',
        fallback: 0.0,
      );
      expect(avg, 0.0);
    });

    test('TAC-5.7: Direct prices map without root prices key is parsed correctly', () {
      final directMap = {
        'usd': '3.50',
        'usd_foil': '12.00',
      };

      final nonfoilAvg = TrimmedAverageCalculator.computeFromPayload(
        directMap,
        targetCurrency: AppCurrency.usd,
        finish: 'nonfoil',
      );
      expect(nonfoilAvg, 3.50);

      final foilAvg = TrimmedAverageCalculator.computeFromPayload(
        directMap,
        targetCurrency: AppCurrency.usd,
        finish: 'foil',
      );
      expect(foilAvg, 12.00);
    });
  });
}
