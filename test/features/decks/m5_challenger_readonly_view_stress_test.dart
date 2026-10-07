import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/decks/data/daos/explore_deck_dao.dart';
import 'package:countr/features/decks/presentation/providers/explore_deck_providers.dart';
import 'package:countr/features/decks/presentation/screens/read_only_deck_screen.dart';

/// Test double to precisely control async timing and inject faults into clone execution.
class ControllableExploreDeckDao extends ExploreDeckDao {
  ControllableExploreDeckDao(super.db);

  Completer<void>? cloneCompleter;
  bool shouldThrowOnClone = false;

  @override
  Future<Deck> cloneExploreDeckToPersonal({required String exploreDeckId}) async {
    if (shouldThrowOnClone) {
      throw Exception('Simulated SQLite disk I/O error');
    }
    if (cloneCompleter != null) {
      final result = await super.cloneExploreDeckToPersonal(exploreDeckId: exploreDeckId);
      await cloneCompleter!.future;
      return result;
    }
    return super.cloneExploreDeckToPersonal(exploreDeckId: exploreDeckId);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  late AppDatabase db;
  late VaultDao vaultDao;
  late ControllableExploreDeckDao exploreDao;

  const kTestDeckId = 'stress_test_explore_deck_1';
  const kTestDeckName = 'Niv-Mizzet Empirical Overload';

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    vaultDao = VaultDao(db);
    exploreDao = ControllableExploreDeckDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildTestApp({
    required Widget child,
    AppDatabase? customDb,
    ExploreDeckDao? customExploreDao,
  }) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(customDb ?? db),
        vaultDaoProvider.overrideWithValue(vaultDao),
        exploreDeckDaoProvider.overrideWithValue(customExploreDao ?? exploreDao),
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  Future<void> seedStandardDeck({
    String deckId = kTestDeckId,
    String name = kTestDeckName,
    String creator = 'Official WotC',
    String sourceType = 'official',
    int upvotes = 20,
    int downvotes = 5,
    int score = 15,
    String? commanderArtCrop = 'https://cards.scryfall.io/art_crop/test.jpg',
    String? commanderImageUrl = 'https://cards.scryfall.io/normal/test.jpg',
    String? description = 'Adversarial verification deck for milestone 5 testing.',
    List<String> colorIdentity = const ['U', 'R'],
  }) async {
    final now = DateTime.now();

    await db.into(db.exploreDecks).insert(
      ExploreDecksCompanion.insert(
        id: deckId,
        name: name,
        format: 'Commander',
        tcgDomain: const Value('mtg'),
        sourceType: Value(sourceType),
        creatorName: Value(creator),
        description: Value(description),
        commanderName: const Value('Niv-Mizzet, Parun'),
        commanderImageUrl: Value(commanderImageUrl),
        commanderArtCrop: Value(commanderArtCrop),
        colorIdentity: Value(jsonEncode(colorIdentity)),
        cardCount: const Value(100),
        estimatedPrice: const Value(185.75),
        upvotes: Value(upvotes),
        downvotes: Value(downvotes),
        score: Value(score),
        featuredCategory: const Value('Popular Standard'),
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: Value(now),
        isDeleted: const Value(false),
      ),
    );

    // Seed standard partitioned cards
    // 1. Commander
    await db.into(db.exploreDeckItems).insert(
      ExploreDeckItemsCompanion.insert(
        id: '${deckId}_cmd',
        exploreDeckId: deckId,
        cardName: 'Niv-Mizzet, Parun',
        manaCost: const Value('{U}{U}{U}{R}{R}{R}'),
        cmc: const Value(6.0),
        typeLine: const Value('Legendary Creature — Dragon Wizard'),
        quantity: const Value(1),
        boardZone: const Value('Commander'),
        isCommander: const Value(true),
        price: const Value(4.50),
      ),
    );

    // 2. Creature
    await db.into(db.exploreDeckItems).insert(
      ExploreDeckItemsCompanion.insert(
        id: '${deckId}_creature',
        exploreDeckId: deckId,
        cardName: 'Guttersnipe',
        manaCost: const Value('{2}{R}'),
        cmc: const Value(3.0),
        typeLine: const Value('Creature — Goblin Shaman'),
        quantity: const Value(2),
        boardZone: const Value('Mainboard'),
        isCommander: const Value(false),
        price: const Value(0.35),
      ),
    );

    // 3. Spell (Instant / Sorcery)
    await db.into(db.exploreDeckItems).insert(
      ExploreDeckItemsCompanion.insert(
        id: '${deckId}_spell',
        exploreDeckId: deckId,
        cardName: 'Opt',
        manaCost: const Value('{U}'),
        cmc: const Value(1.0),
        typeLine: const Value('Instant'),
        quantity: const Value(4),
        boardZone: const Value('Mainboard'),
        isCommander: const Value(false),
        price: const Value(0.25),
      ),
    );

    // 4. Permanent (Artifact / Enchantment)
    await db.into(db.exploreDeckItems).insert(
      ExploreDeckItemsCompanion.insert(
        id: '${deckId}_artifact',
        exploreDeckId: deckId,
        cardName: 'Arcane Signet',
        manaCost: const Value('{2}'),
        cmc: const Value(2.0),
        typeLine: const Value('Artifact'),
        quantity: const Value(1),
        boardZone: const Value('Mainboard'),
        isCommander: const Value(false),
        price: const Value(1.10),
      ),
    );

    // 5. Land
    await db.into(db.exploreDeckItems).insert(
      ExploreDeckItemsCompanion.insert(
        id: '${deckId}_land',
        exploreDeckId: deckId,
        cardName: 'Steam Vents',
        manaCost: const Value(''),
        cmc: const Value(0.0),
        typeLine: const Value('Land — Island Mountain'),
        quantity: const Value(1),
        boardZone: const Value('Mainboard'),
        isCommander: const Value(false),
        price: const Value(14.00),
      ),
    );

    // 6. Sideboard
    await db.into(db.exploreDeckItems).insert(
      ExploreDeckItemsCompanion.insert(
        id: '${deckId}_sideboard',
        exploreDeckId: deckId,
        cardName: 'Counterspell',
        manaCost: const Value('{U}{U}'),
        cmc: const Value(2.0),
        typeLine: const Value('Instant'),
        quantity: const Value(1),
        boardZone: const Value('Sideboard'),
        isCommander: const Value(false),
        price: const Value(1.75),
      ),
    );
  }

  // ===========================================================================
  // GROUP 1: RAPID CLONE BUTTON DEBOUNCING & CONCURRENCY RESILIENCE
  // ===========================================================================
  group('CHALLENGER GROUP 1: Rapid Clone Button Debouncing & Concurrency Resilience', () {
    testWidgets('1.1 Furious 10x rapid tapping on clone button creates exactly 1 cloned deck and version',
        (tester) async {
      await seedStandardDeck();

      await tester.pumpWidget(
        buildTestApp(
          child: ReadOnlyDeckScreen(exploreDeckId: kTestDeckId),
        ),
      );
      await tester.pumpAndSettle();

      final cloneBtnFinder = find.byKey(const Key('explore_clone_deck_button'));
      expect(cloneBtnFinder, findsOneWidget);

      // Simulate a user furiously tapping the clone button 10 times consecutively
      for (int i = 0; i < 10; i++) {
        await tester.tap(cloneBtnFinder, warnIfMissed: false);
      }
      await tester.pumpAndSettle();

      // Exactly 1 cloned deck created in SQLite
      final allClonedDecks = await (db.select(db.decks)
            ..where((t) => t.sourceExploreDeckId.equals(kTestDeckId)))
          .get();
      expect(allClonedDecks.length, equals(1),
          reason: 'Furious tapping must NOT produce duplicate cloned decks');

      final clonedDeck = allClonedDecks.first;
      expect(clonedDeck.name, equals('$kTestDeckName (Copy)'));
      expect(clonedDeck.isCloned, isTrue);

      // Exactly 1 deck version created
      final versions = await (db.select(db.deckVersions)
            ..where((t) => t.deckId.equals(clonedDeck.id)))
          .get();
      expect(versions.length, equals(1),
          reason: 'Furious tapping must NOT create redundant deck versions');

      // Cloned items match source items exactly (6 items)
      final items = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals(versions.first.id)))
          .get();
      expect(items.length, equals(6));

      // Exactly 1 SnackBar is displayed
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Cloned "$kTestDeckName" to My Decks!'), findsOneWidget);
    });

    testWidgets('1.2 In-flight clone operation disables button and displays progress indicator',
        (tester) async {
      await seedStandardDeck();

      final completer = Completer<void>();
      exploreDao.cloneCompleter = completer;

      await tester.pumpWidget(
        buildTestApp(
          child: ReadOnlyDeckScreen(exploreDeckId: kTestDeckId),
        ),
      );
      await tester.pumpAndSettle();

      final cloneBtnFinder = find.byKey(const Key('explore_clone_deck_button'));
      expect(cloneBtnFinder, findsOneWidget);
      expect(find.text('Add to My Decks'), findsOneWidget);

      // Tap once to initiate async clone
      await tester.tap(cloneBtnFinder);
      await tester.pump(); // Advance 1 frame to trigger setState(_isCloning = true)

      // Button must show in-flight state
      expect(find.text('Cloning Deck...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Attempting to tap again while in flight should be a no-op
      await tester.tap(cloneBtnFinder, warnIfMissed: false);
      await tester.pump();

      // Complete async clone
      completer.complete();
      await tester.pumpAndSettle();

      // Button returns to normal state with SnackBar feedback
      expect(find.text('Add to My Decks'), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('1.3 Database failure during clone resets in-flight state and presents error SnackBar',
        (tester) async {
      await seedStandardDeck();

      exploreDao.shouldThrowOnClone = true;

      await tester.pumpWidget(
        buildTestApp(
          child: ReadOnlyDeckScreen(exploreDeckId: kTestDeckId),
        ),
      );
      await tester.pumpAndSettle();

      final cloneBtnFinder = find.byKey(const Key('explore_clone_deck_button'));
      await tester.tap(cloneBtnFinder);
      await tester.pumpAndSettle();

      // Error SnackBar displayed
      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        find.textContaining('Failed to clone deck: Exception: Simulated SQLite disk I/O error'),
        findsOneWidget,
      );

      // Button reverts from _isCloning and becomes re-enabled
      expect(find.text('Add to My Decks'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  // ===========================================================================
  // GROUP 2: EXPANDABLE SECTIONS (0-CARD EDGE CASES & LARGE 100-CARD DECKS)
  // ===========================================================================
  group('CHALLENGER GROUP 2: Expandable Sections (0-Card Edge Cases & Large 100-Card Decks)', () {
    testWidgets('2.1 Deck with 0 card items renders cleanly without layout crash or unhandled errors',
        (tester) async {
      const emptyDeckId = 'empty_deck_0';
      final now = DateTime.now();

      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: emptyDeckId,
          name: 'Completely Empty Deck',
          format: 'Standard',
          tcgDomain: const Value('mtg'),
          sourceType: const Value('community'),
          creatorName: const Value('@GhostBrewer'),
          description: const Value('A deck that contains zero card items.'),
          commanderName: const Value(null),
          commanderImageUrl: const Value(null),
          commanderArtCrop: const Value(null),
          colorIdentity: const Value('[]'),
          cardCount: const Value(0),
          estimatedPrice: const Value(0.0),
          upvotes: const Value(0),
          downvotes: const Value(0),
          score: const Value(0),
          createdAt: now,
          updatedAt: Value(now),
          isDeleted: const Value(false),
        ),
      );

      await tester.pumpWidget(
        buildTestApp(
          child: ReadOnlyDeckScreen(exploreDeckId: emptyDeckId),
        ),
      );
      await tester.pumpAndSettle();

      // Verifies screen mounted
      expect(find.byKey(const Key('read_only_deck_screen')), findsOneWidget);
      expect(find.text('Completely Empty Deck'), findsWidgets);
      expect(find.text('@GhostBrewer'), findsOneWidget);
      expect(find.text('0 Cards'), findsOneWidget);
      expect(find.text('\$0.00'), findsOneWidget);

      // Card sections should NOT render since all are empty
      expect(find.byKey(const Key('read_only_section_commander')), findsNothing);
      expect(find.byKey(const Key('read_only_section_creatures')), findsNothing);
      expect(find.byKey(const Key('read_only_section_spells')), findsNothing);
      expect(find.byKey(const Key('read_only_section_permanents')), findsNothing);
      expect(find.byKey(const Key('read_only_section_lands')), findsNothing);
      expect(find.byKey(const Key('read_only_section_sideboard')), findsNothing);

      // Cloning an empty deck succeeds cleanly without crashing
      await tester.tap(find.byKey(const Key('explore_clone_deck_button')));
      await tester.pumpAndSettle();

      final cloned = await (db.select(db.decks)
            ..where((t) => t.sourceExploreDeckId.equals(emptyDeckId)))
          .getSingle();
      expect(cloned.name, equals('Completely Empty Deck (Copy)'));
    });

    testWidgets('2.2 Partial deck with missing sections: only non-empty sections render and toggle smoothly',
        (tester) async {
      const partialDeckId = 'partial_deck_spells_only';
      final now = DateTime.now();

      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: partialDeckId,
          name: 'Burn Spells Only',
          format: 'Modern',
          tcgDomain: const Value('mtg'),
          sourceType: const Value('community'),
          creatorName: const Value('@LightningBoltFan'),
          description: const Value('Only spells and no creatures or sideboard.'),
          cardCount: const Value(8),
          estimatedPrice: const Value(24.00),
          upvotes: const Value(5),
          downvotes: const Value(1),
          score: const Value(4),
          createdAt: now,
          updatedAt: Value(now),
          isDeleted: const Value(false),
        ),
      );

      // Add only Spells (Instant & Sorcery)
      await db.into(db.exploreDeckItems).insert(
        ExploreDeckItemsCompanion.insert(
          id: '${partialDeckId}_s1',
          exploreDeckId: partialDeckId,
          cardName: 'Lightning Bolt',
          manaCost: const Value('{R}'),
          cmc: const Value(1.0),
          typeLine: const Value('Instant'),
          quantity: const Value(4),
          boardZone: const Value('Mainboard'),
          isCommander: const Value(false),
          price: const Value(2.50),
        ),
      );

      await db.into(db.exploreDeckItems).insert(
        ExploreDeckItemsCompanion.insert(
          id: '${partialDeckId}_s2',
          exploreDeckId: partialDeckId,
          cardName: 'Lava Spike',
          manaCost: const Value('{R}'),
          cmc: const Value(1.0),
          typeLine: const Value('Sorcery'),
          quantity: const Value(4),
          boardZone: const Value('Mainboard'),
          isCommander: const Value(false),
          price: const Value(3.50),
        ),
      );

      await tester.pumpWidget(
        buildTestApp(
          child: ReadOnlyDeckScreen(exploreDeckId: partialDeckId),
        ),
      );
      await tester.pumpAndSettle();

      // Only Spells section must render
      expect(find.byKey(const Key('read_only_section_spells')), findsOneWidget);
      expect(find.byKey(const Key('read_only_section_commander')), findsNothing);
      expect(find.byKey(const Key('read_only_section_creatures')), findsNothing);
      expect(find.byKey(const Key('read_only_section_permanents')), findsNothing);
      expect(find.byKey(const Key('read_only_section_lands')), findsNothing);
      expect(find.byKey(const Key('read_only_section_sideboard')), findsNothing);

      // Section counts
      expect(find.text('Instants & Sorceries (8)'), findsOneWidget);
      expect(find.text('Lightning Bolt'), findsOneWidget);
      expect(find.text('Lava Spike'), findsOneWidget);

      // Tap header to collapse section
      await tester.tap(find.text('Instants & Sorceries (8)'));
      await tester.pumpAndSettle();

      // Cards should be hidden while section is collapsed
      expect(find.text('Lightning Bolt'), findsNothing);
      expect(find.text('Lava Spike'), findsNothing);

      // Tap header again to expand section
      await tester.tap(find.text('Instants & Sorceries (8)'));
      await tester.pumpAndSettle();

      // Cards restored
      expect(find.text('Lightning Bolt'), findsOneWidget);
      expect(find.text('Lava Spike'), findsOneWidget);
    });

    testWidgets('2.3 Massive 100+ card deck stress test: scrolls smoothly without RenderFlex overflow',
        (tester) async {
      const largeDeckId = 'large_deck_100';
      final now = DateTime.now();

      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: largeDeckId,
          name: 'Urza Artificer 100-Card Precon',
          format: 'Commander',
          tcgDomain: const Value('mtg'),
          sourceType: const Value('official'),
          creatorName: const Value('Official WotC'),
          description: const Value('Full 100-card precon stress test.'),
          cardCount: const Value(100),
          estimatedPrice: const Value(350.00),
          upvotes: const Value(100),
          downvotes: const Value(10),
          score: const Value(90),
          createdAt: now,
          updatedAt: Value(now),
          isDeleted: const Value(false),
        ),
      );

      // Seed 1 Commander
      await db.into(db.exploreDeckItems).insert(
        ExploreDeckItemsCompanion.insert(
          id: '${largeDeckId}_cmd_1',
          exploreDeckId: largeDeckId,
          cardName: 'Urza, Lord High Artificer',
          manaCost: const Value('{2}{U}{U}'),
          cmc: const Value(4.0),
          typeLine: const Value('Legendary Creature — Human Artificer'),
          quantity: const Value(1),
          boardZone: const Value('Commander'),
          isCommander: const Value(true),
          price: const Value(18.00),
        ),
      );

      // Seed 25 unique Creatures
      for (int i = 1; i <= 25; i++) {
        await db.into(db.exploreDeckItems).insert(
          ExploreDeckItemsCompanion.insert(
            id: '${largeDeckId}_cr_$i',
            exploreDeckId: largeDeckId,
            cardName: 'Artificer Creature #$i',
            manaCost: const Value('{2}{U}'),
            cmc: const Value(3.0),
            typeLine: const Value('Creature — Artificer'),
            quantity: const Value(1),
            boardZone: const Value('Mainboard'),
            isCommander: const Value(false),
            price: const Value(1.50),
          ),
        );
      }

      // Seed 25 unique Spells
      for (int i = 1; i <= 25; i++) {
        await db.into(db.exploreDeckItems).insert(
          ExploreDeckItemsCompanion.insert(
            id: '${largeDeckId}_sp_$i',
            exploreDeckId: largeDeckId,
            cardName: 'Blue Instant #$i',
            manaCost: const Value('{1}{U}'),
            cmc: const Value(2.0),
            typeLine: const Value('Instant'),
            quantity: const Value(1),
            boardZone: const Value('Mainboard'),
            isCommander: const Value(false),
            price: const Value(0.80),
          ),
        );
      }

      // Seed 20 unique Artifacts
      for (int i = 1; i <= 20; i++) {
        await db.into(db.exploreDeckItems).insert(
          ExploreDeckItemsCompanion.insert(
            id: '${largeDeckId}_art_$i',
            exploreDeckId: largeDeckId,
            cardName: 'Mana Artifact #$i',
            manaCost: const Value('{2}'),
            cmc: const Value(2.0),
            typeLine: const Value('Artifact'),
            quantity: const Value(1),
            boardZone: const Value('Mainboard'),
            isCommander: const Value(false),
            price: const Value(2.20),
          ),
        );
      }

      // Seed 29 Lands
      for (int i = 1; i <= 29; i++) {
        await db.into(db.exploreDeckItems).insert(
          ExploreDeckItemsCompanion.insert(
            id: '${largeDeckId}_lnd_$i',
            exploreDeckId: largeDeckId,
            cardName: 'Island #$i',
            manaCost: const Value(''),
            cmc: const Value(0.0),
            typeLine: const Value('Basic Land — Island'),
            quantity: const Value(1),
            boardZone: const Value('Mainboard'),
            isCommander: const Value(false),
            price: const Value(0.15),
          ),
        );
      }

      await tester.pumpWidget(
        buildTestApp(
          child: ReadOnlyDeckScreen(exploreDeckId: largeDeckId),
        ),
      );
      await tester.pumpAndSettle();

      // Verify sections mounted
      expect(find.byKey(const Key('read_only_section_commander')), findsOneWidget);
      expect(find.byKey(const Key('read_only_section_creatures')), findsOneWidget);

      // Deep scroll down through the 100-card deck
      final scrollFinder = find.byType(SingleChildScrollView);
      expect(scrollFinder, findsOneWidget);

      for (int step = 0; step < 8; step++) {
        await tester.drag(scrollFinder, const Offset(0, -600));
        await tester.pumpAndSettle();
      }

      // Verify deep sections reached without error
      expect(find.byKey(const Key('read_only_section_lands')), findsOneWidget);

      // Deep scroll back up
      for (int step = 0; step < 8; step++) {
        await tester.drag(scrollFinder, const Offset(0, 600));
        await tester.pumpAndSettle();
      }

      // Verify sticky clone button is always visible
      expect(find.byKey(const Key('explore_clone_deck_button')), findsOneWidget);
    });
  });

  // ===========================================================================
  // GROUP 3: PERSISTENT VOTING STATE MACHINE & REACTIVITY INVARIANTS
  // ===========================================================================
  group('CHALLENGER GROUP 3: Persistent Voting State Machine & Reactivity Invariants', () {
    testWidgets('3.1 Complete voting lifecycle: upvote, toggle off, downvote, toggle off, flip direction',
        (tester) async {
      await seedStandardDeck(score: 10, upvotes: 12, downvotes: 2);

      await tester.pumpWidget(
        buildTestApp(
          child: ReadOnlyDeckScreen(exploreDeckId: kTestDeckId),
        ),
      );
      await tester.pumpAndSettle();

      final upvoteFinder = find.byKey(Key('read_only_upvote_$kTestDeckId'));
      final downvoteFinder = find.byKey(Key('read_only_downvote_$kTestDeckId'));
      final scoreFinder = find.byKey(Key('read_only_score_$kTestDeckId'));

      expect(scoreFinder, findsOneWidget);
      expect(find.text('10'), findsOneWidget);

      // 1. Tap Upvote -> score 11, upvote turns emerald
      await tester.tap(upvoteFinder);
      await tester.pumpAndSettle();

      expect(find.text('11'), findsOneWidget);
      final upvoteIcon1 = tester.widget<Icon>(
        find.descendant(of: upvoteFinder, matching: find.byType(Icon)),
      );
      expect(upvoteIcon1.color, equals(AppColors.accentEmerald));

      var voteRow = await (db.select(db.exploreDeckVotes)
            ..where((t) => t.exploreDeckId.equals(kTestDeckId)))
          .getSingle();
      expect(voteRow.vote, equals(1));

      // 2. Tap Upvote again -> toggle off back to 10
      await tester.tap(upvoteFinder);
      await tester.pumpAndSettle();

      expect(find.text('10'), findsOneWidget);
      final upvoteIcon2 = tester.widget<Icon>(
        find.descendant(of: upvoteFinder, matching: find.byType(Icon)),
      );
      expect(upvoteIcon2.color, equals(AppColors.textMuted));

      voteRow = await (db.select(db.exploreDeckVotes)
            ..where((t) => t.exploreDeckId.equals(kTestDeckId)))
          .getSingle();
      expect(voteRow.vote, equals(0));

      // 3. Tap Downvote -> score 9, downvote turns amber
      await tester.tap(downvoteFinder);
      await tester.pumpAndSettle();

      expect(find.text('9'), findsOneWidget);
      final downvoteIcon1 = tester.widget<Icon>(
        find.descendant(of: downvoteFinder, matching: find.byType(Icon)),
      );
      expect(downvoteIcon1.color, equals(AppColors.accentAmber));

      voteRow = await (db.select(db.exploreDeckVotes)
            ..where((t) => t.exploreDeckId.equals(kTestDeckId)))
          .getSingle();
      expect(voteRow.vote, equals(-1));

      // 4. Tap Downvote again -> toggle off back to 10
      await tester.tap(downvoteFinder);
      await tester.pumpAndSettle();

      expect(find.text('10'), findsOneWidget);
      final downvoteIcon2 = tester.widget<Icon>(
        find.descendant(of: downvoteFinder, matching: find.byType(Icon)),
      );
      expect(downvoteIcon2.color, equals(AppColors.textMuted));

      voteRow = await (db.select(db.exploreDeckVotes)
            ..where((t) => t.exploreDeckId.equals(kTestDeckId)))
          .getSingle();
      expect(voteRow.vote, equals(0));

      // 5. Flip Direction: Downvote (score 9) -> Upvote (score 11, delta +2)
      await tester.tap(downvoteFinder);
      await tester.pumpAndSettle();
      expect(find.text('9'), findsOneWidget);

      await tester.tap(upvoteFinder);
      await tester.pumpAndSettle();

      expect(find.text('11'), findsOneWidget);
      final upvoteIcon3 = tester.widget<Icon>(
        find.descendant(of: upvoteFinder, matching: find.byType(Icon)),
      );
      expect(upvoteIcon3.color, equals(AppColors.accentEmerald));

      voteRow = await (db.select(db.exploreDeckVotes)
            ..where((t) => t.exploreDeckId.equals(kTestDeckId)))
          .getSingle();
      expect(voteRow.vote, equals(1));
    });

    testWidgets('3.2 Rapid alternating vote stress test maintains SQLite integrity and score consistency',
        (tester) async {
      await seedStandardDeck(score: 50);

      await tester.pumpWidget(
        buildTestApp(
          child: ReadOnlyDeckScreen(exploreDeckId: kTestDeckId),
        ),
      );
      await tester.pumpAndSettle();

      final upvoteFinder = find.byKey(Key('read_only_upvote_$kTestDeckId'));
      final downvoteFinder = find.byKey(Key('read_only_downvote_$kTestDeckId'));

      // Perform 6 alternating taps
      await tester.tap(upvoteFinder);
      await tester.pumpAndSettle();
      await tester.tap(downvoteFinder);
      await tester.pumpAndSettle();
      await tester.tap(upvoteFinder);
      await tester.pumpAndSettle();
      await tester.tap(downvoteFinder);
      await tester.pumpAndSettle();
      await tester.tap(upvoteFinder);
      await tester.pumpAndSettle();
      await tester.tap(upvoteFinder); // Toggle off
      await tester.pumpAndSettle();

      // State is neutral
      expect(find.text('50'), findsOneWidget);

      final voteRow = await (db.select(db.exploreDeckVotes)
            ..where((t) => t.exploreDeckId.equals(kTestDeckId)))
          .getSingle();
      expect(voteRow.vote, equals(0));
    });
  });

  // ===========================================================================
  // GROUP 4: VIEWPORT GEOMETRY & HOSTILE CONTENT INVARIANTS
  // ===========================================================================
  group('CHALLENGER GROUP 4: Viewport Geometry & Hostile Content Invariants', () {
    testWidgets('4.1 Compact mobile viewport (320x568 iPhone SE) renders with zero RenderFlex overflow',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await seedStandardDeck();

      await tester.pumpWidget(
        buildTestApp(
          child: ReadOnlyDeckScreen(exploreDeckId: kTestDeckId),
        ),
      );
      await tester.pumpAndSettle();

      // Verify no overflow error occurred
      expect(find.byKey(const Key('read_only_deck_screen')), findsOneWidget);
      expect(find.byKey(const Key('explore_clone_deck_button')), findsOneWidget);
    });

    testWidgets('4.2 Hostile long strings & extreme prices wrap cleanly without breaking layout',
        (tester) async {
      const hostileDeckId = 'hostile_deck_strings';
      const extremeTitle =
          'Ultra Super Long Competitive Deck Name Intended To Stress Test Layout Boundaries In ReadOnlyDeckScreen Header Columns Without Crashing';
      const extremeCreator = '@A_Ludicrously_Long_Creator_Username_Exceeding_Expected_Lengths';
      const extremeDescription =
          'Paragraph 1: Testing extreme description text lengths to ensure container padding and text typography wrap properly.\n\nParagraph 2: Additional paragraph data ensuring multi-line vertical expansion operates without overflow.';

      await seedStandardDeck(
        deckId: hostileDeckId,
        name: extremeTitle,
        creator: extremeCreator,
        sourceType: 'community',
        description: extremeDescription,
        colorIdentity: ['W', 'U', 'B', 'R', 'G'], // All 5 colors
      );

      // Use narrow standard viewport (360x640)
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestApp(
          child: ReadOnlyDeckScreen(exploreDeckId: hostileDeckId),
        ),
      );
      await tester.pumpAndSettle();

      // Confirms all components rendered without RenderFlex overflow
      expect(find.text(extremeTitle), findsWidgets);
      expect(find.text(extremeCreator), findsOneWidget);
      expect(find.byKey(const Key('explore_clone_deck_button')), findsOneWidget);
    });

    testWidgets('4.3 Constrained landscape viewport (600x320) handles scrolling and sticky bar',
        (tester) async {
      tester.view.physicalSize = const Size(600, 320);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await seedStandardDeck();

      await tester.pumpWidget(
        buildTestApp(
          child: ReadOnlyDeckScreen(exploreDeckId: kTestDeckId),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('read_only_deck_screen')), findsOneWidget);
      expect(find.byKey(const Key('explore_clone_deck_button')), findsOneWidget);

      // Scroll works cleanly in constrained landscape
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -200));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('explore_clone_deck_button')), findsOneWidget);
    });
  });

  // ===========================================================================
  // GROUP 5: CREATOR BADGES, BANNER FALLBACK & MISSING DECK INVARIANTS
  // ===========================================================================
  group('CHALLENGER GROUP 5: Creator Badges, Banner Fallback & Missing Deck Invariants', () {
    testWidgets('5.1 Creator badging: Official WotC shows verified badge; Community shows @username in muted text',
        (tester) async {
      // 1. Official Deck
      await seedStandardDeck(
        deckId: 'official_deck_1',
        name: 'Official Precon',
        creator: 'Official WotC',
        sourceType: 'official',
      );

      await tester.pumpWidget(
        buildTestApp(
          child: ReadOnlyDeckScreen(exploreDeckId: 'official_deck_1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Official WotC'), findsOneWidget);
      expect(find.byIcon(Icons.verified_rounded), findsOneWidget);

      // 2. Community Deck
      await seedStandardDeck(
        deckId: 'community_deck_1',
        name: 'Community Brew',
        creator: 'SpicyBrewMaster',
        sourceType: 'community',
      );

      await tester.pumpWidget(
        buildTestApp(
          child: ReadOnlyDeckScreen(exploreDeckId: 'community_deck_1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('@SpicyBrewMaster'), findsOneWidget);
      expect(find.byIcon(Icons.verified_rounded), findsNothing);
    });

    testWidgets('5.2 Null art crops and URLs render fallback decorative banner cleanly',
        (tester) async {
      await seedStandardDeck(
        deckId: 'null_banner_deck',
        commanderArtCrop: null,
        commanderImageUrl: null,
      );

      await tester.pumpWidget(
        buildTestApp(
          child: ReadOnlyDeckScreen(exploreDeckId: 'null_banner_deck'),
        ),
      );
      await tester.pumpAndSettle();

      // Verifies fallback decoration icon renders
      expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
    });

    testWidgets('5.3 Non-existent deck ID renders graceful "Deck not found" screen',
        (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: ReadOnlyDeckScreen(exploreDeckId: 'non_existent_id_404'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Deck not found'), findsOneWidget);
      // Bottom clone bar should be absent
      expect(find.byKey(const Key('explore_clone_deck_button')), findsNothing);
    });
  });
}
