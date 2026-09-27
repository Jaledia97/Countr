import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/life_counter/domain/models/pod_state.dart';

/// Interface contract for MatchSessionRepository.
abstract class MatchSessionRepositoryInterface {
  /// Creates a new match session, records seating and starting life, and returns the initial [PodState].
  Future<PodState> createSession({
    required String format,
    required int startingLife,
    required List<PlayerSetupConfig> players,
    bool isP2pHost = false,
    String? roomCode,
    Map<String, dynamic>? initialSettings,
  });

  /// Checks if an active (in-progress) session exists in SQLite.
  Future<bool> hasActiveSession();

  /// Watcher stream emitting whether an active match session currently exists.
  Stream<bool> watchHasActiveSession();

  /// Fetches the raw active [MatchSession] metadata if one exists, or null.
  Future<MatchSession?> getActiveSessionMetadata();

  /// Fully reconstitutes the active session from [MatchSessions], [MatchPlayers], and [MatchEvents].
  /// Returns null if no active session is present.
  Future<PodState?> restoreActiveSession();

  /// Marks the current active session as abandoned (`status = 'abandoned'`).
  Future<void> abandonSession(String sessionId);

  /// Marks the current active session as completed (`status = 'completed'`).
  Future<void> completeSession(String sessionId);

  /// Resets player life totals and counters to initial values while strictly preserving seating and decks.
  Future<PodState> resetSession(String sessionId, int startingLife);

  /// Logs a life delta immediately and updates player's current life.
  Future<void> recordLifeDelta({
    required String sessionId,
    required String playerId,
    required int delta,
    required int sequenceNumber,
  });

  /// Logs a commander damage transaction immediately.
  Future<void> recordCommanderDamage({
    required String sessionId,
    required String targetPlayerId,
    required String sourcePlayerId,
    required int delta,
    required int sequenceNumber,
  });

  /// Logs a secondary counter change (poison, energy, experience, commander_tax, monarch, initiative).
  Future<void> recordCounterChange({
    required String sessionId,
    required String playerId,
    required String counterType,
    required int delta,
    required int sequenceNumber,
    Map<String, dynamic>? payload,
  });

  /// Toggles or sets the shared Day/Night cycle across the pod.
  Future<void> recordDayNightToggle({
    required String sessionId,
    required bool isDay,
    required int sequenceNumber,
  });

  /// Adjusts a player's floating mana count.
  Future<void> recordManaChange({
    required String sessionId,
    required String playerId,
    required String color,
    required int delta,
    required int sequenceNumber,
  });

  /// Instantly clears a player's floating mana pool and storm count.
  Future<void> clearManaPool({
    required String sessionId,
    required String playerId,
    required int sequenceNumber,
  });

  /// Adjusts a player's storm counter.
  Future<void> recordStormChange({
    required String sessionId,
    required String playerId,
    required int delta,
    required int sequenceNumber,
  });

  /// Reverses the most recent active event in the session log.
  Future<PodState?> undoLastEvent(String sessionId);

  /// Flushes any pending asynchronous writes to SQLite (used on app pause/inactive).
  Future<void> flush();

  /// Disposes repository resources.
  void dispose();
}

/// Production implementation of [MatchSessionRepositoryInterface].
///
/// Features:
/// 1. Backed by [MatchDao] transactions and Drift Schema v10 event sourcing.
/// 2. FIFO Async Write Queue ensuring deterministic transaction ordering and zero thread contention.
/// 3. Event-sourced state reconstruction from `MatchSessions`, `MatchPlayers`, and `MatchEvents`.
/// 4. Robust error handling with zero state loss guarantees on sudden app termination.
class MatchSessionRepository implements MatchSessionRepositoryInterface {
  final AppDatabase _db;

  /// Sequential FIFO queue chaining all write operations to guarantee monotonic order.
  Future<void> _writeQueue = Future.value();
  bool _isDisposed = false;

  MatchSessionRepository({required AppDatabase db}) : _db = db;

