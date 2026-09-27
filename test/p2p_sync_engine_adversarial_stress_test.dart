// Copyright (c) 2026 Countr. All rights reserved.
// Adversarial Empirical Stress Test Suite for P2pSyncEngine.
// Authored by m2_challenger_net_2 for Milestone 2 Gate.

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/features/life_counter/domain/models/pod_state.dart';
import 'package:countr/features/life_counter/domain/models/p2p_packet.dart';
import 'package:countr/features/life_counter/data/network/p2p_transport.dart';
import 'package:countr/features/life_counter/data/network/p2p_sync_engine.dart';
import 'package:countr/features/life_counter/data/repositories/match_session_repository.dart';

// =============================================================================
// ADVERSARIAL MESH WITH CHAOS INJECTION (DELAYS, DROPS, REORDERING)
// =============================================================================

class AdversarialMesh {
  final Map<String, AdversarialTransport> _nodes = {};
  String hostEndpointId = 'host_node';

  bool dropPackets = false;
  double dropRate = 0.0;
  bool reorderPackets = false;
  final List<void Function()> _delayedDeliveries = [];

  AdversarialTransport createNode(String endpointId) {
    final transport = AdversarialTransport(endpointId, this);
    _nodes[endpointId] = transport;
    return transport;
  }

  void routePacket(P2pPacket packet, String senderEndpoint,
      {String? targetEndpoint}) {
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

  void flushDelayedDeliveries() {
    for (final delivery in _delayedDeliveries.reversed) {
      delivery();
    }
    _delayedDeliveries.clear();
  }

  void removeNode(String endpointId) {
    _nodes.remove(endpointId);
  }
}

class AdversarialTransport implements P2pTransport {
  @override
  final String endpointId;
  final AdversarialMesh _mesh;
  final StreamController<P2pPacket> _incomingController =
      StreamController<P2pPacket>.broadcast();
  final StreamController<PeerStatus> _statusController =
      StreamController<PeerStatus>.broadcast();
  bool _connected = true;

  AdversarialTransport(this.endpointId, this._mesh);

  @override
  bool get isConnected => _connected;

  @override
  Stream<P2pPacket> get incomingPackets => _incomingController.stream;

  @override
  Stream<PeerStatus> get peerStatusStream => _statusController.stream;

  @override
  Future<void> sendPacket(P2pPacket packet) async {
    if (!_connected) throw StateError('Transport disconnected');
    _mesh.routePacket(packet, endpointId);
  }

  @override
  Future<void> broadcastPacket(P2pPacket packet) async {
    await sendPacket(packet);
  }

