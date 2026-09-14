import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/database/tables/vault_binders_table.dart';
import 'package:countr/core/database/tables/vault_items_table.dart';
import 'package:countr/features/scanner/domain/ocr_heuristic_matcher.dart';

part 'vault_dao.g.dart';

/// Data Access Object for VaultItems and VaultBinders with polymorphic queries and seeding.
@DriftAccessor(tables: [VaultItems, VaultBinders])
class VaultDao extends DatabaseAccessor<AppDatabase> with _$VaultDaoMixin {
  VaultDao(super.db);

  /// Streams items filtered by collection type.
  /// If [onlyOwned] is true, filters for quantity > 0 (personal vault inventory).
  /// If [limit] is provided, caps the returned rows to prevent UI thread memory spikes.
  Stream<List<VaultItem>> watchItemsByCollection(
    String collectionType, {
    bool onlyOwned = false,
    int? limit,
    int? offset,
  }) {
    final normalized = _normalizeCollectionType(collectionType);
    final query = select(vaultItems);

    if (normalized != 'all') {
      query.where((t) => t.collectionType.equals(normalized));
    }

    if (onlyOwned) {
      query.where((t) => t.quantity.isBiggerThanValue(0));
    }

    query.orderBy([
      (t) => OrderingTerm(
            expression: t.acquiredDate,
            mode: OrderingMode.desc,
          ),
      (t) => OrderingTerm(
            expression: t.name,
            mode: OrderingMode.asc,
          ),
    ]);

    if (limit != null) {
      query.limit(limit, offset: offset);
    }

    return query.watch();
  }

  /// One-shot query to fetch cards by collection type.
  Future<List<VaultItem>> getItemsByCollection(
    String collectionType, {
    bool onlyOwned = false,
    int? limit,
    int? offset,
  }) {
    final normalized = _normalizeCollectionType(collectionType);
    final query = select(vaultItems);

    if (normalized != 'all') {
      query.where((t) => t.collectionType.equals(normalized));
    }

    if (onlyOwned) {
      query.where((t) => t.quantity.isBiggerThanValue(0));
    }

    query.orderBy([
      (t) => OrderingTerm(
            expression: t.acquiredDate,
            mode: OrderingMode.desc,
          ),
      (t) => OrderingTerm(
            expression: t.name,
            mode: OrderingMode.asc,
          ),
    ]);

    if (limit != null) {
      query.limit(limit, offset: offset);
    }

    return query.get();
  }

  /// Normalizes display collection titles to internal collection types.
  String _normalizeCollectionType(String type) {
    final lower = type.toLowerCase().trim();
    if (lower == 'all collections' ||
        lower == 'all' ||
        lower == 'my vault' ||
        lower == 'all vault') {
      return 'all';
    }
    if (lower.contains('magic') || lower == 'mtg') {
      return 'mtg';
    }
    if (lower.contains('pokémon') || lower.contains('pokemon')) {
      return 'pokemon';
    }
    if (lower.contains('comic')) {
      return 'comic';
    }
    if (lower.contains('sport')) {
      return 'sports_card';
    }
    return lower;
  }