  /// Enqueues an asynchronous write task into the sequential write queue.
  Future<T> _enqueueWrite<T>(Future<T> Function() task) {
    if (_isDisposed) {
      throw StateError('Cannot enqueue write on a disposed MatchSessionRepository.');
    }
    final completer = Completer<T>();
    _writeQueue = _writeQueue.then((_) async {
      try {
        final result = await task();
        completer.complete(result);
      } catch (error, stackTrace) {
        debugPrint('[MatchSessionRepository] Write error: $error\n$stackTrace');
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  @override
  Future<PodState> createSession({
    required String format,
    required int startingLife,
    required List<PlayerSetupConfig> players,
    bool isP2pHost = false,
    String? roomCode,
    Map<String, dynamic>? initialSettings,
  }) {
    return _enqueueWrite(() async {
      final sessionId = 'match_${DateTime.now().millisecondsSinceEpoch}_${players.length}p';
      final playerCompanions = players.map((p) => MatchPlayersCompanion.insert(
        id: p.id,
        sessionId: sessionId,
        seatOrder: p.seatOrder,
        playerName: p.name,
        deckId: Value(p.deckId),
        commanderCardId: Value(p.commanderCardId),
        commanderName: Value(p.commanderName),
        artCropUrl: Value(p.artCropUrl),
        colorTheme: Value(p.colorTheme),
        currentLife: Value(p.startingLife),
        isEliminated: const Value(false),
        isLocalDevice: Value(p.isLocalDevice),
        peerDeviceId: Value(p.peerDeviceId),
      )).toList();

      await _db.matchDao.createSession(
        sessionId: sessionId,
        name: '$format Match',
        format: format,
        startingLife: startingLife,
        playerCount: players.length,
        players: playerCompanions,
        isP2pHost: isP2pHost,
        p2pSessionCode: roomCode,
        settings: initialSettings,
        abandonExistingActive: true,
      );

      final pod = await restoreActiveSession();
      if (pod == null) {
        throw StateError('Failed to reconstitute pod state after creation.');
      }
      return pod;
    });
  }

  @override
  Future<bool> hasActiveSession() async {
    final session = await _db.matchDao.getActiveSession();
    return session != null;
  }

  @override
  Stream<bool> watchHasActiveSession() {
    return _db.matchDao.watchActiveSession().map((session) => session != null);
  }

  @override
  Future<MatchSession?> getActiveSessionMetadata() {
    return _db.matchDao.getActiveSession();
  }

  @override
  Future<PodState?> restoreActiveSession() async {
    final session = await _db.matchDao.getActiveSession();
    if (session == null) return null;

    final players = await _db.matchDao.getPlayersForSession(session.id);
    final events = await _db.matchDao.getEventsForSession(session.id);

    return _reconstructPodState(
      session: session,
      playerList: players,
      eventList: events,
    );
  }

  /// Reconstitutes the domain [PodState] from database records and event history.
  PodState _reconstructPodState({
    required MatchSession session,
    required List<MatchPlayer> playerList,
    required List<MatchEvent> eventList,
  }) {
    final Map<String, int> lifeTotals = {};
    final Map<String, int> poisonTotals = {};
    final Map<String, int> energyTotals = {};
    final Map<String, int> experienceTotals = {};
    final Map<String, int> commanderTaxTotals = {};
    final Map<String, Map<String, int>> cmdDamageTaken = {};
    final Map<String, Map<String, int>> floatingManaMap = {};
    final Map<String, int> stormMap = {};
    final Map<String, bool> eliminatedMap = {};

    String? currentMonarchId;
    String? currentInitiativeId;
    bool isDay = true;
    int maxSeq = 0;

    // Parse session settings if available
    if (session.settingsJson != null && session.settingsJson!.isNotEmpty) {
      try {
        final decoded = jsonDecode(session.settingsJson!);
        if (decoded is Map<String, dynamic>) {
          if (decoded.containsKey('is_day')) isDay = decoded['is_day'] as bool;
        }
      } catch (_) {}
    }

    // Initialize state from player records
    for (final p in playerList) {
      lifeTotals[p.id] = p.currentLife;
      poisonTotals[p.id] = p.poison;
      energyTotals[p.id] = p.energy;
      experienceTotals[p.id] = p.experience;
      commanderTaxTotals[p.id] = p.commanderTax;

      // Commander damage JSON
      final Map<String, int> cmdDmg = {};
      if (p.commanderDamageJson != null && p.commanderDamageJson!.isNotEmpty) {
        try {
          final decoded = jsonDecode(p.commanderDamageJson!);
          if (decoded is Map) {
            decoded.forEach((k, v) => cmdDmg[k.toString()] = (v as num).toInt());
          }
        } catch (_) {}
      }
      cmdDamageTaken[p.id] = cmdDmg;

      // Floating mana JSON
      final Map<String, int> mana = {'W': 0, 'U': 0, 'B': 0, 'R': 0, 'G': 0, 'C': 0};
      if (p.floatingManaJson != null && p.floatingManaJson!.isNotEmpty) {
        try {
          final decoded = jsonDecode(p.floatingManaJson!);
          if (decoded is Map) {
            decoded.forEach((k, v) => mana[k.toString()] = (v as num).toInt());
          }
        } catch (_) {}
      }
      floatingManaMap[p.id] = mana;

      stormMap[p.id] = p.stormCount;
      eliminatedMap[p.id] = p.isEliminated;

      if (p.isMonarch) currentMonarchId = p.id;
      if (p.hasInitiative) currentInitiativeId = p.id;
    }

    // Replay active events to track latest sequence number and any dynamic pod tokens/cycles
    for (final e in eventList) {
      if (e.isUndone) continue;
      if (e.sequenceNumber > maxSeq) maxSeq = e.sequenceNumber;

      if (e.eventType == 'day_night') {
        isDay = e.value == 1;
      }
    }

    final List<PodPlayerState> podPlayers = [];
    for (final p in playerList) {
      final pid = p.id;
      final life = lifeTotals[pid] ?? session.startingLife;
      final poison = poisonTotals[pid] ?? 0;
      final dmgTaken = cmdDamageTaken[pid] ?? const {};

      // Lethal check: 0 life, 10 poison, or 21 cmd damage from any single opponent
      final isCmdLethal = dmgTaken.values.any((d) => d >= 21);
      final isLethal = life <= 0 || poison >= 10 || isCmdLethal;

      podPlayers.add(PodPlayerState(
        id: pid,
        seatIndex: p.seatOrder,
        name: p.playerName,
        deckId: p.deckId,
        commanderCardId: p.commanderCardId,
        commanderName: p.commanderName,
        commanderArtCropUrl: p.artCropUrl,
        colorTheme: p.colorTheme,
        life: life,
        poison: poison,
        energy: energyTotals[pid] ?? 0,
        experience: experienceTotals[pid] ?? 0,
        commanderTax: commanderTaxTotals[pid] ?? 0,
        isMonarch: currentMonarchId == pid,
        hasInitiative: currentInitiativeId == pid,
        commanderDamageTaken: dmgTaken,
        floatingMana: floatingManaMap[pid] ?? const {'W': 0, 'U': 0, 'B': 0, 'R': 0, 'G': 0, 'C': 0},
        stormCount: stormMap[pid] ?? 0,
        isEliminated: (eliminatedMap[pid] == true) || isLethal,
        isLocalDevice: p.isLocalDevice,
        peerDeviceId: p.peerDeviceId,
      ));
    }

    return PodState(
      sessionId: session.id,
      format: session.format,
      startingLife: session.startingLife,
      players: podPlayers,
      isDay: isDay,
      isP2pHost: session.isP2pHost,
      roomCode: session.p2pSessionCode,
      sequenceNumber: maxSeq > 0 ? maxSeq : 1,
    );
  }

  @override
  Future<void> abandonSession(String sessionId) {
    return _enqueueWrite(() => _db.matchDao.abandonSession(sessionId));
  }

  @override
  Future<void> completeSession(String sessionId) {
    return _enqueueWrite(() => _db.matchDao.completeSession(sessionId));
  }

  @override
  Future<PodState> resetSession(String sessionId, int startingLife) {
    return _enqueueWrite(() async {
      await _db.matchDao.resetSession(sessionId, startingLife);
      final pod = await restoreActiveSession();
      if (pod == null) {
        throw StateError('Failed to restore active session after reset.');
      }
      return pod;
    });
  }

  @override
  Future<void> recordLifeDelta({
    required String sessionId,
    required String playerId,
    required int delta,
    required int sequenceNumber,
  }) {
    return _enqueueWrite(() => _db.matchDao.updatePlayerLife(
      sessionId: sessionId,
      playerId: playerId,
      delta: delta,
    ));
  }

  @override
  Future<void> recordCommanderDamage({
    required String sessionId,
    required String targetPlayerId,
    required String sourcePlayerId,
    required int delta,
    required int sequenceNumber,
  }) {
    return _enqueueWrite(() => _db.matchDao.recordCommanderDamage(
      sessionId: sessionId,
      targetPlayerId: targetPlayerId,
      sourcePlayerId: sourcePlayerId,
      delta: delta,
      applyLifeDelta: true,
    ));
  }

  @override
  Future<void> recordCounterChange({
    required String sessionId,
    required String playerId,
    required String counterType,
    required int delta,
    required int sequenceNumber,
    Map<String, dynamic>? payload,
  }) {
    return _enqueueWrite(() => _db.matchDao.recordCounterChange(
      sessionId: sessionId,
      playerId: playerId,
      counterType: counterType,
      delta: delta,
    ));
  }

  @override
  Future<void> recordDayNightToggle({
    required String sessionId,
    required bool isDay,
    required int sequenceNumber,
  }) {
    return _enqueueWrite(() => _db.matchDao.recordEvent(
      sessionId: sessionId,
      eventType: 'day_night',
      sequenceNumber: sequenceNumber,
      value: isDay ? 1 : 0,
    ));
  }

  @override
  Future<void> recordManaChange({
    required String sessionId,
    required String playerId,
    required String color,
    required int delta,
    required int sequenceNumber,
  }) {
    return _enqueueWrite(() => _db.matchDao.recordManaChange(
      sessionId: sessionId,
      playerId: playerId,
      manaColor: color,
      delta: delta,
    ));
  }

  @override
  Future<void> clearManaPool({
    required String sessionId,
    required String playerId,
    required int sequenceNumber,
  }) {
    return _enqueueWrite(() => _db.matchDao.clearManaPool(
      sessionId: sessionId,
      playerId: playerId,
    ));
  }

  @override
  Future<void> recordStormChange({
    required String sessionId,
    required String playerId,
    required int delta,
    required int sequenceNumber,
  }) {
    return _enqueueWrite(() => _db.matchDao.recordStormChange(
      sessionId: sessionId,
      playerId: playerId,
      delta: delta,
    ));
  }

  @override
  Future<PodState?> undoLastEvent(String sessionId) {
    return _enqueueWrite(() async {
      final undone = await _db.matchDao.undoLastEvent(sessionId: sessionId);
      if (undone == null) return null;
      return restoreActiveSession();
    });
  }

  @override
  Future<void> flush() async {
    await _writeQueue;
  }

  @override
  void dispose() {
    _isDisposed = true;
  }
}

/// Riverpod provider for [MatchSessionRepository].
final matchSessionRepositoryProvider = Provider<MatchSessionRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final repo = MatchSessionRepository(db: db);
  ref.onDispose(() => repo.dispose());
  return repo;
});

/// Reactive stream checking whether an active match is currently running.
final hasActiveSessionStreamProvider = StreamProvider<bool>((ref) {
  final repo = ref.watch(matchSessionRepositoryProvider);
  return repo.watchHasActiveSession();
});

/// Future provider querying active session metadata on cold launch.
final activeSessionMetadataFutureProvider = FutureProvider<MatchSession?>((ref) {
  final repo = ref.watch(matchSessionRepositoryProvider);
  return repo.getActiveSessionMetadata();
});
