// Copyright (c) 2026 Countr. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:countr/core/cache/countr_cached_image.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/features/decks/domain/models/deck_summary.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/life_counter/domain/models/pod_state.dart';
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

/// Pre-game Deck Selection & Pod Setup Modal Bottom Sheet (Feature 29).
///
/// Features:
/// - Links players to saved MTG decks from `VaultDao` via [deckSummariesProvider].
/// - When a deck is selected, automatically populates:
///   1. Player name (auto-populates to deck name if unedited or default).
///   2. Commander card ID and commander name.
///   3. Commander `art_crop` URL for dynamic backdrop rendering.
///   4. Recommended starting life preset based on format (40 for Commander, 20 for Standard, 30 for Brawl).
/// - Dynamic player count selection (2-player 1v1, 3P, 4P 2x2, 5P, 6P 2x3).
/// - Format selector (Commander, Standard, Brawl, Draft, Custom).
/// - Starting life presets (20, 30, 40, Custom numeric stepper).
/// - Full decoupling for testing: accepts optional [injectedDecks] and [onStartMatch] callback.
/// - Produces a validated [PodState] ready for instant match initialization.
class PregameSetupSheet extends ConsumerStatefulWidget {
  /// Initial number of players (defaults to 4, clamped between 2 and 6).
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

  const PregameSetupSheet({
    super.key,
    this.initialPlayerCount = 4,
    this.initialFormat = 'commander',
    this.initialStartingLife,
    this.initialPlayers,
    this.injectedDecks,
    this.onStartMatch,
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
      ),
    );
  }

  @override
  ConsumerState<PregameSetupSheet> createState() => _PregameSetupSheetState();
}

class _PregameSetupSheetState extends ConsumerState<PregameSetupSheet> {
  late int _playerCount;
  late String _format;
  late int _startingLife;
  final List<_PlayerSetupEntry> _players = [];
  bool _isCreatingSession = false;

  static const List<int> _playerCounts = [2, 3, 4, 5, 6];

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
    _playerCount = widget.initialPlayerCount.clamp(2, 6);
    _format = widget.initialFormat.toLowerCase();
    _startingLife = widget.initialStartingLife ??
        (_formatStartingLife[_format] ?? 40);

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
      _playerCount = count;
    });
  }

  void _setFormat(String newFormat) {
    setState(() {
      _format = newFormat;
      _startingLife = _formatStartingLife[newFormat] ?? _startingLife;
    });
  }

  void _setStartingLife(int life) {
    setState(() {
      _startingLife = life;
    });
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
    for (var i = 0; i < _players.length; i++) {
      final p = _players[i];
      final name = p.nameController.text.trim().isNotEmpty
          ? p.nameController.text.trim()
          : 'Player ${i + 1}';

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

    final podState = PodState(
      sessionId: const Uuid().v4(),
      format: _format,
      startingLife: _startingLife,
      players: podPlayers,
      isDay: true,
      isP2pHost: true,
      sequenceNumber: 0,
    );

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
              padding: const EdgeInsets.all(16),
              children: [
                // 1. Player Count Selector
                _buildPlayerCountSection(),
                const SizedBox(height: 16),

                // 2. Format & Starting Life Selector
                _buildFormatAndLifeSection(),
                const SizedBox(height: 20),

                // 3. Player Seating & Deck Assignment List
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
        ],
      ),
    );
  }

  /// Player count segmented control
  Widget _buildPlayerCountSection() {
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
            final isSelected = count == _playerCount;
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
                      count == 2 ? '1v1' : '${count}P',
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
      ],
    );
  }

  /// Format & starting life presets
  Widget _buildFormatAndLifeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Format & Starting Life',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            // Custom life stepper
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  key: const Key('life_dec_btn'),
                  icon: const Icon(Icons.remove_circle_outline, size: 18, color: Colors.white60),
                  onPressed: () => _setStartingLife((_startingLife - 5).clamp(1, 999)),
                ),
                Text(
                  '$_startingLife',
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
                  onPressed: () => _setStartingLife((_startingLife + 5).clamp(1, 999)),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),
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
      ],
    );
  }

  Widget _buildPresetChip(String label, String formatKey, int life) {
    final isSelected = _format == formatKey && _startingLife == life;
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

  /// Individual seat card
  Widget _buildPlayerCard(int seatIndex) {
    final player = _players[seatIndex];
    final hasDeck = player.deck != null;

    return Container(
      key: Key('player_setup_card_$seatIndex'),
      margin: const EdgeInsets.only(bottom: 12),
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
