import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/providers/mtg_filter_state.dart';
import 'package:countr/features/vault/presentation/screens/vault_screen.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_tile.dart';

Future<void> _seedCards(
  AppDatabase db,
  int count, {
  bool isOwned = true,
  String color = 'U',
  String rarity = 'rare',
  String prefix = 'adv',
}) async {
  for (int i = 0; i < count; i++) {
    await db.vaultDao.into(db.vaultItems).insert(
      VaultItemsCompanion.insert(
        id: '$prefix-card-$i',
        collectionType: 'mtg',
        name: '$prefix Card ${i.toString().padLeft(4, '0')}',
        setOrSeries: 'MH3',
        imageUrl: 'https://example.com/$prefix-$i.jpg',
        acquiredPrice: 5.0 + (i % 20),
        acquiredDate: DateTime(2023, 1, 1).add(Duration(days: i)),
        quantity: drift.Value(isOwned ? 1 : 0),
        condition: 'NM',
        isGraded: const drift.Value(false),
        currentMarketPrice: 10.0 + (i % 20),
        lastPriceUpdate: DateTime.now(),
        dynamicData:
            '{"colors":["$color"],"cmc":3,"type_line":"Creature","rarity":"$rarity","finishes":["nonfoil"]}',
      ),
    );
  }
}

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

  group('Challenger M3: Adversarial Verification of Continuous Lazy Pagination (>150 Items)', () {
    testWidgets('Adversarial 1: Continuous lazy pagination step-by-step past 150 items to 350+ items in List View', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Seed 400 cards
      await _seedCards(db, 400, prefix: 'c400');

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
      addTearDown(container.dispose);

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

      // Function to advance one page
      Future<void> scrollAndAdvance() async {
        final maxScroll = scrollable.position.maxScrollExtent;
        scrollable.position.jumpTo(maxScroll - 50);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();
      }

      // Step 1: 50
      expect(container.read(vaultPaginationLimitProvider), equals(50));
      expect(container.read(vaultItemsStreamProvider).valueOrNull?.length, equals(50));

      // Step 2: 100
      await scrollAndAdvance();
      expect(container.read(vaultPaginationLimitProvider), equals(100));
      expect(container.read(vaultItemsStreamProvider).valueOrNull?.length, equals(100));

      // Step 3: 150 (Former Cap)
      await scrollAndAdvance();
      expect(container.read(vaultPaginationLimitProvider), equals(150));
      expect(container.read(vaultItemsStreamProvider).valueOrNull?.length, equals(150));

      // Step 4: 200 (Past Former Cap!)
      await scrollAndAdvance();
      expect(container.read(vaultPaginationLimitProvider), equals(200));
      expect(container.read(vaultItemsStreamProvider).valueOrNull?.length, equals(200));

      // Step 5: 250
      await scrollAndAdvance();
      expect(container.read(vaultPaginationLimitProvider), equals(250));
      expect(container.read(vaultItemsStreamProvider).valueOrNull?.length, equals(250));

      // Step 6: 300
      await scrollAndAdvance();
      expect(container.read(vaultPaginationLimitProvider), equals(300));
      expect(container.read(vaultItemsStreamProvider).valueOrNull?.length, equals(300));

      // Step 7: 350
      await scrollAndAdvance();
      expect(container.read(vaultPaginationLimitProvider), equals(350));
      expect(container.read(vaultItemsStreamProvider).valueOrNull?.length, equals(350));

      // Step 8: 400
      await scrollAndAdvance();
      expect(container.read(vaultPaginationLimitProvider), equals(400));
      expect(container.read(vaultItemsStreamProvider).valueOrNull?.length, equals(400));
    });

    testWidgets('Adversarial 2: Clean termination when collection ends at non-multiple (320 items) without stuck spinner or endless increments', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Seed 320 cards
      await _seedCards(db, 320, prefix: 'c320');

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
      addTearDown(container.dispose);

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

      Future<void> scrollAndAdvance() async {
        final maxScroll = scrollable.position.maxScrollExtent;
        scrollable.position.jumpTo(maxScroll - 50);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();
      }

      // Advance through pages up to 350 limit
      // 50 -> 100 -> 150 -> 200 -> 250 -> 300 -> 350
      for (int expectedLimit = 100; expectedLimit <= 350; expectedLimit += 50) {
        await scrollAndAdvance();
        expect(container.read(vaultPaginationLimitProvider), equals(expectedLimit));
      }

      // At limit 350, exactly 320 items are available (less than currentLimit=350)
      final items = container.read(vaultItemsStreamProvider).valueOrNull ?? [];
      expect(items.length, equals(320));

      // vaultIsFetchingMoreProvider must be false
      expect(container.read(vaultIsFetchingMoreProvider), isFalse);
      expect(find.byKey(const Key('vault_fetching_more_indicator')), findsNothing);

      // Now attempt multiple aggressive scrolls to bottom:
      for (int i = 0; i < 5; i++) {
        final maxScroll = scrollable.position.maxScrollExtent;
        scrollable.position.jumpTo(maxScroll);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();

      // Limit MUST remain at 350 and NOT increment further (clean termination)
      expect(container.read(vaultPaginationLimitProvider), equals(350));
      expect(container.read(vaultIsFetchingMoreProvider), isFalse);
      expect(find.byKey(const Key('vault_fetching_more_indicator')), findsNothing);
    });

    testWidgets('Adversarial 3: Uncapped pagination (>150 items) under active MTG filter with clean termination', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Insert 220 Blue ('U') cards and 100 Red ('R') cards = 320 total cards
      await _seedCards(db, 220, color: 'U', prefix: 'blue');
      await _seedCards(db, 100, color: 'R', prefix: 'red');

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
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: VaultScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Apply Blue 'U' filter
      container.read(mtgFilterProvider.notifier).update((s) => s.copyWith(colors: const {'U'}));
      await tester.pumpAndSettle();

      expect(container.read(vaultPaginationLimitProvider), equals(50));

      final scrollable = tester.state<ScrollableState>(
        find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down),
      );

      Future<void> scrollAndAdvance() async {
        final maxScroll = scrollable.position.maxScrollExtent;
        scrollable.position.jumpTo(maxScroll - 50);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();
      }

      // Step 2: 100
      await scrollAndAdvance();
      expect(container.read(vaultPaginationLimitProvider), equals(100));

      // Step 3: 150
      await scrollAndAdvance();
      expect(container.read(vaultPaginationLimitProvider), equals(150));

      // Step 4: 200 (Past 150 cap under active filter!)
      await scrollAndAdvance();
      expect(container.read(vaultPaginationLimitProvider), equals(200));

      // Step 5: 250
      await scrollAndAdvance();
      expect(container.read(vaultPaginationLimitProvider), equals(250));

      // Now 220 blue cards loaded (less than currentLimit=250)
      final items = container.read(vaultItemsStreamProvider).valueOrNull ?? [];
      expect(items.length, equals(220));
      expect(container.read(vaultIsFetchingMoreProvider), isFalse);

      // Clean termination: further scrolling does NOT increment beyond 250
      final maxScroll = scrollable.position.maxScrollExtent;
      scrollable.position.jumpTo(maxScroll);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(container.read(vaultPaginationLimitProvider), equals(250));
      expect(container.read(vaultIsFetchingMoreProvider), isFalse);
    });

    testWidgets('Adversarial 4: Continuous pagination past 150 items in 3x3 Grid View layout', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Seed 250 cards
      await _seedCards(db, 250, prefix: 'grid');

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
          vaultPaginationLimitProvider.overrideWith((ref) => 50),
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
          cardDisplayLayoutProvider.overrideWith((ref) => CardDisplayLayout.grid),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: VaultScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(VaultItemTile), findsWidgets);
      expect(container.read(vaultPaginationLimitProvider), equals(50));

      final scrollable = tester.state<ScrollableState>(
        find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first,
      );

      Future<void> scrollAndAdvance() async {
        final maxScroll = scrollable.position.maxScrollExtent;
        scrollable.position.jumpTo(maxScroll - 100);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();
      }

      // Advance 50 -> 100 -> 150 -> 200 -> 250 in Grid View
      await scrollAndAdvance();
      expect(container.read(vaultPaginationLimitProvider), equals(100));

      await scrollAndAdvance();
      expect(container.read(vaultPaginationLimitProvider), equals(150));

      await scrollAndAdvance();
      expect(container.read(vaultPaginationLimitProvider), equals(200));

      await scrollAndAdvance();
      expect(container.read(vaultPaginationLimitProvider), equals(250));

      final items = container.read(vaultItemsStreamProvider).valueOrNull ?? [];
      expect(items.length, equals(250));
      expect(container.read(vaultIsFetchingMoreProvider), isFalse);
    });
  });
}
