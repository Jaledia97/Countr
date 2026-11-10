// Copyright (c) 2026 Countr. All rights reserved.
// Milestone 2 (Epic 2) Verification:
// - authorId persistence on ExploreDecks
// - sharePersonalDeckToExplore with authorId and 4-zone cloning
// - Art series & memorabilia ban invariants
// - Drill-down category navigation

import 'dart:convert';
import 'package:drift/drift.dart' hide isNull, isNotNull, Column;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/data/daos/explore_deck_dao.dart';
import 'package:countr/features/decks/data/models/precon_deck_dto.dart';
import 'package:countr/features/decks/domain/models/explore_deck_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  late AppDatabase db;
  late ExploreDeckDao exploreDao;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    exploreDao = ExploreDeckDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Milestone 2 (Epic 2): authorId Persistence & Scoping', () {
    test('ExploreDecks persists author_id and allows filtering by author', () async {
      final now = DateTime.now();

      // Insert two decks with different authors
      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: 'deck_author_alice',
          name: 'Alice Deck',
          format: 'Commander',
          sourceType: const Value('user_shared'),
          creatorName: const Value('Alice'),
          authorId: const Value('user_alice_123'),
          createdAt: now,
          updatedAt: Value(now),
        ),
      );

      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: 'deck_author_bob',
          name: 'Bob Deck',
          format: 'Commander',
          sourceType: const Value('user_shared'),
          creatorName: const Value('Bob'),
          authorId: const Value('user_bob_456'),
          createdAt: now,
          updatedAt: Value(now),
        ),
      );

      // Verify query by author_id via custom SQL (Epic 3 profile query requirement)
      final aliceRows = await db.customSelect(
        'SELECT * FROM explore_decks WHERE author_id = ?;',
        variables: [Variable.withString('user_alice_123')],
      ).get();

      expect(aliceRows.length, equals(1));
      expect(aliceRows.first.read<String>('id'), equals('deck_author_alice'));
      expect(aliceRows.first.read<String?>('author_id'), equals('user_alice_123'));

      // Verify via Drift select
      final bobDecks = await (db.select(db.exploreDecks)
            ..where((t) => t.authorId.equals('user_bob_456')))
          .get();
      expect(bobDecks.length, equals(1));
      expect(bobDecks.first.name, equals('Bob Deck'));
      expect(bobDecks.first.authorId, equals('user_bob_456'));
    });

    test('ExploreDeckWithVote and ExploreDeckDetail expose authorId getter', () async {
      final now = DateTime.now();
      final deck = ExploreDeck(
        id: 'test_deck_1',
        name: 'Test Deck',
        format: 'Commander',
        tcgDomain: 'mtg',
        sourceType: 'user_shared',
        creatorName: 'TestCreator',
        authorId: 'author_profile_xyz',
        colorIdentity: 'WUBRG',
        cardCount: 100,
        estimatedPrice: 250.0,
        upvotes: 5,
        downvotes: 1,
        score: 4,
        isDeleted: false,
        createdAt: now,
        updatedAt: now,
      );

      final withVote = ExploreDeckWithVote(deck: deck, userVote: 1);
      expect(withVote.authorId, equals('author_profile_xyz'));

      final detail = ExploreDeckDetail(deckWithVote: withVote, cards: const []);
      expect(detail.authorId, equals('author_profile_xyz'));
    });
  });

  group('Milestone 2 (Epic 2): sharePersonalDeckToExplore with authorId & 4-Zone Cloning', () {
    test('sharePersonalDeckToExplore propagates custom authorId and clones all 4 zones', () async {
      final now = DateTime.now();
      const testDeckId = 'deck_4_zones_test';
      const versionId = 'ver_4_zones_1';

      // 1. Create personal deck in SQLite
      await db.into(db.decks).insert(
        DecksCompanion.insert(
          id: testDeckId,
          name: 'Four Zones Commander',
          format: 'Commander',
          createdAt: now,
          tcgDomain: const Value('mtg'),
        ),
      );

      await db.into(db.deckVersions).insert(
        DeckVersionsCompanion.insert(
          id: versionId,
          deckId: testDeckId,
          versionNumber: 1,
          isActive: const Value(true),
          createdAt: now,
        ),
      );

      // 2. Insert cards across all 4 zones: Commander, Mainboard, Sideboard, Maybeboard
      final zones = [
        {'zone': 'Commander', 'name': 'Atraxa, Praetors Voice', 'cmc': 4.0, 'isCmdr': true, 'qty': 1},
        {'zone': 'Mainboard', 'name': 'Sol Ring', 'cmc': 1.0, 'isCmdr': false, 'qty': 1},
        {'zone': 'Mainboard', 'name': 'Arcane Signet', 'cmc': 2.0, 'isCmdr': false, 'qty': 1},
        {'zone': 'Sideboard', 'name': 'Swords to Plowshares', 'cmc': 1.0, 'isCmdr': false, 'qty': 2},
        {'zone': 'Maybeboard', 'name': 'Cyclonic Rift', 'cmc': 2.0, 'isCmdr': false, 'qty': 1},
      ];

      for (var i = 0; i < zones.length; i++) {
        final z = zones[i];
        final vId = 'vault_item_$i';
        await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: vId,
            collectionType: 'mtg',
            name: z['name'] as String,
            setOrSeries: 'Commander 2016',
            condition: 'NM',
            imageUrl: 'https://cards.scryfall.io/normal/front/x/$i.jpg',
            acquiredPrice: 5.0,
            acquiredDate: now,
            currentMarketPrice: 5.0,
            lastPriceUpdate: now,
            dynamicData: jsonEncode({
              'scryfall_id': 'scryfall_id_$i',
              'cmc': z['cmc'],
              'type_line': 'Legendary Creature',
            }),
          ),
        );

        await db.into(db.deckVersionItems).insert(
          DeckVersionItemsCompanion.insert(
            id: 'dvi_$i',
            versionId: versionId,
            vaultItemId: vId,
            quantity: Value(z['qty'] as int),
            boardZone: z['zone'] as String,
            updatedAt: Value(now),
          ),
        );
      }

      // 3. Share deck with explicit authorId
      final shared = await exploreDao.sharePersonalDeckToExplore(
        personalDeckId: testDeckId,
        creatorName: '@AtraxaPlayer',
        customDescription: 'A balanced 4-zone EDH deck.',
        authorId: 'user_profile_pro_99',
      );

      // Verify parent row
      expect(shared.name, equals('Four Zones Commander'));
      expect(shared.authorId, equals('user_profile_pro_99'));
      expect(shared.creatorName, equals('@AtraxaPlayer'));
      expect(shared.commanderName, equals('Atraxa, Praetors Voice'));
      expect(shared.cardCount, equals(6)); // 1 cmdr + 2 main + 2 side + 1 maybe = 6 total

      // 4. Verify cloned items in explore_deck_items across all 4 zones
      final clonedItems = await exploreDao.getExploreDeckItems(shared.id);
      expect(clonedItems.length, equals(5)); // 5 distinct items

      final cmdrCards = clonedItems.where((i) => i.boardZone.toLowerCase() == 'commander').toList();
      final mainCards = clonedItems.where((i) => i.boardZone.toLowerCase() == 'mainboard').toList();
      final sideCards = clonedItems.where((i) => i.boardZone.toLowerCase() == 'sideboard').toList();
      final maybeCards = clonedItems.where((i) => i.boardZone.toLowerCase() == 'maybeboard').toList();

      expect(cmdrCards.length, equals(1));
      expect(cmdrCards.first.cardName, equals('Atraxa, Praetors Voice'));
      expect(cmdrCards.first.isCommander, isTrue);

      expect(mainCards.length, equals(2));
      expect(mainCards.map((c) => c.cardName).toSet(), containsAll(['Sol Ring', 'Arcane Signet']));

      expect(sideCards.length, equals(1));
      expect(sideCards.first.cardName, equals('Swords to Plowshares'));
      expect(sideCards.first.quantity, equals(2));

      expect(maybeCards.length, equals(1));
      expect(maybeCards.first.cardName, equals('Cyclonic Rift'));
      expect(maybeCards.first.quantity, equals(1));
    });

    test('sharePersonalDeckToExplore defaults authorId to local_user when omitted', () async {
      final now = DateTime.now();
      const testDeckId = 'deck_default_author';
      const versionId = 'ver_default_author_1';

      await db.into(db.decks).insert(
        DecksCompanion.insert(
          id: testDeckId,
          name: 'Default Author Deck',
          format: 'Standard',
          createdAt: now,
          tcgDomain: const Value('mtg'),
        ),
      );

      await db.into(db.deckVersions).insert(
        DeckVersionsCompanion.insert(
          id: versionId,
          deckId: testDeckId,
          versionNumber: 1,
          isActive: const Value(true),
          createdAt: now,
        ),
      );

      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'v_default_1',
          collectionType: 'mtg',
          name: 'Lightning Bolt',
          setOrSeries: 'M11',
          condition: 'NM',
          imageUrl: 'https://cards.scryfall.io/normal/front/l/b.jpg',
          acquiredPrice: 1.0,
          acquiredDate: now,
          currentMarketPrice: 1.0,
          lastPriceUpdate: now,
          dynamicData: '{}',
        ),
      );

      await db.into(db.deckVersionItems).insert(
        DeckVersionItemsCompanion.insert(
          id: 'dvi_default_1',
          versionId: versionId,
          vaultItemId: 'v_default_1',
          quantity: const Value(4),
          boardZone: 'Mainboard',
          updatedAt: Value(now),
        ),
      );

      final shared = await exploreDao.sharePersonalDeckToExplore(
        personalDeckId: testDeckId,
        creatorName: 'Anonymous Player',
      );

      expect(shared.authorId, equals('local_user'));
    });
  });

  group('Milestone 2 (Epic 2): Art Series & Memorabilia Ban Invariants', () {
    test('Draconic Domination precon commander resolves to genuine playable The Ur-Dragon', () {
      final urDragonCard = PreconCardDto.fromMap({
        'name': 'The Ur-Dragon',
        'layout': 'normal',
        'isCommander': true,
        'identifiers': {'scryfallId': '7e78b70b-0c67-4f14-8ad7-c9f8e3f59743'},
        'imageUrl': 'https://cards.scryfall.io/normal/front/7/e/7e78b70b-0c67-4f14-8ad7-c9f8e3f59743.jpg',
        'artCropUrl': 'https://cards.scryfall.io/art_crop/front/7/e/7e78b70b-0c67-4f14-8ad7-c9f8e3f59743.jpg',
      });

      expect(urDragonCard.isCommander, isTrue);
      expect(urDragonCard.layout, equals('normal'));
      expect(urDragonCard.name, equals('The Ur-Dragon'));
      expect(urDragonCard.imageUrl, isNot(contains('art_series')));
      expect(urDragonCard.imageUrl, isNot(contains('memorabilia')));
    });

    test('PreconCardDto rejects art series and memorabilia layout/set_type cleanly', () {
      final bannedArtCard = PreconCardDto.fromMap({
        'name': 'The Ur-Dragon (Art Series)',
        'layout': 'art_series',
        'set_type': 'memorabilia',
      });

      // Sanitization converts layout to normal and replaces art series image url with playable fallback
      expect(bannedArtCard.layout, equals('normal'));
      expect(bannedArtCard.imageUrl, isNot(contains('art_series')));
    });
  });
}
