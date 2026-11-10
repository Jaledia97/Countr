import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:drift/drift.dart' as drift;
import 'package:countr/core/cache/countr_cached_image.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/auth/presentation/providers/auth_providers.dart';
import 'package:countr/features/auth/presentation/widgets/auth_modal_sheet.dart';
import 'package:countr/features/auth/presentation/widgets/verified_store_badge.dart';
import 'package:countr/features/feed/data/daos/inbox_dao.dart';
import 'package:countr/features/feed/presentation/providers/inbox_providers.dart';
import 'package:countr/features/feed/presentation/providers/friends_providers.dart';
import 'package:countr/features/feed/presentation/providers/feed_providers.dart';
import 'package:countr/features/feed/presentation/widgets/post_card.dart';
import 'package:countr/features/profile/presentation/providers/profile_providers.dart';
import 'package:countr/features/trades/presentation/screens/trade_modal_sheet.dart';
import 'package:countr/features/trades/domain/services/trade_match_service.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';
import 'package:countr/features/decks/presentation/widgets/explore/explore_deck_unpublish_dialog.dart';

/// User and Business Profile Screen (M3 / Epic 3)
/// Supports dark-slate & neon layout, cover banner, circular avatar with photo
/// upload trigger for self, verified LGS badge, contextual action bars,
/// 3x3 system binder modals, and activity wall.
class UserProfileScreen extends ConsumerStatefulWidget {
  final String profileId;

