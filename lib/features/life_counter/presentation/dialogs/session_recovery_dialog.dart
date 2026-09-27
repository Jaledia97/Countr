import 'package:flutter/material.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/constants/app_typography.dart';
import 'package:countr/core/database/app_database.dart';

/// Presentation dialog prompted whenever an interrupted or active match is detected
/// on app cold launch or navigation to the MTG Life Counter.
///
/// Prompts the user to either:
/// 1. "Continue Match": Reconstitutes board state, seating, and history without data loss.
/// 2. "Start New Game": Marks previous session as abandoned and launches a fresh pod setup wizard.
class SessionRecoveryDialog extends StatelessWidget {
  final MatchSession session;
  final List<MatchPlayer> players;
  final VoidCallback onContinue;
  final VoidCallback onStartNew;

  const SessionRecoveryDialog({
    super.key,
    required this.session,
    required this.players,
    required this.onContinue,
    required this.onStartNew,
  });

  /// Displays the modal dialog as a non-dismissible prompt.
  static Future<void> show({
    required BuildContext context,
    required MatchSession session,
    required List<MatchPlayer> players,
    required VoidCallback onContinue,
    required VoidCallback onStartNew,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SessionRecoveryDialog(
        session: session,
        players: players,
        onContinue: onContinue,
        onStartNew: onStartNew,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final duration = DateTime.now().difference(session.createdAt);
    final durationString = _formatDuration(duration);

    return Dialog(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.surfaceBorder, width: 1.5),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Row: Icon + Title
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.accentAmber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.accentAmber.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Icon(
                      Icons.history_rounded,
                      color: AppColors.accentAmber,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Active Match Detected',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${session.format} • ${players.length} Players • Started $durationString ago',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Player Roster Card
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.surfaceBorderSubtle),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    for (int i = 0; i < players.length; i++) ...[
                      if (i > 0)
                        const Divider(
                          color: AppColors.surfaceBorderSubtle,
                          height: 12,
                          thickness: 1,
                        ),
                      _buildPlayerRow(players[i]),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Action Buttons Row
              Row(
                children: [
                  // Start New Game (Destructive / Secondary)
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('session_recovery_start_new_button'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.surfaceBorder),
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: onStartNew,
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Start New Game',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Continue Match (Primary Action)
                  Expanded(
                    child: ElevatedButton(
                      key: const Key('session_recovery_continue_button'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentAmber,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: onContinue,
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.play_arrow_rounded, size: 20),
                            SizedBox(width: 6),
                            Text(
                              'Continue Match',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerRow(MatchPlayer player) {
    return Row(
      children: [
        // Commander Art Thumbnail or Initial Avatar
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.surfaceHighlight,
            borderRadius: BorderRadius.circular(8),
            image: (player.artCropUrl != null && player.artCropUrl!.isNotEmpty)
                ? DecorationImage(
                    image: NetworkImage(player.artCropUrl!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: (player.artCropUrl == null || player.artCropUrl!.isEmpty)
              ? Center(
                  child: Text(
                    player.playerName.isNotEmpty
                        ? player.playerName.substring(0, 1).toUpperCase()
                        : 'P',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                )
              : null,
        ),

        const SizedBox(width: 10),

        // Player Name & Commander Subtitle
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                player.playerName,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (player.commanderName != null && player.commanderName!.isNotEmpty)
                Text(
                  player.commanderName!,
                  style: AppTypography.caption.copyWith(
                    fontSize: 10.5,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),

        // Current Life Display
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: player.currentLife <= 0
                ? AppColors.accentRose.withValues(alpha: 0.15)
                : AppColors.surfaceHighlight,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: player.currentLife <= 0
                  ? AppColors.accentRose.withValues(alpha: 0.4)
                  : AppColors.surfaceBorderSubtle,
            ),
          ),
          child: Text(
            '${player.currentLife}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: player.currentLife <= 0
                  ? AppColors.accentRose
                  : AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    if (d.inDays > 0) return '${d.inDays}d';
    if (d.inHours > 0) return '${d.inHours}h';
    if (d.inMinutes > 0) return '${d.inMinutes}m';
    return '${d.inSeconds}s';
  }
}
