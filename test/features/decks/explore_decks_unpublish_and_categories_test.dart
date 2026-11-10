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
import 'package:countr/features/decks/domain/models/explore_deck_models.dart';
import 'package:countr/features/decks/domain/services/explore_category_engine.dart';
import 'package:countr/features/decks/presentation/screens/read_only_deck_screen.dart';
import 'package:countr/features/decks/presentation/widgets/explore/explore_deck_card.dart';
import 'package:countr/features/decks/presentation/widgets/explore/explore_deck_unpublish_dialog.dart';
import 'package:countr/features/decks/presentation/widgets/explore/explore_carousel_section.dart';
import 'package:countr/features/profile/presentation/providers/profile_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late VaultDao vaultDao;
  late ExploreDeckDao exploreDao;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    vaultDao = VaultDao(db);
    exploreDao = ExploreDeckDao(db);

    // Seed database with default starter decks (including Edgar Markov)
    await vaultDao.seedDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  group('Feature 16: Explore Deck Unpublish Backend & Personal Deck Preservation', () {
    test('unpublishExploreDeck soft-deletes explore_decks and items, logs sync, and preserves personal deck intact', () async {
      // 1. Share Edgar Markov personal deck to Explore
      final personalDeckId = MockDeckData.edgarMarkovDeckId;
      final sharedDeck = await exploreDao.sharePersonalDeckToExplore(
        personalDeckId: personalDeckId,
        creatorName: '@VampireLord',
        authorId: 'user-vampire-123',
      );

      final personalBefore = await vaultDao.getDeck(personalDeckId);
      expect(personalBefore, isNotNull);
      final personalItemsBefore = await vaultDao.watchDeckItems(personalDeckId).first;
      expect(personalItemsBefore.length, equals(100));

      // Verify published in Explore
      final feedBefore = await exploreDao.watchExploreDecks().first;
      expect(feedBefore.any((d) => d.id == sharedDeck.id), isTrue);

      final itemsBefore = await exploreDao.getExploreDeckItems(sharedDeck.id);
      expect(itemsBefore.length, equals(100));

      // 2. Unpublish from Explore
      await exploreDao.unpublishExploreDeck(exploreDeckId: sharedDeck.id);

      // 3. Verify soft-delete in explore_decks
      final rawExploreDeck = await (db.select(db.exploreDecks)
            ..where((t) => t.id.equals(sharedDeck.id)))
          .getSingle();
      expect(rawExploreDeck.isDeleted, isTrue);
      expect(rawExploreDeck.updatedAt, isNotNull);

      // 4. Verify soft-delete in explore_deck_items
      final rawExploreItems = await (db.select(db.exploreDeckItems)
            ..where((t) => t.exploreDeckId.equals(sharedDeck.id)))
          .get();
      expect(rawExploreItems.length, equals(100));
      expect(rawExploreItems.every((item) => item.isDeleted == true), isTrue);

      // 5. Verify mutation in sync_queue for Firebase deletion sync
      final syncEntries = await (db.select(db.syncQueue)
            ..where((t) => t.entityId.equals(sharedDeck.id)))
          .get();
      expect(syncEntries.length, equals(1));
      expect(syncEntries.first.entityType, equals('explore_deck'));
      expect(syncEntries.first.operation, equals('DELETE'));
      expect(syncEntries.first.retryCount, equals(0));

      // 6. Verify excluded from public feed queries
      final feedAfter = await exploreDao.watchExploreDecks().first;
      expect(feedAfter.any((d) => d.id == sharedDeck.id), isFalse);

      final detailAfter = await exploreDao.getExploreDeck(sharedDeck.id);
      expect(detailAfter, isNull);

      // 7. CRUCIAL INVARIANT: Personal copy in My Decks (decks and deck_version_items) is 100% untouched
      final personalAfter = await vaultDao.getDeck(personalDeckId);
      expect(personalAfter, isNotNull);
      expect(personalAfter!.id, equals(personalBefore!.id));
      expect(personalAfter.name, equals(personalBefore.name));
      expect(personalAfter.format, equals(personalBefore.format));
      expect(personalAfter.isDeleted, isFalse);

      final personalItemsAfter = await vaultDao.watchDeckItems(personalDeckId).first;
      expect(personalItemsAfter.length, equals(100));
      expect(personalItemsAfter.length, equals(personalItemsBefore.length));
    });
  });

  group('Feature 17: UI Unpublish Entry Points & Author Verification', () {
    test('isExploreDeckAuthor correctly gates based on authorId, aliases, and username', () async {
      final deck1 = ExploreDeck(
        id: 'deck-1',
        name: 'Mono Red',
        format: 'Standard',
        tcgDomain: 'mtg',
        sourceType: 'user_shared',
        creatorName: '@BrewMaster',
        authorId: 'usr_alpha_1',
        colorIdentity: '["R"]',
        cardCount: 60,
        estimatedPrice: 50.0,
        upvotes: 0,
        downvotes: 0,
        score: 0,
        createdAt: DateTime.now(),
        isDeleted: false,
      );

      // Direct authorId match
      expect(isExploreDeckAuthor(deck: deck1, currentUserId: 'usr_alpha_1'), isTrue);
      // Non-author
      expect(isExploreDeckAuthor(deck: deck1, currentUserId: 'usr_beta_2'), isFalse);

      // Guest / local alias match
      final guestDeck = ExploreDeck(
        id: 'deck-guest',
        name: 'Guest Deck',
        format: 'Commander',
        tcgDomain: 'mtg',
        sourceType: 'user_shared',
        creatorName: '@CurrentUser',
        authorId: 'local_user',
        colorIdentity: '["W"]',
        cardCount: 100,
        estimatedPrice: 30.0,
        upvotes: 0,
        downvotes: 0,
        score: 0,
        createdAt: DateTime.now(),
        isDeleted: false,
      );
      expect(isExploreDeckAuthor(deck: guestDeck, currentUserId: 'user-current-me'), isTrue);
      expect(isExploreDeckAuthor(deck: guestDeck, currentUserId: 'local_user'), isTrue);

      // Username match fallback
      final namedDeck = ExploreDeck(
        id: 'deck-named',
        name: 'Named Deck',
        format: 'Modern',
        tcgDomain: 'mtg',
        sourceType: 'user_shared',
        creatorName: '@SpicyBrewer',
        authorId: null,
        colorIdentity: '["B"]',
        cardCount: 60,
        estimatedPrice: 75.0,
        upvotes: 0,
        downvotes: 0,
        score: 0,
        createdAt: DateTime.now(),
        isDeleted: false,
      );
      expect(isExploreDeckAuthor(deck: namedDeck, currentUserId: 'user-spicybrewer'), isTrue);
    });

    testWidgets('ReadOnlyDeckScreen: Author sees overflow menu and unpublishes via confirmation dialog', (tester) async {
      // 1. Share deck with authorId = 'test-author'
      final shared = await exploreDao.sharePersonalDeckToExplore(
        personalDeckId: MockDeckData.edgarMarkovDeckId,
        creatorName: '@AuthorTester',
        authorId: 'test-author',
      );

      // Pump ReadOnlyDeckScreen as the author
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            currentUserIdProvider.overrideWith((ref) => 'test-author'),
          ],
          child: MaterialApp(
            home: ReadOnlyDeckScreen(exploreDeckId: shared.id),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Overflow menu should be visible for author
      final overflowFinder = find.byKey(const Key('read_only_deck_overflow_menu'));
      expect(overflowFinder, findsOneWidget);

      // Tap overflow menu
      await tester.tap(overflowFinder);
      await tester.pumpAndSettle();

      // Unpublish option should be visible
      final unpublishOption = find.byKey(const Key('read_only_unpublish_menu_item'));
      expect(unpublishOption, findsOneWidget);

      // Tap unpublish option -> Opens dialog
      await tester.tap(unpublishOption);
      await tester.pumpAndSettle();

      // Verify dialog copy
      expect(find.text('Unpublish Deck?'), findsOneWidget);
      expect(
        find.text(
          'Unpublish from Explore? This removes the deck from public Explore. Your personal copy in My Decks will remain intact.',
        ),
        findsOneWidget,
      );

      // Tap Cancel -> does NOT unpublish
      final cancelBtn = find.byKey(const Key('cancel_unpublish_button'));
      expect(cancelBtn, findsOneWidget);
      await tester.tap(cancelBtn);
      await tester.pumpAndSettle();

      var deckCheck = await exploreDao.getExploreDeck(shared.id);
      expect(deckCheck, isNotNull);

      // Tap menu again and Confirm unpublish
      await tester.tap(overflowFinder);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('read_only_unpublish_menu_item')));
      await tester.pumpAndSettle();

      final confirmBtn = find.byKey(const Key('confirm_unpublish_button'));
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Verify deck is soft-deleted
      deckCheck = await exploreDao.getExploreDeck(shared.id);
      expect(deckCheck, isNull);

      // Verify personal deck is untouched
      final personal = await vaultDao.getDeck(MockDeckData.edgarMarkovDeckId);
      expect(personal, isNotNull);
      expect(personal!.isDeleted, isFalse);
    });

    testWidgets('ReadOnlyDeckScreen: Non-author does NOT see overflow menu', (tester) async {
      final shared = await exploreDao.sharePersonalDeckToExplore(
        personalDeckId: MockDeckData.edgarMarkovDeckId,
        creatorName: '@AuthorTester',
        authorId: 'test-author',
      );

      // Pump ReadOnlyDeckScreen as stranger
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            currentUserIdProvider.overrideWith((ref) => 'other-user'),
          ],
          child: MaterialApp(
            home: ReadOnlyDeckScreen(exploreDeckId: shared.id),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Overflow menu must NOT be visible
      expect(find.byKey(const Key('read_only_deck_overflow_menu')), findsNothing);
    });

    testWidgets('ExploreDeckCard: Author sees top-right overflow button on artwork banner', (tester) async {
      final shared = await exploreDao.sharePersonalDeckToExplore(
        personalDeckId: MockDeckData.edgarMarkovDeckId,
        creatorName: '@CardAuthor',
        authorId: 'card-author-1',
      );

      // Pump for Author
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            currentUserIdProvider.overrideWith((ref) => 'card-author-1'),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 180,
                height: 280,
                child: ExploreDeckCard(
                  deckWithVote: ExploreDeckWithVote(deck: shared, userVote: 0),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cardMenu = find.byKey(Key('explore_card_menu_${shared.id}'));
      expect(cardMenu, findsOneWidget);

      await tester.tap(cardMenu);
      await tester.pumpAndSettle();

      final cardUnpublish = find.byKey(Key('explore_card_menu_unpublish_${shared.id}'));
      expect(cardUnpublish, findsOneWidget);
    });

    testWidgets('ExploreDeckCard: Non-author does NOT see top-right overflow button', (tester) async {
      final shared = await exploreDao.sharePersonalDeckToExplore(
        personalDeckId: MockDeckData.edgarMarkovDeckId,
        creatorName: '@CardAuthor',
        authorId: 'card-author-1',
      );

      // Pump for Non-Author
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            currentUserIdProvider.overrideWith((ref) => 'stranger-user'),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 180,
                height: 280,
                child: ExploreDeckCard(
                  deckWithVote: ExploreDeckWithVote(deck: shared, userVote: 0),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(Key('explore_card_menu_${shared.id}')), findsNothing);
    });
  });

  group('Feature 18: ExploreCategoryEngine 48h Vote Velocity Window', () {
    late ExploreCategoryEngine engine;

    setUp(() {
      engine = ExploreCategoryEngine(exploreDao, velocityThreshold: 5);
    });

    test('resolveLeadVelocityWindow falls back to This Months Picks when vote activity is low', () async {
      final window = await engine.resolveLeadVelocityWindow();
      expect(window, equals(LeadVelocityWindow.thisMonthsPicks));
      expect(window.title, equals("This Month's Picks"));
    });

    test('resolveLeadVelocityWindow switches to This Weeks Picks when 7d count >= threshold', () async {
      final now = DateTime.now();

      // Insert 5 votes from 3 days ago (within 7d, outside 48h)
      for (int i = 0; i < 5; i++) {
        await db.into(db.exploreDeckVotes).insert(
          ExploreDeckVotesCompanion.insert(
            id: 'vote-7d-$i',
            exploreDeckId: 'explore_shared_${MockDeckData.edgarMarkovDeckId}',
            userId: Value('voter-$i'),
            vote: const Value(1),
            updatedAt: now.subtract(const Duration(days: 3)),
          ),
        );
      }

      final window = await engine.resolveLeadVelocityWindow(now: now);
      expect(window, equals(LeadVelocityWindow.thisWeeksPicks));
      expect(window.title, equals("This Week's Picks"));
    });

    test('resolveLeadVelocityWindow switches to Todays Picks when 48h count >= threshold', () async {
      final now = DateTime.now();

      // Insert 5 votes within past 24 hours (within 48h)
      for (int i = 0; i < 5; i++) {
        await db.into(db.exploreDeckVotes).insert(
          ExploreDeckVotesCompanion.insert(
            id: 'vote-48h-$i',
            exploreDeckId: 'explore_shared_${MockDeckData.edgarMarkovDeckId}',
            userId: Value('voter-48-$i'),
            vote: const Value(1),
            updatedAt: now.subtract(const Duration(hours: 12)),
          ),
        );
      }

      final window = await engine.resolveLeadVelocityWindow(now: now);
      expect(window, equals(LeadVelocityWindow.todaysPicks));
      expect(window.title, equals("Today's Picks"));
    });

    test('watchDecksByVoteVelocity ranks decks with recent positive velocity first', () async {
      final now = DateTime.now();

      // Create two explore decks
      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: 'deck-alpha',
          name: 'Alpha Hot Deck',
          format: 'Commander',
          createdAt: now,
          score: const Value(10),
          isDeleted: const Value(false),
        ),
      );
      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: 'deck-beta',
          name: 'Beta Older Deck',
          format: 'Commander',
          createdAt: now,
          score: const Value(100), // higher baseline score
          isDeleted: const Value(false),
        ),
      );

      // Cast 3 fresh upvotes on deck-alpha within 48h
      for (int i = 0; i < 3; i++) {
        await db.into(db.exploreDeckVotes).insert(
          ExploreDeckVotesCompanion.insert(
            id: 'alpha-vote-$i',
            exploreDeckId: 'deck-alpha',
            userId: Value('voter-$i'),
            vote: const Value(1),
            updatedAt: now.subtract(const Duration(hours: 2)),
          ),
        );
      }

      final cutoff = now.subtract(const Duration(hours: 48));
      final ranked = await exploreDao.watchDecksByVoteVelocity(cutoff: cutoff).first;

      // deck-alpha has fresh velocity so it should rank higher than deck-beta
      expect(ranked.first.deck.id, equals('deck-alpha'));
    });
  });

  group('Feature 19 & 20: Deterministic Lateral Categories & Drill-Down Filtering', () {
    late ExploreCategoryEngine engine;

    setUp(() {
      engine = ExploreCategoryEngine(exploreDao);
    });

    test('dayOfYear and weekOfYear deterministic date calculation', () {
      final jan1 = DateTime(2026, 1, 1);
      expect(jan1.dayOfYear, equals(1));
      expect(jan1.weekOfYear, equals(1));

      final feb1 = DateTime(2026, 2, 1);
      expect(feb1.dayOfYear, equals(32));
      expect(feb1.weekOfYear, equals(5));

      final dec31 = DateTime(2026, 12, 31);
      expect(dec31.dayOfYear, equals(365));
      expect(dec31.weekOfYear, equals(53));
    });

    test('resolveDailyRotatingCategory & resolveWeeklyRotatingCategory are deterministic and avoid collision', () {
      final dateA = DateTime(2026, 3, 15);
      final dailyA = engine.resolveDailyRotatingCategory(dateA);
      final weeklyA = engine.resolveWeeklyRotatingCategory(dateA);

      expect(dailyA, isNotNull);
      expect(weeklyA, isNotNull);
      // Ensure daily and weekly never collide on same id
      expect(dailyA.id != weeklyA.id, isTrue);

      // Calling again with same date produces identical results
      expect(engine.resolveDailyRotatingCategory(dateA).id, equals(dailyA.id));
      expect(engine.resolveWeeklyRotatingCategory(dateA).id, equals(weeklyA.id));
    });

    test('watchExploreDecks and watchFeaturedCategory filter properly for algorithmic categories', () async {
      final now = DateTime.now();

      // Seed a budget deck ($45) and an expensive deck ($450)
      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: 'deck-budget',
          name: 'Budget Goblins',
          format: 'Commander',
          estimatedPrice: const Value(45.0),
          createdAt: now,
          isDeleted: const Value(false),
        ),
      );
      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: 'deck-expensive',
          name: 'Cedh Timetwister',
          format: 'Commander',
          estimatedPrice: const Value(4500.0),
          createdAt: now,
          isDeleted: const Value(false),
        ),
      );

      // Query Trending Budget Brews (<$100)
      final budgetDecks = await exploreDao.watchExploreDecks(
        featuredCategory: r'Trending Budget Brews (<$100)',
      ).first;

      expect(budgetDecks.any((d) => d.id == 'deck-budget'), isTrue);
      expect(budgetDecks.any((d) => d.id == 'deck-expensive'), isFalse);
    });

    testWidgets('ExploreCarouselSection: See More triggers drill-down category selection', (tester) async {
      String? selectedCategory;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ExploreCarouselSection(
                category: "Today's Picks",
                title: "Today's Picks",
                onSeeMore: () {
                  selectedCategory = "Today's Picks";
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final seeMoreFinder = find.byKey(const Key('explore_carousel_see_more_todays_picks'));
      expect(seeMoreFinder, findsOneWidget);

      await tester.tap(seeMoreFinder);
      await tester.pumpAndSettle();

      expect(selectedCategory, equals("Today's Picks"));
    });
  });
}
