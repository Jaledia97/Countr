import 'dart:async';
import 'dart:math';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Represents a distinct zone or category section in the proportional scrollbar rail.
class ScrollbarSection {
  final String label;
  final String? shortLabel;
  final int count;
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;
  final IconData? icon;
  final Color? bubbleColor;

  ScrollbarSection({
    required this.label,
    this.shortLabel,
    required this.count,
    required this.onTap,
    this.onDoubleTap,
    this.icon,
    this.bubbleColor,
  });
}

/// A proportional bubble scrollbar that partitions rail height according to
/// card counts, enforces a 24.0px minimum touch clamp (Feature 18), renders an
/// active thumb indicator, and supports drag scrubbing and double-tap jumps (Feature 19).
class ProportionalBubbleScrollbar extends StatefulWidget {
  final List<ScrollbarSection> sections;
  final ScrollController? controller;
  final double railWidth;
  final Color railColor;
  final Color bubbleColor;
  final ValueChanged<int>? onSectionTap;
  final ValueChanged<int>? onSectionDoubleTap;
  final ValueChanged<double>? onDoubleTapJump;
  final ValueChanged<double>? onScrubUpdate;
  final double minSectionHeight;
  final bool autoHide;
  final Duration hideDelay;
  final Duration fadeDuration;
  final BoxBorder? railBorder;
  final List<BoxShadow>? railShadow;

  const ProportionalBubbleScrollbar({
    super.key,
    required this.sections,
    this.controller,
    this.railWidth = 26.0,
    this.railColor = Colors.black12,
    this.bubbleColor = Colors.blueAccent,
    this.onSectionTap,
    this.onSectionDoubleTap,
    this.onDoubleTapJump,
    this.onScrubUpdate,
    this.minSectionHeight = 24.0,
    this.autoHide = true,
    this.hideDelay = const Duration(milliseconds: 1500),
    this.fadeDuration = const Duration(milliseconds: 300),
    this.railBorder,
    this.railShadow,
  });

  /// Mathematical water-filling algorithm to partition [totalHeight] among [counts]
  /// guaranteeing every section receives at least [minHeight] without exceeding [totalHeight].
  static List<double> computeSectionHeights({
    required List<int> counts,
    required double totalHeight,
    double minHeight = 24.0,
  }) {
    final n = counts.length;
    if (n == 0 || totalHeight <= 0) return [];

    // Guard: If rail height cannot accommodate all sections at minHeight,
    // divide rail equally to prevent overflow.
    if (n * minHeight >= totalHeight) {
      return List.filled(n, totalHeight / n);
    }

    final heights = List.filled(n, 0.0);
    final isClamped = List.filled(n, false);
    bool needsRecalculation = true;

    while (needsRecalculation) {
      needsRecalculation = false;
      double clampedHeightSum = 0;
      int unclampedCardSum = 0;

      for (int i = 0; i < n; i++) {
        if (isClamped[i]) {
          clampedHeightSum += minHeight;
        } else {
          unclampedCardSum += counts[i];
        }
      }

      final remainingHeight = totalHeight - clampedHeightSum;

      for (int i = 0; i < n; i++) {
        if (!isClamped[i]) {
          final proportional = unclampedCardSum > 0
              ? remainingHeight * (counts[i] / unclampedCardSum)
              : remainingHeight / n;
          if (proportional < minHeight) {
            isClamped[i] = true;
            needsRecalculation = true;
            break;
          } else {
            heights[i] = proportional;
          }
        } else {
          heights[i] = minHeight;
        }
      }
    }

    return heights;
  }

  /// Determines whether the section represents the Commander zone.
  static bool isCommanderSection(ScrollbarSection sec) {
    return sec.label.toLowerCase().contains('commander');
  }

  /// Resolves the icon for a section (defaulting to crown for Commander).
  static IconData? resolveSectionIcon(ScrollbarSection sec) {
    if (sec.icon != null) return sec.icon;
    if (isCommanderSection(sec)) return Icons.workspace_premium_rounded;
    return null;
  }

  /// Standardized abbreviation labels for trading card zones (Cr, L, Sp, A&E, PW, etc.).
  static String resolveSectionLabel(ScrollbarSection sec) {
    if (sec.shortLabel != null && sec.shortLabel!.isNotEmpty) {
      return sec.shortLabel!;
    }
    final lower = sec.label.toLowerCase().trim();
    if (lower.contains('commander')) return '';
    if (lower == 'creatures' || lower == 'creature') return 'Cr';
    if (lower == 'lands' || lower == 'land') return 'L';
    if (lower == 'spells' || lower == 'spell') return 'Sp';
    if (lower.contains('artifact') && lower.contains('enchantment')) return 'A&E';
    if (lower == 'artifacts' || lower == 'artifact') return 'Ar';
    if (lower == 'enchantments' || lower == 'enchantment') return 'En';
    if (lower == 'planeswalkers' || lower == 'planeswalker') return 'PW';
    if (lower == 'instants' || lower == 'instant') return 'In';
    if (lower == 'sorceries' || lower == 'sorcery') return 'So';
    if (lower == 'sideboard') return 'SB';
    if (lower == 'maybeboard') return 'MB';
    if (lower == 'companion') return 'Cp';
    if (lower.contains('pokémon') || lower.contains('pokemon')) return 'PK';
    if (lower.contains('trainer')) return 'TR';
    if (lower.contains('energy')) return 'EN';
    return sec.label;
  }

