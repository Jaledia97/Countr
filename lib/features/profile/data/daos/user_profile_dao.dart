import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/tables/user_profiles_table.dart';

part 'user_profile_dao.g.dart';

@DriftAccessor(tables: [UserProfiles])
class UserProfileDao extends DatabaseAccessor<AppDatabase>
    with _$UserProfileDaoMixin {
  UserProfileDao(super.db);

  /// Streams a user profile by ID or username.
  Stream<UserProfile?> watchProfile(String profileId) {
    final cleanUsername = profileId.startsWith('@') ? profileId : '@$profileId';
    return (select(userProfiles)
          ..where((t) =>
              t.id.equals(profileId) |
              t.username.equals(cleanUsername) |
              t.username.equals(profileId)))
        .watchSingleOrNull();
  }

  /// Fetches a user profile by ID or username.
  Future<UserProfile?> getProfile(String profileId) {
    final cleanUsername = profileId.startsWith('@') ? profileId : '@$profileId';
    return (select(userProfiles)
          ..where((t) =>
              t.id.equals(profileId) |
              t.username.equals(cleanUsername) |
              t.username.equals(profileId)))
        .getSingleOrNull();
  }

  /// Fetches a profile by exact username (case-insensitive).
  Future<UserProfile?> getProfileByUsername(String username) {
    final cleanUsername = username.startsWith('@') ? username : '@$username';
    return (select(userProfiles)
          ..where((t) =>
              t.username.equals(cleanUsername) |
              t.username.equals(cleanUsername.substring(1))))
        .getSingleOrNull();
  }

  /// Upserts a user profile into SQLite.
  Future<void> upsertProfile(UserProfilesCompanion companion) async {
    await into(userProfiles).insertOnConflictUpdate(companion);
  }

  /// Updates user collection visibility ('public' or 'private').
  Future<void> updateCollectionVisibility(String userId, String visibility) async {
    final now = DateTime.now();
    await (update(userProfiles)..where((t) => t.id.equals(userId))).write(
      UserProfilesCompanion(
        collectionVisibility: Value(visibility),
        updatedAt: Value(now),
        syncStatus: const Value('pending_update'),
      ),
    );
  }

  /// Updates a user profile avatarUrl.
  Future<void> updateAvatar(String userId, String avatarUrl) async {
    final now = DateTime.now();
    await (update(userProfiles)..where((t) => t.id.equals(userId))).write(
      UserProfilesCompanion(
        avatarUrl: Value(avatarUrl),
        updatedAt: Value(now),
      ),
    );
  }

  /// Updates business verification details for an LGS.
  Future<void> updateBusinessVerification(
    String userId, {
    required String storeName,
    required String storeAddress,
    required String storePhone,
    required String storeWebsite,
  }) async {
    final now = DateTime.now();
    await (update(userProfiles)..where((t) => t.id.equals(userId))).write(
      UserProfilesCompanion(
        displayName: Value(storeName),
        accountType: const Value('business'),
        isVerifiedBusiness: const Value(true),
        storeAddress: Value(storeAddress),
        storePhone: Value(storePhone),
        storeWebsite: Value(storeWebsite),
        tier: const Value('business'),
        updatedAt: Value(now),
        syncStatus: const Value('pending_update'),
      ),
    );
  }

  /// Searches profiles by username or display name.
  Future<List<UserProfile>> searchProfiles(String query, {int limit = 20}) {
    final cleanQuery = query.trim().replaceAll('@', '');
    if (cleanQuery.isEmpty) return Future.value([]);

    return (select(userProfiles)
          ..where((t) =>
              t.isDeleted.equals(false) &
              (t.username.like('%$cleanQuery%') |
                  t.displayName.like('%$cleanQuery%')))
          ..limit(limit))
        .get();
  }

  /// Seeds default unified profiles for social feeds, explore, and trade discovery.
  Future<void> seedDefaultProfiles() async {
    final now = DateTime.now();

    final profiles = [
      UserProfilesCompanion.insert(
        id: 'user-edh-rec-fanatic',
        username: '@EDH_Rec_Fanatic',
        displayName: 'EDH Rec Fanatic',
        bio: const Value('Commander theorycrafter and combo optimizer.'),
        avatarUrl: const Value('https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400&auto=format&fit=crop&q=80'),
        bannerUrl: const Value('https://images.unsplash.com/photo-1511512578047-dfb367046420?w=600'),
        accountType: const Value('individual'),
        isVerifiedBusiness: const Value(false),
        friendCount: const Value(42),
        repCount: const Value(128),
        tier: const Value('pro'),
        createdAt: now,
        updatedAt: Value(now),
      ),
      UserProfilesCompanion.insert(
        id: 'user-spicy-brew-master',
        username: '@SpicyBrewMaster',
        displayName: 'Spicy Brew Master',
        bio: const Value('Turning jank into gold since 2014. Pauper and Modern rogue deck specialist.'),
        avatarUrl: const Value('https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&auto=format&fit=crop&q=80'),
        bannerUrl: const Value('https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=600'),
        accountType: const Value('individual'),
        isVerifiedBusiness: const Value(false),
        friendCount: const Value(88),
        repCount: const Value(256),
        tier: const Value('free'),
        createdAt: now,
        updatedAt: Value(now),
      ),
      UserProfilesCompanion.insert(
        id: 'user-foil-collector-99',
        username: '@FoilCollector99',
        displayName: 'Foil Collector 99',
        bio: const Value('Masterpieces, Serialized, and Old Border Foils. Always open for trades!'),
        avatarUrl: const Value('https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400&auto=format&fit=crop&q=80'),
        bannerUrl: const Value('https://images.unsplash.com/photo-1579783900882-c0d3dad7b119?w=600'),
        accountType: const Value('individual'),
        isVerifiedBusiness: const Value(false),
        friendCount: const Value(19),
        repCount: const Value(95),
        tier: const Value('free'),
        createdAt: now,
        updatedAt: Value(now),
      ),
      UserProfilesCompanion.insert(
        id: 'store-tbs-comics',
        username: '@TBSComics',
        displayName: 'TBS Comics - Fort Walton Beach',
        bio: const Value('Northwest Florida\'s Premier Comic & Gaming Destination. Singles, tournaments, and buylists.'),
        avatarUrl: const Value('https://images.unsplash.com/photo-1568602471122-7832951cc4c5?w=400&auto=format&fit=crop&q=80'),
        bannerUrl: const Value('https://images.unsplash.com/photo-1607604276583-eef5d076aa5f?w=600'),
        accountType: const Value('business'),
        isVerifiedBusiness: const Value(true),
        storeAddress: const Value('68 SW Eglin Pkwy, Fort Walton Beach, FL 32548'),
        storePhone: const Value('(850) 244-4445'),
        storeWebsite: const Value('https://tbscomics.com'),
        friendCount: const Value(310),
        repCount: const Value(512),
        tier: const Value('business'),
        createdAt: now,
        updatedAt: Value(now),
      ),
      UserProfilesCompanion.insert(
        id: 'user-current-me',
        username: '@collector_me',
        displayName: 'Current Collector',
        bio: const Value('TCG Enthusiast, deckbuilder, and binder organizer.'),
        avatarUrl: const Value('https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=400&auto=format&fit=crop&q=80'),
        bannerUrl: const Value(null),
        accountType: const Value('individual'),
        isVerifiedBusiness: const Value(false),
        friendCount: const Value(12),
        repCount: const Value(34),
        tier: const Value('free'),
        createdAt: now,
        updatedAt: Value(now),
      ),
    ];

    for (final profile in profiles) {
      await into(userProfiles).insert(
        profile,
        mode: InsertMode.insertOrIgnore,
      );
    }

    try {
      await db.vaultDao.seedSystemBindersForUser('user-edh-rec-fanatic', isBusiness: false);
      await db.vaultDao.seedSystemBindersForUser('store-tbs-comics', isBusiness: true);

      // Seed sample trade block cards for EDH Rec Fanatic
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'item-edh-rhystic-study',
          collectionType: 'mtg',
          primaryBinderId: const Value('system_trade_block_user-edh-rec-fanatic'),
          userId: const Value('user-edh-rec-fanatic'),
          name: 'Rhystic Study',
          setOrSeries: 'Prophecy',
          imageUrl:
              'https://cards.scryfall.io/large/front/9/2/92271c74-2e32-441a-802e-277a5de1dd73.jpg',
          acquiredPrice: 35.00,
          currentMarketPrice: 38.50,
          lastPriceUpdate: now,
          dynamicData: '{}',
          acquiredDate: now,
          quantity: const Value(1),
          condition: 'NM',
          isGraded: const Value(false),
          isDeleted: const Value(false),
          updatedAt: Value(now),
        ),
        mode: InsertMode.insertOrIgnore,
      );

      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'item-edh-cyclonic-rift',
          collectionType: 'mtg',
          primaryBinderId: const Value('system_trade_block_user-edh-rec-fanatic'),
          userId: const Value('user-edh-rec-fanatic'),
          name: 'Cyclonic Rift',
          setOrSeries: 'Return to Ravnica',
          imageUrl:
              'https://cards.scryfall.io/large/front/f/f/ff08e5ed-f07b-4591-9b89-42cc25472382.jpg',
          acquiredPrice: 32.00,
          currentMarketPrice: 35.00,
          lastPriceUpdate: now,
          dynamicData: '{}',
          acquiredDate: now,
          quantity: const Value(1),
          condition: 'NM',
          isGraded: const Value(false),
          isDeleted: const Value(false),
          updatedAt: Value(now),
        ),
        mode: InsertMode.insertOrIgnore,
      );

      // Seed sample store inventory for TBS Comics
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'item-tbs-mox-diamond',
          collectionType: 'mtg',
          primaryBinderId: const Value('system_store_inventory_store-tbs-comics'),
          userId: const Value('store-tbs-comics'),
          name: 'Mox Diamond',
          setOrSeries: 'Stronghold',
          imageUrl:
              'https://cards.scryfall.io/large/front/b/f/bf9fec14-d217-4343-b45f-740791fcbfe6.jpg',
          acquiredPrice: 620.00,
          currentMarketPrice: 650.00,
          lastPriceUpdate: now,
          dynamicData: '{}',
          acquiredDate: now,
          quantity: const Value(1),
          condition: 'LP',
          isGraded: const Value(false),
          isDeleted: const Value(false),
          updatedAt: Value(now),
        ),
        mode: InsertMode.insertOrIgnore,
      );
    } catch (_) {}
  }
}
