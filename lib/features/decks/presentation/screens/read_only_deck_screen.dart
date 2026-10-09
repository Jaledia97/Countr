import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/constants/app_typography.dart';
import 'package:countr/core/cache/countr_cached_image.dart';
import 'package:countr/core/cache/parsed_json_cache.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/domain/models/explore_deck_models.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/decks/presentation/providers/explore_deck_providers.dart';
import 'package:countr/features/decks/presentation/widgets/skeleton_shimmer_box.dart';
import 'package:countr/features/symbology/presentation/widgets/mana_cost_bar.dart';

/// Read-Only Deck View Screen for explore precons and community decks.
///
/// Strictly hides all deck editing/mutation controls while exposing real-time
/// persistent voting, card categorization by MTG card types, and the
/// "Add to My Decks" (Clone) engine.
class ReadOnlyDeckScreen extends ConsumerStatefulWidget {
  final String exploreDeckId;

  ReadOnlyDeckScreen({
    super.key,
    String? exploreDeckId,
    String? deckId,
  })  : exploreDeckId = exploreDeckId ??
            deckId ??
            (throw ArgumentError('exploreDeckId or deckId must be provided'));

  @override
  ConsumerState<ReadOnlyDeckScreen> createState() => _ReadOnlyDeckScreenState();
}

class _ReadOnlyDeckScreenState extends ConsumerState<ReadOnlyDeckScreen> {
  final Map<String, bool> _expandedSections = {
    'Commander': true,
    'Creatures': true,
    'Instants & Sorceries': true,
    'Artifacts & Enchantments': true,
    'Lands': true,
    'Sideboard': true,
  };

  bool _isCloning = false;

  Map<String, List<ExploreDeckItem>> _partitionCards(List<ExploreDeckItem> cards) {
    final result = <String, List<ExploreDeckItem>>{
      'Commander': [],
      'Creatures': [],
      'Instants & Sorceries': [],
      'Artifacts & Enchantments': [],
      'Lands': [],
      'Sideboard': [],
    };

    for (final item in cards) {
      if (item.isCommander || item.boardZone.toLowerCase() == 'commander') {
        result['Commander']!.add(item);
        continue;
      }

      if (item.boardZone.toLowerCase() == 'sideboard') {
        result['Sideboard']!.add(item);
        continue;
      }

      final type = (item.typeLine ?? '').toLowerCase();
      if (type.contains('creature')) {
        result['Creatures']!.add(item);
      } else if (type.contains('instant') || type.contains('sorcery')) {
        result['Instants & Sorceries']!.add(item);
      } else if (type.contains('artifact') ||
          type.contains('enchantment') ||
          type.contains('planeswalker') ||
          type.contains('battle')) {
        result['Artifacts & Enchantments']!.add(item);
      } else if (type.contains('land')) {
        result['Lands']!.add(item);
      } else {
        // Fallback: If no type match, check mana cost
        if (item.manaCost == null || item.manaCost!.isEmpty) {
          result['Lands']!.add(item);
        } else {
          result['Artifacts & Enchantments']!.add(item);
        }
      }
    }

    return result;
  }

