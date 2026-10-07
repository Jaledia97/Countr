import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/decks/data/daos/explore_deck_dao.dart';
import 'package:countr/features/decks/presentation/providers/explore_deck_providers.dart';
import 'package:countr/features/decks/presentation/screens/read_only_deck_screen.dart';
import 'package:countr/features/decks/presentation/widgets/explore/explore_deck_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  late AppDatabase db;
  late VaultDao vaultDao;
  late ExploreDeckDao exploreDao;

  const testDeckId = 'explore_deck_test_1';
  const testDeckName = 'The Ur-Dragon Onslaught';

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    vaultDao = VaultDao(db);
    exploreDao = ExploreDeckDao(db);

    final now = DateTime.now();

    // 1. Seed Explore Deck
    await db.into(db.exploreDecks).insert(
      ExploreDecksCompanion.insert(
        id: testDeckId,
        name: testDeckName,
        format: 'Commander',
        tcgDomain: const Value('mtg'),
        sourceType: const Value('official'),
        creatorName: const Value('Official WotC'),
        description: const Value('Precon Dragon tribal deck led by The Ur-Dragon.'),
        commanderName: const Value('The Ur-Dragon'),
        commanderImageUrl: const Value('https://cards.scryfall.io/normal/front/7/e/7e78b70b.jpg'),
        commanderArtCrop: const Value('https://cards.scryfall.io/art_crop/front/7/e/7e78b70b.jpg'),
        colorIdentity: const Value('["W","U","B","R","G"]'),
        cardCount: const Value(100),
        estimatedPrice: const Value(125.50),
        upvotes: const Value(50),
        downvotes: const Value(2),
        score: const Value(48),
        featuredCategory: const Value('Suggested Commanders'),
        createdAt: now.subtract(const Duration(days: 3)),
        updatedAt: Value(now),
        isDeleted: const Value(false),
      ),
    );

    // 2. Seed Explore Deck Items
    // Commander
    await db.into(db.exploreDeckItems).insert(
      ExploreDeckItemsCompanion.insert(
        id: 'item_cmd_1',
        exploreDeckId: testDeckId,
        cardName: 'The Ur-Dragon',
        manaCost: const Value('{4}{W}{U}{B}{R}{G}'),
        cmc: const Value(9.0),
        typeLine: const Value('Legendary Creature — Dragon Avatar'),
        quantity: const Value(1),
        boardZone: const Value('Commander'),
        isCommander: const Value(true),
        price: const Value(8.50),
      ),
    );

    // Creatures
    await db.into(db.exploreDeckItems).insert(
      ExploreDeckItemsCompanion.insert(
        id: 'item_creature_1',
        exploreDeckId: testDeckId,
        cardName: 'Scion of the Ur-Dragon',
        manaCost: const Value('{W}{U}{B}{R}{G}'),
        cmc: const Value(5.0),
        typeLine: const Value('Legendary Creature — Dragon Avatar'),
        quantity: const Value(1),
        boardZone: const Value('Mainboard'),
        isCommander: const Value(false),
        price: const Value(4.25),
      ),
    );

    await db.into(db.exploreDeckItems).insert(
      ExploreDeckItemsCompanion.insert(
        id: 'item_creature_2',
        exploreDeckId: testDeckId,
        cardName: 'Utvara Hellkite',
        manaCost: const Value('{6}{R}{R}'),
        cmc: const Value(8.0),
        typeLine: const Value('Creature — Dragon'),
        quantity: const Value(1),
        boardZone: const Value('Mainboard'),
        isCommander: const Value(false),
        price: const Value(9.50),
      ),
    );

    // Spells (Instants & Sorceries)
    await db.into(db.exploreDeckItems).insert(
      ExploreDeckItemsCompanion.insert(
        id: 'item_spell_1',
        exploreDeckId: testDeckId,
        cardName: 'Crux of Fate',
        manaCost: const Value('{3}{B}{B}'),
        cmc: const Value(5.0),
        typeLine: const Value('Sorcery'),
        quantity: const Value(1),
        boardZone: const Value('Mainboard'),
        isCommander: const Value(false),
        price: const Value(3.50),
      ),
    );

    await db.into(db.exploreDeckItems).insert(
      ExploreDeckItemsCompanion.insert(
        id: 'item_spell_2',
        exploreDeckId: testDeckId,
        cardName: 'Swords to Plowshares',
        manaCost: const Value('{W}'),
        cmc: const Value(1.0),
        typeLine: const Value('Instant'),
        quantity: const Value(1),
        boardZone: const Value('Mainboard'),
        isCommander: const Value(false),
        price: const Value(1.60),
      ),
    );

    // Permanents (Artifacts & Enchantments)
    await db.into(db.exploreDeckItems).insert(
      ExploreDeckItemsCompanion.insert(
        id: 'item_artifact_1',
        exploreDeckId: testDeckId,
        cardName: 'Sol Ring',
        manaCost: const Value('{1}'),
        cmc: const Value(1.0),
        typeLine: const Value('Artifact'),
        quantity: const Value(1),
        boardZone: const Value('Mainboard'),
        isCommander: const Value(false),
        price: const Value(2.50),
      ),
    );

    // Lands
    await db.into(db.exploreDeckItems).insert(
      ExploreDeckItemsCompanion.insert(
        id: 'item_land_1',
        exploreDeckId: testDeckId,
        cardName: 'Command Tower',
        manaCost: const Value(''),
        cmc: const Value(0.0),
        typeLine: const Value('Land'),
        quantity: const Value(1),
        boardZone: const Value('Mainboard'),
        isCommander: const Value(false),
        price: const Value(0.50),
      ),
    );

    await db.into(db.exploreDeckItems).insert(
      ExploreDeckItemsCompanion.insert(
        id: 'item_land_2',
        exploreDeckId: testDeckId,
        cardName: 'Forest',
        manaCost: const Value(''),
        cmc: const Value(0.0),
        typeLine: const Value('Basic Land — Forest'),
        quantity: const Value(10),
        boardZone: const Value('Mainboard'),
        isCommander: const Value(false),
        price: const Value(0.10),
      ),
    );

    // Sideboard
    await db.into(db.exploreDeckItems).insert(
      ExploreDeckItemsCompanion.insert(
        id: 'item_sideboard_1',
        exploreDeckId: testDeckId,
        cardName: 'Dragon Tempest',
        manaCost: const Value('{1}{R}'),
        cmc: const Value(2.0),
        typeLine: const Value('Enchantment'),
        quantity: const Value(1),
        boardZone: const Value('Sideboard'),
        isCommander: const Value(false),
        price: const Value(2.20),
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildSubject({
    required Widget child,
  }) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        vaultDaoProvider.overrideWithValue(vaultDao),
        exploreDeckDaoProvider.overrideWithValue(exploreDao),
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('Milestone 5: Read-Only Deck Screen & Clone Engine Tests', () {
    testWidgets('1. Tapping explore card navigates to ReadOnlyDeckScreen',
        (tester) async {
      final deckWithVote = await exploreDao.getExploreDeck(testDeckId);
      expect(deckWithVote, isNotNull);

      await tester.pumpWidget(
        buildSubject(
          child: Scaffold(
            body: Center(
              child: ExploreDeckCard(
                deckWithVote: deckWithVote!,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Card is displayed with explore card key
      final cardFinder = find.byKey(Key('explore_card_$testDeckId'));
      expect(cardFinder, findsOneWidget);

      // Tap explore card with default navigation
      await tester.tap(cardFinder);
      await tester.pumpAndSettle();

      // Confirms navigation pushed ReadOnlyDeckScreen
      expect(find.byKey(const Key('read_only_deck_screen')), findsOneWidget);
      expect(find.text(testDeckName), findsWidgets);
    });

    testWidgets(
        '2. ReadOnlyDeckScreen displays banner, badges, price, and partitions cards by type (Commander, Creatures, Lands, Spells)',
        (tester) async {
      await tester.pumpWidget(
        buildSubject(
          child: ReadOnlyDeckScreen(
            exploreDeckId: testDeckId,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Screen is mounted
      expect(find.byKey(const Key('read_only_deck_screen')), findsOneWidget);

      // Deck overview metadata
      expect(find.text(testDeckName), findsWidgets);
      expect(find.text('Official WotC'), findsOneWidget);
      expect(find.text('Commander'), findsWidgets);
      expect(find.text('100 Cards'), findsOneWidget);
      expect(find.text('\$125.50'), findsOneWidget);
      expect(find.text('Precon Dragon tribal deck led by The Ur-Dragon.'),
          findsOneWidget);

      // Partitioned sections by MTG card type
      expect(find.byKey(const Key('read_only_section_commander')), findsOneWidget);
      expect(find.byKey(const Key('read_only_section_creatures')), findsOneWidget);
      expect(find.byKey(const Key('read_only_section_spells')), findsOneWidget);
      expect(find.byKey(const Key('read_only_section_permanents')), findsOneWidget);
      expect(find.byKey(const Key('read_only_section_lands')), findsOneWidget);
      expect(find.byKey(const Key('read_only_section_sideboard')), findsOneWidget);

      // Verifies cards rendered with quantities and names
      expect(find.text('The Ur-Dragon'), findsWidgets);
      expect(find.text('Scion of the Ur-Dragon'), findsOneWidget);
      expect(find.text('Utvara Hellkite'), findsOneWidget);
      expect(find.text('Crux of Fate'), findsOneWidget);
      expect(find.text('Swords to Plowshares'), findsOneWidget);
      expect(find.text('Sol Ring'), findsOneWidget);
      expect(find.text('Command Tower'), findsOneWidget);
      expect(find.text('Forest'), findsOneWidget);
      expect(find.text('Dragon Tempest'), findsOneWidget);

      // Verifies section counts
      expect(find.text('Commander (1)'), findsOneWidget);
      expect(find.text('Creatures (2)'), findsOneWidget);
      expect(find.text('Instants & Sorceries (2)'), findsOneWidget);
      expect(find.text('Artifacts & Enchantments (1)'), findsOneWidget);
      expect(find.text('Lands (11)'), findsOneWidget); // 1 Command Tower + 10 Forest
      expect(find.text('Sideboard (1)'), findsOneWidget);
    });

    testWidgets(
        '3. Confirms editing and builder actions are completely hidden / absent',
        (tester) async {
      await tester.pumpWidget(
        buildSubject(
          child: ReadOnlyDeckScreen(
            exploreDeckId: testDeckId,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Strictly verifies builder and editing actions do NOT exist
      expect(find.text('Add Card'), findsNothing);
      expect(find.text('Add Cards'), findsNothing);
      expect(find.text('Edit Deck'), findsNothing);
      expect(find.text('Delete Deck'), findsNothing);
      expect(find.text('Playtest'), findsNothing);
      expect(find.byKey(const Key('deck_setup_wizard_button')), findsNothing);
      expect(find.byKey(const Key('deck_builder_add_card_button')), findsNothing);
      expect(find.byKey(Key('deck_card_menu_$testDeckId')), findsNothing);
      expect(find.byIcon(Icons.delete), findsNothing);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
    });

    testWidgets(
        '4. Interactive voting updates score reactively inside ReadOnlyDeckScreen',
        (tester) async {
      await tester.pumpWidget(
        buildSubject(
          child: ReadOnlyDeckScreen(
            exploreDeckId: testDeckId,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initial score is 48
      final scoreFinder = find.byKey(Key('read_only_score_$testDeckId'));
      expect(scoreFinder, findsOneWidget);
      expect(find.text('48'), findsOneWidget);

      // Tap Upvote
      final upvoteFinder = find.byKey(Key('read_only_upvote_$testDeckId'));
      expect(upvoteFinder, findsOneWidget);
      await tester.tap(upvoteFinder);
      await tester.pumpAndSettle();

      // Score reactively updates from 48 -> 49
      expect(find.text('49'), findsOneWidget);

      // Verify persistent write in SQLite
      final voteRowAfterUp = await (db.select(db.exploreDeckVotes)
            ..where((t) => t.exploreDeckId.equals(testDeckId)))
          .getSingle();
      expect(voteRowAfterUp.vote, equals(1));

      // Tap Downvote
      final downvoteFinder = find.byKey(Key('read_only_downvote_$testDeckId'));
      expect(downvoteFinder, findsOneWidget);
      await tester.tap(downvoteFinder);
      await tester.pumpAndSettle();

      // Score reactively updates from 49 -> 47 (new delta: -1 - (+1) = -2)
      expect(find.text('47'), findsOneWidget);

      // Verify downvote persisted in SQLite
      final voteRowAfterDown = await (db.select(db.exploreDeckVotes)
            ..where((t) => t.exploreDeckId.equals(testDeckId)))
          .getSingle();
      expect(voteRowAfterDown.vote, equals(-1));
    });

    testWidgets(
        '5. Tapping "Add to My Decks" button successfully executes clone into SQLite tables decks, deck_versions, deck_version_items, sets isCloned = true, and displays SnackBar',
        (tester) async {
      // Pre-check: No cloned decks exist
      final initialDecks = await db.select(db.decks).get();
      expect(
        initialDecks.where((d) => d.sourceExploreDeckId == testDeckId),
        isEmpty,
      );

      await tester.pumpWidget(
        buildSubject(
          child: ReadOnlyDeckScreen(
            exploreDeckId: testDeckId,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Locate clone button in sticky bottom bar
      final cloneButtonFinder = find.byKey(const Key('explore_clone_deck_button'));
      expect(cloneButtonFinder, findsOneWidget);
      expect(find.text('Add to My Decks'), findsOneWidget);

      // Tap clone button
      await tester.tap(cloneButtonFinder);
      await tester.pumpAndSettle();

      // 1. Confirms SnackBar feedback
      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        find.text('Cloned "$testDeckName" to My Decks!'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(SnackBarAction, 'View in My Decks'),
        findsOneWidget,
      );

      // 2. Confirms SQLite table `decks` contains cloned record with isCloned = true
      final clonedDecks = await (db.select(db.decks)
            ..where((t) => t.sourceExploreDeckId.equals(testDeckId)))
          .get();
      expect(clonedDecks.length, equals(1));
      final clonedDeck = clonedDecks.first;
      expect(clonedDeck.name, equals('$testDeckName (Copy)'));
      expect(clonedDeck.isCloned, isTrue);
      expect(clonedDeck.format, equals('Commander'));
      expect(clonedDeck.isRegistered, isFalse);
      expect(clonedDeck.isAssembled, isFalse);

      // 3. Confirms SQLite table `deck_versions` contains active v1 record
      final versions = await (db.select(db.deckVersions)
            ..where((t) => t.deckId.equals(clonedDeck.id)))
          .get();
      expect(versions.length, equals(1));
      final v1 = versions.first;
      expect(v1.versionNumber, equals(1));
      expect(v1.isActive, isTrue);

      // 4. Confirms SQLite table `deck_version_items` contains all 9 cloned cards
      final items = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals(v1.id)))
          .get();
      expect(items.length, equals(9));
      expect(items.every((i) => i.isProxy == true), isTrue);
    });
  });
}
