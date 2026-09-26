import 'package:drift/drift.dart';
import 'package:countr/core/database/tables/decks/decks_table.dart';

@DataClassName('DeckMatchup')
class DeckMatchups extends Table {
  TextColumn get id => text()();
  TextColumn get deckId => text().references(Decks, #id)();
  TextColumn get opponentArchetype => text()();
  TextColumn get notes => text().nullable()();
  TextColumn get swapInItemIds => text().nullable()(); // JSON list
  TextColumn get swapOutItemIds => text().nullable()(); // JSON list
  
  // Soft Delete & Outbox Sync (v9)
  BoolColumn get isDeleted =>
      boolean().named('is_deleted').withDefault(const Constant(false))();
  DateTimeColumn get updatedAt =>
      dateTime().named('updated_at').nullable()();
  
  @override
  Set<Column> get primaryKey => {id};
}
