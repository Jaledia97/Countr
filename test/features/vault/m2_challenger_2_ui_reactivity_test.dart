import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/decks/data/daos/explore_deck_dao.dart';
import 'package:countr/features/decks/data/services/explore_seeder_service.dart';
import 'package:countr/features/decks/data/services/fallback_explore_seeds.dart';
import 'package:countr/features/decks/domain/models/explore_deck_models.dart';
import 'package:countr/features/decks/presentation/providers/explore_deck_providers.dart';
import 'package:countr/features/decks/presentation/widgets/explore/explore_decks_tab_view.dart';
import 'package:countr/features/vault/presentation/providers/mtg_filter_state.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/screens/vault_screen.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_tile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('Milestone 2 Challenger 2: VaultScreen UI Reactivity & Decoupled Count Invariants', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await db.delete(db.vaultItems).go();
    });

    tearDown(() async {
      await db.close();
    });

    Widget createVaultHarness({
      List<Override> overrides = const [],
    }) {
      return ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
          ...overrides,
        ],
        child: const MaterialApp(
          home: VaultScreen(),
        ),
      );
    }

    testWidgets(
      'Adversarial Invariant: Showing 180 results with 50 rendered, live dynamic card insertion 180 -> 181, filter clearing',
      (tester) async {
        // Size viewport so all 50 items in the initial paginated slice are rendered
        // without triggering maxScroll <= 0 auto-fetch
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final now = DateTime.now();

        // 1. Insert 180 matching Red Goblin cards and 20 non-matching Blue Merfolk cards
        final seedCards = <VaultItemsCompanion>[];
        for (int i = 0; i < 180; i++) {
          seedCards.add(
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
        for (int i = 0; i < 20; i++) {
          seedCards.add(
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
          b.insertAll(db.vaultItems, seedCards);
        });

        late WidgetRef capturedRef;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              vaultDaoProvider.overrideWithValue(db.vaultDao),
              activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
            ],
            child: MaterialApp(
              home: Consumer(
                builder: (context, ref, child) {
                  capturedRef = ref;
                  return const VaultScreen();
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Initial state is unfiltered -> counter MUST NOT be displayed
        expect(find.byKey(const Key('vault_showing_results_counter')), findsNothing);

        // 3. Apply search filter "Goblin"
        await tester.tap(find.byKey(const Key('vault_search_expand_button')));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const Key('vault_search_text_field')), 'Goblin');
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        // 4. Assert Key('vault_showing_results_counter') renders "showing 180 results"
        expect(find.byKey(const Key('vault_showing_results_counter')), findsOneWidget);
        expect(find.text('showing 180 results'), findsOneWidget);

        // 5. Assert rendered slice and pagination invariants
        // Database contains 180 matching items, but pagination slice is strictly 50
        expect(capturedRef.read(vaultPaginationLimitProvider), equals(50));
        expect(capturedRef.read(vaultItemsStreamProvider).value!.length, equals(50));

        final sliverGrid = tester.widget<SliverGrid>(find.byKey(const PageStorageKey<String>('vault_cards_sliver_grid')));
        final delegate = sliverGrid.delegate as SliverChildBuilderDelegate;
        expect(delegate.childCount, equals(50),
            reason: 'SliverGrid delegate childCount must be strictly bounded to the initial pagination limit of 50');

        final renderedTiles = find.byType(VaultItemTile).evaluate();
        expect(renderedTiles.length, lessThanOrEqualTo(50));
        expect(renderedTiles.length, greaterThan(0));

        // 6. Dynamically insert a 181st matching card into the database
        await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'bulk_goblin_180',
            collectionType: 'mtg',
            name: 'Goblin Guide 180',
            setOrSeries: 'Zendikar',
            imageUrl: 'https://cards.scryfall.io/goblin_180.jpg',
            acquiredPrice: 5.0,
            acquiredDate: now,
            lastPriceUpdate: now,
            currentMarketPrice: 8.0,
            quantity: const Value(1),
            condition: 'NM',
            dynamicData: '{"colors":["R"],"legalities":{"commander":"legal"}}',
          ),
        );

        // Allow reactive stream query to re-emit and Flutter to rebuild
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        // 7. Assert counter reactively updates to "showing 181 results"
        expect(find.byKey(const Key('vault_showing_results_counter')), findsOneWidget);
        expect(find.text('showing 181 results'), findsOneWidget);

        // Rendered slice and child count remain strictly bounded by pagination limit of 50
        expect(capturedRef.read(vaultPaginationLimitProvider), equals(50));
        expect(capturedRef.read(vaultItemsStreamProvider).value!.length, equals(50));
        final updatedGrid = tester.widget<SliverGrid>(find.byKey(const PageStorageKey<String>('vault_cards_sliver_grid')));
        final updatedDelegate = updatedGrid.delegate as SliverChildBuilderDelegate;
        expect(updatedDelegate.childCount, equals(50));
        expect(find.byType(VaultItemTile).evaluate().length, lessThanOrEqualTo(50));

        // 8. Clear filter via clear button and assert counter is removed
        expect(find.byKey(const Key('vault_search_clear_button')), findsOneWidget);
        await tester.tap(find.byKey(const Key('vault_search_clear_button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('vault_showing_results_counter')), findsNothing,
            reason: 'Clearing filter must immediately remove the results counter');
      },
    );

    testWidgets(
      'Adversarial Invariant: MTG Filter Provider reactivity with dynamic card insertion and reset',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final now = DateTime.now();

        // Insert 180 Red cards
        final redCards = <VaultItemsCompanion>[];
        for (int i = 0; i < 180; i++) {
          redCards.add(
            VaultItemsCompanion.insert(
              id: 'red_dragon_$i',
              collectionType: 'mtg',
              name: 'Shivan Dragon $i',
              setOrSeries: 'Alpha',
              imageUrl: 'https://cards.scryfall.io/dragon_$i.jpg',
              acquiredPrice: 10.0,
              acquiredDate: now,
              lastPriceUpdate: now,
              currentMarketPrice: 15.0,
              quantity: const Value(1),
              condition: 'NM',
              dynamicData: '{"colors":["R"],"legalities":{"commander":"legal"}}',
            ),
          );
        }
        await db.batch((b) {
          b.insertAll(db.vaultItems, redCards);
        });

        late WidgetRef capturedRef;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              vaultDaoProvider.overrideWithValue(db.vaultDao),
              activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
            ],
            child: MaterialApp(
              home: Consumer(
                builder: (context, ref, child) {
                  capturedRef = ref;
                  return const VaultScreen();
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Activate Red MTG Filter programmatically
        capturedRef.read(mtgFilterProvider.notifier).state = const MtgFilterState(
          colors: {'R'},
          colorMatchMode: ColorMatchMode.including,
        );
        await tester.pumpAndSettle();

        // 180 results displayed
        expect(find.byKey(const Key('vault_showing_results_counter')), findsOneWidget);
        expect(find.text('showing 180 results'), findsOneWidget);
        expect(capturedRef.read(vaultPaginationLimitProvider), equals(50));
        expect(capturedRef.read(vaultItemsStreamProvider).value!.length, equals(50));
        final sliverGrid = tester.widget<SliverGrid>(find.byKey(const PageStorageKey<String>('vault_cards_sliver_grid')));
        final delegate = sliverGrid.delegate as SliverChildBuilderDelegate;
        expect(delegate.childCount, equals(50));
        expect(find.byType(VaultItemTile).evaluate().length, lessThanOrEqualTo(50));

        // Insert 181st Red card
        await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'red_dragon_180',
            collectionType: 'mtg',
            name: 'Shivan Dragon 180',
            setOrSeries: 'Alpha',
            imageUrl: 'https://cards.scryfall.io/dragon_180.jpg',
            acquiredPrice: 10.0,
            acquiredDate: now,
            lastPriceUpdate: now,
            currentMarketPrice: 15.0,
            quantity: const Value(1),
            condition: 'NM',
            dynamicData: '{"colors":["R"],"legalities":{"commander":"legal"}}',
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        // Counter reactively updates to 181
        expect(find.text('showing 181 results'), findsOneWidget);
        expect(capturedRef.read(vaultPaginationLimitProvider), equals(50));
        expect(capturedRef.read(vaultItemsStreamProvider).value!.length, equals(50));
        final updatedGrid = tester.widget<SliverGrid>(find.byKey(const PageStorageKey<String>('vault_cards_sliver_grid')));
        final updatedDelegate = updatedGrid.delegate as SliverChildBuilderDelegate;
        expect(updatedDelegate.childCount, equals(50));
        expect(find.byType(VaultItemTile).evaluate().length, lessThanOrEqualTo(50));

        // Clear MTG Filter
        capturedRef.read(mtgFilterProvider.notifier).state = const MtgFilterState();
        await tester.pumpAndSettle();

        // Counter removed
        expect(find.byKey(const Key('vault_showing_results_counter')), findsNothing);
      },
    );

    testWidgets(
      'Adversarial Invariant: Singular/plural/zero transitions: 0 -> 1 -> 2 -> 1 -> 0 results',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final now = DateTime.now();

        await tester.pumpWidget(createVaultHarness());
        await tester.pumpAndSettle();

        // Expand search bar and query for "Mox"
        await tester.tap(find.byKey(const Key('vault_search_expand_button')));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const Key('vault_search_text_field')), 'Mox');
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        // 1. Initial: 0 matching cards -> "showing 0 results"
        expect(find.byKey(const Key('vault_showing_results_counter')), findsOneWidget);
        expect(find.text('showing 0 results'), findsOneWidget);

        // 2. Insert 1st card -> reactively transitions to "showing 1 result" (singular)
        await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'mox_ruby_1',
            collectionType: 'mtg',
            name: 'Mox Ruby',
            setOrSeries: 'Alpha',
            imageUrl: '',
            acquiredPrice: 5000.0,
            acquiredDate: now,
            lastPriceUpdate: now,
            currentMarketPrice: 7000.0,
            quantity: const Value(1),
            condition: 'NM',
            dynamicData: '{"colors":[]}',
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('vault_showing_results_counter')), findsOneWidget);
        expect(find.text('showing 1 result'), findsOneWidget);

        // 3. Insert 2nd card -> reactively transitions to "showing 2 results" (plural)
        await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'mox_sapphire_1',
            collectionType: 'mtg',
            name: 'Mox Sapphire',
            setOrSeries: 'Alpha',
            imageUrl: '',
            acquiredPrice: 6000.0,
            acquiredDate: now,
            lastPriceUpdate: now,
            currentMarketPrice: 8500.0,
            quantity: const Value(1),
            condition: 'NM',
            dynamicData: '{"colors":[]}',
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('vault_showing_results_counter')), findsOneWidget);
        expect(find.text('showing 2 results'), findsOneWidget);

        // 4. Soft-delete 2nd card -> reactively transitions back to "showing 1 result"
        await (db.update(db.vaultItems)..where((t) => t.id.equals('mox_sapphire_1')))
            .write(const VaultItemsCompanion(isDeleted: Value(true)));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('vault_showing_results_counter')), findsOneWidget);
        expect(find.text('showing 1 result'), findsOneWidget);

        // 5. Soft-delete 1st card -> reactively transitions back to "showing 0 results"
        await (db.update(db.vaultItems)..where((t) => t.id.equals('mox_ruby_1')))
            .write(const VaultItemsCompanion(isDeleted: Value(true)));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('vault_showing_results_counter')), findsOneWidget);
        expect(find.text('showing 0 results'), findsOneWidget);
      },
    );

    testWidgets(
      'Adversarial Invariant: Rapid search input debounce stress and narrow viewport stability',
      (tester) async {
        // Test narrow 320px viewport for layout resilience
        tester.view.physicalSize = const Size(320, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final now = DateTime.now();
        await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'sol_ring_1',
            collectionType: 'mtg',
            name: 'Sol Ring',
            setOrSeries: 'Commander',
            imageUrl: '',
            acquiredPrice: 1.0,
            acquiredDate: now,
            lastPriceUpdate: now,
            currentMarketPrice: 2.0,
            quantity: const Value(1),
            condition: 'NM',
            dynamicData: '{"colors":[]}',
          ),
        );

        await tester.pumpWidget(createVaultHarness());
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('vault_search_expand_button')));
        await tester.pumpAndSettle();

        // Rapid keystroke inputs simulating fast typing
        final searchField = find.byKey(const Key('vault_search_text_field'));
        final queries = ['S', 'So', 'Sol', 'Sol ', 'Sol R', 'Sol Ri', 'Sol Rin', 'Sol Ring'];
        for (final q in queries) {
          await tester.enterText(searchField, q);
          await tester.pump(const Duration(milliseconds: 50));
        }

        // Settle debounce (250ms)
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('vault_showing_results_counter')), findsOneWidget);
        expect(find.text('showing 1 result'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'Zero layout exceptions on rapid typing');
      },
    );
  });

  group('Milestone 2 Challenger 2: ExploreDecksTabView Dynamic Count Badge Reactivity', () {
    late AppDatabase db;
    late ExploreDeckDao exploreDao;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      exploreDao = ExploreDeckDao(db);
      await ExploreSeederService.seedFromRawDecks(db, FallbackExploreSeeds.allSeeds);
    });

    tearDown(() async {
      await db.close();
    });

    Widget createExploreHarness({
      List<Override> overrides = const [],
    }) {
      return ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          exploreDeckDaoProvider.overrideWithValue(exploreDao),
          ...overrides,
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: ExploreDecksTabView(),
          ),
        ),
      );
    }

    testWidgets(
      'Adversarial Invariant: Category transitions reactively update Key("explore_decks_count_badge")',
      (tester) async {
        tester.view.physicalSize = const Size(390, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(createExploreHarness());
        await tester.pumpAndSettle();

        // 1. Initial State ("All" Category) -> 19 decks
        expect(find.byKey(const Key('explore_decks_count_badge')), findsOneWidget);
        expect(find.text('19 decks'), findsOneWidget);

        // 2. Transition to "Official (WotC)" -> 12 decks
        await tester.tap(find.byKey(const Key('explore_pill_official')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('explore_decks_count_badge')), findsOneWidget);
        expect(find.text('12 decks'), findsOneWidget);

        // 3. Transition to "Community" -> 7 decks
        await tester.tap(find.byKey(const Key('explore_pill_community')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('explore_decks_count_badge')), findsOneWidget);
        expect(find.text('7 decks'), findsOneWidget);

        // 4. Transition back to "All" -> 19 decks
        await tester.tap(find.byKey(const Key('explore_pill_all')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('explore_decks_count_badge')), findsOneWidget);
        expect(find.text('19 decks'), findsOneWidget);
      },
    );

    testWidgets(
      'Adversarial Invariant: Filter & search transitions reactively update Key("explore_decks_count_badge")',
      (tester) async {
        tester.view.physicalSize = const Size(390, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        late WidgetRef capturedRef;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              exploreDeckDaoProvider.overrideWithValue(exploreDao),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: Consumer(
                  builder: (context, ref, child) {
                    capturedRef = ref;
                    return const ExploreDecksTabView();
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Baseline: 19 decks
        expect(find.byKey(const Key('explore_decks_count_badge')), findsOneWidget);
        expect(find.text('19 decks'), findsOneWidget);

        // Filter by format: Commander
        final commanderCount = await exploreDao.getFilteredExploreDeckCount(
          filter: const ExploreFilterState(format: 'Commander'),
        );
        capturedRef.read(exploreFilterStateProvider.notifier).state =
            const ExploreFilterState(format: 'Commander');
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('explore_decks_count_badge')), findsOneWidget);
        expect(find.text('$commanderCount decks'), findsOneWidget);

        // Filter by price range: budget_0_50
        final budgetCount = await exploreDao.getFilteredExploreDeckCount(
          filter: const ExploreFilterState(priceRange: 'budget_0_50'),
        );
        capturedRef.read(exploreFilterStateProvider.notifier).state =
            const ExploreFilterState(priceRange: 'budget_0_50');
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('explore_decks_count_badge')), findsOneWidget);
        expect(find.text('$budgetCount decks'), findsOneWidget);

        // Reset filter
        capturedRef.read(exploreFilterStateProvider.notifier).state =
            const ExploreFilterState();
        await tester.pumpAndSettle();
        expect(find.text('19 decks'), findsOneWidget);
      },
    );

    testWidgets(
      'Adversarial Invariant: Live dynamic deck insertion (19 -> 20) and soft-deletion (20 -> 19) in ExploreDecksTabView',
      (tester) async {
        tester.view.physicalSize = const Size(390, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(createExploreHarness());
        await tester.pumpAndSettle();

        expect(find.text('19 decks'), findsOneWidget);

        // Dynamically insert a 20th deck into explore_decks
        const newDeckId = 'adversarial_dynamic_deck_20';
        await db.into(db.exploreDecks).insert(
          ExploreDecksCompanion.insert(
            id: newDeckId,
            name: 'Challenger Dynamic Deck 20',
            format: 'Commander',
            sourceType: const Value('community'),
            creatorName: const Value('EmpiricalChallenger'),
            createdAt: DateTime.now(),
            updatedAt: Value(DateTime.now()),
          ),
        );

        // Allow Drift stream query to emit and UI to react
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        // Assert count badge reactively updates to '20 decks'
        expect(find.byKey(const Key('explore_decks_count_badge')), findsOneWidget);
        expect(find.text('20 decks'), findsOneWidget);

        // Switch to Community category -> should be 8 decks (7 initial + 1 inserted)
        await tester.tap(find.byKey(const Key('explore_pill_community')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('explore_decks_count_badge')), findsOneWidget);
        expect(find.text('8 decks'), findsOneWidget);

        // Soft-delete the dynamically inserted deck
        await (db.update(db.exploreDecks)..where((t) => t.id.equals(newDeckId)))
            .write(const ExploreDecksCompanion(isDeleted: Value(true)));

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        // Community count drops back to 7 decks
        expect(find.byKey(const Key('explore_decks_count_badge')), findsOneWidget);
        expect(find.text('7 decks'), findsOneWidget);

        // Switch back to All -> drops back to 19 decks
        await tester.tap(find.byKey(const Key('explore_pill_all')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('explore_decks_count_badge')), findsOneWidget);
        expect(find.text('19 decks'), findsOneWidget);
      },
    );

    testWidgets(
      'Adversarial Invariant: Rapid category pill switching stress under constrained viewports',
      (tester) async {
        tester.view.physicalSize = const Size(450, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(createExploreHarness());
        await tester.pumpAndSettle();

        final officialPill = find.byKey(const Key('explore_pill_official'));
        final communityPill = find.byKey(const Key('explore_pill_community'));
        final allPill = find.byKey(const Key('explore_pill_all'));

        // Rapid category toggling across 5 full cycles
        for (int i = 0; i < 5; i++) {
          await tester.tap(officialPill);
          await tester.pump(const Duration(milliseconds: 20));
          await tester.tap(communityPill);
          await tester.pump(const Duration(milliseconds: 20));
          await tester.tap(allPill);
          await tester.pump(const Duration(milliseconds: 20));
        }

        await tester.pumpAndSettle();

        // Final state is "All" -> must accurately reflect 19 decks with 0 exceptions
        expect(find.byKey(const Key('explore_decks_count_badge')), findsOneWidget);
        expect(find.text('19 decks'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'Zero exceptions during rapid category switching');
      },
    );
  });
}
