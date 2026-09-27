// Copyright (c) 2026 Countr. All rights reserved.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/cache/countr_cached_image.dart';
import 'package:countr/features/life_counter/domain/models/pod_state.dart';

/// Visual roulette selector (Feature 44) cycling across 2–6 players in the active pod.
///
/// Features:
/// 1. Decelerating cycling animation via [AnimationController] with [Curves.easeOutCubic].
/// 2. Highlights each player seat in succession with light impact haptic feedback on each tick.
/// 3. Final stop on chosen player with celebration/fanfare banner ("Player X Goes First!" / "Chosen Player: Seat N").
/// 4. Provides Key 'roulette_spin_btn' and Key 'chosen_player_banner'.
/// 5. Strictly passive: Neutral player selection without active turn passing or turn timers.
class PlayerRouletteOverlay extends StatefulWidget {
  /// Players in the active pod. If omitted, synthesized seats are generated from [playerCount].
  final List<PodPlayerState>? players;

  /// Total number of seats in the pod (clamped 2..6).
  final int playerCount;

  /// Optional target seat index (0-indexed) for deterministic testing.
  final int? targetSeatIndex;

  /// Optional seat index to exclude (e.g. "Choose Random Opponent" excluding self).
  final int? excludedSeatIndex;

  /// Callback executed when the roulette finishes and a seat is selected.
  final void Function(int pickedSeatIndex)? onPlayerSelected;

  /// Whether to automatically start spinning when mounted.
  final bool autoStart;

  /// Duration of the spin animation. Defaults to 2800ms.
  final Duration spinDuration;

  /// Whether this widget is rendered embedded inside another modal or full-screen overlay.
  final bool isEmbedded;

  const PlayerRouletteOverlay({
    super.key,
    this.players,
    int? playerCount,
    this.targetSeatIndex,
    this.excludedSeatIndex,
    this.onPlayerSelected,
    this.autoStart = false,
    this.spinDuration = const Duration(milliseconds: 2800),
    this.isEmbedded = false,
  }) : playerCount = playerCount ?? (players?.length ?? 4);

  /// Static helper to display the [PlayerRouletteOverlay] as a modal dialog or bottom sheet.
  static Future<int?> show(
    BuildContext context, {
    List<PodPlayerState>? players,
    int? playerCount,
    int? targetSeatIndex,
    int? excludedSeatIndex,
    void Function(int pickedSeatIndex)? onPlayerSelected,
    bool autoStart = true,
    Duration spinDuration = const Duration(milliseconds: 2800),
  }) {
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Color(0xFF141820),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: PlayerRouletteOverlay(
          players: players,
          playerCount: playerCount,
          targetSeatIndex: targetSeatIndex,
          excludedSeatIndex: excludedSeatIndex,
          onPlayerSelected: (seat) {
            onPlayerSelected?.call(seat);
            Navigator.of(ctx).pop(seat);
          },
          autoStart: autoStart,
          spinDuration: spinDuration,
        ),
      ),
    );
  }

  @override
  State<PlayerRouletteOverlay> createState() => _PlayerRouletteOverlayState();
}

