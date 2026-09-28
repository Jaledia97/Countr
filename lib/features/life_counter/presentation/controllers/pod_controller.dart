// Copyright (c) 2026 Countr. All rights reserved.

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:countr/features/life_counter/domain/models/pod_state.dart';
import 'package:countr/features/life_counter/data/repositories/match_session_repository.dart';
import 'package:countr/features/life_counter/data/network/p2p_sync_engine.dart';

/// Riverpod StateNotifier controlling the MTG Life Counter Pod state.
///
/// Features:
/// 1. Single source of truth unifying [PodState], SQLite [MatchSessionRepository]
///    continuous persistence, and local mesh [P2pSyncEngine].
/// 2. Commutative delta dispatch for Life, Commander Damage, Secondary Counters,
///    WUBRGC Mana Pools, Storm Count, Monarch/Initiative, and Day/Night cycle.
/// 3. Resilient event sourcing: immediate undo support restoring state from the DB ledger.
/// 4. Headless-ready: functions in offline standalone mode with zero network dependencies.
class PodController extends StateNotifier<PodState> {
  final MatchSessionRepositoryInterface? _repository;
  P2pSyncEngine? _syncEngine;

  PodController({
    required PodState initialState,
    MatchSessionRepositoryInterface? repository,
    P2pSyncEngine? syncEngine,
  })  : _repository = repository,
        _syncEngine = syncEngine,
        super(initialState) {
    _bindSyncEngine();
  }

  /// Connects the P2P sync engine listener to propagate mesh updates to UI state.
  void _bindSyncEngine() {
    if (_syncEngine != null) {
      _syncEngine!.onStateChanged = (newState) {
        if (mounted) {
          state = newState;
        }
      };
    }
  }

  /// Attaches or updates an active [P2pSyncEngine].
  void attachSyncEngine(P2pSyncEngine syncEngine) {
    _syncEngine?.dispose();
    _syncEngine = syncEngine;
    _bindSyncEngine();
  }

  // ===========================================================================
  // 1. PRIMARY LIFE ADJUSTMENT
  // ===========================================================================

  /// Adjusts life total for [playerId] by [delta].
  Future<void> adjustLife(String playerId, int delta) async {
    if (delta == 0) return;

    if (_syncEngine != null) {
      await _syncEngine!.sendLifeAdjustment(playerId, delta);
    } else {
      // Standalone local mode
      final nextSeq = state.sequenceNumber + 1;
      final updatedPlayers = state.players.map((p) {
        if (p.id == playerId) {
          final newLife = p.life + delta;
          final isCmdLethal = p.commanderDamageTaken.values.any((dmg) => dmg >= 21);
          final isEliminated = newLife <= 0 || p.isPoisonLethal || isCmdLethal;
          return p.copyWith(life: newLife, isEliminated: isEliminated);
        }
        return p;
      }).toList();

      state = state.copyWith(players: updatedPlayers, sequenceNumber: nextSeq);

      await _repository?.recordLifeDelta(
        sessionId: state.sessionId,
        playerId: playerId,
        delta: delta,
        sequenceNumber: nextSeq,
      );
    }
  }

  // ===========================================================================
  // 2. COMMANDER DAMAGE MATRIX
  // ===========================================================================

  /// Records incoming commander damage dealt by [sourcePlayerId] to [targetPlayerId].
  Future<void> recordCommanderDamage({
    required String targetPlayerId,
    required String sourcePlayerId,
    required int damageDelta,
  }) async {
    if (damageDelta == 0) return;

    if (_syncEngine != null) {
      await _syncEngine!.sendCommanderDamage(
        targetPlayerId: targetPlayerId,
        sourcePlayerId: sourcePlayerId,
        damageDelta: damageDelta,
      );
    } else {
      final nextSeq = state.sequenceNumber + 1;
      final updatedPlayers = state.players.map((p) {
        if (p.id == targetPlayerId) {
          final currentDmg = p.commanderDamageTaken[sourcePlayerId] ?? 0;
          final newDmg = math.max(0, currentDmg + damageDelta);
          final newMap = Map<String, int>.from(p.commanderDamageTaken);
          newMap[sourcePlayerId] = newDmg;

          final newLife = p.life - damageDelta;
          final isCmdLethal = newMap.values.any((d) => d >= 21);
          final isEliminated = newLife <= 0 || p.isPoisonLethal || isCmdLethal;

          return p.copyWith(
            life: newLife,
            commanderDamageTaken: newMap,
            isEliminated: isEliminated,
          );
        }
        return p;
      }).toList();

      state = state.copyWith(players: updatedPlayers, sequenceNumber: nextSeq);

      await _repository?.recordCommanderDamage(
        sessionId: state.sessionId,
        targetPlayerId: targetPlayerId,
        sourcePlayerId: sourcePlayerId,
        delta: damageDelta,
        sequenceNumber: nextSeq,
      );
    }
  }

