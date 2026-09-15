import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

/// ManaBox-style dynamic reactive scanning reticle overlay that animates
/// and snaps corner brackets in real-time to detected card coordinates.
class DynamicScannerOverlay extends StatelessWidget {
  /// The detected bounding box of the card in screen coordinates.
  final Rect? cardBounds;

  /// Whether a card match has just been confirmed (triggers emerald green flash).
  final bool isGreenFlash;

  /// Whether scanning is currently paused (triggers amber battery-saver state).
  final bool isPaused;

  /// Vertical scanning laser animation (bounded within the dynamic rect).
  final Animation<double>? scanLineAnimation;

  const DynamicScannerOverlay({
    super.key,
    required this.cardBounds,
    required this.isGreenFlash,
    required this.isPaused,
    this.scanLineAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return _DynamicReticleContent(
      cardBounds: cardBounds,
      isGreenFlash: isGreenFlash,
      isPaused: isPaused,
      scanLineAnimation: scanLineAnimation,
    );
  }
}

class _DynamicReticleContent extends StatefulWidget {
  final Rect? cardBounds;
  final bool isGreenFlash;
  final bool isPaused;
  final Animation<double>? scanLineAnimation;

  const _DynamicReticleContent({
    required this.cardBounds,
    required this.isGreenFlash,
    required this.isPaused,
    this.scanLineAnimation,
  });

  @override
  State<_DynamicReticleContent> createState() => _DynamicReticleContentState();
}

class _DynamicReticleContentState extends State<_DynamicReticleContent> {
  Rect? _lastNonNullBounds;

  @override
  void initState() {
    super.initState();
    if (widget.cardBounds != null) {
      _lastNonNullBounds = widget.cardBounds;
    }
  }

  @override
  void didUpdateWidget(covariant _DynamicReticleContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.cardBounds != null) {
      _lastNonNullBounds = widget.cardBounds;
    }
  }

  Color get _themeColor {
    if (widget.isPaused) return AppColors.accentAmber;
    if (widget.isGreenFlash) return AppColors.accentEmerald;
    return AppColors.accentCyan;
  }

  @override
  Widget build(BuildContext context) {
    final activeBounds = widget.cardBounds ?? _lastNonNullBounds;
    final isVisible = widget.cardBounds != null && activeBounds != null;

    if (activeBounds == null) {
      return const SizedBox.shrink(key: Key('dynamic_scanner_overlay_empty'));
    }

    return IgnorePointer(
      child: AnimatedOpacity(
        key: const Key('dynamic_scanner_overlay'),
        opacity: isVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        child: TweenAnimationBuilder<Rect?>(
          tween: RectTween(end: activeBounds),
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          builder: (context, currentRect, child) {
            if (currentRect == null ||
                currentRect.width <= 0 ||
                currentRect.height <= 0) {
              return const SizedBox.shrink();
            }

            final theme = _themeColor;
            final cornerLength = math.min(
              28.0,
              math.min(currentRect.width, currentRect.height) * 0.25,
            );
            final thickness = widget.isGreenFlash ? 3.5 : 3.0;

            return Stack(
              children: [
                // Subtle Card Perimeter Outline & Ambient Glow
                Positioned.fromRect(
                  rect: currentRect,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.withValues(
                          alpha: widget.isGreenFlash ? 0.9 : 0.35,
                        ),
                        width: widget.isGreenFlash ? 2.5 : 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: theme.withValues(
                            alpha: widget.isGreenFlash
                                ? 0.45
                                : (widget.isPaused ? 0.25 : 0.15),
                          ),
                          blurRadius: widget.isGreenFlash ? 24 : 14,
                          spreadRadius: widget.isGreenFlash ? 3 : 1,
                        ),
                      ],
                    ),
                  ),
                ),

                // Top-Left Corner Bracket
                Positioned(
                  left: currentRect.left,
                  top: currentRect.top,
                  width: cornerLength,
                  height: cornerLength,
                  child: CustomPaint(
                    key: const Key('corner_bracket_tl'),
                    painter: _DynamicCornerPainter(
                      isTop: true,
                      isLeft: true,
                      thickness: thickness,
                      color: theme,
                    ),
                  ),
                ),

                // Top-Right Corner Bracket
                Positioned(
                  left: currentRect.right - cornerLength,
                  top: currentRect.top,
                  width: cornerLength,
                  height: cornerLength,
                  child: CustomPaint(
                    key: const Key('corner_bracket_tr'),
                    painter: _DynamicCornerPainter(
                      isTop: true,
                      isLeft: false,
                      thickness: thickness,
                      color: theme,
                    ),
                  ),
                ),

                // Bottom-Left Corner Bracket
                Positioned(
                  left: currentRect.left,
                  top: currentRect.bottom - cornerLength,
                  width: cornerLength,
                  height: cornerLength,
                  child: CustomPaint(
                    key: const Key('corner_bracket_bl'),
                    painter: _DynamicCornerPainter(
                      isTop: false,
                      isLeft: true,
                      thickness: thickness,
                      color: theme,
                    ),
                  ),
                ),

                // Bottom-Right Corner Bracket
                Positioned(
                  left: currentRect.right - cornerLength,
                  top: currentRect.bottom - cornerLength,
                  width: cornerLength,
                  height: cornerLength,
                  child: CustomPaint(
                    key: const Key('corner_bracket_br'),
                    painter: _DynamicCornerPainter(
                      isTop: false,
                      isLeft: false,
                      thickness: thickness,
                      color: theme,
                    ),
                  ),
                ),

                // Laser Scan Line Bounded Within Dynamic Card Coordinates
                if (widget.scanLineAnimation != null && !widget.isPaused)
                  AnimatedBuilder(
                    animation: widget.scanLineAnimation!,
                    builder: (context, _) {
                      final laserY = currentRect.top +
                          (currentRect.height *
                              widget.scanLineAnimation!.value.clamp(0.0, 1.0));
                      final laserWidth =
                          math.max(0.0, currentRect.width - 8.0);

                      return Positioned(
                        key: const Key('bounded_laser_scan_line'),
                        left: currentRect.left + 4.0,
                        top: laserY - 1.25,
                        width: laserWidth,
                        height: 2.5,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                theme.withValues(alpha: 0.8),
                                Colors.white,
                                theme.withValues(alpha: 0.8),
                                Colors.transparent,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: theme.withValues(alpha: 0.7),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DynamicCornerPainter extends CustomPainter {
  final bool isTop;
  final bool isLeft;
  final double thickness;
  final Color color;

  const _DynamicCornerPainter({
    required this.isTop,
    required this.isLeft,
    required this.thickness,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    if (isTop && isLeft) {
      path.moveTo(0, size.height);
      path.lineTo(0, 0);
      path.lineTo(size.width, 0);
    } else if (isTop && !isLeft) {
      path.moveTo(size.width, size.height);
      path.lineTo(size.width, 0);
      path.lineTo(0, 0);
    } else if (!isTop && isLeft) {
      path.moveTo(0, 0);
      path.lineTo(0, size.height);
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(size.width, 0);
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _DynamicCornerPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.thickness != thickness ||
      oldDelegate.isTop != isTop ||
      oldDelegate.isLeft != isLeft;
}
