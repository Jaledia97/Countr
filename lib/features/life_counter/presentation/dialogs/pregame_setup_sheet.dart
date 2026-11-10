// Copyright (c) 2026 Countr. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:countr/core/cache/countr_cached_image.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/features/decks/domain/models/deck_summary.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/life_counter/domain/models/pod_state.dart';
import '../../domain/services/pod_haptics.dart';
import 'art_override_sheet.dart';

/// Per-seat internal configuration state inside the setup sheet.
class _PlayerSetupEntry {
  final String id;
  final TextEditingController nameController;
  DeckSummary? deck;
  String? commanderCardId;
  String? commanderName;
  String? artCropUrl;
  String? colorTheme;

  _PlayerSetupEntry({
    required this.id,
    required this.nameController,
    this.commanderCardId,
    this.commanderName,
    this.artCropUrl,
    this.colorTheme,
  });

  void dispose() {
    nameController.dispose();
  }
}

/// Riverpod state providers for Match Setup Preferences.
final podSeatingOrientationProvider = StateProvider<String>((ref) => 'opposed');
final podLayoutVariantProvider = StateProvider<String>((ref) => 'opposed');
final podCameraModeProvider = StateProvider<bool>((ref) => false);
final podOledModeProvider = StateProvider<bool>((ref) => false);
final podImmersiveModeProvider = StateProvider<bool>((ref) => false);
final podLayoutDensityProvider = StateProvider<String>((ref) => 'Default');
final podAutohideMenuProvider = StateProvider<bool>((ref) => true);
final podWakelockProvider = StateProvider<bool>((ref) => true);
final podHapticsProvider = StateProvider<bool>((ref) => true);

/// Visual miniature layout preview widget showing physical table layout
/// and directional seating arrows for each player slot.
class MiniatureLayoutIcon extends StatelessWidget {
  final int playerCount;
  final String variant; // 'A', 'B', 'opposed', 'standard', 'radial'
  final bool isSelected;

  const MiniatureLayoutIcon({
    super.key,
    required this.playerCount,
    required this.variant,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 32,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1218),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isSelected ? AppColors.accentGold : Colors.white24,
          width: 1,
        ),
      ),
      child: _buildMiniSlots(context),
    );
  }

  Widget _buildSlot({required String direction, double flex = 1.0}) {
    IconData icon;
    switch (direction) {
      case 'up':
        icon = Icons.keyboard_arrow_up_rounded;
        break;
      case 'down':
        icon = Icons.keyboard_arrow_down_rounded;
        break;
      case 'left':
        icon = Icons.keyboard_arrow_left_rounded;
        break;
      case 'right':
        icon = Icons.keyboard_arrow_right_rounded;
        break;
      default:
        icon = Icons.crop_square_rounded;
        break;
    }

    return Expanded(
      flex: (flex * 10).round(),
      child: Container(
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentGold.withValues(alpha: 0.25) : Colors.white12,
          borderRadius: BorderRadius.circular(2),
          border: Border.all(
            color: isSelected ? AppColors.accentGold : Colors.white24,
            width: 0.5,
          ),
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 10,
          color: isSelected ? AppColors.accentGold : Colors.white70,
        ),
      ),
    );
  }

  Widget _buildMiniSlots(BuildContext context) {
    final isVarB = variant == 'B' || variant == 'standard';

    if (playerCount <= 1) {
      return Column(
        children: [
          _buildSlot(direction: 'down'),
        ],
      );
    }

    if (playerCount == 2) {
      if (!isVarB) {
        // Layout A: Face-to-Face (Top 2, Bottom 0)
        return Column(
          children: [
            _buildSlot(direction: 'up'),
            _buildSlot(direction: 'down'),
          ],
        );
      } else {
        // Layout B: Side-by-Side (Left 1, Right 3)
        return Row(
          children: [
            _buildSlot(direction: 'left'),
            _buildSlot(direction: 'right'),
          ],
        );
      }
    }

    if (playerCount == 3) {
      if (!isVarB) {
        // Layout A: Top 1 & 3, Bottom 0
        return Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  _buildSlot(direction: 'left'),
                  _buildSlot(direction: 'right'),
                ],
              ),
            ),
            _buildSlot(direction: 'down'),
          ],
        );
      } else {
        // Layout B: Top 2, Bottom 0 & 0
        return Column(
          children: [
            _buildSlot(direction: 'up'),
            Expanded(
              child: Row(
                children: [
                  _buildSlot(direction: 'down'),
                  _buildSlot(direction: 'down'),
                ],
              ),
            ),
          ],
        );
      }
    }

    if (playerCount == 4) {
      if (variant == 'radial') {
        return const Center(
          child: Icon(Icons.rotate_right_rounded, size: 16, color: Colors.white70),
        );
      }
      if (!isVarB) {
        // Layout A: 2x2 Grid Side Seating (Left 1, Right 3)
        return Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  _buildSlot(direction: 'left'),
                  _buildSlot(direction: 'right'),
                ],
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  _buildSlot(direction: 'left'),
                  _buildSlot(direction: 'right'),
                ],
              ),
            ),
          ],
        );
      } else {
        // Layout B: Head-of-Table (Top 2, Middle 1 & 3, Bottom 0)
        return Column(
          children: [
            _buildSlot(direction: 'up'),
            Expanded(
              child: Row(
                children: [
                  _buildSlot(direction: 'left'),
                  _buildSlot(direction: 'right'),
                ],
              ),
            ),
            _buildSlot(direction: 'down'),
          ],
        );
      }
    }

    if (playerCount == 5) {
      if (!isVarB) {
        // Layout A: Grid (Top 1 & 3, Mid 1 & 3, Bottom 0)
        return Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  _buildSlot(direction: 'left'),
                  _buildSlot(direction: 'right'),
                ],
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  _buildSlot(direction: 'left'),
                  _buildSlot(direction: 'right'),
                ],
              ),
            ),
            _buildSlot(direction: 'down'),
          ],
        );
      } else {
        // Layout B: Opposed (Top 2 & 2, Bottom 0, 0, 0)
        return Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  _buildSlot(direction: 'up'),
                  _buildSlot(direction: 'up'),
                ],
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  _buildSlot(direction: 'down'),
                  _buildSlot(direction: 'down'),
                  _buildSlot(direction: 'down'),
                ],
              ),
            ),
          ],
        );
      }
    }

    // 6P
    if (!isVarB) {
      // Layout A: 2x3 Side Grid (Left 1, Right 3 across 3 rows)
      return Column(
        children: [
          Expanded(
            child: Row(
              children: [
                _buildSlot(direction: 'left'),
                _buildSlot(direction: 'right'),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                _buildSlot(direction: 'left'),
                _buildSlot(direction: 'right'),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                _buildSlot(direction: 'left'),
                _buildSlot(direction: 'right'),
              ],
            ),
          ),
        ],
      );
    } else {
      // Layout B: Head-of-Table (Top 2, Middle 2x2 1 & 3, Bottom 0)
      return Column(
        children: [
          _buildSlot(direction: 'up'),
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      _buildSlot(direction: 'left'),
                      _buildSlot(direction: 'right'),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      _buildSlot(direction: 'left'),
                      _buildSlot(direction: 'right'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _buildSlot(direction: 'down'),
        ],
      );
    }
  }
}

