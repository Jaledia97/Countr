// Copyright (c) 2026 Countr. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Production widget for the synchronized pod-wide Day/Night cycle toggle (Feature 39).
///
/// Features:
/// - Toggles between ☀️ Day and 🌙 Night across all player quadrants simultaneously.
/// - Warm golden solar radial gradient and amber styling for Day.
/// - Celestial twilight blue/indigo radial gradient and silver styling for Night.
/// - Smooth animated transitions via [AnimatedContainer].
/// - Tactile haptic feedback on state flip.
class DayNightToggleWidget extends StatelessWidget {
  final bool isDay;
  final VoidCallback? onToggle;
  final bool isCompact;

  const DayNightToggleWidget({
    super.key,
    required this.isDay,
    this.onToggle,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = isDay ? const Color(0xFFFFB300) : const Color(0xFF7986CB);
    final bgColor = isDay
        ? const Color(0xFF3E2723).withValues(alpha: 0.8)
        : const Color(0xFF1A237E).withValues(alpha: 0.8);

    return GestureDetector(
      key: const Key('day_night_toggle'),
      onTap: () {
        HapticFeedback.mediumImpact();
        onToggle?.call();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: isCompact
            ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
            : const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: activeColor.withValues(alpha: 0.6), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: activeColor.withValues(alpha: 0.3),
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isDay ? Icons.wb_sunny : Icons.nightlight_round,
              size: isCompact ? 14 : 18,
              color: activeColor,
            ),
            const SizedBox(width: 6),
            Text(
              isDay ? 'Day' : 'Night',
              key: const Key('day_night_label'),
              style: TextStyle(
                color: activeColor,
                fontWeight: FontWeight.bold,
                fontSize: isCompact ? 11 : 13,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