  const UserProfileScreen({
    super.key,
    required this.profileId,
  });

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {

  bool get _isSelf {
    final activeId = ref.watch(currentUserIdProvider);
    return widget.profileId == 'me' || widget.profileId == activeId;
  }

  String get _effectiveUserId {
    if (widget.profileId == 'me') {
      return ref.watch(currentUserIdProvider);
    }
    return widget.profileId;
  }

  @override
  Widget build(BuildContext context) {
    final targetId = _effectiveUserId;
    final profileAsync = ref.watch(userProfileProvider(targetId));

    return Scaffold(
      key: const Key('user_profile_screen'),
      backgroundColor: AppColors.background,
      body: profileAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentCyan),
          ),
        ),
        error: (err, _) => _buildNotFoundState(context),
        data: (profile) {
          if (profile == null) {
            // If active user is guest and no profile in DB, create fallback guest profile
            final authUser = ref.watch(currentUserProvider);
            if (_isSelf && authUser.isGuest) {
              return _buildProfileContent(
                context,
                UserProfile(
                  id: authUser.id,
                  username: authUser.username,
                  displayName: authUser.displayName,
                  bio: 'Guest Collector exploring Countr. Sign in to customize!',
                  avatarUrl: null,
                  bannerUrl: null,
                  accountType: 'individual',
                  isVerifiedBusiness: false,
                  friendCount: 0,
                  repCount: 0,
                  tier: 'guest',
                  syncStatus: 'synced',
                  collectionVisibility: 'public',
                  createdAt: DateTime.now(),
                  isDeleted: false,
                ),
                isGuestSelf: true,
              );
            }
            return _buildNotFoundState(context);
          }
          return _buildProfileContent(context, profile);
        },
      ),
    );
  }

  Widget _buildNotFoundState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.person_off_rounded,
              size: 64,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            const Text(
              'Profile Not Found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This user or store profile does not exist or has been removed.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  context.go('/feed');
                }
              },
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Return to Feed'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentCyan,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileContent(
    BuildContext context,
    UserProfile profile, {
    bool isGuestSelf = false,
  }) {
    final isBusiness =
        profile.accountType == 'business' || profile.isVerifiedBusiness;
    final wallPosts = ref.watch(userWallPostsProvider(profile.id));

    return CustomScrollView(
      slivers: [
        // 1. Cover Banner & AppBar
        SliverAppBar(
          expandedHeight: 160,
          pinned: true,
          backgroundColor: AppColors.surface,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Navigator.of(context).canPop()
                  ? Icons.arrow_back_rounded
                  : Icons.home_rounded,
              color: AppColors.textPrimary,
            ),
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                context.go('/feed');
              }
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.share_rounded, color: AppColors.textPrimary),
              tooltip: 'Share Profile',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Profile link copied: countr.app/u/${profile.username}'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            if (_isSelf)
              IconButton(
                key: const Key('profile_btn_edit_profile'),
                icon: const Icon(Icons.edit_rounded, color: AppColors.accentCyan),
                tooltip: 'Edit Profile',
                onPressed: () => _showEditProfileDialog(context, profile),
              ),
            if (!_isSelf)
              IconButton(
                key: const Key('profile_btn_secondary_menu'),
                icon: const Icon(Icons.more_vert_rounded, color: AppColors.textPrimary),
                tooltip: 'More Options',
                onPressed: () => _showSecondaryProfileMenu(context, profile),
              ),
            const SizedBox(width: 8),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                if (profile.bannerUrl != null && profile.bannerUrl!.isNotEmpty)
                  CountrCachedImage(
                    imageUrl: profile.bannerUrl!,
                    fit: BoxFit.cover,
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.surfaceRaised,
                          AppColors.accentViolet.withValues(alpha: 0.35),
                          AppColors.surface,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black54,
                        Colors.transparent,
                        AppColors.background.withValues(alpha: 0.8),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // 2. Profile Header Card
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar Row & Badges
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Circular Avatar
                    Stack(
                      children: [
                        Container(
                          key: const Key('profile_avatar'),
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isBusiness
                                  ? AppColors.accentAmber
                                  : AppColors.accentCyan,
                              width: 2.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (isBusiness
                                        ? AppColors.accentAmber
                                        : AppColors.accentCyan)
                                    .withValues(alpha: 0.25),
                                blurRadius: 16,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: profile.avatarUrl != null &&
                                    profile.avatarUrl!.isNotEmpty
                                ? CountrCachedImage(
                                    imageUrl: profile.avatarUrl!,
                                    fit: BoxFit.cover,
                                  )
                                : Container(
                                    color: AppColors.surfaceRaised,
                                    child: Center(
                                      child: Text(
                                        profile.displayName.isNotEmpty
                                            ? profile.displayName
                                                .substring(0, 1)
                                                .toUpperCase()
                                            : 'U',
                                        style: TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.bold,
                                          color: isBusiness
                                              ? AppColors.accentAmber
                                              : AppColors.accentCyan,
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        if (_isSelf)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: InkWell(
                              key: const Key('profile_avatar_upload_button'),
                              onTap: () => _handleAvatarUpload(context),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.accentCyan,
                                    width: 1.5,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  size: 14,
                                  color: AppColors.accentCyan,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    // Names & Badges
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  profile.displayName,
                                  key: const Key('profile_display_name'),
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (profile.isVerifiedBusiness) ...[
                                const SizedBox(width: 6),
                                const VerifiedStoreBadge(),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  profile.username.startsWith('@')
                                      ? profile.username
                                      : '@${profile.username}',
                                  key: const Key('profile_username'),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.accentCyan,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildTierBadge(profile.tier),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // Bio
                if (profile.bio != null && profile.bio!.isNotEmpty)
                  Text(
                    profile.bio!,
                    key: const Key('profile_bio'),
                    style: const TextStyle(
                      fontSize: 13.5,
                      height: 1.4,
                      color: AppColors.textSecondary,
                    ),
                  ),

                // Store details for LGS
                if (isBusiness) ...[
                  const SizedBox(height: 10),
                  if (profile.storeAddress != null &&
                      profile.storeAddress!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            size: 15,
                            color: AppColors.accentAmber,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              profile.storeAddress!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (profile.storeWebsite != null &&
                      profile.storeWebsite!.isNotEmpty)
                    Row(
                      children: [
                        const Icon(
                          Icons.link_rounded,
                          size: 15,
                          color: AppColors.accentCyan,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            profile.storeWebsite!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.accentCyan,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                ],

                // Guest prompt banner
                if (isGuestSelf) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceRaised,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.accentViolet.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: AppColors.accentVioletLight,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'You are currently browsing as a Guest',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.5,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Sign in to customize your profile, unlock unlimited binders, and trade with the community!',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () => AuthModalSheet.show(context),
                          child: const Text('Sign In'),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Stats Row
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.surfaceBorder,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Expanded(
                        child: _buildStatColumn(
                          key: isBusiness
                              ? const Key('profile_stat_followers')
                              : const Key('profile_stat_friends'),
                          label: isBusiness ? 'Followers' : 'Friends',
                          value: isBusiness
                              ? '${ref.watch(followersCountProvider(profile.id)).value ?? 0}'
                              : '${ref.watch(friendCountStreamProvider(profile.id)).value ?? profile.friendCount}',
                          onTap: isBusiness
                              ? null
                              : () {
                                  context.push('/friends?userId=${profile.id}');
                                },
                        ),
                      ),
                      Container(
                        height: 28,
                        width: 1,
                        color: AppColors.surfaceBorder,
                      ),
                      Expanded(
                        child: _buildStatColumn(
                          key: const Key('profile_stat_rep'),
                          label: 'Reputation',
                          value: '${profile.repCount}',
                          onTap: null,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // 2.5. Trade Opportunity Banner (Feature 7)
        if (!_isSelf)
          SliverToBoxAdapter(
            child: Builder(
              builder: (context) {
                final currentUserId = ref.watch(currentUserIdProvider);
                final matchesAsync =
                    ref.watch(tradeMatchesForUserProvider(currentUserId));
                final matchesForThisUser = matchesAsync.value
                        ?.where((m) => m.partnerUser.id == profile.id)
                        .toList() ??
                    [];

                if (matchesForThisUser.isEmpty) {
                  return const SizedBox.shrink();
                }

                final match = matchesForThisUser.first;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Container(
                    key: const Key('profile_trade_match_banner'),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.accentAmber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.accentAmber.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.accentAmber.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.auto_awesome_rounded,
                            color: AppColors.accentAmber,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'Trade Opportunity!',
                                    style: TextStyle(
                                      color: AppColors.accentAmber,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (match.isMutual) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.accentCyan
                                            .withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'MUTUAL',
                                        style: TextStyle(
                                          color: AppColors.accentCyan,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '@${profile.username.replaceFirst('@', '')} has ${match.matchingTradeCard.name} in their Trade Binder that you have been looking for!',
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 12,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          key: const Key('profile_trade_match_propose_button'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentCyan,
                            foregroundColor: AppColors.background,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            minimumSize: const Size(60, 32),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () {
                            _showProposeTradeModal(
                              context,
                              profile,
                              initialPartnerCard: match.matchingTradeCard,
                            );
                          },
                          child: const Text(
                            'Propose',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

        // 3. Profile Contextual Action Bar
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: isBusiness
                ? _buildBusinessActionBar(context, profile)
                : _buildIndividualActionBar(context, profile),
          ),
        ),

        // 4. Activity Wall Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Row(
              children: [
                const Icon(
                  Icons.dynamic_feed_rounded,
                  size: 18,
                  color: AppColors.accentCyan,
                ),
                const SizedBox(width: 8),
                const Text(
                  'ACTIVITY WALL',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceRaised,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${wallPosts.length}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.accentCyan,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // 5. Activity Wall Feed
        if (wallPosts.isEmpty)
          SliverToBoxAdapter(
            child: Container(
              key: const Key('profile_activity_wall'),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: Column(
                children: const [
                  Icon(
                    Icons.feed_outlined,
                    size: 40,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'No posts yet. Recent card pulls, deck shares, and trades will appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final post = wallPosts[index];
                return PostCard(post: post);
              },
              childCount: wallPosts.length,
            ),
          ),

        const SliverToBoxAdapter(
          child: SizedBox(height: 48),
        ),
      ],
    );
  }

  Widget _buildTierBadge(String tier) {
    Color badgeColor;
    String label = tier.toUpperCase();

    switch (tier.toLowerCase()) {
      case 'business':
        badgeColor = AppColors.accentAmber;
        label = 'LGS';
        break;
      case 'pro':
        badgeColor = AppColors.accentCyan;
        label = 'PRO';
        break;
      case 'guest':
        badgeColor = AppColors.textSecondary;
        label = 'GUEST';
        break;
      default:
        badgeColor = AppColors.accentVioletLight;
        label = 'FREE';
    }

    return Container(
      key: const Key('profile_tier_badge'),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: badgeColor.withValues(alpha: 0.6),
          width: 0.8,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: badgeColor,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _buildStatColumn({
    Key? key,
    required String label,
    required String value,
    VoidCallback? onTap,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIndividualActionBar(BuildContext context, UserProfile profile) {
    return Column(
      children: [
        // Top row: Looking For & Trade Block
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                key: const Key('profile_btn_looking_for'),
                onPressed: () => _showSystemBinderModal(
                  context,
                  title: 'Looking For',
                  binderType: 'looking_for',
                  userId: profile.id,
                ),
                icon: const Icon(Icons.search_rounded, size: 16),
                label: const Text('Looking For'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.surfaceRaised,
                  foregroundColor: AppColors.accentCyan,
                  side: const BorderSide(color: AppColors.accentCyan, width: 1),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                key: const Key('profile_btn_trade_block'),
                onPressed: () => _showSystemBinderModal(
                  context,
                  title: 'Trade Block',
                  binderType: 'trade_block',
                  userId: profile.id,
                ),
                icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                label: const Text('Trade Block'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.surfaceRaised,
                  foregroundColor: AppColors.accentVioletLight,
                  side: const BorderSide(
                    color: AppColors.accentVioletLight,
                    width: 1,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Shared decks button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            key: const Key('profile_btn_shared_decks'),
            onPressed: () => _showSharedDecksModal(context, profile.id),
            icon: const Icon(Icons.style_outlined, size: 16),
            label: const Text('Shared Decks'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(color: AppColors.surfaceBorder),
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),

        // Social Actions (Hidden if viewing self)
        if (!_isSelf) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  key: const Key('profile_btn_propose_trade'),
                  onPressed: () => _showProposeTradeModal(context, profile),
                  icon: const Icon(Icons.handshake_rounded, size: 16),
                  label: const Text('Propose Trade'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentCyan,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: _buildFriendshipControl(context, profile),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                key: const Key('profile_btn_message'),
                onPressed: () {
                  final currentUserId = ref.read(currentUserIdProvider);
                  final convId = InboxDao.getConversationId(currentUserId, profile.id);
                  context.push('/inbox/chat/$convId?contactId=${profile.id}');
                },
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                tooltip: 'Direct Message',
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildFriendshipControl(BuildContext context, UserProfile profile) {
    final currentUserId = ref.watch(currentUserIdProvider);
    final friendshipStatusAsync = ref.watch(friendshipStatusProvider(profile.id));
    final status = friendshipStatusAsync.value ?? 'none';

    switch (status) {
      case 'friends':
        return OutlinedButton.icon(
          key: const Key('profile_btn_friends_dropdown'),
          onPressed: () => _showFriendsDropdownMenu(context, profile),
          icon: const Icon(Icons.check_circle_rounded, size: 16, color: Colors.greenAccent),
          label: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Friends', style: TextStyle(color: Colors.greenAccent)),
              SizedBox(width: 4),
              Icon(Icons.arrow_drop_down_rounded, size: 18, color: Colors.greenAccent),
            ],
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.greenAccent,
            side: const BorderSide(color: Colors.greenAccent),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );

      case 'pending_received':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              key: const Key('profile_btn_approve_friend'),
              onPressed: () async {
                await ref.read(friendsDaoProvider).respondToFriendRequest(
                  currentUserId,
                  profile.id,
                  accept: true,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('You are now friends with ${profile.displayName}'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.check_rounded, size: 15),
              label: const Text('Approve', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentCyan,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(width: 6),
            OutlinedButton.icon(
              key: const Key('profile_btn_deny_friend'),
              onPressed: () async {
                await ref.read(friendsDaoProvider).respondToFriendRequest(
                  currentUserId,
                  profile.id,
                  accept: false,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Friend request declined'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.close_rounded, size: 15),
              label: const Text('Deny', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accentRose,
                side: const BorderSide(color: AppColors.accentRose),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        );

      case 'pending_sent':
        return OutlinedButton.icon(
          key: const Key('profile_btn_request_sent'),
          onPressed: () async {
            await ref.read(friendsDaoProvider).cancelFriendRequest(currentUserId, profile.id);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Friend request cancelled'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
          icon: const Icon(Icons.pending_rounded, size: 16),
          label: const Text('Request Sent', style: TextStyle(fontSize: 12)),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            side: const BorderSide(color: AppColors.surfaceBorder),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );

      case 'blocked':
        return OutlinedButton.icon(
          key: const Key('profile_btn_unblock'),
          onPressed: () async {
            await ref.read(friendsDaoProvider).unblockUser(currentUserId, profile.id);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Unblocked ${profile.displayName}'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
          icon: const Icon(Icons.lock_open_rounded, size: 16),
          label: const Text('Unblock'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.accentRose,
            side: const BorderSide(color: AppColors.accentRose),
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );

      case 'blocked_by':
        return OutlinedButton(
          onPressed: null,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            side: const BorderSide(color: AppColors.surfaceBorder),
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text('Unavailable'),
        );

      case 'none':
      default:
        return OutlinedButton.icon(
          key: const Key('profile_btn_add_friend'),
          onPressed: () async {
            await ref.read(friendsDaoProvider).sendFriendRequest(currentUserId, profile.id);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Friend request sent to ${profile.displayName}'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
          icon: const Icon(Icons.person_add_rounded, size: 16),
          label: const Text('Add Friend'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            side: const BorderSide(color: AppColors.surfaceBorder),
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
    }
  }

  void _showFriendsDropdownMenu(BuildContext context, UserProfile profile) {
    final currentUserId = ref.read(currentUserIdProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.surfaceBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                key: const Key('profile_menu_unfriend'),
                leading: const Icon(Icons.person_remove_rounded, color: AppColors.textSecondary),
                title: const Text('Unfriend', style: TextStyle(color: AppColors.textPrimary)),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await ref.read(friendsDaoProvider).removeFriend(currentUserId, profile.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Removed ${profile.displayName} from friends'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
              ),
              ListTile(
                key: const Key('profile_menu_block_user'),
                leading: const Icon(Icons.block_rounded, color: AppColors.accentRose),
                title: const Text('Block User', style: TextStyle(color: AppColors.accentRose)),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await ref.read(friendsDaoProvider).blockUser(currentUserId, profile.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Blocked ${profile.displayName}'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
              ),
              ListTile(
                key: const Key('profile_menu_report_profile'),
                leading: const Icon(Icons.flag_outlined, color: AppColors.textSecondary),
                title: const Text('Report Profile', style: TextStyle(color: AppColors.textPrimary)),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Profile reported. Thank you for keeping Countr safe.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSecondaryProfileMenu(BuildContext context, UserProfile profile) {
    final currentUserId = ref.read(currentUserIdProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.surfaceBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                key: const Key('profile_menu_block_user'),
                leading: const Icon(Icons.block_rounded, color: AppColors.accentRose),
                title: const Text('Block User', style: TextStyle(color: AppColors.accentRose)),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await ref.read(friendsDaoProvider).blockUser(currentUserId, profile.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Blocked ${profile.displayName}'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
              ),
              ListTile(
                key: const Key('profile_menu_report_profile'),
                leading: const Icon(Icons.flag_outlined, color: AppColors.textSecondary),
                title: const Text('Report Profile', style: TextStyle(color: AppColors.textPrimary)),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Profile reported. Thank you for keeping Countr safe.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBusinessActionBar(BuildContext context, UserProfile profile) {
    return Column(
      children: [
        // Store Inventory & Store Buylist
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                key: const Key('profile_btn_store_inventory'),
                onPressed: () => _showSystemBinderModal(
                  context,
                  title: 'Store Inventory',
                  binderType: 'store_inventory',
                  userId: profile.id,
                ),
                icon: const Icon(Icons.inventory_2_outlined, size: 16),
                label: const Text('Store Inventory'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.surfaceRaised,
                  foregroundColor: AppColors.accentAmber,
                  side: const BorderSide(color: AppColors.accentAmber, width: 1),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                key: const Key('profile_btn_store_buylist'),
                onPressed: () => _showSystemBinderModal(
                  context,
                  title: 'Store Buylist',
                  binderType: 'store_buylist',
                  userId: profile.id,
                ),
                icon: const Icon(Icons.price_change_outlined, size: 16),
                label: const Text('Store Buylist'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.surfaceRaised,
                  foregroundColor: AppColors.accentCyan,
                  side: const BorderSide(color: AppColors.accentCyan, width: 1),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Shared Decks
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            key: const Key('profile_btn_shared_decks'),
            onPressed: () => _showSharedDecksModal(context, profile.id),
            icon: const Icon(Icons.style_outlined, size: 16),
            label: const Text('Store Tournament Builds / Decks'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(color: AppColors.surfaceBorder),
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),

        if (!_isSelf) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildBusinessFollowButton(context, profile),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  key: const Key('profile_btn_propose_trade'),
                  onPressed: () => _showProposeTradeModal(context, profile),
                  icon: const Icon(Icons.handshake_rounded, size: 16),
                  label: const Text('Propose Trade / Buylist Offer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentAmber,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                key: const Key('profile_btn_message'),
                onPressed: () {
                  final currentUserId = ref.read(currentUserIdProvider);
                  final convId = InboxDao.getConversationId(currentUserId, profile.id);
                  context.push('/inbox/chat/$convId?contactId=${profile.id}');
                },
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                tooltip: 'Contact Store',
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildBusinessFollowButton(BuildContext context, UserProfile profile) {
    final currentUserId = ref.watch(currentUserIdProvider);
    final isFollowingAsync = ref.watch(isFollowingProvider(profile.id));
    final isFollowing = isFollowingAsync.value ?? false;

    if (isFollowing) {
      return ElevatedButton.icon(
        key: const Key('profile_btn_follow'),
        onPressed: () async {
          final db = ref.read(appDatabaseProvider);
          await db.feedDao.toggleFollow(currentUserId, profile.id);
          ref.invalidate(isFollowingProvider(profile.id));
          ref.invalidate(followersCountProvider(profile.id));
          ref.invalidate(feedPostsStreamProvider);
        },
        icon: const Icon(Icons.check_rounded, size: 16, color: Colors.black),
        label: const Text(
          'Following ✓',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accentCyan,
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } else {
      return OutlinedButton.icon(
        key: const Key('profile_btn_follow'),
        onPressed: () async {
          final db = ref.read(appDatabaseProvider);
          await db.feedDao.toggleFollow(currentUserId, profile.id);
          ref.invalidate(isFollowingProvider(profile.id));
          ref.invalidate(followersCountProvider(profile.id));
          ref.invalidate(feedPostsStreamProvider);
        },
        icon: const Icon(Icons.add_rounded, size: 16, color: AppColors.accentCyan),
        label: const Text(
          'Follow',
          style: TextStyle(
            color: AppColors.accentCyan,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.accentCyan),
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  void _showSystemBinderModal(
    BuildContext context, {
    required String title,
    required String binderType,
    required String userId,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Consumer(
          builder: (context, ref, _) {
            final cardsAsync = ref.watch(
              userSystemBinderCardsProvider(
                (userId: userId, binderType: binderType),
              ),
            );

            return DraggableScrollableSheet(
              key: const Key('system_binder_grid_modal'),
              initialChildSize: 0.75,
              minChildSize: 0.4,
              maxChildSize: 0.95,
              expand: false,
              builder: (ctx, scrollController) {
                return Column(
                  children: [
                    // Handle & Title bar
                    Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            binderType.contains('inventory') ||
                                    binderType.contains('buylist')
                                ? Icons.storefront_rounded
                                : Icons.folder_special_rounded,
                            color: AppColors.accentCyan,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.of(sheetContext).pop(),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: AppColors.surfaceBorder, height: 1),

                    // Content: 3x3 Card Grid
                    Expanded(
                      child: cardsAsync.when(
                        loading: () => const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.accentCyan,
                            ),
                          ),
                        ),
                        error: (err, _) => Center(
                          child: Text(
                            'Error loading cards: $err',
                            style: const TextStyle(color: Colors.redAccent),
                          ),
                        ),
                        data: (cards) {
                          if (cards.isEmpty) {
                            String emptyMessage;
                            switch (binderType) {
                              case 'looking_for':
                                emptyMessage =
                                    'No cards currently on looking-for list';
                                break;
                              case 'trade_block':
                                emptyMessage = 'Trade block is empty';
                                break;
                              case 'store_inventory':
                                emptyMessage =
                                    'This store hasn\'t listed any singles yet.';
                                break;
                              case 'store_buylist':
                                emptyMessage =
                                    'Store is not currently seeking cards.';
                                break;
                              default:
                                emptyMessage = 'No cards in this system binder';
                            }

                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.inventory_2_outlined,
                                      size: 48,
                                      color: AppColors.textSecondary,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      emptyMessage,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          return GridView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.all(12),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              childAspectRatio: 0.68,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                            itemCount: cards.length,
                            itemBuilder: (context, index) {
                              final card = cards[index];
                              return InkWell(
                                onTap: () =>
                                    CardDetailSheet.show(context, card),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppColors.surfaceBorder,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius:
                                              const BorderRadius.vertical(
                                            top: Radius.circular(8),
                                          ),
                                          child: card.imageUrl.isNotEmpty
                                              ? CountrCachedImage(
                                                  imageUrl: card.imageUrl,
                                                  fit: BoxFit.cover,
                                                )
                                              : Container(
                                                  color: AppColors.surfaceRaised,
                                                  child: const Icon(
                                                    Icons.image_outlined,
                                                    color: AppColors
                                                        .textSecondary,
                                                  ),
                                                ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(6.0),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              card.name,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.textPrimary,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              card.currentMarketPrice > 0
                                                  ? '\$${card.currentMarketPrice.toStringAsFixed(2)}'
                                                  : 'x${card.quantity}',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: AppColors.accentCyan,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _showSharedDecksModal(BuildContext context, String userId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Consumer(
          builder: (context, ref, _) {
            final decksAsync = ref.watch(userSharedDecksProvider(userId));

            return DraggableScrollableSheet(
              key: const Key('shared_decks_modal'),
              initialChildSize: 0.65,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              expand: false,
              builder: (ctx, scrollController) {
                return Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.style_rounded,
                            color: AppColors.accentVioletLight,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Shared Explore Decks',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.of(sheetContext).pop(),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: AppColors.surfaceBorder, height: 1),
                    Expanded(
                      child: decksAsync.when(
                        loading: () => const Center(
                          child: CircularProgressIndicator(),
                        ),
                        error: (err, _) => Center(
                          child: Text(
                            'Error: $err',
                            style: const TextStyle(color: Colors.redAccent),
                          ),
                        ),
                        data: (decks) {
                          if (decks.isEmpty) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24.0),
                                child: Text(
                                  'No decks shared to Explore yet',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            );
                          }
                          return ListView.separated(
                            controller: scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: decks.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final deck = decks[index];
                              final currentUserId = ref.watch(currentUserIdProvider);
                              final isAuthor = isExploreDeckAuthor(deck: deck, currentUserId: currentUserId) ||
                                  userId == currentUserId ||
                                  userId == 'me';

                              return ListTile(
                                tileColor: AppColors.surface,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: const BorderSide(
                                    color: AppColors.surfaceBorder,
                                  ),
                                ),
                                title: Text(
                                  deck.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                subtitle: Text(
                                  '${deck.format.toUpperCase()} • ${deck.cardCount} cards',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isAuthor)
                                      PopupMenuButton<String>(
                                        key: Key('profile_shared_deck_menu_${deck.id}'),
                                        icon: const Icon(
                                          Icons.more_vert_rounded,
                                          color: AppColors.textSecondary,
                                          size: 20,
                                        ),
                                        tooltip: 'Deck options',
                                        color: AppColors.surfaceRaised,
                                        elevation: 8,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          side: const BorderSide(color: AppColors.surfaceBorder),
                                        ),
                                        onSelected: (val) {
                                          if (val == 'unpublish') {
                                            showExploreDeckUnpublishWorkflow(
                                              context: context,
                                              ref: ref,
                                              deck: deck,
                                              popOnSuccess: false,
                                            );
                                          }
                                        },
                                        itemBuilder: (context) => [
                                          PopupMenuItem<String>(
                                            key: Key('profile_unpublish_deck_${deck.id}'),
                                            value: 'unpublish',
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.public_off_rounded,
                                                  color: AppColors.accentRose,
                                                  size: 16,
                                                ),
                                                SizedBox(width: 8),
                                                Flexible(
                                                  child: Text(
                                                    'Unpublish from Explore',
                                                    style: TextStyle(
                                                      color: AppColors.accentRose,
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 12.5,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      )
                                    else
                                      const Icon(
                                        Icons.chevron_right_rounded,
                                        color: AppColors.textSecondary,
                                      ),
                                  ],
                                ),
                                onTap: () {
                                  Navigator.of(sheetContext).pop();
                                  context.push('/explore/deck/${deck.id}');
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _handleAvatarUpload(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceRaised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Update Profile Photo',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  key: const Key('profile_avatar_take_photo'),
                  leading: const Icon(Icons.photo_camera_rounded,
                      color: AppColors.accentCyan),
                  title: const Text('Take Photo',
                      style: TextStyle(color: AppColors.textPrimary)),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await _pickAndSaveAvatar(context, ImageSource.camera);
                  },
                ),
                ListTile(
                  key: const Key('profile_avatar_choose_gallery'),
                  leading: const Icon(Icons.photo_library_rounded,
                      color: AppColors.accentCyan),
                  title: const Text('Choose from Gallery',
                      style: TextStyle(color: AppColors.textPrimary)),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await _pickAndSaveAvatar(context, ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickAndSaveAvatar(BuildContext context, ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (pickedFile == null) return;

      final docsDir = await getApplicationDocumentsDirectory();
      final avatarsDir = Directory(p.join(docsDir.path, 'avatars'));
      if (!await avatarsDir.exists()) {
        await avatarsDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final targetUserId = _effectiveUserId;
      final destPath = p.join(avatarsDir.path, '${targetUserId}_$timestamp.jpg');
      await File(pickedFile.path).copy(destPath);

      final db = ref.read(appDatabaseProvider);

      // 1. Update user profile in SQLite
      await db.userProfileDao.updateAvatar(targetUserId, destPath);

      // 2. Cascade avatar to user's feed posts
      await db.feedDao.updateAuthorAvatar(targetUserId, destPath);

      // 3. Immediately refresh UI
      ref.invalidate(userProfileProvider(targetUserId));
      ref.invalidate(userProfileProvider('me'));
      ref.invalidate(currentUserProfileProvider);
      ref.invalidate(feedPostsStreamProvider);
      ref.invalidate(userWallPostsStreamProvider(targetUserId));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo updated successfully'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('[UserProfileScreen] Error updating avatar: $e');
    }
  }

  void _showEditProfileDialog(BuildContext context, UserProfile profile) {
    final nameCtrl = TextEditingController(text: profile.displayName);
    final usernameCtrl = TextEditingController(
      text: profile.username.startsWith('@') ? profile.username : '@${profile.username}',
    );
    final avatarCtrl = TextEditingController(text: profile.avatarUrl ?? '');
    final bioCtrl = TextEditingController(text: profile.bio ?? '');
    var selectedVisibility = profile.collectionVisibility;

    showDialog(
      context: context,
      builder: (dlgContext) {
        return AlertDialog(
          key: const Key('edit_profile_dialog'),
          backgroundColor: AppColors.surfaceRaised,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.edit_rounded, color: AppColors.accentCyan, size: 22),
              SizedBox(width: 8),
              Text(
                'Edit Profile',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  key: const Key('edit_profile_display_name_field'),
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Display Name',
                    hintText: 'e.g. Master Collector',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.badge_rounded, color: AppColors.accentCyan),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('edit_profile_username_field'),
                  controller: usernameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Username (@handle)',
                    hintText: '@username',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.alternate_email_rounded, color: AppColors.accentCyan),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('edit_profile_avatar_url_field'),
                  controller: avatarCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Profile Picture / Avatar URL',
                    hintText: 'https://...',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.photo_camera_rounded, color: AppColors.accentCyan),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('edit_profile_bio_field'),
                  controller: bioCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Bio & Collector Notes',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.notes_rounded, color: AppColors.accentCyan),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: const Key('edit_profile_collection_visibility_dropdown'),
                  isExpanded: true,
                  initialValue: selectedVisibility,
                  decoration: const InputDecoration(
                    labelText: 'Collection Visibility',
                    helperText: 'Public: Trade partners browse full collection. Private: Trade binder only.',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.inventory_2_outlined, color: AppColors.accentCyan),
                  ),
                  dropdownColor: AppColors.surfaceRaised,
                  items: const [
                    DropdownMenuItem(
                      value: 'public',
                      child: Text('Public (Full Collection & Trade Binder)', overflow: TextOverflow.ellipsis),
                    ),
                    DropdownMenuItem(
                      value: 'private',
                      child: Text('Private (Trade Binder Only)', overflow: TextOverflow.ellipsis),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      selectedVisibility = val;
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dlgContext).pop(),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              key: const Key('edit_profile_save_button'),
              onPressed: () async {
                final db = ref.read(appDatabaseProvider);
                var formattedUsername = usernameCtrl.text.trim();
                if (!formattedUsername.startsWith('@') && formattedUsername.isNotEmpty) {
                  formattedUsername = '@$formattedUsername';
                }
                if (formattedUsername.isEmpty) {
                  formattedUsername = profile.username;
                }
                final updatedDisplayName = nameCtrl.text.trim().isNotEmpty
                    ? nameCtrl.text.trim()
                    : profile.displayName;
                final updatedAvatar = avatarCtrl.text.trim().isNotEmpty
                    ? avatarCtrl.text.trim()
                    : profile.avatarUrl;

                await db.userProfileDao.upsertProfile(
                  UserProfilesCompanion.insert(
                    id: profile.id,
                    username: formattedUsername,
                    displayName: updatedDisplayName,
                    bio: drift.Value(bioCtrl.text.trim()),
                    avatarUrl: drift.Value(updatedAvatar),
                    bannerUrl: drift.Value(profile.bannerUrl),
                    accountType: drift.Value(profile.accountType),
                    isVerifiedBusiness: drift.Value(profile.isVerifiedBusiness),
                    friendCount: drift.Value(profile.friendCount),
                    repCount: drift.Value(profile.repCount),
                    tier: drift.Value(profile.tier),
                    collectionVisibility: drift.Value(selectedVisibility),
                    createdAt: profile.createdAt,
                    updatedAt: drift.Value(DateTime.now()),
                  ),
                );

                if (_isSelf) {
                  final curUser = ref.read(currentUserProvider);
                  ref.read(currentUserProvider.notifier).setUser(
                        curUser.copyWith(
                          displayName: updatedDisplayName,
                          username: formattedUsername,
                          avatarUrl: updatedAvatar,
                        ),
                      );
                }

                // Immediately refresh UI for live profile sync across feed and comments
                ref.invalidate(userProfileProvider(profile.id));
                ref.invalidate(userProfileProvider('me'));
                ref.invalidate(currentUserProfileProvider);
                ref.invalidate(feedPostsStreamProvider);
                ref.invalidate(userWallPostsStreamProvider(profile.id));

                if (dlgContext.mounted) {
                  Navigator.of(dlgContext).pop();
                }
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Profile updated successfully!'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: AppColors.accentEmerald,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentCyan,
                foregroundColor: Colors.black,
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showProposeTradeModal(
    BuildContext context,
    UserProfile partnerProfile, {
    VaultItem? initialPartnerCard,
  }) async {
    final currentUserId = ref.read(currentUserIdProvider);
    final db = ref.read(appDatabaseProvider);
    final myProfile = await db.userProfileDao.getProfile(currentUserId);
    final currentUser = myProfile ??
        UserProfile(
          id: currentUserId,
          username: '@collector_me',
          displayName: 'Me',
          accountType: 'individual',
          isVerifiedBusiness: false,
          friendCount: 0,
          repCount: 0,
          tier: 'collector',
          syncStatus: 'synced',
          collectionVisibility: 'public',
          isDeleted: false,
          createdAt: DateTime.now(),
        );

    if (!context.mounted) return;
    TradeModalSheet.show(
      context,
      currentUser: currentUser,
      partnerProfile: partnerProfile,
      initialPartnerCard: initialPartnerCard,
    );
  }
}

class _ProposeTradeModalSheet extends ConsumerStatefulWidget {
  final UserProfile partnerProfile;

  const _ProposeTradeModalSheet({required this.partnerProfile});

  @override
  ConsumerState<_ProposeTradeModalSheet> createState() =>
      _ProposeTradeModalSheetState();
}

class _ProposeTradeModalSheetState
    extends ConsumerState<_ProposeTradeModalSheet> {
  final Set<String> _selectedTheirCardIds = {};
  final Set<String> _selectedMyCardIds = {};
  final TextEditingController _noteCtrl = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isBiz = widget.partnerProfile.isVerifiedBusiness;
    final partnerBinderType = isBiz ? 'store_inventory' : 'trade_block';

    final theirCardsAsync = ref.watch(
      userSystemBinderCardsProvider(
        (userId: widget.partnerProfile.id, binderType: partnerBinderType),
      ),
    );

    final myCardsAsync = ref.watch(
      userSystemBinderCardsProvider(
        (userId: 'me', binderType: 'trade_block'),
      ),
    );

    return Container(
      key: const Key('propose_trade_modal'),
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.surfaceBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.accentCyan.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.handshake_rounded,
                    color: AppColors.accentCyan,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isBiz ? 'Propose Trade / Buylist Offer' : 'Propose Trade',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.partnerProfile.displayName,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          if (widget.partnerProfile.isVerifiedBusiness) ...[
                            const SizedBox(width: 6),
                            const VerifiedStoreBadge(iconSize: 10, fontSize: 8),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(color: AppColors.surfaceBorder, height: 1),

          // Scrollable Trade Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // SECTION 1: Partner's Cards
                _buildSectionTitle(
                  title: isBiz
                      ? "Store Inventory / Cards Available"
                      : "Cards You Want (${widget.partnerProfile.displayName}'s Trade Block)",
                  icon: Icons.inventory_2_outlined,
                  color: isBiz ? AppColors.accentAmber : AppColors.accentCyan,
                ),
                const SizedBox(height: 8),
                theirCardsAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (e, _) => Text('Error: $e', style: const TextStyle(color: Colors.red)),
                  data: (cards) {
                    if (cards.isEmpty) {
                      return _buildEmptyCardsNotice(
                        'No cards listed in ${widget.partnerProfile.displayName}\'s trade block yet.',
                      );
                    }
                    return _buildCardPickerList(
                      cards: cards,
                      selectedIds: _selectedTheirCardIds,
                      onToggle: (id) {
                        setState(() {
                          if (_selectedTheirCardIds.contains(id)) {
                            _selectedTheirCardIds.remove(id);
                          } else {
                            _selectedTheirCardIds.add(id);
                          }
                        });
                      },
                    );
                  },
                ),
                const SizedBox(height: 20),

                // SECTION 2: User's Cards
                _buildSectionTitle(
                  title: 'Cards You Offer (Your Trade Block & Collection)',
                  icon: Icons.swap_horiz_rounded,
                  color: AppColors.accentEmerald,
                ),
                const SizedBox(height: 8),
                myCardsAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (e, _) => Text('Error: $e', style: const TextStyle(color: Colors.red)),
                  data: (myCards) {
                    return FutureBuilder<List<VaultItem>>(
                      future: myCards.isNotEmpty
                          ? Future.value(myCards)
                          : (ref.read(appDatabaseProvider).select(ref.read(appDatabaseProvider).vaultItems)
                                ..where((t) => t.isDeleted.equals(false) & t.quantity.isBiggerThanValue(0)))
                              .get(),
                      builder: (ctx, snap) {
                        final available = snap.data ?? myCards;
                        if (available.isEmpty) {
                          return _buildEmptyCardsNotice(
                            'Your trade block is currently empty. Add cards to your Trade Block in Vault to offer items!',
                          );
                        }
                        return _buildCardPickerList(
                          cards: available,
                          selectedIds: _selectedMyCardIds,
                          onToggle: (id) {
                            setState(() {
                              if (_selectedMyCardIds.contains(id)) {
                                _selectedMyCardIds.remove(id);
                              } else {
                                _selectedMyCardIds.add(id);
                              }
                            });
                          },
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 20),

                // Trade Notes
                const Text(
                  'Message / Condition Terms (Optional):',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  key: const Key('propose_trade_note_field'),
                  controller: _noteCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'e.g. Willing to add cash or meet at TBS Comics FNM...',
                    hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    filled: true,
                    fillColor: AppColors.surfaceRaised,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.surfaceBorder),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // SUMMARY & ACTION BAR
          _buildTradeSummaryBar(context, theirCardsAsync.valueOrNull ?? const [], myCardsAsync.valueOrNull ?? const []),
        ],
      ),
    );
  }

  Widget _buildSectionTitle({
    required String title,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyCardsNotice(String msg) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Text(
        msg,
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
      ),
    );
  }

  Widget _buildCardPickerList({
    required List<VaultItem> cards,
    required Set<String> selectedIds,
    required ValueChanged<String> onToggle,
  }) {
    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cards.length,
        separatorBuilder: (_, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final card = cards[index];
          final isSelected = selectedIds.contains(card.id);

          return InkWell(
            onTap: () => onToggle(card.id),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 100,
              decoration: BoxDecoration(
                color: AppColors.surfaceRaised,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? AppColors.accentCyan : AppColors.surfaceBorder,
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.accentCyan.withValues(alpha: 0.3),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
                          child: card.imageUrl.isNotEmpty
                              ? CountrCachedImage(imageUrl: card.imageUrl, fit: BoxFit.cover)
                              : Container(
                                  color: AppColors.surface,
                                  child: const Icon(Icons.style_outlined, color: AppColors.textSecondary),
                                ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              card.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              '\$${(card.currentMarketPrice > 0 ? card.currentMarketPrice : card.acquiredPrice).toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.accentEmerald,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.accentCyan : Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isSelected ? Icons.check_rounded : Icons.add_rounded,
                        size: 14,
                        color: isSelected ? Colors.black : Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTradeSummaryBar(
    BuildContext context,
    List<VaultItem> theirCards,
    List<VaultItem> myCards,
  ) {
    double theirTotal = 0;
    for (final c in theirCards) {
      if (_selectedTheirCardIds.contains(c.id)) {
        theirTotal += (c.currentMarketPrice > 0 ? c.currentMarketPrice : c.acquiredPrice);
      }
    }

    double myTotal = 0;
    for (final c in myCards) {
      if (_selectedMyCardIds.contains(c.id)) {
        myTotal += (c.currentMarketPrice > 0 ? c.currentMarketPrice : c.acquiredPrice);
      }
    }

    final delta = myTotal - theirTotal;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.surfaceBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('You Offer:', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    Text(
                      '\$${myTotal.toStringAsFixed(2)} (${_selectedMyCardIds.length} cards)',
                      style: const TextStyle(
                        color: AppColors.accentEmerald,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceRaised,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.surfaceBorder),
                  ),
                  child: Text(
                    delta == 0
                        ? 'Fair Trade'
                        : delta > 0
                            ? '+\$${delta.toStringAsFixed(2)} in your favor'
                            : '-\$${(-delta).toStringAsFixed(2)} in their favor',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: delta.abs() < 5 ? AppColors.accentCyan : AppColors.accentAmber,
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('They Give:', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    Text(
                      '\$${theirTotal.toStringAsFixed(2)} (${_selectedTheirCardIds.length} cards)',
                      style: const TextStyle(
                        color: AppColors.accentCyan,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                key: const Key('propose_trade_submit_button'),
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text(
                  _isSubmitting ? 'Sending Proposal...' : 'Send Trade Proposal',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentCyan,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isSubmitting
                    ? null
                    : () async {
                        setState(() => _isSubmitting = true);
                        try {
                          final currentUserId = ref.read(currentUserIdProvider);
                          await ref.read(inboxDaoProvider).createTradeProposal(
                                proposerId: currentUserId,
                                receiverId: widget.partnerProfile.id,
                                offeredCardIds: _selectedMyCardIds.toList(),
                                requestedCardIds: _selectedTheirCardIds.toList(),
                                offeredTotalValue: myTotal,
                                requestedTotalValue: theirTotal,
                                proposerCashDelta: delta,
                                note: _noteCtrl.text.trim(),
                              );

                          if (context.mounted) {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Trade proposal submitted to ${widget.partnerProfile.displayName}!',
                                ),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: AppColors.accentEmerald,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _isSubmitting = false);
                        }
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
