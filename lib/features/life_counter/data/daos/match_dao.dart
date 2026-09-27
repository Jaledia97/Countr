import 'dart:convert';
import 'dart:math' as math;
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/database/tables/matches/match_sessions_table.dart';
import 'package:countr/core/database/tables/matches/match_players_table.dart';
import 'package:countr/core/database/tables/matches/match_events_table.dart';
import 'package:countr/core/database/tables/sync_queue_table.dart';

part 'match_dao.g.dart';

/// Data Access Object interface for MTG Match Sessions, Players, and Event Sourcing.
abstract class MatchDaoInterface {
  Future<String> createSession({
    String? sessionId,
    String name,
    required String format,
    required int startingLife,
    required int playerCount,
    required List<MatchPlayersCompanion> players,
    bool isP2pHost,
    String? p2pSessionCode,
    Map<String, dynamic>? settings,
    bool abandonExistingActive,
  });

  Stream<MatchSession?> watchActiveSession();
  Future<MatchSession?> getActiveSession();
  Stream<MatchSession?> watchSessionById(String sessionId);
  Future<MatchSession?> getSessionById(String sessionId);
  Stream<List<MatchPlayer>> watchPlayersForSession(String sessionId);
  Future<List<MatchPlayer>> getPlayersForSession(String sessionId);
  Future<MatchPlayer?> getPlayerById(String playerId);

  Stream<List<MatchEvent>> watchEventsForSession(
    String sessionId, {
    int? sinceSequenceNumber,
    int? limit,
  });

  Future<List<MatchEvent>> getEventsForSession(
    String sessionId, {
    int? sinceSequenceNumber,
    int? limit,
  });

  Future<void> updatePlayerLife({
    required String sessionId,
    required String playerId,
    required int delta,
    String? sourcePlayerId,
    String? note,
  });

  Future<void> recordCommanderDamage({
    required String sessionId,
    required String targetPlayerId,
    required String sourcePlayerId,
    required int delta,
    bool applyLifeDelta,
    String? commanderName,
  });

  Future<void> recordCounterChange({
    required String sessionId,
    required String playerId,
    required String counterType,
    required int delta,
    int? absoluteValue,
  });

  Future<void> updatePlayerCounter(String playerId, String counterType, int newValue);

  Future<void> recordManaChange({
    required String sessionId,
    required String playerId,
    required String manaColor,
    required int delta,
  });

  Future<void> recordStormChange({
    required String sessionId,
    required String playerId,
    required int delta,
  });

  Future<void> clearManaPool({
    required String sessionId,
    required String playerId,
  });

  Future<void> resetSession(String sessionId, [int? startingLifeOverride]);

  Future<void> recordEvent({
    required String sessionId,
    required String eventType,
    required int sequenceNumber,
    String? targetPlayerId,
    String? sourcePlayerId,
    int delta,
    int value,
    Map<String, dynamic>? payload,
  });

  Future<MatchEvent?> undoLastEvent({
    required String sessionId,
    String? playerId,
  });

  Future<void> completeSession(String sessionId);
  Future<void> abandonSession(String sessionId);
  Future<void> softDeleteSession(String sessionId);
  Future<Map<String, Map<String, dynamic>>> reconstructStateFromEvents(String sessionId);
}

