import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/settings_state.dart';
import 'package:countr/features/values/domain/exchange_rate_service.dart';

/// Centralized pricing utility for Scryfall price extraction, hierarchical
/// fallback resolution, and UI price label formatting across Countr.
class VaultPricingHelper {
  VaultPricingHelper._();

  /// Canonical fallback hierarchy for Scryfall prices:
  /// 1. prices['usd'] (USD Regular / Non-foil)
  /// 2. prices['usd_foil'] (USD Traditional Foil)
  /// 3. prices['usd_etched'] (USD Etched Foil)
  /// 4. prices['eur'] (EUR Regular / Non-foil)
  /// 5. prices['eur_foil'] (EUR Traditional Foil)
  static const List<String> pricingHierarchy = [
    'usd',
    'usd_foil',
    'usd_etched',
    'eur',
    'eur_foil',
  ];

  /// Standard fallback label when no market price is listed or available.
  static const String unlistedLabel = 'Unlisted';

  /// Standard mask emitted for all monetary values when Privacy Mode is active.
  static const String privacyMask = '****';

  /// Parses [value] into a positive finite double (> 0.0).
  ///
  /// Returns `null` if [value] is null, unparseable, NaN, infinite, or <= 0.0.
  /// This explicitly solves the bug where `double.tryParse('0.00')` returns `0.0`
  /// (which is non-null) and would prematurely abort `??` fallback chains.
  static double? parsePositivePrice(dynamic value) {
    if (value == null) return null;
    final d = double.tryParse(value.toString().trim());
    if (d == null || d.isNaN || d.isInfinite || d <= 0.0) {
      return null;
    }
    return d;
  }

  /// Extracts the highest-priority positive price from a Scryfall prices map
  /// according to the canonical hierarchy:
  /// prices['usd'] -> prices['usd_foil'] -> prices['usd_etched'] -> prices['eur'] -> prices['eur_foil'] -> 0.0
  static double resolveHierarchicalPrice(Map<dynamic, dynamic>? prices) {
    if (prices == null || prices.isEmpty) return 0.0;
    for (final key in pricingHierarchy) {
      final parsed = parsePositivePrice(prices[key]);
      if (parsed != null) {
        return parsed;
      }
    }
    return 0.0;
  }

  /// Alias for [resolveHierarchicalPrice] for compatibility with alternate naming conventions.
  static double extractFromPricesMap(Map<dynamic, dynamic>? prices) =>
      resolveHierarchicalPrice(prices);

  /// Extracts the market price from dynamic data (either already a Map or a JSON String).
  ///
  /// Returns 0.0 if [dynamicData] is null, empty, malformed JSON, or contains no positive prices.
  static double extractFromDynamicData(dynamic dynamicData) {
    if (dynamicData == null) return 0.0;
    try {
      Map<dynamic, dynamic>? map;
      if (dynamicData is Map) {
        map = dynamicData;
      } else if (dynamicData is String && dynamicData.trim().isNotEmpty) {
        final decoded = jsonDecode(dynamicData);
        if (decoded is Map) {
          map = decoded;
        }
      }
      if (map != null) {
        if (map['prices'] is Map) {
          final p = resolveHierarchicalPrice(map['prices'] as Map);
          if (p > 0) return p;
        }
        if (map['card_faces'] is List && (map['card_faces'] as List).isNotEmpty) {
          final firstFace = (map['card_faces'] as List)[0];
          if (firstFace is Map && firstFace['prices'] is Map) {
            final p = resolveHierarchicalPrice(firstFace['prices'] as Map);
            if (p > 0) return p;
          }
        }
      }
    } catch (e, stackTrace) {
      debugPrint('[VaultPricingHelper] Failed to extract price from dynamicData: $e\n$stackTrace');
      // Malformed JSON is gracefully swallowed, returning 0.0
    }
    return 0.0;
  }

