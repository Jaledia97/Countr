// Copyright (c) 2026 Countr. All rights reserved.

import 'package:flutter/material.dart';

import 'package:countr/core/constants/app_colors.dart';
import '../../domain/services/pod_haptics.dart';
import 'center_hub_button.dart';

/// Central floating utility bar (Features 1 & 4) situated at the exact table intersection.
/// Houses 6 core game actions arranged symmetrically around the central die button:
/// 1. Exit App (`Key('life_counter_exit_button')`)
/// 2. Reset Game (`Key('central_hub_reset_button')`)
/// 3. Match Setup & Settings (`Key('central_hub_settings_button')`) with player-count badge
/// 4. Dice & Randomizers (`Key('center_hub_button')`, `Key('central_hub_dice_button')`) at exact geometric center
/// 5. Floating Mana & Storm (`Key('central_hub_mana_button')`)
/// 6. Game History (`Key('central_hub_history_button')`)
/// 7. Quick Random Player Roll (`Key('central_hub_quick_roll_button')`)
///
/// Balanced layout ensures the crossroads die button is located at the exact
/// geometric midpoint `(viewportWidth / 2, viewportHeight / 2)`.
class CentralUtilityBar extends StatelessWidget {
  /// Number of active players in the pod.
  final int playerCount;

  /// Callback when Reset Game button is tapped.
  final VoidCallback? onResetGame;

  /// Callback when Setup/Settings button is tapped.
  final VoidCallback? onOpenSettings;

  /// Callback when Game History button is tapped.
  final VoidCallback? onOpenHistory;

  /// Callback when Floating Mana & Storm button is tapped.
  final VoidCallback? onOpenMana;

  /// Callback when Dice/Randomizer button is tapped.
  final VoidCallback? onOpenRandomizer;

  /// Callback when Dice/Randomizer button is long-pressed for quick starting player roll.
  final VoidCallback? onQuickRandomPlayer;

  /// Callback when Exit App button is tapped. Defaults to `Navigator.of(context).pop()`.
  final VoidCallback? onExitApp;

  /// Whether the bar is collapsed into the compact die hub (for Auto-Hide Menu in M4).
  final bool isCollapsed;

  /// Callback to toggle collapsed/expanded state.
  final VoidCallback? onToggleCollapse;

  /// Specific testing keys.
  final Key? resetKey;
  final Key? settingsKey;
  final Key? diceKey;
  final Key? centerHubKey;
  final Key? manaKey;
  final Key? historyKey;
  final Key? quickRollKey;
  final Key? exitKey;

  const CentralUtilityBar({
    super.key,
    this.playerCount = 4,
    this.onResetGame,
    this.onOpenSettings,
    this.onOpenHistory,
    this.onOpenMana,
    this.onOpenRandomizer,
    this.onQuickRandomPlayer,
    this.onExitApp,
    this.isCollapsed = false,
    this.onToggleCollapse,
    this.resetKey = const Key('central_hub_reset_button'),
    this.settingsKey = const Key('central_hub_settings_button'),
    this.diceKey = const Key('central_hub_dice_button'),
    this.centerHubKey = const Key('center_hub_button'),
    this.manaKey = const Key('central_hub_mana_button'),
    this.historyKey = const Key('central_hub_history_button'),
    this.quickRollKey = const Key('central_hub_quick_roll_button'),
    this.exitKey = const Key('life_counter_exit_button'),
  });

