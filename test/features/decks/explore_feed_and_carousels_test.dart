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
import 'package:countr/features/decks/domain/models/explore_deck_models.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/decks/presentation/providers/explore_deck_providers.dart';
import 'package:countr/features/decks/presentation/screens/decks_screen.dart';

class _FailingAppDatabase extends AppDatabase {
  _FailingAppDatabase() : super(NativeDatabase.memory());

  @override
  Future<void> batch(Function(Batch) runInBatch) {
    throw Exception('Simulated SQLite disk write failure');
  }
}

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

    final now = DateTime.now();

    // 1. Seed Suggested Commanders
    await db.into(db.exploreDecks).insert(
      ExploreDecksCompanion.insert(
        id: 'deck_sug_comm_1',
        name: 'Urza Thopter Foundry',
        format: 'Commander',
        tcgDomain: const Value('mtg'),
        sourceType: const Value('official'),
        creatorName: const Value('Official WotC'),
        commanderName: const Value('Urza, Lord High Artificer'),
        featuredCategory: const Value('Suggested Commanders'),
        colorIdentity: const Value('["U"]'),
        cardCount: const Value(100),
        estimatedPrice: const Value(145.0),
        upvotes: const Value(42),
        downvotes: const Value(3),
        score: const Value(39),
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: Value(now),
        isDeleted: const Value(false),
      ),
    );

    // 2. Seed From Top Deck Builders
    await db.into(db.exploreDecks).insert(
      ExploreDecksCompanion.insert(
        id: 'deck_top_builder_1',
        name: 'Spicy Aristocrats',
        format: 'Commander',
        tcgDomain: const Value('mtg'),
        sourceType: const Value('community'),
        creatorName: const Value('@SpicyBrewMaster'),
        commanderName: const Value('Teysa Karlov'),
        featuredCategory: const Value('From Top Deck Builders'),
        colorIdentity: const Value('["W","B"]'),
        cardCount: const Value(100),
        estimatedPrice: const Value(68.5),
        upvotes: const Value(88),
        downvotes: const Value(5),
        score: const Value(83),
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: Value(now),
        isDeleted: const Value(false),
      ),
    );

    // 3. Seed Popular Standard Decks
    await db.into(db.exploreDecks).insert(
      ExploreDecksCompanion.insert(
        id: 'deck_pop_standard_1',
        name: 'Mono Red Aggro Pro',
        format: 'Standard',
        tcgDomain: const Value('mtg'),
        sourceType: const Value('community'),
        creatorName: const Value('@DraftGuru'),
        commanderName: const Value(''),
        featuredCategory: const Value('Popular Standard Decks'),
        colorIdentity: const Value('["R"]'),
        cardCount: const Value(60),
        estimatedPrice: const Value(45.0),
        upvotes: const Value(60),
        downvotes: const Value(4),
        score: const Value(56),
        createdAt: now,
        updatedAt: Value(now),
        isDeleted: const Value(false),
      ),
    );

    // 4. Seed General Grid Decks
    for (int i = 1; i <= 6; i++) {
      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: 'deck_grid_$i',
          name: 'Community Deck #$i',
          format: i % 2 == 0 ? 'Commander' : 'Modern',
          tcgDomain: const Value('mtg'),
          sourceType: i == 1 ? const Value('official') : const Value('community'),
          creatorName: Value(i == 1 ? 'Official WotC' : '@Brewer_$i'),
          colorIdentity: const Value('["G"]'),
          cardCount: const Value(60),
          estimatedPrice: Value(30.0 + (i * 20)),
          upvotes: Value(10 + i),
          score: Value(10 + i),
          createdAt: now.subtract(Duration(hours: i)),
          updatedAt: Value(now),
          isDeleted: const Value(false),
        ),
      );
    }
  });

  tearDown(() async {
    await db.close();
  });

  Widget createSubject({
    int initialTopTab = 1,
  }) {
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

  group('Milestone 3: Explore Feed, Carousels & Filters Tests', () {
    testWidgets('1. Discovery layout renders 2-column grid and all 3 horizontal category carousels',
        (tester) async {
      tester.view.physicalSize = const Size(800, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createSubject(initialTopTab: 1));
      await tester.pumpAndSettle();

      // Top category pills are visible
      expect(find.byKey(const Key('explore_pill_all')), findsOneWidget);
      expect(find.byKey(const Key('explore_pill_official')), findsOneWidget);
      expect(find.byKey(const Key('explore_pill_community')), findsOneWidget);

      // Search bar with embedded buttons is mounted
      expect(find.byKey(const Key('explore_search_input')), findsOneWidget);
      expect(find.byKey(const Key('explore_search_sort_button')), findsOneWidget);
      expect(find.byKey(const Key('explore_filter_button')), findsOneWidget);

      // Horizontal Carousels
      expect(find.byKey(const Key('explore_carousel_suggested_commanders')), findsOneWidget);
      expect(find.byKey(const Key('explore_carousel_top_builders')), findsOneWidget);

      // Primary 2-Column Grid is rendered
      final gridFinders = find.byType(SliverGrid);
      expect(gridFinders, findsWidgets);

      final sliverGridWidget = tester.widget<SliverGrid>(gridFinders.first);
      final delegate = sliverGridWidget.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, 2);

      // Deck cards render with explore_card_${id} keys
      expect(find.byKey(const Key('explore_card_deck_sug_comm_1')), findsWidgets);
      expect(find.byKey(const Key('explore_card_deck_top_builder_1')), findsWidgets);

      // Scroll down to reveal popular standard carousel
      await tester.drag(
        find.byKey(const PageStorageKey('explore_decks_scroll_key')),
        const Offset(0, -1000),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('explore_carousel_popular_standard')), findsOneWidget);
    });

    testWidgets('2. Top category pills filter between All, Official (WotC), and Community',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(vaultDao),
          exploreDeckDaoProvider.overrideWithValue(exploreDao),
          decksTopTabProvider.overrideWith((ref) => 1),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: DecksScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Official (WotC) pill
      await tester.tap(find.byKey(const Key('explore_pill_official')));
      await tester.pumpAndSettle();

      expect(container.read(activeExploreCategoryProvider), ExploreCategory.official);

      // Tap Community pill
      await tester.tap(find.byKey(const Key('explore_pill_community')));
      await tester.pumpAndSettle();

      expect(container.read(activeExploreCategoryProvider), ExploreCategory.community);

      // Tap All pill
      await tester.tap(find.byKey(const Key('explore_pill_all')));
      await tester.pumpAndSettle();

      expect(container.read(activeExploreCategoryProvider), ExploreCategory.all);
    });

    testWidgets('3. Filter modal opens, accepts format, color, price, and input filters, then applies',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(vaultDao),
          exploreDeckDaoProvider.overrideWithValue(exploreDao),
          decksTopTabProvider.overrideWith((ref) => 1),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: DecksScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Tap filter button to open ExploreFilterModal
      await tester.tap(find.byKey(const Key('explore_filter_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('explore_filter_modal')), findsOneWidget);

      // Select Format: Commander
      await tester.tap(find.byKey(const Key('explore_filter_format_commander')));
      await tester.pumpAndSettle();

      // Select Colors: W and U
      await tester.tap(find.byKey(const Key('explore_filter_color_W')));
      await tester.tap(find.byKey(const Key('explore_filter_color_U')));
      await tester.pumpAndSettle();

      // Select Match Mode: Exactly
      await tester.tap(find.byKey(const Key('explore_filter_mode_exactly')));
      await tester.pumpAndSettle();

      // Select Budget: $50–$200
      await tester.tap(find.byKey(const Key('explore_filter_price_50_200')));
      await tester.pumpAndSettle();

      // Enter Commander Name
      await tester.enterText(find.byKey(const Key('explore_filter_commander_input')), 'Urza');
      await tester.pumpAndSettle();

      // Enter Card Inclusion
      await tester.enterText(find.byKey(const Key('explore_filter_card_input')), 'Sol Ring');
      await tester.pumpAndSettle();

      // Tap Apply Filters
      await tester.tap(find.byKey(const Key('explore_filter_apply_button')));
      await tester.pumpAndSettle();

      // Modal is dismissed
      expect(find.byKey(const Key('explore_filter_modal')), findsNothing);

      // Assert applied filter state
      final state = container.read(exploreFilterStateProvider);
      expect(state.format, 'Commander');
      expect(state.colors, containsAll(['W', 'U']));
      expect(state.colorMatchMode, 'exactly');
      expect(state.priceRange, 'mid_50_200');
      expect(state.commanderName, 'Urza');
      expect(state.cardInclusion, 'Sol Ring');
      expect(state.isEmpty, isFalse);
    });

    testWidgets('4. Filter modal Reset button clears all active filters',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(vaultDao),
          exploreDeckDaoProvider.overrideWithValue(exploreDao),
          decksTopTabProvider.overrideWith((ref) => 1),
          exploreFilterStateProvider.overrideWith((ref) => const ExploreFilterState(
                format: 'Modern',
                colors: ['R'],
                priceRange: 'budget_0_50',
                commanderName: 'Ragavan',
              )),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: DecksScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Open filter modal
      await tester.tap(find.byKey(const Key('explore_filter_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('explore_filter_modal')), findsOneWidget);

      // Tap Reset button
      await tester.tap(find.byKey(const Key('explore_filter_reset_button')));
      await tester.pumpAndSettle();

      final state = container.read(exploreFilterStateProvider);
      expect(state.isEmpty, isTrue);
    });

    testWidgets('5. Interactive voting cluster updates score persistently on deck card',
        (tester) async {
      tester.view.physicalSize = const Size(800, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createSubject(initialTopTab: 1));
      await tester.pumpAndSettle();

      final deckId = 'deck_grid_6';
      final upvoteFinder = find.byKey(Key('explore_upvote_$deckId'));
      final scoreFinder = find.byKey(Key('explore_score_$deckId'));

      expect(upvoteFinder, findsOneWidget);
      expect(scoreFinder, findsOneWidget);
      expect(tester.widget<Text>(scoreFinder).data, '16');

      // Tap Upvote
      await tester.tap(upvoteFinder);
      await tester.pumpAndSettle();

      // Score increases from 16 to 17
      expect(tester.widget<Text>(scoreFinder).data, '17');

      // Tap Downvote
      final downvoteFinder = find.byKey(Key('explore_downvote_$deckId'));
      await tester.tap(downvoteFinder);
      await tester.pumpAndSettle();

      // User switched vote to -1 -> score becomes 15 (base 16 - 1)
      expect(tester.widget<Text>(scoreFinder).data, '15');
    });

    testWidgets('6. Category pill row cleanly displays All, Official, and Community, and omits debug load_precons_button when feed is populated',
        (tester) async {
      await tester.pumpWidget(createSubject(initialTopTab: 1));
      await tester.pumpAndSettle();

      // Top category pills are present
      expect(find.byKey(const Key('explore_pill_all')), findsOneWidget);
      expect(find.byKey(const Key('explore_pill_official')), findsOneWidget);
      expect(find.byKey(const Key('explore_pill_community')), findsOneWidget);

      // Debug seed button is absent from the populated top category pill bar
      expect(find.byKey(const Key('load_precons_button')), findsNothing);
      expect(find.text('Seed Precons & Community'), findsNothing);
    });

    testWidgets('7. Tapping empty-state seed button (load_precons_button) triggers seeding, displays loading indicator, shows completion SnackBar, populates 19 decks, and removes seed button from populated feed',
        (tester) async {
      final freshDb = AppDatabase(NativeDatabase.memory());
      addTearDown(freshDb.close);

      final freshVaultDao = VaultDao(freshDb);
      final freshExploreDao = ExploreDeckDao(freshDb);

      expect(await freshExploreDao.getExploreDeckCount(), 0);

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(freshDb),
          vaultDaoProvider.overrideWithValue(freshVaultDao),
          exploreDeckDaoProvider.overrideWithValue(freshExploreDao),
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

      // Initially, 0 decks in DB
      expect(await freshExploreDao.getExploreDeckCount(), 0);

      // Seed Precons & Community button is visible
      final seedButton = find.byKey(const Key('load_precons_button'));
      expect(seedButton, findsOneWidget);
      expect(find.text('Load Official Precons & Community Decks'), findsOneWidget);

      // Tap the seed button and pump to dispatch tap event and trigger _seedPreconsAndCommunity
      await tester.tap(seedButton);
      await tester.pump();

      // Verify loading state is shown on the button
      expect(find.text('Loading Decks...'), findsOneWidget);

      // Advance time past the inter-seed delay and allow seeding to complete
      await tester.pump(const Duration(milliseconds: 50));
      // Pump frame for the completion SnackBar animation to enter
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify completion SnackBar
      expect(find.text('Successfully loaded precons & community decks!'), findsOneWidget);

      // Settle animations and stream updates
      await tester.pumpAndSettle();

      // Verify database has all 19 decks
      final count = await freshExploreDao.getExploreDeckCount();
      expect(count, 19);

      // Verify decks are rendered in the feed and carousels
      expect(find.byKey(const Key('explore_carousel_suggested_commanders')), findsOneWidget);
      expect(find.byKey(const Key('explore_carousel_top_builders')), findsOneWidget);

      // Ur-Dragon official precon card is rendered
      expect(find.byKey(const Key('explore_card_precon-c17-draconic-domination')), findsWidgets);

      // Verify debug seed button is absent from the populated category pill bar
      expect(find.byKey(const Key('load_precons_button')), findsNothing);
      expect(find.text('Seed Precons & Community'), findsNothing);
      expect(await freshExploreDao.getExploreDeckCount(), equals(19));
    });

    testWidgets('8. Rapid tab switching between My Decks and Explore Decks maintains state integrity and populates feed without deadlock or exceptions',
        (tester) async {
      final freshDb = AppDatabase(NativeDatabase.memory());
      addTearDown(freshDb.close);

      final freshVaultDao = VaultDao(freshDb);
      final freshExploreDao = ExploreDeckDao(freshDb);

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(freshDb),
          vaultDaoProvider.overrideWithValue(freshVaultDao),
          exploreDeckDaoProvider.overrideWithValue(freshExploreDao),
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

      // Start asynchronous seeding while user rapidly switches tabs back and forth
      final seedFuture = ExploreSeederService.seedIfNeeded(freshDb);

      // Perform rapid 10x tab switching cycles
      for (int i = 0; i < 10; i++) {
        container.read(decksTopTabProvider.notifier).state = (i % 2 == 0) ? 1 : 0;
        await tester.pump(const Duration(milliseconds: 16));
      }

      await seedFuture;
      await tester.pumpAndSettle();

      // Settle on Explore tab
      container.read(decksTopTabProvider.notifier).state = 1;
      await tester.pumpAndSettle();

      // Verify all 19 decks are populated and rendered without exception
      final count = await freshExploreDao.getExploreDeckCount();
      expect(count, equals(19));
      expect(find.byKey(const Key('load_precons_button')), findsNothing);
      expect(find.text('Seed Precons & Community'), findsNothing);
    });

    testWidgets('9. Seeding error is caught gracefully, displays error feedback SnackBar, resets loading state, and allows user retry',
        (tester) async {
      final failingDb = _FailingAppDatabase();
      addTearDown(failingDb.close);

      final freshVaultDao = VaultDao(failingDb);
      final freshExploreDao = ExploreDeckDao(failingDb);

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(failingDb),
          vaultDaoProvider.overrideWithValue(freshVaultDao),
          exploreDeckDaoProvider.overrideWithValue(freshExploreDao),
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

      // Tap seed button; batch insertion throws
      await tester.tap(seedButton);
      await tester.pump();

      // Error SnackBar is displayed with failure feedback
      expect(find.textContaining('Failed to load decks:'), findsOneWidget);

      // Settle animations
      await tester.pumpAndSettle();

      // Button is re-enabled for retry and not stuck in loading state
      expect(find.text('Loading Decks...'), findsNothing);
      expect(find.byKey(const Key('load_precons_button')), findsOneWidget);
    });

    testWidgets('10. Rapid multi-tapping on seed button while active seeding is in progress is debounced/ignored safely',
        (tester) async {
      final freshDb = AppDatabase(NativeDatabase.memory());
      addTearDown(freshDb.close);

      final freshVaultDao = VaultDao(freshDb);
      final freshExploreDao = ExploreDeckDao(freshDb);

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(freshDb),
          vaultDaoProvider.overrideWithValue(freshVaultDao),
          exploreDeckDaoProvider.overrideWithValue(freshExploreDao),
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

      final seedButton = find.byKey(const Key('load_precons_button'));
      expect(seedButton, findsOneWidget);

      // Perform initial tap to initiate seeding
      await tester.tap(seedButton);
      await tester.pump();

      // Immediately attempt 3 additional rapid taps while button is in loading state
      await tester.tap(seedButton, warnIfMissed: false);
      await tester.tap(seedButton, warnIfMissed: false);
      await tester.tap(seedButton, warnIfMissed: false);
      await tester.pump();

      // Ensure button reflects loading state
      expect(find.text('Loading Decks...'), findsOneWidget);

      // Allow seeding to complete
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Exactly 1 completion SnackBar is present
      expect(find.text('Successfully loaded precons & community decks!'), findsOneWidget);

      await tester.pumpAndSettle();

      // 19 decks populated cleanly
      final count = await freshExploreDao.getExploreDeckCount();
      expect(count, equals(19));
      expect(find.byKey(const Key('load_precons_button')), findsNothing);
      expect(find.text('Seed Precons & Community'), findsNothing);
    });
  });
}

