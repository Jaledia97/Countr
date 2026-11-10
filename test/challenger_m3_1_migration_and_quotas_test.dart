// Copyright (c) 2026 Countr. All rights reserved.
// Empirical Challenger stress test suite for Milestone 3 (Epic 3: Profiles, Auth Onboarding, Quotas & System Binders)
// Challenger: challenger_m3_1

import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/auth/presentation/providers/auth_providers.dart';
import 'package:countr/features/profile/domain/services/tier_quota_service.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.userProfileDao.seedDefaultProfiles();
  });

  tearDown(() async {
    await db.close();
  });

  group('CHALLENGER STRESS: 1. Guest Migration Concurrency, Atomicity & Data Integrity', () {
    test('1.1 Zero card loss, zero binder loss, zero deck loss across custom and guest system binders', () async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
        ],
      );
      addTearDown(container.dispose);

      final now = DateTime.now();

      // Seed 2 custom guest binders
      await db.into(db.vaultBinders).insert(
            VaultBindersCompanion.insert(
              id: 'binder_guest_custom_1',
              name: 'Guest Vintage Binder',
              collectionType: 'mtg',
              createdAt: now,
              isSystemBinder: const drift.Value(false),
              userId: const drift.Value('guest'),
            ),
          );
      await db.into(db.vaultBinders).insert(
            VaultBindersCompanion.insert(
              id: 'binder_guest_custom_2',
              name: 'Guest Commander Binder',
              collectionType: 'mtg',
              createdAt: now,
              isSystemBinder: const drift.Value(false),
              userId: const drift.Value('guest'),
            ),
          );

      // Seed guest system binders
      await db.vaultDao.seedSystemBindersForUser('guest', isBusiness: false);

      // Seed 5 cards in custom binder 1
      for (int i = 1; i <= 5; i++) {
        await db.into(db.vaultItems).insert(
              VaultItemsCompanion.insert(
                id: 'card_custom1_$i',
                collectionType: 'mtg',
                name: 'Custom Card 1.$i',
                setOrSeries: 'M3',
                imageUrl: '',
                acquiredPrice: 5.0,
                acquiredDate: now,
                quantity: const drift.Value(1),
                condition: 'NM',
                currentMarketPrice: 5.0,
                lastPriceUpdate: now,
                dynamicData: jsonEncode({'rarity': 'rare'}),
                primaryBinderId: const drift.Value('binder_guest_custom_1'),
                userId: const drift.Value('guest'),
              ),
            );
      }

      // Seed 5 cards in custom binder 2
      for (int i = 1; i <= 5; i++) {
        await db.into(db.vaultItems).insert(
              VaultItemsCompanion.insert(
                id: 'card_custom2_$i',
                collectionType: 'mtg',
                name: 'Custom Card 2.$i',
                setOrSeries: 'M3',
                imageUrl: '',
                acquiredPrice: 10.0,
                acquiredDate: now,
                quantity: const drift.Value(1),
                condition: 'NM',
                currentMarketPrice: 10.0,
                lastPriceUpdate: now,
                dynamicData: jsonEncode({'rarity': 'rare'}),
                primaryBinderId: const drift.Value('binder_guest_custom_2'),
                userId: const drift.Value('guest'),
              ),
            );
      }

      // Seed 3 cards in guest looking_for system binder
      for (int i = 1; i <= 3; i++) {
        await db.into(db.vaultItems).insert(
              VaultItemsCompanion.insert(
                id: 'card_sys_looking_$i',
                collectionType: 'mtg',
                name: 'Looking For Card $i',
                setOrSeries: 'M3',
                imageUrl: '',
                acquiredPrice: 20.0,
                acquiredDate: now,
                quantity: const drift.Value(1),
                condition: 'NM',
                currentMarketPrice: 20.0,
                lastPriceUpdate: now,
                dynamicData: jsonEncode({'rarity': 'mythic'}),
                primaryBinderId: const drift.Value('system_looking_for_guest'),
                userId: const drift.Value('guest'),
              ),
            );
      }

      // Seed 2 cards in guest trade_block system binder
      for (int i = 1; i <= 2; i++) {
        await db.into(db.vaultItems).insert(
              VaultItemsCompanion.insert(
                id: 'card_sys_trade_$i',
                collectionType: 'mtg',
                name: 'Trade Block Card $i',
                setOrSeries: 'M3',
                imageUrl: '',
                acquiredPrice: 15.0,
                acquiredDate: now,
                quantity: const drift.Value(1),
                condition: 'NM',
                currentMarketPrice: 15.0,
                lastPriceUpdate: now,
                dynamicData: jsonEncode({'rarity': 'uncommon'}),
                primaryBinderId: const drift.Value('system_trade_block_guest'),
                userId: const drift.Value('guest'),
              ),
            );
      }

      // Seed 2 guest decks
      await db.into(db.decks).insert(
            DecksCompanion.insert(
              id: 'deck_guest_1',
              name: 'Guest Deck One',
              format: 'Modern',
              createdAt: now,
              userId: const drift.Value('guest'),
            ),
          );
      await db.into(db.decks).insert(
            DecksCompanion.insert(
              id: 'deck_guest_2',
              name: 'Guest Deck Two',
              format: 'Legacy',
              createdAt: now,
              userId: const drift.Value('guest'),
            ),
          );

      // Seed 1 guest explore deck
      await db.into(db.exploreDecks).insert(
            ExploreDecksCompanion.insert(
              id: 'explore_guest_deck_1',
              name: 'Guest Shared Deck',
              format: 'Commander',
              sourceType: const drift.Value('user_shared'),
              authorId: const drift.Value('guest'),
              createdAt: now,
              updatedAt: drift.Value(now),
            ),
          );

      const targetAuthUserId = 'user_auth_target_100';
      final migrationService = container.read(guestMigrationServiceProvider);

      final summary = await migrationService.migrateGuestData(
        newUserId: targetAuthUserId,
        isBusiness: false,
      );

      expect(summary.isSuccess, isTrue);

      // 1. Verify zero card loss: all 15 specifically seeded guest cards migrated to target user ID
      final guestCardsMigrated = await (db.select(db.vaultItems)
            ..where((t) =>
                (t.id.like('card_custom%') | t.id.like('card_sys_%')) &
                t.userId.equals(targetAuthUserId) &
                t.isDeleted.equals(false)))
          .get();
      expect(guestCardsMigrated.length, equals(15), reason: 'Zero card loss mandate violated');

      // 2. Verify zero custom binder loss: 2 custom binders migrated to newUserId
      final customBinders = await (db.select(db.vaultBinders)
            ..where((t) =>
                t.id.isIn(const ['binder_guest_custom_1', 'binder_guest_custom_2']) &
                t.isDeleted.equals(false) &
                t.isSystemBinder.equals(false)))
          .get();
      expect(customBinders.length, equals(2), reason: 'Zero binder loss mandate violated');
      for (final binder in customBinders) {
        expect(binder.userId, equals(targetAuthUserId),
            reason: 'Custom binder ${binder.id} was not migrated to target user ID');
      }

      // 3. Verify zero deck loss: 2 guest decks migrated to newUserId
      final guestDecks = await (db.select(db.decks)
            ..where((t) => t.id.isIn(const ['deck_guest_1', 'deck_guest_2']) & t.isDeleted.equals(false)))
          .get();
      expect(guestDecks.length, equals(2), reason: 'Zero deck loss mandate violated');
      for (final deck in guestDecks) {
        expect(deck.userId, equals(targetAuthUserId),
            reason: 'Deck ${deck.id} was not migrated to target user ID');
      }

      // 4. Verify explore deck authorId updated
      final exploreDeck = await (db.select(db.exploreDecks)..where((t) => t.id.equals('explore_guest_deck_1'))).getSingle();
      expect(exploreDeck.authorId, equals(targetAuthUserId));

      // 5. Verify system binder items re-anchored to target user's system binder IDs
      final lookingForCards = await (db.select(db.vaultItems)
            ..where((t) => t.id.like('card_sys_looking_%')))
          .get();
      expect(lookingForCards.length, equals(3));
      for (final card in lookingForCards) {
        expect(card.primaryBinderId, equals('system_looking_for_$targetAuthUserId'),
            reason: 'Card in guest looking_for was not re-anchored to new user system binder');
      }

      final tradeBlockCards = await (db.select(db.vaultItems)
            ..where((t) => t.id.like('card_sys_trade_%')))
          .get();
      expect(tradeBlockCards.length, equals(2));
      for (final card in tradeBlockCards) {
        expect(card.primaryBinderId, equals('system_trade_block_$targetAuthUserId'),
            reason: 'Card in guest trade_block was not re-anchored to new user system binder');
      }

      // 6. Verify authenticated user has permanent system binders provisioned
      final userSystemBinders = await (db.select(db.vaultBinders)
            ..where((t) => t.userId.equals(targetAuthUserId) & t.isSystemBinder.equals(true)))
          .get();
      expect(userSystemBinders.length, equals(2));
      expect(userSystemBinders.any((b) => b.id == 'system_looking_for_$targetAuthUserId'), isTrue);
      expect(userSystemBinders.any((b) => b.id == 'system_trade_block_$targetAuthUserId'), isTrue);
    });

    test('1.2 Guest migration idempotency under repeated calls', () async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
        ],
      );
      addTearDown(container.dispose);

      const userId = 'user_idempotent_test';
      final migrationService = container.read(guestMigrationServiceProvider);

      // Call migration first time
      final summary1 = await migrationService.migrateGuestData(newUserId: userId, isBusiness: false);
      expect(summary1.isSuccess, isTrue);

      // Call migration second time
      final summary2 = await migrationService.migrateGuestData(newUserId: userId, isBusiness: false);
      expect(summary2.isSuccess, isTrue);

      // Verify system binders are not duplicated
      final systemBinders = await (db.select(db.vaultBinders)
            ..where((t) => t.userId.equals(userId) & t.isSystemBinder.equals(true) & t.isDeleted.equals(false)))
          .get();
      expect(systemBinders.length, equals(2));
    });

    test('1.3 Duplicate explore deck vote migration resolution', () async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
        ],
      );
      addTearDown(container.dispose);

      final now = DateTime.now();
      const authUserId = 'user_voter_target_1';

      // Seed 2 explore decks
      await db.into(db.exploreDecks).insert(
            ExploreDecksCompanion.insert(
              id: 'deck_explore_vote_1',
              name: 'Explore Deck 1',
              format: 'Commander',
              createdAt: now,
              updatedAt: drift.Value(now),
            ),
          );
      await db.into(db.exploreDecks).insert(
            ExploreDecksCompanion.insert(
              id: 'deck_explore_vote_2',
              name: 'Explore Deck 2',
              format: 'Commander',
              createdAt: now,
              updatedAt: drift.Value(now),
            ),
          );

      // Seed existing vote by authenticated user on deck 1
      await db.into(db.exploreDeckVotes).insert(
            ExploreDeckVotesCompanion.insert(
              id: 'deck_explore_vote_1_$authUserId',
              exploreDeckId: 'deck_explore_vote_1',
              userId: const drift.Value(authUserId),
              vote: const drift.Value(1),
              updatedAt: now,
            ),
          );

      // Seed guest vote on deck 1 (DUPLICATE vote on deck 1)
      await db.into(db.exploreDeckVotes).insert(
            ExploreDeckVotesCompanion.insert(
              id: 'deck_explore_vote_1_guest',
              exploreDeckId: 'deck_explore_vote_1',
              userId: const drift.Value('guest'),
              vote: const drift.Value(-1),
              updatedAt: now,
            ),
          );

      // Seed guest vote on deck 2 (NON-DUPLICATE vote on deck 2)
      await db.into(db.exploreDeckVotes).insert(
            ExploreDeckVotesCompanion.insert(
              id: 'deck_explore_vote_2_guest',
              exploreDeckId: 'deck_explore_vote_2',
              userId: const drift.Value('guest'),
              vote: const drift.Value(1),
              updatedAt: now,
            ),
          );

      final migrationService = container.read(guestMigrationServiceProvider);

      // Run migration
      final summary = await migrationService.migrateGuestData(
        newUserId: authUserId,
        isBusiness: false,
      );

      expect(summary.isSuccess, isTrue);

      // Check whether duplicate vote caused migration to fail or leave orphaned guest votes
      final guestVotesRemaining = await (db.select(db.exploreDeckVotes)
            ..where((t) => t.userId.equals('guest') | t.userId.isNull() | t.userId.equals('')))
          .get();

      // Stress assertion: Are there orphaned guest votes remaining due to collision?
      expect(guestVotesRemaining.isEmpty, isTrue,
          reason: 'Duplicate explore deck vote caused vote migration failure: unmigrated guest votes remain!');

      // Check deck 2 vote was migrated to authUserId
      final deck2Votes = await (db.select(db.exploreDeckVotes)
            ..where((t) => t.exploreDeckId.equals('deck_explore_vote_2') & t.userId.equals(authUserId)))
          .get();
      expect(deck2Votes.length, equals(1),
          reason: 'Non-colliding guest vote on deck 2 was not migrated');

      // Check deck 1 has exactly 1 resolved vote for authUserId
      final deck1Votes = await (db.select(db.exploreDeckVotes)
            ..where((t) => t.exploreDeckId.equals('deck_explore_vote_1') & t.userId.equals(authUserId)))
          .get();
      expect(deck1Votes.length, equals(1),
          reason: 'Deck 1 should have exactly one resolved vote for user');
    });

    test('1.4 Guest migration to verified Business re-anchors system items appropriately', () async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
        ],
      );
      addTearDown(container.dispose);

      final now = DateTime.now();
      const bizUserId = 'store_migrated_lgs_1';

      // Seed guest cards in looking_for and trade_block
      await db.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'card_guest_biz_1',
              collectionType: 'mtg',
              name: 'Lotus Petal',
              setOrSeries: 'M3',
              imageUrl: '',
              acquiredPrice: 20.0,
              acquiredDate: now,
              quantity: const drift.Value(1),
              condition: 'NM',
              currentMarketPrice: 20.0,
              lastPriceUpdate: now,
              dynamicData: jsonEncode({'rarity': 'common'}),
              primaryBinderId: const drift.Value('system_looking_for_guest'),
              userId: const drift.Value('guest'),
            ),
          );

      final migrationService = container.read(guestMigrationServiceProvider);
      await migrationService.migrateGuestData(
        newUserId: bizUserId,
        isBusiness: true,
      );

      // Verify business system binders exist: Store Inventory & Store Buylist
      final bizSystemBinders = await (db.select(db.vaultBinders)
            ..where((t) => t.userId.equals(bizUserId) & t.isSystemBinder.equals(true)))
          .get();
      expect(bizSystemBinders.any((b) => b.systemBinderType == 'store_inventory'), isTrue);
      expect(bizSystemBinders.any((b) => b.systemBinderType == 'store_buylist'), isTrue);

      // Check if looking_for binder exists or if card points to a non-existent binder
      final card = await (db.select(db.vaultItems)..where((t) => t.id.equals('card_guest_biz_1'))).getSingle();
      final targetBinder = await (db.select(db.vaultBinders)..where((t) => t.id.equals(card.primaryBinderId!))).getSingleOrNull();
      expect(targetBinder, isNotNull,
          reason: 'Card points to orphaned binder ${card.primaryBinderId} because business accounts do not have looking_for binders');
    });
  });

  group('CHALLENGER STRESS: 2. Tier Quota Boundary Conditions', () {
    testWidgets('2.1 Guest limits: 2 custom binders pass, 3rd blocked (isolated count)', (tester) async {
      // Clear seeded custom binders to test isolated 0 -> 1 -> 2 -> 3 transition
      await (db.delete(db.vaultBinders)..where((t) => t.isSystemBinder.equals(false))).go();

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
        ],
      );
      addTearDown(container.dispose);

      container.read(currentUserProvider.notifier).setUser(AuthUser.guest(guestId: 'guest_test_quota_b'));

      final quotaService = container.read(tierQuotaServiceProvider);

      // Provision system binders (should not affect count)
      await db.vaultDao.seedSystemBindersForUser('guest_test_quota_b', isBusiness: false);

      // 0 custom binders: pass
      expect(await quotaService.canCreateCustomBinder(container), isTrue);

      // 1st custom binder: pass
      await db.vaultDao.createBinder(name: 'Guest Binder 1', collectionType: 'mtg', userId: 'guest_test_quota_b');
      expect(await quotaService.canCreateCustomBinder(container), isTrue);

      // 2nd custom binder: at limit (2), next is blocked
      await db.vaultDao.createBinder(name: 'Guest Binder 2', collectionType: 'mtg', userId: 'guest_test_quota_b');
      expect(await quotaService.canCreateCustomBinder(container), isFalse,
          reason: 'Guest should be blocked after 2 custom binders');
    });

    testWidgets('2.2 Guest limits: starter decks do NOT consume guest allowance (3 personal decks pass, 4th blocked)', (tester) async {
      // Clear personal decks
      await (db.delete(db.decks)..where((t) => t.userId.equals('guest_test_deck_starter'))).go();

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
        ],
      );
      addTearDown(container.dispose);

      container.read(currentUserProvider.notifier).setUser(AuthUser.guest(guestId: 'guest_test_deck_starter'));

      final quotaService = container.read(tierQuotaServiceProvider);

      // Seed canonical starter decks
      final now = DateTime.now();
      final starterDeckIds = [
        'deck-edgar-markov',
        'deck-yuriko',
        'deck-tron',
        'deck-charizard-ex',
        'deck-lost-zone',
        'deck-lorcana',
      ];
      for (final starterId in starterDeckIds) {
        await db.into(db.decks).insert(
              DecksCompanion.insert(
                id: starterId,
                name: 'Starter $starterId',
                format: 'Commander',
                createdAt: now,
                userId: const drift.Value('guest'),
              ),
              mode: drift.InsertMode.insertOrReplace,
            );
      }

      // With 6 starter decks, guest should still have 0 personal decks -> canCreateOrCloneDeck == true
      expect(await quotaService.canCreateOrCloneDeck(container), isTrue,
          reason: 'Starter decks must NOT consume guest allowance');

      // Create 1st personal deck
      await db.vaultDao.createDeck('Personal Deck 1', userId: 'guest_test_deck_starter');
      expect(await quotaService.canCreateOrCloneDeck(container), isTrue);

      // Create 2nd personal deck
      await db.vaultDao.createDeck('Personal Deck 2', userId: 'guest_test_deck_starter');
      expect(await quotaService.canCreateOrCloneDeck(container), isTrue);

      // Create 3rd personal deck
      await db.vaultDao.createDeck('Personal Deck 3', userId: 'guest_test_deck_starter');
      
      // Now at limit 3 personal decks -> 4th deck blocked
      expect(await quotaService.canCreateOrCloneDeck(container), isFalse,
          reason: 'Guest should be blocked after 3 personal decks');
    });

    testWidgets('2.3 Free tier limits: 3 custom binders pass, 4th blocked; 5 decks pass, 6th blocked', (tester) async {
      const freeUserId = 'user_free_quota_boundary';
      // Clear custom binders and decks for clean test
      await (db.delete(db.vaultBinders)..where((t) => t.userId.equals(freeUserId) & t.isSystemBinder.equals(false))).go();
      await (db.delete(db.decks)..where((t) => t.userId.equals(freeUserId))).go();

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
        ],
      );
      addTearDown(container.dispose);

      container.read(currentUserProvider.notifier).setUser(AuthUser(
            id: freeUserId,
            displayName: 'Free User',
            username: '@FreeUser',
            provider: AuthProviderType.email,
            tier: AccountTier.free,
            createdAt: DateTime.now(),
          ));

      final quotaService = container.read(tierQuotaServiceProvider);

      // System binders provisioned
      await db.vaultDao.seedSystemBindersForUser(freeUserId, isBusiness: false);

      // Test custom binder boundary: 0, 1, 2 pass; 3 reaches limit; 4th blocked
      expect(await quotaService.canCreateCustomBinder(container), isTrue);

      await db.vaultDao.createBinder(name: 'Free Binder 1', collectionType: 'mtg', userId: freeUserId);
      expect(await quotaService.canCreateCustomBinder(container), isTrue);

      await db.vaultDao.createBinder(name: 'Free Binder 2', collectionType: 'mtg', userId: freeUserId);
      expect(await quotaService.canCreateCustomBinder(container), isTrue);

      await db.vaultDao.createBinder(name: 'Free Binder 3', collectionType: 'mtg', userId: freeUserId);
      expect(await quotaService.canCreateCustomBinder(container), isFalse,
          reason: 'Free tier must be blocked after 3 custom binders');

      // Test personal deck boundary: 0, 1, 2, 3, 4 pass; 5 reaches limit; 6th blocked
      expect(await quotaService.canCreateOrCloneDeck(container), isTrue);

      await db.vaultDao.createDeck('Free Deck 1', userId: freeUserId);
      expect(await quotaService.canCreateOrCloneDeck(container), isTrue);

      await db.vaultDao.createDeck('Free Deck 2', userId: freeUserId);
      expect(await quotaService.canCreateOrCloneDeck(container), isTrue);

      await db.vaultDao.createDeck('Free Deck 3', userId: freeUserId);
      expect(await quotaService.canCreateOrCloneDeck(container), isTrue);

      await db.vaultDao.createDeck('Free Deck 4', userId: freeUserId);
      expect(await quotaService.canCreateOrCloneDeck(container), isTrue);

      await db.vaultDao.createDeck('Free Deck 5', userId: freeUserId);
      expect(await quotaService.canCreateOrCloneDeck(container), isFalse,
          reason: 'Free tier must be blocked after 5 personal decks');
    });

    testWidgets('2.4 Pro and Business limits: unlimited custom binders and decks', (tester) async {
      const proUserId = 'user_pro_unlimited';
      final proContainer = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
        ],
      );
      addTearDown(proContainer.dispose);

      proContainer.read(currentUserProvider.notifier).setUser(AuthUser(
            id: proUserId,
            displayName: 'Pro Collector',
            username: '@ProCollector',
            provider: AuthProviderType.discord,
            tier: AccountTier.pro,
            createdAt: DateTime.now(),
          ));

      final proQuotaService = proContainer.read(tierQuotaServiceProvider);

      // Create 10 custom binders for Pro user
      for (int i = 1; i <= 10; i++) {
        await db.vaultDao.createBinder(name: 'Pro Binder $i', collectionType: 'mtg', userId: proUserId);
      }
      expect(await proQuotaService.canCreateCustomBinder(proContainer), isTrue,
          reason: 'Pro user should have unlimited custom binders');

      // Create 10 decks for Pro user
      for (int i = 1; i <= 10; i++) {
        await db.vaultDao.createDeck('Pro Deck $i', userId: proUserId);
      }
      expect(await proQuotaService.canCreateOrCloneDeck(proContainer), isTrue,
          reason: 'Pro user should have unlimited decks');

      // Test Business tier
      const bizUserId = 'user_biz_unlimited';
      final bizContainer = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
        ],
      );
      addTearDown(bizContainer.dispose);

      bizContainer.read(currentUserProvider.notifier).setUser(AuthUser(
            id: bizUserId,
            displayName: 'Game Store',
            username: '@GameStore',
            provider: AuthProviderType.google,
            tier: AccountTier.business,
            isVerifiedBusiness: true,
            createdAt: DateTime.now(),
          ));

      final bizQuotaService = bizContainer.read(tierQuotaServiceProvider);

      for (int i = 1; i <= 10; i++) {
        await db.vaultDao.createBinder(name: 'Biz Binder $i', collectionType: 'mtg', userId: bizUserId);
      }
      expect(await bizQuotaService.canCreateCustomBinder(bizContainer), isTrue,
          reason: 'Business user should have unlimited custom binders');

      for (int i = 1; i <= 10; i++) {
        await db.vaultDao.createDeck('Biz Deck $i', userId: bizUserId);
      }
      expect(await bizQuotaService.canCreateOrCloneDeck(bizContainer), isTrue,
          reason: 'Business user should have unlimited decks');
    });

    test('2.5 System binders are strictly excluded from custom binder count across all tiers', () async {
      // Clear custom binders so custom binder baseline is cleanly zero
      await (db.delete(db.vaultBinders)..where((t) => t.isSystemBinder.equals(false))).go();

      const guestId = 'guest_sys_quota_test';
      const freeId = 'free_sys_quota_test';
      const bizId = 'biz_sys_quota_test';

      // Seed system binders for guest, free, and business
      await db.vaultDao.seedSystemBindersForUser(guestId, isBusiness: false);
      await db.vaultDao.seedSystemBindersForUser(freeId, isBusiness: false);
      await db.vaultDao.seedSystemBindersForUser(bizId, isBusiness: true);

      // Verify custom binder count is 0 for all three
      expect(await db.vaultDao.getCustomBinderCount(userId: guestId), equals(0));
      expect(await db.vaultDao.getCustomBinderCount(userId: freeId), equals(0));
      expect(await db.vaultDao.getCustomBinderCount(userId: bizId), equals(0));

      // Add cards into system binders
      final now = DateTime.now();
      await db.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'card_sys_test_1',
              collectionType: 'mtg',
              name: 'Sol Ring',
              setOrSeries: 'M3',
              imageUrl: '',
              acquiredPrice: 2.0,
              acquiredDate: now,
              quantity: const drift.Value(1),
              condition: 'NM',
              currentMarketPrice: 2.0,
              lastPriceUpdate: now,
              dynamicData: jsonEncode({'rarity': 'uncommon'}),
              primaryBinderId: drift.Value('system_looking_for_$freeId'),
              userId: const drift.Value(freeId),
            ),
          );

      // Verify custom binder count remains 0
      expect(await db.vaultDao.getCustomBinderCount(userId: freeId), equals(0),
          reason: 'Adding cards to system binders must not increment custom binder count');
    });

    testWidgets('2.6 Adversarial: Migrated starter decks must not exhaust newly registered Free user deck quota', (tester) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
        ],
      );
      addTearDown(container.dispose);

      final now = DateTime.now();
      // Ensure starter decks exist with null userId (as seeded by default in vaultDao)
      final starterDeckIds = [
        'deck-edgar-markov',
        'deck-yuriko',
        'deck-tron',
        'deck-charizard-ex',
        'deck-lost-zone',
        'deck-lorcana',
      ];
      for (final starterId in starterDeckIds) {
        await db.into(db.decks).insert(
              DecksCompanion.insert(
                id: starterId,
                name: 'Starter $starterId',
                format: 'Commander',
                createdAt: now,
              ),
              mode: drift.InsertMode.insertOrReplace,
            );
      }

      // Guest migrates to a newly registered Free user
      const newFreeUserId = 'user_free_migrated_from_guest';
      final migrationService = container.read(guestMigrationServiceProvider);
      await migrationService.migrateGuestData(newUserId: newFreeUserId, isBusiness: false);

      container.read(currentUserProvider.notifier).setUser(AuthUser(
            id: newFreeUserId,
            displayName: 'New Free User',
            username: '@NewFreeUser',
            provider: AuthProviderType.email,
            tier: AccountTier.free,
            createdAt: now,
          ));

      final quotaService = container.read(tierQuotaServiceProvider);

      // The new free user has created 0 personal decks. Can they create a deck?
      final canCreate = await quotaService.canCreateOrCloneDeck(container);
      expect(canCreate, isTrue,
          reason: 'A newly migrated Free user with 0 personal decks is blocked because starter decks were migrated to their userId!');
    });
  });
}
