// Copyright (c) 2026 Countr. All rights reserved.
// Empirical Fuzz & Stress Verification Harness for Milestone 2 Iteration 2 Gate.
// Authored by m2_challenger_net_2_it2.

import 'dart:async';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/features/life_counter/domain/models/p2p_packet.dart';
import 'package:countr/features/life_counter/domain/models/pod_state.dart';
import 'package:countr/features/life_counter/data/network/p2p_transport.dart';
import 'package:countr/features/life_counter/data/network/pod_connection_fallback.dart';
import 'package:countr/features/life_counter/data/network/p2p_sync_engine.dart';

class StarMesh {
  final Map<String, StarTransport> _nodes = {};
  String hostEndpointId = 'host';

  StarTransport createNode(String endpointId) {
    final transport = StarTransport(endpointId, this);
    _nodes[endpointId] = transport;
    return transport;
  }

  void routePacket(P2pPacket packet, String senderEndpoint, {String? targetEndpoint}) {
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
      // Host broadcasts confirmed packets to all clients
      for (final entry in _nodes.entries) {
        if (entry.key != senderEndpoint && entry.value.isConnected) {
          entry.value.receivePacket(packet);
        }
      }
    }
  }

  void reset() {
    _nodes.clear();
  }
}

class StarTransport implements P2pTransport {
  @override
  final String endpointId;
  final StarMesh _mesh;
  final StreamController<P2pPacket> _incomingController = StreamController<P2pPacket>.broadcast();
  final StreamController<PeerStatus> _statusController = StreamController<PeerStatus>.broadcast();
  bool _connected = true;

  StarTransport(this.endpointId, this._mesh);

  @override
  bool get isConnected => _connected;
  @override
  Stream<P2pPacket> get incomingPackets => _incomingController.stream;
  @override
  Stream<PeerStatus> get peerStatusStream => _statusController.stream;

  @override
  Future<void> sendPacket(P2pPacket packet) async {
    if (!_connected) throw StateError('Disconnected');
    _mesh.routePacket(packet, endpointId);
  }

  @override
  Future<void> broadcastPacket(P2pPacket packet) async {
    await sendPacket(packet);
  }

  @override
  Future<void> sendTo(String targetPeerId, P2pPacket packet) async {
    if (!_connected) throw StateError('Disconnected');
    _mesh.routePacket(packet, endpointId, targetEndpoint: targetPeerId);
  }

  @override
  Future<void> broadcast(P2pPacket packet) => broadcastPacket(packet);
  @override
  Future<void> disconnect() async { _connected = false; }
  @override
  Future<void> close() async { await disconnect(); dispose(); }

  void receivePacket(P2pPacket packet) {
    if (_connected && !_incomingController.isClosed) {
      _incomingController.add(packet);
    }
  }

  void dispose() {
    _incomingController.close();
    _statusController.close();
  }
}

