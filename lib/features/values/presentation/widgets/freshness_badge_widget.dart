import 'package:flutter/material.dart';
import 'package:countr/core/constants/app_colors.dart';

/// Capsule badge displaying relative data freshness with an animated live pulse dot.
class FreshnessBadgeWidget extends StatefulWidget {
  /// The timestamp of the last market price synchronization.
  final DateTime? lastUpdated;

  /// Optional custom label overriding the relative timestamp calculation.
  final String? customLabel;

  /// Optional callback when user taps the freshness badge.
  final VoidCallback? onTap;

  /// Whether the pulse dot should continuously animate. Defaults to true.
  final bool animate;

  const FreshnessBadgeWidget({
    super.key,
    this.lastUpdated,
    this.customLabel,
    this.onTap,
    this.animate = true,
  });

  @override
  State<FreshnessBadgeWidget> createState() => _FreshnessBadgeWidgetState();
}

class _FreshnessBadgeWidgetState extends State<FreshnessBadgeWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    if (widget.animate) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.value = 1.0;
    }

    _pulseAnimation = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String _formatRelativeTime(DateTime? date) {
    if (widget.customLabel != null && widget.customLabel!.isNotEmpty) {
      return widget.customLabel!;
    }
    if (date == null) return 'Updated just now';

    final diff = DateTime.now().difference(date);
    if (diff.inSeconds < 60) {
      return 'Updated just now';
    } else if (diff.inMinutes < 60) {
      return 'Updated ${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return 'Updated ${diff.inHours}h ago';
    } else {
      return 'Updated ${diff.inDays}d ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = _formatRelativeTime(widget.lastUpdated);

    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        key: const Key('freshness_badge_widget'),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Live Pulsing Dot
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.accentEmerald.withValues(alpha: _pulseAnimation.value),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accentEmerald.withValues(alpha: _pulseAnimation.value * 0.5),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(width: 6),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  key: const Key('freshness_badge_label'),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