  Future<void> _cloneDeck(ExploreDeck deck) async {
    if (_isCloning) return;
    setState(() => _isCloning = true);

    try {
      final dao = ref.read(exploreDeckDaoProvider);
      await dao.cloneExploreDeckToPersonal(exploreDeckId: deck.id);

      // Invalidate personal deck stream providers
      ref.invalidate(deckListProvider);
      ref.invalidate(deckSummariesProvider);
      ref.invalidate(myDecksCombinedSummariesProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cloned "${deck.name}" to My Decks!'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.surfaceRaised,
            action: SnackBarAction(
              label: 'View in My Decks',
              textColor: AppColors.accentCyan,
              onPressed: () {
                ref.read(decksTopTabProvider.notifier).state = 0;
                Navigator.of(context).pop();
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to clone deck: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.surfaceRaised,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCloning = false);
      }
    }
  }

  Widget _buildArtBanner(ExploreDeck deck) {
    final rawArtUrl = deck.commanderArtCrop ?? deck.commanderImageUrl;
    const bannerHeight = 180.0;

    Widget imageContent;
    if (rawArtUrl != null) {
      final isArtSeries = rawArtUrl.contains('art_series');
      final isEmptyUrl = rawArtUrl.isEmpty;
      String resolvedArtUrl = rawArtUrl;
      String cacheKey = 'explore_cover_${deck.id}';

      if (isArtSeries || isEmptyUrl) {
        final commander = deck.commanderName ?? deck.name;
        if (commander.isNotEmpty && commander != 'Unknown Card') {
          final clean = commander.contains('//') ? commander.split('//').first.trim() : commander.trim();
          resolvedArtUrl = CountrCachedImage.buildScryfallNamedUrl(clean, version: 'art_crop');
          cacheKey = 'explore_cover_${deck.id}_fallback';
        } else {
          resolvedArtUrl = '';
        }
      }

      if (resolvedArtUrl.isNotEmpty) {
        imageContent = CountrCachedImage(
          imageUrl: resolvedArtUrl,
          cacheKey: cacheKey,
          cardName: deck.commanderName ?? deck.name,
          tcgDomain: deck.tcgDomain,
          fit: BoxFit.cover,
          placeholder: const SkeletonShimmerBox(
            width: double.infinity,
            height: bannerHeight,
            animate: false,
          ),
          errorWidget: _buildFallbackBanner(bannerHeight),
        );
      } else {
        imageContent = _buildFallbackBanner(bannerHeight);
      }
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
        // Gradient overlay for readability
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withValues(alpha: 0.6),
                  Colors.transparent,
                  AppColors.background.withValues(alpha: 0.8),
                  AppColors.background,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.3, 0.8, 1.0],
              ),
            ),
          ),
        ),
        // Format Pill Overlay
        Positioned(
          top: 12,
          right: 14,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
            decoration: BoxDecoration(
              color: AppColors.background.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: AppColors.surfaceBorderSubtle,
                width: 0.8,
              ),
            ),
            child: Text(
              deck.format,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
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
          size: 40,
        ),
      ),
    );
  }

  Widget _buildCreatorBadge(ExploreDeck deck) {
    final isOfficial = deck.sourceType == 'official' ||
        deck.creatorName.toLowerCase().contains('official');

    if (isOfficial) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.verified_rounded,
            size: 13,
            color: AppColors.accentCyan,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              'Official WotC',
              style: AppTypography.caption.copyWith(
                fontSize: 11.5,
                color: AppColors.accentCyan,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      );
    } else {
      final name = deck.creatorName.startsWith('@')
          ? deck.creatorName
          : '@${deck.creatorName}';
      return Text(
        name,
        style: AppTypography.caption.copyWith(
          fontSize: 11.5,
          color: AppColors.textMuted,
          fontWeight: FontWeight.w500,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      );
    }
  }

  Widget _buildVotingCluster(ExploreDeckWithVote deckWithVote) {
    final deckId = deckWithVote.id;
    final score = deckWithVote.score;
    final isUpvoted = deckWithVote.isUpvoted;
    final isDownvoted = deckWithVote.isDownvoted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.surfaceBorderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: Key('read_only_upvote_$deckId'),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: Icon(
              Icons.arrow_upward_rounded,
              size: 18,
              color: isUpvoted ? AppColors.accentEmerald : AppColors.textMuted,
            ),
            onPressed: () {
              ref.read(exploreDeckDaoProvider).castVote(
                    deckId: deckId,
                    targetVote: 1,
                  );
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '$score',
              key: Key('read_only_score_$deckId'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: isUpvoted
                    ? AppColors.accentEmerald
                    : (isDownvoted ? AppColors.accentAmber : AppColors.textPrimary),
              ),
            ),
          ),
          IconButton(
            key: Key('read_only_downvote_$deckId'),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: Icon(
              Icons.arrow_downward_rounded,
              size: 18,
              color: isDownvoted ? AppColors.accentAmber : AppColors.textMuted,
            ),
            onPressed: () {
              ref.read(exploreDeckDaoProvider).castVote(
                    deckId: deckId,
                    targetVote: -1,
                  );
            },
          ),
        ],
      ),
    );
  }

  static bool _isArtSeriesCard(ExploreDeckItem card) {
    final nameLower = card.cardName.toLowerCase();
    if (nameLower.contains('art series') || nameLower.contains('art card')) {
      return true;
    }
    final typeLower = (card.typeLine ?? '').toLowerCase();
    if (typeLower.contains('art series') || typeLower.contains('art card')) {
      return true;
    }
    final imgUrl = card.imageUrl;
    if (imgUrl != null && imgUrl.contains('art_series')) {
      return true;
    }
    final artCrop = card.artCropUrl;
    if (artCrop != null && artCrop.contains('art_series')) {
      return true;
    }
    final dynStr = card.dynamicData;
    if (dynStr != null && dynStr.isNotEmpty) {
      try {
        final dynData = ParsedJsonCache.parse(dynStr);
        if (dynData.isNotEmpty) {
          final dynLayout = dynData['layout']?.toString().toLowerCase();
          if (dynLayout == 'art_series') return true;
          final dynType = dynData['type_line']?.toString().toLowerCase() ?? '';
          if (dynType.contains('art series') || dynType.contains('art card')) return true;
          final dynName = dynData['name']?.toString().toLowerCase() ?? '';
          if (dynName.contains('art series') || dynName.contains('art card')) return true;
          final setCode = dynData['set']?.toString().toLowerCase();
          if (setCode != null &&
              setCode.length >= 4 &&
              setCode.startsWith('a') &&
              RegExp(r'^a[a-z0-9]{3,4}$').hasMatch(setCode)) {
            return true;
          }
          if (dynData['image_uris'] is Map) {
            final uris = dynData['image_uris'] as Map;
            for (final u in uris.values) {
              if (u != null && u.toString().contains('art_series')) return true;
            }
          }
        }
      } catch (_) {
        if (dynStr.contains('"layout":"art_series"') ||
            dynStr.contains('"layout": "art_series"') ||
            dynStr.contains('art_series')) {
          return true;
        }
      }
    }
    return false;
  }

  static String _resolveCardThumbnailUrl(ExploreDeckItem card) {
    final isArtSeries = _isArtSeriesCard(card);
    final rawUrl = card.imageUrl?.trim() ?? '';
    String resolvedUrl = isArtSeries ? '' : rawUrl;

    if (!isArtSeries && (resolvedUrl.contains('/back.jpg') || resolvedUrl.contains('/art_crop/'))) {
      resolvedUrl = '';
    }

    if (!isArtSeries && resolvedUrl.isEmpty && card.dynamicData != null && card.dynamicData!.isNotEmpty) {
      try {
        final dynData = ParsedJsonCache.parse(card.dynamicData!);
        if (dynData['image_uris'] is Map) {
          final uris = dynData['image_uris'] as Map;
          final u = uris['normal'] ?? uris['large'] ?? uris['small'];
          if (u != null && u.toString().isNotEmpty && !u.toString().contains('/back.jpg')) {
            resolvedUrl = u.toString();
          }
        }
      } catch (_) {}
    }

    if (resolvedUrl.isEmpty && card.cardName.isNotEmpty && card.cardName != 'Unknown Card') {
      String cleanName = card.cardName;
      cleanName = cleanName.contains('//') ? cleanName.split('//').first.trim() : cleanName.trim();
      cleanName = cleanName
          .replaceAll(RegExp(r'\s*\((?:Art Card|Art Series)\)', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s*-\s*(?:Art Card|Art Series)', caseSensitive: false), '')
          .trim();
      resolvedUrl = CountrCachedImage.buildScryfallNamedUrl(cleanName, version: 'normal');
    }

    return resolvedUrl;
  }

  Widget _buildCardThumbnail(ExploreDeckItem card) {
    final isArtSeries = _isArtSeriesCard(card);
    final resolvedUrl = _resolveCardThumbnailUrl(card);
    final cacheKey = card.id.isNotEmpty
        ? (isArtSeries ? 'explore_item_${card.id}_fallback' : 'explore_item_${card.id}')
        : null;

    return Container(
      width: 40,
      height: 56,
      decoration: const BoxDecoration(
        color: AppColors.surfaceRaised,
      ),
      clipBehavior: Clip.antiAlias,
      child: (resolvedUrl.isNotEmpty || (card.cardName.isNotEmpty && card.cardName != 'Unknown Card'))
          ? CountrCachedImage(
              imageUrl: resolvedUrl,
              cacheKey: cacheKey,
              cardName: card.cardName,
              width: 40,
              height: 56,
              fit: BoxFit.cover,
              fallbackVersion: 'normal',
              errorWidget: Container(
                color: AppColors.surfaceRaised,
                child: const Center(
                  child: Icon(Icons.style_outlined, size: 16, color: AppColors.textMuted),
                ),
              ),
            )
          : Container(
              color: AppColors.surfaceRaised,
              child: const Center(
                child: Icon(Icons.style_outlined, size: 16, color: AppColors.textMuted),
              ),
            ),
    );
  }

  Widget _buildCardRow(ExploreDeckItem card) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: Row(
        children: [
          // Quantity
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.surfaceRaised,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.surfaceBorderSubtle, width: 0.5),
            ),
            child: Text(
              '${card.quantity}x',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.accentCyan,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Thumbnail
          _buildCardThumbnail(card),
          const SizedBox(width: 10),
          // Card Name
          Expanded(
            child: Text(
              card.cardName,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (card.manaCost != null && card.manaCost!.isNotEmpty) ...[
            const SizedBox(width: 8),
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 80.0),
                child: ManaCostBar(
                  manaCost: card.manaCost!,
                  symbolSize: 12,
                  spacing: 2,
                ),
              ),
            ),
          ],
          // Card Price
          if (card.price != null && card.price! > 0) ...[
            const SizedBox(width: 8),
            Text(
              '\$${(card.price! * card.quantity).toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCardSection({
    required Key key,
    required String title,
    required List<ExploreDeckItem> items,
  }) {
    final totalCount = items.fold<int>(0, (sum, i) => sum + i.quantity);
    final isExpanded = _expandedSections[title] ?? true;

    return Container(
      key: key,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header (Expandable toggle)
          InkWell(
            onTap: () {
              setState(() {
                _expandedSections[title] = !isExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '$title ($totalCount)',
                      style: AppTypography.heading2.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1, color: AppColors.surfaceBorder),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(
                height: 1,
                color: AppColors.surfaceBorderSubtle,
              ),
              itemBuilder: (context, index) {
                final card = items[index];
                return _buildCardRow(card);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStickyBottomBar(ExploreDeck deck) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(
          top: BorderSide(color: AppColors.surfaceBorder),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton.icon(
            key: const Key('explore_clone_deck_button'),
            onPressed: _isCloning ? null : () => _cloneDeck(deck),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accentCyan,
              foregroundColor: Colors.black,
              disabledBackgroundColor: AppColors.accentCyan.withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            icon: _isCloning
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  )
                : const Icon(Icons.library_add_rounded, size: 20),
            label: Text(_isCloning ? 'Cloning Deck...' : 'Add to My Decks'),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(exploreDeckDetailStreamProvider(widget.exploreDeckId));

    return Scaffold(
      key: const Key('read_only_deck_screen'),
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: detailAsync.maybeWhen(
          data: (detail) => detail != null
              ? Text(
                  detail.deck.name,
                  style: AppTypography.heading2.copyWith(fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              : null,
          orElse: () => null,
        ),
      ),
      body: detailAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accentCyan),
        ),
        error: (err, _) => Center(
          child: Text(
            'Error loading deck: $err',
            style: const TextStyle(color: Colors.red),
          ),
        ),
        data: (detail) {
          if (detail == null) {
            return const Center(
              child: Text(
                'Deck not found',
                style: TextStyle(color: AppColors.textMuted),
              ),
            );
          }

          final deckWithVote = detail.deckWithVote;
          final deck = deckWithVote.deck;
          final partitioned = _partitionCards(detail.cards);

          const sectionConfigs = [
            (title: 'Commander', key: Key('read_only_section_commander')),
            (title: 'Creatures', key: Key('read_only_section_creatures')),
            (title: 'Instants & Sorceries', key: Key('read_only_section_spells')),
            (title: 'Artifacts & Enchantments', key: Key('read_only_section_permanents')),
            (title: 'Lands', key: Key('read_only_section_lands')),
            (title: 'Sideboard', key: Key('read_only_section_sideboard')),
          ];

          return SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Commander Art Banner with Format Overlay
                _buildArtBanner(deck),

                // Deck Overview Card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title & Badges
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  deck.name,
                                  style: AppTypography.heading1.copyWith(
                                    fontSize: 18,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                _buildCreatorBadge(deck),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Interactive Voting Cluster
                          _buildVotingCluster(deckWithVote),
                        ],
                      ),

                      // Description
                      if (deck.description != null && deck.description!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.surfaceBorder),
                          ),
                          child: Text(
                            deck.description!,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 11.5,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 10),

                      // Metadata stats: Total card count and estimated price
                      Row(
                        children: [
                          // Card count
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3.5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceRaised,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${deck.cardCount} Cards',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Estimated price
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3.5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accentEmerald.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: AppColors.accentEmerald.withValues(alpha: 0.3),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              '\$${deck.estimatedPrice.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.accentEmerald,
                              ),
                            ),
                          ),
                          if (deckWithVote.colorIdentity.isNotEmpty) ...[
                            const SizedBox(width: 10),
                            ManaCostBar(
                              manaCost: deckWithVote.colorIdentity
                                  .map((c) => '{$c}')
                                  .join(''),
                              symbolSize: 12,
                              spacing: 2,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 6),

                // Partitioned Card Sections by MTG Card Type
                for (final config in sectionConfigs)
                  if ((partitioned[config.title] ?? []).isNotEmpty)
                    _buildCardSection(
                      key: config.key,
                      title: config.title,
                      items: partitioned[config.title]!,
                    ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: detailAsync.maybeWhen(
        data: (detail) => detail != null ? _buildStickyBottomBar(detail.deck) : null,
        orElse: () => null,
      ),
    );
  }
}
