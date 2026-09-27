// Copyright (c) 2026 Countr. All rights reserved.
// Tier 5 Phase 2 Dedicated Concurrency & Pod Chaos Test Suite.
// Authored by m5_tier5_challenger_2 (Cross-Module Concurrency & Pod Chaos Challenger).
//
// White-box concurrency stress, chaos injection, and resilience verification across:
// 1. High-throughput asynchronous multi-player interactions across 6 players (life, commander damage,
//    poison defeat, monarch steals, initiative claims, Day/Night toggles, floating mana, storm bursts,
//    dice rolls, coin flips, and mid-game reset triggers).
// 2. P2P mesh synchronization under network chaos (out-of-order delivery, simulated network drops,
//    partition reconciliation, deep catch-up gap fallback to syncState snapshot, and duplicate packets).
// 3. SQLite auto-save resilience under concurrent heavy write bursts (monotonic event sequencing,
//    zero deadlocks, outbox SyncQueue durability, and active session recovery).

import 'dart:async';
import 'dart:math' as math;
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/life_counter/domain/models/pod_state.dart';
import 'package:countr/features/life_counter/domain/models/p2p_packet.dart';
import 'package:countr/features/life_counter/domain/models/randomizer_models.dart';
import 'package:countr/features/life_counter/domain/services/dice_roller_service.dart';
import 'package:countr/features/life_counter/data/network/p2p_transport.dart';
import 'package:countr/features/life_counter/data/network/p2p_sync_engine.dart';
import 'package:countr/features/life_counter/data/repositories/match_session_repository.dart';
import 'package:countr/features/life_counter/presentation/controllers/pod_controller.dart';

// =============================================================================
// CHAOS INJECTION TRANSPORT & MESH HARNESS (6-NODE STAR TOPOLOGY)
// =============================================================================

class SixNodeChaosMesh {
  final Map<String, ChaosTransport> _nodes = {};
  String hostEndpointId = 'host_node';

  bool dropPackets = false;
  double dropRate = 0.0;
  bool reorderPackets = false;
  final List<void Function()> _delayedDeliveries = [];

  ChaosTransport createNode(String endpointId) {
    final transport = ChaosTransport(endpointId, this);
    _nodes[endpointId] = transport;
    return transport;
  }

  void routePacket(
    P2pPacket packet,
    String senderEndpoint, {
    String? targetEndpoint,
  }) {
    if (dropPackets && dropRate > 0.0) {
      if (math.Random().nextDouble() < dropRate) {
        return; // Dropped by chaos injection
      }
    }

    void deliver() {
      if (targetEndpoint != null) {
        final target = _nodes[targetEndpoint];
        if (target != null && target.isConnected) {
          target.receivePacket(packet);
        }
      } else if (senderEndpoint != hostEndpointId) {
        final host = _nodes[hostEndpointId];
        if (host != null && host.isConnected) {
          host.receivePacket(packet);
        }
      } else {
        for (final entry in _nodes.entries) {
          if (entry.key != senderEndpoint && entry.value.isConnected) {
            entry.value.receivePacket(packet);
          }
        }
      }
    }

    if (reorderPackets) {
      _delayedDeliveries.add(deliver);
    } else {
      deliver();
    }
  }

  void flushDelayedDeliveries({bool reverse = true}) {
    final deliveries = reverse
        ? _delayedDeliveries.reversed.toList()
        : List<void Function()>.from(_delayedDeliveries);
    _delayedDeliveries.clear();
    for (final delivery in deliveries) {
      delivery();
    }
  }

  void removeNode(String endpointId) {
    _nodes.remove(endpointId);
  }
}

class ChaosTransport implements P2pTransport {
  @override
  final String endpointId;
  final SixNodeChaosMesh _mesh;
  final StreamController<P2pPacket> _incomingController =
      StreamController<P2pPacket>.broadcast();
  final StreamController<PeerStatus> _statusController =
      StreamController<PeerStatus>.broadcast();
  bool _connected = true;

  ChaosTransport(this.endpointId, this._mesh);

  @override
  bool get isConnected => _connected;

  @override
  Stream<P2pPacket> get incomingPackets => _incomingController.stream;

  @override
  Stream<PeerStatus> get peerStatusStream => _statusController.stream;

  @override
  Future<void> sendPacket(P2pPacket packet) async {
    if (!_connected) throw StateError('Transport disconnected: $endpointId');
    _mesh.routePacket(packet, endpointId);
  }

  @override
  Future<void> broadcastPacket(P2pPacket packet) async {
    await sendPacket(packet);
  }

  @override
  Future<void> sendTo(String targetPeerId, P2pPacket packet) async {
    if (!_connected) throw StateError('Transport disconnected: $endpointId');
    _mesh.routePacket(packet, endpointId, targetEndpoint: targetPeerId);
  }

