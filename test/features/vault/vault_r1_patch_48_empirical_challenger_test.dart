import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/screens/vault_screen.dart';
import 'package:countr/features/vault/presentation/widgets/vault_collection_view_sliver.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.vaultDao.clearAllItems();
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildHarness({
    required ProviderContainer container,
    Size? viewportSize,
    double? textScale,
  }) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        builder: (context, child) {
          MediaQueryData data = MediaQuery.of(context);
          if (viewportSize != null) {
            data = data.copyWith(size: viewportSize);
          } else {
            data = data.copyWith(size: const Size(1080, 2400));
          }
          if (textScale != null) {
            data = data.copyWith(textScaler: TextScaler.linear(textScale));
          }
          return MediaQuery(
            data: data,
            child: child!,
          );
        },
        home: const VaultScreen(),
      ),
    );
  }

  // ===========================================================================
  // GROUP 1: EMPIRICAL CHALLENGE — 2x2 COLLECTIONS GRID
  // ===========================================================================
  group('Empirical Challenge: 2x2 Collections Grid', () {
    testWidgets('Grid with 0 collections: renders empty state without crashing', (tester) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'mtg'),
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.collections),
        ],
      );

      await tester.pumpWidget(buildHarness(container: container));
      await tester.pumpAndSettle();

      // Verify no SliverGrid is present when empty
      expect(find.byKey(const Key('vault_collections_sliver_grid')), findsNothing);
      expect(find.byType(VaultCollectionCard), findsNothing);

      // Verify empty state container and copy are rendered
      expect(find.byIcon(Icons.collections_bookmark_outlined), findsOneWidget);
      expect(find.text('No Collections in mtg'), findsOneWidget);
      expect(
        find.text('Set collections will appear here once cards are saved or catalog data is hydrated.'),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('Grid with 1 collection: renders single tile in 2x2 grid, expands & collapses cleanly', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await db.vaultDao.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'coll-solo-1',
          collectionType: 'mtg',
          name: 'Solo Set Card',
          setOrSeries: 'Solo Set',
          imageUrl: 'https://example.com/solo.jpg',
          acquiredPrice: 10.0,
          acquiredDate: DateTime(2024, 1, 1),
          quantity: const drift.Value(1),
          condition: 'NM',
          isGraded: const drift.Value(false),
          currentMarketPrice: 10.0,
          lastPriceUpdate: DateTime.now(),
          dynamicData: jsonEncode({
            'set': 'solo',
            'set_code': 'solo',
            'collector_number': '1',
            'released_at': '2024-01-01',
          }),
        ),
      );

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'mtg'),
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.collections),
        ],
      );

      await tester.pumpWidget(buildHarness(container: container));
      await tester.pumpAndSettle();

      // Verify 2x2 grid is mounted with crossAxisCount: 2
      final gridFinder = find.byKey(const Key('vault_collections_sliver_grid'));
      expect(gridFinder, findsOneWidget);
      final grid = tester.widget<SliverGrid>(gridFinder);
      final delegate = grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, equals(2));

      // Exactly 1 card is displayed
      expect(find.byType(VaultCollectionCard), findsOneWidget);
      expect(find.byKey(const Key('vault_collection_tile_SOLO')), findsOneWidget);

      // Verify expansion: tap the card header
      await tester.tap(find.byKey(const Key('vault_collection_header_SOLO')));
      await tester.pumpAndSettle();

      // Expanded section is mounted
      expect(find.text('Solo Set Cards'), findsOneWidget);
      expect(find.byKey(const Key('vault_collection_grid_SOLO')), findsOneWidget);
      expect(find.text('Solo Set Card'), findsOneWidget);

      // Verify collapse: tap the close icon in expanded header
      final closeFinder = find.byTooltip('Close set cards');
      expect(closeFinder, findsOneWidget);
      await tester.tap(closeFinder);
      await tester.pumpAndSettle();

      // Expanded section is unmounted
      expect(find.text('Solo Set Cards'), findsNothing);
      expect(find.byKey(const Key('vault_collection_grid_SOLO')), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('Grid with odd number of collections (3 and 5): layouts correctly with no overflow', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Insert 3 collections
      for (int i = 1; i <= 3; i++) {
        await db.vaultDao.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'coll-item-odd-$i',
            collectionType: 'mtg',
            name: 'Card in Set $i',
            setOrSeries: 'Set $i',
            imageUrl: 'https://example.com/img$i.jpg',
            acquiredPrice: 5.0 * i,
            acquiredDate: DateTime(2024, i, 1),
            quantity: const drift.Value(1),
            condition: 'NM',
            isGraded: const drift.Value(false),
            currentMarketPrice: 5.0 * i,
            lastPriceUpdate: DateTime.now(),
            dynamicData: jsonEncode({
              'set': 's$i',
              'set_code': 's$i',
              'collector_number': '$i',
              'released_at': '2024-0$i-01',
            }),
          ),
        );
      }

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'mtg'),
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.collections),
        ],
      );

      await tester.pumpWidget(buildHarness(container: container));
      await tester.pumpAndSettle();

      // Verify 3 collection cards are in the 2x2 grid
      expect(find.byType(VaultCollectionCard), findsNWidgets(3));

      // Tap the 3rd collection (the odd element in row 2)
      await tester.tap(find.byKey(const Key('vault_collection_header_S3')));
      await tester.pumpAndSettle();

      // Expanded section for Set 3 mounts cleanly
      expect(find.text('Set 3 Cards'), findsOneWidget);
      expect(find.byKey(const Key('vault_collection_grid_S3')), findsOneWidget);

      // Now insert 2 more sets to make 5 collections (odd count)
      for (int i = 4; i <= 5; i++) {
        await db.vaultDao.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'coll-item-odd-$i',
            collectionType: 'mtg',
            name: 'Card in Set $i',
            setOrSeries: 'Set $i',
            imageUrl: 'https://example.com/img$i.jpg',
            acquiredPrice: 5.0 * i,
            acquiredDate: DateTime(2024, i, 1),
            quantity: const drift.Value(1),
            condition: 'NM',
            isGraded: const drift.Value(false),
            currentMarketPrice: 5.0 * i,
            lastPriceUpdate: DateTime.now(),
            dynamicData: jsonEncode({
              'set': 's$i',
              'set_code': 's$i',
              'collector_number': '$i',
              'released_at': '2024-0$i-01',
            }),
          ),
        );
      }
      await tester.pumpAndSettle();

      // Verify 5 collection cards are displayed
      expect(find.byType(VaultCollectionCard), findsNWidgets(5));

      // Tap 5th card header to expand it
      await tester.tap(find.byKey(const Key('vault_collection_header_S5')));
      await tester.pumpAndSettle();

      // Set 3 is collapsed, Set 5 is expanded
      expect(find.text('Set 3 Cards'), findsNothing);
      expect(find.text('Set 5 Cards'), findsOneWidget);
      expect(find.byKey(const Key('vault_collection_grid_S5')), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    test('watchSetCollections: identical completion % tie-breaks by release date descending, then name ascending', () async {
      // 4 sets with IDENTICAL 50% completion
      // Set 1: released 2024-06-01, name "Zeta Set"
      // Set 2: released 2024-06-01, name "Alpha Set" (same date as Set 1 -> tie-break by name)
      // Set 3: released 2022-01-01, name "Beta Set" (older release date)
      // Set 4: released 2025-01-01, name "Omega Set" (newest release date)

      final sets = [
        {'name': 'Zeta Set', 'code': 'zeta', 'date': '2024-06-01'},
        {'name': 'Alpha Set', 'code': 'alph', 'date': '2024-06-01'},
        {'name': 'Beta Set', 'code': 'beta', 'date': '2022-01-01'},
        {'name': 'Omega Set', 'code': 'omeg', 'date': '2025-01-01'},
      ];

      for (final s in sets) {
        // 1 owned card
        await db.vaultDao.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: '${s['code']}-card-1',
            collectionType: 'mtg',
            name: '${s['name']} Card 1',
            setOrSeries: s['name']!,
            imageUrl: 'https://example.com/${s['code']}1.jpg',
            acquiredPrice: 5.0,
            acquiredDate: DateTime(2024, 1, 1),
            quantity: const drift.Value(1),
            condition: 'NM',
            isGraded: const drift.Value(false),
            currentMarketPrice: 5.0,
            lastPriceUpdate: DateTime.now(),
            dynamicData: jsonEncode({
              'set': s['code'],
              'set_code': s['code'],
              'released_at': s['date'],
            }),
          ),
        );
        // 1 unowned card -> 50% completion
        await db.vaultDao.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: '${s['code']}-card-2',
            collectionType: 'mtg',
            name: '${s['name']} Card 2',
            setOrSeries: s['name']!,
            imageUrl: 'https://example.com/${s['code']}2.jpg',
            acquiredPrice: 0.0,
            acquiredDate: DateTime(2024, 1, 1),
            quantity: const drift.Value(0),
            condition: 'NM',
            isGraded: const drift.Value(false),
            currentMarketPrice: 5.0,
            lastPriceUpdate: DateTime.now(),
            dynamicData: jsonEncode({
              'set': s['code'],
              'set_code': s['code'],
              'released_at': s['date'],
            }),
          ),
        );
      }

      final collections = await db.vaultDao.watchSetCollections(collectionType: 'mtg').first;
      expect(collections.length, equals(4));

      // All have 50% completion
      for (final c in collections) {
        expect(c.completionPercentage, equals(0.5));
      }

      // Expected order:
      // 1. "Omega Set" (2025-01-01) - newest release date
      // 2. "Alpha Set" (2024-06-01) - same release date as Zeta, but 'Alpha' < 'Zeta'
      // 3. "Zeta Set"  (2024-06-01)
      // 4. "Beta Set"  (2022-01-01) - oldest release date
      expect(collections[0].setName, equals('Omega Set'));
      expect(collections[0].releaseDate, equals('2025-01-01'));

      expect(collections[1].setName, equals('Alpha Set'));
      expect(collections[1].releaseDate, equals('2024-06-01'));

      expect(collections[2].setName, equals('Zeta Set'));
      expect(collections[2].releaseDate, equals('2024-06-01'));

      expect(collections[3].setName, equals('Beta Set'));
      expect(collections[3].releaseDate, equals('2022-01-01'));
    });

    test('watchSetCollections: null release dates are handled gracefully and sorted safely', () async {
      // Set 1: 50% completion, releaseDate: null, name: "Zeta Null"
      // Set 2: 50% completion, releaseDate: '2024-01-01', name: "Dated Set"
      // Set 3: 50% completion, releaseDate: null, name: "Alpha Null"
      // Set 4: 100% completion, releaseDate: null, name: "Complete Null"

      // Set 1: Zeta Null (50%)
      await db.vaultDao.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'zn-1',
          collectionType: 'mtg',
          name: 'Zeta Card 1',
          setOrSeries: 'Zeta Null',
          imageUrl: 'https://example.com/zn1.jpg',
          acquiredPrice: 5.0,
          acquiredDate: DateTime(2024, 1, 1),
          quantity: const drift.Value(1),
          condition: 'NM',
          isGraded: const drift.Value(false),
          currentMarketPrice: 5.0,
          lastPriceUpdate: DateTime.now(),
          dynamicData: jsonEncode({'set_code': 'zn'}), // No released_at
        ),
      );
      await db.vaultDao.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'zn-2',
          collectionType: 'mtg',
          name: 'Zeta Card 2',
          setOrSeries: 'Zeta Null',
          imageUrl: 'https://example.com/zn2.jpg',
          acquiredPrice: 0.0,
          acquiredDate: DateTime(2024, 1, 1),
          quantity: const drift.Value(0),
          condition: 'NM',
          isGraded: const drift.Value(false),
          currentMarketPrice: 5.0,
          lastPriceUpdate: DateTime.now(),
          dynamicData: jsonEncode({'set_code': 'zn'}),
        ),
      );

      // Set 2: Dated Set (50%, 2024-01-01)
      await db.vaultDao.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'ds-1',
          collectionType: 'mtg',
          name: 'Dated Card 1',
          setOrSeries: 'Dated Set',
          imageUrl: 'https://example.com/ds1.jpg',
          acquiredPrice: 5.0,
          acquiredDate: DateTime(2024, 1, 1),
          quantity: const drift.Value(1),
          condition: 'NM',
          isGraded: const drift.Value(false),
          currentMarketPrice: 5.0,
          lastPriceUpdate: DateTime.now(),
          dynamicData: jsonEncode({'set_code': 'ds', 'released_at': '2024-01-01'}),
        ),
      );
      await db.vaultDao.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'ds-2',
          collectionType: 'mtg',
          name: 'Dated Card 2',
          setOrSeries: 'Dated Set',
          imageUrl: 'https://example.com/ds2.jpg',
          acquiredPrice: 0.0,
          acquiredDate: DateTime(2024, 1, 1),
          quantity: const drift.Value(0),
          condition: 'NM',
          isGraded: const drift.Value(false),
          currentMarketPrice: 5.0,
          lastPriceUpdate: DateTime.now(),
          dynamicData: jsonEncode({'set_code': 'ds', 'released_at': '2024-01-01'}),
        ),
      );

      // Set 3: Alpha Null (50%)
      await db.vaultDao.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'an-1',
          collectionType: 'mtg',
          name: 'Alpha Card 1',
          setOrSeries: 'Alpha Null',
          imageUrl: 'https://example.com/an1.jpg',
          acquiredPrice: 5.0,
          acquiredDate: DateTime(2024, 1, 1),
          quantity: const drift.Value(1),
          condition: 'NM',
          isGraded: const drift.Value(false),
          currentMarketPrice: 5.0,
          lastPriceUpdate: DateTime.now(),
          dynamicData: jsonEncode({'set_code': 'an'}), // No released_at
        ),
      );
      await db.vaultDao.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'an-2',
          collectionType: 'mtg',
          name: 'Alpha Card 2',
          setOrSeries: 'Alpha Null',
          imageUrl: 'https://example.com/an2.jpg',
          acquiredPrice: 0.0,
          acquiredDate: DateTime(2024, 1, 1),
          quantity: const drift.Value(0),
          condition: 'NM',
          isGraded: const drift.Value(false),
          currentMarketPrice: 5.0,
          lastPriceUpdate: DateTime.now(),
          dynamicData: jsonEncode({'set_code': 'an'}),
        ),
      );

      // Set 4: Complete Null (100%, no date)
      await db.vaultDao.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'cn-1',
          collectionType: 'mtg',
          name: 'Complete Card 1',
          setOrSeries: 'Complete Null',
          imageUrl: 'https://example.com/cn1.jpg',
          acquiredPrice: 10.0,
          acquiredDate: DateTime(2024, 1, 1),
          quantity: const drift.Value(1),
          condition: 'NM',
          isGraded: const drift.Value(false),
          currentMarketPrice: 10.0,
          lastPriceUpdate: DateTime.now(),
          dynamicData: jsonEncode({'set_code': 'cn'}), // No released_at
        ),
      );

      final collections = await db.vaultDao.watchSetCollections(collectionType: 'mtg').first;
      expect(collections.length, equals(4));

      // 1. "Complete Null" has 100% completion -> must be index 0
      expect(collections[0].setName, equals('Complete Null'));
      expect(collections[0].completionPercentage, equals(1.0));
      expect(collections[0].releaseDate, isNull);

      // 2. Among 50% sets: "Dated Set" has valid '2024-01-01', while Alpha & Zeta are null
      expect(collections[1].setName, equals('Dated Set'));
      expect(collections[1].releaseDate, equals('2024-01-01'));

      // 3. Between Alpha Null and Zeta Null (both 50%, both null date): alphabetical fallback
      expect(collections[2].setName, equals('Alpha Null'));
      expect(collections[2].releaseDate, isNull);

      expect(collections[3].setName, equals('Zeta Null'));
      expect(collections[3].releaseDate, isNull);
    });

    testWidgets('Collections UI handles null release dates and dynamic card addition while expanded', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await db.vaultDao.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'null-date-card-1',
          collectionType: 'mtg',
          name: 'Null Date Card 1',
          setOrSeries: 'Null Release Set',
          imageUrl: 'https://example.com/null1.jpg',
          acquiredPrice: 5.0,
          acquiredDate: DateTime(2024, 1, 1),
          quantity: const drift.Value(1),
          condition: 'NM',
          isGraded: const drift.Value(false),
          currentMarketPrice: 5.0,
          lastPriceUpdate: DateTime.now(),
          dynamicData: jsonEncode({
            'set': 'nrs',
            'set_code': 'nrs',
            'collector_number': '1',
          }), // No released_at
        ),
      );

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'mtg'),
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.collections),
        ],
      );

      await tester.pumpWidget(buildHarness(container: container));
      await tester.pumpAndSettle();

      // Verify renders without throwing error
      expect(find.text('Null Release Set'), findsOneWidget);
      expect(find.byType(VaultCollectionCard), findsOneWidget);

      // Expand the collection
      await tester.tap(find.byKey(const Key('vault_collection_header_NRS')));
      await tester.pumpAndSettle();

      expect(find.text('Null Release Set Cards'), findsOneWidget);
      expect(find.text('Null Date Card 1'), findsOneWidget);

      // Now dynamically add a second card while expanded
      await db.vaultDao.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'null-date-card-2',
          collectionType: 'mtg',
          name: 'Null Date Card 2',
          setOrSeries: 'Null Release Set',
          imageUrl: 'https://example.com/null2.jpg',
          acquiredPrice: 7.0,
          acquiredDate: DateTime(2024, 1, 2),
          quantity: const drift.Value(0),
          condition: 'NM',
          isGraded: const drift.Value(false),
          currentMarketPrice: 7.0,
          lastPriceUpdate: DateTime.now(),
          dynamicData: jsonEncode({
            'set': 'nrs',
            'set_code': 'nrs',
            'collector_number': '2',
          }),
        ),
      );

      // Settle stream updates
      await tester.pumpAndSettle();

      // Card 2 is now rendered in the expanded grid
      expect(find.text('Null Date Card 2'), findsOneWidget);
      // Unowned card has grayscale filter
      expect(find.byKey(const Key('vault_collection_grayscale_null-date-card-2')), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });

  // ===========================================================================
  // GROUP 2: EMPIRICAL CHALLENGE — LIST/TILE PERSISTENT LAYOUT TOGGLE
  // ===========================================================================
  group('Empirical Challenge: Persistent List/Tile Layout Toggle', () {
    testWidgets('Search expanded vs collapsed: layout toggle persists and toggles layout state', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Seed a card so total count is 1
      await db.vaultDao.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'search-card-1',
          collectionType: 'mtg',
          name: 'Persistent Layout Test Card',
          setOrSeries: 'Test Set',
          imageUrl: 'https://example.com/art.jpg',
          acquiredPrice: 10.0,
          acquiredDate: DateTime(2024, 1, 1),
          quantity: const drift.Value(1),
          condition: 'NM',
          isGraded: const drift.Value(false),
          currentMarketPrice: 10.0,
          lastPriceUpdate: DateTime.now(),
          dynamicData: '{}',
        ),
      );

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'mtg'),
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
        ],
      );

      await tester.pumpWidget(buildHarness(container: container));
      await tester.pumpAndSettle();

      // --- 1. Collapsed Search State ---
      // Primary view switcher is visible
      expect(find.byKey(const Key('vault_view_singles_toggle')), findsOneWidget);
      expect(find.byKey(const Key('vault_view_binders_toggle')), findsOneWidget);
      expect(find.byKey(const Key('vault_view_collections_toggle')), findsOneWidget);

      // Persistent layout switcher is visible
      expect(find.byKey(const Key('vault_layout_list_button')), findsOneWidget);
      expect(find.byKey(const Key('vault_layout_grid_button')), findsOneWidget);

      // Default layout is list; tap grid button to toggle to grid
      await tester.tap(find.byKey(const Key('vault_layout_grid_button')));
      await tester.pumpAndSettle();
      expect(container.read(cardDisplayLayoutProvider), equals(CardDisplayLayout.grid));

      // --- 2. Expand Search ---
      await tester.tap(find.byKey(const Key('vault_search_expand_button')));
      await tester.pumpAndSettle();

      // Top row now shows search input
      expect(find.byKey(const Key('vault_search_text_field')), findsOneWidget);

      // CRITICAL CHECK: Layout switcher STILL PERSISTS below search bar
      expect(find.byKey(const Key('vault_layout_list_button')), findsOneWidget);
      expect(find.byKey(const Key('vault_layout_grid_button')), findsOneWidget);

      // Toggle layout back to list while search is expanded
      await tester.tap(find.byKey(const Key('vault_layout_list_button')));
      await tester.pumpAndSettle();
      expect(container.read(cardDisplayLayoutProvider), equals(CardDisplayLayout.list));

      // Enter search text
      await tester.enterText(find.byKey(const Key('vault_search_text_field')), 'Persistent');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Layout switcher row STILL persists with query entered
      expect(find.byKey(const Key('vault_layout_list_button')), findsOneWidget);
      expect(find.byKey(const Key('vault_layout_grid_button')), findsOneWidget);

      // Collapse search: first tap clears text, second tap closes search
      await tester.tap(find.byKey(const Key('vault_search_clear_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('vault_search_collapse_button')));
      await tester.pumpAndSettle();

      // View toggle returns, layout switcher remains intact
      expect(find.byKey(const Key('vault_view_singles_toggle')), findsOneWidget);
      expect(find.byKey(const Key('vault_layout_list_button')), findsOneWidget);
      expect(find.byKey(const Key('vault_layout_grid_button')), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('Small screens (320px width): Singles mode layout switcher and search bar render with zero overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Insert card
      await db.vaultDao.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'small-screen-card-singles',
          collectionType: 'mtg',
          name: 'Compact Display Card',
          setOrSeries: 'Compact Set',
          imageUrl: 'https://example.com/small.jpg',
          acquiredPrice: 15.0,
          acquiredDate: DateTime(2024, 1, 1),
          quantity: const drift.Value(1),
          condition: 'NM',
          isGraded: const drift.Value(false),
          currentMarketPrice: 15.0,
          lastPriceUpdate: DateTime.now(),
          dynamicData: '{}',
        ),
      );

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'mtg'),
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
        ],
      );

      // Verify Singles mode at 320px
      await tester.pumpWidget(buildHarness(container: container, viewportSize: const Size(320, 568)));
      await tester.pumpAndSettle();

      // Check no overflow errors on 320px in Singles mode
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('vault_layout_list_button')), findsOneWidget);
      expect(find.byKey(const Key('vault_layout_grid_button')), findsOneWidget);

      // Expand search on 320px width
      await tester.tap(find.byKey(const Key('vault_search_expand_button')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('vault_search_text_field')), findsOneWidget);
      expect(find.byKey(const Key('vault_layout_list_button')), findsOneWidget);
      expect(find.byKey(const Key('vault_layout_grid_button')), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('Small screens (320px width): Collections 2x2 grid renders with zero RenderFlex overflow in 100% badge and card column', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Insert 2 complete sets (100% completion)
      for (int i = 1; i <= 2; i++) {
        await db.vaultDao.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'small-screen-card-$i',
            collectionType: 'mtg',
            name: 'Compact Display Card $i',
            setOrSeries: 'Compact Set 0$i',
            imageUrl: 'https://example.com/small$i.jpg',
            acquiredPrice: 15.0,
            acquiredDate: DateTime(2024, 1, 1),
            quantity: const drift.Value(1),
            condition: 'NM',
            isGraded: const drift.Value(false),
            currentMarketPrice: 15.0,
            lastPriceUpdate: DateTime.now(),
            dynamicData: jsonEncode({
              'set': 'cs0$i',
              'set_code': 'cs0$i',
              'collector_number': '$i',
              'released_at': '2024-0$i-01',
            }),
          ),
        );
      }

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'mtg'),
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.collections),
        ],
      );

      final errors = <FlutterErrorDetails>[];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        errors.add(details);
      };

      try {
        await tester.pumpWidget(buildHarness(container: container, viewportSize: const Size(320, 568)));
        await tester.pumpAndSettle();

        // Empirically assert that zero RenderFlex overflow occurs on 320px width
        final overflowErrors = errors.where((e) => e.toString().contains('RenderFlex overflowed')).toList();
        expect(
          overflowErrors.isEmpty,
          isTrue,
          reason: 'Expected 2x2 Collections grid to produce zero RenderFlex overflow on 320px screen',
        );
        expect(tester.takeException(), isNull);
      } finally {
        FlutterError.onError = originalOnError;
      }

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Standard mobile screens (390px width): Collections 2x2 grid renders with zero RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Insert 2 complete sets (100% completion)
      for (int i = 1; i <= 2; i++) {
        await db.vaultDao.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'standard-screen-card-$i',
            collectionType: 'mtg',
            name: 'Standard Display Card $i',
            setOrSeries: 'Standard Set 0$i',
            imageUrl: 'https://example.com/std$i.jpg',
            acquiredPrice: 15.0,
            acquiredDate: DateTime(2024, 1, 1),
            quantity: const drift.Value(1),
            condition: 'NM',
            isGraded: const drift.Value(false),
            currentMarketPrice: 15.0,
            lastPriceUpdate: DateTime.now(),
            dynamicData: jsonEncode({
              'set': 'std0$i',
              'set_code': 'std0$i',
              'collector_number': '$i',
              'released_at': '2024-0$i-01',
            }),
          ),
        );
      }

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'mtg'),
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.collections),
        ],
      );

      await tester.pumpWidget(buildHarness(container: container, viewportSize: const Size(390, 844)));
      await tester.pumpAndSettle();

      // Zero exceptions on standard 390px screen
      expect(tester.takeException(), isNull);
      expect(find.byType(VaultCollectionCard), findsNWidgets(2));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('Large text scale (2.0x): aspect ratio scales gracefully with zero overflow', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Insert card
      await db.vaultDao.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'scale-card-1',
          collectionType: 'mtg',
          name: 'Accessibility Scale Card',
          setOrSeries: 'Accessibility Set',
          imageUrl: 'https://example.com/scale.jpg',
          acquiredPrice: 20.0,
          acquiredDate: DateTime(2024, 1, 1),
          quantity: const drift.Value(1),
          condition: 'NM',
          isGraded: const drift.Value(false),
          currentMarketPrice: 20.0,
          lastPriceUpdate: DateTime.now(),
          dynamicData: jsonEncode({
            'set': 'acs',
            'set_code': 'acs',
            'collector_number': '1',
            'released_at': '2024-01-01',
          }),
        ),
      );

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'mtg'),
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.collections),
        ],
      );

      // Render at 2.0x text scale
      await tester.pumpWidget(buildHarness(
        container: container,
        textScale: 2.0,
      ));
      await tester.pumpAndSettle();

      // Check no overflow errors
      expect(tester.takeException(), isNull);

      // Verify Collections grid dynamicAspectRatio is calibrated to 0.70 at > 1.8x text scale
      final collectionsGridFinder = find.byKey(const Key('vault_collections_sliver_grid'));
      expect(collectionsGridFinder, findsOneWidget);
      final collectionsGrid = tester.widget<SliverGrid>(collectionsGridFinder);
      final collectionsDelegate = collectionsGrid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(collectionsDelegate.childAspectRatio, equals(0.70));

      // Switch to Singles view with Tile (grid) mode at 2.0x scale
      container.read(vaultViewModeProvider.notifier).state = VaultViewMode.allVault;
      container.read(cardDisplayLayoutProvider.notifier).state = CardDisplayLayout.grid;
      await tester.pumpAndSettle();

      // Check no overflow errors
      expect(tester.takeException(), isNull);

      // Verify Singles grid dynamicAspectRatio is calibrated to 0.36 at > 1.8x text scale
      final singlesGridFinder = find.byKey(const PageStorageKey<String>('vault_cards_sliver_grid'));
      expect(singlesGridFinder, findsOneWidget);
      final singlesGrid = tester.widget<SliverGrid>(singlesGridFinder);
      final singlesDelegate = singlesGrid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(singlesDelegate.childAspectRatio, equals(0.36));

      // Verify persistent layout switcher row is still intact at 2.0x scale
      expect(find.byKey(const Key('vault_layout_list_button')), findsOneWidget);
      expect(find.byKey(const Key('vault_layout_grid_button')), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
