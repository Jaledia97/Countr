import 'package:flutter/material.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/constants/app_typography.dart';

/// Bottom action bar displayed during multi-selection mode in "My Decks".
/// Enforces the strict rule that "Share to Explore" is enabled strictly when
/// exactly 1 deck is selected.
class MyDecksSelectionFooter extends StatelessWidget {
  final int selectedCount;
  final VoidCallback? onShareToExplore;
  final VoidCallback? onCancel;

  const MyDecksSelectionFooter({
    super.key,
    required this.selectedCount,
    this.onShareToExplore,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final bool canShare = selectedCount == 1;

    return Container(
      key: const Key('my_decks_selection_footer'),
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: const Border(
          top: BorderSide(color: AppColors.surfaceBorder, width: 1.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Close / Cancel selection mode
          IconButton(
            key: const Key('selection_cancel_button'),
            icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
            tooltip: 'Exit selection mode',
            onPressed: onCancel,
          ),
          const SizedBox(width: 8),

          // Selected count
          Expanded(
            child: Text(
              '$selectedCount selected',
              style: AppTypography.heading2.copyWith(
                fontSize: 14,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // "Share to Explore" action button (enabled strictly when count == 1)
          ElevatedButton.icon(
            key: const Key('selection_share_to_explore_button'),
            onPressed: canShare ? onShareToExplore : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentCyan,
              foregroundColor: AppColors.textDark,
              disabledBackgroundColor: AppColors.surfaceHighlight,
              disabledForegroundColor: AppColors.textMuted,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            icon: const Icon(Icons.share_rounded, size: 16),
            label: const Text(
              'Share to Explore',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
