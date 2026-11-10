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
import 'package:countr/features/decks/data/services/fallback_explore_seeds.dart';
import 'package:countr/features/decks/data/services/precon_hydration_service.dart';

/// Service responsible for offline parsing and ingestion of MTGJSON precons
/// and mock community decks into local SQLite via Drift.
class ExploreSeederService {
  static Future<void>? _activeSeedFuture;

  /// Visible for testing and coordination: returns the active seed Future if running.
  static Future<void>? get activeSeedFuture => _activeSeedFuture;

  static const _exploreZoneKey = #_exploreSeedInProgress;

  /// Checks whether both official WotC precons and curated community decks
  /// have been seeded into `explore_decks` (ignoring `user_shared` decks so
  /// sharing a personal deck never prevents initial catalog seeding).
  static Future<bool> isExploreCatalogSeeded(
    AppDatabase db, {
    int minOfficialDecks = 12,
    int minCommunityDecks = 7,
  }) async {
    final officialRow = await (db.selectOnly(db.exploreDecks)
          ..addColumns([db.exploreDecks.id.count()])
          ..where(
            db.exploreDecks.sourceType.equals('official') &
                db.exploreDecks.isDeleted.equals(false),
          ))
        .getSingle();
    final officialCount = officialRow.read(db.exploreDecks.id.count()) ?? 0;
    if (officialCount < minOfficialDecks) return false;

    final communityRow = await (db.selectOnly(db.exploreDecks)
          ..addColumns([db.exploreDecks.id.count()])
          ..where(
            db.exploreDecks.sourceType.equals('community') &
                db.exploreDecks.isDeleted.equals(false),
          ))
        .getSingle();
    final communityCount = communityRow.read(db.exploreDecks.id.count()) ?? 0;
    return communityCount >= minCommunityDecks;
  }

