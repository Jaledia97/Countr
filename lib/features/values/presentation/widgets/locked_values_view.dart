import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/constants/app_typography.dart';
import 'package:countr/core/state/settings_state.dart';

/// Locked UI state displayed when accessing financial data with Privacy Mode enabled.
///
/// Mandated requirements:
/// - Verbatim text: "Values hidden. Disable Privacy Mode to view market data."
/// - Lock icon: Icons.lock_outline_rounded
/// - Unlock button: "Disable Privacy Mode" toggling privacyModeProvider to false.
class LockedValuesView extends ConsumerWidget {
  const LockedValuesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      key: const Key('locked_values_view'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceRaised,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.accentAmber.withValues(alpha: 0.4),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentAmber.withValues(alpha: 0.1),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                key: Key('locked_values_lock_icon'),
                size: 36,
                color: AppColors.accentAmber,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Values hidden. Disable Privacy Mode to view market data.',
              key: const Key('locked_values_tab_message'),
              textAlign: TextAlign.center,
              style: AppTypography.heading2.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              key: const Key('locked_values_disable_privacy_button'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentAmber,
                foregroundColor: AppColors.textDark,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.visibility_rounded, size: 18),
              label: const Text(
                'Disable Privacy Mode',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              onPressed: () {
                ref.read(privacyModeProvider.notifier).state = false;
              },
            ),
          ],
        ),
      ),
    );
  }
}
