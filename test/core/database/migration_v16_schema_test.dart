import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/core/database/app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('Drift Schema v15 to v16 Migration & Reactive Social DAO Tests', () {
    test('upgrades from schema v15 to v16, adds parent_comment_id and is_wishlisted without data loss', () async {
      // 1. Initialize raw SQLite database simulating schema v15
      final rawDb = NativeDatabase.memory(setup: (raw) {
        raw.execute('PRAGMA user_version = 15;');

        // Post comments table as of schema v15 (NO parent_comment_id)
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

        // Vault items table as of schema v15 (NO is_wishlisted)
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

        // User profiles table
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
            "collection_visibility" TEXT NOT NULL DEFAULT 'public',
            "sync_status" TEXT NOT NULL DEFAULT 'synced',
            "created_at" INTEGER NOT NULL,
            "updated_at" INTEGER,
            "deleted_at" INTEGER,
            "is_deleted" INTEGER NOT NULL DEFAULT 0
          );
        ''');

        // Feed posts table
        raw.execute('''
          CREATE TABLE "feed_posts" (
            "id" TEXT NOT NULL PRIMARY KEY,
            "author_id" TEXT NOT NULL,
            "author_username" TEXT NOT NULL,
            "author_display_name" TEXT NOT NULL,
            "author_avatar_url" TEXT,
            "type" TEXT NOT NULL,
            "text_content" TEXT,
            "like_count" INTEGER NOT NULL DEFAULT 0,
            "comment_count" INTEGER NOT NULL DEFAULT 0,
            "created_at" INTEGER NOT NULL,
            "updated_at" INTEGER NOT NULL,
            "deleted_at" INTEGER,
            "is_deleted" INTEGER NOT NULL DEFAULT 0,
            "sync_status" TEXT NOT NULL DEFAULT 'synced'
          );
        ''');

        // Notifications table
        raw.execute('''
          CREATE TABLE "notifications" (
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
            "is_read" INTEGER NOT NULL DEFAULT 0,
            "is_actioned" INTEGER NOT NULL DEFAULT 0,
            "status" TEXT,
            "created_at" INTEGER NOT NULL,
            "updated_at" INTEGER,
            "deleted_at" INTEGER,
            "is_deleted" INTEGER NOT NULL DEFAULT 0
          );
        ''');

        // Pre-insert legacy items in v15
        raw.execute('''
          INSERT INTO "post_comments" (
            "id", "post_id", "author_id", "author_username", "author_display_name", "content", "created_at", "updated_at"
          ) VALUES (
            'comment-v15-1', 'post-1', 'user-1', '@alpha_trader', 'Alpha Trader', 'Legacy comment pre-migration', 1700000000000, 1700000000000
          );
        ''');

        raw.execute('''
          INSERT INTO "vault_items" (
            "id", "name", "set_or_series", "current_market_price", "acquired_date"
          ) VALUES (
            'vault-v15-1', 'Black Lotus', 'LEA', 50000.0, 1700000000000
          );
        ''');

        raw.execute('''
          INSERT INTO "user_profiles" (
            "id", "username", "display_name", "created_at"
          ) VALUES (
            'user-1', '@alpha_trader', 'Alpha Trader', 1700000000000
          );
        ''');

        raw.execute('''
          INSERT INTO "feed_posts" (
            "id", "author_id", "author_username", "author_display_name", "type", "text_content", "created_at", "updated_at"
          ) VALUES (
            'post-1', 'user-1', '@alpha_trader', 'Alpha Trader', 'single_pull', 'Check this lotus', 1700000000000, 1700000000000
          );
        ''');
      });

      // 2. Open AppDatabase on top of the v15 database
      final db = AppDatabase(rawDb);

      // Verify schema version is bumped to 16
      final versionResult = await db.customSelect('PRAGMA user_version;').getSingle();
      final currentVersion = versionResult.data['user_version'] as int;
      expect(currentVersion, equals(16));

      // 3. Verify columns created in table_info
      final commentTableInfo = await db.customSelect('PRAGMA table_info("post_comments");').get();
      final commentColumns = commentTableInfo.map((r) => r.read<String>('name')).toSet();
      expect(commentColumns, contains('parent_comment_id'));

      final vaultTableInfo = await db.customSelect('PRAGMA table_info("vault_items");').get();
      final vaultColumns = vaultTableInfo.map((r) => r.read<String>('name')).toSet();
      expect(vaultColumns, contains('is_wishlisted'));

      // 4. Verify 4 new tables exist in sqlite_master
      final masterTables = await db.customSelect(
        "SELECT name FROM sqlite_master WHERE type='table';",
      ).get();
      final tableNames = masterTables.map((r) => r.read<String>('name')).toSet();
      expect(tableNames, containsAll(['post_votes', 'post_reactions', 'comment_reactions', 'saved_posts']));

      // 5. Verify legacy post_comments data intact and parentCommentId is null
      final legacyComment = await (db.select(db.postComments)..where((t) => t.id.equals('comment-v15-1'))).getSingle();
      expect(legacyComment.content, equals('Legacy comment pre-migration'));
      expect(legacyComment.parentCommentId, isNull);

      // 6. Verify legacy vault_items data intact and isWishlisted is false
      final legacyVaultItem = await (db.select(db.vaultItems)..where((t) => t.id.equals('vault-v15-1'))).getSingle();
      expect(legacyVaultItem.name, equals('Black Lotus'));
      expect(legacyVaultItem.isWishlisted, isFalse);

      await db.close();
    });

    test('verifies Reddit-style voting and net score reactivity in FeedDao', () async {
      final db = AppDatabase(NativeDatabase.memory());

      // Seed post
      await db.into(db.feedPosts).insert(
        FeedPostsCompanion.insert(
          id: 'post-vote-test',
          authorId: 'author-alice',
          authorUsername: '@alice',
          authorDisplayName: 'Alice',
          type: 'text',
          textContent: const Value('Vote on this!'),
        ),
      );

      // 1. Initial vote state
      final initialVote = await db.feedDao.getUserPostVote('post-vote-test', 'user-bob');
      expect(initialVote, equals(0));

      // 2. Upvote post (+1)
      final scoreAfterUpvote = await db.feedDao.votePost('post-vote-test', 'user-bob', 1);
      expect(scoreAfterUpvote, equals(1));

      final voteBob = await db.feedDao.getUserPostVote('post-vote-test', 'user-bob');
      expect(voteBob, equals(1));

      final postAfterUpvote = await (db.select(db.feedPosts)..where((t) => t.id.equals('post-vote-test'))).getSingle();
      expect(postAfterUpvote.likeCount, equals(1));

      // Notification sent to author-alice
      final notif = await (db.select(db.notifications)..where((t) => t.targetEntityId.equals('post-vote-test'))).getSingleOrNull();
      expect(notif, isNotNull);
      expect(notif!.type, equals('post_vote'));
      expect(notif.userId, equals('author-alice'));

      // 3. Charlie downvotes post (-1)
      await db.feedDao.votePost('post-vote-test', 'user-charlie', -1);
      final netScoreAfterCharlie = await db.feedDao.watchPostNetScore('post-vote-test').first;
      expect(netScoreAfterCharlie, equals(0)); // +1 - 1 = 0

      // 4. Bob changes vote to downvote (-1)
      await db.feedDao.votePost('post-vote-test', 'user-bob', -1);
      final netScoreDoubleDown = await db.feedDao.watchPostNetScore('post-vote-test').first;
      expect(netScoreDoubleDown, equals(-2)); // -1 - 1 = -2

      // 5. Bob resets vote to neutral (0)
      await db.feedDao.votePost('post-vote-test', 'user-bob', 0);
      final netScoreReset = await db.feedDao.watchPostNetScore('post-vote-test').first;
      expect(netScoreReset, equals(-1)); // 0 - 1 = -1

      await db.close();
    });

    test('verifies post and comment emoji reactions in FeedDao', () async {
      final db = AppDatabase(NativeDatabase.memory());

      // 1. Post reactions
      await db.feedDao.reactToPost('post-1', 'user-1', '🔥');
      await db.feedDao.reactToPost('post-1', 'user-2', '🔥');
      await db.feedDao.reactToPost('post-1', 'user-1', '❤️');

      var postReactions = await db.feedDao.watchPostReactions('post-1').first;
      expect(postReactions.length, equals(3));

      // Toggle off 🔥 for user-1
      final toggledOff = await db.feedDao.togglePostReaction('post-1', 'user-1', '🔥');
      expect(toggledOff, isFalse);

      postReactions = await db.feedDao.watchPostReactions('post-1').first;
      expect(postReactions.length, equals(2));

      // Toggle on 🔥 for user-1
      final toggledOn = await db.feedDao.togglePostReaction('post-1', 'user-1', '🔥');
      expect(toggledOn, isTrue);

      postReactions = await db.feedDao.watchPostReactions('post-1').first;
      expect(postReactions.length, equals(3));

      // 2. Comment reactions
      await db.feedDao.reactToComment('comment-1', 'user-1', '💎');
      await db.feedDao.reactToComment('comment-1', 'user-2', '💎');

      var commentReactions = await db.feedDao.watchCommentReactions('comment-1').first;
      expect(commentReactions.length, equals(2));

      await db.feedDao.removeCommentReaction('comment-1', 'user-1', '💎');
      commentReactions = await db.feedDao.watchCommentReactions('comment-1').first;
      expect(commentReactions.length, equals(1));
      expect(commentReactions.first.userId, equals('user-2'));

      await db.close();
    });

    test('verifies saved posts (bookmarks) lifecycle in FeedDao', () async {
      final db = AppDatabase(NativeDatabase.memory());

      // Seed post and author profile
      await db.into(db.userProfiles).insert(
        UserProfilesCompanion.insert(
          id: 'author-dave',
          username: '@dave_mtg',
          displayName: 'Dave MTG',
          avatarUrl: const Value('https://example.com/dave.jpg'),
          createdAt: DateTime.now(),
        ),
      );

      await db.into(db.feedPosts).insert(
        FeedPostsCompanion.insert(
          id: 'post-save-test',
          authorId: 'author-dave',
          authorUsername: '@dave_mtg',
          authorDisplayName: 'Dave MTG',
          type: 'text',
          textContent: const Value('Bookmark me for later'),
        ),
      );

      // Check initial saved status
      var isSaved = await db.feedDao.isPostSaved('post-save-test', 'user-me');
      expect(isSaved, isFalse);

      var count = await db.feedDao.watchSavedPostsCount('user-me').first;
      expect(count, equals(0));

      // Save post
      await db.feedDao.savePost('post-save-test', 'user-me');

      isSaved = await db.feedDao.isPostSaved('post-save-test', 'user-me');
      expect(isSaved, isTrue);

      count = await db.feedDao.watchSavedPostsCount('user-me').first;
      expect(count, equals(1));

      // Watch saved posts streams joined FeedPostRecord with resolved profile metadata
      final savedPosts = await db.feedDao.watchSavedPosts('user-me').first;
      expect(savedPosts.length, equals(1));
      expect(savedPosts.first.id, equals('post-save-test'));
      expect(savedPosts.first.authorDisplayName, equals('Dave MTG'));
      expect(savedPosts.first.authorAvatarUrl, equals('https://example.com/dave.jpg'));

      // Toggle save (unsaves)
      final toggleResult = await db.feedDao.toggleSavePost('post-save-test', 'user-me');
      expect(toggleResult, isFalse);

      count = await db.feedDao.watchSavedPostsCount('user-me').first;
      expect(count, equals(0));

      await db.close();
    });

    test('verifies reactive profile LEFT JOIN in watchComments and nested thread counting', () async {
      final db = AppDatabase(NativeDatabase.memory());

      // 1. Seed author profile
      await db.into(db.userProfiles).insert(
        UserProfilesCompanion.insert(
          id: 'author-eva',
          username: '@eva_initial',
          displayName: 'Eva Initial',
          avatarUrl: const Value('https://example.com/initial.jpg'),
          createdAt: DateTime.now(),
        ),
      );

      await db.into(db.feedPosts).insert(
        FeedPostsCompanion.insert(
          id: 'post-comment-sync-test',
          authorId: 'author-eva',
          authorUsername: '@eva_initial',
          authorDisplayName: 'Eva Initial',
          type: 'text',
          textContent: const Value('Leave comments'),
        ),
      );

      // 2. Add top-level comment
      final rootComment = await db.feedDao.addComment(
        postId: 'post-comment-sync-test',
        authorId: 'author-eva',
        authorUsername: '@eva_initial',
        authorDisplayName: 'Eva Initial',
        authorAvatarUrl: 'https://example.com/initial.jpg',
        content: 'Root comment',
      );
      expect(rootComment.parentCommentId, isNull);

      // Verify comment stream returns profile values
      var comments = await db.feedDao.watchComments('post-comment-sync-test').first;
      expect(comments.length, equals(1));
      expect(comments.first.authorDisplayName, equals('Eva Initial'));
      expect(comments.first.authorAvatarUrl, equals('https://example.com/initial.jpg'));

      // 3. Add nested reply comment linked via parentCommentId
      final replyComment = await db.feedDao.addComment(
        postId: 'post-comment-sync-test',
        authorId: 'user-replyer',
        authorUsername: '@replyer',
        authorDisplayName: 'Replyer',
        content: 'Nested reply to root',
        parentCommentId: rootComment.id,
      );
      expect(replyComment.parentCommentId, equals(rootComment.id));

      // 4. Verify true total count across nested thread levels
      final totalCount = await db.feedDao.getCommentCount('post-comment-sync-test');
      expect(totalCount, equals(2));

      final streamedCount = await db.feedDao.watchCommentCount('post-comment-sync-test').first;
      expect(streamedCount, equals(2));

      // Post record commentCount was atomically updated
      final post = await (db.select(db.feedPosts)..where((t) => t.id.equals('post-comment-sync-test'))).getSingle();
      expect(post.commentCount, equals(2));

      // 5. Test Live Profile Sync: Update author-eva in user_profiles
      await (db.update(db.userProfiles)..where((t) => t.id.equals('author-eva'))).write(
        const UserProfilesCompanion(
          displayName: Value('Eva Updated'),
          username: Value('@eva_updated'),
          avatarUrl: Value('https://example.com/updated.jpg'),
        ),
      );

      // Verify watchComments reflects updated author profile
      comments = await db.feedDao.watchComments('post-comment-sync-test').first;
      final updatedRoot = comments.firstWhere((c) => c.id == rootComment.id);
      expect(updatedRoot.authorDisplayName, equals('Eva Updated'));
      expect(updatedRoot.authorUsername, equals('@eva_updated'));
      expect(updatedRoot.authorAvatarUrl, equals('https://example.com/updated.jpg'));

      await db.close();
    });
  });
}
