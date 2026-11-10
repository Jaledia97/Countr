import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/vault/presentation/providers/mtg_filter_state.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/screens/vault_screen.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_tile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VaultDao Filtered Item Count & Pushdown Tests (Milestone 2 - R4)', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await db.delete(db.vaultItems).go();
    });

    tearDown(() async {
      await db.close();
    });

    test('getFilteredItemCount returns true database total (180) vs 50 paginated slice', () async {
      final now = DateTime.now();

      // Insert 180 matching Red cards (owned) and 20 non-matching Blue cards
      final itemsToInsert = <VaultItemsCompanion>[];
      for (int i = 0; i < 180; i++) {
        itemsToInsert.add(
          VaultItemsCompanion.insert(
            id: 'red_goblin_$i',
            collectionType: 'mtg',
            name: 'Goblin Guide $i',
            setOrSeries: 'Zendikar',
            imageUrl: 'https://cards.scryfall.io/goblin_$i.jpg',
            acquiredPrice: 5.0,
            acquiredDate: now,
            lastPriceUpdate: now,
            currentMarketPrice: 8.0,
            quantity: const Value(1),
            condition: 'NM',
            dynamicData: '{"colors":["R"],"legalities":{"commander":"legal"}}',
          ),
        );
      }

      for (int i = 0; i < 20; i++) {
        itemsToInsert.add(
          VaultItemsCompanion.insert(
            id: 'blue_merfolk_$i',
            collectionType: 'mtg',
            name: 'Merfolk Sovereign $i',
            setOrSeries: 'Lorwyn',
            imageUrl: 'https://cards.scryfall.io/merfolk_$i.jpg',
            acquiredPrice: 2.0,
            acquiredDate: now,
            lastPriceUpdate: now,
            currentMarketPrice: 3.0,
            quantity: const Value(1),
            condition: 'NM',
            dynamicData: '{"colors":["U"],"legalities":{"commander":"legal"}}',
          ),
        );
      }

      await db.batch((b) {
        b.insertAll(db.vaultItems, itemsToInsert);
      });

      const redFilter = MtgFilterState(
        colors: {'R'},
        colorMatchMode: ColorMatchMode.including,
      );

      // 1. Verify getFilteredItemCount returns 180
      final totalCount = await db.vaultDao.getFilteredItemCount(
        'mtg',
        onlyOwned: true,
        mtgFilter: redFilter,
      );
      expect(totalCount, equals(180));

      // 2. Verify paginated fetch with limit 50 only returns 50 rows
      final paginatedSlice = await db.vaultDao.getItemsByCollection(
        'mtg',
        onlyOwned: true,
        mtgFilter: redFilter,
        limit: 50,
      );
      expect(paginatedSlice.length, equals(50));
    });

    test('ColorMatchMode.exactly excludes multi-colored cards in SQL Stage 1 pushdown', () async {
      final now = DateTime.now();

      await db.batch((b) {
        b.insertAll(db.vaultItems, [
          // Monored card
          VaultItemsCompanion.insert(
            id: 'mono_red_1',
            collectionType: 'mtg',
            name: 'Lightning Bolt',
            setOrSeries: 'Alpha',
            imageUrl: 'https://cards.scryfall.io/bolt.jpg',
            acquiredPrice: 2.0,
            acquiredDate: now,
            lastPriceUpdate: now,
            currentMarketPrice: 3.0,
            quantity: const Value(1),
            condition: 'NM',
            dynamicData: '{"colors":["R"],"color_identity":["R"]}',
          ),
          // Red-White card
          VaultItemsCompanion.insert(
            id: 'boros_1',
            collectionType: 'mtg',
            name: 'Lightning Helix',
            setOrSeries: 'Ravnica',
            imageUrl: 'https://cards.scryfall.io/helix.jpg',
            acquiredPrice: 1.0,
            acquiredDate: now,
            lastPriceUpdate: now,
            currentMarketPrice: 2.0,
            quantity: const Value(1),
            condition: 'NM',
            dynamicData: '{"colors":["R","W"],"color_identity":["R","W"]}',
          ),
          // Monowhite card
          VaultItemsCompanion.insert(
            id: 'mono_white_1',
            collectionType: 'mtg',
            name: 'Swords to Plowshares',
            setOrSeries: 'Alpha',
            imageUrl: 'https://cards.scryfall.io/stp.jpg',
            acquiredPrice: 3.0,
            acquiredDate: now,
            lastPriceUpdate: now,
            currentMarketPrice: 4.0,
            quantity: const Value(1),
            condition: 'NM',
            dynamicData: '{"colors":["W"],"color_identity":["W"]}',
          ),
        ]);
      });

      // Exactly Red -> Should match ONLY Lightning Bolt
      const exactlyRed = MtgFilterState(
        colors: {'R'},
        colorMatchMode: ColorMatchMode.exactly,
      );
      final countExactly = await db.vaultDao.getFilteredItemCount(
        'mtg',
        onlyOwned: true,
        mtgFilter: exactlyRed,
      );
      expect(countExactly, equals(1));

      // Including Red -> Should match Lightning Bolt AND Lightning Helix
      const includingRed = MtgFilterState(
        colors: {'R'},
        colorMatchMode: ColorMatchMode.including,
      );
      final countIncluding = await db.vaultDao.getFilteredItemCount(
        'mtg',
        onlyOwned: true,
        mtgFilter: includingRed,
      );
      expect(countIncluding, equals(2));
    });

    test('Ownership status (onlyOwned) filters out catalog items with quantity = 0', () async {
      final now = DateTime.now();

      await db.batch((b) {
        b.insertAll(db.vaultItems, [
          // Owned Red card
          VaultItemsCompanion.insert(
            id: 'owned_card_1',
            collectionType: 'mtg',
            name: 'Shock',
            setOrSeries: 'Stronghold',
            imageUrl: '',
            acquiredPrice: 0.5,
            acquiredDate: now,
            lastPriceUpdate: now,
            currentMarketPrice: 0.5,
            quantity: const Value(2),
            condition: 'NM',
            dynamicData: '{"colors":["R"]}',
          ),
          // Unowned catalog Red card
          VaultItemsCompanion.insert(
            id: 'catalog_card_1',
            collectionType: 'mtg',
            name: 'Chain Lightning',
            setOrSeries: 'Legends',
            imageUrl: '',
            acquiredPrice: 0.0,
            acquiredDate: now,
            lastPriceUpdate: now,
            currentMarketPrice: 5.0,
            quantity: const Value(0),
            condition: 'NM',
            dynamicData: '{"colors":["R"]}',
          ),
        ]);
      });

      const redFilter = MtgFilterState(
        colors: {'R'},
        colorMatchMode: ColorMatchMode.including,
      );

      // In Owned Mode -> 1
      final ownedCount = await db.vaultDao.getFilteredItemCount(
        'mtg',
        onlyOwned: true,
        mtgFilter: redFilter,
      );
      expect(ownedCount, equals(1));

      // In All Cards Catalog Mode -> 2
      final catalogCount = await db.vaultDao.getFilteredItemCount(
        'mtg',
        onlyOwned: false,
        mtgFilter: redFilter,
      );
      expect(catalogCount, equals(2));
    });

    test('watchFilteredItemCount emits reactively when matching items are inserted or deleted', () async {
      final now = DateTime.now();

      const redFilter = MtgFilterState(
        colors: {'R'},
        colorMatchMode: ColorMatchMode.including,
      );

      final countStream = db.vaultDao.watchFilteredItemCount(
        'mtg',
        onlyOwned: true,
        mtgFilter: redFilter,
      );

      expectLater(
        countStream,
        emitsInOrder([
          0, // Initial count
          1, // After inserting 1st matching card
          2, // After inserting 2nd matching card
          1, // After soft-deleting 1st matching card
        ]),
      );

      await Future.delayed(const Duration(milliseconds: 50));
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'reactive_card_1',
          collectionType: 'mtg',
          name: 'Lightning Bolt',
          setOrSeries: 'Alpha',
          imageUrl: '',
          acquiredPrice: 2.0,
          acquiredDate: now,
          lastPriceUpdate: now,
          currentMarketPrice: 3.0,
          quantity: const Value(1),
          condition: 'NM',
          dynamicData: '{"colors":["R"]}',
        ),
      );

      await Future.delayed(const Duration(milliseconds: 50));
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'reactive_card_2',
          collectionType: 'mtg',
          name: 'Shock',
          setOrSeries: 'Stronghold',
          imageUrl: '',
          acquiredPrice: 0.5,
          acquiredDate: now,
          lastPriceUpdate: now,
          currentMarketPrice: 0.5,
          quantity: const Value(1),
          condition: 'NM',
          dynamicData: '{"colors":["R"]}',
        ),
      );

      await Future.delayed(const Duration(milliseconds: 50));
      await (db.update(db.vaultItems)..where((t) => t.id.equals('reactive_card_1')))
          .write(const VaultItemsCompanion(isDeleted: Value(true)));
    });
  });

  group('VaultScreen UI Dynamic Filtered Counter Invariants (R4)', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await db.delete(db.vaultItems).go();
    });

    tearDown(() async {
      await db.close();
    });

    Widget createTestHarness({
      List<Override> extraOverrides = const [],
    }) {
      return ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
          ...extraOverrides,
        ],
        child: const MaterialApp(
          home: VaultScreen(),
        ),
      );
    }

    testWidgets('R4: "showing 180 results" displays true database total when matching items exceed pagination limit', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final now = DateTime.now();

      // Insert 180 bulk cards matching "Goblin"
      final bulkGoblins = <VaultItemsCompanion>[];
      for (int i = 0; i < 180; i++) {
        bulkGoblins.add(
          VaultItemsCompanion.insert(
            id: 'bulk_goblin_$i',
            collectionType: 'mtg',
            name: 'Goblin Guide $i',
            setOrSeries: 'Zendikar',
            imageUrl: 'https://cards.scryfall.io/goblin_$i.jpg',
            acquiredPrice: 5.0,
            acquiredDate: now,
            lastPriceUpdate: now,
            currentMarketPrice: 8.0,
            quantity: const Value(1),
            condition: 'NM',
            dynamicData: '{"colors":["R"],"legalities":{"commander":"legal"}}',
          ),
        );
      }

      await db.batch((b) {
        b.insertAll(db.vaultItems, bulkGoblins);
      });

      await tester.pumpWidget(createTestHarness());
      await tester.pumpAndSettle();

      // Unfiltered -> counter should NOT be displayed
      expect(find.byKey(const Key('vault_showing_results_counter')), findsNothing);

      // Search for "Goblin"
      await tester.tap(find.byKey(const Key('vault_search_expand_button')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('vault_search_text_field')), 'Goblin');
      await tester.pumpAndSettle();

      // 1. Verify rendered sliver items are bounded by viewport and FLUTTER_TEST pagination batch size (50)
      expect(find.byType(VaultItemTile), findsWidgets);
      expect(find.byType(VaultItemTile).evaluate().length, lessThanOrEqualTo(50));

      // 2. Verify counter shows TRUE database count: "showing 180 results"
      expect(find.byKey(const Key('vault_showing_results_counter')), findsOneWidget);
      expect(find.text('showing 180 results'), findsOneWidget);
    });

    testWidgets('R4: Singular grammar "showing 1 result" and zero results "showing 0 results"', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final now = DateTime.now();

      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'single_lotus',
          collectionType: 'mtg',
          name: 'Black Lotus',
          setOrSeries: 'Alpha',
          imageUrl: 'https://cards.scryfall.io/lotus.jpg',
          acquiredPrice: 10000.0,
          acquiredDate: now,
          lastPriceUpdate: now,
          currentMarketPrice: 25000.0,
          quantity: const Value(1),
          condition: 'NM',
          dynamicData: '{"colors":[]}',
        ),
      );

      await tester.pumpWidget(createTestHarness());
      await tester.pumpAndSettle();

      // Search for single item "Lotus"
      await tester.tap(find.byKey(const Key('vault_search_expand_button')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('vault_search_text_field')), 'Lotus');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('vault_showing_results_counter')), findsOneWidget);
      expect(find.text('showing 1 result'), findsOneWidget);

      // Search for non-existent item "NonExistentCard"
      await tester.enterText(find.byKey(const Key('vault_search_text_field')), 'NonExistentCard');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('vault_showing_results_counter')), findsOneWidget);
      expect(find.text('showing 0 results'), findsOneWidget);
    });
  });
}
