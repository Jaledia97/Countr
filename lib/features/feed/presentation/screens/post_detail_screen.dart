import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../domain/models/feed_post.dart';
import '../providers/feed_providers.dart';
import '../widgets/post_card.dart';
import '../widgets/post_comments_sheet.dart';

/// Standalone screen displaying a single post and optional automatic comments sheet.
class PostDetailScreen extends ConsumerStatefulWidget {
  final String postId;
  final bool openComments;

  const PostDetailScreen({
    super.key,
    required this.postId,
    this.openComments = false,
  });

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  bool _commentsOpened = false;

  @override
  Widget build(BuildContext context) {
    final postAsync = ref.watch(feedPostByIdProvider(widget.postId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text(
          'Post',
          style: AppTypography.heading1.copyWith(color: AppColors.textPrimary),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: postAsync.when(
        data: (record) {
          if (record == null) {
            return const Center(
              child: Text(
                'Post not found',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            );
          }
          final feedPost = FeedPost.fromRecord(record);

          if (widget.openComments && !_commentsOpened) {
            _commentsOpened = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                PostCommentsSheet.show(context, feedPost);
              }
            });
          }

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              PostCard(post: feedPost),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accentCyan),
        ),
        error: (err, _) => Center(
          child: Text(
            'Error loading post: $err',
            style: const TextStyle(color: Colors.redAccent),
          ),
        ),
      ),
    );
  }
}
