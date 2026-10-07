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
  
  // Soft Delete & Outbox Sync (v9)
  BoolColumn get isDeleted =>
      boolean().named('is_deleted').withDefault(const Constant(false))();
  DateTimeColumn get updatedAt =>
      dateTime().named('updated_at').nullable()();

  // Clone & Explore Lineage (v11)
  BoolColumn get isCloned =>
      boolean().named('is_cloned').withDefault(const Constant(false))();
  TextColumn get sourceExploreDeckId =>
      text().named('source_explore_deck_id').nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
