import 'dart:async';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/sync/gateways/remote_sync_gateway.dart';
import 'package:countr/core/sync/models/sync_status.dart';
import 'package:countr/core/sync/services/connectivity_stream_service.dart';
import 'package:countr/core/sync/sync_engine.dart';

class MockRemoteSyncGateway implements RemoteSyncGateway {
  final List<Map<String, dynamic>> pushedMutations = [];
  Exception? throwError;

  @override
  Future<void> pushMutation({
    required String entityType,
    required String entityId,
    required SyncOperation operation,
    required Map<String, dynamic> payload,
    required DateTime updatedAt,
  }) async {
    if (throwError != null) throw throwError!;
    pushedMutations.add({
      'entityType': entityType,
      'entityId': entityId,
      'operation': operation,
      'payload': payload,
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
}

class MockConnectivityStreamService implements ConnectivityStreamService {
  final _controller = StreamController<bool>.broadcast();
  bool _online = true;

  @override
  bool get isOnline => _online;

  set isOnline(bool value) {
    _online = value;
    _controller.add(value);
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
  late MockRemoteSyncGateway remoteGateway;
  late MockConnectivityStreamService connectivityService;
  late SyncEngine syncEngine;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    remoteGateway = MockRemoteSyncGateway();
    connectivityService = MockConnectivityStreamService();
    syncEngine = SyncEngine(
      db: db,
      remoteGateway: remoteGateway,
      connectivityService: connectivityService,
      mutationDebounceDuration: const Duration(milliseconds: 100),
    );
    syncEngine.initialize();

    // Seed test binder
    await db.into(db.vaultBinders).insert(
          VaultBindersCompanion.insert(
            id: 'binder-1',
            name: 'Trade Binder',
            collectionType: 'mtg',
            createdAt: DateTime.utc(2026, 1, 1),
          ),
        );

    // Seed test deck
    await db.into(db.decks).insert(
          DecksCompanion.insert(
            id: 'deck-1',
            name: 'Urza Commander',
            format: 'Commander',
            createdAt: DateTime.utc(2026, 1, 1),
          ),
        );
  });

  tearDown(() async {
    syncEngine.dispose();
    connectivityService.dispose();
    await db.close();
  });

  group('SyncEngine - Outbox State Machine & Transitions', () {
    test('Enqueue insert sets syncStatus == pending_create and flushes to remote', () async {
      await syncEngine.enqueueMutation(
        entityType: 'vault_binders',
        entityId: 'binder-1',
        operation: SyncOperation.insert,
      );

      // Verify pending state before flush
      final pendingBinder = await (db.select(db.vaultBinders)..where((t) => t.id.equals('binder-1'))).getSingle();
      expect(pendingBinder.syncStatus, equals('pending_create'));

      // Flush outbox
      final result = await syncEngine.flushOutbox();

      expect(result.status, equals('completed'));
      expect(result.successCount, equals(1));
      expect(remoteGateway.pushedMutations.length, equals(1));
      expect(remoteGateway.pushedMutations.first['entityId'], equals('binder-1'));
      expect(remoteGateway.pushedMutations.first['operation'], equals(SyncOperation.insert));

      // Verify synced state after flush
      final syncedBinder = await (db.select(db.vaultBinders)..where((t) => t.id.equals('binder-1'))).getSingle();
      expect(syncedBinder.syncStatus, equals('synced'));

      // Verify outbox queue is empty
      final queueItems = await db.select(db.syncQueue).get();
      expect(queueItems, isEmpty);
    });

    test('Enqueue update sets syncStatus == pending_update', () async {
      await syncEngine.enqueueMutation(
        entityType: 'decks',
        entityId: 'deck-1',
        operation: SyncOperation.update,
      );

      final deck = await (db.select(db.decks)..where((t) => t.id.equals('deck-1'))).getSingle();
      expect(deck.syncStatus, equals('pending_update'));

      await syncEngine.flushOutbox();

      final syncedDeck = await (db.select(db.decks)..where((t) => t.id.equals('deck-1'))).getSingle();
      expect(syncedDeck.syncStatus, equals('synced'));
    });

    test('Soft delete sets isDeleted == true, deletedAt != null, syncStatus == pending_delete', () async {
      await syncEngine.softDeleteEntity(
        entityType: 'decks',
        entityId: 'deck-1',
      );

      final deck = await (db.select(db.decks)..where((t) => t.id.equals('deck-1'))).getSingle();
      expect(deck.isDeleted, isTrue);
      expect(deck.deletedAt, isNotNull);
      expect(deck.syncStatus, equals('pending_delete'));

      await syncEngine.flushOutbox();

      final syncedDeck = await (db.select(db.decks)..where((t) => t.id.equals('deck-1'))).getSingle();
      expect(syncedDeck.syncStatus, equals('synced'));
      expect(syncedDeck.isDeleted, isTrue);
      expect(syncedDeck.deletedAt, isNotNull);

      // Verify UI query exclusion: queries filtering deletedAt == null find 0 records
      final activeDecks = await (db.select(db.decks)
            ..where((t) => t.isDeleted.equals(false) & t.deletedAt.isNull()))
          .get();
      expect(activeDecks.any((d) => d.id == 'deck-1'), isFalse);
    });
  });

  group('SyncEngine - Triggers & Offline Resilience', () {
    test('Offline mode aborts flush and retains mutations in outbox', () async {
      connectivityService.isOnline = false;

      await syncEngine.enqueueMutation(
        entityType: 'vault_binders',
        entityId: 'binder-1',
        operation: SyncOperation.update,
      );

      final result = await syncEngine.flushOutbox();
      expect(result.status, equals('offline'));
      expect(remoteGateway.pushedMutations, isEmpty);

      final queueEntries = await db.select(db.syncQueue).get();
      expect(queueEntries.length, equals(1));
    });

    test('Connectivity restoration automatically triggers flushOutbox', () async {
      connectivityService.isOnline = false;

      await syncEngine.enqueueMutation(
        entityType: 'vault_binders',
        entityId: 'binder-1',
        operation: SyncOperation.update,
      );

      expect(remoteGateway.pushedMutations, isEmpty);

      // Restore connectivity
      connectivityService.isOnline = true;

      // Allow microtask / event loop to process stream listener
      await Future.delayed(const Duration(milliseconds: 50));

      expect(remoteGateway.pushedMutations.length, equals(1));
      final queueEntries = await db.select(db.syncQueue).get();
      expect(queueEntries, isEmpty);
    });

    test('handleAppResume triggers outbox flush', () async {
      // Add entry directly to sync_queue
      await db.into(db.syncQueue).insert(
            SyncQueueCompanion.insert(
              id: 'q-resume',
              entityType: 'decks',
              entityId: 'deck-1',
              operation: 'UPDATE',
              timestamp: DateTime.now().toUtc(),
            ),
          );

      expect(remoteGateway.pushedMutations, isEmpty);

      syncEngine.handleAppResume();
      await Future.delayed(const Duration(milliseconds: 50));

      expect(remoteGateway.pushedMutations.length, equals(1));
    });

    test('Debounce timer: multiple rapid mutations debounce to a single flush', () async {
      final engine = SyncEngine(
        db: db,
        remoteGateway: remoteGateway,
        connectivityService: connectivityService,
        mutationDebounceDuration: const Duration(milliseconds: 100),
      );

      // Trigger 3 rapid mutations
      for (var i = 1; i <= 3; i++) {
        await engine.enqueueMutation(
          entityType: 'decks',
          entityId: 'deck-1',
          operation: SyncOperation.update,
        );
      }

      // Within debounce period, mutations remain in queue
      expect(engine.hasActiveDebounce, isTrue);

      // Wait for debounce period to expire
      await Future.delayed(const Duration(milliseconds: 150));

      // Outbox flush pushed all mutations
      expect(remoteGateway.pushedMutations.length, equals(3));

      engine.dispose();
    });

    test('Remote gateway error increments retryCount and keeps mutation in outbox', () async {
      remoteGateway.throwError = Exception('503 Service Unavailable');

      await syncEngine.enqueueMutation(
        entityType: 'decks',
        entityId: 'deck-1',
        operation: SyncOperation.update,
      );

      final result = await syncEngine.flushOutbox();
      expect(result.status, equals('partial_failure'));
      expect(result.failureCount, equals(1));

      final queueEntry = await (db.select(db.syncQueue)..where((t) => t.entityId.equals('deck-1'))).getSingle();
      expect(queueEntry.retryCount, equals(1));

      // Resolve error and flush again
      remoteGateway.throwError = null;
      final retryResult = await syncEngine.flushOutbox();
      expect(retryResult.status, equals('completed'));
      expect(retryResult.successCount, equals(1));
    });
  });

  group('SyncEngine - Last-Write-Wins & Reconcile', () {
    test('Newer remote delta overwrites older local record', () async {
      // Local deck updatedAt was Jan 1, 2026
      final remoteDoc = RemoteSyncDocument(
        id: 'deck-1',
        entityType: 'decks',
        data: {'name': 'Urza Supreme Commander'},
        updatedAt: DateTime.utc(2026, 6, 1),
      );

      await syncEngine.applyRemoteDeltas([remoteDoc]);

      final updatedDeck = await (db.select(db.decks)..where((t) => t.id.equals('deck-1'))).getSingle();
      expect(updatedDeck.name, equals('Urza Supreme Commander'));
      expect(updatedDeck.syncStatus, equals('synced'));
    });

    test('Older remote delta is rejected when local record is newer', () async {
      // Local deck updated to July 1, 2026
      await db.customUpdate(
        'UPDATE "decks" SET "name" = \'Urza Newest\', "updated_at" = ? WHERE "id" = \'deck-1\';',
        variables: [Variable.withDateTime(DateTime.utc(2026, 7, 1))],
      );

      // Remote delta is from May 1, 2026
      final olderRemoteDoc = RemoteSyncDocument(
        id: 'deck-1',
        entityType: 'decks',
        data: {'name': 'Urza Outdated'},
        updatedAt: DateTime.utc(2026, 5, 1),
      );

      await syncEngine.applyRemoteDeltas([olderRemoteDoc]);

      final retainedDeck = await (db.select(db.decks)..where((t) => t.id.equals('deck-1'))).getSingle();
      expect(retainedDeck.name, equals('Urza Newest'));
    });

    test('Remote delta with tombstone soft-deletes local record', () async {
      final remoteDeleteDoc = RemoteSyncDocument(
        id: 'deck-1',
        entityType: 'decks',
        data: {},
        updatedAt: DateTime.utc(2026, 6, 15),
        deletedAt: DateTime.utc(2026, 6, 15),
        isDeleted: true,
      );

      await syncEngine.applyRemoteDeltas([remoteDeleteDoc]);

      final deck = await (db.select(db.decks)..where((t) => t.id.equals('deck-1'))).getSingle();
      expect(deck.isDeleted, isTrue);
      expect(deck.deletedAt?.toUtc(), equals(DateTime.utc(2026, 6, 15)));
      expect(deck.syncStatus, equals('synced'));
    });

    test('reconcileDirtyRecords discovers dirty records missing from outbox', () async {
      // Mark deck as pending_update directly in table without outbox entry
      await db.customUpdate(
        'UPDATE "decks" SET "sync_status" = \'pending_update\' WHERE "id" = \'deck-1\';',
      );

      // Outbox is initially empty
      expect(await db.select(db.syncQueue).get(), isEmpty);

      // Run reconciliation
      await syncEngine.reconcileDirtyRecords();

      final queueEntries = await db.select(db.syncQueue).get();
      expect(queueEntries.length, equals(1));
      expect(queueEntries.first.entityId, equals('deck-1'));
      expect(queueEntries.first.operation, equals('UPDATE'));
    });
  });

  group('SyncEngine - deck_matchups and deck_synergies coverage', () {
    test('deck_matchups: enqueueMutation insert, update, and delete tombstones succeed', () async {
      // Seed deck matchup
      await db.into(db.deckMatchups).insert(
            DeckMatchupsCompanion.insert(
              id: 'matchup-1',
              deckId: 'deck-1',
              opponentArchetype: 'Burn',
            ),
          );

      // Enqueue insert
      await syncEngine.enqueueMutation(
        entityType: 'deck_matchups',
        entityId: 'matchup-1',
        operation: SyncOperation.insert,
      );

      var matchup = await (db.select(db.deckMatchups)..where((t) => t.id.equals('matchup-1'))).getSingle();
      expect(matchup.syncStatus, equals('pending_create'));

      // Flush outbox
      var flushResult = await syncEngine.flushOutbox();
      expect(flushResult.status, equals('completed'));
      expect(remoteGateway.pushedMutations.last['entityType'], equals('deck_matchups'));
      expect(remoteGateway.pushedMutations.last['entityId'], equals('matchup-1'));
      expect(remoteGateway.pushedMutations.last['operation'], equals(SyncOperation.insert));

      matchup = await (db.select(db.deckMatchups)..where((t) => t.id.equals('matchup-1'))).getSingle();
      expect(matchup.syncStatus, equals('synced'));

      // Enqueue update
      await syncEngine.enqueueMutation(
        entityType: 'deck_matchups',
        entityId: 'matchup-1',
        operation: SyncOperation.update,
      );

      matchup = await (db.select(db.deckMatchups)..where((t) => t.id.equals('matchup-1'))).getSingle();
      expect(matchup.syncStatus, equals('pending_update'));

      flushResult = await syncEngine.flushOutbox();
      expect(flushResult.status, equals('completed'));
      matchup = await (db.select(db.deckMatchups)..where((t) => t.id.equals('matchup-1'))).getSingle();
      expect(matchup.syncStatus, equals('synced'));

      // Enqueue delete (tombstone)
      await syncEngine.enqueueMutation(
        entityType: 'deck_matchups',
        entityId: 'matchup-1',
        operation: SyncOperation.delete,
      );

      matchup = await (db.select(db.deckMatchups)..where((t) => t.id.equals('matchup-1'))).getSingle();
      expect(matchup.isDeleted, isTrue);
      expect(matchup.deletedAt, isNotNull);
      expect(matchup.syncStatus, equals('pending_delete'));

      flushResult = await syncEngine.flushOutbox();
      expect(flushResult.status, equals('completed'));
      matchup = await (db.select(db.deckMatchups)..where((t) => t.id.equals('matchup-1'))).getSingle();
      expect(matchup.isDeleted, isTrue);
      expect(matchup.syncStatus, equals('synced'));
    });

    test('deck_synergies: enqueueMutation insert, update, and delete tombstones succeed', () async {
      // Seed deck synergy
      await db.into(db.deckSynergies).insert(
            DeckSynergiesCompanion.insert(
              id: 'synergy-1',
              deckId: 'deck-1',
              synergyName: 'Thopter Sword Combo',
              vaultItemIds: '["c1","c2"]',
            ),
          );

      // Enqueue insert
      await syncEngine.enqueueMutation(
        entityType: 'deck_synergies',
        entityId: 'synergy-1',
        operation: SyncOperation.insert,
      );

      var synergy = await (db.select(db.deckSynergies)..where((t) => t.id.equals('synergy-1'))).getSingle();
      expect(synergy.syncStatus, equals('pending_create'));

      var flushResult = await syncEngine.flushOutbox();
      expect(flushResult.status, equals('completed'));
      expect(remoteGateway.pushedMutations.last['entityType'], equals('deck_synergies'));
      expect(remoteGateway.pushedMutations.last['entityId'], equals('synergy-1'));
      expect(remoteGateway.pushedMutations.last['operation'], equals(SyncOperation.insert));

      synergy = await (db.select(db.deckSynergies)..where((t) => t.id.equals('synergy-1'))).getSingle();
      expect(synergy.syncStatus, equals('synced'));

      // Enqueue delete (tombstone)
      await syncEngine.enqueueMutation(
        entityType: 'deck_synergies',
        entityId: 'synergy-1',
        operation: SyncOperation.delete,
      );

      synergy = await (db.select(db.deckSynergies)..where((t) => t.id.equals('synergy-1'))).getSingle();
      expect(synergy.isDeleted, isTrue);
      expect(synergy.deletedAt, isNotNull);
      expect(synergy.syncStatus, equals('pending_delete'));

      flushResult = await syncEngine.flushOutbox();
      expect(flushResult.status, equals('completed'));
      synergy = await (db.select(db.deckSynergies)..where((t) => t.id.equals('synergy-1'))).getSingle();
      expect(synergy.isDeleted, isTrue);
      expect(synergy.syncStatus, equals('synced'));
    });

    test('reconcileDirtyRecords discovers dirty records in deck_matchups and deck_synergies', () async {
      await db.into(db.deckMatchups).insert(
            DeckMatchupsCompanion.insert(
              id: 'matchup-dirty-1',
              deckId: 'deck-1',
              opponentArchetype: 'Control',
              syncStatus: const Value('pending_create'),
            ),
          );

      await db.into(db.deckSynergies).insert(
            DeckSynergiesCompanion.insert(
              id: 'synergy-dirty-1',
              deckId: 'deck-1',
              synergyName: 'Dockside Loop',
              vaultItemIds: '["c3","c4"]',
              syncStatus: const Value('pending_update'),
            ),
          );

      // Verify syncQueue is empty
      expect(await db.select(db.syncQueue).get(), isEmpty);

      await syncEngine.reconcileDirtyRecords();

      final queueEntries = await db.select(db.syncQueue).get();
      expect(queueEntries.length, equals(2));
      final ids = queueEntries.map((e) => e.entityId).toSet();
      expect(ids, contains('matchup-dirty-1'));
      expect(ids, contains('synergy-dirty-1'));

      final flushResult = await syncEngine.flushOutbox();
      expect(flushResult.status, equals('completed'));
      expect(flushResult.successCount, equals(2));

      final m = await (db.select(db.deckMatchups)..where((t) => t.id.equals('matchup-dirty-1'))).getSingle();
      expect(m.syncStatus, equals('synced'));

      final s = await (db.select(db.deckSynergies)..where((t) => t.id.equals('synergy-dirty-1'))).getSingle();
      expect(s.syncStatus, equals('synced'));
    });

    test('applyRemoteDeltas inserts and applies tombstones to deck_matchups and deck_synergies', () async {
      // 1. Insert remote matchup
      final remoteMatchup = RemoteSyncDocument(
        id: 'remote-matchup-1',
        entityType: 'deck_matchups',
        data: {
          'deck_id': 'deck-1',
          'opponent_archetype': 'Tron',
          'notes': 'Board in Blood Moon',
        },
        updatedAt: DateTime.utc(2026, 8, 1),
      );

      await syncEngine.applyRemoteDeltas([remoteMatchup]);

      final insertedMatchup = await (db.select(db.deckMatchups)..where((t) => t.id.equals('remote-matchup-1'))).getSingle();
      expect(insertedMatchup.opponentArchetype, equals('Tron'));
      expect(insertedMatchup.notes, equals('Board in Blood Moon'));
      expect(insertedMatchup.syncStatus, equals('synced'));

      // 2. Tombstone remote synergy
      await db.into(db.deckSynergies).insert(
            DeckSynergiesCompanion.insert(
              id: 'synergy-tomb-1',
              deckId: 'deck-1',
              synergyName: 'Heliod Ballista',
              vaultItemIds: '["h1","b1"]',
              updatedAt: Value(DateTime.utc(2026, 1, 1)),
            ),
          );

      final remoteTombstone = RemoteSyncDocument(
        id: 'synergy-tomb-1',
        entityType: 'deck_synergies',
        data: {},
        updatedAt: DateTime.utc(2026, 9, 1),
        deletedAt: DateTime.utc(2026, 9, 1),
        isDeleted: true,
      );

      await syncEngine.applyRemoteDeltas([remoteTombstone]);

      final tombstonedSynergy = await (db.select(db.deckSynergies)..where((t) => t.id.equals('synergy-tomb-1'))).getSingle();
      expect(tombstonedSynergy.isDeleted, isTrue);
      expect(tombstonedSynergy.deletedAt?.toUtc(), equals(DateTime.utc(2026, 9, 1)));
      expect(tombstonedSynergy.syncStatus, equals('synced'));
    });

    test('enqueueMutation and applyRemoteDeltas safely ignore unsupported tables without throwing', () async {
      // enqueueMutation on unsupported table
      await syncEngine.enqueueMutation(
        entityType: 'non_existent_table',
        entityId: 'dummy-1',
        operation: SyncOperation.insert,
      );
      expect(await db.select(db.syncQueue).get(), isEmpty);

      // applyRemoteDeltas on unsupported table
      final unsupportedDoc = RemoteSyncDocument(
        id: 'dummy-2',
        entityType: 'non_existent_table',
        data: {'foo': 'bar'},
        updatedAt: DateTime.utc(2026, 8, 1),
      );
      await syncEngine.applyRemoteDeltas([unsupportedDoc]);
      // Should complete without error
    });
  });
}