  /// Seeds the 4 hyper-detailed mock records if the ledger is empty.
  Future<void> seedDatabase() async {
    final existing = await select(vaultItems).get();
    if (existing.isNotEmpty) return;

    final now = DateTime.now();

    await batch((b) {
      b.insertAll(vaultItems, [
        // 1. MTG: The One Ring
        VaultItemsCompanion.insert(
          id: 'item-mtg-one-ring',
          collectionType: 'mtg',
          name: 'The One Ring (Serialized #007/100)',
          setOrSeries: 'The Lord of the Rings: Tales of Middle-earth',
          imageUrl:
              'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?auto=format&fit=crop&w=400&q=80',
          acquiredPrice: 15.00,
          acquiredDate: now.subtract(const Duration(days: 45)),
          quantity: const Value(1),
          condition: 'NM',
          isGraded: const Value(false),
          personalNotes: const Value(
              'Pulled from collector booster at TBS Comics. Flawless surface.'),
          currentMarketPrice: 45.50,
          lastPriceUpdate: now,
          dynamicData:
              '{"mana": "2UB", "type": "Creature", "power": 3, "toughness": 2}',
        ),

        // 2. Pokémon: Charizard ex
        VaultItemsCompanion.insert(
          id: 'item-pokemon-charizard',
          collectionType: 'pokemon',
          name: 'Charizard ex',
          setOrSeries: 'Scarlet & Violet: 151',
          imageUrl:
              'https://images.unsplash.com/photo-1613771404784-3a5686aa2be3?auto=format&fit=crop&w=400&q=80',
          acquiredPrice: 4.50,
          acquiredDate: now.subtract(const Duration(days: 60)),
          quantity: const Value(1),
          condition: 'LP',
          isGraded: const Value(false),
          personalNotes: const Value(
              'Minor corner wear on rear. Stored in double sleeve.'),
          currentMarketPrice: 3.25,
          lastPriceUpdate: now,
          dynamicData: '{"hp": 120, "stage": "Basic"}',
        ),

        // 3. Comic Book: Ultimate Fallout #4
        VaultItemsCompanion.insert(
          id: 'item-comic-fallout-4',
          collectionType: 'comic',
          name: 'Ultimate Fallout #4 (1st Miles Morales)',
          setOrSeries: 'Marvel Comics • 1st Print 2011',
          imageUrl:
              'https://images.unsplash.com/photo-1569003339405-ea396a5a8a90?auto=format&fit=crop&w=400&q=80',
          acquiredPrice: 150.00,
          acquiredDate: now.subtract(const Duration(days: 180)),
          quantity: const Value(1),
          condition: 'CGC 9.8',
          isGraded: const Value(true),
          personalNotes: const Value(
              'Graded CGC 9.8 with pristine white pages. Holy grail issue.'),
          currentMarketPrice: 210.00,
          lastPriceUpdate: now,
          dynamicData: '{"issue": 1, "publisher": "Marvel"}',
        ),

        // 4. Sports Card: T.J. Watt Prizm Silver Rookie
        VaultItemsCompanion.insert(
          id: 'item-sports-watt-rookie',
          collectionType: 'sports_card',
          name: 'T.J. Watt Prizm Silver Rookie',
          setOrSeries: '2017 Panini Prizm Football',
          imageUrl:
              'https://images.unsplash.com/photo-1587280501635-68a0e82cd5ff?auto=format&fit=crop&w=400&q=80',
          acquiredPrice: 20.00,
          acquiredDate: now.subtract(const Duration(days: 365)),
          quantity: const Value(1),
          condition: 'PSA 10',
          isGraded: const Value(true),
          personalNotes:
              const Value('Gem Mint 10 rookie card. True investment hold.'),
          currentMarketPrice: 180.00,
          lastPriceUpdate: now,
          dynamicData:
              '{"sport": "Football", "team": "Steelers", "is_rookie": true}',
        ),
      ]);
    });
  }

  /// Inserts a new vault item.
  Future<int> insertItem(VaultItemsCompanion item) =>
      into(vaultItems).insert(item);

  /// Inserts large lists of catalog/dictionary items in chunks of 1,000 using batch().
  /// Prevents database lockups, transaction limits, and OOM crashes.
  /// Uses Drift's true UPSERT (DoUpdate) to update catalog metadata while strictly
  /// preserving all user inventory fields (quantity, acquiredPrice, condition, personalNotes).
  Future<void> insertDictionaryChunked(
    List<VaultItemsCompanion> items, {
    void Function(int inserted, int total)? onProgress,
  }) async {
    const chunkSize = 1000;
    final total = items.length;
    var inserted = 0;

    for (var i = 0; i < total; i += chunkSize) {
      final end = (i + chunkSize < total) ? i + chunkSize : total;
      final chunk = items.sublist(i, end);

      await insertDictionaryBatch(chunk);

      inserted += chunk.length;
      onProgress?.call(inserted, total);
    }
  }

