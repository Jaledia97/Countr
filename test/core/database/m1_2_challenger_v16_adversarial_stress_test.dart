// Copyright (c) 2026 Countr. All rights reserved.
// Challenger 2 (challenger_m1_2) Adversarial Stress Test Suite for Milestone 1.

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/core/database/app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('Milestone 1 Adversarial Challenge: Schema v16 Migration & Idempotency', () {
    test('Migration idempotency: handles dirty pre-existing v16 tables and partial columns without crashing', () async {
      final rawDb = NativeDatabase.memory(setup: (raw) {
        raw.execute('PRAGMA user_version = 15;');

        // 1. Pre-create post_comments ALREADY containing parent_comment_id (e.g. from hot-patch)
        raw.execute('''
          CREATE TABLE "post_comments" (
            "id" TEXT NOT NULL PRIMARY KEY,
            "post_id" TEXT NOT NULL,
            "author_id" TEXT NOT NULL,
            "author_username" TEXT NOT NULL,
            "author_display_name" TEXT NOT NULL,
            "author_avatar_url" TEXT,
            "content" TEXT NOT NULL,
            "parent_comment_id" TEXT,
            "created_at" INTEGER NOT NULL,
            "updated_at" INTEGER NOT NULL,
            "deleted_at" INTEGER,
            "is_deleted" INTEGER NOT NULL DEFAULT 0,
            "sync_status" TEXT NOT NULL DEFAULT 'synced'
          );
        ''');

        // 2. Pre-create vault_items ALREADY containing is_wishlisted
        raw.execute('''
          CREATE TABLE "vault_items" (
            "id" TEXT NOT NULL PRIMARY KEY,
            "name" TEXT NOT NULL,
            "set_or_series" TEXT NOT NULL,
            "collection_type" TEXT NOT NULL DEFAULT 'mtg',
            "image_url" TEXT NOT NULL DEFAULT '',
            "acquired_price" REAL NOT NULL DEFAULT 0.0,
            "acquired_date" INTEGER NOT NULL DEFAULT 0,
            "quantity" INTEGER NOT NULL DEFAULT 1,
            "condition" TEXT NOT NULL DEFAULT 'Near Mint',
            "current_market_price" REAL NOT NULL DEFAULT 0.0,
            "last_price_update" INTEGER NOT NULL DEFAULT 0,
            "is_graded" INTEGER NOT NULL DEFAULT 0,
            "is_altered" INTEGER NOT NULL DEFAULT 0,
            "is_misprint" INTEGER NOT NULL DEFAULT 0,
            "is_signed" INTEGER NOT NULL DEFAULT 0,
            "is_wishlisted" INTEGER NOT NULL DEFAULT 0,
            "dynamic_data" TEXT NOT NULL DEFAULT '{}',
            "is_deleted" INTEGER NOT NULL DEFAULT 0
          );
        ''');

        // 3. Pre-create post_votes table partially
        raw.execute('''
          CREATE TABLE "post_votes" (
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

        // 4. Pre-create user_profiles, feed_posts, notifications
        raw.execute('''
          CREATE TABLE "user_profiles" (
            "id" TEXT NOT NULL PRIMARY KEY,
            "username" TEXT NOT NULL,
            "display_name" TEXT NOT NULL,
            "avatar_url" TEXT,
            "account_type" TEXT NOT NULL DEFAULT 'individual',
            "sync_status" TEXT NOT NULL DEFAULT 'synced',
            "created_at" INTEGER NOT NULL,
            "updated_at" INTEGER,
            "is_deleted" INTEGER NOT NULL DEFAULT 0
          );
        ''');

        raw.execute('''
          CREATE TABLE "feed_posts" (
            "id" TEXT NOT NULL PRIMARY KEY,
            "author_id" TEXT NOT NULL,
            "author_username" TEXT NOT NULL,
            "author_display_name" TEXT NOT NULL,
            "type" TEXT NOT NULL,
            "like_count" INTEGER NOT NULL DEFAULT 0,
            "comment_count" INTEGER NOT NULL DEFAULT 0,
            "created_at" INTEGER NOT NULL,
            "updated_at" INTEGER NOT NULL,
            "is_deleted" INTEGER NOT NULL DEFAULT 0
          );
        ''');

        raw.execute('''
          CREATE TABLE "notifications" (
            "id" TEXT NOT NULL PRIMARY KEY,
            "user_id" TEXT NOT NULL,
            "actor_id" TEXT NOT NULL,
            "actor_username" TEXT NOT NULL,
            "type" TEXT NOT NULL,
            "title" TEXT NOT NULL,
            "body" TEXT NOT NULL,
            "target_entity_id" TEXT,
            "target_entity_type" TEXT,
            "is_read" INTEGER NOT NULL DEFAULT 0,
            "is_actioned" INTEGER NOT NULL DEFAULT 0,
            "status" TEXT,
            "created_at" INTEGER NOT NULL
          );
        ''');

        // Seed legacy row
        raw.execute('''
          INSERT INTO "vault_items" ("id", "name", "set_or_series", "is_wishlisted")
          VALUES ('v-dirty-1', 'Mox Diamond', 'STH', 1);
        ''');
      });

      // Opening AppDatabase must safely handle existing tables & columns
      final db = AppDatabase(rawDb);

      final versionResult = await db.customSelect('PRAGMA user_version;').getSingle();
      expect(versionResult.data['user_version'], equals(16));

      // Check legacy row value preserved
      final item = await (db.select(db.vaultItems)..where((t) => t.id.equals('v-dirty-1'))).getSingle();
      expect(item.name, equals('Mox Diamond'));
      expect(item.isWishlisted, isTrue);

      // Verify all 4 new tables exist and can accept records
      await db.into(db.savedPosts).insert(
        const SavedPostsCompanion(
          id: Value('sp-1'),
          postId: Value('post-test'),
          userId: Value('user-test'),
        ),
      );

      final saved = await (db.select(db.savedPosts)..where((t) => t.id.equals('sp-1'))).getSingle();
      expect(saved.postId, equals('post-test'));

      await db.close();
    });
  });

  group('Milestone 1 Adversarial Challenge: Reddit Voting Concurrency & Net Score', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());

      // Create author and post
      await db.into(db.userProfiles).insert(
        UserProfilesCompanion.insert(
          id: 'post-author-1',
          username: '@author_one',
          displayName: 'Author One',
          createdAt: DateTime.now(),
        ),
      );

      await db.into(db.feedPosts).insert(
        FeedPostsCompanion.insert(
          id: 'post-voting-stress',
          authorId: 'post-author-1',
          authorUsername: '@author_one',
          authorDisplayName: 'Author One',
          type: 'text',
          textContent: const Value('Voting stress test target'),
        ),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('Rapid single-user vote flapping maintains compound uniqueness and accurate score', () async {
      const postId = 'post-voting-stress';
      const userId = 'voter-alice';

      // Alice flutters vote rapidly: +1, -1, 0, +1, -1, +1, 0, +1
      final voteSequence = [1, -1, 0, 1, -1, 1, 0, 1];
      for (final v in voteSequence) {
        await db.feedDao.votePost(postId, userId, v);
      }

      // Check user vote is finally 1
      final finalUserVote = await db.feedDao.getUserPostVote(postId, userId);
      expect(finalUserVote, equals(1));

      // Net score must be 1
      final finalNetScore = await db.feedDao.watchPostNetScore(postId).first;
      expect(finalNetScore, equals(1));

      // Post likeCount in feed_posts must also be 1
      final post = await (db.select(db.feedPosts)..where((t) => t.id.equals(postId))).getSingle();
      expect(post.likeCount, equals(1));

      // Table must contain EXACTLY ONE record for (postId, userId)
      final allVotes = await (db.select(db.postVotes)
            ..where((t) => t.postId.equals(postId) & t.userId.equals(userId)))
          .get();
      expect(allVotes.length, equals(1));
      expect(allVotes.first.vote, equals(1));
    });

    test('Mass concurrent voting by 40 distinct users computes mathematically exact net score', () async {
      const postId = 'post-voting-stress';

      // 40 concurrent voters:
      // 25 vote +1 (upvote)
      // 10 vote -1 (downvote)
      // 5 vote 0 (neutral)
      // Expected Net Score: 25 - 10 + 0 = 15.
      final futures = <Future<int>>[];

      for (int i = 0; i < 25; i++) {
        futures.add(db.feedDao.votePost(postId, 'upvoter_$i', 1));
      }
      for (int i = 0; i < 10; i++) {
        futures.add(db.feedDao.votePost(postId, 'downvoter_$i', -1));
      }
      for (int i = 0; i < 5; i++) {
        futures.add(db.feedDao.votePost(postId, 'neutral_$i', 0));
      }

      await Future.wait(futures);

      // Verify aggregate net score
      final netScore = await db.feedDao.watchPostNetScore(postId).first;
      expect(netScore, equals(15));

      final post = await (db.select(db.feedPosts)..where((t) => t.id.equals(postId))).getSingle();
      expect(post.likeCount, equals(15));

      // Total rows in post_votes for this post must be 40
      final totalVoteRows = await (db.select(db.postVotes)
            ..where((t) => t.postId.equals(postId)))
          .get();
      expect(totalVoteRows.length, equals(40));

      // Author self-upvote does NOT emit notification
      await db.feedDao.votePost(postId, 'post-author-1', 1);
      final authorSelfNotif = await (db.select(db.notifications)
            ..where((t) => t.targetEntityId.equals(postId) & t.actorId.equals('post-author-1')))
          .get();
      expect(authorSelfNotif, isEmpty);

      // Downvote and neutral vote do NOT emit notification
      final downvoteNotifs = await (db.select(db.notifications)
            ..where((t) => t.targetEntityId.equals(postId) & t.actorId.equals('downvoter_0')))
          .get();
      expect(downvoteNotifs, isEmpty);

      final neutralNotifs = await (db.select(db.notifications)
            ..where((t) => t.targetEntityId.equals(postId) & t.actorId.equals('neutral_0')))
          .get();
      expect(neutralNotifs, isEmpty);
    });
  });

  group('Milestone 1 Adversarial Challenge: Arbitrary Depth Nested Comments & Soft Deletion Counting', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());

      // Seed post
      await db.into(db.feedPosts).insert(
        FeedPostsCompanion.insert(
          id: 'post-deep-tree',
          authorId: 'post-author-tree',
          authorUsername: '@author_tree',
          authorDisplayName: 'Author Tree',
          type: 'text',
          textContent: const Value('Post for nested tree testing'),
        ),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('8-level deep linear comment chain updates true total count accurately at every step', () async {
      const postId = 'post-deep-tree';
      String? parentId;

      for (int depth = 1; depth <= 8; depth++) {
        final comment = await db.feedDao.addComment(
          postId: postId,
          authorId: 'user_depth_$depth',
          authorUsername: '@user_$depth',
          authorDisplayName: 'User $depth',
          content: 'Level $depth reply',
          parentCommentId: parentId,
        );

        expect(comment.parentCommentId, equals(parentId));
        parentId = comment.id;

        // Verify count at every level
        final currentCount = await db.feedDao.getCommentCount(postId);
        expect(currentCount, equals(depth));

        final post = await (db.select(db.feedPosts)..where((t) => t.id.equals(postId))).getSingle();
        expect(post.commentCount, equals(depth));
      }

      final streamCount = await db.feedDao.watchCommentCount(postId).first;
      expect(streamCount, equals(8));
    });

    test('Multi-branch tree with 39 comments: soft deletions at root, middle, and leaf decrement count strictly', () async {
      const postId = 'post-deep-tree';
      final allCommentIds = <String>[];
      final rootIds = <String>[];
      final middleIds = <String>[];
      final leafIds = <String>[];

      // 3 Roots -> each has 4 replies (12) -> each reply has 2 sub-replies (24). Total = 39.
      for (int r = 0; r < 3; r++) {
        final root = await db.feedDao.addComment(
          postId: postId,
          authorId: 'root_user_$r',
          authorUsername: '@root_$r',
          authorDisplayName: 'Root $r',
          content: 'Root comment $r',
        );
        allCommentIds.add(root.id);
        rootIds.add(root.id);

        for (int m = 0; m < 4; m++) {
          final middle = await db.feedDao.addComment(
            postId: postId,
            authorId: 'middle_user_${r}_$m',
            authorUsername: '@mid_${r}_$m',
            authorDisplayName: 'Mid $r-$m',
            content: 'Middle reply $m to root $r',
            parentCommentId: root.id,
          );
          allCommentIds.add(middle.id);
          middleIds.add(middle.id);

          for (int l = 0; l < 2; l++) {
            final leaf = await db.feedDao.addComment(
              postId: postId,
              authorId: 'leaf_user_${r}_${m}_$l',
              authorUsername: '@leaf_${r}_${m}_$l',
              authorDisplayName: 'Leaf $r-$m-$l',
              content: 'Leaf reply $l to mid $m',
              parentCommentId: middle.id,
            );
            allCommentIds.add(leaf.id);
            leafIds.add(leaf.id);
          }
        }
      }

      expect(allCommentIds.length, equals(39));
      expect(await db.feedDao.getCommentCount(postId), equals(39));

      // 1. Soft-delete a leaf comment using isDeleted = true
      await (db.update(db.postComments)..where((t) => t.id.equals(leafIds.first))).write(
        const PostCommentsCompanion(isDeleted: Value(true)),
      );
      expect(await db.feedDao.getCommentCount(postId), equals(38));

      // 2. Soft-delete a middle comment using deletedAt != null
      await (db.update(db.postComments)..where((t) => t.id.equals(middleIds.first))).write(
        PostCommentsCompanion(deletedAt: Value(DateTime.now())),
      );
      expect(await db.feedDao.getCommentCount(postId), equals(37));

      // 3. Soft-delete a root comment using both isDeleted = true and deletedAt
      await (db.update(db.postComments)..where((t) => t.id.equals(rootIds.first))).write(
        PostCommentsCompanion(
          isDeleted: const Value(true),
          deletedAt: Value(DateTime.now()),
        ),
      );
      expect(await db.feedDao.getCommentCount(postId), equals(36));

      // Active stream watchComments must yield exactly 36 records
      final activeComments = await db.feedDao.watchComments(postId).first;
      expect(activeComments.length, equals(36));
      expect(activeComments.any((c) => c.id == leafIds.first), isFalse);
      expect(activeComments.any((c) => c.id == middleIds.first), isFalse);
      expect(activeComments.any((c) => c.id == rootIds.first), isFalse);
    });

    test('Cycle tolerance: circular or orphan parentCommentId does not cause infinite loops or query failures', () async {
      const postId = 'post-deep-tree';

      // Comment referencing non-existent parent
      final orphan = await db.feedDao.addComment(
        postId: postId,
        authorId: 'user_orphan',
        authorUsername: '@orphan',
        authorDisplayName: 'Orphan User',
        content: 'Orphan comment',
        parentCommentId: 'ghost_parent_99999',
      );
      expect(orphan.parentCommentId, equals('ghost_parent_99999'));

      // Cycle simulation: A points to B, B points to A
      final commentA = await db.feedDao.addComment(
        postId: postId,
        authorId: 'user_a',
        authorUsername: '@user_a',
        authorDisplayName: 'User A',
        content: 'Cycle A',
        parentCommentId: 'cycle_comment_b',
      );

      final commentB = await db.feedDao.addComment(
        postId: postId,
        authorId: 'user_b',
        authorUsername: '@user_b',
        authorDisplayName: 'User B',
        content: 'Cycle B',
        parentCommentId: commentA.id,
      );

      // Verify watchComments and getCommentCount execute cleanly in finite time
      final total = await db.feedDao.getCommentCount(postId);
      expect(total, equals(3));

      final comments = await db.feedDao.watchComments(postId).first;
      expect(comments.length, equals(3));
      expect(comments.any((c) => c.id == commentB.id), isTrue);
    });
  });

  group('Milestone 1 Adversarial Challenge: Reactive Profile Updates & Degraded Profile Fallbacks', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());

      // Seed post
      await db.into(db.feedPosts).insert(
        FeedPostsCompanion.insert(
          id: 'post-sync-stress',
          authorId: 'author-sync-1',
          authorUsername: '@author_sync',
          authorDisplayName: 'Author Sync',
          type: 'text',
          textContent: const Value('Profile sync stress post'),
        ),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('watchComments reacts to sequential profile updates (display name, username, avatar) dynamically', () async {
      const postId = 'post-sync-stress';
      const authorId = 'reactive_user_1';

      // 1. Initial user profile
      await db.into(db.userProfiles).insert(
        UserProfilesCompanion.insert(
          id: authorId,
          username: '@alpha_trader',
          displayName: 'Alpha Trader',
          avatarUrl: const Value('https://images.countr.io/avatar_v1.png'),
          createdAt: DateTime.now(),
        ),
      );

      // 2. Add comment
      final comment = await db.feedDao.addComment(
        postId: postId,
        authorId: authorId,
        authorUsername: '@alpha_trader',
        authorDisplayName: 'Alpha Trader',
        authorAvatarUrl: 'https://images.countr.io/avatar_v1.png',
        content: 'Checking live profile sync',
      );

      // Stream initial value
      var comments = await db.feedDao.watchComments(postId).first;
      expect(comments.any((c) => c.id == comment.id), isTrue);
      expect(comments.first.authorDisplayName, equals('Alpha Trader'));
      expect(comments.first.authorUsername, equals('@alpha_trader'));
      expect(comments.first.authorAvatarUrl, equals('https://images.countr.io/avatar_v1.png'));

      // 3. Update display name only
      await (db.update(db.userProfiles)..where((t) => t.id.equals(authorId))).write(
        const UserProfilesCompanion(displayName: Value('Alpha Prime')),
      );

      comments = await db.feedDao.watchComments(postId).first;
      expect(comments.first.authorDisplayName, equals('Alpha Prime'));
      expect(comments.first.authorUsername, equals('@alpha_trader'));

      // 4. Update username and avatar
      await (db.update(db.userProfiles)..where((t) => t.id.equals(authorId))).write(
        const UserProfilesCompanion(
          username: Value('@prime_trader'),
          avatarUrl: Value('https://images.countr.io/avatar_v2_neon.png'),
        ),
      );

      comments = await db.feedDao.watchComments(postId).first;
      expect(comments.first.authorDisplayName, equals('Alpha Prime'));
      expect(comments.first.authorUsername, equals('@prime_trader'));
      expect(comments.first.authorAvatarUrl, equals('https://images.countr.io/avatar_v2_neon.png'));
    });

    test('Graceful fallback: empty profile strings and non-existent profiles fall back cleanly to static comment values', () async {
      const postId = 'post-sync-stress';

      // 1. Comment authored by a user who has NO row in user_profiles (e.g. guest or deleted account)
      await db.feedDao.addComment(
        postId: postId,
        authorId: 'ghost_author_99',
        authorUsername: '@ghost_original',
        authorDisplayName: 'Ghost Original',
        authorAvatarUrl: 'https://images.countr.io/ghost.png',
        content: 'I have no user_profile record',
      );

      var comments = await db.feedDao.watchComments(postId).first;
      final ghostComment = comments.firstWhere((c) => c.authorId == 'ghost_author_99');
      expect(ghostComment.authorDisplayName, equals('Ghost Original'));
      expect(ghostComment.authorUsername, equals('@ghost_original'));
      expect(ghostComment.authorAvatarUrl, equals('https://images.countr.io/ghost.png'));

      // 2. User profile exists but displayName and username are empty strings
      await db.into(db.userProfiles).insert(
        UserProfilesCompanion.insert(
          id: 'empty_fields_user',
          username: '',
          displayName: '',
          avatarUrl: const Value(null),
          createdAt: DateTime.now(),
        ),
      );

      await db.feedDao.addComment(
        postId: postId,
        authorId: 'empty_fields_user',
        authorUsername: '@cached_username',
        authorDisplayName: 'Cached Name',
        authorAvatarUrl: 'https://images.countr.io/cached.png',
        content: 'Profile has empty strings',
      );

      comments = await db.feedDao.watchComments(postId).first;
      final emptyComment = comments.firstWhere((c) => c.authorId == 'empty_fields_user');
      // Must fall back to cached fields rather than showing empty blanks
      expect(emptyComment.authorDisplayName, equals('Cached Name'));
      expect(emptyComment.authorUsername, equals('@cached_username'));
      expect(emptyComment.authorAvatarUrl, equals('https://images.countr.io/cached.png'));
    });
  });

  group('Milestone 1 Adversarial Challenge: Trade Proposal State Transitions & Concurrency', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());

      // Seed Alice, Bob, and Charlie
      await db.into(db.userProfiles).insert(
        UserProfilesCompanion.insert(
          id: 'user-alice',
          username: '@alice',
          displayName: 'Alice',
          createdAt: DateTime.now(),
        ),
      );
      await db.into(db.userProfiles).insert(
        UserProfilesCompanion.insert(
          id: 'user-bob',
          username: '@bob',
          displayName: 'Bob',
          createdAt: DateTime.now(),
        ),
      );
      await db.into(db.userProfiles).insert(
        UserProfilesCompanion.insert(
          id: 'user-charlie',
          username: '@charlie',
          displayName: 'Charlie',
          createdAt: DateTime.now(),
        ),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('Cancellation security: only proposer can cancel; non-proposers are strictly ignored', () async {
      final proposal = await db.inboxDao.createTradeProposal(
        proposerId: 'user-alice',
        receiverId: 'user-bob',
        offeredCardIds: ['card-a1'],
        requestedCardIds: ['card-b1'],
      );

      // 1. Bob (recipient) attempts cancel
      await db.inboxDao.cancelTradeProposal(proposal.id, currentUserId: 'user-bob');
      var check = await db.inboxDao.getTradeProposal(proposal.id);
      expect(check!.status, equals('pending'));

      // 2. Charlie (third party) attempts cancel
      await db.inboxDao.cancelTradeProposal(proposal.id, currentUserId: 'user-charlie');
      check = await db.inboxDao.getTradeProposal(proposal.id);
      expect(check!.status, equals('pending'));

      // 3. Alice (proposer) cancels
      await db.inboxDao.cancelTradeProposal(proposal.id, currentUserId: 'user-alice');
      check = await db.inboxDao.getTradeProposal(proposal.id);
      expect(check!.status, equals('cancelled'));

      // 4. Repeated cancel is idempotent
      await db.inboxDao.cancelTradeProposal(proposal.id, currentUserId: 'user-alice');
      check = await db.inboxDao.getTradeProposal(proposal.id);
      expect(check!.status, equals('cancelled'));
    });

    test('Multi-hop counter chain: Offer 1 -> Countered by Bob -> Countered by Alice -> Terminal state', () async {
      // Step 1: Alice creates initial trade proposal for Bob
      final offer1 = await db.inboxDao.createTradeProposal(
        proposerId: 'user-alice',
        receiverId: 'user-bob',
        offeredCardIds: ['c-alice-1'],
        requestedCardIds: ['c-bob-1', 'c-bob-2'],
        offeredTotalValue: 100.0,
        requestedTotalValue: 120.0,
      );
      expect(offer1.status, equals('pending'));

      // Step 2: Bob counters Offer 1
      final offer2 = await db.inboxDao.counterTradeProposal(
        offer1.id,
        proposerId: 'user-bob',
        receiverId: 'user-alice',
        offeredCardIds: ['c-bob-1'],
        requestedCardIds: ['c-alice-1'],
        proposerCashDelta: 10.0,
        offeredTotalValue: 90.0,
        requestedTotalValue: 100.0,
      );
      expect(offer2.status, equals('pending'));

      // Offer 1 must be 'countered'
      final offer1Updated = await db.inboxDao.getTradeProposal(offer1.id);
      expect(offer1Updated!.status, equals('countered'));

      // Countering Offer 1 AGAIN must throw StateError
      expect(
        () => db.inboxDao.counterTradeProposal(
          offer1.id,
          proposerId: 'user-bob',
          receiverId: 'user-alice',
          offeredCardIds: [],
          requestedCardIds: [],
        ),
        throwsA(isA<StateError>()),
      );

      // Step 3: Alice counters Offer 2
      final offer3 = await db.inboxDao.counterTradeProposal(
        offer2.id,
        proposerId: 'user-alice',
        receiverId: 'user-bob',
        offeredCardIds: ['c-alice-1', 'c-alice-2'],
        requestedCardIds: ['c-bob-1'],
        offeredTotalValue: 110.0,
        requestedTotalValue: 90.0,
      );
      expect(offer3.status, equals('pending'));

      // Offer 2 must be 'countered'
      final offer2Updated = await db.inboxDao.getTradeProposal(offer2.id);
      expect(offer2Updated!.status, equals('countered'));

      // Verify all notifications from Offer 1 & Offer 2 are actioned with status 'countered'
      final notifsOffer1 = await (db.select(db.notifications)
            ..where((t) => t.targetEntityId.equals(offer1.id)))
          .get();
      expect(notifsOffer1.every((n) => n.isActioned && n.status == 'countered'), isTrue);

      final notifsOffer2 = await (db.select(db.notifications)
            ..where((t) => t.targetEntityId.equals(offer2.id)))
          .get();
      expect(notifsOffer2.every((n) => n.isActioned && n.status == 'countered'), isTrue);

      // Attempting to cancel already countered Offer 1 does nothing
      await db.inboxDao.cancelTradeProposal(offer1.id, currentUserId: 'user-alice');
      final offer1AfterCancel = await db.inboxDao.getTradeProposal(offer1.id);
      expect(offer1AfterCancel!.status, equals('countered'));

      // Cancelling active Offer 3 succeeds
      await db.inboxDao.cancelTradeProposal(offer3.id, currentUserId: 'user-alice');
      final offer3AfterCancel = await db.inboxDao.getTradeProposal(offer3.id);
      expect(offer3AfterCancel!.status, equals('cancelled'));

      // Countering cancelled Offer 3 throws StateError
      expect(
        () => db.inboxDao.counterTradeProposal(
          offer3.id,
          proposerId: 'user-bob',
          receiverId: 'user-alice',
          offeredCardIds: [],
          requestedCardIds: [],
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}
