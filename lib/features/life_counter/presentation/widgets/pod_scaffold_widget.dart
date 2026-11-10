// Copyright (c) 2026 Countr. All rights reserved.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:countr/features/decks/domain/models/deck_summary.dart';
import 'package:countr/features/life_counter/domain/models/game_history_entry.dart';
import 'package:countr/features/life_counter/domain/models/pod_state.dart';
import 'package:countr/features/life_counter/domain/services/dice_roller_service.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';

import '../../domain/services/pod_haptics.dart';
import '../../domain/services/wakelock_service.dart';
import '../dialogs/game_history_modal.dart';
import '../dialogs/pregame_setup_sheet.dart';
import '../dialogs/randomizer_hub_modal.dart';
import '../dialogs/reset_game_dialog.dart';
import 'central_utility_bar.dart';
import 'floating_mana_drawer_widget.dart';
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

  /// Seating layout orientation ('opposed', 'standard', 'radial').
  final String seatingOrientation;

  /// Layout variant ('A' or 'B' or legacy strings).
  final String layoutVariant;

  /// Whether camera mode is active (all cards facing upright 0°).
  final bool isCameraMode;

  /// OLED True Black mode toggle (#000000).
  final bool isOledMode;

  /// Immersive full-screen gameplay mode (SystemUiMode.immersiveSticky).
  final bool isImmersiveMode;

  /// Card layout density: 'Default', 'Name only', 'Big font'.
  final String cardDensity;

  /// Whether the central utility bar automatically hides after 4 seconds of inactivity.
  final bool autohideMenu;

  /// Whether the screen is kept on / awake during match gameplay.
  final bool keepDisplayAwake;

  /// Whether haptic feedback is triggered on counter and button taps.
  final bool enableHaptics;

  final void Function(String playerId, int delta)? onLifeDelta;
  final void Function(String targetId, String sourceId, int delta)? onCommanderDamage;
  final void Function(String playerId, String color, int delta)? onManaDelta;
  final void Function(String playerId)? onManaClear;
  final void Function(String playerId, int delta)? onStormDelta;
  final void Function(String playerId, String counterType, int delta)? onCounterDelta;
  final VoidCallback? onResetGame;
  final VoidCallback? onRandomizerPressed;
  final VoidCallback? onToggleDayNight;
  final void Function(String tokenType, String claimantId)? onClaimToken;
  final void Function(int pickedSeatIndex)? onPlayerSelected;

  /// Optional DAO providing SQLite deck match synchronization.
  final VaultDao? vaultDao;

  /// Optional builder allowing customized quadrant injection (e.g. for testing harnesses or mocks).
  final QuadrantWidgetBuilder? customQuadrantBuilder;

  /// Optional widget overriding the central crossroads floating hub button.
  final Widget? customCenterHubButton;

  /// Divider styling separating quadrants.
  final Color dividerColor;
  final double dividerThickness;

  /// Whether to render physical Divider/VerticalDivider widgets between quadrants.
  /// Defaults to true for backward-compatible test fixtures, while [PodLayoutEngine] defaults to false.
  final bool showDividers;

  const PodScaffoldWidget({
    super.key,
    required this.podState,
    this.seatingOrientation = 'opposed',
    this.layoutVariant = 'opposed',
    this.isCameraMode = false,
    this.isOledMode = false,
    this.isImmersiveMode = false,
    this.cardDensity = 'Default',
    this.autohideMenu = true,
    this.keepDisplayAwake = true,
    this.enableHaptics = true,
    this.onLifeDelta,
    this.onCommanderDamage,
    this.onManaDelta,
    this.onManaClear,
    this.onStormDelta,
    this.onCounterDelta,
    this.onResetGame,
    this.onRandomizerPressed,
    this.onToggleDayNight,
    this.onClaimToken,
    this.onPlayerSelected,
    this.vaultDao,
    this.customQuadrantBuilder,
    this.customCenterHubButton,
    this.dividerColor = Colors.white24,
    this.dividerThickness = 2.0,
    this.showDividers = true,
  });

  @override
  State<PodScaffoldWidget> createState() => _PodScaffoldWidgetState();
}

