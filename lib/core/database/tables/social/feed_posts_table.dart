import 'package:drift/drift.dart';

@DataClassName('FeedPostRecord')
class FeedPosts extends Table {
  TextColumn get id => text()();
  TextColumn get authorId => text().named('author_id')();
  TextColumn get authorUsername => text().named('author_username')();
  TextColumn get authorDisplayName => text().named('author_display_name')();
  TextColumn get authorAvatarUrl => text().named('author_avatar_url').nullable()();
  TextColumn get sharedByUserId => text().named('shared_by_user_id').nullable()();
  TextColumn get type => text()(); // 'text', 'single_pull', 'multi_pull', 'deck_share'
  TextColumn get textContent => text().named('text_content').nullable()();
  TextColumn get locationTag => text().named('location_tag').nullable()();
  TextColumn get cardId => text().named('card_id').nullable()();
  TextColumn get cardTitle => text().named('card_title').nullable()();
  TextColumn get cardSubtitle => text().named('card_subtitle').nullable()();
  TextColumn get cardRarity => text().named('card_rarity').nullable()();
  RealColumn get estimatedValue => real().named('estimated_value').nullable()();
  TextColumn get cardImageUrl => text().named('card_image_url').nullable()();
  TextColumn get pullImagesJson => text().named('pull_images_json').nullable()();
  TextColumn get pullCardIdsJson => text().named('pull_card_ids_json').nullable()();
  IntColumn get likeCount => integer().named('like_count').withDefault(const Constant(0))();
  IntColumn get commentCount => integer().named('comment_count').withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().named('created_at').withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().named('updated_at').withDefault(currentDateAndTime)();
  DateTimeColumn get deletedAt => dateTime().named('deleted_at').nullable()();
  BoolColumn get isDeleted => boolean().named('is_deleted').withDefault(const Constant(false))();
  TextColumn get syncStatus => text().named('sync_status').withDefault(const Constant('synced'))();

  @override
  Set<Column> get primaryKey => {id};
}
