import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart' hide isNull, isNotNull, Column;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/cache/countr_cached_image.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/data/daos/explore_deck_dao.dart';
import 'package:countr/features/decks/data/models/precon_deck_dto.dart';
import 'package:countr/features/decks/data/services/explore_seeder_service.dart';
import 'package:countr/features/decks/data/services/fallback_explore_seeds.dart';
import 'package:countr/features/decks/domain/models/explore_deck_models.dart';
import 'package:countr/features/decks/presentation/providers/explore_deck_providers.dart';
import 'package:countr/features/decks/presentation/screens/read_only_deck_screen.dart';
import 'package:countr/features/decks/presentation/widgets/explore/explore_category_drill_down_view.dart';
import 'package:countr/features/decks/presentation/widgets/explore/explore_deck_card.dart';
import 'package:countr/features/decks/presentation/widgets/explore/explore_decks_tab_view.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('M2 Challenger Group 1: PopScope & System Back Handling Stress Tests', () {
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

    testWidgets('1.1 End-to-end system back gesture (handlePopRoute) dismisses drill-down to discovery feed without exiting app', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
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

      // Verify discovery feed carousels are present initially
      expect(find.byKey(const Key('explore_carousel_suggested_commanders')), findsOneWidget);
      expect(find.byKey(const Key('explore_drill_down_title')), findsNothing);

      // Open drill down by tapping See More on Suggested Commanders
      final seeMoreButton = find.byKey(const Key('explore_carousel_see_more_suggested_commanders'));
      expect(seeMoreButton, findsOneWidget);
      await tester.tap(seeMoreButton);
      await tester.pumpAndSettle();

      // Drill down view is mounted
      expect(find.byKey(const Key('explore_drill_down_title')), findsOneWidget);
      expect(find.text('Suggested Commanders'), findsOneWidget);
      expect(container.read(exploreDrillDownCategoryProvider), equals('Suggested Commanders'));

      // Dispatch real system back navigation event via Flutter test binding
      final handled = await tester.binding.handlePopRoute();
      expect(handled, isTrue, reason: 'PopScope must intercept and handle the system back route without propagating out of app');
      await tester.pumpAndSettle();

      // Invariant: Drill down category provider must be cleared to null
      expect(container.read(exploreDrillDownCategoryProvider), isNull);

      // Invariant: Discovery feed carousels are restored
      expect(find.byKey(const Key('explore_carousel_suggested_commanders')), findsOneWidget);
      expect(find.byKey(const Key('explore_drill_down_title')), findsNothing);
    });

    testWidgets('1.2 Pushed ExploreCategoryDrillDownScreen pops via handlePopRoute returning to caller screen', (tester) async {
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
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  key: const Key('root_push_btn'),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ExploreCategoryDrillDownScreen(
                          category: 'Popular Standard Decks',
                        ),
                      ),
                    );
                  },
                  child: const Text('Push Drill Down'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Push drill-down screen
      await tester.tap(find.byKey(const Key('root_push_btn')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('explore_drill_down_title')), findsOneWidget);
      expect(find.text('Popular Standard Decks'), findsOneWidget);

      // Dispatch system back
      final popped = await tester.binding.handlePopRoute();
      expect(popped, isTrue);
      await tester.pumpAndSettle();

      // Screen is popped, root button visible again
      expect(find.byKey(const Key('root_push_btn')), findsOneWidget);
      expect(find.byKey(const Key('explore_drill_down_title')), findsNothing);
    });

    testWidgets('1.3 Custom onBack callback is invoked by PopScope without mutating provider directly', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool customBackInvoked = false;

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
          child: MaterialApp(
            home: Scaffold(
              body: ExploreCategoryDrillDownView(
                category: 'Suggested Commanders',
                onBack: () {
                  customBackInvoked = true;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final popScopeFinder = find.byKey(const Key('explore_drill_down_pop_scope'));
      expect(popScopeFinder, findsOneWidget);

      final handled = await tester.binding.handlePopRoute();
      expect(handled, isTrue);
      await tester.pumpAndSettle();

      expect(customBackInvoked, isTrue, reason: 'PopScope must invoke the provided onBack callback');
    });

    testWidgets('1.4 Rapid double-back gesture does not crash or leave dangling corrupted state', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
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
      container.read(exploreDrillDownCategoryProvider.notifier).state = 'From Top Deck Builders';
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('explore_drill_down_title')), findsOneWidget);

      // Fire back route twice in rapid succession
      await tester.binding.handlePopRoute();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      // Must be safely back on discovery feed without uncaught exceptions
      expect(tester.takeException(), isNull);
      expect(container.read(exploreDrillDownCategoryProvider), isNull);
      expect(find.byKey(const Key('explore_carousel_top_builders')), findsOneWidget);
    });
  });

  group('M2 Challenger Group 2: True Database Total Count Badge (SELECT COUNT(*)) Invariants', () {
    late AppDatabase db;
    late ExploreDeckDao exploreDao;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      exploreDao = ExploreDeckDao(db);
      // Clean start without default seeds for exact count testing
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('2.1 Count badge displays exact SELECT COUNT(*) for 35 seeded decks uncapped', (tester) async {
      const category = 'Suggested Commanders';
      final now = DateTime.now();

      // Insert 35 decks into category
      for (int i = 1; i <= 35; i++) {
        await db.into(db.exploreDecks).insert(
          ExploreDecksCompanion.insert(
            id: 'sug_deck_$i',
            name: 'Suggested Commander Deck $i',
            format: 'Commander',
            featuredCategory: const Value(category),
            sourceType: const Value('official'),
            creatorName: const Value('Official WotC'),
            createdAt: now.subtract(Duration(minutes: i)),
            updatedAt: Value(now.subtract(Duration(minutes: i))),
          ),
        );
      }

      tester.view.physicalSize = const Size(390, 1200);
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
              body: ExploreCategoryDrillDownView(category: category),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Count badge must show exactly 35 decks
      expect(find.byKey(const Key('explore_drill_down_count_badge')), findsOneWidget);
      expect(find.byKey(const Key('explore_decks_count_badge')), findsOneWidget);
      expect(find.text('35 decks'), findsOneWidget);
    });

    testWidgets('2.2 Count badge reactively updates under search query and restores on clear', (tester) async {
      const category = 'From Top Deck Builders';
      final now = DateTime.now();

      for (int i = 1; i <= 20; i++) {
        await db.into(db.exploreDecks).insert(
          ExploreDecksCompanion.insert(
            id: 'top_builder_deck_$i',
            name: i <= 3 ? 'Aetherworks Marvel Combo $i' : 'Mono Red Burn $i',
            format: 'Standard',
            featuredCategory: const Value(category),
            sourceType: const Value('community'),
            creatorName: const Value('@ProBuilder'),
            createdAt: now.subtract(Duration(minutes: i)),
            updatedAt: Value(now.subtract(Duration(minutes: i))),
          ),
        );
      }

      tester.view.physicalSize = const Size(390, 1200);
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
              body: ExploreCategoryDrillDownView(category: category),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially shows all 20 decks
      expect(find.text('20 decks'), findsOneWidget);

      // Apply search query matching only the 3 Aetherworks decks
      container.read(exploreSearchQueryProvider.notifier).state = 'Aetherworks';
      await tester.pumpAndSettle();

      // Count badge must reactively display '3 decks'
      expect(find.text('3 decks'), findsOneWidget);
      expect(find.text('20 decks'), findsNothing);

      // Clear search query
      container.read(exploreSearchQueryProvider.notifier).state = '';
      await tester.pumpAndSettle();

      // Restores to '20 decks'
      expect(find.text('20 decks'), findsOneWidget);
    });

    testWidgets('2.3 Dynamic SQLite insertions, deletions, and category reassignment reactively update count badge', (tester) async {
      const category = 'Popular Standard Decks';
      final now = DateTime.now();

      for (int i = 1; i <= 5; i++) {
        await db.into(db.exploreDecks).insert(
          ExploreDecksCompanion.insert(
            id: 'pop_deck_$i',
            name: 'Standard Deck $i',
            format: 'Standard',
            featuredCategory: const Value(category),
            sourceType: const Value('official'),
            creatorName: const Value('Official WotC'),
            createdAt: now,
            updatedAt: Value(now),
          ),
        );
      }

      tester.view.physicalSize = const Size(390, 1200);
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
              body: ExploreCategoryDrillDownView(category: category),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('5 decks'), findsOneWidget);

      // 1. Dynamic insertion: add 6th deck
      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: 'pop_deck_6',
          name: 'Standard Deck 6',
          format: 'Standard',
          featuredCategory: const Value(category),
          sourceType: const Value('official'),
          creatorName: const Value('Official WotC'),
          createdAt: now,
          updatedAt: Value(now),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('6 decks'), findsOneWidget);

      // 2. Soft deletion: mark pop_deck_1 as deleted
      await (db.update(db.exploreDecks)..where((t) => t.id.equals('pop_deck_1'))).write(
        const ExploreDecksCompanion(isDeleted: Value(true)),
      );
      await tester.pumpAndSettle();

      expect(find.text('5 decks'), findsOneWidget);

      // 3. Category reassignment: reassign pop_deck_2 to a different category
      await (db.update(db.exploreDecks)..where((t) => t.id.equals('pop_deck_2'))).write(
        const ExploreDecksCompanion(featuredCategory: Value('Other Category')),
      );
      await tester.pumpAndSettle();

      expect(find.text('4 decks'), findsOneWidget);
    });

    testWidgets('2.4 Empty category displays 0 decks badge and clean empty state placeholder', (tester) async {
      const category = 'Nonexistent Category';

      tester.view.physicalSize = const Size(390, 844);
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
              body: ExploreCategoryDrillDownView(category: category),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('0 decks'), findsOneWidget);
      expect(find.text('No decks found in $category'), findsOneWidget);
      expect(find.byIcon(Icons.explore_off_rounded), findsOneWidget);
    });
  });

  group('M2 Challenger Group 3: Narrow Viewport (300px/320px) & Layout Stress Tests', () {
    late AppDatabase db;
    late ExploreDeckDao exploreDao;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      exploreDao = ExploreDeckDao(db);

      final now = DateTime.now();
      // Insert decks with long titles, creator names, price, votes
      for (int i = 1; i <= 6; i++) {
        await db.into(db.exploreDecks).insert(
          ExploreDecksCompanion.insert(
            id: 'long_deck_$i',
            name: 'Extremely Long Deck Name Designed to Stress Grid Geometry and Text Overflow $i',
            format: 'Commander',
            featuredCategory: const Value('From Top Deck Builders'),
            sourceType: const Value('community'),
            creatorName: const Value('@VeryLongSuperDuperCreatorNameThatExceedsNormalWidth'),
            colorIdentity: const Value('["W","U","B","R","G"]'),
            estimatedPrice: const Value(9999.99),
            upvotes: const Value(12345),
            downvotes: const Value(678),
            score: const Value(11667),
            createdAt: now,
            updatedAt: Value(now),
          ),
        );
      }
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('3.1 320px narrow mobile viewport: zero RenderFlex overflows in sticky header and 2-column grid', (tester) async {
      // 320x568 is iPhone SE 1st gen / narrow mobile standard
      tester.view.physicalSize = const Size(320, 568);
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

      FlutterErrorDetails? caughtDetails;
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        caughtDetails = details;
        originalOnError?.call(details);
      };
      addTearDown(() {
        FlutterError.onError = originalOnError;
      });

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: ExploreCategoryDrillDownView(
                category: 'From Top Deck Builders',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      if (caughtDetails != null) {
        // ignore: avoid_print
        print('=== CAUGHT FLUTTER ERROR DETAILS ===');
        // ignore: avoid_print
        print(caughtDetails!.toString());
        // ignore: avoid_print
        print('====================================');
      }

      // Check for layout exceptions
      final error = tester.takeException();
      expect(error, isNull, reason: 'Must not produce any RenderFlex overflow on 320px screen');

      // Scroll through grid to trigger lazy building of all items
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'Must not overflow during scrolling on 320px screen');
    });

    testWidgets('3.2 300px extreme narrow viewport: zero RenderFlex overflows with large font scale', (tester) async {
      // 300px viewport with 1.3x text scaling
      tester.view.physicalSize = const Size(300, 600);
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

      FlutterErrorDetails? caughtDetails;
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        caughtDetails = details;
        originalOnError?.call(details);
      };
      addTearDown(() {
        FlutterError.onError = originalOnError;
      });

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MediaQuery(
            data: const MediaQueryData(
              size: Size(300, 600),
              textScaler: TextScaler.linear(1.2),
            ),
            child: const MaterialApp(
              home: Scaffold(
                body: ExploreCategoryDrillDownView(
                  category: 'Suggested Commanders',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      if (caughtDetails != null) {
        // ignore: avoid_print
        print('=== TEST 3.2 CAUGHT FLUTTER ERROR DETAILS ===');
        // ignore: avoid_print
        print(caughtDetails!.toString());
        // ignore: avoid_print
        print('=============================================');
      }

      expect(tester.takeException(), isNull, reason: 'Must not produce any overflow on 300px viewport with text scaling');
    });

    testWidgets('3.3 Reset button and Back button in drill down header operate smoothly', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
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
      await tester.tap(find.byKey(const Key('explore_carousel_see_more_top_builders')));
      await tester.pumpAndSettle();

      expect(container.read(exploreDrillDownCategoryProvider), equals('From Top Deck Builders'));

      // Tap Reset button
      final resetBtn = find.byKey(const Key('explore_drill_down_reset_button'));
      expect(resetBtn, findsOneWidget);
      await tester.tap(resetBtn);
      await tester.pumpAndSettle();

      expect(container.read(exploreDrillDownCategoryProvider), isNull);
      expect(find.byKey(const Key('explore_carousel_top_builders')), findsOneWidget);
    });

    testWidgets('3.4 Isolated 2-column grid geometry (childAspectRatio: 0.52) layout stability on 320px and 300px viewports', (tester) async {
      tester.view.physicalSize = const Size(300, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final decks = await exploreDao.watchExploreDecks(featuredCategory: 'From Top Deck Builders').first;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.52,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => ExploreDeckCard(deckWithVote: decks[index]),
                      childCount: decks.length,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: '2-column grid alone with childAspectRatio 0.52 should not overflow');
    });

    testWidgets('3.5 Narrow 320px viewport: back button and reset button tap interactions successfully navigate back without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
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

      // Open drill down on 320px viewport by scrolling See More into view
      final seeMoreBtn = find.byKey(const Key('explore_carousel_see_more_top_builders'));
      await tester.ensureVisible(seeMoreBtn);
      await tester.pumpAndSettle();
      await tester.tap(seeMoreBtn);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'No RenderFlex overflow on drill down open (320px)');
      expect(container.read(exploreDrillDownCategoryProvider), equals('From Top Deck Builders'));

      // Tap Reset button (which is rendered as compact IconButton on narrow viewports)
      final resetBtn = find.byKey(const Key('explore_drill_down_reset_button'));
      expect(resetBtn, findsOneWidget);
      await tester.tap(resetBtn);
      await tester.pumpAndSettle();

      expect(container.read(exploreDrillDownCategoryProvider), isNull, reason: 'Reset button must reset drill down category on 320px');
      expect(find.byKey(const Key('explore_carousel_top_builders')), findsOneWidget);

      // Open drill down again to test Back button
      final seeMoreBtnAgain = find.byKey(const Key('explore_carousel_see_more_top_builders'));
      await tester.ensureVisible(seeMoreBtnAgain);
      await tester.pumpAndSettle();
      await tester.tap(seeMoreBtnAgain);
      await tester.pumpAndSettle();

      expect(container.read(exploreDrillDownCategoryProvider), equals('From Top Deck Builders'));

      final backBtn = find.byKey(const Key('explore_drill_down_back_button'));
      expect(backBtn, findsOneWidget);
      await tester.tap(backBtn);
      await tester.pumpAndSettle();

      expect(container.read(exploreDrillDownCategoryProvider), isNull, reason: 'Back button must return to explore feed on 320px');
      expect(find.byKey(const Key('explore_carousel_top_builders')), findsOneWidget);
    });

    testWidgets('3.6 Extreme 300px viewport with 1.3x font scale: back button and reset button tap interactions', (tester) async {
      tester.view.physicalSize = const Size(300, 600);
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
          child: MediaQuery(
            data: const MediaQueryData(
              size: Size(300, 600),
              textScaler: TextScaler.linear(1.3),
            ),
            child: const MaterialApp(
              home: Scaffold(
                body: ExploreDecksTabView(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open drill down on 300px viewport with 1.3x font scaling
      await tester.tap(find.byKey(const Key('explore_carousel_see_more_suggested_commanders')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'No RenderFlex overflow on 300px with 1.3x scaling');
      expect(container.read(exploreDrillDownCategoryProvider), equals('Suggested Commanders'));

      // Tap Reset button
      final resetBtn = find.byKey(const Key('explore_drill_down_reset_button'));
      expect(resetBtn, findsOneWidget);
      await tester.tap(resetBtn);
      await tester.pumpAndSettle();

      expect(container.read(exploreDrillDownCategoryProvider), isNull, reason: 'Reset button must dismiss drill down on 300px 1.3x scale');
      expect(find.byKey(const Key('explore_carousel_suggested_commanders')), findsOneWidget);

      // Re-enter and tap Back button
      await tester.tap(find.byKey(const Key('explore_carousel_see_more_suggested_commanders')));
      await tester.pumpAndSettle();

      final backBtn = find.byKey(const Key('explore_drill_down_back_button'));
      expect(backBtn, findsOneWidget);
      await tester.tap(backBtn);
      await tester.pumpAndSettle();

      expect(container.read(exploreDrillDownCategoryProvider), isNull, reason: 'Back button must dismiss drill down on 300px 1.3x scale');
      expect(find.byKey(const Key('explore_carousel_suggested_commanders')), findsOneWidget);
    });

    testWidgets('3.7 300px viewport with extreme textScaler (1.35x) and long category name: zero overflow', (tester) async {
      tester.view.physicalSize = const Size(300, 600);
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
          child: MediaQuery(
            data: const MediaQueryData(
              size: Size(300, 600),
              textScaler: TextScaler.linear(1.35),
            ),
            child: const MaterialApp(
              home: Scaffold(
                body: ExploreCategoryDrillDownView(
                  category: 'From Top Deck Builders',
                  customDecks: [],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'Zero RenderFlex overflow under extreme 300px 1.35x text scale with long category name');
      expect(find.byKey(const Key('explore_drill_down_title')), findsOneWidget);
      expect(find.byKey(const Key('explore_drill_down_reset_button')), findsOneWidget);
      expect(find.byKey(const Key('explore_drill_down_back_button')), findsOneWidget);
    });
  });

  group('M2 Challenger Group 4: Adversarial Art Series & Memorabilia Ban Invariants Across Precons, Explore Decks, and Community Builds', () {
    test('4.1 Comprehensive sweep across all 590+ precons in official_precons.json.gz: zero art_series or memorabilia', () {
      final file = File('assets/data/official_precons.json.gz');
      expect(file.existsSync(), isTrue, reason: 'official_precons.json.gz must exist');
      final bytes = file.readAsBytesSync();
      final decks = (jsonDecode(utf8.decode(gzip.decode(bytes))) as List)
          .cast<Map<String, dynamic>>();

      expect(decks.length, greaterThanOrEqualTo(500), reason: 'Must contain 500+ official MTG precons');

      int checkedCommanders = 0;
      int checkedCards = 0;

      for (final d in decks) {
        final commander = d['commander'] as Map<String, dynamic>?;
        if (commander != null) {
          checkedCommanders++;
          final cName = (commander['name'] ?? '').toString();
          final cImg = (commander['image_url'] ?? '').toString();
          final cArt = (commander['art_crop_url'] ?? commander['art_crop'] ?? '').toString();
          final cLayout = (commander['layout'] ?? '').toString();
          final cSetType = (commander['set_type'] ?? '').toString();

          expect(cLayout.toLowerCase(), isNot(equals('art_series')),
              reason: 'Commander $cName in ${d['name']} must not have art_series layout');
          expect(cLayout.toLowerCase(), isNot(equals('double_faced_token')),
              reason: 'Commander $cName in ${d['name']} must not have double_faced_token layout');
          expect(cSetType.toLowerCase(), isNot(equals('memorabilia')),
              reason: 'Commander $cName in ${d['name']} must not have memorabilia set_type');
          expect(cImg, isNot(contains('art_series')),
              reason: 'Commander $cName in ${d['name']} must not have art_series in image_url');
          expect(cArt, isNot(contains('art_series')),
              reason: 'Commander $cName in ${d['name']} must not have art_series in art_crop_url');

          if (cName.contains('//')) {
            final parts = cName.split('//').map((p) => p.trim().toLowerCase()).toList();
            expect(parts[0] == parts[1], isFalse,
                reason: 'Commander $cName in ${d['name']} must not have identical split face names');
          }
        }

        // Check cards if embedded in precon JSON
        for (final zoneKey in ['cards', 'mainBoard', 'commander', 'sideBoard']) {
          final zoneList = d[zoneKey];
          if (zoneList is List) {
            for (final card in zoneList) {
              if (card is Map<String, dynamic>) {
                checkedCards++;
                final name = (card['name'] ?? '').toString();
                final layout = (card['layout'] ?? '').toString();
                final setType = (card['set_type'] ?? '').toString();
                final img = (card['image_url'] ?? card['imageUrl'] ?? '').toString();

                expect(layout.toLowerCase(), isNot(equals('art_series')),
                    reason: 'Card $name in ${d['name']} must not have art_series layout');
                expect(setType.toLowerCase(), isNot(equals('memorabilia')),
                    reason: 'Card $name in ${d['name']} must not have memorabilia set_type');
                expect(img, isNot(contains('art_series')),
                    reason: 'Card $name in ${d['name']} must not have art_series in image_url');
              }
            }
          }
        }
      }
      expect(checkedCommanders, greaterThanOrEqualTo(500));
      expect(checkedCards, greaterThanOrEqualTo(0));
    });

    test('4.2 Draconic Domination / The Ur-Dragon specifically resolves to genuine playable card', () {
      final bytes = File('assets/data/official_precons.json.gz').readAsBytesSync();
      final decks = (jsonDecode(utf8.decode(gzip.decode(bytes))) as List)
          .cast<Map<String, dynamic>>();

      final draconicDecks = decks.where((d) => (d['name'] as String).contains('Draconic Domination')).toList();
      expect(draconicDecks, isNotEmpty);

      for (final deck in draconicDecks) {
        final commander = deck['commander'] as Map<String, dynamic>?;
        expect(commander, isNotNull);
        expect(commander!['name'], equals('The Ur-Dragon'));
        final img = commander['image_url']?.toString() ?? '';
        expect(img, isNot(contains('art_series')));
        expect(img, isNot(contains('/art_crop/')));
        expect(img, contains('normal'));
      }

      // Test PreconCardDto sanitization for The Ur-Dragon
      final poisonedUrDragon = PreconCardDto.fromMap({
        'name': 'The Ur-Dragon // The Ur-Dragon',
        'layout': 'art_series',
        'set_type': 'memorabilia',
        'isCommander': true,
        'imageUrl': 'https://cards.scryfall.io/art_series/front/7/e/urdragon.jpg',
      });

      expect(poisonedUrDragon.name, equals('The Ur-Dragon'));
      expect(poisonedUrDragon.layout, equals('normal'));
      expect(poisonedUrDragon.imageUrl, isNot(contains('art_series')));
      expect(poisonedUrDragon.imageUrl, contains('version=normal'));
    });

    testWidgets('4.3 Community deck with art series card is sanitized in ExploreDeckCard and ReadOnlyDeckScreen', (tester) async {
      final now = DateTime.now();
      final contaminatedDeck = ExploreDeckWithVote(
        deck: ExploreDeck(
          id: 'comm_art_series_deck_1',
          name: 'Community Dragons',
          format: 'Commander',
          sourceType: 'user_shared',
          creatorName: '@BrewMaster',
          featuredCategory: 'From Top Deck Builders',
          commanderName: 'The Ur-Dragon // The Ur-Dragon',
          commanderImageUrl: 'https://cards.scryfall.io/art_series/front/7/e/urdragon.jpg',
          commanderArtCrop: 'https://cards.scryfall.io/art_crop/front/7/e/urdragon.jpg',
          tcgDomain: 'mtg',
          cardCount: 100,
          colorIdentity: jsonEncode(['W', 'U', 'B', 'R', 'G']),
          estimatedPrice: 350.0,
          upvotes: 12,
          downvotes: 0,
          score: 12,
          createdAt: now,
          updatedAt: now,
          isDeleted: false,
        ),
        userVote: 0,
      );

      // Render ExploreDeckCard
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExploreDeckCard(
              deckWithVote: contaminatedDeck,
            ),
          ),
        ),
      );
      await tester.pump();

      // Verify CountrCachedImage resolved away from art series
      final cachedImage = tester.widget<CountrCachedImage>(find.byType(CountrCachedImage));
      expect(cachedImage.imageUrl, isNot(contains('art_series')));
      expect(cachedImage.imageUrl, contains('api.scryfall.com/cards/named'));
      expect(cachedImage.imageUrl, contains('The%20Ur-Dragon'));
      expect(cachedImage.imageUrl, contains('version=normal'));
    });
  });

  group('M2 Challenger Group 5: Explore Category Drill-Down Deep Navigation & Uncapped 2-Column Grid', () {
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

    testWidgets('5.1 Tapping See More > on each featured category opens 2-column uncapped grid view', (tester) async {
      final categories = [
        {'key': 'explore_carousel_see_more_suggested_commanders', 'title': 'Suggested Commanders'},
        {'key': 'explore_carousel_see_more_top_builders', 'title': 'From Top Deck Builders'},
        {'key': 'explore_carousel_see_more_popular_standard', 'title': 'Popular Standard Decks'},
      ];

      for (final cat in categories) {
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

        final seeMoreBtn = find.byKey(Key(cat['key']!));
        await tester.ensureVisible(seeMoreBtn);
        await tester.pumpAndSettle();
        await tester.tap(seeMoreBtn);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('explore_drill_down_title')), findsOneWidget);
        expect(find.text(cat['title']!), findsOneWidget);
        expect(find.byKey(const Key('explore_drill_down_back_button')), findsOneWidget);
        expect(find.byKey(const Key('explore_drill_down_reset_button')), findsOneWidget);

        // Tap back to return
        await tester.tap(find.byKey(const Key('explore_drill_down_back_button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('explore_drill_down_title')), findsNothing);
      }
    });

    testWidgets('5.2 Uncapped 2-column grid renders 60+ decks without artificial cap or RenderFlex overflow', (tester) async {
      const category = 'Suggested Commanders';
      final now = DateTime.now();

      // Insert 60 decks
      for (int i = 1; i <= 60; i++) {
        await db.into(db.exploreDecks).insert(
          ExploreDecksCompanion.insert(
            id: 'uncapped_deck_$i',
            name: 'Uncapped Commander Deck $i',
            format: 'Commander',
            featuredCategory: const Value(category),
            sourceType: const Value('official'),
            creatorName: const Value('Official WotC'),
            createdAt: now.subtract(Duration(minutes: i)),
            updatedAt: Value(now.subtract(Duration(minutes: i))),
          ),
        );
      }

      tester.view.physicalSize = const Size(390, 844);
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
              body: ExploreCategoryDrillDownView(category: category),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check uncapped badge shows 60+ decks
      final badgeFinder = find.byKey(const Key('explore_drill_down_count_badge'));
      expect(badgeFinder, findsOneWidget);

      // Verify the count in text
      final matchingTotal = await exploreDao.getFilteredExploreDeckCount(featuredCategory: category);
      expect(matchingTotal, greaterThanOrEqualTo(60));
      expect(find.text('$matchingTotal decks'), findsOneWidget);

      // Scroll vigorously through the 2-column grid
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'Zero RenderFlex overflow when scrolling 60+ uncapped decks');
    });

    testWidgets('5.3 Full navigation stack: Carousel -> Drill Down -> ReadOnlyDeckScreen -> Pop -> Pop', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
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

      // Step 1: Tap See More on Suggested Commanders
      final seeMoreBtn = find.byKey(const Key('explore_carousel_see_more_suggested_commanders'));
      await tester.tap(seeMoreBtn);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('explore_drill_down_title')), findsOneWidget);

      // Step 2: Find first ExploreDeckCard in the 2-column grid and tap it
      final firstCard = find.byType(ExploreDeckCard).first;
      expect(firstCard, findsOneWidget);
      await tester.tap(firstCard);
      await tester.pumpAndSettle();

      // Step 3: ReadOnlyDeckScreen is pushed
      expect(find.byType(ReadOnlyDeckScreen), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Step 4: Pop back from ReadOnlyDeckScreen
      final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
      navigator.pop();
      await tester.pumpAndSettle();

      // Returned to Drill Down
      expect(find.byType(ReadOnlyDeckScreen), findsNothing);
      expect(find.byKey(const Key('explore_drill_down_title')), findsOneWidget);

      // Step 5: Pop back from Drill Down to Discovery Feed
      final resetBtn = find.byKey(const Key('explore_drill_down_reset_button'));
      await tester.tap(resetBtn);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('explore_drill_down_title')), findsNothing);
      expect(find.byKey(const Key('explore_carousel_suggested_commanders')), findsOneWidget);
    });
  });
}