class _PlayerRouletteOverlayState extends State<PlayerRouletteOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _curveAnimation;

  int get _effectivePlayerCount => widget.playerCount.clamp(2, 6);
  late List<int> _eligibleSeats;
  late final math.Random _random;

  int _currentHighlightedSeat = 0;
  int _lastTickSeat = -1;
  int? _finalChosenSeat;
  bool _isSpinning = false;
  bool _hasCompleted = false;

  int _targetSeat = 0;
  int _totalStepCount = 0;

  void _initEligibleSeats() {
    _eligibleSeats = List<int>.generate(_effectivePlayerCount, (i) => i)
      ..removeWhere((seat) => seat == widget.excludedSeatIndex);

    if (_eligibleSeats.isEmpty) {
      _eligibleSeats.add(0);
    }
  }

  @override
  void initState() {
    super.initState();
    _random = math.Random();
    _initEligibleSeats();

    _animController = AnimationController(
      vsync: this,
      duration: widget.spinDuration,
    );

    _curveAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );

    _animController.addListener(_onAnimationTick);
    _animController.addStatusListener(_onAnimationStatus);

    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startSpin();
      });
    }
  }

  @override
  void didUpdateWidget(PlayerRouletteOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playerCount != widget.playerCount ||
        oldWidget.excludedSeatIndex != widget.excludedSeatIndex) {
      _initEligibleSeats();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _startSpin() {
    if (_isSpinning) return;

    final target = widget.targetSeatIndex != null &&
            _eligibleSeats.contains(widget.targetSeatIndex)
        ? widget.targetSeatIndex!
        : _eligibleSeats[_random.nextInt(_eligibleSeats.length)];

    setState(() {
      _isSpinning = true;
      _hasCompleted = false;
      _finalChosenSeat = null;
      _targetSeat = target;

      // Base 5 full revolutions + target offset
      const baseRevolutions = 5;
      final targetOffsetInEligible = _eligibleSeats.indexOf(target);
      _totalStepCount = (baseRevolutions * _eligibleSeats.length) + targetOffsetInEligible;
    });

    _animController.reset();
    _animController.forward();
  }

  void _onAnimationTick() {
    if (!_isSpinning) return;

    final progress = _curveAnimation.value;
    final currentStep = (progress * _totalStepCount).floor();
    final seatIndex = _eligibleSeats[currentStep % _eligibleSeats.length];

    if (seatIndex != _lastTickSeat) {
      _lastTickSeat = seatIndex;
      HapticFeedback.lightImpact();
      setState(() {
        _currentHighlightedSeat = seatIndex;
      });
    }
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      HapticFeedback.mediumImpact();
      setState(() {
        _isSpinning = false;
        _hasCompleted = true;
        _currentHighlightedSeat = _targetSeat;
        _finalChosenSeat = _targetSeat;
      });

      widget.onPlayerSelected?.call(_targetSeat);
    }
  }

  String _getPlayerName(int seatIndex) {
    if (widget.players != null && seatIndex < widget.players!.length) {
      return widget.players![seatIndex].name;
    }
    return 'Player ${seatIndex + 1}';
  }

  String? _getCommanderArt(int seatIndex) {
    if (widget.players != null && seatIndex < widget.players!.length) {
      return widget.players![seatIndex].commanderArtCropUrl;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('player_roulette_overlay'),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.stars_rounded, color: AppColors.accentGold, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Player Roulette',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              IconButton(
                key: const Key('roulette_close_btn'),
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Cycling spotlight across active pod seats to determine first turn or neutral target.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 16),

          // Fanfare Banner (Celebration State)
          if (_hasCompleted && _finalChosenSeat != null) ...[
            Container(
              key: const Key('chosen_player_banner'),
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8A5A00), Color(0xFFFF9E40), Color(0xFF8A5A00)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66FF7A00),
                    blurRadius: 16,
                    spreadRadius: 2,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        '${_getPlayerName(_finalChosenSeat!)} Goes First!',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Chosen Player: Seat ${_finalChosenSeat! + 1}',
                    key: const Key('chosen_player_text'),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Seats Grid
          Flexible(
            child: _buildSeatsGrid(),
          ),
          const SizedBox(height: 16),

          // Spin Action Button
          ElevatedButton.icon(
            key: const Key('roulette_spin_btn'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentGold,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
            ),
            icon: Icon(
              _isSpinning ? Icons.hourglass_top_rounded : Icons.casino_rounded,
              color: Colors.black,
            ),
            label: Text(
              _isSpinning
                  ? 'Decelerating...'
                  : _hasCompleted
                      ? 'Spin Again'
                      : 'Spin Roulette',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                letterSpacing: 0.5,
              ),
            ),
            onPressed: _isSpinning ? null : _startSpin,
          ),
        ],
      ),
    );
  }

  Widget _buildSeatsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = _effectivePlayerCount >= 5
            ? 3
            : (_effectivePlayerCount <= 3 ? _effectivePlayerCount : 2);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _effectivePlayerCount,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: _effectivePlayerCount >= 5 ? 1.5 : 1.3,
          ),
          itemBuilder: (context, index) {
            final isHighlighted = index == _currentHighlightedSeat;
            final isTargetWinner = _hasCompleted && index == _finalChosenSeat;
            final isExcluded = index == widget.excludedSeatIndex;
            final name = _getPlayerName(index);
            final artUrl = _getCommanderArt(index);

            return AnimatedContainer(
              key: Key('roulette_seat_card_$index'),
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: isHighlighted
                    ? const Color(0xFF252D3A)
                    : const Color(0xFF141820),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isTargetWinner
                      ? AppColors.accentEmerald
                      : isHighlighted
                          ? AppColors.accentGold
                          : isExcluded
                              ? Colors.white10
                              : Colors.white24,
                  width: isHighlighted || isTargetWinner ? 3.0 : 1.0,
                ),
                boxShadow: isHighlighted || isTargetWinner
                    ? [
                        BoxShadow(
                          color: (isTargetWinner
                                  ? AppColors.accentEmerald
                                  : AppColors.accentGold)
                              .withValues(alpha: 0.45),
                          blurRadius: 14,
                          spreadRadius: 2,
                        ),
                      ]
                    : const [],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  children: [
                    if (artUrl != null && artUrl.isNotEmpty) ...[
                      Positioned.fill(
                        child: Opacity(
                          opacity: isHighlighted ? 0.35 : 0.15,
                          child: CountrCachedImage(
                            imageUrl: artUrl,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ],
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Seat ${index + 1}',
                              style: TextStyle(
                                color: isHighlighted
                                    ? AppColors.accentGold
                                    : AppColors.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isHighlighted
                                    ? Colors.white
                                    : AppColors.textPrimary,
                                fontSize: 13,
                                fontWeight: isHighlighted
                                    ? FontWeight.w900
                                    : FontWeight.w600,
                              ),
                            ),
                            if (isExcluded) ...[
                              const SizedBox(height: 2),
                              const Text(
                                '(Self - Excluded)',
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
