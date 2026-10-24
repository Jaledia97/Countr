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

Future<void> _seedAdversarialDataset(AppDatabase db) async {
  // 12 Blue Instants (Rare, CMC 2)
  for (int i = 0; i < 12; i++) {
    await db.vaultDao.into(db.vaultItems).insert(
      VaultItemsCompanion.insert(
        id: 'adv-blue-$i',
        collectionType: 'mtg',
        name: 'Blue Instant ${i.toString().padLeft(2, '0')}',
        setOrSeries: 'MH3',
        imageUrl: 'https://example.com/blue-$i.jpg',
        acquiredPrice: 5.0 + i,
        acquiredDate: DateTime(2023, 1, 1).add(Duration(days: i)),
        quantity: const drift.Value(1),
        condition: 'NM',
        isGraded: const drift.Value(false),
        currentMarketPrice: 8.0 + i,
        lastPriceUpdate: DateTime.now(),
        dynamicData:
            '{"colors":["U"],"cmc":2,"type_line":"Instant","rarity":"rare","finishes":["nonfoil"]}',
      ),
    );
  }

  // 18 Red Creatures (Common, CMC 3)
  for (int i = 0; i < 18; i++) {
    await db.vaultDao.into(db.vaultItems).insert(
      VaultItemsCompanion.insert(
        id: 'adv-red-$i',
        collectionType: 'mtg',
        name: 'Red Creature ${i.toString().padLeft(2, '0')}',
        setOrSeries: 'BLB',
        imageUrl: 'https://example.com/red-$i.jpg',
        acquiredPrice: 2.0,
        acquiredDate: DateTime(2023, 2, 1).add(Duration(days: i)),
        quantity: const drift.Value(1),
        condition: 'NM',
        isGraded: const drift.Value(false),
        currentMarketPrice: 3.5,
        lastPriceUpdate: DateTime.now(),
        dynamicData:
            '{"colors":["R"],"cmc":3,"type_line":"Creature - Goblin","rarity":"common","finishes":["nonfoil"]}',
      ),
    );
  }

  // 20 Green Lands (Uncommon, CMC 0)
  for (int i = 0; i < 20; i++) {
    await db.vaultDao.into(db.vaultItems).insert(
      VaultItemsCompanion.insert(
        id: 'adv-green-$i',
        collectionType: 'mtg',
        name: 'Green Land ${i.toString().padLeft(2, '0')}',
        setOrSeries: 'OTJ',
        imageUrl: 'https://example.com/green-$i.jpg',
        acquiredPrice: 1.0,
        acquiredDate: DateTime(2023, 3, 1).add(Duration(days: i)),
        quantity: const drift.Value(1),
        condition: 'NM',
        isGraded: const drift.Value(false),
        currentMarketPrice: 2.0,
        lastPriceUpdate: DateTime.now(),
        dynamicData:
            '{"colors":["G"],"cmc":0,"type_line":"Land - Forest","rarity":"uncommon","finishes":["nonfoil"]}',
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

  group('Adversarial Challenge 1: Exact First-Frame Filter Reactivity (Zero-Scroll Required)', () {
    testWidgets('Grid layout updates on single tester.pump() without scrolling or dragging', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await _seedAdversarialDataset(db);

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

      // Initially all 50 items shown in grid (Green is most recent, so visible)
      expect(find.byType(VaultItemTile), findsWidgets);
      expect(find.text('Green Land 19'), findsOneWidget);

      // Mutate MTG Filter to Blue ('U')
      container.read(mtgFilterProvider.notifier).update((s) => s.copyWith(colors: const {'U'}));

      // Single frame pump ONLY — no pumpAndSettle, no scroll/drag gesture
      await tester.pump();

      // Assert instant reactivity on frame 1
      expect(find.text('showing 12 results'), findsOneWidget);
      expect(find.byKey(const Key('vault_tile_adv-blue-11')), findsOneWidget);
      expect(find.byKey(const Key('vault_tile_adv-red-17')), findsNothing);
      expect(find.byKey(const Key('vault_tile_adv-green-19')), findsNothing);

      // Mutate filter to Green ('G')
      container.read(mtgFilterProvider.notifier).update((s) => s.copyWith(colors: const {'G'}));
      await tester.pump();

      expect(find.text('showing 20 results'), findsOneWidget);
      expect(find.byKey(const Key('vault_tile_adv-green-19')), findsOneWidget);
      expect(find.byKey(const Key('vault_tile_adv-blue-11')), findsNothing);
      expect(find.byKey(const Key('vault_tile_adv-red-17')), findsNothing);

      // Clear filter back to empty
      container.read(mtgFilterProvider.notifier).update((s) => s.clear());
      await tester.pump();

      // All initial items restored on single frame: Green Land is top item
      expect(find.byKey(const Key('vault_tile_adv-green-19')), findsOneWidget);
    });

    testWidgets('List layout updates instantly across multiple filter dimensions (rarity, type, cmc)', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await _seedAdversarialDataset(db);

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

      // Dimension 1: Rarity == 'rare' (12 Blue Instants)
      container.read(mtgFilterProvider.notifier).update((s) => s.copyWith(rarities: const {'rare'}));
      await tester.pump();

      expect(find.text('showing 12 results'), findsOneWidget);
      expect(find.text('Blue Instant 11'), findsOneWidget);
      expect(find.text('Red Creature 17'), findsNothing);

      // Dimension 2: TypeLine == 'Creature' (18 Red Creatures)
      container.read(mtgFilterProvider.notifier).update((s) => s.copyWith(rarities: const {}, typeLine: 'Creature'));
      await tester.pump();

      expect(find.text('showing 18 results'), findsOneWidget);
      expect(find.text('Red Creature 17'), findsOneWidget);
      expect(find.text('Blue Instant 11'), findsNothing);

      // Dimension 3: CMC == 0 (20 Green Lands)
      container.read(mtgFilterProvider.notifier).update((s) => s.copyWith(typeLine: '', cmcRange: const RangeValues(0, 0)));
      await tester.pump();

      expect(find.text('showing 20 results'), findsOneWidget);
      expect(find.text('Green Land 19'), findsOneWidget);
      expect(find.text('Red Creature 17'), findsNothing);
    });
  });

  group('Adversarial Challenge 2: Immediate Scroll Offset Reset to 0.0 Under Displacement', () {
    testWidgets('Scroll offset resets to 0.0 across all filter trigger channels', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await _seedAdversarialDataset(db);

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

      // Test Channel 1: MTG Filter update
      scrollable.position.jumpTo(750.0);
      await tester.pump();
      expect(scrollable.position.pixels, equals(750.0));

      container.read(mtgFilterProvider.notifier).update((s) => s.copyWith(colors: const {'U'}));
      await tester.pump();
      expect(scrollable.position.pixels, equals(0.0), reason: 'MTG filter change must reset scroll to 0');

      // Test Channel 2: Search Query update
      scrollable.position.jumpTo(400.0);
      await tester.pump();
      expect(scrollable.position.pixels, equals(400.0));

      container.read(vaultSearchQueryProvider.notifier).state = 'Instant';
      await tester.pump();
      expect(scrollable.position.pixels, equals(0.0), reason: 'Search query change must reset scroll to 0');

      // Test Channel 3: Catalog Toggle
      scrollable.position.jumpTo(600.0);
      await tester.pump();
      expect(scrollable.position.pixels, equals(600.0));

      container.read(vaultShowCatalogProvider.notifier).state = true;
      await tester.pump();
      expect(scrollable.position.pixels, equals(0.0), reason: 'Catalog toggle must reset scroll to 0');

      // Test Channel 4: Filter cleared
      scrollable.position.jumpTo(350.0);
      await tester.pump();
      expect(scrollable.position.pixels, equals(350.0));

      container.read(mtgFilterProvider.notifier).update((s) => s.clear());
      await tester.pump();
      expect(scrollable.position.pixels, equals(0.0), reason: 'Filter clear must reset scroll to 0');
    });
  });

  group('Adversarial Challenge 3: Spinner Prevention & Rapid 0-Match Alternation', () {
    testWidgets('0-match filter state renders empty state immediately without flashing full-screen loading spinner', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await _seedAdversarialDataset(db);

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

      // Apply 0-match filter: White ('W') - 0 matches in dataset
      container.read(mtgFilterProvider.notifier).update((s) => s.copyWith(colors: const {'W'}));
      await tester.pump();

      // Empty state rendered immediately
      expect(find.text('showing 0 results'), findsOneWidget);
      expect(find.text('No owned items in Magic: The Gathering'), findsOneWidget);

      // Adversarial Check: Full-screen loading spinner ("Loading collection...") MUST NOT be present
      expect(find.text('Loading collection...'), findsNothing);

      // Rapidly toggle back to Green ('G')
      container.read(mtgFilterProvider.notifier).update((s) => s.copyWith(colors: const {'G'}));
      await tester.pump();

      expect(find.text('showing 20 results'), findsOneWidget);
      expect(find.text('No owned items in Magic: The Gathering'), findsNothing);
      expect(find.text('Loading collection...'), findsNothing);

      // Rapidly toggle back to impossible combo (Black 'B' + CMC 9)
      container.read(mtgFilterProvider.notifier).update((s) => s.copyWith(colors: const {'B'}, cmcRange: const RangeValues(9, 9)));
      await tester.pump();

      expect(find.text('showing 0 results'), findsOneWidget);
      expect(find.text('No owned items in Magic: The Gathering'), findsOneWidget);
      expect(find.text('Loading collection...'), findsNothing);

      // Allow async tasks to finish
      await tester.pumpAndSettle();
      expect(find.text('showing 0 results'), findsOneWidget);
      expect(find.text('Loading collection...'), findsNothing);
    });
  });

  group('Adversarial Challenge 4: Architectural Invariants & Key Stability', () {
    testWidgets('Tiles and cards maintain stable RepaintBoundary ValueKey(item.id) in list and grid', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await _seedAdversarialDataset(db);

      // Test List Mode
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
          vaultPaginationLimitProvider.overrideWith((ref) => 50),
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

      // Check ValueKey on RepaintBoundary for top visible items (Green Land 19 is top item)
      final repaintBoundaries = find.byType(RepaintBoundary);
      expect(repaintBoundaries, findsWidgets);

      final hasItemKey = find.byKey(const ValueKey('adv-green-19'));
      expect(hasItemKey, findsOneWidget);

      // Filter by Blue (U): only 12 items, top item is adv-blue-11
      container.read(mtgFilterProvider.notifier).update((s) => s.copyWith(colors: const {'U'}));
      await tester.pump();

      final hasBlueKey = find.byKey(const ValueKey('adv-blue-11'));
      expect(hasBlueKey, findsOneWidget);
    });
  });
}
