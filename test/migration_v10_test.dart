import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Drift Schema v10 Migration & Match Persistence Tests', () {
    test('upgrades from schema v9 to v10, creates match tables without data loss', () async {
      // 1. Initialize raw in-memory SQLite database simulating schema v9
      final rawDb = NativeDatabase.memory(setup: (raw) {
        raw.execute('PRAGMA user_version = 9;');

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
            "board_zone" TEXT NOT NULL DEFAULT 'mainboard',
            "is_proxy" INTEGER NOT NULL DEFAULT 0,
            "is_deleted" INTEGER NOT NULL DEFAULT 0,
            "updated_at" INTEGER
          );
        ''');

        raw.execute('''
          CREATE TABLE "deck_matchups" (
            "id" TEXT NOT NULL PRIMARY KEY,
            "deck_id" TEXT NOT NULL,
            "opponent_archetype" TEXT NOT NULL,
            "notes" TEXT NOT NULL,
            "swap_in_item_ids" TEXT NOT NULL,
            "swap_out_item_ids" TEXT NOT NULL,
            "is_deleted" INTEGER NOT NULL DEFAULT 0,
            "updated_at" INTEGER
          );
        ''');

        raw.execute('''
          CREATE TABLE "deck_synergies" (
            "id" TEXT NOT NULL PRIMARY KEY,
            "deck_id" TEXT NOT NULL,
            "card_a_name" TEXT NOT NULL,
            "card_b_name" TEXT NOT NULL,
            "synergy_type" TEXT NOT NULL,
            "score" REAL NOT NULL,
            "description" TEXT NOT NULL,
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

        raw.execute('''
          CREATE TABLE "vault_items" (
            "id" TEXT NOT NULL PRIMARY KEY,
            "collection_type" TEXT NOT NULL,
            "name" TEXT NOT NULL,
            "set_or_series" TEXT NOT NULL,
            "image_url" TEXT NOT NULL,
            "flavor_name" TEXT,
            "acquired_price" REAL NOT NULL,
            "acquired_date" INTEGER NOT NULL,
            "quantity" INTEGER NOT NULL DEFAULT 1,
            "condition" TEXT NOT NULL,
            "is_graded" INTEGER NOT NULL DEFAULT 0,
            "is_altered" INTEGER NOT NULL DEFAULT 0,
            "is_misprint" INTEGER NOT NULL DEFAULT 0,
            "is_signed" INTEGER NOT NULL DEFAULT 0,
            "personal_notes" TEXT,
            "date_obtained" INTEGER,
            "purchase_price" REAL,
            "binder_page" INTEGER,
            "binder_slot" TEXT,
            "notes" TEXT,
            "protection_status" TEXT,
            "primary_binder_id" TEXT,
            "current_market_price" REAL NOT NULL,
            "last_price_update" INTEGER NOT NULL,
            "dynamic_data" TEXT NOT NULL DEFAULT '{}',
            "is_deleted" INTEGER NOT NULL DEFAULT 0,
            "updated_at" INTEGER
          );
        ''');

        // Insert legacy data before migration
        raw.execute('''
          INSERT INTO "vault_items" (
            id, collection_type, name, set_or_series, image_url,
            acquired_price, acquired_date, quantity, condition,
            current_market_price, last_price_update, dynamic_data, is_deleted
          ) VALUES (
            'legacy-atraxa', 'mtg', 'Atraxa, Praetors'' Voice', 'Commander 2016', 'https://img.scryfall.com/atraxa.jpg',
            25.0, 1600000000, 1, 'NM',
            35.0, 1600000000, '{"image_uris":{"art_crop":"https://img.scryfall.com/atraxa_art.jpg"}}', 0
          );
        ''');

        raw.execute('''
          INSERT INTO "decks" (
            id, name, format, created_at, is_registered, is_competitive, is_assembled, is_deleted
          ) VALUES (
            'deck-atraxa-superfriends', 'Atraxa Superfriends', 'Commander', 1600000000, 1, 1, 1, 0
          );
        ''');
      });

      // 2. Open AppDatabase triggering onUpgrade from 9 to 10
      final db = AppDatabase(rawDb);

      // Verify schema version is at least 10
      expect(db.schemaVersion, greaterThanOrEqualTo(10));

      // Verify legacy v9 items are intact and readable
      final legacyCard = await db.vaultDao.getItemById('legacy-atraxa');
      expect(legacyCard, isNotNull);
      expect(legacyCard!.name, equals('Atraxa, Praetors\' Voice'));
      expect(legacyCard.isDeleted, isFalse);

      final legacyDecks = await db.vaultDao.watchAllDecks().first;
      expect(legacyDecks.any((d) => d.id == 'deck-atraxa-superfriends'), isTrue);

      // 3. Verify match_sessions, match_players, and match_events tables exist in sqlite_master
      final tables = await db.customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('match_sessions', 'match_players', 'match_events');",
      ).get();
      final tableNames = tables.map((r) => r.read<String>('name')).toSet();
      expect(tableNames, contains('match_sessions'));
      expect(tableNames, contains('match_players'));
      expect(tableNames, contains('match_events'));

      // 4. Verify compound indexes exist
      final indexes = await db.customSelect(
        "SELECT name FROM sqlite_master WHERE type='index' AND name LIKE 'idx_match_%';",
      ).get();
      final indexNames = indexes.map((r) => r.read<String>('name')).toSet();
      expect(indexNames, contains('idx_match_sessions_status'));
      expect(indexNames, contains('idx_match_players_session'));
      expect(indexNames, contains('idx_match_events_session_seq'));
      expect(indexNames, contains('idx_match_events_player'));

      await db.close();
    });

    test('verifies match table CRUD, relational constraints, and event sequence', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // 1. Insert Match Session
      await db.customStatement('''
        INSERT INTO "match_sessions" (
          id, name, format, starting_life, player_count, status, created_at, is_p2p_host, p2p_session_code, is_deleted
        ) VALUES (
          'session-m1-001', 'Friday Commander Pod', 'Commander', 40, 4, 'active', $now, 1, 'CMD42', 0
        );
      ''');

      // 2. Insert 4 Match Players
      for (int i = 0; i < 4; i++) {
        final playerId = 'player-$i';
        final seat = i;
        final name = 'Player ${i + 1}';
        await db.customStatement('''
          INSERT INTO "match_players" (
            id, session_id, seat_order, player_name, current_life, poison, energy, experience, commander_tax, is_monarch, has_initiative, is_eliminated, is_local_device, is_deleted
          ) VALUES (
            '$playerId', 'session-m1-001', $seat, '$name', 40, 0, 0, 0, 0, 0, 0, 0, 1, 0
          );
        ''');
      }

      // 3. Insert Events: Life Delta & Commander Damage
      await db.customStatement('''
        INSERT INTO "match_events" (
          id, session_id, player_id, source_player_id, event_type, delta, value, sequence_number, timestamp, is_undone, is_deleted
        ) VALUES (
          'event-001', 'session-m1-001', 'player-0', 'player-1', 'commander_damage', -3, 3, 1, $now, 0, 0
        );
      ''');

      await db.customStatement('''
        INSERT INTO "match_events" (
          id, session_id, player_id, event_type, delta, value, sequence_number, timestamp, is_undone, is_deleted
        ) VALUES (
          'event-002', 'session-m1-001', 'player-0', 'poison', 1, 1, 2, $now, 0, 0
        );
      ''');

      // 4. Update denormalized player life & poison
      await db.customStatement('''
        UPDATE "match_players" SET current_life = 37, poison = 1 WHERE id = 'player-0';
      ''');

      // 5. Query and verify session state
      final sessionRow = await db.customSelect(
        "SELECT * FROM match_sessions WHERE id = 'session-m1-001' AND is_deleted = 0;",
      ).getSingle();
      expect(sessionRow.read<String>('name'), equals('Friday Commander Pod'));
      expect(sessionRow.read<int>('starting_life'), equals(40));
      expect(sessionRow.read<int>('player_count'), equals(4));
      expect(sessionRow.read<String>('p2p_session_code'), equals('CMD42'));

      // 6. Query players in seat order
      final playerRows = await db.customSelect(
        "SELECT * FROM match_players WHERE session_id = 'session-m1-001' AND is_deleted = 0 ORDER BY seat_order ASC;",
      ).get();
      expect(playerRows.length, equals(4));
      expect(playerRows[0].read<String>('player_name'), equals('Player 1'));
      expect(playerRows[0].read<int>('current_life'), equals(37));
      expect(playerRows[0].read<int>('poison'), equals(1));
      expect(playerRows[1].read<int>('current_life'), equals(40));

      // 7. Query events in monotonic sequence order
      final eventRows = await db.customSelect(
        "SELECT * FROM match_events WHERE session_id = 'session-m1-001' AND is_deleted = 0 ORDER BY sequence_number ASC;",
      ).get();
      expect(eventRows.length, equals(2));
      expect(eventRows[0].read<String>('event_type'), equals('commander_damage'));
      expect(eventRows[0].read<String?>('source_player_id'), equals('player-1'));
      expect(eventRows[0].read<int>('delta'), equals(-3));
      expect(eventRows[1].read<String>('event_type'), equals('poison'));
      expect(eventRows[1].read<int>('sequence_number'), equals(2));

      await db.close();
    });

    test('verifies soft delete on match sessions preserves history in SQLite', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await db.customStatement('''
        INSERT INTO "match_sessions" (
          id, name, format, starting_life, player_count, status, created_at, is_deleted
        ) VALUES (
          'session-del-1', 'Match to delete', 'Commander', 40, 2, 'active', $now, 0
        );
      ''');

      // Soft delete
      await db.customStatement('''
        UPDATE "match_sessions" SET is_deleted = 1, updated_at = $now WHERE id = 'session-del-1';
      ''');

      // Filtered from active query
      final active = await db.customSelect(
        "SELECT * FROM match_sessions WHERE id = 'session-del-1' AND is_deleted = 0;",
      ).get();
      expect(active, isEmpty);

      // Still exists physically in SQLite
      final raw = await db.customSelect(
        "SELECT is_deleted, updated_at FROM match_sessions WHERE id = 'session-del-1';",
      ).getSingle();
      expect(raw.read<int>('is_deleted'), equals(1));
      expect(raw.read<int?>('updated_at'), isNotNull);

      await db.close();
    });

    test('beforeOpen defensively creates missing match tables if database was drifted', () async {
      // Simulates database where user_version = 10 but tables are missing
      final driftedDb = NativeDatabase.memory(setup: (raw) {
        raw.execute('PRAGMA user_version = 10;');
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
            "is_graded" INTEGER NOT NULL DEFAULT 0,
            "is_altered" INTEGER NOT NULL DEFAULT 0,
            "is_misprint" INTEGER NOT NULL DEFAULT 0,
            "is_signed" INTEGER NOT NULL DEFAULT 0,
            "current_market_price" REAL NOT NULL,
            "last_price_update" INTEGER NOT NULL,
            "dynamic_data" TEXT NOT NULL DEFAULT '{}',
            "is_deleted" INTEGER NOT NULL DEFAULT 0
          );
        ''');
      });

      // Opening AppDatabase must execute beforeOpen defensive creation without throwing
      final db = AppDatabase(driftedDb);
      expect(db.schemaVersion, greaterThanOrEqualTo(10));

      // Assert tables now exist
      final tables = await db.customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('match_sessions', 'match_players', 'match_events');",
      ).get();
      final names = tables.map((r) => r.read<String>('name')).toSet();
      expect(names, contains('match_sessions'));
      expect(names, contains('match_players'));
      expect(names, contains('match_events'));

      await db.close();
    });
  });
}
