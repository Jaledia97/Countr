import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../providers/feed_providers.dart';
import '../widgets/post_card.dart';

/// Dedicated screen displaying all saved/bookmarked feed posts per Milestone 3 (Feature 13).
class SavedPostsScreen extends ConsumerWidget {
  const SavedPostsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedPostsAsync = ref.watch(savedPostsStreamProvider);

    return Scaffold(
      key: const Key('saved_posts_screen'),
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Saved Posts',
          key: Key('saved_posts_title'),
          style: AppTypography.heading2,
        ),
      ),
      body: savedPostsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accentCyan),
        ),
        error: (error, stack) => Center(
          child: Text(
            'Error loading saved posts: $error',
            style: const TextStyle(color: AppColors.accentRose),
          ),
        ),
        data: (posts) {
          if (posts.isEmpty) {
            return Center(
              key: const Key('saved_posts_empty_view'),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.bookmark_border_rounded,
                      size: 64,
                      color: AppColors.textSecondary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No Saved Posts Yet',
                      style: AppTypography.heading2,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Bookmark posts from the feed using the \'⋮\' menu to easily revisit them here.',
                      style: AppTypography.caption.copyWith(fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            key: const Key('saved_posts_list'),
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              return PostCard(
                key: Key('saved_post_${post.id}'),
                post: post,
              );
            },
          );
        },
      ),
    );
  }
}
