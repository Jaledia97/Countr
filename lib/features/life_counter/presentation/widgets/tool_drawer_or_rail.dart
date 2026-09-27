// Copyright (c) 2026 Countr. All rights reserved.

import 'package:flutter/material.dart';

import 'package:countr/features/life_counter/domain/models/pod_state.dart';
import 'commander_damage_matrix.dart';
import 'secondary_counters_bar.dart';

/// Modular Tool Rail / Drawer widget supporting both tablet perpetual tool rail
/// and phone pull-out collapsible panel.
///
/// Features:
/// - Commander damage matrix: interactive opponent buttons with avatar art_crop and lethal 21+ highlighting.
/// - Secondary counters: Poison (☠️), Energy (⚡), Experience (XP), and Commander Tax steppers.
/// - Floating Mana Pool launcher: opens [FloatingManaDrawerWidget] modal bottom sheet.
class ToolDrawerOrRail extends StatelessWidget {
  final PodPlayerState player;
  final List<PodPlayerState> opponents;
  final bool isTablet;
  final void Function(String opponentId, int delta)? onCommanderDamage;
  final void Function(String color, int delta)? onManaDelta;
  final VoidCallback? onManaClear;
  final void Function(String counterType, int delta)? onCounterDelta;
  final VoidCallback? onClaimMonarch;
  final VoidCallback? onClaimInitiative;
  final VoidCallback? onCloseDrawer;

  const ToolDrawerOrRail({
    super.key,
    required this.player,
    required this.opponents,
    required this.isTablet,
    this.onCommanderDamage,
    this.onManaDelta,
    this.onManaClear,
    this.onCounterDelta,
    this.onClaimMonarch,
    this.onClaimInitiative,
    this.onCloseDrawer,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Opponent Commander Damage Matrix (Features 32 & 33)
        if (opponents.isNotEmpty) ...[
          CommanderDamageMatrixWidget(
            player: player,
            opponents: opponents,
            isTablet: isTablet,
            onCommanderDamage: onCommanderDamage,
          ),
          const SizedBox(height: 6),
        ],

        // Secondary Counters & Mana Launcher (Features 35, 36, 37)
        SecondaryCountersBar(
          player: player,
          isTablet: isTablet,
          onCounterDelta: onCounterDelta,
          onManaDelta: onManaDelta,
          onManaClear: onManaClear,
          onClaimMonarch: onClaimMonarch,
          onClaimInitiative: onClaimInitiative,
        ),
      ],
    );
  }
}
