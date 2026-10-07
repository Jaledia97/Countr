import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/core/database/app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('Drift Schema v10 to v11 Explore Migration Tests', () {
    test('upgrades from schema v10 to v11, creates explore tables and adds columns without data loss', () async {
      // 1. Initialize raw SQLite database simulating schema v10
      final rawDb = NativeDatabase.memory(setup: (raw) {
        raw.execute('PRAGMA user_version = 10;');

        raw.execute('''
          CREATE TABLE "vault_binders" (
            "id" TEXT NOT NULL PRIMARY KEY,
            "name" TEXT NOT NULL,
            "collection_type" TEXT NOT NULL,
            "created_at" INTEGER NOT NULL,
            "is_deleted" INTEGER NOT NULL DEFAULT 0,
            "updated_at" INTEGER
          );
        ''');

        // Decks table as of schema v10 (NO is_cloned, NO source_explore_deck_id)
        raw.execute('''
          CREATE TABLE "decks" (
            "id" TEXT NOT NULL PRIMARY KEY,
            "name" TEXT NOT NULL,
            "format" TEXT NOT NULL,
            "description" TEXT,
            "wins" INTEGER NOT NULL DEFAULT 0,
            "losses" INTEGER NOT NULL DEFAULT 0,
            "draws" INTEGER NOT NULL DEFAULT 0,
            "cover_item_id" TEXT,
            "cover_crop_rect" TEXT,
            "created_at" INTEGER NOT NULL,
            "tcg_domain" TEXT NOT NULL DEFAULT 'mtg',
            "is_registered" INTEGER NOT NULL DEFAULT 0,
            "is_competitive" INTEGER NOT NULL DEFAULT 0,
            "is_assembled" INTEGER NOT NULL DEFAULT 0,
            "is_deleted" INTEGER NOT NULL DEFAULT 0,
            "updated_at" INTEGER
          );
        ''');

        raw.execute('''
          CREATE TABLE "deck_versions" (
            "id" TEXT NOT NULL PRIMARY KEY,
            "deck_id" TEXT NOT NULL,
            "version_number" INTEGER NOT NULL,
            "label" TEXT NOT NULL,
            "is_active" INTEGER NOT NULL DEFAULT 0,
            "created_at" INTEGER NOT NULL,
            "is_deleted" INTEGER NOT NULL DEFAULT 0,
            "updated_at" INTEGER
          );
        ''');

        raw.execute('''
          CREATE TABLE "deck_version_items" (
            "id" TEXT NOT NULL PRIMARY KEY,
            "version_id" TEXT NOT NULL,
            "vault_item_id" TEXT NOT NULL,
            "quantity" INTEGER NOT NULL DEFAULT 1,
            "board_zone" TEXT NOT NULL DEFAULT 'Mainboard',
            "is_proxy" INTEGER NOT NULL DEFAULT 0,
            "is_deleted" INTEGER NOT NULL DEFAULT 0,
            "updated_at" INTEGER
          );
        ''');

        raw.execute('''
          CREATE TABLE "vault_items" (
            "id" TEXT NOT NULL PRIMARY KEY,
            "collection_type" TEXT NOT NULL,
            "name" TEXT NOT NULL,
            "set_or_series" TEXT NOT NULL,
            "image_url" TEXT NOT NULL,
            "acquired_price" REAL NOT NULL,
            "acquired_date" INTEGER NOT NULL,
            "quantity" INTEGER NOT NULL DEFAULT 1,
            "condition" TEXT NOT NULL,
            "current_market_price" REAL NOT NULL,
            "last_price_update" INTEGER NOT NULL,
            "dynamic_data" TEXT,
            "is_deleted" INTEGER NOT NULL DEFAULT 0,
            "updated_at" INTEGER
          );
        ''');

        raw.execute('''
          CREATE TABLE "sync_queue" (
            "id" TEXT NOT NULL PRIMARY KEY,
            "entity_type" TEXT NOT NULL,
            "entity_id" TEXT NOT NULL,
            "operation" TEXT NOT NULL,
            "timestamp" INTEGER NOT NULL,
            "retry_count" INTEGER NOT NULL DEFAULT 0
          );
        ''');

        // Insert legacy deck
        raw.execute('''
          INSERT INTO "decks" (
            "id", "name", "format", "description", "wins", "losses", "draws",
            "cover_item_id", "cover_crop_rect", "created_at", "tcg_domain",
            "is_registered", "is_competitive", "is_assembled", "is_deleted"
          ) VALUES (
            'legacy_deck_1', 'Legacy EDH Deck', 'Commander', 'Old deck notes',
            5, 2, 0, NULL, NULL, 1600000000000, 'mtg', 1, 0, 1, 0
          );
        ''');
      });

      // 2. Open via AppDatabase, triggering v10 -> v11 migration
      final db = AppDatabase(rawDb);

      try {
        // Query user_version
        final versionRow = await db.customSelect('PRAGMA user_version;').getSingle();
        final currentVersion = versionRow.read<int>('user_version');
        expect(currentVersion, equals(11),
            reason: 'Database schemaVersion must be upgraded to 11');

        // Verify decks table has been altered with new columns
        final tableInfo = await db.customSelect("PRAGMA table_info('decks');").get();
        final columnNames = tableInfo.map((row) => row.read<String>('name')).toSet();
        expect(columnNames.contains('is_cloned'), isTrue,
            reason: 'Column is_cloned must exist on decks table');
        expect(columnNames.contains('source_explore_deck_id'), isTrue,
            reason: 'Column source_explore_deck_id must exist on decks table');

        // Verify pre-existing data preserved
        final legacyDeck = await (db.select(db.decks)
              ..where((t) => t.id.equals('legacy_deck_1')))
            .getSingle();
        expect(legacyDeck.name, equals('Legacy EDH Deck'));
        expect(legacyDeck.isCloned, isFalse);
        expect(legacyDeck.sourceExploreDeckId, isNull);

        // Verify explore tables exist and can be written to
        final now = DateTime.now();
        await db.into(db.exploreDecks).insert(
          ExploreDecksCompanion.insert(
            id: 'v11_explore_test_1',
            name: 'V11 Test Explore Deck',
            format: 'Commander',
            createdAt: now,
          ),
        );

        await db.into(db.exploreDeckVotes).insert(
          ExploreDeckVotesCompanion.insert(
            id: 'v11_explore_test_1_user1',
            exploreDeckId: 'v11_explore_test_1',
            vote: const Value(1),
            updatedAt: now,
          ),
        );

        final exploreCount = await db.exploreDeckDao.getExploreDeckCount();
        expect(exploreCount, equals(1));

        final voteRes = await db.exploreDeckDao.castVote(
          deckId: 'v11_explore_test_1',
          targetVote: 1,
          toggle: true,
        );
        // Toggled off to 0
        expect(voteRes.newVote, equals(0));
      } finally {
        await db.close();
      }
    });
  });
}
