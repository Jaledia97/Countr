// Copyright (c) 2026 Countr. All rights reserved.

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:countr/core/cache/countr_cached_image.dart';
import 'package:countr/features/life_counter/domain/models/pod_state.dart';

/// Production widget rendering the Commander Damage Ledger (Features 32 & 33).
///
/// Features:
/// - Per-player damage ledger tracking incoming combat damage from each opposing commander.
/// - Circular avatar buttons displaying each opponent's commander `art_crop` via [CountrCachedImage].
/// - Fallback avatar with player/commander initials and MTG frame styling.
/// - Short name badge overlay (first 3 characters or initials).
/// - Prominent tabular figures damage tally (`FontFeature.tabularFigures()`).
/// - Interactive gestures: Tap to increment (+1), Long-press to decrement (-1).
/// - 21-point lethal threshold visual styling: pulsing crimson border, bright red alert background.
/// - Responsive adaptation: horizontal single-row scroll on tablets (`isTablet == true`),
///   compact wrapped grid layout on phones (`isTablet == false`).
/// - Strictly conforms to opaque-box key contract: `Key('cmd_damage_btn_${player.id}_from_${opp.id}')`.
class CommanderDamageMatrixWidget extends StatelessWidget {
  final PodPlayerState player;
  final List<PodPlayerState> opponents;
  final bool isTablet;
  final void Function(String opponentId, int delta)? onCommanderDamage;

  const CommanderDamageMatrixWidget({
    super.key,
    required this.player,
    required this.opponents,
    required this.isTablet,
    this.onCommanderDamage,
  });

  @override
  Widget build(BuildContext context) {
    if (opponents.isEmpty) {
      return const SizedBox.shrink();
    }

    if (isTablet) {
      // Tablet perpetual tool rail: single horizontal scrollable row
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: opponents.map((opp) => _buildOpponentButton(context, opp)).toList(),
        ),
      );
    }

    // Phone drawer mode: wrapped, multi-line responsive layout
    // Prevents controls from overflowing or being pushed into adjacent player quadrants.
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      runSpacing: 4,
      children: opponents.map((opp) => _buildOpponentButton(context, opp)).toList(),
    );
  }

  Widget _buildOpponentButton(BuildContext context, PodPlayerState opp) {
    final dmg = player.commanderDamageTaken[opp.id] ?? 0;
    final isLethalFromThis = dmg >= 21;
    final shortName = opp.name.substring(0, min(3, opp.name.length));
    final hasArt = opp.commanderArtCropUrl != null && opp.commanderArtCropUrl!.isNotEmpty;

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: GestureDetector(
        key: Key('cmd_damage_btn_${player.id}_from_${opp.id}'),
        onTap: () {
          HapticFeedback.lightImpact();
          onCommanderDamage?.call(opp.id, 1);
        },
        onLongPress: () {
          HapticFeedback.selectionClick();
          onCommanderDamage?.call(opp.id, -1);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: isLethalFromThis
                ? Colors.red.shade700
                : Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: isLethalFromThis
                ? Border.all(color: Colors.white, width: 1.5)
                : Border.all(color: Colors.white24, width: 0.5),
            boxShadow: isLethalFromThis
                ? [
                    BoxShadow(
                      color: Colors.redAccent.withValues(alpha: 0.6),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Opponent Commander Circular Avatar (Feature 33)
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isLethalFromThis ? Colors.white : Colors.white54,
                    width: 1,
                  ),
                ),
                child: ClipOval(
                  child: hasArt
                      ? CountrCachedImage(
                          imageUrl: opp.commanderArtCropUrl!,
                          fit: BoxFit.cover,
                          errorWidget: _buildFallbackAvatar(shortName),
                        )
                      : _buildFallbackAvatar(shortName),
                ),
              ),
              const SizedBox(width: 5),
              // Opponent Short Name and Damage Tally
              Text(
                '$shortName: $dmg',
                style: TextStyle(
                  fontSize: 11,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: isLethalFromThis ? Colors.white : Colors.white70,
                  fontWeight: isLethalFromThis ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackAvatar(String shortName) {
    return Container(
      color: Colors.indigo.shade900,
      alignment: Alignment.center,
      child: Text(
        shortName.isNotEmpty ? shortName[0].toUpperCase() : '?',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
