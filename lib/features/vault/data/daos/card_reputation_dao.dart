import 'package:drift/drift.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/database/tables/social/card_reputation_votes_table.dart';
import 'package:countr/core/database/tables/vault_items_table.dart';

part 'card_reputation_dao.g.dart';

class CardVoteResult {
  final int newVote;
  final int newScore;
  final int upvotes;
  final int downvotes;

  const CardVoteResult({
    required this.newVote,
    required this.newScore,
    required this.upvotes,
    required this.downvotes,
  });

  @override
  String toString() =>
      'CardVoteResult(newVote: $newVote, newScore: $newScore, upvotes: $upvotes, downvotes: $downvotes)';
}

class CardReputationSummary {
  final int score;
  final int upvotes;
  final int downvotes;
  final int userVote;

  const CardReputationSummary({
    required this.score,
    required this.upvotes,
    required this.downvotes,
    this.userVote = 0,
  });

  @override
  String toString() =>
      'CardReputationSummary(score: $score, upvotes: $upvotes, downvotes: $downvotes, userVote: $userVote)';
}

@DriftAccessor(tables: [CardReputationVotes, VaultItems])
class CardReputationDao extends DatabaseAccessor<AppDatabase>
    with _$CardReputationDaoMixin {
  CardReputationDao(super.db);

  /// Performs atomic card reputation vote casting.
  ///
  /// If [toggle] is true and current vote equals [targetVote], reverts vote to 0 (neutral).
  /// Updates `card_reputation_votes` table and updates `vault_items` columns:
  /// `upvotes`, `downvotes`, and `reputation_score`.
  Future<CardVoteResult> castVote({
    required String cardId,
    String userId = 'local_user',
    required int targetVote,
    bool toggle = true,
  }) async {
    return transaction(() async {
      // 1. Fetch current vote row
      final currentVoteRow = await (select(cardReputationVotes)
            ..where((t) =>
                t.cardId.equals(cardId) &
                t.userId.equals(userId) &
                t.isDeleted.equals(false)))
          .getSingleOrNull();

      final currentVote = currentVoteRow?.vote ?? 0;
      final int newVote;

      if (toggle && currentVote == targetVote) {
        newVote = 0; // Toggle to neutral
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
      await into(cardReputationVotes).insert(
        CardReputationVotesCompanion(
          id: Value('${cardId}_$userId'),
          cardId: Value(cardId),
          userId: Value(userId),
          vote: Value(newVote),
          updatedAt: Value(now),
          isDeleted: const Value(false),
          deletedAt: const Value(null),
          syncStatus: const Value('pending'),
        ),
        mode: InsertMode.insertOrReplace,
      );

      // 4. Atomically update vault_items table
      await customUpdate(
        '''
        UPDATE vault_items
        SET upvotes = MAX(0, COALESCE(upvotes, 0) + ?),
            downvotes = MAX(0, COALESCE(downvotes, 0) + ?),
            reputation_score = COALESCE(reputation_score, 0) + ?,
            updated_at = ?
        WHERE id = ?;
        ''',
        variables: [
          Variable.withInt(deltaUp),
          Variable.withInt(deltaDown),
          Variable.withInt(deltaScore),
          Variable.withDateTime(now),
          Variable.withString(cardId),
        ],
        updates: {vaultItems},
      );

      // 5. Read back current item score
      final item = await (select(vaultItems)
            ..where((t) => t.id.equals(cardId)))
          .getSingleOrNull();

      final score = item?.reputationScore ?? deltaScore;
      final upvotes = item?.upvotes ?? (newVote == 1 ? 1 : 0);
      final downvotes = item?.downvotes ?? (newVote == -1 ? 1 : 0);

      return CardVoteResult(
        newVote: newVote,
        newScore: score,
        upvotes: upvotes,
        downvotes: downvotes,
      );
    });
  }

  /// Streams the current user's vote on [cardId].
  Stream<int> watchUserVote(String cardId, {String userId = 'local_user'}) {
    return (select(cardReputationVotes)
          ..where((t) =>
              t.cardId.equals(cardId) &
              t.userId.equals(userId) &
              t.isDeleted.equals(false)))
        .watchSingleOrNull()
        .map((row) => row?.vote ?? 0);
  }

  /// One-shot fetch of the current user's vote on [cardId].
  Future<int> getUserVote(String cardId, {String userId = 'local_user'}) async {
    final row = await (select(cardReputationVotes)
          ..where((t) =>
              t.cardId.equals(cardId) &
              t.userId.equals(userId) &
              t.isDeleted.equals(false)))
        .getSingleOrNull();
    return row?.vote ?? 0;
  }

  /// Streams the live reputation score, upvotes, downvotes, and active user vote for [cardId].
  Stream<CardReputationSummary> watchReputationScore(
    String cardId, {
    String userId = 'local_user',
  }) {
    final query = customSelect(
      '''
      SELECT 
        COALESCE(vi.reputation_score, 0) AS score,
        COALESCE(vi.upvotes, 0) AS upvotes,
        COALESCE(vi.downvotes, 0) AS downvotes,
        COALESCE(crv.vote, 0) AS user_vote
      FROM (SELECT ? AS id) q
      LEFT JOIN vault_items vi ON vi.id = q.id
      LEFT JOIN card_reputation_votes crv ON crv.card_id = q.id AND crv.user_id = ? AND crv.is_deleted = 0
      LIMIT 1;
      ''',
      variables: [Variable.withString(cardId), Variable.withString(userId)],
      readsFrom: {vaultItems, cardReputationVotes},
    );

    return query.watchSingle().map((row) {
      return CardReputationSummary(
        score: row.read<int>('score'),
        upvotes: row.read<int>('upvotes'),
        downvotes: row.read<int>('downvotes'),
        userVote: row.read<int>('user_vote'),
      );
    });
  }

  /// One-shot fetch of the card's reputation summary.
  Future<CardReputationSummary> getReputationScore(
    String cardId, {
    String userId = 'local_user',
  }) async {
    final query = customSelect(
      '''
      SELECT 
        COALESCE(vi.reputation_score, 0) AS score,
        COALESCE(vi.upvotes, 0) AS upvotes,
        COALESCE(vi.downvotes, 0) AS downvotes,
        COALESCE(crv.vote, 0) AS user_vote
      FROM (SELECT ? AS id) q
      LEFT JOIN vault_items vi ON vi.id = q.id
      LEFT JOIN card_reputation_votes crv ON crv.card_id = q.id AND crv.user_id = ? AND crv.is_deleted = 0
      LIMIT 1;
      ''',
      variables: [Variable.withString(cardId), Variable.withString(userId)],
      readsFrom: {vaultItems, cardReputationVotes},
    );

    final row = await query.getSingle();
    return CardReputationSummary(
      score: row.read<int>('score'),
      upvotes: row.read<int>('upvotes'),
      downvotes: row.read<int>('downvotes'),
      userVote: row.read<int>('user_vote'),
    );
  }
}
