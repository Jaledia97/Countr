import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Adversarial Stress Test: Stage 1 Soft Deletes & Active Filtering', () {
    late AppDatabase db;
    late VaultDao dao;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      dao = db.vaultDao;
      await dao.clearAllItems();
      await db.delete(db.syncQueue).go();
    });

    tearDown(() async {
      await db.close();
    });

    VaultItem createSampleItem(String id, {String name = 'Sample Card', String binderId = 'binder-1', double price = 10.0, int quantity = 1}) {
      final now = DateTime.now();
      return VaultItem(
        id: id,
        collectionType: 'mtg',
        name: name,
        setOrSeries: 'Modern Horizons 3',
        imageUrl: 'https://example.com/$id.png',
        acquiredPrice: price,
        acquiredDate: now,
        quantity: quantity,
        condition: 'NM',
        isGraded: false,
        isAltered: false,
        isMisprint: false,
        isSigned: false,
        isDeleted: false,
        primaryBinderId: binderId,
        currentMarketPrice: price * 1.5,
        lastPriceUpdate: now,
        dynamicData: '{"collector_number":"123","set":"mh3","set_code":"mh3"}',
      );
    }

    // =========================================================================
    // 1. RAW SQLITE PERSISTENCE VERIFICATION (is_deleted == true & updated_at)
    // =========================================================================
    test('1.1 deleteItem: item persists in SQLite with is_deleted = 1 and updated_at populated', () async {
      final item = createSampleItem('item-raw-1');
      await dao.insertItem(item.toCompanion(false));

      final deletedCount = await dao.deleteItem('item-raw-1');
      expect(deletedCount, equals(1));

      // Query raw SQLite without DAO active filter
      final rows = await db.customSelect(
        'SELECT id, is_deleted, updated_at FROM vault_items WHERE id = ?',
        variables: [Variable.withString('item-raw-1')],
      ).get();

      expect(rows, hasLength(1));
      expect(rows.first.read<int>('is_deleted'), equals(1));
      expect(rows.first.read<DateTime?>('updated_at'), isNotNull);

      // Verify sync queue outbox
      final syncEntries = await dao.getPendingSyncEntries();
      expect(
        syncEntries.any((e) => e.entityType == 'vault_item' && e.entityId == 'item-raw-1' && e.operation == 'DELETE'),
        isTrue,
      );
    });

    test('1.2 deleteBinder: binder persists in SQLite with is_deleted = 1 and updated_at populated', () async {
      final binder = await dao.createBinder(name: 'Trade Binder', collectionType: 'mtg');
      
      final deletedCount = await dao.deleteBinder(binder.id);
      expect(deletedCount, equals(1));

      final rows = await db.customSelect(
        'SELECT id, is_deleted, updated_at FROM vault_binders WHERE id = ?',
        variables: [Variable.withString(binder.id)],
      ).get();

      expect(rows, hasLength(1));
      expect(rows.first.read<int>('is_deleted'), equals(1));
      expect(rows.first.read<DateTime?>('updated_at'), isNotNull);

      final syncEntries = await dao.getPendingSyncEntries();
      expect(
        syncEntries.any((e) => e.entityType == 'binder' && e.entityId == binder.id && e.operation == 'DELETE'),
        isTrue,
      );
    });

    test('1.3 deleteDeck: deck persists in SQLite with is_deleted = 1 and updated_at populated', () async {
      final deck = await dao.createDeck('Urza EDH', format: 'Commander');

      final deletedCount = await dao.deleteDeck(deck.id);
      expect(deletedCount, equals(1));

      final rows = await db.customSelect(
        'SELECT id, is_deleted, updated_at FROM decks WHERE id = ?',
        variables: [Variable.withString(deck.id)],
      ).get();

      expect(rows, hasLength(1));
      expect(rows.first.read<int>('is_deleted'), equals(1));
      expect(rows.first.read<DateTime?>('updated_at'), isNotNull);

      final syncEntries = await dao.getPendingSyncEntries();
      expect(
        syncEntries.any((e) => e.entityType == 'deck' && e.entityId == deck.id && e.operation == 'DELETE'),
        isTrue,
      );
    });

    // =========================================================================
    // 2. ACTIVE READ QUERIES INVARIANCE
    // =========================================================================
    test('2.1 active read queries strictly exclude soft-deleted items across all vault read APIs', () async {
      final activeItem = createSampleItem('active-card-1', name: 'Black Lotus', binderId: 'binder-alpha');
      final deletedItem = createSampleItem('deleted-card-1', name: 'Mox Pearl', binderId: 'binder-alpha');

      await dao.insertItem(activeItem.toCompanion(false));
      await dao.insertItem(deletedItem.toCompanion(false));
      await dao.deleteItem('deleted-card-1');

      // 1. getItemById
      expect(await dao.getItemById('deleted-card-1'), isNull);
      expect(await dao.getItemById('active-card-1'), isNotNull);
      // But accessible if includeDeleted: true
      expect(await dao.getItemById('deleted-card-1', includeDeleted: true), isNotNull);

      // 2. watchItemById
      expect(await dao.watchItemById('deleted-card-1').first, isNull);
      expect(await dao.watchItemById('active-card-1').first, isNotNull);

      // 3. watchItemsByCollection
      final allItems = await dao.watchItemsByCollection('mtg').first;
      expect(allItems.map((i) => i.id), contains('active-card-1'));
      expect(allItems.map((i) => i.id), isNot(contains('deleted-card-1')));

      // 4. searchCatalogCards
      final searchResults = await dao.searchCatalogCards('Mox');
      expect(searchResults.map((i) => i.id), isNot(contains('deleted-card-1')));

      // 5. watchItemsByBinder
      final binderItems = await dao.watchItemsByBinder('binder-alpha').first;
      expect(binderItems.map((i) => i.id), contains('active-card-1'));
      expect(binderItems.map((i) => i.id), isNot(contains('deleted-card-1')));

      // 6. watchVaultTotals & getVaultTotals
      final totals = await dao.getVaultTotals(collectionType: 'mtg');
      expect(totals.totalCount, equals(1)); // only active-card-1
      expect(totals.uniqueCount, equals(1));
      expect(totals.totalCostBasis, equals(10.0));

      final streamedTotals = await dao.watchVaultTotals(collectionType: 'mtg').first;
      expect(streamedTotals.totalCount, equals(1));

      // 7. watchBinderItemCounts
      final binderCounts = await dao.watchBinderItemCounts().first;
      expect(binderCounts['binder-alpha'], equals(1));

      // 8. getItemsBySet
      final setItems = await dao.getItemsBySet(setIdentifier: 'mh3');
      expect(setItems.map((i) => i.id), contains('active-card-1'));
      expect(setItems.map((i) => i.id), isNot(contains('deleted-card-1')));
    });

    test('2.2 deck active queries strictly exclude soft-deleted decks', () async {
      final deck1 = await dao.createDeck('Active Deck', format: 'Standard');
      final deck2 = await dao.createDeck('To Be Deleted', format: 'Modern');

      await dao.deleteDeck(deck2.id);

      // watchAllDecks
      final decks = await dao.watchAllDecks().first;
      expect(decks.map((d) => d.id), contains(deck1.id));
      expect(decks.map((d) => d.id), isNot(contains(deck2.id)));

      // getDeck
      expect(await dao.getDeck(deck1.id), isNotNull);
      expect(await dao.getDeck(deck2.id), isNull);

      // watchDeckOrNull
      expect(await dao.watchDeckOrNull(deck2.id).first, isNull);
      expect(await dao.watchDeckOrNull(deck1.id).first, isNotNull);
    });

    // =========================================================================
    // 3. BULK SOFT-DELETES (deleteItems)
    // =========================================================================
    test('3.1 deleteItems: bulk soft deletion of 50 items maintains consistency and outbox logging', () async {
      final ids = List.generate(50, (i) => 'bulk-item-$i');
      for (final id in ids) {
        await dao.insertItem(createSampleItem(id, name: 'Card $id').toCompanion(false));
      }

      var itemsBefore = await dao.watchItemsByCollection('mtg').first;
      expect(itemsBefore.length, equals(50));

      // Clear sync queue from inserts to isolate delete outbox check
      await db.delete(db.syncQueue).go();

      // Bulk soft delete
      final affected = await dao.deleteItems(ids);
      expect(affected, equals(50));

      // Active read is immediately empty
      var itemsAfter = await dao.watchItemsByCollection('mtg').first;
      expect(itemsAfter, isEmpty);

      // Check SQLite raw rows: all 50 must have is_deleted = 1 and updated_at populated
      final placeholders = List.filled(50, '?').join(',');
      final rawRows = await db.customSelect(
        'SELECT id, is_deleted, updated_at FROM vault_items WHERE id IN ($placeholders)',
        variables: ids.map((id) => Variable.withString(id)).toList(),
      ).get();
      expect(rawRows.length, equals(50));
      for (final row in rawRows) {
        expect(row.read<int>('is_deleted'), equals(1));
        expect(row.read<DateTime?>('updated_at'), isNotNull);
      }

      // Check syncQueue: all 50 must have DELETE entries
      final syncEntries = await dao.getPendingSyncEntries();
      expect(syncEntries.length, equals(50));
      for (final entry in syncEntries) {
        expect(entry.operation, equals('DELETE'));
        expect(entry.entityType, equals('vault_item'));
      }

      // Edge cases: empty list and non-existent IDs
      expect(await dao.deleteItems([]), equals(0));
      expect(await dao.deleteItems(['ghost-id-1', 'ghost-id-2']), equals(0));
    });

    // =========================================================================
    // 4. CASCADE SOFT-DELETES: deleteDeck & CHILD VERSION ITEMS
    // =========================================================================
    test('4.1 deleteDeck cascade: soft deleting a deck MUST mark child version items as soft-deleted', () async {
      final deck = await dao.createDeck('Commander Cascade Deck', format: 'Commander');
      final cardA = createSampleItem('cascade-card-a', name: 'Sol Ring');
      final cardB = createSampleItem('cascade-card-b', name: 'Arcane Signet');
      await dao.insertItem(cardA.toCompanion(false));
      await dao.insertItem(cardB.toCompanion(false));

      // Add cards to deck
      await dao.addCardToDeck(deck.id, 'cascade-card-a', quantity: 1, boardZone: 'mainboard');
      await dao.addCardToDeck(deck.id, 'cascade-card-b', quantity: 1, boardZone: 'mainboard');

      // Verify active deck has items
      final itemsBeforeDelete = await dao.watchDeckItems(deck.id).first;
      expect(itemsBeforeDelete.length, equals(2));

      // Verify card allocations before delete
      final allocBefore = await dao.watchCardDeckAllocations('cascade-card-a').first;
      expect(allocBefore[deck.id], equals(1));

      // Delete deck
      await dao.deleteDeck(deck.id);

      // ADVERSARIAL CHALLENGE CHECKS:
      // A) Does watchDeckItems(deck.id) return empty?
      final itemsAfterDelete = await dao.watchDeckItems(deck.id).first;
      expect(itemsAfterDelete, isEmpty, reason: 'watchDeckItems must not return items for a soft-deleted deck');

      // B) Does watchDeckVersions(deck.id) return empty?
      final versionsAfterDelete = await dao.watchDeckVersions(deck.id).first;
      expect(versionsAfterDelete, isEmpty, reason: 'watchDeckVersions must not return versions for a soft-deleted deck');

      // C) Does watchCardDeckAllocations still allocate cards to the soft-deleted deck?
      final allocAfter = await dao.watchCardDeckAllocations('cascade-card-a').first;
      expect(allocAfter.containsKey(deck.id), isFalse, reason: 'Card deck allocations must not include deleted decks');

      // D) Are child DeckVersions marked is_deleted = 1 in SQLite?
      final rawVersions = await db.customSelect(
        'SELECT id, is_deleted, updated_at FROM deck_versions WHERE deck_id = ?',
        variables: [Variable.withString(deck.id)],
      ).get();
      for (final v in rawVersions) {
        expect(v.read<int>('is_deleted'), equals(1), reason: 'Child deck_versions must be marked is_deleted = 1');
        expect(v.read<DateTime?>('updated_at'), isNotNull);
      }

      // E) Are child DeckVersionItems marked is_deleted = 1 in SQLite?
      final rawVersionItems = await db.customSelect(
        '''
        SELECT dvi.id, dvi.is_deleted, dvi.updated_at
        FROM deck_version_items dvi
        INNER JOIN deck_versions dv ON dv.id = dvi.version_id
        WHERE dv.deck_id = ?
        ''',
        variables: [Variable.withString(deck.id)],
      ).get();
      for (final dvi in rawVersionItems) {
        expect(dvi.read<int>('is_deleted'), equals(1), reason: 'Child deck_version_items must be marked is_deleted = 1');
        expect(dvi.read<DateTime?>('updated_at'), isNotNull);
      }
    });

    test('4.2 deleteBinder: deleting a binder must not leave orphaned cards or phantom binder counts', () async {
      final binder = await dao.createBinder(name: 'Mythics Binder', collectionType: 'mtg');
      final card = createSampleItem('card-in-binder', binderId: binder.id);
      await dao.insertItem(card.toCompanion(false));

      // Verify binder has 1 item
      final countBefore = await dao.watchBinderItemCounts().first;
      expect(countBefore[binder.id], equals(1));

      // Delete binder
      await dao.deleteBinder(binder.id);

      // Verify watchItemsByBinder(binder.id) returns empty
      final itemsInDeletedBinder = await dao.watchItemsByBinder(binder.id).first;
      expect(itemsInDeletedBinder, isEmpty, reason: 'watchItemsByBinder must be empty for deleted binder');

      // Verify watchBinderItemCounts no longer counts the deleted binder
      final countAfter = await dao.watchBinderItemCounts().first;
      expect(countAfter.containsKey(binder.id), isFalse, reason: 'watchBinderItemCounts must not include deleted binder');
    });

    // =========================================================================
    // 5. CONCURRENT ADVERSARIAL MUTATION STRESS TEST
    // =========================================================================
    test('5.1 concurrent high-throughput mutations and streaming reads maintain active query invariance', () async {
      const workerCount = 20;
      const opsPerWorker = 10;
      final errors = <String>[];

      // Stream subscription collecting all emissions
      final sub = dao.watchItemsByCollection('mtg').listen((items) {
        for (final item in items) {
          if (item.isDeleted) {
            errors.add('LEAK: Active stream emitted soft-deleted item: ${item.id}');
          }
        }
      });

      // Concurrent async workers
      final futures = <Future<void>>[];
      for (int w = 0; w < workerCount; w++) {
        final workerId = w;
        futures.add(Future(() async {
          for (int i = 0; i < opsPerWorker; i++) {
            final itemId = 'conc-item-$workerId-$i';
            final item = createSampleItem(itemId, name: 'Card $workerId-$i');
            
            // Insert
            await dao.insertItem(item.toCompanion(false));

            // Immediate query
            final fetched = await dao.getItemById(itemId);
            if (fetched == null || fetched.isDeleted) {
              errors.add('ERROR: Inserted item $itemId not found or isDeleted');
            }

            // Update
            await dao.updateItemNotesAndDecks(itemId, personalNotes: 'updated notes');

            // Delete
            await dao.deleteItem(itemId);

            // Immediate verify hidden
            final fetchedAfterDelete = await dao.getItemById(itemId);
            if (fetchedAfterDelete != null) {
              errors.add('LEAK: Deleted item $itemId still visible in getItemById');
            }
          }
        }));
      }

      await Future.wait(futures);
      await sub.cancel();

      expect(errors, isEmpty, reason: errors.join('\n'));

      // Final state: all inserted items were deleted; active items must be 0
      final finalActive = await dao.watchItemsByCollection('mtg').first;
      expect(finalActive, isEmpty);

      // Raw SQLite should have workerCount * opsPerWorker rows, all with is_deleted = 1
      final rawCount = await db.customSelect(
        "SELECT COUNT(*) as cnt FROM vault_items WHERE id LIKE 'conc-item-%' AND is_deleted = 1",
      ).getSingle();
      expect(rawCount.read<int>('cnt'), equals(workerCount * opsPerWorker));
    });
  });
}
