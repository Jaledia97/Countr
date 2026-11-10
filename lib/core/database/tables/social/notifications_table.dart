import 'package:drift/drift.dart';

@DataClassName('NotificationRecord')
class Notifications extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().named('user_id')();
  TextColumn get actorId => text().named('actor_id')();
  TextColumn get actorUsername => text().named('actor_username')();
  TextColumn get actorDisplayName => text().named('actor_display_name').nullable()();
  TextColumn get actorAvatarUrl => text().named('actor_avatar_url').nullable()();
  TextColumn get type => text()(); // 'friend_request', 'trade_proposal', 'post_like', 'post_comment', 'deck_upvote'
  TextColumn get title => text()();
  TextColumn get body => text()();
  TextColumn get targetEntityId => text().named('target_entity_id').nullable()();
  TextColumn get targetEntityType => text().named('target_entity_type').nullable()();
  TextColumn get status => text().withDefault(const Constant('unread'))(); // 'unread', 'read', 'accepted', 'declined'
  BoolColumn get isRead => boolean().named('is_read').withDefault(const Constant(false))();
  BoolColumn get isActioned => boolean().named('is_actioned').withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().named('updated_at').nullable()();
  DateTimeColumn get deletedAt => dateTime().named('deleted_at').nullable()();
  BoolColumn get isDeleted => boolean().named('is_deleted').withDefault(const Constant(false))();
  TextColumn get syncStatus => text().named('sync_status').withDefault(const Constant('synced'))();

  @override
  Set<Column> get primaryKey => {id};
}
