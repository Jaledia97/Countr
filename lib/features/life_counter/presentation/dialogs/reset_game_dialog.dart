// Copyright (c) 2026 Countr. All rights reserved.

import 'package:flutter/material.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/features/life_counter/domain/models/pod_state.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';

/// Reset actions supported by the Smart Reset Game modal dialog (R5.3).
enum ResetGameAction {
  reset,
  resetRandomizeSeats,
  resetClearProfiles,
}

/// Result payload containing chosen reset action, winner ID, or draw flag.
class ResetGameResult {
  final ResetGameAction action;
  final String? winningPlayerId;
  final bool isDraw;

  const ResetGameResult({
    required this.action,
    this.winningPlayerId,
    this.isDraw = false,
  });
}

/// Smart Confirmation dialog for the Global "Reset Game" action (R5.3).
///
/// Features:
/// 1. Prevents accidental in-game resets by requiring explicit confirmation.
/// 2. Displays warning prompt:
///    "Reset current game? Life totals will return to {startingLife} and all counters/mana will be cleared. Seating and commanders will be preserved."
/// 3. Winner selection pills: [Player 1  20], [Player 2  0], etc. and [Draw] pill.
/// 4. 4 Action Buttons:
///    - 'Reset' (Key: 'confirm_reset_game_btn')
///    - 'Reset + randomize seats' (Key: 'reset_randomize_seats_btn')
///    - 'Reset + clear profiles' (Key: 'reset_clear_profiles_btn')
///    - 'Cancel' (Key: 'cancel_reset_game_btn')
/// 5. Automatically records deck match results (wins, losses, draws) in SQLite via [VaultDao].
class ResetGameDialog extends StatefulWidget {
  final int startingLife;
  final List<PodPlayerState> players;
  final VoidCallback? onConfirm;
  final void Function(ResetGameResult result)? onConfirmAction;
  final VoidCallback? onCancel;
  final VaultDao? vaultDao;

  const ResetGameDialog({
    super.key,
    required this.startingLife,
    this.players = const [],
    this.onConfirm,
    this.onConfirmAction,
    this.onCancel,
    this.vaultDao,
  });

  /// Displays the [ResetGameDialog] alert dialog.
  static Future<ResetGameResult?> show(
    BuildContext context, {
    required int startingLife,
    List<PodPlayerState> players = const [],
    VoidCallback? onConfirm,
    void Function(ResetGameResult result)? onConfirmAction,
    VoidCallback? onCancel,
    VaultDao? vaultDao,
  }) {
    return showDialog<ResetGameResult>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ResetGameDialog(
        startingLife: startingLife,
        players: players,
        onConfirm: onConfirm,
        onConfirmAction: onConfirmAction,
        onCancel: onCancel,
        vaultDao: vaultDao,
      ),
    );
  }

  @override
  State<ResetGameDialog> createState() => _ResetGameDialogState();
}

class _ResetGameDialogState extends State<ResetGameDialog> {
  String? _selectedWinnerId;
  bool _isDraw = false;

