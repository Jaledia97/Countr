import 'package:drift/drift.dart';

/// Drift Table representing persistent offline and synced user votes on feed posts.
///
/// Tracks upvote (+1), downvote (-1), or neutral (0) vote states for each user/post pair,
/// replacing legacy single-direction post likes with Reddit-style net score voting.
@DataClassName('PostVoteRecord')
class PostVotes extends Table {
  /// Unique identifier: 'vote_${postId}_${userId}'
  TextColumn get id => text()();

  /// Target post identifier
  TextColumn get postId => text().named('post_id')();

  /// User identifier ('local_user' for offline device persistence or auth user ID)
  TextColumn get userId => text().named('user_id')();

  /// Vote value: 1 = Upvote, -1 = Downvote, 0 = Neutral / Removed
  IntColumn get vote => integer().withDefault(const Constant(0))();

  /// Timestamp when vote was recorded or updated
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();

  /// Timestamp when vote was recorded or updated
  DateTimeColumn get updatedAt =>
      dateTime().named('updated_at').withDefault(currentDateAndTime)();

  /// Soft delete flag for synchronization
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
