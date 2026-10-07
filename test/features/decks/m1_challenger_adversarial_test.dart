import 'dart:io';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/domain/models/explore_deck_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('Milestone 1 Challenger: Schema v11 Upgrade & Migration Resilience', () {
    test('Migration v10 -> v11 guards against duplicate is_cloned column in decks table', () async {
      // 1. Setup raw database at version 10 where decks table ALREADY has is_cloned
      final rawDb = NativeDatabase.memory(setup: (raw) {
        raw.execute('PRAGMA user_version = 10;');

        // Simulate legacy decks table that somehow already has is_cloned (e.g. aborted prior migration)
        raw.execute('''
          CREATE TABLE "decks" (
            "id" TEXT NOT NULL PRIMARY KEY,
            "name" TEXT NOT NULL,
            "format" TEXT NOT NULL,
            "description" TEXT,
            "wins" INTEGER NOT NULL DEFAULT 0,
            "losses" INTEGER NOT NULL DEFAULT 0,
            "draws" INTEGER NOT NULL DEFAULT 0,
            "cover_item_id" TEXT,
            "cover_crop_rect" TEXT,
            "created_at" INTEGER NOT NULL,
            "tcg_domain" TEXT NOT NULL DEFAULT 'mtg',
            "is_registered" INTEGER NOT NULL DEFAULT 0,
            "is_competitive" INTEGER NOT NULL DEFAULT 0,
            "is_assembled" INTEGER NOT NULL DEFAULT 0,
            "is_deleted" INTEGER NOT NULL DEFAULT 0,
            "updated_at" INTEGER,
            "is_cloned" INTEGER NOT NULL DEFAULT 1
          );
        ''');

        raw.execute('''
          INSERT INTO "decks" (
            "id", "name", "format", "created_at", "is_cloned"
          ) VALUES (
            'preexisting_deck_1', 'Pre-existing Deck', 'Commander', 1700000000000, 1
          );
        ''');
      });

      // 2. Open via AppDatabase, triggering migration from 10 to 11
      final db = AppDatabase(rawDb);

      try {
        // Query decks table via Drift
        final deck = await (db.select(db.decks)..where((t) => t.id.equals('preexisting_deck_1'))).getSingle();
        expect(deck.id, equals('preexisting_deck_1'));
        expect(deck.name, equals('Pre-existing Deck'));
        expect(deck.isCloned, isTrue); // Preserved pre-existing value
        expect(deck.sourceExploreDeckId, isNull); // New column added cleanly

        // Verify version bumped to 11
        final userVersion = await db.customSelect('PRAGMA user_version;').getSingle();
        expect(userVersion.read<int>('user_version'), equals(11));

        // Verify explore tables exist
        final tables = await db.customSelect("SELECT name FROM sqlite_master WHERE type='table';").get();
        final tableNames = tables.map((t) => t.read<String>('name')).toSet();
        expect(tableNames.contains('explore_decks'), isTrue);
        expect(tableNames.contains('explore_deck_items'), isTrue);
        expect(tableNames.contains('explore_deck_votes'), isTrue);
      } finally {
        await db.close();
      }
    });

    test('Migration v10 -> v11 guards against pre-existing explore_decks table', () async {
      // 1. Setup raw database at version 10 where explore_decks table ALREADY exists
      final rawDb = NativeDatabase.memory(setup: (raw) {
        raw.execute('PRAGMA user_version = 10;');

        raw.execute('''
          CREATE TABLE "decks" (
            "id" TEXT NOT NULL PRIMARY KEY,
            "name" TEXT NOT NULL,
            "format" TEXT NOT NULL,
            "created_at" INTEGER NOT NULL
          );
        ''');

        // explore_decks already exists before migration step
        raw.execute('''
          CREATE TABLE "explore_decks" (
            "id" TEXT NOT NULL PRIMARY KEY,
            "name" TEXT NOT NULL,
            "format" TEXT NOT NULL,
            "created_at" INTEGER NOT NULL
          );
        ''');

        raw.execute('''
          INSERT INTO "explore_decks" ("id", "name", "format", "created_at")
          VALUES ('existing_explore_1', 'Surviving Deck', 'Commander', 1700000000000);
        ''');
      });

      final db = AppDatabase(rawDb);

      try {
        // Migration should execute without crashing on duplicate table
        final exploreDeck = await db.customSelect(
          "SELECT id, name FROM explore_decks WHERE id = 'existing_explore_1';",
        ).getSingle();
        expect(exploreDeck.read<String>('name'), equals('Surviving Deck'));

        final userVersion = await db.customSelect('PRAGMA user_version;').getSingle();
        expect(userVersion.read<int>('user_version'), equals(11));
      } finally {
        await db.close();
      }
    });

    test('Migration from older schema v8 directly to v11 survives all intermediate steps', () async {
      final rawDb = NativeDatabase.memory(setup: (raw) {
        raw.execute('PRAGMA user_version = 8;');

        raw.execute('''
          CREATE TABLE "decks" (
            "id" TEXT NOT NULL PRIMARY KEY,
            "name" TEXT NOT NULL,
            "format" TEXT NOT NULL,
            "description" TEXT,
            "wins" INTEGER NOT NULL DEFAULT 0,
            "losses" INTEGER NOT NULL DEFAULT 0,
            "draws" INTEGER NOT NULL DEFAULT 0,
            "cover_item_id" TEXT,
            "cover_crop_rect" TEXT,
            "created_at" INTEGER NOT NULL,
            "tcg_domain" TEXT NOT NULL DEFAULT 'mtg',
            "is_registered" INTEGER NOT NULL DEFAULT 0,
            "is_competitive" INTEGER NOT NULL DEFAULT 0,
            "is_assembled" INTEGER NOT NULL DEFAULT 0
          );
        ''');

        raw.execute('''
          CREATE TABLE "deck_versions" (
            "id" TEXT NOT NULL PRIMARY KEY,
            "deck_id" TEXT NOT NULL,
            "version_number" INTEGER NOT NULL,
            "label" TEXT NOT NULL,
            "is_active" INTEGER NOT NULL DEFAULT 0,
            "created_at" INTEGER NOT NULL
          );
        ''');

        raw.execute('''
          CREATE TABLE "deck_version_items" (
            "id" TEXT NOT NULL PRIMARY KEY,
            "version_id" TEXT NOT NULL,
            "vault_item_id" TEXT NOT NULL,
            "quantity" INTEGER NOT NULL DEFAULT 1,
            "board_zone" TEXT NOT NULL DEFAULT 'mainboard'
          );
        ''');

        raw.execute('''
          CREATE TABLE "vault_items" (
            "id" TEXT NOT NULL PRIMARY KEY,
            "collection_type" TEXT NOT NULL,
            "name" TEXT NOT NULL,
            "set_or_series" TEXT NOT NULL DEFAULT '',
            "image_url" TEXT NOT NULL DEFAULT '',
            "acquired_price" REAL NOT NULL DEFAULT 0.0,
            "acquired_date" INTEGER NOT NULL DEFAULT 0,
            "quantity" INTEGER NOT NULL DEFAULT 1,
            "condition" TEXT NOT NULL DEFAULT 'NM',
            "is_graded" INTEGER NOT NULL DEFAULT 0,
            "is_altered" INTEGER NOT NULL DEFAULT 0,
            "is_misprint" INTEGER NOT NULL DEFAULT 0,
            "is_signed" INTEGER NOT NULL DEFAULT 0,
            "personal_notes" TEXT,
            "date_obtained" INTEGER,
            "purchase_price" REAL,
            "protection_status" TEXT DEFAULT 'Sleeved',
            "primary_binder_id" TEXT,
            "current_market_price" REAL NOT NULL DEFAULT 0.0,
            "last_price_update" INTEGER NOT NULL DEFAULT 0,
            "dynamic_data" TEXT,
            "is_deleted" INTEGER NOT NULL DEFAULT 0,
            "updated_at" INTEGER
          );
        ''');

        raw.execute('''
          INSERT INTO "decks" ("id", "name", "format", "created_at")
          VALUES ('v8_deck', 'Deck from v8', 'Modern', 1600000000000);
        ''');
      });

      final db = AppDatabase(rawDb);

      try {
        final deck = await (db.select(db.decks)..where((t) => t.id.equals('v8_deck'))).getSingle();
        expect(deck.name, equals('Deck from v8'));
        expect(deck.isCloned, isFalse);
        expect(deck.sourceExploreDeckId, isNull);

        final userVersion = await db.customSelect('PRAGMA user_version;').getSingle();
        expect(userVersion.read<int>('user_version'), equals(11));

        // Check tables created across v9, v10, and v11
        final tables = await db.customSelect("SELECT name FROM sqlite_master WHERE type='table';").get();
        final tableNames = tables.map((t) => t.read<String>('name')).toSet();
        expect(tableNames.contains('sync_queue'), isTrue); // v9
        expect(tableNames.contains('match_sessions'), isTrue); // v10
        expect(tableNames.contains('explore_decks'), isTrue); // v11
        expect(tableNames.contains('explore_deck_items'), isTrue); // v11
        expect(tableNames.contains('explore_deck_votes'), isTrue); // v11
      } finally {
        await db.close();
      }
    });

    test('beforeOpen DDL statements are completely idempotent across repeated connection reopens', () async {
      final tempDir = Directory.systemTemp.createTempSync('drift_idempotent_test_');
      final dbFile = File('${tempDir.path}/idempotent.sqlite');

      try {
        // Open and close 4 times in sequence
        for (var i = 0; i < 4; i++) {
          final db = AppDatabase(NativeDatabase(dbFile));
          final count = await db.exploreDeckDao.getExploreDeckCount();
          expect(count, equals(0));
          await db.close();
        }
      } finally {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      }
    });
  });

  group('Milestone 1 Challenger: Persistent Voting Engine Stress & Concurrency', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());

      final now = DateTime.now();
      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: 'deck_stress_1',
          name: 'Stress Test Deck',
          format: 'Commander',
          tcgDomain: const Value('mtg'),
          sourceType: const Value('community'),
          creatorName: const Value('@Challenger'),
          commanderName: const Value('Adversarial Commander'),
          colorIdentity: const Value('["B","R"]'),
          cardCount: const Value(100),
          estimatedPrice: const Value(150.0),
          upvotes: const Value(0),
          downvotes: const Value(0),
          score: const Value(0),
          createdAt: now,
        ),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('Rapid vote toggling sequence preserves arithmetic exactness and returns to neutral', () async {
      const user = 'user_rapid';

      // 0 -> +1 (Upvote)
      var res = await db.exploreDeckDao.castVote(deckId: 'deck_stress_1', userId: user, targetVote: 1);
      expect(res.newVote, equals(1));
      expect(res.upvotes, equals(1));
      expect(res.downvotes, equals(0));
      expect(res.newScore, equals(1));

      // +1 -> 0 (Toggle off Upvote)
      res = await db.exploreDeckDao.castVote(deckId: 'deck_stress_1', userId: user, targetVote: 1, toggle: true);
      expect(res.newVote, equals(0));
      expect(res.upvotes, equals(0));
      expect(res.downvotes, equals(0));
      expect(res.newScore, equals(0));

      // 0 -> -1 (Downvote)
      res = await db.exploreDeckDao.castVote(deckId: 'deck_stress_1', userId: user, targetVote: -1);
      expect(res.newVote, equals(-1));
      expect(res.upvotes, equals(0));
      expect(res.downvotes, equals(1));
      expect(res.newScore, equals(-1));

      // -1 -> 0 (Toggle off Downvote)
      res = await db.exploreDeckDao.castVote(deckId: 'deck_stress_1', userId: user, targetVote: -1, toggle: true);
      expect(res.newVote, equals(0));
      expect(res.upvotes, equals(0));
      expect(res.downvotes, equals(0));
      expect(res.newScore, equals(0));

      // 0 -> +1 (Upvote again)
      res = await db.exploreDeckDao.castVote(deckId: 'deck_stress_1', userId: user, targetVote: 1);
      expect(res.newVote, equals(1));
      expect(res.upvotes, equals(1));
      expect(res.downvotes, equals(0));
      expect(res.newScore, equals(1));
    });

    test('Polarity inversion (1 -> -1 -> 1) applies exact +/-2 delta without drifting', () async {
      const user = 'user_inversion';

      // 1. Initial Upvote: score 0 -> 1
      var res = await db.exploreDeckDao.castVote(deckId: 'deck_stress_1', userId: user, targetVote: 1);
      expect(res.newVote, equals(1));
      expect(res.newScore, equals(1));

      // 2. Direct switch to Downvote: score 1 -> -1 (deltaScore = -2)
      res = await db.exploreDeckDao.castVote(deckId: 'deck_stress_1', userId: user, targetVote: -1, toggle: false);
      expect(res.newVote, equals(-1));
      expect(res.upvotes, equals(0));
      expect(res.downvotes, equals(1));
      expect(res.newScore, equals(-1));

      // 3. Direct switch back to Upvote: score -1 -> 1 (deltaScore = +2)
      res = await db.exploreDeckDao.castVote(deckId: 'deck_stress_1', userId: user, targetVote: 1, toggle: false);
      expect(res.newVote, equals(1));
      expect(res.upvotes, equals(1));
      expect(res.downvotes, equals(0));
      expect(res.newScore, equals(1));
    });

    test('Underflow guard MAX(0, count) prevents upvotes and downvotes from dropping below zero', () async {
      // In SQLite: upvotes = MAX(0, upvotes + deltaUp).
      // Even if user vote was corrupted or deltaUp is negative on zero upvotes,
      // it must clamp at 0.
      const user = 'user_underflow';

      // Cast downvote from 0
      final res = await db.exploreDeckDao.castVote(deckId: 'deck_stress_1', userId: user, targetVote: -1);
      expect(res.upvotes, equals(0));
      expect(res.downvotes, equals(1));
      expect(res.newScore, equals(-1));

      final deck = await db.exploreDeckDao.getExploreDeck('deck_stress_1', userId: user);
      expect(deck!.deck.upvotes, greaterThanOrEqualTo(0));
      expect(deck.deck.downvotes, equals(1));
    });

    test('50 concurrent users voting simultaneously on a single deck maintain strict serial consistency', () async {
      // 30 upvoters, 20 downvoters launched concurrently
      final futures = <Future<VoteResult>>[];

      for (var i = 1; i <= 30; i++) {
        futures.add(db.exploreDeckDao.castVote(
          deckId: 'deck_stress_1',
          userId: 'concurrent_up_$i',
          targetVote: 1,
        ));
      }

      for (var j = 1; j <= 20; j++) {
        futures.add(db.exploreDeckDao.castVote(
          deckId: 'deck_stress_1',
          userId: 'concurrent_down_$j',
          targetVote: -1,
        ));
      }

      await Future.wait(futures);

      // Verify the final state on deck
      final deck = await db.exploreDeckDao.getExploreDeck('deck_stress_1');
      expect(deck, isNotNull);
      expect(deck!.deck.upvotes, equals(30));
      expect(deck.deck.downvotes, equals(20));
      expect(deck.deck.score, equals(10)); // 30 - 20 = 10

      // Verify total vote rows in explore_deck_votes table
      final voteRows = await db.customSelect(
        "SELECT COUNT(*) AS c FROM explore_deck_votes WHERE explore_deck_id = 'deck_stress_1';",
      ).getSingle();
      expect(voteRows.read<int>('c'), equals(50));
    });

    test('Concurrent mass untoggle by 30 upvoters accurately zeroes out upvotes', () async {
      // 1. First have 30 upvoters vote
      final upFutures = <Future>[];
      for (var i = 1; i <= 30; i++) {
        upFutures.add(db.exploreDeckDao.castVote(
          deckId: 'deck_stress_1',
          userId: 'mass_user_$i',
          targetVote: 1,
        ));
      }
      await Future.wait(upFutures);

      var deck = await db.exploreDeckDao.getExploreDeck('deck_stress_1');
      expect(deck!.deck.upvotes, equals(30));
      expect(deck.deck.score, equals(30));

      // 2. Concurrently untoggle all 30
      final untoggleFutures = <Future>[];
      for (var i = 1; i <= 30; i++) {
        untoggleFutures.add(db.exploreDeckDao.castVote(
          deckId: 'deck_stress_1',
          userId: 'mass_user_$i',
          targetVote: 1,
          toggle: true,
        ));
      }
      await Future.wait(untoggleFutures);

      deck = await db.exploreDeckDao.getExploreDeck('deck_stress_1');
      expect(deck!.deck.upvotes, equals(0));
      expect(deck.deck.score, equals(0));
    });

    test('Concurrent voting across multiple distinct decks operates without locks or interference', () async {
      final now = DateTime.now();

      // Insert 4 additional decks
      for (var d = 2; d <= 5; d++) {
        await db.into(db.exploreDecks).insert(
          ExploreDecksCompanion.insert(
            id: 'deck_stress_$d',
            name: 'Stress Test Deck $d',
            format: 'Commander',
            score: const Value(0),
            createdAt: now,
          ),
        );
      }

      // 5 decks, 10 votes each in parallel (50 operations total)
      final crossDeckFutures = <Future>[];
      for (var d = 1; d <= 5; d++) {
        for (var u = 1; u <= 10; u++) {
          final isUp = (u % 2 == 1);
          crossDeckFutures.add(db.exploreDeckDao.castVote(
            deckId: 'deck_stress_$d',
            userId: 'cross_user_${d}_$u',
            targetVote: isUp ? 1 : -1,
          ));
        }
      }

      await Future.wait(crossDeckFutures);

      // Each deck should have 5 upvotes, 5 downvotes, score = 0
      for (var d = 1; d <= 5; d++) {
        final deck = await db.exploreDeckDao.getExploreDeck('deck_stress_$d');
        expect(deck, isNotNull);
        expect(deck!.deck.upvotes, equals(5));
        expect(deck.deck.downvotes, equals(5));
        expect(deck.deck.score, equals(0));
      }
    });

    test('Voting on non-existent deck ID safely throws without database corruption', () async {
      expect(
        () async => await db.exploreDeckDao.castVote(
          deckId: 'non_existent_deck_9999',
          userId: 'user_err',
          targetVote: 1,
        ),
        throwsA(anyOf(
          isA<Exception>(),
          isA<StateError>(),
        )),
      );

      // Verify original deck remains intact
      final deck = await db.exploreDeckDao.getExploreDeck('deck_stress_1');
      expect(deck, isNotNull);
      expect(deck!.deck.score, equals(0));
    });

    test('Disk persistence across physical database close and reopen preserves vote states and tallies', () async {
      final tempDir = Directory.systemTemp.createTempSync('drift_persistence_stress_');
      final dbFile = File('${tempDir.path}/persistence_deck.sqlite');

      try {
        // 1. Initial Connection: create and vote
        var diskDb = AppDatabase(NativeDatabase(dbFile));

        final now = DateTime.now();
        await diskDb.into(diskDb.exploreDecks).insert(
          ExploreDecksCompanion.insert(
            id: 'disk_deck_alpha',
            name: 'Disk Persistence Deck',
            format: 'Commander',
            createdAt: now,
          ),
        );

        // Cast votes from two distinct users
        await diskDb.exploreDeckDao.castVote(
          deckId: 'disk_deck_alpha',
          userId: 'disk_user_1',
          targetVote: 1,
        );
        await diskDb.exploreDeckDao.castVote(
          deckId: 'disk_deck_alpha',
          userId: 'disk_user_2',
          targetVote: -1,
        );

        var deck = await diskDb.exploreDeckDao.getExploreDeck('disk_deck_alpha');
        expect(deck!.deck.upvotes, equals(1));
        expect(deck.deck.downvotes, equals(1));
        expect(deck.deck.score, equals(0));

        // 2. Terminate connection
        await diskDb.close();

        // 3. Re-open NEW AppDatabase instance pointing to the SAME SQLite file
        diskDb = AppDatabase(NativeDatabase(dbFile));

        // Check user 1's vote
        final deckUser1 = await diskDb.exploreDeckDao.getExploreDeck('disk_deck_alpha', userId: 'disk_user_1');
        expect(deckUser1, isNotNull);
        expect(deckUser1!.userVote, equals(1));
        expect(deckUser1.deck.upvotes, equals(1));
        expect(deckUser1.deck.downvotes, equals(1));
        expect(deckUser1.deck.score, equals(0));

        // Check user 2's vote
        final deckUser2 = await diskDb.exploreDeckDao.getExploreDeck('disk_deck_alpha', userId: 'disk_user_2');
        expect(deckUser2, isNotNull);
        expect(deckUser2!.userVote, equals(-1));

        // Untoggle user 1's vote on the reopened database
        final untoggleRes = await diskDb.exploreDeckDao.castVote(
          deckId: 'disk_deck_alpha',
          userId: 'disk_user_1',
          targetVote: 1,
          toggle: true,
        );
        expect(untoggleRes.newVote, equals(0));
        expect(untoggleRes.upvotes, equals(0));
        expect(untoggleRes.downvotes, equals(1));
        expect(untoggleRes.newScore, equals(-1));

        await diskDb.close();
      } finally {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      }
    });
  });

  group('Milestone 1 Challenger: Edge Cases, Extremes & Adversarial Search', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());

      final now = DateTime.now();

      // Insert decks spanning negative scores, zero scores, and price extremes
      final testDecks = [
        ExploreDecksCompanion.insert(
          id: 'deck_negative_50',
          name: 'Reviled Deck',
          format: 'Modern',
          score: const Value(-50),
          estimatedPrice: const Value(500.0),
          creatorName: const Value('@Villain'),
          createdAt: now.subtract(const Duration(days: 5)),
        ),
        ExploreDecksCompanion.insert(
          id: 'deck_negative_3',
          name: 'Mediocre Deck',
          format: 'Standard',
          score: const Value(-3),
          estimatedPrice: const Value(120.0),
          creatorName: const Value('@Casual'),
          createdAt: now.subtract(const Duration(days: 4)),
        ),
        ExploreDecksCompanion.insert(
          id: 'deck_zero_score',
          name: 'Zero Score Deck',
          format: 'Commander',
          score: const Value(0),
          estimatedPrice: const Value(0.0), // $0.00 extreme
          creatorName: const Value('@PennyPincher'),
          createdAt: now.subtract(const Duration(days: 3)),
        ),
        ExploreDecksCompanion.insert(
          id: 'deck_positive_10',
          name: 'Popular Deck',
          format: 'Commander',
          score: const Value(10),
          estimatedPrice: const Value(250.0),
          creatorName: const Value('@SpicyBrewMaster'),
          createdAt: now.subtract(const Duration(days: 2)),
        ),
        ExploreDecksCompanion.insert(
          id: 'deck_vintage_whale',
          name: 'Vintage Power Nine Whale',
          format: 'Vintage',
          score: const Value(150),
          estimatedPrice: const Value(18500.0), // $18,500.00 extreme
          creatorName: const Value('@CollectorSupreme'),
          commanderName: const Value('Urza, Lord High Artificer'),
          colorIdentity: const Value('["U"]'),
          createdAt: now.subtract(const Duration(days: 1)),
        ),
      ];

      for (final deck in testDecks) {
        await db.into(db.exploreDecks).insert(deck);
      }

      // Add a card item to deck_vintage_whale
      await db.into(db.exploreDeckItems).insert(
        ExploreDeckItemsCompanion.insert(
          id: 'item_black_lotus',
          exploreDeckId: 'deck_vintage_whale',
          cardName: 'Black Lotus',
          quantity: const Value(1),
          price: const Value(10000.0),
        ),
      );

      // Add card item with apostrophe and emoji to deck_positive_10
      await db.into(db.exploreDeckItems).insert(
        ExploreDeckItemsCompanion.insert(
          id: 'item_special_card',
          exploreDeckId: 'deck_positive_10',
          cardName: "Gaea's Cradle 🔥",
          quantity: const Value(1),
          price: const Value(900.0),
        ),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('Popularity sort correctly orders positive, zero, and negative scores descending', () async {
      final feed = await db.exploreDeckDao.watchExploreDecks(
        sort: ExploreSortOption.popularity,
      ).first;

      final scores = feed.map((d) => d.score).toList();
      expect(scores, equals([150, 10, 0, -3, -50]));
    });

    test(r'Extreme price filtering: $0.00 in budget_0_50 and $18,500.00 in high_200_plus', () async {
      // 1. Budget 0-50 filter
      final budgetDecks = await db.exploreDeckDao.watchExploreDecks(
        filter: const ExploreFilterState(priceRange: 'budget_0_50'),
      ).first;
      expect(budgetDecks.length, equals(1));
      expect(budgetDecks.first.id, equals('deck_zero_score'));
      expect(budgetDecks.first.estimatedPrice, equals(0.0));

      // 2. High 200+ filter
      final highDecks = await db.exploreDeckDao.watchExploreDecks(
        filter: const ExploreFilterState(priceRange: 'high_200_plus'),
      ).first;
      final highIds = highDecks.map((d) => d.id).toSet();
      expect(highIds.contains('deck_vintage_whale'), isTrue);
      expect(highIds.contains('deck_positive_10'), isTrue);
      expect(highIds.contains('deck_negative_50'), isTrue);
      expect(highIds.contains('deck_zero_score'), isFalse);

      // 3. Price Low-to-High sort
      final lowToHigh = await db.exploreDeckDao.watchExploreDecks(
        sort: ExploreSortOption.priceLowToHigh,
      ).first;
      expect(lowToHigh.first.estimatedPrice, equals(0.0));
      expect(lowToHigh.last.estimatedPrice, equals(18500.0));

      // 4. Price High-to-Low sort
      final highToLow = await db.exploreDeckDao.watchExploreDecks(
        sort: ExploreSortOption.priceHighToLow,
      ).first;
      expect(highToLow.first.estimatedPrice, equals(18500.0));
      expect(highToLow.last.estimatedPrice, equals(0.0));
    });

    test('Adversarial SQL injection queries execute safely via parameterized statements without table corruption', () async {
      final injectionStrings = [
        "' OR '1'='1",
        "'; DROP TABLE explore_decks; --",
        "' UNION SELECT * FROM decks --",
        "admin'--",
        "''''''''",
        "' OR 1=1; --",
      ];

      for (final injection in injectionStrings) {
        // Test searchExploreDecks
        final searchResult = await db.exploreDeckDao.searchExploreDecks(query: injection);
        // Parameterized matching ensures these literal string queries return 0 rows
        expect(searchResult.inDeckName.isEmpty, isTrue);

        // Test watchExploreDecks
        final feedResult = await db.exploreDeckDao.watchExploreDecks(searchQuery: injection).first;
        expect(feedResult.isEmpty, isTrue);

        // Verify explore_decks table was NOT dropped
        final count = await db.exploreDeckDao.getExploreDeckCount();
        expect(count, equals(5));
      }
    });

    test('Unusual characters, emojis, apostrophes, and wildcard characters search accurately across tiers', () async {
      // 1. Search for card with apostrophe: "Gaea's"
      final gaeasResult = await db.exploreDeckDao.searchExploreDecks(query: "Gaea's");
      expect(gaeasResult.inDeckCards.isNotEmpty, isTrue);
      expect(gaeasResult.inDeckCards.first.deckWithVote.id, equals('deck_positive_10'));
      expect(gaeasResult.inDeckCards.first.matchingCardName, contains("Gaea's"));

      // 2. Search for emoji: "🔥"
      final emojiResult = await db.exploreDeckDao.searchExploreDecks(query: '🔥');
      expect(emojiResult.inDeckCards.isNotEmpty, isTrue);
      expect(emojiResult.inDeckCards.first.matchingCardName, contains('🔥'));

      // 3. Search for card in deck: "Black Lotus"
      final lotusResult = await db.exploreDeckDao.searchExploreDecks(query: 'Black Lotus');
      expect(lotusResult.inDeckCards.isNotEmpty, isTrue);
      expect(lotusResult.inDeckCards.first.deckWithVote.id, equals('deck_vintage_whale'));

      // 4. Search by username: "@Villain"
      final userResult = await db.exploreDeckDao.searchExploreDecks(query: '@Villain');
      expect(userResult.byUsername.isNotEmpty, isTrue);
      expect(userResult.byUsername.first.id, equals('deck_negative_50'));

      // 5. Search with SQLite wildcard characters ("%" and "_") executes without syntax errors
      final wildcardPercent = await db.exploreDeckDao.searchExploreDecks(query: '%');
      expect(wildcardPercent, isNotNull);

      final wildcardUnderscore = await db.exploreDeckDao.searchExploreDecks(query: '_');
      expect(wildcardUnderscore, isNotNull);
    });

    test('Complex feed query combining format, commander, price range, colors, and pagination executes seamlessly', () async {
      final results = await db.exploreDeckDao.watchExploreDecks(
        category: ExploreCategory.all,
        sort: ExploreSortOption.popularity,
        filter: const ExploreFilterState(
          format: 'Vintage',
          priceRange: 'high_200_plus',
          commanderName: 'Urza',
          colors: ['U'],
          colorMatchMode: 'including',
        ),
        searchQuery: 'Whale',
        limit: 10,
        offset: 0,
      ).first;

      expect(results.length, equals(1));
      expect(results.first.id, equals('deck_vintage_whale'));
      expect(results.first.estimatedPrice, equals(18500.0));
      expect(results.first.score, equals(150));
    });
  });
}
