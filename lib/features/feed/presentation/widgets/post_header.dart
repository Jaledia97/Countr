import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';

/// Reusable PostHeader component.
/// Displays Avatar (left), Username (@handle), Location pill/subtext,
/// and Timestamp (right).
class PostHeader extends StatelessWidget {
  final String username;
  final String avatarInitials;
  final String timestamp;
  final String locationTag;

  const PostHeader({
    super.key,
    required this.username,
    required this.avatarInitials,
    required this.timestamp,
    required this.locationTag,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar Icon (Left)
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [AppColors.accentViolet, AppColors.accentCyan],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accentCyan.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(2),
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surfaceRaised,
              ),
              alignment: Alignment.center,
              child: Text(
                avatarInitials,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Username & Location Tag
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        username,
                        style: AppTypography.heading2.copyWith(fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.verified_rounded,
                      size: 14,
                      color: AppColors.accentCyan,
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                // Subtext/Location Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: locationTag.startsWith('PULLED')
                        ? AppColors.accentAmber.withValues(alpha: 0.15)
                        : AppColors.surfaceHighlight,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: locationTag.startsWith('PULLED')
                          ? AppColors.accentAmber.withValues(alpha: 0.4)
                          : AppColors.surfaceBorder,
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        locationTag.startsWith('PULLED')
                            ? Icons.auto_awesome
                            : Icons.place_outlined,
                        size: 10,
                        color: locationTag.startsWith('PULLED')
                            ? AppColors.accentAmber
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          locationTag,
                          style: AppTypography.caption.copyWith(
                            color: locationTag.startsWith('PULLED')
                                ? AppColors.accentAmber
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Timestamp (Right)
          Text(
            timestamp,
            style: AppTypography.caption,
          ),
        ],
      ),
    );
  }
}
