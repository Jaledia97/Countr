import 'dart:convert';
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
import 'package:countr/features/vault/presentation/widgets/manual_add_bottom_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late VaultDao dao;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dao = db.vaultDao;
    await dao.seedDatabase();

    // Insert additional unowned catalog reference card (quantity = 0)
    await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'catalog-sol-ring',
            collectionType: 'mtg',
            name: 'Sol Ring',
            setOrSeries: 'Commander Masters',
            imageUrl: '',
            acquiredPrice: 0.0,
            acquiredDate: DateTime.now(),
            quantity: const drift.Value(0),
            condition: 'NM',
            currentMarketPrice: 2.50,
            lastPriceUpdate: DateTime.now(),
            dynamicData: jsonEncode({
              'rarity': 'uncommon',
              'type': 'Artifact',
            }),
          ),
        );

    // Insert additional owned card (quantity = 1)
    await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'item-mtg-black-lotus',
            collectionType: 'mtg',
            name: 'Black Lotus',
            setOrSeries: 'Limited Edition Alpha',
            imageUrl: '',
            acquiredPrice: 10000.0,
            acquiredDate: DateTime.now(),
            quantity: const drift.Value(1),
            condition: 'NM',
            currentMarketPrice: 25000.0,
            lastPriceUpdate: DateTime.now(),
            dynamicData: jsonEncode({
              'rarity': 'rare',
              'type': 'Artifact',
            }),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  group('VaultDao.searchCatalogCards Unit Tests', () {
    test('Searches by card name case-insensitively', () async {
      final resultsLower = await dao.searchCatalogCards('sol ring');
      expect(resultsLower.length, 1);
      expect(resultsLower.first.id, 'catalog-sol-ring');
      expect(resultsLower.first.name, 'Sol Ring');

      final resultsUpper = await dao.searchCatalogCards('SOL RING');
      expect(resultsUpper.length, 1);
      expect(resultsUpper.first.id, 'catalog-sol-ring');

      final resultsPartial = await dao.searchCatalogCards('lotus');
      expect(resultsPartial.length, 1);
      expect(resultsPartial.first.name, 'Black Lotus');
    });

    test('Searches by set or series case-insensitively', () async {
      final results = await dao.searchCatalogCards('Commander Masters');
      expect(results.length, 1);
      expect(results.first.name, 'Sol Ring');

      final resultsLower = await dao.searchCatalogCards('masters');
      expect(resultsLower.length, 1);
      expect(resultsLower.first.name, 'Sol Ring');
    });

    test('Filters results by normalized collection type', () async {
      // MTG search should find Sol Ring and Black Lotus
      final mtgResults = await dao.searchCatalogCards('', collectionType: 'mtg');
      expect(mtgResults.any((c) => c.name == 'Sol Ring'), isTrue);
      expect(mtgResults.any((c) => c.name == 'Black Lotus'), isTrue);
      expect(mtgResults.any((c) => c.name.contains('Charizard')), isFalse);

      // Pokemon search should find Charizard but not Sol Ring
      final pkmResults =
          await dao.searchCatalogCards('', collectionType: 'Pokémon');
      expect(pkmResults.any((c) => c.name.contains('Charizard')), isTrue);
      expect(pkmResults.any((c) => c.name == 'Sol Ring'), isFalse);

      // All collections should include all
      final allResults =
          await dao.searchCatalogCards('', collectionType: 'all');
      expect(allResults.length, greaterThanOrEqualTo(5));
    });

    test('Orders results alphabetically by name ASC and respects limit', () async {
      final results = await dao.searchCatalogCards('', limit: 2);
      expect(results.length, 2);
      expect(results[0].name.compareTo(results[1].name), lessThanOrEqualTo(0));
    });
  });

  group('VaultDao.bulkAddCatalogItems Transaction Tests', () {
    test('Converts unowned catalog card (quantity == 0) to owned', () async {
      // Before bulk add: Sol Ring has quantity 0, acquiredPrice 0
      final before = await (db.select(db.vaultItems)
            ..where((t) => t.id.equals('catalog-sol-ring')))
          .getSingle();
      expect(before.quantity, 0);

      await dao.bulkAddCatalogItems(
        stagedItems: {'catalog-sol-ring': 3},
        targetBinderId: 'binder-alpha',
      );

      final after = await (db.select(db.vaultItems)
            ..where((t) => t.id.equals('catalog-sol-ring')))
          .getSingle();
      expect(after.quantity, 3);
      expect(after.primaryBinderId, 'binder-alpha');
      // Acquired price takes currentMarketPrice (2.50) when acquiredPrice was 0
      expect(after.acquiredPrice, 2.50);
    });

    test('Increments owned card (quantity > 0) and updates binder if provided', () async {
      // Before bulk add: Black Lotus has quantity 1, acquiredPrice 10000.0
      final before = await (db.select(db.vaultItems)
            ..where((t) => t.id.equals('item-mtg-black-lotus')))
          .getSingle();
      expect(before.quantity, 1);

      await dao.bulkAddCatalogItems(
        stagedItems: {'item-mtg-black-lotus': 2},
        targetBinderId: 'binder-vintage',
      );

      final after = await (db.select(db.vaultItems)
            ..where((t) => t.id.equals('item-mtg-black-lotus')))
          .getSingle();
      expect(after.quantity, 3); // 1 + 2
      expect(after.primaryBinderId, 'binder-vintage');
      expect(after.acquiredPrice, 10000.0); // Preserves existing acquired price
    });

    test('Preserves existing primaryBinderId when targetBinderId is null for owned card', () async {
      // Set existing binder
      await (db.update(db.vaultItems)
            ..where((t) => t.id.equals('item-mtg-black-lotus')))
          .write(
        const VaultItemsCompanion(
          primaryBinderId: drift.Value('existing-binder'),
        ),
      );

      await dao.bulkAddCatalogItems(
        stagedItems: {'item-mtg-black-lotus': 1},
        targetBinderId: null,
      );

      final after = await (db.select(db.vaultItems)
            ..where((t) => t.id.equals('item-mtg-black-lotus')))
          .getSingle();
      expect(after.quantity, 2);
      expect(after.primaryBinderId, 'existing-binder');
    });

    test('Executes atomic transaction updating multiple items and updates VaultTotals', () async {
      final initialTotals =
          await dao.watchVaultTotals(collectionType: 'mtg').first;
      final initialCount = initialTotals.totalCount;

      await dao.bulkAddCatalogItems(
        stagedItems: {
          'catalog-sol-ring': 2,
          'item-mtg-black-lotus': 3,
        },
        targetBinderId: 'test-binder',
      );

      final updatedTotals =
          await dao.watchVaultTotals(collectionType: 'mtg').first;
      // Sol Ring went from 0 -> 2 (+2)
      // Black Lotus went from 1 -> 4 (+3)
      // Net change = +5 items
      expect(updatedTotals.totalCount, initialCount + 5);
      expect(
        updatedTotals.totalMarketValue,
        closeTo(initialTotals.totalMarketValue + (2 * 2.50) + (3 * 25000.0), 0.01),
      );
    });

    test('Ignores empty stagedItems map and zero/negative quantities safely', () async {
      await dao.bulkAddCatalogItems(stagedItems: {});
      await dao.bulkAddCatalogItems(
        stagedItems: {'catalog-sol-ring': 0, 'item-mtg-black-lotus': -2},
      );

      final solRing = await (db.select(db.vaultItems)
            ..where((t) => t.id.equals('catalog-sol-ring')))
          .getSingle();
      expect(solRing.quantity, 0);
    });
  });

  group('ManualAddBottomSheet Widget & Interaction Tests', () {
    Widget buildTestApp({Widget? child}) {
      return ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: child ?? const ManualAddBottomSheet(),
          ),
        ),
      );
    }

    testWidgets('Renders initial default catalog cards, search field, and title',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Add Cards to Vault'), findsOneWidget);
      expect(find.byType(SearchField), findsOneWidget);
      expect(find.text('Sol Ring'), findsOneWidget);
      expect(find.text('Black Lotus'), findsOneWidget);
      expect(find.text('\$2.50'), findsOneWidget);
      expect(find.text('\$25000.00'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('Debounced search filters catalog cards in SQLite after 300ms',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Sol Ring'), findsOneWidget);
      expect(find.text('Black Lotus'), findsOneWidget);

      // Type search query
      await tester.enterText(find.byType(SearchField), 'Lotus');

      // Before debounce timer fires (< 300ms), Sol Ring is still visible
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('Sol Ring'), findsOneWidget);

      // Advance past 300ms debounce
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      // Now only Black Lotus is shown
      expect(find.text('Black Lotus'), findsOneWidget);
      expect(find.text('Sol Ring'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('Clear button restores default catalog card results',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Enter search query
      await tester.enterText(find.byType(SearchField), 'Lotus');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.text('Black Lotus'), findsOneWidget);
      expect(find.text('Sol Ring'), findsNothing);

      // Tap clear icon button
      await tester.tap(find.byKey(const Key('search_field_clear_button')));
      await tester.pumpAndSettle();

      // Both cards restored
      expect(find.text('Black Lotus'), findsOneWidget);
      expect(find.text('Sol Ring'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('Quantity stepper increments, decrements, and toggles sticky action bar',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Sticky action bar initially hidden
      expect(find.byKey(const Key('bulk_add_submit_button')), findsNothing);

      // Tap [+] on Sol Ring
      await tester.tap(find.byKey(const Key('stepper_increment_catalog-sol-ring')));
      await tester.pumpAndSettle();

      // Stepper shows 1
      expect(find.byKey(const Key('stepper_count_catalog-sol-ring')), findsOneWidget);
      expect(find.text('1'), findsOneWidget);

      // Sticky action bar visible with "Add 1 Item to Vault"
      expect(find.byKey(const Key('bulk_add_submit_button')), findsOneWidget);
      expect(find.text('Add 1 Item to Vault'), findsOneWidget);

      // Tap [+] again on Sol Ring
      await tester.tap(find.byKey(const Key('stepper_increment_catalog-sol-ring')));
      await tester.pumpAndSettle();
      expect(find.text('Add 2 Items to Vault'), findsOneWidget);

      // Tap [+] on Black Lotus
      await tester.tap(find.byKey(const Key('stepper_increment_item-mtg-black-lotus')));
      await tester.pumpAndSettle();
      expect(find.text('Add 3 Items to Vault'), findsOneWidget);

      // Tap [-] on Sol Ring
      await tester.tap(find.byKey(const Key('stepper_decrement_catalog-sol-ring')));
      await tester.pumpAndSettle();
      expect(find.text('Add 2 Items to Vault'), findsOneWidget);

      // Tap [-] on Sol Ring again -> Sol Ring count is 0
      await tester.tap(find.byKey(const Key('stepper_decrement_catalog-sol-ring')));
      await tester.pumpAndSettle();
      expect(find.text('Add 1 Item to Vault'), findsOneWidget);

      // Tap [-] on Black Lotus -> Total staged is 0, bar disappears
      await tester.tap(find.byKey(const Key('stepper_decrement_item-mtg-black-lotus')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('bulk_add_submit_button')), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('Destination binder selector allows choosing target binder',
        (WidgetTester tester) async {
      // Insert a custom MTG binder
      await db.into(db.vaultBinders).insert(
            VaultBindersCompanion.insert(
              id: 'binder-commander-deck',
              name: 'Commander Staples',
              collectionType: 'mtg',
              createdAt: DateTime.now(),
            ),
          );

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Stage 1 Sol Ring
      await tester.tap(find.byKey(const Key('stepper_increment_catalog-sol-ring')));
      await tester.pumpAndSettle();

      // Verify binder selector is present and defaults to Unsorted
      expect(find.text('Unsorted (Main Vault)'), findsOneWidget);

      // Open binder dropdown
      await tester.tap(find.text('Unsorted (Main Vault)'));
      await tester.pumpAndSettle();

      // Select 'Commander Staples'
      expect(find.text('Commander Staples').last, findsOneWidget);
      await tester.tap(find.text('Commander Staples').last);
      await tester.pumpAndSettle();

      // Verify selected
      expect(find.text('Commander Staples'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('Tapping bulk add button executes SQLite update, pops sheet, and shows SnackBar',
        (WidgetTester tester) async {
      // Insert a custom MTG binder
      await db.into(db.vaultBinders).insert(
            VaultBindersCompanion.insert(
              id: 'binder-commander-deck',
              name: 'Commander Staples',
              collectionType: 'mtg',
              createdAt: DateTime.now(),
            ),
          );

      // Launch via static show()
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => ManualAddBottomSheet.show(context),
                  child: const Text('Open Sheet'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open bottom sheet
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.byType(ManualAddBottomSheet), findsOneWidget);

      // Stage 2 Sol Rings
      await tester.tap(find.byKey(const Key('stepper_increment_catalog-sol-ring')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('stepper_increment_catalog-sol-ring')));
      await tester.pumpAndSettle();

      // Select destination binder
      await tester.tap(find.text('Unsorted (Main Vault)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Commander Staples').last);
      await tester.pumpAndSettle();

      // Tap bulk add button
      await tester.tap(find.byKey(const Key('bulk_add_submit_button')));
      await tester.pumpAndSettle();

      // Bottom sheet popped
      expect(find.byType(ManualAddBottomSheet), findsNothing);

      // SnackBar displayed
      expect(find.text('Added 2 items to Vault'), findsOneWidget);

      // Verify SQLite state
      final solRing = await (db.select(db.vaultItems)
            ..where((t) => t.id.equals('catalog-sol-ring')))
          .getSingle();
      expect(solRing.quantity, 2);
      expect(solRing.primaryBinderId, 'binder-commander-deck');

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('VaultScreen Add Item button opens ManualAddBottomSheet',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(dao),
            activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: VaultScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find and tap the Add Item button in portfolio summary card
      final addButton = find.byKey(const Key('vault_add_item_button'));
      expect(addButton, findsOneWidget);

      await tester.tap(addButton);
      await tester.pumpAndSettle();

      // Sheet is opened
      expect(find.byType(ManualAddBottomSheet), findsOneWidget);
      expect(find.text('Add Cards to Vault'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
