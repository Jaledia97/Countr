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

    // 1. Deck with specific Name: 'Urza Thopter Army'
    await db.into(db.exploreDecks).insert(
      ExploreDecksCompanion.insert(
        id: 'deck_search_1',
        name: 'Urza Thopter Army',
        format: 'Commander',
        tcgDomain: const Value('mtg'),
        sourceType: const Value('official'),
        creatorName: const Value('Official WotC'),
        commanderName: const Value('Urza, Lord High Artificer'),
        colorIdentity: const Value('["U"]'),
        cardCount: const Value(100),
        estimatedPrice: const Value(250.0),
        upvotes: const Value(20),
        score: const Value(20),
        createdAt: now.subtract(const Duration(days: 5)),
        updatedAt: Value(now),
        isDeleted: const Value(false),
      ),
    );

    // 2. Deck containing specific Card: 'Sol Ring' (deck name does NOT contain 'Sol Ring')
    await db.into(db.exploreDecks).insert(
      ExploreDecksCompanion.insert(
        id: 'deck_search_2',
        name: 'Goblins Burn Aggro',
        format: 'Modern',
        tcgDomain: const Value('mtg'),
        sourceType: const Value('community'),
        creatorName: const Value('@GoblinKing'),
        commanderName: const Value('Krenko'),
        colorIdentity: const Value('["R"]'),
        cardCount: const Value(60),
        estimatedPrice: const Value(35.0),
        upvotes: const Value(10),
        score: const Value(10),
        createdAt: now.subtract(const Duration(days: 3)),
        updatedAt: Value(now),
        isDeleted: const Value(false),
      ),
    );

    await db.into(db.exploreDeckItems).insert(
      ExploreDeckItemsCompanion.insert(
        id: 'item_sol_ring_1',
        exploreDeckId: 'deck_search_2',
        cardName: 'Sol Ring',
        boardZone: const Value('Mainboard'),
        quantity: const Value(1),
      ),
    );

    // 3. Deck with specific Creator: '@SpicyBrewMaster' (name does not contain 'Spicy')
    await db.into(db.exploreDecks).insert(
      ExploreDecksCompanion.insert(
        id: 'deck_search_3',
        name: 'Necromancy Reanimator',
        format: 'Commander',
        tcgDomain: const Value('mtg'),
        sourceType: const Value('community'),
        creatorName: const Value('@SpicyBrewMaster'),
        commanderName: const Value('Animate Dead'),
        colorIdentity: const Value('["B"]'),
        cardCount: const Value(100),
        estimatedPrice: const Value(110.0),
        upvotes: const Value(50),
        score: const Value(50),
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: Value(now),
        isDeleted: const Value(false),
      ),
    );

    // 4. Alphabetical anchor decks for sorting tests
    await db.into(db.exploreDecks).insert(
      ExploreDecksCompanion.insert(
        id: 'deck_alpha_a',
        name: 'Abzan Tokens',
        format: 'Commander',
        tcgDomain: const Value('mtg'),
        sourceType: const Value('community'),
        creatorName: const Value('@AlphaBuilder'),
        cardCount: const Value(100),
        estimatedPrice: const Value(15.0), // Lowest price
        upvotes: const Value(5),
        score: const Value(5),
        createdAt: now.subtract(const Duration(days: 10)),
        updatedAt: Value(now),
        isDeleted: const Value(false),
      ),
    );

    await db.into(db.exploreDecks).insert(
      ExploreDecksCompanion.insert(
        id: 'deck_alpha_z',
        name: 'Zur the Enchanter Stax',
        format: 'Commander',
        tcgDomain: const Value('mtg'),
        sourceType: const Value('community'),
        creatorName: const Value('@OmegaBuilder'),
        cardCount: const Value(100),
        estimatedPrice: const Value(499.0), // Highest price
        upvotes: const Value(100), // Highest score
        score: const Value(100),
        createdAt: now, // Most recent
        updatedAt: Value(now),
        isDeleted: const Value(false),
      ),
    );
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

  group('Milestone 3: Embedded Sort Menu & Multi-Tier Search Tests', () {
    testWidgets('1. Embedded sort popup menu offers all 5 sort options and updates active sort option',
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

      // Open embedded sort menu
      final sortButton = find.byKey(const Key('explore_search_sort_button'));
      expect(sortButton, findsOneWidget);
      await tester.tap(sortButton);
      await tester.pumpAndSettle();

      // All 5 options are present
      expect(find.byKey(const Key('explore_sort_popular')), findsOneWidget);
      expect(find.byKey(const Key('explore_sort_recent')), findsOneWidget);
      expect(find.byKey(const Key('explore_sort_price_asc')), findsOneWidget);
      expect(find.byKey(const Key('explore_sort_price_desc')), findsOneWidget);
      expect(find.byKey(const Key('explore_sort_alpha')), findsOneWidget);

      // Select Price: Low to High
      await tester.tap(find.byKey(const Key('explore_sort_price_asc')));
      await tester.pumpAndSettle();

      expect(container.read(activeExploreSortOptionProvider), ExploreSortOption.priceLowToHigh);

      // Open sort menu again and select Alphabetical (A-Z)
      await tester.tap(sortButton);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('explore_sort_alpha')));
      await tester.pumpAndSettle();

      expect(container.read(activeExploreSortOptionProvider), ExploreSortOption.alphabetical);
    });

    testWidgets('2. Sort algorithms genuinely order explore decks in DAO stream',
        (tester) async {
      // 1. Popularity sort -> Highest score first (Zur: 100)
      final popularDecks = await exploreDao.watchExploreDecks(
        sort: ExploreSortOption.popularity,
      ).first;
      expect(popularDecks.first.id, 'deck_alpha_z');
      expect(popularDecks.first.score, 100);

      // 2. Price Low to High -> Cheapest first (Abzan: $15)
      final cheapDecks = await exploreDao.watchExploreDecks(
        sort: ExploreSortOption.priceLowToHigh,
      ).first;
      expect(cheapDecks.first.id, 'deck_alpha_a');
      expect(cheapDecks.first.estimatedPrice, 15.0);

      // 3. Price High to Low -> Most expensive first (Zur: $499)
      final expensiveDecks = await exploreDao.watchExploreDecks(
        sort: ExploreSortOption.priceHighToLow,
      ).first;
      expect(expensiveDecks.first.id, 'deck_alpha_z');
      expect(expensiveDecks.first.estimatedPrice, 499.0);

      // 4. Alphabetical -> First alphabetically (Abzan Tokens)
      final alphaDecks = await exploreDao.watchExploreDecks(
        sort: ExploreSortOption.alphabetical,
      ).first;
      expect(alphaDecks.first.name, 'Abzan Tokens');
      expect(alphaDecks.last.name, 'Zur the Enchanter Stax');
    });

    testWidgets('3. Multi-level search categorizes matches under "in Deck Name", "in Deck Cards", and "by Username"',
        (tester) async {
      // Perform 3-tier search via DAO
      final resultsName = await exploreDao.searchExploreDecks(query: 'Urza');
      expect(resultsName.inDeckName, hasLength(1));
      expect(resultsName.inDeckName.first.name, contains('Urza'));

      final resultsCard = await exploreDao.searchExploreDecks(query: 'Sol Ring');
      expect(resultsCard.inDeckCards, hasLength(1));
      expect(resultsCard.inDeckCards.first.matchingCardName, 'Sol Ring');
      expect(resultsCard.inDeckCards.first.deckWithVote.id, 'deck_search_2');

      final resultsUser = await exploreDao.searchExploreDecks(query: 'SpicyBrewMaster');
      expect(resultsUser.byUsername, hasLength(1));
      expect(resultsUser.byUsername.first.creatorName, contains('SpicyBrewMaster'));

      // Now verify UI rendering of Multi-Tier Search Results View
      await tester.pumpWidget(createSubject(initialTopTab: 1));
      await tester.pumpAndSettle();

      // Enter search query 'Sol Ring'
      await tester.enterText(find.byKey(const Key('explore_search_input')), 'Sol Ring');
      await tester.pumpAndSettle();

      // Section header "in Deck Cards" is visible
      expect(find.byKey(const Key('explore_search_group_cards')), findsOneWidget);
      // Subtitle "contains: Sol Ring" is visible
      expect(find.textContaining('contains: Sol Ring'), findsWidgets);
      // Matching deck title is visible
      expect(find.text('Goblins Burn Aggro'), findsOneWidget);

      // Enter search query 'Urza'
      await tester.enterText(find.byKey(const Key('explore_search_input')), 'Urza');
      await tester.pumpAndSettle();

      // Section header "in Deck Name" is visible
      expect(find.byKey(const Key('explore_search_group_name')), findsOneWidget);
      expect(find.text('Urza Thopter Army'), findsOneWidget);

      // Enter search query 'SpicyBrewMaster'
      await tester.enterText(find.byKey(const Key('explore_search_input')), 'SpicyBrewMaster');
      await tester.pumpAndSettle();

      // Section header "by Username" is visible
      expect(find.byKey(const Key('explore_search_group_creator')), findsOneWidget);
      expect(find.text('Necromancy Reanimator'), findsOneWidget);
    });

    testWidgets('4. Clear search button restores discovery feed mode',
        (tester) async {
      await tester.pumpWidget(createSubject(initialTopTab: 1));
      await tester.pumpAndSettle();

      // Initially in discovery feed mode: carousels are present
      expect(find.byKey(const Key('explore_carousel_suggested_commanders')), findsOneWidget);

      // Enter search query -> transitions to search results view
      await tester.enterText(find.byKey(const Key('explore_search_input')), 'Urza');
      await tester.pumpAndSettle();

      // Carousels are not visible during search mode
      expect(find.byKey(const Key('explore_carousel_suggested_commanders')), findsNothing);
      expect(find.byKey(const Key('explore_search_group_name')), findsOneWidget);

      // Clear search button is visible
      final clearButton = find.byKey(const Key('explore_search_clear_button'));
      expect(clearButton, findsOneWidget);

      // Tap clear button
      await tester.tap(clearButton);
      await tester.pumpAndSettle();

      // Returned to discovery feed mode: carousels are restored
      expect(find.byKey(const Key('explore_carousel_suggested_commanders')), findsOneWidget);
      expect(find.byKey(const Key('explore_search_group_name')), findsNothing);
    });

    testWidgets('5. Empty search results display friendly empty state',
        (tester) async {
      await tester.pumpWidget(createSubject(initialTopTab: 1));
      await tester.pumpAndSettle();

      // Enter query that matches nothing
      await tester.enterText(find.byKey(const Key('explore_search_input')), 'NonexistentQueryXYZ');
      await tester.pumpAndSettle();

      expect(find.text('No decks found'), findsOneWidget);
      expect(find.textContaining('No explore decks match "NonexistentQueryXYZ"'), findsOneWidget);
    });
  });
}
