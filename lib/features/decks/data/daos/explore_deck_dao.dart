import 'dart:convert';
import 'dart:math' as math;
import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/database/tables/decks/explore_decks_table.dart';
import 'package:countr/core/database/tables/decks/explore_deck_items_table.dart';
import 'package:countr/core/database/tables/decks/explore_deck_votes_table.dart';
import 'package:countr/core/database/tables/decks/decks_table.dart';
import 'package:countr/core/database/tables/decks/deck_versions_table.dart';
import 'package:countr/core/database/tables/decks/deck_version_items_table.dart';
import 'package:countr/core/database/tables/vault_items_table.dart';
import 'package:countr/core/database/tables/sync_queue_table.dart';
import 'package:countr/features/decks/data/services/mtgjson_precon_parser.dart';
import 'package:countr/features/decks/domain/models/explore_deck_models.dart';
import 'package:countr/features/decks/data/mock_deck_data.dart';

part 'explore_deck_dao.g.dart';

/// Contract interface for Explore Decks data access.
abstract class ExploreDeckDaoInterface {
  Stream<List<ExploreDeckWithVote>> watchExploreDecks({
    ExploreCategory category = ExploreCategory.all,
    ExploreSortOption sort = ExploreSortOption.popularity,
    ExploreFilterState? filter,
    String searchQuery = '',
    String? featuredCategory,
    String userId = 'local_user',
    int? limit,
    int? offset,
    bool balanceFeed = false,
  });

  /// Streams the true total database count (SELECT COUNT(*)) of explore decks
  /// matching the given category, filters, and search query.
  /// Completely independent of pagination limit and offset.
  Stream<int> watchFilteredExploreDeckCount({
    ExploreCategory category = ExploreCategory.all,
    ExploreFilterState? filter,
    String searchQuery = '',
    String? featuredCategory,
    String? currentUserId,
  });

  /// One-shot query to fetch the true total database count of explore decks
  /// matching the given category, filters, and search query.
  Future<int> getFilteredExploreDeckCount({
    ExploreCategory category = ExploreCategory.all,
    ExploreFilterState? filter,
    String searchQuery = '',
    String? featuredCategory,
    String? currentUserId,
  });

  Stream<List<ExploreDeckWithVote>> watchFeaturedCategory(
    String category, {
    String userId = 'local_user',
    int? limit = 15,
  });

  Stream<ExploreDeckWithVote?> watchExploreDeck(
    String deckId, {
    String userId = 'local_user',
  });

  Stream<List<ExploreDeckItem>> watchExploreDeckItems(String deckId);

  Stream<ExploreDeckDetail?> watchExploreDeckDetail(
    String deckId, {
    String userId = 'local_user',
  });

  Future<ExploreDeckWithVote?> getExploreDeck(
    String deckId, {
    String userId = 'local_user',
  });

  Future<List<ExploreDeckItem>> getExploreDeckItems(String deckId);

  Future<VoteResult> castVote({
    required String deckId,
    String userId = 'local_user',
    required int targetVote,
    bool toggle = true,
  });

  Future<ExploreSearchResults> searchExploreDecks({
    required String query,
    String userId = 'local_user',
    int limitPerTier = 20,
  });

  Future<int> getExploreDeckCount();

  Future<void> batchInsertExploreDecks(List<ExploreDecksCompanion> decks);

  Future<void> batchInsertExploreDeckItems(
    List<ExploreDeckItemsCompanion> items, {
    int chunkSize = 250,
  });

  Future<void> clearExploreDecks();

  Future<ExploreDeck> sharePersonalDeckToExplore({
    required String personalDeckId,
    String creatorName = '@CurrentUser',
    String? authorId,
    String? customDescription,
  });

  Future<Deck> cloneExploreDeckToPersonal({
    required String exploreDeckId,
  });

  Future<List<ExploreDeckItem>> hydrateOfficialDeckItems({
    required String exploreDeckId,
    http.Client? httpClient,
  });

  String resolveMtgjsonFileName(ExploreDeck deck);

  Future<void> unpublishExploreDeck({
    required String exploreDeckId,
  });

  Future<int> getVoteCountSince(DateTime cutoff);

  Stream<int> watchVoteActivity();

  Stream<List<ExploreDeckWithVote>> watchDecksByVoteVelocity({
    required DateTime cutoff,
    int limit = 15,
    String userId = 'local_user',
  });

  Stream<List<ExploreDeckWithVote>> watchDecksForAlgorithmicCategory(
    String categoryKeyOrTitle, {
    int? limit = 15,
    String userId = 'local_user',
  });
}

