// Copyright (c) 2026 Countr. All rights reserved.
// Milestone 2 Adversarial Stress Test: Backend Invariants, Deduplication & Store Purge

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late VaultDao dao;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dao = db.vaultDao;
    await (db.delete(db.vaultItems)).go();
    await (db.delete(db.vaultBinders)).go();
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> insertCard({
    required String cardId,
    required String? binderId,
    required String userId,
    String name = 'Test MTG Card',
    double price = 5.0,
  }) async {
    await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: cardId,
            collectionType: 'mtg',
            name: name,
            setOrSeries: 'TEST',
            imageUrl: 'https://example.com/cards/$cardId.jpg',
            acquiredPrice: price,
            acquiredDate: DateTime.now(),
            condition: 'Near Mint',
            currentMarketPrice: price,
            lastPriceUpdate: DateTime.now(),
            dynamicData: '{}',
            primaryBinderId: drift.Value(binderId),
            userId: drift.Value(userId),
          ),
        );
  }

  group('Milestone 2 Backend Invariant Challenger: Chaos & Deduplication', () {
    test('Chaos Injection: 5 duplicate Trade & 5 duplicate Looking For binders re-anchor 100% cards with 0 loss', () async {
      const userId = 'user_chaos_normal_1';

      // 1. Create a custom binder that must remain completely unaffected
      final customBinder = await dao.createBinder(
        name: 'My Commander Album',
        collectionType: 'mtg',
        userId: userId,
      );

      // 2. Inject 5 duplicate Trade Binders (various historical / rogue naming and types)
      final trade1 = await db.into(db.vaultBinders).insertReturning(
            VaultBindersCompanion.insert(
              id: 'trade_dup_1',
              name: 'Trade Block',
              collectionType: 'mtg',
              isSystemBinder: const drift.Value(true),
              systemBinderType: const drift.Value('trade_block'),
              userId: const drift.Value(userId),
              createdAt: DateTime.now().subtract(const Duration(days: 10)),
            ),
          );
      final trade2 = await db.into(db.vaultBinders).insertReturning(
            VaultBindersCompanion.insert(
              id: 'trade_dup_2',
              name: 'Trade Binder',
              collectionType: 'mtg',
              isSystemBinder: const drift.Value(true),
              systemBinderType: const drift.Value('trade_binder'),
              userId: const drift.Value(userId),
              createdAt: DateTime.now().subtract(const Duration(days: 8)),
            ),
          );
      final trade3 = await db.into(db.vaultBinders).insertReturning(
            VaultBindersCompanion.insert(
              id: 'trade_dup_3',
              name: 'Trade Block',
              collectionType: 'mtg',
              isSystemBinder: const drift.Value(true),
              userId: const drift.Value(userId),
              createdAt: DateTime.now().subtract(const Duration(days: 6)),
            ),
          );
      final trade4 = await db.into(db.vaultBinders).insertReturning(
            VaultBindersCompanion.insert(
              id: 'system_trade_block_${userId}_legacy',
              name: 'Trade Binder',
              collectionType: 'mtg',
              isSystemBinder: const drift.Value(true),
              systemBinderType: const drift.Value('trade_block'),
              userId: const drift.Value(userId),
              createdAt: DateTime.now().subtract(const Duration(days: 4)),
            ),
          );
      final tradeCanonical = await db.into(db.vaultBinders).insertReturning(
            VaultBindersCompanion.insert(
              id: 'system_trade_block_$userId',
              name: 'Old Trade Block Name', // Deliberately non-standard name to test auto-standardization
              collectionType: 'mtg',
              isSystemBinder: const drift.Value(true),
              systemBinderType: const drift.Value('trade_block'),
              userId: const drift.Value(userId),
              createdAt: DateTime.now().subtract(const Duration(days: 2)),
            ),
          );

      // 3. Inject 5 duplicate Looking For binders
      final lf1 = await db.into(db.vaultBinders).insertReturning(
            VaultBindersCompanion.insert(
              id: 'lf_dup_1',
              name: 'Wishlist',
              collectionType: 'mtg',
              isSystemBinder: const drift.Value(true),
              systemBinderType: const drift.Value('looking_for'),
              userId: const drift.Value(userId),
              createdAt: DateTime.now().subtract(const Duration(days: 10)),
            ),
          );
      final lf2 = await db.into(db.vaultBinders).insertReturning(
            VaultBindersCompanion.insert(
              id: 'lf_dup_2',
              name: 'Looking For',
              collectionType: 'mtg',
              isSystemBinder: const drift.Value(true),
              systemBinderType: const drift.Value('looking_for'),
              userId: const drift.Value(userId),
              createdAt: DateTime.now().subtract(const Duration(days: 8)),
            ),
          );
      final lf3 = await db.into(db.vaultBinders).insertReturning(
            VaultBindersCompanion.insert(
              id: 'lf_dup_3',
              name: 'Looking For',
              collectionType: 'mtg',
              isSystemBinder: const drift.Value(true),
              userId: const drift.Value(userId),
              createdAt: DateTime.now().subtract(const Duration(days: 6)),
            ),
          );
      final lf4 = await db.into(db.vaultBinders).insertReturning(
            VaultBindersCompanion.insert(
              id: 'system_looking_for_${userId}_legacy',
              name: 'Wishlist',
              collectionType: 'mtg',
              isSystemBinder: const drift.Value(true),
              systemBinderType: const drift.Value('looking_for'),
              userId: const drift.Value(userId),
              createdAt: DateTime.now().subtract(const Duration(days: 4)),
            ),
          );
      final lfCanonical = await db.into(db.vaultBinders).insertReturning(
            VaultBindersCompanion.insert(
              id: 'system_looking_for_$userId',
              name: 'Wishlist Old Name',
              collectionType: 'mtg',
              isSystemBinder: const drift.Value(true),
              systemBinderType: const drift.Value('looking_for'),
              userId: const drift.Value(userId),
              createdAt: DateTime.now().subtract(const Duration(days: 2)),
            ),
          );

      // 4. Distribute cards across all binders:
      // - 2 cards in each of the 5 trade binders = 10 trade cards
      // - 2 cards in each of the 5 looking for binders = 10 looking for cards
      // - 3 cards in the custom binder = 3 custom cards
      // - 2 unassigned cards = 2 unassigned cards
      // Total cards = 25 cards
      final tradeCardIds = <String>{};
      final lfCardIds = <String>{};
      final customCardIds = <String>{};
      final unassignedCardIds = <String>{};

      final tradeBinders = [trade1, trade2, trade3, trade4, tradeCanonical];
      for (var bIdx = 0; bIdx < tradeBinders.length; bIdx++) {
        for (var cIdx = 0; cIdx < 2; cIdx++) {
          final cid = 'card_trade_${bIdx}_$cIdx';
          tradeCardIds.add(cid);
          await insertCard(cardId: cid, binderId: tradeBinders[bIdx].id, userId: userId);
        }
      }

      final lfBinders = [lf1, lf2, lf3, lf4, lfCanonical];
      for (var bIdx = 0; bIdx < lfBinders.length; bIdx++) {
        for (var cIdx = 0; cIdx < 2; cIdx++) {
          final cid = 'card_lf_${bIdx}_$cIdx';
          lfCardIds.add(cid);
          await insertCard(cardId: cid, binderId: lfBinders[bIdx].id, userId: userId);
        }
      }

      for (var cIdx = 0; cIdx < 3; cIdx++) {
        final cid = 'card_custom_$cIdx';
        customCardIds.add(cid);
        await insertCard(cardId: cid, binderId: customBinder.id, userId: userId);
      }

      for (var cIdx = 0; cIdx < 2; cIdx++) {
        final cid = 'card_unassigned_$cIdx';
        unassignedCardIds.add(cid);
        await insertCard(cardId: cid, binderId: null, userId: userId);
      }

      final initialTotalCards = await (db.select(db.vaultItems)).get();
      expect(initialTotalCards.length, equals(25));

      // 5. Execute Deduplication
      final stats = await dao.deduplicateAndPurgeSystemBinders(userId, isBusiness: false);
      expect(stats['bindersPurged'], equals(8)); // 4 duplicate trades + 4 duplicate looking fors
      expect(stats['cardsReanchored'], equals(16)); // 8 trade cards + 8 looking for cards moved

      // 6. Empirical Verification: Active Binders
      final activeBinders = await dao.getBindersByCollection('mtg', userId: userId, isBusiness: false);
      // Strictly 1 Trade Binder + 1 Looking For + 1 Custom Binder = 3 binders total
      expect(activeBinders.length, equals(3));

      final activeTrade = activeBinders.firstWhere((b) => b.id == tradeCanonical.id);
      expect(activeTrade.name, equals('Trade Binder')); // Auto-standardized
      expect(activeTrade.isSystemBinder, isTrue);

      final activeLf = activeBinders.firstWhere((b) => b.id == lfCanonical.id);
      expect(activeLf.name, equals('Looking For')); // Auto-standardized
      expect(activeLf.isSystemBinder, isTrue);

      final activeCustom = activeBinders.firstWhere((b) => b.id == customBinder.id);
      expect(activeCustom.name, equals('My Commander Album'));
      expect(activeCustom.isSystemBinder, isFalse);

      // 7. Empirical Verification: Zero Card Loss & 100% Re-Anchoring
      final finalCards = await (db.select(db.vaultItems)).get();
      expect(finalCards.length, equals(25)); // ZERO lost cards

      // All 10 trade cards must now be anchored to tradeCanonical.id
      final anchoredTradeCards = await (db.select(db.vaultItems)
            ..where((t) => t.primaryBinderId.equals(tradeCanonical.id)))
          .get();
      expect(anchoredTradeCards.length, equals(10));
      expect(anchoredTradeCards.map((c) => c.id).toSet(), equals(tradeCardIds));

      // All 10 looking for cards must now be anchored to lfCanonical.id
      final anchoredLfCards = await (db.select(db.vaultItems)
            ..where((t) => t.primaryBinderId.equals(lfCanonical.id)))
          .get();
      expect(anchoredLfCards.length, equals(10));
      expect(anchoredLfCards.map((c) => c.id).toSet(), equals(lfCardIds));

      // Custom binder cards untouched
      final customCards = await (db.select(db.vaultItems)
            ..where((t) => t.primaryBinderId.equals(customBinder.id)))
          .get();
      expect(customCards.length, equals(3));
      expect(customCards.map((c) => c.id).toSet(), equals(customCardIds));

      // Unassigned cards untouched
      final unassignedCards = await (db.select(db.vaultItems)
            ..where((t) => t.primaryBinderId.isNull()))
          .get();
      expect(unassignedCards.length, equals(2));
      expect(unassignedCards.map((c) => c.id).toSet(), equals(unassignedCardIds));

      // 8. Verify duplicate binders are soft-deleted
      for (final dup in [trade1, trade2, trade3, trade4, lf1, lf2, lf3, lf4]) {
        final b = await dao.getBinderById(dup.id, includeDeleted: true);
        expect(b!.isDeleted, isTrue, reason: 'Duplicate binder ${dup.id} must be soft-deleted');
      }
    });

    test('Deduplication Idempotency: Running 5 consecutive times produces identical, invariant state', () async {
      const userId = 'user_idempotency_test';

      // Setup duplicate binders and cards
      await dao.seedSystemBindersForUser(userId, isBusiness: false);

      final extraTrade = await db.into(db.vaultBinders).insertReturning(
            VaultBindersCompanion.insert(
              id: 'trade_extra_1',
              name: 'Trade Block Duplicate',
              collectionType: 'mtg',
              isSystemBinder: const drift.Value(true),
              systemBinderType: const drift.Value('trade_block'),
              userId: const drift.Value(userId),
              createdAt: DateTime.now(),
            ),
          );

      await insertCard(cardId: 'card_idem_1', binderId: extraTrade.id, userId: userId);
      await insertCard(cardId: 'card_idem_2', binderId: 'system_trade_block_$userId', userId: userId);
      await insertCard(cardId: 'card_idem_3', binderId: 'system_looking_for_$userId', userId: userId);

      // Run 1: Should migrate extraTrade and re-anchor card_idem_1
      final run1 = await dao.deduplicateAndPurgeSystemBinders(userId, isBusiness: false);
      expect(run1['bindersPurged'], equals(1));
      expect(run1['cardsReanchored'], equals(1));

      // Runs 2 to 5: Must be completely idempotent (0 purged, 0 re-anchored, zero state divergence)
      for (var run = 2; run <= 5; run++) {
        final stats = await dao.deduplicateAndPurgeSystemBinders(userId, isBusiness: false);
        expect(stats['bindersPurged'], equals(0), reason: 'Run $run must purge 0 binders');
        expect(stats['cardsReanchored'], equals(0), reason: 'Run $run must re-anchor 0 cards');

        final binders = await dao.getBindersByCollection('mtg', userId: userId, isBusiness: false);
        expect(binders.length, equals(2), reason: 'Run $run must have strictly 2 binders');
        expect(binders.map((b) => b.id).toSet(), equals({
          'system_trade_block_$userId',
          'system_looking_for_$userId',
        }));

        final tradeCards = await (db.select(db.vaultItems)
              ..where((t) => t.primaryBinderId.equals('system_trade_block_$userId')))
            .get();
        expect(tradeCards.length, equals(2), reason: 'Run $run trade cards must remain 2');
        expect(tradeCards.map((c) => c.id).toSet(), equals({'card_idem_1', 'card_idem_2'}));

        final lfCards = await (db.select(db.vaultItems)
              ..where((t) => t.primaryBinderId.equals('system_looking_for_$userId')))
            .get();
        expect(lfCards.length, equals(1), reason: 'Run $run lf cards must remain 1');
      }
    });

    test('Store Binder Purge for Normal Users: store inventory & buylist purged, cards re-anchored to Trade & LF', () async {
      const userId = 'user_normal_store_purge';

      // Seed normal system binders
      await dao.seedSystemBindersForUser(userId, isBusiness: false);

      // Inject multiple store binders (simulating legacy data or bug from previous version)
      final storeInv1 = await db.into(db.vaultBinders).insertReturning(
            VaultBindersCompanion.insert(
              id: 'system_store_inventory_$userId',
              name: 'Store Inventory',
              collectionType: 'mtg',
              isSystemBinder: const drift.Value(true),
              systemBinderType: const drift.Value('store_inventory'),
              userId: const drift.Value(userId),
              createdAt: DateTime.now().subtract(const Duration(days: 3)),
            ),
          );

      final storeInv2 = await db.into(db.vaultBinders).insertReturning(
            VaultBindersCompanion.insert(
              id: 'rogue_store_inv_2',
              name: 'Store Inventory',
              collectionType: 'mtg',
              isSystemBinder: const drift.Value(true),
              systemBinderType: const drift.Value('store_inventory'),
              userId: const drift.Value(userId),
              createdAt: DateTime.now().subtract(const Duration(days: 2)),
            ),
          );

      final storeBuy1 = await db.into(db.vaultBinders).insertReturning(
            VaultBindersCompanion.insert(
              id: 'system_store_buylist_$userId',
              name: 'Store Buylist',
              collectionType: 'mtg',
              isSystemBinder: const drift.Value(true),
              systemBinderType: const drift.Value('store_buylist'),
              userId: const drift.Value(userId),
              createdAt: DateTime.now().subtract(const Duration(days: 3)),
            ),
          );

      final storeBuy2 = await db.into(db.vaultBinders).insertReturning(
            VaultBindersCompanion.insert(
              id: 'rogue_store_buylist_2',
              name: 'Store Buylist',
              collectionType: 'mtg',
              isSystemBinder: const drift.Value(true),
              systemBinderType: const drift.Value('store_buylist'),
              userId: const drift.Value(userId),
              createdAt: DateTime.now().subtract(const Duration(days: 2)),
            ),
          );

      // Insert 6 cards into store inventories and 4 cards into store buylists
      final invCardIds = <String>{};
      final buyCardIds = <String>{};

      for (var i = 0; i < 3; i++) {
        final cid1 = 'card_store_inv_1_$i';
        final cid2 = 'card_store_inv_2_$i';
        invCardIds.addAll([cid1, cid2]);
        await insertCard(cardId: cid1, binderId: storeInv1.id, userId: userId);
        await insertCard(cardId: cid2, binderId: storeInv2.id, userId: userId);
      }

      for (var i = 0; i < 2; i++) {
        final cid1 = 'card_store_buy_1_$i';
        final cid2 = 'card_store_buy_2_$i';
        buyCardIds.addAll([cid1, cid2]);
        await insertCard(cardId: cid1, binderId: storeBuy1.id, userId: userId);
        await insertCard(cardId: cid2, binderId: storeBuy2.id, userId: userId);
      }

      // Execute purge
      final stats = await dao.deduplicateAndPurgeSystemBinders(userId, isBusiness: false);
      expect(stats['bindersPurged'], equals(4));
      expect(stats['cardsReanchored'], equals(10));

      // Active binders query must NEVER show any store binders
      final activeBinders = await dao.getBindersByCollection('mtg', userId: userId, isBusiness: false);
      expect(activeBinders.length, equals(2));
      expect(activeBinders.any((b) => b.systemBinderType == 'store_inventory'), isFalse);
      expect(activeBinders.any((b) => b.systemBinderType == 'store_buylist'), isFalse);
      expect(activeBinders.any((b) => b.name == 'Store Inventory'), isFalse);
      expect(activeBinders.any((b) => b.name == 'Store Buylist'), isFalse);

      // Verify all store inventory cards re-anchored to Trade Binder
      final tradeCards = await (db.select(db.vaultItems)
            ..where((t) => t.primaryBinderId.equals('system_trade_block_$userId')))
          .get();
      expect(tradeCards.length, equals(6));
      expect(tradeCards.map((c) => c.id).toSet(), equals(invCardIds));

      // Verify all store buylist cards re-anchored to Looking For binder
      final lfCards = await (db.select(db.vaultItems)
            ..where((t) => t.primaryBinderId.equals('system_looking_for_$userId')))
          .get();
      expect(lfCards.length, equals(4));
      expect(lfCards.map((c) => c.id).toSet(), equals(buyCardIds));

      // Verify all 4 store binders are soft-deleted in database
      for (final sb in [storeInv1, storeInv2, storeBuy1, storeBuy2]) {
        final binder = await dao.getBinderById(sb.id, includeDeleted: true);
        expect(binder!.isDeleted, isTrue);
      }
    });

    test('Store Binder Retention for Business Users: duplicate store binders consolidated, canonical retained', () async {
      const bizUserId = 'user_business_retention';

      // Seed business system binders
      await dao.seedSystemBindersForUser(bizUserId, isBusiness: true);

      // Inject duplicate store inventory and buylist
      final dupStoreInv = await db.into(db.vaultBinders).insertReturning(
            VaultBindersCompanion.insert(
              id: 'biz_store_inv_dup',
              name: 'Store Inventory Secondary',
              collectionType: 'mtg',
              isSystemBinder: const drift.Value(true),
              systemBinderType: const drift.Value('store_inventory'),
              userId: const drift.Value(bizUserId),
              createdAt: DateTime.now().subtract(const Duration(days: 1)),
            ),
          );

      final dupStoreBuy = await db.into(db.vaultBinders).insertReturning(
            VaultBindersCompanion.insert(
              id: 'biz_store_buy_dup',
              name: 'Store Buylist Secondary',
              collectionType: 'mtg',
              isSystemBinder: const drift.Value(true),
              systemBinderType: const drift.Value('store_buylist'),
              userId: const drift.Value(bizUserId),
              createdAt: DateTime.now().subtract(const Duration(days: 1)),
            ),
          );

      // Insert cards in canonical and duplicate store binders
      await insertCard(cardId: 'card_biz_inv_canonical', binderId: 'system_store_inventory_$bizUserId', userId: bizUserId);
      await insertCard(cardId: 'card_biz_inv_dup', binderId: dupStoreInv.id, userId: bizUserId);
      await insertCard(cardId: 'card_biz_buy_canonical', binderId: 'system_store_buylist_$bizUserId', userId: bizUserId);
      await insertCard(cardId: 'card_biz_buy_dup', binderId: dupStoreBuy.id, userId: bizUserId);

      // Run deduplicate with isBusiness: true
      final stats = await dao.deduplicateAndPurgeSystemBinders(bizUserId, isBusiness: true);
      expect(stats['bindersPurged'], equals(2)); // Only duplicates purged
      expect(stats['cardsReanchored'], equals(2)); // Cards from duplicates re-anchored to canonical store binders

      // Verify business user has strictly 4 active system binders
      final bizBinders = await dao.getBindersByCollection('mtg', userId: bizUserId, isBusiness: true);
      expect(bizBinders.length, equals(4));
      expect(bizBinders.map((b) => b.systemBinderType).toSet(), equals({
        'trade_block',
        'looking_for',
        'store_inventory',
        'store_buylist',
      }));

      // Verify canonical store inventory has both cards
      final invCards = await (db.select(db.vaultItems)
            ..where((t) => t.primaryBinderId.equals('system_store_inventory_$bizUserId')))
          .get();
      expect(invCards.length, equals(2));
      expect(invCards.map((c) => c.id).toSet(), equals({'card_biz_inv_canonical', 'card_biz_inv_dup'}));

      // Verify canonical store buylist has both cards
      final buyCards = await (db.select(db.vaultItems)
            ..where((t) => t.primaryBinderId.equals('system_store_buylist_$bizUserId')))
          .get();
      expect(buyCards.length, equals(2));
      expect(buyCards.map((c) => c.id).toSet(), equals({'card_biz_buy_canonical', 'card_biz_buy_dup'}));

      // Verify duplicates are soft-deleted
      final softDeletedInv = await dao.getBinderById(dupStoreInv.id, includeDeleted: true);
      expect(softDeletedInv!.isDeleted, isTrue);

      final softDeletedBuy = await dao.getBinderById(dupStoreBuy.id, includeDeleted: true);
      expect(softDeletedBuy!.isDeleted, isTrue);
    });

    test('Immutability: deleteBinder throws UnsupportedError for all system binders, but deletes custom binders', () async {
      const normalUser = 'user_immutability_norm';
      const bizUser = 'user_immutability_biz';

      await dao.seedSystemBindersForUser(normalUser, isBusiness: false);
      await dao.seedSystemBindersForUser(bizUser, isBusiness: true);

      // 1. Calling deleteBinder on Trade Binder throws UnsupportedError
      expect(
        () => dao.deleteBinder('system_trade_block_$normalUser'),
        throwsA(isA<UnsupportedError>()),
      );

      // 2. Calling deleteBinder on Looking For binder throws UnsupportedError
      expect(
        () => dao.deleteBinder('system_looking_for_$normalUser'),
        throwsA(isA<UnsupportedError>()),
      );

      // 3. Calling deleteBinder on Store Inventory throws UnsupportedError
      expect(
        () => dao.deleteBinder('system_store_inventory_$bizUser'),
        throwsA(isA<UnsupportedError>()),
      );

      // 4. Calling deleteBinder on Store Buylist throws UnsupportedError
      expect(
        () => dao.deleteBinder('system_store_buylist_$bizUser'),
        throwsA(isA<UnsupportedError>()),
      );

      // 5. Calling deleteBinder on a custom binder succeeds and unassigns cards
      final customBinder = await dao.createBinder(
        name: 'Deletable Custom Binder',
        collectionType: 'mtg',
        userId: normalUser,
      );

      await insertCard(cardId: 'card_in_custom', binderId: customBinder.id, userId: normalUser);

      final deleteCount = await dao.deleteBinder(customBinder.id);
      expect(deleteCount, equals(1));

      // Verify custom binder is soft-deleted
      final deletedBinder = await dao.getBinderById(customBinder.id, includeDeleted: true);
      expect(deletedBinder!.isDeleted, isTrue);

      // Verify card was unassigned (primaryBinderId == null) rather than deleted
      final card = await (db.select(db.vaultItems)..where((t) => t.id.equals('card_in_custom'))).getSingle();
      expect(card.primaryBinderId, isNull);
    });

    test('Cross-User Isolation: User A deduplication never modifies User B binders or cards', () async {
      const userA = 'user_isolate_a';
      const userB = 'user_isolate_b';

      // Seed both users
      await dao.seedSystemBindersForUser(userA, isBusiness: false);
      await dao.seedSystemBindersForUser(userB, isBusiness: true);

      // Add duplicate binder and cards to User B
      final dupUserB = await db.into(db.vaultBinders).insertReturning(
            VaultBindersCompanion.insert(
              id: 'system_trade_block_${userB}_dup',
              name: 'User B Trade Duplicate',
              collectionType: 'mtg',
              isSystemBinder: const drift.Value(true),
              systemBinderType: const drift.Value('trade_block'),
              userId: const drift.Value(userB),
              createdAt: DateTime.now(),
            ),
          );

      await insertCard(cardId: 'card_user_b_dup', binderId: dupUserB.id, userId: userB);

      // Run deduplication for User A only
      final statsA = await dao.deduplicateAndPurgeSystemBinders(userA, isBusiness: false);
      expect(statsA['bindersPurged'], equals(0));
      expect(statsA['cardsReanchored'], equals(0));

      // Assert User B duplicate binder is STILL active and card STILL anchored to it
      final bBinder = await dao.getBinderById(dupUserB.id);
      expect(bBinder, isNotNull);
      expect(bBinder!.isDeleted, isFalse);

      final bCard = await (db.select(db.vaultItems)..where((t) => t.id.equals('card_user_b_dup'))).getSingle();
      expect(bCard.primaryBinderId, equals(dupUserB.id));

      // Now run deduplication for User B
      final statsB = await dao.deduplicateAndPurgeSystemBinders(userB, isBusiness: true);
      expect(statsB, isNotNull);
    });

    test('High-Volume Scale Test: 100 cards across 10 duplicate binders + 20 custom cards preserves 100% data', () async {
      const userId = 'user_scale_100';

      // Create 2 custom binders
      final custom1 = await dao.createBinder(name: 'Scale Album A', collectionType: 'mtg', userId: userId);
      final custom2 = await dao.createBinder(name: 'Scale Album B', collectionType: 'mtg', userId: userId);

      // Create 5 duplicate Trade binders and 5 duplicate Looking For binders
      final tradeBinders = <VaultBinder>[];
      final lfBinders = <VaultBinder>[];

      for (var i = 1; i <= 5; i++) {
        final tb = await db.into(db.vaultBinders).insertReturning(
              VaultBindersCompanion.insert(
                id: i == 5 ? 'system_trade_block_$userId' : 'scale_trade_dup_$i',
                name: i % 2 == 0 ? 'Trade Block' : 'Trade Binder',
                collectionType: 'mtg',
                isSystemBinder: const drift.Value(true),
                systemBinderType: const drift.Value('trade_block'),
                userId: const drift.Value(userId),
                createdAt: DateTime.now().subtract(Duration(hours: i)),
              ),
            );
        tradeBinders.add(tb);

        final lfb = await db.into(db.vaultBinders).insertReturning(
              VaultBindersCompanion.insert(
                id: i == 5 ? 'system_looking_for_$userId' : 'scale_lf_dup_$i',
                name: i % 2 == 0 ? 'Wishlist' : 'Looking For',
                collectionType: 'mtg',
                isSystemBinder: const drift.Value(true),
                systemBinderType: const drift.Value('looking_for'),
                userId: const drift.Value(userId),
                createdAt: DateTime.now().subtract(Duration(hours: i)),
              ),
            );
        lfBinders.add(lfb);
      }

      // Distribute 10 cards to each of the 5 trade binders (50 cards)
      // Distribute 10 cards to each of the 5 looking for binders (50 cards)
      // Distribute 10 cards to each of the 2 custom binders (20 cards)
      // Total cards = 120
      final expectedTradeCardIds = <String>{};
      final expectedLfCardIds = <String>{};
      final expectedCustom1CardIds = <String>{};
      final expectedCustom2CardIds = <String>{};

      for (var b = 0; b < tradeBinders.length; b++) {
        for (var c = 0; c < 10; c++) {
          final cid = 'card_scale_trade_${b}_$c';
          expectedTradeCardIds.add(cid);
          await insertCard(cardId: cid, binderId: tradeBinders[b].id, userId: userId);
        }
      }

      for (var b = 0; b < lfBinders.length; b++) {
        for (var c = 0; c < 10; c++) {
          final cid = 'card_scale_lf_${b}_$c';
          expectedLfCardIds.add(cid);
          await insertCard(cardId: cid, binderId: lfBinders[b].id, userId: userId);
        }
      }

      for (var c = 0; c < 10; c++) {
        final cid1 = 'card_scale_custom1_$c';
        expectedCustom1CardIds.add(cid1);
        await insertCard(cardId: cid1, binderId: custom1.id, userId: userId);

        final cid2 = 'card_scale_custom2_$c';
        expectedCustom2CardIds.add(cid2);
        await insertCard(cardId: cid2, binderId: custom2.id, userId: userId);
      }

      final countBefore = await (db.select(db.vaultItems)).get();
      expect(countBefore.length, equals(120));

      // Run deduplication
      final stats = await dao.deduplicateAndPurgeSystemBinders(userId, isBusiness: false);
      expect(stats['bindersPurged'], equals(8));
      expect(stats['cardsReanchored'], equals(80)); // 40 trade + 40 lf cards from 8 duplicates

      // Verify active binders: strictly 2 system binders + 2 custom binders = 4
      final activeBinders = await dao.getBindersByCollection('mtg', userId: userId, isBusiness: false);
      expect(activeBinders.length, equals(4));

      // Verify all 120 cards exist (0 loss)
      final countAfter = await (db.select(db.vaultItems)).get();
      expect(countAfter.length, equals(120));

      // Check all 50 trade cards anchored to canonical trade binder
      final tradeCards = await (db.select(db.vaultItems)
            ..where((t) => t.primaryBinderId.equals('system_trade_block_$userId')))
          .get();
      expect(tradeCards.length, equals(50));
      expect(tradeCards.map((c) => c.id).toSet(), equals(expectedTradeCardIds));

      // Check all 50 looking for cards anchored to canonical looking for binder
      final lfCards = await (db.select(db.vaultItems)
            ..where((t) => t.primaryBinderId.equals('system_looking_for_$userId')))
          .get();
      expect(lfCards.length, equals(50));
      expect(lfCards.map((c) => c.id).toSet(), equals(expectedLfCardIds));

      // Check custom albums
      final custom1Cards = await (db.select(db.vaultItems)
            ..where((t) => t.primaryBinderId.equals(custom1.id)))
          .get();
      expect(custom1Cards.length, equals(10));
      expect(custom1Cards.map((c) => c.id).toSet(), equals(expectedCustom1CardIds));

      final custom2Cards = await (db.select(db.vaultItems)
            ..where((t) => t.primaryBinderId.equals(custom2.id)))
          .get();
      expect(custom2Cards.length, equals(10));
      expect(custom2Cards.map((c) => c.id).toSet(), equals(expectedCustom2CardIds));
    });

    test('Business-to-Normal Downgrade Transition: store inventory & buylist purged safely into Trade & Looking For', () async {
      const userId = 'user_downgrade_transition';

      // 1. User starts as business account with 4 system binders
      await dao.seedSystemBindersForUser(userId, isBusiness: true);

      // Insert cards into all 4 binders
      final tradeCardIds = <String>{};
      final lfCardIds = <String>{};
      final storeInvCardIds = <String>{};
      final storeBuyCardIds = <String>{};

      for (var i = 0; i < 5; i++) {
        final cidT = 'down_t_$i';
        tradeCardIds.add(cidT);
        await insertCard(cardId: cidT, binderId: 'system_trade_block_$userId', userId: userId);

        final cidLf = 'down_lf_$i';
        lfCardIds.add(cidLf);
        await insertCard(cardId: cidLf, binderId: 'system_looking_for_$userId', userId: userId);

        final cidInv = 'down_inv_$i';
        storeInvCardIds.add(cidInv);
        await insertCard(cardId: cidInv, binderId: 'system_store_inventory_$userId', userId: userId);

        final cidBuy = 'down_buy_$i';
        storeBuyCardIds.add(cidBuy);
        await insertCard(cardId: cidBuy, binderId: 'system_store_buylist_$userId', userId: userId);
      }

      // Pre-downgrade check: business user sees 4 binders and 20 total cards
      final preBizBinders = await dao.getBindersByCollection('mtg', userId: userId, isBusiness: true);
      expect(preBizBinders.length, equals(4));
      final preCount = await (db.select(db.vaultItems)).get();
      expect(preCount.length, equals(20));

      // 2. User transitions to normal user (`isBusiness: false`) and deduplication/purge runs
      final stats = await dao.deduplicateAndPurgeSystemBinders(userId, isBusiness: false);
      expect(stats['bindersPurged'], equals(2)); // store_inventory and store_buylist purged
      expect(stats['cardsReanchored'], equals(10)); // 5 from store_inv + 5 from store_buy

      // 3. Post-downgrade check: normal user sees strictly 2 binders
      final postNormalBinders = await dao.getBindersByCollection('mtg', userId: userId, isBusiness: false);
      expect(postNormalBinders.length, equals(2));
      expect(postNormalBinders.map((b) => b.id).toSet(), equals({
        'system_trade_block_$userId',
        'system_looking_for_$userId',
      }));

      // Store binders must be soft-deleted in database
      final invBinder = await dao.getBinderById('system_store_inventory_$userId', includeDeleted: true);
      expect(invBinder!.isDeleted, isTrue);
      final buyBinder = await dao.getBinderById('system_store_buylist_$userId', includeDeleted: true);
      expect(buyBinder!.isDeleted, isTrue);

      // Trade binder now has original 5 + 5 store inventory = 10 cards
      final tradeCards = await (db.select(db.vaultItems)
            ..where((t) => t.primaryBinderId.equals('system_trade_block_$userId')))
          .get();
      expect(tradeCards.length, equals(10));
      expect(tradeCards.map((c) => c.id).toSet(), equals({...tradeCardIds, ...storeInvCardIds}));

      // Looking For binder now has original 5 + 5 store buylist = 10 cards
      final lfCards = await (db.select(db.vaultItems)
            ..where((t) => t.primaryBinderId.equals('system_looking_for_$userId')))
          .get();
      expect(lfCards.length, equals(10));
      expect(lfCards.map((c) => c.id).toSet(), equals({...lfCardIds, ...storeBuyCardIds}));

      // Total cards in database is still 20 (0 lost cards)
      final postCount = await (db.select(db.vaultItems)).get();
      expect(postCount.length, equals(20));
    });

    test('Reactive Stream Integrity: watchBindersByCollection emits strictly 1 Trade and 1 Looking For binder', () async {
      const userId = 'user_stream_reactive';

      // Insert duplicate binders in database
      await db.into(db.vaultBinders).insert(
            VaultBindersCompanion.insert(
              id: 'stream_dup_trade_1',
              name: 'Trade Block',
              collectionType: 'mtg',
              isSystemBinder: const drift.Value(true),
              systemBinderType: const drift.Value('trade_block'),
              userId: const drift.Value(userId),
              createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
            ),
          );
      await db.into(db.vaultBinders).insert(
            VaultBindersCompanion.insert(
              id: 'system_trade_block_$userId',
              name: 'Trade Binder',
              collectionType: 'mtg',
              isSystemBinder: const drift.Value(true),
              systemBinderType: const drift.Value('trade_block'),
              userId: const drift.Value(userId),
              createdAt: DateTime.now(),
            ),
          );
      await db.into(db.vaultBinders).insert(
            VaultBindersCompanion.insert(
              id: 'stream_dup_lf_1',
              name: 'Wishlist',
              collectionType: 'mtg',
              isSystemBinder: const drift.Value(true),
              systemBinderType: const drift.Value('looking_for'),
              userId: const drift.Value(userId),
              createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
            ),
          );
      await db.into(db.vaultBinders).insert(
            VaultBindersCompanion.insert(
              id: 'system_looking_for_$userId',
              name: 'Looking For',
              collectionType: 'mtg',
              isSystemBinder: const drift.Value(true),
              systemBinderType: const drift.Value('looking_for'),
              userId: const drift.Value(userId),
              createdAt: DateTime.now(),
            ),
          );

      // Even before running deduplicateAndPurgeSystemBinders, the stream's in-memory defense
      // guarantees strictly <= 1 Trade Binder and <= 1 Looking For binder to the UI
      final initialStreamBinders = await dao.watchBindersByCollection('mtg', userId: userId, isBusiness: false).first;
      expect(initialStreamBinders.length, equals(2));
      expect(initialStreamBinders.map((b) => b.name).toSet(), equals({'Trade Binder', 'Looking For'}));

      // Now run database deduplication
      await dao.deduplicateAndPurgeSystemBinders(userId, isBusiness: false);

      // Stream continues to emit strictly 2 canonical binders
      final postStreamBinders = await dao.watchBindersByCollection('mtg', userId: userId, isBusiness: false).first;
      expect(postStreamBinders.length, equals(2));
      expect(postStreamBinders.map((b) => b.id).toSet(), equals({
        'system_trade_block_$userId',
        'system_looking_for_$userId',
      }));
    });
  });
}

