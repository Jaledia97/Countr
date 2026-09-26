import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:uuid/uuid.dart';

import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import '../../e2e_phase46/phase46_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('Milestone 2 Remediation: Multi-Threaded Transfer Invariants & Concurrency Stress', () {
    late AppDatabase db;
    late VaultDao dao;
    const testDeckId = 'stress-remediation-deck';
    const testVersionId = 'stress-remediation-ver';

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      dao = db.vaultDao;

      final now = DateTime.now();
      await db.into(db.decks).insert(
        DecksCompanion.insert(
          id: testDeckId,
          name: 'Concurrency Remediation Deck',
          format: 'Commander',
          createdAt: now,
          isRegistered: const drift.Value(true),
          isAssembled: const drift.Value(true),
          isDeleted: const drift.Value(false),
        ),
      );

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

    Future<List<DeckVersionItem>> getActiveItems() async {
      return (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals(testVersionId) & t.isDeleted.equals(false)))
          .get();
    }

    int sumQuantities(List<DeckVersionItem> items) {
      return items.fold<int>(0, (sum, i) => sum + i.quantity);
    }

    test('10 parallel Future.wait transfers moving cards across Mainboard, Sideboard, and Maybeboard strictly preserves initialTotal (0 phantom cards)', () async {
      const initialTotal = 10;
      final cardId = await insertVaultCard(cardId: 'card-10-parallel', name: 'Mox Diamond', quantity: initialTotal);
      final dviId = await addCardToBoard(vaultItemId: cardId, boardZone: 'Mainboard', quantity: initialTotal);

      // Target boards rotating across Sideboard and Maybeboard
      final targets = [
        'Sideboard',
        'Maybeboard',
        'Sideboard',
        'Maybeboard',
        'Sideboard',
        'Maybeboard',
        'Sideboard',
        'Maybeboard',
        'Sideboard',
        'Maybeboard',
      ];

      // Dispatch 10 parallel Future.wait calls simultaneously
      await Future.wait(
        targets.map((target) => dao.moveDeckItemBoard(testDeckId, dviId, target, 1)),
      );

      final items = await getActiveItems();
      final total = sumQuantities(items);

      expect(
        total,
        equals(initialTotal),
        reason: 'Invariant violation: sum(quantities) must strictly equal initialTotal ($initialTotal), but got $total. Phantom cards detected!',
      );

      // Verify each board has non-negative quantities and valid zones
      for (final item in items) {
        expect(item.quantity, greaterThan(0));
        expect(['Mainboard', 'Sideboard', 'Maybeboard'].contains(item.boardZone), isTrue);
      }
    });

    test('10 parallel Future.wait transfers across all 3 boards with circular movement maintains invariant', () async {
      // Setup: 4 copies on Mainboard, 4 on Sideboard, 4 on Maybeboard (total 12)
      const initialTotal = 12;
      final cardId = await insertVaultCard(cardId: 'card-tri-board', name: 'Force of Will', quantity: initialTotal);
      final mainDvi = await addCardToBoard(vaultItemId: cardId, boardZone: 'Mainboard', quantity: 4);
      final sideDvi = await addCardToBoard(vaultItemId: cardId, boardZone: 'Sideboard', quantity: 4);
      final maybeDvi = await addCardToBoard(vaultItemId: cardId, boardZone: 'Maybeboard', quantity: 4);

      // 10 concurrent operations:
      // 4 move from Mainboard to Sideboard
      // 3 move from Sideboard to Maybeboard
      // 3 move from Maybeboard to Mainboard
      await Future.wait([
        dao.moveDeckItemBoard(testDeckId, mainDvi, 'Sideboard', 1),
        dao.moveDeckItemBoard(testDeckId, mainDvi, 'Sideboard', 1),
        dao.moveDeckItemBoard(testDeckId, mainDvi, 'Sideboard', 1),
        dao.moveDeckItemBoard(testDeckId, mainDvi, 'Sideboard', 1),
        dao.moveDeckItemBoard(testDeckId, sideDvi, 'Maybeboard', 1),
        dao.moveDeckItemBoard(testDeckId, sideDvi, 'Maybeboard', 1),
        dao.moveDeckItemBoard(testDeckId, sideDvi, 'Maybeboard', 1),
        dao.moveDeckItemBoard(testDeckId, maybeDvi, 'Mainboard', 1),
        dao.moveDeckItemBoard(testDeckId, maybeDvi, 'Mainboard', 1),
        dao.moveDeckItemBoard(testDeckId, maybeDvi, 'Mainboard', 1),
      ]);

      final items = await getActiveItems();
      final total = sumQuantities(items);

      expect(
        total,
        equals(initialTotal),
        reason: 'Invariant violation in circular 3-board parallel moves: expected $initialTotal, got $total',
      );
    });

    test('10 parallel Future.wait transfers with source exhaustion (3 copies available, 10 competing tasks) produces zero phantom cards', () async {
      const initialTotal = 3;
      final cardId = await insertVaultCard(cardId: 'card-exhaustion', name: 'Black Lotus', quantity: initialTotal);
      final dviId = await addCardToBoard(vaultItemId: cardId, boardZone: 'Mainboard', quantity: initialTotal);

      // 10 tasks all try to move 1 copy from Mainboard to Sideboard concurrently
      await Future.wait(
        List.generate(10, (_) => dao.moveDeckItemBoard(testDeckId, dviId, 'Sideboard', 1)),
      );

      final items = await getActiveItems();
      final total = sumQuantities(items);

      expect(
        total,
        equals(initialTotal),
        reason: 'Over-subscription race created phantom cards: expected $initialTotal, got $total',
      );

      // Mainboard should be completely empty (or soft-deleted), Sideboard should have all 3
      final sideboardItem = items.where((i) => i.boardZone == 'Sideboard').firstOrNull;
      expect(sideboardItem, isNotNull);
      expect(sideboardItem!.quantity, equals(3));

      final mainboardItem = items.where((i) => i.boardZone == 'Mainboard').firstOrNull;
      expect(mainboardItem, isNull, reason: 'Mainboard should be soft-deleted when exhausted');
    });

    test('10 parallel Future.wait transfers with mixed aliases and divergent casing', () async {
      const initialTotal = 20;
      final cardId = await insertVaultCard(cardId: 'card-alias-race', name: 'Mana Crypt', quantity: initialTotal);
      final dviId = await addCardToBoard(vaultItemId: cardId, boardZone: 'Mainboard', quantity: initialTotal);

      final aliasTargets = [
        'side',
        'sb',
        'SIDEBOARD',
        '  sideboard  ',
        'maybe',
        'mb',
        'MAYBEBOARD',
        '  maybeboard  ',
        'commander',
        'cmd',
      ];

      await Future.wait(
        aliasTargets.map((target) => dao.moveDeckItemBoard(testDeckId, dviId, target, 1)),
      );

      final items = await getActiveItems();
      final total = sumQuantities(items);

      expect(total, equals(initialTotal));

      // Check canonical names
      for (final item in items) {
        expect(
          ['Mainboard', 'Sideboard', 'Maybeboard', 'Commander'].contains(item.boardZone),
          isTrue,
          reason: 'Non-canonical zone found: ${item.boardZone}',
        );
      }
    });

    test('50 concurrent transfers across 5 distinct cards preserves per-card and total invariants', () async {
      final cardIds = <String>[];
      final dviIds = <String>[];
      const cardsCount = 5;
      const copiesPerCard = 6;
      const initialGrandTotal = cardsCount * copiesPerCard; // 30

      for (int i = 0; i < cardsCount; i++) {
        final cId = await insertVaultCard(cardId: 'multi-c-$i', name: 'Card $i', quantity: copiesPerCard);
        final dId = await addCardToBoard(vaultItemId: cId, boardZone: 'Mainboard', quantity: copiesPerCard);
        cardIds.add(cId);
        dviIds.add(dId);
      }

      // Generate 50 concurrent operations (10 per card) targeting Sideboard and Maybeboard
      final operations = <Future<void>>[];
      final rng = math.Random(42);
      final targetBoards = ['Sideboard', 'Maybeboard', 'Mainboard'];

      for (int i = 0; i < 50; i++) {
        final cardIndex = i % cardsCount;
        final target = targetBoards[rng.nextInt(targetBoards.length)];
        operations.add(dao.moveDeckItemBoard(testDeckId, dviIds[cardIndex], target, 1));
      }

      await Future.wait(operations);

      final items = await getActiveItems();
      final grandTotal = sumQuantities(items);

      expect(grandTotal, equals(initialGrandTotal), reason: 'Total deck inventory corrupted');

      // Verify each individual card has exactly copiesPerCard copies
      for (final cId in cardIds) {
        final cardItems = items.where((i) => i.vaultItemId == cId).toList();
        final cardTotal = sumQuantities(cardItems);
        expect(
          cardTotal,
          equals(copiesPerCard),
          reason: 'Card $cId inventory violated: expected $copiesPerCard, got $cardTotal',
        );
      }
    });

    test('SyncQueue integrity under 10 parallel transfers', () async {
      const initialTotal = 10;
      final cardId = await insertVaultCard(cardId: 'card-sync-10', name: 'Tarmogoyf', quantity: initialTotal);
      final dviId = await addCardToBoard(vaultItemId: cardId, boardZone: 'Mainboard', quantity: initialTotal);

      // Perform 10 parallel transfers to Sideboard
      await Future.wait(
        List.generate(10, (_) => dao.moveDeckItemBoard(testDeckId, dviId, 'Sideboard', 1)),
      );

      final syncRows = await (db.select(db.syncQueue)
            ..where((t) => t.entityType.equals('deck_version_item')))
          .get();

      expect(syncRows.isNotEmpty, isTrue);
      // All recorded operations must be valid Drift v9 sync operations
      for (final row in syncRows) {
        expect(['INSERT', 'UPDATE', 'DELETE'].contains(row.operation), isTrue);
        expect(row.retryCount, equals(0));
      }

      final active = await getActiveItems();
      expect(sumQuantities(active), equals(initialTotal));
    });
  });
}
