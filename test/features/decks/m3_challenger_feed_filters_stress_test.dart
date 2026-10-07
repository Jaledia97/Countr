import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/decks/data/daos/explore_deck_dao.dart';
import 'package:countr/features/decks/domain/models/explore_deck_models.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/decks/presentation/providers/explore_deck_providers.dart';
import 'package:countr/features/decks/presentation/screens/decks_screen.dart';
import 'package:countr/features/decks/presentation/widgets/explore/explore_carousel_section.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  late AppDatabase db;
  late VaultDao vaultDao;
  late ExploreDeckDao exploreDao;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    vaultDao = VaultDao(db);
    exploreDao = ExploreDeckDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  Widget createSubject({
    int initialTopTab = 1,
    ProviderContainer? container,
  }) {
    if (container != null) {
      return UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: DecksScreen(),
        ),
      );
    }
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        vaultDaoProvider.overrideWithValue(vaultDao),
        exploreDeckDaoProvider.overrideWithValue(exploreDao),
        decksTopTabProvider.overrideWith((ref) => initialTopTab),
      ],
      child: const MaterialApp(
        home: DecksScreen(),
      ),
    );
  }

  group('Milestone 3 Empirical Adversarial Stress Suite', () {
    // =========================================================================
    // GROUP 1: Extreme Viewport Geometry & High-Velocity Scrolling Invariants
    // =========================================================================
    group('1. Viewport Geometry & Rapid Bidirectional Scrolling Invariants', () {
      testWidgets(
        '1.1 Narrow constrained viewport (320x568) handles rapid bidirectional scrolling without RenderFlex overflow',
        (tester) async {
          // Constrained mobile viewport (iPhone SE 1st gen)
          tester.view.physicalSize = const Size(320, 568);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);

          final now = DateTime.now();

          // Seed 20 decks with extremely long names, extreme prices, and varying identities
          for (int i = 1; i <= 20; i++) {
            await db.into(db.exploreDecks).insert(
              ExploreDecksCompanion.insert(
                id: 'stress_deck_$i',
                name: 'Extremely Long Deck Name #$i For Stress Testing RenderFlex Overflows and Sizing Limits',
                format: i % 2 == 0 ? 'Commander' : 'Modern',
                tcgDomain: const Value('mtg'),
                sourceType: i % 3 == 0 ? const Value('official') : const Value('community'),
                creatorName: Value(i % 3 == 0 ? 'Official WotC' : '@VeryLongAuthorNameWithSpecialChars_$i'),
                commanderName: const Value('Nicol Bolas, the Ravager // Nicol Bolas, the Arisen'),
                featuredCategory: i <= 3
                    ? const Value('Suggested Commanders')
                    : (i <= 6 ? const Value('From Top Deck Builders') : const Value('Popular Standard Decks')),
                colorIdentity: const Value('["U","B","R"]'),
                cardCount: const Value(100),
                estimatedPrice: Value(i == 20 ? 12500.0 : 49.99 * i),
                upvotes: Value(100 * i),
                downvotes: Value(5 * i),
                score: Value(95 * i),
                createdAt: now.subtract(Duration(hours: i)),
                updatedAt: Value(now),
                isDeleted: const Value(false),
              ),
            );
          }

          final caughtErrors = <FlutterErrorDetails>[];
          final originalOnError = FlutterError.onError;
          FlutterError.onError = (details) {
            caughtErrors.add(details);
          };

          try {
            await tester.pumpWidget(createSubject(initialTopTab: 1));
            await tester.pumpAndSettle();

            // Perform rapid bidirectional vertical flings
            final scrollKeyFinder = find.byKey(const PageStorageKey('explore_decks_scroll_key'));
            expect(scrollKeyFinder, findsOneWidget);

            for (int fling = 0; fling < 4; fling++) {
              await tester.fling(scrollKeyFinder, const Offset(0, -900), 3000);
              await tester.pumpAndSettle();

              await tester.fling(scrollKeyFinder, const Offset(0, 900), 3000);
              await tester.pumpAndSettle();
            }

            // Verify UI didn't break and header controls remain interactive
            expect(find.byKey(const Key('explore_search_input')), findsOneWidget);
            expect(find.byKey(const Key('explore_pill_all')), findsOneWidget);
          } finally {
            FlutterError.onError = originalOnError;
          }

          expect(
            caughtErrors.any((e) => e.toString().contains('RenderFlex overflowed')),
            isFalse,
            reason: 'RenderFlex overflow detected in ExploreCarouselSection header: '
                '${caughtErrors.where((e) => e.toString().contains("RenderFlex overflowed")).map((e) => e.exceptionAsString()).toList()}',
          );
        },
      );

      testWidgets(
        '1.2 High-velocity horizontal scrolling across all 3 carousels without clipping or overflow',
        (tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);

          final now = DateTime.now();

          // Seed multiple decks into each carousel
          final categories = [
            'Suggested Commanders',
            'From Top Deck Builders',
            'Popular Standard Decks',
          ];

          for (final cat in categories) {
            for (int i = 1; i <= 8; i++) {
              await db.into(db.exploreDecks).insert(
                ExploreDecksCompanion.insert(
                  id: 'carousel_${cat}_$i',
                  name: '$cat Deck #$i',
                  format: 'Commander',
                  tcgDomain: const Value('mtg'),
                  sourceType: const Value('community'),
                  creatorName: Value('@Creator_$i'),
                  commanderName: Value('Commander $i'),
                  featuredCategory: Value(cat),
                  colorIdentity: const Value('["W","U"]'),
                  cardCount: const Value(100),
                  estimatedPrice: Value(80.0 + i),
                  upvotes: Value(10 + i),
                  score: Value(10 + i),
                  createdAt: now,
                  updatedAt: Value(now),
                  isDeleted: const Value(false),
                ),
              );
            }
          }

          final caughtErrors = <FlutterErrorDetails>[];
          final originalOnError = FlutterError.onError;
          FlutterError.onError = (details) {
            caughtErrors.add(details);
          };

          try {
            await tester.pumpWidget(createSubject(initialTopTab: 1));
            await tester.pumpAndSettle();

            // Horizontal scroll in Carousel 1
            final c1Finder = find.byKey(const Key('explore_carousel_suggested_commanders'));
            expect(c1Finder, findsOneWidget);
            final c1Scrollable = find.descendant(of: c1Finder, matching: find.byType(Scrollable)).first;

            await tester.fling(c1Scrollable, const Offset(-600, 0), 2000);
            await tester.pumpAndSettle();

            await tester.fling(c1Scrollable, const Offset(600, 0), 2000);
            await tester.pumpAndSettle();

            // Scroll main list down to bring Carousel 2 and Carousel 3 into view
            final scrollKeyFinder = find.byKey(const PageStorageKey('explore_decks_scroll_key'));
            await tester.drag(scrollKeyFinder, const Offset(0, -600));
            await tester.pumpAndSettle();

            final c2Finder = find.byKey(const Key('explore_carousel_top_builders'));
            expect(c2Finder, findsOneWidget);
            final c2Scrollable = find.descendant(of: c2Finder, matching: find.byType(Scrollable)).first;

            await tester.fling(c2Scrollable, const Offset(-500, 0), 1500);
            await tester.pumpAndSettle();

            // Drag down further to reach Popular Standard
            await tester.drag(scrollKeyFinder, const Offset(0, -600));
            await tester.pumpAndSettle();

            final c3Finder = find.byKey(const Key('explore_carousel_popular_standard'));
            expect(c3Finder, findsOneWidget);
            final c3Scrollable = find.descendant(of: c3Finder, matching: find.byType(Scrollable)).first;

            await tester.fling(c3Scrollable, const Offset(-500, 0), 1500);
            await tester.pumpAndSettle();
          } finally {
            FlutterError.onError = originalOnError;
          }

          expect(
            caughtErrors.any((e) => e.toString().contains('RenderFlex overflowed')),
            isFalse,
            reason: 'RenderFlex overflow detected in ExploreCarouselSection header: '
                '${caughtErrors.where((e) => e.toString().contains("RenderFlex overflowed")).map((e) => e.exceptionAsString()).toList()}',
          );
        },
      );

      testWidgets(
        '1.3 Tablet wide viewport (1200x800) layout stability and 2-column grid geometry integrity',
        (tester) async {
          tester.view.physicalSize = const Size(1200, 800);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);

          final now = DateTime.now();
          for (int i = 1; i <= 10; i++) {
            await db.into(db.exploreDecks).insert(
              ExploreDecksCompanion.insert(
                id: 'wide_deck_$i',
                name: 'Wide Deck #$i',
                format: 'Commander',
                tcgDomain: const Value('mtg'),
                sourceType: const Value('community'),
                creatorName: Value('@Brewer_$i'),
                colorIdentity: const Value('["G"]'),
                cardCount: const Value(100),
                estimatedPrice: Value(50.0 + i),
                upvotes: const Value(5),
                score: const Value(5),
                createdAt: now,
                updatedAt: Value(now),
                isDeleted: const Value(false),
              ),
            );
          }

          await tester.pumpWidget(createSubject(initialTopTab: 1));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);

          final gridFinder = find.byType(SliverGrid);
          expect(gridFinder, findsWidgets);

          final sliverGrid = tester.widget<SliverGrid>(gridFinder.first);
          final delegate = sliverGrid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
          expect(delegate.crossAxisCount, 2);
          expect(delegate.childAspectRatio, 0.72);
        },
      );
    });

    // =========================================================================
    // GROUP 2: Deep Filter Modal Edge Cases & Boundary Conditions
    // =========================================================================
    group('2. Deep Filter Modal Edge Cases & Boundary Conditions', () {
      test(
        r'2.1 Extreme Price Boundaries ($0.00, $50.00, $50.01, $200.00, $200.01, $12,500.00+)',
        () async {
          final now = DateTime.now();

          // Seed decks at boundary prices
          final boundaryDecks = [
            ('deck_free', 'Free Pauper Proxy', 0.0),
            ('deck_50_exact', 'Exact 50 Deck', 50.0),
            ('deck_50_01', 'Mid Lower Bound Deck', 50.01),
            ('deck_200_exact', 'Exact 200 Deck', 200.0),
            ('deck_200_01', 'High Lower Bound Deck', 200.01),
            ('deck_vintage', 'Vintage Lotus Deck', 12500.0),
          ];

          for (final (id, name, price) in boundaryDecks) {
            await db.into(db.exploreDecks).insert(
              ExploreDecksCompanion.insert(
                id: id,
                name: name,
                format: 'Commander',
                tcgDomain: const Value('mtg'),
                sourceType: const Value('community'),
                creatorName: const Value('@BoundaryTester'),
                colorIdentity: const Value('["W"]'),
                cardCount: const Value(100),
                estimatedPrice: Value(price),
                upvotes: const Value(1),
                score: const Value(1),
                createdAt: now,
                updatedAt: Value(now),
                isDeleted: const Value(false),
              ),
            );
          }

          // 1. Budget: $0-$50 (should match 0.0 and 50.0, but NOT 50.01)
          final budgetResults = await exploreDao.watchExploreDecks(
            filter: const ExploreFilterState(priceRange: 'budget_0_50'),
          ).first;
          final budgetIds = budgetResults.map((d) => d.id).toSet();
          expect(budgetIds, containsAll(['deck_free', 'deck_50_exact']));
          expect(budgetIds.contains('deck_50_01'), isFalse);
          expect(budgetIds.contains('deck_200_exact'), isFalse);
          expect(budgetIds.contains('deck_vintage'), isFalse);

          // 2. Mid: $50-$200 (should match 50.01 and 200.0, but NOT 50.0 or 200.01)
          final midResults = await exploreDao.watchExploreDecks(
            filter: const ExploreFilterState(priceRange: 'mid_50_200'),
          ).first;
          final midIds = midResults.map((d) => d.id).toSet();
          expect(midIds, containsAll(['deck_50_01', 'deck_200_exact']));
          expect(midIds.contains('deck_free'), isFalse);
          expect(midIds.contains('deck_50_exact'), isFalse);
          expect(midIds.contains('deck_200_01'), isFalse);
          expect(midIds.contains('deck_vintage'), isFalse);

          // 3. High: $200+ (should match 200.01 and 12500.0, but NOT 200.0)
          final highResults = await exploreDao.watchExploreDecks(
            filter: const ExploreFilterState(priceRange: 'high_200_plus'),
          ).first;
          final highIds = highResults.map((d) => d.id).toSet();
          expect(highIds, containsAll(['deck_200_01', 'deck_vintage']));
          expect(highIds.contains('deck_free'), isFalse);
          expect(highIds.contains('deck_50_exact'), isFalse);
          expect(highIds.contains('deck_200_exact'), isFalse);

          // 4. Any Price: 'all' (should match all 6)
          final allResults = await exploreDao.watchExploreDecks(
            filter: const ExploreFilterState(priceRange: 'all'),
          ).first;
          expect(allResults.length, 6);
        },
      );

      test(
        '2.2 Color Identity Combinations & Match Modes (All 6 colors WUBRGC, Colorless, Subsets)',
        () async {
          final now = DateTime.now();

          // Seed decks with various color combinations
          final colorDecks = [
            ('c_colorless', 'Colorless Tron', '[]'),
            ('c_mono_w', 'Mono White Heliod', '["W"]'),
            ('c_wu', 'Azorius Control', '["W","U"]'),
            ('c_wub', 'Esper Blink', '["W","U","B"]'),
            ('c_wubr', '4-Color Yore-Tiller', '["W","U","B","R"]'),
            ('c_wubrg', '5-Color Omnath', '["W","U","B","R","G"]'),
          ];

          for (final (id, name, colorsJson) in colorDecks) {
            await db.into(db.exploreDecks).insert(
              ExploreDecksCompanion.insert(
                id: id,
                name: name,
                format: 'Commander',
                tcgDomain: const Value('mtg'),
                sourceType: const Value('community'),
                creatorName: const Value('@ColorTester'),
                colorIdentity: Value(colorsJson),
                cardCount: const Value(100),
                estimatedPrice: const Value(100.0),
                upvotes: const Value(1),
                score: const Value(1),
                createdAt: now,
                updatedAt: Value(now),
                isDeleted: const Value(false),
              ),
            );
          }

          // Case A: Only Colorless ("C") selected
          final colorlessResults = await exploreDao.watchExploreDecks(
            filter: const ExploreFilterState(colors: ['C']),
          ).first;
          expect(colorlessResults.map((d) => d.id).toList(), ['c_colorless']);

          // Case B: All 6 colors selected ('W', 'U', 'B', 'R', 'G', 'C')
          // Mode: 'including' -> Must contain W, U, B, R, G -> Only 5-color matches
          final includingAll = await exploreDao.watchExploreDecks(
            filter: const ExploreFilterState(
              colors: ['W', 'U', 'B', 'R', 'G', 'C'],
              colorMatchMode: 'including',
            ),
          ).first;
          expect(includingAll.map((d) => d.id).toList(), ['c_wubrg']);

          // Mode: 'exactly' -> Must contain W, U, B, R, G and no other -> Only 5-color matches
          final exactlyAll = await exploreDao.watchExploreDecks(
            filter: const ExploreFilterState(
              colors: ['W', 'U', 'B', 'R', 'G', 'C'],
              colorMatchMode: 'exactly',
            ),
          ).first;
          expect(exactlyAll.map((d) => d.id).toList(), ['c_wubrg']);

          // Mode: 'atMost' -> At most WUBRG (excluded is empty set) -> All 6 decks match
          final atMostAll = await exploreDao.watchExploreDecks(
            filter: const ExploreFilterState(
              colors: ['W', 'U', 'B', 'R', 'G', 'C'],
              colorMatchMode: 'atMost',
            ),
          ).first;
          expect(atMostAll.length, 6);

          // Case C: Azorius ['W', 'U']
          // 1. Including: Matches decks containing both W and U (Azorius, Esper, 4C, 5C)
          final includingWU = await exploreDao.watchExploreDecks(
            filter: const ExploreFilterState(
              colors: ['W', 'U'],
              colorMatchMode: 'including',
            ),
          ).first;
          expect(
            includingWU.map((d) => d.id).toSet(),
            containsAll(['c_wu', 'c_wub', 'c_wubr', 'c_wubrg']),
          );
          expect(includingWU.map((d) => d.id).contains('c_mono_w'), isFalse);
          expect(includingWU.map((d) => d.id).contains('c_colorless'), isFalse);

          // 2. Exactly: Matches ONLY Azorius ['W', 'U']
          final exactlyWU = await exploreDao.watchExploreDecks(
            filter: const ExploreFilterState(
              colors: ['W', 'U'],
              colorMatchMode: 'exactly',
            ),
          ).first;
          expect(exactlyWU.map((d) => d.id).toList(), ['c_wu']);

          // 3. At Most: Matches Colorless, Mono-W, and Azorius WU (does NOT contain B, R, or G)
          final atMostWU = await exploreDao.watchExploreDecks(
            filter: const ExploreFilterState(
              colors: ['W', 'U'],
              colorMatchMode: 'atMost',
            ),
          ).first;
          final atMostWUIds = atMostWU.map((d) => d.id).toSet();
          expect(atMostWUIds, containsAll(['c_colorless', 'c_mono_w', 'c_wu']));
          expect(atMostWUIds.contains('c_wub'), isFalse);
          expect(atMostWUIds.contains('c_wubr'), isFalse);
          expect(atMostWUIds.contains('c_wubrg'), isFalse);
        },
      );

      test(
        '2.3 Commander name substring match: case insensitivity and whitespace handling',
        () async {
          final now = DateTime.now();

          await db.into(db.exploreDecks).insert(
            ExploreDecksCompanion.insert(
              id: 'cmd_deck_1',
              name: 'Infect Counters',
              format: 'Commander',
              tcgDomain: const Value('mtg'),
              sourceType: const Value('community'),
              creatorName: const Value('@ProPlayer'),
              commanderName: const Value("Atraxa, Praetors' Voice"),
              colorIdentity: const Value('["W","U","B","G"]'),
              cardCount: const Value(100),
              estimatedPrice: const Value(250.0),
              upvotes: const Value(10),
              score: const Value(10),
              createdAt: now,
              updatedAt: Value(now),
              isDeleted: const Value(false),
            ),
          );

          // 1. Lowercase substring match "atraxa"
          final match1 = await exploreDao.watchExploreDecks(
            filter: const ExploreFilterState(commanderName: 'atraxa'),
          ).first;
          expect(match1.length, 1);
          expect(match1.first.id, 'cmd_deck_1');

          // 2. Mixed case with whitespace "   PRAETORS   "
          final match2 = await exploreDao.watchExploreDecks(
            filter: const ExploreFilterState(commanderName: '   PRAETORS   '),
          ).first;
          expect(match2.length, 1);
          expect(match2.first.id, 'cmd_deck_1');

          // 3. Substring with no match "Bolas"
          final matchNone = await exploreDao.watchExploreDecks(
            filter: const ExploreFilterState(commanderName: 'Bolas'),
          ).first;
          expect(matchNone, isEmpty);
        },
      );

      test(
        '2.4 Specific card inclusion matching with joined items table',
        () async {
          final now = DateTime.now();

          // Deck 1: Contains Sol Ring and Rhystic Study
          await db.into(db.exploreDecks).insert(
            ExploreDecksCompanion.insert(
              id: 'card_inc_1',
              name: 'Blue Deck',
              format: 'Commander',
              tcgDomain: const Value('mtg'),
              sourceType: const Value('community'),
              creatorName: const Value('@BlueMage'),
              colorIdentity: const Value('["U"]'),
              cardCount: const Value(100),
              estimatedPrice: const Value(150.0),
              upvotes: const Value(5),
              score: const Value(5),
              createdAt: now,
              updatedAt: Value(now),
              isDeleted: const Value(false),
            ),
          );

          await db.into(db.exploreDeckItems).insert(
            ExploreDeckItemsCompanion.insert(
              id: 'item_1_sol',
              exploreDeckId: 'card_inc_1',
              cardName: 'Sol Ring',
              quantity: const Value(1),
            ),
          );

          await db.into(db.exploreDeckItems).insert(
            ExploreDeckItemsCompanion.insert(
              id: 'item_1_rhystic',
              exploreDeckId: 'card_inc_1',
              cardName: 'Rhystic Study',
              quantity: const Value(1),
            ),
          );

          // Deck 2: Contains Sol Ring and Lightning Bolt
          await db.into(db.exploreDecks).insert(
            ExploreDecksCompanion.insert(
              id: 'card_inc_2',
              name: 'Red Deck',
              format: 'Commander',
              tcgDomain: const Value('mtg'),
              sourceType: const Value('community'),
              creatorName: const Value('@RedMage'),
              colorIdentity: const Value('["R"]'),
              cardCount: const Value(100),
              estimatedPrice: const Value(90.0),
              upvotes: const Value(3),
              score: const Value(3),
              createdAt: now,
              updatedAt: Value(now),
              isDeleted: const Value(false),
            ),
          );

          await db.into(db.exploreDeckItems).insert(
            ExploreDeckItemsCompanion.insert(
              id: 'item_2_sol',
              exploreDeckId: 'card_inc_2',
              cardName: 'Sol Ring',
              quantity: const Value(1),
            ),
          );

          await db.into(db.exploreDeckItems).insert(
            ExploreDeckItemsCompanion.insert(
              id: 'item_2_bolt',
              exploreDeckId: 'card_inc_2',
              cardName: 'Lightning Bolt',
              quantity: const Value(1),
            ),
          );

          // Query for Sol Ring -> Matches both
          final solRingDecks = await exploreDao.watchExploreDecks(
            filter: const ExploreFilterState(cardInclusion: 'Sol Ring'),
          ).first;
          expect(solRingDecks.map((d) => d.id).toSet(), {'card_inc_1', 'card_inc_2'});

          // Query for "rhystic" (lowercase partial) -> Matches Deck 1 only
          final rhysticDecks = await exploreDao.watchExploreDecks(
            filter: const ExploreFilterState(cardInclusion: 'rhystic'),
          ).first;
          expect(rhysticDecks.map((d) => d.id).toList(), ['card_inc_1']);

          // Query for "Black Lotus" -> Matches neither
          final lotusDecks = await exploreDao.watchExploreDecks(
            filter: const ExploreFilterState(cardInclusion: 'Black Lotus'),
          ).first;
          expect(lotusDecks, isEmpty);
        },
      );

      testWidgets(
        '2.5 Modal full interaction: select all 6 colors, match modes, price, inputs, then verify Reset restores exact defaults',
        (tester) async {
          final container = ProviderContainer(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              vaultDaoProvider.overrideWithValue(vaultDao),
              exploreDeckDaoProvider.overrideWithValue(exploreDao),
              decksTopTabProvider.overrideWith((ref) => 1),
            ],
          );

          await tester.pumpWidget(createSubject(container: container));
          await tester.pumpAndSettle();

          // Open filter modal
          await tester.tap(find.byKey(const Key('explore_filter_button')));
          await tester.pumpAndSettle();

          expect(find.byKey(const Key('explore_filter_modal')), findsOneWidget);

          // 1. Select all 6 colors (W, U, B, R, G, C)
          final colorKeys = ['W', 'U', 'B', 'R', 'G', 'C'];
          for (final c in colorKeys) {
            await tester.tap(find.byKey(Key('explore_filter_color_$c')));
            await tester.pumpAndSettle();
          }

          // 2. Switch match mode to "atMost"
          await tester.tap(find.byKey(const Key('explore_filter_mode_atMost')));
          await tester.pumpAndSettle();

          // 3. Select Price $200+
          await tester.tap(find.byKey(const Key('explore_filter_price_200_plus')));
          await tester.pumpAndSettle();

          // 4. Enter Commander Name
          await tester.enterText(
            find.byKey(const Key('explore_filter_commander_input')),
            'Atraxa, Praetors Voice',
          );
          await tester.pumpAndSettle();

          // 5. Enter Specific Card Inclusion
          await tester.enterText(
            find.byKey(const Key('explore_filter_card_input')),
            'Doubling Season',
          );
          await tester.pumpAndSettle();

          // 6. Tap Reset button
          final resetButton = find.byKey(const Key('explore_filter_reset_button'));
          expect(resetButton, findsOneWidget);
          await tester.tap(resetButton);
          await tester.pumpAndSettle();

          // Verify state provider is immediately reset
          final resetState = container.read(exploreFilterStateProvider);
          expect(resetState.isEmpty, isTrue);
          expect(resetState.format, isNull);
          expect(resetState.colors, isEmpty);
          expect(resetState.colorMatchMode, 'including');
          expect(resetState.priceRange, 'all');
          expect(resetState.commanderName, isNull);
          expect(resetState.cardInclusion, isNull);

          // Text fields in modal should also be cleared
          final commanderField = tester.widget<TextField>(
            find.byKey(const Key('explore_filter_commander_input')),
          );
          expect(commanderField.controller?.text, '');

          final cardField = tester.widget<TextField>(
            find.byKey(const Key('explore_filter_card_input')),
          );
          expect(cardField.controller?.text, '');

          // Tap Apply Filters to close modal with reset state
          await tester.tap(find.byKey(const Key('explore_filter_apply_button')));
          await tester.pumpAndSettle();

          expect(find.byKey(const Key('explore_filter_modal')), findsNothing);
          expect(container.read(exploreFilterStateProvider).isEmpty, isTrue);
        },
      );
    });

    // =========================================================================
    // GROUP 3: Interspersed Layout & Category Pill Invariants
    // =========================================================================
    group('3. Interspersed Layout & Category Pill Invariants', () {
      testWidgets(
        '3.1 Category pills toggle dynamically: Official WotC vs Community vs All without disappearing or throwing errors',
        (tester) async {
          final now = DateTime.now();

          // Seed 2 official decks and 2 community decks
          await db.into(db.exploreDecks).insert(
            ExploreDecksCompanion.insert(
              id: 'official_1',
              name: 'WotC Official Challenger',
              format: 'Standard',
              tcgDomain: const Value('mtg'),
              sourceType: const Value('official'),
              creatorName: const Value('Official WotC'),
              colorIdentity: const Value('["W","U"]'),
              cardCount: const Value(60),
              estimatedPrice: const Value(40.0),
              upvotes: const Value(20),
              score: const Value(20),
              createdAt: now,
              updatedAt: Value(now),
              isDeleted: const Value(false),
            ),
          );

          await db.into(db.exploreDecks).insert(
            ExploreDecksCompanion.insert(
              id: 'community_1',
              name: 'Community Brew EDH',
              format: 'Commander',
              tcgDomain: const Value('mtg'),
              sourceType: const Value('community'),
              creatorName: const Value('@BrewMaster'),
              colorIdentity: const Value('["B","R"]'),
              cardCount: const Value(100),
              estimatedPrice: const Value(120.0),
              upvotes: const Value(15),
              score: const Value(15),
              createdAt: now,
              updatedAt: Value(now),
              isDeleted: const Value(false),
            ),
          );

          final container = ProviderContainer(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              vaultDaoProvider.overrideWithValue(vaultDao),
              exploreDeckDaoProvider.overrideWithValue(exploreDao),
              decksTopTabProvider.overrideWith((ref) => 1),
            ],
          );

          await tester.pumpWidget(createSubject(container: container));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);

          // Initially "All": both decks visible in feed
          expect(find.text('WotC Official Challenger'), findsOneWidget);
          expect(find.text('Community Brew EDH'), findsOneWidget);

          // Switch to Official (WotC)
          await tester.tap(find.byKey(const Key('explore_pill_official')));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(container.read(activeExploreCategoryProvider), ExploreCategory.official);
          expect(find.text('WotC Official Challenger'), findsOneWidget);
          expect(find.text('Community Brew EDH'), findsNothing);

          // Switch to Community
          await tester.tap(find.byKey(const Key('explore_pill_community')));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(container.read(activeExploreCategoryProvider), ExploreCategory.community);
          expect(find.text('WotC Official Challenger'), findsNothing);
          expect(find.text('Community Brew EDH'), findsOneWidget);

          // Switch back to All
          await tester.tap(find.byKey(const Key('explore_pill_all')));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(container.read(activeExploreCategoryProvider), ExploreCategory.all);
          expect(find.text('WotC Official Challenger'), findsOneWidget);
          expect(find.text('Community Brew EDH'), findsOneWidget);
        },
      );

      testWidgets(
        '3.2 Feed slice partitioning handles sparse and empty datasets gracefully without range errors',
        (tester) async {
          tester.view.physicalSize = const Size(800, 1400);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);

          // Empty dataset initially
          await tester.pumpWidget(createSubject(initialTopTab: 1));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          // Empty indicator displayed
          expect(
            find.text('No community or precon decks found in this category'),
            findsOneWidget,
          );
          // Carousels still mounted
          expect(find.byKey(const Key('explore_carousel_suggested_commanders')), findsOneWidget);

          // Now seed exactly 2 decks (sparse dataset: slice 1 has 2 items, slices 2 & 3 empty)
          final now = DateTime.now();
          for (int i = 1; i <= 2; i++) {
            await db.into(db.exploreDecks).insert(
              ExploreDecksCompanion.insert(
                id: 'sparse_deck_$i',
                name: 'Sparse Deck #$i',
                format: 'Commander',
                tcgDomain: const Value('mtg'),
                sourceType: const Value('community'),
                creatorName: Value('@Sparse_$i'),
                colorIdentity: const Value('["G"]'),
                cardCount: const Value(100),
                estimatedPrice: Value(50.0 + i),
                upvotes: const Value(5),
                score: const Value(5),
                createdAt: now,
                updatedAt: Value(now),
                isDeleted: const Value(false),
              ),
            );
          }

          await tester.pumpWidget(createSubject(initialTopTab: 1));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.text('Sparse Deck #1'), findsOneWidget);
          expect(find.text('Sparse Deck #2'), findsOneWidget);
          expect(find.text('No community or precon decks found in this category'), findsNothing);
        },
      );

      testWidgets(
        '3.3 Rapid transitions between Search Mode and Discovery Feed Mode preserve state and avoid jank',
        (tester) async {
          final now = DateTime.now();
          await db.into(db.exploreDecks).insert(
            ExploreDecksCompanion.insert(
              id: 'search_mode_deck',
              name: 'Rapid Search Target Deck',
              format: 'Modern',
              tcgDomain: const Value('mtg'),
              sourceType: const Value('community'),
              creatorName: const Value('@Searcher'),
              colorIdentity: const Value('["R"]'),
              cardCount: const Value(60),
              estimatedPrice: const Value(75.0),
              upvotes: const Value(10),
              score: const Value(10),
              createdAt: now,
              updatedAt: Value(now),
              isDeleted: const Value(false),
            ),
          );

          await tester.pumpWidget(createSubject(initialTopTab: 1));
          await tester.pumpAndSettle();

          final searchInput = find.byKey(const Key('explore_search_input'));
          expect(searchInput, findsOneWidget);

          // Alternate 5 times rapidly between typing and clearing
          for (int cycle = 0; cycle < 5; cycle++) {
            await tester.enterText(searchInput, 'Rapid');
            await tester.pumpAndSettle();

            expect(find.byType(ExploreCarouselSection), findsNothing);
            expect(find.byKey(const Key('explore_search_group_name')), findsOneWidget);
            expect(tester.takeException(), isNull);

            final clearButton = find.byKey(const Key('explore_search_clear_button'));
            await tester.tap(clearButton);
            await tester.pumpAndSettle();

            expect(find.byType(ExploreCarouselSection), findsWidgets);
            expect(find.byKey(const Key('explore_search_group_name')), findsNothing);
            expect(tester.takeException(), isNull);
          }
        },
      );
    });
  });
}
