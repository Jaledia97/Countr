import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/constants/app_typography.dart';
import 'package:countr/core/state/settings_state.dart';
import 'package:countr/features/vault/domain/vault_pricing_helper.dart';

String _formatChartDate(DateTime d, {bool includeYear = false}) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  final monthStr = months[d.month - 1];
  if (includeYear) {
    return '$monthStr ${d.day}, ${d.year}';
  }
  return '$monthStr ${d.day}';
}

// ============================================================================
// 1. Domain Models
// ============================================================================

/// The 5 supported historical time horizons for financial price series.
enum ChartTimeHorizon {
  sevenDays('7D', Duration(days: 7), '7 Days'),
  thirtyDays('30D', Duration(days: 30), '30 Days'),
  ninetyDays('90D', Duration(days: 90), '90 Days'),
  oneYear('1Y', Duration(days: 365), '1 Year'),
  allTime('ALL', Duration(days: 1825), 'All Time');

  final String label;
  final Duration duration;
  final String fullLabel;

  const ChartTimeHorizon(this.label, this.duration, this.fullLabel);
}

/// Supported collectible marketplaces rendered as individual curves.
enum MarketVendor {
  tcgplayer(
    id: 'tcgplayer',
    displayName: 'TCGplayer',
    color: Color(0xFF3B82F6), // Blue
    nativeCurrency: AppCurrency.usd,
  ),
  cardmarket(
    id: 'cardmarket',
    displayName: 'Cardmarket',
    color: Color(0xFFF59E0B), // Amber
    nativeCurrency: AppCurrency.eur,
  ),
  ebay(
    id: 'ebay',
    displayName: 'eBay',
    color: Color(0xFF8B5CF6), // Violet
    nativeCurrency: AppCurrency.usd,
  ),
  cardKingdom(
    id: 'card_kingdom',
    displayName: 'Card Kingdom',
    color: Color(0xFFF43F5E), // Rose
    nativeCurrency: AppCurrency.usd,
  ),
  manapool(
    id: 'manapool',
    displayName: 'Manapool',
    color: Color(0xFF14B8A6), // Teal
    nativeCurrency: AppCurrency.usd,
  );

  final String id;
  final String displayName;
  final Color color;
  final AppCurrency nativeCurrency;

  const MarketVendor({
    required this.id,
    required this.displayName,
    required this.color,
    required this.nativeCurrency,
  });
}

/// A discrete price observation at a specific point in time.
@immutable
class ChartPoint {
  final DateTime timestamp;
  final double price;

