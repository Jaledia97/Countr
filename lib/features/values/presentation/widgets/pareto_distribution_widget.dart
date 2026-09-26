import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/cache/countr_cached_image.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/constants/app_typography.dart';
import 'package:countr/core/state/settings_state.dart';
import 'package:countr/features/decks/domain/models/deck_item_with_card.dart';
import 'package:countr/features/values/domain/services/pareto_distribution_calculator.dart';
import 'package:countr/features/values/presentation/widgets/value_concentration_pie_chart.dart';
import 'package:countr/features/vault/domain/vault_pricing_helper.dart';

/// Presentation widget displaying Pareto value concentration analytics ("Heavy Hitters")
/// with an interactive custom canvas Donut Chart and bi-directional list synchronization.
///
/// Features:
/// - Adaptive headline banner: "The top 5 cards represent X% of this deck's total value."
/// - Interactive CustomPainter Donut Chart (ValueConcentrationPieChart) with polar hit-testing.
/// - 6.0px exploded slice offset along the bisecting angle for selected card.
/// - Center hole overlay badge showing card name, price, and percentage share.
/// - Bi-directional synchronization: tapping slice highlights & scrolls micro-list; tapping row highlights chart slice.
/// - Ranked micro-list of top 3-5 cards with tier-colored badges (#1 Amber, #2 Cyan, #3 Violet, #4 Emerald, #5 Rose).
/// - 40x40 art crop thumbnail with resilient fallback.
/// - Metadata row (Name, Set, Quantity) and formatted valuation with percentage share.
/// - Proportional visual horizontal contribution bar.
/// - Zero RenderFlex overflows on 320x568 at 2.0x font scaling via Expanded, Flexible, and FittedBox.
/// - Full privacy mode masking ('****' for all prices, percentages, and headline numbers).
class ParetoDistributionWidget extends ConsumerStatefulWidget {
  final ParetoDistributionResult? result;
  final double? deckTotalValue;
  final double? topKConcentrationPercentage;
  final List<dynamic>? topCards;
  final AppCurrency? currency;
  final bool? isPrivacyMode;

  const ParetoDistributionWidget({
    super.key,
    this.result,
    this.deckTotalValue,
    this.topKConcentrationPercentage,
    this.topCards,
    this.currency,
    this.isPrivacyMode,
  });

  @override
  ConsumerState<ParetoDistributionWidget> createState() => _ParetoDistributionWidgetState();
}

class _ParetoDistributionWidgetState extends ConsumerState<ParetoDistributionWidget> {
  int? _selectedIndex;
  final Map<int, GlobalKey> _rowKeys = {};

  void _onSliceSelected(int? index, ParetoDistributionResult resolvedResult) {
    setState(() {
      _selectedIndex = index;
    });

    if (index != null && index < resolvedResult.topCards.length) {
      final key = _rowKeys[index];
      if (key?.currentContext != null) {
        Scrollable.ensureVisible(
          key!.currentContext!,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0.5,
        );
      }
    }
  }