  @override
  Widget build(BuildContext context) {
    const double wingItemWidth = 36.0;
    const double barHeight = 48.0;
    const double pillHeight = 44.0;
    const double expandedPillWidth = 264.0;
    const double collapsedPillWidth = 48.0;
    final double targetWidth = isCollapsed ? collapsedPillWidth : expandedPillWidth;

    return Semantics(
      container: true,
      label: 'Central Table Utilities Bar',
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          height: barHeight,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // 1. Background Pill Container with smooth expansion/collapse
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOutCubic,
                width: targetWidth,
                height: pillHeight,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E2C).withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(pillHeight / 2),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.20),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.65),
                      blurRadius: 10,
                      spreadRadius: 1,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),

              // 2. Wings Row (Symmetrically arranged around center gap)
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // LEFT WING (Exit, Reset, Settings)
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    opacity: isCollapsed ? 0.0 : 1.0,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOutCubic,
                      width: isCollapsed ? 0.0 : 108.0,
                      child: ClipRect(
                        child: OverflowBox(
                          minWidth: 108.0,
                          maxWidth: 108.0,
                          alignment: Alignment.center,
                          child: IgnorePointer(
                            ignoring: isCollapsed,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildIconButton(
                                  key: exitKey,
                                  width: wingItemWidth,
                                  icon: Icons.close_rounded,
                                  iconSize: 18,
                                  iconColor: Colors.white70,
                                  tooltip: 'Exit Life Tracker',
                                  splashColor: Colors.redAccent.withValues(alpha: 0.3),
                                  onPressed: () {
                                    if (onExitApp != null) {
                                      onExitApp!();
                                    } else {
                                      Navigator.of(context).pop();
                                    }
                                  },
                                ),
                                _buildIconButton(
                                  key: resetKey,
                                  width: wingItemWidth,
                                  icon: Icons.restart_alt_rounded,
                                  iconSize: 20,
                                  iconColor: Colors.white70,
                                  tooltip: 'Reset Game',
                                  splashColor: Colors.redAccent.withValues(alpha: 0.3),
                                  onPressed: onResetGame,
                                ),
                                _buildSettingsBadge(
                                  key: settingsKey,
                                  width: wingItemWidth,
                                  playerCount: playerCount,
                                  tooltip: 'Match Setup & Settings ($playerCount Players)',
                                  onPressed: onOpenSettings,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // CENTER GAP (48dp for CenterHubButton)
                  const SizedBox(width: 48.0),

                  // RIGHT WING (Mana, History, Quick Roll)
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    opacity: isCollapsed ? 0.0 : 1.0,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOutCubic,
                      width: isCollapsed ? 0.0 : 108.0,
                      child: ClipRect(
                        child: OverflowBox(
                          minWidth: 108.0,
                          maxWidth: 108.0,
                          alignment: Alignment.center,
                          child: IgnorePointer(
                            ignoring: isCollapsed,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildIconButton(
                                  key: manaKey,
                                  width: wingItemWidth,
                                  icon: Icons.auto_awesome_rounded,
                                  iconSize: 19,
                                  iconColor: Colors.cyanAccent.shade200,
                                  tooltip: 'Floating Mana & Storm',
                                  splashColor: Colors.cyanAccent.withValues(alpha: 0.3),
                                  onPressed: onOpenMana,
                                ),
                                _buildIconButton(
                                  key: historyKey,
                                  width: wingItemWidth,
                                  icon: Icons.history_rounded,
                                  iconSize: 20,
                                  iconColor: Colors.white70,
                                  tooltip: 'Game History & Turn Log',
                                  splashColor: Colors.amberAccent.withValues(alpha: 0.3),
                                  onPressed: onOpenHistory,
                                ),
                                _buildIconButton(
                                  key: quickRollKey,
                                  width: wingItemWidth,
                                  icon: Icons.bolt_rounded,
                                  iconSize: 20,
                                  iconColor: Colors.amberAccent,
                                  tooltip: 'Quick Starting Player Roll',
                                  splashColor: Colors.amberAccent.withValues(alpha: 0.3),
                                  onPressed: onQuickRandomPlayer,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // 3. CENTER ITEM: CenterHubButton (Exact Alignment.center)
              CenterHubButton(
                key: diceKey,
                buttonKey: centerHubKey,
                size: 48.0,
                onPressed: isCollapsed
                    ? (onToggleCollapse ?? onOpenRandomizer)
                    : onOpenRandomizer,
                onLongPress: onQuickRandomPlayer,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds a wing icon button with proper hit area and haptic feedback.
  Widget _buildIconButton({
    required Key? key,
    required double width,
    required IconData icon,
    required double iconSize,
    required Color iconColor,
    required String tooltip,
    required Color splashColor,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: width,
      height: 38.0,
      child: Tooltip(
        message: tooltip,
        child: Semantics(
          button: true,
          label: tooltip,
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: key,
              customBorder: const CircleBorder(),
              splashColor: splashColor,
              onTap: onPressed == null
                  ? null
                  : () {
                      PodHaptics.lightImpact();
                      onPressed();
                    },
              child: Center(
                child: Icon(
                  icon,
                  color: iconColor,
                  size: iconSize,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the Settings action button displaying current player count inside a circle badge.
  Widget _buildSettingsBadge({
    required Key? key,
    required double width,
    required int playerCount,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: width,
      height: 38.0,
      child: Tooltip(
        message: tooltip,
        child: Semantics(
          button: true,
          label: tooltip,
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: key,
              customBorder: const CircleBorder(),
              splashColor: Colors.white24,
              onTap: onPressed == null
                  ? null
                  : () {
                      PodHaptics.lightImpact();
                      onPressed();
                    },
              child: Center(
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$playerCount',
                    style: const TextStyle(
                      color: AppColors.accentGold,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
