import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/state/settings_state.dart';
import 'package:countr/features/values/domain/services/pareto_distribution_calculator.dart';
import 'package:countr/features/vault/domain/vault_pricing_helper.dart';

/// Data model representing an individual slice in the value concentration donut chart.
class PieSliceData {
  final int? rank; // 1..5 for top cards; null for 'Others'
  final String id;
  final String name;
  final double value;
  final double percentage;
  final Color color;
  final ParetoItem? item;

  const PieSliceData({
    this.rank,
    required this.id,
    required this.name,
    required this.value,
    required this.percentage,
    required this.color,
    this.item,
  });
}

/// Interactive custom canvas Donut Chart with polar touch hit testing, exploded slice offset,
/// center hole readout overlay badge, and full privacy mode support.
///
/// Zero external chart package dependencies.
class ValueConcentrationPieChart extends StatefulWidget {
  final List<PieSliceData> slices;
  final double totalDeckValue;
  final int topK;
  final double concentrationPercentage;
  final int? selectedIndex;
  final ValueChanged<int?>? onSliceSelected;
  final bool isPrivacyMode;
  final AppCurrency currency;
  final double size;

  const ValueConcentrationPieChart({
    super.key,
    required this.slices,
    required this.totalDeckValue,
    required this.topK,
    required this.concentrationPercentage,
    this.selectedIndex,
    this.onSliceSelected,
    this.isPrivacyMode = false,
    this.currency = AppCurrency.usd,
    this.size = 180.0,
  });

  @override
  State<ValueConcentrationPieChart> createState() => _ValueConcentrationPieChartState();
}

