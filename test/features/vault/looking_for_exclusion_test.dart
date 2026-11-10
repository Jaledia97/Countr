// Copyright (c) 2026 Countr. All rights reserved.
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';

void main() {
  late AppDatabase db;
  late VaultDao dao;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dao = db.vaultDao;
    await dao.seedDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  group('Looking For Binder Exclusion & Portfolio Value Integrity', () {
    test('Looking For card has 0 acquisition price and is excluded from portfolio value & card count', () async {
      // 1. Initial portfolio totals
      final initialTotals = await dao.watchVaultTotals().first;
      final initialMarket = initialTotals.totalMarketValue;
      final initialCount = initialTotals.totalCount;

      // 2. Insert a Looking For card in system_looking_for binder
      const lookingForCardId = 'item_looking_for_mox_diamond';
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: lookingForCardId,
          collectionType: 'mtg',
          name: 'Mox Diamond',
          setOrSeries: 'Stronghold',
          imageUrl: '',
          acquiredPrice: 0.0,
          acquiredDate: DateTime.now(),
          quantity: const drift.Value(1),
          condition: 'NM',
          currentMarketPrice: 650.0,
          lastPriceUpdate: DateTime.now(),
          dynamicData: '{}',
          primaryBinderId: const drift.Value('system_looking_for_me'),
        ),
      );

      // 3. Insert the system looking_for binder
      await db.into(db.vaultBinders).insert(
        VaultBindersCompanion.insert(
          id: 'system_looking_for_me',
          name: 'Looking For',
          collectionType: 'mtg',
          createdAt: DateTime.now(),
          systemBinderType: const drift.Value('looking_for'),
          isSystemBinder: const drift.Value(true),
        ),
      );

      // 4. Verify portfolio totals remain identical: $0 added, 0 cards added
      final updatedTotals = await dao.watchVaultTotals().first;
      expect(updatedTotals.totalMarketValue, equals(initialMarket));
      expect(updatedTotals.totalCount, equals(initialCount));

      // 5. Verify onlyOwned filter excludes Looking For card from Singles
      final ownedCards = await dao.watchItemsByCollection(
        'mtg',
        onlyOwned: true,
      ).first;
      expect(ownedCards.any((c) => c.id == lookingForCardId), isFalse);

      final totalOwnedCount = await dao.watchFilteredItemCount(
        'mtg',
        onlyOwned: true,
      ).first;
      // In seed, unique MTG item rows is 5 (total quantity 8 with 4x Lightning Bolt)
      expect(totalOwnedCount, equals(5));
    });

    test('Trade Block cards remain 100% owned and are included in portfolio totals & singles', () async {
      // 1. Initial portfolio totals
      final initialTotals = await dao.watchVaultTotals().first;
      final initialMarket = initialTotals.totalMarketValue;
      final initialCount = initialTotals.totalCount;

      // 2. Insert a Trade Block card in system_trade_block binder
      const tradeBlockCardId = 'item_trade_block_force_of_will';
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: tradeBlockCardId,
          collectionType: 'mtg',
          name: 'Force of Will',
          setOrSeries: 'Alliances',
          imageUrl: '',
          acquiredPrice: 50.0,
          acquiredDate: DateTime.now(),
          quantity: const drift.Value(1),
          condition: 'NM',
          currentMarketPrice: 75.0,
          lastPriceUpdate: DateTime.now(),
          dynamicData: '{}',
          primaryBinderId: const drift.Value('system_trade_block_me'),
          isTraded: const drift.Value(false),
        ),
      );

      // 3. Insert system trade_block binder
      await db.into(db.vaultBinders).insert(
        VaultBindersCompanion.insert(
          id: 'system_trade_block_me',
          name: 'Trade Block',
          collectionType: 'mtg',
          createdAt: DateTime.now(),
          systemBinderType: const drift.Value('trade_block'),
          isSystemBinder: const drift.Value(true),
        ),
      );

      // 4. Verify Trade Block card IS included in portfolio totals
      final updatedTotals = await dao.watchVaultTotals().first;
      expect(updatedTotals.totalMarketValue, closeTo(initialMarket + 75.0, 0.001));
      expect(updatedTotals.totalCount, equals(initialCount + 1));

      // 5. Verify Trade Block card IS included when onlyOwned: true
      final ownedCards = await dao.watchItemsByCollection(
        'mtg',
        onlyOwned: true,
      ).first;
      expect(ownedCards.any((c) => c.id == tradeBlockCardId), isTrue);
    });

    test('Traded cards (isTraded == true) are excluded from portfolio totals & singles', () async {
      final initialTotals = await dao.watchVaultTotals().first;

      // Insert a traded card
      const tradedCardId = 'item_traded_away_card';
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: tradedCardId,
          collectionType: 'mtg',
          name: 'Mana Crypt',
          setOrSeries: 'Double Masters',
          imageUrl: '',
          acquiredPrice: 100.0,
          acquiredDate: DateTime.now(),
          quantity: const drift.Value(1),
          condition: 'NM',
          currentMarketPrice: 180.0,
          lastPriceUpdate: DateTime.now(),
          dynamicData: '{}',
          isTraded: const drift.Value(true),
        ),
      );

      // Verify portfolio totals do not include traded card
      final updatedTotals = await dao.watchVaultTotals().first;
      expect(updatedTotals.totalMarketValue, equals(initialTotals.totalMarketValue));
      expect(updatedTotals.totalCount, equals(initialTotals.totalCount));

      // Verify excluded from singles
      final ownedCards = await dao.watchItemsByCollection(
        'mtg',
        onlyOwned: true,
      ).first;
      expect(ownedCards.any((c) => c.id == tradedCardId), isFalse);
    });

    test('Assigning unowned item to Looking For binder resets acquiredPrice to 0 and dateObtained to null', () async {
      // Create user binder for Looking For
      const lookingForBinderId = 'system_looking_for_me';
      await db.into(db.vaultBinders).insert(
        VaultBindersCompanion.insert(
          id: lookingForBinderId,
          name: 'Looking For',
          collectionType: 'mtg',
          createdAt: DateTime.now(),
          systemBinderType: const drift.Value('looking_for'),
          isSystemBinder: const drift.Value(true),
        ),
      );

      // Create an unowned item (quantity == 0)
      const itemId = 'item_to_move_to_lf';
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: itemId,
          collectionType: 'mtg',
          name: 'Ragavan, Nimble Pilferer',
          setOrSeries: 'Modern Horizons 2',
          imageUrl: '',
          acquiredPrice: 40.0,
          acquiredDate: DateTime.now(),
          quantity: const drift.Value(0),
          condition: 'NM',
          currentMarketPrice: 45.0,
          lastPriceUpdate: DateTime.now(),
          dynamicData: '{}',
        ),
      );

      // Promote to looking for binder
      await dao.assignItemsToBinder(
        [itemId],
        lookingForBinderId,
      );

      final item = await (db.select(db.vaultItems)..where((t) => t.id.equals(itemId))).getSingle();
      expect(item.primaryBinderId, equals(lookingForBinderId));
      expect(item.acquiredPrice, equals(0.0));
      expect(item.purchasePrice, equals(0.0));
      expect(item.dateObtained, isNull);
      expect(item.protectionStatus, isNull);
    });
  });
}
