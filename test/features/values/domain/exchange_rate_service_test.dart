import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/state/settings_state.dart';
import 'package:countr/features/values/domain/exchange_rate_service.dart';

void main() {
  setUp(() {
    ExchangeRateService.resetToDefaults();
  });

  tearDown(() {
    ExchangeRateService.resetToDefaults();
  });

  group('ExchangeRateService - Core Calculations & Conversion Engine', () {
    test('identity rate returns 1.0 for identical currencies', () {
      for (final currency in AppCurrency.values) {
        expect(
          ExchangeRateService.getRate(from: currency, to: currency),
          1.0,
        );
        expect(
          ExchangeRateService.convert(100.0, from: currency, to: currency),
          100.0,
        );
      }
    });

    test('calculates direct baseline rates from USD correctly', () {
      expect(
        ExchangeRateService.getRate(from: AppCurrency.usd, to: AppCurrency.eur),
        0.9200,
      );
      expect(
        ExchangeRateService.getRate(from: AppCurrency.usd, to: AppCurrency.gbp),
        0.7850,
      );
      expect(
        ExchangeRateService.getRate(from: AppCurrency.usd, to: AppCurrency.cad),
        1.3600,
      );
    });

    test('calculates cross rates correctly', () {
      // EUR to USD: 1.0 / 0.92 ≈ 1.0869565...
      final eurToUsd = ExchangeRateService.getRate(from: AppCurrency.eur, to: AppCurrency.usd);
      expect(eurToUsd, closeTo(1.0 / 0.92, 0.0001));

      // GBP to EUR: 0.92 / 0.785 ≈ 1.1719745...
      final gbpToEur = ExchangeRateService.getRate(from: AppCurrency.gbp, to: AppCurrency.eur);
      expect(gbpToEur, closeTo(0.92 / 0.785, 0.0001));

      // CAD to GBP: 0.785 / 1.36 ≈ 0.577205...
      final cadToGbp = ExchangeRateService.getRate(from: AppCurrency.cad, to: AppCurrency.gbp);
      expect(cadToGbp, closeTo(0.785 / 1.36, 0.0001));
    });

    test('converts amounts between currencies accurately', () {
      // 100 USD -> EUR
      final eurAmount = ExchangeRateService.convert(100.0, from: AppCurrency.usd, to: AppCurrency.eur);
      expect(eurAmount, 92.0);

      // 92 EUR -> USD
      final usdAmount = ExchangeRateService.convert(92.0, from: AppCurrency.eur, to: AppCurrency.usd);
      expect(usdAmount, closeTo(100.0, 0.0001));

      // 100 USD -> CAD
      final cadAmount = ExchangeRateService.convert(100.0, from: AppCurrency.usd, to: AppCurrency.cad);
      expect(cadAmount, 136.0);

      // 100 USD -> GBP
      final gbpAmount = ExchangeRateService.convert(100.0, from: AppCurrency.usd, to: AppCurrency.gbp);
      expect(gbpAmount, 78.50);
    });

    test('safely handles non-positive, zero, NaN, and infinite inputs', () {
      expect(ExchangeRateService.convert(0.0, from: AppCurrency.usd, to: AppCurrency.eur), 0.0);
      expect(ExchangeRateService.convert(-25.5, from: AppCurrency.usd, to: AppCurrency.eur), 0.0);
      expect(ExchangeRateService.convert(double.nan, from: AppCurrency.usd, to: AppCurrency.eur), 0.0);
      expect(ExchangeRateService.convert(double.infinity, from: AppCurrency.usd, to: AppCurrency.eur), 0.0);
      expect(ExchangeRateService.convert(double.negativeInfinity, from: AppCurrency.usd, to: AppCurrency.eur), 0.0);
    });

    test('getCurrencySymbol returns canonical symbols', () {
      expect(ExchangeRateService.getCurrencySymbol(AppCurrency.usd), r'$');
      expect(ExchangeRateService.getCurrencySymbol(AppCurrency.eur), '€');
      expect(ExchangeRateService.getCurrencySymbol(AppCurrency.gbp), '£');
      expect(ExchangeRateService.getCurrencySymbol(AppCurrency.cad), r'CA$');
    });
  });

  group('ExchangeRateService - Market Normalization', () {
    test('maps market sources to their native currencies', () {
      expect(ExchangeRateService.defaultCurrencyForMarket('TCGplayer'), AppCurrency.usd);
      expect(ExchangeRateService.defaultCurrencyForMarket('tcg'), AppCurrency.usd);
      expect(ExchangeRateService.defaultCurrencyForMarket('eBay'), AppCurrency.usd);
      expect(ExchangeRateService.defaultCurrencyForMarket('Cardmarket'), AppCurrency.eur);
      expect(ExchangeRateService.defaultCurrencyForMarket('MKM'), AppCurrency.eur);
      expect(ExchangeRateService.defaultCurrencyForMarket('Face2Face'), AppCurrency.cad);
      expect(ExchangeRateService.defaultCurrencyForMarket('MagicMadhouse'), AppCurrency.gbp);
      expect(ExchangeRateService.defaultCurrencyForMarket('unknown_source'), AppCurrency.usd);
    });

    test('normalizes single market prices correctly', () {
      // 92 EUR from Cardmarket -> USD (should be 100 USD)
      final normUsd = ExchangeRateService.normalizeMarketPrice(
        92.0,
        marketSource: 'Cardmarket',
        targetCurrency: AppCurrency.usd,
      );
      expect(normUsd, closeTo(100.0, 0.0001));

      // 100 USD from TCGplayer -> EUR (should be 92 EUR)
      final normEur = ExchangeRateService.normalizeMarketPrice(
        100.0,
        marketSource: 'TCGplayer',
        targetCurrency: AppCurrency.eur,
      );
      expect(normEur, 92.0);
    });

    test('normalizes multi-vendor quote maps correctly', () {
      final rawQuotes = {
        'tcgplayer': 100.0,  // USD -> USD = 100.0
        'cardmarket': 92.0,   // EUR -> USD = 100.0
        'face2face': 136.0,   // CAD -> USD = 100.0
        'magicmadhouse': 78.50, // GBP -> USD = 100.0
      };

      final normalizedToUsd = ExchangeRateService.normalizeVendorQuotes(
        rawQuotes,
        targetCurrency: AppCurrency.usd,
      );

      expect(normalizedToUsd['tcgplayer'], closeTo(100.0, 0.001));
      expect(normalizedToUsd['cardmarket'], closeTo(100.0, 0.001));
      expect(normalizedToUsd['face2face'], closeTo(100.0, 0.001));
      expect(normalizedToUsd['magicmadhouse'], closeTo(100.0, 0.001));
    });

    test('normalizes Scryfall price keys correctly', () {
      // Scryfall 'usd' price: 50.0 -> EUR
      final usdNormEur = ExchangeRateService.normalizeScryfallPrice(
        50.0,
        priceKey: 'usd',
        targetCurrency: AppCurrency.eur,
      );
      expect(usdNormEur, 50.0 * 0.92);

      // Scryfall 'eur_foil' price: 46.0 -> USD
      final eurFoilNormUsd = ExchangeRateService.normalizeScryfallPrice(
        46.0,
        priceKey: 'eur_foil',
        targetCurrency: AppCurrency.usd,
      );
      expect(eurFoilNormUsd, closeTo(46.0 * (1.0 / 0.92), 0.001));
    });
  });

  group('ExchangeRateService - Cache & Freshness', () {
    test('freshnessBadge reports recent status', () {
      expect(ExchangeRateService.freshnessBadge, 'Updated just now');
    });

    test('updateRates modifies cached rates and lastUpdated', () {
      final customRates = {
        AppCurrency.usd: 1.0,
        AppCurrency.eur: 0.95,
        AppCurrency.gbp: 0.80,
        AppCurrency.cad: 1.40,
      };

      ExchangeRateService.updateRates(customRates);

      expect(
        ExchangeRateService.getRate(from: AppCurrency.usd, to: AppCurrency.eur),
        0.95,
      );
      expect(
        ExchangeRateService.convert(100.0, from: AppCurrency.usd, to: AppCurrency.cad),
        140.0,
      );

      ExchangeRateService.resetToDefaults();
      expect(
        ExchangeRateService.getRate(from: AppCurrency.usd, to: AppCurrency.eur),
        0.92,
      );
    });

    test('instance methods and Riverpod provider function properly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final service = container.read(exchangeRateServiceProvider);
      expect(service, isNotNull);

      final converted = service.convertInstance(100.0, from: AppCurrency.usd, to: AppCurrency.eur);
      expect(converted, 92.0);
      expect(service.instanceFreshnessBadge, 'Updated just now');
    });
  });
}
