import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/screens/vault_screen.dart';
import 'package:countr/features/vault/presentation/widgets/vault_import_bottom_sheet.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_card.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_tile.dart';

Future<void> _insertTestCards(
  AppDatabase db,
  int count, {
  bool isOwned = true,
  String prefix = 'challenger2-card',
}) async {
  for (int i = 0; i < count; i++) {
    await db.vaultDao.into(db.vaultItems).insert(
      VaultItemsCompanion.insert(
        id: '$prefix-$i',
        collectionType: 'mtg',
        name: 'Challenger Card ${i.toString().padLeft(3, '0')}',
        setOrSeries: 'M1 Stress Set',
        imageUrl: 'https://example.com/card-$i.jpg',
        acquiredPrice: 10.0 + i,
        acquiredDate: DateTime(2023, 1, 1).add(Duration(days: i)),
        quantity: drift.Value(isOwned ? 1 : 0),
        condition: 'NM',
        isGraded: const drift.Value(false),
        currentMarketPrice: 20.0 + i,
        lastPriceUpdate: DateTime.now(),
        dynamicData: '{"oracle_text":"Challenger stress card $i","rarity":"rare"}',
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Challenger 2 Empirical Stress Tests: Scroll Dynamics & Gestures', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await db.vaultDao.clearAllItems();
    });

    tearDown(() async {
      await db.close();
    });

    Widget createTestHarness({
      required ProviderContainer container,
      Size viewportSize = const Size(390, 844),
      TargetPlatform platform = TargetPlatform.android,
    }) {
      return UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData(
            platform: platform,
          ),
          home: MediaQuery(
            data: MediaQueryData(
              size: viewportSize,
              padding: const EdgeInsets.only(top: 44, bottom: 34),
            ),
            child: const VaultScreen(),
          ),
        ),
      );
    }

    ProviderContainer createContainer({
      List<Override> extraOverrides = const [],
    }) {
      return ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
          ...extraOverrides,
        ],
      );
    }

    // =========================================================================
    // Challenge 1: Smooth Vertical Header Collapse & Step-by-Step Expansion
    // =========================================================================
    testWidgets('Challenge 1: Micro-step scrolling smoothly collapses and expands header without layout flutter',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await _insertTestCards(db, 30, isOwned: true);
      final container = createContainer();

      await tester.pumpWidget(createTestHarness(container: container));
      await tester.pumpAndSettle();

      final scrollFinder = find.byType(CustomScrollView);
      expect(scrollFinder, findsOneWidget);

      final summaryCardFinder = find.byKey(const Key('vault_portfolio_summary_card'));
      expect(summaryCardFinder, findsOneWidget);

      final initialRect = tester.getRect(summaryCardFinder);
      expect(initialRect.height, greaterThanOrEqualTo(50.0));

      // Micro-scroll downward in 10px increments up to 150px
      for (double offset = 10.0; offset <= 150.0; offset += 10.0) {
        await tester.drag(scrollFinder, const Offset(0, -10));
        await tester.pump();
        expect(tester.takeException(), isNull,
            reason: 'Exception thrown at downward scroll offset $offset');
      }

      await tester.pumpAndSettle();

      // Scrolled past maxExtent (98.0) -> header should be collapsed
      // Now micro-scroll upward in reverse increments back to top
      for (double offset = 10.0; offset <= 160.0; offset += 10.0) {
        await tester.drag(scrollFinder, const Offset(0, 10));
        await tester.pump();
        expect(tester.takeException(), isNull,
            reason: 'Exception thrown at upward scroll offset $offset');
      }

      await tester.pumpAndSettle();

      // At top, summary card must be fully visible and intact
      expect(summaryCardFinder, findsOneWidget);
      final restoredRect = tester.getRect(summaryCardFinder);
      expect(restoredRect.height, equals(initialRect.height));
    });

    // =========================================================================
    // Challenge 2: Negative Overscroll & Pull-to-Refresh Clamping
    // =========================================================================
    testWidgets('Challenge 2: Negative overscroll with iOS BouncingScrollPhysics clamps without distortion or crash',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await _insertTestCards(db, 30, isOwned: true);
      final container = createContainer();

      // Test with iOS platform for BouncingScrollPhysics overscroll dynamics
      await tester.pumpWidget(createTestHarness(
        container: container,
        platform: TargetPlatform.iOS,
      ));
      await tester.pumpAndSettle();

      final scrollFinder = find.byType(CustomScrollView);
      final summaryCardFinder = find.byKey(const Key('vault_portfolio_summary_card'));
      expect(summaryCardFinder, findsOneWidget);

      // Aggressive drag downward while at offset 0 (overscroll stretching)
      await tester.drag(scrollFinder, const Offset(0, 250));
      await tester.pump();

      // Ensure no negative constraint or render overflow exceptions
      expect(tester.takeException(), isNull);
      expect(summaryCardFinder, findsOneWidget);

      // Release gesture and allow physics bounce-back simulation
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Perform an aggressive downward fling
      await tester.fling(scrollFinder, const Offset(0, -1200), 3000);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Perform aggressive upward fling back to top
      await tester.fling(scrollFinder, const Offset(0, 1200), 3000);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(summaryCardFinder, findsOneWidget);
    });

    // =========================================================================
    // Challenge 3: Dynamic maxExtent Morphing Across Filter Transitions
    // =========================================================================
    testWidgets('Challenge 3: Toggling filter while partially scrolled smoothly morphs maxExtent',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await _insertTestCards(db, 30, isOwned: true);
      final container = createContainer();

      await tester.pumpWidget(createTestHarness(container: container));
      await tester.pumpAndSettle();

      final scrollFinder = find.byType(CustomScrollView);

      // Scroll partially by 40px (midway through 98px header)
      await tester.drag(scrollFinder, const Offset(0, -40));
      await tester.pump();

      // Activate search query while partially scrolled
      await tester.tap(find.byKey(const Key('vault_search_expand_button')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('vault_search_text_field')), 'Challenger Card 001');
      await tester.pumpAndSettle();

      // Verify compact filtered row morphs cleanly without RenderFlex error
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Filtered Value:'), findsOneWidget);
      expect(find.byKey(const Key('vault_showing_results_counter')), findsOneWidget);
      expect(find.text('showing 1 result'), findsOneWidget);

      // Scroll down another 60px (exceeds filtered maxExtent 52.0)
      await tester.drag(scrollFinder, const Offset(0, -60));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Clear search query while scrolled
      await tester.tap(find.byKey(const Key('vault_search_clear_button')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('vault_showing_results_counter')), findsNothing);
    });

    // =========================================================================
    // Challenge 4: Switching between Owned and Catalog while Scrolled
    // =========================================================================
    testWidgets('Challenge 4: Switching between Owned and Catalog at non-zero scroll retains stability',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await _insertTestCards(db, 30, isOwned: true, prefix: 'owned-card');
      await _insertTestCards(db, 20, isOwned: false, prefix: 'catalog-card');
      final container = createContainer();

      await tester.pumpWidget(createTestHarness(container: container));
      await tester.pumpAndSettle();

      final scrollFinder = find.byType(CustomScrollView);

      // Scroll down 200px (header fully off-screen)
      await tester.drag(scrollFinder, const Offset(0, -200));
      await tester.pumpAndSettle();

      // Switch to All Cards (Catalog mode) while scrolled via provider mutation
      container.read(vaultShowCatalogProvider.notifier).state = true;
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('vault_portfolio_summary_card')), findsNothing);

      // Scroll further in Catalog mode
      await tester.drag(scrollFinder, const Offset(0, -100));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Switch back to Owned mode while scrolled via provider mutation
      container.read(vaultShowCatalogProvider.notifier).state = false;
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Scroll back to top
      await tester.drag(scrollFinder, const Offset(0, 400));
      await tester.pumpAndSettle();

      // Header is restored cleanly
      expect(find.byKey(const Key('vault_portfolio_summary_card')), findsOneWidget);
    });

    // =========================================================================
    // Challenge 5: Adaptive headerOffset Verification in _scrollToCardIndex
    // =========================================================================
    testWidgets('Challenge 5: Adaptive headerOffset swiping scrolls cards into view across all modes',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await _insertTestCards(db, 40, isOwned: true);
      final container = createContainer();

      await tester.pumpWidget(createTestHarness(container: container));
      await tester.pumpAndSettle();

      // 1. In Owned Mode (Unfiltered Grid):
      // Tap on the first card tile to open CardDetailSheet
      final firstCardTile = find.byType(VaultItemTile).first;
      expect(firstCardTile, findsOneWidget);
      await tester.tap(firstCardTile);
      await tester.pumpAndSettle();

      // Swipe through cards in CardDetailSheet (card 0 -> 1 -> 2 -> 3)
      final pageViewFinder = find.byType(PageView);
      expect(pageViewFinder, findsOneWidget);

      // Swipe left to page 1
      await tester.drag(pageViewFinder, const Offset(-300, 0));
      await tester.pumpAndSettle();

      // Swipe left to page 2
      await tester.drag(pageViewFinder, const Offset(-300, 0));
      await tester.pumpAndSettle();

      // Swipe left to page 3 (moves to row 1 in a 3-column grid)
      await tester.drag(pageViewFinder, const Offset(-300, 0));
      await tester.pumpAndSettle();

      // Background scroll position adapts smoothly without crashing
      expect(tester.takeException(), isNull);

      // Close bottom sheet
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      // Scroll back up to top so layout buttons are not obscured by AppBar
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 500));
      await tester.pumpAndSettle();

      // 2. Switch to List Mode
      await tester.tap(find.byKey(const Key('vault_layout_list_button')));
      await tester.pumpAndSettle();
      expect(find.byType(VaultItemCard), findsWidgets);

      // Open CardDetailSheet on the first visible card thumbnail in List mode
      final thumbnail = find.byWidgetPredicate(
        (w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('vault_card_thumbnail_tap_'),
      ).first;
      expect(thumbnail, findsOneWidget);
      await tester.tap(thumbnail);
      await tester.pumpAndSettle();

      // Swipe to card 1
      await tester.drag(find.byType(PageView), const Offset(-300, 0));
      await tester.pumpAndSettle();

      // Swipe to card 2
      await tester.drag(find.byType(PageView), const Offset(-300, 0));
      await tester.pumpAndSettle();

      // Close bottom sheet
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    // =========================================================================
    // Challenge 6: Rigorous Hit-Testing & Tap Bounds of vault_import_button
    // =========================================================================
    testWidgets('Challenge 6: vault_import_button hit-testing is verified across bounds and scroll states',
        (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await _insertTestCards(db, 30, isOwned: true);
      final container = createContainer();

      await tester.pumpWidget(createTestHarness(
        container: container,
        viewportSize: const Size(800, 600),
      ));
      await tester.pumpAndSettle();

      final importBtnFinder = find.byKey(const Key('vault_import_button'));
      expect(importBtnFinder, findsOneWidget);

      final rect = tester.getRect(importBtnFinder);
      expect(rect.width, greaterThan(40.0));
      expect(rect.height, greaterThan(20.0));

      // Verify no occlusion with AppBar title / PopupMenuButton
      final titleFinder = find.byType(PopupMenuButton<String>);
      expect(titleFinder, findsOneWidget);
      final titleRect = tester.getRect(titleFinder);
      expect(rect.overlaps(titleRect), isFalse,
          reason: 'vault_import_button must not overlap with title PopupMenuButton');

      // Test 1: Hit test at Center
      await tester.tapAt(rect.center);
      await tester.pumpAndSettle();
      expect(find.byType(VaultImportBottomSheet), findsOneWidget);
      await tester.tapAt(const Offset(20, 20)); // dismiss
      await tester.pumpAndSettle();
      expect(find.byType(VaultImportBottomSheet), findsNothing);

      // Test 2: Hit test at Top-Left corner (+2px inward)
      await tester.tapAt(rect.topLeft + const Offset(2, 2));
      await tester.pumpAndSettle();
      expect(find.byType(VaultImportBottomSheet), findsOneWidget);
      await tester.tapAt(const Offset(20, 20)); // dismiss
      await tester.pumpAndSettle();

      // Test 3: Hit test at Bottom-Right corner (-2px inward)
      await tester.tapAt(rect.bottomRight + const Offset(-2, -2));
      await tester.pumpAndSettle();
      expect(find.byType(VaultImportBottomSheet), findsOneWidget);
      await tester.tapAt(const Offset(20, 20)); // dismiss
      await tester.pumpAndSettle();

      // Test 4: Hit test after scrolling down 300px
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();

      // Button in AppBar remains pinned and clickable
      await tester.tap(importBtnFinder);
      await tester.pumpAndSettle();
      expect(find.byType(VaultImportBottomSheet), findsOneWidget);
      await tester.tapAt(const Offset(20, 20)); // dismiss
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
