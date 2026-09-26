import 'package:drift/drift.dart';
import 'package:countr/core/database/tables/decks/decks_table.dart';

@DataClassName('DeckSynergy')
class DeckSynergies extends Table {
  TextColumn get id => text()();
  TextColumn get deckId => text().references(Decks, #id)();
  TextColumn get synergyName => text()();
  TextColumn get vaultItemIds => text()(); // JSON list of combo pieces
  
  // Soft Delete & Outbox Sync (v9)
  BoolColumn get isDeleted =>
      boolean().named('is_deleted').withDefault(const Constant(false))();
  DateTimeColumn get updatedAt =>
      dateTime().named('updated_at').nullable()();
  
  @override
  Set<Column> get primaryKey => {id};
}
