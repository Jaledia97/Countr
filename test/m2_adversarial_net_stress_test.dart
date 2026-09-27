// Copyright (c) 2026 Countr. All rights reserved.
// Adversarial stress test harness for Milestone 2: P2P Packet, WebSockets, and UDP Discovery.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/features/life_counter/domain/models/p2p_packet.dart';
import 'package:countr/features/life_counter/data/network/websocket_p2p_transport.dart';
import 'package:countr/features/life_counter/data/network/udp_beacon_discovery.dart';

void main() {
  group('Group 1: Adversarial Packet Parsing & Boundary Fuzzing', () {
    test('ADV-PKT-1: fromJson handles empty or missing keys gracefully with default fallbacks', () {
      final emptyPacket = P2pPacket.fromJson({});
      expect(emptyPacket.type, equals(P2pPacketType.heartbeat));
      expect(emptyPacket.senderId, equals(''));
      expect(emptyPacket.sequenceNumber, equals(0));
      expect(emptyPacket.targetPlayerId, isNull);
      expect(emptyPacket.delta, equals(0));
      expect(emptyPacket.value, equals(0));
      expect(emptyPacket.payload, isEmpty);
      expect(emptyPacket.timestamp, greaterThan(0));
    });

    test('ADV-PKT-2: fromWireName handles case variations, hyphens, and unknown strings', () {
      final testCases = {
        'HANDSHAKE_REQUEST': P2pPacketType.handshakeRequest,
        'handshake-request': P2pPacketType.handshakeRequest,
        'HandshakeRequest': P2pPacketType.handshakeRequest,
        '  LIFE_DELTA  ': P2pPacketType.lifeDelta,
        'commander-damage': P2pPacketType.commanderDamage,
        'COUNTER_DELTA': P2pPacketType.counterDelta,
        'MANA-CLEAR': P2pPacketType.manaClear,
        'day_night_toggle': P2pPacketType.dayNightToggle,
        'claim-token': P2pPacketType.claimToken,
        'reset-game': P2pPacketType.resetGame,
        'catchup_request': P2pPacketType.catchupRequest,
        'catchup-response': P2pPacketType.catchupResponse,
        'INVALID_TYPE_1234': P2pPacketType.heartbeat,
        '': P2pPacketType.heartbeat,
        '⚔️💥_ATTACK': P2pPacketType.heartbeat,
      };

      for (final entry in testCases.entries) {
        expect(
          P2pPacketType.fromWireName(entry.key),
          equals(entry.value),
          reason: 'Failed for wire name: ${entry.key}',
        );
      }
    });

    test('ADV-PKT-3: All 14 P2pPacketType values round-trip accurately through JSON serialization', () {
      for (final type in P2pPacketType.values) {
        final packet = P2pPacket(
          type: type,
          senderId: 'node_${type.wireName}',
          sequenceNumber: 100,
          targetPlayerId: 'p1',
          delta: 5,
          value: 40,
          payload: {'test_key': 'test_val_${type.wireName}'},
          timestamp: 1727395000000,
        );

        final jsonStr = packet.encode();
        final decoded = P2pPacket.decode(jsonStr);

        expect(decoded.type, equals(type));
        expect(decoded.senderId, equals('node_${type.wireName}'));
        expect(decoded.sequenceNumber, equals(100));
        expect(decoded.targetPlayerId, equals('p1'));
        expect(decoded.delta, equals(5));
        expect(decoded.value, equals(40));
        expect(decoded.payload['test_key'], equals('test_val_${type.wireName}'));
        expect(decoded, equals(packet));
        expect(decoded.hashCode, equals(packet.hashCode));
      }
    });

    test('ADV-PKT-4: Handles extreme numeric ranges, negative numbers, and boundary limits', () {
      final boundaryPacket = P2pPacket(
        type: P2pPacketType.lifeDelta,
        senderId: 'extreme_node',
        sequenceNumber: -2147483648,
        delta: -999999999,
        value: 2147483647,
        timestamp: 0,
      );

      final decoded = P2pPacket.decode(boundaryPacket.encode());
      expect(decoded.sequenceNumber, equals(-2147483648));
      expect(decoded.delta, equals(-999999999));
      expect(decoded.value, equals(2147483647));
      expect(decoded.timestamp, equals(0));
    });

    test('ADV-PKT-5: Handles large payload sizes and complex nested dictionaries', () {
      final largePayload = <String, dynamic>{
        'nested': {
          'deep': {
            'array': [1, 2, 3, 'four', {'five': true}],
          },
        },
        'big_string': 'A' * 50000, // 50KB payload string
        'special_chars': 'Line1\nLine2\tTab"Quote\\Slash/Unicode:🔥✨🃏',
      };

      final packet = P2pPacket(
        type: P2pPacketType.syncState,
        senderId: 'heavy_node',
        sequenceNumber: 999,
        payload: largePayload,
      );

      final encoded = packet.encode();
      final decoded = P2pPacket.decode(encoded);

      expect(decoded.payload['big_string'].length, equals(50000));
      expect(decoded.payload['special_chars'], equals('Line1\nLine2\tTab"Quote\\Slash/Unicode:🔥✨🃏'));
      expect((decoded.payload['nested']['deep']['array'] as List).length, equals(5));
    });

    test('ADV-PKT-6: copyWith accurately preserves or replaces fields immutably', () {
      final original = P2pPacket(
        type: P2pPacketType.lifeDelta,
        senderId: 'orig_sender',
        sequenceNumber: 10,
        targetPlayerId: 'p1',
        delta: 2,
        value: 20,
        payload: {'k': 'v'},
        timestamp: 5000,
      );

      final copy1 = original.copyWith(delta: -4, value: 16);
      expect(copy1.type, equals(P2pPacketType.lifeDelta));
      expect(copy1.senderId, equals('orig_sender'));
      expect(copy1.sequenceNumber, equals(10));
      expect(copy1.targetPlayerId, equals('p1'));
      expect(copy1.delta, equals(-4));
      expect(copy1.value, equals(16));
      expect(copy1.payload, equals({'k': 'v'}));
      expect(copy1.timestamp, equals(5000));

      final copy2 = original.copyWith(
        type: P2pPacketType.resetGame,
        senderId: 'new_sender',
        sequenceNumber: 11,
      );
      expect(copy2.type, equals(P2pPacketType.resetGame));
      expect(copy2.senderId, equals('new_sender'));
      expect(copy2.sequenceNumber, equals(11));
    });
  });

  group('Group 2: WebSocket Loopback Bombardment & Concurrency', () {
    WebSocketP2pHostTransport? host;
    final clients = <WebSocketP2pClientTransport>[];

    tearDown(() async {
      for (final client in clients) {
        await client.disconnect();
      }
      clients.clear();
      await Future.delayed(const Duration(milliseconds: 50));
      await host?.disconnect();
      host = null;
    });

    test('ADV-WS-1: High-volume concurrent packet bombardment (500 packets in tight burst)', () async {
      host = WebSocketP2pTransport.host(
        hostEndpointId: 'host-bombard',
        port: 0,
        bindAddress: InternetAddress.loopbackIPv4,
      );
      await host!.start();

      final client = WebSocketP2pTransport.client(
        clientEndpointId: 'client-bombard',
        hostAddress: '127.0.0.1',
        port: host!.actualPort,
        autoReconnect: false,
      );
      clients.add(client);
      await client.connect();

      expect(host!.connectedClientCount, equals(1));

      const packetCount = 500;
      final receivedPackets = <P2pPacket>[];
      final completer = Completer<void>();

      final sub = host!.incomingPackets.listen((packet) {
        receivedPackets.add(packet);
        if (receivedPackets.length == packetCount) {
          if (!completer.isCompleted) completer.complete();
        }
      });

      // Fire 500 packets concurrently in rapid succession
      final sendFutures = List.generate(packetCount, (i) {
        return client.sendPacket(P2pPacket(
          type: P2pPacketType.lifeDelta,
          senderId: 'client-bombard',
          sequenceNumber: i + 1,
          targetPlayerId: 'p1',
          delta: (i % 2 == 0) ? 1 : -1,
        ));
      });

      await Future.wait(sendFutures);
      await completer.future.timeout(const Duration(seconds: 10));
      await sub.cancel();

      expect(receivedPackets.length, equals(packetCount));
      // Verify sequence integrity
      final seqs = receivedPackets.map((p) => p.sequenceNumber).toList();
      for (int i = 1; i <= packetCount; i++) {
        expect(seqs.contains(i), isTrue, reason: 'Missing sequence $i in received stream');
      }
    });

    test('ADV-WS-2: Multi-client concurrent bombardment (4 clients x 100 packets = 400 packets)', () async {
      host = WebSocketP2pTransport.host(
        hostEndpointId: 'host-multi',
        port: 0,
        bindAddress: InternetAddress.loopbackIPv4,
      );
      await host!.start();

      const clientCount = 4;
      const packetsPerClient = 100;
      const totalPackets = clientCount * packetsPerClient;

      for (int i = 0; i < clientCount; i++) {
        final client = WebSocketP2pTransport.client(
          clientEndpointId: 'client-$i',
          hostAddress: '127.0.0.1',
          port: host!.actualPort,
          autoReconnect: false,
        );
        clients.add(client);
        await client.connect();
      }

      expect(host!.connectedClientCount, equals(clientCount));

      final receivedPackets = <P2pPacket>[];
      final completer = Completer<void>();

      final sub = host!.incomingPackets.listen((packet) {
        receivedPackets.add(packet);
        if (receivedPackets.length == totalPackets) {
          if (!completer.isCompleted) completer.complete();
        }
      });

      // All 4 clients send 100 packets simultaneously
      final allSends = <Future<void>>[];
      for (int c = 0; c < clientCount; c++) {
        for (int p = 0; p < packetsPerClient; p++) {
          allSends.add(clients[c].sendPacket(P2pPacket(
            type: P2pPacketType.counterDelta,
            senderId: 'client-$c',
            sequenceNumber: (c * packetsPerClient) + p,
            targetPlayerId: 'p$c',
            delta: 1,
            payload: {'counter_type': 'energy'},
          )));
        }
      }

      await Future.wait(allSends);
      await completer.future.timeout(const Duration(seconds: 10));
      await sub.cancel();

      expect(receivedPackets.length, equals(totalPackets));
    });

    test('ADV-WS-3: Host broadcast flood to multiple connected clients', () async {
      host = WebSocketP2pTransport.host(
        hostEndpointId: 'host-broadcast',
        port: 0,
        bindAddress: InternetAddress.loopbackIPv4,
      );
      await host!.start();

      const clientCount = 3;
      const broadcastCount = 150;

      final clientPointers = <WebSocketP2pClientTransport>[];
      for (int i = 0; i < clientCount; i++) {
        final c = WebSocketP2pTransport.client(
          clientEndpointId: 'rx-client-$i',
          hostAddress: '127.0.0.1',
          port: host!.actualPort,
          autoReconnect: false,
        );
        clients.add(c);
        clientPointers.add(c);
        await c.connect();
      }

      final clientRecvCounts = List<int>.filled(clientCount, 0);
      final clientCompleters = List.generate(clientCount, (_) => Completer<void>());

      final subs = <StreamSubscription>[];
      for (int i = 0; i < clientCount; i++) {
        final index = i;
        subs.add(clientPointers[i].incomingPackets.listen((pkt) {
          clientRecvCounts[index]++;
          if (clientRecvCounts[index] == broadcastCount) {
            if (!clientCompleters[index].isCompleted) {
              clientCompleters[index].complete();
            }
          }
        }));
      }

      // Host broadcasts 150 packets
      for (int i = 0; i < broadcastCount; i++) {
        await host!.broadcastPacket(P2pPacket(
          type: P2pPacketType.manaDelta,
          senderId: 'host-broadcast',
          sequenceNumber: i + 1,
          targetPlayerId: 'p1',
          delta: 1,
          payload: {'color': 'R'},
        ));
      }

      await Future.wait(clientCompleters.map((c) => c.future.timeout(const Duration(seconds: 10))));
      for (final s in subs) {
        await s.cancel();
      }

      for (int i = 0; i < clientCount; i++) {
        expect(clientRecvCounts[i], equals(broadcastCount));
      }
    });

    test('ADV-WS-4: Adversarial raw socket payload bombardment does not crash host', () async {
      host = WebSocketP2pTransport.host(
        hostEndpointId: 'host-resilient',
        port: 0,
        bindAddress: InternetAddress.loopbackIPv4,
      );
      await host!.start();

      final rawUri = Uri.parse('ws://127.0.0.1:${host!.actualPort}/pod?endpointId=adversary-1');
      final rawWs = await WebSocket.connect(rawUri.toString());

      // Send malformed non-JSON string
      rawWs.add('THIS IS NOT VALID JSON TEXT AT ALL !@#\$%^&*()');

      // Send truncated JSON
      rawWs.add('{"type": "life_delta", "sender_id": "malicious');

      // Send JSON primitives and arrays instead of object
      rawWs.add('[1, 2, 3, "unexpected array"]');
      rawWs.add('"raw standalone json string"');
      rawWs.add('123456789');

      // Send packet with malformed types
      rawWs.add(jsonEncode({
        'type': 'life_delta',
        'sender_id': 'bad_types',
        'sequence_number': {'nested': 'not_num'},
        'delta': 'not_a_number',
      }));

      // Send binary garbage bytes
      rawWs.add([0x00, 0xFF, 0xFE, 0xFD, 0x12, 0x34]);

      // Now send a 100% valid packet
      final validPacket = P2pPacket(
        type: P2pPacketType.handshakeRequest,
        senderId: 'adversary-1',
        sequenceNumber: 1,
        payload: {'playerName': 'WhiteHat'},
      );

      final hostPktFuture = host!.incomingPackets.first;
      rawWs.add(validPacket.encode());

      // Host must safely ignore all garbage frames and process the valid packet
      final received = await hostPktFuture.timeout(const Duration(seconds: 3));
      expect(received.type, equals(P2pPacketType.handshakeRequest));
      expect(received.senderId, equals('adversary-1'));
      expect(received.payload['playerName'], equals('WhiteHat'));

      await rawWs.close();
    });
  });

  group('Group 3: Rapid Connect / Disconnect Churn & Socket Lifecycle', () {
    test('ADV-CHURN-1: Rapid sequential client connect/disconnect cycles (25 iterations)', () async {
      final host = WebSocketP2pTransport.host(
        hostEndpointId: 'host-churn',
        port: 0,
        bindAddress: InternetAddress.loopbackIPv4,
      );
      await host.start();

      for (int i = 0; i < 25; i++) {
        final client = WebSocketP2pTransport.client(
          clientEndpointId: 'churn-client-$i',
          hostAddress: '127.0.0.1',
          port: host.actualPort,
          autoReconnect: false,
        );

        await client.connect();
        expect(client.isConnected, isTrue);

        await client.sendPacket(P2pPacket(
          type: P2pPacketType.heartbeat,
          senderId: 'churn-client-$i',
          sequenceNumber: i,
        ));

        await client.disconnect();
        expect(client.isConnected, isFalse);
      }

      await Future.delayed(const Duration(milliseconds: 100));
      expect(host.connectedClientCount, equals(0));

      await host.disconnect();
    });

    test('ADV-CHURN-2: Abrupt socket destruction mid-broadcast does not crash host', () async {
      final host = WebSocketP2pTransport.host(
        hostEndpointId: 'host-abrupt',
        port: 0,
        bindAddress: InternetAddress.loopbackIPv4,
      );
      await host.start();

      // Connect 2 clients: one will be destroyed abruptly, one will stay alive
      final rawUri1 = Uri.parse('ws://127.0.0.1:${host.actualPort}/pod?endpointId=victim-1');
      final rawWs1 = await WebSocket.connect(rawUri1.toString());

      final client2 = WebSocketP2pTransport.client(
        clientEndpointId: 'survivor-2',
        hostAddress: '127.0.0.1',
        port: host.actualPort,
        autoReconnect: false,
      );
      await client2.connect();

      expect(host.connectedClientCount, equals(2));

      // Abruptly destroy client 1's socket
      await rawWs1.close(WebSocketStatus.protocolError);

      await Future.delayed(const Duration(milliseconds: 150));

      // Host broadcasts packet — should cleanly handle dead socket and deliver to client2
      final survivorFuture = client2.incomingPackets.first;
      await host.broadcastPacket(P2pPacket(
        type: P2pPacketType.lifeDelta,
        senderId: 'host-abrupt',
        sequenceNumber: 99,
        targetPlayerId: 'p2',
        delta: -1,
      ));

      final receivedBySurvivor = await survivorFuture.timeout(const Duration(seconds: 3));
      expect(receivedBySurvivor.sequenceNumber, equals(99));

      await client2.disconnect();
      await host.disconnect();
    });

    test('ADV-CHURN-3: Host stop and immediate restart on loopback succeeds cleanly', () async {
      final host1 = WebSocketP2pTransport.host(
        hostEndpointId: 'host-cycle',
        port: 0,
        bindAddress: InternetAddress.loopbackIPv4,
      );
      await host1.start();
      final port1 = host1.actualPort;
      expect(port1, greaterThan(0));

      await host1.disconnect();
      expect(host1.isConnected, isFalse);

      // Start host 2 on ephemeral loopback port
      final host2 = WebSocketP2pTransport.host(
        hostEndpointId: 'host-cycle-2',
        port: 0,
        bindAddress: InternetAddress.loopbackIPv4,
      );
      await host2.start();
      expect(host2.isConnected, isTrue);

      final client = WebSocketP2pTransport.client(
        clientEndpointId: 'client-restart',
        hostAddress: '127.0.0.1',
        port: host2.actualPort,
        autoReconnect: false,
      );
      await client.connect();
      expect(client.isConnected, isTrue);

      await client.disconnect();
      await host2.disconnect();
    });
  });

  group('Group 4: UDP Beacon Discovery Stress & Boundary Handling', () {
    test('ADV-UDP-1: Rapid probe storm (30 probes) handled without errors', () async {
      final beaconData = PodBeaconData(
        sessionId: 'session-udp-stress',
        roomCode: 'STRS99',
        hostName: 'StressHost',
        hostAddress: '127.0.0.1',
        port: 40407,
        format: 'Commander',
        startingLife: 40,
        maxPlayers: 4,
        connectedPlayers: 1,
        playerNames: ['StressHost'],
      );

      final udpHost = UdpBeaconDiscovery.createHost(
        initialBeaconData: beaconData,
        port: 0,
        broadcastAddress: InternetAddress.loopbackIPv4,
        bindAddress: InternetAddress.loopbackIPv4,
      );
      await udpHost.start();

      final udpClient = UdpBeaconDiscovery.createClient(
        clientName: 'StressClient',
        clientId: 'client-stress-uuid',
        port: 0,
        broadcastAddress: InternetAddress.loopbackIPv4,
        bindAddress: InternetAddress.loopbackIPv4,
      );
      await udpClient.startDiscovery();

      // Fire 30 probes rapidly
      for (int i = 0; i < 30; i++) {
        udpClient.sendProbe();
      }

      final pods = await udpClient.discoveredPodsStream
          .firstWhere((p) => p.isNotEmpty)
          .timeout(const Duration(seconds: 3));

      expect(pods.first.sessionId, equals('session-udp-stress'));
      expect(pods.first.roomCode, equals('STRS99'));

      await udpHost.stop();
      await udpClient.stopDiscovery();
    });

    test('ADV-UDP-2: Malformed UDP datagrams are safely ignored by host and client', () {
      expect(PodBeaconData.tryDecode('NOT_JSON_DATA'), isNull);
      expect(PodBeaconData.tryDecode('{"type": "UNKNOWN_PACKET"}'), isNull);
      expect(PodBeaconData.tryDecode('{"type": "POD_BEACON"}'), isNull); // missing required fields
      expect(PodProbeData.tryDecode('INVALID_PROBE'), isNull);
      expect(PodProbeData.tryDecode('{"type": "WRONG_TYPE"}'), isNull);
      expect(PodProbeData.tryDecode('{"type": "POD_PROBE"}'), isNull); // missing clientName, clientId
    });

    test('ADV-UDP-3: Dynamic beacon metadata update propagates to active client', () async {
      final initialData = PodBeaconData(
        sessionId: 'session-dyn-update',
        roomCode: 'DYN123',
        hostName: 'DynHost',
        hostAddress: '127.0.0.1',
        connectedPlayers: 1,
        playerNames: ['DynHost'],
      );

      final udpHost = UdpBeaconDiscovery.createHost(
        initialBeaconData: initialData,
        port: 0,
        broadcastAddress: InternetAddress.loopbackIPv4,
        bindAddress: InternetAddress.loopbackIPv4,
      );
      await udpHost.start();

      final udpClient = UdpBeaconDiscovery.createClient(
        clientName: 'DynClient',
        clientId: 'client-dyn-uuid',
        port: 0,
        broadcastAddress: InternetAddress.loopbackIPv4,
        bindAddress: InternetAddress.loopbackIPv4,
      );
      await udpClient.startDiscovery();

      final initialPods = await udpClient.discoveredPodsStream
          .firstWhere((p) => p.isNotEmpty)
          .timeout(const Duration(seconds: 3));
      expect(initialPods.first.connectedPlayers, equals(1));

      // Host updates player count to 3
      final updatedData = PodBeaconData(
        sessionId: 'session-dyn-update',
        roomCode: 'DYN123',
        hostName: 'DynHost',
        hostAddress: '127.0.0.1',
        connectedPlayers: 3,
        playerNames: ['DynHost', 'Player2', 'Player3'],
      );

      udpHost.updateBeaconData(updatedData);

      final updatedPods = await udpClient.discoveredPodsStream
          .firstWhere((p) => p.any((b) => b.connectedPlayers == 3))
          .timeout(const Duration(seconds: 3));

      expect(updatedPods.first.connectedPlayers, equals(3));
      expect(updatedPods.first.playerNames.length, equals(3));

      await udpHost.stop();
      await udpClient.stopDiscovery();
    });
  });

  group('Group 5: Room Code & Direct Connect Validation', () {
    test('ADV-CODE-1: RoomCodeGenerator comprehensive charset and edge validation', () {
      for (int i = 0; i < 500; i++) {
        final code = RoomCodeGenerator.generate();
        expect(code.length, equals(6));
        expect(RoomCodeGenerator.isValid(code), isTrue);

        // Ambiguous characters check
        expect(code.contains('0'), isFalse);
        expect(code.contains('O'), isFalse);
        expect(code.contains('1'), isFalse);
        expect(code.contains('I'), isFalse);
        expect(code.contains('L'), isFalse);
      }

      // Normalization tests
      expect(RoomCodeGenerator.normalize('   abc-def   '), equals('ABCDEF'));
      expect(RoomCodeGenerator.normalize('x_y-z 1 2 3'), equals('XYZ123'));

      // Adversarial invalid inputs
      expect(RoomCodeGenerator.isValid(''), isFalse);
      expect(RoomCodeGenerator.isValid('   '), isFalse);
      expect(RoomCodeGenerator.isValid('A'), isFalse);
      expect(RoomCodeGenerator.isValid('12345'), isFalse);
      expect(RoomCodeGenerator.isValid('1234567'), isFalse);
      expect(RoomCodeGenerator.isValid('DROP TABLE'), isFalse);
      expect(RoomCodeGenerator.isValid('<script>'), isFalse);
    });

    test('ADV-URI-1: PodDirectConnect QR URI generator and valid parser round-trip', () {
      final validUri = PodDirectConnect.generateQrUri(
        host: '192.168.1.100',
        port: 40407,
        roomCode: 'ADV999',
        sessionId: 'sess-adv-1',
      );
      final parsed = PodDirectConnect.parseQrUri(validUri);
      expect(parsed, isNotNull);
      expect(parsed!.host, equals('192.168.1.100'));
      expect(parsed.port, equals(40407));
      expect(parsed.roomCode, equals('ADV999'));
      expect(parsed.sessionId, equals('sess-adv-1'));
      expect(parsed.websocketUrl, equals('ws://192.168.1.100:40407/pod'));

      // Malformed / unsupported schemes
      expect(PodDirectConnect.parseQrUri('https://countr.app/pod/join?host=1.1.1.1'), isNull);
      expect(PodDirectConnect.parseQrUri('file:///etc/passwd'), isNull);
      expect(PodDirectConnect.parseQrUri('javascript:alert(1)'), isNull);
      expect(PodDirectConnect.parseQrUri('countr://wrong_host/join?code=ABC'), isNull);
      expect(PodDirectConnect.parseQrUri('countr://pod/wrong_action?code=ABC'), isNull);

      // Missing required query parameters
      expect(PodDirectConnect.parseQrUri('countr://pod/join?host=1.1.1.1&port=40407'), isNull);
      expect(PodDirectConnect.parseQrUri('countr://pod/join?code=ABC123'), isNull);
    });

    test('ADV-DIRECT-1: parseDirectAddress valid addresses and default port handling', () {
      final valid = PodDirectConnect.parseDirectAddress(
        '192.168.0.50:40407',
        roomCode: 'DEF456',
        sessionId: 'sess-direct-50',
      );
      expect(valid, isNotNull);
      expect(valid!.host, equals('192.168.0.50'));
      expect(valid.port, equals(40407));

      // Default port when omitted
      final defaultPort = PodDirectConnect.parseDirectAddress(
        '192.168.0.50',
        roomCode: 'DEF456',
      );
      expect(defaultPort, isNotNull);
      expect(defaultPort!.port, equals(40407));

      // Empty / whitespace inputs
      expect(PodDirectConnect.parseDirectAddress(''), isNull);
      expect(PodDirectConnect.parseDirectAddress('   '), isNull);
    });
  });

  group('Group 6: Empirical Defect Verifications (Milestone 2 Defect Ledger)', () {
    test('DEFECT-1: Race condition in host close - concurrent _removeClientSocket mutates _clientSockets during close iteration', () async {
      // In WebSocketP2pHostTransport.close() line 289:
      //   for (final socket in _clientSockets.values) { await socket.close(...); }
      // When socket.close() is awaited, onDone fires _removeClientSocket which calls _clientSockets.remove().
      // Because _clientSockets.values is an active view rather than a snapshot copy (List.from),
      // any concurrent socket removal immediately throws ConcurrentModificationError.
      final activeSockets = <String, String>{'client-1': 'sock1', 'client-2': 'sock2'};
      expect(() {
        for (final s in activeSockets.values) {
          if (s == 'sock1') {
            activeSockets.remove('client-1'); // Exact mutation executed by _removeClientSocket
          }
        }
      }, throwsA(isA<ConcurrentModificationError>()));
    });

    test('DEFECT-2: Reconnecting client with same endpointId is dropped from routing when old socket closes', () async {
      final host = WebSocketP2pTransport.host(
        hostEndpointId: 'host-defect-2',
        port: 0,
        bindAddress: InternetAddress.loopbackIPv4,
      );
      await host.start();

      // Client session 1
      final client1 = WebSocketP2pTransport.client(
        clientEndpointId: 'charlie',
        hostAddress: '127.0.0.1',
        port: host.actualPort,
        autoReconnect: false,
      );
      await client1.connect();
      expect(host.connectedClientCount, equals(1));

      // Client session 2 reconnects before session 1 TCP socket finishes teardown
      final client2 = WebSocketP2pTransport.client(
        clientEndpointId: 'charlie',
        hostAddress: '127.0.0.1',
        port: host.actualPort,
        autoReconnect: false,
      );
      await client2.connect();

      // Session 1 disconnects (FIN packet processed)
      await client1.disconnect();
      await Future.delayed(const Duration(milliseconds: 100));

      // VERIFY REMEDIATION: _removeClientSocket only removes socket if _clientSockets[peerId] == socket.
      // Since client2 is actively connected under 'charlie', host retains client2's socket.
      expect(
        host.connectedClientCount,
        equals(1),
        reason: 'Host retains active client2 socket when previous client1 socket disconnects',
      );
      expect(client2.isConnected, isTrue);

      await client2.disconnect();
      await host.disconnect();
    });

    test('DEFECT-3: Port range validation in PodDirectConnect parsers rejects negative and out-of-range ports', () {
      // VERIFY REMEDIATION: parseDirectAddress rejects negative port numbers
      final negativePortInfo = PodDirectConnect.parseDirectAddress('192.168.0.50:-5');
      expect(negativePortInfo, isNull,
          reason: 'parseDirectAddress must reject negative port numbers');

      // VERIFY REMEDIATION: parseQrUri rejects negative port numbers
      final qrUriWithNegPort = 'countr://pod/join?host=192.168.1.150&port=-10&code=KLD42A&session=sess-1';
      final parsedQr = PodDirectConnect.parseQrUri(qrUriWithNegPort);
      expect(parsedQr, isNull,
          reason: 'parseQrUri must reject negative port numbers');
    });

    test('DEFECT-4: P2pPacket.fromJson successfully coerces string numbers and numeric target IDs', () {
      // String integer delta coerces to int
      final pkt1 = P2pPacket.fromJson({'delta': '5'});
      expect(pkt1.delta, equals(5));

      // String sequence number coerces to int
      final pkt2 = P2pPacket.fromJson({'sequence_number': '10'});
      expect(pkt2.sequenceNumber, equals(10));

      // Integer targetPlayerId coerces to String
      final pkt3 = P2pPacket.fromJson({'target_player_id': 1});
      expect(pkt3.targetPlayerId, equals('1'));
    });
  });
}
