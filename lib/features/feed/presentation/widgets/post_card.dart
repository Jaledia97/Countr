import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../domain/models/feed_post.dart';
import '../providers/feed_providers.dart';
import 'media_post_body.dart';
import 'multi_pull_post_body.dart';
import 'post_action_bar.dart';
import 'post_comments_sheet.dart';
import 'post_header.dart';
import 'single_pull_post_body.dart';
import 'text_post_body.dart';

/// Modular PostCard widget that composes PostHeader, the appropriate
/// post body variant, and PostActionBar with 100% interactivity wired to Drift SQLite.
class PostCard extends StatelessWidget {
  final FeedPost post;
  final VoidCallback? onHypeTap;
  final VoidCallback? onCommentTap;
  final void Function(int index, String cardId)? onCardTap;

  const PostCard({
    super.key,
    required this.post,
    this.onHypeTap,
    this.onCommentTap,
    this.onCardTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.surfaceBorder,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Shared Reusable PostHeader with Avatar/Username Tap
          PostHeader(
            username: post.username,
            avatarInitials: post.avatarInitials,
            avatarUrl: post.avatarUrl,
            timestamp: post.timestamp,
            locationTag: post.locationTag,
            authorId: post.effectiveAuthorId,
            post: post,
          ),

          // 2. Dynamic Modular Post Body Variant with Card Tap -> CardDetailSheet
          _buildPostBody(post),

          // 3. Shared Reusable PostActionBar with Like Persistence and Comment Sheet
          _buildActionBar(context),
        ],
      ),
    );
  }

  Widget _buildActionBar(BuildContext context) {
    bool hasScope = false;
    try {
      ProviderScope.containerOf(context, listen: false);
      hasScope = true;
    } catch (_) {
      hasScope = false;
    }

    if (hasScope) {
      return Consumer(
        builder: (context, ref, _) {
          final currentUserId = ref.watch(currentUserIdProvider);
          final dynamicCommentCount =
              ref.watch(postCommentCountProvider(post.id)).valueOrNull ?? post.commentCount;
          final dynamicNetScore =
              ref.watch(postNetScoreProvider(post.id)).valueOrNull ?? post.hypeCount;
          final dynamicUserVote =
              ref.watch(postUserVoteProvider(post.id)).valueOrNull ?? (post.isHyped ? 1 : 0);
          final dynamicReactions =
              ref.watch(postReactionSummaryProvider(post.id)).valueOrNull ?? const [];
          final mruEmojis = ref.watch(mruReactionsProvider);

          final reactionCounts = <String, int>{};
          final userReactions = <String>{};
          for (final r in dynamicReactions) {
            reactionCounts[r.emoji] = r.count;
            if (r.userReacted) {
              userReactions.add(r.emoji);
            }
          }

          return PostActionBar(
            postId: post.id,
            initialNetScore: dynamicNetScore,
            initialUserVote: dynamicUserVote,
            initialHypeCount: dynamicNetScore,
            commentCount: dynamicCommentCount,
            initialIsHyped: dynamicUserVote == 1,
            initialIsWishlisted: post.isWishlisted,
            initialReactions: reactionCounts,
            userReactions: userReactions,
            mruEmojis: mruEmojis,
            onVoteChanged: (newVote) {
              ref.read(feedDaoProvider).votePost(post.id, currentUserId, newVote);
            },
            onReactionSelected: (emoji) {
              ref.read(feedDaoProvider).togglePostReaction(post.id, currentUserId, emoji);
              ref.read(mruReactionsProvider.notifier).recordEmojiUsage(emoji);
            },
            onHypeTap: onHypeTap ??
                () {
                  ref
                      .read(feedDaoProvider)
                      .togglePostLike(post.id, currentUserId);
                },
            onCommentTap: onCommentTap ??
                () {
                  PostCommentsSheet.show(context, post);
                },
          );
        },
      );
    }

    return PostActionBar(
      postId: post.id,
      initialNetScore: post.hypeCount,
      initialUserVote: post.isHyped ? 1 : 0,
      initialHypeCount: post.hypeCount,
      commentCount: post.commentCount,
      initialIsHyped: post.isHyped,
      initialIsWishlisted: post.isWishlisted,
      onHypeTap: onHypeTap,
      onCommentTap: onCommentTap ??
          () {
            PostCommentsSheet.show(context, post);
          },
    );
  }

  Widget _buildPostBody(FeedPost post) {
    switch (post.type) {
      case PostType.text:
        return TextPostBody(
          text: post.textContent ?? '',
        );

      case PostType.singlePull:
        return SinglePullPostBody(
          commentary: post.textContent,
          cardTitle: post.cardTitle,
          cardSubtitle: post.cardSubtitle,
          cardRarity: post.cardRarity,
          estimatedValue: post.estimatedValue,
          cardId: post.cardId,
          imageUrl: post.cardImageUrl,
          useLightbox: true,
          onCardTap: onCardTap != null ? () => onCardTap!(0, post.cardId ?? '') : null,
        );

      case PostType.multiPull:
        return MultiPullPostBody(
          commentary: post.textContent,
          pullItems: post.pullImages,
          pullCardIds: post.pullCardIds,
          useLightbox: true,
          onCardTap: onCardTap,
        );

      case PostType.media:
        return MediaPostBody(
          imageUrl: post.cardImageUrl ?? '',
          aspectRatioTag: post.cardSubtitle,
          caption: post.textContent,
        );

      case PostType.mixedMedia:
        return MultiPullPostBody(
          commentary: post.textContent,
          pullItems: post.pullImages.isNotEmpty ? post.pullImages : [post.cardImageUrl ?? ''],
          pullCardIds: post.pullCardIds,
          useLightbox: true,
          onCardTap: onCardTap,
        );
    }
  }
}
