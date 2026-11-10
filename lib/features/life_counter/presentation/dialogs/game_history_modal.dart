// Copyright (c) 2026 Countr. All rights reserved.

import 'package:flutter/material.dart';

import 'package:countr/features/life_counter/domain/models/game_history_entry.dart';

/// Modal bottom sheet presenting committed game actions and the turn log.
class GameHistoryModal extends StatelessWidget {
  final List<GameHistoryEntry> gameHistory;
  final VoidCallback? onClearHistory;

  const GameHistoryModal({
    super.key,
    required this.gameHistory,
    this.onClearHistory,
  });

  /// Presents the Game History modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required List<GameHistoryEntry> gameHistory,
    VoidCallback? onClearHistory,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1D27),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => GameHistoryModal(
        gameHistory: gameHistory,
        onClearHistory: onClearHistory,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        key: const Key('game_history_modal'),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Drag Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header Bar
            Row(
              children: [
                const Icon(
                  Icons.history_rounded,
                  color: Colors.amberAccent,
                  size: 22,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Game History & Turn Log',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (gameHistory.isNotEmpty && onClearHistory != null)
                  TextButton.icon(
                    key: const Key('game_history_clear_button'),
                    onPressed: () {
                      onClearHistory?.call();
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.delete_sweep_outlined,
                        size: 16, color: Colors.redAccent),
                    label: const Text(
                      'Clear',
                      style: TextStyle(color: Colors.redAccent, fontSize: 13),
                    ),
                  ),
                IconButton(
                  key: const Key('game_history_close_button'),
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(color: Colors.white12, height: 16),

            // Content
            Expanded(
              child: gameHistory.isEmpty
                  ? Center(
                      child: Container(
                        key: const Key('game_history_empty'),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 32),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.history_toggle_off_rounded,
                              size: 48,
                              color: Colors.white24,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'No committed game actions yet.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: gameHistory.length,
                      separatorBuilder: (ctx, index) =>
                          const Divider(color: Colors.white10, height: 1),
                      itemBuilder: (ctx, index) {
                        final entry = gameHistory[index];
                        final isPositive = entry.delta > 0;
                        final deltaText =
                            isPositive ? '+${entry.delta}' : '${entry.delta}';
                        final timestampStr =
                            '${entry.timestamp.hour.toString().padLeft(2, '0')}:'
                            '${entry.timestamp.minute.toString().padLeft(2, '0')}:'
                            '${entry.timestamp.second.toString().padLeft(2, '0')}';

                        return Container(
                          key: Key('history_item_${entry.id}'),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 10),
                          child: Row(
                            children: [
                              // Timestamp
                              Text(
                                timestampStr,
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Description
                              Expanded(
                                child: Text(
                                  entry.description,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                              ),

                              const SizedBox(width: 8),

                              // Delta pill
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isPositive
                                      ? Colors.green.withValues(alpha: 0.2)
                                      : Colors.red.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isPositive
                                        ? Colors.greenAccent
                                        : Colors.redAccent,
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  deltaText,
                                  style: TextStyle(
                                    color: isPositive
                                        ? Colors.greenAccent
                                        : Colors.redAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
