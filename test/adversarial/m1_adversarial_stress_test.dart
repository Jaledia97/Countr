import 'dart:convert';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/profile/presentation/providers/profile_providers.dart';
import 'package:countr/features/feed/presentation/providers/feed_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('Group 1: Database Migration & Schema Stress (v14 -> v16)', () {
    test('Direct jump migration v14 -> v16 creates all v15 & v16 tables and columns without loss', () async {
      final rawDb = NativeDatabase.memory(setup: (raw) {
        raw.execute('PRAGMA user_version = 14;');

        raw.execute('''
          CREATE TABLE "user_profiles" (
            "id" TEXT NOT NULL PRIMARY KEY,
            "username" TEXT NOT NULL,
            "display_name" TEXT NOT NULL,
            "bio" TEXT,
            "avatar_url" TEXT,
            "banner_url" TEXT,
            "account_type" TEXT NOT NULL DEFAULT 'individual',
            "is_verified_business" INTEGER NOT NULL DEFAULT 0,
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
            "dynamic_data" TEXT NOT NULL DEFAULT '{}',
            "is_deleted" INTEGER NOT NULL DEFAULT 0
          );
        ''');

        raw.execute('''
          CREATE TABLE "post_comments" (
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

        raw.execute('''
          INSERT INTO "user_profiles" ("id", "username", "display_name", "created_at")
          VALUES ('user-v14', '@v14user', 'V14 User', 1700000000000);
        ''');

        raw.execute('''
          INSERT INTO "post_comments" ("id", "post_id", "author_id", "author_username", "author_display_name", "content", "created_at", "updated_at")
          VALUES ('comment-v14', 'post-1', 'user-v14', '@v14user', 'V14 User', 'Pre-existing comment', 1700000000000, 1700000000000);
        ''');

        raw.execute('''
          INSERT INTO "vault_items" ("id", "name", "set_or_series")
          VALUES ('vault-v14', 'Mox Diamond', 'ST');
        ''');
      });

      final db = AppDatabase(rawDb);

      final versionResult = await db.customSelect('PRAGMA user_version;').getSingle();
      expect(versionResult.data['user_version'], equals(16));

      // v15 added collection_visibility
      final profile = await db.userProfileDao.getProfile('user-v14');
      expect(profile, isNotNull);
      expect(profile!.collectionVisibility, equals('public'));

      // v16 added parent_comment_id
      final comment = await (db.select(db.postComments)..where((t) => t.id.equals('comment-v14'))).getSingle();
      expect(comment.parentCommentId, isNull);

      // v16 added is_wishlisted
      final vaultItem = await (db.select(db.vaultItems)..where((t) => t.id.equals('vault-v14'))).getSingle();
      expect(vaultItem.isWishlisted, isFalse);

      // v16 new tables
      final tables = (await db.customSelect("SELECT name FROM sqlite_master WHERE type='table';").get())
          .map((r) => r.read<String>('name'))
          .toSet();
      expect(tables, containsAll(['post_votes', 'post_reactions', 'comment_reactions', 'saved_posts']));

      await db.close();
    });

    test('Migration idempotency: existing columns or tables do not fail migration', () async {
      final rawDb = NativeDatabase.memory(setup: (raw) {
        raw.execute('PRAGMA user_version = 15;');

        // Simulate a db that already partially ran v16 migration or had columns pre-created
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
            "dynamic_data" TEXT NOT NULL DEFAULT '{}',
            "is_wishlisted" INTEGER NOT NULL DEFAULT 1,
            "is_deleted" INTEGER NOT NULL DEFAULT 0
          );
        ''');

        raw.execute('''
          CREATE TABLE "post_votes" (
            "id" TEXT NOT NULL PRIMARY KEY,
            "post_id" TEXT NOT NULL,
            "user_id" TEXT NOT NULL,
            "vote" INTEGER NOT NULL DEFAULT 1,
            "created_at" INTEGER NOT NULL,
            "updated_at" INTEGER NOT NULL,
            "deleted_at" INTEGER,
            "is_deleted" INTEGER NOT NULL DEFAULT 0,
            "sync_status" TEXT DEFAULT 'synced'
          );
        ''');

        raw.execute('''
          INSERT INTO "vault_items" ("id", "name", "set_or_series", "is_wishlisted")
          VALUES ('v-wish', 'Force of Will', 'ALL', 1);
        ''');
      });

      // Must open cleanly without "duplicate column" or "table already exists" error
      final db = AppDatabase(rawDb);

      final versionResult = await db.customSelect('PRAGMA user_version;').getSingle();
      expect(versionResult.data['user_version'], equals(16));

      final item = await (db.select(db.vaultItems)..where((t) => t.id.equals('v-wish'))).getSingle();
      expect(item.isWishlisted, isTrue);

      await db.close();
    });

    test('Compound unique keys enforce uniqueness on post_votes, post_reactions, comment_reactions, saved_posts', () async {
      final db = AppDatabase(NativeDatabase.memory());

      // 1. PostVotes: {postId, userId}
      await db.into(db.postVotes).insert(
        PostVotesCompanion.insert(
          id: 'vote-1',
          postId: 'post-1',
          userId: 'user-1',
          vote: const Value(1),
        ),
      );

      // Attempt duplicate (postId, userId) with different id -> constraint failure
      expect(
        () => db.into(db.postVotes).insert(
          PostVotesCompanion.insert(
            id: 'vote-duplicate',
            postId: 'post-1',
            userId: 'user-1',
            vote: const Value(-1),
          ),
        ),
        throwsA(isA<SqliteException>()),
      );

      // 2. PostReactions: {postId, userId, emoji}
      await db.into(db.postReactions).insert(
        PostReactionsCompanion.insert(
          id: 'react-1',
          postId: 'post-1',
          userId: 'user-1',
          emoji: '🔥',
        ),
      );

      // Same user, same post, DIFFERENT emoji -> should SUCCEED
      await db.into(db.postReactions).insert(
        PostReactionsCompanion.insert(
          id: 'react-2',
          postId: 'post-1',
          userId: 'user-1',
          emoji: '❤️',
        ),
      );

      // Same user, same post, SAME emoji -> constraint failure
      expect(
        () => db.into(db.postReactions).insert(
          PostReactionsCompanion.insert(
            id: 'react-duplicate',
            postId: 'post-1',
            userId: 'user-1',
            emoji: '🔥',
          ),
        ),
        throwsA(isA<SqliteException>()),
      );

      // 3. SavedPosts: {postId, userId}
      await db.into(db.savedPosts).insert(
        SavedPostsCompanion.insert(
          id: 'saved-1',
          postId: 'post-1',
          userId: 'user-1',
        ),
      );

      expect(
        () => db.into(db.savedPosts).insert(
          SavedPostsCompanion.insert(
            id: 'saved-duplicate',
            postId: 'post-1',
            userId: 'user-1',
          ),
        ),
        throwsA(isA<SqliteException>()),
      );

      await db.close();
    });
  });

  group('Group 2: Reddit Voting Net Score & Concurrency Stress', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());

      // Seed post author
      await db.into(db.userProfiles).insert(
        UserProfilesCompanion.insert(
          id: 'author-alice',
          username: '@alice',
          displayName: 'Alice Post Author',
          createdAt: DateTime.now(),
        ),
      );

      // Seed post
      await db.into(db.feedPosts).insert(
        FeedPostsCompanion.insert(
          id: 'post-concurrency-test',
          authorId: 'author-alice',
          authorUsername: '@alice',
          authorDisplayName: 'Alice Post Author',
          type: 'text',
          textContent: const Value('Concurrency vote test post'),
        ),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('Rapid consecutive vote flipping by a single user converges to final state', () async {
      // User flips vote: +1 -> -1 -> +1 -> 0 -> -1 in rapid sequence
      final sequence = [1, -1, 1, 0, -1];
      for (final v in sequence) {
        await db.feedDao.votePost('post-concurrency-test', 'user-flipper', v);
      }

      final finalVote = await db.feedDao.getUserPostVote('post-concurrency-test', 'user-flipper');
      expect(finalVote, equals(-1));

      final netScore = await db.feedDao.watchPostNetScore('post-concurrency-test').first;
      expect(netScore, equals(-1));

      final post = await (db.select(db.feedPosts)..where((t) => t.id.equals('post-concurrency-test'))).getSingle();
      expect(post.likeCount, equals(-1));

      // Reset to 0
      await db.feedDao.votePost('post-concurrency-test', 'user-flipper', 0);
      final resetScore = await db.feedDao.watchPostNetScore('post-concurrency-test').first;
      expect(resetScore, equals(0));
    });

    test('High concurrency multi-user voting stress: 40 simultaneous voters compute exact net score', () async {
      // 25 upvotes (+1), 10 downvotes (-1), 5 neutral (0)
      // Expected total net score = 25 - 10 + 0 = 15
      final voters = <Future<int>>[];

      for (int i = 0; i < 25; i++) {
        voters.add(db.feedDao.votePost('post-concurrency-test', 'upvoter_$i', 1));
      }
      for (int i = 0; i < 10; i++) {
        voters.add(db.feedDao.votePost('post-concurrency-test', 'downvoter_$i', -1));
      }
      for (int i = 0; i < 5; i++) {
        voters.add(db.feedDao.votePost('post-concurrency-test', 'neutral_$i', 0));
      }

      await Future.wait(voters);

      final netScore = await db.feedDao.watchPostNetScore('post-concurrency-test').first;
      expect(netScore, equals(15));

      final post = await (db.select(db.feedPosts)..where((t) => t.id.equals('post-concurrency-test'))).getSingle();
      expect(post.likeCount, equals(15));

      // Verify individual user vote records
      expect(await db.feedDao.getUserPostVote('post-concurrency-test', 'upvoter_0'), equals(1));
      expect(await db.feedDao.getUserPostVote('post-concurrency-test', 'downvoter_0'), equals(-1));
      expect(await db.feedDao.getUserPostVote('post-concurrency-test', 'neutral_0'), equals(0));
      expect(await db.feedDao.getUserPostVote('post-concurrency-test', 'non_voter'), equals(0));
    });

    test('Negative net score is accurately calculated and stored in FeedPosts.likeCount', () async {
      // 15 downvotes and 3 upvotes -> net score = -12
      final votes = <Future<int>>[];
      for (int i = 0; i < 15; i++) {
        votes.add(db.feedDao.votePost('post-concurrency-test', 'hater_$i', -1));
      }
      for (int i = 0; i < 3; i++) {
        votes.add(db.feedDao.votePost('post-concurrency-test', 'fan_$i', 1));
      }
      await Future.wait(votes);

      final netScore = await db.feedDao.watchPostNetScore('post-concurrency-test').first;
      expect(netScore, equals(-12));

      final post = await (db.select(db.feedPosts)..where((t) => t.id.equals('post-concurrency-test'))).getSingle();
      expect(post.likeCount, equals(-12));
    });

    test('Self-upvote does not generate notification; other user upvote creates notification; downvote does not', () async {
      // 1. Author Alice upvotes her own post
      await db.feedDao.votePost('post-concurrency-test', 'author-alice', 1);

      var notifs = await (db.select(db.notifications)
            ..where((t) => t.targetEntityId.equals('post-concurrency-test')))
          .get();
      expect(notifs, isEmpty);

      // 2. Bob downvotes Alice's post
      await db.feedDao.votePost('post-concurrency-test', 'user-bob', -1);
      notifs = await (db.select(db.notifications)
            ..where((t) => t.targetEntityId.equals('post-concurrency-test')))
          .get();
      expect(notifs, isEmpty);

      // 3. Bob upvotes Alice's post
      await db.feedDao.votePost('post-concurrency-test', 'user-bob', 1);
      notifs = await (db.select(db.notifications)
            ..where((t) => t.targetEntityId.equals('post-concurrency-test')))
          .get();
      expect(notifs.length, equals(1));
      expect(notifs.first.type, equals('post_vote'));
      expect(notifs.first.userId, equals('author-alice'));
    });
  });

  group('Group 3: Comments, Deep Nesting, Cycle Recovery & True Comment Counting', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());

      // Seed author profile
      await db.into(db.userProfiles).insert(
        UserProfilesCompanion.insert(
          id: 'author-cynthia',
          username: '@cynthia_mtg',
          displayName: 'Cynthia MTG',
          avatarUrl: const Value('https://example.com/cynthia.jpg'),
          createdAt: DateTime.now(),
        ),
      );

      // Seed post
      await db.into(db.feedPosts).insert(
        FeedPostsCompanion.insert(
          id: 'post-comment-deep',
          authorId: 'author-cynthia',
          authorUsername: '@cynthia_mtg',
          authorDisplayName: 'Cynthia MTG',
          type: 'text',
          textContent: const Value('Deep comments post'),
        ),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('Arbitrary depth nesting (15 levels deep) correctly calculates true comment count', () async {
      String? currentParentId;
      final createdIds = <String>[];

      for (int depth = 0; depth < 15; depth++) {
        // Stagger timestamp slightly to avoid any potential millisecond clash
        await Future.delayed(const Duration(milliseconds: 2));

        final comment = await db.feedDao.addComment(
          postId: 'post-comment-deep',
          authorId: 'author-cynthia',
          authorUsername: '@cynthia_mtg',
          authorDisplayName: 'Cynthia MTG',
          content: 'Reply level $depth',
          parentCommentId: currentParentId,
        );

        createdIds.add(comment.id);
        currentParentId = comment.id;
      }

      // 15 total comments
      final count = await db.feedDao.getCommentCount('post-comment-deep');
      expect(count, equals(15));

      final streamedCount = await db.feedDao.watchCommentCount('post-comment-deep').first;
      expect(streamedCount, equals(15));

      final post = await (db.select(db.feedPosts)..where((t) => t.id.equals('post-comment-deep'))).getSingle();
      expect(post.commentCount, equals(15));

      // Verify chain integrity
      final comments = await db.feedDao.watchComments('post-comment-deep').first;
      expect(comments.length, equals(15));
      expect(comments.first.parentCommentId, isNull);
      for (int i = 1; i < 15; i++) {
        expect(comments[i].parentCommentId, equals(createdIds[i - 1]));
      }
    });

    test('Soft deleting comments decrements true total count and excludes from active stream', () async {
      final c1 = await db.feedDao.addComment(
        postId: 'post-comment-deep',
        authorId: 'user-1',
        authorUsername: '@u1',
        authorDisplayName: 'User 1',
        content: 'Root comment 1',
      );
      await Future.delayed(const Duration(milliseconds: 2));

      final c2 = await db.feedDao.addComment(
        postId: 'post-comment-deep',
        authorId: 'user-2',
        authorUsername: '@u2',
        authorDisplayName: 'User 2',
        content: 'Child comment of 1',
        parentCommentId: c1.id,
      );
      await Future.delayed(const Duration(milliseconds: 2));

      final c3 = await db.feedDao.addComment(
        postId: 'post-comment-deep',
        authorId: 'user-3',
        authorUsername: '@u3',
        authorDisplayName: 'User 3',
        content: 'Root comment 2',
      );

      expect(await db.feedDao.getCommentCount('post-comment-deep'), equals(3));

      // Soft delete c2 (the child)
      final now = DateTime.now();
      await (db.update(db.postComments)..where((t) => t.id.equals(c2.id))).write(
        PostCommentsCompanion(
          isDeleted: const Value(true),
          deletedAt: Value(now),
        ),
      );

      // Total count decreases to 2
      expect(await db.feedDao.getCommentCount('post-comment-deep'), equals(2));
      final commentsAfterDelete = await db.feedDao.watchComments('post-comment-deep').first;
      expect(commentsAfterDelete.length, equals(2));
      expect(commentsAfterDelete.map((c) => c.id), containsAll([c1.id, c3.id]));
      expect(commentsAfterDelete.map((c) => c.id), isNot(contains(c2.id)));
    });

    test('Cycle tolerance in comment hierarchy does not deadlock or loop infinitely', () async {
      // Manually insert cyclical parent_comment_id (e.g. A points to B and B points to A)
      final now = DateTime.now();
      await db.into(db.postComments).insert(
        PostCommentsCompanion.insert(
          id: 'cycle-comment-A',
          postId: 'post-comment-deep',
          authorId: 'user-a',
          authorUsername: '@a',
          authorDisplayName: 'A',
          content: 'Cycle A',
          parentCommentId: const Value('cycle-comment-B'),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

      await db.into(db.postComments).insert(
        PostCommentsCompanion.insert(
          id: 'cycle-comment-B',
          postId: 'post-comment-deep',
          authorId: 'user-b',
          authorUsername: '@b',
          authorDisplayName: 'B',
          content: 'Cycle B',
          parentCommentId: const Value('cycle-comment-A'),
          createdAt: Value(now.add(const Duration(milliseconds: 1))),
          updatedAt: Value(now.add(const Duration(milliseconds: 1))),
        ),
      );

      // watchComments and getCommentCount must complete immediately without hanging
      final comments = await db.feedDao.watchComments('post-comment-deep').first;
      expect(comments.length, equals(2));

      final count = await db.feedDao.getCommentCount('post-comment-deep');
      expect(count, equals(2));
    });

    test('Live profile sync: updates in user_profiles reflect immediately in watchComments stream with fallback', () async {
      // 1. Comment authored by Cynthia whose profile exists
      final comment = await db.feedDao.addComment(
        postId: 'post-comment-deep',
        authorId: 'author-cynthia',
        authorUsername: '@cynthia_mtg',
        authorDisplayName: 'Cynthia MTG',
        authorAvatarUrl: 'https://example.com/cynthia.jpg',
        content: 'Original comment text',
      );

      // 2. Comment authored by orphan user with NO profile in user_profiles
      await db.into(db.postComments).insert(
        PostCommentsCompanion.insert(
          id: 'orphan-comment',
          postId: 'post-comment-deep',
          authorId: 'user-unknown-ghost',
          authorUsername: '@ghost_original',
          authorDisplayName: 'Ghost Original',
          content: 'Ghost comment',
        ),
      );

      var comments = await db.feedDao.watchComments('post-comment-deep').first;
      final cynthiaComment = comments.firstWhere((c) => c.id == comment.id);
      final ghostComment = comments.firstWhere((c) => c.id == 'orphan-comment');

      expect(cynthiaComment.authorDisplayName, equals('Cynthia MTG'));
      expect(ghostComment.authorDisplayName, equals('Ghost Original')); // fallback to comment record

      // 3. Update Cynthia's profile
      await (db.update(db.userProfiles)..where((t) => t.id.equals('author-cynthia'))).write(
        const UserProfilesCompanion(
          displayName: Value('Cynthia Grandmaster'),
          username: Value('@cynthia_gm'),
          avatarUrl: Value('https://example.com/cynthia_gm.png'),
        ),
      );

      comments = await db.feedDao.watchComments('post-comment-deep').first;
      final updatedCynthia = comments.firstWhere((c) => c.id == comment.id);
      expect(updatedCynthia.authorDisplayName, equals('Cynthia Grandmaster'));
      expect(updatedCynthia.authorUsername, equals('@cynthia_gm'));
      expect(updatedCynthia.authorAvatarUrl, equals('https://example.com/cynthia_gm.png'));
    });

    test('Concurrent comments by 15 different authors succeed without collision', () async {
      final futures = <Future<PostCommentRecord>>[];
      for (int i = 0; i < 15; i++) {
        futures.add(
          db.feedDao.addComment(
            postId: 'post-comment-deep',
            authorId: 'author_concur_$i',
            authorUsername: '@author_$i',
            authorDisplayName: 'Author $i',
            content: 'Concurrent comment from author $i',
          ),
        );
      }

      final results = await Future.wait(futures);
      expect(results.length, equals(15));

      final count = await db.feedDao.getCommentCount('post-comment-deep');
      expect(count, equals(15));
    });
  });

  group('Group 4: Trade Lifecycle Invariants, Counter-Chains & Cancels', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());

      await db.into(db.userProfiles).insert(
        UserProfilesCompanion.insert(
          id: 'trader-alice',
          username: '@alice',
          displayName: 'Alice Trader',
          createdAt: DateTime.now(),
        ),
      );

      await db.into(db.userProfiles).insert(
        UserProfilesCompanion.insert(
          id: 'trader-bob',
          username: '@bob',
          displayName: 'Bob Trader',
          createdAt: DateTime.now(),
        ),
      );

      await db.into(db.userProfiles).insert(
        UserProfilesCompanion.insert(
          id: 'trader-charlie',
          username: '@charlie',
          displayName: 'Charlie Trader',
          createdAt: DateTime.now(),
        ),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('cancelTradeProposal authorization & idempotency invariants', () async {
      final proposal = await db.inboxDao.createTradeProposal(
        proposerId: 'trader-alice',
        receiverId: 'trader-bob',
        offeredCardIds: ['c1'],
        requestedCardIds: ['c2'],
      );

      // 1. Recipient Bob tries to cancel -> ignored, remains pending
      await db.inboxDao.cancelTradeProposal(proposal.id, currentUserId: 'trader-bob');
      var check = await db.inboxDao.getTradeProposal(proposal.id);
      expect(check!.status, equals('pending'));

      // 2. Random third party Charlie tries to cancel -> ignored, remains pending
      await db.inboxDao.cancelTradeProposal(proposal.id, currentUserId: 'trader-charlie');
      check = await db.inboxDao.getTradeProposal(proposal.id);
      expect(check!.status, equals('pending'));

      // 3. Proposer Alice cancels -> transitions to 'cancelled'
      await db.inboxDao.cancelTradeProposal(proposal.id, currentUserId: 'trader-alice');
      check = await db.inboxDao.getTradeProposal(proposal.id);
      expect(check!.status, equals('cancelled'));

      // 4. Repeated cancel is idempotent no-op
      await db.inboxDao.cancelTradeProposal(proposal.id, currentUserId: 'trader-alice');
      check = await db.inboxDao.getTradeProposal(proposal.id);
      expect(check!.status, equals('cancelled'));
    });

    test('Multi-turn negotiation ping-pong counter-chain maintains single pending proposal invariant', () async {
      // Step 1: Alice creates initial proposal to Bob
      final p1 = await db.inboxDao.createTradeProposal(
        proposerId: 'trader-alice',
        receiverId: 'trader-bob',
        offeredCardIds: ['alice_c1'],
        requestedCardIds: ['bob_c1', 'bob_c2'],
        note: 'Offer 1',
      );
      expect(p1.status, equals('pending'));

      // Step 2: Bob counters Alice
      final p2 = await db.inboxDao.counterTradeProposal(
        p1.id,
        proposerId: 'trader-bob',
        receiverId: 'trader-alice',
        offeredCardIds: ['bob_c1'],
        requestedCardIds: ['alice_c1'],
        note: 'Counter 1',
      );
      expect(p2.status, equals('pending'));
      expect((await db.inboxDao.getTradeProposal(p1.id))!.status, equals('countered'));

      // Step 3: Alice counters Bob back
      final p3 = await db.inboxDao.counterTradeProposal(
        p2.id,
        proposerId: 'trader-alice',
        receiverId: 'trader-bob',
        offeredCardIds: ['alice_c1', 'alice_c2'],
        requestedCardIds: ['bob_c1'],
        note: 'Counter 2',
      );
      expect(p3.status, equals('pending'));
      expect((await db.inboxDao.getTradeProposal(p2.id))!.status, equals('countered'));

      // Step 4: Bob counters Alice again
      final p4 = await db.inboxDao.counterTradeProposal(
        p3.id,
        proposerId: 'trader-bob',
        receiverId: 'trader-alice',
        offeredCardIds: ['bob_c1'],
        requestedCardIds: ['alice_c1'],
        proposerCashDelta: 10.0,
        note: 'Counter 3 + \$10 cash',
      );
      expect(p4.status, equals('pending'));
      expect((await db.inboxDao.getTradeProposal(p3.id))!.status, equals('countered'));

      // Step 5: Bob (proposer of p4) cancels p4
      await db.inboxDao.cancelTradeProposal(p4.id, currentUserId: 'trader-bob');
      expect((await db.inboxDao.getTradeProposal(p4.id))!.status, equals('cancelled'));

      // Invariant check: all prior proposals are countered, last is cancelled, zero pending
      final allProposals = await (db.select(db.tradeProposals)
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .get();
      expect(allProposals.length, equals(4));
      expect(allProposals[0].status, equals('countered'));
      expect(allProposals[1].status, equals('countered'));
      expect(allProposals[2].status, equals('countered'));
      expect(allProposals[3].status, equals('cancelled'));

      final anyPending = allProposals.any((p) => p.status == 'pending');
      expect(anyPending, isFalse);
    });

    test('Attempting to counter cancelled or already countered trade proposal throws StateError', () async {
      final p1 = await db.inboxDao.createTradeProposal(
        proposerId: 'trader-alice',
        receiverId: 'trader-bob',
        offeredCardIds: ['c1'],
        requestedCardIds: ['c2'],
      );

      final p2 = await db.inboxDao.counterTradeProposal(
        p1.id,
        proposerId: 'trader-bob',
        receiverId: 'trader-alice',
        offeredCardIds: ['c2'],
        requestedCardIds: ['c1'],
      );

      // 1. Try to counter p1 again (already countered)
      expect(
        () => db.inboxDao.counterTradeProposal(
          p1.id,
          proposerId: 'trader-bob',
          receiverId: 'trader-alice',
          offeredCardIds: ['c2'],
          requestedCardIds: ['c1'],
        ),
        throwsA(isA<StateError>()),
      );

      // 2. Cancel p2 and try to counter p2 (now cancelled)
      await db.inboxDao.cancelTradeProposal(p2.id, currentUserId: 'trader-bob');
      expect(
        () => db.inboxDao.counterTradeProposal(
          p2.id,
          proposerId: 'trader-alice',
          receiverId: 'trader-bob',
          offeredCardIds: ['c1'],
          requestedCardIds: ['c2'],
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('Group 5: Emoji Reactions & Saved Posts Stress', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());

      await db.into(db.feedPosts).insert(
        FeedPostsCompanion.insert(
          id: 'post-reactions-test',
          authorId: 'author-1',
          authorUsername: '@author1',
          authorDisplayName: 'Author One',
          type: 'text',
          textContent: const Value('Post for reactions stress test'),
        ),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('Multiple distinct emoji reactions per post and comment with grouping summary', () async {
      // 5 users react 🔥, 3 users react ❤️, 2 users react 🤯
      final futures = <Future<void>>[];
      for (int i = 0; i < 5; i++) {
        futures.add(db.feedDao.reactToPost('post-reactions-test', 'user_fire_$i', '🔥'));
      }
      for (int i = 0; i < 3; i++) {
        futures.add(db.feedDao.reactToPost('post-reactions-test', 'user_heart_$i', '❤️'));
      }
      for (int i = 0; i < 2; i++) {
        futures.add(db.feedDao.reactToPost('post-reactions-test', 'user_mind_$i', '🤯'));
      }
      await Future.wait(futures);

      final reactions = await db.feedDao.watchPostReactions('post-reactions-test').first;
      expect(reactions.length, equals(10));

      // User removes reaction
      await db.feedDao.removePostReaction('post-reactions-test', 'user_fire_0', '🔥');
      final reactionsAfter = await db.feedDao.watchPostReactions('post-reactions-test').first;
      expect(reactionsAfter.length, equals(9));

      // Toggle off / on
      final toggledOff = await db.feedDao.togglePostReaction('post-reactions-test', 'user_heart_0', '❤️');
      expect(toggledOff, isFalse);

      final toggledOn = await db.feedDao.togglePostReaction('post-reactions-test', 'user_heart_0', '❤️');
      expect(toggledOn, isTrue);
    });

    test('Saved posts bookmarking lifecycle: 20 rapid saves and unsaves maintain correct counts', () async {
      // Create 20 posts
      for (int i = 0; i < 20; i++) {
        await db.into(db.feedPosts).insert(
          FeedPostsCompanion.insert(
            id: 'post_save_$i',
            authorId: 'author-1',
            authorUsername: '@author1',
            authorDisplayName: 'Author One',
            type: 'text',
            textContent: Value('Save post $i'),
          ),
        );
      }

      // User saves all 20
      for (int i = 0; i < 20; i++) {
        await db.feedDao.savePost('post_save_$i', 'bookmark_user');
      }

      var savedCount = await db.feedDao.watchSavedPostsCount('bookmark_user').first;
      expect(savedCount, equals(20));

      var savedList = await db.feedDao.watchSavedPosts('bookmark_user').first;
      expect(savedList.length, equals(20));

      // Unsave 8 posts
      for (int i = 0; i < 8; i++) {
        await db.feedDao.unsavePost('post_save_$i', 'bookmark_user');
      }

      savedCount = await db.feedDao.watchSavedPostsCount('bookmark_user').first;
      expect(savedCount, equals(12));

      savedList = await db.feedDao.watchSavedPosts('bookmark_user').first;
      expect(savedList.length, equals(12));

      expect(await db.feedDao.isPostSaved('post_save_0', 'bookmark_user'), isFalse);
      expect(await db.feedDao.isPostSaved('post_save_15', 'bookmark_user'), isTrue);
    });

    test('Cash-only trade counter with empty card lists and special unicode characters', () async {
      final p1 = await db.inboxDao.createTradeProposal(
        proposerId: 'author-1',
        receiverId: 'trader-alice',
        offeredCardIds: ['c-initial'],
        requestedCardIds: [],
        note: 'Initial offer with single card',
      );

      final counter = await db.inboxDao.counterTradeProposal(
        p1.id,
        proposerId: 'trader-alice',
        receiverId: 'author-1',
        offeredCardIds: [],
        requestedCardIds: [],
        proposerCashDelta: 45.50,
        note: 'Cash only: \$45.50 for card ⚡️🔥✨ (Special Unicode)',
        fairnessSummaryJson: '{"even": true, "marketDiff": 0.0}',
      );

      expect(counter.status, equals('pending'));
      expect(counter.proposerCashDelta, equals(45.50));
      expect(counter.note, contains('⚡️🔥✨'));
      expect(jsonDecode(counter.offeredCardIdsJson), isEmpty);
      expect(jsonDecode(counter.requestedCardIdsJson), isEmpty);
    });
  });

  group('Group 6: Riverpod Feed Providers Reactive Wire-Up Tests', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());

      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          feedDaoProvider.overrideWithValue(db.feedDao),
          currentUserIdProvider.overrideWith((ref) => 'user-tester'),
        ],
      );

      // Seed post
      await db.into(db.feedPosts).insert(
        FeedPostsCompanion.insert(
          id: 'post-provider-test',
          authorId: 'post-author-xyz',
          authorUsername: '@xyz',
          authorDisplayName: 'XYZ Author',
          type: 'text',
          textContent: const Value('Testing riverpod providers'),
        ),
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('postNetScoreProvider & postUserVoteProvider reactively reflect votes', () async {
      final netScoreHistory = <int>[];
      final voteHistory = <int>[];

      container.listen(
        postNetScoreProvider('post-provider-test'),
        (prev, next) {
          next.whenData(netScoreHistory.add);
        },
        fireImmediately: true,
      );

      container.listen(
        postUserVoteProvider('post-provider-test'),
        (prev, next) {
          next.whenData(voteHistory.add);
        },
        fireImmediately: true,
      );

      await Future.delayed(const Duration(milliseconds: 20));
      expect(netScoreHistory.last, equals(0));
      expect(voteHistory.last, equals(0));

      // Upvote by user-tester
      await db.feedDao.votePost('post-provider-test', 'user-tester', 1);
      await Future.delayed(const Duration(milliseconds: 20));

      expect(netScoreHistory.last, equals(1));
      expect(voteHistory.last, equals(1));

      // Downvote by another user
      await db.feedDao.votePost('post-provider-test', 'user-other', -1);
      await Future.delayed(const Duration(milliseconds: 20));

      expect(netScoreHistory.last, equals(0));
      expect(voteHistory.last, equals(1));
    });

    test('postReactionSummaryProvider correctly aggregates counts and identifies userReacted', () async {
      // React with 💎 by user-tester and other user
      await db.feedDao.reactToPost('post-provider-test', 'user-tester', '💎');
      await db.feedDao.reactToPost('post-provider-test', 'user-other', '💎');
      await db.feedDao.reactToPost('post-provider-test', 'user-other', '🚀');

      final summaries = await container.read(postReactionSummaryProvider('post-provider-test').future);
      expect(summaries.length, equals(2));

      final gem = summaries.firstWhere((s) => s.emoji == '💎');
      expect(gem.count, equals(2));
      expect(gem.userReacted, isTrue);

      final rocket = summaries.firstWhere((s) => s.emoji == '🚀');
      expect(rocket.count, equals(1));
      expect(rocket.userReacted, isFalse);
    });

    test('postIsSavedProvider & savedPostsCountProvider reflect bookmark states', () async {
      final savedHistory = <bool>[];
      final countHistory = <int>[];

      container.listen(
        postIsSavedProvider('post-provider-test'),
        (prev, next) {
          next.whenData(savedHistory.add);
        },
        fireImmediately: true,
      );

      container.listen(
        savedPostsCountProvider,
        (prev, next) {
          next.whenData(countHistory.add);
        },
        fireImmediately: true,
      );

      await Future.delayed(const Duration(milliseconds: 20));
      expect(savedHistory.last, isFalse);
      expect(countHistory.last, equals(0));

      await db.feedDao.savePost('post-provider-test', 'user-tester');
      await Future.delayed(const Duration(milliseconds: 20));

      expect(savedHistory.last, isTrue);
      expect(countHistory.last, equals(1));

      final savedFeedPosts = await db.feedDao.watchSavedPosts('user-tester').first;
      expect(savedFeedPosts.length, equals(1));
      expect(savedFeedPosts.first.id, equals('post-provider-test'));
    });
  });
}

