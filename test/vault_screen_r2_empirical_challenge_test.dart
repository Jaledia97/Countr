import 'package:drift/drift.dart' hide isNull;
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

  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.vaultDao.clearAllItems();
    await db.vaultDao.seedDatabase();

    // Insert extra test binder with long name
    await db.into(db.vaultBinders).insert(
          VaultBindersCompanion.insert(
            id: 'binder-alpha',
            name: 'Alpha Collection Extremely Long Binder Name For Stress Testing Overflow',
            collectionType: 'mtg',
            createdAt: DateTime.now(),
          ),
        );

    // Insert an unowned catalog card (quantity == 0) with matching name
    await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'item-unowned-ring',
            collectionType: 'mtg',
            name: 'The One Ring (Catalog Unowned Reference)',
            setOrSeries: 'Tales of Middle-earth Special Edition',
            imageUrl: '',
            acquiredPrice: 0.0,
            acquiredDate: DateTime.now(),
            quantity: const Value(0), // UNOWNED
            condition: 'NM',
            isGraded: const Value(false),
            currentMarketPrice: 50.00,
            lastPriceUpdate: DateTime.now(),
            dynamicData: '{}',
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildVaultApp({
    double textScale = 1.0,
    Size viewport = const Size(390, 844),
    List<Override> overrides = const [],
    ProviderContainer? container,
  }) {
    final defaultOverrides = [
      appDatabaseProvider.overrideWithValue(db),
      vaultDaoProvider.overrideWithValue(db.vaultDao),
      activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
      ...overrides,
    ];

    Widget app = MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: viewport,
          textScaler: TextScaler.linear(textScale),
        ),
        child: const VaultScreen(),
      ),
    );

    if (container != null) {
      return UncontrolledProviderScope(
        container: container,
        child: app,
      );
    }

    return ProviderScope(
      key: UniqueKey(),
      overrides: defaultOverrides,
      child: app,
    );
  }

  // ===========================================================================
  // 1. ACCESSIBILITY & SEMANTICS AUDIT
  // ===========================================================================
  group('1. Accessibility & Semantics Audit', () {
    testWidgets('1.1 Audit screen reader semantics for search expand/collapse/clear buttons', (tester) async {
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(buildVaultApp());
        await tester.pumpAndSettle();

        // 1.1.1 Collapsed search expand button
        final expandButton = find.byKey(const Key('vault_search_expand_button'));
        expect(expandButton, findsOneWidget);
        final expandSemantics = tester.getSemantics(expandButton);
        // IconButton with tooltip provides tooltip in semantics
        expect(expandSemantics.tooltip, equals('Search Vault'));

        // 1.1.2 Expand search
        await tester.tap(expandButton);
        await tester.pumpAndSettle();

        // 1.1.3 Collapse button
        final collapseButton = find.byKey(const Key('vault_search_collapse_button'));
        expect(collapseButton, findsOneWidget);
        final collapseSemantics = tester.getSemantics(collapseButton);
        expect(collapseSemantics.tooltip, equals('Close search'));

        // 1.1.4 Type query to reveal clear button
        await tester.enterText(find.byKey(const Key('vault_search_text_field')), 'Ring');
        await tester.pumpAndSettle();

        final clearButton = find.byKey(const Key('vault_search_clear_button'));
        expect(clearButton, findsOneWidget);
        final clearSemantics = tester.getSemantics(clearButton);
        expect(clearSemantics.tooltip, equals('Clear query'));
      } finally {
        handle.dispose();
      }

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('1.2 Audit screen reader semantics for icon-only layout switches and view toggles', (tester) async {
      final handle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(buildVaultApp());
        await tester.pumpAndSettle();

        // Switch to Singles view where layout switcher is rendered
        await tester.tap(find.byKey(const Key('vault_view_singles_toggle')));
        await tester.pumpAndSettle();

        // View toggles: Text children ensure screen reader can announce 'Singles' and 'Binders'
        final singlesToggle = find.byKey(const Key('vault_view_singles_toggle'));
        final bindersToggle = find.byKey(const Key('vault_view_binders_toggle'));
        expect(tester.getSemantics(singlesToggle).label, contains('Singles'));
        expect(tester.getSemantics(bindersToggle).label, contains('Binders'));

        // Icon-only layout switchers
        final listLayoutButton = find.byKey(const Key('vault_layout_list_button'));
        final gridLayoutButton = find.byKey(const Key('vault_layout_grid_button'));
        expect(listLayoutButton, findsOneWidget);
        expect(gridLayoutButton, findsOneWidget);

        final listSemantics = tester.getSemantics(listLayoutButton);
        final gridSemantics = tester.getSemantics(gridLayoutButton);

        debugPrint('Layout List Button Semantics: label="${listSemantics.label}", tooltip="${listSemantics.tooltip}"');
        debugPrint('Layout Grid Button Semantics: label="${gridSemantics.label}", tooltip="${gridSemantics.tooltip}"');

        // Check whether icon-only layout switcher buttons have accessible descriptions
        final hasListAccessibility = (listSemantics.label.isNotEmpty) ||
            (listSemantics.tooltip.isNotEmpty);
        final hasGridAccessibility = (gridSemantics.label.isNotEmpty) ||
            (gridSemantics.tooltip.isNotEmpty);

        debugPrint('Has List Accessibility: $hasListAccessibility, Has Grid Accessibility: $hasGridAccessibility');
      } finally {
        handle.dispose();
      }

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });

  // ===========================================================================
  // 2. ACCESSIBILITY TEXT SCALING (textScaleFactor: 1.5 and 2.0)
  // ===========================================================================
  group('2. Accessibility Text Scaling Stress Test (textScaleFactor 1.5 & 2.0)', () {
    testWidgets('2.1 Binders View under 1.5x and 2.0x text scaling on phone viewports (360x640, 390x844, 320x568)', (tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      for (final scale in [1.5, 2.0]) {
        for (final width in [360.0, 390.0, 320.0]) {
          tester.view.physicalSize = Size(width, 800);
          tester.view.devicePixelRatio = 1.0;

          await tester.pumpWidget(
            buildVaultApp(
              textScale: scale,
              viewport: Size(width, 800),
              overrides: [
                vaultViewModeProvider.overrideWith((ref) => VaultViewMode.binders),
              ],
            ),
          );
          await tester.pumpAndSettle();

          // Verify Binders grid rendered
          expect(find.byKey(const PageStorageKey<String>('vault_binders_sliver_grid')), findsOneWidget);

          // Assert zero RenderFlex overflows
          expect(
            tester.takeException(),
            isNull,
            reason: 'RenderFlex overflow detected in Binders view at width $width px and textScale $scale',
          );
        }
      }

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('2.2 Singles View (Grid 3-col & List) under 1.5x and 2.0x text scaling', (tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      for (final scale in [1.5, 2.0]) {
        for (final width in [360.0, 390.0, 320.0]) {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1.0;

          // 2.2.1 Singles Grid (3 columns on phone)
          await tester.pumpWidget(
            buildVaultApp(
              textScale: scale,
              viewport: Size(width, 844),
              overrides: [
                vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
                cardDisplayLayoutProvider.overrideWith((ref) => CardDisplayLayout.grid),
              ],
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byKey(const PageStorageKey<String>('vault_cards_sliver_grid')), findsOneWidget);
          expect(
            tester.takeException(),
            isNull,
            reason: 'RenderFlex overflow in Singles Grid at scale $scale, width $width px',
          );

          // 2.2.2 Singles List
          await tester.pumpWidget(
            buildVaultApp(
              textScale: scale,
              viewport: Size(width, 844),
              overrides: [
                vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
                cardDisplayLayoutProvider.overrideWith((ref) => CardDisplayLayout.list),
              ],
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byKey(const PageStorageKey<String>('vault_cards_sliver_list')), findsOneWidget);
          expect(
            tester.takeException(),
            isNull,
            reason: 'RenderFlex overflow in Singles List at scale $scale, width $width px',
          );
        }
      }

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('2.3 Controls Bar & Search Bar expanded under 1.5x and 2.0x text scaling', (tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      for (final scale in [1.5, 2.0]) {
        for (final width in [320.0, 360.0, 390.0]) {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1.0;

          await tester.pumpWidget(
            buildVaultApp(
              textScale: scale,
              viewport: Size(width, 844),
              overrides: [
                vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
              ],
            ),
          );
          await tester.pumpAndSettle();

          // Collapsed state: FittedBox scales down cleanly
          expect(find.byKey(const Key('vault_view_singles_toggle')), findsOneWidget);
          expect(find.byKey(const Key('vault_search_expand_button')), findsOneWidget);
          expect(
            tester.takeException(),
            isNull,
            reason: 'RenderFlex overflow in collapsed controls bar at scale $scale, width $width',
          );

          // Tap expand search
          await tester.tap(find.byKey(const Key('vault_search_expand_button')));
          await tester.pumpAndSettle();

          // Expanded state: Full width search bar
          expect(find.byKey(const Key('vault_search_text_field')), findsOneWidget);
          expect(
            tester.takeException(),
            isNull,
            reason: 'RenderFlex overflow in expanded search bar at scale $scale, width $width',
          );

          // Tap collapse
          await tester.tap(find.byKey(const Key('vault_search_collapse_button')));
          await tester.pumpAndSettle();
        }
      }

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });

  // ===========================================================================
  // 3. FILTER INTERACTION: "OWNED" SCOPING & NON-COLLISION WITH SEARCH
  // ===========================================================================
  group('3. Filter Interaction & Search Scoping Stress Test', () {
    testWidgets('3.1 "Owned" filter properly scopes cards to quantity > 0 and does not collide with search query',
        (tester) async {
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

      await tester.pumpWidget(buildVaultApp(container: container));
      await tester.pumpAndSettle();

      // 3.1.1 Verify initial state: "Owned" filter is active by default (index 0)
      final ownedChipFinder = find.byKey(const Key('vault_filter_chip_owned'));
      expect(ownedChipFinder, findsOneWidget);
      final ownedChip = tester.widget<FilterChip>(ownedChipFinder);
      expect(ownedChip.selected, isTrue);

      // Verify the owned card is visible, but the unowned card is NOT visible
      expect(find.text('The One Ring (Serialized #007/100)'), findsOneWidget);
      expect(find.text('The One Ring (Catalog Unowned Reference)'), findsNothing);

      // 3.1.2 Expand search and enter query "The One Ring"
      await tester.tap(find.byKey(const Key('vault_search_expand_button')));
      await tester.pumpAndSettle();

      final searchFieldFinder = find.byKey(const Key('vault_search_text_field'));
      await tester.enterText(searchFieldFinder, 'The One Ring');
      await tester.pump(const Duration(milliseconds: 300)); // allow debounce
      await tester.pumpAndSettle();

      // Verify search query updated provider
      expect(container.read(vaultSearchQueryProvider), equals('The One Ring'));

      // In Owned mode with search "The One Ring": ONLY the owned card should be displayed!
      expect(find.text('The One Ring (Serialized #007/100)'), findsOneWidget);
      expect(find.text('The One Ring (Catalog Unowned Reference)'), findsNothing);

      // 3.1.3 Switch filter to "Catalog (Ref)" while search query is active
      final catalogChipFinder = find.byKey(const Key('vault_filter_chip_catalog_(ref)'));
      expect(catalogChipFinder, findsOneWidget);
      await tester.tap(catalogChipFinder);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Now both or the unowned catalog reference card must appear in Catalog mode
      expect(container.read(vaultShowCatalogProvider), isTrue);
      expect(find.text('The One Ring (Catalog Unowned Reference)'), findsOneWidget);

      // 3.1.4 Switch BACK to "Owned" filter while search query remains active
      await tester.tap(ownedChipFinder);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(container.read(vaultShowCatalogProvider), isFalse);

      // Scoping check: Unowned reference card MUST disappear immediately, owned card remains
      expect(find.text('The One Ring (Serialized #007/100)'), findsOneWidget);
      expect(find.text('The One Ring (Catalog Unowned Reference)'), findsNothing);

      // Verify search text was NOT wiped or collided by selecting "Owned" filter
      final currentSearchField = tester.widget<TextField>(searchFieldFinder);
      expect(currentSearchField.controller?.text, equals('The One Ring'));

      // 3.1.5 Clear search text while staying on "Owned" filter
      final clearBtn = find.byKey(const Key('vault_search_clear_button'));
      expect(clearBtn, findsOneWidget);
      await tester.tap(clearBtn);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Search is cleared, but "Owned" filter is STILL selected
      final postClearOwnedChip = tester.widget<FilterChip>(find.byKey(const Key('vault_filter_chip_owned')));
      expect(postClearOwnedChip.selected, isTrue);

      // Unowned card is still excluded
      expect(find.text('The One Ring (Catalog Unowned Reference)'), findsNothing);

      // 3.1.6 Enter search query for something that exists ONLY as unowned catalog item
      await tester.enterText(searchFieldFinder, 'Catalog Unowned');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Owned mode must show empty state, NOT leak the unowned card
      expect(find.text('The One Ring (Catalog Unowned Reference)'), findsNothing);
      expect(find.text('No owned items in Magic: The Gathering'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
