// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'friends_dao.dart';

// ignore_for_file: type=lint
mixin _$FriendsDaoMixin on DatabaseAccessor<AppDatabase> {
  $FriendshipsTable get friendships => attachedDatabase.friendships;
  $UserProfilesTable get userProfiles => attachedDatabase.userProfiles;
  $NotificationsTable get notifications => attachedDatabase.notifications;
  FriendsDaoManager get managers => FriendsDaoManager(this);
}

class FriendsDaoManager {
  final _$FriendsDaoMixin _db;
  FriendsDaoManager(this._db);
  $$FriendshipsTableTableManager get friendships =>
      $$FriendshipsTableTableManager(_db.attachedDatabase, _db.friendships);
  $$UserProfilesTableTableManager get userProfiles =>
      $$UserProfilesTableTableManager(_db.attachedDatabase, _db.userProfiles);
  $$NotificationsTableTableManager get notifications =>
      $$NotificationsTableTableManager(_db.attachedDatabase, _db.notifications);
}
