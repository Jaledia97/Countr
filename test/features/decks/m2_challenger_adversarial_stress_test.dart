import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:uuid/uuid.dart';

import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/domain/legality_enforcer.dart';
import 'package:countr/features/decks/presentation/widgets/proportional_bubble_scrollbar.dart';
import 'package:countr/features/decks/presentation/screens/deck_builder_screen.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import '../../e2e_phase46/phase46_test_helpers.dart';
import 'deck_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  // ===========================================================================
  // GROUP 1: FORMAT LEGALITY ENGINE ADVERSARIAL STRESS TESTS
  // ===========================================================================
  group('Adversarial Group 1: Format Legality Engine Empirical Stress', () {
    test('Extreme inputs to CardLegality.evaluate never throw and return UNKNOWN status', () {
      const format = 'Commander';

      // 1. Null input
      final resNull = CardLegality.evaluate(null, format);
      expect(resNull.status, equals(LegalityStatus.unknown));
      expect(resNull.rawStatus, equals('unknown'));
      expect(resNull.badgeLabel, equals('UNKNOWN'));
      expect(resNull.hasWarning, isFalse);

      // 2. Empty string & whitespace
      final resEmpty = CardLegality.evaluate('', format);
      expect(resEmpty.status, equals(LegalityStatus.unknown));

      final resWhitespace = CardLegality.evaluate('   \t\n  ', format);
      expect(resWhitespace.status, equals(LegalityStatus.unknown));

      // 3. Malformed JSON
      final resTruncated = CardLegality.evaluate('{"legalities": {"commander": "leg', format);
      expect(resTruncated.status, equals(LegalityStatus.unknown));

      final resInvalidJson = CardLegality.evaluate('NOT_JSON_AT_ALL {]', format);
      expect(resInvalidJson.status, equals(LegalityStatus.unknown));

      // 4. Primitive JSON strings
      final resNumberJson = CardLegality.evaluate('42', format);
      expect(resNumberJson.status, equals(LegalityStatus.unknown));

      final resBoolJson = CardLegality.evaluate('true', format);
      expect(resBoolJson.status, equals(LegalityStatus.unknown));

      final resArrayJson = CardLegality.evaluate('["commander", "legal"]', format);
      expect(resArrayJson.status, equals(LegalityStatus.unknown));

      // 5. Primitive dynamic objects directly
      final resInt = CardLegality.evaluate(12345, format);
      expect(resInt.status, equals(LegalityStatus.unknown));

      final resList = CardLegality.evaluate([1, 2, 3], format);
      expect(resList.status, equals(LegalityStatus.unknown));

      final resBool = CardLegality.evaluate(false, format);
      expect(resBool.status, equals(LegalityStatus.unknown));

      // 6. Non-map or empty legalities
      final resEmptyMap = CardLegality.evaluate(<String, dynamic>{}, format);
      expect(resEmptyMap.status, equals(LegalityStatus.unknown));

      final resStringLegalities = CardLegality.evaluate({'legalities': 'legal'}, format);
      expect(resStringLegalities.status, equals(LegalityStatus.unknown));

      final resListLegalities = CardLegality.evaluate({'legalities': ['legal', 'commander']}, format);
      expect(resListLegalities.status, equals(LegalityStatus.unknown));

      final resEmptyLegalitiesMap = CardLegality.evaluate({'legalities': <String, dynamic>{}}, format);
      expect(resEmptyLegalitiesMap.status, equals(LegalityStatus.unknown));

      // 7. Generic non-MTG card dynamicData map without legality keys
      final resGenericCard = CardLegality.evaluate({
        'set': 'pokemon_base',
        'rarity': 'holo',
        'hp': 120,
      }, format);
      expect(resGenericCard.status, equals(LegalityStatus.unknown));
      expect(resGenericCard.hasWarning, isFalse);
    });

    test('Format Normalization correctly maps aliases, casing, and whitespace', () {
      final cardLegal = {
        'legalities': {
          'commander': 'legal',
          'modern': 'legal',
          'standard': 'not_legal',
          'vintage': 'restricted',
          'legacy': 'banned',
          'pauper': 'legal',
          'pioneer': 'legal',
          'brawl': 'legal',
          'historic': 'legal',
          'penny': 'legal',
          'alchemy': 'legal',
        }
      };

      // Commander aliases and casing
      expect(CardLegality.evaluate(cardLegal, 'commander').status, equals(LegalityStatus.legal));
      expect(CardLegality.evaluate(cardLegal, 'COMMANDER').status, equals(LegalityStatus.legal));
      expect(CardLegality.evaluate(cardLegal, '  cOmMaNdEr  ').status, equals(LegalityStatus.legal));
      expect(CardLegality.evaluate(cardLegal, 'EDH').status, equals(LegalityStatus.legal));
      expect(CardLegality.evaluate(cardLegal, 'Commander / EDH').status, equals(LegalityStatus.legal));
      expect(CardLegality.evaluate(cardLegal, 'edh format').status, equals(LegalityStatus.legal));

      // Modern
      expect(CardLegality.evaluate(cardLegal, 'MODERN').status, equals(LegalityStatus.legal));
      expect(CardLegality.evaluate(cardLegal, 'Modern 60-card').status, equals(LegalityStatus.legal));

      // Standard
      expect(CardLegality.evaluate(cardLegal, 'standard').status, equals(LegalityStatus.notLegal));
      expect(CardLegality.evaluate(cardLegal, 'STANDARD').status, equals(LegalityStatus.notLegal));

      // Vintage
      expect(CardLegality.evaluate(cardLegal, 'VINTAGE').status, equals(LegalityStatus.restricted));

      // Legacy
      expect(CardLegality.evaluate(cardLegal, 'legacy').status, equals(LegalityStatus.banned));

      // Unsupported / custom formats default safely to notLegal with warning
      final resCustom = CardLegality.evaluate(cardLegal, 'canadian_highlander');
      expect(resCustom.status, equals(LegalityStatus.notLegal));
      expect(resCustom.rawStatus, equals('not_legal'));
      expect(resCustom.hasWarning, isTrue);

      final resOathbreaker = CardLegality.evaluate(cardLegal, 'oathbreaker');
      expect(resOathbreaker.status, equals(LegalityStatus.notLegal));
      expect(resOathbreaker.hasWarning, isTrue);

      final resBlankFormat = CardLegality.evaluate(cardLegal, '');
      expect(resBlankFormat.status, equals(LegalityStatus.notLegal));
    });

    test('Vintage Restricted vs Commander Banned vs Modern Not Legal distinction', () {
      // 1. Black Lotus: Restricted in Vintage, Banned in Commander/Legacy, Not Legal in Modern/Standard
      final blackLotusData = jsonEncode({
        'name': 'Black Lotus',
        'legalities': {
          'vintage': 'restricted',
          'commander': 'banned',
          'legacy': 'banned',
          'modern': 'not_legal',
          'standard': 'not_legal',
        }
      });

      final lotusVintage = CardLegality.evaluate(blackLotusData, 'Vintage');
      expect(lotusVintage.status, equals(LegalityStatus.restricted));
      expect(lotusVintage.rawStatus, equals('restricted'));
      expect(lotusVintage.badgeLabel, equals('RESTRICTED'));
      expect(lotusVintage.isRestricted, isTrue);
      expect(lotusVintage.isBanned, isFalse);
      expect(lotusVintage.isLegal, isFalse);
      expect(lotusVintage.isNotLegal, isFalse);
      expect(lotusVintage.hasWarning, isTrue);

      final lotusCommander = CardLegality.evaluate(blackLotusData, 'Commander');
      expect(lotusCommander.status, equals(LegalityStatus.banned));
      expect(lotusCommander.rawStatus, equals('banned'));
      expect(lotusCommander.badgeLabel, equals('BANNED'));
      expect(lotusCommander.isBanned, isTrue);
      expect(lotusCommander.isRestricted, isFalse);
      expect(lotusCommander.isLegal, isFalse);
      expect(lotusCommander.hasWarning, isTrue);

      final lotusModern = CardLegality.evaluate(blackLotusData, 'Modern');
      expect(lotusModern.status, equals(LegalityStatus.notLegal));
      expect(lotusModern.rawStatus, equals('not_legal'));
      expect(lotusModern.badgeLabel, equals('NOT LEGAL'));
      expect(lotusModern.isNotLegal, isTrue);
      expect(lotusModern.hasWarning, isTrue);

      // 2. Sol Ring: Restricted in Vintage, Legal in Commander, Banned in Legacy, Not Legal in Modern
      final solRingData = {
        'name': 'Sol Ring',
        'legalities': {
          'vintage': 'restricted',
          'commander': 'legal',
          'legacy': 'banned',
          'modern': 'not_legal',
        }
      };

      final solVintage = CardLegality.evaluate(solRingData, 'Vintage');
      expect(solVintage.status, equals(LegalityStatus.restricted));
      expect(solVintage.badgeLabel, equals('RESTRICTED'));
      expect(solVintage.hasWarning, isTrue);

      final solCommander = CardLegality.evaluate(solRingData, 'Commander');
      expect(solCommander.status, equals(LegalityStatus.legal));
      expect(solCommander.badgeLabel, equals('LEGAL'));
      expect(solCommander.isLegal, isTrue);
      expect(solCommander.hasWarning, isFalse);

      // 3. Shahrazad: Banned in Vintage, Commander, Legacy
      final shahrazadData = {
        'legalities': {
          'vintage': 'banned',
          'commander': 'banned',
          'legacy': 'banned',
        }
      };
      expect(CardLegality.evaluate(shahrazadData, 'Vintage').isBanned, isTrue);
      expect(CardLegality.evaluate(shahrazadData, 'Commander').isBanned, isTrue);
    });

    test('LegalityEnforcer compute isolate parses bulk items with zero exceptions', () async {
      final items = <VaultItem>[
        createPhase46TestCard(
          id: 'v-1',
          name: 'Legal Card',
          legalities: {'standard': 'legal', 'commander': 'legal'},
        ),
        createPhase46TestCard(
          id: 'v-2',
          name: 'Banned Card',
          legalities: {'standard': 'banned', 'commander': 'legal'},
        ),
        createPhase46TestCard(
          id: 'v-3',
          name: 'Malformed Card 1',
          additionalDynamicData: {'corrupted': true},
        ),
        createPhase46TestCard(
          id: 'v-4',
          name: 'Empty Dynamic Card',
        ),
        createPhase46TestCard(
          id: 'v-5',
          name: 'Restricted Vintage Card',
          legalities: {'vintage': 'restricted'},
        ),
      ];

      // Test Standard
      final stdResult = await LegalityEnforcer.checkLegality('standard', items);
      expect(stdResult.isLegal, isFalse);
      expect(stdResult.violations.any((v) => v.contains('Banned Card')), isTrue);

      // Test Vintage: Restricted is NOT treated as violation at format rule check
      final vintageResult = await LegalityEnforcer.checkLegality('vintage', [items[4]]);
      expect(vintageResult.isLegal, isTrue);
      expect(vintageResult.violations, isEmpty);
    });
  });

  // ===========================================================================
  // GROUP 2: BOARD MOVEMENT ENGINE ADVERSARIAL STRESS TESTS
  // ===========================================================================
  group('Adversarial Group 2: Board Movement Engine Empirical Stress', () {
    late AppDatabase db;
    late VaultDao dao;
    const testDeckId = 'stress-test-deck-1';
    const testVersionId = 'stress-ver-1';

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      dao = db.vaultDao;

      final now = DateTime.now();
      // Insert test deck
      await db.into(db.decks).insert(
        DecksCompanion.insert(
          id: testDeckId,
          name: 'Adversarial Board Deck',
          format: 'Commander',
          createdAt: now,
          isRegistered: const drift.Value(true),
          isAssembled: const drift.Value(true),
          isDeleted: const drift.Value(false),
        ),
      );

      // Insert active deck version
      await db.into(db.deckVersions).insert(
        DeckVersionsCompanion.insert(
          id: testVersionId,
          deckId: testDeckId,
          versionNumber: 1,
          isActive: const drift.Value(true),
          createdAt: now,
          isDeleted: const drift.Value(false),
        ),
      );
    });

    tearDown(() async {
      await db.close();
    });

    Future<String> insertVaultCard({
      required String cardId,
      required String name,
      int quantity = 4,
    }) async {
      final card = createPhase46TestCard(
        id: cardId,
        name: name,
        quantity: quantity,
      );
      await db.into(db.vaultItems).insert(card);
      return cardId;
    }

    Future<String> addCardToBoard({
      required String vaultItemId,
      required String boardZone,
      int quantity = 1,
      bool isProxy = false,
      String? id,
    }) async {
      final dviId = id ?? const Uuid().v4();
      final now = DateTime.now();
      await db.into(db.deckVersionItems).insert(
        DeckVersionItemsCompanion.insert(
          id: dviId,
          versionId: testVersionId,
          vaultItemId: vaultItemId,
          quantity: drift.Value(quantity),
          boardZone: boardZone,
          isProxy: drift.Value(isProxy),
          isDeleted: const drift.Value(false),
          updatedAt: drift.Value(now),
        ),
      );
      return dviId;
    }

    test('Moving card to the SAME board is a completely safe no-op (no duplicates, no deletion)', () async {
      final cardId = await insertVaultCard(cardId: 'card-same-board', name: 'Brainstorm');
      final dviId = await addCardToBoard(vaultItemId: cardId, boardZone: 'Mainboard', quantity: 3);

      // Move to 'Mainboard'
      await dao.moveDeckItemBoard(testDeckId, dviId, 'Mainboard', 2);
      // Move with lowercase and whitespace
      await dao.moveDeckItemBoard(testDeckId, dviId, '  mainboard  ', 3);

      final activeItems = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals(testVersionId) & t.isDeleted.equals(false)))
          .get();

      expect(activeItems.length, equals(1));
      expect(activeItems.first.id, equals(dviId));
      expect(activeItems.first.quantity, equals(3));
      expect(activeItems.first.boardZone, equals('Mainboard'));
    });

    test('Moving 0 or negative copies moves all available copies without data loss', () async {
      final cardId = await insertVaultCard(cardId: 'card-zero-move', name: 'Lightning Bolt');
      final dviId = await addCardToBoard(vaultItemId: cardId, boardZone: 'Mainboard', quantity: 4);

      // Moving 0 copies moves all copies
      await dao.moveDeckItemBoard(testDeckId, dviId, 'Sideboard', 0);

      var activeItems = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals(testVersionId) & t.isDeleted.equals(false)))
          .get();

      expect(activeItems.length, equals(1));
      expect(activeItems.first.boardZone, equals('Sideboard'));
      expect(activeItems.first.quantity, equals(4));

      // Moving negative copies (-5) from Sideboard to Maybeboard moves all copies
      await dao.moveDeckItemBoard(testDeckId, activeItems.first.id, 'Maybeboard', -5);

      activeItems = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals(testVersionId) & t.isDeleted.equals(false)))
          .get();

      expect(activeItems.length, equals(1));
      expect(activeItems.first.boardZone, equals('Maybeboard'));
      expect(activeItems.first.quantity, equals(4));
    });

    test('Moving MORE copies than exist clamps to available quantity and preserves total inventory', () async {
      final cardId = await insertVaultCard(cardId: 'card-clamp-test', name: 'Counterspell');
      final dviId = await addCardToBoard(vaultItemId: cardId, boardZone: 'Mainboard', quantity: 2);

      // Attempt to move 10 copies when only 2 exist
      await dao.moveDeckItemBoard(testDeckId, dviId, 'Sideboard', 10);

      final activeItems = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals(testVersionId) & t.isDeleted.equals(false)))
          .get();

      expect(activeItems.length, equals(1));
      expect(activeItems.first.boardZone, equals('Sideboard'));
      expect(activeItems.first.quantity, equals(2));

      // Attempt to move 999 copies from Sideboard to Commander
      await dao.moveDeckItemBoard(testDeckId, activeItems.first.id, 'Commander', 999);

      final updatedItems = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals(testVersionId) & t.isDeleted.equals(false)))
          .get();

      expect(updatedItems.length, equals(1));
      expect(updatedItems.first.boardZone, equals('Commander'));
      expect(updatedItems.first.quantity, equals(2));
    });

    test('Multi-hop partial quantity movements with consolidation preserve total card count invariant', () async {
      final cardId = await insertVaultCard(cardId: 'card-multihop', name: 'Sol Ring');
      final initialDviId = await addCardToBoard(vaultItemId: cardId, boardZone: 'Mainboard', quantity: 4);

      int getTotalCards(List<DeckVersionItem> items) =>
          items.fold<int>(0, (sum, i) => sum + i.quantity);

      // 1. Move 1 copy from Mainboard to Sideboard
      await dao.moveDeckItemBoard(testDeckId, initialDviId, 'Sideboard', 1, 'Mainboard');
      var items = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals(testVersionId) & t.isDeleted.equals(false)))
          .get();
      expect(items.length, equals(2));
      expect(getTotalCards(items), equals(4));
      expect(items.firstWhere((i) => i.boardZone == 'Mainboard').quantity, equals(3));
      expect(items.firstWhere((i) => i.boardZone == 'Sideboard').quantity, equals(1));

      // 2. Move 1 copy from Mainboard to Maybeboard
      final mainDvi = items.firstWhere((i) => i.boardZone == 'Mainboard');
      await dao.moveDeckItemBoard(testDeckId, mainDvi.id, 'Maybeboard', 1, 'Mainboard');
      items = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals(testVersionId) & t.isDeleted.equals(false)))
          .get();
      expect(items.length, equals(3));
      expect(getTotalCards(items), equals(4));
      expect(items.firstWhere((i) => i.boardZone == 'Mainboard').quantity, equals(2));
      expect(items.firstWhere((i) => i.boardZone == 'Sideboard').quantity, equals(1));
      expect(items.firstWhere((i) => i.boardZone == 'Maybeboard').quantity, equals(1));

      // 3. Move remaining 2 copies from Mainboard to Sideboard (consolidation test!)
      await dao.moveDeckItemBoard(testDeckId, mainDvi.id, 'Sideboard', 2, 'Mainboard');
      items = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals(testVersionId) & t.isDeleted.equals(false)))
          .get();
      expect(items.length, equals(2));
      expect(getTotalCards(items), equals(4));
      expect(items.firstWhere((i) => i.boardZone == 'Sideboard').quantity, equals(3));
      expect(items.firstWhere((i) => i.boardZone == 'Maybeboard').quantity, equals(1));
      expect(items.any((i) => i.boardZone == 'Mainboard'), isFalse);

      // 4. Move 2 copies from Sideboard to Maybeboard (consolidation into Maybeboard)
      final sideDvi = items.firstWhere((i) => i.boardZone == 'Sideboard');
      await dao.moveDeckItemBoard(testDeckId, sideDvi.id, 'Maybeboard', 2, 'Sideboard');
      items = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals(testVersionId) & t.isDeleted.equals(false)))
          .get();
      expect(items.length, equals(2));
      expect(getTotalCards(items), equals(4));
      expect(items.firstWhere((i) => i.boardZone == 'Sideboard').quantity, equals(1));
      expect(items.firstWhere((i) => i.boardZone == 'Maybeboard').quantity, equals(3));

      // 5. Move all 3 copies from Maybeboard to Mainboard
      final maybeDvi = items.firstWhere((i) => i.boardZone == 'Maybeboard');
      await dao.moveDeckItemBoard(testDeckId, maybeDvi.id, 'Mainboard', 3, 'Maybeboard');
      items = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals(testVersionId) & t.isDeleted.equals(false)))
          .get();
      expect(items.length, equals(2));
      expect(getTotalCards(items), equals(4));
      expect(items.firstWhere((i) => i.boardZone == 'Mainboard').quantity, equals(3));
      expect(items.firstWhere((i) => i.boardZone == 'Sideboard').quantity, equals(1));

      // 6. Move the 1 copy from Sideboard to Mainboard (final consolidation back to 4 in Mainboard)
      final lastSideDvi = items.firstWhere((i) => i.boardZone == 'Sideboard');
      await dao.moveDeckItemBoard(testDeckId, lastSideDvi.id, 'Mainboard', 1, 'Sideboard');
      items = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals(testVersionId) & t.isDeleted.equals(false)))
          .get();
      expect(items.length, equals(1));
      expect(getTotalCards(items), equals(4));
      expect(items.first.boardZone, equals('Mainboard'));
      expect(items.first.quantity, equals(4));
    });

    test('Proxy items and Physical items are strictly isolated and never merged during moves', () async {
      final cardId = await insertVaultCard(cardId: 'card-proxy-iso', name: 'Mox Diamond');
      final physicalDviId = await addCardToBoard(
        vaultItemId: cardId,
        boardZone: 'Mainboard',
        quantity: 2,
        isProxy: false,
      );
      final proxyDviId = await addCardToBoard(
        vaultItemId: cardId,
        boardZone: 'Mainboard',
        quantity: 3,
        isProxy: true,
      );

      // Move 2 proxy copies to Sideboard
      await dao.moveDeckItemBoard(testDeckId, proxyDviId, 'Sideboard', 2, 'Mainboard');

      var items = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals(testVersionId) & t.isDeleted.equals(false)))
          .get();

      // Mainboard should have 2 physical + 1 proxy. Sideboard should have 2 proxy.
      expect(items.length, equals(3));
      final mainPhysical = items.firstWhere((i) => i.boardZone == 'Mainboard' && !i.isProxy);
      final mainProxy = items.firstWhere((i) => i.boardZone == 'Mainboard' && i.isProxy);
      final sideProxy = items.firstWhere((i) => i.boardZone == 'Sideboard' && i.isProxy);

      expect(mainPhysical.quantity, equals(2));
      expect(mainProxy.quantity, equals(1));
      expect(sideProxy.quantity, equals(2));

      // Now move 1 physical copy to Sideboard. Sideboard should now have 1 physical AND 2 proxy (separate rows!)
      await dao.moveDeckItemBoard(testDeckId, physicalDviId, 'Sideboard', 1, 'Mainboard');

      items = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals(testVersionId) & t.isDeleted.equals(false)))
          .get();

      expect(items.length, equals(4));
      final sidePhysical = items.firstWhere((i) => i.boardZone == 'Sideboard' && !i.isProxy);
      final updatedSideProxy = items.firstWhere((i) => i.boardZone == 'Sideboard' && i.isProxy);

      expect(sidePhysical.quantity, equals(1));
      expect(updatedSideProxy.quantity, equals(2));

      // Now move the remaining 1 proxy from Mainboard to Sideboard
      await dao.moveDeckItemBoard(testDeckId, mainProxy.id, 'Sideboard', 1, 'Mainboard');

      items = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals(testVersionId) & t.isDeleted.equals(false)))
          .get();

      // Sideboard should have: 1 physical (quantity 1) and 1 consolidated proxy (quantity 3)
      final finalSidePhysical = items.firstWhere((i) => i.boardZone == 'Sideboard' && !i.isProxy);
      final finalSideProxy = items.firstWhere((i) => i.boardZone == 'Sideboard' && i.isProxy);
      expect(finalSidePhysical.quantity, equals(1));
      expect(finalSideProxy.quantity, equals(3));

      // Total items across deck must still be exactly 5 (2 physical + 3 proxy)
      final totalQty = items.fold<int>(0, (sum, i) => sum + i.quantity);
      expect(totalQty, equals(5));
    });

    test('Sequential multi-card board transfer stress test preserves 40 cards invariant', () async {
      // Create 10 distinct cards, each with 4 copies in Mainboard (total 40 cards)
      final cardDviIds = <String>[];
      for (int i = 0; i < 10; i++) {
        final cId = await insertVaultCard(cardId: 'seq-card-$i', name: 'SeqCard $i');
        final dId = await addCardToBoard(vaultItemId: cId, boardZone: 'Mainboard', quantity: 4);
        cardDviIds.add(dId);
      }

      // Execute 30 sequential transfers across boards
      final targets = ['Sideboard', 'Maybeboard', 'Mainboard'];
      for (int op = 0; op < 30; op++) {
        final targetDvi = cardDviIds[op % cardDviIds.length];
        final targetBoard = targets[op % targets.length];
        await dao.moveDeckItemBoard(testDeckId, targetDvi, targetBoard, 1);
      }

      final allItems = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals(testVersionId) & t.isDeleted.equals(false)))
          .get();

      final totalCopies = allItems.fold<int>(0, (sum, i) => sum + i.quantity);
      expect(totalCopies, equals(40));
    });

    test('Concurrent board transfer TOCTOU race condition creates phantom cards (VULNERABILITY)', () async {
      final cardId = await insertVaultCard(cardId: 'card-race-minimal', name: 'Lightning Greaves', quantity: 4);
      final dviId = await addCardToBoard(vaultItemId: cardId, boardZone: 'Mainboard', quantity: 4);

      // Concurrently move 1 copy twice from Mainboard to Sideboard
      await Future.wait([
        dao.moveDeckItemBoard(testDeckId, dviId, 'Sideboard', 1),
        dao.moveDeckItemBoard(testDeckId, dviId, 'Sideboard', 1),
      ]);

      final activeItems = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals(testVersionId) & t.isDeleted.equals(false)))
          .get();

      final totalCopies = activeItems.fold<int>(0, (sum, i) => sum + i.quantity);
      // Expected invariant: Total copies must strictly remain 4 (2 in Mainboard, 2 in Sideboard).
      // Bug finding: Because `candidates`, `sourceItem`, and `moveQty` are queried/computed outside
      // `transaction(() async { ... })` in VaultDao.moveDeckItemBoard, Task B reads stale quantity=4,
      // setting Mainboard quantity to 4 - 1 = 3 while Sideboard gets 1 + 1 = 2 (total 5 copies).
      expect(
        totalCopies,
        equals(4),
        reason: 'Concurrency TOCTOU race: sourceItem read outside transaction in moveDeckItemBoard caused phantom card creation (expected 4, got $totalCopies)',
      );
    });

    test('SyncQueue records audit entries for board moves', () async {
      final cardId = await insertVaultCard(cardId: 'card-sync-audit', name: 'Demonic Tutor');
      final dviId = await addCardToBoard(vaultItemId: cardId, boardZone: 'Mainboard', quantity: 2);

      // Move 1 copy to Sideboard (triggers UPDATE on source and INSERT on target)
      await dao.moveDeckItemBoard(testDeckId, dviId, 'Sideboard', 1);

      final syncRows = await (db.select(db.syncQueue)
            ..where((t) => t.entityType.equals('deck_version_item')))
          .get();

      expect(syncRows.isNotEmpty, isTrue);
      expect(syncRows.any((r) => r.operation == 'UPDATE'), isTrue);
      expect(syncRows.any((r) => r.operation == 'INSERT'), isTrue);
    });
  });

  // ===========================================================================
  // GROUP 3: CUSTOM SCROLLBAR ADVERSARIAL STRESS TESTS
  // ===========================================================================
  group('Adversarial Group 3: Proportional Bubble Scrollbar Stress', () {
    test('Water-filling algorithm boundary resilience (zero, negative, extreme disparity, fuzzing)', () {
      // 1. Boundary: empty counts
      expect(ProportionalBubbleScrollbar.computeSectionHeights(counts: [], totalHeight: 300.0), isEmpty);

      // 2. Boundary: zero or negative height
      expect(ProportionalBubbleScrollbar.computeSectionHeights(counts: [10, 20], totalHeight: 0.0), isEmpty);
      expect(ProportionalBubbleScrollbar.computeSectionHeights(counts: [10, 20], totalHeight: -150.0), isEmpty);

      // 3. Boundary: single section gets 100% of height
      final singleRes = ProportionalBubbleScrollbar.computeSectionHeights(
        counts: [42],
        totalHeight: 500.0,
      );
      expect(singleRes.length, equals(1));
      expect(singleRes.first, equals(500.0));

      // 4. Extreme 1:1,000,000 ratio
      final extremeRes = ProportionalBubbleScrollbar.computeSectionHeights(
        counts: [1000000, 1, 1, 1],
        totalHeight: 300.0,
        minHeight: 24.0,
      );
      expect(extremeRes.length, equals(4));
      // The 3 small sections each clamp to 24.0
      expect(extremeRes[1], equals(24.0));
      expect(extremeRes[2], equals(24.0));
      expect(extremeRes[3], equals(24.0));
      // Large section receives remaining 300 - (3 * 24) = 228.0
      expect(extremeRes[0], equals(228.0));
      final totalSum = extremeRes.fold<double>(0.0, (sum, h) => sum + h);
      expect(totalSum, closeTo(300.0, 1e-6));

      // 5. Dense rail guard: 25 sections on 300px rail (25 * 24 = 600 > 300)
      final denseRes = ProportionalBubbleScrollbar.computeSectionHeights(
        counts: List.filled(25, 2),
        totalHeight: 300.0,
        minHeight: 24.0,
      );
      expect(denseRes.length, equals(25));
      for (final h in denseRes) {
        expect(h, equals(12.0)); // 300 / 25
      }
      expect(denseRes.fold<double>(0.0, (s, h) => s + h), closeTo(300.0, 1e-6));

      // 6. Invariant fuzzing: 500 randomized trials
      final rng = math.Random(1337);
      for (int i = 0; i < 500; i++) {
        final n = rng.nextInt(20) + 1; // 1 to 20 sections
        final counts = List.generate(n, (_) => rng.nextInt(10000) + 1);
        final height = rng.nextDouble() * 1000.0 + 10.0;
        final res = ProportionalBubbleScrollbar.computeSectionHeights(
          counts: counts,
          totalHeight: height,
          minHeight: 24.0,
        );
        expect(res.length, equals(n));
        final sum = res.fold<double>(0.0, (acc, val) => acc + val);
        expect(sum, closeTo(height, 1e-5), reason: 'Failed conservation on fuzz run $i');
      }
    });

    testWidgets('Scrollbar Auto-Hide timer lifecycle, inactivity fading, and scroll wakeups', (tester) async {
      final scrollController = ScrollController();
      final sections = [
        ScrollbarSection(label: 'Commander', count: 1, onTap: () {}),
        ScrollbarSection(label: 'Spells', count: 30, onTap: () {}),
        ScrollbarSection(label: 'Lands', count: 30, onTap: () {}),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 400,
              child: Row(
                children: [
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: 100,
                      itemExtent: 40.0,
                      itemBuilder: (ctx, i) => Text('Row $i'),
                    ),
                  ),
                  SizedBox(
                    height: 400,
                    width: 26,
                    child: ProportionalBubbleScrollbar(
                      sections: sections,
                      controller: scrollController,
                      autoHide: true,
                      hideDelay: const Duration(milliseconds: 1500),
                      fadeDuration: const Duration(milliseconds: 300),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final fadeAnimationFinder = find.byKey(const Key('scrollbar_fade_animation'));
      expect(fadeAnimationFinder, findsOneWidget);

      // 1. Initially visible (opacity = 1.0)
      var animatedOpacity = tester.widget<AnimatedOpacity>(fadeAnimationFinder);
      expect(animatedOpacity.opacity, equals(1.0));

      // 2. Inactivity: advance time past 1500ms hide delay -> opacity triggers fade to 0.0
      await tester.pump(const Duration(milliseconds: 1600));
      animatedOpacity = tester.widget<AnimatedOpacity>(fadeAnimationFinder);
      expect(animatedOpacity.opacity, equals(0.0));

      // 3. User scrolls: controller listener triggers immediate wakeup to opacity 1.0
      scrollController.jumpTo(100.0);
      await tester.pump();
      animatedOpacity = tester.widget<AnimatedOpacity>(fadeAnimationFinder);
      expect(animatedOpacity.opacity, equals(1.0));

      // 4. Reset timer during active scrolling: advance 1000ms (<1500ms), scroll again
      await tester.pump(const Duration(milliseconds: 1000));
      scrollController.jumpTo(200.0);
      await tester.pump();

      // Still visible after another 1000ms because timer was reset!
      await tester.pump(const Duration(milliseconds: 1000));
      animatedOpacity = tester.widget<AnimatedOpacity>(fadeAnimationFinder);
      expect(animatedOpacity.opacity, equals(1.0));

      // 5. Now wait 1600ms without scrolling -> fades out
      await tester.pump(const Duration(milliseconds: 1600));
      animatedOpacity = tester.widget<AnimatedOpacity>(fadeAnimationFinder);
      expect(animatedOpacity.opacity, equals(0.0));

      // 6. Pointer down on scrollbar wakes up immediately
      final scrollbarFinder = find.byType(ProportionalBubbleScrollbar);
      await tester.tap(scrollbarFinder);
      await tester.pump();
      animatedOpacity = tester.widget<AnimatedOpacity>(fadeAnimationFinder);
      expect(animatedOpacity.opacity, equals(1.0));
    });

    testWidgets('Active thumb indicator handles extreme negative and excessive scroll offsets cleanly', (tester) async {
      final scrollController = ScrollController();
      final sections = [
        ScrollbarSection(label: 'Creatures', count: 40, onTap: () {}),
        ScrollbarSection(label: 'Lands', count: 40, onTap: () {}),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 300,
              child: Row(
                children: [
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: 100,
                      itemExtent: 50.0,
                      itemBuilder: (ctx, i) => Text('Item $i'),
                    ),
                  ),
                  SizedBox(
                    height: 300,
                    width: 26,
                    child: ProportionalBubbleScrollbar(
                      sections: sections,
                      controller: scrollController,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final thumbFinder = find.byKey(const Key('scrollbar_thumb'));
      expect(thumbFinder, findsOneWidget);

      // Extreme negative scroll offset (e.g. overscroll bounce)
      scrollController.jumpTo(-500.0);
      await tester.pump();
      expect(tester.takeException(), isNull);
      var thumbRect = tester.getRect(thumbFinder);
      expect(thumbRect.top, equals(0.0));

      // Extreme excessive scroll offset (e.g. fast fling past bounds)
      scrollController.jumpTo(999999.0);
      await tester.pump();
      expect(tester.takeException(), isNull);
      thumbRect = tester.getRect(thumbFinder);
      expect(thumbRect.bottom, closeTo(300.0, 1.0));
    });

    testWidgets('Rapid drag scrubbing gestures above and below rail clamp strictly to [0, maxExtent]', (tester) async {
      final scrollController = ScrollController();
      final scrubValues = <double>[];
      final sections = [
        ScrollbarSection(label: 'Main', count: 60, onTap: () {}),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 400,
              child: Row(
                children: [
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: 150,
                      itemExtent: 40.0,
                      itemBuilder: (ctx, i) => Text('Row $i'),
                    ),
                  ),
                  SizedBox(
                    height: 400,
                    width: 26,
                    child: ProportionalBubbleScrollbar(
                      sections: sections,
                      controller: scrollController,
                      onScrubUpdate: (val) => scrubValues.add(val),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      final maxExtent = scrollController.position.maxScrollExtent;
      final railCenter = tester.getCenter(find.byType(ProportionalBubbleScrollbar));
      final gesture = await tester.startGesture(railCenter);

      // Violent scrub upwards (past rail top)
      await gesture.moveBy(const Offset(0, -800));
      await tester.pump();
      expect(scrollController.offset, equals(0.0));
      expect(scrubValues.last, equals(0.0));

      // Violent scrub downwards (past rail bottom)
      await gesture.moveBy(const Offset(0, 1600));
      await tester.pump();
      expect(scrollController.offset, equals(maxExtent));
      expect(scrubValues.last, equals(maxExtent));

      // Rapid zig-zag dragging
      for (int i = 0; i < 10; i++) {
        final dy = (i % 2 == 0) ? -200.0 : 200.0;
        await gesture.moveBy(Offset(0, dy));
        await tester.pump();
        expect(scrollController.offset, greaterThanOrEqualTo(0.0));
        expect(scrollController.offset, lessThanOrEqualTo(maxExtent));
      }

      await gesture.up();
      await tester.pump();
    });

    testWidgets('DeckBuilderScreen tile layout with Banned/Restricted badges and 2.0x font scaling has ZERO RenderFlex overflows', (tester) async {
      // Stress test: 320px viewport with 2.0x accessibility font scale
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final deck = createTestDeck(
        id: 'deck-stress-320',
        name: 'Urza Lord High Artificer Extreme Long Deck Title',
        format: 'Vintage',
      );

      final stressCards = <Map<String, dynamic>>[
        {
          'id': 'card-banned-stress',
          'name': 'Black Lotus Power Nine Ancestral Recall Artifact',
          'board_zone': 'Mainboard',
          'deck_quantity': 1,
          'vault_quantity': 1,
          'set_or_series': 'LEA',
          'dynamic_data': jsonEncode({
            'mana_cost': '{0}',
            'type_line': 'Artifact',
            'legalities': {'vintage': 'restricted', 'commander': 'banned'},
            'image_uris': {'small': 'https://cards.scryfall.io/small/1.jpg'},
          }),
          'current_market_price': 25000.0,
          'is_proxy': 0,
        },
        {
          'id': 'card-cost-stress',
          'name': 'Progenitus Soul of the World Avatar',
          'board_zone': 'Mainboard',
          'deck_quantity': 4,
          'vault_quantity': 4,
          'set_or_series': 'CON',
          'dynamic_data': jsonEncode({
            'mana_cost': '{W}{W}{U}{U}{B}{B}{R}{R}{G}{G}',
            'type_line': 'Legendary Creature — Hydra Avatar',
            'legalities': {'vintage': 'legal'},
            'image_uris': {'small': 'https://cards.scryfall.io/small/2.jpg'},
          }),
          'current_market_price': 15.0,
          'is_proxy': 0,
        },
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deckItemsProvider(deck.id).overrideWith(
              (ref) => Stream.value(stressCards),
            ),
          ],
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 600),
                textScaler: TextScaler.linear(2.0),
              ),
              child: DeckBuilderScreen(deck: deck),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Zero exceptions and zero RenderFlex overflows
      expect(tester.takeException(), isNull);

      // Verify RESTRICTED badge is rendered
      final badgeFinder = find.byKey(const Key('card_legality_badge_card-banned-stress'));
      expect(badgeFinder, findsOneWidget);
      expect(find.text('RESTRICTED'), findsOneWidget);
    });
  });
}
