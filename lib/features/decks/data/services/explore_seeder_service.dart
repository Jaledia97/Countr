import 'dart:convert';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:drift/drift.dart';

import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/data/services/fallback_explore_seeds.dart';

/// Service responsible for offline parsing and ingestion of MTGJSON precons
/// and mock community decks into local SQLite via Drift.
class ExploreSeederService {
  static bool _isSeeding = false;

  /// Idempotently seeds bundled MTG precons and community decks off the UI thread.
  static Future<void> seedIfNeeded(AppDatabase db, {bool force = false}) async {
    if (_isSeeding) return;
    _isSeeding = true;

    try {
      final existingCount = await db.exploreDeckDao.getExploreDeckCount();
      if (existingCount > 0 && !force) {
        debugPrint(
            '[ExploreSeederService] Explore catalog already populated ($existingCount decks). Skipping seed.');
        return;
      }

      debugPrint('[ExploreSeederService] Starting background explore deck ingestion...');

      // 1. Offload JSON decoding and normalization to background isolate
      List<Map<String, dynamic>> rawDecks = [];
      try {
        final preconStr = await rootBundle.loadString('assets/decks/precons.json');
        final commStr = await rootBundle.loadString('assets/decks/community.json');

        rawDecks = await parseRawDecksInIsolate(preconStr, commStr);
      } catch (e) {
        debugPrint(
            '[ExploreSeederService] Asset load failed ($e). Using compiled FallbackExploreSeeds.');
        rawDecks = FallbackExploreSeeds.allSeeds;
      }

      await seedFromRawDecks(db, rawDecks);

      debugPrint(
        '[ExploreSeederService] Ingestion complete: ${rawDecks.length} decks seeded.',
      );
    } finally {
      _isSeeding = false;
    }
  }

  /// Parses precon and community JSON strings on a background isolate.
  static Future<List<Map<String, dynamic>>> parseRawDecksInIsolate(
    String preconJson,
    String communityJson,
  ) {
    return Isolate.run(() {
      final pList = (jsonDecode(preconJson) as List).cast<Map<String, dynamic>>();
      final cList = (jsonDecode(communityJson) as List).cast<Map<String, dynamic>>();
      return [...pList, ...cList];
    });
  }

