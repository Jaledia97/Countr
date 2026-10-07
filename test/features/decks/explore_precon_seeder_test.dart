import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/data/services/fallback_explore_seeds.dart';
import 'package:countr/features/decks/data/services/explore_seeder_service.dart';
import 'package:countr/features/decks/domain/models/explore_deck_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Explore Precon & Community Seeder Tests', () {
    test('FallbackExploreSeeds dataset integrity invariants', () {
      expect(FallbackExploreSeeds.preconSeeds.length, equals(12),
          reason: 'Expected exactly 12 official preconstructed decks');
      expect(FallbackExploreSeeds.communitySeeds.length, equals(7),
          reason: 'Expected exactly 7 curated community decks');
      expect(FallbackExploreSeeds.allSeeds.length, equals(19),
          reason: 'Expected 19 total fallback seeds');

      final allIds = <String>{};
      for (final deck in FallbackExploreSeeds.allSeeds) {
        final id = deck['id'] as String;
        expect(allIds.add(id), isTrue, reason: 'Duplicate deck id: $id');
        expect(deck['name'], isNotNull);
        expect((deck['name'] as String).isNotEmpty, isTrue);
        expect(deck['format'], isNotNull);
        expect(deck['source_type'], isIn(['official', 'community']));
        expect(deck['creator_name'], isNotNull);

        final colors = (deck['color_identity'] as List).cast<String>();
        expect(colors, isA<List<String>>());

        final cards = (deck['cards'] as List).cast<Map<String, dynamic>>();
        expect(cards.isNotEmpty, isTrue, reason: 'Deck $id has no cards');

        final commander = deck['commander'] as Map<String, dynamic>?;
        if (deck['format'] == 'Commander') {
          expect(commander, isNotNull,
              reason: 'Commander deck $id must specify a commander');
          expect(commander!['is_commander'], isTrue);
          expect(commander['name'], isNotNull);
        }

        // Valuation check
        final estimatedPrice = (deck['estimated_price'] as num).toDouble();
        expect(estimatedPrice, greaterThan(0.0),
            reason: 'Deck $id must have positive estimated price');
      }
    });

    test('Background isolate parses raw precon and community JSON', () async {
      final preconFile = File('assets/decks/precons.json');
      final commFile = File('assets/decks/community.json');

      expect(preconFile.existsSync(), isTrue,
          reason: 'assets/decks/precons.json must exist');
      expect(commFile.existsSync(), isTrue,
          reason: 'assets/decks/community.json must exist');

      final preconStr = await preconFile.readAsString();
      final commStr = await commFile.readAsString();

      // Test JSON decoding in real background isolate via Isolate.run
      final parsed = await ExploreSeederService.parseRawDecksInIsolate(
        preconStr,
        commStr,
      );

      expect(parsed.length, equals(19));
      final officialCount =
          parsed.where((d) => d['source_type'] == 'official').length;
      final communityCount =
          parsed.where((d) => d['source_type'] == 'community').length;
      expect(officialCount, equals(12));
      expect(communityCount, equals(7));

      // Validate Draconic Domination structure
      final dragonDeck =
          parsed.firstWhere((d) => d['id'] == 'precon-c17-draconic-domination');
      expect(dragonDeck['name'], equals('Draconic Domination'));
      expect(dragonDeck['commander']['name'], equals('The Ur-Dragon'));
      expect(dragonDeck['color_identity'], equals(['W', 'U', 'B', 'R', 'G']));
      expect(dragonDeck['cards'], isNotEmpty);
    });

    test('seedFromRawDecks ingests seeds into SQLite database', () async {
      expect(await db.exploreDeckDao.getExploreDeckCount(), equals(0));

      await ExploreSeederService.seedFromRawDecks(
        db,
        FallbackExploreSeeds.allSeeds,
      );

      final totalDecks = await db.exploreDeckDao.getExploreDeckCount();
      expect(totalDecks, equals(19));

      // Verify Ur-Dragon deck item in database
      final urDragonWithVote = await db.exploreDeckDao
          .getExploreDeck('precon-c17-draconic-domination');
      expect(urDragonWithVote, isNotNull);
      final urDragon = urDragonWithVote!.deck;
      expect(urDragon.name, equals('Draconic Domination'));
      expect(urDragon.format, equals('Commander'));
      expect(urDragon.commanderName, equals('The Ur-Dragon'));
      expect(urDragon.sourceType, equals('official'));
      expect(urDragon.score, greaterThan(0));

      // Verify items
      final items = await db.exploreDeckDao
          .getExploreDeckItems('precon-c17-draconic-domination');
      expect(items.isNotEmpty, isTrue);

      final commanderItem = items.firstWhere((i) => i.isCommander);
      expect(commanderItem.cardName, equals('The Ur-Dragon'));
      expect(commanderItem.boardZone, equals('Commander'));
      expect(commanderItem.manaCost, equals('{4}{W}{U}{B}{R}{G}'));
      expect(commanderItem.cmc, equals(9.0));

      // Verify non-commander items
      final scion = items.firstWhere((i) => i.cardName == 'Scion of the Ur-Dragon');
      expect(scion.isCommander, isFalse);
      expect(scion.boardZone, equals('Mainboard'));
    });

    test('seedIfNeeded is idempotent and avoids redundant inserts', () async {
      expect(await db.exploreDeckDao.getExploreDeckCount(), equals(0));

      // Initial seeding
      await ExploreSeederService.seedIfNeeded(db);
      final countAfterFirst = await db.exploreDeckDao.getExploreDeckCount();
      expect(countAfterFirst, equals(19));

      // Second seeding with force=false should be a no-op
      await ExploreSeederService.seedIfNeeded(db, force: false);
      final countAfterSecond = await db.exploreDeckDao.getExploreDeckCount();
      expect(countAfterSecond, equals(19));

      // Third seeding with force=true re-runs without error or duplication
      await ExploreSeederService.seedIfNeeded(db, force: true);
      final countAfterForce = await db.exploreDeckDao.getExploreDeckCount();
      expect(countAfterForce, equals(19));
    });

    test('clearExploreDecks cleanly removes all decks, items, and votes', () async {
      await ExploreSeederService.seedFromRawDecks(
        db,
        FallbackExploreSeeds.allSeeds,
      );
      expect(await db.exploreDeckDao.getExploreDeckCount(), equals(19));

      // Cast a vote to verify vote deletion cascade
      await db.exploreDeckDao.castVote(
        deckId: 'precon-c17-draconic-domination',
        targetVote: 1,
      );

      await db.exploreDeckDao.clearExploreDecks();

      expect(await db.exploreDeckDao.getExploreDeckCount(), equals(0));
      final items = await db.exploreDeckDao
          .getExploreDeckItems('precon-c17-draconic-domination');
      expect(items.isEmpty, isTrue);
    });

    test('Featured categories, category filtering, and sorting queries work on seeded dataset', () async {
      await ExploreSeederService.seedFromRawDecks(
        db,
        FallbackExploreSeeds.allSeeds,
      );

      // 1. Featured category stream
      final suggestedCommanders =
          await db.exploreDeckDao.watchFeaturedCategory('Suggested Commanders').first;
      expect(suggestedCommanders.isNotEmpty, isTrue);
      for (final deckWithVote in suggestedCommanders) {
        expect(deckWithVote.deck.featuredCategory, equals('Suggested Commanders'));
      }

      // 2. Official vs Community filter
      final officialDecks = await db.exploreDeckDao
          .watchExploreDecks(category: ExploreCategory.official)
          .first;
      expect(officialDecks.length, equals(12));
      for (final d in officialDecks) {
        expect(d.deck.sourceType, equals('official'));
      }

      final communityDecks = await db.exploreDeckDao
          .watchExploreDecks(category: ExploreCategory.community)
          .first;
      expect(communityDecks.length, equals(7));
      for (final d in communityDecks) {
        expect(d.deck.sourceType, isIn(['community', 'user_shared']));
      }

      // 3. Sort by popularity (score descending)
      final sortedByPopularity = await db.exploreDeckDao
          .watchExploreDecks(sort: ExploreSortOption.popularity)
          .first;
      for (var i = 0; i < sortedByPopularity.length - 1; i++) {
        expect(
          sortedByPopularity[i].deck.score,
          greaterThanOrEqualTo(sortedByPopularity[i + 1].deck.score),
          reason: 'Decks should be in non-increasing score order',
        );
      }
    });

    test('3-tier search finds decks by name, card contents, and creator username', () async {
      await ExploreSeederService.seedFromRawDecks(
        db,
        FallbackExploreSeeds.allSeeds,
      );

      // Search by deck name
      final nameSearch = await db.exploreDeckDao.searchExploreDecks(query: 'Cavalry');
      expect(nameSearch.inDeckName.any((d) => d.deck.name == 'Cavalry Charge'), isTrue);

      // Search by card name in deck items
      final cardSearch = await db.exploreDeckDao.searchExploreDecks(query: 'Sol Ring');
      expect(cardSearch.inDeckCards.isNotEmpty, isTrue);
      for (final cardMatch in cardSearch.inDeckCards) {
        expect(cardMatch.matchingCardName.toLowerCase(), contains('sol ring'));
      }

      // Search by creator name
      final creatorSearch = await db.exploreDeckDao.searchExploreDecks(query: 'SpicyBrewMaster');
      expect(creatorSearch.byUsername.isNotEmpty, isTrue);
      expect(creatorSearch.byUsername.first.deck.creatorName, equals('@SpicyBrewMaster'));
    });
  });
}
