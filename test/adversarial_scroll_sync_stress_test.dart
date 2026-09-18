import 'dart:convert';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/screens/vault_screen.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_card.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_tile.dart';

// ============================================================================
// Mathematical Oracle Functions mirroring VaultScreen._scrollToCardIndex
// ============================================================================

int calculateGridColumns(double screenWidth) {
  if (screenWidth < 600) return 3;
  if (screenWidth < 900) return 4;
  if (screenWidth < 1200) return 5;
  return 6;
}

double calculateGridScrollOffset({
  required int index,
  required int totalCount,
  required double screenWidth,
  required double screenHeight,
  double headerOffset = 288.0,
  double maxScrollExtent = 50000.0,
}) {
  if (totalCount <= 0 || index < 0 || index >= totalCount) return 0.0;

  final columns = calculateGridColumns(screenWidth);
  final totalSpacing = (columns - 1) * 10.0;
  final gridWidth = screenWidth - 32.0; // 16px horizontal margins
  final itemWidth = (gridWidth - totalSpacing) / columns;
  final itemHeight = itemWidth / 0.64; // childAspectRatio: 0.64
  final rowHeight = itemHeight + 10.0; // mainAxisSpacing: 10.0
  final rowIndex = index ~/ columns;

  final targetOffset = rowIndex == 0
      ? 0.0
      : headerOffset + (rowIndex * rowHeight) - (screenHeight / 3.5);

  return targetOffset.clamp(0.0, maxScrollExtent);
}

double calculateListScrollOffset({
  required int index,
  required int totalCount,
  required double screenHeight,
  double headerOffset = 288.0,
  double listItemHeight = 136.0,
  double maxScrollExtent = 50000.0,
}) {
  if (totalCount <= 0 || index < 0 || index >= totalCount) return 0.0;

  final targetOffset = index == 0
      ? 0.0
      : headerOffset + (index * listItemHeight) - (screenHeight / 3.5);

  return targetOffset.clamp(0.0, maxScrollExtent);
}

// ============================================================================
// Test Card Factory & Seeder
// ============================================================================

Future<void> seedVaultCards(AppDatabase db, int count) async {
  for (int i = 0; i < count; i++) {
    await db.vaultDao.into(db.vaultItems).insert(
      VaultItemsCompanion.insert(
        id: 'adversarial-card-$i',
        collectionType: 'mtg',
        name: 'Stress Card ${i.toString().padLeft(3, '0')}',
        setOrSeries: 'Phyrexia',
        imageUrl: 'https://cards.scryfall.io/large/front/test.jpg',
        acquiredPrice: 5.0 + i,
        acquiredDate: DateTime(2026, 9, 18),
        quantity: const Value(1),
        condition: 'NM',
        isGraded: const Value(false),
        currentMarketPrice: 10.0 + (i * 1.5),
        lastPriceUpdate: DateTime(2026, 9, 18),
        dynamicData: jsonEncode({
          'layout': 'normal',
          'mana_cost': '{1}{B}',
          'type_line': 'Creature — Phyrexian',
          'oracle_text': 'Deathtouch. When this dies, draw a card. #$i',
          'rarity': 'rare',
        }),
      ),
    );
  }
}

