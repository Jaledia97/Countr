// Copyright (c) 2026 Countr. All rights reserved.
// Unit test specification for P2pSyncEngine, event sourcing reconciliation, and catch-up replay.

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/features/life_counter/domain/models/pod_state.dart';
import 'package:countr/features/life_counter/domain/models/p2p_packet.dart';
import 'package:countr/features/life_counter/data/network/p2p_transport.dart';
import 'package:countr/features/life_counter/data/network/p2p_sync_engine.dart';
import 'package:countr/features/life_counter/data/repositories/match_session_repository.dart';

// =============================================================================
// TEST MOCK INFRASTRUCTURE (DETERMINISTIC IN-MEMORY MESH)
// =============================================================================

class MockP2pMesh {
  final Map<String, MockP2pTransport> _nodes = {};

  String hostEndpointId = 'host_node';

  MockP2pTransport createNode(String endpointId) {
    final transport = MockP2pTransport(endpointId, this);
    _nodes[endpointId] = transport;
    return transport;
  }

  void routePacket(P2pPacket packet, String senderEndpoint,
      {String? targetEndpoint}) {
    if (targetEndpoint != null) {
      final target = _nodes[targetEndpoint];
      if (target != null && target.isConnected) {
        target.receivePacket(packet);
      }
    } else if (senderEndpoint != hostEndpointId) {
      // In Star topology, clients send packets exclusively to the Host
      final host = _nodes[hostEndpointId];
      if (host != null && host.isConnected) {
        host.receivePacket(packet);
      }
    } else {
      // Host broadcasts to all clients
      for (final entry in _nodes.entries) {
        if (entry.key != senderEndpoint && entry.value.isConnected) {
          entry.value.receivePacket(packet);
        }
      }
    }
  }

  void removeNode(String endpointId) {
    _nodes.remove(endpointId);
  }
}

class MockP2pTransport implements P2pTransport {
  @override
  final String endpointId;
  final MockP2pMesh _mesh;
  final StreamController<P2pPacket> _incomingController =
      StreamController<P2pPacket>.broadcast();
  final StreamController<PeerStatus> _statusController =
      StreamController<PeerStatus>.broadcast();
  bool _connected = true;

  MockP2pTransport(this.endpointId, this._mesh);

  @override
  bool get isConnected => _connected;

  @override
  Stream<P2pPacket> get incomingPackets => _incomingController.stream;

  @override
  Stream<PeerStatus> get peerStatusStream => _statusController.stream;

  @override
  Future<void> sendPacket(P2pPacket packet) async {
    if (!_connected) throw StateError('MockP2pTransport is disconnected');
    _mesh.routePacket(packet, endpointId);
  }

  @override
  Future<void> broadcastPacket(P2pPacket packet) async {
    await sendPacket(packet);
  }

  @override
  Future<void> sendTo(String targetPeerId, P2pPacket packet) async {
    if (!_connected) throw StateError('MockP2pTransport is disconnected');
    _mesh.routePacket(packet, endpointId, targetEndpoint: targetPeerId);
  }

  @override
  Future<void> broadcast(P2pPacket packet) async {
    await broadcastPacket(packet);
  }

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

class MockMatchSessionRepository implements MatchSessionRepositoryInterface {
  final List<Map<String, dynamic>> recordedCalls = [];

