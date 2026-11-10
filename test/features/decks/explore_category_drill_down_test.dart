import 'package:drift/drift.dart' hide isNull, isNotNull, Column;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/data/daos/explore_deck_dao.dart';
import 'package:countr/features/decks/data/services/explore_seeder_service.dart';
import 'package:countr/features/decks/data/services/fallback_explore_seeds.dart';
import 'package:countr/features/decks/presentation/providers/explore_deck_providers.dart';
import 'package:countr/features/decks/presentation/widgets/explore/explore_carousel_section.dart';
import 'package:countr/features/decks/presentation/widgets/explore/explore_category_drill_down_view.dart';
import 'package:countr/features/decks/presentation/widgets/explore/explore_decks_tab_view.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('ExploreDeckDao Featured Category Queries & Uncapped Limits (R2)', () {
    late AppDatabase db;
    late ExploreDeckDao exploreDao;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      exploreDao = ExploreDeckDao(db);
      await ExploreSeederService.seedFromRawDecks(db, FallbackExploreSeeds.allSeeds);
    });

    tearDown(() async {
      await db.close();
    });

    test('watchExploreDecks with featuredCategory scopes strictly to that category', () async {
      final suggestedDecks = await exploreDao.watchExploreDecks(
        featuredCategory: 'Suggested Commanders',
      ).first;

      expect(suggestedDecks, isNotEmpty);
      for (final deck in suggestedDecks) {
        expect(deck.featuredCategory, equals('Suggested Commanders'));
      }

      final topBuilderDecks = await exploreDao.watchExploreDecks(
        featuredCategory: 'From Top Deck Builders',
      ).first;

      expect(topBuilderDecks, isNotEmpty);
      for (final deck in topBuilderDecks) {
        expect(deck.featuredCategory, equals('From Top Deck Builders'));
      }
    });

    test('watchFilteredExploreDeckCount and getFilteredExploreDeckCount with featuredCategory return true counts', () async {
      final streamCount = await exploreDao.watchFilteredExploreDeckCount(
        featuredCategory: 'Suggested Commanders',
      ).first;

      final futureCount = await exploreDao.getFilteredExploreDeckCount(
        featuredCategory: 'Suggested Commanders',
      );

      expect(streamCount, equals(futureCount));
      expect(streamCount, greaterThan(0));

      // Verify count equals actual matching rows in database
      final matchingDecks = await (db.select(db.exploreDecks)
            ..where((t) => t.featuredCategory.equals('Suggested Commanders') & t.isDeleted.equals(false)))
          .get();
      expect(streamCount, equals(matchingDecks.length));
    });

    test('watchFeaturedCategory supports nullable limit and uncapped queries beyond 15 items', () async {
      const testCategory = 'Bulk Test Category';

      // Insert 20 decks belonging to testCategory
      for (int i = 0; i < 20; i++) {
        await db.into(db.exploreDecks).insert(
          ExploreDecksCompanion.insert(
            id: 'bulk_deck_$i',
            name: 'Bulk Deck $i',
            format: 'Commander',
            featuredCategory: const Value(testCategory),
            sourceType: const Value('community'),
            createdAt: DateTime.now(),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }

      // Default watchFeaturedCategory (limit 15) caps at 15 items
      final cappedDecks = await exploreDao.watchFeaturedCategory(testCategory).first;
      expect(cappedDecks.length, equals(15));

      // watchFeaturedCategory with limit: null returns all 20 items uncapped
      final uncappedDecks = await exploreDao.watchFeaturedCategory(
        testCategory,
        limit: null,
      ).first;
      expect(uncappedDecks.length, equals(20));

      // watchExploreDecks with featuredCategory also returns all 20 items without cap
      final exploreCategoryDecks = await exploreDao.watchExploreDecks(
        featuredCategory: testCategory,
      ).first;
      expect(exploreCategoryDecks.length, equals(20));
    });
  });

  group('ExploreCarouselSection Interactive See More Button (R2)', () {
    late AppDatabase db;
    late ExploreDeckDao exploreDao;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      exploreDao = ExploreDeckDao(db);
      await ExploreSeederService.seedFromRawDecks(db, FallbackExploreSeeds.allSeeds);
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('Renders See More > button with normalized keys and chevron icon', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            exploreDeckDaoProvider.overrideWithValue(exploreDao),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    ExploreCarouselSection(category: 'Suggested Commanders'),
                    ExploreCarouselSection(category: 'From Top Deck Builders'),
                    ExploreCarouselSection(category: 'Popular Standard Decks'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check Suggested Commanders button key
      expect(find.byKey(const Key('explore_carousel_see_more_suggested_commanders')), findsOneWidget);

      // Check From Top Deck Builders primary key and alias key
      expect(find.byKey(const Key('explore_carousel_see_more_top_builders')), findsOneWidget);
      expect(find.byKey(const Key('explore_carousel_see_more_from_top_deck_builders')), findsOneWidget);

      // Check Popular Standard Decks primary key and alias key
      expect(find.byKey(const Key('explore_carousel_see_more_popular_standard')), findsOneWidget);
      expect(find.byKey(const Key('explore_carousel_see_more_popular_standard_decks')), findsOneWidget);

      // Verify chevron icons are present
      expect(find.byIcon(Icons.chevron_right_rounded), findsNWidgets(3));
      expect(find.text('See More'), findsNWidgets(3));
    });

    testWidgets('Tapping See More triggers onSeeMore callback when provided', (tester) async {
      bool seeMoreTapped = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            exploreDeckDaoProvider.overrideWithValue(exploreDao),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ExploreCarouselSection(
                category: 'Suggested Commanders',
                onSeeMore: () => seeMoreTapped = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('explore_carousel_see_more_suggested_commanders')));
      await tester.pumpAndSettle();

      expect(seeMoreTapped, isTrue);
    });

    testWidgets('Tapping See More updates exploreDrillDownCategoryProvider by default', (tester) async {
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
              body: ExploreCarouselSection(
                category: 'From Top Deck Builders',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(container.read(exploreDrillDownCategoryProvider), isNull);

      await tester.tap(find.byKey(const Key('explore_carousel_see_more_top_builders')));
      await tester.pumpAndSettle();

      expect(container.read(exploreDrillDownCategoryProvider), equals('From Top Deck Builders'));
    });
  });

  group('ExploreCategoryDrillDownView & ExploreDecksTabView Integration (R2)', () {
    late AppDatabase db;
    late ExploreDeckDao exploreDao;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      exploreDao = ExploreDeckDao(db);
      await ExploreSeederService.seedFromRawDecks(db, FallbackExploreSeeds.allSeeds);
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('Tapping See More on Suggested Commanders opens drill-down view with header and 2-column grid', (tester) async {
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

      // Initially discovery feed carousels are present
      expect(find.byKey(const Key('explore_carousel_suggested_commanders')), findsOneWidget);
      expect(find.byKey(const Key('explore_carousel_top_builders')), findsOneWidget);
      expect(find.byKey(const Key('explore_carousel_popular_standard')), findsOneWidget);

      // Tap See More > on Suggested Commanders
      await tester.tap(find.byKey(const Key('explore_carousel_see_more_suggested_commanders')));
      await tester.pumpAndSettle();

      // Drill-down header bar elements are visible
      expect(find.byKey(const Key('explore_drill_down_title')), findsOneWidget);
      expect(find.text('Suggested Commanders'), findsOneWidget);
      expect(find.byKey(const Key('explore_drill_down_back_button')), findsOneWidget);
      expect(find.byKey(const Key('explore_drill_down_reset_button')), findsOneWidget);
      expect(find.byKey(const Key('explore_drill_down_count_badge')), findsOneWidget);
      expect(find.byKey(const Key('explore_decks_count_badge')), findsOneWidget);

      // Verify count in count badge reflects matching database decks
      final expectedCount = await exploreDao.getFilteredExploreDeckCount(
        featuredCategory: 'Suggested Commanders',
      );
      expect(find.text('$expectedCount decks'), findsOneWidget);

      // Tapping back button returns to the discovery feed
      await tester.tap(find.byKey(const Key('explore_drill_down_back_button')));
      await tester.pumpAndSettle();

      // All 3 carousels should be visible again
      expect(find.byKey(const Key('explore_carousel_suggested_commanders')), findsOneWidget);
      expect(find.byKey(const Key('explore_carousel_top_builders')), findsOneWidget);
      expect(find.byKey(const Key('explore_carousel_popular_standard')), findsOneWidget);
    });

    testWidgets('Tapping Reset button in drill-down view returns to discovery feed', (tester) async {
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

      // Tap See More on From Top Deck Builders
      await tester.tap(find.byKey(const Key('explore_carousel_see_more_top_builders')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('explore_drill_down_title')), findsOneWidget);
      expect(find.text('From Top Deck Builders'), findsOneWidget);

      // Tap Reset button
      await tester.tap(find.byKey(const Key('explore_drill_down_reset_button')));
      await tester.pumpAndSettle();

      // Returned to discovery feed
      expect(find.byKey(const Key('explore_carousel_top_builders')), findsOneWidget);
    });

    testWidgets('PopScope handles system back pop by returning to discovery feed', (tester) async {
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
      container.read(exploreDrillDownCategoryProvider.notifier).state = 'Popular Standard Decks';
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('explore_drill_down_title')), findsOneWidget);
      expect(find.text('Popular Standard Decks'), findsOneWidget);

      // Simulate system back pop by finding the PopScope and invoking onPopInvokedWithResult
      final popScopeFinder = find.byKey(const Key('explore_drill_down_pop_scope'));
      expect(popScopeFinder, findsOneWidget);
      final popScopeWidget = tester.widget<PopScope<Object?>>(popScopeFinder);
      popScopeWidget.onPopInvokedWithResult!(false, null);
      await tester.pumpAndSettle();

      expect(container.read(exploreDrillDownCategoryProvider), isNull);
      expect(find.byKey(const Key('explore_carousel_popular_standard')), findsOneWidget);
    });

    testWidgets('Standalone ExploreCategoryDrillDownScreen renders and handles back cleanly', (tester) async {
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
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  key: const Key('push_screen_button'),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ExploreCategoryDrillDownScreen(
                          category: 'Suggested Commanders',
                        ),
                      ),
                    );
                  },
                  child: const Text('Push Screen'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Push screen
      await tester.tap(find.byKey(const Key('push_screen_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('explore_drill_down_title')), findsOneWidget);
      expect(find.text('Suggested Commanders'), findsOneWidget);

      // Tap back button to pop
      await tester.tap(find.byKey(const Key('explore_drill_down_back_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('push_screen_button')), findsOneWidget);
    });
  });
}