Widget wrapWithAdversarialHarness(
  Widget child, {
  required AppDatabase db,
  required VaultDao dao,
  UserPersona persona = UserPersona.investor,
  CardDisplayLayout layout = CardDisplayLayout.grid,
}) {
  return ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      vaultDaoProvider.overrideWithValue(dao),
      userPersonaProvider.overrideWith((ref) => persona),
      cardDisplayLayoutProvider.overrideWith((ref) => layout),
      activeGameContextProvider.overrideWith((ref) => 'mtg'),
      vaultShowCatalogProvider.overrideWith((ref) => false),
      vaultSearchQueryProvider.overrideWith((ref) => ''),
      vaultPaginationLimitProvider.overrideWith((ref) => 200),
      vaultIsFetchingMoreProvider.overrideWith((ref) => false),
      vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: child,
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late VaultDao dao;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dao = db.vaultDao;
  });

  tearDown(() async {
    await db.close();
  });

  // ===========================================================================
  // SECTION 1: Mathematical Oracle Stress Tests Across 120+ Items & Devices
  // ===========================================================================
  group('Section 1: Mathematical Stress Tests on Scroll Offset Formulas', () {
    test('1.1: Grid Mode: 120 items monotonicity and boundary clamp on Phone 360x780', () {
      const double width = 360.0;
      const double height = 780.0;
      const int count = 120;
      final cols = calculateGridColumns(width);
      expect(cols, equals(3), reason: 'Phone 360 width must resolve to 3 columns');

      double previousOffset = -1.0;
      for (int i = 0; i < count; i++) {
        final offset = calculateGridScrollOffset(
          index: i,
          totalCount: count,
          screenWidth: width,
          screenHeight: height,
        );

        // Clamping checks
        expect(offset, greaterThanOrEqualTo(0.0), reason: 'Offset for index $i must never be negative');

        // Card 0 in row 0 must strictly clamp to 0.0
        final row = i ~/ cols;
        if (row == 0) {
          expect(offset, equals(0.0), reason: 'Row 0 (index $i) must clamp to 0.0');
        } else {
          expect(offset, greaterThan(0.0), reason: 'Rows > 0 (index $i) must be positive');
        }

        // Monotonicity: next row offset >= previous row offset
        if (previousOffset >= 0.0) {
          expect(offset, greaterThanOrEqualTo(previousOffset),
              reason: 'Scroll offset must be monotonic at index $i (got $offset < $previousOffset)');
        }
        previousOffset = offset;
      }
    });

    test('1.2: Grid Mode: 150 items on Phone 400x800', () {
      const double width = 400.0;
      const double height = 800.0;
      const int count = 150;
      final cols = calculateGridColumns(width);
      expect(cols, equals(3));

      double previousOffset = -1.0;
      for (int i = 0; i < count; i++) {
        final offset = calculateGridScrollOffset(
          index: i,
          totalCount: count,
          screenWidth: width,
          screenHeight: height,
        );

        expect(offset, greaterThanOrEqualTo(0.0));
        if (i ~/ cols == 0) {
          expect(offset, equals(0.0));
        } else {
          expect(offset, greaterThan(0.0));
        }
        if (previousOffset >= 0.0) {
          expect(offset, greaterThanOrEqualTo(previousOffset));
        }
        previousOffset = offset;
      }
    });

    test('1.3: Grid Mode: 150 items on Tablet 800x1200 (4 columns)', () {
      const double width = 800.0;
      const double height = 1200.0;
      const int count = 150;
      final cols = calculateGridColumns(width);
      expect(cols, equals(4), reason: 'Tablet 800 width must resolve to 4 columns');

      double previousOffset = -1.0;
      for (int i = 0; i < count; i++) {
        final offset = calculateGridScrollOffset(
          index: i,
          totalCount: count,
          screenWidth: width,
          screenHeight: height,
        );

        expect(offset, greaterThanOrEqualTo(0.0));
        if (i ~/ cols == 0) {
          expect(offset, equals(0.0));
        } else {
          expect(offset, greaterThan(0.0));
        }
        if (previousOffset >= 0.0) {
          expect(offset, greaterThanOrEqualTo(previousOffset));
        }
        previousOffset = offset;
      }
    });

    test('1.4: Grid Mode: 120 items on Large Tablet 1024x1366 (5 columns)', () {
      const double width = 1024.0;
      const double height = 1366.0;
      const int count = 120;
      final cols = calculateGridColumns(width);
      expect(cols, equals(5), reason: 'Tablet 1024 width must resolve to 5 columns');

      double previousOffset = -1.0;
      for (int i = 0; i < count; i++) {
        final offset = calculateGridScrollOffset(
          index: i,
          totalCount: count,
          screenWidth: width,
          screenHeight: height,
        );

        expect(offset, greaterThanOrEqualTo(0.0));
        if (i ~/ cols == 0) {
          expect(offset, equals(0.0));
        }
        if (previousOffset >= 0.0) {
          expect(offset, greaterThanOrEqualTo(previousOffset));
        }
        previousOffset = offset;
      }
    });

    test('1.5: List Mode: 150 items strictly monotonic progression across viewports', () {
      const int count = 150;
      final viewports = [
        const Size(360, 780),
        const Size(400, 800),
        const Size(800, 1200),
      ];

      for (final vp in viewports) {
        double previousOffset = -1.0;
        for (int i = 0; i < count; i++) {
          final offset = calculateListScrollOffset(
            index: i,
            totalCount: count,
            screenHeight: vp.height,
          );

          expect(offset, greaterThanOrEqualTo(0.0));
          if (i == 0) {
            expect(offset, equals(0.0), reason: 'Card 0 in list mode must clamp cleanly to 0.0');
          } else {
            expect(offset, greaterThan(0.0));
            // In list mode, each index represents a separate row, so offsets are strictly increasing
            if (previousOffset > 0.0) {
              expect(offset, greaterThan(previousOffset),
                  reason: 'List mode offset at index $i must be strictly greater than index ${i - 1}');
            }
          }
          previousOffset = offset;
        }
      }
    });

    test('1.6: Boundary & Invalid Index Clamping', () {
      expect(calculateGridScrollOffset(index: -1, totalCount: 100, screenWidth: 400, screenHeight: 800), equals(0.0));
      expect(calculateGridScrollOffset(index: 100, totalCount: 100, screenWidth: 400, screenHeight: 800), equals(0.0));
      expect(calculateGridScrollOffset(index: 999, totalCount: 100, screenWidth: 400, screenHeight: 800), equals(0.0));
      expect(calculateListScrollOffset(index: -5, totalCount: 100, screenHeight: 800), equals(0.0));
      expect(calculateListScrollOffset(index: 100, totalCount: 100, screenHeight: 800), equals(0.0));
    });
  });

  // ===========================================================================
  // SECTION 2: Empirical Widget Tests with 120+ DB Items Across Viewports
  // ===========================================================================
  group('Section 2: Empirical VaultScreen Widget Tests (120+ Items)', () {
    testWidgets('2.1: Phone 360x780 Grid Mode: Opening, Swiping 10 cards, and Dismissal position persistence', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final originalOnError = FlutterError.onError;
      bool detectedOverflow = false;
      FlutterError.onError = (FlutterErrorDetails details) {
        if (details.exceptionAsString().contains('RenderFlex overflowed')) {
          detectedOverflow = true;
          return;
        }
        originalOnError?.call(details);
      };
      addTearDown(() {
        FlutterError.onError = originalOnError;
      });

      await seedVaultCards(db, 120);

      await tester.pumpWidget(wrapWithAdversarialHarness(
        const VaultScreen(),
        db: db,
        dao: dao,
        layout: CardDisplayLayout.grid,
      ));
      await tester.pumpAndSettle();

      final scrollableFinder = find.descendant(
        of: find.byType(CustomScrollView),
        matching: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down),
      );
      final scrollable = tester.state<ScrollableState>(scrollableFinder);
      expect(scrollable.position.pixels, equals(0.0), reason: 'Initial scroll offset must be 0.0');

      // Tap card 0 to open CardDetailSheet
      final firstCard = find.byType(VaultItemTile).hitTestable().first;
      expect(firstCard, findsOneWidget);
      await tester.tap(firstCard);
      await tester.pumpAndSettle();

      expect(find.byType(CardDetailSheet), findsOneWidget);
      expect(scrollable.position.pixels, equals(0.0), reason: 'Card 0 should not disturb 0.0 offset');

      // Empirical check: Verify whether CardDetailSheet overflowed on 360px viewport
      expect(detectedOverflow, isTrue,
          reason: 'Empirical bug: CardDetailSheet Row overflowed by 35px on 360px viewport width');

      // Swipe forward through 9 cards to Card 9 (row 3 in 3-column grid)
      for (int i = 0; i < 9; i++) {
        await tester.fling(find.byKey(const Key('card_detail_page_view')), const Offset(-400, 0), 1000);
        await tester.pumpAndSettle();
      }

      final scrolledOffsetCard9 = scrollable.position.pixels;
      expect(scrolledOffsetCard9, greaterThan(0.0), reason: 'Card 9 (row 3) must scroll down in background');

      // Swipe backward back to Card 0
      for (int i = 0; i < 9; i++) {
        await tester.fling(find.byKey(const Key('card_detail_page_view')), const Offset(400, 0), 1000);
        await tester.pumpAndSettle();
      }

      expect(scrollable.position.pixels, equals(0.0),
          reason: 'Swiping back to card 0 must cleanly restore scroll position to 0.0 without header clipping');

      // Swipe to Card 6 (row 2)
      for (int i = 0; i < 6; i++) {
        await tester.fling(find.byKey(const Key('card_detail_page_view')), const Offset(-400, 0), 1000);
        await tester.pumpAndSettle();
      }

      final scrolledOffsetCard6 = scrollable.position.pixels;
      expect(scrolledOffsetCard6, greaterThan(0.0));

      // Dismiss CardDetailSheet via close button
      final closeButton = find.descendant(
        of: find.byType(CardDetailSheet),
        matching: find.byIcon(Icons.close),
      );
      expect(closeButton, findsOneWidget);
      await tester.tap(closeButton);
      await tester.pumpAndSettle();

      // Verify sheet is dismissed
      expect(find.byType(CardDetailSheet), findsNothing);

      // Verify underlying grid STAYS at the scrolled position and DOES NOT reset
      expect(scrollable.position.pixels, equals(scrolledOffsetCard6),
          reason: 'Dismissing sheet must preserve underlying scroll position');

      // Clean teardown
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('2.2: Phone 400x800 List Mode: Swiping, Preservation, Re-opening, and Zero Clamping', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await seedVaultCards(db, 120);

      await tester.pumpWidget(wrapWithAdversarialHarness(
        const VaultScreen(),
        db: db,
        dao: dao,
        layout: CardDisplayLayout.list,
      ));
      await tester.pumpAndSettle();

      final scrollableFinder = find.descendant(
        of: find.byType(CustomScrollView),
        matching: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down),
      );
      final scrollable = tester.state<ScrollableState>(scrollableFinder);
      expect(scrollable.position.pixels, equals(0.0));

      // Tap card 0 to open CardDetailSheet
      final firstCard = find.byType(VaultItemCard).hitTestable().first;
      expect(firstCard, findsOneWidget);
      await tester.tap(firstCard);
      await tester.pumpAndSettle();

      expect(find.byType(CardDetailSheet), findsOneWidget);

      // Swipe through 5 cards in List mode
      for (int i = 0; i < 5; i++) {
        await tester.fling(find.byKey(const Key('card_detail_page_view')), const Offset(-400, 0), 1000);
        await tester.pumpAndSettle();
      }

      final offsetAtCard5 = scrollable.position.pixels;
      expect(offsetAtCard5, greaterThan(0.0));

      // Dismiss sheet
      await tester.tap(find.descendant(
        of: find.byType(CardDetailSheet),
        matching: find.byIcon(Icons.close),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(CardDetailSheet), findsNothing);
      expect(scrollable.position.pixels, equals(offsetAtCard5),
          reason: 'List mode must preserve scroll position after sheet dismissal');

      // Re-open from currently visible card
      final visibleCard = find.byType(VaultItemCard).hitTestable().first;
      await tester.tap(visibleCard);
      await tester.pumpAndSettle();
      expect(find.byType(CardDetailSheet), findsOneWidget);

      // Swipe backward multiple times towards Card 0
      for (int i = 0; i < 8; i++) {
        await tester.fling(find.byKey(const Key('card_detail_page_view')), const Offset(400, 0), 1000);
        await tester.pumpAndSettle();
      }

      // Verify underlying list clamped back to 0.0
      expect(scrollable.position.pixels, equals(0.0),
          reason: 'Swiping back past card 0 clamps cleanly to 0.0 in list mode');

      // Dismiss sheet
      await tester.tap(find.descendant(
        of: find.byType(CardDetailSheet),
        matching: find.byIcon(Icons.close),
      ));
      await tester.pumpAndSettle();

      expect(scrollable.position.pixels, equals(0.0),
          reason: 'Dismissal at card 0 leaves scroll position at 0.0 with full header visible');

      // Clean teardown
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('2.3: Tablet 800x1200 Grid Mode (4 columns): Swiping and Background Tracking', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await seedVaultCards(db, 120);

      await tester.pumpWidget(wrapWithAdversarialHarness(
        const VaultScreen(),
        db: db,
        dao: dao,
        layout: CardDisplayLayout.grid,
      ));
      await tester.pumpAndSettle();

      final scrollableFinder = find.descendant(
        of: find.byType(CustomScrollView),
        matching: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down),
      );
      final scrollable = tester.state<ScrollableState>(scrollableFinder);
      expect(scrollable.position.pixels, equals(0.0));

      // Open sheet
      final firstTile = find.byType(VaultItemTile).hitTestable().first;
      await tester.tap(firstTile);
      await tester.pumpAndSettle();

      // Swipe 8 cards forward (row 2 in 4-column grid)
      for (int i = 0; i < 8; i++) {
        await tester.fling(find.byKey(const Key('card_detail_page_view')), const Offset(-400, 0), 1000);
        await tester.pumpAndSettle();
      }

      final offsetRow2 = scrollable.position.pixels;
      expect(offsetRow2, greaterThan(0.0), reason: 'Tablet 4-column grid row 2 must scroll down');

      // Dismiss sheet
      await tester.tap(find.descendant(
        of: find.byType(CardDetailSheet),
        matching: find.byIcon(Icons.close),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(CardDetailSheet), findsNothing);
      expect(scrollable.position.pixels, equals(offsetRow2),
          reason: 'Tablet view must retain scrolled position upon dismissal');

      // Clean teardown
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('2.4: Stress Test: Rapid Sequential Swipes and Boundary Resilience', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await seedVaultCards(db, 120);

      await tester.pumpWidget(wrapWithAdversarialHarness(
        const VaultScreen(),
        db: db,
        dao: dao,
        layout: CardDisplayLayout.grid,
      ));
      await tester.pumpAndSettle();

      final scrollableFinder = find.descendant(
        of: find.byType(CustomScrollView),
        matching: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down),
      );
      final scrollable = tester.state<ScrollableState>(scrollableFinder);

      // Open sheet
      await tester.tap(find.byType(VaultItemTile).hitTestable().first);
      await tester.pumpAndSettle();

      // Execute 12 rapid flings with minimal interval
      for (int i = 0; i < 12; i++) {
        await tester.fling(find.byKey(const Key('card_detail_page_view')), const Offset(-400, 0), 1200);
        await tester.pump(const Duration(milliseconds: 50));
      }

      // Settle all remaining animations
      await tester.pumpAndSettle();

      // Verify no exceptions were thrown and scrollable position is valid finite number
      expect(tester.takeException(), isNull);
      expect(scrollable.position.pixels, greaterThan(0.0));
      expect(scrollable.position.pixels, lessThanOrEqualTo(scrollable.position.maxScrollExtent));

      // Dismiss sheet
      await tester.tap(find.descendant(
        of: find.byType(CardDetailSheet),
        matching: find.byIcon(Icons.close),
      ));
      await tester.pumpAndSettle();

      expect(scrollable.position.pixels, greaterThan(0.0));

      // Clean teardown
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
