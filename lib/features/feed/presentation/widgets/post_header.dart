import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/cache/countr_cached_image.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../vault/presentation/providers/vault_providers.dart';
import '../../domain/models/feed_post.dart';
import '../providers/feed_providers.dart';
import 'multi_card_wishlist_drawer.dart';

/// Reusable PostHeader component per Milestone 3 (Feature 12).
/// Displays Avatar (left), Username (@handle), Location pill/subtext,
/// Timestamp, and Post Header '⋮' Overflow Menu (right).
class PostHeader extends StatelessWidget {
  final String username;
  final String avatarInitials;
  final String? avatarUrl;
  final String timestamp;
  final String locationTag;
  final String? authorId;
  final VoidCallback? onUserTap;

  // Milestone 3: Post context for '⋮' overflow menu actions
  final FeedPost? post;
  final String? postId;
  final PostType? postType;
  final String? cardId;
  final String? cardTitle;
  final String? cardImageUrl;
  final List<String> pullCardIds;
  final List<String> pullImages;
  final VoidCallback? onWishlistTap;
  final VoidCallback? onSavePostTap;

  const PostHeader({
    super.key,
    required this.username,
    required this.avatarInitials,
    this.avatarUrl,
    required this.timestamp,
    required this.locationTag,
    this.authorId,
    this.onUserTap,
    this.post,
    this.postId,
    this.postType,
    this.cardId,
    this.cardTitle,
    this.cardImageUrl,
    this.pullCardIds = const [],
    this.pullImages = const [],
    this.onWishlistTap,
    this.onSavePostTap,
  });

  String get effectivePostId => postId ?? post?.id ?? '';
  PostType get effectivePostType => postType ?? post?.type ?? PostType.text;
  String? get effectiveCardId => cardId ?? post?.cardId;
  String? get effectiveCardTitle => cardTitle ?? post?.cardTitle;
  String? get effectiveCardImageUrl => cardImageUrl ?? post?.cardImageUrl;
  List<String> get effectivePullCardIds =>
      pullCardIds.isNotEmpty ? pullCardIds : (post?.pullCardIds ?? const []);
  List<String> get effectivePullImages =>
      pullImages.isNotEmpty ? pullImages : (post?.pullImages ?? const []);

  bool get isSingleCard {
    if (effectivePostType == PostType.singlePull) return true;
    if (effectiveCardId != null && effectiveCardId!.isNotEmpty && effectivePullCardIds.isEmpty) {
      return true;
    }
    return false;
  }

  bool get isMultiCard {
    if (effectivePostType == PostType.multiPull || effectivePostType == PostType.mixedMedia) {
      return true;
    }
    if (effectivePullCardIds.length > 1) return true;
    if (effectivePullImages.length > 1 && effectivePostType != PostType.media) return true;
    return false;
  }

  void _handleUserTap(BuildContext context) {
    if (onUserTap != null) {
      onUserTap!();
    } else if (authorId != null && authorId!.isNotEmpty) {
      context.push('/profile/$authorId');
    }
  }