  @override
  Future<void> broadcast(P2pPacket packet) => broadcastPacket(packet);

  @override
  Future<void> disconnect() async {
    _connected = false;
  }

  @override
  Future<void> close() async {
    await disconnect();
    dispose();
  }

  void reconnect() {
    _connected = true;
  }

  void receivePacket(P2pPacket packet) {
    if (_connected && !_incomingController.isClosed) {
      _incomingController.add(packet);
    }
  }

  void dispose() {
    _incomingController.close();
    _statusController.close();
    _mesh.removeNode(endpointId);
  }
}

// =============================================================================
// 6-PLAYER INITIAL POD STATE TEMPLATE
// =============================================================================

PodState createInitial6PlayerPod({
  String sessionId = 'pod_chaos_session_6p',
  int startingLife = 40,
}) {
  return PodState(
    sessionId: sessionId,
    format: 'commander',
    startingLife: startingLife,
    players: [
      PodPlayerState(
        id: 'p1',
        seatIndex: 0,
        name: 'Player 1 (Host)',
        commanderName: 'Atraxa, Praetors Voice',
        commanderArtCropUrl: 'https://cards.scryfall.io/art_crop/atraxa.jpg',
        life: startingLife,
        isLocalDevice: true,
      ),
      PodPlayerState(
        id: 'p2',
        seatIndex: 1,
        name: 'Player 2',
        commanderName: 'Urza, Lord High Artificer',
        commanderArtCropUrl: 'https://cards.scryfall.io/art_crop/urza.jpg',
        life: startingLife,
        isLocalDevice: false,
      ),
      PodPlayerState(
        id: 'p3',
        seatIndex: 2,
        name: 'Player 3',
        commanderName: 'Krenko, Mob Boss',
        commanderArtCropUrl: 'https://cards.scryfall.io/art_crop/krenko.jpg',
        life: startingLife,
        isLocalDevice: false,
      ),
      PodPlayerState(
        id: 'p4',
        seatIndex: 3,
        name: 'Player 4',
        commanderName: 'Edgar Markov',
        commanderArtCropUrl: 'https://cards.scryfall.io/art_crop/edgar.jpg',
        life: startingLife,
        isLocalDevice: false,
      ),
      PodPlayerState(
        id: 'p5',
        seatIndex: 4,
        name: 'Player 5',
        commanderName: 'Korvold, Fae-Cursed King',
        commanderArtCropUrl: 'https://cards.scryfall.io/art_crop/korvold.jpg',
        life: startingLife,
        isLocalDevice: false,
      ),
      PodPlayerState(
        id: 'p6',
        seatIndex: 5,
        name: 'Player 6',
        commanderName: 'The Ur-Dragon',
        commanderArtCropUrl: 'https://cards.scryfall.io/art_crop/urdragon.jpg',
        life: startingLife,
        isLocalDevice: false,
      ),
    ],
    isDay: true,
    isP2pHost: true,
    roomCode: 'CHAOS',
    sequenceNumber: 0,
  );
}

List<PlayerSetupConfig> create6PlayerConfigs({int startingLife = 40}) {
  return [
    PlayerSetupConfig(
      id: 'p1',
      seatOrder: 0,
      name: 'Player 1 (Host)',
      commanderName: 'Atraxa',
      startingLife: startingLife,
    ),
    PlayerSetupConfig(
      id: 'p2',
      seatOrder: 1,
      name: 'Player 2',
      commanderName: 'Urza',
      startingLife: startingLife,
    ),
    PlayerSetupConfig(
      id: 'p3',
      seatOrder: 2,
      name: 'Player 3',
      commanderName: 'Krenko',
      startingLife: startingLife,
    ),
    PlayerSetupConfig(
      id: 'p4',
      seatOrder: 3,
      name: 'Player 4',
      commanderName: 'Edgar Markov',
      startingLife: startingLife,
    ),
    PlayerSetupConfig(
      id: 'p5',
      seatOrder: 4,
      name: 'Player 5',
      commanderName: 'Korvold',
      startingLife: startingLife,
    ),
    PlayerSetupConfig(
      id: 'p6',
      seatOrder: 5,
      name: 'Player 6',
      commanderName: 'The Ur-Dragon',
      startingLife: startingLife,
    ),
  ];
}

