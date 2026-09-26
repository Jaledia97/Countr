import 'package:drift/drift.dart';

/// SyncQueue Drift Table
/// Outbox table logging all local database mutations for eventual cloud synchronization.
@DataClassName('SyncQueueEntry')
class SyncQueue extends Table {
  /// Unique mutation ID (UUID v4)
  TextColumn get id => text()();

  /// Entity table type (e.g. 'vault_item', 'deck', 'binder', 'deck_version', 'deck_version_item')
  TextColumn get entityType => text().named('entity_type')();

  /// Target entity primary key ID
  TextColumn get entityId => text().named('entity_id')();

  /// Mutation operation: 'INSERT', 'UPDATE', 'DELETE'
  TextColumn get operation => text()();

  /// Timestamp when mutation occurred
  DateTimeColumn get timestamp => dateTime()();

  /// Number of sync attempt retries
  IntColumn get retryCount =>
      integer().named('retry_count').withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}
