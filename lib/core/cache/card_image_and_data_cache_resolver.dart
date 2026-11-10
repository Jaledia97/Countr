import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/hydration/data/services/scryfall_service.dart';
import 'package:countr/features/hydration/presentation/providers/hydration_providers.dart';
import 'package:countr/features/hydration/domain/isolate/scryfall_parser.dart';
import 'package:countr/core/cache/countr_image_cache_manager.dart';

/// Riverpod provider for [CardImageAndDataCacheResolver].
final cardImageAndDataCacheResolverProvider =
    Provider<CardImageAndDataCacheResolver>((ref) {
  final vaultDao = ref.watch(vaultDaoProvider);
  final scryfallService = ref.watch(scryfallServiceProvider);
  return CardImageAndDataCacheResolver(vaultDao, scryfallService);
});

/// Unified on-demand card data and image resolution engine.
///
/// Features a two-step resolution pipeline:
/// - **Step 1 (Local Catalog Repair):** Queries local Scryfall SQLite catalog
///   (`vault_items` with `quantity == 0`) first by `customId`/`scryfall_id`, then
///   by `oracle_id`, and finally by case-insensitive exact `name` (excluding `layout == 'art_series'`).
///   If found, immediately backfills and links `dynamic_data`, `oracle_text`,
///   `mana_cost`, `type_line`, `legalities`, `prices`, and `image_url` in SQLite.
/// - **Step 2 (On-Demand Network Hydration Fallback):** If missing from local
///   catalog, fetches the complete card object from Scryfall API (`/cards/{id}` or
///   `/cards/named?exact={name}`), caches the image via [CountrImageCacheManager],
///   and permanently upserts the catalog row and collection item back into SQLite.
class CardImageAndDataCacheResolver {
  final VaultDao _vaultDao;
  final ScryfallService _scryfallService;

  CardImageAndDataCacheResolver(this._vaultDao, this._scryfallService);

