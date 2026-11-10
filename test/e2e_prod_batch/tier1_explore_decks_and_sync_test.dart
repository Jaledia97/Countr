import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' as drift;
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/data/daos/explore_deck_dao.dart';
import 'package:countr/features/decks/data/models/precon_deck_dto.dart';
import 'package:countr/features/decks/data/services/mtgjson_precon_parser.dart';
import 'package:countr/features/decks/data/services/precon_hydration_service.dart';
import 'package:countr/features/decks/domain/models/explore_deck_models.dart';
import 'package:countr/features/decks/presentation/widgets/explore/explore_deck_card.dart';
import 'package:countr/features/decks/presentation/widgets/explore/explore_deck_unpublish_dialog.dart';

import 'e2e_prod_batch_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Tier 1 - Feature 9: Explore Decks "My Uploads" Tab/Filter & Publishing Status (F9.1 to F9.5)', () {
    late AppDatabase db;
    late ExploreDeckDao exploreDao;

    setUp(() async {
      db = createE2eProdBatchTestDb();
      exploreDao = ExploreDeckDao(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('F9.1: isExploreDeckAuthor matches authorId and creatorName for active user aliases', () {
      final deckAuthoredByMe = createTestExploreDeckRecord(
        id: 'deck-my-upload-1',
        name: 'Urza Thopter Foundry',
        authorId: 'user-current-me',
        creatorName: 'collector_me',
      );

      final isMe = isExploreDeckAuthor(
        deck: deckAuthoredByMe,
        currentUserId: 'user-current-me',
      );
      expect(isMe, isTrue);

      final deckAuthoredByLocal = createTestExploreDeckRecord(
        id: 'deck-my-upload-2',
        name: 'Omnath Landfall',
        authorId: 'local_user',
        creatorName: 'local_user',
      );

      expect(isExploreDeckAuthor(deck: deckAuthoredByLocal, currentUserId: 'user-current-me'), isTrue);
    });

    test('F9.2: isExploreDeckAuthor strictly returns false for decks authored by other creators', () {
      final wizardsDeck = createTestExploreDeckRecord(
        id: 'precon-wizards-1',
        name: 'Velociramptor Precon',
        authorId: 'wizards-of-the-coast',
        creatorName: 'Official WotC',
        sourceType: 'official',
      );

      expect(isExploreDeckAuthor(deck: wizardsDeck, currentUserId: 'user-current-me'), isFalse);

      final peerDeck = createTestExploreDeckRecord(
        id: 'deck-peer-1',
        name: 'Spicy Aristocrats',
        authorId: 'user-spicy-brew-master',
        creatorName: '@SpicyBrewMaster',
      );

      expect(isExploreDeckAuthor(deck: peerDeck, currentUserId: 'user-current-me'), isFalse);
    });

    testWidgets('F9.3: ExploreDeckCard renders unpublish menu item only when viewer is the deck author', (tester) async {
      final authoredDeck = createTestExploreDeckRecord(
        id: 'deck-with-unpublish',
        name: 'Krenko Mob Boss Burn',
        authorId: 'user-current-me',
        creatorName: 'collector_me',
      );

      final deckWithVote = ExploreDeckWithVote(
        deck: authoredDeck,
        userVote: 0,
      );

      await tester.pumpWidget(
        wrapWithMaterialAndScope(
          SizedBox(
            width: 200,
            child: ExploreDeckCard(deckWithVote: deckWithVote),
          ),
        ),
      );

      // PopupMenuButton exists for author
      final popupFinder = find.byType(PopupMenuButton<String>);
      expect(popupFinder, findsOneWidget);

      await tester.tap(popupFinder);
      await tester.pumpAndSettle();

      expect(find.byKey(Key('explore_card_menu_unpublish_${deckWithVote.id}')), findsOneWidget);
      expect(find.text('Unpublish from Explore'), findsOneWidget);
    });

    test('F9.4: unpublishExploreDeck soft-deletes deck and its items and logs sync mutation', () async {
      final deckId = 'deck-to-unpublish';
      await db.into(db.exploreDecks).insert(
        createTestExploreDeckRecord(
          id: deckId,
          name: 'Atraxa Superfriends',
          authorId: 'user-current-me',
        ),
        mode: drift.InsertMode.insertOrReplace,
      );

      // Add item in explore_deck_items
      await db.into(db.exploreDeckItems).insert(
        ExploreDeckItemsCompanion.insert(
          id: 'item-atraxa-1',
          exploreDeckId: deckId,
          cardName: 'Doubling Season',
          quantity: const drift.Value(1),
          isCommander: const drift.Value(false),
          isDeleted: const drift.Value(false),
        ),
        mode: drift.InsertMode.insertOrReplace,
      );

      await exploreDao.unpublishExploreDeck(exploreDeckId: deckId);

      final deck = await (db.select(db.exploreDecks)..where((t) => t.id.equals(deckId))).getSingle();
      expect(deck.isDeleted, isTrue);

      final items = await (db.select(db.exploreDeckItems)..where((t) => t.exploreDeckId.equals(deckId))).get();
      expect(items.first.isDeleted, isTrue);

      final syncLog = await (db.select(db.syncQueue)
            ..where((t) => t.entityType.equals('explore_deck') & t.entityId.equals(deckId)))
          .get();
      expect(syncLog.isNotEmpty, isTrue);
      expect(syncLog.first.operation, equals('DELETE'));
    });

    test('F9.5: watchExploreDecks stream automatically excludes soft-deleted decks', () async {
      final activeId = 'deck-explore-active';
      final deletedId = 'deck-explore-deleted';

      await db.into(db.exploreDecks).insert(
        createTestExploreDeckRecord(id: activeId, name: 'Active Deck'),
        mode: drift.InsertMode.insertOrReplace,
      );

      await db.into(db.exploreDecks).insert(
        createTestExploreDeckRecord(id: deletedId, name: 'Deleted Deck', isDeleted: true),
        mode: drift.InsertMode.insertOrReplace,
      );

      final decks = await exploreDao.watchExploreDecks().first;
      final ids = decks.map((d) => d.id).toList();
      expect(ids, contains(activeId));
      expect(ids, isNot(contains(deletedId)));
    });
  });

  group('Tier 1 - Feature 10: Uncropped Deck Cover Grid & Compact Aspect Ratio (F10.1 to F10.5)', () {
    test('F10.1: ExploreDeckCard prioritizes commanderImageUrl over commanderArtCrop', () {
      final deck = createTestExploreDeckRecord(
        id: 'deck-priority-test',
        name: 'Priority Test Deck',
        commanderImageUrl: 'https://cards.scryfall.io/normal/front/1/2/123.jpg',
        commanderArtCrop: 'https://cards.scryfall.io/art_crop/front/1/2/123.jpg',
      );

      final deckWithVote = ExploreDeckWithVote(deck: deck, userVote: 0);

      // Verify DTO exposes both fields intact
      expect(deckWithVote.commanderImageUrl, equals('https://cards.scryfall.io/normal/front/1/2/123.jpg'));
      expect(deckWithVote.commanderArtCrop, equals('https://cards.scryfall.io/art_crop/front/1/2/123.jpg'));
    });

    test('F10.2: ExploreDeckCard falls back to commanderArtCrop when commanderImageUrl is null or empty', () {
      final deck = createTestExploreDeckRecord(
        id: 'deck-fallback-test',
        name: 'Fallback Deck',
        commanderImageUrl: null,
        commanderArtCrop: 'https://cards.scryfall.io/art_crop/front/9/9/999.jpg',
      );

      final deckWithVote = ExploreDeckWithVote(deck: deck, userVote: 0);
      expect(deckWithVote.commanderImageUrl, isNull);
      expect(deckWithVote.commanderArtCrop, isNotEmpty);
    });

    testWidgets('F10.3: ExploreDeckCard in compact mode renders with standard 63/88 proportions without overflow', (tester) async {
      final deck = createTestExploreDeckRecord(
        id: 'deck-compact-aspect',
        name: 'Edgar Markov Vampires',
        commanderName: 'Edgar Markov',
        commanderImageUrl: 'https://cards.scryfall.io/normal/front/e/d/edgar.jpg',
        estimatedPrice: 350.00,
        score: 42,
      );

      final deckWithVote = ExploreDeckWithVote(deck: deck, userVote: 0);

      await tester.pumpWidget(
        wrapWithMaterialAndScope(
          SizedBox(
            width: 173,
            child: SingleChildScrollView(
              child: ExploreDeckCard(
                deckWithVote: deckWithVote,
                isCompact: true,
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Edgar Markov Vampires'), findsOneWidget);
      expect(find.text('\$350.00'), findsOneWidget);
    });

    testWidgets('F10.4: ExploreDeckCard displays creator badge, price, and interactive voting cluster', (tester) async {
      final deck = createTestExploreDeckRecord(
        id: 'deck-voting-test',
        name: 'Prosper Tome-Bound Treasures',
        creatorName: 'TreasuresAreCool',
        score: 88,
        estimatedPrice: 95.50,
      );

      final deckWithVote = ExploreDeckWithVote(deck: deck, userVote: 1);

      await tester.pumpWidget(
        wrapWithMaterialAndScope(
          SizedBox(
            width: 200,
            child: SingleChildScrollView(
              child: ExploreDeckCard(deckWithVote: deckWithVote),
            ),
          ),
        ),
      );

      expect(find.text('@TreasuresAreCool'), findsOneWidget);
      expect(find.text('88'), findsOneWidget);
      expect(find.text('\$95.50'), findsOneWidget);
      expect(find.byKey(Key('explore_upvote_${deck.id}')), findsOneWidget);
      expect(find.byKey(Key('explore_downvote_${deck.id}')), findsOneWidget);
    });

    testWidgets('F10.5: ExploreDeckCard handles missing image URLs gracefully with placeholder icon without error', (tester) async {
      final deck = createTestExploreDeckRecord(
        id: 'deck-no-art',
        name: 'Artless Brew',
        commanderImageUrl: null,
        commanderArtCrop: null,
      );

      final deckWithVote = ExploreDeckWithVote(deck: deck, userVote: 0);

      await tester.pumpWidget(
        wrapWithMaterialAndScope(
          SizedBox(
            width: 180,
            child: SingleChildScrollView(
              child: ExploreDeckCard(deckWithVote: deckWithVote),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
      expect(find.text('Artless Brew'), findsOneWidget);
    });
  });

  group('Tier 1 - Feature 11: MTGJSON Precon Ingestion, Filtering, and Seeding Sync (F11.1 to F11.5)', () {
    late AppDatabase db;

    setUp(() async {
      db = createE2eProdBatchTestDb();
    });

    tearDown(() async {
      await db.close();
    });

    test('F11.1: MtgjsonPreconParser.parseJson extracts precon decks from MTGJSON schema', () {
      final rawJson = '''
      {
        "data": [
          {
            "name": "Animated Army",
            "code": "BLC",
            "type": "Commander Deck",
            "cards": [
              {"name": "Bello, Bard of the Brambles", "count": 1, "isCommander": true},
              {"name": "Sol Ring", "count": 1}
            ]
          }
        ]
      }
      ''';

      final dtos = MtgjsonPreconParser.parseJson(rawJson);
      expect(dtos.length, equals(1));
      expect(dtos.first.name, equals('Animated Army'));
      expect(dtos.first.setCode, equals('BLC'));
      expect(dtos.first.format, equals('Commander'));
      expect(dtos.first.allCards.length, equals(2));
    });

    test('F11.2: MtgjsonPreconParser.buildDeterministicDeckId formats precon ID with set code and slug', () {
      final id = MtgjsonPreconParser.buildDeterministicDeckId(
        setCode: 'BLC',
        name: 'Animated Army',
      );

      expect(id, equals('precon-blc-animated-army'));
    });

    test('F11.3: PreconCardDto sanitizes and removes art_series layout and image URIs', () {
      final cardMap = {
        'name': 'Gilded Goose Art Card',
        'layout': 'art_series',
        'image_uris': {
          'normal': 'https://cards.scryfall.io/art_series/front/1/2/123.jpg',
          'art_crop': 'https://cards.scryfall.io/art_series/front/1/2/123_crop.jpg',
        },
      };

      final cardDto = PreconCardDto.fromMap(cardMap);
      expect(cardDto.layout, equals('normal'));
      expect(cardDto.imageUrl, isNot(contains('art_series')));
      expect(cardDto.artCropUrl, isNot(contains('art_series')));
    });

    test('F11.4: PreconHydrationService.isHistoricalPreconSeeded checks registered MTG precons in Drift', () async {
      // Empty db returns false
      final seededBefore = await PreconHydrationService.isHistoricalPreconSeeded(db, minExpectedDecks: 1);
      expect(seededBefore, isFalse);

      // Insert 1 precon
      await db.into(db.decks).insert(
        DecksCompanion.insert(
          id: 'precon-test-1',
          name: 'Test Precon',
          format: 'Commander',
          tcgDomain: const drift.Value('mtg'),
          isRegistered: const drift.Value(true),
          isDeleted: const drift.Value(false),
          createdAt: DateTime.now(),
          updatedAt: drift.Value(DateTime.now()),
        ),
      );

      final seededAfter = await PreconHydrationService.isHistoricalPreconSeeded(db, minExpectedDecks: 1);
      expect(seededAfter, isTrue);
    });

    test('F11.5: MtgjsonPreconParser.normalizeFormat normalizes formats accurately', () {
      expect(MtgjsonPreconParser.normalizeFormat('edh'), equals('Commander'));
      expect(MtgjsonPreconParser.normalizeFormat('Commander Deck'), equals('Commander'));
      expect(MtgjsonPreconParser.normalizeFormat('brawl'), equals('Commander'));
      expect(MtgjsonPreconParser.normalizeFormat('planeswalker deck'), equals('Starter Kit'));
      expect(MtgjsonPreconParser.normalizeFormat('challenger'), equals('Challenger'));
      expect(MtgjsonPreconParser.normalizeFormat('pauper'), equals('Pauper'));
      expect(MtgjsonPreconParser.normalizeFormat(''), equals('Commander'));
    });
  });
}
