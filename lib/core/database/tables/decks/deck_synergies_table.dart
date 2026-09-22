import 'package:drift/drift.dart';
import 'package:countr/core/database/tables/decks/decks_table.dart';

@DataClassName('DeckSynergy')
class DeckSynergies extends Table {
  TextColumn get id => text()();
  TextColumn get deckId => text().references(Decks, #id)();
  TextColumn get synergyName => text()();
  TextColumn get vaultItemIds => text()(); // JSON list of combo pieces
  
  @override
  Set<Column> get primaryKey => {id};
}
