import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:countr/core/database/app_database.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/cache/countr_cached_image.dart';
import '../../../symbology/presentation/widgets/mana_text.dart';
import '../../../vault/presentation/widgets/card_detail_sheet.dart';
import '../../../vault/presentation/widgets/expanded_card_view_modal.dart';

/// Body for Single Pull Post variant.
/// Features optional commentary text and a large, high-resolution square
/// image placeholder representing a scanned trading card or comic book.
class SinglePullPostBody extends StatelessWidget {
  final String? commentary;
  final String? cardTitle;
  final String? cardSubtitle;
  final String? cardRarity;
  final String? estimatedValue;
  final String? cardId;
  final String? imageUrl;
  final VoidCallback? onCardTap;
  final bool? useLightbox;

  const SinglePullPostBody({
    super.key,
    this.commentary,
    this.cardTitle,
    this.cardSubtitle,
    this.cardRarity,
    this.estimatedValue,
    this.cardId,
    this.imageUrl,
    this.onCardTap,
    this.useLightbox,
  });

  void _handleCardTap(BuildContext context) {
    if (onCardTap != null) {
      onCardTap!();
    } else {
      final fallbackItem = VaultItem(
        id: cardId ?? 'item-mtg-one-ring',
        collectionType: 'mtg',
        name: cardTitle?.isNotEmpty == true
            ? cardTitle!
            : 'The One Ring (Serialized #007/100)',
        setOrSeries: cardSubtitle?.isNotEmpty == true
            ? cardSubtitle!
            : 'The Lord of the Rings: Tales of Middle-earth',
        imageUrl: imageUrl?.isNotEmpty == true
            ? imageUrl!
            : 'https://cards.scryfall.io/large/front/d/5/d5806e68-1054-458e-866d-1f2470f682b2.jpg?1790212038',
        acquiredPrice:
            double.tryParse(
              estimatedValue?.replaceAll(RegExp(r'[^0-9.]'), '') ?? '',
            ) ??
            45.50,
        acquiredDate: DateTime.now(),
        quantity: 1,
        condition: 'Near Mint',
        isGraded: false,
        isAltered: false,
        isMisprint: false,
        isSigned: false,
        isDeleted: false,
        currentMarketPrice:
            double.tryParse(
              estimatedValue?.replaceAll(RegExp(r'[^0-9.]'), '') ?? '',
            ) ??
            45.50,
        lastPriceUpdate: DateTime.now(),
        dynamicData: jsonEncode({
          'oracle_text':
              'Indestructible\nAt the beginning of your upkeep, you lose 1 life for each burden counter on The One Ring.\n{T}: Put a burden counter on The One Ring, then draw a card for each burden counter on it.',
          'type_line': 'Legendary Artifact',
          'mana_cost': '{4}',
          'rarity': cardRarity ?? 'Mythic Rare',
        }),
      );
      if (useLightbox == true) {
        ExpandedCardViewModal.show(
          context,
          cardId: cardId ?? 'item-mtg-one-ring',
          imageUrl: imageUrl,
          cardTitle: cardTitle ?? 'The One Ring (Serialized #007/100)',
          cardSubtitle: cardSubtitle ?? 'The Lord of the Rings: Tales of Middle-earth',
          cardRarity: cardRarity ?? 'Mythic Rare',
          estimatedValue: estimatedValue,
          item: fallbackItem,
        );
      } else {
        CardDetailSheet.show(
          context,
          fallbackItem,
          cardId: cardId ?? 'item-mtg-one-ring',
        );
      }
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

        // Large high-resolution card artwork container
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: InkWell(
            key: Key('single_pull_card_${cardId ?? "default"}'),
            borderRadius: BorderRadius.circular(14),
            onTap: () => _handleCardTap(context),
            child: AspectRatio(
              aspectRatio: 63 / 88,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const RadialGradient(
                    center: Alignment(0.0, -0.2),
                    radius: 1.1,
                    colors: [
                      Color(0xFF232A36),
                      Color(0xFF131720),
                      Color(0xFF090B0E),
                    ],
                  ),
                  border: Border.all(
                    color: AppColors.accentCyan.withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentCyan.withValues(alpha: 0.12),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Subtle background holographic grid/pattern
                      CustomPaint(painter: _CardGridPatternPainter()),

                      // Central Card Graphic Representation with authentic MTG aspect ratio
                      Center(
                        child: AspectRatio(
                          aspectRatio: 63 / 88,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppColors.accentAmber.withValues(
                                  alpha: 0.6,
                                ),
                                width: 1.2,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black54,
                                  blurRadius: 16,
                                  offset: Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(9),
                              child:
                                  (imageUrl != null && imageUrl!.isNotEmpty) ||
                                      (cardId != null && cardId!.isNotEmpty)
                                  ? CountrCachedImage(
                                      imageUrl: imageUrl ?? '',
                                      cardId: cardId,
                                      cardName: cardTitle,
                                      tcgDomain: 'mtg',
                                      fallbackVersion: 'normal',
                                      fit: BoxFit.contain,
                                      errorWidget: _buildScanGraphic(),
                                    )
                                  : _buildScanGraphic(),
                            ),
                          ),
                        ),
                      ),

                      // Top OCR Scanner Spec Badge
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.background.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: AppColors.accentCyan.withValues(
                                alpha: 0.4,
                              ),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.document_scanner_outlined,
                                size: 12,
                                color: AppColors.accentCyan,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'RAW SCAN 600 DPI',
                                style: TextStyle(
                                  color: AppColors.accentCyan,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Top Right Estimated Value Pill
                      if (estimatedValue != null)
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accentEmerald.withValues(
                                alpha: 0.2,
                              ),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: AppColors.accentEmerald.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.trending_up_rounded,
                                  size: 12,
                                  color: AppColors.accentEmerald,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  estimatedValue!,
                                  style: const TextStyle(
                                    color: AppColors.accentEmerald,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Bottom Scanned Card Details Overlay
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.95),
                                Colors.black.withValues(alpha: 0.7),
                                Colors.transparent,
                              ],
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (cardTitle != null)
                                Text(
                                  cardTitle!,
                                  style: AppTypography.heading2.copyWith(
                                    fontSize: 15,
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  if (cardSubtitle != null)
                                    Expanded(
                                      child: Text(
                                        cardSubtitle!,
                                        style: AppTypography.caption.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  if (cardRarity != null) ...[
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        cardRarity!,
                                        style: AppTypography.caption.copyWith(
                                          color: AppColors.accentAmber,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildScanGraphic() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surfaceRaised,
            AppColors.surfaceHighlight,
            AppColors.accentViolet.withValues(alpha: 0.25),
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface,
              border: Border.all(color: AppColors.accentAmber, width: 1),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              size: 36,
              color: AppColors.accentAmber,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'VERIFIED SCAN',
            style: TextStyle(
              color: AppColors.accentCyan,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'HIGH-RES RAW CARD',
            style: TextStyle(
              color: AppColors.textSecondary.withValues(alpha: 0.8),
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardGridPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..strokeWidth = 1;

    const double step = 24.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
