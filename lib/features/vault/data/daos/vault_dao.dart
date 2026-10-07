import 'dart:convert';
import 'dart:math' as math;
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/database/tables/vault_binders_table.dart';
import 'package:countr/core/database/tables/vault_items_table.dart';
import 'package:countr/features/decks/data/mock_deck_data.dart';
import 'package:countr/features/decks/domain/models/board_zone.dart';
import 'package:countr/features/decks/domain/models/assembly_models.dart';
import 'package:countr/features/scanner/domain/ocr_heuristic_matcher.dart';
import 'package:countr/features/decks/domain/models/deck_item_with_card.dart';
import 'package:countr/features/decks/domain/models/deck_summary.dart';
import 'package:countr/features/vault/domain/models/vault_totals.dart';
import 'package:countr/features/vault/domain/models/card_availability.dart';
import 'package:countr/features/vault/domain/vault_variant_helper.dart';
import 'package:countr/features/vault/presentation/providers/mtg_filter_state.dart';
import 'package:countr/features/vault/domain/models/vault_set_collection.dart';

import 'package:countr/core/database/tables/decks/decks_table.dart';
import 'package:countr/core/database/tables/decks/deck_versions_table.dart';
import 'package:countr/core/database/tables/decks/deck_version_items_table.dart';
import 'package:countr/core/database/tables/decks/deck_matchups_table.dart';
import 'package:countr/core/database/tables/decks/deck_synergies_table.dart';
import 'package:countr/core/database/tables/sync_queue_table.dart';

part 'vault_dao.g.dart';

/// Data Access Object for VaultItems and VaultBinders with polymorphic queries and seeding.
@DriftAccessor(tables: [
  VaultItems,
  VaultBinders,
  Decks,
  DeckVersions,
  DeckVersionItems,
  DeckMatchups,
  DeckSynergies,
  SyncQueue,
])
class VaultDao extends DatabaseAccessor<AppDatabase> with _$VaultDaoMixin {
  VaultDao(super.db);

  // ---------------------------------------------------------------------------
  // OUTBOX SYNC QUEUE HELPERS
  // ---------------------------------------------------------------------------

  /// Internal outbox logging helper. Records all mutations for cloud synchronization.
  Future<void> _recordSync(
    String entityType,
    String entityId,
    String operation, {
    DateTime? timestamp,
  }) async {
    final now = timestamp ?? DateTime.now();
    await into(syncQueue).insert(
      SyncQueueCompanion.insert(
        id: const Uuid().v4(),
        entityType: entityType,
        entityId: entityId,
        operation: operation,
        timestamp: now,
        retryCount: const Value(0),
      ),
    );
  }

  /// Retrieves pending sync queue entries ordered chronologically.
  Future<List<SyncQueueEntry>> getPendingSyncEntries({int limit = 100}) {
    return (select(syncQueue)
          ..orderBy([(t) => OrderingTerm(expression: t.timestamp, mode: OrderingMode.asc)])
          ..limit(limit))
        .get();
  }

  /// Acknowledges and deletes a synchronized entry from the outbox.
  Future<int> markSyncCompleted(String syncId) {
    return (delete(syncQueue)..where((t) => t.id.equals(syncId))).go();
  }

  /// Increments the retry counter for a failed synchronization attempt atomically in SQLite.
  Future<int> incrementSyncRetry(String syncId) {
    return customUpdate(
      'UPDATE sync_queue SET retry_count = retry_count + 1 WHERE id = ?',
      variables: [Variable.withString(syncId)],
      updates: {syncQueue},
    );
  }

  /// Clears all entries from the sync queue outbox.
  Future<int> clearSyncQueue() {
    return delete(syncQueue).go();
  }

  /// Cleans up old sync queue entries older than a cutoff threshold (defaults to 30 days ago).
  Future<int> cleanupOldProcessedSyncQueue({
    Duration maxAge = const Duration(days: 30),
    DateTime? olderThan,
  }) {
    final cutoff = olderThan ?? DateTime.now().subtract(maxAge);
    return (delete(syncQueue)
          ..where((t) => t.timestamp.isSmallerThanValue(cutoff)))
        .go();
  }

  /// Watches the pending sync queue count for UI status indicators.
  Stream<int> watchPendingSyncCount() {
    final count = syncQueue.id.count();
    final query = selectOnly(syncQueue)..addColumns([count]);
    return query.map((row) => row.read(count) ?? 0).watchSingle();
  }

  /// Streams items filtered by collection type and optional [MtgFilterState].
  /// If [onlyOwned] is true, filters for quantity > 0 (personal vault inventory).
  /// If [limit] is provided, caps the returned rows to prevent UI thread memory spikes.
  Stream<List<VaultItem>> watchItemsByCollection(
    String collectionType, {
    bool onlyOwned = false,
    String? searchQuery,
    MtgFilterState? mtgFilter,
    int? limit,
    int? offset,
  }) {
    final normalized = _normalizeCollectionType(collectionType);
    final query = select(vaultItems);
    query.where((t) => t.isDeleted.equals(false));

    if (normalized != 'all') {
      query.where((t) => t.collectionType.equals(normalized));
    }

    if (onlyOwned) {
      query.where((t) => t.quantity.isBiggerThanValue(0));
    }

    query.where((t) =>
        t.primaryBinderId.isNull() |
        t.primaryBinderId.equals('INBOX').not());

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final clean = searchQuery.trim();
      final term = '%$clean%';
      final lower = clean.toLowerCase();
      final isSld = lower == 'sld' || lower == 'secret lair' || lower == 'secret lair drop';

      query.where((t) {
        final base = t.name.like(term) |
            t.flavorName.like(term) |
            t.setOrSeries.like(term) |
            t.dynamicData.like(term);
        if (isSld) {
          return base |
              t.setOrSeries.like('%Secret Lair%') |
              t.dynamicData.like('%"set":"sld"%') |
              t.dynamicData.like('%"set_code":"sld"%') |
              t.dynamicData.like('%"set": "sld"%') |
              t.dynamicData.like('%"set_code": "sld"%');
        }
        return base;
      });
    }

    final effectiveMtgFilter = (mtgFilter != null && mtgFilter.colors.isNotEmpty)
        ? mtgFilter.copyWith(colors: mtgFilter.colors.map((c) => c.toUpperCase()).toSet())
        : mtgFilter;

    // Stage 1: Push down direct SQLite column where clauses
    if (effectiveMtgFilter != null && effectiveMtgFilter.isActive) {
      _applyMtgFilterStage1(query, effectiveMtgFilter);
    } else {
      _applyDefaultMemorabiliaExclusion(query);
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      query.orderBy([
        (t) => OrderingTerm(
              expression: _buildSearchRankExpression(t, searchQuery),
              mode: OrderingMode.asc,
            ),
        (t) => OrderingTerm(
              expression: t.name,
              mode: OrderingMode.asc,
            ),
      ]);
    } else {
      query.orderBy([
        (t) => OrderingTerm(
              expression: t.acquiredDate,
              mode: OrderingMode.desc,
            ),
        (t) => OrderingTerm(
              expression: t.name,
              mode: OrderingMode.asc,
            ),
      ]);
    }

    final hasActiveMtgFilter = effectiveMtgFilter != null && effectiveMtgFilter.isActive;
    if (!hasActiveMtgFilter && limit != null) {
      query.limit(limit, offset: offset);
    }

