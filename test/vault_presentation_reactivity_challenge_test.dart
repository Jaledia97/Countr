import 'dart:io';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/screens/vault_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Adversarial Challenge: VaultScreen Riverpod Presentation Reactivity', () {
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

    Widget createTestVaultScreen({
      required ProviderContainer container,
    }) {
      return UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: VaultScreen(),
        ),
      );
    }

    Finder findHeaderMarketValue(String value) {
      return find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.data == value &&
            widget.style?.fontSize == 30,
      );
    }

    Finder findHeaderProfitLoss(String textSnippet) {
      return find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            (widget.data?.contains(textSnippet) ?? false) &&
            widget.style?.fontSize == 10.5,
      );
    }

    testWidgets('1. Dynamically updates header statistics on SQLite mutations without manual setState',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(dao),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(createTestVaultScreen(container: container));
      await tester.pumpAndSettle();

      // Initial MTG state: The One Ring (qty 1, market $45.50, cost $15.00)
      expect(find.text('MTG Vault'), findsOneWidget);
      expect(find.text('Total Tracked Items: 1'), findsOneWidget);
      expect(findHeaderMarketValue('\$45.50'), findsOneWidget);
      expect(findHeaderProfitLoss('+203.3% (+\$30.50)'), findsOneWidget);

      // --- MUTATION 1: INSERT a new MTG card into SQLite ---
      await db.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'test-mtg-black-lotus',
              collectionType: 'mtg',
              name: 'Black Lotus',
              setOrSeries: 'Alpha',
              imageUrl: '',
              acquiredPrice: 5000.0,
              acquiredDate: DateTime.now(),
              quantity: const drift.Value(2), // 2 copies
              condition: 'NM',
              currentMarketPrice: 20000.0, // 2 * 20,000 = 40,000
              lastPriceUpdate: DateTime.now(),
              dynamicData: '{}',
            ),
          );

      // Allow Drift stream to trigger and Riverpod to rebuild VaultScreen
      await tester.pumpAndSettle();

      // New expected:
      // Count: 1 + 2 = 3
      // Market value: 45.50 + 40000.00 = 40045.50
      // Cost basis: 15.00 + 10000.00 = 10015.00
      // Delta: 40045.50 - 10015.00 = 30030.50
      // Pct: (30030.50 / 10015.00) * 100 = 299.855... -> 299.9%
      expect(find.text('Total Tracked Items: 3'), findsOneWidget);
      expect(find.text('\$40045.50'), findsOneWidget);
      expect(findHeaderProfitLoss('+299.9% (+\$30030.50)'), findsOneWidget);

      // --- MUTATION 2: UPDATE quantity and price in SQLite ---
      await (db.update(db.vaultItems)..where((t) => t.id.equals('test-mtg-black-lotus'))).write(
            const VaultItemsCompanion(
              quantity: drift.Value(5), // updated from 2 to 5 copies
              currentMarketPrice: drift.Value(25000.0), // updated from 20k to 25k
            ),
          );

      await tester.pumpAndSettle();

      // New expected:
      // Count: 1 + 5 = 6
      // Market value: 45.50 + (5 * 25000) = 125045.50
      // Cost basis: 15.00 + (5 * 5000) = 25015.00
      // Delta: 125045.50 - 25015.00 = 100030.50
      // Pct: (100030.50 / 25015.00) * 100 = 399.88... -> 399.9%
      expect(find.text('Total Tracked Items: 6'), findsOneWidget);
      expect(find.text('\$125045.50'), findsOneWidget);
      expect(findHeaderProfitLoss('+399.9% (+\$100030.50)'), findsOneWidget);

      // --- MUTATION 3: DELETE item from SQLite ---
      await (db.delete(db.vaultItems)..where((t) => t.id.equals('test-mtg-black-lotus'))).go();

      await tester.pumpAndSettle();

      // Should revert back to 1 item
      expect(find.text('Total Tracked Items: 1'), findsOneWidget);
      expect(findHeaderMarketValue('\$45.50'), findsOneWidget);
      expect(findHeaderProfitLoss('+203.3% (+\$30.50)'), findsOneWidget);

      // --- MUTATION 4: DELETE all items (Empty State Boundary) ---
      await dao.clearAllItems();

      await tester.pumpAndSettle();

      // Boundary condition: empty database must render cleanly without crash or NaN
      expect(find.text('Total Tracked Items: 0'), findsOneWidget);
      expect(findHeaderMarketValue('\$0.00'), findsOneWidget);
      expect(findHeaderProfitLoss('+0.0% (+\$0.00)'), findsOneWidget);
    });

    testWidgets('2. Accurately switches totals and title across active collection contexts',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(dao),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(createTestVaultScreen(container: container));
      await tester.pumpAndSettle();

      // Initial: MTG
      expect(find.text('MTG Vault'), findsOneWidget);
      expect(find.text('Total Tracked Items: 1'), findsOneWidget);
      expect(findHeaderMarketValue('\$45.50'), findsOneWidget);

      // Switch to Pokémon TCG via activeGameContextProvider
      container.read(activeGameContextProvider.notifier).state = 'Pokémon TCG';
      await tester.pumpAndSettle();

      // Pokemon: Charizard ex (qty 1, market $3.25, cost $4.50 -> loss $1.25)
      expect(find.text('Pokémon Vault'), findsOneWidget);
      expect(find.text('Total Tracked Items: 1'), findsOneWidget);
      expect(findHeaderMarketValue('\$3.25'), findsOneWidget);
      expect(findHeaderProfitLoss('-27.8% (-\$1.25)'), findsOneWidget);

      // Switch to All Collections
      container.read(activeGameContextProvider.notifier).state = 'All Collections';
      await tester.pumpAndSettle();

      // Macro view: 4 items (MTG + Pokemon + Comics + Sports = $438.75, cost $189.50)
      expect(find.text('My Vault'), findsOneWidget);
      expect(find.text('Total Tracked Items: 4'), findsOneWidget);
      expect(findHeaderMarketValue('\$438.75'), findsOneWidget);
      expect(findHeaderProfitLoss('+131.5% (+\$249.25)'), findsOneWidget);

      // Switch to Comic Books
      container.read(activeGameContextProvider.notifier).state = 'Comic Books';
      await tester.pumpAndSettle();

      // Comics: Ultimate Fallout #4 (qty 1, market $210.00, cost $150.00)
      expect(find.text('Comics Vault'), findsOneWidget);
      expect(find.text('Total Tracked Items: 1'), findsOneWidget);
      expect(findHeaderMarketValue('\$210.00'), findsOneWidget);
      expect(findHeaderProfitLoss('+40.0% (+\$60.00)'), findsOneWidget);

      // Switch to Sports Cards
      container.read(activeGameContextProvider.notifier).state = 'Sports Cards';
      await tester.pumpAndSettle();

      // Sports: T.J. Watt (qty 1, market $180.00, cost $20.00)
      expect(find.text('Sports Vault'), findsOneWidget);
      expect(find.text('Total Tracked Items: 1'), findsOneWidget);
      expect(findHeaderMarketValue('\$180.00'), findsOneWidget);
      expect(findHeaderProfitLoss('+800.0% (+\$160.00)'), findsOneWidget);
    });

    testWidgets('3. UI PopupMenuButton accurately changes collection and updates totals',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(dao),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(createTestVaultScreen(container: container));
      await tester.pumpAndSettle();

      expect(find.text('MTG Vault'), findsOneWidget);
      expect(find.text('Total Tracked Items: 1'), findsOneWidget);

      // Tap the collection dropdown in AppBar
      await tester.tap(find.text('MTG Vault'));
      await tester.pumpAndSettle();

      // Verify PopupMenu contains options and tap 'All Collections'
      expect(find.text('All Collections'), findsOneWidget);
      await tester.tap(find.text('All Collections'));
      await tester.pumpAndSettle();

      // Vault title and totals must reactively update
      expect(find.text('My Vault'), findsOneWidget);
      expect(find.text('Total Tracked Items: 4'), findsOneWidget);
      expect(findHeaderMarketValue('\$438.75'), findsOneWidget);
    });

    testWidgets('4. Mutating an inactive collection does not bleed into the active collection totals',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(dao),
          activeGameContextProvider.overrideWith((ref) => 'Pokémon TCG'),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(createTestVaultScreen(container: container));
      await tester.pumpAndSettle();

      // Currently in Pokémon context
      expect(find.text('Pokémon Vault'), findsOneWidget);
      expect(find.text('Total Tracked Items: 1'), findsOneWidget);
      expect(findHeaderMarketValue('\$3.25'), findsOneWidget);

      // Insert an MTG card into SQLite
      await db.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'item-mtg-mox-ruby',
              collectionType: 'mtg',
              name: 'Mox Ruby',
              setOrSeries: 'Alpha',
              imageUrl: '',
              acquiredPrice: 400.0,
              acquiredDate: DateTime.now(),
              quantity: const drift.Value(1),
              condition: 'NM',
              currentMarketPrice: 4500.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: '{}',
            ),
          );

      await tester.pumpAndSettle();

      // Pokémon view MUST NOT change
      expect(find.text('Pokémon Vault'), findsOneWidget);
      expect(find.text('Total Tracked Items: 1'), findsOneWidget);
      expect(findHeaderMarketValue('\$3.25'), findsOneWidget);

      // Now insert a Pokémon card
      await db.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'item-pokemon-pikachu',
              collectionType: 'pokemon',
              name: 'Pikachu Illustrator',
              setOrSeries: 'Promo',
              imageUrl: '',
              acquiredPrice: 50000.0,
              acquiredDate: DateTime.now(),
              quantity: const drift.Value(1),
              condition: 'NM',
              currentMarketPrice: 200000.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: '{}',
            ),
          );

      await tester.pumpAndSettle();

      // Pokémon view MUST now update to 2 items ($200,003.25)
      expect(find.text('Pokémon Vault'), findsOneWidget);
      expect(find.text('Total Tracked Items: 2'), findsOneWidget);
      expect(findHeaderMarketValue('\$200003.25'), findsOneWidget);

      // Now switch to All Collections - both MTG and Pokémon insertions should be present
      container.read(activeGameContextProvider.notifier).state = 'All Collections';
      await tester.pumpAndSettle();

      // 4 seed + 1 MTG + 1 Pokemon = 6 items
      // 438.75 + 4500.00 + 200000.00 = 204938.75
      expect(find.text('My Vault'), findsOneWidget);
      expect(find.text('Total Tracked Items: 6'), findsOneWidget);
      expect(findHeaderMarketValue('\$204938.75'), findsOneWidget);
    });

    testWidgets('5. Excludes INBOX holding items and quantity=0 catalog reference items from presentation header',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(dao),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(createTestVaultScreen(container: container));
      await tester.pumpAndSettle();

      expect(find.text('Total Tracked Items: 1'), findsOneWidget);
      expect(findHeaderMarketValue('\$45.50'), findsOneWidget);

      // Add an item to INBOX staging binder
      await db.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'item-mtg-inbox',
              collectionType: 'mtg',
              name: 'Inbox Staged Card',
              setOrSeries: 'Staging',
              imageUrl: '',
              acquiredPrice: 10.0,
              acquiredDate: DateTime.now(),
              quantity: const drift.Value(1),
              condition: 'NM',
              currentMarketPrice: 50.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: '{}',
              primaryBinderId: const drift.Value('INBOX'),
            ),
          );

      await tester.pumpAndSettle();

      // INBOX items must be excluded from macro totals
      expect(find.text('Total Tracked Items: 1'), findsOneWidget);
      expect(findHeaderMarketValue('\$45.50'), findsOneWidget);

      // Add a catalog reference item with quantity = 0
      await db.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'item-mtg-catalog-ref',
              collectionType: 'mtg',
              name: 'Catalog Reference Card',
              setOrSeries: 'Alpha',
              imageUrl: '',
              acquiredPrice: 0.0,
              acquiredDate: DateTime.now(),
              quantity: const drift.Value(0),
              condition: 'NM',
              currentMarketPrice: 1000.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: '{}',
            ),
          );

      await tester.pumpAndSettle();

      // Reference items with quantity = 0 must NOT be counted
      expect(find.text('Total Tracked Items: 1'), findsOneWidget);
      expect(findHeaderMarketValue('\$45.50'), findsOneWidget);
    });

    testWidgets('6. Dynamic binder scoping strictly filters presentation header totals',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Create a binder
      await db.into(db.vaultBinders).insert(
            VaultBindersCompanion.insert(
              id: 'binder-top-shelf',
              name: 'Top Shelf MTG',
              collectionType: 'mtg',
              createdAt: DateTime.now(),
            ),
          );

      // Move The One Ring into this binder
      await (db.update(db.vaultItems)..where((t) => t.id.equals('item-mtg-one-ring'))).write(
            const VaultItemsCompanion(
              primaryBinderId: drift.Value('binder-top-shelf'),
            ),
          );

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(dao),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(createTestVaultScreen(container: container));
      await tester.pumpAndSettle();

      // Macro view: still includes items with binders
      expect(find.text('Total Tracked Items: 1'), findsOneWidget);
      expect(findHeaderMarketValue('\$45.50'), findsOneWidget);

      // Scope to the specific binder
      container.read(selectedVaultBinderIdProvider.notifier).state = 'binder-top-shelf';
      await tester.pumpAndSettle();

      expect(find.text('Total Tracked Items: 1'), findsOneWidget);
      expect(findHeaderMarketValue('\$45.50'), findsOneWidget);

      // Add another card outside this binder
      await db.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'item-mtg-unassigned',
              collectionType: 'mtg',
              name: 'Sol Ring',
              setOrSeries: 'Commander',
              imageUrl: '',
              acquiredPrice: 2.0,
              acquiredDate: DateTime.now(),
              quantity: const drift.Value(1),
              condition: 'NM',
              currentMarketPrice: 3.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: '{}',
              primaryBinderId: const drift.Value(null),
            ),
          );

      await tester.pumpAndSettle();

      // Scoped binder header must remain 1 item ($45.50)
      expect(find.text('Total Tracked Items: 1'), findsOneWidget);
      expect(findHeaderMarketValue('\$45.50'), findsOneWidget);

      // Reset binder selection to null (macro view)
      container.read(selectedVaultBinderIdProvider.notifier).state = null;
      await tester.pumpAndSettle();

      // Macro view should now reflect both cards (2 items, $48.50)
      expect(find.text('Total Tracked Items: 2'), findsOneWidget);
      expect(findHeaderMarketValue('\$48.50'), findsOneWidget);
    });

    testWidgets('7. Adversarial verify Add Item button does not manipulate counter state',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(dao),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(createTestVaultScreen(container: container));
      await tester.pumpAndSettle();

      expect(find.text('Total Tracked Items: 1'), findsOneWidget);

      // Tap 'Add Item' button 5 times
      final addButtonFinder = find.text('Add Item');
      expect(addButtonFinder, findsOneWidget);

      for (int i = 0; i < 5; i++) {
        await tester.tap(addButtonFinder);
        await tester.pump();
      }
      await tester.pumpAndSettle();

      // Under the old dummy implementation, this would have become 6.
      // With true reactive Drift SQLite totals, it MUST strictly remain 1.
      expect(find.text('Total Tracked Items: 1'), findsOneWidget);
      expect(find.text('Total Tracked Items: 6'), findsNothing);
    });

    testWidgets('8. Vault header reflects true total item count beyond pagination page limit',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Insert 70 additional MTG items (71 items total, whereas pagination limit is 50)
      final companions = List.generate(70, (i) {
        return VaultItemsCompanion.insert(
          id: 'item-mtg-paginated-$i',
          collectionType: 'mtg',
          name: 'Bulk Card $i',
          setOrSeries: 'Set $i',
          imageUrl: '',
          acquiredPrice: 1.0,
          acquiredDate: DateTime.now(),
          quantity: const drift.Value(1),
          condition: 'NM',
          currentMarketPrice: 2.0,
          lastPriceUpdate: DateTime.now(),
          dynamicData: '{}',
        );
      });

      await db.batch((b) {
        b.insertAll(db.vaultItems, companions);
      });

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(dao),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
          vaultPaginationLimitProvider.overrideWith((ref) => 50),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(createTestVaultScreen(container: container));
      await tester.pumpAndSettle();

      // Total count must be 71 (1 seed + 70 new), NOT capped at 50!
      expect(find.text('Total Tracked Items: 71'), findsOneWidget);
      expect(find.text('Total Tracked Items: 50'), findsNothing);
      // Market value: 45.50 + 140.00 = 185.50
      expect(findHeaderMarketValue('\$185.50'), findsOneWidget);
    });

    testWidgets('9. Financial break-even and massive loss scenarios render cleanly with correct signs',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Clear all items and insert a break-even item (market $100 == cost $100)
      await dao.clearAllItems();
      await db.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'item-mtg-breakeven',
              collectionType: 'mtg',
              name: 'Break-Even Card',
              setOrSeries: 'Base',
              imageUrl: '',
              acquiredPrice: 100.0,
              acquiredDate: DateTime.now(),
              quantity: const drift.Value(1),
              condition: 'NM',
              currentMarketPrice: 100.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: '{}',
            ),
          );

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(dao),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(createTestVaultScreen(container: container));
      await tester.pumpAndSettle();

      expect(find.text('Total Tracked Items: 1'), findsOneWidget);
      expect(findHeaderMarketValue('\$100.00'), findsOneWidget);
      expect(findHeaderProfitLoss('+0.0% (+\$0.00)'), findsOneWidget);

      // Now update to massive loss: market $10.00, cost $100.00 (-$90.00, -90.0%)
      await (db.update(db.vaultItems)..where((t) => t.id.equals('item-mtg-breakeven'))).write(
            const VaultItemsCompanion(
              currentMarketPrice: drift.Value(10.0),
            ),
          );

      await tester.pumpAndSettle();

      expect(findHeaderMarketValue('\$10.00'), findsOneWidget);
      expect(findHeaderProfitLoss('-90.0% (-\$90.00)'), findsOneWidget);
    });

    test('10. Static audit verifies zero traces of _manualItemCount or dummy state in VaultScreen', () {
      final code = File('lib/features/vault/presentation/screens/vault_screen.dart').readAsStringSync();
      expect(code.contains('_manualItemCount'), isFalse,
          reason: '_manualItemCount must be completely eliminated from VaultScreen');
      expect(code.contains('summary.totalItemCount +'), isFalse,
          reason: 'Item count must not add any manual offset to SQLite totals');
    });
  });
}