/// Pre-game Deck Selection & Pod Setup Modal Bottom Sheet (Feature 29).
///
/// Features:
/// - Links players to saved MTG decks from `VaultDao` via [deckSummariesProvider].
/// - When a deck is selected, automatically populates:
///   1. Player name (auto-populates to deck name if unedited or default).
///   2. Commander card ID and commander name.
///   3. Commander `art_crop` URL for dynamic backdrop rendering.
///   4. Recommended starting life preset based on format (40 for Commander, 20 for Standard, 30 for Brawl).
/// - Dynamic player count selection (1-player Solo, 2-player 1v1, 3P, 4P 2x2, 5P, 6P 2x3).
/// - Pod table seating orientation picker with visual miniature layout icons.
/// - Format selector (Commander, Standard, Brawl, Draft, Custom).
/// - Starting life slider with format snap points (20, 30, 40) + stepper.
/// - OLED True Black (#000000), Camera Mode & Immersive gameplay modes.
/// - Full decoupling for testing: accepts optional [injectedDecks] and [onStartMatch] callback.
/// - Produces a validated [PodState] ready for instant match initialization.
class PregameSetupSheet extends ConsumerStatefulWidget {
  /// Initial number of players (defaults to 4, clamped between 1 and 6).
  final int initialPlayerCount;

  /// Initial format (defaults to 'commander').
  final String initialFormat;

  /// Initial starting life (defaults to format standard: 40 for commander, 20 for standard).
  final int? initialStartingLife;

  /// Optional pre-configured players list.
  final List<PlayerSetupConfig>? initialPlayers;

  /// Optional injected decks for headless testing without SQLite.
  final List<DeckSummary>? injectedDecks;

  /// Callback executed when the match setup is finalized.
  final void Function(PodState podState)? onStartMatch;

  /// Optional active TCG context (e.g. 'Magic: The Gathering', 'Pokémon', 'Disney Lorcana').
  final String? initialTcg;

  /// Table seating orientation ('opposed', 'standard', 'radial').
  final String initialSeatingOrientation;

  /// Layout variant ('A' or 'B').
  final String initialLayoutVariant;

  /// Camera mode toggle (all cards upright 0°).
  final bool initialCameraMode;

  /// OLED True Black mode toggle.
  final bool initialOledMode;

  /// Immersive full-screen gameplay mode toggle.
  final bool initialImmersiveMode;

  /// Card layout density ('Default', 'Name only', 'Big font').
  final String initialCardDensity;

  /// Whether a match is already ongoing in the pod.
  final bool isGameInProgress;

  /// Existing pod state before opening settings mid-game.
  final PodState? existingPodState;

  /// Auto-hide menu toggle.
  final bool initialAutohideMenu;

  /// Keep display awake toggle.
  final bool initialWakelock;

  /// Haptic feedback toggle.
  final bool initialHaptics;

  /// Static trackers preserving user match setup preferences across navigation.
  static String lastSeatingOrientation = 'opposed';
  static String lastLayoutVariant = 'opposed';
  static bool lastCameraMode = false;
  static bool lastOledMode = false;
  static bool lastImmersiveMode = false;
  static String lastCardDensity = 'Default';
  static bool lastAutohideMenu = true;
  static bool lastWakelock = true;
  static bool lastHaptics = true;
  static String? lastTcg;

  const PregameSetupSheet({
    super.key,
    this.initialPlayerCount = 4,
    this.initialFormat = 'commander',
    this.initialStartingLife,
    this.initialPlayers,
    this.injectedDecks,
    this.onStartMatch,
    this.initialTcg,
    this.initialSeatingOrientation = 'opposed',
    this.initialLayoutVariant = 'opposed',
    this.initialCameraMode = false,
    this.initialOledMode = false,
    this.initialImmersiveMode = false,
    this.initialCardDensity = 'Default',
    this.isGameInProgress = false,
    this.existingPodState,
    this.initialAutohideMenu = true,
    this.initialWakelock = true,
    this.initialHaptics = true,
  });

  /// Static helper to display the [PregameSetupSheet] bottom modal.
  static Future<PodState?> show(
    BuildContext context, {
    int initialPlayerCount = 4,
    String initialFormat = 'commander',
    int? initialStartingLife,
    List<PlayerSetupConfig>? initialPlayers,
    List<DeckSummary>? injectedDecks,
    void Function(PodState podState)? onStartMatch,
    String? initialTcg,
    String initialSeatingOrientation = 'opposed',
    String initialLayoutVariant = 'opposed',
    bool initialCameraMode = false,
    bool initialOledMode = false,
    bool initialImmersiveMode = false,
    String initialCardDensity = 'Default',
    bool isGameInProgress = false,
    PodState? existingPodState,
    bool initialAutohideMenu = true,
    bool initialWakelock = true,
    bool initialHaptics = true,
  }) {
    return showModalBottomSheet<PodState>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PregameSetupSheet(
        initialPlayerCount: initialPlayerCount,
        initialFormat: initialFormat,
        initialStartingLife: initialStartingLife,
        initialPlayers: initialPlayers,
        injectedDecks: injectedDecks,
        onStartMatch: onStartMatch,
        initialTcg: initialTcg,
        initialSeatingOrientation: initialSeatingOrientation,
        initialLayoutVariant: initialLayoutVariant,
        initialCameraMode: initialCameraMode,
        initialOledMode: initialOledMode,
        initialImmersiveMode: initialImmersiveMode,
        initialCardDensity: initialCardDensity,
        isGameInProgress: isGameInProgress,
        existingPodState: existingPodState,
        initialAutohideMenu: initialAutohideMenu,
        initialWakelock: initialWakelock,
        initialHaptics: initialHaptics,
      ),
    );
  }

  @override
  ConsumerState<PregameSetupSheet> createState() => _PregameSetupSheetState();
}

