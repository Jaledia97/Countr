// Copyright (c) 2026 Countr. All rights reserved.

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:countr/features/life_counter/domain/models/pod_state.dart';
import 'package:countr/features/life_counter/domain/models/game_history_entry.dart';
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
  // 1. PRIMARY LIFE ADJUSTMENT & HISTORY COMMIT
  // ===========================================================================

  /// Game action history log.
  List<GameHistoryEntry> get gameHistory => state.gameHistory;

  /// Consolidates and commits a life change history entry after 1500ms inactivity.
  void commitLifeHistory({
    required String playerId,
    required int startLife,
    required int endLife,
    required int netDelta,
  }) {
    if (netDelta == 0) return;
    final player = state.getPlayer(playerId);
    final playerName = player?.name ?? 'Player';
    final entry = GameHistoryEntry.lifeChange(
      playerId: playerId,
      playerName: playerName,
      playerColor: player?.colorTheme,
      startLife: startLife,
      endLife: endLife,
      netDelta: netDelta,
    );
    addGameHistoryEntry(entry);
  }

  /// Appends a new game history log entry.
  void addGameHistoryEntry(GameHistoryEntry entry) {
    final nextSeq = state.sequenceNumber + 1;
    state = state.copyWith(
      gameHistory: [entry, ...state.gameHistory],
      sequenceNumber: nextSeq,
    );
  }

  /// Clears the turn log / game history.
  void clearGameHistory() {
    final nextSeq = state.sequenceNumber + 1;
    state = state.copyWith(
      gameHistory: const [],
      sequenceNumber: nextSeq,
    );
  }

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
          final isLethal = newLife <= 0 || p.isPoisonLethal || isCmdLethal;
          final isEliminated =
              state.autoKo ? (isLethal ? !p.isKoIgnored : false) : p.isEliminated;
          final isKoIgnored = isLethal ? p.isKoIgnored : false;
          return p.copyWith(
            life: newLife,
            isEliminated: isEliminated,
            isKoIgnored: isKoIgnored,
          );
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

  /// Toggles whether commander damage simultaneously causes player life loss.
  void toggleCommanderDamageLifeLoss([bool? value]) {
    final newValue = value ?? !state.commanderDamageLifeLoss;
    state = state.copyWith(commanderDamageLifeLoss: newValue);
  }

  /// Toggles whether spatial commander mini-grid cells are tinted to opponent colors.
  void toggleColorizeCommanderMiniGrids([bool? value]) {
    final newValue = value ?? !state.colorizeCommanderMiniGrids;
    state = state.copyWith(colorizeCommanderMiniGrids: newValue);
  }

  /// Sets automated knockout detection toggle.
  void setAutoKo(bool value) {
    state = state.copyWith(autoKo: value);
  }

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
          final actualDelta = newDmg - currentDmg;
          final newMap = Map<String, int>.from(p.commanderDamageTaken);
          newMap[sourcePlayerId] = newDmg;

          final newLife = state.commanderDamageLifeLoss
              ? p.life - actualDelta
              : p.life;
          final isCmdLethal = newMap.values.any((d) => d >= 21);
          final isLethal = newLife <= 0 || p.isPoisonLethal || isCmdLethal;
          final isEliminated =
              state.autoKo ? (isLethal ? !p.isKoIgnored : false) : p.isEliminated;
          final isKoIgnored = isLethal ? p.isKoIgnored : false;

          return p.copyWith(
            life: newLife,
            commanderDamageTaken: newMap,
            isEliminated: isEliminated,
            isKoIgnored: isKoIgnored,
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

  /// Adjusts secondary counter (poison, energy, experience, commander_tax, rad).
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
              final isLethal = p.life <= 0 || newPoison >= 10 || isCmdLethal;
              final isEliminated =
                  state.autoKo ? (isLethal ? !p.isKoIgnored : false) : p.isEliminated;
              final isKoIgnored = isLethal ? p.isKoIgnored : false;
              return p.copyWith(
                poison: newPoison,
                isEliminated: isEliminated,
                isKoIgnored: isKoIgnored,
              );
            case 'energy':
              return p.copyWith(energy: math.max(0, p.energy + delta));
            case 'experience':
            case 'xp':
              return p.copyWith(experience: math.max(0, p.experience + delta));
            case 'commander_tax':
            case 'commandertax':
              return p.copyWith(commanderTax: math.max(0, p.commanderTax + delta));
            case 'rad':
            case 'rad_counters':
            case 'radcounters':
            case 'radiation':
              return p.copyWith(radCounters: math.max(0, p.radCounters + delta));
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

  /// Claims or toggles Monarch or Initiative pod-wide token atomically.
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
      final claimant = state.getPlayer(claimantId);
      final willHaveMonarch = isMonarch ? !(claimant?.isMonarch ?? false) : false;
      final willHaveInit = isInit ? !(claimant?.hasInitiative ?? false) : false;

      final updatedPlayers = state.players.map((p) {
        if (p.id == claimantId) {
          return p.copyWith(
            isMonarch: isMonarch ? willHaveMonarch : p.isMonarch,
            hasInitiative: isInit ? willHaveInit : p.hasInitiative,
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
            radCounters: 0,
            isMonarch: false,
            hasInitiative: false,
            commanderDamageTaken: const {},
            floatingMana: const {'W': 0, 'U': 0, 'B': 0, 'R': 0, 'G': 0, 'C': 0},
            stormCount: 0,
            isEliminated: false,
            isKoIgnored: false,
          );
        }).toList();

        state = state.copyWith(
          startingLife: startingLife,
          players: resetPlayers,
          isDay: true,
          gameHistory: const [],
          sequenceNumber: state.sequenceNumber + 1,
        );
      }
    }
  }

  /// Shuffles player seating positions around the table while strictly preserving
  /// each player's name, color, and linked deck attached to them.
  void randomizeSeats() {
    final shuffled = List<PodPlayerState>.from(state.players)..shuffle();
    final reindexed = [
      for (int i = 0; i < shuffled.length; i++)
        shuffled[i].copyWith(seatIndex: i)
    ];
    state = state.copyWith(
      players: reindexed,
      sequenceNumber: state.sequenceNumber + 1,
    );
  }

  /// Resets game to starting life/zeroes counters AND shuffles player seating positions.
  Future<void> resetAndRandomizeSeats([int? startingLifeOverride]) async {
    await resetGame(startingLifeOverride);
    randomizeSeats();
  }

  /// Resets custom player names, colors, and linked decks back to defaults
  /// ('Player 1', 'Player 2', etc.) while preserving current life and counters.
  void clearProfiles() {
    final cleared = [
      for (int i = 0; i < state.players.length; i++)
        PodPlayerState(
          id: state.players[i].id,
          seatIndex: state.players[i].seatIndex,
          name: 'Player ${i + 1}',
          deckId: null,
          commanderCardId: null,
          commanderName: null,
          commanderArtCropUrl: null,
          colorTheme: null,
          life: state.players[i].life,
          poison: state.players[i].poison,
          energy: state.players[i].energy,
          experience: state.players[i].experience,
          commanderTax: state.players[i].commanderTax,
          radCounters: state.players[i].radCounters,
          isMonarch: state.players[i].isMonarch,
          hasInitiative: state.players[i].hasInitiative,
          commanderDamageTaken: state.players[i].commanderDamageTaken,
          floatingMana: state.players[i].floatingMana,
          stormCount: state.players[i].stormCount,
          isEliminated: state.players[i].isEliminated,
          isKoIgnored: state.players[i].isKoIgnored,
          isLocalDevice: state.players[i].isLocalDevice,
          peerDeviceId: state.players[i].peerDeviceId,
        )
    ];
    state = state.copyWith(
      players: cleared,
      sequenceNumber: state.sequenceNumber + 1,
    );
  }

  /// Resets game to starting life/zeroes counters AND resets player profiles back to defaults.
  Future<void> resetAndClearProfiles([int? startingLifeOverride]) async {
    final startingLife = startingLifeOverride ?? state.startingLife;
    final cleared = [
      for (int i = 0; i < state.players.length; i++)
        PodPlayerState(
          id: state.players[i].id,
          seatIndex: state.players[i].seatIndex,
          name: 'Player ${i + 1}',
          deckId: null,
          commanderCardId: null,
          commanderName: null,
          commanderArtCropUrl: null,
          colorTheme: null,
          life: startingLife,
          poison: 0,
          energy: 0,
          experience: 0,
          commanderTax: 0,
          radCounters: 0,
          isMonarch: false,
          hasInitiative: false,
          commanderDamageTaken: const {},
          floatingMana: const {'W': 0, 'U': 0, 'B': 0, 'R': 0, 'G': 0, 'C': 0},
          stormCount: 0,
          isEliminated: false,
          isKoIgnored: false,
          isLocalDevice: state.players[i].isLocalDevice,
          peerDeviceId: state.players[i].peerDeviceId,
        )
    ];
    state = state.copyWith(
      startingLife: startingLife,
      players: cleared,
      isDay: true,
      gameHistory: const [],
      sequenceNumber: state.sequenceNumber + 1,
    );
  }

  // ===========================================================================
  // 6. UI CUSTOMIZATION, AUTO-KO OVERRIDES & PROFILES
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

  /// Manually overrides / ignores automated knockout for [playerId].
  void ignoreKo(String playerId) {
    final nextSeq = state.sequenceNumber + 1;
    final updated = state.players.map((p) {
      if (p.id == playerId) {
        return p.copyWith(isKoIgnored: true, isEliminated: false);
      }
      return p;
    }).toList();
    state = state.copyWith(players: updated, sequenceNumber: nextSeq);
  }

  /// Updates profile metadata (name, colorTheme, deckId, commanderName, commanderArtCropUrl).
  void updatePlayerProfile(
    String playerId, {
    String? name,
    String? colorTheme,
    String? deckId,
    String? commanderName,
    String? commanderArtCropUrl,
  }) {
    final nextSeq = state.sequenceNumber + 1;
    final updated = state.players.map((p) {
      if (p.id == playerId) {
        return p.copyWith(
          name: name ?? p.name,
          colorTheme: colorTheme ?? p.colorTheme,
          deckId: deckId ?? p.deckId,
          commanderName: commanderName ?? p.commanderName,
          commanderArtCropUrl: commanderArtCropUrl ?? p.commanderArtCropUrl,
        );
      }
      return p;
    }).toList();
    state = state.copyWith(players: updated, sequenceNumber: nextSeq);
  }

  /// Links a saved Vault deck to [playerId].
  void linkDeck(
    String playerId, {
    required String deckId,
    required String deckName,
    String? commanderName,
    String? commanderArtCropUrl,
    String? colorIdentity,
  }) {
    final nextSeq = state.sequenceNumber + 1;
    final updated = state.players.map((p) {
      if (p.id == playerId) {
        final updatedName = (p.name.startsWith('Player ') || p.name.isEmpty)
            ? deckName
            : p.name;
        return p.copyWith(
          deckId: deckId,
          commanderName: commanderName ?? deckName,
          commanderArtCropUrl: commanderArtCropUrl ?? p.commanderArtCropUrl,
          name: updatedName,
          colorTheme: colorIdentity ?? p.colorTheme,
        );
      }
      return p;
    }).toList();
    state = state.copyWith(players: updated, sequenceNumber: nextSeq);
  }

  /// Unlinks any saved deck from [playerId], clearing deck and art references.
  void unlinkDeck(String playerId) {
    final nextSeq = state.sequenceNumber + 1;
    final updated = state.players.map((p) {
      if (p.id == playerId) {
        return PodPlayerState(
          id: p.id,
          seatIndex: p.seatIndex,
          name: p.name,
          deckId: null,
          commanderCardId: null,
          commanderName: null,
          commanderArtCropUrl: null,
          colorTheme: p.colorTheme,
          life: p.life,
          poison: p.poison,
          energy: p.energy,
          experience: p.experience,
          commanderTax: p.commanderTax,
          radCounters: p.radCounters,
          isMonarch: p.isMonarch,
          hasInitiative: p.hasInitiative,
          commanderDamageTaken: p.commanderDamageTaken,
          floatingMana: p.floatingMana,
          stormCount: p.stormCount,
          isEliminated: p.isEliminated,
          isKoIgnored: p.isKoIgnored,
          isLocalDevice: p.isLocalDevice,
          peerDeviceId: p.peerDeviceId,
        );
      }
      return p;
    }).toList();
    state = state.copyWith(players: updated, sequenceNumber: nextSeq);
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

  /// Updates the player card layout density setting (R4.2).
  void setCardDensity(String density) {
    state = state.copyWith(cardDensity: density);
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

/// Selector provider for Commander Damage Life Loss setting.
final podCommanderDamageLifeLossProvider = Provider<bool>((ref) {
  return ref.watch(podControllerProvider.select((s) => s.commanderDamageLifeLoss));
});

/// Selector provider for Commander Mini-Grid Colorization setting.
final podColorizeCommanderMiniGridsProvider = Provider<bool>((ref) {
  return ref.watch(podControllerProvider.select((s) => s.colorizeCommanderMiniGrids));
});

/// Selector provider for Auto-KO setting.
final podAutoKoProvider = Provider<bool>((ref) {
  return ref.watch(podControllerProvider.select((s) => s.autoKo));
});

/// Selector provider for Game Action History turn log.
final podGameHistoryProvider = Provider<List<GameHistoryEntry>>((ref) {
  return ref.watch(podControllerProvider.select((s) => s.gameHistory));
});

/// Selector provider for card density.
final podCardDensityProvider = Provider<String>((ref) {
  return ref.watch(podControllerProvider.select((s) => s.cardDensity));
});
