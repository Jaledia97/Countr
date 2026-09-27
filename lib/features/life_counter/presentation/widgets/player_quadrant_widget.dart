// Copyright (c) 2026 Countr. All rights reserved.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:countr/features/life_counter/domain/models/pod_state.dart';
import 'commander_art_backdrop.dart';
import 'tool_drawer_or_rail.dart';

/// Production widget representing a player's seat in an MTG life counter pod.
///
/// Features:
/// - Dynamic Commander art crop backdrop with dark vignette gradient (WCAG AAA contrast).
/// - Massive tabular figures life display with FittedBox overflow protection.
/// - Split Left (-1) and Right (+1) touch hitboxes with haptic feedback.
/// - Accumulating transient delta badge (+3 / -5) with 1500ms auto-fade debounce.
/// - Staged press-and-hold acceleration ticker (350ms delay -> 120ms -> 80ms -> 60ms x5).
/// - Responsive secondary trackers: perpetual tool rail on tablets (>=600dp),
///   gesture/tap pull-out drawer on phones (<600dp).
/// - Commander 21+ lethal damage banner alert and toxic 10+ poison lethal banner alert.
/// - Lethal defeat overlay for eliminated/dead players.
class PlayerQuadrantWidget extends StatefulWidget {
  final PodPlayerState player;
  final bool isTablet;
  final List<PodPlayerState> opponents;
  final void Function(int delta)? onLifeDelta;
  final void Function(String opponentId, int delta)? onCommanderDamage;
  final void Function(String color, int delta)? onManaDelta;
  final VoidCallback? onManaClear;
  final void Function(String counterType, int delta)? onCounterDelta;
  final VoidCallback? onClaimMonarch;
  final VoidCallback? onClaimInitiative;
  final VoidCallback? onArtOverride;
  final VoidCallback? onToggleEliminated;

  const PlayerQuadrantWidget({
    super.key,
    required this.player,
    required this.isTablet,
    required this.opponents,
    this.onLifeDelta,
    this.onCommanderDamage,
    this.onManaDelta,
    this.onManaClear,
    this.onCounterDelta,
    this.onClaimMonarch,
    this.onClaimInitiative,
    this.onArtOverride,
    this.onToggleEliminated,
  });

  @override
  State<PlayerQuadrantWidget> createState() => _PlayerQuadrantWidgetState();
}

class _PlayerQuadrantWidgetState extends State<PlayerQuadrantWidget> {
  int _transientDelta = 0;
  Timer? _deltaFadeTimer;
  Timer? _accelerationTimer;
  bool _isDrawerOpen = false;