void main() {
  group('Empirical Challenge Group 1: Packet Type Coercion & Boundary Fuzzing (10,000 iterations)', () {
    test('10,000 randomized fuzzed payloads never throw TypeError or unhandled exception', () {
      final rand = Random(42);
      final validTypes = [
        'life_delta', 'commander_damage', 'counter_delta', 'mana_delta',
        'mana_clear', 'day_night_toggle', 'claim_token', 'reset_game',
        'heartbeat', 'sync_state', 'handshake_request', 'handshake_response',
        'catchup_request', 'catchup_response'
      ];

      final candidateValues = <dynamic>[
        null,
        0,
        1,
        -1,
        42,
        -999999,
        999999,
        '0',
        '1',
        '-1',
        '+5',
        '100',
        '1.0',
        '-5.5',
        '1e3',
        'not_a_number',
        '',
        '   ',
        'NaN',
        'Infinity',
        '-Infinity',
        true,
        false,
        <String>[],
        <String, dynamic>{},
        {'nested': 123},
      ];

      int parsedCount = 0;
      int formatExceptionCount = 0;

      for (int i = 0; i < 10000; i++) {
        final wireType = rand.nextBool()
            ? validTypes[rand.nextInt(validTypes.length)]
            : 'fuzzed_type_${rand.nextInt(50)}';

        final seqVal = candidateValues[rand.nextInt(candidateValues.length)];
        final deltaVal = candidateValues[rand.nextInt(candidateValues.length)];
        final valVal = candidateValues[rand.nextInt(candidateValues.length)];
        final targetVal = candidateValues[rand.nextInt(candidateValues.length)];
        final senderVal = candidateValues[rand.nextInt(candidateValues.length)];
        final timeVal = candidateValues[rand.nextInt(candidateValues.length)];

        // Randomize key styles (snake_case vs camelCase)
        final map = <String, dynamic>{
          rand.nextBool() ? 'type' : 'packet_type': wireType,
          rand.nextBool() ? 'sequence_number' : 'sequenceNumber': seqVal,
          'delta': deltaVal,
          'value': valVal,
          rand.nextBool() ? 'target_player_id' : 'targetPlayerId': targetVal,
          rand.nextBool() ? 'sender_id' : 'senderId': senderVal,
          'timestamp': timeVal,
          'payload': rand.nextBool() ? {'key': 'val'} : null,
        };

        try {
          final packet = P2pPacket.fromJson(map);
          expect(packet, isA<P2pPacket>());
          parsedCount++;

          // Verify serialization integrity
          final jsonMap = packet.toJson();
          expect(jsonMap['sequence_number'], isA<int>());
          expect(jsonMap['delta'], isA<int>());
          expect(jsonMap['value'], isA<int>());
          expect(jsonMap['timestamp'], isA<int>());
        } on FormatException {
          formatExceptionCount++;
        } catch (e, stack) {
          fail('Unexpected unhandled error for payload $map: $e\n$stack');
        }
      }

      expect(parsedCount, greaterThan(0));
      expect(formatExceptionCount, greaterThan(0));
      expect(parsedCount + formatExceptionCount, equals(10000));
    });
  });

  group('Empirical Challenge Group 2: PodDirectConnect Port Range Boundary Fuzzing', () {
    test('Strict RFC 793 port range [1..65535] verification across all boundaries', () {
      final boundaryPorts = [
        -99999, -65536, -65535, -1, 0,
        1, 2, 80, 443, 8080, 40407, 65534, 65535,
        65536, 65537, 100000, 999999
      ];

      for (final port in boundaryPorts) {
        final isValidPort = port >= 1 && port <= 65535;

        // 1. PodJoinInfo constructor assertion
        if (isValidPort) {
          final info = PodJoinInfo(
            host: '192.168.1.10',
            port: port,
            roomCode: 'MTG42',
            sessionId: 'ses_1',
          );
          expect(info.port, equals(port));
        } else {
          expect(
            () => PodJoinInfo(
              host: '192.168.1.10',
              port: port,
              roomCode: 'MTG42',
              sessionId: 'ses_1',
            ),
            throwsAssertionError,
          );
        }

        // 2. generateQrUri
        if (isValidPort) {
          final uri = PodDirectConnect.generateQrUri(
            host: '192.168.1.10',
            port: port,
            roomCode: 'MTG42',
            sessionId: 'ses_1',
          );
          expect(uri, contains('port=$port'));
          final parsed = PodDirectConnect.parseQrUri(uri);
          expect(parsed, isNotNull);
          expect(parsed!.port, equals(port));
        } else {
          expect(
            () => PodDirectConnect.generateQrUri(
              host: '192.168.1.10',
              port: port,
              roomCode: 'MTG42',
              sessionId: 'ses_1',
            ),
            throwsA(isA<ArgumentError>()),
          );
        }

        // 3. parseDirectAddress
        final addr = '192.168.1.10:$port';
        final parsedAddr = PodDirectConnect.parseDirectAddress(addr);
        if (isValidPort) {
          expect(parsedAddr, isNotNull);
          expect(parsedAddr!.port, equals(port));
        } else {
          expect(parsedAddr, isNull);
        }
      }
    });

    test('parseDirectAddress edge inputs do not throw unhandled exceptions', () {
      final invalidInputs = [
        '',
        '   ',
        ':',
        '::',
        '192.168.1.1:abc',
        '192.168.1.1:40407:extra',
        ':40407',
        'localhost:-5',
        'localhost:0',
        'localhost:65536',
        '127.0.0.1:999999999999999999999',
      ];

      for (final input in invalidInputs) {
        expect(() => PodDirectConnect.parseDirectAddress(input), returnsNormally);
        final result = PodDirectConnect.parseDirectAddress(input);
        expect(result, isNull);
      }
    });
  });

  group('Empirical Challenge Group 3: 6-Player High-Load Mesh Sync Convergence', () {
    test('6-node full pod executes 300 interleaved concurrent mutations and converges', () async {
      final mesh = StarMesh();
      final hostTransport = mesh.createNode('host');
      final c1Transport = mesh.createNode('c1');
      final c2Transport = mesh.createNode('c2');
      final c3Transport = mesh.createNode('c3');
      final c4Transport = mesh.createNode('c4');
      final c5Transport = mesh.createNode('c5');

      const initial6PState = PodState(
        sessionId: 'ses_6p_stress',
        format: 'commander',
        startingLife: 40,
        players: [
          PodPlayerState(id: 'p1', seatIndex: 0, name: 'P1', life: 40),
          PodPlayerState(id: 'p2', seatIndex: 1, name: 'P2', life: 40),
          PodPlayerState(id: 'p3', seatIndex: 2, name: 'P3', life: 40),
          PodPlayerState(id: 'p4', seatIndex: 3, name: 'P4', life: 40),
          PodPlayerState(id: 'p5', seatIndex: 4, name: 'P5', life: 40),
          PodPlayerState(id: 'p6', seatIndex: 5, name: 'P6', life: 40),
        ],
        sequenceNumber: 0,
      );

      final hostEngine = P2pSyncEngine(initialState: initial6PState, transport: hostTransport, isHost: true);
      final c1 = P2pSyncEngine(initialState: initial6PState, transport: c1Transport, isHost: false, localPlayerId: 'p2');
      final c2 = P2pSyncEngine(initialState: initial6PState, transport: c2Transport, isHost: false, localPlayerId: 'p3');
      final c3 = P2pSyncEngine(initialState: initial6PState, transport: c3Transport, isHost: false, localPlayerId: 'p4');
      final c4 = P2pSyncEngine(initialState: initial6PState, transport: c4Transport, isHost: false, localPlayerId: 'p5');
      final c5 = P2pSyncEngine(initialState: initial6PState, transport: c5Transport, isHost: false, localPlayerId: 'p6');

      final allClients = [c1, c2, c3, c4, c5];
      final allEngines = [hostEngine, ...allClients];

      // Track expected life
      final expectedLife = {'p1': 40, 'p2': 40, 'p3': 40, 'p4': 40, 'p5': 40, 'p6': 40};

      final futures = <Future<void>>[];

      // 50 rounds x 6 nodes = 300 total actions
      for (int round = 0; round < 50; round++) {
        // Host modifies P1
        final p1Delta = (round % 2 == 0) ? -1 : 2;
        expectedLife['p1'] = expectedLife['p1']! + p1Delta;
        futures.add(hostEngine.sendLifeAdjustment('p1', p1Delta));

        // C1 modifies P2
        final p2Delta = (round % 3 == 0) ? -2 : 1;
        expectedLife['p2'] = expectedLife['p2']! + p2Delta;
        futures.add(c1.sendLifeAdjustment('p2', p2Delta));

        // C2 modifies P3
        final p3Delta = (round % 4 == 0) ? 3 : -1;
        expectedLife['p3'] = expectedLife['p3']! + p3Delta;
        futures.add(c2.sendLifeAdjustment('p3', p3Delta));

        // C3 modifies P4
        final p4Delta = (round % 5 == 0) ? -3 : 2;
        expectedLife['p4'] = expectedLife['p4']! + p4Delta;
        futures.add(c3.sendLifeAdjustment('p4', p4Delta));

        // C4 modifies P5
        final p5Delta = (round % 2 == 0) ? 1 : -2;
        expectedLife['p5'] = expectedLife['p5']! + p5Delta;
        futures.add(c4.sendLifeAdjustment('p5', p5Delta));

        // C5 modifies P6
        final p6Delta = (round % 3 == 0) ? -1 : 3;
        expectedLife['p6'] = expectedLife['p6']! + p6Delta;
        futures.add(c5.sendLifeAdjustment('p6', p6Delta));
      }

      await Future.wait(futures);
      await Future.delayed(const Duration(milliseconds: 100));

      final hostSeq = hostEngine.state.sequenceNumber;
      expect(hostSeq, equals(300));

      for (final engine in allEngines) {
        expect(engine.state.sequenceNumber, equals(300));
        for (final pid in ['p1', 'p2', 'p3', 'p4', 'p5', 'p6']) {
          expect(engine.state.getPlayer(pid)!.life, equals(expectedLife[pid]));
        }
      }

      // Dispose all
      for (final engine in allEngines) {
        engine.dispose();
      }
      mesh.reset();
    });
  });
}
