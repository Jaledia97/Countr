import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' as drift;
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/trades/domain/models/trade_card_source_filter.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/presentation/screens/binder_detail_screen.dart';
import 'package:countr/features/vault/presentation/widgets/edit_binder_modal.dart';

import 'e2e_prod_batch_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Tier 1 - Feature 6: Trade Card Source Filter & Vault Display (F6.1 to F6.5)', () {
    late AppDatabase db;
    late VaultDao vaultDao;
    final testUserId = 'user-spicy-brew-master';
    final tradeBinderId = 'system_trade_block_$testUserId';
    final lookingForBinderId = 'system_looking_for_$testUserId';

    setUp(() async {
      db = createE2eProdBatchTestDb();
      vaultDao = VaultDao(db);

      // Create canonical trade binder and looking for binder
      final now = DateTime.now();
      await db.into(db.vaultBinders).insert(
        VaultBindersCompanion.insert(
          id: tradeBinderId,
          name: 'Trade Binder',
          collectionType: 'mtg',
          createdAt: now,
          isSystemBinder: const drift.Value(true),
          systemBinderType: const drift.Value('trade_block'),
          userId: drift.Value(testUserId),
        ),
        mode: drift.InsertMode.insertOrReplace,
      );

      await db.into(db.vaultBinders).insert(
        VaultBindersCompanion.insert(
          id: lookingForBinderId,
          name: 'Looking For',
          collectionType: 'mtg',
          createdAt: now,
          isSystemBinder: const drift.Value(true),
          systemBinderType: const drift.Value('looking_for'),
          userId: drift.Value(testUserId),
        ),
        mode: drift.InsertMode.insertOrReplace,
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('F6.1: watchUserTradeCards with TradeCardSourceFilter.both returns both trade binder and collection cards', () async {
      // 1 Card in Trade Binder
      await db.into(db.vaultItems).insert(
        createTestVaultCard(
          id: 'card-trade-1',
          name: 'Mox Diamond',
          userId: testUserId,
          primaryBinderId: tradeBinderId,
          currentMarketPrice: 650.0,
        ),
      );

      // 1 Card in general collection (no binder)
      await db.into(db.vaultItems).insert(
        createTestVaultCard(
          id: 'card-collection-1',
          name: 'Mana Crypt',
          userId: testUserId,
          primaryBinderId: null,
          currentMarketPrice: 180.0,
        ),
      );

      final cards = await vaultDao.watchUserTradeCards(
        testUserId,
        filter: TradeCardSourceFilter.both,
      ).first;

      expect(cards.length, equals(2));
      final names = cards.map((c) => c.name).toList();
      expect(names, contains('Mox Diamond'));
      expect(names, contains('Mana Crypt'));
    });

    test('F6.2: watchUserTradeCards with TradeCardSourceFilter.tradeBinder filters strictly cards in trade binder', () async {
      await db.into(db.vaultItems).insert(
        createTestVaultCard(
          id: 'card-trade-only',
          name: 'Wheel of Fortune',
          userId: testUserId,
          primaryBinderId: tradeBinderId,
          currentMarketPrice: 280.0,
        ),
      );

      await db.into(db.vaultItems).insert(
        createTestVaultCard(
          id: 'card-collection-ignored',
          name: 'Sol Ring',
          userId: testUserId,
          primaryBinderId: null,
          currentMarketPrice: 2.0,
        ),
      );

      final cards = await vaultDao.watchUserTradeCards(
        testUserId,
        filter: TradeCardSourceFilter.tradeBinder,
      ).first;

      expect(cards.length, equals(1));
      expect(cards.first.id, equals('card-trade-only'));
      expect(cards.first.name, equals('Wheel of Fortune'));
    });

    test('F6.3: watchUserTradeCards with TradeCardSourceFilter.collection strictly returns general collection cards', () async {
      await db.into(db.vaultItems).insert(
        createTestVaultCard(
          id: 'card-in-trade-ignored',
          name: 'Gaea\'s Cradle',
          userId: testUserId,
          primaryBinderId: tradeBinderId,
          currentMarketPrice: 900.0,
        ),
      );

      await db.into(db.vaultItems).insert(
        createTestVaultCard(
          id: 'card-in-collection-found',
          name: 'Survival of the Fittest',
          userId: testUserId,
          primaryBinderId: null,
          currentMarketPrice: 200.0,
        ),
      );

      final cards = await vaultDao.watchUserTradeCards(
        testUserId,
        filter: TradeCardSourceFilter.collection,
      ).first;

      expect(cards.length, equals(1));
      expect(cards.first.id, equals('card-in-collection-found'));
      expect(cards.first.name, equals('Survival of the Fittest'));
    });

    test('F6.4: watchUserTradeCards strictly excludes 0 quantity, traded, deleted, and wishlist items', () async {
      // 0 Quantity card
      await db.into(db.vaultItems).insert(
        createTestVaultCard(
          id: 'card-zero-qty',
          name: 'Unowned Reference Card',
          userId: testUserId,
          quantity: 0,
        ),
      );

      // Traded card
      await db.into(db.vaultItems).insert(
        createTestVaultCard(
          id: 'card-traded',
          name: 'Already Traded Card',
          userId: testUserId,
          isTraded: true,
        ),
      );

      // Deleted card
      await db.into(db.vaultItems).insert(
        createTestVaultCard(
          id: 'card-deleted',
          name: 'Soft Deleted Card',
          userId: testUserId,
          isDeleted: true,
        ),
      );

      // Wishlist card (anchored to system_looking_for)
      await db.into(db.vaultItems).insert(
        createTestVaultCard(
          id: 'card-wishlist',
          name: 'Wishlist Item',
          userId: testUserId,
          primaryBinderId: lookingForBinderId,
        ),
      );

      // Valid card
      await db.into(db.vaultItems).insert(
        createTestVaultCard(
          id: 'card-valid',
          name: 'Valid Tradeable Card',
          userId: testUserId,
          primaryBinderId: tradeBinderId,
        ),
      );

      final cards = await vaultDao.watchUserTradeCards(
        testUserId,
        filter: TradeCardSourceFilter.both,
      ).first;

      expect(cards.length, equals(1));
      expect(cards.first.id, equals('card-valid'));
    });

    test('F6.5: watchUserTradeCards with isBusiness: true scopes trade binder to system_store_inventory', () async {
      final businessUserId = 'store-tbs-comics';
      final storeInvId = 'system_store_inventory_$businessUserId';

      await db.into(db.vaultBinders).insert(
        VaultBindersCompanion.insert(
          id: storeInvId,
          name: 'Store Inventory',
          collectionType: 'mtg',
          createdAt: DateTime.now(),
          isSystemBinder: const drift.Value(true),
          systemBinderType: const drift.Value('store_inventory'),
          userId: drift.Value(businessUserId),
        ),
        mode: drift.InsertMode.insertOrReplace,
      );

      await db.into(db.vaultItems).insert(
        createTestVaultCard(
          id: 'card-store-inv',
          name: 'Black Lotus (CE)',
          userId: businessUserId,
          primaryBinderId: storeInvId,
        ),
      );

      final cards = await vaultDao.watchUserTradeCards(
        businessUserId,
        filter: TradeCardSourceFilter.tradeBinder,
        isBusiness: true,
      ).first;

      expect(cards.length, equals(1));
      expect(cards.first.id, equals('card-store-inv'));
      expect(cards.first.name, equals('Black Lotus (CE)'));
    });
  });

  group('Tier 1 - Feature 7: System Binder De-duplication & Consolidation (F7.1 to F7.5)', () {
    late AppDatabase db;
    late VaultDao vaultDao;
    final testUserId = 'user-test-f7';
    final canonicalTradeId = 'system_trade_block_$testUserId';
    final canonicalLfId = 'system_looking_for_$testUserId';

    setUp(() async {
      db = createE2eProdBatchTestDb();
      vaultDao = VaultDao(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('F7.1: deduplicateAndPurgeSystemBinders consolidates multiple duplicate trade binders into single canonical trade binder', () async {
      final now = DateTime.now();

      // Create canonical trade binder
      await db.into(db.vaultBinders).insert(
        VaultBindersCompanion.insert(
          id: canonicalTradeId,
          name: 'Trade Binder',
          collectionType: 'mtg',
          createdAt: now,
          isSystemBinder: const drift.Value(true),
          systemBinderType: const drift.Value('trade_block'),
          userId: drift.Value(testUserId),
        ),
        mode: drift.InsertMode.insertOrReplace,
      );

      // Create duplicate trade binder
      final dupTradeId = 'system_trade_block_duplicate_1';
      await db.into(db.vaultBinders).insert(
        VaultBindersCompanion.insert(
          id: dupTradeId,
          name: 'Trade Block',
          collectionType: 'mtg',
          createdAt: now,
          isSystemBinder: const drift.Value(true),
          systemBinderType: const drift.Value('trade_block'),
          userId: drift.Value(testUserId),
        ),
        mode: drift.InsertMode.insertOrReplace,
      );

      final result = await vaultDao.deduplicateAndPurgeSystemBinders(testUserId, isBusiness: false);
      expect(result['bindersPurged'], greaterThanOrEqualTo(1));

      final activeBinders = await (db.select(db.vaultBinders)
            ..where((t) => t.userId.equals(testUserId) & t.isDeleted.equals(false) & t.systemBinderType.equals('trade_block')))
          .get();

      expect(activeBinders.length, equals(1));
      expect(activeBinders.first.id, equals(canonicalTradeId));
      expect(activeBinders.first.name, equals('Trade Binder'));
    });

    test('F7.2: deduplicateAndPurgeSystemBinders consolidates duplicate looking-for binders into single canonical binder', () async {
      final now = DateTime.now();

      // Canonical looking for
      await db.into(db.vaultBinders).insert(
        VaultBindersCompanion.insert(
          id: canonicalLfId,
          name: 'Looking For',
          collectionType: 'mtg',
          createdAt: now,
          isSystemBinder: const drift.Value(true),
          systemBinderType: const drift.Value('looking_for'),
          userId: drift.Value(testUserId),
        ),
        mode: drift.InsertMode.insertOrReplace,
      );

      // Duplicate looking for
      final dupLfId = 'system_looking_for_dup_123';
      await db.into(db.vaultBinders).insert(
        VaultBindersCompanion.insert(
          id: dupLfId,
          name: 'Looking For',
          collectionType: 'mtg',
          createdAt: now,
          isSystemBinder: const drift.Value(true),
          systemBinderType: const drift.Value('looking_for'),
          userId: drift.Value(testUserId),
        ),
        mode: drift.InsertMode.insertOrReplace,
      );

      final result = await vaultDao.deduplicateAndPurgeSystemBinders(testUserId, isBusiness: false);
      expect(result['bindersPurged'], greaterThanOrEqualTo(1));

      final activeLfs = await (db.select(db.vaultBinders)
            ..where((t) => t.userId.equals(testUserId) & t.isDeleted.equals(false) & t.systemBinderType.equals('looking_for')))
          .get();

      expect(activeLfs.length, equals(1));
      expect(activeLfs.first.id, equals(canonicalLfId));
    });

    test('F7.3: deduplicateAndPurgeSystemBinders re-anchors cards from duplicate binders to canonical binder without card loss', () async {
      final now = DateTime.now();
      final dupTradeId = 'system_trade_block_dup_cards';

      await db.into(db.vaultBinders).insert(
        VaultBindersCompanion.insert(
          id: canonicalTradeId,
          name: 'Trade Binder',
          collectionType: 'mtg',
          createdAt: now,
          isSystemBinder: const drift.Value(true),
          systemBinderType: const drift.Value('trade_block'),
          userId: drift.Value(testUserId),
        ),
        mode: drift.InsertMode.insertOrReplace,
      );

      await db.into(db.vaultBinders).insert(
        VaultBindersCompanion.insert(
          id: dupTradeId,
          name: 'Trade Block',
          collectionType: 'mtg',
          createdAt: now,
          isSystemBinder: const drift.Value(true),
          systemBinderType: const drift.Value('trade_block'),
          userId: drift.Value(testUserId),
        ),
        mode: drift.InsertMode.insertOrReplace,
      );

      // Card anchored to duplicate binder
      await db.into(db.vaultItems).insert(
        createTestVaultCard(
          id: 'card-in-dup-trade',
          name: 'Force of Will',
          userId: testUserId,
          primaryBinderId: dupTradeId,
        ),
      );

      final result = await vaultDao.deduplicateAndPurgeSystemBinders(testUserId, isBusiness: false);
      expect(result['cardsReanchored'], greaterThanOrEqualTo(1));

      final card = await (db.select(db.vaultItems)..where((t) => t.id.equals('card-in-dup-trade'))).getSingle();
      expect(card.primaryBinderId, equals(canonicalTradeId));
    });

    test('F7.4: Non-business users have strictly 1 Trade Binder and 1 Looking For binder after deduplication', () async {
      await vaultDao.seedSystemBindersForUser(testUserId, isBusiness: false);

      // Seed duplicates intentionally
      final now = DateTime.now();
      await db.into(db.vaultBinders).insert(
        VaultBindersCompanion.insert(
          id: 'system_trade_block_extra_1',
          name: 'Trade Block',
          collectionType: 'mtg',
          createdAt: now,
          isSystemBinder: const drift.Value(true),
          systemBinderType: const drift.Value('trade_block'),
          userId: drift.Value(testUserId),
        ),
        mode: drift.InsertMode.insertOrReplace,
      );

      await vaultDao.deduplicateAndPurgeSystemBinders(testUserId, isBusiness: false);

      final systemBinders = await (db.select(db.vaultBinders)
            ..where((t) => t.userId.equals(testUserId) & t.isDeleted.equals(false) & t.isSystemBinder.equals(true)))
          .get();

      expect(systemBinders.length, equals(2));
      final types = systemBinders.map((b) => b.systemBinderType).toSet();
      expect(types, equals({'trade_block', 'looking_for'}));
    });

    test('F7.5: deduplicateAndPurgeSystemBinders purges store inventory binders on individual users and re-anchors cards', () async {
      final now = DateTime.now();
      final storeInvId = 'system_store_inventory_$testUserId';

      await db.into(db.vaultBinders).insert(
        VaultBindersCompanion.insert(
          id: canonicalTradeId,
          name: 'Trade Binder',
          collectionType: 'mtg',
          createdAt: now,
          isSystemBinder: const drift.Value(true),
          systemBinderType: const drift.Value('trade_block'),
          userId: drift.Value(testUserId),
        ),
        mode: drift.InsertMode.insertOrReplace,
      );

      await db.into(db.vaultBinders).insert(
        VaultBindersCompanion.insert(
          id: storeInvId,
          name: 'Store Inventory',
          collectionType: 'mtg',
          createdAt: now,
          isSystemBinder: const drift.Value(true),
          systemBinderType: const drift.Value('store_inventory'),
          userId: drift.Value(testUserId),
        ),
        mode: drift.InsertMode.insertOrReplace,
      );

      await db.into(db.vaultItems).insert(
        createTestVaultCard(
          id: 'card-misassigned-store',
          name: 'Ancient Tomb',
          userId: testUserId,
          primaryBinderId: storeInvId,
        ),
      );

      final result = await vaultDao.deduplicateAndPurgeSystemBinders(testUserId, isBusiness: false);
      expect(result['bindersPurged'], greaterThanOrEqualTo(1));
      expect(result['cardsReanchored'], greaterThanOrEqualTo(1));

      final reanchored = await (db.select(db.vaultItems)..where((t) => t.id.equals('card-misassigned-store'))).getSingle();
      expect(reanchored.primaryBinderId, equals(canonicalTradeId));

      final storeBinder = await (db.select(db.vaultBinders)..where((t) => t.id.equals(storeInvId))).getSingle();
      expect(storeBinder.isDeleted, isTrue);
    });
  });

  group('Tier 1 - Feature 8: System Binder Immutability & UI Protection (F8.1 to F8.5)', () {
    late AppDatabase db;
    late VaultDao vaultDao;
    final testUserId = 'user-current-me';
    final canonicalTradeId = 'system_trade_block_$testUserId';

    setUp(() async {
      db = createE2eProdBatchTestDb();
      vaultDao = VaultDao(db);

      await db.into(db.vaultBinders).insert(
        VaultBindersCompanion.insert(
          id: canonicalTradeId,
          name: 'Trade Binder',
          collectionType: 'mtg',
          createdAt: DateTime.now(),
          isSystemBinder: const drift.Value(true),
          systemBinderType: const drift.Value('trade_block'),
          userId: drift.Value(testUserId),
        ),
        mode: drift.InsertMode.insertOrReplace,
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('F8.1: deleteBinder throws UnsupportedError when attempted on a system binder', () async {
      expect(
        () => vaultDao.deleteBinder(canonicalTradeId),
        throwsA(isA<UnsupportedError>()),
      );

      final binder = await (db.select(db.vaultBinders)..where((t) => t.id.equals(canonicalTradeId))).getSingle();
      expect(binder.isDeleted, isFalse);
    });

    test('F8.1b: updateBinder throws UnsupportedError when attempted on a system binder', () async {
      expect(
        () => vaultDao.updateBinder(canonicalTradeId, name: 'Renamed Trade Binder'),
        throwsA(isA<UnsupportedError>()),
      );

      final binder = await (db.select(db.vaultBinders)..where((t) => t.id.equals(canonicalTradeId))).getSingle();
      expect(binder.name, equals('Trade Binder'));
    });

    test('F8.2: deleteBinder succeeds and soft-deletes a normal custom user binder', () async {
      final customBinderId = 'custom-binder-modern-staples';
      await db.into(db.vaultBinders).insert(
        VaultBindersCompanion.insert(
          id: customBinderId,
          name: 'Modern Staples',
          collectionType: 'mtg',
          createdAt: DateTime.now(),
          isSystemBinder: const drift.Value(false),
          userId: drift.Value(testUserId),
        ),
      );

      final deletedCount = await vaultDao.deleteBinder(customBinderId);
      expect(deletedCount, equals(1));

      final deletedBinder = await (db.select(db.vaultBinders)..where((t) => t.id.equals(customBinderId))).getSingle();
      expect(deletedBinder.isDeleted, isTrue);
    });

    testWidgets('F8.3: EditBinderModal renders system protection banner and readOnly name for system binders', (tester) async {
      final systemBinder = await (db.select(db.vaultBinders)..where((t) => t.id.equals(canonicalTradeId))).getSingle();

      await tester.pumpWidget(
        wrapWithMaterialAndScope(
          EditBinderModal(binder: systemBinder),
        ),
      );

      // Verify protected banner is visible
      expect(find.byKey(const Key('edit_binder_system_protected_banner')), findsOneWidget);
      expect(find.textContaining('Permanent System Binder — Protected against deletion'), findsOneWidget);

      // Verify name input is read-only
      final textFieldFinder = find.byKey(const Key('edit_binder_name_input'));
      expect(textFieldFinder, findsOneWidget);
      final textField = tester.widget<TextField>(textFieldFinder);
      expect(textField.readOnly, isTrue);
    });

    test('F8.4: assignItemsToBinder allows card assignment to system binders freely without restriction', () async {
      await db.into(db.vaultItems).insert(
        createTestVaultCard(
          id: 'card-add-test',
          name: 'Urza\'s Saga',
          userId: testUserId,
          primaryBinderId: null,
        ),
      );

      final assignedCount = await vaultDao.assignItemsToBinder(
        ['card-add-test'],
        canonicalTradeId,
      );

      expect(assignedCount, equals(1));
      final updatedCard = await (db.select(db.vaultItems)..where((t) => t.id.equals('card-add-test'))).getSingle();
      expect(updatedCard.primaryBinderId, equals(canonicalTradeId));
    });

    testWidgets('F8.5: BinderDetailScreen renders PINNED SYSTEM badge, Quota Exempt subtitle, and hides edit button for system binders', (tester) async {
      final systemBinder = await (db.select(db.vaultBinders)..where((t) => t.id.equals(canonicalTradeId))).getSingle();

      await tester.pumpWidget(
        wrapWithMaterialAndScope(
          BinderDetailScreen(binder: systemBinder),
        ),
      );

      expect(find.byKey(Key('binder_detail_system_badge_${systemBinder.id}')), findsOneWidget);
      expect(find.text('PINNED SYSTEM'), findsOneWidget);
      expect(find.text('Permanent System Binder • Quota Exempt'), findsOneWidget);
      expect(find.byKey(const Key('binder_edit_button')), findsNothing);
    });

    testWidgets('F8.6: BinderDetailScreen renders binder_edit_button for custom user binders', (tester) async {
      final customBinderId = 'custom-binder-test-edit';
      await db.into(db.vaultBinders).insert(
        VaultBindersCompanion.insert(
          id: customBinderId,
          name: 'Custom Binder',
          collectionType: 'mtg',
          createdAt: DateTime.now(),
          isSystemBinder: const drift.Value(false),
          userId: drift.Value(testUserId),
        ),
      );
      final customBinder = await (db.select(db.vaultBinders)..where((t) => t.id.equals(customBinderId))).getSingle();

      await tester.pumpWidget(
        wrapWithMaterialAndScope(
          BinderDetailScreen(binder: customBinder),
        ),
      );

      expect(find.byKey(const Key('binder_edit_button')), findsOneWidget);
    });
  });
}
