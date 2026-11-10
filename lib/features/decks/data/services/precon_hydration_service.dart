import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:drift/drift.dart';

import 'package:countr/core/cache/countr_cached_image.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/data/models/precon_deck_dto.dart';
import 'package:countr/features/decks/data/services/mtgjson_precon_parser.dart';
import 'package:countr/features/decks/data/services/fallback_explore_seeds.dart';

/// Service orchestrating offline ingestion, background isolate parsing,
/// and atomic SQLite seeding of official MTG preconstructed decks.
class PreconHydrationService {
  static Future<void>? _activeSeedFuture;

  /// Visible for testing and coordination: returns the active seed Future if running.
  static Future<void>? get activeSeedFuture => _activeSeedFuture;

  static const _preconZoneKey = #_preconSeedInProgress;

  /// Default asset path for bundled preconstructed decks.
  static const String defaultPreconAssetPath = 'assets/decks/precons.json';

  /// Standard batch chunk size for SQLite bulk operations to stay well within
  /// SQLite query variable limits.
  static const int batchChunkSize = 250;

  /// Checks whether official historical MTG preconstructed decks have already
  /// been seeded into the Drift database.
  static Future<bool> isHistoricalPreconSeeded(
    AppDatabase db, {
    int minExpectedDecks = 12,
  }) async {
    final countRow = await (db.selectOnly(db.decks)
          ..addColumns([db.decks.id.count()])
          ..where(
            db.decks.id.like('precon-%') &
                db.decks.tcgDomain.equals('mtg') &
                db.decks.isRegistered.equals(true) &
                db.decks.isDeleted.equals(false),
          ))
        .getSingle();

    final count = countRow.read(db.decks.id.count()) ?? 0;
    return count >= minExpectedDecks;
  }

