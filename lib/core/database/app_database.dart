import 'package:drift/drift.dart';
import 'package:countr/core/database/connection/connection.dart';
import 'package:countr/core/database/tables/vault_binders_table.dart';
import 'package:countr/core/database/tables/vault_items_table.dart';
import 'package:countr/core/database/tables/decks/decks_table.dart';
import 'package:countr/core/database/tables/decks/deck_versions_table.dart';
import 'package:countr/core/database/tables/decks/deck_version_items_table.dart';
import 'package:countr/core/database/tables/decks/deck_matchups_table.dart';
import 'package:countr/core/database/tables/decks/deck_synergies_table.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';

part 'app_database.g.dart';

/// Root Drift SQLite Database for Countr.
/// Handles offline persistence, schema migrations, and initial mock seeding.
@DriftDatabase(
  tables: [
    VaultItems,
    VaultBinders,
    Decks,
    DeckVersions,
    DeckVersionItems,
    DeckMatchups,
    DeckSynergies,
  ],
  daos: [VaultDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? openConnection());

  @override
  int get schemaVersion => 6;

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
        if (from < 4) {
          try {
            await m.addColumn(vaultItems, vaultItems.isAltered);
            await m.addColumn(vaultItems, vaultItems.isMisprint);
            await m.addColumn(vaultItems, vaultItems.isSigned);
          } catch (_) {}
        }
        if (from < 5) {
          try {
            await m.addColumn(vaultItems, vaultItems.flavorName);
          } catch (_) {}
        }
        if (from < 6) {
          await m.createTable(decks);
          await m.createTable(deckVersions);
          await m.createTable(deckVersionItems);
          await m.createTable(deckMatchups);
          await m.createTable(deckSynergies);
        }
      },
      beforeOpen: (details) async {
        // High-performance SQLite configuration
        try {
          await customStatement('PRAGMA journal_mode = WAL;');
          await customStatement('PRAGMA synchronous = NORMAL;');
          await customStatement('PRAGMA cache_size = -64000;'); // 64MB page cache
          await customStatement('PRAGMA temp_store = MEMORY;');
        } catch (_) {}

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
          if (!columnNames.contains('is_altered')) {
            await customStatement(
              'ALTER TABLE "vault_items" ADD COLUMN "is_altered" INTEGER NOT NULL DEFAULT 0;',
            );
          }
          if (!columnNames.contains('is_misprint')) {
            await customStatement(
              'ALTER TABLE "vault_items" ADD COLUMN "is_misprint" INTEGER NOT NULL DEFAULT 0;',
            );
          }
          if (!columnNames.contains('is_signed')) {
            await customStatement(
              'ALTER TABLE "vault_items" ADD COLUMN "is_signed" INTEGER NOT NULL DEFAULT 0;',
            );
          }
          if (!columnNames.contains('flavor_name')) {
            await customStatement(
              'ALTER TABLE "vault_items" ADD COLUMN "flavor_name" TEXT;',
            );
          }

          // Backfill flavor_name for legacy records where flavor_name is null or empty
          await customStatement('''
            UPDATE "vault_items"
            SET "flavor_name" = json_extract("dynamic_data", '\$.flavor_name')
            WHERE ("flavor_name" IS NULL OR "flavor_name" = '')
              AND "dynamic_data" LIKE '%"flavor_name"%'
              AND json_extract("dynamic_data", '\$.flavor_name') IS NOT NULL
              AND json_extract("dynamic_data", '\$.flavor_name') != '';
          ''');

          // Backfill current_market_price for legacy cards where it was 0 or null but dynamic_data has prices
          await customStatement('''
            UPDATE "vault_items"
            SET "current_market_price" = CAST(json_extract("dynamic_data", '\$.prices.usd') AS REAL)
            WHERE ("current_market_price" IS NULL OR "current_market_price" <= 0.0)
              AND "dynamic_data" LIKE '%"usd"%'
              AND json_extract("dynamic_data", '\$.prices.usd') IS NOT NULL
              AND json_extract("dynamic_data", '\$.prices.usd') != ''
              AND CAST(json_extract("dynamic_data", '\$.prices.usd') AS REAL) > 0.0;
          ''');
          await customStatement('''
            UPDATE "vault_items"
            SET "current_market_price" = CAST(json_extract("dynamic_data", '\$.prices.usd_foil') AS REAL)
            WHERE ("current_market_price" IS NULL OR "current_market_price" <= 0.0)
              AND "dynamic_data" LIKE '%"usd_foil"%'
              AND json_extract("dynamic_data", '\$.prices.usd_foil') IS NOT NULL
              AND json_extract("dynamic_data", '\$.prices.usd_foil') != ''
              AND CAST(json_extract("dynamic_data", '\$.prices.usd_foil') AS REAL) > 0.0;
          ''');
          await customStatement('''
            UPDATE "vault_items"
            SET "current_market_price" = CAST(json_extract("dynamic_data", '\$.prices.eur') AS REAL)
            WHERE ("current_market_price" IS NULL OR "current_market_price" <= 0.0)
              AND "dynamic_data" LIKE '%"eur"%'
              AND json_extract("dynamic_data", '\$.prices.eur') IS NOT NULL
              AND json_extract("dynamic_data", '\$.prices.eur') != ''
              AND CAST(json_extract("dynamic_data", '\$.prices.eur') AS REAL) > 0.0;
          ''');
        } catch (_) {}

        // Performance compound indexes for instantaneous query and sorting
        try {
          await customStatement('''
            CREATE INDEX IF NOT EXISTS "idx_vault_items_collection_qty"
            ON "vault_items" ("collection_type", "quantity", "acquired_date" DESC);
          ''');
          await customStatement('''
            CREATE INDEX IF NOT EXISTS "idx_vault_items_qty_date"
            ON "vault_items" ("quantity", "acquired_date" DESC);
          ''');
          await customStatement('''
            CREATE INDEX IF NOT EXISTS "idx_vault_items_col_cat"
            ON "vault_items" ("collection_type", "acquired_date" DESC, "name" ASC);
          ''');
          await customStatement('''
            CREATE INDEX IF NOT EXISTS "idx_vault_items_name"
            ON "vault_items" ("name" COLLATE NOCASE);
          ''');
          await customStatement('''
            CREATE INDEX IF NOT EXISTS "idx_vault_items_flavor_name"
            ON "vault_items" ("flavor_name" COLLATE NOCASE);
          ''');
          await customStatement('''
            CREATE INDEX IF NOT EXISTS "idx_vault_items_binder"
            ON "vault_items" ("primary_binder_id");
          ''');
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
