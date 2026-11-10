// Copyright (c) 2026 Countr. All rights reserved.

import 'package:flutter/material.dart';

import 'package:countr/features/life_counter/domain/models/pod_state.dart';

/// Pod layout classification based on active player count.
enum PodLayoutType {
  /// 1-player testing or playtest view.
  solo,

  /// 2-player horizontal split across the table (Feature 16).
  oneVsOne,

  /// 3-player asymmetric layout (2 top inverted, 1 bottom upright) (Feature 17).
  threePlayer,

  /// 4-player 2x2 quadrant grid (2 top inverted, 2 bottom upright) (Feature 18).
  fourPlayer,

  /// 5-player hybrid grid (3 top inverted, 2 bottom upright) (Feature 19).
  fivePlayer,

  /// 6-player 2x3 grid (3 top inverted, 3 bottom upright) (Feature 20).
  sixPlayer,
}

/// Seating position metadata for a player quadrant within the pod table layout.
class PodSeatingSlot {
  final PodPlayerState player;
  final int seatIndex;
  final bool isTopRow;
  final int quarterTurns;
  final double flexWidth;

  const PodSeatingSlot({
    required this.player,
    required this.seatIndex,
    required this.isTopRow,
    required this.quarterTurns,
    this.flexWidth = 1.0,
  });
}

/// Signature for building individual player quadrants in the pod layout.
typedef QuadrantWidgetBuilder = Widget Function(
  BuildContext context,
  PodPlayerState player, {
  required bool isTopRow,
  required bool isTablet,
});

/// Responsive dynamic pod layout engine executing zero-overflow physical tabletop geometry
/// for MTG games ranging from 1v1 up to 6-player pods.
///
/// Implements Features 16-21:
/// - Feature 16: 1v1 Split Pod Layout (Top rotated 180°, Bottom 0°)
/// - Feature 17: 3-Player Asymmetric Pod Layout (Top 2x 50% rotated 180°, Bottom 1x 100% 0°)
/// - Feature 18: 4-Player 2x2 Quadrant Grid (Top 2x rotated 180°, Bottom 2x 0°)
/// - Feature 19: 5-Player Hybrid Pod Layout (Top 3x 33.3% rotated 180°, Bottom 2x 50% 0°)
/// - Feature 20: 6-Player 2x3 Grid Layout (Top 3x rotated 180°, Bottom 3x 0°)
/// - Feature 21: Opposing Player Inversion (RotatedBox(quarterTurns: isTopRow ? 2 : 0))
/// Pod layout orientation variants.
enum PodLayoutVariant {
  layoutA,
  layoutB,
  legacy;

  static PodLayoutVariant parse(String? value) {
    if (value == null) return PodLayoutVariant.legacy;
    final normalized = value.trim().toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');
    if (normalized == 'a' || normalized == 'layouta') {
      return PodLayoutVariant.layoutA;
    }
    if (normalized == 'b' || normalized == 'layoutb') {
      return PodLayoutVariant.layoutB;
    }
    return PodLayoutVariant.legacy;
  }
}

class PodLayoutEngine extends StatelessWidget {
  final List<PodPlayerState> players;
  final bool isTablet;
  final QuadrantWidgetBuilder quadrantBuilder;
  final Color dividerColor;
  final double dividerThickness;
  final bool showDividers;

  /// Layout variant: 'layoutA', 'layoutB', or legacy ('opposed', 'standard', 'radial').
  /// Defaults to 'opposed' for backward compatibility.
  final String layoutVariant;

  /// When true, overrides all player rotations to quarterTurns: 0.
  final bool isCameraMode;

  const PodLayoutEngine({
    super.key,
    required this.players,
    required this.isTablet,
    required this.quadrantBuilder,
    this.dividerColor = Colors.white24,
    this.dividerThickness = 2.0,
    this.showDividers = false,
    this.layoutVariant = 'opposed',
    this.isCameraMode = false,
  });

