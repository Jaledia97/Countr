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
  });
}
