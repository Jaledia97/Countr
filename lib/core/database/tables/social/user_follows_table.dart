import 'package:drift/drift.dart';

@DataClassName('UserFollow')
class UserFollows extends Table {
  TextColumn get id => text()(); // '${followerId}_${targetUserId}'
  TextColumn get followerId => text().named('follower_id')();
  TextColumn get targetUserId => text().named('target_user_id')();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();
  BoolColumn get isDeleted =>
      boolean().named('is_deleted').withDefault(const Constant(false))();
  DateTimeColumn get deletedAt => dateTime().named('deleted_at').nullable()();
  TextColumn get syncStatus =>
      text().named('sync_status').withDefault(const Constant('synced')).nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {followerId, targetUserId}
      ];
}