  // ===========================================================================
  // 3. FLOATING MANA POOL & STORM (FEATURES 40 & 41)
  // ===========================================================================

  /// Modifies floating mana count for [color] ('W', 'U', 'B', 'R', 'G', 'C') for [playerId].
  Future<void> adjustMana({
    required String playerId,
    required String color,
    required int delta,
  }) async {
    if (delta == 0) return;

    if (_syncEngine != null) {
      await _syncEngine!.sendManaDelta(
        targetPlayerId: playerId,
        color: color,
        delta: delta,
      );
    } else {
      final nextSeq = state.sequenceNumber + 1;
      final updatedPlayers = state.players.map((p) {
        if (p.id == playerId) {
          final current = p.floatingMana[color] ?? 0;
          final newPool = Map<String, int>.from(p.floatingMana);
          newPool[color] = math.max(0, current + delta);
          final newStorm = delta > 0 ? p.stormCount + 1 : p.stormCount;
          return p.copyWith(floatingMana: newPool, stormCount: newStorm);
        }
        return p;
      }).toList();

      state = state.copyWith(players: updatedPlayers, sequenceNumber: nextSeq);

      await _repository?.recordManaChange(
        sessionId: state.sessionId,
        playerId: playerId,
        color: color,
        delta: delta,
        sequenceNumber: nextSeq,
      );
      if (delta > 0) {
        await _repository?.recordStormChange(
          sessionId: state.sessionId,
          playerId: playerId,
          delta: 1,
          sequenceNumber: nextSeq,
        );
      }
    }
  }

  /// One-Tap Clear Pool Action (Feature 41): instantly zeroes all 6 mana pools and storm count.
  Future<void> clearManaPool(String playerId) async {
    if (_syncEngine != null) {
      await _syncEngine!.sendManaClear(playerId);
    } else {
      final nextSeq = state.sequenceNumber + 1;
      final updatedPlayers = state.players.map((p) {
        if (p.id == playerId) {
          return p.copyWith(
            floatingMana: const {'W': 0, 'U': 0, 'B': 0, 'R': 0, 'G': 0, 'C': 0},
            stormCount: 0,
          );
        }
        return p;
      }).toList();

      state = state.copyWith(players: updatedPlayers, sequenceNumber: nextSeq);

      await _repository?.clearManaPool(
        sessionId: state.sessionId,
        playerId: playerId,
        sequenceNumber: nextSeq,
      );
    }
  }

  /// Modifies storm counter directly for [playerId] by [delta].
  Future<void> adjustStorm(String playerId, int delta) async {
    if (delta == 0) return;

    if (_syncEngine != null) {
      await _syncEngine!.sendCounterDelta(
        targetPlayerId: playerId,
        counterType: 'storm',
        delta: delta,
      );
    } else {
      final nextSeq = state.sequenceNumber + 1;
      final updatedPlayers = state.players.map((p) {
        if (p.id == playerId) {
          return p.copyWith(stormCount: math.max(0, p.stormCount + delta));
        }
        return p;
      }).toList();

      state = state.copyWith(players: updatedPlayers, sequenceNumber: nextSeq);

      await _repository?.recordStormChange(
        sessionId: state.sessionId,
        playerId: playerId,
        delta: delta,
        sequenceNumber: nextSeq,
      );
    }
  }

  // ===========================================================================
  // 4. SECONDARY COUNTERS & POD TOKENS
  // ===========================================================================

