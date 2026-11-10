import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../vault/presentation/providers/vault_providers.dart';
import '../../data/daos/feed_dao.dart';
import '../../domain/models/feed_post.dart';
import '../../domain/models/home_search_results.dart';
import '../../domain/models/post_comment.dart';

/// Provider exposing [FeedDao].
final feedDaoProvider = Provider<FeedDao>((ref) {
  return ref.watch(appDatabaseProvider).feedDao;
});

/// Streams active feed posts mapped to [FeedPost] domain models.
final feedPostsStreamProvider = StreamProvider<List<FeedPost>>((ref) {
  final dao = ref.watch(feedDaoProvider);
  final currentUserId = ref.watch(currentUserIdProvider);

  return dao.watchFeedPosts(currentUserId: currentUserId).asyncMap((records) async {
    final posts = <FeedPost>[];
    for (final r in records) {
      final isLiked = await (dao.select(dao.postLikes)
            ..where((t) =>
                t.postId.equals(r.id) &
                t.userId.equals(currentUserId) &
                t.isDeleted.equals(false)))
          .getSingleOrNull();

      posts.add(FeedPost.fromRecord(r, isHyped: isLiked?.isLiked ?? false));
    }
    return posts;
  });
});

/// Streams posts on a specific user's wall.
final userWallPostsStreamProvider =
    StreamProvider.family<List<FeedPost>, String>((ref, userId) {
  final dao = ref.watch(feedDaoProvider);
  final currentUserId = ref.watch(currentUserIdProvider);
  final targetUserId = userId == 'me' ? currentUserId : userId;

  return dao.watchUserWallPosts(targetUserId).asyncMap((records) async {
    final posts = <FeedPost>[];
    for (final r in records) {
      final isLiked = await (dao.select(dao.postLikes)
            ..where((t) =>
                t.postId.equals(r.id) &
                t.userId.equals(currentUserId) &
                t.isDeleted.equals(false)))
          .getSingleOrNull();

      posts.add(FeedPost.fromRecord(r, isHyped: isLiked?.isLiked ?? false));
    }
    return posts;
  });
});

/// Streams whether a post is liked by the current user.
final postIsLikedProvider =
    StreamProvider.family<bool, String>((ref, postId) {
  final dao = ref.watch(feedDaoProvider);
  final currentUserId = ref.watch(currentUserIdProvider);
  return dao.watchIsPostLiked(postId, currentUserId);
});

/// Streams comments for a post in chronological order.
final postCommentsStreamProvider =
    StreamProvider.family<List<PostComment>, String>((ref, postId) {
  final dao = ref.watch(feedDaoProvider);
  return dao
      .watchComments(postId)
      .map((list) => list.map(PostComment.fromRecord).toList());
});

/// Streams reactive comment count for a post.
final postCommentCountProvider =
    StreamProvider.family<int, String>((ref, postId) {
  final dao = ref.watch(feedDaoProvider);
  return dao.watchCommentCount(postId);
});

/// StateProvider holding the Home Search bar input query.
final homeSearchQueryProvider = StateProvider<String>((ref) => '');

/// Categorized search results for Home Search Discovery.
final homeSearchResultsProvider =
    FutureProvider<HomeSearchResults>((ref) async {
  final query = ref.watch(homeSearchQueryProvider).trim();
  if (query.isEmpty) {
    return const HomeSearchResults(
      people: [],
      stores: [],
      posts: [],
      query: '',
    );
  }

  final db = ref.watch(appDatabaseProvider);
  final currentUserId = ref.watch(currentUserIdProvider);

  // 1. Search profiles via userProfileDao
  final allProfiles = await db.userProfileDao.searchProfiles(query, limit: 30);
  final people = <UserProfile>[];
  final stores = <UserProfile>[];

  for (final p in allProfiles) {
    if (p.isVerifiedBusiness || p.accountType == 'business') {
      stores.add(p);
    } else {
      people.add(p);
    }
  }

  // 2. Search posts via feedDao
  final postRecords = await db.feedDao.searchPosts(query, limit: 20);
  final posts = <FeedPost>[];
  for (final r in postRecords) {
    final isLiked = await (db.feedDao.select(db.feedDao.postLikes)
          ..where((t) =>
              t.postId.equals(r.id) &
              t.userId.equals(currentUserId) &
              t.isDeleted.equals(false)))
        .getSingleOrNull();

    posts.add(FeedPost.fromRecord(r, isHyped: isLiked?.isLiked ?? false));
  }

  return HomeSearchResults(
    people: people,
    stores: stores,
    posts: posts,
    query: query,
  );
});

/// Fetches a single post record by ID.
final feedPostByIdProvider =
    FutureProvider.family<FeedPostRecord?, String>((ref, postId) {
  final dao = ref.watch(feedDaoProvider);
  return dao.getPostById(postId);
});