class _PodScaffoldWidgetState extends State<PodScaffoldWidget> {
  late PodState _activePodState;
  late String _activeSeatingOrientation;
  late String _activeLayoutVariant;
  late bool _activeCameraMode;
  late String _activeCardDensity;
  late bool _activeOledMode;
  late bool _activeImmersiveMode;
  late bool _activeAutohideMenu;
  late bool _activeWakelock;
  late bool _activeHaptics;

  bool _isCollapsed = false;
  Timer? _autohideTimer;
  int? _highlightedPlayerIndex;
  Timer? _highlightTimer;

  void _triggerPlayerHighlight(int seatIndex) {
    if (seatIndex < 0 || seatIndex >= _activePodState.players.length) return;
    setState(() {
      _highlightedPlayerIndex = seatIndex;
    });
    PodHaptics.mediumImpact();
    widget.onPlayerSelected?.call(seatIndex);

    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(milliseconds: 3000), () {
      if (mounted) {
        setState(() {
          _highlightedPlayerIndex = null;
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _activePodState = widget.podState;
    _activeSeatingOrientation = widget.seatingOrientation;
    _activeLayoutVariant = widget.layoutVariant;
    _activeCameraMode = widget.isCameraMode;
    _activeCardDensity = widget.cardDensity;
    _activeOledMode = widget.isOledMode;
    _activeImmersiveMode = widget.isImmersiveMode;
    _activeAutohideMenu = widget.autohideMenu;
    _activeWakelock = widget.keepDisplayAwake;
    _activeHaptics = widget.enableHaptics;

    PodHaptics.enabled = _activeHaptics;
    if (_activeWakelock) {
      WakelockService.enable();
    }
    if (_activeImmersiveMode) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
    if (_activeAutohideMenu) {
      _startAutohideTimer();
    }
  }

  @override
  void dispose() {
    _autohideTimer?.cancel();
    _highlightTimer?.cancel();
    if (_activeWakelock) {
      WakelockService.disable();
    }
    if (_activeImmersiveMode) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(PodScaffoldWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.podState != oldWidget.podState) {
      _activePodState = widget.podState;
    }
    if (widget.seatingOrientation != oldWidget.seatingOrientation) {
      _activeSeatingOrientation = widget.seatingOrientation;
    }
    if (widget.layoutVariant != oldWidget.layoutVariant) {
      _activeLayoutVariant = widget.layoutVariant;
    }
    if (widget.isCameraMode != oldWidget.isCameraMode) {
      _activeCameraMode = widget.isCameraMode;
    }
    if (widget.cardDensity != oldWidget.cardDensity) {
      _activeCardDensity = widget.cardDensity;
    }
    if (widget.isOledMode != oldWidget.isOledMode) {
      _activeOledMode = widget.isOledMode;
    }
    if (widget.isImmersiveMode != oldWidget.isImmersiveMode) {
      _activeImmersiveMode = widget.isImmersiveMode;
      if (_activeImmersiveMode) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
    }
    if (widget.autohideMenu != oldWidget.autohideMenu) {
      _activeAutohideMenu = widget.autohideMenu;
      if (_activeAutohideMenu) {
        _startAutohideTimer();
      } else {
        _autohideTimer?.cancel();
        _isCollapsed = false;
      }
    }
    if (widget.keepDisplayAwake != oldWidget.keepDisplayAwake) {
      _activeWakelock = widget.keepDisplayAwake;
      if (_activeWakelock) {
        WakelockService.enable();
      } else {
        WakelockService.disable();
      }
    }
    if (widget.enableHaptics != oldWidget.enableHaptics) {
      _activeHaptics = widget.enableHaptics;
      PodHaptics.enabled = _activeHaptics;
    }
  }

  void _startAutohideTimer() {
    _autohideTimer?.cancel();
    if (!_activeAutohideMenu) return;
    _autohideTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      final route = ModalRoute.of(context);
      if (route != null && !route.isCurrent) {
        _startAutohideTimer();
        return;
      }
      setState(() {
        _isCollapsed = true;
      });
    });
  }

  void _handleUserActivity() {
    if (_isCollapsed) {
      setState(() {
        _isCollapsed = false;
      });
    }
    _startAutohideTimer();
  }

  @override
  Widget build(BuildContext context) {
    final hasScope = context.findAncestorWidgetOfExactType<UncontrolledProviderScope>() != null;
    if (hasScope) {
      return Consumer(
        builder: (ctx, ref, _) {
          final cameraMode = widget.isCameraMode || ref.watch(podCameraModeProvider);
          final layoutVar = (widget.layoutVariant != 'opposed' && widget.layoutVariant.isNotEmpty)
              ? widget.layoutVariant
              : ref.watch(podLayoutVariantProvider);
          final seating = (widget.seatingOrientation != 'opposed' && widget.seatingOrientation.isNotEmpty)
              ? widget.seatingOrientation
              : ref.watch(podSeatingOrientationProvider);
          final density = (widget.cardDensity != 'Default')
              ? widget.cardDensity
              : ref.watch(podLayoutDensityProvider);
          final oled = widget.isOledMode || ref.watch(podOledModeProvider);
          final autohide = ref.watch(podAutohideMenuProvider);

          return _buildScaffoldBody(
            ctx,
            cameraMode: cameraMode,
            layoutVariant: layoutVar,
            seatingOrientation: seating,
            cardDensity: density,
            isOledMode: oled,
            autohideMenu: autohide,
          );
        },
      );
    }

    return _buildScaffoldBody(
      context,
      cameraMode: _activeCameraMode,
      layoutVariant: _activeLayoutVariant,
      seatingOrientation: _activeSeatingOrientation,
      cardDensity: _activeCardDensity,
      isOledMode: _activeOledMode,
      autohideMenu: _activeAutohideMenu,
    );
  }

  Widget _buildScaffoldBody(
    BuildContext context, {
    required bool cameraMode,
    required String layoutVariant,
    required String seatingOrientation,
    required String cardDensity,
    required bool isOledMode,
    required bool autohideMenu,
  }) {
    final mediaQuery = MediaQuery.of(context);
    // Responsive breakpoint: tablets have shortestSide >= 600dp
    final isTablet = mediaQuery.size.shortestSide >= 600;
    final effectiveLayoutVariant = (layoutVariant != 'opposed' && layoutVariant.isNotEmpty)
        ? layoutVariant
        : seatingOrientation;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _handleUserActivity(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Dynamic Pod Layout Grid (Features 16-21)
            PodLayoutEngine(
              players: _activePodState.players,
              isTablet: isTablet,
              dividerColor: widget.dividerColor,
              dividerThickness: widget.dividerThickness,
              showDividers: widget.showDividers,
              layoutVariant: effectiveLayoutVariant,
              isCameraMode: cameraMode,
              quadrantBuilder: widget.customQuadrantBuilder ??
                  (ctx, player, {required isTopRow, required isTablet}) =>
                      _buildDefaultQuadrant(
                        ctx,
                        player,
                        isTopRow: isTopRow,
                        isTablet: isTablet,
                        isCameraMode: cameraMode,
                        seatingOrientation: seatingOrientation,
                        cardDensity: cardDensity,
                        isOledMode: isOledMode,
                      ),
            ),

            // Central crossroads floating utility bar (Features 1 & 4)
            _buildCenterHub(context),
          ],
        ),
      ),
    );
  }

  /// Builds the production PlayerQuadrantWidget instance for an individual player seat.
  Widget _buildDefaultQuadrant(
    BuildContext context,
    PodPlayerState player, {
    required bool isTopRow,
    required bool isTablet,
    bool isCameraMode = false,
    String seatingOrientation = 'opposed',
    String cardDensity = 'Default',
    bool isOledMode = false,
  }) {
    final opponents = _activePodState.players
        .where((p) => p.id != player.id)
        .toList();

    final playerIndex = _activePodState.players.indexWhere((p) => p.id == player.id);
    final isHighlighted = _highlightedPlayerIndex != null && playerIndex == _highlightedPlayerIndex;

    Widget quadrant = PlayerQuadrantWidget(
      key: Key('quadrant_${player.id}'),
      player: player,
      isTablet: isTablet,
      opponents: opponents,
      isOledMode: isOledMode,
      colorizeCommanderMiniGrids: _activePodState.colorizeCommanderMiniGrids,
      cardDensity: cardDensity,
      isHighlighted: isHighlighted,
      onCommitLifeHistory: ({
        required String playerId,
        required int startLife,
        required int endLife,
        required int netDelta,
      }) {
        setState(() {
          final entry = GameHistoryEntry.lifeChange(
            playerId: playerId,
            startLife: startLife,
            endLife: endLife,
            netDelta: netDelta,
          );
          _activePodState = _activePodState.copyWith(
            gameHistory: [entry, ..._activePodState.gameHistory],
          );
        });
      },
      onNameChanged: (name) {
        setState(() {
          _activePodState = _activePodState.copyWith(
            players: _activePodState.players.map((p) {
              if (p.id == player.id) {
                return p.copyWith(name: name);
              }
              return p;
            }).toList(),
          );
        });
      },
      onColorChanged: (color) {
        setState(() {
          _activePodState = _activePodState.copyWith(
            players: _activePodState.players.map((p) {
              if (p.id == player.id) {
                return p.copyWith(colorTheme: color);
              }
              return p;
            }).toList(),
          );
        });
      },
      onLinkDeck: (DeckSummary deck) {
        setState(() {
          _activePodState = _activePodState.copyWith(
            players: _activePodState.players.map((p) {
              if (p.id == player.id) {
                return p.copyWith(
                  deckId: deck.id,
                  commanderName: deck.commanderName,
                  commanderArtCropUrl: deck.commanderArtCrop,
                  colorTheme: deck.colorIdentity.isNotEmpty
                      ? deck.colorIdentity.first
                      : p.colorTheme,
                );
              }
              return p;
            }).toList(),
          );
        });
      },
      onUnlinkDeck: () {
        setState(() {
          _activePodState = _activePodState.copyWith(
            players: _activePodState.players.map((p) {
              if (p.id == player.id) {
                return p.copyWith(
                  deckId: null,
                  commanderName: null,
                  commanderArtCropUrl: null,
                );
              }
              return p;
            }).toList(),
          );
        });
      },
      onIgnoreKo: () {
        setState(() {
          _activePodState = _activePodState.copyWith(
            players: _activePodState.players.map((p) {
              if (p.id == player.id) {
                return p.copyWith(isKoIgnored: true, isEliminated: false);
              }
              return p;
            }).toList(),
          );
        });
      },
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
                  final isEliminated = !p.isKoIgnored &&
                      (newLife <= 0 || p.isPoisonLethal || isCmdLethal);
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
          _applyCommanderDamage(player.id, oppId, delta);
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
                      isEliminated: !p.isKoIgnored &&
                          (p.life <= 0 || newPoison >= 10 || p.hasAnyLethalCommanderDamage),
                    );
                  } else if (counter == 'energy') {
                    return p.copyWith(
                        energy: (p.energy + delta).clamp(0, 999));
                  } else if (counter == 'experience') {
                    return p.copyWith(
                        experience: (p.experience + delta).clamp(0, 999));
                  } else if (counter == 'commander_tax' || counter == 'commanderTax') {
                    return p.copyWith(
                        commanderTax: (p.commanderTax + delta).clamp(0, 999));
                  } else if (counter == 'rad' || counter == 'radiation') {
                    return p.copyWith(
                        radCounters: (p.radCounters + delta).clamp(0, 999));
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
            final alreadyClaimed = player.isMonarch;
            _activePodState = _activePodState.copyWith(
              players: _activePodState.players.map((p) {
                return p.copyWith(
                  isMonarch: alreadyClaimed ? false : p.id == player.id,
                );
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
            final alreadyClaimed = player.hasInitiative;
            _activePodState = _activePodState.copyWith(
              players: _activePodState.players.map((p) {
                return p.copyWith(
                  hasInitiative: alreadyClaimed ? false : p.id == player.id,
                );
              }).toList(),
            );
          });
        }
      },
    );

    final effectiveSeating =
        seatingOrientation.isNotEmpty ? seatingOrientation : widget.seatingOrientation;
    if (!isCameraMode && effectiveSeating == 'standard' && isTopRow) {
      // Counter-rotate top row so all players face upright in standard shared orientation
      quadrant = RotatedBox(
        quarterTurns: 2,
        child: quadrant,
      );
    }

    return quadrant;
  }

  void _applyCommanderDamage(String targetId, String oppId, int delta) {
    setState(() {
      _activePodState = _activePodState.copyWith(
        players: _activePodState.players.map((p) {
          if (p.id == targetId) {
            final cur = p.commanderDamageTaken[oppId] ?? 0;
            final updatedMap = Map<String, int>.from(p.commanderDamageTaken);
            final nextVal = (cur + delta).clamp(0, 999);
            final actualDelta = nextVal - cur;
            updatedMap[oppId] = nextVal;
            final isCmdLethal = updatedMap.values.any((dmg) => dmg >= 21);
            final newLife = _activePodState.commanderDamageLifeLoss
                ? p.life - actualDelta
                : p.life;
            final isEliminated = !p.isKoIgnored &&
                (newLife <= 0 || p.isPoisonLethal || isCmdLethal);
            return p.copyWith(
              life: newLife,
              commanderDamageTaken: updatedMap,
              isEliminated: isEliminated,
            );
          }
          return p;
        }).toList(),
      );
    });
  }

  /// Central crossroads floating utility bar positioned at the exact table intersection.
  Widget _buildCenterHub(BuildContext context) {
    if (widget.customCenterHubButton != null) {
      return Center(child: widget.customCenterHubButton!);
    }

    return Center(
      child: CentralUtilityBar(
        playerCount: _activePodState.players.length,
        isCollapsed: _isCollapsed,
        onToggleCollapse: () {
          setState(() {
            _isCollapsed = !_isCollapsed;
          });
          _startAutohideTimer();
        },
        onResetGame: () => _handleResetGame(context),
        onOpenSettings: () => _handleOpenSettings(context),
        onOpenHistory: () => _handleOpenHistory(context),
        onOpenMana: () => _handleOpenMana(context),
        onOpenRandomizer: () => _handleCenterHubPressed(context),
        onQuickRandomPlayer: () => _handleQuickRandomPlayer(context),
        onExitApp: () => Navigator.of(context).pop(),
      ),
    );
  }

  void _handleResetGame(BuildContext context) async {
    if (widget.onResetGame != null) {
      widget.onResetGame!();
      return;
    }

    _autohideTimer?.cancel();
    await ResetGameDialog.show(
      context,
      startingLife: _activePodState.startingLife,
      players: _activePodState.players,
      vaultDao: widget.vaultDao,
      onConfirmAction: (result) {
        _applyResetAction(result);
      },
    );
    if (mounted) {
      _handleUserActivity();
    }
  }

  void _applyResetAction(ResetGameResult result) {
    setState(() {
      switch (result.action) {
        case ResetGameAction.reset:
          _activePodState = _activePodState.copyWith(
            gameHistory: const [],
            players: _activePodState.players.map((p) {
              return p.copyWith(
                life: _activePodState.startingLife,
                poison: 0,
                energy: 0,
                experience: 0,
                commanderTax: 0,
                radCounters: 0,
                isMonarch: false,
                hasInitiative: false,
                isEliminated: false,
                isKoIgnored: false,
                commanderDamageTaken: const {},
                floatingMana: const {'W': 0, 'U': 0, 'B': 0, 'R': 0, 'G': 0, 'C': 0},
                stormCount: 0,
              );
            }).toList(),
          );
          break;
        case ResetGameAction.resetRandomizeSeats:
          final resetPlayers = _activePodState.players.map((p) {
            return p.copyWith(
              life: _activePodState.startingLife,
              poison: 0,
              energy: 0,
              experience: 0,
              commanderTax: 0,
              radCounters: 0,
              isMonarch: false,
              hasInitiative: false,
              isEliminated: false,
              isKoIgnored: false,
              commanderDamageTaken: const {},
              floatingMana: const {'W': 0, 'U': 0, 'B': 0, 'R': 0, 'G': 0, 'C': 0},
              stormCount: 0,
            );
          }).toList()..shuffle();

          final reindexed = [
            for (int i = 0; i < resetPlayers.length; i++)
              resetPlayers[i].copyWith(seatIndex: i)
          ];

          _activePodState = _activePodState.copyWith(
            gameHistory: const [],
            players: reindexed,
          );
          break;
        case ResetGameAction.resetClearProfiles:
          final cleared = [
            for (int i = 0; i < _activePodState.players.length; i++)
              PodPlayerState(
                id: _activePodState.players[i].id,
                seatIndex: _activePodState.players[i].seatIndex,
                name: 'Player ${i + 1}',
                deckId: null,
                commanderCardId: null,
                commanderName: null,
                commanderArtCropUrl: null,
                colorTheme: null,
                life: _activePodState.startingLife,
                poison: 0,
                energy: 0,
                experience: 0,
                commanderTax: 0,
                radCounters: 0,
                isMonarch: false,
                hasInitiative: false,
                commanderDamageTaken: const {},
                floatingMana: const {'W': 0, 'U': 0, 'B': 0, 'R': 0, 'G': 0, 'C': 0},
                stormCount: 0,
                isEliminated: false,
                isKoIgnored: false,
                isLocalDevice: _activePodState.players[i].isLocalDevice,
                peerDeviceId: _activePodState.players[i].peerDeviceId,
              )
          ];
          _activePodState = _activePodState.copyWith(
            gameHistory: const [],
            players: cleared,
          );
          break;
      }
    });
  }

  void _handleOpenSettings(BuildContext context) async {
    _autohideTimer?.cancel();
    final nextPodState = await PregameSetupSheet.show(
      context,
      initialPlayerCount: _activePodState.players.length,
      initialFormat: _activePodState.format,
      initialStartingLife: _activePodState.startingLife,
      initialSeatingOrientation: _activeSeatingOrientation,
      initialLayoutVariant: _activeLayoutVariant,
      initialCameraMode: _activeCameraMode,
      initialOledMode: _activeOledMode,
      initialImmersiveMode: _activeImmersiveMode,
      initialCardDensity: _activeCardDensity,
      initialAutohideMenu: _activeAutohideMenu,
      initialWakelock: _activeWakelock,
      initialHaptics: _activeHaptics,
      isGameInProgress: _activePodState.isGameInProgress,
      existingPodState: _activePodState,
    );
    if (mounted) {
      if (nextPodState != null) {
        setState(() {
          _activePodState = nextPodState;
          _activeSeatingOrientation = PregameSetupSheet.lastSeatingOrientation;
          _activeLayoutVariant = PregameSetupSheet.lastLayoutVariant;
          _activeCameraMode = PregameSetupSheet.lastCameraMode;
          _activeCardDensity = PregameSetupSheet.lastCardDensity;
          _activeOledMode = PregameSetupSheet.lastOledMode;
          _activeImmersiveMode = PregameSetupSheet.lastImmersiveMode;
          _activeAutohideMenu = PregameSetupSheet.lastAutohideMenu;
          _activeWakelock = PregameSetupSheet.lastWakelock;
          _activeHaptics = PregameSetupSheet.lastHaptics;
        });
        PodHaptics.enabled = _activeHaptics;
        if (_activeWakelock) {
          WakelockService.enable();
        } else {
          WakelockService.disable();
        }
        if (_activeImmersiveMode) {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        } else {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        }
      }
      _handleUserActivity();
    }
  }

  void _handleOpenHistory(BuildContext context) async {
    _autohideTimer?.cancel();
    await GameHistoryModal.show(
      context,
      gameHistory: _activePodState.gameHistory,
      onClearHistory: () {
        setState(() {
          _activePodState = _activePodState.copyWith(gameHistory: const []);
        });
      },
    );
    if (mounted) {
      _handleUserActivity();
    }
  }

  void _handleOpenMana(BuildContext context) async {
    if (_activePodState.players.isEmpty) return;
    final activePlayer = _activePodState.players.first;
    _autohideTimer?.cancel();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final currentPlayer = _activePodState.players.firstWhere(
            (p) => p.id == activePlayer.id,
            orElse: () => activePlayer,
          );
          return FloatingManaDrawerWidget(
            player: currentPlayer,
            onManaDelta: (color, delta) {
              if (widget.onManaDelta != null) {
                widget.onManaDelta!(currentPlayer.id, color, delta);
              } else {
                setState(() {
                  _activePodState = _activePodState.copyWith(
                    players: _activePodState.players.map((p) {
                      if (p.id == currentPlayer.id) {
                        final cur = p.floatingMana[color] ?? 0;
                        final updatedMap = Map<String, int>.from(p.floatingMana);
                        updatedMap[color] = (cur + delta).clamp(0, 999);
                        return p.copyWith(floatingMana: updatedMap);
                      }
                      return p;
                    }).toList(),
                  );
                });
              }
              setSheetState(() {});
            },
            onStormDelta: (delta) {
              if (widget.onStormDelta != null) {
                widget.onStormDelta!(currentPlayer.id, delta);
              } else {
                setState(() {
                  _activePodState = _activePodState.copyWith(
                    players: _activePodState.players.map((p) {
                      if (p.id == currentPlayer.id) {
                        return p.copyWith(
                          stormCount: math.max(0, p.stormCount + delta),
                        );
                      }
                      return p;
                    }).toList(),
                  );
                });
              }
              setSheetState(() {});
            },
            onManaClear: () {
              if (widget.onManaClear != null) {
                widget.onManaClear!(currentPlayer.id);
              } else {
                setState(() {
                  _activePodState = _activePodState.copyWith(
                    players: _activePodState.players.map((p) {
                      if (p.id == currentPlayer.id) {
                        return p.copyWith(
                          floatingMana: const {'W': 0, 'U': 0, 'B': 0, 'R': 0, 'G': 0, 'C': 0},
                          stormCount: 0,
                        );
                      }
                      return p;
                    }).toList(),
                  );
                });
              }
              setSheetState(() {});
            },
          );
        },
      ),
    );
    if (mounted) {
      _handleUserActivity();
    }
  }

  void _handleQuickRandomPlayer(BuildContext context) {
    _handleUserActivity();
    if (_activePodState.players.isEmpty) return;
    final pickedIndex =
        RandomizerService().selectRandomPlayerIndex(_activePodState.players.length);
    _triggerPlayerHighlight(pickedIndex);
  }

  void _handleCenterHubPressed(BuildContext context) async {
    if (widget.onRandomizerPressed != null) {
      widget.onRandomizerPressed!();
      return;
    }

    _autohideTimer?.cancel();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => RandomizerHubModal(
        playerCount: _activePodState.players.length,
        onResetGame: () => _handleResetGame(context),
        onPlayerSelected: (seat) => _triggerPlayerHighlight(seat),
      ),
    );
    if (mounted) {
      _handleUserActivity();
    }
  }
}
