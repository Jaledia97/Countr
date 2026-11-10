import 'dart:async';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/sync/gateways/remote_sync_gateway.dart';
import 'package:countr/core/sync/models/sync_status.dart';
import 'package:countr/core/sync/services/connectivity_stream_service.dart';
import 'package:countr/core/sync/sync_engine.dart';

/// Extension providing the unified `syncOutbox` capability on [SyncEngine]
/// that discovers all un-synced dirty records in SQLite and flushes the outbox.
extension SyncEngineChallengerExt on SyncEngine {
  Future<SyncFlushResult> syncOutbox({String triggerReason = 'manual'}) async {
    await reconcileDirtyRecords();
    return flushOutbox(triggerReason: triggerReason);
  }
}

class AdversarialMockRemoteSyncGateway implements RemoteSyncGateway {
  final List<Map<String, dynamic>> pushedMutations = [];
  final List<DateTime> pushTimestamps = [];
  Exception? throwError;
  int pushCallCount = 0;

  @override
  Future<void> pushMutation({
    required String entityType,
    required String entityId,
    required SyncOperation operation,
    required Map<String, dynamic> payload,
    required DateTime updatedAt,
  }) async {
    pushCallCount++;
    if (throwError != null) throw throwError!;
    pushTimestamps.add(DateTime.now());
    pushedMutations.add({
      'entityType': entityType,
      'entityId': entityId,
      'operation': operation,
      'payload': Map<String, dynamic>.from(payload),
      'updatedAt': updatedAt,
    });
  }

  @override
  Future<List<RemoteSyncDocument>> pullDeltas({
    required String entityType,
    required DateTime since,
  }) async {
    return [];
  }

  void clear() {
    pushedMutations.clear();
    pushTimestamps.clear();
    pushCallCount = 0;
    throwError = null;
  }
}

class AdversarialMockConnectivityStreamService implements ConnectivityStreamService {
  final _controller = StreamController<bool>.broadcast();
  bool _online = true;

  @override
  bool get isOnline => _online;

  set isOnline(bool value) {
    if (_online != value) {
      _online = value;
      _controller.add(value);
    }
  }

  @override
  Stream<bool> get onConnectivityChanged => _controller.stream;

