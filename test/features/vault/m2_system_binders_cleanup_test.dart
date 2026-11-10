// Copyright (c) 2026 Countr. All rights reserved.
// Milestone 2 System Binders Cleanup & Half-Height UI Presentation Test Suite

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/auth/presentation/providers/auth_providers.dart';
import 'package:countr/features/profile/presentation/providers/profile_providers.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/screens/vault_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late VaultDao dao;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dao = db.vaultDao;
    await dao.clearAllItems();
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> insertTestCard({
    required String cardId,
    required String binderId,
    required String userId,
    String name = 'Test Card',
  }) async {
    await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: cardId,
            collectionType: 'mtg',
            name: name,
            setOrSeries: 'TEST',
            imageUrl: 'https://example.com/cards/$cardId.jpg',
            acquiredPrice: 10.0,
            acquiredDate: DateTime.now(),
            condition: 'Near Mint',
            currentMarketPrice: 12.0,
            lastPriceUpdate: DateTime.now(),
            dynamicData: '{}',
            primaryBinderId: drift.Value(binderId),
            userId: drift.Value(userId),
          ),
        );
  }

  group('M2 DAO: deduplicateAndPurgeSystemBinders & Filtering', () {
    test('Normal user deduplication merges duplicate trade and looking_for binders and re-anchors cards', () async {
      const userId = 'user_m2_norm_1';

      // Insert duplicate trade binders
      final trade1 = await db.into(db.vaultBinders).insertReturning(
            VaultBindersCompanion.insert(
              id: 'trade_sys_1',
              name: 'Trade Block',
              collectionType: 'mtg',
              isSystemBinder: const drift.Value(true),
              systemBinderType: const drift.Value('trade_binder'),
              userId: const drift.Value(userId),
              createdAt: DateTime.now().subtract(const Duration(days: 2)),
            ),
          );
      final trade2 = await db.into(db.vaultBinders).insertReturning(
            VaultBindersCompanion.insert(
              id: 'trade_sys_2',
              name: 'Trade Binder',
              collectionType: 'mtg',
              isSystemBinder: const drift.Value(true),
              systemBinderType: const drift.Value('trade_binder'),
              userId: const drift.Value(userId),
              createdAt: DateTime.now().subtract(const Duration(days: 1)),
            ),
          );

      // Insert duplicate looking for binders
      final lf1 = await db.into(db.vaultBinders).insertReturning(
            VaultBindersCompanion.insert(
              id: 'lf_sys_1',
              name: 'Wishlist',
              collectionType: 'mtg',
              isSystemBinder: const drift.Value(true),
              systemBinderType: const drift.Value('looking_for'),
              userId: const drift.Value(userId),
              createdAt: DateTime.now().subtract(const Duration(days: 2)),
            ),
          );
      final lf2 = await db.into(db.vaultBinders).insertReturning(
            VaultBindersCompanion.insert(
              id: 'lf_sys_2',
              name: 'Looking For',
              collectionType: 'mtg',
              isSystemBinder: const drift.Value(true),
              systemBinderType: const drift.Value('looking_for'),
              userId: const drift.Value(userId),
              createdAt: DateTime.now().subtract(const Duration(days: 1)),
            ),
          );

      // Insert cards into both duplicate sets
      await insertTestCard(cardId: 'card_t1', binderId: trade1.id, userId: userId, name: 'Card Trade 1');
      await insertTestCard(cardId: 'card_t2', binderId: trade2.id, userId: userId, name: 'Card Trade 2');
      await insertTestCard(cardId: 'card_lf1', binderId: lf1.id, userId: userId, name: 'Card LF 1');
      await insertTestCard(cardId: 'card_lf2', binderId: lf2.id, userId: userId, name: 'Card LF 2');

      // Execute deduplication
      await dao.deduplicateAndPurgeSystemBinders(userId, isBusiness: false);

      // Query active binders for normal user
      final activeBinders = await dao.getBindersByCollection('mtg', userId: userId, isBusiness: false);
      expect(activeBinders.length, equals(2));

      final activeTrade = activeBinders.firstWhere((b) =>
          b.name == 'Trade Binder' ||
          b.systemBinderType == 'trade_block' ||
          b.systemBinderType == 'trade_binder');
      expect(activeTrade.name, equals('Trade Binder'));

      final activeLf = activeBinders.firstWhere((b) => b.systemBinderType == 'looking_for');
      expect(activeLf.name, equals('Looking For'));

      // Check cards were re-anchored to the survivor binder
      final tradeCards = await (db.select(db.vaultItems)
            ..where((t) => t.primaryBinderId.equals(activeTrade.id) & t.userId.equals(userId)))
          .get();
      expect(tradeCards.length, equals(2));
      expect(tradeCards.map((c) => c.id).toSet(), equals({'card_t1', 'card_t2'}));

      final lfCards = await (db.select(db.vaultItems)
            ..where((t) => t.primaryBinderId.equals(activeLf.id) & t.userId.equals(userId)))
          .get();
      expect(lfCards.length, equals(2));
      expect(lfCards.map((c) => c.id).toSet(), equals({'card_lf1', 'card_lf2'}));

      // Verify the duplicates were soft-deleted
      final deletedTrade = await dao.getBinderById('trade_sys_2', includeDeleted: true);
      expect(deletedTrade!.isDeleted, isTrue);

      final deletedLf = await dao.getBinderById('lf_sys_2', includeDeleted: true);
      expect(deletedLf!.isDeleted, isTrue);
    });

    test('Normal user purge removes Store Inventory and Store Buylist, moving cards to Trade and Looking For', () async {
      const userId = 'user_m2_store_purge';

      // Seed normal system binders
      await dao.seedSystemBindersForUser(userId, isBusiness: false);

      // Manually add store binders for this normal user (e.g. from legacy state)
      final storeInv = await db.into(db.vaultBinders).insertReturning(
            VaultBindersCompanion.insert(
              id: 'store_inv_legacy',
              name: 'Store Inventory',
              collectionType: 'mtg',
              isSystemBinder: const drift.Value(true),
              systemBinderType: const drift.Value('store_inventory'),
              userId: const drift.Value(userId),
              createdAt: DateTime.now(),
            ),
          );
      final storeBuy = await db.into(db.vaultBinders).insertReturning(
            VaultBindersCompanion.insert(
              id: 'store_buy_legacy',
              name: 'Store Buylist',
              collectionType: 'mtg',
              isSystemBinder: const drift.Value(true),
              systemBinderType: const drift.Value('store_buylist'),
              userId: const drift.Value(userId),
              createdAt: DateTime.now(),
            ),
          );

      await insertTestCard(cardId: 'card_store_inv', binderId: storeInv.id, userId: userId, name: 'Store Card 1');
      await insertTestCard(cardId: 'card_store_buy', binderId: storeBuy.id, userId: userId, name: 'Store Card 2');

      // Run deduplicateAndPurgeSystemBinders
      await dao.deduplicateAndPurgeSystemBinders(userId, isBusiness: false);

      // Active binders must contain only 2 binders: Trade Binder and Looking For
      final activeBinders = await dao.getBindersByCollection('mtg', userId: userId, isBusiness: false);
      expect(activeBinders.length, equals(2));
      expect(activeBinders.any((b) => b.systemBinderType == 'store_inventory'), isFalse);
      expect(activeBinders.any((b) => b.systemBinderType == 'store_buylist'), isFalse);

      final tradeBinder = activeBinders.firstWhere((b) =>
          b.name == 'Trade Binder' ||
          b.systemBinderType == 'trade_block' ||
          b.systemBinderType == 'trade_binder');
      final lfBinder = activeBinders.firstWhere((b) => b.systemBinderType == 'looking_for');

      // Store inventory card re-anchored to tradeBinder
      final cardInv = await (db.select(db.vaultItems)..where((t) => t.id.equals('card_store_inv'))).getSingle();
      expect(cardInv.primaryBinderId, equals(tradeBinder.id));

      // Store buylist card re-anchored to lfBinder
      final cardBuy = await (db.select(db.vaultItems)..where((t) => t.id.equals('card_store_buy'))).getSingle();
      expect(cardBuy.primaryBinderId, equals(lfBinder.id));

      // Store binders soft-deleted
      final softDeletedInv = await dao.getBinderById('store_inv_legacy', includeDeleted: true);
      expect(softDeletedInv!.isDeleted, isTrue);

      final softDeletedBuy = await dao.getBinderById('store_buy_legacy', includeDeleted: true);
      expect(softDeletedBuy!.isDeleted, isTrue);
    });

    test('Business user retains Store Inventory and Store Buylist without purging', () async {
      const bizUserId = 'user_m2_biz_retained';

      // Seed business system binders
      await dao.seedSystemBindersForUser(bizUserId, isBusiness: true);

      // Add cards to all 4 system binders
      final binders = await dao.getBindersByCollection('mtg', userId: bizUserId, isBusiness: true);
      expect(binders.length, equals(4));

      // Run deduplicateAndPurgeSystemBinders with isBusiness: true
      await dao.deduplicateAndPurgeSystemBinders(bizUserId, isBusiness: true);

      final retainedBinders = await dao.getBindersByCollection('mtg', userId: bizUserId, isBusiness: true);
      expect(retainedBinders.length, equals(4));
      expect(retainedBinders.map((b) => b.systemBinderType).toSet(), equals({
        'trade_block',
        'looking_for',
        'store_inventory',
        'store_buylist',
      }));
    });

    test('deleteBinder throws UnsupportedError for any system binder but succeeds for custom binders', () async {
      const userId = 'user_m2_immutability';
      final systemBinders = await dao.seedSystemBindersForUser(userId, isBusiness: false);
      expect(systemBinders.length, equals(2));

      // Attempting to delete trade_binder throws
      final tradeBinder = systemBinders.firstWhere((b) =>
          b.name == 'Trade Binder' ||
          b.systemBinderType == 'trade_block' ||
          b.systemBinderType == 'trade_binder');
      expect(
        () => dao.deleteBinder(tradeBinder.id),
        throwsA(isA<UnsupportedError>()),
      );

      // Attempting to delete looking_for throws
      final lfBinder = systemBinders.firstWhere((b) => b.systemBinderType == 'looking_for');
      expect(
        () => dao.deleteBinder(lfBinder.id),
        throwsA(isA<UnsupportedError>()),
      );

      // Creating a custom binder and deleting it succeeds
      final custom = await dao.createBinder(
        name: 'My Custom Binder',
        collectionType: 'mtg',
        userId: userId,
      );
      final deletedCount = await dao.deleteBinder(custom.id);
      expect(deletedCount, equals(1));
    });
  });

  group('M2 UI: Half-Height Pinned System Binder Presentation', () {
    Widget createVaultApp({
      required String userId,
      required bool isBusiness,
    }) {
      final user = AuthUser(
        id: userId,
        displayName: 'Test User',
        username: 'testuser',
        provider: AuthProviderType.email,
        tier: isBusiness ? AccountTier.business : AccountTier.free,
        isGuest: false,
        isVerifiedBusiness: isBusiness,
        createdAt: DateTime.now(),
      );

      return ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(dao),
          currentUserIdProvider.overrideWith((ref) => userId),
          currentUserProvider.overrideWith((ref) => CurrentUserNotifier(ref.watch(authRepositoryProvider))..setUser(user)),
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.binders),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
        ],
        child: const MaterialApp(
          home: VaultScreen(),
        ),
      );
    }

    testWidgets('VaultScreen displays half-height top dock (aspect ratio 2.2) with amber trade and cyan looking for binders', (tester) async {
      const userId = 'user_m2_widget_test';

      // Seed 2 system binders and 1 custom binder
      await dao.seedSystemBindersForUser(userId, isBusiness: false);
      await dao.createBinder(
        name: 'Vintage Foils',
        collectionType: 'mtg',
        userId: userId,
      );

      await tester.pumpWidget(createVaultApp(userId: userId, isBusiness: false));
      await tester.pumpAndSettle();

      // 1. Pinned System Binders Header and Grid exist
      expect(find.byKey(const Key('vault_pinned_system_binders_header')), findsOneWidget);
      expect(find.text('PROFILE BINDERS'), findsOneWidget);
      expect(find.text('Synced with Profile'), findsOneWidget);

      final pinnedGridFinder = find.byKey(const Key('vault_pinned_system_binders_grid'));
      expect(pinnedGridFinder, findsOneWidget);

      final pinnedGrid = tester.widget<SliverGrid>(pinnedGridFinder);
      final pinnedDelegate = pinnedGrid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(pinnedDelegate.crossAxisCount, equals(2));
      expect(pinnedDelegate.childAspectRatio, equals(2.2));

      // 2. Both pinned cards rendered with specific keys
      final tradeCardFinder = find.byKey(const Key('vault_pinned_trade_binder'));
      final lfCardFinder = find.byKey(const Key('vault_pinned_looking_for_binder'));
      expect(tradeCardFinder, findsOneWidget);
      expect(lfCardFinder, findsOneWidget);

      // Verify Trade badge and Looking For badge text
      expect(find.text('TRADE'), findsOneWidget);
      expect(find.text('LOOKING FOR'), findsOneWidget);

      // Verify Trade Card decoration uses Amber accent
      final tradeInkWell = tester.widget<InkWell>(tradeCardFinder);
      final tradeContainer = tradeInkWell.child as Container;
      final tradeBoxDec = tradeContainer.decoration as BoxDecoration;
      final tradeBorder = tradeBoxDec.border as Border;
      expect(tradeBorder.top.color, equals(AppColors.accentAmber.withValues(alpha: 0.55)));

      // Verify Looking For Card decoration uses Cyan accent
      final lfInkWell = tester.widget<InkWell>(lfCardFinder);
      final lfContainer = lfInkWell.child as Container;
      final lfBoxDec = lfContainer.decoration as BoxDecoration;
      final lfBorder = lfBoxDec.border as Border;
      expect(lfBorder.top.color, equals(AppColors.accentCyan.withValues(alpha: 0.55)));

      // 3. Custom Binders Header ("MY BINDERS") and Grid (childAspectRatio 1.05)
      expect(find.byKey(const Key('vault_custom_binders_header')), findsOneWidget);
      expect(find.text('MY BINDERS'), findsOneWidget);
      expect(find.text('Vintage Foils'), findsOneWidget);

      final customGridFinder = find.byKey(const PageStorageKey<String>('vault_binders_sliver_grid'));
      expect(customGridFinder, findsOneWidget);
      final customGrid = tester.widget<SliverGrid>(customGridFinder);
      final customDelegate = customGrid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(customDelegate.crossAxisCount, equals(2));
      expect(customDelegate.childAspectRatio, equals(1.05));
    });

    testWidgets('Empty custom binders displays empty placeholder under MY BINDERS', (tester) async {
      const userId = 'user_m2_empty_custom';
      await dao.seedSystemBindersForUser(userId, isBusiness: false);

      await tester.pumpWidget(createVaultApp(userId: userId, isBusiness: false));
      await tester.pumpAndSettle();

      // Pinned grid still shows
      expect(find.byKey(const Key('vault_pinned_trade_binder')), findsOneWidget);
      expect(find.byKey(const Key('vault_pinned_looking_for_binder')), findsOneWidget);

      // Empty custom binders card is displayed
      expect(find.byKey(const Key('vault_custom_binders_empty_card')), findsOneWidget);
      expect(find.text('No Custom Binders Yet'), findsOneWidget);
    });
  });
}
