// Copyright (c) 2026 Countr. All rights reserved.

import 'package:flutter/material.dart';

import 'package:countr/features/life_counter/domain/models/pod_state.dart';
import '../dialogs/randomizer_hub_modal.dart';
import 'center_hub_button.dart';
import 'player_quadrant_widget.dart';
import 'pod_layout_engine.dart';

/// Top-level responsive MTG life counter pod screen.
/// Orchestrates dynamic seating configurations (1v1, 3P, 4P 2x2, 5P, 6P 2x3),
/// manages opposing player 180° rotation (`RotatedBox(quarterTurns: 2)`),
/// adapts between Phone (collapsible drawers) and Tablet (perpetual rails),
/// and hosts the central crossroads utility hub floating button.
class PodScaffoldWidget extends StatefulWidget {
  final PodState podState;
  final void Function(String playerId, int delta)? onLifeDelta;
  final void Function(String targetId, String sourceId, int delta)? onCommanderDamage;
  final void Function(String playerId, String color, int delta)? onManaDelta;
  final void Function(String playerId)? onManaClear;
  final void Function(String playerId, String counterType, int delta)? onCounterDelta;
  final VoidCallback? onResetGame;
  final VoidCallback? onRandomizerPressed;
  final VoidCallback? onToggleDayNight;
  final void Function(String tokenType, String claimantId)? onClaimToken;
  final void Function(int pickedSeatIndex)? onPlayerSelected;

  /// Optional builder allowing customized quadrant injection (e.g. for testing harnesses or mocks).
  final QuadrantWidgetBuilder? customQuadrantBuilder;

  /// Optional widget overriding the central crossroads floating hub button.
  final Widget? customCenterHubButton;

  /// Divider styling separating quadrants.
  final Color dividerColor;
  final double dividerThickness;

  const PodScaffoldWidget({
    super.key,
    required this.podState,
    this.onLifeDelta,
    this.onCommanderDamage,
    this.onManaDelta,
    this.onManaClear,
    this.onCounterDelta,
    this.onResetGame,
    this.onRandomizerPressed,
    this.onToggleDayNight,
    this.onClaimToken,
    this.onPlayerSelected,
    this.customQuadrantBuilder,
    this.customCenterHubButton,
    this.dividerColor = Colors.white24,
    this.dividerThickness = 2.0,
  });

  @override
  State<PodScaffoldWidget> createState() => _PodScaffoldWidgetState();
}

class _PodScaffoldWidgetState extends State<PodScaffoldWidget> {
  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    // Responsive breakpoint: tablets have shortestSide >= 600dp
    final isTablet = mediaQuery.size.shortestSide >= 600;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Dynamic Pod Layout Grid (Features 16-21)
          PodLayoutEngine(
            players: widget.podState.players,
            isTablet: isTablet,
            dividerColor: widget.dividerColor,
            dividerThickness: widget.dividerThickness,
            quadrantBuilder: widget.customQuadrantBuilder ?? _buildDefaultQuadrant,
          ),

          // Central crossroads floating hub button (Feature 24)
          _buildCenterHub(context),
        ],
      ),
    );
  }

  /// Builds the production PlayerQuadrantWidget instance for an individual player seat.
  Widget _buildDefaultQuadrant(
    BuildContext context,
    PodPlayerState player, {
    required bool isTopRow,
    required bool isTablet,
  }) {
    final opponents = widget.podState.players
        .where((p) => p.id != player.id)
        .toList();

    return PlayerQuadrantWidget(
      key: Key('quadrant_${player.id}'),
      player: player,
      isTablet: isTablet,
      opponents: opponents,
      onLifeDelta: (delta) => widget.onLifeDelta?.call(player.id, delta),
      onCommanderDamage: (oppId, delta) =>
          widget.onCommanderDamage?.call(player.id, oppId, delta),
      onManaDelta: (color, delta) =>
          widget.onManaDelta?.call(player.id, color, delta),
      onManaClear: () => widget.onManaClear?.call(player.id),
      onCounterDelta: (counter, delta) =>
          widget.onCounterDelta?.call(player.id, counter, delta),
      onClaimMonarch: () =>
          widget.onClaimToken?.call('monarch', player.id),
      onClaimInitiative: () =>
          widget.onClaimToken?.call('initiative', player.id),
    );
  }

  /// Central crossroads floating hub button positioned at the exact table intersection.
  Widget _buildCenterHub(BuildContext context) {
    if (widget.customCenterHubButton != null) {
      return Center(child: widget.customCenterHubButton!);
    }

    return Center(
      child: CenterHubButton(
        onPressed: () => _handleCenterHubPressed(context),
      ),
    );
  }

  void _handleCenterHubPressed(BuildContext context) {
    if (widget.onRandomizerPressed != null) {
      widget.onRandomizerPressed!();
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RandomizerHubModal(
        playerCount: widget.podState.players.length,
        onResetGame: widget.onResetGame,
        onPlayerSelected: widget.onPlayerSelected,
      ),
    );
  }
}
