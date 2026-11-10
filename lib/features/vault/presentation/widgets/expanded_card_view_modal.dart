// Copyright (c) 2026 Countr. All rights reserved.
import 'package:flutter/material.dart';
import 'package:countr/core/cache/countr_cached_image.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/constants/app_typography.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';

/// Lightweight data holder for an item displayed in [ExpandedCardViewModal].
class ExpandedCardItem {
  final String cardId;
  final String? imageUrl;
  final String? cardTitle;
  final String? cardSubtitle;
  final String? cardRarity;
  final String? estimatedValue;
  final VaultItem? item;

  const ExpandedCardItem({
    required this.cardId,
    this.imageUrl,
    this.cardTitle,
    this.cardSubtitle,
    this.cardRarity,
    this.estimatedValue,
    this.item,
  });
}

/// Fullscreen lightbox modal overlay displaying high-resolution card artwork,
/// horizontal swipe navigation for multi-card posts, and a prominent [See Details]
/// action button navigating to [CardDetailSheet].
class ExpandedCardViewModal extends StatefulWidget {
  final List<ExpandedCardItem> cards;
  final int initialIndex;
  final BuildContext? parentContext;
  final VoidCallback? onSeeDetails;

  ExpandedCardViewModal({
    super.key,
    required this.cards,
    this.initialIndex = 0,
    this.parentContext,
    this.onSeeDetails,
  }) : assert(cards.isNotEmpty, 'cards list must not be empty');

  /// Displays the [ExpandedCardViewModal] using a fade transition modal route.
  static Future<void> show(
    BuildContext context, {
    List<ExpandedCardItem>? cards,
    String? cardId,
    List<String>? cardIds,
    String? imageUrl,
    List<String>? imageUrls,
    String? cardTitle,
    List<String>? cardTitles,
    String? cardSubtitle,
    List<String>? cardSubtitles,
    String? cardRarity,
    List<String>? cardRarities,
    String? estimatedValue,
    List<String>? estimatedValues,
    VaultItem? item,
    List<VaultItem>? items,
    int initialIndex = 0,
    VoidCallback? onSeeDetails,
  }) {
    List<ExpandedCardItem> resolvedCards = [];

    if (cards != null && cards.isNotEmpty) {
      resolvedCards = cards;
    } else if (items != null && items.isNotEmpty) {
      resolvedCards = items
          .map((it) => ExpandedCardItem(
                cardId: it.id,
                imageUrl: it.imageUrl,
                cardTitle: it.name,
                cardSubtitle: it.setOrSeries,
                estimatedValue: it.currentMarketPrice > 0
                    ? '\$${it.currentMarketPrice.toStringAsFixed(2)}'
                    : null,
                item: it,
              ))
          .toList();
    } else if (cardIds != null && cardIds.isNotEmpty) {
      resolvedCards = List.generate(cardIds.length, (i) {
        return ExpandedCardItem(
          cardId: cardIds[i],
          imageUrl: (imageUrls != null && imageUrls.length > i)
              ? imageUrls[i]
              : null,
          cardTitle: (cardTitles != null && cardTitles.length > i)
              ? cardTitles[i]
              : null,
          cardSubtitle: (cardSubtitles != null && cardSubtitles.length > i)
              ? cardSubtitles[i]
              : null,
          cardRarity: (cardRarities != null && cardRarities.length > i)
              ? cardRarities[i]
              : null,
          estimatedValue: (estimatedValues != null && estimatedValues.length > i)
              ? estimatedValues[i]
              : null,
        );
      });
    } else {
      resolvedCards = [
        ExpandedCardItem(
          cardId: cardId ?? 'item-mtg-one-ring',
          imageUrl: imageUrl,
          cardTitle: cardTitle,
          cardSubtitle: cardSubtitle,
          cardRarity: cardRarity,
          estimatedValue: estimatedValue,
          item: item,
        ),
      ];
    }

    final safeIndex = (initialIndex >= 0 && initialIndex < resolvedCards.length)
        ? initialIndex
        : 0;

    return Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black.withValues(alpha: 0.94),
        barrierDismissible: true,
        pageBuilder: (modalCtx, _, _) => ExpandedCardViewModal(
          cards: resolvedCards,
          initialIndex: safeIndex,
          parentContext: context,
          onSeeDetails: onSeeDetails,
        ),
        transitionsBuilder: (ctx, animation, _, child) => FadeTransition(
          opacity: animation,
          child: child,
        ),
      ),
    );
  }

  @override
  State<ExpandedCardViewModal> createState() => _ExpandedCardViewModalState();
}

