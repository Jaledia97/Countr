import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/core/database/app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('Auditor Adversarial Stress Test: Milestone 1 Invariants', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      // Seed user profiles
      await db.into(db.userProfiles).insert(
        UserProfilesCompanion.insert(
          id: 'user-adversary-1',
          username: '@adv1',
          displayName: 'Adversary One',
          createdAt: DateTime.now(),
        ),
      );
      await db.into(db.userProfiles).insert(
        UserProfilesCompanion.insert(
          id: 'user-adversary-2',
          username: '@adv2',
          displayName: 'Adversary Two',
          createdAt: DateTime.now(),
        ),
      );
      await db.into(db.feedPosts).insert(
        FeedPostsCompanion.insert(
          id: 'post-adversarial-1',
          authorId: 'user-adversary-1',
          authorUsername: '@adv1',
          authorDisplayName: 'Adversary One',
          type: 'text',
          textContent: const Value('Stress test post'),
        ),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('Stress Test 1: Rapid voting flips, multi-user net score math, and neutrality', () async {
      const postId = 'post-adversarial-1';
      // User 1 flips: +1 -> -1 -> +1 -> 0 -> +1
      await db.feedDao.votePost(postId, 'user-adversary-1', 1);
      await db.feedDao.votePost(postId, 'user-adversary-1', -1);
      await db.feedDao.votePost(postId, 'user-adversary-1', 1);
      await db.feedDao.votePost(postId, 'user-adversary-1', 0);
      await db.feedDao.votePost(postId, 'user-adversary-1', 1);

      // User 2: -1
      await db.feedDao.votePost(postId, 'user-adversary-2', -1);

      // Verify net score = 1 + (-1) = 0
      final netScore = await db.feedDao.watchPostNetScore(postId).first;
      expect(netScore, equals(0));

      final post = await (db.select(db.feedPosts)..where((t) => t.id.equals(postId))).getSingle();
      expect(post.likeCount, equals(0));

      // User 2 removes vote -> net score should become +1
      await db.feedDao.votePost(postId, 'user-adversary-2', 0);
      final netScore2 = await db.feedDao.watchPostNetScore(postId).first;
      expect(netScore2, equals(1));
    });

    test('Stress Test 2: Deep multi-level nested replies (depth 4) and soft-deleted comment count', () async {
      const postId = 'post-adversarial-1';

      // Level 1 (Root)
      final l1 = await db.feedDao.addComment(
        postId: postId,
        authorId: 'user-adversary-1',
        authorUsername: '@adv1',
        authorDisplayName: 'Adversary One',
        content: 'Level 1 comment',
      );
      expect(l1.parentCommentId, isNull);

      // Level 2 (Child of L1)
      final l2 = await db.feedDao.addComment(
        postId: postId,
        authorId: 'user-adversary-2',
        authorUsername: '@adv2',
        authorDisplayName: 'Adversary Two',
        content: 'Level 2 reply',
        parentCommentId: l1.id,
      );
      expect(l2.parentCommentId, equals(l1.id));

      // Level 3 (Child of L2)
      final l3 = await db.feedDao.addComment(
        postId: postId,
        authorId: 'user-adversary-1',
        authorUsername: '@adv1',
        authorDisplayName: 'Adversary One',
        content: 'Level 3 reply',
        parentCommentId: l2.id,
      );
      expect(l3.parentCommentId, equals(l2.id));

      // Level 4 (Child of L3)
      final l4 = await db.feedDao.addComment(
        postId: postId,
        authorId: 'user-adversary-2',
        authorUsername: '@adv2',
        authorDisplayName: 'Adversary Two',
        content: 'Level 4 reply',
        parentCommentId: l3.id,
      );
      expect(l4.parentCommentId, equals(l3.id));

      // Total count across all 4 levels must be 4
      var total = await db.feedDao.getCommentCount(postId);
      expect(total, equals(4));

      var streamedTotal = await db.feedDao.watchCommentCount(postId).first;
      expect(streamedTotal, equals(4));

      // Soft-delete level 3
      await (db.update(db.postComments)..where((t) => t.id.equals(l3.id))).write(
        PostCommentsCompanion(
          isDeleted: const Value(true),
          deletedAt: Value(DateTime.now()),
        ),
      );

      // Active count should now be 3
      total = await db.feedDao.getCommentCount(postId);
      expect(total, equals(3));

      streamedTotal = await db.feedDao.watchCommentCount(postId).first;
      expect(streamedTotal, equals(3));
    });

    test('Stress Test 3: Multiple emoji reactions on same comment, toggle idempotency', () async {
      const commentId = 'comment-adversarial-1';
      // User 1 adds 🔥, ❤️, 💎
      await db.feedDao.reactToComment(commentId, 'user-adversary-1', '🔥');
      await db.feedDao.reactToComment(commentId, 'user-adversary-1', '❤️');
      await db.feedDao.reactToComment(commentId, 'user-adversary-1', '💎');

      var reactions = await db.feedDao.watchCommentReactions(commentId).first;
      expect(reactions.length, equals(3));

      // Toggle 🔥 off -> should be 2
      final off = await db.feedDao.toggleCommentReaction(commentId, 'user-adversary-1', '🔥');
      expect(off, isFalse);

      reactions = await db.feedDao.watchCommentReactions(commentId).first;
      expect(reactions.length, equals(2));

      // Toggle 🔥 back on -> should be 3
      final on = await db.feedDao.toggleCommentReaction(commentId, 'user-adversary-1', '🔥');
      expect(on, isTrue);

      reactions = await db.feedDao.watchCommentReactions(commentId).first;
      expect(reactions.length, equals(3));
    });

    test('Stress Test 4: Trade proposal state machine defenses (counter after cancel, cancel by outsider)', () async {
      // 1. Create trade proposal
      final proposal = await db.inboxDao.createTradeProposal(
        proposerId: 'user-adversary-1',
        receiverId: 'user-adversary-2',
        offeredCardIds: ['c1'],
        requestedCardIds: ['c2'],
      );

      // 2. Outsider attempts cancel -> no-op, still pending
      await db.inboxDao.cancelTradeProposal(proposal.id, currentUserId: 'outsider-attacker');
      var check = await db.inboxDao.getTradeProposal(proposal.id);
      expect(check!.status, equals('pending'));

      // 3. Proposer cancels
      await db.inboxDao.cancelTradeProposal(proposal.id, currentUserId: 'user-adversary-1');
      check = await db.inboxDao.getTradeProposal(proposal.id);
      expect(check!.status, equals('cancelled'));

      // 4. Attempt to counter cancelled proposal -> must throw StateError
      expect(
        () => db.inboxDao.counterTradeProposal(
          proposal.id,
          proposerId: 'user-adversary-2',
          receiverId: 'user-adversary-1',
          offeredCardIds: ['c2'],
          requestedCardIds: ['c1'],
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('Stress Test 5: Saved posts toggle idempotency and user scoping', () async {
      const postId = 'post-adversarial-1';

      // User 1 saves
      await db.feedDao.savePost(postId, 'user-adversary-1');
      expect(await db.feedDao.isPostSaved(postId, 'user-adversary-1'), isTrue);
      // User 2 has NOT saved
      expect(await db.feedDao.isPostSaved(postId, 'user-adversary-2'), isFalse);

      // Counts
      expect(await db.feedDao.watchSavedPostsCount('user-adversary-1').first, equals(1));
      expect(await db.feedDao.watchSavedPostsCount('user-adversary-2').first, equals(0));

      // User 1 toggles (unsaves)
      await db.feedDao.toggleSavePost(postId, 'user-adversary-1');
      expect(await db.feedDao.isPostSaved(postId, 'user-adversary-1'), isFalse);
      expect(await db.feedDao.watchSavedPostsCount('user-adversary-1').first, equals(0));
    });
  });
}
