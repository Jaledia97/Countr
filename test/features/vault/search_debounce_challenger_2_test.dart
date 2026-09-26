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
import 'package:countr/features/vault/presentation/screens/vault_screen.dart';
import 'package:countr/features/vault/presentation/widgets/manual_add_bottom_sheet.dart';
import 'package:countr/features/vault/presentation/widgets/multi_deck_allocation_sheet.dart';

/// Spy VaultDao to record search queries with timestamps to empirically prove debounce timing
class DebounceSpyVaultDao extends VaultDao {
  final List<String> recordedCatalogQueries = [];
  final List<DateTime> recordedQueryTimes = [];

  DebounceSpyVaultDao(super.db);

  @override
  Future<List<VaultItem>> searchCatalogCards(
    String query, {
    String? collectionType,
    int limit = 50,
    bool groupByOracleId = false,
  }) async {
    recordedCatalogQueries.add(query);
    recordedQueryTimes.add(DateTime.now());
    return super.searchCatalogCards(
      query,
      collectionType: collectionType,
      limit: limit,
      groupByOracleId: groupByOracleId,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // =========================================================================
  // 1. VaultScreen Search Bar Debounce (250ms)
  // =========================================================================
  group('Challenger 2 Empirical Verification: VaultScreen Search Bar (250ms Debounce)', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await db.vaultDao.clearAllItems();
      await db.vaultDao.seedDatabase();
    });

    tearDown(() async {
      await db.close();
    });

    Widget createVaultApp() {
      return ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
        ],
        child: const MaterialApp(
          home: VaultScreen(),
        ),
      );
    }

    testWidgets(
      'Typing does not immediately execute query; pump 200ms (< 250ms) does not trigger; pump 260ms (> 250ms) triggers search',
      (tester) async {
        await tester.pumpWidget(createVaultApp());
        await tester.pumpAndSettle();

        // 1. Initially search is collapsed and provider query is empty
        final element = tester.element(find.byType(VaultScreen));
        final container = ProviderScope.containerOf(element);
        expect(container.read(vaultSearchQueryProvider), equals(''));

        // Expand search bar
        final expandButton = find.byKey(const Key('vault_search_expand_button'));
        expect(expandButton, findsOneWidget);
        await tester.tap(expandButton);
        await tester.pumpAndSettle();

        final searchField = find.byKey(const Key('vault_search_text_field'));
        expect(searchField, findsOneWidget);

        // 2. Type query "Lotus"
        await tester.enterText(searchField, 'Lotus');

        // Immediately after typing (0ms elapsed) -> query must NOT be executed yet
        await tester.pump();
        expect(
          container.read(vaultSearchQueryProvider),
          equals(''),
          reason: 'Typing must not immediately execute query before debounce timer expires',
        );

        // 3. Advance time by 200ms (< 250ms threshold)
        await tester.pump(const Duration(milliseconds: 200));
        expect(
          container.read(vaultSearchQueryProvider),
          equals(''),
          reason: 'Pumping 200ms (< 250ms) must NOT trigger search',
        );

        // 4. Advance time by another 60ms (cumulative 260ms > 250ms threshold)
        await tester.pump(const Duration(milliseconds: 60));
        expect(
          container.read(vaultSearchQueryProvider),
          equals('Lotus'),
          reason: 'Pumping cumulative 260ms (> 250ms) MUST trigger search',
        );

        // Clean up
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 50));
      },
    );

    testWidgets(
      'Rapid typing cancels previous timers without thrashing vaultSearchQueryProvider',
      (tester) async {
        await tester.pumpWidget(createVaultApp());
        await tester.pumpAndSettle();

        final element = tester.element(find.byType(VaultScreen));
        final container = ProviderScope.containerOf(element);

        await tester.tap(find.byKey(const Key('vault_search_expand_button')));
        await tester.pumpAndSettle();

        final searchField = find.byKey(const Key('vault_search_text_field'));

        // Rapid typing with 100ms intervals between strokes
        await tester.enterText(searchField, 'L');
        await tester.pump(const Duration(milliseconds: 100));
        expect(container.read(vaultSearchQueryProvider), equals(''));

        await tester.enterText(searchField, 'Lo');
        await tester.pump(const Duration(milliseconds: 100));
        expect(container.read(vaultSearchQueryProvider), equals(''));

        await tester.enterText(searchField, 'Lot');
        await tester.pump(const Duration(milliseconds: 100));
        expect(container.read(vaultSearchQueryProvider), equals(''));

        await tester.enterText(searchField, 'Lotus');
        // Total elapsed time since 'L' is 300ms, but only 0ms since 'Lotus'
        // Advance 200ms (cumulative 500ms since 'L', but 200ms < 250ms since 'Lotus')
        await tester.pump(const Duration(milliseconds: 200));
        expect(
          container.read(vaultSearchQueryProvider),
          equals(''),
          reason: 'Rapid typing must cancel previous timers so query is not set prematurely',
        );

        // Advance 60ms (260ms > 250ms since last keystroke)
        await tester.pump(const Duration(milliseconds: 60));
        expect(
          container.read(vaultSearchQueryProvider),
          equals('Lotus'),
          reason: 'Query is set to final keystroke value after settling for >250ms',
        );

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 50));
      },
    );

    testWidgets(
      'Clear button immediately cancels pending debounce timer and clears search query',
      (tester) async {
        await tester.pumpWidget(createVaultApp());
        await tester.pumpAndSettle();

        final element = tester.element(find.byType(VaultScreen));
        final container = ProviderScope.containerOf(element);

        await tester.tap(find.byKey(const Key('vault_search_expand_button')));
        await tester.pumpAndSettle();

        final searchField = find.byKey(const Key('vault_search_text_field'));
        await tester.enterText(searchField, 'Mox Emerald');
        await tester.pump(const Duration(milliseconds: 100)); // < 250ms

        // Tap clear button while debounce timer is still pending
        final clearButton = find.byKey(const Key('vault_search_clear_button'));
        expect(clearButton, findsOneWidget);
        await tester.tap(clearButton);
        await tester.pump();

        expect(container.read(vaultSearchQueryProvider), equals(''));

        // Wait another 260ms - ensure pending timer was cancelled and does not overwrite provider
        await tester.pump(const Duration(milliseconds: 260));
        expect(container.read(vaultSearchQueryProvider), equals(''));

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 50));
      },
    );

    testWidgets(
      'Disposing VaultScreen while debounce timer is active cancels timer cleanly without leaking or throwing',
      (tester) async {
        await tester.pumpWidget(createVaultApp());
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('vault_search_expand_button')));
        await tester.pumpAndSettle();

        final searchField = find.byKey(const Key('vault_search_text_field'));
        await tester.enterText(searchField, 'Unmounted Query');
        await tester.pump(const Duration(milliseconds: 100)); // pending timer

        // Unmount screen
        await tester.pumpWidget(const SizedBox());
        // Advance past debounce duration
        await tester.pump(const Duration(milliseconds: 300));
        // No exceptions thrown
        expect(tester.takeException(), isNull);
      },
    );
  });

  // =========================================================================
  // 2. ManualAddBottomSheet Catalog Search Bar Debounce (250ms vs 300ms)
  // =========================================================================
  group('Challenger 2 Empirical Verification: ManualAddBottomSheet Catalog Search (250ms vs 300ms)', () {
    late AppDatabase db;
    late DebounceSpyVaultDao spyDao;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      spyDao = DebounceSpyVaultDao(db);
      await spyDao.seedDatabase();

      // Seed catalog items
      final now = DateTime.now();
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'cat-sol-ring',
          collectionType: 'mtg',
          name: 'Sol Ring',
          flavorName: const drift.Value.absent(),
          setOrSeries: 'C21',
          imageUrl: '',
          acquiredPrice: 0.0,
          acquiredDate: now,
          quantity: const drift.Value(0),
          condition: 'NM',
          currentMarketPrice: 2.0,
          lastPriceUpdate: now,
          dynamicData: '{}',
        ),
      );
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'cat-black-lotus',
          collectionType: 'mtg',
          name: 'Black Lotus',
          flavorName: const drift.Value.absent(),
          setOrSeries: 'LEA',
          imageUrl: '',
          acquiredPrice: 0.0,
          acquiredDate: now,
          quantity: const drift.Value(0),
          condition: 'NM',
          currentMarketPrice: 25000.0,
          lastPriceUpdate: now,
          dynamicData: '{}',
        ),
      );
    });

    tearDown(() async {
      await db.close();
    });

    Widget createManualAddApp() {
      return ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(spyDao),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: ManualAddBottomSheet(),
          ),
        ),
      );
    }

    testWidgets(
      'Verify debounce is exactly 250ms (not 300ms): 200ms pump does not trigger search; 260ms pump triggers search',
      (tester) async {
        await tester.pumpWidget(createManualAddApp());
        await tester.pumpAndSettle();

        // Initial search for empty query executed on mount
        expect(
          spyDao.recordedCatalogQueries.length,
          equals(1),
          reason: 'Initial search on mount must execute once',
        );
        expect(spyDao.recordedCatalogQueries[0], equals(''));

        final searchField = find.byKey(const Key('manual_add_search_field'));
        expect(searchField, findsOneWidget);

        // Type query 'Black Lotus'
        await tester.enterText(searchField, 'Black Lotus');

        // Immediately after typing (0ms elapsed) -> no new query
        await tester.pump();
        expect(
          spyDao.recordedCatalogQueries.length,
          equals(1),
          reason: 'Typing must not trigger search immediately',
        );

        // Advance 200ms (< 250ms threshold)
        await tester.pump(const Duration(milliseconds: 200));
        expect(
          spyDao.recordedCatalogQueries.length,
          equals(1),
          reason: 'At 200ms (< 250ms), search must NOT have triggered',
        );

        // Advance another 60ms (cumulative 260ms > 250ms threshold)
        await tester.pump(const Duration(milliseconds: 60));
        await tester.pumpAndSettle();

        // Verify search triggered at 260ms!
        // NOTE: If debounce were 300ms, at 260ms recordedCatalogQueries.length would STILL be 1!
        expect(
          spyDao.recordedCatalogQueries.length,
          equals(2),
          reason: 'At 260ms (> 250ms), debounce must have triggered. If it were 300ms, this would fail.',
        );
        expect(spyDao.recordedCatalogQueries[1], equals('Black Lotus'));

        // Clean up
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 50));
      },
    );

    testWidgets(
      'Rapid typing cancels earlier debounce timers, issuing exactly ONE query upon settling',
      (tester) async {
        await tester.pumpWidget(createManualAddApp());
        await tester.pumpAndSettle();

        expect(spyDao.recordedCatalogQueries.length, equals(1)); // initial

        final searchField = find.byKey(const Key('manual_add_search_field'));

        // Rapid typing strokes every 80ms
        await tester.enterText(searchField, 'B');
        await tester.pump(const Duration(milliseconds: 80));
        expect(spyDao.recordedCatalogQueries.length, equals(1));

        await tester.enterText(searchField, 'Bl');
        await tester.pump(const Duration(milliseconds: 80));
        expect(spyDao.recordedCatalogQueries.length, equals(1));

        await tester.enterText(searchField, 'Bla');
        await tester.pump(const Duration(milliseconds: 80));
        expect(spyDao.recordedCatalogQueries.length, equals(1));

        await tester.enterText(searchField, 'Black');
        await tester.pump(const Duration(milliseconds: 80));
        expect(spyDao.recordedCatalogQueries.length, equals(1));

        await tester.enterText(searchField, 'Black Lotus');
        // Pump 200ms (total elapsed: 520ms since 'B', but only 200ms since 'Black Lotus')
        await tester.pump(const Duration(milliseconds: 200));
        expect(
          spyDao.recordedCatalogQueries.length,
          equals(1),
          reason: 'None of the intermediate keystrokes should trigger queries because each cancelled the previous timer',
        );

        // Advance 60ms (260ms since 'Black Lotus')
        await tester.pump(const Duration(milliseconds: 60));
        await tester.pumpAndSettle();

        // Exactly one new query was executed
        expect(
          spyDao.recordedCatalogQueries.length,
          equals(2),
          reason: 'Only the settled final query must execute',
        );
        expect(spyDao.recordedCatalogQueries.last, equals('Black Lotus'));

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 50));
      },
    );

    testWidgets(
      'Disposing ManualAddBottomSheet cancels pending debounce timer cleanly',
      (tester) async {
        await tester.pumpWidget(createManualAddApp());
        await tester.pumpAndSettle();

        final searchField = find.byKey(const Key('manual_add_search_field'));
        await tester.enterText(searchField, 'Cancelled Query');
        await tester.pump(const Duration(milliseconds: 100)); // pending timer

        // Unmount sheet
        await tester.pumpWidget(const SizedBox());
        // Advance past debounce duration
        await tester.pump(const Duration(milliseconds: 300));

        // Ensure timer was cancelled and no new query recorded
        expect(spyDao.recordedCatalogQueries.length, equals(1)); // only initial
        expect(tester.takeException(), isNull);
      },
    );
  });

  // =========================================================================
  // 3. MultiDeckAllocationSheet Deck Card Add Search Bar Debounce (250ms)
  // =========================================================================
  group('Challenger 2 Empirical Verification: MultiDeckAllocationSheet Search Debounce (250ms)', () {
    late AppDatabase db;
    late VaultItem testItem;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await db.vaultDao.clearAllItems();

      final now = DateTime.now();

      // Seed decks
      await db.into(db.decks).insert(
        DecksCompanion.insert(
          id: 'deck-urza-artificer',
          name: 'Urza Lord High Artificer Deck',
          format: 'Commander',
          tcgDomain: const drift.Value('mtg'),
          createdAt: now,
        ),
      );

      await db.into(db.decks).insert(
        DecksCompanion.insert(
          id: 'deck-pikachu-electro',
          name: 'Pikachu Electro Spark',
          format: 'Standard',
          tcgDomain: const drift.Value('pokemon'),
          createdAt: now,
        ),
      );

      // Seed vault item
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'item-sol-ring',
          collectionType: 'mtg',
          name: 'Sol Ring',
          flavorName: const drift.Value.absent(),
          setOrSeries: 'C21',
          imageUrl: '',
          acquiredPrice: 2.0,
          acquiredDate: now,
          quantity: const drift.Value(4),
          condition: 'NM',
          currentMarketPrice: 2.50,
          lastPriceUpdate: now,
          dynamicData: '{}',
        ),
      );

      testItem = (await db.vaultDao.getItemById('item-sol-ring'))!;
    });

    tearDown(() async {
      await db.close();
    });

    Widget createAllocationApp() {
      return ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          deckListProvider.overrideWith((ref) => db.select(db.decks).watch()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: MultiDeckAllocationSheet(item: testItem),
          ),
        ),
      );
    }

    testWidgets(
      'Verify debounce is 250ms: 200ms pump does not filter; 260ms pump filters list',
      (tester) async {
        await tester.pumpWidget(createAllocationApp());
        await tester.pumpAndSettle();

        // Both decks initially visible
        expect(find.text('Urza Lord High Artificer Deck'), findsOneWidget);
        expect(find.text('Pikachu Electro Spark'), findsOneWidget);

        final searchField = find.widgetWithText(TextField, 'Search decks...');
        expect(searchField, findsOneWidget);

        // Type query 'Urza'
        await tester.enterText(searchField, 'Urza');

        // Immediately after typing (0ms elapsed) -> both still visible
        await tester.pump();
        expect(
          find.text('Pikachu Electro Spark'),
          findsOneWidget,
          reason: 'Pikachu must remain visible immediately after typing (debounce not fired)',
        );

        // Advance 200ms (< 250ms threshold)
        await tester.pump(const Duration(milliseconds: 200));
        expect(
          find.text('Pikachu Electro Spark'),
          findsOneWidget,
          reason: 'At 200ms (< 250ms), Pikachu must still be visible',
        );

        // Advance 60ms (cumulative 260ms > 250ms threshold)
        await tester.pump(const Duration(milliseconds: 60));
        await tester.pumpAndSettle();

        // Now Pikachu is filtered out and Urza is visible
        expect(find.text('Urza Lord High Artificer Deck'), findsOneWidget);
        expect(
          find.text('Pikachu Electro Spark'),
          findsNothing,
          reason: 'At 260ms (> 250ms), debounce must have updated _searchQuery and filtered the list',
        );

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 50));
      },
    );

    testWidgets(
      'Rapid typing cancels previous timers without thrashing _searchQuery',
      (tester) async {
        await tester.pumpWidget(createAllocationApp());
        await tester.pumpAndSettle();

        final searchField = find.widgetWithText(TextField, 'Search decks...');

        // Rapid typing towards "Pikachu" with 75ms between strokes
        await tester.enterText(searchField, 'P');
        await tester.pump(const Duration(milliseconds: 75));

        await tester.enterText(searchField, 'Pi');
        await tester.pump(const Duration(milliseconds: 75));

        await tester.enterText(searchField, 'Pik');
        await tester.pump(const Duration(milliseconds: 75));

        await tester.enterText(searchField, 'Pika');
        await tester.pump(const Duration(milliseconds: 75));

        await tester.enterText(searchField, 'Pikachu');
        // Total elapsed time since 'P' is 300ms (> 250ms), but only 0ms since 'Pikachu'.
        // Advance 200ms (500ms since 'P', 200ms since 'Pikachu')
        await tester.pump(const Duration(milliseconds: 200));

        // Because earlier timers were cancelled, Urza has NOT been filtered out yet
        expect(
          find.text('Urza Lord High Artificer Deck'),
          findsOneWidget,
          reason: 'Intermediate timers were cancelled; Urza must still be visible before settling',
        );

        // Advance 60ms (260ms after 'Pikachu')
        await tester.pump(const Duration(milliseconds: 60));
        await tester.pumpAndSettle();

        // Now Pikachu is visible, Urza is filtered out
        expect(find.text('Pikachu Electro Spark'), findsOneWidget);
        expect(find.text('Urza Lord High Artificer Deck'), findsNothing);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 50));
      },
    );

    testWidgets(
      'Clearing search controller debounces at 250ms before restoring all decks',
      (tester) async {
        await tester.pumpWidget(createAllocationApp());
        await tester.pumpAndSettle();

        final searchField = find.widgetWithText(TextField, 'Search decks...');
        await tester.enterText(searchField, 'Urza');
        await tester.pump(const Duration(milliseconds: 260));
        await tester.pumpAndSettle();

        expect(find.text('Urza Lord High Artificer Deck'), findsOneWidget);
        expect(find.text('Pikachu Electro Spark'), findsNothing);

        // Suffix clear button is present
        final clearButton = find.byIcon(Icons.clear);
        expect(clearButton, findsOneWidget);

        await tester.tap(clearButton);
        // Immediately pump
        await tester.pump();
        // At 200ms after clearing (< 250ms)
        await tester.pump(const Duration(milliseconds: 200));
        expect(
          find.text('Pikachu Electro Spark'),
          findsNothing,
          reason: 'Clearing triggers _onSearchChanged which debounces at 250ms; at 200ms Pikachu not yet restored',
        );

        // Advance 60ms (cumulative 260ms > 250ms)
        await tester.pump(const Duration(milliseconds: 60));
        await tester.pumpAndSettle();

        // Both decks restored
        expect(find.text('Urza Lord High Artificer Deck'), findsOneWidget);
        expect(find.text('Pikachu Electro Spark'), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 50));
      },
    );

    testWidgets(
      'Disposing MultiDeckAllocationSheet while debounce timer is active cancels cleanly',
      (tester) async {
        await tester.pumpWidget(createAllocationApp());
        await tester.pumpAndSettle();

        final searchField = find.widgetWithText(TextField, 'Search decks...');
        await tester.enterText(searchField, 'Pending Unmount');
        await tester.pump(const Duration(milliseconds: 100)); // pending timer

        // Unmount sheet
        await tester.pumpWidget(const SizedBox());
        // Advance past debounce duration
        await tester.pump(const Duration(milliseconds: 300));

        // Zero exceptions
        expect(tester.takeException(), isNull);
      },
    );
  });
}
