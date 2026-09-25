// Copyright (c) 2026 Countr. All rights reserved.
// Empirical Adversarial Stress Test Suite for Milestone 1:
// Currency Normalization Engine, Dynamic FX Formatting, and Privacy Redaction.

import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/settings_state.dart';
import 'package:countr/features/values/domain/exchange_rate_service.dart';
import 'package:countr/features/vault/domain/vault_pricing_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    ExchangeRateService.resetToDefaults();
  });

  tearDown(() {
    ExchangeRateService.resetToDefaults();
  });

  // ===========================================================================
  // SECTION 1: EXCHANGE RATE PRECISION & ROUND-TRIPPING ORACLES
  // ===========================================================================
  group('Adversarial Stress 1: FX Precision & Round-Tripping Oracles', () {
    test('Identity Oracle: Rate and conversion for identical currency is strictly 1.0 and invariant', () {
      final testAmounts = [0.01, 1.0, 15.5, 99.99, 1000.0, 50000.0, 1000000.0];
      for (final currency in AppCurrency.values) {
        expect(
          ExchangeRateService.getRate(from: currency, to: currency),
          equals(1.0),
          reason: 'Identity rate must be 1.0 for ${currency.code}',
        );
        for (final amount in testAmounts) {
          final converted = ExchangeRateService.convert(amount, from: currency, to: currency);
          expect(
            converted,
            equals(amount),
            reason: 'Identity conversion must preserve exact value for ${currency.code}',
          );
        }
      }
    });

    test('Pairwise Round-Tripping Oracle: A -> B -> A recovers initial value within floating tolerance', () {
      final currencies = AppCurrency.values;
      final testAmounts = [
        0.05,
        1.0,
        12.34,
        99.99,
        500.0,
        25000.0, // High-value vintage staple
        1000000.0, // Million dollar collection
      ];

      for (final from in currencies) {
        for (final to in currencies) {
          for (final amount in testAmounts) {
            final intermediate = ExchangeRateService.convert(amount, from: from, to: to);
            final roundTripped = ExchangeRateService.convert(intermediate, from: to, to: from);

            // Due to IEEE-754 64-bit float multiplication/division:
            // Relative error should be < 1e-12
            final relativeError = (roundTripped - amount).abs() / amount;
            expect(
              relativeError,
              lessThan(1e-9),
              reason: 'Round-tripping $amount from ${from.code} -> ${to.code} -> ${from.code} lost precision (Relative error: $relativeError)',
            );
          }
        }
      }
    });

    test('Cyclic 4-Hop Round-Tripping Oracle: USD -> EUR -> GBP -> CAD -> USD closes cycle', () {
      const initialAmount = 10000.0;

      // Forward cycle
      final inEur = ExchangeRateService.convert(initialAmount, from: AppCurrency.usd, to: AppCurrency.eur);
      final inGbp = ExchangeRateService.convert(inEur, from: AppCurrency.eur, to: AppCurrency.gbp);
      final inCad = ExchangeRateService.convert(inGbp, from: AppCurrency.gbp, to: AppCurrency.cad);
      final backToUsd = ExchangeRateService.convert(inCad, from: AppCurrency.cad, to: AppCurrency.usd);

      final cycleErrorForward = (backToUsd - initialAmount).abs() / initialAmount;
      expect(
        cycleErrorForward,
        lessThan(1e-9),
        reason: 'Forward 4-hop cycle USD->EUR->GBP->CAD->USD accumulated excessive drift ($backToUsd vs $initialAmount)',
      );

      // Reverse cycle
      final revCad = ExchangeRateService.convert(initialAmount, from: AppCurrency.usd, to: AppCurrency.cad);
      final revGbp = ExchangeRateService.convert(revCad, from: AppCurrency.cad, to: AppCurrency.gbp);
      final revEur = ExchangeRateService.convert(revGbp, from: AppCurrency.gbp, to: AppCurrency.eur);
      final revUsd = ExchangeRateService.convert(revEur, from: AppCurrency.eur, to: AppCurrency.usd);

      final cycleErrorReverse = (revUsd - initialAmount).abs() / initialAmount;
      expect(
        cycleErrorReverse,
        lessThan(1e-9),
        reason: 'Reverse 4-hop cycle USD->CAD->GBP->EUR->USD accumulated excessive drift ($revUsd vs $initialAmount)',
      );
    });

    test('Triangular Arbitrage Consistency: Direct rate A -> C equals A -> B * B -> C', () {
      final currencies = AppCurrency.values;
      for (final a in currencies) {
        for (final b in currencies) {
          for (final c in currencies) {
            final directRate = ExchangeRateService.getRate(from: a, to: c);
            final transitiveRate = ExchangeRateService.getRate(from: a, to: b) *
                ExchangeRateService.getRate(from: b, to: c);

            expect(
              directRate,
              closeTo(transitiveRate, 1e-12),
              reason: 'Triangular consistency violated for ${a.code} -> ${b.code} -> ${c.code}',
            );
          }
        }
      }
    });

    test('Custom Exchange Rates Mutability and Reset Oracle', () {
      final initialEurRate = ExchangeRateService.getRate(from: AppCurrency.usd, to: AppCurrency.eur);
      expect(initialEurRate, equals(0.9200));

      final customRates = {
        AppCurrency.usd: 1.0,
        AppCurrency.eur: 0.9542,
        AppCurrency.gbp: 0.8123,
        AppCurrency.cad: 1.3987,
      };

      ExchangeRateService.updateRates(customRates);

      expect(
        ExchangeRateService.getRate(from: AppCurrency.usd, to: AppCurrency.eur),
        equals(0.9542),
      );
      expect(
        ExchangeRateService.convert(1000.0, from: AppCurrency.usd, to: AppCurrency.eur),
        equals(954.2),
      );

      // Reset to defaults
      ExchangeRateService.resetToDefaults();
      expect(
        ExchangeRateService.getRate(from: AppCurrency.usd, to: AppCurrency.eur),
        equals(0.9200),
      );
    });
  });

  // ===========================================================================
  // SECTION 2: ZERO, NEGATIVE, EXTREME VALUES & BOUNDARY CONDITIONS
  // ===========================================================================
  group('Adversarial Stress 2: Boundary Conditions, Zero, Negative, and Extreme Values', () {
    test('Zero amounts conversion and formatting', () {
      for (final from in AppCurrency.values) {
        for (final to in AppCurrency.values) {
          expect(ExchangeRateService.convert(0.0, from: from, to: to), equals(0.0));
          expect(ExchangeRateService.convert(-0.0, from: from, to: to), equals(0.0));
        }
      }

      // formatAmount with allowZero
      expect(
        VaultPricingHelper.formatAmount(0.0, currency: AppCurrency.usd, isPrivacyMode: false, allowZero: false),
        equals('Unlisted'),
      );
      expect(
        VaultPricingHelper.formatAmount(0.0, currency: AppCurrency.usd, isPrivacyMode: false, allowZero: true),
        equals(r'$0.00'),
      );
      expect(
        VaultPricingHelper.formatAmount(0.0, currency: AppCurrency.eur, isPrivacyMode: false, allowZero: true),
        equals('€0.00'),
      );
      expect(
        VaultPricingHelper.formatAmount(0.0, currency: AppCurrency.gbp, isPrivacyMode: false, allowZero: true),
        equals('£0.00'),
      );
      expect(
        VaultPricingHelper.formatAmount(0.0, currency: AppCurrency.cad, isPrivacyMode: false, allowZero: true),
        equals(r'CA$0.00'),
      );
    });

    test('Negative numbers in conversion vs formatting', () {
      // ExchangeRateService.convert treats negative numbers as invalid market prices -> returns 0.0
      expect(ExchangeRateService.convert(-1.0, from: AppCurrency.usd, to: AppCurrency.eur), equals(0.0));
      expect(ExchangeRateService.convert(-500.0, from: AppCurrency.eur, to: AppCurrency.usd), equals(0.0));
      expect(ExchangeRateService.convert(-0.0001, from: AppCurrency.usd, to: AppCurrency.cad), equals(0.0));

      // VaultPricingHelper.formatAmount supports allowNegative: true (e.g. for P&L or debt)
      expect(
        VaultPricingHelper.formatAmount(-25.50, currency: AppCurrency.usd, isPrivacyMode: false, allowNegative: true),
        equals(r'-$25.50'),
      );
      expect(
        VaultPricingHelper.formatAmount(-25.50, currency: AppCurrency.eur, isPrivacyMode: false, allowNegative: true),
        equals('-€25.50'),
      );
      expect(
        VaultPricingHelper.formatAmount(-25.50, currency: AppCurrency.gbp, isPrivacyMode: false, allowNegative: true),
        equals('-£25.50'),
      );
      expect(
        VaultPricingHelper.formatAmount(-25.50, currency: AppCurrency.cad, isPrivacyMode: false, allowNegative: true),
        equals(r'-CA$25.50'),
      );

      // If allowNegative: false, returns fallback
      expect(
        VaultPricingHelper.formatAmount(-25.50, currency: AppCurrency.usd, isPrivacyMode: false, allowNegative: false),
        equals('Unlisted'),
      );
    });

    test('Extreme high values: 1 Billion and 1 Trillion without overflow or scientific notation', () {
      const oneBillion = 1000000000.0;
      final convertedEur = ExchangeRateService.convert(oneBillion, from: AppCurrency.usd, to: AppCurrency.eur);
      expect(convertedEur, equals(920000000.0));

      final formattedUsd = VaultPricingHelper.formatAmount(oneBillion, currency: AppCurrency.usd, isPrivacyMode: false);
      expect(formattedUsd, equals(r'$1000000000.00'));
      expect(formattedUsd.contains('e+'), isFalse);

      final formattedCad = VaultPricingHelper.formatAmount(oneBillion, currency: AppCurrency.cad, isPrivacyMode: false);
      expect(formattedCad, equals(r'CA$1000000000.00'));

      // 500k Black Lotus check
      const lotusPrice = 511100.0;
      final formattedLotus = VaultPricingHelper.formatAmount(lotusPrice, currency: AppCurrency.usd, isPrivacyMode: false);
      expect(formattedLotus, equals(r'$511100.00'));
    });

    test('Micro-values and sub-cent rounding boundaries', () {
      // 0.0001 USD
      final convertedMicro = ExchangeRateService.convert(0.0001, from: AppCurrency.usd, to: AppCurrency.eur);
      expect(convertedMicro, closeTo(0.000092, 1e-8));

      // 0.0001 formatted with 2 decimals rounds to $0.00
      final formattedMicro = VaultPricingHelper.formatAmount(0.0001, currency: AppCurrency.usd, isPrivacyMode: false);
      expect(formattedMicro, equals(r'$0.00'));

      // Half-cent rounding: 0.005 rounds to 0.01 in toStringAsFixed(2)
      final formattedHalfCent = VaultPricingHelper.formatAmount(0.005, currency: AppCurrency.usd, isPrivacyMode: false);
      expect(formattedHalfCent, equals(r'$0.01'));

      // Exact $0.02 floor price
      final formattedFloor = VaultPricingHelper.formatAmount(0.02, currency: AppCurrency.usd, isPrivacyMode: false);
      expect(formattedFloor, equals(r'$0.02'));
    });

    test('Non-finite inputs (NaN, +Infinity, -Infinity) gracefully return zero or fallback without leaking', () {
      final invalidDoubles = [double.nan, double.infinity, double.negativeInfinity];

      for (final invalid in invalidDoubles) {
        expect(
          ExchangeRateService.convert(invalid, from: AppCurrency.usd, to: AppCurrency.eur),
          equals(0.0),
          reason: 'convert must return 0.0 for $invalid',
        );

        final formattedAmount = VaultPricingHelper.formatAmount(
          invalid,
          currency: AppCurrency.usd,
          isPrivacyMode: false,
        );
        expect(formattedAmount, equals('Unlisted'));
        expect(formattedAmount.contains('NaN'), isFalse);
        expect(formattedAmount.contains('Infinity'), isFalse);

        final formattedReturn = VaultPricingHelper.formatReturn(
          invalid,
          invalid,
          currency: AppCurrency.usd,
          isPrivacyMode: false,
        );
        expect(formattedReturn, equals('—'));
        expect(formattedReturn.contains('NaN'), isFalse);
        expect(formattedReturn.contains('Infinity'), isFalse);

        final formattedPriceLabel = VaultPricingHelper.formatMarketPriceLabel(
          invalid,
          currency: AppCurrency.usd,
          isPrivacyMode: false,
        );
        expect(formattedPriceLabel, equals('Unlisted'));

        final formattedHeaderLabel = VaultPricingHelper.formatMarketHeaderLabel(
          invalid,
          currency: AppCurrency.usd,
          isPrivacyMode: false,
        );
        expect(formattedHeaderLabel, equals('Market: Unlisted'));
      }
    });
  });

  // ===========================================================================
  // SECTION 3: MULTI-MARKET QUOTES NORMALIZATION & CANONICAL SYMBOLS
  // ===========================================================================
  group('Adversarial Stress 3: Multi-Market Normalization & Canonical Symbols', () {
    test('Market source resolution handles case variations, whitespace, and unknown sources', () {
      expect(ExchangeRateService.defaultCurrencyForMarket('TCGplayer'), equals(AppCurrency.usd));
      expect(ExchangeRateService.defaultCurrencyForMarket('  tcgplayer  '), equals(AppCurrency.usd));
      expect(ExchangeRateService.defaultCurrencyForMarket('TCG_DIRECT'), equals(AppCurrency.usd));
      expect(ExchangeRateService.defaultCurrencyForMarket('eBay'), equals(AppCurrency.usd));
      expect(ExchangeRateService.defaultCurrencyForMarket('EBAY_VAULT'), equals(AppCurrency.usd));

      expect(ExchangeRateService.defaultCurrencyForMarket('Cardmarket'), equals(AppCurrency.eur));
      expect(ExchangeRateService.defaultCurrencyForMarket('cardmarket_pro'), equals(AppCurrency.eur));
      expect(ExchangeRateService.defaultCurrencyForMarket('MKM'), equals(AppCurrency.eur));
      expect(ExchangeRateService.defaultCurrencyForMarket('mkm_singles'), equals(AppCurrency.eur));

      expect(ExchangeRateService.defaultCurrencyForMarket('MagicMadhouse'), equals(AppCurrency.gbp));
      expect(ExchangeRateService.defaultCurrencyForMarket('gbp_market'), equals(AppCurrency.gbp));

      expect(ExchangeRateService.defaultCurrencyForMarket('Face2Face'), equals(AppCurrency.cad));
      expect(ExchangeRateService.defaultCurrencyForMarket('face2face_games'), equals(AppCurrency.cad));

      // Fallbacks
      expect(ExchangeRateService.defaultCurrencyForMarket(''), equals(AppCurrency.usd));
      expect(ExchangeRateService.defaultCurrencyForMarket('   '), equals(AppCurrency.usd));
      expect(ExchangeRateService.defaultCurrencyForMarket('RandomVendorXYZ'), equals(AppCurrency.usd));
    });

    test('Batch multi-vendor normalization performs apples-to-apples comparison across USD, EUR, GBP, CAD', () {
      // 100 USD equivalent in each currency based on baseline rates:
      // USD: 100.0
      // EUR: 92.0
      // GBP: 78.50
      // CAD: 136.0
      final rawQuotes = {
        'tcgplayer': 100.0,
        'cardmarket': 92.0,
        'magicmadhouse': 78.50,
        'face2face': 136.0,
      };

      // 1. Normalized to USD: all 4 quotes must be 100.0
      final normUsd = ExchangeRateService.normalizeVendorQuotes(
        rawQuotes,
        targetCurrency: AppCurrency.usd,
      );
      expect(normUsd['tcgplayer'], closeTo(100.0, 1e-4));
      expect(normUsd['cardmarket'], closeTo(100.0, 1e-4));
      expect(normUsd['magicmadhouse'], closeTo(100.0, 1e-4));
      expect(normUsd['face2face'], closeTo(100.0, 1e-4));

      // 2. Normalized to EUR: all 4 quotes must be 92.0
      final normEur = ExchangeRateService.normalizeVendorQuotes(
        rawQuotes,
        targetCurrency: AppCurrency.eur,
      );
      expect(normEur['tcgplayer'], closeTo(92.0, 1e-4));
      expect(normEur['cardmarket'], closeTo(92.0, 1e-4));
      expect(normEur['magicmadhouse'], closeTo(92.0, 1e-4));
      expect(normEur['face2face'], closeTo(92.0, 1e-4));

      // 3. Normalized to GBP: all 4 quotes must be 78.50
      final normGbp = ExchangeRateService.normalizeVendorQuotes(
        rawQuotes,
        targetCurrency: AppCurrency.gbp,
      );
      expect(normGbp['tcgplayer'], closeTo(78.50, 1e-4));
      expect(normGbp['cardmarket'], closeTo(78.50, 1e-4));
      expect(normGbp['magicmadhouse'], closeTo(78.50, 1e-4));
      expect(normGbp['face2face'], closeTo(78.50, 1e-4));

      // 4. Normalized to CAD: all 4 quotes must be 136.0
      final normCad = ExchangeRateService.normalizeVendorQuotes(
        rawQuotes,
        targetCurrency: AppCurrency.cad,
      );
      expect(normCad['tcgplayer'], closeTo(136.0, 1e-4));
      expect(normCad['cardmarket'], closeTo(136.0, 1e-4));
      expect(normCad['magicmadhouse'], closeTo(136.0, 1e-4));
      expect(normCad['face2face'], closeTo(136.0, 1e-4));
    });

    test('vendorCurrencies override parameter takes precedence over heuristic string matching', () {
      final rawQuotes = {'cardmarket_usd_listing': 50.0};

      // Without override, 'cardmarket' heuristic matches EUR
      final defaultNorm = ExchangeRateService.normalizeVendorQuotes(
        rawQuotes,
        targetCurrency: AppCurrency.usd,
      );
      // 50 EUR -> USD: 50 / 0.92 ≈ 54.3478
      expect(defaultNorm['cardmarket_usd_listing'], closeTo(54.3478, 1e-3));

      // With explicit override to USD:
      final overriddenNorm = ExchangeRateService.normalizeVendorQuotes(
        rawQuotes,
        targetCurrency: AppCurrency.usd,
        vendorCurrencies: {'cardmarket_usd_listing': AppCurrency.usd},
      );
      // 50 USD -> USD: 50.0
      expect(overriddenNorm['cardmarket_usd_listing'], equals(50.0));
    });

    test('Scryfall price keys normalization across finishes', () {
      final finishes = ['usd', 'usd_foil', 'usd_etched'];
      for (final key in finishes) {
        final norm = ExchangeRateService.normalizeScryfallPrice(100.0, priceKey: key, targetCurrency: AppCurrency.cad);
        expect(norm, equals(136.0));
      }

      final eurFinishes = ['eur', 'eur_foil'];
      for (final key in eurFinishes) {
        final norm = ExchangeRateService.normalizeScryfallPrice(92.0, priceKey: key, targetCurrency: AppCurrency.usd);
        expect(norm, closeTo(100.0, 1e-4));
      }
    });

    test('Canonical symbols are verified for all 4 currencies', () {
      expect(ExchangeRateService.getCurrencySymbol(AppCurrency.usd), equals(r'$'));
      expect(ExchangeRateService.getCurrencySymbol(AppCurrency.eur), equals('€'));
      expect(ExchangeRateService.getCurrencySymbol(AppCurrency.gbp), equals('£'));
      expect(ExchangeRateService.getCurrencySymbol(AppCurrency.cad), equals(r'CA$'));

      for (final c in AppCurrency.values) {
        expect(ExchangeRateService.getCurrencySymbol(c), equals(c.symbol));
      }
    });
  });

  // ===========================================================================
  // SECTION 4: DYNAMIC CURRENCY CHANGES, PRIVACY MASKING & FORMATTING
  // ===========================================================================
  group('Adversarial Stress 4: Dynamic Currency Changes, Privacy Masking & Formatting', () {
    test('Privacy Mode Masking: formatAmount returns verbatim **** for any input', () {
      final testAmounts = [
        150.0,
        0.0,
        -50.0,
        1000000000.0,
        0.0001,
        null,
        double.nan,
        double.infinity,
        double.negativeInfinity,
      ];

      for (final currency in AppCurrency.values) {
        for (final amount in testAmounts) {
          final formatted = VaultPricingHelper.formatAmount(
            amount,
            currency: currency,
            isPrivacyMode: true,
          );
          expect(
            formatted,
            equals('****'),
            reason: 'formatAmount must return verbatim **** in privacy mode for amount=$amount and currency=${currency.code}',
          );
        }
      }
    });

    test('Privacy Mode Masking: formatReturn returns verbatim **** for any combination', () {
      final testDeltas = [15.0, -15.0, 0.0, null, double.nan, double.infinity];
      final testPercentages = [25.0, -25.0, 0.0, null, double.nan, double.infinity];

      for (final currency in AppCurrency.values) {
        for (final d in testDeltas) {
          for (final p in testPercentages) {
            final formatted = VaultPricingHelper.formatReturn(
              d,
              p,
              currency: currency,
              isPrivacyMode: true,
            );
            expect(
              formatted,
              equals('****'),
              reason: 'formatReturn must return verbatim **** in privacy mode for delta=$d, pct=$p',
            );
          }
        }
      }
    });

    test('formatReturn amountFirst toggle and exact sign formatting across currencies', () {
      // 1. Positive return, amountFirst = true
      expect(
        VaultPricingHelper.formatReturn(12.50, 25.0, currency: AppCurrency.usd, isPrivacyMode: false, amountFirst: true),
        equals(r'+$12.50 (+25.0%)'),
      );
      expect(
        VaultPricingHelper.formatReturn(12.50, 25.0, currency: AppCurrency.eur, isPrivacyMode: false, amountFirst: true),
        equals('+€12.50 (+25.0%)'),
      );
      expect(
        VaultPricingHelper.formatReturn(12.50, 25.0, currency: AppCurrency.gbp, isPrivacyMode: false, amountFirst: true),
        equals('+£12.50 (+25.0%)'),
      );
      expect(
        VaultPricingHelper.formatReturn(12.50, 25.0, currency: AppCurrency.cad, isPrivacyMode: false, amountFirst: true),
        equals(r'+CA$12.50 (+25.0%)'),
      );

      // 2. Positive return, amountFirst = false
      expect(
        VaultPricingHelper.formatReturn(12.50, 25.0, currency: AppCurrency.usd, isPrivacyMode: false, amountFirst: false),
        equals(r'+25.0% (+$12.50)'),
      );

      // 3. Negative return, amountFirst = true
      expect(
        VaultPricingHelper.formatReturn(-8.75, -15.5, currency: AppCurrency.usd, isPrivacyMode: false, amountFirst: true),
        equals(r'-$8.75 (-15.5%)'),
      );
      expect(
        VaultPricingHelper.formatReturn(-8.75, -15.5, currency: AppCurrency.eur, isPrivacyMode: false, amountFirst: true),
        equals('-€8.75 (-15.5%)'),
      );

      // 4. Negative return, amountFirst = false
      expect(
        VaultPricingHelper.formatReturn(-8.75, -15.5, currency: AppCurrency.usd, isPrivacyMode: false, amountFirst: false),
        equals(r'-15.5% (-$8.75)'),
      );

      // 5. Break-even return (0.0 delta, 0.0 percentage)
      expect(
        VaultPricingHelper.formatReturn(0.0, 0.0, currency: AppCurrency.usd, isPrivacyMode: false, amountFirst: true),
        equals(r'+$0.00 (+0.0%)'),
      );
      expect(
        VaultPricingHelper.formatReturn(0.0, 0.0, currency: AppCurrency.usd, isPrivacyMode: false, amountFirst: false),
        equals(r'+0.0% (+$0.00)'),
      );

      // 6. Single-valued returns
      expect(
        VaultPricingHelper.formatReturn(null, 15.0, currency: AppCurrency.usd, isPrivacyMode: false),
        equals('+15.0%'),
      );
      expect(
        VaultPricingHelper.formatReturn(null, -15.0, currency: AppCurrency.usd, isPrivacyMode: false),
        equals('-15.0%'),
      );
      expect(
        VaultPricingHelper.formatReturn(20.0, null, currency: AppCurrency.gbp, isPrivacyMode: false),
        equals('+£20.00'),
      );
      expect(
        VaultPricingHelper.formatReturn(-20.0, null, currency: AppCurrency.cad, isPrivacyMode: false),
        equals(r'-CA$20.00'),
      );

      // 7. Both null returns fallback
      expect(
        VaultPricingHelper.formatReturn(null, null, currency: AppCurrency.usd, isPrivacyMode: false),
        equals('—'),
      );
    });

    test('VaultItem extension methods format dynamically with reactive currency and privacy mode', () {
      final testItem = VaultItem(
        id: 'item-stress-1',
        collectionType: 'mtg',
        name: 'Mox Diamond',
        setOrSeries: 'STH',
        imageUrl: 'https://example.com/diamond.jpg',
        acquiredPrice: 400.0,
        acquiredDate: DateTime.now(),
        quantity: 1,
        condition: 'NM',
        isGraded: false,
        isAltered: false,
        isMisprint: false,
        isSigned: false,
        currentMarketPrice: 650.0,
        lastPriceUpdate: DateTime.now(),
        dynamicData: '{}',
      );

      // In USD
      expect(testItem.formatMarketPrice(currency: AppCurrency.usd, isPrivacyMode: false), equals(r'$650.00'));
      expect(testItem.formatMarketHeader(currency: AppCurrency.usd, isPrivacyMode: false), equals(r'Market: $650.00'));

      // In EUR
      expect(testItem.formatMarketPrice(currency: AppCurrency.eur, isPrivacyMode: false), equals('€650.00'));
      expect(testItem.formatMarketHeader(currency: AppCurrency.eur, isPrivacyMode: false), equals('Market: €650.00'));

      // In CAD
      expect(testItem.formatMarketPrice(currency: AppCurrency.cad, isPrivacyMode: false), equals(r'CA$650.00'));
      expect(testItem.formatMarketHeader(currency: AppCurrency.cad, isPrivacyMode: false), equals(r'Market: CA$650.00'));

      // Privacy Mode Active
      expect(testItem.formatMarketPrice(currency: AppCurrency.usd, isPrivacyMode: true), equals('****'));
      expect(testItem.formatMarketHeader(currency: AppCurrency.usd, isPrivacyMode: true), equals('Market: ****'));
      expect(testItem.formatAmount(currency: AppCurrency.usd, isPrivacyMode: true), equals('****'));
    });

    test('Riverpod State Reactivity: baseCurrencyProvider and privacyModeProvider state changes', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Default checks
      expect(container.read(baseCurrencyProvider), equals(AppCurrency.usd));
      expect(container.read(privacyModeProvider), isFalse);
      expect(container.read(streamerSecurityEnabledProvider), isFalse);

      final currencyUpdates = <AppCurrency>[];
      container.listen<AppCurrency>(
        baseCurrencyProvider,
        (previous, next) => currencyUpdates.add(next),
      );

      final privacyUpdates = <bool>[];
      container.listen<bool>(
        privacyModeProvider,
        (previous, next) => privacyUpdates.add(next),
      );

      // Transition currencies
      container.read(baseCurrencyProvider.notifier).state = AppCurrency.eur;
      container.read(baseCurrencyProvider.notifier).state = AppCurrency.gbp;
      container.read(baseCurrencyProvider.notifier).state = AppCurrency.cad;

      expect(currencyUpdates, equals([AppCurrency.eur, AppCurrency.gbp, AppCurrency.cad]));

      // Toggle privacy
      container.read(privacyModeProvider.notifier).state = true;
      container.read(privacyModeProvider.notifier).state = false;

      expect(privacyUpdates, equals([true, false]));
    });
  });

  // ===========================================================================
  // SECTION 5: ADVERSARIAL FUZZING & MONTE CARLO INVARIANT TEST HARNESS
  // ===========================================================================
  group('Adversarial Stress 5: Fuzzing & Monte Carlo Invariants', () {
    test('Monte Carlo Fuzz Harness: 1,000 random currency conversions never crash or violate invariants', () {
      final rng = Random(42); // Deterministic seed for reproducible testing
      const iterations = 1000;
      final currencies = AppCurrency.values;

      for (int i = 0; i < iterations; i++) {
        final from = currencies[rng.nextInt(currencies.length)];
        final to = currencies[rng.nextInt(currencies.length)];

        // Generate values spanning -1e6 to 1e7, with some subnormals and edge values
        final rawExp = rng.nextDouble() * 12.0 - 4.0; // 10^-4 to 10^8
        final sign = rng.nextBool() ? 1.0 : -1.0;
        final amount = sign * pow(10.0, rawExp).toDouble();

        final converted = ExchangeRateService.convert(amount, from: from, to: to);

        if (amount <= 0.0) {
          expect(
            converted,
            equals(0.0),
            reason: 'convert must yield 0.0 for non-positive input: $amount',
          );
        } else {
          expect(
            converted,
            greaterThan(0.0),
            reason: 'convert must yield positive value for positive input: $amount',
          );
          expect(converted.isFinite, isTrue);
          expect(converted.isNaN, isFalse);

          // Verify round trip stability on random amounts
          final roundTrip = ExchangeRateService.convert(converted, from: to, to: from);
          final relErr = (roundTrip - amount).abs() / amount;
          expect(
            relErr,
            lessThan(1e-8),
            reason: 'Fuzzed round-trip precision loss for amount=$amount ($from -> $to -> $from)',
          );
        }
      }
    });

    test('Monte Carlo Fuzz Harness: 1,000 randomized formatAmount calls strictly satisfy format contracts', () {
      final rng = Random(99);
      const iterations = 1000;
      final currencies = AppCurrency.values;

      for (int i = 0; i < iterations; i++) {
        final currency = currencies[rng.nextInt(currencies.length)];
        final isPrivacy = rng.nextBool();
        final isNull = rng.nextDouble() < 0.1;
        final isSpecial = rng.nextDouble() < 0.05;

        double? amount;
        if (isNull) {
          amount = null;
        } else if (isSpecial) {
          final choice = rng.nextInt(3);
          amount = choice == 0 ? double.nan : (choice == 1 ? double.infinity : double.negativeInfinity);
        } else {
          final sign = rng.nextBool() ? 1.0 : -1.0;
          final exp = rng.nextDouble() * 10.0 - 2.0;
          amount = sign * pow(10.0, exp).toDouble();
        }

        final formatted = VaultPricingHelper.formatAmount(
          amount,
          currency: currency,
          isPrivacyMode: isPrivacy,
        );

        expect(formatted, isNotEmpty);
        expect(formatted.contains('NaN'), isFalse);
        expect(formatted.contains('Infinity'), isFalse);

        if (isPrivacy) {
          expect(formatted, equals('****'));
        } else {
          if (amount == null || amount.isNaN || amount.isInfinite || amount == 0.0) {
            expect(formatted, equals('Unlisted'));
          } else {
            // Must contain the currency symbol
            expect(
              formatted.contains(currency.symbol),
              isTrue,
              reason: 'Formatted amount "$formatted" must contain symbol "${currency.symbol}"',
            );
          }
        }
      }
    });
  });
}