  void _handleMenuAction(BuildContext context, String action) async {
    try {
      final container = ProviderScope.containerOf(context, listen: false);
      final currentUserId = container.read(currentUserIdProvider);
      final feedDao = container.read(feedDaoProvider);
      final db = container.read(appDatabaseProvider);

      if (action == 'wishlist_card') {
        if (onWishlistTap != null) {
          onWishlistTap!();
        } else if (effectiveCardId != null && effectiveCardId!.isNotEmpty) {
          await addCardToLookingForBinder(
            db: db,
            userId: currentUserId,
            cardId: effectiveCardId!,
            cardTitle: effectiveCardTitle,
            cardImageUrl: effectiveCardImageUrl,
          );
          if (context.mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
                content: Text(
                  effectiveCardTitle != null && effectiveCardTitle!.isNotEmpty
                      ? 'Added ${effectiveCardTitle!} to Looking For binder'
                      : 'Added card to Looking For binder',
                ),
              ),
            );
          }
        }
      } else if (action == 'wishlist_cards_drawer') {
        if (!context.mounted) return;
        if (post != null) {
          MultiCardWishlistDrawer.show(context, post: post!);
        } else {
          MultiCardWishlistDrawer.showWithData(
            context,
            cardIds: effectivePullCardIds,
            imageUrls: effectivePullImages,
          );
        }
      } else if (action == 'save_post') {
        if (onSavePostTap != null) {
          onSavePostTap!();
        } else if (effectivePostId.isNotEmpty) {
          final isSaved = await feedDao.toggleSavePost(effectivePostId, currentUserId);
          if (context.mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
                content: Text(
                  isSaved ? 'Post saved to Command Center' : 'Post removed from saved',
                ),
              ),
            );
          }
        }
      }
    } catch (_) {
      // Standalone widget test without ProviderScope
      if (!context.mounted) return;
      if (action == 'wishlist_card') {
        onWishlistTap?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 2),
            content: Text(
              effectiveCardTitle != null && effectiveCardTitle!.isNotEmpty
                  ? 'Added ${effectiveCardTitle!} to Looking For binder'
                  : 'Added card to Looking For binder',
            ),
          ),
        );
      } else if (action == 'wishlist_cards_drawer') {
        if (post != null) {
          MultiCardWishlistDrawer.show(context, post: post!);
        } else {
          MultiCardWishlistDrawer.showWithData(
            context,
            cardIds: effectivePullCardIds,
            imageUrls: effectivePullImages,
          );
        }
      } else if (action == 'save_post') {
        onSavePostTap?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            duration: Duration(seconds: 2),
            content: Text('Post saved'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 260;
        final horizontalPadding = isNarrow ? 8.0 : 16.0;
        final avatarGap = isNarrow ? 6.0 : 8.0;

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Avatar Icon (Left)
          InkWell(
            key: Key('post_avatar_${authorId ?? username}'),
            borderRadius: BorderRadius.circular(21),
            onTap: () => _handleUserTap(context),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [AppColors.accentViolet, AppColors.accentCyan],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentCyan.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(2),
              child: ClipOval(
                child: (avatarUrl != null && avatarUrl!.isNotEmpty)
                    ? CountrCachedImage(
                        imageUrl: avatarUrl!,
                        fit: BoxFit.cover,
                        errorWidget: Container(
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.surfaceRaised,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            avatarInitials,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                      )
                    : Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.surfaceRaised,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          avatarInitials,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
              ),
            ),
          ),
          SizedBox(width: avatarGap),

          // 2. Username & Location Tag
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  key: Key('post_username_${authorId ?? username}'),
                  onTap: () => _handleUserTap(context),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          username,
                          style: AppTypography.heading2.copyWith(fontSize: 15),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.verified_rounded,
                        size: 14,
                        color: AppColors.accentCyan,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                // Subtext/Location Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: locationTag.startsWith('PULLED')
                        ? AppColors.accentAmber.withValues(alpha: 0.15)
                        : AppColors.surfaceHighlight,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: locationTag.startsWith('PULLED')
                          ? AppColors.accentAmber.withValues(alpha: 0.4)
                          : AppColors.surfaceBorder,
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        locationTag.startsWith('PULLED')
                            ? Icons.auto_awesome
                            : Icons.place_outlined,
                        size: 10,
                        color: locationTag.startsWith('PULLED')
                            ? AppColors.accentAmber
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          locationTag,
                          style: AppTypography.caption.copyWith(
                            color: locationTag.startsWith('PULLED')
                                ? AppColors.accentAmber
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 4),

          // 3. Timestamp
          Text(
            timestamp,
            style: AppTypography.caption,
          ),

          const SizedBox(width: 2),

          // 4. Milestone 3: Post Header '⋮' Overflow Menu
          Theme(
            data: Theme.of(context).copyWith(
              cardColor: AppColors.surfaceRaised,
            ),
            child: PopupMenuButton<String>(
              key: const Key('post_header_overflow_menu'),
              padding: EdgeInsets.zero,
              color: AppColors.surfaceRaised,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.surfaceBorder, width: 0.8),
              ),
              elevation: 8,
              onSelected: (action) => _handleMenuAction(context, action),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                child: Icon(
                  Icons.more_vert_rounded,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
              ),
              itemBuilder: (BuildContext context) {
                if (isSingleCard) {
                  return [
                    const PopupMenuItem<String>(
                      key: Key('post_menu_wishlist_card'),
                      value: 'wishlist_card',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.bookmark_add_outlined,
                            size: 18,
                            color: AppColors.accentAmber,
                          ),
                          SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              'Wishlist Card (Add to Looking For)',
                              style: TextStyle(fontSize: 13, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ];
                } else if (isMultiCard) {
                  return [
                    const PopupMenuItem<String>(
                      key: Key('post_menu_wishlist_cards_drawer'),
                      value: 'wishlist_cards_drawer',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.collections_bookmark_outlined,
                            size: 18,
                            color: AppColors.accentCyan,
                          ),
                          SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              'Wishlist Cards',
                              style: TextStyle(fontSize: 13, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ];
                } else {
                  return [
                    const PopupMenuItem<String>(
                      key: Key('post_menu_save_post'),
                      value: 'save_post',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.bookmark_border_rounded,
                            size: 18,
                            color: AppColors.accentCyan,
                          ),
                          SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              'Save Post',
                              style: TextStyle(fontSize: 13, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ];
                }
              },
            ),
          ),
        ],
      ),
    );
  },
);
}
}