  const ChartPoint({
    required this.timestamp,
    required this.price,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChartPoint &&
          runtimeType == other.runtimeType &&
          timestamp == other.timestamp &&
          price == other.price;

  @override
  int get hashCode => timestamp.hashCode ^ price.hashCode;
}

/// A continuous curve of price points for either the Trimmed Average or a Vendor.
@immutable
class ChartSeries {
  final String id;
  final String label;
  final Color color;
  final double strokeWidth;
  final bool isTrimmedAverage;
  final List<ChartPoint> points;

  const ChartSeries({
    required this.id,
    required this.label,
    required this.color,
    this.strokeWidth = 1.5,
    this.isTrimmedAverage = false,
    required this.points,
  });

  bool get isEmpty => points.isEmpty;
  bool get isNotEmpty => points.isNotEmpty;

  double get minPrice =>
      points.isEmpty ? 0.0 : points.map((p) => p.price).reduce(math.min);
  double get maxPrice =>
      points.isEmpty ? 0.0 : points.map((p) => p.price).reduce(math.max);
}

/// The complete snapshot of financial curves for a given horizon.
@immutable
class MultiLineChartData {
  final ChartTimeHorizon horizon;
  final AppCurrency currency;
  final ChartSeries trimmedAverage;
  final Map<MarketVendor, ChartSeries> vendorSeries;

  const MultiLineChartData({
    required this.horizon,
    required this.currency,
    required this.trimmedAverage,
    required this.vendorSeries,
  });
}

// ============================================================================
// 2. Interactive Multi-Line Chart Widget
// ============================================================================

/// High-performance zero-dependency multi-line chart visualizing market price
/// history, vendor spreads, and trimmed market average.
class InteractiveMultiLineChart extends ConsumerStatefulWidget {
  final MultiLineChartData? data;
  final double? fallbackCurrentPrice;
  final bool? isPrivacyMode;
  final ValueChanged<ChartTimeHorizon>? onHorizonChanged;
  final ValueChanged<Set<MarketVendor>>? onVendorsChanged;

  const InteractiveMultiLineChart({
    super.key,
    this.data,
    this.fallbackCurrentPrice,
    this.isPrivacyMode,
    this.onHorizonChanged,
    this.onVendorsChanged,
  });

  @override
  ConsumerState<InteractiveMultiLineChart> createState() =>
      _InteractiveMultiLineChartState();
}

class _InteractiveMultiLineChartState
    extends ConsumerState<InteractiveMultiLineChart> {
  late ChartTimeHorizon _selectedHorizon;
  late Set<MarketVendor> _selectedVendors;
  Offset? _touchPosition;

  @override
  void initState() {
    super.initState();
    _selectedHorizon = widget.data?.horizon ?? ChartTimeHorizon.thirtyDays;
    _selectedVendors = {
      MarketVendor.tcgplayer,
      MarketVendor.cardmarket,
      MarketVendor.ebay,
      MarketVendor.cardKingdom,
      MarketVendor.manapool,
    };
  }

  @override
  void didUpdateWidget(covariant InteractiveMultiLineChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.data != null && widget.data!.horizon != _selectedHorizon) {
      _selectedHorizon = widget.data!.horizon;
    }
  }

  bool get _effectivePrivacyMode =>
      widget.isPrivacyMode ?? ref.watch(privacyModeProvider);

  AppCurrency get _effectiveCurrency =>
      widget.data?.currency ?? ref.watch(baseCurrencyProvider);

  MultiLineChartData _resolveData() {
    if (widget.data != null) return widget.data!;
    return _generateSampleChartData(
      _selectedHorizon,
      _effectiveCurrency,
      widget.fallbackCurrentPrice ?? 15.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final chartData = _resolveData();

    return Container(
      key: const Key('interactive_multi_line_chart_container'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Header & Time Horizon Selector
          _buildHeaderAndHorizons(),

          const SizedBox(height: 12),

          // 2. Interactive Chart Canvas + Tooltip Stack
          _buildChartCanvasArea(chartData),

          const SizedBox(height: 12),

          // 3. Vendor Toggle Legend
          _buildVendorToggleLegend(),
        ],
      ),
    );
  }

  Widget _buildHeaderAndHorizons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Market Price History',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.heading2.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.surfaceHighlight,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _selectedHorizon.fullLabel,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Horizon Selector Pill Row
        Container(
          height: 32,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.surfaceBorderSubtle),
          ),
          child: Row(
            children: ChartTimeHorizon.values.map((horizon) {
              final isSelected = horizon == _selectedHorizon;
              return Expanded(
                child: GestureDetector(
                  key: Key('chart_horizon_${horizon.label}'),
                  onTap: () {
                    setState(() {
                      _selectedHorizon = horizon;
                      _touchPosition = null;
                    });
                    widget.onHorizonChanged?.call(horizon);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.surfaceRaised
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: isSelected
                          ? Border.all(
                              color:
                                  AppColors.accentCyan.withValues(alpha: 0.6),
                              width: 1,
                            )
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        horizon.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? AppColors.accentCyan
                              : AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildChartCanvasArea(MultiLineChartData chartData) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasWidth = constraints.maxWidth;
        const canvasHeight = 190.0;

        return SizedBox(
          width: canvasWidth,
          height: canvasHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // CustomPaint Canvas
              CustomPaint(
                key: const Key('multi_line_chart_canvas'),
                size: Size(canvasWidth, canvasHeight),
                painter: MultiLineChartPainter(
                  data: chartData,
                  activeVendors: _selectedVendors,
                  touchPosition: _touchPosition,
                  isPrivacyMode: _effectivePrivacyMode,
                ),
              ),

              // Pan & Scrub GestureDetector
              Positioned.fill(
                child: GestureDetector(
                  key: const Key('chart_gesture_detector'),
                  behavior: HitTestBehavior.opaque,
                  onPanDown: (d) => setState(() => _touchPosition = d.localPosition),
                  onPanUpdate: (d) => setState(() => _touchPosition = d.localPosition),
                  onPanEnd: (_) => setState(() => _touchPosition = null),
                  onPanCancel: () => setState(() => _touchPosition = null),
                  onTapDown: (d) => setState(() => _touchPosition = d.localPosition),
                ),
              ),

              // Glassmorphic Floating Tooltip Card
              if (_touchPosition != null)
                _buildFloatingTooltip(chartData, canvasWidth, canvasHeight),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFloatingTooltip(
    MultiLineChartData data,
    double canvasWidth,
    double canvasHeight,
  ) {
    if (_touchPosition == null) return const SizedBox.shrink();

    const paddingLeft = 8.0;
    const paddingRight = 46.0;
    const plotLeft = paddingLeft;
    final plotRight = canvasWidth - paddingRight;
    final plotWidth = plotRight - plotLeft;

    final touchX = _touchPosition!.dx.clamp(plotLeft, plotRight);
    final normX = plotWidth > 0 ? ((touchX - plotLeft) / plotWidth).clamp(0.0, 1.0) : 0.0;

    // Retrieve active points closest to touch
    final trimmedPoints = data.trimmedAverage.points;
    if (trimmedPoints.isEmpty) return const SizedBox.shrink();

    final targetIndex = ((trimmedPoints.length - 1) * normX).round().clamp(0, trimmedPoints.length - 1);
    final targetDate = trimmedPoints[targetIndex].timestamp;
    final dateStr = _formatChartDate(targetDate, includeYear: true);

    // Tooltip positioning: auto-flip left or right
    const tooltipWidth = 144.0;
    final isLeft = touchX > (canvasWidth / 2);
    final leftPos = isLeft
        ? (touchX - tooltipWidth - 8).clamp(4.0, canvasWidth - tooltipWidth)
        : (touchX + 8).clamp(4.0, canvasWidth - tooltipWidth);

    return Positioned(
      left: leftPos,
      top: 6.0,
      child: IgnorePointer(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              key: const Key('chart_tooltip_card'),
              width: tooltipWidth,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceHighlight.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.surfaceBorder,
                  width: 1,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    dateStr,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Divider(
                    height: 1,
                    thickness: 0.8,
                    color: AppColors.surfaceBorderSubtle,
                  ),
                  const SizedBox(height: 6),
                  // Trimmed Avg Row
                  _buildTooltipRow(
                    label: 'Trimmed Avg',
                    color: AppColors.accentCyan,
                    price: trimmedPoints[targetIndex].price,
                  ),
                  // Active Vendor Rows
                  ...MarketVendor.values
                      .where((v) => _selectedVendors.contains(v))
                      .map((v) {
                    final series = data.vendorSeries[v];
                    if (series == null || series.points.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    final idx = ((series.points.length - 1) * normX).round().clamp(0, series.points.length - 1);
                    return _buildTooltipRow(
                      label: v.displayName,
                      color: v.color,
                      price: series.points[idx].price,
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTooltipRow({
    required String label,
    required Color color,
    required double price,
  }) {
    final priceStr = _effectivePrivacyMode
        ? '****'
        : VaultPricingHelper.formatAmount(
            price,
            currency: _effectiveCurrency,
            isPrivacyMode: false,
          );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 9.5,
                color: AppColors.textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            priceStr,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVendorToggleLegend() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        // Pinned Trimmed Avg Baseline (Always active)
        Container(
          key: const Key('chart_legend_trimmed_avg'),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.accentCyan.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: AppColors.accentCyan.withValues(alpha: 0.4),
              width: 1,
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_rounded, size: 10, color: AppColors.accentCyan),
              SizedBox(width: 4),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Trimmed Avg',
                    style: TextStyle(
                      color: AppColors.accentCyan,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Interactive Vendor Toggles
        ...MarketVendor.values.map((vendor) {
          final isSelected = _selectedVendors.contains(vendor);
          return GestureDetector(
            key: Key('vendor_toggle_${vendor.id}'),
            onTap: () {
              setState(() {
                if (isSelected) {
                  _selectedVendors.remove(vendor);
                } else {
                  _selectedVendors.add(vendor);
                }
              });
              widget.onVendorsChanged?.call(Set.from(_selectedVendors));
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? vendor.color.withValues(alpha: 0.14)
                    : AppColors.surfaceHighlight.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected
                      ? vendor.color.withValues(alpha: 0.8)
                      : AppColors.surfaceBorderSubtle,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: isSelected ? vendor.color : AppColors.textMuted,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        vendor.displayName,
                        style: TextStyle(
                          color: isSelected
                              ? AppColors.textPrimary
                              : AppColors.textMuted,
                          fontSize: 11,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ============================================================================
// 3. Native CustomPainter Engine
// ============================================================================

class MultiLineChartPainter extends CustomPainter {
  final MultiLineChartData data;
  final Set<MarketVendor> activeVendors;
  final Offset? touchPosition;
  final bool isPrivacyMode;

  MultiLineChartPainter({
    required this.data,
    required this.activeVendors,
    this.touchPosition,
    required this.isPrivacyMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const paddingLeft = 8.0;
    const paddingRight = 46.0;
    const paddingTop = 14.0;
    const paddingBottom = 22.0;

    final plotLeft = paddingLeft;
    final plotRight = size.width - paddingRight;
    const plotTop = paddingTop;
    final plotBottom = size.height - paddingBottom;
    final plotWidth = plotRight - plotLeft;
    final plotHeight = plotBottom - plotTop;

    if (plotWidth <= 0 || plotHeight <= 0) return;

    // 1. Calculate Price & Time Bounds
    final allVisibleSeries = <ChartSeries>[
      data.trimmedAverage,
      ...MarketVendor.values
          .where((v) => activeVendors.contains(v))
          .map((v) => data.vendorSeries[v])
          .whereType<ChartSeries>(),
    ];

    double minPrice = double.infinity;
    double maxPrice = double.negativeInfinity;
    DateTime? minTime;
    DateTime? maxTime;

    for (final s in allVisibleSeries) {
      for (final p in s.points) {
        if (p.price < minPrice) minPrice = p.price;
        if (p.price > maxPrice) maxPrice = p.price;
        if (minTime == null || p.timestamp.isBefore(minTime)) {
          minTime = p.timestamp;
        }
        if (maxTime == null || p.timestamp.isAfter(maxTime)) {
          maxTime = p.timestamp;
        }
      }
    }

    if (minPrice.isInfinite || maxPrice.isInfinite) {
      minPrice = 0.0;
      maxPrice = 10.0;
    }
    if (minTime == null || maxTime == null || minTime == maxTime) {
      minTime = DateTime.now().subtract(const Duration(days: 30));
      maxTime = DateTime.now();
    }

    final priceSpread = maxPrice - minPrice;
    final buffer = priceSpread > 0.001 ? priceSpread * 0.08 : 1.0;
    final displayMinY = math.max(0.0, minPrice - buffer);
    final displayMaxY = maxPrice + buffer;
    final displaySpreadY = displayMaxY - displayMinY;

    final startMs = minTime.millisecondsSinceEpoch;
    final endMs = maxTime.millisecondsSinceEpoch;
    final spanMs = math.max(1, endMs - startMs);

    double mapX(DateTime t) {
      final fraction = (t.millisecondsSinceEpoch - startMs) / spanMs;
      return plotLeft + (fraction * plotWidth);
    }

    double mapY(double p) {
      final fraction = (p - displayMinY) / displaySpreadY;
      return plotBottom - (fraction * plotHeight);
    }

    // 2. Draw Horizontal Gridlines & Y-Axis Labels
    _drawGridAndYLabels(
      canvas,
      size,
      plotLeft,
      plotRight,
      plotTop,
      plotBottom,
      displayMinY,
      displayMaxY,
    );

    // 3. Draw Bottom X-Axis Dates
    _drawXAxisDates(
      canvas,
      plotLeft,
      plotRight,
      plotBottom,
      minTime,
      maxTime,
    );

    // 4. Draw Area Gradient under Trimmed Average
    _drawTrimmedAverageGradient(
      canvas,
      data.trimmedAverage,
      mapX,
      mapY,
      plotLeft,
      plotRight,
      plotTop,
      plotBottom,
    );

    // 5. Draw Individual Vendor Curves
    for (final vendor in MarketVendor.values) {
      if (!activeVendors.contains(vendor)) continue;
      final series = data.vendorSeries[vendor];
      if (series != null && series.isNotEmpty) {
        _drawSplineCurve(
          canvas,
          series.points,
          series.color,
          series.strokeWidth,
          mapX,
          mapY,
        );
      }
    }

    // 6. Draw Trimmed Average Curve (Bold 2.5px Cyan)
    _drawSplineCurve(
      canvas,
      data.trimmedAverage.points,
      data.trimmedAverage.color,
      2.5,
      mapX,
      mapY,
    );

    // 7. Draw Touch Crosshair & Highlight Dots
    if (touchPosition != null) {
      final touchX = touchPosition!.dx.clamp(plotLeft, plotRight);
      _drawCrosshair(canvas, touchX, plotTop, plotBottom);
      _drawHighlightDots(
        canvas,
        touchX,
        plotLeft,
        plotWidth,
        allVisibleSeries,
        mapX,
        mapY,
      );
    }
  }

  void _drawGridAndYLabels(
    Canvas canvas,
    Size size,
    double plotLeft,
    double plotRight,
    double plotTop,
    double plotBottom,
    double minY,
    double maxY,
  ) {
    final gridPaint = Paint()
      ..color = AppColors.surfaceBorder.withValues(alpha: 0.45)
      ..strokeWidth = 1.0;

    const divisions = 4;
    final span = maxY - minY;

    for (int i = 0; i <= divisions; i++) {
      final yRatio = i / divisions;
      final yPixel = plotBottom - (yRatio * (plotBottom - plotTop));
      final priceVal = minY + (yRatio * span);

      // Grid line
      canvas.drawLine(Offset(plotLeft, yPixel), Offset(plotRight, yPixel), gridPaint);

      // Price label
      final label = isPrivacyMode
          ? '****'
          : '\$${priceVal < 10 ? priceVal.toStringAsFixed(2) : priceVal.toStringAsFixed(1)}';

      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 9.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();

      tp.paint(canvas, Offset(plotRight + 6, yPixel - (tp.height / 2)));
    }
  }

  void _drawXAxisDates(
    Canvas canvas,
    double plotLeft,
    double plotRight,
    double plotBottom,
    DateTime minTime,
    DateTime maxTime,
  ) {
    const dateDivisions = 3;
    final totalSpan = maxTime.difference(minTime);

    for (int i = 0; i <= dateDivisions; i++) {
      final ratio = i / dateDivisions;
      final targetDate = minTime.add(Duration(
        milliseconds: (totalSpan.inMilliseconds * ratio).round(),
      ));
      final xPixel = plotLeft + (ratio * (plotRight - plotLeft));

      final label = _formatChartDate(targetDate);
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 9.5,
            fontWeight: FontWeight.w400,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();

      final alignX = i == 0
          ? xPixel
          : (i == dateDivisions ? xPixel - tp.width : xPixel - (tp.width / 2));

      tp.paint(canvas, Offset(alignX, plotBottom + 6));
    }
  }

  void _drawTrimmedAverageGradient(
    Canvas canvas,
    ChartSeries series,
    double Function(DateTime) mapX,
    double Function(double) mapY,
    double plotLeft,
    double plotRight,
    double plotTop,
    double plotBottom,
  ) {
    if (series.points.length < 2) return;

    final splinePath = _buildSplinePath(series.points, mapX, mapY);
    final fillPath = Path.from(splinePath);

    final lastX = mapX(series.points.last.timestamp);
    final firstX = mapX(series.points.first.timestamp);

    fillPath.lineTo(lastX, plotBottom);
    fillPath.lineTo(firstX, plotBottom);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, plotTop),
        Offset(0, plotBottom),
        [
          AppColors.accentCyan.withValues(alpha: 0.16),
          AppColors.accentCyan.withValues(alpha: 0.0),
        ],
      )
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);
  }

  void _drawSplineCurve(
    Canvas canvas,
    List<ChartPoint> points,
    Color color,
    double strokeWidth,
    double Function(DateTime) mapX,
    double Function(double) mapY,
  ) {
    if (points.isEmpty) return;

    if (points.length == 1) {
      final pt = points.first;
      final p = Offset(mapX(pt.timestamp), mapY(pt.price));
      canvas.drawCircle(p, strokeWidth * 1.5, Paint()..color = color);
      return;
    }

    final path = _buildSplinePath(points, mapX, mapY);
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, paint);
  }

  /// Fritsch-Carlson Monotone Cubic Hermite Spline Interpolation.
  /// Prevents overshooting, negative dips, and artificial ringing in financial curves.
  Path _buildSplinePath(
    List<ChartPoint> points,
    double Function(DateTime) mapX,
    double Function(double) mapY,
  ) {
    final path = Path();
    if (points.isEmpty) return path;

    final n = points.length;
    final coords = List<Offset>.generate(
      n,
      (i) => Offset(mapX(points[i].timestamp), mapY(points[i].price)),
    );

    path.moveTo(coords[0].dx, coords[0].dy);

    if (n == 2) {
      path.lineTo(coords[1].dx, coords[1].dy);
      return path;
    }

    // Step 1: Compute secants
    final dxs = List<double>.filled(n - 1, 0.0);
    final dys = List<double>.filled(n - 1, 0.0);
    final secants = List<double>.filled(n - 1, 0.0);

    for (int i = 0; i < n - 1; i++) {
      dxs[i] = coords[i + 1].dx - coords[i].dx;
      dys[i] = coords[i + 1].dy - coords[i].dy;
      secants[i] = dxs[i] != 0.0 ? dys[i] / dxs[i] : 0.0;
    }

    // Step 2: Initialize tangents
    final slopes = List<double>.filled(n, 0.0);
    slopes[0] = secants[0];
    slopes[n - 1] = secants[n - 2];

    for (int i = 1; i < n - 1; i++) {
      final sPrev = secants[i - 1];
      final sNext = secants[i];
      if (sPrev * sNext <= 0.0) {
        slopes[i] = 0.0; // Local extremum: flat slope
      } else {
        slopes[i] = (sPrev + sNext) / 2.0;
      }
    }

    // Step 3: Fritsch-Carlson monotonicity check & adjustment
    for (int i = 0; i < n - 1; i++) {
      final s = secants[i];
      if (s == 0.0) {
        slopes[i] = 0.0;
        slopes[i + 1] = 0.0;
      } else {
        final alpha = slopes[i] / s;
        final beta = slopes[i + 1] / s;
        if (alpha < 0.0) slopes[i] = 0.0;
        if (beta < 0.0) slopes[i + 1] = 0.0;
        final sumSq = alpha * alpha + beta * beta;
        if (sumSq > 9.0) {
          final tau = 3.0 / math.sqrt(sumSq);
          slopes[i] = tau * alpha * s;
          slopes[i + 1] = tau * beta * s;
        }
      }
    }

    // Step 4: Convert Hermite tangents into cubic Bézier control points
    for (int i = 0; i < n - 1; i++) {
      final cur = coords[i];
      final next = coords[i + 1];
      final dx = dxs[i];
      final cp1 = Offset(cur.dx + dx / 3.0, cur.dy + slopes[i] * dx / 3.0);
      final cp2 = Offset(next.dx - dx / 3.0, next.dy - slopes[i + 1] * dx / 3.0);
      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, next.dx, next.dy);
    }

    return path;
  }

  void _drawCrosshair(Canvas canvas, double x, double top, double bottom) {
    final paint = Paint()
      ..color = AppColors.textSecondary.withValues(alpha: 0.5)
      ..strokeWidth = 1.0;

    const dashHeight = 4.0;
    const dashSpace = 4.0;
    double currentY = top;

    while (currentY < bottom) {
      canvas.drawLine(
        Offset(x, currentY),
        Offset(x, math.min(currentY + dashHeight, bottom)),
        paint,
      );
      currentY += dashHeight + dashSpace;
    }
  }

  void _drawHighlightDots(
    Canvas canvas,
    double touchX,
    double plotLeft,
    double plotWidth,
    List<ChartSeries> visibleSeries,
    double Function(DateTime) mapX,
    double Function(double) mapY,
  ) {
    final normX = plotWidth > 0 ? ((touchX - plotLeft) / plotWidth).clamp(0.0, 1.0) : 0.0;

    for (final series in visibleSeries) {
      if (series.points.isEmpty) continue;
      final idx = ((series.points.length - 1) * normX).round().clamp(0, series.points.length - 1);
      final pt = series.points[idx];
      final pos = Offset(mapX(pt.timestamp), mapY(pt.price));

      // Glow halo
      canvas.drawCircle(
        pos,
        6.5,
        Paint()..color = series.color.withValues(alpha: 0.28),
      );
      // Solid core
      canvas.drawCircle(
        pos,
        3.5,
        Paint()..color = series.color,
      );
      // Border ring
      canvas.drawCircle(
        pos,
        3.5,
        Paint()
          ..color = AppColors.surfaceRaised
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke,
      );
    }
  }

  @override
  bool shouldRepaint(covariant MultiLineChartPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.activeVendors != activeVendors ||
        oldDelegate.touchPosition != touchPosition ||
        oldDelegate.isPrivacyMode != isPrivacyMode;
  }
}

// ============================================================================
// 4. Sample Chart Data Generator (Offline / Testing / Preview)
// ============================================================================

MultiLineChartData _generateSampleChartData(
  ChartTimeHorizon horizon,
  AppCurrency currency,
  double basePrice,
) {
  final now = DateTime.now();
  final int pointsCount = switch (horizon) {
    ChartTimeHorizon.sevenDays => 7,
    ChartTimeHorizon.thirtyDays => 30,
    ChartTimeHorizon.ninetyDays => 45,
    ChartTimeHorizon.oneYear => 52,
    ChartTimeHorizon.allTime => 60,
  };

  final totalDuration = horizon.duration;
  final stepMs = totalDuration.inMilliseconds ~/ math.max(1, pointsCount - 1);

  List<ChartPoint> generateCurve(double drift, double volatility, double bias) {
    final list = <ChartPoint>[];
    double p = basePrice * bias;
    for (int i = 0; i < pointsCount; i++) {
      final t = now.subtract(Duration(milliseconds: (pointsCount - 1 - i) * stepMs));
      final noise = (math.sin(i * 0.4) * volatility) + (math.cos(i * 0.2) * (volatility * 0.5));
      p = math.max(0.05, p + (drift * 0.1) + noise);
      list.add(ChartPoint(timestamp: t, price: p));
    }
    return list;
  }

  final trimmedAvgPoints = generateCurve(0.02, 0.20, 1.0);
  final tcgPoints = generateCurve(0.03, 0.25, 1.02);
  final cmPoints = generateCurve(0.01, 0.18, 0.94);
  final ebayPoints = generateCurve(0.04, 0.35, 1.05);
  final ckPoints = generateCurve(0.02, 0.22, 1.08);
  final mpPoints = generateCurve(0.01, 0.19, 0.99);

  return MultiLineChartData(
    horizon: horizon,
    currency: currency,
    trimmedAverage: ChartSeries(
      id: 'trimmed_avg',
      label: 'Trimmed Avg',
      color: AppColors.accentCyan,
      strokeWidth: 2.5,
      isTrimmedAverage: true,
      points: trimmedAvgPoints,
    ),
    vendorSeries: {
      MarketVendor.tcgplayer: ChartSeries(
        id: MarketVendor.tcgplayer.id,
        label: MarketVendor.tcgplayer.displayName,
        color: MarketVendor.tcgplayer.color,
        points: tcgPoints,
      ),
      MarketVendor.cardmarket: ChartSeries(
        id: MarketVendor.cardmarket.id,
        label: MarketVendor.cardmarket.displayName,
        color: MarketVendor.cardmarket.color,
        points: cmPoints,
      ),
      MarketVendor.ebay: ChartSeries(
        id: MarketVendor.ebay.id,
        label: MarketVendor.ebay.displayName,
        color: MarketVendor.ebay.color,
        points: ebayPoints,
      ),
      MarketVendor.cardKingdom: ChartSeries(
        id: MarketVendor.cardKingdom.id,
        label: MarketVendor.cardKingdom.displayName,
        color: MarketVendor.cardKingdom.color,
        points: ckPoints,
      ),
      MarketVendor.manapool: ChartSeries(
        id: MarketVendor.manapool.id,
        label: MarketVendor.manapool.displayName,
        color: MarketVendor.manapool.color,
        points: mpPoints,
      ),
    },
  );
}
