import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:countr/core/state/settings_state.dart';
import 'package:countr/features/values/domain/exchange_rate_service.dart';
import 'package:countr/features/values/domain/models/market_price_quote.dart';

/// Pure mathematical calculation service for anomaly filtering, multi-source
/// currency normalization, and symmetrical outlier trimming.
class TrimmedAverageCalculator {
  TrimmedAverageCalculator._();

  /// Floor threshold below which quotes are discarded as corrupt, placeholder, or penny bids.
  /// Set to 0.02001 to strictly discard values <= 0.02 while preserving valid quotes at 0.021+.
  static const double floorAnomalyThreshold = 0.02001;

  /// Canonical minimum floor price constant matching PROJECT.md interface contract.
  static const double minimumFloorPrice = 0.02;

  // ===========================================================================
  // 1. Floor Anomaly Rejection
  // ===========================================================================

  /// Returns true if [price] represents an invalid, non-positive, or floor anomaly quote.
  static bool isFloorAnomaly(double? price, {double threshold = floorAnomalyThreshold}) {
    if (price == null || price.isNaN || price.isInfinite || price <= 0.0) {
      return true;
    }
    return price <= threshold;
  }

  // ===========================================================================
  // 2. Symmetrical Trimming Core Math
  // ===========================================================================

  /// Computes the trimmed mean of a pre-filtered list of normalized positive prices.
  ///
  /// Mathematical Rules:
  /// - N = 0: Returns [fallback]
  /// - N = 1: Returns p1
  /// - N = 2: Returns (p1 + p2) / 2
  /// - N in [3, 4]: Returns arithmetic mean (sum / N)
  /// - 5 <= N < 10: Sorts ascending, trims 1 lowest and 1 highest (k = 1), returns mean of middle N - 2
  /// - N >= 10: Sorts ascending, trims k = floor(0.10 * N) from both ends, returns mean of remaining slice
  static double computeTrimmedMean(
    List<double> validNormalizedPrices, {
    double fallback = 0.0,
  }) {
    final n = validNormalizedPrices.length;
    if (n == 0) return fallback;
    if (n == 1) return validNormalizedPrices.first;
    if (n == 2) return (validNormalizedPrices[0] + validNormalizedPrices[1]) / 2.0;

    // Sort ascending for trimming: p(1) <= p(2) <= ... <= p(N)
    final sorted = List<double>.of(validNormalizedPrices)..sort();

    if (n == 3 || n == 4) {
      final sum = sorted.reduce((a, b) => a + b);
      return sum / n;
    }

    // Determine trimming depth k
    final int k = (n >= 10) ? (0.10 * n).floor() : 1;
    final trimmedSlice = sorted.sublist(k, n - k);
    if (trimmedSlice.isEmpty) return fallback;

    final sum = trimmedSlice.reduce((a, b) => a + b);
    return sum / trimmedSlice.length;
  }

  // ===========================================================================
  // 3. High-Level Quote Map API (PROJECT.md Interface Contract)
  // ===========================================================================

  /// Computes the trimmed market average across raw multi-market quotes.
  ///
  /// Complies with `TrimmedMarketAverageCalculator.computeTrimmedAverage` contract.
  static double? computeTrimmedAverage({
    required Map<String, double> rawQuotes,
    required Map<String, AppCurrency> vendorCurrencies,
    required AppCurrency targetCurrency,
    Map<AppCurrency, double>? customRates,
    double threshold = floorAnomalyThreshold,
  }) {
    final validNormalized = <double>[];

    for (final entry in rawQuotes.entries) {
      final vendor = entry.key;
      final rawPrice = entry.value;

      if (rawPrice.isNaN || rawPrice.isInfinite || rawPrice <= 0.0) {
        continue;
      }

      final sourceCurrency = vendorCurrencies[vendor] ??
          ExchangeRateService.defaultCurrencyForMarket(vendor);

      final double normalized;
      if (customRates != null) {
        if (sourceCurrency == targetCurrency) {
          normalized = rawPrice;
        } else {
          final rateFrom = customRates[sourceCurrency] ?? 1.0;
          final rateTo = customRates[targetCurrency] ?? 1.0;
          normalized = rateFrom > 0.0 ? rawPrice * (rateTo / rateFrom) : 0.0;
        }
      } else {
        normalized = ExchangeRateService.convert(
          rawPrice,
          from: sourceCurrency,
          to: targetCurrency,
        );
      }

      // Floor anomaly rejection rule
      if (normalized <= threshold) {
        continue;
      }

      validNormalized.add(normalized);
    }

    if (validNormalized.isEmpty) return null;
    return computeTrimmedMean(validNormalized);
  }

  // ===========================================================================
  // 4. Domain Model List API
  // ===========================================================================

