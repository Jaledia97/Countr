import 'dart:math';
import 'package:flutter/material.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/constants/app_typography.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/symbology/presentation/widgets/mana_symbol_icon.dart';

/// Reusable inline collapsible analytics card embedded directly in DeckBuilderScreen.
class InlineDeckAnalyticsCard extends StatelessWidget {
  final DeckAnalytics analytics;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final VoidCallback onOpenModal;

  const InlineDeckAnalyticsCard({
    super.key,
    required this.analytics,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.onOpenModal,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('deck_builder_inline_analytics_card'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceBorderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.bar_chart_rounded, size: 18, color: AppColors.accentCyan),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Deck Analytics',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.heading2.copyWith(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton.icon(
                    key: const Key('inline_analytics_expand_modal_button'),
                    icon: const Icon(Icons.open_in_full_rounded, size: 12, color: AppColors.accentCyan),
                    label: const Text('Modal', style: TextStyle(fontSize: 10, color: AppColors.accentCyan)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: onOpenModal,
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    key: const Key('inline_analytics_collapse_toggle'),
                    icon: Icon(
                      isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                    visualDensity: VisualDensity.compact,
                    onPressed: onToggleExpand,
                    tooltip: isExpanded ? 'Collapse Analytics' : 'Expand Analytics',
                  ),
                ],
              ),
            ],
          ),
          if (isExpanded) ...[
            const SizedBox(height: 12),
            _buildSectionHeader('Mana Curve'),
            ManaCurveChartWidget(manaCurve: analytics.manaCurve),
            const SizedBox(height: 14),
            _buildSectionHeader('Color Devotion'),
            ColorDevotionPipsWidget(devotion: analytics.colorDevotion),
            const SizedBox(height: 12),
            _buildSectionHeader('Deck Bling'),
            BlingMeterWidget(blingPercentage: analytics.blingPercentage),
          ] else ...[
            const SizedBox(height: 6),
            _buildCollapsedSummary(context),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppColors.textSecondary,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _buildCollapsedSummary(BuildContext context) {
    final nonZeroDevotions = analytics.colorDevotion.entries.where((e) => e.value > 0).toList();
    final blingPct = (analytics.blingPercentage * 100).clamp(0.0, 100.0).toStringAsFixed(1);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome_rounded, size: 13, color: AppColors.accentAmber),
            const SizedBox(width: 4),
            Text(
              '$blingPct% Bling',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white70),
            ),
          ],
        ),
        if (nonZeroDevotions.isNotEmpty)
          Flexible(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: nonZeroDevotions.take(5).map((e) {
                  return Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ManaSymbolIcon(symbolCode: e.key, size: 14, circular: true),
                        const SizedBox(width: 2),
                        Text('${e.value}', style: const TextStyle(fontSize: 10, color: Colors.white70)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }
}

/// Reusable Mana Curve Histogram Chart
class ManaCurveChartWidget extends StatelessWidget {
  final Map<int, int> manaCurve;

  const ManaCurveChartWidget({super.key, required this.manaCurve});

  @override
  Widget build(BuildContext context) {
    final buckets = [0, 1, 2, 3, 4, 5, 6, 7];
    int maxCount = 1;

    for (final cmc in buckets) {
      int count = (cmc == 7)
          ? manaCurve.entries.where((e) => e.key >= 7).fold<int>(0, (sum, e) => sum + e.value)
          : (manaCurve[cmc] ?? 0);
      if (count > maxCount) maxCount = count;
    }

    return Container(
      constraints: const BoxConstraints(minHeight: 120),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.surfaceBorderSubtle),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: buckets.map((cmc) {
          final count = (cmc == 7)
              ? manaCurve.entries.where((e) => e.key >= 7).fold<int>(0, (sum, e) => sum + e.value)
              : (manaCurve[cmc] ?? 0);

          final barProportion = (count / maxCount).clamp(0.05, 1.0);
          final barHeight = 56.0 * barProportion;

          return FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.bottomCenter,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '$count',
                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 3),
                Container(
                  width: 18,
                  height: barHeight,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.accentCyan, AppColors.accentVioletLight],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  cmc == 7 ? '7+' : '$cmc',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white70),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Reusable Color Devotion Pips & Breakdown
class ColorDevotionPipsWidget extends StatelessWidget {
  final Map<String, int> devotion;

  const ColorDevotionPipsWidget({super.key, required this.devotion});

  static const colors = [
    {'code': 'W', 'name': 'White', 'color': Color(0xFFF8E7B9)},
    {'code': 'U', 'name': 'Blue', 'color': Color(0xFF0E68AB)},
    {'code': 'B', 'name': 'Black', 'color': Color(0xFF212121)},
    {'code': 'R', 'name': 'Red', 'color': Color(0xFFD3202A)},
    {'code': 'G', 'name': 'Green', 'color': Color(0xFF00733E)},
    {'code': 'C', 'name': 'Colorless', 'color': Color(0xFF9E9E9E)},
  ];

  @override
  Widget build(BuildContext context) {
    final totalPips = devotion.values.fold<int>(0, (sum, v) => sum + v);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.surfaceBorderSubtle),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: colors.map((c) {
              final code = c['code'] as String;
              final count = devotion[code] ?? 0;

              return Column(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Tooltip(
                        message: c['name'] as String,
                        child: ManaSymbolIcon(symbolCode: code, size: 24, circular: true),
                      ),
                      Opacity(
                        opacity: 0.0,
                        child: Text(code, style: const TextStyle(fontSize: 1)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$count',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ],
              );
            }).toList(),
          ),
          if (totalPips > 0) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: SizedBox(
                height: 6,
                child: Row(
                  children: colors.map((c) {
                    final code = c['code'] as String;
                    final count = devotion[code] ?? 0;
                    if (count == 0) return const SizedBox.shrink();
                    return Expanded(
                      flex: max(1, count),
                      child: Container(color: c['color'] as Color),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Reusable Bling Meter
class BlingMeterWidget extends StatelessWidget {
  final double blingPercentage;

  const BlingMeterWidget({super.key, required this.blingPercentage});

  @override
  Widget build(BuildContext context) {
    final pct = (blingPercentage * 100).clamp(0.0, 100.0);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.surfaceBorderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${pct.toStringAsFixed(1)}% Bling',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Foils, Promos, Graded & Alters',
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: Container(
              height: 10,
              width: double.infinity,
              color: Colors.black38,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: (pct / 100.0).clamp(0.0, 1.0),
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.accentCyan, AppColors.accentVioletLight, Colors.amberAccent],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
