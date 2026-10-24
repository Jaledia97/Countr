import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/core/database/app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.vaultDao.clearAllItems();
  });

  tearDown(() async {
    await db.close();
  });

  VaultItem buildTestCard({
    required String id,
    required String name,
    required int quantity,
    double marketPrice = 10.0,
    double acquiredPrice = 0.0,
    String? primaryBinderId,
    String condition = 'NM',
    bool isDeleted = false,
    String collectionType = 'mtg',
  }) {
    return VaultItem(
      id: id,
      collectionType: collectionType,
      name: name,
      setOrSeries: 'MH3',
      imageUrl: 'https://example.com/$id.jpg',
      acquiredPrice: acquiredPrice,
      acquiredDate: DateTime(2025, 1, 1),
      quantity: quantity,
      condition: condition,
      isGraded: false,
      isAltered: false,
      isMisprint: false,
      isSigned: false,
      isDeleted: isDeleted,
      currentMarketPrice: marketPrice,
      lastPriceUpdate: DateTime.now(),
      dynamicData: jsonEncode({
        'collector_number': '1',
        'set': 'mh3',
      }),
      personalNotes: null,
      primaryBinderId: primaryBinderId,
    );
  }

  group('Challenger M1 Adversarial Suite - VaultDao.assignItemsToBinder', () {
    test('1. Empty item ID lists return 0, perform no DB writes, and create no sync records', () async {
      final binder = await db.vaultDao.createBinder(name: 'Empty Test', collectionType: 'mtg');

      final initialSyncCount = (await db.select(db.syncQueue).get()).length;
      final result = await db.vaultDao.assignItemsToBinder([], binder.id);

      expect(result, equals(0));
      final finalSyncCount = (await db.select(db.syncQueue).get()).length;
      expect(finalSyncCount, equals(initialSyncCount));
    });

    test('2. Completely non-existent item IDs return 0 and write no sync records', () async {
      final binder = await db.vaultDao.createBinder(name: 'Ghost Binder', collectionType: 'mtg');

      final result = await db.vaultDao.assignItemsToBinder(
        ['nonexistent-uuid-1', 'nonexistent-uuid-2'],
        binder.id,
      );

      expect(result, equals(0));
      final syncEntries = await (db.select(db.syncQueue)
            ..where((t) => t.entityId.isIn(['nonexistent-uuid-1', 'nonexistent-uuid-2'])))
          .get();
      expect(syncEntries, isEmpty);
    });

    test('3. Partially existent item ID lists update only valid rows and emit sync only for those', () async {
      final binder = await db.vaultDao.createBinder(name: 'Partial Binder', collectionType: 'mtg');

      final real1 = buildTestCard(id: 'real-1', name: 'Real One', quantity: 0, marketPrice: 5.0);
      final real2 = buildTestCard(id: 'real-2', name: 'Real Two', quantity: 2, acquiredPrice: 8.0);
      await db.into(db.vaultItems).insert(real1);
      await db.into(db.vaultItems).insert(real2);

      final result = await db.vaultDao.assignItemsToBinder(
        ['real-1', 'ghost-fake-id', 'real-2', 'another-fake-id'],
        binder.id,
      );

      expect(result, equals(2));

      final card1 = await db.vaultDao.getItemById('real-1');
      expect(card1!.quantity, equals(1));
      expect(card1.primaryBinderId, equals(binder.id));

      final card2 = await db.vaultDao.getItemById('real-2');
      expect(card2!.quantity, equals(2)); // preserved
      expect(card2.primaryBinderId, equals(binder.id));

      final syncEntries = await db.select(db.syncQueue).get();
      final syncIds = syncEntries.map((e) => e.entityId).toSet();
      expect(syncIds, containsAll(['real-1', 'real-2']));
      expect(syncIds.contains('ghost-fake-id'), isFalse);
      expect(syncIds.contains('another-fake-id'), isFalse);
    });

    test('4. Duplicate item IDs in input list are handled safely without duplicate counting', () async {
      final binder = await db.vaultDao.createBinder(name: 'Dedup Binder', collectionType: 'mtg');

      final card = buildTestCard(id: 'dup-1', name: 'Dedup Card', quantity: 0, marketPrice: 12.0);
      await db.into(db.vaultItems).insert(card);

      final result = await db.vaultDao.assignItemsToBinder(
        ['dup-1', 'dup-1', 'dup-1'],
        binder.id,
      );

      expect(result, equals(1));
      final after = await db.vaultDao.getItemById('dup-1');
      expect(after!.quantity, equals(1));
      expect(after.primaryBinderId, equals(binder.id));

      final syncEntries = await (db.select(db.syncQueue)
            ..where((t) => t.entityId.equals('dup-1')))
          .get();
      expect(syncEntries.length, equals(1));
    });

    test('5. Unowned cards with zero or negative market price safely fallback and do not store negative price', () async {
      final binder = await db.vaultDao.createBinder(name: 'Pricing Binder', collectionType: 'mtg');

      // Zero market price, zero acquired price
      final zeroPrice = buildTestCard(id: 'p-zero', name: 'Zero Price', quantity: 0, marketPrice: 0.0, acquiredPrice: 0.0);
      // Negative market price, zero acquired price
      final negPrice = buildTestCard(id: 'p-neg', name: 'Neg Price', quantity: 0, marketPrice: -15.0, acquiredPrice: 0.0);
      // Zero market price, positive acquired price
      final zeroMarketWithAcquired = buildTestCard(id: 'p-zero-acq', name: 'Zero Market Acq', quantity: 0, marketPrice: 0.0, acquiredPrice: 18.50);
      // Negative market price, positive acquired price
      final negMarketWithAcquired = buildTestCard(id: 'p-neg-acq', name: 'Neg Market Acq', quantity: 0, marketPrice: -25.0, acquiredPrice: 40.00);
      // Normal positive market price
      final normalPrice = buildTestCard(id: 'p-normal', name: 'Normal', quantity: 0, marketPrice: 32.75, acquiredPrice: 0.0);
      // Negative quantity edge case
      final negQuantity = buildTestCard(id: 'p-neg-qty', name: 'Neg Qty', quantity: -2, marketPrice: 10.0, acquiredPrice: 0.0);

      await db.into(db.vaultItems).insert(zeroPrice);
      await db.into(db.vaultItems).insert(negPrice);
      await db.into(db.vaultItems).insert(zeroMarketWithAcquired);
      await db.into(db.vaultItems).insert(negMarketWithAcquired);
      await db.into(db.vaultItems).insert(normalPrice);
      await db.into(db.vaultItems).insert(negQuantity);

      final result = await db.vaultDao.assignItemsToBinder(
        ['p-zero', 'p-neg', 'p-zero-acq', 'p-neg-acq', 'p-normal', 'p-neg-qty'],
        binder.id,
      );

      expect(result, equals(6));

      final cZero = await db.vaultDao.getItemById('p-zero');
      expect(cZero!.quantity, equals(1));
      expect(cZero.acquiredPrice, equals(0.0));
      expect(cZero.purchasePrice, equals(0.0));
      expect(cZero.protectionStatus, equals('Sleeved'));

      final cNeg = await db.vaultDao.getItemById('p-neg');
      expect(cNeg!.quantity, equals(1));
      expect(cNeg.acquiredPrice, equals(0.0)); // Fallback, not -15.0
      expect(cNeg.purchasePrice, equals(0.0));

      final cZeroAcq = await db.vaultDao.getItemById('p-zero-acq');
      expect(cZeroAcq!.quantity, equals(1));
      expect(cZeroAcq.acquiredPrice, equals(18.50)); // Fallback to acquiredPrice
      expect(cZeroAcq.purchasePrice, equals(18.50));

      final cNegAcq = await db.vaultDao.getItemById('p-neg-acq');
      expect(cNegAcq!.quantity, equals(1));
      expect(cNegAcq.acquiredPrice, equals(40.00)); // Fallback to positive acquiredPrice
      expect(cNegAcq.purchasePrice, equals(40.00));

      final cNormal = await db.vaultDao.getItemById('p-normal');
      expect(cNormal!.quantity, equals(1));
      expect(cNormal.acquiredPrice, equals(32.75));
      expect(cNormal.purchasePrice, equals(32.75));

      final cNegQty = await db.vaultDao.getItemById('p-neg-qty');
      expect(cNegQty!.quantity, equals(1)); // Promoted from -2 to 1
    });

    test('6. Unowned card with isDeleted = true is undeleted and fully promoted', () async {
      final binder = await db.vaultDao.createBinder(name: 'Undelete Binder', collectionType: 'mtg');

      final deletedCard = buildTestCard(
        id: 'del-card',
        name: 'Deleted Unowned',
        quantity: 0,
        marketPrice: 9.99,
        isDeleted: true,
      );
      await db.into(db.vaultItems).insert(deletedCard);

      final count = await db.vaultDao.assignItemsToBinder(['del-card'], binder.id);
      expect(count, equals(1));

      final after = await db.vaultDao.getItemById('del-card', includeDeleted: true);
      expect(after!.isDeleted, isFalse);
      expect(after.quantity, equals(1));
      expect(after.primaryBinderId, equals(binder.id));
      expect(after.protectionStatus, equals('Sleeved'));
    });

    test('7. Mixed batch (5 unowned + 3 owned): owned card attributes are strictly preserved', () async {
      final binder = await db.vaultDao.createBinder(name: 'Mixed Batch Binder', collectionType: 'mtg');

      // 5 unowned cards
      final unownedCards = List.generate(
        5,
        (i) => buildTestCard(
          id: 'unowned-$i',
          name: 'Unowned Card $i',
          quantity: 0,
          marketPrice: 10.0 + i * 5.0,
          acquiredPrice: 0.0,
        ),
      );

      // 3 owned cards with established inventory metadata
      final owned1 = buildTestCard(
        id: 'owned-1',
        name: 'Mox Diamond',
        quantity: 2,
        marketPrice: 650.0,
        acquiredPrice: 450.0,
        condition: 'HP',
      );
      final owned2 = buildTestCard(
        id: 'owned-2',
        name: 'Gaea\'s Cradle',
        quantity: 4,
        marketPrice: 900.0,
        acquiredPrice: 500.0,
        condition: 'MP',
      );
      final owned3 = buildTestCard(
        id: 'owned-3',
        name: 'Force of Will',
        quantity: 1,
        marketPrice: 85.0,
        acquiredPrice: 60.0,
        condition: 'NM',
      );

      for (final c in unownedCards) {
        await db.into(db.vaultItems).insert(c);
      }
      await db.into(db.vaultItems).insert(owned1);
      await db.into(db.vaultItems).insert(owned2);
      await db.into(db.vaultItems).insert(owned3);

      final allIds = [...unownedCards.map((c) => c.id), 'owned-1', 'owned-2', 'owned-3'];
      final updated = await db.vaultDao.assignItemsToBinder(allIds, binder.id);
      expect(updated, equals(8));

      // Verify owned cards
      final o1After = await db.vaultDao.getItemById('owned-1');
      expect(o1After!.quantity, equals(2)); // Preserved
      expect(o1After.acquiredPrice, equals(450.0)); // Preserved, not overwritten by 650.0
      expect(o1After.condition, equals('HP')); // Preserved
      expect(o1After.primaryBinderId, equals(binder.id)); // Updated

      final o2After = await db.vaultDao.getItemById('owned-2');
      expect(o2After!.quantity, equals(4)); // Preserved
      expect(o2After.acquiredPrice, equals(500.0)); // Preserved, not overwritten by 900.0
      expect(o2After.condition, equals('MP')); // Preserved
      expect(o2After.primaryBinderId, equals(binder.id)); // Updated

      final o3After = await db.vaultDao.getItemById('owned-3');
      expect(o3After!.quantity, equals(1)); // Preserved
      expect(o3After.acquiredPrice, equals(60.0)); // Preserved, not overwritten by 85.0
      expect(o3After.condition, equals('NM')); // Preserved
      expect(o3After.primaryBinderId, equals(binder.id)); // Updated

      // Verify unowned cards
      for (int i = 0; i < 5; i++) {
        final uAfter = await db.vaultDao.getItemById('unowned-$i');
        expect(uAfter!.quantity, equals(1)); // Promoted
        expect(uAfter.acquiredPrice, equals(10.0 + i * 5.0)); // Set to market price
        expect(uAfter.purchasePrice, equals(10.0 + i * 5.0));
        expect(uAfter.primaryBinderId, equals(binder.id));
        expect(uAfter.protectionStatus, equals('Sleeved'));
      }

      // Verify sync queue: exactly 8 records generated
      final syncQueueEntries = await db.select(db.syncQueue).get();
      final syncMap = {for (var e in syncQueueEntries) e.entityId: e};
      for (final id in allIds) {
        expect(syncMap.containsKey(id), isTrue, reason: 'Sync queue missing record for $id');
        expect(syncMap[id]!.operation, equals('UPDATE'));
        expect(syncMap[id]!.entityType, equals('vault_item'));
      }
    });

    test('8. Streams watchItemsByBinder and watchBinderItemCounts reflect promoted items and sums', () async {
      final binderA = await db.vaultDao.createBinder(name: 'Binder Alpha', collectionType: 'mtg');
      final binderB = await db.vaultDao.createBinder(name: 'Binder Beta', collectionType: 'mtg');

      // Create 3 unowned cards and 2 owned cards (with quantities 3 and 2)
      final un1 = buildTestCard(id: 'stream-u1', name: 'Alpha Card 1', quantity: 0, marketPrice: 5.0);
      final un2 = buildTestCard(id: 'stream-u2', name: 'Alpha Card 2', quantity: 0, marketPrice: 10.0);
      final un3 = buildTestCard(id: 'stream-u3', name: 'Alpha Card 3', quantity: 0, marketPrice: 15.0);
      final ow1 = buildTestCard(id: 'stream-o1', name: 'Alpha Owned 1', quantity: 3, acquiredPrice: 20.0);
      final ow2 = buildTestCard(id: 'stream-o2', name: 'Alpha Owned 2', quantity: 2, acquiredPrice: 30.0);

      await db.into(db.vaultItems).insert(un1);
      await db.into(db.vaultItems).insert(un2);
      await db.into(db.vaultItems).insert(un3);
      await db.into(db.vaultItems).insert(ow1);
      await db.into(db.vaultItems).insert(ow2);

      // Initial state: binderA has 0 items
      var counts = await db.vaultDao.watchBinderItemCounts().first;
      expect(counts[binderA.id] ?? 0, equals(0));

      // Assign all 5 to binderA
      await db.vaultDao.assignItemsToBinder(
        ['stream-u1', 'stream-u2', 'stream-u3', 'stream-o1', 'stream-o2'],
        binderA.id,
      );

      // watchItemsByBinder should yield 5 items
      final binderAItems = await db.vaultDao.watchItemsByBinder(binderA.id).first;
      expect(binderAItems.length, equals(5));
      expect(binderAItems.every((item) => item.quantity > 0), isTrue);

      // watchBinderItemCounts should compute total copy count: 3*1 + 3 + 2 = 8
      counts = await db.vaultDao.watchBinderItemCounts().first;
      expect(counts[binderA.id], equals(8));
      expect(counts[binderB.id] ?? 0, equals(0));

      // Reassign all from binderA to binderB
      await db.vaultDao.assignItemsToBinder(
        ['stream-u1', 'stream-u2', 'stream-u3', 'stream-o1', 'stream-o2'],
        binderB.id,
      );

      final binderAItemsAfter = await db.vaultDao.watchItemsByBinder(binderA.id).first;
      expect(binderAItemsAfter, isEmpty);

      final binderBItemsAfter = await db.vaultDao.watchItemsByBinder(binderB.id).first;
      expect(binderBItemsAfter.length, equals(5));

      counts = await db.vaultDao.watchBinderItemCounts().first;
      expect(counts[binderA.id] ?? 0, equals(0));
      expect(counts[binderB.id], equals(8));
    });

    test('9. Assigning unowned cards to INBOX promotes them and populates watchInboxItems', () async {
      final inboxCard = buildTestCard(
        id: 'inbox-promo',
        name: 'Inbox Promo',
        quantity: 0,
        marketPrice: 7.50,
      );
      await db.into(db.vaultItems).insert(inboxCard);

      final initialInbox = await db.vaultDao.watchInboxItems().first;
      expect(initialInbox.any((c) => c.id == 'inbox-promo'), isFalse);

      await db.vaultDao.assignItemsToBinder(['inbox-promo'], 'INBOX');

      final updatedCard = await db.vaultDao.getItemById('inbox-promo');
      expect(updatedCard!.quantity, equals(1));
      expect(updatedCard.primaryBinderId, equals('INBOX'));
      expect(updatedCard.acquiredPrice, equals(7.50));

      final finalInbox = await db.vaultDao.watchInboxItems().first;
      expect(finalInbox.any((c) => c.id == 'inbox-promo'), isTrue);

      // watchBinderItemCounts specifically excludes INBOX
      final counts = await db.vaultDao.watchBinderItemCounts().first;
      expect(counts.containsKey('INBOX'), isFalse);
    });

    test('10. Atomic rollback: database failure during batch execution rolls back all changes', () async {
      final binder = await db.vaultDao.createBinder(name: 'Rollback Binder', collectionType: 'mtg');

      final cardA = buildTestCard(id: 'rollback-a', name: 'Safe Card A', quantity: 2, primaryBinderId: null);
      final cardB = buildTestCard(id: 'rollback-b', name: 'Failing Card B', quantity: 0, primaryBinderId: null);

      await db.into(db.vaultItems).insert(cardA);
      await db.into(db.vaultItems).insert(cardB);

      final initialSyncCount = (await db.select(db.syncQueue).get()).length;

      // Install a SQLite trigger that forces an abort when rollback-b is updated
      await db.customStatement('''
        CREATE TRIGGER abort_on_rollback_b
        BEFORE UPDATE ON vault_items
        FOR EACH ROW
        WHEN NEW.id = 'rollback-b'
        BEGIN
          SELECT RAISE(ABORT, 'Simulated SQLite trigger constraint failure');
        END;
      ''');

      // Attempting to assign both in one transaction must fail
      expect(
        () => db.vaultDao.assignItemsToBinder(['rollback-a', 'rollback-b'], binder.id),
        throwsA(isA<Exception>()),
      );

      // Verify complete atomic rollback:
      // cardA was in ownedItems (updated first in the transaction), but should be rolled back!
      final cardAAfter = await db.vaultDao.getItemById('rollback-a');
      expect(cardAAfter!.primaryBinderId, isNull, reason: 'cardA update must have rolled back');
      expect(cardAAfter.quantity, equals(2));

      // cardB should remain unowned
      final cardBAfter = await db.vaultDao.getItemById('rollback-b');
      expect(cardBAfter!.quantity, equals(0), reason: 'cardB must still have quantity 0');
      expect(cardBAfter.primaryBinderId, isNull);

      // Sync queue should have no new records
      final finalSyncCount = (await db.select(db.syncQueue).get()).length;
      expect(finalSyncCount, equals(initialSyncCount), reason: 'Sync queue inserts must roll back');
    });

    test('11. Stress test: 100 mixed items (50 unowned + 50 owned) in a single atomic batch', () async {
      final binder = await db.vaultDao.createBinder(name: 'Stress Binder', collectionType: 'mtg');

      final List<String> batchIds = [];
      int expectedTotalCopies = 0;

      for (int i = 0; i < 50; i++) {
        final id = 'stress-unowned-$i';
        batchIds.add(id);
        await db.into(db.vaultItems).insert(
          buildTestCard(
            id: id,
            name: 'Stress Unowned $i',
            quantity: 0,
            marketPrice: 5.0 + i,
          ),
        );
        expectedTotalCopies += 1; // Each promoted to 1
      }

      for (int i = 0; i < 50; i++) {
        final id = 'stress-owned-$i';
        batchIds.add(id);
        final qty = 1 + (i % 4); // 1, 2, 3, or 4
        expectedTotalCopies += qty;
        await db.into(db.vaultItems).insert(
          buildTestCard(
            id: id,
            name: 'Stress Owned $i',
            quantity: qty,
            acquiredPrice: 20.0 + i,
            marketPrice: 50.0 + i,
          ),
        );
      }

      final stopwatch = Stopwatch()..start();
      final updated = await db.vaultDao.assignItemsToBinder(batchIds, binder.id);
      stopwatch.stop();

      expect(updated, equals(100));
      expect(stopwatch.elapsedMilliseconds, lessThan(3000), reason: '100 card batch should complete swiftly');

      // Verify binder item counts match expected sum of copies
      final counts = await db.vaultDao.watchBinderItemCounts().first;
      expect(counts[binder.id], equals(expectedTotalCopies));

      // Verify watchItemsByBinder yields all 100 unique items
      final binderItems = await db.vaultDao.watchItemsByBinder(binder.id).first;
      expect(binderItems.length, equals(100));

      // Verify 100 sync queue entries
      final syncEntries = await (db.select(db.syncQueue)
            ..where((t) => t.entityId.isIn(batchIds)))
          .get();
      expect(syncEntries.length, equals(100));
    });
  });
}