  void _handleConfirm(ResetGameAction action) async {
    final result = ResetGameResult(
      action: action,
      winningPlayerId: _selectedWinnerId,
      isDraw: _isDraw,
    );

    // Synchronize to SQLite if vaultDao is available and match result is determined
    if (widget.vaultDao != null && (_selectedWinnerId != null || _isDraw)) {
      try {
        if (_selectedWinnerId != null) {
          final winner = widget.players.cast<PodPlayerState?>().firstWhere(
            (p) => p?.id == _selectedWinnerId,
            orElse: () => null,
          );
          final winningDeckId = (winner?.deckId != null && winner!.deckId!.isNotEmpty)
              ? winner.deckId
              : null;
          final losingDeckIds = widget.players
              .where((p) => p.id != _selectedWinnerId && p.deckId != null && p.deckId!.isNotEmpty)
              .map((p) => p.deckId!)
              .toList();

          await widget.vaultDao!.recordDeckMatchResults(
            winningDeckId: winningDeckId,
            losingDeckIds: losingDeckIds,
          );
        } else if (_isDraw) {
          final drawDeckIds = widget.players
              .where((p) => p.deckId != null && p.deckId!.isNotEmpty)
              .map((p) => p.deckId!)
              .toList();

          await widget.vaultDao!.recordDeckMatchResults(
            drawDeckIds: drawDeckIds,
          );
        }
      } catch (e) {
        debugPrint('VaultDao deck sync skipped or failed: $e');
      }
    }

    widget.onConfirm?.call();
    widget.onConfirmAction?.call(result);
    if (mounted) {
      Navigator.of(context).pop(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('reset_game_dialog'),
      backgroundColor: const Color(0xFF141820),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.white12),
      ),
      title: const Row(
        children: [
          Icon(Icons.replay_rounded, color: Colors.redAccent, size: 24),
          SizedBox(width: 8),
          Text(
            'Reset Game',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Reset current game? Life totals will return to ${widget.startingLife} and all counters/mana will be cleared. Seating and commanders will be preserved.',
              key: const Key('reset_game_prompt_text'),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            if (widget.players.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Select the Winner (Optional):',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...widget.players.map((p) {
                    final isSelected = _selectedWinnerId == p.id;
                    return InkWell(
                      key: Key('reset_winner_pill_${p.id}'),
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        setState(() {
                          if (_selectedWinnerId == p.id) {
                            _selectedWinnerId = null;
                          } else {
                            _selectedWinnerId = p.id;
                            _isDraw = false;
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.accentGold.withValues(alpha: 0.25)
                              : const Color(0xFF222834),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? AppColors.accentGold : Colors.white24,
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isSelected) ...[
                              const Icon(Icons.emoji_events, size: 14, color: AppColors.accentGold),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              '${p.name}  ${p.life}',
                              style: TextStyle(
                                color: isSelected ? AppColors.accentGold : Colors.white,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  // Draw pill
                  InkWell(
                    key: const Key('reset_draw_pill'),
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      setState(() {
                        _isDraw = !_isDraw;
                        if (_isDraw) {
                          _selectedWinnerId = null;
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _isDraw
                            ? AppColors.accentCyan.withValues(alpha: 0.25)
                            : const Color(0xFF222834),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _isDraw ? AppColors.accentCyan : Colors.white24,
                          width: _isDraw ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isDraw) ...[
                            const Icon(Icons.handshake, size: 14, color: AppColors.accentCyan),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            'Draw',
                            style: TextStyle(
                              color: _isDraw ? AppColors.accentCyan : Colors.white,
                              fontWeight: _isDraw ? FontWeight.bold : FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      actions: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Action 1: Standard Reset
            ElevatedButton(
              key: const Key('confirm_reset_game_btn'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade800,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => _handleConfirm(ResetGameAction.reset),
              child: const Text(
                'Reset',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 6),

            // Action 2: Reset + randomize seats
            OutlinedButton(
              key: const Key('reset_randomize_seats_btn'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.amberAccent,
                side: const BorderSide(color: Colors.amberAccent),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => _handleConfirm(ResetGameAction.resetRandomizeSeats),
              child: const Text('Reset + randomize seats'),
            ),
            const SizedBox(height: 6),

            // Action 3: Reset + clear profiles
            OutlinedButton(
              key: const Key('reset_clear_profiles_btn'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: Colors.white24),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => _handleConfirm(ResetGameAction.resetClearProfiles),
              child: const Text('Reset + clear profiles'),
            ),
            const SizedBox(height: 6),

            // Action 4: Cancel
            TextButton(
              key: const Key('cancel_reset_game_btn'),
              onPressed: () {
                widget.onCancel?.call();
                Navigator.of(context).pop(null);
              },
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white60, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