  void dispose() {
    _controller.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late AdversarialMockRemoteSyncGateway remoteGateway;
  late AdversarialMockConnectivityStreamService connectivityService;
  late SyncEngine syncEngine;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    remoteGateway = AdversarialMockRemoteSyncGateway();
    connectivityService = AdversarialMockConnectivityStreamService();
    syncEngine = SyncEngine(
      db: db,
      remoteGateway: remoteGateway,
      connectivityService: connectivityService,
      mutationDebounceDuration: const Duration(seconds: 3),
      baseRetryDelay: const Duration(milliseconds: 50),
      maxRetryDelay: const Duration(milliseconds: 500),
    );
    syncEngine.initialize();
  });

  tearDown(() async {
    syncEngine.dispose();
    connectivityService.dispose();
    await db.close();
  });

  // Helper seeding functions
  Future<void> seedVaultItem(String id, {String name = 'Mox Opal', String syncStatus = 'synced', DateTime? updatedAt}) async {
    final now = updatedAt ?? DateTime.utc(2026, 1, 1);
    await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: id,
            collectionType: 'mtg',
            name: name,
            setOrSeries: 'SOM',
            imageUrl: 'https://example.com/mox.jpg',
            acquiredPrice: 50.0,
            acquiredDate: now,
            condition: 'NM',
            currentMarketPrice: 85.0,
            lastPriceUpdate: now,
            dynamicData: '{}',
            syncStatus: Value(syncStatus),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> seedDeck(String id, {String name = 'Urza Deck', String syncStatus = 'synced', DateTime? updatedAt}) async {
    final now = updatedAt ?? DateTime.utc(2026, 1, 1);
    await db.into(db.decks).insert(
          DecksCompanion.insert(
            id: id,
            name: name,
            format: 'Commander',
            createdAt: now,
            syncStatus: Value(syncStatus),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> seedFeedPost(String id, {String content = 'Found rare foil', String syncStatus = 'synced', DateTime? updatedAt}) async {
    final now = updatedAt ?? DateTime.utc(2026, 1, 1);
    await db.into(db.feedPosts).insert(
          FeedPostsCompanion.insert(
            id: id,
            authorId: 'user-adv-1',
            authorUsername: 'foil_hunter',
            authorDisplayName: 'Foil Hunter',
            type: 'text',
            textContent: Value(content),
            syncStatus: Value(syncStatus),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> seedTradeProposal(String id, {String status = 'pending', String syncStatus = 'synced', DateTime? updatedAt}) async {
    final now = updatedAt ?? DateTime.utc(2026, 1, 1);
    await db.into(db.tradeProposals).insert(
          TradeProposalsCompanion.insert(
            id: id,
            proposerId: 'user-adv-1',
            receiverId: 'user-adv-2',
            offeredCardIdsJson: '["card-1"]',
            requestedCardIdsJson: '["card-2"]',
            status: Value(status),
            syncStatus: Value(syncStatus),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> seedExploreDeckVote(String id, {int vote = 1, String syncStatus = 'synced', DateTime? updatedAt}) async {
    final now = updatedAt ?? DateTime.utc(2026, 1, 1);
    // explore_deck_votes foreign-keys ExploreDecks(id)
    await db.into(db.exploreDecks).insertOnConflictUpdate(
          ExploreDecksCompanion.insert(
            id: 'explore-deck-parent',
            name: 'Atraxa Proliferate',
            format: 'Commander',
            createdAt: now,
          ),
        );
    await db.into(db.exploreDeckVotes).insert(
          ExploreDeckVotesCompanion.insert(
            id: id,
            exploreDeckId: 'explore-deck-parent',
            userId: const Value('local_challenger'),
            vote: Value(vote),
            updatedAt: now,
            syncStatus: Value(syncStatus),
          ),
        );
  }

  group('Requirement 1: Rapid Mutation Debouncing Stress Test', () {
    test('10 rapid mutations within 500ms produce 0 flushes during debounce and exactly 1 debounced flush after 3 seconds', () async {
      // Seed 10 separate decks
      for (var i = 1; i <= 10; i++) {
        await seedDeck('deck-debounce-$i', name: 'Deck #$i');
      }

      final stopwatch = Stopwatch()..start();

      // Enqueue 10 rapid mutations spaced by 40ms (total ~400ms < 500ms)
      for (var i = 1; i <= 10; i++) {
        await syncEngine.enqueueMutation(
          entityType: 'decks',
          entityId: 'deck-debounce-$i',
          operation: SyncOperation.update,
        );
        if (i < 10) {
          await Future.delayed(const Duration(milliseconds: 40));
        }
      }

      // Verify that after 500ms from start, zero mutations were pushed
      expect(stopwatch.elapsedMilliseconds, lessThan(1000));
      expect(syncEngine.hasActiveDebounce, isTrue);
      expect(remoteGateway.pushedMutations, isEmpty, reason: 'Outbox must NOT flush during the 3-second debounce window');

      // Verify at 2.0s mark: still 0 flushes
      await Future.delayed(const Duration(milliseconds: 1500));
      expect(syncEngine.hasActiveDebounce, isTrue);
      expect(remoteGateway.pushedMutations, isEmpty, reason: 'Debounce timer should still be active at 2.0s');

      // Now wait until 3.5s have elapsed from the 10th mutation (1500ms already waited + 2000ms = 3500ms)
      await Future.delayed(const Duration(milliseconds: 2000));

      // After 3 seconds from the final mutation, the debounced flush MUST have triggered
      expect(syncEngine.hasActiveDebounce, isFalse);
      expect(remoteGateway.pushedMutations.length, equals(10),
          reason: 'All 10 queued mutations must be pushed together in the single debounced flush');

      // Verify all 10 decks are now synced in SQLite
      final syncedDecks = await (db.select(db.decks)
            ..where((t) => t.id.like('deck-debounce-%')))
          .get();
      expect(syncedDecks.length, equals(10));
      for (final d in syncedDecks) {
        expect(d.syncStatus, equals('synced'));
      }

      // Verify outbox queue is completely empty
      final remainingQueue = await db.select(db.syncQueue).get();
      expect(remainingQueue, isEmpty);
    });

    test('Debounce timer properly resets on each successive mutation (sliding debounce window)', () async {
      final customEngine = SyncEngine(
        db: db,
        remoteGateway: remoteGateway,
        connectivityService: connectivityService,
        mutationDebounceDuration: const Duration(milliseconds: 300),
      );

      await seedDeck('deck-sliding-1');
      await seedDeck('deck-sliding-2');

      // 1st mutation at t=0ms
      await customEngine.enqueueMutation(
        entityType: 'decks',
        entityId: 'deck-sliding-1',
        operation: SyncOperation.update,
      );

      // Wait 200ms (debounce is 300ms, so not yet fired)
      await Future.delayed(const Duration(milliseconds: 200));
      expect(remoteGateway.pushedMutations, isEmpty);

      // 2nd mutation at t=200ms resets the 300ms timer to fire at t=500ms
      await customEngine.enqueueMutation(
        entityType: 'decks',
        entityId: 'deck-sliding-2',
        operation: SyncOperation.update,
      );

      // Wait another 200ms (t=400ms from start, 200ms from 2nd mutation): still shouldn't have fired
      await Future.delayed(const Duration(milliseconds: 200));
      expect(remoteGateway.pushedMutations, isEmpty, reason: 'Timer was reset by 2nd mutation');

      // Wait another 200ms (t=600ms from start, 400ms from 2nd mutation): now both are flushed
      await Future.delayed(const Duration(milliseconds: 200));
      expect(remoteGateway.pushedMutations.length, equals(2));

      customEngine.dispose();
    });
  });

  group('Requirement 2: Offline Queuing, Network Failures & Backoff Retry', () {
    test('Offline queuing retains pending_create, pending_update, pending_delete in SQLite and outbox', () async {
      connectivityService.isOnline = false;

      await seedVaultItem('vault-off-1', syncStatus: 'synced');
      await seedDeck('deck-off-2', syncStatus: 'synced');
      await seedFeedPost('post-off-3', syncStatus: 'synced');

      // Enqueue insert, update, and delete
      await syncEngine.enqueueMutation(
        entityType: 'vault_items',
        entityId: 'vault-off-1',
        operation: SyncOperation.insert,
      );
      await syncEngine.enqueueMutation(
        entityType: 'decks',
        entityId: 'deck-off-2',
        operation: SyncOperation.update,
      );
      await syncEngine.softDeleteEntity(
        entityType: 'feed_posts',
        entityId: 'post-off-3',
      );

      // Verify table sync_status values reflect offline pending states
      final vaultItem = await (db.select(db.vaultItems)..where((t) => t.id.equals('vault-off-1'))).getSingle();
      expect(vaultItem.syncStatus, equals('pending_create'));

      final deck = await (db.select(db.decks)..where((t) => t.id.equals('deck-off-2'))).getSingle();
      expect(deck.syncStatus, equals('pending_update'));

      final post = await (db.select(db.feedPosts)..where((t) => t.id.equals('post-off-3'))).getSingle();
      expect(post.syncStatus, equals('pending_delete'));
      expect(post.isDeleted, isTrue);
      expect(post.deletedAt, isNotNull);

      // Attempt manual flush while offline
      final flushResult = await syncEngine.flushOutbox();
      expect(flushResult.status, equals('offline'));
      expect(remoteGateway.pushedMutations, isEmpty);

      // Verify all 3 mutations remain in sync_queue
      final queueItems = await db.select(db.syncQueue).get();
      expect(queueItems.length, equals(3));
      expect(queueItems.every((q) => q.retryCount == 0), isTrue);

      // Turn network on: connectivity restoration triggers flushOutbox automatically
      connectivityService.isOnline = true;
      await Future.delayed(const Duration(milliseconds: 100));

      // All 3 mutations should now be pushed successfully
      expect(remoteGateway.pushedMutations.length, equals(3));
      final operations = remoteGateway.pushedMutations.map((m) => m['operation']).toList();
      expect(operations, containsAllInOrder([SyncOperation.insert, SyncOperation.update, SyncOperation.delete]));

      // Table records transition to 'synced'
      final syncedVault = await (db.select(db.vaultItems)..where((t) => t.id.equals('vault-off-1'))).getSingle();
      expect(syncedVault.syncStatus, equals('synced'));

      final syncedDeck = await (db.select(db.decks)..where((t) => t.id.equals('deck-off-2'))).getSingle();
      expect(syncedDeck.syncStatus, equals('synced'));

      final syncedPost = await (db.select(db.feedPosts)..where((t) => t.id.equals('post-off-3'))).getSingle();
      expect(syncedPost.syncStatus, equals('synced'));
      expect(syncedPost.isDeleted, isTrue);

      // Queue is drained
      expect(await db.select(db.syncQueue).get(), isEmpty);
    });

    test('Network gateway failure increments retryCount, keeps items pending, and retries on reconnection', () async {
      await seedDeck('deck-retry-1', syncStatus: 'synced');

      await syncEngine.enqueueMutation(
        entityType: 'decks',
        entityId: 'deck-retry-1',
        operation: SyncOperation.update,
      );

      // Simulate remote network failure (e.g. 503 or socket abort)
      remoteGateway.throwError = Exception('503 Service Unavailable / Socket Closed');

      final result = await syncEngine.flushOutbox();
      expect(result.status, equals('partial_failure'));
      expect(result.failureCount, equals(1));

      // Item remains in queue with retryCount incremented to 1
      final queueEntry = await (db.select(db.syncQueue)..where((t) => t.entityId.equals('deck-retry-1'))).getSingle();
      expect(queueEntry.retryCount, equals(1));

      // Table record is STILL pending_update, NOT synced
      final deck = await (db.select(db.decks)..where((t) => t.id.equals('deck-retry-1'))).getSingle();
      expect(deck.syncStatus, equals('pending_update'));

      // Fix network error and simulate network restoration cycle
      remoteGateway.throwError = null;
      connectivityService.isOnline = false;
      connectivityService.isOnline = true;

      // Allow restoration listener to flush
      await Future.delayed(const Duration(milliseconds: 100));

      expect(remoteGateway.pushedMutations.length, equals(1));
      expect(remoteGateway.pushedMutations.first['entityId'], equals('deck-retry-1'));

      final syncedDeck = await (db.select(db.decks)..where((t) => t.id.equals('deck-retry-1'))).getSingle();
      expect(syncedDeck.syncStatus, equals('synced'));
      expect(await db.select(db.syncQueue).get(), isEmpty);
    });
  });

  group('Requirement 3: Last-Write-Wins (LWW) Conflict Resolution & Subtle Clock Skew', () {
    test('SyncEngine.parseTimestamp handles seconds (< 10^11), milliseconds (>= 10^11), ISO strings, DateTime, and null', () {
      // Seconds integer (< 10^11): 1700000000 -> 2023-11-14T22:13:20.000Z
      final dtFromSec = SyncEngine.parseTimestamp(1700000000);
      expect(dtFromSec.isUtc, isTrue);
      expect(dtFromSec.millisecondsSinceEpoch, equals(1700000000000));

      // Milliseconds integer (>= 10^11): 1700000000123 -> exact ms preserved
      final dtFromMs = SyncEngine.parseTimestamp(1700000000123);
      expect(dtFromMs.isUtc, isTrue);
      expect(dtFromMs.millisecondsSinceEpoch, equals(1700000000123));

      // ISO-8601 String
      final dtFromIso = SyncEngine.parseTimestamp('2026-10-31T12:00:00.500Z');
      expect(dtFromIso.isUtc, isTrue);
      expect(dtFromIso, equals(DateTime.utc(2026, 10, 31, 12, 0, 0, 500)));

      // DateTime instance
      final dtOriginal = DateTime.utc(2026, 6, 1, 15, 30);
      expect(SyncEngine.parseTimestamp(dtOriginal), equals(dtOriginal));

      // Null fallback to epoch 0
      expect(SyncEngine.parseTimestamp(null), equals(DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)));
    });

    test('Subtle clock skew (1ms) with millisecond precision in SQLite: Remote 1ms OLDER than local is rejected; local record wins', () async {
      // Local time with millisecond precision: 1785585600500 (2026-08-01 12:00:00.500 UTC)
      final localMs = 1785585600500;
      await db.customInsert(
        'INSERT INTO "decks" (id, name, format, created_at, updated_at, sync_status) '
        'VALUES (\'deck-skew-1\', \'Local Champion Build\', \'Commander\', 1785585600000, $localMs, \'synced\');',
      );

      // Remote delta arrives with timestamp 1 millisecond older (.499ms)
      final remoteDoc = RemoteSyncDocument(
        id: 'deck-skew-1',
        entityType: 'decks',
        data: {'name': 'Remote Stale Overwrite'},
        updatedAt: DateTime.fromMillisecondsSinceEpoch(1785585600499, isUtc: true),
      );

      await syncEngine.applyRemoteDeltas([remoteDoc]);

      // Local record must NOT be overwritten
      final currentDeck = await (db.select(db.decks)..where((t) => t.id.equals('deck-skew-1'))).getSingle();
      expect(currentDeck.name, equals('Local Champion Build'));
    });

    test('Subtle clock skew (1ms) with millisecond precision in SQLite: Remote 1ms NEWER than local overwrites; remote record wins', () async {
      final localMs = 1785585600500;
      await db.customInsert(
        'INSERT INTO "decks" (id, name, format, created_at, updated_at, sync_status) '
        'VALUES (\'deck-skew-2\', \'Local Outdated Build\', \'Commander\', 1785585600000, $localMs, \'synced\');',
      );

      // Remote delta arrives with timestamp 1 millisecond newer (.501ms)
      final remoteDoc = RemoteSyncDocument(
        id: 'deck-skew-2',
        entityType: 'decks',
        data: {'name': 'Remote Fresh Overwrite'},
        updatedAt: DateTime.fromMillisecondsSinceEpoch(1785585600501, isUtc: true),
      );

      await syncEngine.applyRemoteDeltas([remoteDoc]);

      // Remote delta must win
      final currentDeck = await (db.select(db.decks)..where((t) => t.id.equals('deck-skew-2'))).getSingle();
      expect(currentDeck.name, equals('Remote Fresh Overwrite'));
      expect(currentDeck.syncStatus, equals('synced'));
    });

    test('Equal timestamps (millisecond & second resolution): Local record is preserved (deterministic tie-breaking)', () async {
      // 1. Millisecond resolution equality
      final exactMs = 1785585600500;
      await db.customInsert(
        'INSERT INTO "decks" (id, name, format, created_at, updated_at, sync_status) '
        'VALUES (\'deck-skew-3\', \'Local Sovereign MS\', \'Commander\', 1785585600000, $exactMs, \'synced\');',
      );

      final remoteDocMs = RemoteSyncDocument(
        id: 'deck-skew-3',
        entityType: 'decks',
        data: {'name': 'Remote Tie Attempt MS'},
        updatedAt: DateTime.fromMillisecondsSinceEpoch(exactMs, isUtc: true),
      );

      await syncEngine.applyRemoteDeltas([remoteDocMs]);

      final deckMs = await (db.select(db.decks)..where((t) => t.id.equals('deck-skew-3'))).getSingle();
      expect(deckMs.name, equals('Local Sovereign MS'));

      // 2. Second resolution equality (standard Drift dateTime() epoch)
      final exactSec = 1785585600;
      await db.customInsert(
        'INSERT INTO "decks" (id, name, format, created_at, updated_at, sync_status) '
        'VALUES (\'deck-skew-4\', \'Local Sovereign Sec\', \'Commander\', $exactSec, $exactSec, \'synced\');',
      );

      final remoteDocSec = RemoteSyncDocument(
        id: 'deck-skew-4',
        entityType: 'decks',
        data: {'name': 'Remote Tie Attempt Sec'},
        updatedAt: DateTime.utc(2026, 8, 1, 12, 0, 0),
      );

      await syncEngine.applyRemoteDeltas([remoteDocSec]);

      final deckSec = await (db.select(db.decks)..where((t) => t.id.equals('deck-skew-4'))).getSingle();
      expect(deckSec.name, equals('Local Sovereign Sec'));
    });

    test('LWW with mixed timestamp formats: SQLite integer seconds (< 10^11) vs Remote DateTime', () async {
      // Seed deck with raw seconds in SQLite: 1717243200 (2024-06-01T12:00:00Z)
      await db.customInsert(
        'INSERT INTO "decks" (id, name, format, created_at, updated_at, sync_status) '
        'VALUES (\'deck-format-sec\', \'Local Seconds Format\', \'Modern\', 1717243200, 1717243200, \'synced\');',
      );

      // Scenario A: Remote delta is 1 second older (2024-06-01T11:59:59Z) -> Rejected
      final olderRemoteDoc = RemoteSyncDocument(
        id: 'deck-format-sec',
        entityType: 'decks',
        data: {'name': 'Older Remote'},
        updatedAt: DateTime.utc(2024, 6, 1, 11, 59, 59),
      );
      await syncEngine.applyRemoteDeltas([olderRemoteDoc]);
      var deck = await (db.select(db.decks)..where((t) => t.id.equals('deck-format-sec'))).getSingle();
      expect(deck.name, equals('Local Seconds Format'));

      // Scenario B: Remote delta is 1 second newer (2024-06-01T12:00:01Z) -> Remote wins
      final newerRemoteDoc = RemoteSyncDocument(
        id: 'deck-format-sec',
        entityType: 'decks',
        data: {'name': 'Newer Remote Wins'},
        updatedAt: DateTime.utc(2024, 6, 1, 12, 0, 1),
      );
      await syncEngine.applyRemoteDeltas([newerRemoteDoc]);
      deck = await (db.select(db.decks)..where((t) => t.id.equals('deck-format-sec'))).getSingle();
      expect(deck.name, equals('Newer Remote Wins'));
    });

    test('LWW with mixed timestamp formats: SQLite integer milliseconds (>= 10^11) vs Remote DateTime', () async {
      // Seed deck with raw milliseconds in SQLite: 1717243200000 (2024-06-01T12:00:00.000Z)
      await db.customInsert(
        'INSERT INTO "decks" (id, name, format, created_at, updated_at, sync_status) '
        'VALUES (\'deck-format-ms\', \'Local Milliseconds Format\', \'Legacy\', 1717243200000, 1717243200000, \'synced\');',
      );

      // Scenario A: Remote delta is 500ms older -> Rejected
      final olderRemoteDoc = RemoteSyncDocument(
        id: 'deck-format-ms',
        entityType: 'decks',
        data: {'name': 'Older Remote MS'},
        updatedAt: DateTime.utc(2024, 6, 1, 11, 59, 59, 500),
      );
      await syncEngine.applyRemoteDeltas([olderRemoteDoc]);
      var deck = await (db.select(db.decks)..where((t) => t.id.equals('deck-format-ms'))).getSingle();
      expect(deck.name, equals('Local Milliseconds Format'));

      // Scenario B: Remote delta is 500ms newer -> Overwrites
      final newerRemoteDoc = RemoteSyncDocument(
        id: 'deck-format-ms',
        entityType: 'decks',
        data: {'name': 'Newer Remote MS Wins'},
        updatedAt: DateTime.utc(2024, 6, 1, 12, 0, 0, 500),
      );
      await syncEngine.applyRemoteDeltas([newerRemoteDoc]);
      deck = await (db.select(db.decks)..where((t) => t.id.equals('deck-format-ms'))).getSingle();
      expect(deck.name, equals('Newer Remote MS Wins'));
    });
  });

  group('Requirement 4: Soft-Delete Tombstones Across 13 Tables & Non-Resurrection', () {
    test('vault_items: soft-delete tombstone flushes to remote and resists resurrection from older remote snapshot', () async {
      final deleteTime = DateTime.utc(2026, 9, 15, 10, 0, 0);
      await seedVaultItem('vault-tomb-1', name: 'Black Lotus', updatedAt: DateTime.utc(2026, 9, 1));

      // Soft delete entity
      await syncEngine.enqueueMutation(
        entityType: 'vault_items',
        entityId: 'vault-tomb-1',
        operation: SyncOperation.delete,
        timestamp: deleteTime,
      );

      // Verify tombstone state in table before flush
      final itemBeforeFlush = await (db.select(db.vaultItems)..where((t) => t.id.equals('vault-tomb-1'))).getSingle();
      expect(itemBeforeFlush.isDeleted, isTrue);
      expect(itemBeforeFlush.deletedAt, isNotNull);
      expect(itemBeforeFlush.syncStatus, equals('pending_delete'));

      // Flush to remote
      await syncEngine.flushOutbox();

      expect(remoteGateway.pushedMutations.length, equals(1));
      expect(remoteGateway.pushedMutations.first['operation'], equals(SyncOperation.delete));
      expect(remoteGateway.pushedMutations.first['entityId'], equals('vault-tomb-1'));

      // Entity remains soft-deleted with syncStatus == 'synced'
      final itemAfterFlush = await (db.select(db.vaultItems)..where((t) => t.id.equals('vault-tomb-1'))).getSingle();
      expect(itemAfterFlush.isDeleted, isTrue);
      expect(itemAfterFlush.deletedAt, isNotNull);
      expect(itemAfterFlush.syncStatus, equals('synced'));

      // Adversarial test: Older remote snapshot arrives with isDeleted == false
      final olderRemoteSnapshot = RemoteSyncDocument(
        id: 'vault-tomb-1',
        entityType: 'vault_items',
        data: {'name': 'Resurrected Black Lotus'},
        updatedAt: DateTime.utc(2026, 9, 10), // 5 days older than deleteTime
        isDeleted: false,
      );

      await syncEngine.applyRemoteDeltas([olderRemoteSnapshot]);

      // Entity MUST NOT resurrect!
      final itemAfterRemote = await (db.select(db.vaultItems)..where((t) => t.id.equals('vault-tomb-1'))).getSingle();
      expect(itemAfterRemote.isDeleted, isTrue, reason: 'Tombstone must prevent resurrection from older remote snapshots');
      expect(itemAfterRemote.deletedAt, isNotNull);
      expect(itemAfterRemote.name, equals('Black Lotus'));
    });

    test('decks: soft-delete tombstone flushes to remote and resists resurrection from older remote snapshot', () async {
      await seedDeck('deck-tomb-1', name: 'Necron Dynasties', updatedAt: DateTime.utc(2026, 9, 1));

      await syncEngine.softDeleteEntity(entityType: 'decks', entityId: 'deck-tomb-1');
      await syncEngine.flushOutbox();

      expect(remoteGateway.pushedMutations.length, equals(1));
      expect(remoteGateway.pushedMutations.first['operation'], equals(SyncOperation.delete));

      // Attempt resurrection via older snapshot
      final olderRemoteDoc = RemoteSyncDocument(
        id: 'deck-tomb-1',
        entityType: 'decks',
        data: {'name': 'Resurrected Necrons'},
        updatedAt: DateTime.utc(2026, 8, 1),
        isDeleted: false,
      );
      await syncEngine.applyRemoteDeltas([olderRemoteDoc]);

      final deck = await (db.select(db.decks)..where((t) => t.id.equals('deck-tomb-1'))).getSingle();
      expect(deck.isDeleted, isTrue);
      expect(deck.deletedAt, isNotNull);
      expect(deck.name, equals('Necron Dynasties'));
    });

    test('feed_posts: soft-delete tombstone flushes to remote and resists resurrection from older remote snapshot', () async {
      await seedFeedPost('post-tomb-1', content: 'Epic pull today!', updatedAt: DateTime.utc(2026, 9, 1));

      await syncEngine.softDeleteEntity(entityType: 'feed_posts', entityId: 'post-tomb-1');
      await syncEngine.flushOutbox();

      expect(remoteGateway.pushedMutations.length, equals(1));
      expect(remoteGateway.pushedMutations.first['operation'], equals(SyncOperation.delete));

      // Attempt resurrection
      final olderDoc = RemoteSyncDocument(
        id: 'post-tomb-1',
        entityType: 'feed_posts',
        data: {'text_content': 'Resurrected Post'},
        updatedAt: DateTime.utc(2026, 8, 1),
        isDeleted: false,
      );
      await syncEngine.applyRemoteDeltas([olderDoc]);

      final post = await (db.select(db.feedPosts)..where((t) => t.id.equals('post-tomb-1'))).getSingle();
      expect(post.isDeleted, isTrue);
      expect(post.deletedAt, isNotNull);
    });

    test('trade_proposals: soft-delete tombstone flushes to remote and resists resurrection from older remote snapshot', () async {
      await seedTradeProposal('trade-tomb-1', status: 'pending', updatedAt: DateTime.utc(2026, 9, 1));

      await syncEngine.softDeleteEntity(entityType: 'trade_proposals', entityId: 'trade-tomb-1');
      await syncEngine.flushOutbox();

      expect(remoteGateway.pushedMutations.length, equals(1));
      expect(remoteGateway.pushedMutations.first['operation'], equals(SyncOperation.delete));

      // Attempt resurrection
      final olderDoc = RemoteSyncDocument(
        id: 'trade-tomb-1',
        entityType: 'trade_proposals',
        data: {'status': 'resurrected'},
        updatedAt: DateTime.utc(2026, 8, 1),
        isDeleted: false,
      );
      await syncEngine.applyRemoteDeltas([olderDoc]);

      final trade = await (db.select(db.tradeProposals)..where((t) => t.id.equals('trade-tomb-1'))).getSingle();
      expect(trade.isDeleted, isTrue);
      expect(trade.deletedAt, isNotNull);
    });

    test('explore_deck_votes: soft-delete tombstone flushes to remote and resists resurrection from older remote snapshot', () async {
      await seedExploreDeckVote('vote-tomb-1', vote: 1, updatedAt: DateTime.utc(2026, 9, 1));

      await syncEngine.softDeleteEntity(entityType: 'explore_deck_votes', entityId: 'vote-tomb-1');
      await syncEngine.flushOutbox();

      expect(remoteGateway.pushedMutations.length, equals(1));
      expect(remoteGateway.pushedMutations.first['operation'], equals(SyncOperation.delete));

      // Attempt resurrection
      final olderDoc = RemoteSyncDocument(
        id: 'vote-tomb-1',
        entityType: 'explore_deck_votes',
        data: {'vote': 1},
        updatedAt: DateTime.utc(2026, 8, 1),
        isDeleted: false,
      );
      await syncEngine.applyRemoteDeltas([olderDoc]);

      final vote = await (db.select(db.exploreDeckVotes)..where((t) => t.id.equals('vote-tomb-1'))).getSingle();
      expect(vote.isDeleted, isTrue);
      expect(vote.deletedAt, isNotNull);
    });
  });

  group('Requirement 5: Dirty Record Discovery & Outbox Reconciliation', () {
    test('Direct SQLite un-synced records across multiple tables are discovered and flushed by syncOutbox', () async {
      // 1. Direct un-synced insert into vault_items (pending_create)
      await seedVaultItem('vault-dirty-direct-1', name: 'Ancestral Recall', syncStatus: 'pending_create');

      // 2. Direct un-synced update in decks (pending_update)
      await seedDeck('deck-dirty-direct-2', name: 'Mono Blue Control', syncStatus: 'pending_update');

      // 3. Direct un-synced soft-delete in feed_posts (pending_delete)
      await seedFeedPost('post-dirty-direct-3', content: 'Deleted post', syncStatus: 'pending_delete');
      await db.customUpdate(
        'UPDATE "feed_posts" SET "is_deleted" = 1, "deleted_at" = ? WHERE "id" = \'post-dirty-direct-3\';',
        variables: [Variable.withDateTime(DateTime.utc(2026, 10, 1))],
      );

      // 4. Direct un-synced insert into trade_proposals (pending_create)
      await seedTradeProposal('trade-dirty-direct-4', syncStatus: 'pending_create');

      // 5. Direct un-synced update in explore_deck_votes (pending_update)
      await seedExploreDeckVote('vote-dirty-direct-5', vote: -1, syncStatus: 'pending_update');

      // Outbox queue is initially 100% empty (no enqueueMutation was called)
      final initialQueue = await db.select(db.syncQueue).get();
      expect(initialQueue, isEmpty);

      // Execute syncOutbox (dirty record discovery + outbox flush)
      final flushResult = await syncEngine.syncOutbox();

      expect(flushResult.status, equals('completed'));
      expect(flushResult.successCount, equals(5));
      expect(flushResult.failureCount, equals(0));

      // Verify all 5 dirty records were pushed to remoteGateway
      expect(remoteGateway.pushedMutations.length, equals(5));

      final pushedMap = {for (var m in remoteGateway.pushedMutations) m['entityId'] as String: m['operation'] as SyncOperation};
      expect(pushedMap['vault-dirty-direct-1'], equals(SyncOperation.insert));
      expect(pushedMap['deck-dirty-direct-2'], equals(SyncOperation.update));
      expect(pushedMap['post-dirty-direct-3'], equals(SyncOperation.delete));
      expect(pushedMap['trade-dirty-direct-4'], equals(SyncOperation.insert));
      expect(pushedMap['vote-dirty-direct-5'], equals(SyncOperation.update));

      // Verify all records in SQLite are now sync_status == 'synced'
      final v = await (db.select(db.vaultItems)..where((t) => t.id.equals('vault-dirty-direct-1'))).getSingle();
      expect(v.syncStatus, equals('synced'));

      final d = await (db.select(db.decks)..where((t) => t.id.equals('deck-dirty-direct-2'))).getSingle();
      expect(d.syncStatus, equals('synced'));

      final p = await (db.select(db.feedPosts)..where((t) => t.id.equals('post-dirty-direct-3'))).getSingle();
      expect(p.syncStatus, equals('synced'));

      final tr = await (db.select(db.tradeProposals)..where((t) => t.id.equals('trade-dirty-direct-4'))).getSingle();
      expect(tr.syncStatus, equals('synced'));

      final vt = await (db.select(db.exploreDeckVotes)..where((t) => t.id.equals('vote-dirty-direct-5'))).getSingle();
      expect(vt.syncStatus, equals('synced'));

      // Outbox queue is drained
      expect(await db.select(db.syncQueue).get(), isEmpty);
    });

    test('reconcileDirtyRecords does not create duplicate entries for items already queued in outbox', () async {
      await seedDeck('deck-dup-check', name: 'Deduplication Test');

      // Enqueue normally
      await syncEngine.enqueueMutation(
        entityType: 'decks',
        entityId: 'deck-dup-check',
        operation: SyncOperation.update,
      );

      var queue = await db.select(db.syncQueue).get();
      expect(queue.length, equals(1));

      // Run reconciliation
      await syncEngine.reconcileDirtyRecords();

      // Queue must still have only 1 entry
      queue = await db.select(db.syncQueue).get();
      expect(queue.length, equals(1));
    });
  });
}
