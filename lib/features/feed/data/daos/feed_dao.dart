import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/tables/social/feed_posts_table.dart';
import '../../../../core/database/tables/social/post_likes_table.dart';
import '../../../../core/database/tables/social/post_comments_table.dart';
import '../../../../core/database/tables/social/notifications_table.dart';
import '../../../../core/database/tables/social/user_follows_table.dart';
import '../../../../core/database/tables/user_profiles_table.dart';
import '../../../../core/database/tables/social/post_votes_table.dart';
import '../../../../core/database/tables/social/post_reactions_table.dart';
import '../../../../core/database/tables/social/comment_reactions_table.dart';
import '../../../../core/database/tables/social/saved_posts_table.dart';

part 'feed_dao.g.dart';

@DriftAccessor(tables: [
  FeedPosts,
  PostLikes,
  PostComments,
  Notifications,
  UserFollows,
  UserProfiles,
  PostVotes,
  PostReactions,
  CommentReactions,
  SavedPosts,
])
class FeedDao extends DatabaseAccessor<AppDatabase> with _$FeedDaoMixin {
  FeedDao(super.db);

  /// Streams active feed posts ordered chronologically descending, with encounter boost
  /// for posts from followed businesses/users. Joins user_profiles to ensure authorAvatarUrl is populated.
  Stream<List<FeedPostRecord>> watchFeedPosts({
    int limit = 50,
    int offset = 0,
    String? currentUserId,
  }) {
    final joins = <Join>[
      leftOuterJoin(
        attachedDatabase.userProfiles,
        attachedDatabase.userProfiles.id.equalsExp(feedPosts.authorId),
      ),
    ];

    if (currentUserId != null && currentUserId.isNotEmpty) {
      joins.add(
        leftOuterJoin(
          userFollows,
          userFollows.targetUserId.equalsExp(feedPosts.authorId) &
              userFollows.followerId.equals(currentUserId) &
              userFollows.isDeleted.equals(false),
        ),
      );
    }

    final query = select(feedPosts).join(joins);
    query.where(feedPosts.isDeleted.equals(false));

    if (currentUserId != null && currentUserId.isNotEmpty) {
      query.orderBy([
        OrderingTerm(
          expression: userFollows.id.isNotNull(),
          mode: OrderingMode.desc,
        ),
        OrderingTerm.desc(feedPosts.createdAt),
      ]);
    } else {
      query.orderBy([OrderingTerm.desc(feedPosts.createdAt)]);
    }
    query.limit(limit, offset: offset);

    return query.watch().map((rows) {
      return rows.map((r) {
        final post = r.readTable(feedPosts);
        final profile = r.readTableOrNull(attachedDatabase.userProfiles);
        if (profile != null && profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty) {
          return post.copyWith(authorAvatarUrl: Value(profile.avatarUrl));
        }
        return post;
      }).toList();
    });
  }

  /// Streams posts authored or shared by a specific user (User Wall). Joins user_profiles.
  Stream<List<FeedPostRecord>> watchUserWallPosts(String userId, {int limit = 50}) {
    final query = select(feedPosts).join([
      leftOuterJoin(
        attachedDatabase.userProfiles,
        attachedDatabase.userProfiles.id.equalsExp(feedPosts.authorId),
      ),
    ]);
    query.where((feedPosts.authorId.equals(userId) | feedPosts.sharedByUserId.equals(userId)) &
        feedPosts.isDeleted.equals(false));
    query.orderBy([OrderingTerm.desc(feedPosts.createdAt)]);
    query.limit(limit);

    return query.watch().map((rows) {
      return rows.map((r) {
        final post = r.readTable(feedPosts);
        final profile = r.readTableOrNull(attachedDatabase.userProfiles);
        if (profile != null && profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty) {
          return post.copyWith(authorAvatarUrl: Value(profile.avatarUrl));
        }
        return post;
      }).toList();
    });
  }

  /// Fetches a single post by ID.
  Future<FeedPostRecord?> getPostById(String postId) {
    return (select(feedPosts)..where((t) => t.id.equals(postId))).getSingleOrNull();
  }

  /// Streams whether a user has liked a specific post.
  Stream<bool> watchIsPostLiked(String postId, String userId) {
    return (select(postLikes)
          ..where((t) =>
              t.postId.equals(postId) &
              t.userId.equals(userId) &
              t.isDeleted.equals(false)))
        .watchSingleOrNull()
        .map((like) => like?.isLiked ?? false);
  }

