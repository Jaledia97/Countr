import 'package:flutter/material.dart';
import '../../../../core/cache/countr_cached_image.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../symbology/presentation/widgets/mana_text.dart';
import '../../../vault/presentation/widgets/card_detail_sheet.dart';
import '../../../vault/presentation/widgets/expanded_card_view_modal.dart';

/// Body for Multi-Pull Post variant.
/// Displays optional commentary and either a 3-card combo row or a 2x2 grid of cards.
/// Each card is individually tappable to open [CardDetailSheet].
class MultiPullPostBody extends StatelessWidget {
  final String? commentary;
  final List<String> pullItems;
  final List<String>? pullCardIds;
  final VoidCallback? onSeeMoreTap;
  final void Function(int index, String cardId)? onCardTap;
  final bool? useLightbox;

  const MultiPullPostBody({
    super.key,
    this.commentary,
    required this.pullItems,
    this.pullCardIds,
    this.onSeeMoreTap,
    this.onCardTap,
    this.useLightbox,
  });

  bool get _isThreeCardCombo => pullItems.length == 3;

  void _openLightbox(BuildContext context, int initialIndex) {
    final totalCards = _isThreeCardCombo ? 3 : 4;
    final allCardIds = List<String>.generate(totalCards, (i) {
      if (pullCardIds != null && pullCardIds!.length > i) {
        return pullCardIds![i];
      }
      if (_isThreeCardCombo) {
        return i == 0
            ? 'item-card-urza-high-artificer'
            : (i == 1
                ? 'item-card-isochron-scepter'
                : 'item-card-dramatic-reversal');
      }
      return i == 0 ? 'item-mtg-one-ring' : 'item-mtg-sol-ring';
    });

    final allItems = List<String>.from(pullItems);
    while (allItems.length < totalCards) {
      allItems.add('Secret Rare Hit #${allItems.length + 1}');
    }

    final allImageUrls = allItems.map((it) {
      final isUrl = it.startsWith('http://') ||
          it.startsWith('https://') ||
          it.contains('cards.scryfall.io') ||
          it.contains('.jpg') ||
          it.contains('.png');
      return isUrl ? it : '';
    }).toList();

    final allTitles = allItems.map((it) {
      final isUrl = it.startsWith('http://') ||
          it.startsWith('https://') ||
          it.contains('cards.scryfall.io');
      return isUrl ? null : it;
    }).toList();

    ExpandedCardViewModal.show(
      context,
      cardIds: allCardIds,
      imageUrls: allImageUrls,
      cardTitles: allTitles.whereType<String>().isNotEmpty
          ? allTitles.map((t) => t ?? '').toList()
          : null,
      initialIndex: initialIndex,
    );
  }

