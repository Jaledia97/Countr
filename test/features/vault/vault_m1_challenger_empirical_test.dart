import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/providers/mtg_filter_state.dart';
import 'package:countr/features/vault/presentation/screens/vault_screen.dart';
import 'package:countr/features/vault/presentation/widgets/mtg_filter_sheet.dart';
import 'package:countr/features/vault/presentation/widgets/vault_import_bottom_sheet.dart';
import 'package:countr/features/command_center/presentation/widgets/morphing_command_center.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Milestone 1 Challenger Empirical Stress Suite', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await db.vaultDao.clearAllItems();
      await db.vaultDao.seedDatabase();
    });

    tearDown(() async {
      await db.close();
    });

    Widget createTestApp({
      List<Override> overrides = const [],
      double textScaleFactor = 1.0,
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
              textScaler: TextScaler.linear(textScaleFactor),
            ),
            child: child!,
          ),
          home: const VaultScreen(),
        ),
      );
    }

    // =========================================================================
    // 1. Search Bar UX: Strict 2-Step Single "X" Button Interaction & State
    // =========================================================================
    group('1. Search Bar UX: 2-Step Single "X" Button Interaction', () {
      testWidgets('Collapsed initial state: crossFade shows view toggles, expand trigger is present', (tester) async {
        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();

        // CrossFade is showFirst
        final crossFade = tester.widget<AnimatedCrossFade>(find.byType(AnimatedCrossFade));
        expect(crossFade.crossFadeState, equals(CrossFadeState.showFirst));

        // View toggles are visible in collapsed state
        expect(find.byKey(const Key('vault_view_singles_toggle')), findsOneWidget);
        expect(find.byKey(const Key('vault_view_binders_toggle')), findsOneWidget);

        // Expand trigger is present
        expect(find.byKey(const Key('vault_search_expand_button')), findsOneWidget);

        // Clear button does not exist in any state when search controller is empty
        expect(find.byKey(const Key('vault_search_clear_button')), findsNothing);
      });

      testWidgets('Step 1 & Step 2 verification: Typed text gives exactly 1 clear button, empty text gives 1 collapse button', (tester) async {
        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();

        // 1. Expand the search bar
        await tester.tap(find.byKey(const Key('vault_search_expand_button')));
        await tester.pumpAndSettle();

        final crossFade = tester.widget<AnimatedCrossFade>(find.byType(AnimatedCrossFade));
        expect(crossFade.crossFadeState, equals(CrossFadeState.showSecond));

        final textFieldFinder = find.byKey(const Key('vault_search_text_field'));
        expect(textFieldFinder, findsOneWidget);

        // When text is empty:
        // Key MUST be vault_search_collapse_button
        expect(find.byKey(const Key('vault_search_collapse_button')), findsOneWidget);
        expect(find.byKey(const Key('vault_search_clear_button')), findsNothing);

        // Count total 'X' buttons (Icons.close) in the entire search bar: EXACTLY ONE
        expect(find.byIcon(Icons.close), findsOneWidget);

        // 2. Enter text
        await tester.enterText(textFieldFinder, 'Black Lotus');
        await tester.pump(); // Trigger setState from onChanged

        // Now text is typed:
        // Key MUST be vault_search_clear_button
        expect(find.byKey(const Key('vault_search_clear_button')), findsOneWidget);
        expect(find.byKey(const Key('vault_search_collapse_button')), findsNothing);

        // Still EXACTLY one 'X' button in the tree
        expect(find.byIcon(Icons.close), findsOneWidget);

        // 3. STEP 1 TAP: Tap clear button
        await tester.tap(find.byKey(const Key('vault_search_clear_button')));
        await tester.pump();

        // Assert 1: Text in controller is cleared
        final textField = tester.widget<TextField>(textFieldFinder);
        expect(textField.controller?.text, isEmpty);

        // Assert 2: Search field REMAINS OPEN and expanded (crossFade is still showSecond!)
        final openCrossFade = tester.widget<AnimatedCrossFade>(find.byType(AnimatedCrossFade));
        expect(openCrossFade.crossFadeState, equals(CrossFadeState.showSecond));

        // Assert 3: Button immediately transitioned to vault_search_collapse_button
        expect(find.byKey(const Key('vault_search_collapse_button')), findsOneWidget);
        expect(find.byKey(const Key('vault_search_clear_button')), findsNothing);
        expect(find.byIcon(Icons.close), findsOneWidget);

        // 4. STEP 2 TAP: Tap collapse button
        await tester.tap(find.byKey(const Key('vault_search_collapse_button')));
        await tester.pumpAndSettle();

        // Assert 4: Search field collapses back to view toggles
        final collapsedCrossFade = tester.widget<AnimatedCrossFade>(find.byType(AnimatedCrossFade));
        expect(collapsedCrossFade.crossFadeState, equals(CrossFadeState.showFirst));
        expect(find.byKey(const Key('vault_view_singles_toggle')), findsOneWidget);
        expect(find.byKey(const Key('vault_view_binders_toggle')), findsOneWidget);
        expect(find.byKey(const Key('vault_search_expand_button')), findsOneWidget);
        expect(find.byKey(const Key('vault_search_clear_button')), findsNothing);
      });

      testWidgets('Stress test: Rapid alternating expand -> type -> clear -> collapse cycles (10 iterations)', (tester) async {
        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();

        for (int i = 0; i < 10; i++) {
          // 1. Expand
          await tester.tap(find.byKey(const Key('vault_search_expand_button')));
          await tester.pumpAndSettle();

          expect(tester.widget<AnimatedCrossFade>(find.byType(AnimatedCrossFade)).crossFadeState, equals(CrossFadeState.showSecond));
          expect(find.byKey(const Key('vault_search_collapse_button')), findsOneWidget);
          expect(find.byKey(const Key('vault_search_clear_button')), findsNothing);

          // 2. Type
          await tester.enterText(find.byKey(const Key('vault_search_text_field')), 'Query $i');
          await tester.pump();

          expect(find.byKey(const Key('vault_search_clear_button')), findsOneWidget);
          expect(find.byKey(const Key('vault_search_collapse_button')), findsNothing);

          // 3. Clear (Search field stays open!)
          await tester.tap(find.byKey(const Key('vault_search_clear_button')));
          await tester.pump();

          expect(tester.widget<AnimatedCrossFade>(find.byType(AnimatedCrossFade)).crossFadeState, equals(CrossFadeState.showSecond));
          expect(find.byKey(const Key('vault_search_collapse_button')), findsOneWidget);
          expect(find.byKey(const Key('vault_search_clear_button')), findsNothing);

          // 4. Collapse
          await tester.tap(find.byKey(const Key('vault_search_collapse_button')));
          await tester.pumpAndSettle();

          expect(tester.widget<AnimatedCrossFade>(find.byType(AnimatedCrossFade)).crossFadeState, equals(CrossFadeState.showFirst));
          expect(find.byKey(const Key('vault_search_expand_button')), findsOneWidget);
        }
      });

      testWidgets('Debounce cancellation: Clearing immediately prevents pending debounce from overwriting cleared state', (tester) async {
        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(db.vaultDao),
            activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
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

        // Expand and enter text
        await tester.tap(find.byKey(const Key('vault_search_expand_button')));
        await tester.pumpAndSettle();

        await tester.enterText(find.byKey(const Key('vault_search_text_field')), 'Instant Lotus');
        // Only pump 50ms (before the 250ms debounce fires)
        await tester.pump(const Duration(milliseconds: 50));

        // Immediately tap clear
        await tester.tap(find.byKey(const Key('vault_search_clear_button')));
        await tester.pump();

        // Advance past the 250ms debounce duration
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        // Query in provider MUST be empty, not 'Instant Lotus'
        expect(container.read(vaultSearchQueryProvider), equals(''));
      });

      testWidgets('Direct collapse when empty: Single tap on empty search collapses immediately', (tester) async {
        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();

        // Expand
        await tester.tap(find.byKey(const Key('vault_search_expand_button')));
        await tester.pumpAndSettle();
        expect(tester.widget<AnimatedCrossFade>(find.byType(AnimatedCrossFade)).crossFadeState, equals(CrossFadeState.showSecond));

        // Without entering any text, tap the collapse button
        await tester.tap(find.byKey(const Key('vault_search_collapse_button')));
        await tester.pumpAndSettle();

        // Search collapses directly
        expect(tester.widget<AnimatedCrossFade>(find.byType(AnimatedCrossFade)).crossFadeState, equals(CrossFadeState.showFirst));
        expect(find.byKey(const Key('vault_search_expand_button')), findsOneWidget);
      });
    });

    // =========================================================================
    // 2. MTG Filter Button Persistence & Accessibility
    // =========================================================================
    group('2. MTG Filter Button Persistence & Exclusivity', () {
      testWidgets('vault_mtg_filter_button is present and operable in collapsed state', (tester) async {
        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();

        // Verified collapsed
        expect(find.byKey(const Key('vault_search_expand_button')), findsOneWidget);

        // Filter button is present
        final filterBtn = find.byKey(const Key('vault_mtg_filter_button'));
        expect(filterBtn, findsOneWidget);

        // Tap filter button to open filter sheet
        await tester.tap(filterBtn);
        await tester.pumpAndSettle();

        // MTG Filter Sheet modal is rendered
        expect(find.byType(MtgFilterSheet), findsOneWidget);
        expect(find.text('Filter Cards'), findsWidgets);

        // Close modal using specific filter sheet close button
        await tester.tap(find.byKey(const Key('mtg_filter_close_button')));
        await tester.pumpAndSettle();
        expect(find.byType(MtgFilterSheet), findsNothing);
      });

      testWidgets('vault_mtg_filter_button remains accessible and operable in expanded state with empty text', (tester) async {
        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();

        // Expand search
        await tester.tap(find.byKey(const Key('vault_search_expand_button')));
        await tester.pumpAndSettle();

        // Filter button is STILL present outside the search field on the right
        final filterBtn = find.byKey(const Key('vault_mtg_filter_button'));
        expect(filterBtn, findsOneWidget);

        // Tap filter button while search is expanded
        await tester.tap(filterBtn);
        await tester.pumpAndSettle();

        // Filter modal opens properly
        expect(find.byType(MtgFilterSheet), findsOneWidget);

        // Close modal
        await tester.tap(find.byKey(const Key('mtg_filter_close_button')));
        await tester.pumpAndSettle();
        expect(find.byType(MtgFilterSheet), findsNothing);

        // Search bar is still expanded
        expect(tester.widget<AnimatedCrossFade>(find.byType(AnimatedCrossFade)).crossFadeState, equals(CrossFadeState.showSecond));
      });

      testWidgets('vault_mtg_filter_button remains accessible and operable in expanded state with active search query', (tester) async {
        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();

        // Expand and enter search text
        await tester.tap(find.byKey(const Key('vault_search_expand_button')));
        await tester.pumpAndSettle();

        await tester.enterText(find.byKey(const Key('vault_search_text_field')), 'Sol Ring');
        await tester.pumpAndSettle();

        // Filter button is still present on the right
        final filterBtn = find.byKey(const Key('vault_mtg_filter_button'));
        expect(filterBtn, findsOneWidget);

        // Tap filter button
        await tester.tap(filterBtn);
        await tester.pumpAndSettle();

        expect(find.byType(MtgFilterSheet), findsOneWidget);

        // Close modal
        await tester.tap(find.byKey(const Key('mtg_filter_close_button')));
        await tester.pumpAndSettle();
        expect(find.byType(MtgFilterSheet), findsNothing);
      });

      testWidgets('No redundant internal filter button exists inside search bar', (tester) async {
        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();

        // Expand search
        await tester.tap(find.byKey(const Key('vault_search_expand_button')));
        await tester.pumpAndSettle();

        // Verify redundant key 'vault_mtg_filter_button_expanded' is completely removed
        expect(find.byKey(const Key('vault_mtg_filter_button_expanded')), findsNothing);

        // Exactly one filter button exists across the entire screen
        expect(find.byKey(const Key('vault_mtg_filter_button')), findsOneWidget);
      });

      testWidgets('Filter badge dynamically reflects active filter count on vault_mtg_filter_button', (tester) async {
        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(db.vaultDao),
            activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
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

        // Initially no filters active
        expect(find.byType(Badge), findsOneWidget);
        Badge badge = tester.widget<Badge>(find.byType(Badge));
        expect(badge.isLabelVisible, isFalse);

        // Activate 2 filter dimensions (colors and rarities)
        container.read(mtgFilterProvider.notifier).update(
              (s) => s.copyWith(
                colors: {'W', 'U'},
                rarities: {'mythic'},
              ),
            );
        await tester.pumpAndSettle();

        badge = tester.widget<Badge>(find.byType(Badge));
        expect(badge.isLabelVisible, isTrue);
        expect(find.text('2'), findsOneWidget);
      });
    });

    // =========================================================================
    // 3. Vault Header & Action Streamlining: Add Button Removal & Import Button
    // =========================================================================
    group('3. Vault Header & Action Streamlining', () {
      testWidgets('vault_add_item_button is absent from the entire widget tree', (tester) async {
        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('vault_add_item_button')), findsNothing);
      });

      testWidgets('vault_import_button is present, correctly labeled, and triggers import modal', (tester) async {
        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();

        final importBtn = find.byKey(const Key('vault_import_button'));
        expect(importBtn, findsOneWidget);

        // Verify label is streamlined to 'Import' (not 'Import +')
        expect(find.text('Import'), findsOneWidget);
        expect(find.text('Import +'), findsNothing);

        // Tap import button
        await tester.tap(importBtn);
        await tester.pumpAndSettle();

        // Verify VaultImportBottomSheet modal is presented
        expect(find.byType(VaultImportBottomSheet), findsOneWidget);
        expect(find.text('Import Cards to Vault'), findsOneWidget);

        // Dismiss modal
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();
        expect(find.byType(VaultImportBottomSheet), findsNothing);
      });

      testWidgets('AppBar.actions is completely empty: privacy mode, hydration, db verification, and redundant filter buttons are removed', (tester) async {
        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();

        final appBarFinder = find.byType(AppBar);
        expect(appBarFinder, findsOneWidget);
        final appBar = tester.widget<AppBar>(appBarFinder);
        expect(appBar.actions, isEmpty);

        expect(find.byKey(const Key('vault_privacy_mode_button')), findsNothing);
        expect(find.byKey(const Key('vault_appbar_filter_button')), findsNothing);
        expect(find.byIcon(Icons.flash_on_rounded), findsNothing);
        expect(find.byIcon(Icons.sync_rounded), findsNothing);
      });

      testWidgets('Relocated tools exist in MorphingCommandCenter developer card', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              vaultDaoProvider.overrideWithValue(db.vaultDao),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: MorphingCommandCenter(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Scroll down to developer card if needed
        final devCard = find.byKey(const Key('command_center_developer_tools_card'));
        await tester.scrollUntilVisible(devCard, 300);
        expect(devCard, findsOneWidget);

        // Hydration button & DB verification button exist in Command Center
        expect(find.byKey(const Key('command_center_hydrate_button')), findsOneWidget);
        expect(find.byKey(const Key('command_center_verify_database_button')), findsOneWidget);
        expect(find.text('TEST & DEVELOPER TOOLS'), findsOneWidget);
      });
    });

    // =========================================================================
    // 4. Viewport & Accessibility Stress Testing
    // =========================================================================
    group('4. Viewport & Accessibility Stress Testing', () {
      testWidgets('320px narrow screen viewport handles search expand/collapse without throwing RenderFlex error', (tester) async {
        tester.view.physicalSize = const Size(320, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(createTestApp());
        await tester.pumpAndSettle();

        // Catch any exceptions
        final exception = tester.takeException();
        expect(exception, isNull);

        // Expand search
        await tester.tap(find.byKey(const Key('vault_search_expand_button')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        expect(find.byKey(const Key('vault_search_text_field')), findsOneWidget);
        expect(find.byKey(const Key('vault_mtg_filter_button')), findsOneWidget);

        // Type query
        await tester.enterText(find.byKey(const Key('vault_search_text_field')), 'Narrow Query');
        await tester.pump();
        expect(tester.takeException(), isNull);

        // Clear query
        await tester.tap(find.byKey(const Key('vault_search_clear_button')));
        await tester.pump();
        expect(tester.takeException(), isNull);

        // Collapse
        await tester.tap(find.byKey(const Key('vault_search_collapse_button')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('Large accessibility text scaling (1.5x) preserves layout without error', (tester) async {
        await tester.pumpWidget(createTestApp(textScaleFactor: 1.5));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        // Expand search
        await tester.tap(find.byKey(const Key('vault_search_expand_button')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        expect(find.byKey(const Key('vault_search_text_field')), findsOneWidget);
        expect(find.byKey(const Key('vault_mtg_filter_button')), findsOneWidget);

        // Collapse
        await tester.tap(find.byKey(const Key('vault_search_collapse_button')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    });
  });
}