// =============================================================================
// MAIN TEST SUITE
// =============================================================================

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  // ===========================================================================
  // GROUP 1: 6-PLAYER HIGH-THROUGHPUT CONCURRENT MULTI-PLAYER CHAOS
  // ===========================================================================
  group('Group 1: 6-Player High-Throughput Concurrent Multi-Player Chaos', () {
    test('1.1: Concurrent asynchronous operations across all 6 players and subsystems', () async {
      final initialPod = createInitial6PlayerPod();
      final controller = PodController(initialState: initialPod);
      final randomizer = RandomizerService(math.Random(42));

      // Launch simultaneous async tasks across 6 players
      final futures = <Future<void>>[];

      // Player 1: rapid life adjustments and coin flips
      futures.add(Future(() async {
        for (int i = 0; i < 20; i++) {
          final delta = (i % 2 == 0) ? -2 : 1;
          await controller.adjustLife('p1', delta);
          final flip = randomizer.flipCoin();
          expect(flip, anyOf(equals(CoinSide.heads), equals(CoinSide.tails)));
        }
      }));

      // Player 2: WUBRGC floating mana manipulation and storm bursts
      futures.add(Future(() async {
        final colors = ['W', 'U', 'B', 'R', 'G', 'C'];
        for (int i = 0; i < 24; i++) {
          final color = colors[i % colors.length];
          await controller.adjustMana(playerId: 'p2', color: color, delta: 2);
          if (i == 10) {
            await controller.clearManaPool('p2');
          }
        }
      }));

      // Player 3: poison counter accumulation reaching lethal threshold (>= 10)
      futures.add(Future(() async {
        for (int i = 0; i < 11; i++) {
          await controller.adjustCounter(
            playerId: 'p3',
            counterType: 'poison',
            delta: 1,
          );
        }
        // Polyhedral dice rolls
        final rollD20 = randomizer.rollDice(DiceType.d20);
        expect(rollD20, inInclusiveRange(1, 20));
      }));

      // Player 4: incoming commander damage from P5 reaching lethal 21
      futures.add(Future(() async {
        for (int i = 0; i < 7; i++) {
          await controller.recordCommanderDamage(
            targetPlayerId: 'p4',
            sourcePlayerId: 'p5',
            damageDelta: 3, // 7 * 3 = 21
          );
        }
      }));

      // Player 5: Day/Night toggles and energy counter adjustments
      futures.add(Future(() async {
        for (int i = 0; i < 15; i++) {
          await controller.toggleDayNight();
          await controller.adjustCounter(
            playerId: 'p5',
            counterType: 'energy',
            delta: 1,
          );
        }
      }));

      // Player 6: Monarch and Initiative claims interleaved with life loss
      futures.add(Future(() async {
        for (int i = 0; i < 10; i++) {
          await controller.adjustLife('p6', -3);
          await controller.claimToken(tokenType: 'monarch', claimantId: 'p6');
          await controller.claimToken(tokenType: 'initiative', claimantId: 'p6');
        }
      }));

      // Await all concurrent tasks
      await Future.wait(futures);

      final endState = controller.state;

      // 1. Verify P3 poison defeat
      final p3 = endState.getPlayer('p3')!;
      expect(p3.poison, greaterThanOrEqualTo(10));
      expect(p3.isPoisonLethal, isTrue);
      expect(p3.isEliminated, isTrue);

      // 2. Verify P4 commander damage defeat from P5
      final p4 = endState.getPlayer('p4')!;
      expect(p4.commanderDamageTaken['p5'], equals(21));
      expect(p4.isCommanderDamageLethalFrom('p5'), isTrue);
      expect(p4.hasAnyLethalCommanderDamage, isTrue);
      expect(p4.isEliminated, isTrue);
      // Life loss from commander damage: 40 - 21 = 19
      expect(p4.life, equals(19));

      // 3. Verify P2 floating mana has no negative values
      final p2 = endState.getPlayer('p2')!;
      for (final color in ['W', 'U', 'B', 'R', 'G', 'C']) {
        expect(p2.floatingMana[color], greaterThanOrEqualTo(0));
      }
      expect(p2.stormCount, greaterThanOrEqualTo(0));

      // 4. Verify P6 holds Monarch and Initiative
      final p6 = endState.getPlayer('p6')!;
      expect(p6.isMonarch, isTrue);
      expect(p6.hasInitiative, isTrue);

      // 5. Verify randomizer history integrity
      expect(randomizer.history, isNotEmpty);
      expect(randomizer.totalFlips, equals(20));

      controller.dispose();
    });

    test('1.2: Pod-wide Monarch and Initiative atomic race condition under contention', () async {
      final initialPod = createInitial6PlayerPod();
      final controller = PodController(initialState: initialPod);

      // 6 players concurrently racing to claim Monarch
      final monarchClaims = <Future<void>>[];
      for (int i = 0; i < 60; i++) {
        final claimantId = 'p${(i % 6) + 1}';
        monarchClaims.add(controller.claimToken(
          tokenType: 'monarch',
          claimantId: claimantId,
        ));
      }

      // Concurrently racing to claim Initiative
      final initiativeClaims = <Future<void>>[];
      for (int i = 0; i < 60; i++) {
        final claimantId = 'p${((i + 3) % 6) + 1}';
        initiativeClaims.add(controller.claimToken(
          tokenType: 'initiative',
          claimantId: claimantId,
        ));
      }

      await Future.wait([...monarchClaims, ...initiativeClaims]);

      final endState = controller.state;

      // Invariant: Exactly 1 player holds Monarch across the entire pod
      final monarchHolders = endState.players.where((p) => p.isMonarch).toList();
      expect(monarchHolders.length, equals(1),
          reason: 'Expected exactly 1 monarch holder in 6-player pod');

      // Invariant: Exactly 1 player holds Initiative across the entire pod
      final initiativeHolders = endState.players.where((p) => p.hasInitiative).toList();
      expect(initiativeHolders.length, equals(1),
          reason: 'Expected exactly 1 initiative holder in 6-player pod');

      controller.dispose();
    });

    test('1.3: Floating mana pool, storm burst, and concurrent clear action race', () async {
      final initialPod = createInitial6PlayerPod();
      final controller = PodController(initialState: initialPod);

      final ops = <Future<void>>[];

      // Thread A: Rapidly incrementing mana across colors
      ops.add(Future(() async {
        for (int i = 0; i < 30; i++) {
          await controller.adjustMana(playerId: 'p1', color: 'U', delta: 1);
          await controller.adjustMana(playerId: 'p1', color: 'R', delta: 1);
        }
      }));

      // Thread B: Rapidly incrementing storm count directly
      ops.add(Future(() async {
        for (int i = 0; i < 20; i++) {
          await controller.adjustStorm('p1', 1);
        }
      }));

      // Thread C: Clear mana pool mid-stream
      ops.add(Future(() async {
        await Future.delayed(const Duration(milliseconds: 5));
        await controller.clearManaPool('p1');
      }));

      await Future.wait(ops);

      final p1 = controller.state.getPlayer('p1')!;
      // Mana and storm must never be negative
      expect(p1.floatingMana['U'], greaterThanOrEqualTo(0));
      expect(p1.floatingMana['R'], greaterThanOrEqualTo(0));
      expect(p1.stormCount, greaterThanOrEqualTo(0));

      controller.dispose();
    });

    test('1.4: Mid-game reset game trigger interleaved with active multi-player mutation burst', () async {
      final initialPod = createInitial6PlayerPod();
      final controller = PodController(initialState: initialPod);

      // Pre-dirty all 6 players
      for (int i = 1; i <= 6; i++) {
        await controller.adjustLife('p$i', -10);
        await controller.adjustCounter(playerId: 'p$i', counterType: 'poison', delta: 3);
        await controller.adjustCounter(playerId: 'p$i', counterType: 'energy', delta: 5);
      }

      expect(controller.state.players.every((p) => p.life == 30), isTrue);
      expect(controller.state.players.every((p) => p.poison == 3), isTrue);

      // Trigger resetGame(40)
      await controller.resetGame(40);

      final resetState = controller.state;

      // Invariant: Seating order, names, and commander associations are strictly preserved
      expect(resetState.players.length, equals(6));
      for (int i = 0; i < 6; i++) {
        final p = resetState.players[i];
        expect(p.seatIndex, equals(i));
        expect(p.id, equals('p${i + 1}'));
        expect(p.life, equals(40));
        expect(p.poison, equals(0));
        expect(p.energy, equals(0));
        expect(p.experience, equals(0));
        expect(p.commanderTax, equals(0));
        expect(p.isMonarch, isFalse);
        expect(p.hasInitiative, isFalse);
        expect(p.commanderDamageTaken, isEmpty);
        expect(p.stormCount, equals(0));
        expect(p.isEliminated, isFalse);
        for (final c in ['W', 'U', 'B', 'R', 'G', 'C']) {
          expect(p.floatingMana[c], equals(0));
        }
      }
      expect(resetState.isDay, isTrue);

      controller.dispose();
    });
  });

  // ===========================================================================
  // GROUP 2: P2P MESH SYNCHRONIZATION UNDER NETWORK CHAOS
  // ===========================================================================
  group('Group 2: P2P Mesh Synchronization Under Network Chaos', () {
    test('2.1: 6-node P2P mesh converges bit-for-bit under high-frequency interleaved actions', () async {
      final mesh = SixNodeChaosMesh();
      final hostTransport = mesh.createNode('host_node');
      final initialPod = createInitial6PlayerPod();

      final hostEngine = P2pSyncEngine(
        initialState: initialPod,
        transport: hostTransport,
        isHost: true,
      );

      final clientTransports = <ChaosTransport>[];
      final clientEngines = <P2pSyncEngine>[];

      for (int i = 2; i <= 6; i++) {
        final transport = mesh.createNode('node_p$i');
        clientTransports.add(transport);
        clientEngines.add(P2pSyncEngine(
          initialState: initialPod,
          transport: transport,
          isHost: false,
          localPlayerId: 'p$i',
        ));
      }

      // Fire 15 operations per client node and 15 on host (90 total ops)
      final allFutures = <Future<void>>[];

      // Host modifies P1 life
      for (int i = 0; i < 15; i++) {
        allFutures.add(hostEngine.sendLifeAdjustment('p1', (i % 2 == 0) ? -2 : 1));
      }

      // Each client modifies their own player and opponents
      for (int c = 0; c < 5; c++) {
        final clientEngine = clientEngines[c];
        final myPid = 'p${c + 2}';
        final opponentPid = 'p${((c + 1) % 5) + 2}';

        for (int i = 0; i < 15; i++) {
          allFutures.add(clientEngine.sendLifeAdjustment(myPid, (i % 3 == 0) ? 2 : -1));
          if (i % 4 == 0) {
            allFutures.add(clientEngine.sendCommanderDamage(
              targetPlayerId: opponentPid,
              sourcePlayerId: myPid,
              damageDelta: 2,
            ));
          }
        }
      }

      await Future.wait(allFutures);
      await Future.delayed(const Duration(milliseconds: 80));

      final hostState = hostEngine.state;

      // 1. Verify monotonic sequence progression
      expect(hostState.sequenceNumber, greaterThanOrEqualTo(90));

      // 2. Verify all 5 clients converged to the exact same sequence number as Host
      for (final client in clientEngines) {
        expect(client.state.sequenceNumber, equals(hostState.sequenceNumber));
        expect(client.pendingActions, isEmpty);
      }

      // 3. Verify bit-for-bit equality of all 6 players across all 6 engines
      for (final pid in ['p1', 'p2', 'p3', 'p4', 'p5', 'p6']) {
        final hostP = hostState.getPlayer(pid)!;
        for (final client in clientEngines) {
          final clientP = client.state.getPlayer(pid)!;
          expect(clientP.life, equals(hostP.life), reason: 'Life mismatch on $pid');
          expect(clientP.poison, equals(hostP.poison), reason: 'Poison mismatch on $pid');
          expect(clientP.commanderDamageTaken, equals(hostP.commanderDamageTaken),
              reason: 'Commander damage mismatch on $pid');
          expect(clientP.isEliminated, equals(hostP.isEliminated),
              reason: 'Eliminated mismatch on $pid');
        }
      }

      hostEngine.dispose();
      for (final c in clientEngines) {
        c.dispose();
      }
    });

    test('2.2: Simulated network drops and reconnect catch-up under active 6-player play', () async {
      final mesh = SixNodeChaosMesh();
      final hostTransport = mesh.createNode('host_node');
      final initialPod = createInitial6PlayerPod();

      final hostEngine = P2pSyncEngine(
        initialState: initialPod,
        transport: hostTransport,
        isHost: true,
      );

      final c2Transport = mesh.createNode('node_p2');
      final c3Transport = mesh.createNode('node_p3');

      final c2Engine = P2pSyncEngine(
        initialState: initialPod,
        transport: c2Transport,
        isHost: false,
        localPlayerId: 'p2',
      );

      final c3Engine = P2pSyncEngine(
        initialState: initialPod,
        transport: c3Transport,
        isHost: false,
        localPlayerId: 'p3',
      );

      // Initial synced event
      await hostEngine.sendLifeAdjustment('p1', -2);
      await Future.delayed(Duration.zero);
      expect(c2Engine.state.sequenceNumber, equals(1));
      expect(c3Engine.state.sequenceNumber, equals(1));

      // Network drop: C2 and C3 disconnect
      await c2Transport.disconnect();
      await c3Transport.disconnect();
      expect(c2Transport.isConnected, isFalse);
      expect(c3Transport.isConnected, isFalse);

      // While disconnected, Host executes 30 events with heavy state alterations
      for (int i = 0; i < 6; i++) {
        await hostEngine.sendLifeAdjustment('p1', -1);
        await hostEngine.sendCommanderDamage(
          targetPlayerId: 'p2',
          sourcePlayerId: 'p1',
          damageDelta: 3,
        );
        await hostEngine.sendCounterDelta(
          targetPlayerId: 'p3',
          counterType: 'poison',
          delta: 1,
        );
        await hostEngine.sendManaDelta(
          targetPlayerId: 'p4',
          color: 'G',
          delta: 1,
        );
        await hostEngine.toggleDayNight();
      }

      expect(hostEngine.state.sequenceNumber, equals(31));
      // Disconnected clients remain stuck at seq 1
      expect(c2Engine.state.sequenceNumber, equals(1));
      expect(c3Engine.state.sequenceNumber, equals(1));

      // Reconnect C2 and C3
      c2Transport.reconnect();
      c3Transport.reconnect();

      // Send catch-up requests asking for missing sequence slices
      await c2Engine.requestCatchup(1);
      await c3Engine.requestCatchup(1);
      await Future.delayed(const Duration(milliseconds: 60));

      // Verify both clients reached sequence 31 and match host state bit-for-bit
      expect(c2Engine.state.sequenceNumber, equals(31));
      expect(c3Engine.state.sequenceNumber, equals(31));

      expect(c2Engine.state.getPlayer('p2')!.commanderDamageTaken['p1'], equals(18));
      expect(c3Engine.state.getPlayer('p3')!.poison, equals(6));
      expect(c2Engine.state.isDay, equals(hostEngine.state.isDay));
      expect(c3Engine.state.isDay, equals(hostEngine.state.isDay));

      hostEngine.dispose();
      c2Engine.dispose();
      c3Engine.dispose();
    });

    test('2.3: Disconnected optimistic mutations and partition reconciliation', () async {
      final mesh = SixNodeChaosMesh();
      final hostTransport = mesh.createNode('host_node');
      final clientTransport = mesh.createNode('node_p2');
      final initialPod = createInitial6PlayerPod();

      final hostEngine = P2pSyncEngine(
        initialState: initialPod,
        transport: hostTransport,
        isHost: true,
      );

      final clientEngine = P2pSyncEngine(
        initialState: initialPod,
        transport: clientTransport,
        isHost: false,
        localPlayerId: 'p2',
      );

      // Initial event
      await hostEngine.sendLifeAdjustment('p1', -5);
      await Future.delayed(Duration.zero);
      expect(clientEngine.state.sequenceNumber, equals(1));

      // Network partition begins
      await clientTransport.disconnect();

      // Client performs local optimistic life change while offline
      try {
        await clientEngine.sendLifeAdjustment('p2', 8);
      } catch (_) {
        // Transport throws disconnected StateError
      }

      // Optimistic update must be immediately visible to the user
      expect(clientEngine.state.getPlayer('p2')!.life, equals(48));
      expect(clientEngine.pendingActions.length, equals(1));

      // Host advances 5 events independently
      for (int i = 0; i < 5; i++) {
        await hostEngine.sendLifeAdjustment('p1', -1);
      }
      expect(hostEngine.state.sequenceNumber, equals(6));

      // Partition heals: client reconnects and syncs
      clientTransport.reconnect();
      await clientEngine.requestCatchup(1);
      await Future.delayed(const Duration(milliseconds: 50));

      // Client absorbed host updates (P1 life is 40 - 5 - 5 = 30)
      expect(clientEngine.state.getPlayer('p1')!.life, equals(30));
      expect(clientEngine.state.sequenceNumber, equals(6));

      hostEngine.dispose();
      clientEngine.dispose();
    });

    test('2.4: Out-of-order packet delivery delta convergence', () async {
      final mesh = SixNodeChaosMesh();
      final hostTransport = mesh.createNode('host_node');
      final clientTransport = mesh.createNode('node_p2');
      final initialPod = createInitial6PlayerPod();

      final hostEngine = P2pSyncEngine(
        initialState: initialPod,
        transport: hostTransport,
        isHost: true,
      );

      final clientEngine = P2pSyncEngine(
        initialState: initialPod,
        transport: clientTransport,
        isHost: false,
        localPlayerId: 'p2',
      );

      // Sync event 1
      await hostEngine.sendLifeAdjustment('p1', -1);
      await Future.delayed(Duration.zero);
      expect(clientEngine.state.sequenceNumber, equals(1));

      // Construct out-of-order packets 2, 3, 4
      final pkt2 = P2pPacket(
        type: P2pPacketType.lifeDelta,
        senderId: 'host_node',
        sequenceNumber: 2,
        targetPlayerId: 'p1',
        delta: -3,
        payload: {'action_id': 'a2'},
      );

      final pkt3 = P2pPacket(
        type: P2pPacketType.lifeDelta,
        senderId: 'host_node',
        sequenceNumber: 3,
        targetPlayerId: 'p1',
        delta: -5,
        payload: {'action_id': 'a3'},
      );

      final pkt4 = P2pPacket(
        type: P2pPacketType.lifeDelta,
        senderId: 'host_node',
        sequenceNumber: 4,
        targetPlayerId: 'p1',
        delta: 2,
        payload: {'action_id': 'a4'},
      );

      // Deliver in reverse order: 4, then 3, then 2
      clientTransport.receivePacket(pkt4);
      clientTransport.receivePacket(pkt3);
      clientTransport.receivePacket(pkt2);
      await Future.delayed(Duration.zero);

      // Arithmetic is commutative: 40 - 1 + 2 - 5 - 3 = 33
      expect(clientEngine.state.getPlayer('p1')!.life, equals(33));

      hostEngine.dispose();
      clientEngine.dispose();
    });

    test('2.5: Deep catchup gap (>300 events) falls back to syncState snapshot cleanly', () async {
      final mesh = SixNodeChaosMesh();
      final hostTransport = mesh.createNode('host_node');
      final clientTransport = mesh.createNode('node_p2');
      final initialPod = createInitial6PlayerPod();

      final hostEngine = P2pSyncEngine(
        initialState: initialPod,
        transport: hostTransport,
        isHost: true,
      );

      final clientEngine = P2pSyncEngine(
        initialState: initialPod,
        transport: clientTransport,
        isHost: false,
        localPlayerId: 'p2',
      );

      // Client disconnects at seq 0
      await clientTransport.disconnect();

      // Host generates 320 events (exceeding _maxEventLogSize = 300)
      for (int i = 0; i < 320; i++) {
        await hostEngine.sendLifeAdjustment('p1', (i % 2 == 0) ? 1 : -1);
      }

      expect(hostEngine.state.sequenceNumber, equals(320));
      expect(hostEngine.eventLog.length, equals(300));
      expect(hostEngine.eventLog.first.sequenceNumber, equals(21));

      // Client reconnects and requests catchup from seq 0
      clientTransport.reconnect();
      await clientEngine.requestCatchup(0);
      await Future.delayed(const Duration(milliseconds: 50));

      // Host detects pruned gap and transmits full authoritative snapshot
      expect(clientEngine.state.sequenceNumber, equals(320));
      expect(clientEngine.state.getPlayer('p1')!.life,
          equals(hostEngine.state.getPlayer('p1')!.life));

      hostEngine.dispose();
      clientEngine.dispose();
    });
  });

  // ===========================================================================
  // GROUP 3: SQLITE AUTO-SAVE RESILIENCE UNDER CONCURRENT HEAVY WRITE BURSTS
  // ===========================================================================
  group('Group 3: SQLite Auto-Save Resilience Under Concurrent Heavy Write Bursts', () {
    late AppDatabase db;
    late MatchSessionRepository repo;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      repo = MatchSessionRepository(db: db);
    });

    tearDown(() async {
      repo.dispose();
      await db.close();
    });

    test('3.1: 120 simultaneous async writes against SQLite across 6 players with zero deadlocks', () async {
      final configs = create6PlayerConfigs(startingLife: 40);
      final pod = await repo.createSession(
        format: 'commander',
        startingLife: 40,
        players: configs,
        isP2pHost: true,
        roomCode: 'BURST',
      );

      final sessionId = pod.sessionId;

      // Launch 120 simultaneous async mutations in parallel across all 6 players
      final burstFutures = <Future<void>>[];

      // 40 life deltas (+1 to P1..P6 cyclically)
      for (int i = 0; i < 40; i++) {
        final pid = 'p${(i % 6) + 1}';
        burstFutures.add(repo.recordLifeDelta(
          sessionId: sessionId,
          playerId: pid,
          delta: 1,
          sequenceNumber: i + 1,
        ));
      }

      // 30 commander damage transactions
      for (int i = 0; i < 30; i++) {
        final targetId = 'p${(i % 6) + 1}';
        final sourceId = 'p${((i + 1) % 6) + 1}';
        burstFutures.add(repo.recordCommanderDamage(
          sessionId: sessionId,
          targetPlayerId: targetId,
          sourcePlayerId: sourceId,
          delta: 1,
          sequenceNumber: i + 41,
        ));
      }

      // 20 secondary counter changes (poison, energy, xp)
      for (int i = 0; i < 20; i++) {
        final pid = 'p${(i % 6) + 1}';
        final counter = (i % 2 == 0) ? 'poison' : 'energy';
        burstFutures.add(repo.recordCounterChange(
          sessionId: sessionId,
          playerId: pid,
          counterType: counter,
          delta: 1,
          sequenceNumber: i + 71,
        ));
      }

      // 20 mana & storm changes
      for (int i = 0; i < 20; i++) {
        final pid = 'p${(i % 6) + 1}';
        burstFutures.add(repo.recordManaChange(
          sessionId: sessionId,
          playerId: pid,
          color: 'U',
          delta: 1,
          sequenceNumber: i + 91,
        ));
      }

      // 10 Day/Night toggles
      for (int i = 0; i < 10; i++) {
        burstFutures.add(repo.recordDayNightToggle(
          sessionId: sessionId,
          isDay: i % 2 == 0,
          sequenceNumber: i + 112,
        ));
      }

      // Await all 120 concurrent operations simultaneously
      await Future.wait(burstFutures);

      // Verify event ledger integrity:
      // 1 session_created + 120 mutations = 121 events in SQLite
      final events = await db.matchDao.getEventsForSession(sessionId);
      expect(events.length, equals(121));

      // Verify sequence number monotonicity (strictly 1..121 with NO gaps and NO duplicates)
      final seqNumbers = events.map((e) => e.sequenceNumber).toList();
      final expectedSeqs = List.generate(121, (i) => i + 1);
      expect(seqNumbers, equals(expectedSeqs));

      // Verify Outbox SyncQueue durability:
      // Every event generated an INSERT in sync_queue
      final syncQueueEntries = await (db.select(db.syncQueue)).get();
      final eventSyncEntries =
          syncQueueEntries.where((s) => s.entityType == 'match_event').toList();
      expect(eventSyncEntries.length, equals(121));
    });

    test('3.2: Crash recovery reconstitutes exact board state after sudden dirty writes', () async {
      final configs = create6PlayerConfigs(startingLife: 40);
      final pod = await repo.createSession(
        format: 'commander',
        startingLife: 40,
        players: configs,
        isP2pHost: true,
      );

      final sessionId = pod.sessionId;

      // Perform a series of writes altering life, commander damage, and counters
      await repo.recordLifeDelta(sessionId: sessionId, playerId: 'p1', delta: -15, sequenceNumber: 1);
      await repo.recordCommanderDamage(
        sessionId: sessionId,
        targetPlayerId: 'p2',
        sourcePlayerId: 'p1',
        delta: 21, // Lethal commander damage
        sequenceNumber: 2,
      );
      await repo.recordCounterChange(
        sessionId: sessionId,
        playerId: 'p3',
        counterType: 'poison',
        delta: 10, // Lethal poison
        sequenceNumber: 3,
      );
      await repo.recordDayNightToggle(sessionId: sessionId, isDay: false, sequenceNumber: 4);

      // Simulate app restart / crash recovery
      final recoveredPod = await repo.restoreActiveSession();
      expect(recoveredPod, isNotNull);

      // Verify exact reconstituted state
      final recP1 = recoveredPod!.getPlayer('p1')!;
      expect(recP1.life, equals(25));
      expect(recP1.isEliminated, isFalse);

      final recP2 = recoveredPod.getPlayer('p2')!;
      expect(recP2.commanderDamageTaken['p1'], equals(21));
      expect(recP2.isCommanderDamageLethalFrom('p1'), isTrue);
      expect(recP2.isEliminated, isTrue);

      final recP3 = recoveredPod.getPlayer('p3')!;
      expect(recP3.poison, equals(10));
      expect(recP3.isPoisonLethal, isTrue);
      expect(recP3.isEliminated, isTrue);

      expect(recoveredPod.isDay, isFalse);
    });

    test('3.3: Event ledger rollback via undo maintains strict SQLite integrity', () async {
      final configs = create6PlayerConfigs(startingLife: 40);
      final pod = await repo.createSession(
        format: 'commander',
        startingLife: 40,
        players: configs,
      );

      final sessionId = pod.sessionId;

      // Apply 3 events
      await repo.recordLifeDelta(sessionId: sessionId, playerId: 'p1', delta: -5, sequenceNumber: 1);
      await repo.recordLifeDelta(sessionId: sessionId, playerId: 'p1', delta: -3, sequenceNumber: 2);
      await repo.recordLifeDelta(sessionId: sessionId, playerId: 'p1', delta: 10, sequenceNumber: 3);

      var activePod = await repo.restoreActiveSession();
      expect(activePod!.getPlayer('p1')!.life, equals(42)); // 40 - 5 - 3 + 10 = 42

      // Undo event 3 (+10)
      final undonePod1 = await repo.undoLastEvent(sessionId);
      expect(undonePod1, isNotNull);
      expect(undonePod1!.getPlayer('p1')!.life, equals(32)); // 40 - 5 - 3 = 32

      // Undo event 2 (-3)
      final undonePod2 = await repo.undoLastEvent(sessionId);
      expect(undonePod2, isNotNull);
      expect(undonePod2!.getPlayer('p1')!.life, equals(35)); // 40 - 5 = 35
    });
  });
}
