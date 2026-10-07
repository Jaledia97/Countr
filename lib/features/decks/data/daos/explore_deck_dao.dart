import 'dart:convert';
import 'dart:math' as math;
import 'package:drift/drift.dart';
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
    String userId = 'local_user',
    int? limit,
    int? offset,
  });

  Stream<List<ExploreDeckWithVote>> watchFeaturedCategory(
    String category, {
    String userId = 'local_user',
    int limit = 15,
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
    String? customDescription,
  });

  Future<Deck> cloneExploreDeckToPersonal({
    required String exploreDeckId,
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
    String userId = 'local_user',
    int? limit,
    int? offset,
  }) {
    final (sql, variables, needsItemsTable) = _buildFeedQuery(
      category: category,
      sort: sort,
      filter: filter,
      searchQuery: searchQuery,
      userId: userId,
      limit: limit,
      offset: offset,
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
  Stream<List<ExploreDeckWithVote>> watchFeaturedCategory(
    String category, {
    String userId = 'local_user',
    int limit = 15,
  }) {
    const querySql = '''
      SELECT ed.*, COALESCE(v.vote, 0) AS user_vote
      FROM explore_decks ed
      LEFT JOIN explore_deck_votes v 
        ON v.explore_deck_id = ed.id AND v.user_id = ?
      WHERE ed.featured_category = ? AND ed.is_deleted = 0
      ORDER BY ed.score DESC, ed.created_at DESC
      LIMIT ?;
    ''';

    return customSelect(
      querySql,
      variables: [
        Variable.withString(userId),
        Variable.withString(category),
        Variable.withInt(limit),
      ],
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

      final itemsQuery = versionId != null
          ? await customSelect('''
              SELECT dvi.*, vi.name, vi.set_or_series, vi.image_url, vi.dynamic_data, vi.current_market_price
              FROM deck_version_items dvi
              LEFT JOIN vault_items vi ON vi.id = dvi.vault_item_id
              WHERE dvi.version_id = ?
                AND COALESCE(dvi.is_deleted, 0) = 0
                AND (vi.is_deleted IS NULL OR vi.is_deleted = 0);
            ''', variables: [Variable.withString(versionId)]).get()
          : <QueryRow>[];

      bool isDeckWithDedicatedMockList(String id) {
        final lower = id.toLowerCase();
        return id == MockDeckData.edgarMarkovDeckId ||
            lower.contains('charizard') ||
            lower.contains('tron');
      }

      final shouldUseMockData = (itemsQuery.isEmpty || itemsQuery.length <= 1) &&
          isDeckWithDedicatedMockList(personalDeckId);

      final isCommanderFormat = deck.format.toLowerCase().contains('commander') ||
          deck.format.toLowerCase().contains('edh');

      final bool hasExplicitCommander = shouldUseMockData
          ? MockDeckData.getDeckItems(personalDeckId).any((m) =>
              (m['board_zone'] as String? ?? '').trim().toLowerCase() == 'commander')
          : itemsQuery.any((row) =>
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

      if (shouldUseMockData) {
        final mockCards = MockDeckData.getDeckItems(personalDeckId);
        for (final m in mockCards) {
          final cardName = m['name'] as String? ?? 'Unknown Card';
          final rawZone = m['board_zone'] as String? ?? 'Mainboard';
          final quantity = (m['deck_quantity'] as int?) ?? (m['quantity'] as int?) ?? 1;
          final price = (m['current_market_price'] as num?)?.toDouble() ?? 0.0;
          final dynStr = m['dynamic_data'] as String?;
          final imgUrl = m['image_url'] as String?;
          final vaultItemId = (m['vault_item_id'] ?? m['id']) as String?;
          final setOrSeries = m['set_or_series'] as String?;

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
      } else if (itemsQuery.isNotEmpty) {
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
        description: Value(customDescription ?? deck.description),
        commanderName: Value(commanderName),
        commanderImageUrl: Value(commanderImageUrl),
        commanderArtCrop: Value(commanderArtCrop),
        colorIdentity: Value(jsonEncode(colors.toList())),
        cardCount: Value(totalCardCount),
        estimatedPrice: Value(totalPrice),
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
  Future<Deck> cloneExploreDeckToPersonal({
    required String exploreDeckId,
  }) async {
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

  (String sql, List<Variable> variables, bool needsItemsTable) _buildFeedQuery({
    required ExploreCategory category,
    required ExploreSortOption sort,
    ExploreFilterState? filter,
    required String searchQuery,
    required String userId,
    int? limit,
    int? offset,
  }) {
    final whereClauses = <String>['ed.is_deleted = 0'];
    final variables = <Variable>[Variable.withString(userId)];
    bool needsItemsTable = false;

    // Category / Source Type
    if (category == ExploreCategory.official) {
      whereClauses.add("ed.source_type = 'official'");
    } else if (category == ExploreCategory.community) {
      whereClauses.add("ed.source_type IN ('community', 'user_shared')");
    }

    // Search Query pushdown
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

    // Filter: Format
    if (filter != null &&
        filter.format != null &&
        filter.format!.isNotEmpty &&
        filter.format!.toLowerCase() != 'all') {
      whereClauses.add('ed.format = ? COLLATE NOCASE');
      variables.add(Variable.withString(filter.format!));
    }

    // Filter: Price Range
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

    // Filter: Commander Name
    if (filter != null &&
        filter.commanderName != null &&
        filter.commanderName!.trim().isNotEmpty) {
      whereClauses.add('ed.commander_name LIKE ? COLLATE NOCASE');
      variables.add(Variable.withString('%${filter.commanderName!.trim()}%'));
    }

    // Filter: Specific Card Inclusion
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

    // Filter: Color Identity
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

    // Sorting
    final String orderClause;
    switch (sort) {
      case ExploreSortOption.recentlyAdded:
        orderClause = 'ed.created_at DESC, ed.score DESC';
        break;
      case ExploreSortOption.priceLowToHigh:
        orderClause = 'ed.estimated_price ASC, ed.score DESC';
        break;
      case ExploreSortOption.priceHighToLow:
        orderClause = 'ed.estimated_price DESC, ed.score DESC';
        break;
      case ExploreSortOption.alphabetical:
        orderClause = 'ed.name COLLATE NOCASE ASC';
        break;
      case ExploreSortOption.popularity:
        orderClause = 'ed.score DESC, ed.upvotes DESC, ed.created_at DESC';
        break;
    }

    var sql = '''
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
