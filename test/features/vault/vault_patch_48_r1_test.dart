import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/vault/domain/models/vault_set_collection.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/screens/vault_screen.dart';
import 'package:countr/features/vault/presentation/widgets/full_screen_card_viewer.dart';
import 'package:countr/features/vault/presentation/widgets/vault_collection_view_sliver.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_tile.dart';

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

  group('Countr 4.8 Patch - Requirement R1 Tests', () {
    test('R1.4: VaultSetCollection domain model supports releaseDate property', () {
      const collection = VaultSetCollection(
        setName: 'Modern Horizons 3',
        setCode: 'MH3',
        collectionType: 'mtg',
        totalCount: 100,
        ownedCount: 50,
        completionPercentage: 0.5,
        releaseDate: '2024-06-14',
      );

      expect(collection.releaseDate, equals('2024-06-14'));
      expect(collection.toString(), contains('releaseDate: 2024-06-14'));

      final copied = collection.copyWith(releaseDate: '2024-07-01');
      expect(copied.releaseDate, equals('2024-07-01'));
      expect(copied == collection, isFalse);
    });

    test('R1.4: watchSetCollections sorts by completion percentage descending, then release date descending', () async {
      // Set A: 50% completion, released 2023-01-01
      await db.vaultDao.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'set-a-1',
          collectionType: 'mtg',
          name: 'Card A1',
          setOrSeries: 'Set A (Older, 50%)',
          imageUrl: 'https://example.com/a1.jpg',
          acquiredPrice: 5.0,
          acquiredDate: DateTime(2023, 1, 1),
          quantity: const drift.Value(1),
          condition: 'NM',
          isGraded: const drift.Value(false),
          currentMarketPrice: 5.0,
          lastPriceUpdate: DateTime.now(),
          dynamicData: jsonEncode({
            'set': 'seta',
            'set_code': 'seta',
            'released_at': '2023-01-01',
          }),
        ),
      );
      await db.vaultDao.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'set-a-2',
          collectionType: 'mtg',
          name: 'Card A2',
          setOrSeries: 'Set A (Older, 50%)',
          imageUrl: 'https://example.com/a2.jpg',
          acquiredPrice: 0.0,
          acquiredDate: DateTime(2023, 1, 1),
          quantity: const drift.Value(0),
          condition: 'NM',
          isGraded: const drift.Value(false),
          currentMarketPrice: 5.0,
          lastPriceUpdate: DateTime.now(),
          dynamicData: jsonEncode({
            'set': 'seta',
            'set_code': 'seta',
            'released_at': '2023-01-01',
          }),
        ),
      );

      // Set B: 100% completion, released 2022-01-01 (older release)
      await db.vaultDao.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'set-b-1',
          collectionType: 'mtg',
          name: 'Card B1',
          setOrSeries: 'Set B (100%, 2022)',
          imageUrl: 'https://example.com/b1.jpg',
          acquiredPrice: 10.0,
          acquiredDate: DateTime(2022, 1, 1),
          quantity: const drift.Value(1),
          condition: 'NM',
          isGraded: const drift.Value(false),
          currentMarketPrice: 10.0,
          lastPriceUpdate: DateTime.now(),
          dynamicData: jsonEncode({
            'set': 'setb',
            'set_code': 'setb',
            'released_at': '2022-01-01',
          }),
        ),
      );

      // Set C: 100% completion, released 2024-01-01 (newer release)
      await db.vaultDao.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'set-c-1',
          collectionType: 'mtg',
          name: 'Card C1',
          setOrSeries: 'Set C (100%, 2024)',
          imageUrl: 'https://example.com/c1.jpg',
          acquiredPrice: 15.0,
          acquiredDate: DateTime(2024, 1, 1),
          quantity: const drift.Value(1),
          condition: 'NM',
          isGraded: const drift.Value(false),
          currentMarketPrice: 15.0,
          lastPriceUpdate: DateTime.now(),
          dynamicData: jsonEncode({
            'set': 'setc',
            'set_code': 'setc',
            'released_at': '2024-01-01',
          }),
        ),
      );

      final collections = await db.vaultDao.watchSetCollections(collectionType: 'mtg').first;
      expect(collections.length, equals(3));

      // Order should be:
      // 1. Set C (100%, released 2024-01-01) - highest completion, newer date tie-breaker
      // 2. Set B (100%, released 2022-01-01) - highest completion, older date
      // 3. Set A (50%, released 2023-01-01)  - lower completion
      expect(collections[0].setName, equals('Set C (100%, 2024)'));
      expect(collections[0].releaseDate, equals('2024-01-01'));
      expect(collections[0].completionPercentage, equals(1.0));

      expect(collections[1].setName, equals('Set B (100%, 2022)'));
      expect(collections[1].releaseDate, equals('2022-01-01'));
      expect(collections[1].completionPercentage, equals(1.0));

      expect(collections[2].setName, equals('Set A (Older, 50%)'));
      expect(collections[2].releaseDate, equals('2023-01-01'));
      expect(collections[2].completionPercentage, equals(0.5));
    });

    testWidgets('R1.4: Collections tab displays collections in a 2x2 SliverGrid', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Insert 4 sets
      for (int i = 1; i <= 4; i++) {
        await db.vaultDao.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'coll-item-$i',
            collectionType: 'mtg',
            name: 'Card $i',
            setOrSeries: 'Set 0$i',
            imageUrl: 'https://example.com/img$i.jpg',
            acquiredPrice: 10.0,
            acquiredDate: DateTime(2024, i, 1),
            quantity: const drift.Value(1),
            condition: 'NM',
            isGraded: const drift.Value(false),
            currentMarketPrice: 10.0,
            lastPriceUpdate: DateTime.now(),
            dynamicData: jsonEncode({
              'set': 's0$i',
              'set_code': 's0$i',
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

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: VaultScreen(),
        ),
      ));
      await tester.pumpAndSettle();

      // Find collections SliverGrid with 2 columns
      final gridFinder = find.byKey(const Key('vault_collections_sliver_grid'));
      expect(gridFinder, findsOneWidget);
      final grid = tester.widget<SliverGrid>(gridFinder);
      final delegate = grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, equals(2));

      // 4 collection cards displayed in the 2x2 grid
      expect(find.byType(VaultCollectionCard), findsNWidgets(4));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('R1.1: Dedicated layout row is persistent below view switcher', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'mtg'),
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
        ],
      );

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: VaultScreen(),
        ),
      ));
      await tester.pumpAndSettle();

      // Both primary view toggle and layout switcher are visible
      expect(find.byKey(const Key('vault_view_singles_toggle')), findsOneWidget);
      expect(find.byKey(const Key('vault_view_binders_toggle')), findsOneWidget);
      expect(find.byKey(const Key('vault_view_collections_toggle')), findsOneWidget);
      expect(find.byKey(const Key('vault_layout_grid_button')), findsOneWidget);
      expect(find.byKey(const Key('vault_layout_list_button')), findsOneWidget);

      // Verify layout switcher is positioned strictly below view toggle
      final viewTogglePos = tester.getTopLeft(find.byKey(const Key('vault_view_singles_toggle')));
      final layoutBtnPos = tester.getTopLeft(find.byKey(const Key('vault_layout_grid_button')));
      expect(layoutBtnPos.dy, greaterThan(viewTogglePos.dy));

      // Expand search
      await tester.tap(find.byKey(const Key('vault_search_expand_button')));
      await tester.pumpAndSettle();

      // View toggle is now hidden under search, but layout switcher persists in dedicated row
      expect(find.byKey(const Key('vault_search_text_field')), findsOneWidget);
      expect(find.byKey(const Key('vault_layout_grid_button')), findsOneWidget);
      expect(find.byKey(const Key('vault_layout_list_button')), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('R1.2: Tile mode uses BoxFit.contain and childAspectRatio ~0.54', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Insert card
      await db.vaultDao.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-aspect-1',
          collectionType: 'mtg',
          name: 'Aspect Ratio Test Card',
          setOrSeries: 'Test Set',
          imageUrl: 'https://example.com/art.jpg',
          acquiredPrice: 10.0,
          acquiredDate: DateTime(2024, 1, 1),
          quantity: const drift.Value(1),
          condition: 'NM',
          isGraded: const drift.Value(false),
          currentMarketPrice: 10.0,
          lastPriceUpdate: DateTime.now(),
          dynamicData: '{"oracle_text":"Test"}',
        ),
      );

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'mtg'),
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
          cardDisplayLayoutProvider.overrideWith((ref) => CardDisplayLayout.grid),
        ],
      );

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: VaultScreen(),
        ),
      ));
      await tester.pumpAndSettle();

      // Verify grid childAspectRatio is ~0.54 at 1.0x text scale
      final gridFinder = find.byKey(const PageStorageKey<String>('vault_cards_sliver_grid'));
      expect(gridFinder, findsOneWidget);
      final grid = tester.widget<SliverGrid>(gridFinder);
      final delegate = grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.childAspectRatio, equals(0.54));

      // Verify VaultItemTile renders CountrCachedImage with BoxFit.contain
      final tileFinder = find.byType(VaultItemTile);
      expect(tileFinder, findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('R1.3: FullScreenCardViewer physics is BouncingScrollPhysics and panEnabled is false unzoomed', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final testItem = VaultItem(
        id: 'fs-test-1',
        collectionType: 'mtg',
        name: 'FullScreen Card',
        setOrSeries: 'Test Set',
        imageUrl: 'https://example.com/fs.jpg',
        acquiredPrice: 10.0,
        acquiredDate: DateTime(2024, 1, 1),
        quantity: 1,
        condition: 'NM',
        isGraded: false,
        isAltered: false,
        isMisprint: false,
        isSigned: false,
        isDeleted: false,
        currentMarketPrice: 10.0,
        lastPriceUpdate: DateTime.now(),
        dynamicData: '{}',
      );

      await tester.pumpWidget(MaterialApp(
        home: FullScreenCardViewer(item: testItem),
      ));
      await tester.pumpAndSettle();

      final pageViewFinder = find.byKey(const Key('fullscreen_page_view'));
      expect(pageViewFinder, findsOneWidget);
      final pageView = tester.widget<PageView>(pageViewFinder);
      expect(pageView.physics, isA<BouncingScrollPhysics>());

      final ivFinder = find.byKey(const Key('fullscreen_interactive_viewer'));
      expect(ivFinder, findsOneWidget);
      final iv = tester.widget<InteractiveViewer>(ivFinder);
      expect(iv.panEnabled, isFalse);
      expect(iv.boundaryMargin, equals(EdgeInsets.zero));
    });
  });
}
