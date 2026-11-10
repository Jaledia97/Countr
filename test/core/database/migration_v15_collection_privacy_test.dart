import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/core/database/app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('Drift Schema v14 to v15 Collection Privacy Migration Tests', () {
    test('upgrades from schema v14 to v15, adds collection_visibility with default "public" without data loss', () async {
      // 1. Initialize raw SQLite database simulating schema v14
      final rawDb = NativeDatabase.memory(setup: (raw) {
        raw.execute('PRAGMA user_version = 14;');

        // User profiles table as of schema v14 (contains all v14 columns, NO collection_visibility)
        raw.execute('''
          CREATE TABLE "user_profiles" (
            "id" TEXT NOT NULL PRIMARY KEY,
            "username" TEXT NOT NULL,
            "display_name" TEXT NOT NULL,
            "bio" TEXT,
            "avatar_url" TEXT,
            "banner_url" TEXT,
            "account_type" TEXT NOT NULL DEFAULT 'individual',
            "is_verified_business" INTEGER NOT NULL DEFAULT 0,
            "store_address" TEXT,
            "store_phone" TEXT,
            "store_website" TEXT,
            "friend_count" INTEGER NOT NULL DEFAULT 0,
            "rep_count" INTEGER NOT NULL DEFAULT 0,
            "tier" TEXT NOT NULL DEFAULT 'free',
            "sync_status" TEXT NOT NULL DEFAULT 'synced',
            "created_at" INTEGER NOT NULL,
            "updated_at" INTEGER,
            "deleted_at" INTEGER,
            "is_deleted" INTEGER NOT NULL DEFAULT 0
          );
        ''');

        // Vault items table to satisfy VaultDao.seedDatabase during beforeOpen
        raw.execute('''
          CREATE TABLE "vault_items" (
            "id" TEXT NOT NULL PRIMARY KEY,
            "name" TEXT NOT NULL,
            "set_or_series" TEXT NOT NULL,
            "collection_type" TEXT NOT NULL DEFAULT 'mtg',
            "image_url" TEXT NOT NULL DEFAULT '',
            "acquired_price" REAL NOT NULL DEFAULT 0.0,
            "acquired_date" INTEGER NOT NULL DEFAULT 0,
            "quantity" INTEGER NOT NULL DEFAULT 1,
            "condition" TEXT NOT NULL DEFAULT 'Near Mint',
            "current_market_price" REAL NOT NULL DEFAULT 0.0,
            "last_price_update" INTEGER NOT NULL DEFAULT 0,
            "is_deleted" INTEGER NOT NULL DEFAULT 0
          );
        ''');

        // Pre-insert an existing user profile in schema v14
        raw.execute('''
          INSERT INTO "user_profiles" (
            "id", "username", "display_name", "bio", "account_type", "created_at"
          ) VALUES (
            'legacy-user-1', '@legacy_trader', 'Legacy Trader', 'Veteran Magic Collector', 'individual', 1700000000000
          );
        ''');
      });

      // 2. Open AppDatabase on top of the v14 database
      final db = AppDatabase(rawDb);

      // Verify schema version is upgraded to 15 or higher
      final versionResult = await db.customSelect('PRAGMA user_version;').getSingle();
      final currentVersion = versionResult.data['user_version'] as int;
      expect(currentVersion, greaterThanOrEqualTo(15));

      // 3. Verify collection_visibility column was created in table_info
      final tableInfo = await db.customSelect('PRAGMA table_info("user_profiles");').get();
      final columns = tableInfo.map((r) => r.read<String>('name')).toSet();
      expect(columns, contains('collection_visibility'));

      // 4. Verify existing profile data is intact and collection_visibility defaulted to 'public'
      final profile = await db.userProfileDao.getProfile('legacy-user-1');
      expect(profile, isNotNull);
      expect(profile!.id, equals('legacy-user-1'));
      expect(profile.username, equals('@legacy_trader'));
      expect(profile.displayName, equals('Legacy Trader'));
      expect(profile.bio, equals('Veteran Magic Collector'));
      expect(profile.collectionVisibility, equals('public'));

      // 5. Test updating collection visibility to 'private'
      await db.userProfileDao.updateCollectionVisibility('legacy-user-1', 'private');
      final updatedProfile = await db.userProfileDao.getProfile('legacy-user-1');
      expect(updatedProfile!.collectionVisibility, equals('private'));

      // 6. Test inserting a new profile with explicit collection visibility
      await db.userProfileDao.upsertProfile(
        UserProfilesCompanion.insert(
          id: 'new-user-private',
          username: '@stealth_collector',
          displayName: 'Stealth Collector',
          collectionVisibility: const Value('private'),
          createdAt: DateTime.now(),
        ),
      );

      final newProfile = await db.userProfileDao.getProfile('new-user-private');
      expect(newProfile, isNotNull);
      expect(newProfile!.collectionVisibility, equals('private'));

      await db.close();
    });
  });
}