enum _ResetTrigger { playerCount, startingLife }

class _PregameSetupSheetState extends ConsumerState<PregameSetupSheet> {
  late int _playerCount;
  late String _format;
  late int _startingLife;
  late String _seatingOrientation;
  late String _layoutVariant;
  late bool _isCameraMode;
  late bool _isOledMode;
  late bool _isImmersiveMode;
  late String _cardDensity;
  late bool _isAutohideMenu;
  late bool _isWakelock;
  late bool _isHaptics;
  String? _tcg;
  final List<_PlayerSetupEntry> _players = [];
  bool _isCreatingSession = false;

  // R4.1 Reset safeguard state
  late bool _isGameInProgress;
  late int _originalPlayerCount;
  late int _originalStartingLife;
  late String _originalFormat;
  bool _showResetWarning = false;
  _ResetTrigger? _pendingResetTrigger;
  int? _pendingPlayerCount;
  int? _pendingStartingLife;
  String? _pendingFormat;
  bool _hasConfirmedReset = false;

  static const List<int> _playerCounts = [1, 2, 3, 4, 5, 6];

  static const Map<String, int> _formatStartingLife = {
    'commander': 40,
    'standard': 20,
    'brawl': 30,
    'draft': 20,
    'custom': 40,
  };

  @override
  void initState() {
    super.initState();
    _playerCount = widget.initialPlayerCount.clamp(1, 6);
    _tcg = widget.initialTcg;
    _seatingOrientation = widget.initialSeatingOrientation;
    _layoutVariant = widget.initialLayoutVariant;
    _isCameraMode = widget.initialCameraMode;
    _isOledMode = widget.initialOledMode;
    _isImmersiveMode = widget.initialImmersiveMode;
    _cardDensity = widget.initialCardDensity;
    _isAutohideMenu = widget.initialAutohideMenu;
    _isWakelock = widget.initialWakelock;
    _isHaptics = widget.initialHaptics;

    _format = widget.initialFormat.toLowerCase();
    _startingLife = widget.initialStartingLife ??
        (_formatStartingLife[_format] ?? 40);

    _isGameInProgress = widget.isGameInProgress ||
        (widget.existingPodState?.isGameInProgress ?? false);
    _originalPlayerCount = _playerCount;
    _originalStartingLife = _startingLife;
    _originalFormat = _format;

    PregameSetupSheet.lastSeatingOrientation = _seatingOrientation;
    PregameSetupSheet.lastLayoutVariant = _layoutVariant;
    PregameSetupSheet.lastCameraMode = _isCameraMode;
    PregameSetupSheet.lastOledMode = _isOledMode;
    PregameSetupSheet.lastImmersiveMode = _isImmersiveMode;
    PregameSetupSheet.lastCardDensity = _cardDensity;
    PregameSetupSheet.lastAutohideMenu = _isAutohideMenu;
    PregameSetupSheet.lastWakelock = _isWakelock;
    PregameSetupSheet.lastHaptics = _isHaptics;
    if (_tcg != null) {
      PregameSetupSheet.lastTcg = _tcg;
    }

    _initializePlayers();
  }

  void _initializePlayers() {
    _players.clear();
    final preConfig = widget.initialPlayers ?? const [];

    for (var i = 0; i < _playerCount; i++) {
      final config = i < preConfig.length ? preConfig[i] : null;
      final defaultName = 'Player ${i + 1}';
      final name = config?.name ?? defaultName;

      _players.add(
        _PlayerSetupEntry(
          id: config?.id ?? const Uuid().v4(),
          nameController: TextEditingController(text: name),
          commanderCardId: config?.commanderCardId,
          commanderName: config?.commanderName,
          artCropUrl: config?.artCropUrl,
          colorTheme: config?.colorTheme,
        ),
      );
    }
  }

  @override
  void dispose() {
    for (final p in _players) {
      p.dispose();
    }
    super.dispose();
  }

  void _setPlayerCount(int count) {
    if (_isGameInProgress && !_hasConfirmedReset) {
      if (count == _originalPlayerCount) {
        setState(() {
          _pendingPlayerCount = null;
          if (_pendingStartingLife == null) {
            _showResetWarning = false;
            _pendingResetTrigger = null;
          }
        });
        return;
      }
      setState(() {
        _pendingPlayerCount = count;
        _pendingResetTrigger = _ResetTrigger.playerCount;
        _showResetWarning = true;
      });
      return;
    }
    _applyPlayerCountChange(count);
  }

  void _applyPlayerCountChange(int count) {
    if (count == _playerCount) return;
    setState(() {
      if (count > _playerCount) {
        // Add additional seats
        for (var i = _playerCount; i < count; i++) {
          _players.add(
            _PlayerSetupEntry(
              id: const Uuid().v4(),
              nameController: TextEditingController(text: 'Player ${i + 1}'),
            ),
          );
        }
      } else {
        // Remove excess seats
        while (_players.length > count) {
          final removed = _players.removeLast();
          removed.dispose();
        }
      }
      if (count != 4 && _seatingOrientation == 'radial') {
        _seatingOrientation = 'opposed';
        _layoutVariant = 'A';
        PregameSetupSheet.lastSeatingOrientation = _seatingOrientation;
        PregameSetupSheet.lastLayoutVariant = _layoutVariant;
      }
      _playerCount = count;
    });
  }

  void _setFormat(String newFormat) {
    final targetLife = _formatStartingLife[newFormat] ?? _startingLife;
    if (_isGameInProgress && !_hasConfirmedReset) {
      if (targetLife == _originalStartingLife && newFormat == _originalFormat) {
        setState(() {
          _pendingStartingLife = null;
          _pendingFormat = null;
          if (_pendingPlayerCount == null) {
            _showResetWarning = false;
            _pendingResetTrigger = null;
          }
        });
        return;
      }
      setState(() {
        _pendingFormat = newFormat;
        _pendingStartingLife = targetLife;
        _pendingResetTrigger = _ResetTrigger.startingLife;
        _showResetWarning = true;
      });
      return;
    }
    setState(() {
      _format = newFormat;
      _startingLife = targetLife;
    });
  }