  /// Resolves the layout configuration enum for a given player count.
  static PodLayoutType resolveLayoutType(int count) {
    if (count <= 1) return PodLayoutType.solo;
    if (count == 2) return PodLayoutType.oneVsOne;
    if (count == 3) return PodLayoutType.threePlayer;
    if (count == 4) return PodLayoutType.fourPlayer;
    if (count == 5) return PodLayoutType.fivePlayer;
    return PodLayoutType.sixPlayer;
  }

  /// Determines whether a seat index corresponds to the top row across standard MTG pod seating.
  static bool isTopRowSeat(int seatIndex, int playerCount) {
    switch (playerCount) {
      case 2:
        return seatIndex == 1;
      case 3:
        return seatIndex == 1 || seatIndex == 2;
      case 4:
        return seatIndex == 1 || seatIndex == 2;
      case 5:
        return seatIndex == 1 || seatIndex == 2 || seatIndex == 3;
      case 6:
      default:
        return seatIndex == 1 || seatIndex == 2 || seatIndex == 3;
    }
  }

  /// Safely extracts a player by index with fallback to avoid out-of-bounds errors.
  static PodPlayerState safeGetPlayer(List<PodPlayerState> players, int index) {
    if (index >= 0 && index < players.length) {
      return players[index];
    }
    if (players.isNotEmpty) {
      return players.first;
    }
    return PodPlayerState(
      id: 'fallback_$index',
      seatIndex: index,
      name: 'Player ${index + 1}',
      life: 40,
    );
  }

  /// Sorts players by seatIndex to guarantee deterministic physical seating.
  static List<PodPlayerState> normalizePlayers(List<PodPlayerState> players) {
    final list = List<PodPlayerState>.from(players);
    list.sort((a, b) => a.seatIndex.compareTo(b.seatIndex));
    return list;
  }

  Widget _buildPlayerSlot(
    BuildContext context, {
    required PodPlayerState player,
    required int quarterTurns,
    required bool isTopRow,
  }) {
    final effectiveQuarterTurns = isCameraMode ? 0 : quarterTurns;
    final quadrant = quadrantBuilder(
      context,
      player,
      isTopRow: isTopRow,
      isTablet: isTablet,
    );

    if (effectiveQuarterTurns % 4 == 0) {
      return quadrant;
    }
    return RotatedBox(
      quarterTurns: effectiveQuarterTurns % 4,
      child: quadrant,
    );
  }

  Widget _buildHorizontalDivider() {
    return Divider(
      height: dividerThickness,
      thickness: dividerThickness,
      color: dividerColor,
    );
  }

  Widget _buildVerticalDivider() {
    return VerticalDivider(
      width: dividerThickness,
      thickness: dividerThickness,
      color: dividerColor,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) {
      return const Center(
        child: Text(
          'No players in pod',
          style: TextStyle(color: Colors.white54, fontSize: 16),
        ),
      );
    }

    final normalized = normalizePlayers(players);
    final variant = PodLayoutVariant.parse(layoutVariant);

    if (variant == PodLayoutVariant.layoutA) {
      return _buildLayoutA(context, normalized);
    } else if (variant == PodLayoutVariant.layoutB) {
      return _buildLayoutB(context, normalized);
    } else {
      return _buildLegacyLayout(context, normalized);
    }
  }

  /// Routes legacy layout strings ('opposed', 'standard', 'radial') to preserve exact test compatibility.
  Widget _buildLegacyLayout(BuildContext context, List<PodPlayerState> normalized) {
    final count = normalized.length;
    switch (count) {
      case 1:
        return _buildSoloLayout(context, normalized);
      case 2:
        return _build1v1Layout(context, normalized);
      case 3:
        return _build3PlayerLayout(context, normalized);
      case 4:
        return _build4PlayerLayout(context, normalized);
      case 5:
        return _build5PlayerLayout(context, normalized);
      case 6:
      default:
        return _build6PlayerLayout(context, normalized);
    }
  }