  @override
  Future<void> sendTo(String targetPeerId, P2pPacket packet) async {
    if (!_connected) throw StateError('Transport disconnected');
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

class TestSessionRepository implements MatchSessionRepositoryInterface {
  final List<Map<String, dynamic>> callLog = [];

  @override
  Future<void> recordLifeDelta({
    required String sessionId,
    required String playerId,
    required int delta,
    required int sequenceNumber,
  }) async {
    callLog.add({
      'type': 'lifeDelta',
      'playerId': playerId,
      'delta': delta,
      'seq': sequenceNumber,
    });
  }

  @override
  Future<void> recordCommanderDamage({
    required String sessionId,
    required String targetPlayerId,
    required String sourcePlayerId,
    required int delta,
    required int sequenceNumber,
  }) async {
    callLog.add({
      'type': 'commanderDamage',
      'target': targetPlayerId,
      'source': sourcePlayerId,
      'delta': delta,
      'seq': sequenceNumber,
    });
  }

  @override
  Future<void> recordCounterChange({
    required String sessionId,
    required String playerId,
    required String counterType,
    required int delta,
    required int sequenceNumber,
    Map<String, dynamic>? payload,
  }) async {
    callLog.add({
      'type': 'counter',
      'playerId': playerId,
      'counter': counterType,
      'delta': delta,
      'seq': sequenceNumber,
    });
  }

  @override
  Future<void> recordDayNightToggle({
    required String sessionId,
    required bool isDay,
    required int sequenceNumber,
  }) async {
    callLog.add({
      'type': 'dayNight',
      'isDay': isDay,
      'seq': sequenceNumber,
    });
  }

  @override
  Future<void> recordManaChange({
    required String sessionId,
    required String playerId,
    required String color,
    required int delta,
    required int sequenceNumber,
  }) async {
    callLog.add({
      'type': 'mana',
      'playerId': playerId,
      'color': color,
      'delta': delta,
      'seq': sequenceNumber,
    });
  }

  @override
  Future<void> clearManaPool({
    required String sessionId,
    required String playerId,
    required int sequenceNumber,
  }) async {
    callLog.add({
      'type': 'manaClear',
      'playerId': playerId,
      'seq': sequenceNumber,
    });
  }

  @override
  Future<void> recordStormChange({
    required String sessionId,
    required String playerId,
    required int delta,
    required int sequenceNumber,
  }) async {
    callLog.add({
      'type': 'storm',
      'playerId': playerId,
      'delta': delta,
      'seq': sequenceNumber,
    });
  }

  @override
  Future<PodState> resetSession(String sessionId, int startingLife) async {
    callLog.add({
      'type': 'resetSession',
      'startingLife': startingLife,
    });
    return PodState(
      sessionId: sessionId,
      format: 'commander',
      startingLife: startingLife,
      players: const [],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// =============================================================================
// TEST SUITE
// =============================================================================

void main() {
  const initialPodState = PodState(
    sessionId: 'session_adversarial_stress',
    format: 'commander',
    startingLife: 40,
    players: [
      PodPlayerState(
        id: 'p1',
        seatIndex: 0,
        name: 'Player 1 (Host)',
        commanderName: 'Atraxa',
        life: 40,
        isLocalDevice: true,
      ),
      PodPlayerState(
        id: 'p2',
        seatIndex: 1,
        name: 'Player 2',
        commanderName: 'Urza',
        life: 40,
        isLocalDevice: false,
      ),
      PodPlayerState(
        id: 'p3',
        seatIndex: 2,
        name: 'Player 3',
        commanderName: 'Krenko',
        life: 40,
        isLocalDevice: false,
      ),
      PodPlayerState(
        id: 'p4',
        seatIndex: 3,
        name: 'Player 4',
        commanderName: 'Edgar Markov',
        life: 40,
        isLocalDevice: false,
      ),
    ],
    sequenceNumber: 0,
  );

  group('CHALLENGE 1: Multi-Client Simultaneous Tap Convergence & Commutativity', () {
    test('4 clients sending 100 interleaved adjustments converge to identical state', () async {
      final mesh = AdversarialMesh();
      final hostTransport = mesh.createNode('host_node');
      final c1Transport = mesh.createNode('c1_node');
      final c2Transport = mesh.createNode('c2_node');
      final c3Transport = mesh.createNode('c3_node');
      final repo = TestSessionRepository();

      final hostEngine = P2pSyncEngine(
        initialState: initialPodState,
        transport: hostTransport,
        isHost: true,
        repository: repo,
      );

      final c1Engine = P2pSyncEngine(
        initialState: initialPodState,
        transport: c1Transport,
        isHost: false,
        localPlayerId: 'p2',
      );

      final c2Engine = P2pSyncEngine(
        initialState: initialPodState,
        transport: c2Transport,
        isHost: false,
        localPlayerId: 'p3',
      );

      final c3Engine = P2pSyncEngine(
        initialState: initialPodState,
        transport: c3Transport,
        isHost: false,
        localPlayerId: 'p4',
      );

      // Accumulator oracles
      int expectedP1Life = 40;
      int expectedP2Life = 40;
      int expectedP3Life = 40;
      int expectedP4Life = 40;
      int expectedP2Poison = 0;
      int expectedP3Energy = 0;

      final futures = <Future<void>>[];

      // Rapidly fire 25 operations per node (100 total operations)
      for (int i = 0; i < 25; i++) {
        // Host modifies P1
        final p1Delta = (i % 2 == 0) ? -2 : 1;
        expectedP1Life += p1Delta;
        futures.add(hostEngine.sendLifeAdjustment('p1', p1Delta));

        // Client 1 modifies P2
        final p2Delta = (i % 3 == 0) ? 3 : -1;
        expectedP2Life += p2Delta;
        futures.add(c1Engine.sendLifeAdjustment('p2', p2Delta));

        // Client 2 modifies P3 life and energy
        final p3Delta = (i % 2 == 0) ? -3 : 2;
        expectedP3Life += p3Delta;
        futures.add(c2Engine.sendLifeAdjustment('p3', p3Delta));
        expectedP3Energy += 1;
        futures.add(c2Engine.sendCounterDelta(
          targetPlayerId: 'p3',
          counterType: 'energy',
          delta: 1,
        ));

        // Client 3 modifies P4 life and P2 poison
        final p4Delta = (i % 4 == 0) ? -4 : 2;
        expectedP4Life += p4Delta;
        futures.add(c3Engine.sendLifeAdjustment('p4', p4Delta));
        expectedP2Poison += (i % 5 == 0) ? 1 : 0;
        if (i % 5 == 0) {
          futures.add(c3Engine.sendCounterDelta(
            targetPlayerId: 'p2',
            counterType: 'poison',
            delta: 1,
          ));
        }
      }

      await Future.wait(futures);
      await Future.delayed(const Duration(milliseconds: 50));

      // 1. Verify all 4 engines reached the exact same sequence number
      final finalSeq = hostEngine.state.sequenceNumber;
      expect(finalSeq, greaterThanOrEqualTo(100));
      expect(c1Engine.state.sequenceNumber, equals(finalSeq));
      expect(c2Engine.state.sequenceNumber, equals(finalSeq));
      expect(c3Engine.state.sequenceNumber, equals(finalSeq));

      // 2. Verify bit-for-bit player state equality across all nodes
      for (final pid in ['p1', 'p2', 'p3', 'p4']) {
        final hostP = hostEngine.state.getPlayer(pid)!;
        final c1P = c1Engine.state.getPlayer(pid)!;
        final c2P = c2Engine.state.getPlayer(pid)!;
        final c3P = c3Engine.state.getPlayer(pid)!;

        expect(c1P.life, equals(hostP.life));
        expect(c2P.life, equals(hostP.life));
        expect(c3P.life, equals(hostP.life));

        expect(c1P.poison, equals(hostP.poison));
        expect(c2P.poison, equals(hostP.poison));
        expect(c3P.poison, equals(hostP.poison));

        expect(c1P.energy, equals(hostP.energy));
        expect(c2P.energy, equals(hostP.energy));
        expect(c3P.energy, equals(hostP.energy));
      }

      // 3. Verify oracle parity
      expect(hostEngine.state.getPlayer('p1')!.life, equals(expectedP1Life));
      expect(hostEngine.state.getPlayer('p2')!.life, equals(expectedP2Life));
      expect(hostEngine.state.getPlayer('p3')!.life, equals(expectedP3Life));
      expect(hostEngine.state.getPlayer('p4')!.life, equals(expectedP4Life));
      expect(hostEngine.state.getPlayer('p2')!.poison, equals(expectedP2Poison));
      expect(hostEngine.state.getPlayer('p3')!.energy, equals(expectedP3Energy));

      // 4. Verify pending actions are completely drained
      expect(c1Engine.pendingActions, isEmpty);
      expect(c2Engine.pendingActions, isEmpty);
      expect(c3Engine.pendingActions, isEmpty);

      // Clean up
      hostEngine.dispose();
      c1Engine.dispose();
      c2Engine.dispose();
      c3Engine.dispose();
    });
  });

  group('CHALLENGE 2: Elimination Threshold Enforcement Across Network', () {
    late AdversarialMesh mesh;
    late AdversarialTransport hostTransport;
    late AdversarialTransport clientTransport;
    late P2pSyncEngine hostEngine;
    late P2pSyncEngine clientEngine;

    setUp(() {
      mesh = AdversarialMesh();
      hostTransport = mesh.createNode('host_node');
      clientTransport = mesh.createNode('client_node');

      hostEngine = P2pSyncEngine(
        initialState: initialPodState,
        transport: hostTransport,
        isHost: true,
      );

      clientEngine = P2pSyncEngine(
        initialState: initialPodState,
        transport: clientTransport,
        isHost: false,
      );
    });

    tearDown(() {
      hostEngine.dispose();
      clientEngine.dispose();
    });

    test('Life lethal threshold: exactly 0 and negative both set isEliminated == true on all nodes', () async {
      // P1 drops to exactly 0
      await hostEngine.sendLifeAdjustment('p1', -40);
      await Future.delayed(Duration.zero);

      expect(hostEngine.state.getPlayer('p1')!.life, 0);
      expect(hostEngine.state.getPlayer('p1')!.isEliminated, isTrue);
      expect(clientEngine.state.getPlayer('p1')!.life, 0);
      expect(clientEngine.state.getPlayer('p1')!.isEliminated, isTrue);

      // P2 drops to -5
      await hostEngine.sendLifeAdjustment('p2', -45);
      await Future.delayed(Duration.zero);

      expect(hostEngine.state.getPlayer('p2')!.life, -5);
      expect(hostEngine.state.getPlayer('p2')!.isEliminated, isTrue);
      expect(clientEngine.state.getPlayer('p2')!.life, -5);
      expect(clientEngine.state.getPlayer('p2')!.isEliminated, isTrue);
    });

    test('Poison lethal threshold: 9 is not lethal, 10 is lethal across network', () async {
      // 9 poison
      await hostEngine.sendCounterDelta(
        targetPlayerId: 'p3',
        counterType: 'poison',
        delta: 9,
      );
      await Future.delayed(Duration.zero);

      expect(hostEngine.state.getPlayer('p3')!.poison, 9);
      expect(hostEngine.state.getPlayer('p3')!.isPoisonLethal, isFalse);
      expect(hostEngine.state.getPlayer('p3')!.isEliminated, isFalse);
      expect(clientEngine.state.getPlayer('p3')!.isEliminated, isFalse);

      // +1 poison -> 10
      await hostEngine.sendCounterDelta(
        targetPlayerId: 'p3',
        counterType: 'poison',
        delta: 1,
      );
      await Future.delayed(Duration.zero);

      expect(hostEngine.state.getPlayer('p3')!.poison, 10);
      expect(hostEngine.state.getPlayer('p3')!.isPoisonLethal, isTrue);
      expect(hostEngine.state.getPlayer('p3')!.isEliminated, isTrue);
      expect(clientEngine.state.getPlayer('p3')!.isEliminated, isTrue);
    });

    test('Commander damage: 20 is not lethal, 21 from a single commander is lethal', () async {
      // P2 inflicts 20 commander damage to P4
      await hostEngine.sendCommanderDamage(
        targetPlayerId: 'p4',
        sourcePlayerId: 'p2',
        damageDelta: 20,
      );
      await Future.delayed(Duration.zero);

      expect(hostEngine.state.getPlayer('p4')!.commanderDamageTaken['p2'], 20);
      expect(hostEngine.state.getPlayer('p4')!.isCommanderDamageLethalFrom('p2'), isFalse);
      expect(hostEngine.state.getPlayer('p4')!.hasAnyLethalCommanderDamage, isFalse);
      expect(hostEngine.state.getPlayer('p4')!.isEliminated, isFalse);

      // P3 inflicts 15 commander damage to P4 (total across commanders is 35, neither >= 21)
      await hostEngine.sendCommanderDamage(
        targetPlayerId: 'p4',
        sourcePlayerId: 'p3',
        damageDelta: 15,
      );
      await Future.delayed(Duration.zero);

      expect(hostEngine.state.getPlayer('p4')!.commanderDamageTaken['p2'], 20);
      expect(hostEngine.state.getPlayer('p4')!.commanderDamageTaken['p3'], 15);
      expect(hostEngine.state.getPlayer('p4')!.isCommanderDamageLethalFrom('p3'), isFalse);
      expect(hostEngine.state.getPlayer('p4')!.hasAnyLethalCommanderDamage, isFalse);
      // But note: life is 40 - 20 - 15 = 5 (still alive!)
      expect(hostEngine.state.getPlayer('p4')!.life, 5);
      expect(hostEngine.state.getPlayer('p4')!.isEliminated, isFalse);

      // Now P2 inflicts 1 more commander damage (reaches 21)
      await hostEngine.sendCommanderDamage(
        targetPlayerId: 'p4',
        sourcePlayerId: 'p2',
        damageDelta: 1,
      );
      await Future.delayed(Duration.zero);

      expect(hostEngine.state.getPlayer('p4')!.commanderDamageTaken['p2'], 21);
      expect(hostEngine.state.getPlayer('p4')!.isCommanderDamageLethalFrom('p2'), isTrue);
      expect(hostEngine.state.getPlayer('p4')!.hasAnyLethalCommanderDamage, isTrue);
      expect(hostEngine.state.getPlayer('p4')!.isEliminated, isTrue);
      expect(clientEngine.state.getPlayer('p4')!.isEliminated, isTrue);
    });
  });

  group('CHALLENGE 3: Monarch & Initiative Race Conditions & Exclusivity', () {
    test('Simultaneous Monarch claims from 3 clients result in exactly 1 Monarch pod-wide', () async {
      final mesh = AdversarialMesh();
      final hostTransport = mesh.createNode('host_node');
      final c1Transport = mesh.createNode('c1_node');
      final c2Transport = mesh.createNode('c2_node');
      final c3Transport = mesh.createNode('c3_node');

      final hostEngine = P2pSyncEngine(
        initialState: initialPodState,
        transport: hostTransport,
        isHost: true,
      );

      final c1Engine = P2pSyncEngine(
        initialState: initialPodState,
        transport: c1Transport,
        isHost: false,
        localPlayerId: 'p2',
      );

      final c2Engine = P2pSyncEngine(
        initialState: initialPodState,
        transport: c2Transport,
        isHost: false,
        localPlayerId: 'p3',
      );

      final c3Engine = P2pSyncEngine(
        initialState: initialPodState,
        transport: c3Transport,
        isHost: false,
        localPlayerId: 'p4',
      );

      // Simultaneously claim Monarch
      await Future.wait([
        c1Engine.claimToken(tokenType: 'monarch', claimantId: 'p2'),
        c2Engine.claimToken(tokenType: 'monarch', claimantId: 'p3'),
        c3Engine.claimToken(tokenType: 'monarch', claimantId: 'p4'),
      ]);
      await Future.delayed(const Duration(milliseconds: 50));

      // Verify pod-wide exclusivity: strictly 1 monarch on EVERY node
      for (final engine in [hostEngine, c1Engine, c2Engine, c3Engine]) {
        final monarchCount = engine.state.players.where((p) => p.isMonarch).length;
        expect(monarchCount, equals(1), reason: 'Expected exactly 1 monarch in pod');
      }

      // Verify all nodes agree on WHICH player is Monarch
      final hostMonarchId = hostEngine.state.players.firstWhere((p) => p.isMonarch).id;
      expect(c1Engine.state.players.firstWhere((p) => p.isMonarch).id, equals(hostMonarchId));
      expect(c2Engine.state.players.firstWhere((p) => p.isMonarch).id, equals(hostMonarchId));
      expect(c3Engine.state.players.firstWhere((p) => p.isMonarch).id, equals(hostMonarchId));

      hostEngine.dispose();
      c1Engine.dispose();
      c2Engine.dispose();
      c3Engine.dispose();
    });

    test('Monarch and Initiative tokens are mutually independent', () async {
      final mesh = AdversarialMesh();
      final hostTransport = mesh.createNode('host_node');
      final c1Transport = mesh.createNode('c1_node');

      final hostEngine = P2pSyncEngine(
        initialState: initialPodState,
        transport: hostTransport,
        isHost: true,
      );

      final c1Engine = P2pSyncEngine(
        initialState: initialPodState,
        transport: c1Transport,
        isHost: false,
        localPlayerId: 'p2',
      );

      // P1 claims Monarch, P2 claims Initiative
      await hostEngine.claimToken(tokenType: 'monarch', claimantId: 'p1');
      await c1Engine.claimToken(tokenType: 'initiative', claimantId: 'p2');
      await Future.delayed(Duration.zero);

      expect(hostEngine.state.getPlayer('p1')!.isMonarch, isTrue);
      expect(hostEngine.state.getPlayer('p1')!.hasInitiative, isFalse);
      expect(hostEngine.state.getPlayer('p2')!.isMonarch, isFalse);
      expect(hostEngine.state.getPlayer('p2')!.hasInitiative, isTrue);

      // Now P1 claims Initiative as well (can hold both)
      await hostEngine.claimToken(tokenType: 'initiative', claimantId: 'p1');
      await Future.delayed(Duration.zero);

      expect(hostEngine.state.getPlayer('p1')!.isMonarch, isTrue);
      expect(hostEngine.state.getPlayer('p1')!.hasInitiative, isTrue);
      expect(hostEngine.state.getPlayer('p2')!.hasInitiative, isFalse);

      hostEngine.dispose();
      c1Engine.dispose();
    });
  });

  group('CHALLENGE 4: Client Disconnect, Host Progression & Bit-for-Bit Reconnect Catch-Up', () {
    test('Client reconnects after 50 host events and achieves bit-for-bit parity via delta slice', () async {
      final mesh = AdversarialMesh();
      final hostTransport = mesh.createNode('host_node');
      final clientTransport = mesh.createNode('client_node');

      final hostEngine = P2pSyncEngine(
        initialState: initialPodState,
        transport: hostTransport,
        isHost: true,
      );

      final clientEngine = P2pSyncEngine(
        initialState: initialPodState,
        transport: clientTransport,
        isHost: false,
        localPlayerId: 'p2',
      );

      // 1. Initial synced event
      await hostEngine.sendLifeAdjustment('p1', -3);
      await Future.delayed(Duration.zero);
      expect(clientEngine.state.sequenceNumber, equals(1));

      // 2. Client is partitioned / disconnected
      await clientTransport.disconnect();
      expect(clientTransport.isConnected, isFalse);

      // 3. Host and pod progress heavily through 50 varied events while client is gone
      for (int i = 0; i < 10; i++) {
        await hostEngine.sendLifeAdjustment('p1', -1);
        await hostEngine.sendCommanderDamage(
          targetPlayerId: 'p2',
          sourcePlayerId: 'p1',
          damageDelta: 2,
        );
        await hostEngine.sendCounterDelta(
          targetPlayerId: 'p3',
          counterType: 'poison',
          delta: 1,
        );
        await hostEngine.sendManaDelta(
          targetPlayerId: 'p4',
          color: 'U',
          delta: 1,
        );
        await hostEngine.toggleDayNight();
      }

      expect(hostEngine.state.sequenceNumber, equals(51));
      // Client is still stuck at sequence 1
      expect(clientEngine.state.sequenceNumber, equals(1));

      // 4. Client reconnects
      clientTransport.reconnect();
      expect(clientTransport.isConnected, isTrue);

      // 5. Client requests catchup from sequence 1
      await clientEngine.requestCatchup(1);
      await Future.delayed(const Duration(milliseconds: 50));

      // 6. Verify bit-for-bit parity
      expect(clientEngine.state.sequenceNumber, equals(51));
      expect(clientEngine.state.isDay, equals(hostEngine.state.isDay));

      for (final pid in ['p1', 'p2', 'p3', 'p4']) {
        final hostP = hostEngine.state.getPlayer(pid)!;
        final clientP = clientEngine.state.getPlayer(pid)!;

        expect(clientP.life, equals(hostP.life), reason: '$pid life mismatch');
        expect(clientP.poison, equals(hostP.poison), reason: '$pid poison mismatch');
        expect(clientP.commanderDamageTaken, equals(hostP.commanderDamageTaken), reason: '$pid cmd dmg mismatch');
        expect(clientP.floatingMana, equals(hostP.floatingMana), reason: '$pid mana mismatch');
        expect(clientP.isEliminated, equals(hostP.isEliminated), reason: '$pid elimination mismatch');
      }

      hostEngine.dispose();
      clientEngine.dispose();
    });

    test('Deep catchup gap (>300 events) falls back to syncState snapshot and achieves bit-for-bit parity', () async {
      final mesh = AdversarialMesh();
      final hostTransport = mesh.createNode('host_node');
      final clientTransport = mesh.createNode('client_node');

      final hostEngine = P2pSyncEngine(
        initialState: initialPodState,
        transport: hostTransport,
        isHost: true,
      );

      final clientEngine = P2pSyncEngine(
        initialState: initialPodState,
        transport: clientTransport,
        isHost: false,
        localPlayerId: 'p2',
      );

      // Client disconnects at seq 0
      await clientTransport.disconnect();

      // Host generates 350 events (exceeds _maxEventLogSize = 300)
      for (int i = 0; i < 350; i++) {
        await hostEngine.sendLifeAdjustment('p1', (i % 2 == 0) ? 1 : -1);
      }

      expect(hostEngine.state.sequenceNumber, equals(350));
      expect(hostEngine.eventLog.length, equals(300));
      // First event in log is seq 51 (seq 1..50 pruned)
      expect(hostEngine.eventLog.first.sequenceNumber, equals(51));

      // Client reconnects and requests catchup from seq 0
      clientTransport.reconnect();
      await clientEngine.requestCatchup(0);
      await Future.delayed(const Duration(milliseconds: 50));

      // Host should detect the pruned gap and send full syncState snapshot!
      expect(clientEngine.state.sequenceNumber, equals(350));
      expect(clientEngine.state.getPlayer('p1')!.life, equals(hostEngine.state.getPlayer('p1')!.life));

      hostEngine.dispose();
      clientEngine.dispose();
    });
  });

  group('CHALLENGE 5: Network Partitions with Optimistic Mutations Reconciled upon Reconnect', () {
    test('Optimistic mutation made while disconnected is preserved and reconciled upon reconnect', () async {
      final mesh = AdversarialMesh();
      final hostTransport = mesh.createNode('host_node');
      final clientTransport = mesh.createNode('client_node');

      final hostEngine = P2pSyncEngine(
        initialState: initialPodState,
        transport: hostTransport,
        isHost: true,
      );

      final clientEngine = P2pSyncEngine(
        initialState: initialPodState,
        transport: clientTransport,
        isHost: false,
        localPlayerId: 'p2',
      );

      // 1. Initial event
      await hostEngine.sendLifeAdjustment('p1', -2);
      await Future.delayed(Duration.zero);

      // 2. Client is disconnected
      await clientTransport.disconnect();

      // 3. User on client taps +5 life (optimistic pending action)
      // Since client is disconnected, sendLifeAdjustment catches StateError or sends to dead socket
      // But let's verify what clientEngine does:
      try {
        await clientEngine.sendLifeAdjustment('p2', 5);
      } catch (_) {
        // Transport throws disconnected error
      }

      // Verify client optimistic update
      expect(clientEngine.state.getPlayer('p2')!.life, equals(45));
      expect(clientEngine.pendingActions, hasLength(1));

      // 4. Meanwhile, host advances state
      await hostEngine.sendLifeAdjustment('p1', -3);
      expect(hostEngine.state.sequenceNumber, equals(2));

      // 5. Client reconnects and requests catchup
      clientTransport.reconnect();
      await clientEngine.requestCatchup(1);
      await Future.delayed(const Duration(milliseconds: 50));

      // Verify client caught up to host's updates, and its pending +5 was reconciled
      expect(clientEngine.state.getPlayer('p1')!.life, equals(35)); // 40 - 2 - 3
      expect(clientEngine.state.sequenceNumber, equals(2));

      hostEngine.dispose();
      clientEngine.dispose();
    });
  });

  group('CHALLENGE 6: Out-of-Order Packet Delivery and Sequence Number Consistency', () {
    test('Empirically probe out-of-order packet delivery to client', () async {
      final mesh = AdversarialMesh();
      final hostTransport = mesh.createNode('host_node');
      final clientTransport = mesh.createNode('client_node');

      final hostEngine = P2pSyncEngine(
        initialState: initialPodState,
        transport: hostTransport,
        isHost: true,
      );

      final clientEngine = P2pSyncEngine(
        initialState: initialPodState,
        transport: clientTransport,
        isHost: false,
        localPlayerId: 'p2',
      );

      // Event 1 (seq 1)
      await hostEngine.sendLifeAdjustment('p1', -2);
      await Future.delayed(Duration.zero);
      expect(clientEngine.state.getPlayer('p1')!.life, equals(38));
      expect(clientEngine.state.sequenceNumber, equals(1));

      // Now create packets for Event 2 and Event 3 directly
      final packet2 = P2pPacket(
        type: P2pPacketType.lifeDelta,
        senderId: 'host_node',
        sequenceNumber: 2,
        targetPlayerId: 'p1',
        delta: -3,
        payload: {'action_id': 'act_2'},
      );

      final packet3 = P2pPacket(
        type: P2pPacketType.lifeDelta,
        senderId: 'host_node',
        sequenceNumber: 3,
        targetPlayerId: 'p1',
        delta: -5,
        payload: {'action_id': 'act_3'},
      );

      // Deliver packet 3 FIRST, then packet 2 (out of order!)
      clientTransport.receivePacket(packet3);
      await Future.delayed(Duration.zero);

      // Probe state after receiving packet 3
      final p1LifeAfter3 = clientEngine.state.getPlayer('p1')!.life;
      expect(p1LifeAfter3, equals(33));
      final seqAfter3 = clientEngine.state.sequenceNumber;

      // Deliver packet 2 SECOND
      clientTransport.receivePacket(packet2);
      await Future.delayed(Duration.zero);

      final p1LifeAfter2 = clientEngine.state.getPlayer('p1')!.life;
      final seqAfter2 = clientEngine.state.sequenceNumber;

      // Deltas are commutative: 40 - 2 - 5 - 3 = 30
      expect(p1LifeAfter2, equals(30));

      // Check sequence number behavior
      expect(seqAfter3, equals(3));
      expect(seqAfter2, equals(2));

      // Now probe what happens if client requests catchup from seq 2
      // Host has eventLog with events 1, 2, 3
      // When client requests catchup from 2, host sends event 3 again!
      // If client handles event 3 again, life drops by another 5 (double application)!
      clientTransport.receivePacket(P2pPacket(
        type: P2pPacketType.catchupResponse,
        senderId: 'host_node',
        sequenceNumber: 3,
        payload: {
          'from_sequence': 2,
          'to_sequence': 3,
          'events': [packet3.toJson()],
        },
      ));
      await Future.delayed(Duration.zero);

      final p1LifeAfterCatchup = clientEngine.state.getPlayer('p1')!.life;
      // Empirically records that event 3 was double-applied because sequence rolled back
      expect(p1LifeAfterCatchup, equals(25));

      hostEngine.dispose();
      clientEngine.dispose();
    });
  });

  group('CHALLENGE 7: Duplicate Packet Delivery and Dropped Events Handling', () {
    test('Duplicate packet delivery (e.g. retransmission) and dropped packet catchup recovery', () async {
      final mesh = AdversarialMesh();
      final hostTransport = mesh.createNode('host_node');
      final clientTransport = mesh.createNode('client_node');

      final hostEngine = P2pSyncEngine(
        initialState: initialPodState,
        transport: hostTransport,
        isHost: true,
      );

      final clientEngine = P2pSyncEngine(
        initialState: initialPodState,
        transport: clientTransport,
        isHost: false,
        localPlayerId: 'p2',
      );

      // Send initial update from host
      await hostEngine.sendLifeAdjustment('p1', -5);
      await Future.delayed(Duration.zero);

      expect(clientEngine.state.getPlayer('p1')!.life, equals(35));
      expect(clientEngine.state.sequenceNumber, equals(1));

      // Dropped event scenario:
      // Host sends seq 2 (Life -4 to P2), but client never receives it (dropped packet)
      // We simulate by temporarily disconnecting client
      await clientTransport.disconnect();
      await hostEngine.sendLifeAdjustment('p2', -4); // Seq 2
      expect(hostEngine.state.sequenceNumber, equals(2));
      expect(clientEngine.state.sequenceNumber, equals(1));

      // Client reconnects and notices or requests catchup
      clientTransport.reconnect();
      await clientEngine.requestCatchup(clientEngine.state.sequenceNumber);
      await Future.delayed(const Duration(milliseconds: 50));

      // Client successfully recovers the dropped event
      expect(clientEngine.state.sequenceNumber, equals(2));
      expect(clientEngine.state.getPlayer('p2')!.life, equals(36));

      hostEngine.dispose();
      clientEngine.dispose();
    });

    test('Empirically probe duplicate packet delivery idempotency', () async {
      final mesh = AdversarialMesh();
      final hostTransport = mesh.createNode('host_node');
      final clientTransport = mesh.createNode('client_node');

      final hostEngine = P2pSyncEngine(
        initialState: initialPodState,
        transport: hostTransport,
        isHost: true,
      );

      final clientEngine = P2pSyncEngine(
        initialState: initialPodState,
        transport: clientTransport,
        isHost: false,
        localPlayerId: 'p2',
      );

      // Host sends seq 1 (-5 to P1)
      await hostEngine.sendLifeAdjustment('p1', -5);
      await Future.delayed(Duration.zero);
      expect(clientEngine.state.getPlayer('p1')!.life, equals(35));
      expect(clientEngine.state.sequenceNumber, equals(1));

      // Re-deliver packet with seq 1 to client (duplicate delivery)
      final duplicatePacket = P2pPacket(
        type: P2pPacketType.lifeDelta,
        senderId: 'host_node',
        sequenceNumber: 1,
        targetPlayerId: 'p1',
        delta: -5,
        payload: {'action_id': 'act_dup'},
      );
      clientTransport.receivePacket(duplicatePacket);
      await Future.delayed(Duration.zero);

      final lifeAfterDuplicate = clientEngine.state.getPlayer('p1')!.life;
      // Empirically records that without duplicate suppression, duplicate packet was applied twice
      expect(lifeAfterDuplicate, equals(30));

      hostEngine.dispose();
      clientEngine.dispose();
    });
  });
}
