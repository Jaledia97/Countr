// Copyright (c) 2026 Countr. All rights reserved.
// Challenger Delta Adversarial Test Suite
// Verifying Looking For Wishlist Isolation & Trade Block Invariant

import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/domain/models/vault_set_collection.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/screens/master_set_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late VaultDao dao;

  const testUserId = 'whale_adversarial_user';
  const lookingForBinderId = 'system_looking_for_$testUserId';
  const tradeBlockBinderId = 'system_trade_block_$testUserId';

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dao = db.vaultDao;

    // Purge default auto-seeded records to guarantee clean empirical baselines
    await db.delete(db.vaultItems).go();
    await db.delete(db.vaultBinders).go();

    // Create system Looking For binder
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

    // Create system Trade Block binder
    await db.into(db.vaultBinders).insert(
      VaultBindersCompanion.insert(
        id: tradeBlockBinderId,
        name: 'Trade Block',
        collectionType: 'mtg',
        createdAt: DateTime.now(),
        systemBinderType: const drift.Value('trade_block'),
        isSystemBinder: const drift.Value(true),
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('Adversarial Stress Test: Looking For Wishlist Isolation (50+ cards with \$50k+ values)', () {
    test('Adding 60 cards with values \$50k–\$200k to Looking For results strictly in \$0.00 vault total and 0 count', () async {
      double totalWishlistValue = 0.0;
      final companions = <VaultItemsCompanion>[];

      for (int i = 0; i < 60; i++) {
        final cardValue = 50000.0 + (i * 2500.0); // $50,000 to $197,500 each
        totalWishlistValue += cardValue;

        companions.add(
          VaultItemsCompanion.insert(
            id: 'c_vintage_alpha_$i',
            collectionType: 'mtg',
            name: 'Alpha Power Card #$i',
            setOrSeries: 'Limited Edition Alpha',
            imageUrl: 'https://cards.scryfall.io/normal/alpha_$i.jpg',
            acquiredPrice: 0.0,
            acquiredDate: DateTime.now(),
            quantity: const drift.Value(1),
            condition: 'NM',
            currentMarketPrice: cardValue,
            lastPriceUpdate: DateTime.now(),
            dynamicData: jsonEncode({
              'set_code': 'lea',
              'collector_number': '$i',
              'rarity': 'rare',
            }),
            primaryBinderId: const drift.Value(lookingForBinderId),
            isDeleted: const drift.Value(false),
            isTraded: const drift.Value(false),
          ),
        );
      }

      // Bulk insert all 60 huge-value cards
      await db.batch((b) {
        b.insertAll(db.vaultItems, companions);
      });

      // Assert cumulative wishlist value is massive ($7,425,000)
      expect(totalWishlistValue, greaterThan(7000000.0));

      // 1. One-shot getVaultTotals must strictly return $0.00 and 0 count
      final totals = await dao.getVaultTotals();
      expect(totals.totalCount, equals(0), reason: 'Looking For cards must never inflate totalCount');
      expect(totals.totalMarketValue, equals(0.0), reason: 'Looking For cards must never inflate totalMarketValue');
      expect(totals.totalCostBasis, equals(0.0));
      expect(totals.uniqueCount, equals(0));

      // 2. Stream watchVaultTotals must strictly emit $0.00 and 0 count
      final streamTotals = await dao.watchVaultTotals().first;
      expect(streamTotals.totalCount, equals(0));
      expect(streamTotals.totalMarketValue, equals(0.0));
      expect(streamTotals.totalCostBasis, equals(0.0));

      // 3. Scoped by collection type 'mtg' must strictly return $0.00 and 0 count
      final mtgTotals = await dao.getVaultTotals(collectionType: 'mtg');
      expect(mtgTotals.totalCount, equals(0));
      expect(mtgTotals.totalMarketValue, equals(0.0));

      final streamMtgTotals = await dao.watchVaultTotals(collectionType: 'mtg').first;
      expect(streamMtgTotals.totalCount, equals(0));
      expect(streamMtgTotals.totalMarketValue, equals(0.0));

      // 4. Singles owned queries must strictly return empty
      final ownedCards = await dao.getItemsByCollection('mtg', onlyOwned: true);
      expect(ownedCards, isEmpty, reason: 'Singles inventory with onlyOwned: true must ignore Looking For cards');

      final streamOwnedCards = await dao.watchItemsByCollection('mtg', onlyOwned: true).first;
      expect(streamOwnedCards, isEmpty);

      final ownedCount = await dao.watchFilteredItemCount('mtg', onlyOwned: true).first;
      expect(ownedCount, equals(0));
    });

    test('Custom binder with system_binder_type = "looking_for" (non-prefixed ID) is also strictly excluded', () async {
      const customLfBinderId = 'custom_wishlist_binder_adversarial_99';
      await db.into(db.vaultBinders).insert(
        VaultBindersCompanion.insert(
          id: customLfBinderId,
          name: 'My Grail Wishlist',
          collectionType: 'mtg',
          createdAt: DateTime.now(),
          systemBinderType: const drift.Value('looking_for'),
          isSystemBinder: const drift.Value(false),
        ),
      );

      // Insert 10 cards anchored to custom looking_for binder
      for (int i = 0; i < 10; i++) {
        await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'c_custom_grail_$i',
            collectionType: 'mtg',
            name: 'Grail Item #$i',
            setOrSeries: 'Arabian Nights',
            imageUrl: '',
            acquiredPrice: 0.0,
            acquiredDate: DateTime.now(),
            quantity: const drift.Value(1),
            condition: 'NM',
            currentMarketPrice: 25000.0,
            lastPriceUpdate: DateTime.now(),
            dynamicData: '{}',
            primaryBinderId: const drift.Value(customLfBinderId),
          ),
        );
      }

      final totals = await dao.getVaultTotals();
      expect(totals.totalCount, equals(0));
      expect(totals.totalMarketValue, equals(0.0));

      final owned = await dao.getItemsByCollection('mtg', onlyOwned: true);
      expect(owned, isEmpty);
    });

    test('watchCollectionItemCounts and watchSetCollections strictly ignore Looking For cards', () async {
      // Insert 20 Looking For cards in set 'Antiquities'
      for (int i = 0; i < 20; i++) {
        await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'c_antiquities_$i',
            collectionType: 'mtg',
            name: 'Antiquities Card #$i',
            setOrSeries: 'Antiquities',
            imageUrl: '',
            acquiredPrice: 0.0,
            acquiredDate: DateTime.now(),
            quantity: const drift.Value(1),
            condition: 'NM',
            currentMarketPrice: 1500.0,
            lastPriceUpdate: DateTime.now(),
            dynamicData: jsonEncode({'set_code': 'atq'}),
            primaryBinderId: const drift.Value(lookingForBinderId),
          ),
        );
      }

      // 1. watchCollectionItemCounts must return 0 for all and mtg
      final counts = await dao.watchCollectionItemCounts().first;
      expect(counts['all'], equals(0), reason: 'Global collection count must ignore Looking For items');
      expect(counts['mtg'], equals(0), reason: 'MTG collection count must ignore Looking For items');

      // 2. watchSetCollections must show totalCards = 20, but ownedCards = 0 and completionPercentage = 0.0
      final setCollections = await dao.watchSetCollections(collectionType: 'mtg').first;
      expect(setCollections.length, equals(1));
      final atqSet = setCollections.first;
      expect(atqSet.setName, equals('Antiquities'));
      expect(atqSet.totalCount, equals(20));
      expect(atqSet.ownedCount, equals(0), reason: 'Looking For cards must not count toward owned cards in set');
      expect(atqSet.completionPercentage, equals(0.0), reason: 'Set completion must be 0.0% when cards are only in Looking For');
    });
  });

  group('Adversarial Transition: Moving Cards from Looking For to Trade Block', () {
    test('Moving 10 cards to Trade Block makes them owned, adds to singles, and updates portfolio totals', () async {
      // 1. Insert 10 cards into Looking For
      const cardCount = 10;
      const pricePerCard = 6000.0;
      final cardIds = <String>[];

      for (int i = 0; i < cardCount; i++) {
        final id = 'c_move_test_$i';
        cardIds.add(id);
        await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: id,
            collectionType: 'mtg',
            name: 'Dual Land #$i',
            setOrSeries: 'Revised Edition',
            imageUrl: '',
            acquiredPrice: 0.0,
            acquiredDate: DateTime.now(),
            quantity: const drift.Value(1),
            condition: 'NM',
            currentMarketPrice: pricePerCard,
            lastPriceUpdate: DateTime.now(),
            dynamicData: jsonEncode({'set_code': '3ed'}),
            primaryBinderId: const drift.Value(lookingForBinderId),
          ),
        );
      }

      // Pre-condition: totals are 0
      final preTotals = await dao.getVaultTotals();
      expect(preTotals.totalCount, equals(0));
      expect(preTotals.totalMarketValue, equals(0.0));

      // 2. Move items to Trade Block binder
      final assignedCount = await dao.assignItemsToBinder(cardIds, tradeBlockBinderId);
      expect(assignedCount, equals(cardCount));

      // 3. Post-condition: cards immediately become owned and add to totals
      final postTotals = await dao.getVaultTotals();
      expect(postTotals.totalCount, equals(10));
      expect(postTotals.totalMarketValue, equals(cardCount * pricePerCard)); // $60,000.0

      final streamTotals = await dao.watchVaultTotals().first;
      expect(streamTotals.totalCount, equals(10));
      expect(streamTotals.totalMarketValue, equals(60000.0));

      // 4. Singles inventory reflects the 10 owned cards
      final ownedSingles = await dao.getItemsByCollection('mtg', onlyOwned: true);
      expect(ownedSingles.length, equals(10));
      expect(ownedSingles.map((c) => c.id).toSet(), equals(cardIds.toSet()));

      final singlesCount = await dao.watchFilteredItemCount('mtg', onlyOwned: true).first;
      expect(singlesCount, equals(10));

      // 5. Collection counts reflect the 10 owned cards
      final counts = await dao.watchCollectionItemCounts().first;
      expect(counts['mtg'], equals(10));
      expect(counts['all'], equals(10));

      // 6. Set collections reflect owned cards
      final setCollections = await dao.watchSetCollections(collectionType: 'mtg').first;
      expect(setCollections.first.ownedCount, equals(10));
      expect(setCollections.first.completionPercentage, equals(1.0));
    });

    test('Trade Block cards are strictly owned until traded (isTraded = true)', () async {
      // 1. Insert 5 cards into Trade Block
      final tradeCardIds = <String>[];
      const cardPrice = 1000.0;
      for (int i = 0; i < 5; i++) {
        final id = 'c_tb_item_$i';
        tradeCardIds.add(id);
        await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: id,
            collectionType: 'mtg',
            name: 'Trade Card #$i',
            setOrSeries: 'Legends',
            imageUrl: '',
            acquiredPrice: 800.0,
            acquiredDate: DateTime.now(),
            quantity: const drift.Value(1),
            condition: 'NM',
            currentMarketPrice: cardPrice,
            lastPriceUpdate: DateTime.now(),
            dynamicData: jsonEncode({'set_code': 'leg'}),
            primaryBinderId: const drift.Value(tradeBlockBinderId),
            isTraded: const drift.Value(false),
          ),
        );
      }

      // Assert Trade Block cards are owned
      final initialTotals = await dao.getVaultTotals();
      expect(initialTotals.totalCount, equals(5));
      expect(initialTotals.totalMarketValue, equals(5000.0));

      // 2. Mark 2 cards as traded (isTraded = true)
      final tradedIds = [tradeCardIds[0], tradeCardIds[1]];
      await (db.update(db.vaultItems)..where((t) => t.id.isIn(tradedIds))).write(
        const VaultItemsCompanion(
          isTraded: drift.Value(true),
        ),
      );

      // 3. Assert traded cards are immediately excluded from totals
      final postTradeTotals = await dao.getVaultTotals();
      expect(postTradeTotals.totalCount, equals(3), reason: 'Traded cards must be subtracted from totalCount');
      expect(postTradeTotals.totalMarketValue, equals(3000.0), reason: 'Traded cards must be subtracted from totalMarketValue');

      // 4. Assert singles inventory excludes traded cards
      final ownedSingles = await dao.getItemsByCollection('mtg', onlyOwned: true);
      expect(ownedSingles.length, equals(3));
      expect(ownedSingles.any((c) => tradedIds.contains(c.id)), isFalse);

      // 5. Assert collection counts and set completion exclude traded cards
      final counts = await dao.watchCollectionItemCounts().first;
      expect(counts['mtg'], equals(3));

      final sets = await dao.watchSetCollections(collectionType: 'mtg').first;
      expect(sets.first.ownedCount, equals(3));
    });
  });

  group('Adversarial Widget Test: MasterSetScreen Looking For Exclusion', () {
    testWidgets('MasterSetScreen displays Looking For cards as unowned ("Missing", grayscale) with 0% completion', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const setCode = '2ed';
      const setName = 'Unlimited Edition';

      // Insert 3 cards in Looking For binder and 1 catalog card (quantity 0)
      final cardLf1 = VaultItemsCompanion.insert(
        id: 'c_unl_black_lotus',
        collectionType: 'mtg',
        name: 'Black Lotus',
        setOrSeries: setName,
        imageUrl: 'https://cards.scryfall.io/normal/lotus.jpg',
        acquiredPrice: 0.0,
        acquiredDate: DateTime.now(),
        quantity: const drift.Value(1),
        condition: 'NM',
        currentMarketPrice: 85000.0,
        lastPriceUpdate: DateTime.now(),
        dynamicData: jsonEncode({
          'set_code': setCode,
          'collector_number': '1',
          'rarity': 'rare',
        }),
        primaryBinderId: const drift.Value(lookingForBinderId),
      );

      final cardLf2 = VaultItemsCompanion.insert(
        id: 'c_unl_mox_sapphire',
        collectionType: 'mtg',
        name: 'Mox Sapphire',
        setOrSeries: setName,
        imageUrl: 'https://cards.scryfall.io/normal/mox_sapphire.jpg',
        acquiredPrice: 0.0,
        acquiredDate: DateTime.now(),
        quantity: const drift.Value(2),
        condition: 'NM',
        currentMarketPrice: 20000.0,
        lastPriceUpdate: DateTime.now(),
        dynamicData: jsonEncode({
          'set_code': setCode,
          'collector_number': '2',
          'rarity': 'rare',
        }),
        primaryBinderId: const drift.Value(lookingForBinderId),
      );

      final cardLf3 = VaultItemsCompanion.insert(
        id: 'c_unl_time_walk',
        collectionType: 'mtg',
        name: 'Time Walk',
        setOrSeries: setName,
        imageUrl: 'https://cards.scryfall.io/normal/time_walk.jpg',
        acquiredPrice: 0.0,
        acquiredDate: DateTime.now(),
        quantity: const drift.Value(1),
        condition: 'NM',
        currentMarketPrice: 22000.0,
        lastPriceUpdate: DateTime.now(),
        dynamicData: jsonEncode({
          'set_code': setCode,
          'collector_number': '3',
          'rarity': 'rare',
        }),
        primaryBinderId: const drift.Value(lookingForBinderId),
      );

      final cardCatalog = VaultItemsCompanion.insert(
        id: 'c_unl_ancestral_recall',
        collectionType: 'mtg',
        name: 'Ancestral Recall',
        setOrSeries: setName,
        imageUrl: 'https://cards.scryfall.io/normal/recall.jpg',
        acquiredPrice: 0.0,
        acquiredDate: DateTime.now(),
        quantity: const drift.Value(0),
        condition: 'NM',
        currentMarketPrice: 30000.0,
        lastPriceUpdate: DateTime.now(),
        dynamicData: jsonEncode({
          'set_code': setCode,
          'collector_number': '4',
          'rarity': 'rare',
        }),
      );

      await db.into(db.vaultItems).insert(cardLf1);
      await db.into(db.vaultItems).insert(cardLf2);
      await db.into(db.vaultItems).insert(cardLf3);
      await db.into(db.vaultItems).insert(cardCatalog);

      const collection = VaultSetCollection(
        setName: setName,
        setCode: setCode,
        collectionType: 'mtg',
        totalCount: 4,
        ownedCount: 0,
        completionPercentage: 0.0,
      );

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(dao),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: MasterSetScreen(
              collection: collection,
              activeGame: 'mtg',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Completion header must show 0 / 4 and 0.0% complete
      expect(find.text('0 / 4'), findsOneWidget, reason: 'Header must report 0 owned out of 4 cards');
      expect(find.text('0.0% complete'), findsOneWidget, reason: 'Completion percentage must be strictly 0.0%');

      // 2. Filter chips show Owned (0) and Missing (4)
      expect(find.text('All (4)'), findsOneWidget);
      expect(find.text('Owned (0)'), findsOneWidget);
      expect(find.text('Missing (4)'), findsOneWidget);

      // 3. All 4 cards must have grayscale color filter and 'Missing' badge
      expect(find.byKey(const Key('master_set_grayscale_c_unl_black_lotus')), findsOneWidget);
      expect(find.byKey(const Key('master_set_grayscale_c_unl_mox_sapphire')), findsOneWidget);
      expect(find.byKey(const Key('master_set_grayscale_c_unl_time_walk')), findsOneWidget);
      expect(find.byKey(const Key('master_set_grayscale_c_unl_ancestral_recall')), findsOneWidget);

      // 4. 'Missing' text appears for all cards
      expect(find.text('Missing'), findsNWidgets(4));

      // 5. Zero cards have 'x1' or 'x2' badges
      expect(find.text('x1'), findsNothing);
      expect(find.text('x2'), findsNothing);

      // 6. Test Owned filter chip: tapping Owned shows 0 cards and empty message
      await tester.tap(find.text('Owned (0)'));
      await tester.pumpAndSettle();
      expect(find.text('No cards match your filter criteria'), findsOneWidget);

      // 7. Test Missing filter chip: tapping Missing shows all 4 cards
      await tester.tap(find.text('Missing (4)'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('master_set_card_c_unl_black_lotus')), findsOneWidget);
      expect(find.byKey(const Key('master_set_card_c_unl_ancestral_recall')), findsOneWidget);

      // 8. Now transition Black Lotus to Trade Block: must immediately become owned!
      await dao.assignItemsToBinder(['c_unl_black_lotus'], tradeBlockBinderId);
      await tester.pumpAndSettle();

      // Switch filter back to All
      await tester.tap(find.text('All (4)'));
      await tester.pumpAndSettle();

      // Header updates to 1 / 4 and 25.0% complete
      expect(find.text('1 / 4'), findsOneWidget);
      expect(find.text('25.0% complete'), findsOneWidget);
      expect(find.text('Owned (1)'), findsOneWidget);
      expect(find.text('Missing (3)'), findsOneWidget);

      // Black Lotus now has 'x1' and grayscale is removed
      expect(find.byKey(const Key('master_set_grayscale_c_unl_black_lotus')), findsNothing);
      expect(find.text('x1'), findsOneWidget);

      // 9. Now mark Black Lotus as traded (isTraded = true): must revert to unowned!
      await (db.update(db.vaultItems)..where((t) => t.id.equals('c_unl_black_lotus'))).write(
        const VaultItemsCompanion(isTraded: drift.Value(true)),
      );
      await tester.pumpAndSettle();

      // Header reverts to 0 / 4 and 0.0% complete
      expect(find.text('0 / 4'), findsOneWidget);
      expect(find.text('0.0% complete'), findsOneWidget);
      expect(find.text('Owned (0)'), findsOneWidget);
      expect(find.text('Missing (4)'), findsOneWidget);

      // Grayscale restored to Black Lotus
      expect(find.byKey(const Key('master_set_grayscale_c_unl_black_lotus')), findsOneWidget);
    });

    testWidgets('MasterSetScreen in-set search with Looking For cards preserves Missing badge and grayscale', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const setCode = 'lea';
      const setName = 'Limited Edition Alpha';

      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'c_alpha_lotus_search',
          collectionType: 'mtg',
          name: 'Black Lotus',
          setOrSeries: setName,
          imageUrl: '',
          acquiredPrice: 0.0,
          acquiredDate: DateTime.now(),
          quantity: const drift.Value(1),
          condition: 'NM',
          currentMarketPrice: 150000.0,
          lastPriceUpdate: DateTime.now(),
          dynamicData: jsonEncode({
            'set_code': setCode,
            'collector_number': '101',
          }),
          primaryBinderId: const drift.Value(lookingForBinderId),
        ),
      );

      const collection = VaultSetCollection(
        setName: setName,
        setCode: setCode,
        collectionType: 'mtg',
        totalCount: 1,
        ownedCount: 0,
        completionPercentage: 0.0,
      );

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(dao),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: MasterSetScreen(
              collection: collection,
              activeGame: 'mtg',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Search for 'Lotus' in in-set search bar
      final searchInput = find.byType(TextField);
      expect(searchInput, findsOneWidget);
      await tester.enterText(searchInput, 'Lotus');
      await tester.pumpAndSettle();

      // Verify card appears, is Missing, and has grayscale filter
      expect(find.byKey(const Key('master_set_card_c_alpha_lotus_search')), findsOneWidget);
      expect(find.byKey(const Key('master_set_grayscale_c_alpha_lotus_search')), findsOneWidget);
      expect(find.text('Missing'), findsOneWidget);
    });
  });

  group('Adversarial Invariant Hardening: Playsets, Multi-Binder Portfolios & Reversals', () {
    test('Playset quantities (4x copies) of high-value cards in Looking For do not leak into counts or values', () async {
      // User wishlist for 4x Underground Sea ($800 each = $3,200)
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'c_playset_underground_sea',
          collectionType: 'mtg',
          name: 'Underground Sea',
          setOrSeries: 'Revised Edition',
          imageUrl: '',
          acquiredPrice: 0.0,
          acquiredDate: DateTime.now(),
          quantity: const drift.Value(4), // Playset requested
          condition: 'NM',
          currentMarketPrice: 800.0,
          lastPriceUpdate: DateTime.now(),
          dynamicData: '{}',
          primaryBinderId: const drift.Value(lookingForBinderId),
        ),
      );

      final totals = await dao.getVaultTotals();
      expect(totals.totalCount, equals(0), reason: '4x quantity in Looking For must still yield 0 owned count');
      expect(totals.totalMarketValue, equals(0.0), reason: '4x quantity in Looking For must still yield \$0.00 value');

      final owned = await dao.getItemsByCollection('mtg', onlyOwned: true);
      expect(owned, isEmpty);
    });

    test('Mixed Binder Portfolio Stress: 10 custom binder, 50 Looking For (\$2.5M), 10 Trade Block (\$100k)', () async {
      // 1. Create a regular user custom binder
      const customBinderId = 'custom_edh_binder_1';
      await db.into(db.vaultBinders).insert(
        VaultBindersCompanion.insert(
          id: customBinderId,
          name: 'EDH Foil Binder',
          collectionType: 'mtg',
          createdAt: DateTime.now(),
          isSystemBinder: const drift.Value(false),
        ),
      );

      // 2. Insert 10 owned cards into custom binder (each $2,000, total $20,000)
      for (int i = 0; i < 10; i++) {
        await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'c_custom_owned_$i',
            collectionType: 'mtg',
            name: 'Custom Card #$i',
            setOrSeries: 'Modern Horizons 2',
            imageUrl: '',
            acquiredPrice: 1500.0,
            acquiredDate: DateTime.now(),
            quantity: const drift.Value(1),
            condition: 'NM',
            currentMarketPrice: 2000.0,
            lastPriceUpdate: DateTime.now(),
            dynamicData: '{}',
            primaryBinderId: const drift.Value(customBinderId),
          ),
        );
      }

      // 3. Insert 50 cards into Looking For (each $50,000, total $2,500,000)
      for (int i = 0; i < 50; i++) {
        await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'c_lf_stress_$i',
            collectionType: 'mtg',
            name: 'Looking For Card #$i',
            setOrSeries: 'Alpha',
            imageUrl: '',
            acquiredPrice: 0.0,
            acquiredDate: DateTime.now(),
            quantity: const drift.Value(1),
            condition: 'NM',
            currentMarketPrice: 50000.0,
            lastPriceUpdate: DateTime.now(),
            dynamicData: '{}',
            primaryBinderId: const drift.Value(lookingForBinderId),
          ),
        );
      }

      // 4. Insert 10 cards into Trade Block (each $10,000, total $100,000)
      for (int i = 0; i < 10; i++) {
        await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'c_tb_stress_$i',
            collectionType: 'mtg',
            name: 'Trade Block Card #$i',
            setOrSeries: 'Beta',
            imageUrl: '',
            acquiredPrice: 8000.0,
            acquiredDate: DateTime.now(),
            quantity: const drift.Value(1),
            condition: 'NM',
            currentMarketPrice: 10000.0,
            lastPriceUpdate: DateTime.now(),
            dynamicData: '{}',
            primaryBinderId: const drift.Value(tradeBlockBinderId),
            isTraded: const drift.Value(false),
          ),
        );
      }

      // Total owned should be strictly:
      // Custom Binder (10 * $2,000 = $20,000) + Trade Block (10 * $10,000 = $100,000) = 20 cards, $120,000.0
      // Looking For ($2,500,000 across 50 cards) must have 0% leakage!
      final totals = await dao.getVaultTotals();
      expect(totals.totalCount, equals(20), reason: 'Total count must be exactly 10 custom + 10 trade block = 20');
      expect(totals.totalMarketValue, equals(120000.0), reason: 'Total market value must strictly be \$120,000.0 without \$2.5M wishlist leakage');

      final streamTotals = await dao.watchVaultTotals().first;
      expect(streamTotals.totalCount, equals(20));
      expect(streamTotals.totalMarketValue, equals(120000.0));

      final ownedSingles = await dao.getItemsByCollection('mtg', onlyOwned: true);
      expect(ownedSingles.length, equals(20));

      final counts = await dao.watchCollectionItemCounts().first;
      expect(counts['mtg'], equals(20));
    });

    test('Trade Reversal / Undo Invariant: Marking isTraded = false restores card to owned inventory', () async {
      const cardId = 'c_traded_then_reversed';
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: cardId,
          collectionType: 'mtg',
          name: 'Gaea\'s Cradle',
          setOrSeries: 'Urza\'s Saga',
          imageUrl: '',
          acquiredPrice: 600.0,
          acquiredDate: DateTime.now(),
          quantity: const drift.Value(1),
          condition: 'NM',
          currentMarketPrice: 900.0,
          lastPriceUpdate: DateTime.now(),
          dynamicData: '{}',
          primaryBinderId: const drift.Value(tradeBlockBinderId),
          isTraded: const drift.Value(true), // initially traded
        ),
      );

      // Pre-condition: traded card is not counted
      final preTotals = await dao.getVaultTotals();
      expect(preTotals.totalCount, equals(0));
      expect(preTotals.totalMarketValue, equals(0.0));

      // Undo trade: isTraded = false
      await (db.update(db.vaultItems)..where((t) => t.id.equals(cardId))).write(
        const VaultItemsCompanion(isTraded: drift.Value(false)),
      );

      // Post-condition: card is restored
      final postTotals = await dao.getVaultTotals();
      expect(postTotals.totalCount, equals(1));
      expect(postTotals.totalMarketValue, equals(900.0));

      final owned = await dao.getItemsByCollection('mtg', onlyOwned: true);
      expect(owned.length, equals(1));
      expect(owned.first.id, equals(cardId));
    });

    test('Multi-TCG Collection Count: Pokémon and MTG Looking For cards do not leak into respective counters', () async {
      // Insert MTG Looking For card ($10,000)
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'c_mtg_lf',
          collectionType: 'mtg',
          name: 'Timetwister',
          setOrSeries: 'Unlimited Edition',
          imageUrl: '',
          acquiredPrice: 0.0,
          acquiredDate: DateTime.now(),
          quantity: const drift.Value(1),
          condition: 'NM',
          currentMarketPrice: 10000.0,
          lastPriceUpdate: DateTime.now(),
          dynamicData: '{}',
          primaryBinderId: const drift.Value(lookingForBinderId),
        ),
      );

      // Insert Pokémon Looking For binder and card ($25,000 1st Ed Charizard)
      const pokeLfBinderId = 'system_looking_for_poke_$testUserId';
      await db.into(db.vaultBinders).insert(
        VaultBindersCompanion.insert(
          id: pokeLfBinderId,
          name: 'Looking For',
          collectionType: 'pokemon',
          createdAt: DateTime.now(),
          systemBinderType: const drift.Value('looking_for'),
          isSystemBinder: const drift.Value(true),
        ),
      );

      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'c_poke_charizard_lf',
          collectionType: 'pokemon',
          name: 'Charizard 1st Edition Base Set',
          setOrSeries: 'Base Set',
          imageUrl: '',
          acquiredPrice: 0.0,
          acquiredDate: DateTime.now(),
          quantity: const drift.Value(1),
          condition: 'NM',
          currentMarketPrice: 25000.0,
          lastPriceUpdate: DateTime.now(),
          dynamicData: '{}',
          primaryBinderId: const drift.Value(pokeLfBinderId),
        ),
      );

      final counts = await dao.watchCollectionItemCounts().first;
      expect(counts['mtg'], equals(0));
      expect(counts['pokemon'], equals(0));
      expect(counts['all'], equals(0));
    });
  });
}
