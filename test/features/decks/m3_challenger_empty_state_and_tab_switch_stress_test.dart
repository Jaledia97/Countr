import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/decks/data/daos/explore_deck_dao.dart';
import 'package:countr/features/decks/data/services/explore_seeder_service.dart';
import 'package:countr/features/decks/data/services/fallback_explore_seeds.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/decks/presentation/providers/explore_deck_providers.dart';
import 'package:countr/features/decks/presentation/screens/decks_screen.dart';
import 'package:countr/features/decks/presentation/widgets/explore/explore_deck_card.dart';
import 'package:countr/features/decks/presentation/widgets/explore/explore_carousel_section.dart';

class _SimulatedFaultyDatabase extends AppDatabase {
  bool failBatch = false;

  _SimulatedFaultyDatabase() : super(NativeDatabase.memory());

  @override
  Future<void> batch(Function(Batch) runInBatch) async {
    if (failBatch) {
      throw Exception('Simulated SQLite disk write failure (I/O error 500)');
    }
    return super.batch(runInBatch);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('Milestone 3 Empirical Challenger Stress Test Suite', () {
    // =========================================================================
    // 1. EMPTY STATE TRANSITIONS & SEEDING INTEGRITY
    // =========================================================================
    group('1. Empty State Transitions & Seeding Integrity', () {
      testWidgets(
        '1.1 0 decks -> Tap seed button -> 19 decks populated -> UI smoothly transitions to populated feed and removes seed button',
        (tester) async {
          final db = AppDatabase(NativeDatabase.memory());
          addTearDown(db.close);
          final vaultDao = VaultDao(db);
          final exploreDao = ExploreDeckDao(db);

          final container = ProviderContainer(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              vaultDaoProvider.overrideWithValue(vaultDao),
              exploreDeckDaoProvider.overrideWithValue(exploreDao),
              decksTopTabProvider.overrideWith((ref) => 1),
            ],
          );
          addTearDown(container.dispose);

          tester.view.physicalSize = const Size(800, 2600);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: const MaterialApp(
                home: ScaffoldMessenger(
                  child: DecksScreen(),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // 1. Confirm initial empty state
          expect(await exploreDao.getExploreDeckCount(), 0);
          expect(find.byKey(const Key('load_precons_button')), findsOneWidget);
          expect(find.text('No community or precon decks found in this category'), findsOneWidget);
          expect(find.byKey(const Key('all_explore_decks_header')), findsNothing);

          // 2. Tap seed button
          await tester.tap(find.byKey(const Key('load_precons_button')));
          await tester.pump();

          // Button enters loading state
          expect(find.text('Loading Decks...'), findsOneWidget);

          // Settle the seeding process
          await tester.pump(const Duration(milliseconds: 50));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pumpAndSettle();

          // 3. Confirm 19 decks populated in DB
          final totalCount = await exploreDao.getExploreDeckCount();
          expect(totalCount, 19);

          // 4. Confirm UI transitioned: empty banner gone, header visible with badge
          expect(find.byKey(const Key('load_precons_button')), findsNothing);
          expect(find.text('No community or precon decks found in this category'), findsNothing);
          expect(find.byKey(const Key('all_explore_decks_header')), findsOneWidget);
          expect(find.byKey(const Key('explore_decks_count_badge')), findsOneWidget);
          expect(find.text('19 decks'), findsOneWidget);

          // 5. Carousels render without error
          expect(find.byKey(const Key('explore_carousel_suggested_commanders')), findsOneWidget);
          expect(find.byKey(const Key('explore_carousel_top_builders')), findsOneWidget);
          expect(find.byKey(const Key('explore_carousel_popular_standard')), findsOneWidget);
        },
      );

      testWidgets(
        '1.2 Dynamic DB deletion while on populated feed transitions to empty state without throwing errors',
        (tester) async {
          final db = AppDatabase(NativeDatabase.memory());
          addTearDown(db.close);
          final vaultDao = VaultDao(db);
          final exploreDao = ExploreDeckDao(db);

          await ExploreSeederService.seedFromRawDecks(db, FallbackExploreSeeds.allSeeds);
          expect(await exploreDao.getExploreDeckCount(), 19);

          final container = ProviderContainer(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              vaultDaoProvider.overrideWithValue(vaultDao),
              exploreDeckDaoProvider.overrideWithValue(exploreDao),
              decksTopTabProvider.overrideWith((ref) => 1),
            ],
          );
          addTearDown(container.dispose);

          tester.view.physicalSize = const Size(800, 2400);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: const MaterialApp(
                home: ScaffoldMessenger(
                  child: DecksScreen(),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Populated feed confirmed
          expect(find.byKey(const Key('all_explore_decks_header')), findsOneWidget);
          expect(find.byKey(const Key('load_precons_button')), findsNothing);

          // Now soft-delete all explore decks dynamically
          await (db.update(db.exploreDecks)).write(
            const ExploreDecksCompanion(isDeleted: Value(true)),
          );
          await tester.pumpAndSettle();

          // Stream emits 0 items -> Empty state banner dynamically reappears
          expect(find.text('No community or precon decks found in this category'), findsOneWidget);
          expect(find.byKey(const Key('load_precons_button')), findsOneWidget);
          expect(find.byKey(const Key('all_explore_decks_header')), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        '1.3 Force re-seeding via empty state button repopulates 19 decks without duplicate key crashes',
        (tester) async {
          final db = AppDatabase(NativeDatabase.memory());
          addTearDown(db.close);
          final vaultDao = VaultDao(db);
          final exploreDao = ExploreDeckDao(db);

          await ExploreSeederService.seedFromRawDecks(db, FallbackExploreSeeds.allSeeds);
          // Soft-delete all decks so empty state displays
          await (db.update(db.exploreDecks)).write(
            const ExploreDecksCompanion(isDeleted: Value(true)),
          );

          final container = ProviderContainer(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              vaultDaoProvider.overrideWithValue(vaultDao),
              exploreDeckDaoProvider.overrideWithValue(exploreDao),
              decksTopTabProvider.overrideWith((ref) => 1),
            ],
          );
          addTearDown(container.dispose);

          tester.view.physicalSize = const Size(800, 2400);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: const MaterialApp(
                home: ScaffoldMessenger(
                  child: DecksScreen(),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.byKey(const Key('load_precons_button')), findsOneWidget);

          // Tap seed button to force re-seed
          await tester.tap(find.byKey(const Key('load_precons_button')));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 50));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          // DB count is restored to 19 non-deleted decks
          final count = await exploreDao.getExploreDeckCount();
          expect(count, 19);
          expect(find.byKey(const Key('all_explore_decks_header')), findsOneWidget);
        },
      );
    });

    // =========================================================================
    // 2. SEED BUTTON ACTIONS & CONCURRENCY STRESS
    // =========================================================================
    group('2. Seed Button Actions & Concurrency Stress', () {
      testWidgets(
        '2.1 Rapid 15x taps on seed button within 16ms are debounced safely without duplicate execution',
        (tester) async {
          final db = AppDatabase(NativeDatabase.memory());
          addTearDown(db.close);
          final vaultDao = VaultDao(db);
          final exploreDao = ExploreDeckDao(db);

          final container = ProviderContainer(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              vaultDaoProvider.overrideWithValue(vaultDao),
              exploreDeckDaoProvider.overrideWithValue(exploreDao),
              decksTopTabProvider.overrideWith((ref) => 1),
            ],
          );
          addTearDown(container.dispose);

          tester.view.physicalSize = const Size(800, 2400);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: const MaterialApp(
                home: ScaffoldMessenger(
                  child: DecksScreen(),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final seedButton = find.byKey(const Key('load_precons_button'));
          expect(seedButton, findsOneWidget);

          // 15 rapid taps in succession
          for (int i = 0; i < 15; i++) {
            await tester.tap(seedButton, warnIfMissed: false);
          }
          await tester.pump();

          // Should reflect loading state
          expect(find.text('Loading Decks...'), findsOneWidget);

          // Let seeding complete
          await tester.pump(const Duration(milliseconds: 50));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(await exploreDao.getExploreDeckCount(), 19);
        },
      );

      testWidgets(
        '2.2 Seeding error recovery: I/O failure displays SnackBar, resets loading flag, and allows successful retry',
        (tester) async {
          final faultyDb = _SimulatedFaultyDatabase();
          faultyDb.failBatch = true;
          addTearDown(faultyDb.close);
          final vaultDao = VaultDao(faultyDb);
          final exploreDao = ExploreDeckDao(faultyDb);

          final container = ProviderContainer(
            overrides: [
              appDatabaseProvider.overrideWithValue(faultyDb),
              vaultDaoProvider.overrideWithValue(vaultDao),
              exploreDeckDaoProvider.overrideWithValue(exploreDao),
              decksTopTabProvider.overrideWith((ref) => 1),
            ],
          );
          addTearDown(container.dispose);

          tester.view.physicalSize = const Size(800, 2400);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: const MaterialApp(
                home: ScaffoldMessenger(
                  child: DecksScreen(),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final seedBtn = find.byKey(const Key('load_precons_button'));
          expect(seedBtn, findsOneWidget);

          // 1. First attempt fails due to simulated I/O error
          await tester.tap(seedBtn);
          await tester.pump();

          expect(find.textContaining('Failed to load decks:'), findsOneWidget);
          await tester.pumpAndSettle();

          // Button should no longer be loading
          expect(find.text('Loading Decks...'), findsNothing);
          expect(find.byKey(const Key('load_precons_button')), findsOneWidget);

          // 2. Fix database failure and retry
          faultyDb.failBatch = false;
          await tester.tap(find.byKey(const Key('load_precons_button')));
          await tester.pump();
          expect(find.text('Loading Decks...'), findsOneWidget);

          await tester.pump(const Duration(milliseconds: 50));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pumpAndSettle();

          // Verify success
          expect(find.text('Successfully loaded precons & community decks!'), findsOneWidget);
          expect(await exploreDao.getExploreDeckCount(), 19);
          expect(find.byKey(const Key('load_precons_button')), findsNothing);
        },
      );
    });

    // =========================================================================
    // 3. FAST TAB SWITCHES & STATE INVARIANTS
    // =========================================================================
    group('3. Fast Tab Switches & State Invariants', () {
      testWidgets(
        '3.1 Rapid 20x tab switching cycles during active seeding preserves state and avoids deadlock',
        (tester) async {
          final db = AppDatabase(NativeDatabase.memory());
          addTearDown(db.close);
          final vaultDao = VaultDao(db);
          final exploreDao = ExploreDeckDao(db);

          final container = ProviderContainer(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              vaultDaoProvider.overrideWithValue(vaultDao),
              exploreDeckDaoProvider.overrideWithValue(exploreDao),
              decksTopTabProvider.overrideWith((ref) => 0),
            ],
          );
          addTearDown(container.dispose);

          tester.view.physicalSize = const Size(800, 2400);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: const MaterialApp(
                home: ScaffoldMessenger(
                  child: DecksScreen(),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Start seeding in background
          final seedFuture = ExploreSeederService.seedIfNeeded(db);

          // Perform 20 rapid tab switches between 0 and 1
          for (int i = 1; i <= 20; i++) {
            container.read(decksTopTabProvider.notifier).state = (i % 2 == 0) ? 0 : 1;
            await tester.pump(const Duration(milliseconds: 16));
          }

          await seedFuture;
          await tester.pumpAndSettle();

          // Verify landing on Tab 0 has FAB
          container.read(decksTopTabProvider.notifier).state = 0;
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('decks_new_deck_fab')), findsOneWidget);

          // Switch to Tab 1: FAB is gone, 19 explore decks are visible
          container.read(decksTopTabProvider.notifier).state = 1;
          await tester.pumpAndSettle();
          expect(find.byKey(const Key('decks_new_deck_fab')), findsNothing);
          expect(await exploreDao.getExploreDeckCount(), 19);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        '3.2 State Isolation: My Decks search vs Explore search remain strictly isolated across multiple tab switches',
        (tester) async {
          final db = AppDatabase(NativeDatabase.memory());
          addTearDown(db.close);
          final vaultDao = VaultDao(db);
          final exploreDao = ExploreDeckDao(db);

          await ExploreSeederService.seedFromRawDecks(db, FallbackExploreSeeds.allSeeds);

          final container = ProviderContainer(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              vaultDaoProvider.overrideWithValue(vaultDao),
              exploreDeckDaoProvider.overrideWithValue(exploreDao),
            ],
          );
          addTearDown(container.dispose);

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: const MaterialApp(home: DecksScreen()),
            ),
          );
          await tester.pumpAndSettle();

          // 1. On My Decks (Tab 0), enter search "Edgar"
          await tester.enterText(find.byKey(const Key('my_decks_search_input')), 'Edgar');
          await tester.pumpAndSettle();
          expect(container.read(myDecksSearchQueryProvider), 'Edgar');

          // 2. Switch to Explore (Tab 1)
          await tester.tap(find.byKey(const Key('decks_top_tab_explore')));
          await tester.pumpAndSettle();

          // Explore search is empty
          expect(container.read(exploreSearchQueryProvider), '');

          // Enter search "Ur-Dragon" in Explore
          await tester.enterText(find.byKey(const Key('explore_search_input')), 'Ur-Dragon');
          await tester.pumpAndSettle();
          expect(container.read(exploreSearchQueryProvider), 'Ur-Dragon');

          // 3. Switch back to My Decks (Tab 0)
          await tester.tap(find.byKey(const Key('decks_top_tab_my_decks')));
          await tester.pumpAndSettle();

          // My Decks search remains 'Edgar'
          expect(container.read(myDecksSearchQueryProvider), 'Edgar');
          final myDecksField = tester.widget<TextField>(find.byKey(const Key('my_decks_search_input')));
          expect(myDecksField.controller?.text, 'Edgar');

          // 4. Switch back to Explore (Tab 1)
          await tester.tap(find.byKey(const Key('decks_top_tab_explore')));
          await tester.pumpAndSettle();

          // Explore search remains 'Ur-Dragon'
          expect(container.read(exploreSearchQueryProvider), 'Ur-Dragon');
          final exploreField = tester.widget<TextField>(find.byKey(const Key('explore_search_input')));
          expect(exploreField.controller?.text, 'Ur-Dragon');
        },
      );
    });

    // =========================================================================
    // 4. VIEWPORT CONSTRAINTS & UNCROPPED CARD GEOMETRY
    // =========================================================================
    group('4. Viewport Constraints & Uncropped Card Geometry', () {
      testWidgets(
        '4.1 Ultra-compact mobile screen (280x500) renders ExploreDeckCard without RenderFlex overflow',
        (tester) async {
          final db = AppDatabase(NativeDatabase.memory());
          addTearDown(db.close);
          final vaultDao = VaultDao(db);
          final exploreDao = ExploreDeckDao(db);

          final now = DateTime.now();
          await db.into(db.exploreDecks).insert(
            ExploreDecksCompanion.insert(
              id: 'compact_deck_1',
              name: 'Compact Test Deck With A Super Extremely Long Title That Might Cause RenderFlex Overflow',
              format: 'Commander',
              tcgDomain: const Value('mtg'),
              sourceType: const Value('official'),
              creatorName: const Value('Official WotC'),
              commanderName: const Value('Atraxa, Praetors\' Voice'),
              colorIdentity: const Value('["W","U","B","G"]'),
              cardCount: const Value(100),
              estimatedPrice: const Value(999.99),
              upvotes: const Value(500),
              downvotes: const Value(10),
              score: const Value(490),
              createdAt: now,
              updatedAt: Value(now),
              isDeleted: const Value(false),
            ),
          );

          tester.view.physicalSize = const Size(280, 500);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);

          final caughtErrors = <FlutterErrorDetails>[];
          final prevOnError = FlutterError.onError;
          FlutterError.onError = (details) {
            caughtErrors.add(details);
          };

          try {
            await tester.pumpWidget(
              ProviderScope(
                overrides: [
                  appDatabaseProvider.overrideWithValue(db),
                  vaultDaoProvider.overrideWithValue(vaultDao),
                  exploreDeckDaoProvider.overrideWithValue(exploreDao),
                  decksTopTabProvider.overrideWith((ref) => 1),
                ],
                child: const MaterialApp(
                  home: DecksScreen(),
                ),
              ),
            );
            await tester.pumpAndSettle();

            // Scroll down past the 3 carousels to reach the unified grid where the card is placed
            final scrollFinder = find.byKey(const PageStorageKey('explore_decks_scroll_key'));
            await tester.drag(scrollFinder, const Offset(0, -1200));
            await tester.pumpAndSettle();

            // Verify the card is mounted in the grid
            expect(find.byType(ExploreDeckCard), findsWidgets);
          } finally {
            FlutterError.onError = prevOnError;
          }

          expect(
            caughtErrors.any((e) => e.toString().contains('RenderFlex overflowed')),
            isFalse,
            reason: 'RenderFlex overflow in ExploreDeckCard on 280px screen: '
                '${caughtErrors.where((e) => e.toString().contains("RenderFlex overflowed")).map((e) => e.exceptionAsString()).toList()}',
          );
        },
      );

      testWidgets(
        '4.2 ExploreDeckCard uses uncropped aspect ratio (63/88) and ExploreCarouselSection has height 350',
        (tester) async {
          final db = AppDatabase(NativeDatabase.memory());
          addTearDown(db.close);
          final vaultDao = VaultDao(db);
          final exploreDao = ExploreDeckDao(db);

          await ExploreSeederService.seedFromRawDecks(db, FallbackExploreSeeds.allSeeds);

          tester.view.physicalSize = const Size(800, 2400);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                appDatabaseProvider.overrideWithValue(db),
                vaultDaoProvider.overrideWithValue(vaultDao),
                exploreDeckDaoProvider.overrideWithValue(exploreDao),
                decksTopTabProvider.overrideWith((ref) => 1),
              ],
              child: const MaterialApp(
                home: DecksScreen(),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // 1. Verify Carousel heights are exactly 350
          final carouselSizedBoxFinders = find.descendant(
            of: find.byType(ExploreCarouselSection),
            matching: find.byWidgetPredicate(
              (w) => w is SizedBox && w.height == 350,
            ),
          );
          expect(carouselSizedBoxFinders, findsWidgets);

          // 2. Verify AspectRatio in ExploreDeckCard is 63 / 88
          final cardAspectRatioFinders = find.descendant(
            of: find.byType(ExploreDeckCard),
            matching: find.byWidgetPredicate(
              (w) => w is AspectRatio && (w.aspectRatio - (63.0 / 88.0)).abs() < 0.001,
            ),
          );
          expect(cardAspectRatioFinders, findsWidgets);
        },
      );
    });
  });
}
