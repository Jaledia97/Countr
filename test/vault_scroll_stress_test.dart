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
import 'package:countr/features/vault/presentation/widgets/vault_item_tile.dart';

Future<void> _insertTestCards(AppDatabase db, int count, {bool isOwned = true}) async {
  for (int i = 0; i < count; i++) {
    await db.vaultDao.into(db.vaultItems).insert(
      VaultItemsCompanion.insert(
        id: 'stress-card-$i',
        collectionType: 'mtg',
        name: 'Stress Card ${i.toString().padLeft(3, '0')}',
        setOrSeries: 'Stress Set',
        imageUrl: 'https://example.com/card-$i.jpg',
        acquiredPrice: 10.0 + i,
        acquiredDate: DateTime(2023, 1, 1).add(Duration(days: i)),
        quantity: drift.Value(isOwned ? 1 : 0),
        condition: 'NM',
        isGraded: const drift.Value(false),
        currentMarketPrice: 15.0 + i,
        lastPriceUpdate: DateTime.now(),
        dynamicData: '{"oracle_text":"Stress test card $i","rarity":"rare"}',
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Milestone 1 Empirical Stress Tests: Vault Scroll & Pagination', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await db.vaultDao.clearAllItems();
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('Stress Test 1: Rapid flinging near threshold does not cause multiple increments or jitter',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Insert 60 items (initial limit is 50)
      await _insertTestCards(db, 60, isOwned: true);

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

      final scrollable = tester.state<ScrollableState>(
        find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down),
      );
      final maxScroll = scrollable.position.maxScrollExtent;
      expect(maxScroll, greaterThan(300));

      // Jump near threshold (maxScroll - 250)
      scrollable.position.jumpTo(maxScroll - 250);
      await tester.pump();

      // Trigger rapid micro-scrolls around the threshold
      for (int i = 0; i < 10; i++) {
        scrollable.position.jumpTo(maxScroll - 250 + (i % 2 == 0 ? 5 : -5));
        await tester.pump(const Duration(milliseconds: 16));
      }

      // Pagination limit should have incremented exactly once (from 50 to 100), not 10 times
      expect(container.read(vaultPaginationLimitProvider), equals(100));

      // Settle all streams
      await tester.pumpAndSettle();

      // Scroll position must still be near bottom and not reset to 0
      expect(scrollable.position.pixels, greaterThan(maxScroll - 300));
      expect(find.byType(VaultItemCard), findsWidgets);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('Stress Test 2: Empty vault items - scrolling does not crash or trigger pagination',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // 0 items in database
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

      // Empty state text should be visible
      expect(find.text('No owned items in Magic: The Gathering'), findsOneWidget);
      expect(find.byType(VaultItemCard), findsNothing);
      expect(find.byKey(const Key('vault_fetching_more_indicator')), findsNothing);

      // Try scrolling down
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();

      // Ensure no fetch triggered and limit remains 50
      expect(container.read(vaultPaginationLimitProvider), equals(50));
      expect(container.read(vaultIsFetchingMoreProvider), isFalse);

      // Tap 'Catalog (Ref)' FilterChip
      final catalogChip = find.text('Catalog (Ref)');
      expect(catalogChip, findsOneWidget);
      await tester.tap(catalogChip);
      await tester.pumpAndSettle();

      // Verified: 'No catalog cards found' empty state is shown
      expect(find.text('No catalog cards found'), findsOneWidget);
      expect(container.read(vaultShowCatalogProvider), isTrue);

      // Try scrolling in empty catalog mode
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();

      // Ensure limit remains 50 and isFetchingMore is false
      expect(container.read(vaultPaginationLimitProvider), equals(50));
      expect(container.read(vaultIsFetchingMoreProvider), isFalse);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('Stress Test 3: List vs Grid mode toggling preserves scroll position and handles pagination in Grid view',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Insert 60 items
      await _insertTestCards(db, 60, isOwned: true);

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

      final scrollable = tester.state<ScrollableState>(
        find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down),
      );

      // Tap 'Tiles' button while header is in view
      expect(find.byKey(const Key('vault_layout_grid_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('vault_layout_grid_button')));
      await tester.pumpAndSettle();

      // Verify grid items are rendered
      expect(find.byType(VaultItemTile), findsWidgets);
      expect(find.byType(VaultItemCard), findsNothing);

      // Scroll down 400 pixels in Grid mode
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();

      final gridScrollPixels = scrollable.position.pixels;
      expect(gridScrollPixels, greaterThanOrEqualTo(300));

      // Toggle back to List view via provider while scrolled down
      container.read(cardDisplayLayoutProvider.notifier).state = CardDisplayLayout.list;
      await tester.pumpAndSettle();

      // Verified: list items rendered and offset is preserved (not reset to 0)
      expect(find.byType(VaultItemCard), findsWidgets);
      expect(find.byType(VaultItemTile), findsNothing);
      expect(scrollable.position.pixels, greaterThan(0));

      // Now scroll near bottom in List mode to trigger pagination
      final listMaxScroll = scrollable.position.maxScrollExtent;
      scrollable.position.jumpTo(listMaxScroll - 200);
      await tester.pump();

      // Should trigger fetch more
      expect(container.read(vaultPaginationLimitProvider), equals(100));
      await tester.pumpAndSettle();

      // All 60 items now loaded and rendered
      expect(find.byType(VaultItemCard), findsWidgets);
      expect(scrollable.position.pixels, greaterThan(0));

      // Toggle to Grid mode while near bottom
      container.read(cardDisplayLayoutProvider.notifier).state = CardDisplayLayout.grid;
      await tester.pumpAndSettle();

      // Verified: Grid tiles render smoothly near bottom without scroll reset or crash
      expect(find.byType(VaultItemTile), findsWidgets);
      expect(scrollable.position.pixels, greaterThan(0));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('Stress Test 4: Scroll position does NOT jump or reset to 0 during async page loading',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await _insertTestCards(db, 60, isOwned: true);

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

      final scrollable = tester.state<ScrollableState>(
        find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down),
      );

      // Scroll to near bottom
      final initialMax = scrollable.position.maxScrollExtent;
      scrollable.position.jumpTo(initialMax - 250);
      await tester.pump();

      final positionBeforeFetch = scrollable.position.pixels;
      expect(positionBeforeFetch, equals(initialMax - 250));

      // Trigger fetch
      expect(container.read(vaultPaginationLimitProvider), equals(100));

      // Pump 1 frame (during async loading)
      await tester.pump();

      // Scroll position must NOT jump to 0 during loading
      expect(scrollable.position.pixels, equals(positionBeforeFetch));
      expect(find.byType(SliverFillRemaining), findsNothing);

      // Complete fetch
      await tester.pumpAndSettle();

      // Scroll position after items arrive must still be around the previous position
      expect(scrollable.position.pixels, greaterThanOrEqualTo(positionBeforeFetch - 50));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('Stress Test 5: Boundary item count (exactly limit vs limit - 1)',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Insert exactly 49 items (limit is 50)
      await _insertTestCards(db, 49, isOwned: true);

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

      final scrollable = tester.state<ScrollableState>(
        find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down),
      );
      scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
      await tester.pump();

      // With 49 items (< 50), limit must NOT increment
      expect(container.read(vaultPaginationLimitProvider), equals(50));
      expect(container.read(vaultIsFetchingMoreProvider), isFalse);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('Stress Test 6: Rapid toggling between List and Grid during active pagination fetch',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await _insertTestCards(db, 60, isOwned: true);

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

      final scrollable = tester.state<ScrollableState>(
        find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down),
      );

      // Scroll near bottom to trigger pagination fetch
      final maxScroll = scrollable.position.maxScrollExtent;
      scrollable.position.jumpTo(maxScroll - 200);
      await tester.pump();

      // Fetch more in flight
      expect(container.read(vaultPaginationLimitProvider), equals(100));

      // In the middle of the fetch, rapidly flip layout between list and grid
      container.read(cardDisplayLayoutProvider.notifier).state = CardDisplayLayout.grid;
      await tester.pump();

      container.read(cardDisplayLayoutProvider.notifier).state = CardDisplayLayout.list;
      await tester.pump();

      container.read(cardDisplayLayoutProvider.notifier).state = CardDisplayLayout.grid;
      await tester.pump();

      // Settle
      await tester.pumpAndSettle();

      // No crash occurred, grid tiles rendered, scroll position preserved
      expect(find.byType(VaultItemTile), findsWidgets);
      expect(scrollable.position.pixels, greaterThan(0));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