  /// Resolves the effective market price for a [VaultItem].
  ///
  /// Priority:
  /// 1. `item.currentMarketPrice` if > 0.0 and finite.
  /// 2. Extracted from `item.dynamicData` JSON payload via the pricing hierarchy.
  /// 3. Returns 0.0 if no price can be resolved.
  static double resolveEffectiveMarketPrice(VaultItem item) {
    if (!item.currentMarketPrice.isNaN &&
        !item.currentMarketPrice.isInfinite &&
        item.currentMarketPrice > 0.0) {
      return item.currentMarketPrice;
    }
    return extractFromDynamicData(item.dynamicData);
  }

  // ===========================================================================
  // Phase 4.4 Contract: formatAmount & formatReturn
  // ===========================================================================

  /// Formats an arbitrary monetary [amount] with dynamic currency symbol and privacy masking.
  ///
  /// - If [isPrivacyMode] is true, returns `'****'` unconditionally.
  /// - If [amount] is null, NaN, infinite, or <= 0.0 (unless [allowZero] is true), returns [fallback].
  /// - If [amount] is negative, prepends a minus sign before the currency symbol (e.g. `-$12.50`).
  /// - Otherwise formats as `${currency.symbol}${amount.toStringAsFixed(2)}`.
  static String formatAmount(
    double? amount, {
    required AppCurrency currency,
    required bool isPrivacyMode,
    String fallback = unlistedLabel,
    bool allowZero = false,
    bool allowNegative = true,
  }) {
    if (isPrivacyMode) {
      return privacyMask;
    }
    if (amount == null || amount.isNaN || amount.isInfinite) {
      return fallback;
    }
    if (amount == 0.0 && !allowZero) {
      return fallback;
    }
    if (amount < 0.0 && !allowNegative) {
      return fallback;
    }
    final symbol = ExchangeRateService.getCurrencySymbol(currency);
    if (amount < 0.0) {
      return '-$symbol${amount.abs().toStringAsFixed(2)}';
    }
    return '$symbol${amount.toStringAsFixed(2)}';
  }

  /// Formats a financial return (absolute delta and/or percentage return) with dynamic currency
  /// symbol and privacy masking.
  ///
  /// - If [isPrivacyMode] is true, returns `'****'` unconditionally.
  /// - If both [delta] and [percentage] are null, returns [fallback].
  /// - If both are non-null:
  ///   - When [amountFirst] is true (default):
  ///     - Positive: `'+$symbol12.50 (+25.0%)'`
  ///     - Negative: `'-$symbol5.00 (-10.0%)'`
  ///     - Zero: `'$symbol0.00 (0.0%)'`
  ///   - When [amountFirst] is false:
  ///     - Positive: `'+25.0% (+$symbol12.50)'`
  ///     - Negative: `'-10.0% (-$symbol5.00)'`
  ///     - Zero: `'0.0% ($symbol0.00)'`
  /// - If only [delta] is provided: formats with sign and symbol (e.g. `'+$symbol12.50'`).
  /// - If only [percentage] is provided: formats with sign (e.g. `'+25.0%'`).
  static String formatReturn(
    double? delta,
    double? percentage, {
    required AppCurrency currency,
    required bool isPrivacyMode,
    bool amountFirst = true,
    String fallback = '—',
  }) {
    if (isPrivacyMode) {
      return privacyMask;
    }
    if (delta == null && percentage == null) {
      return fallback;
    }

    final symbol = ExchangeRateService.getCurrencySymbol(currency);

    // Only percentage available
    if (delta == null && percentage != null) {
      if (percentage.isNaN || percentage.isInfinite) return fallback;
      final sign = percentage < 0 ? '-' : '+';
      return '$sign${percentage.abs().toStringAsFixed(1)}%';
    }

    // Only delta available
    if (delta != null && percentage == null) {
      if (delta.isNaN || delta.isInfinite) return fallback;
      final sign = delta < 0 ? '-' : '+';
      return '$sign$symbol${delta.abs().toStringAsFixed(2)}';
    }

    // Both delta and percentage available
    final d = delta!;
    final p = percentage!;
    if (d.isNaN || d.isInfinite || p.isNaN || p.isInfinite) {
      return fallback;
    }

    final isNegative = d < 0 || p < 0;
    final deltaSign = isNegative ? '-' : '+';
    final pctSign = isNegative ? '-' : '+';

    final deltaStr = '$deltaSign$symbol${d.abs().toStringAsFixed(2)}';
    final pctStr = '$pctSign${p.abs().toStringAsFixed(1)}%';

    if (amountFirst) {
      return '$deltaStr ($pctStr)';
    } else {
      return '$pctStr ($deltaStr)';
    }
  }

