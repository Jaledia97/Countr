import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';

void main() {
  group('Database Schema Migration Tests', () {
    test('auto-patches legacy database missing primary_binder_id column and vault_binders table',
        () async {
      // 1. Initialize an in-memory database with raw legacy schema (no primary_binder_id, no vault_binders)
      final rawDb = NativeDatabase.memory(setup: (raw) {
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
            is_graded, personal_notes, current_market_price, last_price_update, dynamic_data
          ) VALUES (
            'legacy-1', 'mtg', 'Black Lotus', 'Alpha', 'https://example.com/lotus.jpg',
            1000.0, 1600000000, 1, 'NM', 0, NULL, 5000.0, 1600000000, '{}'
          );
        ''');
      });

      // 2. Open via AppDatabase
      final migratedDb = AppDatabase(rawDb);

      // 3. Verify watchBinderItemCounts executes without SqliteException
      final counts = await migratedDb.vaultDao.watchBinderItemCounts().first;
      expect(counts, isEmpty);

      // 4. Verify existing record survived intact
      final legacyItem = await (migratedDb.select(migratedDb.vaultItems)
            ..where((t) => t.id.equals('legacy-1')))
          .getSingle();
      expect(legacyItem.name, 'Black Lotus');
      expect(legacyItem.primaryBinderId, isNull);

      // 5. Verify assigning to a binder works cleanly
      final binder = await migratedDb.vaultDao
          .createBinder(name: 'Vintage Power', collectionType: 'mtg');
      await migratedDb.vaultDao.assignItemsToBinder(['legacy-1'], binder.id);

      final updatedItem = await (migratedDb.select(migratedDb.vaultItems)
            ..where((t) => t.id.equals('legacy-1')))
          .getSingle();
      expect(updatedItem.primaryBinderId, binder.id);

      final updatedCounts =
          await migratedDb.vaultDao.watchBinderItemCounts().first;
      expect(updatedCounts[binder.id], 1);

      await migratedDb.close();
    });

    test('auto-patches database missing flavor_name column and creates idx_vault_items_flavor_name', () async {
      // 1. Initialize a legacy database with schema version 4 (without flavor_name)
      final rawDb = NativeDatabase.memory(setup: (raw) {
        raw.execute('''
          CREATE TABLE vault_binders (
            id TEXT NOT NULL PRIMARY KEY,
            name TEXT NOT NULL,
            collection_type TEXT NOT NULL,
            created_at INTEGER NOT NULL
          );
        ''');
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
            personal_notes TEXT,
            primary_binder_id TEXT,
            current_market_price REAL NOT NULL,
            last_price_update INTEGER NOT NULL,
            dynamic_data TEXT NOT NULL
          );
        ''');
        raw.execute('''
          INSERT INTO vault_items (
            id, collection_type, name, set_or_series, image_url,
            acquired_price, acquired_date, quantity, condition,
            is_graded, is_altered, is_misprint, is_signed, personal_notes,
            primary_binder_id, current_market_price, last_price_update, dynamic_data
          ) VALUES (
            'v4-item-1', 'mtg', 'The Ozolith', 'Ikoria', 'https://example.com/ozolith.jpg',
            10.0, 1600000000, 1, 'NM', 0, 0, 0, 0, NULL, NULL, 15.0, 1600000000, '{}'
          );
        ''');
      });

      // 2. Open via AppDatabase (which triggers beforeOpen and onUpgrade to v5)
      final migratedDb = AppDatabase(rawDb);

      // 3. Verify PRAGMA table_info contains flavor_name
      final tableInfo = await migratedDb.customSelect('PRAGMA table_info("vault_items");').get();
      final columns = tableInfo.map((r) => r.read<String>('name')).toSet();
      expect(columns, contains('flavor_name'));

      // 4. Verify idx_vault_items_flavor_name exists in sqlite_master
      final indexInfo = await migratedDb.customSelect(
        "SELECT name FROM sqlite_master WHERE type='index' AND name='idx_vault_items_flavor_name';",
      ).get();
      expect(indexInfo, isNotEmpty);

      // 5. Verify existing item is readable and has null flavorName
      final item = await (migratedDb.select(migratedDb.vaultItems)
            ..where((t) => t.id.equals('v4-item-1')))
          .getSingle();
      expect(item.name, 'The Ozolith');
      expect(item.flavorName, isNull);

      // 6. Update item with flavor_name and verify retrieval
      await migratedDb.vaultDao.updateItemCardDetails(
        id: 'v4-item-1',
        flavorName: 'Adamantium Bonding Tank',
      );
      final updated = await (migratedDb.select(migratedDb.vaultItems)
            ..where((t) => t.id.equals('v4-item-1')))
          .getSingle();
      expect(updated.flavorName, 'Adamantium Bonding Tank');

      await migratedDb.close();
    });
  });
}
