// Copyright (c) 2026 Countr. All rights reserved.
// Integration tests for real IO WebSockets, UDP beacons, and connection fallback.

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/features/life_counter/domain/models/p2p_packet.dart';
import 'package:countr/features/life_counter/data/network/websocket_p2p_transport.dart';
import 'package:countr/features/life_counter/data/network/udp_beacon_discovery.dart';

void main() {
  group('P2P IO Socket Integration Tests (Loopback 127.0.0.1)', () {
    WebSocketP2pHostTransport? hostTransport;
    WebSocketP2pClientTransport? clientTransport;

    tearDown(() async {
      await hostTransport?.disconnect();
      await clientTransport?.disconnect();
    });

    test('T-IO-1: Host binds loopback port 0 and accepts WebSocket connection',
        () async {
      hostTransport = WebSocketP2pTransport.host(
        hostEndpointId: 'host-1',
        port: 0,
        bindAddress: InternetAddress.loopbackIPv4,
      );
      await hostTransport!.start();

      expect(hostTransport!.isConnected, isTrue);
      expect(hostTransport!.actualPort, greaterThan(0));

      clientTransport = WebSocketP2pTransport.client(
        clientEndpointId: 'client-1',
        hostAddress: '127.0.0.1',
        port: hostTransport!.actualPort,
        autoReconnect: false,
      );
      await clientTransport!.connect();

      expect(clientTransport!.isConnected, isTrue);
      expect(hostTransport!.connectedClientCount, equals(1));
    });

    test(
        'T-IO-2: Bidirectional packet transmission between Host and Client',
        () async {
      hostTransport = WebSocketP2pTransport.host(
        hostEndpointId: 'host-1',
        port: 0,
        bindAddress: InternetAddress.loopbackIPv4,
      );
      await hostTransport!.start();

      clientTransport = WebSocketP2pTransport.client(
        clientEndpointId: 'client-1',
        hostAddress: '127.0.0.1',
        port: hostTransport!.actualPort,
        autoReconnect: false,
      );
      await clientTransport!.connect();

      // Client -> Host
      final hostPacketFuture = hostTransport!.incomingPackets.first;
      await clientTransport!.sendPacket(P2pPacket(
        type: P2pPacketType.lifeDelta,
        senderId: 'client-1',
        sequenceNumber: 1,
        targetPlayerId: 'p2',
        delta: -3,
      ));

      final receivedByHost =
          await hostPacketFuture.timeout(const Duration(seconds: 2));
      expect(receivedByHost.type, equals(P2pPacketType.lifeDelta));
      expect(receivedByHost.senderId, equals('client-1'));
      expect(receivedByHost.delta, equals(-3));

      // Host -> Client
      final clientPacketFuture = clientTransport!.incomingPackets.first;
      await hostTransport!.broadcastPacket(P2pPacket(
        type: P2pPacketType.syncState,
        senderId: 'host-1',
        sequenceNumber: 42,
        payload: {'status': 'active'},
      ));

      final receivedByClient =
          await clientPacketFuture.timeout(const Duration(seconds: 2));
      expect(receivedByClient.type, equals(P2pPacketType.syncState));
      expect(receivedByClient.sequenceNumber, equals(42));
      expect(receivedByClient.payload['status'], equals('active'));
    });

    test('T-IO-3: Star topology broadcasts packet to multiple clients',
        () async {
      hostTransport = WebSocketP2pTransport.host(
        hostEndpointId: 'host-1',
        port: 0,
        bindAddress: InternetAddress.loopbackIPv4,
      );
      await hostTransport!.start();

      final clientA = WebSocketP2pTransport.client(
        clientEndpointId: 'client-a',
        hostAddress: '127.0.0.1',
        port: hostTransport!.actualPort,
        autoReconnect: false,
      );
      final clientB = WebSocketP2pTransport.client(
        clientEndpointId: 'client-b',
        hostAddress: '127.0.0.1',
        port: hostTransport!.actualPort,
        autoReconnect: false,
      );

      await clientA.connect();
      await clientB.connect();
      expect(hostTransport!.connectedClientCount, equals(2));

      final futureA = clientA.incomingPackets.first;
      final futureB = clientB.incomingPackets.first;

      await hostTransport!.broadcastPacket(P2pPacket(
        type: P2pPacketType.resetGame,
        senderId: 'host-1',
        sequenceNumber: 10,
        value: 40,
      ));

      final pktA = await futureA.timeout(const Duration(seconds: 2));
      final pktB = await futureB.timeout(const Duration(seconds: 2));

      expect(pktA.type, equals(P2pPacketType.resetGame));
      expect(pktA.value, equals(40));
      expect(pktB.type, equals(P2pPacketType.resetGame));
      expect(pktB.value, equals(40));

      await clientA.disconnect();
      await clientB.disconnect();
    });

    test(
        'T-IO-4: Client handles unexpected server disconnect and reports status',
        () async {
      hostTransport = WebSocketP2pTransport.host(
        hostEndpointId: 'host-1',
        port: 0,
        bindAddress: InternetAddress.loopbackIPv4,
      );
      await hostTransport!.start();

      final statusEvents = <PeerStatus>[];
      clientTransport = WebSocketP2pTransport.client(
        clientEndpointId: 'client-1',
        hostAddress: '127.0.0.1',
        port: hostTransport!.actualPort,
        autoReconnect: true,
        initialBackoff: const Duration(milliseconds: 100),
      );
      clientTransport!.peerStatusStream.listen(statusEvents.add);

      await clientTransport!.connect();
      expect(clientTransport!.isConnected, isTrue);

      await hostTransport!.disconnect();

      await Future.delayed(const Duration(milliseconds: 300));
      expect(clientTransport!.isConnected, isFalse);
      expect(
          statusEvents
              .any((s) => s.state == PeerConnectionState.reconnecting),
          isTrue);
    });

    test('T-IO-5: UDP Beacon Discovery and Probe response on loopback',
        () async {
      final beaconData = PodBeaconData(
        sessionId: 'session-loopback-001',
        roomCode: 'KLD42A',
        hostName: 'Alice',
        hostAddress: '127.0.0.1',
        port: 40407,
        format: 'Commander',
        startingLife: 40,
        maxPlayers: 4,
        connectedPlayers: 1,
        playerNames: ['Alice'],
      );

      final udpHost = UdpBeaconDiscovery.createHost(
        initialBeaconData: beaconData,
        port: 0,
        broadcastAddress: InternetAddress.loopbackIPv4,
        bindAddress: InternetAddress.loopbackIPv4,
      );
      await udpHost.start();

      final udpClient = UdpBeaconDiscovery.createClient(
        clientName: 'Bob',
        clientId: 'bob-uuid',
        port: 0,
        broadcastAddress: InternetAddress.loopbackIPv4,
        bindAddress: InternetAddress.loopbackIPv4,
      );
      await udpClient.startDiscovery();

      udpClient.sendProbe();

      final podsFuture = udpClient.discoveredPodsStream
          .firstWhere((pods) => pods.isNotEmpty);
      final discoveredPods =
          await podsFuture.timeout(const Duration(seconds: 3));

      expect(discoveredPods, isNotEmpty);
      final pod = discoveredPods.first;
      expect(pod.sessionId, equals('session-loopback-001'));
      expect(pod.roomCode, equals('KLD42A'));
      expect(pod.hostName, equals('Alice'));
      expect(pod.format, equals('Commander'));
      expect(pod.startingLife, equals(40));

      await udpHost.stop();
      await udpClient.stopDiscovery();
    });

    test('T-IO-6: RoomCodeGenerator generates valid 6-char unambiguous codes',
        () {
      for (int i = 0; i < 100; i++) {
        final code = RoomCodeGenerator.generate();
        expect(code.length, equals(6));
        expect(RoomCodeGenerator.isValid(code), isTrue);
        expect(code, isNot(contains('0')));
        expect(code, isNot(contains('O')));
        expect(code, isNot(contains('1')));
        expect(code, isNot(contains('I')));
        expect(code, isNot(contains('L')));
      }

      expect(RoomCodeGenerator.normalize(' kld-42a '), equals('KLD42A'));
      expect(RoomCodeGenerator.isValid('kld-42a'), isTrue);
      expect(RoomCodeGenerator.isValid('TOO_LONG_CODE'), isFalse);
      expect(RoomCodeGenerator.isValid('SHORT'), isFalse);
      expect(RoomCodeGenerator.isValid('ABC12O'), isFalse);
    });

    test('T-IO-7: PodDirectConnect generates and parses QR URI', () {
      final qrUri = PodDirectConnect.generateQrUri(
        host: '192.168.1.150',
        port: 40407,
        roomCode: 'KLD42A',
        sessionId: 'sess-abc-123',
      );

      expect(
        qrUri,
        equals(
            'countr://pod/join?host=192.168.1.150&port=40407&code=KLD42A&session=sess-abc-123'),
      );

      final parsed = PodDirectConnect.parseQrUri(qrUri);
      expect(parsed, isNotNull);
      expect(parsed!.host, equals('192.168.1.150'));
      expect(parsed.port, equals(40407));
      expect(parsed.roomCode, equals('KLD42A'));
      expect(parsed.sessionId, equals('sess-abc-123'));
      expect(parsed.websocketUrl, equals('ws://192.168.1.150:40407/pod'));

      final manual = PodDirectConnect.parseDirectAddress(
        '10.0.0.5:40407',
        roomCode: 'RAV79X',
        sessionId: 'sess-direct',
      );
      expect(manual, isNotNull);
      expect(manual!.host, equals('10.0.0.5'));
      expect(manual.port, equals(40407));
      expect(manual.roomCode, equals('RAV79X'));

      expect(PodDirectConnect.parseQrUri('https://notcountr.com'), isNull);
      expect(PodDirectConnect.parseQrUri('countr://wrong/path'), isNull);
    });

    test(
        'T-IO-8: Concurrent close with multiple connected clients does not throw ConcurrentModificationError',
        () async {
      for (int i = 0; i < 10; i++) {
        final host = WebSocketP2pTransport.host(
          hostEndpointId: 'host-stress-$i',
          port: 0,
          bindAddress: InternetAddress.loopbackIPv4,
        );
        await host.start();
        final port = host.actualPort;

        final clients = <WebSocketP2pClientTransport>[];
        for (int c = 0; c < 4; c++) {
          final client = WebSocketP2pTransport.client(
            clientEndpointId: 'client-$i-$c',
            hostAddress: '127.0.0.1',
            port: port,
            autoReconnect: false,
          );
          await client.connect();
          clients.add(client);
        }

        expect(host.connectedClientCount, equals(4));

        // Concurrently close clients and host to provoke race conditions
        final futures = <Future<void>>[
          host.close(),
          ...clients.map((c) => c.close()),
        ];
        await Future.wait(futures);

        expect(host.isConnected, isFalse);
        expect(host.connectedClientCount, equals(0));

        // Verify port was cleanly released and can be immediately re-bound
        final testServer = await HttpServer.bind(
          InternetAddress.loopbackIPv4,
          port,
        );
        await testServer.close(force: true);
      }
    });

    test(
        'T-IO-9: Concurrent broadcast and client disconnect does not throw ConcurrentModificationError',
        () async {
      for (int i = 0; i < 5; i++) {
        final host = WebSocketP2pTransport.host(
          hostEndpointId: 'host-bcast-$i',
          port: 0,
          bindAddress: InternetAddress.loopbackIPv4,
        );
        await host.start();
        final port = host.actualPort;

        final clients = <WebSocketP2pClientTransport>[];
        for (int c = 0; c < 4; c++) {
          final client = WebSocketP2pTransport.client(
            clientEndpointId: 'client-bcast-$i-$c',
            hostAddress: '127.0.0.1',
            port: port,
            autoReconnect: false,
          );
          await client.connect();
          clients.add(client);
        }

        // Fire 20 broadcasts while disconnecting clients in parallel
        final bcastFutures = List.generate(
          20,
          (seq) => host.broadcastPacket(P2pPacket(
            type: P2pPacketType.lifeDelta,
            senderId: 'host-bcast-$i',
            sequenceNumber: seq,
            delta: seq,
          )),
        );
        final disconnectFutures = clients.map((c) => c.disconnect());

        await Future.wait([...bcastFutures, ...disconnectFutures]);
        await host.disconnect();
      }
    });

    test(
        'T-IO-10: Host close guarantees server subscription cancellation and socket release',
        () async {
      final host = WebSocketP2pTransport.host(
        hostEndpointId: 'host-leak-test',
        port: 0,
        bindAddress: InternetAddress.loopbackIPv4,
      );
      await host.start();
      final port = host.actualPort;

      final client = WebSocketP2pTransport.client(
        clientEndpointId: 'client-leak-test',
        hostAddress: '127.0.0.1',
        port: port,
        autoReconnect: false,
      );
      await client.connect();

      await host.close();

      // Verify server is nullified, client sockets cleared, and port released
      expect(host.isConnected, isFalse);
      expect(host.connectedClientCount, equals(0));

      final rebind = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
      expect(rebind.port, equals(port));
      await rebind.close(force: true);
      await client.disconnect();
    });

    test(
        'T-IO-11: Client reconnect with same endpointId replaces old socket without ghost disconnect or black-hole routing',
        () async {
      final host = WebSocketP2pTransport.host(
        hostEndpointId: 'host-1',
        port: 0,
        bindAddress: InternetAddress.loopbackIPv4,
      );
      await host.start();

      final hostStatuses = <PeerStatus>[];
      host.peerStatusStream.listen(hostStatuses.add);

      // 1. Initial client connection
      final client1 = WebSocketP2pTransport.client(
        clientEndpointId: 'player-bob',
        hostAddress: '127.0.0.1',
        port: host.actualPort,
        autoReconnect: false,
      );
      await client1.connect();
      expect(client1.isConnected, isTrue);
      expect(host.connectedClientCount, equals(1));
      expect(host.connectedPeerIds, contains('player-bob'));

      // 2. Client reconnects with same endpointId before socket 1 teardown finishes
      final client2 = WebSocketP2pTransport.client(
        clientEndpointId: 'player-bob',
        hostAddress: '127.0.0.1',
        port: host.actualPort,
        autoReconnect: false,
      );
      await client2.connect();
      expect(client2.isConnected, isTrue);

      // 3. Old socket disconnects (e.g. TCP FIN arrives)
      await client1.disconnect();
      await Future.delayed(const Duration(milliseconds: 100));

      // 4. VERIFY: Host still retains player-bob via client2's socket
      expect(host.connectedClientCount, equals(1));
      expect(host.connectedPeerIds, contains('player-bob'));

      // 5. VERIFY: Broadcast packet reaches client2 (no black-hole routing)
      final client2PacketFuture = client2.incomingPackets.first;
      await host.broadcastPacket(P2pPacket(
        type: P2pPacketType.lifeDelta,
        senderId: 'host-1',
        sequenceNumber: 100,
        targetPlayerId: 'player-bob',
        delta: -2,
      ));
      final receivedBroadcast =
          await client2PacketFuture.timeout(const Duration(seconds: 2));
      expect(receivedBroadcast.type, equals(P2pPacketType.lifeDelta));
      expect(receivedBroadcast.sequenceNumber, equals(100));
      expect(receivedBroadcast.delta, equals(-2));

      // 6. VERIFY: Unicast sendTo reaches client2
      final client2UnicastFuture = client2.incomingPackets.first;
      await host.sendTo(
        'player-bob',
        P2pPacket(
          type: P2pPacketType.counterDelta,
          senderId: 'host-1',
          sequenceNumber: 101,
          targetPlayerId: 'player-bob',
          delta: 1,
        ),
      );
      final receivedUnicast =
          await client2UnicastFuture.timeout(const Duration(seconds: 2));
      expect(receivedUnicast.type, equals(P2pPacketType.counterDelta));
      expect(receivedUnicast.sequenceNumber, equals(101));

      // 7. VERIFY: Client2 can send packet to host
      final hostPacketFuture = host.incomingPackets.first;
      await client2.sendPacket(P2pPacket(
        type: P2pPacketType.manaDelta,
        senderId: 'player-bob',
        sequenceNumber: 102,
        delta: 3,
      ));
      final receivedFromClient2 =
          await hostPacketFuture.timeout(const Duration(seconds: 2));
      expect(receivedFromClient2.senderId, equals('player-bob'));
      expect(receivedFromClient2.delta, equals(3));

      // 8. VERIFY: Peer status was NOT spuriously set to disconnected when client1 closed
      final bobDisconnectCountWhileClient2Active = hostStatuses
          .where((s) =>
              s.peerId == 'player-bob' &&
              s.state == PeerConnectionState.disconnected)
          .length;
      expect(bobDisconnectCountWhileClient2Active, equals(0));

      // 9. When client2 disconnects, host now properly cleans up
      await client2.disconnect();
      await Future.delayed(const Duration(milliseconds: 100));
      expect(host.connectedClientCount, equals(0));
      expect(host.connectedPeerIds, isEmpty);

      final bobDisconnectCountAfterClient2Close = hostStatuses
          .where((s) =>
              s.peerId == 'player-bob' &&
              s.state == PeerConnectionState.disconnected)
          .length;
      expect(bobDisconnectCountAfterClient2Close, equals(1));

      await host.disconnect();
    });

    test(
        'T-IO-12: PodDirectConnect port validation enforces 1..65535 range on parseQrUri and parseDirectAddress',
        () {
      // --- parseDirectAddress tests ---
      final minPort = PodDirectConnect.parseDirectAddress('192.168.1.1:1');
      expect(minPort, isNotNull);
      expect(minPort!.port, equals(1));

      final maxPort = PodDirectConnect.parseDirectAddress('192.168.1.1:65535');
      expect(maxPort, isNotNull);
      expect(maxPort!.port, equals(65535));

      final defaultPort = PodDirectConnect.parseDirectAddress('192.168.1.1');
      expect(defaultPort, isNotNull);
      expect(defaultPort!.port, equals(40407));

      expect(PodDirectConnect.parseDirectAddress('192.168.1.1:0'), isNull);
      expect(PodDirectConnect.parseDirectAddress('192.168.1.1:-1'), isNull);
      expect(PodDirectConnect.parseDirectAddress('192.168.1.1:-5'), isNull);
      expect(PodDirectConnect.parseDirectAddress('192.168.1.1:65536'), isNull);
      expect(PodDirectConnect.parseDirectAddress('192.168.1.1:999999'), isNull);
      expect(
          PodDirectConnect.parseDirectAddress('192.168.1.1:not_a_number'), isNull);
      expect(PodDirectConnect.parseDirectAddress('192.168.1.1:'), isNull);
      expect(
          PodDirectConnect.parseDirectAddress('192.168.1.1:40407:extra'), isNull);

      // --- parseQrUri tests ---
      String buildQrUri(String portParam) =>
          'countr://pod/join?host=192.168.1.150&port=$portParam&code=KLD42A&session=sess-abc';

      final qrMin = PodDirectConnect.parseQrUri(buildQrUri('1'));
      expect(qrMin, isNotNull);
      expect(qrMin!.port, equals(1));

      final qrMax = PodDirectConnect.parseQrUri(buildQrUri('65535'));
      expect(qrMax, isNotNull);
      expect(qrMax!.port, equals(65535));

      final qrDefault = PodDirectConnect.parseQrUri(
          'countr://pod/join?host=192.168.1.150&code=KLD42A&session=sess-abc');
      expect(qrDefault, isNotNull);
      expect(qrDefault!.port, equals(40407));

      expect(PodDirectConnect.parseQrUri(buildQrUri('0')), isNull);
      expect(PodDirectConnect.parseQrUri(buildQrUri('-1')), isNull);
      expect(PodDirectConnect.parseQrUri(buildQrUri('-10')), isNull);
      expect(PodDirectConnect.parseQrUri(buildQrUri('65536')), isNull);
      expect(PodDirectConnect.parseQrUri(buildQrUri('999999')), isNull);
      expect(PodDirectConnect.parseQrUri(buildQrUri('xyz')), isNull);
      expect(PodDirectConnect.parseQrUri(buildQrUri('')), isNull);
    });
  });
}
