import 'dart:math';
import 'package:flutter/material.dart';

class ScrollbarSection {
  final String label;
  final int count;
  final VoidCallback onTap;

  ScrollbarSection({
    required this.label,
    required this.count,
    required this.onTap,
  });
}

class ProportionalBubbleScrollbar extends StatelessWidget {
  final List<ScrollbarSection> sections;
  final double railWidth;
  final Color railColor;
  final Color bubbleColor;
  final ValueChanged<int>? onSectionTap;

  const ProportionalBubbleScrollbar({
    super.key,
    required this.sections,
    this.railWidth = 24.0,
    this.railColor = Colors.black12,
    this.bubbleColor = Colors.blueAccent,
    this.onSectionTap,
  });

  @override
  Widget build(BuildContext context) {
    final validSections = sections.where((sec) => sec.count > 0).toList();
    final totalCount =
        validSections.fold<int>(0, (sum, sec) => sum + sec.count);

    if (totalCount == 0 || validSections.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: railWidth,
      decoration: BoxDecoration(
        color: railColor,
        borderRadius: BorderRadius.circular(railWidth / 2),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxH = constraints.maxHeight;
          final totalHeight =
              (maxH.isInfinite || maxH.isNaN || maxH <= 0) ? 300.0 : maxH;
          final bubbles = <Widget>[];

          double currentY = 0;
          for (int i = 0; i < sections.length; i++) {
            final section = sections[i];
            if (section.count <= 0) continue;

            final proportion = section.count / totalCount;
            final sectionHeight = totalHeight * proportion;

            final vMargin = sectionHeight < 8.0
                ? 0.0
                : (sectionHeight < 16.0 ? 1.0 : 2.0);
            final hMargin = railWidth < 16.0 ? 1.0 : 3.0;

            final isTiny = sectionHeight < 24.0;

            bubbles.add(
              Positioned(
                top: currentY,
                height: max(1.0, sectionHeight),
                left: 0,
                right: 0,
                child: Tooltip(
                  message: '${section.label} (${section.count})',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      section.onTap();
                      onSectionTap?.call(i);
                    },
                    child: Container(
                      margin: EdgeInsets.symmetric(
                        vertical: vMargin,
                        horizontal: hMargin,
                      ),
                      decoration: BoxDecoration(
                        color: bubbleColor.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(
                          min(railWidth / 2, 8.0),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          min(railWidth / 2, 8.0),
                        ),
                        child: isTiny
                            ? (sectionHeight >= 8.0
                                ? Center(
                                    child: Container(
                                      width: 4,
                                      height: 4,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink())
                            : Center(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: RotatedBox(
                                    quarterTurns: 1,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 2,
                                      ),
                                      child: Text(
                                        section.label,
                                        maxLines: 1,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            );

            currentY += sectionHeight;
          }

          return Stack(
            children: bubbles,
          );
        },
      ),
    );
  }
}