  /// Checks whether [item] has complete metadata and a non-empty image URI.
  /// Used to avoid redundant database updates and network calls.
  bool isCardComplete(VaultItem item) {
    if (item.imageUrl.isEmpty) return false;
    if (item.imageUrl.contains('12a34567') ||
        item.imageUrl.contains('722a3456') ||
        !item.imageUrl.startsWith('http')) {
      return false;
    }
    if (item.dynamicData.isEmpty || item.dynamicData == '{}') return false;
    try {
      final data = jsonDecode(item.dynamicData);
      if (data is! Map<String, dynamic>) return false;
      final oracle = data['oracle_text']?.toString() ?? '';
      final typeLine = data['type_line']?.toString() ?? '';
      final cardFaces = data['card_faces'];
      final hasFaces = cardFaces is List && cardFaces.isNotEmpty;
      if (oracle.trim().isEmpty && !hasFaces && typeLine.trim().isEmpty) {
        return false;
      }

      // Check legalities presence: complete cards must have a non-empty legalities map
      final legalities = data['legalities'];
      if (legalities == null || (legalities is Map && legalities.isEmpty)) {
        return false;
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Helper to check if a catalog card has sufficient data to backfill a stub.
  bool _isCatalogMatchUsable(VaultItem match) {
    if (match.imageUrl.isEmpty) return false;
    if (match.dynamicData.isEmpty || match.dynamicData == '{}') return false;
    try {
      final data = jsonDecode(match.dynamicData);
      if (data is! Map<String, dynamic>) return false;
      final oracle = data['oracle_text']?.toString() ?? '';
      final cardFaces = data['card_faces'];
      final hasFaces = cardFaces is List && cardFaces.isNotEmpty;
      final typeLine = data['type_line']?.toString() ?? '';
      return oracle.trim().isNotEmpty || hasFaces || typeLine.trim().isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Resolves missing card metadata and artwork for [item].
  ///
  /// Returns the hydrated [VaultItem] if repaired/hydrated, or the original
  /// [item] if already complete or if offline resolution could not find a match.
  Future<VaultItem> resolveCardDataAndImage(
    VaultItem item, {
    bool forceRemote = false,
  }) async {
    if (!forceRemote && isCardComplete(item)) {
      return item;
    }

    // Step 1: Local SQLite Catalog Repair
    final localMatch = await _findInLocalCatalog(item);
    if (localMatch != null && (isCardComplete(localMatch) || _isCatalogMatchUsable(localMatch))) {
      final backfilled = await _backfillFromCatalog(item, localMatch);
      if (backfilled != null) return backfilled;
    }

    // Step 2: Remote Scryfall Hydration Fallback
    final remoteResolved = await _fetchAndPersistRemote(item);
    if (remoteResolved != null) {
      return remoteResolved;
    }

    return item;
  }

  /// Resolves any card identifier (cards.id, scryfall_id, collection_items.id, or legacy slug).
  /// Step 1: Local SQLite catalog lookup via VaultDao.findCatalogCard
  /// Step 2: Remote Scryfall API fetch & persistence fallback
  Future<VaultItem?> resolveByIdentifier(
    String identifier, {
    bool forceRemote = false,
  }) async {
    final trimmed = identifier.trim();
    if (trimmed.isEmpty) return null;

    String? candidateName;
    final lower = trimmed.toLowerCase();
    String? matchedPrefix;
    for (final prefix in const [
      'item-mtg-',
      'item-pokemon-',
      'item-yugioh-',
      'item-lorcana-',
      'item-starwars-',
    ]) {
      if (lower.startsWith(prefix)) {
        matchedPrefix = prefix;
        break;
      }
    }
    if (matchedPrefix != null) {
      final slugCore = trimmed.substring(matchedPrefix.length);
      final cleanWords = slugCore.split('-').map((w) => w.trim()).where((w) => w.isNotEmpty).toList();
      if (cleanWords.isEmpty) {
        throw ArgumentError('Malformed card slug: $identifier');
      }
      candidateName = cleanWords.map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase()).join(' ');
    }

    // Step 1: Local catalog lookup
    if (!forceRemote) {
      final local = await _vaultDao.findCatalogCard(
        identifier: identifier,
        name: candidateName,
      );
      if (local != null && (isCardComplete(local) || _isCatalogMatchUsable(local))) {
        return local;
      }
    }

    // Step 2: Remote Scryfall Hydration Fallback
    try {
      final isUuid = RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(trimmed);
      final cardJson = await _scryfallService.fetchCardDetails(
        scryfallId: isUuid ? trimmed : null,
        name: candidateName ?? (isUuid ? null : trimmed),
      );

      if (cardJson != null) {
        final companion = mapScryfallCardToCompanion(cardJson);
        await _vaultDao.upsertCatalogItem(companion);
        final catalogItem = await _vaultDao.findCatalogCard(
          scryfallId: cardJson['id']?.toString(),
          name: cardJson['name']?.toString(),
        );
        if (catalogItem != null) {
          if (catalogItem.imageUrl.isNotEmpty) {
            try {
              await CountrImageCacheManager.instance.downloadFile(
                catalogItem.imageUrl,
                key: CountrImageCacheManager.cardArtKey(catalogItem.id),
              );
            } catch (_) {}
          }
          return catalogItem;
        }
      }
    } catch (e, st) {
      debugPrint('[CardImageAndDataCacheResolver.resolveByIdentifier] Remote fallback failed: $e\n$st');
    }

    return _vaultDao.findCatalogCard(identifier: identifier, name: candidateName);
  }

  /// Finds matching catalog card in the local SQLite database.
  Future<VaultItem?> _findInLocalCatalog(VaultItem item) async {
    String? scryfallId;
    String? oracleId;

    if (item.dynamicData.isNotEmpty && item.dynamicData != '{}') {
      try {
        final data = jsonDecode(item.dynamicData) as Map<String, dynamic>;
        scryfallId = data['scryfall_id']?.toString() ?? data['id']?.toString();
        oracleId = data['oracle_id']?.toString();
      } catch (_) {}
    }

    final uuidRegex = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    if ((scryfallId == null || scryfallId.isEmpty) &&
        uuidRegex.hasMatch(item.id) &&
        !item.id.startsWith('12a34567') &&
        !item.id.startsWith('722a3456')) {
      scryfallId = item.id;
    }

    String? lookupName = (item.name.isNotEmpty && item.name != 'Loading...') ? item.name : null;
    if (lookupName == null) {
      final lowerId = item.id.toLowerCase();
      String? matchedPrefix;
      for (final prefix in const [
        'item-mtg-',
        'item-pokemon-',
        'item-yugioh-',
        'item-lorcana-',
        'item-starwars-',
      ]) {
        if (lowerId.startsWith(prefix)) {
          matchedPrefix = prefix;
          break;
        }
      }
      if (matchedPrefix != null) {
        final slugCore = item.id.substring(matchedPrefix.length);
        final cleanWords = slugCore.split('-').map((w) => w.trim()).where((w) => w.isNotEmpty).toList();
        if (cleanWords.isNotEmpty) {
          lookupName = cleanWords.map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase()).join(' ');
        }
      }
    }

    return _vaultDao.findCatalogCard(
      identifier: item.id,
      scryfallId: scryfallId,
      oracleId: oracleId,
      name: lookupName,
    );
  }

  /// Backfills [item]'s SQLite record from a complete catalog [match].
  Future<VaultItem?> _backfillFromCatalog(
      VaultItem item, VaultItem match) async {
    try {
      final catalogData =
          jsonDecode(match.dynamicData) as Map<String, dynamic>;
      Map<String, dynamic> itemData = {};
      if (item.dynamicData.isNotEmpty && item.dynamicData != '{}') {
        try {
          itemData = jsonDecode(item.dynamicData) as Map<String, dynamic>;
        } catch (_) {}
      }

      final merged = Map<String, dynamic>.from(catalogData);
      // Preserve existing user customizations
      if (itemData['cached_rulings'] != null) {
        merged['cached_rulings'] = itemData['cached_rulings'];
      }
      if (itemData['deck_history'] != null) {
        merged['deck_history'] = itemData['deck_history'];
      }
      if (itemData['personal_notes'] != null) {
        merged['personal_notes'] = itemData['personal_notes'];
      }
      final newDynamicStr = jsonEncode(merged);

      final newImageUrl = (item.imageUrl.isEmpty ||
              item.imageUrl.contains('12a34567') ||
              item.imageUrl.contains('722a3456') ||
              !item.imageUrl.startsWith('http'))
          ? match.imageUrl
          : (match.imageUrl.isNotEmpty ? match.imageUrl : item.imageUrl);

      final newPrice = (item.currentMarketPrice <= 0.0 &&
              match.currentMarketPrice > 0.0)
          ? match.currentMarketPrice
          : item.currentMarketPrice;

      final newFlavor = match.flavorName ?? item.flavorName;

      await _vaultDao.updateItemMetadata(
        item.id,
        imageUrl: newImageUrl.isNotEmpty ? newImageUrl : null,
        currentMarketPrice: newPrice > 0 ? newPrice : null,
        flavorName: newFlavor,
        dynamicData: newDynamicStr,
      );

      final updated = await _vaultDao.getItemById(item.id);
      if (updated != null) return updated;

      return item.copyWith(
        name: (item.name.isEmpty || item.name == 'Loading...') ? match.name : item.name,
        setOrSeries: item.setOrSeries.isEmpty ? match.setOrSeries : item.setOrSeries,
        imageUrl: newImageUrl.isNotEmpty ? newImageUrl : item.imageUrl,
        currentMarketPrice: newPrice > 0 ? newPrice : item.currentMarketPrice,
        flavorName: Value(newFlavor),
        dynamicData: newDynamicStr,
      );
    } catch (e, stackTrace) {
      debugPrint(
          '[CardImageAndDataCacheResolver._backfillFromCatalog] Error: $e\n$stackTrace');
      return null;
    }
  }

  /// Fetches card details from Scryfall API and persists full metadata to SQLite.
  Future<VaultItem?> _fetchAndPersistRemote(VaultItem item) async {
    try {
      String? scryfallId;
      if (item.dynamicData.isNotEmpty && item.dynamicData != '{}') {
        try {
          final data = jsonDecode(item.dynamicData) as Map<String, dynamic>;
          scryfallId =
              data['scryfall_id']?.toString() ?? data['id']?.toString();
        } catch (_) {}
      }

      final uuidRegex = RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
      if ((scryfallId == null || scryfallId.isEmpty) &&
          uuidRegex.hasMatch(item.id) &&
          !item.id.startsWith('12a34567') &&
          !item.id.startsWith('722a3456')) {
        scryfallId = item.id;
      }

      String? remoteName = (item.name.isNotEmpty && item.name != 'Loading...') ? item.name : null;
      if (remoteName == null) {
        final lowerId = item.id.toLowerCase();
        String? matchedPrefix;
        for (final prefix in const [
          'item-mtg-',
          'item-pokemon-',
          'item-yugioh-',
          'item-lorcana-',
          'item-starwars-',
        ]) {
          if (lowerId.startsWith(prefix)) {
            matchedPrefix = prefix;
            break;
          }
        }
        if (matchedPrefix != null) {
          final slugCore = item.id.substring(matchedPrefix.length);
          final cleanWords = slugCore.split('-').map((w) => w.trim()).where((w) => w.isNotEmpty).toList();
          if (cleanWords.isNotEmpty) {
            remoteName = cleanWords.map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase()).join(' ');
          }
        }
      }

      final cardJson = await _scryfallService.fetchCardDetails(
        scryfallId: scryfallId,
        name: remoteName,
      );

      if (cardJson == null) return null;

      final companion = mapScryfallCardToCompanion(cardJson);

      // Permanently upsert catalog reference card entry (quantity = 0)
      await _vaultDao.upsertCatalogItem(companion);

      final newDynamic =
          jsonDecode(companion.dynamicData.value) as Map<String, dynamic>;
      final newImageUrl = companion.imageUrl.value;
      final newPrice = companion.currentMarketPrice.value;
      final newFlavor =
          companion.flavorName.present ? companion.flavorName.value : null;

      // Update the user item row in SQLite
      await _vaultDao.updateItemMetadata(
        item.id,
        imageUrl: newImageUrl.isNotEmpty ? newImageUrl : null,
        currentMarketPrice: newPrice > 0 ? newPrice : null,
        flavorName: newFlavor,
        dynamicData: jsonEncode(newDynamic),
      );

      // On-demand image download/cache
      if (newImageUrl.isNotEmpty) {
        try {
          await CountrImageCacheManager.instance.downloadFile(
            newImageUrl,
            key: CountrImageCacheManager.cardArtKey(companion.id.value),
          );
        } catch (_) {}
      }

      final updated = await _vaultDao.getItemById(item.id);
      if (updated != null) return updated;

      return item.copyWith(
        imageUrl: newImageUrl.isNotEmpty ? newImageUrl : item.imageUrl,
        currentMarketPrice: newPrice > 0 ? newPrice : item.currentMarketPrice,
        flavorName: Value(newFlavor),
        dynamicData: jsonEncode(newDynamic),
      );
    } catch (e, stackTrace) {
      debugPrint(
          '[CardImageAndDataCacheResolver._fetchAndPersistRemote] Error: $e\n$stackTrace');
      return null;
    }
  }

  /// Resolves the exact image URL for a given [scryfallId] printing variant.
  Future<String?> resolveVariantImageUrl({
    required String scryfallId,
    String? preferredFinish,
  }) async {
    // 1. Check local catalog
    final local = await _vaultDao.findCatalogCard(scryfallId: scryfallId);
    if (local != null && local.imageUrl.isNotEmpty) {
      return local.imageUrl;
    }

    // 2. Fetch remote
    try {
      final cardJson =
          await _scryfallService.fetchCardDetails(scryfallId: scryfallId);
      if (cardJson != null) {
        if (cardJson['image_uris'] is Map) {
          final uris = cardJson['image_uris'] as Map;
          final img = (uris['normal'] ??
                  uris['large'] ??
                  uris['small'] ??
                  uris['png'] ??
                  uris['art_crop'])
              ?.toString();
          if (img != null && img.isNotEmpty) {
            final companion = mapScryfallCardToCompanion(cardJson);
            await _vaultDao.upsertCatalogItem(companion);
            return img;
          }
        } else if (cardJson['card_faces'] is List &&
            (cardJson['card_faces'] as List).isNotEmpty) {
          final firstFace = (cardJson['card_faces'] as List)[0];
          if (firstFace is Map && firstFace['image_uris'] is Map) {
            final uris = firstFace['image_uris'] as Map;
            final img = (uris['normal'] ??
                    uris['large'] ??
                    uris['small'] ??
                    uris['png'] ??
                    uris['art_crop'])
                ?.toString();
            if (img != null && img.isNotEmpty) {
              final companion = mapScryfallCardToCompanion(cardJson);
              await _vaultDao.upsertCatalogItem(companion);
              return img;
            }
          }
        }
      }
    } catch (_) {}

    return null;
  }
}
