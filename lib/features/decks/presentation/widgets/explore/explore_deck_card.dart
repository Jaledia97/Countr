import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/constants/app_typography.dart';
import 'package:countr/core/cache/countr_cached_image.dart';
import 'package:countr/features/decks/domain/models/explore_deck_models.dart';
import 'package:countr/features/decks/presentation/providers/explore_deck_providers.dart';
import 'package:countr/features/decks/presentation/screens/read_only_deck_screen.dart';
import 'package:countr/features/decks/presentation/widgets/skeleton_shimmer_box.dart';
import 'package:countr/features/symbology/presentation/widgets/mana_cost_bar.dart';

/// Presentation card for explore decks, featuring commander artwork banner,
/// verified creator badge, mana cost bar, valuation, and interactive voting cluster.
class ExploreDeckCard extends ConsumerWidget {
  final ExploreDeckWithVote deckWithVote;
  final VoidCallback? onTap;
  final bool isCompact;
  final double? width;
  final ExploreDeckCardMatch? cardMatch;

  const ExploreDeckCard({
    super.key,
    required this.deckWithVote,
    this.onTap,
    this.isCompact = false,
    this.width,
    this.cardMatch,
  });

  Widget _buildArtBanner() {
    final artUrl = deckWithVote.commanderArtCrop ?? deckWithVote.commanderImageUrl;
    final bannerHeight = isCompact ? 74.0 : 86.0;

    Widget imageContent;
    if (artUrl != null && artUrl.isNotEmpty) {
      imageContent = CountrCachedImage(
        imageUrl: artUrl,
        cacheKey: 'explore_cover_${deckWithVote.id}',
        cardName: deckWithVote.commanderName ?? deckWithVote.name,
        tcgDomain: deckWithVote.tcgDomain,
        fit: BoxFit.cover,
        placeholder: SkeletonShimmerBox(
          width: double.infinity,
          height: bannerHeight,
          animate: false,
        ),
        errorWidget: _buildFallbackBanner(bannerHeight),
      );
    } else {
      imageContent = _buildFallbackBanner(bannerHeight);
    }

    return Stack(
      children: [
        SizedBox(
          width: double.infinity,
          height: bannerHeight,
          child: imageContent,
        ),
        // Format Pill Overlay
        Positioned(
          top: 5,
          left: 5,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            decoration: BoxDecoration(
              color: AppColors.background.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: AppColors.surfaceBorderSubtle,
                width: 0.5,
              ),
            ),
            child: Text(
              deckWithVote.format,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 8.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFallbackBanner(double height) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.surfaceRaised,
            AppColors.surfaceHighlight,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.auto_awesome_rounded,
          color: AppColors.accentCyan,
          size: 28,
        ),
      ),
    );
  }

  Widget _buildCreatorBadge() {
    final isOfficial = deckWithVote.sourceType == 'official' ||
        deckWithVote.creatorName.toLowerCase().contains('official');

    return Row(
      children: [
        if (isOfficial) ...[
          const Icon(
            Icons.verified_rounded,
            size: 11,
            color: AppColors.accentCyan,
          ),
          const SizedBox(width: 3),
          Expanded(
            child: Text(
              'Official WotC',
              style: AppTypography.caption.copyWith(
                fontSize: 10,
                color: AppColors.accentCyan,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ] else ...[
          Expanded(
            child: Text(
              deckWithVote.creatorName.startsWith('@')
                  ? deckWithVote.creatorName
                  : '@${deckWithVote.creatorName}',
              style: AppTypography.caption.copyWith(
                fontSize: 10,
                color: AppColors.textMuted,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildVotingCluster(WidgetRef ref) {
    final deckId = deckWithVote.id;
    final score = deckWithVote.score;
    final isUpvoted = deckWithVote.isUpvoted;
    final isDownvoted = deckWithVote.isDownvoted;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Upvote
        InkWell(
          key: Key('explore_upvote_$deckId'),
          onTap: () {
            ref.read(exploreDeckDaoProvider).castVote(
                  deckId: deckId,
                  targetVote: 1,
                );
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(
              Icons.arrow_upward_rounded,
              size: 15,
              color: isUpvoted ? AppColors.accentEmerald : AppColors.textMuted,
            ),
          ),
        ),
        // Score Display
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text(
            '$score',
            key: Key('explore_score_$deckId'),
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: isUpvoted
                  ? AppColors.accentEmerald
                  : (isDownvoted ? AppColors.accentAmber : AppColors.textSecondary),
            ),
          ),
        ),
        // Downvote
        InkWell(
          key: Key('explore_downvote_$deckId'),
          onTap: () {
            ref.read(exploreDeckDaoProvider).castVote(
                  deckId: deckId,
                  targetVote: -1,
                );
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(
              Icons.arrow_downward_rounded,
              size: 15,
              color: isDownvoted ? AppColors.accentAmber : AppColors.textMuted,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardContent = Container(
      width: width,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildArtBanner(),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  deckWithVote.name,
                  style: AppTypography.heading2.copyWith(
                    fontSize: 12,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),

                // Creator
                _buildCreatorBadge(),

                // Card match info if search query matched a contained card
                if (cardMatch != null) ...[
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: AppColors.accentCyan.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: AppColors.accentCyan.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      'contains: ${cardMatch!.matchingCardName}',
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: AppColors.accentCyan,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],

                // Color Identity
                if (deckWithVote.colorIdentity.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  ManaCostBar(
                    manaCost: deckWithVote.colorIdentity.map((c) => '{$c}').join(''),
                    symbolSize: 10,
                    spacing: 2,
                  ),
                ],

                const SizedBox(height: 4),

                // Footer: Price + Voting Cluster
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        '\$${deckWithVote.estimatedPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accentEmerald,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 2),
                    _buildVotingCluster(ref),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return RepaintBoundary(
      child: InkWell(
        key: Key('explore_card_${deckWithVote.id}'),
        onTap: onTap ??
            () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ReadOnlyDeckScreen(
                    exploreDeckId: deckWithVote.id,
                  ),
                ),
              );
            },
        borderRadius: BorderRadius.circular(12),
        child: cardContent,
      ),
    );
  }
}
