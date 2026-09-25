import 'package:flutter/foundation.dart';
import 'package:countr/core/state/settings_state.dart';
import 'package:countr/features/values/domain/exchange_rate_service.dart';

/// The market categorization of a price quote.
enum MarketQuoteType {
  /// General aggregate secondary market price (e.g., TCGplayer Market, Cardmarket Trend).
  market('Market'),

  /// Direct secondary retailer buy-now price (e.g., Card Kingdom retail, Star City Games).
  retail('Retail'),

  /// Cash dealer purchase price for immediate liquidation (e.g., Card Kingdom Buylist, TCG Buylist).
  buylist('Buylist'),

  /// Direct marketplace fulfillment channel (e.g., TCGplayer Direct, Cardmarket Direct).
  direct('Direct');

  final String displayName;
  const MarketQuoteType(this.displayName);

  static MarketQuoteType fromString(String? value) {
    if (value == null) return MarketQuoteType.market;
    final normalized = value.trim().toLowerCase();
    for (final type in MarketQuoteType.values) {
      if (type.name.toLowerCase() == normalized ||
          type.displayName.toLowerCase() == normalized) {
        return type;
      }
    }
    return MarketQuoteType.market;
  }
}

/// A standardized price quote from a specific marketplace vendor.
@immutable
class MarketPriceQuote {
  /// The canonical vendor or source name (e.g., 'tcgplayer', 'cardmarket', 'ebay', 'card_kingdom').
  final String vendor;

  /// The categorization of this quote (market, retail, buylist, direct).
  final MarketQuoteType quoteType;

  /// The raw quote amount in the vendor's native currency.
  final double rawAmount;

  /// The native currency in which the quote was issued.
  final AppCurrency currency;

  /// The normalized price converted into the user's active base currency.
  final double convertedAmount;

  /// The active base currency target for [convertedAmount].
  final AppCurrency baseCurrency;

  /// The timestamp when this quote was fetched or captured.
  final DateTime timestamp;

  const MarketPriceQuote({
    required this.vendor,
    required this.quoteType,
    required this.rawAmount,
    required this.currency,
    required this.convertedAmount,
    required this.baseCurrency,
    required this.timestamp,
  });

  /// Factory constructor that automatically performs currency normalization.
  factory MarketPriceQuote.fromRaw({
    required String vendor,
    required MarketQuoteType quoteType,
    required double rawAmount,
    required AppCurrency currency,
    required AppCurrency baseCurrency,
    DateTime? timestamp,
    Map<AppCurrency, double>? rates,
  }) {
    final double converted;
    if (rates != null) {
      if (currency == baseCurrency) {
        converted = rawAmount > 0.0 && !rawAmount.isNaN && !rawAmount.isInfinite ? rawAmount : 0.0;
      } else if (rawAmount <= 0.0 || rawAmount.isNaN || rawAmount.isInfinite) {
        converted = 0.0;
      } else {
        final rateFrom = rates[currency] ?? 1.0;
        final rateTo = rates[baseCurrency] ?? 1.0;
        converted = rateFrom > 0.0 ? rawAmount * (rateTo / rateFrom) : 0.0;
      }
    } else {
      converted = ExchangeRateService.convert(
        rawAmount,
        from: currency,
        to: baseCurrency,
      );
    }

    return MarketPriceQuote(
      vendor: vendor,
      quoteType: quoteType,
      rawAmount: rawAmount,
      currency: currency,
      convertedAmount: converted,
      baseCurrency: baseCurrency,
      timestamp: timestamp ?? DateTime.now(),
    );
  }

  /// Whether this quote represents a finite, strictly positive price.
  bool get isValid =>
      !rawAmount.isNaN &&
      !rawAmount.isInfinite &&
      rawAmount > 0.0 &&
      !convertedAmount.isNaN &&
      !convertedAmount.isInfinite &&
      convertedAmount > 0.0;

  /// Whether this quote is considered a penny/floor anomaly ($p \le \$0.02$).
  /// Threshold defaults to 0.02001 to absorb floating point precision drift.
  bool isFloorAnomaly({double threshold = 0.02001}) =>
      !isValid || convertedAmount <= threshold;