  void _handleLifeTap(int delta) {
    HapticFeedback.lightImpact();
    widget.onLifeDelta?.call(delta);
    setState(() {
      _transientDelta += delta;
    });
    _deltaFadeTimer?.cancel();
    _deltaFadeTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _transientDelta = 0;
        });
      }
    });
  }

  void _startAcceleration(int delta) {
    _handleLifeTap(delta);
    int step = 0;
    _accelerationTimer = Timer(const Duration(milliseconds: 350), () {
      void tick() {
        step++;
        final multiplier = step > 5 ? 5 : 1;
        _handleLifeTap(delta * multiplier);
        final nextDelay = step > 10
            ? 60
            : step > 5
                ? 80
                : 120;
        _accelerationTimer = Timer(Duration(milliseconds: nextDelay), tick);
      }

      tick();
    });
  }

  void _stopAcceleration() {
    _accelerationTimer?.cancel();
  }

  @override
  void dispose() {
    _deltaFadeTimer?.cancel();
    _accelerationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = widget.player;
    final isLethal = player.isLethal;

    return LayoutBuilder(
      builder: (context, constraints) {
        final quadrantHeight = constraints.maxHeight;
        final maxDrawerHeight = (quadrantHeight - 56.0).clamp(60.0, double.infinity);

        return Container(
          decoration: BoxDecoration(
            color: isLethal
                ? Colors.red.shade900.withValues(alpha: 0.3)
                : const Color(0xFF1E1E2C),
            border: player.hasAnyLethalCommanderDamage
                ? Border.all(color: Colors.redAccent, width: 3)
                : Border.all(color: Colors.white10, width: 0.5),
          ),
          child: Stack(
            children: [
              // Commander Art Backdrop with dark vignette gradient (Feature 30)
              if (player.commanderArtCropUrl != null &&
                  player.commanderArtCropUrl!.isNotEmpty)
                Positioned.fill(
                  child: CommanderArtBackdrop(
                    imageUrl: player.commanderArtCropUrl,
                    opacity: 0.30,
                  ),
                ),

              // Player Header Bar (Name, Seat, Status Badges)
              Positioned(
                top: 8,
                left: 12,
                right: 12,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              player.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          if (widget.onArtOverride != null) ...[
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: widget.onArtOverride,
                              child: const Icon(
                                Icons.image_search,
                                size: 14,
                                color: Colors.white54,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (player.commanderTax > 0 && !widget.isTablet)
                              Container(
                                margin: const EdgeInsets.only(left: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.purple.shade800.withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Tax: +${player.commanderTax * 2}',
                                  style: const TextStyle(fontSize: 10, color: Colors.white),
                                ),
                              ),
                            if (player.isMonarch)
                              Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: GestureDetector(
                                  onTap: widget.onClaimMonarch,
                                  child: const Chip(
                                    key: Key('chip_monarch'),
                                    label: Text(
                                      '👑 Monarch',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                    backgroundColor: Colors.amber,
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    padding: EdgeInsets.zero,
                                  ),
                                ),
                              ),
                            if (player.hasInitiative)
                              Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: GestureDetector(
                                  onTap: widget.onClaimInitiative,
                                  child: const Chip(
                                    key: Key('chip_initiative'),
                                    label: Text(
                                      '🗡 Initiative',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    backgroundColor: Colors.lightBlue,
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    padding: EdgeInsets.zero,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Split Touch Hitboxes (- / +) Layer (50/50 split across full quadrant width)
              Positioned.fill(
                child: Row(
                  children: [
                    // Left Hitbox: Decrement Life (-1)
                    Expanded(
                      child: GestureDetector(
                        key: Key('hitbox_minus_${player.id}'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _handleLifeTap(-1),
                        onLongPressStart: (_) => _startAcceleration(-1),
                        onLongPressEnd: (_) => _stopAcceleration(),
                        onLongPressCancel: () => _stopAcceleration(),
                        child: Container(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.only(left: 12),
                          child: const Icon(Icons.remove, color: Colors.white24, size: 28),
                        ),
                      ),
                    ),

                    // Right Hitbox: Increment Life (+1)
                    Expanded(
                      child: GestureDetector(
                        key: Key('hitbox_plus_${player.id}'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _handleLifeTap(1),
                        onLongPressStart: (_) => _startAcceleration(1),
                        onLongPressEnd: (_) => _stopAcceleration(),
                        onLongPressCancel: () => _stopAcceleration(),
                        child: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 12),
                          child: const Icon(Icons.add, color: Colors.white24, size: 28),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Massive Life Display & Transient Delta Badge Overlay
              // Layered with IgnorePointer so all touch events pass through cleanly to hitboxes below.
              // Centered with bounded horizontal constraints allowing FittedBox to dynamically scale down.
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '${player.life}',
                              key: Key('life_display_${player.id}'),
                              style: TextStyle(
                                fontSize: 64,
                                fontWeight: FontWeight.bold,
                                color: isLethal ? Colors.redAccent : Colors.white,
                                fontFeatures: const [FontFeature.tabularFigures()],
                                shadows: const [
                                  Shadow(
                                    blurRadius: 10.0,
                                    color: Colors.black,
                                    offset: Offset(2.0, 2.0),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Transient accumulating delta badge
                          if (_transientDelta != 0)
                            Container(
                              key: Key('delta_badge_${player.id}'),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _transientDelta > 0 ? Colors.green : Colors.red,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black45,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                _transientDelta > 0 ? '+$_transientDelta' : '$_transientDelta',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // 21 Commander Damage Lethal Banner
              if (player.hasAnyLethalCommanderDamage)
                Positioned(
                  top: 36,
                  left: 0,
                  right: 0,
                  child: Container(
                    key: Key('commander_lethal_alert_${player.id}'),
                    color: Colors.redAccent.withValues(alpha: 0.85),
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.warning, color: Colors.white, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'LETHAL COMMANDER DAMAGE (21+)',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // 10 Poison Lethal Alert
              if (player.isPoisonLethal)
                Positioned(
                  top: 56,
                  left: 0,
                  right: 0,
                  child: Container(
                    key: Key('poison_lethal_alert_${player.id}'),
                    color: Colors.green.shade800.withValues(alpha: 0.85),
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.dangerous, color: Colors.white, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'LETHAL POISON (10+)',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Lethal Defeat State Overlay
              if (player.isEliminated)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.65),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.dangerous, color: Colors.redAccent, size: 40),
                        const SizedBox(height: 6),
                        const Text(
                          'ELIMINATED',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            letterSpacing: 2,
                          ),
                        ),
                        if (widget.onToggleEliminated != null)
                          TextButton.icon(
                            onPressed: widget.onToggleEliminated,
                            icon: const Icon(Icons.undo, size: 14, color: Colors.white70),
                            label: const Text('Revive', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          ),
                      ],
                    ),
                  ),
                ),

              // Secondary Trackers & Commander Damage Tool Rail / Drawer
              if (widget.isTablet)
                // Perpetual Tool Rail for Tablets (>= 600dp)
                Positioned(
                  bottom: 8,
                  left: 8,
                  right: 8,
                  child: ToolDrawerOrRail(
                    player: player,
                    opponents: widget.opponents,
                    isTablet: true,
                    onCommanderDamage: widget.onCommanderDamage,
                    onManaDelta: widget.onManaDelta,
                    onManaClear: widget.onManaClear,
                    onCounterDelta: widget.onCounterDelta,
                    onClaimMonarch: widget.onClaimMonarch,
                    onClaimInitiative: widget.onClaimInitiative,
                  ),
                )
              else ...[
                // Pull-out drawer toggle button for Phones (< 600dp)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: IconButton(
                    key: Key('drawer_toggle_${player.id}'),
                    icon: Icon(
                      _isDrawerOpen ? Icons.close : Icons.tune,
                      color: Colors.white70,
                    ),
                    onPressed: () {
                      setState(() {
                        _isDrawerOpen = !_isDrawerOpen;
                      });
                    },
                  ),
                ),

                // Phone drawer panel overlay
                if (_isDrawerOpen)
                  Positioned(
                    bottom: 48,
                    left: 0,
                    right: 0,
                    child: Container(
                      key: Key('drawer_panel_${player.id}'),
                      constraints: BoxConstraints(
                        maxHeight: maxDrawerHeight,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                        border: Border.all(color: Colors.white24, width: 0.5),
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(8),
                        child: ToolDrawerOrRail(
                          player: player,
                          opponents: widget.opponents,
                          isTablet: false,
                          onCommanderDamage: widget.onCommanderDamage,
                          onManaDelta: widget.onManaDelta,
                          onManaClear: widget.onManaClear,
                          onCounterDelta: widget.onCounterDelta,
                          onClaimMonarch: widget.onClaimMonarch,
                          onClaimInitiative: widget.onClaimInitiative,
                          onCloseDrawer: () {
                            setState(() {
                              _isDrawerOpen = false;
                            });
                          },
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}