class _ValueConcentrationPieChartState extends State<ValueConcentrationPieChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _sweepAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _sweepAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.slices.isEmpty) return;

    final center = Offset(widget.size / 2, widget.size / 2);
    final touchVector = details.localPosition - center;
    final distance = touchVector.distance;

    final outerRadius = (widget.size / 2) - 10.0;
    final innerRadius = outerRadius * 0.58;

    // 1. Center hole tap -> deselect
    if (distance < innerRadius) {
      widget.onSliceSelected?.call(null);
      return;
    }

    // 2. Outside donut boundary tap -> deselect
    if (distance > outerRadius + 14.0) {
      widget.onSliceSelected?.call(null);
      return;
    }

    // 3. Polar angle calculation via math.atan2
    final rawAngle = math.atan2(touchVector.dy, touchVector.dx);

    // Normalize angle to start at 12 o'clock (-pi/2) and run clockwise [0 .. 2*pi)
    double angleFromTop = rawAngle - (-math.pi / 2);
    if (angleFromTop < 0) {
      angleFromTop += 2 * math.pi;
    }

    final totalVal = widget.slices.fold<double>(0.0, (sum, s) => sum + s.value);
    if (totalVal <= 0) return;

    double accumulatedAngle = 0.0;
    int? tappedIndex;

    for (int i = 0; i < widget.slices.length; i++) {
      final sweep = 2 * math.pi * (widget.slices[i].value / totalVal);
      if (angleFromTop >= accumulatedAngle && angleFromTop < accumulatedAngle + sweep) {
        tappedIndex = i;
        break;
      }
      accumulatedAngle += sweep;
    }

    // Fallback for floating point boundary at 2*pi
    tappedIndex ??= widget.slices.length - 1;

    // Toggle off if already selected
    if (widget.selectedIndex == tappedIndex) {
      widget.onSliceSelected?.call(null);
    } else {
      widget.onSliceSelected?.call(tappedIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.slices.isEmpty || widget.totalDeckValue <= 0) {
      return const SizedBox.shrink();
    }

    final outerRadius = (widget.size / 2) - 10.0;
    final innerRadius = outerRadius * 0.58;
    final centerHoleDiameter = innerRadius * 2 - 4.0;

    return Center(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Donut Chart Canvas
            AnimatedBuilder(
              animation: _sweepAnimation,
              builder: (context, _) {
                return RepaintBoundary(
                  child: CustomPaint(
                    size: Size(widget.size, widget.size),
                    painter: DonutChartPainter(
                      slices: widget.slices,
                      selectedIndex: widget.selectedIndex,
                      sweepProgress: _sweepAnimation.value,
                    ),
                  ),
                );
              },
            ),

            // Tap detector overlay
            GestureDetector(
              key: const Key('value_concentration_pie_gesture_detector'),
              behavior: HitTestBehavior.opaque,
              onTapUp: _handleTapUp,
              child: SizedBox(
                width: widget.size,
                height: widget.size,
              ),
            ),

            // Center Hole Readout Badge
            IgnorePointer(
              child: Container(
                key: const Key('donut_center_hole_badge'),
                width: centerHoleDiameter,
                height: centerHoleDiameter,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surface,
                  border: Border.all(
                    color: widget.selectedIndex != null
                        ? widget.slices[widget.selectedIndex!].color.withValues(alpha: 0.5)
                        : AppColors.surfaceBorderSubtle,
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: _buildCenterBadgeContent(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterBadgeContent() {
    if (widget.selectedIndex != null && widget.selectedIndex! < widget.slices.length) {
      final slice = widget.slices[widget.selectedIndex!];
      final formattedPrice = VaultPricingHelper.formatAmount(
        slice.value,
        currency: widget.currency,
        isPrivacyMode: widget.isPrivacyMode,
        allowZero: true,
      );
      final formattedShare = widget.isPrivacyMode
          ? '****'
          : '${slice.percentage.toStringAsFixed(1)}%';

      final String displayName = slice.name.length > 13
          ? '${slice.name.substring(0, 12)}…'
          : slice.name;

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: slice.color,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                slice.rank != null ? '#${slice.rank}' : 'OTHERS',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: slice.color,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            displayName,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
          ),
          const SizedBox(height: 2),
          Text(
            formattedPrice,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              color: AppColors.accentAmber,
            ),
          ),
          Text(
            formattedShare,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: slice.color,
            ),
          ),
        ],
      );
    }

    // Default Unselected Aggregate State
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(
          Icons.touch_app_outlined,
          size: 15,
          color: AppColors.accentCyan,
        ),
        const SizedBox(height: 2),
        Text(
          widget.topK > 0 ? 'TOP ${widget.topK}' : 'CONCENTRATION',
          style: const TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            color: AppColors.accentCyan,
          ),
        ),
        const SizedBox(height: 1),
        const Text(
          'TAP SLICE',
          style: TextStyle(
            fontSize: 7.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

/// CustomPainter rendering Donut arcs with gap spacing and exploded offset.
class DonutChartPainter extends CustomPainter {
  final List<PieSliceData> slices;
  final int? selectedIndex;
  final double sweepProgress;

  DonutChartPainter({
    required this.slices,
    this.selectedIndex,
    this.sweepProgress = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (slices.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = (size.width / 2) - 10.0;
    final innerRadius = outerRadius * 0.58;
    final strokeWidth = outerRadius - innerRadius;
    final midRadius = (outerRadius + innerRadius) / 2;

    final totalVal = slices.fold<double>(0.0, (sum, s) => sum + s.value);
    if (totalVal <= 0) return;

    double currentAngle = -math.pi / 2; // Start at 12 o'clock
    final totalSweepLimit = 2 * math.pi * sweepProgress;
    double accumulatedSweep = 0.0;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    for (int i = 0; i < slices.length; i++) {
      final slice = slices[i];
      final fullSweep = 2 * math.pi * (slice.value / totalVal);

      if (accumulatedSweep >= totalSweepLimit) break;
      final remainingSweepLimit = totalSweepLimit - accumulatedSweep;
      final sweep = math.min(fullSweep, remainingSweepLimit);

      // Adaptive gap: single slice has 0 gap; multi-slice has min(0.035, sweep * 0.2)
      final double gap = (slices.length > 1 && sweep > 0.08)
          ? 0.035
          : (slices.length > 1 ? sweep * 0.20 : 0.0);
      final drawSweep = math.max(0.002, sweep - gap);
      final drawStart = currentAngle + (gap / 2);

      final isSelected = (selectedIndex == i);

      if (isSelected) {
        final bisectAngle = currentAngle + (fullSweep / 2);
        const double explodeDist = 6.0;
        final dx = math.cos(bisectAngle) * explodeDist;
        final dy = math.sin(bisectAngle) * explodeDist;

        canvas.save();
        canvas.translate(dx, dy);

        // Highlight outer glow stroke
        final glowPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth + 3.0
          ..color = slice.color.withValues(alpha: 0.35);
        final sliceRect = Rect.fromCircle(center: center, radius: midRadius);
        canvas.drawArc(sliceRect, drawStart, drawSweep, false, glowPaint);

        // Primary slice arc
        paint.color = slice.color;
        canvas.drawArc(sliceRect, drawStart, drawSweep, false, paint);

        canvas.restore();
      } else {
        // Dim unselected slices if one slice is active
        if (selectedIndex != null) {
          paint.color = slice.color.withValues(alpha: 0.45);
        } else {
          paint.color = slice.color;
        }
        final sliceRect = Rect.fromCircle(center: center, radius: midRadius);
        canvas.drawArc(sliceRect, drawStart, drawSweep, false, paint);
      }

      currentAngle += fullSweep;
      accumulatedSweep += fullSweep;
    }
  }

  @override
  bool shouldRepaint(covariant DonutChartPainter oldDelegate) {
    return oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.sweepProgress != sweepProgress ||
        oldDelegate.slices != slices;
  }
}
