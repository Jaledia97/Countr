import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/core/database/app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('M1 Challenger: Migration v15 Adversarial & Idempotency Stress Tests', () {
    test('Migration idempotency: upgrades cleanly when collection_visibility already exists in SQLite table', () async {
      // Setup a raw database at user_version 14 BUT with collection_visibility column pre-existing
      final rawDb = NativeDatabase.memory(setup: (raw) {
        raw.execute('PRAGMA user_version = 14;');

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
            "collection_visibility" TEXT NOT NULL DEFAULT 'private',
            "created_at" INTEGER NOT NULL,
            "updated_at" INTEGER,
            "deleted_at" INTEGER,
            "is_deleted" INTEGER NOT NULL DEFAULT 0
          );
        ''');

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

        raw.execute('''
          INSERT INTO "user_profiles" (
            "id", "username", "display_name", "collection_visibility", "created_at"
          ) VALUES (
            'pre-existing-col-user', '@stealth', 'Stealth Guy', 'private', 1700000000000
          );
        ''');
      });

      // Opening AppDatabase must run onUpgrade from 14 to 15 without throwing "duplicate column" error
      final db = AppDatabase(rawDb);

      final versionResult = await db.customSelect('PRAGMA user_version;').getSingle();
      final currentVersion = versionResult.data['user_version'] as int;
      expect(currentVersion, greaterThanOrEqualTo(15));

      // Verify profile is intact and kept its pre-existing custom 'private' setting
      final profile = await db.userProfileDao.getProfile('pre-existing-col-user');
      expect(profile, isNotNull);
      expect(profile!.collectionVisibility, equals('private'));

      await db.close();
    });

    test('Data preservation across 25 legacy profiles when migrating v14 -> v15', () async {
      const profileCount = 25;

      final rawDb = NativeDatabase.memory(setup: (raw) {
        raw.execute('PRAGMA user_version = 14;');

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

        for (int i = 0; i < profileCount; i++) {
          raw.execute('''
            INSERT INTO "user_profiles" (
              "id", "username", "display_name", "bio", "account_type", "friend_count", "rep_count", "created_at"
            ) VALUES (
              'legacy_user_$i', '@trader_$i', 'Trader $i Display', 'Bio for trader $i', 'individual', $i, ${i * 10}, 1700000000000
            );
          ''');
        }
      });

      final db = AppDatabase(rawDb);

      final versionResult = await db.customSelect('PRAGMA user_version;').getSingle();
      expect(versionResult.data['user_version'], greaterThanOrEqualTo(15));

      // Verify all 25 profiles exist with all fields intact and default 'public' collection_visibility
      for (int i = 0; i < profileCount; i++) {
        final profile = await db.userProfileDao.getProfile('legacy_user_$i');
        expect(profile, isNotNull);
        expect(profile!.username, equals('@trader_$i'));
        expect(profile.displayName, equals('Trader $i Display'));
        expect(profile.bio, equals('Bio for trader $i'));
        expect(profile.friendCount, equals(i));
        expect(profile.repCount, equals(i * 10));
        expect(profile.collectionVisibility, equals('public'));
      }

      await db.close();
    });

    test('Collection visibility transitions (public <-> private) persist reliably in SQLite', () async {
      final db = AppDatabase(NativeDatabase.memory());

      // Create new profile
      await db.userProfileDao.upsertProfile(
        UserProfilesCompanion.insert(
          id: 'user-toggle-test',
          username: '@toggle_trader',
          displayName: 'Toggle Trader',
          createdAt: DateTime.now(),
        ),
      );

      // 1. Initial default is 'public'
      var profile = await db.userProfileDao.getProfile('user-toggle-test');
      expect(profile!.collectionVisibility, equals('public'));

      // 2. Toggle to 'private'
      await db.userProfileDao.updateCollectionVisibility('user-toggle-test', 'private');
      profile = await db.userProfileDao.getProfile('user-toggle-test');
      expect(profile!.collectionVisibility, equals('private'));

      // 3. Toggle back to 'public'
      await db.userProfileDao.updateCollectionVisibility('user-toggle-test', 'public');
      profile = await db.userProfileDao.getProfile('user-toggle-test');
      expect(profile!.collectionVisibility, equals('public'));

      await db.close();
    });
  });
}
