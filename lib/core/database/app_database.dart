import 'package:flutter/foundation.dart';
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
  AppDatabase([QueryExecutor? e])
      : super(
          e is DatabaseConnection
              ? e
              : DatabaseConnection(
                  e ?? openConnection(),
                  closeStreamsSynchronously: true,
                ),
        );

  @override
  int get schemaVersion => 8;

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
          } catch (error, stackTrace) {
            debugPrint('[AppDatabase.onUpgrade] Migration to v3 warning: $error\n$stackTrace');
            // Already exists or re-created
          }
        }
        if (from < 4) {
          try {
            await m.addColumn(vaultItems, vaultItems.isAltered);
            await m.addColumn(vaultItems, vaultItems.isMisprint);
            await m.addColumn(vaultItems, vaultItems.isSigned);
          } catch (error, stackTrace) {
            debugPrint('[AppDatabase.onUpgrade] Migration to v4 warning: $error\n$stackTrace');
          }
        }
        if (from < 5) {
          try {
            await m.addColumn(vaultItems, vaultItems.flavorName);
          } catch (error, stackTrace) {
            debugPrint('[AppDatabase.onUpgrade] Migration to v5 warning: $error\n$stackTrace');
          }
        }
        if (from < 6) {
          await m.createTable(decks);
          await m.createTable(deckVersions);
          await m.createTable(deckVersionItems);
          await m.createTable(deckMatchups);
          await m.createTable(deckSynergies);
        }
        if (from < 7) {
          try {
            await m.addColumn(decks, decks.tcgDomain);
            await m.addColumn(decks, decks.isRegistered);
            await m.addColumn(decks, decks.isCompetitive);
          } catch (error, stackTrace) {
            debugPrint('[AppDatabase.onUpgrade] Migration to v7 warning: $error\n$stackTrace');
          }
        }
        if (from < 8) {
          try {
            await m.addColumn(vaultItems, vaultItems.dateObtained);
            await m.addColumn(vaultItems, vaultItems.purchasePrice);
            await m.addColumn(vaultItems, vaultItems.binderPage);
            await m.addColumn(vaultItems, vaultItems.binderSlot);
            await m.addColumn(vaultItems, vaultItems.notes);
            await m.addColumn(vaultItems, vaultItems.protectionStatus);
          } catch (error, stackTrace) {
            debugPrint('[AppDatabase.onUpgrade] Migration to v8 warning: $error\n$stackTrace');
          }
        }
      },
      beforeOpen: (details) async {
        // High-performance SQLite configuration
        try {
          await customStatement('PRAGMA journal_mode = WAL;');
          await customStatement('PRAGMA synchronous = NORMAL;');
          await customStatement('PRAGMA cache_size = -64000;'); // 64MB page cache
          await customStatement('PRAGMA temp_store = MEMORY;');
        } catch (error, stackTrace) {
          debugPrint('[AppDatabase.beforeOpen] PRAGMA configuration warning: $error\n$stackTrace');
        }

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
        } catch (error, stackTrace) {
          debugPrint('[AppDatabase.beforeOpen] vault_binders table creation warning: $error\n$stackTrace');
        }

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
        } catch (error, stackTrace) {
          debugPrint('[AppDatabase.beforeOpen] vault_items schema backfill warning: $error\n$stackTrace');
        }

        // Defensive runtime schema verification for decks table (v7)
        try {
          final decksTableInfo =
              await customSelect('PRAGMA table_info("decks");').get();
          final deckColumnNames =
              decksTableInfo.map((row) => row.read<String>('name')).toSet();
          if (deckColumnNames.isNotEmpty) {
            if (!deckColumnNames.contains('tcg_domain')) {
              await customStatement(
                'ALTER TABLE "decks" ADD COLUMN "tcg_domain" TEXT NOT NULL DEFAULT \'mtg\';',
              );
            }
            if (!deckColumnNames.contains('is_registered')) {
              await customStatement(
                'ALTER TABLE "decks" ADD COLUMN "is_registered" INTEGER NOT NULL DEFAULT 0;',
              );
            }
            if (!deckColumnNames.contains('is_competitive')) {
              await customStatement(
                'ALTER TABLE "decks" ADD COLUMN "is_competitive" INTEGER NOT NULL DEFAULT 0;',
              );
            }
          }
        } catch (error, stackTrace) {
          debugPrint('[AppDatabase.beforeOpen] decks schema verification warning: $error\n$stackTrace');
        }

        // Defensive runtime schema verification for vault_items v8 columns
        try {
          final tableInfo =
              await customSelect('PRAGMA table_info("vault_items");').get();
          final columnNames =
              tableInfo.map((row) => row.read<String>('name')).toSet();

          if (!columnNames.contains('date_obtained')) {
            await customStatement(
              'ALTER TABLE "vault_items" ADD COLUMN "date_obtained" INTEGER;',
            );
          }
          if (!columnNames.contains('purchase_price')) {
            await customStatement(
              'ALTER TABLE "vault_items" ADD COLUMN "purchase_price" REAL;',
            );
          }
          if (!columnNames.contains('binder_page')) {
            await customStatement(
              'ALTER TABLE "vault_items" ADD COLUMN "binder_page" INTEGER;',
            );
          }
          if (!columnNames.contains('binder_slot')) {
            await customStatement(
              'ALTER TABLE "vault_items" ADD COLUMN "binder_slot" TEXT;',
            );
          }
          if (!columnNames.contains('notes')) {
            await customStatement(
              'ALTER TABLE "vault_items" ADD COLUMN "notes" TEXT;',
            );
          }
          if (!columnNames.contains('protection_status')) {
            await customStatement(
              'ALTER TABLE "vault_items" ADD COLUMN "protection_status" TEXT DEFAULT \'Sleeved\';',
            );
          }

          // Safe non-destructive legacy backfill:
          // 1. Copy acquired_date to date_obtained where not already populated
          await customStatement('''
            UPDATE "vault_items"
            SET "date_obtained" = "acquired_date"
            WHERE "date_obtained" IS NULL AND "acquired_date" IS NOT NULL;
          ''');

          // 2. Copy acquired_price to purchase_price where not already populated
          await customStatement('''
            UPDATE "vault_items"
            SET "purchase_price" = "acquired_price"
            WHERE "purchase_price" IS NULL AND "acquired_price" IS NOT NULL;
          ''');

          // 3. Copy personal_notes to notes where not already populated
          await customStatement('''
            UPDATE "vault_items"
            SET "notes" = "personal_notes"
            WHERE "notes" IS NULL AND "personal_notes" IS NOT NULL;
          ''');

          // 4. Default protection_status to 'Sleeved' for null or empty values
          await customStatement('''
            UPDATE "vault_items"
            SET "protection_status" = 'Sleeved'
            WHERE "protection_status" IS NULL OR "protection_status" = '';
          ''');
        } catch (error, stackTrace) {
          debugPrint('[AppDatabase.beforeOpen] vault_items v8 schema verification/backfill warning: $error\n$stackTrace');
        }

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
          await customStatement('''
            CREATE INDEX IF NOT EXISTS "idx_vault_items_protection_status"
            ON "vault_items" ("protection_status");
          ''');
          await customStatement('''
            CREATE INDEX IF NOT EXISTS "idx_vault_items_date_obtained"
            ON "vault_items" ("date_obtained" DESC);
          ''');
        } catch (error, stackTrace) {
          debugPrint('[AppDatabase.beforeOpen] Index creation warning: $error\n$stackTrace');
        }

        try {
          // Automatically seed database on first open if empty
          await vaultDao.seedDatabase();
        } catch (error, stackTrace) {
          debugPrint('[AppDatabase.beforeOpen] Initial database seeding warning: $error\n$stackTrace');
          // Fallback gracefully; seeding can also be triggered manually
        }
      },
    );
  }
}

/// Extended physical provenance and backward-compatibility helpers for [VaultItem].
extension VaultItemX on VaultItem {
  /// Returns [protectionStatus] if specified, defaulting to 'Sleeved'.
  String get effectiveProtectionStatus =>
      (protectionStatus != null && protectionStatus!.isNotEmpty)
          ? protectionStatus!
          : 'Sleeved';

  /// Returns [purchasePrice], falling back to legacy [acquiredPrice].
  double get effectivePurchasePrice => purchasePrice ?? acquiredPrice;

  /// Returns [dateObtained], falling back to legacy [acquiredDate].
  DateTime get effectiveDateObtained => dateObtained ?? acquiredDate;

  /// Returns [notes], falling back to legacy [personalNotes].
  String? get effectiveNotes => notes ?? personalNotes;
}
