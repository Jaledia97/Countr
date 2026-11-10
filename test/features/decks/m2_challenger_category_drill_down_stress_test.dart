import 'package:drift/drift.dart' hide isNull, isNotNull, Column;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/data/daos/explore_deck_dao.dart';
import 'package:countr/features/decks/domain/models/explore_deck_models.dart';
import 'package:countr/features/decks/presentation/providers/explore_deck_providers.dart';
import 'package:countr/features/decks/presentation/widgets/explore/explore_category_drill_down_view.dart';
import 'package:countr/features/decks/presentation/widgets/explore/explore_decks_tab_view.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('Milestone 2 Challenger 1: Adversarial Drill-Down & See More Stress Tests', () {
    late AppDatabase db;
    late ExploreDeckDao exploreDao;

    // Helper to seed N decks for a specific featured category
    Future<void> seedDecks(
      String category,
      int count, {
      String format = 'Commander',
      String sourceType = 'community',
      String creatorName = 'Adversarial Tester',
    }) async {
      for (int i = 0; i < count; i++) {
        final id = '${category.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}_deck_$i';
        await db.into(db.exploreDecks).insert(
          ExploreDecksCompanion.insert(
            id: id,
            name: '$category Deck #$i',
            format: format,
            featuredCategory: Value(category),
            sourceType: Value(sourceType),
            creatorName: Value(creatorName),
            upvotes: Value(10 + i),
            createdAt: DateTime.now().subtract(Duration(hours: i)),
            updatedAt: Value(DateTime.now().subtract(Duration(hours: i))),
          ),
        );
      }
    }

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      exploreDao = ExploreDeckDao(db);

      // Seed 35 decks for Suggested Commanders (well above 15-item limit)
      await seedDecks('Suggested Commanders', 35);

      // Seed 25 decks for From Top Deck Builders (well above 15-item limit)
      await seedDecks('From Top Deck Builders', 25, creatorName: 'ProBuilder');

      // Seed 20 decks for Popular Standard Decks (well above 15-item limit)
      await seedDecks('Popular Standard Decks', 20, format: 'Standard');

      // Seed 10 uncategorized decks to ensure filtering isolates correctly
      for (int i = 0; i < 10; i++) {
        await db.into(db.exploreDecks).insert(
          ExploreDecksCompanion.insert(
            id: 'uncategorized_deck_$i',
            name: 'Uncategorized Deck $i',
            format: 'Modern',
            sourceType: const Value('community'),
            createdAt: DateTime.now(),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('1. Tap every See More button and verify drill-down state triggers cleanly', (tester) async {
      tester.view.physicalSize = const Size(390, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            exploreDeckDaoProvider.overrideWithValue(exploreDao),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ExploreDecksTabView(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Step A: Suggested Commanders See More
      final suggestedSeeMore = find.byKey(const Key('explore_carousel_see_more_suggested_commanders'));
      expect(suggestedSeeMore, findsOneWidget);
      await tester.tap(suggestedSeeMore);
      await tester.pumpAndSettle();

      // Drill-down header bar keys verification
      expect(find.byKey(const Key('explore_drill_down_title')), findsOneWidget);
      expect(find.text('Suggested Commanders'), findsOneWidget);
      expect(find.byKey(const Key('explore_drill_down_back_button')), findsOneWidget);
      expect(find.byKey(const Key('explore_drill_down_count_badge')), findsOneWidget);
      expect(find.byKey(const Key('explore_drill_down_reset_button')), findsOneWidget);
      expect(find.text('35 decks'), findsOneWidget);

      // Return to discovery feed via back button
      await tester.tap(find.byKey(const Key('explore_drill_down_back_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('explore_carousel_suggested_commanders')), findsOneWidget);

      // Step B: Top Builders See More (verify primary key and alias key)
      final topBuildersSeeMore = find.byKey(const Key('explore_carousel_see_more_top_builders'));
      expect(topBuildersSeeMore, findsOneWidget);
      expect(find.byKey(const Key('explore_carousel_see_more_from_top_deck_builders')), findsOneWidget);
      await tester.tap(topBuildersSeeMore);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('explore_drill_down_title')), findsOneWidget);
      expect(find.text('From Top Deck Builders'), findsOneWidget);
      expect(find.text('25 decks'), findsOneWidget);

      // Return to discovery feed via reset button
      await tester.tap(find.byKey(const Key('explore_drill_down_reset_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('explore_carousel_top_builders')), findsOneWidget);

      // Step C: Popular Standard See More (verify primary key and alias key)
      final popularStandardSeeMore = find.byKey(const Key('explore_carousel_see_more_popular_standard'));
      expect(popularStandardSeeMore, findsOneWidget);
      expect(find.byKey(const Key('explore_carousel_see_more_popular_standard_decks')), findsOneWidget);
      await tester.tap(popularStandardSeeMore);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('explore_drill_down_title')), findsOneWidget);
      expect(find.text('Popular Standard Decks'), findsOneWidget);
      expect(find.text('20 decks'), findsOneWidget);

      // Return to discovery feed via back button
      await tester.tap(find.byKey(const Key('explore_drill_down_back_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('explore_carousel_popular_standard')), findsOneWidget);
    });

    testWidgets('2. Category drill-down renders all 35 decks without 15-item limit in 2-column grid', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            exploreDeckDaoProvider.overrideWithValue(exploreDao),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ExploreDecksTabView(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap See More on Suggested Commanders (35 seeded decks)
      await tester.tap(find.byKey(const Key('explore_carousel_see_more_suggested_commanders')));
      await tester.pumpAndSettle();

      // Count badge must say exactly 35 decks
      expect(find.text('35 decks'), findsOneWidget);

      // Verify uncapped DAO query
      final decksInDb = await exploreDao.watchExploreDecks(
        featuredCategory: 'Suggested Commanders',
      ).first;
      expect(decksInDb.length, equals(35));

      // Scroll through grid to verify decks past 15 are fully rendered without layout overflow
      final scrollViewFinder = find.byKey(const PageStorageKey('explore_drill_down_Suggested Commanders_scroll_key'));
      expect(scrollViewFinder, findsOneWidget);

      // Before scrolling: Top deck with highest upvotes (Deck #34) is rendered at top
      expect(find.text('Suggested Commanders Deck #34'), findsOneWidget);

      // Verify intermediate deck past the 15-item carousel cap (e.g. Deck #18)
      await tester.scrollUntilVisible(
        find.text('Suggested Commanders Deck #18'),
        300.0,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Suggested Commanders Deck #18'), findsOneWidget);

      // Scroll until the very bottom deck (Deck #0, 35th item) is visible
      await tester.scrollUntilVisible(
        find.text('Suggested Commanders Deck #0'),
        300.0,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Suggested Commanders Deck #0'), findsOneWidget);

      // Ensure sticky header stayed pinned and back button is still clickable
      expect(find.byKey(const Key('explore_drill_down_back_button')), findsOneWidget);
      expect(find.byKey(const Key('explore_drill_down_reset_button')), findsOneWidget);
      expect(find.text('35 decks'), findsOneWidget);

      // Tap reset button while scrolled deep to verify it resets cleanly
      await tester.tap(find.byKey(const Key('explore_drill_down_reset_button')));
      await tester.pumpAndSettle();

      // Returned to discovery feed cleanly
      expect(find.byKey(const Key('explore_carousel_suggested_commanders')), findsOneWidget);
    });

    testWidgets('3. Sticky header bar remains pinned and visible during long vertical scrolls', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            exploreDeckDaoProvider.overrideWithValue(exploreDao),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ExploreCategoryDrillDownView(
                category: 'Suggested Commanders',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find initial positions of sticky header widgets
      final titleFinder = find.byKey(const Key('explore_drill_down_title'));
      final backFinder = find.byKey(const Key('explore_drill_down_back_button'));
      final countFinder = find.byKey(const Key('explore_drill_down_count_badge'));
      final resetFinder = find.byKey(const Key('explore_drill_down_reset_button'));

      expect(titleFinder, findsOneWidget);
      expect(backFinder, findsOneWidget);
      expect(countFinder, findsOneWidget);
      expect(resetFinder, findsOneWidget);

      final initialTitleOffset = tester.getTopLeft(titleFinder);

      // Scroll the CustomScrollView by -1500 pixels
      final scrollFinder = find.byType(CustomScrollView);
      await tester.drag(scrollFinder, const Offset(0, -1500));
      await tester.pumpAndSettle();

      // Sticky header elements MUST NOT move: top-left offset should remain identical
      final scrolledTitleOffset = tester.getTopLeft(titleFinder);
      expect(scrolledTitleOffset.dy, equals(initialTitleOffset.dy));
      expect(find.byKey(const Key('explore_drill_down_back_button')), findsOneWidget);
      expect(find.byKey(const Key('explore_drill_down_reset_button')), findsOneWidget);
      expect(find.byKey(const Key('explore_drill_down_count_badge')), findsOneWidget);
    });

    testWidgets('4. Rapid back and reset navigation sequence stress test', (tester) async {
      tester.view.physicalSize = const Size(390, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          exploreDeckDaoProvider.overrideWithValue(exploreDao),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: ExploreDecksTabView(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Cycle 1: Suggested Commanders -> Back
      await tester.tap(find.byKey(const Key('explore_carousel_see_more_suggested_commanders')));
      await tester.pumpAndSettle();
      expect(container.read(exploreDrillDownCategoryProvider), equals('Suggested Commanders'));
      await tester.tap(find.byKey(const Key('explore_drill_down_back_button')));
      await tester.pumpAndSettle();
      expect(container.read(exploreDrillDownCategoryProvider), isNull);

      // Cycle 2: Top Builders -> Reset
      await tester.tap(find.byKey(const Key('explore_carousel_see_more_top_builders')));
      await tester.pumpAndSettle();
      expect(container.read(exploreDrillDownCategoryProvider), equals('From Top Deck Builders'));
      await tester.tap(find.byKey(const Key('explore_drill_down_reset_button')));
      await tester.pumpAndSettle();
      expect(container.read(exploreDrillDownCategoryProvider), isNull);

      // Cycle 3: Popular Standard -> Back
      await tester.tap(find.byKey(const Key('explore_carousel_see_more_popular_standard')));
      await tester.pumpAndSettle();
      expect(container.read(exploreDrillDownCategoryProvider), equals('Popular Standard Decks'));
      await tester.tap(find.byKey(const Key('explore_drill_down_back_button')));
      await tester.pumpAndSettle();
      expect(container.read(exploreDrillDownCategoryProvider), isNull);

      // Cycle 4: Suggested Commanders -> Reset
      await tester.tap(find.byKey(const Key('explore_carousel_see_more_suggested_commanders')));
      await tester.pumpAndSettle();
      expect(container.read(exploreDrillDownCategoryProvider), equals('Suggested Commanders'));
      await tester.tap(find.byKey(const Key('explore_drill_down_reset_button')));
      await tester.pumpAndSettle();
      expect(container.read(exploreDrillDownCategoryProvider), isNull);

      // Verify all carousels remain intact
      expect(find.byKey(const Key('explore_carousel_suggested_commanders')), findsOneWidget);
      expect(find.byKey(const Key('explore_carousel_top_builders')), findsOneWidget);
      expect(find.byKey(const Key('explore_carousel_popular_standard')), findsOneWidget);
    });

    testWidgets('5. PopScope cleanly handles back gesture without route pop', (tester) async {
      tester.view.physicalSize = const Size(390, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          exploreDeckDaoProvider.overrideWithValue(exploreDao),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: ExploreDecksTabView(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open drill down
      await tester.tap(find.byKey(const Key('explore_carousel_see_more_suggested_commanders')));
      await tester.pumpAndSettle();
      expect(container.read(exploreDrillDownCategoryProvider), equals('Suggested Commanders'));

      // Simulate system back gesture via PopScope
      final popScopeFinder = find.byKey(const Key('explore_drill_down_pop_scope'));
      expect(popScopeFinder, findsOneWidget);
      final popScopeWidget = tester.widget<PopScope<Object?>>(popScopeFinder);
      expect(popScopeWidget.canPop, isFalse);

      popScopeWidget.onPopInvokedWithResult!(false, null);
      await tester.pumpAndSettle();

      // Drill-down should be closed and container state cleared
      expect(container.read(exploreDrillDownCategoryProvider), isNull);
      expect(find.byKey(const Key('explore_carousel_suggested_commanders')), findsOneWidget);
    });

    testWidgets('6. Empty category renders clean empty state without throwing', (tester) async {
      const emptyCat = 'Non-Existent Category';

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            exploreDeckDaoProvider.overrideWithValue(exploreDao),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ExploreCategoryDrillDownView(
                category: emptyCat,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('explore_drill_down_title')), findsOneWidget);
      expect(find.text(emptyCat), findsOneWidget);
      expect(find.text('0 decks'), findsOneWidget);
      expect(find.text('No decks found in $emptyCat'), findsOneWidget);
      expect(find.byIcon(Icons.explore_off_rounded), findsOneWidget);
      expect(find.byKey(const Key('explore_drill_down_back_button')), findsOneWidget);
      expect(find.byKey(const Key('explore_drill_down_reset_button')), findsOneWidget);
    });

    testWidgets('7. CustomDecks stress harness renders 40 custom in-memory decks', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final customDecks = List.generate(
        40,
        (i) => ExploreDeckWithVote(
          deck: ExploreDeck(
            id: 'custom_deck_$i',
            name: 'Custom Stress Deck #$i',
            format: 'Commander',
            tcgDomain: 'mtg',
            sourceType: 'community',
            creatorName: 'Custom Builder',
            featuredCategory: 'Custom Category',
            colorIdentity: 'W,U',
            cardCount: 100,
            estimatedPrice: 49.99,
            upvotes: 5,
            downvotes: 0,
            score: 5,
            isDeleted: false,
            createdAt: DateTime.now(),
          ),
          userVote: 0,
        ),
      );

      bool backCalled = false;
      ExploreDeckWithVote? tappedDeck;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExploreCategoryDrillDownView(
              category: 'Custom Category',
              customDecks: customDecks,
              onBack: () => backCalled = true,
              onTapDeck: (d) => tappedDeck = d,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('explore_drill_down_title')), findsOneWidget);
      expect(find.text('Custom Category'), findsOneWidget);
      expect(find.text('40 decks'), findsOneWidget);

      // Tap first deck card
      await tester.tap(find.text('Custom Stress Deck #0'));
      await tester.pumpAndSettle();
      expect(tappedDeck?.id, equals('custom_deck_0'));

      // Tap back button
      await tester.tap(find.byKey(const Key('explore_drill_down_back_button')));
      await tester.pumpAndSettle();
      expect(backCalled, isTrue);
    });
  });
}