  void _setStartingLife(int life) {
    if (_isGameInProgress && !_hasConfirmedReset) {
      if (life == _originalStartingLife) {
        setState(() {
          _pendingStartingLife = null;
          if (_pendingPlayerCount == null) {
            _showResetWarning = false;
            _pendingResetTrigger = null;
          }
        });
        return;
      }
      setState(() {
        _pendingStartingLife = life;
        _pendingResetTrigger = _ResetTrigger.startingLife;
        _showResetWarning = true;
      });
      return;
    }
    setState(() {
      _startingLife = life;
    });
  }

  void _handleCancelReset() {
    setState(() {
      _pendingPlayerCount = null;
      _pendingStartingLife = null;
      _pendingFormat = null;
      _showResetWarning = false;
      _pendingResetTrigger = null;
    });
  }

  void _handleConfirmReset() {
    setState(() {
      if (_pendingPlayerCount != null) {
        _applyPlayerCountChange(_pendingPlayerCount!);
        _originalPlayerCount = _playerCount;
      }
      if (_pendingStartingLife != null) {
        _startingLife = _pendingStartingLife!;
        _originalStartingLife = _startingLife;
        if (_pendingFormat != null) {
          _format = _pendingFormat!;
          _originalFormat = _format;
        }
      }
      _pendingPlayerCount = null;
      _pendingStartingLife = null;
      _pendingFormat = null;
      _showResetWarning = false;
      _pendingResetTrigger = null;
      _hasConfirmedReset = true;
      _isGameInProgress = false;
    });
  }

