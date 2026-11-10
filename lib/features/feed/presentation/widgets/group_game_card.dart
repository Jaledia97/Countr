// Copyright (c) 2026 Countr. All rights reserved.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../life_counter/presentation/widgets/pod_scaffold_widget.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../domain/models/group_game_models.dart';
import '../providers/group_game_providers.dart';
import 'select_deck_for_queue_sheet.dart';

/// Card widget displaying an active LGS EDH pod, its seated players,
/// the next-game waitlist queue, and a button to reserve a spot.
class GroupGameCard extends ConsumerWidget {
  final GroupPodGame game;

  const GroupGameCard({super.key, required this.game});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.watch(currentUserIdProvider);
    final profile = ref.watch(currentUserProfileProvider);
    final isQueued = game.isUserQueued(currentUserId);
    final position = game.queuePosition(currentUserId);

    return Container(
      key: Key('group_game_card_${game.id}'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isQueued
              ? AppColors.accentCyan.withValues(alpha: 0.6)
              : AppColors.surfaceBorder,
          width: isQueued ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Pod Title, Status badge, Format
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.accentViolet.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.groups_rounded,
                    color: AppColors.accentVioletLight,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        game.title,
                        style: AppTypography.heading2.copyWith(fontSize: 16),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 13,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              game.location,
                              style: AppTypography.bodySecondary.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Status Badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accentCyan.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.accentCyan.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    game.status,
                    style: const TextStyle(
                      color: AppColors.accentCyan,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(color: AppColors.surfaceBorder, height: 1),

          // Seated Players Grid / List
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Seated Players (${game.seatedPlayers.length}/${game.maxSeats})',
                        style: AppTypography.bodySecondary.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      'Starting Life: ${game.startingLife}',
                      style: AppTypography.bodySecondary.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: game.seatedPlayers.map((player) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.surfaceBorder,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor:
                                AppColors.accentCyan.withValues(alpha: 0.2),
                            child: Text(
                              player.name.isNotEmpty
                                  ? player.name[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.accentCyan,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 95),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  player.name,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (player.commanderName != null)
                                  Text(
                                    player.commanderName!,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textSecondary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: player.life <= 10
                                  ? AppColors.accentRose.withValues(alpha: 0.2)
                                  : AppColors.surfaceRaised,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${player.life} HP',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: player.life <= 10
                                    ? AppColors.accentRose
                                    : AppColors.accentCyan,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          // Waitlist Queue Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(
                  Icons.hourglass_top_rounded,
                  size: 16,
                  color: AppColors.accentGold,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Waitlist: ${game.waitlistCount} ${game.waitlistCount == 1 ? 'player' : 'players'} queued',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.accentGold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isQueued) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.accentCyan.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'You are #$position in line',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.accentCyan,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Action Row: Reserve / Leave / Launch Pod
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (isQueued)
                  Expanded(
                    child: OutlinedButton.icon(
                      key: Key('leave_queue_btn_${game.id}'),
                      onPressed: () {
                        ref.read(groupGamesProvider.notifier).leaveQueue(
                              gameId: game.id,
                              userId: currentUserId,
                            );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Left the waitlist for ${game.title}'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text('Leave Queue'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.accentRose,
                        side: const BorderSide(color: AppColors.accentRose),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ElevatedButton.icon(
                      key: Key('reserve_spot_btn_${game.id}'),
                      onPressed: () async {
                        final selectedDeck =
                            await SelectDeckForQueueSheet.show(context);
                        if (!context.mounted) return;

                        final entry = WaitlistQueueEntry(
                          userId: currentUserId,
                          username: profile?.username ?? '@guest_player',
                          displayName:
                              profile?.displayName ?? 'You (Commander)',
                          avatarUrl: profile?.avatarUrl,
                          deckId: selectedDeck?.id,
                          deckName: selectedDeck?.name,
                          commanderCardId: selectedDeck?.commanderCardId,
                          commanderName: selectedDeck?.commanderName,
                          commanderArtCropUrl: selectedDeck?.commanderArtCrop,
                          joinedAt: DateTime.now(),
                        );

                        ref.read(groupGamesProvider.notifier).reserveSpotInGame(
                              gameId: game.id,
                              entry: entry,
                            );

                        final newPos = game.waitlistCount + 1;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Spot reserved! You are #$newPos in line for ${game.title}',
                            ),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      icon: const Icon(Icons.queue_play_next_rounded, size: 16),
                      label: const Text('Reserve Spot in Next Game'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentCyan,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  key: Key('launch_tracker_btn_${game.id}'),
                  tooltip: 'Open Life Tracker',
                  icon: const Icon(Icons.play_arrow_rounded, size: 20),
                  onPressed: () {
                    // Seamlessly launch or rotate into Life Tracker
                    final podState = ref
                        .read(groupGamesProvider.notifier)
                        .getPodStateForGame(game.id);
                    if (podState != null) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PodScaffoldWidget(podState: podState),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
