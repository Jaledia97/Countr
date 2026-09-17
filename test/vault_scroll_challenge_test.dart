import 'dart:async';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/screens/vault_screen.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_card.dart';

List<VaultItem> _generateDummyCards(int count) {
  return List.generate(
    count,
    (i) => VaultItem(
      id: 'challenge-card-$i',
      collectionType: 'mtg',
      name: 'Card ${i.toString().padLeft(3, '0')}',
      setOrSeries: 'Test Set',
      imageUrl: '',
      acquiredPrice: 10.0 + i,
      acquiredDate: DateTime(2023, 1, 1).add(Duration(days: i)),
      quantity: 1,
      condition: 'NM',
      isGraded: false,
      currentMarketPrice: 15.0 + i,
      lastPriceUpdate: DateTime.now(),
      dynamicData: '{"oracle_text":"Test text $i","rarity":"rare"}',
      primaryBinderId: null,
      personalNotes: null,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Adversarial Challenge 1: Race conditions in _onScroll vs ref.listen', () {
    testWidgets('In-flight fetch guard: rapid scroll events while fetch is in-flight do NOT increment limit',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final streamController = StreamController<List<VaultItem>>.broadcast();
      addTearDown(() => streamController.close());

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          vaultItemsStreamProvider.overrideWith((ref) => streamController.stream),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
          vaultPaginationLimitProvider.overrideWith((ref) => 50),
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
          cardDisplayLayoutProvider.overrideWith((ref) => CardDisplayLayout.list),
        ],
      );
      addTearDown(() => container.dispose());

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: VaultScreen()),
        ),
      );

      // Emit initial 50 cards
      streamController.add(_generateDummyCards(50));
      await tester.pump();

      expect(find.byType(VaultItemCard), findsWidgets);
      expect(container.read(vaultPaginationLimitProvider), equals(50));
      expect(container.read(vaultIsFetchingMoreProvider), isFalse);

      final scrollable = tester.state<ScrollableState>(
        find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down),
      );
      final maxScroll = scrollable.position.maxScrollExtent;
      expect(maxScroll, greaterThan(500));

      // 1. Scroll near bottom to trigger pagination fetch
      scrollable.position.jumpTo(maxScroll - 100);
      await tester.pump();

      // Limit has incremented to 100 and isFetchingMore is true
      expect(container.read(vaultPaginationLimitProvider), equals(100));
      expect(container.read(vaultIsFetchingMoreProvider), isTrue);

      // 2. Adversarial attack: Fire 20 rapid scroll movements while stream has NOT emitted yet
      for (int i = 0; i < 20; i++) {
        scrollable.position.jumpTo(maxScroll - 50 + (i % 5));
        await tester.pump();
      }

      // Limit MUST remain 100 because isFetchingMore is true
      expect(container.read(vaultPaginationLimitProvider), equals(100));
      expect(container.read(vaultIsFetchingMoreProvider), isTrue);

      // 3. Now emit the new 100 cards from the stream
      streamController.add(_generateDummyCards(100));
      await tester.pump();

      // ref.listen MUST reset isFetchingMore to false
      expect(container.read(vaultIsFetchingMoreProvider), isFalse);

      // 4. Trigger second page fetch: scroll to new bottom
      final newMaxScroll = scrollable.position.maxScrollExtent;
      expect(newMaxScroll, greaterThan(maxScroll));

      scrollable.position.jumpTo(newMaxScroll - 100);
      await tester.pump();

      // Limit increments to 150
      expect(container.read(vaultPaginationLimitProvider), equals(150));
      expect(container.read(vaultIsFetchingMoreProvider), isTrue);

      // 5. Simulate end of database: stream emits 100 cards again (less than limit 150)
      streamController.add(_generateDummyCards(100));
      await tester.pump();

      expect(container.read(vaultIsFetchingMoreProvider), isFalse);

      // 6. Scroll to bottom again: verify NO further fetch happens because loaded (100) < limit (150)
      scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
      await tester.pump();

      expect(container.read(vaultPaginationLimitProvider), equals(150));
      expect(container.read(vaultIsFetchingMoreProvider), isFalse);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('Stream error recovery: isFetchingMore resets to false on error and prevents lockup',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final streamController = StreamController<List<VaultItem>>.broadcast();
      addTearDown(() => streamController.close());

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          vaultItemsStreamProvider.overrideWith((ref) => streamController.stream),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
          vaultPaginationLimitProvider.overrideWith((ref) => 50),
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
          cardDisplayLayoutProvider.overrideWith((ref) => CardDisplayLayout.list),
        ],
      );
      addTearDown(() => container.dispose());

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: VaultScreen()),
        ),
      );

      // Emit initial cards
      streamController.add(_generateDummyCards(5));
      await tester.pump();

      expect(find.byType(VaultItemCard), findsWidgets);
      expect(container.read(vaultIsFetchingMoreProvider), isFalse);

      // Simulate starting fetch more
      container.read(vaultIsFetchingMoreProvider.notifier).state = true;
      await tester.pump();
      expect(find.byKey(const Key('vault_fetching_more_indicator')), findsOneWidget);

      // Stream emits an error during pagination
      streamController.addError(Exception('Database disk I/O error'));
      await tester.pump();

      // ref.listen MUST reset isFetchingMore to false on error
      expect(container.read(vaultIsFetchingMoreProvider), isFalse);
      expect(find.byKey(const Key('vault_fetching_more_indicator')), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });

  group('Adversarial Challenge 2: PageStorageKey scroll offset retention and rebuild stress', () {
    testWidgets('Scroll offset remains exactly preserved when new items are appended', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final streamController = StreamController<List<VaultItem>>.broadcast();
      addTearDown(() => streamController.close());

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          vaultItemsStreamProvider.overrideWith((ref) => streamController.stream),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
          vaultPaginationLimitProvider.overrideWith((ref) => 50),
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
          cardDisplayLayoutProvider.overrideWith((ref) => CardDisplayLayout.list),
        ],
      );
      addTearDown(() => container.dispose());

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: VaultScreen()),
        ),
      );

      streamController.add(_generateDummyCards(50));
      await tester.pump();

      final scrollable = tester.state<ScrollableState>(
        find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down),
      );

      // Scroll to 450.0 pixels
      scrollable.position.jumpTo(450.0);
      await tester.pump();
      expect(scrollable.position.pixels, equals(450.0));

      // Append 50 more cards via stream
      streamController.add(_generateDummyCards(100));
      await tester.pump();

      // Offset must remain exactly at 450.0 without reset or jitter
      expect(scrollable.position.pixels, equals(450.0));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('Scroll offset is restored across unmount and remount with PageStorageBucket', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final streamController = StreamController<List<VaultItem>>.broadcast();
      addTearDown(() => streamController.close());

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
      addTearDown(() => container.dispose());

      final bucket = PageStorageBucket();

      Widget buildRoot(Widget child) {
        return UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: PageStorage(
              bucket: bucket,
              child: child,
            ),
          ),
        );
      }

      // Mount VaultScreen
      await tester.pumpWidget(buildRoot(const VaultScreen()));
      streamController.add(_generateDummyCards(50));
      await tester.pump();

      // Scroll down to 380.0
      final scrollable1 = tester.state<ScrollableState>(
        find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down),
      );
      scrollable1.position.jumpTo(380.0);
      await tester.pump();
      expect(scrollable1.position.pixels, equals(380.0));

      // Unmount VaultScreen by navigating to another screen
      await tester.pumpWidget(buildRoot(const Scaffold(body: Center(child: Text('Settings Tab')))));
      await tester.pump();
      expect(find.text('Settings Tab'), findsOneWidget);
      expect(find.byType(VaultScreen), findsNothing);

      // Remount VaultScreen with same bucket
      await tester.pumpWidget(buildRoot(const VaultScreen()));
      streamController.add(_generateDummyCards(50));
      await tester.pump();

      // Scroll offset restored by PageStorageKey('vault_custom_scroll_view')
      final scrollable2 = tester.state<ScrollableState>(
        find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down),
      );
      expect(scrollable2.position.pixels, equals(380.0));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('Toggling CardDisplayLayout between List and Grid preserves scroll offset stability',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final streamController = StreamController<List<VaultItem>>.broadcast();
      addTearDown(() => streamController.close());

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
      addTearDown(() => container.dispose());

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: VaultScreen()),
        ),
      );

      streamController.add(_generateDummyCards(50));
      await tester.pump();

      final scrollable = tester.state<ScrollableState>(
        find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down),
      );

      // Scroll down in List view
      scrollable.position.jumpTo(250.0);
      await tester.pump();
      expect(scrollable.position.pixels, equals(250.0));
      expect(find.byType(SliverList), findsOneWidget);
      expect(find.byType(SliverGrid), findsNothing);

      // Toggle layout to Grid via Riverpod provider
      container.read(cardDisplayLayoutProvider.notifier).state = CardDisplayLayout.grid;
      await tester.pump();

      expect(find.byType(SliverGrid), findsOneWidget);
      expect(find.byType(SliverList), findsNothing);
      // Scroll position must remain non-negative and valid
      expect(scrollable.position.pixels, equals(250.0));

      // Toggle back to List layout
      container.read(cardDisplayLayoutProvider.notifier).state = CardDisplayLayout.list;
      await tester.pump();

      expect(find.byType(SliverList), findsOneWidget);
      expect(find.byType(SliverGrid), findsNothing);
      expect(scrollable.position.pixels, equals(250.0));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
