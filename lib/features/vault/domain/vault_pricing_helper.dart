import 'dart:convert';
import 'package:countr/core/database/app_database.dart';

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
    } catch (_) {
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

  /// Formats a market price for display.
  ///
  /// If [price] > 0.0 (and finite), returns `'\$${price.toStringAsFixed(2)}'`.
  /// Otherwise, returns [fallback] (default: 'Unlisted').
  ///
  /// Guarantees that the literal string "Check" is never displayed.
  static String formatMarketPriceLabel(
    double price, {
    String fallback = unlistedLabel,
  }) {
    if (price.isNaN || price.isInfinite || price <= 0.0) {
      return fallback;
    }
    return '\$${price.toStringAsFixed(2)}';
  }

  /// Compatibility alias for [formatMarketPriceLabel].
  static String formatPrice(
    double price, {
    String fallback = unlistedLabel,
  }) =>
      formatMarketPriceLabel(price, fallback: fallback);

  /// Formats a market price label for headers/pills (e.g. "Market: $12.50" or "Market: Unlisted").
  ///
  /// Strictly replaces legacy "Market: Check".
  static String formatMarketHeaderLabel(
    double price, {
    String fallback = unlistedLabel,
  }) {
    if (price.isNaN || price.isInfinite || price <= 0.0) {
      return 'Market: $fallback';
    }
    return 'Market: \$${price.toStringAsFixed(2)}';
  }

  /// Compatibility alias for [formatMarketHeaderLabel].
  static String formatMarketHeader(
    double price, {
    String fallback = unlistedLabel,
  }) =>
      formatMarketHeaderLabel(price, fallback: fallback);
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
  String fallback = VaultPricingHelper.unlistedLabel,
}) =>
    VaultPricingHelper.formatMarketPriceLabel(price, fallback: fallback);

/// Top-level convenience wrapper for [VaultPricingHelper.formatMarketHeaderLabel].
String formatMarketHeaderLabel(
  double price, {
  String fallback = VaultPricingHelper.unlistedLabel,
}) =>
    VaultPricingHelper.formatMarketHeaderLabel(price, fallback: fallback);

/// Extension on [VaultItem] providing ergonomic access to pricing helpers.
extension VaultItemPricing on VaultItem {
  /// Resolves the effective market price (checking currentMarketPrice first, then dynamicData fallback chain).
  double get effectiveMarketPrice =>
      VaultPricingHelper.resolveEffectiveMarketPrice(this);

  /// Formatted market price string (e.g. "$12.50" or "Unlisted").
  String formatMarketPrice({String fallback = VaultPricingHelper.unlistedLabel}) =>
      VaultPricingHelper.formatMarketPriceLabel(effectiveMarketPrice, fallback: fallback);

  /// Formatted market header string (e.g. "Market: $12.50" or "Market: Unlisted").
  String formatMarketHeader({String fallback = VaultPricingHelper.unlistedLabel}) =>
      VaultPricingHelper.formatMarketHeaderLabel(effectiveMarketPrice, fallback: fallback);
}