  /// Adjusts secondary counter (poison, energy, experience, commander_tax).
  Future<void> adjustCounter({
    required String playerId,
    required String counterType,
    required int delta,
  }) async {
    if (delta == 0) return;

    if (_syncEngine != null) {
      await _syncEngine!.sendCounterDelta(
        targetPlayerId: playerId,
        counterType: counterType,
        delta: delta,
      );
    } else {
      final nextSeq = state.sequenceNumber + 1;
      final updatedPlayers = state.players.map((p) {
        if (p.id == playerId) {
          switch (counterType.toLowerCase()) {
            case 'poison':
              final newPoison = math.max(0, p.poison + delta);
              final isCmdLethal = p.commanderDamageTaken.values.any((d) => d >= 21);
              final isEliminated = p.life <= 0 || newPoison >= 10 || isCmdLethal;
              return p.copyWith(poison: newPoison, isEliminated: isEliminated);
            case 'energy':
              return p.copyWith(energy: math.max(0, p.energy + delta));
            case 'experience':
            case 'xp':
              return p.copyWith(experience: math.max(0, p.experience + delta));
            case 'commander_tax':
            case 'commandertax':
              return p.copyWith(commanderTax: math.max(0, p.commanderTax + delta));
          }
        }
        return p;
      }).toList();

      state = state.copyWith(players: updatedPlayers, sequenceNumber: nextSeq);

      await _repository?.recordCounterChange(
        sessionId: state.sessionId,
        playerId: playerId,
        counterType: counterType,
        delta: delta,
        sequenceNumber: nextSeq,
      );
    }
  }

  /// Claims Monarch or Initiative pod-wide token atomically.
  Future<void> claimToken({
    required String tokenType,
    required String claimantId,
  }) async {
    if (_syncEngine != null) {
      await _syncEngine!.claimToken(
        tokenType: tokenType,
        claimantId: claimantId,
      );
    } else {
      final isMonarch = tokenType == 'monarch';
      final isInit = tokenType == 'initiative';

      final updatedPlayers = state.players.map((p) {
        if (p.id == claimantId) {
          return p.copyWith(
            isMonarch: isMonarch ? true : p.isMonarch,
            hasInitiative: isInit ? true : p.hasInitiative,
          );
        } else {
          return p.copyWith(
            isMonarch: isMonarch ? false : p.isMonarch,
            hasInitiative: isInit ? false : p.hasInitiative,
          );
        }
      }).toList();

      final nextSeq = state.sequenceNumber + 1;
      state = state.copyWith(players: updatedPlayers, sequenceNumber: nextSeq);

      await _repository?.recordCounterChange(
        sessionId: state.sessionId,
        playerId: claimantId,
        counterType: tokenType,
        delta: 1,
        sequenceNumber: nextSeq,
      );
    }
  }

  /// Toggles synchronized Day/Night cycle across all quadrants.
  Future<void> toggleDayNight() async {
    if (_syncEngine != null) {
      await _syncEngine!.toggleDayNight();
    } else {
      final newDay = !state.isDay;
      final nextSeq = state.sequenceNumber + 1;
      state = state.copyWith(isDay: newDay, sequenceNumber: nextSeq);

      await _repository?.recordDayNightToggle(
        sessionId: state.sessionId,
        isDay: newDay,
        sequenceNumber: nextSeq,
      );
    }
  }

  // ===========================================================================
  // 5. UNDO & GAME RESET ACTIONS
  // ===========================================================================

  /// Rolls back the most recent event transaction from SQLite event ledger.
  Future<bool> undo() async {
    if (_repository == null) return false;

    final restoredPod = await _repository!.undoLastEvent(state.sessionId);
    if (restoredPod != null) {
      state = restoredPod;
      if (_syncEngine != null && _syncEngine!.isHost) {
        await _syncEngine!.broadcastSyncState();
      }
      return true;
    }
    return false;
  }

