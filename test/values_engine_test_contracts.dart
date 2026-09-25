// Copyright (c) 2026 Countr. All rights reserved.
// Opaque-box contract interfaces, models, and reference implementation
// for Phase 4.4 Values Engine, Settings, and Privacy Security.
// Derived strictly from PROJECT.md § Interface Contracts & ORIGINAL_REQUEST.md.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Supported base currencies for Countr portfolio valuations and market analysis.
enum AppCurrency {
  usd('USD', r'$', 'US Dollar'),
  eur('EUR', '€', 'Euro'),
  gbp('GBP', '£', 'British Pound'),
  cad('CAD', r'CA$', 'Canadian Dollar');

  /// Standard 3-letter ISO-4217 currency code.
  final String code;

  /// Display symbol for prices (e.g. '$', '€', '£', 'CA$').
  final String symbol;

  /// English human-readable currency name.
  final String displayName;

  const AppCurrency(this.code, this.symbol, this.displayName);

  /// Safe parser converting case-insensitive ISO strings or enum names into [AppCurrency].
  ///
  /// Defaults to [AppCurrency.usd] for null, unrecognized, or empty strings.
  static AppCurrency fromCode(String? code) {
    if (code == null || code.trim().isEmpty) {
      return AppCurrency.usd;
    }
    final normalized = code.trim().toLowerCase();
    for (final c in AppCurrency.values) {
      if (c.code.toLowerCase() == normalized ||
          c.name.toLowerCase() == normalized) {
        return c;
      }
    }
    return AppCurrency.usd;
  }
}

/// Global Riverpod StateProvider holding the user's selected base currency.
final baseCurrencyProvider = StateProvider<AppCurrency>((ref) {
  return AppCurrency.usd;
});

/// Global Riverpod StateProvider tracking whether Privacy Mode is active.
final privacyModeProvider = StateProvider<bool>((ref) {
  return false;
});

/// Global Riverpod StateProvider for Streamer Security.
final streamerSecurityEnabledProvider = StateProvider<bool>((ref) {
  return false;
});

/// Core Exchange Rate Service providing multi-currency normalization and cached FX rates.
class ExchangeRateService {
  /// Daily reference exchange rates relative to USD (1.0000 USD).
  static const Map<AppCurrency, double> defaultRatesToUsd = {
    AppCurrency.usd: 1.0000,
    AppCurrency.eur: 0.9200, // 1 USD = 0.92 EUR  (1 EUR ≈ 1.0869565 USD)
    AppCurrency.gbp: 0.7850, // 1 USD = 0.785 GBP (1 GBP ≈ 1.2738853 USD)
    AppCurrency.cad: 1.3600, // 1 USD = 1.36 CAD  (1 CAD ≈ 0.7352941 USD)
  };

  final Map<AppCurrency, double> rates;
  final DateTime lastUpdated;

  ExchangeRateService({
    Map<AppCurrency, double>? rates,
    DateTime? lastUpdated,
  })  : rates = rates ?? defaultRatesToUsd,
        lastUpdated = lastUpdated ?? DateTime.now();

  /// Static method to get conversion rate from [from] currency to [to] currency.
  static double getRate({
    required AppCurrency from,
    required AppCurrency to,
    Map<AppCurrency, double>? rates,
  }) {
    if (from == to) return 1.0;
    final r = rates ?? defaultRatesToUsd;
    final rateFrom = r[from] ?? 1.0;
    final rateTo = r[to] ?? 1.0;
    return rateTo / rateFrom;
  }

  /// Converts [amount] from [from] currency into [to] currency.
  static double convert(
    double amount, {
    required AppCurrency from,
    required AppCurrency to,
    Map<AppCurrency, double>? rates,
  }) {
    if (from == to) return amount;
    if (amount <= 0.0 || amount.isNaN || amount.isInfinite) return 0.0;
    final rateMultiplier = getRate(from: from, to: to, rates: rates);
    return amount * rateMultiplier;
  }

  /// Returns the standard display symbol for [currency].
  static String getCurrencySymbol(AppCurrency currency) {
    return currency.symbol;
  }

  /// Freshness badge string describing age of exchange rate cache.
  String get freshnessBadge {
    final diff = DateTime.now().difference(lastUpdated);
    if (diff.inMinutes < 60) return 'Updated just now';
    if (diff.inHours < 24) return 'Updated ${diff.inHours}h ago';
    return 'Updated today';
  }
}

/// Upgraded pricing helper supporting dynamic currency formatting and privacy redaction.
class VaultPricingHelper {
  VaultPricingHelper._();

