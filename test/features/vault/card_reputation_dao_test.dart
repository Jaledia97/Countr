import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/data/daos/card_reputation_dao.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';

void main() {
  late AppDatabase db;
  late CardReputationDao reputationDao;
  late VaultDao vaultDao;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    reputationDao = db.cardReputationDao;
    vaultDao = db.vaultDao;
    await vaultDao.clearAllItems();
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> seedCard({
    required String id,
    required String name,
    int initialScore = 0,
    int initialUpvotes = 0,
    int initialDownvotes = 0,
  }) async {
    await db.into(db.vaultItems).insert(
      VaultItemsCompanion.insert(
        id: id,
        collectionType: 'mtg',
        name: name,
        setOrSeries: 'MH3',
        imageUrl: 'https://example.com/$id.png',
        acquiredPrice: 5.0,
        acquiredDate: DateTime.now(),
        quantity: const Value(1),
        condition: 'Near Mint',
        currentMarketPrice: 10.0,
        lastPriceUpdate: DateTime.now(),
        dynamicData: '{}',
        reputationScore: Value(initialScore),
        upvotes: Value(initialUpvotes),
        downvotes: Value(initialDownvotes),
      ),
    );
  }

  group('CardReputationDao - Feature 21 Engine', () {
    test('initial vote and score are 0 for unvoted card', () async {
      await seedCard(id: 'card_sol_ring', name: 'Sol Ring');

      final userVote = await reputationDao.getUserVote('card_sol_ring');
      expect(userVote, equals(0));

      final summary = await reputationDao.getReputationScore('card_sol_ring');
      expect(summary.score, equals(0));
      expect(summary.upvotes, equals(0));
      expect(summary.downvotes, equals(0));
      expect(summary.userVote, equals(0));
    });

    test('upvoting card increments vote, upvotes, and reputation_score', () async {
      await seedCard(id: 'card_rhystic', name: 'Rhystic Study');

      final result = await reputationDao.castVote(
        cardId: 'card_rhystic',
        targetVote: 1,
      );

      expect(result.newVote, equals(1));
      expect(result.newScore, equals(1));
      expect(result.upvotes, equals(1));
      expect(result.downvotes, equals(0));

      final vote = await reputationDao.getUserVote('card_rhystic');
      expect(vote, equals(1));

      final summary = await reputationDao.getReputationScore('card_rhystic');
      expect(summary.score, equals(1));
      expect(summary.upvotes, equals(1));
      expect(summary.downvotes, equals(0));
      expect(summary.userVote, equals(1));
    });

    test('upvoting again toggles vote back to neutral (0)', () async {
      await seedCard(id: 'card_rhystic', name: 'Rhystic Study');

      // First upvote
      await reputationDao.castVote(cardId: 'card_rhystic', targetVote: 1);

      // Second upvote -> toggle off
      final toggleResult = await reputationDao.castVote(
        cardId: 'card_rhystic',
        targetVote: 1,
      );

      expect(toggleResult.newVote, equals(0));
      expect(toggleResult.newScore, equals(0));
      expect(toggleResult.upvotes, equals(0));
      expect(toggleResult.downvotes, equals(0));

      final vote = await reputationDao.getUserVote('card_rhystic');
      expect(vote, equals(0));

      final summary = await reputationDao.getReputationScore('card_rhystic');
      expect(summary.score, equals(0));
      expect(summary.upvotes, equals(0));
      expect(summary.downvotes, equals(0));
    });

    test('downvoting card decrements score and increments downvotes', () async {
      await seedCard(id: 'card_storm_crow', name: 'Storm Crow');

      final result = await reputationDao.castVote(
        cardId: 'card_storm_crow',
        targetVote: -1,
      );

      expect(result.newVote, equals(-1));
      expect(result.newScore, equals(-1));
      expect(result.upvotes, equals(0));
      expect(result.downvotes, equals(1));

      final summary = await reputationDao.getReputationScore('card_storm_crow');
      expect(summary.score, equals(-1));
      expect(summary.upvotes, equals(0));
      expect(summary.downvotes, equals(1));
      expect(summary.userVote, equals(-1));
    });

    test('downvoting again toggles vote back to neutral (0)', () async {
      await seedCard(id: 'card_storm_crow', name: 'Storm Crow');

      await reputationDao.castVote(cardId: 'card_storm_crow', targetVote: -1);
      final toggleResult = await reputationDao.castVote(
        cardId: 'card_storm_crow',
        targetVote: -1,
      );

      expect(toggleResult.newVote, equals(0));
      expect(toggleResult.newScore, equals(0));
      expect(toggleResult.upvotes, equals(0));
      expect(toggleResult.downvotes, equals(0));
    });

    test('switching between upvote and downvote computes delta of 2', () async {
      await seedCard(id: 'card_mana_crypt', name: 'Mana Crypt');

      // Upvote -> +1
      await reputationDao.castVote(cardId: 'card_mana_crypt', targetVote: 1);
      var summary = await reputationDao.getReputationScore('card_mana_crypt');
      expect(summary.score, equals(1));
      expect(summary.upvotes, equals(1));
      expect(summary.downvotes, equals(0));

      // Switch to Downvote -> -1 (delta -2)
      final downResult = await reputationDao.castVote(
        cardId: 'card_mana_crypt',
        targetVote: -1,
      );
      expect(downResult.newVote, equals(-1));
      expect(downResult.newScore, equals(-1));
      expect(downResult.upvotes, equals(0));
      expect(downResult.downvotes, equals(1));

      // Switch back to Upvote -> +1 (delta +2)
      final upResult = await reputationDao.castVote(
        cardId: 'card_mana_crypt',
        targetVote: 1,
      );
      expect(upResult.newVote, equals(1));
      expect(upResult.newScore, equals(1));
      expect(upResult.upvotes, equals(1));
      expect(upResult.downvotes, equals(0));
    });

    test('multiple users can vote independently on the same card', () async {
      await seedCard(id: 'card_cyclonic_rift', name: 'Cyclonic Rift');

      // User 1 upvotes
      await reputationDao.castVote(
        cardId: 'card_cyclonic_rift',
        userId: 'user_1',
        targetVote: 1,
      );

      // User 2 upvotes
      await reputationDao.castVote(
        cardId: 'card_cyclonic_rift',
        userId: 'user_2',
        targetVote: 1,
      );

      // User 3 downvotes
      await reputationDao.castVote(
        cardId: 'card_cyclonic_rift',
        userId: 'user_3',
        targetVote: -1,
      );

      final summary = await reputationDao.getReputationScore(
        'card_cyclonic_rift',
        userId: 'user_1',
      );
      expect(summary.score, equals(1)); // +1 + 1 - 1 = 1
      expect(summary.upvotes, equals(2));
      expect(summary.downvotes, equals(1));
      expect(summary.userVote, equals(1));

      final user3Vote = await reputationDao.getUserVote(
        'card_cyclonic_rift',
        userId: 'user_3',
      );
      expect(user3Vote, equals(-1));
    });

    test('watchReputationScore re-emits when a vote is cast', () async {
      await seedCard(id: 'card_black_lotus', name: 'Black Lotus');

      final stream = reputationDao.watchReputationScore('card_black_lotus');
      final expectation = expectLater(
        stream.map((s) => s.score),
        emitsInOrder([0, 1, 0]),
      );

      await Future<void>.delayed(const Duration(milliseconds: 10));
      await reputationDao.castVote(cardId: 'card_black_lotus', targetVote: 1);

      await Future<void>.delayed(const Duration(milliseconds: 10));
      await reputationDao.castVote(cardId: 'card_black_lotus', targetVote: 1); // toggle to 0

      await expectation;
    });

    test('VaultDao orders by reputationHighest and reputationLowest correctly', () async {
      await seedCard(id: 'c1', name: 'Card Alpha', initialScore: 10);
      await seedCard(id: 'c2', name: 'Card Beta', initialScore: -3);
      await seedCard(id: 'c3', name: 'Card Gamma', initialScore: 25);
      await seedCard(id: 'c4', name: 'Card Delta', initialScore: 0);

      // Highest upvoted
      final highest = await vaultDao.getItemsByCollection(
        'mtg',
        sortOption: VaultSortOption.reputationHighest,
      );
      expect(highest.map((c) => c.id).toList(), equals(['c3', 'c1', 'c4', 'c2']));

      // Lowest / Controversial
      final lowest = await vaultDao.getItemsByCollection(
        'mtg',
        sortOption: VaultSortOption.reputationLowest,
      );
      expect(lowest.map((c) => c.id).toList(), equals(['c2', 'c4', 'c1', 'c3']));
    });
  });
}
