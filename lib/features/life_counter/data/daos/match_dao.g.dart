// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'match_dao.dart';

// ignore_for_file: type=lint
mixin _$MatchDaoMixin on DatabaseAccessor<AppDatabase> {
  $MatchSessionsTable get matchSessions => attachedDatabase.matchSessions;
  $DecksTable get decks => attachedDatabase.decks;
  $VaultBindersTable get vaultBinders => attachedDatabase.vaultBinders;
  $VaultItemsTable get vaultItems => attachedDatabase.vaultItems;
  $MatchPlayersTable get matchPlayers => attachedDatabase.matchPlayers;
  $MatchEventsTable get matchEvents => attachedDatabase.matchEvents;
  $SyncQueueTable get syncQueue => attachedDatabase.syncQueue;
  MatchDaoManager get managers => MatchDaoManager(this);
}

class MatchDaoManager {
  final _$MatchDaoMixin _db;
  MatchDaoManager(this._db);
  $$MatchSessionsTableTableManager get matchSessions =>
      $$MatchSessionsTableTableManager(_db.attachedDatabase, _db.matchSessions);
  $$DecksTableTableManager get decks =>
      $$DecksTableTableManager(_db.attachedDatabase, _db.decks);
  $$VaultBindersTableTableManager get vaultBinders =>
      $$VaultBindersTableTableManager(_db.attachedDatabase, _db.vaultBinders);
  $$VaultItemsTableTableManager get vaultItems =>
      $$VaultItemsTableTableManager(_db.attachedDatabase, _db.vaultItems);
  $$MatchPlayersTableTableManager get matchPlayers =>
      $$MatchPlayersTableTableManager(_db.attachedDatabase, _db.matchPlayers);
  $$MatchEventsTableTableManager get matchEvents =>
      $$MatchEventsTableTableManager(_db.attachedDatabase, _db.matchEvents);
  $$SyncQueueTableTableManager get syncQueue =>
      $$SyncQueueTableTableManager(_db.attachedDatabase, _db.syncQueue);
}
