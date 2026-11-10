import 'package:flutter/material.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/constants/app_typography.dart';
import 'package:countr/core/cache/countr_cached_image.dart';
import 'package:countr/features/decks/domain/models/deck_summary.dart';
import 'package:countr/features/decks/domain/models/my_decks_search_result.dart';
import 'package:countr/features/decks/presentation/widgets/skeleton_shimmer_box.dart';
import 'package:countr/features/symbology/presentation/widgets/mana_cost_bar.dart';

/// Presentation card for a personal deck in "My Decks", featuring assembly status badges,
/// 3-dot overflow actions ("Share to Explore"), multi-selection checkbox, and card match chips.
class MyDeckCard extends StatelessWidget {
  final DeckSummary deck;
  final bool isSelectionMode;
  final bool isSelected;
  final ValueChanged<bool?>? onSelectedChanged;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final ValueChanged<DeckSummary>? onShareToExplore;
  final MyDeckCardMatch? cardMatch;

  const MyDeckCard({
    super.key,
    required this.deck,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onSelectedChanged,
    this.onTap,
    this.onLongPress,
    this.onShareToExplore,
    this.cardMatch,
  });

  String? _resolveCommanderArtUrl() {
    final rawUrl = deck.commanderArtCrop ?? deck.commanderImageUrl;
    if (rawUrl == null || rawUrl.isEmpty) return null;
    final isArtSeries = rawUrl.contains('art_series');
    final cmdr = deck.commanderName ?? deck.name;
    final hasIdenticalFaces = cmdr.contains('//') &&
        cmdr.split('//')[0].trim().toLowerCase() ==
            cmdr.split('//')[1].trim().toLowerCase();
    final hasArtSeriesName = cmdr.toLowerCase().contains('art card') ||
        cmdr.toLowerCase().contains('art series') ||
        hasIdenticalFaces;

    if (isArtSeries || hasArtSeriesName) {
      String clean = cmdr.contains('//') ? cmdr.split('//').first.trim() : cmdr.trim();
      clean = clean
          .replaceAll(RegExp(r'\s*\((?:Art Card|Art Series)\)', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s*-\s*(?:Art Card|Art Series)', caseSensitive: false), '')
          .trim();
      return CountrCachedImage.buildScryfallNamedUrl(clean, version: 'art_crop');
    }
    return rawUrl;
  }

  Widget _buildCommanderCardArt() {
    final artUrl = _resolveCommanderArtUrl();
    if (artUrl != null && artUrl.isNotEmpty) {
      final isFallback = artUrl.contains('api.scryfall.com/cards/named');
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 44,
          height: 56,
          color: AppColors.surfaceRaised,
          child: CountrCachedImage(
            imageUrl: artUrl,
            cacheKey: isFallback ? 'deck_cover_${deck.id}_fallback' : 'deck_cover_${deck.id}',
            cardName: deck.commanderName ?? deck.name,
            tcgDomain: deck.tcgDomain,
            fit: BoxFit.cover,
            width: 44,
            height: 56,
            placeholder: const SkeletonShimmerBox(
              width: 44,
              height: 56,
              animate: false,
            ),
            errorWidget: _buildFallbackArt(),
          ),
        ),
      );
    }
    return _buildFallbackArt();
  }

  Widget _buildFallbackArt() {
    return Container(
      width: 44,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: const LinearGradient(
          colors: [
            AppColors.surfaceRaised,
            AppColors.surfaceHighlight,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: AppColors.accentViolet.withValues(alpha: 0.5),
        ),
      ),
      child: const Icon(
        Icons.style_rounded,
        color: AppColors.accentVioletLight,
        size: 24,
      ),
    );
  }

  Widget _buildColorPips() {
    if (deck.colorIdentity.isNotEmpty && deck.tcgDomain == 'mtg') {
      final manaCost = deck.colorIdentity.map((c) => '{$c}').join('');
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: ManaCostBar(
          manaCost: manaCost,
          symbolSize: 12,
          spacing: 2,
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildAssemblyStatusPill() {
    final Color badgeColor;
    final Color textColor;
    final IconData icon;

    switch (deck.assemblyStatus) {
      case 'Assembled':
        badgeColor = AppColors.accentEmerald.withValues(alpha: 0.15);
        textColor = AppColors.accentEmerald;
        icon = Icons.verified_rounded;
        break;
      case 'Ready':
        badgeColor = AppColors.accentCyan.withValues(alpha: 0.15);
        textColor = AppColors.accentCyan;
        icon = Icons.check_circle_outline_rounded;
        break;
      case 'Draft':
      default:
        badgeColor = AppColors.surfaceRaised;
        textColor = AppColors.accentAmber;
        icon = Icons.edit_note_rounded;
        break;
    }

    return Container(
      key: Key('deck_assembly_status_${deck.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: textColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: textColor),
          const SizedBox(width: 3),
          Text(
            deck.assemblyStatus,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w700,
              fontSize: 9.5,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardCountDisplay = '${deck.cardCount}/${deck.targetCardCount}';

    return RepaintBoundary(
      child: InkWell(
        key: Key('deck_item_${deck.id}'),
        onTap: () {
          if (isSelectionMode) {
            onSelectedChanged?.call(!isSelected);
          } else {
            onTap?.call();
          }
        },
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.accentCyan.withValues(alpha: 0.08)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? AppColors.accentCyan
                  : AppColors.surfaceBorder,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              // Selection Checkbox
              if (isSelectionMode) ...[
                Checkbox(
                  key: Key('deck_checkbox_${deck.id}'),
                  value: isSelected,
                  activeColor: AppColors.accentCyan,
                  checkColor: AppColors.textDark,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: onSelectedChanged,
                ),
                const SizedBox(width: 8),
              ],

              // Commander Card Artwork / Archetype Icon with Skeleton Shimmer
              _buildCommanderCardArt(),
              const SizedBox(width: 14),

              // Title, Format, Relocated Assembly Status & Inline Color Pips
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Full deck name spanning available horizontal width (maxLines: 2)
                    Text(
                      deck.name,
                      style: AppTypography.heading2.copyWith(fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Secondary metadata row with format, card count, and relocated status badge
                    Row(
                      children: [
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '${deck.format} • $cardCountDisplay',
                              style: AppTypography.caption,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: _buildAssemblyStatusPill(),
                          ),
                        ),
                      ],
                    ),
                    _buildColorPips(),

                    // Matched card chip indicator (for search view)
                    if (cardMatch != null) ...[
                      const SizedBox(height: 4),
                      Container(
                        key: Key('deck_card_match_chip_${deck.id}'),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accentCyan.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppColors.accentCyan.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.style_outlined,
                              size: 11,
                              color: AppColors.accentCyan,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Contains: ${cardMatch!.matchingCardName} (x${cardMatch!.cardQuantity})',
                                style: const TextStyle(
                                  color: AppColors.accentCyan,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 4),

              // 3-Dot Overflow Menu
              PopupMenuButton<String>(
                key: Key('deck_card_menu_${deck.id}'),
                tooltip: 'Deck options',
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: AppColors.textMuted,
                  size: 20,
                ),
                color: AppColors.surfaceRaised,
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppColors.surfaceBorder),
                ),
                onSelected: (value) {
                  if (value == 'share_explore') {
                    onShareToExplore?.call(deck);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem<String>(
                    key: Key('deck_menu_share_explore_${deck.id}'),
                    value: 'share_explore',
                    child: const Row(
                      children: [
                        Icon(
                          Icons.share_rounded,
                          color: AppColors.accentCyan,
                          size: 18,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Share to Explore',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
