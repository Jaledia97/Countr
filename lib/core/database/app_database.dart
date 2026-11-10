import 'dart:async';
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
import 'package:countr/core/database/tables/decks/explore_decks_table.dart';
import 'package:countr/core/database/tables/decks/explore_deck_items_table.dart';
import 'package:countr/core/database/tables/decks/explore_deck_votes_table.dart';
import 'package:countr/features/decks/data/daos/explore_deck_dao.dart';
import 'package:countr/core/database/tables/user_profiles_table.dart';
import 'package:countr/features/profile/data/daos/user_profile_dao.dart';
import 'package:countr/core/database/tables/social/feed_posts_table.dart';
import 'package:countr/core/database/tables/social/post_likes_table.dart';
import 'package:countr/core/database/tables/social/post_comments_table.dart';
import 'package:countr/core/database/tables/social/friendships_table.dart';
import 'package:countr/core/database/tables/social/notifications_table.dart';
import 'package:countr/core/database/tables/social/messages_table.dart';
import 'package:countr/core/database/tables/social/trade_proposals_table.dart';
import 'package:countr/core/database/tables/social/user_follows_table.dart';
import 'package:countr/core/database/tables/social/card_reputation_votes_table.dart';
import 'package:countr/core/database/tables/social/post_votes_table.dart';
import 'package:countr/core/database/tables/social/post_reactions_table.dart';
import 'package:countr/core/database/tables/social/comment_reactions_table.dart';
import 'package:countr/core/database/tables/social/saved_posts_table.dart';
import 'package:countr/features/feed/data/daos/feed_dao.dart';
import 'package:countr/features/feed/data/daos/inbox_dao.dart';
import 'package:countr/features/feed/data/daos/friends_dao.dart';
import 'package:countr/features/vault/data/daos/card_reputation_dao.dart';

part 'app_database.g.dart';