  @override
  Future<void> recordLifeDelta({
    required String sessionId,
    required String playerId,
    required int delta,
    required int sequenceNumber,
  }) async {
    recordedCalls.add({
      'method': 'recordLifeDelta',
      'sessionId': sessionId,
      'playerId': playerId,
      'delta': delta,
      'sequenceNumber': sequenceNumber,
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
    recordedCalls.add({
      'method': 'recordCommanderDamage',
      'sessionId': sessionId,
      'targetPlayerId': targetPlayerId,
      'sourcePlayerId': sourcePlayerId,
      'delta': delta,
      'sequenceNumber': sequenceNumber,
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
    recordedCalls.add({
      'method': 'recordCounterChange',
      'sessionId': sessionId,
      'playerId': playerId,
      'counterType': counterType,
      'delta': delta,
      'sequenceNumber': sequenceNumber,
    });
  }

  @override
  Future<void> recordDayNightToggle({
    required String sessionId,
    required bool isDay,
    required int sequenceNumber,
  }) async {
    recordedCalls.add({
      'method': 'recordDayNightToggle',
      'sessionId': sessionId,
      'isDay': isDay,
      'sequenceNumber': sequenceNumber,
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
    recordedCalls.add({
      'method': 'recordManaChange',
      'sessionId': sessionId,
      'playerId': playerId,
      'color': color,
      'delta': delta,
      'sequenceNumber': sequenceNumber,
    });
  }

  @override
  Future<void> clearManaPool({
    required String sessionId,
    required String playerId,
    required int sequenceNumber,
  }) async {
    recordedCalls.add({
      'method': 'clearManaPool',
      'sessionId': sessionId,
      'playerId': playerId,
      'sequenceNumber': sequenceNumber,
    });
  }

  @override
  Future<void> recordStormChange({
    required String sessionId,
    required String playerId,
    required int delta,
    required int sequenceNumber,
  }) async {
    recordedCalls.add({
      'method': 'recordStormChange',
      'sessionId': sessionId,
      'playerId': playerId,
      'delta': delta,
      'sequenceNumber': sequenceNumber,
    });
  }

  @override
  Future<PodState> resetSession(String sessionId, int startingLife) async {
    recordedCalls.add({
      'method': 'resetSession',
      'sessionId': sessionId,
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
// UNIT TESTS
// =============================================================================

void main() {
  late MockP2pMesh mesh;
  late MockP2pTransport hostTransport;
  late MockP2pTransport clientTransport1;
  late MockP2pTransport clientTransport2;
  late MockMatchSessionRepository mockRepository;

  const initialPodState = PodState(
    sessionId: 'session_m2_test',
    format: 'commander',
    startingLife: 40,
    players: [
      PodPlayerState(
        id: 'p1',
        seatIndex: 0,
        name: 'Alice',
        commanderName: 'Atraxa',
        life: 40,
        isLocalDevice: true,
      ),
      PodPlayerState(
        id: 'p2',
        seatIndex: 1,
        name: 'Bob',
        commanderName: "K'rrik",
        life: 40,
        isLocalDevice: false,
      ),
      PodPlayerState(
        id: 'p3',
        seatIndex: 2,
        name: 'Charlie',
        commanderName: 'Edgar Markov',
        life: 40,
        isLocalDevice: false,
      ),
    ],
    sequenceNumber: 0,
  );

  setUp(() {
    mesh = MockP2pMesh();
    hostTransport = mesh.createNode('host_node');
    clientTransport1 = mesh.createNode('client_1_node');
    clientTransport2 = mesh.createNode('client_2_node');
    mockRepository = MockMatchSessionRepository();
  });

  tearDown(() {
    hostTransport.dispose();
    clientTransport1.dispose();
    clientTransport2.dispose();
  });

  group('Group 1: Delta-Based Life Reconciliation & Commutativity', () {
    test('Host life adjustment broadcasts sequenced packet to all clients',
        () async {
      final hostEngine = P2pSyncEngine(
        initialState: initialPodState,
        transport: hostTransport,
        isHost: true,
        repository: mockRepository,
      );

      final clientEngine = P2pSyncEngine(
        initialState: initialPodState,
        transport: clientTransport1,
        isHost: false,
      );

      await hostEngine.sendLifeAdjustment('p1', -5);
      await Future.delayed(Duration.zero);

      expect(hostEngine.state.getPlayer('p1')!.life, 35);
      expect(clientEngine.state.getPlayer('p1')!.life, 35);
      expect(hostEngine.state.sequenceNumber, 1);
      expect(clientEngine.state.sequenceNumber, 1);

      // Verify DB persistence call
      expect(mockRepository.recordedCalls, hasLength(1));
      expect(mockRepository.recordedCalls.first['method'], 'recordLifeDelta');
      expect(mockRepository.recordedCalls.first['delta'], -5);
      expect(mockRepository.recordedCalls.first['sequenceNumber'], 1);
    });

    test(
        'Client applies optimistic update immediately and reconciles on host confirmation',
        () async {
      final hostEngine = P2pSyncEngine(
        initialState: initialPodState,
        transport: hostTransport,
        isHost: true,
        repository: mockRepository,
      );

      final clientEngine = P2pSyncEngine(
        initialState: initialPodState,
        transport: clientTransport1,
        isHost: false,
        localPlayerId: 'p2',
      );

      // Client sends +3 life
      final sendFuture = clientEngine.sendLifeAdjustment('p2', 3);

      // Immediately verify optimistic update in client state
      expect(clientEngine.state.getPlayer('p2')!.life, 43);
      expect(clientEngine.pendingActions, hasLength(1));

      await sendFuture;
      await Future.delayed(Duration.zero);

      // Confirmed by host
      expect(hostEngine.state.getPlayer('p2')!.life, 43);
      expect(clientEngine.state.getPlayer('p2')!.life, 43);
      expect(clientEngine.pendingActions, isEmpty); // Pending action cleared
      expect(clientEngine.state.sequenceNumber, 1);
    });

    test(
        'Concurrent life adjustments from two clients converge to identical state',
        () async {
      final hostEngine = P2pSyncEngine(
        initialState: initialPodState,
        transport: hostTransport,
        isHost: true,
        repository: mockRepository,
      );

      final client1 = P2pSyncEngine(
        initialState: initialPodState,
        transport: clientTransport1,
        isHost: false,
        localPlayerId: 'p1',
      );

      final client2 = P2pSyncEngine(
        initialState: initialPodState,
        transport: clientTransport2,
        isHost: false,
        localPlayerId: 'p2',
      );

      // Client 1 subtracts 4 from P1
      // Client 2 adds 2 to P1 concurrently
      await client1.sendLifeAdjustment('p1', -4);
      await client2.sendLifeAdjustment('p1', 2);
      await Future.delayed(Duration.zero);

      // Final state: 40 - 4 + 2 = 38
      expect(hostEngine.state.getPlayer('p1')!.life, 38);
      expect(client1.state.getPlayer('p1')!.life, 38);
      expect(client2.state.getPlayer('p1')!.life, 38);
      expect(hostEngine.state.sequenceNumber, 2);
    });

    test('Elimination detected when life drops to 0 or below', () async {
      final hostEngine = P2pSyncEngine(
        initialState: initialPodState,
        transport: hostTransport,
        isHost: true,
        repository: mockRepository,
      );

      await hostEngine.sendLifeAdjustment('p1', -40);
      expect(hostEngine.state.getPlayer('p1')!.life, 0);
      expect(hostEngine.state.getPlayer('p1')!.isEliminated, isTrue);
    });
  });

  group('Group 2: Commander Damage Tracking & 21 Lethal Threshold', () {
    test(
        'Commander damage reduces life and updates matrix per opposing commander',
        () async {
      final hostEngine = P2pSyncEngine(
        initialState: initialPodState,
        transport: hostTransport,
        isHost: true,
        repository: mockRepository,
      );

      final clientEngine = P2pSyncEngine(
        initialState: initialPodState,
        transport: clientTransport1,
        isHost: false,
      );

      // P2 commander inflicts 7 damage to P1
      await hostEngine.sendCommanderDamage(
        targetPlayerId: 'p1',
        sourcePlayerId: 'p2',
        damageDelta: 7,
      );
      await Future.delayed(Duration.zero);

      expect(hostEngine.state.getPlayer('p1')!.life, 33);
      expect(clientEngine.state.getPlayer('p1')!.life, 33);
      expect(hostEngine.state.getPlayer('p1')!.commanderDamageTaken['p2'], 7);
      expect(clientEngine.state.getPlayer('p1')!.commanderDamageTaken['p2'], 7);

      // P3 commander inflicts 5 damage to P1 independently
      await hostEngine.sendCommanderDamage(
        targetPlayerId: 'p1',
        sourcePlayerId: 'p3',
        damageDelta: 5,
      );
      await Future.delayed(Duration.zero);

      expect(clientEngine.state.getPlayer('p1')!.life, 28);
      expect(clientEngine.state.getPlayer('p1')!.commanderDamageTaken['p2'], 7);
      expect(clientEngine.state.getPlayer('p1')!.commanderDamageTaken['p3'], 5);
    });

    test('Accumulating 21 commander damage triggers lethal threshold',
        () async {
      final hostEngine = P2pSyncEngine(
        initialState: initialPodState,
        transport: hostTransport,
        isHost: true,
      );

      await hostEngine.sendCommanderDamage(
        targetPlayerId: 'p1',
        sourcePlayerId: 'p2',
        damageDelta: 21,
      );

      final p1 = hostEngine.state.getPlayer('p1')!;
      expect(p1.commanderDamageTaken['p2'], 21);
      expect(p1.isCommanderDamageLethalFrom('p2'), isTrue);
      expect(p1.hasAnyLethalCommanderDamage, isTrue);
      expect(p1.isEliminated, isTrue);
    });
  });

  group('Group 3: Secondary Counters (Poison, Energy, XP, Tax)', () {
    test(
        'Poison counter increments and evaluates 10-counter lethal threshold',
        () async {
      final hostEngine = P2pSyncEngine(
        initialState: initialPodState,
        transport: hostTransport,
        isHost: true,
        repository: mockRepository,
      );

      final clientEngine = P2pSyncEngine(
        initialState: initialPodState,
        transport: clientTransport1,
        isHost: false,
      );

      await hostEngine.sendCounterDelta(
        targetPlayerId: 'p2',
        counterType: 'poison',
        delta: 9,
      );
      await Future.delayed(Duration.zero);

      expect(clientEngine.state.getPlayer('p2')!.poison, 9);
      expect(clientEngine.state.getPlayer('p2')!.isPoisonLethal, isFalse);

      await hostEngine.sendCounterDelta(
        targetPlayerId: 'p2',
        counterType: 'poison',
        delta: 1,
      );
      await Future.delayed(Duration.zero);

      expect(clientEngine.state.getPlayer('p2')!.poison, 10);
      expect(clientEngine.state.getPlayer('p2')!.isPoisonLethal, isTrue);
      expect(clientEngine.state.getPlayer('p2')!.isEliminated, isTrue);
    });

    test('Energy and Experience counters clamp to non-negative values',
        () async {
      final hostEngine = P2pSyncEngine(
        initialState: initialPodState,
        transport: hostTransport,
        isHost: true,
      );

      await hostEngine.sendCounterDelta(
        targetPlayerId: 'p1',
        counterType: 'energy',
        delta: -3,
      );

      expect(hostEngine.state.getPlayer('p1')!.energy, 0);
    });
  });

  group('Group 4: Token Exclusivity (Monarch & Initiative)', () {
    test(
        'Claiming Monarch transfers token atomically, clearing previous holder',
        () async {
      final hostEngine = P2pSyncEngine(
        initialState: initialPodState,
        transport: hostTransport,
        isHost: true,
        repository: mockRepository,
      );

      final clientEngine = P2pSyncEngine(
        initialState: initialPodState,
        transport: clientTransport1,
        isHost: false,
      );

      // P1 claims Monarch
      await hostEngine.claimToken(tokenType: 'monarch', claimantId: 'p1');
      await Future.delayed(Duration.zero);

      expect(hostEngine.state.getPlayer('p1')!.isMonarch, isTrue);
      expect(hostEngine.state.getPlayer('p2')!.isMonarch, isFalse);
      expect(clientEngine.state.getPlayer('p1')!.isMonarch, isTrue);
      expect(clientEngine.state.getPlayer('p2')!.isMonarch, isFalse);

      // P2 claims Monarch (steals from P1)
      await clientEngine.claimToken(tokenType: 'monarch', claimantId: 'p2');
      await Future.delayed(Duration.zero);

      expect(hostEngine.state.getPlayer('p1')!.isMonarch, isFalse);
      expect(hostEngine.state.getPlayer('p2')!.isMonarch, isTrue);
      expect(clientEngine.state.getPlayer('p1')!.isMonarch, isFalse);
      expect(clientEngine.state.getPlayer('p2')!.isMonarch, isTrue);
    });

    test(
        'Claiming Initiative transfers token atomically, clearing previous holder',
        () async {
      final hostEngine = P2pSyncEngine(
        initialState: initialPodState,
        transport: hostTransport,
        isHost: true,
      );

      await hostEngine.claimToken(tokenType: 'initiative', claimantId: 'p3');
      expect(hostEngine.state.getPlayer('p3')!.hasInitiative, isTrue);
      expect(hostEngine.state.getPlayer('p1')!.hasInitiative, isFalse);

      await hostEngine.claimToken(tokenType: 'initiative', claimantId: 'p1');
      expect(hostEngine.state.getPlayer('p3')!.hasInitiative, isFalse);
      expect(hostEngine.state.getPlayer('p1')!.hasInitiative, isTrue);
    });
  });

  group('Group 5: Day / Night Cycle Synchronization', () {
    test(
        'Day/Night toggle flips across all peers and increments sequence number',
        () async {
      final hostEngine = P2pSyncEngine(
        initialState: initialPodState,
        transport: hostTransport,
        isHost: true,
        repository: mockRepository,
      );

      final clientEngine = P2pSyncEngine(
        initialState: initialPodState,
        transport: clientTransport1,
        isHost: false,
      );

      expect(hostEngine.state.isDay, isTrue);

      await hostEngine.toggleDayNight();
      await Future.delayed(Duration.zero);

      expect(hostEngine.state.isDay, isFalse);
      expect(clientEngine.state.isDay, isFalse);
      expect(hostEngine.state.sequenceNumber, 1);
    });
  });

  group('Group 6: Floating Mana & Storm Counter', () {
    test('Mana delta increments color pool and tracks storm count', () async {
      final hostEngine = P2pSyncEngine(
        initialState: initialPodState,
        transport: hostTransport,
        isHost: true,
        repository: mockRepository,
      );

      final clientEngine = P2pSyncEngine(
        initialState: initialPodState,
        transport: clientTransport1,
        isHost: false,
      );

      await hostEngine.sendManaDelta(targetPlayerId: 'p1', color: 'U', delta: 2);
      await Future.delayed(Duration.zero);

      expect(clientEngine.state.getPlayer('p1')!.floatingMana['U'], 2);
      expect(clientEngine.state.getPlayer('p1')!.stormCount, 1);

      // Clear mana pool
      await hostEngine.sendManaClear('p1');
      await Future.delayed(Duration.zero);

      expect(clientEngine.state.getPlayer('p1')!.floatingMana['U'], 0);
      expect(clientEngine.state.getPlayer('p1')!.stormCount, 0);
    });
  });

  group('Group 7: Global Reset Game', () {
    test(
        'Reset game restores starting life and clears counters while preserving seating',
        () async {
      final hostEngine = P2pSyncEngine(
        initialState: initialPodState,
        transport: hostTransport,
        isHost: true,
        repository: mockRepository,
      );

      final clientEngine = P2pSyncEngine(
        initialState: initialPodState,
        transport: clientTransport1,
        isHost: false,
      );

      // Make dirty changes
      await hostEngine.sendLifeAdjustment('p1', -15);
      await hostEngine.sendCounterDelta(
          targetPlayerId: 'p1', counterType: 'poison', delta: 3);
      await hostEngine.claimToken(tokenType: 'monarch', claimantId: 'p1');
      await Future.delayed(Duration.zero);

      expect(clientEngine.state.getPlayer('p1')!.life, 25);
      expect(clientEngine.state.getPlayer('p1')!.isMonarch, isTrue);

      // Reset
      await hostEngine.resetGame(40);
      await Future.delayed(Duration.zero);

      final p1Client = clientEngine.state.getPlayer('p1')!;
      expect(p1Client.life, 40);
      expect(p1Client.poison, 0);
      expect(p1Client.isMonarch, isFalse);
      expect(p1Client.name, 'Alice'); // Seating preserved
      expect(p1Client.commanderName, 'Atraxa'); // Metadata preserved
      expect(clientEngine.state.isDay, isTrue);
    });
  });

  group('Group 8: Catch-Up & Reconnection Replay', () {
    test(
        'Disconnected client reconnects and replays missed event slice bit-for-bit',
        () async {
      final hostEngine = P2pSyncEngine(
        initialState: initialPodState,
        transport: hostTransport,
        isHost: true,
      );

      final clientEngine = P2pSyncEngine(
        initialState: initialPodState,
        transport: clientTransport1,
        isHost: false,
      );

      // Initial change
      await hostEngine.sendLifeAdjustment('p1', -2);
      await Future.delayed(Duration.zero);
      expect(clientEngine.state.getPlayer('p1')!.life, 38);

      // Client goes offline
      await clientTransport1.disconnect();
      expect(clientTransport1.isConnected, isFalse);

      // Host processes further updates
      await hostEngine.sendLifeAdjustment('p2', -6);
      await hostEngine.sendCounterDelta(
          targetPlayerId: 'p2', counterType: 'poison', delta: 2);
      await hostEngine.claimToken(tokenType: 'monarch', claimantId: 'p3');

      // Client reconnects
      clientTransport1.reconnect();
      expect(clientTransport1.isConnected, isTrue);

      // Request catch-up from sequence 1
      await clientEngine.requestCatchup(1);
      await Future.delayed(Duration.zero);

      // Verify bit-for-bit parity
      expect(clientEngine.state.getPlayer('p1')!.life, 38);
      expect(clientEngine.state.getPlayer('p2')!.life, 34);
      expect(clientEngine.state.getPlayer('p2')!.poison, 2);
      expect(clientEngine.state.getPlayer('p3')!.isMonarch, isTrue);
      expect(
          clientEngine.state.sequenceNumber, hostEngine.state.sequenceNumber);
    });
  });
}
