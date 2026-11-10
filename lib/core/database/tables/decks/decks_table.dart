import 'package:drift/drift.dart';

@DataClassName('Deck')
class Decks extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get format => text()();
  TextColumn get description => text().nullable()();
  IntColumn get wins => integer().withDefault(const Constant(0))();
  IntColumn get losses => integer().withDefault(const Constant(0))();
  IntColumn get draws => integer().withDefault(const Constant(0))();
  TextColumn get coverItemId => text().nullable()();
  TextColumn get coverCropRect => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get tcgDomain => text().withDefault(const Constant('mtg'))();
  BoolColumn get isRegistered => boolean().withDefault(const Constant(false))();
  BoolColumn get isCompetitive => boolean().withDefault(const Constant(false))();
  BoolColumn get isAssembled =>
      boolean().named('is_assembled').withDefault(const Constant(false))();
  
  // User Scoping & Guest Migration (v12 / Epic 3)
  TextColumn get userId => text().named('user_id').nullable()();

  // Soft Delete & Outbox Sync (v9 & v12 / Epic 5)
  BoolColumn get isDeleted =>
      boolean().named('is_deleted').withDefault(const Constant(false))();
  DateTimeColumn get updatedAt =>
      dateTime().named('updated_at').nullable()();
  DateTimeColumn get deletedAt =>
      dateTime().named('deleted_at').nullable()();
  TextColumn get syncStatus =>
      text().named('sync_status').withDefault(const Constant('synced')).nullable()();

  // Clone & Explore Lineage (v11)
  BoolColumn get isCloned =>
      boolean().named('is_cloned').withDefault(const Constant(false))();
  TextColumn get sourceExploreDeckId =>
      text().named('source_explore_deck_id').nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
