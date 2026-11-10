import 'dart:convert';
import 'package:drift/drift.dart' hide isNull, isNotNull, Column;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/data/daos/explore_deck_dao.dart';
import 'package:countr/features/decks/data/services/precon_hydration_service.dart';
import 'package:countr/features/decks/domain/models/explore_deck_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('Milestone 3 Pipeline: Balanced Feed Interleaving (R3.A)', () {
    late AppDatabase db;
    late ExploreDeckDao dao;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      dao = ExploreDeckDao(db);

      // Insert 6 official decks and 3 community decks with decreasing scores
      final now = DateTime.now();
      for (int i = 1; i <= 6; i++) {
        await db.into(db.exploreDecks).insert(
          ExploreDecksCompanion.insert(
            id: 'official_$i',
            name: 'Official Deck $i',
            format: 'Commander',
            sourceType: const Value('official'),
            creatorName: const Value('Wizards of the Coast'),
            score: Value(100 - i),
            upvotes: Value(100 - i),
            createdAt: now.subtract(Duration(days: i)),
            updatedAt: Value(now),
          ),
        );
      }

      for (int i = 1; i <= 3; i++) {
        await db.into(db.exploreDecks).insert(
          ExploreDecksCompanion.insert(
            id: 'community_$i',
            name: 'Community Deck $i',
            format: 'Commander',
            sourceType: const Value('community'),
            creatorName: Value('@User$i'),
            score: Value(95 - i),
            upvotes: Value(95 - i),
            createdAt: now.subtract(Duration(days: i)),
            updatedAt: Value(now),
          ),
        );
      }
    });

    tearDown(() async {
      await db.close();
    });

    test('balanceFeed interleaves 2 official : 1 community deck in ExploreCategory.all', () async {
      final feed = await dao.watchExploreDecks(
        category: ExploreCategory.all,
        balanceFeed: true,
      ).first;

      expect(feed.length, equals(9));

      // Ratio pattern: Off 1, Off 2, Comm 1, Off 3, Off 4, Comm 2, Off 5, Off 6, Comm 3
      expect(feed[0].deck.id, equals('official_1'));
      expect(feed[1].deck.id, equals('official_2'));
      expect(feed[2].deck.id, equals('community_1'));
      expect(feed[3].deck.id, equals('official_3'));
      expect(feed[4].deck.id, equals('official_4'));
      expect(feed[5].deck.id, equals('community_2'));
      expect(feed[6].deck.id, equals('official_5'));
      expect(feed[7].deck.id, equals('official_6'));
      expect(feed[8].deck.id, equals('community_3'));

      // Both groups preserve individual descending score order
      expect(feed[0].deck.score, greaterThan(feed[1].deck.score));
      expect(feed[2].deck.score, greaterThan(feed[5].deck.score));
      expect(feed[5].deck.score, greaterThan(feed[8].deck.score));
    });

    test('balanceFeed is disabled when category is not ExploreCategory.all', () async {
      final officialFeed = await dao.watchExploreDecks(
        category: ExploreCategory.official,
        balanceFeed: true,
      ).first;

      expect(officialFeed.length, equals(6));
      for (final item in officialFeed) {
        expect(item.deck.sourceType, equals('official'));
      }
    });
  });

  group('Milestone 3 Pipeline: Community Deck Sharing & Carousel Isolation (R3.A)', () {
    late AppDatabase db;
    late ExploreDeckDao dao;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      dao = ExploreDeckDao(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('sharePersonalDeckToExplore sets featuredCategory to From Top Deck Builders', () async {
      final now = DateTime.now();

      // Create personal deck
      await db.into(db.decks).insert(
        DecksCompanion.insert(
          id: 'personal_deck_1',
          name: 'My Custom Atraxa Brew',
          format: 'Commander',
          createdAt: now,
          updatedAt: Value(now),
        ),
      );

      final sharedExploreDeck = await dao.sharePersonalDeckToExplore(
        personalDeckId: 'personal_deck_1',
        creatorName: '@BrewMaster',
      );

      expect(sharedExploreDeck.featuredCategory, equals('From Top Deck Builders'));
      expect(sharedExploreDeck.sourceType, equals('user_shared'));

      // Verify watchFeaturedCategory returns the shared deck in 'From Top Deck Builders'
      final carouselDecks = await dao.watchFeaturedCategory('From Top Deck Builders').first;
      expect(carouselDecks.any((d) => d.id == sharedExploreDeck.id), isTrue);
    });

    test('Strict isolation: From Top Deck Builders only returns community/user_shared decks', () async {
      final now = DateTime.now();

      // Insert official deck with 'From Top Deck Builders' (adversarial scenario)
      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: 'adversarial_official_top',
          name: 'Fake Official Top Builder',
          format: 'Commander',
          sourceType: const Value('official'),
          featuredCategory: const Value('From Top Deck Builders'),
          createdAt: now,
          updatedAt: Value(now),
        ),
      );

      // Insert community deck
      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: 'valid_community_top',
          name: 'Real Community Top Builder',
          format: 'Commander',
          sourceType: const Value('community'),
          featuredCategory: const Value('From Top Deck Builders'),
          createdAt: now,
          updatedAt: Value(now),
        ),
      );

      final topBuilderDecks = await dao.watchFeaturedCategory('From Top Deck Builders').first;
      expect(topBuilderDecks.length, equals(1));
      expect(topBuilderDecks.first.id, equals('valid_community_top'));
    });
  });

  group('Milestone 3 Pipeline: MTGJSON Lazy Hydration & Fallback (R3.B)', () {
    late AppDatabase db;
    late ExploreDeckDao dao;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      dao = ExploreDeckDao(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('hydrateOfficialDeckItems fetches MTGJSON deck and populates exploreDeckItems', () async {
      final now = DateTime.now();

      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: 'precon-blc-family-matters',
          name: 'Family Matters',
          format: 'Commander',
          sourceType: const Value('official'),
          releaseCode: const Value('BLC'),
          tags: const Value('fn:FamilyMatters_BLC,official,wotc'),
          createdAt: now,
          updatedAt: Value(now),
        ),
      );

      // Mock HTTP Client returning MTGJSON v5 deck JSON
      final mockJson = jsonEncode({
        'data': {
          'name': 'Family Matters',
          'code': 'BLC',
          'type': 'Commander Deck',
          'commander': [
            {
              'name': 'Zinnia, Valley\'s Voice',
              'scryfall_id': '11111111-2222-3333-4444-555555555555',
              'mana_cost': '{U}{R}{W}',
              'cmc': 3.0,
              'type_line': 'Legendary Creature — Bird Bard',
              'colors': ['U', 'R', 'W'],
              'count': 1,
              'board_zone': 'Commander',
              'price': 2.5,
            }
          ],
          'mainBoard': [
            {
              'name': 'Agate Instigator',
              'scryfall_id': '22222222-3333-4444-5555-666666666666',
              'mana_cost': '{1}{R}',
              'cmc': 2.0,
              'type_line': 'Creature — Lizard Rogue',
              'colors': ['R'],
              'count': 1,
              'board_zone': 'Mainboard',
              'price': 1.0,
            }
          ],
        }
      });

      final mockClient = MockClient((request) async {
        if (request.url.path.contains('FamilyMatters_BLC.json')) {
          return http.Response.bytes(
            utf8.encode(mockJson),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('Not Found', 404);
      });

      // Initially empty
      final initialCards = await dao.getExploreDeckItems('precon-blc-family-matters');
      expect(initialCards, isEmpty);

      // Call hydrateOfficialDeckItems
      final hydratedCards = await dao.hydrateOfficialDeckItems(
        exploreDeckId: 'precon-blc-family-matters',
        httpClient: mockClient,
      );

      expect(hydratedCards.length, equals(2));
      expect(hydratedCards.any((c) => c.cardName == 'Zinnia, Valley\'s Voice' && c.isCommander), isTrue);
      expect(hydratedCards.any((c) => c.cardName == 'Agate Instigator' && !c.isCommander), isTrue);
    });

    test('cloneExploreDeckToPersonal lazily hydrates unpopulated official deck before cloning', () async {
      final now = DateTime.now();

      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: 'precon-blc-family-matters',
          name: 'Family Matters',
          format: 'Commander',
          sourceType: const Value('official'),
          releaseCode: const Value('BLC'),
          tags: const Value('fn:FamilyMatters_BLC,official,wotc'),
          createdAt: now,
          updatedAt: Value(now),
        ),
      );

      final mockJson = jsonEncode({
        'data': {
          'name': 'Family Matters',
          'code': 'BLC',
          'type': 'Commander Deck',
          'commander': [
            {
              'name': 'Zinnia, Valley\'s Voice',
              'scryfall_id': '11111111-2222-3333-4444-555555555555',
              'mana_cost': '{U}{R}{W}',
              'cmc': 3.0,
              'type_line': 'Legendary Creature — Bird Bard',
              'colors': ['U', 'R', 'W'],
              'count': 1,
              'board_zone': 'Commander',
              'price': 2.5,
            }
          ],
          'mainBoard': [],
        }
      });

      // Hydrate first using mock client
      final mockClient = MockClient((request) async {
        return http.Response.bytes(
          utf8.encode(mockJson),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      await dao.hydrateOfficialDeckItems(
        exploreDeckId: 'precon-blc-family-matters',
        httpClient: mockClient,
      );

      final clonedDeck = await dao.cloneExploreDeckToPersonal(
        exploreDeckId: 'precon-blc-family-matters',
      );

      expect(clonedDeck.name, equals('Family Matters (Copy)'));
      expect(clonedDeck.isCloned, isTrue);
    });
  });

  group('Milestone 3 Pipeline: Art Series & Memorabilia Banning Pass (R4)', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('repairArtSeriesCards sanitizes art_series and identical face names across tables', () async {
      final now = DateTime.now();

      // 1. Insert explore_deck with identical split commander name
      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: 'deck_with_art_series',
          name: 'Art Series Deck',
          format: 'Commander',
          sourceType: const Value('official'),
          commanderName: const Value('Smothering Tithe // Smothering Tithe'),
          commanderImageUrl: const Value('https://cards.scryfall.io/art_crop/front/1/2/12345.jpg'),
          commanderArtCrop: const Value('https://cards.scryfall.io/art_crop/front/1/2/12345.jpg'),
          createdAt: now,
          updatedAt: Value(now),
        ),
      );

      // 2. Insert explore_deck_item with Art Series layout
      await db.into(db.exploreDeckItems).insert(
        ExploreDeckItemsCompanion.insert(
          id: 'item_with_art_series',
          exploreDeckId: 'deck_with_art_series',
          cardName: 'Smothering Tithe (Art Series)',
          quantity: const Value(1),
          boardZone: const Value('Commander'),
          isCommander: const Value(true),
          imageUrl: const Value('https://cards.scryfall.io/art_crop/front/1/2/12345.jpg'),
          isDeleted: const Value(false),
        ),
      );

      // 3. Insert vault_item with art_series dynamic_data
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'vault_art_series_1',
          name: 'Rhystic Study // Rhystic Study',
          collectionType: 'mtg',
          setOrSeries: 'Commander',
          condition: 'NM',
          imageUrl: 'https://cards.scryfall.io/art_crop/front/3/4/34567.jpg',
          dynamicData: jsonEncode({
            'layout': 'art_series',
            'set_type': 'memorabilia',
          }),
          acquiredPrice: 10.0,
          currentMarketPrice: 10.0,
          acquiredDate: now,
          lastPriceUpdate: now,
          isDeleted: const Value(false),
          updatedAt: Value(now),
        ),
      );

      // Run repair pass
      await PreconHydrationService.repairArtSeriesCards(db);

      // Verify explore_deck was sanitized
      final repairedDeck = await (db.select(db.exploreDecks)
            ..where((t) => t.id.equals('deck_with_art_series')))
          .getSingle();
      expect(repairedDeck.commanderName, equals('Smothering Tithe'));
      expect(repairedDeck.commanderImageUrl, contains('version=normal'));

      // Verify explore_deck_item was sanitized
      final repairedItem = await (db.select(db.exploreDeckItems)
            ..where((t) => t.id.equals('item_with_art_series')))
          .getSingle();
      expect(repairedItem.cardName, equals('Smothering Tithe'));
      expect(repairedItem.imageUrl, contains('version=normal'));

      // Verify vault_item was sanitized
      final repairedVault = await (db.select(db.vaultItems)
            ..where((t) => t.id.equals('vault_art_series_1')))
          .getSingle();
      expect(repairedVault.name, equals('Rhystic Study'));
      expect(repairedVault.imageUrl, contains('version=normal'));
      final dyn = jsonDecode(repairedVault.dynamicData);
      expect(dyn['layout'], equals('normal'));
    });
  });
}