  static const String unlistedLabel = 'Unlisted';
  static const String redactedPlaceholder = '****';

  /// Formats a monetary [amount] in the specified [currency].
  ///
  /// Redacts to [redactedPlaceholder] ('****') if [isPrivacyMode] is true.
  static String formatAmount(
    double? amount, {
    required AppCurrency currency,
    required bool isPrivacyMode,
    String fallback = unlistedLabel,
  }) {
    if (isPrivacyMode) {
      return redactedPlaceholder;
    }
    if (amount == null || amount.isNaN || amount.isInfinite || amount <= 0.0) {
      return fallback;
    }
    return '${currency.symbol}${amount.toStringAsFixed(2)}';
  }

  /// Formats profit & loss returns (absolute dollar return and percentage return).
  ///
  /// Redacts to [redactedPlaceholder] ('****') if [isPrivacyMode] is true.
  static String formatReturn(
    double? delta,
    double? percentage, {
    required AppCurrency currency,
    required bool isPrivacyMode,
  }) {
    if (isPrivacyMode) {
      return redactedPlaceholder;
    }
    if (delta == null || percentage == null || delta.isNaN || percentage.isNaN) {
      return '—';
    }
    final sym = currency.symbol;
    final pctStr = percentage.toStringAsFixed(1);
    if (delta > 0.0) {
      return '+$sym${delta.toStringAsFixed(2)} (+$pctStr%)';
    } else if (delta < 0.0) {
      return '-$sym${delta.abs().toStringAsFixed(2)} ($pctStr%)';
    } else {
      return '$sym${delta.toStringAsFixed(2)} (0.0%)';
    }
  }
}

/// Robust multi-source trimmed market average calculator.
///
/// Discards floor anomalies (p <= $0.02) and applies symmetrical outlier trimming
/// across normalized currency market quotes.
class TrimmedMarketAverageCalculator {
  TrimmedMarketAverageCalculator._();

  /// Floor threshold below which quotes are treated as corrupt, placeholder, or penny bids.
  static const double minimumFloorPrice = 0.02;

  /// Computes the trimmed market average across raw multi-market quotes.
  static double? computeTrimmedAverage({
    required Map<String, double> rawQuotes,
    required Map<String, AppCurrency> vendorCurrencies,
    required AppCurrency targetCurrency,
    Map<AppCurrency, double>? customRates,
  }) {
    final validNormalized = <double>[];

    for (final entry in rawQuotes.entries) {
      final vendor = entry.key;
      final rawPrice = entry.value;

      if (rawPrice.isNaN || rawPrice.isInfinite || rawPrice <= 0.0) {
        continue;
      }

      final sourceCurrency = vendorCurrencies[vendor] ?? AppCurrency.usd;
      final normalized = ExchangeRateService.convert(
        rawPrice,
        from: sourceCurrency,
        to: targetCurrency,
        rates: customRates,
      );

      // Floor anomaly rejection rule: discard p <= $0.02 (with floating tolerance)
      if (normalized <= (minimumFloorPrice + 1e-6)) {
        continue;
      }

      validNormalized.add(normalized);
    }

    final n = validNormalized.length;
    if (n == 0) return null;
    if (n == 1) return validNormalized.first;
    if (n == 2) return (validNormalized[0] + validNormalized[1]) / 2.0;

    validNormalized.sort();

    if (n == 3 || n == 4) {
      final sum = validNormalized.reduce((a, b) => a + b);
      return sum / n;
    }

    // Symmetrical trimming for N >= 5
    // k = 1 for 5 <= N < 10, k = floor(0.10 * N) for N >= 10
    final int k = (n >= 10) ? (0.10 * n).floor() : 1;
    final trimmedSlice = validNormalized.sublist(k, n - k);
    final sum = trimmedSlice.reduce((a, b) => a + b);
    return sum / trimmedSlice.length;
  }
}

/// Pareto distribution concentration analytics ("Heavy Hitters").
class ParetoAnalyticsCalculator {
  ParetoAnalyticsCalculator._();

  /// Computes the Pareto concentration percentage of the top [topK] items.
  static double computeConcentration({
    required List<double> itemLineValues,
    int topK = 5,
  }) {
    final valid = itemLineValues.where((v) => !v.isNaN && v > 0.0).toList();
    if (valid.isEmpty) return 0.0;

    valid.sort((a, b) => b.compareTo(a)); // descending
    final total = valid.reduce((a, b) => a + b);
    if (total <= 0.0) return 0.0;

    final k = (topK > valid.length) ? valid.length : topK;
    final topSum = valid.sublist(0, k).reduce((a, b) => a + b);
    return (topSum / total) * 100.0;
  }

