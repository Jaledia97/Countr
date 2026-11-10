// Copyright (c) 2026 Countr. All rights reserved.
// Adversarial Challenger Test Suite: Milestone 2 (Epic 2)
// 4-Zone Card Cloning, Author Lineage & Zero-Mock Pipeline Integrity

import 'dart:convert';
import 'package:drift/drift.dart' hide isNull, isNotNull, Column;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/data/daos/explore_deck_dao.dart';

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

  group('CHALLENGER GROUP 1: 4-Zone Card Cloning Exhaustive Verification', () {
    test('1.1 Clones cards across all 4 zones (2 Commanders, Mainboard, Sideboard, Maybeboard) with exact counts', () async {
      final now = DateTime.now();
      const personalDeckId = 'adv_deck_4zones';
      const versionId = 'adv_ver_4zones';

      // Setup deck & version
      await db.into(db.decks).insert(
        DecksCompanion.insert(
          id: personalDeckId,
          name: 'Partner Commanders 4-Zone Stress',
          format: 'Commander',
          createdAt: now,
          tcgDomain: const Value('mtg'),
        ),
      );
      await db.into(db.deckVersions).insert(
        DeckVersionsCompanion.insert(
          id: versionId,
          deckId: personalDeckId,
          versionNumber: 1,
          isActive: const Value(true),
          createdAt: now,
        ),
      );

      // Create test items across 4 zones:
      // Zone 1: Commander (2 partner cards, 1 copy each)
      // Zone 2: Mainboard (3 cards, quantities 1, 2, 4)
      // Zone 3: Sideboard (2 cards, quantities 1, 3)
      // Zone 4: Maybeboard (2 cards, quantities 1, 2)
      final testCards = [
        // Commander Partner 1
        {
          'id': 'v_cmdr_1',
          'name': 'Thrasios, Triton Hero',
          'zone': 'Commander',
          'qty': 1,
          'scryfall_id': 'scryfall_thrasios',
          'oracle_id': 'oracle_thrasios',
          'price': 25.0,
          'cmc': 2.0,
          'type': 'Legendary Creature — Merfolk Wizard',
          'colors': ['G', 'U'],
          'isCmdr': true,
        },
        // Commander Partner 2
        {
          'id': 'v_cmdr_2',
          'name': 'Vial Smasher the Fierce',
          'zone': 'Commander',
          'qty': 1,
          'scryfall_id': 'scryfall_vialsmasher',
          'oracle_id': 'oracle_vialsmasher',
          'price': 18.0,
          'cmc': 3.0,
          'type': 'Legendary Creature — Goblin Berserker',
          'colors': ['B', 'R'],
          'isCmdr': true,
        },
        // Mainboard 1
        {
          'id': 'v_main_1',
          'name': 'Sol Ring',
          'zone': 'Mainboard',
          'qty': 1,
          'scryfall_id': 'scryfall_solring',
          'oracle_id': 'oracle_solring',
          'price': 1.5,
          'cmc': 1.0,
          'type': 'Artifact',
          'colors': <String>[],
          'isCmdr': false,
        },
        // Mainboard 2
        {
          'id': 'v_main_2',
          'name': 'Arcane Signet',
          'zone': 'Mainboard',
          'qty': 2,
          'scryfall_id': 'scryfall_signet',
          'oracle_id': 'oracle_signet',
          'price': 0.75,
          'cmc': 2.0,
          'type': 'Artifact',
          'colors': <String>[],
          'isCmdr': false,
        },
        // Mainboard 3
        {
          'id': 'v_main_3',
          'name': 'Lightning Bolt',
          'zone': 'Mainboard',
          'qty': 4,
          'scryfall_id': 'scryfall_bolt',
          'oracle_id': 'oracle_bolt',
          'price': 2.0,
          'cmc': 1.0,
          'type': 'Instant',
          'colors': ['R'],
          'isCmdr': false,
        },
        // Sideboard 1
        {
          'id': 'v_side_1',
          'name': 'Pyroblast',
          'zone': 'Sideboard',
          'qty': 1,
          'scryfall_id': 'scryfall_pyroblast',
          'oracle_id': 'oracle_pyroblast',
          'price': 6.0,
          'cmc': 1.0,
          'type': 'Instant',
          'colors': ['R'],
          'isCmdr': false,
        },
        // Sideboard 2
        {
          'id': 'v_side_2',
          'name': 'Red Elemental Blast',
          'zone': 'Sideboard',
          'qty': 3,
          'scryfall_id': 'scryfall_reb',
          'oracle_id': 'oracle_reb',
          'price': 4.0,
          'cmc': 1.0,
          'type': 'Instant',
          'colors': ['R'],
          'isCmdr': false,
        },
        // Maybeboard 1
        {
          'id': 'v_maybe_1',
          'name': 'Rhystic Study',
          'zone': 'Maybeboard',
          'qty': 1,
          'scryfall_id': 'scryfall_rhystic',
          'oracle_id': 'oracle_rhystic',
          'price': 40.0,
          'cmc': 3.0,
          'type': 'Enchantment',
          'colors': ['U'],
          'isCmdr': false,
        },
        // Maybeboard 2
        {
          'id': 'v_maybe_2',
          'name': 'Mystic Remora',
          'zone': 'Maybeboard',
          'qty': 2,
          'scryfall_id': 'scryfall_remora',
          'oracle_id': 'oracle_remora',
          'price': 8.0,
          'cmc': 1.0,
          'type': 'Enchantment',
          'colors': ['U'],
          'isCmdr': false,
        },
      ];

      for (var i = 0; i < testCards.length; i++) {
        final c = testCards[i];
        final vId = c['id'] as String;
        await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: vId,
            collectionType: 'mtg',
            name: c['name'] as String,
            setOrSeries: 'Stress Set',
            condition: 'NM',
            imageUrl: 'https://cards.scryfall.io/img/$vId.jpg',
            acquiredPrice: (c['price'] as num).toDouble(),
            acquiredDate: now,
            currentMarketPrice: (c['price'] as num).toDouble(),
            lastPriceUpdate: now,
            dynamicData: jsonEncode({
              'scryfall_id': c['scryfall_id'],
              'oracle_id': c['oracle_id'],
              'cmc': c['cmc'],
              'type_line': c['type'],
              'colors': c['colors'],
            }),
          ),
        );

        await db.into(db.deckVersionItems).insert(
          DeckVersionItemsCompanion.insert(
            id: 'dvi_$i',
            versionId: versionId,
            vaultItemId: vId,
            quantity: Value(c['qty'] as int),
            boardZone: c['zone'] as String,
            updatedAt: Value(now),
          ),
        );
      }

      // Total card units: 1 + 1 + 1 + 2 + 4 + 1 + 3 + 1 + 2 = 16
      // Total price: 25(1) + 18(1) + 1.5(1) + 0.75(2) + 2(4) + 6(1) + 4(3) + 40(1) + 8(2) = 128.0

      // Share to Explore
      final shared = await exploreDao.sharePersonalDeckToExplore(
        personalDeckId: personalDeckId,
        creatorName: 'StressTester',
        authorId: 'author_tester_001',
      );

      // Verify Parent Explore Deck
      expect(shared.id, equals('explore_shared_$personalDeckId'));
      expect(shared.cardCount, equals(16));
      expect(shared.estimatedPrice, closeTo(128.0, 0.01));
      expect(shared.authorId, equals('author_tester_001'));
      expect(shared.commanderName, isNotNull);

      // Verify All 4 Zones in ExploreDeckItems
      final clonedItems = await exploreDao.getExploreDeckItems(shared.id);
      expect(clonedItems.length, equals(testCards.length)); // 9 entries

      // Zone 1: Commander
      final cmdrRows = clonedItems.where((i) => i.boardZone == 'Commander').toList();
      expect(cmdrRows.length, equals(2));
      expect(cmdrRows.every((c) => c.isCommander), isTrue);
      expect(cmdrRows.map((c) => c.cardName).toSet(), containsAll(['Thrasios, Triton Hero', 'Vial Smasher the Fierce']));

      // Zone 2: Mainboard
      final mainRows = clonedItems.where((i) => i.boardZone == 'Mainboard').toList();
      expect(mainRows.length, equals(3));
      final solRing = mainRows.firstWhere((c) => c.cardName == 'Sol Ring');
      expect(solRing.quantity, equals(1));
      expect(solRing.scryfallId, equals('scryfall_solring'));
      final signet = mainRows.firstWhere((c) => c.cardName == 'Arcane Signet');
      expect(signet.quantity, equals(2));
      final bolt = mainRows.firstWhere((c) => c.cardName == 'Lightning Bolt');
      expect(bolt.quantity, equals(4));

      // Zone 3: Sideboard
      final sideRows = clonedItems.where((i) => i.boardZone == 'Sideboard').toList();
      expect(sideRows.length, equals(2));
      final pyro = sideRows.firstWhere((c) => c.cardName == 'Pyroblast');
      expect(pyro.quantity, equals(1));
      expect(pyro.scryfallId, equals('scryfall_pyroblast'));
      final reb = sideRows.firstWhere((c) => c.cardName == 'Red Elemental Blast');
      expect(reb.quantity, equals(3));
      expect(reb.scryfallId, equals('scryfall_reb'));

      // Zone 4: Maybeboard
      final maybeRows = clonedItems.where((i) => i.boardZone == 'Maybeboard').toList();
      expect(maybeRows.length, equals(2));
      final rhystic = maybeRows.firstWhere((c) => c.cardName == 'Rhystic Study');
      expect(rhystic.quantity, equals(1));
      expect(rhystic.scryfallId, equals('scryfall_rhystic'));
      final remora = maybeRows.firstWhere((c) => c.cardName == 'Mystic Remora');
      expect(remora.quantity, equals(2));
      expect(remora.scryfallId, equals('scryfall_remora'));
    });

    test('1.2 Tolerates case variations and whitespace in boardZone strings', () async {
      final now = DateTime.now();
      const pDeckId = 'deck_casing_stress';
      const vId = 'ver_casing_stress';

      await db.into(db.decks).insert(
        DecksCompanion.insert(
          id: pDeckId,
          name: 'Casing Stress',
          format: 'Standard',
          createdAt: now,
        ),
      );
      await db.into(db.deckVersions).insert(
        DeckVersionsCompanion.insert(
          id: vId,
          deckId: pDeckId,
          versionNumber: 1,
          isActive: const Value(true),
          createdAt: now,
        ),
      );

      final casingRows = [
        {'id': 'c1', 'zone': '  commander  ', 'name': 'Cmdr Card'},
        {'id': 'c2', 'zone': 'SIDEBOARD', 'name': 'Side Card'},
        {'id': 'c3', 'zone': 'MaybeBoard ', 'name': 'Maybe Card'},
        {'id': 'c4', 'zone': 'mainBOARD', 'name': 'Main Card'},
      ];

      for (final r in casingRows) {
        await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: r['id']!,
            collectionType: 'mtg',
            name: r['name']!,
            setOrSeries: 'Set',
            condition: 'NM',
            imageUrl: '',
            acquiredPrice: 1.0,
            acquiredDate: now,
            currentMarketPrice: 1.0,
            lastPriceUpdate: now,
            dynamicData: '{}',
          ),
        );
        await db.into(db.deckVersionItems).insert(
          DeckVersionItemsCompanion.insert(
            id: 'dvi_${r['id']}',
            versionId: vId,
            vaultItemId: r['id']!,
            quantity: const Value(1),
            boardZone: r['zone']!,
            updatedAt: Value(now),
          ),
        );
      }

      final shared = await exploreDao.sharePersonalDeckToExplore(
        personalDeckId: pDeckId,
      );

      final items = await exploreDao.getExploreDeckItems(shared.id);
      expect(items.firstWhere((i) => i.cardName == 'Cmdr Card').boardZone, equals('Commander'));
      expect(items.firstWhere((i) => i.cardName == 'Side Card').boardZone, equals('Sideboard'));
      expect(items.firstWhere((i) => i.cardName == 'Maybe Card').boardZone, equals('Maybeboard'));
      expect(items.firstWhere((i) => i.cardName == 'Main Card').boardZone, equals('Mainboard'));
    });

    test('1.3 Multiple distinct printings of the exact same card name remain separate rows with their own printing IDs', () async {
      final now = DateTime.now();
      const deckId = 'deck_multi_printings';
      const vId = 'ver_multi_printings';

      await db.into(db.decks).insert(
        DecksCompanion.insert(
          id: deckId,
          name: 'Multi Printings Deck',
          format: 'Commander',
          createdAt: now,
        ),
      );
      await db.into(db.deckVersions).insert(
        DeckVersionsCompanion.insert(
          id: vId,
          deckId: deckId,
          versionNumber: 1,
          isActive: const Value(true),
          createdAt: now,
        ),
      );

      // 4 different printings of Forest
      final forestPrintings = [
        {'id': 'forest_lea', 'set': 'Limited Edition Alpha', 'scryfall': 'scryfall_forest_lea', 'art': 'https://art/lea.jpg'},
        {'id': 'forest_unh', 'set': 'Unhinged', 'scryfall': 'scryfall_forest_unh', 'art': 'https://art/unh.jpg'},
        {'id': 'forest_neo', 'set': 'Kamigawa: Neon Dynasty', 'scryfall': 'scryfall_forest_neo', 'art': 'https://art/neo.jpg'},
        {'id': 'forest_ust', 'set': 'Unstable', 'scryfall': 'scryfall_forest_ust', 'art': 'https://art/ust.jpg'},
      ];

      for (final f in forestPrintings) {
        await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: f['id']!,
            collectionType: 'mtg',
            name: 'Forest',
            setOrSeries: f['set']!,
            condition: 'NM',
            imageUrl: f['art']!,
            acquiredPrice: 5.0,
            acquiredDate: now,
            currentMarketPrice: 5.0,
            lastPriceUpdate: now,
            dynamicData: jsonEncode({
              'scryfall_id': f['scryfall'],
              'image_uris': {'art_crop': f['art'], 'normal': f['art']},
              'set_name': f['set'],
            }),
          ),
        );
        await db.into(db.deckVersionItems).insert(
          DeckVersionItemsCompanion.insert(
            id: 'dvi_${f['id']}',
            versionId: vId,
            vaultItemId: f['id']!,
            quantity: const Value(1),
            boardZone: 'Mainboard',
            updatedAt: Value(now),
          ),
        );
      }

      final shared = await exploreDao.sharePersonalDeckToExplore(
        personalDeckId: deckId,
      );

      final items = await exploreDao.getExploreDeckItems(shared.id);
      expect(items.length, equals(4));

      final scryfallIds = items.map((i) => i.scryfallId).toSet();
      expect(scryfallIds, containsAll([
        'scryfall_forest_lea',
        'scryfall_forest_unh',
        'scryfall_forest_neo',
        'scryfall_forest_ust',
      ]));
    });
  });

  group('CHALLENGER GROUP 2: Zero Mock Fallback & Hostile Edge Cases', () {
    test('2.1 Novel personal deck with novel cards has ZERO mock cards injected', () async {
      final now = DateTime.now();
      const novelDeckId = 'deck_completely_novel_unique_9988';
      const versionId = 'ver_novel_unique_9988';

      await db.into(db.decks).insert(
        DecksCompanion.insert(
          id: novelDeckId,
          name: 'Novel Custom Brew',
          format: 'Modern',
          createdAt: now,
        ),
      );
      await db.into(db.deckVersions).insert(
        DeckVersionsCompanion.insert(
          id: versionId,
          deckId: novelDeckId,
          versionNumber: 1,
          isActive: const Value(true),
          createdAt: now,
        ),
      );

      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card_ragavan_custom',
          collectionType: 'mtg',
          name: 'Ragavan, Nimble Pilferer',
          setOrSeries: 'Modern Horizons 2',
          condition: 'NM',
          imageUrl: 'https://cards.scryfall.io/ragavan.jpg',
          acquiredPrice: 50.0,
          acquiredDate: now,
          currentMarketPrice: 55.0,
          lastPriceUpdate: now,
          dynamicData: jsonEncode({
            'scryfall_id': 'ragavan_scryfall_mh2',
            'cmc': 1.0,
            'type_line': 'Legendary Creature — Monkey Pirate',
          }),
        ),
      );

      await db.into(db.deckVersionItems).insert(
        DeckVersionItemsCompanion.insert(
          id: 'dvi_ragavan',
          versionId: versionId,
          vaultItemId: 'card_ragavan_custom',
          quantity: const Value(4),
          boardZone: 'Mainboard',
          updatedAt: Value(now),
        ),
      );

      final shared = await exploreDao.sharePersonalDeckToExplore(
        personalDeckId: novelDeckId,
        creatorName: 'ModernBrewer',
      );

      expect(shared.cardCount, equals(4));
      final items = await exploreDao.getExploreDeckItems(shared.id);
      expect(items.length, equals(1));
      expect(items.first.cardName, equals('Ragavan, Nimble Pilferer'));
      expect(items.first.quantity, equals(4));

      // Assert zero mock cards (no Edgar Markov, no Blood Artist, no Charizard, etc.)
      expect(items.any((i) => i.cardName.toLowerCase().contains('edgar')), isFalse);
      expect(items.any((i) => i.cardName.toLowerCase().contains('charizard')), isFalse);
    });

    test('2.2 Empty personal deck shares cleanly with 0 items without throwing or falling back to mock cards', () async {
      final now = DateTime.now();
      const emptyDeckId = 'deck_empty_personal_brew';
      const versionId = 'ver_empty_personal_brew';

      await db.into(db.decks).insert(
        DecksCompanion.insert(
          id: emptyDeckId,
          name: 'Empty WIP Deck',
          format: 'Pioneer',
          createdAt: now,
        ),
      );
      await db.into(db.deckVersions).insert(
        DeckVersionsCompanion.insert(
          id: versionId,
          deckId: emptyDeckId,
          versionNumber: 1,
          isActive: const Value(true),
          createdAt: now,
        ),
      );

      final shared = await exploreDao.sharePersonalDeckToExplore(
        personalDeckId: emptyDeckId,
        creatorName: 'EmptyBrewer',
      );

      expect(shared.cardCount, equals(0));
      expect(shared.estimatedPrice, equals(0.0));

      final items = await exploreDao.getExploreDeckItems(shared.id);
      expect(items, isEmpty);
    });

    test('2.3 Soft-deleted rows in deck_version_items and vault_items are strictly ignored', () async {
      final now = DateTime.now();
      const deckId = 'deck_soft_delete_stress';
      const vId = 'ver_soft_delete_stress';

      await db.into(db.decks).insert(
        DecksCompanion.insert(
          id: deckId,
          name: 'Soft Delete Filter Deck',
          format: 'Standard',
          createdAt: now,
        ),
      );
      await db.into(db.deckVersions).insert(
        DeckVersionsCompanion.insert(
          id: vId,
          deckId: deckId,
          versionNumber: 1,
          isActive: const Value(true),
          createdAt: now,
        ),
      );

      // Card 1: Active in both tables
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'v_active',
          collectionType: 'mtg',
          name: 'Active Card',
          setOrSeries: 'Set A',
          condition: 'NM',
          imageUrl: '',
          acquiredPrice: 2.0,
          acquiredDate: now,
          currentMarketPrice: 2.0,
          lastPriceUpdate: now,
          isDeleted: const Value(false),
          dynamicData: '{}',
        ),
      );
      await db.into(db.deckVersionItems).insert(
        DeckVersionItemsCompanion.insert(
          id: 'dvi_active',
          versionId: vId,
          vaultItemId: 'v_active',
          quantity: const Value(2),
          boardZone: 'Mainboard',
          isDeleted: const Value(false),
          updatedAt: Value(now),
        ),
      );

      // Card 2: Deleted in deck_version_items (isDeleted: true)
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'v_dvi_deleted',
          collectionType: 'mtg',
          name: 'DVI Deleted Card',
          setOrSeries: 'Set A',
          condition: 'NM',
          imageUrl: '',
          acquiredPrice: 5.0,
          acquiredDate: now,
          currentMarketPrice: 5.0,
          lastPriceUpdate: now,
          isDeleted: const Value(false),
          dynamicData: '{}',
        ),
      );
      await db.into(db.deckVersionItems).insert(
        DeckVersionItemsCompanion.insert(
          id: 'dvi_deleted',
          versionId: vId,
          vaultItemId: 'v_dvi_deleted',
          quantity: const Value(3),
          boardZone: 'Mainboard',
          isDeleted: const Value(true),
          updatedAt: Value(now),
        ),
      );

      // Card 3: Deleted in vault_items (isDeleted: true)
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'v_vault_deleted',
          collectionType: 'mtg',
          name: 'Vault Deleted Card',
          setOrSeries: 'Set A',
          condition: 'NM',
          imageUrl: '',
          acquiredPrice: 10.0,
          acquiredDate: now,
          currentMarketPrice: 10.0,
          lastPriceUpdate: now,
          isDeleted: const Value(true),
          dynamicData: '{}',
        ),
      );
      await db.into(db.deckVersionItems).insert(
        DeckVersionItemsCompanion.insert(
          id: 'dvi_vault_deleted',
          versionId: vId,
          vaultItemId: 'v_vault_deleted',
          quantity: const Value(1),
          boardZone: 'Sideboard',
          isDeleted: const Value(false),
          updatedAt: Value(now),
        ),
      );

      final shared = await exploreDao.sharePersonalDeckToExplore(
        personalDeckId: deckId,
      );

      // Only Card 1 should be cloned (quantity 2, price 4.0)
      expect(shared.cardCount, equals(2));
      expect(shared.estimatedPrice, equals(4.0));

      final items = await exploreDao.getExploreDeckItems(shared.id);
      expect(items.length, equals(1));
      expect(items.first.cardName, equals('Active Card'));
    });

    test('2.4 Multi-version deck only clones cards from the latest version', () async {
      final t1 = DateTime(2026, 1, 1);
      final t2 = DateTime(2026, 2, 1);
      const deckId = 'deck_multiver';

      await db.into(db.decks).insert(
        DecksCompanion.insert(
          id: deckId,
          name: 'Multi Version Deck',
          format: 'Modern',
          createdAt: t1,
        ),
      );

      // Version 1 (older)
      await db.into(db.deckVersions).insert(
        DeckVersionsCompanion.insert(
          id: 'ver_old_1',
          deckId: deckId,
          versionNumber: 1,
          createdAt: t1,
        ),
      );
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'v_old_card',
          collectionType: 'mtg',
          name: 'Old Version Card',
          setOrSeries: 'OldSet',
          condition: 'NM',
          imageUrl: '',
          acquiredPrice: 1.0,
          acquiredDate: t1,
          currentMarketPrice: 1.0,
          lastPriceUpdate: t1,
          dynamicData: '{}',
        ),
      );
      await db.into(db.deckVersionItems).insert(
        DeckVersionItemsCompanion.insert(
          id: 'dvi_old_1',
          versionId: 'ver_old_1',
          vaultItemId: 'v_old_card',
          quantity: const Value(4),
          boardZone: 'Mainboard',
          updatedAt: Value(t1),
        ),
      );

      // Version 2 (newer)
      await db.into(db.deckVersions).insert(
        DeckVersionsCompanion.insert(
          id: 'ver_new_2',
          deckId: deckId,
          versionNumber: 2,
          createdAt: t2,
        ),
      );
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'v_new_card',
          collectionType: 'mtg',
          name: 'New Version Card',
          setOrSeries: 'NewSet',
          condition: 'NM',
          imageUrl: '',
          acquiredPrice: 2.0,
          acquiredDate: t2,
          currentMarketPrice: 2.0,
          lastPriceUpdate: t2,
          dynamicData: '{}',
        ),
      );
      await db.into(db.deckVersionItems).insert(
        DeckVersionItemsCompanion.insert(
          id: 'dvi_new_2',
          versionId: 'ver_new_2',
          vaultItemId: 'v_new_card',
          quantity: const Value(2),
          boardZone: 'Mainboard',
          updatedAt: Value(t2),
        ),
      );

      final shared = await exploreDao.sharePersonalDeckToExplore(
        personalDeckId: deckId,
      );

      // Should only contain Version 2 (quantity 2, not 6)
      expect(shared.cardCount, equals(2));
      final items = await exploreDao.getExploreDeckItems(shared.id);
      expect(items.length, equals(1));
      expect(items.first.cardName, equals('New Version Card'));
    });

    test('2.5 Re-sharing an edited deck updates explore record and cleanly purges old items without orphan records', () async {
      final now = DateTime.now();
      const deckId = 'deck_reshare_test';
      const vId = 'ver_reshare_test';

      await db.into(db.decks).insert(
        DecksCompanion.insert(
          id: deckId,
          name: 'Initial Deck Name',
          format: 'Commander',
          createdAt: now,
        ),
      );
      await db.into(db.deckVersions).insert(
        DeckVersionsCompanion.insert(
          id: vId,
          deckId: deckId,
          versionNumber: 1,
          createdAt: now,
        ),
      );

      // Initial card: Alpha Card x1
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'v_alpha',
          collectionType: 'mtg',
          name: 'Alpha Card',
          setOrSeries: 'Set',
          condition: 'NM',
          imageUrl: '',
          acquiredPrice: 10.0,
          acquiredDate: now,
          currentMarketPrice: 10.0,
          lastPriceUpdate: now,
          dynamicData: '{}',
        ),
      );
      await db.into(db.deckVersionItems).insert(
        DeckVersionItemsCompanion.insert(
          id: 'dvi_alpha',
          versionId: vId,
          vaultItemId: 'v_alpha',
          quantity: const Value(1),
          boardZone: 'Commander',
          updatedAt: Value(now),
        ),
      );

      // First share
      final shared1 = await exploreDao.sharePersonalDeckToExplore(
        personalDeckId: deckId,
        authorId: 'initial_author',
      );
      expect(shared1.cardCount, equals(1));
      expect(shared1.authorId, equals('initial_author'));

      // Now mutate personal deck: remove Alpha Card, add Beta Card x3
      await (db.delete(db.deckVersionItems)..where((t) => t.versionId.equals(vId))).go();

      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'v_beta',
          collectionType: 'mtg',
          name: 'Beta Card',
          setOrSeries: 'Set',
          condition: 'NM',
          imageUrl: '',
          acquiredPrice: 5.0,
          acquiredDate: now,
          currentMarketPrice: 5.0,
          lastPriceUpdate: now,
          dynamicData: '{}',
        ),
      );
      await db.into(db.deckVersionItems).insert(
        DeckVersionItemsCompanion.insert(
          id: 'dvi_beta',
          versionId: vId,
          vaultItemId: 'v_beta',
          quantity: const Value(3),
          boardZone: 'Commander',
          updatedAt: Value(now),
        ),
      );

      // Second share with new author
      final shared2 = await exploreDao.sharePersonalDeckToExplore(
        personalDeckId: deckId,
        authorId: 'updated_author',
      );

      expect(shared2.id, equals(shared1.id));
      expect(shared2.cardCount, equals(3));
      expect(shared2.authorId, equals('updated_author'));

      final items = await exploreDao.getExploreDeckItems(shared2.id);
      expect(items.length, equals(1));
      expect(items.first.cardName, equals('Beta Card'));
      expect(items.first.quantity, equals(3));
      expect(items.any((i) => i.cardName == 'Alpha Card'), isFalse);
    });
  });

  group('CHALLENGER GROUP 3: authorId Queryability, Isolation & Injection Hardening', () {
    test('3.1 Queries explore_decks by author_id using SQL index without cross-contamination', () async {
      final now = DateTime.now();

      // Seed 3 decks with distinct authors
      final authors = ['user_alpha_77', 'user_beta_88', 'user_alpha_77'];
      for (var i = 0; i < authors.length; i++) {
        await db.into(db.exploreDecks).insert(
          ExploreDecksCompanion.insert(
            id: 'explore_deck_$i',
            name: 'Deck $i',
            format: 'Commander',
            sourceType: const Value('user_shared'),
            creatorName: Value('Creator $i'),
            authorId: Value(authors[i]),
            createdAt: now,
            updatedAt: Value(now),
          ),
        );
      }

      // Query author user_alpha_77 via direct SQL
      final alphaRows = await db.customSelect(
        'SELECT id, name, author_id FROM explore_decks WHERE author_id = ? ORDER BY id ASC;',
        variables: [Variable.withString('user_alpha_77')],
      ).get();

      expect(alphaRows.length, equals(2));
      expect(alphaRows[0].read<String>('id'), equals('explore_deck_0'));
      expect(alphaRows[1].read<String>('id'), equals('explore_deck_2'));

      // Query author user_beta_88
      final betaRows = await db.customSelect(
        'SELECT id, name, author_id FROM explore_decks WHERE author_id = ?;',
        variables: [Variable.withString('user_beta_88')],
      ).get();

      expect(betaRows.length, equals(1));
      expect(betaRows.first.read<String>('id'), equals('explore_deck_1'));

      // Query non-existent author
      final emptyRows = await db.customSelect(
        'SELECT id, name, author_id FROM explore_decks WHERE author_id = ?;',
        variables: [Variable.withString('user_non_existent')],
      ).get();

      expect(emptyRows, isEmpty);
    });

    test('3.2 authorId with UUID, Emojis, Spaces, and SQL injection strings persist and query safely', () async {
      final now = DateTime.now();

      final hostileAuthors = [
        '9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d', // UUID v4
        '🧙‍♂️ Magic Master ⚔️ [LGS]',            // Emojis & brackets
        "user_attack'; DROP TABLE explore_decks; --", // SQL injection attempt 1
        "admin' OR '1'='1",                     // SQL injection attempt 2
      ];

      for (var i = 0; i < hostileAuthors.length; i++) {
        final aId = hostileAuthors[i];
        final dId = 'deck_hostile_$i';

        await db.into(db.decks).insert(
          DecksCompanion.insert(
            id: dId,
            name: 'Hostile Deck $i',
            format: 'Standard',
            createdAt: now,
          ),
        );
        await db.into(db.deckVersions).insert(
          DeckVersionsCompanion.insert(
            id: 'ver_$dId',
            deckId: dId,
            versionNumber: 1,
            createdAt: now,
          ),
        );

        final shared = await exploreDao.sharePersonalDeckToExplore(
          personalDeckId: dId,
          authorId: aId,
        );

        expect(shared.authorId, equals(aId));

        // Verify retrieval via parameter binding
        final result = await (db.select(db.exploreDecks)
              ..where((t) => t.authorId.equals(aId)))
            .get();
        expect(result.length, equals(1));
        expect(result.first.authorId, equals(aId));
      }

      // Verify the explore_decks table was NOT dropped by injection
      final allRows = await db.select(db.exploreDecks).get();
      expect(allRows.length, equals(hostileAuthors.length));
    });

    test('3.3 Verify index idx_explore_decks_author is utilized by SQLite query planner', () async {
      final planRows = await db.customSelect(
        'EXPLAIN QUERY PLAN SELECT * FROM explore_decks WHERE author_id = ?;',
        variables: [Variable.withString('test_user')],
      ).get();

      final planDetails = planRows.map((r) => r.data.values.join(' ')).join('\n');
      // Must either use idx_explore_decks_author or index scan on author_id
      expect(
        planDetails.toLowerCase().contains('idx_explore_decks_author') ||
        planDetails.toLowerCase().contains('author_id') ||
        planDetails.toLowerCase().contains('index'),
        isTrue,
        reason: 'Query planner should utilize the author_id index',
      );
    });
  });

  group('CHALLENGER GROUP 4: 4-Zone Round-Trip Fidelity (Personal -> Explore -> Personal Clone)', () {
    test('4.1 Cloned personal deck preserves all 4 zones, quantities, and properties from source explore deck', () async {
      final now = DateTime.now();
      const originDeckId = 'deck_roundtrip_origin';
      const originVerId = 'ver_roundtrip_origin';

      await db.into(db.decks).insert(
        DecksCompanion.insert(
          id: originDeckId,
          name: 'Round Trip Commander',
          format: 'Commander',
          createdAt: now,
        ),
      );
      await db.into(db.deckVersions).insert(
        DeckVersionsCompanion.insert(
          id: originVerId,
          deckId: originDeckId,
          versionNumber: 1,
          createdAt: now,
        ),
      );

      final cards = [
        {'id': 'c_cmdr', 'name': 'Korvold, Fae-Cursed King', 'zone': 'Commander', 'qty': 1, 'cmc': 5.0},
        {'id': 'c_main', 'name': 'Mayhem Devil', 'zone': 'Mainboard', 'qty': 1, 'cmc': 3.0},
        {'id': 'c_side', 'name': 'Veil of Summer', 'zone': 'Sideboard', 'qty': 2, 'cmc': 1.0},
        {'id': 'c_maybe', 'name': 'Dockside Extortionist', 'zone': 'Maybeboard', 'qty': 1, 'cmc': 2.0},
      ];

      for (final c in cards) {
        await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: c['id'] as String,
            collectionType: 'mtg',
            name: c['name'] as String,
            setOrSeries: 'Eldraine',
            condition: 'NM',
            imageUrl: 'https://cards.scryfall.io/${c['id']}.jpg',
            acquiredPrice: 10.0,
            acquiredDate: now,
            currentMarketPrice: 10.0,
            lastPriceUpdate: now,
            dynamicData: jsonEncode({
              'scryfall_id': 'scryfall_${c['id']}',
              'cmc': c['cmc'],
              'type_line': 'Creature',
            }),
          ),
        );
        await db.into(db.deckVersionItems).insert(
          DeckVersionItemsCompanion.insert(
            id: 'dvi_${c['id']}',
            versionId: originVerId,
            vaultItemId: c['id'] as String,
            quantity: Value(c['qty'] as int),
            boardZone: c['zone'] as String,
            updatedAt: Value(now),
          ),
        );
      }

      // Step 1: Share to Explore
      final shared = await exploreDao.sharePersonalDeckToExplore(
        personalDeckId: originDeckId,
        creatorName: 'RoundTripAuthor',
        authorId: 'user_rt_99',
      );

      expect(shared.cardCount, equals(5));

      // Step 2: Clone Explore Deck to New Personal Deck
      final clonedDeck = await exploreDao.cloneExploreDeckToPersonal(
        exploreDeckId: shared.id,
      );

      expect(clonedDeck.name, equals('Round Trip Commander (Copy)'));
      expect(clonedDeck.isCloned, isTrue);
      expect(clonedDeck.sourceExploreDeckId, equals(shared.id));

      // Step 3: Fetch items of cloned personal deck
      final activeVersion = await (db.select(db.deckVersions)
            ..where((t) => t.deckId.equals(clonedDeck.id)))
          .getSingle();

      final clonedItems = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals(activeVersion.id)))
          .get();

      expect(clonedItems.length, equals(4));

      final clonedZones = clonedItems.map((i) => i.boardZone).toSet();
      expect(clonedZones, containsAll(['Commander', 'Mainboard', 'Sideboard', 'Maybeboard']));

      final cmdrItem = clonedItems.firstWhere((i) => i.boardZone == 'Commander');
      expect(cmdrItem.quantity, equals(1));

      final sideItem = clonedItems.firstWhere((i) => i.boardZone == 'Sideboard');
      expect(sideItem.quantity, equals(2));

      final maybeItem = clonedItems.firstWhere((i) => i.boardZone == 'Maybeboard');
      expect(maybeItem.quantity, equals(1));
    });
  });
}

