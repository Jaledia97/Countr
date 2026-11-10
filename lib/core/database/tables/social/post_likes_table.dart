import 'package:drift/drift.dart';

@DataClassName('PostLikeRecord')
class PostLikes extends Table {
  TextColumn get id => text()();
  TextColumn get postId => text().named('post_id')();
  TextColumn get userId => text().named('user_id')();
  BoolColumn get isLiked => boolean().named('is_liked').withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().named('updated_at').withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().named('deleted_at').nullable()();
  BoolColumn get isDeleted => boolean().named('is_deleted').withDefault(const Constant(false))();
  TextColumn get syncStatus => text().named('sync_status').withDefault(const Constant('synced'))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {postId, userId},
  ];
}
