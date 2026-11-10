import 'package:drift/drift.dart';

/// The UserProfiles Schema (v12 / Epic 3)
/// Represents individual collectors, creators, and verified Local Game Store (LGS) profiles.
@DataClassName('UserProfile')
class UserProfiles extends Table {
  /// Unique identifier (e.g. 'user-edh-rec-fanatic', 'store-tbs-comics', 'user-current-me')
  TextColumn get id => text()();

  /// Unique handle (e.g. '@EDH_Rec_Fanatic' or 'EDH_Rec_Fanatic')
  TextColumn get username => text()();

  /// Display name shown across feed, profile, and search
  TextColumn get displayName => text().named('display_name')();

  /// Biography or store tagline
  TextColumn get bio => text().nullable()();

  /// URL to circular avatar picture
  TextColumn get avatarUrl => text().named('avatar_url').nullable()();

  /// URL to profile cover banner
  TextColumn get bannerUrl => text().named('banner_url').nullable()();

  /// 'individual' or 'business'
  TextColumn get accountType =>
      text().named('account_type').withDefault(const Constant('individual'))();

  /// True if verified Local Game Store or business entity
  BoolColumn get isVerifiedBusiness =>
      boolean().named('is_verified_business').withDefault(const Constant(false))();

  /// Physical street address, city, state, zip for LGS
  TextColumn get storeAddress => text().named('store_address').nullable()();

  /// Contact phone number for store
  TextColumn get storePhone => text().named('store_phone').nullable()();

  /// Store website domain
  TextColumn get storeWebsite => text().named('store_website').nullable()();

  /// Total friends count
  IntColumn get friendCount =>
      integer().named('friend_count').withDefault(const Constant(0))();

  /// Community reputation score / vouches
  IntColumn get repCount =>
      integer().named('rep_count').withDefault(const Constant(0))();

  /// Account tier: 'guest', 'free', 'pro', 'business'
  TextColumn get tier =>
      text().withDefault(const Constant('free'))();

  /// Sync status: 'synced', 'pending_create', 'pending_update', 'pending_delete'
  TextColumn get syncStatus =>
      text().named('sync_status').withDefault(const Constant('synced'))();

  /// Creation timestamp
  DateTimeColumn get createdAt => dateTime().named('created_at')();

  /// Last modification timestamp
  DateTimeColumn get updatedAt => dateTime().named('updated_at').nullable()();

  /// Soft delete tombstone timestamp
  DateTimeColumn get deletedAt => dateTime().named('deleted_at').nullable()();

  /// Soft delete flag
  BoolColumn get isDeleted =>
      boolean().named('is_deleted').withDefault(const Constant(false))();

  /// Collection visibility in trade builder and discovery:
  /// 'public' -> Other users can browse full collection and trade binder
  /// 'private' -> Other users are restricted strictly to Trade Binder
  TextColumn get collectionVisibility => text()
      .named('collection_visibility')
      .withDefault(const Constant('public'))();

  @override
  Set<Column> get primaryKey => {id};
}
