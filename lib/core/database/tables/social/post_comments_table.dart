import 'package:drift/drift.dart';

@DataClassName('PostCommentRecord')
class PostComments extends Table {
  TextColumn get id => text()();
  TextColumn get postId => text().named('post_id')();
  TextColumn get authorId => text().named('author_id')();
  TextColumn get authorUsername => text().named('author_username')();
  TextColumn get authorDisplayName => text().named('author_display_name')();
  TextColumn get authorAvatarUrl => text().named('author_avatar_url').nullable()();
  TextColumn get content => text()();
  TextColumn get parentCommentId =>
      text().named('parent_comment_id').nullable()();
  DateTimeColumn get createdAt => dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().named('updated_at').withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().named('deleted_at').nullable()();
  BoolColumn get isDeleted => boolean().named('is_deleted').withDefault(const Constant(false))();
  TextColumn get syncStatus => text().named('sync_status').withDefault(const Constant('synced'))();

  @override
  Set<Column> get primaryKey => {id};
}
