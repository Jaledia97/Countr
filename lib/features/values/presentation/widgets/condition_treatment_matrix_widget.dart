import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/constants/app_typography.dart';
import 'package:countr/core/state/settings_state.dart';
import 'package:countr/features/vault/domain/vault_pricing_helper.dart';
import 'package:countr/features/values/domain/models/financial_analytics.dart';

/// 3x3 pricing grid mapping condition tiers against finish treatments.
class ConditionTreatmentMatrixWidget extends ConsumerWidget {
  /// Structured matrix model.
  final ConditionTreatmentMatrix? matrix;

  /// Baseline NM prices if matrix is not directly passed.
  final double? baseNonFoil;
  final double? baseFoil;
  final double? baseEtched;

  /// The condition of the user's owned card (e.g. 'NM', 'LP', 'MP').
  final String ownedCondition;

  /// The finish treatment of the user's owned card (e.g. 'non_foil', 'foil', 'etched').
  final String ownedFinish;

  /// Active display currency.
  final AppCurrency? currency;

  /// Explicit privacy mode toggle.
  final bool? isPrivacyMode;

  /// Callback when user taps any matrix cell.
  final void Function(String condition, String finish, double price)? onCellSelected;

  const ConditionTreatmentMatrixWidget({
    super.key,
    this.matrix,
    this.baseNonFoil,
    this.baseFoil,
    this.baseEtched,
    this.ownedCondition = 'NM',
    this.ownedFinish = 'non_foil',
    this.currency,
    this.isPrivacyMode,
    this.onCellSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppCurrency activeCurrency = currency ?? ref.watch(baseCurrencyProvider);
    final bool activePrivacy = isPrivacyMode ?? ref.watch(privacyModeProvider);

    final effectiveMatrix = matrix ??
        ConditionTreatmentMatrix.compute(
          baseNonFoil: baseNonFoil ?? 0.0,
          baseFoil: baseFoil ?? 0.0,
          baseEtched: baseEtched ?? 0.0,
          currency: activeCurrency,
        );

    const conditions = ['NM', 'LP', 'MP'];
    const finishes = [
      {'key': 'non_foil', 'label': 'Non-Foil'},
      {'key': 'foil', 'label': 'Foil'},
      {'key': 'etched', 'label': 'Etched'},
    ];

    final normalizedOwnedCond = ownedCondition.toUpperCase().trim();
    final normalizedOwnedFinish = ownedFinish.toLowerCase().trim().replaceAll('-', '_');

    return Container(
      key: const Key('condition_treatment_matrix_widget'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Title + Subtitle
          Row(
            children: [
              const Icon(
                Icons.grid_view_rounded,
                size: 16,
                color: AppColors.accentCyan,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Condition & Finish Spreads',
                  style: AppTypography.heading2.copyWith(fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Estimated market values across degradation tiers and card printings.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),

          const SizedBox(height: 14),

          // Column Headers Row (Non-Foil, Foil, Etched)
          Row(
            children: [
              const SizedBox(width: 38), // Space for row label (NM/LP/MP)
              for (final f in finishes)
                Expanded(
                  child: Center(
                    child: Text(
                      f['label']!,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 8),

          // 3 Data Rows (NM, LP, MP)
          for (final cond in conditions) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  // Row Header (Condition Badge)
                  SizedBox(
                    width: 38,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceHighlight,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        cond,
                        style: TextStyle(
                          color: cond == 'NM'
                              ? AppColors.accentEmerald
                              : cond == 'LP'
                                  ? AppColors.accentCyan
                                  : AppColors.accentAmber,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),

                  // 3 Treatment Cells
                  for (final f in finishes) ...[
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildMatrixCell(
                        condition: cond,
                        finishKey: f['key']!,
                        finishLabel: f['label']!,
                        price: effectiveMatrix.getPrice(cond, f['key']!),
                        isCurrent: cond == normalizedOwnedCond &&
                            (f['key'] == normalizedOwnedFinish ||
                                (normalizedOwnedFinish.contains('foil') &&
                                    !normalizedOwnedFinish.contains('etched') &&
                                    f['key'] == 'foil')),
                        currency: activeCurrency,
                        isPrivacyMode: activePrivacy,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMatrixCell({
    required String condition,
    required String finishKey,
    required String finishLabel,
    required double price,
    required bool isCurrent,
    required AppCurrency currency,
    required bool isPrivacyMode,
  }) {
    final cellKey = Key('matrix_cell_${condition}_$finishKey');

    return InkWell(
      onTap: () => onCellSelected?.call(condition, finishKey, price),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: isCurrent
              ? AppColors.accentCyan.withValues(alpha: 0.14)
              : AppColors.surfaceHighlight.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isCurrent ? AppColors.accentCyan : AppColors.surfaceBorderSubtle,
            width: isCurrent ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (isCurrent) ...[
              Container(
                key: Key('matrix_badge_current_${condition}_$finishKey'),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.accentCyan,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: const Text(
                  'CURRENT',
                  style: TextStyle(
                    color: AppColors.textDark,
                    fontSize: 7.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(height: 2),
            ],
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                VaultPricingHelper.formatAmount(
                  price,
                  currency: currency,
                  isPrivacyMode: isPrivacyMode,
                  allowZero: true,
                ),
                key: cellKey,
                style: TextStyle(
                  color: isCurrent ? AppColors.accentCyan : AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
