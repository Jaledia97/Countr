import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/manual_add_bottom_sheet.dart';
import 'package:countr/features/vault/presentation/widgets/multi_deck_allocation_sheet.dart';

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

  group('VaultDao Search Engine Weighted Ranking Tests (Phase 4.3 M1)', () {
    test('Querying "aether" ranks Tier 1 (prefix) < Tier 1.5 ("The " bypass) < Tier 2 (substring)', () async {
      final now = DateTime.now();

      // Seed cards in non-alphabetical and reversed rank order
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-serum',
          collectionType: 'mtg',
          name: 'Serum Aether',
          flavorName: const drift.Value.absent(),
          setOrSeries: 'Fifth Dawn',
          imageUrl: 'https://example.com/serum.jpg',
          acquiredPrice: 3.0,
          acquiredDate: now.subtract(const Duration(days: 1)),
          quantity: const drift.Value(1),
          condition: 'NM',
          currentMarketPrice: 3.5,
          lastPriceUpdate: now,
          dynamicData: '{}',
        ),
      );

      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-res',
          collectionType: 'mtg',
          name: 'The Aether Reservoir',
          flavorName: const drift.Value.absent(),
          setOrSeries: 'Kaladesh',
          imageUrl: 'https://example.com/res.jpg',
          acquiredPrice: 15.0,
          acquiredDate: now.subtract(const Duration(days: 2)),
          quantity: const drift.Value(1),
          condition: 'NM',
          currentMarketPrice: 18.0,
          lastPriceUpdate: now,
          dynamicData: '{}',
        ),
      );

      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-vial',
          collectionType: 'mtg',
          name: 'Aether Vial',
          flavorName: const drift.Value.absent(),
          setOrSeries: 'Darksteel',
          imageUrl: 'https://example.com/vial.jpg',
          acquiredPrice: 40.0,
          acquiredDate: now.subtract(const Duration(days: 3)),
          quantity: const drift.Value(1),
          condition: 'NM',
          currentMarketPrice: 45.0,
          lastPriceUpdate: now,
          dynamicData: '{}',
        ),
      );

      // 1. Test getItemsByCollection
      final getResults = await dao.getItemsByCollection('mtg', searchQuery: 'aether');
      expect(getResults.length, 3);
      expect(getResults[0].name, 'Aether Vial', reason: 'Tier 1 prefix must rank 1st');
      expect(getResults[1].name, 'The Aether Reservoir', reason: 'Tier 1.5 "The " bypass must rank 2nd');
      expect(getResults[2].name, 'Serum Aether', reason: 'Tier 2 substring must rank 3rd');

      // 2. Test watchItemsByCollection stream
      final watchResults = await dao.watchItemsByCollection('mtg', searchQuery: 'aether').first;
      expect(watchResults.length, 3);
      expect(watchResults[0].name, 'Aether Vial');
      expect(watchResults[1].name, 'The Aether Reservoir');
      expect(watchResults[2].name, 'Serum Aether');

      // 3. Test searchCatalogCards
      final catalogResults = await dao.searchCatalogCards('aether', collectionType: 'mtg');
      expect(catalogResults.length, 3);
      expect(catalogResults[0].name, 'Aether Vial');
      expect(catalogResults[1].name, 'The Aether Reservoir');
      expect(catalogResults[2].name, 'Serum Aether');
    });

    test('Flavor name search matches and calculates rank identically to name', () async {
      final now = DateTime.now();

      // Card A: flavor name starts with "Adamantium" (Tier 1)
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-ozolith',
          collectionType: 'mtg',
          name: 'The Ozolith',
          flavorName: const drift.Value('Adamantium Bonding Tank'),
          setOrSeries: 'SLD',
          imageUrl: 'https://example.com/ozolith.jpg',
          acquiredPrice: 20.0,
          acquiredDate: now,
          quantity: const drift.Value(1),
          condition: 'NM',
          currentMarketPrice: 25.0,
          lastPriceUpdate: now,
          dynamicData: '{}',
        ),
      );

      // Card B: flavor name starts with "The Adamantium" (Tier 1.5)
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-battery',
          collectionType: 'mtg',
          name: 'Arcane Signet',
          flavorName: const drift.Value('The Adamantium Battery'),
          setOrSeries: 'SLD',
          imageUrl: 'https://example.com/signet.jpg',
          acquiredPrice: 10.0,
          acquiredDate: now,
          quantity: const drift.Value(1),
          condition: 'NM',
          currentMarketPrice: 12.0,
          lastPriceUpdate: now,
          dynamicData: '{}',
        ),
      );

      // Card C: flavor name contains "Adamantium" in the middle (Tier 2)
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-hammer',
          collectionType: 'mtg',
          name: 'Colossus Hammer',
          flavorName: const drift.Value('Refined Adamantium Spire'),
          setOrSeries: 'SLD',
          imageUrl: 'https://example.com/hammer.jpg',
          acquiredPrice: 5.0,
          acquiredDate: now,
          quantity: const drift.Value(1),
          condition: 'NM',
          currentMarketPrice: 6.0,
          lastPriceUpdate: now,
          dynamicData: '{}',
        ),
      );

      // Querying by flavor name "adamantium"
      final results = await dao.getItemsByCollection('mtg', searchQuery: 'adamantium');
      expect(results.length, 3);
      expect(results[0].name, 'The Ozolith', reason: 'Flavor prefix "Adamantium..." is Tier 1');
      expect(results[1].name, 'Arcane Signet', reason: 'Flavor "The Adamantium..." is Tier 1.5');
      expect(results[2].name, 'Colossus Hammer', reason: 'Flavor "...Adamantium..." is Tier 2');

      // Also verify catalog search
      final catalog = await dao.searchCatalogCards('adamantium', collectionType: 'mtg');
      expect(catalog.length, 3);
      expect(catalog[0].name, 'The Ozolith');
      expect(catalog[1].name, 'Arcane Signet');
      expect(catalog[2].name, 'Colossus Hammer');
    });

    test('Case-insensitivity, leading/trailing whitespace, and "The " bypass handling', () async {
      final now = DateTime.now();

      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-song',
          collectionType: 'mtg',
          name: 'A Song of The One Ring',
          flavorName: const drift.Value.absent(),
          setOrSeries: 'LTR',
          imageUrl: 'https://example.com/song.jpg',
          acquiredPrice: 1.0,
          acquiredDate: now,
          quantity: const drift.Value(1),
          condition: 'NM',
          currentMarketPrice: 1.5,
          lastPriceUpdate: now,
          dynamicData: '{}',
        ),
      );

      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-rule',
          collectionType: 'mtg',
          name: 'One Ring to Rule Them All',
          flavorName: const drift.Value.absent(),
          setOrSeries: 'LTR',
          imageUrl: 'https://example.com/rule.jpg',
          acquiredPrice: 2.0,
          acquiredDate: now,
          quantity: const drift.Value(1),
          condition: 'NM',
          currentMarketPrice: 2.5,
          lastPriceUpdate: now,
          dynamicData: '{}',
        ),
      );

      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-ring',
          collectionType: 'mtg',
          name: 'The One Ring',
          flavorName: const drift.Value.absent(),
          setOrSeries: 'LTR',
          imageUrl: 'https://example.com/ring.jpg',
          acquiredPrice: 80.0,
          acquiredDate: now,
          quantity: const drift.Value(1),
          condition: 'NM',
          currentMarketPrice: 100.0,
          lastPriceUpdate: now,
          dynamicData: '{}',
        ),
      );

      // Query with mixed case and extra whitespace: "  oNe RiNg  "
      final results = await dao.getItemsByCollection('mtg', searchQuery: '  oNe RiNg  ');
      expect(results.length, 3);
      expect(results[0].name, 'One Ring to Rule Them All', reason: 'Tier 1 exact prefix');
      expect(results[1].name, 'The One Ring', reason: 'Tier 1.5 "The " bypass');
      expect(results[2].name, 'A Song of The One Ring', reason: 'Tier 2 substring');

      // Catalog search with UPPERCASE
      final catalog = await dao.searchCatalogCards('ONE RING', collectionType: 'mtg');
      expect(catalog.length, 3);
      expect(catalog[0].name, 'One Ring to Rule Them All');
      expect(catalog[1].name, 'The One Ring');
      expect(catalog[2].name, 'A Song of The One Ring');
    });

    test('Secondary sorting fallback to alphabetical name ASC within identical tiers', () async {
      final now = DateTime.now();

      // Tier 1 items (all start with "Aether")
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-vial',
          collectionType: 'mtg',
          name: 'Aether Vial',
          flavorName: const drift.Value.absent(),
          setOrSeries: 'Darksteel',
          imageUrl: 'https://example.com/vial.jpg',
          acquiredPrice: 40.0,
          acquiredDate: now,
          quantity: const drift.Value(1),
          condition: 'NM',
          currentMarketPrice: 45.0,
          lastPriceUpdate: now,
          dynamicData: '{}',
        ),
      );

      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-hub',
          collectionType: 'mtg',
          name: 'Aether Hub',
          flavorName: const drift.Value.absent(),
          setOrSeries: 'Kaladesh',
          imageUrl: 'https://example.com/hub.jpg',
          acquiredPrice: 1.0,
          acquiredDate: now,
          quantity: const drift.Value(1),
          condition: 'NM',
          currentMarketPrice: 1.5,
          lastPriceUpdate: now,
          dynamicData: '{}',
        ),
      );

      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-spouts',
          collectionType: 'mtg',
          name: 'Aetherspouts',
          flavorName: const drift.Value.absent(),
          setOrSeries: 'M15',
          imageUrl: 'https://example.com/spouts.jpg',
          acquiredPrice: 2.0,
          acquiredDate: now,
          quantity: const drift.Value(1),
          condition: 'NM',
          currentMarketPrice: 2.5,
          lastPriceUpdate: now,
          dynamicData: '{}',
        ),
      );

      // Tier 1.5 items (both start with "The Aether")
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-res',
          collectionType: 'mtg',
          name: 'The Aether Reservoir',
          flavorName: const drift.Value.absent(),
          setOrSeries: 'Kaladesh',
          imageUrl: 'https://example.com/res.jpg',
          acquiredPrice: 15.0,
          acquiredDate: now,
          quantity: const drift.Value(1),
          condition: 'NM',
          currentMarketPrice: 18.0,
          lastPriceUpdate: now,
          dynamicData: '{}',
        ),
      );

      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-engine',
          collectionType: 'mtg',
          name: 'The Aether Engine',
          flavorName: const drift.Value.absent(),
          setOrSeries: 'AER',
          imageUrl: 'https://example.com/engine.jpg',
          acquiredPrice: 5.0,
          acquiredDate: now,
          quantity: const drift.Value(1),
          condition: 'NM',
          currentMarketPrice: 6.0,
          lastPriceUpdate: now,
          dynamicData: '{}',
        ),
      );

      // Tier 2 items (contain "Aether")
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-tainted',
          collectionType: 'mtg',
          name: 'Tainted Aether',
          flavorName: const drift.Value.absent(),
          setOrSeries: '7ED',
          imageUrl: 'https://example.com/tainted.jpg',
          acquiredPrice: 8.0,
          acquiredDate: now,
          quantity: const drift.Value(1),
          condition: 'NM',
          currentMarketPrice: 10.0,
          lastPriceUpdate: now,
          dynamicData: '{}',
        ),
      );

      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-serum',
          collectionType: 'mtg',
          name: 'Serum Aether',
          flavorName: const drift.Value.absent(),
          setOrSeries: '5DN',
          imageUrl: 'https://example.com/serum.jpg',
          acquiredPrice: 3.0,
          acquiredDate: now,
          quantity: const drift.Value(1),
          condition: 'NM',
          currentMarketPrice: 3.5,
          lastPriceUpdate: now,
          dynamicData: '{}',
        ),
      );

      final results = await dao.getItemsByCollection('mtg', searchQuery: 'aether');
      expect(results.length, 7);

      // Tier 1: Aether Hub, Aether Vial, Aetherspouts (alphabetical order)
      expect(results[0].name, 'Aether Hub');
      expect(results[1].name, 'Aether Vial');
      expect(results[2].name, 'Aetherspouts');

      // Tier 1.5: The Aether Engine, The Aether Reservoir (alphabetical order)
      expect(results[3].name, 'The Aether Engine');
      expect(results[4].name, 'The Aether Reservoir');

      // Tier 2: Serum Aether, Tainted Aether (alphabetical order)
      expect(results[5].name, 'Serum Aether');
      expect(results[6].name, 'Tainted Aether');
    });

    test('Unfiltered/Empty search preserves default ordering (acquiredDate DESC, name ASC)', () async {
      final now = DateTime.now();

      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-old',
          collectionType: 'mtg',
          name: 'Alpha Card',
          flavorName: const drift.Value.absent(),
          setOrSeries: 'LEA',
          imageUrl: 'https://example.com/alpha.jpg',
          acquiredPrice: 1.0,
          acquiredDate: now.subtract(const Duration(days: 10)),
          quantity: const drift.Value(1),
          condition: 'NM',
          currentMarketPrice: 1.0,
          lastPriceUpdate: now,
          dynamicData: '{}',
        ),
      );

      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-new',
          collectionType: 'mtg',
          name: 'Beta Card',
          flavorName: const drift.Value.absent(),
          setOrSeries: 'LEB',
          imageUrl: 'https://example.com/beta.jpg',
          acquiredPrice: 2.0,
          acquiredDate: now,
          quantity: const drift.Value(1),
          condition: 'NM',
          currentMarketPrice: 2.0,
          lastPriceUpdate: now,
          dynamicData: '{}',
        ),
      );

      // Without search query: newest acquired first
      final getNull = await dao.getItemsByCollection('mtg', searchQuery: null);
      expect(getNull.map((e) => e.name).toList(), ['Beta Card', 'Alpha Card']);

      final getEmpty = await dao.getItemsByCollection('mtg', searchQuery: '   ');
      expect(getEmpty.map((e) => e.name).toList(), ['Beta Card', 'Alpha Card']);

      // searchCatalogCards with empty string defaults to name ASC
      final catEmpty = await dao.searchCatalogCards('');
      expect(catEmpty.map((e) => e.name).toList(), ['Alpha Card', 'Beta Card']);
    });
  });

  group('Search Debounce Standardization Tests (250ms)', () {
    testWidgets('ManualAddBottomSheet debounces search with 250ms delay', (tester) async {
      final now = DateTime.now();
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-vial',
          collectionType: 'pokemon',
          name: 'Aether Vial',
          flavorName: const drift.Value.absent(),
          setOrSeries: 'DST',
          imageUrl: 'https://example.com/vial.jpg',
          acquiredPrice: 40.0,
          acquiredDate: now,
          quantity: const drift.Value(0),
          condition: 'NM',
          currentMarketPrice: 45.0,
          lastPriceUpdate: now,
          dynamicData: '{}',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(dao),
            activeGameContextProvider.overrideWith((ref) => 'Pokémon'),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ManualAddBottomSheet(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final searchFieldFinder = find.byKey(const Key('manual_add_search_field'));
      expect(searchFieldFinder, findsOneWidget);

      // Type query
      await tester.enterText(searchFieldFinder, 'Aether');
      // Pump 150ms - should NOT have executed search yet
      await tester.pump(const Duration(milliseconds: 150));

      // Pump another 150ms (total 300ms > 250ms debounce threshold)
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();

      expect(find.text('Aether Vial'), findsWidgets);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('MultiDeckAllocationSheet debounces search query updates with 250ms delay', (tester) async {
      final now = DateTime.now();

      await db.into(db.decks).insert(
        DecksCompanion.insert(
          id: 'deck-urza',
          name: 'Urza Commander Deck',
          format: 'Commander',
          tcgDomain: const drift.Value('mtg'),
          createdAt: now,
        ),
      );

      await db.into(db.decks).insert(
        DecksCompanion.insert(
          id: 'deck-pika',
          name: 'Pikachu Electro',
          format: 'Standard',
          tcgDomain: const drift.Value('pokemon'),
          createdAt: now,
        ),
      );

      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'item-sol-ring',
          collectionType: 'mtg',
          name: 'Sol Ring',
          flavorName: const drift.Value.absent(),
          setOrSeries: 'C21',
          imageUrl: 'https://example.com/sol.jpg',
          acquiredPrice: 2.0,
          acquiredDate: now,
          quantity: const drift.Value(4),
          condition: 'NM',
          currentMarketPrice: 2.50,
          lastPriceUpdate: now,
          dynamicData: '{}',
        ),
      );

      final testItem = await dao.getItemById('item-sol-ring');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(dao),
            deckListProvider.overrideWith((ref) => db.select(db.decks).watch()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => MultiDeckAllocationSheet.show(context, testItem!),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Urza Commander Deck'), findsOneWidget);
      expect(find.text('Pikachu Electro'), findsOneWidget);

      // Find search text field
      final searchTextFieldFinder = find.widgetWithText(TextField, 'Search decks...');
      expect(searchTextFieldFinder, findsOneWidget);

      // Type "Urza"
      await tester.enterText(searchTextFieldFinder, 'Urza');

      // At 150ms (< 250ms), Pikachu Electro is still visible because debounce has not fired
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('Pikachu Electro'), findsOneWidget);

      // Advance by another 150ms (total 300ms > 250ms)
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();

      // Now Pikachu Electro should be filtered out
      expect(find.text('Urza Commander Deck'), findsOneWidget);
      expect(find.text('Pikachu Electro'), findsNothing);

      // Clean up sheet
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
