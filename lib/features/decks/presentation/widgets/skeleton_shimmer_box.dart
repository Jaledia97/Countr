// Copyright (c) 2026 Countr. All rights reserved.
// Skeleton shimmer box for placeholder loading states.

import 'package:flutter/material.dart';
import 'package:countr/core/constants/app_colors.dart';

/// Renders a skeleton shimmer box with smooth linear gradient animation
/// for card artwork and component loading states.
class SkeletonShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;
  final bool animate;

  const SkeletonShimmerBox({
    super.key,
    this.width = 44,
    this.height = 56,
    this.borderRadius,
    this.animate = true,
  });

  @override
  State<SkeletonShimmerBox> createState() => _SkeletonShimmerBoxState();
}

class _SkeletonShimmerBoxState extends State<SkeletonShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    if (widget.animate) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? BorderRadius.circular(8);
    if (!widget.animate) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: const LinearGradient(
            colors: [AppColors.surfaceRaised, AppColors.surfaceHighlight],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: AppColors.surfaceBorder),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              colors: const [
                AppColors.surfaceRaised,
                AppColors.surfaceHighlight,
                AppColors.surfaceRaised,
              ],
              stops: [
                (_controller.value - 0.3).clamp(0.0, 1.0),
                _controller.value,
                (_controller.value + 0.3).clamp(0.0, 1.0),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: AppColors.accentCyan.withValues(alpha: 0.2),
            ),
          ),
        );
      },
    );
  }
}