  /// Ingests a list of raw deck Maps into SQLite in chunked transactions.
  static Future<void> seedFromRawDecks(
    AppDatabase db,
    List<Map<String, dynamic>> rawDecks,
  ) async {
    final deckCompanions = <ExploreDecksCompanion>[];
    final itemCompanions = <ExploreDeckItemsCompanion>[];
    final now = DateTime.now();

    for (final d in rawDecks) {
      final deckId = d['id'] as String;
      final commander = d['commander'] as Map<String, dynamic>?;
      final cards = (d['cards'] as List? ?? []).cast<Map<String, dynamic>>();
      final colorList = (d['color_identity'] as List? ?? []).cast<String>();

      double computedPrice = (commander?['price'] as num?)?.toDouble() ?? 0.0;
      int computedCardCount = (commander != null ? (commander['count'] as num?)?.toInt() ?? 1 : 0);

      for (final c in cards) {
        final p = (c['price'] as num?)?.toDouble() ?? 0.0;
        final qty = (c['count'] as num?)?.toInt() ?? 1;
        computedPrice += (p * qty);
        computedCardCount += qty;
      }

      final estimatedPrice = (d['estimated_price'] as num?)?.toDouble() ?? computedPrice;
      final cardCount = (d['card_count'] as num?)?.toInt() ?? computedCardCount;

      final initialUpvotes = (d['upvotes'] as num?)?.toInt() ?? 15;
      final initialDownvotes = (d['downvotes'] as num?)?.toInt() ?? 1;
      final initialScore = (d['score'] as num?)?.toInt() ?? (initialUpvotes - initialDownvotes);

      final tagsRaw = d['tags'];
      final String? tagsStr;
      if (tagsRaw is List) {
        tagsStr = tagsRaw.join(',');
      } else if (tagsRaw is String) {
        tagsStr = tagsRaw;
      } else {
        tagsStr = null;
      }

      deckCompanions.add(ExploreDecksCompanion.insert(
        id: deckId,
        name: d['name'] as String,
        format: d['format'] as String,
        tcgDomain: Value(d['tcg_domain'] as String? ?? 'mtg'),
        sourceType: Value(d['source_type'] as String? ?? 'official'),
        creatorName: Value(d['creator_name'] as String? ?? 'Wizards of the Coast'),
        description: Value(d['description'] as String?),
        commanderName: Value(commander?['name'] as String?),
        commanderImageUrl: Value(commander?['image_url'] as String?),
        commanderArtCrop: Value(commander?['art_crop_url'] as String?),
        colorIdentity: Value(jsonEncode(colorList)),
        cardCount: Value(cardCount),
        estimatedPrice: Value(estimatedPrice),
        upvotes: Value(initialUpvotes),
        downvotes: Value(initialDownvotes),
        score: Value(initialScore),
        featuredCategory: Value(d['featured_category'] as String?),
        releaseCode: Value(d['release_code'] as String?),
        releaseYear: Value(d['release_year'] as int?),
        tags: Value(tagsStr),
        createdAt: now,
        updatedAt: Value(now),
        isDeleted: const Value(false),
      ));

      // Commander Card Item
      if (commander != null) {
        final colorsVal = commander['colors'];
        final colorsStr = colorsVal != null
            ? (colorsVal is List ? jsonEncode(colorsVal) : colorsVal.toString())
            : null;

        itemCompanions.add(ExploreDeckItemsCompanion.insert(
          id: '${deckId}_commander',
          exploreDeckId: deckId,
          cardName: commander['name'] as String,
          scryfallId: Value(commander['scryfall_id'] as String?),
          oracleId: Value(commander['oracle_id'] as String?),
          quantity: Value((commander['count'] as num?)?.toInt() ?? 1),
          boardZone: Value(commander['board_zone'] as String? ?? 'Commander'),
          manaCost: Value(commander['mana_cost'] as String?),
          cmc: Value((commander['cmc'] as num?)?.toDouble()),
          typeLine: Value(commander['type_line'] as String?),
          colors: Value(colorsStr),
          imageUrl: Value(commander['image_url'] as String?),
          artCropUrl: Value(commander['art_crop_url'] as String?),
          price: Value((commander['price'] as num?)?.toDouble()),
          isCommander: const Value(true),
          isDeleted: const Value(false),
        ));
      }

      // Mainboard & Sideboard Card Items
      int cardIdx = 0;
      for (final c in cards) {
        cardIdx++;
        final colorsVal = c['colors'];
        final colorsStr = colorsVal != null
            ? (colorsVal is List ? jsonEncode(colorsVal) : colorsVal.toString())
            : null;

        itemCompanions.add(ExploreDeckItemsCompanion.insert(
          id: '${deckId}_card_$cardIdx',
          exploreDeckId: deckId,
          cardName: c['name'] as String,
          scryfallId: Value(c['scryfall_id'] as String?),
          oracleId: Value(c['oracle_id'] as String?),
          quantity: Value((c['count'] as num?)?.toInt() ?? 1),
          boardZone: Value(c['board_zone'] as String? ?? 'Mainboard'),
          manaCost: Value(c['mana_cost'] as String?),
          cmc: Value((c['cmc'] as num?)?.toDouble()),
          typeLine: Value(c['type_line'] as String?),
          colors: Value(colorsStr),
          imageUrl: Value(c['image_url'] as String?),
          artCropUrl: Value(c['art_crop_url'] as String?),
          price: Value((c['price'] as num?)?.toDouble()),
          isCommander: Value(c['is_commander'] as bool? ?? false),
          isDeleted: const Value(false),
        ));
      }
    }

    await db.transaction(() async {
      await db.exploreDeckDao.batchInsertExploreDecks(deckCompanions);
      await db.exploreDeckDao.batchInsertExploreDeckItems(itemCompanions, chunkSize: 250);
    });
  }
}