  void _handleDefaultCardTap(BuildContext context, int index, String resolvedCardId) {
    if (useLightbox == true) {
      _openLightbox(context, index);
    } else {
      CardDetailSheet.show(context, resolvedCardId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (commentary != null && commentary!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
            child: ManaText(
              commentary!,
              style: AppTypography.body.copyWith(fontSize: 14, height: 1.4),
            ),
          ),

        if (_isThreeCardCombo)
          _buildThreeCardRow(context)
        else
          _buildTwoByTwoGrid(context),

        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildThreeCardRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: List.generate(3, (index) {
          final resolvedCardId =
              (pullCardIds != null && pullCardIds!.length > index)
              ? pullCardIds![index]
              : (index == 0
                    ? 'item-card-urza-high-artificer'
                    : (index == 1
                          ? 'item-card-isochron-scepter'
                          : 'item-card-dramatic-reversal'));
          final item = pullItems[index];

          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                left: index == 0 ? 0 : 4,
                right: index == 2 ? 0 : 4,
              ),
              child: AspectRatio(
                aspectRatio: 63 / 88,
                child: _GridCardPlaceholder(
                  index: index,
                  title: item,
                  isFourth: false,
                  cardId: resolvedCardId,
                  onTap: () {
                    if (onCardTap != null) {
                      onCardTap!(index, resolvedCardId);
                    } else {
                      _handleDefaultCardTap(context, index, resolvedCardId);
                    }
                  },
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTwoByTwoGrid(BuildContext context) {
    final items = List<String>.from(pullItems);
    while (items.length < 4) {
      items.add('Secret Rare Hit #${items.length + 1}');
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: AspectRatio(
          aspectRatio: 1.0,
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 5,
              mainAxisSpacing: 5,
            ),
            itemCount: 4,
            itemBuilder: (context, index) {
              final title = items[index];
              final isFourth = index == 3;
              final resolvedCardId =
                  (pullCardIds != null && pullCardIds!.length > index)
                  ? pullCardIds![index]
                  : (index == 0 ? 'item-mtg-one-ring' : 'item-mtg-sol-ring');

              return _GridCardPlaceholder(
                index: index,
                title: title,
                isFourth: isFourth,
                cardId: resolvedCardId,
                onTap: () {
                  if (isFourth && onSeeMoreTap != null) {
                    onSeeMoreTap!();
                  } else if (onCardTap != null) {
                    onCardTap!(index, resolvedCardId);
                  } else {
                    _handleDefaultCardTap(context, index, resolvedCardId);
                  }
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _GridCardPlaceholder extends StatelessWidget {
  final int index;
  final String title;
  final bool isFourth;
  final String? cardId;
  final VoidCallback? onTap;

  const _GridCardPlaceholder({
    required this.index,
    required this.title,
    required this.isFourth,
    this.cardId,
    this.onTap,
  });

  bool get _isImageUrl =>
      title.startsWith('http://') ||
      title.startsWith('https://') ||
      title.contains('cards.scryfall.io') ||
      title.contains('.jpg') ||
      title.contains('.png');

  @override
  Widget build(BuildContext context) {
    // Unique gradients for cards
    final gradients = [
      [const Color(0xFF2A1B40), const Color(0xFF161925)],
      [const Color(0xFF1B3240), const Color(0xFF131B24)],
      [const Color(0xFF352615), const Color(0xFF1A1714)],
      [const Color(0xFF241D35), const Color(0xFF12141C)],
    ];

    final accentColors = [
      AppColors.accentViolet,
      AppColors.accentCyan,
      AppColors.accentAmber,
      AppColors.accentVioletLight,
    ];

    return GestureDetector(
      key: Key('multi_pull_card_${index}_${cardId ?? index}'),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradients[index % gradients.length],
          ),
          border: Border.all(color: AppColors.surfaceBorder, width: 1),
          boxShadow: const [
            BoxShadow(
              color: Colors.black38,
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_isImageUrl)
                IgnorePointer(
                  child: CountrCachedImage(
                    imageUrl: title,
                    cardId: cardId,
                    tcgDomain: 'mtg',
                    fallbackVersion: 'normal',
                    fit: BoxFit.cover,
                    errorWidget: _buildFallback(accentColors),
                  ),
                )
              else
                _buildFallback(accentColors),

              // 4th Item Overlay: Dark overlay with "+ SEE MORE"
              if (isFourth)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.82),
                    borderRadius: BorderRadius.zero,
                  ),
                  alignment: Alignment.center,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.surfaceHighlight.withValues(
                              alpha: 0.8,
                            ),
                            border: Border.all(color: AppColors.accentCyan),
                          ),
                          child: const Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 20,
                            color: AppColors.accentCyan,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          '+ SEE MORE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFallback(List<Color> accentColors) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surfaceRaised,
                border: Border.all(
                  color: accentColors[index % accentColors.length].withValues(
                    alpha: 0.6,
                  ),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.style_rounded,
                size: 22,
                color: accentColors[index % accentColors.length],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'HIT #${index + 1}',
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                color: accentColors[index % accentColors.length],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
