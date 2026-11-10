import 'package:drift/drift.dart';
import 'package:countr/core/database/tables/decks/deck_versions_table.dart';
import 'package:countr/core/database/tables/vault_items_table.dart';

@DataClassName('DeckVersionItem')
class DeckVersionItems extends Table {
  TextColumn get id => text()();
  TextColumn get versionId => text().references(DeckVersions, #id)();
  TextColumn get vaultItemId => text().references(VaultItems, #id)();
  IntColumn get quantity => integer().withDefault(const Constant(1))();
  TextColumn get boardZone => text()(); // Mainboard, Sideboard, Maybeboard, Commander
  BoolColumn get isProxy => boolean().withDefault(const Constant(false))();

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