QueryExecutor _resolveConnection(QueryExecutor? e) {
  if (e != null) {
    if (e is DatabaseConnection) return e;
    return DatabaseConnection(e, closeStreamsSynchronously: true);
  }
  final conn = openConnection();
  if (conn is DatabaseConnection) return conn;
  return DatabaseConnection(conn, closeStreamsSynchronously: true);
}

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
    // Milestone 1 (v11): Explore Decks, Items, and Persistent Voting
    ExploreDecks,
    ExploreDeckItems,
    ExploreDeckVotes,
    // Milestone 3 (v12): User Profiles
    UserProfiles,
    // Milestone 4: Social, Feed, Inbox, Friends
    FeedPosts,
    PostLikes,
    PostComments,
    Friendships,
    Notifications,
    Messages,
    TradeProposals,
    UserFollows,
    CardReputationVotes,
    // Milestone 1 (v16): Social Votes, Reactions & Bookmarks
    PostVotes,
    PostReactions,
    CommentReactions,
    SavedPosts,
  ],
  daos: [
    VaultDao,
    MatchDao,
    ExploreDeckDao,
    UserProfileDao,
    FeedDao,
    InboxDao,
    FriendsDao,
    CardReputationDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(_resolveConnection(e));

  static const beforeOpenZoneKey = #_driftBeforeOpen;

  bool _isOpening = false;
  /// Returns true while Drift's [beforeOpen] lifecycle callback is actively executing.
  bool get isOpening => _isOpening;

  @override
  int get schemaVersion => 16;

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
        Future<void> safeAddColumn(TableInfo table, GeneratedColumn column) async {
          try {
            final tableCheck = await customSelect(
              "SELECT name FROM sqlite_master WHERE type='table' AND name=?;",
              variables: [Variable.withString(table.actualTableName)],
            ).get();
            if (tableCheck.isEmpty) return;

            final existingCols = await customSelect(
              'PRAGMA table_info("${table.actualTableName}");',
            ).get();
            final exists = existingCols.any((row) => row.data['name'] == column.name);
            if (!exists) {
              await m.addColumn(table, column);
            }
          } catch (error) {
            try {
              await m.addColumn(table, column);
            } catch (innerError) {
              debugPrint('[AppDatabase.onUpgrade] Safe add column ${table.actualTableName}.${column.name} warning: $innerError');
            }
          }
        }

        if (from < 7) {
          await safeAddColumn(decks, decks.tcgDomain);
          await safeAddColumn(decks, decks.isRegistered);
          await safeAddColumn(decks, decks.isCompetitive);
        }
        if (from < 8) {
          await safeAddColumn(vaultItems, vaultItems.dateObtained);
          await safeAddColumn(vaultItems, vaultItems.purchasePrice);
          await safeAddColumn(vaultItems, vaultItems.binderPage);
          await safeAddColumn(vaultItems, vaultItems.binderSlot);
          await safeAddColumn(vaultItems, vaultItems.notes);
          await safeAddColumn(vaultItems, vaultItems.protectionStatus);

          Future<void> safeBackfill(String sql) async {
            try {
              final tableCheck = await customSelect(
                "SELECT name FROM sqlite_master WHERE type='table' AND name='vault_items';",
              ).get();
              if (tableCheck.isEmpty) return;

              await customStatement(sql);
            } catch (error, stackTrace) {
              debugPrint('[AppDatabase.onUpgrade] Migration v8 backfill warning: $error\n$stackTrace');
            }
          }

          // Safe non-destructive legacy backfill during migration:
          await safeBackfill('''
            UPDATE "vault_items"
            SET "date_obtained" = "acquired_date"
            WHERE "date_obtained" IS NULL AND "acquired_date" IS NOT NULL AND "quantity" > 0;
          ''');
          await safeBackfill('''
            UPDATE "vault_items"
            SET "purchase_price" = "acquired_price"
            WHERE "purchase_price" IS NULL AND "acquired_price" IS NOT NULL AND "quantity" > 0;
          ''');
          await safeBackfill('''
            UPDATE "vault_items"
            SET "notes" = "personal_notes"
            WHERE "notes" IS NULL AND "personal_notes" IS NOT NULL AND "quantity" > 0;
          ''');
          await safeBackfill('''
            UPDATE "vault_items"
            SET "protection_status" = 'Sleeved'
            WHERE ("protection_status" IS NULL OR "protection_status" = '') AND "quantity" > 0;
          ''');
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

        if (from < 11) {
          try {
            await m.createTable(exploreDecks);
          } catch (error, stackTrace) {
            debugPrint('[AppDatabase.onUpgrade] Migration to v11 (exploreDecks) warning: $error\n$stackTrace');
          }
          try {
            await m.createTable(exploreDeckItems);
          } catch (error, stackTrace) {
            debugPrint('[AppDatabase.onUpgrade] Migration to v11 (exploreDeckItems) warning: $error\n$stackTrace');
          }
          try {
            await m.createTable(exploreDeckVotes);
          } catch (error, stackTrace) {
            debugPrint('[AppDatabase.onUpgrade] Migration to v11 (exploreDeckVotes) warning: $error\n$stackTrace');
          }

          await safeAddColumn(decks, decks.isCloned);
          await safeAddColumn(decks, decks.sourceExploreDeckId);
          await safeAddColumn(exploreDecks, exploreDecks.authorId);
        }

        if (from < 12) {
          try {
            await m.createTable(userProfiles);
          } catch (error, stackTrace) {
            debugPrint('[AppDatabase.onUpgrade] Migration to v12 (userProfiles) warning: $error\n$stackTrace');
          }

          await safeAddColumn(vaultBinders, vaultBinders.isSystemBinder);
          await safeAddColumn(vaultBinders, vaultBinders.systemBinderType);
          await safeAddColumn(vaultBinders, vaultBinders.userId);
          await safeAddColumn(vaultBinders, vaultBinders.deletedAt);
          await safeAddColumn(vaultBinders, vaultBinders.syncStatus);

          await safeAddColumn(vaultItems, vaultItems.userId);
          await safeAddColumn(vaultItems, vaultItems.isTraded);
          await safeAddColumn(vaultItems, vaultItems.deletedAt);
          await safeAddColumn(vaultItems, vaultItems.syncStatus);

          await safeAddColumn(decks, decks.userId);
          await safeAddColumn(decks, decks.deletedAt);
          await safeAddColumn(decks, decks.syncStatus);

          await safeAddColumn(deckVersions, deckVersions.deletedAt);
          await safeAddColumn(deckVersions, deckVersions.syncStatus);

          await safeAddColumn(deckVersionItems, deckVersionItems.deletedAt);
          await safeAddColumn(deckVersionItems, deckVersionItems.syncStatus);

          await safeAddColumn(deckMatchups, deckMatchups.deletedAt);
          await safeAddColumn(deckMatchups, deckMatchups.syncStatus);

          await safeAddColumn(deckSynergies, deckSynergies.deletedAt);
          await safeAddColumn(deckSynergies, deckSynergies.syncStatus);

          await safeAddColumn(exploreDeckVotes, exploreDeckVotes.isDeleted);
          await safeAddColumn(exploreDeckVotes, exploreDeckVotes.deletedAt);
          await safeAddColumn(exploreDeckVotes, exploreDeckVotes.syncStatus);
        }

        if (from < 13) {
          try {
            await m.createTable(userFollows);
          } catch (error, stackTrace) {
            debugPrint('[AppDatabase.onUpgrade] Migration to v13 (userFollows) warning: $error\n$stackTrace');
          }
          await safeAddColumn(feedPosts, feedPosts.sharedByUserId);
        }

        if (from < 14) {
          try {
            await m.createTable(cardReputationVotes);
          } catch (error, stackTrace) {
            debugPrint('[AppDatabase.onUpgrade] Migration to v14 (cardReputationVotes) warning: $error\n$stackTrace');
          }
          await safeAddColumn(vaultItems, vaultItems.reputationScore);
          await safeAddColumn(vaultItems, vaultItems.upvotes);
          await safeAddColumn(vaultItems, vaultItems.downvotes);
        }

        if (from < 15) {
          await safeAddColumn(userProfiles, userProfiles.collectionVisibility);
        }

        if (from < 16) {
          try {
            await m.createTable(postVotes);
          } catch (error, stackTrace) {
            debugPrint('[AppDatabase.onUpgrade] Migration to v16 (postVotes) warning: $error\n$stackTrace');
          }
          try {
            await m.createTable(postReactions);
          } catch (error, stackTrace) {
            debugPrint('[AppDatabase.onUpgrade] Migration to v16 (postReactions) warning: $error\n$stackTrace');
          }
          try {
            await m.createTable(commentReactions);
          } catch (error, stackTrace) {
            debugPrint('[AppDatabase.onUpgrade] Migration to v16 (commentReactions) warning: $error\n$stackTrace');
          }
          try {
            await m.createTable(savedPosts);
          } catch (error, stackTrace) {
            debugPrint('[AppDatabase.onUpgrade] Migration to v16 (savedPosts) warning: $error\n$stackTrace');
          }

          await safeAddColumn(postComments, postComments.parentCommentId);
          await safeAddColumn(vaultItems, vaultItems.isWishlisted);
        }
      },
      beforeOpen: (details) async {
        _isOpening = true;
        try {
          await runZoned(
            () async {
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

        // Defensive runtime schema verification for v11 (Explore Decks, Items, Votes):
        try {
          await customStatement('''
            CREATE TABLE IF NOT EXISTS "explore_decks" (
              "id" TEXT NOT NULL PRIMARY KEY,
              "name" TEXT NOT NULL,
              "format" TEXT NOT NULL,
              "tcg_domain" TEXT NOT NULL DEFAULT 'mtg',
              "source_type" TEXT NOT NULL DEFAULT 'official',
              "creator_name" TEXT NOT NULL DEFAULT 'Wizards of the Coast',
              "author_id" TEXT,
              "description" TEXT,
              "commander_name" TEXT,
              "commander_image_url" TEXT,
              "commander_art_crop" TEXT,
              "color_identity" TEXT NOT NULL DEFAULT '[]',
              "card_count" INTEGER NOT NULL DEFAULT 100,
              "estimated_price" REAL NOT NULL DEFAULT 0.0,
              "upvotes" INTEGER NOT NULL DEFAULT 0,
              "downvotes" INTEGER NOT NULL DEFAULT 0,
              "score" INTEGER NOT NULL DEFAULT 0,
              "featured_category" TEXT,
              "release_code" TEXT,
              "release_year" INTEGER,
              "tags" TEXT,
              "created_at" INTEGER NOT NULL,
              "updated_at" INTEGER,
              "is_deleted" INTEGER NOT NULL DEFAULT 0
            );
          ''');
        } catch (error, stackTrace) {
          debugPrint('[AppDatabase.beforeOpen] explore_decks table creation warning: $error\n$stackTrace');
        }

        try {
          await customStatement('''
            CREATE TABLE IF NOT EXISTS "explore_deck_items" (
              "id" TEXT NOT NULL PRIMARY KEY,
              "explore_deck_id" TEXT NOT NULL REFERENCES "explore_decks" ("id") ON DELETE CASCADE,
              "card_name" TEXT NOT NULL,
              "scryfall_id" TEXT,
              "oracle_id" TEXT,
              "quantity" INTEGER NOT NULL DEFAULT 1,
              "board_zone" TEXT NOT NULL DEFAULT 'Mainboard',
              "mana_cost" TEXT,
              "cmc" REAL,
              "type_line" TEXT,
              "colors" TEXT,
              "image_url" TEXT,
              "art_crop_url" TEXT,
              "price" REAL,
              "is_commander" INTEGER NOT NULL DEFAULT 0,
              "dynamic_data" TEXT,
              "is_deleted" INTEGER NOT NULL DEFAULT 0
            );
          ''');
        } catch (error, stackTrace) {
          debugPrint('[AppDatabase.beforeOpen] explore_deck_items table creation warning: $error\n$stackTrace');
        }

        try {
          await customStatement('''
            CREATE TABLE IF NOT EXISTS "explore_deck_votes" (
              "id" TEXT NOT NULL PRIMARY KEY,
              "explore_deck_id" TEXT NOT NULL REFERENCES "explore_decks" ("id") ON DELETE CASCADE,
              "user_id" TEXT NOT NULL DEFAULT 'local_user',
              "vote" INTEGER NOT NULL DEFAULT 0,
              "updated_at" INTEGER NOT NULL
            );
          ''');
        } catch (error, stackTrace) {
          debugPrint('[AppDatabase.beforeOpen] explore_deck_votes table creation warning: $error\n$stackTrace');
        }

        // Fast unconditional verification for v11 columns on decks and explore_deck_items
        try {
          final decksInfo =
              await customSelect('PRAGMA table_info("decks");').get();
          final deckCols =
              decksInfo.map((row) => row.read<String>('name')).toSet();
          if (deckCols.isNotEmpty) {
            if (!deckCols.contains('is_cloned')) {
              await customStatement(
                'ALTER TABLE "decks" ADD COLUMN "is_cloned" INTEGER NOT NULL DEFAULT 0;',
              );
            }
            if (!deckCols.contains('source_explore_deck_id')) {
              await customStatement(
                'ALTER TABLE "decks" ADD COLUMN "source_explore_deck_id" TEXT;',
              );
            }
          }

          final exploreItemsInfo =
              await customSelect('PRAGMA table_info("explore_deck_items");').get();
          final exploreItemCols =
              exploreItemsInfo.map((row) => row.read<String>('name')).toSet();
          if (exploreItemCols.isNotEmpty &&
              !exploreItemCols.contains('dynamic_data')) {
            await customStatement(
              'ALTER TABLE "explore_deck_items" ADD COLUMN "dynamic_data" TEXT;',
            );
          }

          final exploreDecksInfo =
              await customSelect('PRAGMA table_info("explore_decks");').get();
          final exploreCols =
              exploreDecksInfo.map((row) => row.read<String>('name')).toSet();
          if (exploreCols.isNotEmpty && !exploreCols.contains('author_id')) {
            await customStatement(
              'ALTER TABLE "explore_decks" ADD COLUMN "author_id" TEXT;',
            );
          }

          // Defensive column verification for M5 (deck_versions, deck_version_items, explore_deck_votes)
          final deckVersionsInfo =
              await customSelect('PRAGMA table_info("deck_versions");').get();
          final dvCols =
              deckVersionsInfo.map((row) => row.read<String>('name')).toSet();
          if (dvCols.isNotEmpty) {
            if (!dvCols.contains('deleted_at')) {
              await customStatement('ALTER TABLE "deck_versions" ADD COLUMN "deleted_at" INTEGER;');
            }
            if (!dvCols.contains('sync_status')) {
              await customStatement('ALTER TABLE "deck_versions" ADD COLUMN "sync_status" TEXT DEFAULT \'synced\';');
            }
          }

          final deckVersionItemsInfo =
              await customSelect('PRAGMA table_info("deck_version_items");').get();
          final dviCols =
              deckVersionItemsInfo.map((row) => row.read<String>('name')).toSet();
          if (dviCols.isNotEmpty) {
            if (!dviCols.contains('deleted_at')) {
              await customStatement('ALTER TABLE "deck_version_items" ADD COLUMN "deleted_at" INTEGER;');
            }
            if (!dviCols.contains('sync_status')) {
              await customStatement('ALTER TABLE "deck_version_items" ADD COLUMN "sync_status" TEXT DEFAULT \'synced\';');
            }
          }

          final exploreVotesInfo =
              await customSelect('PRAGMA table_info("explore_deck_votes");').get();
          final evCols =
              exploreVotesInfo.map((row) => row.read<String>('name')).toSet();
          if (evCols.isNotEmpty) {
            if (!evCols.contains('is_deleted')) {
              await customStatement('ALTER TABLE "explore_deck_votes" ADD COLUMN "is_deleted" INTEGER NOT NULL DEFAULT 0;');
            }
            if (!evCols.contains('deleted_at')) {
              await customStatement('ALTER TABLE "explore_deck_votes" ADD COLUMN "deleted_at" INTEGER;');
            }
            if (!evCols.contains('sync_status')) {
              await customStatement('ALTER TABLE "explore_deck_votes" ADD COLUMN "sync_status" TEXT DEFAULT \'synced\';');
            }
          }

          final deckMatchupsInfo =
              await customSelect('PRAGMA table_info("deck_matchups");').get();
          final dmCols =
              deckMatchupsInfo.map((row) => row.read<String>('name')).toSet();
          if (dmCols.isNotEmpty) {
            if (!dmCols.contains('deleted_at')) {
              await customStatement('ALTER TABLE "deck_matchups" ADD COLUMN "deleted_at" INTEGER;');
            }
            if (!dmCols.contains('sync_status')) {
              await customStatement('ALTER TABLE "deck_matchups" ADD COLUMN "sync_status" TEXT DEFAULT \'synced\';');
            }
          }

          final deckSynergiesInfo =
              await customSelect('PRAGMA table_info("deck_synergies");').get();
          final dsCols =
              deckSynergiesInfo.map((row) => row.read<String>('name')).toSet();
          if (dsCols.isNotEmpty) {
            if (!dsCols.contains('deleted_at')) {
              await customStatement('ALTER TABLE "deck_synergies" ADD COLUMN "deleted_at" INTEGER;');
            }
            if (!dsCols.contains('sync_status')) {
              await customStatement('ALTER TABLE "deck_synergies" ADD COLUMN "sync_status" TEXT DEFAULT \'synced\';');
            }
          }
        } catch (error, stackTrace) {
          debugPrint('[AppDatabase.beforeOpen] v11/v12 column verification warning: $error\n$stackTrace');
        }

        // Defensive runtime schema verification for v12 (User Profiles, System Binders, Scoped items/decks):
        try {
          await customStatement('''
            CREATE TABLE IF NOT EXISTS "user_profiles" (
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

          // Check vault_binders v12 columns
          final bindersInfo = await customSelect('PRAGMA table_info("vault_binders");').get();
          final binderCols = bindersInfo.map((row) => row.read<String>('name')).toSet();
          if (binderCols.isNotEmpty) {
            if (!binderCols.contains('is_system_binder')) {
              await customStatement('ALTER TABLE "vault_binders" ADD COLUMN "is_system_binder" INTEGER NOT NULL DEFAULT 0;');
            }
            if (!binderCols.contains('system_binder_type')) {
              await customStatement('ALTER TABLE "vault_binders" ADD COLUMN "system_binder_type" TEXT;');
            }
            if (!binderCols.contains('user_id')) {
              await customStatement('ALTER TABLE "vault_binders" ADD COLUMN "user_id" TEXT;');
            }
            if (!binderCols.contains('deleted_at')) {
              await customStatement('ALTER TABLE "vault_binders" ADD COLUMN "deleted_at" INTEGER;');
            }
            if (!binderCols.contains('sync_status')) {
              await customStatement('ALTER TABLE "vault_binders" ADD COLUMN "sync_status" TEXT NOT NULL DEFAULT \'synced\';');
            }
          }

          // Check vault_items v12 columns
          final itemsInfo = await customSelect('PRAGMA table_info("vault_items");').get();
          final itemCols = itemsInfo.map((row) => row.read<String>('name')).toSet();
          if (itemCols.isNotEmpty) {
            if (!itemCols.contains('user_id')) {
              await customStatement('ALTER TABLE "vault_items" ADD COLUMN "user_id" TEXT;');
            }
            if (!itemCols.contains('is_traded')) {
              await customStatement('ALTER TABLE "vault_items" ADD COLUMN "is_traded" INTEGER NOT NULL DEFAULT 0;');
            }
            if (!itemCols.contains('deleted_at')) {
              await customStatement('ALTER TABLE "vault_items" ADD COLUMN "deleted_at" INTEGER;');
            }
            if (!itemCols.contains('sync_status')) {
              await customStatement('ALTER TABLE "vault_items" ADD COLUMN "sync_status" TEXT NOT NULL DEFAULT \'synced\';');
            }
          }

          // Check decks v12 columns
          final decksInfo12 = await customSelect('PRAGMA table_info("decks");').get();
          final deckCols12 = decksInfo12.map((row) => row.read<String>('name')).toSet();
          if (deckCols12.isNotEmpty) {
            if (!deckCols12.contains('user_id')) {
              await customStatement('ALTER TABLE "decks" ADD COLUMN "user_id" TEXT;');
            }
            if (!deckCols12.contains('deleted_at')) {
              await customStatement('ALTER TABLE "decks" ADD COLUMN "deleted_at" INTEGER;');
            }
            if (!deckCols12.contains('sync_status')) {
              await customStatement('ALTER TABLE "decks" ADD COLUMN "sync_status" TEXT NOT NULL DEFAULT \'synced\';');
            }
          }

          // v12 Covering Indexes
          await customStatement('''
            CREATE INDEX IF NOT EXISTS "idx_user_profiles_username"
            ON "user_profiles" ("username" COLLATE NOCASE);
          ''');
          await customStatement('''
            CREATE INDEX IF NOT EXISTS "idx_vault_binders_user_system"
            ON "vault_binders" ("user_id", "is_system_binder");
          ''');
          await customStatement('''
            CREATE INDEX IF NOT EXISTS "idx_vault_binders_user"
            ON "vault_binders" ("user_id");
          ''');
          await customStatement('''
            CREATE INDEX IF NOT EXISTS "idx_vault_items_user"
            ON "vault_items" ("user_id");
          ''');
          await customStatement('''
            CREATE INDEX IF NOT EXISTS "idx_decks_user"
            ON "decks" ("user_id");
          ''');

          // Milestone 4: Social tables and indexes
          await customStatement('''
            CREATE TABLE IF NOT EXISTS "feed_posts" (
              "id" TEXT NOT NULL PRIMARY KEY,
              "author_id" TEXT NOT NULL,
              "author_username" TEXT NOT NULL,
              "author_display_name" TEXT NOT NULL,
              "author_avatar_url" TEXT,
              "type" TEXT NOT NULL,
              "text_content" TEXT,
              "location_tag" TEXT,
              "card_id" TEXT,
              "card_title" TEXT,
              "card_subtitle" TEXT,
              "card_rarity" TEXT,
              "estimated_value" REAL,
              "card_image_url" TEXT,
              "pull_images_json" TEXT,
              "pull_card_ids_json" TEXT,
              "like_count" INTEGER NOT NULL DEFAULT 0,
              "comment_count" INTEGER NOT NULL DEFAULT 0,
              "created_at" INTEGER NOT NULL,
              "updated_at" INTEGER NOT NULL,
              "deleted_at" INTEGER,
              "is_deleted" INTEGER NOT NULL DEFAULT 0,
              "sync_status" TEXT NOT NULL DEFAULT 'synced'
            );
          ''');

          await customStatement('''
            CREATE TABLE IF NOT EXISTS "post_likes" (
              "id" TEXT NOT NULL PRIMARY KEY,
              "post_id" TEXT NOT NULL,
              "user_id" TEXT NOT NULL,
              "is_liked" INTEGER NOT NULL DEFAULT 1,
              "created_at" INTEGER NOT NULL,
              "updated_at" INTEGER NOT NULL,
              "deleted_at" INTEGER,
              "is_deleted" INTEGER NOT NULL DEFAULT 0,
              "sync_status" TEXT NOT NULL DEFAULT 'synced'
            );
          ''');

          await customStatement('''
            CREATE TABLE IF NOT EXISTS "post_comments" (
              "id" TEXT NOT NULL PRIMARY KEY,
              "post_id" TEXT NOT NULL,
              "author_id" TEXT NOT NULL,
              "author_username" TEXT NOT NULL,
              "author_display_name" TEXT NOT NULL,
              "author_avatar_url" TEXT,
              "content" TEXT NOT NULL,
              "created_at" INTEGER NOT NULL,
              "updated_at" INTEGER NOT NULL,
              "deleted_at" INTEGER,
              "is_deleted" INTEGER NOT NULL DEFAULT 0,
              "sync_status" TEXT NOT NULL DEFAULT 'synced'
            );
          ''');

          await customStatement('''
            CREATE TABLE IF NOT EXISTS "friendships" (
              "id" TEXT NOT NULL PRIMARY KEY,
              "user_id" TEXT NOT NULL,
              "friend_id" TEXT NOT NULL,
              "status" TEXT NOT NULL DEFAULT 'pending',
              "created_at" INTEGER NOT NULL,
              "updated_at" INTEGER,
              "deleted_at" INTEGER,
              "is_deleted" INTEGER NOT NULL DEFAULT 0,
              "sync_status" TEXT NOT NULL DEFAULT 'synced'
            );
          ''');

          await customStatement('''
            CREATE TABLE IF NOT EXISTS "notifications" (
              "id" TEXT NOT NULL PRIMARY KEY,
              "user_id" TEXT NOT NULL,
              "actor_id" TEXT NOT NULL,
              "actor_username" TEXT NOT NULL,
              "actor_display_name" TEXT,
              "actor_avatar_url" TEXT,
              "type" TEXT NOT NULL,
              "title" TEXT NOT NULL,
              "body" TEXT NOT NULL,
              "target_entity_id" TEXT,
              "target_entity_type" TEXT,
              "status" TEXT NOT NULL DEFAULT 'unread',
              "is_read" INTEGER NOT NULL DEFAULT 0,
              "is_actioned" INTEGER NOT NULL DEFAULT 0,
              "created_at" INTEGER NOT NULL,
              "updated_at" INTEGER,
              "deleted_at" INTEGER,
              "is_deleted" INTEGER NOT NULL DEFAULT 0,
              "sync_status" TEXT NOT NULL DEFAULT 'synced'
            );
          ''');

          await customStatement('''
            CREATE TABLE IF NOT EXISTS "messages" (
              "id" TEXT NOT NULL PRIMARY KEY,
              "conversation_id" TEXT NOT NULL,
              "sender_id" TEXT NOT NULL,
              "recipient_id" TEXT NOT NULL,
              "message_text" TEXT NOT NULL,
              "attachment_type" TEXT NOT NULL DEFAULT 'none',
              "attachment_card_id" TEXT,
              "attachment_card_json" TEXT,
              "attachment_trade_proposal_id" TEXT,
              "is_read" INTEGER NOT NULL DEFAULT 0,
              "created_at" INTEGER NOT NULL,
              "updated_at" INTEGER,
              "deleted_at" INTEGER,
              "is_deleted" INTEGER NOT NULL DEFAULT 0,
              "sync_status" TEXT NOT NULL DEFAULT 'synced'
            );
          ''');

          await customStatement('''
            CREATE TABLE IF NOT EXISTS "trade_proposals" (
              "id" TEXT NOT NULL PRIMARY KEY,
              "proposer_id" TEXT NOT NULL,
              "receiver_id" TEXT NOT NULL,
              "offered_card_ids_json" TEXT NOT NULL,
              "requested_card_ids_json" TEXT NOT NULL,
              "offered_cards_snapshot_json" TEXT,
              "requested_cards_snapshot_json" TEXT,
              "proposer_cash_delta" REAL NOT NULL DEFAULT 0.0,
              "offered_total_value" REAL NOT NULL DEFAULT 0.0,
              "requested_total_value" REAL NOT NULL DEFAULT 0.0,
              "status" TEXT NOT NULL DEFAULT 'pending',
              "note" TEXT,
              "is_transferred" INTEGER NOT NULL DEFAULT 0,
              "created_at" INTEGER NOT NULL,
              "updated_at" INTEGER,
              "deleted_at" INTEGER,
              "is_deleted" INTEGER NOT NULL DEFAULT 0,
              "sync_status" TEXT NOT NULL DEFAULT 'synced'
            );
          ''');

          // Social covering indexes
          await customStatement('''
            CREATE INDEX IF NOT EXISTS "idx_feed_posts_created_at"
            ON "feed_posts" ("is_deleted", "created_at" DESC);
          ''');
          await customStatement('''
            CREATE INDEX IF NOT EXISTS "idx_feed_posts_author"
            ON "feed_posts" ("author_id", "is_deleted", "created_at" DESC);
          ''');
          await customStatement('''
            CREATE UNIQUE INDEX IF NOT EXISTS "unique_post_likes"
            ON "post_likes" ("post_id", "user_id");
          ''');
          await customStatement('''
            CREATE INDEX IF NOT EXISTS "idx_post_comments_post"
            ON "post_comments" ("post_id", "is_deleted", "created_at" ASC);
          ''');
          await customStatement('''
            CREATE INDEX IF NOT EXISTS "idx_friendships_user_status"
            ON "friendships" ("user_id", "status", "is_deleted");
          ''');
          await customStatement('''
            CREATE INDEX IF NOT EXISTS "idx_friendships_friend_status"
            ON "friendships" ("friend_id", "status", "is_deleted");
          ''');
          await customStatement('''
            CREATE INDEX IF NOT EXISTS "idx_notifications_user_read"
            ON "notifications" ("user_id", "is_read", "is_deleted", "created_at" DESC);
          ''');
          await customStatement('''
            CREATE INDEX IF NOT EXISTS "idx_messages_conversation"
            ON "messages" ("conversation_id", "is_deleted", "created_at" ASC);
          ''');
          await customStatement('''
            CREATE INDEX IF NOT EXISTS "idx_messages_recipient_read"
            ON "messages" ("recipient_id", "is_read", "is_deleted");
          ''');
          await customStatement('''
            CREATE INDEX IF NOT EXISTS "idx_trade_proposals_proposer"
            ON "trade_proposals" ("proposer_id", "status", "is_deleted");
          ''');
          await customStatement('''
            CREATE INDEX IF NOT EXISTS "idx_trade_proposals_receiver"
            ON "trade_proposals" ("receiver_id", "status", "is_deleted");
          ''');

          // Milestone 3 (v13): User Follows table and feed_posts shared_by_user_id column
          await customStatement('''
            CREATE TABLE IF NOT EXISTS "user_follows" (
              "id" TEXT NOT NULL PRIMARY KEY,
              "follower_id" TEXT NOT NULL,
              "target_user_id" TEXT NOT NULL,
              "created_at" INTEGER NOT NULL,
              "deleted_at" INTEGER,
              "is_deleted" INTEGER NOT NULL DEFAULT 0,
              "sync_status" TEXT DEFAULT 'synced'
            );
          ''');

          final feedPostsInfo =
              await customSelect('PRAGMA table_info("feed_posts");').get();
          final feedPostCols =
              feedPostsInfo.map((row) => row.read<String>('name')).toSet();
          if (feedPostCols.isNotEmpty && !feedPostCols.contains('shared_by_user_id')) {
            await customStatement(
              'ALTER TABLE "feed_posts" ADD COLUMN "shared_by_user_id" TEXT;',
            );
          }

          await customStatement('''
            CREATE INDEX IF NOT EXISTS "idx_user_follows_follower"
            ON "user_follows" ("follower_id");
          ''');
          await customStatement('''
            CREATE INDEX IF NOT EXISTS "idx_user_follows_target"
            ON "user_follows" ("target_user_id");
          ''');
        } catch (error, stackTrace) {
          debugPrint('[AppDatabase.beforeOpen] v12/v13 column & table verification warning: $error\n$stackTrace');
        }

        // Milestone 4 (v14): Card Reputation Votes table and VaultItems reputation columns
        try {
          await customStatement('''
            CREATE TABLE IF NOT EXISTS "card_reputation_votes" (
              "id" TEXT NOT NULL PRIMARY KEY,
              "card_id" TEXT NOT NULL,
              "user_id" TEXT NOT NULL DEFAULT 'local_user',
              "vote" INTEGER NOT NULL DEFAULT 0,
              "updated_at" INTEGER NOT NULL,
              "is_deleted" INTEGER NOT NULL DEFAULT 0,
              "deleted_at" INTEGER,
              "sync_status" TEXT DEFAULT 'synced'
            );
          ''');

          await customStatement('''
            CREATE UNIQUE INDEX IF NOT EXISTS "unique_card_reputation_votes"
            ON "card_reputation_votes" ("card_id", "user_id");
          ''');

          await customStatement('''
            CREATE INDEX IF NOT EXISTS "idx_card_reputation_votes_card"
            ON "card_reputation_votes" ("card_id", "is_deleted");
          ''');

          final vaultItemsInfo =
              await customSelect('PRAGMA table_info("vault_items");').get();
          final viCols =
              vaultItemsInfo.map((row) => row.read<String>('name')).toSet();
          if (viCols.isNotEmpty) {
            if (!viCols.contains('reputation_score')) {
              await customStatement(
                'ALTER TABLE "vault_items" ADD COLUMN "reputation_score" INTEGER DEFAULT 0;',
              );
            }
            if (!viCols.contains('upvotes')) {
              await customStatement(
                'ALTER TABLE "vault_items" ADD COLUMN "upvotes" INTEGER DEFAULT 0;',
              );
            }
            if (!viCols.contains('downvotes')) {
              await customStatement(
                'ALTER TABLE "vault_items" ADD COLUMN "downvotes" INTEGER DEFAULT 0;',
              );
            }
          }

          if (viCols.contains('is_deleted')) {
            await customStatement('''
              CREATE INDEX IF NOT EXISTS "idx_vault_items_reputation"
              ON "vault_items" ("is_deleted", "collection_type", "reputation_score" DESC);
            ''');
          }
        } catch (error, stackTrace) {
          debugPrint('[AppDatabase.beforeOpen] v14 reputation table & column verification warning: $error\n$stackTrace');
        }

        // Milestone 1 (v16): Post Votes, Post Reactions, Comment Reactions, Saved Posts
        try {
          await customStatement('''
            CREATE TABLE IF NOT EXISTS "post_votes" (
              "id" TEXT NOT NULL PRIMARY KEY,
              "post_id" TEXT NOT NULL,
              "user_id" TEXT NOT NULL,
              "vote" INTEGER NOT NULL DEFAULT 0,
              "created_at" INTEGER NOT NULL,
              "updated_at" INTEGER NOT NULL,
              "deleted_at" INTEGER,
              "is_deleted" INTEGER NOT NULL DEFAULT 0,
              "sync_status" TEXT DEFAULT 'synced'
            );
          ''');

          await customStatement('''
            CREATE UNIQUE INDEX IF NOT EXISTS "unique_post_votes"
            ON "post_votes" ("post_id", "user_id");
          ''');

          await customStatement('''
            CREATE INDEX IF NOT EXISTS "idx_post_votes_post"
            ON "post_votes" ("post_id", "is_deleted");
          ''');

          await customStatement('''
            CREATE TABLE IF NOT EXISTS "post_reactions" (
              "id" TEXT NOT NULL PRIMARY KEY,
              "post_id" TEXT NOT NULL,
              "user_id" TEXT NOT NULL,
              "emoji" TEXT NOT NULL,
              "created_at" INTEGER NOT NULL,
              "deleted_at" INTEGER,
              "is_deleted" INTEGER NOT NULL DEFAULT 0,
              "sync_status" TEXT DEFAULT 'synced'
            );
          ''');

          await customStatement('''
            CREATE UNIQUE INDEX IF NOT EXISTS "unique_post_reactions"
            ON "post_reactions" ("post_id", "user_id", "emoji");
          ''');

          await customStatement('''
            CREATE INDEX IF NOT EXISTS "idx_post_reactions_post"
            ON "post_reactions" ("post_id", "is_deleted");
          ''');

          await customStatement('''
            CREATE TABLE IF NOT EXISTS "comment_reactions" (
              "id" TEXT NOT NULL PRIMARY KEY,
              "comment_id" TEXT NOT NULL,
              "user_id" TEXT NOT NULL,
              "emoji" TEXT NOT NULL,
              "created_at" INTEGER NOT NULL,
              "deleted_at" INTEGER,
              "is_deleted" INTEGER NOT NULL DEFAULT 0,
              "sync_status" TEXT DEFAULT 'synced'
            );
          ''');

          await customStatement('''
            CREATE UNIQUE INDEX IF NOT EXISTS "unique_comment_reactions"
            ON "comment_reactions" ("comment_id", "user_id", "emoji");
          ''');

          await customStatement('''
            CREATE INDEX IF NOT EXISTS "idx_comment_reactions_comment"
            ON "comment_reactions" ("comment_id", "is_deleted");
          ''');

          await customStatement('''
            CREATE TABLE IF NOT EXISTS "saved_posts" (
              "id" TEXT NOT NULL PRIMARY KEY,
              "post_id" TEXT NOT NULL,
              "user_id" TEXT NOT NULL,
              "created_at" INTEGER NOT NULL,
              "deleted_at" INTEGER,
              "is_deleted" INTEGER NOT NULL DEFAULT 0,
              "sync_status" TEXT DEFAULT 'synced'
            );
          ''');

          await customStatement('''
            CREATE UNIQUE INDEX IF NOT EXISTS "unique_saved_posts"
            ON "saved_posts" ("post_id", "user_id");
          ''');

          await customStatement('''
            CREATE INDEX IF NOT EXISTS "idx_saved_posts_user"
            ON "saved_posts" ("user_id", "is_deleted", "created_at" DESC);
          ''');

          final commentCols = (await customSelect('PRAGMA table_info("post_comments");').get())
              .map((row) => row.read<String>('name'))
              .toSet();
          if (commentCols.isNotEmpty && !commentCols.contains('parent_comment_id')) {
            await customStatement('ALTER TABLE "post_comments" ADD COLUMN "parent_comment_id" TEXT;');
          }

          final vaultCols = (await customSelect('PRAGMA table_info("vault_items");').get())
              .map((row) => row.read<String>('name'))
              .toSet();
          if (vaultCols.isNotEmpty && !vaultCols.contains('is_wishlisted')) {
            await customStatement('ALTER TABLE "vault_items" ADD COLUMN "is_wishlisted" INTEGER NOT NULL DEFAULT 0;');
          }

          if (commentCols.contains('parent_comment_id') && commentCols.contains('is_deleted')) {
            await customStatement('''
              CREATE INDEX IF NOT EXISTS "idx_post_comments_parent"
              ON "post_comments" ("parent_comment_id", "is_deleted");
            ''');
          }

          if (vaultCols.contains('is_wishlisted') && vaultCols.contains('is_deleted')) {
            await customStatement('''
              CREATE INDEX IF NOT EXISTS "idx_vault_items_wishlisted"
              ON "vault_items" ("is_deleted", "is_wishlisted");
            ''');
          }
        } catch (error, stackTrace) {
          debugPrint('[AppDatabase.beforeOpen] v16 table & column verification warning: $error\n$stackTrace');
        }

        // Fast unconditional covering indexes for Vault browse and catalog ordering
        try {
          final vaultBrowseCols = (await customSelect('PRAGMA table_info("vault_items");').get())
              .map((row) => row.read<String>('name'))
              .toSet();

          if (vaultBrowseCols.contains('is_deleted')) {
            await customStatement('''
              CREATE INDEX IF NOT EXISTS "idx_vault_items_browse"
              ON "vault_items" ("is_deleted", "collection_type", "acquired_date" DESC, "name" ASC);
            ''');
            await customStatement('''
              CREATE INDEX IF NOT EXISTS "idx_vault_items_catalog_name"
              ON "vault_items" ("is_deleted", "collection_type", "name" COLLATE NOCASE ASC);
            ''');
          }

          if (vaultBrowseCols.contains('dynamic_data')) {
            await customStatement('''
              CREATE INDEX IF NOT EXISTS "idx_vault_items_expr_set_code"
              ON "vault_items" (json_extract(dynamic_data, '\$.set_code'))
              WHERE json_valid(dynamic_data) = 1;
            ''');
            await customStatement('''
              CREATE INDEX IF NOT EXISTS "idx_vault_items_expr_collector_number"
              ON "vault_items" (json_extract(dynamic_data, '\$.collector_number'))
              WHERE json_valid(dynamic_data) = 1;
            ''');
            await customStatement('''
              CREATE INDEX IF NOT EXISTS "idx_vault_items_expr_rarity"
              ON "vault_items" (json_extract(dynamic_data, '\$.rarity'))
              WHERE json_valid(dynamic_data) = 1;
            ''');
            await customStatement('''
              CREATE INDEX IF NOT EXISTS "idx_vault_items_expr_cmc"
              ON "vault_items" (CAST(json_extract(dynamic_data, '\$.cmc') AS REAL))
              WHERE json_valid(dynamic_data) = 1;
            ''');
            await customStatement('''
              CREATE INDEX IF NOT EXISTS "idx_vault_items_expr_type_line"
              ON "vault_items" (json_extract(dynamic_data, '\$.type_line') COLLATE NOCASE)
              WHERE json_valid(dynamic_data) = 1;
            ''');
            await customStatement('''
              CREATE INDEX IF NOT EXISTS "idx_vault_items_expr_colors"
              ON "vault_items" (json_extract(dynamic_data, '\$.colors'))
              WHERE json_valid(dynamic_data) = 1;
            ''');
            await customStatement('''
              CREATE INDEX IF NOT EXISTS "idx_vault_items_expr_color_identity"
              ON "vault_items" (json_extract(dynamic_data, '\$.color_identity'))
              WHERE json_valid(dynamic_data) = 1;
            ''');
            await customStatement('''
              CREATE INDEX IF NOT EXISTS "idx_vault_items_expr_layout"
              ON "vault_items" (json_extract(dynamic_data, '\$.layout'))
              WHERE json_valid(dynamic_data) = 1;
            ''');
          }
        } catch (error, stackTrace) {
          debugPrint('[AppDatabase.beforeOpen] Vault browse covering indexes warning: $error\n$stackTrace');
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
              CREATE INDEX IF NOT EXISTS "idx_vault_items_set_series"
              ON "vault_items" ("set_or_series");
            ''');
            await customStatement('''
              CREATE INDEX IF NOT EXISTS "idx_vault_items_condition"
              ON "vault_items" ("condition");
            ''');
            await customStatement('''
              CREATE INDEX IF NOT EXISTS "idx_vault_items_flags"
              ON "vault_items" ("is_graded", "is_altered", "is_misprint", "is_signed");
            ''');
            await customStatement('''
              CREATE INDEX IF NOT EXISTS "idx_vault_items_expr_set_code"
              ON "vault_items" (json_extract(dynamic_data, '\$.set_code'))
              WHERE json_valid(dynamic_data) = 1;
            ''');
            await customStatement('''
              CREATE INDEX IF NOT EXISTS "idx_vault_items_expr_collector_number"
              ON "vault_items" (json_extract(dynamic_data, '\$.collector_number'))
              WHERE json_valid(dynamic_data) = 1;
            ''');
            await customStatement('''
              CREATE INDEX IF NOT EXISTS "idx_vault_items_expr_rarity"
              ON "vault_items" (json_extract(dynamic_data, '\$.rarity'))
              WHERE json_valid(dynamic_data) = 1;
            ''');
            await customStatement('''
              CREATE INDEX IF NOT EXISTS "idx_vault_items_expr_cmc"
              ON "vault_items" (CAST(json_extract(dynamic_data, '\$.cmc') AS REAL))
              WHERE json_valid(dynamic_data) = 1;
            ''');
            await customStatement('''
              CREATE INDEX IF NOT EXISTS "idx_vault_items_expr_type_line"
              ON "vault_items" (json_extract(dynamic_data, '\$.type_line') COLLATE NOCASE)
              WHERE json_valid(dynamic_data) = 1;
            ''');
            await customStatement('''
              CREATE INDEX IF NOT EXISTS "idx_vault_items_expr_colors"
              ON "vault_items" (json_extract(dynamic_data, '\$.colors'))
              WHERE json_valid(dynamic_data) = 1;
            ''');
            await customStatement('''
              CREATE INDEX IF NOT EXISTS "idx_vault_items_expr_color_identity"
              ON "vault_items" (json_extract(dynamic_data, '\$.color_identity'))
              WHERE json_valid(dynamic_data) = 1;
            ''');
            await customStatement('''
              CREATE INDEX IF NOT EXISTS "idx_vault_items_expr_layout"
              ON "vault_items" (json_extract(dynamic_data, '\$.layout'))
              WHERE json_valid(dynamic_data) = 1;
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

          // Defensive runtime schema verification for decks v11 columns
          try {
            final decksTableInfo =
                await customSelect('PRAGMA table_info("decks");').get();
            final deckColumnNames =
                decksTableInfo.map((row) => row.read<String>('name')).toSet();
            if (deckColumnNames.isNotEmpty) {
              if (!deckColumnNames.contains('is_cloned')) {
                await customStatement(
                  'ALTER TABLE "decks" ADD COLUMN "is_cloned" INTEGER NOT NULL DEFAULT 0;',
                );
              }
              if (!deckColumnNames.contains('source_explore_deck_id')) {
                await customStatement(
                  'ALTER TABLE "decks" ADD COLUMN "source_explore_deck_id" TEXT;',
                );
              }
            }
          } catch (error, stackTrace) {
            debugPrint('[AppDatabase.beforeOpen] decks v11 column verification warning: $error\n$stackTrace');
          }

          // Compound indexes for Explore Discovery, Carousels, and Search (v11)
          try {
            await customStatement('''
              CREATE INDEX IF NOT EXISTS "idx_explore_decks_source_score"
              ON "explore_decks" ("source_type", "score" DESC, "created_at" DESC);
            ''');
            await customStatement('''
              CREATE INDEX IF NOT EXISTS "idx_explore_decks_format_score"
              ON "explore_decks" ("format", "score" DESC);
            ''');
            await customStatement('''
              CREATE INDEX IF NOT EXISTS "idx_explore_decks_featured"
              ON "explore_decks" ("featured_category", "score" DESC);
            ''');
            await customStatement('''
              CREATE INDEX IF NOT EXISTS "idx_explore_deck_items_deck"
              ON "explore_deck_items" ("explore_deck_id", "board_zone");
            ''');
            await customStatement('''
              CREATE INDEX IF NOT EXISTS "idx_explore_deck_items_card_name"
              ON "explore_deck_items" ("card_name" COLLATE NOCASE);
            ''');
            await customStatement('''
              CREATE UNIQUE INDEX IF NOT EXISTS "idx_explore_deck_votes_unique"
              ON "explore_deck_votes" ("explore_deck_id", "user_id");
            ''');
            await customStatement('''
              CREATE INDEX IF NOT EXISTS "idx_explore_decks_author"
              ON "explore_decks" ("author_id");
            ''');
          } catch (error, stackTrace) {
            debugPrint('[AppDatabase.beforeOpen] Explore index creation warning: $error\n$stackTrace');
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
      zoneValues: {beforeOpenZoneKey: true},
    );
  } catch (error, stackTrace) {
    debugPrint('[AppDatabase.beforeOpen] beforeOpen unhandled error: $error\n$stackTrace');
  } finally {
    _isOpening = false;
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
