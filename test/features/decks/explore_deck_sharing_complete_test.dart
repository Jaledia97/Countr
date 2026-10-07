import 'dart:convert';
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
import 'package:countr/features/decks/presentation/screens/read_only_deck_screen.dart';
import 'package:countr/features/decks/presentation/providers/explore_deck_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late VaultDao vaultDao;
  late ExploreDeckDao exploreDao;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    vaultDao = VaultDao(db);
    exploreDao = ExploreDeckDao(db);

    // Seed initial database (creates starter decks in SQLite with placeholder 1-card item)
    await vaultDao.seedDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  group('Explore Deck Sharing Pipeline Complete Verification', () {
    test('Sharing Edgar Markov starter deck copies all 100 cards across all zones with complete metadata', () async {
      // Act: Share the seeded Edgar Markov personal deck
      final sharedDeck = await exploreDao.sharePersonalDeckToExplore(
        personalDeckId: MockDeckData.edgarMarkovDeckId,
        creatorName: '@VampireLord',
      );

      // 1. Verify ExploreDeck parent row
      expect(sharedDeck.id, equals('explore_shared_${MockDeckData.edgarMarkovDeckId}'));
      expect(sharedDeck.name, equals('Edgar Markov Aristocrats'));
      expect(sharedDeck.cardCount, equals(100), reason: 'ExploreDeck.cardCount must reflect all 100 cards');
      expect(sharedDeck.commanderName, equals('Edgar Markov'));
      expect(sharedDeck.commanderImageUrl, isNotNull);
      expect(sharedDeck.estimatedPrice, greaterThan(100.0));
      expect(sharedDeck.sourceType, equals('user_shared'));

      // 2. Verify all 100 items in explore_deck_items
      final items = await exploreDao.getExploreDeckItems(sharedDeck.id);
      expect(items.length, equals(100), reason: 'explore_deck_items must contain exactly 100 cards');

      // Verify Commander card
      final commanderItems = items.where((i) => i.isCommander || i.boardZone.toLowerCase() == 'commander').toList();
      expect(commanderItems.length, equals(1));
      final commander = commanderItems.first;
      expect(commander.cardName, equals('Edgar Markov'));
      expect(commander.boardZone, equals('Commander'));
      expect(commander.isCommander, isTrue);
      expect(commander.scryfallId, isNotNull);
      expect(commander.manaCost, equals('{3}{R}{W}{B}'));
      expect(commander.cmc, equals(6.0));
      expect(commander.dynamicData, isNotNull);

      // Verify Non-commander cards (mainboard zones)
      final mainboardItems = items.where((i) => !i.isCommander && i.boardZone == 'Mainboard').toList();
      expect(mainboardItems.length, equals(99), reason: '99 mainboard cards must have boardZone == Mainboard');

      // Verify card type breakdowns from dynamic data
      final creatures = items.where((i) => (i.typeLine ?? '').toLowerCase().contains('creature') && !i.isCommander).toList();
      final spells = items.where((i) =>
          ((i.typeLine ?? '').toLowerCase().contains('instant') ||
           (i.typeLine ?? '').toLowerCase().contains('sorcery'))).toList();
      final permanents = items.where((i) =>
          ((i.typeLine ?? '').toLowerCase().contains('artifact') ||
           (i.typeLine ?? '').toLowerCase().contains('enchantment'))).toList();
      final lands = items.where((i) => (i.typeLine ?? '').toLowerCase().contains('land')).toList();

      expect(creatures.length, equals(32));
      expect(spells.length, equals(18));
      expect(permanents.length, equals(14));
      expect(lands.length, equals(35));
      expect(commanderItems.length + creatures.length + spells.length + permanents.length + lands.length, equals(100));

      // Verify Scryfall IDs, quantities, and pricing on every card
      for (final card in items) {
        expect(card.quantity, greaterThanOrEqualTo(1));
        expect(card.scryfallId, isNotNull, reason: '${card.cardName} should have a populated scryfallId');
        expect(card.dynamicData, isNotNull, reason: '${card.cardName} should have dynamicData JSON');
      }
    });

    testWidgets('ReadOnlyDeckScreen renders complete 100-card deck with all sections populated', (tester) async {
      // Share Edgar Markov first
      final shared = await exploreDao.sharePersonalDeckToExplore(
        personalDeckId: MockDeckData.edgarMarkovDeckId,
      );

      // Build ReadOnlyDeckScreen
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            exploreDeckDaoProvider.overrideWithValue(exploreDao),
          ],
          child: MaterialApp(
            home: ReadOnlyDeckScreen(exploreDeckId: shared.id),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify screen title and card count
      expect(find.byKey(const Key('read_only_deck_screen')), findsOneWidget);
      expect(find.text('100 Cards'), findsOneWidget);

      // Verify all partitioned card section headers render
      expect(find.byKey(const Key('read_only_section_commander')), findsOneWidget);
      expect(find.byKey(const Key('read_only_section_creatures')), findsOneWidget);
      expect(find.byKey(const Key('read_only_section_spells')), findsOneWidget);
      expect(find.byKey(const Key('read_only_section_permanents')), findsOneWidget);
      expect(find.byKey(const Key('read_only_section_lands')), findsOneWidget);

      // Commander card visible
      expect(find.text('Edgar Markov'), findsWidgets);
      // Key creatures visible
      expect(find.text('Blood Artist'), findsOneWidget);
      expect(find.text('Cruel Celebrant'), findsOneWidget);
    });

    test('Cloning shared Edgar Markov deck produces complete 100-card personal deck with valid zones', () async {
      // 1. Share Edgar Markov to Explore
      final shared = await exploreDao.sharePersonalDeckToExplore(
        personalDeckId: MockDeckData.edgarMarkovDeckId,
        creatorName: '@OriginalBrewer',
      );

      // 2. Clone from Explore to personal
      final clonedDeck = await exploreDao.cloneExploreDeckToPersonal(
        exploreDeckId: shared.id,
      );

      // 3. Verify cloned personal deck items in SQLite
      final personalItems = await vaultDao.watchDeckItems(clonedDeck.id).first;
      expect(personalItems.length, equals(100), reason: 'Cloned personal deck must have all 100 cards');

      final commanderItem = personalItems.firstWhere((i) => i.boardZone == 'Commander');
      expect(commanderItem.name, equals('Edgar Markov'));

      final mainboardCount = personalItems.where((i) => i.boardZone == 'Mainboard').length;
      expect(mainboardCount, equals(99));
    });

    test('Sharing a custom deck with Mainboard and Sideboard preserves all cards, quantities, and zones', () async {
      final now = DateTime.now();

      // Create a custom 60-card Standard deck in SQLite with 15 sideboard cards
      final customDeck = await vaultDao.createDeck('Azorius Control', isRegistered: true);
      final version = (await (db.select(db.deckVersions)..where((t) => t.deckId.equals(customDeck.id))).get()).first;

      // Insert 2 unique vault items: Teferi (mainboard x4) and Dovin's Veto (sideboard x3)
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-teferi',
          collectionType: 'mtg',
          name: 'Teferi, Hero of Dominaria',
          setOrSeries: 'Dominaria',
          imageUrl: 'https://cards.scryfall.io/teferi.jpg',
          acquiredPrice: 15.0,
          acquiredDate: now,
          quantity: const Value(4),
          condition: 'NM',
          currentMarketPrice: 20.0,
          lastPriceUpdate: now,
          dynamicData: jsonEncode({
            'scryfall_id': 'scryfall-teferi-123',
            'oracle_id': 'oracle-teferi-456',
            'mana_cost': '{3}{W}{U}',
            'cmc': 5.0,
            'type_line': 'Legendary Planeswalker — Teferi',
            'colors': ['W', 'U'],
          }),
        ),
      );

      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-veto',
          collectionType: 'mtg',
          name: "Dovin's Veto",
          setOrSeries: 'War of the Spark',
          imageUrl: 'https://cards.scryfall.io/veto.jpg',
          acquiredPrice: 2.0,
          acquiredDate: now,
          quantity: const Value(3),
          condition: 'NM',
          currentMarketPrice: 3.5,
          lastPriceUpdate: now,
          dynamicData: jsonEncode({
            'scryfall_id': 'scryfall-veto-789',
            'oracle_id': 'oracle-veto-012',
            'mana_cost': '{W}{U}',
            'cmc': 2.0,
            'type_line': 'Instant',
            'colors': ['W', 'U'],
          }),
        ),
      );

      await db.into(db.deckVersionItems).insert(
        DeckVersionItemsCompanion.insert(
          id: 'dvi-teferi',
          versionId: version.id,
          vaultItemId: 'card-teferi',
          quantity: const Value(4),
          boardZone: 'Mainboard',
          isProxy: const Value(false),
          isDeleted: const Value(false),
          updatedAt: Value(now),
        ),
      );

      await db.into(db.deckVersionItems).insert(
        DeckVersionItemsCompanion.insert(
          id: 'dvi-veto',
          versionId: version.id,
          vaultItemId: 'card-veto',
          quantity: const Value(3),
          boardZone: 'Sideboard',
          isProxy: const Value(false),
          isDeleted: const Value(false),
          updatedAt: Value(now),
        ),
      );

      // Share custom deck to explore
      final sharedCustom = await exploreDao.sharePersonalDeckToExplore(
        personalDeckId: customDeck.id,
        creatorName: '@ControlMage',
      );

      expect(sharedCustom.cardCount, equals(7)); // 4 main + 3 side
      expect(sharedCustom.estimatedPrice, equals(4 * 20.0 + 3 * 3.5)); // 80 + 10.5 = 90.5

      final customItems = await exploreDao.getExploreDeckItems(sharedCustom.id);
      expect(customItems.length, equals(2));

      final teferiItem = customItems.firstWhere((i) => i.cardName.contains('Teferi'));
      expect(teferiItem.quantity, equals(4));
      expect(teferiItem.boardZone, equals('Mainboard'));
      expect(teferiItem.scryfallId, equals('scryfall-teferi-123'));
      expect(teferiItem.oracleId, equals('oracle-teferi-456'));

      final vetoItem = customItems.firstWhere((i) => i.cardName.contains('Veto'));
      expect(vetoItem.quantity, equals(3));
      expect(vetoItem.boardZone, equals('Sideboard'));
      expect(vetoItem.scryfallId, equals('scryfall-veto-789'));
      expect(vetoItem.oracleId, equals('oracle-veto-012'));
    });

    test('Sharing Yuriko starter deck preserves Yuriko as Commander and does NOT hijack with Edgar Markov Mardu cards', () async {
      // Act: Share the seeded Yuriko deck
      final sharedYuriko = await exploreDao.sharePersonalDeckToExplore(
        personalDeckId: 'deck-yuriko',
        creatorName: '@NinjaMaster',
      );

      expect(sharedYuriko.commanderName, equals("Yuriko, the Tiger's Shadow"));
      expect(sharedYuriko.cardCount, equals(1));

      final items = await exploreDao.getExploreDeckItems(sharedYuriko.id);
      expect(items.length, equals(1));
      expect(items.first.cardName, equals("Yuriko, the Tiger's Shadow"));
      expect(items.first.isCommander, isTrue);
      expect(items.first.boardZone, equals('Commander'));

      // Ensure no Edgar Markov cards leaked in
      expect(items.any((i) => i.cardName.toLowerCase().contains('edgar')), isFalse);
      expect(items.any((i) => i.cardName.toLowerCase().contains('vampire')), isFalse);
    });

    test('Commander deck with non-commander coverItemId does NOT promote cover card to Commander when explicit Commander exists', () async {
      final now = DateTime.now();

      // Create Commander deck in SQLite
      final deck = await vaultDao.createDeck('Atraxa Superfriends', format: 'Commander');
      final version = (await (db.select(db.deckVersions)..where((t) => t.deckId.equals(deck.id))).get()).first;

      // Card 1: Atraxa (Commander)
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-atraxa',
          collectionType: 'mtg',
          name: "Atraxa, Praetors' Voice",
          setOrSeries: 'Commander 2016',
          imageUrl: 'https://cards.scryfall.io/atraxa.jpg',
          acquiredPrice: 30.0,
          acquiredDate: now,
          quantity: const Value(1),
          condition: 'NM',
          currentMarketPrice: 35.0,
          lastPriceUpdate: now,
          dynamicData: jsonEncode({
            'scryfall_id': 'scryfall-atraxa',
            'type_line': 'Legendary Creature — Phyrexian Angel Horror',
            'mana_cost': '{G}{W}{U}{B}',
            'cmc': 4.0,
            'colors': ['G', 'W', 'U', 'B'],
          }),
        ),
      );

      // Card 2: Sol Ring (Mainboard, but set as coverItemId because user likes the art)
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-sol-ring-custom',
          collectionType: 'mtg',
          name: 'Sol Ring',
          setOrSeries: 'Masterpiece Series',
          imageUrl: 'https://cards.scryfall.io/solring.jpg',
          acquiredPrice: 100.0,
          acquiredDate: now,
          quantity: const Value(1),
          condition: 'NM',
          currentMarketPrice: 120.0,
          lastPriceUpdate: now,
          dynamicData: jsonEncode({
            'scryfall_id': 'scryfall-solring',
            'type_line': 'Artifact',
            'mana_cost': '{1}',
            'cmc': 1.0,
            'colors': <String>[],
          }),
        ),
      );

      // Add Atraxa to Commander zone
      await db.into(db.deckVersionItems).insert(
        DeckVersionItemsCompanion.insert(
          id: 'dvi-atraxa',
          versionId: version.id,
          vaultItemId: 'card-atraxa',
          quantity: const Value(1),
          boardZone: 'Commander',
          isProxy: const Value(false),
          isDeleted: const Value(false),
          updatedAt: Value(now),
        ),
      );

      // Add Sol Ring to Mainboard zone
      await db.into(db.deckVersionItems).insert(
        DeckVersionItemsCompanion.insert(
          id: 'dvi-sol-ring',
          versionId: version.id,
          vaultItemId: 'card-sol-ring-custom',
          quantity: const Value(1),
          boardZone: 'Mainboard',
          isProxy: const Value(false),
          isDeleted: const Value(false),
          updatedAt: Value(now),
        ),
      );

      // Set Sol Ring as the deck thumbnail / cover
      await (db.update(db.decks)..where((t) => t.id.equals(deck.id)))
          .write(DecksCompanion(coverItemId: const Value('card-sol-ring-custom')));

      // Share deck to explore
      final sharedAtraxa = await exploreDao.sharePersonalDeckToExplore(
        personalDeckId: deck.id,
      );

      expect(sharedAtraxa.commanderName, equals("Atraxa, Praetors' Voice"));

      final items = await exploreDao.getExploreDeckItems(sharedAtraxa.id);
      final commanderItem = items.firstWhere((i) => i.cardName == "Atraxa, Praetors' Voice");
      final solRingItem = items.firstWhere((i) => i.cardName == 'Sol Ring');

      expect(commanderItem.isCommander, isTrue);
      expect(commanderItem.boardZone, equals('Commander'));

      // Sol Ring MUST remain Mainboard and not be falsely promoted to Commander
      expect(solRingItem.isCommander, isFalse);
      expect(solRingItem.boardZone, equals('Mainboard'));
    });

    test('Modal double-faced commander (MDFC) properly resolves art and attributes from card_faces', () async {
      final now = DateTime.now();

      final mdfcDeck = await vaultDao.createDeck('Esika Rainbow', format: 'Commander');
      final version = (await (db.select(db.deckVersions)..where((t) => t.deckId.equals(mdfcDeck.id))).get()).first;

      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-esika-mdfc',
          collectionType: 'mtg',
          name: 'Esika, God of the Tree // The Prismatic Bridge',
          setOrSeries: 'Kaldheim',
          imageUrl: '', // Empty at top-level
          acquiredPrice: 15.0,
          acquiredDate: now,
          quantity: const Value(1),
          condition: 'NM',
          currentMarketPrice: 20.0,
          lastPriceUpdate: now,
          dynamicData: jsonEncode({
            'scryfall_id': 'scryfall-esika-456',
            'oracle_id': 'oracle-esika-789',
            'card_faces': [
              {
                'name': 'Esika, God of the Tree',
                'mana_cost': '{1}{G}{G}',
                'type_line': 'Legendary Creature — God',
                'colors': ['G'],
                'image_uris': {
                  'small': 'https://cards.scryfall.io/small/esika.jpg',
                  'normal': 'https://cards.scryfall.io/normal/esika.jpg',
                  'art_crop': 'https://cards.scryfall.io/art_crop/esika.jpg',
                },
              },
              {
                'name': 'The Prismatic Bridge',
                'mana_cost': '{W}{U}{B}{R}{G}',
                'type_line': 'Legendary Enchantment',
                'colors': ['W', 'U', 'B', 'R', 'G'],
                'image_uris': {
                  'small': 'https://cards.scryfall.io/small/bridge.jpg',
                  'normal': 'https://cards.scryfall.io/normal/bridge.jpg',
                  'art_crop': 'https://cards.scryfall.io/art_crop/bridge.jpg',
                },
              },
            ],
            'color_identity': ['W', 'U', 'B', 'R', 'G'],
          }),
        ),
      );

      await db.into(db.deckVersionItems).insert(
        DeckVersionItemsCompanion.insert(
          id: 'dvi-esika',
          versionId: version.id,
          vaultItemId: 'card-esika-mdfc',
          quantity: const Value(1),
          boardZone: 'Commander',
          isProxy: const Value(false),
          isDeleted: const Value(false),
          updatedAt: Value(now),
        ),
      );

      final sharedEsika = await exploreDao.sharePersonalDeckToExplore(
        personalDeckId: mdfcDeck.id,
      );

      expect(sharedEsika.commanderImageUrl, equals('https://cards.scryfall.io/normal/esika.jpg'));
      expect(sharedEsika.commanderArtCrop, equals('https://cards.scryfall.io/art_crop/esika.jpg'));

      final items = await exploreDao.getExploreDeckItems(sharedEsika.id);
      expect(items.length, equals(1));
      final esikaItem = items.first;
      expect(esikaItem.manaCost, equals('{1}{G}{G}'));
      expect(esikaItem.typeLine, equals('Legendary Creature — God'));
      expect(esikaItem.imageUrl, equals('https://cards.scryfall.io/normal/esika.jpg'));
      expect(esikaItem.artCropUrl, equals('https://cards.scryfall.io/art_crop/esika.jpg'));
    });
  });
}
