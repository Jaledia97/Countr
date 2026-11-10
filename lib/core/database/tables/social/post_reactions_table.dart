import 'package:drift/drift.dart';

/// Drift Table representing persistent offline and synced emoji reactions on feed posts.
///
/// Tracks emoji reactions (e.g. 🔥, ❤️, 😂, 🤯, 💎) per user/post pair.
@DataClassName('PostReactionRecord')
class PostReactions extends Table {
  /// Unique identifier: 'react_${postId}_${userId}_${emoji}'
  TextColumn get id => text()();

  /// Target post identifier
  TextColumn get postId => text().named('post_id')();

  /// User identifier ('local_user' for offline device persistence or auth user ID)
  TextColumn get userId => text().named('user_id')();

  /// The reacted emoji symbol string (e.g. '🔥', '❤️', '😂', '🤯', '💎')
  TextColumn get emoji => text()();

  /// Timestamp when reaction was added
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();

  /// Soft delete flag for toggling reaction off / synchronization
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
    {postId, userId, emoji},
  ];
}