  Widget _buildResetWarningBox() {
    return Container(
      key: const Key('pregame_reset_warning_box'),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF261A14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFE5A93C).withValues(alpha: 0.8),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFE5A93C),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Warning: this will reset the current game',
                      style: TextStyle(
                        color: Color(0xFFE5A93C),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Changing player count or starting life will reset the current game.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                key: const Key('pregame_reset_cancel_button'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                onPressed: _handleCancelReset,
                child: const Text('Cancel', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                key: const Key('pregame_reset_confirm_button'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE5A93C),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                onPressed: _handleConfirmReset,
                child: const Text('Confirm', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Assigns a saved MTG deck to a specific player seat and auto-populates all metadata.
  void _assignDeckToPlayer(int seatIndex, DeckSummary deck) {
    final entry = _players[seatIndex];
    final defaultName = 'Player ${seatIndex + 1}';

    setState(() {
      entry.deck = deck;

      // 1. Auto-populate player name if empty, default, or previously matched deck name
      if (entry.nameController.text.trim().isEmpty ||
          entry.nameController.text == defaultName ||
          (entry.commanderName != null &&
              entry.nameController.text == entry.commanderName)) {
        entry.nameController.text = deck.name;
      }

      // 2. Auto-populate Commander card ID & Commander name
      entry.commanderCardId = deck.commanderCardId;
      entry.commanderName = deck.commanderName;

      // 3. Auto-populate Commander art_crop URL
      entry.artCropUrl = deck.commanderArtCrop ?? deck.commanderImageUrl;

      // 4. Color identity
      if (deck.colorIdentity.isNotEmpty) {
        entry.colorTheme = deck.colorIdentity.join();
      }

      // 5. Format & starting life recommendation
      final deckFmt = deck.format.toLowerCase();
      if (deckFmt.contains('commander') || deckFmt.contains('edh')) {
        if (_format != 'commander') {
          _format = 'commander';
          _startingLife = 40;
        }
      } else if (deckFmt.contains('standard') ||
          deckFmt.contains('modern') ||
          deckFmt.contains('pioneer')) {
        if (_format == 'commander') {
          _format = 'standard';
          _startingLife = 20;
        }
      } else if (deckFmt.contains('brawl')) {
        if (_format != 'brawl') {
          _format = 'brawl';
          _startingLife = 30;
        }
      }
    });
  }

  /// Clears deck assignment for a seat.
  void _clearPlayerDeck(int seatIndex) {
    final entry = _players[seatIndex];
    setState(() {
      if (entry.nameController.text == entry.deck?.name ||
          entry.nameController.text == entry.commanderName) {
        entry.nameController.text = 'Player ${seatIndex + 1}';
      }
      entry.deck = null;
      entry.commanderCardId = null;
      entry.commanderName = null;
      entry.artCropUrl = null;
      entry.colorTheme = null;
    });
  }

  /// Opens the modal deck selector bottom sheet.
  void _openDeckPicker(int seatIndex) {
    final availableDecks = widget.injectedDecks;

    showModalBottomSheet<DeckSummary>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (pickerCtx) {
        return _SavedDecksPickerSheet(
          injectedDecks: availableDecks,
          onDeckSelected: (deck) {
            Navigator.of(pickerCtx).pop(deck);
          },
        );
      },
    ).then((selectedDeck) {
      if (selectedDeck != null) {
        _assignDeckToPlayer(seatIndex, selectedDeck);
      }
    });
  }

  /// Opens the art override sheet for a specific player seat.
  void _openArtOverride(int seatIndex) {
    final entry = _players[seatIndex];
    ArtOverrideSheet.show(
      context,
      playerId: entry.id,
      playerName: entry.nameController.text.trim().isNotEmpty
          ? entry.nameController.text.trim()
          : 'Player ${seatIndex + 1}',
      currentArtUrl: entry.artCropUrl,
      initialCommanderName: entry.commanderName,
      onArtSelected: (newArtUrl, cardName) {
        setState(() {
          entry.artCropUrl = newArtUrl;
          if (cardName != null && cardName.isNotEmpty) {
            entry.commanderName = cardName;
          }
        });
      },
      onResetDefault: () {
        setState(() {
          entry.artCropUrl = entry.deck?.commanderArtCrop ?? entry.deck?.commanderImageUrl;
          entry.commanderName = entry.deck?.commanderName;
        });
      },
    );
  }

  /// Builds the configured [PodState] and initializes the match.
  Future<void> _startMatch() async {
    if (_isCreatingSession) return;
    setState(() => _isCreatingSession = true);

    final podPlayers = <PodPlayerState>[];
    final existingPod = widget.existingPodState;
    final preserveOngoingMatch =
        _isGameInProgress && !_hasConfirmedReset && existingPod != null;

    for (var i = 0; i < _players.length; i++) {
      final p = _players[i];
      final name = p.nameController.text.trim().isNotEmpty
          ? p.nameController.text.trim()
          : 'Player ${i + 1}';

      final existingPlayer =
          (preserveOngoingMatch && i < existingPod.players.length)
              ? existingPod.players[i]
              : null;

      if (existingPlayer != null) {
        podPlayers.add(
          PodPlayerState(
            id: p.id,
            seatIndex: i,
            name: name,
            deckId: p.deck?.id ?? existingPlayer.deckId,
            commanderCardId:
                p.commanderCardId ?? existingPlayer.commanderCardId,
            commanderName: p.commanderName ?? existingPlayer.commanderName,
            commanderArtCropUrl:
                p.artCropUrl ?? existingPlayer.commanderArtCropUrl,
            colorTheme: p.colorTheme ?? existingPlayer.colorTheme,
            life: existingPlayer.life,
            poison: existingPlayer.poison,
            energy: existingPlayer.energy,
            experience: existingPlayer.experience,
            commanderTax: existingPlayer.commanderTax,
            radCounters: existingPlayer.radCounters,
            isMonarch: existingPlayer.isMonarch,
            hasInitiative: existingPlayer.hasInitiative,
            commanderDamageTaken: existingPlayer.commanderDamageTaken,
            floatingMana: existingPlayer.floatingMana,
            stormCount: existingPlayer.stormCount,
            isEliminated: existingPlayer.isEliminated,
            isKoIgnored: existingPlayer.isKoIgnored,
            isLocalDevice: existingPlayer.isLocalDevice,
            peerDeviceId: existingPlayer.peerDeviceId,
          ),
        );
      } else {
        podPlayers.add(
          PodPlayerState(
            id: p.id,
            seatIndex: i,
            name: name,
            deckId: p.deck?.id,
            commanderCardId: p.commanderCardId,
            commanderName: p.commanderName,
            commanderArtCropUrl: p.artCropUrl,
            colorTheme: p.colorTheme,
            life: _startingLife,
          ),
        );
      }
    }

    final podState = PodState(
      sessionId:
          preserveOngoingMatch ? existingPod.sessionId : const Uuid().v4(),
      format: _format,
      startingLife: _startingLife,
      players: podPlayers,
      isDay: preserveOngoingMatch ? existingPod.isDay : true,
      isP2pHost: preserveOngoingMatch ? existingPod.isP2pHost : true,
      sequenceNumber: preserveOngoingMatch ? existingPod.sequenceNumber : 0,
      gameHistory: preserveOngoingMatch ? existingPod.gameHistory : const [],
      commanderDamageLifeLoss:
          preserveOngoingMatch ? existingPod.commanderDamageLifeLoss : true,
      colorizeCommanderMiniGrids:
          preserveOngoingMatch ? existingPod.colorizeCommanderMiniGrids : true,
      autoKo: preserveOngoingMatch ? existingPod.autoKo : true,
      cardDensity: _cardDensity,
    );

    // Persist setup preferences to static trackers and Riverpod providers
    PregameSetupSheet.lastSeatingOrientation = _seatingOrientation;
    PregameSetupSheet.lastLayoutVariant = _layoutVariant;
    PregameSetupSheet.lastCameraMode = _isCameraMode;
    PregameSetupSheet.lastOledMode = _isOledMode;
    PregameSetupSheet.lastImmersiveMode = _isImmersiveMode;
    PregameSetupSheet.lastCardDensity = _cardDensity;
    PregameSetupSheet.lastAutohideMenu = _isAutohideMenu;
    PregameSetupSheet.lastWakelock = _isWakelock;
    PregameSetupSheet.lastHaptics = _isHaptics;
    PregameSetupSheet.lastTcg = _tcg;

    try {
      ref.read(podSeatingOrientationProvider.notifier).state =
          _seatingOrientation;
      ref.read(podLayoutVariantProvider.notifier).state = _layoutVariant;
      ref.read(podCameraModeProvider.notifier).state = _isCameraMode;
      ref.read(podOledModeProvider.notifier).state = _isOledMode;
      ref.read(podImmersiveModeProvider.notifier).state = _isImmersiveMode;
      ref.read(podLayoutDensityProvider.notifier).state = _cardDensity;
      ref.read(podAutohideMenuProvider.notifier).state = _isAutohideMenu;
      ref.read(podWakelockProvider.notifier).state = _isWakelock;
      ref.read(podHapticsProvider.notifier).state = _isHaptics;
    } catch (_) {}

    try {
      // 1. If parent provided an onStartMatch hook, call it
      widget.onStartMatch?.call(podState);

      // 2. Return created PodState to the caller
      if (mounted) {
        Navigator.of(context).pop(podState);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isCreatingSession = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final screenHeight = mediaQuery.size.height;

    return Container(
      key: const Key('pregame_setup_sheet'),
      height: screenHeight * 0.92,
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Color(0xFF141820),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black87,
            blurRadius: 20,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Modal Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Match Setup',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Select decks, format & starting life presets',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const Key('setup_sheet_close_btn'),
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white12, height: 1),

          // Scrollable Setup Body
          Expanded(
            child: ListView(
              cacheExtent: 10000,
              padding: const EdgeInsets.all(16),
              children: [
                // 1. Player Count Selector
                _buildPlayerCountSection(),
                const SizedBox(height: 16),

                // 2. Pod Table Seating Orientation Picker (R5.1)
                _buildSeatingOrientationSection(),
                const SizedBox(height: 16),

                // 3. Format & Starting Life Selector with Snap Slider (R5.2)
                _buildFormatAndLifeSection(),
                const SizedBox(height: 16),

                // 4. Player Card Layout Density (R4.2)
                _buildCardDensitySection(),
                const SizedBox(height: 16),

                // 5. OLED True Black & Immersive Gameplay Settings (R5.3 & R5.4)
                _buildDisplayAndGameplaySettingsSection(),
                const SizedBox(height: 20),

                // 5. Player Seating & Deck Assignment List
                const Text(
                  'Players & Decks',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...List.generate(_players.length, (i) => _buildPlayerCard(i)),
              ],
            ),
          ),

          // Bottom Action Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF101318),
              border: Border(top: BorderSide(color: Colors.white12, width: 0.5)),
            ),
            child: KeyedSubtree(
              key: const Key('pregame_start_match_button'),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  key: const Key('start_match_button'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentGold,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: _isCreatingSession
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : const Icon(Icons.play_arrow, size: 22),
                label: Text(
                  _isCreatingSession ? 'Starting Match...' : 'Start Match ($_format • $_startingLife Life)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                onPressed: _isCreatingSession ? null : _startMatch,
              ),
            ),
          ),
        ),
        ],
      ),
    );
  }

  /// Player count segmented control
  Widget _buildPlayerCountSection() {
    final selectedCount = _pendingPlayerCount ?? _playerCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pod Size (Player Count)',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: _playerCounts.map((count) {
            final isSelected = count == selectedCount;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: InkWell(
                  key: Key('player_count_btn_$count'),
                  onTap: () => _setPlayerCount(count),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.accentGold : const Color(0xFF1C222C),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? AppColors.accentGold : Colors.white12,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      count == 1 ? '1P' : (count == 2 ? '1v1' : '${count}P'),
                      style: TextStyle(
                        color: isSelected ? Colors.black : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        if (_showResetWarning && _pendingResetTrigger == _ResetTrigger.playerCount) ...[
          const SizedBox(height: 10),
          _buildResetWarningBox(),
        ],
      ],
    );
  }

  /// Pod table seating orientation segmented control with visual miniature layout icons (R2)
  Widget _buildSeatingOrientationSection() {
    final segments = _buildSegmentsForPlayerCount(_playerCount);
    final validValues = segments.map((s) => s.value).toSet();
    final effectiveSelected = validValues.contains(_seatingOrientation)
        ? _seatingOrientation
        : validValues.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pod Seating Orientation',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<String>(
            key: const Key('pregame_seating_orientation_picker'),
            style: SegmentedButton.styleFrom(
              backgroundColor: const Color(0xFF1C222C),
              selectedBackgroundColor: AppColors.accentGold,
              selectedForegroundColor: Colors.black,
              foregroundColor: Colors.white70,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            ),
            segments: segments,
            selected: {effectiveSelected},
            onSelectionChanged: (newSelection) {
              final selectedVal = newSelection.first;
              setState(() {
                _seatingOrientation = selectedVal;
                if (_playerCount == 4 || _playerCount == 1) {
                  _layoutVariant = selectedVal;
                } else {
                  if (selectedVal == 'standard' || selectedVal == 'B') {
                    _layoutVariant = 'B';
                  } else if (selectedVal == 'opposed' || selectedVal == 'A') {
                    _layoutVariant = 'A';
                  } else {
                    _layoutVariant = selectedVal;
                  }
                }
                PregameSetupSheet.lastSeatingOrientation = _seatingOrientation;
                PregameSetupSheet.lastLayoutVariant = _layoutVariant;
              });
            },
          ),
        ),
      ],
    );
  }

  List<ButtonSegment<String>> _buildSegmentsForPlayerCount(int count) {
    if (count == 1) {
      return [
        ButtonSegment<String>(
          value: 'opposed',
          icon: const MiniatureLayoutIcon(playerCount: 1, variant: 'A', isSelected: true),
          label: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Solo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              Text('Full View', style: TextStyle(fontSize: 10)),
            ],
          ),
        ),
      ];
    }

    if (count == 4) {
      return [
        ButtonSegment<String>(
          value: 'opposed',
          icon: MiniatureLayoutIcon(playerCount: 4, variant: 'A', isSelected: _seatingOrientation == 'opposed'),
          label: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Opposed', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              Text('2x2 Grid', style: TextStyle(fontSize: 10)),
            ],
          ),
        ),
        ButtonSegment<String>(
          value: 'standard',
          icon: MiniatureLayoutIcon(playerCount: 4, variant: 'B', isSelected: _seatingOrientation == 'standard'),
          label: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Standard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              Text('1-2-1 Hybrid', style: TextStyle(fontSize: 10)),
            ],
          ),
        ),
        const ButtonSegment<String>(
          value: 'radial',
          icon: Icon(Icons.rotate_right_rounded, size: 16),
          label: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Radial', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              Text('Circular', style: TextStyle(fontSize: 10)),
            ],
          ),
        ),
      ];
    }

    String labelA = 'Layout A';
    String descA = 'Opposed';
    String labelB = 'Layout B';
    String descB = 'Standard';

    switch (count) {
      case 2:
        labelA = 'Opposed';
        descA = 'Face-to-Face';
        labelB = 'Standard';
        descB = 'Side-by-Side';
        break;
      case 3:
        descA = 'Top 1 & 3, Bot 0';
        descB = 'Top 2, Bot 0 & 0';
        break;
      case 5:
        descA = 'Grid (2+2+1)';
        descB = 'Opposed (2+3)';
        break;
      case 6:
        descA = '2x3 Side Grid';
        descB = 'Head-of-Table';
        break;
    }

    return [
      ButtonSegment<String>(
        value: 'opposed',
        icon: MiniatureLayoutIcon(playerCount: count, variant: 'A', isSelected: _seatingOrientation == 'opposed'),
        label: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(labelA, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            Text(descA, style: const TextStyle(fontSize: 10)),
          ],
        ),
      ),
      ButtonSegment<String>(
        value: 'standard',
        icon: MiniatureLayoutIcon(playerCount: count, variant: 'B', isSelected: _seatingOrientation == 'standard'),
        label: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(labelB, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            Text(descB, style: const TextStyle(fontSize: 10)),
          ],
        ),
      ),
    ];
  }

  /// Format & starting life presets with interactive snap slider (R5.2)
  Widget _buildFormatAndLifeSection() {
    final displayedLife = _pendingStartingLife ?? _startingLife;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'Format & Starting Life',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // Custom life stepper
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  key: const Key('life_dec_btn'),
                  icon: const Icon(Icons.remove_circle_outline, size: 18, color: Colors.white60),
                  onPressed: () => _setStartingLife((displayedLife - 5).clamp(1, 999)),
                ),
                Text(
                  '$displayedLife',
                  key: const Key('starting_life_value_text'),
                  style: const TextStyle(
                    color: AppColors.accentGold,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                IconButton(
                  key: const Key('life_inc_btn'),
                  icon: const Icon(Icons.add_circle_outline, size: 18, color: Colors.white60),
                  onPressed: () => _setStartingLife((displayedLife + 5).clamp(1, 999)),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Interactive Starting Life Slider with Snap Points (R5.2)
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppColors.accentGold,
            inactiveTrackColor: Colors.white24,
            thumbColor: AppColors.accentGold,
            overlayColor: AppColors.accentGold.withValues(alpha: 0.2),
            valueIndicatorColor: AppColors.accentGold,
            valueIndicatorTextStyle:
                const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          child: Slider(
            key: const Key('pregame_starting_life_slider'),
            min: 10.0,
            max: 100.0,
            divisions: 90,
            value: displayedLife.toDouble().clamp(10.0, 100.0),
            label: '$displayedLife Life',
            onChanged: (val) {
              int target = val.round();
              // Format snap points: 40 Commander, 30 Brawl, 20 Standard
              const snapNodes = [20, 30, 40];
              for (final node in snapNodes) {
                if ((target - node).abs() <= 2) {
                  target = node;
                  break;
                }
              }
              _setStartingLife(target);
            },
          ),
        ),
        const SizedBox(height: 4),
        // Preset pills
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildPresetChip('Commander (40)', 'commander', 40),
              const SizedBox(width: 8),
              _buildPresetChip('Standard (20)', 'standard', 20),
              const SizedBox(width: 8),
              _buildPresetChip('Brawl (30)', 'brawl', 30),
              const SizedBox(width: 8),
              _buildPresetChip('Draft (20)', 'draft', 20),
            ],
          ),
        ),
        if (_showResetWarning && _pendingResetTrigger == _ResetTrigger.startingLife) ...[
          const SizedBox(height: 10),
          _buildResetWarningBox(),
        ],
      ],
    );
  }

  Widget _buildPresetChip(String label, String formatKey, int life) {
    final displayedFormat = _pendingFormat ?? _format;
    final displayedLife = _pendingStartingLife ?? _startingLife;
    final isSelected = displayedFormat == formatKey && displayedLife == life;
    return ChoiceChip(
      key: Key('preset_chip_$formatKey'),
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          _setFormat(formatKey);
          _setStartingLife(life);
        }
      },
      selectedColor: AppColors.accentGold,
      backgroundColor: const Color(0xFF1C222C),
      labelStyle: TextStyle(
        color: isSelected ? Colors.black : Colors.white70,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      side: BorderSide(
        color: isSelected ? AppColors.accentGold : Colors.white12,
      ),
    );
  }

  /// Player card layout density selector (R4.2)
  Widget _buildCardDensitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Player Card Layout Density',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<String>(
            key: const Key('pregame_density_picker'),
            style: SegmentedButton.styleFrom(
              backgroundColor: const Color(0xFF1C222C),
              selectedBackgroundColor: AppColors.accentGold,
              selectedForegroundColor: Colors.black,
              foregroundColor: Colors.white70,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            ),
            segments: const [
              ButtonSegment<String>(
                value: 'Default',
                label: Text('Default', style: TextStyle(fontSize: 12)),
                icon: Icon(Icons.dashboard_customize_outlined, size: 16),
              ),
              ButtonSegment<String>(
                value: 'Name only',
                label: Text('Name only', style: TextStyle(fontSize: 12)),
                icon: Icon(Icons.badge_outlined, size: 16),
              ),
              ButtonSegment<String>(
                value: 'Big font',
                label: Text('Big font', style: TextStyle(fontSize: 12)),
                icon: Icon(Icons.format_size_rounded, size: 16),
              ),
            ],
            selected: {_cardDensity},
            onSelectionChanged: (newSelection) {
              final selectedVal = newSelection.first;
              setState(() {
                _cardDensity = selectedVal;
                PregameSetupSheet.lastCardDensity = selectedVal;
              });
            },
          ),
        ),
      ],
    );
  }

  /// Display & gameplay settings (OLED mode, Immersive mode, Wakelock, Haptics, Autohide) (R4.3 & R4.4)
  Widget _buildDisplayAndGameplaySettingsSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C222C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Display & Gameplay Preferences',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),

          // 1. Auto-Hide Menu (R4.3)
          KeyedSubtree(
            key: const Key('pregame_autohide_mode_switch'),
            child: SwitchListTile(
              key: const Key('pregame_autohide_switch'),
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text(
                'Auto-Hide Menu',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              value: _isAutohideMenu,
              activeThumbColor: AppColors.accentGold,
              onChanged: (val) {
                setState(() {
                  _isAutohideMenu = val;
                  PregameSetupSheet.lastAutohideMenu = val;
                });
              },
            ),
          ),
          const Divider(color: Colors.white12, height: 1),

          // 2. OLED True Black Mode (R4.4)
          KeyedSubtree(
            key: const Key('pregame_oled_switch'),
            child: SwitchListTile(
              key: const Key('pregame_oled_mode_switch'),
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text(
                'OLED True Black Mode',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              value: _isOledMode,
              activeThumbColor: AppColors.accentGold,
              onChanged: (val) {
                setState(() {
                  _isOledMode = val;
                  PregameSetupSheet.lastOledMode = val;
                });
              },
            ),
          ),
          const Divider(color: Colors.white12, height: 1),

          // 3. Keep Display Awake (R4.4)
          KeyedSubtree(
            key: const Key('pregame_wakelock_mode_switch'),
            child: SwitchListTile(
              key: const Key('pregame_wakelock_switch'),
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text(
                'Keep Display Awake',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              value: _isWakelock,
              activeThumbColor: AppColors.accentGold,
              onChanged: (val) {
                setState(() {
                  _isWakelock = val;
                  PregameSetupSheet.lastWakelock = val;
                });
              },
            ),
          ),
          const Divider(color: Colors.white12, height: 1),

          // 4. Haptic Feedback (R4.4)
          KeyedSubtree(
            key: const Key('pregame_haptics_mode_switch'),
            child: SwitchListTile(
              key: const Key('pregame_haptics_switch'),
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text(
                'Haptic Feedback',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              value: _isHaptics,
              activeThumbColor: AppColors.accentGold,
              onChanged: (val) {
                setState(() {
                  _isHaptics = val;
                  PregameSetupSheet.lastHaptics = val;
                  PodHaptics.enabled = val;
                });
              },
            ),
          ),
          const Divider(color: Colors.white12, height: 1),

          // 5. Immersive Mode (R4.4)
          KeyedSubtree(
            key: const Key('pregame_immersive_switch'),
            child: SwitchListTile(
              key: const Key('pregame_immersive_mode_switch'),
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text(
                'Immersive Mode',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              value: _isImmersiveMode,
              activeThumbColor: AppColors.accentGold,
              onChanged: (val) {
                setState(() {
                  _isImmersiveMode = val;
                  PregameSetupSheet.lastImmersiveMode = val;
                });
              },
            ),
          ),
          const Divider(color: Colors.white12, height: 1),

          // 6. Camera Mode (Streamer / Overhead)
          SwitchListTile(
            key: const Key('pregame_camera_mode_switch'),
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text(
              'Camera Mode (Streamer / Overhead)',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            value: _isCameraMode,
            activeThumbColor: AppColors.accentGold,
            onChanged: (val) {
              setState(() {
                _isCameraMode = val;
                PregameSetupSheet.lastCameraMode = val;
              });
            },
          ),
        ],
      ),
    );
  }

  /// Individual seat card
  Widget _buildPlayerCard(int seatIndex) {
    final player = _players[seatIndex];
    final hasDeck = player.deck != null;

    return Container(
      key: Key('player_setup_card_$seatIndex'),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F29),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasDeck ? AppColors.accentGold.withValues(alpha: 0.5) : Colors.white12,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Player Seat Header & Name Input
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                // Seat Number Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'P${seatIndex + 1}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Name Input
                Expanded(
                  child: TextField(
                    key: Key('player_name_input_$seatIndex'),
                    controller: player.nameController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Player ${seatIndex + 1} Name',
                      hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.black26,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Art Override Action Button
                IconButton(
                  key: Key('art_override_btn_$seatIndex'),
                  icon: const Icon(Icons.image_search, color: Colors.white60, size: 20),
                  tooltip: 'Customize Backdrop Art',
                  onPressed: () => _openArtOverride(seatIndex),
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white10, height: 1),

          // Deck Linking Row
          Padding(
            padding: const EdgeInsets.all(10),
            child: hasDeck
                ? _buildLinkedDeckRow(seatIndex, player)
                : _buildUnlinkedDeckRow(seatIndex),
          ),
        ],
      ),
    );
  }

  /// Deck linked status view
  Widget _buildLinkedDeckRow(int seatIndex, _PlayerSetupEntry player) {
    final deck = player.deck!;
    final commanderArt = player.artCropUrl;

    return Row(
      children: [
        // Commander Art Crop Mini Avatar
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 48,
            height: 48,
            color: Colors.black38,
            child: commanderArt != null
                ? CountrCachedImage(
                    imageUrl: commanderArt,
                    fit: BoxFit.cover,
                    errorWidget: const Icon(Icons.shield, color: Colors.white38),
                  )
                : const Icon(Icons.shield, color: Colors.white38),
          ),
        ),
        const SizedBox(width: 12),

        // Deck & Commander Info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                deck.name,
                key: Key('deck_title_$seatIndex'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              if (player.commanderName != null)
                Text(
                  'Cmd: ${player.commanderName}',
                  key: Key('commander_name_$seatIndex'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.accentGold,
                    fontSize: 11,
                  ),
                ),
              Text(
                '${deck.format} • ${deck.cardCount} cards',
                style: const TextStyle(color: Colors.white54, fontSize: 10),
              ),
            ],
          ),
        ),

        // Change Deck Button
        TextButton(
          key: Key('change_deck_btn_$seatIndex'),
          onPressed: () => _openDeckPicker(seatIndex),
          child: const Text('Change', style: TextStyle(fontSize: 12)),
        ),

        // Unlink Deck Button
        IconButton(
          key: Key('clear_deck_btn_$seatIndex'),
          icon: const Icon(Icons.close, color: Colors.redAccent, size: 18),
          tooltip: 'Unlink Deck',
          onPressed: () => _clearPlayerDeck(seatIndex),
        ),
      ],
    );
  }

  /// Deck unlinked prompt
  Widget _buildUnlinkedDeckRow(int seatIndex) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            key: Key('select_deck_btn_$seatIndex'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: const BorderSide(color: Colors.white24, strokeAlign: BorderSide.strokeAlignCenter),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.style, size: 18, color: AppColors.accentGold),
            label: const Text('Link Saved Deck (Vault)'),
            onPressed: () => _openDeckPicker(seatIndex),
          ),
        ),
      ],
    );
  }
}

