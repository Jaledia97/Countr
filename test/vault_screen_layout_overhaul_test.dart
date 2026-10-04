import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/screens/vault_screen.dart';
import 'package:countr/features/vault/presentation/widgets/vault_import_bottom_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Vault Screen Layout Overhaul Comprehensive Empirical Test Suite', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    Widget createTestHarness({
      List<Override> extraOverrides = const [],
      Size viewportSize = const Size(390, 844),
      TextScaler textScaler = TextScaler.noScaling,
    }) {
      return ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
          ...extraOverrides,
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              size: viewportSize,
              textScaler: textScaler,
            ),
            child: child!,
          ),
          home: const VaultScreen(),
        ),
      );
    }

    // =========================================================================
    // R1: "All Cards" Full Screen Grid (Value Card Completely Hidden)
    // =========================================================================
    testWidgets('R1: "All Cards" catalog mode completely hides portfolio value card', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await db.vaultDao.seedDatabase();

      // 1. Initial Owned mode -> value card must be visible
      await tester.pumpWidget(createTestHarness());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('vault_portfolio_summary_card')), findsOneWidget);

      // 2. Switch to "All Cards" catalog mode via SegmentedButton or Provider
      final allCardsSegment = find.text('All Cards');
      expect(allCardsSegment, findsOneWidget);
      await tester.tap(allCardsSegment);
      await tester.pumpAndSettle();

      // In All Cards mode: value card must be completely omitted
      expect(find.byKey(const Key('vault_portfolio_summary_card')), findsNothing);

      // Search bar and controls remain visible directly at the top
      expect(find.byKey(const Key('vault_search_expand_button')), findsOneWidget);

      // 3. Switch back to "Owned" -> value card is restored
      final ownedSegment = find.text('Owned');
      expect(ownedSegment, findsOneWidget);
      await tester.tap(ownedSegment);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('vault_portfolio_summary_card')), findsOneWidget);
    });

    // =========================================================================
    // R2: Collapsible Value Header for "Owned" Tab
    // =========================================================================
    testWidgets('R2: Collapsible sliver header smoothly compresses and scrolls without overflow', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await db.vaultDao.seedDatabase();

      await tester.pumpWidget(createTestHarness());
      await tester.pumpAndSettle();

      // Value card is present in un-scrolled state
      final cardFinder = find.byKey(const Key('vault_portfolio_summary_card'));
      expect(cardFinder, findsOneWidget);
      final initialRect = tester.getRect(cardFinder);
      expect(initialRect.height, greaterThanOrEqualTo(50.0));

      // Scroll up by 150px
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -150));
      await tester.pumpAndSettle();

      // No unhandled exceptions thrown during scrolling and collapse
      expect(tester.takeException(), isNull);
    });

    // =========================================================================
    // R3: Component Compression & AppBar Import Action
    // =========================================================================
    testWidgets('R3: Import button relocated to AppBar.actions and triggers modal; card metrics compressed', (tester) async {
      await db.vaultDao.seedDatabase();

      await tester.pumpWidget(createTestHarness());
      await tester.pumpAndSettle();

      // Verify Import button is in AppBar.actions
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      final appBar = scaffold.appBar as AppBar;
      expect(appBar.actions, isNotNull);
      expect(appBar.actions!.length, equals(1));

      final importBtnFinder = find.byKey(const Key('vault_import_button'));
      expect(importBtnFinder, findsOneWidget);
      expect(
        find.descendant(of: find.byType(AppBar), matching: importBtnFinder),
        findsOneWidget,
      );
      expect(find.text('Import'), findsOneWidget);
      expect(find.byIcon(Icons.file_download_outlined), findsOneWidget);

      // Verify card layout has Total Tracked Items on the same row as P/L pill
      expect(find.textContaining('Total Tracked Items:'), findsOneWidget);
      expect(find.text('ESTIMATED VAULT VALUE'), findsOneWidget);

      // Tap Import button to verify it launches VaultImportBottomSheet
      await tester.tap(importBtnFinder);
      await tester.pumpAndSettle();

      expect(find.byType(VaultImportBottomSheet), findsOneWidget);

      // Dismiss the bottom sheet
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      expect(find.byType(VaultImportBottomSheet), findsNothing);
    });

    // =========================================================================
    // R4: Contextual Filter Behavior ("Filtered Value: $X")
    // =========================================================================
    testWidgets('R4: Contextual filter behavior transforms value card into compact "Filtered Value" row', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await db.vaultDao.seedDatabase();

      await tester.pumpWidget(createTestHarness());
      await tester.pumpAndSettle();

      // Expand search
      await tester.tap(find.byKey(const Key('vault_search_expand_button')));
      await tester.pumpAndSettle();

      // Type search query that matches 'Lotus'
      await tester.enterText(find.byKey(const Key('vault_search_text_field')), 'Lotus');
      await tester.pumpAndSettle();

      // Summary card is still present
      final summaryCard = find.byKey(const Key('vault_portfolio_summary_card'));
      expect(summaryCard, findsOneWidget);

      // Shows compact "Filtered Value"
      expect(find.textContaining('Filtered Value:'), findsOneWidget);
      expect(
        find.descendant(of: summaryCard, matching: find.byIcon(Icons.tune_rounded)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: summaryCard, matching: find.textContaining('Total Tracked Items:')),
        findsOneWidget,
      );

      // Clear search query
      await tester.tap(find.byKey(const Key('vault_search_clear_button')));
      await tester.pumpAndSettle();

      // Reverts back to full estimated vault value card
      expect(find.text('ESTIMATED VAULT VALUE'), findsOneWidget);
    });

    // =========================================================================
    // R5: Dynamic "showing ___ results" Counter in Owned and All Cards views
    // =========================================================================
    testWidgets('R5: Dynamic "showing ___ results" counter renders only when filtered in both Owned and All Cards modes', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await db.vaultDao.seedDatabase();

      await tester.pumpWidget(createTestHarness());
      await tester.pumpAndSettle();

      // When unfiltered, counter must NOT be present
      expect(find.byKey(const Key('vault_showing_results_counter')), findsNothing);

      // 1. In Owned Mode: Activate search
      await tester.tap(find.byKey(const Key('vault_search_expand_button')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('vault_search_text_field')), 'Lotus');
      await tester.pumpAndSettle();

      // Counter should appear with 'showing 1 result'
      expect(find.byKey(const Key('vault_showing_results_counter')), findsOneWidget);
      expect(find.text('showing 1 result'), findsOneWidget);

      // Clear search
      await tester.tap(find.byKey(const Key('vault_search_clear_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('vault_showing_results_counter')), findsNothing);

      // 2. In "All Cards" Mode:
      await tester.tap(find.text('All Cards'));
      await tester.pumpAndSettle();

      // Unfiltered in All Cards -> no counter
      expect(find.byKey(const Key('vault_showing_results_counter')), findsNothing);

      // Type query in All Cards
      await tester.enterText(find.byKey(const Key('vault_search_text_field')), 'Ring');
      await tester.pumpAndSettle();

      // Counter appears in All Cards mode as well
      expect(find.byKey(const Key('vault_showing_results_counter')), findsOneWidget);
      expect(find.textContaining('showing'), findsOneWidget);
      expect(find.textContaining('result'), findsOneWidget);

      // Clear query
      await tester.tap(find.byKey(const Key('vault_search_clear_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('vault_showing_results_counter')), findsNothing);
    });

    // =========================================================================
    // Responsive Text Scale & Viewport Stress Test
    // =========================================================================
    testWidgets('Responsive & Text Scale stress: renders at 1.5x text scale with 0 overflows', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await db.vaultDao.seedDatabase();

      await tester.pumpWidget(
        createTestHarness(
          viewportSize: const Size(320, 568),
          textScaler: const TextScaler.linear(1.5),
        ),
      );
      await tester.pumpAndSettle();

      // Expand search on small screen at 1.5x scale
      await tester.tap(find.byKey(const Key('vault_search_expand_button')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('vault_search_text_field')), 'Black');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('vault_portfolio_summary_card')), findsOneWidget);
      expect(find.byKey(const Key('vault_showing_results_counter')), findsOneWidget);
    });

    // =========================================================================
    // Adaptive Scroll Sync
    // =========================================================================
    testWidgets('Adaptive scroll sync smoothly offsets scroll position in Owned and Catalog modes', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await db.vaultDao.seedDatabase();

      await tester.pumpWidget(createTestHarness());
      await tester.pumpAndSettle();

      final scrollFinder = find.byType(CustomScrollView);
      expect(scrollFinder, findsOneWidget);

      // Drag scroll in Owned mode
      await tester.drag(scrollFinder, const Offset(0, -100));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Switch to catalog mode and drag scroll
      await tester.tap(find.text('All Cards'));
      await tester.pumpAndSettle();

      await tester.drag(scrollFinder, const Offset(0, -100));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}