  /// Parses raw JSON string into [PreconDeckDto]s in a background isolate.
  static Future<List<PreconDeckDto>> parseJsonInIsolate(String rawJson) {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return Future.value(MtgjsonPreconParser.parseJson(rawJson));
    }
    return Isolate.run(() => MtgjsonPreconParser.parseJson(rawJson));
  }

  /// Parses raw byte data into [PreconDeckDto]s in a background isolate.
  static Future<List<PreconDeckDto>> parseBytesInIsolate(Uint8List byteData) {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return Future.value(MtgjsonPreconParser.parseBytes(byteData));
    }
    return Isolate.run(() => MtgjsonPreconParser.parseBytes(byteData));
  }

  /// Loads bundled preconstructed decks from disk or assets, parsing them
  /// off the UI thread via a background isolate. Falls back safely to
  /// [FallbackExploreSeeds] if file/asset I/O fails.
  static Future<List<PreconDeckDto>> loadAndParseBundledPrecons({
    String? assetPath,
  }) async {
    final effectivePath = assetPath ?? defaultPreconAssetPath;
    Uint8List? byteData;

    try {
      final file = File(effectivePath);
      if (file.existsSync()) {
        byteData = file.readAsBytesSync();
      }
    } catch (_) {}

    if (byteData == null) {
      try {
        final bd = await rootBundle.load(effectivePath);
        byteData = bd.buffer.asUint8List();
      } catch (_) {}
    }

    if (byteData != null && byteData.isNotEmpty) {
      try {
        return await parseBytesInIsolate(byteData);
      } catch (err) {
        debugPrint(
          '[PreconHydrationService] Isolate parsing error ($err). Using FallbackExploreSeeds.',
        );
      }
    }

    // Secondary fallback: compiled fallback seeds in memory
    return FallbackExploreSeeds.preconSeeds
        .map((m) => MtgjsonPreconParser.parseDeck(m))
        .toList();
  }

  /// Atomically seeds historical MTG preconstructed decks into Drift SQLite:
  /// - `decks` (`tcgDomain = 'mtg'`, `isRegistered = true`, `isAssembled = false`)
  /// - `deck_versions` (v1, `isActive = true`)
  /// - `vault_items` (unowned catalog reference, `quantity = 0`, preserving `Owned = Available + Allocated`)
  /// - `deck_version_items` (`isProxy = true`, exact zones and quantities)
  ///
  /// Guarantees strict idempotency: subsequent calls skip execution unless [force] is true.
  /// When [force] is true, operations use atomic UPSERT without duplicating rows.
  static Future<void> seedHistoricalPrecons(
    AppDatabase db, {
    bool force = false,
    String? assetPath,
    List<PreconDeckDto>? customPrecons,
  }) async {
    if (Zone.current[_preconZoneKey] == true) {
      debugPrint('[PreconHydrationService] Re-entrant call detected; skipping to prevent self-await deadlock.');
      return;
    }

    if (Zone.current[AppDatabase.beforeOpenZoneKey] == true) {
      debugPrint('[PreconHydrationService] Call from within beforeOpen detected; deferring to microtask to prevent deadlock.');
      Zone.root.scheduleMicrotask(() => seedHistoricalPrecons(
        db,
        force: force,
        assetPath: assetPath,
        customPrecons: customPrecons,
      ));
      return;
    }

    if (_activeSeedFuture != null) {
      try {
        await _activeSeedFuture;
      } catch (_) {}
      if (!force && customPrecons == null) {
        final alreadySeeded = await isHistoricalPreconSeeded(db);
        if (alreadySeeded) return;
      }
    }

    final future = runZoned(
      () => _executeHistoricalPreconSeed(
        db,
        force: force,
        assetPath: assetPath,
        customPrecons: customPrecons,
      ),
      zoneValues: {_preconZoneKey: true},
    );
    _activeSeedFuture = future;
    try {
      await future;
    } finally {
      if (identical(_activeSeedFuture, future)) {
        _activeSeedFuture = null;
      }
    }
  }

  static Future<void> _executeHistoricalPreconSeed(
    AppDatabase db, {
    required bool force,
    String? assetPath,
    List<PreconDeckDto>? customPrecons,
  }) async {
    // Startup repair pass: always sanitize legacy / cached art_series, art_crop, and identical X // X rows
    await repairArtSeriesCards(db);

    if (!force && customPrecons == null) {
      final alreadySeeded = await isHistoricalPreconSeeded(db);
      if (alreadySeeded) {
        debugPrint('[PreconHydrationService] Preconstructed decks already seeded. Skipping.');
        return;
      }
    }

    debugPrint('[PreconHydrationService] Starting precon hydration pipeline...');

    final List<PreconDeckDto> precons = customPrecons ??
        await loadAndParseBundledPrecons(assetPath: assetPath);

    if (precons.isEmpty) {
      debugPrint('[PreconHydrationService] No preconstructed decks to seed.');
      return;
    }

    await _executeAtomicBatchIngestion(db, precons);

    debugPrint(
      '[PreconHydrationService] Successfully seeded ${precons.length} preconstructed decks.',
    );
  }

  /// Executes chunked SQLite insertions inside a single atomic transaction.
  static Future<void> _executeAtomicBatchIngestion(
    AppDatabase db,
    List<PreconDeckDto> precons,
  ) async {
    final now = DateTime.now();

    final deckCompanions = <DecksCompanion>[];
    final versionCompanions = <DeckVersionsCompanion>[];
    final vaultItemsMap = <String, VaultItemsCompanion>{};
    final itemCompanions = <DeckVersionItemsCompanion>[];

    final Map<String, int> itemKeyCounts = {};

    for (final precon in precons) {
      final deckCreatedAt = precon.releaseDate ??
          (precon.releaseYear != null ? DateTime(precon.releaseYear!) : DateTime(2020));
      final versionId = '${precon.id}-v1';

      // 1. Deck Companion
      deckCompanions.add(
        DecksCompanion.insert(
          id: precon.id,
          name: precon.name,
          format: precon.format,
          description: Value(precon.description),
          tcgDomain: const Value('mtg'),
          isRegistered: const Value(true), // Precons are registered WotC decks
          isAssembled: const Value(false),
          isCompetitive: const Value(false),
          isCloned: const Value(false),
          coverItemId: Value(precon.primaryCommander?.scryfallId),
          createdAt: deckCreatedAt,
          updatedAt: Value(now),
          isDeleted: const Value(false),
        ),
      );

      // 2. Active Deck Version Companion
      versionCompanions.add(
        DeckVersionsCompanion.insert(
          id: versionId,
          deckId: precon.id,
          versionNumber: 1,
          versionNote: Value('Official Preconstructed Deck: ${precon.name}'),
          isActive: const Value(true),
          createdAt: deckCreatedAt,
          updatedAt: Value(now),
          isDeleted: const Value(false),
        ),
      );

      // 3. Process Cards (vault_items and deck_version_items)
      for (final card in precon.allCards) {
        final isSyntheticOracle = card.oracleId != null &&
            (card.oracleId!.startsWith('12a34567-') ||
             card.oracleId!.startsWith('722a3456-') ||
             card.oracleId!.startsWith('812a3456-'));

        final effectiveImageUrl = isSyntheticOracle
            ? CountrCachedImage.buildScryfallNamedUrl(card.name, version: 'normal')
            : (card.imageUrl ?? '');

        // Collect catalog reference row for vault_items (unowned, quantity = 0)
        if (!vaultItemsMap.containsKey(card.scryfallId)) {
          vaultItemsMap[card.scryfallId] = VaultItemsCompanion.insert(
            id: card.scryfallId,
            collectionType: 'mtg',
            name: card.name,
            setOrSeries: precon.setCode ?? 'Catalog',
            imageUrl: effectiveImageUrl,
            acquiredPrice: 0.0,
            acquiredDate: deckCreatedAt,
            quantity: const Value(0), // Unowned catalog reference preserves Owned = 0
            condition: 'NM',
            currentMarketPrice: card.price ?? 0.0,
            lastPriceUpdate: now,
            dynamicData: card.toDynamicDataJson(),
            isDeleted: const Value(false),
            updatedAt: Value(now),
          );
        }

        // Unique deterministic ID for each deck item entry
        final baseKey =
            '${precon.id}-${card.boardZone.toLowerCase()}-${card.scryfallId}';
        final seq = (itemKeyCounts[baseKey] ?? 0) + 1;
        itemKeyCounts[baseKey] = seq;
        final itemId = seq == 1 ? baseKey : '$baseKey-$seq';

        itemCompanions.add(
          DeckVersionItemsCompanion.insert(
            id: itemId,
            versionId: versionId,
            vaultItemId: card.scryfallId,
            quantity: Value(card.count),
            boardZone: card.boardZone,
            isProxy: const Value(true), // Proxy card preserves Owned = Available + Allocated
            isDeleted: const Value(false),
            updatedAt: Value(now),
          ),
        );
      }
    }

    final vaultCompanions = vaultItemsMap.values.toList();

    // Execute all precon insertions in chunked transactions (chunkSize <= 250)
    await db.transaction(() async {
      for (var i = 0; i < deckCompanions.length; i += batchChunkSize) {
        final chunk = deckCompanions.sublist(
          i,
          math.min(i + batchChunkSize, deckCompanions.length),
        );
        await db.batch((b) => b.insertAll(db.decks, chunk, mode: InsertMode.insertOrReplace));
      }

      for (var i = 0; i < versionCompanions.length; i += batchChunkSize) {
        final chunk = versionCompanions.sublist(
          i,
          math.min(i + batchChunkSize, versionCompanions.length),
        );
        await db.batch((b) => b.insertAll(db.deckVersions, chunk, mode: InsertMode.insertOrReplace));
      }

      for (var i = 0; i < vaultCompanions.length; i += batchChunkSize) {
        final chunk = vaultCompanions.sublist(
          i,
          math.min(i + batchChunkSize, vaultCompanions.length),
        );
        await db.batch((b) => b.insertAll(
          db.vaultItems,
          chunk,
          onConflict: DoUpdate<$VaultItemsTable, VaultItem>.withExcluded(
            (old, excluded) => VaultItemsCompanion.custom(
              name: excluded.name,
              flavorName: excluded.flavorName,
              setOrSeries: excluded.setOrSeries,
              imageUrl: const CustomExpression<String>(
                'CASE WHEN vault_items.image_url IS NOT NULL AND vault_items.image_url != \'\' THEN vault_items.image_url ELSE excluded.image_url END',
              ),
              currentMarketPrice: const CustomExpression<double>(
                'CASE WHEN excluded.current_market_price > 0.0 THEN excluded.current_market_price ELSE vault_items.current_market_price END',
              ),
              lastPriceUpdate: const CustomExpression<DateTime>(
                'CASE WHEN excluded.current_market_price > 0.0 THEN excluded.last_price_update ELSE vault_items.last_price_update END',
              ),
              dynamicData: const CustomExpression<String>(
                'CASE WHEN vault_items.dynamic_data IS NOT NULL AND vault_items.dynamic_data != \'\' AND vault_items.dynamic_data != \'{}\' THEN vault_items.dynamic_data ELSE excluded.dynamic_data END',
              ),
              collectionType: excluded.collectionType,
            ),
            target: [db.vaultItems.id],
          ),
        ));
      }

      for (var i = 0; i < itemCompanions.length; i += batchChunkSize) {
        final chunk = itemCompanions.sublist(
          i,
          math.min(i + batchChunkSize, itemCompanions.length),
        );
        await db.batch((b) => b.insertAll(db.deckVersionItems, chunk, mode: InsertMode.insertOrReplace));
      }
    });

    await repairSyntheticPreconVaultItems(db);
    await repairArtSeriesCards(db);
  }

  /// Repairs synthetic precon vault_items rows in SQLite so that cards with
  /// synthetic oracle IDs ('12a34567-...', '722a3456-...', '812a3456-...')
  /// or recent acquired_date timestamps use Scryfall named normal URLs
  /// and historical release timestamps.
  static Future<void> repairSyntheticPreconVaultItems(AppDatabase db) async {
    final syntheticRows = await db.customSelect('''
      SELECT id, name, set_or_series, acquired_date, image_url, dynamic_data
      FROM vault_items
      WHERE quantity = 0 AND (
        dynamic_data LIKE '%12a34567-%' OR
        dynamic_data LIKE '%722a3456-%' OR
        dynamic_data LIKE '%812a3456-%'
      );
    ''').get();

    if (syntheticRows.isEmpty) return;

    await db.batch((b) {
      for (final row in syntheticRows) {
        final id = row.read<String>('id');
        final name = row.read<String>('name');
        final setCode = (row.readNullable<String>('set_or_series') ?? '').toUpperCase();
        final currentAcquired = row.read<DateTime>('acquired_date');
        final currentImageUrl = row.readNullable<String>('image_url') ?? '';

        DateTime historicalDate;
        if (setCode == 'C17') {
          historicalDate = DateTime(2017);
        } else if (setCode == 'C16') {
          historicalDate = DateTime(2016);
        } else if (setCode == 'MOC') {
          historicalDate = DateTime(2023);
        } else {
          historicalDate = DateTime(2020);
        }

        final namedUrl = CountrCachedImage.buildScryfallNamedUrl(name, version: 'normal');
        final needsUrlRepair = currentImageUrl.isEmpty ||
            currentImageUrl.contains('cards.scryfall.io') ||
            currentImageUrl.contains('/normal/front/');
        final needsDateRepair = currentAcquired.isAfter(DateTime(2025));

        if (needsUrlRepair || needsDateRepair) {
          b.update(
            db.vaultItems,
            VaultItemsCompanion(
              acquiredDate: needsDateRepair ? Value(historicalDate) : const Value.absent(),
              imageUrl: needsUrlRepair ? Value(namedUrl) : const Value.absent(),
            ),
            where: (t) => t.id.equals(id),
          );
        }
      }
    });
  }

  /// Inspects explore_decks, explore_deck_items, and vault_items to automatically
  /// repair stored art_series URLs, identical "X // X" names, or /art_crop/ URLs.
  static Future<void> repairArtSeriesCards(AppDatabase db) async {
    // 1. Repair explore_decks
    final dirtyDecks = await db.customSelect('''
      SELECT id, name, commander_name, commander_image_url, commander_art_crop
      FROM explore_decks
      WHERE commander_image_url LIKE '%art_series%'
         OR commander_image_url LIKE '%/art_crop/%'
         OR commander_art_crop LIKE '%art_series%'
         OR commander_name LIKE '%//%'
         OR commander_name LIKE '%Art Card%'
         OR commander_name LIKE '%Art Series%';
    ''').get();

    for (final row in dirtyDecks) {
      final id = row.read<String>('id');
      final deckName = row.read<String>('name');
      final rawCmdr = row.readNullable<String>('commander_name') ?? deckName;

      String cleanName = rawCmdr;
      if (cleanName.contains('//')) {
        final parts = cleanName.split('//').map((p) => p.trim()).toList();
        if (parts.length >= 2 && parts[0].toLowerCase() == parts[1].toLowerCase()) {
          cleanName = parts[0];
        } else {
          cleanName = parts.first;
        }
      }
      cleanName = cleanName
          .replaceAll(RegExp(r'\s*\((?:Art Card|Art Series)\)', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s*-\s*(?:Art Card|Art Series)', caseSensitive: false), '')
          .trim();
      if (cleanName.isEmpty) cleanName = deckName;

      final normalUrl = CountrCachedImage.buildScryfallNamedUrl(cleanName, version: 'normal');
      final artCropUrl = CountrCachedImage.buildScryfallNamedUrl(cleanName, version: 'art_crop');

      await db.customUpdate('''
        UPDATE explore_decks
        SET commander_name = ?,
            commander_image_url = ?,
            commander_art_crop = ?
        WHERE id = ?;
      ''', variables: [
        Variable.withString(cleanName),
        Variable.withString(normalUrl),
        Variable.withString(artCropUrl),
        Variable.withString(id),
      ]);
    }

    // 2. Repair explore_deck_items
    final dirtyItems = await db.customSelect('''
      SELECT id, card_name, image_url, art_crop_url, dynamic_data
      FROM explore_deck_items
      WHERE image_url LIKE '%art_series%'
         OR image_url LIKE '%/art_crop/%'
         OR art_crop_url LIKE '%art_series%'
         OR card_name LIKE '%//%'
         OR card_name LIKE '%Art Card%'
         OR card_name LIKE '%Art Series%'
         OR dynamic_data LIKE '%art_series%'
         OR dynamic_data LIKE '%double_faced_token%'
         OR dynamic_data LIKE '%memorabilia%';
    ''').get();

    for (final row in dirtyItems) {
      final id = row.read<String>('id');
      final rawName = row.read<String>('card_name');
      String cleanName = rawName;
      if (cleanName.contains('//')) {
        final parts = cleanName.split('//').map((p) => p.trim()).toList();
        if (parts.length >= 2 && parts[0].toLowerCase() == parts[1].toLowerCase()) {
          cleanName = parts[0];
        }
      }
      cleanName = cleanName
          .replaceAll(RegExp(r'\s*\((?:Art Card|Art Series)\)', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s*-\s*(?:Art Card|Art Series)', caseSensitive: false), '')
          .trim();

      final normalUrl = CountrCachedImage.buildScryfallNamedUrl(cleanName, version: 'normal');
      final artCropUrl = CountrCachedImage.buildScryfallNamedUrl(cleanName, version: 'art_crop');

      await db.customUpdate('''
        UPDATE explore_deck_items
        SET card_name = ?,
            image_url = ?,
            art_crop_url = ?
        WHERE id = ?;
      ''', variables: [
        Variable.withString(cleanName),
        Variable.withString(normalUrl),
        Variable.withString(artCropUrl),
        Variable.withString(id),
      ]);
    }

    // 3. Repair vault_items
    final dirtyVault = await db.customSelect('''
      SELECT id, name, image_url, dynamic_data
      FROM vault_items
      WHERE image_url LIKE '%art_series%'
         OR image_url LIKE '%/art_crop/%'
         OR name LIKE '%//%'
         OR name LIKE '%Art Card%'
         OR name LIKE '%Art Series%'
         OR dynamic_data LIKE '%art_series%'
         OR dynamic_data LIKE '%double_faced_token%'
         OR dynamic_data LIKE '%memorabilia%';
    ''').get();

    for (final row in dirtyVault) {
      final id = row.read<String>('id');
      final rawName = row.read<String>('name');
      String cleanName = rawName;
      if (cleanName.contains('//')) {
        final parts = cleanName.split('//').map((p) => p.trim()).toList();
        if (parts.length >= 2 && parts[0].toLowerCase() == parts[1].toLowerCase()) {
          cleanName = parts[0];
        }
      }
      cleanName = cleanName
          .replaceAll(RegExp(r'\s*\((?:Art Card|Art Series)\)', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s*-\s*(?:Art Card|Art Series)', caseSensitive: false), '')
          .trim();

      final normalUrl = CountrCachedImage.buildScryfallNamedUrl(cleanName, version: 'normal');
      final dynStr = row.readNullable<String>('dynamic_data');
      String? cleanDyn = dynStr;
      if (dynStr != null && dynStr.isNotEmpty) {
        try {
          final dyn = jsonDecode(dynStr) as Map<String, dynamic>;
          dyn['layout'] = 'normal';
          dyn['image_uris'] = {
            'small': normalUrl,
            'normal': normalUrl,
            'large': normalUrl,
            'art_crop': CountrCachedImage.buildScryfallNamedUrl(cleanName, version: 'art_crop'),
          };
          cleanDyn = jsonEncode(dyn);
        } catch (_) {}
      }

      await db.customUpdate('''
        UPDATE vault_items
        SET name = ?,
            image_url = ?,
            dynamic_data = ?
        WHERE id = ?;
      ''', variables: [
        Variable.withString(cleanName),
        Variable.withString(normalUrl),
        Variable.withString(cleanDyn ?? '{}'),
        Variable.withString(id),
      ]);
    }
  }
}