  // ===========================================================================
  // Upgraded Formatters (Maintaining 100% Backward Compatibility)
  // ===========================================================================

  /// Formats a market price for display.
  ///
  /// If [price] > 0.0 (and finite), returns formatted price string.
  /// When [isPrivacyMode] is true, returns `'****'`.
  /// Otherwise, returns [fallback] (default: 'Unlisted').
  ///
  /// Guarantees that the literal string "Check" is never displayed.
  static String formatMarketPriceLabel(
    double price, {
    AppCurrency currency = AppCurrency.usd,
    bool isPrivacyMode = false,
    String fallback = unlistedLabel,
  }) {
    return formatAmount(
      price,
      currency: currency,
      isPrivacyMode: isPrivacyMode,
      fallback: fallback,
      allowZero: false,
      allowNegative: false,
    );
  }

  /// Compatibility alias for [formatMarketPriceLabel].
  static String formatPrice(
    double price, {
    AppCurrency currency = AppCurrency.usd,
    bool isPrivacyMode = false,
    String fallback = unlistedLabel,
  }) =>
      formatMarketPriceLabel(
        price,
        currency: currency,
        isPrivacyMode: isPrivacyMode,
        fallback: fallback,
      );

  /// Formats a market price label for headers/pills (e.g. "Market: $12.50" or "Market: Unlisted").
  /// When [isPrivacyMode] is true, returns `'Market: ****'`.
  ///
  /// Strictly replaces legacy "Market: Check".
  static String formatMarketHeaderLabel(
    double price, {
    AppCurrency currency = AppCurrency.usd,
    bool isPrivacyMode = false,
    String fallback = unlistedLabel,
  }) {
    if (isPrivacyMode) {
      return 'Market: $privacyMask';
    }
    if (price.isNaN || price.isInfinite || price <= 0.0) {
      return 'Market: $fallback';
    }
    final symbol = ExchangeRateService.getCurrencySymbol(currency);
    return 'Market: $symbol${price.toStringAsFixed(2)}';
  }

  /// Compatibility alias for [formatMarketHeaderLabel].
  static String formatMarketHeader(
    double price, {
    AppCurrency currency = AppCurrency.usd,
    bool isPrivacyMode = false,
    String fallback = unlistedLabel,
  }) =>
      formatMarketHeaderLabel(
        price,
        currency: currency,
        isPrivacyMode: isPrivacyMode,
        fallback: fallback,
      );
}

/// Top-level convenience wrapper for [VaultPricingHelper.parsePositivePrice].
double? parsePositivePrice(dynamic value) =>
    VaultPricingHelper.parsePositivePrice(value);

/// Top-level convenience wrapper for [VaultPricingHelper.resolveHierarchicalPrice].
double resolveHierarchicalPrice(Map<dynamic, dynamic>? prices) =>
    VaultPricingHelper.resolveHierarchicalPrice(prices);

/// Top-level convenience wrapper for [VaultPricingHelper.resolveEffectiveMarketPrice].
double resolveEffectiveMarketPrice(VaultItem item) =>
    VaultPricingHelper.resolveEffectiveMarketPrice(item);

