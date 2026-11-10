import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import 'gateways/remote_sync_gateway.dart';
import 'models/sync_status.dart';
import 'services/connectivity_stream_service.dart';

class SyncFlushResult {
  final int successCount;
  final int failureCount;
  final String status;

  const SyncFlushResult({
    required this.successCount,
    required this.failureCount,
    required this.status,
  });

  factory SyncFlushResult.aborted(String reason) => SyncFlushResult(
        successCount: 0,
        failureCount: 0,
        status: reason,
      );
}

class SyncEngine {
  final AppDatabase db;
  final RemoteSyncGateway remoteGateway;
  final ConnectivityStreamService connectivityService;
  final Duration mutationDebounceDuration;
  final Duration baseRetryDelay;
  final Duration maxRetryDelay;

  final Uuid _uuid = const Uuid();
  Timer? _debounceTimer;
  Timer? _retryTimer;
  StreamSubscription<bool>? _connectivitySub;
  bool _isFlushing = false;
  bool _flushPending = false;
  bool _disposed = false;

  static const List<String> targetTables = [
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

  SyncEngine({
    required this.db,
    required this.remoteGateway,
    required this.connectivityService,
    this.mutationDebounceDuration = const Duration(seconds: 3),
    this.baseRetryDelay = const Duration(seconds: 2),
    this.maxRetryDelay = const Duration(seconds: 60),
  });

  bool get isFlushing => _isFlushing;
  bool get hasActiveDebounce => _debounceTimer != null && _debounceTimer!.isActive;

  /// Initializes lifecycle listeners and connectivity stream.
  void initialize() {
    _connectivitySub = connectivityService.onConnectivityChanged.listen((isOnline) {
      if (isOnline) {
        flushOutbox(triggerReason: 'connectivity_restored');
      }
    });
  }

  /// Called when the app returns to foreground from background or lock screen.
  void handleAppResume() {
    flushOutbox(triggerReason: 'app_resume');
  }

  /// Normalizes plural / singular entity types to exact SQLite table names.
  static String resolveTableName(String entityType) {
    switch (entityType.toLowerCase()) {
      case 'vault_item':
      case 'vault_items':
        return 'vault_items';
      case 'vault_binder':
      case 'vault_binders':
      case 'binder':
      case 'binders':
        return 'vault_binders';
      case 'deck':
      case 'decks':
        return 'decks';
      case 'deck_version':
      case 'deck_versions':
        return 'deck_versions';
      case 'deck_version_item':
      case 'deck_version_items':
        return 'deck_version_items';
      case 'deck_matchup':
      case 'deck_matchups':
      case 'matchup':
      case 'matchups':
        return 'deck_matchups';
      case 'deck_synergy':
      case 'deck_synergies':
      case 'synergy':
      case 'synergies':
        return 'deck_synergies';
      case 'explore_deck_vote':
      case 'explore_deck_votes':
      case 'explore_votes':
        return 'explore_deck_votes';
      case 'user_profile':
      case 'user_profiles':
      case 'user':
      case 'users':
        return 'user_profiles';
      case 'friendship':
      case 'friendships':
        return 'friendships';
      case 'feed_post':
      case 'feed_posts':
      case 'post':
      case 'posts':
        return 'feed_posts';
      case 'post_like':
      case 'post_likes':
      case 'like':
      case 'likes':
        return 'post_likes';
      case 'post_comment':
      case 'post_comments':
      case 'comment':
      case 'comments':
        return 'post_comments';
      case 'notification':
      case 'notifications':
        return 'notifications';
      case 'trade_proposal':
      case 'trade_proposals':
      case 'trade':
      case 'trades':
        return 'trade_proposals';
      case 'message':
      case 'messages':
        return 'messages';
      default:
        return entityType;
    }
  }

  /// Enqueues a local mutation to the outbox queue and schedules debounced flush.
  Future<void> enqueueMutation({
    required String entityType,
    required String entityId,
    required SyncOperation operation,
    DateTime? timestamp,
  }) async {
    final nowUtc = (timestamp ?? DateTime.now()).toUtc();
    final mutationId = _uuid.v4();
    final tableName = resolveTableName(entityType);

    if (!targetTables.contains(tableName)) {
      debugPrint('[SyncEngine] enqueueMutation skipped: Unsupported table "$tableName"');
      return;
    }

    // Update entity's sync status in table
    final syncStatusWire = switch (operation) {
      SyncOperation.insert => SyncStatus.pendingCreate.wireName,
      SyncOperation.update => SyncStatus.pendingUpdate.wireName,
      SyncOperation.delete => SyncStatus.pendingDelete.wireName,
    };

    try {
      if (operation == SyncOperation.delete) {
        await db.customUpdate(
          'UPDATE "$tableName" SET "is_deleted" = 1, "deleted_at" = ?, "updated_at" = ?, "sync_status" = ? WHERE "id" = ?;',
          variables: [
            Variable.withDateTime(nowUtc),
            Variable.withDateTime(nowUtc),
            Variable.withString(syncStatusWire),
            Variable.withString(entityId),
          ],
        );
      } else {
        await db.customUpdate(
          'UPDATE "$tableName" SET "updated_at" = ?, "sync_status" = ? WHERE "id" = ?;',
          variables: [
            Variable.withDateTime(nowUtc),
            Variable.withString(syncStatusWire),
            Variable.withString(entityId),
          ],
        );
      }
    } catch (e, st) {
      debugPrint('[SyncEngine] Warning updating entity syncStatus for "$tableName": $e\n$st');
    }

    // Insert mutation into sync_queue
    await db.into(db.syncQueue).insert(
          SyncQueueCompanion.insert(
            id: mutationId,
            entityType: tableName,
            entityId: entityId,
            operation: operation.wireName,
            timestamp: nowUtc,
          ),
        );

    notifyLocalMutation();
  }

  /// Convenience soft-delete method that marks entity as soft-deleted tombstone and enqueues delete mutation.
  Future<void> softDeleteEntity({
    required String entityType,
    required String entityId,
  }) async {
    await enqueueMutation(
      entityType: entityType,
      entityId: entityId,
      operation: SyncOperation.delete,
    );
  }

  /// Debounces local mutations by 3 seconds before executing flush.
  void notifyLocalMutation() {
    if (_disposed) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(mutationDebounceDuration, () {
      flushOutbox(triggerReason: 'mutation_debounce');
    });
  }

  /// Executes flush of all pending mutations to Firestore.
  Future<SyncFlushResult> flushOutbox({String triggerReason = 'manual'}) async {
    if (_disposed) return SyncFlushResult.aborted('disposed');

    if (!connectivityService.isOnline) {
      return SyncFlushResult.aborted('offline');
    }

    if (_isFlushing) {
      _flushPending = true;
      return SyncFlushResult.aborted('flush_in_progress');
    }

    _isFlushing = true;
    _debounceTimer?.cancel();

    var successCount = 0;
    var failureCount = 0;

    try {
      final pendingEntries = await (db.select(db.syncQueue)
            ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]))
          .get();

      for (final entry in pendingEntries) {
        if (!connectivityService.isOnline) break;

        final tableName = resolveTableName(entry.entityType);
        final operation = SyncOperation.fromWire(entry.operation);

        // Fetch entity data to construct mutation payload
        Map<String, dynamic> payload = {};
        final rows = await db.customSelect(
          'SELECT * FROM "$tableName" WHERE "id" = ?;',
          variables: [Variable.withString(entry.entityId)],
        ).get();

        if (rows.isNotEmpty) {
          payload = Map<String, dynamic>.from(rows.first.data);
        }

        try {
          await remoteGateway.pushMutation(
            entityType: tableName,
            entityId: entry.entityId,
            operation: operation,
            payload: payload,
            updatedAt: entry.timestamp,
          );

          // On successful remote write: update entity sync_status to 'synced'
          await db.customUpdate(
            'UPDATE "$tableName" SET "sync_status" = \'synced\' WHERE "id" = ?;',
            variables: [Variable.withString(entry.entityId)],
          );

          // Remove mutation from sync_queue
          await (db.delete(db.syncQueue)..where((t) => t.id.equals(entry.id))).go();
          successCount++;
        } catch (error) {
          failureCount++;
          // Increment retryCount on entry
          await (db.update(db.syncQueue)..where((t) => t.id.equals(entry.id))).write(
            SyncQueueCompanion(
              retryCount: Value(entry.retryCount + 1),
            ),
          );

          // Schedule exponential backoff retry
          _scheduleRetry(entry.retryCount + 1);
        }
      }
    } finally {
      _isFlushing = false;
      if (_flushPending && connectivityService.isOnline) {
        _flushPending = false;
        flushOutbox(triggerReason: 'pending_retrigger');
      }
    }

