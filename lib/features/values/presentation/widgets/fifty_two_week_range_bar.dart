import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/constants/app_typography.dart';
import 'package:countr/core/state/settings_state.dart';
import 'package:countr/features/vault/domain/vault_pricing_helper.dart';
import 'package:countr/features/values/domain/models/financial_analytics.dart';

/// Horizontal slider gauge showing current price relative to 52-week low and high.
class FiftyTwoWeekRangeBar extends ConsumerWidget {
  /// Structured 52-week range model.
  final FiftyTwoWeekRange? range;

  /// 52-week lowest price.
  final double? low52;

  /// 52-week highest price.
  final double? high52;

  /// Current market price.
  final double? currentPrice;

  /// Display currency.
  final AppCurrency? currency;

  /// Explicit privacy mode toggle.
  final bool? isPrivacyMode;

  const FiftyTwoWeekRangeBar({
    super.key,
    this.range,
    this.low52,
    this.high52,
    this.currentPrice,
    this.currency,
    this.isPrivacyMode,
  });

  factory FiftyTwoWeekRangeBar.fromRange(
    FiftyTwoWeekRange range, {
    Key? key,
    bool? isPrivacyMode,
  }) {
    return FiftyTwoWeekRangeBar(
      key: key,
      range: range,
      currency: range.currency,
      isPrivacyMode: isPrivacyMode,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppCurrency activeCurrency = currency ?? ref.watch(baseCurrencyProvider);
    final bool activePrivacy = isPrivacyMode ?? ref.watch(privacyModeProvider);

    final effectiveRange = range ??
        FiftyTwoWeekRange.calculate(
          low52: low52 ?? 0.0,
          high52: high52 ?? 0.0,
          currentPrice: currentPrice ?? 0.0,
          currency: activeCurrency,
        );

    final position = effectiveRange.rangePosition;
    final percentile = (position * 100.0).toStringAsFixed(0);

    return Container(
      key: const Key('fifty_two_week_range_bar'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Title + Percentile Marker Pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.linear_scale_rounded,
                      size: 16,
                      color: AppColors.accentCyan,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '52-Week Price Range',
                        style: AppTypography.heading2.copyWith(fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  key: const Key('range_percentile_pill'),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: AppColors.accentCyan.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.accentCyan.withValues(alpha: 0.3)),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      activePrivacy ? '**** of Range' : '$percentile% of Range',
                      key: const Key('range_percentile_text'),
                      style: const TextStyle(
                        color: AppColors.accentCyan,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Slider Track & Indicator Thumb
          LayoutBuilder(
            builder: (context, constraints) {
              const thumbDiameter = 14.0;
              final maxTravel = constraints.maxWidth - thumbDiameter;
              final thumbLeftOffset = maxTravel > 0 ? (maxTravel * position).clamp(0.0, maxTravel) : 0.0;

              return Column(
                children: [
                  SizedBox(
                    height: 18,
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        // Track Background
                        Container(
                          height: 6,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceHighlight,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        // Track Active Gradient (from low to thumb position)
                        FractionallySizedBox(
                          widthFactor: position.clamp(0.01, 1.0),
                          child: Container(
                            height: 6,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  AppColors.accentCyan,
                                  AppColors.accentEmerald,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                        // Indicator Thumb with Glowing Halo
                        Positioned(
                          left: thumbLeftOffset,
                          child: Container(
                            key: const Key('range_slider_thumb'),
                            width: thumbDiameter,
                            height: thumbDiameter,
                            decoration: BoxDecoration(
                              color: AppColors.accentCyan,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: const [
                                BoxShadow(
                                  color: AppColors.accentCyanGlow,
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 8),

          // Numerical Range Labels: Low | Current | High
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 52W Low
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '52W LOW',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        VaultPricingHelper.formatAmount(
                          effectiveRange.low52,
                          currency: activeCurrency,
                          isPrivacyMode: activePrivacy,
                          allowZero: true,
                        ),
                        key: const Key('range_low_value'),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Current Market Price
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'CURRENT',
                      style: TextStyle(
                        color: AppColors.accentCyan,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: Text(
                        VaultPricingHelper.formatAmount(
                          effectiveRange.currentPrice,
                          currency: activeCurrency,
                          isPrivacyMode: activePrivacy,
                          allowZero: true,
                        ),
                        key: const Key('range_current_value'),
                        style: const TextStyle(
                          color: AppColors.accentCyan,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 52W High
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      '52W HIGH',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        VaultPricingHelper.formatAmount(
                          effectiveRange.high52,
                          currency: activeCurrency,
                          isPrivacyMode: activePrivacy,
                          allowZero: true,
                        ),
                        key: const Key('range_high_value'),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
