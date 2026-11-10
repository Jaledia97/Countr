import 'package:flutter/material.dart';
import 'package:countr/core/constants/app_colors.dart';

/// Neon-accented verification badge rendered next to verified Local Game Store profiles.
class VerifiedStoreBadge extends StatelessWidget {
  final double iconSize;
  final double fontSize;
  final bool showLabel;
  final String label;

  const VerifiedStoreBadge({
    super.key,
    this.iconSize = 12.0,
    this.fontSize = 9.0,
    this.showLabel = true,
    this.label = 'VERIFIED LGS',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('verified_store_badge'),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: AppColors.accentAmber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: AppColors.accentAmber.withValues(alpha: 0.7),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentAmber.withValues(alpha: 0.2),
            blurRadius: 6,
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.storefront_rounded,
            size: iconSize,
            color: AppColors.accentAmber,
          ),
          if (showLabel) ...[
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: AppColors.accentAmber,
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
