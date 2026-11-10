import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart' hide isNull, isNotNull, Column;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/data/daos/explore_deck_dao.dart';
import 'package:countr/features/decks/domain/models/explore_deck_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('Milestone 3 Empirical Challenge: Feed Balancing Ratios & Pagination Sweeps', () {
    late AppDatabase db;
    late ExploreDeckDao dao;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      dao = ExploreDeckDao(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('Adversarial Ratio: 500 Official : 1 Community deck produces balanced head and full official tail without dropping or duplicating decks', () async {
      final now = DateTime.now();

      // Batch insert 500 official decks
      final officialCompanions = <ExploreDecksCompanion>[];
      for (int i = 1; i <= 500; i++) {
        officialCompanions.add(
          ExploreDecksCompanion.insert(
            id: 'official_$i',
            name: 'Official Deck $i',
            format: 'Commander',
            sourceType: const Value('official'),
            creatorName: const Value('Wizards of the Coast'),
            score: Value(1000 - i),
            upvotes: Value(1000 - i),
            createdAt: now.subtract(Duration(minutes: i)),
            updatedAt: Value(now),
          ),
        );
      }
      await db.batch((b) => b.insertAll(db.exploreDecks, officialCompanions));

      // Insert 1 community deck with high score
      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: 'community_single',
          name: 'The Lone Community Deck',
          format: 'Commander',
          sourceType: const Value('community'),
          creatorName: const Value('@LoneWolf'),
          score: const Value(999),
          upvotes: const Value(999),
          createdAt: now,
          updatedAt: Value(now),
        ),
      );

      // Query full feed with balancing enabled
      final feed = await dao.watchExploreDecks(
        category: ExploreCategory.all,
        balanceFeed: true,
        limit: 1000,
      ).first;

      expect(feed.length, equals(501), reason: 'All 501 decks must be returned without loss');

      // The 2:1 pattern requires: Official 1, Official 2, Community 1, then all remaining Officials
      expect(feed[0].deck.id, equals('official_1'));
      expect(feed[1].deck.id, equals('official_2'));
      expect(feed[2].deck.id, equals('community_single'));

      // From index 3 onward, all remaining 498 decks must be official decks in monotonic descending score order
      final communityOccurrences = feed.where((item) => item.deck.id == 'community_single').toList();
      expect(communityOccurrences.length, equals(1), reason: 'Single community deck must appear exactly once');

      for (int i = 3; i < 501; i++) {
        expect(feed[i].deck.sourceType, equals('official'),
            reason: 'Item at index $i must be official once community decks are exhausted');
        if (i > 3) {
          expect(feed[i - 1].deck.score, greaterThanOrEqualTo(feed[i].deck.score),
              reason: 'Official decks must strictly maintain monotonic score order');
        }
      }

      expect(feed[3].deck.id, equals('official_3'));
      expect(feed[500].deck.id, equals('official_500'));
    });

    test('Adversarial Ratio: 0 Official : 50 Community decks handles empty partition gracefully', () async {
      final now = DateTime.now();

      final communityCompanions = <ExploreDecksCompanion>[];
      for (int i = 1; i <= 50; i++) {
        communityCompanions.add(
          ExploreDecksCompanion.insert(
            id: 'comm_$i',
            name: 'Community Deck $i',
            format: 'Commander',
            sourceType: const Value('community'),
            creatorName: Value('@User_$i'),
            score: Value(200 - i),
            upvotes: Value(200 - i),
            createdAt: now.subtract(Duration(minutes: i)),
            updatedAt: Value(now),
          ),
        );
      }
      await db.batch((b) => b.insertAll(db.exploreDecks, communityCompanions));

      final feed = await dao.watchExploreDecks(
        category: ExploreCategory.all,
        balanceFeed: true,
        limit: 100,
      ).first;

      expect(feed.length, equals(50));
      for (int i = 0; i < 50; i++) {
        expect(feed[i].deck.id, equals('comm_${i + 1}'));
        expect(feed[i].deck.sourceType, equals('community'));
      }
    });

    test('Large Limit / Offset Pagination Sweeps across balanced 2:1 boundaries yield lossless contiguous partitions', () async {
      final now = DateTime.now();

      // Seed 60 official decks and 30 community decks -> total 90 decks
      final officialCompanions = <ExploreDecksCompanion>[];
      for (int i = 1; i <= 60; i++) {
        officialCompanions.add(
          ExploreDecksCompanion.insert(
            id: 'off_${i.toString().padLeft(2, '0')}',
            name: 'Official Precon $i',
            format: 'Commander',
            sourceType: const Value('official'),
            creatorName: const Value('Wizards of the Coast'),
            score: Value(500 - i),
            upvotes: Value(500 - i),
            createdAt: now.subtract(Duration(minutes: i)),
            updatedAt: Value(now),
          ),
        );
      }
      await db.batch((b) => b.insertAll(db.exploreDecks, officialCompanions));

      final communityCompanions = <ExploreDecksCompanion>[];
      for (int i = 1; i <= 30; i++) {
        communityCompanions.add(
          ExploreDecksCompanion.insert(
            id: 'comm_${i.toString().padLeft(2, '0')}',
            name: 'Community Deck $i',
            format: 'Commander',
            sourceType: const Value('community'),
            creatorName: Value('@Brewer$i'),
            score: Value(500 - i),
            upvotes: Value(500 - i),
            createdAt: now.subtract(Duration(minutes: i)),
            updatedAt: Value(now),
          ),
        );
      }
      await db.batch((b) => b.insertAll(db.exploreDecks, communityCompanions));

      // Reference list: fetch all 90 items in one call
      final referenceList = await dao.watchExploreDecks(
        category: ExploreCategory.all,
        balanceFeed: true,
        limit: 150,
      ).first;

      expect(referenceList.length, equals(90));

      // Verify the 2:1 pattern in reference list
      for (int b = 0; b < 30; b++) {
        expect(referenceList[b * 3 + 0].deck.sourceType, equals('official'),
            reason: 'Item at index ${b * 3 + 0} must be official');
        expect(referenceList[b * 3 + 1].deck.sourceType, equals('official'),
            reason: 'Item at index ${b * 3 + 1} must be official');
        expect(referenceList[b * 3 + 2].deck.sourceType, equals('community'),
            reason: 'Item at index ${b * 3 + 2} must be community');
      }

      // Sweep 1: Window size 3 (aligned with 2:1 block)
      final sweptSize3 = <ExploreDeckWithVote>[];
      for (int offset = 0; offset < 90; offset += 3) {
        final page = await dao.watchExploreDecks(
          category: ExploreCategory.all,
          balanceFeed: true,
          limit: 3,
          offset: offset,
        ).first;
        expect(page.length, equals(3));
        sweptSize3.addAll(page);
      }
      expect(sweptSize3.length, equals(90));
      for (int i = 0; i < 90; i++) {
        expect(sweptSize3[i].deck.id, equals(referenceList[i].deck.id),
            reason: 'Mismatch at index $i for page size 3');
      }

      // Sweep 2: Window size 7 (prime, completely misaligned with 3)
      final sweptSize7 = <ExploreDeckWithVote>[];
      for (int offset = 0; offset < 90; offset += 7) {
        final expectedCount = (offset + 7 > 90) ? (90 - offset) : 7;
        final page = await dao.watchExploreDecks(
          category: ExploreCategory.all,
          balanceFeed: true,
          limit: 7,
          offset: offset,
        ).first;
        expect(page.length, equals(expectedCount));
        sweptSize7.addAll(page);
      }
      expect(sweptSize7.length, equals(90));
      for (int i = 0; i < 90; i++) {
        expect(sweptSize7[i].deck.id, equals(referenceList[i].deck.id),
            reason: 'Mismatch at index $i for page size 7');
      }

      // Sweep 3: Window size 13 (prime, crosses multiple 2:1 blocks)
      final sweptSize13 = <ExploreDeckWithVote>[];
      for (int offset = 0; offset < 90; offset += 13) {
        final expectedCount = (offset + 13 > 90) ? (90 - offset) : 13;
        final page = await dao.watchExploreDecks(
          category: ExploreCategory.all,
          balanceFeed: true,
          limit: 13,
          offset: offset,
        ).first;
        expect(page.length, equals(expectedCount));
        sweptSize13.addAll(page);
      }
      expect(sweptSize13.length, equals(90));
      for (int i = 0; i < 90; i++) {
        expect(sweptSize13[i].deck.id, equals(referenceList[i].deck.id),
            reason: 'Mismatch at index $i for page size 13');
      }

      // Boundary tests: offset beyond total rows
      final outOfBoundsPage = await dao.watchExploreDecks(
        category: ExploreCategory.all,
        balanceFeed: true,
        limit: 10,
        offset: 100,
      ).first;
      expect(outOfBoundsPage, isEmpty);

      // Boundary test: limit = 0
      final zeroLimitPage = await dao.watchExploreDecks(
        category: ExploreCategory.all,
        balanceFeed: true,
        limit: 0,
        offset: 0,
      ).first;
      expect(zeroLimitPage, isEmpty);
    });

    test('Category filter strictly isolates official and community feeds even with balanceFeed flag true', () async {
      final now = DateTime.now();

      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: 'off_1',
          name: 'Official Deck',
          format: 'Commander',
          sourceType: const Value('official'),
          createdAt: now,
          updatedAt: Value(now),
        ),
      );
      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: 'comm_1',
          name: 'Community Deck',
          format: 'Commander',
          sourceType: const Value('community'),
          createdAt: now,
          updatedAt: Value(now),
        ),
      );
      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: 'user_shared_1',
          name: 'User Shared Deck',
          format: 'Commander',
          sourceType: const Value('user_shared'),
          createdAt: now,
          updatedAt: Value(now),
        ),
      );

      final officialFeed = await dao.watchExploreDecks(
        category: ExploreCategory.official,
        balanceFeed: true,
      ).first;
      expect(officialFeed.length, equals(1));
      expect(officialFeed.first.deck.id, equals('off_1'));

      final communityFeed = await dao.watchExploreDecks(
        category: ExploreCategory.community,
        balanceFeed: true,
      ).first;
      expect(communityFeed.length, equals(2));
      expect(communityFeed.map((d) => d.deck.id).toSet(), equals({'comm_1', 'user_shared_1'}));
    });
  });

  group('Milestone 3 Empirical Challenge: Deck Sharing Complex Zones & Quantity Preservation', () {
    late AppDatabase db;
    late ExploreDeckDao dao;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      dao = ExploreDeckDao(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('sharePersonalDeckToExplore preserves all zones (Commander, Mainboard, Sideboard, Maybeboard) and exact quantities', () async {
      final now = DateTime.now();
      const personalDeckId = 'complex_personal_deck_42';
      const versionId = 'ver_complex_1';

      // 1. Create personal deck in decks table
      await db.into(db.decks).insert(
        DecksCompanion.insert(
          id: personalDeckId,
          name: 'Adversarial Quad-Zone Commander',
          format: 'Commander',
          description: const Value('A deck testing 4 distinct zones and various quantities'),
          createdAt: now,
          updatedAt: Value(now),
        ),
      );

      // 2. Create active version in deck_versions
      await db.into(db.deckVersions).insert(
        DeckVersionsCompanion.insert(
          id: versionId,
          deckId: personalDeckId,
          versionNumber: 1,
          isActive: const Value(true),
          createdAt: now,
          updatedAt: Value(now),
        ),
      );

      // 3. Insert vault items across zones
      final vaultCards = [
        {
          'id': 'v_cmdr_1',
          'name': 'Kraum, Ludevic\'s Opus',
          'zone': 'Commander',
          'qty': 1,
          'price': 15.0,
          'dyn': jsonEncode({
            'scryfall_id': 'kraum-111',
            'oracle_id': 'kraum-orc',
            'mana_cost': '{3}{U}{R}',
            'cmc': 5.0,
            'type_line': 'Legendary Creature — Zombie Horror',
            'colors': ['U', 'R'],
            'color_identity': ['U', 'R'],
            'image_uris': {'normal': 'https://example.com/kraum.jpg', 'art_crop': 'https://example.com/kraum_crop.jpg'},
          }),
        },
        {
          'id': 'v_cmdr_2',
          'name': 'Tymna the Weaver',
          'zone': 'Commander',
          'qty': 1,
          'price': 40.0,
          'dyn': jsonEncode({
            'scryfall_id': 'tymna-222',
            'oracle_id': 'tymna-orc',
            'mana_cost': '{1}{W}{B}',
            'cmc': 3.0,
            'type_line': 'Legendary Creature — Human Cleric',
            'colors': ['W', 'B'],
            'color_identity': ['W', 'B'],
            'image_uris': {'normal': 'https://example.com/tymna.jpg', 'art_crop': 'https://example.com/tymna_crop.jpg'},
          }),
        },
        {
          'id': 'v_main_1',
          'name': 'Lightning Bolt',
          'zone': 'Mainboard',
          'qty': 4,
          'price': 2.0,
          'dyn': jsonEncode({
            'scryfall_id': 'bolt-333',
            'mana_cost': '{R}',
            'cmc': 1.0,
            'type_line': 'Instant',
            'colors': ['R'],
          }),
        },
        {
          'id': 'v_main_2',
          'name': 'Sol Ring',
          'zone': 'Mainboard',
          'qty': 1,
          'price': 1.5,
          'dyn': jsonEncode({
            'scryfall_id': 'sol-444',
            'mana_cost': '{1}',
            'cmc': 1.0,
            'type_line': 'Artifact',
            'colors': [],
          }),
        },
        {
          'id': 'v_main_3',
          'name': 'Island',
          'zone': 'Mainboard',
          'qty': 30,
          'price': 0.1,
          'dyn': jsonEncode({
            'scryfall_id': 'island-555',
            'mana_cost': '',
            'cmc': 0.0,
            'type_line': 'Basic Land — Island',
            'colors': [],
          }),
        },
        {
          'id': 'v_side_1',
          'name': 'Pyroblast',
          'zone': 'Sideboard',
          'qty': 3,
          'price': 5.0,
          'dyn': jsonEncode({
            'scryfall_id': 'pyro-666',
            'mana_cost': '{R}',
            'cmc': 1.0,
            'type_line': 'Instant',
            'colors': ['R'],
          }),
        },
        {
          'id': 'v_side_2',
          'name': 'Red Elemental Blast',
          'zone': 'Sideboard',
          'qty': 2,
          'price': 4.5,
          'dyn': jsonEncode({
            'scryfall_id': 'reb-777',
            'mana_cost': '{R}',
            'cmc': 1.0,
            'type_line': 'Instant',
            'colors': ['R'],
          }),
        },
        {
          'id': 'v_maybe_1',
          'name': 'Blood Moon',
          'zone': 'Maybeboard',
          'qty': 1,
          'price': 12.0,
          'dyn': jsonEncode({
            'scryfall_id': 'moon-888',
            'mana_cost': '{2}{R}',
            'cmc': 3.0,
            'type_line': 'Enchantment',
            'colors': ['R'],
          }),
        },
        {
          'id': 'v_maybe_2',
          'name': 'Deflecting Swat',
          'zone': 'Maybeboard',
          'qty': 2,
          'price': 50.0,
          'dyn': jsonEncode({
            'scryfall_id': 'swat-999',
            'mana_cost': '{2}{R}',
            'cmc': 3.0,
            'type_line': 'Instant',
            'colors': ['R'],
          }),
        },
      ];

      for (final card in vaultCards) {
        final id = card['id'] as String;
        final name = card['name'] as String;
        final price = card['price'] as double;
        final dynStr = card['dyn'] as String;

        await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: id,
            name: name,
            collectionType: 'mtg',
            setOrSeries: 'MTG Sets',
            condition: 'NM',
            imageUrl: 'https://example.com/$id.jpg',
            currentMarketPrice: price,
            acquiredPrice: price,
            acquiredDate: now,
            lastPriceUpdate: now,
            dynamicData: dynStr,
          ),
        );

        await db.into(db.deckVersionItems).insert(
          DeckVersionItemsCompanion.insert(
            id: 'dvi_$id',
            versionId: versionId,
            vaultItemId: id,
            quantity: Value(card['qty'] as int),
            boardZone: card['zone'] as String,
          ),
        );
      }

      // Expected total cards: 1 + 1 + 4 + 1 + 30 + 3 + 2 + 1 + 2 = 45 cards
      const expectedTotalCards = 45;

      // Act: Share to explore
      final sharedDeck = await dao.sharePersonalDeckToExplore(
        personalDeckId: personalDeckId,
        creatorName: '@ZoneMaster',
      );

      // Verify ExploreDeck properties
      expect(sharedDeck.sourceType, equals('user_shared'));
      expect(sharedDeck.featuredCategory, equals('From Top Deck Builders'));
      expect(sharedDeck.cardCount, equals(expectedTotalCards));
      expect(sharedDeck.commanderName, isNotNull);

      // Verify ExploreDeckItems
      final items = await dao.getExploreDeckItems(sharedDeck.id);
      expect(items.length, equals(vaultCards.length), reason: 'All 9 card rows must be preserved in items');

      int totalItemsCount = 0;
      for (final item in items) {
        totalItemsCount += item.quantity;
      }
      expect(totalItemsCount, equals(expectedTotalCards));

      // Verify individual zones
      final commanderCards = items.where((i) => i.boardZone == 'Commander').toList();
      expect(commanderCards.length, equals(2));
      for (final c in commanderCards) {
        expect(c.isCommander, isTrue);
        expect(c.quantity, equals(1));
      }

      final mainboardCards = items.where((i) => i.boardZone == 'Mainboard').toList();
      expect(mainboardCards.length, equals(3));
      final bolt = mainboardCards.firstWhere((c) => c.cardName == 'Lightning Bolt');
      expect(bolt.quantity, equals(4));
      expect(bolt.isCommander, isFalse);

      final island = mainboardCards.firstWhere((c) => c.cardName == 'Island');
      expect(island.quantity, equals(30));

      final sideboardCards = items.where((i) => i.boardZone == 'Sideboard').toList();
      expect(sideboardCards.length, equals(2));
      final pyro = sideboardCards.firstWhere((c) => c.cardName == 'Pyroblast');
      expect(pyro.quantity, equals(3));
      final reb = sideboardCards.firstWhere((c) => c.cardName == 'Red Elemental Blast');
      expect(reb.quantity, equals(2));

      final maybeboardCards = items.where((i) => i.boardZone == 'Maybeboard').toList();
      expect(maybeboardCards.length, equals(2));
      final moon = maybeboardCards.firstWhere((c) => c.cardName == 'Blood Moon');
      expect(moon.quantity, equals(1));
      final swat = maybeboardCards.firstWhere((c) => c.cardName == 'Deflecting Swat');
      expect(swat.quantity, equals(2));

      // Idempotency: re-sharing deck updates items cleanly without orphan duplication
      final reshared = await dao.sharePersonalDeckToExplore(
        personalDeckId: personalDeckId,
        creatorName: '@ZoneMasterUpdated',
      );
      expect(reshared.id, equals(sharedDeck.id));

      final itemsAfterReshare = await dao.getExploreDeckItems(sharedDeck.id);
      expect(itemsAfterReshare.length, equals(9), reason: 'No duplicated rows after re-sharing');
    });
  });

  group('Milestone 3 Empirical Challenge: Carousel Isolation & Boundary Enforcement', () {
    late AppDatabase db;
    late ExploreDeckDao dao;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      dao = ExploreDeckDao(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('From Top Deck Builders strictly excludes official decks even if featured_category is maliciously set to From Top Deck Builders', () async {
      final now = DateTime.now();

      // Seed 4 official decks claiming to be From Top Deck Builders
      for (int i = 1; i <= 4; i++) {
        await db.into(db.exploreDecks).insert(
          ExploreDecksCompanion.insert(
            id: 'adversarial_official_$i',
            name: 'Spoofed Official Deck $i',
            format: 'Commander',
            sourceType: const Value('official'),
            creatorName: const Value('Wizards of the Coast'),
            featuredCategory: const Value('From Top Deck Builders'),
            score: Value(200 + i), // High scores to win order if not filtered
            createdAt: now,
            updatedAt: Value(now),
          ),
        );
      }

      // Seed 2 valid community decks
      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: 'valid_comm_1',
          name: 'Real Community Deck 1',
          format: 'Commander',
          sourceType: const Value('community'),
          creatorName: const Value('@CommunityPro'),
          featuredCategory: const Value('From Top Deck Builders'),
          score: const Value(50),
          createdAt: now,
          updatedAt: Value(now),
        ),
      );
      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: 'valid_user_shared_1',
          name: 'Real User Shared Deck 1',
          format: 'Commander',
          sourceType: const Value('user_shared'),
          creatorName: const Value('@LocalPlayer'),
          featuredCategory: const Value('From Top Deck Builders'),
          score: const Value(40),
          createdAt: now,
          updatedAt: Value(now),
        ),
      );

      final carouselResults = await dao.watchFeaturedCategory('From Top Deck Builders').first;

      // Must strictly contain only the 2 community/user_shared decks
      expect(carouselResults.length, equals(2));
      final returnedIds = carouselResults.map((d) => d.id).toSet();
      expect(returnedIds, containsAll(['valid_comm_1', 'valid_user_shared_1']));
      for (int i = 1; i <= 4; i++) {
        expect(returnedIds.contains('adversarial_official_$i'), isFalse,
            reason: 'Official deck adversarial_official_$i must be strictly excluded');
      }
    });

    test('Featured Preconstructed Decks strictly excludes community decks even if featured_category is set to Featured Preconstructed Decks', () async {
      final now = DateTime.now();

      // Seed 2 spoofed community decks
      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: 'spoofed_comm_precon',
          name: 'Fake Precon by Community',
          format: 'Commander',
          sourceType: const Value('community'),
          featuredCategory: const Value('Featured Preconstructed Decks'),
          score: const Value(500),
          createdAt: now,
          updatedAt: Value(now),
        ),
      );

      // Seed 1 official precon
      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: 'genuine_official_precon',
          name: 'Genuine WotC Precon',
          format: 'Commander',
          sourceType: const Value('official'),
          featuredCategory: const Value('Featured Preconstructed Decks'),
          score: const Value(100),
          createdAt: now,
          updatedAt: Value(now),
        ),
      );

      final preconCarousel = await dao.watchFeaturedCategory('Featured Preconstructed Decks').first;

      expect(preconCarousel.length, equals(1));
      expect(preconCarousel.first.id, equals('genuine_official_precon'));
      expect(preconCarousel.any((d) => d.id == 'spoofed_comm_precon'), isFalse);
    });
  });

  group('Milestone 3 Empirical Challenge: Lazy Precon Hydration Error Handling & Resilience', () {
    late AppDatabase db;
    late ExploreDeckDao dao;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      dao = ExploreDeckDao(db);

      // Seed official deck target
      final now = DateTime.now();
      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: 'precon_lazy_target',
          name: 'Mh3 Tricky Terrain',
          format: 'Commander',
          sourceType: const Value('official'),
          releaseCode: const Value('M3C'),
          tags: const Value('fn:TrickyTerrain_M3C,official'),
          createdAt: now,
          updatedAt: Value(now),
        ),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('hydrateOfficialDeckItems handles malformed JSON response gracefully without throwing or corrupting DB', () async {
      final brokenJsonClient = MockClient((request) async {
        return http.Response('{ "data": { "name": "Tricky Terrain", "commander": [ INVALID JSON HERE', 200);
      });

      final result = await dao.hydrateOfficialDeckItems(
        exploreDeckId: 'precon_lazy_target',
        httpClient: brokenJsonClient,
      );

      // Must not throw, returns empty list
      expect(result, isEmpty);

      // Database explore_deck_items must remain empty and uncorrupted
      final dbItems = await dao.getExploreDeckItems('precon_lazy_target');
      expect(dbItems, isEmpty);
    });

    test('hydrateOfficialDeckItems handles unexpected JSON schema (non-map data) gracefully', () async {
      final unexpectedSchemaClient = MockClient((request) async {
        return http.Response(jsonEncode(['unexpected', 'array', 'format']), 200);
      });

      final result = await dao.hydrateOfficialDeckItems(
        exploreDeckId: 'precon_lazy_target',
        httpClient: unexpectedSchemaClient,
      );

      expect(result, isEmpty);

      final dbItems = await dao.getExploreDeckItems('precon_lazy_target');
      expect(dbItems, isEmpty);
    });

    test('hydrateOfficialDeckItems handles HTTP 404 Not Found gracefully', () async {
      final notFoundClient = MockClient((request) async {
        return http.Response('Deck file not found', 404);
      });

      final result = await dao.hydrateOfficialDeckItems(
        exploreDeckId: 'precon_lazy_target',
        httpClient: notFoundClient,
      );

      expect(result, isEmpty);

      final dbItems = await dao.getExploreDeckItems('precon_lazy_target');
      expect(dbItems, isEmpty);
    });

    test('hydrateOfficialDeckItems handles HTTP 500 Internal Server Error gracefully', () async {
      final serverErrorClient = MockClient((request) async {
        return http.Response('Server error occurred', 500);
      });

      final result = await dao.hydrateOfficialDeckItems(
        exploreDeckId: 'precon_lazy_target',
        httpClient: serverErrorClient,
      );

      expect(result, isEmpty);
    });

    test('hydrateOfficialDeckItems handles network ClientException / SocketException gracefully', () async {
      final networkFailClient = MockClient((request) async {
        throw http.ClientException('Network unreachable');
      });

      final result = await dao.hydrateOfficialDeckItems(
        exploreDeckId: 'precon_lazy_target',
        httpClient: networkFailClient,
      );

      expect(result, isEmpty);
    });

    test('hydrateOfficialDeckItems handles network TimeoutException gracefully', () async {
      final timeoutClient = MockClient((request) async {
        throw TimeoutException('Request timed out after 12 seconds');
      });

      final result = await dao.hydrateOfficialDeckItems(
        exploreDeckId: 'precon_lazy_target',
        httpClient: timeoutClient,
      );

      expect(result, isEmpty);
    });

    test('hydrateOfficialDeckItems immediately returns empty without network request for non-official decks', () async {
      final now = DateTime.now();
      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: 'comm_deck_lazy_test',
          name: 'Community Deck Test',
          format: 'Commander',
          sourceType: const Value('community'),
          createdAt: now,
          updatedAt: Value(now),
        ),
      );

      bool networkCalled = false;
      final sentinelClient = MockClient((request) async {
        networkCalled = true;
        throw StateError('Network should never be contacted for community decks');
      });

      final result = await dao.hydrateOfficialDeckItems(
        exploreDeckId: 'comm_deck_lazy_test',
        httpClient: sentinelClient,
      );

      expect(result, isEmpty);
      expect(networkCalled, isFalse);
    });

    test('hydrateOfficialDeckItems returns cached items immediately without network request if already hydrated', () async {
      // Seed existing item
      await db.into(db.exploreDeckItems).insert(
        ExploreDeckItemsCompanion.insert(
          id: 'existing_item_1',
          exploreDeckId: 'precon_lazy_target',
          cardName: 'Omo, Queen of Vesuva',
          quantity: const Value(1),
          boardZone: const Value('Commander'),
          isCommander: const Value(true),
          isDeleted: const Value(false),
        ),
      );

      bool networkCalled = false;
      final sentinelClient = MockClient((request) async {
        networkCalled = true;
        throw StateError('Network should never be contacted when items already exist');
      });

      final result = await dao.hydrateOfficialDeckItems(
        exploreDeckId: 'precon_lazy_target',
        httpClient: sentinelClient,
      );

      expect(result.length, equals(1));
      expect(result.first.cardName, equals('Omo, Queen of Vesuva'));
      expect(networkCalled, isFalse);
    });
  });
}