/// Top-level convenience wrapper for [VaultPricingHelper.formatMarketPriceLabel].
String formatMarketPriceLabel(
  double price, {
  AppCurrency currency = AppCurrency.usd,
  bool isPrivacyMode = false,
  String fallback = VaultPricingHelper.unlistedLabel,
}) =>
    VaultPricingHelper.formatMarketPriceLabel(
      price,
      currency: currency,
      isPrivacyMode: isPrivacyMode,
      fallback: fallback,
    );

/// Top-level convenience wrapper for [VaultPricingHelper.formatMarketHeaderLabel].
String formatMarketHeaderLabel(
  double price, {
  AppCurrency currency = AppCurrency.usd,
  bool isPrivacyMode = false,
  String fallback = VaultPricingHelper.unlistedLabel,
}) =>
    VaultPricingHelper.formatMarketHeaderLabel(
      price,
      currency: currency,
      isPrivacyMode: isPrivacyMode,
      fallback: fallback,
    );

/// Top-level convenience wrapper for [VaultPricingHelper.formatAmount].
String formatAmount(
  double? amount, {
  required AppCurrency currency,
  required bool isPrivacyMode,
  String fallback = VaultPricingHelper.unlistedLabel,
  bool allowZero = false,
  bool allowNegative = true,
}) =>
    VaultPricingHelper.formatAmount(
      amount,
      currency: currency,
      isPrivacyMode: isPrivacyMode,
      fallback: fallback,
      allowZero: allowZero,
      allowNegative: allowNegative,
    );

/// Top-level convenience wrapper for [VaultPricingHelper.formatReturn].
String formatReturn(
  double? delta,
  double? percentage, {
  required AppCurrency currency,
  required bool isPrivacyMode,
  bool amountFirst = true,
  String fallback = '—',
}) =>
    VaultPricingHelper.formatReturn(
      delta,
      percentage,
      currency: currency,
      isPrivacyMode: isPrivacyMode,
      amountFirst: amountFirst,
      fallback: fallback,
    );

/// Extension on [VaultItem] providing ergonomic access to pricing helpers.
extension VaultItemPricing on VaultItem {
  /// Resolves the effective market price (checking currentMarketPrice first, then dynamicData fallback chain).
  double get effectiveMarketPrice =>
      VaultPricingHelper.resolveEffectiveMarketPrice(this);

  /// Formatted market price string (e.g. "$12.50" or "Unlisted").
  String formatMarketPrice({
    AppCurrency currency = AppCurrency.usd,
    bool isPrivacyMode = false,
    String fallback = VaultPricingHelper.unlistedLabel,
  }) =>
      VaultPricingHelper.formatMarketPriceLabel(
        effectiveMarketPrice,
        currency: currency,
        isPrivacyMode: isPrivacyMode,
        fallback: fallback,
      );

  /// Formatted market header string (e.g. "Market: $12.50" or "Market: Unlisted").
  String formatMarketHeader({
    AppCurrency currency = AppCurrency.usd,
    bool isPrivacyMode = false,
    String fallback = VaultPricingHelper.unlistedLabel,
  }) =>
      VaultPricingHelper.formatMarketHeaderLabel(
        effectiveMarketPrice,
        currency: currency,
        isPrivacyMode: isPrivacyMode,
        fallback: fallback,
      );

  /// Formats the item's effective market price via [formatAmount].
  String formatAmount({
    required AppCurrency currency,
    required bool isPrivacyMode,
    String fallback = VaultPricingHelper.unlistedLabel,
    bool allowZero = false,
    bool allowNegative = true,
  }) =>
      VaultPricingHelper.formatAmount(
        effectiveMarketPrice,
        currency: currency,
        isPrivacyMode: isPrivacyMode,
        fallback: fallback,
        allowZero: allowZero,
        allowNegative: allowNegative,
      );
}
