import 'dart:async';
import 'package:flutter/material.dart';

import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/features/decks/domain/models/deck_summary.dart';
import 'package:countr/features/life_counter/domain/models/pod_state.dart';
import '../../domain/services/pod_haptics.dart';
import 'commander_art_backdrop.dart';
import 'commander_spatial_mini_grid.dart';
import 'tool_drawer_or_rail.dart';
import '../dialogs/commander_damage_matrix_dialog.dart';
import '../dialogs/player_status_drawer_sheet.dart';

/// Production widget representing a player's seat in an MTG life counter pod.
///
/// Features:
/// - Lifetap rounded card styling (`BorderRadius.circular(16.0)`, 1.5px border, 4px margins on pitch-black canvas).
/// - Strictly encapsulated 3-tier local coordinate layout:
///   1. Top Tier: Player/Commander Name + spatial Commander Damage Mini-Grid (`cmd_mini_grid_${player.id}`).
///   2. Middle Tier: Split hitboxes (- / +) & Tabular Figures Life Display with transient delta badge.
///   3. Bottom Tier: Centered Settings Gear (`drawer_toggle_${player.id}`) flanked by active counter pills.
/// - Dynamic Commander art crop backdrop with dark vignette gradient (WCAG AAA contrast).
/// - 250ms periodic hold ticker (±5, accelerating to ±10 after 2s) with 1500ms delta debounce history commit.
/// - Responsive secondary trackers: perpetual tool rail on tablets (>=600dp),
///   gesture/tap pull-out drawer on phones (<600dp).
/// - Commander 21+ lethal damage banner alert and toxic 10+ poison lethal banner alert.
/// - Auto-KO overlay with specific defeat reason and 'Ignore / Revive' button.
class PlayerQuadrantWidget extends StatefulWidget {
  final PodPlayerState player;
  final bool isTablet;
  final List<PodPlayerState> opponents;
  final void Function(int delta)? onLifeDelta;
  final void Function({
    required String playerId,
    required int startLife,
    required int endLife,
    required int netDelta,
  })? onCommitLifeHistory;
  final void Function(String opponentId, int delta)? onCommanderDamage;
  final void Function(String color, int delta)? onManaDelta;
  final VoidCallback? onManaClear;
  final void Function(String counterType, int delta)? onCounterDelta;
  final VoidCallback? onClaimMonarch;
  final VoidCallback? onClaimInitiative;
  final VoidCallback? onArtOverride;
  final VoidCallback? onToggleEliminated;
  final VoidCallback? onIgnoreKo;
  final VoidCallback? onOpenSettings;
  final void Function(String name)? onNameChanged;
  final void Function(String color)? onColorChanged;
  final void Function(DeckSummary deck)? onLinkDeck;
  final VoidCallback? onUnlinkDeck;
  final void Function(String opponentId)? onOpenCommanderDamage;

  /// OLED True Black mode toggle (#000000).
  final bool isOledMode;

  /// Colorize commander damage mini-grid cells.
  final bool colorizeCommanderMiniGrids;

  /// Layout density ('Default', 'Name only', 'Big font').
  final String cardDensity;

  /// Whether this player's quadrant is highlighted by randomizer roll.
  final bool isHighlighted;

  const PlayerQuadrantWidget({
    super.key,
    required this.player,
    required this.isTablet,
    required this.opponents,
    this.isOledMode = false,
    this.colorizeCommanderMiniGrids = true,
    this.cardDensity = 'Default',
    this.isHighlighted = false,
    this.onLifeDelta,
    this.onCommitLifeHistory,
    this.onCommanderDamage,
    this.onManaDelta,
    this.onManaClear,
    this.onCounterDelta,
    this.onClaimMonarch,
    this.onClaimInitiative,
    this.onArtOverride,
    this.onToggleEliminated,
    this.onIgnoreKo,
    this.onOpenSettings,
    this.onNameChanged,
    this.onColorChanged,
    this.onLinkDeck,
    this.onUnlinkDeck,
    this.onOpenCommanderDamage,
  });

