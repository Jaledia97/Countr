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

  const testExploreDeckId = 'm6_challenger_explore_deck_1';

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    vaultDao = VaultDao(db);
    exploreDao = ExploreDeckDao(db);

    final now = DateTime.now();

    // Seed test explore precon in explore_decks
    await db.into(db.exploreDecks).insert(
      ExploreDecksCompanion.insert(
        id: testExploreDeckId,
        name: 'Urza Lord High Artificer Combo',
        format: 'Commander',
        tcgDomain: const Value('mtg'),
        sourceType: const Value('official'),
        creatorName: const Value('Official WotC'),
        description: const Value('High power artifact precon deck for verification.'),
        commanderName: const Value('Urza, Lord High Artificer'),
        colorIdentity: const Value('["U"]'),
        cardCount: const Value(100),
        estimatedPrice: const Value(349.99),
        upvotes: const Value(50),
        downvotes: const Value(2),
        score: const Value(48),
        featuredCategory: const Value('Suggested Commanders'),
        createdAt: now.subtract(const Duration(days: 3)),
        updatedAt: Value(now),
        isDeleted: const Value(false),
      ),
    );

    await db.into(db.exploreDeckItems).insert(
      ExploreDeckItemsCompanion.insert(
        id: 'urza_item_commander',
        exploreDeckId: testExploreDeckId,
        cardName: 'Urza, Lord High Artificer',
        manaCost: const Value('{2}{U}{U}'),
        cmc: const Value(4.0),
        typeLine: const Value('Legendary Creature — Human Artificer'),
        quantity: const Value(1),
        boardZone: const Value('Commander'),
        isCommander: const Value(true),
        price: const Value(45.00),
      ),
    );

    await db.into(db.exploreDeckItems).insert(
      ExploreDeckItemsCompanion.insert(
        id: 'urza_item_mana_vault',
        exploreDeckId: testExploreDeckId,
        cardName: 'Mana Vault',
        manaCost: const Value('{1}'),
        cmc: const Value(1.0),
        typeLine: const Value('Artifact'),
        quantity: const Value(1),
        boardZone: const Value('Mainboard'),
        isCommander: const Value(false),
        price: const Value(65.00),
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildSubject({
    ProviderContainer? container,
    int initialTopTab = 0,
    String initialTcgFilter = 'all',
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
        activeDeckTcgFilterProvider.overrideWith((ref) => initialTcgFilter),
      ],
      child: const MaterialApp(
        home: DecksScreen(),
      ),
    );
  }

  void ignoreImageErrors(WidgetTester tester) {
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
  }

  void setupLargeViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  group('Milestone 6 Empirical Adversarial Challenge: E2E Suite Validation & Hardening', () {
    // =========================================================================
    // 1. DUAL-TAB RAPID SWITCHING, STATE ISOLATION & SCROLL PRESERVATION
    // =========================================================================
    testWidgets(
      'Challenge 1.1: Rapid switching between Tab 0 and Tab 1 preserves independent query, filter, and category states without cross-contamination',
      (tester) async {
        setupLargeViewport(tester);
        ignoreImageErrors(tester);

        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(vaultDao),
            exploreDeckDaoProvider.overrideWithValue(exploreDao),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(buildSubject(container: container));
        await tester.pumpAndSettle();

        // 1. Establish state on Tab 0 ("My Decks")
        final myDecksSearchInput = find.byKey(const Key('my_decks_search_input'));
        expect(myDecksSearchInput, findsOneWidget);
        await tester.enterText(myDecksSearchInput, 'Edgar');
        await tester.pumpAndSettle();

        expect(container.read(myDecksSearchQueryProvider), 'Edgar');
        expect(find.byKey(const Key('my_decks_search_header_name')), findsOneWidget);

        // Switch Tab 0 filter to "Draft"
        final draftSubtab = find.byKey(const Key('decks_tab_draft'));
        expect(draftSubtab, findsOneWidget);
        await tester.tap(draftSubtab);
        await tester.pumpAndSettle();

        // 2. Switch to Tab 1 ("Explore Decks")
        final tabExplore = find.byKey(const Key('decks_top_tab_explore'));
        await tester.tap(tabExplore);
        await tester.pumpAndSettle();

        // Verify Tab 1 is clean and unaffected by Tab 0 state
        expect(container.read(exploreSearchQueryProvider), '');
        expect(container.read(activeExploreCategoryProvider), ExploreCategory.all);

        // Establish state on Tab 1
        final communityPill = find.byKey(const Key('explore_pill_community'));
        expect(communityPill, findsOneWidget);
        await tester.tap(communityPill);
        await tester.pumpAndSettle();
        expect(container.read(activeExploreCategoryProvider), ExploreCategory.community);

        final exploreSearchInput = find.byKey(const Key('explore_search_input'));
        expect(exploreSearchInput, findsOneWidget);
        await tester.enterText(exploreSearchInput, 'Urza');
        await tester.pumpAndSettle();
        expect(container.read(exploreSearchQueryProvider), 'Urza');

        // 3. Perform 30 rapid switches between Tab 0 and Tab 1
        final tabMyDecks = find.byKey(const Key('decks_top_tab_my_decks'));
        for (int i = 0; i < 15; i++) {
          await tester.tap(tabMyDecks);
          await tester.pump(const Duration(milliseconds: 50));
          await tester.tap(tabExplore);
          await tester.pump(const Duration(milliseconds: 50));
        }
        await tester.pumpAndSettle();

        // Assert Tab 1 state after rapid thrashing
        expect(container.read(decksTopTabProvider), 1);
        expect(container.read(exploreSearchQueryProvider), 'Urza');
        expect(container.read(activeExploreCategoryProvider), ExploreCategory.community);

        // 4. Switch back to Tab 0 and assert complete preservation
        await tester.tap(tabMyDecks);
        await tester.pumpAndSettle();

        expect(container.read(decksTopTabProvider), 0);
        expect(container.read(myDecksSearchQueryProvider), 'Edgar');
        final myDecksField = tester.widget<TextField>(myDecksSearchInput);
        expect(myDecksField.controller?.text, 'Edgar');
        expect(find.byKey(const Key('my_decks_search_header_name')), findsOneWidget);

        // Tab 1 state must NOT have leaked into Tab 0
        expect(container.read(exploreSearchQueryProvider), 'Urza');
      },
    );

    testWidgets(
      'Challenge 1.2: Bidirectional scroll preservation across tabs under sustained switching',
      (tester) async {
        setupLargeViewport(tester);
        ignoreImageErrors(tester);

        // Seed 25 personal decks for Tab 0
        final now = DateTime.now();
        for (int i = 0; i < 25; i++) {
          await db.into(db.decks).insert(
            DecksCompanion.insert(
              id: 'm6-personal-deck-$i',
              name: 'Personal Stress Deck #$i',
              format: 'MTG Commander',
              tcgDomain: const Value('mtg'),
              createdAt: now,
            ),
          );
        }

        // Seed 25 explore decks for Tab 1
        for (int i = 0; i < 25; i++) {
          await db.into(db.exploreDecks).insert(
            ExploreDecksCompanion.insert(
              id: 'm6-explore-deck-$i',
              name: 'Explore Stress Precon #$i',
              format: 'Commander',
              tcgDomain: const Value('mtg'),
              sourceType: const Value('official'),
              creatorName: const Value('WotC Seeder'),
              createdAt: now,
            ),
          );
        }

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        // Step A: Scroll Tab 0 down
        final tab0ScrollFinder = find.byKey(const PageStorageKey('my_decks_scroll_key'));
        expect(tab0ScrollFinder, findsOneWidget);
        await tester.drag(tab0ScrollFinder, const Offset(0, -600));
        await tester.pumpAndSettle();

        final tab0Scrollable = find.descendant(of: tab0ScrollFinder, matching: find.byType(Scrollable));
        final scrolledTab0Offset = tester.state<ScrollableState>(tab0Scrollable.first).position.pixels;
        expect(scrolledTab0Offset, greaterThan(350.0));

        // Step B: Switch to Tab 1 and scroll down
        await tester.tap(find.byKey(const Key('decks_top_tab_explore')));
        await tester.pumpAndSettle();

        final tab1ScrollFinder = find.byKey(const PageStorageKey('explore_decks_scroll_key'));
        expect(tab1ScrollFinder, findsOneWidget);
        await tester.drag(tab1ScrollFinder, const Offset(0, -750));
        await tester.pumpAndSettle();

        final tab1Scrollable = find.descendant(of: tab1ScrollFinder, matching: find.byType(Scrollable));
        final scrolledTab1Offset = tester.state<ScrollableState>(tab1Scrollable.first).position.pixels;
        expect(scrolledTab1Offset, greaterThan(450.0));

        // Step C: Rapid switch 10 times
        for (int i = 0; i < 5; i++) {
          await tester.tap(find.byKey(const Key('decks_top_tab_my_decks')));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('decks_top_tab_explore')));
          await tester.pumpAndSettle();
        }

        // Assert Tab 1 scroll position preserved
        final currentTab1State = tester.state<ScrollableState>(
          find.descendant(of: find.byKey(const PageStorageKey('explore_decks_scroll_key')), matching: find.byType(Scrollable)).first,
        );
        expect(currentTab1State.position.pixels, closeTo(scrolledTab1Offset, 1.0));

        // Switch to Tab 0 and assert Tab 0 scroll position preserved
        await tester.tap(find.byKey(const Key('decks_top_tab_my_decks')));
        await tester.pumpAndSettle();

        final currentTab0State = tester.state<ScrollableState>(
          find.descendant(of: find.byKey(const PageStorageKey('my_decks_scroll_key')), matching: find.byType(Scrollable)).first,
        );
        expect(currentTab0State.position.pixels, closeTo(scrolledTab0Offset, 1.0));
      },
    );

    // =========================================================================
    // 2. COMPLETE END-TO-END MULTI-SCREEN USER JOURNEY
    // =========================================================================
    testWidgets(
      'Challenge 2.1: Full E2E User Journey: Explore -> Upvote -> ReadOnlyDeckScreen (Zero mutation controls) -> Add to My Decks -> Draft badge -> Press-and-hold Share -> Explore Community pill user_shared verification',
      (tester) async {
        setupLargeViewport(tester);
        ignoreImageErrors(tester);

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        // 1. Navigate to Explore Decks Tab
        await tester.tap(find.byKey(const Key('decks_top_tab_explore')));
        await tester.pumpAndSettle();

        // 2. Discover deck in Explore feed & Upvote
        final upvoteBtn = find.byKey(const Key('explore_upvote_$testExploreDeckId')).first;
        expect(upvoteBtn, findsOneWidget);
        expect(find.text('48'), findsWidgets);

        await tester.tap(upvoteBtn);
        await tester.pumpAndSettle();

        // Verify score incremented in UI and SQLite
        expect(find.text('49'), findsWidgets);
        final voteRow = await (db.select(db.exploreDeckVotes)
              ..where((tbl) => tbl.exploreDeckId.equals(testExploreDeckId)))
            .getSingle();
        expect(voteRow.vote, equals(1));

        // 3. Open ReadOnlyDeckScreen
        final deckCard = find.byKey(const Key('explore_card_$testExploreDeckId')).first;
        expect(deckCard, findsOneWidget);
        await tester.tap(deckCard);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('read_only_deck_screen')), findsOneWidget);
        expect(find.text('Urza Lord High Artificer Combo'), findsAtLeastNWidgets(1));

        // 4. Verify ZERO mutation controls on ReadOnlyDeckScreen
        // There must be no add card, edit deck, delete card, or playtest modification controls
        expect(find.byKey(const Key('deck_builder_add_card_button')), findsNothing);
        expect(find.byKey(const Key('deck_builder_back_button')), findsNothing);
        expect(find.byIcon(Icons.edit_rounded), findsNothing);
        expect(find.byIcon(Icons.delete_rounded), findsNothing);
        expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
        expect(find.byIcon(Icons.add_circle_outline_rounded), findsNothing);

        // 5. Tap prominent "Add to My Decks" (Clone) button
        final cloneButton = find.byKey(const Key('explore_clone_deck_button'));
        expect(cloneButton, findsOneWidget);
        await tester.tap(cloneButton);
        await tester.pumpAndSettle();

        // 6. Verify SnackBar and tap 'View in My Decks' action
        expect(find.text('Cloned "Urza Lord High Artificer Combo" to My Decks!'), findsOneWidget);
        final viewAction = find.text('View in My Decks');
        expect(viewAction, findsOneWidget);
        await tester.tap(viewAction);
        await tester.pumpAndSettle();

        // 7. Verify we arrived on Tab 0 ("My Decks")
        expect(find.byKey(const Key('my_decks_search_input')), findsOneWidget);

        // 8. Find cloned deck in SQLite and verify properties
        final personalDecks = await db.select(db.decks).get();
        final clonedDeck = personalDecks.firstWhere((d) => d.name.contains('Urza'));
        expect(clonedDeck.name, equals('Urza Lord High Artificer Combo (Copy)'));
        expect(clonedDeck.isCloned, isTrue);
        expect(clonedDeck.isAssembled, isFalse);

        // Verify cloned deck card rendered with Draft badge in UI
        expect(find.byKey(Key('deck_item_${clonedDeck.id}')), findsOneWidget);
        final statusBadge = find.byKey(Key('deck_assembly_status_${clonedDeck.id}'));
        expect(statusBadge, findsOneWidget);
        expect(
          find.descendant(of: statusBadge, matching: find.text('Draft')),
          findsOneWidget,
        );

        // 9. Select deck in press-and-hold mode
        await tester.longPress(find.byKey(Key('deck_item_${clonedDeck.id}')));
        await tester.pumpAndSettle();

        // Verify selection footer appeared
        expect(find.byKey(const Key('my_decks_selection_footer')), findsOneWidget);
        expect(find.text('1 selected'), findsOneWidget);

        // 10. Tap "Share to Explore"
        final shareBtn = find.byKey(const Key('selection_share_to_explore_button'));
        expect(shareBtn, findsOneWidget);
        await tester.tap(shareBtn);
        await tester.pumpAndSettle();

        expect(find.text('Deck "Urza Lord High Artificer Combo (Copy)" shared to Explore!'), findsOneWidget);
        expect(find.byKey(const Key('my_decks_selection_footer')), findsNothing);

        // 11. Switch to Explore Tab
        await tester.tap(find.byKey(const Key('decks_top_tab_explore')));
        await tester.pumpAndSettle();

        // 12. Tap Community pill
        await tester.tap(find.byKey(const Key('explore_pill_community')));
        await tester.pumpAndSettle();

        // 13. Verify shared deck in SQLite exploreDecks table
        final sharedDecks = await (db.select(db.exploreDecks)
              ..where((tbl) => tbl.sourceType.equals('user_shared')))
            .get();
        expect(sharedDecks.length, equals(1));
        final shared = sharedDecks.first;
        expect(shared.name, equals('Urza Lord High Artificer Combo (Copy)'));
        expect(shared.creatorName, equals('@CurrentUser'));
        expect(shared.sourceType, equals('user_shared'));

        // 14. Verify in Explore UI under Community pill
        expect(find.text('Urza Lord High Artificer Combo (Copy)'), findsWidgets);
        expect(find.text('@CurrentUser'), findsWidgets);
      },
    );

    // =========================================================================
    // 3. ADVERSARIAL EDGE CASES & RACE CONDITIONS
    // =========================================================================
    testWidgets(
      'Challenge 3.1: Malformed search strings and SQL injection attacks cause zero crashes or database corruption',
      (tester) async {
        setupLargeViewport(tester);
        ignoreImageErrors(tester);

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        final malformedQueries = [
          r"'; DROP TABLE explore_decks; --",
          r"' OR 1=1 --",
          r"[[[(((\**+??^${}",
          "<script>alert('xss')</script>",
          "   \t\n   ",
          "%%%___",
          "''''''''",
        ];

        // Test malformed queries on Tab 0 (My Decks)
        final myDecksSearch = find.byKey(const Key('my_decks_search_input'));
        for (final query in malformedQueries) {
          await tester.enterText(myDecksSearch, query);
          await tester.pumpAndSettle();
          // Clear query
          if (query.trim().isNotEmpty) {
            await tester.tap(find.byKey(const Key('my_decks_search_clear_button')));
            await tester.pumpAndSettle();
          }
        }

        // Switch to Tab 1 (Explore Decks)
        await tester.tap(find.byKey(const Key('decks_top_tab_explore')));
        await tester.pumpAndSettle();

        // Test malformed queries on Tab 1 (Explore Decks)
        final exploreSearch = find.byKey(const Key('explore_search_input'));
        for (final query in malformedQueries) {
          await tester.enterText(exploreSearch, query);
          await tester.pumpAndSettle();
          // Clear query
          if (query.trim().isNotEmpty) {
            await tester.tap(find.byKey(const Key('explore_search_clear_button')));
            await tester.pumpAndSettle();
          }
        }

        // Verify SQLite tables remain intact and accessible
        final exploreDeckCount = await exploreDao.getExploreDeckCount();
        expect(exploreDeckCount, greaterThan(0), reason: 'explore_decks table must not be corrupted or dropped');
        final personalDeckCount = (await db.select(db.decks).get()).length;
        expect(personalDeckCount, greaterThan(0), reason: 'decks table must not be corrupted or dropped');
      },
    );

    testWidgets(
      'Challenge 3.2: Unicode, Emoji, and Multilingual deck data survives clone and share lifecycle without encoding corruption',
      (tester) async {
        setupLargeViewport(tester);
        ignoreImageErrors(tester);

        const unicodeDeckId = 'unicode_explore_deck_1';
        const unicodeDeckName = '🐉 ドラゴン・ファイア (Nicol Bolas) 🔥';
        const unicodeCommander = 'ニコル・ボーラス (Nicol Bolas)';

        final now = DateTime.now();
        await db.into(db.exploreDecks).insert(
          ExploreDecksCompanion.insert(
            id: unicodeDeckId,
            name: unicodeDeckName,
            format: 'Commander',
            tcgDomain: const Value('mtg'),
            sourceType: const Value('community'),
            creatorName: const Value('@東京BrewMaster'),
            commanderName: const Value(unicodeCommander),
            colorIdentity: const Value('["U","B","R"]'),
            cardCount: const Value(100),
            estimatedPrice: const Value(250.0),
            createdAt: now,
            updatedAt: Value(now),
            isDeleted: const Value(false),
          ),
        );

        await db.into(db.exploreDeckItems).insert(
          ExploreDeckItemsCompanion.insert(
            id: 'unicode_item_1',
            exploreDeckId: unicodeDeckId,
            cardName: 'Nicol Bolas, the Ravager // ニコル・ボーラス',
            quantity: const Value(1),
            boardZone: const Value('Commander'),
            isCommander: const Value(true),
          ),
        );

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        // Clone unicode deck to personal
        final clonedPersonal = await exploreDao.cloneExploreDeckToPersonal(exploreDeckId: unicodeDeckId);
        expect(clonedPersonal.name, equals('$unicodeDeckName (Copy)'));

        // Share cloned deck back to explore
        final sharedBack = await exploreDao.sharePersonalDeckToExplore(
          personalDeckId: clonedPersonal.id,
          creatorName: '@CurrentUser',
        );

        expect(sharedBack.name, equals('$unicodeDeckName (Copy)'));
        expect(sharedBack.sourceType, equals('user_shared'));

        // Verify query matches Unicode substrings in SQLite
        final searchResult = await exploreDao.searchExploreDecks(query: 'ドラゴン');
        expect(searchResult.inDeckName.any((d) => d.name.contains('ドラゴン')), isTrue);
      },
    );

    testWidgets(
      'Challenge 3.3: Rapid double-tapping and concurrency race condition defense across clone, share, and vote',
      (tester) async {
        setupLargeViewport(tester);
        ignoreImageErrors(tester);

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        // 1. Rapid double-tap on Upvote button
        await tester.tap(find.byKey(const Key('decks_top_tab_explore')));
        await tester.pumpAndSettle();

        final upvoteFinder = find.byKey(const Key('explore_upvote_$testExploreDeckId')).first;
        // Fast successive double-tap (vote 1 -> toggle to 0)
        await tester.tap(upvoteFinder);
        await tester.tap(upvoteFinder);
        await tester.pumpAndSettle();

        // Net vote must be 0 (toggled off)
        final voteState = await (db.select(db.exploreDeckVotes)
              ..where((tbl) => tbl.exploreDeckId.equals(testExploreDeckId)))
            .getSingleOrNull();
        expect(voteState?.vote, equals(0));

        // 2. Rapid double-tap on Clone button in ReadOnlyDeckScreen
        await tester.tap(find.byKey(const Key('explore_card_$testExploreDeckId')).first);
        await tester.pumpAndSettle();

        final cloneBtn = find.byKey(const Key('explore_clone_deck_button'));
        // Rapid fire taps
        await tester.tap(cloneBtn, warnIfMissed: false);
        await tester.tap(cloneBtn, warnIfMissed: false);
        await tester.tap(cloneBtn, warnIfMissed: false);
        await tester.pumpAndSettle();

        // Verify exactly 1 cloned deck exists for this source
        final clones = await (db.select(db.decks)
              ..where((tbl) => tbl.sourceExploreDeckId.equals(testExploreDeckId)))
            .get();
        expect(clones.length, equals(1), reason: 'Concurrent taps must not spawn multiple cloned decks');

        // 3. Rapid double-tap on Share button
        final clonedDeckId = clones.first.id;
        // Trigger share twice concurrently
        final future1 = exploreDao.sharePersonalDeckToExplore(personalDeckId: clonedDeckId);
        final future2 = exploreDao.sharePersonalDeckToExplore(personalDeckId: clonedDeckId);
        await Future.wait([future1, future2]);

        final sharedRows = await (db.select(db.exploreDecks)
              ..where((tbl) => tbl.id.equals('explore_shared_$clonedDeckId')))
            .get();
        expect(sharedRows.length, equals(1), reason: 'Idempotent upsert must guarantee exactly 1 shared explore deck');
      },
    );
  });
}
