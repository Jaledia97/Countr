import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/constants/app_typography.dart';
import 'package:countr/features/auth/presentation/providers/auth_providers.dart';
import 'package:countr/features/auth/presentation/widgets/auth_modal_sheet.dart';

enum QuotaResource { binder, deck }

class QuotaLimitPromptSheet extends ConsumerWidget {
  final QuotaResource resource;

  const QuotaLimitPromptSheet({
    super.key,
    required this.resource,
  });

  static Future<void> showForBinders(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const QuotaLimitPromptSheet(resource: QuotaResource.binder),
    );
  }

  static Future<void> showForDecks(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const QuotaLimitPromptSheet(resource: QuotaResource.deck),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isGuest = user.isGuest;
    final resourceName = resource == QuotaResource.binder ? 'Binder' : 'Deck';

    return Container(
      key: const Key('quota_limit_prompt_sheet'),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.surfaceBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header Icon
          Center(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: (isGuest ? AppColors.accentCyan : AppColors.accentAmber)
                    .withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isGuest ? Icons.lock_open_rounded : Icons.workspace_premium_rounded,
                color: isGuest ? AppColors.accentCyan : AppColors.accentAmber,
                size: 32,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Title
          Text(
            isGuest
                ? 'Guest $resourceName Limit Reached'
                : 'Free Tier $resourceName Limit Reached',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),

          // Subtitle
          Text(
            isGuest
                ? 'Guests can create up to 2 custom binders and 3 decks. Create a free account to expand your limits and preserve your collection across devices!'
                : 'Free accounts are limited to 3 custom binders and 5 decks. Upgrade to Countr Pro for unlimited portfolios, decks, and advanced market price updates!',
            textAlign: TextAlign.center,
            style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 18),

          // Benefits Checklist
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceRaised,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.surfaceBorder),
            ),
            child: Column(
              children: [
                _buildBenefitRow(
                  Icons.check_circle_outline,
                  isGuest ? 'Unlock 3 custom binders & 5 decks' : 'Unlimited custom binders & decks',
                ),
                const SizedBox(height: 8),
                _buildBenefitRow(
                  Icons.check_circle_outline,
                  'Permanent system binders ("Looking For" & "Trade Block")',
                ),
                const SizedBox(height: 8),
                _buildBenefitRow(
                  Icons.check_circle_outline,
                  isGuest ? 'Cloud backup & multi-device sync' : '3:00 AM daily automated market price sync',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Primary CTA Button
          ElevatedButton(
            key: isGuest
                ? const Key('quota_prompt_register_button')
                : const Key('quota_prompt_upgrade_pro_button'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isGuest ? AppColors.accentCyan : AppColors.accentAmber,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              if (isGuest) {
                AuthModalSheet.show(context);
              } else {
                // Pro tier upgrade simulation
                ref.read(currentUserProvider.notifier).setUser(
                      user.copyWith(tier: AccountTier.pro),
                    );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Upgraded to Countr Pro! Unlimited limits unlocked.'),
                    backgroundColor: AppColors.accentEmerald,
                  ),
                );
              }
            },
            child: Text(
              isGuest ? 'Create Free Account' : 'Upgrade to Countr Pro',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
          ),
          const SizedBox(height: 8),

          // Dismiss Button
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Maybe Later', style: TextStyle(color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: AppColors.accentEmerald, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
