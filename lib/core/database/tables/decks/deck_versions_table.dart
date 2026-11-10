import 'package:drift/drift.dart';
import 'package:countr/core/database/tables/decks/decks_table.dart';

@DataClassName('DeckVersion')
class DeckVersions extends Table {
  TextColumn get id => text()();
  TextColumn get deckId => text().references(Decks, #id)();
  IntColumn get versionNumber => integer()();
  TextColumn get versionNote => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();

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
