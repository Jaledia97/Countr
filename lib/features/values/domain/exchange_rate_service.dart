import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/state/settings_state.dart';

/// Centralized service managing cached foreign exchange rates, currency conversions,
/// and multi-market price normalization across Countr.
class ExchangeRateService {
  ExchangeRateService({
    Map<AppCurrency, double>? rates,
    DateTime? lastUpdated,
  })  : _instanceRates = rates != null ? Map.of(rates) : Map.of(defaultRatesToUsd),
        _instanceLastUpdated = lastUpdated ?? DateTime.now();

  /// Official daily baseline exchange rates relative to USD (1.0000 USD).
  ///
  /// - 1.000 USD = 1.0000 USD
  /// - 1.000 USD = 0.9200 EUR  (1 EUR ≈ 1.0870 USD)
  /// - 1.000 USD = 0.7850 GBP  (1 GBP ≈ 1.2739 USD)
  /// - 1.000 USD = 1.3600 CAD  (1 CAD ≈ 0.7353 USD)
  static const Map<AppCurrency, double> defaultRatesToUsd = {
    AppCurrency.usd: 1.0000,
    AppCurrency.eur: 0.9200,
    AppCurrency.gbp: 0.7850,
    AppCurrency.cad: 1.3600,
  };

  /// In-memory cached exchange rates. Defaults to [defaultRatesToUsd].
  static Map<AppCurrency, double> _cachedRates = Map.of(defaultRatesToUsd);

  /// Timestamp when static cached exchange rates were last synchronized.
  static DateTime _lastUpdated = DateTime.now();

  final Map<AppCurrency, double> _instanceRates;
  final DateTime _instanceLastUpdated;

  // ===========================================================================
  // Static Core Conversion API (Complies with PROJECT.md Contract)
  // ===========================================================================

  /// Calculates the exchange rate from [from] currency to [to] currency.
  ///
  /// Formula: `rates[to] / rates[from]`.
  static double getRate({
    required AppCurrency from,
    required AppCurrency to,
  }) {
    if (from == to) return 1.0;
    final rateFrom = _cachedRates[from] ?? defaultRatesToUsd[from] ?? 1.0;
    final rateTo = _cachedRates[to] ?? defaultRatesToUsd[to] ?? 1.0;
    if (rateFrom <= 0.0 || rateFrom.isNaN || rateFrom.isInfinite) return 1.0;
    return rateTo / rateFrom;
  }

  /// Converts [amount] from [from] currency into [to] currency.
  ///
  /// Returns `0.0` if [amount] is non-positive (<= 0.0), NaN, or infinite.
  static double convert(
    double amount, {
    required AppCurrency from,
    required AppCurrency to,
  }) {
    if (amount <= 0.0 || amount.isNaN || amount.isInfinite) {
      return 0.0;
    }
    if (from == to) {
      return amount;
    }
    final rate = getRate(from: from, to: to);
    return amount * rate;
  }

  /// Returns the canonical display symbol for [currency].
  ///
  /// - USD: `'$'`
  /// - EUR: `'€'`
  /// - GBP: `'£'`
  /// - CAD: `'CA$'`
  static String getCurrencySymbol(AppCurrency currency) {
    return currency.symbol;
  }

  // ===========================================================================
  // Multi-Market Normalization Engine
  // ===========================================================================

  /// Resolves the default native quoting currency for major collectible markets.
  ///
  /// - TCGplayer -> USD
  /// - Cardmarket (MKM) -> EUR
  /// - eBay -> USD
  static AppCurrency defaultCurrencyForMarket(String marketSource) {
    final lower = marketSource.toLowerCase().trim();
    if (lower.contains('cardmarket') || lower.contains('mkm') || lower == 'eur') {
      return AppCurrency.eur;
    }
    if (lower.contains('tcgplayer') || lower.contains('tcg') || lower.contains('ebay') || lower == 'usd') {
      return AppCurrency.usd;
    }
    if (lower.contains('cad') || lower.contains('face2face')) {
      return AppCurrency.cad;
    }
    if (lower.contains('gbp') || lower.contains('magicmadhouse')) {
      return AppCurrency.gbp;
    }
    return AppCurrency.usd;
  }