  /// 1-Player Solo / Playtest View (100% viewport, 0° rotation).
  Widget _buildSoloLayout(BuildContext context, List<PodPlayerState> p) {
    return _buildPlayerSlot(
      context,
      player: safeGetPlayer(p, 0),
      quarterTurns: 0,
      isTopRow: false,
    );
  }

  /// Feature 16: 1v1 Horizontal Split Layout (Legacy).
  /// Top player (Seat 1) inverted 180° facing opponent; Bottom player (Seat 0) upright 0°.
  Widget _build1v1Layout(BuildContext context, List<PodPlayerState> p) {
    final topPlayer = safeGetPlayer(p, 1);
    final bottomPlayer = safeGetPlayer(p, 0);

    return Column(
      children: [
        Expanded(
          child: _buildPlayerSlot(
            context,
            player: topPlayer,
            quarterTurns: 2,
            isTopRow: true,
          ),
        ),
        if (showDividers) _buildHorizontalDivider(),
        Expanded(
          child: _buildPlayerSlot(
            context,
            player: bottomPlayer,
            quarterTurns: 0,
            isTopRow: false,
          ),
        ),
      ],
    );
  }

  /// Feature 17: 3-Player Asymmetric Pod Layout (Legacy).
  /// Top row: Seats 1 and 2 (50% width each, inverted 180°).
  /// Bottom row: Seat 0 (100% width, upright 0°).
  Widget _build3PlayerLayout(BuildContext context, List<PodPlayerState> p) {
    final p1 = safeGetPlayer(p, 0); // Bottom
    final p2 = safeGetPlayer(p, 1); // Top Left
    final p3 = safeGetPlayer(p, 2); // Top Right

    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildPlayerSlot(
                  context,
                  player: p2,
                  quarterTurns: 2,
                  isTopRow: true,
                ),
              ),
              if (showDividers) _buildVerticalDivider(),
              Expanded(
                child: _buildPlayerSlot(
                  context,
                  player: p3,
                  quarterTurns: 2,
                  isTopRow: true,
                ),
              ),
            ],
          ),
        ),
        if (showDividers) _buildHorizontalDivider(),
        Expanded(
          child: _buildPlayerSlot(
            context,
            player: p1,
            quarterTurns: 0,
            isTopRow: false,
          ),
        ),
      ],
    );
  }

  /// Feature 18: 4-Player 2x2 Quadrant Grid (Legacy).
  /// Top row: Seats 1 and 2 (inverted 180°).
  /// Bottom row: Seats 0 and 3 (upright 0°).
  Widget _build4PlayerLayout(BuildContext context, List<PodPlayerState> p) {
    final p1 = safeGetPlayer(p, 0); // Bottom Left
    final p2 = safeGetPlayer(p, 1); // Top Left
    final p3 = safeGetPlayer(p, 2); // Top Right
    final p4 = safeGetPlayer(p, 3); // Bottom Right

    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildPlayerSlot(
                  context,
                  player: p2,
                  quarterTurns: 2,
                  isTopRow: true,
                ),
              ),
              if (showDividers) _buildVerticalDivider(),
              Expanded(
                child: _buildPlayerSlot(
                  context,
                  player: p3,
                  quarterTurns: 2,
                  isTopRow: true,
                ),
              ),
            ],
          ),
        ),
        if (showDividers) _buildHorizontalDivider(),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildPlayerSlot(
                  context,
                  player: p1,
                  quarterTurns: 0,
                  isTopRow: false,
                ),
              ),
              if (showDividers) _buildVerticalDivider(),
              Expanded(
                child: _buildPlayerSlot(
                  context,
                  player: p4,
                  quarterTurns: 0,
                  isTopRow: false,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Feature 19: 5-Player Hybrid Pod Layout (Legacy).
  /// Top row: Seats 1, 2, 3 (33.3% width each, inverted 180°).
  /// Bottom row: Seats 0, 4 (50% width each, upright 0°).
  Widget _build5PlayerLayout(BuildContext context, List<PodPlayerState> p) {
    final p1 = safeGetPlayer(p, 0); // Bottom Left
    final p2 = safeGetPlayer(p, 1); // Top Left
    final p3 = safeGetPlayer(p, 2); // Top Middle
    final p4 = safeGetPlayer(p, 3); // Top Right
    final p5 = safeGetPlayer(p, 4); // Bottom Right

    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildPlayerSlot(
                  context,
                  player: p2,
                  quarterTurns: 2,
                  isTopRow: true,
                ),
              ),
              if (showDividers) _buildVerticalDivider(),
              Expanded(
                child: _buildPlayerSlot(
                  context,
                  player: p3,
                  quarterTurns: 2,
                  isTopRow: true,
                ),
              ),
              if (showDividers) _buildVerticalDivider(),
              Expanded(
                child: _buildPlayerSlot(
                  context,
                  player: p4,
                  quarterTurns: 2,
                  isTopRow: true,
                ),
              ),
            ],
          ),
        ),
        if (showDividers) _buildHorizontalDivider(),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildPlayerSlot(
                  context,
                  player: p1,
                  quarterTurns: 0,
                  isTopRow: false,
                ),
              ),
              if (showDividers) _buildVerticalDivider(),
              Expanded(
                child: _buildPlayerSlot(
                  context,
                  player: p5,
                  quarterTurns: 0,
                  isTopRow: false,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Feature 20: 6-Player 2x3 Grid Layout (Legacy).
  /// Top row: Seats 1, 2, 3 (33.3% width each, inverted 180°).
  /// Bottom row: Seats 0, 4, 5 (33.3% width each, upright 0°).
  Widget _build6PlayerLayout(BuildContext context, List<PodPlayerState> p) {
    final p1 = safeGetPlayer(p, 0); // Bottom Left
    final p2 = safeGetPlayer(p, 1); // Top Left
    final p3 = safeGetPlayer(p, 2); // Top Middle
    final p4 = safeGetPlayer(p, 3); // Top Right
    final p5 = safeGetPlayer(p, 4); // Bottom Middle
    final p6 = safeGetPlayer(p, 5); // Bottom Right

    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildPlayerSlot(
                  context,
                  player: p2,
                  quarterTurns: 2,
                  isTopRow: true,
                ),
              ),
              if (showDividers) _buildVerticalDivider(),
              Expanded(
                child: _buildPlayerSlot(
                  context,
                  player: p3,
                  quarterTurns: 2,
                  isTopRow: true,
                ),
              ),
              if (showDividers) _buildVerticalDivider(),
              Expanded(
                child: _buildPlayerSlot(
                  context,
                  player: p4,
                  quarterTurns: 2,
                  isTopRow: true,
                ),
              ),
            ],
          ),
        ),
        if (showDividers) _buildHorizontalDivider(),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildPlayerSlot(
                  context,
                  player: p1,
                  quarterTurns: 0,
                  isTopRow: false,
                ),
              ),
              if (showDividers) _buildVerticalDivider(),
              Expanded(
                child: _buildPlayerSlot(
                  context,
                  player: p5,
                  quarterTurns: 0,
                  isTopRow: false,
                ),
              ),
              if (showDividers) _buildVerticalDivider(),
              Expanded(
                child: _buildPlayerSlot(
                  context,
                  player: p6,
                  quarterTurns: 0,
                  isTopRow: false,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Milestone 2: Layout A physical tabletop geometry.
  /// - 1P: Solo (quarterTurns: 0)
  /// - 2P: Face-to-Face (Top: Seat 1 [2], Bottom: Seat 0 [0])
  /// - 3P: Side-by-Side + Head (Top: Seat 1 [1] & Seat 2 [3], Bottom: Seat 0 [0])
  /// - 4P: 2x2 Grid Side Seating (Top: Seat 1 [1] & Seat 2 [3], Bottom: Seat 0 [1] & Seat 3 [3])
  /// - 5P: Grid (Top: Seat 1 [1] & Seat 2 [3], Mid: Seat 3 [1] & Seat 4 [3], Bottom: Seat 0 [0])
  /// - 6P: 2x3 Side Grid (Left col all 1, Right col all 3)
  Widget _buildLayoutA(BuildContext context, List<PodPlayerState> p) {
    final count = p.length;
    switch (count) {
      case 1:
        return _buildSoloLayout(context, p);
      case 2:
        return Column(
          children: [
            Expanded(
              child: _buildPlayerSlot(
                context,
                player: safeGetPlayer(p, 1),
                quarterTurns: 2,
                isTopRow: true,
              ),
            ),
            if (showDividers) _buildHorizontalDivider(),
            Expanded(
              child: _buildPlayerSlot(
                context,
                player: safeGetPlayer(p, 0),
                quarterTurns: 0,
                isTopRow: false,
              ),
            ),
          ],
        );
      case 3:
        return Column(
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _buildPlayerSlot(
                      context,
                      player: safeGetPlayer(p, 1),
                      quarterTurns: 1,
                      isTopRow: true,
                    ),
                  ),
                  if (showDividers) _buildVerticalDivider(),
                  Expanded(
                    child: _buildPlayerSlot(
                      context,
                      player: safeGetPlayer(p, 2),
                      quarterTurns: 3,
                      isTopRow: true,
                    ),
                  ),
                ],
              ),
            ),
            if (showDividers) _buildHorizontalDivider(),
            Expanded(
              child: _buildPlayerSlot(
                context,
                player: safeGetPlayer(p, 0),
                quarterTurns: 0,
                isTopRow: false,
              ),
            ),
          ],
        );
      case 4:
        return Column(
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _buildPlayerSlot(
                      context,
                      player: safeGetPlayer(p, 1),
                      quarterTurns: 1,
                      isTopRow: true,
                    ),
                  ),
                  if (showDividers) _buildVerticalDivider(),
                  Expanded(
                    child: _buildPlayerSlot(
                      context,
                      player: safeGetPlayer(p, 2),
                      quarterTurns: 3,
                      isTopRow: true,
                    ),
                  ),
                ],
              ),
            ),
            if (showDividers) _buildHorizontalDivider(),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _buildPlayerSlot(
                      context,
                      player: safeGetPlayer(p, 0),
                      quarterTurns: 1,
                      isTopRow: false,
                    ),
                  ),
                  if (showDividers) _buildVerticalDivider(),
                  Expanded(
                    child: _buildPlayerSlot(
                      context,
                      player: safeGetPlayer(p, 3),
                      quarterTurns: 3,
                      isTopRow: false,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      case 5:
        return Column(
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _buildPlayerSlot(
                      context,
                      player: safeGetPlayer(p, 1),
                      quarterTurns: 1,
                      isTopRow: true,
                    ),
                  ),
                  if (showDividers) _buildVerticalDivider(),
                  Expanded(
                    child: _buildPlayerSlot(
                      context,
                      player: safeGetPlayer(p, 2),
                      quarterTurns: 3,
                      isTopRow: true,
                    ),
                  ),
                ],
              ),
            ),
            if (showDividers) _buildHorizontalDivider(),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _buildPlayerSlot(
                      context,
                      player: safeGetPlayer(p, 3),
                      quarterTurns: 1,
                      isTopRow: false,
                    ),
                  ),
                  if (showDividers) _buildVerticalDivider(),
                  Expanded(
                    child: _buildPlayerSlot(
                      context,
                      player: safeGetPlayer(p, 4),
                      quarterTurns: 3,
                      isTopRow: false,
                    ),
                  ),
                ],
              ),
            ),
            if (showDividers) _buildHorizontalDivider(),
            Expanded(
              child: _buildPlayerSlot(
                context,
                player: safeGetPlayer(p, 0),
                quarterTurns: 0,
                isTopRow: false,
              ),
            ),
          ],
        );
      case 6:
      default:
        return Column(
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _buildPlayerSlot(
                      context,
                      player: safeGetPlayer(p, 1),
                      quarterTurns: 1,
                      isTopRow: true,
                    ),
                  ),
                  if (showDividers) _buildVerticalDivider(),
                  Expanded(
                    child: _buildPlayerSlot(
                      context,
                      player: safeGetPlayer(p, 2),
                      quarterTurns: 3,
                      isTopRow: true,
                    ),
                  ),
                ],
              ),
            ),
            if (showDividers) _buildHorizontalDivider(),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _buildPlayerSlot(
                      context,
                      player: safeGetPlayer(p, 3),
                      quarterTurns: 1,
                      isTopRow: false,
                    ),
                  ),
                  if (showDividers) _buildVerticalDivider(),
                  Expanded(
                    child: _buildPlayerSlot(
                      context,
                      player: safeGetPlayer(p, 4),
                      quarterTurns: 3,
                      isTopRow: false,
                    ),
                  ),
                ],
              ),
            ),
            if (showDividers) _buildHorizontalDivider(),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _buildPlayerSlot(
                      context,
                      player: safeGetPlayer(p, 0),
                      quarterTurns: 1,
                      isTopRow: false,
                    ),
                  ),
                  if (showDividers) _buildVerticalDivider(),
                  Expanded(
                    child: _buildPlayerSlot(
                      context,
                      player: safeGetPlayer(p, 5),
                      quarterTurns: 3,
                      isTopRow: false,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
    }
  }

  /// Milestone 2: Layout B physical tabletop geometry.
  /// - 1P: Solo (quarterTurns: 0)
  /// - 2P: Side-by-Side (Left: Seat 0 [1], Right: Seat 1 [3])
  /// - 3P: Opposed (Top: Seat 1 [2], Bottom row: Seat 0 [0] & Seat 2 [0])
  /// - 4P: Head-of-Table (Top: Seat 1 [2], Middle: Seat 2 [1] & Seat 3 [3], Bottom: Seat 0 [0])
  /// - 5P: Opposed (Top: Seat 1 [2] & Seat 2 [2], Bottom: Seat 0 [0], Seat 3 [0], Seat 4 [0])
  /// - 6P: Head-of-Table (Top: Seat 1 [2], Middle 2x2: Seats 2 [1], 3 [3], 4 [1], 5 [3], Bottom: Seat 0 [0])
  Widget _buildLayoutB(BuildContext context, List<PodPlayerState> p) {
    final count = p.length;
    switch (count) {
      case 1:
        return _buildSoloLayout(context, p);
      case 2:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _buildPlayerSlot(
                context,
                player: safeGetPlayer(p, 0),
                quarterTurns: 1,
                isTopRow: false,
              ),
            ),
            if (showDividers) _buildVerticalDivider(),
            Expanded(
              child: _buildPlayerSlot(
                context,
                player: safeGetPlayer(p, 1),
                quarterTurns: 3,
                isTopRow: true,
              ),
            ),
          ],
        );
      case 3:
        return Column(
          children: [
            Expanded(
              child: _buildPlayerSlot(
                context,
                player: safeGetPlayer(p, 1),
                quarterTurns: 2,
                isTopRow: true,
              ),
            ),
            if (showDividers) _buildHorizontalDivider(),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _buildPlayerSlot(
                      context,
                      player: safeGetPlayer(p, 0),
                      quarterTurns: 0,
                      isTopRow: false,
                    ),
                  ),
                  if (showDividers) _buildVerticalDivider(),
                  Expanded(
                    child: _buildPlayerSlot(
                      context,
                      player: safeGetPlayer(p, 2),
                      quarterTurns: 0,
                      isTopRow: false,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      case 4:
        return Column(
          children: [
            Expanded(
              child: _buildPlayerSlot(
                context,
                player: safeGetPlayer(p, 1),
                quarterTurns: 2,
                isTopRow: true,
              ),
            ),
            if (showDividers) _buildHorizontalDivider(),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _buildPlayerSlot(
                      context,
                      player: safeGetPlayer(p, 2),
                      quarterTurns: 1,
                      isTopRow: false,
                    ),
                  ),
                  if (showDividers) _buildVerticalDivider(),
                  Expanded(
                    child: _buildPlayerSlot(
                      context,
                      player: safeGetPlayer(p, 3),
                      quarterTurns: 3,
                      isTopRow: false,
                    ),
                  ),
                ],
              ),
            ),
            if (showDividers) _buildHorizontalDivider(),
            Expanded(
              child: _buildPlayerSlot(
                context,
                player: safeGetPlayer(p, 0),
                quarterTurns: 0,
                isTopRow: false,
              ),
            ),
          ],
        );
      case 5:
        return Column(
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _buildPlayerSlot(
                      context,
                      player: safeGetPlayer(p, 1),
                      quarterTurns: 2,
                      isTopRow: true,
                    ),
                  ),
                  if (showDividers) _buildVerticalDivider(),
                  Expanded(
                    child: _buildPlayerSlot(
                      context,
                      player: safeGetPlayer(p, 2),
                      quarterTurns: 2,
                      isTopRow: true,
                    ),
                  ),
                ],
              ),
            ),
            if (showDividers) _buildHorizontalDivider(),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _buildPlayerSlot(
                      context,
                      player: safeGetPlayer(p, 0),
                      quarterTurns: 0,
                      isTopRow: false,
                    ),
                  ),
                  if (showDividers) _buildVerticalDivider(),
                  Expanded(
                    child: _buildPlayerSlot(
                      context,
                      player: safeGetPlayer(p, 3),
                      quarterTurns: 0,
                      isTopRow: false,
                    ),
                  ),
                  if (showDividers) _buildVerticalDivider(),
                  Expanded(
                    child: _buildPlayerSlot(
                      context,
                      player: safeGetPlayer(p, 4),
                      quarterTurns: 0,
                      isTopRow: false,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      case 6:
      default:
        return Column(
          children: [
            Expanded(
              child: _buildPlayerSlot(
                context,
                player: safeGetPlayer(p, 1),
                quarterTurns: 2,
                isTopRow: true,
              ),
            ),
            if (showDividers) _buildHorizontalDivider(),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _buildPlayerSlot(
                      context,
                      player: safeGetPlayer(p, 2),
                      quarterTurns: 1,
                      isTopRow: false,
                    ),
                  ),
                  if (showDividers) _buildVerticalDivider(),
                  Expanded(
                    child: _buildPlayerSlot(
                      context,
                      player: safeGetPlayer(p, 3),
                      quarterTurns: 3,
                      isTopRow: false,
                    ),
                  ),
                ],
              ),
            ),
            if (showDividers) _buildHorizontalDivider(),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _buildPlayerSlot(
                      context,
                      player: safeGetPlayer(p, 4),
                      quarterTurns: 1,
                      isTopRow: false,
                    ),
                  ),
                  if (showDividers) _buildVerticalDivider(),
                  Expanded(
                    child: _buildPlayerSlot(
                      context,
                      player: safeGetPlayer(p, 5),
                      quarterTurns: 3,
                      isTopRow: false,
                    ),
                  ),
                ],
              ),
            ),
            if (showDividers) _buildHorizontalDivider(),
            Expanded(
              child: _buildPlayerSlot(
                context,
                player: safeGetPlayer(p, 0),
                quarterTurns: 0,
                isTopRow: false,
              ),
            ),
          ],
        );
    }
  }
}
