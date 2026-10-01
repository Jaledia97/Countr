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
          id: 'adv-test-card-$i',
          collectionType: 'mtg',
          name: 'Card Name $i',
          setOrSeries: 'Set $i',
          imageUrl: 'https://example.com/card_$i.jpg',
          acquiredPrice: 1.0 * i,
          acquiredDate: DateTime(2024, 1, i),
          quantity: const drift.Value(1),
          condition: 'NM',
          isGraded: const drift.Value(false),
          currentMarketPrice: 2.0 * i,
          lastPriceUpdate: DateTime.now(),
          dynamicData: '{}',
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

  group('Adversarial Stress: Vault Layout Switcher Persistent Filter Anchor', () {
    testWidgets('Adversarial Stress 1: Extreme horizontal flings & end-to-end scroll stability', (tester) async {
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

      final listButton = find.byKey(const Key('vault_layout_list_button'));
      final gridButton = find.byKey(const Key('vault_layout_grid_button'));
      final initialListPos = tester.getTopLeft(listButton);
      final initialGridPos = tester.getTopLeft(gridButton);

      // Perform rapid bidirectional flings on the filter row
      for (int i = 0; i < 5; i++) {
        await tester.fling(find.byKey(const Key('vault_filter_chip_owned')), const Offset(-600, 0), 2000);
        await tester.pumpAndSettle();
        // Layout buttons must maintain exact coordinates
        expect(tester.getTopLeft(listButton), equals(initialListPos));
        expect(tester.getTopLeft(gridButton), equals(initialGridPos));

        await tester.fling(find.byType(SingleChildScrollView).first, const Offset(600, 0), 2000);
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(listButton), equals(initialListPos));
        expect(tester.getTopLeft(gridButton), equals(initialGridPos));
      }
    });

    testWidgets('Adversarial Stress 2: Ultra-narrow 320px viewport with 2.5x and 3.0x text scaling', (tester) async {
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

      // Test with 320px width and 2.5x text scale
      await tester.pumpWidget(buildHarness(
        container: container,
        viewportSize: const Size(320, 640),
        textScale: 2.5,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('vault_layout_list_button')), findsOneWidget);
      expect(find.byKey(const Key('vault_layout_grid_button')), findsOneWidget);
      expect(find.byKey(const Key('vault_filter_chip_owned')), findsOneWidget);

      // Toggle layout under 2.5x text scale
      await tester.tap(find.byKey(const Key('vault_layout_list_button')));
      await tester.pumpAndSettle();
      expect(container.read(cardDisplayLayoutProvider), equals(CardDisplayLayout.list));
      expect(tester.takeException(), isNull);

      // Test with 320px width and 3.0x extreme text scale
      await tester.pumpWidget(buildHarness(
        container: container,
        viewportSize: const Size(320, 640),
        textScale: 3.0,
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('vault_layout_grid_button')));
      await tester.pumpAndSettle();
      expect(container.read(cardDisplayLayoutProvider), equals(CardDisplayLayout.grid));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Adversarial Stress 3: Rapid layout toggling during search expansion and collapse', (tester) async {
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

      // Rapidly expand search, switch to list layout, type query, toggle back to grid, collapse search
      await tester.tap(find.byKey(const Key('vault_search_expand_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('vault_layout_list_button')));
      await tester.pumpAndSettle();
      expect(container.read(cardDisplayLayoutProvider), equals(CardDisplayLayout.list));

      await tester.enterText(find.byKey(const Key('vault_search_text_field')), 'Card');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.byType(VaultItemCard), findsNWidgets(2));
      expect(find.byType(VaultItemTile), findsNothing);

      await tester.tap(find.byKey(const Key('vault_layout_grid_button')));
      await tester.pumpAndSettle();
      expect(container.read(cardDisplayLayoutProvider), equals(CardDisplayLayout.grid));
      expect(find.byType(VaultItemTile), findsNWidgets(2));
      expect(find.byType(VaultItemCard), findsNothing);

      // Clear & Collapse
      await tester.tap(find.byKey(const Key('vault_search_clear_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('vault_search_collapse_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('vault_view_singles_toggle')), findsOneWidget);
      expect(find.byKey(const Key('vault_layout_grid_button')), findsOneWidget);
      expect(find.byKey(const Key('vault_layout_list_button')), findsOneWidget);
    });

    testWidgets('Adversarial Stress 4: Polymorphic multi-TCG switcher rapid context alternation', (tester) async {
      final games = ['pokemon', 'lorcana', 'starwars', 'onepiece', 'mtg'];

      for (final game in games) {
        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(db.vaultDao),
            activeGameContextProvider.overrideWith((ref) => game),
            vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
          ],
        );

        await tester.pumpWidget(buildHarness(container: container));
        await tester.pumpAndSettle();

        final listBtn = find.byKey(const Key('vault_layout_list_button'));
        final gridBtn = find.byKey(const Key('vault_layout_grid_button'));
        final ownedChip = find.byKey(const Key('vault_filter_chip_owned'));

        expect(listBtn, findsOneWidget, reason: 'List button missing for $game');
        expect(gridBtn, findsOneWidget, reason: 'Grid button missing for $game');
        expect(ownedChip, findsOneWidget, reason: 'Owned chip missing for $game');

        final listPos = tester.getTopLeft(listBtn);
        final ownedPos = tester.getTopLeft(ownedChip);
        expect(listPos.dx, lessThan(ownedPos.dx), reason: 'List button must precede Owned chip in $game');

        container.dispose();
      }
    });

    testWidgets('Adversarial Stress 5: Spacing and layout geometry verification', (tester) async {
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
      final searchControlsBar = find.byKey(const Key('vault_search_expand_button'));

      final listTop = tester.getTopLeft(listButton).dy;
      final searchControlsBottom = tester.getBottomLeft(searchControlsBar).dy;

      // Vertical breathing room between search/controls bar and layout switcher
      final verticalGap = listTop - searchControlsBottom;
      expect(verticalGap, greaterThanOrEqualTo(8.0),
          reason: 'Must maintain breathing room below search/controls bar');

      // Horizontal spacing between layout switcher and owned chip
      // List button is inside the 38px height container with border & padding
      final ownedLeft = tester.getTopLeft(ownedChip).dx;
      final gridButtonRight = tester.getTopRight(find.byKey(const Key('vault_layout_grid_button'))).dx;
      final horizontalGap = ownedLeft - gridButtonRight;
      expect(horizontalGap, greaterThanOrEqualTo(8.0),
          reason: 'Must maintain horizontal spacing between layout switcher and Owned chip');
    });
  });
}
