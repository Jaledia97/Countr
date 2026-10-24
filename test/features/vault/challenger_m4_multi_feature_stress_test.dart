import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/hydration/data/services/scryfall_service.dart';
import 'package:countr/features/hydration/presentation/providers/hydration_providers.dart';
import 'package:countr/features/vault/presentation/providers/mtg_filter_state.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/screens/vault_screen.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_card.dart';

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

  VaultItemsCompanion createCompanion({
    required String id,
    required String name,
    required String collectionType,
    int quantity = 1,
    double marketPrice = 15.0,
    double acquiredPrice = 10.0,
    String? primaryBinderId,
    String color = 'U',
    String rarity = 'rare',
    int cmc = 3,
    String typeLine = 'Creature',
  }) {
    return VaultItemsCompanion.insert(
      id: id,
      collectionType: collectionType,
      name: name,
      setOrSeries: 'MH3',
      imageUrl: 'https://example.com/$id.jpg',
      acquiredPrice: acquiredPrice,
      acquiredDate: DateTime(2025, 1, 1),
      quantity: drift.Value(quantity),
      condition: 'NM',
      isGraded: const drift.Value(false),
      currentMarketPrice: marketPrice,
      lastPriceUpdate: DateTime.now(),
      dynamicData: jsonEncode({
        'colors': [color],
        'cmc': cmc,
        'type_line': typeLine,
        'rarity': rarity,
        'finishes': ['nonfoil'],
      }),
      primaryBinderId: drift.Value(primaryBinderId),
    );
  }

  Widget createHarness({
    required Widget child,
    List<Override> overrides = const [],
    ProviderContainer? container,
  }) {
    final mockScryfall = ScryfallService(
      client: MockClient((request) async {
        return http.Response(jsonEncode({'object': 'list', 'data': []}), 200);
      }),
    );

    final defaultOverrides = [
      appDatabaseProvider.overrideWithValue(db),
      vaultDaoProvider.overrideWithValue(db.vaultDao),
      scryfallServiceProvider.overrideWithValue(mockScryfall),
      activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
      vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
      cardDisplayLayoutProvider.overrideWith((ref) => CardDisplayLayout.list),
      ...overrides,
    ];

    if (container != null) {
      return UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(size: Size(1080, 2400)),
              child: child,
            ),
          ),
        ),
      );
    }

    return ProviderScope(
      overrides: defaultOverrides,
      child: MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(size: Size(1080, 2400)),
            child: child,
          ),
        ),
      ),
    );
  }

  group('Milestone 4: Multi-Feature Stress Verification (Challenger Suite)', () {
    // -------------------------------------------------------------------------
    // Scenario 1: Binder addition while paginating beyond 150 items
    // -------------------------------------------------------------------------
    testWidgets('Stress 1: Binder addition at high pagination index (>150 items) maintains pagination stability and database integrity', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // 1. Create target destination binder
      final binder = await db.vaultDao.createBinder(
        name: 'Late Pagination Vault',
        collectionType: 'mtg',
      );

      // 2. Seed 220 MTG items
      for (int i = 0; i < 220; i++) {
        await db.vaultDao.into(db.vaultItems).insert(
          createCompanion(
            id: 'late-pag-card-$i',
            name: 'Late Card ${i.toString().padLeft(4, '0')}',
            collectionType: 'mtg',
            quantity: 1,
            marketPrice: 20.0 + i,
          ),
        );
      }

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
        createHarness(
          container: container,
          child: const VaultScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Initial page limit is 50
      expect(container.read(vaultPaginationLimitProvider), equals(50));

      final scrollable = tester.state<ScrollableState>(
        find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down),
      );

      // Function to trigger lazy-load pagination step
      Future<void> scrollAndAdvance() async {
        final maxScroll = scrollable.position.maxScrollExtent;
        scrollable.position.jumpTo(maxScroll - 50);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();
      }

      // Step 1: Advance from 50 -> 100
      await scrollAndAdvance();
      expect(container.read(vaultPaginationLimitProvider), greaterThanOrEqualTo(100));

      // Step 2: Advance from 100 -> 150
      await scrollAndAdvance();
      expect(container.read(vaultPaginationLimitProvider), greaterThanOrEqualTo(150));

      // Step 3: Advance past 150 -> 200+
      await scrollAndAdvance();
      final currentLimit = container.read(vaultPaginationLimitProvider);
      expect(currentLimit, greaterThan(150), reason: 'Must successfully paginate past 150 items');

      // Now scroll to and locate card 180
      final targetCardId = 'late-pag-card-180';
      final targetCardName = 'Late Card 0180';

      final targetItemCard = find.widgetWithText(VaultItemCard, targetCardName);
      // Ensure target item is in view
      if (targetItemCard.evaluate().isEmpty) {
        for (int step = 0; step < 10; step++) {
          scrollable.position.jumpTo(scrollable.position.pixels + 600);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 50));
          if (targetItemCard.evaluate().isNotEmpty) break;
        }
      }

      expect(targetItemCard, findsOneWidget, reason: 'Card 180 must be renderable past 150 items');

      // Long-press to select card 180
      await tester.longPress(targetItemCard);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('vault_selection_move_binder_button')), findsOneWidget);

      // Tap Move to Binder
      await tester.tap(find.byKey(const Key('vault_selection_move_binder_button')));
      await tester.pumpAndSettle();

      // Select destination binder
      final optionFinder = find.byKey(Key('vault_binder_option_${binder.id}'));
      expect(optionFinder, findsOneWidget);
      await tester.tap(optionFinder);
      await tester.pumpAndSettle();

      // Invariants verification after binder assignment at high pagination:
      // 1. Database updated: target card assigned to binder
      final dbCard = await db.vaultDao.getItemById(targetCardId);
      expect(dbCard, isNotNull);
      expect(dbCard!.primaryBinderId, equals(binder.id));

      // 2. Selection bar dismissed
      expect(find.byKey(const Key('vault_selection_move_binder_button')), findsNothing);

      // 3. Pagination limit did NOT collapse back to 50
      expect(container.read(vaultPaginationLimitProvider), equals(currentLimit));

      // 4. isFetchingMore is not stuck
      expect(container.read(vaultIsFetchingMoreProvider), isFalse);

      // 5. User can continue scrolling without spinner deadlock
      await scrollAndAdvance();
      expect(container.read(vaultIsFetchingMoreProvider), isFalse);
    });

    // -------------------------------------------------------------------------
    // Scenario 2: Filtering while selecting multiple cards and assigning to binders
    // -------------------------------------------------------------------------
    testWidgets('Stress 2: Filtering while multi-selecting cards and assigning to binder promotes unowned cards, updates DB, and preserves active filter', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // 1. Create target binder
      final targetBinder = await db.vaultDao.createBinder(
        name: 'Filtered Selection Binder',
        collectionType: 'mtg',
      );

      // 2. Seed mixed cards:
      // - 4 Blue cards (2 unowned, 2 owned)
      // - 4 Red cards (owned)
      // - 4 Green cards (owned)
      final blue1 = createCompanion(id: 'blue-1', name: 'Blue Spell 1', collectionType: 'mtg', color: 'U', quantity: 0, marketPrice: 25.0);
      final blue2 = createCompanion(id: 'blue-2', name: 'Blue Spell 2', collectionType: 'mtg', color: 'U', quantity: 0, marketPrice: 15.0);
      final blue3 = createCompanion(id: 'blue-3', name: 'Blue Spell 3', collectionType: 'mtg', color: 'U', quantity: 1, marketPrice: 10.0);
      final blue4 = createCompanion(id: 'blue-4', name: 'Blue Spell 4', collectionType: 'mtg', color: 'U', quantity: 1, marketPrice: 5.0);

      await db.vaultDao.into(db.vaultItems).insert(blue1);
      await db.vaultDao.into(db.vaultItems).insert(blue2);
      await db.vaultDao.into(db.vaultItems).insert(blue3);
      await db.vaultDao.into(db.vaultItems).insert(blue4);

      for (int i = 1; i <= 4; i++) {
        await db.vaultDao.into(db.vaultItems).insert(
          createCompanion(id: 'red-$i', name: 'Red Fire $i', collectionType: 'mtg', color: 'R', quantity: 1),
        );
        await db.vaultDao.into(db.vaultItems).insert(
          createCompanion(id: 'green-$i', name: 'Green Growth $i', collectionType: 'mtg', color: 'G', quantity: 1),
        );
      }

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
          vaultShowCatalogProvider.overrideWith((ref) => true), // View all (including unowned)
          cardDisplayLayoutProvider.overrideWith((ref) => CardDisplayLayout.list),
        ],
      );
      addTearDown(container.dispose);

      // Set active MTG filter: Blue ('U')
      container.read(mtgFilterProvider.notifier).update(
        (s) => s.copyWith(
          colors: const {'U'},
          colorMatchMode: ColorMatchMode.including,
        ),
      );

      await tester.pumpWidget(
        createHarness(
          container: container,
          child: const VaultScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Invariant 1: Only Blue cards are displayed under active filter
      expect(find.text('Blue Spell 1'), findsOneWidget);
      expect(find.text('Blue Spell 2'), findsOneWidget);
      expect(find.text('Blue Spell 3'), findsOneWidget);
      expect(find.text('Blue Spell 4'), findsOneWidget);
      expect(find.text('Red Fire 1'), findsNothing);
      expect(find.text('Green Growth 1'), findsNothing);

      // Invariant 2: Multi-select 3 Blue cards (both unowned and owned)
      await tester.longPress(find.text('Blue Spell 1'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Blue Spell 2'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Blue Spell 3'));
      await tester.pumpAndSettle();

      expect(find.text('Move to Binder (3)'), findsOneWidget);

      // Invariant 3: Tap Move to Binder and choose destination
      await tester.tap(find.byKey(const Key('vault_selection_move_binder_button')));
      await tester.pumpAndSettle();

      final optionFinder = find.byKey(Key('vault_binder_option_${targetBinder.id}'));
      expect(optionFinder, findsOneWidget);
      await tester.tap(optionFinder);
      await tester.pumpAndSettle();

      // Invariant 4: Selection bar dismissed cleanly
      expect(find.byKey(const Key('vault_selection_move_binder_button')), findsNothing);

      // Invariant 5: Verify SQLite persistence and quantity promotion for unowned cards
      final dbBlue1 = await db.vaultDao.getItemById('blue-1');
      final dbBlue2 = await db.vaultDao.getItemById('blue-2');
      final dbBlue3 = await db.vaultDao.getItemById('blue-3');
      final dbBlue4 = await db.vaultDao.getItemById('blue-4');

      expect(dbBlue1!.quantity, equals(1), reason: 'Unowned blue-1 must be promoted to quantity 1');
      expect(dbBlue1.primaryBinderId, equals(targetBinder.id));
      expect(dbBlue1.acquiredPrice, equals(25.0));
      expect(dbBlue1.protectionStatus, equals('Sleeved'));

      expect(dbBlue2!.quantity, equals(1), reason: 'Unowned blue-2 must be promoted to quantity 1');
      expect(dbBlue2.primaryBinderId, equals(targetBinder.id));
      expect(dbBlue2.acquiredPrice, equals(15.0));

      expect(dbBlue3!.quantity, equals(1));
      expect(dbBlue3.primaryBinderId, equals(targetBinder.id));

      expect(dbBlue4!.primaryBinderId, isNull, reason: 'Unselected blue-4 should remain unassigned');

      // Invariant 6: Active filter remains active - Red and Green cards are still NOT visible
      expect(find.text('Red Fire 1'), findsNothing);
      expect(find.text('Green Growth 1'), findsNothing);
      expect(container.read(mtgFilterProvider).colors, contains('U'));
      expect(container.read(vaultIsFetchingMoreProvider), isFalse);
    });

    // -------------------------------------------------------------------------
    // Scenario 3: Game context switching under heavy active filtering
    // -------------------------------------------------------------------------
    testWidgets('Stress 3: Game context switching under heavy active MTG filtering isolates collections, prevents cross-game leakage, and resets state cleanly', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // 1. Seed MTG cards
      // - 3 Red Rare CMC 3 cards
      // - 3 Red Common CMC 1 cards
      // - 5 Blue cards
      for (int i = 1; i <= 3; i++) {
        await db.vaultDao.into(db.vaultItems).insert(
          createCompanion(
            id: 'mtg-red-rare-$i',
            name: 'Red Dragon $i',
            collectionType: 'mtg',
            color: 'R',
            rarity: 'rare',
            cmc: 3,
            quantity: 1,
          ),
        );
        await db.vaultDao.into(db.vaultItems).insert(
          createCompanion(
            id: 'mtg-red-common-$i',
            name: 'Red Goblin $i',
            collectionType: 'mtg',
            color: 'R',
            rarity: 'common',
            cmc: 1,
            quantity: 1,
          ),
        );
      }
      for (int i = 1; i <= 5; i++) {
        await db.vaultDao.into(db.vaultItems).insert(
          createCompanion(
            id: 'mtg-blue-$i',
            name: 'Blue Drake $i',
            collectionType: 'mtg',
            color: 'U',
            rarity: 'uncommon',
            cmc: 2,
            quantity: 1,
          ),
        );
      }

      // 2. Seed Pokemon cards
      for (int i = 1; i <= 5; i++) {
        await db.vaultDao.into(db.vaultItems).insert(
          createCompanion(
            id: 'pkm-$i',
            name: 'Pikachu EX #0$i',
            collectionType: 'pokemon',
            quantity: 1,
          ),
        );
      }

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
          cardDisplayLayoutProvider.overrideWith((ref) => CardDisplayLayout.list),
        ],
      );
      addTearDown(container.dispose);

      // Apply heavy MTG filter: Red ('R'), Rare, CMC == 3
      container.read(mtgFilterProvider.notifier).update(
        (s) => s.copyWith(
          colors: const {'R'},
          colorMatchMode: ColorMatchMode.including,
          rarities: const {'rare'},
          cmcRange: const RangeValues(3, 3),
        ),
      );

      await tester.pumpWidget(
        createHarness(
          container: container,
          child: const VaultScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Invariant 1: In MTG context with heavy filter, only Red Rare CMC 3 cards are shown
      expect(find.text('Red Dragon 1'), findsOneWidget);
      expect(find.text('Red Dragon 2'), findsOneWidget);
      expect(find.text('Red Dragon 3'), findsOneWidget);
      expect(find.text('Red Goblin 1'), findsNothing);
      expect(find.text('Blue Drake 1'), findsNothing);
      expect(find.text('Pikachu EX #01'), findsNothing);

      // Invariant 2: Switch game context to Pokemon
      container.read(activeGameContextProvider.notifier).state = 'Pokemon';
      await tester.pumpAndSettle();

      // Invariant 3: Pokemon collection rendered immediately; MTG cards completely gone
      expect(find.text('Pikachu EX #01'), findsOneWidget);
      expect(find.text('Pikachu EX #02'), findsOneWidget);
      expect(find.text('Red Dragon 1'), findsNothing, reason: 'MTG cards must not leak into Pokemon context');
      expect(find.text('Red Goblin 1'), findsNothing);
      expect(find.text('Blue Drake 1'), findsNothing);

      // Invariant 4: No spinner stuck after game context switch
      expect(container.read(vaultIsFetchingMoreProvider), isFalse);
      expect(container.read(vaultPaginationLimitProvider), equals(50));

      // Invariant 5: Switch back to MTG restores MTG filtered collection
      container.read(activeGameContextProvider.notifier).state = 'Magic: The Gathering';
      await tester.pumpAndSettle();

      expect(find.text('Red Dragon 1'), findsOneWidget);
      expect(find.text('Red Dragon 2'), findsOneWidget);
      expect(find.text('Red Dragon 3'), findsOneWidget);
      expect(find.text('Pikachu EX #01'), findsNothing, reason: 'Pokemon cards must not leak into MTG context');
      expect(find.text('Red Goblin 1'), findsNothing);
      expect(container.read(vaultIsFetchingMoreProvider), isFalse);
    });
  });
}
