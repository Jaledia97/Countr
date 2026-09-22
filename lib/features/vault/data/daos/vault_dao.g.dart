// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vault_dao.dart';

// ignore_for_file: type=lint
mixin _$VaultDaoMixin on DatabaseAccessor<AppDatabase> {
  $VaultBindersTable get vaultBinders => attachedDatabase.vaultBinders;
  $VaultItemsTable get vaultItems => attachedDatabase.vaultItems;
  $DecksTable get decks => attachedDatabase.decks;
  $DeckVersionsTable get deckVersions => attachedDatabase.deckVersions;
  $DeckVersionItemsTable get deckVersionItems =>
      attachedDatabase.deckVersionItems;
  $DeckMatchupsTable get deckMatchups => attachedDatabase.deckMatchups;
  $DeckSynergiesTable get deckSynergies => attachedDatabase.deckSynergies;
  VaultDaoManager get managers => VaultDaoManager(this);
}

class VaultDaoManager {
  final _$VaultDaoMixin _db;
  VaultDaoManager(this._db);
  $$VaultBindersTableTableManager get vaultBinders =>
      $$VaultBindersTableTableManager(_db.attachedDatabase, _db.vaultBinders);
  $$VaultItemsTableTableManager get vaultItems =>
      $$VaultItemsTableTableManager(_db.attachedDatabase, _db.vaultItems);
  $$DecksTableTableManager get decks =>
      $$DecksTableTableManager(_db.attachedDatabase, _db.decks);
  $$DeckVersionsTableTableManager get deckVersions =>
      $$DeckVersionsTableTableManager(_db.attachedDatabase, _db.deckVersions);
  $$DeckVersionItemsTableTableManager get deckVersionItems =>
      $$DeckVersionItemsTableTableManager(
        _db.attachedDatabase,
        _db.deckVersionItems,
      );
  $$DeckMatchupsTableTableManager get deckMatchups =>
      $$DeckMatchupsTableTableManager(_db.attachedDatabase, _db.deckMatchups);
  $$DeckSynergiesTableTableManager get deckSynergies =>
      $$DeckSynergiesTableTableManager(_db.attachedDatabase, _db.deckSynergies);
}