  /// Resets life and counters to starting values while strictly preserving seating and decks.
  Future<void> resetGame([int? startingLifeOverride]) async {
    final startingLife = startingLifeOverride ?? state.startingLife;

    if (_syncEngine != null) {
      await _syncEngine!.resetGame(startingLife);
    } else {
      if (_repository != null) {
        final resetPod = await _repository!.resetSession(state.sessionId, startingLife);
        state = resetPod;
      } else {
        final resetPlayers = state.players.map((p) {
          return p.copyWith(
            life: startingLife,
            poison: 0,
            energy: 0,
            experience: 0,
            commanderTax: 0,
            isMonarch: false,
            hasInitiative: false,
            commanderDamageTaken: const {},
            floatingMana: const {'W': 0, 'U': 0, 'B': 0, 'R': 0, 'G': 0, 'C': 0},
            stormCount: 0,
            isEliminated: false,
          );
        }).toList();

        state = state.copyWith(
          startingLife: startingLife,
          players: resetPlayers,
          isDay: true,
          sequenceNumber: state.sequenceNumber + 1,
        );
      }
    }
  }

  // ===========================================================================
  // 6. UI CUSTOMIZATION & OVERRIDES
  // ===========================================================================

  /// Overrides quadrant background art with selected Scryfall card art.
  void overrideCommanderArt(String playerId, String artCropUrl) {
    final updated = state.players.map((p) {
      if (p.id == playerId) {
        return p.copyWith(commanderArtCropUrl: artCropUrl);
      }
      return p;
    }).toList();
    state = state.copyWith(players: updated);
  }

  /// Toggles manual elimination override (e.g. conceding / reviving).
  void toggleEliminated(String playerId) {
    final updated = state.players.map((p) {
      if (p.id == playerId) {
        return p.copyWith(isEliminated: !p.isEliminated);
      }
      return p;
    }).toList();
    state = state.copyWith(players: updated);
  }

  // ===========================================================================
  // 7. SESSION LIFECYCLE MANAGEMENT
  // ===========================================================================

  /// Creates a new match session and updates state.
  Future<void> createNewSession({
    required String format,
    required int startingLife,
    required List<PlayerSetupConfig> players,
    bool isP2pHost = false,
    String? roomCode,
  }) async {
    if (_repository != null) {
      final newPod = await _repository!.createSession(
        format: format,
        startingLife: startingLife,
        players: players,
        isP2pHost: isP2pHost,
        roomCode: roomCode,
      );
      state = newPod;
    }
  }

  /// Restores active match session from SQLite.
  Future<bool> restoreActiveSession() async {
    if (_repository == null) return false;
    final activePod = await _repository!.restoreActiveSession();
    if (activePod != null) {
      state = activePod;
      return true;
    }
    return false;
  }

  /// Completes session.
  Future<void> completeSession() async {
    await _repository?.completeSession(state.sessionId);
  }

  /// Abandons session.
  Future<void> abandonSession() async {
    await _repository?.abandonSession(state.sessionId);
  }

  /// Directly synchronizes or sets the active in-memory pod state.
  void setPodState(PodState newState) {
    state = newState;
  }

  @override
  void dispose() {
    _syncEngine?.dispose();
    super.dispose();
  }
}

// =============================================================================
// RIVERPOD PROVIDERS
// =============================================================================

/// Global Riverpod StateNotifierProvider for [PodController].
final podControllerProvider =
    StateNotifierProvider<PodController, PodState>((ref) {
  final repository = ref.watch(matchSessionRepositoryProvider);

  const defaultInitialState = PodState(
    sessionId: 'initial_session',
    format: 'commander',
    startingLife: 40,
    players: [
      PodPlayerState(id: 'p1', seatIndex: 0, name: 'Player 1', life: 40),
      PodPlayerState(id: 'p2', seatIndex: 1, name: 'Player 2', life: 40),
      PodPlayerState(id: 'p3', seatIndex: 2, name: 'Player 3', life: 40),
      PodPlayerState(id: 'p4', seatIndex: 3, name: 'Player 4', life: 40),
    ],
  );

  return PodController(
    initialState: defaultInitialState,
    repository: repository,
  );
});

/// Selector provider exposing the list of players.
final podPlayersProvider = Provider<List<PodPlayerState>>((ref) {
  return ref.watch(podControllerProvider.select((s) => s.players));
});

/// Family selector provider watching an individual player by ID.
final podPlayerProvider =
    Provider.family<PodPlayerState?, String>((ref, playerId) {
  return ref.watch(
    podControllerProvider.select((s) => s.getPlayer(playerId)),
  );
});

/// Selector provider for Day/Night state.
final podIsDayProvider = Provider<bool>((ref) {
  return ref.watch(podControllerProvider.select((s) => s.isDay));
});
