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
  late DateTime baseTime;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    vaultDao = VaultDao(db);
    exploreDao = ExploreDeckDao(db);
    baseTime = DateTime(2026, 10, 6, 12, 0, 0);

    // 1. Deck matching Deck Name ONLY for "Dragon"
    await db.into(db.exploreDecks).insert(
      ExploreDecksCompanion.insert(
        id: 'deck_dragon_name_only',
        name: 'Dragon Tempest',
        format: 'Commander',
        tcgDomain: const Value('mtg'),
        sourceType: const Value('official'),
        creatorName: const Value('Official WotC'),
        commanderName: const Value('Sarkhan, the Dragonspeaker'),
        colorIdentity: const Value('["R"]'),
        cardCount: const Value(100),
        estimatedPrice: const Value(120.0),
        upvotes: const Value(40),
        score: const Value(40),
        createdAt: baseTime.subtract(const Duration(days: 5)),
        updatedAt: Value(baseTime),
        isDeleted: const Value(false),
      ),
    );
    await db.into(db.exploreDeckItems).insert(
      ExploreDeckItemsCompanion.insert(
        id: 'item_tempest_1',
        exploreDeckId: 'deck_dragon_name_only',
        cardName: 'Mountain',
        boardZone: const Value('Mainboard'),
        quantity: const Value(30),
        isDeleted: const Value(false),
      ),
    );

    // 2. Deck matching Card Name ONLY for "Dragon" (deck name does NOT contain "Dragon")
    await db.into(db.exploreDecks).insert(
      ExploreDecksCompanion.insert(
        id: 'deck_dragon_card_only',
        name: 'Red Burn Aggro',
        format: 'Modern',
        tcgDomain: const Value('mtg'),
        sourceType: const Value('community'),
        creatorName: const Value('@GoblinKing'),
        commanderName: const Value('Krenko, Mob Boss'),
        colorIdentity: const Value('["R"]'),
        cardCount: const Value(60),
        estimatedPrice: const Value(45.0),
        upvotes: const Value(15),
        score: const Value(15),
        createdAt: baseTime.subtract(const Duration(days: 3)),
        updatedAt: Value(baseTime),
        isDeleted: const Value(false),
      ),
    );
    await db.into(db.exploreDeckItems).insert(
      ExploreDeckItemsCompanion.insert(
        id: 'item_fodder_1',
        exploreDeckId: 'deck_dragon_card_only',
        cardName: 'Dragon Fodder',
        boardZone: const Value('Mainboard'),
        quantity: const Value(4),
        isDeleted: const Value(false),
      ),
    );
    await db.into(db.exploreDeckItems).insert(
      ExploreDeckItemsCompanion.insert(
        id: 'item_bolt_1',
        exploreDeckId: 'deck_dragon_card_only',
        cardName: 'Lightning Bolt',
        boardZone: const Value('Mainboard'),
        quantity: const Value(4),
        isDeleted: const Value(false),
      ),
    );

    // 3. Deck matching BOTH Deck Name AND Card Name for "Dragon" (Deduplication test subject)
    await db.into(db.exploreDecks).insert(
      ExploreDecksCompanion.insert(
        id: 'deck_dragon_both',
        name: 'Dragonstorm Combo',
        format: 'Modern',
        tcgDomain: const Value('mtg'),
        sourceType: const Value('community'),
        creatorName: const Value('@StormBrewer'),
        commanderName: const Value('Niv-Mizzet, Parun'),
        colorIdentity: const Value('["U", "R"]'),
        cardCount: const Value(60),
        estimatedPrice: const Value(250.0),
        upvotes: const Value(80),
        score: const Value(80),
        createdAt: baseTime.subtract(const Duration(days: 2)),
        updatedAt: Value(baseTime),
        isDeleted: const Value(false),
      ),
    );
    await db.into(db.exploreDeckItems).insert(
      ExploreDeckItemsCompanion.insert(
        id: 'item_drc_1',
        exploreDeckId: 'deck_dragon_both',
        cardName: "Dragon's Rage Channeler",
        boardZone: const Value('Mainboard'),
        quantity: const Value(4),
        isDeleted: const Value(false),
      ),
    );

    // 4. Deck matching Creator Username ONLY for "Dragon"
    await db.into(db.exploreDecks).insert(
      ExploreDecksCompanion.insert(
        id: 'deck_dragon_creator_only',
        name: 'Mono Blue Delver',
        format: 'Legacy',
        tcgDomain: const Value('mtg'),
        sourceType: const Value('community'),
        creatorName: const Value('@DragonMaster'),
        commanderName: const Value('Murktide Regent'),
        colorIdentity: const Value('["U"]'),
        cardCount: const Value(60),
        estimatedPrice: const Value(85.0),
        upvotes: const Value(25),
        score: const Value(25),
        createdAt: baseTime.subtract(const Duration(days: 4)),
        updatedAt: Value(baseTime),
        isDeleted: const Value(false),
      ),
    );
    await db.into(db.exploreDeckItems).insert(
      ExploreDeckItemsCompanion.insert(
        id: 'item_delver_1',
        exploreDeckId: 'deck_dragon_creator_only',
        cardName: 'Delver of Secrets',
        boardZone: const Value('Mainboard'),
        quantity: const Value(4),
        isDeleted: const Value(false),
      ),
    );

    // 5. Deck with lowest alphabetical name and lowest price
    await db.into(db.exploreDecks).insert(
      ExploreDecksCompanion.insert(
        id: 'deck_alpha_first',
        name: 'Aether Revolt Artifacts',
        format: 'Standard',
        tcgDomain: const Value('mtg'),
        sourceType: const Value('community'),
        creatorName: const Value('@Artisan'),
        commanderName: const Value('Karn, Scion of Urza'),
        colorIdentity: const Value('[]'),
        cardCount: const Value(60),
        estimatedPrice: const Value(10.0),
        upvotes: const Value(5),
        score: const Value(5),
        createdAt: baseTime.subtract(const Duration(days: 10)),
        updatedAt: Value(baseTime),
        isDeleted: const Value(false),
      ),
    );
    await db.into(db.exploreDeckItems).insert(
      ExploreDeckItemsCompanion.insert(
        id: 'item_ornithopter_1',
        exploreDeckId: 'deck_alpha_first',
        cardName: 'Ornithopter',
        boardZone: const Value('Mainboard'),
        quantity: const Value(4),
        isDeleted: const Value(false),
      ),
    );

    // 6. Deck with highest alphabetical name, highest price, highest score, most recent
    await db.into(db.exploreDecks).insert(
      ExploreDecksCompanion.insert(
        id: 'deck_alpha_last',
        name: 'Zur the Enchanter Stax',
        format: 'Commander',
        tcgDomain: const Value('mtg'),
        sourceType: const Value('community'),
        creatorName: const Value('@ZirdaFan'),
        commanderName: const Value('Zur the Enchanter'),
        colorIdentity: const Value('["W", "U", "B"]'),
        cardCount: const Value(100),
        estimatedPrice: const Value(500.0),
        upvotes: const Value(100),
        score: const Value(100),
        createdAt: baseTime,
        updatedAt: Value(baseTime),
        isDeleted: const Value(false),
      ),
    );

    // 7. Deck with boundary special characters in Name, Creator, and Cards
    await db.into(db.exploreDecks).insert(
      ExploreDecksCompanion.insert(
        id: 'deck_special_chars',
        name: 'O\'Connor\'s "Wild" Deck %_100% 🐉',
        format: 'Commander',
        tcgDomain: const Value('mtg'),
        sourceType: const Value('community'),
        creatorName: const Value('@D\'Artagnan_100% 🔥'),
        commanderName: const Value('Gaea\'s Herald'),
        colorIdentity: const Value('["G"]'),
        cardCount: const Value(100),
        estimatedPrice: const Value(75.0),
        upvotes: const Value(30),
        score: const Value(30),
        createdAt: baseTime.subtract(const Duration(days: 1)),
        updatedAt: Value(baseTime),
        isDeleted: const Value(false),
      ),
    );
    await db.into(db.exploreDeckItems).insert(
      ExploreDeckItemsCompanion.insert(
        id: 'item_special_gaea',
        exploreDeckId: 'deck_special_chars',
        cardName: 'Gaea\'s Cradle',
        boardZone: const Value('Mainboard'),
        quantity: const Value(1),
        isDeleted: const Value(false),
      ),
    );
    await db.into(db.exploreDeckItems).insert(
      ExploreDeckItemsCompanion.insert(
        id: 'item_special_juergen',
        exploreDeckId: 'deck_special_chars',
        cardName: 'Jürgen\'s Familiar ✨',
        boardZone: const Value('Mainboard'),
        quantity: const Value(1),
        isDeleted: const Value(false),
      ),
    );

    // 8. Tie-breaker deck A
    await db.into(db.exploreDecks).insert(
      ExploreDecksCompanion.insert(
        id: 'deck_tie_alpha',
        name: 'Tie Breaker Alpha',
        format: 'Commander',
        tcgDomain: const Value('mtg'),
        sourceType: const Value('community'),
        creatorName: const Value('@TieAlpha'),
        cardCount: const Value(100),
        estimatedPrice: const Value(99.0),
        upvotes: const Value(50),
        score: const Value(50),
        createdAt: baseTime.subtract(const Duration(days: 7)),
        updatedAt: Value(baseTime),
        isDeleted: const Value(false),
      ),
    );

    // 9. Tie-breaker deck B (same score, higher upvotes)
    await db.into(db.exploreDecks).insert(
      ExploreDecksCompanion.insert(
        id: 'deck_tie_beta',
        name: 'Tie Breaker Beta',
        format: 'Commander',
        tcgDomain: const Value('mtg'),
        sourceType: const Value('community'),
        creatorName: const Value('@TieBeta'),
        cardCount: const Value(100),
        estimatedPrice: const Value(99.0),
        upvotes: const Value(60),
        score: const Value(50),
        createdAt: baseTime.subtract(const Duration(days: 6)),
        updatedAt: Value(baseTime),
        isDeleted: const Value(false),
      ),
    );
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

  // ===========================================================================
  // GROUP 1: MULTI-TIER CONTEXTUAL SEARCH CATEGORIZATION & PARTITIONING
  // ===========================================================================
  group('1. Multi-Tier Contextual Search Categorization & Partitioning Invariants', () {
    testWidgets('1.1 Dual-tier partitioning: query matching both deck name and card name partitions items with subtitle "contains: [Card Name]"',
        (tester) async {
      // Direct DAO empirical validation
      final results = await exploreDao.searchExploreDecks(query: 'Dragon');

      // Tier 1 contains decks with "Dragon" in name
      final tier1Names = results.inDeckName.map((d) => d.name).toList();
      expect(tier1Names, contains('Dragon Tempest'));
      expect(tier1Names, contains('Dragonstorm Combo'));
      expect(tier1Names, isNot(contains('Red Burn Aggro')));

      // Tier 2 contains decks matching "Dragon" via cards
      final tier2DeckNames = results.inDeckCards.map((m) => m.deckWithVote.name).toList();
      expect(tier2DeckNames, contains('Red Burn Aggro'));
      final fodderMatch = results.inDeckCards.firstWhere((m) => m.deckWithVote.name == 'Red Burn Aggro');
      expect(fodderMatch.matchingCardName, 'Dragon Fodder');

      // UI Widget Level Verification
      await tester.pumpWidget(createSubject(initialTopTab: 1));
      await tester.pumpAndSettle();

      // Enter search query "Dragon"
      await tester.enterText(find.byKey(const Key('explore_search_input')), 'Dragon');
      await tester.pumpAndSettle();

      // Both section headers are displayed
      expect(find.byKey(const Key('explore_search_group_name')), findsOneWidget);
      expect(find.byKey(const Key('explore_search_group_cards')), findsOneWidget);

      // Section titles
      expect(find.text('in Deck Name'), findsOneWidget);
      expect(find.text('in Deck Cards'), findsOneWidget);

      // Decks rendered in their respective tiers
      expect(find.text('Dragon Tempest'), findsOneWidget);
      expect(find.text('Dragonstorm Combo'), findsOneWidget);
      expect(find.text('Red Burn Aggro'), findsOneWidget);

      // Subtitle "contains: Dragon Fodder" is strictly rendered
      expect(find.text('contains: Dragon Fodder'), findsOneWidget);
    });

    testWidgets('1.2 Deduplication invariant: deck matching BOTH name and card name is strictly in Tier 1 and NEVER duplicated in Tier 2',
        (tester) async {
      // "Dragonstorm Combo" has "Dragon" in name AND has card "Dragon's Rage Channeler"
      final results = await exploreDao.searchExploreDecks(query: 'Dragon');

      final tier1Ids = results.inDeckName.map((d) => d.id).toSet();
      final tier2Ids = results.inDeckCards.map((m) => m.deckWithVote.id).toSet();

      // Deck MUST be in Tier 1
      expect(tier1Ids.contains('deck_dragon_both'), isTrue);

      // Deck MUST NOT be in Tier 2 (Deduplication invariant)
      expect(tier2Ids.contains('deck_dragon_both'), isFalse,
          reason: 'A deck matching Tier 1 must NOT be duplicated under Tier 2');

      // Intersection between Tier 1 and Tier 2 must be strictly empty
      final intersection = tier1Ids.intersection(tier2Ids);
      expect(intersection, isEmpty,
          reason: 'Tier 1 and Tier 2 must be strictly mutually exclusive');

      // UI verification: Card for "Dragonstorm Combo" rendered exactly once
      await tester.pumpWidget(createSubject(initialTopTab: 1));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('explore_search_input')), 'Dragonstorm');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('explore_card_deck_dragon_both')), findsOneWidget);
      expect(find.byKey(const Key('explore_search_group_name')), findsOneWidget);
      expect(find.byKey(const Key('explore_search_group_cards')), findsNothing);
    });

    testWidgets('1.3 Triple-tier partitioning: renders all 3 headers ("in Deck Name", "in Deck Cards", "by Username") with visual dividers',
        (tester) async {
      final results = await exploreDao.searchExploreDecks(query: 'Dragon');

      expect(results.inDeckName, isNotEmpty);
      expect(results.inDeckCards, isNotEmpty);
      expect(results.byUsername, isNotEmpty);

      // Tier 3 contains "@DragonMaster"
      final tier3Usernames = results.byUsername.map((d) => d.creatorName).toList();
      expect(tier3Usernames, contains('@DragonMaster'));

      await tester.pumpWidget(createSubject(initialTopTab: 1));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('explore_search_input')), 'Dragon');
      await tester.pumpAndSettle();

      // Verify all 3 section headers are rendered
      expect(find.byKey(const Key('explore_search_group_name')), findsOneWidget);
      expect(find.byKey(const Key('explore_search_group_cards')), findsOneWidget);
      expect(find.byKey(const Key('explore_search_group_creator')), findsOneWidget);

      // Exactly 2 dividers between the 3 sections
      expect(find.byType(Divider), findsNWidgets(2));
    });

    testWidgets('1.4 Creator tier deduplication invariant: deck matching Tier 1 or Tier 2 is excluded from Tier 3 ("by Username")',
        (tester) async {
      // Insert a deck whose name contains "Storm" AND whose creator is "@StormBrewer"
      // (deck_dragon_both has name "Dragonstorm Combo" and creator "@StormBrewer")
      final results = await exploreDao.searchExploreDecks(query: 'Storm');

      final tier1Ids = results.inDeckName.map((d) => d.id).toSet();
      final tier2Ids = results.inDeckCards.map((m) => m.deckWithVote.id).toSet();
      final tier3Ids = results.byUsername.map((d) => d.id).toSet();

      // It matches Tier 1 because "Dragonstorm" contains "Storm"
      expect(tier1Ids.contains('deck_dragon_both'), isTrue);

      // Deduplication: It MUST NOT appear in Tier 3 even though creator is "@StormBrewer"
      expect(tier3Ids.contains('deck_dragon_both'), isFalse,
          reason: 'Deck already matching Tier 1 must NOT duplicate into Tier 3');

      // The union of pairwise intersections must be empty
      expect(tier1Ids.intersection(tier3Ids), isEmpty);
      expect(tier2Ids.intersection(tier3Ids), isEmpty);
    });

    testWidgets('1.5 Case-insensitivity across tiers: mixed-case queries match identical result sets',
        (tester) async {
      final lower = await exploreDao.searchExploreDecks(query: 'dragon');
      final upper = await exploreDao.searchExploreDecks(query: 'DRAGON');
      final mixed = await exploreDao.searchExploreDecks(query: 'dRaGoN');

      expect(lower.inDeckName.length, upper.inDeckName.length);
      expect(lower.inDeckName.length, mixed.inDeckName.length);

      expect(lower.inDeckCards.length, upper.inDeckCards.length);
      expect(lower.inDeckCards.length, mixed.inDeckCards.length);

      expect(lower.byUsername.length, upper.byUsername.length);
      expect(lower.byUsername.length, mixed.byUsername.length);

      expect(lower.inDeckName.map((d) => d.id).toSet(),
          mixed.inDeckName.map((d) => d.id).toSet());
    });
  });

  // ===========================================================================
  // GROUP 2: BOUNDARY SEARCH INPUTS, SQL WILDCARDS, SPECIAL CHARACTERS & EMPTY STATES
  // ===========================================================================
  group('2. Boundary Search Inputs, SQL Wildcards, Special Characters & Empty States', () {
    testWidgets('2.1 SQLite LIKE wildcards (% and _) execute cleanly without SQL errors or crashes',
        (tester) async {
      // '%' wildcard
      final percentResults = await exploreDao.searchExploreDecks(query: '%');
      expect(percentResults, isNotNull);
      expect(tester.takeException(), isNull);

      // '_' wildcard
      final underscoreResults = await exploreDao.searchExploreDecks(query: '_');
      expect(underscoreResults, isNotNull);
      expect(tester.takeException(), isNull);

      // Test in UI with '%'
      await tester.pumpWidget(createSubject(initialTopTab: 1));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('explore_search_input')), '%');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Test in UI with '_'
      await tester.enterText(find.byKey(const Key('explore_search_input')), '_');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('2.2 Quotes and SQL injection patterns execute safely without corruption or unhandled errors',
        (tester) async {
      final injectionQueries = [
        "'",
        '"',
        "''",
        '""',
        "O'Connor",
        "'; DROP TABLE explore_decks; --",
        "/* comment */",
        r"\' OR 1=1 --",
      ];

      for (final query in injectionQueries) {
        final res = await exploreDao.searchExploreDecks(query: query);
        expect(res, isNotNull);
        expect(tester.takeException(), isNull);
      }

      // Verify "O'Connor" matches the deck with apostrophe
      final oconnorResults = await exploreDao.searchExploreDecks(query: "O'Connor");
      expect(oconnorResults.inDeckName, hasLength(1));
      expect(oconnorResults.inDeckName.first.id, 'deck_special_chars');

      // Verify "Gaea's" matches card name in Tier 2
      final gaeaResults = await exploreDao.searchExploreDecks(query: "Gaea's");
      expect(gaeaResults.inDeckCards, hasLength(1));
      expect(gaeaResults.inDeckCards.first.matchingCardName, "Gaea's Cradle");

      // Verify database table was NOT dropped by injection attempt!
      final count = await exploreDao.getExploreDeckCount();
      expect(count, greaterThanOrEqualTo(8));
    });

    testWidgets('2.3 Unicode, accents, and emojis execute cleanly and match accurately',
        (tester) async {
      // Emoji in name: 🐉
      final dragonEmoji = await exploreDao.searchExploreDecks(query: '🐉');
      expect(dragonEmoji.inDeckName, hasLength(1));
      expect(dragonEmoji.inDeckName.first.id, 'deck_special_chars');

      // Emoji in creator: 🔥
      final fireEmoji = await exploreDao.searchExploreDecks(query: '🔥');
      expect(fireEmoji.byUsername, hasLength(1));
      expect(fireEmoji.byUsername.first.id, 'deck_special_chars');

      // Accented name in card: "Jürgen"
      final juergenResults = await exploreDao.searchExploreDecks(query: 'Jürgen');
      expect(juergenResults.inDeckCards, hasLength(1));
      expect(juergenResults.inDeckCards.first.matchingCardName, 'Jürgen\'s Familiar ✨');

      // Emoji in card: ✨
      final sparkleResults = await exploreDao.searchExploreDecks(query: '✨');
      expect(sparkleResults.inDeckCards, hasLength(1));
      expect(sparkleResults.inDeckCards.first.matchingCardName, 'Jürgen\'s Familiar ✨');
    });

    testWidgets('2.4 Empty string and whitespace-only queries retain discovery feed mode',
        (tester) async {
      // Empty query via DAO returns empty result object
      final emptyResult = await exploreDao.searchExploreDecks(query: '');
      expect(emptyResult.isEmpty, isTrue);

      final whitespaceResult = await exploreDao.searchExploreDecks(query: '     ');
      expect(whitespaceResult.isEmpty, isTrue);

      // UI behavior: Discovery feed carousels remain mounted
      await tester.pumpWidget(createSubject(initialTopTab: 1));
      await tester.pumpAndSettle();

      // In discovery feed mode, carousels are present
      expect(find.byKey(const Key('explore_carousel_suggested_commanders')), findsOneWidget);

      // Type whitespace
      await tester.enterText(find.byKey(const Key('explore_search_input')), '     ');
      await tester.pumpAndSettle();

      // Still in discovery feed mode because trimmed query is empty!
      expect(find.byKey(const Key('explore_carousel_suggested_commanders')), findsOneWidget);
      expect(find.byKey(const Key('explore_search_group_name')), findsNothing);
    });

    testWidgets('2.5 Non-existent decks render friendly empty state with icon and search term',
        (tester) async {
      await tester.pumpWidget(createSubject(initialTopTab: 1));
      await tester.pumpAndSettle();

      const nonExistent = 'ZzXyQwNonExistent123';
      await tester.enterText(find.byKey(const Key('explore_search_input')), nonExistent);
      await tester.pumpAndSettle();

      // Header icon
      expect(find.byIcon(Icons.search_off_rounded), findsOneWidget);
      // Empty state title
      expect(find.text('No decks found'), findsOneWidget);
      // Informative subtitle containing the exact query
      expect(find.text('No explore decks match "$nonExistent".'), findsOneWidget);
    });

    testWidgets('2.6 Rapid typing burst simulation across frames executes without unhandled exceptions',
        (tester) async {
      await tester.pumpWidget(createSubject(initialTopTab: 1));
      await tester.pumpAndSettle();

      final searchField = find.byKey(const Key('explore_search_input'));

      // Simulate rapid user keystrokes with partial pumps
      final typingSequence = ['D', 'Dr', 'Dra', 'Drag', 'Dragon', 'Drago', 'Drag', 'Dr', ''];
      for (final stroke in typingSequence) {
        await tester.enterText(searchField, stroke);
        await tester.pump(const Duration(milliseconds: 16)); // Single frame pump
      }

      // Settle all pending asynchronous riverpod notifications
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Returned to empty string -> discovery feed mode restored
      expect(find.byKey(const Key('explore_carousel_suggested_commanders')), findsOneWidget);
    });
  });

  // ===========================================================================
  // GROUP 3: EMBEDDED SORT MENU RAPID SWITCHING & STRICT MATHEMATICAL ORDERING
  // ===========================================================================
  group('3. Embedded Sort Menu Rapid Switching & Algorithm Correctness', () {
    testWidgets('3.1 Strict mathematical ordering validation across all 5 sort options',
        (tester) async {
      // 1. Popularity: score DESC, upvotes DESC, createdAt DESC
      final popularList = await exploreDao.watchExploreDecks(
        sort: ExploreSortOption.popularity,
      ).first;
      for (var i = 0; i < popularList.length - 1; i++) {
        final current = popularList[i];
        final next = popularList[i + 1];
        expect(current.score >= next.score, isTrue,
            reason: 'Popularity sort violation at index $i: ${current.score} < ${next.score}');
        if (current.score == next.score) {
          expect(current.deck.upvotes >= next.deck.upvotes, isTrue,
              reason: 'Tie-break upvotes violation at index $i');
        }
      }
      expect(popularList.first.id, 'deck_alpha_last'); // Score: 100

      // 2. Recently Added: createdAt DESC, score DESC
      final recentList = await exploreDao.watchExploreDecks(
        sort: ExploreSortOption.recentlyAdded,
      ).first;
      for (var i = 0; i < recentList.length - 1; i++) {
        final current = recentList[i];
        final next = recentList[i + 1];
        expect(
          current.deck.createdAt.isAfter(next.deck.createdAt) ||
              current.deck.createdAt.isAtSameMomentAs(next.deck.createdAt),
          isTrue,
          reason: 'Recently added sort violation at index $i',
        );
      }
      expect(recentList.first.id, 'deck_alpha_last'); // Created at baseTime

      // 3. Price Low to High: estimatedPrice ASC, score DESC
      final priceAscList = await exploreDao.watchExploreDecks(
        sort: ExploreSortOption.priceLowToHigh,
      ).first;
      for (var i = 0; i < priceAscList.length - 1; i++) {
        final current = priceAscList[i];
        final next = priceAscList[i + 1];
        expect(current.estimatedPrice <= next.estimatedPrice, isTrue,
            reason: 'Price low-to-high violation at index $i: ${current.estimatedPrice} > ${next.estimatedPrice}');
      }
      expect(priceAscList.first.id, 'deck_alpha_first'); // $10.0
      expect(priceAscList.last.id, 'deck_alpha_last'); // $500.0

      // 4. Price High to Low: estimatedPrice DESC, score DESC
      final priceDescList = await exploreDao.watchExploreDecks(
        sort: ExploreSortOption.priceHighToLow,
      ).first;
      for (var i = 0; i < priceDescList.length - 1; i++) {
        final current = priceDescList[i];
        final next = priceDescList[i + 1];
        expect(current.estimatedPrice >= next.estimatedPrice, isTrue,
            reason: 'Price high-to-low violation at index $i: ${current.estimatedPrice} < ${next.estimatedPrice}');
      }
      expect(priceDescList.first.id, 'deck_alpha_last'); // $500.0
      expect(priceDescList.last.id, 'deck_alpha_first'); // $10.0

      // 5. Alphabetical: name COLLATE NOCASE ASC
      final alphaList = await exploreDao.watchExploreDecks(
        sort: ExploreSortOption.alphabetical,
      ).first;
      for (var i = 0; i < alphaList.length - 1; i++) {
        final current = alphaList[i].name.toLowerCase();
        final next = alphaList[i + 1].name.toLowerCase();
        expect(current.compareTo(next) <= 0, isTrue,
            reason: 'Alphabetical sort violation at index $i: "$current" > "$next"');
      }
      expect(alphaList.first.id, 'deck_alpha_first'); // 'Aether Revolt Artifacts'
      expect(alphaList.last.id, 'deck_alpha_last'); // 'Zur the Enchanter Stax'
    });

    testWidgets('3.2 Rapid sort switching stress: cycling 20 times between all sort options without state race conditions',
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
        createSubject(container: container),
      );
      await tester.pumpAndSettle();

      final options = [
        ExploreSortOption.popularity,
        ExploreSortOption.recentlyAdded,
        ExploreSortOption.priceLowToHigh,
        ExploreSortOption.priceHighToLow,
        ExploreSortOption.alphabetical,
      ];

      // Rapidly update the sort state 20 times
      for (var i = 0; i < 20; i++) {
        final targetOption = options[i % options.length];
        container.read(activeExploreSortOptionProvider.notifier).state = targetOption;
        await tester.pump(const Duration(milliseconds: 10));
      }

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Verify the final sort state matches the last emitted option
      final expectedFinalOption = options[19 % options.length];
      expect(container.read(activeExploreSortOptionProvider), expectedFinalOption);

      // Verify the feed renders properly after rapid switching
      final feedDecks = container.read(exploreDecksStreamProvider).value;
      expect(feedDecks, isNotNull);
      expect(feedDecks!.isNotEmpty, isTrue);
    });

    testWidgets('3.3 Concurrent multi-sort stream listeners maintain isolated sort orders simultaneously',
        (tester) async {
      // Subscribe to 2 concurrent streams with opposing sort options
      final streamAsc = exploreDao.watchExploreDecks(sort: ExploreSortOption.priceLowToHigh);
      final streamDesc = exploreDao.watchExploreDecks(sort: ExploreSortOption.priceHighToLow);

      final listAsc = await streamAsc.first;
      final listDesc = await streamDesc.first;

      expect(listAsc.first.estimatedPrice, lessThan(listDesc.first.estimatedPrice));
      expect(listAsc.first.id, 'deck_alpha_first');
      expect(listDesc.first.id, 'deck_alpha_last');
    });

    testWidgets('3.4 Sort popup menu UI interaction: all 5 options selectable and reactive',
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

      final sortButton = find.byKey(const Key('explore_search_sort_button'));

      // Cycle through selecting each option via the UI PopupMenuButton
      final sortActions = [
        ('explore_sort_recent', ExploreSortOption.recentlyAdded),
        ('explore_sort_price_asc', ExploreSortOption.priceLowToHigh),
        ('explore_sort_price_desc', ExploreSortOption.priceHighToLow),
        ('explore_sort_alpha', ExploreSortOption.alphabetical),
        ('explore_sort_popular', ExploreSortOption.popularity),
      ];

      for (final (keyString, expectedEnum) in sortActions) {
        await tester.tap(sortButton);
        await tester.pumpAndSettle();

        final menuItem = find.byKey(Key(keyString));
        expect(menuItem, findsOneWidget);
        await tester.tap(menuItem);
        await tester.pumpAndSettle();

        expect(container.read(activeExploreSortOptionProvider), expectedEnum);
      }
    });
  });

  // ===========================================================================
  // GROUP 4: CLEAR BUTTON INVARIANTS & DISCOVERY FEED RESTORATION
  // ===========================================================================
  group('4. Clear Button Invariants & Discovery Feed Restoration', () {
    testWidgets('4.1 Clear button visibility invariant: absent when query is empty, present when non-empty',
        (tester) async {
      await tester.pumpWidget(createSubject(initialTopTab: 1));
      await tester.pumpAndSettle();

      final clearFinder = find.byKey(const Key('explore_search_clear_button'));
      final inputFinder = find.byKey(const Key('explore_search_input'));

      // Initially empty -> Clear button is NOT present
      expect(clearFinder, findsNothing);

      // Enter text -> Clear button appears
      await tester.enterText(inputFinder, 'Urza');
      await tester.pumpAndSettle();
      expect(clearFinder, findsOneWidget);

      // Backspace to empty -> Clear button disappears
      await tester.enterText(inputFinder, '');
      await tester.pumpAndSettle();
      expect(clearFinder, findsNothing);
    });

    testWidgets('4.2 Immediate discovery feed restoration: tapping clear clears text and restores discovery carousels',
        (tester) async {
      await tester.pumpWidget(createSubject(initialTopTab: 1));
      await tester.pumpAndSettle();

      // Verify initially in discovery feed mode
      expect(find.byKey(const Key('explore_carousel_suggested_commanders')), findsOneWidget);

      // Enter search query -> transitions to search results view
      await tester.enterText(find.byKey(const Key('explore_search_input')), 'Dragon');
      await tester.pumpAndSettle();

      // Carousels are unmounted; search results view is mounted
      expect(find.byKey(const Key('explore_carousel_suggested_commanders')), findsNothing);
      expect(find.byKey(const Key('explore_search_group_name')), findsOneWidget);

      // Tap clear button
      final clearButton = find.byKey(const Key('explore_search_clear_button'));
      expect(clearButton, findsOneWidget);
      await tester.tap(clearButton);
      await tester.pumpAndSettle();

      // Clear button is gone
      expect(find.byKey(const Key('explore_search_clear_button')), findsNothing);

      // Text input field is empty
      final textField = tester.widget<TextField>(find.byKey(const Key('explore_search_input')));
      expect(textField.controller?.text, isEmpty);

      // Discovery feed carousels and 2-column grid are immediately restored
      expect(find.byKey(const Key('explore_carousel_suggested_commanders')), findsOneWidget);
      expect(find.byKey(const Key('explore_search_group_name')), findsNothing);
    });

    testWidgets('4.3 Repeated search-and-clear cycle stress: 5 consecutive cycles without state leakage',
        (tester) async {
      await tester.pumpWidget(createSubject(initialTopTab: 1));
      await tester.pumpAndSettle();

      final inputFinder = find.byKey(const Key('explore_search_input'));
      final clearFinder = find.byKey(const Key('explore_search_clear_button'));

      final searchWords = ['Dragon', 'Red', 'Combo', 'Zur', 'Aether'];

      for (final word in searchWords) {
        // 1. Enter query
        await tester.enterText(inputFinder, word);
        await tester.pumpAndSettle();
        expect(clearFinder, findsOneWidget);
        expect(find.byKey(const Key('explore_carousel_suggested_commanders')), findsNothing);

        // 2. Clear query
        await tester.tap(clearFinder);
        await tester.pumpAndSettle();
        expect(clearFinder, findsNothing);
        expect(find.byKey(const Key('explore_carousel_suggested_commanders')), findsOneWidget);
      }
    });
  });
}