/// Clean domain value object for grouped emoji reactions on posts and comments.
class ReactionSummary {
  final String emoji;
  final int count;
  final bool userReacted;

  const ReactionSummary({
    required this.emoji,
    required this.count,
    this.userReacted = false,
  });
}

/// Streams reactive net score for a post from [post_votes].
final postNetScoreProvider =
    StreamProvider.family<int, String>((ref, postId) {
  final dao = ref.watch(feedDaoProvider);
  return dao.watchPostNetScore(postId);
});

/// Streams current user's vote (+1, -1, 0) on a post.
final postUserVoteProvider =
    StreamProvider.family<int, String>((ref, postId) {
  final dao = ref.watch(feedDaoProvider);
  final currentUserId = ref.watch(currentUserIdProvider);
  return dao.watchUserPostVote(postId, currentUserId);
});

/// Streams grouped emoji reaction summary for a post.
final postReactionSummaryProvider =
    StreamProvider.family<List<ReactionSummary>, String>((ref, postId) {
  final dao = ref.watch(feedDaoProvider);
  final currentUserId = ref.watch(currentUserIdProvider);

  return dao.watchPostReactions(postId).map((records) {
    final counts = <String, int>{};
    final userReactedMap = <String, bool>{};

    for (final r in records) {
      counts[r.emoji] = (counts[r.emoji] ?? 0) + 1;
      if (r.userId == currentUserId) {
        userReactedMap[r.emoji] = true;
      }
    }

    return counts.entries.map((e) {
      return ReactionSummary(
        emoji: e.key,
        count: e.value,
        userReacted: userReactedMap[e.key] ?? false,
      );
    }).toList();
  });
});

/// Streams grouped emoji reaction summary for an individual comment.
final commentReactionSummaryProvider =
    StreamProvider.family<List<ReactionSummary>, String>((ref, commentId) {
  final dao = ref.watch(feedDaoProvider);
  final currentUserId = ref.watch(currentUserIdProvider);

  return dao.watchCommentReactions(commentId).map((records) {
    final counts = <String, int>{};
    final userReactedMap = <String, bool>{};

    for (final r in records) {
      counts[r.emoji] = (counts[r.emoji] ?? 0) + 1;
      if (r.userId == currentUserId) {
        userReactedMap[r.emoji] = true;
      }
    }

    return counts.entries.map((e) {
      return ReactionSummary(
        emoji: e.key,
        count: e.value,
        userReacted: userReactedMap[e.key] ?? false,
      );
    }).toList();
  });
});

/// Streams whether a post is saved by the current user.
final postIsSavedProvider =
    StreamProvider.family<bool, String>((ref, postId) {
  final dao = ref.watch(feedDaoProvider);
  final currentUserId = ref.watch(currentUserIdProvider);
  return dao.watchIsPostSaved(postId, currentUserId);
});

/// Streams the total count of saved posts for current user (for Command Center badge).
final savedPostsCountProvider = StreamProvider<int>((ref) {
  final dao = ref.watch(feedDaoProvider);
  final currentUserId = ref.watch(currentUserIdProvider);
  return dao.watchSavedPostsCount(currentUserId);
});

/// Streams saved posts for the current user mapped to [FeedPost] domain models.
final savedPostsStreamProvider = StreamProvider<List<FeedPost>>((ref) {
  final dao = ref.watch(feedDaoProvider);
  final currentUserId = ref.watch(currentUserIdProvider);

  return dao.watchSavedPosts(currentUserId).asyncMap((records) async {
    final posts = <FeedPost>[];
    for (final r in records) {
      final userVote = await dao.getUserPostVote(r.id, currentUserId);
      final isSaved = await dao.isPostSaved(r.id, currentUserId);

      posts.add(
        FeedPost.fromRecord(
          r,
          isHyped: userVote > 0,
        ).copyWith(
          isWishlisted: isSaved,
        ),
      );
    }
    return posts;
  });
});

/// Default 5 Most Recently Used reaction emojis per R2/R3.
const kDefaultReactionEmojis = ['🔥', '❤️', '😂', '🤯', '💎'];

/// StateNotifier for Most Recently Used emojis.
class MruReactionsNotifier extends StateNotifier<List<String>> {
  MruReactionsNotifier() : super(kDefaultReactionEmojis);

  void recordEmojiUsage(String emoji) {
    final updated = [emoji, ...state.where((e) => e != emoji)];
    state = updated.take(5).toList();
  }
}

final mruReactionsProvider =
    StateNotifierProvider<MruReactionsNotifier, List<String>>((ref) {
  return MruReactionsNotifier();
});

final mruReactionEmojisProvider = mruReactionsProvider;
