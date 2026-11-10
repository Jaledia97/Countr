// Copyright (c) 2026 Countr. All rights reserved.

import 'package:flutter/material.dart';

import 'package:countr/features/life_counter/domain/models/pod_state.dart';

/// Miniature spatial grid rendered on a player's quadrant card showing incoming
/// commander damage from each opponent according to their relative seating arrangement.
class CommanderSpatialMiniGrid extends StatelessWidget {
  final PodPlayerState player;
  final List<PodPlayerState> opponents;
  final bool colorize;
  final void Function(String opponentId)? onOpponentTap;
  final void Function(String opponentId)? onLongPressSlot;

  const CommanderSpatialMiniGrid({
    super.key,
    required this.player,
    required this.opponents,
    this.colorize = true,
    this.onOpponentTap,
    this.onLongPressSlot,
  });

  /// Resolves a display color accent for an opponent based on colorTheme or index.
  Color _resolveOpponentColor(PodPlayerState opp, int index) {
    if (opp.colorTheme != null && opp.colorTheme!.isNotEmpty) {
      final code = opp.colorTheme!.toUpperCase();
      if (code == 'W' || code == 'WHITE') return const Color(0xFFF8E7B9);
      if (code == 'U' || code == 'BLUE') return const Color(0xFF0E68AB);
      if (code == 'B' || code == 'BLACK') return const Color(0xFF43413F);
      if (code == 'R' || code == 'RED') return const Color(0xFFD3202A);
      if (code == 'G' || code == 'GREEN') return const Color(0xFF00733E);
      if (code == 'PURPLE') return Colors.purpleAccent;
      if (code == 'AMBER') return Colors.amberAccent;
      if (code == 'CYAN') return Colors.cyanAccent;
    }
    const defaultPalette = [
      Colors.blueAccent,
      Colors.redAccent,
      Colors.greenAccent,
      Colors.amberAccent,
      Colors.purpleAccent,
      Colors.cyanAccent,
    ];
    return defaultPalette[index % defaultPalette.length];
  }

  @override
  Widget build(BuildContext context) {
    if (opponents.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      key: Key('cmd_mini_grid_${player.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12, width: 0.5),
      ),
      child: _buildSpatialLayout(context),
    );
  }

  Widget _buildSpatialLayout(BuildContext context) {
    // 2 Players: 1 opponent cell
    if (opponents.length == 1) {
      return _buildCell(opponents.first, 0);
    }

    // 3 Players: 2 opponent cells in a row
    if (opponents.length == 2) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCell(opponents[0], 0),
          const SizedBox(width: 4),
          _buildCell(opponents[1], 1),
        ],
      );
    }

    // 4 Players: 2x2 grid representing table quadrants
    if (opponents.length == 3) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildCell(opponents[0], 0),
              const SizedBox(width: 4),
              _buildCell(opponents[1], 1),
            ],
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildCell(opponents[2], 2),
              const SizedBox(width: 4),
              // Blank/dimmed cell representing self seat in 2x2 grid
              Container(
                width: 24,
                height: 18,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(4),
                ),
                alignment: Alignment.center,
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: Colors.white24,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    // 5 or 6 Players: 2 rows
    final topHalf = opponents.sublist(0, (opponents.length / 2).ceil());
    final bottomHalf = opponents.sublist((opponents.length / 2).ceil());

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: topHalf.asMap().entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: _buildCell(entry.value, entry.key),
            );
          }).toList(),
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: bottomHalf.asMap().entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: _buildCell(entry.value, topHalf.length + entry.key),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCell(PodPlayerState opp, int index) {
    // Total commander damage from this opponent (Partner A + Partner B)
    final dmgA = player.commanderDamageTaken[opp.id] ?? 0;
    final dmgB = player.commanderDamageTaken['${opp.id}_partner'] ?? 0;
    final totalDmg = dmgA + dmgB;
    final isLethal = dmgA >= 21 || dmgB >= 21;
    final oppColor = _resolveOpponentColor(opp, index);

    Color bgColor = Colors.white10;
    if (isLethal) {
      bgColor = Colors.redAccent.withValues(alpha: 0.85);
    } else if (colorize) {
      bgColor = oppColor.withValues(alpha: 0.28);
    }

    return GestureDetector(
      key: Key('cmd_damage_btn_${player.id}_from_${opp.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => onOpponentTap?.call(opp.id),
      onLongPress: () => onLongPressSlot?.call(opp.id),
      child: Container(
        key: Key('cmd_mini_slot_${opp.id}'),
        constraints: const BoxConstraints(minWidth: 24, minHeight: 18),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isLethal
                ? Colors.redAccent
                : (colorize ? oppColor.withValues(alpha: 0.6) : Colors.white24),
            width: isLethal ? 1.0 : 0.5,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          totalDmg > 0 ? '$totalDmg' : (dmgA == 0 && dmgB == 0 ? '0' : '-'),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isLethal
                ? Colors.white
                : (totalDmg > 0 ? Colors.amberAccent : Colors.white70),
          ),
        ),
      ),
    );
  }
}
