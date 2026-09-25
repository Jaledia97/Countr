import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/constants/app_typography.dart';
import 'package:countr/core/state/settings_state.dart';
import 'package:countr/features/vault/domain/vault_pricing_helper.dart';
import 'package:countr/features/values/domain/models/financial_analytics.dart';

/// Liquidity and reality check widget comparing retail replacement vs buylist cash out.
class LiquidityRealityCheckWidget extends ConsumerWidget {
  /// Structured liquidity analysis model.
  final LiquidityAnalysis? liquidityAnalysis;

  /// Replacement retail market value per card.
  final double? marketPrice;

  /// Card quantity.
  final int quantity;

  /// Whether this card is on WotC's official Reserved List.
  final bool isReservedList;

  /// Explicit buylist cash out estimate.
  final double? explicitBuylistPrice;

  /// Active display currency.
  final AppCurrency? currency;

  /// Explicit privacy mode toggle.
  final bool? isPrivacyMode;

  const LiquidityRealityCheckWidget({
    super.key,
    this.liquidityAnalysis,
    this.marketPrice,
    this.quantity = 1,
    this.isReservedList = false,
    this.explicitBuylistPrice,
    this.currency,
    this.isPrivacyMode,
  });

  factory LiquidityRealityCheckWidget.fromAnalysis(
    LiquidityAnalysis analysis, {
    Key? key,
    bool? isPrivacyMode,
  }) {
    return LiquidityRealityCheckWidget(
      key: key,
      liquidityAnalysis: analysis,
      isReservedList: analysis.isReservedList,
      currency: analysis.currency,
      isPrivacyMode: isPrivacyMode,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppCurrency activeCurrency = currency ?? ref.watch(baseCurrencyProvider);
    final bool activePrivacy = isPrivacyMode ?? ref.watch(privacyModeProvider);

    final analysis = liquidityAnalysis ??
        LiquidityAnalysis.calculate(
          marketPrice: marketPrice ?? 0.0,
          quantity: quantity,
          currency: activeCurrency,
          isReservedList: isReservedList,
          explicitBuylistPrice: explicitBuylistPrice,
        );

    final tag = analysis.liquidityTag;
    final Color tagColor;
    final IconData tagIcon;
    final String tagLabel;

    switch (tag) {
      case LiquidityTag.high:
        tagColor = AppColors.accentEmerald;
        tagIcon = Icons.bolt_rounded;
        tagLabel = 'HIGH LIQUIDITY';
        break;
      case LiquidityTag.moderate:
        tagColor = AppColors.accentCyan;
        tagIcon = Icons.waves_rounded;
        tagLabel = 'MODERATE LIQUIDITY';
        break;
      case LiquidityTag.low:
        tagColor = AppColors.accentAmber;
        tagIcon = Icons.hourglass_bottom_rounded;
        tagLabel = 'LOW LIQUIDITY';
        break;
    }

    final haircutAmount = analysis.replacementValue - analysis.cashOutValue;
    final rateNormalized = (analysis.realizationRate / 100.0).clamp(0.0, 1.0);

    return Container(
      key: const Key('liquidity_reality_check_widget'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Title + Liquidity Tag Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.water_drop_outlined,
                      size: 16,
                      color: AppColors.accentCyan,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Liquidity Reality Check',
                        style: AppTypography.heading2.copyWith(fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Liquidity Tag Badge
              Flexible(
                child: Container(
                  key: const Key('liquidity_tag_badge'),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: tagColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: tagColor.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(tagIcon, size: 12, color: tagColor),
                      const SizedBox(width: 4),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            tagLabel,
                            key: const Key('liquidity_tag_label'),
                            style: TextStyle(
                              color: tagColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Comparative Values: Replacement Retail vs Cash Out Buylist
          Row(
            children: [
              // Replacement Value (Retail)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHighlight.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.surfaceBorderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'RETAIL REPLACEMENT',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          VaultPricingHelper.formatAmount(
                            analysis.replacementValue,
                            currency: activeCurrency,
                            isPrivacyMode: activePrivacy,
                            allowZero: true,
                          ),
                          key: const Key('liquidity_replacement_value'),
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Cost to buy singles',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: AppColors.textMuted,
                ),
              ),

              // Cash Out Value (Buylist)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHighlight.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.surfaceBorderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CASH OUT ESTIMATE',
                        style: TextStyle(
                          color: AppColors.accentAmber,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          VaultPricingHelper.formatAmount(
                            analysis.cashOutValue,
                            currency: activeCurrency,
                            isPrivacyMode: activePrivacy,
                            allowZero: true,
                          ),
                          key: const Key('liquidity_cash_out_value'),
                          style: const TextStyle(
                            color: AppColors.accentAmber,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Instant dealer buylist',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Realization Progress Gauge
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        activePrivacy
                            ? '**** Cash Realization'
                            : '${analysis.realizationRate.toStringAsFixed(0)}% Cash Realization',
                        key: const Key('liquidity_realization_rate_text'),
                        style: TextStyle(
                          color: tagColor,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        activePrivacy
                            ? 'Haircut: ****'
                            : 'Haircut: -${VaultPricingHelper.formatAmount(haircutAmount, currency: activeCurrency, isPrivacyMode: false, allowZero: true)}',
                        key: const Key('liquidity_haircut_text'),
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 6,
                  child: LinearProgressIndicator(
                    value: activePrivacy ? 0.5 : rateNormalized,
                    backgroundColor: AppColors.surfaceHighlight,
                    valueColor: AlwaysStoppedAnimation<Color>(tagColor),
                  ),
                ),
              ),
            ],
          ),

          // Reserved List Warning Badge (Conditional)
          if (analysis.isReservedList) ...[
            const SizedBox(height: 14),
            Container(
              key: const Key('reserved_list_warning_badge'),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.accentAmber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.accentAmber.withValues(alpha: 0.4)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.shield_rounded,
                    color: AppColors.accentAmber,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'RESERVED LIST CARD',
                          style: TextStyle(
                            color: AppColors.accentAmber,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Protected by WotC reprint policy. Cannot be reprinted in tournament-legal sets, ensuring long-term secondary market scarcity.',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 11,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