    return SyncFlushResult(
      successCount: successCount,
      failureCount: failureCount,
      status: failureCount > 0 ? 'partial_failure' : 'completed',
    );
  }

  /// Calculates exponential backoff delay and schedules retry.
  void _scheduleRetry(int retryCount) {
    if (_disposed) return;
    _retryTimer?.cancel();
    final delayMs = baseRetryDelay.inMilliseconds * (1 << min(retryCount, 5));
    final cappedMs = min(delayMs, maxRetryDelay.inMilliseconds);
    _retryTimer = Timer(Duration(milliseconds: cappedMs), () {
      if (connectivityService.isOnline) {
        flushOutbox(triggerReason: 'retry_backoff');
      }
    });
  }

  static DateTime parseTimestamp(dynamic rawTs) {
    if (rawTs == null) return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    if (rawTs is int) {
      if (rawTs < 100000000000) {
        return DateTime.fromMillisecondsSinceEpoch(rawTs * 1000, isUtc: true);
      }
      return DateTime.fromMillisecondsSinceEpoch(rawTs, isUtc: true);
    }
    if (rawTs is DateTime) {
      return rawTs.toUtc();
    }
    return DateTime.tryParse(rawTs.toString())?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  /// Applies remote deltas using Last-Write-Wins based on UTC updatedAt.
  Future<void> applyRemoteDeltas(List<RemoteSyncDocument> deltas) async {
    for (final doc in deltas) {
      final tableName = resolveTableName(doc.entityType);
      if (!targetTables.contains(tableName)) {
        debugPrint('[SyncEngine] applyRemoteDeltas skipped: Unsupported table "$tableName"');
        continue;
      }

      try {
        final existingRows = await db.customSelect(
          'SELECT * FROM "$tableName" WHERE "id" = ?;',
          variables: [Variable.withString(doc.id)],
        ).get();

        if (existingRows.isEmpty) {
          // Remote entity is new locally: insert if not deleted
          if (!doc.isDeleted && doc.deletedAt == null) {
            final columns = <String>['"id"', '"updated_at"', '"sync_status"'];
            final values = <String>['?', '?', '\'synced\''];
            final vars = <Variable>[
              Variable.withString(doc.id),
              Variable.withDateTime(doc.updatedAt),
            ];

            for (final entry in doc.data.entries) {
              if (entry.key == 'id' || entry.key == 'updated_at' || entry.key == 'sync_status') {
                continue;
              }
              columns.add('"${entry.key}"');
              values.add('?');
              final val = entry.value;
              if (val is int) {
                vars.add(Variable.withInt(val));
              } else if (val is double) {
                vars.add(Variable.withReal(val));
              } else if (val is bool) {
                vars.add(Variable.withBool(val));
              } else if (val is DateTime) {
                vars.add(Variable.withDateTime(val));
              } else {
                vars.add(Variable.withString(val?.toString() ?? ''));
              }
            }

            try {
              await db.customInsert(
                'INSERT INTO "$tableName" (${columns.join(', ')}) VALUES (${values.join(', ')});',
                variables: vars,
              );
            } catch (_) {
              // Defensive ignore if columns differ from schema
            }
          }
        } else {
          // Local entity exists: compare updatedAt for Last-Write-Wins
          final localData = existingRows.first.data;
          final localUpdatedAt = parseTimestamp(localData['updated_at']);

          if (doc.updatedAt.isAfter(localUpdatedAt)) {
            // Remote delta wins!
            if (doc.isDeleted || doc.deletedAt != null) {
              final tombstone = doc.deletedAt ?? doc.updatedAt;
              try {
                await db.customUpdate(
                  'UPDATE "$tableName" SET "is_deleted" = 1, "deleted_at" = ?, "updated_at" = ?, "sync_status" = \'synced\' WHERE "id" = ?;',
                  variables: [
                    Variable.withDateTime(tombstone),
                    Variable.withDateTime(doc.updatedAt),
                    Variable.withString(doc.id),
                  ],
                );
              } catch (_) {}
            } else {
              // Update fields from doc.data
              final setClauses = <String>[
                '"updated_at" = ?',
                '"is_deleted" = 0',
                '"deleted_at" = NULL',
                '"sync_status" = \'synced\'',
              ];
              final vars = <Variable>[
                Variable.withDateTime(doc.updatedAt),
              ];

              for (final entry in doc.data.entries) {
                if (entry.key == 'id' ||
                    entry.key == 'updated_at' ||
                    entry.key == 'is_deleted' ||
                    entry.key == 'deleted_at' ||
                    entry.key == 'sync_status') {
                  continue;
                }
                setClauses.add('"${entry.key}" = ?');
                final val = entry.value;
                if (val is int) {
                  vars.add(Variable.withInt(val));
                } else if (val is double) {
                  vars.add(Variable.withReal(val));
                } else if (val is bool) {
                  vars.add(Variable.withBool(val));
                } else if (val is DateTime) {
                  vars.add(Variable.withDateTime(val));
                } else {
                  vars.add(Variable.withString(val?.toString() ?? ''));
                }
              }

              vars.add(Variable.withString(doc.id));
              try {
                await db.customUpdate(
                  'UPDATE "$tableName" SET ${setClauses.join(', ')} WHERE "id" = ?;',
                  variables: vars,
                );
              } catch (_) {}
            }
          }
          // If local is newer, do not overwrite; local record remains dirty and will push on next flush
        }
      } catch (e, st) {
        debugPrint('[SyncEngine] Error applying remote delta for $tableName / ${doc.id}: $e\n$st');
      }
    }
  }

  /// Sweeps all target tables for rows where syncStatus != 'synced' and enqueues missing outbox entries.
  Future<void> reconcileDirtyRecords() async {
    for (final table in targetTables) {
      try {
        final dirtyRows = await db.customSelect(
          'SELECT "id", "updated_at", "is_deleted", "sync_status" FROM "$table" WHERE "sync_status" IS NOT NULL AND "sync_status" != \'synced\';',
        ).get();

        for (final row in dirtyRows) {
          final id = row.read<String>('id');
          final syncStatus = row.read<String>('sync_status');

          // Check if already in sync_queue
          final inQueue = await (db.select(db.syncQueue)
                ..where((t) => t.entityType.equals(table) & t.entityId.equals(id)))
              .get();

          if (inQueue.isEmpty) {
            final op = switch (syncStatus) {
              'pending_create' => SyncOperation.insert,
              'pending_delete' => SyncOperation.delete,
              _ => SyncOperation.update,
            };

            await db.into(db.syncQueue).insert(
                  SyncQueueCompanion.insert(
                    id: _uuid.v4(),
                    entityType: table,
                    entityId: id,
                    operation: op.wireName,
                    timestamp: DateTime.now().toUtc(),
                  ),
                );
          }
        }
      } catch (_) {
        // Safe skip if table does not exist in testing mock
      }
    }
  }

  /// Disposes timers and subscriptions.
  void dispose() {
    _disposed = true;
    _debounceTimer?.cancel();
    _retryTimer?.cancel();
    _connectivitySub?.cancel();
  }
}