    // Stage 2: In-memory stream mapping using mtgFilter.matches(item)
    return query.watch().map((items) {
      if (!hasActiveMtgFilter) return items;
      final filtered = items.where((item) => effectiveMtgFilter.matches(item));
      final skipped = (offset != null && offset > 0) ? filtered.skip(offset) : filtered;
      final limited = (limit != null) ? skipped.take(limit) : skipped;
      return limited.toList();
    });
  }

  /// One-shot query to fetch cards by collection type and optional [MtgFilterState].
  Future<List<VaultItem>> getItemsByCollection(
    String collectionType, {
    bool onlyOwned = false,
    String? searchQuery,
    MtgFilterState? mtgFilter,
    int? limit,
    int? offset,
  }) async {
    final normalized = _normalizeCollectionType(collectionType);
    final query = select(vaultItems);
    query.where((t) => t.isDeleted.equals(false));

    if (normalized != 'all') {
      query.where((t) => t.collectionType.equals(normalized));
    }

    if (onlyOwned) {
      query.where((t) => t.quantity.isBiggerThanValue(0));
    }

    query.where((t) =>
        t.primaryBinderId.isNull() |
        t.primaryBinderId.equals('INBOX').not());

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final clean = searchQuery.trim();
      final term = '%$clean%';
      final lower = clean.toLowerCase();
      final isSld = lower == 'sld' || lower == 'secret lair' || lower == 'secret lair drop';

      query.where((t) {
        final base = t.name.like(term) |
            t.flavorName.like(term) |
            t.setOrSeries.like(term) |
            t.dynamicData.like(term);
        if (isSld) {
          return base |
              t.setOrSeries.like('%Secret Lair%') |
              t.dynamicData.like('%"set":"sld"%') |
              t.dynamicData.like('%"set_code":"sld"%') |
              t.dynamicData.like('%"set": "sld"%') |
              t.dynamicData.like('%"set_code": "sld"%');
        }
        return base;
      });
    }

    final effectiveMtgFilter = (mtgFilter != null && mtgFilter.colors.isNotEmpty)
        ? mtgFilter.copyWith(colors: mtgFilter.colors.map((c) => c.toUpperCase()).toSet())
        : mtgFilter;

    // Stage 1: Push down direct SQLite column where clauses
    if (effectiveMtgFilter != null && effectiveMtgFilter.isActive) {
      _applyMtgFilterStage1(query, effectiveMtgFilter);
    } else {
      _applyDefaultMemorabiliaExclusion(query);
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      query.orderBy([
        (t) => OrderingTerm(
              expression: _buildSearchRankExpression(t, searchQuery),
              mode: OrderingMode.asc,
            ),
        (t) => OrderingTerm(
              expression: t.name,
              mode: OrderingMode.asc,
            ),
      ]);
    } else {
      query.orderBy([
        (t) => OrderingTerm(
              expression: t.acquiredDate,
              mode: OrderingMode.desc,
            ),
        (t) => OrderingTerm(
              expression: t.name,
              mode: OrderingMode.asc,
            ),
      ]);
    }

    final hasActiveMtgFilter = effectiveMtgFilter != null && effectiveMtgFilter.isActive;
    if (!hasActiveMtgFilter && limit != null) {
      query.limit(limit, offset: offset);
    }

    final items = await query.get();

    // Stage 2: In-memory evaluation using mtgFilter.matches(item)
    if (!hasActiveMtgFilter) {
      return items;
    }

    final filtered = items.where((item) => effectiveMtgFilter.matches(item));
    final skipped = (offset != null && offset > 0) ? filtered.skip(offset) : filtered;
    final limited = (limit != null) ? skipped.take(limit) : skipped;
    return limited.toList();
  }

  /// Generates a weighted search rank [Expression<int>] prioritizing:
  /// - Tier 1 (rank 1): Exact prefix match on name or flavor_name
  /// - Tier 1.5 (rank 2): Leading 'The ' bypass prefix match on name or flavor_name
  /// - Tier 2 (rank 3): Substring match on name or flavor_name
  /// - Fallback (rank 4): Other matches (e.g. setOrSeries or dynamicData)
  Expression<int> _buildSearchRankExpression($VaultItemsTable t, String query) {
    final clean = query.trim();
    return CaseWhenExpression<int>(
      cases: [
        CaseWhen(
          t.name.like('$clean%') |
              (t.flavorName.isNotNull() & t.flavorName.like('$clean%')),
          then: const Constant(1),
        ),
        CaseWhen(
          t.name.like('The $clean%') |
              (t.flavorName.isNotNull() & t.flavorName.like('The $clean%')),
          then: const Constant(2),
        ),
        CaseWhen(
          t.name.like('%$clean%') |
              (t.flavorName.isNotNull() & t.flavorName.like('%$clean%')),
          then: const Constant(3),
        ),
      ],
      orElse: const Constant(4),
    );
  }

  @visibleForTesting
  Expression<int> buildSearchRankExpression($VaultItemsTable t, String query) =>
      _buildSearchRankExpression(t, query);

  /// Default exclusion for Art Series and non-playable memorabilia.
  void _applyDefaultMemorabiliaExclusion(
    SimpleSelectStatement<$VaultItemsTable, VaultItem> query,
  ) {
    query.where((t) =>
        t.dynamicData.like('%"layout":"art_series"%').not() &
        t.dynamicData.like('%"layout": "art_series"%').not() &
        t.dynamicData.like('%"layout":"token"%').not() &
        t.dynamicData.like('%"layout": "token"%').not() &
        t.dynamicData.like('%"layout":"double_faced_token"%').not() &
        t.dynamicData.like('%"layout": "double_faced_token"%').not() &
        t.dynamicData.like('%"layout":"emblem"%').not() &
        t.dynamicData.like('%"layout": "emblem"%').not() &
        t.dynamicData.like('%"layout":"planar"%').not() &
        t.dynamicData.like('%"layout": "planar"%').not() &
        t.dynamicData.like('%"layout":"scheme"%').not() &
        t.dynamicData.like('%"layout": "scheme"%').not() &
        t.dynamicData.like('%"layout":"vanguard"%').not() &
        t.dynamicData.like('%"layout": "vanguard"%').not());
  }

  /// Applies Stage 1 SQL pushdown filters to the Drift query.
  void _applyMtgFilterStage1(
    SimpleSelectStatement<$VaultItemsTable, VaultItem> query,
    MtgFilterState filter,
  ) {
    // 0. Default exclusions & special cards pushdown
    final allowsArtCards = filter.rarities.contains('art_card') ||
        filter.rarities.contains('art card') ||
        filter.layouts.contains('art_series');
    final allowsSpecialCards = filter.rarities.contains('special') ||
        filter.rarities.contains('special_card') ||
        filter.rarities.contains('special card') ||
        filter.layouts.any((l) => [
              'token',
              'double_faced_token',
              'emblem',
              'planar',
              'scheme',
              'vanguard',
            ].contains(l.toLowerCase()));

    if (!allowsArtCards) {
      query.where((t) =>
          t.dynamicData.like('%"layout":"art_series"%').not() &
          t.dynamicData.like('%"layout": "art_series"%').not());
    }
    if (!allowsSpecialCards && !allowsArtCards) {
      query.where((t) =>
          t.dynamicData.like('%"layout":"token"%').not() &
          t.dynamicData.like('%"layout": "token"%').not() &
          t.dynamicData.like('%"layout":"double_faced_token"%').not() &
          t.dynamicData.like('%"layout": "double_faced_token"%').not() &
          t.dynamicData.like('%"layout":"emblem"%').not() &
          t.dynamicData.like('%"layout": "emblem"%').not() &
          t.dynamicData.like('%"layout":"planar"%').not() &
          t.dynamicData.like('%"layout": "planar"%').not() &
          t.dynamicData.like('%"layout":"scheme"%').not() &
          t.dynamicData.like('%"layout": "scheme"%').not() &
          t.dynamicData.like('%"layout":"vanguard"%').not() &
          t.dynamicData.like('%"layout": "vanguard"%').not());
    }

    // 1. Direct table columns
    if (filter.conditions.isNotEmpty) {
      final expandedConditions = filter.conditions
          .expand((c) => [c, c.toUpperCase(), c.toLowerCase()])
          .toSet()
          .toList();
      query.where((t) => t.condition.isIn(expandedConditions));
    }
    if (filter.isGraded != null) {
      query.where((t) => t.isGraded.equals(filter.isGraded!));
    }
    if (filter.isAltered != null) {
      query.where((t) => t.isAltered.equals(filter.isAltered!));
    }
    if (filter.isMisprint != null) {
      query.where((t) => t.isMisprint.equals(filter.isMisprint!));
    }
    if (filter.isSigned != null) {
      query.where((t) => t.isSigned.equals(filter.isSigned!));
    }

    // 2. Simple text pushdown clauses
    if (filter.typeLine.trim().isNotEmpty) {
      final parts = filter.typeLine.trim().split(RegExp(r'\s+'));
      for (final part in parts) {
        if (part.isNotEmpty) {
          query.where((t) => t.dynamicData.like('%$part%'));
        }
      }
    }

    for (final clause in filter.oracleTextClauses) {
      final trimmed = clause.trim();
      if (trimmed.isNotEmpty) {
        query.where((t) => t.dynamicData.like('%$trimmed%'));
      }
    }

    if (filter.isUniversesBeyond == true) {
      query.where((t) =>
          const CustomExpression<bool>(
            "json_extract(vault_items.dynamic_data, '\$.is_universes_beyond') = 1",
          ) |
          t.dynamicData.like('%"is_universes_beyond":true%') |
          t.dynamicData.like('%"is_universes_beyond": true%') |
          t.dynamicData.like('%universes_beyond%') |
          t.dynamicData.like('%universesbeyond%') |
          t.dynamicData.like('%"security_stamp":"triangle"%') |
          t.dynamicData.like('%"security_stamp": "triangle"%'));
    }

    if (filter.setCode.trim().isNotEmpty && filter.setOperator == '=') {
      final cleanSet = filter.setCode.trim().toLowerCase();
      final isSld = cleanSet == 'sld' || cleanSet == 'secret lair' || cleanSet == 'secret lair drop';
      if (isSld) {
        query.where((t) =>
            t.setOrSeries.like('%Secret Lair%') |
            t.dynamicData.like('%"set":"sld"%') |
            t.dynamicData.like('%"set_code":"sld"%') |
            t.dynamicData.like('%"set": "sld"%') |
            t.dynamicData.like('%"set_code": "sld"%'));
      } else {
        query.where((t) =>
            t.setOrSeries.equals(filter.setCode.trim()) |
            t.setOrSeries.like('%${filter.setCode.trim()}%') |
            t.dynamicData.like('%"set":"$cleanSet"%') |
            t.dynamicData.like('%"set_code":"$cleanSet"%') |
            t.dynamicData.like('%"set": "$cleanSet"%') |
            t.dynamicData.like('%"set_code": "$cleanSet"%'));
      }
    }

    // 3. Rarities pushdown
    if (filter.rarities.isNotEmpty) {
      query.where((t) {
        final rarityExprs = <Expression<bool>>[];
        for (final r in filter.rarities) {
          final clean = r.toLowerCase().trim();
          if (clean == 'art_card' || clean == 'art card') {
            rarityExprs.add(
              t.dynamicData.like('%"layout":"art_series"%') |
              t.dynamicData.like('%"layout": "art_series"%'),
            );
          } else if (clean == 'special_card' || clean == 'special card') {
            rarityExprs.add(
              t.dynamicData.like('%"rarity":"special"%') |
              t.dynamicData.like('%"rarity": "special"%') |
              t.dynamicData.like('%"rarity":"bonus"%') |
              t.dynamicData.like('%"rarity": "bonus"%') |
              t.dynamicData.like('%"layout":"token"%') |
              t.dynamicData.like('%"layout": "token"%'),
            );
          } else {
            rarityExprs.add(
              t.dynamicData.like('%"rarity":"$clean"%') |
              t.dynamicData.like('%"rarity": "$clean"%'),
            );
          }
        }
        var combined = rarityExprs.first;
        for (int i = 1; i < rarityExprs.length; i++) {
          combined = combined | rarityExprs[i];
        }
        return combined;
      });
    }

    // 4. Layouts pushdown
    if (filter.layouts.isNotEmpty) {
      query.where((t) {
        final layoutExprs = <Expression<bool>>[];
        for (final l in filter.layouts) {
          final clean = l.toLowerCase().trim();
          layoutExprs.add(
            t.dynamicData.like('%"layout":"$clean"%') |
            t.dynamicData.like('%"layout": "$clean"%'),
          );
        }
        var combined = layoutExprs.first;
        for (int i = 1; i < layoutExprs.length; i++) {
          combined = combined | layoutExprs[i];
        }
        return combined;
      });
    }

    // 5. Finishes pushdown
    if (filter.finishes.isNotEmpty) {
      query.where((t) {
        final finishExprs = <Expression<bool>>[];
        for (final f in filter.finishes) {
          final clean = f.toLowerCase().trim().replaceAll('-', '_');
          final raw = f.toLowerCase().trim();
          finishExprs.add(
            t.dynamicData.like('%"$clean"%') |
            t.dynamicData.like('%"$raw"%'),
          );
        }
        var combined = finishExprs.first;
        for (int i = 1; i < finishExprs.length; i++) {
          combined = combined | finishExprs[i];
        }
        return combined;
      });
    }

    // 6. Colors pushdown (Robust multi-target & multi-faced support)
    if (filter.colors.isNotEmpty) {
      final isColorIdentity = filter.colorTarget == ColorTarget.colorIdentity;
      final targetKey = isColorIdentity ? 'color_identity' : 'colors';
      final normalizedColors = filter.colors.map((c) => c.toUpperCase()).toSet();

      final onlyC = normalizedColors.length == 1 && normalizedColors.contains('C');
      if (onlyC) {
        query.where((t) =>
            CustomExpression<bool>(
              "CASE WHEN json_valid(vault_items.dynamic_data) = 1 THEN ("
              "json_extract(vault_items.dynamic_data, '\$.$targetKey') = '[]' OR "
              "json_extract(vault_items.dynamic_data, '\$.$targetKey') IS NULL"
              ") ELSE 0 END",
            ) |
            t.dynamicData.like('%"$targetKey":[]%') |
            t.dynamicData.like('%"$targetKey": []%') |
            t.dynamicData.like('%"{C}"%'));
      } else if (filter.colorMatchMode == ColorMatchMode.including ||
          filter.colorMatchMode == ColorMatchMode.exactly) {
        for (final upperC in normalizedColors.where((c) => c != 'C')) {
          query.where((t) => CustomExpression<bool>(
                "CASE WHEN json_valid(vault_items.dynamic_data) = 1 THEN ("
                "json_extract(vault_items.dynamic_data, '\$.$targetKey') GLOB '*\"$upperC\"*' OR "
                "json_extract(vault_items.dynamic_data, '\$.card_faces[0].$targetKey') GLOB '*\"$upperC\"*' OR "
                "json_extract(vault_items.dynamic_data, '\$.card_faces[1].$targetKey') GLOB '*\"$upperC\"*' OR "
                "json_extract(vault_items.dynamic_data, '\$.mana_cost') GLOB '*{*$upperC*}*' OR "
                "json_extract(vault_items.dynamic_data, '\$.card_faces[0].mana_cost') GLOB '*{*$upperC*}*' OR "
                "json_extract(vault_items.dynamic_data, '\$.card_faces[1].mana_cost') GLOB '*{*$upperC*}*'"
                ") ELSE 0 END",
              ));
        }
      } else if (filter.colorMatchMode == ColorMatchMode.atMost ||
          filter.colorMatchMode == ColorMatchMode.commander) {
        final excludedColors = {'W', 'U', 'B', 'R', 'G'}
            .difference(normalizedColors.where((c) => c != 'C').toSet());
        for (final ex in excludedColors) {
          query.where((t) => CustomExpression<bool>(
                "CASE WHEN json_valid(vault_items.dynamic_data) = 1 THEN ("
                "json_extract(vault_items.dynamic_data, '\$.$targetKey') NOT GLOB '*\"$ex\"*' AND "
                "(json_extract(vault_items.dynamic_data, '\$.card_faces[0].$targetKey') IS NULL OR "
                "json_extract(vault_items.dynamic_data, '\$.card_faces[0].$targetKey') NOT GLOB '*\"$ex\"*') AND "
                "(json_extract(vault_items.dynamic_data, '\$.card_faces[1].$targetKey') IS NULL OR "
                "json_extract(vault_items.dynamic_data, '\$.card_faces[1].$targetKey') NOT GLOB '*\"$ex\"*')"
                ") ELSE 1 END",
              ));
        }
      }
    }

    // 7. Formats pushdown
    if (filter.formats.isNotEmpty) {
      for (final fmt in filter.formats) {
        final cleanFmt = fmt.toLowerCase().trim().replaceAll(RegExp(r'[^a-z0-9_]'), '');
        if (cleanFmt.isNotEmpty) {
          query.where((t) => CustomExpression<bool>(
                "CASE WHEN json_valid(vault_items.dynamic_data) = 1 THEN ("
                "json_extract(vault_items.dynamic_data, '\$.legalities.$cleanFmt') IN ('legal', 'restricted')"
                ") ELSE 0 END",
              ));
        }
      }
    }

    // 8. CMC (Mana Value) range pushdown
    if (filter.cmcRange.start > 0 || filter.cmcRange.end < 16) {
      final minCmc = filter.cmcRange.start;
      final maxCmc = filter.cmcRange.end;
      query.where((t) => CustomExpression<bool>(
            "CASE WHEN json_valid(vault_items.dynamic_data) = 1 THEN ("
            "CAST(json_extract(vault_items.dynamic_data, '\$.cmc') AS REAL) >= $minCmc AND "
            "CAST(json_extract(vault_items.dynamic_data, '\$.cmc') AS REAL) <= $maxCmc"
            ") ELSE 1 END",
          ));
    }

    // 9. Languages pushdown
    if (filter.languages.isNotEmpty) {
      final langCodes = filter.languages
          .map((l) => "'${l.toLowerCase().trim()}'")
          .join(',');
      query.where((t) => CustomExpression<bool>(
            "CASE WHEN json_valid(vault_items.dynamic_data) = 1 THEN ("
            "lower(json_extract(vault_items.dynamic_data, '\$.lang')) IN ($langCodes)"
            ") ELSE 1 END",
          ));
    }
  }

  /// Streams reactive aggregate totals for vault items scoped to collection and binder.
  Stream<VaultTotals> watchVaultTotals({
    String? collectionType,
    String? binderId,
  }) {
    final whereClauses = <String>['"quantity" > 0', '"is_deleted" = 0'];
    final variables = <Variable>[];

    if (collectionType != null) {
      final normalized = _normalizeCollectionType(collectionType);
      if (normalized != 'all') {
        whereClauses.add('"collection_type" = ?');
        variables.add(Variable.withString(normalized));
      }
    }

    if (binderId != null) {
      whereClauses.add('"primary_binder_id" = ?');
      variables.add(Variable.withString(binderId));
    } else {
      whereClauses.add('("primary_binder_id" IS NULL OR "primary_binder_id" != \'INBOX\')');
    }

    final whereSql = whereClauses.join(' AND ');
    final querySql = '''
      SELECT
        CAST(COALESCE(SUM("quantity"), 0) AS INTEGER) AS total_count,
        CAST(COUNT(*) AS INTEGER) AS unique_count,
        CAST(COALESCE(SUM("current_market_price" * "quantity"), 0.0) AS REAL) AS total_market_value,
        CAST(COALESCE(SUM(COALESCE("purchase_price", "acquired_price", 0.0) * "quantity"), 0.0) AS REAL) AS total_cost_basis
      FROM "vault_items"
      WHERE $whereSql;
    ''';

    return customSelect(
      querySql,
      variables: variables,
      readsFrom: {vaultItems},
    ).watchSingle().map((row) {
      final count = (row.data['total_count'] as num?)?.toInt() ?? 0;
      final unique = (row.data['unique_count'] as num?)?.toInt() ?? count;
      final marketVal =
          (row.data['total_market_value'] as num?)?.toDouble() ?? 0.0;
      final costBasis =
          (row.data['total_cost_basis'] as num?)?.toDouble() ?? 0.0;
      final delta = marketVal - costBasis;
      final pct = costBasis > 0 ? (delta / costBasis) * 100 : 0.0;

      return VaultTotals(
        totalCount: count,
        uniqueCount: unique,
        totalMarketValue: marketVal,
        totalCostBasis: costBasis,
        totalProfitLoss: delta,
        profitLossPercentage: pct,
      );
    });
  }

  /// One-shot query for aggregate totals for vault items scoped to collection and binder.
  Future<VaultTotals> getVaultTotals({
    String? collectionType,
    String? binderId,
  }) async {
    final whereClauses = <String>['"quantity" > 0', '"is_deleted" = 0'];
    final variables = <Variable>[];

    if (collectionType != null) {
      final normalized = _normalizeCollectionType(collectionType);
      if (normalized != 'all') {
        whereClauses.add('"collection_type" = ?');
        variables.add(Variable.withString(normalized));
      }
    }

    if (binderId != null) {
      whereClauses.add('"primary_binder_id" = ?');
      variables.add(Variable.withString(binderId));
    } else {
      whereClauses.add('("primary_binder_id" IS NULL OR "primary_binder_id" != \'INBOX\')');
    }

    final whereSql = whereClauses.join(' AND ');
    final querySql = '''
      SELECT
        CAST(COALESCE(SUM("quantity"), 0) AS INTEGER) AS total_count,
        CAST(COUNT(*) AS INTEGER) AS unique_count,
        CAST(COALESCE(SUM("current_market_price" * "quantity"), 0.0) AS REAL) AS total_market_value,
        CAST(COALESCE(SUM(COALESCE("purchase_price", "acquired_price", 0.0) * "quantity"), 0.0) AS REAL) AS total_cost_basis
      FROM "vault_items"
      WHERE $whereSql;
    ''';

    final row = await customSelect(
      querySql,
      variables: variables,
      readsFrom: {vaultItems},
    ).getSingle();

    final count = (row.data['total_count'] as num?)?.toInt() ?? 0;
    final unique = (row.data['unique_count'] as num?)?.toInt() ?? count;
    final marketVal =
        (row.data['total_market_value'] as num?)?.toDouble() ?? 0.0;
    final costBasis =
        (row.data['total_cost_basis'] as num?)?.toDouble() ?? 0.0;
    final delta = marketVal - costBasis;
    final pct = costBasis > 0 ? (delta / costBasis) * 100 : 0.0;

    return VaultTotals(
      totalCount: count,
      uniqueCount: unique,
      totalMarketValue: marketVal,
      totalCostBasis: costBasis,
      totalProfitLoss: delta,
      profitLossPercentage: pct,
    );
  }

  /// Returns the count of unowned reference MTG catalog cards in the database.
  /// Used by health checks to verify if MTG card dictionary has been hydrated.
  Future<int> getMtgCatalogCardCount() async {
    final countCol = vaultItems.id.count();
    final query = selectOnly(vaultItems)
      ..addColumns([countCol])
      ..where(
        vaultItems.collectionType.equals('mtg') &
            vaultItems.quantity.equals(0) &
            vaultItems.isDeleted.equals(false),
      );
    final row = await query.getSingleOrNull();
    return row?.read(countCol) ?? 0;
  }

  /// Queries vaultItems table with case-insensitive name or setOrSeries matching.
  /// Filters by normalized collection type if specified (unless 'all').
  /// Orders by name ASC and applies limit.
  /// When [groupByOracleId] is true, groups results by abstract oracle_id for catalog discovery,
  /// returning one representative printing per abstract card concept.
  Future<List<VaultItem>> searchCatalogCards(
    String query, {
    String? collectionType,
    int limit = 50,
    bool groupByOracleId = false,
  }) async {
    final normalized =
        collectionType != null ? _normalizeCollectionType(collectionType) : 'all';
    final trimmed = query.trim();
    final q = select(vaultItems);
    q.where((t) => t.isDeleted.equals(false));
    q.where((t) => t.dynamicData.like('%"layout":"art_series"%').not() &
                   t.dynamicData.like('%"layout": "art_series"%').not());

    if (normalized != 'all') {
      q.where((t) => t.collectionType.equals(normalized));
    }

    if (trimmed.isNotEmpty) {
      final term = '%$trimmed%';
      final lower = trimmed.toLowerCase();
      final isSld = lower == 'sld' || lower == 'secret lair' || lower == 'secret lair drop';

      q.where((t) {
        final base = t.name.like(term) |
            t.flavorName.like(term) |
            t.setOrSeries.like(term) |
            t.dynamicData.like(term);
        if (isSld) {
          return base |
              t.setOrSeries.like('%Secret Lair%') |
              t.dynamicData.like('%"set":"sld"%') |
              t.dynamicData.like('%"set_code":"sld"%') |
              t.dynamicData.like('%"set": "sld"%') |
              t.dynamicData.like('%"set_code": "sld"%');
        }
        return base;
      });
    }

    if (trimmed.isNotEmpty) {
      q.orderBy([
        (t) => OrderingTerm(
              expression: _buildSearchRankExpression(t, trimmed),
              mode: OrderingMode.asc,
            ),
        (t) => OrderingTerm(
              expression: t.name,
              mode: OrderingMode.asc,
            ),
      ]);
    } else {
      q.orderBy([(t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc)]);
    }

    if (groupByOracleId) {
      q.limit(limit * 3 > 100 ? limit * 3 : 100);
      final rawResults = await q.get();
      final seenKeys = <String>{};
      final deduplicated = <VaultItem>[];
      for (final item in rawResults) {
        String? oracleId;
        if (item.dynamicData.isNotEmpty) {
          try {
            final dyn = jsonDecode(item.dynamicData) as Map<String, dynamic>;
            oracleId = dyn['oracle_id']?.toString();
          } catch (_) {}
        }
        final key = (oracleId != null && oracleId.isNotEmpty)
            ? oracleId
            : item.name.toLowerCase().trim();
        if (seenKeys.add(key)) {
          deduplicated.add(item);
          if (deduplicated.length >= limit) break;
        }
      }
      return deduplicated;
    }

    q.limit(limit);

    return q.get();
  }

  /// Searches catalog items by their abstract Scryfall oracle_id.
  /// Returns all printings sharing that abstract oracle rules identity.
  Future<List<VaultItem>> searchByOracleId(
    String oracleId, {
    int limit = 50,
  }) async {
    final clean = oracleId.trim();
    if (clean.isEmpty) return [];

    final q = select(vaultItems);
    q.where((t) =>
        t.isDeleted.equals(false) &
        (t.dynamicData.like('%"oracle_id":"$clean"%') |
         t.dynamicData.like('%"oracle_id": "$clean"%') |
         t.dynamicData.like('%"oracle_id":$clean%')));
    q.orderBy([(t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc)]);
    q.limit(limit);
    return q.get();
  }

  /// Updates the physical finish metadata ('nonfoil', 'foil', 'etched') of a specific VaultItem.
  /// Enforces that physical inventory copies strictly specify their physical finish.
  Future<void> updateItemFinish(String id, String finish) async {
    final validFinishes = {'nonfoil', 'foil', 'etched'};
    final normalized = finish.toLowerCase().trim();
    if (!validFinishes.contains(normalized)) {
      throw ArgumentError('Invalid finish "$finish". Must be one of: nonfoil, foil, etched');
    }
    final existing =
        await (select(vaultItems)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (existing == null) {
      throw StateError('VaultItem with id "$id" not found.');
    }
    Map<String, dynamic> data = {};
    if (existing.dynamicData.isNotEmpty) {
      try {
        data = jsonDecode(existing.dynamicData) as Map<String, dynamic>;
      } catch (e) {
        debugPrint('[VaultDao.updateItemFinish] JSON decode error: $e');
      }
    }
    data['finish'] = normalized;
    data['treatment'] = normalized;
    final finishes = (data['finishes'] as List?)?.cast<String>() ?? [];
    if (!finishes.contains(normalized)) {
      finishes.add(normalized);
    }
    data['finishes'] = finishes;

    final now = DateTime.now();
    await (update(vaultItems)..where((t) => t.id.equals(id))).write(
      VaultItemsCompanion(
        dynamicData: Value(jsonEncode(data)),
        updatedAt: Value(now),
      ),
    );
    await _recordSync('vault_item', id, 'UPDATE', timestamp: now);
  }

  /// Bulk inserts or upserts catalog items into user inventory scoped to a destination binder.
  Future<void> bulkAddCatalogItems({
    required Map<String, int> stagedItems,
    String? targetBinderId,
  }) async {
    if (stagedItems.isEmpty) return;

    await transaction(() async {
      final now = DateTime.now();
      for (final entry in stagedItems.entries) {
        final cardId = entry.key;
        final quantityToAdd = entry.value;
        if (quantityToAdd <= 0) continue;

        final existing = await (select(vaultItems)
              ..where((t) => t.id.equals(cardId)))
            .getSingleOrNull();

        if (existing == null) continue;

        if (existing.quantity == 0) {
          final acquired = existing.acquiredPrice > 0
              ? existing.acquiredPrice
              : existing.currentMarketPrice;
          await (update(vaultItems)..where((t) => t.id.equals(cardId))).write(
            VaultItemsCompanion(
              quantity: Value(quantityToAdd),
              primaryBinderId: Value(targetBinderId),
              acquiredPrice: Value(acquired),
              acquiredDate: Value(now),
              lastPriceUpdate: Value(now),
              isDeleted: const Value(false),
              updatedAt: Value(now),
            ),
          );
        } else {
          await (update(vaultItems)..where((t) => t.id.equals(cardId))).write(
            VaultItemsCompanion(
              quantity: Value(existing.quantity + quantityToAdd),
              primaryBinderId: Value(targetBinderId ?? existing.primaryBinderId),
              lastPriceUpdate: Value(now),
              isDeleted: const Value(false),
              updatedAt: Value(now),
            ),
          );
        }
        await _recordSync('vault_item', cardId, 'UPDATE', timestamp: now);
      }
    });
  }

  /// Updates personal notes and deck history tags for a vault item without wiping existing dynamicData.
  Future<int> updateItemNotesAndDecks(
    String id, {
    String? personalNotes,
    List<String>? deckTags,
    String? communityNotes,
    List<String>? assignmentHistory,
  }) async {
    final existing =
        await (select(vaultItems)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (existing == null) return 0;

    Map<String, dynamic> data = {};
    if (existing.dynamicData.isNotEmpty) {
      try {
        data = jsonDecode(existing.dynamicData) as Map<String, dynamic>;
      } catch (error, stackTrace) {
        debugPrint('[VaultDao._syncItemDeckHistory] Failed decoding dynamicData for $id: $error\n$stackTrace');
      }
    }

    if (deckTags != null) {
      data['deck_history'] = deckTags;
    }
    if (assignmentHistory != null) {
      data['assignment_history'] = assignmentHistory;
    }
    if (communityNotes != null) {
      data['use_cases'] = communityNotes;
    }

    final now = DateTime.now();
    final count = await (update(vaultItems)..where((t) => t.id.equals(id))).write(
      VaultItemsCompanion(
        personalNotes: personalNotes != null
            ? Value(personalNotes)
            : const Value.absent(),
        dynamicData: Value(jsonEncode(data)),
        updatedAt: Value(now),
      ),
    );
    if (count > 0) {
      await _recordSync('vault_item', id, 'UPDATE', timestamp: now);
    }
    return count;
  }

  /// Updates existing card condition flags, acquired price, variant art/series,
  /// tags, and notes with immediate Drift reactive invalidation.
  Future<int> updateItemCardDetails({
    required String id,
    double? acquiredPrice,
    double? purchasePrice,
    DateTime? acquiredDate,
    DateTime? dateObtained,
    int? binderPage,
    String? binderSlot,
    String? notes,
    String? personalNotes,
    String? protectionStatus,
    String? condition,
    bool? isGraded,
    bool? isAltered,
    bool? isMisprint,
    bool? isSigned,
    String? name,
    String? flavorName,
    String? setOrSeries,
    String? imageUrl,
    double? currentMarketPrice,
    List<String>? tags,
  }) async {
    final existing =
        await (select(vaultItems)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (existing == null) return 0;

    Map<String, dynamic> data = {};
    if (existing.dynamicData.isNotEmpty) {
      try {
        data = jsonDecode(existing.dynamicData) as Map<String, dynamic>;
      } catch (error, stackTrace) {
        debugPrint('[VaultDao.updateItemCardDetails] Failed decoding dynamicData for $id: $error\n$stackTrace');
      }
    }

    if (tags != null) {
      data['tags'] = tags;
    }

    final effectivePrice = purchasePrice ?? acquiredPrice;
    final effectiveDate = dateObtained ?? acquiredDate;
    final effectiveNotes = notes ?? personalNotes;
    final now = DateTime.now();

    final result = await (update(vaultItems)..where((t) => t.id.equals(id))).write(
      VaultItemsCompanion(
        acquiredPrice: effectivePrice != null
            ? Value(effectivePrice)
            : const Value.absent(),
        purchasePrice: effectivePrice != null
            ? Value(effectivePrice)
            : const Value.absent(),
        acquiredDate: effectiveDate != null
            ? Value(effectiveDate)
            : const Value.absent(),
        dateObtained: effectiveDate != null
            ? Value(effectiveDate)
            : const Value.absent(),
        personalNotes: effectiveNotes != null
            ? Value(effectiveNotes)
            : const Value.absent(),
        notes: effectiveNotes != null
            ? Value(effectiveNotes)
            : const Value.absent(),
        binderPage:
            binderPage != null ? Value(binderPage) : const Value.absent(),
        binderSlot:
            binderSlot != null ? Value(binderSlot) : const Value.absent(),
        protectionStatus: protectionStatus != null
            ? Value(protectionStatus)
            : const Value.absent(),
        condition: condition != null ? Value(condition) : const Value.absent(),
        isGraded: isGraded != null ? Value(isGraded) : const Value.absent(),
        isAltered: isAltered != null ? Value(isAltered) : const Value.absent(),
        isMisprint:
            isMisprint != null ? Value(isMisprint) : const Value.absent(),
        isSigned: isSigned != null ? Value(isSigned) : const Value.absent(),
        name: name != null ? Value(name) : const Value.absent(),
        flavorName: flavorName != null
            ? Value(flavorName)
            : const Value.absent(),
        setOrSeries: setOrSeries != null
            ? Value(setOrSeries)
            : const Value.absent(),
        imageUrl: imageUrl != null ? Value(imageUrl) : const Value.absent(),
        currentMarketPrice: currentMarketPrice != null
            ? Value(currentMarketPrice)
            : const Value.absent(),
        dynamicData: Value(jsonEncode(data)),
        lastPriceUpdate: Value(now),
        updatedAt: Value(now),
      ),
    );
    if (result > 0) {
      await _recordSync('vault_item', id, 'UPDATE', timestamp: now);
    }
    return result;
  }


  /// Retrieves a single vault item by ID.
  Future<VaultItem?> getItemById(String id, {bool includeDeleted = false}) {
    final query = select(vaultItems)..where((t) => t.id.equals(id));
    if (!includeDeleted) {
      query.where((t) => t.isDeleted.equals(false));
    }
    return query.getSingleOrNull();
  }

  /// Watches a single vault item by ID reactively.
  Stream<VaultItem?> watchItemById(String id, {bool includeDeleted = false}) {
    final query = select(vaultItems)..where((t) => t.id.equals(id));
    if (!includeDeleted) {
      query.where((t) => t.isDeleted.equals(false));
    }
    return query.watchSingleOrNull();
  }

  /// Normalizes display collection titles to internal collection types.
  String _normalizeCollectionType(String type) {
    final lower = type.toLowerCase().trim();
    if (lower == 'all collections' ||
        lower == 'all' ||
        lower == 'my vault' ||
        lower == 'all vault') {
      return 'all';
    }
    if (lower.contains('magic') || lower == 'mtg') {
      return 'mtg';
    }
    if (lower.contains('pokémon') || lower.contains('pokemon')) {
      return 'pokemon';
    }
    if (lower.contains('comic')) {
      return 'comic';
    }
    if (lower.contains('sport')) {
      return 'sports_card';
    }
    return lower;
  }

  /// Seeds the starter binder and 4 hyper-detailed mock records.
  Future<void> seedDatabase() async {
    final now = DateTime.now();

    // 1. Ensure starter binder exists if vaultBinders is empty
    final existingBinders = await (select(vaultBinders)
          ..where((t) => t.isDeleted.equals(false))
          ..limit(1))
        .get();
    if (existingBinders.isEmpty) {
      await into(vaultBinders).insert(
        VaultBindersCompanion.insert(
          id: 'binder-mtg-personal',
          name: 'Personal Collection',
          collectionType: 'mtg',
          createdAt: now,
          isDeleted: const Value(false),
          updatedAt: Value(now),
        ),
        mode: InsertMode.insertOrReplace,
      );
    }

    // 2. Ensure starter items exist if vaultItems has no owned items
    final existing = await (select(vaultItems)
          ..where((t) => t.quantity.isBiggerThanValue(0) & t.isDeleted.equals(false))
          ..limit(1))
        .get();
    if (existing.isEmpty) {
      await batch((b) {
        b.insertAll(vaultItems, [
          // 1. MTG: The One Ring
          VaultItemsCompanion.insert(
            id: 'item-mtg-one-ring',
            collectionType: 'mtg',
            primaryBinderId: const Value('binder-mtg-personal'),
            name: 'The One Ring (Serialized #007/100)',
            setOrSeries: 'The Lord of the Rings: Tales of Middle-earth',
            imageUrl:
                'https://cards.scryfall.io/large/front/d/5/d5806e68-1054-458e-866d-1f2470f682b2.jpg?1790212038',
            acquiredPrice: 15.00,
            acquiredDate: now,
            quantity: const Value(1),
            condition: 'NM',
            isGraded: const Value(false),
            personalNotes: const Value(
                'Pulled from collector booster at TBS Comics. Serialized #007/100.'),
            dateObtained: Value(now),
            purchasePrice: const Value(15.00),
            protectionStatus: const Value('Sleeved'),
            isDeleted: const Value(false),
            updatedAt: Value(now),
            currentMarketPrice: 45.50,
            lastPriceUpdate: now,
            dynamicData: jsonEncode({
              'scryfall_id': 'd5806e68-1054-458e-866d-1f2470f682b2',
              'id': 'd5806e68-1054-458e-866d-1f2470f682b2',
              'oracle_id': '3aa83ed2-f48b-4ce6-a614-2c54ddf50538',
              'mana': '{4}',
              'mana_cost': '{4}',
              'cmc': 4.0,
              'type': 'Legendary Artifact',
              'type_line': 'Legendary Artifact',
              'oracle_text':
                  'Indestructible\nAs The One Ring enters the battlefield, if you cast it, you gain protection from everything until your next turn.\nAt the beginning of your upkeep, you lose 1 life for each burden counter on The One Ring.\n{T}: Put a burden counter on The One Ring, then draw a card for each burden counter on The One Ring.',
              'keywords': ['Indestructible'],
              'rarity': 'mythic',
              'collector_number': '007',
              'set_code': 'ltr',
              'set': 'ltr',
              'artist': 'Tania Sanchez-Fortun',
              'flavor_text':
                  'One Ring to rule them all, One Ring to find them, One Ring to bring them all and in the darkness bind them.',
              'image_uris': {
                'small':
                    'https://cards.scryfall.io/small/front/d/5/d5806e68-1054-458e-866d-1f2470f682b2.jpg?1790212038',
                'normal':
                    'https://cards.scryfall.io/normal/front/d/5/d5806e68-1054-458e-866d-1f2470f682b2.jpg?1790212038',
                'large':
                    'https://cards.scryfall.io/large/front/d/5/d5806e68-1054-458e-866d-1f2470f682b2.jpg?1790212038',
                'art_crop':
                    'https://cards.scryfall.io/art_crop/front/d/5/d5806e68-1054-458e-866d-1f2470f682b2.jpg?1790212038',
              },
              'finishes': ['nonfoil', 'foil'],
              'finish': 'foil',
              'rulings':
                  "Protection from everything means that you can't be targeted by anything, damaged by anything, enchanted/equipped by anything, or blocked by anything.",
              'legalities': {
                'standard': 'not_legal',
                'modern': 'legal',
                'commander': 'legal',
                'legacy': 'legal',
                'vintage': 'restricted',
              },
              'scryfall_uri': 'https://scryfall.com/card/ltr/246/the-one-ring',
            }),
          ),

          // 2. MTG: Sol Ring
          VaultItemsCompanion.insert(
            id: 'item-mtg-sol-ring',
            collectionType: 'mtg',
            primaryBinderId: const Value('binder-mtg-personal'),
            name: 'Sol Ring (Retro Artifact)',
            setOrSeries: 'Commander Masters',
            imageUrl:
                'https://cards.scryfall.io/large/front/a/a/aa626895-d166-4a49-8c67-6228383f98c8.jpg',
            acquiredPrice: 2.00,
            acquiredDate: now.subtract(const Duration(days: 30)),
            quantity: const Value(1),
            condition: 'NM',
            isGraded: const Value(false),
            personalNotes:
                const Value('Essential staple mana rock for Commander format.'),
            dateObtained: Value(now.subtract(const Duration(days: 30))),
            purchasePrice: const Value(2.00),
            protectionStatus: const Value('Sleeved'),
            isDeleted: const Value(false),
            updatedAt: Value(now),
            currentMarketPrice: 2.50,
            lastPriceUpdate: now,
            dynamicData: jsonEncode({
              'scryfall_id': 'aa626895-d166-4a49-8c67-6228383f98c8',
              'id': 'aa626895-d166-4a49-8c67-6228383f98c8',
              'oracle_id': '1970ae46-d249-4113-98fe-c020d5885c34',
              'mana': '{1}',
              'mana_cost': '{1}',
              'cmc': 1.0,
              'type': 'Artifact',
              'type_line': 'Artifact',
              'oracle_text': '{T}: Add {C}{C}.',
              'rarity': 'uncommon',
              'collector_number': '405',
              'set_code': 'cmm',
              'set': 'cmm',
              'artist': 'Mark Tedin',
              'image_uris': {
                'small':
                    'https://cards.scryfall.io/small/front/a/a/aa626895-d166-4a49-8c67-6228383f98c8.jpg',
                'normal':
                    'https://cards.scryfall.io/normal/front/a/a/aa626895-d166-4a49-8c67-6228383f98c8.jpg',
                'large':
                    'https://cards.scryfall.io/large/front/a/a/aa626895-d166-4a49-8c67-6228383f98c8.jpg',
                'art_crop':
                    'https://cards.scryfall.io/art_crop/front/a/a/aa626895-d166-4a49-8c67-6228383f98c8.jpg',
              },
              'finishes': ['nonfoil', 'foil'],
              'finish': 'nonfoil',
              'legalities': {
                'commander': 'legal',
                'vintage': 'restricted',
                'legacy': 'banned',
              },
            }),
          ),

          // 3. MTG: Black Lotus
          VaultItemsCompanion.insert(
            id: 'item-mtg-black-lotus',
            collectionType: 'mtg',
            primaryBinderId: const Value('binder-mtg-personal'),
            name: 'Black Lotus',
            setOrSeries: 'Limited Edition Beta',
            imageUrl:
                'https://cards.scryfall.io/large/front/b/d/bd8fa327-dd41-4737-8f19-2cf5eb1f7cdd.jpg',
            acquiredPrice: 12000.00,
            acquiredDate: now.subtract(const Duration(days: 300)),
            quantity: const Value(1),
            condition: 'LP',
            isGraded: const Value(true),
            personalNotes:
                const Value('Power Nine centerpiece of vintage collection.'),
            dateObtained: Value(now.subtract(const Duration(days: 300))),
            purchasePrice: const Value(12000.00),
            protectionStatus: const Value('Graded Slab'),
            isDeleted: const Value(false),
            updatedAt: Value(now),
            currentMarketPrice: 25000.00,
            lastPriceUpdate: now,
            dynamicData: jsonEncode({
              'scryfall_id': 'bd8fa327-dd41-4737-8f19-2cf5eb1f7cdd',
              'id': 'bd8fa327-dd41-4737-8f19-2cf5eb1f7cdd',
              'oracle_id': '4c311684-2830-4e3f-a63e-b873f1d84814',
              'mana': '{0}',
              'mana_cost': '{0}',
              'cmc': 0.0,
              'type': 'Artifact',
              'type_line': 'Artifact',
              'oracle_text':
                  '{T}, Sacrifice Black Lotus: Add three mana of any one color.',
              'rarity': 'rare',
              'collector_number': '232',
              'set_code': 'leb',
              'set': 'leb',
              'artist': 'Christopher Rush',
              'image_uris': {
                'small':
                    'https://cards.scryfall.io/small/front/b/d/bd8fa327-dd41-4737-8f19-2cf5eb1f7cdd.jpg',
                'normal':
                    'https://cards.scryfall.io/normal/front/b/d/bd8fa327-dd41-4737-8f19-2cf5eb1f7cdd.jpg',
                'large':
                    'https://cards.scryfall.io/large/front/b/d/bd8fa327-dd41-4737-8f19-2cf5eb1f7cdd.jpg',
                'art_crop':
                    'https://cards.scryfall.io/art_crop/front/b/d/bd8fa327-dd41-4737-8f19-2cf5eb1f7cdd.jpg',
              },
              'finishes': ['nonfoil'],
              'finish': 'nonfoil',
              'legalities': {
                'vintage': 'restricted',
                'commander': 'banned',
                'legacy': 'banned',
              },
            }),
          ),

          // 4. MTG: Lightning Bolt
          VaultItemsCompanion.insert(
            id: 'item-mtg-lightning-bolt',
            collectionType: 'mtg',
            primaryBinderId: const Value('binder-mtg-personal'),
            name: 'Lightning Bolt',
            setOrSeries: 'Masters 25',
            imageUrl:
                'https://cards.scryfall.io/large/front/e/3/e3285e6b-3e79-4d7c-bf96-d920f973b122.jpg',
            acquiredPrice: 2.50,
            acquiredDate: now.subtract(const Duration(days: 20)),
            quantity: const Value(4),
            condition: 'NM',
            isGraded: const Value(false),
            personalNotes: const Value('Playset for burn/aggro builds.'),
            dateObtained: Value(now.subtract(const Duration(days: 20))),
            purchasePrice: const Value(2.50),
            protectionStatus: const Value('Sleeved'),
            isDeleted: const Value(false),
            updatedAt: Value(now),
            currentMarketPrice: 3.50,
            lastPriceUpdate: now,
            dynamicData: jsonEncode({
              'scryfall_id': 'e3285e6b-3e79-4d7c-bf96-d920f973b122',
              'id': 'e3285e6b-3e79-4d7c-bf96-d920f973b122',
              'oracle_id': '9f583595-6b80-4cf8-a968-3e4b77f98501',
              'mana': '{R}',
              'mana_cost': '{R}',
              'cmc': 1.0,
              'type': 'Instant',
              'type_line': 'Instant',
              'oracle_text': 'Lightning Bolt deals 3 damage to any target.',
              'colors': ['R'],
              'rarity': 'uncommon',
              'collector_number': '141',
              'set_code': 'a25',
              'set': 'a25',
              'artist': 'Christopher Moeller',
              'image_uris': {
                'small':
                    'https://cards.scryfall.io/small/front/e/3/e3285e6b-3e79-4d7c-bf96-d920f973b122.jpg',
                'normal':
                    'https://cards.scryfall.io/normal/front/e/3/e3285e6b-3e79-4d7c-bf96-d920f973b122.jpg',
                'large':
                    'https://cards.scryfall.io/large/front/e/3/e3285e6b-3e79-4d7c-bf96-d920f973b122.jpg',
                'art_crop':
                    'https://cards.scryfall.io/art_crop/front/e/3/e3285e6b-3e79-4d7c-bf96-d920f973b122.jpg',
              },
              'finishes': ['nonfoil', 'foil'],
              'finish': 'foil',
              'legalities': {
                'modern': 'legal',
                'commander': 'legal',
                'legacy': 'legal',
                'pauper': 'legal',
                'vintage': 'legal',
              },
            }),
          ),

          // 5. Pokémon: Charizard ex
          VaultItemsCompanion.insert(
            id: 'item-pokemon-charizard',
            collectionType: 'pokemon',
            name: 'Charizard ex',
            setOrSeries: 'Scarlet & Violet: 151',
            imageUrl:
                'https://images.unsplash.com/photo-1613771404784-3a5686aa2be3?auto=format&fit=crop&w=400&q=80',
            acquiredPrice: 4.50,
            acquiredDate: now.subtract(const Duration(days: 60)),
            quantity: const Value(1),
            condition: 'LP',
            isGraded: const Value(false),
            personalNotes: const Value(
                'Minor corner wear on rear. Stored in double sleeve.'),
            dateObtained: Value(now.subtract(const Duration(days: 60))),
            purchasePrice: const Value(4.50),
            protectionStatus: const Value('Sleeved'),
            isDeleted: const Value(false),
            updatedAt: Value(now),
            currentMarketPrice: 3.25,
            lastPriceUpdate: now,
            dynamicData: '{"hp": 120, "stage": "Basic"}',
          ),

          // 6. Comic Book: Ultimate Fallout #4
          VaultItemsCompanion.insert(
            id: 'item-comic-fallout-4',
            collectionType: 'comic',
            name: 'Ultimate Fallout #4 (1st Miles Morales)',
            setOrSeries: 'Marvel Comics • 1st Print 2011',
            imageUrl:
                'https://images.unsplash.com/photo-1569003339405-ea396a5a8a90?auto=format&fit=crop&w=400&q=80',
            acquiredPrice: 150.00,
            acquiredDate: now.subtract(const Duration(days: 180)),
            quantity: const Value(1),
            condition: 'CGC 9.8',
            isGraded: const Value(true),
            personalNotes: const Value(
                'Graded CGC 9.8 with pristine white pages. Holy grail issue.'),
            dateObtained: Value(now.subtract(const Duration(days: 180))),
            purchasePrice: const Value(150.00),
            protectionStatus: const Value('Graded Slab'),
            isDeleted: const Value(false),
            updatedAt: Value(now),
            currentMarketPrice: 210.00,
            lastPriceUpdate: now,
            dynamicData: '{"issue": 1, "publisher": "Marvel"}',
          ),

          // 7. Sports Card: T.J. Watt Prizm Silver Rookie
          VaultItemsCompanion.insert(
            id: 'item-sports-watt-rookie',
            collectionType: 'sports_card',
            name: 'T.J. Watt Prizm Silver Rookie',
            setOrSeries: '2017 Panini Prizm Football',
            imageUrl:
                'https://images.unsplash.com/photo-1587280501635-68a0e82cd5ff?auto=format&fit=crop&w=400&q=80',
            acquiredPrice: 20.00,
            acquiredDate: now.subtract(const Duration(days: 365)),
            quantity: const Value(1),
            condition: 'PSA 10',
            isGraded: const Value(true),
            personalNotes:
                const Value('Gem Mint 10 rookie card. True investment hold.'),
            dateObtained: Value(now.subtract(const Duration(days: 365))),
            purchasePrice: const Value(20.00),
            protectionStatus: const Value('Graded Slab'),
            isDeleted: const Value(false),
            updatedAt: Value(now),
            currentMarketPrice: 180.00,
            lastPriceUpdate: now,
            dynamicData:
                '{"sport": "Football", "team": "Steelers", "is_rookie": true}',
          ),
        ], mode: InsertMode.insertOrReplace);
      });
    }

    // 3. Ensure starter MTG catalog reference cards (quantity == 0) exist
    final existingCatalog = await (select(vaultItems)
          ..where((t) => t.quantity.equals(0) & t.isDeleted.equals(false))
          ..limit(1))
        .get();
    if (existingCatalog.isEmpty) {
      await batch((b) {
        b.insertAll(vaultItems, [
          // Catalog Reference Card 1: Mox Diamond
          VaultItemsCompanion.insert(
            id: 'item-catalog-mox-diamond',
            collectionType: 'mtg',
            name: 'Mox Diamond',
            setOrSeries: 'Stronghold',
            imageUrl:
                'https://cards.scryfall.io/large/front/b/f/bf9fec3e-5aa8-4188-bad5-aacbe0666282.jpg',
            acquiredPrice: 0.0,
            acquiredDate: now,
            quantity: const Value(0),
            condition: 'NM',
            isGraded: const Value(false),
            protectionStatus: const Value('Catalog Reference'),
            isDeleted: const Value(false),
            updatedAt: Value(now),
            currentMarketPrice: 650.00,
            lastPriceUpdate: now,
            dynamicData: jsonEncode({
              'scryfall_id': 'bf9fec3e-5aa8-4188-bad5-aacbe0666282',
              'id': 'bf9fec3e-5aa8-4188-bad5-aacbe0666282',
              'oracle_id': 'f0535e6c-e1a5-4eb4-b9b5-c0525d8b7625',
              'mana': '{0}',
              'mana_cost': '{0}',
              'cmc': 0.0,
              'type': 'Artifact',
              'type_line': 'Artifact',
              'oracle_text':
                  'You may discard a land card rather than pay this spell’s mana cost.\nIf Mox Diamond would enter the battlefield, you may discard a land card instead. If you do, put Mox Diamond onto the battlefield. If you don’t, put it into its owner’s graveyard.\n{T}: Add one mana of any color.',
              'rarity': 'rare',
              'collector_number': '138',
              'set_code': 'sth',
              'set': 'sth',
              'artist': 'Dan Frazier',
              'image_uris': {
                'small':
                    'https://cards.scryfall.io/small/front/b/f/bf9fec3e-5aa8-4188-bad5-aacbe0666282.jpg',
                'normal':
                    'https://cards.scryfall.io/normal/front/b/f/bf9fec3e-5aa8-4188-bad5-aacbe0666282.jpg',
                'large':
                    'https://cards.scryfall.io/large/front/b/f/bf9fec3e-5aa8-4188-bad5-aacbe0666282.jpg',
                'art_crop':
                    'https://cards.scryfall.io/art_crop/front/b/f/bf9fec3e-5aa8-4188-bad5-aacbe0666282.jpg',
              },
              'finishes': ['nonfoil'],
              'finish': 'nonfoil',
              'legalities': {
                'legacy': 'legal',
                'commander': 'legal',
                'vintage': 'restricted',
              },
            }),
          ),

          // Catalog Reference Card 2: Mana Crypt
          VaultItemsCompanion.insert(
            id: 'item-catalog-mana-crypt',
            collectionType: 'mtg',
            name: 'Mana Crypt',
            setOrSeries: 'Double Masters',
            imageUrl:
                'https://cards.scryfall.io/large/front/4/d/4d960186-4559-4af0-bd22-63baa15f8939.jpg',
            acquiredPrice: 0.0,
            acquiredDate: now,
            quantity: const Value(0),
            condition: 'NM',
            isGraded: const Value(false),
            protectionStatus: const Value('Catalog Reference'),
            isDeleted: const Value(false),
            updatedAt: Value(now),
            currentMarketPrice: 180.00,
            lastPriceUpdate: now,
            dynamicData: jsonEncode({
              'scryfall_id': '4d960186-4559-4af0-bd22-63baa15f8939',
              'id': '4d960186-4559-4af0-bd22-63baa15f8939',
              'oracle_id': 'b5dfba73-5593-4b68-b7eb-d1cf57adab4b',
              'mana': '{0}',
              'mana_cost': '{0}',
              'cmc': 0.0,
              'type': 'Artifact',
              'type_line': 'Artifact',
              'oracle_text':
                  'At the beginning of your upkeep, flip a coin. If you lose the flip, Mana Crypt deals 3 damage to you.\n{T}: Add {C}{C}.',
              'rarity': 'mythic',
              'collector_number': '270',
              'set_code': '2xm',
              'set': '2xm',
              'artist': 'Mark Tedin',
              'image_uris': {
                'small':
                    'https://cards.scryfall.io/small/front/4/d/4d960186-4559-4af0-bd22-63baa15f8939.jpg',
                'normal':
                    'https://cards.scryfall.io/normal/front/4/d/4d960186-4559-4af0-bd22-63baa15f8939.jpg',
                'large':
                    'https://cards.scryfall.io/large/front/4/d/4d960186-4559-4af0-bd22-63baa15f8939.jpg',
                'art_crop':
                    'https://cards.scryfall.io/art_crop/front/4/d/4d960186-4559-4af0-bd22-63baa15f8939.jpg',
              },
              'finishes': ['nonfoil', 'foil'],
              'finish': 'nonfoil',
              'legalities': {
                'vintage': 'restricted',
                'commander': 'banned',
                'legacy': 'banned',
              },
            }),
          ),

          // Catalog Reference Card 3: Force of Will
          VaultItemsCompanion.insert(
            id: 'item-catalog-force-of-will',
            collectionType: 'mtg',
            name: 'Force of Will',
            setOrSeries: 'Alliances',
            imageUrl:
                'https://cards.scryfall.io/large/front/e/b/ebc01ab4-d88a-4625-be44-a4c45e3c2363.jpg',
            acquiredPrice: 0.0,
            acquiredDate: now,
            quantity: const Value(0),
            condition: 'NM',
            isGraded: const Value(false),
            protectionStatus: const Value('Catalog Reference'),
            isDeleted: const Value(false),
            updatedAt: Value(now),
            currentMarketPrice: 75.00,
            lastPriceUpdate: now,
            dynamicData: jsonEncode({
              'scryfall_id': 'ebc01ab4-d88a-4625-be44-a4c45e3c2363',
              'id': 'ebc01ab4-d88a-4625-be44-a4c45e3c2363',
              'oracle_id': 'd69ec7ea-626e-4f36-96b6-d2427a1470ce',
              'mana': '{3}{U}{U}',
              'mana_cost': '{3}{U}{U}',
              'cmc': 5.0,
              'type': 'Instant',
              'type_line': 'Instant',
              'oracle_text':
                  'You may pay 1 life and exile a blue card from your hand rather than pay this spell’s mana cost.\nCounter target spell.',
              'colors': ['U'],
              'rarity': 'uncommon',
              'collector_number': '38',
              'set_code': 'all',
              'set': 'all',
              'artist': 'Terese Nielsen',
              'image_uris': {
                'small':
                    'https://cards.scryfall.io/small/front/e/b/ebc01ab4-d88a-4625-be44-a4c45e3c2363.jpg',
                'normal':
                    'https://cards.scryfall.io/normal/front/e/b/ebc01ab4-d88a-4625-be44-a4c45e3c2363.jpg',
                'large':
                    'https://cards.scryfall.io/large/front/e/b/ebc01ab4-d88a-4625-be44-a4c45e3c2363.jpg',
                'art_crop':
                    'https://cards.scryfall.io/art_crop/front/e/b/ebc01ab4-d88a-4625-be44-a4c45e3c2363.jpg',
              },
              'finishes': ['nonfoil'],
              'finish': 'nonfoil',
              'legalities': {
                'legacy': 'legal',
                'commander': 'legal',
                'vintage': 'restricted',
              },
            }),
          ),

          // Catalog Reference Card 4: Demonic Tutor
          VaultItemsCompanion.insert(
            id: 'item-catalog-demonic-tutor',
            collectionType: 'mtg',
            name: 'Demonic Tutor',
            setOrSeries: 'Revised Edition',
            imageUrl:
                'https://cards.scryfall.io/large/front/3/b/3bdbc231-5316-4abd-9d8d-d87cff2c9847.jpg',
            acquiredPrice: 0.0,
            acquiredDate: now,
            quantity: const Value(0),
            condition: 'NM',
            isGraded: const Value(false),
            protectionStatus: const Value('Catalog Reference'),
            isDeleted: const Value(false),
            updatedAt: Value(now),
            currentMarketPrice: 42.00,
            lastPriceUpdate: now,
            dynamicData: jsonEncode({
              'scryfall_id': '3bdbc231-5316-4abd-9d8d-d87cff2c9847',
              'id': '3bdbc231-5316-4abd-9d8d-d87cff2c9847',
              'oracle_id': '7b3e1572-c511-4809-b684-25e1bc48ff41',
              'mana': '{1}{B}',
              'mana_cost': '{1}{B}',
              'cmc': 2.0,
              'type': 'Sorcery',
              'type_line': 'Sorcery',
              'oracle_text':
                  'Search your library for a card, put that card into your hand, then shuffle.',
              'colors': ['B'],
              'rarity': 'uncommon',
              'collector_number': '105',
              'set_code': '3ed',
              'set': '3ed',
              'artist': 'Douglas Shuler',
              'image_uris': {
                'small':
                    'https://cards.scryfall.io/small/front/3/b/3bdbc231-5316-4abd-9d8d-d87cff2c9847.jpg',
                'normal':
                    'https://cards.scryfall.io/normal/front/3/b/3bdbc231-5316-4abd-9d8d-d87cff2c9847.jpg',
                'large':
                    'https://cards.scryfall.io/large/front/3/b/3bdbc231-5316-4abd-9d8d-d87cff2c9847.jpg',
                'art_crop':
                    'https://cards.scryfall.io/art_crop/front/3/b/3bdbc231-5316-4abd-9d8d-d87cff2c9847.jpg',
              },
              'finishes': ['nonfoil'],
              'finish': 'nonfoil',
              'legalities': {
                'commander': 'legal',
                'vintage': 'restricted',
                'legacy': 'banned',
              },
            }),
          ),
        ], mode: InsertMode.insertOrReplace);
      });
    }

    // 3. Ensure starter decks exist if decks table is empty
    final existingDecks = await (select(decks)
          ..where((t) => t.isDeleted.equals(false))
          ..limit(1))
        .get();
    if (existingDecks.isEmpty) {
      // 3.1 Canonical MTG Commander Deck: Edgar Markov Aristocrats
      await into(decks).insert(
        DecksCompanion.insert(
          id: 'deck-edgar-markov',
          name: 'Edgar Markov Aristocrats',
          format: 'MTG Commander',
          tcgDomain: const Value('mtg'),
          isRegistered: const Value(true),
          isCompetitive: const Value(false),
          isAssembled: const Value(true),
          coverItemId: const Value('edgar-markov'),
          coverCropRect: const Value(null),
          createdAt: now,
          isDeleted: const Value(false),
          updatedAt: Value(now),
        ),
        mode: InsertMode.insertOrReplace,
      );

      await into(deckVersions).insert(
        DeckVersionsCompanion.insert(
          id: 'ver-edgar-3',
          deckId: 'deck-edgar-markov',
          versionNumber: 3,
          isActive: const Value(true),
          createdAt: now,
          isDeleted: const Value(false),
          updatedAt: Value(now),
        ),
        mode: InsertMode.insertOrReplace,
      );

      // Authentic Edgar Markov card in vault_items with direct Scryfall CDN art
      await into(vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'edgar-markov',
          collectionType: 'mtg',
          primaryBinderId: const Value('binder-mtg-personal'),
          name: 'Edgar Markov',
          setOrSeries: 'Commander 2017',
          imageUrl:
              'https://cards.scryfall.io/art_crop/front/8/d/8d94b8ec-ecda-43c8-a60e-1ba33e6a54a4.jpg',
          acquiredPrice: 0.0,
          acquiredDate: now.subtract(const Duration(days: 5)),
          quantity: const Value(1),
          condition: 'NM',
          isGraded: const Value(false),
          protectionStatus: const Value('Sleeved'),
          isDeleted: const Value(false),
          updatedAt: Value(now),
          currentMarketPrice: 85.00,
          lastPriceUpdate: now,
          dynamicData: jsonEncode({
            'id': '8d94b8ec-ecda-43c8-a60e-1ba33e6a54a4',
            'scryfall_id': '8d94b8ec-ecda-43c8-a60e-1ba33e6a54a4',
            'name': 'Edgar Markov',
            'mana_cost': '{3}{R}{W}{B}',
            'cmc': 6.0,
            'type_line': 'Legendary Creature — Vampire Knight',
            'oracle_text':
                'Eminence — As long as Edgar Markov is in the command zone or on the battlefield, whenever you cast another Vampire spell, create a 1/1 black Vampire creature token.\nFirst strike, haste\nWhenever Edgar Markov attacks, put a +1/+1 counter on each Vampire you control.',
            'power': '4',
            'toughness': '4',
            'colors': ['R', 'W', 'B'],
            'color_identity': ['R', 'W', 'B'],
            'image_uris': {
              'small':
                  'https://cards.scryfall.io/small/front/8/d/8d94b8ec-ecda-43c8-a60e-1ba33e6a54a4.jpg',
              'normal':
                  'https://cards.scryfall.io/normal/front/8/d/8d94b8ec-ecda-43c8-a60e-1ba33e6a54a4.jpg',
              'art_crop':
                  'https://cards.scryfall.io/art_crop/front/8/d/8d94b8ec-ecda-43c8-a60e-1ba33e6a54a4.jpg',
            },
          }),
        ),
        mode: InsertMode.insertOrReplace,
      );

      await into(deckVersionItems).insert(
        DeckVersionItemsCompanion.insert(
          id: 'dvi-edgar-markov',
          versionId: 'ver-edgar-3',
          vaultItemId: 'edgar-markov',
          quantity: const Value(1),
          boardZone: 'Commander',
          isProxy: const Value(false),
          isDeleted: const Value(false),
          updatedAt: Value(now),
        ),
        mode: InsertMode.insertOrReplace,
      );

      // 3.2 Canonical MTG Commander Deck: Yuriko, the Tiger's Shadow
      await into(decks).insert(
        DecksCompanion.insert(
          id: 'deck-yuriko',
          name: "Yuriko, the Tiger's Shadow",
          format: 'MTG Commander (cEDH)',
          tcgDomain: const Value('mtg'),
          isRegistered: const Value(false),
          isCompetitive: const Value(true),
          isAssembled: const Value(false),
          coverItemId: const Value('card-yuriko'),
          coverCropRect: const Value(null),
          createdAt: now.subtract(const Duration(seconds: 2)),
          isDeleted: const Value(false),
          updatedAt: Value(now),
        ),
        mode: InsertMode.insertOrReplace,
      );

      await into(deckVersions).insert(
        DeckVersionsCompanion.insert(
          id: 'ver-yuriko-1',
          deckId: 'deck-yuriko',
          versionNumber: 1,
          isActive: const Value(true),
          createdAt: now.subtract(const Duration(seconds: 2)),
          isDeleted: const Value(false),
          updatedAt: Value(now),
        ),
        mode: InsertMode.insertOrReplace,
      );

      await into(vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-yuriko',
          collectionType: 'mtg',
          name: "Yuriko, the Tiger's Shadow",
          setOrSeries: 'Commander 2018',
          imageUrl:
              'https://cards.scryfall.io/art_crop/front/3/6/364c9d33-660b-4125-a382-920f6667505f.jpg',
          acquiredPrice: 0.0,
          acquiredDate: now,
          quantity: const Value(0),
          condition: 'NM',
          isGraded: const Value(false),
          protectionStatus: const Value('Catalog Reference'),
          isDeleted: const Value(false),
          updatedAt: Value(now),
          currentMarketPrice: 2.50,
          lastPriceUpdate: now,
          dynamicData: jsonEncode({
            'id': '364c9d33-660b-4125-a382-920f6667505f',
            'scryfall_id': '364c9d33-660b-4125-a382-920f6667505f',
            'name': "Yuriko, the Tiger's Shadow",
            'mana_cost': '{1}{U}{B}',
            'cmc': 3.0,
            'type_line': 'Legendary Creature — Human Ninja',
            'oracle_text':
                'Commander ninjutsu {U}{B} ({U}{B}, Return an unblocked attacker you control to hand: Put this card onto the battlefield from your hand or the command zone tapped and attacking.)\nWhenever a Ninja you control deals combat damage to a player, reveal the top card of your library and put that card into your hand. Each opponent loses life equal to that card\'s mana value.',
            'power': '1',
            'toughness': '3',
            'colors': ['U', 'B'],
            'color_identity': ['U', 'B'],
            'image_uris': {
              'small':
                  'https://cards.scryfall.io/small/front/3/6/364c9d33-660b-4125-a382-920f6667505f.jpg',
              'normal':
                  'https://cards.scryfall.io/normal/front/3/6/364c9d33-660b-4125-a382-920f6667505f.jpg',
              'art_crop':
                  'https://cards.scryfall.io/art_crop/front/3/6/364c9d33-660b-4125-a382-920f6667505f.jpg',
            },
          }),
        ),
        mode: InsertMode.insertOrReplace,
      );

      await into(deckVersionItems).insert(
        DeckVersionItemsCompanion.insert(
          id: 'dvi-yuriko',
          versionId: 'ver-yuriko-1',
          vaultItemId: 'card-yuriko',
          quantity: const Value(1),
          boardZone: 'Commander',
          isProxy: const Value(false),
          isDeleted: const Value(false),
          updatedAt: Value(now),
        ),
        mode: InsertMode.insertOrReplace,
      );

      // 3.3 Canonical MTG Commander Deck: Yuriko, the Tiger's Shadow is already 3.2

      // 3.3 MTG Modern Deck: Modern Mono-Green Tron
      await into(decks).insert(
        DecksCompanion.insert(
          id: 'deck-tron',
          name: 'Modern Mono-Green Tron',
          format: 'MTG Modern',
          tcgDomain: const Value('mtg'),
          isRegistered: const Value(false),
          isCompetitive: const Value(false),
          isAssembled: const Value(false),
          coverItemId: const Value('card-tron'),
          coverCropRect: const Value(null),
          createdAt: now.subtract(const Duration(seconds: 5)),
          isDeleted: const Value(false),
          updatedAt: Value(now),
        ),
        mode: InsertMode.insertOrReplace,
      );

      await into(deckVersions).insert(
        DeckVersionsCompanion.insert(
          id: 'ver-tron-1',
          deckId: 'deck-tron',
          versionNumber: 1,
          isActive: const Value(true),
          createdAt: now.subtract(const Duration(seconds: 5)),
          isDeleted: const Value(false),
          updatedAt: Value(now),
        ),
        mode: InsertMode.insertOrReplace,
      );

      await into(vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-tron',
          collectionType: 'mtg',
          name: 'Karn Liberated',
          setOrSeries: 'New Phyrexia',
          imageUrl:
              'https://cards.scryfall.io/art_crop/front/4/b/4b0c6662-4dde-40a2-97e0-0318478c0367.jpg',
          acquiredPrice: 0.0,
          acquiredDate: now,
          quantity: const Value(0),
          condition: 'NM',
          isGraded: const Value(false),
          protectionStatus: const Value('Catalog Reference'),
          isDeleted: const Value(false),
          updatedAt: Value(now),
          currentMarketPrice: 20.00,
          lastPriceUpdate: now,
          dynamicData: jsonEncode({
            'id': '4b0c6662-4dde-40a2-97e0-0318478c0367',
            'scryfall_id': '4b0c6662-4dde-40a2-97e0-0318478c0367',
            'name': 'Karn Liberated',
            'mana_cost': '{7}',
            'cmc': 7.0,
            'type_line': 'Legendary Planeswalker — Karn',
            'oracle_text':
                '+4: Target player exiles a card from their hand.\n−3: Exile target permanent.\n−14: Restart the game, leaving in exile all non-Aura permanent cards exiled with Karn Liberated. Then put those cards onto the battlefield under your control.',
            'loyalty': '6',
            'colors': <String>[],
            'color_identity': <String>[],
            'image_uris': {
              'small':
                  'https://cards.scryfall.io/small/front/4/b/4b0c6662-4dde-40a2-97e0-0318478c0367.jpg',
              'normal':
                  'https://cards.scryfall.io/normal/front/4/b/4b0c6662-4dde-40a2-97e0-0318478c0367.jpg',
              'art_crop':
                  'https://cards.scryfall.io/art_crop/front/4/b/4b0c6662-4dde-40a2-97e0-0318478c0367.jpg',
            },
          }),
        ),
        mode: InsertMode.insertOrReplace,
      );

      await into(deckVersionItems).insert(
        DeckVersionItemsCompanion.insert(
          id: 'dvi-tron',
          versionId: 'ver-tron-1',
          vaultItemId: 'card-tron',
          quantity: const Value(1),
          boardZone: 'Mainboard',
          isProxy: const Value(false),
          isDeleted: const Value(false),
          updatedAt: Value(now),
        ),
        mode: InsertMode.insertOrReplace,
      );

      // 3.4 Pokemon Decks
      // 3.4.1 Charizard ex / Pidgeot ex (registered, competitive)
      await into(decks).insert(
        DecksCompanion.insert(
          id: 'deck-charizard-ex',
          name: 'Charizard ex / Pidgeot ex',
          format: 'Pokémon Standard',
          tcgDomain: const Value('pokemon'),
          isRegistered: const Value(true),
          isCompetitive: const Value(true),
          isAssembled: const Value(true),
          coverItemId: const Value('item-pokemon-charizard'),
          createdAt: now.subtract(const Duration(seconds: 1)),
          isDeleted: const Value(false),
          updatedAt: Value(now),
        ),
        mode: InsertMode.insertOrReplace,
      );

      await into(deckVersions).insert(
        DeckVersionsCompanion.insert(
          id: 'ver-charizard-1',
          deckId: 'deck-charizard-ex',
          versionNumber: 1,
          isActive: const Value(true),
          createdAt: now.subtract(const Duration(seconds: 1)),
          isDeleted: const Value(false),
          updatedAt: Value(now),
        ),
        mode: InsertMode.insertOrReplace,
      );

      await into(deckVersionItems).insert(
        DeckVersionItemsCompanion.insert(
          id: 'dvi-charizard-ex',
          versionId: 'ver-charizard-1',
          vaultItemId: 'item-pokemon-charizard',
          quantity: const Value(1),
          boardZone: 'Mainboard',
          isProxy: const Value(false),
          isDeleted: const Value(false),
          updatedAt: Value(now),
        ),
        mode: InsertMode.insertOrReplace,
      );

      // 3.4.2 Lost Zone Giratina VSTAR (registered, competitive)
      await into(decks).insert(
        DecksCompanion.insert(
          id: 'deck-lost-zone',
          name: 'Lost Zone Giratina VSTAR',
          format: 'Pokémon Standard',
          tcgDomain: const Value('pokemon'),
          isRegistered: const Value(true),
          isCompetitive: const Value(true),
          isAssembled: const Value(true),
          coverItemId: const Value('card-giratina'),
          createdAt: now.subtract(const Duration(seconds: 4)),
          isDeleted: const Value(false),
          updatedAt: Value(now),
        ),
        mode: InsertMode.insertOrReplace,
      );

      await into(deckVersions).insert(
        DeckVersionsCompanion.insert(
          id: 'ver-lost-zone-1',
          deckId: 'deck-lost-zone',
          versionNumber: 1,
          isActive: const Value(true),
          createdAt: now.subtract(const Duration(seconds: 4)),
          isDeleted: const Value(false),
          updatedAt: Value(now),
        ),
        mode: InsertMode.insertOrReplace,
      );

      await into(vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-giratina',
          collectionType: 'pokemon',
          name: 'Giratina VSTAR',
          setOrSeries: 'Lost Origin',
          imageUrl:
              'https://images.unsplash.com/photo-1613771404784-3a5686aa2be3?auto=format&fit=crop&w=400&q=80',
          acquiredPrice: 0.0,
          acquiredDate: now,
          quantity: const Value(0),
          condition: 'NM',
          isGraded: const Value(false),
          protectionStatus: const Value('Catalog Reference'),
          isDeleted: const Value(false),
          updatedAt: Value(now),
          currentMarketPrice: 15.00,
          lastPriceUpdate: now,
          dynamicData: '{"hp": 280, "stage": "VSTAR"}',
        ),
        mode: InsertMode.insertOrReplace,
      );

      await into(deckVersionItems).insert(
        DeckVersionItemsCompanion.insert(
          id: 'dvi-lost-zone',
          versionId: 'ver-lost-zone-1',
          vaultItemId: 'card-giratina',
          quantity: const Value(1),
          boardZone: 'Mainboard',
          isProxy: const Value(false),
          isDeleted: const Value(false),
          updatedAt: Value(now),
        ),
        mode: InsertMode.insertOrReplace,
      );

      // 3.5 Lorcana Deck: Ruby / Amethyst Bounce Control (draft/unregistered, casual)
      await into(decks).insert(
        DecksCompanion.insert(
          id: 'deck-lorcana',
          name: 'Ruby / Amethyst Bounce Control',
          format: 'Disney Lorcana Core',
          tcgDomain: const Value('lorcana'),
          isRegistered: const Value(false),
          isCompetitive: const Value(false),
          isAssembled: const Value(false),
          coverItemId: const Value('card-lorcana'),
          createdAt: now.subtract(const Duration(seconds: 3)),
          isDeleted: const Value(false),
          updatedAt: Value(now),
        ),
        mode: InsertMode.insertOrReplace,
      );

      await into(deckVersions).insert(
        DeckVersionsCompanion.insert(
          id: 'ver-lorcana-1',
          deckId: 'deck-lorcana',
          versionNumber: 1,
          isActive: const Value(true),
          createdAt: now.subtract(const Duration(seconds: 3)),
          isDeleted: const Value(false),
          updatedAt: Value(now),
        ),
        mode: InsertMode.insertOrReplace,
      );

      await into(vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-lorcana',
          collectionType: 'lorcana',
          name: 'Ruby / Amethyst Bounce Control',
          setOrSeries: 'The First Chapter',
          imageUrl:
              'https://images.unsplash.com/photo-1569003339405-ea396a5a8a90?auto=format&fit=crop&w=400&q=80',
          acquiredPrice: 0.0,
          acquiredDate: now,
          quantity: const Value(0),
          condition: 'NM',
          isGraded: const Value(false),
          protectionStatus: const Value('Catalog Reference'),
          isDeleted: const Value(false),
          updatedAt: Value(now),
          currentMarketPrice: 45.00,
          lastPriceUpdate: now,
          dynamicData: '{"ink": "Ruby/Amethyst"}',
        ),
        mode: InsertMode.insertOrReplace,
      );

      await into(deckVersionItems).insert(
        DeckVersionItemsCompanion.insert(
          id: 'dvi-lorcana',
          versionId: 'ver-lorcana-1',
          vaultItemId: 'card-lorcana',
          quantity: const Value(1),
          boardZone: 'Mainboard',
          isProxy: const Value(false),
          isDeleted: const Value(false),
          updatedAt: Value(now),
        ),
        mode: InsertMode.insertOrReplace,
      );
    }
  }

  /// Inserts a new vault item.
  Future<int> insertItem(VaultItemsCompanion item) async {
    final now = DateTime.now();
    final companion = item.copyWith(
      isDeleted: item.isDeleted.present ? item.isDeleted : const Value(false),
      updatedAt: item.updatedAt.present ? item.updatedAt : Value(now),
    );
    final count = await into(vaultItems).insert(companion);
    if (item.id.present) {
      await _recordSync('vault_item', item.id.value, 'INSERT', timestamp: now);
    }
    return count;
  }

  /// Inserts large lists of catalog/dictionary items in chunks of 1,000 using batch().
  /// Prevents database lockups, transaction limits, and OOM crashes.
  /// Uses Drift's true UPSERT (DoUpdate) to update catalog metadata while strictly
  /// preserving all user inventory fields (quantity, acquiredPrice, condition, personalNotes).
  Future<void> insertDictionaryChunked(
    List<VaultItemsCompanion> items, {
    void Function(int inserted, int total)? onProgress,
  }) async {
    const chunkSize = 1000;
    final total = items.length;
    var inserted = 0;

    for (var i = 0; i < total; i += chunkSize) {
      final end = (i + chunkSize < total) ? i + chunkSize : total;
      final chunk = items.sublist(i, end);

      await insertDictionaryBatch(chunk);

      inserted += chunk.length;
      onProgress?.call(inserted, total);
    }
  }

  /// Inserts a single chunk of dictionary items with true UPSERT conflict resolution.
  /// Upon an ID conflict, overwrites ONLY catalog-level fields (pricing, images, metadata)
  /// and explicitly preserves all user-level inventory fields.
  Future<void> insertDictionaryBatch(List<VaultItemsCompanion> chunk) async {
    await batch((b) {
      b.insertAll(
        vaultItems,
        chunk,
        onConflict: DoUpdate<$VaultItemsTable, VaultItem>.withExcluded(
          (old, excluded) => VaultItemsCompanion.custom(
            name: excluded.name,
            flavorName: excluded.flavorName,
            setOrSeries: excluded.setOrSeries,
            imageUrl: const CustomExpression<String>(
              'CASE WHEN excluded.image_url IS NOT NULL AND excluded.image_url != \'\' THEN excluded.image_url ELSE vault_items.image_url END',
            ),
            currentMarketPrice: const CustomExpression<double>(
              'CASE WHEN excluded.current_market_price > 0.0 THEN excluded.current_market_price ELSE vault_items.current_market_price END',
            ),
            lastPriceUpdate: const CustomExpression<DateTime>(
              'CASE WHEN excluded.current_market_price > 0.0 THEN excluded.last_price_update ELSE vault_items.last_price_update END',
            ),
            dynamicData: excluded.dynamicData,
            collectionType: excluded.collectionType,
          ),
          target: [vaultItems.id],
        ),
      );
    });
  }

  /// Soft deletes all items (used for test and bulk resets).
  Future<int> clearAllItems() async {
    final now = DateTime.now();
    final count = await (update(vaultItems)).write(
      VaultItemsCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(now),
      ),
    );
    await (update(vaultBinders)).write(
      VaultBindersCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(now),
      ),
    );
    await delete(decks).go();
    await delete(deckVersions).go();
    await delete(deckVersionItems).go();
    await _recordSync('vault_item', 'ALL', 'DELETE', timestamp: now);
    return count;
  }

  // ---------------------------------------------------------------------------
  // PHASE 3: VAULT BINDER METHODS
  // ---------------------------------------------------------------------------

  /// Streams all binders filtered by collection type (or all collections).
  Stream<List<VaultBinder>> watchBindersByCollection(String collectionType) {
    final normalized = _normalizeCollectionType(collectionType);
    final query = select(vaultBinders)..where((t) => t.isDeleted.equals(false));
    if (normalized != 'all') {
      query.where((t) => t.collectionType.equals(normalized));
    }
    query.orderBy([
      (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
    ]);
    return query.watch();
  }

  /// Creates a new custom Vault Binder with an active game context.
  Future<VaultBinder> createBinder({
    required String name,
    required String collectionType,
  }) async {
    final id = const Uuid().v4();
    final normalized = _normalizeCollectionType(collectionType);
    final now = DateTime.now();
    final binder = VaultBindersCompanion.insert(
      id: id,
      name: name.trim().isEmpty ? 'Untitled Binder' : name.trim(),
      collectionType: normalized == 'all' ? 'mtg' : normalized,
      createdAt: now,
      isDeleted: const Value(false),
      updatedAt: Value(now),
    );
    await into(vaultBinders).insert(binder);
    await _recordSync('binder', id, 'INSERT', timestamp: now);
    return (select(vaultBinders)..where((t) => t.id.equals(id))).getSingle();
  }

  /// Fetches a binder by its unique ID.
  Future<VaultBinder?> getBinderById(String binderId, {bool includeDeleted = false}) {
    final query = select(vaultBinders)..where((t) => t.id.equals(binderId));
    if (!includeDeleted) {
      query.where((t) => t.isDeleted.equals(false));
    }
    return query.getSingleOrNull();
  }

  /// Returns all active binders across collections.
  Future<List<VaultBinder>> getAllBinders() {
    return (select(vaultBinders)
          ..where((t) => t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
        .get();
  }

  final Map<String, String> _binderDescriptions = {};
  final Map<String, String> _binderCoverArts = {};

  /// Gets optional custom description for a binder.
  String? getBinderDescription(String binderId) => _binderDescriptions[binderId];

  /// Gets optional custom cover art URL for a binder.
  String? getBinderCoverArt(String binderId) => _binderCoverArts[binderId];

  /// Updates binder attributes (name, description, coverArtUrl) and logs to SyncQueue.
  Future<void> updateBinder(
    String binderId, {
    String? name,
    String? description,
    String? coverArtUrl,
  }) async {
    final now = DateTime.now();
    if (description != null) {
      _binderDescriptions[binderId] = description;
    }
    if (coverArtUrl != null) {
      _binderCoverArts[binderId] = coverArtUrl;
    }
    final companion = VaultBindersCompanion(
      name: name != null && name.trim().isNotEmpty ? Value(name.trim()) : const Value.absent(),
      updatedAt: Value(now),
    );
    await (update(vaultBinders)..where((t) => t.id.equals(binderId))).write(companion);
    await _recordSync('binder', binderId, 'UPDATE', timestamp: now);
  }

  /// Streams a map of binderId -> total items anchored inside that binder.
  Stream<Map<String, int>> watchBinderItemCounts() {
    final querySql = '''
      SELECT vi.primary_binder_id, CAST(COALESCE(SUM(vi.quantity), 0) AS INTEGER) AS total_count
      FROM vault_items vi
      LEFT JOIN vault_binders vb ON vb.id = vi.primary_binder_id
      WHERE vi.quantity > 0
        AND vi.is_deleted = 0
        AND vi.primary_binder_id IS NOT NULL
        AND vi.primary_binder_id != 'INBOX'
        AND (vb.is_deleted IS NULL OR vb.is_deleted = 0)
      GROUP BY vi.primary_binder_id
    ''';

    return customSelect(
      querySql,
      readsFrom: {vaultItems, vaultBinders},
    ).watch().map((rows) {
      final counts = <String, int>{};
      for (final r in rows) {
        final binderId = r.read<String>('primary_binder_id');
        final count = (r.data['total_count'] as num?)?.toInt() ?? 0;
        counts[binderId] = count;
      }
      return counts;
    });
  }

  /// Streams aggregate total card copies grouped by collection type.
  /// Keys include 'all', 'mtg', 'pokemon', 'comic', 'sports_card'.
  Stream<Map<String, int>> watchCollectionItemCounts() {
    final querySql = '''
      SELECT LOWER(TRIM(collection_type)) AS col_type, CAST(COALESCE(SUM(quantity), 0) AS INTEGER) AS total_count
      FROM vault_items
      WHERE quantity > 0
        AND is_deleted = 0
        AND (primary_binder_id IS NULL OR primary_binder_id != 'INBOX')
      GROUP BY LOWER(TRIM(collection_type))
    ''';

    return customSelect(
      querySql,
      readsFrom: {vaultItems},
    ).watch().map((rows) {
      final counts = <String, int>{
        'all': 0,
        'mtg': 0,
        'pokemon': 0,
        'comic': 0,
        'sports_card': 0,
      };

      for (final r in rows) {
        final col = r.read<String>('col_type');
        final count = (r.data['total_count'] as num?)?.toInt() ?? 0;
        counts[col] = count;
        counts['all'] = (counts['all'] ?? 0) + count;
      }
      return counts;
    });
  }

  /// Bulk assigns a list of item IDs to their physical home anchor (binder).
  Future<int> assignItemsToBinder(
      List<String> itemIds, String targetBinderId) async {
    final now = DateTime.now();
    final count = await (update(vaultItems)..where((t) => t.id.isIn(itemIds))).write(
      VaultItemsCompanion(
        primaryBinderId: Value(targetBinderId),
        updatedAt: Value(now),
      ),
    );
    for (final id in itemIds) {
      await _recordSync('vault_item', id, 'UPDATE', timestamp: now);
    }
    return count;
  }

  /// Alias for assignItemsToBinder
  Future<int> moveItemsToBinder(
          List<String> itemIds, String targetBinderId) =>
      assignItemsToBinder(itemIds, targetBinderId);

  /// Streams all owned cards anchored to a specific physical binder.
  Stream<List<VaultItem>> watchItemsByBinder(String binderId) {
    final query = select(vaultItems).join([
      leftOuterJoin(
          vaultBinders, vaultBinders.id.equalsExp(vaultItems.primaryBinderId)),
    ]);
    query.where(
      vaultItems.primaryBinderId.equals(binderId) &
          vaultItems.quantity.isBiggerThanValue(0) &
          vaultItems.isDeleted.equals(false) &
          (vaultBinders.isDeleted.isNull() |
              vaultBinders.isDeleted.equals(false)),
    );
    query.orderBy([
      OrderingTerm(
          expression: vaultItems.lastPriceUpdate, mode: OrderingMode.desc),
      OrderingTerm(expression: vaultItems.name, mode: OrderingMode.asc),
    ]);
    return query
        .watch()
        .map((rows) => rows.map((r) => r.readTable(vaultItems)).toList());
  }

  /// Returns all owned cards anchored to a specific physical binder.
  Future<List<VaultItem>> getItemsByBinder(String binderId) async {
    final query = select(vaultItems).join([
      leftOuterJoin(
          vaultBinders, vaultBinders.id.equalsExp(vaultItems.primaryBinderId)),
    ]);
    query.where(
      vaultItems.primaryBinderId.equals(binderId) &
          vaultItems.quantity.isBiggerThanValue(0) &
          vaultItems.isDeleted.equals(false) &
          (vaultBinders.isDeleted.isNull() |
              vaultBinders.isDeleted.equals(false)),
    );
    query.orderBy([
      OrderingTerm(
          expression: vaultItems.lastPriceUpdate, mode: OrderingMode.desc),
      OrderingTerm(expression: vaultItems.name, mode: OrderingMode.asc),
    ]);
    final rows = await query.get();
    return rows.map((r) => r.readTable(vaultItems)).toList();
  }

  // ---------------------------------------------------------------------------
  // PHASE 3: INBOX HOLDING AREA
  // ---------------------------------------------------------------------------

  /// Streams all owned cards currently staged in the "Inbox" holding area (primaryBinderId == 'INBOX').
  Stream<List<VaultItem>> watchInboxItems() {
    return (select(vaultItems)
          ..where((t) =>
              t.primaryBinderId.equals('INBOX') &
              t.quantity.isBiggerThanValue(0) &
              t.isDeleted.equals(false))
          ..orderBy([
            (t) => OrderingTerm(
                expression: t.lastPriceUpdate, mode: OrderingMode.desc),
            (t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc),
          ]))
        .watch();
  }

  // ---------------------------------------------------------------------------
  // PHASE 3: ITEM DELETION
  // ---------------------------------------------------------------------------

  /// Soft deletes a single item from SQLite by its ID.
  Future<int> deleteItem(String id) async {
    final now = DateTime.now();
    final count = await (update(vaultItems)
          ..where((t) => t.id.equals(id) & t.isDeleted.equals(false)))
        .write(
      VaultItemsCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(now),
      ),
    );
    if (count > 0) {
      await _recordSync('vault_item', id, 'DELETE', timestamp: now);
    }
    return count;
  }

  /// Soft deletes multiple items from SQLite by their IDs.
  Future<int> deleteItems(List<String> ids) async {
    if (ids.isEmpty) return 0;
    final now = DateTime.now();
    final activeItems = await (select(vaultItems)
          ..where((t) => t.id.isIn(ids) & t.isDeleted.equals(false)))
        .get();
    if (activeItems.isEmpty) return 0;
    final activeIds = activeItems.map((e) => e.id).toList();
    final count = await (update(vaultItems)
          ..where((t) => t.id.isIn(activeIds)))
        .write(
      VaultItemsCompanion(
        isDeleted: const Value(true),
        updatedAt: Value(now),
      ),
    );
    for (final id in activeIds) {
      await _recordSync('vault_item', id, 'DELETE', timestamp: now);
    }
    return count;
  }

  /// Soft deletes a deck, cascades soft-deletion to all child versions and items, and flags sync deletion.
  Future<int> deleteDeck(String deckId) async {
    return transaction(() async {
      final now = DateTime.now();

      // Collect all member vaultItemIds before/during soft-deletion
      final versions = await (select(deckVersions)..where((t) => t.deckId.equals(deckId))).get();
      final affectedVaultItemIds = <String>{};
      for (final v in versions) {
        final items = await (select(deckVersionItems)..where((t) => t.versionId.equals(v.id))).get();
        for (final item in items) {
          affectedVaultItemIds.add(item.vaultItemId);
        }
      }

      final count = await (update(decks)
            ..where((t) => t.id.equals(deckId) & t.isDeleted.equals(false)))
          .write(
        DecksCompanion(
          isDeleted: const Value(true),
          updatedAt: Value(now),
        ),
      );
      if (count > 0) {
        await _recordSync('deck', deckId, 'DELETE', timestamp: now);

        for (final v in versions) {
          await (update(deckVersions)..where((t) => t.id.equals(v.id))).write(
            DeckVersionsCompanion(
              isDeleted: const Value(true),
              updatedAt: Value(now),
            ),
          );
          await _recordSync('deck_version', v.id, 'DELETE', timestamp: now);

          final items = await (select(deckVersionItems)..where((t) => t.versionId.equals(v.id))).get();
          for (final item in items) {
            await (update(deckVersionItems)..where((t) => t.id.equals(item.id))).write(
              DeckVersionItemsCompanion(
                isDeleted: const Value(true),
                updatedAt: Value(now),
              ),
            );
            await _recordSync('deck_version_item', item.id, 'DELETE', timestamp: now);
          }
        }

        // Cascade sync to all affected member cards
        for (final vaultItemId in affectedVaultItemIds) {
          await _syncItemDeckHistory(vaultItemId);
        }
      }
      return count;
    });
  }

  /// Soft deletes a binder, unassigns its cards, and flags its sync deletion.
  Future<int> deleteBinder(String binderId) async {
    return transaction(() async {
      final now = DateTime.now();
      final count = await (update(vaultBinders)
            ..where((t) => t.id.equals(binderId) & t.isDeleted.equals(false)))
          .write(
        VaultBindersCompanion(
          isDeleted: const Value(true),
          updatedAt: Value(now),
        ),
      );
      if (count > 0) {
        await _recordSync('binder', binderId, 'DELETE', timestamp: now);

        // Unassign cards that were anchored to this binder
        final cardsInBinder = await (select(vaultItems)..where((t) => t.primaryBinderId.equals(binderId))).get();
        if (cardsInBinder.isNotEmpty) {
          await (update(vaultItems)..where((t) => t.primaryBinderId.equals(binderId))).write(
            VaultItemsCompanion(
              primaryBinderId: const Value(null),
              updatedAt: Value(now),
            ),
          );
          for (final card in cardsInBinder) {
            await _recordSync('vault_item', card.id, 'UPDATE', timestamp: now);
          }
        }
      }
      return count;
    });
  }

  // ---------------------------------------------------------------------------
  // PHASE 3: REAL-TIME SCANNER CARD MATCHING
  // ---------------------------------------------------------------------------

  /// Extracts the base card name by stripping split / adventure card delimiter (' //')
  /// and variant / serialized subtitle (' (').
  String _extractBaseCardName(String name) {
    var base = name;
    final slashIndex = base.indexOf(' //');
    if (slashIndex != -1) base = base.substring(0, slashIndex);
    final parenIndex = base.indexOf(' (');
    if (parenIndex != -1) base = base.substring(0, parenIndex);
    return base.trim();
  }

  /// Real-time hybrid search in SQLite and Dart for a card matching OCR candidate lines.
  ///
  /// Requirement R3 Hybrid Matching Engine:
  /// - Step 1 (Regex Override): Extracts collector number patterns (xxx/yyy, #xxx, SV01-xxx)
  ///   or uses explicit collectorNumber parameter and queries dynamic_data LIMIT 1.
  /// - Step 2 (SQL Wide Net): Filters OCR lines length >= 4 (ordered descending by length),
  ///   extracts first 5 characters, and queries SQLite:
  ///   `WHERE name LIKE '$firstFiveChars%' AND quantity == 0 LIMIT 25`.
  /// - Step 3 (Dart `contains` Verification): Iterates candidate items in memory, sanitizes
  ///   names via [sanitize], and confirms match via `sanitizedOcrLine.contains(sanitizedDbName)`
  ///   or `sanitizedOcrLine.contains(sanitizedBaseDbName)`.
  Future<VaultItem?> matchScannedCard(
    List<String> cleanedOcrLines,
    String activeContext, {
    String? collectorNumber,
    String? setCode,
    bool enforceMultiFactor = false,
  }) async {
    // -------------------------------------------------------------------------
    // Guard: Empty Input Check
    // -------------------------------------------------------------------------
    if (cleanedOcrLines.isEmpty &&
        (collectorNumber == null || collectorNumber.trim().isEmpty)) {
      return null;
    }

    final normalized = _normalizeCollectionType(activeContext);

    // Helper to evaluate multi-factor gate when enforceMultiFactor is enabled
    bool validateMultiFactor(VaultItem item, {String? detectedCollector}) {
      if (!enforceMultiFactor) return true;
      String? cardCollector = collectorNumber;
      String? cardSet = setCode;
      String? cardTypeLine;
      if (item.dynamicData.isNotEmpty) {
        try {
          final data = jsonDecode(item.dynamicData) as Map<String, dynamic>;
          cardCollector ??= data['collector_number']?.toString();
          cardSet ??= data['set']?.toString();
          cardTypeLine = data['type_line']?.toString();
        } catch (error, stackTrace) {
          debugPrint('[VaultDao._detectCardCollectorAndSet] Failed decoding dynamicData: $error\n$stackTrace');
        }
      }
      cardCollector ??= detectedCollector;
      cardSet ??= item.setOrSeries;
      return OcrHeuristicMatcher.passesMultiFactorGate(
        cardName: item.name,
        ocrLines: cleanedOcrLines,
        collectorNumber: cardCollector,
        setCode: cardSet,
        typeLine: cardTypeLine,
      );
    }

    // -------------------------------------------------------------------------
    // STEP 1: Collector Number Regex Override
    // -------------------------------------------------------------------------
    String? effectiveCollector = collectorNumber?.trim();
    if (effectiveCollector == null || effectiveCollector.isEmpty) {
      final fractionPattern = RegExp(r'\b(\d{1,4})\s*[/]\s*(\d{1,4})\b');
      final setDashPattern =
          RegExp(r'\b([A-Za-z0-9]{2,5})\s*[-–—]\s*(\d{1,4})\b');
      final hashPattern =
          RegExp(r'\b(?:NO\.?|#)\s*(\d{1,4})\b', caseSensitive: false);

      for (final line in cleanedOcrLines) {
        final fMatch = fractionPattern.firstMatch(line);
        if (fMatch != null) {
          final num = fMatch.group(1)!;
          final denom = fMatch.group(2)!;
          // Guard against creature P/T stat boxes like 2/2 or 5/5
          if (num != denom || (int.tryParse(num) ?? 0) > 20) {
            effectiveCollector = num;
            break;
          }
        }
        final sMatch = setDashPattern.firstMatch(line);
        if (sMatch != null) {
          effectiveCollector = sMatch.group(2);
          break;
        }
        final hMatch = hashPattern.firstMatch(line);
        if (hMatch != null) {
          effectiveCollector = hMatch.group(1);
          break;
        }
      }
    }

    if (effectiveCollector != null && effectiveCollector.isNotEmpty) {
      final cleanNum = effectiveCollector.trim();
      final stripped = cleanNum.replaceFirst(RegExp(r'^0+'), '');
      final numCandidates = <String>{
        cleanNum,
        if (stripped.isNotEmpty) stripped,
        cleanNum.padLeft(3, '0'),
        cleanNum.padLeft(4, '0'),
        if (stripped.isNotEmpty) stripped.padLeft(3, '0'),
        if (stripped.isNotEmpty) stripped.padLeft(4, '0'),
      };

      Expression<bool> buildCollectorPred(VaultItems t) {
        Expression<bool>? p;
        for (final num in numCandidates) {
          final pred1 = t.dynamicData.like('%"collector_number":"$num"%') |
              t.dynamicData.like('%"collector_number": "$num"%');
          p = p == null ? pred1 : (p | pred1);
        }
        return p!;
      }

      final collectorCandidates = await (select(vaultItems)
            ..where((t) {
              final pred = buildCollectorPred(t) & t.isDeleted.equals(false);
              if (normalized != 'all') {
                return pred & t.collectionType.equals(normalized);
              }
              return pred;
            })
            ..limit(25))
          .get();

      for (final candidate in collectorCandidates) {
        if (validateMultiFactor(candidate, detectedCollector: cleanNum)) {
          debugPrint(
              '[VaultDao.matchScannedCard] Matched via collector number ($cleanNum): "${candidate.name}"');
          return candidate;
        } else {
          debugPrint(
              '[VaultDao.matchScannedCard] Multi-factor gate rejected collector match: "${candidate.name}"');
        }
      }

      if (normalized != 'all') {
        final crossCandidates = await (select(vaultItems)
              ..where((t) => buildCollectorPred(t) & t.isDeleted.equals(false))
              ..limit(25))
            .get();

        for (final candidate in crossCandidates) {
          if (validateMultiFactor(candidate, detectedCollector: cleanNum)) {
            debugPrint(
                '[VaultDao.matchScannedCard] Matched via cross-collection collector number ($cleanNum): "${candidate.name}"');
            return candidate;
          } else {
            debugPrint(
                '[VaultDao.matchScannedCard] Multi-factor gate rejected cross-collection collector match: "${candidate.name}"');
          }
        }
      }
    }

    // -------------------------------------------------------------------------
    // STEP 2: Filter OCR Lines & SQL Wide Net
    // -------------------------------------------------------------------------
    // Filter lines length >= 3 (longest lines tested first via sort below)
    var eligibleLines = cleanedOcrLines
        .map((l) => l.trim())
        .where((l) => l.length >= 3)
        .toList();

    if (eligibleLines.isEmpty) return null;

    // Filter out lines that lack at least 3 alphanumeric characters
    eligibleLines = eligibleLines.where((l) {
      final stripped = l.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
      return stripped.length >= 3;
    }).toList();

    if (eligibleLines.isEmpty) return null;

    // Sort descending by length to test the longest, most descriptive lines first
    eligibleLines.sort((a, b) => b.length.compareTo(a.length));

    // Internal helper for Step 2 (SQL Wide Net) and Step 3 (Dart verification)
    Future<VaultItem?> verifyCandidatesForLine(
      String line, {
      required bool catalogOnly,
      required String collection,
      bool Function(VaultItem candidate)? filter,
    }) async {
      final cleanLine = line.replaceFirst(RegExp(r'^[^a-zA-Z0-9]+'), '').trim();
      if (cleanLine.length < 3) return null;

      final firstFive = cleanLine.length >= 5 ? cleanLine.substring(0, 5) : cleanLine;
      final alphaLine = cleanLine.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
      final alphaFive = alphaLine.length >= 5 ? alphaLine.substring(0, 5) : alphaLine;
      final firstWord = cleanLine.split(RegExp(r'\s+')).first;

      final sql = '''
        SELECT * FROM "vault_items"
        WHERE "is_deleted" = 0 AND 
              ${collection != 'all' ? '"collection_type" = ? AND ' : ''}
              ${catalogOnly ? '"quantity" = 0 AND ' : ''}
              (
                "name" LIKE ?
                OR "name" LIKE ?
                OR replace(replace(replace("name", char(34), ''), char(39), ''), '’', '') LIKE ?
                ${firstWord.length >= 3 && firstWord.length < 5 ? 'OR "name" LIKE ?' : ''}
              )
        LIMIT 25;
      ''';

      final candidates = await customSelect(
        sql,
        variables: [
          if (collection != 'all') Variable.withString(collection),
          Variable.withString('$firstFive%'),
          Variable.withString('"$firstFive%'),
          Variable.withString('$alphaFive%'),
          if (firstWord.length >= 3 && firstWord.length < 5) Variable.withString('$firstWord%'),
        ],
        readsFrom: {vaultItems},
      ).map((row) => vaultItems.map(row.data)).get();

      if (candidates.isEmpty) return null;

      final sanitizedOcrLine = sanitize(line);

      // STEP 3: Dart contains verification
      // Pass A: Exact match pass (prioritizes identical titles)
      final exactMatches = <VaultItem>[];
      for (final card in candidates) {
        final sanitizedDb = sanitize(card.name);
        final sanitizedBase = sanitize(_extractBaseCardName(card.name));
        if (sanitizedOcrLine == sanitizedDb || sanitizedOcrLine == sanitizedBase) {
          if (filter == null || filter(card)) {
            exactMatches.add(card);
          } else {
            debugPrint(
                '[VaultDao.matchScannedCard] Multi-factor gate rejected candidate: "${card.name}" (${card.setOrSeries})');
          }
        }
      }

      if (exactMatches.isNotEmpty) {
        if (exactMatches.length == 1) return exactMatches.first;
        // Prioritize candidate matching set code or collector number in OCR lines
        for (final card in exactMatches) {
          String? cardSet;
          String? cardCollector;
          if (card.dynamicData.isNotEmpty) {
            try {
              final data = jsonDecode(card.dynamicData) as Map<String, dynamic>;
              cardSet = data['set']?.toString();
              cardCollector = data['collector_number']?.toString();
            } catch (error, stackTrace) {
              debugPrint('[VaultDao.matchScannedCard] Exact match decoding dynamicData failed: $error\n$stackTrace');
            }
          }
          cardSet ??= card.setOrSeries;
          if (cardSet.isNotEmpty) {
            final upperSet = cardSet.toUpperCase();
            if (cleanedOcrLines.any((l) =>
                l.trim().toUpperCase() == upperSet ||
                RegExp(r'\b' + RegExp.escape(upperSet) + r'\b', caseSensitive: false).hasMatch(l))) {
              return card;
            }
          }
          if (cardCollector != null && cardCollector.isNotEmpty) {
            final stripped = cardCollector.replaceFirst(RegExp(r'^0+'), '');
            if (cleanedOcrLines.any((l) =>
                l.trim() == cardCollector ||
                (stripped.isNotEmpty && l.trim() == stripped))) {
              return card;
            }
          }
        }
        return exactMatches.first;
      }

      // Pass B: Substring containment pass (prioritizes longer candidate names)
      final sortedCandidates = List<VaultItem>.from(candidates)
        ..sort((a, b) {
          final lenA = sanitize(_extractBaseCardName(a.name)).length;
          final lenB = sanitize(_extractBaseCardName(b.name)).length;
          return lenB.compareTo(lenA);
        });

      final substringMatches = <VaultItem>[];
      for (final card in sortedCandidates) {
        final sanitizedDb = sanitize(card.name);
        final sanitizedBase = sanitize(_extractBaseCardName(card.name));
        if (sanitizedBase.length >= 3 &&
            (sanitizedOcrLine.contains(sanitizedDb) ||
             sanitizedOcrLine.contains(sanitizedBase))) {
          if (filter == null || filter(card)) {
            substringMatches.add(card);
          } else {
            debugPrint(
                '[VaultDao.matchScannedCard] Multi-factor gate rejected candidate: "${card.name}" (${card.setOrSeries})');
          }
        }
      }

      if (substringMatches.isNotEmpty) {
        if (substringMatches.length == 1) return substringMatches.first;
        for (final card in substringMatches) {
          String? cardSet;
          String? cardCollector;
          if (card.dynamicData.isNotEmpty) {
            try {
              final data = jsonDecode(card.dynamicData) as Map<String, dynamic>;
              cardSet = data['set']?.toString();
              cardCollector = data['collector_number']?.toString();
            } catch (error, stackTrace) {
              debugPrint('[VaultDao.matchScannedCard] Substring match decoding dynamicData failed: $error\n$stackTrace');
            }
          }
          cardSet ??= card.setOrSeries;
          if (cardSet.isNotEmpty) {
            final upperSet = cardSet.toUpperCase();
            if (cleanedOcrLines.any((l) =>
                l.trim().toUpperCase() == upperSet ||
                RegExp(r'\b' + RegExp.escape(upperSet) + r'\b', caseSensitive: false).hasMatch(l))) {
              return card;
            }
          }
          if (cardCollector != null && cardCollector.isNotEmpty) {
            final stripped = cardCollector.replaceFirst(RegExp(r'^0+'), '');
            if (cleanedOcrLines.any((l) =>
                l.trim() == cardCollector ||
                (stripped.isNotEmpty && l.trim() == stripped))) {
              return card;
            }
          }
        }
        return substringMatches.first;
      }

      return null;
    }

    // -------------------------------------------------------------------------
    // Tiered Verification Passes
    // -------------------------------------------------------------------------

    // Pass 1: Catalog reference items (quantity == 0) in active collection context
    for (final line in eligibleLines) {
      final match = await verifyCandidatesForLine(
        line,
        catalogOnly: true,
        collection: normalized,
        filter: validateMultiFactor,
      );
      if (match != null) {
        debugPrint('[VaultDao.matchScannedCard] Matched catalog item: "${match.name}" from line: "$line" (context: $normalized)');
        return match;
      }
    }

    // Pass 2: Owned inventory items (quantity >= 0) in active collection context
    for (final line in eligibleLines) {
      final match = await verifyCandidatesForLine(
        line,
        catalogOnly: false,
        collection: normalized,
        filter: validateMultiFactor,
      );
      if (match != null) {
        debugPrint('[VaultDao.matchScannedCard] Matched inventory item: "${match.name}" from line: "$line" (context: $normalized)');
        return match;
      }
    }

    // Pass 3: Cross-collection search fallback
    if (normalized != 'all') {
      for (final line in eligibleLines) {
        final match = await verifyCandidatesForLine(
          line,
          catalogOnly: true,
          collection: 'all',
          filter: validateMultiFactor,
        );
        if (match != null) {
          debugPrint('[VaultDao.matchScannedCard] Matched cross-collection catalog item: "${match.name}" from line: "$line" (collection: "${match.collectionType}")');
          return match;
        }
      }
      for (final line in eligibleLines) {
        final match = await verifyCandidatesForLine(
          line,
          catalogOnly: false,
          collection: 'all',
          filter: validateMultiFactor,
        );
        if (match != null) {
          debugPrint('[VaultDao.matchScannedCard] Matched cross-collection inventory item: "${match.name}" from line: "$line" (collection: "${match.collectionType}")');
          return match;
        }
      }
    }

    return null;
  }

  /// Instantly UPSERTs a matched card into the user's Inbox holding area.
  Future<void> upsertScannedCardToInbox(
    VaultItem card, {
    bool isFoil = false,
  }) async {
    final existing = await (select(vaultItems)..where((t) => t.id.equals(card.id) & t.isDeleted.equals(false)))
        .getSingleOrNull();

    final now = DateTime.now();
    if (existing == null) {
      await into(vaultItems).insert(
        VaultItemsCompanion.insert(
          id: card.id,
          collectionType: card.collectionType,
          name: card.name,
          setOrSeries: card.setOrSeries,
          imageUrl: card.imageUrl,
          acquiredPrice: card.currentMarketPrice,
          acquiredDate: now,
          quantity: const Value(1),
          condition: isFoil ? 'NM (Foil)' : 'NM',
          isGraded: const Value(false),
          personalNotes: isFoil
              ? const Value('Scanned Foil / Variant')
              : const Value('Edge Scanned'),
          currentMarketPrice: card.currentMarketPrice,
          lastPriceUpdate: now,
          dynamicData: card.dynamicData,
          primaryBinderId: const Value('INBOX'),
          isDeleted: const Value(false),
          updatedAt: Value(now),
        ),
      );
      await _recordSync('vault_item', card.id, 'INSERT', timestamp: now);
    } else {
      final newQuantity = existing.quantity > 0 ? existing.quantity + 1 : 1;
      final newNotes = existing.personalNotes != null &&
              existing.personalNotes!.isNotEmpty
          ? existing.personalNotes
          : (isFoil ? 'Scanned Foil / Variant' : 'Edge Scanned');

      await (update(vaultItems)..where((t) => t.id.equals(card.id))).write(
        VaultItemsCompanion(
          quantity: Value(newQuantity),
          primaryBinderId: const Value('INBOX'),
          currentMarketPrice: Value(card.currentMarketPrice),
          lastPriceUpdate: Value(now),
          condition:
              isFoil ? const Value('NM (Foil)') : Value(existing.condition),
          personalNotes: Value(newNotes),
          updatedAt: Value(now),
        ),
      );
      await _recordSync('vault_item', card.id, 'UPDATE', timestamp: now);
    }
  }

  /// Updates catalog/metadata fields of a card on-demand (e.g. self-healing).
  Future<void> updateItemMetadata(
    String id, {
    String? flavorName,
    String? imageUrl,
    double? currentMarketPrice,
    String? dynamicData,
  }) async {
    final now = DateTime.now();
    await (update(vaultItems)..where((t) => t.id.equals(id))).write(
      VaultItemsCompanion(
        flavorName:
            flavorName != null ? Value(flavorName) : const Value.absent(),
        imageUrl: imageUrl != null && imageUrl.isNotEmpty
            ? Value(imageUrl)
            : const Value.absent(),
        currentMarketPrice: currentMarketPrice != null
            ? Value(currentMarketPrice)
            : const Value.absent(),
        dynamicData:
            dynamicData != null ? Value(dynamicData) : const Value.absent(),
        lastPriceUpdate: currentMarketPrice != null
            ? Value(now)
            : const Value.absent(),
        updatedAt: Value(now),
      ),
    );
    await _recordSync('vault_item', id, 'UPDATE', timestamp: now);
  }

  /// Ensures case-insensitive indexes for Secret Lair sets, flavor names, and Universes Beyond.
  Future<void> ensureSecretLairIndexes() async {
    try {
      await customStatement('''
        CREATE INDEX IF NOT EXISTS "idx_vault_items_set_or_series"
        ON "vault_items" ("set_or_series" COLLATE NOCASE);
      ''');
      await customStatement('''
        CREATE INDEX IF NOT EXISTS "idx_vault_items_set_code"
        ON "vault_items" (json_extract("dynamic_data", '\$.set') COLLATE NOCASE);
      ''');
      await customStatement('''
        CREATE INDEX IF NOT EXISTS "idx_vault_items_flavor_name"
        ON "vault_items" ("flavor_name" COLLATE NOCASE);
      ''');
      await customStatement('''
        CREATE INDEX IF NOT EXISTS "idx_vault_items_is_ub"
        ON "vault_items" (json_extract("dynamic_data", '\$.is_universes_beyond'));
      ''');
    } catch (error, stackTrace) {
      debugPrint('[VaultDao.ensureSecretLairIndexes] Index creation failed: $error\n$stackTrace');
    }
  }

  // ---------------------------------------------------------------------------
  // PHASE 3.9 R1: UNIVERSES BEYOND & SECRET LAIR FILTER QUERIES
  // ---------------------------------------------------------------------------

  /// Streams Universes Beyond cards scoped by collection and ownership.
  Stream<List<VaultItem>> watchUniversesBeyondItems({
    String? collectionType,
    bool onlyOwned = false,
    int? limit,
    int? offset,
  }) {
    final normalized = collectionType != null ? _normalizeCollectionType(collectionType) : 'all';
    final query = select(vaultItems)
      ..where((t) =>
          t.isDeleted.equals(false) &
          (const CustomExpression<bool>(
            "json_extract(vault_items.dynamic_data, '\$.is_universes_beyond') = 1",
          ) |
          t.dynamicData.like('%"is_universes_beyond":true%') |
          t.dynamicData.like('%"is_universes_beyond": true%')));

    if (normalized != 'all') {
      query.where((t) => t.collectionType.equals(normalized));
    }
    if (onlyOwned) {
      query.where((t) => t.quantity.isBiggerThanValue(0));
    }
    query.where((t) =>
        t.primaryBinderId.isNull() |
        t.primaryBinderId.equals('INBOX').not());

    query.orderBy([(t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc)]);
    if (limit != null) query.limit(limit, offset: offset);
    return query.watch();
  }

  /// One-shot query for Universes Beyond cards.
  Future<List<VaultItem>> getUniversesBeyondItems({
    String? collectionType,
    bool onlyOwned = false,
    int? limit,
    int? offset,
  }) {
    final normalized = collectionType != null ? _normalizeCollectionType(collectionType) : 'all';
    final query = select(vaultItems)
      ..where((t) =>
          t.isDeleted.equals(false) &
          (const CustomExpression<bool>(
            "json_extract(vault_items.dynamic_data, '\$.is_universes_beyond') = 1",
          ) |
          t.dynamicData.like('%"is_universes_beyond":true%') |
          t.dynamicData.like('%"is_universes_beyond": true%')));

    if (normalized != 'all') {
      query.where((t) => t.collectionType.equals(normalized));
    }
    if (onlyOwned) {
      query.where((t) => t.quantity.isBiggerThanValue(0));
    }
    query.where((t) =>
        t.primaryBinderId.isNull() |
        t.primaryBinderId.equals('INBOX').not());

    query.orderBy([(t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc)]);
    if (limit != null) query.limit(limit, offset: offset);
    return query.get();
  }

  /// Streams Secret Lair Drop cards case-insensitively matching set code 'sld' or set name 'Secret Lair Drop'.
  Stream<List<VaultItem>> watchSecretLairItems({
    bool onlyOwned = false,
    int? limit,
    int? offset,
  }) {
    final query = select(vaultItems)
      ..where((t) =>
          t.isDeleted.equals(false) &
          (t.setOrSeries.like('%Secret Lair%') |
          const CustomExpression<bool>(
            "json_extract(vault_items.dynamic_data, '\$.set') = 'sld' COLLATE NOCASE",
          ) |
          const CustomExpression<bool>(
            "json_extract(vault_items.dynamic_data, '\$.set_code') = 'sld' COLLATE NOCASE",
          ) |
          t.dynamicData.like('%"set":"sld"%') |
          t.dynamicData.like('%"set_code":"sld"%') |
          t.dynamicData.like('%"set": "sld"%') |
          t.dynamicData.like('%"set_code": "sld"%')));

    if (onlyOwned) {
      query.where((t) => t.quantity.isBiggerThanValue(0));
    }
    query.where((t) =>
        t.primaryBinderId.isNull() |
        t.primaryBinderId.equals('INBOX').not());

    query.orderBy([(t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc)]);
    if (limit != null) query.limit(limit, offset: offset);
    return query.watch();
  }

  /// One-shot query for Secret Lair Drop cards.
  Future<List<VaultItem>> getSecretLairItems({
    bool onlyOwned = false,
    int? limit,
    int? offset,
  }) {
    final query = select(vaultItems)
      ..where((t) =>
          t.isDeleted.equals(false) &
          (t.setOrSeries.like('%Secret Lair%') |
          const CustomExpression<bool>(
            "json_extract(vault_items.dynamic_data, '\$.set') = 'sld' COLLATE NOCASE",
          ) |
          const CustomExpression<bool>(
            "json_extract(vault_items.dynamic_data, '\$.set_code') = 'sld' COLLATE NOCASE",
          ) |
          t.dynamicData.like('%"set":"sld"%') |
          t.dynamicData.like('%"set_code":"sld"%') |
          t.dynamicData.like('%"set": "sld"%') |
          t.dynamicData.like('%"set_code": "sld"%')));

    if (onlyOwned) {
      query.where((t) => t.quantity.isBiggerThanValue(0));
    }
    query.where((t) =>
        t.primaryBinderId.isNull() |
        t.primaryBinderId.equals('INBOX').not());

    query.orderBy([(t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc)]);
    if (limit != null) query.limit(limit, offset: offset);
    return query.get();
  }

  /// Generic set filter query matching set code or set name case-insensitively.
  Future<List<VaultItem>> getItemsBySet({
    required String setIdentifier,
    String? collectionType,
    bool onlyOwned = false,
    int? limit,
    int? offset,
  }) {
    final normalized = collectionType != null ? _normalizeCollectionType(collectionType) : 'all';
    final cleanSet = setIdentifier.trim().toLowerCase();
    final isSld = cleanSet == 'sld' || cleanSet == 'secret lair' || cleanSet == 'secret lair drop';

    final query = select(vaultItems)..where((t) => t.isDeleted.equals(false));
    if (isSld) {
      query.where((t) =>
          t.setOrSeries.like('%Secret Lair%') |
          const CustomExpression<bool>(
            "json_extract(vault_items.dynamic_data, '\$.set') = 'sld' COLLATE NOCASE",
          ) |
          const CustomExpression<bool>(
            "json_extract(vault_items.dynamic_data, '\$.set_code') = 'sld' COLLATE NOCASE",
          ) |
          t.dynamicData.like('%"set":"sld"%') |
          t.dynamicData.like('%"set_code":"sld"%') |
          t.dynamicData.like('%"set": "sld"%') |
          t.dynamicData.like('%"set_code": "sld"%'));
    } else {
      query.where((t) =>
          t.setOrSeries.equals(setIdentifier) |
          t.setOrSeries.like('%$setIdentifier%') |
          CustomExpression<bool>(
            "json_extract(vault_items.dynamic_data, '\$.set') = '$cleanSet' COLLATE NOCASE",
          ) |
          CustomExpression<bool>(
            "json_extract(vault_items.dynamic_data, '\$.set_code') = '$cleanSet' COLLATE NOCASE",
          ) |
          t.dynamicData.like('%"set":"$cleanSet"%') |
          t.dynamicData.like('%"set_code":"$cleanSet"%') |
          t.dynamicData.like('%"set": "$cleanSet"%') |
          t.dynamicData.like('%"set_code": "$cleanSet"%'));
    }

    if (normalized != 'all') {
      query.where((t) => t.collectionType.equals(normalized));
    }
    if (onlyOwned) {
      query.where((t) => t.quantity.isBiggerThanValue(0));
    }
    query.where((t) =>
        t.primaryBinderId.isNull() |
        t.primaryBinderId.equals('INBOX').not());

    query.orderBy([(t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc)]);
    if (limit != null) query.limit(limit, offset: offset);
    return query.get();
  }

  /// Evaluates available quantity of a physical VaultItem by subtracting
  /// assigned copies across all active DeckVersions of REGISTERED decks.
  /// 
  /// Available = (VaultItem.quantity) - SUM(DeckVersionItems.quantity across all ACTIVE DeckVersions of REGISTERED Decks)
  /// Draft decks (is_registered == 0) do NOT lock physical inventory.
  Future<int> getAvailableQuantity(String vaultItemId) async {
    final querySql = '''
      SELECT 
        MAX(0, vi.quantity - COALESCE(alloc.total_allocated, 0)) AS available_quantity
      FROM vault_items vi
      LEFT JOIN (
        SELECT dvi.vault_item_id, SUM(dvi.quantity) AS total_allocated
        FROM deck_version_items dvi
        INNER JOIN deck_versions dv ON dv.id = dvi.version_id
        INNER JOIN decks d ON d.id = dv.deck_id
        WHERE dv.is_active = 1
          AND dvi.is_proxy = 0
          AND (d.is_assembled = 1 OR d.is_registered = 1)
          AND dvi.is_deleted = 0
          AND dv.is_deleted = 0
          AND d.is_deleted = 0
        GROUP BY dvi.vault_item_id
      ) alloc ON alloc.vault_item_id = vi.id
      WHERE vi.id = ? AND vi.is_deleted = 0
    ''';

    final row = await customSelect(
      querySql,
      variables: [Variable.withString(vaultItemId)],
      readsFrom: {vaultItems, deckVersionItems, deckVersions, decks},
    ).getSingleOrNull();

    if (row == null) return 0;
    return (row.data['available_quantity'] as num?)?.toInt() ?? 0;
  }

  /// Streams available physical quantity for a VaultItem reactively.
  Stream<int> watchAvailableQuantity(String vaultItemId) {
    final querySql = '''
      SELECT 
        MAX(0, vi.quantity - COALESCE(alloc.total_allocated, 0)) AS available_quantity
      FROM vault_items vi
      LEFT JOIN (
        SELECT dvi.vault_item_id, SUM(dvi.quantity) AS total_allocated
        FROM deck_version_items dvi
        INNER JOIN deck_versions dv ON dv.id = dvi.version_id
        INNER JOIN decks d ON d.id = dv.deck_id
        WHERE dv.is_active = 1
          AND dvi.is_proxy = 0
          AND (d.is_assembled = 1 OR d.is_registered = 1)
          AND dvi.is_deleted = 0
          AND dv.is_deleted = 0
          AND d.is_deleted = 0
        GROUP BY dvi.vault_item_id
      ) alloc ON alloc.vault_item_id = vi.id
      WHERE vi.id = ? AND vi.is_deleted = 0
    ''';

    return customSelect(
      querySql,
      variables: [Variable.withString(vaultItemId)],
      readsFrom: {vaultItems, deckVersionItems, deckVersions, decks},
    ).watchSingleOrNull().map((row) {
      if (row == null) return 0;
      return (row.data['available_quantity'] as num?)?.toInt() ?? 0;
    });
  }

  /// Lists all active decks where a vault item is currently assigned.
  /// If [onlyRegistered] is true, only decks that lock physical inventory (d.is_assembled == 1 || d.is_registered == 1) are returned.
  Future<List<String>> getDecksUsingItem(String vaultItemId, {bool onlyRegistered = true}) async {
    final whereClause = onlyRegistered
        ? 'WHERE dvi.vault_item_id = ? AND dv.is_active = 1 AND dvi.is_proxy = 0 AND (d.is_assembled = 1 OR d.is_registered = 1) AND dvi.is_deleted = 0 AND dv.is_deleted = 0 AND d.is_deleted = 0'
        : 'WHERE dvi.vault_item_id = ? AND dv.is_active = 1 AND dvi.is_proxy = 0 AND dvi.is_deleted = 0 AND dv.is_deleted = 0 AND d.is_deleted = 0';

    final querySql = '''
      SELECT DISTINCT d.name
      FROM deck_version_items dvi
      INNER JOIN deck_versions dv ON dv.id = dvi.version_id
      INNER JOIN decks d ON d.id = dv.deck_id
      $whereClause
    ''';

    final rows = await customSelect(
      querySql,
      variables: [Variable.withString(vaultItemId)],
      readsFrom: {deckVersionItems, deckVersions, decks},
    ).get();

    return rows.map((r) => r.read<String>('name')).toList();
  }

  /// Streams all active decks with Commander art crop, color identity, card count, and completeness.
  Stream<List<DeckSummary>> watchDeckSummaries() {
    const querySql = '''
      SELECT 
        d.id AS deck_id,
        d.name AS deck_name,
        d.format AS deck_format,
        d.tcg_domain AS tcg_domain,
        d.is_registered AS is_registered,
        d.is_competitive AS is_competitive,
        d.created_at AS created_at,
        d.cover_item_id AS cover_item_id,
        d.cover_crop_rect AS cover_crop_rect,
        dv.id AS active_version_id,
        COALESCE(cover_vi.id, vi.id) AS commander_card_id,
        COALESCE(cover_vi.name, vi.name) AS commander_name,
        COALESCE(cover_vi.image_url, vi.image_url, fallback_vi.image_url) AS commander_image_url,
        COALESCE(cover_vi.dynamic_data, vi.dynamic_data, fallback_vi.dynamic_data) AS commander_dynamic_data,
        (SELECT COALESCE(SUM(dvi_count.quantity), 0) 
         FROM deck_version_items dvi_count 
         WHERE dvi_count.version_id = dv.id 
           AND (dvi_count.is_deleted IS NULL OR dvi_count.is_deleted = 0)) AS total_card_count
      FROM decks d
      LEFT JOIN deck_versions dv 
        ON dv.deck_id = d.id 
       AND dv.is_active = 1 
       AND (dv.is_deleted IS NULL OR dv.is_deleted = 0)
      LEFT JOIN deck_version_items dvi 
        ON dvi.version_id = dv.id 
       AND dvi.board_zone = 'Commander' 
       AND (dvi.is_deleted IS NULL OR dvi.is_deleted = 0)
      LEFT JOIN vault_items vi 
        ON vi.id = dvi.vault_item_id 
       AND (vi.is_deleted IS NULL OR vi.is_deleted = 0)
      LEFT JOIN (
        SELECT version_id, vault_item_id,
               ROW_NUMBER() OVER (
                 PARTITION BY version_id 
                 ORDER BY CASE WHEN board_zone = 'Mainboard' THEN 0 ELSE 1 END, rowid ASC
               ) as rn
        FROM deck_version_items
        WHERE (is_deleted IS NULL OR is_deleted = 0)
      ) first_dvi ON first_dvi.version_id = dv.id AND first_dvi.rn = 1
      LEFT JOIN vault_items fallback_vi 
        ON fallback_vi.id = first_dvi.vault_item_id 
       AND (fallback_vi.is_deleted IS NULL OR fallback_vi.is_deleted = 0)
      LEFT JOIN vault_items cover_vi 
        ON cover_vi.id = d.cover_item_id 
       AND (cover_vi.is_deleted IS NULL OR cover_vi.is_deleted = 0)
      WHERE (d.is_deleted IS NULL OR d.is_deleted = 0)
      GROUP BY d.id
      ORDER BY d.created_at DESC;
    ''';

    return customSelect(
      querySql,
      readsFrom: {decks, deckVersions, deckVersionItems, vaultItems},
    ).watch().map((rows) {
      return rows.map((row) {
        return DeckSummary.fromRow(
          id: row.read<String>('deck_id'),
          name: row.read<String>('deck_name'),
          format: row.read<String>('deck_format'),
          tcgDomain: row.read<String?>('tcg_domain') ?? 'mtg',
          isRegistered: row.read<bool?>('is_registered') ?? false,
          isCompetitive: row.read<bool?>('is_competitive') ?? false,
          createdAt: row.read<DateTime>('created_at'),
          coverItemId: row.read<String?>('cover_item_id'),
          coverCropRect: row.read<String?>('cover_crop_rect'),
          activeVersionId: row.read<String?>('active_version_id'),
          commanderCardId: row.read<String?>('commander_card_id'),
          commanderName: row.read<String?>('commander_name'),
          commanderImageUrl: row.read<String?>('commander_image_url'),
          commanderDynamicData: row.read<String?>('commander_dynamic_data'),
          cardCount: row.read<int?>('total_card_count') ?? 0,
        );
      }).toList();
    });
  }

  /// One-shot query for active deck summaries.
  Future<List<DeckSummary>> getDeckSummaries() async {
    const querySql = '''
      SELECT 
        d.id AS deck_id,
        d.name AS deck_name,
        d.format AS deck_format,
        d.tcg_domain AS tcg_domain,
        d.is_registered AS is_registered,
        d.is_competitive AS is_competitive,
        d.created_at AS created_at,
        d.cover_item_id AS cover_item_id,
        d.cover_crop_rect AS cover_crop_rect,
        dv.id AS active_version_id,
        COALESCE(cover_vi.id, vi.id) AS commander_card_id,
        COALESCE(cover_vi.name, vi.name) AS commander_name,
        COALESCE(cover_vi.image_url, vi.image_url, fallback_vi.image_url) AS commander_image_url,
        COALESCE(cover_vi.dynamic_data, vi.dynamic_data, fallback_vi.dynamic_data) AS commander_dynamic_data,
        (SELECT COALESCE(SUM(dvi_count.quantity), 0) 
         FROM deck_version_items dvi_count 
         WHERE dvi_count.version_id = dv.id 
           AND (dvi_count.is_deleted IS NULL OR dvi_count.is_deleted = 0)) AS total_card_count
      FROM decks d
      LEFT JOIN deck_versions dv 
        ON dv.deck_id = d.id 
       AND dv.is_active = 1 
       AND (dv.is_deleted IS NULL OR dv.is_deleted = 0)
      LEFT JOIN deck_version_items dvi 
        ON dvi.version_id = dv.id 
       AND dvi.board_zone = 'Commander' 
       AND (dvi.is_deleted IS NULL OR dvi.is_deleted = 0)
      LEFT JOIN vault_items vi 
        ON vi.id = dvi.vault_item_id 
       AND (vi.is_deleted IS NULL OR vi.is_deleted = 0)
      LEFT JOIN (
        SELECT version_id, vault_item_id,
               ROW_NUMBER() OVER (
                 PARTITION BY version_id 
                 ORDER BY CASE WHEN board_zone = 'Mainboard' THEN 0 ELSE 1 END, rowid ASC
               ) as rn
        FROM deck_version_items
        WHERE (is_deleted IS NULL OR is_deleted = 0)
      ) first_dvi ON first_dvi.version_id = dv.id AND first_dvi.rn = 1
      LEFT JOIN vault_items fallback_vi 
        ON fallback_vi.id = first_dvi.vault_item_id 
       AND (fallback_vi.is_deleted IS NULL OR fallback_vi.is_deleted = 0)
      LEFT JOIN vault_items cover_vi 
        ON cover_vi.id = d.cover_item_id 
       AND (cover_vi.is_deleted IS NULL OR cover_vi.is_deleted = 0)
      WHERE (d.is_deleted IS NULL OR d.is_deleted = 0)
      GROUP BY d.id
      ORDER BY d.created_at DESC;
    ''';

    final rows = await customSelect(
      querySql,
      readsFrom: {decks, deckVersions, deckVersionItems, vaultItems},
    ).get();

    return rows.map((row) {
      return DeckSummary.fromRow(
        id: row.read<String>('deck_id'),
        name: row.read<String>('deck_name'),
        format: row.read<String>('deck_format'),
        tcgDomain: row.read<String?>('tcg_domain') ?? 'mtg',
        isRegistered: row.read<bool?>('is_registered') ?? false,
        isCompetitive: row.read<bool?>('is_competitive') ?? false,
        createdAt: row.read<DateTime>('created_at'),
        coverItemId: row.read<String?>('cover_item_id'),
        coverCropRect: row.read<String?>('cover_crop_rect'),
        activeVersionId: row.read<String?>('active_version_id'),
        commanderCardId: row.read<String?>('commander_card_id'),
        commanderName: row.read<String?>('commander_name'),
        commanderImageUrl: row.read<String?>('commander_image_url'),
        commanderDynamicData: row.read<String?>('commander_dynamic_data'),
        cardCount: row.read<int?>('total_card_count') ?? 0,
      );
    }).toList();
  }

  /// Streams all decks
  Stream<List<Deck>> watchAllDecks() {
    return (select(decks)..where((t) => t.isDeleted.equals(false))).watch();
  }

  /// Returns all active decks.
  Future<List<Deck>> getAllDecks() {
    return (select(decks)..where((t) => t.isDeleted.equals(false))).get();
  }

  /// Returns all active versions for a deck.
  Future<List<DeckVersion>> getDeckVersions(String deckId) {
    return (select(deckVersions)..where((t) => t.deckId.equals(deckId) & t.isDeleted.equals(false))).get();
  }

  /// Returns deck items with card data for active version.
  Future<List<DeckItemWithCard>> getDeckItems(String deckId) async {
    const querySql = '''
      SELECT 
        dvi.id as dvi_id, dvi.version_id, dvi.vault_item_id, dvi.quantity as deck_quantity, dvi.board_zone, dvi.is_proxy,
        vi.id, vi.name, vi.set_or_series, vi.image_url, vi.dynamic_data, vi.current_market_price, vi.quantity as vault_quantity, vi.is_graded, vi.condition,
        vi.acquired_price, vi.purchase_price, vi.acquired_date, vi.date_obtained, vi.notes, vi.protection_status
      FROM deck_version_items dvi
      INNER JOIN deck_versions dv ON dv.id = dvi.version_id
      INNER JOIN decks d ON d.id = dv.deck_id
      INNER JOIN vault_items vi ON vi.id = dvi.vault_item_id
      WHERE dv.deck_id = ? AND dv.is_active = 1
        AND dvi.is_deleted = 0 AND dv.is_deleted = 0 AND d.is_deleted = 0 AND vi.is_deleted = 0
    ''';
    final rows = await customSelect(
      querySql,
      variables: [Variable.withString(deckId)],
      readsFrom: {decks, deckVersions, deckVersionItems, vaultItems},
    ).get();
    return rows.map((row) => DeckItemWithCard.fromRow(row.data)).toList();
  }

  /// Streams a single deck
  Stream<Deck> watchDeck(String id) {
    return (select(decks)..where((t) => t.id.equals(id) & t.isDeleted.equals(false))).watchSingle();
  }

  /// Streams a single deck or null if not found
  Stream<Deck?> watchDeckOrNull(String id) {
    return (select(decks)..where((t) => t.id.equals(id) & t.isDeleted.equals(false))).watchSingleOrNull();
  }

  /// Retrieves a single deck by ID or null if not found
  Future<Deck?> getDeck(String id) {
    return (select(decks)..where((t) => t.id.equals(id) & t.isDeleted.equals(false))).getSingleOrNull();
  }

  /// Streams deck items with vault item data for the active deck version
  Stream<List<DeckItemWithCard>> watchDeckItems(String deckId) {
    final querySql = '''
      SELECT 
        dvi.id as dvi_id, dvi.version_id, dvi.vault_item_id, dvi.quantity as deck_quantity, dvi.board_zone, dvi.is_proxy,
        vi.id, vi.name, vi.set_or_series, vi.image_url, vi.dynamic_data, vi.current_market_price, vi.quantity as vault_quantity, vi.is_graded, vi.condition,
        vi.acquired_price, vi.purchase_price, vi.acquired_date, vi.date_obtained, vi.notes, vi.protection_status
      FROM deck_version_items dvi
      INNER JOIN deck_versions dv ON dv.id = dvi.version_id
      INNER JOIN decks d ON d.id = dv.deck_id
      INNER JOIN vault_items vi ON vi.id = dvi.vault_item_id
      WHERE dv.deck_id = ? AND dv.is_active = 1
        AND dvi.is_deleted = 0 AND dv.is_deleted = 0 AND d.is_deleted = 0 AND vi.is_deleted = 0
    ''';
    
    return customSelect(
      querySql,
      variables: [Variable.withString(deckId)],
      readsFrom: {deckVersionItems, deckVersions, decks, vaultItems},
    ).watch().map((rows) {
      return rows.map((row) => DeckItemWithCard.fromRow(row.data)).toList();
    });
  }

  /// Streams active decks for a vault item, useful for UI badges
  Stream<List<String>> watchItemActiveDecks(String vaultItemId) {
    final querySql = '''
      SELECT DISTINCT d.name
      FROM deck_version_items dvi
      INNER JOIN deck_versions dv ON dv.id = dvi.version_id
      INNER JOIN decks d ON d.id = dv.deck_id
      WHERE dvi.vault_item_id = ? AND dv.is_active = 1 AND dvi.is_proxy = 0
        AND (d.is_assembled = 1 OR d.is_registered = 1)
        AND dvi.is_deleted = 0 AND dv.is_deleted = 0 AND d.is_deleted = 0
    ''';

    return customSelect(
      querySql,
      variables: [Variable.withString(vaultItemId)],
      readsFrom: {deckVersionItems, deckVersions, decks},
    ).watch().map((rows) {
      return rows.map((r) => r.read<String>('name')).toList();
    });
  }

  /// Alias for watchItemActiveDecks matching tier1_feature_coverage_test naming contract.
  Stream<List<String>> watchCardActiveDecks(String vaultItemId) =>
      watchItemActiveDecks(vaultItemId);

  /// Streams all active decks grouped by vault item id: `Map<String, List<String>>`
  Stream<Map<String, List<String>>> watchAllCardActiveDecks() {
    final querySql = '''
      SELECT DISTINCT dvi.vault_item_id, d.name
      FROM deck_version_items dvi
      INNER JOIN deck_versions dv ON dv.id = dvi.version_id
      INNER JOIN decks d ON d.id = dv.deck_id
      WHERE dv.is_active = 1 AND dvi.is_proxy = 0
        AND (d.is_assembled = 1 OR d.is_registered = 1)
        AND dvi.is_deleted = 0 AND dv.is_deleted = 0 AND d.is_deleted = 0
    ''';

    return customSelect(
      querySql,
      readsFrom: {deckVersionItems, deckVersions, decks},
    ).watch().map((rows) {
      final map = <String, List<String>>{};
      for (final r in rows) {
        final itemId = r.read<String>('vault_item_id');
        final deckName = r.read<String>('name');
        map.putIfAbsent(itemId, () => []).add(deckName);
      }
      return map;
    });
  }

  /// Streams reactive availability breakdown for all physical VaultItems.
  /// 
  /// Invariant: Owned = Available + In Deck.
  /// Only active versions of ASSEMBLED / REGISTERED decks lock physical stock.
  Stream<Map<String, CardAvailability>> watchAllCardAvailability() {
    const querySql = '''
      SELECT 
        vi.id AS vault_item_id,
        vi.quantity AS owned_quantity,
        COALESCE(alloc.total_allocated, 0) AS in_deck_quantity,
        MAX(0, vi.quantity - COALESCE(alloc.total_allocated, 0)) AS available_quantity
      FROM vault_items vi
      LEFT JOIN (
        SELECT dvi.vault_item_id, SUM(dvi.quantity) AS total_allocated
        FROM deck_version_items dvi
        INNER JOIN deck_versions dv ON dv.id = dvi.version_id
        INNER JOIN decks d ON d.id = dv.deck_id
        WHERE dv.is_active = 1
          AND dvi.is_proxy = 0
          AND (d.is_assembled = 1 OR d.is_registered = 1)
          AND dvi.is_deleted = 0
          AND dv.is_deleted = 0
          AND d.is_deleted = 0
        GROUP BY dvi.vault_item_id
      ) alloc ON alloc.vault_item_id = vi.id
      WHERE vi.is_deleted = 0;
    ''';

    return customSelect(
      querySql,
      readsFrom: {vaultItems, deckVersionItems, deckVersions, decks},
    ).watch().map((rows) {
      final map = <String, CardAvailability>{};
      for (final row in rows) {
        final id = row.read<String>('vault_item_id');
        final owned = row.read<int>('owned_quantity');
        final inDeck = row.read<int>('in_deck_quantity');
        final avail = row.read<int>('available_quantity');
        map[id] = CardAvailability(
          owned: owned,
          available: avail,
          inDeck: inDeck,
        );
      }
      return map;
    });
  }

  /// Streams deck versions history for active decks
  Stream<List<DeckVersion>> watchDeckVersions(String deckId) {
    final query = select(deckVersions).join([
      innerJoin(decks, decks.id.equalsExp(deckVersions.deckId)),
    ]);
    query.where(
      deckVersions.deckId.equals(deckId) &
          deckVersions.isDeleted.equals(false) &
          decks.isDeleted.equals(false),
    );
    query.orderBy([
      OrderingTerm(
          expression: deckVersions.createdAt, mode: OrderingMode.desc),
    ]);
    return query
        .watch()
        .map((rows) => rows.map((r) => r.readTable(deckVersions)).toList());
  }

  /// Streams deck matchups
  Stream<List<DeckMatchup>> watchDeckMatchups(String deckId) {
    return (select(deckMatchups)..where((t) => t.deckId.equals(deckId) & t.isDeleted.equals(false))).watch();
  }
  
  /// Update deck description
  Future<void> updateDeckDescription(String deckId, String description) async {
    final now = DateTime.now();
    await (update(decks)..where((t) => t.id.equals(deckId))).write(DecksCompanion(
      description: Value(description),
      updatedAt: Value(now),
    ));
    await _recordSync('deck', deckId, 'UPDATE', timestamp: now);
  }

  /// Creates a deck with custom format, tcgDomain, and initial registration/competitive flags.
  Future<Deck> createDeck(
    String name, {
    String format = 'Commander',
    String tcgDomain = 'mtg',
    bool isRegistered = false,
    bool isCompetitive = false,
  }) async {
    final now = DateTime.now();
    final deckId = const Uuid().v4();
    final deck = DecksCompanion.insert(
      id: deckId,
      name: name,
      format: format,
      tcgDomain: Value(tcgDomain),
      isRegistered: Value(isRegistered),
      isCompetitive: Value(isCompetitive),
      createdAt: now,
      isDeleted: const Value(false),
      updatedAt: Value(now),
    );
    await into(decks).insert(deck);
    await _recordSync('deck', deckId, 'INSERT', timestamp: now);
    
    final versionId = const Uuid().v4();
    final version = DeckVersionsCompanion.insert(
      id: versionId,
      deckId: deckId,
      versionNumber: 1,
      isActive: const Value(true),
      createdAt: now,
      isDeleted: const Value(false),
      updatedAt: Value(now),
    );
    await into(deckVersions).insert(version);
    await _recordSync('deck_version', versionId, 'INSERT', timestamp: now);
    
    return (await (select(decks)..where((t) => t.id.equals(deckId))).getSingle());
  }

  /// Adds a card to a deck version with specified boardZone and quantity.
  /// Supports multiple distinct commanders and zone isolation.
  Future<void> addCardToDeck(
    String deckId,
    String vaultItemId, {
    bool isProxy = false,
    String boardZone = 'Mainboard',
    int quantity = 1,
  }) async {
    final now = DateTime.now();
    var version = await (select(deckVersions)..where((t) => t.deckId.equals(deckId) & t.isActive.equals(true) & t.isDeleted.equals(false))).getSingleOrNull();
    if (version == null) {
      final existingDeck = await (select(decks)..where((t) => t.id.equals(deckId) & t.isDeleted.equals(false))).getSingleOrNull();
      if (existingDeck == null) {
        final mockMatch = MockDeckData.defaultDecks.where((d) => d.id == deckId).firstOrNull;
        final resolvedName = mockMatch?.name ?? 'Deck $deckId';
        final resolvedFormat = mockMatch?.format ?? 'Commander';
        final resolvedDomain = mockMatch?.tcgDomain ?? 'mtg';
        final resolvedRegistered = mockMatch?.isRegistered ?? false;
        final resolvedCompetitive = mockMatch?.isCompetitive ?? false;
        await into(decks).insert(DecksCompanion.insert(
          id: deckId,
          name: resolvedName,
          format: resolvedFormat,
          tcgDomain: Value(resolvedDomain),
          isRegistered: Value(resolvedRegistered),
          isCompetitive: Value(resolvedCompetitive),
          createdAt: now,
          isDeleted: const Value(false),
          updatedAt: Value(now),
        ));
        await _recordSync('deck', deckId, 'INSERT', timestamp: now);
      }
      final versionId = const Uuid().v4();
      await into(deckVersions).insert(DeckVersionsCompanion.insert(
        id: versionId,
        deckId: deckId,
        versionNumber: 1,
        isActive: const Value(true),
        createdAt: now,
        isDeleted: const Value(false),
        updatedAt: Value(now),
      ));
      await _recordSync('deck_version', versionId, 'INSERT', timestamp: now);
      version = await (select(deckVersions)..where((t) => t.id.equals(versionId))).getSingle();
    }

    // Normalize boardZone to canonical PascalCase
    final canonicalZone = _normalizeBoardZone(boardZone);
    
    final existing = await (select(deckVersionItems)
      ..where((t) =>
          t.versionId.equals(version!.id) &
          t.vaultItemId.equals(vaultItemId) &
          t.boardZone.equals(canonicalZone) &
          t.isProxy.equals(isProxy) &
          t.isDeleted.equals(false)))
      .getSingleOrNull();
      
    if (existing != null) {
      await update(deckVersionItems).replace(existing.copyWith(
        quantity: existing.quantity + quantity,
        updatedAt: Value(now),
      ));
      await _recordSync('deck_version_item', existing.id, 'UPDATE', timestamp: now);
    } else {
      final newDviId = const Uuid().v4();
      await into(deckVersionItems).insert(DeckVersionItemsCompanion.insert(
        id: newDviId,
        versionId: version.id,
        vaultItemId: vaultItemId,
        quantity: Value(quantity),
        boardZone: canonicalZone,
        isProxy: Value(isProxy),
        isDeleted: const Value(false),
        updatedAt: Value(now),
      ));
      await _recordSync('deck_version_item', newDviId, 'INSERT', timestamp: now);
    }

    await _syncItemDeckHistory(vaultItemId);
  }

  String _normalizeBoardZone(String zone) {
    final lower = zone.trim().toLowerCase();
    switch (lower) {
      case 'commander':
      case 'command':
      case 'cmd':
        return 'Commander';
      case 'sideboard':
      case 'side':
      case 'sb':
        return 'Sideboard';
      case 'maybeboard':
      case 'maybe':
      case 'mb':
        return 'Maybeboard';
      case 'companion':
      case 'comp':
        return 'Companion';
      case 'mainboard':
      case 'main':
      case 'deck':
      case 'primary':
      default:
        return 'Mainboard';
    }
  }

  Set<String> _getBoardZoneAliases(String zone) {
    final canonical = _normalizeBoardZone(zone);
    final rawLower = zone.trim().toLowerCase();
    final Set<String> aliases = {rawLower, canonical.toLowerCase()};
    switch (canonical) {
      case 'Commander':
        aliases.addAll(const ['commander', 'command', 'cmd']);
        break;
      case 'Sideboard':
        aliases.addAll(const ['sideboard', 'side', 'sb']);
        break;
      case 'Maybeboard':
        aliases.addAll(const ['maybeboard', 'maybe', 'mb']);
        break;
      case 'Companion':
        aliases.addAll(const ['companion', 'comp']);
        break;
      case 'Mainboard':
      default:
        aliases.addAll(const ['mainboard', 'main', 'deck', 'primary']);
        break;
    }
    return aliases;
  }

  /// Moves a physical card from an active deck to targetDeckId, prioritizing registered decks.
  Future<void> moveCardToDeck(String vaultItemId, String targetDeckId) async {
    final row = await customSelect(
      '''
      SELECT dvi.id as item_id
      FROM deck_version_items dvi
      INNER JOIN deck_versions dv ON dv.id = dvi.version_id
      INNER JOIN decks d ON d.id = dv.deck_id
      WHERE dvi.vault_item_id = ? AND dv.is_active = 1 AND dvi.is_proxy = 0
        AND dvi.is_deleted = 0 AND dv.is_deleted = 0 AND d.is_deleted = 0
      ORDER BY d.is_registered DESC
      LIMIT 1
      ''',
      variables: [Variable.withString(vaultItemId)],
      readsFrom: {deckVersionItems, deckVersions, decks},
    ).getSingleOrNull();
    
    if (row != null) {
      final itemId = row.data['item_id'] as String;
      final existing = await (select(deckVersionItems)..where((t) => t.id.equals(itemId) & t.isDeleted.equals(false))).getSingleOrNull();
      if (existing != null) {
        final now = DateTime.now();
        if (existing.quantity > 1) {
          await update(deckVersionItems).replace(existing.copyWith(
            quantity: existing.quantity - 1,
            updatedAt: Value(now),
          ));
          await _recordSync('deck_version_item', existing.id, 'UPDATE', timestamp: now);
        } else {
          await (update(deckVersionItems)..where((t) => t.id.equals(existing.id))).write(
            DeckVersionItemsCompanion(
              isDeleted: const Value(true),
              updatedAt: Value(now),
            ),
          );
          await _recordSync('deck_version_item', existing.id, 'DELETE', timestamp: now);
        }
      }
    }
    
    await addCardToDeck(targetDeckId, vaultItemId, isProxy: false);
  }

  /// Cascades deck ledger synchronization to all member vault items.
  Future<void> _cascadeSyncDeckMembers(String deckId) async {
    final rows = await customSelect(
      '''
      SELECT DISTINCT dvi.vault_item_id
      FROM deck_version_items dvi
      INNER JOIN deck_versions dv ON dv.id = dvi.version_id
      WHERE dv.deck_id = ? AND dv.is_active = 1
        AND dvi.is_deleted = 0 AND dv.is_deleted = 0
        AND dvi.vault_item_id IS NOT NULL
      ''',
      variables: [Variable.withString(deckId)],
      readsFrom: {deckVersionItems, deckVersions},
    ).get();

    for (final row in rows) {
      final vaultItemId = row.read<String>('vault_item_id');
      await _syncItemDeckHistory(vaultItemId);
    }
  }

  /// Sets physical registration status of a deck (Draft vs Registered).
  Future<void> setDeckRegistered(String deckId, bool isRegistered) async {
    final now = DateTime.now();
    await (update(decks)..where((t) => t.id.equals(deckId))).write(DecksCompanion(
      isRegistered: Value(isRegistered),
      isAssembled: Value(isRegistered),
      updatedAt: Value(now),
    ));
    await _recordSync('deck', deckId, 'UPDATE', timestamp: now);
    await _cascadeSyncDeckMembers(deckId);
  }

  /// Sets physical assembly status of a deck (Assembled vs Disassembled).
  Future<void> setDeckAssembled(String deckId, bool isAssembled) async {
    final now = DateTime.now();
    await (update(decks)..where((t) => t.id.equals(deckId))).write(DecksCompanion(
      isAssembled: Value(isAssembled),
      isRegistered: Value(isAssembled),
      updatedAt: Value(now),
    ));
    await _recordSync('deck', deckId, 'UPDATE', timestamp: now);
    await _cascadeSyncDeckMembers(deckId);
  }

  /// Updates the custom cover image and optional crop rect for a deck.
  /// Logs an UPDATE operation to SyncQueue for cloud sync.
  Future<void> updateDeckCover(
    String deckId,
    String? coverItemId, {
    String? coverCropRect,
  }) async {
    final now = DateTime.now();
    await (update(decks)..where((t) => t.id.equals(deckId))).write(
      DecksCompanion(
        coverItemId: Value(coverItemId),
        coverCropRect: Value(coverCropRect),
        updatedAt: Value(now),
      ),
    );
    await _recordSync('deck', deckId, 'UPDATE', timestamp: now);
  }

  /// Atomically moves card(s) between boards in an active deck version.
  ///
  /// Guarantees strict transactional isolation against TOCTOU concurrency races
  /// by performing candidate resolution, source quantity reads, target consolidation,
  /// and updates inside a single serialized SQLite transaction.
  Future<void> moveDeckItemBoard(
    String deckId,
    String itemId,
    String targetBoard, [
    int quantity = 1,
    String? sourceBoard,
  ]) async {
    final version = await (select(deckVersions)
          ..where((t) =>
              t.deckId.equals(deckId) &
              t.isActive.equals(true) &
              t.isDeleted.equals(false)))
        .getSingleOrNull();
    if (version == null) return;

    final canonicalTarget = _normalizeBoardZone(targetBoard);
    String? affectedVaultItemId;

    await transaction(() async {
      // 1. Query candidate items INSIDE the transaction to eliminate TOCTOU stale reads
      final query = select(deckVersionItems)
        ..where((t) =>
            t.versionId.equals(version.id) &
            t.isDeleted.equals(false) &
            (t.id.equals(itemId) | t.vaultItemId.equals(itemId)));

      final candidates = await query.get();
      if (candidates.isEmpty) return;

      // 2. Resolve sourceItem with alias and casing resilience
      final canonicalSource = (sourceBoard != null && sourceBoard.trim().isNotEmpty)
          ? _normalizeBoardZone(sourceBoard)
          : null;

      final sourceItem = candidates.where((i) => i.id == itemId).firstOrNull ??
          (canonicalSource != null
              ? candidates.where((i) {
                  final z = _normalizeBoardZone(i.boardZone);
                  return z.toLowerCase() == canonicalSource.toLowerCase() ||
                      i.boardZone.trim().toLowerCase() == sourceBoard!.trim().toLowerCase();
                }).firstOrNull
              : null) ??
          candidates.where((i) => _normalizeBoardZone(i.boardZone) != canonicalTarget).firstOrNull ??
          candidates.first;

      // 3. No-op if already on target board
      if (_normalizeBoardZone(sourceItem.boardZone) == canonicalTarget) return;

      // 4. Calculate move quantity based on the fresh, transactional quantity
      final now = DateTime.now();
      final moveQty = quantity <= 0
          ? sourceItem.quantity
          : math.min(quantity, sourceItem.quantity);
      if (moveQty <= 0) return;

      affectedVaultItemId = sourceItem.vaultItemId;

      // 5. Look up existing target row with case-insensitive and alias-tolerant zone matching
      final targetAliases = _getBoardZoneAliases(canonicalTarget);
      final existingTargets = await (select(deckVersionItems)
            ..where((t) {
              Expression<bool> zoneMatch = t.boardZone.lower().equals(canonicalTarget.toLowerCase());
              for (final alias in targetAliases) {
                zoneMatch = zoneMatch | t.boardZone.lower().equals(alias.toLowerCase());
              }
              return t.versionId.equals(version.id) &
                  t.vaultItemId.equals(sourceItem.vaultItemId) &
                  zoneMatch &
                  t.isProxy.equals(sourceItem.isProxy) &
                  t.isDeleted.equals(false);
            }))
          .get();
      final existingTarget = existingTargets.firstOrNull;

      if (existingTarget != null) {
        // Target row exists: increment target quantity and canonicalize zone
        await (update(deckVersionItems)..where((t) => t.id.equals(existingTarget.id)))
            .write(DeckVersionItemsCompanion(
          quantity: Value(existingTarget.quantity + moveQty),
          boardZone: Value(canonicalTarget),
          updatedAt: Value(now),
        ));
        await _recordSync('deck_version_item', existingTarget.id, 'UPDATE', timestamp: now);

        if (sourceItem.quantity > moveQty) {
          // Decrement source item and canonicalize zone
          await (update(deckVersionItems)..where((t) => t.id.equals(sourceItem.id)))
              .write(DeckVersionItemsCompanion(
            quantity: Value(sourceItem.quantity - moveQty),
            boardZone: Value(_normalizeBoardZone(sourceItem.boardZone)),
            updatedAt: Value(now),
          ));
          await _recordSync('deck_version_item', sourceItem.id, 'UPDATE', timestamp: now);
        } else {
          // Source item exhausted: soft-delete
          await (update(deckVersionItems)..where((t) => t.id.equals(sourceItem.id)))
              .write(DeckVersionItemsCompanion(
            isDeleted: const Value(true),
            updatedAt: Value(now),
          ));
          await _recordSync('deck_version_item', sourceItem.id, 'DELETE', timestamp: now);
        }
      } else {
        if (sourceItem.quantity == moveQty) {
          // Move entire row by updating boardZone to canonicalTarget
          await (update(deckVersionItems)..where((t) => t.id.equals(sourceItem.id)))
              .write(DeckVersionItemsCompanion(
            boardZone: Value(canonicalTarget),
            updatedAt: Value(now),
          ));
          await _recordSync('deck_version_item', sourceItem.id, 'UPDATE', timestamp: now);
        } else {
          // Partial move: decrement source row and insert new row in canonicalTarget
          await (update(deckVersionItems)..where((t) => t.id.equals(sourceItem.id)))
              .write(DeckVersionItemsCompanion(
            quantity: Value(sourceItem.quantity - moveQty),
            boardZone: Value(_normalizeBoardZone(sourceItem.boardZone)),
            updatedAt: Value(now),
          ));
          await _recordSync('deck_version_item', sourceItem.id, 'UPDATE', timestamp: now);

          final newDviId = const Uuid().v4();
          await into(deckVersionItems).insert(DeckVersionItemsCompanion.insert(
            id: newDviId,
            versionId: version.id,
            vaultItemId: sourceItem.vaultItemId,
            quantity: Value(moveQty),
            boardZone: canonicalTarget,
            isProxy: Value(sourceItem.isProxy),
            isDeleted: const Value(false),
            updatedAt: Value(now),
          ));
          await _recordSync('deck_version_item', newDviId, 'INSERT', timestamp: now);
        }
      }
    });

    if (affectedVaultItemId != null) {
      await _syncItemDeckHistory(affectedVaultItemId!);
    }
  }

  /// Idempotently consolidates duplicate VaultItem records sharing the exact same
  /// variant key (scryfall_id, finish).
  ///
  /// Remaps all assigned deck_version_items to the surviving primary record,
  /// aggregates owned quantity into the primary record, and soft-deletes duplicates
  /// with outbox entries in SyncQueue.
  Future<int> consolidateDuplicateVaultItems() async {
    final activeItems = await (select(vaultItems)
          ..where((t) => t.isDeleted.equals(false)))
        .get();

    // Group items by (scryfall_id, finish)
    final grouped = <String, List<VaultItem>>{};
    for (final item in activeItems) {
      final key = VaultVariantHelper.computeVariantKey(item);
      grouped.putIfAbsent(key, () => []).add(item);
    }

    int consolidatedRows = 0;
    final now = DateTime.now();

    await transaction(() async {
      for (final entry in grouped.entries) {
        final items = entry.value;
        if (items.length <= 1) continue;

        // Deterministic primary selection: prefer records with non-empty primaryBinderId,
        // or earliest acquiredDate.
        items.sort((a, b) {
          if (a.primaryBinderId != null && b.primaryBinderId == null) return -1;
          if (a.primaryBinderId == null && b.primaryBinderId != null) return 1;
          return a.acquiredDate.compareTo(b.acquiredDate);
        });

        final primary = items.first;
        final duplicates = items.sublist(1);
        final totalQuantity = items.fold<int>(0, (sum, i) => sum + i.quantity);

        for (final dup in duplicates) {
          // Remap deck_version_items
          await (update(deckVersionItems)
                ..where((t) => t.vaultItemId.equals(dup.id) & t.isDeleted.equals(false)))
              .write(DeckVersionItemsCompanion(
            vaultItemId: Value(primary.id),
            updatedAt: Value(now),
          ));

          // Soft delete duplicate vault item
          await (update(vaultItems)..where((t) => t.id.equals(dup.id))).write(
            VaultItemsCompanion(
              isDeleted: const Value(true),
              updatedAt: Value(now),
            ),
          );
          await _recordSync('vault_item', dup.id, 'DELETE', timestamp: now);
        }

        // Update primary item total quantity
        await (update(vaultItems)..where((t) => t.id.equals(primary.id))).write(
          VaultItemsCompanion(
            quantity: Value(totalQuantity),
            updatedAt: Value(now),
          ),
        );
        await _recordSync('vault_item', primary.id, 'UPDATE', timestamp: now);

        consolidatedRows += duplicates.length;
      }
    });

    return consolidatedRows;
  }

  /// Sets competitive status of a deck (Tournament vs Casual).
  Future<void> setDeckCompetitive(String deckId, bool isCompetitive) async {
    final now = DateTime.now();
    await (update(decks)..where((t) => t.id.equals(deckId))).write(DecksCompanion(
      isCompetitive: Value(isCompetitive),
      updatedAt: Value(now),
    ));
    await _recordSync('deck', deckId, 'UPDATE', timestamp: now);
  }

  /// Swaps physical printing assigned to a deck version item.
  /// Consolidates duplicate rows if the target printing is already present in the same zone,
  /// and synchronizes dynamicData['deck_history'] for both the former and replacement items.
  Future<void> swapDeckItemPrinting(String dviId, String newVaultItemId) async {
    final currentDvi = await (select(deckVersionItems)..where((t) => t.id.equals(dviId) & t.isDeleted.equals(false))).getSingleOrNull();
    if (currentDvi == null) return;
    final oldVaultItemId = currentDvi.vaultItemId;
    if (oldVaultItemId == newVaultItemId) return;

    final now = DateTime.now();
    // Check if target item already exists in the same version, zone, and proxy status
    final existingTarget = await (select(deckVersionItems)
      ..where((t) =>
          t.versionId.equals(currentDvi.versionId) &
          t.vaultItemId.equals(newVaultItemId) &
          t.boardZone.equals(currentDvi.boardZone) &
          t.isProxy.equals(currentDvi.isProxy) &
          t.isDeleted.equals(false)))
      .getSingleOrNull();

    if (existingTarget != null) {
      // Merge quantities and soft delete the duplicate row
      await (update(deckVersionItems)..where((t) => t.id.equals(existingTarget.id))).write(
        DeckVersionItemsCompanion(
          quantity: Value(existingTarget.quantity + currentDvi.quantity),
          updatedAt: Value(now),
        ),
      );
      await _recordSync('deck_version_item', existingTarget.id, 'UPDATE', timestamp: now);

      await (update(deckVersionItems)..where((t) => t.id.equals(dviId))).write(
        DeckVersionItemsCompanion(
          isDeleted: const Value(true),
          updatedAt: Value(now),
        ),
      );
      await _recordSync('deck_version_item', dviId, 'DELETE', timestamp: now);
    } else {
      await (update(deckVersionItems)..where((t) => t.id.equals(dviId))).write(
        DeckVersionItemsCompanion(
          vaultItemId: Value(newVaultItemId),
          updatedAt: Value(now),
        ),
      );
      await _recordSync('deck_version_item', dviId, 'UPDATE', timestamp: now);
    }

    // Synchronize deck history for both old and new vault items
    await _syncItemDeckHistory(oldVaultItemId);
    await _syncItemDeckHistory(newVaultItemId);
  }

  /// Finds all owned VaultItems with matching card name or oracle_id for swap printing sheet.
  /// Strictly filters quantity > 0 (physical copies in vault) and excludes currently assigned copy.
  Future<List<VaultItem>> getAlternativePrintings(
    String cardName, {
    String? oracleId,
    String? excludeVaultItemId,
  }) async {
    final clean = cardName.trim().toLowerCase();
    final cleanFirstFace = clean.contains('//') ? clean.split('//').first.trim() : clean;

    final items = await (select(vaultItems)
      ..where((t) => t.isDeleted.equals(false) & t.quantity.isBiggerThanValue(0))
      ..orderBy([(t) => OrderingTerm(expression: t.setOrSeries, mode: OrderingMode.asc)]))
      .get();

    return items.where((t) {
      if (excludeVaultItemId != null && t.id == excludeVaultItemId) {
        return false;
      }
      final nameLower = t.name.toLowerCase();
      final firstFaceLower = nameLower.contains('//') ? nameLower.split('//').first.trim() : nameLower;
      final flavorLower = t.flavorName?.toLowerCase();

      // 1. Check exact or front-face name match
      if (nameLower == clean || firstFaceLower == cleanFirstFace || (flavorLower != null && flavorLower == clean)) {
        return true;
      }

      // 2. Check oracle_id match if present
      if (oracleId != null && oracleId.isNotEmpty) {
        try {
          final dyn = jsonDecode(t.dynamicData) as Map<String, dynamic>;
          if (dyn['oracle_id'] == oracleId) return true;
        } catch (error, stackTrace) {
          debugPrint('[VaultDao._matchesItem] Oracle ID match decoding dynamicData failed: $error\n$stackTrace');
        }
      }

      return false;
    }).toList();
  }

  /// Finds all owned VaultItems with matching card name or oracle_id for swap printing sheet,
  /// with binder names and available physical quantity calculated in a single relational query.
  Future<List<AlternativePrintingDetail>> getAlternativePrintingsWithDetails(
    String cardName, {
    String? oracleId,
    String? excludeVaultItemId,
  }) async {
    final clean = cardName.trim().toLowerCase();
    final cleanFirstFace = clean.contains('//') ? clean.split('//').first.trim() : clean;

    final variables = <Variable>[];
    var excludeClause = '';
    if (excludeVaultItemId != null && excludeVaultItemId.isNotEmpty) {
      excludeClause = 'AND vi.id != ?';
      variables.add(Variable.withString(excludeVaultItemId));
    }

    var oracleClause = '';
    if (oracleId != null && oracleId.isNotEmpty) {
      oracleClause = '''
        OR vi.dynamic_data LIKE ?
        OR vi.dynamic_data LIKE ?
        OR json_extract(vi.dynamic_data, '\$.oracle_id') = ?
      ''';
    }

    variables.add(Variable.withString(clean));
    variables.add(Variable.withString(cleanFirstFace));
    variables.add(Variable.withString('$cleanFirstFace // %'));
    variables.add(Variable.withString(clean));
    if (oracleId != null && oracleId.isNotEmpty) {
      variables.add(Variable.withString('%"oracle_id":"$oracleId"%'));
      variables.add(Variable.withString('%"oracle_id": "$oracleId"%'));
      variables.add(Variable.withString(oracleId));
    }

    final querySql = '''
      SELECT 
        vi.*,
        vb.name AS binder_name,
        MAX(0, vi.quantity - COALESCE(alloc.total_allocated, 0)) AS available_quantity
      FROM vault_items vi
      LEFT JOIN vault_binders vb ON vb.id = vi.primary_binder_id
      LEFT JOIN (
        SELECT dvi.vault_item_id, SUM(dvi.quantity) AS total_allocated
        FROM deck_version_items dvi
        INNER JOIN deck_versions dv ON dv.id = dvi.version_id
        INNER JOIN decks d ON d.id = dv.deck_id
        WHERE dv.is_active = 1
          AND dvi.is_proxy = 0
          AND d.is_registered = 1
          AND dvi.is_deleted = 0
          AND dv.is_deleted = 0
          AND d.is_deleted = 0
        GROUP BY dvi.vault_item_id
      ) alloc ON alloc.vault_item_id = vi.id
      WHERE vi.quantity > 0
        AND vi.is_deleted = 0
        AND (vi.dynamic_data IS NULL OR (vi.dynamic_data NOT LIKE '%"layout":"art_series"%' AND vi.dynamic_data NOT LIKE '%"layout": "art_series"%'))
        $excludeClause
        AND (
          LOWER(vi.name) = ?
          OR LOWER(vi.name) = ?
          OR LOWER(vi.name) LIKE ?
          OR (vi.flavor_name IS NOT NULL AND LOWER(vi.flavor_name) = ?)
          $oracleClause
        )
      ORDER BY vi.set_or_series ASC;
    ''';

    final rows = await customSelect(
      querySql,
      variables: variables,
      readsFrom: {vaultItems, vaultBinders, deckVersionItems, deckVersions, decks},
    ).get();

    return rows.map((row) {
      final item = vaultItems.map(row.data);
      final availableQuantity = (row.data['available_quantity'] as num?)?.toInt() ?? 0;
      final dbBinderName = row.data['binder_name'] as String?;
      final String binderName;
      if (item.primaryBinderId == 'INBOX') {
        binderName = 'Inbox (Unsorted)';
      } else if (item.primaryBinderId != null && dbBinderName != null && dbBinderName.isNotEmpty) {
        binderName = dbBinderName;
      } else {
        binderName = 'Main Vault';
      }

      return AlternativePrintingDetail(
        item: item,
        availableQuantity: availableQuantity,
        binderName: binderName,
      );
    }).toList();
  }

  /// Updates a VaultItem's printing edition, set code, collector number, and art crop
  /// in place without deleting or re-scanning the card.
  /// Preserves: id, quantity, primaryBinderId, acquiredPrice, acquiredDate, personalNotes, condition.
  Future<VaultItem> switchCardPrinting({
    required String id,
    required String setCode,
    required String setName,
    required String collectorNumber,
    required String imageUrl,
    required double marketPrice,
    String? artCropUrl,
    String? treatment,
    Map<String, dynamic>? extraDynamicData,
  }) async {
    final existing = await (select(vaultItems)..where((t) => t.id.equals(id) & t.isDeleted.equals(false))).getSingleOrNull();
    if (existing == null) {
      throw StateError('VaultItem with id "$id" not found.');
    }

    Map<String, dynamic> data = {};
    if (existing.dynamicData.isNotEmpty) {
      try {
        data = jsonDecode(existing.dynamicData) as Map<String, dynamic>;
      } catch (error, stackTrace) {
        debugPrint('[VaultDao.switchCardPrinting] Failed decoding existing dynamicData: $error\n$stackTrace');
      }
    }

    // Merge new printing attributes into polymorphic dynamicData
    data['set'] = setCode.toLowerCase();
    data['set_code'] = setCode.toLowerCase();
    data['set_name'] = setName;
    data['collector_number'] = collectorNumber;
    if (treatment != null) {
      data['treatment'] = treatment;
      if (treatment.toLowerCase().contains('foil')) {
        final finishes = (data['finishes'] as List?)?.cast<String>() ?? [];
        if (!finishes.contains('foil')) finishes.add('foil');
        data['finishes'] = finishes;
      }
    }

    if (imageUrl.isNotEmpty || (artCropUrl != null && artCropUrl.isNotEmpty)) {
      final imageUris = Map<String, dynamic>.from((data['image_uris'] as Map?) ?? {});
      if (imageUrl.isNotEmpty) {
        imageUris['normal'] = imageUrl;
      }
      if (artCropUrl != null && artCropUrl.isNotEmpty) {
        imageUris['art_crop'] = artCropUrl;
      }
      data['image_uris'] = imageUris;
    }

    if (data['card_faces'] is List && (data['card_faces'] as List).isNotEmpty) {
      final faces = List<dynamic>.from(data['card_faces'] as List);
      final frontFace = Map<String, dynamic>.from(faces[0] as Map);
      final faceUris = Map<String, dynamic>.from((frontFace['image_uris'] as Map?) ?? {});
      if (imageUrl.isNotEmpty) {
        faceUris['normal'] = imageUrl;
        frontFace['image_url'] = imageUrl;
      }
      if (artCropUrl != null && artCropUrl.isNotEmpty) {
        faceUris['art_crop'] = artCropUrl;
      }
      frontFace['image_uris'] = faceUris;
      faces[0] = frontFace;
      data['card_faces'] = faces;
    }

    if (extraDynamicData != null && extraDynamicData.isNotEmpty) {
      if (extraDynamicData.containsKey('artist')) data['artist'] = extraDynamicData['artist'];
      if (extraDynamicData.containsKey('flavor_text')) data['flavor_text'] = extraDynamicData['flavor_text'];
      if (extraDynamicData.containsKey('rarity')) data['rarity'] = extraDynamicData['rarity'];
      if (extraDynamicData.containsKey('oracle_id')) data['oracle_id'] = extraDynamicData['oracle_id'];
    }

    final updatedSetOrSeries = treatment != null && treatment != 'Standard'
        ? '$setName ($treatment)'
        : setName;

    final now = DateTime.now();
    await (update(vaultItems)..where((t) => t.id.equals(id))).write(
      VaultItemsCompanion(
        setOrSeries: Value(updatedSetOrSeries),
        imageUrl: Value(imageUrl.isNotEmpty ? imageUrl : existing.imageUrl),
        currentMarketPrice: Value(marketPrice > 0 ? marketPrice : existing.currentMarketPrice),
        lastPriceUpdate: Value(now),
        dynamicData: Value(jsonEncode(data)),
        updatedAt: Value(now),
      ),
    );
    await _recordSync('vault_item', id, 'UPDATE', timestamp: now);

    return (select(vaultItems)..where((t) => t.id.equals(id))).getSingle();
  }

  /// Retrieves all catalog printings (owned and unowned reference dictionary)
  /// matching the card name or flavor name.
  Future<List<VaultItem>> getCatalogPrintings(String cardName, {String? oracleId}) async {
    final clean = cardName.trim().toLowerCase();
    final cleanFirstFace = clean.contains('//') ? clean.split('//').first.trim() : clean;

    final items = await (select(vaultItems)
      ..where((t) =>
          t.isDeleted.equals(false) &
          (t.name.lower().equals(clean) |
          t.name.lower().equals(cleanFirstFace) |
          (t.flavorName.isNotNull() & t.flavorName.lower().equals(clean))))
      ..orderBy([(t) => OrderingTerm(expression: t.setOrSeries, mode: OrderingMode.asc)]))
      .get();

    if (oracleId != null && oracleId.isNotEmpty) {
      final allMatchingOracle = await (select(vaultItems)
        ..where((t) => t.isDeleted.equals(false) & t.dynamicData.like('%"oracle_id":"$oracleId"%'))
        ..orderBy([(t) => OrderingTerm(expression: t.setOrSeries, mode: OrderingMode.asc)]))
        .get();
      final seenIds = items.map((e) => e.id).toSet();
      for (final it in allMatchingOracle) {
        if (!seenIds.contains(it.id)) {
          items.add(it);
          seenIds.add(it.id);
        }
      }
    }

    return items;
  }

  /// Resolves an assembly plan for a deck with physical inventory and binder breakdown.
  Future<DeckAssemblyPlan> getDeckAssemblyPlan(String deckId) async {
    final deck = await (select(decks)..where((t) => t.id.equals(deckId) & t.isDeleted.equals(false))).getSingleOrNull();
    final deckName = deck?.name ?? 'Deck $deckId';

    final querySql = '''
      SELECT 
        dvi.id AS dvi_id,
        dvi.version_id,
        dvi.vault_item_id,
        dvi.quantity AS deck_quantity,
        dvi.board_zone,
        dvi.is_proxy,
        vi.name AS card_name,
        vi.set_or_series,
        vi.image_url,
        vi.quantity AS vault_quantity,
        vi.primary_binder_id,
        vb.name AS binder_name,
        COALESCE(other_alloc.total_allocated, 0) AS other_allocated
      FROM deck_version_items dvi
      INNER JOIN deck_versions dv ON dv.id = dvi.version_id
      INNER JOIN vault_items vi ON vi.id = dvi.vault_item_id
      LEFT JOIN vault_binders vb ON vb.id = vi.primary_binder_id
      LEFT JOIN (
        SELECT dvi2.vault_item_id, SUM(dvi2.quantity) AS total_allocated
        FROM deck_version_items dvi2
        INNER JOIN deck_versions dv2 ON dv2.id = dvi2.version_id
        INNER JOIN decks d2 ON d2.id = dv2.deck_id
        WHERE dv2.is_active = 1
          AND dvi2.is_proxy = 0
          AND d2.is_registered = 1
          AND dvi2.is_deleted = 0
          AND dv2.is_deleted = 0
          AND d2.is_deleted = 0
          AND d2.id != ?
        GROUP BY dvi2.vault_item_id
      ) other_alloc ON other_alloc.vault_item_id = dvi.vault_item_id
      WHERE dv.deck_id = ? AND dv.is_active = 1
        AND dvi.is_deleted = 0
        AND dv.is_deleted = 0
        AND vi.is_deleted = 0
        AND (vb.is_deleted IS NULL OR vb.is_deleted = 0)
    ''';

    final rows = await customSelect(
      querySql,
      variables: [Variable.withString(deckId), Variable.withString(deckId)],
      readsFrom: {deckVersionItems, deckVersions, vaultItems, vaultBinders, decks},
    ).get();

    final items = <AssemblyPickItem>[];
    for (final row in rows) {
      final dviId = row.read<String>('dvi_id');
      final vaultItemId = row.read<String>('vault_item_id');
      final cardName = row.read<String>('card_name');
      final setCode = row.read<String>('set_or_series');
      final imageUrl = row.readNullable<String>('image_url');
      final zoneStr = row.read<String>('board_zone');
      final zone = BoardZone.fromString(zoneStr);
      final deckQty = row.read<int>('deck_quantity');
      final isProxy = row.read<bool>('is_proxy');
      final binderId = row.readNullable<String>('primary_binder_id');
      final binderName = row.readNullable<String>('binder_name');

      // Exclude wishlist/maybeboard from physical assembly
      if (zone == BoardZone.maybeboard) continue;

      final otherAlloc = (row.data['other_allocated'] as num?)?.toInt() ?? 0;
      final totalVaultQty = row.read<int>('vault_quantity');
      final avail = math.max(0, totalVaultQty - otherAlloc);
      final pull = isProxy ? 0 : math.min(deckQty, avail);
      final deficit = isProxy ? 0 : math.max(0, deckQty - avail);

      final locName = binderName != null && binderName.isNotEmpty
          ? binderName
          : 'Unsorted Vault';

      items.add(AssemblyPickItem(
        dviId: dviId,
        vaultItemId: vaultItemId,
        cardName: cardName,
        setCode: setCode,
        imageUrl: imageUrl,
        boardZone: zone,
        requiredQuantity: deckQty,
        availableQuantity: avail,
        pullQuantity: pull,
        deficitQuantity: deficit,
        binderId: binderId,
        locationName: locName,
        isProxy: isProxy,
      ));
    }

    final Map<String, List<AssemblyPickItem>> grouped = {};
    for (final it in items) {
      if (it.pullQuantity > 0) {
        grouped.putIfAbsent(it.locationName, () => []).add(it);
      }
    }
    final deficitItems = items.where((it) => it.hasDeficit).toList();

    return DeckAssemblyPlan(
      deckId: deckId,
      deckName: deckName,
      items: items,
      itemsByLocation: grouped,
      deficitItems: deficitItems,
    );
  }

  /// Persists deck registration and splits deficit items into physical and proxy rows.
  Future<void> registerDeckWithProxyResolution({
    required String deckId,
    required List<AssemblyPickItem> items,
  }) async {
    final now = DateTime.now();
    final version = await (select(deckVersions)
      ..where((t) => t.deckId.equals(deckId) & t.isActive.equals(true) & t.isDeleted.equals(false)))
      .getSingleOrNull();

    if (version != null) {
      for (final item in items) {
        if (item.hasDeficit) {
          final existingDvi = await (select(deckVersionItems)
            ..where((t) => t.id.equals(item.dviId) & t.isDeleted.equals(false)))
            .getSingleOrNull();

          if (existingDvi != null) {
            if (existingDvi.quantity <= item.deficitQuantity) {
              // Full deficit: mark row as proxy
              await (update(deckVersionItems)..where((t) => t.id.equals(existingDvi.id)))
                  .write(DeckVersionItemsCompanion(
                    isProxy: const Value(true),
                    updatedAt: Value(now),
                  ));
              await _recordSync('deck_version_item', existingDvi.id, 'UPDATE', timestamp: now);
            } else {
              // Partial deficit: split row
              final physicalQty = existingDvi.quantity - item.deficitQuantity;
              await (update(deckVersionItems)..where((t) => t.id.equals(existingDvi.id)))
                  .write(DeckVersionItemsCompanion(
                    quantity: Value(physicalQty),
                    updatedAt: Value(now),
                  ));
              await _recordSync('deck_version_item', existingDvi.id, 'UPDATE', timestamp: now);

              final existingProxy = await (select(deckVersionItems)
                ..where((t) =>
                    t.versionId.equals(version.id) &
                    t.vaultItemId.equals(existingDvi.vaultItemId) &
                    t.boardZone.equals(existingDvi.boardZone) &
                    t.isProxy.equals(true) &
                    t.isDeleted.equals(false)))
                .getSingleOrNull();

              if (existingProxy != null) {
                await (update(deckVersionItems)..where((t) => t.id.equals(existingProxy.id)))
                    .write(DeckVersionItemsCompanion(
                      quantity: Value(existingProxy.quantity + item.deficitQuantity),
                      updatedAt: Value(now),
                    ));
                await _recordSync('deck_version_item', existingProxy.id, 'UPDATE', timestamp: now);
              } else {
                final proxyDviId = const Uuid().v4();
                await into(deckVersionItems).insert(DeckVersionItemsCompanion.insert(
                  id: proxyDviId,
                  versionId: version.id,
                  vaultItemId: existingDvi.vaultItemId,
                  quantity: Value(item.deficitQuantity),
                  boardZone: existingDvi.boardZone,
                  isProxy: const Value(true),
                  isDeleted: const Value(false),
                  updatedAt: Value(now),
                ));
                await _recordSync('deck_version_item', proxyDviId, 'INSERT', timestamp: now);
              }
            }
          }
        }
      }
    }

    await setDeckRegistered(deckId, true);
  }

  /// Streams a map of deckId -> total allocated quantity for a vault item
  Stream<Map<String, int>> watchCardDeckAllocations(String vaultItemId) {
    Future<Map<String, int>> fetch() async {
      final querySql = '''
        SELECT dv.deck_id, COALESCE(SUM(dvi.quantity), 0) AS total_qty
        FROM deck_version_items dvi
        INNER JOIN deck_versions dv ON dv.id = dvi.version_id
        INNER JOIN decks d ON d.id = dv.deck_id
        WHERE dvi.vault_item_id = ? AND dv.is_active = 1
          AND dvi.is_deleted = 0 AND dv.is_deleted = 0 AND d.is_deleted = 0
        GROUP BY dv.deck_id
      ''';

      final rows = await customSelect(
        querySql,
        variables: [Variable.withString(vaultItemId)],
        readsFrom: {deckVersionItems, deckVersions, decks},
      ).get();

      final map = <String, int>{};
      for (final r in rows) {
        final deckId = r.read<String>('deck_id');
        final qty = r.read<int?>('total_qty') ?? 0;
        map[deckId] = qty;
      }
      return map;
    }

    Stream<Map<String, int>> generate() async* {
      yield await fetch();
      final updates = attachedDatabase.tableUpdates(
        TableUpdateQuery.onAllTables([deckVersionItems, deckVersions, decks]),
      );
      await for (final _ in updates) {
        yield await fetch();
      }
    }

    return generate().distinct(mapEquals);
  }

  /// Sets exact card quantity in active version of deck.
  Future<void> setCardQuantityInDeck(
    String deckId,
    String vaultItemId,
    int newQuantity, {
    String boardZone = 'Mainboard',
    bool isProxy = false,
  }) async {
    if (newQuantity <= 0) {
      await removeCardFromDeck(
        deckId,
        vaultItemId,
        quantity: 999999,
        boardZone: boardZone,
        isProxy: isProxy,
      );
      return;
    }

    final now = DateTime.now();
    var version = await (select(deckVersions)
          ..where((t) => t.deckId.equals(deckId) & t.isActive.equals(true) & t.isDeleted.equals(false)))
        .getSingleOrNull();

    if (version == null) {
      final existingDeck = await (select(decks)..where((t) => t.id.equals(deckId) & t.isDeleted.equals(false))).getSingleOrNull();
      if (existingDeck == null) {
        final mockMatch = MockDeckData.defaultDecks.where((d) => d.id == deckId).firstOrNull;
        final resolvedName = mockMatch?.name ?? 'Deck $deckId';
        final resolvedFormat = mockMatch?.format ?? 'Commander';
        final resolvedDomain = mockMatch?.tcgDomain ?? 'mtg';
        final resolvedRegistered = mockMatch?.isRegistered ?? false;
        final resolvedCompetitive = mockMatch?.isCompetitive ?? false;
        await into(decks).insert(DecksCompanion.insert(
          id: deckId,
          name: resolvedName,
          format: resolvedFormat,
          tcgDomain: Value(resolvedDomain),
          isRegistered: Value(resolvedRegistered),
          isCompetitive: Value(resolvedCompetitive),
          createdAt: now,
          isDeleted: const Value(false),
          updatedAt: Value(now),
        ));
        await _recordSync('deck', deckId, 'INSERT', timestamp: now);
      }
      final versionId = const Uuid().v4();
      await into(deckVersions).insert(DeckVersionsCompanion.insert(
        id: versionId,
        deckId: deckId,
        versionNumber: 1,
        isActive: const Value(true),
        createdAt: now,
        isDeleted: const Value(false),
        updatedAt: Value(now),
      ));
      await _recordSync('deck_version', versionId, 'INSERT', timestamp: now);
      version = await (select(deckVersions)..where((t) => t.id.equals(versionId))).getSingle();
    }

    final canonicalZone = _normalizeBoardZone(boardZone);
    final existing = await (select(deckVersionItems)
      ..where((t) =>
          t.versionId.equals(version!.id) &
          t.vaultItemId.equals(vaultItemId) &
          t.boardZone.equals(canonicalZone) &
          t.isProxy.equals(isProxy) &
          t.isDeleted.equals(false)))
      .getSingleOrNull();

    if (existing != null) {
      await (update(deckVersionItems)..where((t) => t.id.equals(existing.id))).write(
        DeckVersionItemsCompanion(
          quantity: Value(newQuantity),
          updatedAt: Value(now),
        ),
      );
      await _recordSync('deck_version_item', existing.id, 'UPDATE', timestamp: now);
    } else {
      final newDviId = const Uuid().v4();
      await into(deckVersionItems).insert(DeckVersionItemsCompanion.insert(
        id: newDviId,
        versionId: version!.id,
        vaultItemId: vaultItemId,
        quantity: Value(newQuantity),
        boardZone: canonicalZone,
        isProxy: Value(isProxy),
        isDeleted: const Value(false),
        updatedAt: Value(now),
      ));
      await _recordSync('deck_version_item', newDviId, 'INSERT', timestamp: now);
    }

    await _syncItemDeckHistory(vaultItemId);
  }

  /// Decrements or removes a card from a deck's active version.
  Future<void> removeCardFromDeck(
    String deckId,
    String vaultItemId, {
    int quantity = 1,
    String boardZone = 'Mainboard',
    bool? isProxy,
  }) async {
    final version = await (select(deckVersions)
          ..where((t) => t.deckId.equals(deckId) & t.isActive.equals(true) & t.isDeleted.equals(false)))
        .getSingleOrNull();
    if (version == null) return;

    final canonicalZone = _normalizeBoardZone(boardZone);
    final query = select(deckVersionItems)
      ..where((t) =>
          t.versionId.equals(version.id) &
          t.vaultItemId.equals(vaultItemId) &
          t.boardZone.equals(canonicalZone) &
          t.isDeleted.equals(false));
    if (isProxy != null) {
      query.where((t) => t.isProxy.equals(isProxy));
    }

    final items = await query.get();
    if (items.isEmpty) return;

    final now = DateTime.now();
    int remaining = quantity;
    for (final item in items) {
      if (remaining <= 0) break;
      if (item.quantity > remaining) {
        await (update(deckVersionItems)..where((t) => t.id.equals(item.id))).write(
          DeckVersionItemsCompanion(
            quantity: Value(item.quantity - remaining),
            updatedAt: Value(now),
          ),
        );
        await _recordSync('deck_version_item', item.id, 'UPDATE', timestamp: now);
        remaining = 0;
      } else {
        remaining -= item.quantity;
        // Soft delete D6: mark isDeleted = true instead of hard delete
        await (update(deckVersionItems)..where((t) => t.id.equals(item.id))).write(
          DeckVersionItemsCompanion(
            isDeleted: const Value(true),
            updatedAt: Value(now),
          ),
        );
        await _recordSync('deck_version_item', item.id, 'DELETE', timestamp: now);
      }
    }

    await _syncItemDeckHistory(vaultItemId);
  }

  /// Synchronizes VaultItem dynamicData['deck_history'] and assignment_history with currently assigned decks.
  Future<void> _syncItemDeckHistory(String vaultItemId) async {
    final activeDecks = await customSelect(
      '''
      SELECT d.id, d.name, d.is_assembled, d.is_registered, dvi.updated_at
      FROM deck_version_items dvi
      INNER JOIN deck_versions dv ON dv.id = dvi.version_id
      INNER JOIN decks d ON d.id = dv.deck_id
      WHERE dvi.vault_item_id = ? AND dv.is_active = 1
        AND dvi.is_deleted = 0 AND dv.is_deleted = 0 AND d.is_deleted = 0
      ''',
      variables: [Variable.withString(vaultItemId)],
      readsFrom: {deckVersionItems, deckVersions, decks},
    ).get();

    final formalDeckNames = <String>[];
    final draftEntries = <String>[];
    final seenDecks = <String>{};

    for (final row in activeDecks) {
      final name = row.read<String>('name');
      if (!seenDecks.add(name)) continue;

      final rawAssembled = row.data['is_assembled'];
      final rawRegistered = row.data['is_registered'];
      final isAssembled = rawAssembled == 1 ||
          rawAssembled == true ||
          rawRegistered == 1 ||
          rawRegistered == true;

      if (isAssembled) {
        formalDeckNames.add(name);
      } else {
        final rawDate = row.data['updated_at'];
        DateTime dt = DateTime.now();
        if (rawDate is DateTime) {
          dt = rawDate;
        } else if (rawDate is int) {
          dt = DateTime.fromMillisecondsSinceEpoch(
              rawDate * (rawDate < 10000000000 ? 1000 : 1));
        } else if (rawDate is String) {
          dt = DateTime.tryParse(rawDate) ?? DateTime.now();
        }
        final dateStr =
            '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
        draftEntries.add('Drafted in - $name - $dateStr');
      }
    }

    final allAssignmentEntries = <String>[...formalDeckNames, ...draftEntries];
    await updateItemNotesAndDecks(
      vaultItemId,
      deckTags: formalDeckNames,
      assignmentHistory: allAssignmentEntries,
    );
  }

  // ---------------------------------------------------------------------------
  // MILESTONE 3: VAULT COLLECTION VIEW & SET AGGREGATIONS
  // ---------------------------------------------------------------------------

  /// Streams aggregated set collections grouped by set_or_series,
  /// calculating total unique cards, unique owned cards (quantity > 0),
  /// and completion percentage (0.0 to 1.0).
  Stream<List<VaultSetCollection>> watchSetCollections({
    String? collectionType,
    String? searchQuery,
  }) {
    final variables = <Variable>[];
    final whereClauses = <String>[
      'is_deleted = 0',
      'set_or_series IS NOT NULL',
      "TRIM(set_or_series) != ''",
    ];

    if (collectionType != null) {
      final normalized = _normalizeCollectionType(collectionType);
      if (normalized != 'all') {
        whereClauses.add('collection_type = ?');
        variables.add(Variable.withString(normalized));
      }
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      whereClauses.add('(set_or_series LIKE ? OR name LIKE ? OR dynamic_data LIKE ?)');
      final term = '%${searchQuery.trim()}%';
      variables.add(Variable.withString(term));
      variables.add(Variable.withString(term));
      variables.add(Variable.withString(term));
    }

    final whereSql = whereClauses.join(' AND ');
    final querySql = '''
      SELECT
        set_or_series AS set_name,
        COALESCE(
          MAX(json_extract(dynamic_data, '\$.set_code')),
          MAX(json_extract(dynamic_data, '\$.set')),
          ''
        ) AS set_code,
        collection_type,
        COUNT(DISTINCT name) AS total_cards,
        COUNT(DISTINCT CASE WHEN quantity > 0 THEN name END) AS owned_cards,
        MAX(image_url) AS sample_image_url,
        MAX(json_extract(dynamic_data, '\$.released_at')) AS release_date
      FROM vault_items
      WHERE $whereSql
      GROUP BY set_or_series
    ''';

    return customSelect(
      querySql,
      variables: variables,
      readsFrom: {vaultItems},
    ).watch().map((rows) {
      final collections = rows.map((r) {
        final total = (r.data['total_cards'] as num?)?.toInt() ?? 0;
        final owned = (r.data['owned_cards'] as num?)?.toInt() ?? 0;
        final pct = total > 0 ? (owned / total).clamp(0.0, 1.0) : 0.0;
        return VaultSetCollection(
          setName: r.read<String>('set_name'),
          setCode: (r.data['set_code'] as String? ?? '').toUpperCase(),
          collectionType: r.read<String>('collection_type'),
          totalCount: total,
          ownedCount: owned,
          completionPercentage: pct,
          sampleImageUrl: r.data['sample_image_url'] as String?,
          releaseDate: r.data['release_date'] as String?,
        );
      }).toList();

      collections.sort((a, b) {
        // Primary: highest completion percentage descending (1.0 -> 0.0)
        final pctComp = b.completionPercentage.compareTo(a.completionPercentage);
        if (pctComp != 0) return pctComp;

        // Tie-breaker: release date newest to oldest (descending)
        final aDate = a.releaseDate ?? '';
        final bDate = b.releaseDate ?? '';
        final dateComp = bDate.compareTo(aDate);
        if (dateComp != 0) return dateComp;

        // Fallback: alphabetical set name ascending
        return a.setName.compareTo(b.setName);
      });

      return collections;
    });
  }

  /// Streams cards belonging to a given set, ordered by set code and collector number.
  Stream<List<VaultItem>> watchItemsBySet(
    String setName, {
    String? collectionType,
  }) {
    final query = select(vaultItems)
      ..where((t) => t.isDeleted.equals(false) & t.setOrSeries.equals(setName));
    if (collectionType != null) {
      final normalized = _normalizeCollectionType(collectionType);
      if (normalized != 'all') {
        query.where((t) => t.collectionType.equals(normalized));
      }
    }
    query.orderBy([
      (t) => OrderingTerm(
            expression: const CustomExpression<String>(
              "COALESCE(json_extract(vault_items.dynamic_data, '\$.set_code'), json_extract(vault_items.dynamic_data, '\$.set'), '')",
            ),
            mode: OrderingMode.asc,
          ),
      (t) => OrderingTerm(
            expression: const CustomExpression<String>(
              "CAST(COALESCE(json_extract(vault_items.dynamic_data, '\$.collector_number'), '0') AS INTEGER)",
            ),
            mode: OrderingMode.asc,
          ),
      (t) => OrderingTerm(
            expression: const CustomExpression<String>(
              "COALESCE(json_extract(vault_items.dynamic_data, '\$.collector_number'), vault_items.name)",
            ),
            mode: OrderingMode.asc,
          ),
      (t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc),
    ]);
    return query.watch();
  }

  /// Backward-compatible alias for watchItemsBySet
  Stream<List<VaultItem>> watchCardsBySet(
    String setName, {
    String? collectionType,
  }) =>
      watchItemsBySet(setName, collectionType: collectionType);
}

/// Model representing alternative physical printings with computed headroom and location details.
class AlternativePrintingDetail {
  final VaultItem item;
  final int availableQuantity;
  final String binderName;

  const AlternativePrintingDetail({
    required this.item,
    required this.availableQuantity,
    required this.binderName,
  });
}
