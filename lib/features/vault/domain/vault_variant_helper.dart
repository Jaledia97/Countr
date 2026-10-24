import 'package:countr/core/cache/parsed_json_cache.dart';
import 'package:countr/core/database/app_database.dart';

/// Container for consolidated variant grouping results.
class ConsolidatedVariantResult {
  final List<VaultItem> items;
  final Map<String, Set<String>> variantToUnderlyingIds;
  final Set<String> multiVariantCardKeys;

  const ConsolidatedVariantResult({
    required this.items,
    required this.variantToUnderlyingIds,
    required this.multiVariantCardKeys,
  });
}

/// Helper for resolving MTG and TCG card variants by printing and finish.
class VaultVariantHelper {
  VaultVariantHelper._();

  static final Map<String, String> _variantKeyCache = {};
  static final Map<String, String> _abstractKeyCache = {};
  static const int _maxCacheSize = 20000;

  static void clearCache() {
    _variantKeyCache.clear();
    _abstractKeyCache.clear();
  }

  /// Extracts the unique printing ID (Scryfall ID or authentic printing identifier).
  static String resolvePrintingId(VaultItem item) {
    if (item.dynamicData.isNotEmpty) {
      try {
        final map = ParsedJsonCache.parse(item.dynamicData);
        final scryfallId = map['scryfall_id']?.toString() ?? map['id']?.toString();
        if (scryfallId != null && scryfallId.trim().isNotEmpty) {
          return scryfallId.trim();
        }
        final collectorNum = map['collector_number']?.toString().trim();
        final set = (map['set'] ?? map['set_code'] ?? item.setOrSeries).toString().toLowerCase().trim();
        if (collectorNum != null && collectorNum.isNotEmpty && set.isNotEmpty) {
          return '${item.name.toLowerCase().trim()}_${set}_$collectorNum';
        }
      } catch (_) {}
    }
    return item.id;
  }

  /// Extracts the normalized finish: 'nonfoil', 'foil', or 'etched'.
  static String resolveFinish(VaultItem item) {
    if (item.dynamicData.isNotEmpty) {
      try {
        final map = ParsedJsonCache.parse(item.dynamicData);
        final finish = map['finish']?.toString().toLowerCase().trim();
        if (finish != null && finish.isNotEmpty) {
          return finish;
        }
        final finishes = map['finishes'];
        if (finishes is List && finishes.isNotEmpty) {
          final first = finishes.first.toString().toLowerCase().trim();
          if (first.isNotEmpty) return first;
        }
        final treatment = map['treatment']?.toString().toLowerCase().trim();
        if (treatment != null && treatment.isNotEmpty) {
          if (treatment.contains('etched')) return 'etched';
          if (treatment.contains('foil')) return 'foil';
        }
      } catch (_) {}
    }
    final cond = item.condition.toLowerCase();
    if (cond.contains('etched')) return 'etched';
    if (cond.contains('foil')) return 'foil';
    return 'nonfoil';
  }

  /// Computes the strict variant grouping key: (scryfall_id, finish).
  static String computeVariantKey(VaultItem item) {
    final cacheKey = '${item.id}_${item.dynamicData.hashCode}_${item.updatedAt?.millisecondsSinceEpoch ?? 0}';
    final cached = _variantKeyCache[cacheKey];
    if (cached != null) return cached;

    final printingId = resolvePrintingId(item);
    final finish = resolveFinish(item);
    final key = '${item.collectionType}_${printingId}_$finish';

    if (_variantKeyCache.length >= _maxCacheSize) {
      _variantKeyCache.clear();
    }
    _variantKeyCache[cacheKey] = key;
    return key;
  }

  /// Resolves the abstract card concept key (for identifying multiple variants of the same card).
  static String resolveAbstractCardKey(VaultItem item) {
    final cacheKey = '${item.id}_${item.dynamicData.hashCode}_${item.updatedAt?.millisecondsSinceEpoch ?? 0}';
    final cached = _abstractKeyCache[cacheKey];
    if (cached != null) return cached;

    String key = '${item.collectionType}_${item.name.toLowerCase().trim()}';
    if (item.dynamicData.isNotEmpty) {
      try {
        final map = ParsedJsonCache.parse(item.dynamicData);
        final oracleId = map['oracle_id']?.toString();
        if (oracleId != null && oracleId.trim().isNotEmpty) {
          key = '${item.collectionType}_${oracleId.trim()}';
        }
      } catch (_) {}
    }

    if (_abstractKeyCache.length >= _maxCacheSize) {
      _abstractKeyCache.clear();
    }
    _abstractKeyCache[cacheKey] = key;
    return key;
  }

  /// Groups and consolidates a raw list of VaultItems strictly by (scryfall_id, finish).
  static ConsolidatedVariantResult groupVaultItemsByVariant(List<VaultItem> rawItems) {
    if (rawItems.isEmpty) {
      return const ConsolidatedVariantResult(
        items: [],
        variantToUnderlyingIds: {},
        multiVariantCardKeys: {},
      );
    }

    // Step 1: Bucket by variant key (scryfall_id, finish)
    final buckets = <String, List<VaultItem>>{};
    for (final item in rawItems) {
      final key = computeVariantKey(item);
      (buckets[key] ??= []).add(item);
    }

    // Step 2: Consolidate each bucket into a representative VaultItem
    final consolidatedItems = <VaultItem>[];
    final variantToUnderlyingIds = <String, Set<String>>{};
    final cardKeyVariantCount = <String, int>{};

    for (final entry in buckets.entries) {
      final group = entry.value;
      final underlyingIds = group.map((i) => i.id).toSet();
      final totalQuantity = group.fold<int>(0, (sum, i) => sum + i.quantity);

      // Select best representative item (has image, latest acquiredDate, or non-empty dynamicData)
      VaultItem best = group.first;
      for (final item in group) {
        if (item.imageUrl.isNotEmpty && best.imageUrl.isEmpty) {
          best = item;
        } else if (item.dynamicData.length > best.dynamicData.length) {
          best = item;
        }
      }

      final consolidatedItem = best.copyWith(quantity: totalQuantity);
      consolidatedItems.add(consolidatedItem);
      variantToUnderlyingIds[consolidatedItem.id] = underlyingIds;

      final abstractKey = resolveAbstractCardKey(consolidatedItem);
      cardKeyVariantCount[abstractKey] = (cardKeyVariantCount[abstractKey] ?? 0) + 1;
    }

    // Step 3: Identify cards with multiple variants in the collection
    final multiVariantCardKeys = <String>{};
    for (final entry in cardKeyVariantCount.entries) {
      if (entry.value > 1) {
        multiVariantCardKeys.add(entry.key);
      }
    }

    return ConsolidatedVariantResult(
      items: consolidatedItems,
      variantToUnderlyingIds: variantToUnderlyingIds,
      multiVariantCardKeys: multiVariantCardKeys,
    );
  }
}