  /// Creates a copy of this quote with updated fields.
  MarketPriceQuote copyWith({
    String? vendor,
    MarketQuoteType? quoteType,
    double? rawAmount,
    AppCurrency? currency,
    double? convertedAmount,
    AppCurrency? baseCurrency,
    DateTime? timestamp,
  }) {
    return MarketPriceQuote(
      vendor: vendor ?? this.vendor,
      quoteType: quoteType ?? this.quoteType,
      rawAmount: rawAmount ?? this.rawAmount,
      currency: currency ?? this.currency,
      convertedAmount: convertedAmount ?? this.convertedAmount,
      baseCurrency: baseCurrency ?? this.baseCurrency,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  /// JSON serialization.
  Map<String, dynamic> toJson() => {
        'vendor': vendor,
        'quote_type': quoteType.name,
        'raw_amount': rawAmount,
        'currency': currency.code,
        'converted_amount': convertedAmount,
        'base_currency': baseCurrency.code,
        'timestamp': timestamp.toIso8601String(),
      };

  /// JSON deserialization.
  factory MarketPriceQuote.fromJson(Map<String, dynamic> json) {
    return MarketPriceQuote(
      vendor: json['vendor']?.toString() ?? 'unknown',
      quoteType: MarketQuoteType.fromString(json['quote_type']?.toString()),
      rawAmount: (json['raw_amount'] as num?)?.toDouble() ?? 0.0,
      currency: AppCurrency.fromCode(json['currency']?.toString()),
      convertedAmount: (json['converted_amount'] as num?)?.toDouble() ?? 0.0,
      baseCurrency: AppCurrency.fromCode(json['base_currency']?.toString()),
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MarketPriceQuote &&
          runtimeType == other.runtimeType &&
          vendor == other.vendor &&
          quoteType == other.quoteType &&
          rawAmount == other.rawAmount &&
          currency == other.currency &&
          convertedAmount == other.convertedAmount &&
          baseCurrency == other.baseCurrency &&
          timestamp == other.timestamp;

  @override
  int get hashCode => Object.hash(
        vendor,
        quoteType,
        rawAmount,
        currency,
        convertedAmount,
        baseCurrency,
        timestamp,
      );

  @override
  String toString() =>
      'MarketPriceQuote($vendor, ${quoteType.name}, raw: ${currency.symbol}$rawAmount, base: ${baseCurrency.symbol}$convertedAmount)';
}

/// Aggregated breakdown of market retail vs buylist spread across multiple vendors.
@immutable
class MarketSpreadSummary {
  final MarketPriceQuote? lowestRetail;
  final MarketPriceQuote? highestBuylist;
  final double? spreadAmount;
  final double? spreadPercentage;
  final List<MarketPriceQuote> quotes;

  const MarketSpreadSummary({
    this.lowestRetail,
    this.highestBuylist,
    this.spreadAmount,
    this.spreadPercentage,
    required this.quotes,
  });

  /// Factory computing spread metrics from a list of market quotes.
  factory MarketSpreadSummary.fromQuotes(List<MarketPriceQuote> allQuotes) {
    final validQuotes = allQuotes.where((q) => q.isValid && !q.isFloorAnomaly()).toList();

    MarketPriceQuote? minRetail;
    MarketPriceQuote? maxBuylist;

    for (final q in validQuotes) {
      if (q.quoteType == MarketQuoteType.retail || q.quoteType == MarketQuoteType.market) {
        if (minRetail == null || q.convertedAmount < minRetail.convertedAmount) {
          minRetail = q;
        }
      } else if (q.quoteType == MarketQuoteType.buylist) {
        if (maxBuylist == null || q.convertedAmount > maxBuylist.convertedAmount) {
          maxBuylist = q;
        }
      }
    }

    double? spreadDelta;
    double? spreadPct;

    if (minRetail != null && maxBuylist != null) {
      spreadDelta = minRetail.convertedAmount - maxBuylist.convertedAmount;
      if (minRetail.convertedAmount > 0.0) {
        spreadPct = (spreadDelta / minRetail.convertedAmount) * 100.0;
      }
    }

    return MarketSpreadSummary(
      lowestRetail: minRetail,
      highestBuylist: maxBuylist,
      spreadAmount: spreadDelta,
      spreadPercentage: spreadPct,
      quotes: List.unmodifiable(validQuotes),
    );
  }
}