/// Drift DAO managing explore decks, items, persistent voting, search, and cloning.
@DriftAccessor(tables: [
  ExploreDecks,
  ExploreDeckItems,
  ExploreDeckVotes,
  Decks,
  DeckVersions,
  DeckVersionItems,
  VaultItems,
  SyncQueue,
])
class ExploreDeckDao extends DatabaseAccessor<AppDatabase>
    with _$ExploreDeckDaoMixin
    implements ExploreDeckDaoInterface {
  ExploreDeckDao(super.db);

  // ===========================================================================
  // 1. REACTIVE STREAM QUERIES
  // ===========================================================================

  @override
  Stream<List<ExploreDeckWithVote>> watchExploreDecks({
    ExploreCategory category = ExploreCategory.all,
    ExploreSortOption sort = ExploreSortOption.popularity,
    ExploreFilterState? filter,
    String searchQuery = '',
    String? featuredCategory,
    String userId = 'local_user',
    int? limit,
    int? offset,
    bool balanceFeed = false,
  }) {
    final (sql, variables, needsItemsTable) = _buildFeedQuery(
      category: category,
      sort: sort,
      filter: filter,
      searchQuery: searchQuery,
      featuredCategory: featuredCategory,
      userId: userId,
      limit: limit,
      offset: offset,
      balanceFeed: balanceFeed,
    );

    final tablesToWatch = <TableInfo>{
      exploreDecks,
      exploreDeckVotes,
      if (needsItemsTable) exploreDeckItems,
    };

    return customSelect(
      sql,
      variables: variables,
      readsFrom: tablesToWatch,
    ).watch().map((rows) {
      return rows.map((row) {
        final deck = exploreDecks.map(row.data);
        final vote = row.read<int>('user_vote');
        return ExploreDeckWithVote(deck: deck, userVote: vote);
      }).toList();
    });
  }

  @override
  Stream<int> watchFilteredExploreDeckCount({
    ExploreCategory category = ExploreCategory.all,
    ExploreFilterState? filter,
    String searchQuery = '',
    String? featuredCategory,
    String? currentUserId,
  }) {
    final (whereClauses, variables, needsItemsTable) =
        _buildExploreWhereClauses(
      category: category,
      filter: filter,
      searchQuery: searchQuery,
      featuredCategory: featuredCategory,
      currentUserId: currentUserId,
    );

    final sql = '''
      SELECT CAST(COUNT(*) AS INTEGER) AS count
      FROM explore_decks ed
      WHERE ${whereClauses.join(' AND ')}
    ''';

    final tablesToWatch = <TableInfo>{
      exploreDecks,
      if (needsItemsTable) exploreDeckItems,
    };

    return customSelect(
      sql,
      variables: variables,
      readsFrom: tablesToWatch,
    ).watchSingle().map((row) => row.read<int?>('count') ?? 0);
  }

  @override
  Future<int> getFilteredExploreDeckCount({
    ExploreCategory category = ExploreCategory.all,
    ExploreFilterState? filter,
    String searchQuery = '',
    String? featuredCategory,
    String? currentUserId,
  }) async {
    final (whereClauses, variables, _) = _buildExploreWhereClauses(
      category: category,
      filter: filter,
      searchQuery: searchQuery,
      featuredCategory: featuredCategory,
      currentUserId: currentUserId,
    );

    final sql = '''
      SELECT CAST(COUNT(*) AS INTEGER) AS count
      FROM explore_decks ed
      WHERE ${whereClauses.join(' AND ')}
    ''';

    final row = await customSelect(
      sql,
      variables: variables,
      readsFrom: {exploreDecks},
    ).getSingleOrNull();

    return row?.read<int?>('count') ?? 0;
  }

  @override
  Stream<List<ExploreDeckWithVote>> watchFeaturedCategory(
    String category, {
    String userId = 'local_user',
    int? limit = 15,
  }) {
    if (category == "Today's Picks") {
      return watchDecksByVoteVelocity(
        cutoff: DateTime.now().subtract(const Duration(hours: 48)),
        limit: limit ?? 15,
        userId: userId,
      );
    }
    if (category == "This Week's Picks") {
      return watchDecksByVoteVelocity(
        cutoff: DateTime.now().subtract(const Duration(days: 7)),
        limit: limit ?? 15,
        userId: userId,
      );
    }
    if (category == "This Month's Picks") {
      return watchDecksByVoteVelocity(
        cutoff: DateTime.now().subtract(const Duration(days: 30)),
        limit: limit ?? 15,
        userId: userId,
      );
    }

    const lateralCategories = {
      'trending_budget_brews',
      r"Trending Budget Brews (<$100)",
      'mono_color_commanders',
      'Most Upvoted Mono-Color Commanders',
      'hot_new_precons',
      'Hot New Precons',
      'tribal_spotlight',
      'Tribal Spotlight',
      'rising_community_builders',
      'Rising Community Builders',
      'top_modern_decks',
      'Top Modern Decks',
      'pioneer_showdown',
      'Pioneer Showdown',
    };
    if (lateralCategories.contains(category)) {
      return watchDecksForAlgorithmicCategory(
        category,
        limit: limit,
        userId: userId,
      );
    }

    final String sourceFilter;
    if (category == 'From Top Deck Builders') {
      sourceFilter = " AND ed.source_type IN ('community', 'user_shared')";
    } else if (category == 'Featured Preconstructed Decks') {
      sourceFilter = " AND ed.source_type = 'official'";
    } else {
      sourceFilter = "";
    }

    var querySql = '''
      SELECT ed.*, COALESCE(v.vote, 0) AS user_vote
      FROM explore_decks ed
      LEFT JOIN explore_deck_votes v 
        ON v.explore_deck_id = ed.id AND v.user_id = ?
      WHERE ed.featured_category = ? AND ed.is_deleted = 0$sourceFilter
      ORDER BY ed.score DESC, ed.created_at DESC
    ''';

    final variables = <Variable>[
      Variable.withString(userId),
      Variable.withString(category),
    ];

    if (limit != null) {
      querySql += ' LIMIT ?;';
      variables.add(Variable.withInt(limit));
    } else {
      querySql += ';';
    }

    return customSelect(
      querySql,
      variables: variables,
      readsFrom: {exploreDecks, exploreDeckVotes},
    ).watch().map((rows) {
      return rows.map((row) {
        final deck = exploreDecks.map(row.data);
        final vote = row.read<int>('user_vote');
        return ExploreDeckWithVote(deck: deck, userVote: vote);
      }).toList();
    });
  }

  @override
  Future<int> getVoteCountSince(DateTime cutoff) async {
    const sql = '''
      SELECT CAST(COUNT(*) AS INTEGER) AS vote_count
      FROM explore_deck_votes
      WHERE is_deleted = 0
        AND vote != 0
        AND updated_at >= ?;
    ''';
    final row = await customSelect(
      sql,
      variables: [Variable.withDateTime(cutoff)],
      readsFrom: {exploreDeckVotes},
    ).getSingleOrNull();
    return row?.read<int?>('vote_count') ?? 0;
  }

  @override
  Stream<int> watchVoteActivity() {
    const sql = '''
      SELECT CAST(COUNT(*) AS INTEGER) AS total_votes
      FROM explore_deck_votes
      WHERE is_deleted = 0 AND vote != 0;
    ''';
    return customSelect(
      sql,
      readsFrom: {exploreDeckVotes},
    ).watchSingle().map((row) => row.read<int?>('total_votes') ?? 0);
  }

  @override
  Stream<List<ExploreDeckWithVote>> watchDecksByVoteVelocity({
    required DateTime cutoff,
    int limit = 15,
    String userId = 'local_user',
  }) {
    const sql = '''
      SELECT ed.*,
             COALESCE(v_user.vote, 0) AS user_vote,
             COALESCE(velocity.net_votes, 0) AS window_velocity
      FROM explore_decks ed
      LEFT JOIN explore_deck_votes v_user
        ON v_user.explore_deck_id = ed.id AND v_user.user_id = ?
      LEFT JOIN (
        SELECT explore_deck_id,
               SUM(vote) AS net_votes,
               COUNT(*) AS total_votes
        FROM explore_deck_votes
        WHERE is_deleted = 0
          AND vote != 0
          AND updated_at >= ?
        GROUP BY explore_deck_id
      ) velocity ON velocity.explore_deck_id = ed.id
      WHERE ed.is_deleted = 0
      ORDER BY COALESCE(velocity.net_votes, 0) DESC,
               ed.score DESC,
               ed.upvotes DESC,
               ed.created_at DESC
      LIMIT ?;
    ''';

    return customSelect(
      sql,
      variables: [
        Variable.withString(userId),
        Variable.withDateTime(cutoff),
        Variable.withInt(limit),
      ],
      readsFrom: {exploreDecks, exploreDeckVotes},
    ).watch().map((rows) {
      return rows.map((row) {
        final deck = exploreDecks.map(row.data);
        final userVote = row.read<int>('user_vote');
        return ExploreDeckWithVote(deck: deck, userVote: userVote);
      }).toList();
    });
  }

  @override
  Stream<List<ExploreDeckWithVote>> watchDecksForAlgorithmicCategory(
    String categoryKeyOrTitle, {
    int? limit = 15,
    String userId = 'local_user',
  }) {
    return watchExploreDecks(
      category: ExploreCategory.all,
      featuredCategory: categoryKeyOrTitle,
      userId: userId,
      limit: limit,
    );
  }

  @override
  Stream<ExploreDeckWithVote?> watchExploreDeck(
    String deckId, {
    String userId = 'local_user',
  }) {
    const querySql = '''
      SELECT ed.*, COALESCE(v.vote, 0) AS user_vote
      FROM explore_decks ed
      LEFT JOIN explore_deck_votes v 
        ON v.explore_deck_id = ed.id AND v.user_id = ?
      WHERE ed.id = ? AND ed.is_deleted = 0
      LIMIT 1;
    ''';

    return customSelect(
      querySql,
      variables: [Variable.withString(userId), Variable.withString(deckId)],
      readsFrom: {exploreDecks, exploreDeckVotes},
    ).watchSingleOrNull().map((row) {
      if (row == null) return null;
      return ExploreDeckWithVote(
        deck: exploreDecks.map(row.data),
        userVote: row.read<int>('user_vote'),
      );
    });
  }

  @override
  Stream<List<ExploreDeckItem>> watchExploreDeckItems(String deckId) {
    return (select(exploreDeckItems)
          ..where((t) => t.exploreDeckId.equals(deckId) & t.isDeleted.equals(false))
          ..orderBy([
            (t) => OrderingTerm(expression: t.isCommander, mode: OrderingMode.desc),
            (t) => OrderingTerm(expression: t.cardName, mode: OrderingMode.asc),
          ]))
        .watch();
  }

  @override
  Stream<ExploreDeckDetail?> watchExploreDeckDetail(
    String deckId, {
    String userId = 'local_user',
  }) {
    return watchExploreDeck(deckId, userId: userId).asyncMap((deckWithVote) async {
      if (deckWithVote == null) return null;
      final items = await getExploreDeckItems(deckId);
      return ExploreDeckDetail(
        deckWithVote: deckWithVote,
        cards: items,
      );
    });
  }

  @override
  Future<ExploreDeckWithVote?> getExploreDeck(
    String deckId, {
    String userId = 'local_user',
  }) async {
    const querySql = '''
      SELECT ed.*, COALESCE(v.vote, 0) AS user_vote
      FROM explore_decks ed
      LEFT JOIN explore_deck_votes v 
        ON v.explore_deck_id = ed.id AND v.user_id = ?
      WHERE ed.id = ? AND ed.is_deleted = 0
      LIMIT 1;
    ''';

    final row = await customSelect(
      querySql,
      variables: [Variable.withString(userId), Variable.withString(deckId)],
      readsFrom: {exploreDecks, exploreDeckVotes},
    ).getSingleOrNull();

    if (row == null) return null;
    return ExploreDeckWithVote(
      deck: exploreDecks.map(row.data),
      userVote: row.read<int>('user_vote'),
    );
  }

  @override
  Future<List<ExploreDeckItem>> getExploreDeckItems(String deckId) {
    return (select(exploreDeckItems)
          ..where((t) => t.exploreDeckId.equals(deckId) & t.isDeleted.equals(false))
          ..orderBy([
            (t) => OrderingTerm(expression: t.isCommander, mode: OrderingMode.desc),
            (t) => OrderingTerm(expression: t.cardName, mode: OrderingMode.asc),
          ]))
        .get();
  }

  // ===========================================================================
  // 2. ATOMIC VOTING ENGINE
  // ===========================================================================

  @override
  Future<VoteResult> castVote({
    required String deckId,
    String userId = 'local_user',
    required int targetVote,
    bool toggle = true,
  }) async {
    return transaction(() async {
      // 1. Fetch current vote row
      final currentVoteRow = await (select(exploreDeckVotes)
            ..where((t) =>
                t.exploreDeckId.equals(deckId) & t.userId.equals(userId)))
          .getSingleOrNull();

      final currentVote = currentVoteRow?.vote ?? 0;
      final int newVote;

      if (toggle && currentVote == targetVote) {
        newVote = 0; // Toggle off to neutral
      } else {
        newVote = targetVote;
      }

      // 2. Compute Deltas
      int deltaUp = 0;
      int deltaDown = 0;

      if (currentVote == 1) deltaUp -= 1;
      if (currentVote == -1) deltaDown -= 1;
      if (newVote == 1) deltaUp += 1;
      if (newVote == -1) deltaDown += 1;

      final deltaScore = newVote - currentVote;
      final now = DateTime.now();

      // 3. Upsert user vote record
      await into(exploreDeckVotes).insert(
        ExploreDeckVotesCompanion(
          id: Value('${deckId}_$userId'),
          exploreDeckId: Value(deckId),
          userId: Value(userId),
          vote: Value(newVote),
          updatedAt: Value(now),
        ),
        mode: InsertMode.insertOrReplace,
      );

      // 4. Atomically update explore_decks score and counts
      await customUpdate(
        '''
        UPDATE explore_decks
        SET upvotes = MAX(0, upvotes + ?),
            downvotes = MAX(0, downvotes + ?),
            score = score + ?,
            updated_at = ?
        WHERE id = ?;
        ''',
        variables: [
          Variable.withInt(deltaUp),
          Variable.withInt(deltaDown),
          Variable.withInt(deltaScore),
          Variable.withDateTime(now),
          Variable.withString(deckId),
        ],
        updates: {exploreDecks},
      );

      // 5. Read back current deck score for immediate caller verification
      final updatedDeck = await (select(exploreDecks)
            ..where((t) => t.id.equals(deckId)))
          .getSingle();

      return VoteResult(
        newVote: newVote,
        newScore: updatedDeck.score,
        upvotes: updatedDeck.upvotes,
        downvotes: updatedDeck.downvotes,
      );
    });
  }

  // ===========================================================================
  // 3. MULTI-TIER CONTEXTUAL SEARCH
  // ===========================================================================

  @override
  Future<ExploreSearchResults> searchExploreDecks({
    required String query,
    String userId = 'local_user',
    int limitPerTier = 20,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const ExploreSearchResults(
        inDeckName: [],
        inDeckCards: [],
        byUsername: [],
      );
    }

    final pattern = '%$trimmed%';

    // Tier 1: In Deck Name
    final nameQuery = '''
      SELECT ed.*, COALESCE(v.vote, 0) AS user_vote
      FROM explore_decks ed
      LEFT JOIN explore_deck_votes v 
        ON v.explore_deck_id = ed.id AND v.user_id = ?
      WHERE ed.name LIKE ? COLLATE NOCASE AND ed.is_deleted = 0
      ORDER BY ed.score DESC, ed.created_at DESC
      LIMIT ?;
    ''';

    final nameRows = await customSelect(
      nameQuery,
      variables: [
        Variable.withString(userId),
        Variable.withString(pattern),
        Variable.withInt(limitPerTier),
      ],
      readsFrom: {exploreDecks, exploreDeckVotes},
    ).get();

    final nameMatches = nameRows.map((r) => ExploreDeckWithVote(
          deck: exploreDecks.map(r.data),
          userVote: r.read<int>('user_vote'),
        )).toList();

    final tier1Ids = nameMatches.map((m) => m.id).toSet();

    // Tier 2: In Deck Cards (excluding Tier 1 IDs)
    final notInTier1Clause = tier1Ids.isNotEmpty
        ? 'AND ed.id NOT IN (${tier1Ids.map((_) => '?').join(', ')})'
        : '';

    final cardQuery = '''
      SELECT ed.*, edi.card_name, edi.quantity, COALESCE(v.vote, 0) AS user_vote
      FROM explore_decks ed
      INNER JOIN explore_deck_items edi 
        ON edi.explore_deck_id = ed.id
      LEFT JOIN explore_deck_votes v 
        ON v.explore_deck_id = ed.id AND v.user_id = ?
      WHERE edi.card_name LIKE ? COLLATE NOCASE 
        AND ed.is_deleted = 0 
        AND edi.is_deleted = 0
        $notInTier1Clause
      ORDER BY ed.score DESC, ed.created_at DESC
      LIMIT ?;
    ''';

    final cardVars = <Variable>[
      Variable.withString(userId),
      Variable.withString(pattern),
      ...tier1Ids.map((id) => Variable.withString(id)),
      Variable.withInt(limitPerTier * 2),
    ];

    final cardRows = await customSelect(
      cardQuery,
      variables: cardVars,
      readsFrom: {exploreDecks, exploreDeckItems, exploreDeckVotes},
    ).get();

    final cardMatchesMap = <String, ExploreDeckCardMatch>{};
    for (final row in cardRows) {
      final deckId = row.read<String>('id');
      if (!cardMatchesMap.containsKey(deckId)) {
        cardMatchesMap[deckId] = ExploreDeckCardMatch(
          deckWithVote: ExploreDeckWithVote(
            deck: exploreDecks.map(row.data),
            userVote: row.read<int>('user_vote'),
          ),
          matchingCardName: row.read<String>('card_name'),
          cardQuantity: row.read<int>('quantity'),
        );
      }
      if (cardMatchesMap.length >= limitPerTier) break;
    }
    final cardMatches = cardMatchesMap.values.toList();
    final tier2Ids = cardMatches.map((m) => m.deckWithVote.id).toSet();

    // Tier 3: By Username (excluding Tier 1 & Tier 2 IDs)
    final seenIds = {...tier1Ids, ...tier2Ids};
    final notInSeenClause = seenIds.isNotEmpty
        ? 'AND ed.id NOT IN (${seenIds.map((_) => '?').join(', ')})'
        : '';

    final userQuery = '''
      SELECT ed.*, COALESCE(v.vote, 0) AS user_vote
      FROM explore_decks ed
      LEFT JOIN explore_deck_votes v 
        ON v.explore_deck_id = ed.id AND v.user_id = ?
      WHERE ed.creator_name LIKE ? COLLATE NOCASE 
        AND ed.is_deleted = 0
        $notInSeenClause
      ORDER BY ed.score DESC, ed.created_at DESC
      LIMIT ?;
    ''';

    final userVars = <Variable>[
      Variable.withString(userId),
      Variable.withString(pattern),
      ...seenIds.map((id) => Variable.withString(id)),
      Variable.withInt(limitPerTier),
    ];

    final userRows = await customSelect(
      userQuery,
      variables: userVars,
      readsFrom: {exploreDecks, exploreDeckVotes},
    ).get();

    final userMatches = userRows.map((r) => ExploreDeckWithVote(
          deck: exploreDecks.map(r.data),
          userVote: r.read<int>('user_vote'),
        )).toList();

    return ExploreSearchResults(
      inDeckName: nameMatches,
      inDeckCards: cardMatches,
      byUsername: userMatches,
    );
  }

  // ===========================================================================
  // 4. BATCH INGESTION & SEEDER HELPERS
  // ===========================================================================

  @override
  Future<int> getExploreDeckCount() async {
    final count = await (selectOnly(exploreDecks)
          ..addColumns([exploreDecks.id.count()]))
        .getSingle();
    return count.read<int>(exploreDecks.id.count()) ?? 0;
  }

  @override
  Future<void> batchInsertExploreDecks(List<ExploreDecksCompanion> decks) async {
    await batch((b) {
      b.insertAll(exploreDecks, decks, mode: InsertMode.insertOrReplace);
    });
  }

  @override
  Future<void> batchInsertExploreDeckItems(
    List<ExploreDeckItemsCompanion> items, {
    int chunkSize = 250,
  }) async {
    for (var i = 0; i < items.length; i += chunkSize) {
      final chunk = items.sublist(i, math.min(i + chunkSize, items.length));
      await batch((b) {
        b.insertAll(exploreDeckItems, chunk, mode: InsertMode.insertOrReplace);
      });
    }
  }

  @override
  Future<void> clearExploreDecks() async {
    await transaction(() async {
      await delete(exploreDeckItems).go();
      await delete(exploreDeckVotes).go();
      await delete(exploreDecks).go();
    });
  }

  // ===========================================================================
  // 5. SHARING & CLONING HELPERS
  // ===========================================================================

  @override
  Future<ExploreDeck> sharePersonalDeckToExplore({
    required String personalDeckId,
    String creatorName = '@CurrentUser',
    String? authorId,
    String? customDescription,
  }) async {
    return transaction(() async {
      // 1. Fetch personal deck
      final Deck deck;
      final existingDeck = await (select(decks)
            ..where((t) => t.id.equals(personalDeckId) & t.isDeleted.equals(false)))
          .getSingleOrNull();

      if (existingDeck != null) {
        deck = existingDeck;
      } else {
        final mockDeck = MockDeckData.defaultDecks.cast<Deck?>().firstWhere(
              (d) => d?.id == personalDeckId,
              orElse: () => null,
            );
        if (mockDeck != null) {
          deck = mockDeck;
        } else if (personalDeckId == 'deck-tron') {
          deck = Deck(
            id: 'deck-tron',
            name: 'Modern Mono-Green Tron',
            format: 'MTG Modern',
            wins: 0,
            losses: 0,
            draws: 0,
            tcgDomain: 'mtg',
            isRegistered: false,
            isAssembled: false,
            isCompetitive: false,
            isCloned: false,
            isDeleted: false,
            createdAt: DateTime.now(),
          );
        } else if (personalDeckId == 'deck-lost-zone') {
          deck = Deck(
            id: 'deck-lost-zone',
            name: 'Lost Zone Giratina VSTAR',
            format: 'Pokémon Standard',
            wins: 0,
            losses: 0,
            draws: 0,
            tcgDomain: 'pokemon',
            isRegistered: true,
            isAssembled: true,
            isCompetitive: true,
            isCloned: false,
            isDeleted: false,
            createdAt: DateTime.now(),
          );
        } else {
          deck = await (select(decks)
                ..where((t) => t.id.equals(personalDeckId) & t.isDeleted.equals(false)))
              .getSingle();
        }
      }

      final now = DateTime.now();
      final exploreId = 'explore_shared_${deck.id}';

      // 2. Fetch items for active version joined with vault items
      final activeVersion = await (select(deckVersions)
            ..where((t) =>
                t.deckId.equals(personalDeckId) &
                t.isDeleted.equals(false))
            ..orderBy([
              (t) => OrderingTerm(
                    expression: t.isActive,
                    mode: OrderingMode.desc,
                  ),
              (t) => OrderingTerm(
                    expression: t.versionNumber,
                    mode: OrderingMode.desc,
                  ),
              (t) => OrderingTerm(
                    expression: t.createdAt,
                    mode: OrderingMode.desc,
                  ),
            ])
            ..limit(1))
          .getSingleOrNull();

      final versionId = activeVersion?.id;

      List<QueryRow> itemsQuery = versionId != null
          ? await customSelect('''
              SELECT dvi.*, vi.name, vi.set_or_series, vi.image_url, vi.dynamic_data, vi.current_market_price
              FROM deck_version_items dvi
              LEFT JOIN vault_items vi ON vi.id = dvi.vault_item_id
              WHERE dvi.version_id = ?
                AND COALESCE(dvi.is_deleted, 0) = 0
                AND (vi.is_deleted IS NULL OR vi.is_deleted = 0);
            ''', variables: [Variable.withString(versionId)]).get()
          : <QueryRow>[];

      // If starter deck in SQLite only had 1 placeholder card, ensure genuine cards in SQLite
      if ((itemsQuery.isEmpty || itemsQuery.length <= 1) &&
          versionId != null &&
          (personalDeckId == MockDeckData.edgarMarkovDeckId ||
           personalDeckId.toLowerCase().contains('charizard') ||
           personalDeckId.toLowerCase().contains('tron'))) {
        final mockCards = MockDeckData.getDeckItems(personalDeckId);
        final seedVaultItems = <VaultItemsCompanion>[];
        final seedDvi = <DeckVersionItemsCompanion>[];
        for (final m in mockCards) {
          final cId = (m['vault_item_id'] ?? m['id'] ?? const Uuid().v4()) as String;
          seedVaultItems.add(VaultItemsCompanion.insert(
            id: cId,
            collectionType: 'mtg',
            primaryBinderId: const Value('binder-mtg-personal'),
            name: m['name'] as String? ?? 'Unknown',
            setOrSeries: m['set_or_series'] as String? ?? 'Commander 2017',
            imageUrl: m['image_url'] as String? ?? '',
            acquiredPrice: 0.0,
            acquiredDate: now,
            quantity: const Value(1),
            condition: 'NM',
            isGraded: const Value(false),
            protectionStatus: const Value('Sleeved'),
            isDeleted: const Value(false),
            updatedAt: Value(now),
            currentMarketPrice: (m['current_market_price'] as num?)?.toDouble() ?? 0.0,
            lastPriceUpdate: now,
            dynamicData: m['dynamic_data'] as String? ?? '{}',
          ));
          seedDvi.add(DeckVersionItemsCompanion.insert(
            id: 'dvi_${cId}_$personalDeckId',
            versionId: versionId,
            vaultItemId: cId,
            quantity: Value((m['deck_quantity'] as int?) ?? (m['quantity'] as int?) ?? 1),
            boardZone: m['board_zone'] as String? ?? 'Mainboard',
            isProxy: const Value(false),
            isDeleted: const Value(false),
            updatedAt: Value(now),
          ));
        }
        // Clear any existing dummy placeholder items for this version so card count is exactly 100
        await (delete(deckVersionItems)..where((t) => t.versionId.equals(versionId))).go();
        await batch((b) {
          b.insertAll(vaultItems, seedVaultItems, mode: InsertMode.insertOrReplace);
          b.insertAll(deckVersionItems, seedDvi, mode: InsertMode.insertOrReplace);
        });

        itemsQuery = await customSelect('''
          SELECT dvi.*, vi.name, vi.set_or_series, vi.image_url, vi.dynamic_data, vi.current_market_price
          FROM deck_version_items dvi
          LEFT JOIN vault_items vi ON vi.id = dvi.vault_item_id
          WHERE dvi.version_id = ?
            AND COALESCE(dvi.is_deleted, 0) = 0
            AND (vi.is_deleted IS NULL OR vi.is_deleted = 0);
        ''', variables: [Variable.withString(versionId)]).get();
      }

      final isCommanderFormat = deck.format.toLowerCase().contains('commander') ||
          deck.format.toLowerCase().contains('edh');

      final bool hasExplicitCommander = itemsQuery.any((row) =>
          (row.readNullable<String>('board_zone') ?? '').trim().toLowerCase() == 'commander');

      String? commanderName;
      String? commanderImageUrl;
      String? commanderArtCrop;
      final Set<String> colors = {};
      double totalPrice = 0.0;
      int totalCardCount = 0;

      final exploreItems = <ExploreDeckItemsCompanion>[];

      void processCardEntry({
        required String cardName,
        required String rawBoardZone,
        required int quantity,
        required double price,
        required String? dynStr,
        required String? imgUrl,
        required String? vaultItemId,
        required String? setOrSeries,
      }) {
        Map<String, dynamic> dyn = {};
        if (dynStr != null && dynStr.isNotEmpty) {
          try {
            final decoded = jsonDecode(dynStr);
            if (decoded is Map<String, dynamic>) {
              dyn = decoded;
            } else if (decoded is Map) {
              dyn = Map<String, dynamic>.from(decoded);
            }
          } catch (_) {}
        }

        Map<String, dynamic>? face0;
        if (dyn['card_faces'] is List && (dyn['card_faces'] as List).isNotEmpty) {
          final first = (dyn['card_faces'] as List).first;
          if (first is Map<String, dynamic>) {
            face0 = first;
          } else if (first is Map) {
            face0 = Map<String, dynamic>.from(first);
          }
        }

        final manaCost = (dyn['mana_cost'] ?? face0?['mana_cost']) as String?;
        final cmc = (dyn['cmc'] as num?)?.toDouble() ?? (face0?['cmc'] as num?)?.toDouble();
        final typeLine = (dyn['type_line'] ?? face0?['type_line']) as String?;
        final scryfallId = (dyn['scryfall_id'] ?? dyn['id'] ?? vaultItemId) as String?;
        final oracleId = (dyn['oracle_id'] ?? dyn['oracle_text_id']) as String?;

        List<String> cardColors = [];
        if (dyn['colors'] is List) {
          cardColors = (dyn['colors'] as List).cast<String>();
          colors.addAll(cardColors);
        } else if (face0 != null && face0['colors'] is List) {
          cardColors = (face0['colors'] as List).cast<String>();
          colors.addAll(cardColors);
        }
        if (dyn['color_identity'] is List) {
          colors.addAll((dyn['color_identity'] as List).cast<String>());
        }

        String? artCrop;
        if (dyn['image_uris'] is Map) {
          artCrop = dyn['image_uris']['art_crop'] as String?;
        } else if (face0 != null && face0['image_uris'] is Map) {
          artCrop = face0['image_uris']['art_crop'] as String?;
        }

        var effectivePrice = price;
        if (effectivePrice <= 0.0 && dyn['prices'] is Map && dyn['prices']['usd'] != null) {
          effectivePrice = double.tryParse(dyn['prices']['usd'].toString()) ?? 0.0;
        }

        totalCardCount += quantity;
        totalPrice += (effectivePrice * quantity);

        final bool isExplicitCommander =
            rawBoardZone.trim().toLowerCase() == 'commander';
        final bool isFallbackCommander = !hasExplicitCommander &&
            isCommanderFormat &&
            deck.coverItemId != null &&
            (deck.coverItemId == vaultItemId ||
                deck.coverItemId == scryfallId ||
                deck.coverItemId == cardName);

        final bool isCommander = isExplicitCommander || isFallbackCommander;

        final String boardZone;
        if (isCommander) {
          boardZone = 'Commander';
        } else {
          final lowerZone = rawBoardZone.trim().toLowerCase();
          if (lowerZone == 'sideboard') {
            boardZone = 'Sideboard';
          } else if (lowerZone == 'maybeboard') {
            boardZone = 'Maybeboard';
          } else {
            boardZone = 'Mainboard';
          }
        }

        final resolvedImgUrl = (imgUrl != null && imgUrl.isNotEmpty)
            ? imgUrl
            : (dyn['image_uris'] is Map
                ? (dyn['image_uris']['normal'] ?? dyn['image_uris']['small']) as String?
                : (face0 != null && face0['image_uris'] is Map
                    ? (face0['image_uris']['normal'] ?? face0['image_uris']['small']) as String?
                    : null));
        final resolvedArtCrop = (artCrop != null && artCrop.isNotEmpty) ? artCrop : resolvedImgUrl;

        if (isCommander) {
          commanderName ??= cardName;
          commanderImageUrl ??= resolvedImgUrl;
          commanderArtCrop ??= resolvedArtCrop;
        }

        // Ensure set and variant attributes are preserved in dynamicData
        if (setOrSeries != null && setOrSeries.isNotEmpty && !dyn.containsKey('set_name')) {
          dyn['set_name'] = setOrSeries;
          dyn['set'] = setOrSeries;
          dynStr = jsonEncode(dyn);
        }

        exploreItems.add(ExploreDeckItemsCompanion.insert(
          id: const Uuid().v4(),
          exploreDeckId: exploreId,
          cardName: cardName,
          scryfallId: Value(scryfallId),
          oracleId: Value(oracleId),
          quantity: Value(quantity),
          boardZone: Value(boardZone),
          manaCost: Value(manaCost),
          cmc: Value(cmc),
          typeLine: Value(typeLine),
          colors: Value(cardColors.isNotEmpty ? jsonEncode(cardColors) : null),
          imageUrl: Value(resolvedImgUrl),
          artCropUrl: Value(resolvedArtCrop),
          price: Value(effectivePrice),
          isCommander: Value(isCommander),
          dynamicData: Value(dynStr),
          isDeleted: const Value(false),
        ));
      }

      if (itemsQuery.isNotEmpty) {
        for (final row in itemsQuery) {
          final cardName = row.readNullable<String>('name') ?? 'Unknown Card';
          final rawZone = row.readNullable<String>('board_zone') ?? 'Mainboard';
          final quantity = row.readNullable<int>('quantity') ?? 1;
          final price = row.readNullable<double>('current_market_price') ?? 0.0;
          final dynStr = row.readNullable<String>('dynamic_data');
          final imgUrl = row.readNullable<String>('image_url');
          final vaultItemId = row.readNullable<String>('vault_item_id');
          final setOrSeries = row.readNullable<String>('set_or_series');

          processCardEntry(
            cardName: cardName,
            rawBoardZone: rawZone,
            quantity: quantity,
            price: price,
            dynStr: dynStr,
            imgUrl: imgUrl,
            vaultItemId: vaultItemId,
            setOrSeries: setOrSeries,
          );
        }
      }

      // If commander banner/art was not explicitly set (e.g. non-Commander formats), resolve from cover or first card
      if (commanderImageUrl == null && exploreItems.isNotEmpty) {
        final coverMatch = exploreItems.cast<ExploreDeckItemsCompanion?>().firstWhere(
          (item) =>
              item != null &&
              (item.scryfallId.value == deck.coverItemId ||
                  item.cardName.value == deck.coverItemId),
          orElse: () => null,
        );
        if (coverMatch != null) {
          commanderName ??= coverMatch.cardName.value;
          commanderImageUrl = coverMatch.imageUrl.value;
          commanderArtCrop = coverMatch.artCropUrl.value;
        } else {
          final first = exploreItems.first;
          commanderName ??= first.cardName.value;
          commanderImageUrl = first.imageUrl.value;
          commanderArtCrop = first.artCropUrl.value;
        }
      }

      // 3. Insert or Replace ExploreDeck
      final newExploreDeck = ExploreDecksCompanion.insert(
        id: exploreId,
        name: deck.name,
        format: deck.format,
        tcgDomain: Value(deck.tcgDomain),
        sourceType: const Value('user_shared'),
        creatorName: Value(creatorName),
        authorId: Value(authorId ?? 'local_user'),
        description: Value(customDescription ?? deck.description),
        commanderName: Value(commanderName),
        commanderImageUrl: Value(commanderImageUrl),
        commanderArtCrop: Value(commanderArtCrop),
        colorIdentity: Value(jsonEncode(colors.toList())),
        cardCount: Value(totalCardCount),
        estimatedPrice: Value(totalPrice),
        featuredCategory: const Value('From Top Deck Builders'),
        upvotes: const Value(1),
        score: const Value(1),
        createdAt: now,
        updatedAt: Value(now),
        isDeleted: const Value(false),
      );

      await into(exploreDecks).insert(
        newExploreDeck,
        mode: InsertMode.insertOrReplace,
      );

      // Clean existing items if updating shared deck
      await (delete(exploreDeckItems)
            ..where((t) => t.exploreDeckId.equals(exploreId)))
          .go();

      await batchInsertExploreDeckItems(exploreItems);

      // Owner auto-upvote
      await into(exploreDeckVotes).insert(
        ExploreDeckVotesCompanion.insert(
          id: '${exploreId}_local_user',
          exploreDeckId: exploreId,
          userId: const Value('local_user'),
          vote: const Value(1),
          updatedAt: now,
        ),
        mode: InsertMode.insertOrReplace,
      );

      return (await (select(exploreDecks)..where((t) => t.id.equals(exploreId)))
          .getSingle());
    });
  }

  @override
  Future<void> unpublishExploreDeck({
    required String exploreDeckId,
  }) async {
    await transaction(() async {
      final now = DateTime.now();

      // 1. Soft-delete parent row in explore_decks
      await (update(exploreDecks)..where((t) => t.id.equals(exploreDeckId))).write(
        ExploreDecksCompanion(
          isDeleted: const Value(true),
          updatedAt: Value(now),
        ),
      );

      // 2. Soft-delete all card entries in explore_deck_items
      await (update(exploreDeckItems)
            ..where((t) => t.exploreDeckId.equals(exploreDeckId)))
          .write(
        const ExploreDeckItemsCompanion(
          isDeleted: Value(true),
        ),
      );

      // 3. Log mutation to sync_queue for Firebase sync
      await _recordSync(
        'explore_deck',
        exploreDeckId,
        'DELETE',
        timestamp: now,
      );
    });
  }

  @override
  Future<Deck> cloneExploreDeckToPersonal({
    required String exploreDeckId,
  }) async {
    // 0. Pre-check: If precon card list is not yet populated in explore_deck_items,
    // trigger lazy hydration from MTGJSON before starting the transaction.
    final initialCheck = await (select(exploreDeckItems)
          ..where((t) =>
              t.exploreDeckId.equals(exploreDeckId) &
              t.isDeleted.equals(false)))
        .get();

    if (initialCheck.isEmpty) {
      final sourceCheck = await (select(exploreDecks)
            ..where((t) => t.id.equals(exploreDeckId)))
          .getSingleOrNull();
      if (sourceCheck != null && sourceCheck.sourceType == 'official') {
        try {
          await hydrateOfficialDeckItems(exploreDeckId: exploreDeckId);
        } catch (_) {
          // Non-fatal: proceed with whatever is available
        }
      }
    }

    return transaction(() async {
      // 1. Fetch source explore deck and cards
      final expDeck = await (select(exploreDecks)
            ..where((t) => t.id.equals(exploreDeckId)))
          .getSingle();

      final expItems = await (select(exploreDeckItems)
            ..where((t) =>
                t.exploreDeckId.equals(exploreDeckId) &
                t.isDeleted.equals(false)))
          .get();

      final now = DateTime.now();
      final newDeckId = const Uuid().v4();
      final newVersionId = const Uuid().v4();

      String? resolvedCoverItemId;

      // 2. Insert Personal Deck (as Draft, cloned)
      final newDeck = DecksCompanion.insert(
        id: newDeckId,
        name: '${expDeck.name} (Copy)',
        format: expDeck.format,
        description: Value(expDeck.description),
        tcgDomain: Value(expDeck.tcgDomain),
        isRegistered: const Value(false),
        isAssembled: const Value(false),
        isCompetitive: const Value(false),
        isCloned: const Value(true),
        sourceExploreDeckId: Value(expDeck.id),
        createdAt: now,
        updatedAt: Value(now),
        isDeleted: const Value(false),
      );
      await into(decks).insert(newDeck);
      await _recordSync('deck', newDeckId, 'INSERT', timestamp: now);

      // 3. Insert Active DeckVersion (v1)
      final newVersion = DeckVersionsCompanion.insert(
        id: newVersionId,
        deckId: newDeckId,
        versionNumber: 1,
        versionNote: Value(
            'Cloned from Explore: ${expDeck.name} by ${expDeck.creatorName}'),
        isActive: const Value(true),
        createdAt: now,
        updatedAt: Value(now),
        isDeleted: const Value(false),
      );
      await into(deckVersions).insert(newVersion);
      await _recordSync('deck_version', newVersionId, 'INSERT', timestamp: now);

      // 4. Resolve cards into vault_items and deck_version_items
      for (final item in expItems) {
        // Query existing vault_item by exact name or scryfall ID
        var vaultItem = await (select(vaultItems)
              ..where((t) =>
                  (t.name.equals(item.cardName) |
                      t.id.equals(item.scryfallId ?? '')) &
                  t.isDeleted.equals(false))
              ..limit(1))
            .getSingleOrNull();

        if (vaultItem == null) {
          // Synthesize unowned catalog reference row in vault_items
          final catalogId = item.scryfallId ?? const Uuid().v4();
          final dynData = item.dynamicData ??
              jsonEncode({
                'name': item.cardName,
                'mana_cost': item.manaCost,
                'type_line': item.typeLine,
                'cmc': item.cmc,
              });

          await into(vaultItems).insert(
            VaultItemsCompanion.insert(
              id: catalogId,
              collectionType: expDeck.tcgDomain.isNotEmpty ? expDeck.tcgDomain : 'mtg',
              name: item.cardName,
              setOrSeries: 'Catalog',
              imageUrl: item.imageUrl ?? '',
              acquiredPrice: 0.0,
              acquiredDate: now,
              quantity: const Value(0), // Unowned reference
              condition: 'NM',
              currentMarketPrice: item.price ?? 0.0,
              lastPriceUpdate: now,
              dynamicData: dynData,
              isDeleted: const Value(false),
              updatedAt: Value(now),
            ),
            mode: InsertMode.insertOrReplace,
          );

          vaultItem = await (select(vaultItems)
                ..where((t) => t.id.equals(catalogId)))
              .getSingle();
        }

        if (item.isCommander && resolvedCoverItemId == null) {
          resolvedCoverItemId = vaultItem.id;
        }

        // Available inventory check: if owned < needed, mark proxy
        final isProxy = vaultItem.quantity < item.quantity;
        final newDviId = const Uuid().v4();

        await into(deckVersionItems).insert(
          DeckVersionItemsCompanion.insert(
            id: newDviId,
            versionId: newVersionId,
            vaultItemId: vaultItem.id,
            quantity: Value(item.quantity),
            boardZone: item.boardZone,
            isProxy: Value(isProxy),
            isDeleted: const Value(false),
            updatedAt: Value(now),
          ),
        );
        await _recordSync('deck_version_item', newDviId, 'INSERT', timestamp: now);
      }

      // 5. Update cover item ID if commander or cover card resolved
      if (resolvedCoverItemId != null) {
        await (update(decks)..where((t) => t.id.equals(newDeckId)))
            .write(DecksCompanion(coverItemId: Value(resolvedCoverItemId)));
      }

      return (await (select(decks)..where((t) => t.id.equals(newDeckId)))
          .getSingle());
    });
  }

  // ===========================================================================
  // 6. INTERNAL QUERY & SYNC HELPERS
  // ===========================================================================

  /// Extracts shared WHERE clauses and variables for Explore feed queries and SELECT COUNT(*) queries.
  /// Guarantees exact predicate symmetry between watchExploreDecks and watchFilteredExploreDeckCount.
  (List<String> whereClauses, List<Variable> variables, bool needsItemsTable)
      _buildExploreWhereClauses({
    required ExploreCategory category,
    ExploreFilterState? filter,
    required String searchQuery,
    String? featuredCategory,
    String? currentUserId,
  }) {
    final whereClauses = <String>['ed.is_deleted = 0'];
    final variables = <Variable>[];
    bool needsItemsTable = false;

    // 0. Featured Category pushdown
    if (featuredCategory != null && featuredCategory.trim().isNotEmpty) {
      final cat = featuredCategory.trim();
      if (cat == "Today's Picks" || cat == "This Week's Picks" || cat == "This Month's Picks" || cat == 'Trending') {
        // Lead velocity window: include all non-deleted explore decks without restrictive category filter
      } else if (cat == r"Trending Budget Brews (<$100)" || cat == 'trending_budget_brews') {
        whereClauses.add('ed.estimated_price > 0.0 AND ed.estimated_price <= 100.0');
      } else if (cat == 'Most Upvoted Mono-Color Commanders' || cat == 'mono_color_commanders') {
        whereClauses.add("(ed.format LIKE '%Commander%' OR ed.format LIKE '%EDH%')");
        whereClauses.add("(ed.color_identity = '[\"W\"]' OR ed.color_identity = '[\"U\"]' OR ed.color_identity = '[\"B\"]' OR ed.color_identity = '[\"R\"]' OR ed.color_identity = '[\"G\"]')");
      } else if (cat == 'Hot New Precons' || cat == 'hot_new_precons') {
        whereClauses.add("ed.source_type = 'official'");
      } else if (cat == 'Tribal Spotlight' || cat == 'tribal_spotlight') {
        whereClauses.add("(ed.tags LIKE '%tribal%' OR ed.name LIKE '%Tribal%' OR ed.name LIKE '%Dragon%' OR ed.name LIKE '%Vampire%' OR ed.name LIKE '%Elf%' OR ed.name LIKE '%Elves%' OR ed.name LIKE '%Zombie%' OR ed.name LIKE '%Goblins%' OR ed.name LIKE '%Goblin%' OR ed.name LIKE '%Sliver%')");
      } else if (cat == 'Rising Community Builders' || cat == 'rising_community_builders') {
        whereClauses.add("ed.source_type IN ('community', 'user_shared')");
      } else if (cat == 'Top Modern Decks' || cat == 'top_modern_decks') {
        whereClauses.add("ed.format LIKE '%Modern%'");
      } else if (cat == 'Pioneer Showdown' || cat == 'pioneer_showdown') {
        whereClauses.add("ed.format LIKE '%Pioneer%'");
      } else {
        whereClauses.add('ed.featured_category = ?');
        variables.add(Variable.withString(cat));
        if (cat == 'From Top Deck Builders') {
          whereClauses.add("ed.source_type IN ('community', 'user_shared')");
        }
      }
    }

    // 1. Category / Source Type
    if (category == ExploreCategory.official) {
      whereClauses.add("ed.source_type = 'official'");
    } else if (category == ExploreCategory.community) {
      whereClauses.add("ed.source_type IN ('community', 'user_shared')");
    } else if (category == ExploreCategory.myUploads) {
      final uid = currentUserId ?? 'local_user';
      whereClauses.add(
          "(ed.author_id = ? OR ed.author_id = ? OR (ed.author_id IN ('local_user', 'user-current-me') AND ? IN ('local_user', 'user-current-me')))");
      variables.add(Variable.withString(uid));
      variables.add(Variable.withString('@$uid'));
      variables.add(Variable.withString(uid));
    }

    // 2. Search Query pushdown (Deck Name, Creator Name, or Card Name via explore_deck_items)
    final trimmedSearch = searchQuery.trim();
    if (trimmedSearch.isNotEmpty) {
      needsItemsTable = true;
      whereClauses.add('''
        (ed.name LIKE ? COLLATE NOCASE OR 
         ed.creator_name LIKE ? COLLATE NOCASE OR 
         EXISTS (
           SELECT 1 FROM explore_deck_items edi 
           WHERE edi.explore_deck_id = ed.id 
             AND edi.card_name LIKE ? COLLATE NOCASE 
             AND edi.is_deleted = 0
         ))
      ''');
      final searchPattern = '%$trimmedSearch%';
      variables.add(Variable.withString(searchPattern));
      variables.add(Variable.withString(searchPattern));
      variables.add(Variable.withString(searchPattern));
    }

    // 3. Filter: Format
    if (filter != null &&
        filter.format != null &&
        filter.format!.isNotEmpty &&
        filter.format!.toLowerCase() != 'all') {
      whereClauses.add('ed.format = ? COLLATE NOCASE');
      variables.add(Variable.withString(filter.format!));
    }

    // 4. Filter: Price Range
    if (filter != null && filter.priceRange != 'all') {
      switch (filter.priceRange) {
        case 'budget_0_50':
          whereClauses.add('ed.estimated_price >= 0.0 AND ed.estimated_price <= 50.0');
          break;
        case 'mid_50_200':
          whereClauses.add('ed.estimated_price > 50.0 AND ed.estimated_price <= 200.0');
          break;
        case 'high_200_plus':
          whereClauses.add('ed.estimated_price > 200.0');
          break;
      }
    }

    // 5. Filter: Commander Name
    if (filter != null &&
        filter.commanderName != null &&
        filter.commanderName!.trim().isNotEmpty) {
      whereClauses.add('ed.commander_name LIKE ? COLLATE NOCASE');
      variables.add(Variable.withString('%${filter.commanderName!.trim()}%'));
    }

    // 6. Filter: Specific Card Inclusion
    if (filter != null &&
        filter.cardInclusion != null &&
        filter.cardInclusion!.trim().isNotEmpty) {
      needsItemsTable = true;
      whereClauses.add('''
        EXISTS (
          SELECT 1 FROM explore_deck_items edi 
          WHERE edi.explore_deck_id = ed.id 
            AND edi.card_name LIKE ? COLLATE NOCASE 
            AND edi.is_deleted = 0
        )
      ''');
      variables.add(Variable.withString('%${filter.cardInclusion!.trim()}%'));
    }

    // 7. Filter: Color Identity
    if (filter != null && filter.colors.isNotEmpty) {
      final normalized = filter.colors.map((c) => c.toUpperCase()).toSet();
      final onlyC = normalized.length == 1 && normalized.contains('C');

      if (onlyC) {
        whereClauses.add(
            "(ed.color_identity = '[]' OR ed.color_identity = '[\"C\"]' OR ed.color_identity IS NULL)");
      } else {
        final activeColors = normalized.where((c) => c != 'C').toSet();
        if (filter.colorMatchMode == 'including') {
          for (final c in activeColors) {
            whereClauses.add("ed.color_identity GLOB '*\"$c\"*'");
          }
        } else if (filter.colorMatchMode == 'atMost' ||
            filter.colorMatchMode == 'commander') {
          final excluded = {'W', 'U', 'B', 'R', 'G'}.difference(activeColors);
          for (final ex in excluded) {
            whereClauses.add("ed.color_identity NOT GLOB '*\"$ex\"*'");
          }
        } else if (filter.colorMatchMode == 'exactly') {
          for (final c in activeColors) {
            whereClauses.add("ed.color_identity GLOB '*\"$c\"*'");
          }
          final excluded = {'W', 'U', 'B', 'R', 'G'}.difference(activeColors);
          for (final ex in excluded) {
            whereClauses.add("ed.color_identity NOT GLOB '*\"$ex\"*'");
          }
        }
      }
    }

    return (whereClauses, variables, needsItemsTable);
  }

  (String sql, List<Variable> variables, bool needsItemsTable) _buildFeedQuery({
    required ExploreCategory category,
    required ExploreSortOption sort,
    ExploreFilterState? filter,
    required String searchQuery,
    String? featuredCategory,
    required String userId,
    int? limit,
    int? offset,
    bool balanceFeed = false,
  }) {
    final (whereClauses, whereVariables, needsItemsTable) =
        _buildExploreWhereClauses(
      category: category,
      filter: filter,
      searchQuery: searchQuery,
      featuredCategory: featuredCategory,
      currentUserId: userId,
    );

    // Note: userId is the first placeholder in the SQL query:
    // LEFT JOIN explore_deck_votes v ON v.explore_deck_id = ed.id AND v.user_id = ?
    final variables = <Variable>[
      Variable.withString(userId),
      ...whereVariables,
    ];

    // Sorting
    final String orderClause;
    switch (sort) {
      case ExploreSortOption.recentlyAdded:
        orderClause = 'created_at DESC, score DESC';
        break;
      case ExploreSortOption.priceLowToHigh:
        orderClause = 'estimated_price ASC, score DESC';
        break;
      case ExploreSortOption.priceHighToLow:
        orderClause = 'estimated_price DESC, score DESC';
        break;
      case ExploreSortOption.alphabetical:
        orderClause = 'name COLLATE NOCASE ASC';
        break;
      case ExploreSortOption.popularity:
        orderClause = 'score DESC, upvotes DESC, created_at DESC';
        break;
    }

    final shouldBalance = balanceFeed &&
        category == ExploreCategory.all &&
        (featuredCategory == null || featuredCategory.trim().isEmpty);

    var sql = shouldBalance
        ? '''
      WITH numbered_feed AS (
        SELECT ed.*, COALESCE(v.vote, 0) AS user_vote,
               ROW_NUMBER() OVER (
                 PARTITION BY (CASE WHEN ed.source_type IN ('community', 'user_shared') THEN 1 ELSE 0 END)
                 ORDER BY $orderClause
               ) AS source_rank,
               CASE WHEN ed.source_type IN ('community', 'user_shared') THEN 1 ELSE 0 END AS is_community
        FROM explore_decks ed
        LEFT JOIN explore_deck_votes v 
          ON v.explore_deck_id = ed.id AND v.user_id = ?
        WHERE ${whereClauses.join(' AND ')}
      )
      SELECT *
      FROM numbered_feed
      ORDER BY 
        CASE 
          WHEN is_community = 0 THEN (source_rank - 1) * 1.5 + 1.0 
          ELSE source_rank * 3.0 
        END ASC,
        $orderClause
    '''
        : '''
      SELECT ed.*, COALESCE(v.vote, 0) AS user_vote
      FROM explore_decks ed
      LEFT JOIN explore_deck_votes v 
        ON v.explore_deck_id = ed.id AND v.user_id = ?
      WHERE ${whereClauses.join(' AND ')}
      ORDER BY $orderClause
    ''';

    if (limit != null) {
      sql += ' LIMIT ?';
      variables.add(Variable.withInt(limit));
      if (offset != null) {
        sql += ' OFFSET ?';
        variables.add(Variable.withInt(offset));
      }
    }

    return (sql, variables, needsItemsTable);
  }

  @override
  String resolveMtgjsonFileName(ExploreDeck deck) {
    if (deck.tags != null && deck.tags!.isNotEmpty) {
      final tagList = deck.tags!.split(',');
      for (final t in tagList) {
        final trimmed = t.trim();
        if (trimmed.startsWith('fn:')) {
          return trimmed.substring(3).trim();
        }
        if (trimmed.startsWith('fileName:')) {
          return trimmed.substring(9).trim();
        }
      }
    }
    // Heuristic fallback: PascalCase deck name + release code
    final cleanName = deck.name
        .replaceAll(RegExp(r"[^a-zA-Z0-9\s]"), "")
        .split(RegExp(r"\s+"))
        .where((s) => s.isNotEmpty)
        .map((s) => s[0].toUpperCase() + s.substring(1).toLowerCase())
        .join('');
    final code = deck.releaseCode != null && deck.releaseCode!.isNotEmpty
        ? deck.releaseCode!.toUpperCase()
        : 'MTG';
    return '${cleanName}_$code';
  }

  @override
  Future<List<ExploreDeckItem>> hydrateOfficialDeckItems({
    required String exploreDeckId,
    http.Client? httpClient,
  }) async {
    final existingItems = await (select(exploreDeckItems)
          ..where((t) =>
              t.exploreDeckId.equals(exploreDeckId) &
              t.isDeleted.equals(false)))
        .get();
    if (existingItems.isNotEmpty) return existingItems;

    final deck = await (select(exploreDecks)
          ..where((t) => t.id.equals(exploreDeckId)))
        .getSingleOrNull();
    if (deck == null || deck.sourceType != 'official') return [];

    final fileName = resolveMtgjsonFileName(deck);
    final client = httpClient ?? http.Client();
    final shouldCloseClient = httpClient == null;

    try {
      final url = Uri.parse('https://mtgjson.com/api/v5/decks/$fileName.json');
      final response = await client.get(
        url,
        headers: {'User-Agent': 'Countr/1.0 (Lazy Hydration)'},
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final rawDeck = decoded is Map<String, dynamic> && decoded.containsKey('data')
            ? decoded['data'] as Map<String, dynamic>
            : decoded as Map<String, dynamic>;

        final parsedDecks = MtgjsonPreconParser.parseObject(rawDeck);
        if (parsedDecks.isNotEmpty) {
          final precon = parsedDecks.first;
          final companions = <ExploreDeckItemsCompanion>[];

          if (precon.primaryCommander != null) {
            final cmdr = precon.primaryCommander!;
            companions.add(ExploreDeckItemsCompanion.insert(
              id: '${exploreDeckId}_commander',
              exploreDeckId: exploreDeckId,
              cardName: cmdr.name,
              scryfallId: Value(cmdr.scryfallId),
              oracleId: Value(cmdr.oracleId),
              quantity: Value(cmdr.count),
              boardZone: Value(cmdr.boardZone),
              manaCost: Value(cmdr.manaCost),
              cmc: Value(cmdr.cmc),
              typeLine: Value(cmdr.typeLine),
              colors: Value(jsonEncode(cmdr.colors)),
              imageUrl: Value(cmdr.imageUrl),
              artCropUrl: Value(cmdr.artCropUrl),
              price: Value(cmdr.price),
              isCommander: const Value(true),
              isDeleted: const Value(false),
            ));
          }

          int cardIdx = 0;
          for (final card in [...precon.mainboardCards, ...precon.sideboardCards]) {
            cardIdx++;
            companions.add(ExploreDeckItemsCompanion.insert(
              id: '${exploreDeckId}_card_$cardIdx',
              exploreDeckId: exploreDeckId,
              cardName: card.name,
              scryfallId: Value(card.scryfallId),
              oracleId: Value(card.oracleId),
              quantity: Value(card.count),
              boardZone: Value(card.boardZone),
              manaCost: Value(card.manaCost),
              cmc: Value(card.cmc),
              typeLine: Value(card.typeLine),
              colors: Value(jsonEncode(card.colors)),
              imageUrl: Value(card.imageUrl),
              artCropUrl: Value(card.artCropUrl),
              price: Value(card.price),
              isCommander: Value(card.isCommander),
              isDeleted: const Value(false),
            ));
          }

          if (companions.isNotEmpty) {
            await batchInsertExploreDeckItems(companions);
          }
        }
      }
    } catch (_) {
      // Non-fatal lazy hydration fallback
    } finally {
      if (shouldCloseClient) {
        client.close();
      }
    }

    return getExploreDeckItems(exploreDeckId);
  }

  Future<void> _recordSync(
    String entityType,
    String entityId,
    String op, {
    required DateTime timestamp,
  }) async {
    await into(syncQueue).insert(
      SyncQueueCompanion.insert(
        id: const Uuid().v4(),
        entityType: entityType,
        entityId: entityId,
        operation: op,
        timestamp: timestamp,
        retryCount: const Value(0),
      ),
    );
  }
}
