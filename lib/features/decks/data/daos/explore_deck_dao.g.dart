// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'explore_deck_dao.dart';

// ignore_for_file: type=lint
mixin _$ExploreDeckDaoMixin on DatabaseAccessor<AppDatabase> {
  $ExploreDecksTable get exploreDecks => attachedDatabase.exploreDecks;
  $ExploreDeckItemsTable get exploreDeckItems =>
      attachedDatabase.exploreDeckItems;
  $ExploreDeckVotesTable get exploreDeckVotes =>
      attachedDatabase.exploreDeckVotes;
  $DecksTable get decks => attachedDatabase.decks;
  $DeckVersionsTable get deckVersions => attachedDatabase.deckVersions;
  $VaultBindersTable get vaultBinders => attachedDatabase.vaultBinders;
  $VaultItemsTable get vaultItems => attachedDatabase.vaultItems;
  $DeckVersionItemsTable get deckVersionItems =>
      attachedDatabase.deckVersionItems;
  $SyncQueueTable get syncQueue => attachedDatabase.syncQueue;
  ExploreDeckDaoManager get managers => ExploreDeckDaoManager(this);
}

class ExploreDeckDaoManager {
  final _$ExploreDeckDaoMixin _db;
  ExploreDeckDaoManager(this._db);
  $$ExploreDecksTableTableManager get exploreDecks =>
      $$ExploreDecksTableTableManager(_db.attachedDatabase, _db.exploreDecks);
  $$ExploreDeckItemsTableTableManager get exploreDeckItems =>
      $$ExploreDeckItemsTableTableManager(
        _db.attachedDatabase,
        _db.exploreDeckItems,
      );
  $$ExploreDeckVotesTableTableManager get exploreDeckVotes =>
      $$ExploreDeckVotesTableTableManager(
        _db.attachedDatabase,
        _db.exploreDeckVotes,
      );
  $$DecksTableTableManager get decks =>
      $$DecksTableTableManager(_db.attachedDatabase, _db.decks);
  $$DeckVersionsTableTableManager get deckVersions =>
      $$DeckVersionsTableTableManager(_db.attachedDatabase, _db.deckVersions);
  $$VaultBindersTableTableManager get vaultBinders =>
      $$VaultBindersTableTableManager(_db.attachedDatabase, _db.vaultBinders);
  $$VaultItemsTableTableManager get vaultItems =>
      $$VaultItemsTableTableManager(_db.attachedDatabase, _db.vaultItems);
  $$DeckVersionItemsTableTableManager get deckVersionItems =>
      $$DeckVersionItemsTableTableManager(
        _db.attachedDatabase,
        _db.deckVersionItems,
      );
  $$SyncQueueTableTableManager get syncQueue =>
      $$SyncQueueTableTableManager(_db.attachedDatabase, _db.syncQueue);
}