  /// Atomically toggles like status for a post.
  /// Updates or inserts into [PostLikes] and adjusts [FeedPosts.likeCount].
  /// Returns the new liked state.
  Future<bool> togglePostLike(String postId, String userId) {
    return transaction(() async {
      final existing = await (select(postLikes)
            ..where((t) => t.postId.equals(postId) & t.userId.equals(userId)))
          .getSingleOrNull();

      final now = DateTime.now();
      bool newLikedState;

      if (existing == null) {
        newLikedState = true;
        await into(postLikes).insert(
          PostLikesCompanion.insert(
            id: 'like_${postId}_$userId',
            postId: postId,
            userId: userId,
            isLiked: const Value(true),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
      } else {
        newLikedState = !existing.isLiked;
        await (update(postLikes)..where((t) => t.id.equals(existing.id))).write(
          PostLikesCompanion(
            isLiked: Value(newLikedState),
            updatedAt: Value(now),
          ),
        );
      }

      final post = await (select(feedPosts)..where((t) => t.id.equals(postId)))
          .getSingleOrNull();

      if (post != null) {
        final currentCount = post.likeCount;
        final newCount = newLikedState
            ? currentCount + 1
            : (currentCount > 0 ? currentCount - 1 : 0);

        await (update(feedPosts)..where((t) => t.id.equals(postId))).write(
          FeedPostsCompanion(
            likeCount: Value(newCount),
            updatedAt: Value(now),
          ),
        );

        // If newly liked and not own post, create a notification
        if (newLikedState && post.authorId != userId) {
          await into(notifications).insert(
            NotificationsCompanion.insert(
              id: 'notif_like_${postId}_$userId',
              userId: post.authorId,
              actorId: userId,
              actorUsername: '@collector_me',
              type: 'post_like',
              title: 'New Like',
              body: 'hyped your post',
              targetEntityId: Value(postId),
              targetEntityType: const Value('post'),
              createdAt: Value(now),
            ),
            mode: InsertMode.insertOrReplace,
          );
        }
      }

      return newLikedState;
    });
  }

  /// Streams comments for a post in ascending chronological order.
  /// Performs a reactive LEFT JOIN on [UserProfiles] to populate live author display name,
  /// username, and avatar URL from the profile (falling back to cached comment fields).
  Stream<List<PostCommentRecord>> watchComments(String postId) {
    final query = select(postComments).join([
      leftOuterJoin(
        attachedDatabase.userProfiles,
        attachedDatabase.userProfiles.id.equalsExp(postComments.authorId),
      ),
    ]);
    query.where(
      postComments.postId.equals(postId) &
      postComments.isDeleted.equals(false) &
      postComments.deletedAt.isNull(),
    );
    query.orderBy([OrderingTerm.asc(postComments.createdAt)]);

    return query.watch().map((rows) {
      return rows.map((r) {
        final comment = r.readTable(postComments);
        final profile = r.readTableOrNull(attachedDatabase.userProfiles);
        if (profile != null) {
          final resolvedDisplayName = profile.displayName.isNotEmpty
              ? profile.displayName
              : comment.authorDisplayName;
          final resolvedUsername = profile.username.isNotEmpty
              ? profile.username
              : comment.authorUsername;
          final resolvedAvatarUrl = (profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty)
              ? profile.avatarUrl
              : comment.authorAvatarUrl;

          return comment.copyWith(
            authorDisplayName: resolvedDisplayName,
            authorUsername: resolvedUsername,
            authorAvatarUrl: Value(resolvedAvatarUrl),
          );
        }
        return comment;
      }).toList();
    });
  }

  /// Streams the true active comment count for a post across all nesting depths.
  /// Matches requirement: SELECT COUNT(*) FROM post_comments WHERE post_id = ? AND deleted_at IS NULL AND is_deleted = 0
  Stream<int> watchCommentCount(String postId) {
    final countCol = postComments.id.count();
    final query = selectOnly(postComments)
      ..addColumns([countCol])
      ..where(
        postComments.postId.equals(postId) &
        postComments.isDeleted.equals(false) &
        postComments.deletedAt.isNull(),
      );

    return query.map((row) => row.read(countCol) ?? 0).watchSingle();
  }

  /// Returns the true active comment count for a post across all nesting depths.
  Future<int> getCommentCount(String postId) {
    final countCol = postComments.id.count();
    final query = selectOnly(postComments)
      ..addColumns([countCol])
      ..where(
        postComments.postId.equals(postId) &
        postComments.isDeleted.equals(false) &
        postComments.deletedAt.isNull(),
      );

    return query.map((row) => row.read(countCol) ?? 0).getSingle();
  }

  /// Inserts a new comment into [PostComments], increments [FeedPosts.commentCount] with
  /// true total count across all depths, and notifies the post author if commenter is someone else.
  Future<PostCommentRecord> addComment({
    required String postId,
    required String authorId,
    required String authorUsername,
    required String authorDisplayName,
    String? authorAvatarUrl,
    required String content,
    String? parentCommentId,
  }) {
    return transaction(() async {
      final now = DateTime.now();
      final commentId = 'comment_${DateTime.now().millisecondsSinceEpoch}_$authorId';

      final companion = PostCommentsCompanion(
        id: Value(commentId),
        postId: Value(postId),
        authorId: Value(authorId),
        authorUsername: Value(authorUsername),
        authorDisplayName: Value(authorDisplayName),
        authorAvatarUrl: Value(authorAvatarUrl),
        content: Value(content),
        parentCommentId: Value(parentCommentId),
        createdAt: Value(now),
        updatedAt: Value(now),
        isDeleted: const Value(false),
        syncStatus: const Value('synced'),
      );

      await into(postComments).insert(companion);

      final post = await (select(feedPosts)..where((t) => t.id.equals(postId)))
          .getSingleOrNull();

      if (post != null) {
        final trueCount = await getCommentCount(postId);

        await (update(feedPosts)..where((t) => t.id.equals(postId))).write(
          FeedPostsCompanion(
            commentCount: Value(trueCount),
            updatedAt: Value(now),
          ),
        );

        if (post.authorId != authorId) {
          await into(notifications).insert(
            NotificationsCompanion.insert(
              id: 'notif_comment_$commentId',
              userId: post.authorId,
              actorId: authorId,
              actorUsername: authorUsername,
              actorDisplayName: Value(authorDisplayName),
              actorAvatarUrl: Value(authorAvatarUrl),
              type: 'post_comment',
              title: 'New Comment',
              body: 'commented: "$content"',
              targetEntityId: Value(postId),
              targetEntityType: const Value('post'),
              createdAt: Value(now),
            ),
            mode: InsertMode.insertOrReplace,
          );
        }
      }

      return (select(postComments)..where((t) => t.id.equals(commentId)))
          .getSingle();
    });
  }

  /// Inserts a newly published social post.
  Future<void> createPost(FeedPostsCompanion post) async {
    await into(feedPosts).insert(post, mode: InsertMode.insertOrReplace);
  }

  /// Soft deletes a post.
  Future<void> deletePost(String postId) async {
    final now = DateTime.now();
    await (update(feedPosts)..where((t) => t.id.equals(postId))).write(
      FeedPostsCompanion(
        isDeleted: const Value(true),
        deletedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  /// Cascades an author's updated avatar URL to all posts authored by them.
  Future<void> updateAuthorAvatar(String authorId, String avatarUrl) async {
    final now = DateTime.now();
    await (update(feedPosts)..where((t) => t.authorId.equals(authorId))).write(
      FeedPostsCompanion(
        authorAvatarUrl: Value(avatarUrl),
        updatedAt: Value(now),
      ),
    );
  }

  /// Searches feed posts by text content, card title, or location tag.
  Future<List<FeedPostRecord>> searchPosts(String query, {int limit = 20}) {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return Future.value([]);

    return (select(feedPosts)
          ..where((t) =>
              t.isDeleted.equals(false) &
              (t.textContent.like('%$cleanQuery%') |
                  t.cardTitle.like('%$cleanQuery%') |
                  t.locationTag.like('%$cleanQuery%')))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(limit))
        .get();
  }

  /// Atomically toggles following a user or business.
  /// Returns true if now following, false if unfollowed.
  Future<bool> toggleFollow(String followerId, String targetUserId) {
    return transaction(() async {
      final existing = await (select(userFollows)
            ..where((t) =>
                t.followerId.equals(followerId) &
                t.targetUserId.equals(targetUserId)))
          .getSingleOrNull();

      final now = DateTime.now();
      if (existing == null) {
        await into(userFollows).insert(
          UserFollowsCompanion.insert(
            id: 'follow_${followerId}_$targetUserId',
            followerId: followerId,
            targetUserId: targetUserId,
            createdAt: Value(now),
            isDeleted: const Value(false),
          ),
        );
        return true;
      } else {
        final newDeletedState = !existing.isDeleted;
        await (update(userFollows)..where((t) => t.id.equals(existing.id))).write(
          UserFollowsCompanion(
            isDeleted: Value(newDeletedState),
            deletedAt: Value(newDeletedState ? now : null),
          ),
        );
        return !newDeletedState;
      }
    });
  }

  /// Streams whether [followerId] follows [targetUserId].
  Stream<bool> watchIsFollowing(String followerId, String targetUserId) {
    return (select(userFollows)
          ..where((t) =>
              t.followerId.equals(followerId) &
              t.targetUserId.equals(targetUserId) &
              t.isDeleted.equals(false)))
        .watchSingleOrNull()
        .map((follow) => follow != null);
  }

  /// Streams follower count for [targetUserId].
  Stream<int> watchFollowersCount(String targetUserId) {
    final countCol = userFollows.id.count();
    final query = selectOnly(userFollows)
      ..addColumns([countCol])
      ..where(userFollows.targetUserId.equals(targetUserId) &
          userFollows.isDeleted.equals(false));

    return query.map((row) => row.read(countCol) ?? 0).watchSingle();
  }

  /// Gets follower count for [targetUserId].
  Future<int> getFollowersCount(String targetUserId) {
    final countCol = userFollows.id.count();
    final query = selectOnly(userFollows)
      ..addColumns([countCol])
      ..where(userFollows.targetUserId.equals(targetUserId) &
          userFollows.isDeleted.equals(false));

    return query.map((row) => row.read(countCol) ?? 0).getSingle();
  }

  // ---------------------------------------------------------------------------
  // 2. REDDIT VOTING & NET SCORE (post_votes)
  // ---------------------------------------------------------------------------

  /// Upserts user vote (+1, -1, 0) into [PostVotes], recalculates net score,
  /// updates [FeedPosts.likeCount] with net score, and returns the new net score.
  Future<int> votePost(String postId, String userId, int vote) {
    return transaction(() async {
      final now = DateTime.now();
      final voteId = 'vote_${postId}_$userId';

      // 1. Upsert into post_votes
      await into(attachedDatabase.postVotes).insert(
        PostVotesCompanion(
          id: Value(voteId),
          postId: Value(postId),
          userId: Value(userId),
          vote: Value(vote),
          createdAt: Value(now),
          updatedAt: Value(now),
          isDeleted: const Value(false),
          syncStatus: const Value('pending_update'),
        ),
        mode: InsertMode.insertOrReplace,
      );

      // 2. Calculate net score: SUM(vote) WHERE post_id = ? AND is_deleted = 0
      final sumCol = attachedDatabase.postVotes.vote.sum();
      final sumQuery = selectOnly(attachedDatabase.postVotes)
        ..addColumns([sumCol])
        ..where(
          attachedDatabase.postVotes.postId.equals(postId) &
          attachedDatabase.postVotes.isDeleted.equals(false),
        );
      final sumRow = await sumQuery.getSingle();
      final netScore = sumRow.read(sumCol) ?? 0;

      // 3. Update FeedPosts.likeCount with net score
      await (update(feedPosts)..where((t) => t.id.equals(postId))).write(
        FeedPostsCompanion(
          likeCount: Value(netScore),
          updatedAt: Value(now),
        ),
      );

      // 4. If upvoted (+1) and not own post, create/update notification
      final post = await (select(feedPosts)..where((t) => t.id.equals(postId))).getSingleOrNull();
      if (post != null && vote == 1 && post.authorId != userId) {
        await into(notifications).insert(
          NotificationsCompanion.insert(
            id: 'notif_vote_${postId}_$userId',
            userId: post.authorId,
            actorId: userId,
            actorUsername: '@collector_me',
            type: 'post_vote',
            title: 'New Upvote',
            body: 'upvoted your post',
            targetEntityId: Value(postId),
            targetEntityType: const Value('post'),
            createdAt: Value(now),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }

      return netScore;
    });
  }

  /// Streams the current user's vote (+1, -1, 0) on a post.
  Stream<int> watchUserPostVote(String postId, String userId) {
    return (select(attachedDatabase.postVotes)
          ..where((t) =>
              t.postId.equals(postId) &
              t.userId.equals(userId) &
              t.isDeleted.equals(false)))
        .watchSingleOrNull()
        .map((v) => v?.vote ?? 0);
  }

  /// Gets the current user's vote (+1, -1, 0) on a post.
  Future<int> getUserPostVote(String postId, String userId) async {
    final v = await (select(attachedDatabase.postVotes)
          ..where((t) =>
              t.postId.equals(postId) &
              t.userId.equals(userId) &
              t.isDeleted.equals(false)))
        .getSingleOrNull();
    return v?.vote ?? 0;
  }

  /// Streams the aggregate net score (sum of all votes) for a post.
  Stream<int> watchPostNetScore(String postId) {
    final sumCol = attachedDatabase.postVotes.vote.sum();
    final query = selectOnly(attachedDatabase.postVotes)
      ..addColumns([sumCol])
      ..where(
        attachedDatabase.postVotes.postId.equals(postId) &
        attachedDatabase.postVotes.isDeleted.equals(false),
      );

    return query.map((row) => row.read(sumCol) ?? 0).watchSingle();
  }

  // ---------------------------------------------------------------------------
  // 3. EMOJI REACTIONS (Post & Comment Reactions)
  // ---------------------------------------------------------------------------

  /// Adds or updates an emoji reaction on a post.
  Future<void> reactToPost(String postId, String userId, String emoji) async {
    final now = DateTime.now();
    final id = 'post_react_${postId}_${userId}_$emoji';
    await into(attachedDatabase.postReactions).insert(
      PostReactionsCompanion(
        id: Value(id),
        postId: Value(postId),
        userId: Value(userId),
        emoji: Value(emoji),
        createdAt: Value(now),
        isDeleted: const Value(false),
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  /// Removes an emoji reaction on a post.
  Future<void> removePostReaction(String postId, String userId, String emoji) async {
    await (update(attachedDatabase.postReactions)
          ..where((t) =>
              t.postId.equals(postId) &
              t.userId.equals(userId) &
              t.emoji.equals(emoji)))
        .write(
      const PostReactionsCompanion(
        isDeleted: Value(true),
      ),
    );
  }

  /// Toggles an emoji reaction on a post. Returns true if added, false if removed.
  Future<bool> togglePostReaction(String postId, String userId, String emoji) async {
    final existing = await (select(attachedDatabase.postReactions)
          ..where((t) =>
              t.postId.equals(postId) &
              t.userId.equals(userId) &
              t.emoji.equals(emoji) &
              t.isDeleted.equals(false)))
        .getSingleOrNull();

    if (existing == null) {
      await reactToPost(postId, userId, emoji);
      return true;
    } else {
      await removePostReaction(postId, userId, emoji);
      return false;
    }
  }

  /// Streams all active reactions for a post ordered chronologically.
  Stream<List<PostReactionRecord>> watchPostReactions(String postId) {
    return (select(attachedDatabase.postReactions)
          ..where((t) => t.postId.equals(postId) & t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();
  }

  /// Adds or updates an emoji reaction on an individual comment.
  Future<void> reactToComment(String commentId, String userId, String emoji) async {
    final now = DateTime.now();
    final id = 'comment_react_${commentId}_${userId}_$emoji';
    await into(attachedDatabase.commentReactions).insert(
      CommentReactionsCompanion(
        id: Value(id),
        commentId: Value(commentId),
        userId: Value(userId),
        emoji: Value(emoji),
        createdAt: Value(now),
        isDeleted: const Value(false),
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  /// Removes an emoji reaction on an individual comment.
  Future<void> removeCommentReaction(String commentId, String userId, String emoji) async {
    await (update(attachedDatabase.commentReactions)
          ..where((t) =>
              t.commentId.equals(commentId) &
              t.userId.equals(userId) &
              t.emoji.equals(emoji)))
        .write(
      const CommentReactionsCompanion(
        isDeleted: Value(true),
      ),
    );
  }

  /// Toggles an emoji reaction on a comment. Returns true if added, false if removed.
  Future<bool> toggleCommentReaction(String commentId, String userId, String emoji) async {
    final existing = await (select(attachedDatabase.commentReactions)
          ..where((t) =>
              t.commentId.equals(commentId) &
              t.userId.equals(userId) &
              t.emoji.equals(emoji) &
              t.isDeleted.equals(false)))
        .getSingleOrNull();

    if (existing == null) {
      await reactToComment(commentId, userId, emoji);
      return true;
    } else {
      await removeCommentReaction(commentId, userId, emoji);
      return false;
    }
  }

  /// Streams all active reactions for a comment ordered chronologically.
  Stream<List<CommentReactionRecord>> watchCommentReactions(String commentId) {
    return (select(attachedDatabase.commentReactions)
          ..where((t) => t.commentId.equals(commentId) & t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();
  }

  // ---------------------------------------------------------------------------
  // 4. SAVED POSTS (saved_posts)
  // ---------------------------------------------------------------------------

  /// Saves a post for the user (bookmark).
  Future<void> savePost(String postId, String userId) async {
    final now = DateTime.now();
    final id = 'saved_${postId}_$userId';
    await into(attachedDatabase.savedPosts).insert(
      SavedPostsCompanion(
        id: Value(id),
        postId: Value(postId),
        userId: Value(userId),
        createdAt: Value(now),
        isDeleted: const Value(false),
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  /// Unsaves a post for the user.
  Future<void> unsavePost(String postId, String userId) async {
    await (update(attachedDatabase.savedPosts)
          ..where((t) =>
              t.postId.equals(postId) &
              t.userId.equals(userId)))
        .write(
      const SavedPostsCompanion(
        isDeleted: Value(true),
      ),
    );
  }

  /// Toggles save status for a post. Returns true if saved, false if unsaved.
  Future<bool> toggleSavePost(String postId, String userId) async {
    final existing = await (select(attachedDatabase.savedPosts)
          ..where((t) =>
              t.postId.equals(postId) &
              t.userId.equals(userId) &
              t.isDeleted.equals(false)))
        .getSingleOrNull();

    if (existing == null) {
      await savePost(postId, userId);
      return true;
    } else {
      await unsavePost(postId, userId);
      return false;
    }
  }

  /// Streams whether a post is saved by the user.
  Stream<bool> watchIsPostSaved(String postId, String userId) {
    return (select(attachedDatabase.savedPosts)
          ..where((t) =>
              t.postId.equals(postId) &
              t.userId.equals(userId) &
              t.isDeleted.equals(false)))
        .watchSingleOrNull()
        .map((saved) => saved != null);
  }

  /// Gets whether a post is saved by the user.
  Future<bool> isPostSaved(String postId, String userId) async {
    final saved = await (select(attachedDatabase.savedPosts)
          ..where((t) =>
              t.postId.equals(postId) &
              t.userId.equals(userId) &
              t.isDeleted.equals(false)))
        .getSingleOrNull();
    return saved != null;
  }

  /// Streams total count of saved posts for a user (for Command Center badge).
  Stream<int> watchSavedPostsCount(String userId) {
    final countCol = attachedDatabase.savedPosts.id.count();
    final query = selectOnly(attachedDatabase.savedPosts)
      ..addColumns([countCol])
      ..where(
        attachedDatabase.savedPosts.userId.equals(userId) &
        attachedDatabase.savedPosts.isDeleted.equals(false),
      );

    return query.map((row) => row.read(countCol) ?? 0).watchSingle();
  }

  /// Streams saved posts for a user with joined author profile metadata.
  Stream<List<FeedPostRecord>> watchSavedPosts(
    String userId, {
    int limit = 50,
    int offset = 0,
  }) {
    final query = select(feedPosts).join([
      innerJoin(
        attachedDatabase.savedPosts,
        attachedDatabase.savedPosts.postId.equalsExp(feedPosts.id) &
        attachedDatabase.savedPosts.userId.equals(userId) &
        attachedDatabase.savedPosts.isDeleted.equals(false),
      ),
      leftOuterJoin(
        attachedDatabase.userProfiles,
        attachedDatabase.userProfiles.id.equalsExp(feedPosts.authorId),
      ),
    ]);

    query.where(feedPosts.isDeleted.equals(false));
    query.orderBy([OrderingTerm.desc(attachedDatabase.savedPosts.createdAt)]);
    query.limit(limit, offset: offset);

    return query.watch().map((rows) {
      return rows.map((r) {
        final post = r.readTable(feedPosts);
        final profile = r.readTableOrNull(attachedDatabase.userProfiles);
        if (profile != null) {
          final resolvedAvatar = (profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty)
              ? profile.avatarUrl
              : post.authorAvatarUrl;
          final resolvedDisplayName = profile.displayName.isNotEmpty
              ? profile.displayName
              : post.authorDisplayName;
          final resolvedUsername = profile.username.isNotEmpty
              ? profile.username
              : post.authorUsername;
          return post.copyWith(
            authorAvatarUrl: Value(resolvedAvatar),
            authorDisplayName: resolvedDisplayName,
            authorUsername: resolvedUsername,
          );
        }
        return post;
      }).toList();
    });
  }
}
