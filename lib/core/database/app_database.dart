import 'package:drift/drift.dart';
import 'package:countr/core/database/connection/connection.dart';
import 'package:countr/core/database/tables/vault_binders_table.dart';
import 'package:countr/core/database/tables/vault_items_table.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';

part 'app_database.g.dart';

/// Root Drift SQLite Database for Countr.
/// Handles offline persistence, schema migrations, and initial mock seeding.
@DriftDatabase(tables: [VaultItems, VaultBinders], daos: [VaultDao])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? openConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
      },
      onUpgrade: (m, from, to) async {
        if (from < 2) {
          await m.createTable(vaultBinders);
        }
        if (from < 3) {
          try {
            await m.addColumn(vaultItems, vaultItems.primaryBinderId);
          } catch (_) {
            // Already exists or re-created
          }
        }
      },
      beforeOpen: (details) async {
        // Defensive runtime schema verification:
        // Automatically patch legacy local SQLite databases where schema version may have
        // drifted without primary_binder_id or vault_binders table.
        try {
          await customStatement('''
            CREATE TABLE IF NOT EXISTS "vault_binders" (
              "id" TEXT NOT NULL PRIMARY KEY,
              "name" TEXT NOT NULL,
              "collection_type" TEXT NOT NULL,
              "created_at" INTEGER NOT NULL
            );
          ''');
        } catch (_) {}

        try {
          final tableInfo =
              await customSelect('PRAGMA table_info("vault_items");').get();
          final columnNames =
              tableInfo.map((row) => row.read<String>('name')).toSet();
          if (!columnNames.contains('primary_binder_id')) {
            await customStatement(
              'ALTER TABLE "vault_items" ADD COLUMN "primary_binder_id" TEXT REFERENCES "vault_binders" ("id");',
            );
          }
        } catch (_) {}

        try {
          // Automatically seed database on first open if empty
          await vaultDao.seedDatabase();
        } catch (_) {
          // Fallback gracefully; seeding can also be triggered manually
        }
      },
    );
  }
}
