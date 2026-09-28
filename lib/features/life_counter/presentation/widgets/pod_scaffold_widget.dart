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
/// hosts the central crossroads utility hub floating button,
/// provides an exit button, and seamlessly manages local or external pod state.
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
  late PodState _activePodState;

  @override
  void initState() {
    super.initState();
    _activePodState = widget.podState;
  }

  @override
  void didUpdateWidget(PodScaffoldWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.podState != oldWidget.podState) {
      _activePodState = widget.podState;
    }
  }

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
            players: _activePodState.players,
            isTablet: isTablet,
            dividerColor: widget.dividerColor,
            dividerThickness: widget.dividerThickness,
            quadrantBuilder: widget.customQuadrantBuilder ??
                (ctx, player, {required isTopRow, required isTablet}) =>
                    _buildDefaultQuadrant(
                      ctx,
                      player,
                      isTopRow: isTopRow,
                      isTablet: isTablet,
                    ),
          ),

          // Central crossroads floating hub button (Feature 24)
          _buildCenterHub(context),

          // Exit / Back button to return cleanly to Countr shell
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                child: IconButton(
                  key: const Key('life_counter_exit_button'),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.white70,
                    size: 20,
                  ),
                  tooltip: 'Exit Life Tracker',
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ),
          ),
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
    final opponents = _activePodState.players
        .where((p) => p.id != player.id)
        .toList();

    return PlayerQuadrantWidget(
      key: Key('quadrant_${player.id}'),
      player: player,
      isTablet: isTablet,
      opponents: opponents,
      onLifeDelta: (delta) {
        if (widget.onLifeDelta != null) {
          widget.onLifeDelta!(player.id, delta);
        } else {
          setState(() {
            _activePodState = _activePodState.copyWith(
              players: _activePodState.players.map((p) {
                if (p.id == player.id) {
                  final newLife = p.life + delta;
                  final isCmdLethal =
                      p.commanderDamageTaken.values.any((dmg) => dmg >= 21);
                  final isEliminated =
                      newLife <= 0 || p.isPoisonLethal || isCmdLethal;
                  return p.copyWith(life: newLife, isEliminated: isEliminated);
                }
                return p;
              }).toList(),
            );
          });
        }
      },
      onCommanderDamage: (oppId, delta) {
        if (widget.onCommanderDamage != null) {
          widget.onCommanderDamage!(player.id, oppId, delta);
        } else {
          setState(() {
            _activePodState = _activePodState.copyWith(
              players: _activePodState.players.map((p) {
                if (p.id == player.id) {
                  final cur = p.commanderDamageTaken[oppId] ?? 0;
                  final updatedMap =
                      Map<String, int>.from(p.commanderDamageTaken);
                  final nextVal = (cur + delta).clamp(0, 999);
                  updatedMap[oppId] = nextVal;
                  final isCmdLethal =
                      updatedMap.values.any((dmg) => dmg >= 21);
                  final isEliminated =
                      p.life <= 0 || p.isPoisonLethal || isCmdLethal;
                  return p.copyWith(
                    commanderDamageTaken: updatedMap,
                    isEliminated: isEliminated,
                  );
                }
                return p;
              }).toList(),
            );
          });
        }
      },
      onManaDelta: (color, delta) {
        if (widget.onManaDelta != null) {
          widget.onManaDelta!(player.id, color, delta);
        } else {
          setState(() {
            _activePodState = _activePodState.copyWith(
              players: _activePodState.players.map((p) {
                if (p.id == player.id) {
                  final cur = p.floatingMana[color] ?? 0;
                  final updatedMap =
                      Map<String, int>.from(p.floatingMana);
                  updatedMap[color] = (cur + delta).clamp(0, 999);
                  return p.copyWith(floatingMana: updatedMap);
                }
                return p;
              }).toList(),
            );
          });
        }
      },
      onManaClear: () {
        if (widget.onManaClear != null) {
          widget.onManaClear!(player.id);
        } else {
          setState(() {
            _activePodState = _activePodState.copyWith(
              players: _activePodState.players.map((p) {
                if (p.id == player.id) {
                  return p.copyWith(floatingMana: const {});
                }
                return p;
              }).toList(),
            );
          });
        }
      },
      onCounterDelta: (counter, delta) {
        if (widget.onCounterDelta != null) {
          widget.onCounterDelta!(player.id, counter, delta);
        } else {
          setState(() {
            _activePodState = _activePodState.copyWith(
              players: _activePodState.players.map((p) {
                if (p.id == player.id) {
                  if (counter == 'poison') {
                    final newPoison = (p.poison + delta).clamp(0, 99);
                    return p.copyWith(
                      poison: newPoison,
                      isEliminated:
                          p.life <= 0 || newPoison >= 10 || p.hasAnyLethalCommanderDamage,
                    );
                  } else if (counter == 'energy') {
                    return p.copyWith(
                        energy: (p.energy + delta).clamp(0, 999));
                  } else if (counter == 'experience') {
                    return p.copyWith(
                        experience: (p.experience + delta).clamp(0, 999));
                  } else if (counter == 'commander_tax') {
                    return p.copyWith(
                        commanderTax: (p.commanderTax + delta).clamp(0, 999));
                  }
                }
                return p;
              }).toList(),
            );
          });
        }
      },
      onClaimMonarch: () {
        if (widget.onClaimToken != null) {
          widget.onClaimToken!('monarch', player.id);
        } else {
          setState(() {
            _activePodState = _activePodState.copyWith(
              players: _activePodState.players.map((p) {
                return p.copyWith(isMonarch: p.id == player.id);
              }).toList(),
            );
          });
        }
      },
      onClaimInitiative: () {
        if (widget.onClaimToken != null) {
          widget.onClaimToken!('initiative', player.id);
        } else {
          setState(() {
            _activePodState = _activePodState.copyWith(
              players: _activePodState.players.map((p) {
                return p.copyWith(hasInitiative: p.id == player.id);
              }).toList(),
            );
          });
        }
      },
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
        playerCount: _activePodState.players.length,
        onResetGame: widget.onResetGame ??
            () {
              setState(() {
                _activePodState = _activePodState.copyWith(
                  players: _activePodState.players.map((p) {
                    return p.copyWith(
                      life: _activePodState.startingLife,
                      poison: 0,
                      energy: 0,
                      experience: 0,
                      commanderTax: 0,
                      isMonarch: false,
                      hasInitiative: false,
                      isEliminated: false,
                      commanderDamageTaken: const {},
                      floatingMana: const {},
                      stormCount: 0,
                    );
                  }).toList(),
                );
              });
            },
        onPlayerSelected: widget.onPlayerSelected,
      ),
    );
  }
}
