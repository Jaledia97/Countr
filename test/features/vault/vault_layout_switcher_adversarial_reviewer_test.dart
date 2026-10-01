import 'dart:convert';
import 'dart:ui' as ui;
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
          id: 'rev-test-card-$i',
          collectionType: 'mtg',
          name: 'Rev Card $i',
          setOrSeries: 'Set $i',
          imageUrl: 'https://example.com/rev_$i.jpg',
          acquiredPrice: 3.50 * i,
          acquiredDate: DateTime(2024, 1, i),
          quantity: const drift.Value(1),
          condition: 'NM',
          isGraded: const drift.Value(false),
          currentMarketPrice: 5.0 * i,
          lastPriceUpdate: DateTime.now(),
          dynamicData: jsonEncode({
            'set': 'set$i',
            'set_code': 'set$i',
            'released_at': '2024-01-0$i',
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

  group('Reviewer-2 Adversarial Audit: Layout Switcher Filter Anchor', () {
    testWidgets('1. Semantics Audit: Layout buttons and View toggles accurately declare selected state to screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      try {
        await seedTestCards(db, 2);

        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(db.vaultDao),
            activeGameContextProvider.overrideWith((ref) => 'mtg'),
            vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
            cardDisplayLayoutProvider.overrideWith((ref) => CardDisplayLayout.grid),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(buildHarness(container: container));
        await tester.pumpAndSettle();

        final listBtnFinder = find.byKey(const Key('vault_layout_list_button'));
        final gridBtnFinder = find.byKey(const Key('vault_layout_grid_button'));
        final singlesFinder = find.byKey(const Key('vault_view_singles_toggle'));
        final bindersFinder = find.byKey(const Key('vault_view_binders_toggle'));

        // In default grid layout: grid is selected, list is unselected
        final gridSemantics = tester.getSemantics(gridBtnFinder);
        final listSemantics = tester.getSemantics(listBtnFinder);
        expect(gridSemantics.flagsCollection.isButton, isTrue);
        expect(listSemantics.flagsCollection.isButton, isTrue);
        expect(gridSemantics.flagsCollection.isSelected, equals(ui.Tristate.isTrue));
        expect(listSemantics.flagsCollection.isSelected, equals(ui.Tristate.isFalse));

        // View toggle: singles is selected, binders is unselected
        final singlesSemantics = tester.getSemantics(singlesFinder);
        final bindersSemantics = tester.getSemantics(bindersFinder);
        expect(singlesSemantics.flagsCollection.isButton, isTrue);
        expect(bindersSemantics.flagsCollection.isButton, isTrue);
        expect(singlesSemantics.flagsCollection.isSelected, equals(ui.Tristate.isTrue));
        expect(bindersSemantics.flagsCollection.isSelected, equals(ui.Tristate.isFalse));

        // Tap list button: list becomes selected, grid becomes unselected
        await tester.tap(listBtnFinder);
        await tester.pumpAndSettle();

        final updatedListSemantics = tester.getSemantics(listBtnFinder);
        final updatedGridSemantics = tester.getSemantics(gridBtnFinder);
        expect(updatedListSemantics.flagsCollection.isSelected, equals(ui.Tristate.isTrue));
        expect(updatedGridSemantics.flagsCollection.isSelected, equals(ui.Tristate.isFalse));
      } finally {
        handle.dispose();
      }
    });

    testWidgets('2. Hit-Test Integrity: Tapping on edge/padding of layout button triggers layout switch via opaque hit test', (tester) async {
      await seedTestCards(db, 2);

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'mtg'),
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
          cardDisplayLayoutProvider.overrideWith((ref) => CardDisplayLayout.grid),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(buildHarness(container: container));
      await tester.pumpAndSettle();

      final listBtnFinder = find.byKey(const Key('vault_layout_list_button'));
      // Tap near top-left edge of the list button container
      final listTopLeft = tester.getTopLeft(listBtnFinder);
      await tester.tapAt(listTopLeft + const Offset(2, 2));
      await tester.pumpAndSettle();

      expect(container.read(cardDisplayLayoutProvider), equals(CardDisplayLayout.list));
      expect(find.byType(VaultItemCard), findsNWidgets(2));
      expect(find.byType(VaultItemTile), findsNothing);
    });

    testWidgets('3. Multi-Touch Concurrency: Simultaneous pointers on layout switcher and filter chips resolve safely without deadlock', (tester) async {
      await seedTestCards(db, 5);

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

      final listBtnFinder = find.byKey(const Key('vault_layout_list_button'));
      final ownedChipFinder = find.byKey(const Key('vault_filter_chip_owned'));

      // Pointer 1 presses and holds the Owned filter chip
      final pointer1 = await tester.createGesture(pointer: 1);
      await pointer1.down(tester.getCenter(ownedChipFinder));
      await tester.pump();

      // Drag pointer 1 horizontally (simulating active chip scrolling)
      await pointer1.moveBy(const Offset(-50, 0));
      await tester.pump();

      // Pointer 2 simultaneously taps the List layout toggle
      final pointer2 = await tester.createGesture(pointer: 2);
      await pointer2.down(tester.getCenter(listBtnFinder));
      await tester.pump(const Duration(milliseconds: 50));
      await pointer2.up();
      await tester.pumpAndSettle();

      // Layout should have successfully switched to list mode
      expect(container.read(cardDisplayLayoutProvider), equals(CardDisplayLayout.list));
      expect(tester.takeException(), isNull);

      // Release pointer 1 cleanly
      await pointer1.up();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('4. Scroll Position Persistence: Filter row horizontal scroll offset is preserved across view mode switches', (tester) async {
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

      final ownedChip = find.byKey(const Key('vault_filter_chip_owned'));
      final initialOwnedPos = tester.getTopLeft(ownedChip);

      // Drag the filter chips row by 150px to the left
      await tester.drag(ownedChip, const Offset(-150, 0));
      await tester.pumpAndSettle();

      final scrolledOwnedPos = tester.getTopLeft(ownedChip);
      expect(scrolledOwnedPos.dx, lessThan(initialOwnedPos.dx));

      // Switch to Binders view
      await tester.tap(find.byKey(const Key('vault_view_binders_toggle')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('vault_filter_chip_owned')), findsNothing);

      // Switch back to Singles view
      await tester.tap(find.byKey(const Key('vault_view_singles_toggle')));
      await tester.pumpAndSettle();

      // Owned chip should have its scrolled offset restored via PageStorageKey
      final restoredOwnedPos = tester.getTopLeft(find.byKey(const Key('vault_filter_chip_owned')));
      expect(restoredOwnedPos.dx, equals(scrolledOwnedPos.dx));
    });

    testWidgets('5. Horizontal Containment: Filter chips clip cleanly without visual or geometric overlap into layout switcher', (tester) async {
      await seedTestCards(db, 2);

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

      final gridButton = find.byKey(const Key('vault_layout_grid_button'));
      final layoutSwitcherRight = tester.getTopRight(gridButton).dx;

      final scrollViewFinder = find.byKey(const PageStorageKey<String>('vault_mtg_filter_chips_scroll'));
      expect(scrollViewFinder, findsOneWidget);

      final scrollViewLeft = tester.getTopLeft(scrollViewFinder).dx;
      // Scroll view must start strictly after layout switcher right edge + spacing gap
      expect(scrollViewLeft, greaterThanOrEqualTo(layoutSwitcherRight));

      // Scroll filter chips significantly to the left
      await tester.drag(scrollViewFinder, const Offset(-300, 0));
      await tester.pumpAndSettle();

      // Layout switcher button remains at its initial position
      expect(tester.getTopRight(gridButton).dx, equals(layoutSwitcherRight));
      // ScrollView left bound remains invariant
      expect(tester.getTopLeft(scrollViewFinder).dx, equals(scrollViewLeft));
    });
  });
}
