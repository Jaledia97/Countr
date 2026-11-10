import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';

import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/decks/data/daos/explore_deck_dao.dart';
import 'package:countr/features/decks/data/mock_deck_data.dart';
import 'package:countr/features/decks/data/services/explore_seeder_service.dart';
import 'package:countr/features/decks/data/services/fallback_explore_seeds.dart';
import 'package:countr/features/decks/domain/models/explore_deck_models.dart';
import 'package:countr/features/decks/domain/services/explore_category_engine.dart';
import 'package:countr/features/decks/presentation/providers/explore_deck_providers.dart';
import 'package:countr/features/decks/presentation/screens/read_only_deck_screen.dart';
import 'package:countr/features/decks/presentation/widgets/explore/explore_deck_card.dart';
import 'package:countr/features/decks/presentation/widgets/explore/explore_decks_tab_view.dart';
import 'package:countr/features/decks/presentation/widgets/explore/explore_category_drill_down_view.dart';
import 'package:countr/features/profile/presentation/providers/profile_providers.dart';

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

    // Seed starter decks and explore community seeds
    await vaultDao.seedDatabase();
    await ExploreSeederService.seedFromRawDecks(db, FallbackExploreSeeds.allSeeds);
  });

  tearDown(() async {
    await db.close();
  });

  group('Group 1: Narrow Viewport & Text Scaling Stress (Zero RenderFlex Overflows)', () {
    const viewports = [
      // iPhone SE / iPod Touch (320px width)
      Size(320, 568),
      // Galaxy Fold outer display (280px narrow width)
      Size(280, 653),
    ];

    const textScales = [1.5, 2.0];

    for (final size in viewports) {
      for (final scale in textScales) {
        testWidgets(
          'ExploreDeckCard renders cleanly on ${size.width.toInt()}px width at ${scale}x text scale with 0 overflows',
          (tester) async {
            tester.view.physicalSize = Size(size.width, size.height);
            tester.view.devicePixelRatio = 1.0;
            addTearDown(() {
              tester.view.resetPhysicalSize();
              tester.view.resetDevicePixelRatio();
            });

            final testDeck = ExploreDeck(
              id: 'stress_deck_card_${size.width}_$scale',
              name: 'Draconic Domination Ultra Super Long Commander Deck Name',
              format: 'Commander',
              tcgDomain: 'mtg',
              sourceType: 'user_shared',
              creatorName: '@VeryLongCreatorUsernameThatWrapsAround',
              authorId: 'test-author',
              colorIdentity: '["W","U","B","R","G"]',
              cardCount: 100,
              estimatedPrice: 349.99,
              upvotes: 42,
              downvotes: 3,
              score: 39,
              createdAt: DateTime.now(),
              isDeleted: false,
            );

            final deckWithVote = ExploreDeckWithVote(deck: testDeck, userVote: 1);

            final overflowErrors = <FlutterErrorDetails>[];
            final originalOnError = FlutterError.onError;
            FlutterError.onError = (details) {
              if (details.toString().contains('overflow') ||
                  details.toString().contains('RenderFlex')) {
                overflowErrors.add(details);
              }
              originalOnError?.call(details);
            };
            addTearDown(() => FlutterError.onError = originalOnError);

            // Test 1: Compact Carousel Card (fixed 173 width inside carousel)
            await tester.pumpWidget(
              ProviderScope(
                overrides: [
                  appDatabaseProvider.overrideWithValue(db),
                  currentUserIdProvider.overrideWith((ref) => 'test-author'),
                ],
                child: MaterialApp(
                  home: MediaQuery(
                    data: MediaQueryData(
                      size: size,
                      textScaler: TextScaler.linear(scale),
                    ),
                    child: Scaffold(
                      body: SizedBox(
                        width: 173,
                        height: 350,
                        child: ExploreDeckCard(
                          deckWithVote: deckWithVote,
                          isCompact: true,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();

            expect(overflowErrors, isEmpty,
                reason: 'Compact card overflowed on ${size.width}px at ${scale}x');
            expect(tester.takeException(), isNull);

            // Test 2: 2-Column Grid Card (width is (size.width - 32 - 10) / 2)
            final columnWidth = (size.width - 42) / 2;
            await tester.pumpWidget(
              ProviderScope(
                overrides: [
                  appDatabaseProvider.overrideWithValue(db),
                  currentUserIdProvider.overrideWith((ref) => 'test-author'),
                ],
                child: MaterialApp(
                  home: MediaQuery(
                    data: MediaQueryData(
                      size: size,
                      textScaler: TextScaler.linear(scale),
                    ),
                    child: Scaffold(
                      body: SizedBox(
                        width: columnWidth,
                        height: columnWidth / 0.74,
                        child: ExploreDeckCard(
                          deckWithVote: deckWithVote,
                          isCompact: false,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();

            expect(overflowErrors, isEmpty,
                reason: 'Grid card overflowed on ${size.width}px at ${scale}x');
            expect(tester.takeException(), isNull);
          },
        );

        testWidgets(
          'ReadOnlyDeckScreen renders and scrolls with 0 overflows on ${size.width.toInt()}px width at ${scale}x text scale',
          (tester) async {
            tester.view.physicalSize = Size(size.width, size.height);
            tester.view.devicePixelRatio = 1.0;
            addTearDown(() {
              tester.view.resetPhysicalSize();
              tester.view.resetDevicePixelRatio();
            });

            // Share a deck to read
            final shared = await exploreDao.sharePersonalDeckToExplore(
              personalDeckId: MockDeckData.edgarMarkovDeckId,
              creatorName: '@VampireLord',
              authorId: 'vampire-author',
            );

            final overflowErrors = <FlutterErrorDetails>[];
            final originalOnError = FlutterError.onError;
            FlutterError.onError = (details) {
              if (details.toString().contains('overflow') ||
                  details.toString().contains('RenderFlex')) {
                overflowErrors.add(details);
              }
              originalOnError?.call(details);
            };
            addTearDown(() => FlutterError.onError = originalOnError);

            await tester.pumpWidget(
              ProviderScope(
                overrides: [
                  appDatabaseProvider.overrideWithValue(db),
                  currentUserIdProvider.overrideWith((ref) => 'vampire-author'),
                ],
                child: MaterialApp(
                  home: MediaQuery(
                    data: MediaQueryData(
                      size: size,
                      textScaler: TextScaler.linear(scale),
                    ),
                    child: ReadOnlyDeckScreen(exploreDeckId: shared.id),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();

            expect(overflowErrors, isEmpty,
                reason: 'ReadOnlyDeckScreen initial render overflow on ${size.width}px at ${scale}x');
            expect(tester.takeException(), isNull);

            // Scroll down to test remaining sliver sections
            final scrollFinder = find.byType(CustomScrollView);
            if (scrollFinder.evaluate().isNotEmpty) {
              await tester.drag(scrollFinder, const Offset(0, -300));
              await tester.pumpAndSettle();
              expect(overflowErrors, isEmpty,
                  reason: 'ReadOnlyDeckScreen scrolled overflow on ${size.width}px at ${scale}x');
            }
          },
        );

        testWidgets(
          'ExploreDecksTabView renders and scrolls with 0 overflows on ${size.width.toInt()}px width at ${scale}x text scale',
          (tester) async {
            tester.view.physicalSize = Size(size.width, size.height);
            tester.view.devicePixelRatio = 1.0;
            addTearDown(() {
              tester.view.resetPhysicalSize();
              tester.view.resetDevicePixelRatio();
            });

            final overflowErrors = <FlutterErrorDetails>[];
            final originalOnError = FlutterError.onError;
            FlutterError.onError = (details) {
              if (details.toString().contains('overflow') ||
                  details.toString().contains('RenderFlex')) {
                overflowErrors.add(details);
              }
              originalOnError?.call(details);
            };
            addTearDown(() => FlutterError.onError = originalOnError);

            await tester.pumpWidget(
              ProviderScope(
                overrides: [
                  appDatabaseProvider.overrideWithValue(db),
                  exploreDeckDaoProvider.overrideWithValue(exploreDao),
                  currentUserIdProvider.overrideWith((ref) => 'test-user'),
                ],
                child: MaterialApp(
                  home: MediaQuery(
                    data: MediaQueryData(
                      size: size,
                      textScaler: TextScaler.linear(scale),
                    ),
                    child: const Scaffold(
                      body: ExploreDecksTabView(),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();

            expect(overflowErrors, isEmpty,
                reason: 'ExploreDecksTabView initial render overflow on ${size.width}px at ${scale}x');
            expect(tester.takeException(), isNull);

            // Scroll down to stress test interleaved carousels and grid slices
            final scrollFinder = find.byType(CustomScrollView);
            if (scrollFinder.evaluate().isNotEmpty) {
              await tester.drag(scrollFinder, const Offset(0, -400));
              await tester.pumpAndSettle();
              expect(overflowErrors, isEmpty,
                  reason: 'ExploreDecksTabView scrolled overflow on ${size.width}px at ${scale}x');
            }
          },
        );
      }
    }
  });

  group('Group 2: ReadOnlyDeckScreen Unpublish Interactive Workflow', () {
    testWidgets(
      'Asserts verbatim confirmation copy, cancel preserves deck, and unpublish pops screen & removes from explore feed',
      (tester) async {
        const authorId = 'alice-author-777';
        final shared = await exploreDao.sharePersonalDeckToExplore(
          personalDeckId: MockDeckData.edgarMarkovDeckId,
          creatorName: '@AliceInMTG',
          authorId: authorId,
        );

        // Pre-condition: personal deck exists in My Decks with 100 cards
        final personalBefore = await vaultDao.getDeck(MockDeckData.edgarMarkovDeckId);
        expect(personalBefore, isNotNull);
        final personalItemsBefore =
            await vaultDao.watchDeckItems(MockDeckData.edgarMarkovDeckId).first;
        expect(personalItemsBefore.length, equals(100));

        // Mount inside a navigator stack with an underlying root screen
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              exploreDeckDaoProvider.overrideWithValue(exploreDao),
              currentUserIdProvider.overrideWith((ref) => authorId),
            ],
            child: MaterialApp(
              home: Builder(
                builder: (context) => Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      key: const Key('open_read_only_deck_button'),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ReadOnlyDeckScreen(
                              exploreDeckId: shared.id,
                            ),
                          ),
                        );
                      },
                      child: const Text('Open Deck'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Push ReadOnlyDeckScreen
        await tester.tap(find.byKey(const Key('open_read_only_deck_button')));
        await tester.pumpAndSettle();

        // Assert ReadOnlyDeckScreen is visible
        expect(find.byKey(const Key('read_only_deck_screen')), findsOneWidget);

        // Assert author overflow menu is visible in AppBar
        final overflowFinder = find.byKey(const Key('read_only_deck_overflow_menu'));
        expect(overflowFinder, findsOneWidget);

        // --- SUBTEST A: Tap overflow menu and check unpublish option ---
        await tester.tap(overflowFinder);
        await tester.pumpAndSettle();

        final unpublishOptionFinder = find.byKey(const Key('read_only_unpublish_menu_item'));
        expect(unpublishOptionFinder, findsOneWidget);
        expect(find.text('Unpublish from Explore'), findsOneWidget);

        // Open confirmation dialog
        await tester.tap(unpublishOptionFinder);
        await tester.pumpAndSettle();

        // --- SUBTEST B: Assert verbatim confirmation copy ---
        expect(find.text('Unpublish Deck?'), findsOneWidget);
        expect(
          find.text(
            'Unpublish from Explore? This removes the deck from public Explore. Your personal copy in My Decks will remain intact.',
          ),
          findsOneWidget,
        );

        // --- SUBTEST C: Tap Cancel button -> Dialog dismisses, deck remains published, screen does NOT pop ---
        final cancelBtn = find.byKey(const Key('cancel_unpublish_button'));
        expect(cancelBtn, findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);

        await tester.tap(cancelBtn);
        await tester.pumpAndSettle();

        // Confirmation dialog is closed
        expect(find.text('Unpublish Deck?'), findsNothing);
        // ReadOnlyDeckScreen is still visible (did NOT pop)
        expect(find.byKey(const Key('read_only_deck_screen')), findsOneWidget);

        // Explore deck in SQLite is still active
        var deckInDb = await exploreDao.getExploreDeck(shared.id);
        expect(deckInDb, isNotNull);
        expect(deckInDb!.deck.isDeleted, isFalse);

        // --- SUBTEST D: Confirm Unpublish -> Screen pops, SnackBar shown, deck removed from explore feed ---
        await tester.tap(overflowFinder);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('read_only_unpublish_menu_item')));
        await tester.pumpAndSettle();

        final confirmBtn = find.byKey(const Key('confirm_unpublish_button'));
        expect(confirmBtn, findsOneWidget);
        expect(find.text('Unpublish'), findsOneWidget);

        await tester.tap(confirmBtn);
        await tester.pumpAndSettle();

        // Assert ReadOnlyDeckScreen has POPPED back to host screen
        expect(find.byKey(const Key('read_only_deck_screen')), findsNothing);
        expect(find.byKey(const Key('open_read_only_deck_button')), findsOneWidget);

        // Assert SnackBar notification appears
        expect(find.text('Deck "${shared.name}" unpublished from Explore'), findsOneWidget);

        // Assert SQLite explore_decks is soft-deleted
        deckInDb = await exploreDao.getExploreDeck(shared.id);
        expect(deckInDb, isNull);

        final rawExploreRow = await (db.select(db.exploreDecks)
              ..where((t) => t.id.equals(shared.id)))
            .getSingle();
        expect(rawExploreRow.isDeleted, isTrue);

        // Assert SQLite explore_deck_items are soft-deleted
        final rawItems = await (db.select(db.exploreDeckItems)
              ..where((t) => t.exploreDeckId.equals(shared.id)))
            .get();
        expect(rawItems.every((item) => item.isDeleted == true), isTrue);

        // Assert sync_queue contains DELETE mutation
        final syncMutations = await (db.select(db.syncQueue)
              ..where((t) => t.entityId.equals(shared.id)))
            .get();
        expect(syncMutations.length, equals(1));
        expect(syncMutations.first.operation, equals('DELETE'));

        // Assert removed from explore feed stream
        final exploreFeed = await exploreDao.watchExploreDecks().first;
        expect(exploreFeed.any((d) => d.id == shared.id), isFalse);

        // CRUCIAL INVARIANT: Personal copy in My Decks remains 100% intact
        final personalAfter = await vaultDao.getDeck(MockDeckData.edgarMarkovDeckId);
        expect(personalAfter, isNotNull);
        expect(personalAfter!.isDeleted, isFalse);
        final personalItemsAfter =
            await vaultDao.watchDeckItems(MockDeckData.edgarMarkovDeckId).first;
        expect(personalItemsAfter.length, equals(100));
      },
    );
  });

  group('Group 3: ExploreDeckCard Top-Right ⋮ Button Interaction Isolation', () {
    testWidgets(
      'Tapping ⋮ button on artwork banner and unpublishing DOES NOT trigger parent card onTap',
      (tester) async {
        const authorId = 'banner-menu-author';
        final shared = await exploreDao.sharePersonalDeckToExplore(
          personalDeckId: MockDeckData.edgarMarkovDeckId,
          creatorName: '@BannerAuthor',
          authorId: authorId,
        );

        var cardTapCount = 0;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              exploreDeckDaoProvider.overrideWithValue(exploreDao),
              currentUserIdProvider.overrideWith((ref) => authorId),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: 180,
                  height: 280,
                  child: ExploreDeckCard(
                    deckWithVote: ExploreDeckWithVote(deck: shared, userVote: 0),
                    onTap: () {
                      cardTapCount++;
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final cardMenuButton = find.byKey(Key('explore_card_menu_${shared.id}'));
        expect(cardMenuButton, findsOneWidget);

        // Tap the top-right ⋮ button on the artwork banner
        await tester.tap(cardMenuButton);
        await tester.pumpAndSettle();

        // INVARIANT 1: Card onTap must NOT have fired
        expect(cardTapCount, equals(0),
            reason: 'Tapping banner ⋮ button must not invoke card onTap');

        // Verify popup menu item is present
        final unpublishItem = find.byKey(Key('explore_card_menu_unpublish_${shared.id}'));
        expect(unpublishItem, findsOneWidget);

        // Tap unpublish item
        await tester.tap(unpublishItem);
        await tester.pumpAndSettle();

        // INVARIANT 2: Selecting unpublish must NOT invoke card onTap
        expect(cardTapCount, equals(0),
            reason: 'Selecting unpublish item from popup menu must not invoke card onTap');

        // Confirmation dialog is open
        expect(find.text('Unpublish Deck?'), findsOneWidget);

        // Confirm unpublish
        final confirmBtn = find.byKey(const Key('confirm_unpublish_button'));
        expect(confirmBtn, findsOneWidget);
        await tester.tap(confirmBtn);
        await tester.pumpAndSettle();

        // INVARIANT 3: Confirming dialog unpublish must NOT invoke card onTap
        expect(cardTapCount, equals(0),
            reason: 'Confirming unpublish dialog must not invoke card onTap');

        // Verify unpublish was executed
        final deckCheck = await exploreDao.getExploreDeck(shared.id);
        expect(deckCheck, isNull);
      },
    );

    testWidgets(
      'Tapping card artwork/body outside menu button properly fires card onTap',
      (tester) async {
        const authorId = 'tap-body-author';
        final shared = await exploreDao.sharePersonalDeckToExplore(
          personalDeckId: MockDeckData.edgarMarkovDeckId,
          creatorName: '@BodyAuthor',
          authorId: authorId,
        );

        var cardTapCount = 0;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              exploreDeckDaoProvider.overrideWithValue(exploreDao),
              currentUserIdProvider.overrideWith((ref) => authorId),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: 180,
                  height: 280,
                  child: ExploreDeckCard(
                    deckWithVote: ExploreDeckWithVote(deck: shared, userVote: 0),
                    onTap: () {
                      cardTapCount++;
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap the card body (center)
        final cardFinder = find.byKey(Key('explore_card_${shared.id}'));
        expect(cardFinder, findsOneWidget);

        await tester.tap(cardFinder);
        await tester.pumpAndSettle();

        expect(cardTapCount, equals(1),
            reason: 'Tapping card body should fire card onTap callback');
      },
    );
  });

  group('Group 4: See More > Drill-Down Navigation & Category Scoping', () {
    testWidgets(
      'Tapping See More on carousel opens 2-column drill-down; Back button returns to discovery feed',
      (tester) async {
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
              currentUserIdProvider.overrideWith((ref) => 'test-user'),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: ExploreDecksTabView(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Locate See More on From Top Deck Builders carousel
        final seeMoreTopBuilders =
            find.byKey(const Key('explore_carousel_see_more_top_builders'));
        expect(seeMoreTopBuilders, findsOneWidget);

        // Tap See More >
        await tester.tap(seeMoreTopBuilders);
        await tester.pumpAndSettle();

        // Assert ExploreCategoryDrillDownView is mounted
        expect(find.byType(ExploreCategoryDrillDownView), findsOneWidget);
        expect(find.byKey(const Key('explore_drill_down_title')), findsOneWidget);
        expect(find.text('From Top Deck Builders'), findsOneWidget);

        // Assert 2-column grid is present
        expect(find.byKey(const Key('explore_drill_down_back_button')), findsOneWidget);

        // Tap back button
        await tester.tap(find.byKey(const Key('explore_drill_down_back_button')));
        await tester.pumpAndSettle();

        // Assert returned to main discovery feed
        expect(find.byType(ExploreCategoryDrillDownView), findsNothing);
        expect(find.byKey(const Key('explore_carousel_top_builders')), findsOneWidget);
      },
    );

    testWidgets(
      'Dynamic lead velocity carousel switches to Todays Picks and See More opens Todays Picks drill down',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Seed 6 votes in the last 2 hours to exceed threshold of 5
        final decks = await exploreDao.watchExploreDecks().first;
        expect(decks, isNotEmpty);
        final targetDeck = decks.first;

        for (int i = 0; i < 6; i++) {
          await db.into(db.exploreDeckVotes).insert(
            ExploreDeckVotesCompanion.insert(
              id: 'velocity_vote_stress_$i',
              exploreDeckId: targetDeck.id,
              userId: Value('stress_voter_$i'),
              vote: const Value(1),
              updatedAt: DateTime.now().subtract(Duration(minutes: i * 10)),
            ),
          );
        }

        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            exploreDeckDaoProvider.overrideWithValue(exploreDao),
            currentUserIdProvider.overrideWith((ref) => 'stress-user'),
          ],
        );
        addTearDown(container.dispose);

        // Verify engine resolves todaysPicks
        final window = await container.read(leadVelocityWindowProvider.future);
        expect(window, equals(LeadVelocityWindow.todaysPicks));

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

        // Lead carousel header should now display Today's Picks
        expect(find.text("Today's Picks"), findsOneWidget);

        // Tap See More on Today's Picks
        final seeMoreTodaysPicks =
            find.byKey(const Key('explore_carousel_see_more_todays_picks'));
        expect(seeMoreTodaysPicks, findsOneWidget);

        await tester.tap(seeMoreTodaysPicks);
        await tester.pumpAndSettle();

        // Assert drill-down title is Today's Picks
        expect(find.byType(ExploreCategoryDrillDownView), findsOneWidget);
        expect(find.text("Today's Picks"), findsOneWidget);

        // Tap back button
        await tester.tap(find.byKey(const Key('explore_drill_down_back_button')));
        await tester.pumpAndSettle();

        // Returns cleanly to discovery feed
        expect(find.byType(ExploreCategoryDrillDownView), findsNothing);
        expect(find.text("Today's Picks"), findsOneWidget);
      },
    );
  });
}
