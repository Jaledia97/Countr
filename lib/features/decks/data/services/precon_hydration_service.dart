import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:drift/drift.dart';

import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/data/models/precon_deck_dto.dart';
import 'package:countr/features/decks/data/services/mtgjson_precon_parser.dart';
import 'package:countr/features/decks/data/services/fallback_explore_seeds.dart';

/// Service orchestrating offline ingestion, background isolate parsing,
/// and atomic SQLite seeding of official MTG preconstructed decks.
class PreconHydrationService {
  static bool _isSeeding = false;

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
    return Isolate.run(() => MtgjsonPreconParser.parseJson(rawJson));
  }

  /// Parses raw byte data into [PreconDeckDto]s in a background isolate.
  static Future<List<PreconDeckDto>> parseBytesInIsolate(Uint8List byteData) {
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
      final bd = await rootBundle.load(effectivePath);
      byteData = bd.buffer.asUint8List();
    } catch (_) {
      // Fallback: Check local filesystem for test environments
      try {
        final file = File(effectivePath);
        if (file.existsSync()) {
          byteData = await file.readAsBytes();
        }
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
    if (_isSeeding) {
      debugPrint('[PreconHydrationService] Seeding already in progress. Skipping concurrent request.');
      return;
    }
    _isSeeding = true;

    try {
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
    } finally {
      _isSeeding = false;
    }
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
      final deckCreatedAt = precon.releaseDate ?? now;
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
        // Collect catalog reference row for vault_items (unowned, quantity = 0)
        if (!vaultItemsMap.containsKey(card.scryfallId)) {
          vaultItemsMap[card.scryfallId] = VaultItemsCompanion.insert(
            id: card.scryfallId,
            collectionType: 'mtg',
            name: card.name,
            setOrSeries: precon.setCode ?? 'Catalog',
            imageUrl: card.imageUrl ?? '',
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

    // Execute everything in a single atomic transaction
    await db.transaction(() async {
      // Step A: Insert parent decks
      for (var i = 0; i < deckCompanions.length; i += batchChunkSize) {
        final chunk = deckCompanions.skip(i).take(batchChunkSize).toList();
        await db.batch((b) {
          b.insertAll(db.decks, chunk, mode: InsertMode.insertOrReplace);
        });
      }

      // Step B: Insert active deck versions (FK references decks)
      for (var i = 0; i < versionCompanions.length; i += batchChunkSize) {
        final chunk = versionCompanions.skip(i).take(batchChunkSize).toList();
        await db.batch((b) {
          b.insertAll(db.deckVersions, chunk, mode: InsertMode.insertOrReplace);
        });
      }

      // Step C: Insert catalog reference rows into vault_items (preserving owned cards)
      for (var i = 0; i < vaultCompanions.length; i += batchChunkSize) {
        final chunk = vaultCompanions.skip(i).take(batchChunkSize).toList();
        await db.batch((b) {
          b.insertAll(
            db.vaultItems,
            chunk,
            onConflict: DoUpdate<$VaultItemsTable, VaultItem>.withExcluded(
              (old, excluded) => VaultItemsCompanion.custom(
                name: excluded.name,
                flavorName: excluded.flavorName,
                setOrSeries: excluded.setOrSeries,
                imageUrl: const CustomExpression<String>(
                  'CASE WHEN excluded.image_url IS NOT NULL AND excluded.image_url != \'\' THEN excluded.image_url ELSE vault_items.image_url END',
                ),
                currentMarketPrice: const CustomExpression<double>(
                  'CASE WHEN excluded.current_market_price > 0.0 THEN excluded.current_market_price ELSE vault_items.current_market_price END',
                ),
                lastPriceUpdate: const CustomExpression<DateTime>(
                  'CASE WHEN excluded.current_market_price > 0.0 THEN excluded.last_price_update ELSE vault_items.last_price_update END',
                ),
                dynamicData: excluded.dynamicData,
                collectionType: excluded.collectionType,
              ),
              target: [db.vaultItems.id],
            ),
          );
        });
      }

      // Step D: Insert deck items (FK references deck_versions and vault_items)
      for (var i = 0; i < itemCompanions.length; i += batchChunkSize) {
        final chunk = itemCompanions.skip(i).take(batchChunkSize).toList();
        await db.batch((b) {
          b.insertAll(
            db.deckVersionItems,
            chunk,
            mode: InsertMode.insertOrReplace,
          );
        });
      }
    });
  }
}
