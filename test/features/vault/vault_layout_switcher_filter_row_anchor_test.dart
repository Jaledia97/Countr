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

  Future<void> seedTestCard(AppDatabase database) async {
    await database.vaultDao.into(database.vaultItems).insert(
      VaultItemsCompanion.insert(
        id: 'anchor-test-card-1',
        collectionType: 'mtg',
        name: 'Sol Ring',
        setOrSeries: 'Commander',
        imageUrl: 'https://example.com/sol_ring.jpg',
        acquiredPrice: 2.50,
        acquiredDate: DateTime(2024, 1, 1),
        quantity: const drift.Value(1),
        condition: 'NM',
        isGraded: const drift.Value(false),
        currentMarketPrice: 2.50,
        lastPriceUpdate: DateTime.now(),
        dynamicData: '{}',
      ),
    );
  }

  Widget buildHarness({
    required ProviderContainer container,
    Size viewportSize = const Size(390, 844),
  }) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: ThemeData.dark(),
        home: MediaQuery(
          data: MediaQueryData(size: viewportSize),
          child: const VaultScreen(),
        ),
      ),
    );
  }

  group('VaultScreen - Persistent Left-Anchored List/Tile Layout Switcher in Filter Row', () {
    testWidgets('AC1 & AC3: List/Tile toggle is positioned on filter pills row at far left, directly preceding "Owned" pill', (tester) async {
      await seedTestCard(db);

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

      final listButton = find.byKey(const Key('vault_layout_list_button'));
      final gridButton = find.byKey(const Key('vault_layout_grid_button'));
      final ownedChip = find.byKey(const Key('vault_filter_chip_owned'));
      final singlesToggle = find.byKey(const Key('vault_view_singles_toggle'));

      expect(listButton, findsOneWidget);
      expect(gridButton, findsOneWidget);
      expect(ownedChip, findsOneWidget);
      expect(singlesToggle, findsOneWidget);

      final listButtonPos = tester.getTopLeft(listButton);
      final ownedChipPos = tester.getTopLeft(ownedChip);
      final singlesTogglePos = tester.getTopLeft(singlesToggle);

      // 1. List/Tile toggle is strictly below the primary view switcher row
      expect(listButtonPos.dy, greaterThan(singlesTogglePos.dy));

      // 2. List/Tile toggle is positioned to the left of the "Owned" filter pill
      expect(listButtonPos.dx, lessThan(ownedChipPos.dx));

      // 3. Both List/Tile toggle and "Owned" filter pill are vertically aligned in the same row
      final listButtonCenterY = tester.getCenter(listButton).dy;
      final ownedChipCenterY = tester.getCenter(ownedChip).dy;
      expect((listButtonCenterY - ownedChipCenterY).abs(), lessThan(8.0),
          reason: 'Layout switcher and Owned chip must be on the same horizontal row');
    });

    testWidgets('AC2: List/Tile toggle remains persistently pinned and does not scroll when filter chips are scrolled', (tester) async {
      await seedTestCard(db);

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

      final listButton = find.byKey(const Key('vault_layout_list_button'));
      final ownedChip = find.byKey(const Key('vault_filter_chip_owned'));

      final initialListButtonPos = tester.getTopLeft(listButton);
      final initialOwnedChipPos = tester.getTopLeft(ownedChip);

      // Scroll the horizontal filter chips to the left by dragging the Owned chip
      await tester.drag(ownedChip, const Offset(-200, 0));
      await tester.pumpAndSettle();

      final scrolledListButtonPos = tester.getTopLeft(listButton);
      final scrolledOwnedChipPos = tester.getTopLeft(ownedChip);

      // The Owned chip has shifted to the left
      expect(scrolledOwnedChipPos.dx, lessThan(initialOwnedChipPos.dx));

      // The layout switcher button position is STRICTLY UNCHANGED (persistent anchor)
      expect(scrolledListButtonPos.dx, equals(initialListButtonPos.dx));
      expect(scrolledListButtonPos.dy, equals(initialListButtonPos.dy));
    });

    testWidgets('AC4: Tapping List and Grid layout buttons properly updates cardDisplayLayoutProvider and switches views', (tester) async {
      await seedTestCard(db);

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

      final listButton = find.byKey(const Key('vault_layout_list_button'));
      final gridButton = find.byKey(const Key('vault_layout_grid_button'));

      // Default is grid layout
      expect(container.read(cardDisplayLayoutProvider), equals(CardDisplayLayout.grid));
      expect(find.byType(VaultItemTile), findsOneWidget);
      expect(find.byType(VaultItemCard), findsNothing);

      // Tap List layout button
      await tester.tap(listButton);
      await tester.pumpAndSettle();

      expect(container.read(cardDisplayLayoutProvider), equals(CardDisplayLayout.list));
      expect(find.byType(VaultItemCard), findsOneWidget);
      expect(find.byType(VaultItemTile), findsNothing);

      // Tap Grid layout button
      await tester.tap(gridButton);
      await tester.pumpAndSettle();

      expect(container.read(cardDisplayLayoutProvider), equals(CardDisplayLayout.grid));
      expect(find.byType(VaultItemTile), findsOneWidget);
      expect(find.byType(VaultItemCard), findsNothing);
    });

    testWidgets('AC5: [ Singles | Binders | Collections ] row is uncrowded and responsive across mobile viewports (320px)', (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await seedTestCard(db);

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'mtg'),
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(buildHarness(container: container, viewportSize: const Size(320, 600)));
      await tester.pumpAndSettle();

      // Zero exceptions / RenderFlex overflows
      expect(tester.takeException(), isNull);

      // View switcher items all visible and distinct
      expect(find.byKey(const Key('vault_view_singles_toggle')), findsOneWidget);
      expect(find.byKey(const Key('vault_view_binders_toggle')), findsOneWidget);
      expect(find.byKey(const Key('vault_view_collections_toggle')), findsOneWidget);
      expect(find.byKey(const Key('vault_search_expand_button')), findsOneWidget);

      // Layout buttons and filter row render cleanly without overflow
      expect(find.byKey(const Key('vault_layout_list_button')), findsOneWidget);
      expect(find.byKey(const Key('vault_layout_grid_button')), findsOneWidget);
      expect(find.byKey(const Key('vault_filter_chip_owned')), findsOneWidget);
    });

    testWidgets('Polymorphic Mode: Anchors List/Tile toggle before "Owned" filter chip for non-MTG games', (tester) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'pokemon'),
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(buildHarness(container: container));
      await tester.pumpAndSettle();

      final listButton = find.byKey(const Key('vault_layout_list_button'));
      final ownedChip = find.byKey(const Key('vault_filter_chip_owned'));

      expect(listButton, findsOneWidget);
      expect(ownedChip, findsOneWidget);

      final listButtonPos = tester.getTopLeft(listButton);
      final ownedChipPos = tester.getTopLeft(ownedChip);

      expect(listButtonPos.dx, lessThan(ownedChipPos.dx));
      expect((tester.getCenter(listButton).dy - tester.getCenter(ownedChip).dy).abs(), lessThan(8.0));
    });
  });
}
