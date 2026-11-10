import 'dart:convert';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/domain/vault_pricing_helper.dart';

/// Service for resolving variant and finish-aware pricing for cards in trades.
class TradePricingCalculator {
  /// Extracts the effective finish ('foil', 'etched', or 'non_foil') from a [VaultItem].
  static String resolveFinish(VaultItem item) {
    if (item.dynamicData.isNotEmpty) {
      try {
        final decoded = jsonDecode(item.dynamicData);
        if (decoded is Map) {
          final rawFinish = decoded['finish']?.toString().toLowerCase().trim();
          if (rawFinish != null && rawFinish.isNotEmpty) {
            if (rawFinish.contains('etched')) return 'etched';
            if (rawFinish.contains('non') || rawFinish == 'regular' || rawFinish == 'normal') {
              return 'non_foil';
            }
            if (rawFinish.contains('foil')) return 'foil';
          }
          if (decoded['finishes'] is List) {
            final list = (decoded['finishes'] as List).map((e) => e.toString().toLowerCase()).toList();
            if (list.contains('etched')) return 'etched';
            if (list.contains('foil')) return 'foil';
          }
        }
      } catch (_) {}
    }
    return 'non_foil';
  }

  /// Calculates the exact market price for [item] respecting its exact printing and finish.
  static double calculateCardPrice(VaultItem item, {String? finish}) {
    final effectiveFinish = finish ?? resolveFinish(item);

    if (item.dynamicData.isNotEmpty) {
      final helperFinish = (effectiveFinish == 'non_foil') ? 'nonfoil' : effectiveFinish;
      final hierarchicalPrice = VaultPricingHelper.extractFromDynamicData(
        item.dynamicData,
        finish: helperFinish,
      );
      if (hierarchicalPrice > 0.0) {
        return hierarchicalPrice;
      }
    }

    if (item.currentMarketPrice > 0.0) {
      return item.currentMarketPrice;
    }

    if (item.acquiredPrice > 0.0) {
      return item.acquiredPrice;
    }

    return 0.0;
  }
}
