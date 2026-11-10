// Copyright (c) 2026 Countr. All rights reserved.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../life_counter/domain/models/pod_state.dart';
import '../../domain/models/group_game_models.dart';

/// Seeded active group games for LGS EDH pods.
final _initialGroupGames = <GroupPodGame>[
  const GroupPodGame(
    id: 'game_tbs_table_1',
    title: 'TBS Comics Table 1',
    location: 'TBS Comics & Games - Pensacola',
    format: 'Commander',
    status: 'Game in Progress',
    maxSeats: 4,
    startingLife: 40,
    seatedPlayers: [
      PodPlayerState(
        id: 'user_marcus',
        seatIndex: 0,
        name: 'Marcus',
        commanderName: 'Edgar Markov',
        life: 34,
        colorTheme: 'vampire',
      ),
      PodPlayerState(
        id: 'user_sarah',
        seatIndex: 1,
        name: 'Sarah',
        commanderName: 'Atraxa, Praetors\' Voice',
        life: 28,
        colorTheme: 'phyrexian',
      ),
      PodPlayerState(
        id: 'user_dave',
        seatIndex: 2,
        name: 'Dave',
        commanderName: 'Urza, Lord High Artificer',
        life: 40,
        colorTheme: 'artifacts',
      ),
      PodPlayerState(
        id: 'user_chloe',
        seatIndex: 3,
        name: 'Chloe',
        commanderName: 'Yuriko, the Tiger\'s Shadow',
        life: 19,
        colorTheme: 'ninja',
      ),
    ],
    waitlistQueue: [],
  ),
  const GroupPodGame(
    id: 'game_emerald_coast_table_2',
    title: 'Emerald Coast EDH Table 2',
    location: 'Emerald Coast Games - FWB',
    format: 'Commander',
    status: 'Game in Progress',
    maxSeats: 4,
    startingLife: 40,
    seatedPlayers: [
      PodPlayerState(
        id: 'user_alex',
        seatIndex: 0,
        name: 'Alex',
        commanderName: 'Miirym, Sentinel Wyrm',
        life: 37,
        colorTheme: 'dragon',
      ),
      PodPlayerState(
        id: 'user_jordan',
        seatIndex: 1,
        name: 'Jordan',
        commanderName: 'Krenko, Mob Boss',
        life: 12,
        colorTheme: 'goblin',
      ),
      PodPlayerState(
        id: 'user_sam',
        seatIndex: 2,
        name: 'Sam',
        commanderName: 'Korvold, Fae-Cursed King',
        life: 40,
        colorTheme: 'jund',
      ),
      PodPlayerState(
        id: 'user_morgan',
        seatIndex: 3,
        name: 'Morgan',
        commanderName: 'Lathril, Blade of the Elves',
        life: 25,
        colorTheme: 'elf',
      ),
    ],
    waitlistQueue: [],
  ),
];

class GroupGamesNotifier extends StateNotifier<List<GroupPodGame>> {
  GroupGamesNotifier() : super(_initialGroupGames);

  /// Reserves a spot in the next game waitlist queue for a specific game pod.
  void reserveSpotInGame({
    required String gameId,
    required WaitlistQueueEntry entry,
  }) {
    state = [
      for (final game in state)
        if (game.id == gameId)
          if (game.isUserQueued(entry.userId))
            game
          else
            game.copyWith(
              waitlistQueue: [...game.waitlistQueue, entry],
            )
        else
          game,
    ];
  }

  /// Leaves the waitlist queue for a specific game pod.
  void leaveQueue({
    required String gameId,
    required String userId,
  }) {
    state = [
      for (final game in state)
        if (game.id == gameId)
          game.copyWith(
            waitlistQueue:
                game.waitlistQueue.where((e) => e.userId != userId).toList(),
          )
        else
          game,
    ];
  }

  /// Rotates the next waitlisted player into an active pod seat, resetting all
  /// seated players to starting life (40) and returns the resulting [PodState].
  PodState? rotateQueueIntoSeats(String gameId) {
    final gameIdx = state.indexWhere((g) => g.id == gameId);
    if (gameIdx < 0) return null;

    final game = state[gameIdx];
    if (game.waitlistQueue.isEmpty) {
      return getPodStateForGame(gameId);
    }

    final nextPlayer = game.waitlistQueue.first;
    final remainingQueue = game.waitlistQueue.sublist(1);

    // Find seat to replace (lowest life or first seat)
    int seatToReplace = 0;
    int lowestLife = 999999;
    for (int i = 0; i < game.seatedPlayers.length; i++) {
      if (game.seatedPlayers[i].life < lowestLife) {
        lowestLife = game.seatedPlayers[i].life;
        seatToReplace = i;
      }
    }

    final newPlayerState = PodPlayerState(
      id: nextPlayer.userId,
      seatIndex: seatToReplace,
      name: nextPlayer.displayName,
      deckId: nextPlayer.deckId,
      commanderCardId: nextPlayer.commanderCardId,
      commanderName: nextPlayer.commanderName,
      commanderArtCropUrl: nextPlayer.commanderArtCropUrl,
      life: game.startingLife,
      isLocalDevice: true,
    );

    final updatedPlayers = <PodPlayerState>[];
    for (int i = 0; i < game.seatedPlayers.length; i++) {
      if (i == seatToReplace) {
        updatedPlayers.add(newPlayerState);
      } else {
        // Reset life to starting life for the fresh game
        updatedPlayers.add(game.seatedPlayers[i].copyWith(
          life: game.startingLife,
          poison: 0,
          energy: 0,
          experience: 0,
          commanderTax: 0,
          radCounters: 0,
          stormCount: 0,
          isEliminated: false,
          commanderDamageTaken: const {},
          floatingMana: const {'W': 0, 'U': 0, 'B': 0, 'R': 0, 'G': 0, 'C': 0},
        ));
      }
    }

    final updatedGame = game.copyWith(
      seatedPlayers: updatedPlayers,
      waitlistQueue: remainingQueue,
      status: 'Game in Progress',
    );

    final newGames = List<GroupPodGame>.from(state);
    newGames[gameIdx] = updatedGame;
    state = newGames;

    return PodState(
      sessionId: 'session_${game.id}',
      format: game.format,
      startingLife: game.startingLife,
      players: updatedPlayers,
    );
  }

  /// Converts a group game into an active [PodState] for the Life Tracker.
  PodState? getPodStateForGame(String gameId) {
    final game = state.firstWhere(
      (g) => g.id == gameId,
      orElse: () => _initialGroupGames.first,
    );
    return PodState(
      sessionId: 'session_${game.id}',
      format: game.format,
      startingLife: game.startingLife,
      players: game.seatedPlayers,
    );
  }
}

final groupGamesProvider =
    StateNotifierProvider<GroupGamesNotifier, List<GroupPodGame>>((ref) {
  return GroupGamesNotifier();
});
