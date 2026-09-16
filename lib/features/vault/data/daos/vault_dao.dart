import 'dart:convert';
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
    String? searchQuery,
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

    query.where((t) =>
        t.primaryBinderId.isNull() |
        t.primaryBinderId.equals('INBOX').not());

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final term = '%${searchQuery.trim()}%';
      query.where((t) => t.name.like(term) | t.setOrSeries.like(term));
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
    String? searchQuery,
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

    query.where((t) =>
        t.primaryBinderId.isNull() |
        t.primaryBinderId.equals('INBOX').not());

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final term = '%${searchQuery.trim()}%';
      query.where((t) => t.name.like(term) | t.setOrSeries.like(term));
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

  /// Updates personal notes and deck history tags for a vault item without wiping existing dynamicData.
  Future<int> updateItemNotesAndDecks(
    String id, {
    String? personalNotes,
    List<String>? deckTags,
    String? communityNotes,
  }) async {
    final existing =
        await (select(vaultItems)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (existing == null) return 0;

    Map<String, dynamic> data = {};
    if (existing.dynamicData.isNotEmpty) {
      try {
        data = jsonDecode(existing.dynamicData) as Map<String, dynamic>;
      } catch (_) {}
    }

    if (deckTags != null) {
      data['deck_history'] = deckTags;
    }
    if (communityNotes != null) {
      data['use_cases'] = communityNotes;
    }

    return (update(vaultItems)..where((t) => t.id.equals(id))).write(
      VaultItemsCompanion(
        personalNotes: personalNotes != null
            ? Value(personalNotes)
            : const Value.absent(),
        dynamicData: Value(jsonEncode(data)),
      ),
    );
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
              'https://cards.scryfall.io/large/front/7/8/78038b95-30f2-4e4b-972f-04cfa65c275a.jpg',
          acquiredPrice: 15.00,
          acquiredDate: now.subtract(const Duration(days: 45)),
          quantity: const Value(1),
          condition: 'NM',
          isGraded: const Value(false),
          personalNotes: const Value(
              'Pulled from collector booster at TBS Comics. Serialized #007/100.'),
          currentMarketPrice: 45.50,
          lastPriceUpdate: now,
          dynamicData: jsonEncode({
            'mana': '{4}',
            'mana_cost': '{4}',
            'type': 'Legendary Artifact',
            'type_line': 'Legendary Artifact',
            'oracle_text':
                'Indestructible\nAs The One Ring enters the battlefield, if you cast it, you gain protection from everything until your next turn.\nAt the beginning of your upkeep, you lose 1 life for each burden counter on The One Ring.\n{T}: Put a burden counter on The One Ring, then draw a card for each burden counter on The One Ring.',
            'keywords': ['Indestructible'],
            'rarity': 'mythic',
            'collector_number': '007',
            'set_code': 'ltr',
            'set': 'ltr',
            'artist': 'Tania Sanchez-Fortun',
            'flavor_text':
                'One Ring to rule them all, One Ring to find them, One Ring to bring them all and in the darkness bind them.',
            'rulings':
                "Protection from everything means that you can't be targeted by anything, damaged by anything, enchanted/equipped by anything, or blocked by anything.",
            'legalities': {
              'standard': 'not_legal',
              'modern': 'legal',
              'commander': 'legal',
              'legacy': 'legal',
              'vintage': 'restricted',
            },
            'scryfall_uri': 'https://scryfall.com/card/ltr/246/the-one-ring',
          }),
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
          t.quantity.isBiggerThanValue(0) &
          t.primaryBinderId.isNotNull() &
          t.primaryBinderId.equals('INBOX').not());
    return query.watch().map((items) {
      final counts = <String, int>{};
      for (final item in items) {
        final loc = item.primaryBinderId;
        if (loc != null && loc != 'INBOX') {
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

  /// Streams all owned cards currently staged in the "Inbox" holding area (primaryBinderId == 'INBOX').
  Stream<List<VaultItem>> watchInboxItems() {
    return (select(vaultItems)
          ..where((t) =>
              t.primaryBinderId.equals('INBOX') &
              t.quantity.isBiggerThanValue(0))
          ..orderBy([
            (t) => OrderingTerm(
                expression: t.lastPriceUpdate, mode: OrderingMode.desc),
            (t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc),
          ]))
        .watch();
  }

  // ---------------------------------------------------------------------------
  // PHASE 3: ITEM DELETION
  // ---------------------------------------------------------------------------

  /// Permanently deletes a single item from SQLite by its ID.
  Future<int> deleteItem(String id) {
    return (delete(vaultItems)..where((t) => t.id.equals(id))).go();
  }

  /// Permanently deletes multiple items from SQLite by their IDs.
  Future<int> deleteItems(List<String> ids) {
    if (ids.isEmpty) return Future.value(0);
    return (delete(vaultItems)..where((t) => t.id.isIn(ids))).go();
  }

  // ---------------------------------------------------------------------------
  // PHASE 3: REAL-TIME SCANNER CARD MATCHING
  // ---------------------------------------------------------------------------

  /// Extracts the base card name by stripping split / adventure card delimiter (' //')
  /// and variant / serialized subtitle (' (').
  String _extractBaseCardName(String name) {
    var base = name;
    final slashIndex = base.indexOf(' //');
    if (slashIndex != -1) base = base.substring(0, slashIndex);
    final parenIndex = base.indexOf(' (');
    if (parenIndex != -1) base = base.substring(0, parenIndex);
    return base.trim();
  }

  /// Real-time hybrid search in SQLite and Dart for a card matching OCR candidate lines.
  ///
  /// Requirement R3 Hybrid Matching Engine:
  /// - Step 1 (Regex Override): Extracts collector number patterns (xxx/yyy, #xxx, SV01-xxx)
  ///   or uses explicit collectorNumber parameter and queries dynamic_data LIMIT 1.
  /// - Step 2 (SQL Wide Net): Filters OCR lines length >= 4 (ordered descending by length),
  ///   extracts first 5 characters, and queries SQLite:
  ///   `WHERE name LIKE '$firstFiveChars%' AND quantity == 0 LIMIT 25`.
  /// - Step 3 (Dart `contains` Verification): Iterates candidate items in memory, sanitizes
  ///   names via [sanitize], and confirms match via `sanitizedOcrLine.contains(sanitizedDbName)`
  ///   or `sanitizedOcrLine.contains(sanitizedBaseDbName)`.
  Future<VaultItem?> matchScannedCard(
    List<String> cleanedOcrLines,
    String activeContext, {
    String? collectorNumber,
    String? setCode,
    bool enforceMultiFactor = false,
  }) async {
    // -------------------------------------------------------------------------
    // Guard: Empty Input Check
    // -------------------------------------------------------------------------
    if (cleanedOcrLines.isEmpty &&
        (collectorNumber == null || collectorNumber.trim().isEmpty)) {
      return null;
    }

    final normalized = _normalizeCollectionType(activeContext);

    // Helper to evaluate multi-factor gate when enforceMultiFactor is enabled
    bool validateMultiFactor(VaultItem item, {String? detectedCollector}) {
      if (!enforceMultiFactor) return true;
      String? cardCollector = collectorNumber;
      String? cardSet = setCode;
      String? cardTypeLine;
      if (item.dynamicData.isNotEmpty) {
        try {
          final data = jsonDecode(item.dynamicData) as Map<String, dynamic>;
          cardCollector ??= data['collector_number']?.toString();
          cardSet ??= data['set']?.toString();
          cardTypeLine = data['type_line']?.toString();
        } catch (_) {}
      }
      cardCollector ??= detectedCollector;
      cardSet ??= item.setOrSeries;
      return OcrHeuristicMatcher.passesMultiFactorGate(
        cardName: item.name,
        ocrLines: cleanedOcrLines,
        collectorNumber: cardCollector,
        setCode: cardSet,
        typeLine: cardTypeLine,
      );
    }

    // -------------------------------------------------------------------------
    // STEP 1: Collector Number Regex Override
    // -------------------------------------------------------------------------
    String? effectiveCollector = collectorNumber?.trim();
    if (effectiveCollector == null || effectiveCollector.isEmpty) {
      final fractionPattern = RegExp(r'\b(\d{1,4})\s*[/]\s*(\d{1,4})\b');
      final setDashPattern =
          RegExp(r'\b([A-Za-z0-9]{2,5})\s*[-–—]\s*(\d{1,4})\b');
      final hashPattern =
          RegExp(r'\b(?:NO\.?|#)\s*(\d{1,4})\b', caseSensitive: false);

      for (final line in cleanedOcrLines) {
        final fMatch = fractionPattern.firstMatch(line);
        if (fMatch != null) {
          final num = fMatch.group(1)!;
          final denom = fMatch.group(2)!;
          // Guard against creature P/T stat boxes like 2/2 or 5/5
          if (num != denom || (int.tryParse(num) ?? 0) > 20) {
            effectiveCollector = num;
            break;
          }
        }
        final sMatch = setDashPattern.firstMatch(line);
        if (sMatch != null) {
          effectiveCollector = sMatch.group(2);
          break;
        }
        final hMatch = hashPattern.firstMatch(line);
        if (hMatch != null) {
          effectiveCollector = hMatch.group(1);
          break;
        }
      }
    }

    if (effectiveCollector != null && effectiveCollector.isNotEmpty) {
      final cleanNum = effectiveCollector.trim();
      final stripped = cleanNum.replaceFirst(RegExp(r'^0+'), '');
      final numCandidates = <String>{
        cleanNum,
        if (stripped.isNotEmpty) stripped,
        cleanNum.padLeft(3, '0'),
        cleanNum.padLeft(4, '0'),
        if (stripped.isNotEmpty) stripped.padLeft(3, '0'),
        if (stripped.isNotEmpty) stripped.padLeft(4, '0'),
      };

      Expression<bool> buildCollectorPred(VaultItems t) {
        Expression<bool>? p;
        for (final num in numCandidates) {
          final pred1 = t.dynamicData.like('%"collector_number":"$num"%') |
              t.dynamicData.like('%"collector_number": "$num"%');
          p = p == null ? pred1 : (p | pred1);
        }
        return p!;
      }

      final collectorCandidates = await (select(vaultItems)
            ..where((t) {
              final pred = buildCollectorPred(t);
              if (normalized != 'all') {
                return pred & t.collectionType.equals(normalized);
              }
              return pred;
            })
            ..limit(25))
          .get();

      for (final candidate in collectorCandidates) {
        if (validateMultiFactor(candidate, detectedCollector: cleanNum)) {
          debugPrint(
              '[VaultDao.matchScannedCard] Matched via collector number ($cleanNum): "${candidate.name}"');
          return candidate;
        } else {
          debugPrint(
              '[VaultDao.matchScannedCard] Multi-factor gate rejected collector match: "${candidate.name}"');
        }
      }

      if (normalized != 'all') {
        final crossCandidates = await (select(vaultItems)
              ..where(buildCollectorPred)
              ..limit(25))
            .get();

        for (final candidate in crossCandidates) {
          if (validateMultiFactor(candidate, detectedCollector: cleanNum)) {
            debugPrint(
                '[VaultDao.matchScannedCard] Matched via cross-collection collector number ($cleanNum): "${candidate.name}"');
            return candidate;
          } else {
            debugPrint(
                '[VaultDao.matchScannedCard] Multi-factor gate rejected cross-collection collector match: "${candidate.name}"');
          }
        }
      }
    }

    // -------------------------------------------------------------------------
    // STEP 2: Filter OCR Lines & SQL Wide Net
    // -------------------------------------------------------------------------
    // Filter lines length >= 3 (longest lines tested first via sort below)
    var eligibleLines = cleanedOcrLines
        .map((l) => l.trim())
        .where((l) => l.length >= 3)
        .toList();

    if (eligibleLines.isEmpty) return null;

    // Filter out lines that lack at least 3 alphanumeric characters
    eligibleLines = eligibleLines.where((l) {
      final stripped = l.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
      return stripped.length >= 3;
    }).toList();

    if (eligibleLines.isEmpty) return null;

    // Sort descending by length to test the longest, most descriptive lines first
    eligibleLines.sort((a, b) => b.length.compareTo(a.length));

    // Internal helper for Step 2 (SQL Wide Net) and Step 3 (Dart verification)
    Future<VaultItem?> verifyCandidatesForLine(
      String line, {
      required bool catalogOnly,
      required String collection,
      bool Function(VaultItem candidate)? filter,
    }) async {
      final cleanLine = line.replaceFirst(RegExp(r'^[^a-zA-Z0-9]+'), '').trim();
      if (cleanLine.length < 3) return null;

      final firstFive = cleanLine.length >= 5 ? cleanLine.substring(0, 5) : cleanLine;
      final alphaLine = cleanLine.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
      final alphaFive = alphaLine.length >= 5 ? alphaLine.substring(0, 5) : alphaLine;
      final firstWord = cleanLine.split(RegExp(r'\s+')).first;

      final sql = '''
        SELECT * FROM "vault_items"
        WHERE ${collection != 'all' ? '"collection_type" = ? AND ' : ''}
              ${catalogOnly ? '"quantity" = 0 AND ' : ''}
              (
                "name" LIKE ?
                OR "name" LIKE ?
                OR replace(replace(replace("name", char(34), ''), char(39), ''), '’', '') LIKE ?
                ${firstWord.length >= 3 && firstWord.length < 5 ? 'OR "name" LIKE ?' : ''}
              )
        LIMIT 25;
      ''';

      final candidates = await customSelect(
        sql,
        variables: [
          if (collection != 'all') Variable.withString(collection),
          Variable.withString('$firstFive%'),
          Variable.withString('"$firstFive%'),
          Variable.withString('$alphaFive%'),
          if (firstWord.length >= 3 && firstWord.length < 5) Variable.withString('$firstWord%'),
        ],
        readsFrom: {vaultItems},
      ).map((row) => vaultItems.map(row.data)).get();

      if (candidates.isEmpty) return null;

      final sanitizedOcrLine = sanitize(line);

      // STEP 3: Dart contains verification
      // Pass A: Exact match pass (prioritizes identical titles)
      final exactMatches = <VaultItem>[];
      for (final card in candidates) {
        final sanitizedDb = sanitize(card.name);
        final sanitizedBase = sanitize(_extractBaseCardName(card.name));
        if (sanitizedOcrLine == sanitizedDb || sanitizedOcrLine == sanitizedBase) {
          if (filter == null || filter(card)) {
            exactMatches.add(card);
          } else {
            debugPrint(
                '[VaultDao.matchScannedCard] Multi-factor gate rejected candidate: "${card.name}" (${card.setOrSeries})');
          }
        }
      }

      if (exactMatches.isNotEmpty) {
        if (exactMatches.length == 1) return exactMatches.first;
        // Prioritize candidate matching set code or collector number in OCR lines
        for (final card in exactMatches) {
          String? cardSet;
          String? cardCollector;
          if (card.dynamicData.isNotEmpty) {
            try {
              final data = jsonDecode(card.dynamicData) as Map<String, dynamic>;
              cardSet = data['set']?.toString();
              cardCollector = data['collector_number']?.toString();
            } catch (_) {}
          }
          cardSet ??= card.setOrSeries;
          if (cardSet.isNotEmpty) {
            final upperSet = cardSet.toUpperCase();
            if (cleanedOcrLines.any((l) =>
                l.trim().toUpperCase() == upperSet ||
                RegExp(r'\b' + RegExp.escape(upperSet) + r'\b', caseSensitive: false).hasMatch(l))) {
              return card;
            }
          }
          if (cardCollector != null && cardCollector.isNotEmpty) {
            final stripped = cardCollector.replaceFirst(RegExp(r'^0+'), '');
            if (cleanedOcrLines.any((l) =>
                l.trim() == cardCollector ||
                (stripped.isNotEmpty && l.trim() == stripped))) {
              return card;
            }
          }
        }
        return exactMatches.first;
      }

      // Pass B: Substring containment pass (prioritizes longer candidate names)
      final sortedCandidates = List<VaultItem>.from(candidates)
        ..sort((a, b) {
          final lenA = sanitize(_extractBaseCardName(a.name)).length;
          final lenB = sanitize(_extractBaseCardName(b.name)).length;
          return lenB.compareTo(lenA);
        });

      final substringMatches = <VaultItem>[];
      for (final card in sortedCandidates) {
        final sanitizedDb = sanitize(card.name);
        final sanitizedBase = sanitize(_extractBaseCardName(card.name));
        if (sanitizedBase.length >= 3 &&
            (sanitizedOcrLine.contains(sanitizedDb) ||
             sanitizedOcrLine.contains(sanitizedBase))) {
          if (filter == null || filter(card)) {
            substringMatches.add(card);
          } else {
            debugPrint(
                '[VaultDao.matchScannedCard] Multi-factor gate rejected candidate: "${card.name}" (${card.setOrSeries})');
          }
        }
      }

      if (substringMatches.isNotEmpty) {
        if (substringMatches.length == 1) return substringMatches.first;
        for (final card in substringMatches) {
          String? cardSet;
          String? cardCollector;
          if (card.dynamicData.isNotEmpty) {
            try {
              final data = jsonDecode(card.dynamicData) as Map<String, dynamic>;
              cardSet = data['set']?.toString();
              cardCollector = data['collector_number']?.toString();
            } catch (_) {}
          }
          cardSet ??= card.setOrSeries;
          if (cardSet.isNotEmpty) {
            final upperSet = cardSet.toUpperCase();
            if (cleanedOcrLines.any((l) =>
                l.trim().toUpperCase() == upperSet ||
                RegExp(r'\b' + RegExp.escape(upperSet) + r'\b', caseSensitive: false).hasMatch(l))) {
              return card;
            }
          }
          if (cardCollector != null && cardCollector.isNotEmpty) {
            final stripped = cardCollector.replaceFirst(RegExp(r'^0+'), '');
            if (cleanedOcrLines.any((l) =>
                l.trim() == cardCollector ||
                (stripped.isNotEmpty && l.trim() == stripped))) {
              return card;
            }
          }
        }
        return substringMatches.first;
      }

      return null;
    }

    // -------------------------------------------------------------------------
    // Tiered Verification Passes
    // -------------------------------------------------------------------------

    // Pass 1: Catalog reference items (quantity == 0) in active collection context
    for (final line in eligibleLines) {
      final match = await verifyCandidatesForLine(
        line,
        catalogOnly: true,
        collection: normalized,
        filter: validateMultiFactor,
      );
      if (match != null) {
        debugPrint('[VaultDao.matchScannedCard] Matched catalog item: "${match.name}" from line: "$line" (context: $normalized)');
        return match;
      }
    }

    // Pass 2: Owned inventory items (quantity >= 0) in active collection context
    for (final line in eligibleLines) {
      final match = await verifyCandidatesForLine(
        line,
        catalogOnly: false,
        collection: normalized,
        filter: validateMultiFactor,
      );
      if (match != null) {
        debugPrint('[VaultDao.matchScannedCard] Matched inventory item: "${match.name}" from line: "$line" (context: $normalized)');
        return match;
      }
    }

    // Pass 3: Cross-collection search fallback
    if (normalized != 'all') {
      for (final line in eligibleLines) {
        final match = await verifyCandidatesForLine(
          line,
          catalogOnly: true,
          collection: 'all',
          filter: validateMultiFactor,
        );
        if (match != null) {
          debugPrint('[VaultDao.matchScannedCard] Matched cross-collection catalog item: "${match.name}" from line: "$line" (collection: "${match.collectionType}")');
          return match;
        }
      }
      for (final line in eligibleLines) {
        final match = await verifyCandidatesForLine(
          line,
          catalogOnly: false,
          collection: 'all',
          filter: validateMultiFactor,
        );
        if (match != null) {
          debugPrint('[VaultDao.matchScannedCard] Matched cross-collection inventory item: "${match.name}" from line: "$line" (collection: "${match.collectionType}")');
          return match;
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
          primaryBinderId: const Value('INBOX'),
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
          primaryBinderId: const Value('INBOX'),
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