  /// Inserts a single chunk of dictionary items with true UPSERT conflict resolution.
  /// Upon an ID conflict, overwrites ONLY catalog-level fields (pricing, images, metadata)
  /// and explicitly preserves all user-level inventory fields.
  Future<void> insertDictionaryBatch(List<VaultItemsCompanion> chunk) async {
    await batch((b) {
      b.insertAll(
        vaultItems,
        chunk,
        onConflict: DoUpdate<$VaultItemsTable, VaultItem>.withExcluded(
          (old, excluded) => VaultItemsCompanion.custom(
            name: excluded.name,
            setOrSeries: excluded.setOrSeries,
            imageUrl: excluded.imageUrl,
            currentMarketPrice: excluded.currentMarketPrice,
            lastPriceUpdate: excluded.lastPriceUpdate,
            dynamicData: excluded.dynamicData,
            collectionType: excluded.collectionType,
          ),
          target: [vaultItems.id],
        ),
      );
    });
  }

  /// Deletes all items (used for test resets).
  Future<int> clearAllItems() => delete(vaultItems).go();

  // ---------------------------------------------------------------------------
  // PHASE 3: VAULT BINDER METHODS
  // ---------------------------------------------------------------------------

  /// Streams all binders filtered by collection type (or all collections).
  Stream<List<VaultBinder>> watchBindersByCollection(String collectionType) {
    final normalized = _normalizeCollectionType(collectionType);
    final query = select(vaultBinders);
    if (normalized != 'all') {
      query.where((t) => t.collectionType.equals(normalized));
    }
    query.orderBy([
      (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
    ]);
    return query.watch();
  }

  /// Creates a new custom Vault Binder with an active game context.
  Future<VaultBinder> createBinder({
    required String name,
    required String collectionType,
  }) async {
    final id = const Uuid().v4();
    final normalized = _normalizeCollectionType(collectionType);
    final binder = VaultBindersCompanion.insert(
      id: id,
      name: name.trim().isEmpty ? 'Untitled Binder' : name.trim(),
      collectionType: normalized == 'all' ? 'mtg' : normalized,
      createdAt: DateTime.now(),
    );
    await into(vaultBinders).insert(binder);
    return (select(vaultBinders)..where((t) => t.id.equals(id))).getSingle();
  }

  /// Streams a map of binderId -> total items anchored inside that binder.
  Stream<Map<String, int>> watchBinderItemCounts() {
    final query = select(vaultItems)
      ..where((t) =>
          t.quantity.isBiggerThanValue(0) & t.primaryBinderId.isNotNull());
    return query.watch().map((items) {
      final counts = <String, int>{};
      for (final item in items) {
        final loc = item.primaryBinderId;
        if (loc != null) {
          counts[loc] = (counts[loc] ?? 0) + item.quantity;
        }
      }
      return counts;
    });
  }

  /// Bulk assigns a list of item IDs to their physical home anchor (binder).
  Future<int> assignItemsToBinder(
      List<String> itemIds, String targetBinderId) async {
    return (update(vaultItems)..where((t) => t.id.isIn(itemIds))).write(
      VaultItemsCompanion(
        primaryBinderId: Value(targetBinderId),
      ),
    );
  }

  /// Alias for assignItemsToBinder
  Future<int> moveItemsToBinder(
          List<String> itemIds, String targetBinderId) =>
      assignItemsToBinder(itemIds, targetBinderId);

  /// Streams all owned cards anchored to a specific physical binder.
  Stream<List<VaultItem>> watchItemsByBinder(String binderId) {
    return (select(vaultItems)
          ..where((t) =>
              t.primaryBinderId.equals(binderId) &
              t.quantity.isBiggerThanValue(0))
          ..orderBy([
            (t) => OrderingTerm(
                expression: t.lastPriceUpdate, mode: OrderingMode.desc),
            (t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc),
          ]))
        .watch();
  }

  // ---------------------------------------------------------------------------
  // PHASE 3: INBOX HOLDING AREA
  // ---------------------------------------------------------------------------

  /// Streams all owned cards currently staged in the "Inbox" holding area (primaryBinderId is NULL).
  Stream<List<VaultItem>> watchInboxItems() {
    return (select(vaultItems)
          ..where((t) =>
              t.primaryBinderId.isNull() &
              t.quantity.isBiggerThanValue(0))
          ..orderBy([
            (t) => OrderingTerm(
                expression: t.lastPriceUpdate, mode: OrderingMode.desc),
            (t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc),
          ]))
        .watch();
  }

  // ---------------------------------------------------------------------------
  // PHASE 3: REAL-TIME SCANNER CARD MATCHING
  // ---------------------------------------------------------------------------

  static const String _sqliteNameNormalized = r'''
    replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(
      lower(
        substr(
          substr("name", 1, instr("name" || ' //', ' //') - 1),
          1,
          instr(substr("name", 1, instr("name" || ' //', ' //') - 1) || ' (', ' (') - 1
        )
      ),
      char(34), ''), char(39), ''), '-', ''), ',', ''), ':', ''), '.', ''), '’', ''), '‘', ''), '!', ''), '?', ''), ';', ''), '&', '')
  ''';

  /// Real-time search in SQLite for a card matching OCR candidate lines.
  /// Strictly requires line-by-line exact matching on cleaned lines and guards against
  /// empty or short noise lines (< 3 characters) to eliminate false positives
  /// (such as the "Lifetime" Pass Holder bug).
  Future<VaultItem?> matchScannedCard(
    List<String> cleanedOcrLines,
    String activeContext, {
    String? collectorNumber,
    String? setCode,
  }) async {
    // 1. Empty String & Short Guard: If empty or all lines < 3 chars, return null immediately
    if (cleanedOcrLines.isEmpty) return null;

    final validLines = cleanedOcrLines
        .map((l) => OcrHeuristicMatcher.sanitizeText(l))
        .where((l) => l.length >= 3)
        .toList();

    if (validLines.isEmpty) return null;

    final normalized = _normalizeCollectionType(activeContext);

    // 2. Collector Number Override: If a collector number pattern exists, prioritize querying it
    if (collectorNumber != null && collectorNumber.trim().isNotEmpty) {
      final cleanCollector = collectorNumber.trim();
      final collectorQuery = select(vaultItems)
        ..where((t) {
          Expression<bool> predicate = t.dynamicData
                  .like('%"collector_number":"$cleanCollector"%') |
              t.dynamicData.like('%"collector_number": "$cleanCollector"%');
          if (normalized != 'all') {
            predicate = predicate & t.collectionType.equals(normalized);
          }
          return predicate;
        })
        ..limit(5);

      final collectorMatches = await collectorQuery.get();
      if (collectorMatches.isNotEmpty) {
        // If any line matches the card's cleaned name, return that exact card
        for (final card in collectorMatches) {
          final cardCleaned = OcrHeuristicMatcher.sanitizeText(card.name);
          if (validLines.contains(cardCleaned)) {
            return card;
          }
        }
        // If single collector match in the active collection, return it
        if (collectorMatches.length == 1) {
          return collectorMatches.first;
        }
      }
    }

    // 3. Line-by-Line Exact Match (No fuzzy LIKE):
    // First, query catalog reference items (quantity == 0)
    for (final line in validLines) {
      final sqlCatalog = normalized != 'all'
          ? '''
            SELECT * FROM "vault_items"
            WHERE "collection_type" = ?
              AND "quantity" = 0
              AND (
                "name" = ? COLLATE NOCASE
                OR $_sqliteNameNormalized = ?
              )
            LIMIT 1;
            '''
          : '''
            SELECT * FROM "vault_items"
            WHERE "quantity" = 0
              AND (
                "name" = ? COLLATE NOCASE
                OR $_sqliteNameNormalized = ?
              )
            LIMIT 1;
            ''';

      final catalogMatch = await customSelect(
        sqlCatalog,
        variables: [
          if (normalized != 'all') Variable.withString(normalized),
          Variable.withString(line),
          Variable.withString(line),
        ],
        readsFrom: {vaultItems},
      ).map((row) => vaultItems.map(row.data)).getSingleOrNull();

      if (catalogMatch != null) {
        debugPrint('[VaultDao.matchScannedCard] Matched catalog item: "${catalogMatch.name}" from line: "$line" (context: $normalized)');
        return catalogMatch;
      }
    }

    // 4. Fallback: Check all items (including owned cards quantity > 0) with exact match
    for (final line in validLines) {
      final sqlFallback = normalized != 'all'
          ? '''
            SELECT * FROM "vault_items"
            WHERE "collection_type" = ?
              AND (
                "name" = ? COLLATE NOCASE
                OR $_sqliteNameNormalized = ?
              )
            LIMIT 1;
            '''
          : '''
            SELECT * FROM "vault_items"
            WHERE (
              "name" = ? COLLATE NOCASE
              OR $_sqliteNameNormalized = ?
            )
            LIMIT 1;
            ''';

      final fallbackMatch = await customSelect(
        sqlFallback,
        variables: [
          if (normalized != 'all') Variable.withString(normalized),
          Variable.withString(line),
          Variable.withString(line),
        ],
        readsFrom: {vaultItems},
      ).map((row) => vaultItems.map(row.data)).getSingleOrNull();

      if (fallbackMatch != null) {
        debugPrint('[VaultDao.matchScannedCard] Matched inventory item: "${fallbackMatch.name}" from line: "$line" (context: $normalized)');
        return fallbackMatch;
      }
    }

    // 5. Cross-Collection Fallback: If active context didn't match, search across all collections
    if (normalized != 'all') {
      for (final line in validLines) {
        final sqlAny = '''
          SELECT * FROM "vault_items"
          WHERE (
            "name" = ? COLLATE NOCASE
            OR $_sqliteNameNormalized = ?
          )
          LIMIT 1;
        ''';

        final anyMatch = await customSelect(
          sqlAny,
          variables: [
            Variable.withString(line),
            Variable.withString(line),
          ],
          readsFrom: {vaultItems},
        ).map((row) => vaultItems.map(row.data)).getSingleOrNull();

        if (anyMatch != null) {
          debugPrint('[VaultDao.matchScannedCard] Matched cross-collection item: "${anyMatch.name}" from line: "$line" (collection: "${anyMatch.collectionType}")');
          return anyMatch;
        }
      }
    }

    return null;
  }

  /// Instantly UPSERTs a matched card into the user's Inbox holding area.
  Future<void> upsertScannedCardToInbox(
    VaultItem card, {
    bool isFoil = false,
  }) async {
    final existing = await (select(vaultItems)..where((t) => t.id.equals(card.id)))
        .getSingleOrNull();

    if (existing == null) {
      await into(vaultItems).insert(
        VaultItemsCompanion.insert(
          id: card.id,
          collectionType: card.collectionType,
          name: card.name,
          setOrSeries: card.setOrSeries,
          imageUrl: card.imageUrl,
          acquiredPrice: card.currentMarketPrice,
          acquiredDate: DateTime.now(),
          quantity: const Value(1),
          condition: isFoil ? 'NM (Foil)' : 'NM',
          isGraded: const Value(false),
          personalNotes: isFoil
              ? const Value('Scanned Foil / Variant')
              : const Value('Edge Scanned'),
          currentMarketPrice: card.currentMarketPrice,
          lastPriceUpdate: DateTime.now(),
          dynamicData: card.dynamicData,
          primaryBinderId: const Value(null),
        ),
      );
    } else {
      final newQuantity = existing.quantity > 0 ? existing.quantity + 1 : 1;
      final newNotes = existing.personalNotes != null &&
              existing.personalNotes!.isNotEmpty
          ? existing.personalNotes
          : (isFoil ? 'Scanned Foil / Variant' : 'Edge Scanned');

      await (update(vaultItems)..where((t) => t.id.equals(card.id))).write(
        VaultItemsCompanion(
          quantity: Value(newQuantity),
          primaryBinderId: Value(existing.primaryBinderId),
          currentMarketPrice: Value(card.currentMarketPrice),
          lastPriceUpdate: Value(DateTime.now()),
          condition:
              isFoil ? const Value('NM (Foil)') : Value(existing.condition),
          personalNotes: Value(newNotes),
        ),
      );
    }
  }
}