  @override
  State<ProportionalBubbleScrollbar> createState() =>
      _ProportionalBubbleScrollbarState();
}

class _ProportionalBubbleScrollbarState
    extends State<ProportionalBubbleScrollbar> {
  bool _isDragging = false;
  bool _isVisible = true;
  Timer? _hideTimer;
  DateTime? _lastRailTapTime;
  Offset? _lastRailTapPos;
  DateTime? _lastBubbleTapTime;
  int? _lastBubbleTapIndex;

  @override
  void initState() {
    super.initState();
    _isVisible = true;
    _attachControllerListener(widget.controller);
    _startHideTimer();
  }

  @override
  void didUpdateWidget(ProportionalBubbleScrollbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      _detachControllerListener(oldWidget.controller);
      _attachControllerListener(widget.controller);
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _detachControllerListener(widget.controller);
    super.dispose();
  }

  void _attachControllerListener(ScrollController? controller) {
    controller?.addListener(_onScroll);
  }

  void _detachControllerListener(ScrollController? controller) {
    controller?.removeListener(_onScroll);
  }

  void _onScroll() {
    if (!mounted) return;
    if (!_isVisible) {
      setState(() => _isVisible = true);
    }
    _resetHideTimer();
  }

  void _startHideTimer() {
    if (!widget.autoHide) return;
    _hideTimer?.cancel();
    _hideTimer = Timer(widget.hideDelay, () {
      if (mounted && !_isDragging) {
        setState(() => _isVisible = false);
      }
    });
  }

  void _resetHideTimer() {
    _startHideTimer();
  }

  void _handleDrag(double localY, double totalHeight) {
    final controller = widget.controller;
    if (controller == null ||
        !controller.hasClients ||
        !controller.position.hasContentDimensions) {
      return;
    }
    final maxExtent = controller.position.maxScrollExtent;
    if (maxExtent <= 0) {
      return;
    }

    final progress = (localY / totalHeight).clamp(0.0, 1.0);
    final targetOffset = progress * maxExtent;

    controller.jumpTo(targetOffset);
    widget.onScrubUpdate?.call(targetOffset);
  }

  void _handleDoubleTap(double localY, double totalHeight) {
    final controller = widget.controller;
    final progress = (localY / totalHeight).clamp(0.0, 1.0);

    if (controller != null &&
        controller.hasClients &&
        controller.position.hasContentDimensions) {
      final maxExtent = controller.position.maxScrollExtent;
      final targetOffset = progress * maxExtent;
      controller.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
      widget.onDoubleTapJump?.call(targetOffset);
    } else {
      widget.onDoubleTapJump?.call(progress);
    }
  }

  void _handlePointerDown(PointerDownEvent event, double totalHeight) {
    if (!_isVisible) {
      setState(() => _isVisible = true);
    }
    _hideTimer?.cancel();

    final now = DateTime.now();
    if (_lastRailTapTime != null &&
        _lastRailTapPos != null &&
        now.difference(_lastRailTapTime!) < const Duration(milliseconds: 350) &&
        (event.localPosition - _lastRailTapPos!).distance < 40.0) {
      _handleDoubleTap(event.localPosition.dy, totalHeight);
      _lastRailTapTime = null;
      _lastRailTapPos = null;
    } else {
      _lastRailTapTime = now;
      _lastRailTapPos = event.localPosition;
    }
  }

  @override
  Widget build(BuildContext context) {
    final validSections = widget.sections.where((sec) => sec.count > 0).toList();
    final totalCount =
        validSections.fold<int>(0, (sum, sec) => sum + sec.count);

    if (totalCount == 0 || validSections.isEmpty) {
      return const SizedBox.shrink();
    }

    return AnimatedOpacity(
      key: const Key('scrollbar_fade_animation'),
      opacity: _isVisible ? 1.0 : 0.0,
      duration: widget.fadeDuration,
      curve: Curves.easeInOut,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxH = constraints.maxHeight;
          final totalHeight =
              (maxH.isInfinite || maxH.isNaN || maxH <= 0) ? 300.0 : maxH;

          final counts = validSections.map((s) => s.count).toList();
          final sectionHeights = ProportionalBubbleScrollbar.computeSectionHeights(
            counts: counts,
            totalHeight: totalHeight,
            minHeight: widget.minSectionHeight,
          );

          final bubbles = <Widget>[];
          double currentY = 0;

          for (int i = 0; i < validSections.length; i++) {
            final section = validSections[i];
            final sectionHeight = sectionHeights[i];
            final targetY = currentY;
            final sectionIndex = i;

            bubbles.add(
              Positioned(
                key: Key('scrollbar_bubble_$i'),
                top: targetY,
                height: max(1.0, sectionHeight),
                left: 0,
                right: 0,
                child: Tooltip(
                  message: '${section.label} (${section.count})',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      final now = DateTime.now();
                      if (_lastBubbleTapIndex == sectionIndex &&
                          _lastBubbleTapTime != null &&
                          now.difference(_lastBubbleTapTime!) <
                              const Duration(milliseconds: 350)) {
                        section.onDoubleTap?.call();
                        widget.onSectionDoubleTap?.call(sectionIndex);
                        _lastBubbleTapTime = null;
                        _lastBubbleTapIndex = null;
                      } else {
                        _lastBubbleTapTime = now;
                        _lastBubbleTapIndex = sectionIndex;
                      }
                      section.onTap();
                      widget.onSectionTap?.call(sectionIndex);
                    },
                    child: _buildBubbleContent(section, sectionHeight),
                  ),
                ),
              ),
            );

            currentY += sectionHeight;
          }

          // Active thumb indicator overlay (Feature 19)
          Widget? thumbWidget;
          if (widget.controller != null) {
            thumbWidget = ListenableBuilder(
              listenable: widget.controller!,
              builder: (context, _) {
                final controller = widget.controller!;
                double progress = 0.0;
                if (controller.hasClients &&
                    controller.position.hasContentDimensions &&
                    controller.position.maxScrollExtent > 0) {
                  progress = (controller.offset /
                          controller.position.maxScrollExtent)
                      .clamp(0.0, 1.0);
                }

                const thumbHeight = 16.0;
                final thumbY = progress * max(0.0, totalHeight - thumbHeight);

                return Positioned(
                  key: const Key('scrollbar_thumb'),
                  top: thumbY,
                  left: -2,
                  right: -2,
                  height: thumbHeight,
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        color: _isDragging ? Colors.white : Colors.white70,
                        borderRadius: BorderRadius.circular(thumbHeight / 2),
                        border: Border.all(
                          color: _isDragging
                              ? widget.bubbleColor
                              : widget.bubbleColor.withValues(alpha: 0.6),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: _isDragging ? 6 : 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Container(
                          width: 10,
                          height: 2,
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          }

          return Listener(
            onPointerDown: (event) => _handlePointerDown(event, totalHeight),
            child: RawGestureDetector(
              behavior: HitTestBehavior.opaque,
              gestures: {
                VerticalDragGestureRecognizer:
                    GestureRecognizerFactoryWithHandlers<VerticalDragGestureRecognizer>(
                  () => VerticalDragGestureRecognizer(),
                  (instance) {
                    instance
                      ..onStart = (details) {
                        setState(() {
                          _isDragging = true;
                          _isVisible = true;
                        });
                        _hideTimer?.cancel();
                        _handleDrag(details.localPosition.dy, totalHeight);
                      }
                      ..onUpdate = (details) {
                        _handleDrag(details.localPosition.dy, totalHeight);
                      }
                      ..onEnd = (_) {
                        setState(() => _isDragging = false);
                        _resetHideTimer();
                      }
                      ..onCancel = () {
                        setState(() => _isDragging = false);
                        _resetHideTimer();
                      };
                  },
                ),
              },
              child: Container(
                width: widget.railWidth,
                decoration: BoxDecoration(
                  color: widget.railColor,
                  borderRadius: BorderRadius.circular(widget.railWidth / 2),
                  border: widget.railBorder,
                  boxShadow: widget.railShadow,
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ...bubbles,
                    ?thumbWidget,
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBubbleContent(ScrollbarSection section, double sectionHeight) {
    final vMargin = sectionHeight < 8.0
        ? 0.0
        : (sectionHeight < 16.0 ? 1.0 : 2.0);
    final hMargin = widget.railWidth < 16.0 ? 1.0 : 3.0;
    final isTiny = sectionHeight < 16.0;

    final sectionIcon = ProportionalBubbleScrollbar.resolveSectionIcon(section);
    final effectiveBubbleColor =
        section.bubbleColor ?? widget.bubbleColor;

    Widget bubbleChild;
    if (sectionIcon != null) {
      // Sleek Crown Icon for Commander (Feature 16) - Upright and scaled with FittedBox
      bubbleChild = Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Icon(
            sectionIcon,
            size: min(16.0, max(10.0, widget.railWidth - 8)),
            color: Colors.white,
          ),
        ),
      );
    } else if (isTiny) {
      bubbleChild = sectionHeight >= 6.0
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
          : const SizedBox.shrink();
    } else {
      final displayLabel =
          ProportionalBubbleScrollbar.resolveSectionLabel(section);
      bubbleChild = Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: RotatedBox(
            quarterTurns: 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                displayLabel,
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
      );
    }

    return Container(
      margin: EdgeInsets.symmetric(
        vertical: vMargin,
        horizontal: hMargin,
      ),
      decoration: BoxDecoration(
        color: effectiveBubbleColor.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(
          min(widget.railWidth / 2, 8.0),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          min(widget.railWidth / 2, 8.0),
        ),
        child: bubbleChild,
      ),
    );
  }
}
