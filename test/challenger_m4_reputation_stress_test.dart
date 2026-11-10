// Copyright (c) 2026 Countr. All rights reserved.
// Empirical Challenger stress test suite for Milestone 4 (Vault AppBar Relocation & Card Reputation)
// Challenger: challenger_m4_r1_1

import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/data/daos/card_reputation_dao.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late CardReputationDao reputationDao;
  late VaultDao vaultDao;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    reputationDao = db.cardReputationDao;
    vaultDao = db.vaultDao;
    await vaultDao.clearAllItems();
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> seedVaultCard({
    required String id,
    required String name,
    int initialScore = 0,
    int initialUpvotes = 0,
    int initialDownvotes = 0,
    double marketPrice = 10.0,
  }) async {
    await db.into(db.vaultItems).insert(
      VaultItemsCompanion.insert(
        id: id,
        collectionType: 'mtg',
        name: name,
        setOrSeries: 'TEST',
        imageUrl: 'https://example.com/$id.png',
        acquiredPrice: 5.0,
        acquiredDate: DateTime.now(),
        quantity: const drift.Value(1),
        condition: 'Near Mint',
        currentMarketPrice: marketPrice,
        lastPriceUpdate: DateTime.now(),
        dynamicData: jsonEncode({
          'reputation_score': initialScore,
          'upvotes': initialUpvotes,
          'downvotes': initialDownvotes,
        }),
        reputationScore: drift.Value(initialScore),
        upvotes: drift.Value(initialUpvotes),
        downvotes: drift.Value(initialDownvotes),
      ),
    );
  }

  // =========================================================================
  // GROUP 1: CardReputationDao Concurrency & High-Volume Voting Stress
  // =========================================================================
  group('1. CardReputationDao Concurrency & High-Volume Voting Stress', () {
    test('1.1 50 concurrent distinct users voting simultaneously maintains net score integrity', () async {
      const cardId = 'card_stress_concurrency_50';
      await seedVaultCard(id: cardId, name: 'Force of Will');

      // 30 users upvote (+1), 20 users downvote (-1) concurrently via Future.wait
      final futures = <Future<CardVoteResult>>[];

      for (int i = 1; i <= 30; i++) {
        futures.add(
          reputationDao.castVote(
            cardId: cardId,
            userId: 'user_up_$i',
            targetVote: 1,
          ),
        );
      }
      for (int i = 1; i <= 20; i++) {
        futures.add(
          reputationDao.castVote(
            cardId: cardId,
            userId: 'user_down_$i',
            targetVote: -1,
          ),
        );
      }

      final results = await Future.wait(futures);
      expect(results.length, equals(50));

      // Inspect final card state in vault_items
      final summary = await reputationDao.getReputationScore(cardId);
      expect(summary.upvotes, equals(30), reason: 'All 30 upvotes must be tallied');
      expect(summary.downvotes, equals(20), reason: 'All 20 downvotes must be tallied');
      expect(summary.score, equals(10), reason: 'Net score must be 30 - 20 = 10');
      expect(summary.upvotes - summary.downvotes, equals(summary.score),
          reason: 'Mathematical integrity: upvotes - downvotes == score');

      // Inspect votes in card_reputation_votes table
      final allVotes = await (db.select(db.cardReputationVotes)
            ..where((t) => t.cardId.equals(cardId)))
          .get();
      expect(allVotes.length, equals(50));

      final upCount = allVotes.where((v) => v.vote == 1).length;
      final downCount = allVotes.where((v) => v.vote == -1).length;
      expect(upCount, equals(30));
      expect(downCount, equals(20));
    });

    test('1.2 High-volume multi-user toggle and reversal stress', () async {
      const cardId = 'card_stress_reversal';
      await seedVaultCard(id: cardId, name: 'Mox Diamond');

      // Phase 1: 40 users vote (20 upvote, 20 downvote)
      final phase1 = <Future<CardVoteResult>>[];
      for (int i = 1; i <= 20; i++) {
        phase1.add(reputationDao.castVote(cardId: cardId, userId: 'u_up_$i', targetVote: 1));
      }
      for (int i = 1; i <= 20; i++) {
        phase1.add(reputationDao.castVote(cardId: cardId, userId: 'u_down_$i', targetVote: -1));
      }
      await Future.wait(phase1);

      var summary = await reputationDao.getReputationScore(cardId);
      expect(summary.upvotes, equals(20));
      expect(summary.downvotes, equals(20));
      expect(summary.score, equals(0));
      expect(summary.upvotes - summary.downvotes, equals(summary.score));

      // Phase 2: Concurrent mutations
      // - 10 of the 20 upvoters toggle to neutral (0)
      // - 10 of the 20 downvoters switch to upvote (+1)
      final phase2 = <Future<CardVoteResult>>[];
      for (int i = 1; i <= 10; i++) {
        phase2.add(reputationDao.castVote(
          cardId: cardId,
          userId: 'u_up_$i',
          targetVote: 1,
          toggle: true,
        ));
      }
      for (int i = 1; i <= 10; i++) {
        phase2.add(reputationDao.castVote(
          cardId: cardId,
          userId: 'u_down_$i',
          targetVote: 1,
          toggle: true,
        ));
      }
      await Future.wait(phase2);

      // Calculation:
      // Upvoters: 10 unchanged + 10 switched from downvote = 20 upvotes
      // Downvoters: 10 unchanged = 10 downvotes
      // Neutral: 10 toggled off
      // Total score: 20 - 10 = 10
      summary = await reputationDao.getReputationScore(cardId);
      expect(summary.upvotes, equals(20), reason: '10 original + 10 flipped downvoters');
      expect(summary.downvotes, equals(10), reason: '10 downvoters remained');
      expect(summary.score, equals(10), reason: '20 - 10 = 10');
      expect(summary.upvotes - summary.downvotes, equals(summary.score));
    });

    test('1.3 Rapid alternating votes by single user sequentially executes without deadlock', () async {
      const cardId = 'card_single_user_rapid';
      await seedVaultCard(id: cardId, name: 'Lightning Bolt');

      const userId = 'rapid_user_1';
      // Rapid sequence of 25 vote actions
      // Sequence: up, up (toggle off), down, down (toggle off), up, down (flip), up (flip)...
      final sequence = [
        1, 1, // +1 then toggle to 0
        -1, -1, // -1 then toggle to 0
        1, -1, // +1 then flip to -1
        1, -1, // +1 then flip to -1
        1, 1, // +1 then toggle to 0
        -1, 1, // -1 then flip to 1
        1, // toggle to 0
        1, // +1
      ];

      for (final target in sequence) {
        await reputationDao.castVote(
          cardId: cardId,
          userId: userId,
          targetVote: target,
          toggle: true,
        );
      }

      final summary = await reputationDao.getReputationScore(cardId, userId: userId);
      // Final target in sequence is upvote (+1) after toggling to 0
      expect(summary.userVote, equals(1));
      expect(summary.score, equals(1));
      expect(summary.upvotes, equals(1));
      expect(summary.downvotes, equals(0));
      expect(summary.upvotes - summary.downvotes, equals(summary.score));
    });

    test('1.4 Multi-card concurrent voting across 10 cards and 20 users (200 ops)', () async {
      final cardIds = List.generate(10, (i) => 'card_multi_$i');
      for (final id in cardIds) {
        await seedVaultCard(id: id, name: 'Card $id');
      }

      // 20 users vote on all 10 cards concurrently
      // Even index users upvote (+1), odd index users downvote (-1)
      final allFutures = <Future<CardVoteResult>>[];
      for (int u = 0; u < 20; u++) {
        final userId = 'user_concur_$u';
        final vote = (u % 2 == 0) ? 1 : -1;
        for (final cardId in cardIds) {
          allFutures.add(
            reputationDao.castVote(
              cardId: cardId,
              userId: userId,
              targetVote: vote,
            ),
          );
        }
      }

      await Future.wait(allFutures);

      // Verify every card: 10 upvotes, 10 downvotes, score 0
      for (final cardId in cardIds) {
        final s = await reputationDao.getReputationScore(cardId);
        expect(s.upvotes, equals(10), reason: 'Each card must have 10 upvotes');
        expect(s.downvotes, equals(10), reason: 'Each card must have 10 downvotes');
        expect(s.score, equals(0), reason: '10 - 10 == 0');
        expect(s.upvotes - s.downvotes, equals(s.score));
      }
    });

    test('1.5 Voting on non-existent card ID gracefully records vote without throwing', () async {
      const nonExistentCardId = 'card_not_in_vault';

      // castVote should succeed, updating 0 rows in vault_items but recording vote in card_reputation_votes
      final result = await reputationDao.castVote(
        cardId: nonExistentCardId,
        userId: 'ghost_user',
        targetVote: 1,
      );

      expect(result.newVote, equals(1));
      expect(result.newScore, equals(1));

      final vote = await reputationDao.getUserVote(nonExistentCardId, userId: 'ghost_user');
      expect(vote, equals(1));

      final summary = await reputationDao.getReputationScore(nonExistentCardId, userId: 'ghost_user');
      expect(summary.userVote, equals(1));
      expect(summary.score, equals(0)); // coalesce to 0 because vault item doesn't exist
    });

    test('1.6 Stream watchReputationScore emits updates in correct order without leaks', () async {
      const cardId = 'card_stream_liveness';
      await seedVaultCard(id: cardId, name: 'Sensei Divining Top');

      final emittedScores = <int>[];
      final subscription = reputationDao.watchReputationScore(cardId).listen((summary) {
        emittedScores.add(summary.score);
      });

      // Allow initial emission
      await Future<void>.delayed(const Duration(milliseconds: 20));

      await reputationDao.castVote(cardId: cardId, targetVote: 1); // +1
      await Future<void>.delayed(const Duration(milliseconds: 20));

      await reputationDao.castVote(cardId: cardId, targetVote: -1); // -1 (delta -2)
      await Future<void>.delayed(const Duration(milliseconds: 20));

      await reputationDao.castVote(cardId: cardId, targetVote: -1); // toggle to 0
      await Future<void>.delayed(const Duration(milliseconds: 20));

      await subscription.cancel();

      expect(emittedScores, containsAllInOrder([0, 1, -1, 0]));
    });
  });

  // =========================================================================
  // GROUP 2: SQLite Migration Safety (v13 -> v14)
  // =========================================================================
  group('2. SQLite Migration Safety: schemaVersion 13 -> 14', () {
    test('2.1 Upgrading real v13 schema to v14 adds reputation columns, card_reputation_votes table, and retains 0 defaults', () async {
      final rawDb = NativeDatabase.memory(setup: (raw) {
        raw.execute('PRAGMA user_version = 13;');

        // Create v13 vault_items table (WITHOUT reputation_score, upvotes, downvotes)
        raw.execute('''
          CREATE TABLE vault_items (
            id TEXT NOT NULL PRIMARY KEY,
            collection_type TEXT NOT NULL,
            name TEXT NOT NULL,
            set_or_series TEXT NOT NULL,
            image_url TEXT NOT NULL,
            acquired_price REAL NOT NULL,
            acquired_date INTEGER NOT NULL,
            quantity INTEGER NOT NULL DEFAULT 1,
            condition TEXT NOT NULL,
            is_graded INTEGER NOT NULL DEFAULT 0,
            is_altered INTEGER NOT NULL DEFAULT 0,
            is_misprint INTEGER NOT NULL DEFAULT 0,
            is_signed INTEGER NOT NULL DEFAULT 0,
            flavor_name TEXT,
            personal_notes TEXT,
            primary_binder_id TEXT,
            current_market_price REAL NOT NULL,
            last_price_update INTEGER NOT NULL,
            dynamic_data TEXT NOT NULL,
            date_obtained INTEGER,
            purchase_price REAL,
            binder_page INTEGER,
            binder_slot INTEGER,
            notes TEXT,
            protection_status TEXT,
            is_deleted INTEGER NOT NULL DEFAULT 0,
            updated_at INTEGER,
            deleted_at INTEGER,
            sync_status TEXT DEFAULT 'synced',
            user_id TEXT,
            is_traded INTEGER NOT NULL DEFAULT 0
          );
        ''');

        // Create other core tables present in v13
        raw.execute('''
          CREATE TABLE vault_binders (
            id TEXT NOT NULL PRIMARY KEY,
            name TEXT NOT NULL,
            collection_type TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            is_system_binder INTEGER NOT NULL DEFAULT 0,
            system_binder_type TEXT,
            user_id TEXT,
            deleted_at INTEGER,
            sync_status TEXT NOT NULL DEFAULT 'synced'
          );
        ''');

        // Insert 2 legacy cards into v13 database
        raw.execute('''
          INSERT INTO vault_items (
            id, collection_type, name, set_or_series, image_url,
            acquired_price, acquired_date, quantity, condition,
            current_market_price, last_price_update, dynamic_data
          ) VALUES (
            'legacy_black_lotus', 'mtg', 'Black Lotus', 'LEA', 'https://example.com/lotus.png',
            10000.0, 1600000000, 1, 'NM', 25000.0, 1600000000, '{}'
          ), (
            'legacy_time_walk', 'mtg', 'Time Walk', 'LEA', 'https://example.com/walk.png',
            4000.0, 1600000000, 1, 'EX', 7500.0, 1600000000, '{}'
          );
        ''');
      });

      // Open database with AppDatabase (triggers onUpgrade from 13 to 14 and beforeOpen)
      final migratedDb = AppDatabase(rawDb);

      // Verify PRAGMA user_version is 14
      final versionResult = await migratedDb.customSelect('PRAGMA user_version;').getSingle();
      expect(versionResult.data['user_version'], equals(14));

      // Verify PRAGMA table_info on vault_items contains reputation columns
      final tableInfo = await migratedDb.customSelect('PRAGMA table_info("vault_items");').get();
      final colNames = tableInfo.map((row) => row.read<String>('name')).toSet();
      expect(colNames, containsAll(['reputation_score', 'upvotes', 'downvotes']));

      // Verify card_reputation_votes table exists with proper unique index
      final tables = await migratedDb.customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='card_reputation_votes';",
      ).get();
      expect(tables, isNotEmpty, reason: 'card_reputation_votes table must be created');

      final indexes = await migratedDb.customSelect(
        "SELECT name FROM sqlite_master WHERE type='index' AND name IN ('unique_card_reputation_votes', 'idx_vault_items_reputation');",
      ).get();
      final indexNames = indexes.map((row) => row.read<String>('name')).toSet();
      expect(indexNames, contains('unique_card_reputation_votes'));
      expect(indexNames, contains('idx_vault_items_reputation'));

      // Verify legacy cards survived and have 0 defaults (or 0 fallback)
      final lotus = await (migratedDb.select(migratedDb.vaultItems)
            ..where((t) => t.id.equals('legacy_black_lotus')))
          .getSingle();
      expect(lotus.name, equals('Black Lotus'));
      expect(lotus.reputationScore ?? 0, equals(0));
      expect(lotus.upvotes ?? 0, equals(0));
      expect(lotus.downvotes ?? 0, equals(0));

      final timeWalk = await (migratedDb.select(migratedDb.vaultItems)
            ..where((t) => t.id.equals('legacy_time_walk')))
          .getSingle();
      expect(timeWalk.name, equals('Time Walk'));
      expect(timeWalk.reputationScore ?? 0, equals(0));

      // Verify voting on migrated legacy cards functions smoothly
      final voteResult = await migratedDb.cardReputationDao.castVote(
        cardId: 'legacy_black_lotus',
        targetVote: 1,
      );
      expect(voteResult.newScore, equals(1));
      expect(voteResult.upvotes, equals(1));
      expect(voteResult.downvotes, equals(0));

      final updatedLotus = await (migratedDb.select(migratedDb.vaultItems)
            ..where((t) => t.id.equals('legacy_black_lotus')))
          .getSingle();
      expect(updatedLotus.reputationScore, equals(1));
      expect(updatedLotus.upvotes, equals(1));

      await migratedDb.close();
    });

    test('2.2 Idempotent migration when reputation_score column already exists in intermediate state', () async {
      final rawDb = NativeDatabase.memory(setup: (raw) {
        raw.execute('PRAGMA user_version = 13;');

        // Simulate intermediate schema where reputation_score already existed, but upvotes and downvotes do not
        raw.execute('''
          CREATE TABLE vault_items (
            id TEXT NOT NULL PRIMARY KEY,
            collection_type TEXT NOT NULL,
            name TEXT NOT NULL,
            set_or_series TEXT NOT NULL,
            image_url TEXT NOT NULL,
            acquired_price REAL NOT NULL,
            acquired_date INTEGER NOT NULL,
            quantity INTEGER NOT NULL DEFAULT 1,
            condition TEXT NOT NULL,
            is_graded INTEGER NOT NULL DEFAULT 0,
            is_altered INTEGER NOT NULL DEFAULT 0,
            is_misprint INTEGER NOT NULL DEFAULT 0,
            is_signed INTEGER NOT NULL DEFAULT 0,
            flavor_name TEXT,
            personal_notes TEXT,
            primary_binder_id TEXT,
            current_market_price REAL NOT NULL,
            last_price_update INTEGER NOT NULL,
            dynamic_data TEXT NOT NULL,
            date_obtained INTEGER,
            purchase_price REAL,
            binder_page INTEGER,
            binder_slot INTEGER,
            notes TEXT,
            protection_status TEXT,
            is_deleted INTEGER NOT NULL DEFAULT 0,
            updated_at INTEGER,
            deleted_at INTEGER,
            sync_status TEXT DEFAULT 'synced',
            user_id TEXT,
            is_traded INTEGER NOT NULL DEFAULT 0,
            reputation_score INTEGER DEFAULT 0
          );
        ''');

        raw.execute('''
          INSERT INTO vault_items (
            id, collection_type, name, set_or_series, image_url,
            acquired_price, acquired_date, quantity, condition,
            current_market_price, last_price_update, dynamic_data, reputation_score
          ) VALUES (
            'card_partial_v14', 'mtg', 'Tarmogoyf', 'FUT', 'https://example.com/goyf.png',
            50.0, 1600000000, 1, 'NM', 80.0, 1600000000, '{}', 5
          );
        ''');
      });

      // Opening AppDatabase must safely handle the already-existing column via safeAddColumn
      final migratedDb = AppDatabase(rawDb);

      final tableInfo = await migratedDb.customSelect('PRAGMA table_info("vault_items");').get();
      final cols = tableInfo.map((row) => row.read<String>('name')).toSet();
      expect(cols, containsAll(['reputation_score', 'upvotes', 'downvotes']));

      final card = await (migratedDb.select(migratedDb.vaultItems)
            ..where((t) => t.id.equals('card_partial_v14')))
          .getSingle();
      expect(card.name, equals('Tarmogoyf'));
      expect(card.reputationScore, equals(5)); // Preserves pre-existing value

      await migratedDb.close();
    });
  });

  // =========================================================================
  // GROUP 3: VaultSortOption Ordering in DAO & In-Memory Queries
  // =========================================================================
  group('3. VaultSortOption Ordering in DAO & In-Memory Queries', () {
    test('3.1 reputationHighest puts top-voted cards first, ties broken cleanly by name A-Z', () async {
      await seedVaultCard(id: 'c_top', name: 'Sol Ring', initialScore: 100);
      await seedVaultCard(id: 'c_mid_b', name: 'Counterspell (Beta)', initialScore: 50);
      await seedVaultCard(id: 'c_mid_a', name: 'Counterspell (Alpha)', initialScore: 50);
      await seedVaultCard(id: 'c_zero_b', name: 'Zulaport Cutthroat', initialScore: 0);
      await seedVaultCard(id: 'c_zero_a', name: 'Anaba Shaman', initialScore: 0);
      await seedVaultCard(id: 'c_neg_1', name: 'Sorrow\'s Path', initialScore: -15);
      await seedVaultCard(id: 'c_neg_2', name: 'Wood Elemental', initialScore: -50);

      final items = await vaultDao.getItemsByCollection(
        'mtg',
        sortOption: VaultSortOption.reputationHighest,
      );

      final resultIds = items.map((c) => c.id).toList();
      final expectedIds = [
        'c_top', // 100
        'c_mid_a', // 50, 'Counterspell (Alpha)' comes before 'Counterspell (Beta)'
        'c_mid_b', // 50
        'c_zero_a', // 0, 'Anaba Shaman' comes before 'Zulaport Cutthroat'
        'c_zero_b', // 0
        'c_neg_1', // -15
        'c_neg_2', // -50
      ];

      expect(resultIds, equals(expectedIds));
    });

    test('3.2 reputationLowest puts lowest/negative cards first, ties broken cleanly by name A-Z', () async {
      await seedVaultCard(id: 'c_top', name: 'Sol Ring', initialScore: 100);
      await seedVaultCard(id: 'c_mid_b', name: 'Counterspell (Beta)', initialScore: 50);
      await seedVaultCard(id: 'c_mid_a', name: 'Counterspell (Alpha)', initialScore: 50);
      await seedVaultCard(id: 'c_zero_b', name: 'Zulaport Cutthroat', initialScore: 0);
      await seedVaultCard(id: 'c_zero_a', name: 'Anaba Shaman', initialScore: 0);
      await seedVaultCard(id: 'c_neg_1', name: 'Sorrow\'s Path', initialScore: -15);
      await seedVaultCard(id: 'c_neg_2', name: 'Wood Elemental', initialScore: -50);

      final items = await vaultDao.getItemsByCollection(
        'mtg',
        sortOption: VaultSortOption.reputationLowest,
      );

      final resultIds = items.map((c) => c.id).toList();
      final expectedIds = [
        'c_neg_2', // -50
        'c_neg_1', // -15
        'c_zero_a', // 0, 'Anaba Shaman' comes before 'Zulaport Cutthroat'
        'c_zero_b', // 0
        'c_mid_a', // 50, 'Counterspell (Alpha)' comes before 'Counterspell (Beta)'
        'c_mid_b', // 50
        'c_top', // 100
      ];

      expect(resultIds, equals(expectedIds));
    });

    test('3.3 watchItemsByCollection dynamically reorders list when votes change card ranking', () async {
      await seedVaultCard(id: 'card_a', name: 'Card Alpha', initialScore: 5);
      await seedVaultCard(id: 'card_b', name: 'Card Beta', initialScore: 10);

      final emissions = <List<String>>[];
      final subscription = vaultDao
          .watchItemsByCollection('mtg', sortOption: VaultSortOption.reputationHighest)
          .listen((items) {
        emissions.add(items.map((i) => i.id).toList());
      });

      // Allow initial stream emission
      await Future<void>.delayed(const Duration(milliseconds: 30));

      // Initial state: Card Beta (10) > Card Alpha (5)
      expect(emissions.last, equals(['card_b', 'card_a']));

      // Cast 10 upvotes on Card Alpha to bring its score to 15
      for (int i = 1; i <= 10; i++) {
        await reputationDao.castVote(
          cardId: 'card_a',
          userId: 'booster_$i',
          targetVote: 1,
        );
      }

      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Reordered state: Card Alpha (15) > Card Beta (10)
      expect(emissions.last, equals(['card_a', 'card_b']));

      await subscription.cancel();
    });

    test('3.4 sortVaultItemsInMemory produces identical ordering to DAO SQL query', () async {
      await seedVaultCard(id: 'c1', name: 'Aether Vial', initialScore: 30);
      await seedVaultCard(id: 'c2', name: 'Brainstorm', initialScore: 30);
      await seedVaultCard(id: 'c3', name: 'Dark Ritual', initialScore: -5);
      await seedVaultCard(id: 'c4', name: 'Entomb', initialScore: 80);
      await seedVaultCard(id: 'c5', name: 'Fatal Push', initialScore: 0);

      final daoHighest = await vaultDao.getItemsByCollection(
        'mtg',
        sortOption: VaultSortOption.reputationHighest,
      );
      final memHighest = sortVaultItemsInMemory(daoHighest, VaultSortOption.reputationHighest);
      expect(memHighest.map((c) => c.id).toList(), equals(daoHighest.map((c) => c.id).toList()));

      final daoLowest = await vaultDao.getItemsByCollection(
        'mtg',
        sortOption: VaultSortOption.reputationLowest,
      );
      final memLowest = sortVaultItemsInMemory(daoHighest, VaultSortOption.reputationLowest);
      expect(memLowest.map((c) => c.id).toList(), equals(daoLowest.map((c) => c.id).toList()));
    });
  });

  // =========================================================================
  // GROUP 4: CardDetailSheet Widget Responsiveness & Bounded Pump Safety
  // =========================================================================
  group('4. CardDetailSheet Widget Responsiveness & Bounded Pump Safety', () {
    VaultItem createTestCard({
      String id = 'card_sheet_stress',
      String name = 'Cyclonic Rift',
      int reputationScore = 0,
    }) {
      return VaultItem(
        id: id,
        collectionType: 'mtg',
        name: name,
        setOrSeries: 'RTR',
        imageUrl: 'https://example.com/rift.jpg',
        acquiredPrice: 15.0,
        acquiredDate: DateTime(2024, 1, 1),
        quantity: 1,
        condition: 'NM',
        isGraded: false,
        isAltered: false,
        isMisprint: false,
        isSigned: false,
        isDeleted: false,
        currentMarketPrice: 20.0,
        lastPriceUpdate: DateTime(2024, 1, 1),
        dynamicData: jsonEncode({
          'cmc': 2.0,
          'reputation_score': reputationScore,
          'oracle_text': 'Return target nonland permanent you don\'t control to its owner\'s hand.',
        }),
      );
    }

    testWidgets('4.1 Rapid toggling on CardDetailSheet updates UI optimistically without unbounded pump timeout', (tester) async {
      final card = createTestCard();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: CardDetailSheet(item: card),
            ),
          ),
        ),
      );

      // Bounded pump to initialize sheet without infinite pumpAndSettle
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final upvoteFinder = find.byKey(const Key('card_detail_upvote_button'));
      final downvoteFinder = find.byKey(const Key('card_detail_downvote_button'));
      final scoreFinder = find.byKey(const Key('card_detail_reputation_score'));

      expect(upvoteFinder, findsOneWidget);
      expect(downvoteFinder, findsOneWidget);
      expect(scoreFinder, findsOneWidget);
      expect(tester.widget<Text>(scoreFinder).data, equals('0'));

      // 1. Rapid upvote tap
      await tester.tap(upvoteFinder);
      await tester.pump();
      expect(tester.widget<Text>(scoreFinder).data, equals('1'));
      expect(tester.widget<Text>(scoreFinder).style?.color, equals(AppColors.accentEmerald));

      // 2. Rapid double tap on downvote (flip to -1 then toggle to 0)
      await tester.tap(downvoteFinder);
      await tester.pump();
      expect(tester.widget<Text>(scoreFinder).data, equals('-1'));
      expect(tester.widget<Text>(scoreFinder).style?.color, equals(AppColors.accentAmber));

      await tester.tap(downvoteFinder);
      await tester.pump();
      expect(tester.widget<Text>(scoreFinder).data, equals('0'));

      // Allow background microtasks to finish with bounded pumps
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    });
  });
}