  /// Normalizes a single price quote from a named market source into [targetCurrency].
  ///
  /// Example:
  /// ```dart
  /// ExchangeRateService.normalizeMarketPrice(20.0, marketSource: 'Cardmarket', targetCurrency: AppCurrency.usd);
  /// ```
  static double normalizeMarketPrice(
    double amount, {
    required String marketSource,
    required AppCurrency targetCurrency,
  }) {
    final nativeCurrency = defaultCurrencyForMarket(marketSource);
    return convert(amount, from: nativeCurrency, to: targetCurrency);
  }

  /// Normalizes a map of vendor price quotes into [targetCurrency].
  ///
  /// [rawQuotes]: Map of vendor name to raw price (e.g. `{'tcgplayer': 25.0, 'cardmarket': 21.5}`).
  /// [vendorCurrencies]: Optional map overriding default currency detection per vendor.
  static Map<String, double> normalizeVendorQuotes(
    Map<String, double> rawQuotes, {
    required AppCurrency targetCurrency,
    Map<String, AppCurrency>? vendorCurrencies,
  }) {
    final normalized = <String, double>{};
    for (final entry in rawQuotes.entries) {
      final vendor = entry.key;
      final price = entry.value;
      final sourceCurrency = vendorCurrencies?[vendor] ?? defaultCurrencyForMarket(vendor);
      normalized[vendor] = convert(price, from: sourceCurrency, to: targetCurrency);
    }
    return normalized;
  }

  /// Normalizes a Scryfall price key (e.g. `'usd'`, `'usd_foil'`, `'eur'`, `'eur_foil'`)
  /// to the user's active [targetCurrency].
  static double normalizeScryfallPrice(
    double price, {
    required String priceKey,
    required AppCurrency targetCurrency,
  }) {
    final isEur = priceKey.toLowerCase().trim().startsWith('eur');
    final sourceCurrency = isEur ? AppCurrency.eur : AppCurrency.usd;
    return convert(price, from: sourceCurrency, to: targetCurrency);
  }

  // ===========================================================================
  // Cache Management & Freshness
  // ===========================================================================

  /// Human-readable freshness label (e.g. "Updated just now", "Updated 2h ago", "Updated today").
  static String get freshnessBadge {
    final diff = DateTime.now().difference(_lastUpdated);
    if (diff.inMinutes < 60) {
      return 'Updated just now';
    } else if (diff.inHours < 24) {
      return 'Updated ${diff.inHours}h ago';
    } else {
      return 'Updated today';
    }
  }

  /// Updates the cached exchange rates and refreshes the timestamp.
  static void updateRates(Map<AppCurrency, double> newRates) {
    _cachedRates = Map.of(newRates);
    _lastUpdated = DateTime.now();
  }

  /// Resets the static cached rates to default baseline values.
  static void resetToDefaults() {
    _cachedRates = Map.of(defaultRatesToUsd);
    _lastUpdated = DateTime.now();
  }

  /// Timestamp of the last static rate update.
  static DateTime get lastUpdated => _lastUpdated;

  // ===========================================================================
  // Instance Methods for Riverpod Service Pattern
  // ===========================================================================

  double convertInstance(double amount, {required AppCurrency from, required AppCurrency to}) {
    if (amount <= 0.0 || amount.isNaN || amount.isInfinite) return 0.0;
    if (from == to) return amount;
    final rateFrom = _instanceRates[from] ?? 1.0;
    final rateTo = _instanceRates[to] ?? 1.0;
    if (rateFrom <= 0.0) return 0.0;
    return amount * (rateTo / rateFrom);
  }

  String get instanceFreshnessBadge {
    final diff = DateTime.now().difference(_instanceLastUpdated);
    if (diff.inMinutes < 60) return 'Updated just now';
    if (diff.inHours < 24) return 'Updated ${diff.inHours}h ago';
    return 'Updated today';
  }
}

/// Riverpod Provider providing an instance of [ExchangeRateService].
final exchangeRateServiceProvider = Provider<ExchangeRateService>((ref) {
  return ExchangeRateService();
});