  @override
  State<PlayerQuadrantWidget> createState() => _PlayerQuadrantWidgetState();
}

class _PlayerQuadrantWidgetState extends State<PlayerQuadrantWidget> {
  int _pendingDelta = 0;
  int? _burstStartLife;
  Timer? _debounceTimer;
  Timer? _holdTickerTimer;
  int _holdElapsedMs = 0;
  bool _isDrawerOpen = false;

  void _applyLifeDelta(int delta) {
    PodHaptics.lightImpact();
    _burstStartLife ??= widget.player.life;
    widget.onLifeDelta?.call(delta);
    setState(() {
      _pendingDelta += delta;
    });
    _resetDebounceTimer();
  }

  void _resetDebounceTimer() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 1500), _commitPendingDelta);
  }

  void _commitPendingDelta() {
    if (_pendingDelta != 0 && _burstStartLife != null) {
      final startLife = _burstStartLife!;
      final netDelta = _pendingDelta;
      final endLife = startLife + netDelta;
      widget.onCommitLifeHistory?.call(
        playerId: widget.player.id,
        startLife: startLife,
        endLife: endLife,
        netDelta: netDelta,
      );
    }
    if (mounted) {
      setState(() {
        _pendingDelta = 0;
        _burstStartLife = null;
      });
    }
  }

  void _startHold(int sign) {
    _holdElapsedMs = 0;
    _applyLifeDelta(sign * 5);
    _holdTickerTimer?.cancel();
    _holdTickerTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) return;
      _holdElapsedMs += 250;
      final tickDelta = _holdElapsedMs >= 2000 ? sign * 10 : sign * 5;
      _applyLifeDelta(tickDelta);
    });
  }

  void _stopHold() {
    _holdTickerTimer?.cancel();
    _holdTickerTimer = null;
    _holdElapsedMs = 0;
  }

  @override
  void dispose() {
    if (_pendingDelta != 0 && _burstStartLife != null) {
      widget.onCommitLifeHistory?.call(
        playerId: widget.player.id,
        startLife: _burstStartLife!,
        endLife: _burstStartLife! + _pendingDelta,
        netDelta: _pendingDelta,
      );
    }
    _debounceTimer?.cancel();
    _holdTickerTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = widget.player;
    final isLethal = player.isLethal;

    return LayoutBuilder(
      builder: (context, constraints) {
        final quadrantHeight = constraints.maxHeight;
        final maxDrawerHeight =
            (quadrantHeight - 56.0).clamp(60.0, double.infinity);

        final Color baseColor = widget.isOledMode
            ? const Color(0xFF000000)
            : const Color(0xFF1E1E2C);

        final Color cardBackground = isLethal
            ? Colors.red.shade900.withValues(alpha: 0.3)
            : baseColor;

        final Border border = widget.isHighlighted
            ? Border.all(color: AppColors.accentGold, width: 3.5)
            : (player.hasAnyLethalCommanderDamage
                ? Border.all(color: Colors.redAccent, width: 3.0)
                : Border.all(
                    color: widget.isOledMode
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.white10,
                    width: 1.5,
                  ));

        final List<BoxShadow>? boxShadow = widget.isHighlighted
            ? [
                BoxShadow(
                  color: AppColors.accentGold.withValues(alpha: 0.6),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ]
            : null;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          // Lifetap-Style Margin, Rounded Corners & 1.5px Border
          margin: const EdgeInsets.all(4.0),
          decoration: BoxDecoration(
            color: cardBackground,
            borderRadius: BorderRadius.circular(16.0),
            border: border,
            boxShadow: boxShadow,
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Dynamic Commander Art Crop Backdrop with dark vignette gradient (Feature 30)
              // Hidden in OLED True Black Mode for maximum battery saving and true black pixels
              if (player.commanderArtCropUrl != null &&
                  player.commanderArtCropUrl!.isNotEmpty &&
                  !widget.isOledMode)
                Positioned.fill(
                  child: CommanderArtBackdrop(
                    imageUrl: player.commanderArtCropUrl,
                    opacity: 0.30,
                  ),
                ),

              // 2. Encapsulated 3-Tier Local Orientation Layout
              Positioned.fill(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top Tier: Name + Commander Damage Mini-Grid
                    if (widget.cardDensity != 'Big font')
                      _buildTopHeader(player),

                    // Middle Tier: Split Hitboxes (- / +) & Tabular Life Display
                    Expanded(
                      child: _buildMiddleLifeStepper(player),
                    ),

                    // Bottom Tier: Settings Gear & Flanking Active Counter Pills
                    _buildBottomBar(player),
                  ],
                ),
              ),

              // 3. 21 Commander Damage Lethal Banner
              if (player.hasAnyLethalCommanderDamage)
                Positioned(
                  top: 36,
                  left: 0,
                  right: 0,
                  child: _buildCommanderLethalBanner(player),
                ),

              // 4. 10 Poison Lethal Alert
              if (player.isPoisonLethal)
                Positioned(
                  top: player.hasAnyLethalCommanderDamage ? 60 : 36,
                  left: 0,
                  right: 0,
                  child: _buildPoisonLethalBanner(player),
                ),

              // 5. Lethal Defeat State Overlay
              if ((player.isEliminated || player.isLethal) && !player.isKoIgnored)
                Positioned.fill(
                  child: _buildEliminatedOverlay(player),
                ),

              // 6. Tool Drawer Overlay for Phones (<600dp)
              if (!widget.isTablet && _isDrawerOpen)
                Positioned(
                  bottom: 44,
                  left: 0,
                  right: 0,
                  child: _buildPhoneDrawerPanel(player, maxDrawerHeight),
                ),
            ],
          ),
        );
      },
    );
  }

  // ===========================================================================
  // Top Tier: Header Bar (Player/Commander Name + Spatial Commander Mini-Grid)
  // ===========================================================================
  Widget _buildTopHeader(PodPlayerState player) {
    final displayName = player.commanderName?.isNotEmpty == true
        ? player.commanderName!
        : player.name;

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.centerLeft,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Player / Commander Name
            GestureDetector(
              onTap: () {
                PlayerStatusDrawerSheet.show(
                  context,
                  player: player,
                  opponents: widget.opponents,
                  onNameChanged: widget.onNameChanged,
                  onColorChanged: widget.onColorChanged,
                  onCounterDelta: widget.onCounterDelta,
                  onClaimMonarch: widget.onClaimMonarch,
                  onClaimInitiative: widget.onClaimInitiative,
                  onLinkDeck: widget.onLinkDeck,
                  onUnlinkDeck: widget.onUnlinkDeck,
                );
              },
              child: Text(
                displayName,
                key: Key('player_name_${player.id}'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
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
            const SizedBox(width: 6),

            // Spatial Commander Damage Mini-Grid
            if (widget.cardDensity == 'Default')
              _buildCommanderMiniGrid(player),

            // Status Badges on Tablets (Monarch and Initiative)
            if (widget.isTablet) ...[
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
          ],
        ),
      ),
    );
  }

  /// Spatial mini-grid showing opponent commander damage.
  Widget _buildCommanderMiniGrid(PodPlayerState player) {
    if (widget.opponents.isEmpty) return const SizedBox.shrink();

    return CommanderSpatialMiniGrid(
      player: player,
      opponents: widget.opponents,
      colorize: widget.colorizeCommanderMiniGrids,
      onOpponentTap: (oppId) {
        if (widget.onCommanderDamage != null) {
          widget.onCommanderDamage!(oppId, 1);
        } else if (widget.onOpenCommanderDamage != null) {
          widget.onOpenCommanderDamage!(oppId);
        } else {
          CommanderDamageMatrixDialog.show(
            context,
            targetPlayer: widget.player,
            opponents: widget.opponents,
            onDamageDelta: (opponentId, delta) {
              widget.onCommanderDamage?.call(opponentId, delta);
            },
          );
        }
      },
      onLongPressSlot: (oppId) {
        if (widget.onOpenCommanderDamage != null) {
          widget.onOpenCommanderDamage!(oppId);
        } else {
          CommanderDamageMatrixDialog.show(
            context,
            targetPlayer: widget.player,
            opponents: widget.opponents,
            onDamageDelta: (opponentId, delta) {
              widget.onCommanderDamage?.call(opponentId, delta);
            },
          );
        }
      },
    );
  }

  // ===========================================================================
  // Middle Tier: Life Stepper & Split Hitboxes
  // ===========================================================================
  Widget _buildMiddleLifeStepper(PodPlayerState player) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Split Hitboxes (- / +) Layer (50/50 split across full quadrant width)
        Row(
          children: [
            // Left Hitbox: Decrement Life (-1)
            Expanded(
              child: GestureDetector(
                key: Key('hitbox_minus_${player.id}'),
                behavior: HitTestBehavior.opaque,
                onTap: () => _applyLifeDelta(-1),
                onLongPressStart: (_) => _startHold(-1),
                onLongPressEnd: (_) => _stopHold(),
                onLongPressCancel: () => _stopHold(),
                child: Container(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: 14),
                  child: const Icon(
                    Icons.remove,
                    color: Colors.white24,
                    size: 28,
                  ),
                ),
              ),
            ),

            // Right Hitbox: Increment Life (+1)
            Expanded(
              child: GestureDetector(
                key: Key('hitbox_plus_${player.id}'),
                behavior: HitTestBehavior.opaque,
                onTap: () => _applyLifeDelta(1),
                onLongPressStart: (_) => _startHold(1),
                onLongPressEnd: (_) => _stopHold(),
                onLongPressCancel: () => _stopHold(),
                child: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 14),
                  child: const Icon(
                    Icons.add,
                    color: Colors.white24,
                    size: 28,
                  ),
                ),
              ),
            ),
          ],
        ),

        // Massive Tabular Figures Life Display & Transient Delta Badge Overlay
        IgnorePointer(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${player.life}',
                      key: Key('life_display_${player.id}'),
                      style: TextStyle(
                        fontSize: widget.cardDensity == 'Big font' ? 84 : 68,
                        fontWeight: FontWeight.bold,
                        color: player.isLethal ? Colors.redAccent : Colors.white,
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

                    // Transient accumulating delta badge
                    if (_pendingDelta != 0)
                      Container(
                        key: Key('delta_badge_${player.id}'),
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: _pendingDelta > 0 ? Colors.green : Colors.red,
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
                          _pendingDelta > 0 ? '+$_pendingDelta' : '$_pendingDelta',
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
      ],
    );
  }

  // ===========================================================================
  // Bottom Tier: Settings Gear & Flanking Active Counter Pills
  // ===========================================================================
  Widget _buildBottomBar(PodPlayerState player) {
    if (widget.isTablet) {
      // Perpetual Tool Rail for Tablets (>= 600dp)
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
      );
    }

    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Left Pills: Monarch, Initiative, Tax
            if (player.isMonarch)
              Padding(
                key: Key('pill_monarch_${player.id}'),
                padding: const EdgeInsets.only(right: 4),
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
                key: Key('pill_initiative_${player.id}'),
                padding: const EdgeInsets.only(right: 4),
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
            if (player.commanderTax > 0)
              Container(
                key: Key('pill_tax_${player.id}'),
                margin: const EdgeInsets.only(right: 4),
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

            // Center: Settings Gear Icon (aliased to drawer_toggle for phone tests)
            KeyedSubtree(
              key: Key('gear_button_${player.id}'),
              child: IconButton(
                key: Key('drawer_toggle_${player.id}'),
                icon: Icon(
                  _isDrawerOpen ? Icons.close : Icons.settings,
                  color: Colors.white70,
                  size: 18,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: () {
                  if (widget.onOpenSettings != null) {
                    widget.onOpenSettings!();
                  } else {
                    setState(() {
                      _isDrawerOpen = !_isDrawerOpen;
                    });
                  }
                },
              ),
            ),

            // Right Pills: Poison, Energy, XP, Rad
            if (player.poison > 0)
              Container(
                key: Key('pill_poison_${player.id}'),
                margin: const EdgeInsets.only(left: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.shade900.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '☠ ${player.poison}',
                  key: Key('val_poison_${player.id}'),
                  style: const TextStyle(fontSize: 10, color: Colors.white),
                ),
              ),
            if (player.energy > 0)
              Container(
                key: Key('pill_energy_${player.id}'),
                margin: const EdgeInsets.only(left: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.shade900.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '⚡ ${player.energy}',
                  key: Key('val_energy_${player.id}'),
                  style: const TextStyle(fontSize: 10, color: Colors.white),
                ),
              ),
            if (player.experience > 0)
              Container(
                key: Key('pill_xp_${player.id}'),
                margin: const EdgeInsets.only(left: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.shade900.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'XP ${player.experience}',
                  key: Key('val_xp_${player.id}'),
                  style: const TextStyle(fontSize: 10, color: Colors.white),
                ),
              ),
            if (player.radCounters > 0)
              Container(
                key: Key('pill_rad_${player.id}'),
                margin: const EdgeInsets.only(left: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.lime.shade900.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '☢ ${player.radCounters}',
                  key: Key('val_rad_${player.id}'),
                  style: const TextStyle(fontSize: 10, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Overlays
  // ===========================================================================
  Widget _buildCommanderLethalBanner(PodPlayerState player) {
    return Container(
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
    );
  }

  Widget _buildPoisonLethalBanner(PodPlayerState player) {
    return Container(
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
    );
  }

  Widget _buildEliminatedOverlay(PodPlayerState player) {
    if (player.isKoIgnored) {
      return const SizedBox.shrink();
    }

    String deathReason;
    if (player.life <= 0) {
      deathReason = 'Knocked Out: ${player.life} Life';
    } else if (player.poison >= 10) {
      deathReason = 'Knocked Out: ${player.poison} Poison';
    } else if (player.hasAnyLethalCommanderDamage) {
      int maxCmd = 0;
      for (final opp in widget.opponents) {
        final dmg = player.maxCommanderDamageFrom(opp.id);
        if (dmg > maxCmd) maxCmd = dmg;
      }
      if (maxCmd < 21) {
        for (final v in player.commanderDamageTaken.values) {
          if (v > maxCmd) maxCmd = v;
        }
      }
      deathReason = 'Knocked Out: $maxCmd Commander Damage';
    } else {
      deathReason = 'Knocked Out: Eliminated';
    }

    return Container(
      color: Colors.black.withValues(alpha: 0.8),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
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
            const SizedBox(height: 4),
            Text(
              deathReason,
              key: Key('death_reason_${player.id}'),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              key: Key('btn_ignore_revive_${player.id}'),
              onPressed: () {
                if (widget.onIgnoreKo != null) {
                  widget.onIgnoreKo!();
                } else if (widget.onToggleEliminated != null) {
                  widget.onToggleEliminated!();
                }
              },
              icon: const Icon(Icons.undo, size: 14, color: Colors.white70),
              label: const Text(
                'Ignore / Revive',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneDrawerPanel(PodPlayerState player, double maxDrawerHeight) {
    return Container(
      key: Key('drawer_panel_${player.id}'),
      constraints: BoxConstraints(maxHeight: maxDrawerHeight),
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
    );
  }
}
