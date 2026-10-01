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
import 'package:countr/features/vault/presentation/widgets/vault_item_card.dart';
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

  Future<void> seedTestCards(AppDatabase database, int count) async {
    for (int i = 1; i <= count; i++) {
      await database.vaultDao.into(database.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'rev3-test-card-$i',
          collectionType: 'mtg',
          name: 'Rev3 Card $i',
          setOrSeries: 'Set $i',
          imageUrl: 'https://example.com/rev3_$i.jpg',
          acquiredPrice: 2.0 * i,
          acquiredDate: DateTime(2024, 1, i),
          quantity: const drift.Value(1),
          condition: 'NM',
          isGraded: const drift.Value(false),
          currentMarketPrice: 4.0 * i,
          lastPriceUpdate: DateTime.now(),
          dynamicData: jsonEncode({
            'set': 'set$i',
            'set_code': 'set$i',
            'released_at': '2024-01-0$i',
            'colors': ['W', 'U'],
            'rarity': 'rare',
          }),
        ),
      );
    }
  }

  Widget buildHarness({
    required ProviderContainer container,
    Size viewportSize = const Size(390, 844),
    double textScale = 1.0,
  }) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: ThemeData.dark(),
        home: MediaQuery(
          data: MediaQueryData(
            size: viewportSize,
            textScaler: TextScaler.linear(textScale),
          ),
          child: const VaultScreen(),
        ),
      ),
    );
  }

  group('Reviewer-3 Adversarial Edge-Case Suite: Vault Layout Switcher Anchor', () {
    testWidgets('1. Extreme constraints: 280px width & 3.5x text scale renders zero overflow', (tester) async {
      await seedTestCards(db, 3);

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'mtg'),
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(buildHarness(
        container: container,
        viewportSize: const Size(280, 600),
        textScale: 3.5,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      final listBtn = find.byKey(const Key('vault_layout_list_button'));
      final gridBtn = find.byKey(const Key('vault_layout_grid_button'));
      final ownedChip = find.byKey(const Key('vault_filter_chip_owned'));

      expect(listBtn, findsOneWidget);
      expect(gridBtn, findsOneWidget);
      expect(ownedChip, findsOneWidget);

      final listPos = tester.getTopLeft(listBtn);
      final ownedPos = tester.getTopLeft(ownedChip);
      expect(listPos.dx, lessThan(ownedPos.dx));

      // Switch to list layout under extreme constraints
      await tester.tap(listBtn);
      await tester.pumpAndSettle();

      expect(container.read(cardDisplayLayoutProvider), equals(CardDisplayLayout.list));
      expect(tester.takeException(), isNull);
    });

    testWidgets('2. Landscape orientation (900x400): Layout switcher remains persistently anchored on left', (tester) async {
      await seedTestCards(db, 4);

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'mtg'),
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(buildHarness(
        container: container,
        viewportSize: const Size(900, 400),
      ));
      await tester.pumpAndSettle();

      final listBtn = find.byKey(const Key('vault_layout_list_button'));
      final gridBtn = find.byKey(const Key('vault_layout_grid_button'));
      final ownedChip = find.byKey(const Key('vault_filter_chip_owned'));

      final listPos = tester.getTopLeft(listBtn);
      final ownedPos = tester.getTopLeft(ownedChip);

      expect(listPos.dx, lessThan(ownedPos.dx));
      expect(listPos.dx, lessThan(50.0), reason: 'Must remain anchored at left margin');

      // Drag filter chips in landscape
      await tester.drag(ownedChip, const Offset(-300, 0));
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(listBtn), equals(listPos));
      expect(tester.getTopLeft(gridBtn), isNotNull);
    });

    testWidgets('3. Filter Sheet interaction: opening/closing filter sheet preserves layout switcher state', (tester) async {
      await seedTestCards(db, 3);

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'mtg'),
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
          cardDisplayLayoutProvider.overrideWith((ref) => CardDisplayLayout.list),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(buildHarness(container: container));
      await tester.pumpAndSettle();

      // Verify initial layout is list
      expect(container.read(cardDisplayLayoutProvider), equals(CardDisplayLayout.list));

      // Open filter sheet
      final filterSheetBtn = find.byKey(const Key('vault_mtg_filter_button'));
      expect(filterSheetBtn, findsOneWidget);
      await tester.tap(filterSheetBtn);
      await tester.pumpAndSettle();

      // Dismiss filter sheet by dragging down or tapping outside
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      // Layout switcher must still be present and in list mode
      final listBtn = find.byKey(const Key('vault_layout_list_button'));
      expect(listBtn, findsOneWidget);
      expect(container.read(cardDisplayLayoutProvider), equals(CardDisplayLayout.list));

      // Switch back to grid mode
      await tester.tap(find.byKey(const Key('vault_layout_grid_button')));
      await tester.pumpAndSettle();
      expect(container.read(cardDisplayLayoutProvider), equals(CardDisplayLayout.grid));
    });

    testWidgets('4. Concurrency during search debounce: rapid layout toggling matches final state', (tester) async {
      await seedTestCards(db, 3);

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'mtg'),
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(buildHarness(container: container));
      await tester.pumpAndSettle();

      // Expand search
      await tester.tap(find.byKey(const Key('vault_search_expand_button')));
      await tester.pumpAndSettle();

      // Enter search text
      await tester.enterText(find.byKey(const Key('vault_search_text_field')), 'Rev3');
      // Advance by 100ms (debounce is 250ms, so not yet fired)
      await tester.pump(const Duration(milliseconds: 100));

      // Rapidly alternate layout toggles before debounce fires
      final listBtn = find.byKey(const Key('vault_layout_list_button'));
      final gridBtn = find.byKey(const Key('vault_layout_grid_button'));

      await tester.tap(listBtn);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(gridBtn);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(listBtn);
      await tester.pump(const Duration(milliseconds: 50));

      // Now allow the debounce timer to complete
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      // Final state must be list layout
      expect(container.read(cardDisplayLayoutProvider), equals(CardDisplayLayout.list));
      expect(find.byType(VaultItemCard), findsNWidgets(3));
      expect(find.byType(VaultItemTile), findsNothing);
    });

    testWidgets('5. Polymorphic mode: layout switcher stays anchored while scrolling non-MTG chips', (tester) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'lorcana'),
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(buildHarness(container: container));
      await tester.pumpAndSettle();

      final listBtn = find.byKey(const Key('vault_layout_list_button'));
      final gridBtn = find.byKey(const Key('vault_layout_grid_button'));
      final initialListPos = tester.getTopLeft(listBtn);

      // Scroll polymorphic chips
      final ownedChip = find.byKey(const Key('vault_filter_chip_owned'));
      await tester.drag(ownedChip, const Offset(-200, 0));
      await tester.pumpAndSettle();

      // Position of list and grid buttons must not move
      expect(tester.getTopLeft(listBtn), equals(initialListPos));

      // Tap list button in polymorphic mode
      await tester.tap(listBtn);
      await tester.pumpAndSettle();
      expect(container.read(cardDisplayLayoutProvider), equals(CardDisplayLayout.list));

      // Tap grid button in polymorphic mode
      await tester.tap(gridBtn);
      await tester.pumpAndSettle();
      expect(container.read(cardDisplayLayoutProvider), equals(CardDisplayLayout.grid));
    });

    testWidgets('6. Layout provider state persistence across multi-step view mode transitions', (tester) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'mtg'),
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(buildHarness(container: container));
      await tester.pumpAndSettle();

      // Switch to List layout
      await tester.tap(find.byKey(const Key('vault_layout_list_button')));
      await tester.pumpAndSettle();
      expect(container.read(cardDisplayLayoutProvider), equals(CardDisplayLayout.list));

      // Switch to Binders view mode
      await tester.tap(find.byKey(const Key('vault_view_binders_toggle')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('vault_layout_list_button')), findsNothing);

      // Switch to Collections view mode
      await tester.tap(find.byKey(const Key('vault_view_collections_toggle')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('vault_layout_list_button')), findsNothing);

      // Switch back to Singles (allVault) view mode
      await tester.tap(find.byKey(const Key('vault_view_singles_toggle')));
      await tester.pumpAndSettle();

      // Layout switcher reappears, provider still retains List layout, semantics reflect selected
      expect(find.byKey(const Key('vault_layout_list_button')), findsOneWidget);
      expect(container.read(cardDisplayLayoutProvider), equals(CardDisplayLayout.list));
    });
  });
}
