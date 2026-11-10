// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inbox_dao.dart';

// ignore_for_file: type=lint
mixin _$InboxDaoMixin on DatabaseAccessor<AppDatabase> {
  $NotificationsTable get notifications => attachedDatabase.notifications;
  $MessagesTable get messages => attachedDatabase.messages;
  $TradeProposalsTable get tradeProposals => attachedDatabase.tradeProposals;
  $FriendshipsTable get friendships => attachedDatabase.friendships;
  $UserProfilesTable get userProfiles => attachedDatabase.userProfiles;
  $VaultBindersTable get vaultBinders => attachedDatabase.vaultBinders;
  $VaultItemsTable get vaultItems => attachedDatabase.vaultItems;
  InboxDaoManager get managers => InboxDaoManager(this);
}

class InboxDaoManager {
  final _$InboxDaoMixin _db;
  InboxDaoManager(this._db);
  $$NotificationsTableTableManager get notifications =>
      $$NotificationsTableTableManager(_db.attachedDatabase, _db.notifications);
  $$MessagesTableTableManager get messages =>
      $$MessagesTableTableManager(_db.attachedDatabase, _db.messages);
  $$TradeProposalsTableTableManager get tradeProposals =>
      $$TradeProposalsTableTableManager(
        _db.attachedDatabase,
        _db.tradeProposals,
      );
  $$FriendshipsTableTableManager get friendships =>
      $$FriendshipsTableTableManager(_db.attachedDatabase, _db.friendships);
  $$UserProfilesTableTableManager get userProfiles =>
      $$UserProfilesTableTableManager(_db.attachedDatabase, _db.userProfiles);
  $$VaultBindersTableTableManager get vaultBinders =>
      $$VaultBindersTableTableManager(_db.attachedDatabase, _db.vaultBinders);
  $$VaultItemsTableTableManager get vaultItems =>
      $$VaultItemsTableTableManager(_db.attachedDatabase, _db.vaultItems);
}
