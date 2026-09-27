// Copyright (c) 2026 Countr. All rights reserved.

import 'package:flutter/material.dart';
import 'package:countr/core/constants/app_colors.dart';

/// Confirmation dialog for the Global "Reset Game" action (Feature 46).
///
/// Features:
/// 1. Prevents accidental in-game resets by requiring explicit confirmation.
/// 2. Displays warning prompt:
///    "Reset current game? Life totals will return to {startingLife} and all counters/mana will be cleared. Seating and commanders will be preserved."
/// 3. Reassures players that seating, deck selections, and commanders are strictly preserved.
/// 4. Supports key bindings:
///    - Key 'reset_game_dialog'
///    - Key 'confirm_reset_game_btn'
///    - Key 'cancel_reset_game_btn'
///    - Key 'reset_game_prompt_text'
class ResetGameDialog extends StatelessWidget {
  /// The starting life that players will be restored to upon reset.
  final int startingLife;

  /// Callback executed when the player confirms the game reset.
  final VoidCallback onConfirm;

  /// Callback executed when the player cancels the reset.
  final VoidCallback? onCancel;

  const ResetGameDialog({
    super.key,
    required this.startingLife,
    required this.onConfirm,
    this.onCancel,
  });

  /// Displays the [ResetGameDialog] alert dialog.
  static Future<bool?> show(
    BuildContext context, {
    required int startingLife,
    required VoidCallback onConfirm,
    VoidCallback? onCancel,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ResetGameDialog(
        startingLife: startingLife,
        onConfirm: onConfirm,
        onCancel: onCancel,
      ),
    );
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
            'Reset Game?',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
      content: Text(
        'Reset current game? Life totals will return to $startingLife and all counters/mana will be cleared. Seating and commanders will be preserved.',
        key: const Key('reset_game_prompt_text'),
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 14,
          height: 1.4,
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      actions: [
        TextButton(
          key: const Key('cancel_reset_game_btn'),
          onPressed: () {
            onCancel?.call();
            Navigator.of(context).pop(false);
          },
          child: const Text(
            'Cancel',
            style: TextStyle(color: Colors.white60, fontWeight: FontWeight.w600),
          ),
        ),
        ElevatedButton(
          key: const Key('confirm_reset_game_btn'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade800,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () {
            onConfirm();
            Navigator.of(context).pop(true);
          },
          child: const Text(
            'Reset Game',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