/// Modal sheet displaying saved MTG decks for selection.
class _SavedDecksPickerSheet extends ConsumerWidget {
  final List<DeckSummary>? injectedDecks;
  final void Function(DeckSummary deck) onDeckSelected;

  const _SavedDecksPickerSheet({
    this.injectedDecks,
    required this.onDeckSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // If injected decks are provided, use them directly (supports pure widget testing)
    if (injectedDecks != null) {
      return _buildDeckList(context, injectedDecks!);
    }

    final decksAsync = ref.watch(deckSummariesProvider);

    return decksAsync.when(
      data: (decks) => _buildDeckList(context, decks),
      loading: () => Container(
        height: 300,
        decoration: const BoxDecoration(
          color: Color(0xFF141820),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.accentGold),
        ),
      ),
      error: (e, _) => Container(
        height: 200,
        decoration: const BoxDecoration(
          color: Color(0xFF141820),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Center(
          child: Text(
            'Failed to load decks: $e',
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      ),
    );
  }

  Widget _buildDeckList(BuildContext context, List<DeckSummary> decks) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.70,
      decoration: const BoxDecoration(
        color: Color(0xFF141820),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Select Saved Deck',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          Expanded(
            child: decks.isEmpty
                ? const Center(
                    child: Text(
                      'No saved decks found in Vault.\nCreate decks in Deck Builder first.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, height: 1.4),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: decks.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final deck = decks[index];
                      final art = deck.commanderArtCrop ?? deck.commanderImageUrl;

                      return ListTile(
                        key: Key('deck_picker_tile_${deck.id}'),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(color: Colors.white12),
                        ),
                        tileColor: const Color(0xFF1C222C),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            width: 44,
                            height: 44,
                            color: Colors.black26,
                            child: art != null
                                ? CountrCachedImage(
                                    imageUrl: art,
                                    fit: BoxFit.cover,
                                    errorWidget: const Icon(Icons.style, color: Colors.white38),
                                  )
                                : const Icon(Icons.style, color: Colors.white38),
                          ),
                        ),
                        title: Text(
                          deck.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          deck.commanderName != null
                              ? '${deck.commanderName} • ${deck.format}'
                              : '${deck.format} • ${deck.cardCount} cards',
                          style: const TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                        trailing: const Icon(Icons.chevron_right, color: Colors.white38),
                        onTap: () => onDeckSelected(deck),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
