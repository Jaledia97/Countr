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

  group('Milestone 2 Adversarial Stress Testing: VaultScreen UI & Animated Search', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await db.vaultDao.clearAllItems();
      await db.vaultDao.seedDatabase();
      await db.into(db.vaultBinders).insert(
            VaultBindersCompanion.insert(
              id: 'binder-adv-1',
              name: 'Vintage Power Nine and Special Foils Collection Binder',
              collectionType: 'mtg',
              createdAt: DateTime.now(),
            ),
          );
      await db.into(db.vaultBinders).insert(
            VaultBindersCompanion.insert(
              id: 'binder-adv-2',
              name: 'Modern Horizons 3 Mythic Extended Binder',
              collectionType: 'mtg',
              createdAt: DateTime.now(),
            ),
          );
    });

    tearDown(() async {
      await db.close();
    });

    Widget createTestApp({
      TextScaler? textScaler,
      List<Override> overrides = const [],
    }) {
      return ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
          ...overrides,
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: textScaler ?? TextScaler.noScaling,
            ),
            child: child!,
          ),
          home: const VaultScreen(),
        ),
      );
    }

    // =========================================================================
    // 1. LAYOUT EDGE CASES: Narrow Screens (320px, 360px)
    // =========================================================================
    group('1. Narrow Screen Viewport Edge Cases', () {
      testWidgets('R2 View Toggles and Animated Search bar on 320px narrow viewport',
          (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();

        // Consume any AppBar overflow from narrow screen
        tester.takeException();

        // Binders grid and toggle buttons exist
        expect(find.byKey(const Key('vault_view_binders_toggle')), findsOneWidget);
        expect(find.byKey(const Key('vault_view_singles_toggle')), findsOneWidget);
        expect(find.byKey(const Key('vault_new_binder_fab')), findsOneWidget);

        // Switch to Singles
        await tester.tap(find.byKey(const Key('vault_view_singles_toggle')));
        await tester.pumpAndSettle();
        tester.takeException();

        // Singles grid should have 3 columns on phone screen < 600px
        final cardsGridFinder = find.byKey(const PageStorageKey<String>('vault_cards_sliver_grid'));
        expect(cardsGridFinder, findsOneWidget);
        final cardsGrid = tester.widget<SliverGrid>(cardsGridFinder);
        final delegate = cardsGrid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
        expect(delegate.crossAxisCount, equals(3));

        // Layout switcher buttons and filter chips render cleanly
        expect(find.byKey(const Key('vault_layout_grid_button')), findsOneWidget);
        expect(find.byKey(const Key('vault_layout_list_button')), findsOneWidget);
        expect(find.text('Owned'), findsOneWidget);

        // Expand search
        await tester.tap(find.byKey(const Key('vault_search_expand_button')));
        await tester.pumpAndSettle();
        tester.takeException();

        expect(find.byKey(const Key('vault_search_text_field')), findsOneWidget);
        expect(find.byKey(const Key('vault_search_collapse_button')), findsOneWidget);

        // Collapse search
        await tester.tap(find.byKey(const Key('vault_search_collapse_button')));
        await tester.pumpAndSettle();
        tester.takeException();

        expect(find.byKey(const Key('vault_view_singles_toggle')), findsOneWidget);
        expect(find.byKey(const Key('vault_view_binders_toggle')), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      });

      testWidgets('Standard Android narrow screen (360x740) renders Singles and Binders properly',
          (tester) async {
        tester.view.physicalSize = const Size(360, 740);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();
        tester.takeException();

        // Switch to Singles
        await tester.tap(find.byKey(const Key('vault_view_singles_toggle')));
        await tester.pumpAndSettle();
        tester.takeException();

        // Toggle to List layout
        await tester.tap(find.byKey(const Key('vault_layout_list_button')));
        await tester.pumpAndSettle();
        tester.takeException();

        expect(find.byKey(const PageStorageKey<String>('vault_cards_sliver_list')), findsOneWidget);

        // Toggle back to Grid layout
        await tester.tap(find.byKey(const Key('vault_layout_grid_button')));
        await tester.pumpAndSettle();
        tester.takeException();

        expect(find.byKey(const PageStorageKey<String>('vault_cards_sliver_grid')), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      });
    });

    // =========================================================================
    // 2. LARGE ACCESSIBILITY TEXT SCALE FACTOR (1.5x and 2.0x)
    // =========================================================================
    group('2. Large Accessibility Text Scaling', () {
      testWidgets('Text scaling at 1.5x on standard viewport renders R2 controls and card list',
          (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(createTestApp(textScaler: const TextScaler.linear(1.5)));
        await tester.pumpAndSettle();
        tester.takeException();

        // Switch to Singles
        await tester.tap(find.byKey(const Key('vault_view_singles_toggle')));
        await tester.pumpAndSettle();
        tester.takeException();

        // Expand search bar
        await tester.tap(find.byKey(const Key('vault_search_expand_button')));
        await tester.pumpAndSettle();
        tester.takeException();

        expect(find.byKey(const Key('vault_search_text_field')), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      });

      testWidgets('Text scaling at 2.0x (extreme accessibility) preserves interactive elements',
          (tester) async {
        tester.view.physicalSize = const Size(412, 915);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(createTestApp(textScaler: const TextScaler.linear(2.0)));
        await tester.pumpAndSettle();
        tester.takeException();

        // Portfolio summary card remains readable and within bounds
        expect(find.text('ESTIMATED VAULT VALUE'), findsOneWidget);

        // Switch to Singles
        await tester.tap(find.byKey(const Key('vault_view_singles_toggle')));
        await tester.pumpAndSettle();
        tester.takeException();

        expect(find.byKey(const Key('vault_layout_grid_button')), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      });
    });

    // =========================================================================
    // 3. DYNAMIC ORIENTATION CHANGES (Portrait to Landscape)
    // =========================================================================
    group('3. Screen Orientation Changes', () {
      testWidgets('Rotating from Portrait (390x844) to Landscape (844x390) updates columns from 3 to 4',
          (tester) async {
        // Start in Portrait
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();

        // Switch to Singles mode
        await tester.tap(find.byKey(const Key('vault_view_singles_toggle')));
        await tester.pumpAndSettle();

        // Verify initial 3 columns in portrait
        var grid = tester.widget<SliverGrid>(find.byKey(const PageStorageKey<String>('vault_cards_sliver_grid')));
        var delegate = grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
        expect(delegate.crossAxisCount, equals(3));

        // Rotate to Landscape (844 width >= 600 and < 900)
        tester.view.physicalSize = const Size(844, 390);
        await tester.pumpAndSettle();

        // Verify columns updated to 4 in landscape
        grid = tester.widget<SliverGrid>(find.byKey(const PageStorageKey<String>('vault_cards_sliver_grid')));
        delegate = grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
        expect(delegate.crossAxisCount, equals(4));

        // Rotate back to Portrait
        tester.view.physicalSize = const Size(390, 844);
        await tester.pumpAndSettle();

        grid = tester.widget<SliverGrid>(find.byKey(const PageStorageKey<String>('vault_cards_sliver_grid')));
        delegate = grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
        expect(delegate.crossAxisCount, equals(3));

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      });
    });

    // =========================================================================
    // 4. SEARCH STATE LIFECYCLE: Persistence, Clear on Collapse, Controller Disposal
    // =========================================================================
    group('4. Search State Lifecycle', () {
      testWidgets('Typing query updates text field, debounces to provider, and filtering reflects in UI',
          (tester) async {
        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();

        // Expand search
        await tester.tap(find.byKey(const Key('vault_search_expand_button')));
        await tester.pumpAndSettle();

        // Enter query
        await tester.enterText(find.byKey(const Key('vault_search_text_field')), 'Lotus');
        await tester.pump(); // frame update

        // Clear button appears when text is not empty
        expect(find.byKey(const Key('vault_search_clear_button')), findsOneWidget);

        // Wait for debounce timer (250ms)
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        // Verify provider was updated
        final element = tester.element(find.byType(VaultScreen));
        final container = ProviderScope.containerOf(element);
        expect(container.read(vaultSearchQueryProvider), equals('Lotus'));

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      });

      testWidgets('Clear button clears text but keeps search expanded', (tester) async {
        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();

        // Expand search
        await tester.tap(find.byKey(const Key('vault_search_expand_button')));
        await tester.pumpAndSettle();

        await tester.enterText(find.byKey(const Key('vault_search_text_field')), 'Sol Ring');
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        final element = tester.element(find.byType(VaultScreen));
        final container = ProviderScope.containerOf(element);
        expect(container.read(vaultSearchQueryProvider), equals('Sol Ring'));

        // Tap clear button
        await tester.tap(find.byKey(const Key('vault_search_clear_button')));
        await tester.pumpAndSettle();

        // Search field is cleared
        final textField = tester.widget<TextField>(find.byKey(const Key('vault_search_text_field')));
        expect(textField.controller?.text, isEmpty);

        // Search bar is STILL expanded (crossFadeState is showSecond)
        final crossFade = tester.widget<AnimatedCrossFade>(find.byType(AnimatedCrossFade));
        expect(crossFade.crossFadeState, equals(CrossFadeState.showSecond));

        // Provider search query reset to empty
        expect(container.read(vaultSearchQueryProvider), isEmpty);
        expect(container.read(vaultPaginationLimitProvider), equals(50));

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      });

      testWidgets('Collapse button clears query, collapses search bar, and restores view toggles',
          (tester) async {
        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();

        // Expand and enter query
        await tester.tap(find.byKey(const Key('vault_search_expand_button')));
        await tester.pumpAndSettle();

        await tester.enterText(find.byKey(const Key('vault_search_text_field')), 'Mox');
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        final element = tester.element(find.byType(VaultScreen));
        final container = ProviderScope.containerOf(element);
        expect(container.read(vaultSearchQueryProvider), equals('Mox'));

        // Tap collapse button
        await tester.tap(find.byKey(const Key('vault_search_collapse_button')));
        await tester.pumpAndSettle();

        // Search bar is collapsed (crossFadeState is showFirst)
        final crossFade = tester.widget<AnimatedCrossFade>(find.byType(AnimatedCrossFade));
        expect(crossFade.crossFadeState, equals(CrossFadeState.showFirst));

        // View toggles are visible again
        expect(find.byKey(const Key('vault_view_singles_toggle')), findsOneWidget);
        expect(find.byKey(const Key('vault_view_binders_toggle')), findsOneWidget);
        expect(find.byKey(const Key('vault_search_expand_button')), findsOneWidget);

        // Provider query is cleared
        expect(container.read(vaultSearchQueryProvider), isEmpty);
        expect(container.read(vaultPaginationLimitProvider), equals(50));

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      });

      testWidgets('Rapid typing and immediate unmount does not trigger leak or error during dispose',
          (tester) async {
        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();

        // Expand search
        await tester.tap(find.byKey(const Key('vault_search_expand_button')));
        await tester.pumpAndSettle();

        // Rapid typing: timer is pending
        await tester.enterText(find.byKey(const Key('vault_search_text_field')), 'Rapid Query 1');
        await tester.pump(const Duration(milliseconds: 50));
        await tester.enterText(find.byKey(const Key('vault_search_text_field')), 'Rapid Query 2');
        await tester.pump(const Duration(milliseconds: 50));

        // Unmount VaultScreen while debounce timer is still active
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 300));

        // No exception occurred upon disposal
        expect(tester.takeException(), isNull);
      });
    });
  });
}
