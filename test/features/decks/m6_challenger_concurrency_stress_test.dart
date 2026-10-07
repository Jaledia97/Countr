import 'dart:math' as math;
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/data/daos/explore_deck_dao.dart';
import 'package:countr/features/decks/domain/models/explore_deck_models.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/domain/models/card_availability.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  late AppDatabase db;
  late ExploreDeckDao exploreDao;
  late VaultDao vaultDao;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    exploreDao = ExploreDeckDao(db);
    vaultDao = VaultDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  /// Helper to seed an explore deck with given card count and initial votes.
  Future<ExploreDeck> seedExploreDeck({
    required String id,
    required String name,
    String format = 'Commander',
    String sourceType = 'official',
    String creatorName = 'Wizards of the Coast',
    int cardCount = 10,
    int initialUpvotes = 0,
    int initialDownvotes = 0,
    int initialScore = 0,
    List<Map<String, dynamic>>? cardSpecs,
  }) async {
    final now = DateTime.now();

    await db.into(db.exploreDecks).insert(
      ExploreDecksCompanion.insert(
        id: id,
        name: name,
        format: format,
        tcgDomain: const Value('mtg'),
        sourceType: Value(sourceType),
        creatorName: Value(creatorName),
        description: Value('Explore deck $name description'),
        commanderName: const Value('General Test Commander'),
        colorIdentity: const Value('["W","U","B"]'),
        cardCount: Value(cardCount),
        estimatedPrice: const Value(120.0),
        upvotes: Value(initialUpvotes),
        downvotes: Value(initialDownvotes),
        score: Value(initialScore),
        createdAt: now,
        updatedAt: Value(now),
        isDeleted: const Value(false),
      ),
      mode: InsertMode.insertOrReplace,
    );

    // Seed commander card
    await db.into(db.exploreDeckItems).insert(
      ExploreDeckItemsCompanion.insert(
        id: 'cmd_$id',
        exploreDeckId: id,
        cardName: 'General Test Commander',
        scryfallId: Value('scryfall_cmd_$id'),
        quantity: const Value(1),
        boardZone: const Value('Commander'),
        isCommander: const Value(true),
        price: const Value(12.5),
      ),
      mode: InsertMode.insertOrReplace,
    );

    if (cardSpecs != null) {
      for (var i = 0; i < cardSpecs.length; i++) {
        final spec = cardSpecs[i];
        await db.into(db.exploreDeckItems).insert(
          ExploreDeckItemsCompanion.insert(
            id: 'item_${id}_$i',
            exploreDeckId: id,
            cardName: spec['name'] as String,
            scryfallId: Value(spec['scryfall_id'] as String? ?? 'scryfall_${id}_$i'),
            quantity: Value(spec['quantity'] as int? ?? 1),
            boardZone: Value(spec['board_zone'] as String? ?? 'Mainboard'),
            isCommander: Value(spec['is_commander'] as bool? ?? false),
            price: Value(spec['price'] as double? ?? 1.0),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    } else {
      // Seed regular items up to cardCount
      for (var i = 1; i < cardCount; i++) {
        await db.into(db.exploreDeckItems).insert(
          ExploreDeckItemsCompanion.insert(
            id: 'item_${id}_$i',
            exploreDeckId: id,
            cardName: 'Card $i for $name',
            scryfallId: Value('scryfall_${id}_$i'),
            quantity: const Value(1),
            boardZone: const Value('Mainboard'),
            isCommander: const Value(false),
            price: const Value(1.5),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    }

    return (await (db.select(db.exploreDecks)..where((t) => t.id.equals(id))).getSingle());
  }

  // ===========================================================================
  // GROUP 1: CONCURRENCY & TRANSACTIONAL ATOMICITY UNDER HEAVY ASYNC LOAD
  // ===========================================================================
  group('1. Concurrency & Transactional Consistency Under Heavy Load', () {
    test('1.1 Concurrent multi-user voting race on single explore deck', () async {
      const deckId = 'deck_stress_vote_race_1';
      await seedExploreDeck(
        id: deckId,
        name: 'Concurrency Vote Deck',
        initialUpvotes: 10,
        initialDownvotes: 5,
        initialScore: 5,
      );

      // 50 concurrent distinct users voting simultaneously:
      // 30 users vote +1
      // 15 users vote -1
      // 5 users vote 0 (neutral / unvoted)
      const totalUsers = 50;
      final futures = <Future<VoteResult>>[];

      for (var i = 0; i < totalUsers; i++) {
        final userId = 'voter_stress_$i';
        final int targetVote;
        if (i < 30) {
          targetVote = 1;
        } else if (i < 45) {
          targetVote = -1;
        } else {
          targetVote = 0;
        }

        futures.add(exploreDao.castVote(
          deckId: deckId,
          userId: userId,
          targetVote: targetVote,
          toggle: false,
        ));
      }

      final results = await Future.wait(futures);
      expect(results.length, equals(50));

      // Verify records in explore_deck_votes
      final voteRecords = await (db.select(db.exploreDeckVotes)
            ..where((t) => t.exploreDeckId.equals(deckId)))
          .get();
      expect(voteRecords.length, equals(50));

      final upvoteCount = voteRecords.where((v) => v.vote == 1).length;
      final downvoteCount = voteRecords.where((v) => v.vote == -1).length;
      final neutralCount = voteRecords.where((v) => v.vote == 0).length;

      expect(upvoteCount, equals(30));
      expect(downvoteCount, equals(15));
      expect(neutralCount, equals(5));

      // Verify aggregate deck table
      final deck = await (db.select(db.exploreDecks)
            ..where((t) => t.id.equals(deckId)))
          .getSingle();

      expect(deck.upvotes, equals(10 + 30), reason: 'Initial 10 + 30 new upvotes');
      expect(deck.downvotes, equals(5 + 15), reason: 'Initial 5 + 15 new downvotes');
      expect(deck.score, equals(5 + 30 - 15), reason: 'Score = initial 5 + 30 - 15 = 20');
      expect(deck.score, equals(deck.upvotes - deck.downvotes));
    });

    test('1.2 Rapid async voting toggles and flaps from same user maintain atomic integrity', () async {
      const deckId = 'deck_stress_user_flap_1';
      await seedExploreDeck(
        id: deckId,
        name: 'Single User Flap Deck',
        initialUpvotes: 0,
        initialDownvotes: 0,
        initialScore: 0,
      );

      const userId = 'flapping_user_alpha';

      // Rapidly fire 30 async votes without awaiting between calls
      final targets = [1, -1, 1, 0, -1, 1, 1, -1, 0, 1, -1, 1, 0, -1, 1, -1, 0, 1, 1, -1, 0, 1, -1, 1, -1, 0, 1, -1, 1, 0];
      final futures = <Future<VoteResult>>[];
      for (final t in targets) {
        futures.add(exploreDao.castVote(
          deckId: deckId,
          userId: userId,
          targetVote: t,
          toggle: false,
        ));
      }

      await Future.wait(futures);

      // Verify that the final stored vote for user matches explore_deck_votes exactly
      final userVoteRow = await (db.select(db.exploreDeckVotes)
            ..where((t) => t.exploreDeckId.equals(deckId) & t.userId.equals(userId)))
          .getSingle();

      final deck = await (db.select(db.exploreDecks)
            ..where((t) => t.id.equals(deckId)))
          .getSingle();

      // Check mathematical consistency
      expect(deck.upvotes, greaterThanOrEqualTo(0));
      expect(deck.downvotes, greaterThanOrEqualTo(0));
      expect(deck.score, equals(deck.upvotes - deck.downvotes));

      // With only 1 user voting from 0 base:
      if (userVoteRow.vote == 1) {
        expect(deck.upvotes, equals(1));
        expect(deck.downvotes, equals(0));
        expect(deck.score, equals(1));
      } else if (userVoteRow.vote == -1) {
        expect(deck.upvotes, equals(0));
        expect(deck.downvotes, equals(1));
        expect(deck.score, equals(-1));
      } else {
        expect(deck.upvotes, equals(0));
        expect(deck.downvotes, equals(0));
        expect(deck.score, equals(0));
      }
    });

    test('1.3 Massive interleaved multi-deck concurrent voting stress across 5 decks', () async {
      final deckIds = ['deck_multi_1', 'deck_multi_2', 'deck_multi_3', 'deck_multi_4', 'deck_multi_5'];

      for (var i = 0; i < deckIds.length; i++) {
        await seedExploreDeck(
          id: deckIds[i],
          name: 'Multi Deck #$i',
          initialUpvotes: i * 2,
          initialDownvotes: i,
          initialScore: i,
        );
      }

      // Fire 100 concurrent votes randomly across the 5 decks by 20 distinct users
      final random = math.Random(42);
      final futures = <Future<VoteResult>>[];

      for (var i = 0; i < 100; i++) {
        final dId = deckIds[random.nextInt(deckIds.length)];
        final uId = 'user_rand_${random.nextInt(20)}';
        final voteChoice = [-1, 0, 1][random.nextInt(3)];

        futures.add(exploreDao.castVote(
          deckId: dId,
          userId: uId,
          targetVote: voteChoice,
          toggle: false,
        ));
      }

      await Future.wait(futures);

      // Verify every single deck satisfies exact SQLite ledger invariants
      for (var i = 0; i < deckIds.length; i++) {
        final dId = deckIds[i];
        final deck = await (db.select(db.exploreDecks)..where((t) => t.id.equals(dId))).getSingle();

        final votes = await (db.select(db.exploreDeckVotes)
              ..where((t) => t.exploreDeckId.equals(dId)))
            .get();

        final actualUpvotes = votes.where((v) => v.vote == 1).length;
        final actualDownvotes = votes.where((v) => v.vote == -1).length;

        final expectedUpvotes = (i * 2) + actualUpvotes;
        final expectedDownvotes = i + actualDownvotes;
        final expectedScore = expectedUpvotes - expectedDownvotes;

        expect(deck.upvotes, equals(expectedUpvotes), reason: 'Upvotes match actual vote rows for $dId');
        expect(deck.downvotes, equals(expectedDownvotes), reason: 'Downvotes match actual vote rows for $dId');
        expect(deck.score, equals(expectedScore), reason: 'Score matches net votes for $dId');
      }
    });

    test('1.4 Concurrent clones on the same explore deck create distinct, valid personal decks', () async {
      const deckId = 'deck_clone_race_target';
      await seedExploreDeck(
        id: deckId,
        name: 'Ur-Dragon Clone Target',
        cardCount: 15,
      );

      // Concurrently launch 10 clone operations on the exact same explore deck
      const cloneCount = 10;
      final cloneFutures = List.generate(
        cloneCount,
        (_) => exploreDao.cloneExploreDeckToPersonal(exploreDeckId: deckId),
      );

      final clonedDecks = await Future.wait(cloneFutures);

      expect(clonedDecks.length, equals(cloneCount));

      // Ensure every cloned deck has a distinct unique ID
      final clonedDeckIds = clonedDecks.map((d) => d.id).toSet();
      expect(clonedDeckIds.length, equals(cloneCount), reason: 'All clone deck IDs must be globally unique');

      for (final deck in clonedDecks) {
        expect(deck.name, equals('Ur-Dragon Clone Target (Copy)'));
        expect(deck.isCloned, isTrue);
        expect(deck.isAssembled, isFalse);
        expect(deck.sourceExploreDeckId, equals(deckId));
        expect(deck.isDeleted, isFalse);
      }

      // Check DeckVersions table: exactly 10 distinct versions created
      final versions = await (db.select(db.deckVersions)
            ..where((t) => t.deckId.isIn(clonedDeckIds)))
          .get();
      expect(versions.length, equals(cloneCount));
      final versionIds = versions.map((v) => v.id).toSet();
      expect(versionIds.length, equals(cloneCount));

      // Check DeckVersionItems table: 10 * 15 = 150 items
      final versionItems = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.isIn(versionIds)))
          .get();
      expect(versionItems.length, equals(cloneCount * 15));

      // Source explore deck must be completely untouched
      final sourceDeck = await (db.select(db.exploreDecks)
            ..where((t) => t.id.equals(deckId)))
          .getSingle();
      expect(sourceDeck.name, equals('Ur-Dragon Clone Target'));
      expect(sourceDeck.cardCount, equals(15));
    });

    test('1.5 Concurrent clones across multiple distinct explore decks', () async {
      final sourceDeckIds = ['src_deck_a', 'src_deck_b', 'src_deck_c', 'src_deck_d'];
      for (final id in sourceDeckIds) {
        await seedExploreDeck(id: id, name: 'Precon $id', cardCount: 8);
      }

      // Concurrently clone 4 times per deck = 16 clones total
      final futures = <Future<Deck>>[];
      for (final id in sourceDeckIds) {
        for (var i = 0; i < 4; i++) {
          futures.add(exploreDao.cloneExploreDeckToPersonal(exploreDeckId: id));
        }
      }

      final clonedDecks = await Future.wait(futures);
      expect(clonedDecks.length, equals(16));

      final uniqueIds = clonedDecks.map((d) => d.id).toSet();
      expect(uniqueIds.length, equals(16));

      for (final id in sourceDeckIds) {
        final matches = clonedDecks.where((d) => d.sourceExploreDeckId == id).toList();
        expect(matches.length, equals(4));
      }
    });
  });

  // ===========================================================================
  // GROUP 2: DATABASE ISOLATION INVARIANT (PERSONAL DECK MUTATIONS VS EXPLORE)
  // ===========================================================================
  group('2. Database Isolation Invariant: Heavy Personal Mutations vs Explore Catalog', () {
    test('2.1 Destructive mutation of cloned personal deck does not affect source explore deck', () async {
      const exploreDeckId = 'explore_pristine_source';
      await seedExploreDeck(
        id: exploreDeckId,
        name: 'Pristine Precon',
        cardCount: 20,
        initialUpvotes: 42,
        initialScore: 42,
      );

      // 1. Clone to personal
      final personalDeck = await exploreDao.cloneExploreDeckToPersonal(
        exploreDeckId: exploreDeckId,
      );

      // Verify baseline before mutation
      final initialExploreDeck = await (db.select(db.exploreDecks)
            ..where((t) => t.id.equals(exploreDeckId)))
          .getSingle();
      final initialExploreItems = await (db.select(db.exploreDeckItems)
            ..where((t) => t.exploreDeckId.equals(exploreDeckId)))
          .get();

      expect(initialExploreDeck.name, equals('Pristine Precon'));
      expect(initialExploreItems.length, equals(20));

      // 2. Perform heavy, destructive mutations on personal tables:
      // a) Rename personal deck
      await (db.update(db.decks)..where((t) => t.id.equals(personalDeck.id))).write(
        const DecksCompanion(
          name: Value('Completely Corrupted Personal Deck Name'),
          description: Value('Destroyed description'),
          format: Value('Modern'),
        ),
      );

      // b) Delete half of personal deck version items
      final pVersions = await (db.select(db.deckVersions)
            ..where((t) => t.deckId.equals(personalDeck.id)))
          .get();
      final pVersionId = pVersions.first.id;

      final pItems = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals(pVersionId)))
          .get();

      for (var i = 0; i < 10; i++) {
        await (db.delete(db.deckVersionItems)..where((t) => t.id.equals(pItems[i].id))).go();
      }

      // c) Alter quantities and board zones of remaining items
      for (var i = 10; i < pItems.length; i++) {
        await (db.update(db.deckVersionItems)..where((t) => t.id.equals(pItems[i].id))).write(
          const DeckVersionItemsCompanion(
            quantity: Value(99),
            boardZone: Value('Sideboard'),
            isProxy: Value(true),
          ),
        );
      }

      // d) Mark personal deck as soft-deleted
      await (db.update(db.decks)..where((t) => t.id.equals(personalDeck.id))).write(
        const DecksCompanion(isDeleted: Value(true)),
      );

      // 3. Inspect source Explore tables - must remain 100% UNTOUCHED
      final postExploreDeck = await (db.select(db.exploreDecks)
            ..where((t) => t.id.equals(exploreDeckId)))
          .getSingle();
      final postExploreItems = await (db.select(db.exploreDeckItems)
            ..where((t) => t.exploreDeckId.equals(exploreDeckId)))
          .get();

      expect(postExploreDeck.name, equals('Pristine Precon'));
      expect(postExploreDeck.description, equals('Explore deck Pristine Precon description'));
      expect(postExploreDeck.format, equals('Commander'));
      expect(postExploreDeck.isDeleted, isFalse);
      expect(postExploreDeck.cardCount, equals(20));
      expect(postExploreDeck.upvotes, equals(42));
      expect(postExploreDeck.score, equals(42));

      expect(postExploreItems.length, equals(20));
      for (final item in postExploreItems) {
        expect(item.quantity, equals(1));
        expect(item.isDeleted, isFalse);
      }
    });

    test('2.2 Hard deletion of personal deck records leaves explore catalog intact', () async {
      const exploreDeckId = 'explore_hard_delete_test';
      await seedExploreDeck(id: exploreDeckId, name: 'Hard Delete Target', cardCount: 10);

      final personalDeck = await exploreDao.cloneExploreDeckToPersonal(exploreDeckId: exploreDeckId);

      // Hard delete from personal tables
      final versions = await (db.select(db.deckVersions)..where((t) => t.deckId.equals(personalDeck.id))).get();
      for (final v in versions) {
        await (db.delete(db.deckVersionItems)..where((t) => t.versionId.equals(v.id))).go();
      }
      await (db.delete(db.deckVersions)..where((t) => t.deckId.equals(personalDeck.id))).go();
      await (db.delete(db.decks)..where((t) => t.id.equals(personalDeck.id))).go();

      // Ensure explore tables still contain everything
      final exploreDeck = await (db.select(db.exploreDecks)..where((t) => t.id.equals(exploreDeckId))).getSingleOrNull();
      expect(exploreDeck, isNotNull);
      expect(exploreDeck!.name, equals('Hard Delete Target'));

      final exploreItems = await (db.select(db.exploreDeckItems)..where((t) => t.exploreDeckId.equals(exploreDeckId))).get();
      expect(exploreItems.length, equals(10));
    });

    test('2.3 Mutation or deletion of vault items does not corrupt explore deck items', () async {
      const exploreDeckId = 'explore_vault_mutation_test';
      await seedExploreDeck(
        id: exploreDeckId,
        name: 'Vault Mutation Target',
        cardSpecs: [
          {'name': 'Black Lotus', 'scryfall_id': 'scryfall_bl_1', 'quantity': 1, 'price': 50000.0},
          {'name': 'Mox Sapphire', 'scryfall_id': 'scryfall_ms_1', 'quantity': 1, 'price': 3000.0},
        ],
        cardCount: 3,
      );

      final personalDeck = await exploreDao.cloneExploreDeckToPersonal(exploreDeckId: exploreDeckId);

      // Find the vault items created/linked for this cloned deck
      final pVersions = await (db.select(db.deckVersions)..where((t) => t.deckId.equals(personalDeck.id))).get();
      final pItems = await (db.select(db.deckVersionItems)..where((t) => t.versionId.equals(pVersions.first.id))).get();

      final vaultItemIds = pItems.map((i) => i.vaultItemId).toSet();
      expect(vaultItemIds.isNotEmpty, isTrue);

      // Mutate and delete vault items
      for (final vId in vaultItemIds) {
        await (db.update(db.vaultItems)..where((t) => t.id.equals(vId))).write(
          const VaultItemsCompanion(
            name: Value('Ruined Card Name'),
            currentMarketPrice: Value(0.01),
            isDeleted: Value(true),
          ),
        );
      }

      // Check explore deck items
      final expItems = await (db.select(db.exploreDeckItems)..where((t) => t.exploreDeckId.equals(exploreDeckId))).get();
      final cardNames = expItems.map((i) => i.cardName).toSet();

      expect(cardNames.contains('Black Lotus'), isTrue);
      expect(cardNames.contains('Mox Sapphire'), isTrue);
      expect(cardNames.contains('Ruined Card Name'), isFalse);

      final lotus = expItems.firstWhere((i) => i.cardName == 'Black Lotus');
      expect(lotus.price, equals(50000.0));
      expect(lotus.isDeleted, isFalse);
    });
  });

  // ===========================================================================
  // GROUP 3: VAULT AVAILABILITY LEDGER INVARIANT (OWNED = AVAILABLE + ALLOCATED)
  // ===========================================================================
  group('3. Vault Availability Ledger Invariant (Owned = Available + Allocated) Under Stress', () {
    test('3.1 Cloning and deleting draft decks preserves exact ledger invariant without locking physical stock', () async {
      final now = DateTime.now();

      // Seed physical vault card with owned quantity = 4
      const vaultCardId = 'vault_card_sol_ring';
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: vaultCardId,
          collectionType: 'mtg',
          name: 'Sol Ring',
          setOrSeries: 'Commander',
          imageUrl: 'https://cards.scryfall.io/sol_ring.jpg',
          acquiredPrice: 2.0,
          acquiredDate: now,
          quantity: const Value(4), // 4 copies owned physically
          condition: 'NM',
          currentMarketPrice: 2.50,
          lastPriceUpdate: now,
          dynamicData: '{}',
        ),
      );

      // 1. Initial Ledger State
      var availabilityMap = await vaultDao.watchAllCardAvailability().first;
      var avail = availabilityMap[vaultCardId]!;
      expect(avail.owned, equals(4));
      expect(avail.inDeck, equals(0));
      expect(avail.available, equals(4));
      expect(avail.owned, equals(avail.available + avail.inDeck));

      // 2. Seed explore deck containing Sol Ring
      await seedExploreDeck(
        id: 'explore_sol_ring_deck',
        name: 'Sol Ring Precon',
        cardSpecs: [
          {'name': 'Sol Ring', 'scryfall_id': vaultCardId, 'quantity': 1},
        ],
        cardCount: 2,
      );

      // 3. Clone to personal (creates draft deck: isAssembled = false, isRegistered = false)
      final clonedDeck = await exploreDao.cloneExploreDeckToPersonal(
        exploreDeckId: 'explore_sol_ring_deck',
      );

      // Cloned draft deck MUST NOT lock physical stock!
      availabilityMap = await vaultDao.watchAllCardAvailability().first;
      avail = availabilityMap[vaultCardId]!;
      expect(avail.owned, equals(4));
      expect(avail.inDeck, equals(0), reason: 'Draft decks do not allocate physical stock');
      expect(avail.available, equals(4));
      expect(avail.owned, equals(avail.available + avail.inDeck));

      // 4. Soft-delete cloned deck
      await (db.update(db.decks)..where((t) => t.id.equals(clonedDeck.id))).write(
        const DecksCompanion(isDeleted: Value(true)),
      );

      availabilityMap = await vaultDao.watchAllCardAvailability().first;
      avail = availabilityMap[vaultCardId]!;
      expect(avail.owned, equals(4));
      expect(avail.inDeck, equals(0));
      expect(avail.available, equals(4));
      expect(avail.owned, equals(avail.available + avail.inDeck));
    });

    test('3.2 Assembly status changes allocate and release physical stock with exact conservation', () async {
      final now = DateTime.now();

      // Seed physical card: 5 copies owned
      const cardId = 'vault_card_shock_bolt';
      const cardName = 'Challenger Shock Bolt';
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: cardId,
          collectionType: 'mtg',
          name: cardName,
          setOrSeries: 'Challenger M6',
          imageUrl: 'https://cards.scryfall.io/bolt.jpg',
          acquiredPrice: 1.5,
          acquiredDate: now,
          quantity: const Value(5),
          condition: 'NM',
          currentMarketPrice: 2.0,
          lastPriceUpdate: now,
          dynamicData: '{}',
        ),
      );

      // Seed explore deck with 3 copies of Challenger Shock Bolt
      await seedExploreDeck(
        id: 'explore_burn_deck',
        name: 'Burn Precon',
        cardSpecs: [
          {'name': cardName, 'scryfall_id': cardId, 'quantity': 3},
        ],
        cardCount: 4,
      );

      // Clone deck -> draft deck
      final clonedDeck = await exploreDao.cloneExploreDeckToPersonal(
        exploreDeckId: 'explore_burn_deck',
      );

      // Baseline check: not assembled
      var map = await vaultDao.watchAllCardAvailability().first;
      expect(map[cardId]!.owned, equals(5));
      expect(map[cardId]!.inDeck, equals(0));
      expect(map[cardId]!.available, equals(5));

      // 1. Mark Assembled: physical stock locked
      await vaultDao.setDeckAssembled(clonedDeck.id, true);

      map = await vaultDao.watchAllCardAvailability().first;
      var boltAvail = map[cardId]!;
      expect(boltAvail.owned, equals(5));
      expect(boltAvail.inDeck, equals(3), reason: '3 copies allocated in assembled deck');
      expect(boltAvail.available, equals(2), reason: 'Available = 5 - 3 = 2');
      expect(boltAvail.owned, equals(boltAvail.available + boltAvail.inDeck));

      // 2. Mark Disassembled: physical stock returned to available
      await vaultDao.setDeckAssembled(clonedDeck.id, false);

      map = await vaultDao.watchAllCardAvailability().first;
      boltAvail = map[cardId]!;
      expect(boltAvail.owned, equals(5));
      expect(boltAvail.inDeck, equals(0), reason: 'Disassembled deck releases all allocations');
      expect(boltAvail.available, equals(5));
      expect(boltAvail.owned, equals(boltAvail.available + boltAvail.inDeck));
    });

    test('3.3 Proxies never allocate physical stock even when deck is assembled', () async {
      final now = DateTime.now();

      // Seed vault card with quantity 0 (unowned catalog reference)
      const proxyCardId = 'vault_unowned_lotus';
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: proxyCardId,
          collectionType: 'mtg',
          name: 'Black Lotus',
          setOrSeries: 'Vintage',
          imageUrl: 'https://cards.scryfall.io/lotus.jpg',
          acquiredPrice: 0.0,
          acquiredDate: now,
          quantity: const Value(0), // Unowned
          condition: 'NM',
          currentMarketPrice: 25000.0,
          lastPriceUpdate: now,
          dynamicData: '{}',
        ),
      );

      await seedExploreDeck(
        id: 'explore_vintage_deck',
        name: 'Vintage Power',
        cardSpecs: [
          {'name': 'Black Lotus', 'scryfall_id': proxyCardId, 'quantity': 1},
        ],
        cardCount: 2,
      );

      final clonedDeck = await exploreDao.cloneExploreDeckToPersonal(
        exploreDeckId: 'explore_vintage_deck',
      );

      // Verify item in deckVersionItems was marked as proxy because owned < quantity
      final pVersions = await (db.select(db.deckVersions)..where((t) => t.deckId.equals(clonedDeck.id))).get();
      final pItems = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals(pVersions.first.id) & t.vaultItemId.equals(proxyCardId)))
          .get();
      expect(pItems.first.isProxy, isTrue);

      // Assemble deck
      await vaultDao.setDeckAssembled(clonedDeck.id, true);

      // Check ledger: proxy must NEVER allocate stock or cause negative available!
      final map = await vaultDao.watchAllCardAvailability().first;
      final lotusAvail = map[proxyCardId]!;
      expect(lotusAvail.owned, equals(0));
      expect(lotusAvail.inDeck, equals(0), reason: 'Proxies do not allocate physical stock');
      expect(lotusAvail.available, equals(0));
      expect(lotusAvail.available, greaterThanOrEqualTo(0));
      expect(lotusAvail.owned, equals(lotusAvail.available + lotusAvail.inDeck));
    });

    test('3.4 Over-allocation guard: Available is strictly non-negative (>= 0)', () async {
      final now = DateTime.now();

      // User owns only 2 copies of Counterspell
      const cardId = 'vault_card_counterspell';
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: cardId,
          collectionType: 'mtg',
          name: 'Counterspell',
          setOrSeries: 'Tempest',
          imageUrl: 'https://cards.scryfall.io/counterspell.jpg',
          acquiredPrice: 1.0,
          acquiredDate: now,
          quantity: const Value(2), // 2 owned
          condition: 'NM',
          currentMarketPrice: 1.5,
          lastPriceUpdate: now,
          dynamicData: '{}',
        ),
      );

      // Create two independent decks, each allocating 2 copies physically (total 4 allocated)
      final deck1 = await vaultDao.createDeck('Control A', isRegistered: true);
      final v1 = (await (db.select(db.deckVersions)..where((t) => t.deckId.equals(deck1.id))).get()).first;
      await db.into(db.deckVersionItems).insert(
        DeckVersionItemsCompanion.insert(
          id: const Uuid().v4(),
          versionId: v1.id,
          vaultItemId: cardId,
          quantity: const Value(2),
          boardZone: 'Mainboard',
          isProxy: const Value(false),
          isDeleted: const Value(false),
          updatedAt: Value(now),
        ),
      );

      final deck2 = await vaultDao.createDeck('Control B', isRegistered: true);
      final v2 = (await (db.select(db.deckVersions)..where((t) => t.deckId.equals(deck2.id))).get()).first;
      await db.into(db.deckVersionItems).insert(
        DeckVersionItemsCompanion.insert(
          id: const Uuid().v4(),
          versionId: v2.id,
          vaultItemId: cardId,
          quantity: const Value(2),
          boardZone: 'Mainboard',
          isProxy: const Value(false),
          isDeleted: const Value(false),
          updatedAt: Value(now),
        ),
      );

      // Verify availability
      final map = await vaultDao.watchAllCardAvailability().first;
      final csAvail = map[cardId]!;

      expect(csAvail.owned, equals(2));
      expect(csAvail.inDeck, equals(4), reason: 'Total 4 allocated across 2 assembled decks');
      expect(csAvail.available, equals(0), reason: 'Available is clamped to MAX(0, owned - allocated)');
      expect(csAvail.available, greaterThanOrEqualTo(0));
    });

    test('3.5 Sharing personal deck to explore preserves exact vault availability ledger', () async {
      final now = DateTime.now();

      // Seed physical card with 3 copies
      const cardId = 'vault_card_shared_target';
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: cardId,
          collectionType: 'mtg',
          name: 'Birds of Paradise',
          setOrSeries: 'Ravnica',
          imageUrl: 'https://cards.scryfall.io/bop.jpg',
          acquiredPrice: 5.0,
          acquiredDate: now,
          quantity: const Value(3),
          condition: 'NM',
          currentMarketPrice: 7.0,
          lastPriceUpdate: now,
          dynamicData: '{}',
        ),
      );

      // Create assembled personal deck with 2 copies
      final deck = await vaultDao.createDeck('Ramp Deck', isRegistered: true);
      final v = (await (db.select(db.deckVersions)..where((t) => t.deckId.equals(deck.id))).get()).first;
      await db.into(db.deckVersionItems).insert(
        DeckVersionItemsCompanion.insert(
          id: const Uuid().v4(),
          versionId: v.id,
          vaultItemId: cardId,
          quantity: const Value(2),
          boardZone: 'Mainboard',
          isProxy: const Value(false),
          isDeleted: const Value(false),
          updatedAt: Value(now),
        ),
      );

      // Baseline ledger
      var map = await vaultDao.watchAllCardAvailability().first;
      expect(map[cardId]!.owned, equals(3));
      expect(map[cardId]!.inDeck, equals(2));
      expect(map[cardId]!.available, equals(1));
      expect(map[cardId]!.owned, equals(map[cardId]!.available + map[cardId]!.inDeck));

      // Share personal deck to explore
      final sharedExploreDeck = await exploreDao.sharePersonalDeckToExplore(
        personalDeckId: deck.id,
        creatorName: '@NaturePlayer',
      );
      expect(sharedExploreDeck.id, equals('explore_shared_${deck.id}'));

      // Check ledger again: MUST NOT BE MUTATED OR CORRUPTED!
      map = await vaultDao.watchAllCardAvailability().first;
      final postAvail = map[cardId]!;
      expect(postAvail.owned, equals(3));
      expect(postAvail.inDeck, equals(2));
      expect(postAvail.available, equals(1));
      expect(postAvail.owned, equals(postAvail.available + postAvail.inDeck));
    });

    test('3.6 Heavy interleaved async stress on ledger preserves non-negativity and invariants across all emissions', () async {
      final now = DateTime.now();

      // Seed 4 physical cards in vault
      final cardIds = ['stress_card_1', 'stress_card_2', 'stress_card_3', 'stress_card_4'];
      for (var i = 0; i < cardIds.length; i++) {
        await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: cardIds[i],
            collectionType: 'mtg',
            name: 'Stress Card #$i',
            setOrSeries: 'Stress Set',
            imageUrl: 'https://cards.scryfall.io/c_$i.jpg',
            acquiredPrice: 1.0,
            acquiredDate: now,
            quantity: Value(10), // 10 owned each
            condition: 'NM',
            currentMarketPrice: 2.0,
            lastPriceUpdate: now,
            dynamicData: '{}',
          ),
        );
      }

      // Seed 2 explore decks referencing these cards
      await seedExploreDeck(
        id: 'exp_stress_ledger_a',
        name: 'Stress Ledger A',
        cardSpecs: [
          {'name': 'Stress Card #0', 'scryfall_id': 'stress_card_1', 'quantity': 2},
          {'name': 'Stress Card #1', 'scryfall_id': 'stress_card_2', 'quantity': 3},
        ],
        cardCount: 3,
      );

      await seedExploreDeck(
        id: 'exp_stress_ledger_b',
        name: 'Stress Ledger B',
        cardSpecs: [
          {'name': 'Stress Card #2', 'scryfall_id': 'stress_card_3', 'quantity': 4},
          {'name': 'Stress Card #3', 'scryfall_id': 'stress_card_4', 'quantity': 2},
        ],
        cardCount: 3,
      );

      // Record all emissions from watchAllCardAvailability stream
      final emissions = <Map<String, CardAvailability>>[];
      final sub = vaultDao.watchAllCardAvailability().listen((event) {
        emissions.add(event);
      });

      try {
        // Fire 20 rapid async operations concurrently:
        // - Clone explore decks
        // - Toggle assembly status
        // - Soft-delete decks
        final operations = <Future<dynamic>>[];

        // Clone deck A twice and deck B twice
        final cA1 = exploreDao.cloneExploreDeckToPersonal(exploreDeckId: 'exp_stress_ledger_a');
        final cA2 = exploreDao.cloneExploreDeckToPersonal(exploreDeckId: 'exp_stress_ledger_a');
        final cB1 = exploreDao.cloneExploreDeckToPersonal(exploreDeckId: 'exp_stress_ledger_b');
        final cB2 = exploreDao.cloneExploreDeckToPersonal(exploreDeckId: 'exp_stress_ledger_b');

        final clonedDecks = await Future.wait([cA1, cA2, cB1, cB2]);

        for (final cd in clonedDecks) {
          operations.add(vaultDao.setDeckAssembled(cd.id, true));
          operations.add(vaultDao.setDeckAssembled(cd.id, false));
          operations.add(vaultDao.setDeckAssembled(cd.id, true));
        }

        await Future.wait(operations);

        // Allow microtask cycle to flush stream emissions
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(emissions.isNotEmpty, isTrue);

        // Thoroughly audit EVERY single emission and EVERY single card in it
        for (final emission in emissions) {
          for (final entry in emission.entries) {
            final card = entry.value;

            // Invariant 1: Non-negativity
            expect(card.owned, greaterThanOrEqualTo(0), reason: 'Owned cannot be negative');
            expect(card.inDeck, greaterThanOrEqualTo(0), reason: 'InDeck cannot be negative');
            expect(card.available, greaterThanOrEqualTo(0), reason: 'Available cannot be negative');

            // Invariant 2: Conservation
            if (card.inDeck <= card.owned) {
              expect(
                card.owned,
                equals(card.available + card.inDeck),
                reason: 'When inDeck <= owned, Owned must exactly equal Available + InDeck',
              );
            } else {
              expect(card.available, equals(0), reason: 'Over-allocated card has available = 0');
            }
          }
        }
      } finally {
        await sub.cancel();
      }
    });
  });
}