/// Data Access Object for MTG Match Sessions, Players, and Event Sourcing.
///
/// Handles session lifecycle, reactive watchers, and atomic event-sourced
/// transactions for life deltas, commander damage, secondary counters, and mana pools.
@DriftAccessor(tables: [
  MatchSessions,
  MatchPlayers,
  MatchEvents,
  SyncQueue,
])
class MatchDao extends DatabaseAccessor<AppDatabase>
    with _$MatchDaoMixin
    implements MatchDaoInterface {
  MatchDao(super.db);

  // ===========================================================================
  // OUTBOX SYNC QUEUE HELPER
  // ===========================================================================

  /// Records an operation to the SyncQueue outbox table for cloud and mesh synchronization.
  Future<void> _recordSync(
    String entityType,
    String entityId,
    String operation, {
    DateTime? timestamp,
  }) async {
    final now = timestamp ?? DateTime.now();
    await into(syncQueue).insert(
      SyncQueueCompanion.insert(
        id: const Uuid().v4(),
        entityType: entityType,
        entityId: entityId,
        operation: operation,
        timestamp: now,
        retryCount: const Value(0),
      ),
    );
  }

  // ===========================================================================
  // MONOTONIC SEQUENCE NUMBER GENERATOR
  // ===========================================================================

  /// Retrieves the next strictly monotonic sequence number for a given session.
  /// Must be invoked within an active SQLite transaction to prevent race conditions.
  Future<int> _getNextSequenceNumber(String sessionId) async {
    final maxQuery = selectOnly(matchEvents)
      ..addColumns([matchEvents.sequenceNumber.max()])
      ..where(matchEvents.sessionId.equals(sessionId));
    final row = await maxQuery.getSingle();
    final maxSeq = row.read(matchEvents.sequenceNumber.max());
    return (maxSeq ?? 0) + 1;
  }

  // ===========================================================================
  // ELIMINATION & DAMAGE HELPERS
  // ===========================================================================

  /// Safely decodes a commander damage JSON string into a Map of sourcePlayerId -> damage.
  Map<String, int> _decodeCommanderDamage(String? commanderDamageJson) {
    if (commanderDamageJson == null || commanderDamageJson.isEmpty) {
      return {};
    }
    try {
      final decoded = jsonDecode(commanderDamageJson);
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
      }
    } catch (_) {}
    return {};
  }

  /// Evaluates whether a player is eliminated under MTG Commander rules:
  /// 1. Life total <= 0
  /// 2. Poison counters >= 10
  /// 3. Commander damage from any single opposing commander >= 21
  bool _calculateIsEliminated({
    required int life,
    required int poison,
    required Map<String, int> commanderDamage,
  }) {
    final anyCommanderLethal = commanderDamage.values.any((dmg) => dmg >= 21);
    return life <= 0 || poison >= 10 || anyCommanderLethal;
  }

  // ===========================================================================
  // REACTIVE STREAM WATCHERS & READ QUERIES
  // ===========================================================================

  @override
  Stream<MatchSession?> watchActiveSession() {
    return (select(matchSessions)
          ..where((t) =>
              t.status.equals('active') &
              t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)])
          ..limit(1))
        .watchSingleOrNull();
  }

  @override
  Future<MatchSession?> getActiveSession() {
    return (select(matchSessions)
          ..where((t) =>
              t.status.equals('active') &
              t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)])
          ..limit(1))
        .getSingleOrNull();
  }

  @override
  Stream<MatchSession?> watchSessionById(String sessionId) {
    return (select(matchSessions)
          ..where((t) =>
              t.id.equals(sessionId) &
              t.isDeleted.equals(false)))
        .watchSingleOrNull();
  }

  @override
  Future<MatchSession?> getSessionById(String sessionId) {
    return (select(matchSessions)
          ..where((t) =>
              t.id.equals(sessionId) &
              t.isDeleted.equals(false)))
        .getSingleOrNull();
  }

  @override
  Stream<List<MatchPlayer>> watchPlayersForSession(String sessionId) {
    return (select(matchPlayers)
          ..where((t) =>
              t.sessionId.equals(sessionId) &
              t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm(expression: t.seatOrder, mode: OrderingMode.asc)]))
        .watch();
  }

  @override
  Future<List<MatchPlayer>> getPlayersForSession(String sessionId) {
    return (select(matchPlayers)
          ..where((t) =>
              t.sessionId.equals(sessionId) &
              t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm(expression: t.seatOrder, mode: OrderingMode.asc)]))
        .get();
  }

  @override
  Future<MatchPlayer?> getPlayerById(String playerId) {
    return (select(matchPlayers)
          ..where((t) =>
              t.id.equals(playerId) &
              t.isDeleted.equals(false)))
        .getSingleOrNull();
  }

  @override
  Stream<List<MatchEvent>> watchEventsForSession(
    String sessionId, {
    int? sinceSequenceNumber,
    int? limit,
  }) {
    var query = select(matchEvents)
      ..where((t) =>
          t.sessionId.equals(sessionId) &
          t.isDeleted.equals(false));
    if (sinceSequenceNumber != null) {
      query = query..where((t) => t.sequenceNumber.isBiggerThanValue(sinceSequenceNumber));
    }
    query = query..orderBy([(t) => OrderingTerm(expression: t.sequenceNumber, mode: OrderingMode.asc)]);
    if (limit != null) {
      query = query..limit(limit);
    }
    return query.watch();
  }

  @override
  Future<List<MatchEvent>> getEventsForSession(
    String sessionId, {
    int? sinceSequenceNumber,
    int? limit,
  }) {
    var query = select(matchEvents)
      ..where((t) =>
          t.sessionId.equals(sessionId) &
          t.isDeleted.equals(false));
    if (sinceSequenceNumber != null) {
      query = query..where((t) => t.sequenceNumber.isBiggerThanValue(sinceSequenceNumber));
    }
    query = query..orderBy([(t) => OrderingTerm(expression: t.sequenceNumber, mode: OrderingMode.asc)]);
    if (limit != null) {
      query = query..limit(limit);
    }
    return query.get();
  }

  // ===========================================================================
  // ATOMIC TRANSACTIONS
  // ===========================================================================

  @override
  Future<String> createSession({
    String? sessionId,
    String name = 'MTG Match',
    required String format,
    required int startingLife,
    required int playerCount,
    required List<MatchPlayersCompanion> players,
    bool isP2pHost = false,
    String? p2pSessionCode,
    Map<String, dynamic>? settings,
    bool abandonExistingActive = true,
  }) async {
    return transaction(() async {
      final now = DateTime.now();
      final effectiveSessionId = sessionId ?? const Uuid().v4();

      // 1. Mark existing active session as abandoned if requested
      if (abandonExistingActive) {
        final activeSessions = await (select(matchSessions)
              ..where((t) =>
                  t.status.equals('active') &
                  t.isDeleted.equals(false)))
            .get();
        for (final active in activeSessions) {
          await (update(matchSessions)..where((t) => t.id.equals(active.id))).write(
            MatchSessionsCompanion(
              status: const Value('abandoned'),
              endedAt: Value(now),
              updatedAt: Value(now),
            ),
          );
          await _recordSync('match_session', active.id, 'UPDATE', timestamp: now);
        }
      }

      // 2. Insert match session record
      await into(matchSessions).insert(
        MatchSessionsCompanion.insert(
          id: effectiveSessionId,
          name: Value(name),
          format: Value(format),
          startingLife: Value(startingLife),
          playerCount: Value(playerCount),
          status: const Value('active'),
          createdAt: now,
          isP2pHost: Value(isP2pHost),
          p2pSessionCode: Value(p2pSessionCode),
          settingsJson: Value(settings != null ? jsonEncode(settings) : null),
          isDeleted: const Value(false),
          updatedAt: Value(now),
        ),
      );
      await _recordSync('match_session', effectiveSessionId, 'INSERT', timestamp: now);

      // 3. Insert each player
      for (var i = 0; i < players.length; i++) {
        final playerComp = players[i];
        final playerId = playerComp.id.present ? playerComp.id.value : const Uuid().v4();
        final finalComp = playerComp.copyWith(
          id: Value(playerId),
          sessionId: Value(effectiveSessionId),
          seatOrder: playerComp.seatOrder.present ? playerComp.seatOrder : Value(i),
          currentLife: playerComp.currentLife.present ? playerComp.currentLife : Value(startingLife),
          isDeleted: const Value(false),
          updatedAt: Value(now),
        );
        await into(matchPlayers).insert(finalComp);
        await _recordSync('match_player', playerId, 'INSERT', timestamp: now);
      }

      // 4. Log initial 'session_created' event
      final eventId = const Uuid().v4();
      final firstPlayerId = players.isNotEmpty && players.first.id.present
          ? players.first.id.value
          : effectiveSessionId;

      await into(matchEvents).insert(
        MatchEventsCompanion.insert(
          id: eventId,
          sessionId: effectiveSessionId,
          playerId: firstPlayerId,
          eventType: 'session_created',
          delta: const Value(0),
          value: Value(startingLife),
          sequenceNumber: const Value(1),
          payloadJson: Value(jsonEncode({
            'format': format,
            'starting_life': startingLife,
            'player_count': playerCount,
            'is_p2p_host': isP2pHost,
          })),
          timestamp: now,
          isUndone: const Value(false),
          isDeleted: const Value(false),
          updatedAt: Value(now),
        ),
      );
      await _recordSync('match_event', eventId, 'INSERT', timestamp: now);

      return effectiveSessionId;
    });
  }

  @override
  Future<void> updatePlayerLife({
    required String sessionId,
    required String playerId,
    required int delta,
    String? sourcePlayerId,
    String? note,
  }) async {
    return transaction(() async {
      final now = DateTime.now();

      final player = await (select(matchPlayers)
            ..where((t) =>
                t.id.equals(playerId) &
                t.sessionId.equals(sessionId) &
                t.isDeleted.equals(false)))
          .getSingleOrNull();

      if (player == null) {
        throw ArgumentError('Player $playerId not found in session $sessionId');
      }

      final newLife = player.currentLife + delta;
      final isEliminated = newLife <= 0;
      final shouldMarkEliminated = isEliminated && !player.isEliminated;

      // 1. Update player row
      await (update(matchPlayers)..where((t) => t.id.equals(playerId))).write(
        MatchPlayersCompanion(
          currentLife: Value(newLife),
          isEliminated: shouldMarkEliminated ? const Value(true) : Value(player.isEliminated),
          eliminatedAt: shouldMarkEliminated ? Value(now) : Value(player.eliminatedAt),
          updatedAt: Value(now),
        ),
      );
      await _recordSync('match_player', playerId, 'UPDATE', timestamp: now);

      // 2. Append event
      final nextSeq = await _getNextSequenceNumber(sessionId);
      final eventId = const Uuid().v4();
      await into(matchEvents).insert(
        MatchEventsCompanion.insert(
          id: eventId,
          sessionId: sessionId,
          playerId: playerId,
          sourcePlayerId: Value(sourcePlayerId),
          eventType: 'life_delta',
          delta: Value(delta),
          value: Value(newLife),
          sequenceNumber: Value(nextSeq),
          payloadJson: Value(note != null ? jsonEncode({'note': note}) : null),
          timestamp: now,
          isUndone: const Value(false),
          isDeleted: const Value(false),
          updatedAt: Value(now),
        ),
      );
      await _recordSync('match_event', eventId, 'INSERT', timestamp: now);
    });
  }

  /// Sets absolute life total for a player.
  Future<void> setPlayerLife(String playerId, int newLife) async {
    final player = await getPlayerById(playerId);
    if (player == null) throw ArgumentError('Player $playerId not found');
    final delta = newLife - player.currentLife;
    await updatePlayerLife(sessionId: player.sessionId, playerId: playerId, delta: delta);
  }

  @override
  Future<void> recordCommanderDamage({
    required String sessionId,
    required String targetPlayerId,
    required String sourcePlayerId,
    required int delta,
    bool applyLifeDelta = true,
    String? commanderName,
  }) async {
    return transaction(() async {
      final now = DateTime.now();

      final target = await (select(matchPlayers)
            ..where((t) =>
                t.id.equals(targetPlayerId) &
                t.sessionId.equals(sessionId) &
                t.isDeleted.equals(false)))
          .getSingleOrNull();

      if (target == null) {
        throw ArgumentError('Target player $targetPlayerId not found in session $sessionId');
      }

      // Decode commander damage matrix
      Map<String, int> cmdDamage = {};
      if (target.commanderDamageJson != null && target.commanderDamageJson!.isNotEmpty) {
        try {
          final decoded = jsonDecode(target.commanderDamageJson!);
          if (decoded is Map) {
            cmdDamage = decoded.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
          }
        } catch (_) {}
      }

      final currentDmg = cmdDamage[sourcePlayerId] ?? 0;
      final newDmg = math.max(0, currentDmg + delta);
      cmdDamage[sourcePlayerId] = newDmg;

      final isLethalCommander = newDmg >= 21;
      final newLife = applyLifeDelta ? (target.currentLife - delta) : target.currentLife;
      final isLethalLife = newLife <= 0;
      final isEliminated = target.isEliminated || isLethalCommander || isLethalLife;
      final shouldMarkEliminated = isEliminated && !target.isEliminated;

      // Update target player
      await (update(matchPlayers)..where((t) => t.id.equals(targetPlayerId))).write(
        MatchPlayersCompanion(
          currentLife: applyLifeDelta ? Value(newLife) : const Value.absent(),
          commanderDamageJson: Value(jsonEncode(cmdDamage)),
          isEliminated: shouldMarkEliminated ? const Value(true) : Value(target.isEliminated),
          eliminatedAt: shouldMarkEliminated ? Value(now) : Value(target.eliminatedAt),
          updatedAt: Value(now),
        ),
      );
      await _recordSync('match_player', targetPlayerId, 'UPDATE', timestamp: now);

      // Append event
      final nextSeq = await _getNextSequenceNumber(sessionId);
      final eventId = const Uuid().v4();
      await into(matchEvents).insert(
        MatchEventsCompanion.insert(
          id: eventId,
          sessionId: sessionId,
          playerId: targetPlayerId,
          sourcePlayerId: Value(sourcePlayerId),
          eventType: 'commander_damage',
          delta: Value(delta),
          value: Value(newDmg),
          sequenceNumber: Value(nextSeq),
          payloadJson: Value(jsonEncode({
            'total_commander_damage': newDmg,
            'commander_name': commanderName,
            'is_lethal': isLethalCommander,
            'applied_life_delta': applyLifeDelta,
          })),
          timestamp: now,
          isUndone: const Value(false),
          isDeleted: const Value(false),
          updatedAt: Value(now),
        ),
      );
      await _recordSync('match_event', eventId, 'INSERT', timestamp: now);
    });
  }

  @override
  Future<void> recordCounterChange({
    required String sessionId,
    required String playerId,
    required String counterType,
    required int delta,
    int? absoluteValue,
  }) async {
    return transaction(() async {
      final now = DateTime.now();

      final player = await (select(matchPlayers)
            ..where((t) =>
                t.id.equals(playerId) &
                t.sessionId.equals(sessionId) &
                t.isDeleted.equals(false)))
          .getSingleOrNull();

      if (player == null) {
        throw ArgumentError('Player $playerId not found in session $sessionId');
      }

      int newVal = 0;
      MatchPlayersCompanion companion = MatchPlayersCompanion(updatedAt: Value(now));

      switch (counterType) {
        case 'poison':
          newVal = absoluteValue ?? math.max(0, player.poison + delta);
          final isLethalPoison = newVal >= 10;
          final isEliminated = player.isEliminated || isLethalPoison;
          companion = companion.copyWith(
            poison: Value(newVal),
            isEliminated: isEliminated ? const Value(true) : Value(player.isEliminated),
            eliminatedAt: isEliminated && !player.isEliminated ? Value(now) : Value(player.eliminatedAt),
          );
          break;

        case 'energy':
          newVal = absoluteValue ?? math.max(0, player.energy + delta);
          companion = companion.copyWith(energy: Value(newVal));
          break;

        case 'experience':
          newVal = absoluteValue ?? math.max(0, player.experience + delta);
          companion = companion.copyWith(experience: Value(newVal));
          break;

        case 'commander_tax':
          newVal = absoluteValue ?? math.max(0, player.commanderTax + delta);
          companion = companion.copyWith(commanderTax: Value(newVal));
          break;

        case 'monarch':
          final becomesMonarch = absoluteValue != null ? absoluteValue == 1 : (player.isMonarch ? delta > 0 : true);
          newVal = becomesMonarch ? 1 : 0;
          if (becomesMonarch) {
            // Pod-wide exclusive: clear monarch from all other players
            await (update(matchPlayers)
                  ..where((t) =>
                      t.sessionId.equals(sessionId) &
                      t.id.equals(playerId).not() &
                      t.isDeleted.equals(false)))
                .write(MatchPlayersCompanion(isMonarch: const Value(false), updatedAt: Value(now)));
          }
          companion = companion.copyWith(isMonarch: Value(becomesMonarch));
          break;

        case 'initiative':
          final becomesInitiative = absoluteValue != null ? absoluteValue == 1 : (player.hasInitiative ? delta > 0 : true);
          newVal = becomesInitiative ? 1 : 0;
          if (becomesInitiative) {
            // Pod-wide exclusive: clear initiative from all other players
            await (update(matchPlayers)
                  ..where((t) =>
                      t.sessionId.equals(sessionId) &
                      t.id.equals(playerId).not() &
                      t.isDeleted.equals(false)))
                .write(MatchPlayersCompanion(hasInitiative: const Value(false), updatedAt: Value(now)));
          }
          companion = companion.copyWith(hasInitiative: Value(becomesInitiative));
          break;

        default:
          Map<String, int> counters = {};
          if (player.countersJson != null && player.countersJson!.isNotEmpty) {
            try {
              final decoded = jsonDecode(player.countersJson!);
              if (decoded is Map) {
                counters = decoded.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
              }
            } catch (_) {}
          }
          final current = counters[counterType] ?? 0;
          newVal = absoluteValue ?? math.max(0, current + delta);
          counters[counterType] = newVal;
          companion = companion.copyWith(countersJson: Value(jsonEncode(counters)));
          break;
      }

      await (update(matchPlayers)..where((t) => t.id.equals(playerId))).write(companion);
      await _recordSync('match_player', playerId, 'UPDATE', timestamp: now);

      final nextSeq = await _getNextSequenceNumber(sessionId);
      final eventId = const Uuid().v4();
      await into(matchEvents).insert(
        MatchEventsCompanion.insert(
          id: eventId,
          sessionId: sessionId,
          playerId: playerId,
          eventType: counterType,
          delta: Value(delta),
          value: Value(newVal),
          sequenceNumber: Value(nextSeq),
          payloadJson: Value(jsonEncode({'counter_type': counterType, 'new_value': newVal})),
          timestamp: now,
          isUndone: const Value(false),
          isDeleted: const Value(false),
          updatedAt: Value(now),
        ),
      );
      await _recordSync('match_event', eventId, 'INSERT', timestamp: now);
    });
  }

  @override
  Future<void> updatePlayerCounter(String playerId, String counterType, int newValue) async {
    final player = await getPlayerById(playerId);
    if (player == null) throw ArgumentError('Player $playerId not found');
    await recordCounterChange(
      sessionId: player.sessionId,
      playerId: playerId,
      counterType: counterType,
      delta: 0,
      absoluteValue: newValue,
    );
  }

  @override
  Future<void> recordManaChange({
    required String sessionId,
    required String playerId,
    required String manaColor,
    required int delta,
  }) async {
    return transaction(() async {
      final now = DateTime.now();

      final player = await (select(matchPlayers)
            ..where((t) =>
                t.id.equals(playerId) &
                t.sessionId.equals(sessionId) &
                t.isDeleted.equals(false)))
          .getSingleOrNull();

      if (player == null) throw ArgumentError('Player $playerId not found in session $sessionId');

      Map<String, int> mana = {'W': 0, 'U': 0, 'B': 0, 'R': 0, 'G': 0, 'C': 0};
      if (player.floatingManaJson != null && player.floatingManaJson!.isNotEmpty) {
        try {
          final decoded = jsonDecode(player.floatingManaJson!);
          if (decoded is Map) {
            for (final key in ['W', 'U', 'B', 'R', 'G', 'C']) {
              if (decoded[key] != null) mana[key] = (decoded[key] as num).toInt();
            }
          }
        } catch (_) {}
      }

      final current = mana[manaColor] ?? 0;
      final newVal = math.max(0, current + delta);
      mana[manaColor] = newVal;

      await (update(matchPlayers)..where((t) => t.id.equals(playerId))).write(
        MatchPlayersCompanion(
          floatingManaJson: Value(jsonEncode(mana)),
          updatedAt: Value(now),
        ),
      );
      await _recordSync('match_player', playerId, 'UPDATE', timestamp: now);

      final nextSeq = await _getNextSequenceNumber(sessionId);
      final eventId = const Uuid().v4();
      await into(matchEvents).insert(
        MatchEventsCompanion.insert(
          id: eventId,
          sessionId: sessionId,
          playerId: playerId,
          eventType: 'mana_change',
          delta: Value(delta),
          value: Value(newVal),
          sequenceNumber: Value(nextSeq),
          payloadJson: Value(jsonEncode({'color': manaColor, 'floating_mana': mana})),
          timestamp: now,
          isUndone: const Value(false),
          isDeleted: const Value(false),
          updatedAt: Value(now),
        ),
      );
      await _recordSync('match_event', eventId, 'INSERT', timestamp: now);
    });
  }

  @override
  Future<void> recordStormChange({
    required String sessionId,
    required String playerId,
    required int delta,
  }) async {
    return transaction(() async {
      final now = DateTime.now();

      final player = await (select(matchPlayers)
            ..where((t) =>
                t.id.equals(playerId) &
                t.sessionId.equals(sessionId) &
                t.isDeleted.equals(false)))
          .getSingleOrNull();

      if (player == null) throw ArgumentError('Player $playerId not found');

      final newStorm = math.max(0, player.stormCount + delta);
      await (update(matchPlayers)..where((t) => t.id.equals(playerId))).write(
        MatchPlayersCompanion(stormCount: Value(newStorm), updatedAt: Value(now)),
      );
      await _recordSync('match_player', playerId, 'UPDATE', timestamp: now);

      final nextSeq = await _getNextSequenceNumber(sessionId);
      final eventId = const Uuid().v4();
      await into(matchEvents).insert(
        MatchEventsCompanion.insert(
          id: eventId,
          sessionId: sessionId,
          playerId: playerId,
          eventType: 'storm',
          delta: Value(delta),
          value: Value(newStorm),
          sequenceNumber: Value(nextSeq),
          payloadJson: Value(jsonEncode({'storm_count': newStorm})),
          timestamp: now,
          isUndone: const Value(false),
          isDeleted: const Value(false),
          updatedAt: Value(now),
        ),
      );
      await _recordSync('match_event', eventId, 'INSERT', timestamp: now);
    });
  }

  @override
  Future<void> clearManaPool({
    required String sessionId,
    required String playerId,
  }) async {
    return transaction(() async {
      final now = DateTime.now();

      final player = await (select(matchPlayers)
            ..where((t) =>
                t.id.equals(playerId) &
                t.sessionId.equals(sessionId) &
                t.isDeleted.equals(false)))
          .getSingleOrNull();

      if (player == null) {
        throw ArgumentError('Player $playerId not found in session $sessionId');
      }

      const emptyMana = '{"W":0,"U":0,"B":0,"R":0,"G":0,"C":0}';
      final prevMana = (player.floatingManaJson != null && player.floatingManaJson!.isNotEmpty)
          ? player.floatingManaJson!
          : emptyMana;
      final prevStorm = player.stormCount;

      await (update(matchPlayers)..where((t) => t.id.equals(playerId))).write(
        MatchPlayersCompanion(
          floatingManaJson: const Value(emptyMana),
          stormCount: const Value(0),
          updatedAt: Value(now),
        ),
      );
      await _recordSync('match_player', playerId, 'UPDATE', timestamp: now);

      final nextSeq = await _getNextSequenceNumber(sessionId);
      final eventId = const Uuid().v4();
      await into(matchEvents).insert(
        MatchEventsCompanion.insert(
          id: eventId,
          sessionId: sessionId,
          playerId: playerId,
          eventType: 'mana_clear',
          delta: const Value(0),
          value: const Value(0),
          sequenceNumber: Value(nextSeq),
          payloadJson: Value(jsonEncode({
            'cleared_mana': prevMana,
            'cleared_storm': prevStorm,
          })),
          timestamp: now,
          isUndone: const Value(false),
          isDeleted: const Value(false),
          updatedAt: Value(now),
        ),
      );
      await _recordSync('match_event', eventId, 'INSERT', timestamp: now);
    });
  }

  @override
  Future<void> resetSession(String sessionId, [int? startingLifeOverride]) async {
    return transaction(() async {
      final now = DateTime.now();

      final session = await (select(matchSessions)
            ..where((t) =>
                t.id.equals(sessionId) &
                t.isDeleted.equals(false)))
          .getSingleOrNull();

      if (session == null) throw ArgumentError('Session $sessionId not found');

      final life = startingLifeOverride ?? session.startingLife;
      const defaultMana = '{"W":0,"U":0,"B":0,"R":0,"G":0,"C":0}';

      await (update(matchPlayers)..where((t) => t.sessionId.equals(sessionId) & t.isDeleted.equals(false))).write(
        MatchPlayersCompanion(
          currentLife: Value(life),
          poison: const Value(0),
          energy: const Value(0),
          experience: const Value(0),
          commanderTax: const Value(0),
          isMonarch: const Value(false),
          hasInitiative: const Value(false),
          commanderDamageJson: const Value('{}'),
          floatingManaJson: const Value(defaultMana),
          stormCount: const Value(0),
          countersJson: const Value('{}'),
          isEliminated: const Value(false),
          eliminatedAt: const Value(null),
          updatedAt: Value(now),
        ),
      );

      final players = await getPlayersForSession(sessionId);
      for (final p in players) {
        await _recordSync('match_player', p.id, 'UPDATE', timestamp: now);
      }

      final nextSeq = await _getNextSequenceNumber(sessionId);
      final eventId = const Uuid().v4();
      await into(matchEvents).insert(
        MatchEventsCompanion.insert(
          id: eventId,
          sessionId: sessionId,
          playerId: players.isNotEmpty ? players.first.id : sessionId,
          eventType: 'reset',
          delta: const Value(0),
          value: Value(life),
          sequenceNumber: Value(nextSeq),
          payloadJson: Value(jsonEncode({'starting_life': life, 'action': 'lobby_reset'})),
          timestamp: now,
          isUndone: const Value(false),
          isDeleted: const Value(false),
          updatedAt: Value(now),
        ),
      );
      await _recordSync('match_event', eventId, 'INSERT', timestamp: now);
    });
  }

  @override
  Future<void> recordEvent({
    required String sessionId,
    required String eventType,
    required int sequenceNumber,
    String? targetPlayerId,
    String? sourcePlayerId,
    int delta = 0,
    int value = 0,
    Map<String, dynamic>? payload,
  }) async {
    return transaction(() async {
      final now = DateTime.now();
      final eventId = const Uuid().v4();
      await into(matchEvents).insert(
        MatchEventsCompanion.insert(
          id: eventId,
          sessionId: sessionId,
          playerId: targetPlayerId ?? sessionId,
          sourcePlayerId: Value(sourcePlayerId),
          eventType: eventType,
          delta: Value(delta),
          value: Value(value),
          sequenceNumber: Value(sequenceNumber),
          payloadJson: Value(payload != null ? jsonEncode(payload) : null),
          timestamp: now,
          isUndone: const Value(false),
          isDeleted: const Value(false),
          updatedAt: Value(now),
        ),
      );
      await _recordSync('match_event', eventId, 'INSERT', timestamp: now);
    });
  }

  @override
  Future<MatchEvent?> undoLastEvent({
    required String sessionId,
    String? playerId,
  }) async {
    return transaction(() async {
      final now = DateTime.now();

      var query = select(matchEvents)
        ..where((t) =>
            t.sessionId.equals(sessionId) &
            t.isUndone.equals(false) &
            t.isDeleted.equals(false) &
            t.eventType.isNotIn(['session_created', 'reset', 'undo']));

      if (playerId != null) {
        query = query..where((t) => t.playerId.equals(playerId));
      }

      query = query
        ..orderBy([(t) => OrderingTerm(expression: t.sequenceNumber, mode: OrderingMode.desc)])
        ..limit(1);

      final lastEvent = await query.getSingleOrNull();
      if (lastEvent == null) return null;

      // 1. Mark event as undone
      await (update(matchEvents)..where((t) => t.id.equals(lastEvent.id))).write(
        MatchEventsCompanion(
          isUndone: const Value(true),
          updatedAt: Value(now),
        ),
      );
      await _recordSync('match_event', lastEvent.id, 'UPDATE', timestamp: now);

      // 2. Reverse effect on the target player
      final target = await (select(matchPlayers)
            ..where((t) =>
                t.id.equals(lastEvent.playerId) &
                t.isDeleted.equals(false)))
          .getSingleOrNull();

      if (target != null) {
        MatchPlayersCompanion playerUpdate = MatchPlayersCompanion(updatedAt: Value(now));

        switch (lastEvent.eventType) {
          case 'life_delta':
            final restoredLife = target.currentLife - lastEvent.delta;
            final cmdDamage = _decodeCommanderDamage(target.commanderDamageJson);
            final isEliminated = _calculateIsEliminated(
              life: restoredLife,
              poison: target.poison,
              commanderDamage: cmdDamage,
            );
            playerUpdate = playerUpdate.copyWith(
              currentLife: Value(restoredLife),
              isEliminated: Value(isEliminated),
              eliminatedAt: isEliminated ? Value(target.eliminatedAt ?? now) : const Value(null),
            );
            break;

          case 'commander_damage':
            if (lastEvent.sourcePlayerId != null) {
              final cmdDamage = _decodeCommanderDamage(target.commanderDamageJson);
              final curDmg = cmdDamage[lastEvent.sourcePlayerId!] ?? 0;
              final restoredDmg = math.max(0, curDmg - lastEvent.delta);
              cmdDamage[lastEvent.sourcePlayerId!] = restoredDmg;

              bool appliedLifeDelta = true;
              if (lastEvent.payloadJson != null) {
                try {
                  final decoded = jsonDecode(lastEvent.payloadJson!);
                  if (decoded is Map && decoded['applied_life_delta'] is bool) {
                    appliedLifeDelta = decoded['applied_life_delta'] as bool;
                  }
                } catch (_) {}
              }
              final restoredLife = appliedLifeDelta ? (target.currentLife + lastEvent.delta) : target.currentLife;
              final isEliminated = _calculateIsEliminated(
                life: restoredLife,
                poison: target.poison,
                commanderDamage: cmdDamage,
              );

              playerUpdate = playerUpdate.copyWith(
                commanderDamageJson: Value(jsonEncode(cmdDamage)),
                currentLife: appliedLifeDelta ? Value(restoredLife) : const Value.absent(),
                isEliminated: Value(isEliminated),
                eliminatedAt: isEliminated ? Value(target.eliminatedAt ?? now) : const Value(null),
              );
            }
            break;

          case 'poison':
            final restoredPoison = math.max(0, target.poison - lastEvent.delta);
            final cmdDamage = _decodeCommanderDamage(target.commanderDamageJson);
            final isEliminated = _calculateIsEliminated(
              life: target.currentLife,
              poison: restoredPoison,
              commanderDamage: cmdDamage,
            );
            playerUpdate = playerUpdate.copyWith(
              poison: Value(restoredPoison),
              isEliminated: Value(isEliminated),
              eliminatedAt: isEliminated ? Value(target.eliminatedAt ?? now) : const Value(null),
            );
            break;

          case 'energy':
            playerUpdate = playerUpdate.copyWith(energy: Value(math.max(0, target.energy - lastEvent.delta)));
            break;

          case 'experience':
            playerUpdate = playerUpdate.copyWith(experience: Value(math.max(0, target.experience - lastEvent.delta)));
            break;

          case 'commander_tax':
            playerUpdate = playerUpdate.copyWith(commanderTax: Value(math.max(0, target.commanderTax - lastEvent.delta)));
            break;

          case 'mana_change':
            if (lastEvent.payloadJson != null) {
              try {
                final decoded = jsonDecode(lastEvent.payloadJson!);
                if (decoded is Map && decoded['color'] is String) {
                  final color = decoded['color'] as String;
                  Map<String, int> mana = {'W': 0, 'U': 0, 'B': 0, 'R': 0, 'G': 0, 'C': 0};
                  if (target.floatingManaJson != null) {
                    final curMana = jsonDecode(target.floatingManaJson!);
                    if (curMana is Map) {
                      curMana.forEach((k, v) => mana[k.toString()] = (v as num).toInt());
                    }
                  }
                  mana[color] = math.max(0, (mana[color] ?? 0) - lastEvent.delta);
                  playerUpdate = playerUpdate.copyWith(floatingManaJson: Value(jsonEncode(mana)));
                }
              } catch (_) {}
            }
            break;

          case 'storm':
            playerUpdate = playerUpdate.copyWith(stormCount: Value(math.max(0, target.stormCount - lastEvent.delta)));
            break;

          case 'mana_clear':
            if (lastEvent.payloadJson != null) {
              try {
                final decoded = jsonDecode(lastEvent.payloadJson!);
                if (decoded is Map) {
                  final clearedMana = decoded['cleared_mana'];
                  final clearedStorm = decoded['cleared_storm'];

                  if (clearedMana is String) {
                    playerUpdate = playerUpdate.copyWith(floatingManaJson: Value(clearedMana));
                  } else if (clearedMana is Map) {
                    playerUpdate = playerUpdate.copyWith(floatingManaJson: Value(jsonEncode(clearedMana)));
                  }

                  if (clearedStorm is num) {
                    playerUpdate = playerUpdate.copyWith(stormCount: Value(clearedStorm.toInt()));
                  }
                }
              } catch (_) {}
            }
            break;
        }

        await (update(matchPlayers)..where((t) => t.id.equals(target.id))).write(playerUpdate);
        await _recordSync('match_player', target.id, 'UPDATE', timestamp: now);
      }

      // 3. Log the undo event
      final nextSeq = await _getNextSequenceNumber(sessionId);
      final undoEventId = const Uuid().v4();
      await into(matchEvents).insert(
        MatchEventsCompanion.insert(
          id: undoEventId,
          sessionId: sessionId,
          playerId: lastEvent.playerId,
          eventType: 'undo',
          delta: const Value(0),
          value: const Value(0),
          sequenceNumber: Value(nextSeq),
          payloadJson: Value(jsonEncode({
            'undone_event_id': lastEvent.id,
            'undone_event_type': lastEvent.eventType,
            'undone_delta': lastEvent.delta,
          })),
          timestamp: now,
          isUndone: const Value(false),
          isDeleted: const Value(false),
          updatedAt: Value(now),
        ),
      );
      await _recordSync('match_event', undoEventId, 'INSERT', timestamp: now);

      return lastEvent;
    });
  }

  // ===========================================================================
  // SESSION LIFECYCLE MANAGEMENT
  // ===========================================================================

  @override
  Future<void> completeSession(String sessionId) async {
    final now = DateTime.now();
    await (update(matchSessions)..where((t) => t.id.equals(sessionId))).write(
      MatchSessionsCompanion(
        status: const Value('completed'),
        endedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    await _recordSync('match_session', sessionId, 'UPDATE', timestamp: now);
  }

  @override
  Future<void> abandonSession(String sessionId) async {
    final now = DateTime.now();
    await (update(matchSessions)..where((t) => t.id.equals(sessionId))).write(
      MatchSessionsCompanion(
        status: const Value('abandoned'),
        endedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    await _recordSync('match_session', sessionId, 'UPDATE', timestamp: now);
  }

  @override
  Future<void> softDeleteSession(String sessionId) async {
    return transaction(() async {
      final now = DateTime.now();
      await (update(matchSessions)..where((t) => t.id.equals(sessionId))).write(
        MatchSessionsCompanion(
          isDeleted: const Value(true),
          updatedAt: Value(now),
        ),
      );
      await _recordSync('match_session', sessionId, 'DELETE', timestamp: now);

      await (update(matchPlayers)..where((t) => t.sessionId.equals(sessionId))).write(
        MatchPlayersCompanion(
          isDeleted: const Value(true),
          updatedAt: Value(now),
        ),
      );

      await (update(matchEvents)..where((t) => t.sessionId.equals(sessionId))).write(
        MatchEventsCompanion(
          isDeleted: const Value(true),
          updatedAt: Value(now),
        ),
      );
    });
  }

  // ===========================================================================
  // EVENT REPLAY & STATE RECONSTRUCTION
  // ===========================================================================

  @override
  Future<Map<String, Map<String, dynamic>>> reconstructStateFromEvents(String sessionId) async {
    final events = await (select(matchEvents)
          ..where((t) =>
              t.sessionId.equals(sessionId) &
              t.isUndone.equals(false) &
              t.isDeleted.equals(false))
          ..orderBy([(t) => OrderingTerm(expression: t.sequenceNumber, mode: OrderingMode.asc)]))
        .get();

    final session = await (select(matchSessions)..where((t) => t.id.equals(sessionId))).getSingle();
    final startingLife = session.startingLife;

    final Map<String, Map<String, dynamic>> state = {};

    void ensurePlayer(String pid) {
      state.putIfAbsent(pid, () => {
        'life': startingLife,
        'poison': 0,
        'energy': 0,
        'experience': 0,
        'commanderTax': 0,
        'isMonarch': false,
        'hasInitiative': false,
        'commanderDamage': <String, int>{},
        'floatingMana': {'W': 0, 'U': 0, 'B': 0, 'R': 0, 'G': 0, 'C': 0},
        'stormCount': 0,
        'isEliminated': false,
      });
    }

    for (final e in events) {
      final pid = e.playerId;
      ensurePlayer(pid);
      final p = state[pid]!;

      switch (e.eventType) {
        case 'session_created':
          break;

        case 'life_delta':
          p['life'] = (p['life'] as int) + e.delta;
          if ((p['life'] as int) <= 0) p['isEliminated'] = true;
          break;

        case 'commander_damage':
          final src = e.sourcePlayerId ?? 'unknown';
          final cmdMap = p['commanderDamage'] as Map<String, int>;
          cmdMap[src] = (cmdMap[src] ?? 0) + e.delta;
          if (cmdMap[src]! >= 21) p['isEliminated'] = true;
          bool appliedLife = true;
          if (e.payloadJson != null) {
            try {
              final decoded = jsonDecode(e.payloadJson!);
              if (decoded is Map && decoded['applied_life_delta'] is bool) {
                appliedLife = decoded['applied_life_delta'] as bool;
              }
            } catch (_) {}
          }
          if (appliedLife) {
            p['life'] = (p['life'] as int) - e.delta;
            if ((p['life'] as int) <= 0) p['isEliminated'] = true;
          }
          break;

        case 'poison':
          p['poison'] = (p['poison'] as int) + e.delta;
          if ((p['poison'] as int) >= 10) p['isEliminated'] = true;
          break;

        case 'energy':
          p['energy'] = (p['energy'] as int) + e.delta;
          break;

        case 'experience':
          p['experience'] = (p['experience'] as int) + e.delta;
          break;

        case 'commander_tax':
          p['commanderTax'] = (p['commanderTax'] as int) + e.delta;
          break;

        case 'monarch':
          for (final entry in state.values) {
            entry['isMonarch'] = false;
          }
          p['isMonarch'] = e.value == 1 || e.delta > 0;
          break;

        case 'initiative':
          for (final entry in state.values) {
            entry['hasInitiative'] = false;
          }
          p['hasInitiative'] = e.value == 1 || e.delta > 0;
          break;

        case 'mana_change':
          if (e.payloadJson != null) {
            try {
              final decoded = jsonDecode(e.payloadJson!);
              if (decoded is Map && decoded['color'] is String) {
                final color = decoded['color'] as String;
                final mana = p['floatingMana'] as Map<String, int>;
                mana[color] = (mana[color] ?? 0) + e.delta;
              }
            } catch (_) {}
          }
          break;

        case 'storm':
          p['stormCount'] = (p['stormCount'] as int) + e.delta;
          break;

        case 'mana_clear':
          p['floatingMana'] = {'W': 0, 'U': 0, 'B': 0, 'R': 0, 'G': 0, 'C': 0};
          p['stormCount'] = 0;
          break;

        case 'reset':
          for (final entry in state.values) {
            entry['life'] = e.value;
            entry['poison'] = 0;
            entry['energy'] = 0;
            entry['experience'] = 0;
            entry['commanderTax'] = 0;
            entry['isMonarch'] = false;
            entry['hasInitiative'] = false;
            entry['commanderDamage'] = <String, int>{};
            entry['floatingMana'] = {'W': 0, 'U': 0, 'B': 0, 'R': 0, 'G': 0, 'C': 0};
            entry['stormCount'] = 0;
            entry['isEliminated'] = false;
          }
          break;
      }
    }

    return state;
  }
}
