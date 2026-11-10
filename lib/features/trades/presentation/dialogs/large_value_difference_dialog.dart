import 'package:flutter/material.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/constants/app_typography.dart';

/// Modal dialog shown before proposing or accepting a trade when a significant value
/// discrepancy (>= 15% OR >= $10.00) exists.
class LargeValueDifferenceDialog extends StatelessWidget {
  final double dollarGap;
  final double percentGap;

  const LargeValueDifferenceDialog({
    super.key,
    required this.dollarGap,
    required this.percentGap,
  });

  /// Intercepts a proposal or acceptance action if [dollarGap] >= $10.00 OR [percentGap] >= 15.0%.
  /// Returns `true` if the user elects to "Proceed Anyway", or if no safeguard warning is required.
  /// Returns `false` if the user clicks "Review Trade" or cancels.
  static Future<bool> checkAndConfirm({
    required BuildContext context,
    required double dollarGap,
    required double percentGap,
  }) async {
    // If within safe thresholds, pass through immediately
    if (dollarGap < 10.0 && percentGap < 15.0) {
      return true;
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => LargeValueDifferenceDialog(
        dollarGap: dollarGap,
        percentGap: percentGap,
      ),
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('large_value_difference_dialog'),
      backgroundColor: AppColors.surfaceRaised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.accentRose, width: 1.2),
      ),
      title: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.accentRose,
            size: 24,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Large Value Difference Detected',
              style: AppTypography.heading2.copyWith(
                color: AppColors.textPrimary,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      content: Text(
        'There is a \$${dollarGap.toStringAsFixed(2)} (${percentGap.toStringAsFixed(1)}%) value gap in this trade. Are you sure you want to proceed?',
        style: AppTypography.body.copyWith(
          color: AppColors.textSecondary,
          fontSize: 14,
        ),
      ),
      actions: [
        TextButton(
          key: const Key('review_trade_button'),
          onPressed: () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          child: const Text('Review Trade'),
        ),
        ElevatedButton(
          key: const Key('proceed_anyway_button'),
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentRose,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            'Proceed Anyway',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
