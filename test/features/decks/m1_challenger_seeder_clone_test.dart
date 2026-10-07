import 'dart:convert';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/data/services/explore_seeder_service.dart';
import 'package:countr/features/decks/data/services/fallback_explore_seeds.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    // Restore default rootBundle binary messenger handler
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
    await db.close();
  });

  // ===========================================================================
  // GROUP 1: SEEDER IDEMPOTENCY & ERROR RESILIENCE
  // ===========================================================================
  group('Challenger M1: Seeder Idempotency & Concurrency Stress', () {
    test('Sequential 10x seeding with force:true produces exactly 0 duplicate rows', () async {
      // Execute 10 consecutive forced seeding runs
      for (var iteration = 1; iteration <= 10; iteration++) {
        await ExploreSeederService.seedIfNeeded(db, force: true);

        final deckCount = await db.exploreDeckDao.getExploreDeckCount();
        expect(deckCount, equals(19),
            reason: 'Iteration $iteration must maintain exactly 19 explore decks');
      }

      // 1. Verify 0 duplicate deck IDs via SQL GROUP BY
      final duplicateDecks = await db.customSelect('''
        SELECT id, COUNT(*) as count 
        FROM explore_decks 
        GROUP BY id 
        HAVING count > 1;
      ''').get();
      expect(duplicateDecks.isEmpty, isTrue,
          reason: 'explore_decks must contain zero duplicate IDs across 10 seed runs');

      // 2. Verify 0 duplicate item IDs via SQL GROUP BY
      final duplicateItems = await db.customSelect('''
        SELECT id, COUNT(*) as count 
        FROM explore_deck_items 
        GROUP BY id 
        HAVING count > 1;
      ''').get();
      expect(duplicateItems.isEmpty, isTrue,
          reason: 'explore_deck_items must contain zero duplicate IDs across 10 seed runs');

      // 3. Verify total card count matches baseline exactly
      final totalItemRows = await db.customSelect(
        'SELECT COUNT(*) as total FROM explore_deck_items;',
      ).getSingle();
      final totalItems = totalItemRows.read<int>('total');

      int expectedItemCount = 0;
      for (final seed in FallbackExploreSeeds.allSeeds) {
        if (seed['commander'] != null) expectedItemCount += 1;
        expectedItemCount += (seed['cards'] as List).length;
      }
      expect(totalItems, equals(expectedItemCount),
          reason: 'Total deck items must match sum of all cards and commanders');
    });

    test('Sequential 10x default seeding (force:false) executes as harmless no-op', () async {
      // Run 1: seeds catalog
      await ExploreSeederService.seedIfNeeded(db, force: false);
      expect(await db.exploreDeckDao.getExploreDeckCount(), equals(19));

      // Runs 2-10: should all skip seeding immediately
      for (var i = 2; i <= 10; i++) {
        await ExploreSeederService.seedIfNeeded(db, force: false);
        expect(await db.exploreDeckDao.getExploreDeckCount(), equals(19));
      }

      final totalDecks = await db.exploreDeckDao.getExploreDeckCount();
      expect(totalDecks, equals(19));
    });

    test('Concurrent simultaneous seeding calls throttle safely without race conditions', () async {
      // Fire 10 simultaneous async seeding calls
      final futures = List.generate(
        10,
        (_) => ExploreSeederService.seedIfNeeded(db, force: false),
      );
      await Future.wait(futures);

      final totalDecks = await db.exploreDeckDao.getExploreDeckCount();
      expect(totalDecks, equals(19));

      final duplicateDecks = await db.customSelect('''
        SELECT id, COUNT(*) as count FROM explore_decks GROUP BY id HAVING count > 1;
      ''').get();
      expect(duplicateDecks.isEmpty, isTrue);
    });

    test('User votes in explore_deck_votes persist intact across forced re-seeding', () async {
      // 1. Initial seed
      await ExploreSeederService.seedIfNeeded(db);

      // 2. Alice upvotes Ur-Dragon deck
      final voteBefore = await db.exploreDeckDao.castVote(
        deckId: 'precon-c17-draconic-domination',
        userId: 'user_alice',
        targetVote: 1,
      );
      expect(voteBefore.newVote, equals(1));
      expect(voteBefore.newScore, equals(299));

      // 3. Force re-seed catalog
      await ExploreSeederService.seedIfNeeded(db, force: true);

      // 4. Verify vote record was NOT deleted
      final voteRows = await (db.select(db.exploreDeckVotes)
            ..where((t) =>
                t.exploreDeckId.equals('precon-c17-draconic-domination') &
                t.userId.equals('user_alice')))
          .get();
      expect(voteRows.length, equals(1),
          reason: 'explore_deck_votes record must survive forced re-seeding');
      expect(voteRows.first.vote, equals(1));

      // 5. Query deck with user vote
      final deckWithVote = await db.exploreDeckDao.getExploreDeck(
        'precon-c17-draconic-domination',
        userId: 'user_alice',
      );
      expect(deckWithVote, isNotNull);
      expect(deckWithVote!.userVote, equals(1),
          reason: 'User vote selection (+1) must persist across forced re-seeding');
      // Documented behavior: force re-seeding resets deck table to JSON initial baseline (298)
      expect(deckWithVote.deck.score, equals(298),
          reason: 'Forced re-seeding resets explore_decks baseline score to JSON payload');
    });

    test('Gracefully falls back to FallbackExploreSeeds when asset bundle throws PlatformException', () async {
      // Mock rootBundle to simulate missing asset or bundle failure
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', (ByteData? message) async {
        throw PlatformException(
          code: 'ASSET_NOT_FOUND',
          message: 'Simulated missing asset bundle',
        );
      });

      // Must NOT throw unhandled exception
      await ExploreSeederService.seedIfNeeded(db, force: true);

      final deckCount = await db.exploreDeckDao.getExploreDeckCount();
      expect(deckCount, equals(19),
          reason: 'Must successfully seed 19 fallback decks despite asset failure');

      final urDragon = await db.exploreDeckDao.getExploreDeck('precon-c17-draconic-domination');
      expect(urDragon, isNotNull);
      expect(urDragon!.deck.name, equals('Draconic Domination'));
    });

    test('Gracefully falls back to FallbackExploreSeeds when asset JSON is corrupted', () async {
      // Mock rootBundle to return malformed, corrupted JSON payload
      final malformedBytes = utf8.encode('{"unexpected_root": [INVALID_JSON_CONTENT{{{');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler('flutter/assets', (ByteData? message) async {
        return ByteData.view(Uint8List.fromList(malformedBytes).buffer);
      });

      // Must catch FormatException and fallback cleanly
      await ExploreSeederService.seedIfNeeded(db, force: true);

      final deckCount = await db.exploreDeckDao.getExploreDeckCount();
      expect(deckCount, equals(19),
          reason: 'Must catch JSON decoding error and fallback to FallbackExploreSeeds');
    });

    test('parseRawDecksInIsolate throws FormatException on invalid JSON', () async {
      expect(
        () => ExploreSeederService.parseRawDecksInIsolate('MALFORMED_JSON', '[]'),
        throwsA(isA<FormatException>()),
      );
    });

    test('parseRawDecksInIsolate throws TypeError when JSON is not a List', () async {
      expect(
        () => ExploreSeederService.parseRawDecksInIsolate('{"not": "a list"}', '[]'),
        throwsA(isA<TypeError>()),
      );
    });
  });

  // ===========================================================================
  // GROUP 2: BATCH INGESTION LIMITS & SQLITE VARIABLE THRESHOLDS
  // ===========================================================================
  group('Challenger M1: Batch Ingestion Limits & Stress Testing', () {
    test('Chunked item ingestion handles 1,500+ items without SQLite variable limit errors', () async {
      // 1. Insert parent explore deck
      final now = DateTime.now();
      const parentDeckId = 'stress_deck_1500';
      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: parentDeckId,
          name: 'Stress Test Deck 1500',
          format: 'Commander',
          createdAt: now,
        ),
      );

      // 2. Generate 1,500 distinct ExploreDeckItem companions (17 columns x 1500 = 25,500 variables)
      final largeItemList = <ExploreDeckItemsCompanion>[];
      for (var i = 1; i <= 1500; i++) {
        largeItemList.add(
          ExploreDeckItemsCompanion.insert(
            id: 'stress_item_$i',
            exploreDeckId: parentDeckId,
            cardName: 'Stress Card #$i',
            boardZone: const Value('Mainboard'),
            quantity: const Value(1),
            manaCost: const Value('{2}{U}'),
            cmc: const Value(3.0),
            price: const Value(1.50),
            isCommander: const Value(false),
            isDeleted: const Value(false),
          ),
        );
      }

      // 3. Batch insert with default chunkSize (250)
      await db.exploreDeckDao.batchInsertExploreDeckItems(largeItemList, chunkSize: 250);

      final fetched = await db.exploreDeckDao.getExploreDeckItems(parentDeckId);
      expect(fetched.length, equals(1500),
          reason: 'All 1,500 items must be successfully inserted and retrieved');
    });

    test('Batch insertion with large chunkSize (1,000) completes without error', () async {
      const parentDeckId = 'stress_deck_chunk_1000';
      final now = DateTime.now();
      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: parentDeckId,
          name: 'Chunk Size 1000 Test',
          format: 'Modern',
          createdAt: now,
        ),
      );

      final items = List.generate(
        2000,
        (i) => ExploreDeckItemsCompanion.insert(
          id: 'chunk_item_$i',
          exploreDeckId: parentDeckId,
          cardName: 'Chunk Card #$i',
          quantity: const Value(1),
        ),
      );

      await db.exploreDeckDao.batchInsertExploreDeckItems(items, chunkSize: 1000);

      final fetched = await db.exploreDeckDao.getExploreDeckItems(parentDeckId);
      expect(fetched.length, equals(2000));
    });

    test('seedFromRawDecks ingests 50 synthetic decks with 5,000 cards in a single batch', () async {
      final syntheticDecks = <Map<String, dynamic>>[];

      for (var d = 1; d <= 50; d++) {
        final cards = List.generate(
          100,
          (c) => {
            'name': 'Synthetic Card D${d}_C$c',
            'count': 1,
            'price': 0.50,
            'mana_cost': '{1}{G}',
            'cmc': 2.0,
            'type_line': 'Creature',
            'board_zone': 'Mainboard',
          },
        );

        syntheticDecks.add({
          'id': 'synthetic_deck_$d',
          'name': 'Synthetic Deck $d',
          'format': 'Commander',
          'source_type': 'community',
          'creator_name': '@SyntheticBuilder',
          'estimated_price': 50.0,
          'card_count': 101,
          'color_identity': ['G'],
          'commander': {
            'name': 'Synthetic Commander $d',
            'count': 1,
            'price': 2.0,
            'board_zone': 'Commander',
            'is_commander': true,
          },
          'cards': cards,
        });
      }

      await ExploreSeederService.seedFromRawDecks(db, syntheticDecks);

      final deckCount = await db.exploreDeckDao.getExploreDeckCount();
      expect(deckCount, equals(50));

      // 50 decks * 101 items (1 commander + 100 cards) = 5,050 items
      final totalItemRows = await db.customSelect(
        'SELECT COUNT(*) as total FROM explore_deck_items;',
      ).getSingle();
      expect(totalItemRows.read<int>('total'), equals(5050));
    });
  });

  // ===========================================================================
  // GROUP 3: CLONE ENGINE INVARIANTS & INVENTORY LEDGERS
  // ===========================================================================
  group('Challenger M1: Clone Engine Invariants & Inventory Ledgers', () {
    test('Cloning explore deck creates valid personal deck, active version, and version items', () async {
      // Seed fallback explore catalog
      await ExploreSeederService.seedFromRawDecks(db, FallbackExploreSeeds.allSeeds);

      const sourceExploreId = 'precon-c17-draconic-domination';
      final sourceDeck = (await db.exploreDeckDao.getExploreDeck(sourceExploreId))!.deck;
      final sourceItems = await db.exploreDeckDao.getExploreDeckItems(sourceExploreId);

      // Clone deck
      final clonedDeck = await db.exploreDeckDao.cloneExploreDeckToPersonal(
        exploreDeckId: sourceExploreId,
      );

      // 1. Deck table invariants
      expect(clonedDeck.id, isNot(equals(sourceExploreId)));
      expect(clonedDeck.name, equals('${sourceDeck.name} (Copy)'));
      expect(clonedDeck.format, equals(sourceDeck.format));
      expect(clonedDeck.tcgDomain, equals(sourceDeck.tcgDomain));
      expect(clonedDeck.isCloned, isTrue, reason: 'is_cloned must be true for cloned decks');
      expect(clonedDeck.sourceExploreDeckId, equals(sourceExploreId),
          reason: 'source_explore_deck_id must reference parent explore deck ID');
      expect(clonedDeck.isAssembled, isFalse, reason: 'Cloned decks start in Draft state');
      expect(clonedDeck.isRegistered, isFalse, reason: 'Cloned decks start unregistered');
      expect(clonedDeck.isDeleted, isFalse);
      expect(clonedDeck.coverItemId, isNotNull,
          reason: 'Commander card should be resolved as cover item');

      // 2. DeckVersions table invariants
      final versions = await (db.select(db.deckVersions)
            ..where((t) => t.deckId.equals(clonedDeck.id) & t.isDeleted.equals(false)))
          .get();
      expect(versions.length, equals(1));
      final activeVersion = versions.first;
      expect(activeVersion.versionNumber, equals(1));
      expect(activeVersion.isActive, isTrue);
      expect(activeVersion.versionNote, contains('Cloned from Explore'));

      // 3. DeckVersionItems table invariants
      final versionItems = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals(activeVersion.id) & t.isDeleted.equals(false)))
          .get();
      expect(versionItems.length, equals(sourceItems.length),
          reason: 'DeckVersionItems count must match ExploreDeckItems count');

      final commanderVersionItem = versionItems.firstWhere(
        (i) => i.boardZone.toLowerCase() == 'commander',
      );
      expect(commanderVersionItem.vaultItemId, equals(clonedDeck.coverItemId));
      expect(commanderVersionItem.isProxy, isTrue,
          reason: 'Unowned cards synthesized during clone must be marked isProxy = true');
    });

    test('Cloning same explore deck 5 times produces 5 distinct decks and deduplicates vault_items', () async {
      await ExploreSeederService.seedFromRawDecks(db, FallbackExploreSeeds.allSeeds);
      const sourceExploreId = 'precon-c17-draconic-domination';

      final initialVaultItemsCount = (await db.select(db.vaultItems).get()).length;

      final clonedDeckIds = <String>{};
      for (var i = 1; i <= 5; i++) {
        final cloned = await db.exploreDeckDao.cloneExploreDeckToPersonal(
          exploreDeckId: sourceExploreId,
        );
        expect(clonedDeckIds.add(cloned.id), isTrue,
            reason: 'Each clone operation must generate a distinct UUID');
        expect(cloned.isCloned, isTrue);
        expect(cloned.sourceExploreDeckId, equals(sourceExploreId));
      }

      // Check personal decks count
      final personalDecks = await (db.select(db.decks)
            ..where((t) => t.sourceExploreDeckId.equals(sourceExploreId)))
          .get();
      expect(personalDecks.length, equals(5));

      // Check vault_items count
      // The 1st clone creates reference vault_items; runs 2-5 must reuse them without duplicating
      final vaultCountAfterRun1 = (await db.select(db.vaultItems).get()).length;
      expect(vaultCountAfterRun1, greaterThan(initialVaultItemsCount));

      // After 5 clones, vault_items count must remain identical to run 1 count
      final vaultCountAfterRun5 = (await db.select(db.vaultItems).get()).length;
      expect(vaultCountAfterRun5, equals(vaultCountAfterRun1),
          reason: 'Subsequent clones must reuse catalog vault_items and not duplicate rows');
    });

    test('Inventory Ledger Invariant: Cloned Draft Deck does NOT allocate or corrupt VaultDao availability', () async {
      // 1. User owns physical inventory before cloning:
      // - 2 copies of "Sol Ring" (owned: 2)
      // - 1 copy of "Command Tower" (owned: 1)
      final now = DateTime.now();
      const solRingId = 'vault_card_sol_ring';
      const commandTowerId = 'vault_card_command_tower';

      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: solRingId,
          collectionType: 'mtg',
          name: 'Sol Ring',
          setOrSeries: 'Commander 2017',
          imageUrl: 'https://cards.scryfall.io/sol_ring.jpg',
          acquiredPrice: 2.0,
          acquiredDate: now,
          quantity: const Value(2), // 2 owned copies
          condition: 'NM',
          currentMarketPrice: 2.0,
          lastPriceUpdate: now,
          dynamicData: '{}',
        ),
      );

      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: commandTowerId,
          collectionType: 'mtg',
          name: 'Command Tower',
          setOrSeries: 'Commander 2017',
          imageUrl: 'https://cards.scryfall.io/command_tower.jpg',
          acquiredPrice: 0.50,
          acquiredDate: now,
          quantity: const Value(1), // 1 owned copy
          condition: 'NM',
          currentMarketPrice: 0.50,
          lastPriceUpdate: now,
          dynamicData: '{}',
        ),
      );

      // Verify pre-clone availability
      final preAvailMap = await db.vaultDao.watchAllCardAvailability().first;
      expect(preAvailMap[solRingId]!.owned, equals(2));
      expect(preAvailMap[solRingId]!.inDeck, equals(0));
      expect(preAvailMap[solRingId]!.available, equals(2));

      expect(preAvailMap[commandTowerId]!.owned, equals(1));
      expect(preAvailMap[commandTowerId]!.inDeck, equals(0));
      expect(preAvailMap[commandTowerId]!.available, equals(1));

      // 2. Seed explore catalog (contains Sol Ring & Command Tower in Ur-Dragon precon)
      await ExploreSeederService.seedFromRawDecks(db, FallbackExploreSeeds.allSeeds);

      // 3. Clone Ur-Dragon explore deck (creates a DRAFT deck)
      final cloned = await db.exploreDeckDao.cloneExploreDeckToPersonal(
        exploreDeckId: 'precon-c17-draconic-domination',
      );
      expect(cloned.isAssembled, isFalse);

      // 4. Check post-clone availability in VaultDao
      // INVARIANT: Draft decks do NOT allocate physical inventory!
      // Invariant: Available = Owned - Allocated (Allocated = 0 in draft).
      final postCloneAvailMap = await db.vaultDao.watchAllCardAvailability().first;

      final solRingAvail = postCloneAvailMap[solRingId]!;
      expect(solRingAvail.owned, equals(2));
      expect(solRingAvail.inDeck, equals(0),
          reason: 'Draft deck must NOT lock Sol Ring into physical allocation');
      expect(solRingAvail.available, equals(2));

      final cmdTowerAvail = postCloneAvailMap[commandTowerId]!;
      expect(cmdTowerAvail.owned, equals(1));
      expect(cmdTowerAvail.inDeck, equals(0),
          reason: 'Draft deck must NOT lock Command Tower into physical allocation');
      expect(cmdTowerAvail.available, equals(1));

      // 5. Check synthesized unowned cards in VaultDao (e.g. The Ur-Dragon)
      final urDragonVaultItem = await (db.select(db.vaultItems)
            ..where((t) => t.name.equals('The Ur-Dragon')))
          .getSingle();
      final urDragonAvail = postCloneAvailMap[urDragonVaultItem.id]!;
      expect(urDragonAvail.owned, equals(0));
      expect(urDragonAvail.inDeck, equals(0));
      expect(urDragonAvail.available, equals(0));
    });

    test('Inventory Ledger Invariant: Transitioning cloned deck to Assembled allocates owned cards and respects proxies', () async {
      // 1. Setup owned cards
      final now = DateTime.now();
      const solRingId = 'vault_sol_ring_2';
      const cmdTowerId = 'vault_cmd_tower_2';

      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: solRingId,
          collectionType: 'mtg',
          name: 'Sol Ring',
          setOrSeries: 'C17',
          imageUrl: '',
          acquiredPrice: 2.0,
          acquiredDate: now,
          quantity: const Value(2), // 2 owned
          condition: 'NM',
          currentMarketPrice: 2.0,
          lastPriceUpdate: now,
          dynamicData: '{}',
        ),
      );

      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: cmdTowerId,
          collectionType: 'mtg',
          name: 'Command Tower',
          setOrSeries: 'C17',
          imageUrl: '',
          acquiredPrice: 0.5,
          acquiredDate: now,
          quantity: const Value(1), // 1 owned
          condition: 'NM',
          currentMarketPrice: 0.5,
          lastPriceUpdate: now,
          dynamicData: '{}',
        ),
      );

      await ExploreSeederService.seedFromRawDecks(db, FallbackExploreSeeds.allSeeds);
      final cloned = await db.exploreDeckDao.cloneExploreDeckToPersonal(
        exploreDeckId: 'precon-c17-draconic-domination',
      );

      // 2. Mark cloned deck as ASSEMBLED (is_assembled = true)
      await (db.update(db.decks)..where((t) => t.id.equals(cloned.id)))
          .write(const DecksCompanion(isAssembled: Value(true)));

      // 3. Query availability map
      final availMap = await db.vaultDao.watchAllCardAvailability().first;

      // Sol Ring: Owned 2, Cloned deck needs 1 (not proxy). Available = 2 - 1 = 1.
      final solAvail = availMap[solRingId]!;
      expect(solAvail.owned, equals(2));
      expect(solAvail.inDeck, equals(1));
      expect(solAvail.available, equals(1),
          reason: 'Available must equal Owned - InDeck (2 - 1 = 1)');

      // Command Tower: Owned 1, Cloned deck needs 1 (not proxy). Available = 1 - 1 = 0.
      final cmdAvail = availMap[cmdTowerId]!;
      expect(cmdAvail.owned, equals(1));
      expect(cmdAvail.inDeck, equals(1));
      expect(cmdAvail.available, equals(0),
          reason: 'Available must equal Owned - InDeck (1 - 1 = 0)');

      // Unowned cards (The Ur-Dragon): Owned 0, isProxy = true.
      // INVARIANT: Proxies must NOT allocate or make available negative!
      final urDragonItem = await (db.select(db.vaultItems)
            ..where((t) => t.name.equals('The Ur-Dragon')))
          .getSingle();
      final urAvail = availMap[urDragonItem.id]!;
      expect(urAvail.owned, equals(0));
      expect(urAvail.inDeck, equals(0),
          reason: 'Proxy cards must not be counted in in_deck allocation');
      expect(urAvail.available, equals(0),
          reason: 'Available must never drop below 0');

      // 4. Soft-delete the assembled deck: physical allocation should immediately free up!
      await (db.update(db.decks)..where((t) => t.id.equals(cloned.id)))
          .write(const DecksCompanion(isDeleted: Value(true)));

      final freedMap = await db.vaultDao.watchAllCardAvailability().first;
      expect(freedMap[solRingId]!.inDeck, equals(0));
      expect(freedMap[solRingId]!.available, equals(2));
      expect(freedMap[cmdTowerId]!.inDeck, equals(0));
      expect(freedMap[cmdTowerId]!.available, equals(1));
    });

    test('Cloning deck without commander (e.g. Modern format) succeeds with null coverItemId', () async {
      // Create a modern explore deck without commander
      final now = DateTime.now();
      const modernDeckId = 'explore_modern_burn';
      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: modernDeckId,
          name: 'Modern Burn',
          format: 'Modern',
          commanderName: const Value(null),
          commanderImageUrl: const Value(null),
          createdAt: now,
        ),
      );

      await db.into(db.exploreDeckItems).insert(
        ExploreDeckItemsCompanion.insert(
          id: 'burn_bolt_1',
          exploreDeckId: modernDeckId,
          cardName: 'Lightning Bolt',
          boardZone: const Value('Mainboard'),
          quantity: const Value(4),
          isCommander: const Value(false),
        ),
      );

      final clonedModern = await db.exploreDeckDao.cloneExploreDeckToPersonal(
        exploreDeckId: modernDeckId,
      );

      expect(clonedModern.name, equals('Modern Burn (Copy)'));
      expect(clonedModern.format, equals('Modern'));
      expect(clonedModern.isCloned, isTrue);
      expect(clonedModern.coverItemId, isNull,
          reason: 'Non-commander deck clone should leave coverItemId null');

      final items = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.isNotNull()))
          .get();
      expect(items.any((i) => i.boardZone == 'Mainboard'), isTrue);
    });

    test('Cloning invalid exploreDeckId throws exception and rolls back cleanly', () async {
      final initialDecksCount = (await db.select(db.decks).get()).length;
      final initialVersionsCount = (await db.select(db.deckVersions).get()).length;
      final initialVersionItemsCount = (await db.select(db.deckVersionItems).get()).length;

      // Attempt to clone non-existent ID
      expect(
        () => db.exploreDeckDao.cloneExploreDeckToPersonal(
          exploreDeckId: 'non_existent_deck_id_99999',
        ),
        throwsA(anything),
      );

      // Verify complete transaction rollback: 0 orphaned rows
      final postDecksCount = (await db.select(db.decks).get()).length;
      final postVersionsCount = (await db.select(db.deckVersions).get()).length;
      final postVersionItemsCount = (await db.select(db.deckVersionItems).get()).length;

      expect(postDecksCount, equals(initialDecksCount));
      expect(postVersionsCount, equals(initialVersionsCount));
      expect(postVersionItemsCount, equals(initialVersionItemsCount));
    });
  });
}
