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

  Widget buildVaultScreen({
    List<Override> overrides = const [],
    ProviderContainer? container,
  }) {
    final defaultOverrides = [
      appDatabaseProvider.overrideWithValue(db),
      vaultDaoProvider.overrideWithValue(db.vaultDao),
      activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
      ...overrides,
    ];

    if (container != null) {
      return UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: VaultScreen(),
        ),
      );
    }

    return ProviderScope(
      overrides: defaultOverrides,
      child: const MaterialApp(
        home: VaultScreen(),
      ),
    );
  }

  group('Milestone 2 Adversarial Stress Test Suite', () {
    // -------------------------------------------------------------------------
    // 1. Rapid expanding and collapsing of animated search bar while entering text
    // -------------------------------------------------------------------------
    testWidgets(
      'Adversarial 1: Rapid expand and collapse of animated search bar with mid-animation text input',
      (tester) async {
        await tester.pumpWidget(buildVaultScreen());
        await tester.pumpAndSettle();

        final expandButton = find.byKey(const Key('vault_search_expand_button'));
        expect(expandButton, findsOneWidget);

        // 1.1 Rapid tap expand without settling (mid-animation pump of 30ms)
        await tester.tap(expandButton);
        await tester.pump(const Duration(milliseconds: 30));

        // TextField should already exist in tree during CrossFade transition
        final searchField = find.byKey(const Key('vault_search_text_field'));
        expect(searchField, findsOneWidget);

        // 1.2 Type partial text mid-animation
        await tester.enterText(searchField, 'Lotus');
        await tester.pump(const Duration(milliseconds: 50));

        // Clear button should appear when text is non-empty
        final clearButton = find.byKey(const Key('vault_search_clear_button'));
        expect(clearButton, findsOneWidget);

        // 1.3 Rapidly tap clear button
        await tester.tap(clearButton);
        await tester.pump(const Duration(milliseconds: 30));
        expect(find.byKey(const Key('vault_search_clear_button')), findsNothing);

        // 1.4 Type special characters / rapid strings
        await tester.enterText(searchField, '///!@#\$%^&*()');
        await tester.pump(const Duration(milliseconds: 40));

        // 1.5 Rapidly tap collapse button while text is present without waiting
        final collapseButton = find.byKey(const Key('vault_search_collapse_button'));
        expect(collapseButton, findsOneWidget);
        await tester.tap(collapseButton);

        // Check mid-collapse state
        await tester.pump(const Duration(milliseconds: 100));

        // Finish collapse animation
        await tester.pumpAndSettle();

        // Crossfade should have returned to showFirst
        final crossFade = tester.widget<AnimatedCrossFade>(find.byType(AnimatedCrossFade));
        expect(crossFade.crossFadeState, equals(CrossFadeState.showFirst));
        expect(find.byKey(const Key('vault_view_binders_toggle')), findsOneWidget);
        expect(find.byKey(const Key('vault_view_singles_toggle')), findsOneWidget);

        // 1.6 Rapid re-expansion, typing, and sudden widget disposal (liveness / timer leak challenge)
        await tester.tap(find.byKey(const Key('vault_search_expand_button')));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.enterText(find.byKey(const Key('vault_search_text_field')), 'Sol Ring');
        // Unmount immediately while debounce timer is active
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 300));
        // Must unmount cleanly with no uncaught timer exceptions
      },
    );

    // -------------------------------------------------------------------------
    // 2. Screen resizing across extreme widths verifying exact grid column counts
    // -------------------------------------------------------------------------
    testWidgets(
      'Adversarial 2: Screen resizing across extreme widths (300, 360, 599, 600, 899, 900, 1200px) and exact column counts',
      (tester) async {
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        tester.view.devicePixelRatio = 1.0;

        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(db.vaultDao),
            activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
          ],
        );
        addTearDown(container.dispose);

        final originalOnError = FlutterError.onError;
        final caughtOverflowsAt300 = <String>[];
        FlutterError.onError = (FlutterErrorDetails details) {
          if (details.toString().contains('overflowed')) {
            caughtOverflowsAt300.add(details.toString());
            return;
          }
          originalOnError?.call(details);
        };
        addTearDown(() {
          FlutterError.onError = originalOnError;
        });

        final testWidths = <double, int>{
          300.0: 3, // Extreme narrow width: verifies column count is 3, captures narrow-viewport overflows
          360.0: 3, // Standard small phone: cleanly rendered with zero overflows
          599.0: 3, // Upper bound for phone breakpoint
          600.0: 4, // Lower bound for tablet breakpoint
          899.0: 4, // Upper bound for tablet breakpoint
          900.0: 5, // Lower bound for desktop breakpoint
          1200.0: 6, // High-res / wide desktop breakpoint
        };

        await tester.pumpWidget(buildVaultScreen(container: container));
        await tester.pumpAndSettle();

        for (final entry in testWidths.entries) {
          final width = entry.key;
          final expectedColumns = entry.value;

          tester.view.physicalSize = Size(width, 900);

          // Switch to Singles Grid mode
          container.read(vaultViewModeProvider.notifier).state = VaultViewMode.allVault;
          container.read(cardDisplayLayoutProvider.notifier).state = CardDisplayLayout.grid;
          await tester.pumpAndSettle();

          // In Singles mode with Grid layout: verify exact crossAxisCount
          final cardsGridFinder = find.byKey(const PageStorageKey<String>('vault_cards_sliver_grid'));
          expect(
            cardsGridFinder,
            findsOneWidget,
            reason: 'SliverGrid should exist at width $width px in Singles Grid mode',
          );

          final cardsGrid = tester.widget<SliverGrid>(cardsGridFinder);
          final delegate = cardsGrid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;

          expect(
            delegate.crossAxisCount,
            equals(expectedColumns),
            reason: 'Grid columns at width $width px must be exactly $expectedColumns',
          );

          // Switch to Binders mode: verify Binders grid remains strictly 2 columns
          container.read(vaultViewModeProvider.notifier).state = VaultViewMode.binders;
          await tester.pumpAndSettle();

          final bindersGridFinder = find.byKey(const PageStorageKey<String>('vault_binders_sliver_grid'));
          expect(
            bindersGridFinder,
            findsOneWidget,
            reason: 'Binders SliverGrid should exist at width $width px',
          );

          final bindersGrid = tester.widget<SliverGrid>(bindersGridFinder);
          final bindersDelegate = bindersGrid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;

          expect(
            bindersDelegate.crossAxisCount,
            equals(2),
            reason: 'Binders grid must always remain 2 columns at width $width px',
          );
        }

        // Remediation verification: confirm that with FittedBox/Flexible in place,
        // the extreme 300px narrow width renders cleanly with zero RenderFlex overflows.
        expect(
          caughtOverflowsAt300.isEmpty,
          isTrue,
          reason: 'Confirms narrow-viewport (300px) overflow is remediated and clean.',
        );

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      },
    );

    // -------------------------------------------------------------------------
    // 3. Rapid switching between Singles and Binders while search bar is expanded
    // -------------------------------------------------------------------------
    testWidgets(
      'Adversarial 3: Rapid switching between Singles and Binders while search bar is expanded with active text query',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(db.vaultDao),
            activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(buildVaultScreen(container: container));
        await tester.pumpAndSettle();

        // 3.1 Start in Binders mode, expand search
        await tester.tap(find.byKey(const Key('vault_search_expand_button')));
        await tester.pumpAndSettle();

        final searchField = find.byKey(const Key('vault_search_text_field'));
        expect(searchField, findsOneWidget);

        // Enter query that matches MTG cards
        await tester.enterText(searchField, 'Black Lotus');
        await tester.pump(const Duration(milliseconds: 300)); // allow debounce to fire

        // Verify query reached Riverpod state
        expect(container.read(vaultSearchQueryProvider), equals('Black Lotus'));

        // 3.2 While search bar is expanded, rapidly toggle view mode via provider
        container.read(vaultViewModeProvider.notifier).state = VaultViewMode.allVault;
        await tester.pumpAndSettle();

        // In Singles mode: search bar remains expanded, showing active query
        expect(find.byKey(const Key('vault_search_text_field')), findsOneWidget);
        expect(find.text('Black Lotus'), findsOneWidget);

        // FAB must be absent in Singles mode even when search is expanded
        expect(find.byKey(const Key('vault_new_binder_fab')), findsNothing);

        // Category filter chips should be rendered in Singles mode
        expect(find.text('Owned'), findsOneWidget);

        // Switch back to Binders mode via provider while search is still expanded
        container.read(vaultViewModeProvider.notifier).state = VaultViewMode.binders;
        await tester.pumpAndSettle();

        // In Binders mode: FAB must be visible again even with search expanded
        expect(find.byKey(const Key('vault_new_binder_fab')), findsOneWidget);
        expect(find.byKey(const Key('vault_search_text_field')), findsOneWidget);
        expect(find.text('Black Lotus'), findsOneWidget);

        // 3.3 Test user collapse and manual toggle cycle
        await tester.tap(find.byKey(const Key('vault_search_collapse_button')));
        await tester.pumpAndSettle();

        // Toggles are restored
        expect(find.byKey(const Key('vault_view_singles_toggle')), findsOneWidget);
        expect(find.byKey(const Key('vault_view_binders_toggle')), findsOneWidget);

        // Rapid tap Singles -> tap Expand -> tap Collapse -> tap Binders
        await tester.tap(find.byKey(const Key('vault_view_singles_toggle')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('vault_search_expand_button')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('vault_search_collapse_button')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('vault_view_binders_toggle')));
        await tester.pumpAndSettle();

        // End state must be clean Binders view
        expect(container.read(vaultViewModeProvider), equals(VaultViewMode.binders));
        expect(find.byKey(const Key('vault_new_binder_fab')), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      },
    );

    // -------------------------------------------------------------------------
    // 4. FAB tap interaction in Binders mode vs verified absence in Singles mode
    // -------------------------------------------------------------------------
    testWidgets(
      'Adversarial 4: Full FAB interaction lifecycle (open, empty-validation, cancel, create) vs verified absence in Singles',
      (tester) async {
        await tester.pumpWidget(buildVaultScreen());
        await tester.pumpAndSettle();

        // 4.1 In Binders mode: FAB is present
        final fabFinder = find.byKey(const Key('vault_new_binder_fab'));
        expect(fabFinder, findsOneWidget);

        // Tap FAB to open dialog
        await tester.tap(fabFinder);
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text('New Binder for Magic: The Gathering'), findsOneWidget);
        expect(find.text('Create Binder'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);

        // 4.2 Adversarial check: Empty submission should not create a binder or dismiss dialog
        await tester.tap(find.text('Create Binder'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget); // dialog still open!

        // Whitespace only submission
        final dialogTextField = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        );
        expect(dialogTextField, findsOneWidget);
        await tester.enterText(dialogTextField, '     ');
        await tester.tap(find.text('Create Binder'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget); // still open!

        // 4.3 Cancel interaction
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing); // dialog closed

        // 4.4 Valid creation interaction
        await tester.tap(fabFinder);
        await tester.pumpAndSettle();

        final dialogTextField2 = find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        );
        await tester.enterText(dialogTextField2, 'Vintage Black Border');
        await tester.tap(find.text('Create Binder'));
        await tester.pumpAndSettle();

        // Dialog should be dismissed
        expect(find.byType(AlertDialog), findsNothing);

        // SnackBar verification
        expect(find.text('Created Binder "Vintage Black Border"'), findsOneWidget);

        // Database & UI verification: new binder should be visible in Binders grid
        expect(find.text('Vintage Black Border'), findsOneWidget);

        // 4.5 Switch to Singles mode: FAB must be completely absent from widget tree
        await tester.tap(find.byKey(const Key('vault_view_singles_toggle')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('vault_new_binder_fab')), findsNothing);
        expect(find.byType(FloatingActionButton), findsNothing);
        expect(find.text('New Binder'), findsNothing);

        // Switch back to Binders mode: FAB must return
        await tester.tap(find.byKey(const Key('vault_view_binders_toggle')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('vault_new_binder_fab')), findsOneWidget);
        expect(find.text('New Binder'), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      },
    );
  });
}