  /// Idempotently seeds bundled MTG precons and community decks off the UI thread.
  static Future<void> seedIfNeeded(
    AppDatabase db, {
    bool force = false,
    int minOfficialDecks = 12,
  }) async {
    if (Zone.current[_exploreZoneKey] == true) {
      debugPrint('[ExploreSeederService] Re-entrant call detected; skipping to prevent self-await deadlock.');
      return;
    }

    if (Zone.current[AppDatabase.beforeOpenZoneKey] == true) {
      debugPrint('[ExploreSeederService] Call from within beforeOpen detected; deferring to microtask to prevent deadlock.');
      Zone.root.scheduleMicrotask(() => seedIfNeeded(db, force: force, minOfficialDecks: minOfficialDecks));
      return;
    }

    if (_activeSeedFuture != null) {
      try {
        await _activeSeedFuture;
      } catch (_) {}
      if (!force && await isExploreCatalogSeeded(db, minOfficialDecks: minOfficialDecks)) {
        return;
      }
    }

    final future = runZoned(
      () => _executeSeed(db, force: force, minOfficialDecks: minOfficialDecks),
      zoneValues: {_exploreZoneKey: true},
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

  static Future<void> _executeSeed(
    AppDatabase db, {
    required bool force,
    int minOfficialDecks = 12,
  }) async {
    // 1. Startup repair pass
    await PreconHydrationService.repairArtSeriesCards(db);

    if (!force) {
      final alreadySeeded = await isExploreCatalogSeeded(
        db,
        minOfficialDecks: minOfficialDecks,
      );
      if (alreadySeeded) {
        debugPrint(
          '[ExploreSeederService] Explore catalog already populated with official & community decks. Skipping seed.',
        );
        return;
      }
    }

    if (minOfficialDecks >= 500) {
      await hydrateFullCatalogIfNeeded(db, force: force);
      return;
    }

    // 1. Offload JSON decoding and normalization to background isolate
    List<Map<String, dynamic>> rawDecks = [];
    try {
      String? preconStr;
      String? commStr;

      try {
        final pFile = File('assets/decks/precons.json');
        final cFile = File('assets/decks/community.json');
        if (pFile.existsSync() && cFile.existsSync()) {
          preconStr = pFile.readAsStringSync();
          commStr = cFile.readAsStringSync();
        }
      } catch (_) {}

      if (preconStr == null || commStr == null) {
        preconStr ??= await rootBundle.loadString('assets/decks/precons.json');
        commStr ??= await rootBundle.loadString('assets/decks/community.json');
      }

      rawDecks = await parseRawDecksInIsolate(preconStr, commStr);
    } catch (e) {
      debugPrint(
        '[ExploreSeederService] Asset load failed ($e). Using compiled FallbackExploreSeeds.',
      );
      rawDecks = FallbackExploreSeeds.allSeeds;
    }

    debugPrint('[ExploreSeederService] Calling seedFromRawDecks...');
    await seedFromRawDecks(db, rawDecks);

    debugPrint(
      '[ExploreSeederService] Ingestion complete: ${rawDecks.length} decks seeded.',
    );
  }

  /// Parses precon and community JSON strings on a background isolate.
  static Future<List<Map<String, dynamic>>> parseRawDecksInIsolate(
    String preconJson,
    String communityJson,
  ) {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      final pList = (jsonDecode(preconJson) as List).cast<Map<String, dynamic>>();
      final cList = (jsonDecode(communityJson) as List).cast<Map<String, dynamic>>();
      return Future.value([...pList, ...cList]);
    }
    return Isolate.run(() {
      final pList = (jsonDecode(preconJson) as List).cast<Map<String, dynamic>>();
      final cList = (jsonDecode(communityJson) as List).cast<Map<String, dynamic>>();
      return [...pList, ...cList];
    });
  }

  /// Decompresses and hydrates the 500+ official MTGJSON preconstructed decks
  /// bundle (`assets/data/official_precons.json.gz`) into SQLite if official deck count < 500.
  static Future<void> hydrateFullCatalogIfNeeded(
    AppDatabase db, {
    bool force = false,
    String? bundlePath,
  }) async {
    if (!force) {
      final isHydrated = await isExploreCatalogSeeded(db, minOfficialDecks: 500);
      if (isHydrated) return;
    }

    final path = bundlePath ?? 'assets/data/official_precons.json.gz';
    Uint8List? bytes;
    try {
      final f = File(path);
      if (f.existsSync()) bytes = f.readAsBytesSync();
    } catch (_) {}

    if (bytes == null) {
      try {
        final bd = await rootBundle.load(path);
        bytes = bd.buffer.asUint8List();
      } catch (_) {}
    }

    if (bytes != null && bytes.isNotEmpty) {
      final rawDecks = await parseGzDecksInIsolate(bytes);
      await seedFromRawDecks(db, rawDecks);
    }
  }

  /// Parses gzipped raw decks JSON bytes in a background isolate.
  static Future<List<Map<String, dynamic>>> parseGzDecksInIsolate(Uint8List bytes) {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      final isGzip = bytes.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b;
      final payload = isGzip ? gzip.decode(bytes) : bytes;
      final jsonStr = utf8.decode(payload);
      return Future.value((jsonDecode(jsonStr) as List).cast<Map<String, dynamic>>());
    }
    return Isolate.run(() {
      final isGzip = bytes.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b;
      final payload = isGzip ? gzip.decode(bytes) : bytes;
      final jsonStr = utf8.decode(payload);
      return (jsonDecode(jsonStr) as List).cast<Map<String, dynamic>>();
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

      // Sanitize commander using strict art series / memorabilia predicate
      String? cmdrName = commander?['name'] as String?;
      String? cmdrImg = commander?['image_url'] as String?;
      String? cmdrCrop = commander?['art_crop_url'] as String?;
      if (cmdrName != null && cmdrName.isNotEmpty) {
        final isCmdrArtSeries = (cmdrImg != null && cmdrImg.contains('art_series')) ||
            (cmdrCrop != null && cmdrCrop.contains('art_series')) ||
            cmdrName.toLowerCase().contains('art card') ||
            cmdrName.toLowerCase().contains('art series') ||
            (cmdrName.contains('//') &&
                cmdrName.split('//')[0].trim().toLowerCase() ==
                    cmdrName.split('//')[1].trim().toLowerCase());
        if (isCmdrArtSeries || (cmdrImg != null && cmdrImg.contains('/art_crop/'))) {
          final clean = cmdrName.contains('//')
              ? cmdrName.split('//').first.trim()
              : cmdrName.trim();
          cmdrName = clean
              .replaceAll(RegExp(r'\s*\((?:Art Card|Art Series)\)', caseSensitive: false), '')
              .replaceAll(RegExp(r'\s*-\s*(?:Art Card|Art Series)', caseSensitive: false), '')
              .trim();
          cmdrImg = CountrCachedImage.buildScryfallNamedUrl(cmdrName, version: 'normal');
          cmdrCrop = CountrCachedImage.buildScryfallNamedUrl(cmdrName, version: 'art_crop');
        }
      }

      deckCompanions.add(ExploreDecksCompanion.insert(
        id: deckId,
        name: d['name'] as String,
        format: d['format'] as String,
        tcgDomain: Value(d['tcg_domain'] as String? ?? 'mtg'),
        sourceType: Value(d['source_type'] as String? ?? 'official'),
        creatorName: Value(d['creator_name'] as String? ?? 'Wizards of the Coast'),
        authorId: Value(d['author_id'] as String? ?? d['authorId'] as String?),
        description: Value(d['description'] as String?),
        commanderName: Value(cmdrName),
        commanderImageUrl: Value(cmdrImg),
        commanderArtCrop: Value(cmdrCrop),
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

        final isCommander = (commander['is_commander'] as bool?) ??
            (commander['board_zone'] == 'Commander' || commander['board_zone'] == null);

        itemCompanions.add(ExploreDeckItemsCompanion.insert(
          id: '${deckId}_commander',
          exploreDeckId: deckId,
          cardName: cmdrName ?? (commander['name'] as String),
          scryfallId: Value(commander['scryfall_id'] as String?),
          oracleId: Value(commander['oracle_id'] as String?),
          quantity: Value((commander['count'] as num?)?.toInt() ?? 1),
          boardZone: Value(commander['board_zone'] as String? ?? 'Commander'),
          manaCost: Value(commander['mana_cost'] as String?),
          cmc: Value((commander['cmc'] as num?)?.toDouble()),
          typeLine: Value(commander['type_line'] as String?),
          colors: Value(colorsStr),
          imageUrl: Value(cmdrImg ?? (commander['image_url'] as String?)),
          artCropUrl: Value(cmdrCrop ?? (commander['art_crop_url'] as String?)),
          price: Value((commander['price'] as num?)?.toDouble()),
          isCommander: Value(isCommander),
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

    // Execute chunked insertions in transaction (chunkSize <= 250)
    await db.transaction(() async {
      for (var i = 0; i < deckCompanions.length; i += 250) {
        final chunk = deckCompanions.sublist(
          i,
          math.min(i + 250, deckCompanions.length),
        );
        await db.batch((b) => b.insertAll(db.exploreDecks, chunk, mode: InsertMode.insertOrReplace));
      }
      for (var i = 0; i < itemCompanions.length; i += 250) {
        final chunk = itemCompanions.sublist(
          i,
          math.min(i + 250, itemCompanions.length),
        );
        await db.batch((b) => b.insertAll(db.exploreDeckItems, chunk, mode: InsertMode.insertOrReplace));
      }
    });
  }
}

