import 'package:drift/drift.dart';

/// The VaultBinders Schema
/// Represents customized card binders / portfolio albums for individual collections.
class VaultBinders extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get collectionType => text().named('collection_type')();
  DateTimeColumn get createdAt => dateTime().named('created_at')();

  // System Binder Architecture (Epic 3 / v12)
  BoolColumn get isSystemBinder =>
      boolean().named('is_system_binder').withDefault(const Constant(false)).nullable()();
  TextColumn get systemBinderType =>
      text().named('system_binder_type').nullable()();
  TextColumn get userId =>
      text().named('user_id').nullable()();

  // Soft Delete & Outbox Sync (v9 & v12 / Epic 5)
  BoolColumn get isDeleted =>
      boolean().named('is_deleted').withDefault(const Constant(false))();
  DateTimeColumn get updatedAt =>
      dateTime().named('updated_at').nullable()();
  DateTimeColumn get deletedAt =>
      dateTime().named('deleted_at').nullable()();
  TextColumn get syncStatus =>
      text().named('sync_status').withDefault(const Constant('synced')).nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
