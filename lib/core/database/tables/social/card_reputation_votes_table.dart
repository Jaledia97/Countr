import 'package:drift/drift.dart';

/// Drift Table representing persistent offline and synced user votes on catalog/vault cards.
///
/// Tracks upvote (+1), downvote (-1), or neutral (0) vote states for each user/card pair.
@DataClassName('CardReputationVote')
class CardReputationVotes extends Table {
  /// Unique identifier: '${cardId}_${userId}'
  TextColumn get id => text()();

  /// Identifier of the card (VaultItem.id, scryfall_id, or oracle_id)
  TextColumn get cardId => text().named('card_id')();

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
        {cardId, userId}
      ];
}
