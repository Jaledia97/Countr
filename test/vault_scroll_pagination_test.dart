import 'dart:async';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/screens/vault_screen.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_card.dart';

Future<void> _insertTestCards(AppDatabase db, int count, {bool isOwned = true}) async {
  for (int i = 0; i < count; i++) {
    await db.vaultDao.into(db.vaultItems).insert(
      VaultItemsCompanion.insert(
        id: 'test-card-$i',
        collectionType: 'mtg',
        name: 'Card ${i.toString().padLeft(3, '0')}',
        setOrSeries: 'Test Set',
        imageUrl: 'https://example.com/card-$i.jpg',
        acquiredPrice: 10.0 + i,
        acquiredDate: DateTime(2023, 1, 1).add(Duration(days: i)),
        quantity: drift.Value(isOwned ? 1 : 0),
        condition: 'NM',
        isGraded: const drift.Value(false),
        currentMarketPrice: 15.0 + i,
        lastPriceUpdate: DateTime.now(),
        dynamicData: '{"oracle_text":"Test oracle text $i","rarity":"rare"}',
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Requirement R1: Vault Infinite-Scroll & Pagination Provider Integration', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await db.vaultDao.clearAllItems();
    });

    tearDown(() async {
      await db.close();
    });

    test('vaultItemsStreamProvider respects paginationLimit when onlyOwned is true', () async {
      await _insertTestCards(db, 60, isOwned: true);

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
          vaultShowCatalogProvider.overrideWith((ref) => false),
          vaultPaginationLimitProvider.overrideWith((ref) => 50),
        ],
      );

      final first50 = await container.read(vaultItemsStreamProvider.future);
      expect(first50.length, equals(50));

      container.read(vaultPaginationLimitProvider.notifier).state = 100;
      final nextBatch = await container.read(vaultItemsStreamProvider.future);
      expect(nextBatch.length, equals(60));

      container.dispose();
    });

    test('vaultIsFetchingMoreProvider defaults to false and can be updated', () {
      final container = ProviderContainer();
      expect(container.read(vaultIsFetchingMoreProvider), isFalse);

      container.read(vaultIsFetchingMoreProvider.notifier).state = true;
      expect(container.read(vaultIsFetchingMoreProvider), isTrue);

      container.dispose();
    });
  });

  group('Requirement R1: VaultScreen Infinite-Scroll Stabilization Widget Tests', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await db.vaultDao.clearAllItems();
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('VaultScreen retains rendered items without displaying SliverFillRemaining when new pages are fetched',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Insert 5 items so all cards and the bottom sliver are comfortably in viewport
      await _insertTestCards(db, 5, isOwned: true);

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
          vaultPaginationLimitProvider.overrideWith((ref) => 50),
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
          cardDisplayLayoutProvider.overrideWith((ref) => CardDisplayLayout.list),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: VaultScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Initially items are rendered as cards
      expect(find.byType(VaultItemCard), findsWidgets);
      // Full screen loading spinner is NOT present
      expect(find.byType(SliverFillRemaining), findsNothing);
      expect(find.byKey(const Key('vault_fetching_more_indicator')), findsNothing);

      // 1. When fetching more begins, vaultIsFetchingMoreProvider is set to true
      container.read(vaultIsFetchingMoreProvider.notifier).state = true;
      await tester.pump();

      // Verified: Vault cards remain rendered without blanking to SliverFillRemaining
      expect(find.byType(VaultItemCard), findsWidgets);
      expect(find.byType(SliverFillRemaining), findsNothing);

      // Verified: Bottom loading spinner is displayed
      expect(find.byKey(const Key('vault_fetching_more_indicator')), findsOneWidget);

      // 2. When fetching completes, vaultIsFetchingMoreProvider is set to false
      container.read(vaultIsFetchingMoreProvider.notifier).state = false;
      await tester.pump();

      // Verified: Bottom indicator disappears and cards remain rendered
      expect(find.byKey(const Key('vault_fetching_more_indicator')), findsNothing);
      expect(find.byType(VaultItemCard), findsWidgets);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('PageStorageKey is configured on CustomScrollView, SliverList, and SliverGrid', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await _insertTestCards(db, 5, isOwned: true);

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
          cardDisplayLayoutProvider.overrideWith((ref) => CardDisplayLayout.list),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: VaultScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // CustomScrollView has PageStorageKey('vault_custom_scroll_view')
      final customScrollView = tester.widget<CustomScrollView>(find.byType(CustomScrollView));
      expect(customScrollView.key, equals(const PageStorageKey<String>('vault_custom_scroll_view')));

      // In List view, SliverList has PageStorageKey('vault_cards_sliver_list')
      final sliverList = tester.widget<SliverList>(find.byType(SliverList));
      expect(sliverList.key, equals(const PageStorageKey<String>('vault_cards_sliver_list')));

      // Switch to Grid layout
      await tester.ensureVisible(find.byKey(const Key('vault_layout_grid_button')));
      await tester.tap(find.byKey(const Key('vault_layout_grid_button')));
      await tester.pumpAndSettle();

      // In Grid view, SliverGrid has PageStorageKey('vault_cards_sliver_grid')
      final sliverGrid = tester.widget<SliverGrid>(find.byType(SliverGrid));
      expect(sliverGrid.key, equals(const PageStorageKey<String>('vault_cards_sliver_grid')));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('Scroll offset is persisted across rebuilds via PageStorage', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await _insertTestCards(db, 50, isOwned: true);

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
          cardDisplayLayoutProvider.overrideWith((ref) => CardDisplayLayout.list),
        ],
      );

      final pageStorageBucket = PageStorageBucket();

      Widget buildRoot() {
        return UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: PageStorage(
              bucket: pageStorageBucket,
              child: const VaultScreen(),
            ),
          ),
        );
      }

      await tester.pumpWidget(buildRoot());
      await tester.pumpAndSettle();

      // Scroll down
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();

      final scrollable1 = tester.state<ScrollableState>(find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down));
      final scrolledPixels = scrollable1.position.pixels;
      expect(scrolledPixels, greaterThan(200));

      // Rebuild widget tree with same PageStorage bucket
      await tester.pumpWidget(buildRoot());
      await tester.pumpAndSettle();

      final scrollable2 = tester.state<ScrollableState>(find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down));
      expect(scrollable2.position.pixels, equals(scrolledPixels));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('_onScroll does not trigger redundant fetches when vaultIsFetchingMoreProvider is true', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await _insertTestCards(db, 50, isOwned: true);

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
          vaultPaginationLimitProvider.overrideWith((ref) => 50),
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
          cardDisplayLayoutProvider.overrideWith((ref) => CardDisplayLayout.list),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: VaultScreen()),
        ),
      );
      await tester.pumpAndSettle();

      final scrollable = tester.state<ScrollableState>(find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down));
      final maxScroll = scrollable.position.maxScrollExtent;
      expect(maxScroll, greaterThan(0));

      // 1. Simulate already fetching more: jump near bottom
      container.read(vaultIsFetchingMoreProvider.notifier).state = true;
      expect(container.read(vaultPaginationLimitProvider), equals(50));

      scrollable.position.jumpTo(maxScroll);
      await tester.pump();

      // Limit must NOT increment when isFetchingMore is true
      expect(container.read(vaultPaginationLimitProvider), equals(50));

      // 2. Mark fetching complete and scroll back to top
      container.read(vaultIsFetchingMoreProvider.notifier).state = false;
      scrollable.position.jumpTo(0);
      await tester.pump();

      // Now jump to bottom when !isFetchingMore
      scrollable.position.jumpTo(maxScroll);
      await tester.pump();

      // Limit should increment to 100 and isFetchingMore is reset by ref.listen once data loads
      expect(container.read(vaultPaginationLimitProvider), equals(100));
      expect(container.read(vaultIsFetchingMoreProvider), isFalse);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('_onScroll does not trigger fetches when currently loaded items < currentLimit', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Only 10 items in DB while limit is 50
      await _insertTestCards(db, 10, isOwned: true);

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
          vaultPaginationLimitProvider.overrideWith((ref) => 50),
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
          cardDisplayLayoutProvider.overrideWith((ref) => CardDisplayLayout.list),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: VaultScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(container.read(vaultPaginationLimitProvider), equals(50));

      final scrollable = tester.state<ScrollableState>(find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down));
      scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
      await tester.pump();

      // Since loaded items (10) < current limit (50), no fetch more should occur
      expect(container.read(vaultPaginationLimitProvider), equals(50));
      expect(container.read(vaultIsFetchingMoreProvider), isFalse);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('VaultScreen displays initial SliverFillRemaining spinner only when loading with no data',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final streamController = StreamController<List<VaultItem>>.broadcast();
      addTearDown(() => streamController.close());

      final dummyItem = VaultItem(
        id: 'item-1',
        collectionType: 'mtg',
        name: 'Black Lotus',
        setOrSeries: 'Alpha',
        imageUrl: '',
        acquiredPrice: 10000.0,
        acquiredDate: DateTime.now(),
        quantity: 1,
        condition: 'NM',
        isGraded: false, isAltered: false, isMisprint: false, isSigned: false,
        currentMarketPrice: 25000.0,
        lastPriceUpdate: DateTime.now(),
        dynamicData: '{}',
        primaryBinderId: null,
        personalNotes: null,
      );

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          vaultItemsStreamProvider.overrideWith((ref) => streamController.stream),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
          cardDisplayLayoutProvider.overrideWith((ref) => CardDisplayLayout.list),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: VaultScreen()),
        ),
      );

      // Initial loading state with no value yields SliverFillRemaining
      expect(find.byType(SliverFillRemaining), findsOneWidget);

      // Emit item data
      streamController.add([dummyItem]);
      await tester.pump();

      // Rendered card is displayed, SliverFillRemaining disappears
      expect(find.byType(VaultItemCard), findsOneWidget);
      expect(find.byType(SliverFillRemaining), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
