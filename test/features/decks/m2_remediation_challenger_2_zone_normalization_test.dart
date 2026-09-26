import 'dart:math' as math;
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late VaultDao dao;

  const testDeckId = 'deck-zone-norm-test';
  const testVersionId = 'ver-zone-norm-test';

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dao = db.vaultDao;
    await dao.clearAllItems();

    final now = DateTime.now();
    await db.into(db.decks).insert(
      DecksCompanion(
        id: const drift.Value(testDeckId),
        name: const drift.Value('Zone Normalization Test Deck'),
        format: const drift.Value('Commander'),
        tcgDomain: const drift.Value('mtg'),
        isRegistered: const drift.Value(true),
        isAssembled: const drift.Value(true),
        isCompetitive: const drift.Value(false),
        isDeleted: const drift.Value(false),
        createdAt: drift.Value(now),
        updatedAt: drift.Value(now),
      ),
    );

    await db.into(db.deckVersions).insert(
      DeckVersionsCompanion(
        id: const drift.Value(testVersionId),
        deckId: const drift.Value(testDeckId),
        versionNumber: const drift.Value(1),
        isActive: const drift.Value(true),
        isDeleted: const drift.Value(false),
        createdAt: drift.Value(now),
        updatedAt: drift.Value(now),
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
    final now = DateTime.now();
    await db.into(db.vaultItems).insert(
      VaultItemsCompanion(
        id: drift.Value(cardId),
        collectionType: const drift.Value('mtg'),
        name: drift.Value(name),
        setOrSeries: const drift.Value('LTR'),
        imageUrl: drift.Value('https://cards.scryfall.io/art_crop/$cardId.jpg'),
        currentMarketPrice: const drift.Value(5.0),
        acquiredPrice: const drift.Value(4.0),
        acquiredDate: drift.Value(now),
        lastPriceUpdate: drift.Value(now),
        condition: const drift.Value('NM'),
        quantity: drift.Value(quantity),
        isDeleted: const drift.Value(false),
        updatedAt: drift.Value(now),
        dynamicData: const drift.Value('{"color_identity":["U"]}'),
      ),
    );
    return cardId;
  }

  Future<String> addCardToBoardRaw({
    required String vaultItemId,
    required String rawBoardZone,
    int quantity = 1,
    bool isProxy = false,
  }) async {
    final dviId = const Uuid().v4();
    final now = DateTime.now();
    await db.into(db.deckVersionItems).insert(
      DeckVersionItemsCompanion(
        id: drift.Value(dviId),
        versionId: const drift.Value(testVersionId),
        vaultItemId: drift.Value(vaultItemId),
        quantity: drift.Value(quantity),
        boardZone: drift.Value(rawBoardZone),
        isProxy: drift.Value(isProxy),
        isDeleted: const drift.Value(false),
        updatedAt: drift.Value(now),
      ),
    );
    return dviId;
  }

  // ===========================================================================
  // GROUP 1: TARGET BOARD SHORTHAND & CASING NORMALIZATION PERMUTATIONS
  // ===========================================================================
  group('Adversarial Group 1: Target Board Shorthand & Casing Normalization', () {
    final sideAliases = [
      'side', 'sb', 'SIDE', 'SB', 'Side', 'sB',
      'Sideboard', 'SIDEBOARD', '  side  ', '\tsb\n', '  Sideboard  ', 'SiDeBoArD'
    ];

    for (final alias in sideAliases) {
      test('Target argument "$alias" cleanly normalizes to canonical "Sideboard"', () async {
        final cardId = await insertVaultCard(cardId: 'card-side-${alias.trim().toLowerCase()}', name: 'Test Card');
        final dviId = await addCardToBoardRaw(vaultItemId: cardId, rawBoardZone: 'Mainboard', quantity: 2);

        await dao.moveDeckItemBoard(testDeckId, dviId, alias, 1);

        final items = await (db.select(db.deckVersionItems)
              ..where((t) => t.versionId.equals(testVersionId) & t.isDeleted.equals(false)))
            .get();

        expect(items.length, equals(2));
        final sideItem = items.firstWhere((i) => i.id != dviId);
        expect(sideItem.boardZone, equals('Sideboard'),
            reason: 'Target alias "$alias" should produce canonical "Sideboard"');
        expect(sideItem.quantity, equals(1));

        final sourceItem = items.firstWhere((i) => i.id == dviId);
        expect(sourceItem.boardZone, equals('Mainboard'));
        expect(sourceItem.quantity, equals(1));
      });
    }

    final maybeAliases = [
      'maybe', 'mb', 'MAYBE', 'MB', 'Maybe', 'mB',
      'Maybeboard', 'MAYBEBOARD', '  maybe  ', ' \tmb\t ', '  Maybeboard  ', 'mAyBeBoArD'
    ];

    for (final alias in maybeAliases) {
      test('Target argument "$alias" cleanly normalizes to canonical "Maybeboard"', () async {
        final cardId = await insertVaultCard(cardId: 'card-mb-${alias.trim().toLowerCase()}', name: 'Test Card');
        final dviId = await addCardToBoardRaw(vaultItemId: cardId, rawBoardZone: 'Mainboard', quantity: 2);

        await dao.moveDeckItemBoard(testDeckId, dviId, alias, 1);

        final items = await (db.select(db.deckVersionItems)
              ..where((t) => t.versionId.equals(testVersionId) & t.isDeleted.equals(false)))
            .get();

        expect(items.length, equals(2));
        final mbItem = items.firstWhere((i) => i.id != dviId);
        expect(mbItem.boardZone, equals('Maybeboard'),
            reason: 'Target alias "$alias" should produce canonical "Maybeboard"');
        expect(mbItem.quantity, equals(1));
      });
    }

    final cmdAliases = [
      'cmd', 'command', 'CMD', 'COMMAND', 'Cmd', 'cOmMaNd',
      'Commander', 'COMMANDER', '  cmd  ', '  command  ', '  Commander  '
    ];

    for (final alias in cmdAliases) {
      test('Target argument "$alias" cleanly normalizes to canonical "Commander"', () async {
        final cardId = await insertVaultCard(cardId: 'card-cmd-${alias.trim().toLowerCase()}', name: 'Test Card');
        final dviId = await addCardToBoardRaw(vaultItemId: cardId, rawBoardZone: 'Mainboard', quantity: 1);

        await dao.moveDeckItemBoard(testDeckId, dviId, alias, 1);

        final items = await (db.select(db.deckVersionItems)
              ..where((t) => t.versionId.equals(testVersionId) & t.isDeleted.equals(false)))
            .get();

        expect(items.length, equals(1));
        expect(items.first.boardZone, equals('Commander'),
            reason: 'Target alias "$alias" should produce canonical "Commander"');
        expect(items.first.quantity, equals(1));
      });
    }

    final mainAliases = [
      'main', 'deck', 'primary', 'MAIN', 'DECK', 'PRIMARY',
      'Main', 'Deck', 'Primary', '  main  ', '  deck  ', '  primary  ',
      'Mainboard', 'MAINBOARD', 'MaInBoArD'
    ];

    for (final alias in mainAliases) {
      test('Target argument "$alias" cleanly normalizes to canonical "Mainboard"', () async {
        final cardId = await insertVaultCard(cardId: 'card-main-${alias.trim().toLowerCase()}', name: 'Test Card');
        final dviId = await addCardToBoardRaw(vaultItemId: cardId, rawBoardZone: 'Sideboard', quantity: 2);

        await dao.moveDeckItemBoard(testDeckId, dviId, alias, 1);

        final items = await (db.select(db.deckVersionItems)
              ..where((t) => t.versionId.equals(testVersionId) & t.isDeleted.equals(false)))
            .get();

        expect(items.length, equals(2));
        final mainItem = items.firstWhere((i) => i.id != dviId);
        expect(mainItem.boardZone, equals('Mainboard'),
            reason: 'Target alias "$alias" should produce canonical "Mainboard"');
        expect(mainItem.quantity, equals(1));
      });
    }

    final compAliases = [
      'comp', 'companion', 'COMP', 'COMPANION', 'Comp', '  comp  ', 'Companion'
    ];

    for (final alias in compAliases) {
      test('Target argument "$alias" cleanly normalizes to canonical "Companion"', () async {
        final cardId = await insertVaultCard(cardId: 'card-comp-${alias.trim().toLowerCase()}', name: 'Test Card');
        final dviId = await addCardToBoardRaw(vaultItemId: cardId, rawBoardZone: 'Mainboard', quantity: 1);

        await dao.moveDeckItemBoard(testDeckId, dviId, alias, 1);

        final items = await (db.select(db.deckVersionItems)
              ..where((t) => t.versionId.equals(testVersionId) & t.isDeleted.equals(false)))
            .get();

        expect(items.length, equals(1));
        expect(items.first.boardZone, equals('Companion'),
            reason: 'Target alias "$alias" should produce canonical "Companion"');
      });
    }
  });

  // ===========================================================================
  // GROUP 2: SOURCE BOARD SHORTHAND & CASING DISCOVERY
  // ===========================================================================
  group('Adversarial Group 2: Source Board Shorthand & Casing Discovery', () {
    test('Moves card when itemId is vaultItemId and sourceBoard is shorthand alias', () async {
      final cardId = await insertVaultCard(cardId: 'card-source-alias', name: 'Sol Ring', quantity: 6);
      await addCardToBoardRaw(vaultItemId: cardId, rawBoardZone: 'Sideboard', quantity: 2);
      await addCardToBoardRaw(vaultItemId: cardId, rawBoardZone: 'Mainboard', quantity: 3);
      await addCardToBoardRaw(vaultItemId: cardId, rawBoardZone: 'Maybeboard', quantity: 1);

      // Move 1 copy specifically from Sideboard to Maybeboard using shorthand 'sb'
      await dao.moveDeckItemBoard(testDeckId, cardId, 'mb', 1, 'sb');

      final items = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals(testVersionId) & t.isDeleted.equals(false)))
          .get();

      final sideItem = items.firstWhere((i) => i.boardZone == 'Sideboard');
      final mainItem = items.firstWhere((i) => i.boardZone == 'Mainboard');
      final mbItem = items.firstWhere((i) => i.boardZone == 'Maybeboard');

      expect(sideItem.quantity, equals(1), reason: 'Sideboard should have decremented from 2 to 1');
      expect(mainItem.quantity, equals(3), reason: 'Mainboard should have remained untouched at 3');
      expect(mbItem.quantity, equals(2), reason: 'Maybeboard should have incremented from 1 to 2');
    });

    test('Moves card when source row in DB has alias "cmd" and sourceBoard argument is "commander"', () async {
      final cardId = await insertVaultCard(cardId: 'card-db-cmd-alias', name: 'Atraxa', quantity: 2);
      await addCardToBoardRaw(vaultItemId: cardId, rawBoardZone: 'cmd', quantity: 1);
      await addCardToBoardRaw(vaultItemId: cardId, rawBoardZone: 'Mainboard', quantity: 1);

      // Move from Commander to Sideboard specifying sourceBoard = 'COMMANDER'
      await dao.moveDeckItemBoard(testDeckId, cardId, 'side', 1, 'COMMANDER');

      final items = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals(testVersionId) & t.isDeleted.equals(false)))
          .get();

      final mainItem = items.firstWhere((i) => i.boardZone == 'Mainboard');
      final sideItem = items.firstWhere((i) => i.boardZone == 'Sideboard');

      expect(mainItem.quantity, equals(1));
      expect(sideItem.quantity, equals(1));
      expect(items.any((i) => i.boardZone == 'cmd' || i.boardZone == 'Commander'), isFalse);
    });

    test('Source board with leading/trailing whitespace correctly targets intended board', () async {
      final cardId = await insertVaultCard(cardId: 'card-source-ws', name: 'Rhystic Study', quantity: 4);
      await addCardToBoardRaw(vaultItemId: cardId, rawBoardZone: 'Maybeboard', quantity: 2);
      await addCardToBoardRaw(vaultItemId: cardId, rawBoardZone: 'Mainboard', quantity: 2);

      await dao.moveDeckItemBoard(testDeckId, cardId, 'main', 1, '   maybe   ');

      final items = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals(testVersionId) & t.isDeleted.equals(false)))
          .get();

      final mb = items.firstWhere((i) => i.boardZone == 'Maybeboard');
      final main = items.firstWhere((i) => i.boardZone == 'Mainboard');

      expect(mb.quantity, equals(1));
      expect(main.quantity, equals(3));
    });
  });

  // ===========================================================================
  // GROUP 3: NO-OP SAME-BOARD SHORT-CIRCUITING
  // ===========================================================================
  group('Adversarial Group 3: Same-Board No-Op Invariants', () {
    test('Moving from Sideboard to "side", "sb", "SIDE", or "  sb  " is a strict no-op', () async {
      final cardId = await insertVaultCard(cardId: 'card-noop-side', name: 'Force of Will', quantity: 2);
      final dviId = await addCardToBoardRaw(vaultItemId: cardId, rawBoardZone: 'Sideboard', quantity: 2);

      final noopAliases = ['side', 'sb', 'SIDE', 'SB', '  sb  ', 'Sideboard'];
      for (final alias in noopAliases) {
        await dao.moveDeckItemBoard(testDeckId, dviId, alias, 1);
      }

      final items = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals(testVersionId) & t.isDeleted.equals(false)))
          .get();

      expect(items.length, equals(1));
      expect(items.first.id, equals(dviId));
      expect(items.first.quantity, equals(2));
      expect(items.first.boardZone, equals('Sideboard'));

      // No redundant records in sync queue for no-ops
      final syncRows = await (db.select(db.syncQueue)
            ..where((t) => t.entityType.equals('deck_version_item')))
          .get();
      expect(syncRows.isEmpty, isTrue);
    });

    test('Moving from raw DB zone "deck" to target "primary" is recognized as same-board no-op', () async {
      final cardId = await insertVaultCard(cardId: 'card-noop-main', name: 'Brainstorm', quantity: 4);
      final dviId = await addCardToBoardRaw(vaultItemId: cardId, rawBoardZone: 'deck', quantity: 4);

      await dao.moveDeckItemBoard(testDeckId, dviId, 'primary', 2);

      final items = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals(testVersionId) & t.isDeleted.equals(false)))
          .get();

      expect(items.length, equals(1));
      expect(items.first.quantity, equals(4));
    });
  });

  // ===========================================================================
  // GROUP 4: DESTINATION ROW CONSOLIDATION WITH DIVERGENT CASING & ALIASES
  // ===========================================================================
  group('Adversarial Group 4: Destination Row Consolidation with Divergent Casing & Aliases', () {
    test('Consolidates when target row in DB has shorthand "sb" and target arg is "Sideboard"', () async {
      final cardId = await insertVaultCard(cardId: 'card-cons-sb', name: 'Swords to Plowshares', quantity: 4);
      final targetDviId = await addCardToBoardRaw(vaultItemId: cardId, rawBoardZone: 'sb', quantity: 2);
      final sourceDviId = await addCardToBoardRaw(vaultItemId: cardId, rawBoardZone: 'Mainboard', quantity: 2);

      // Move 1 copy from Mainboard to 'Sideboard'
      await dao.moveDeckItemBoard(testDeckId, sourceDviId, 'Sideboard', 1);

      final activeItems = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals(testVersionId) & t.isDeleted.equals(false)))
          .get();

      // Invariant 1: Exactly 2 active rows (no 3rd duplicate row created!)
      expect(activeItems.length, equals(2),
          reason: 'Existing target row with zone "sb" must be consolidated, not duplicated');

      // Invariant 2: Target row consolidated, quantity incremented, zone canonicalized
      final targetItem = activeItems.firstWhere((i) => i.id == targetDviId);
      expect(targetItem.quantity, equals(3));
      expect(targetItem.boardZone, equals('Sideboard'),
          reason: 'Target zone should be canonicalized from "sb" to "Sideboard"');

      // Invariant 3: Source row decremented
      final sourceItem = activeItems.firstWhere((i) => i.id == sourceDviId);
      expect(sourceItem.quantity, equals(1));

      // Invariant 4: Total quantity conserved
      final totalQty = activeItems.fold<int>(0, (sum, i) => sum + i.quantity);
      expect(totalQty, equals(4));

      // Invariant 5: SyncQueue logged updates
      final syncRows = await (db.select(db.syncQueue)
            ..where((t) => t.entityType.equals('deck_version_item')))
          .get();
      expect(syncRows.any((r) => r.entityId == targetDviId && r.operation == 'UPDATE'), isTrue);
      expect(syncRows.any((r) => r.entityId == sourceDviId && r.operation == 'UPDATE'), isTrue);
    });

    test('Consolidates when target row in DB has uppercase "SIDEBOARD" and target arg is shorthand "side"', () async {
      final cardId = await insertVaultCard(cardId: 'card-cons-upper-side', name: 'Counterspell', quantity: 3);
      final targetDviId = await addCardToBoardRaw(vaultItemId: cardId, rawBoardZone: 'SIDEBOARD', quantity: 1);
      final sourceDviId = await addCardToBoardRaw(vaultItemId: cardId, rawBoardZone: 'Mainboard', quantity: 2);

      // Move ALL 2 copies from Mainboard to 'side'
      await dao.moveDeckItemBoard(testDeckId, sourceDviId, 'side', 2);

      final activeItems = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals(testVersionId) & t.isDeleted.equals(false)))
          .get();

      // Invariant: Source exhausted, target consolidated -> exactly 1 active row!
      expect(activeItems.length, equals(1));
      expect(activeItems.first.id, equals(targetDviId));
      expect(activeItems.first.quantity, equals(3));
      expect(activeItems.first.boardZone, equals('Sideboard'));

      // Check soft-delete on source
      final deletedSource = await (db.select(db.deckVersionItems)
            ..where((t) => t.id.equals(sourceDviId)))
          .getSingle();
      expect(deletedSource.isDeleted, isTrue);

      // SyncQueue logged DELETE for source
      final syncRows = await (db.select(db.syncQueue)
            ..where((t) => t.entityId.equals(sourceDviId)))
          .get();
      expect(syncRows.any((r) => r.operation == 'DELETE'), isTrue);
    });

    test('Consolidates when target row has "mb" and target arg is "  MAYBE  "', () async {
      final cardId = await insertVaultCard(cardId: 'card-cons-mb', name: 'Teferi\'s Protection', quantity: 3);
      final targetDviId = await addCardToBoardRaw(vaultItemId: cardId, rawBoardZone: 'mb', quantity: 1);
      final sourceDviId = await addCardToBoardRaw(vaultItemId: cardId, rawBoardZone: 'Sideboard', quantity: 2);

      await dao.moveDeckItemBoard(testDeckId, sourceDviId, '  MAYBE  ', 1);

      final activeItems = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals(testVersionId) & t.isDeleted.equals(false)))
          .get();

      expect(activeItems.length, equals(2));
      final targetItem = activeItems.firstWhere((i) => i.id == targetDviId);
      expect(targetItem.quantity, equals(2));
      expect(targetItem.boardZone, equals('Maybeboard'));

      final sourceItem = activeItems.firstWhere((i) => i.id == sourceDviId);
      expect(sourceItem.quantity, equals(1));
    });

    test('Consolidates when target row has "cmd" and target arg is "command"', () async {
      final cardId = await insertVaultCard(cardId: 'card-cons-cmd', name: 'Urza, Lord High Artificer', quantity: 2);
      final targetDviId = await addCardToBoardRaw(vaultItemId: cardId, rawBoardZone: 'cmd', quantity: 1);
      final sourceDviId = await addCardToBoardRaw(vaultItemId: cardId, rawBoardZone: 'Mainboard', quantity: 1);

      await dao.moveDeckItemBoard(testDeckId, sourceDviId, 'command', 1);

      final activeItems = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals(testVersionId) & t.isDeleted.equals(false)))
          .get();

      expect(activeItems.length, equals(1));
      expect(activeItems.first.id, equals(targetDviId));
      expect(activeItems.first.quantity, equals(2));
      expect(activeItems.first.boardZone, equals('Commander'));
    });

    test('Consolidates when target row has "deck" and target arg is "primary"', () async {
      final cardId = await insertVaultCard(cardId: 'card-cons-main', name: 'Mana Crypt', quantity: 2);
      final targetDviId = await addCardToBoardRaw(vaultItemId: cardId, rawBoardZone: 'deck', quantity: 1);
      final sourceDviId = await addCardToBoardRaw(vaultItemId: cardId, rawBoardZone: 'Sideboard', quantity: 1);

      await dao.moveDeckItemBoard(testDeckId, sourceDviId, 'primary', 1);

      final activeItems = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals(testVersionId) & t.isDeleted.equals(false)))
          .get();

      expect(activeItems.length, equals(1));
      expect(activeItems.first.id, equals(targetDviId));
      expect(activeItems.first.quantity, equals(2));
      expect(activeItems.first.boardZone, equals('Mainboard'));
    });

    test('Consolidates when target row has "comp" and target arg is "Companion"', () async {
      final cardId = await insertVaultCard(cardId: 'card-cons-comp', name: 'Lurrus of the Dream-Den', quantity: 2);
      final targetDviId = await addCardToBoardRaw(vaultItemId: cardId, rawBoardZone: 'comp', quantity: 1);
      final sourceDviId = await addCardToBoardRaw(vaultItemId: cardId, rawBoardZone: 'Mainboard', quantity: 1);

      await dao.moveDeckItemBoard(testDeckId, sourceDviId, 'Companion', 1);

      final activeItems = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals(testVersionId) & t.isDeleted.equals(false)))
          .get();

      expect(activeItems.length, equals(1));
      expect(activeItems.first.id, equals(targetDviId));
      expect(activeItems.first.quantity, equals(2));
      expect(activeItems.first.boardZone, equals('Companion'));
    });

    test('Consolidation strictly respects isProxy isolation (proxy row never merged with non-proxy)', () async {
      final cardId = await insertVaultCard(cardId: 'card-proxy-iso', name: 'Mox Diamond', quantity: 4);
      // Target board has a PROXY row with alias 'sb'
      final proxyTargetDviId = await addCardToBoardRaw(
        vaultItemId: cardId,
        rawBoardZone: 'sb',
        quantity: 2,
        isProxy: true,
      );
      // Source board has NON-PROXY card
      final sourceDviId = await addCardToBoardRaw(
        vaultItemId: cardId,
        rawBoardZone: 'Mainboard',
        quantity: 2,
        isProxy: false,
      );

      // Move 1 non-proxy copy to Sideboard
      await dao.moveDeckItemBoard(testDeckId, sourceDviId, 'Sideboard', 1);

      final activeItems = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals(testVersionId) & t.isDeleted.equals(false)))
          .get();

      // Expected: 3 active rows:
      // 1. Source non-proxy in Mainboard (qty 1)
      // 2. Target proxy in Sideboard (qty 2) - UNCHANGED
      // 3. New target non-proxy in Sideboard (qty 1)
      expect(activeItems.length, equals(3),
          reason: 'Proxy items must never be merged with non-proxy items');

      final proxyItem = activeItems.firstWhere((i) => i.id == proxyTargetDviId);
      expect(proxyItem.quantity, equals(2));
      expect(proxyItem.isProxy, isTrue);

      final nonProxySideItem = activeItems.firstWhere((i) => i.boardZone == 'Sideboard' && !i.isProxy);
      expect(nonProxySideItem.quantity, equals(1));
      expect(nonProxySideItem.isProxy, isFalse);

      final sourceItem = activeItems.firstWhere((i) => i.id == sourceDviId);
      expect(sourceItem.quantity, equals(1));
      expect(sourceItem.isProxy, isFalse);
    });

    test('Repeated partial transfers across divergent aliases correctly consolidate and conserve quantity', () async {
      final cardId = await insertVaultCard(cardId: 'card-multi-divergent', name: 'Lightning Bolt', quantity: 10);
      final dviMain = await addCardToBoardRaw(vaultItemId: cardId, rawBoardZone: 'Mainboard', quantity: 10);

      // Transfer 2 to 'sb' (creates Sideboard row)
      await dao.moveDeckItemBoard(testDeckId, dviMain, 'sb', 2);
      // Transfer 3 to 'side' (consolidates into existing Sideboard row)
      await dao.moveDeckItemBoard(testDeckId, dviMain, 'side', 3);
      // Transfer 1 to '  SIDEBOARD  ' (consolidates into existing Sideboard row)
      await dao.moveDeckItemBoard(testDeckId, dviMain, '  SIDEBOARD  ', 1);

      final activeItems = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals(testVersionId) & t.isDeleted.equals(false)))
          .get();

      expect(activeItems.length, equals(2));
      final sideItem = activeItems.firstWhere((i) => i.boardZone == 'Sideboard');
      expect(sideItem.quantity, equals(6), reason: '2 + 3 + 1 = 6 copies in Sideboard');

      final mainItem = activeItems.firstWhere((i) => i.boardZone == 'Mainboard');
      expect(mainItem.quantity, equals(4), reason: '10 - 6 = 4 copies remaining in Mainboard');

      // Now transfer 2 from Sideboard back to Mainboard using 'deck' alias
      await dao.moveDeckItemBoard(testDeckId, sideItem.id, 'deck', 2);

      final updatedItems = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals(testVersionId) & t.isDeleted.equals(false)))
          .get();

      expect(updatedItems.length, equals(2));
      final updatedSide = updatedItems.firstWhere((i) => i.boardZone == 'Sideboard');
      final updatedMain = updatedItems.firstWhere((i) => i.boardZone == 'Mainboard');

      expect(updatedSide.quantity, equals(4));
      expect(updatedMain.quantity, equals(6));
    });
  });

  // ===========================================================================
  // GROUP 5: CONCURRENT TOCTOU STRESS & RANDOMIZED ALIAS FUZZING
  // ===========================================================================
  group('Adversarial Group 5: Concurrency & Fuzzing Invariants', () {
    test('Concurrent board transfers with divergent aliases strictly preserve total card quantity', () async {
      final cardId = await insertVaultCard(cardId: 'card-concurrent-aliases', name: 'Cyclonic Rift', quantity: 6);
      final dviMain = await addCardToBoardRaw(vaultItemId: cardId, rawBoardZone: 'Mainboard', quantity: 6);
      // Pre-seed Sideboard with alias 'sb'
      final dviSide = await addCardToBoardRaw(vaultItemId: cardId, rawBoardZone: 'sb', quantity: 2);

      // Concurrently execute 4 transfers targeting Sideboard with varying aliases
      await Future.wait([
        dao.moveDeckItemBoard(testDeckId, dviMain, 'side', 1),
        dao.moveDeckItemBoard(testDeckId, dviMain, 'SB', 1),
        dao.moveDeckItemBoard(testDeckId, dviMain, '  Sideboard  ', 1),
        dao.moveDeckItemBoard(testDeckId, dviSide, 'main', 1),
      ]);

      final activeItems = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals(testVersionId) & t.isDeleted.equals(false)))
          .get();

      final totalQuantity = activeItems.fold<int>(0, (sum, i) => sum + i.quantity);
      expect(totalQuantity, equals(8),
          reason: 'Concurrency with divergent aliases must strictly conserve 8 total copies (no TOCTOU leak)');

      // Verify no duplicate active rows exist per board
      final boards = activeItems.map((i) => i.boardZone).toList();
      expect(boards.toSet().length, equals(boards.length),
          reason: 'Every active board must have at most 1 row per card (no split duplicate rows)');
    });

    test('Adversarial fuzzing: 50 randomized alias transfers across 5 cards preserves all invariants', () async {
      final random = math.Random(42);
      final cards = <String>[];
      final initialDvis = <String>[];

      for (int i = 0; i < 5; i++) {
        final cId = await insertVaultCard(cardId: 'fuzz-card-$i', name: 'Fuzz Card $i', quantity: 4);
        cards.add(cId);
        final dId = await addCardToBoardRaw(vaultItemId: cId, rawBoardZone: 'Mainboard', quantity: 4);
        initialDvis.add(dId);
      }

      final aliases = [
        'side', 'sb', 'SIDE', '  side  ', 'Sideboard',
        'maybe', 'mb', 'MAYBE', '  mb  ', 'Maybeboard',
        'main', 'deck', 'primary', 'MAIN', '  primary  ', 'Mainboard',
      ];

      for (int step = 0; step < 50; step++) {
        final cardIndex = random.nextInt(cards.length);
        final cId = cards[cardIndex];
        final targetAlias = aliases[random.nextInt(aliases.length)];

        // Get currently active rows for this card
        final currentRows = await (db.select(db.deckVersionItems)
              ..where((t) =>
                  t.versionId.equals(testVersionId) &
                  t.vaultItemId.equals(cId) &
                  t.isDeleted.equals(false)))
            .get();

        if (currentRows.isEmpty) continue;
        final selectedRow = currentRows[random.nextInt(currentRows.length)];
        final qtyToMove = random.nextInt(selectedRow.quantity) + 1;

        await dao.moveDeckItemBoard(testDeckId, selectedRow.id, targetAlias, qtyToMove);
      }

      // FINAL INVARIANT AUDIT
      final allActive = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals(testVersionId) & t.isDeleted.equals(false)))
          .get();

      // 1. Total copies for each of the 5 cards must be exactly 4 (5 * 4 = 20 total)
      final grandTotal = allActive.fold<int>(0, (sum, i) => sum + i.quantity);
      expect(grandTotal, equals(20), reason: 'Grand total across all cards must remain 20');

      for (final cId in cards) {
        final cardRows = allActive.where((i) => i.vaultItemId == cId).toList();
        final cardTotal = cardRows.fold<int>(0, (sum, i) => sum + i.quantity);
        expect(cardTotal, equals(4), reason: 'Card $cId must have exactly 4 total copies');

        // 2. Each card has at most 1 active row per canonical board (strict consolidation!)
        final cardZones = cardRows.map((r) => r.boardZone).toList();
        expect(cardZones.toSet().length, equals(cardZones.length),
            reason: 'Card $cId has duplicate rows in the same board: $cardZones');

        // 3. Every boardZone is canonical PascalCase
        const validZones = {'Mainboard', 'Sideboard', 'Maybeboard', 'Commander', 'Companion'};
        for (final z in cardZones) {
          expect(validZones.contains(z), isTrue,
              reason: 'Board zone "$z" is not in canonical set $validZones');
        }
      }
    });
  });
}
