import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/core/cache/countr_image_cache_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Adversarial Stress Test: SyncQueue Outbox & Image Cache Policy', () {
    late AppDatabase db;
    late VaultDao dao;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      dao = db.vaultDao;
    });

    tearDown(() async {
      await db.close();
    });

    // -------------------------------------------------------------------------
    // 1. HIGH-THROUGHPUT MUTATION BURSTS
    // -------------------------------------------------------------------------
    group('High-Throughput Mutation Bursts', () {
      test('Burst 1: 200 rapid consecutive inserts generate 200 distinct SyncQueue records', () async {
        const totalItems = 200;
        final now = DateTime.now();

        for (int i = 0; i < totalItems; i++) {
          final item = VaultItem(
            id: 'burst-item-$i',
            collectionType: 'mtg',
            name: 'Burst Card $i',
            setOrSeries: 'SET',
            imageUrl: 'http://example.com/card-$i.png',
            acquiredPrice: 1.0,
            acquiredDate: now,
            quantity: 1,
            condition: 'NM',
            isGraded: false,
            isAltered: false,
            isMisprint: false,
            isSigned: false,
            isDeleted: false,
            currentMarketPrice: 2.5,
            lastPriceUpdate: now,
            dynamicData: '{}',
          );
          await dao.insertItem(item.toCompanion(false));
        }

        final syncEntries = await dao.getPendingSyncEntries(limit: 500);
        expect(syncEntries.length, equals(totalItems));

        // Verify all 200 are INSERT operations on vault_item with retryCount 0
        final idsSeen = <String>{};
        final entityIdsSeen = <String>{};
        for (final entry in syncEntries) {
          expect(entry.operation, equals('INSERT'));
          expect(entry.entityType, equals('vault_item'));
          expect(entry.retryCount, equals(0));
          expect(idsSeen.add(entry.id), isTrue, reason: 'SyncQueue ID must be globally unique UUID');
          entityIdsSeen.add(entry.entityId);
        }

        expect(entityIdsSeen.length, equals(totalItems));
        for (int i = 0; i < totalItems; i++) {
          expect(entityIdsSeen.contains('burst-item-$i'), isTrue);
        }
      });

      test('Burst 2: 50 rapid sequential INSERT -> UPDATE -> DELETE triplets maintain operation ordering', () async {
        const entityCount = 50;
        final now = DateTime.now();

        for (int i = 0; i < entityCount; i++) {
          final id = 'triplet-item-$i';
          // 1. INSERT
          final item = VaultItem(
            id: id,
            collectionType: 'mtg',
            name: 'Triplet $i',
            setOrSeries: 'SET',
            imageUrl: 'http://example.com/$i.png',
            acquiredPrice: 10.0,
            acquiredDate: now,
            quantity: 1,
            condition: 'NM',
            isGraded: false,
            isAltered: false,
            isMisprint: false,
            isSigned: false,
            isDeleted: false,
            currentMarketPrice: 10.0,
            lastPriceUpdate: now,
            dynamicData: '{}',
          );
          await dao.insertItem(item.toCompanion(false));

          // 2. UPDATE
          await dao.updateItemCardDetails(
            id: id,
            condition: 'LP',
            acquiredPrice: 15.0,
          );

          // 3. DELETE (Soft delete)
          await dao.deleteItem(id);
        }

        final allSyncEntries = await dao.getPendingSyncEntries(limit: 500);
        expect(allSyncEntries.length, equals(entityCount * 3));

        // For each entity, verify that operations appear in order: INSERT, then UPDATE, then DELETE
        for (int i = 0; i < entityCount; i++) {
          final id = 'triplet-item-$i';
          final entityOps = allSyncEntries
              .where((e) => e.entityId == id)
              .map((e) => e.operation)
              .toList();

          expect(
            entityOps,
            equals(['INSERT', 'UPDATE', 'DELETE']),
            reason: 'For entity $id, SyncQueue outbox must strictly preserve INSERT -> UPDATE -> DELETE lifecycle order',
          );
        }
      });

      test('Burst 3: Concurrent async interleaved mutations across multiple entity types', () async {
        final now = DateTime.now();

        // Concurrently create 20 binders, 20 items, 10 decks
        final binderFutures = List.generate(20, (i) => dao.createBinder(name: 'Binder $i', collectionType: 'mtg'));
        final itemFutures = List.generate(20, (i) {
          final item = VaultItem(
            id: 'async-item-$i',
            collectionType: 'mtg',
            name: 'Async Item $i',
            setOrSeries: 'SET',
            imageUrl: '',
            acquiredPrice: 5.0,
            acquiredDate: now,
            quantity: 1,
            condition: 'NM',
            isGraded: false,
            isAltered: false,
            isMisprint: false,
            isSigned: false,
            isDeleted: false,
            currentMarketPrice: 5.0,
            lastPriceUpdate: now,
            dynamicData: '{}',
          );
          return dao.insertItem(item.toCompanion(false));
        });
        final deckFutures = List.generate(10, (i) => dao.createDeck('Deck $i', format: 'Modern'));

        await Future.wait<dynamic>([...binderFutures, ...itemFutures, ...deckFutures]);

        // Each createBinder produces 1 sync (binder INSERT) = 20
        // Each insertItem produces 1 sync (vault_item INSERT) = 20
        // Each createDeck produces 2 syncs (deck INSERT + deck_version INSERT) = 20
        // Total expected = 20 + 20 + 20 = 60
        final entries = await dao.getPendingSyncEntries(limit: 100);
        expect(entries.length, equals(60));

        final binderSyncs = entries.where((e) => e.entityType == 'binder' && e.operation == 'INSERT').length;
        final itemSyncs = entries.where((e) => e.entityType == 'vault_item' && e.operation == 'INSERT').length;
        final deckSyncs = entries.where((e) => e.entityType == 'deck' && e.operation == 'INSERT').length;
        final deckVersionSyncs = entries.where((e) => e.entityType == 'deck_version' && e.operation == 'INSERT').length;

        expect(binderSyncs, equals(20));
        expect(itemSyncs, equals(20));
        expect(deckSyncs, equals(10));
        expect(deckVersionSyncs, equals(10));
      });
    });

    // -------------------------------------------------------------------------
    // 2. IDEMPOTENCE AND RETRY_COUNT TRACKING
    // -------------------------------------------------------------------------
    group('Idempotence and retry_count Tracking', () {
      test('Linear incrementSyncRetry increments retryCount correctly', () async {
        final now = DateTime.now();
        final item = VaultItem(
          id: 'retry-test-item',
          collectionType: 'mtg',
          name: 'Retry Card',
          setOrSeries: 'SET',
          imageUrl: '',
          acquiredPrice: 1.0,
          acquiredDate: now,
          quantity: 1,
          condition: 'NM',
          isGraded: false,
          isAltered: false,
          isMisprint: false,
          isSigned: false,
          isDeleted: false,
          currentMarketPrice: 1.0,
          lastPriceUpdate: now,
          dynamicData: '{}',
        );
        await dao.insertItem(item.toCompanion(false));

        final entries = await dao.getPendingSyncEntries();
        final syncId = entries.first.id;
        expect(entries.first.retryCount, equals(0));

        // 1st retry
        var updatedRows = await dao.incrementSyncRetry(syncId);
        expect(updatedRows, equals(1));
        var currentEntries = await dao.getPendingSyncEntries();
        expect(currentEntries.first.retryCount, equals(1));

        // Increment 4 more times
        for (int i = 0; i < 4; i++) {
          await dao.incrementSyncRetry(syncId);
        }
        currentEntries = await dao.getPendingSyncEntries();
        expect(currentEntries.first.retryCount, equals(5));
      });

      test('incrementSyncRetry on non-existent syncId returns 0 without crashing', () async {
        final result = await dao.incrementSyncRetry('non-existent-uuid-12345');
        expect(result, equals(0));
      });

      test('markSyncCompleted is idempotent and safe against repeated calls', () async {
        final now = DateTime.now();
        final item = VaultItem(
          id: 'idempotence-item',
          collectionType: 'mtg',
          name: 'Idempotence Card',
          setOrSeries: 'SET',
          imageUrl: '',
          acquiredPrice: 1.0,
          acquiredDate: now,
          quantity: 1,
          condition: 'NM',
          isGraded: false,
          isAltered: false,
          isMisprint: false,
          isSigned: false,
          isDeleted: false,
          currentMarketPrice: 1.0,
          lastPriceUpdate: now,
          dynamicData: '{}',
        );
        await dao.insertItem(item.toCompanion(false));

        final entries = await dao.getPendingSyncEntries();
        final syncId = entries.first.id;

        // First acknowledgement deletes the row
        final firstCall = await dao.markSyncCompleted(syncId);
        expect(firstCall, equals(1));

        // Second call for the same syncId returns 0 (already deleted, no throw)
        final secondCall = await dao.markSyncCompleted(syncId);
        expect(secondCall, equals(0));

        // Call with unknown ID returns 0
        final unknownCall = await dao.markSyncCompleted('unknown-id');
        expect(unknownCall, equals(0));
      });

      test('Adversarial Check: Concurrent incrementSyncRetry behavior under race conditions', () async {
        final now = DateTime.now();
        final item = VaultItem(
          id: 'concurrent-retry-item',
          collectionType: 'mtg',
          name: 'Concurrent Retry Card',
          setOrSeries: 'SET',
          imageUrl: '',
          acquiredPrice: 1.0,
          acquiredDate: now,
          quantity: 1,
          condition: 'NM',
          isGraded: false,
          isAltered: false,
          isMisprint: false,
          isSigned: false,
          isDeleted: false,
          currentMarketPrice: 1.0,
          lastPriceUpdate: now,
          dynamicData: '{}',
        );
        await dao.insertItem(item.toCompanion(false));

        final entries = await dao.getPendingSyncEntries();
        final syncId = entries.first.id;

        // Execute 5 concurrent increments simultaneously
        await Future.wait(List.generate(5, (_) => dao.incrementSyncRetry(syncId)));

        final finalEntries = await dao.getPendingSyncEntries();
        final finalRetryCount = finalEntries.first.retryCount;
        
        expect(finalRetryCount, equals(5), reason: 'Atomic SQLite increment ensures all concurrent retry increments are preserved');
      });

      test('Cascade Soft-Delete Stress: deleteDeck cascades soft deletion to deck_versions and items', () async {
        final deck = await dao.createDeck('Orphan Deck', format: 'Commander');
        final now = DateTime.now();
        final item = VaultItem(
          id: 'card-in-orphan-deck',
          collectionType: 'mtg',
          name: 'Sol Ring',
          setOrSeries: 'Commander',
          imageUrl: '',
          acquiredPrice: 1.0,
          acquiredDate: now,
          quantity: 1,
          condition: 'NM',
          isGraded: false,
          isAltered: false,
          isMisprint: false,
          isSigned: false,
          isDeleted: false,
          currentMarketPrice: 1.5,
          lastPriceUpdate: now,
          dynamicData: '{}',
        );
        await dao.insertItem(item.toCompanion(false));
        await dao.addCardToDeck(deck.id, 'card-in-orphan-deck');

        // Delete the deck
        await dao.deleteDeck(deck.id);

        // Deck is soft-deleted
        final deckRow = await (db.select(db.decks)..where((t) => t.id.equals(deck.id))).getSingle();
        expect(deckRow.isDeleted, isTrue);

        final versions = await (db.select(db.deckVersions)..where((t) => t.deckId.equals(deck.id))).get();
        expect(versions, isNotEmpty);
        final versionItems = await (db.select(db.deckVersionItems)..where((t) => t.versionId.equals(versions.first.id))).get();
        expect(versionItems, isNotEmpty);

        // Check if versions are still isDeleted = false (orphaned)
        final versionsAreOrphaned = versions.any((v) => v.isDeleted == false);
        final itemsAreOrphaned = versionItems.any((vi) => vi.isDeleted == false);
        expect(versionsAreOrphaned, isFalse, reason: 'deck_versions are cascade soft deleted when deck is deleted');
        expect(itemsAreOrphaned, isFalse, reason: 'deck_version_items are cascade soft deleted when deck is deleted');
      });

      test('Binder Card Unassignment Stress: deleteBinder unassigns primaryBinderId from vault_items', () async {
        final binder = await dao.createBinder(name: 'Unassign Test Binder', collectionType: 'mtg');
        final now = DateTime.now();
        final item = VaultItem(
          id: 'card-in-test-binder',
          collectionType: 'mtg',
          name: 'Binder Card',
          setOrSeries: 'SET',
          imageUrl: '',
          acquiredPrice: 2.0,
          acquiredDate: now,
          quantity: 1,
          condition: 'NM',
          isGraded: false,
          isAltered: false,
          isMisprint: false,
          isSigned: false,
          isDeleted: false,
          currentMarketPrice: 2.0,
          lastPriceUpdate: now,
          dynamicData: '{}',
          primaryBinderId: binder.id,
        );
        await dao.insertItem(item.toCompanion(false));

        // Delete binder
        await dao.deleteBinder(binder.id);

        // Check card primary_binder_id
        final fetchedItem = await dao.getItemById('card-in-test-binder');
        expect(fetchedItem, isNotNull);
        expect(fetchedItem!.primaryBinderId, isNull, reason: 'Cards are unassigned when binder is soft-deleted');
      });
    });


    // -------------------------------------------------------------------------
    // 3. OUTBOX MAINTENANCE & STREAM REACTIVITY
    // -------------------------------------------------------------------------
    group('Outbox Maintenance & Stream Reactivity', () {
      test('watchPendingSyncCount reactively reflects queue growth and depletion', () async {
        final countsEmitted = <int>[];
        final subscription = dao.watchPendingSyncCount().listen((count) {
          countsEmitted.add(count);
        });

        // Let initial count emit
        await pumpEventQueue();

        final now = DateTime.now();
        final item = VaultItem(
          id: 'stream-test-item',
          collectionType: 'mtg',
          name: 'Stream Test Card',
          setOrSeries: 'SET',
          imageUrl: '',
          acquiredPrice: 1.0,
          acquiredDate: now,
          quantity: 1,
          condition: 'NM',
          isGraded: false,
          isAltered: false,
          isMisprint: false,
          isSigned: false,
          isDeleted: false,
          currentMarketPrice: 1.0,
          lastPriceUpdate: now,
          dynamicData: '{}',
        );

        // 1. Insert item (+1)
        await dao.insertItem(item.toCompanion(false));
        await pumpEventQueue();

        // 2. Update item (+1 -> 2)
        await dao.updateItemCardDetails(id: 'stream-test-item', condition: 'LP');
        await pumpEventQueue();

        // 3. Delete item (+1 -> 3)
        await dao.deleteItem('stream-test-item');
        await pumpEventQueue();

        final pending = await dao.getPendingSyncEntries();
        expect(pending.length, equals(3));

        // 4. Mark all completed one by one (3 -> 2 -> 1 -> 0)
        for (final entry in pending) {
          await dao.markSyncCompleted(entry.id);
          await pumpEventQueue();
        }

        await subscription.cancel();

        expect(countsEmitted.first, equals(0));
        expect(countsEmitted.last, equals(0));
        expect(countsEmitted.contains(3), isTrue);
      });

      test('Drain entire outbox queue sequentially simulating cloud sync worker', () async {
        final now = DateTime.now();
        for (int i = 0; i < 20; i++) {
          final item = VaultItem(
            id: 'drain-item-$i',
            collectionType: 'mtg',
            name: 'Drain Item $i',
            setOrSeries: 'SET',
            imageUrl: '',
            acquiredPrice: 1.0,
            acquiredDate: now,
            quantity: 1,
            condition: 'NM',
            isGraded: false,
            isAltered: false,
            isMisprint: false,
            isSigned: false,
            isDeleted: false,
            currentMarketPrice: 1.0,
            lastPriceUpdate: now,
            dynamicData: '{}',
          );
          await dao.insertItem(item.toCompanion(false));
        }

        var pending = await dao.getPendingSyncEntries(limit: 10);
        expect(pending.length, equals(10));

        // Drain in batches of 10
        while (pending.isNotEmpty) {
          for (final entry in pending) {
            await dao.markSyncCompleted(entry.id);
          }
          pending = await dao.getPendingSyncEntries(limit: 10);
        }

        final remaining = await dao.getPendingSyncEntries();
        expect(remaining, isEmpty);
      });

      test('clearSyncQueue removes all records from sync_queue outbox', () async {
        final now = DateTime.now();
        for (int i = 0; i < 5; i++) {
          final item = VaultItem(
            id: 'clear-item-$i',
            collectionType: 'mtg',
            name: 'Clear Item $i',
            setOrSeries: 'SET',
            imageUrl: '',
            acquiredPrice: 1.0,
            acquiredDate: now,
            quantity: 1,
            condition: 'NM',
            isGraded: false,
            isAltered: false,
            isMisprint: false,
            isSigned: false,
            isDeleted: false,
            currentMarketPrice: 1.0,
            lastPriceUpdate: now,
            dynamicData: '{}',
          );
          await dao.insertItem(item.toCompanion(false));
        }

        final pendingBefore = await dao.getPendingSyncEntries();
        expect(pendingBefore.length, equals(5));

        final deletedCount = await dao.clearSyncQueue();
        expect(deletedCount, equals(5));

        final pendingAfter = await dao.getPendingSyncEntries();
        expect(pendingAfter, isEmpty);
      });

      test('cleanupOldProcessedSyncQueue deletes records older than cutoff threshold', () async {
        final oldTime = DateTime.now().subtract(const Duration(days: 45));
        final recentTime = DateTime.now().subtract(const Duration(days: 5));

        await db.into(db.syncQueue).insert(
          SyncQueueCompanion.insert(
            id: 'old-sync-entry',
            entityType: 'vault_item',
            entityId: 'old-card',
            operation: 'INSERT',
            timestamp: oldTime,
          ),
        );
        await db.into(db.syncQueue).insert(
          SyncQueueCompanion.insert(
            id: 'recent-sync-entry',
            entityType: 'vault_item',
            entityId: 'recent-card',
            operation: 'INSERT',
            timestamp: recentTime,
          ),
        );

        final before = await dao.getPendingSyncEntries();
        expect(before.length, equals(2));

        final cleaned = await dao.cleanupOldProcessedSyncQueue(maxAge: const Duration(days: 30));
        expect(cleaned, equals(1));

        final after = await dao.getPendingSyncEntries();
        expect(after.length, equals(1));
        expect(after.first.id, equals('recent-sync-entry'));
      });
    });

    // -------------------------------------------------------------------------
    // 4. IMAGE CACHE MANAGER CONFIGURATION
    // -------------------------------------------------------------------------
    group('CountrImageCacheManager Configuration', () {
      test('CountrImageCacheManager enforces maxNrOfCacheObjects >= 5000 and stalePeriod >= 30 days', () {
        expect(
          CountrImageCacheManager.maxNrOfCacheObjects,
          greaterThanOrEqualTo(5000),
          reason: 'Cache manager must store at least 5000 images for offline resilience',
        );
        expect(
          CountrImageCacheManager.stalePeriod,
          greaterThanOrEqualTo(const Duration(days: 30)),
          reason: 'Cache manager stale period must be at least 30 days for maximum offline retention',
        );
        expect(CountrImageCacheManager.key, equals('countr_card_images'));

        // Singleton instance verification
        final manager1 = CountrImageCacheManager();
        final manager2 = CountrImageCacheManager();
        expect(identical(manager1, manager2), isTrue);
      });
    });
  });
}
