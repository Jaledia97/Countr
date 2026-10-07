import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:uuid/uuid.dart';

import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/decks/data/daos/explore_deck_dao.dart';
import 'package:countr/features/decks/presentation/providers/explore_deck_providers.dart';
import 'package:countr/features/decks/presentation/screens/read_only_deck_screen.dart';

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
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildSubject({required Widget child}) {
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

  // ===========================================================================
  // GROUP 1: FULL COMMANDER DECK CLONE FIDELITY & SCHEMA INVARIANTS
  // ===========================================================================
  group('1. Full Commander Deck Clone Fidelity & Schema Invariants', () {
    test('Clones authentic 100-card Commander deck with exact fidelity and zones', () async {
      const exploreDeckId = 'explore_cmd_dragon_100';
      const deckTitle = 'The Ur-Dragon Supreme Swarm';
      final now = DateTime.now();

      // 1. Seed Explore Deck
      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: exploreDeckId,
          name: deckTitle,
          format: 'Commander',
          tcgDomain: const Value('mtg'),
          sourceType: const Value('official'),
          creatorName: const Value('Wizards of the Coast'),
          description: const Value('Complete 100-card dragon tribal precon.'),
          commanderName: const Value('The Ur-Dragon'),
          commanderImageUrl: const Value('https://cards.scryfall.io/ur_dragon.jpg'),
          commanderArtCrop: const Value('https://cards.scryfall.io/ur_dragon_crop.jpg'),
          colorIdentity: const Value('["W","U","B","R","G"]'),
          cardCount: const Value(100),
          estimatedPrice: const Value(245.80),
          upvotes: const Value(120),
          downvotes: const Value(3),
          score: const Value(117),
          createdAt: now.subtract(const Duration(days: 10)),
          updatedAt: Value(now),
        ),
      );

      // Pre-seed 1 card already owned in user's vault to test mixed ownership
      const ownedCardName = 'Sol Ring';
      const ownedVaultId = 'vault_owned_sol_ring_1';
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: ownedVaultId,
          collectionType: 'mtg',
          name: ownedCardName,
          setOrSeries: 'Commander',
          imageUrl: 'https://cards.scryfall.io/sol_ring.jpg',
          acquiredPrice: 2.0,
          acquiredDate: now,
          quantity: const Value(4), // User owns 4 physical copies
          condition: 'NM',
          currentMarketPrice: 2.50,
          lastPriceUpdate: now,
          dynamicData: '{}',
        ),
      );

      final exploreItems = <ExploreDeckItemsCompanion>[];

      // Commander (1x, Commander zone)
      exploreItems.add(
        ExploreDeckItemsCompanion.insert(
          id: 'item_c_0',
          exploreDeckId: exploreDeckId,
          cardName: 'The Ur-Dragon',
          scryfallId: const Value('scryfall-ur-dragon'),
          manaCost: const Value('{4}{W}{U}{B}{R}{G}'),
          cmc: const Value(9.0),
          typeLine: const Value('Legendary Creature — Dragon Avatar'),
          quantity: const Value(1),
          boardZone: const Value('Commander'),
          isCommander: const Value(true),
          price: const Value(15.0),
        ),
      );

      // 34 Creatures (Mainboard, 1x each)
      for (var i = 1; i <= 34; i++) {
        exploreItems.add(
          ExploreDeckItemsCompanion.insert(
            id: 'item_creature_$i',
            exploreDeckId: exploreDeckId,
            cardName: 'Dragon Specimen #$i',
            scryfallId: Value('scryfall-dragon-$i'),
            manaCost: const Value('{3}{R}{R}'),
            cmc: const Value(5.0),
            typeLine: const Value('Creature — Dragon'),
            quantity: const Value(1),
            boardZone: const Value('Mainboard'),
            isCommander: const Value(false),
            price: const Value(1.50),
          ),
        );
      }

      // 10 Instants (Mainboard, 1x each)
      for (var i = 1; i <= 10; i++) {
        exploreItems.add(
          ExploreDeckItemsCompanion.insert(
            id: 'item_instant_$i',
            exploreDeckId: exploreDeckId,
            cardName: 'Instant Spell #$i',
            scryfallId: Value('scryfall-instant-$i'),
            manaCost: const Value('{1}{U}'),
            cmc: const Value(2.0),
            typeLine: const Value('Instant'),
            quantity: const Value(1),
            boardZone: const Value('Mainboard'),
            isCommander: const Value(false),
            price: const Value(0.75),
          ),
        );
      }

      // 10 Sorceries (Mainboard, 1x each)
      for (var i = 1; i <= 10; i++) {
        exploreItems.add(
          ExploreDeckItemsCompanion.insert(
            id: 'item_sorcery_$i',
            exploreDeckId: exploreDeckId,
            cardName: 'Sorcery Spell #$i',
            scryfallId: Value('scryfall-sorcery-$i'),
            manaCost: const Value('{3}{B}{B}'),
            cmc: const Value(5.0),
            typeLine: const Value('Sorcery'),
            quantity: const Value(1),
            boardZone: const Value('Mainboard'),
            isCommander: const Value(false),
            price: const Value(2.0),
          ),
        );
      }

      // 8 Artifacts (Mainboard, 1x each; includes pre-owned Sol Ring)
      exploreItems.add(
        ExploreDeckItemsCompanion.insert(
          id: 'item_artifact_sol_ring',
          exploreDeckId: exploreDeckId,
          cardName: ownedCardName,
          scryfallId: const Value('scryfall-sol-ring'),
          manaCost: const Value('{1}'),
          cmc: const Value(1.0),
          typeLine: const Value('Artifact'),
          quantity: const Value(1),
          boardZone: const Value('Mainboard'),
          isCommander: const Value(false),
          price: const Value(2.50),
        ),
      );
      for (var i = 2; i <= 8; i++) {
        exploreItems.add(
          ExploreDeckItemsCompanion.insert(
            id: 'item_artifact_$i',
            exploreDeckId: exploreDeckId,
            cardName: 'Artifact Rock #$i',
            scryfallId: Value('scryfall-artifact-$i'),
            manaCost: const Value('{2}'),
            cmc: const Value(2.0),
            typeLine: const Value('Artifact'),
            quantity: const Value(1),
            boardZone: const Value('Mainboard'),
            isCommander: const Value(false),
            price: const Value(1.0),
          ),
        );
      }

      // 6 Enchantments (Mainboard, 1x each)
      for (var i = 1; i <= 6; i++) {
        exploreItems.add(
          ExploreDeckItemsCompanion.insert(
            id: 'item_enchantment_$i',
            exploreDeckId: exploreDeckId,
            cardName: 'Dragon Enchantment #$i',
            scryfallId: Value('scryfall-enchantment-$i'),
            manaCost: const Value('{2}{R}'),
            cmc: const Value(3.0),
            typeLine: const Value('Enchantment'),
            quantity: const Value(1),
            boardZone: const Value('Mainboard'),
            isCommander: const Value(false),
            price: const Value(3.0),
          ),
        );
      }

      // 31 Lands (Total 31 cards):
      // 1x Command Tower, 1x Haven of the Spirit Dragon, 10x Mountain, 8x Forest, 6x Swamp, 5x Plains
      exploreItems.add(
        ExploreDeckItemsCompanion.insert(
          id: 'item_land_tower',
          exploreDeckId: exploreDeckId,
          cardName: 'Command Tower',
          scryfallId: const Value('scryfall-command-tower'),
          manaCost: const Value(''),
          cmc: const Value(0.0),
          typeLine: const Value('Land'),
          quantity: const Value(1),
          boardZone: const Value('Mainboard'),
          isCommander: const Value(false),
          price: const Value(0.50),
        ),
      );
      exploreItems.add(
        ExploreDeckItemsCompanion.insert(
          id: 'item_land_haven',
          exploreDeckId: exploreDeckId,
          cardName: 'Haven of the Spirit Dragon',
          scryfallId: const Value('scryfall-haven'),
          manaCost: const Value(''),
          cmc: const Value(0.0),
          typeLine: const Value('Land'),
          quantity: const Value(1),
          boardZone: const Value('Mainboard'),
          isCommander: const Value(false),
          price: const Value(1.80),
        ),
      );
      exploreItems.add(
        ExploreDeckItemsCompanion.insert(
          id: 'item_land_mountain',
          exploreDeckId: exploreDeckId,
          cardName: 'Mountain',
          scryfallId: const Value('scryfall-mountain'),
          manaCost: const Value(''),
          cmc: const Value(0.0),
          typeLine: const Value('Basic Land — Mountain'),
          quantity: const Value(10),
          boardZone: const Value('Mainboard'),
          isCommander: const Value(false),
          price: const Value(0.10),
        ),
      );
      exploreItems.add(
        ExploreDeckItemsCompanion.insert(
          id: 'item_land_forest',
          exploreDeckId: exploreDeckId,
          cardName: 'Forest',
          scryfallId: const Value('scryfall-forest'),
          manaCost: const Value(''),
          cmc: const Value(0.0),
          typeLine: const Value('Basic Land — Forest'),
          quantity: const Value(8),
          boardZone: const Value('Mainboard'),
          isCommander: const Value(false),
          price: const Value(0.10),
        ),
      );
      exploreItems.add(
        ExploreDeckItemsCompanion.insert(
          id: 'item_land_swamp',
          exploreDeckId: exploreDeckId,
          cardName: 'Swamp',
          scryfallId: const Value('scryfall-swamp'),
          manaCost: const Value(''),
          cmc: const Value(0.0),
          typeLine: const Value('Basic Land — Swamp'),
          quantity: const Value(6),
          boardZone: const Value('Mainboard'),
          isCommander: const Value(false),
          price: const Value(0.10),
        ),
      );
      exploreItems.add(
        ExploreDeckItemsCompanion.insert(
          id: 'item_land_plains',
          exploreDeckId: exploreDeckId,
          cardName: 'Plains',
          scryfallId: const Value('scryfall-plains'),
          manaCost: const Value(''),
          cmc: const Value(0.0),
          typeLine: const Value('Basic Land — Plains'),
          quantity: const Value(5),
          boardZone: const Value('Mainboard'),
          isCommander: const Value(false),
          price: const Value(0.10),
        ),
      );

      // 2 Sideboard cards (Sideboard zone, 1x each)
      exploreItems.add(
        ExploreDeckItemsCompanion.insert(
          id: 'item_sb_1',
          exploreDeckId: exploreDeckId,
          cardName: 'Pyroblast',
          scryfallId: const Value('scryfall-pyroblast'),
          manaCost: const Value('{R}'),
          cmc: const Value(1.0),
          typeLine: const Value('Instant'),
          quantity: const Value(1),
          boardZone: const Value('Sideboard'),
          isCommander: const Value(false),
          price: const Value(4.50),
        ),
      );
      exploreItems.add(
        ExploreDeckItemsCompanion.insert(
          id: 'item_sb_2',
          exploreDeckId: exploreDeckId,
          cardName: 'Red Elemental Blast',
          scryfallId: const Value('scryfall-reb'),
          manaCost: const Value('{R}'),
          cmc: const Value(1.0),
          typeLine: const Value('Instant'),
          quantity: const Value(1),
          boardZone: const Value('Sideboard'),
          isCommander: const Value(false),
          price: const Value(2.50),
        ),
      );

      // Ingest all explore items
      for (final item in exploreItems) {
        await db.into(db.exploreDeckItems).insert(item);
      }

      // 2. Execute Clone Engine
      final clonedDeck = await exploreDao.cloneExploreDeckToPersonal(
        exploreDeckId: exploreDeckId,
      );

      // 3. Verify Decks table invariants
      expect(clonedDeck.id, isNot(equals(exploreDeckId)));
      expect(clonedDeck.name, equals('$deckTitle (Copy)'));
      expect(clonedDeck.format, equals('Commander'));
      expect(clonedDeck.tcgDomain, equals('mtg'));
      expect(clonedDeck.description, equals('Complete 100-card dragon tribal precon.'));
      expect(clonedDeck.isCloned, isTrue, reason: 'is_cloned must be true');
      expect(clonedDeck.sourceExploreDeckId, equals(exploreDeckId),
          reason: 'source_explore_deck_id must match explore deck id');
      expect(clonedDeck.isAssembled, isFalse, reason: 'Cloned decks start as draft');
      expect(clonedDeck.isRegistered, isFalse);
      expect(clonedDeck.isCompetitive, isFalse);
      expect(clonedDeck.isDeleted, isFalse);
      expect(clonedDeck.coverItemId, isNotNull,
          reason: 'Commander must be resolved as coverItemId');

      // 4. Verify DeckVersions table invariants
      final versions = await (db.select(db.deckVersions)
            ..where((t) => t.deckId.equals(clonedDeck.id) & t.isDeleted.equals(false)))
          .get();
      expect(versions.length, equals(1));
      final v1 = versions.first;
      expect(v1.versionNumber, equals(1));
      expect(v1.isActive, isTrue);
      expect(v1.deckId, equals(clonedDeck.id));

      // 5. Verify DeckVersionItems table invariants
      final versionItems = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals(v1.id) & t.isDeleted.equals(false)))
          .get();

      // Number of row entries must equal explore items count (68 distinct rows)
      expect(versionItems.length, equals(exploreItems.length));

      // Total quantity sum must equal 102 cards (100 main deck + 2 sideboard)
      final totalQuantity = versionItems.fold<int>(0, (sum, i) => sum + i.quantity);
      expect(totalQuantity, equals(102));

      // Verify board zones distribution
      final commanderItems = versionItems.where((i) => i.boardZone == 'Commander').toList();
      final mainboardItems = versionItems.where((i) => i.boardZone == 'Mainboard').toList();
      final sideboardItems = versionItems.where((i) => i.boardZone == 'Sideboard').toList();

      expect(commanderItems.length, equals(1));
      expect(commanderItems.first.quantity, equals(1));
      expect(commanderItems.first.vaultItemId, equals(clonedDeck.coverItemId));

      expect(sideboardItems.length, equals(2));
      expect(sideboardItems.fold<int>(0, (s, i) => s + i.quantity), equals(2));

      expect(mainboardItems.length, equals(74));
      expect(mainboardItems.fold<int>(0, (s, i) => s + i.quantity), equals(99));

      // Verify proxy status: Sol Ring was owned (quantity 4 >= needed 1), so isProxy MUST be false
      final solRingItem = versionItems.firstWhere(
        (i) => i.vaultItemId == ownedVaultId,
      );
      expect(solRingItem.isProxy, isFalse,
          reason: 'Pre-owned card with adequate quantity must not be marked proxy');

      // Unowned cards (e.g. The Ur-Dragon, Dragon Specimen #1) must be marked isProxy = true
      final urDragonItem = commanderItems.first;
      expect(urDragonItem.isProxy, isTrue,
          reason: 'Unowned synthesized card must be marked isProxy = true');
    });
  });

  // ===========================================================================
  // GROUP 2: TWO-WAY ISOLATION & DATABASE MUTATION INVARIANTS
  // ===========================================================================
  group('2. Two-Way Isolation & Database Mutation Invariants', () {
    test('Personal deck mutations (rename, add cards, delete deck) have ZERO effect on Explore deck', () async {
      const exploreDeckId = 'explore_isolation_deck_1';
      final now = DateTime.now();

      // 1. Seed Explore Deck
      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: exploreDeckId,
          name: 'Immutable Explore Deck',
          format: 'Modern',
          tcgDomain: const Value('mtg'),
          sourceType: const Value('official'),
          creatorName: const Value('WotC Archive'),
          description: const Value('Original untouched description.'),
          cardCount: const Value(60),
          estimatedPrice: const Value(300.0),
          upvotes: const Value(88),
          downvotes: const Value(4),
          score: const Value(84),
          createdAt: now,
          updatedAt: Value(now),
        ),
      );

      // Seed 3 explore items
      for (var i = 1; i <= 3; i++) {
        await db.into(db.exploreDeckItems).insert(
          ExploreDeckItemsCompanion.insert(
            id: 'explore_item_iso_$i',
            exploreDeckId: exploreDeckId,
            cardName: 'Original Card #$i',
            quantity: const Value(4),
            boardZone: const Value('Mainboard'),
            price: const Value(5.0),
          ),
        );
      }

      // Snapshot Explore Deck state prior to clone
      final exploreDeckBefore = await (db.select(db.exploreDecks)
            ..where((t) => t.id.equals(exploreDeckId)))
          .getSingle();
      final exploreItemsBefore = await (db.select(db.exploreDeckItems)
            ..where((t) => t.exploreDeckId.equals(exploreDeckId)))
          .get();

      // 2. Clone to personal deck
      final clonedDeck = await exploreDao.cloneExploreDeckToPersonal(
        exploreDeckId: exploreDeckId,
      );

      final v1 = (await (db.select(db.deckVersions)
            ..where((t) => t.deckId.equals(clonedDeck.id)))
          .get())
          .first;

      // 3. Perform aggressive adversarial mutations on personal deck:
      // A: Rename personal deck & alter description
      await (db.update(db.decks)..where((t) => t.id.equals(clonedDeck.id))).write(
        DecksCompanion(
          name: const Value('Heavily Mutated Deck [PERSONAL HACK]'),
          description: const Value('Completely altered user primer notes.'),
          format: const Value('Vintage'),
          wins: const Value(15),
          losses: const Value(3),
        ),
      );

      // B: Add brand new cards into personal deck
      final newVaultItemId = const Uuid().v4();
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: newVaultItemId,
          collectionType: 'mtg',
          name: 'Black Lotus',
          setOrSeries: 'Alpha',
          imageUrl: '',
          acquiredPrice: 10000.0,
          acquiredDate: now,
          quantity: const Value(1),
          condition: 'NM',
          currentMarketPrice: 20000.0,
          lastPriceUpdate: now,
          dynamicData: '{}',
        ),
      );

      await db.into(db.deckVersionItems).insert(
        DeckVersionItemsCompanion.insert(
          id: const Uuid().v4(),
          versionId: v1.id,
          vaultItemId: newVaultItemId,
          quantity: const Value(1),
          boardZone: 'Mainboard',
          isProxy: const Value(false),
        ),
      );

      // C: Mutate quantities of existing cards in personal deck
      final personalItems = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals(v1.id)))
          .get();
      await (db.update(db.deckVersionItems)
            ..where((t) => t.id.equals(personalItems.first.id)))
          .write(
        const DeckVersionItemsCompanion(quantity: Value(99)),
      );

      // D: Soft-delete an item in personal deck
      await (db.update(db.deckVersionItems)
            ..where((t) => t.id.equals(personalItems.last.id)))
          .write(
        const DeckVersionItemsCompanion(isDeleted: Value(true)),
      );

      // E: Soft-delete the entire personal deck
      await (db.update(db.decks)..where((t) => t.id.equals(clonedDeck.id))).write(
        const DecksCompanion(isDeleted: Value(true)),
      );

      // 4. Assert Explore Deck and Explore Items remain 100% UNTOUCHED
      final exploreDeckAfter = await (db.select(db.exploreDecks)
            ..where((t) => t.id.equals(exploreDeckId)))
          .getSingle();
      final exploreItemsAfter = await (db.select(db.exploreDeckItems)
            ..where((t) => t.exploreDeckId.equals(exploreDeckId)))
          .get();

      // Check Deck fields
      expect(exploreDeckAfter.name, equals(exploreDeckBefore.name));
      expect(exploreDeckAfter.description, equals(exploreDeckBefore.description));
      expect(exploreDeckAfter.format, equals(exploreDeckBefore.format));
      expect(exploreDeckAfter.score, equals(exploreDeckBefore.score));
      expect(exploreDeckAfter.cardCount, equals(exploreDeckBefore.cardCount));
      expect(exploreDeckAfter.isDeleted, isFalse);

      // Check Items
      expect(exploreItemsAfter.length, equals(exploreItemsBefore.length));
      for (var i = 0; i < exploreItemsBefore.length; i++) {
        expect(exploreItemsAfter[i].id, equals(exploreItemsBefore[i].id));
        expect(exploreItemsAfter[i].cardName, equals(exploreItemsBefore[i].cardName));
        expect(exploreItemsAfter[i].quantity, equals(exploreItemsBefore[i].quantity));
        expect(exploreItemsAfter[i].boardZone, equals(exploreItemsBefore[i].boardZone));
        expect(exploreItemsAfter[i].isDeleted, isFalse);
      }
    });

    test('Hard-deleting personal deck records leaves explore database intact', () async {
      const exploreDeckId = 'explore_hard_del_test';
      final now = DateTime.now();

      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: exploreDeckId,
          name: 'Hard Delete Isolation',
          format: 'Pioneer',
          createdAt: now,
        ),
      );

      await db.into(db.exploreDeckItems).insert(
        ExploreDeckItemsCompanion.insert(
          id: 'item_hard_1',
          exploreDeckId: exploreDeckId,
          cardName: 'Thoughtseize',
          quantity: const Value(4),
        ),
      );

      final clonedDeck = await exploreDao.cloneExploreDeckToPersonal(
        exploreDeckId: exploreDeckId,
      );

      // Hard delete personal deck from SQLite
      await (db.delete(db.deckVersionItems)).go();
      await (db.delete(db.deckVersions)).go();
      await (db.delete(db.decks)..where((t) => t.id.equals(clonedDeck.id))).go();

      // Verify explore tables still contain the explore deck and items
      final expDeck = await (db.select(db.exploreDecks)
            ..where((t) => t.id.equals(exploreDeckId)))
          .getSingleOrNull();
      expect(expDeck, isNotNull);
      expect(expDeck!.name, equals('Hard Delete Isolation'));

      final expItems = await (db.select(db.exploreDeckItems)
            ..where((t) => t.exploreDeckId.equals(exploreDeckId)))
          .get();
      expect(expItems.length, equals(1));
      expect(expItems.first.cardName, equals('Thoughtseize'));
    });

    test('Explore deck updates and voting have ZERO effect on cloned personal deck', () async {
      const exploreDeckId = 'explore_vote_iso_test';
      final now = DateTime.now();

      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: exploreDeckId,
          name: 'Voting Isolation Deck',
          format: 'Standard',
          score: const Value(10),
          createdAt: now,
        ),
      );

      await db.into(db.exploreDeckItems).insert(
        ExploreDeckItemsCompanion.insert(
          id: 'item_vote_iso_1',
          exploreDeckId: exploreDeckId,
          cardName: 'Cut Down',
          quantity: const Value(4),
        ),
      );

      final cloned = await exploreDao.cloneExploreDeckToPersonal(
        exploreDeckId: exploreDeckId,
      );

      // Cast upvote on explore deck
      await exploreDao.castVote(
        deckId: exploreDeckId,
        targetVote: 1,
        userId: 'iso_user_1',
      );

      // Update explore deck metadata
      await (db.update(db.exploreDecks)..where((t) => t.id.equals(exploreDeckId))).write(
        const ExploreDecksCompanion(
          description: Value('New community update note'),
          estimatedPrice: Value(99.0),
        ),
      );

      // Personal cloned deck must be completely untouched
      final personalDeck = await (db.select(db.decks)
            ..where((t) => t.id.equals(cloned.id)))
          .getSingle();

      expect(personalDeck.name, equals('Voting Isolation Deck (Copy)'));
      expect(personalDeck.description, isNull);
      expect(personalDeck.sourceExploreDeckId, equals(exploreDeckId));
    });
  });

  // ===========================================================================
  // GROUP 3: VAULT AVAILABILITY LEDGER INVARIANTS (Available = Owned - Allocated)
  // ===========================================================================
  group('3. Vault Availability Ledger Invariants (Available = Owned - Allocated)', () {
    test('Cloning deck with unowned cards synthesizes zero-quantity vault items without corrupting availability', () async {
      // 1. Clean slate for ledger verification
      await (db.delete(db.deckVersionItems)).go();
      await (db.delete(db.deckVersions)).go();
      await (db.delete(db.decks)).go();
      await (db.delete(db.vaultItems)).go();

      final initialAvailability = await vaultDao.watchAllCardAvailability().first;
      expect(initialAvailability, isEmpty);

      const exploreDeckId = 'explore_unowned_deck';
      final now = DateTime.now();

      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: exploreDeckId,
          name: 'Unowned Cards Deck',
          format: 'Modern',
          createdAt: now,
        ),
      );

      // Seed 5 cards completely absent from vault
      for (var i = 1; i <= 5; i++) {
        await db.into(db.exploreDeckItems).insert(
          ExploreDeckItemsCompanion.insert(
            id: 'item_unowned_$i',
            exploreDeckId: exploreDeckId,
            cardName: 'Mythic Rare Card #$i',
            quantity: const Value(2),
            price: const Value(25.0),
          ),
        );
      }

      // 2. Clone deck
      final clonedDeck = await exploreDao.cloneExploreDeckToPersonal(
        exploreDeckId: exploreDeckId,
      );
      expect(clonedDeck.isAssembled, isFalse);

      // 3. Inspect VaultDao.watchAllCardAvailability
      final postCloneAvailability = await vaultDao.watchAllCardAvailability().first;

      // 5 synthesized vault items created
      expect(postCloneAvailability.length, equals(5));

      for (final entry in postCloneAvailability.entries) {
        final avail = entry.value;
        // Invariant: Owned = 0, InDeck = 0, Available = 0
        expect(avail.owned, equals(0), reason: 'Unowned synthesized card must have owned: 0');
        expect(avail.inDeck, equals(0), reason: 'Unowned draft card must have inDeck: 0');
        expect(avail.available, equals(0), reason: 'Available must be 0, never negative');
        expect(avail.owned, equals(avail.available + avail.inDeck),
            reason: 'Ledger invariant Owned = Available + InDeck must hold');
      }
    });

    test('Cloned draft deck does NOT lock pre-owned cards; transitioning to Assembled locks correctly and respects proxies', () async {
      await (db.delete(db.deckVersionItems)).go();
      await (db.delete(db.deckVersions)).go();
      await (db.delete(db.decks)).go();
      await (db.delete(db.vaultItems)).go();

      final now = DateTime.now();

      // 1. Setup pre-owned inventory in Vault
      const cardAId = 'vault_item_card_a'; // Owned: 4
      const cardBId = 'vault_item_card_b'; // Owned: 2, 2 allocated in existing assembled deck
      const cardCId = 'vault_item_card_c'; // Owned: 1

      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: cardAId,
          collectionType: 'mtg',
          name: 'Lightning Bolt',
          setOrSeries: 'M10',
          imageUrl: '',
          acquiredPrice: 1.0,
          acquiredDate: now,
          quantity: const Value(4),
          condition: 'NM',
          currentMarketPrice: 2.0,
          lastPriceUpdate: now,
          dynamicData: '{}',
        ),
      );

      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: cardBId,
          collectionType: 'mtg',
          name: 'Counterspell',
          setOrSeries: 'EMA',
          imageUrl: '',
          acquiredPrice: 1.5,
          acquiredDate: now,
          quantity: const Value(2),
          condition: 'NM',
          currentMarketPrice: 2.0,
          lastPriceUpdate: now,
          dynamicData: '{}',
        ),
      );

      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: cardCId,
          collectionType: 'mtg',
          name: 'Force of Will',
          setOrSeries: 'ALL',
          imageUrl: '',
          acquiredPrice: 80.0,
          acquiredDate: now,
          quantity: const Value(1),
          condition: 'NM',
          currentMarketPrice: 90.0,
          lastPriceUpdate: now,
          dynamicData: '{}',
        ),
      );

      // Existing Assembled Personal Deck allocating 2x Counterspell
      final existingDeckId = const Uuid().v4();
      final existingVersionId = const Uuid().v4();
      await db.into(db.decks).insert(
        DecksCompanion.insert(
          id: existingDeckId,
          name: 'Existing Assembled Deck',
          format: 'Legacy',
          isAssembled: const Value(true), // ASSEMBLED!
          createdAt: now,
        ),
      );
      await db.into(db.deckVersions).insert(
        DeckVersionsCompanion.insert(
          id: existingVersionId,
          deckId: existingDeckId,
          versionNumber: 1,
          isActive: const Value(true), // ACTIVE!
          createdAt: now,
        ),
      );
      await db.into(db.deckVersionItems).insert(
        DeckVersionItemsCompanion.insert(
          id: const Uuid().v4(),
          versionId: existingVersionId,
          vaultItemId: cardBId,
          quantity: const Value(2),
          boardZone: 'Mainboard',
          isProxy: const Value(false), // Physical card locked!
        ),
      );

      // Verify baseline availability
      final baseAvail = await vaultDao.watchAllCardAvailability().first;
      expect(baseAvail[cardAId]!.owned, equals(4));
      expect(baseAvail[cardAId]!.inDeck, equals(0));
      expect(baseAvail[cardAId]!.available, equals(4));

      expect(baseAvail[cardBId]!.owned, equals(2));
      expect(baseAvail[cardBId]!.inDeck, equals(2));
      expect(baseAvail[cardBId]!.available, equals(0));

      expect(baseAvail[cardCId]!.owned, equals(1));
      expect(baseAvail[cardCId]!.inDeck, equals(0));
      expect(baseAvail[cardCId]!.available, equals(1));

      // 2. Seed and Clone an Explore deck
      const exploreDeckId = 'explore_ledger_test';
      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: exploreDeckId,
          name: 'Izzet Control Precon',
          format: 'Legacy',
          createdAt: now,
        ),
      );

      // Explore deck cards:
      // - 2x Lightning Bolt (User owns 4)
      // - 1x Counterspell (User owns 2, but 2 already locked in another assembled deck)
      // - 2x Force of Will (User owns 1, but needed 2 -> partial ownership -> marks isProxy = true)
      // - 1x Brainstorm (Completely unowned -> synthesized quantity 0 -> isProxy = true)
      await db.into(db.exploreDeckItems).insert(
        ExploreDeckItemsCompanion.insert(
          id: 'exp_item_1',
          exploreDeckId: exploreDeckId,
          cardName: 'Lightning Bolt',
          quantity: const Value(2),
        ),
      );
      await db.into(db.exploreDeckItems).insert(
        ExploreDeckItemsCompanion.insert(
          id: 'exp_item_2',
          exploreDeckId: exploreDeckId,
          cardName: 'Counterspell',
          quantity: const Value(1),
        ),
      );
      await db.into(db.exploreDeckItems).insert(
        ExploreDeckItemsCompanion.insert(
          id: 'exp_item_3',
          exploreDeckId: exploreDeckId,
          cardName: 'Force of Will',
          quantity: const Value(2),
        ),
      );
      await db.into(db.exploreDeckItems).insert(
        ExploreDeckItemsCompanion.insert(
          id: 'exp_item_4',
          exploreDeckId: exploreDeckId,
          cardName: 'Brainstorm',
          quantity: const Value(1),
        ),
      );

      // 3. Execute Clone
      final clonedDeck = await exploreDao.cloneExploreDeckToPersonal(
        exploreDeckId: exploreDeckId,
      );

      // 4. INVARIANT CHECK: In Draft state (isAssembled = false), NO physical allocation occurs
      final postCloneDraftAvail = await vaultDao.watchAllCardAvailability().first;

      expect(postCloneDraftAvail[cardAId]!.owned, equals(4));
      expect(postCloneDraftAvail[cardAId]!.inDeck, equals(0),
          reason: 'Draft deck must NOT lock Card A');
      expect(postCloneDraftAvail[cardAId]!.available, equals(4));

      expect(postCloneDraftAvail[cardBId]!.owned, equals(2));
      expect(postCloneDraftAvail[cardBId]!.inDeck, equals(2),
          reason: 'Card B inDeck must remain 2 from pre-existing deck');
      expect(postCloneDraftAvail[cardBId]!.available, equals(0));

      expect(postCloneDraftAvail[cardCId]!.owned, equals(1));
      expect(postCloneDraftAvail[cardCId]!.inDeck, equals(0));
      expect(postCloneDraftAvail[cardCId]!.available, equals(1));

      // Synthesized Brainstorm
      final brainstormVaultItem = await (db.select(db.vaultItems)
            ..where((t) => t.name.equals('Brainstorm')))
          .getSingle();
      expect(postCloneDraftAvail[brainstormVaultItem.id]!.owned, equals(0));
      expect(postCloneDraftAvail[brainstormVaultItem.id]!.inDeck, equals(0));
      expect(postCloneDraftAvail[brainstormVaultItem.id]!.available, equals(0));

      // 5. Transition cloned deck to Assembled state (isAssembled = true)
      await (db.update(db.decks)..where((t) => t.id.equals(clonedDeck.id))).write(
        const DecksCompanion(isAssembled: Value(true)),
      );

      final assembledAvail = await vaultDao.watchAllCardAvailability().first;

      // Card A (Lightning Bolt): 2 copies now locked by cloned deck!
      // Owned: 4, inDeck: 2, Available: 2
      expect(assembledAvail[cardAId]!.owned, equals(4));
      expect(assembledAvail[cardAId]!.inDeck, equals(2));
      expect(assembledAvail[cardAId]!.available, equals(2));

      // Card C (Force of Will): needed 2, owned was 1, so clone marked isProxy = true!
      // Invariant: Proxies are excluded from physical allocation!
      // inDeck: 0, available: 1, owned: 1
      expect(assembledAvail[cardCId]!.owned, equals(1));
      expect(assembledAvail[cardCId]!.inDeck, equals(0));
      expect(assembledAvail[cardCId]!.available, equals(1));

      // Brainstorm: unowned proxy!
      // inDeck: 0, available: 0, owned: 0
      expect(assembledAvail[brainstormVaultItem.id]!.owned, equals(0));
      expect(assembledAvail[brainstormVaultItem.id]!.inDeck, equals(0));
      expect(assembledAvail[brainstormVaultItem.id]!.available, equals(0));

      // 6. Transition back to Draft: physical lock releases immediately!
      await (db.update(db.decks)..where((t) => t.id.equals(clonedDeck.id))).write(
        const DecksCompanion(isAssembled: Value(false)),
      );

      final returnedDraftAvail = await vaultDao.watchAllCardAvailability().first;
      expect(returnedDraftAvail[cardAId]!.inDeck, equals(0));
      expect(returnedDraftAvail[cardAId]!.available, equals(4));
    });
  });

  // ===========================================================================
  // GROUP 4: HIGH-CONCURRENCY MULTI-DECK & SAME-DECK STRESS
  // ===========================================================================
  group('4. High-Concurrency Multi-Deck & Same-Deck Stress', () {
    test('Concurrently cloning 4 distinct explore decks with overlapping cards succeeds without locks', () async {
      final now = DateTime.now();

      // Seed 4 distinct explore decks
      final exploreDeckIds = <String>[];
      for (var d = 1; d <= 4; d++) {
        final id = 'concurrent_explore_deck_$d';
        exploreDeckIds.add(id);

        await db.into(db.exploreDecks).insert(
          ExploreDecksCompanion.insert(
            id: id,
            name: 'Concurrent Deck #$d',
            format: 'Commander',
            createdAt: now,
          ),
        );

        // All 4 decks share common cards: Sol Ring, Command Tower, and Arcane Signet
        await db.into(db.exploreDeckItems).insert(
          ExploreDeckItemsCompanion.insert(
            id: 'con_item_${d}_sol',
            exploreDeckId: id,
            cardName: 'Sol Ring',
            scryfallId: const Value('shared-scryfall-sol-ring'),
            quantity: const Value(1),
          ),
        );
        await db.into(db.exploreDeckItems).insert(
          ExploreDeckItemsCompanion.insert(
            id: 'con_item_${d}_tower',
            exploreDeckId: id,
            cardName: 'Command Tower',
            scryfallId: const Value('shared-scryfall-command-tower'),
            quantity: const Value(1),
          ),
        );
        await db.into(db.exploreDeckItems).insert(
          ExploreDeckItemsCompanion.insert(
            id: 'con_item_${d}_signet',
            exploreDeckId: id,
            cardName: 'Arcane Signet',
            scryfallId: const Value('shared-scryfall-arcane-signet'),
            quantity: const Value(1),
          ),
        );

        // Deck-specific cards
        for (var c = 1; c <= 5; c++) {
          await db.into(db.exploreDeckItems).insert(
            ExploreDeckItemsCompanion.insert(
              id: 'con_item_${d}_specific_$c',
              exploreDeckId: id,
              cardName: 'Specific Card D${d}_$c',
              quantity: const Value(1),
            ),
          );
        }
      }

      // Concurrently execute cloning across all 4 decks
      final cloneFutures = exploreDeckIds.map(
        (id) => exploreDao.cloneExploreDeckToPersonal(exploreDeckId: id),
      );

      final clonedDecks = await Future.wait(cloneFutures);

      expect(clonedDecks.length, equals(4));

      // All 4 cloned decks have distinct IDs
      final deckIds = clonedDecks.map((d) => d.id).toSet();
      expect(deckIds.length, equals(4));

      // Verify each cloned deck has 8 deck_version_items (3 shared + 5 specific)
      for (final personalDeck in clonedDecks) {
        expect(personalDeck.isCloned, isTrue);

        final versions = await (db.select(db.deckVersions)
              ..where((t) => t.deckId.equals(personalDeck.id)))
            .get();
        expect(versions.length, equals(1));

        final items = await (db.select(db.deckVersionItems)
              ..where((t) => t.versionId.equals(versions.first.id)))
            .get();
        expect(items.length, equals(8));
      }

      // Verify shared cards in vault_items were not duplicated into duplicate rows
      final solRings = await (db.select(db.vaultItems)
            ..where((t) => t.name.equals('Sol Ring')))
          .get();
      expect(solRings.length, equals(1),
          reason: 'Shared Sol Ring must resolve to a single catalog vault item');

      final commandTowers = await (db.select(db.vaultItems)
            ..where((t) => t.name.equals('Command Tower')))
          .get();
      expect(commandTowers.length, equals(1),
          reason: 'Shared Command Tower must resolve to a single catalog vault item');
    });

    test('Rapid concurrent cloning of the SAME deck (10 concurrent requests) produces 10 isolated decks', () async {
      const exploreDeckId = 'explore_rapid_clone_deck';
      final now = DateTime.now();

      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: exploreDeckId,
          name: 'Rapid Fire Brew',
          format: 'Pauper',
          createdAt: now,
        ),
      );

      for (var i = 1; i <= 10; i++) {
        await db.into(db.exploreDeckItems).insert(
          ExploreDeckItemsCompanion.insert(
            id: 'rapid_item_$i',
            exploreDeckId: exploreDeckId,
            cardName: 'Pauper Common #$i',
            quantity: const Value(1),
          ),
        );
      }

      // Fire 10 simultaneous clone requests for the same deck
      final cloneFutures = List.generate(
        10,
        (_) => exploreDao.cloneExploreDeckToPersonal(exploreDeckId: exploreDeckId),
      );

      final clonedDecks = await Future.wait(cloneFutures);

      expect(clonedDecks.length, equals(10));

      final uniqueDeckIds = clonedDecks.map((d) => d.id).toSet();
      expect(uniqueDeckIds.length, equals(10),
          reason: 'All 10 rapid clone operations must generate unique deck IDs');

      // Check all 10 decks have 10 items
      for (final deck in clonedDecks) {
        expect(deck.name, equals('Rapid Fire Brew (Copy)'));
        expect(deck.isCloned, isTrue);

        final versions = await (db.select(db.deckVersions)
              ..where((t) => t.deckId.equals(deck.id)))
            .get();
        expect(versions.length, equals(1));

        final items = await (db.select(db.deckVersionItems)
              ..where((t) => t.versionId.equals(versions.first.id)))
            .get();
        expect(items.length, equals(10));
      }
    });
  });

  // ===========================================================================
  // GROUP 5: EDGE CASE DECKS (NO COMMANDER, EMPTY, SPECIAL CHARACTERS)
  // ===========================================================================
  group('5. Edge Case Decks (No Commander, Empty, Special Characters)', () {
    test('Standard deck without commander clones cleanly with coverItemId = null', () async {
      const exploreDeckId = 'explore_standard_no_cmd';
      final now = DateTime.now();

      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: exploreDeckId,
          name: 'Mono Red Aggro Standard',
          format: 'Standard',
          commanderName: const Value(null),
          createdAt: now,
        ),
      );

      await db.into(db.exploreDeckItems).insert(
        ExploreDeckItemsCompanion.insert(
          id: 'std_item_1',
          exploreDeckId: exploreDeckId,
          cardName: 'Monastery Swiftspear',
          quantity: const Value(4),
          boardZone: const Value('Mainboard'),
          isCommander: const Value(false),
        ),
      );

      final cloned = await exploreDao.cloneExploreDeckToPersonal(
        exploreDeckId: exploreDeckId,
      );

      expect(cloned.coverItemId, isNull);
      expect(cloned.format, equals('Standard'));
      expect(cloned.isCloned, isTrue);

      final versions = await (db.select(db.deckVersions)
            ..where((t) => t.deckId.equals(cloned.id)))
          .get();
      expect(versions.length, equals(1));
      final items = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals(versions.first.id)))
          .get();
      expect(items.length, equals(1));
      expect(items.first.quantity, equals(4));
    });

    test('Deck with 0 items clones without error', () async {
      const exploreDeckId = 'explore_empty_deck';
      final now = DateTime.now();

      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: exploreDeckId,
          name: 'Empty Explore Shell',
          format: 'Modern',
          cardCount: const Value(0),
          createdAt: now,
        ),
      );

      final cloned = await exploreDao.cloneExploreDeckToPersonal(
        exploreDeckId: exploreDeckId,
      );

      expect(cloned.isCloned, isTrue);
      expect(cloned.coverItemId, isNull);

      final versions = await (db.select(db.deckVersions)
            ..where((t) => t.deckId.equals(cloned.id)))
          .get();
      expect(versions.length, equals(1));

      final items = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals(versions.first.id)))
          .get();
      expect(items, isEmpty);
    });

    test('Special characters, quotes, and punctuation in card names clone faithfully', () async {
      const exploreDeckId = 'explore_special_chars';
      final now = DateTime.now();

      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: exploreDeckId,
          name: 'Complex Names Deck',
          format: 'Legacy',
          createdAt: now,
        ),
      );

      const complexNames = [
        "Lim-Dûl's Vault",
        'Kongming, "Sleeping Dragon"',
        'Question Elemental?',
        'Fire // Ice',
        'Who/What/When/Where/Why',
      ];

      for (var i = 0; i < complexNames.length; i++) {
        await db.into(db.exploreDeckItems).insert(
          ExploreDeckItemsCompanion.insert(
            id: 'item_special_$i',
            exploreDeckId: exploreDeckId,
            cardName: complexNames[i],
            quantity: const Value(1),
          ),
        );
      }

      final cloned = await exploreDao.cloneExploreDeckToPersonal(
        exploreDeckId: exploreDeckId,
      );

      final v1 = (await (db.select(db.deckVersions)
            ..where((t) => t.deckId.equals(cloned.id)))
          .get())
          .first;

      final versionItems = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals(v1.id)))
          .get();
      expect(versionItems.length, equals(complexNames.length));

      // Verify each card name exists faithfully in vault_items
      for (final expectedName in complexNames) {
        final vaultItem = await (db.select(db.vaultItems)
              ..where((t) => t.name.equals(expectedName)))
            .getSingleOrNull();
        expect(vaultItem, isNotNull,
            reason: 'Card name with special characters must be preserved: $expectedName');
      }
    });

    test('Multiple items with same card name in different board zones (Mainboard and Sideboard) clone accurately', () async {
      const exploreDeckId = 'explore_split_zones';
      final now = DateTime.now();

      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: exploreDeckId,
          name: 'Split Zone Deck',
          format: 'Modern',
          createdAt: now,
        ),
      );

      // 3x Veil of Summer in Mainboard
      await db.into(db.exploreDeckItems).insert(
        ExploreDeckItemsCompanion.insert(
          id: 'veil_main',
          exploreDeckId: exploreDeckId,
          cardName: 'Veil of Summer',
          quantity: const Value(3),
          boardZone: const Value('Mainboard'),
        ),
      );

      // 1x Veil of Summer in Sideboard
      await db.into(db.exploreDeckItems).insert(
        ExploreDeckItemsCompanion.insert(
          id: 'veil_side',
          exploreDeckId: exploreDeckId,
          cardName: 'Veil of Summer',
          quantity: const Value(1),
          boardZone: const Value('Sideboard'),
        ),
      );

      final cloned = await exploreDao.cloneExploreDeckToPersonal(
        exploreDeckId: exploreDeckId,
      );

      final v1 = (await (db.select(db.deckVersions)
            ..where((t) => t.deckId.equals(cloned.id)))
          .get())
          .first;

      final versionItems = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals(v1.id)))
          .get();

      expect(versionItems.length, equals(2));

      final mainItem = versionItems.firstWhere((i) => i.boardZone == 'Mainboard');
      final sideItem = versionItems.firstWhere((i) => i.boardZone == 'Sideboard');

      expect(mainItem.quantity, equals(3));
      expect(sideItem.quantity, equals(1));
      expect(mainItem.vaultItemId, equals(sideItem.vaultItemId),
          reason: 'Both zones must reference the same underlying vault item');
    });
  });

  // ===========================================================================
  // GROUP 6: READONLYDECKSCREEN UI CLONE ENGINE INTEGRATION
  // ===========================================================================
  group('6. ReadOnlyDeckScreen UI Clone Engine Integration', () {
    testWidgets('Tapping clone button from UI triggers clone engine and maintains UI invariants',
        (tester) async {
      const exploreDeckId = 'ui_explore_clone_deck';
      final now = DateTime.now();

      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: exploreDeckId,
          name: 'Interactive UI Clone Deck',
          format: 'Commander',
          creatorName: const Value('@ProBrewMaster'),
          score: const Value(75),
          cardCount: const Value(100),
          estimatedPrice: const Value(150.0),
          createdAt: now,
        ),
      );

      await db.into(db.exploreDeckItems).insert(
        ExploreDeckItemsCompanion.insert(
          id: 'ui_item_cmd',
          exploreDeckId: exploreDeckId,
          cardName: 'Atraxa, Praetors Voice',
          quantity: const Value(1),
          boardZone: const Value('Commander'),
          isCommander: const Value(true),
        ),
      );

      await tester.pumpWidget(
        buildSubject(
          child: ReadOnlyDeckScreen(
            exploreDeckId: exploreDeckId,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify clone button exists
      final cloneButton = find.byKey(const Key('explore_clone_deck_button'));
      expect(cloneButton, findsOneWidget);

      // Tap clone button
      await tester.tap(cloneButton);
      await tester.pumpAndSettle();

      // Confirms SnackBar
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Cloned "Interactive UI Clone Deck" to My Decks!'), findsOneWidget);

      // Confirms cloned deck created in SQLite
      final personalDecks = await (db.select(db.decks)
            ..where((t) => t.sourceExploreDeckId.equals(exploreDeckId)))
          .get();
      expect(personalDecks.length, equals(1));
      expect(personalDecks.first.isCloned, isTrue);
      expect(personalDecks.first.name, equals('Interactive UI Clone Deck (Copy)'));

      // Confirms ReadOnlyDeckScreen is still visible and maintains its read-only presentation
      expect(find.byKey(const Key('read_only_deck_screen')), findsOneWidget);
      expect(find.text('Add Card'), findsNothing);
      expect(find.text('Edit Deck'), findsNothing);
    });
  });
}
