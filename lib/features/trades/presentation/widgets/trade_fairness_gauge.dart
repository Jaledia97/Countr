import 'package:flutter/material.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/constants/app_typography.dart';
import 'package:countr/features/trades/domain/models/trade_fairness.dart';

/// Visual fairness gauge bar with 3 color-coded tiers:
/// - Green: Fair / Balanced (gap <= 10%)
/// - Amber: Moderate lopsidedness (gap 10-25%)
/// - Red: Lopsided (gap > 25%)
class TradeFairnessGauge extends StatelessWidget {
  final TradeFairnessResult fairness;
  final bool compact;

  const TradeFairnessGauge({
    super.key,
    required this.fairness,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final tier = fairness.tier;
    final gap = fairness.maxGapPercent;

    return Column(
      key: const Key('trade_fairness_gauge'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header / Status Label
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: compact ? 8 : 10,
                    height: compact ? 8 : 10,
                    decoration: BoxDecoration(
                      color: tier.color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: tier.color.withValues(alpha: 0.5),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '${tier.displayName.toUpperCase()} (${gap.toStringAsFixed(1)}% gap)',
                      key: const Key('trade_fairness_gauge_label'),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 11 : 12,
                        fontWeight: FontWeight.w800,
                        color: tier.color,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (!compact && fairness.maxDollarGap > 0)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  'Max Diff: \$${fairness.maxDollarGap.toStringAsFixed(2)}',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: compact ? 4 : 6),

        // Multi-segment Gauge Bar
        Container(
          height: compact ? 6 : 8,
          decoration: BoxDecoration(
            color: AppColors.surfaceBorder.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(4),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final totalWidth = constraints.maxWidth;
              // Normalize gap percentage (0 to 50% scale for visual representation)
              final progress = (gap / 50.0).clamp(0.02, 1.0);
              final fillWidth = totalWidth * progress;

              return Stack(
                children: [
                  // Threshold markers: 10% (0.2 of 50%) and 25% (0.5 of 50%)
                  Positioned(
                    left: totalWidth * (10.0 / 50.0),
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 1.5,
                      color: AppColors.surfaceRaised,
                    ),
                  ),
                  Positioned(
                    left: totalWidth * (25.0 / 50.0),
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 1.5,
                      color: AppColors.surfaceRaised,
                    ),
                  ),

                  // Active Fill Needle/Bar
                  Container(
                    width: fillWidth,
                    decoration: BoxDecoration(
                      color: tier.color,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: tier.color.withValues(alpha: 0.4),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
