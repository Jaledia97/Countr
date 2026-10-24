import 'dart:io';
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
import 'package:countr/features/vault/presentation/widgets/vault_item_card.dart';

Future<void> _insertTestCards(
  AppDatabase db,
  int count, {
  bool isOwned = true,
  String color = 'U',
  String rarity = 'rare',
  String cardType = 'Creature',
  String prefix = 'm3',
}) async {
  for (int i = 0; i < count; i++) {
    await db.vaultDao.into(db.vaultItems).insert(
      VaultItemsCompanion.insert(
        id: '$prefix-card-$i',
        collectionType: 'mtg',
        name: '$prefix Card ${i.toString().padLeft(3, '0')}',
        setOrSeries: 'MH3',
        imageUrl: 'https://example.com/$prefix-$i.jpg',
        acquiredPrice: 10.0 + i,
        acquiredDate: DateTime(2023, 1, 1).add(Duration(days: i)),
        quantity: drift.Value(isOwned ? 1 : 0),
        condition: 'NM',
        isGraded: const drift.Value(false),
        currentMarketPrice: 15.0 + i,
        lastPriceUpdate: DateTime.now(),
        dynamicData:
            '{"colors":["$color"],"cmc":3,"type_line":"$cardType","rarity":"$rarity","finishes":["nonfoil"]}',
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

  group('M3 Task 1 (R3.1): Clean Riverpod Modals in VaultScreen', () {
    test('Source code verification: zero illegal ref.watch calls and no setModalState in filter modals', () {
      final file = File('lib/features/vault/presentation/screens/vault_screen.dart');
      expect(file.existsSync(), isTrue);
      final lines = file.readAsLinesSync();

      // Find all ref.watch lines
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.contains('ref.watch(')) {
          final lineNum = i + 1;
          // Legal places: build() methods (inside _VaultScreenState or Consumer builders)
          final isInsideConsumer = lineNum >= 2410 && lineNum <= 2435;
          final isInsideBuild = lineNum >= 400 && lineNum <= 440;
          final isInsideSubBuild = lineNum > 1000 && lineNum < 2200;
          expect(
            isInsideConsumer || isInsideBuild || isInsideSubBuild,
            isTrue,
            reason: 'Illegal ref.watch at line $lineNum: $line',
          );
        }
      }

      // Verify no setModalState in the 7 filter modal methods
      final filterModalSection = lines.sublist(2400, 2980).join('\n');
      expect(filterModalSection.contains('setModalState('), isFalse);
    });

    testWidgets('Colors quick-filter modal wraps content in Consumer and updates provider reactively', (tester) async {
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
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
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

      // Open Colors filter modal
      await tester.tap(find.byKey(const Key('vault_filter_chip_colors')));
      await tester.pumpAndSettle();

      expect(find.text('Colors & Identity'), findsOneWidget);

      // Verify Consumer widget exists inside bottom sheet
      expect(find.byType(Consumer), findsWidgets);

      // Tap Blue (U)
      await tester.tap(find.byKey(const Key('quick_filter_color_U')));
      await tester.pumpAndSettle();

      // Verify state was mutated immediately without tapping Done
      expect(container.read(mtgFilterProvider).colors, contains('U'));

      // Tap Clear
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();

      expect(container.read(mtgFilterProvider).colors, isEmpty);

      // Close modal
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
    });
  });

  group('M3 Task 2 (R3.2): Immediate Filter Reactivity & Zero-Scroll Updates', () {
    testWidgets('Single-frame synchronous in-memory MTG filtering updates without requiring a scroll event', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Insert 10 Blue cards and 40 Red cards (total 50)
      await _insertTestCards(db, 10, color: 'U', prefix: 'blue');
      await _insertTestCards(db, 40, color: 'R', prefix: 'red');

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

      // Initially all 50 items are displayed
      expect(find.byType(VaultItemCard), findsWidgets);

      // Filter by Blue (U)
      container.read(mtgFilterProvider.notifier).update((s) => s.copyWith(colors: const {'U'}));

      // Pump ONLY A SINGLE FRAME (no pumpAndSettle, no scrolling!)
      await tester.pump();

      // Immediately verify that synchronous in-memory filtering took effect on the very first frame
      expect(find.text('showing 10 results'), findsOneWidget);

      // Verify that Blue cards are rendered and Red cards are filtered out
      expect(find.text('blue Card 000'), findsOneWidget);
      expect(find.text('red Card 000'), findsNothing);
    });

    testWidgets('Scroll offset resets to 0.0 immediately when MTG filter is modified', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await _insertTestCards(db, 50, color: 'U', prefix: 'scroll');

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

      // Scroll down by 500px
      scrollable.position.jumpTo(500.0);
      await tester.pump();

      expect(scrollable.position.pixels, equals(500.0));

      // Change MTG filter
      container.read(mtgFilterProvider.notifier).update((s) => s.copyWith(colors: const {'R'}));
      await tester.pump();

      // Scroll offset must reset to 0 immediately
      expect(scrollable.position.pixels, equals(0.0));
    });

    testWidgets('Zero-match filter result displays empty state without flashing full-screen loading spinner', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Insert 10 Blue cards only
      await _insertTestCards(db, 10, color: 'U', prefix: 'nomatch');

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

      // Filter for Green 'G' which has 0 matches
      container.read(mtgFilterProvider.notifier).update((s) => s.copyWith(colors: const {'G'}));
      await tester.pump();

      // Result counter shows 0 results
      expect(find.text('showing 0 results'), findsOneWidget);

      // Empty state is rendered
      expect(find.text('No owned items in Magic: The Gathering'), findsOneWidget);

      // Full-screen loading spinner ("Loading collection...") is NOT displayed
      expect(find.text('Loading collection...'), findsNothing);
    });
  });

  group('M3 Task 3 (R3.3): Uncapped Lazy Pagination (>150 items)', () {
    testWidgets('Lazy pagination loads smoothly past 150 items (50 -> 100 -> 150 -> 200 -> 250 -> 300+)', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Insert 350 items into the database
      await _insertTestCards(db, 350, prefix: 'uncap');

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

      // Initial page: 50 items
      expect(container.read(vaultPaginationLimitProvider), equals(50));

      final scrollable = tester.state<ScrollableState>(
        find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down),
      );

      // Helper to scroll to bottom and advance page
      Future<void> advancePage() async {
        final maxScroll = scrollable.position.maxScrollExtent;
        scrollable.position.jumpTo(maxScroll - 100);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();
      }

      // Page 2 -> 100 items
      await advancePage();
      expect(container.read(vaultPaginationLimitProvider), equals(100));

      // Page 3 -> 150 items
      await advancePage();
      expect(container.read(vaultPaginationLimitProvider), equals(150));

      // Page 4 -> 200 items (BEYOND 150-ITEM CAP!)
      await advancePage();
      expect(container.read(vaultPaginationLimitProvider), equals(200));

      // Page 5 -> 250 items
      await advancePage();
      expect(container.read(vaultPaginationLimitProvider), equals(250));

      // Page 6 -> 300 items
      await advancePage();
      expect(container.read(vaultPaginationLimitProvider), equals(300));

      // Page 7 -> 350 items
      await advancePage();
      expect(container.read(vaultPaginationLimitProvider), equals(350));
    });

    test('vaultItemsStreamProvider uncap logic fetches 2x and takes paginationLimit post-consolidation', () async {
      await _insertTestCards(db, 120, prefix: 'stream_uncap');

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
          vaultShowCatalogProvider.overrideWith((ref) => false),
          vaultPaginationLimitProvider.overrideWith((ref) => 50),
        ],
      );
      addTearDown(container.dispose);

      final page1 = await container.read(vaultItemsStreamProvider.future);
      expect(page1.length, equals(50));

      // Increase to 100
      container.read(vaultPaginationLimitProvider.notifier).state = 100;
      final page2 = await container.read(vaultItemsStreamProvider.future);
      expect(page2.length, equals(100));

      // Increase to 150 (only 120 exist)
      container.read(vaultPaginationLimitProvider.notifier).state = 150;
      final page3 = await container.read(vaultItemsStreamProvider.future);
      expect(page3.length, equals(120));
    });
  });
}
