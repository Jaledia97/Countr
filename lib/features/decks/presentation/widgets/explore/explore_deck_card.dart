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
import 'package:countr/features/profile/presentation/providers/profile_providers.dart';
import 'package:countr/features/decks/presentation/widgets/explore/explore_deck_unpublish_dialog.dart';

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

  Widget _buildArtBanner(BuildContext context, WidgetRef ref) {
    String currentUserId = 'user-current-me';
    try {
      currentUserId = ref.watch(currentUserIdProvider);
    } catch (_) {
      // Fallback for tests rendering widget outside ProviderScope
    }
    final isAuthor = isExploreDeckAuthor(
      deck: deckWithVote.deck,
      currentUserId: currentUserId,
    );
    final hasImageUrl = deckWithVote.commanderImageUrl != null &&
        deckWithVote.commanderImageUrl!.isNotEmpty;
    final hasArtCrop = deckWithVote.commanderArtCrop != null &&
        deckWithVote.commanderArtCrop!.isNotEmpty;

    // Prioritize full card image (commanderImageUrl / normal) over cropped art (commanderArtCrop)
    final rawCardUrl = hasImageUrl
        ? deckWithVote.commanderImageUrl
        : (hasArtCrop ? deckWithVote.commanderArtCrop : null);

    Widget imageContent;
    if (rawCardUrl != null) {
      final isArtSeries = rawCardUrl.contains('art_series');
      final isEmptyUrl = rawCardUrl.isEmpty;
      final isArtCropInFullFrame = hasImageUrl && rawCardUrl.contains('/art_crop/');
      final commander = deckWithVote.commanderName ?? deckWithVote.name;
      final hasIdenticalFaces = commander.contains('//') &&
          commander.split('//')[0].trim().toLowerCase() ==
              commander.split('//')[1].trim().toLowerCase();
      final hasArtSeriesName = commander.toLowerCase().contains('art card') ||
          commander.toLowerCase().contains('art series') ||
          hasIdenticalFaces;
      String resolvedCardUrl = rawCardUrl;
      String cacheKey = 'explore_cover_${deckWithVote.id}';

      if (isArtSeries || isEmptyUrl || isArtCropInFullFrame || hasArtSeriesName) {
        if (commander.isNotEmpty && commander != 'Unknown Card') {
          String clean = commander;
          if (clean.contains('//')) {
            final parts = clean.split('//').map((p) => p.trim()).toList();
            clean = (parts.length >= 2 && parts[0].toLowerCase() == parts[1].toLowerCase())
                ? parts[0]
                : parts.first;
          }
          clean = clean.replaceAll(RegExp(r'\s*\((?:Art Card|Art Series)\)', caseSensitive: false), '').trim();
          final fallbackVersion = (!hasImageUrl && hasArtCrop) ? 'art_crop' : 'normal';
          resolvedCardUrl = CountrCachedImage.buildScryfallNamedUrl(clean, version: fallbackVersion);
          cacheKey = 'explore_cover_${deckWithVote.id}_fallback';
        } else {
          resolvedCardUrl = '';
        }
      }

      final fallbackVersion = (!hasImageUrl && hasArtCrop) ? 'art_crop' : 'normal';

      if (resolvedCardUrl.isNotEmpty) {
        imageContent = CountrCachedImage(
          imageUrl: resolvedCardUrl,
          cacheKey: cacheKey,
          cardName: deckWithVote.commanderName ?? deckWithVote.name,
          tcgDomain: deckWithVote.tcgDomain,
          fit: BoxFit.contain,
          fallbackVersion: fallbackVersion,
          placeholder: const AspectRatio(
            aspectRatio: 63.0 / 88.0,
            child: SkeletonShimmerBox(
              width: double.infinity,
              height: double.infinity,
              animate: false,
            ),
          ),
          errorWidget: _buildFallbackBanner(),
        );
      } else {
        imageContent = _buildFallbackBanner();
      }
    } else {
      imageContent = _buildFallbackBanner();
    }

    return Stack(
      children: [
        AspectRatio(
          aspectRatio: 63.0 / 88.0,
          child: imageContent,
        ),
        // Format Pill Overlay in top-left outer margin
        Positioned(
          top: 6,
          left: 6,
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
        // 3-Dot Overflow Menu for Author in top-right
        if (isAuthor)
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.surfaceBorderSubtle,
                  width: 0.5,
                ),
              ),
              child: PopupMenuButton<String>(
                key: Key('explore_card_menu_${deckWithVote.id}'),
                tooltip: 'Deck options',
                padding: EdgeInsets.zero,
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: Colors.white,
                  size: 16,
                ),
                color: AppColors.surfaceRaised,
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppColors.surfaceBorder),
                ),
                onSelected: (value) {
                  if (value == 'unpublish') {
                    showExploreDeckUnpublishWorkflow(
                      context: context,
                      ref: ref,
                      deck: deckWithVote.deck,
                      popOnSuccess: false,
                    );
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem<String>(
                    key: Key('explore_card_menu_unpublish_${deckWithVote.id}'),
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
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFallbackBanner([double? height]) {
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

    final upvoteKey = isCompact
        ? Key('explore_carousel_upvote_$deckId')
        : Key('explore_upvote_$deckId');
    final downvoteKey = isCompact
        ? Key('explore_carousel_downvote_$deckId')
        : Key('explore_downvote_$deckId');
    final scoreKey = isCompact
        ? Key('explore_carousel_score_$deckId')
        : Key('explore_score_$deckId');

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Upvote
        InkWell(
          key: upvoteKey,
          onTap: () {
            ref.read(exploreDeckDaoProvider).castVote(
                  deckId: deckId,
                  targetVote: 1,
                );
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
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
            key: scoreKey,
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
          key: downvoteKey,
          onTap: () {
            ref.read(exploreDeckDaoProvider).castVote(
                  deckId: deckId,
                  targetVote: -1,
                );
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
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
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);

    final cardContent = LayoutBuilder(
      builder: (context, constraints) {
        final hasBoundedHeight = constraints.hasBoundedHeight;
        final effectiveWidth = width ??
            (hasBoundedHeight &&
                    constraints.maxWidth.isFinite &&
                    constraints.maxWidth > (constraints.maxHeight * (63.0 / 88.0))
                ? (constraints.maxHeight * 0.54)
                : null);
        final availableWidth = ((effectiveWidth ??
                    (constraints.maxWidth.isFinite
                        ? constraints.maxWidth
                        : (width ?? 173.0))) -
                18)
            .clamp(100.0, double.infinity);

        final detailsColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
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
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '\$${deckWithVote.estimatedPrice.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accentEmerald,
                      ),
                      maxLines: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                Flexible(
                  fit: FlexFit.loose,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: _buildVotingCluster(ref),
                  ),
                ),
              ],
            ),
          ],
        );

        final detailsWidget = hasBoundedHeight
            ? Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: isCompact ? (textScale > 1.2 ? 3.0 : 5.0) : 6.0,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.topLeft,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: availableWidth,
                      ),
                      child: detailsColumn,
                    ),
                  ),
                ),
              )
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: detailsColumn,
              );

        return Container(
          width: effectiveWidth,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.surfaceBorder),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: hasBoundedHeight ? MainAxisSize.max : MainAxisSize.min,
            children: [
              _buildArtBanner(context, ref),
              detailsWidget,
            ],
          ),
        );
      },
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
