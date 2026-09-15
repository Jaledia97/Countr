import 'package:flutter/material.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/constants/app_typography.dart';
import 'package:countr/core/database/app_database.dart';
import 'card_detail_sheet.dart';
import 'polymorphic_attribute_chip.dart';

/// Individual Ledger Card for a VaultItem.
/// Renders financial delta (P/L % in green or red) and polymorphic dynamic attributes.
class VaultItemCard extends StatelessWidget {
  final VaultItem item;

  const VaultItemCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    // Financial calculations
    final delta = (item.currentMarketPrice - item.acquiredPrice) * item.quantity;
    final pct = item.acquiredPrice > 0
        ? ((item.currentMarketPrice - item.acquiredPrice) / item.acquiredPrice) * 100
        : 0.0;
    final isProfit = delta >= 0;
    final pLColor = isProfit ? AppColors.accentEmerald : AppColors.accentRose;
    final pctSign = isProfit ? '+' : '';
    final deltaSign = isProfit ? '+' : '-';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.surfaceBorder,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => CardDetailSheet.show(context, item),
          child: Padding(
            padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Category Icon, Name, Condition & Grade Badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type Icon Box
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _getTypeColor(item.collectionType).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _getTypeColor(item.collectionType).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Icon(
                    _getTypeIcon(item.collectionType),
                    color: _getTypeColor(item.collectionType),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),

                // Name & Set
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: AppTypography.heading2.copyWith(fontSize: 14.5),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.setOrSeries,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Condition / Grade Pill
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: item.isGraded
                            ? AppColors.accentCyan.withValues(alpha: 0.18)
                            : AppColors.surfaceRaised,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: item.isGraded
                              ? AppColors.accentCyan.withValues(alpha: 0.6)
                              : AppColors.surfaceBorder,
                        ),
                      ),
                      child: Text(
                        item.condition,
                        style: TextStyle(
                          color: item.isGraded
                              ? AppColors.accentCyan
                              : AppColors.textPrimary,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (item.isGraded) ...[
                      const SizedBox(height: 3),
                      const Text(
                        'SLAB / GRADED',
                        style: TextStyle(
                          color: AppColors.accentCyan,
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Polymorphic Engine JSON Display
            PolymorphicAttributeChip(
              collectionType: item.collectionType,
              dynamicDataJson: item.dynamicData,
            ),

            const SizedBox(height: 12),

            // Financial Ledger Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceRaised,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.surfaceBorderSubtle),
              ),
              child: item.quantity == 0
                  ? Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.accentCyan.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: AppColors.accentCyan.withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.menu_book_rounded,
                                  color: AppColors.accentCyan, size: 14),
                              SizedBox(width: 6),
                              Text(
                                'CATALOG / UNOWNED',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.accentCyan,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              'MARKET VALUE',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textMuted,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '\$${item.currentMarketPrice.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Row(
                children: [
                  // Acquired Price
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ACQUIRED',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '\$${item.acquiredPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(width: 16),

                  // Current Market Price (TMV)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'LIVE TMV',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accentCyan,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '\$${item.currentMarketPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Financial Delta (P/L Percentage in Green or Red)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: pLColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: pLColor.withValues(alpha: 0.5),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isProfit ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                          color: pLColor,
                          size: 15,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$pctSign${pct.toStringAsFixed(1)}% ($deltaSign\$${delta.abs().toStringAsFixed(2)})',
                          style: TextStyle(
                            color: pLColor,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);
}

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'mtg':
        return Icons.auto_awesome_rounded;
      case 'pokemon':
        return Icons.catching_pokemon_rounded;
      case 'comic':
        return Icons.menu_book_rounded;
      case 'sports_card':
        return Icons.sports_football_rounded;
      default:
        return Icons.style_rounded;
    }
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'mtg':
        return AppColors.accentViolet;
      case 'pokemon':
        return AppColors.accentAmber;
      case 'comic':
        return AppColors.accentEmerald;
      case 'sports_card':
        return AppColors.accentCyan;
      default:
        return AppColors.accentCyan;
    }
  }
}
