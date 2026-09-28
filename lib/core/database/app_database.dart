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
import 'package:countr/core/database/tables/sync_queue_table.dart';
import 'package:countr/core/database/tables/matches/match_sessions_table.dart';
import 'package:countr/core/database/tables/matches/match_players_table.dart';
import 'package:countr/core/database/tables/matches/match_events_table.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/life_counter/data/daos/match_dao.dart';

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
    SyncQueue,
    MatchSessions,
    MatchPlayers,
    MatchEvents,
  ],
  daos: [VaultDao, MatchDao],
)
QueryExecutor _resolveConnection(QueryExecutor? e) {
  if (e != null) {
    if (e is DatabaseConnection) return e;
    return DatabaseConnection(e, closeStreamsSynchronously: true);
  }
  final conn = openConnection();
  if (conn is DatabaseConnection) return conn;
  return DatabaseConnection(conn, closeStreamsSynchronously: true);
}

class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(_resolveConnection(e));

  @override
  int get schemaVersion => 10;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
      },
      onUpgrade: (m, from, to) async {
        if (from < 2) {
          try {
            await m.createTable(vaultBinders);
          } catch (error, stackTrace) {
            debugPrint('[AppDatabase.onUpgrade] Migration to v2 warning: $error\n$stackTrace');
          }
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
          try {
            await m.createTable(decks);
          } catch (_) {}
          try {
            await m.createTable(deckVersions);
          } catch (_) {}
          try {
            await m.createTable(deckVersionItems);
          } catch (_) {}
          try {
            await m.createTable(deckMatchups);
          } catch (_) {}
          try {
            await m.createTable(deckSynergies);
          } catch (_) {}
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

            // Safe non-destructive legacy backfill during migration:
            await customStatement('''
              UPDATE "vault_items"
              SET "date_obtained" = "acquired_date"
              WHERE "date_obtained" IS NULL AND "acquired_date" IS NOT NULL AND "quantity" > 0;
            ''');
            await customStatement('''
              UPDATE "vault_items"
              SET "purchase_price" = "acquired_price"
              WHERE "purchase_price" IS NULL AND "acquired_price" IS NOT NULL AND "quantity" > 0;
            ''');
            await customStatement('''
              UPDATE "vault_items"
              SET "notes" = "personal_notes"
              WHERE "notes" IS NULL AND "personal_notes" IS NOT NULL AND "quantity" > 0;
            ''');
            await customStatement('''
              UPDATE "vault_items"
              SET "protection_status" = 'Sleeved'
              WHERE ("protection_status" IS NULL OR "protection_status" = '') AND "quantity" > 0;
            ''');
          } catch (error, stackTrace) {
            debugPrint('[AppDatabase.onUpgrade] Migration to v8 warning: $error\n$stackTrace');
          }
        }
        if (from < 9) {
          try {
            await m.createTable(syncQueue);
          } catch (error, stackTrace) {
            debugPrint('[AppDatabase.onUpgrade] Migration to v9 (syncQueue) warning: $error\n$stackTrace');
          }

          Future<void> addSoftDeleteCols(TableInfo table, GeneratedColumn isDeletedCol, GeneratedColumn updatedAtCol) async {
            try {
              final tableCheck = await customSelect(
                "SELECT name FROM sqlite_master WHERE type='table' AND name=?;",
                variables: [Variable.withString(table.actualTableName)],
              ).get();
              if (tableCheck.isEmpty) return;

              try {
                await m.addColumn(table, isDeletedCol);
              } catch (_) {}
              try {
                await m.addColumn(table, updatedAtCol);
              } catch (_) {}
            } catch (error, stackTrace) {
              debugPrint('[AppDatabase.onUpgrade] Migration to v9 ($table) warning: $error\n$stackTrace');
            }
          }

          await addSoftDeleteCols(vaultItems, vaultItems.isDeleted, vaultItems.updatedAt);
          await addSoftDeleteCols(vaultBinders, vaultBinders.isDeleted, vaultBinders.updatedAt);
          await addSoftDeleteCols(decks, decks.isDeleted, decks.updatedAt);
          await addSoftDeleteCols(deckVersions, deckVersions.isDeleted, deckVersions.updatedAt);
          await addSoftDeleteCols(deckVersionItems, deckVersionItems.isDeleted, deckVersionItems.updatedAt);
          await addSoftDeleteCols(deckMatchups, deckMatchups.isDeleted, deckMatchups.updatedAt);
          await addSoftDeleteCols(deckSynergies, deckSynergies.isDeleted, deckSynergies.updatedAt);
        }

        if (from < 10) {
          try {
            await m.createTable(matchSessions);
            await m.createTable(matchPlayers);
            await m.createTable(matchEvents);
          } catch (error, stackTrace) {
            debugPrint('[AppDatabase.onUpgrade] Migration to v10 warning: $error\n$stackTrace');
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

        // Defensive runtime schema verification for v9:
        // Ensure sync_queue table exists
        try {
          await customStatement('''
            CREATE TABLE IF NOT EXISTS "sync_queue" (
              "id" TEXT NOT NULL PRIMARY KEY,
              "entity_type" TEXT NOT NULL,
              "entity_id" TEXT NOT NULL,
              "operation" TEXT NOT NULL,
              "timestamp" INTEGER NOT NULL,
              "retry_count" INTEGER NOT NULL DEFAULT 0
            );
          ''');
        } catch (error, stackTrace) {
          debugPrint('[AppDatabase.beforeOpen] sync_queue table creation warning: $error\n$stackTrace');
        }

        // Defensive runtime schema verification for v10 (Match Sessions, Players, Events):
        try {
          await customStatement('''
            CREATE TABLE IF NOT EXISTS "match_sessions" (
              "id" TEXT NOT NULL PRIMARY KEY,
              "name" TEXT NOT NULL DEFAULT 'MTG Match',
              "format" TEXT NOT NULL DEFAULT 'Commander',
              "starting_life" INTEGER NOT NULL DEFAULT 40,
              "player_count" INTEGER NOT NULL DEFAULT 4,
              "status" TEXT NOT NULL DEFAULT 'active',
              "created_at" INTEGER NOT NULL,
              "ended_at" INTEGER,
              "is_p2p_host" INTEGER NOT NULL DEFAULT 0,
              "p2p_session_code" TEXT,
              "settings_json" TEXT,
              "is_deleted" INTEGER NOT NULL DEFAULT 0,
              "updated_at" INTEGER
            );
          ''');
        } catch (error, stackTrace) {
          debugPrint('[AppDatabase.beforeOpen] match_sessions table creation warning: $error\n$stackTrace');
        }

        try {
          await customStatement('''
            CREATE TABLE IF NOT EXISTS "match_players" (
              "id" TEXT NOT NULL PRIMARY KEY,
              "session_id" TEXT NOT NULL REFERENCES "match_sessions" ("id"),
              "seat_order" INTEGER NOT NULL,
              "player_name" TEXT NOT NULL,
              "deck_id" TEXT REFERENCES "decks" ("id"),
              "commander_card_id" TEXT REFERENCES "vault_items" ("id"),
              "commander_name" TEXT,
              "art_crop_url" TEXT,
              "color_theme" TEXT,
              "current_life" INTEGER NOT NULL DEFAULT 40,
              "poison" INTEGER NOT NULL DEFAULT 0,
              "energy" INTEGER NOT NULL DEFAULT 0,
              "experience" INTEGER NOT NULL DEFAULT 0,
              "commander_tax" INTEGER NOT NULL DEFAULT 0,
              "is_monarch" INTEGER NOT NULL DEFAULT 0,
              "has_initiative" INTEGER NOT NULL DEFAULT 0,
              "is_eliminated" INTEGER NOT NULL DEFAULT 0,
              "eliminated_at" INTEGER,
              "is_local_device" INTEGER NOT NULL DEFAULT 1,
              "peer_device_id" TEXT,
              "commander_damage_json" TEXT,
              "floating_mana_json" TEXT,
              "storm_count" INTEGER NOT NULL DEFAULT 0,
              "counters_json" TEXT,
              "is_deleted" INTEGER NOT NULL DEFAULT 0,
              "updated_at" INTEGER
            );
          ''');
        } catch (error, stackTrace) {
          debugPrint('[AppDatabase.beforeOpen] match_players table creation warning: $error\n$stackTrace');
        }

        try {
          await customStatement('''
            CREATE TABLE IF NOT EXISTS "match_events" (
              "id" TEXT NOT NULL PRIMARY KEY,
              "session_id" TEXT NOT NULL REFERENCES "match_sessions" ("id"),
              "player_id" TEXT NOT NULL,
              "source_player_id" TEXT,
              "event_type" TEXT NOT NULL,
              "delta" INTEGER NOT NULL DEFAULT 0,
              "value" INTEGER NOT NULL DEFAULT 0,
              "sequence_number" INTEGER NOT NULL DEFAULT 0,
              "payload_json" TEXT,
              "timestamp" INTEGER NOT NULL,
              "is_undone" INTEGER NOT NULL DEFAULT 0,
              "is_deleted" INTEGER NOT NULL DEFAULT 0,
              "updated_at" INTEGER
            );
          ''');
        } catch (error, stackTrace) {
          debugPrint('[AppDatabase.beforeOpen] match_events table creation warning: $error\n$stackTrace');
        }

        // Heavy column verifications, index creations, and full-table data repairs
        // MUST only run on database creation or schema migration to prevent storage lockups
        // during routine connection open cycles with large hydrated catalogs (450k+ rows).
        if (details.wasCreated || details.hadUpgrade) {
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
                AND "quantity" > 0
                AND json_valid("dynamic_data") = 1
                AND "dynamic_data" LIKE '%"flavor_name"%'
                AND json_extract("dynamic_data", '\$.flavor_name') IS NOT NULL
                AND json_extract("dynamic_data", '\$.flavor_name') != '';
            ''');

            // Backfill current_market_price for legacy cards where it was 0 or null but dynamic_data has prices
            await customStatement('''
              UPDATE "vault_items"
              SET "current_market_price" = CAST(json_extract("dynamic_data", '\$.prices.usd') AS REAL)
              WHERE ("current_market_price" IS NULL OR "current_market_price" <= 0.0)
                AND "quantity" > 0
                AND json_valid("dynamic_data") = 1
                AND "dynamic_data" LIKE '%"usd"%'
                AND json_extract("dynamic_data", '\$.prices.usd') IS NOT NULL
                AND json_extract("dynamic_data", '\$.prices.usd') != ''
                AND CAST(json_extract("dynamic_data", '\$.prices.usd') AS REAL) > 0.0;
            ''');
            await customStatement('''
              UPDATE "vault_items"
              SET "current_market_price" = CAST(json_extract("dynamic_data", '\$.prices.usd_foil') AS REAL)
              WHERE ("current_market_price" IS NULL OR "current_market_price" <= 0.0)
                AND "quantity" > 0
                AND json_valid("dynamic_data") = 1
                AND "dynamic_data" LIKE '%"usd_foil"%'
                AND json_extract("dynamic_data", '\$.prices.usd_foil') IS NOT NULL
                AND json_extract("dynamic_data", '\$.prices.usd_foil') != ''
                AND CAST(json_extract("dynamic_data", '\$.prices.usd_foil') AS REAL) > 0.0;
            ''');
            await customStatement('''
              UPDATE "vault_items"
              SET "current_market_price" = CAST(json_extract("dynamic_data", '\$.prices.eur') AS REAL)
              WHERE ("current_market_price" IS NULL OR "current_market_price" <= 0.0)
                AND "quantity" > 0
                AND json_valid("dynamic_data") = 1
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
              if (!deckColumnNames.contains('is_assembled')) {
                await customStatement(
                  'ALTER TABLE "decks" ADD COLUMN "is_assembled" INTEGER NOT NULL DEFAULT 0;',
                );
                await customStatement(
                  'UPDATE "decks" SET "is_assembled" = "is_registered";',
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

            // Safe non-destructive legacy backfill scoped strictly to owned inventory cards:
            // 1. Copy acquired_date to date_obtained where not already populated
            await customStatement('''
              UPDATE "vault_items"
              SET "date_obtained" = "acquired_date"
              WHERE "date_obtained" IS NULL AND "acquired_date" IS NOT NULL AND "quantity" > 0;
            ''');

            // 2. Copy acquired_price to purchase_price where not already populated
            await customStatement('''
              UPDATE "vault_items"
              SET "purchase_price" = "acquired_price"
              WHERE "purchase_price" IS NULL AND "acquired_price" IS NOT NULL AND "quantity" > 0;
            ''');

            // 3. Copy personal_notes to notes where not already populated
            await customStatement('''
              UPDATE "vault_items"
              SET "notes" = "personal_notes"
              WHERE "notes" IS NULL AND "personal_notes" IS NOT NULL AND "quantity" > 0;
            ''');

            // 4. Default protection_status to 'Sleeved' for null or empty values
            await customStatement('''
              UPDATE "vault_items"
              SET "protection_status" = 'Sleeved'
              WHERE ("protection_status" IS NULL OR "protection_status" = '') AND "quantity" > 0;
            ''');
          } catch (error, stackTrace) {
            debugPrint('[AppDatabase.beforeOpen] vault_items v8 schema verification/backfill warning: $error\n$stackTrace');
          }

          // Defensive column verification for entity tables
          final entityTables = [
            'vault_items',
            'vault_binders',
            'decks',
            'deck_versions',
            'deck_version_items',
            'deck_matchups',
            'deck_synergies',
          ];

          for (final tableName in entityTables) {
            try {
              final tableInfo =
                  await customSelect('PRAGMA table_info("$tableName");').get();
              final columnNames =
                  tableInfo.map((row) => row.read<String>('name')).toSet();

              if (!columnNames.contains('is_deleted')) {
                await customStatement(
                  'ALTER TABLE "$tableName" ADD COLUMN "is_deleted" INTEGER NOT NULL DEFAULT 0;',
                );
              }
              if (!columnNames.contains('updated_at')) {
                await customStatement(
                  'ALTER TABLE "$tableName" ADD COLUMN "updated_at" INTEGER;',
                );
              }
            } catch (error, stackTrace) {
              debugPrint('[AppDatabase.beforeOpen] v9 schema verification ($tableName) warning: $error\n$stackTrace');
            }
          }

          // Defensive column checks for v10 tables in case of schema drift
          try {
            final sessionCols = (await customSelect('PRAGMA table_info("match_sessions");').get())
                .map((row) => row.read<String>('name'))
                .toSet();
            if (sessionCols.isNotEmpty) {
              if (!sessionCols.contains('name')) await customStatement('ALTER TABLE "match_sessions" ADD COLUMN "name" TEXT NOT NULL DEFAULT \'MTG Match\';');
              if (!sessionCols.contains('format')) await customStatement('ALTER TABLE "match_sessions" ADD COLUMN "format" TEXT NOT NULL DEFAULT \'Commander\';');
              if (!sessionCols.contains('starting_life')) await customStatement('ALTER TABLE "match_sessions" ADD COLUMN "starting_life" INTEGER NOT NULL DEFAULT 40;');
              if (!sessionCols.contains('player_count')) await customStatement('ALTER TABLE "match_sessions" ADD COLUMN "player_count" INTEGER NOT NULL DEFAULT 4;');
              if (!sessionCols.contains('status')) await customStatement('ALTER TABLE "match_sessions" ADD COLUMN "status" TEXT NOT NULL DEFAULT \'active\';');
              if (!sessionCols.contains('is_p2p_host')) await customStatement('ALTER TABLE "match_sessions" ADD COLUMN "is_p2p_host" INTEGER NOT NULL DEFAULT 0;');
              if (!sessionCols.contains('p2p_session_code')) await customStatement('ALTER TABLE "match_sessions" ADD COLUMN "p2p_session_code" TEXT;');
              if (!sessionCols.contains('settings_json')) await customStatement('ALTER TABLE "match_sessions" ADD COLUMN "settings_json" TEXT;');
              if (!sessionCols.contains('is_deleted')) await customStatement('ALTER TABLE "match_sessions" ADD COLUMN "is_deleted" INTEGER NOT NULL DEFAULT 0;');
              if (!sessionCols.contains('updated_at')) await customStatement('ALTER TABLE "match_sessions" ADD COLUMN "updated_at" INTEGER;');
            }

            final playerCols = (await customSelect('PRAGMA table_info("match_players");').get())
                .map((row) => row.read<String>('name'))
                .toSet();
            if (playerCols.isNotEmpty) {
              if (!playerCols.contains('poison')) await customStatement('ALTER TABLE "match_players" ADD COLUMN "poison" INTEGER NOT NULL DEFAULT 0;');
              if (!playerCols.contains('energy')) await customStatement('ALTER TABLE "match_players" ADD COLUMN "energy" INTEGER NOT NULL DEFAULT 0;');
              if (!playerCols.contains('experience')) await customStatement('ALTER TABLE "match_players" ADD COLUMN "experience" INTEGER NOT NULL DEFAULT 0;');
              if (!playerCols.contains('commander_tax')) await customStatement('ALTER TABLE "match_players" ADD COLUMN "commander_tax" INTEGER NOT NULL DEFAULT 0;');
              if (!playerCols.contains('is_monarch')) await customStatement('ALTER TABLE "match_players" ADD COLUMN "is_monarch" INTEGER NOT NULL DEFAULT 0;');
              if (!playerCols.contains('has_initiative')) await customStatement('ALTER TABLE "match_players" ADD COLUMN "has_initiative" INTEGER NOT NULL DEFAULT 0;');
              if (!playerCols.contains('is_eliminated')) await customStatement('ALTER TABLE "match_players" ADD COLUMN "is_eliminated" INTEGER NOT NULL DEFAULT 0;');
              if (!playerCols.contains('eliminated_at')) await customStatement('ALTER TABLE "match_players" ADD COLUMN "eliminated_at" INTEGER;');
              if (!playerCols.contains('is_local_device')) await customStatement('ALTER TABLE "match_players" ADD COLUMN "is_local_device" INTEGER NOT NULL DEFAULT 1;');
              if (!playerCols.contains('peer_device_id')) await customStatement('ALTER TABLE "match_players" ADD COLUMN "peer_device_id" TEXT;');
              if (!playerCols.contains('commander_damage_json')) await customStatement('ALTER TABLE "match_players" ADD COLUMN "commander_damage_json" TEXT;');
              if (!playerCols.contains('floating_mana_json')) await customStatement('ALTER TABLE "match_players" ADD COLUMN "floating_mana_json" TEXT;');
              if (!playerCols.contains('storm_count')) await customStatement('ALTER TABLE "match_players" ADD COLUMN "storm_count" INTEGER NOT NULL DEFAULT 0;');
              if (!playerCols.contains('counters_json')) await customStatement('ALTER TABLE "match_players" ADD COLUMN "counters_json" TEXT;');
              if (!playerCols.contains('is_deleted')) await customStatement('ALTER TABLE "match_players" ADD COLUMN "is_deleted" INTEGER NOT NULL DEFAULT 0;');
              if (!playerCols.contains('updated_at')) await customStatement('ALTER TABLE "match_players" ADD COLUMN "updated_at" INTEGER;');
            }

            final eventCols = (await customSelect('PRAGMA table_info("match_events");').get())
                .map((row) => row.read<String>('name'))
                .toSet();
            if (eventCols.isNotEmpty) {
              if (!eventCols.contains('source_player_id')) await customStatement('ALTER TABLE "match_events" ADD COLUMN "source_player_id" TEXT;');
              if (!eventCols.contains('delta')) await customStatement('ALTER TABLE "match_events" ADD COLUMN "delta" INTEGER NOT NULL DEFAULT 0;');
              if (!eventCols.contains('value')) await customStatement('ALTER TABLE "match_events" ADD COLUMN "value" INTEGER NOT NULL DEFAULT 0;');
              if (!eventCols.contains('sequence_number')) await customStatement('ALTER TABLE "match_events" ADD COLUMN "sequence_number" INTEGER NOT NULL DEFAULT 0;');
              if (!eventCols.contains('payload_json')) await customStatement('ALTER TABLE "match_events" ADD COLUMN "payload_json" TEXT;');
              if (!eventCols.contains('is_undone')) await customStatement('ALTER TABLE "match_events" ADD COLUMN "is_undone" INTEGER NOT NULL DEFAULT 0;');
              if (!eventCols.contains('is_deleted')) await customStatement('ALTER TABLE "match_events" ADD COLUMN "is_deleted" INTEGER NOT NULL DEFAULT 0;');
              if (!eventCols.contains('updated_at')) await customStatement('ALTER TABLE "match_events" ADD COLUMN "updated_at" INTEGER;');
            }
          } catch (error, stackTrace) {
            debugPrint('[AppDatabase.beforeOpen] v10 column verification warning: $error\n$stackTrace');
          }

          // Compound indexes for high-speed match queries and sequence log ordering
          try {
            await customStatement('''
              CREATE INDEX IF NOT EXISTS "idx_match_sessions_status"
              ON "match_sessions" ("status", "is_deleted", "created_at" DESC);
            ''');
            await customStatement('''
              CREATE INDEX IF NOT EXISTS "idx_match_players_session"
              ON "match_players" ("session_id", "seat_order" ASC);
            ''');
            await customStatement('''
              CREATE INDEX IF NOT EXISTS "idx_match_events_session_seq"
              ON "match_events" ("session_id", "sequence_number" ASC);
            ''');
            await customStatement('''
              CREATE INDEX IF NOT EXISTS "idx_match_events_player"
              ON "match_events" ("player_id", "event_type");
            ''');
          } catch (error, stackTrace) {
            debugPrint('[AppDatabase.beforeOpen] Match index creation warning: $error\n$stackTrace');
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
            await customStatement('''
              CREATE INDEX IF NOT EXISTS "idx_vault_items_active"
              ON "vault_items" ("is_deleted", "collection_type", "quantity");
            ''');
            await customStatement('''
              CREATE INDEX IF NOT EXISTS "idx_decks_active"
              ON "decks" ("is_deleted");
            ''');
            await customStatement('''
              CREATE INDEX IF NOT EXISTS "idx_deck_version_items_active"
              ON "deck_version_items" ("is_deleted", "version_id");
            ''');
            await customStatement('''
              CREATE INDEX IF NOT EXISTS "idx_sync_queue_order"
              ON "sync_queue" ("timestamp" ASC, "retry_count" ASC);
            ''');
          } catch (error, stackTrace) {
            debugPrint('[AppDatabase.beforeOpen] Index creation warning: $error\n$stackTrace');
          }
        }

        // Defensive runtime backfill for The One Ring art and Scryfall metadata:
        // Automatically patch legacy databases where The One Ring has the 404 image URL
        // or is missing scryfall_id using fast primary key lookup.
        try {
          await customStatement('''
            UPDATE "vault_items"
            SET "image_url" = 'https://cards.scryfall.io/large/front/d/5/d5806e68-1054-458e-866d-1f2470f682b2.jpg?1790212038'
            WHERE "id" = 'item-mtg-one-ring' AND ("image_url" LIKE '%78038b95%' OR "image_url" IS NULL OR "image_url" = '');
          ''');

          await customStatement('''
            UPDATE "vault_items"
            SET "dynamic_data" = json_set(
              CASE WHEN json_valid("dynamic_data") = 1 THEN "dynamic_data" ELSE '{}' END,
              '\$.scryfall_id', 'd5806e68-1054-458e-866d-1f2470f682b2',
              '\$.oracle_id', '3aa83ed2-f48b-4ce6-a614-2c54ddf50538',
              '\$.image_uris', json('{"small":"https://cards.scryfall.io/small/front/d/5/d5806e68-1054-458e-866d-1f2470f682b2.jpg?1790212038","normal":"https://cards.scryfall.io/normal/front/d/5/d5806e68-1054-458e-866d-1f2470f682b2.jpg?1790212038","large":"https://cards.scryfall.io/large/front/d/5/d5806e68-1054-458e-866d-1f2470f682b2.jpg?1790212038","art_crop":"https://cards.scryfall.io/art_crop/front/d/5/d5806e68-1054-458e-866d-1f2470f682b2.jpg?1790212038"}'),
              '\$.finish', 'foil'
            )
            WHERE "id" = 'item-mtg-one-ring'
              AND json_valid("dynamic_data") = 1
              AND ("dynamic_data" NOT LIKE '%"scryfall_id"%' OR json_extract("dynamic_data", '\$.scryfall_id') IS NULL);
          ''');
        } catch (error, stackTrace) {
          debugPrint('[AppDatabase.beforeOpen] The One Ring art backfill warning: $error\n$stackTrace');
        }

        try {
          // Automatically seed database on first open if empty of owned cards
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
