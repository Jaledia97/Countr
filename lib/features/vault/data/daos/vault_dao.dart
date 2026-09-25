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
import 'package:countr/features/vault/domain/models/vault_totals.dart';
import 'package:countr/features/vault/presentation/providers/mtg_filter_state.dart';

import 'package:countr/core/database/tables/decks/decks_table.dart';
import 'package:countr/core/database/tables/decks/deck_versions_table.dart';
import 'package:countr/core/database/tables/decks/deck_version_items_table.dart';
import 'package:countr/core/database/tables/decks/deck_matchups_table.dart';
import 'package:countr/core/database/tables/decks/deck_synergies_table.dart';

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
])
class VaultDao extends DatabaseAccessor<AppDatabase> with _$VaultDaoMixin {
  VaultDao(super.db);

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

    // Stage 1: Push down direct SQLite column where clauses
    if (mtgFilter != null && mtgFilter.isActive) {
      _applyMtgFilterStage1(query, mtgFilter);
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

    // Defer SQL limit when mtgFilter is active to avoid row starvation prior to Stage 2
    if (limit != null && (mtgFilter == null || !mtgFilter.isActive)) {
      query.limit(limit, offset: offset);
    }

    // Stage 2: In-memory stream mapping using mtgFilter.matches(item)
    return query.watch().map((items) {
      if (mtgFilter == null || !mtgFilter.isActive) return items;
      final filtered = items.where((item) => mtgFilter.matches(item)).toList();
      if (limit != null) {
        if (offset != null) {
          return filtered.skip(offset).take(limit).toList();
        }
        return filtered.take(limit).toList();
      }
      return filtered;
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

    // Stage 1: Push down direct SQLite column where clauses
    if (mtgFilter != null && mtgFilter.isActive) {
      _applyMtgFilterStage1(query, mtgFilter);
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

    // Defer SQL limit when mtgFilter is active to avoid row starvation prior to Stage 2
    if (limit != null && (mtgFilter == null || !mtgFilter.isActive)) {
      query.limit(limit, offset: offset);
    }

    final items = await query.get();

    // Stage 2: In-memory evaluation using mtgFilter.matches(item)
    if (mtgFilter == null || !mtgFilter.isActive) {
      return items;
    }

    final filtered = items.where((item) => mtgFilter.matches(item)).toList();
    if (limit != null) {
      if (offset != null) {
        return filtered.skip(offset).take(limit).toList();
      }
      return filtered.take(limit).toList();
    }
    return filtered;
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

  /// Applies Stage 1 SQL pushdown filters to the Drift query.
  void _applyMtgFilterStage1(
    SimpleSelectStatement<$VaultItemsTable, VaultItem> query,
    MtgFilterState filter,
  ) {
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
  }

  /// Streams reactive aggregate totals for vault items scoped to collection and binder.
  Stream<VaultTotals> watchVaultTotals({
    String? collectionType,
    String? binderId,
  }) {
    final whereClauses = <String>['"quantity" > 0'];
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
    final whereClauses = <String>['"quantity" > 0'];
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

  /// Queries vaultItems table with case-insensitive name or setOrSeries matching.
  /// Filters by normalized collection type if specified (unless 'all').
  /// Orders by name ASC and applies limit.
  Future<List<VaultItem>> searchCatalogCards(
    String query, {
    String? collectionType,
    int limit = 50,
  }) {
    final normalized =
        collectionType != null ? _normalizeCollectionType(collectionType) : 'all';
    final trimmed = query.trim();
    final q = select(vaultItems);

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
    q.limit(limit);

    return q.get();
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
            ),
          );
        } else {
          await (update(vaultItems)..where((t) => t.id.equals(cardId))).write(
            VaultItemsCompanion(
              quantity: Value(existing.quantity + quantityToAdd),
              primaryBinderId: Value(targetBinderId ?? existing.primaryBinderId),
              lastPriceUpdate: Value(now),
            ),
          );
        }
      }
    });
  }

  /// Updates personal notes and deck history tags for a vault item without wiping existing dynamicData.
  Future<int> updateItemNotesAndDecks(
    String id, {
    String? personalNotes,
    List<String>? deckTags,
    String? communityNotes,
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
    if (communityNotes != null) {
      data['use_cases'] = communityNotes;
    }

    return await (update(vaultItems)..where((t) => t.id.equals(id))).write(
      VaultItemsCompanion(
        personalNotes: personalNotes != null
            ? Value(personalNotes)
            : const Value.absent(),
        dynamicData: Value(jsonEncode(data)),
      ),
    );
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

    return await (update(vaultItems)..where((t) => t.id.equals(id))).write(
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
        lastPriceUpdate: Value(DateTime.now()),
      ),
    );
  }


  /// Retrieves a single vault item by ID.
  Future<VaultItem?> getItemById(String id) {
    return (select(vaultItems)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Watches a single vault item by ID reactively.
  Stream<VaultItem?> watchItemById(String id) {
    return (select(vaultItems)..where((t) => t.id.equals(id))).watchSingleOrNull();
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

  /// Seeds the 4 hyper-detailed mock records if the ledger is empty.
  Future<void> seedDatabase() async {
    final existing = await (select(vaultItems)..limit(1)).get();
    if (existing.isNotEmpty) return;

    final now = DateTime.now();

    await batch((b) {
      b.insertAll(vaultItems, [
        // 1. MTG: The One Ring
        VaultItemsCompanion.insert(
          id: 'item-mtg-one-ring',
          collectionType: 'mtg',
          name: 'The One Ring (Serialized #007/100)',
          setOrSeries: 'The Lord of the Rings: Tales of Middle-earth',
          imageUrl:
              'https://cards.scryfall.io/large/front/7/8/78038b95-30f2-4e4b-972f-04cfa65c275a.jpg',
          acquiredPrice: 15.00,
          acquiredDate: now.subtract(const Duration(days: 45)),
          quantity: const Value(1),
          condition: 'NM',
          isGraded: const Value(false),
          personalNotes: const Value(
              'Pulled from collector booster at TBS Comics. Serialized #007/100.'),
          currentMarketPrice: 45.50,
          lastPriceUpdate: now,
          dynamicData: jsonEncode({
            'mana': '{4}',
            'mana_cost': '{4}',
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

        // 2. Pokémon: Charizard ex
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
          currentMarketPrice: 3.25,
          lastPriceUpdate: now,
          dynamicData: '{"hp": 120, "stage": "Basic"}',
        ),

        // 3. Comic Book: Ultimate Fallout #4
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
          currentMarketPrice: 210.00,
          lastPriceUpdate: now,
          dynamicData: '{"issue": 1, "publisher": "Marvel"}',
        ),

        // 4. Sports Card: T.J. Watt Prizm Silver Rookie
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
          currentMarketPrice: 180.00,
          lastPriceUpdate: now,
          dynamicData:
              '{"sport": "Football", "team": "Steelers", "is_rookie": true}',
        ),
      ]);
    });
  }

  /// Inserts a new vault item.
  Future<int> insertItem(VaultItemsCompanion item) async =>
      await into(vaultItems).insert(item);

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

  /// Deletes all items (used for test resets).
  Future<int> clearAllItems() => delete(vaultItems).go();

  // ---------------------------------------------------------------------------
  // PHASE 3: VAULT BINDER METHODS
  // ---------------------------------------------------------------------------

  /// Streams all binders filtered by collection type (or all collections).
  Stream<List<VaultBinder>> watchBindersByCollection(String collectionType) {
    final normalized = _normalizeCollectionType(collectionType);
    final query = select(vaultBinders);
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
    final binder = VaultBindersCompanion.insert(
      id: id,
      name: name.trim().isEmpty ? 'Untitled Binder' : name.trim(),
      collectionType: normalized == 'all' ? 'mtg' : normalized,
      createdAt: DateTime.now(),
    );
    await into(vaultBinders).insert(binder);
    return (select(vaultBinders)..where((t) => t.id.equals(id))).getSingle();
  }

  /// Fetches a binder by its unique ID.
  Future<VaultBinder?> getBinderById(String binderId) {
    return (select(vaultBinders)..where((t) => t.id.equals(binderId))).getSingleOrNull();
  }

  /// Streams a map of binderId -> total items anchored inside that binder.
  Stream<Map<String, int>> watchBinderItemCounts() {
    final querySql = '''
      SELECT primary_binder_id, CAST(COALESCE(SUM(quantity), 0) AS INTEGER) AS total_count
      FROM vault_items
      WHERE quantity > 0
        AND primary_binder_id IS NOT NULL
        AND primary_binder_id != 'INBOX'
      GROUP BY primary_binder_id
    ''';

    return customSelect(
      querySql,
      readsFrom: {vaultItems},
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
    return (update(vaultItems)..where((t) => t.id.isIn(itemIds))).write(
      VaultItemsCompanion(
        primaryBinderId: Value(targetBinderId),
      ),
    );
  }

  /// Alias for assignItemsToBinder
  Future<int> moveItemsToBinder(
          List<String> itemIds, String targetBinderId) =>
      assignItemsToBinder(itemIds, targetBinderId);

  /// Streams all owned cards anchored to a specific physical binder.
  Stream<List<VaultItem>> watchItemsByBinder(String binderId) {
    return (select(vaultItems)
          ..where((t) =>
              t.primaryBinderId.equals(binderId) &
              t.quantity.isBiggerThanValue(0))
          ..orderBy([
            (t) => OrderingTerm(
                expression: t.lastPriceUpdate, mode: OrderingMode.desc),
            (t) => OrderingTerm(expression: t.name, mode: OrderingMode.asc),
          ]))
        .watch();
  }

  // ---------------------------------------------------------------------------
  // PHASE 3: INBOX HOLDING AREA
  // ---------------------------------------------------------------------------

  /// Streams all owned cards currently staged in the "Inbox" holding area (primaryBinderId == 'INBOX').
  Stream<List<VaultItem>> watchInboxItems() {
    return (select(vaultItems)
          ..where((t) =>
              t.primaryBinderId.equals('INBOX') &
              t.quantity.isBiggerThanValue(0))
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

  /// Permanently deletes a single item from SQLite by its ID.
  Future<int> deleteItem(String id) {
    return (delete(vaultItems)..where((t) => t.id.equals(id))).go();
  }

  /// Permanently deletes multiple items from SQLite by their IDs.
  Future<int> deleteItems(List<String> ids) {
    if (ids.isEmpty) return Future.value(0);
    return (delete(vaultItems)..where((t) => t.id.isIn(ids))).go();
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
              final pred = buildCollectorPred(t);
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
              ..where(buildCollectorPred)
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
        WHERE ${collection != 'all' ? '"collection_type" = ? AND ' : ''}
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
    final existing = await (select(vaultItems)..where((t) => t.id.equals(card.id)))
        .getSingleOrNull();

    if (existing == null) {
      await into(vaultItems).insert(
        VaultItemsCompanion.insert(
          id: card.id,
          collectionType: card.collectionType,
          name: card.name,
          setOrSeries: card.setOrSeries,
          imageUrl: card.imageUrl,
          acquiredPrice: card.currentMarketPrice,
          acquiredDate: DateTime.now(),
          quantity: const Value(1),
          condition: isFoil ? 'NM (Foil)' : 'NM',
          isGraded: const Value(false),
          personalNotes: isFoil
              ? const Value('Scanned Foil / Variant')
              : const Value('Edge Scanned'),
          currentMarketPrice: card.currentMarketPrice,
          lastPriceUpdate: DateTime.now(),
          dynamicData: card.dynamicData,
          primaryBinderId: const Value('INBOX'),
        ),
      );
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
          lastPriceUpdate: Value(DateTime.now()),
          condition:
              isFoil ? const Value('NM (Foil)') : Value(existing.condition),
          personalNotes: Value(newNotes),
        ),
      );
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
            ? Value(DateTime.now())
            : const Value.absent(),
      ),
    );
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
          const CustomExpression<bool>(
            "json_extract(vault_items.dynamic_data, '\$.is_universes_beyond') = 1",
          ) |
          t.dynamicData.like('%"is_universes_beyond":true%') |
          t.dynamicData.like('%"is_universes_beyond": true%'));

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
          const CustomExpression<bool>(
            "json_extract(vault_items.dynamic_data, '\$.is_universes_beyond') = 1",
          ) |
          t.dynamicData.like('%"is_universes_beyond":true%') |
          t.dynamicData.like('%"is_universes_beyond": true%'));

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

    final query = select(vaultItems);
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
          AND d.is_registered = 1
        GROUP BY dvi.vault_item_id
      ) alloc ON alloc.vault_item_id = vi.id
      WHERE vi.id = ?
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
          AND d.is_registered = 1
        GROUP BY dvi.vault_item_id
      ) alloc ON alloc.vault_item_id = vi.id
      WHERE vi.id = ?
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
  /// If [onlyRegistered] is true, only decks that lock physical inventory (d.is_registered == 1) are returned.
  Future<List<String>> getDecksUsingItem(String vaultItemId, {bool onlyRegistered = true}) async {
    final whereClause = onlyRegistered
        ? 'WHERE dvi.vault_item_id = ? AND dv.is_active = 1 AND dvi.is_proxy = 0 AND d.is_registered = 1'
        : 'WHERE dvi.vault_item_id = ? AND dv.is_active = 1 AND dvi.is_proxy = 0';

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

  /// Streams all decks
  Stream<List<Deck>> watchAllDecks() {
    return select(decks).watch();
  }

  /// Streams a single deck
  Stream<Deck> watchDeck(String id) {
    return (select(decks)..where((t) => t.id.equals(id))).watchSingle();
  }

  /// Streams a single deck or null if not found
  Stream<Deck?> watchDeckOrNull(String id) {
    return (select(decks)..where((t) => t.id.equals(id))).watchSingleOrNull();
  }

  /// Retrieves a single deck by ID or null if not found
  Future<Deck?> getDeck(String id) {
    return (select(decks)..where((t) => t.id.equals(id))).getSingleOrNull();
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
      INNER JOIN vault_items vi ON vi.id = dvi.vault_item_id
      WHERE dv.deck_id = ? AND dv.is_active = 1
    ''';
    
    return customSelect(
      querySql,
      variables: [Variable.withString(deckId)],
      readsFrom: {deckVersionItems, deckVersions, vaultItems},
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
    ''';

    return customSelect(
      querySql,
      variables: [Variable.withString(vaultItemId)],
      readsFrom: {deckVersionItems, deckVersions, decks},
    ).watch().map((rows) {
      return rows.map((r) => r.read<String>('name')).toList();
    });
  }

  /// Streams all active decks grouped by vault item id: `Map<String, List<String>>`
  Stream<Map<String, List<String>>> watchAllCardActiveDecks() {
    final querySql = '''
      SELECT DISTINCT dvi.vault_item_id, d.name
      FROM deck_version_items dvi
      INNER JOIN deck_versions dv ON dv.id = dvi.version_id
      INNER JOIN decks d ON d.id = dv.deck_id
      WHERE dv.is_active = 1 AND dvi.is_proxy = 0
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

  /// Streams deck versions history
  Stream<List<DeckVersion>> watchDeckVersions(String deckId) {
    return (select(deckVersions)
          ..where((t) => t.deckId.equals(deckId))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
        .watch();
  }

  /// Streams deck matchups
  Stream<List<DeckMatchup>> watchDeckMatchups(String deckId) {
    return (select(deckMatchups)..where((t) => t.deckId.equals(deckId))).watch();
  }
  
  /// Update deck description
  Future<void> updateDeckDescription(String deckId, String description) async {
    await (update(decks)..where((t) => t.id.equals(deckId))).write(DecksCompanion(
      description: Value(description),
    ));
  }

  /// Creates a deck with custom format, tcgDomain, and initial registration/competitive flags.
  Future<Deck> createDeck(
    String name, {
    String format = 'Commander',
    String tcgDomain = 'mtg',
    bool isRegistered = false,
    bool isCompetitive = false,
  }) async {
    final deckId = const Uuid().v4();
    final deck = DecksCompanion.insert(
      id: deckId,
      name: name,
      format: format,
      tcgDomain: Value(tcgDomain),
      isRegistered: Value(isRegistered),
      isCompetitive: Value(isCompetitive),
      createdAt: DateTime.now(),
    );
    await into(decks).insert(deck);
    
    final versionId = const Uuid().v4();
    final version = DeckVersionsCompanion.insert(
      id: versionId,
      deckId: deckId,
      versionNumber: 1,
      isActive: const Value(true),
      createdAt: DateTime.now(),
    );
    await into(deckVersions).insert(version);
    
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
    var version = await (select(deckVersions)..where((t) => t.deckId.equals(deckId) & t.isActive.equals(true))).getSingleOrNull();
    if (version == null) {
      final existingDeck = await (select(decks)..where((t) => t.id.equals(deckId))).getSingleOrNull();
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
          createdAt: DateTime.now(),
        ));
      }
      final versionId = const Uuid().v4();
      await into(deckVersions).insert(DeckVersionsCompanion.insert(
        id: versionId,
        deckId: deckId,
        versionNumber: 1,
        isActive: const Value(true),
        createdAt: DateTime.now(),
      ));
      version = await (select(deckVersions)..where((t) => t.id.equals(versionId))).getSingle();
    }

    // Normalize boardZone to canonical PascalCase
    final canonicalZone = _normalizeBoardZone(boardZone);
    
    final existing = await (select(deckVersionItems)
      ..where((t) =>
          t.versionId.equals(version!.id) &
          t.vaultItemId.equals(vaultItemId) &
          t.boardZone.equals(canonicalZone) &
          t.isProxy.equals(isProxy)))
      .getSingleOrNull();
      
    if (existing != null) {
      await update(deckVersionItems).replace(existing.copyWith(quantity: existing.quantity + quantity));
    } else {
      await into(deckVersionItems).insert(DeckVersionItemsCompanion.insert(
        id: const Uuid().v4(),
        versionId: version.id,
        vaultItemId: vaultItemId,
        quantity: Value(quantity),
        boardZone: canonicalZone,
        isProxy: Value(isProxy),
      ));
    }

    await _syncItemDeckHistory(vaultItemId);
  }

  String _normalizeBoardZone(String zone) {
    final lower = zone.trim().toLowerCase();
    switch (lower) {
      case 'commander':
        return 'Commander';
      case 'sideboard':
        return 'Sideboard';
      case 'maybeboard':
        return 'Maybeboard';
      case 'companion':
        return 'Companion';
      case 'mainboard':
      default:
        return 'Mainboard';
    }
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
      ORDER BY d.is_registered DESC
      LIMIT 1
      ''',
      variables: [Variable.withString(vaultItemId)],
      readsFrom: {deckVersionItems, deckVersions, decks},
    ).getSingleOrNull();
    
    if (row != null) {
      final itemId = row.data['item_id'] as String;
      final existing = await (select(deckVersionItems)..where((t) => t.id.equals(itemId))).getSingleOrNull();
      if (existing != null) {
        if (existing.quantity > 1) {
          await update(deckVersionItems).replace(existing.copyWith(quantity: existing.quantity - 1));
        } else {
          await delete(deckVersionItems).delete(existing);
        }
      }
    }
    
    await addCardToDeck(targetDeckId, vaultItemId, isProxy: false);
  }

  /// Sets physical registration status of a deck (Draft vs Registered).
  Future<void> setDeckRegistered(String deckId, bool isRegistered) async {
    await (update(decks)..where((t) => t.id.equals(deckId))).write(DecksCompanion(
      isRegistered: Value(isRegistered),
    ));
  }

  /// Sets competitive status of a deck (Tournament vs Casual).
  Future<void> setDeckCompetitive(String deckId, bool isCompetitive) async {
    await (update(decks)..where((t) => t.id.equals(deckId))).write(DecksCompanion(
      isCompetitive: Value(isCompetitive),
    ));
  }

  /// Swaps physical printing assigned to a deck version item.
  /// Consolidates duplicate rows if the target printing is already present in the same zone,
  /// and synchronizes dynamicData['deck_history'] for both the former and replacement items.
  Future<void> swapDeckItemPrinting(String dviId, String newVaultItemId) async {
    final currentDvi = await (select(deckVersionItems)..where((t) => t.id.equals(dviId))).getSingleOrNull();
    if (currentDvi == null) return;
    final oldVaultItemId = currentDvi.vaultItemId;
    if (oldVaultItemId == newVaultItemId) return;

    // Check if target item already exists in the same version, zone, and proxy status
    final existingTarget = await (select(deckVersionItems)
      ..where((t) =>
          t.versionId.equals(currentDvi.versionId) &
          t.vaultItemId.equals(newVaultItemId) &
          t.boardZone.equals(currentDvi.boardZone) &
          t.isProxy.equals(currentDvi.isProxy)))
      .getSingleOrNull();

    if (existingTarget != null) {
      // Merge quantities and remove the duplicate row
      await (update(deckVersionItems)..where((t) => t.id.equals(existingTarget.id))).write(
        DeckVersionItemsCompanion(quantity: Value(existingTarget.quantity + currentDvi.quantity)),
      );
      await (delete(deckVersionItems)..where((t) => t.id.equals(dviId))).go();
    } else {
      await (update(deckVersionItems)..where((t) => t.id.equals(dviId))).write(
        DeckVersionItemsCompanion(vaultItemId: Value(newVaultItemId)),
      );
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
      ..where((t) => t.quantity.isBiggerThanValue(0))
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
        GROUP BY dvi.vault_item_id
      ) alloc ON alloc.vault_item_id = vi.id
      WHERE vi.quantity > 0
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
    final existing = await (select(vaultItems)..where((t) => t.id.equals(id))).getSingleOrNull();
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

    if (artCropUrl != null && artCropUrl.isNotEmpty) {
      final imageUris = (data['image_uris'] as Map<String, dynamic>?) ?? {};
      imageUris['art_crop'] = artCropUrl;
      data['image_uris'] = imageUris;
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

    await (update(vaultItems)..where((t) => t.id.equals(id))).write(
      VaultItemsCompanion(
        setOrSeries: Value(updatedSetOrSeries),
        imageUrl: Value(imageUrl.isNotEmpty ? imageUrl : existing.imageUrl),
        currentMarketPrice: Value(marketPrice > 0 ? marketPrice : existing.currentMarketPrice),
        lastPriceUpdate: Value(DateTime.now()),
        dynamicData: Value(jsonEncode(data)),
      ),
    );

    return (select(vaultItems)..where((t) => t.id.equals(id))).getSingle();
  }

  /// Retrieves all catalog printings (owned and unowned reference dictionary)
  /// matching the card name or flavor name.
  Future<List<VaultItem>> getCatalogPrintings(String cardName, {String? oracleId}) async {
    final clean = cardName.trim().toLowerCase();
    final cleanFirstFace = clean.contains('//') ? clean.split('//').first.trim() : clean;

    final items = await (select(vaultItems)
      ..where((t) =>
          t.name.lower().equals(clean) |
          t.name.lower().equals(cleanFirstFace) |
          (t.flavorName.isNotNull() & t.flavorName.lower().equals(clean)))
      ..orderBy([(t) => OrderingTerm(expression: t.setOrSeries, mode: OrderingMode.asc)]))
      .get();

    if (oracleId != null && oracleId.isNotEmpty) {
      final allMatchingOracle = await (select(vaultItems)
        ..where((t) => t.dynamicData.like('%"oracle_id":"$oracleId"%'))
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
    final deck = await (select(decks)..where((t) => t.id.equals(deckId))).getSingleOrNull();
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
          AND d2.id != ?
        GROUP BY dvi2.vault_item_id
      ) other_alloc ON other_alloc.vault_item_id = dvi.vault_item_id
      WHERE dv.deck_id = ? AND dv.is_active = 1
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
    final version = await (select(deckVersions)
      ..where((t) => t.deckId.equals(deckId) & t.isActive.equals(true)))
      .getSingleOrNull();

    if (version != null) {
      for (final item in items) {
        if (item.hasDeficit) {
          final existingDvi = await (select(deckVersionItems)
            ..where((t) => t.id.equals(item.dviId)))
            .getSingleOrNull();

          if (existingDvi != null) {
            if (existingDvi.quantity <= item.deficitQuantity) {
              // Full deficit: mark row as proxy
              await (update(deckVersionItems)..where((t) => t.id.equals(existingDvi.id)))
                  .write(const DeckVersionItemsCompanion(isProxy: Value(true)));
            } else {
              // Partial deficit: split row
              final physicalQty = existingDvi.quantity - item.deficitQuantity;
              await (update(deckVersionItems)..where((t) => t.id.equals(existingDvi.id)))
                  .write(DeckVersionItemsCompanion(quantity: Value(physicalQty)));

              final existingProxy = await (select(deckVersionItems)
                ..where((t) =>
                    t.versionId.equals(version.id) &
                    t.vaultItemId.equals(existingDvi.vaultItemId) &
                    t.boardZone.equals(existingDvi.boardZone) &
                    t.isProxy.equals(true)))
                .getSingleOrNull();

              if (existingProxy != null) {
                await (update(deckVersionItems)..where((t) => t.id.equals(existingProxy.id)))
                    .write(DeckVersionItemsCompanion(
                      quantity: Value(existingProxy.quantity + item.deficitQuantity),
                    ));
              } else {
                await into(deckVersionItems).insert(DeckVersionItemsCompanion.insert(
                  id: const Uuid().v4(),
                  versionId: version.id,
                  vaultItemId: existingDvi.vaultItemId,
                  quantity: Value(item.deficitQuantity),
                  boardZone: existingDvi.boardZone,
                  isProxy: const Value(true),
                ));
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
        WHERE dvi.vault_item_id = ? AND dv.is_active = 1
        GROUP BY dv.deck_id
      ''';

      final rows = await customSelect(
        querySql,
        variables: [Variable.withString(vaultItemId)],
        readsFrom: {deckVersionItems, deckVersions},
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
        TableUpdateQuery.onAllTables([deckVersionItems, deckVersions]),
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

    var version = await (select(deckVersions)
          ..where((t) => t.deckId.equals(deckId) & t.isActive.equals(true)))
        .getSingleOrNull();

    if (version == null) {
      final existingDeck = await (select(decks)..where((t) => t.id.equals(deckId))).getSingleOrNull();
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
          createdAt: DateTime.now(),
        ));
      }
      final versionId = const Uuid().v4();
      await into(deckVersions).insert(DeckVersionsCompanion.insert(
        id: versionId,
        deckId: deckId,
        versionNumber: 1,
        isActive: const Value(true),
        createdAt: DateTime.now(),
      ));
      version = await (select(deckVersions)..where((t) => t.id.equals(versionId))).getSingle();
    }

    final canonicalZone = _normalizeBoardZone(boardZone);
    final existing = await (select(deckVersionItems)
      ..where((t) =>
          t.versionId.equals(version!.id) &
          t.vaultItemId.equals(vaultItemId) &
          t.boardZone.equals(canonicalZone) &
          t.isProxy.equals(isProxy)))
      .getSingleOrNull();

    if (existing != null) {
      await (update(deckVersionItems)..where((t) => t.id.equals(existing.id))).write(
        DeckVersionItemsCompanion(quantity: Value(newQuantity)),
      );
    } else {
      await into(deckVersionItems).insert(DeckVersionItemsCompanion.insert(
        id: const Uuid().v4(),
        versionId: version.id,
        vaultItemId: vaultItemId,
        quantity: Value(newQuantity),
        boardZone: canonicalZone,
        isProxy: Value(isProxy),
      ));
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
          ..where((t) => t.deckId.equals(deckId) & t.isActive.equals(true)))
        .getSingleOrNull();
    if (version == null) return;

    final canonicalZone = _normalizeBoardZone(boardZone);
    final query = select(deckVersionItems)
      ..where((t) =>
          t.versionId.equals(version.id) &
          t.vaultItemId.equals(vaultItemId) &
          t.boardZone.equals(canonicalZone));
    if (isProxy != null) {
      query.where((t) => t.isProxy.equals(isProxy));
    }

    final items = await query.get();
    if (items.isEmpty) return;

    int remaining = quantity;
    for (final item in items) {
      if (remaining <= 0) break;
      if (item.quantity > remaining) {
        await (update(deckVersionItems)..where((t) => t.id.equals(item.id))).write(
          DeckVersionItemsCompanion(quantity: Value(item.quantity - remaining)),
        );
        remaining = 0;
      } else {
        remaining -= item.quantity;
        await (delete(deckVersionItems)..where((t) => t.id.equals(item.id))).go();
      }
    }

    await _syncItemDeckHistory(vaultItemId);
  }

  /// Synchronizes VaultItem dynamicData['deck_history'] with currently assigned decks.
  Future<void> _syncItemDeckHistory(String vaultItemId) async {
    final activeDecks = await customSelect(
      '''
      SELECT DISTINCT d.name
      FROM deck_version_items dvi
      INNER JOIN deck_versions dv ON dv.id = dvi.version_id
      INNER JOIN decks d ON d.id = dv.deck_id
      WHERE dvi.vault_item_id = ? AND dv.is_active = 1
      ''',
      variables: [Variable.withString(vaultItemId)],
      readsFrom: {deckVersionItems, deckVersions, decks},
    ).get();

    final deckNames = activeDecks.map((r) => r.read<String>('name')).toList();
    await updateItemNotesAndDecks(vaultItemId, deckTags: deckNames);
  }
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
