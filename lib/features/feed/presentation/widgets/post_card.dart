import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/models/feed_post.dart';
import 'multi_pull_post_body.dart';
import 'post_action_bar.dart';
import 'post_header.dart';
import 'single_pull_post_body.dart';
import 'text_post_body.dart';

/// Modular PostCard widget that composes PostHeader, the appropriate
/// post body variant, and PostActionBar without duplicating code.
class PostCard extends StatelessWidget {
  final FeedPost post;

  const PostCard({super.key, required this.post});

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
          // 1. Shared Reusable PostHeader
          PostHeader(
            username: post.username,
            avatarInitials: post.avatarInitials,
            timestamp: post.timestamp,
            locationTag: post.locationTag,
          ),

          // 2. Dynamic Modular Post Body Variant
          _buildPostBody(post),

          // 3. Shared Reusable PostActionBar
          PostActionBar(
            initialHypeCount: post.hypeCount,
            commentCount: post.commentCount,
            initialIsHyped: post.isHyped,
            initialIsWishlisted: post.isWishlisted,
          ),
        ],
      ),
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
        );

      case PostType.multiPull:
        return MultiPullPostBody(
          commentary: post.textContent,
          pullItems: post.pullImages,
        );
    }
  }
}
