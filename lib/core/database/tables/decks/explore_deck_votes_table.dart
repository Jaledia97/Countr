import 'package:drift/drift.dart';
import 'package:countr/core/database/tables/decks/explore_decks_table.dart';

/// Drift Table representing persistent offline user votes on Explore Decks.
///
/// Tracks upvote (+1), downvote (-1), or neutral (0) vote states for the local user.
@DataClassName('ExploreDeckVote')
class ExploreDeckVotes extends Table {
  /// Unique identifier: '${exploreDeckId}_${userId}'
  TextColumn get id => text()();

  /// Foreign key referencing ExploreDecks
  TextColumn get exploreDeckId => text()
      .named('explore_deck_id')
      .references(ExploreDecks, #id, onDelete: KeyAction.cascade)();

  /// User identifier ('local_user' for offline device persistence)
  TextColumn get userId =>
      text().named('user_id').withDefault(const Constant('local_user'))();

  /// Vote value: 1 = Upvote, -1 = Downvote, 0 = Neutral / Removed
  IntColumn get vote => integer().withDefault(const Constant(0))();

  /// Timestamp when vote was recorded or updated
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  /// Soft Delete & Outbox Sync (v12 / Epic 5)
  BoolColumn get isDeleted =>
      boolean().named('is_deleted').withDefault(const Constant(false))();
  DateTimeColumn get deletedAt =>
      dateTime().named('deleted_at').nullable()();
  TextColumn get syncStatus =>
      text().named('sync_status').withDefault(const Constant('synced')).nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {exploreDeckId, userId}
      ];
}
