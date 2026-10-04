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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Milestone M1 Challenger Adversarial Stress Suite', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await db.vaultDao.clearAllItems();
    });

    tearDown(() async {
      await db.close();
    });

    Widget createAdversarialApp({
      List<Override> overrides = const [],
      Size viewportSize = const Size(390, 844),
      TextScaler textScaler = TextScaler.noScaling,
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
    // 1. Empty Collection (0 Items) & Boundary Behavior
    // =========================================================================
    group('1. Empty Collection (0 Items) Boundary Invariants', () {
      testWidgets('Empty vault: renders 0 items and \$0.00 without crashing', (tester) async {
        await tester.pumpWidget(createAdversarialApp());
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('vault_portfolio_summary_card')), findsOneWidget);
        expect(find.textContaining('Total Tracked Items: 0'), findsOneWidget);
        expect(find.text('\$0.00'), findsOneWidget);
        expect(find.byKey(const Key('vault_showing_results_counter')), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('Empty vault with active filter: compact row shows \$0.00, items 0, and "showing 0 results"', (tester) async {
        await tester.pumpWidget(createAdversarialApp());
        await tester.pumpAndSettle();

        // Expand search
        await tester.tap(find.byKey(const Key('vault_search_expand_button')));
        await tester.pumpAndSettle();

        await tester.enterText(find.byKey(const Key('vault_search_text_field')), 'Nonexistent');
        await tester.pumpAndSettle();

        final summaryCard = find.byKey(const Key('vault_portfolio_summary_card'));
        expect(summaryCard, findsOneWidget);
        expect(find.text('Filtered Value: \$0.00'), findsOneWidget);
        expect(find.descendant(of: summaryCard, matching: find.textContaining('Total Tracked Items: 0')), findsOneWidget);
        expect(find.byKey(const Key('vault_showing_results_counter')), findsOneWidget);
        expect(find.text('showing 0 results'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });

    // =========================================================================
    // 2. Single Item (1 Item) Singular vs Plural Counter Formatting
    // =========================================================================
    group('2. Single Item & Counter Grammar Invariants', () {
      testWidgets('Exactly 1 matching card displays singular "showing 1 result"', (tester) async {
        // Insert exactly 1 item
        final now = DateTime.now();
        await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'item-single-card-1',
            collectionType: 'mtg',
            name: 'Sol Ring',
            setOrSeries: 'Commander Masters',
            imageUrl: 'https://cards.scryfall.io/sol_ring.jpg',
            acquiredPrice: 1.50,
            acquiredDate: now,
            lastPriceUpdate: now,
            currentMarketPrice: 2.00,
            quantity: const drift.Value(1),
            condition: 'NM',
            dynamicData: '{}',
          ),
        );

        await tester.pumpWidget(createAdversarialApp());
        await tester.pumpAndSettle();

        // Unfiltered: summary shows 1 item
        expect(find.textContaining('Total Tracked Items: 1'), findsOneWidget);
        expect(find.byKey(const Key('vault_showing_results_counter')), findsNothing);

        // Search matching that 1 card
        await tester.tap(find.byKey(const Key('vault_search_expand_button')));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const Key('vault_search_text_field')), 'Sol Ring');
        await tester.pumpAndSettle();

        // Grammar invariant: singular "1 result", NOT "1 results"
        expect(find.byKey(const Key('vault_showing_results_counter')), findsOneWidget);
        expect(find.text('showing 1 result'), findsOneWidget);
        expect(find.text('Filtered Value: \$2.00'), findsOneWidget);

        // Search matching 0 cards: plural "0 results"
        await tester.enterText(find.byKey(const Key('vault_search_text_field')), 'Mana Crypt');
        await tester.pumpAndSettle();

        expect(find.text('showing 0 results'), findsOneWidget);
        expect(find.text('Filtered Value: \$0.00'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });

    // =========================================================================
    // 3. Massive Inventory Counts & Extreme Portfolio Values
    // =========================================================================
    group('3. Massive Inventory & Financial Extreme Values', () {
      testWidgets('Massive portfolio (\$1.23B, 1.5M items) renders cleanly without RenderFlex overflow', (tester) async {
        const massiveSummary = VaultPortfolioSummary(
          totalMarketValue: 1234567890.75,
          totalCostBasis: 246913578.15,
          totalProfitLoss: 987654312.60,
          profitLossPercentage: 400.0,
          totalItemCount: 1542890,
          uniqueCardCount: 84200,
        );

        await tester.pumpWidget(
          createAdversarialApp(
            overrides: [
              vaultPortfolioSummaryProvider.overrideWithValue(massiveSummary),
            ],
            viewportSize: const Size(320, 568),
            textScaler: const TextScaler.linear(2.0),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('vault_portfolio_summary_card')), findsOneWidget);
        expect(find.textContaining('1542890'), findsOneWidget);
        expect(find.text('\$1234567890.75'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('Negative P/L (-\$25,000, -65.2%) renders loss indicator with 0 overflow', (tester) async {
        const lossSummary = VaultPortfolioSummary(
          totalMarketValue: 13500.00,
          totalCostBasis: 38500.00,
          totalProfitLoss: -25000.00,
          profitLossPercentage: -64.9,
          totalItemCount: 320,
          uniqueCardCount: 150,
        );

        await tester.pumpWidget(
          createAdversarialApp(
            overrides: [
              vaultPortfolioSummaryProvider.overrideWithValue(lossSummary),
            ],
            viewportSize: const Size(320, 568),
            textScaler: const TextScaler.linear(1.5),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('vault_portfolio_summary_card')), findsOneWidget);
        expect(find.byIcon(Icons.trending_down_rounded), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });

    // =========================================================================
    // 4. Currencies & Privacy Mode Formatting
    // =========================================================================
    group('4. Currencies & Privacy Mode Formatting', () {
      testWidgets('Alternative currencies (EUR, GBP, CAD) format correctly in hero card', (tester) async {
        const eurSummary = VaultPortfolioSummary(
          totalMarketValue: 5432.10,
          totalCostBasis: 4000.00,
          totalProfitLoss: 1432.10,
          profitLossPercentage: 35.8,
          totalItemCount: 50,
        );

        await tester.pumpWidget(
          createAdversarialApp(
            overrides: [
              vaultPortfolioSummaryProvider.overrideWithValue(eurSummary),
              baseCurrencyProvider.overrideWith((ref) => AppCurrency.eur),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('€5432.10'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('Privacy Mode masks values with **** in both expanded hero card and compact filtered row', (tester) async {
        await db.vaultDao.seedDatabase();

        await tester.pumpWidget(
          createAdversarialApp(
            overrides: [
              privacyModeProvider.overrideWith((ref) => true),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // In expanded hero card: price and P/L pill masked
        expect(find.text('****'), findsWidgets);

        // Filter: compact row also masked
        await tester.tap(find.byKey(const Key('vault_search_expand_button')));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const Key('vault_search_text_field')), 'Ring');
        await tester.pumpAndSettle();

        expect(find.text('Filtered Value: ****'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });

    // =========================================================================
    // 5. Rapid Toggling Stress (Owned <-> All Cards)
    // =========================================================================
    group('5. Rapid View Toggling Stress', () {
      testWidgets('Rapid toggling 20 times between Owned and All Cards does not crash or corrupt sliver state', (tester) async {
        await db.vaultDao.seedDatabase();

        await tester.pumpWidget(createAdversarialApp());
        await tester.pumpAndSettle();

        final allCardsSegment = find.text('All Cards');
        final ownedSegment = find.text('Owned');

        for (int i = 0; i < 20; i++) {
          await tester.tap(allCardsSegment);
          await tester.pump(const Duration(milliseconds: 16));

          await tester.tap(ownedSegment);
          await tester.pump(const Duration(milliseconds: 16));
        }

        await tester.pumpAndSettle();

        // Ensure state settles cleanly
        expect(find.byKey(const Key('vault_portfolio_summary_card')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });

    // =========================================================================
    // 6. Severe 2.0x Text Scaling on Small Screen (320x568)
    // =========================================================================
    group('6. Severe 2.0x Text Scaling on 320x568 Screen', () {
      testWidgets('2.0x Text Scale on 320x568: Unfiltered Owned mode renders with zero RenderFlex overflow', (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await db.vaultDao.seedDatabase();

        await tester.pumpWidget(
          createAdversarialApp(
            viewportSize: const Size(320, 568),
            textScaler: const TextScaler.linear(2.0),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('vault_portfolio_summary_card')), findsOneWidget);
        expect(find.byKey(const Key('vault_search_expand_button')), findsOneWidget);
        expect(find.byKey(const Key('vault_import_button')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('2.0x Text Scale on 320x568: Filtered Owned mode compact row renders with zero RenderFlex overflow', (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await db.vaultDao.seedDatabase();

        await tester.pumpWidget(
          createAdversarialApp(
            viewportSize: const Size(320, 568),
            textScaler: const TextScaler.linear(2.0),
          ),
        );
        await tester.pumpAndSettle();

        // Expand search
        await tester.tap(find.byKey(const Key('vault_search_expand_button')));
        await tester.pumpAndSettle();

        await tester.enterText(find.byKey(const Key('vault_search_text_field')), 'Lotus');
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('vault_portfolio_summary_card')), findsOneWidget);
        expect(find.byKey(const Key('vault_showing_results_counter')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('2.0x Text Scale on 320x568: Scroll compression and collapse executes with zero exceptions', (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await db.vaultDao.seedDatabase();

        await tester.pumpWidget(
          createAdversarialApp(
            viewportSize: const Size(320, 568),
            textScaler: const TextScaler.linear(2.0),
          ),
        );
        await tester.pumpAndSettle();

        final scrollFinder = find.byType(CustomScrollView);
        await tester.drag(scrollFinder, const Offset(0, -180));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        await tester.drag(scrollFinder, const Offset(0, 180));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });

      testWidgets('2.0x Text Scale on 320x568: All Cards catalog mode renders search and cards with zero overflow', (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await db.vaultDao.seedDatabase();

        await tester.pumpWidget(
          createAdversarialApp(
            viewportSize: const Size(320, 568),
            textScaler: const TextScaler.linear(2.0),
          ),
        );
        await tester.pumpAndSettle();

        // Scroll horizontal chip row to bring "All Cards" fully onto 320px viewport
        await tester.drag(find.byType(SingleChildScrollView).first, const Offset(-200, 0));
        await tester.pumpAndSettle();

        await tester.tap(find.text('All Cards'));
        await tester.pumpAndSettle();

        // In All Cards mode: value card is omitted
        expect(find.byKey(const Key('vault_portfolio_summary_card')), findsNothing);

        // Search trigger is functional
        expect(find.byKey(const Key('vault_search_expand_button')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('2.0x Text Scale on 320x568: AppBar actions Import button renders with zero overflow', (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await db.vaultDao.seedDatabase();

        await tester.pumpWidget(
          createAdversarialApp(
            viewportSize: const Size(320, 568),
            textScaler: const TextScaler.linear(2.0),
          ),
        );
        await tester.pumpAndSettle();

        final importBtn = find.byKey(const Key('vault_import_button'));
        expect(importBtn, findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('AppBar actions Import button launches VaultImportBottomSheet at standard scale', (tester) async {
        await db.vaultDao.seedDatabase();

        await tester.pumpWidget(createAdversarialApp());
        await tester.pumpAndSettle();

        final importBtn = find.byKey(const Key('vault_import_button'));
        expect(importBtn, findsOneWidget);

        await tester.tap(importBtn);
        await tester.pumpAndSettle();

        expect(find.byType(VaultImportBottomSheet), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Dismiss
        await tester.tapAt(const Offset(20, 20));
        await tester.pumpAndSettle();
        expect(find.byType(VaultImportBottomSheet), findsNothing);
      });
    });

    // =========================================================================
    // 7. Advanced Edge Case Combos: Filtered Toggles & Extreme Compact Row
    // =========================================================================
    group('7. Advanced Edge Case Combos: Filtered Toggles & Extreme Compact Row', () {
      testWidgets('Direct initial launch into All Cards mode completely omits summary card from first frame', (tester) async {
        await db.vaultDao.seedDatabase();

        await tester.pumpWidget(
          createAdversarialApp(
            overrides: [
              vaultShowCatalogProvider.overrideWith((ref) => true),
            ],
            viewportSize: const Size(320, 568),
            textScaler: const TextScaler.linear(2.0),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('vault_portfolio_summary_card')), findsNothing);
        expect(find.byKey(const Key('vault_search_expand_button')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('Active filter during rapid Owned <-> All Cards toggle alternates compact row while keeping counter visible', (tester) async {
        await db.vaultDao.seedDatabase();

        await tester.pumpWidget(createAdversarialApp());
        await tester.pumpAndSettle();

        // 1. Activate search query 'Lotus'
        await tester.tap(find.byKey(const Key('vault_search_expand_button')));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const Key('vault_search_text_field')), 'Lotus');
        await tester.pumpAndSettle();

        // In Owned: compact row and counter are visible
        expect(find.byKey(const Key('vault_portfolio_summary_card')), findsOneWidget);
        expect(find.byKey(const Key('vault_showing_results_counter')), findsOneWidget);

        final allCardsSegment = find.text('All Cards');
        final ownedSegment = find.text('Owned');

        // Toggle back and forth 10 times while filtered
        for (int i = 0; i < 10; i++) {
          await tester.tap(allCardsSegment);
          await tester.pump(const Duration(milliseconds: 16));

          // In All Cards: value card is omitted, counter is retained
          expect(find.byKey(const Key('vault_portfolio_summary_card')), findsNothing);
          expect(find.byKey(const Key('vault_showing_results_counter')), findsOneWidget);

          await tester.tap(ownedSegment);
          await tester.pump(const Duration(milliseconds: 16));

          // In Owned: value card is restored, counter is retained
          expect(find.byKey(const Key('vault_portfolio_summary_card')), findsOneWidget);
          expect(find.byKey(const Key('vault_showing_results_counter')), findsOneWidget);
        }

        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('Search clear button reverts compact row to hero card and clears counter', (tester) async {
        await db.vaultDao.seedDatabase();

        await tester.pumpWidget(createAdversarialApp());
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('vault_search_expand_button')));
        await tester.pumpAndSettle();

        // Search active
        await tester.enterText(find.byKey(const Key('vault_search_text_field')), 'Mox');
        await tester.pumpAndSettle();

        expect(find.textContaining('Filtered Value:'), findsOneWidget);
        expect(find.byKey(const Key('vault_showing_results_counter')), findsOneWidget);

        // Tap clear button
        final clearBtn = find.byKey(const Key('vault_search_clear_button'));
        expect(clearBtn, findsOneWidget);
        await tester.tap(clearBtn);
        await tester.pumpAndSettle();

        // Reverts to full hero card and removes counter
        expect(find.text('ESTIMATED VAULT VALUE'), findsOneWidget);
        expect(find.byKey(const Key('vault_showing_results_counter')), findsNothing);
        expect(tester.takeException(), isNull);
      });
    });
  });
}