class _ExpandedCardViewModalState extends State<ExpandedCardViewModal> {
  late int _currentIndex;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(
      0,
      widget.cards.isEmpty ? 0 : widget.cards.length - 1,
    );
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _handleSeeDetails() {
    if (widget.onSeeDetails != null) {
      widget.onSeeDetails!();
      return;
    }

    final current = widget.cards[_currentIndex];
    Navigator.of(context).pop();

    final targetContext = (widget.parentContext != null &&
            widget.parentContext!.mounted)
        ? widget.parentContext!
        : context;

    if (current.item != null) {
      CardDetailSheet.show(
        targetContext,
        current.item!,
        cardId: current.cardId,
        item: current.item,
      );
    } else {
      CardDetailSheet.show(
        targetContext,
        current.cardId,
        cardId: current.cardId,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentCard = widget.cards[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        key: const Key('expanded_card_view_lightbox'),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.92),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Tap outside card artwork to dismiss
            GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              behavior: HitTestBehavior.translucent,
              child: const SizedBox.expand(),
            ),

            // Center Swipable Card Display
            Center(
              child: SizedBox(
                height: 520,
                child: PageView.builder(
                  controller: _pageController,
                  physics: const BouncingScrollPhysics(),
                  itemCount: widget.cards.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    final card = widget.cards[index];
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: AspectRatio(
                          aspectRatio: 63 / 88,
                          child: Container(
                            key: const Key('expanded_card_high_res_art'),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
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
                                color: AppColors.accentCyan.withValues(alpha: 0.4),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.accentCyan.withValues(alpha: 0.2),
                                  blurRadius: 28,
                                  spreadRadius: 2,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(15),
                              child: (card.imageUrl != null &&
                                          card.imageUrl!.isNotEmpty) ||
                                      card.cardId.isNotEmpty
                                  ? CountrCachedImage(
                                      imageUrl: card.imageUrl ?? '',
                                      cardId: card.cardId,
                                      cardName: card.cardTitle,
                                      tcgDomain: 'mtg',
                                      fallbackVersion: 'large',
                                      fit: BoxFit.contain,
                                      errorWidget: _buildCardFallback(card),
                                    )
                                  : _buildCardFallback(card),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Top Bar with Close Button and Page Counter (Anchored to Top & Layered ABOVE PageView)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (widget.cards.length > 1)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceRaised.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.accentCyan.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            '${_currentIndex + 1} / ${widget.cards.length}',
                            style: const TextStyle(
                              color: AppColors.accentCyan,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                        )
                      else
                        const SizedBox(width: 44),

                      // Close Action Button
                      IconButton(
                        key: const Key('expanded_card_close_button'),
                        icon: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                            ),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom Action Bar and Metadata
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
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
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Card Title
                      if (currentCard.cardTitle != null &&
                          currentCard.cardTitle!.isNotEmpty)
                        Text(
                          currentCard.cardTitle!,
                          style: AppTypography.heading1.copyWith(
                            fontSize: 18,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                      // Card Subtitle / Estimated Value Row
                      if (currentCard.cardSubtitle != null ||
                          currentCard.estimatedValue != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (currentCard.cardSubtitle != null &&
                                currentCard.cardSubtitle!.isNotEmpty)
                              Flexible(
                                child: Text(
                                  currentCard.cardSubtitle!,
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            if (currentCard.cardSubtitle != null &&
                                currentCard.estimatedValue != null)
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6),
                                child: Text('•',
                                    style: TextStyle(
                                        color: AppColors.textMuted)),
                              ),
                            if (currentCard.estimatedValue != null &&
                                currentCard.estimatedValue!.isNotEmpty)
                              Text(
                                currentCard.estimatedValue!,
                                style: const TextStyle(
                                  color: AppColors.accentEmerald,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                          ],
                        ),
                      ],

                      // Multi-card Dots Indicator
                      if (widget.cards.length > 1) ...[
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(widget.cards.length, (i) {
                            final isActive = i == _currentIndex;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 3),
                              width: isActive ? 16 : 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: isActive
                                    ? AppColors.accentCyan
                                    : Colors.white.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            );
                          }),
                        ),
                      ],

                      const SizedBox(height: 16),

                      // Prominent [See Details] Button
                      ElevatedButton.icon(
                        key: const Key('expanded_card_see_details_button'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentCyan,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                        ),
                        onPressed: _handleSeeDetails,
                        icon: const Icon(Icons.info_outline_rounded,
                            size: 20, color: Colors.black),
                        label: const Text(
                          'See Details',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardFallback(ExpandedCardItem card) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
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
          Text(
            card.cardTitle ?? 'CARD SCAN',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'HIGH-RES ARTWORK',
            style: TextStyle(
              color: AppColors.accentCyan,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
