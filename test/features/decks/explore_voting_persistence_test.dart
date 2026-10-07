import 'dart:io';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/core/database/app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());

    // Insert a test explore deck
    final now = DateTime.now();
    await db.into(db.exploreDecks).insert(
      ExploreDecksCompanion.insert(
        id: 'deck_test_vote_1',
        name: 'Voting Test Deck',
        format: 'Commander',
        tcgDomain: const Value('mtg'),
        sourceType: const Value('community'),
        creatorName: const Value('@VoteTester'),
        commanderName: const Value('Voting Commander'),
        colorIdentity: const Value('["W","U"]'),
        cardCount: const Value(100),
        estimatedPrice: const Value(85.0),
        upvotes: const Value(10),
        downvotes: const Value(2),
        score: const Value(8),
        createdAt: now,
        updatedAt: Value(now),
        isDeleted: const Value(false),
      ),
    );

    // Insert commander card item
    await db.into(db.exploreDeckItems).insert(
      ExploreDeckItemsCompanion.insert(
        id: 'item_commander_1',
        exploreDeckId: 'deck_test_vote_1',
        cardName: 'Voting Commander',
        boardZone: const Value('Commander'),
        isCommander: const Value(true),
        quantity: const Value(1),
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('Explore Voting Persistence & Atomic Mechanics Tests', () {
    test('User casts upvote from neutral state', () async {
      final result = await db.exploreDeckDao.castVote(
        deckId: 'deck_test_vote_1',
        userId: 'user_alice',
        targetVote: 1,
        toggle: true,
      );

      expect(result.newVote, equals(1));
      expect(result.upvotes, equals(11));
      expect(result.downvotes, equals(2));
      expect(result.newScore, equals(9));

      // Verify in explore_decks table
      final deck = await db.exploreDeckDao.getExploreDeck(
        'deck_test_vote_1',
        userId: 'user_alice',
      );
      expect(deck, isNotNull);
      expect(deck!.userVote, equals(1));
      expect(deck.deck.upvotes, equals(11));
      expect(deck.deck.downvotes, equals(2));
      expect(deck.deck.score, equals(9));
    });

    test('User toggles upvote back to neutral (toggle: true)', () async {
      // 1. Initial upvote
      await db.exploreDeckDao.castVote(
        deckId: 'deck_test_vote_1',
        userId: 'user_alice',
        targetVote: 1,
      );

      // 2. Toggle off
      final toggleResult = await db.exploreDeckDao.castVote(
        deckId: 'deck_test_vote_1',
        userId: 'user_alice',
        targetVote: 1,
        toggle: true,
      );

      expect(toggleResult.newVote, equals(0));
      expect(toggleResult.upvotes, equals(10));
      expect(toggleResult.downvotes, equals(2));
      expect(toggleResult.newScore, equals(8));

      final deck = await db.exploreDeckDao.getExploreDeck(
        'deck_test_vote_1',
        userId: 'user_alice',
      );
      expect(deck!.userVote, equals(0));
      expect(deck.deck.score, equals(8));
    });

    test('User casts downvote from neutral state and toggles off', () async {
      // 1. Downvote
      final downResult = await db.exploreDeckDao.castVote(
        deckId: 'deck_test_vote_1',
        userId: 'user_bob',
        targetVote: -1,
      );

      expect(downResult.newVote, equals(-1));
      expect(downResult.upvotes, equals(10));
      expect(downResult.downvotes, equals(3));
      expect(downResult.newScore, equals(7));

      // 2. Toggle downvote off
      final toggleDown = await db.exploreDeckDao.castVote(
        deckId: 'deck_test_vote_1',
        userId: 'user_bob',
        targetVote: -1,
        toggle: true,
      );

      expect(toggleDown.newVote, equals(0));
      expect(toggleDown.upvotes, equals(10));
      expect(toggleDown.downvotes, equals(2));
      expect(toggleDown.newScore, equals(8));
    });

    test('User flips vote directly from Upvote (+1) to Downvote (-1)', () async {
      // 1. Upvote first
      await db.exploreDeckDao.castVote(
        deckId: 'deck_test_vote_1',
        userId: 'user_charlie',
        targetVote: 1,
      );

      // 2. Flip directly to downvote
      final flipResult = await db.exploreDeckDao.castVote(
        deckId: 'deck_test_vote_1',
        userId: 'user_charlie',
        targetVote: -1,
      );

      // Delta: upvotes -1, downvotes +1, score -2
      expect(flipResult.newVote, equals(-1));
      expect(flipResult.upvotes, equals(10));
      expect(flipResult.downvotes, equals(3));
      expect(flipResult.newScore, equals(7)); // 9 - 2 = 7

      final deck = await db.exploreDeckDao.getExploreDeck(
        'deck_test_vote_1',
        userId: 'user_charlie',
      );
      expect(deck!.userVote, equals(-1));
      expect(deck.deck.score, equals(7));
    });

    test('User flips vote directly from Downvote (-1) to Upvote (+1)', () async {
      // 1. Downvote first
      await db.exploreDeckDao.castVote(
        deckId: 'deck_test_vote_1',
        userId: 'user_dan',
        targetVote: -1,
      );

      // 2. Flip to upvote
      final flipResult = await db.exploreDeckDao.castVote(
        deckId: 'deck_test_vote_1',
        userId: 'user_dan',
        targetVote: 1,
      );

      // Delta: upvotes +1, downvotes -1, score +2
      expect(flipResult.newVote, equals(1));
      expect(flipResult.upvotes, equals(11));
      expect(flipResult.downvotes, equals(2));
      expect(flipResult.newScore, equals(9)); // 7 + 2 = 9
    });

    test('Multiple independent users voting computes aggregate score correctly', () async {
      // Alice upvotes (+1)
      await db.exploreDeckDao.castVote(
        deckId: 'deck_test_vote_1',
        userId: 'alice',
        targetVote: 1,
      );
      // Bob upvotes (+1)
      await db.exploreDeckDao.castVote(
        deckId: 'deck_test_vote_1',
        userId: 'bob',
        targetVote: 1,
      );
      // Charlie downvotes (-1)
      await db.exploreDeckDao.castVote(
        deckId: 'deck_test_vote_1',
        userId: 'charlie',
        targetVote: -1,
      );

      // Initial was: up 10, down 2, score 8
      // Alice: up +1 (11, 2, 9)
      // Bob: up +1 (12, 2, 10)
      // Charlie: down +1 (12, 3, 9)
      final aliceView = await db.exploreDeckDao.getExploreDeck('deck_test_vote_1', userId: 'alice');
      final bobView = await db.exploreDeckDao.getExploreDeck('deck_test_vote_1', userId: 'bob');
      final charlieView = await db.exploreDeckDao.getExploreDeck('deck_test_vote_1', userId: 'charlie');
      final strangerView = await db.exploreDeckDao.getExploreDeck('deck_test_vote_1', userId: 'stranger');

      expect(aliceView!.userVote, equals(1));
      expect(aliceView.deck.score, equals(9));
      expect(aliceView.deck.upvotes, equals(12));
      expect(aliceView.deck.downvotes, equals(3));

      expect(bobView!.userVote, equals(1));
      expect(charlieView!.userVote, equals(-1));
      expect(strangerView!.userVote, equals(0));
    });

    test('Vote persists in SQLite disk database across database reload', () async {
      final tempDir = await Directory.systemTemp.createTemp('countr_vote_test_');
      final dbPath = '${tempDir.path}/test_vote.sqlite';

      try {
        // Session 1: Create disk DB, insert deck, and vote
        final db1 = AppDatabase(NativeDatabase(File(dbPath)));
        final now = DateTime.now();

        await db1.into(db1.exploreDecks).insert(
          ExploreDecksCompanion.insert(
            id: 'disk_deck_1',
            name: 'Disk Persistence Deck',
            format: 'Standard',
            score: const Value(5),
            upvotes: const Value(5),
            downvotes: const Value(0),
            createdAt: now,
          ),
        );

        final vResult = await db1.exploreDeckDao.castVote(
          deckId: 'disk_deck_1',
          userId: 'local_user',
          targetVote: 1,
        );
        expect(vResult.newScore, equals(6));
        expect(vResult.upvotes, equals(6));

        await db1.close();

        // Session 2: Reopen same SQLite file with new AppDatabase instance
        final db2 = AppDatabase(NativeDatabase(File(dbPath)));

        final reloaded = await db2.exploreDeckDao.getExploreDeck(
          'disk_deck_1',
          userId: 'local_user',
        );
        expect(reloaded, isNotNull);
        expect(reloaded!.userVote, equals(1),
            reason: 'User vote must be preserved across SQLite connections');
        expect(reloaded.deck.score, equals(6));
        expect(reloaded.deck.upvotes, equals(6));

        // Another user on DB 2 sees score 6 but userVote 0
        final user2View = await db2.exploreDeckDao.getExploreDeck(
          'disk_deck_1',
          userId: 'other_user',
        );
        expect(user2View!.userVote, equals(0));
        expect(user2View.deck.score, equals(6));

        await db2.close();
      } finally {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      }
    });

    test('Reactive stream watchExploreDeck emits updated state on vote', () async {
      final stream = db.exploreDeckDao.watchExploreDeck(
        'deck_test_vote_1',
        userId: 'stream_user',
      );

      final expectations = expectLater(
        stream.map((d) => (d?.userVote, d?.deck.score)),
        emitsInOrder([
          (0, 8), // initial state
          (1, 9), // after upvote
          (0, 8), // after toggle off
        ]),
      );

      // Trigger first vote
      await Future.delayed(const Duration(milliseconds: 10));
      await db.exploreDeckDao.castVote(
        deckId: 'deck_test_vote_1',
        userId: 'stream_user',
        targetVote: 1,
      );

      // Trigger toggle off
      await Future.delayed(const Duration(milliseconds: 10));
      await db.exploreDeckDao.castVote(
        deckId: 'deck_test_vote_1',
        userId: 'stream_user',
        targetVote: 1,
      );

      await expectations;
    });

    test('cloneExploreDeckToPersonal copies deck with lineage and active version', () async {
      final clonedDeck = await db.exploreDeckDao.cloneExploreDeckToPersonal(
        exploreDeckId: 'deck_test_vote_1',
      );

      expect(clonedDeck.name, equals('Voting Test Deck (Copy)'));
      expect(clonedDeck.format, equals('Commander'));
      expect(clonedDeck.isCloned, isTrue);
      expect(clonedDeck.sourceExploreDeckId, equals('deck_test_vote_1'));

      // Verify active deck version was created
      final versions = await (db.select(db.deckVersions)
            ..where((t) => t.deckId.equals(clonedDeck.id)))
          .get();
      expect(versions.length, equals(1));
      expect(versions.first.versionNumber, equals(1));
      expect(versions.first.isActive, isTrue);

      // Verify deck_version_items and vault_items synthesized
      final versionItems = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals(versions.first.id)))
          .get();
      expect(versionItems.length, equals(1));
      expect(versionItems.first.boardZone, equals('Commander'));
      expect(versionItems.first.isProxy, isTrue,
          reason: 'Unowned card in vault should be marked as proxy');
    });
  });
}
