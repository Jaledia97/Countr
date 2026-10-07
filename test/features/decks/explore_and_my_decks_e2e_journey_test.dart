import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/decks/data/daos/explore_deck_dao.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/decks/presentation/providers/explore_deck_providers.dart';
import 'package:countr/features/decks/presentation/screens/decks_screen.dart';
import 'package:countr/features/decks/presentation/screens/read_only_deck_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  late AppDatabase db;
  late VaultDao vaultDao;
  late ExploreDeckDao exploreDao;

  const testExploreDeckId = 'journey_explore_deck_1';
  const testPersonalDeckId = 'deck-edgar-markov'; // Pre-seeded by AppDatabase

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    vaultDao = VaultDao(db);
    exploreDao = ExploreDeckDao(db);

    final now = DateTime.now();

    // Seed explore deck in `explore_decks`
    await db.into(db.exploreDecks).insert(
      ExploreDecksCompanion.insert(
        id: testExploreDeckId,
        name: 'Atraxa Praetors Voice Proliferation',
        format: 'Commander',
        tcgDomain: const Value('mtg'),
        sourceType: const Value('official'),
        creatorName: const Value('Official WotC'),
        description: const Value('Breed Lethality official Commander precon.'),
        commanderName: const Value('Atraxa, Praetors\' Voice'),
        colorIdentity: const Value('["W","U","B","G"]'),
        cardCount: const Value(100),
        estimatedPrice: const Value(180.00),
        upvotes: const Value(75),
        downvotes: const Value(5),
        score: const Value(70),
        featuredCategory: const Value('Suggested Commanders'),
        createdAt: now.subtract(const Duration(days: 5)),
        updatedAt: Value(now),
        isDeleted: const Value(false),
      ),
    );

    await db.into(db.exploreDeckItems).insert(
      ExploreDeckItemsCompanion.insert(
        id: 'explore_item_atraxa',
        exploreDeckId: testExploreDeckId,
        cardName: 'Atraxa, Praetors\' Voice',
        manaCost: const Value('{G}{W}{U}{B}'),
        cmc: const Value(4.0),
        typeLine: const Value('Legendary Creature — Phyrexian Angel Horror'),
        quantity: const Value(1),
        boardZone: const Value('Commander'),
        isCommander: const Value(true),
        price: const Value(15.00),
      ),
    );

    await db.into(db.exploreDeckItems).insert(
      ExploreDeckItemsCompanion.insert(
        id: 'explore_item_doubling_season',
        exploreDeckId: testExploreDeckId,
        cardName: 'Doubling Season',
        manaCost: const Value('{4}{G}'),
        cmc: const Value(5.0),
        typeLine: const Value('Enchantment'),
        quantity: const Value(1),
        boardZone: const Value('Mainboard'),
        isCommander: const Value(false),
        price: const Value(45.00),
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  Widget createSubject({
    String initialTcgFilter = 'all',
  }) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        vaultDaoProvider.overrideWithValue(vaultDao),
        exploreDeckDaoProvider.overrideWithValue(exploreDao),
        activeDeckTcgFilterProvider.overrideWith((ref) => initialTcgFilter),
      ],
      child: const MaterialApp(
        home: DecksScreen(),
      ),
    );
  }

  group('TEST_INFRA Tier 4 Real-World Application Scenarios (F1-F21)', () {
    // =========================================================================
    // Scenario 1: Personal Deck Search & Filtering (F3, F4, F5)
    // =========================================================================
    testWidgets('Scenario 1: Personal Deck Search & Filtering exercises F3, F4, F5',
        (tester) async {
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      // Verify personal deck is rendered with Assembled badge (F3)
      expect(find.byKey(const Key('deck_item_$testPersonalDeckId')), findsOneWidget);
      expect(find.byKey(const Key('deck_assembly_status_$testPersonalDeckId')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('deck_assembly_status_$testPersonalDeckId')),
          matching: find.text('Assembled'),
        ),
        findsOneWidget,
      );

      // Search by deck name (F4)
      final searchInput = find.byKey(const Key('my_decks_search_input'));
      expect(searchInput, findsOneWidget);
      await tester.enterText(searchInput, 'Edgar');
      await tester.pumpAndSettle();

      // Dividers and matches
      expect(find.text('in Deck Name'), findsOneWidget);
      expect(find.text('Edgar Markov Aristocrats'), findsOneWidget);

      // Clear search
      await tester.tap(find.byKey(const Key('my_decks_search_clear_button')));
      await tester.pumpAndSettle();

      // Quick filter pill (F5)
      final filterAll = find.byKey(const Key('decks_tab_all'));
      expect(filterAll, findsOneWidget);
      await tester.tap(filterAll);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('deck_item_$testPersonalDeckId')), findsOneWidget);
    });

    // =========================================================================
    // Scenario 2: Share Personal Deck to Explore (F6, F7, F8, F11)
    // =========================================================================
    testWidgets('Scenario 2: Share Personal Deck to Explore exercises F6, F7, F8, F11',
        (tester) async {
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      // Long press personal deck card to activate Selection Mode (F7)
      await tester.longPress(find.byKey(const Key('deck_item_$testPersonalDeckId')));
      await tester.pumpAndSettle();

      // Selection footer appears (F7)
      expect(find.byKey(const Key('my_decks_selection_footer')), findsOneWidget);
      expect(find.text('1 selected'), findsOneWidget);

      // Tapping "Share to Explore" button
      final shareBtn = find.byKey(const Key('selection_share_to_explore_button'));
      expect(shareBtn, findsOneWidget);
      await tester.tap(shareBtn);
      await tester.pumpAndSettle();

      // Verify SnackBar toast and exit of selection mode
      expect(find.text('Deck "Edgar Markov Aristocrats" shared to Explore!'), findsOneWidget);
      expect(find.byKey(const Key('my_decks_selection_footer')), findsNothing);

      // Verify in SQLite database that explore deck was created with user_shared (F8)
      final sharedDecks = await (db.select(db.exploreDecks)
            ..where((tbl) => tbl.sourceType.equals('user_shared')))
          .get();
      expect(sharedDecks.length, equals(1));
      expect(sharedDecks.first.name, equals('Edgar Markov Aristocrats'));
    });

    // =========================================================================
    // Scenario 3: Explore Discovery, Carousel Browsing & Sorting (F11-F16)
    // =========================================================================
    testWidgets(
        'Scenario 3: Explore Discovery, Carousel Browsing & Sorting exercises F11-F16',
        (tester) async {
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      // Switch to Explore Decks tab
      await tester.tap(find.byKey(const Key('decks_top_tab_explore')));
      await tester.pumpAndSettle();

      // Top-level pills: All, Official, Community (F11)
      expect(find.byKey(const Key('explore_pill_all')), findsOneWidget);
      expect(find.byKey(const Key('explore_pill_official')), findsOneWidget);
      expect(find.byKey(const Key('explore_pill_community')), findsOneWidget);

      // Explore card is displayed
      expect(find.byKey(const Key('explore_card_$testExploreDeckId')), findsWidgets);

      // Embedded sort menu (F15)
      final sortBtn = find.byKey(const Key('explore_search_sort_button'));
      expect(sortBtn, findsOneWidget);
      await tester.tap(sortBtn);
      await tester.pumpAndSettle();

      // Verify 5 sort options
      expect(find.byKey(const Key('explore_sort_popular')), findsOneWidget);
      expect(find.byKey(const Key('explore_sort_recent')), findsOneWidget);
      expect(find.byKey(const Key('explore_sort_price_asc')), findsOneWidget);
      expect(find.byKey(const Key('explore_sort_price_desc')), findsOneWidget);
      expect(find.byKey(const Key('explore_sort_alpha')), findsOneWidget);

      // Select alphabetical sort
      await tester.tap(find.byKey(const Key('explore_sort_alpha')));
      await tester.pumpAndSettle();

      // Filter modal button (F14)
      final filterBtn = find.byKey(const Key('explore_filter_button'));
      expect(filterBtn, findsOneWidget);
      await tester.tap(filterBtn);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('explore_filter_modal')), findsOneWidget);
      await tester.tap(find.byKey(const Key('explore_filter_close_button')));
      await tester.pumpAndSettle();
    });

    // =========================================================================
    // Scenario 4: Offline Precon Seeding, Voting & SQLite Persistence (F8, F9, F10, F17, F18)
    // =========================================================================
    testWidgets(
        'Scenario 4: Offline Precon Seeding, Voting & SQLite Persistence exercises F8, F9, F10, F17, F18',
        (tester) async {
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      // Switch to Explore Decks tab
      await tester.tap(find.byKey(const Key('decks_top_tab_explore')));
      await tester.pumpAndSettle();

      // Upvote deck on explore summary card (F17, F18)
      final upvoteBtn = find.byKey(const Key('explore_upvote_$testExploreDeckId')).first;
      expect(upvoteBtn, findsOneWidget);
      expect(find.byKey(const Key('explore_score_$testExploreDeckId')), findsWidgets);
      expect(find.text('70'), findsWidgets);

      // Tap upvote
      await tester.tap(upvoteBtn);
      await tester.pumpAndSettle();

      // Score updates from 70 to 71
      expect(find.text('71'), findsWidgets);

      // Verify in SQLite database (F18)
      final votes = await (db.select(db.exploreDeckVotes)
            ..where((tbl) => tbl.exploreDeckId.equals(testExploreDeckId)))
          .get();
      expect(votes.length, equals(1));
      expect(votes.first.vote, equals(1));

      // Toggle off upvote
      await tester.tap(upvoteBtn);
      await tester.pumpAndSettle();

      expect(find.text('70'), findsWidgets);
    });

    // =========================================================================
    // Scenario 5: Explore Deck Read-Only Inspection & Clone to My Decks (F17, F19, F20, F1, F3)
    // =========================================================================
    testWidgets(
        'Scenario 5: Explore Deck Read-Only Inspection & Clone to My Decks exercises F17, F19, F20, F1, F3',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(vaultDao),
            exploreDeckDaoProvider.overrideWithValue(exploreDao),
          ],
          child: MaterialApp(
            home: ReadOnlyDeckScreen(exploreDeckId: testExploreDeckId),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify read-only screen loaded (F19)
      expect(find.byKey(const Key('read_only_deck_screen')), findsOneWidget);
      expect(find.text('Atraxa Praetors Voice Proliferation'), findsAtLeastNWidgets(1));

      // Verify partitioned cards
      expect(find.byKey(const Key('read_only_section_commander')), findsOneWidget);
      expect(find.byKey(const Key('read_only_section_permanents')), findsOneWidget);

      // Clone deck to "My Decks" (F20)
      final cloneBtn = find.byKey(const Key('explore_clone_deck_button'));
      expect(cloneBtn, findsOneWidget);
      await tester.tap(cloneBtn);
      await tester.pumpAndSettle();

      // Verify snackbar feedback
      expect(find.text('Cloned "Atraxa Praetors Voice Proliferation" to My Decks!'), findsOneWidget);

      // Verify in SQLite database that cloned deck exists with isCloned = true
      final personalDecks = await db.select(db.decks).get();
      final clonedDeck = personalDecks.firstWhere((d) => d.name.contains('Atraxa'));
      expect(clonedDeck.isCloned, isTrue);
      expect(clonedDeck.isAssembled, isFalse);
    });

    // =========================================================================
    // Scenario 6: Full E2E User Journey (Browse -> Vote -> Clone -> Edit -> Share) (F1-F21)
    // =========================================================================
    testWidgets(
        'Scenario 6: Full E2E User Journey (Browse -> Vote -> Clone -> My Decks -> Share) exercises F1-F21',
        (tester) async {
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exception is NetworkImageLoadException ||
            details.toString().contains('NetworkImageLoadException') ||
            details.library == 'image resource service') {
          return;
        }
        originalOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalOnError);

      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      // 1. Start in Explore Tab (F1)
      await tester.tap(find.byKey(const Key('decks_top_tab_explore')));
      await tester.pumpAndSettle();

      // 2. Upvote an explore deck (F18)
      final upvoteBtn = find.byKey(const Key('explore_upvote_$testExploreDeckId')).first;
      expect(upvoteBtn, findsOneWidget);
      await tester.tap(upvoteBtn);
      await tester.pumpAndSettle();
      expect(find.text('71'), findsWidgets);

      // 3. Open Read-Only Screen (F19)
      await tester.tap(find.byKey(const Key('explore_card_$testExploreDeckId')).first);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('read_only_deck_screen')), findsOneWidget);

      // 4. Clone to My Decks (F20)
      await tester.tap(find.byKey(const Key('explore_clone_deck_button')));
      await tester.pumpAndSettle();

      // 5. Navigate to My Decks via SnackBar action button
      await tester.tap(find.text('View in My Decks'));
      await tester.pumpAndSettle();

      // 6. Verify the cloned deck appears in My Decks with Draft badge (F3)
      expect(find.text('Atraxa Praetors Voice Proliferation (Copy)'), findsOneWidget);

      // 7. Find cloned deck card, long press to enter selection mode (F7)
      final personalDecks = await db.select(db.decks).get();
      final clonedDeck = personalDecks.firstWhere((d) => d.name.contains('Atraxa'));
      await tester.longPress(find.byKey(Key('deck_item_${clonedDeck.id}')));
      await tester.pumpAndSettle();

      // 8. Share cloned deck back to Explore (F6, F8)
      expect(find.byKey(const Key('my_decks_selection_footer')), findsOneWidget);
      await tester.tap(find.byKey(const Key('selection_share_to_explore_button')));
      await tester.pumpAndSettle();

      // 9. Verify shared deck in SQLite exploreDecks table
      final sharedDecks = await (db.select(db.exploreDecks)
            ..where((tbl) => tbl.sourceType.equals('user_shared')))
          .get();
      expect(sharedDecks.any((d) => d.name.contains('Atraxa')), isTrue);
    });
  });
}
