import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/constants/app_typography.dart';
import 'package:countr/core/state/settings_state.dart';
import 'package:countr/features/vault/domain/vault_pricing_helper.dart';
import 'package:countr/features/values/domain/models/financial_analytics.dart';

/// Collector and investor financial P&L return widget.
///
/// Visualizes total cost basis, market value, absolute dollar return, and percentage
/// return color-coded for profit/loss, along with unit sub-metrics and privacy masking.
class CostBasisPnLWidget extends ConsumerWidget {
  /// Optional structured PnL model.
  final PnLResult? pnlResult;

  /// Acquisition price per single unit (fallback if [pnlResult] is not provided).
  final double? purchasePrice;

  /// Trimmed market average price per single unit (fallback if [pnlResult] is not provided).
  final double? marketPrice;

  /// Quantity of cards owned (defaults to 1).
  final int quantity;

  /// Display currency (defaults to active [baseCurrencyProvider]).
  final AppCurrency? currency;

  /// Explicit privacy mode toggle (defaults to active [privacyModeProvider]).
  final bool? isPrivacyMode;

  const CostBasisPnLWidget({
    super.key,
    this.pnlResult,
    this.purchasePrice,
    this.marketPrice,
    this.quantity = 1,
    this.currency,
    this.isPrivacyMode,
  });

  /// Convenience factory creating the widget directly from a [PnLResult].
  factory CostBasisPnLWidget.fromResult(
    PnLResult result, {
    Key? key,
    bool? isPrivacyMode,
  }) {
    return CostBasisPnLWidget(
      key: key,
      pnlResult: result,
      currency: result.currency,
      isPrivacyMode: isPrivacyMode,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppCurrency activeCurrency = currency ?? ref.watch(baseCurrencyProvider);
    final bool activePrivacy = isPrivacyMode ?? ref.watch(privacyModeProvider);

    // Compute or resolve PnLResult
    final pnl = pnlResult ??
        PnLResult.calculate(
          costBasisPerUnit: purchasePrice ?? 0.0,
          marketPricePerUnit: marketPrice ?? 0.0,
          quantity: quantity,
          currency: activeCurrency,
        );

    final isProfit = pnl.isProfit;
    final isLoss = pnl.isLoss;

    final Color statusColor;
    final IconData statusIcon;
    if (isProfit) {
      statusColor = AppColors.accentEmerald;
      statusIcon = Icons.trending_up_rounded;
    } else if (isLoss) {
      statusColor = AppColors.accentRose;
      statusIcon = Icons.trending_down_rounded;
    } else {
      statusColor = AppColors.textSecondary;
      statusIcon = Icons.trending_flat_rounded;
    }

    return Container(
      key: const Key('cost_basis_pnl_widget'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Title + Return Badge Pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 16,
                      color: AppColors.accentCyan,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Cost Basis & Return',
                        style: AppTypography.heading2.copyWith(fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Return Badge Pill
              Flexible(
                child: Container(
                  key: const Key('pnl_return_badge'),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            VaultPricingHelper.formatReturn(
                              pnl.dollarReturn,
                              pnl.percentageReturn,
                              currency: activeCurrency,
                              isPrivacyMode: activePrivacy,
                              amountFirst: true,
                            ),
                            key: const Key('pnl_return_badge_text'),
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
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

          // Primary Valuation Comparison: Cost Basis vs Market Value
          Row(
            children: [
              // Total Cost Basis
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHighlight.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.surfaceBorderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TOTAL COST BASIS',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          VaultPricingHelper.formatAmount(
                            pnl.costBasis,
                            currency: activeCurrency,
                            isPrivacyMode: activePrivacy,
                            allowZero: true,
                          ),
                          key: const Key('pnl_total_cost_basis'),
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 10),

              // Total Market Value
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHighlight.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.surfaceBorderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'MARKET VALUE',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          VaultPricingHelper.formatAmount(
                            pnl.marketValue,
                            currency: activeCurrency,
                            isPrivacyMode: activePrivacy,
                            allowZero: true,
                          ),
                          key: const Key('pnl_total_market_value'),
                          style: const TextStyle(
                            color: AppColors.accentCyan,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(color: AppColors.surfaceBorderSubtle, height: 1),
          const SizedBox(height: 10),

          // Sub-metrics Breakdown Row: Unit Cost | Current Avg | Owned Quantity
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Unit Cost
              Expanded(
                child: _buildSubMetric(
                  label: 'Unit Cost',
                  value: VaultPricingHelper.formatAmount(
                    pnl.unitCostBasis,
                    currency: activeCurrency,
                    isPrivacyMode: activePrivacy,
                    allowZero: true,
                  ),
                  key: const Key('pnl_sub_unit_cost'),
                ),
              ),
              Container(width: 1, height: 24, color: AppColors.surfaceBorderSubtle),
              // Current Avg
              Expanded(
                child: _buildSubMetric(
                  label: 'Current Avg',
                  value: VaultPricingHelper.formatAmount(
                    pnl.unitMarketPrice,
                    currency: activeCurrency,
                    isPrivacyMode: activePrivacy,
                    allowZero: true,
                  ),
                  key: const Key('pnl_sub_current_avg'),
                ),
              ),
              Container(width: 1, height: 24, color: AppColors.surfaceBorderSubtle),
              // Owned Qty
              Expanded(
                child: _buildSubMetric(
                  label: 'Owned',
                  value: '${pnl.quantity}x',
                  key: const Key('pnl_sub_owned_quantity'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubMetric({
    required String label,
    required String value,
    required Key key,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              key: key,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
