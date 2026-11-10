import 'dart:async';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/sync/gateways/remote_sync_gateway.dart';
import 'package:countr/core/sync/models/sync_status.dart';
import 'package:countr/core/sync/services/connectivity_stream_service.dart';
import 'package:countr/core/sync/sync_engine.dart';

class EmpiricalMockGateway implements RemoteSyncGateway {
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
    throwError = null;
  }
}

class EmpiricalMockConnectivity implements ConnectivityStreamService {
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
  late EmpiricalMockGateway gateway;
  late EmpiricalMockConnectivity connectivity;
  late SyncEngine syncEngine;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    gateway = EmpiricalMockGateway();
    connectivity = EmpiricalMockConnectivity();
    syncEngine = SyncEngine(
      db: db,
      remoteGateway: gateway,
      connectivityService: connectivity,
      mutationDebounceDuration: const Duration(milliseconds: 50),
    );
    syncEngine.initialize();

    // Seed parent deck for foreign key integrity
    await db.into(db.decks).insert(
          DecksCompanion.insert(
            id: 'deck-emp-parent',
            name: 'Empirical Parent Deck',
            format: 'Modern',
            createdAt: DateTime.utc(2026, 1, 1),
          ),
        );
  });

  tearDown(() async {
    syncEngine.dispose();
    connectivity.dispose();
    await db.close();
  });

  group('Empirical Challenge: deck_matchups Outbox & Schema Lifecycle', () {
    test('deck_matchups handles insert, update, and soft-delete tombstone with correct sync_status, updated_at, deleted_at', () async {
      final t0 = DateTime.utc(2026, 6, 1, 12, 0, 0);
      final t1 = DateTime.utc(2026, 6, 1, 12, 30, 0);
      final t2 = DateTime.utc(2026, 6, 1, 13, 0, 0);

      // 1. Initial insert via Drift
      await db.into(db.deckMatchups).insert(
            DeckMatchupsCompanion.insert(
              id: 'matchup-emp-1',
              deckId: 'deck-emp-parent',
              opponentArchetype: 'Affinity',
              notes: const Value('Bring in Stony Silence'),
              updatedAt: Value(t0),
            ),
          );

      // Verify defaults
      var row = await (db.select(db.deckMatchups)..where((t) => t.id.equals('matchup-emp-1'))).getSingle();
      expect(row.syncStatus, equals('synced'));
      expect(row.isDeleted, isFalse);
      expect(row.deletedAt, isNull);

      // 2. Enqueue mutation: INSERT
      await syncEngine.enqueueMutation(
        entityType: 'deck_matchups',
        entityId: 'matchup-emp-1',
        operation: SyncOperation.insert,
        timestamp: t0,
      );

      row = await (db.select(db.deckMatchups)..where((t) => t.id.equals('matchup-emp-1'))).getSingle();
      expect(row.syncStatus, equals('pending_create'));
      expect(row.isDeleted, isFalse);
      expect(row.deletedAt, isNull);

      // Flush
      var flushResult = await syncEngine.flushOutbox();
      expect(flushResult.status, equals('completed'));
      expect(flushResult.successCount, equals(1));
      expect(gateway.pushedMutations.length, equals(1));
      expect(gateway.pushedMutations.first['entityType'], equals('deck_matchups'));
      expect(gateway.pushedMutations.first['operation'], equals(SyncOperation.insert));
      expect(gateway.pushedMutations.first['payload']['notes'], equals('Bring in Stony Silence'));

      row = await (db.select(db.deckMatchups)..where((t) => t.id.equals('matchup-emp-1'))).getSingle();
      expect(row.syncStatus, equals('synced'));

      // 3. Enqueue mutation: UPDATE
      gateway.clear();
      await syncEngine.enqueueMutation(
        entityType: 'deck_matchup', // Test singular resolution
        entityId: 'matchup-emp-1',
        operation: SyncOperation.update,
        timestamp: t1,
      );

      row = await (db.select(db.deckMatchups)..where((t) => t.id.equals('matchup-emp-1'))).getSingle();
      expect(row.syncStatus, equals('pending_update'));
      expect(row.updatedAt?.toUtc(), equals(t1));

      flushResult = await syncEngine.flushOutbox();
      expect(flushResult.status, equals('completed'));
      expect(gateway.pushedMutations.length, equals(1));
      expect(gateway.pushedMutations.first['operation'], equals(SyncOperation.update));

      row = await (db.select(db.deckMatchups)..where((t) => t.id.equals('matchup-emp-1'))).getSingle();
      expect(row.syncStatus, equals('synced'));

      // 4. Enqueue mutation: DELETE (Tombstone)
      gateway.clear();
      await syncEngine.enqueueMutation(
        entityType: 'matchups', // Test alias resolution
        entityId: 'matchup-emp-1',
        operation: SyncOperation.delete,
        timestamp: t2,
      );

      row = await (db.select(db.deckMatchups)..where((t) => t.id.equals('matchup-emp-1'))).getSingle();
      expect(row.syncStatus, equals('pending_delete'));
      expect(row.isDeleted, isTrue);
      expect(row.deletedAt?.toUtc(), equals(t2));
      expect(row.updatedAt?.toUtc(), equals(t2));

      flushResult = await syncEngine.flushOutbox();
      expect(flushResult.status, equals('completed'));
      expect(gateway.pushedMutations.length, equals(1));
      expect(gateway.pushedMutations.first['operation'], equals(SyncOperation.delete));

      row = await (db.select(db.deckMatchups)..where((t) => t.id.equals('matchup-emp-1'))).getSingle();
      expect(row.syncStatus, equals('synced'));
      expect(row.isDeleted, isTrue);
      expect(row.deletedAt?.toUtc(), equals(t2));

      // 5. Query with deletedAt filter should omit the record
      final activeList = await (db.select(db.deckMatchups)
            ..where((t) => t.isDeleted.equals(false) & t.deletedAt.isNull()))
          .get();
      expect(activeList.any((m) => m.id == 'matchup-emp-1'), isFalse);
    });

    test('deck_matchups resists resurrection from older remote delta', () async {
      final deleteTime = DateTime.utc(2026, 8, 1, 10, 0, 0);
      await db.into(db.deckMatchups).insert(
            DeckMatchupsCompanion.insert(
              id: 'matchup-tomb-resurrect',
              deckId: 'deck-emp-parent',
              opponentArchetype: 'Jund',
              notes: const Value('Original notes'),
              updatedAt: Value(DateTime.utc(2026, 7, 1)),
            ),
          );

      await syncEngine.enqueueMutation(
        entityType: 'deck_matchups',
        entityId: 'matchup-tomb-resurrect',
        operation: SyncOperation.delete,
        timestamp: deleteTime,
      );
      await syncEngine.flushOutbox();

      // Older remote delta arrives
      final olderDelta = RemoteSyncDocument(
        id: 'matchup-tomb-resurrect',
        entityType: 'deck_matchups',
        data: {'opponent_archetype': 'Jund Resurrected', 'notes': 'Overwritten'},
        updatedAt: DateTime.utc(2026, 7, 15), // older than deleteTime
        isDeleted: false,
      );

      await syncEngine.applyRemoteDeltas([olderDelta]);

      final row = await (db.select(db.deckMatchups)..where((t) => t.id.equals('matchup-tomb-resurrect'))).getSingle();
      expect(row.isDeleted, isTrue);
      expect(row.deletedAt, isNotNull);
      expect(row.opponentArchetype, equals('Jund'));
    });
  });

  group('Empirical Challenge: deck_synergies Outbox & Schema Lifecycle', () {
    test('deck_synergies handles insert, update, and soft-delete tombstone with correct sync_status, updated_at, deleted_at', () async {
      final t0 = DateTime.utc(2026, 7, 1, 14, 0, 0);
      final t1 = DateTime.utc(2026, 7, 1, 14, 45, 0);
      final t2 = DateTime.utc(2026, 7, 1, 15, 30, 0);

      // 1. Initial insert
      await db.into(db.deckSynergies).insert(
            DeckSynergiesCompanion.insert(
              id: 'synergy-emp-1',
              deckId: 'deck-emp-parent',
              synergyName: 'Kiki-Jiki + Restoration Angel',
              vaultItemIds: '["card-kiki", "card-angel"]',
              updatedAt: Value(t0),
            ),
          );

      var row = await (db.select(db.deckSynergies)..where((t) => t.id.equals('synergy-emp-1'))).getSingle();
      expect(row.syncStatus, equals('synced'));
      expect(row.isDeleted, isFalse);
      expect(row.deletedAt, isNull);

      // 2. Enqueue INSERT
      await syncEngine.enqueueMutation(
        entityType: 'deck_synergies',
        entityId: 'synergy-emp-1',
        operation: SyncOperation.insert,
        timestamp: t0,
      );

      row = await (db.select(db.deckSynergies)..where((t) => t.id.equals('synergy-emp-1'))).getSingle();
      expect(row.syncStatus, equals('pending_create'));

      var flushResult = await syncEngine.flushOutbox();
      expect(flushResult.status, equals('completed'));
      expect(gateway.pushedMutations.length, equals(1));
      expect(gateway.pushedMutations.first['entityType'], equals('deck_synergies'));
      expect(gateway.pushedMutations.first['payload']['synergy_name'], equals('Kiki-Jiki + Restoration Angel'));

      row = await (db.select(db.deckSynergies)..where((t) => t.id.equals('synergy-emp-1'))).getSingle();
      expect(row.syncStatus, equals('synced'));

      // 3. Enqueue UPDATE
      gateway.clear();
      await syncEngine.enqueueMutation(
        entityType: 'synergies', // Test alias
        entityId: 'synergy-emp-1',
        operation: SyncOperation.update,
        timestamp: t1,
      );

      row = await (db.select(db.deckSynergies)..where((t) => t.id.equals('synergy-emp-1'))).getSingle();
      expect(row.syncStatus, equals('pending_update'));
      expect(row.updatedAt?.toUtc(), equals(t1));

      flushResult = await syncEngine.flushOutbox();
      expect(flushResult.status, equals('completed'));
      row = await (db.select(db.deckSynergies)..where((t) => t.id.equals('synergy-emp-1'))).getSingle();
      expect(row.syncStatus, equals('synced'));

      // 4. Enqueue DELETE
      gateway.clear();
      await syncEngine.enqueueMutation(
        entityType: 'deck_synergy', // Test singular
        entityId: 'synergy-emp-1',
        operation: SyncOperation.delete,
        timestamp: t2,
      );

      row = await (db.select(db.deckSynergies)..where((t) => t.id.equals('synergy-emp-1'))).getSingle();
      expect(row.syncStatus, equals('pending_delete'));
      expect(row.isDeleted, isTrue);
      expect(row.deletedAt?.toUtc(), equals(t2));

      flushResult = await syncEngine.flushOutbox();
      expect(flushResult.status, equals('completed'));
      row = await (db.select(db.deckSynergies)..where((t) => t.id.equals('synergy-emp-1'))).getSingle();
      expect(row.syncStatus, equals('synced'));
      expect(row.isDeleted, isTrue);
      expect(row.deletedAt?.toUtc(), equals(t2));

      // 5. Query active
      final activeList = await (db.select(db.deckSynergies)
            ..where((t) => t.isDeleted.equals(false) & t.deletedAt.isNull()))
          .get();
      expect(activeList.any((s) => s.id == 'synergy-emp-1'), isFalse);
    });

    test('deck_synergies resists resurrection from older remote delta', () async {
      await db.into(db.deckSynergies).insert(
            DeckSynergiesCompanion.insert(
              id: 'synergy-tomb-resurrect',
              deckId: 'deck-emp-parent',
              synergyName: 'Thopter Foundry Combo',
              vaultItemIds: '["c1","c2"]',
              updatedAt: Value(DateTime.utc(2026, 7, 1)),
            ),
          );

      await syncEngine.softDeleteEntity(
        entityType: 'deck_synergies',
        entityId: 'synergy-tomb-resurrect',
      );
      await syncEngine.flushOutbox();

      final olderDelta = RemoteSyncDocument(
        id: 'synergy-tomb-resurrect',
        entityType: 'deck_synergies',
        data: {'synergy_name': 'Thopter Foundry Resurrected'},
        updatedAt: DateTime.utc(2026, 7, 15),
        isDeleted: false,
      );

      await syncEngine.applyRemoteDeltas([olderDelta]);

      final row = await (db.select(db.deckSynergies)..where((t) => t.id.equals('synergy-tomb-resurrect'))).getSingle();
      expect(row.isDeleted, isTrue);
      expect(row.deletedAt, isNotNull);
      expect(row.synergyName, equals('Thopter Foundry Combo'));
    });
  });

  group('Empirical Challenge: Unsupported Tables & Malformed Names', () {
    test('enqueueMutation safely ignores arbitrary unsupported table names without throwing or enqueuing', () async {
      final unsupportedNames = [
        'users_backup',
        'cards_cache',
        'scryfall_raw',
        'arbitrary_table',
        'deck_matchups_old',
        '; DROP TABLE decks; --',
        '\' OR 1=1 --',
        '',
      ];

      for (final badName in unsupportedNames) {
        await expectLater(
          syncEngine.enqueueMutation(
            entityType: badName,
            entityId: 'dummy-id',
            operation: SyncOperation.insert,
          ),
          completes,
        );
      }

      // Ensure outbox queue is completely empty
      final queue = await db.select(db.syncQueue).get();
      expect(queue, isEmpty);

      // Flush should do nothing
      final flushResult = await syncEngine.flushOutbox();
      expect(flushResult.successCount, equals(0));
      expect(gateway.pushedMutations, isEmpty);
    });

    test('softDeleteEntity safely ignores unsupported table names', () async {
      await expectLater(
        syncEngine.softDeleteEntity(
          entityType: 'unknown_social_table',
          entityId: 'dummy-id',
        ),
        completes,
      );
      expect(await db.select(db.syncQueue).get(), isEmpty);
    });

    test('applyRemoteDeltas safely ignores unsupported table names and malformed documents without crashing or corrupting database', () async {
      final bogusDocs = [
        RemoteSyncDocument(
          id: 'bad-1',
          entityType: 'invalid_entity_type',
          data: {'col': 'val'},
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
        RemoteSyncDocument(
          id: 'bad-2',
          entityType: 'sqlite_master',
          data: {'sql': 'malicious'},
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
        RemoteSyncDocument(
          id: 'bad-3',
          entityType: 'decks; drop table decks;',
          data: {},
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
      ];

      await expectLater(
        syncEngine.applyRemoteDeltas(bogusDocs),
        completes,
      );

      // Verify decks table remains healthy and accessible
      final decks = await db.select(db.decks).get();
      expect(decks.any((d) => d.id == 'deck-emp-parent'), isTrue);
    });
  });

  group('Empirical Challenge: All 15 Target Tables in targetTables', () {
    test('targetTables contains all 13 specified tables plus social tables, and all resolve correctly', () {
      final expectedRequiredTables = [
        'vault_items',
        'vault_binders',
        'decks',
        'deck_versions',
        'deck_version_items',
        'deck_matchups',
        'deck_synergies',
        'explore_deck_votes',
        'user_profiles',
        'friendships',
        'feed_posts',
        'post_likes',
        'post_comments',
        'notifications',
        'trade_proposals',
      ];

      for (final table in expectedRequiredTables) {
        expect(SyncEngine.targetTables, contains(table), reason: 'SyncEngine.targetTables must contain $table');
      }

      // Test resolveTableName aliases
      expect(SyncEngine.resolveTableName('deck_matchup'), equals('deck_matchups'));
      expect(SyncEngine.resolveTableName('deck_matchups'), equals('deck_matchups'));
      expect(SyncEngine.resolveTableName('matchup'), equals('deck_matchups'));
      expect(SyncEngine.resolveTableName('matchups'), equals('deck_matchups'));

      expect(SyncEngine.resolveTableName('deck_synergy'), equals('deck_synergies'));
      expect(SyncEngine.resolveTableName('deck_synergies'), equals('deck_synergies'));
      expect(SyncEngine.resolveTableName('synergy'), equals('deck_synergies'));
      expect(SyncEngine.resolveTableName('synergies'), equals('deck_synergies'));

      expect(SyncEngine.resolveTableName('vault_item'), equals('vault_items'));
      expect(SyncEngine.resolveTableName('binder'), equals('vault_binders'));
      expect(SyncEngine.resolveTableName('deck'), equals('decks'));
      expect(SyncEngine.resolveTableName('feed_post'), equals('feed_posts'));
      expect(SyncEngine.resolveTableName('trade_proposal'), equals('trade_proposals'));
      expect(SyncEngine.resolveTableName('explore_deck_vote'), equals('explore_deck_votes'));
    });
  });
}
