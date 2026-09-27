// Copyright (c) 2026 Countr. All rights reserved.
// Tier 5 White-Box Code Coverage & Edge-Case Hardening Adversarial Test Suite for Phase 4.7.
// Exercises, verifies, and stress-tests white-box code paths, unreached branches, and fallback mechanisms across:
// 1. Data Layer: MatchDao, MatchSessionRepository, P2pSyncEngine
// 2. Domain Layer: PodPlayerState, PodState, RandomizerService
// 3. Presentation Layer: PodController, FloatingManaDrawerWidget, RandomizerHubModal, ResetGameDialog

import 'dart:math' as math;
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/life_counter/data/daos/match_dao.dart';
import 'package:countr/features/life_counter/data/network/in_memory_p2p_mesh.dart';
import 'package:countr/features/life_counter/data/network/p2p_sync_engine.dart';
import 'package:countr/features/life_counter/data/repositories/match_session_repository.dart';
import 'package:countr/features/life_counter/domain/models/p2p_packet.dart';
import 'package:countr/features/life_counter/domain/models/pod_state.dart';
import 'package:countr/features/life_counter/domain/models/randomizer_models.dart';
import 'package:countr/features/life_counter/domain/services/dice_roller_service.dart';
import 'package:countr/features/life_counter/presentation/controllers/pod_controller.dart';
import 'package:countr/features/life_counter/presentation/dialogs/randomizer_hub_modal.dart';
import 'package:countr/features/life_counter/presentation/dialogs/reset_game_dialog.dart';
import 'package:countr/features/life_counter/presentation/widgets/floating_mana_drawer_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ===========================================================================
  // TIER 5.1: MATCH DAO WHITE-BOX BRANCH & REVERSIBILITY AUDIT
  // ===========================================================================
  group('Tier 5.1 - MatchDao White-Box Reversibility, State Replay & Soft Deletes', () {
    late AppDatabase db;
    late MatchDao dao;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      dao = db.matchDao;
    });

    tearDown(() async {
      await db.close();
    });

    test('T5.1.1: undoLastEvent reverses life delta and un-eliminates eliminated player', () async {
      const sessionId = 'session_undo_life_1';
      final p1 = MatchPlayersCompanion.insert(
        id: 'p1',
        sessionId: sessionId,
        seatOrder: 0,
        playerName: 'Alice',
        currentLife: const Value(5),
      );

      await dao.createSession(
        sessionId: sessionId,
        format: 'commander',
        startingLife: 40,
        playerCount: 1,
        players: [p1],
      );

      // Reduce life from 5 to -2 (eliminating player)
      await dao.updatePlayerLife(sessionId: sessionId, playerId: 'p1', delta: -7);
      var player = await dao.getPlayerById('p1');
      expect(player!.currentLife, -2);
      expect(player.isEliminated, isTrue);
      expect(player.eliminatedAt, isNotNull);

      // Undo event: restores life to 5 and clears elimination
      final undone = await dao.undoLastEvent(sessionId: sessionId);
      expect(undone, isNotNull);
      expect(undone!.eventType, 'life_delta');

      player = await dao.getPlayerById('p1');
      expect(player!.currentLife, 5);
      expect(player.isEliminated, isFalse);
      expect(player.eliminatedAt, isNull);
    });

    test('T5.1.2: undoLastEvent reverses commander damage with and without life delta', () async {
      const sessionId = 'session_undo_cmd_dmg';
      final p1 = MatchPlayersCompanion.insert(
        id: 'p1',
        sessionId: sessionId,
        seatOrder: 0,
        playerName: 'Target',
        currentLife: const Value(40),
      );
      final p2 = MatchPlayersCompanion.insert(
        id: 'p2',
        sessionId: sessionId,
        seatOrder: 1,
        playerName: 'Source',
        currentLife: const Value(40),
      );

      await dao.createSession(
        sessionId: sessionId,
        format: 'commander',
        startingLife: 40,
        playerCount: 2,
        players: [p1, p2],
      );

      // 1. Record 21 lethal commander damage with life delta (40 -> 19)
      await dao.recordCommanderDamage(
        sessionId: sessionId,
        targetPlayerId: 'p1',
        sourcePlayerId: 'p2',
        delta: 21,
        applyLifeDelta: true,
      );

      var target = await dao.getPlayerById('p1');
      expect(target!.currentLife, 19);
      expect(target.isEliminated, isTrue);

      // Undo: restores life to 40, resets cmd damage to 0, revives player
      await dao.undoLastEvent(sessionId: sessionId);
      target = await dao.getPlayerById('p1');
      expect(target!.currentLife, 40);
      expect(target.isEliminated, isFalse);

      // 2. Record commander damage WITHOUT life delta (e.g. redirected or life unchanged)
      await dao.recordCommanderDamage(
        sessionId: sessionId,
        targetPlayerId: 'p1',
        sourcePlayerId: 'p2',
        delta: 8,
        applyLifeDelta: false,
      );
      target = await dao.getPlayerById('p1');
      expect(target!.currentLife, 40); // Unchanged

      // Undo: commander damage is reversed, life stays 40
      await dao.undoLastEvent(sessionId: sessionId);
      target = await dao.getPlayerById('p1');
      expect(target!.currentLife, 40);
    });

    test('T5.1.3: undoLastEvent reverses lethal poison and restores player active status', () async {
      const sessionId = 'session_undo_poison';
      final p1 = MatchPlayersCompanion.insert(
        id: 'p1',
        sessionId: sessionId,
        seatOrder: 0,
        playerName: 'Alice',
        currentLife: const Value(30),
      );

      await dao.createSession(
        sessionId: sessionId,
        format: 'commander',
        startingLife: 40,
        playerCount: 1,
        players: [p1],
      );

      // Apply 10 poison counters -> lethal
      await dao.recordCounterChange(
        sessionId: sessionId,
        playerId: 'p1',
        counterType: 'poison',
        delta: 10,
      );

      var player = await dao.getPlayerById('p1');
      expect(player!.poison, 10);
      expect(player.isEliminated, isTrue);

      // Undo: reverts poison to 0, clears elimination
      await dao.undoLastEvent(sessionId: sessionId);
      player = await dao.getPlayerById('p1');
      expect(player!.poison, 0);
      expect(player.isEliminated, isFalse);
      expect(player.eliminatedAt, isNull);
    });

    test('T5.1.4: undoLastEvent accurately restores mana pool map and storm count on mana_clear', () async {
      const sessionId = 'session_undo_mana_clear';
      final p1 = MatchPlayersCompanion.insert(
        id: 'p1',
        sessionId: sessionId,
        seatOrder: 0,
        playerName: 'Alice',
        currentLife: const Value(40),
      );

      await dao.createSession(
        sessionId: sessionId,
        format: 'commander',
        startingLife: 40,
        playerCount: 1,
        players: [p1],
      );

      // Add mana and storm
      await dao.recordManaChange(sessionId: sessionId, playerId: 'p1', manaColor: 'U', delta: 4);
      await dao.recordManaChange(sessionId: sessionId, playerId: 'p1', manaColor: 'R', delta: 2);
      await dao.recordStormChange(sessionId: sessionId, playerId: 'p1', delta: 5);

      var player = await dao.getPlayerById('p1');
      expect(player!.stormCount, 5);

      // Clear mana pool
      await dao.clearManaPool(sessionId: sessionId, playerId: 'p1');
      player = await dao.getPlayerById('p1');
      expect(player!.stormCount, 0);

      // Undo mana clear: restores U:4, R:2, storm:5
      final undone = await dao.undoLastEvent(sessionId: sessionId);
      expect(undone!.eventType, 'mana_clear');

      player = await dao.getPlayerById('p1');
      expect(player!.stormCount, 5);
      expect(player.floatingManaJson, contains('"U":4'));
      expect(player.floatingManaJson, contains('"R":2'));
    });

    test('T5.1.5: undoLastEvent with target playerId only reverses that player\'s events', () async {
      const sessionId = 'session_undo_specific_player';
      final p1 = MatchPlayersCompanion.insert(
        id: 'p1',
        sessionId: sessionId,
        seatOrder: 0,
        playerName: 'Alice',
        currentLife: const Value(40),
      );
      final p2 = MatchPlayersCompanion.insert(
        id: 'p2',
        sessionId: sessionId,
        seatOrder: 1,
        playerName: 'Bob',
        currentLife: const Value(40),
      );

      await dao.createSession(
        sessionId: sessionId,
        format: 'commander',
        startingLife: 40,
        playerCount: 2,
        players: [p1, p2],
      );

      // p1 life -5
      await dao.updatePlayerLife(sessionId: sessionId, playerId: 'p1', delta: -5);
      // p2 life -10
      await dao.updatePlayerLife(sessionId: sessionId, playerId: 'p2', delta: -10);

      // Undo specifically for p1: rolls back p1 (-5) while leaving p2 (-10) untouched
      final undone = await dao.undoLastEvent(sessionId: sessionId, playerId: 'p1');
      expect(undone!.playerId, 'p1');

      final alice = await dao.getPlayerById('p1');
      final bob = await dao.getPlayerById('p2');
      expect(alice!.currentLife, 40);
      expect(bob!.currentLife, 30);
    });

    test('T5.1.6: undoLastEvent returns null when log contains only non-undoable events or is empty', () async {
      const sessionId = 'session_undo_empty';
      final p1 = MatchPlayersCompanion.insert(
        id: 'p1',
        sessionId: sessionId,
        seatOrder: 0,
        playerName: 'Alice',
        currentLife: const Value(40),
      );

      await dao.createSession(
        sessionId: sessionId,
        format: 'commander',
        startingLife: 40,
        playerCount: 1,
        players: [p1],
      );

      // Only 'session_created' is present
      final undone = await dao.undoLastEvent(sessionId: sessionId);
      expect(undone, isNull);
    });

    test('T5.1.7: reconstructStateFromEvents replays complex game history accurately', () async {
      const sessionId = 'session_replay_history';
      final p1 = MatchPlayersCompanion.insert(
        id: 'p1',
        sessionId: sessionId,
        seatOrder: 0,
        playerName: 'P1',
        currentLife: const Value(40),
      );
      final p2 = MatchPlayersCompanion.insert(
        id: 'p2',
        sessionId: sessionId,
        seatOrder: 1,
        playerName: 'P2',
        currentLife: const Value(40),
      );

      await dao.createSession(
        sessionId: sessionId,
        format: 'commander',
        startingLife: 40,
        playerCount: 2,
        players: [p1, p2],
      );

      // Event sequence:
      // 1. P1 takes 3 damage
      await dao.updatePlayerLife(sessionId: sessionId, playerId: 'p1', delta: -3);
      // 2. P2 takes 5 commander damage from P1
      await dao.recordCommanderDamage(
        sessionId: sessionId,
        targetPlayerId: 'p2',
        sourcePlayerId: 'p1',
        delta: 5,
        applyLifeDelta: true,
      );
      // 3. P1 gains Monarch
      await dao.recordCounterChange(sessionId: sessionId, playerId: 'p1', counterType: 'monarch', delta: 1);
      // 4. P2 steals Monarch
      await dao.recordCounterChange(sessionId: sessionId, playerId: 'p2', counterType: 'monarch', delta: 1);
      // 5. P1 floating mana +2 G
      await dao.recordManaChange(sessionId: sessionId, playerId: 'p1', manaColor: 'G', delta: 2);

      // Reconstruct
      final state = await dao.reconstructStateFromEvents(sessionId);
      expect(state['p1']!['life'], 37);
      expect(state['p1']!['isMonarch'], isFalse); // Stolen by P2
      expect((state['p1']!['floatingMana'] as Map)['G'], 2);

      expect(state['p2']!['life'], 35);
      expect((state['p2']!['commanderDamage'] as Map)['p1'], 5);
      expect(state['p2']!['isMonarch'], isTrue);
    });

    test('T5.1.8: softDeleteSession isolates session and players from active queries', () async {
      const sessionId = 'session_soft_delete';
      final p1 = MatchPlayersCompanion.insert(
        id: 'p1',
        sessionId: sessionId,
        seatOrder: 0,
        playerName: 'Alice',
        currentLife: const Value(40),
      );

      await dao.createSession(
        sessionId: sessionId,
        format: 'commander',
        startingLife: 40,
        playerCount: 1,
        players: [p1],
      );

      expect(await dao.getActiveSession(), isNotNull);

      // Soft delete
      await dao.softDeleteSession(sessionId);

      // Active session and player queries must return null / empty
      expect(await dao.getActiveSession(), isNull);
      expect(await dao.getSessionById(sessionId), isNull);
      expect(await dao.getPlayersForSession(sessionId), isEmpty);
    });
  });

  // ===========================================================================
  // TIER 5.2: MATCH SESSION REPOSITORY WRITE QUEUE & RECOVERY HARDENING
  // ===========================================================================
  group('Tier 5.2 - MatchSessionRepository FIFO Queue & Recovery Hardening', () {
    late AppDatabase db;
    late MatchSessionRepository repo;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = MatchSessionRepository(db: db);
    });

    tearDown(() async {
      repo.dispose();
      await db.close();
    });

    test('T5.2.1: FIFO async write queue maintains transaction order under concurrent burst', () async {
      final initialPod = await repo.createSession(
        format: 'commander',
        startingLife: 40,
        players: [
          const PlayerSetupConfig(id: 'p1', seatOrder: 0, name: 'Alice', startingLife: 40),
        ],
      );

      // Fire 20 simultaneous async delta updates without awaiting each individually
      final futures = <Future<void>>[];
      for (int i = 1; i <= 20; i++) {
        futures.add(repo.recordLifeDelta(
          sessionId: initialPod.sessionId,
          playerId: 'p1',
          delta: -1,
          sequenceNumber: i + 1,
        ));
      }

      await Future.wait(futures);
      await repo.flush();

      final restored = await repo.restoreActiveSession();
      expect(restored!.getPlayer('p1')!.life, 20); // 40 - 20 = 20
      expect(restored.sequenceNumber, greaterThanOrEqualTo(21));
    });

    test('T5.2.2: reconstitutes pod state with custom settings (is_day: false)', () async {
      await repo.createSession(
        format: 'brawl',
        startingLife: 30,
        players: [
          const PlayerSetupConfig(id: 'p1', seatOrder: 0, name: 'Alice', startingLife: 30),
        ],
        initialSettings: {'is_day': false},
      );

      final restored = await repo.restoreActiveSession();
      expect(restored!.format, 'brawl');
      expect(restored.startingLife, 30);
      expect(restored.isDay, isFalse);
    });

    test('T5.2.3: throws StateError when enqueuing writes on disposed repository', () async {
      final tempRepo = MatchSessionRepository(db: db);
      tempRepo.dispose();

      expect(
        () => tempRepo.recordLifeDelta(
          sessionId: 'any_session',
          playerId: 'p1',
          delta: -1,
          sequenceNumber: 1,
        ),
        throwsStateError,
      );
    });

    test('T5.2.4: resetSession restores life and zeroes counters while preserving players', () async {
      final pod = await repo.createSession(
        format: 'commander',
        startingLife: 40,
        players: [
          const PlayerSetupConfig(id: 'p1', seatOrder: 0, name: 'Alice', startingLife: 40),
          const PlayerSetupConfig(id: 'p2', seatOrder: 1, name: 'Bob', startingLife: 40),
        ],
      );

      await repo.recordLifeDelta(sessionId: pod.sessionId, playerId: 'p1', delta: -15, sequenceNumber: 2);
      await repo.recordCounterChange(
        sessionId: pod.sessionId,
        playerId: 'p1',
        counterType: 'poison',
        delta: 4,
        sequenceNumber: 3,
      );

      final resetPod = await repo.resetSession(pod.sessionId, 40);
      expect(resetPod.getPlayer('p1')!.life, 40);
      expect(resetPod.getPlayer('p1')!.poison, 0);
      expect(resetPod.getPlayer('p2')!.life, 40);
      expect(resetPod.playerCount, 2);
    });
  });

  // ===========================================================================
  // TIER 5.3: P2P SYNC ENGINE ADVERSARIAL RECONNECTION & BUFFERING
  // ===========================================================================
  group('Tier 5.3 - P2pSyncEngine Adversarial Reconnection, Catch-Up & Token Exclusivity', () {
    late InMemoryP2pMesh mesh;
    late InMemoryP2pTransport hostTransport;
    late InMemoryP2pTransport client1Transport;

    setUp(() {
      mesh = InMemoryP2pMesh();
      hostTransport = mesh.createNode('host');
      client1Transport = mesh.createNode('client1');
    });

    test('T5.3.1: client queues multiple optimistic actions and reconciles on confirmation', () async {
      const initialPod = PodState(
        sessionId: 's_opt',
        format: 'commander',
        startingLife: 40,
        players: [
          PodPlayerState(id: 'p1', seatIndex: 0, name: 'P1', life: 40, isLocalDevice: true),
          PodPlayerState(id: 'p2', seatIndex: 1, name: 'P2', life: 40),
        ],
        isP2pHost: false,
      );

      final clientEngine = P2pSyncEngine(
        initialState: initialPod,
        transport: client1Transport,
        isHost: false,
        localPlayerId: 'p1',
      );

      // Client performs 3 rapid local life adjustments
      await clientEngine.sendLifeAdjustment('p1', -1);
      await clientEngine.sendLifeAdjustment('p1', -2);
      await clientEngine.sendLifeAdjustment('p1', -3);

      expect(clientEngine.pendingActions.length, 3);
      expect(clientEngine.state.getPlayer('p1')!.life, 34); // 40 - 1 - 2 - 3 = 34

      // Host receives and broadcasts confirmation for first action
      final firstAction = clientEngine.pendingActions.first;
      client1Transport.receivePacket(P2pPacket(
        type: P2pPacketType.lifeDelta,
        senderId: 'host',
        sequenceNumber: 1,
        targetPlayerId: 'p1',
        delta: -1,
        payload: {'action_id': firstAction.actionId},
      ));
      await Future.delayed(Duration.zero);

      expect(clientEngine.pendingActions.length, 2);
      expect(clientEngine.state.sequenceNumber, 1);
      expect(clientEngine.state.getPlayer('p1')!.life, 34);
    });

    test('T5.3.2: host responds with catchupResponse delta slice when gap is continuous', () async {
      const pod = PodState(
        sessionId: 's_catchup',
        format: 'commander',
        startingLife: 40,
        players: [
          PodPlayerState(id: 'p1', seatIndex: 0, name: 'P1', life: 40),
          PodPlayerState(id: 'p2', seatIndex: 1, name: 'P2', life: 40),
        ],
        isP2pHost: true,
      );

      final hostEngine = P2pSyncEngine(
        initialState: pod,
        transport: hostTransport,
        isHost: true,
      );

      // Host executes 4 events
      await hostEngine.sendLifeAdjustment('p1', -1);
      await hostEngine.sendLifeAdjustment('p1', -1);
      await hostEngine.sendLifeAdjustment('p1', -1);
      await hostEngine.sendLifeAdjustment('p1', -1);

      expect(hostEngine.state.sequenceNumber, 4);

      P2pPacket? replyPacket;
      client1Transport.incomingPackets.listen((p) => replyPacket = p);

      // Client requests catchup from sequence 2
      await client1Transport.sendPacket(P2pPacket(
        type: P2pPacketType.catchupRequest,
        senderId: 'client1',
        sequenceNumber: 2,
        payload: {'from_sequence': 2},
      ));
      await Future.delayed(Duration.zero);

      expect(replyPacket, isNotNull);
      expect(replyPacket!.type, P2pPacketType.catchupResponse);
      final events = replyPacket!.payload['events'] as List;
      expect(events.length, 2); // Events 3 and 4
    });

    test('T5.3.3: token exclusivity across 3 nodes transfers Monarch and strips from previous holder', () async {
      const pod = PodState(
        sessionId: 's_monarch',
        format: 'commander',
        startingLife: 40,
        players: [
          PodPlayerState(id: 'p1', seatIndex: 0, name: 'P1', life: 40),
          PodPlayerState(id: 'p2', seatIndex: 1, name: 'P2', life: 40),
          PodPlayerState(id: 'p3', seatIndex: 2, name: 'P3', life: 40),
        ],
        isP2pHost: true,
      );

      final hostEngine = P2pSyncEngine(
        initialState: pod,
        transport: hostTransport,
        isHost: true,
      );
      final client1Engine = P2pSyncEngine(
        initialState: pod,
        transport: client1Transport,
        isHost: false,
      );

      // P1 claims Monarch
      await hostEngine.claimToken(tokenType: 'monarch', claimantId: 'p1');
      await Future.delayed(Duration.zero);
      expect(hostEngine.state.getPlayer('p1')!.isMonarch, isTrue);
      expect(client1Engine.state.getPlayer('p1')!.isMonarch, isTrue);

      // P2 claims Monarch
      await hostEngine.claimToken(tokenType: 'monarch', claimantId: 'p2');
      await Future.delayed(Duration.zero);
      expect(hostEngine.state.getPlayer('p1')!.isMonarch, isFalse);
      expect(hostEngine.state.getPlayer('p2')!.isMonarch, isTrue);
      expect(client1Engine.state.getPlayer('p1')!.isMonarch, isFalse);
      expect(client1Engine.state.getPlayer('p2')!.isMonarch, isTrue);
    });

    test('T5.3.4: Day/Night cycle toggle synchronizes across all nodes', () async {
      const pod = PodState(
        sessionId: 's_day_night',
        format: 'commander',
        startingLife: 40,
        players: [
          PodPlayerState(id: 'p1', seatIndex: 0, name: 'P1', life: 40),
          PodPlayerState(id: 'p2', seatIndex: 1, name: 'P2', life: 40),
        ],
        isDay: true,
        isP2pHost: true,
      );

      final hostEngine = P2pSyncEngine(initialState: pod, transport: hostTransport, isHost: true);
      final clientEngine = P2pSyncEngine(initialState: pod, transport: client1Transport, isHost: false);

      expect(hostEngine.state.isDay, isTrue);
      expect(clientEngine.state.isDay, isTrue);

      await hostEngine.toggleDayNight();
      await Future.delayed(Duration.zero);

      expect(hostEngine.state.isDay, isFalse);
      expect(clientEngine.state.isDay, isFalse);
    });

    test('T5.3.5: Heartbeat ping triggers pong reply with sequence number', () async {
      const pod = PodState(
        sessionId: 's_heartbeat',
        format: 'commander',
        startingLife: 40,
        players: [],
        sequenceNumber: 7,
      );

      P2pSyncEngine(initialState: pod, transport: hostTransport, isHost: true);

      P2pPacket? pong;
      client1Transport.incomingPackets.listen((p) => pong = p);

      await client1Transport.sendPacket(P2pPacket(
        type: P2pPacketType.heartbeat,
        senderId: 'client1',
        sequenceNumber: 7,
        payload: {'is_ping': true},
      ));
      await Future.delayed(Duration.zero);

      expect(pong, isNotNull);
      expect(pong!.payload['is_ping'], isFalse);
      expect(pong!.payload['last_seq'], 7);
    });
  });

  // ===========================================================================
  // TIER 5.4: DOMAIN MODELS INVARIANT & IMMUTABILITY HARDENING
  // ===========================================================================
  group('Tier 5.4 - Domain Models Lethal Invariant & Defensive Immutability', () {
    test('T5.4.1: PodPlayerState evaluates lethal boundary conditions exactly', () {
      // 1. Life boundaries
      expect(const PodPlayerState(id: 'p', seatIndex: 0, name: 'A', life: 1).isLethal, isFalse);
      expect(const PodPlayerState(id: 'p', seatIndex: 0, name: 'A', life: 0).isLethal, isTrue);
      expect(const PodPlayerState(id: 'p', seatIndex: 0, name: 'A', life: -5).isLethal, isTrue);

      // 2. Poison boundaries
      expect(const PodPlayerState(id: 'p', seatIndex: 0, name: 'A', life: 40, poison: 9).isPoisonLethal, isFalse);
      expect(const PodPlayerState(id: 'p', seatIndex: 0, name: 'A', life: 40, poison: 10).isPoisonLethal, isTrue);
      expect(const PodPlayerState(id: 'p', seatIndex: 0, name: 'A', life: 40, poison: 10).isLethal, isTrue);

      // 3. Commander damage boundaries
      final nonLethalCmd = const PodPlayerState(
        id: 'p',
        seatIndex: 0,
        name: 'A',
        life: 40,
        commanderDamageTaken: {'op1': 20},
      );
      expect(nonLethalCmd.isCommanderDamageLethalFrom('op1'), isFalse);
      expect(nonLethalCmd.hasAnyLethalCommanderDamage, isFalse);
      expect(nonLethalCmd.isLethal, isFalse);

      final lethalCmd = const PodPlayerState(
        id: 'p',
        seatIndex: 0,
        name: 'A',
        life: 40,
        commanderDamageTaken: {'op1': 21},
      );
      expect(lethalCmd.isCommanderDamageLethalFrom('op1'), isTrue);
      expect(lethalCmd.hasAnyLethalCommanderDamage, isTrue);
      expect(lethalCmd.isLethal, isTrue);
    });

    test('T5.4.2: copyWith enforces defensive unmodifiable map copies', () {
      final mutableCmd = <String, int>{'op1': 5};
      final mutableMana = <String, int>{'W': 1, 'U': 2};

      const p = PodPlayerState(
        id: 'p1',
        seatIndex: 0,
        name: 'Alice',
        life: 40,
      );

      final p2 = p.copyWith(
        commanderDamageTaken: mutableCmd,
        floatingMana: mutableMana,
      );

      // 1. Modifying source mutable map after copyWith must not affect p2
      mutableCmd['op1'] = 99;
      mutableMana['W'] = 99;

      expect(p2.commanderDamageTaken['op1'], 5);
      expect(p2.floatingMana['W'], 1);

      // 2. Direct mutation attempt of p2 maps must throw UnsupportedError
      expect(() => p2.commanderDamageTaken['op1'] = 100, throwsUnsupportedError);
      expect(() => p2.floatingMana['W'] = 100, throwsUnsupportedError);
    });

    test('T5.4.3: JSON round-trip serialization maintains full fidelity', () {
      final original = const PodState(
        sessionId: 's_json_test',
        format: 'commander',
        startingLife: 40,
        players: [
          PodPlayerState(
            id: 'p1',
            seatIndex: 0,
            name: 'Alice',
            life: 37,
            poison: 2,
            energy: 5,
            experience: 3,
            commanderTax: 4,
            isMonarch: true,
            hasInitiative: false,
            commanderDamageTaken: {'p2': 12},
            floatingMana: {'W': 1, 'U': 2, 'B': 0, 'R': 0, 'G': 3, 'C': 0},
            stormCount: 4,
            isEliminated: false,
          ),
        ],
        isDay: false,
        isP2pHost: true,
        roomCode: 'POD42',
        sequenceNumber: 15,
      );

      final json = original.toJson();
      final revived = PodState.fromJson(json);

      expect(revived, equals(original));
      expect(revived.players.first.isMonarch, isTrue);
      expect(revived.players.first.floatingMana['G'], 3);
      expect(revived.isDay, isFalse);
    });
  });

  // ===========================================================================
  // TIER 5.5: RANDOMIZER SERVICE STATISTICAL BOUNDS & EXCLUSION HARDENING
  // ===========================================================================
  group('Tier 5.5 - RandomizerService Statistical Bounds & Exclusions', () {
    late RandomizerService service;

    setUp(() {
      service = RandomizerService(math.Random(42));
    });

    test('T5.5.1: selectRandomOpponentIndex strictly NEVER selects self seat across 1000 samples', () {
      const iterations = 1000;
      for (final podSize in [2, 3, 4, 5, 6]) {
        for (int selfSeat = 0; selfSeat < podSize; selfSeat++) {
          for (int i = 0; i < iterations ~/ 5; i++) {
            final opponent = service.selectRandomOpponentIndex(podSize, selfSeat);
            expect(opponent, isNot(equals(selfSeat)), reason: 'Selected selfSeat in $podSize-player pod');
            expect(opponent, greaterThanOrEqualTo(0));
            expect(opponent, lessThan(podSize));
          }
        }
      }
    });

    test('T5.5.2: selectRandomOpponentIndex with <= 1 player returns selfSeatIndex safely', () {
      expect(service.selectRandomOpponentIndex(1, 0), 0);
      expect(service.selectRandomOpponentIndex(0, 0), 0);
    });

    test('T5.5.3: polyhedral dice rolls strictly bounded across all dice types', () {
      for (final type in DiceType.values) {
        for (int i = 0; i < 200; i++) {
          final roll = service.rollDice(type);
          expect(roll, greaterThanOrEqualTo(1));
          expect(roll, lessThanOrEqualTo(type.sides));
        }
      }
    });

    test('T5.5.4: history ledger bounds to maximum 100 entries', () {
      for (int i = 0; i < 150; i++) {
        service.flipCoin();
      }
      expect(service.history.length, 100);
      expect(service.totalFlips, 150);
    });

    test('T5.5.5: headsRatio handles 0 flips edge case gracefully', () {
      expect(service.headsRatio, 0.5);
      service.flipCoin();
      expect(service.headsRatio, inInclusiveRange(0.0, 1.0));
    });
  });

  // ===========================================================================
  // TIER 5.6: POD CONTROLLER STANDALONE & MESH HARDENING
  // ===========================================================================
  group('Tier 5.6 - PodController Standalone & Storm Coupling Hardening', () {
    test('T5.6.1: adjustMana increments storm count on positive mana, preserves on decrement', () async {
      const initialPod = PodState(
        sessionId: 's_ctrl_mana',
        format: 'commander',
        startingLife: 40,
        players: [
          PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40),
        ],
      );

      final controller = PodController(initialState: initialPod);

      // Increment U mana -> storm count increments to 1
      await controller.adjustMana(playerId: 'p1', color: 'U', delta: 1);
      expect(controller.state.getPlayer('p1')!.floatingMana['U'], 1);
      expect(controller.state.getPlayer('p1')!.stormCount, 1);

      // Increment U mana again -> storm count becomes 2
      await controller.adjustMana(playerId: 'p1', color: 'U', delta: 1);
      expect(controller.state.getPlayer('p1')!.stormCount, 2);

      // Decrement U mana -> storm count stays 2 (does not decrease on spending mana)
      await controller.adjustMana(playerId: 'p1', color: 'U', delta: -1);
      expect(controller.state.getPlayer('p1')!.floatingMana['U'], 1);
      expect(controller.state.getPlayer('p1')!.stormCount, 2);

      // One-tap clear pool zeroes mana AND storm count
      await controller.clearManaPool('p1');
      expect(controller.state.getPlayer('p1')!.floatingMana['U'], 0);
      expect(controller.state.getPlayer('p1')!.stormCount, 0);
    });

    test('T5.6.2: toggleEliminated and overrideCommanderArt update player UI state', () {
      const initialPod = PodState(
        sessionId: 's_ctrl_ui',
        format: 'commander',
        startingLife: 40,
        players: [
          PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40),
        ],
      );

      final controller = PodController(initialState: initialPod);

      controller.toggleEliminated('p1');
      expect(controller.state.getPlayer('p1')!.isEliminated, isTrue);

      controller.overrideCommanderArt('p1', 'https://scryfall.com/art/custom.jpg');
      expect(controller.state.getPlayer('p1')!.commanderArtCropUrl, 'https://scryfall.com/art/custom.jpg');
    });
  });

  // ===========================================================================
  // TIER 5.7: PRESENTATION LAYER (WIDGETS & DIALOGS) HARDENING
  // ===========================================================================
  group('Tier 5.7 - Presentation Widgets & Dialogs Interaction Hardening', () {
    testWidgets('T5.7.1: FloatingManaDrawerWidget increments and decrements mana and storm', (tester) async {
      String? updatedColor;
      int manaDelta = 0;
      int stormDelta = 0;
      bool cleared = false;

      final player = const PodPlayerState(
        id: 'p1',
        seatIndex: 0,
        name: 'Alice',
        life: 40,
        floatingMana: {'W': 1, 'U': 2, 'B': 0, 'R': 0, 'G': 0, 'C': 0},
        stormCount: 3,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FloatingManaDrawerWidget(
              player: player,
              onManaDelta: (c, d) {
                updatedColor = c;
                manaDelta = d;
              },
              onStormDelta: (d) => stormDelta = d,
              onManaClear: () => cleared = true,
              autoCloseOnClear: false,
            ),
          ),
        ),
      );

      // Increment W mana
      await tester.tap(find.byKey(const Key('mana_inc_W_p1')));
      await tester.pump();
      expect(updatedColor, 'W');
      expect(manaDelta, 1);

      // Decrement U mana
      await tester.tap(find.byKey(const Key('mana_dec_U_p1')));
      await tester.pump();
      expect(updatedColor, 'U');
      expect(manaDelta, -1);

      // Increment storm
      await tester.tap(find.byKey(const Key('storm_inc_p1')));
      await tester.pump();
      expect(stormDelta, 1);

      // Tap Clear Pool
      await tester.tap(find.byKey(const Key('clear_pool_btn_p1')));
      await tester.pump();
      expect(cleared, isTrue);
    });

    testWidgets('T5.7.2: RandomizerHubModal rolls dice and selects player/opponent', (tester) async {
      int? pickedPlayer;
      int? pickedOpponent;
      bool resetTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RandomizerHubModal(
              playerCount: 4,
              selfSeatIndex: 1,
              onPlayerSelected: (seat) => pickedPlayer = seat,
              onOpponentSelected: (seat) => pickedOpponent = seat,
              onResetGame: () => resetTriggered = true,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('randomizer_hub_modal')), findsOneWidget);

      // Roll D20
      await tester.tap(find.byKey(const Key('dice_d20_btn')));
      await tester.pump();
      expect(find.textContaining('D20 Roll:'), findsOneWidget);

      // Roll D100
      await tester.tap(find.byKey(const Key('dice_d100_btn')));
      await tester.pump();
      expect(find.textContaining('D100 Roll:'), findsOneWidget);

      // Flip Coin
      await tester.tap(find.byKey(const Key('coin_flip_btn')));
      await tester.pump();
      expect(find.textContaining('Coin Flip:'), findsOneWidget);

      // Pick Random Player
      await tester.tap(find.byKey(const Key('random_player_btn')));
      await tester.pump();
      expect(pickedPlayer, isNotNull);
      expect(pickedPlayer, inInclusiveRange(0, 3));

      // Pick Random Opponent (must not be selfSeatIndex 1)
      await tester.tap(find.byKey(const Key('random_opponent_btn')));
      await tester.pump();
      expect(pickedOpponent, isNotNull);
      expect(pickedOpponent, isNot(equals(1)));

      // Reset Game
      await tester.tap(find.byKey(const Key('reset_game_btn')));
      await tester.pump();
      expect(resetTriggered, isTrue);
    });

    testWidgets('T5.7.3: ResetGameDialog displays prompt and handles cancel / confirm', (tester) async {
      bool confirmed = false;
      bool cancelled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                key: const Key('open_dialog_btn'),
                onPressed: () {
                  ResetGameDialog.show(
                    ctx,
                    startingLife: 40,
                    onConfirm: () => confirmed = true,
                    onCancel: () => cancelled = true,
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.byKey(const Key('open_dialog_btn')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('reset_game_dialog')), findsOneWidget);
      expect(find.textContaining('Life totals will return to 40'), findsOneWidget);

      // Cancel button
      await tester.tap(find.byKey(const Key('cancel_reset_game_btn')));
      await tester.pumpAndSettle();
      expect(cancelled, isTrue);
      expect(find.byKey(const Key('reset_game_dialog')), findsNothing);

      // Open again to confirm
      await tester.tap(find.byKey(const Key('open_dialog_btn')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('confirm_reset_game_btn')));
      await tester.pumpAndSettle();
      expect(confirmed, isTrue);
      expect(find.byKey(const Key('reset_game_dialog')), findsNothing);
    });
  });
}
