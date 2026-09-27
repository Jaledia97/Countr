// Copyright (c) 2026 Countr. All rights reserved.
// Unit test specification for P2P network packet protocol, transport, and mesh.

import 'package:flutter_test/flutter_test.dart';
import 'package:countr/features/life_counter/domain/models/p2p_packet.dart';
import 'package:countr/features/life_counter/data/network/p2p_transport.dart';
import 'package:countr/features/life_counter/data/network/in_memory_p2p_mesh.dart';

void main() {
  group('P2pPacketType', () {
    test('contains all 14 expected packet types with proper wire names', () {
      final expectedWireNames = {
        P2pPacketType.handshakeRequest: 'handshake_request',
        P2pPacketType.handshakeResponse: 'handshake_response',
        P2pPacketType.syncState: 'sync_state',
        P2pPacketType.lifeDelta: 'life_delta',
        P2pPacketType.commanderDamage: 'commander_damage',
        P2pPacketType.counterDelta: 'counter_delta',
        P2pPacketType.manaDelta: 'mana_delta',
        P2pPacketType.manaClear: 'mana_clear',
        P2pPacketType.dayNightToggle: 'day_night_toggle',
        P2pPacketType.claimToken: 'claim_token',
        P2pPacketType.resetGame: 'reset_game',
        P2pPacketType.heartbeat: 'heartbeat',
        P2pPacketType.catchupRequest: 'catchup_request',
        P2pPacketType.catchupResponse: 'catchup_response',
      };

      expect(P2pPacketType.values.length, 14);
      for (final entry in expectedWireNames.entries) {
        expect(entry.key.wireName, entry.value);
      }
    });

    test('fromWireName correctly parses standard wire names', () {
      expect(
        P2pPacketType.fromWireName('handshake_request'),
        P2pPacketType.handshakeRequest,
      );
      expect(
        P2pPacketType.fromWireName('life_delta'),
        P2pPacketType.lifeDelta,
      );
      expect(
        P2pPacketType.fromWireName('commander_damage'),
        P2pPacketType.commanderDamage,
      );
      expect(
        P2pPacketType.fromWireName('counter_delta'),
        P2pPacketType.counterDelta,
      );
      expect(
        P2pPacketType.fromWireName('mana_delta'),
        P2pPacketType.manaDelta,
      );
      expect(
        P2pPacketType.fromWireName('mana_clear'),
        P2pPacketType.manaClear,
      );
      expect(
        P2pPacketType.fromWireName('day_night_toggle'),
        P2pPacketType.dayNightToggle,
      );
      expect(
        P2pPacketType.fromWireName('claim_token'),
        P2pPacketType.claimToken,
      );
      expect(
        P2pPacketType.fromWireName('reset_game'),
        P2pPacketType.resetGame,
      );
      expect(
        P2pPacketType.fromWireName('heartbeat'),
        P2pPacketType.heartbeat,
      );
      expect(
        P2pPacketType.fromWireName('catchup_request'),
        P2pPacketType.catchupRequest,
      );
      expect(
        P2pPacketType.fromWireName('catchup_response'),
        P2pPacketType.catchupResponse,
      );
    });

    test('fromWireName normalizes casing and hyphens', () {
      expect(
        P2pPacketType.fromWireName('LIFE_DELTA'),
        P2pPacketType.lifeDelta,
      );
      expect(
        P2pPacketType.fromWireName('life-delta'),
        P2pPacketType.lifeDelta,
      );
      expect(
        P2pPacketType.fromWireName('lifeDelta'),
        P2pPacketType.lifeDelta,
      );
      expect(
        P2pPacketType.fromWireName('  SYNC_STATE  '),
        P2pPacketType.syncState,
      );
    });

    test('fromWireName falls back safely to heartbeat for unknown strings', () {
      expect(
        P2pPacketType.fromWireName('unknown_future_packet'),
        P2pPacketType.heartbeat,
      );
      expect(
        P2pPacketType.fromWireName(''),
        P2pPacketType.heartbeat,
      );
    });

    test('isStateMutation accurately categorizes packet mutations', () {
      expect(P2pPacketType.lifeDelta.isStateMutation, isTrue);
      expect(P2pPacketType.commanderDamage.isStateMutation, isTrue);
      expect(P2pPacketType.counterDelta.isStateMutation, isTrue);
      expect(P2pPacketType.manaDelta.isStateMutation, isTrue);
      expect(P2pPacketType.manaClear.isStateMutation, isTrue);
      expect(P2pPacketType.dayNightToggle.isStateMutation, isTrue);
      expect(P2pPacketType.claimToken.isStateMutation, isTrue);
      expect(P2pPacketType.resetGame.isStateMutation, isTrue);

      expect(P2pPacketType.handshakeRequest.isStateMutation, isFalse);
      expect(P2pPacketType.heartbeat.isStateMutation, isFalse);
      expect(P2pPacketType.syncState.isStateMutation, isFalse);
    });

    test('isLobbyControl accurately categorizes network control packets', () {
      expect(P2pPacketType.handshakeRequest.isLobbyControl, isTrue);
      expect(P2pPacketType.handshakeResponse.isLobbyControl, isTrue);
      expect(P2pPacketType.syncState.isLobbyControl, isTrue);
      expect(P2pPacketType.heartbeat.isLobbyControl, isTrue);
      expect(P2pPacketType.catchupRequest.isLobbyControl, isTrue);
      expect(P2pPacketType.catchupResponse.isLobbyControl, isTrue);

      expect(P2pPacketType.lifeDelta.isLobbyControl, isFalse);
      expect(P2pPacketType.manaDelta.isLobbyControl, isFalse);
    });
  });

  group('P2pPacket Serialization & Deserialization', () {
    test('encodes and decodes standard packet round-trip accurately', () {
      final packet = P2pPacket(
        type: P2pPacketType.lifeDelta,
        senderId: 'host_node',
        sequenceNumber: 42,
        targetPlayerId: 'p1',
        delta: -3,
        value: 37,
        payload: {'reason': 'combat_damage'},
        timestamp: 1727392500000,
      );

      final raw = packet.encode();
      final decoded = P2pPacket.decode(raw);

      expect(decoded.type, P2pPacketType.lifeDelta);
      expect(decoded.senderId, 'host_node');
      expect(decoded.sequenceNumber, 42);
      expect(decoded.targetPlayerId, 'p1');
      expect(decoded.delta, -3);
      expect(decoded.value, 37);
      expect(decoded.payload['reason'], 'combat_damage');
      expect(decoded.timestamp, 1727392500000);
      expect(decoded, equals(packet));
    });

    test('toJson generates all expected wire contract keys', () {
      final packet = P2pPacket(
        type: P2pPacketType.commanderDamage,
        senderId: 'client_bob',
        sequenceNumber: 15,
        targetPlayerId: 'p2',
        delta: 7,
        value: 14,
        payload: {'source_player_id': 'p1'},
        timestamp: 1000,
      );

      final json = packet.toJson();

      expect(json['type'], 'commander_damage');
      expect(json['sender_id'], 'client_bob');
      expect(json['sequence_number'], 15);
      expect(json['target_player_id'], 'p2');
      expect(json['delta'], 7);
      expect(json['value'], 14);
      expect(json['payload'], {'source_player_id': 'p1'});
      expect(json['timestamp'], 1000);
    });

    test('fromJson handles camelCase keys gracefully', () {
      final json = {
        'type': 'counter_delta',
        'senderId': 'node_alpha',
        'sequenceNumber': 99,
        'targetPlayerId': 'player_x',
        'delta': 2,
        'value': 0,
        'payload': {'counter_type': 'poison'},
      };

      final packet = P2pPacket.fromJson(json);

      expect(packet.type, P2pPacketType.counterDelta);
      expect(packet.senderId, 'node_alpha');
      expect(packet.sequenceNumber, 99);
      expect(packet.targetPlayerId, 'player_x');
      expect(packet.delta, 2);
      expect(packet.payload['counter_type'], 'poison');
    });

    test('fromJson handles missing or malformed fields safely', () {
      final json = <String, dynamic>{};
      final packet = P2pPacket.fromJson(json);

      expect(packet.type, P2pPacketType.heartbeat);
      expect(packet.senderId, '');
      expect(packet.sequenceNumber, 0);
      expect(packet.targetPlayerId, isNull);
      expect(packet.delta, 0);
      expect(packet.value, 0);
      expect(packet.payload, isEmpty);
      expect(packet.timestamp, greaterThan(0));
    });

    test('handles negative sequence numbers and negative deltas', () {
      final packet = P2pPacket(
        type: P2pPacketType.heartbeat,
        senderId: 'pre_sync_node',
        sequenceNumber: -1,
        delta: -999,
      );

      final decoded = P2pPacket.decode(packet.encode());
      expect(decoded.sequenceNumber, -1);
      expect(decoded.delta, -999);
    });
  });

  group('P2pPacket Resilient Type Coercion & Heterogeneous Payloads', () {
    test('coerces stringified integers for sequenceNumber, delta, value, and timestamp', () {
      final json = {
        'type': 'life_delta',
        'sender_id': 'peer_1',
        'sequence_number': '10',
        'target_player_id': 'p1',
        'delta': '-5',
        'value': '35',
        'timestamp': '1727395000000',
      };

      final packet = P2pPacket.fromJson(json);

      expect(packet.sequenceNumber, equals(10));
      expect(packet.delta, equals(-5));
      expect(packet.value, equals(35));
      expect(packet.timestamp, equals(1727395000000));
    });

    test('coerces camelCase stringified integers', () {
      final json = {
        'type': 'counter_delta',
        'senderId': 'node_2',
        'sequenceNumber': '42',
        'targetPlayerId': 'p2',
        'delta': '+3',
        'value': '10',
      };

      final packet = P2pPacket.fromJson(json);

      expect(packet.sequenceNumber, equals(42));
      expect(packet.delta, equals(3));
      expect(packet.value, equals(10));
    });

    test('coerces stringified floating-point values and num doubles to int', () {
      final json = {
        'type': 'mana_delta',
        'sequence_number': 15.0,
        'delta': '3.0',
        'value': 20.9,
        'timestamp': 1727395000000.0,
      };

      final packet = P2pPacket.fromJson(json);

      expect(packet.sequenceNumber, equals(15));
      expect(packet.delta, equals(3));
      expect(packet.value, equals(20));
      expect(packet.timestamp, equals(1727395000000));
    });

    test('coerces numeric and non-string target_player_id to String', () {
      final jsonNumericTarget = {
        'type': 'life_delta',
        'target_player_id': 1,
      };
      expect(P2pPacket.fromJson(jsonNumericTarget).targetPlayerId, equals('1'));

      final jsonZeroTarget = {
        'type': 'life_delta',
        'target_player_id': 0,
      };
      expect(P2pPacket.fromJson(jsonZeroTarget).targetPlayerId, equals('0'));

      final jsonCamelCaseTarget = {
        'type': 'life_delta',
        'targetPlayerId': 99,
      };
      expect(P2pPacket.fromJson(jsonCamelCaseTarget).targetPlayerId, equals('99'));

      final jsonNullTarget = {
        'type': 'life_delta',
        'target_player_id': null,
      };
      expect(P2pPacket.fromJson(jsonNullTarget).targetPlayerId, isNull);
    });

    test('coerces numeric and non-string sender_id to String', () {
      final jsonNumericSender = {
        'type': 'heartbeat',
        'sender_id': 505,
      };
      expect(P2pPacket.fromJson(jsonNumericSender).senderId, equals('505'));

      final jsonCamelCaseSender = {
        'type': 'heartbeat',
        'senderId': 777,
      };
      expect(P2pPacket.fromJson(jsonCamelCaseSender).senderId, equals('777'));
    });

    test('rejects unparseable or malformed numeric strings with FormatException', () {
      final json = {
        'type': 'life_delta',
        'sequence_number': 'not_a_number',
      };

      expect(() => P2pPacket.fromJson(json), throwsA(isA<FormatException>()));
    });

    test('preserves explicit 0 for timestamp and sequence_number even as string', () {
      final json = {
        'sequence_number': '0',
        'timestamp': '0',
      };

      final packet = P2pPacket.fromJson(json);

      expect(packet.sequenceNumber, equals(0));
      expect(packet.timestamp, equals(0));
    });

    test('rejects unexpected object types (bool, list, map) for numeric fields with FormatException', () {
      expect(
        () => P2pPacket.fromJson({'sequence_number': true}),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => P2pPacket.fromJson({'delta': ['invalid']}),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => P2pPacket.fromJson({'value': {'nested': 'map'}}),
        throwsA(isA<FormatException>()),
      );
    });

    test('full round-trip: heterogeneous JSON payload coerces and re-serializes cleanly', () {
      final heterogeneousJson = {
        'type': 'life_delta',
        'sender_id': 101,
        'sequence_number': '42',
        'target_player_id': 2,
        'delta': '-5',
        'value': '35',
        'payload': {'reason': 'combat'},
        'timestamp': '1727395000000',
      };

      final packet = P2pPacket.fromJson(heterogeneousJson);

      expect(packet.type, equals(P2pPacketType.lifeDelta));
      expect(packet.senderId, equals('101'));
      expect(packet.sequenceNumber, equals(42));
      expect(packet.targetPlayerId, equals('2'));
      expect(packet.delta, equals(-5));
      expect(packet.value, equals(35));
      expect(packet.payload['reason'], equals('combat'));
      expect(packet.timestamp, equals(1727395000000));

      final serialized = packet.toJson();
      expect(serialized['sender_id'], equals('101'));
      expect(serialized['sequence_number'], equals(42));
      expect(serialized['sequence_number'], isA<int>());
      expect(serialized['target_player_id'], equals('2'));
      expect(serialized['target_player_id'], isA<String>());
      expect(serialized['delta'], equals(-5));
      expect(serialized['delta'], isA<int>());
      expect(serialized['value'], equals(35));
      expect(serialized['value'], isA<int>());
      expect(serialized['timestamp'], equals(1727395000000));
      expect(serialized['timestamp'], isA<int>());
    });
  });

  group('P2pPacket Typed Factory Constructors', () {
    test('handshakeRequest creates correct packet payload', () {
      final pkt = P2pPacket.handshakeRequest(
        senderId: 'dev_1',
        playerName: 'Alice',
        deckName: 'Atraxa EDH',
        commanderName: 'Atraxa',
      );

      expect(pkt.type, P2pPacketType.handshakeRequest);
      expect(pkt.senderId, 'dev_1');
      expect(pkt.payload['playerName'], 'Alice');
      expect(pkt.payload['deckName'], 'Atraxa EDH');
      expect(pkt.payload['commanderName'], 'Atraxa');
    });

    test('handshakeResponse creates correct packet payload', () {
      final pkt = P2pPacket.handshakeResponse(
        senderId: 'host_node',
        status: 'ACCEPTED',
        assignedPlayerId: 'p2',
        roomCode: 'MTG42',
        seatIndex: 1,
      );

      expect(pkt.type, P2pPacketType.handshakeResponse);
      expect(pkt.payload['status'], 'ACCEPTED');
      expect(pkt.payload['assignedPlayerId'], 'p2');
      expect(pkt.payload['roomCode'], 'MTG42');
      expect(pkt.payload['seatIndex'], 1);
    });

    test('syncState wraps state JSON payload', () {
      final stateJson = {'sessionId': 'ses_1', 'format': 'commander'};
      final pkt = P2pPacket.syncState(
        senderId: 'host_node',
        sequenceNumber: 10,
        stateJson: stateJson,
      );

      expect(pkt.type, P2pPacketType.syncState);
      expect(pkt.sequenceNumber, 10);
      expect(pkt.payload['state'], stateJson);
    });

    test('commanderDamage formats source player and lethal flag', () {
      final pkt = P2pPacket.commanderDamage(
        senderId: 'host_node',
        sequenceNumber: 5,
        targetPlayerId: 'p1',
        sourcePlayerId: 'p2',
        damageDelta: 7,
        newTotal: 21,
        isLethal: true,
      );

      expect(pkt.type, P2pPacketType.commanderDamage);
      expect(pkt.targetPlayerId, 'p1');
      expect(pkt.delta, 7);
      expect(pkt.payload['source_player_id'], 'p2');
      expect(pkt.payload['new_total'], 21);
      expect(pkt.payload['is_lethal'], isTrue);
    });

    test('manaDelta and manaClear constructors format correctly', () {
      final deltaPkt = P2pPacket.manaDelta(
        senderId: 'p1_node',
        sequenceNumber: 8,
        targetPlayerId: 'p1',
        color: 'U',
        delta: 3,
      );
      expect(deltaPkt.type, P2pPacketType.manaDelta);
      expect(deltaPkt.delta, 3);
      expect(deltaPkt.payload['color'], 'U');

      final clearPkt = P2pPacket.manaClear(
        senderId: 'p1_node',
        sequenceNumber: 9,
        targetPlayerId: 'p1',
      );
      expect(clearPkt.type, P2pPacketType.manaClear);
      expect(clearPkt.targetPlayerId, 'p1');
    });

    test('claimToken formats tokenType and claimantId', () {
      final pkt = P2pPacket.claimToken(
        senderId: 'node_x',
        sequenceNumber: 22,
        tokenType: 'monarch',
        claimantId: 'p3',
      );

      expect(pkt.type, P2pPacketType.claimToken);
      expect(pkt.targetPlayerId, 'p3');
      expect(pkt.payload['token_type'], 'monarch');
    });

    test('resetGame formats starting life value', () {
      final pkt = P2pPacket.resetGame(
        senderId: 'host_node',
        sequenceNumber: 50,
        startingLife: 30,
      );

      expect(pkt.type, P2pPacketType.resetGame);
      expect(pkt.value, 30);
    });

    test('catchupRequest and catchupResponse constructors', () {
      final req = P2pPacket.catchupRequest(
        senderId: 'client_node',
        fromSequenceNumber: 12,
      );
      expect(req.type, P2pPacketType.catchupRequest);
      expect(req.payload['from_sequence_number'], 12);

      final res = P2pPacket.catchupResponse(
        senderId: 'host_node',
        sequenceNumber: 15,
        events: [
          {'seq': 13},
          {'seq': 14},
        ],
      );
      expect(res.type, P2pPacketType.catchupResponse);
      expect(res.sequenceNumber, 15);
      expect(res.payload['events'], hasLength(2));
    });
  });

  group('P2pPacket Immutability & Value Equality', () {
    test('copyWith overrides specified fields correctly', () {
      final original = P2pPacket(
        type: P2pPacketType.lifeDelta,
        senderId: 'node_1',
        sequenceNumber: 5,
        targetPlayerId: 'p1',
        delta: -2,
        timestamp: 1000,
      );

      final modified = original.copyWith(
        sequenceNumber: 6,
        delta: -4,
      );

      expect(modified.type, P2pPacketType.lifeDelta);
      expect(modified.senderId, 'node_1');
      expect(modified.sequenceNumber, 6);
      expect(modified.targetPlayerId, 'p1');
      expect(modified.delta, -4);
      expect(modified.timestamp, 1000);
    });

    test('identical packets evaluate as equal with matching hashCode', () {
      final p1 = P2pPacket(
        type: P2pPacketType.manaDelta,
        senderId: 'node_a',
        sequenceNumber: 3,
        payload: {'color': 'B'},
        timestamp: 5000,
      );
      final p2 = P2pPacket(
        type: P2pPacketType.manaDelta,
        senderId: 'node_a',
        sequenceNumber: 3,
        payload: {'color': 'B'},
        timestamp: 5000,
      );

      expect(p1, equals(p2));
      expect(p1.hashCode, equals(p2.hashCode));
    });
  });

  group('PeerStatus and PeerConnectionState', () {
    test('PeerConnectionState isActive reflects connected state', () {
      expect(PeerConnectionState.connected.isActive, isTrue);
      expect(PeerConnectionState.disconnected.isActive, isFalse);
      expect(PeerConnectionState.discovering.isActive, isFalse);
      expect(PeerConnectionState.connecting.isActive, isFalse);
      expect(PeerConnectionState.reconnecting.isActive, isFalse);
    });

    test('PeerStatus serialization and deserialization', () {
      const status = PeerStatus(
        peerId: 'peer_1',
        playerName: 'Bob',
        state: PeerConnectionState.connected,
        latencyMs: 14,
        timestamp: 12345,
      );

      final json = status.toJson();
      final parsed = PeerStatus.fromJson(json);

      expect(parsed.peerId, 'peer_1');
      expect(parsed.playerName, 'Bob');
      expect(parsed.state, PeerConnectionState.connected);
      expect(parsed.latencyMs, 14);
      expect(parsed.timestamp, 12345);
      expect(parsed, equals(status));
    });
  });

  group('InMemoryP2pMesh and InMemoryP2pTransport', () {
    late InMemoryP2pMesh mesh;
    late InMemoryP2pTransport host;
    late InMemoryP2pTransport clientA;
    late InMemoryP2pTransport clientB;

    setUp(() {
      mesh = InMemoryP2pMesh();
      host = mesh.createNode('host');
      clientA = mesh.createNode('clientA');
      clientB = mesh.createNode('clientB');
    });

    test('routes broadcast packets to all peers except sender', () async {
      final hostReceived = <P2pPacket>[];
      final clientAReceived = <P2pPacket>[];
      final clientBReceived = <P2pPacket>[];

      host.incomingPackets.listen(hostReceived.add);
      clientA.incomingPackets.listen(clientAReceived.add);
      clientB.incomingPackets.listen(clientBReceived.add);

      final pkt = P2pPacket(
        type: P2pPacketType.lifeDelta,
        senderId: 'host',
        sequenceNumber: 1,
        targetPlayerId: 'p1',
        delta: -1,
      );

      await host.broadcastPacket(pkt);

      expect(hostReceived, isEmpty,
          reason: 'Sender must not receive own packet');
      expect(clientAReceived, hasLength(1));
      expect(clientBReceived, hasLength(1));
      expect(clientAReceived.first.delta, -1);
      expect(clientBReceived.first.delta, -1);
    });

    test('disconnected transport throws StateError when attempting transmission',
        () async {
      await clientA.disconnect();
      expect(clientA.isConnected, isFalse);

      expect(
        () => clientA.sendPacket(P2pPacket(
          type: P2pPacketType.heartbeat,
          senderId: 'clientA',
          sequenceNumber: 0,
        )),
        throwsStateError,
      );

      expect(
        () => clientA.sendTo(
            'host',
            P2pPacket(
              type: P2pPacketType.heartbeat,
              senderId: 'clientA',
              sequenceNumber: 0,
            )),
        throwsStateError,
      );
    });

    test(
        'reconnecting transport resumes packet reception and updates state',
        () async {
      final received = <P2pPacket>[];
      clientA.incomingPackets.listen(received.add);

      await clientA.disconnect();
      expect(clientA.isConnected, isFalse);

      // Packet sent while disconnected is not received
      await host.sendPacket(P2pPacket(
        type: P2pPacketType.heartbeat,
        senderId: 'host',
        sequenceNumber: 1,
      ));
      expect(received, isEmpty);

      // Reconnect and send again
      clientA.reconnect();
      expect(clientA.isConnected, isTrue);

      await host.sendPacket(P2pPacket(
        type: P2pPacketType.heartbeat,
        senderId: 'host',
        sequenceNumber: 2,
      ));
      expect(received, hasLength(1));
      expect(received.first.sequenceNumber, 2);
    });

    test('peerStatusStream emits disconnect and reconnect events', () async {
      final statuses = <PeerStatus>[];
      clientA.peerStatusStream.listen(statuses.add);

      await clientA.disconnect();
      expect(statuses, hasLength(1));
      expect(statuses.first.state, PeerConnectionState.disconnected);

      clientA.reconnect();
      await Future.delayed(Duration.zero);
      expect(statuses, hasLength(2));
      expect(statuses.last.state, PeerConnectionState.connected);
    });

    test('sendTo delivers packet only to designated target endpoint', () async {
      final clientAReceived = <P2pPacket>[];
      final clientBReceived = <P2pPacket>[];

      clientA.incomingPackets.listen(clientAReceived.add);
      clientB.incomingPackets.listen(clientBReceived.add);

      final targetedPkt = P2pPacket(
        type: P2pPacketType.handshakeResponse,
        senderId: 'host',
        sequenceNumber: 1,
      );

      await host.sendTo('clientA', targetedPkt);

      expect(clientAReceived, hasLength(1));
      expect(clientBReceived, isEmpty);
    });

    test('packetDropRate == 1.0 drops all packets in mesh', () async {
      mesh.packetDropRate = 1.0;
      final received = <P2pPacket>[];
      clientA.incomingPackets.listen(received.add);

      await host.sendPacket(P2pPacket(
        type: P2pPacketType.heartbeat,
        senderId: 'host',
        sequenceNumber: 1,
      ));

      expect(received, isEmpty);
      expect(mesh.totalPacketsDropped, 1);
    });

    test('mesh node management and clear', () {
      expect(mesh.nodeCount, 3);
      expect(
          mesh.connectedNodeIds, containsAll(['host', 'clientA', 'clientB']));

      mesh.removeNode('clientB');
      expect(mesh.nodeCount, 2);

      mesh.reset();
      expect(mesh.nodeCount, 0);
      expect(mesh.connectedNodeIds, isEmpty);
    });
  });
}