  void _onCardRowTapped(int index) {
    setState(() {
      if (_selectedIndex == index) {
        _selectedIndex = null; // Toggle off
      } else {
        _selectedIndex = index;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool activePrivacy = widget.isPrivacyMode ?? ref.watch(privacyModeProvider);
    final AppCurrency activeCurrency = widget.currency ?? ref.watch(baseCurrencyProvider);

    final resolvedResult = _resolveResult(activeCurrency);
    final slices = _buildSlices(resolvedResult);

    return Container(
      key: const Key('pareto_distribution_widget'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.accentCyan.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.pie_chart_outline_rounded,
                  size: 16,
                  color: AppColors.accentCyan,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'VALUE CONCENTRATION (PARETO)',
                  style: AppTypography.heading2.copyWith(
                    fontSize: 12,
                    letterSpacing: 1.1,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Adaptive Headline Banner
          _buildHeadlineBanner(resolvedResult, activePrivacy),

          if (resolvedResult.topCards.isNotEmpty && resolvedResult.totalDeckValue > 0) ...[
            const SizedBox(height: 16),

            // Interactive Custom Canvas Donut Chart
            ValueConcentrationPieChart(
              slices: slices,
              totalDeckValue: resolvedResult.totalDeckValue,
              topK: resolvedResult.topK,
              concentrationPercentage: resolvedResult.concentrationPercentage,
              selectedIndex: _selectedIndex,
              onSliceSelected: (idx) => _onSliceSelected(idx, resolvedResult),
              isPrivacyMode: activePrivacy,
              currency: activeCurrency,
              size: 180.0,
            ),

            const SizedBox(height: 16),
            const Divider(color: AppColors.surfaceBorderSubtle, height: 1),
            const SizedBox(height: 12),

            // Ranked Micro-List with Bi-directional Tap & Highlight
            ListView.separated(
              key: const Key('pareto_micro_list'),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: resolvedResult.topCards.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final card = resolvedResult.topCards[index];
                _rowKeys[index] ??= GlobalKey();

                return _buildParetoRow(
                  context,
                  index,
                  card,
                  activePrivacy,
                  activeCurrency,
                  isSelected: _selectedIndex == index,
                  rowKey: _rowKeys[index]!,
                );
              },
            ),
          ] else if (resolvedResult.topCards.isNotEmpty) ...[
            // When total deck value is 0 or negative but cards exist
            const SizedBox(height: 14),
            const Divider(color: AppColors.surfaceBorderSubtle, height: 1),
            const SizedBox(height: 12),

            ListView.separated(
              key: const Key('pareto_micro_list'),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: resolvedResult.topCards.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final card = resolvedResult.topCards[index];
                _rowKeys[index] ??= GlobalKey();

                return _buildParetoRow(
                  context,
                  index,
                  card,
                  activePrivacy,
                  activeCurrency,
                  isSelected: _selectedIndex == index,
                  rowKey: _rowKeys[index]!,
                );
              },
            ),
          ] else ...[
            const SizedBox(height: 12),
            Container(
              key: const Key('pareto_empty_state'),
              padding: const EdgeInsets.symmetric(vertical: 8),
              alignment: Alignment.center,
              child: const Text(
                'No cards in this deck to analyze.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<PieSliceData> _buildSlices(ParetoDistributionResult res) {
    final slices = <PieSliceData>[];
    double topCardsSum = 0.0;

    for (final card in res.topCards) {
      topCardsSum += card.lineValue;
      slices.add(
        PieSliceData(
          rank: card.rank,
          id: card.id,
          name: card.name,
          value: card.lineValue,
          percentage: card.percentageShare,
          color: _getTierColor(card.rank),
          item: card,
        ),
      );
    }

    final remainingValue = res.totalDeckValue - topCardsSum;
    if (remainingValue > 0.01 && res.totalDeckValue > 0) {
      final remainingPct = (remainingValue / res.totalDeckValue) * 100.0;
      slices.add(
        PieSliceData(
          rank: null,
          id: 'remaining_others',
          name: 'Other Cards',
          value: remainingValue,
          percentage: remainingPct,
          color: const Color(0xFF334155),
          item: null,
        ),
      );
    }

    return slices;
  }

  ParetoDistributionResult _resolveResult(AppCurrency activeCurrency) {
    if (widget.result != null) {
      return widget.result!;
    }

    if (widget.topCards != null) {
      final inputCards = <ParetoCardInput>[];
      for (final raw in widget.topCards!) {
        if (raw is ParetoItem) {
          inputCards.add(
            ParetoCardInput(
              id: raw.id,
              name: raw.name,
              setCode: raw.setCode,
              quantity: raw.quantity,
              unitPrice: raw.unitPrice,
              imageUrl: raw.imageUrl,
              artCropUrl: raw.artCropUrl,
            ),
          );
        } else if (raw is ParetoCardInput) {
          inputCards.add(raw);
        } else if (raw is DeckItemWithCard) {
          inputCards.add(ParetoCardInput.fromDeckItemWithCard(raw, activeCurrency));
        } else if (raw is Map<String, dynamic>) {
          inputCards.add(ParetoCardInput.fromDeckItemMap(raw));
        }
      }

      final computed = ParetoDistributionCalculator.calculate(
        cards: inputCards,
        targetK: 5,
        currency: activeCurrency,
      );

      // If explicit concentration percentage or deck total was supplied, respect it
      if (widget.topKConcentrationPercentage != null || widget.deckTotalValue != null) {
        return ParetoDistributionResult(
          totalDeckValue: widget.deckTotalValue ?? computed.totalDeckValue,
          topCardsValue: computed.topCardsValue,
          concentrationPercentage: widget.topKConcentrationPercentage ?? computed.concentrationPercentage,
          totalUniqueCards: computed.totalUniqueCards,
          totalCardCount: computed.totalCardCount,
          topK: computed.topK,
          topCards: computed.topCards,
          currency: activeCurrency,
        );
      }
      return computed;
    }

    return ParetoDistributionResult.empty(currency: activeCurrency);
  }

  Widget _buildHeadlineBanner(ParetoDistributionResult res, bool isPrivacyMode) {
    final headline = res.getHeadline(isPrivacyMode: isPrivacyMode);

    return Container(
      key: const Key('pareto_headline_banner'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.accentCyan.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.accentCyan.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            isPrivacyMode ? Icons.lock_outline_rounded : Icons.insights_rounded,
            size: 16,
            color: AppColors.accentCyan,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              headline,
              key: const Key('pareto_headline_text'),
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                height: 1.3,
              ),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParetoRow(
    BuildContext context,
    int index,
    ParetoItem card,
    bool isPrivacyMode,
    AppCurrency activeCurrency, {
    required bool isSelected,
    required Key rowKey,
  }) {
    final tierColor = _getTierColor(card.rank);
    final formattedPrice = VaultPricingHelper.formatAmount(
      card.lineValue,
      currency: activeCurrency,
      isPrivacyMode: isPrivacyMode,
      allowZero: true,
    );
    final formattedShare = isPrivacyMode ? '****' : '${card.percentageShare.toStringAsFixed(1)}%';

    return InkWell(
      onTap: () => _onCardRowTapped(index),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        key: Key('pareto_row_${card.rank}'),
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? tierColor.withValues(alpha: 0.14)
              : AppColors.surfaceHighlight.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? tierColor : AppColors.surfaceBorderSubtle,
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: tierColor.withValues(alpha: 0.25),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              key: rowKey,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. Tier Rank Badge
                _buildRankBadge(card.rank, tierColor),

                const SizedBox(width: 8),

                // 2. 40x40 Art Crop Thumbnail
                _buildThumbnail(card),

                const SizedBox(width: 10),

                // 3. Card Metadata (Name & Subtitle)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        card.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        card.subtitle,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // 4. Valuation and Share
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          formattedPrice,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.accentAmber,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '($formattedShare)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: tierColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // 5. Proportional Visual Weight Bar
            LayoutBuilder(
              builder: (context, constraints) {
                final double barRatio = isPrivacyMode
                    ? 0.0
                    : card.weightRatio.clamp(0.0, 1.0);

                return Container(
                  height: 4,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceBorderSubtle,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: barRatio,
                    child: Container(
                      decoration: BoxDecoration(
                        color: tierColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRankBadge(int rank, Color tierColor) {
    return Container(
      key: Key('pareto_rank_badge_$rank'),
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: tierColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: tierColor.withValues(alpha: 0.45),
          width: 1,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        '#$rank',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: tierColor,
        ),
      ),
    );
  }

  Widget _buildThumbnail(ParetoItem card) {
    final url = card.effectiveImageUrl;

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 40,
        height: 40,
        color: AppColors.surfaceRaised,
        child: url.isNotEmpty
            ? CountrCachedImage(
                imageUrl: url,
                fit: BoxFit.cover,
                errorWidget: _buildPlaceholder(),
              )
            : _buildPlaceholder(),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 40,
      height: 40,
      color: AppColors.surfaceBorderSubtle,
      child: const Icon(
        Icons.style_outlined,
        size: 18,
        color: AppColors.textMuted,
      ),
    );
  }

  Color _getTierColor(int rank) {
    switch (rank) {
      case 1:
        return AppColors.accentAmber; // Gold / #1
      case 2:
        return AppColors.accentCyan; // Cyan / #2
      case 3:
        return AppColors.accentViolet; // Violet / #3
      case 4:
        return AppColors.accentEmerald; // Emerald / #4
      case 5:
        return AppColors.accentRose; // Rose / #5
      default:
        return const Color(0xFF334155); // Slate / Others
    }
  }
}
