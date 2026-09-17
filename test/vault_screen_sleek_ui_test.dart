import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/screens/vault_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 3.8 Requirement R2: Vault Providers Defaults', () {
    test('vaultViewModeProvider defaults to VaultViewMode.binders', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final defaultViewMode = container.read(vaultViewModeProvider);
      expect(defaultViewMode, equals(VaultViewMode.binders));
    });

    test('cardDisplayLayoutProvider defaults to CardDisplayLayout.grid', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final defaultLayout = container.read(cardDisplayLayoutProvider);
      expect(defaultLayout, equals(CardDisplayLayout.grid));
    });
  });

  group('Phase 3.8 Requirement R2: VaultScreen Sleek UI Overhaul & Animated Search', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await db.vaultDao.clearAllItems();
      await db.vaultDao.seedDatabase();
      await db.into(db.vaultBinders).insert(
            VaultBindersCompanion.insert(
              id: 'test-binder-1',
              name: 'Rare Binder',
              collectionType: 'mtg',
              createdAt: DateTime.now(),
            ),
          );
    });

    tearDown(() async {
      await db.close();
    });

    Widget createTestWidget({
      List<Override> overrides = const [],
    }) {
      return ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
          ...overrides,
        ],
        child: const MaterialApp(
          home: VaultScreen(),
        ),
      );
    }

    testWidgets('VaultScreen opens in Binders mode with + New Binder FAB visible by default', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // View toggle shows Binders is active and Singles option is available
      expect(find.byKey(const Key('vault_view_binders_toggle')), findsOneWidget);
      expect(find.byKey(const Key('vault_view_singles_toggle')), findsOneWidget);

      // FloatingActionButton [ + New Binder ] is present in Binders view
      expect(find.byKey(const Key('vault_new_binder_fab')), findsOneWidget);
      expect(find.text('New Binder'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsWidgets);

      // Binders grid exists with 2 columns
      final bindersGridFinder = find.byKey(const PageStorageKey<String>('vault_binders_sliver_grid'));
      expect(bindersGridFinder, findsOneWidget);
      final bindersGrid = tester.widget<SliverGrid>(bindersGridFinder);
      final delegate = bindersGrid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, equals(2));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('Switching between Binders and Singles conditionally shows/hides the FAB', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // In Binders view: FAB is visible
      expect(find.byKey(const Key('vault_new_binder_fab')), findsOneWidget);

      // Tap 'Singles' toggle
      await tester.tap(find.byKey(const Key('vault_view_singles_toggle')));
      await tester.pumpAndSettle();

      // In Singles view: FAB is hidden
      expect(find.byKey(const Key('vault_new_binder_fab')), findsNothing);

      // Switch back to 'Binders'
      await tester.tap(find.byKey(const Key('vault_view_binders_toggle')));
      await tester.pumpAndSettle();

      // FAB is visible again
      expect(find.byKey(const Key('vault_new_binder_fab')), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('Singles view displays Owned filter chip instead of legacy All Vault', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Switch to Singles
      await tester.tap(find.byKey(const Key('vault_view_singles_toggle')));
      await tester.pumpAndSettle();

      // Modernized filter chip label: 'Owned'
      expect(find.text('Owned'), findsOneWidget);
      expect(find.text('All Vault'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('Layout switcher displays icons only without text labels', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Switch to Singles mode where layout switcher is rendered
      await tester.tap(find.byKey(const Key('vault_view_singles_toggle')));
      await tester.pumpAndSettle();

      // Grid and List layout buttons are present with their icon buttons
      expect(find.byKey(const Key('vault_layout_grid_button')), findsOneWidget);
      expect(find.byKey(const Key('vault_layout_list_button')), findsOneWidget);
      expect(find.byIcon(Icons.grid_view_rounded), findsOneWidget);
      expect(find.byIcon(Icons.view_list_rounded), findsOneWidget);

      // Verify no textual "Grid" or "List" buttons clutter the bar
      expect(find.text('Grid'), findsNothing);
      expect(find.text('List'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('Grid layout calculates 3 columns for mobile/phone viewports (< 600px)', (tester) async {
      tester.view.physicalSize = const Size(390, 844); // Standard iPhone viewport width
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Switch to Singles mode
      await tester.tap(find.byKey(const Key('vault_view_singles_toggle')));
      await tester.pumpAndSettle();

      // Singles grid delegate should have 3 columns on phone screen
      final cardsGridFinder = find.byKey(const PageStorageKey<String>('vault_cards_sliver_grid'));
      expect(cardsGridFinder, findsOneWidget);
      final cardsGrid = tester.widget<SliverGrid>(cardsGridFinder);
      final delegate = cardsGrid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, equals(3));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('Grid layout calculates 4 columns for tablet (600-899px) and 5 columns for desktop (900-1199px)', (tester) async {
      // Tablet width (768px)
      tester.view.physicalSize = const Size(768, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('vault_view_singles_toggle')));
      await tester.pumpAndSettle();

      final tabletGridFinder = find.byKey(const PageStorageKey<String>('vault_cards_sliver_grid'));
      final tabletGrid = tester.widget<SliverGrid>(tabletGridFinder);
      final tabletDelegate = tabletGrid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(tabletDelegate.crossAxisCount, equals(4));

      // Desktop width (1000px)
      tester.view.physicalSize = const Size(1000, 800);
      await tester.pumpAndSettle();

      final desktopGridFinder = find.byKey(const PageStorageKey<String>('vault_cards_sliver_grid'));
      final desktopGrid = tester.widget<SliverGrid>(desktopGridFinder);
      final desktopDelegate = desktopGrid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(desktopDelegate.crossAxisCount, equals(5));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('Animated search bar starts collapsed with search icon and view toggles visible', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Expand icon button is visible
      expect(find.byKey(const Key('vault_search_expand_button')), findsOneWidget);

      // View toggles ('Singles' & 'Binders') are visible in collapsed state
      expect(find.byKey(const Key('vault_view_singles_toggle')), findsOneWidget);
      expect(find.byKey(const Key('vault_view_binders_toggle')), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('Tapping search icon expands full-width search bar concealing view toggles, and close icon collapses it',
        (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Initial collapsed state: crossFadeState is showFirst
      final initialCrossFade = tester.widget<AnimatedCrossFade>(find.byType(AnimatedCrossFade));
      expect(initialCrossFade.crossFadeState, equals(CrossFadeState.showFirst));
      expect(find.byKey(const Key('vault_view_singles_toggle')), findsOneWidget);
      expect(find.byKey(const Key('vault_view_binders_toggle')), findsOneWidget);
      expect(find.byKey(const Key('vault_search_expand_button')), findsOneWidget);

      // Tap search icon to expand
      await tester.tap(find.byKey(const Key('vault_search_expand_button')));
      await tester.pumpAndSettle();

      // AnimatedCrossFade switched to showSecond
      final expandedCrossFade = tester.widget<AnimatedCrossFade>(find.byType(AnimatedCrossFade));
      expect(expandedCrossFade.crossFadeState, equals(CrossFadeState.showSecond));

      // Search TextField is visible and has hint text
      final searchTextFieldFinder = find.byKey(const Key('vault_search_text_field'));
      expect(searchTextFieldFinder, findsOneWidget);
      expect(find.text('Search cards, sets, or cert numbers...'), findsOneWidget);

      // Close button is present
      final collapseButtonFinder = find.byKey(const Key('vault_search_collapse_button'));
      expect(collapseButtonFinder, findsOneWidget);

      // Enter a search query
      await tester.enterText(searchTextFieldFinder, 'The One Ring');
      await tester.pumpAndSettle();

      // Tap close button to collapse and clear
      await tester.tap(collapseButtonFinder);
      await tester.pumpAndSettle();

      // View toggles are restored to showFirst
      final collapsedCrossFade = tester.widget<AnimatedCrossFade>(find.byType(AnimatedCrossFade));
      expect(collapsedCrossFade.crossFadeState, equals(CrossFadeState.showFirst));
      expect(find.byKey(const Key('vault_view_singles_toggle')), findsOneWidget);
      expect(find.byKey(const Key('vault_view_binders_toggle')), findsOneWidget);
      expect(find.byKey(const Key('vault_search_expand_button')), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('Tapping layout switcher toggles between Grid and List layouts in Singles mode', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Switch to Singles mode (default layout is Grid)
      await tester.tap(find.byKey(const Key('vault_view_singles_toggle')));
      await tester.pumpAndSettle();

      expect(find.byKey(const PageStorageKey<String>('vault_cards_sliver_grid')), findsOneWidget);
      expect(find.byKey(const PageStorageKey<String>('vault_cards_sliver_list')), findsNothing);

      // Switch to List layout
      await tester.tap(find.byKey(const Key('vault_layout_list_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const PageStorageKey<String>('vault_cards_sliver_list')), findsOneWidget);
      expect(find.byKey(const PageStorageKey<String>('vault_cards_sliver_grid')), findsNothing);

      // Switch back to Grid layout
      await tester.tap(find.byKey(const Key('vault_layout_grid_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const PageStorageKey<String>('vault_cards_sliver_grid')), findsOneWidget);
      expect(find.byKey(const PageStorageKey<String>('vault_cards_sliver_list')), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
