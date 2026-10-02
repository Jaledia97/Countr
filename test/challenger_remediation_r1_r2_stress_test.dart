import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/database/connection/connection.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('Challenger Remediation R1 & R2: Migration & Connection Adversarial Stress Suite', () {
    test('R2.1: Intermediate v6 with partial deck columns (only tcg_domain exists)', () async {
      final rawDb = NativeDatabase.memory(setup: (raw) {
        raw.execute('PRAGMA user_version = 6;');
        raw.execute('''
          CREATE TABLE decks (
            id TEXT NOT NULL PRIMARY KEY,
            name TEXT NOT NULL,
            format TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            wins INTEGER NOT NULL DEFAULT 0,
            losses INTEGER NOT NULL DEFAULT 0,
            draws INTEGER NOT NULL DEFAULT 0,
            is_deleted INTEGER NOT NULL DEFAULT 0,
            tcg_domain TEXT NOT NULL DEFAULT 'mtg'
          );
        ''');
        raw.execute('''
          INSERT INTO decks (id, name, format, created_at, tcg_domain)
          VALUES ('deck-partial-1', 'Legacy Burn', 'Legacy', 1600000000, 'mtg');
        ''');
      });

      final db = AppDatabase(rawDb);

      // Verify PRAGMA table_info contains all 3 columns
      final tableInfo = await db.customSelect('PRAGMA table_info("decks");').get();
      final cols = tableInfo.map((r) => r.read<String>('name')).toSet();
      expect(cols, containsAll(['tcg_domain', 'is_registered', 'is_competitive']));

      final deck = await (db.select(db.decks)..where((t) => t.id.equals('deck-partial-1'))).getSingle();
      expect(deck.name, equals('Legacy Burn'));
      expect(deck.tcgDomain, equals('mtg'));
      expect(deck.isRegistered, isFalse);
      expect(deck.isCompetitive, isFalse);

      await db.close();
    });

    test('R2.2: Intermediate v6 with ALL v7 deck columns already present', () async {
      final rawDb = NativeDatabase.memory(setup: (raw) {
        raw.execute('PRAGMA user_version = 6;');
        raw.execute('''
          CREATE TABLE decks (
            id TEXT NOT NULL PRIMARY KEY,
            name TEXT NOT NULL,
            format TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            wins INTEGER NOT NULL DEFAULT 0,
            losses INTEGER NOT NULL DEFAULT 0,
            draws INTEGER NOT NULL DEFAULT 0,
            is_deleted INTEGER NOT NULL DEFAULT 0,
            tcg_domain TEXT NOT NULL DEFAULT 'pokemon',
            is_registered INTEGER NOT NULL DEFAULT 1,
            is_competitive INTEGER NOT NULL DEFAULT 1
          );
        ''');
        raw.execute('''
          INSERT INTO decks (id, name, format, created_at, tcg_domain, is_registered, is_competitive)
          VALUES ('deck-full-v7', 'Charizard ex', 'Standard', 1700000000, 'pokemon', 1, 1);
        ''');
      });

      final db = AppDatabase(rawDb);

      final deck = await (db.select(db.decks)..where((t) => t.id.equals('deck-full-v7'))).getSingle();
      expect(deck.name, equals('Charizard ex'));
      expect(deck.tcgDomain, equals('pokemon'));
      expect(deck.isRegistered, isTrue);
      expect(deck.isCompetitive, isTrue);

      await db.close();
    });

    test('R2.3: Duplicate column with case-insensitivity in intermediate schema', () async {
      final rawDb = NativeDatabase.memory(setup: (raw) {
        raw.execute('PRAGMA user_version = 6;');
        raw.execute('''
          CREATE TABLE decks (
            id TEXT NOT NULL PRIMARY KEY,
            name TEXT NOT NULL,
            format TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            wins INTEGER NOT NULL DEFAULT 0,
            losses INTEGER NOT NULL DEFAULT 0,
            draws INTEGER NOT NULL DEFAULT 0,
            is_deleted INTEGER NOT NULL DEFAULT 0,
            "TCG_DOMAIN" TEXT NOT NULL DEFAULT 'mtg'
          );
        ''');
      });

      // Opening AppDatabase must not throw unhandled SqliteException on duplicate column
      final db = AppDatabase(rawDb);

      final tableInfo = await db.customSelect('PRAGMA table_info("decks");').get();
      final cols = tableInfo.map((r) => r.read<String>('name').toLowerCase()).toSet();
      expect(cols, contains('tcg_domain'));
      expect(cols, contains('is_registered'));
      expect(cols, contains('is_competitive'));

      await db.close();
    });

    test('R2.4: Intermediate v7 schema with partial v8 vault_items columns and backfill verification', () async {
      final rawDb = NativeDatabase.memory(setup: (raw) {
        raw.execute('PRAGMA user_version = 7;');
        raw.execute('''
          CREATE TABLE vault_items (
            id TEXT NOT NULL PRIMARY KEY,
            collection_type TEXT NOT NULL,
            name TEXT NOT NULL,
            set_or_series TEXT NOT NULL,
            image_url TEXT NOT NULL,
            acquired_price REAL NOT NULL,
            acquired_date INTEGER NOT NULL,
            quantity INTEGER NOT NULL DEFAULT 1,
            condition TEXT NOT NULL,
            is_graded INTEGER NOT NULL DEFAULT 0,
            is_altered INTEGER NOT NULL DEFAULT 0,
            is_misprint INTEGER NOT NULL DEFAULT 0,
            is_signed INTEGER NOT NULL DEFAULT 0,
            flavor_name TEXT,
            personal_notes TEXT,
            primary_binder_id TEXT,
            current_market_price REAL NOT NULL,
            last_price_update INTEGER NOT NULL,
            dynamic_data TEXT NOT NULL,
            date_obtained INTEGER,
            notes TEXT
          );
        ''');
        raw.execute('''
          INSERT INTO vault_items (
            id, collection_type, name, set_or_series, image_url,
            acquired_price, acquired_date, quantity, condition,
            personal_notes, current_market_price, last_price_update, dynamic_data,
            date_obtained, notes
          ) VALUES (
            'v7-partial-item', 'mtg', 'Gaea''s Cradle', 'Urza''s Saga', 'https://example.com/cradle.jpg',
            800.0, 1610000000, 1, 'LP',
            'Pre-existing personal note', 1000.0, 1610000000, '{}',
            1610000000 * 1000, 'Custom already present note'
          );
        ''');
      });

      final db = AppDatabase(rawDb);

      // Verify PRAGMA table_info contains all 6 v8 columns
      final tableInfo = await db.customSelect('PRAGMA table_info("vault_items");').get();
      final cols = tableInfo.map((r) => r.read<String>('name')).toSet();
      expect(cols, containsAll([
        'date_obtained',
        'purchase_price',
        'binder_page',
        'binder_slot',
        'notes',
        'protection_status',
      ]));

      // Verify backfill logic:
      // purchasePrice backfills from acquired_price (since purchase_price was null)
      // notes retains 'Custom already present note' because it was NOT null
      // protectionStatus defaults to 'Sleeved' for quantity > 0
      final item = await (db.select(db.vaultItems)..where((t) => t.id.equals('v7-partial-item'))).getSingle();
      expect(item.name, equals("Gaea's Cradle"));
      expect(item.purchasePrice, equals(800.0));
      expect(item.notes, equals('Custom already present note'));
      expect(item.protectionStatus, equals('Sleeved'));

      await db.close();
    });

    test('R2.5: Missing tables do not crash safeAddColumn or safeBackfill', () async {
      // In this scenario, user_version is 6, but neither decks nor vault_items exist yet
      final rawDb = NativeDatabase.memory(setup: (raw) {
        raw.execute('PRAGMA user_version = 6;');
        raw.execute('''
          CREATE TABLE dummy (
            id TEXT NOT NULL PRIMARY KEY
          );
        ''');
      });

      // AppDatabase should open without crash or unhandled exception
      final db = AppDatabase(rawDb);
      expect(db.schemaVersion, equals(10));

      final dummyCheck = await db.customSelect("SELECT name FROM sqlite_master WHERE type='table' AND name='dummy';").get();
      expect(dummyCheck, isNotEmpty);

      await db.close();
    });

    test('R2.6: Multi-hop migration from v1 all the way to v8', () async {
      final rawDb = NativeDatabase.memory(setup: (raw) {
        raw.execute('PRAGMA user_version = 1;');
        raw.execute('''
          CREATE TABLE vault_items (
            id TEXT NOT NULL PRIMARY KEY,
            collection_type TEXT NOT NULL,
            name TEXT NOT NULL,
            set_or_series TEXT NOT NULL,
            image_url TEXT NOT NULL,
            acquired_price REAL NOT NULL,
            acquired_date INTEGER NOT NULL,
            quantity INTEGER NOT NULL DEFAULT 1,
            condition TEXT NOT NULL,
            is_graded INTEGER NOT NULL DEFAULT 0,
            personal_notes TEXT,
            current_market_price REAL NOT NULL,
            last_price_update INTEGER NOT NULL,
            dynamic_data TEXT NOT NULL
          );
        ''');
        raw.execute('''
          INSERT INTO vault_items (
            id, collection_type, name, set_or_series, image_url,
            acquired_price, acquired_date, quantity, condition,
            personal_notes, current_market_price, last_price_update, dynamic_data
          ) VALUES (
            'v1-card-full-hop', 'mtg', 'Black Lotus', 'Alpha', 'https://example.com/lotus.jpg',
            2000.0, 1600000000, 1, 'NM',
            'Full hop migration note', 50000.0, 1600000000, '{}'
          );
        ''');
      });

      final db = AppDatabase(rawDb);

      final versionResult = await db.customSelect('PRAGMA user_version;').getSingle();
      expect(versionResult.read<int>('user_version'), greaterThanOrEqualTo(8));

      final item = await (db.select(db.vaultItems)..where((t) => t.id.equals('v1-card-full-hop'))).getSingle();
      expect(item.name, equals('Black Lotus'));
      expect(item.notes, equals('Full hop migration note'));
      expect(item.purchasePrice, equals(2000.0));
      expect(item.protectionStatus, equals('Sleeved'));

      await db.close();
    });

    test('R2.7: Repeated migration on already-migrated database is idempotent', () async {
      final tempDir = await Directory.systemTemp.createTemp('countr_idempotent_test_');
      final dbFile = File(p.join(tempDir.path, 'idempotent.sqlite'));

      try {
        final db1 = AppDatabase(NativeDatabase(dbFile));
        // Ensure all tables and seed data created
        final itemsCount1 = (await db1.select(db1.vaultItems).get()).length;
        expect(itemsCount1, greaterThanOrEqualTo(0));
        await db1.close();

        // Re-open with same underlying SQLite file
        final db2 = AppDatabase(NativeDatabase(dbFile));
        final itemsCount2 = (await db2.select(db2.vaultItems).get()).length;
        expect(itemsCount2, equals(itemsCount1));

        // Query table definitions to verify no duplication
        final decksInfo = await db2.customSelect('PRAGMA table_info("decks");').get();
        final deckCols = decksInfo.map((r) => r.read<String>('name')).toList();
        // Ensure column names appear exactly once
        expect(deckCols.toSet().length, equals(deckCols.length));

        final itemsInfo = await db2.customSelect('PRAGMA table_info("vault_items");').get();
        final itemCols = itemsInfo.map((r) => r.read<String>('name')).toList();
        expect(itemCols.toSet().length, equals(itemCols.length));

        await db2.close();
      } finally {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      }
    });

    test('R1.1: Database connection stability under high-concurrency stress', () async {
      final db = AppDatabase(NativeDatabase.memory());

      const numConcurrentTasks = 40;
      final futures = <Future<void>>[];

      for (int i = 0; i < numConcurrentTasks; i++) {
        final id = 'stress-card-$i';
        futures.add(() async {
          await db.into(db.vaultItems).insert(
            VaultItemsCompanion(
              id: drift.Value(id),
              collectionType: const drift.Value('mtg'),
              name: drift.Value('Stress Card $i'),
              setOrSeries: const drift.Value('MH3'),
              imageUrl: const drift.Value('https://example.com/img.jpg'),
              currentMarketPrice: drift.Value(10.0 + i),
              acquiredPrice: drift.Value(5.0 + i),
              acquiredDate: drift.Value(DateTime.now()),
              lastPriceUpdate: drift.Value(DateTime.now()),
              condition: const drift.Value('NM'),
              quantity: const drift.Value(1),
              dynamicData: const drift.Value('{"rarity":"rare"}'),
            ),
          );

          // Perform concurrent read
          final readItem = await (db.select(db.vaultItems)..where((t) => t.id.equals(id))).getSingle();
          expect(readItem.name, equals('Stress Card $i'));

          // Perform concurrent update
          await (db.update(db.vaultItems)..where((t) => t.id.equals(id))).write(
            const VaultItemsCompanion(
              quantity: drift.Value(2),
              notes: drift.Value('Updated under stress'),
            ),
          );
        }());
      }

      await Future.wait(futures);

      final totalItems = await (db.select(db.vaultItems)..where((t) => t.id.like('stress-card-%'))).get();
      expect(totalItems.length, equals(numConcurrentTasks));

      final integrity = await db.customSelect('PRAGMA integrity_check;').getSingle();
      expect(integrity.read<String>('integrity_check'), equals('ok'));

      await db.close();
    });

    test('R1.2: Persistent file database open, close, and re-open integrity', () async {
      final tempDir = await Directory.systemTemp.createTemp('countr_db_test_');
      final dbFile = File(p.join(tempDir.path, 'stress_persist.sqlite'));

      try {
        // Cycle 1: Create and populate
        var db = AppDatabase(NativeDatabase(dbFile));
        await db.into(db.vaultItems).insert(
          VaultItemsCompanion(
            id: const drift.Value('persist-1'),
            collectionType: const drift.Value('mtg'),
            name: const drift.Value('Persistent Mox'),
            setOrSeries: const drift.Value('Vintage'),
            imageUrl: const drift.Value('https://example.com/mox.jpg'),
            currentMarketPrice: const drift.Value(500.0),
            acquiredPrice: const drift.Value(300.0),
            acquiredDate: drift.Value(DateTime.now()),
            lastPriceUpdate: drift.Value(DateTime.now()),
            condition: const drift.Value('NM'),
            quantity: const drift.Value(1),
            dynamicData: const drift.Value('{}'),
          ),
        );
        await db.close();

        // Cycle 2: Reopen and read
        db = AppDatabase(NativeDatabase(dbFile));
        final item = await (db.select(db.vaultItems)..where((t) => t.id.equals('persist-1'))).getSingle();
        expect(item.name, equals('Persistent Mox'));

        final integrity = await db.customSelect('PRAGMA integrity_check;').getSingle();
        expect(integrity.read<String>('integrity_check'), equals('ok'));
        await db.close();

        // Cycle 3: Reopen again and insert another item
        db = AppDatabase(NativeDatabase(dbFile));
        await db.into(db.vaultItems).insert(
          VaultItemsCompanion(
            id: const drift.Value('persist-2'),
            collectionType: const drift.Value('mtg'),
            name: const drift.Value('Persistent Lotus'),
            setOrSeries: const drift.Value('Vintage'),
            imageUrl: const drift.Value('https://example.com/lotus.jpg'),
            currentMarketPrice: const drift.Value(5000.0),
            acquiredPrice: const drift.Value(3000.0),
            acquiredDate: drift.Value(DateTime.now()),
            lastPriceUpdate: drift.Value(DateTime.now()),
            condition: const drift.Value('NM'),
            quantity: const drift.Value(1),
            dynamicData: const drift.Value('{}'),
          ),
        );
        final count = (await (db.select(db.vaultItems)..where((t) => t.id.like('persist-%'))).get()).length;
        expect(count, equals(2));
        await db.close();
      } finally {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      }
    });

    test('R1.3: openConnection returns valid in-memory executor under test environment', () async {
      final executor = openConnection(dbName: 'test_conn');
      final db = AppDatabase(executor);

      final result = await db.customSelect('SELECT 1 + 1 AS sum;').getSingle();
      expect(result.read<int>('sum'), equals(2));

      await db.close();
    });
  });
}
