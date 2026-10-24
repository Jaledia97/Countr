import 'dart:async';
import 'dart:io';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/decks/data/models/precon_deck_dto.dart';
import 'package:countr/features/decks/data/services/fallback_explore_seeds.dart';
import 'package:countr/features/decks/data/services/explore_seeder_service.dart';
import 'package:countr/features/decks/data/services/precon_hydration_service.dart';
import 'package:countr/features/decks/domain/models/explore_deck_models.dart';
import 'package:countr/features/decks/presentation/providers/explore_deck_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

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

    test('seedIfNeeded auto-seeds official precons and community decks even when user_shared decks already exist', () async {
      final now = DateTime.now();
      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: 'user-shared-deck-1',
          name: 'My Shared Custom Brew',
          format: 'Commander',
          tcgDomain: const Value('mtg'),
          sourceType: const Value('user_shared'),
          creatorName: const Value('@LocalUser'),
          commanderName: const Value('Atraxa, Praetors\' Voice'),
          colorIdentity: const Value('["W","U","B","G"]'),
          cardCount: const Value(100),
          estimatedPrice: const Value(250.0),
          createdAt: now,
          updatedAt: Value(now),
          isDeleted: const Value(false),
        ),
      );

      expect(await db.exploreDeckDao.getExploreDeckCount(), equals(1));
      expect(await ExploreSeederService.isExploreCatalogSeeded(db), isFalse,
          reason: 'Having only user_shared decks must not mark the official/community catalog as seeded');

      await ExploreSeederService.seedIfNeeded(db);

      expect(await ExploreSeederService.isExploreCatalogSeeded(db), isTrue);
      // 1 user_shared + 12 official + 7 community = 20 total explore decks
      expect(await db.exploreDeckDao.getExploreDeckCount(), equals(20));

      final officialDecks = await db.exploreDeckDao
          .watchExploreDecks(category: ExploreCategory.official)
          .first;
      expect(officialDecks.length, equals(12));
    });

    test('Concurrent AppDatabase opening with ExploreSeederService and PreconHydrationService completes without deadlock', () async {
      // Create a brand new database connection which has not yet executed beforeOpen
      final freshDb = AppDatabase(NativeDatabase.memory());
      addTearDown(() => freshDb.close());

      // Concurrently trigger queries that run beforeOpen (such as reading vault items while
      // beforeOpen executes vaultDao.seedDatabase()), while simultaneously calling
      // ExploreSeederService.seedIfNeeded and PreconHydrationService.seedHistoricalPrecons
      final results = await Future.wait([
        freshDb.select(freshDb.vaultItems).get(),
        ExploreSeederService.seedIfNeeded(freshDb),
        PreconHydrationService.seedHistoricalPrecons(freshDb),
      ]);

      expect(results, isNotNull);

      // Verify that vault starter items were seeded by beforeOpen
      final vaultItems = await freshDb.select(freshDb.vaultItems).get();
      expect(vaultItems.isNotEmpty, isTrue, reason: 'Starter vault items must be present');

      // Verify all 19 explore decks (12 official + 7 community) were seeded
      final exploreCount = await freshDb.exploreDeckDao.getExploreDeckCount();
      expect(exploreCount, equals(19), reason: 'All 19 explore decks must be seeded');

      final officialDecks = await freshDb.exploreDeckDao
          .watchExploreDecks(category: ExploreCategory.official)
          .first;
      expect(officialDecks.length, equals(12));

      final communityDecks = await freshDb.exploreDeckDao
          .watchExploreDecks(category: ExploreCategory.community)
          .first;
      expect(communityDecks.length, equals(7));

      // Verify historical precons were seeded
      final isPreconSeeded = await PreconHydrationService.isHistoricalPreconSeeded(freshDb);
      expect(isPreconSeeded, isTrue, reason: 'Historical precons must be seeded');
    });

    test('exploreDecksStreamProvider and featuredExploreCategoryStreamProvider emit all 19 decks reactively upon seeding', () async {
      final freshDb = AppDatabase(NativeDatabase.memory());
      addTearDown(() => freshDb.close());

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(freshDb),
        ],
      );
      addTearDown(container.dispose);

      // Listen to exploreDecksStreamProvider and featuredExploreCategoryStreamProvider
      final emittedDecks = <List<ExploreDeckWithVote>>[];
      container.listen(
        exploreDecksStreamProvider,
        (_, next) {
          next.whenData((decks) => emittedDecks.add(decks));
        },
        fireImmediately: true,
      );

      final emittedFeatured = <List<ExploreDeckWithVote>>[];
      container.listen(
        featuredExploreCategoryStreamProvider('Suggested Commanders'),
        (_, next) {
          next.whenData((decks) => emittedFeatured.add(decks));
        },
        fireImmediately: true,
      );

      // Perform seeding
      await ExploreSeederService.seedIfNeeded(freshDb);

      // Allow reactive streams to process DB updates
      await pumpEventQueue();

      final currentExploreState = container.read(exploreDecksStreamProvider);
      expect(currentExploreState.hasValue, isTrue);
      expect(currentExploreState.value!.length, equals(19));

      final currentFeaturedState = container.read(
        featuredExploreCategoryStreamProvider('Suggested Commanders'),
      );
      expect(currentFeaturedState.hasValue, isTrue);
      expect(currentFeaturedState.value!.isNotEmpty, isTrue);
    });

    test('ExploreSeederService and PreconHydrationService re-entrancy guards prevent self-deadlock', () async {
      // Sequential and nested calls do not self-deadlock or throw
      await ExploreSeederService.seedIfNeeded(db);
      await PreconHydrationService.seedHistoricalPrecons(db);

      expect(await db.exploreDeckDao.getExploreDeckCount(), equals(19));
      expect(await PreconHydrationService.isHistoricalPreconSeeded(db), isTrue);
    });

    test('Zone.current[AppDatabase.beforeOpenZoneKey] defers seeding to microtask, while outside callers await full completion', () async {
      final freshDb = AppDatabase(NativeDatabase.memory());
      addTearDown(freshDb.close);

      // 1. Inside beforeOpen zone: seedIfNeeded defers to microtask and returns immediately
      bool insideZoneCompleted = false;
      await runZoned(() async {
        await ExploreSeederService.seedIfNeeded(freshDb);
        insideZoneCompleted = true;
      }, zoneValues: {AppDatabase.beforeOpenZoneKey: true});

      // The call inside the zone returns immediately without blocking
      expect(insideZoneCompleted, isTrue);

      // Wait for the scheduled microtask and background isolate to complete seeding
      while (await freshDb.exploreDeckDao.getExploreDeckCount() < 19) {
        await Future.delayed(const Duration(milliseconds: 20));
      }
      expect(await freshDb.exploreDeckDao.getExploreDeckCount(), equals(19));

      // 2. Fresh db outside beforeOpen zone: caller awaits until seeding is 100% complete
      final secondDb = AppDatabase(NativeDatabase.memory());
      addTearDown(secondDb.close);

      // Calling seedIfNeeded directly on a fresh unopened database
      await ExploreSeederService.seedIfNeeded(secondDb);
      // When await returns, all 19 decks must already be populated
      expect(await secondDb.exploreDeckDao.getExploreDeckCount(), equals(19));
      expect(await ExploreSeederService.isExploreCatalogSeeded(secondDb), isTrue);
    });

    test('Simultaneous calls to PreconHydrationService.seedHistoricalPrecons with mismatched customPrecons lists succeed without deadlock and persist both decks', () async {
      final freshDb = AppDatabase(NativeDatabase.memory());
      addTearDown(freshDb.close);

      final customDeckA = PreconDeckDto(
        id: 'precon-custom-a',
        name: 'Custom Precon Alpha',
        format: 'Commander',
        description: 'First custom test deck',
        colorIdentity: const ['W', 'U'],
        commanderCards: const [
          PreconCardDto(
            scryfallId: 'sf-alpha-cmd',
            name: 'Alpha Commander',
            boardZone: 'Commander',
            count: 1,
            manaCost: '{W}{U}',
            cmc: 2.0,
            typeLine: 'Legendary Creature',
          ),
        ],
        mainboardCards: const [
          PreconCardDto(
            scryfallId: 'sf-alpha-mb1',
            name: 'Alpha Sol Ring',
            boardZone: 'Mainboard',
            count: 1,
            manaCost: '{1}',
            cmc: 1.0,
            typeLine: 'Artifact',
          ),
        ],
      );

      final customDeckB = PreconDeckDto(
        id: 'precon-custom-b',
        name: 'Custom Precon Beta',
        format: 'Commander',
        description: 'Second custom test deck',
        colorIdentity: const ['B', 'R'],
        commanderCards: const [
          PreconCardDto(
            scryfallId: 'sf-beta-cmd',
            name: 'Beta Commander',
            boardZone: 'Commander',
            count: 1,
            manaCost: '{B}{R}',
            cmc: 2.0,
            typeLine: 'Legendary Creature',
          ),
        ],
        mainboardCards: const [
          PreconCardDto(
            scryfallId: 'sf-beta-mb1',
            name: 'Beta Dark Ritual',
            boardZone: 'Mainboard',
            count: 1,
            manaCost: '{B}',
            cmc: 1.0,
            typeLine: 'Instant',
          ),
        ],
      );

      // Launch both simultaneously
      await Future.wait([
        PreconHydrationService.seedHistoricalPrecons(freshDb, customPrecons: [customDeckA]),
        PreconHydrationService.seedHistoricalPrecons(freshDb, customPrecons: [customDeckB]),
      ]);

      // Verify both decks were persisted into SQLite
      final allDecks = await freshDb.select(freshDb.decks).get();
      final deckIds = allDecks.map((d) => d.id).toSet();
      expect(deckIds.contains('precon-custom-a'), isTrue, reason: 'Custom deck A must exist');
      expect(deckIds.contains('precon-custom-b'), isTrue, reason: 'Custom deck B must exist');

      // Verify deck versions exist
      final allVersions = await freshDb.select(freshDb.deckVersions).get();
      final versionDeckIds = allVersions.map((v) => v.deckId).toSet();
      expect(versionDeckIds.contains('precon-custom-a'), isTrue);
      expect(versionDeckIds.contains('precon-custom-b'), isTrue);

      // Verify deck version items exist
      final allItems = await freshDb.select(freshDb.deckVersionItems).get();
      final itemDeckVersionIds = allItems.map((i) => i.versionId).toSet();
      expect(itemDeckVersionIds.contains('precon-custom-a-v1'), isTrue);
      expect(itemDeckVersionIds.contains('precon-custom-b-v1'), isTrue);
    });

    test('Simultaneous calls with default precons (customPrecons: null) and custom precons persist both default catalog and custom deck', () async {
      final freshDb = AppDatabase(NativeDatabase.memory());
      addTearDown(freshDb.close);

      final customDeck = PreconDeckDto(
        id: 'precon-special-event',
        name: 'Special Event Precon',
        format: 'Commander',
        colorIdentity: const ['G'],
        commanderCards: const [
          PreconCardDto(
            scryfallId: 'sf-special-cmd',
            name: 'Special Commander',
            boardZone: 'Commander',
            count: 1,
            manaCost: '{G}',
            cmc: 1.0,
            typeLine: 'Legendary Creature',
          ),
        ],
      );

      // Concurrently launch default 12-precon seeding and custom deck seeding
      await Future.wait([
        PreconHydrationService.seedHistoricalPrecons(freshDb),
        PreconHydrationService.seedHistoricalPrecons(freshDb, customPrecons: [customDeck]),
      ]);

      final allDecks = await freshDb.select(freshDb.decks).get();
      final deckIds = allDecks.map((d) => d.id).toSet();

      // Verify custom deck exists
      expect(deckIds.contains('precon-special-event'), isTrue);

      // Verify default official precons were also seeded (12 official precons + 1 custom = 13 precon decks)
      final isSeeded = await PreconHydrationService.isHistoricalPreconSeeded(freshDb);
      expect(isSeeded, isTrue);
      final preconDecks = allDecks.where((d) => d.id.startsWith('precon-')).toList();
      expect(preconDecks.length, equals(13));
    });

    test('PreconHydrationService.loadAndParseBundledPrecons falls back to FallbackExploreSeeds on invalid asset path or I/O failure', () async {
      // Intentionally point to a non-existent asset path
      final precons = await PreconHydrationService.loadAndParseBundledPrecons(
        assetPath: 'assets/non_existent_path_404.json',
      );

      // Verify that FallbackExploreSeeds was used as a resilient fallback
      expect(precons.length, equals(12));
      final dragon = precons.firstWhere((d) => d.id == 'precon-c17-draconic-domination');
      expect(dragon.name, equals('Draconic Domination'));
      expect(dragon.commanderCards.first.name, equals('The Ur-Dragon'));
    });

    test('PreconHydrationService handles empty customPrecons gracefully without error or stuck futures', () async {
      final freshDb = AppDatabase(NativeDatabase.memory());
      addTearDown(freshDb.close);

      // Call with empty customPrecons list
      await PreconHydrationService.seedHistoricalPrecons(freshDb, customPrecons: []);

      // Future must complete immediately, database has 0 decks, and activeSeedFuture is reset
      expect(await PreconHydrationService.isHistoricalPreconSeeded(freshDb), isFalse);
      expect(PreconHydrationService.activeSeedFuture, isNull);
    });

    test('Simultaneous calls to ExploreSeederService.seedIfNeeded with force: true complete without deadlock or row duplication', () async {
      final freshDb = AppDatabase(NativeDatabase.memory());
      addTearDown(freshDb.close);

      // Launch 3 simultaneous force-seeds
      await Future.wait([
        ExploreSeederService.seedIfNeeded(freshDb, force: true),
        ExploreSeederService.seedIfNeeded(freshDb, force: true),
        ExploreSeederService.seedIfNeeded(freshDb, force: true),
      ]);

      // Verify exact count of 19 explore decks and activeSeedFuture reset
      expect(await freshDb.exploreDeckDao.getExploreDeckCount(), equals(19));
      expect(ExploreSeederService.activeSeedFuture, isNull);
    });
  });
}

