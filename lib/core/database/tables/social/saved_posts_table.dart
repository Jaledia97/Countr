import 'package:drift/drift.dart';

/// Drift Table representing user-bookmarked / saved feed posts.
///
/// Tracks posts bookmarked by users via the post header '⋮' menu, viewable
/// from the Command Center saved posts expandable row.
@DataClassName('SavedPostRecord')
class SavedPosts extends Table {
  /// Unique identifier: 'saved_${postId}_${userId}'
  TextColumn get id => text()();

  /// Target post identifier
  TextColumn get postId => text().named('post_id')();

  /// User identifier saving the post
  TextColumn get userId => text().named('user_id')();

  /// Timestamp when post was saved
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();

  /// Soft delete flag for unsaving / synchronization
  BoolColumn get isDeleted =>
      boolean().named('is_deleted').withDefault(const Constant(false))();

  /// Soft delete timestamp
  DateTimeColumn get deletedAt =>
      dateTime().named('deleted_at').nullable()();

  /// Sync engine tracking state ('synced', 'pending', etc.)
  TextColumn get syncStatus =>
      text().named('sync_status').withDefault(const Constant('synced')).nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {postId, userId},
  ];
}
