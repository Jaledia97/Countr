import 'package:drift/drift.dart' as drift;
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

  setUpAll(() {
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('Milestone 3 Challenger 2: Adversarial Stress Test - Filter Count Invariants & UI Reactivity', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await db.delete(db.vaultItems).go();
    });

    tearDown(() async {
      await db.close();
    });

    // Helper to seed cards
    Future<void> insertCard({
      required String id,
      required String name,
      String collectionType = 'mtg',
      String setOrSeries = 'MH3',
      String color = 'R',
      int quantity = 1,
      bool isDeleted = false,
      String? dynamicDataOverride,
    }) async {
      final now = DateTime.now();
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: id,
          collectionType: collectionType,
          name: name,
          setOrSeries: setOrSeries,
          imageUrl: 'https://cards.scryfall.io/$id.jpg',
          acquiredPrice: 5.0,
          acquiredDate: now,
          lastPriceUpdate: now,
          currentMarketPrice: 10.0,
          quantity: drift.Value(quantity),
          condition: 'NM',
          isDeleted: drift.Value(isDeleted),
          dynamicData: dynamicDataOverride ??
              '{"colors":["$color"],"color_identity":["$color"],"cmc":3,"rarity":"rare","legalities":{"commander":"legal"}}',
        ),
      );
    }

    Widget createVaultHarness({
      required ProviderContainer container,
    }) {
      return UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: VaultScreen(),
        ),
      );
    }

    // =========================================================================
    // 1. DYNAMIC COUNTER RENDERING IN "ALL CARDS" VS "OWNED" VIEWS
    // =========================================================================
    testWidgets(
      'Challenge 1: Counter transitions seamlessly between Owned (20) and Catalog (100) on active filter',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Seed 20 owned Red cards + 80 catalog unowned Red cards = 100 total Red cards
        for (int i = 0; i < 20; i++) {
          await insertCard(
            id: 'owned_red_$i',
            name: 'Owned Goblin $i',
            color: 'R',
            quantity: 1,
          );
        }
        for (int i = 0; i < 80; i++) {
          await insertCard(
            id: 'catalog_red_$i',
            name: 'Catalog Goblin $i',
            color: 'R',
            quantity: 0,
          );
        }
        // Seed 10 owned Blue cards + 40 catalog unowned Blue cards
        for (int i = 0; i < 10; i++) {
          await insertCard(
            id: 'owned_blue_$i',
            name: 'Owned Merfolk $i',
            color: 'U',
            quantity: 1,
          );
        }
        for (int i = 0; i < 40; i++) {
          await insertCard(
            id: 'catalog_blue_$i',
            name: 'Catalog Merfolk $i',
            color: 'U',
            quantity: 0,
          );
        }

        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(db.vaultDao),
            activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
            vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
            vaultPaginationLimitProvider.overrideWith((ref) => 50),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(createVaultHarness(container: container));
        await tester.pumpAndSettle();

        // Initially unfiltered in Owned view -> counter must NOT be visible
        expect(find.byKey(const Key('vault_showing_results_counter')), findsNothing);

        // Apply Red MTG Filter
        container.read(mtgFilterProvider.notifier).state = const MtgFilterState(
          colors: {'R'},
          colorMatchMode: ColorMatchMode.including,
        );
        await tester.pumpAndSettle();

        // In Owned mode: 20 owned Red cards exist -> counter must show "showing 20 results"
        expect(find.byKey(const Key('vault_showing_results_counter')), findsOneWidget);
        expect(find.text('showing 20 results'), findsOneWidget);

        // Switch to "All Cards" (Catalog) mode via provider
        container.read(vaultShowCatalogProvider.notifier).state = true;
        await tester.pumpAndSettle();

        // In Catalog mode: all 100 Red cards exist -> counter must show "showing 100 results"
        expect(find.byKey(const Key('vault_showing_results_counter')), findsOneWidget);
        expect(find.text('showing 100 results'), findsOneWidget);

        // Dynamically insert 101st Red card into catalog (quantity = 0)
        await insertCard(
          id: 'catalog_red_new',
          name: 'Catalog Dragon 101',
          color: 'R',
          quantity: 0,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pumpAndSettle();

        // Counter reactively updates to "showing 101 results" in Catalog mode
        expect(find.text('showing 101 results'), findsOneWidget);

        // Switch back to "Owned" mode
        container.read(vaultShowCatalogProvider.notifier).state = false;
        await tester.pumpAndSettle();

        // Owned mode still has 20 cards
        expect(find.text('showing 20 results'), findsOneWidget);

        // Promote one unowned card to owned (quantity 0 -> 1)
        await (db.update(db.vaultItems)..where((t) => t.id.equals('catalog_red_0'))).write(
          const VaultItemsCompanion(quantity: drift.Value(1)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pumpAndSettle();

        // Owned mode counter immediately updates to 21 results
        expect(find.text('showing 21 results'), findsOneWidget);

        // Clear filter
        container.read(mtgFilterProvider.notifier).state = const MtgFilterState();
        await tester.pumpAndSettle();

        // Counter cleanly disappears
        expect(find.byKey(const Key('vault_showing_results_counter')), findsNothing);
      },
    );

    // =========================================================================
    // 2. SINGLE-FRAME FILTER UPDATES (ZERO-DELAY REACTIVITY)
    // =========================================================================
    testWidgets(
      'Challenge 2: Single-frame filter reactivity and rapid-fire toggling resilience',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Seed 15 Red, 25 Blue, 10 Green cards
        for (int i = 0; i < 15; i++) {
          await insertCard(id: 'r_$i', name: 'Red $i', color: 'R', quantity: 1);
        }
        for (int i = 0; i < 25; i++) {
          await insertCard(id: 'u_$i', name: 'Blue $i', color: 'U', quantity: 1);
        }
        for (int i = 0; i < 10; i++) {
          await insertCard(id: 'g_$i', name: 'Green $i', color: 'G', quantity: 1);
        }

        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(db.vaultDao),
            activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
            vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
            vaultPaginationLimitProvider.overrideWith((ref) => 50),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(createVaultHarness(container: container));
        await tester.pumpAndSettle();

        // 1. Mutate filter to Blue (25 cards)
        container.read(mtgFilterProvider.notifier).state = const MtgFilterState(
          colors: {'U'},
          colorMatchMode: ColorMatchMode.including,
        );

        // Verify single pump() synchronously applies filter without waiting for pumpAndSettle
        await tester.pump();
        expect(find.byKey(const Key('vault_showing_results_counter')), findsOneWidget);
        expect(find.text('showing 25 results'), findsOneWidget);

        // 2. Rapid-fire filter mutations across consecutive frames
        final filterStates = [
          const MtgFilterState(colors: {'R'}, colorMatchMode: ColorMatchMode.including),
          const MtgFilterState(colors: {'G'}, colorMatchMode: ColorMatchMode.including),
          const MtgFilterState(colors: {'R', 'U'}, colorMatchMode: ColorMatchMode.including),
          const MtgFilterState(colors: {'W'}, colorMatchMode: ColorMatchMode.including),
          const MtgFilterState(colors: {'R'}, colorMatchMode: ColorMatchMode.including),
        ];

        for (final state in filterStates) {
          container.read(mtgFilterProvider.notifier).state = state;
          await tester.pump();
          expect(tester.takeException(), isNull, reason: 'Rapid filter mutation must never throw');
        }

        // Settle into final state (Red: 15 cards)
        await tester.pumpAndSettle();
        expect(find.text('showing 15 results'), findsOneWidget);
      },
    );

    // =========================================================================
    // 3. ZERO / SINGULAR / PLURAL BOUNDARY TRANSITIONS
    // =========================================================================
    testWidgets(
      'Challenge 3: Zero / Singular / Plural boundary state machine: 0 -> 1 -> 2 -> 100 -> 1 -> 0',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(db.vaultDao),
            activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
            vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
            vaultPaginationLimitProvider.overrideWith((ref) => 50),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(createVaultHarness(container: container));
        await tester.pumpAndSettle();

        // 1. Search for non-existent card "Black Lotus" -> 0 results
        container.read(vaultSearchQueryProvider.notifier).state = 'Black Lotus';
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('vault_showing_results_counter')), findsOneWidget);
        expect(find.text('showing 0 results'), findsOneWidget, reason: 'Zero results must use plural "results"');

        // 2. Insert 1st Black Lotus -> 1 result (singular)
        await insertCard(id: 'bl_1', name: 'Black Lotus', quantity: 1);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        expect(find.text('showing 1 result'), findsOneWidget, reason: 'Exactly 1 result must use singular "result"');

        // 3. Insert 2nd Black Lotus -> 2 results (plural)
        await insertCard(id: 'bl_2', name: 'Black Lotus', quantity: 1);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        expect(find.text('showing 2 results'), findsOneWidget, reason: '2 results must use plural "results"');

        // 4. Batch insert 98 more Black Lotuses -> 100 results
        final bulkLotuses = <VaultItemsCompanion>[];
        final now = DateTime.now();
        for (int i = 3; i <= 100; i++) {
          bulkLotuses.add(
            VaultItemsCompanion.insert(
              id: 'bl_$i',
              collectionType: 'mtg',
              name: 'Black Lotus $i',
              setOrSeries: 'Alpha',
              imageUrl: 'https://cards.scryfall.io/lotus_$i.jpg',
              acquiredPrice: 5000.0,
              acquiredDate: now,
              lastPriceUpdate: now,
              currentMarketPrice: 8000.0,
              quantity: const drift.Value(1),
              condition: 'NM',
              dynamicData: '{"colors":[]}',
            ),
          );
        }
        await db.batch((b) {
          b.insertAll(db.vaultItems, bulkLotuses);
        });

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        expect(find.text('showing 100 results'), findsOneWidget);

        // 5. Delete cards bl_2 through bl_100 -> back to 1 result
        await (db.delete(db.vaultItems)..where((t) => t.id.isIn(
          List.generate(99, (i) => 'bl_${i + 2}'),
        ))).go();

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        expect(find.text('showing 1 result'), findsOneWidget, reason: 'Must smoothly return to singular "result"');

        // 6. Soft delete the last card (bl_1) -> back to 0 results
        await (db.update(db.vaultItems)..where((t) => t.id.equals('bl_1'))).write(
          const VaultItemsCompanion(isDeleted: drift.Value(true)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        expect(find.text('showing 0 results'), findsOneWidget);

        // 7. Clear search query -> counter disappears
        container.read(vaultSearchQueryProvider.notifier).state = '';
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('vault_showing_results_counter')), findsNothing);
      },
    );

    // =========================================================================
    // 4. ADVERSARIAL SEARCH QUERY STRESS TESTING
    // =========================================================================
    testWidgets(
      'Challenge 4: Adversarial search queries (SQL syntax, wildcards, regex, unicode, whitespace)',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await insertCard(id: 'c1', name: "Jace, the Mind Sculptor", quantity: 1);
        await insertCard(id: 'c2', name: "Urza's Power Plant", quantity: 1);
        await insertCard(id: 'c3', name: '100% Legit Magic Card', quantity: 1);
        await insertCard(id: 'c4', name: 'Card [Special_Edition]', quantity: 1);
        await insertCard(id: 'c5', name: 'Dragon 🔥 Fire', quantity: 1);

        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(db.vaultDao),
            activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
            vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
            vaultPaginationLimitProvider.overrideWith((ref) => 50),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(createVaultHarness(container: container));
        await tester.pumpAndSettle();

        // Helper to test search query
        Future<void> testSearch(String query, String expectedCounterText) async {
          container.read(vaultSearchQueryProvider.notifier).state = query;
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'Search query "$query" must not throw');
          expect(find.text(expectedCounterText), findsOneWidget);
        }

        // A. SQL Injection attempts
        await testSearch("' OR '1'='1", 'showing 0 results');
        await testSearch("'; DROP TABLE vault_items; --", 'showing 0 results');

        // B. Single quote in legitimate name
        await testSearch("Urza's", 'showing 1 result');

        // C. Percent sign '%'
        await testSearch("100%", 'showing 1 result');

        // D. Brackets and underscore
        await testSearch("[Special_Edition]", 'showing 1 result');

        // E. Unicode emoji
        await testSearch("🔥", 'showing 1 result');

        // F. Pure whitespace string -> should be treated as empty/unfiltered
        container.read(vaultSearchQueryProvider.notifier).state = '    ';
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('vault_showing_results_counter')), findsNothing,
            reason: 'Whitespace-only search must not activate results counter');
      },
    );

    // =========================================================================
    // 5. DECOUPLED PAGINATION INVARIANT UNDER HEAVY DATASET (350 CARDS)
    // =========================================================================
    testWidgets(
      'Challenge 5: True database count (350) remains strictly decoupled from paginated slice (50..300)',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Insert 350 matching cards
        final now = DateTime.now();
        final cards = <VaultItemsCompanion>[];
        for (int i = 0; i < 350; i++) {
          cards.add(
            VaultItemsCompanion.insert(
              id: 'card_stress_$i',
              collectionType: 'mtg',
              name: 'Lightning Bolt $i',
              setOrSeries: 'M10',
              imageUrl: 'https://cards.scryfall.io/bolt_$i.jpg',
              acquiredPrice: 2.0,
              acquiredDate: now.subtract(Duration(minutes: i)),
              lastPriceUpdate: now,
              currentMarketPrice: 3.5,
              quantity: const drift.Value(1),
              condition: 'NM',
              dynamicData: '{"colors":["R"],"cmc":1,"rarity":"common","legalities":{"commander":"legal"}}',
            ),
          );
        }
        await db.batch((b) {
          b.insertAll(db.vaultItems, cards);
        });

        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(db.vaultDao),
            activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
            vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
            vaultPaginationLimitProvider.overrideWith((ref) => 50),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(createVaultHarness(container: container));
        await tester.pumpAndSettle();

        // Apply Red MTG Filter
        container.read(mtgFilterProvider.notifier).state = const MtgFilterState(
          colors: {'R'},
          colorMatchMode: ColorMatchMode.including,
        );
        await tester.pumpAndSettle();

        // 1. Initial page limit = 50: UI counter MUST report true database total 350
        expect(find.byKey(const Key('vault_showing_results_counter')), findsOneWidget);
        expect(find.text('showing 350 results'), findsOneWidget);
        expect(container.read(vaultPaginationLimitProvider), equals(50));
        expect(container.read(vaultItemsStreamProvider).value!.length, equals(50));
        expect(find.byType(VaultItemTile).evaluate().length, lessThanOrEqualTo(50));

        // 2. Step pagination limit to 150: UI counter MUST STILL report true total 350
        container.read(vaultPaginationLimitProvider.notifier).state = 150;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        expect(find.text('showing 350 results'), findsOneWidget);
        expect(container.read(vaultItemsStreamProvider).value!.length, equals(150));

        // 3. Step pagination limit to 300: UI counter MUST STILL report true total 350
        container.read(vaultPaginationLimitProvider.notifier).state = 300;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        expect(find.text('showing 350 results'), findsOneWidget);
        expect(container.read(vaultItemsStreamProvider).value!.length, equals(300));

        // 4. Dynamically insert 351st card
        await insertCard(
          id: 'card_stress_350',
          name: 'Lightning Bolt 350',
          color: 'R',
          quantity: 1,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        // Counter reactively updates to 351
        expect(find.text('showing 351 results'), findsOneWidget);
        expect(container.read(vaultPaginationLimitProvider), equals(300));

        // 5. Delete 2 cards
        await (db.delete(db.vaultItems)..where((t) => t.id.isIn(['card_stress_0', 'card_stress_1']))).go();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        // Counter reactively updates to 349
        expect(find.text('showing 349 results'), findsOneWidget);
      },
    );

    // =========================================================================
    // 6. MULTI-FACED CARDS (DFCs) & COLOR INVARIANTS
    // =========================================================================
    testWidgets(
      'Challenge 6: Multi-faced card (DFC) color and identity matching invariants',
      (tester) async {
        // Seed DFC card: Front Face Red, Back Face Blue
        await insertCard(
          id: 'dfc_1',
          name: 'Nicol Bolas, the Ravager // Nicol Bolas, the Arisen',
          quantity: 1,
          dynamicDataOverride: '''{
            "colors": ["U", "B", "R"],
            "color_identity": ["U", "B", "R"],
            "card_faces": [
              {"name": "Nicol Bolas, the Ravager", "colors": ["U", "B", "R"], "mana_cost": "{1}{U}{B}{R}"},
              {"name": "Nicol Bolas, the Arisen", "colors": ["U", "B", "R"], "mana_cost": ""}
            ],
            "cmc": 4,
            "rarity": "mythic",
            "legalities": {"commander": "legal"}
          }''',
        );

        // Seed Mono-Red card
        await insertCard(
          id: 'mono_red_1',
          name: 'Chandra, Torch of Defiance',
          quantity: 1,
          dynamicDataOverride: '''{
            "colors": ["R"],
            "color_identity": ["R"],
            "cmc": 4,
            "rarity": "mythic",
            "legalities": {"commander": "legal"}
          }''',
        );

        // A. Filter: including Red ('R') -> both DFC (UBR) and Mono-Red (R) match (2 results)
        expect(
          await db.vaultDao.getFilteredItemCount(
            'mtg',
            onlyOwned: true,
            mtgFilter: const MtgFilterState(colors: {'R'}, colorMatchMode: ColorMatchMode.including),
          ),
          equals(2),
        );

        // B. Filter: including Blue ('U') -> only DFC matches (1 result)
        expect(
          await db.vaultDao.getFilteredItemCount(
            'mtg',
            onlyOwned: true,
            mtgFilter: const MtgFilterState(colors: {'U'}, colorMatchMode: ColorMatchMode.including),
          ),
          equals(1),
        );

        // C. Filter: exactly Red ('R') -> only Mono-Red matches (1 result), DFC excluded
        expect(
          await db.vaultDao.getFilteredItemCount(
            'mtg',
            onlyOwned: true,
            mtgFilter: const MtgFilterState(colors: {'R'}, colorMatchMode: ColorMatchMode.exactly),
          ),
          equals(1),
        );

        // D. Filter: exactly U, B, R -> only DFC matches (1 result)
        expect(
          await db.vaultDao.getFilteredItemCount(
            'mtg',
            onlyOwned: true,
            mtgFilter: const MtgFilterState(colors: {'U', 'B', 'R'}, colorMatchMode: ColorMatchMode.exactly),
          ),
          equals(1),
        );

        // E. Filter: atMost Red ('R') -> Mono-Red matches (1 result), DFC excluded because it has U and B
        expect(
          await db.vaultDao.getFilteredItemCount(
            'mtg',
            onlyOwned: true,
            mtgFilter: const MtgFilterState(colors: {'R'}, colorMatchMode: ColorMatchMode.atMost),
          ),
          equals(1),
        );

        // F. Filter: atMost U, B, R -> both match (2 results)
        expect(
          await db.vaultDao.getFilteredItemCount(
            'mtg',
            onlyOwned: true,
            mtgFilter: const MtgFilterState(colors: {'U', 'B', 'R'}, colorMatchMode: ColorMatchMode.atMost),
          ),
          equals(2),
        );
      },
    );
  });
}
