// Copyright (c) 2026 Countr. All rights reserved.
// Comprehensive Opaque-Box E2E Test Suite for Phase 4.4 Values Engine & Privacy Mode.
// Follows the 4-Tier Specification in TEST_INFRA.md:
// - Tier 1: Feature Coverage (Currency, Trimmed Average, P&L, Privacy Redaction, Locked View, Streamer Lifecycle, Tokens)
// - Tier 2: Boundary & Corner Cases (Empty, Single, $0.02 Floor Boundary, Zero Cost Basis, Extreme Values)
// - Tier 3: Cross-Feature Combinations (Multi-Currency + Trimmed + P&L, Privacy + Streamer, Unlock Flow, Currency Switch)
// - Tier 4: Real-World MTG Card & Deck Workloads (Edgar Markov Pareto, Alpha Black Lotus Spread, Portfolio FX, Streamer OBS Flow)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'values_engine_test_contracts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ===========================================================================
  // TIER 1 - FEATURE COVERAGE (Core Behavior & Contract Verification)
  // ===========================================================================

  group('Tier 1 - Feature Coverage: Currency Normalization', () {
    test('T1.1.1: all four base currencies are supported with exact symbols and display names', () {
      expect(AppCurrency.usd.code, 'USD');
      expect(AppCurrency.usd.symbol, r'$');
      expect(AppCurrency.usd.displayName, 'US Dollar');

      expect(AppCurrency.eur.code, 'EUR');
      expect(AppCurrency.eur.symbol, '€');
      expect(AppCurrency.eur.displayName, 'Euro');

      expect(AppCurrency.gbp.code, 'GBP');
      expect(AppCurrency.gbp.symbol, '£');
      expect(AppCurrency.gbp.displayName, 'British Pound');

      expect(AppCurrency.cad.code, 'CAD');
      expect(AppCurrency.cad.symbol, r'CA$');
      expect(AppCurrency.cad.displayName, 'Canadian Dollar');
    });

    test('T1.1.2: AppCurrency.fromCode parses case-insensitively and falls back to USD', () {
      expect(AppCurrency.fromCode('usd'), AppCurrency.usd);
      expect(AppCurrency.fromCode('EUR'), AppCurrency.eur);
      expect(AppCurrency.fromCode('Gbp'), AppCurrency.gbp);
      expect(AppCurrency.fromCode('cad'), AppCurrency.cad);
      expect(AppCurrency.fromCode(''), AppCurrency.usd);
      expect(AppCurrency.fromCode(null), AppCurrency.usd);
      expect(AppCurrency.fromCode('invalid_code'), AppCurrency.usd);
    });

    test('T1.1.3: ExchangeRateService converts USD directly to EUR, GBP, and CAD', () {
      const amountUsd = 100.0;
      final eur = ExchangeRateService.convert(amountUsd, from: AppCurrency.usd, to: AppCurrency.eur);
      final gbp = ExchangeRateService.convert(amountUsd, from: AppCurrency.usd, to: AppCurrency.gbp);
      final cad = ExchangeRateService.convert(amountUsd, from: AppCurrency.usd, to: AppCurrency.cad);

      expect(eur, closeTo(92.00, 0.001));
      expect(gbp, closeTo(78.50, 0.001));
      expect(cad, closeTo(136.00, 0.001));
    });

    test('T1.1.4: ExchangeRateService converts EUR back to USD and cross-converts to GBP', () {
      const amountEur = 92.0;
      final usd = ExchangeRateService.convert(amountEur, from: AppCurrency.eur, to: AppCurrency.usd);
      final gbp = ExchangeRateService.convert(amountEur, from: AppCurrency.eur, to: AppCurrency.gbp);

      expect(usd, closeTo(100.00, 0.001));
      expect(gbp, closeTo(78.50, 0.001));
    });

    test('T1.1.5: ExchangeRateService returns identity rate for identical currencies', () {
      expect(ExchangeRateService.getRate(from: AppCurrency.usd, to: AppCurrency.usd), 1.0);
      expect(ExchangeRateService.convert(42.50, from: AppCurrency.usd, to: AppCurrency.usd), 42.50);
      expect(ExchangeRateService.convert(85.00, from: AppCurrency.eur, to: AppCurrency.eur), 85.00);
    });
  });

  group('Tier 1 - Feature Coverage: Trimmed Market Average', () {
    test('T1.2.1: returns raw value for single valid quote', () {
      final quotes = {'tcgplayer': 25.0};
      final currencies = {'tcgplayer': AppCurrency.usd};

      final avg = TrimmedMarketAverageCalculator.computeTrimmedAverage(
        rawQuotes: quotes,
        vendorCurrencies: currencies,
        targetCurrency: AppCurrency.usd,
      );

      expect(avg, 25.0);
    });

    test('T1.2.2: returns arithmetic mean for two valid quotes', () {
      final quotes = {'tcgplayer': 20.0, 'cardmarket': 30.0};
      final currencies = {'tcgplayer': AppCurrency.usd, 'cardmarket': AppCurrency.usd};

      final avg = TrimmedMarketAverageCalculator.computeTrimmedAverage(
        rawQuotes: quotes,
        vendorCurrencies: currencies,
        targetCurrency: AppCurrency.usd,
      );

      expect(avg, 25.0);
    });

    test('T1.2.3: returns arithmetic mean without trimming for 3 and 4 quotes', () {
      final quotes3 = {'v1': 10.0, 'v2': 20.0, 'v3': 30.0};
      final currencies3 = {'v1': AppCurrency.usd, 'v2': AppCurrency.usd, 'v3': AppCurrency.usd};

      final avg3 = TrimmedMarketAverageCalculator.computeTrimmedAverage(
        rawQuotes: quotes3,
        vendorCurrencies: currencies3,
        targetCurrency: AppCurrency.usd,
      );
      expect(avg3, 20.0);

      final quotes4 = {'v1': 10.0, 'v2': 20.0, 'v3': 30.0, 'v4': 40.0};
      final currencies4 = {'v1': AppCurrency.usd, 'v2': AppCurrency.usd, 'v3': AppCurrency.usd, 'v4': AppCurrency.usd};

      final avg4 = TrimmedMarketAverageCalculator.computeTrimmedAverage(
        rawQuotes: quotes4,
        vendorCurrencies: currencies4,
        targetCurrency: AppCurrency.usd,
      );
      expect(avg4, 25.0);
    });

    test('T1.2.4: symmetrically trims lowest and highest quote when N = 5', () {
      // Raw quotes: 5.0, 10.0, 12.0, 14.0, 100.0
      // Trim lowest (5.0) and highest (100.0) -> middle 3: 10, 12, 14 -> mean = 12.0
      final quotes = {
        'v1': 5.0,
        'v2': 10.0,
        'v3': 12.0,
        'v4': 14.0,
        'v5': 100.0,
      };
      final currencies = {
        'v1': AppCurrency.usd,
        'v2': AppCurrency.usd,
        'v3': AppCurrency.usd,
        'v4': AppCurrency.usd,
        'v5': AppCurrency.usd,
      };

      final avg = TrimmedMarketAverageCalculator.computeTrimmedAverage(
        rawQuotes: quotes,
        vendorCurrencies: currencies,
        targetCurrency: AppCurrency.usd,
      );

      expect(avg, 12.0);
    });

    test('T1.2.5: discards floor anomalies (quotes <= 0.02) prior to trimming', () {
      // Quotes: 0.01 (discarded), 0.02 (discarded), 10.0, 12.0, 14.0, 100.0
      // Remaining valid: 10.0, 12.0, 14.0, 100.0 (4 quotes)
      // For N=4, returns mean of remaining 4 quotes: (10 + 12 + 14 + 100) / 4 = 136 / 4 = 34.0
      final quotes = {
        'penny1': 0.01,
        'penny2': 0.02,
        'v1': 10.0,
        'v2': 12.0,
        'v3': 14.0,
        'v4': 100.0,
      };
      final currencies = {
        'penny1': AppCurrency.usd,
        'penny2': AppCurrency.usd,
        'v1': AppCurrency.usd,
        'v2': AppCurrency.usd,
        'v3': AppCurrency.usd,
        'v4': AppCurrency.usd,
      };

      final avg = TrimmedMarketAverageCalculator.computeTrimmedAverage(
        rawQuotes: quotes,
        vendorCurrencies: currencies,
        targetCurrency: AppCurrency.usd,
      );

      expect(avg, 34.0);
    });
  });

  group('Tier 1 - Feature Coverage: Cost Basis & P&L Math', () {
    test('T1.3.1: formats positive profit with green plus sign and percentage', () {
      const costBasis = 10.0;
      const marketPrice = 15.0;
      const delta = marketPrice - costBasis; // +5.00
      const pct = (delta / costBasis) * 100.0; // +50.0%

      final formatted = VaultPricingHelper.formatReturn(
        delta,
        pct,
        currency: AppCurrency.usd,
        isPrivacyMode: false,
      );

      expect(formatted, r'+$5.00 (+50.0%)');
    });

    test('T1.3.2: formats negative loss with minus sign and percentage', () {
      const costBasis = 20.0;
      const marketPrice = 15.0;
      const delta = marketPrice - costBasis; // -5.00
      const pct = (delta / costBasis) * 100.0; // -25.0%

      final formatted = VaultPricingHelper.formatReturn(
        delta,
        pct,
        currency: AppCurrency.usd,
        isPrivacyMode: false,
      );

      expect(formatted, r'-$5.00 (-25.0%)');
    });

    test('T1.3.3: formats break-even neutral P&L', () {
      final formatted = VaultPricingHelper.formatReturn(
        0.0,
        0.0,
        currency: AppCurrency.usd,
        isPrivacyMode: false,
      );

      expect(formatted, r'$0.00 (0.0%)');
    });

    test('T1.3.4: respects foreign currency symbols in P&L formatting', () {
      final eur = VaultPricingHelper.formatReturn(
        12.50,
        25.0,
        currency: AppCurrency.eur,
        isPrivacyMode: false,
      );
      final gbp = VaultPricingHelper.formatReturn(
        -8.25,
        -15.0,
        currency: AppCurrency.gbp,
        isPrivacyMode: false,
      );
      final cad = VaultPricingHelper.formatReturn(
        20.00,
        33.3,
        currency: AppCurrency.cad,
        isPrivacyMode: false,
      );

      expect(eur, '+€12.50 (+25.0%)');
      expect(gbp, '-£8.25 (-15.0%)');
      expect(cad, r'+CA$20.00 (+33.3%)');
    });
  });

  group('Tier 1 - Feature Coverage: Privacy Mode Redaction', () {
    test('T1.4.1: formatAmount returns verbatim **** when privacy mode is active', () {
      final unredacted = VaultPricingHelper.formatAmount(
        125.50,
        currency: AppCurrency.usd,
        isPrivacyMode: false,
      );
      final redacted = VaultPricingHelper.formatAmount(
        125.50,
        currency: AppCurrency.usd,
        isPrivacyMode: true,
      );

      expect(unredacted, r'$125.50');
      expect(redacted, '****');
    });

    test('T1.4.2: formatReturn returns verbatim **** when privacy mode is active', () {
      final unredacted = VaultPricingHelper.formatReturn(
        50.0,
        25.0,
        currency: AppCurrency.usd,
        isPrivacyMode: false,
      );
      final redacted = VaultPricingHelper.formatReturn(
        50.0,
        25.0,
        currency: AppCurrency.usd,
        isPrivacyMode: true,
      );

      expect(unredacted, r'+$50.00 (+25.0%)');
      expect(redacted, '****');
    });

    test('T1.4.3: unlisted prices format fallback when not in privacy mode, but still redact to **** when active', () {
      final fallbackUnredacted = VaultPricingHelper.formatAmount(
        null,
        currency: AppCurrency.usd,
        isPrivacyMode: false,
      );
      final fallbackRedacted = VaultPricingHelper.formatAmount(
        null,
        currency: AppCurrency.usd,
        isPrivacyMode: true,
      );

      expect(fallbackUnredacted, 'Unlisted');
      expect(fallbackRedacted, '****');
    });
  });

  group('Tier 1 - Feature Coverage: Locked Values Tab UI', () {
    testWidgets('T1.5.1: LockedValuesView renders verbatim locked message and unlock button', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: LockedValuesView(),
            ),
          ),
        ),
      );

      expect(
        find.text('Values hidden. Disable Privacy Mode to view market data.'),
        findsOneWidget,
      );
      expect(find.byType(ElevatedButton), findsOneWidget);
      expect(find.text('Disable Privacy Mode'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
    });
  });

  group('Tier 1 - Feature Coverage: Streamer Security Background Lock', () {
    test('T1.6.1: transitions to paused/inactive/hidden immediately lock privacy when streamer security enabled', () {
      final container = ProviderContainer(
        overrides: [
          privacyModeProvider.overrideWith((ref) => false),
          streamerSecurityEnabledProvider.overrideWith((ref) => true),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(privacyModeProvider), isFalse);

      // App transitions to background (paused)
      handleAppLifecycleState(
        state: AppLifecycleState.paused,
        privacyModeController: container.read(privacyModeProvider.notifier),
        streamerSecurityEnabled: true,
      );
      expect(container.read(privacyModeProvider), isTrue);

      // Reset
      container.read(privacyModeProvider.notifier).state = false;
      expect(container.read(privacyModeProvider), isFalse);

      // App transitions to inactive (focus lost)
      handleAppLifecycleState(
        state: AppLifecycleState.inactive,
        privacyModeController: container.read(privacyModeProvider.notifier),
        streamerSecurityEnabled: true,
      );
      expect(container.read(privacyModeProvider), isTrue);
    });

    test('T1.6.2: transitions to background do NOT lock privacy when streamer security is disabled', () {
      final container = ProviderContainer(
        overrides: [
          privacyModeProvider.overrideWith((ref) => false),
          streamerSecurityEnabledProvider.overrideWith((ref) => false),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(privacyModeProvider), isFalse);

      handleAppLifecycleState(
        state: AppLifecycleState.paused,
        privacyModeController: container.read(privacyModeProvider.notifier),
        streamerSecurityEnabled: false,
      );

      expect(container.read(privacyModeProvider), isFalse);
    });
  });

  group('Tier 1 - Feature Coverage: Deck Token Checklist Extractor', () {
    test('T1.7.1: extracts distinct tokens from card Oracle texts', () {
      final oracleTexts = [
        '{2}, {T}: Create a 0/0 colorless Construct artifact creature token with...',
        'Whenever an opponent casts a spell, create a Treasure token.',
        'Whenever Edgar Markov attacks, create a 1/1 black Vampire creature token with lifelink.',
        '{T}: Add {C}.', // No token
      ];

      final tokens = DeckTokenExtractor.extractRequiredTokens(oracleTexts);

      expect(tokens, contains('Construct'));
      expect(tokens, contains('Treasure'));
      expect(tokens, contains('Vampire'));
      expect(tokens.length, 3);
    });
  });

  // ===========================================================================
  // TIER 2 - BOUNDARY & CORNER CASES (Stress & Edge Testing)
  // ===========================================================================

  group('Tier 2 - Boundaries: Empty, Zero & Malformed Inputs', () {
    test('T2.1.1: empty quote map returns null for trimmed average', () {
      final avg = TrimmedMarketAverageCalculator.computeTrimmedAverage(
        rawQuotes: {},
        vendorCurrencies: {},
        targetCurrency: AppCurrency.usd,
      );
      expect(avg, isNull);
    });

    test('T2.1.2: quote map containing only negative or zero prices returns null', () {
      final quotes = {'v1': 0.0, 'v2': -10.0, 'v3': -0.05};
      final currencies = {'v1': AppCurrency.usd, 'v2': AppCurrency.usd, 'v3': AppCurrency.usd};

      final avg = TrimmedMarketAverageCalculator.computeTrimmedAverage(
        rawQuotes: quotes,
        vendorCurrencies: currencies,
        targetCurrency: AppCurrency.usd,
      );
      expect(avg, isNull);
    });

    test('T2.1.3: quote map containing NaN or Infinite prices discards them gracefully', () {
      final quotes = {
        'valid': 15.0,
        'nan': double.nan,
        'inf': double.infinity,
        'neg_inf': double.negativeInfinity,
      };
      final currencies = {
        'valid': AppCurrency.usd,
        'nan': AppCurrency.usd,
        'inf': AppCurrency.usd,
        'neg_inf': AppCurrency.usd,
      };

      final avg = TrimmedMarketAverageCalculator.computeTrimmedAverage(
        rawQuotes: quotes,
        vendorCurrencies: currencies,
        targetCurrency: AppCurrency.usd,
      );
      expect(avg, 15.0);
    });
  });

  group(r'Tier 2 - Boundaries: $0.02 Floor Threshold Precision', () {
    test('T2.2.1: quote of exactly 0.020000 is discarded as a floor anomaly', () {
      final quotes = {'floor': 0.020000, 'valid': 10.0};
      final currencies = {'floor': AppCurrency.usd, 'valid': AppCurrency.usd};

      final avg = TrimmedMarketAverageCalculator.computeTrimmedAverage(
        rawQuotes: quotes,
        vendorCurrencies: currencies,
        targetCurrency: AppCurrency.usd,
      );

      // Floor discarded, single quote remains -> 10.0
      expect(avg, 10.0);
    });

    test('T2.2.2: quote of 0.021 is preserved as above the floor anomaly limit', () {
      final quotes = {'validLow': 0.021, 'validHigh': 0.029};
      final currencies = {'validLow': AppCurrency.usd, 'validHigh': AppCurrency.usd};

      final avg = TrimmedMarketAverageCalculator.computeTrimmedAverage(
        rawQuotes: quotes,
        vendorCurrencies: currencies,
        targetCurrency: AppCurrency.usd,
      );

      expect(avg, closeTo(0.025, 0.0001));
    });

    test('T2.2.3: foreign quote below converted 0.02 floor is discarded', () {
      // 0.015 EUR converted to USD = 0.015 / 0.92 = 0.0163 USD <= 0.02 floor
      final quotes = {'cardmarket_penny': 0.015, 'tcg_valid': 5.0};
      final currencies = {'cardmarket_penny': AppCurrency.eur, 'tcg_valid': AppCurrency.usd};

      final avg = TrimmedMarketAverageCalculator.computeTrimmedAverage(
        rawQuotes: quotes,
        vendorCurrencies: currencies,
        targetCurrency: AppCurrency.usd,
      );

      expect(avg, 5.0);
    });
  });

  group('Tier 2 - Boundaries: Cost Basis & Return Edge Cases', () {
    test('T2.3.1: zero cost basis does not divide by zero or emit NaN/Infinity', () {
      const costBasis = 0.0;
      const marketPrice = 25.0;
      const delta = marketPrice - costBasis;
      // Formula: if cost basis <= 0, percentage is 0.0%
      final pct = (costBasis > 0) ? ((delta / costBasis) * 100.0) : 0.0;

      final formatted = VaultPricingHelper.formatReturn(
        delta,
        pct,
        currency: AppCurrency.usd,
        isPrivacyMode: false,
      );

      expect(formatted, r'+$25.00 (+0.0%)');
      expect(formatted.contains('NaN'), isFalse);
      expect(formatted.contains('Infinity'), isFalse);
    });

    test('T2.3.2: null delta or percentage formats graceful dash symbol', () {
      final formattedNullDelta = VaultPricingHelper.formatReturn(
        null,
        15.0,
        currency: AppCurrency.usd,
        isPrivacyMode: false,
      );
      final formattedNullPct = VaultPricingHelper.formatReturn(
        10.0,
        null,
        currency: AppCurrency.usd,
        isPrivacyMode: false,
      );

      expect(formattedNullDelta, '—');
      expect(formattedNullPct, '—');
    });

    test('T2.3.3: 100% loss (market price drops to 0.00)', () {
      const costBasis = 50.0;
      const marketPrice = 0.0;
      const delta = marketPrice - costBasis; // -50.0
      const pct = (delta / costBasis) * 100.0; // -100.0%

      final formatted = VaultPricingHelper.formatReturn(
        delta,
        pct,
        currency: AppCurrency.usd,
        isPrivacyMode: false,
      );

      expect(formatted, r'-$50.00 (-100.0%)');
    });
  });

  group('Tier 2 - Boundaries: Extreme Numerical Values', () {
    test(r'T2.4.1: massive value (Alpha Black Lotus $500,000.00) converts and trims correctly', () {
      final quotes = {
        'v1': 480000.0,
        'v2': 500000.0,
        'v3': 510000.0,
        'v4': 520000.0,
        'outlier_low': 100000.0,
        'outlier_high': 990000.0,
      };
      final currencies = {for (var k in quotes.keys) k: AppCurrency.usd};

      // 6 quotes: trims 1 lowest (100k) and 1 highest (990k)
      // Middle 4: 480k, 500k, 510k, 520k -> sum = 2,010,000 / 4 = 502,500.0
      final avg = TrimmedMarketAverageCalculator.computeTrimmedAverage(
        rawQuotes: quotes,
        vendorCurrencies: currencies,
        targetCurrency: AppCurrency.usd,
      );

      expect(avg, 502500.0);
    });

    test('T2.4.2: Pareto calculation with single item deck handles 100% concentration', () {
      final concentration = ParetoAnalyticsCalculator.computeConcentration(
        itemLineValues: [150.0],
        topK: 5,
      );
      expect(concentration, 100.0);
    });

    test('T2.4.3: Pareto calculation with all zero values returns 0.0%', () {
      final concentration = ParetoAnalyticsCalculator.computeConcentration(
        itemLineValues: [0.0, 0.0, 0.0],
        topK: 5,
      );
      expect(concentration, 0.0);
    });
  });

  // ===========================================================================
  // TIER 3 - CROSS-FEATURE COMBINATIONS (Interaction Workflows)
  // ===========================================================================

  group('Tier 3 - Cross-Feature Combinations', () {
    test('T3.1: Multi-currency conversion -> Trimmed average -> P&L return in CAD', () {
      // Vendors quote in different native currencies:
      // - TCGplayer: $100.00 USD -> in CAD: 100 * 1.36 = 136.00 CAD
      // - Cardmarket: €92.00 EUR -> in CAD: (92 / 0.92) * 1.36 = 136.00 CAD
      // - eBay UK: £78.50 GBP -> in CAD: (78.50 / 0.785) * 1.36 = 136.00 CAD
      // - Card Kingdom: $110.00 USD -> in CAD: 110 * 1.36 = 149.60 CAD
      // - Spurious Outlier: $250.00 USD -> in CAD: 250 * 1.36 = 340.00 CAD
      // - Corrupt Anomaly: $0.01 USD -> discarded
      final quotes = {
        'tcgplayer': 100.0,
        'cardmarket': 92.0,
        'ebay_uk': 78.50,
        'card_kingdom': 110.0,
        'outlier': 250.0,
        'corrupt': 0.01,
      };
      final currencies = {
        'tcgplayer': AppCurrency.usd,
        'cardmarket': AppCurrency.eur,
        'ebay_uk': AppCurrency.gbp,
        'card_kingdom': AppCurrency.usd,
        'outlier': AppCurrency.usd,
        'corrupt': AppCurrency.usd,
      };

      // Target currency is CAD
      final cadTrimmedAvg = TrimmedMarketAverageCalculator.computeTrimmedAverage(
        rawQuotes: quotes,
        vendorCurrencies: currencies,
        targetCurrency: AppCurrency.cad,
      );

      // Valid normalized CAD quotes: 136.0, 136.0, 136.0, 149.6, 340.0 (5 quotes)
      // Discard lowest (136.0) and highest (340.0) -> middle 3: 136.0, 136.0, 149.6
      // Sum = 421.6 / 3 = 140.5333... CAD
      expect(cadTrimmedAvg, isNotNull);
      expect(cadTrimmedAvg!, closeTo(140.533, 0.01));

      // Calculate user P&L in CAD against purchase price of 100.00 CAD
      const userCostBasisCad = 100.0;
      final cadDelta = cadTrimmedAvg - userCostBasisCad; // +40.53 CAD
      final cadPct = (cadDelta / userCostBasisCad) * 100.0; // +40.5%

      final formattedReturn = VaultPricingHelper.formatReturn(
        cadDelta,
        cadPct,
        currency: AppCurrency.cad,
        isPrivacyMode: false,
      );

      expect(formattedReturn, r'+CA$40.53 (+40.5%)');
    });

    test('T3.2: Privacy Mode toggle immediately conceals multi-currency P&L to ****', () {
      const delta = 40.53;
      const pct = 40.5;

      final visible = VaultPricingHelper.formatReturn(
        delta,
        pct,
        currency: AppCurrency.cad,
        isPrivacyMode: false,
      );
      expect(visible, r'+CA$40.53 (+40.5%)');

      // Enable Privacy Mode
      final concealed = VaultPricingHelper.formatReturn(
        delta,
        pct,
        currency: AppCurrency.cad,
        isPrivacyMode: true,
      );
      expect(concealed, '****');
    });

    testWidgets('T3.3: LockedValuesView unlock button toggles privacyModeProvider to false', (tester) async {
      final container = ProviderContainer(
        overrides: [
          privacyModeProvider.overrideWith((ref) => true),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(privacyModeProvider), isTrue);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: LockedValuesView(),
            ),
          ),
        ),
      );

      expect(find.text('Disable Privacy Mode'), findsOneWidget);

      // Tap unlock button
      await tester.tap(find.text('Disable Privacy Mode'));
      await tester.pumpAndSettle();

      // Privacy Mode should now be disabled
      expect(container.read(privacyModeProvider), isFalse);
    });

    test('T3.4: Currency preference switch while in Privacy Mode maintains **** without numeric leaks', () {
      final usdRedacted = VaultPricingHelper.formatAmount(
        100.0,
        currency: AppCurrency.usd,
        isPrivacyMode: true,
      );
      final eurRedacted = VaultPricingHelper.formatAmount(
        92.0,
        currency: AppCurrency.eur,
        isPrivacyMode: true,
      );
      final gbpRedacted = VaultPricingHelper.formatAmount(
        78.50,
        currency: AppCurrency.gbp,
        isPrivacyMode: true,
      );
      final cadRedacted = VaultPricingHelper.formatAmount(
        136.0,
        currency: AppCurrency.cad,
        isPrivacyMode: true,
      );

      expect(usdRedacted, '****');
      expect(eurRedacted, '****');
      expect(gbpRedacted, '****');
      expect(cadRedacted, '****');
    });
  });

  // ===========================================================================
  // TIER 4 - REAL-WORLD APPLICATION SCENARIOS (Card & Deck Workloads)
  // ===========================================================================

  group('Tier 4 - Real-World Scenarios: Edgar Markov Commander Deck (Pareto Concentration)', () {
    test('T4.1: Edgar Markov 100-card deck calculates Pareto distribution and ranked micro-list', () {
      // 100-card Commander deck breakdown:
      // Top 5 Heavy Hitters:
      // 1. Edgar Markov (Commander): $115.00
      // 2. Teferi's Protection: $42.00
      // 3. Demonic Tutor: $38.00
      // 4. Urza's Incubator: $30.00
      // 5. Bloodline Keeper: $25.00
      // Subtotal Top 5 = $250.00
      //
      // Remaining 95 cards: 95 cards totaling $150.00 (average ~$1.58 each)
      // Total Deck Value = $250.00 + $150.00 = $400.00
      final top5Values = [115.0, 42.0, 38.0, 30.0, 25.0];
      final other95Values = List<double>.filled(95, 150.0 / 95.0);
      final allDeckCardValues = [...top5Values, ...other95Values];

      expect(allDeckCardValues.length, 100);

      final concentration = ParetoAnalyticsCalculator.computeConcentration(
        itemLineValues: allDeckCardValues,
        topK: 5,
      );

      // Top 5 sum = 250.0, Total = 400.0 -> Concentration = (250 / 400) * 100 = 62.5%
      expect(concentration, closeTo(62.5, 0.001));

      final headline = ParetoAnalyticsCalculator.generateHeadline(concentration, topK: 5);
      expect(
        headline,
        "The top 5 cards represent 62.5% of this deck's total value.",
      );
    });
  });

  group('Tier 4 - Real-World Scenarios: Alpha Black Lotus Multi-Market Valuation', () {
    test('T4.2: Alpha Black Lotus multi-vendor market spread rejection, trimming, and P&L', () {
      // Real-world marketplace quotes:
      // - TCGplayer Market: $85,000.00 USD
      // - Cardmarket: €75,000.00 EUR (at 0.92 EUR/USD = 75,000 / 0.92 = $81,521.74 USD)
      // - eBay Sold: $92,000.00 USD
      // - Card Kingdom Retail: $95,000.00 USD
      // - PWCC Auction Premium: $110,000.00 USD
      // - Corrupt Floor Listing: $0.02 USD (rejected)
      final rawQuotes = {
        'tcgplayer': 85000.0,
        'cardmarket': 75000.0,
        'ebay_sold': 92000.0,
        'card_kingdom': 95000.0,
        'pwcc_premium': 110000.0,
        'corrupt_listing': 0.02,
      };
      final vendorCurrencies = {
        'tcgplayer': AppCurrency.usd,
        'cardmarket': AppCurrency.eur,
        'ebay_sold': AppCurrency.usd,
        'card_kingdom': AppCurrency.usd,
        'pwcc_premium': AppCurrency.usd,
        'corrupt_listing': AppCurrency.usd,
      };

      final trimmedAvg = TrimmedMarketAverageCalculator.computeTrimmedAverage(
        rawQuotes: rawQuotes,
        vendorCurrencies: vendorCurrencies,
        targetCurrency: AppCurrency.usd,
      );

      expect(trimmedAvg, isNotNull);

      // Floor 0.02 discarded.
      // Valid USD quotes sorted:
      // 1. $81,521.74 (Cardmarket EUR converted) -> Trimmed as lowest
      // 2. $85,000.00 (TCGplayer)
      // 3. $92,000.00 (eBay)
      // 4. $95,000.00 (Card Kingdom)
      // 5. $110,000.00 (PWCC) -> Trimmed as highest
      // Middle 3 average: (85,000 + 92,000 + 95,000) / 3 = 272,000 / 3 = $90,666.67
      expect(trimmedAvg!, closeTo(90666.67, 0.1));

      // Investor acquired this card years ago for $15,000.00 USD
      const purchasePrice = 15000.0;
      final dollarReturn = trimmedAvg - purchasePrice; // +$75,666.67
      final percentageReturn = (dollarReturn / purchasePrice) * 100.0; // +504.4%

      final formattedReturn = VaultPricingHelper.formatReturn(
        dollarReturn,
        percentageReturn,
        currency: AppCurrency.usd,
        isPrivacyMode: false,
      );

      expect(formattedReturn, r'+$75666.67 (+504.4%)');
    });
  });

  group('Tier 4 - Real-World Scenarios: Multi-Currency Global Portfolio Conversion', () {
    test('T4.3: portfolio of 10 items converts consistently across all 4 base currencies', () {
      // 10 portfolio items total $10,000.00 USD
      const usdTotal = 10000.0;

      final eurTotal = ExchangeRateService.convert(usdTotal, from: AppCurrency.usd, to: AppCurrency.eur);
      final gbpTotal = ExchangeRateService.convert(usdTotal, from: AppCurrency.usd, to: AppCurrency.gbp);
      final cadTotal = ExchangeRateService.convert(usdTotal, from: AppCurrency.usd, to: AppCurrency.cad);

      expect(eurTotal, closeTo(9200.0, 0.001));
      expect(gbpTotal, closeTo(7850.0, 0.001));
      expect(cadTotal, closeTo(13600.0, 0.001));

      // Formatted representations
      expect(VaultPricingHelper.formatAmount(usdTotal, currency: AppCurrency.usd, isPrivacyMode: false), r'$10000.00');
      expect(VaultPricingHelper.formatAmount(eurTotal, currency: AppCurrency.eur, isPrivacyMode: false), '€9200.00');
      expect(VaultPricingHelper.formatAmount(gbpTotal, currency: AppCurrency.gbp, isPrivacyMode: false), '£7850.00');
      expect(VaultPricingHelper.formatAmount(cadTotal, currency: AppCurrency.cad, isPrivacyMode: false), r'CA$13600.00');
    });
  });

  group('Tier 4 - Real-World Scenarios: Streamer Live Broadcast Lifecycle Flow', () {
    test('T4.4: live broadcast workflow auto-locks financial visibility upon backgrounding', () {
      final container = ProviderContainer(
        overrides: [
          privacyModeProvider.overrideWith((ref) => false),
          streamerSecurityEnabledProvider.overrideWith((ref) => true),
          baseCurrencyProvider.overrideWith((ref) => AppCurrency.usd),
        ],
      );
      addTearDown(container.dispose);

      // 1. Streamer begins broadcast: Privacy Mode is OFF, values are visible
      expect(container.read(privacyModeProvider), isFalse);
      expect(
        VaultPricingHelper.formatAmount(450.00, currency: container.read(baseCurrencyProvider), isPrivacyMode: container.read(privacyModeProvider)),
        r'$450.00',
      );

      // 2. Streamer alt-tabs to OBS or Discord (triggers AppLifecycleState.inactive / paused)
      handleAppLifecycleState(
        state: AppLifecycleState.paused,
        privacyModeController: container.read(privacyModeProvider.notifier),
        streamerSecurityEnabled: container.read(streamerSecurityEnabledProvider),
      );

      // 3. Privacy Mode is now automatically locked
      expect(container.read(privacyModeProvider), isTrue);

      // 4. Financial amounts are completely redacted
      expect(
        VaultPricingHelper.formatAmount(450.00, currency: container.read(baseCurrencyProvider), isPrivacyMode: container.read(privacyModeProvider)),
        '****',
      );

      // 5. Returns are completely redacted
      expect(
        VaultPricingHelper.formatReturn(120.00, 36.4, currency: container.read(baseCurrencyProvider), isPrivacyMode: container.read(privacyModeProvider)),
        '****',
      );
    });
  });

  group("Tier 4 - Real-World Scenarios: Gaea's Cradle Liquidity & Reserved List", () {
    test("T4.5: high-value Reserved List staple evaluates buylist cash out, liquidity tier, and warning badge", () {
      // Gaea's Cradle: Market price ~$800.00 USD, Reserved List = true
      const marketPrice = 800.0;
      const quantity = 1;

      // 1. High value (>= $50.00) applies 70% cash out ratio
      final cashOut = LiquidityAnalyticsCalculator.computeCashOutEstimate(
        marketPrice: marketPrice,
        quantity: quantity,
      );
      expect(cashOut, closeTo(560.00, 0.01)); // $800 * 0.70 = $560.00

      // 2. Liquidity tag evaluates to 'HIGH' (staple >= $5.00)
      final liquidityTag = LiquidityAnalyticsCalculator.evaluateLiquidityTag(
        marketPrice: marketPrice,
      );
      expect(liquidityTag, 'HIGH');

      // 3. User acquired at $200.00 -> Computes return
      const purchasePrice = 200.0;
      final delta = marketPrice - purchasePrice; // +$600.00
      final pct = (delta / purchasePrice) * 100.0; // +300.0%

      final returnLabel = VaultPricingHelper.formatReturn(
        delta,
        pct,
        currency: AppCurrency.usd,
        isPrivacyMode: false,
      );
      expect(returnLabel, r'+$600.00 (+300.0%)');
    });
  });

  group('Tier 4 - Real-World Scenarios: Mox Diamond 52-Week Range Gauge', () {
    test('T4.6: computes normalized position for 52-week price range slider', () {
      // Mox Diamond: 52-Week Low = $500.00, 52-Week High = $700.00
      // Current market price = $650.00
      // Range span = $700 - $500 = $200.00
      // Position = ($650 - $500) / $200 = 150 / 200 = 0.75 (75th percentile)
      final position = FiftyTwoWeekRangeCalculator.computeNormalizedPosition(
        currentPrice: 650.0,
        low52: 500.0,
        high52: 700.0,
      );

      expect(position, closeTo(0.75, 0.001));

      // Boundary: price at exact 52-week low
      final positionLow = FiftyTwoWeekRangeCalculator.computeNormalizedPosition(
        currentPrice: 500.0,
        low52: 500.0,
        high52: 700.0,
      );
      expect(positionLow, 0.0);

      // Boundary: price at exact 52-week high
      final positionHigh = FiftyTwoWeekRangeCalculator.computeNormalizedPosition(
        currentPrice: 700.0,
        low52: 500.0,
        high52: 700.0,
      );
      expect(positionHigh, 1.0);
    });
  });
}