  /// Computes the trimmed average from a strongly-typed list of [MarketPriceQuote]s.
  static double computeFromQuotes(
    List<MarketPriceQuote> quotes, {
    double fallback = 0.0,
    double threshold = floorAnomalyThreshold,
  }) {
    final validPrices = quotes
        .where((q) => q.isValid && !q.isFloorAnomaly(threshold: threshold))
        .map((q) => q.convertedAmount)
        .toList();

    return computeTrimmedMean(validPrices, fallback: fallback);
  }

  // ===========================================================================
  // 5. Scryfall DynamicData Payload Aggregation
  // ===========================================================================

  /// Extracts individual [MarketPriceQuote]s from a Scryfall card payload (`dynamicData` JSON or Map).
  ///
  /// Maps Scryfall keys:
  /// - `'usd'` -> TCGplayer Market (USD)
  /// - `'usd_foil'` -> TCGplayer Foil (USD)
  /// - `'usd_etched'` -> TCGplayer Etched (USD)
  /// - `'eur'` -> Cardmarket Market (EUR)
  /// - `'eur_foil'` -> Cardmarket Foil (EUR)
  static List<MarketPriceQuote> extractQuotesFromPayload(
    dynamic dynamicData, {
    required AppCurrency targetCurrency,
    DateTime? timestamp,
    Map<AppCurrency, double>? rates,
  }) {
    final quotes = <MarketPriceQuote>[];
    if (dynamicData == null) return quotes;

    Map<dynamic, dynamic>? payloadMap;
    if (dynamicData is Map) {
      payloadMap = dynamicData;
    } else if (dynamicData is String && dynamicData.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(dynamicData);
        if (decoded is Map) {
          payloadMap = decoded;
        }
      } catch (e) {
        debugPrint('[TrimmedAverageCalculator] Failed to decode dynamicData: $e');
        return quotes;
      }
    }

    if (payloadMap == null) return quotes;

    // Check root 'prices' map or first face if double-sided
    Map<dynamic, dynamic>? pricesMap;
    if (payloadMap['prices'] is Map) {
      pricesMap = payloadMap['prices'] as Map;
    } else if (payloadMap['card_faces'] is List && (payloadMap['card_faces'] as List).isNotEmpty) {
      final firstFace = (payloadMap['card_faces'] as List)[0];
      if (firstFace is Map && firstFace['prices'] is Map) {
        pricesMap = firstFace['prices'] as Map;
      }
    }

    if (pricesMap == null || pricesMap.isEmpty) return quotes;

    final captureTime = timestamp ?? DateTime.now();

    void addQuoteIfValid(String key, String vendor, MarketQuoteType type, AppCurrency nativeCurr) {
      final rawStr = pricesMap?[key]?.toString().trim();
      if (rawStr == null || rawStr.isEmpty) return;
      final parsed = double.tryParse(rawStr);
      if (parsed != null && !parsed.isNaN && !parsed.isInfinite && parsed > 0.0) {
        quotes.add(
          MarketPriceQuote.fromRaw(
            vendor: vendor,
            quoteType: type,
            rawAmount: parsed,
            currency: nativeCurr,
            baseCurrency: targetCurrency,
            timestamp: captureTime,
            rates: rates,
          ),
        );
      }
    }

    // TCGplayer Quotes (USD)
    addQuoteIfValid('usd', 'TCGplayer Market', MarketQuoteType.market, AppCurrency.usd);
    addQuoteIfValid('usd_foil', 'TCGplayer Foil', MarketQuoteType.market, AppCurrency.usd);
    addQuoteIfValid('usd_etched', 'TCGplayer Etched', MarketQuoteType.market, AppCurrency.usd);

    // Cardmarket Quotes (EUR)
    addQuoteIfValid('eur', 'Cardmarket Trend', MarketQuoteType.market, AppCurrency.eur);
    addQuoteIfValid('eur_foil', 'Cardmarket Foil', MarketQuoteType.market, AppCurrency.eur);

    return quotes;
  }

  /// High-level method extracting and computing the trimmed market average directly from card payload.
  static double computeFromPayload(
    dynamic dynamicData, {
    required AppCurrency targetCurrency,
    double fallback = 0.0,
    Map<AppCurrency, double>? rates,
  }) {
    final quotes = extractQuotesFromPayload(
      dynamicData,
      targetCurrency: targetCurrency,
      rates: rates,
    );
    return computeFromQuotes(quotes, fallback: fallback);
  }
}

/// Alias class ensuring 100% contract compliance with PROJECT.md and E2E test contracts.
class TrimmedMarketAverageCalculator {
  TrimmedMarketAverageCalculator._();

  static const double minimumFloorPrice = TrimmedAverageCalculator.minimumFloorPrice;

  static double? computeTrimmedAverage({
    required Map<String, double> rawQuotes,
    required Map<String, AppCurrency> vendorCurrencies,
    required AppCurrency targetCurrency,
    Map<AppCurrency, double>? customRates,
  }) {
    return TrimmedAverageCalculator.computeTrimmedAverage(
      rawQuotes: rawQuotes,
      vendorCurrencies: vendorCurrencies,
      targetCurrency: targetCurrency,
      customRates: customRates,
    );
  }
}