  /// Generates the standard headline string for Pareto deck concentration.
  static String generateHeadline(
    double concentrationPercentage, {
    int topK = 5,
  }) {
    return "The top $topK cards represent ${concentrationPercentage.toStringAsFixed(1)}% of this deck's total value.";
  }
}

/// Deck Oracle text parser for auto-generating physical token checklists.
class DeckTokenExtractor {
  DeckTokenExtractor._();

  static final RegExp _tokenRegex = RegExp(
    r'create[s]?\s+(?:a|an|\d+|X)?\s*([A-Za-z0-9\s—/\-]+?)\s+(?:artifact\s+|creature\s+|enchantment\s+)?token',
    caseSensitive: false,
  );

  static const Set<String> _descriptors = {
    'artifact',
    'creature',
    'enchantment',
    'token',
    'tokens',
    'colorless',
    'white',
    'blue',
    'black',
    'red',
    'green',
    'tapped',
    'attacking',
    'legendary',
  };

  /// Extracts unique token names required by cards in the deck.
  static List<String> extractRequiredTokens(List<String> oracleTexts) {
    final tokens = <String>{};

    for (final text in oracleTexts) {
      final matches = _tokenRegex.allMatches(text);
      for (final match in matches) {
        final captured = match.group(1)?.trim();
        if (captured != null && captured.isNotEmpty) {
          final words = captured.split(RegExp(r'\s+'));
          final candidates = words.where((w) {
            final lower = w.toLowerCase();
            if (_descriptors.contains(lower)) return false;
            if (RegExp(r'^\d+/\d+$').hasMatch(w)) return false;
            if (lower == 'a' || lower == 'an' || lower == 'that') return false;
            return true;
          }).toList();

          if (candidates.isNotEmpty) {
            tokens.add(candidates.last);
          }
        }
      }
    }

    final result = tokens.toList()..sort();
    return result;
  }
}

/// Widget rendered when the [Values] tab is accessed while Privacy Mode is active.
class LockedValuesView extends ConsumerWidget {
  const LockedValuesView({super.key});

  static const String lockedMessage =
      'Values hidden. Disable Privacy Mode to view market data.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.lock_outline_rounded,
              size: 48,
              color: Colors.amber,
            ),
            const SizedBox(height: 16),
            const Text(
              lockedMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                ref.read(privacyModeProvider.notifier).state = false;
              },
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.visibility_rounded),
                  SizedBox(width: 8),
                  Text('Disable Privacy Mode'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Handles app lifecycle state transitions to auto-lock privacy when streamer security is active.
void handleAppLifecycleState({
  required AppLifecycleState state,
  required StateController<bool> privacyModeController,
  required bool streamerSecurityEnabled,
}) {
  if (!streamerSecurityEnabled) return;

  if (state == AppLifecycleState.paused ||
      state == AppLifecycleState.inactive ||
      state == AppLifecycleState.hidden) {
    privacyModeController.state = true;
  }
}

/// Liquidity and Reality Check analytics.
class LiquidityAnalyticsCalculator {
  LiquidityAnalyticsCalculator._();

  /// Computes buylist cash out estimate based on market price tiers.
  static double computeCashOutEstimate({
    required double marketPrice,
    int quantity = 1,
  }) {
    if (marketPrice <= 0.0 || quantity <= 0) return 0.0;
    final double ratio;
    if (marketPrice >= 50.0) {
      ratio = 0.70;
    } else if (marketPrice >= 10.0) {
      ratio = 0.60;
    } else if (marketPrice >= 2.0) {
      ratio = 0.45;
    } else {
      ratio = 0.25;
    }
    return marketPrice * ratio * quantity;
  }

  /// Evaluates liquidity tier: 'HIGH' or 'LOW'.
  static String evaluateLiquidityTag({required double marketPrice}) {
    return (marketPrice >= 5.0) ? 'HIGH' : 'LOW';
  }
}

/// 52-week price range position calculator.
class FiftyTwoWeekRangeCalculator {
  FiftyTwoWeekRangeCalculator._();

  /// Computes normalized position (0.0 to 1.0) of current price within 52-week low and high.
  static double computeNormalizedPosition({
    required double currentPrice,
    required double low52,
    required double high52,
  }) {
    final range = high52 - low52;
    if (range <= 0.0) return 0.5;
    return ((currentPrice - low52) / range).clamp(0.0, 1.0);
  }
}

