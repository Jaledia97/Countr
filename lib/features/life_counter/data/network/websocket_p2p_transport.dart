// Copyright (c) 2026 Countr. All rights reserved.
// Production implementation of WebSocket P2P transport in Countr Phase 4.7.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:countr/features/life_counter/domain/models/p2p_packet.dart';
import 'package:countr/features/life_counter/data/network/p2p_transport.dart';

export 'package:countr/features/life_counter/data/network/p2p_transport.dart';
export 'package:countr/features/life_counter/data/network/pod_connection_fallback.dart';

/// Abstract base interface for WebSocket-based P2P transports.
abstract class WebSocketP2pTransport implements P2pTransport {
  static const int defaultPort = 40407;
  static const String podPath = '/pod';

  /// Creates a Host transport running an embedded HttpServer.
  static WebSocketP2pHostTransport host({
    required String hostEndpointId,
    int port = defaultPort,
    InternetAddress? bindAddress,
  }) {
    return WebSocketP2pHostTransport(
      hostEndpointId: hostEndpointId,
      requestedPort: port,
      bindAddress: bindAddress,
    );
  }

  /// Creates a Client transport connecting to an external Host.
  static WebSocketP2pClientTransport client({
    required String clientEndpointId,
    required String hostAddress,
    int port = defaultPort,
    bool autoReconnect = true,
    Duration initialBackoff = const Duration(milliseconds: 500),
    Duration maxBackoff = const Duration(seconds: 10),
    int maxReconnectAttempts = 10,
    Duration connectTimeout = const Duration(seconds: 5),
  }) {
    return WebSocketP2pClientTransport(
      clientEndpointId: clientEndpointId,
      hostAddress: hostAddress,
      port: port,
      autoReconnect: autoReconnect,
      initialBackoff: initialBackoff,
      maxBackoff: maxBackoff,
      maxReconnectAttempts: maxReconnectAttempts,
      connectTimeout: connectTimeout,
    );
  }
}

/// Host-mode WebSocket transport embedding an RFC 6455 WebSocket server on port 40407.
class WebSocketP2pHostTransport implements WebSocketP2pTransport {
  final String hostEndpointId;
  final int requestedPort;
  final InternetAddress? bindAddress;

  HttpServer? _server;
  StreamSubscription<HttpRequest>? _serverSubscription;
  final Map<String, WebSocket> _clientSockets = {};
  final Map<WebSocket, String> _socketToPeerId = {};

  final StreamController<P2pPacket> _incomingController =
      StreamController<P2pPacket>.broadcast();
  final StreamController<PeerStatus> _peerStatusController =
      StreamController<PeerStatus>.broadcast();

  bool _isConnected = false;

  WebSocketP2pHostTransport({
    required this.hostEndpointId,
    this.requestedPort = WebSocketP2pTransport.defaultPort,
    this.bindAddress,
  });

  @override
  String get endpointId => hostEndpointId;

  @override
  bool get isConnected => _isConnected;

  @override
  Stream<P2pPacket> get incomingPackets => _incomingController.stream;

  @override
  Stream<PeerStatus> get peerStatusStream => _peerStatusController.stream;

  /// The actual TCP port bound by the underlying HttpServer.
  int get actualPort => _server?.port ?? requestedPort;

  /// The actual IP address bound by the server.
  InternetAddress? get actualAddress => _server?.address;

  /// Count of active client WebSocket connections.
  int get connectedClientCount => _clientSockets.length;

  /// List of peer IDs currently connected to this host.
  List<String> get connectedPeerIds => List.unmodifiable(_clientSockets.keys);

  /// Start the embedded HTTP/WebSocket server.
  Future<void> start() async {
    if (_isConnected) return;

    final targetAddress = bindAddress ?? InternetAddress.anyIPv4;
    _server = await HttpServer.bind(
      targetAddress,
      requestedPort,
      shared: true,
    );

    _isConnected = true;
    _peerStatusController.add(PeerStatus(
      peerId: hostEndpointId,
      state: PeerConnectionState.connected,
      message: 'Host server started on port $actualPort',
    ));

    _serverSubscription = _server!.listen(
      _handleHttpRequest,
      onError: (error) {
        _peerStatusController.add(PeerStatus(
          peerId: hostEndpointId,
          state: PeerConnectionState.disconnected,
          message: 'Server error: $error',
        ));
      },
    );
  }

  void _handleHttpRequest(HttpRequest request) async {
    final path = request.uri.path;
    if (path == WebSocketP2pTransport.podPath || path == '/') {
      if (WebSocketTransformer.isUpgradeRequest(request)) {
        try {
          final socket = await WebSocketTransformer.upgrade(
            request,
            compression: CompressionOptions.compressionDefault,
          );
          _registerClientSocket(socket, request);
        } catch (_) {
          request.response.statusCode = HttpStatus.internalServerError;
          await request.response.close();
        }
      } else {
        // HTTP GET health-check / status
        request.response.statusCode = HttpStatus.ok;
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({
          'status': 'active',
          'server': 'Countr Pod WebSocket Host',
          'hostEndpointId': hostEndpointId,
          'connectedClients': _clientSockets.length,
          'port': actualPort,
        }));
        await request.response.close();
      }
    } else {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
    }
  }

  void _registerClientSocket(WebSocket socket, HttpRequest request) {
    final peerId = request.uri.queryParameters['endpointId'] ??
        'peer-${DateTime.now().millisecondsSinceEpoch}-${_clientSockets.length + 1}';

    _clientSockets[peerId] = socket;
    _socketToPeerId[socket] = peerId;

    _peerStatusController.add(PeerStatus(
      peerId: peerId,
      state: PeerConnectionState.connected,
      message: 'Client connected: $peerId',
    ));

    socket.listen(
      (data) {
        _handleIncomingData(data, socket);
      },
      onError: (error) {
        _removeClientSocket(socket, reason: 'Socket error: $error');
      },
      onDone: () {
        _removeClientSocket(socket, reason: 'Client closed connection');
      },
      cancelOnError: false,
    );
  }

  void _handleIncomingData(dynamic data, WebSocket socket) {
    try {
      final String raw;
      if (data is String) {
        raw = data;
      } else if (data is List<int>) {
        raw = utf8.decode(data);
      } else {
        return;
      }

      final packet = P2pPacket.decode(raw);

      // Re-key peer mapping if client announces concrete senderId
      final currentPeerId = _socketToPeerId[socket];
      if (currentPeerId != null &&
          currentPeerId != packet.senderId &&
          packet.senderId.isNotEmpty) {
        if (_clientSockets[currentPeerId] == socket) {
          _clientSockets.remove(currentPeerId);
        }
        _clientSockets[packet.senderId] = socket;
        _socketToPeerId[socket] = packet.senderId;
      }

      _incomingController.add(packet);
    } catch (_) {
      // Gracefully discard malformed frames
    }
  }

  void _removeClientSocket(WebSocket socket, {String? reason}) {
    final peerId = _socketToPeerId.remove(socket);
    if (peerId != null) {
      if (_clientSockets[peerId] == socket) {
        _clientSockets.remove(peerId);
        _peerStatusController.add(PeerStatus(
          peerId: peerId,
          state: PeerConnectionState.disconnected,
          message: reason ?? 'Disconnected',
        ));
      }
    }
    try {
      socket.close(WebSocketStatus.normalClosure);
    } catch (_) {}
  }

  @override
  Future<void> broadcastPacket(P2pPacket packet) async {
    final payload = packet.encode();
    final deadSockets = <WebSocket>[];
    final sockets = List<WebSocket>.from(_clientSockets.values);

    for (final socket in sockets) {
      try {
        socket.add(payload);
      } catch (_) {
        deadSockets.add(socket);
      }
    }

    for (final dead in deadSockets) {
      _removeClientSocket(dead, reason: 'Socket write failure');
    }
  }

  @override
  Future<void> broadcast(P2pPacket packet) => broadcastPacket(packet);

  @override
  Future<void> sendPacket(P2pPacket packet) async {
    final targetId = packet.targetPlayerId;
    if (targetId != null && _clientSockets.containsKey(targetId)) {
      await sendTo(targetId, packet);
    } else {
      await broadcastPacket(packet);
    }
  }

  @override
  Future<void> sendTo(String targetPeerId, P2pPacket packet) async {
    final socket = _clientSockets[targetPeerId];
    if (socket != null) {
      try {
        socket.add(packet.encode());
      } catch (_) {
        _removeClientSocket(socket, reason: 'Unicast write failure');
      }
    }
  }

  @override
  Future<void> disconnect() async {
    await close();
  }

  @override
  Future<void> close() async {
    _isConnected = false;

    try {
      final sockets = List<WebSocket>.from(_clientSockets.values);
      for (final socket in sockets) {
        try {
          await socket.close(
              WebSocketStatus.normalClosure, 'Host disconnecting');
        } catch (_) {}
      }
    } finally {
      _clientSockets.clear();
      _socketToPeerId.clear();

      try {
        await _serverSubscription?.cancel();
      } catch (_) {}
      _serverSubscription = null;

      try {
        await _server?.close(force: true);
      } catch (_) {}
      _server = null;

      if (!_peerStatusController.isClosed) {
        _peerStatusController.add(PeerStatus(
          peerId: hostEndpointId,
          state: PeerConnectionState.disconnected,
          message: 'Host server stopped',
        ));
      }
    }
  }

  void dispose() {
    close();
    _incomingController.close();
    _peerStatusController.close();
  }
}

/// Client-mode WebSocket transport connecting to an external Host server.
class WebSocketP2pClientTransport implements WebSocketP2pTransport {
  final String clientEndpointId;
  final String hostAddress;
  final int port;
  final bool autoReconnect;
  final Duration initialBackoff;
  final Duration maxBackoff;
  final int maxReconnectAttempts;
  final Duration connectTimeout;

  WebSocket? _socket;
  StreamSubscription? _socketSubscription;
  Timer? _reconnectTimer;
  Duration _currentBackoff;
  int _reconnectAttempts = 0;
  bool _isConnected = false;
  bool _isExplicitDisconnect = false;

  final StreamController<P2pPacket> _incomingController =
      StreamController<P2pPacket>.broadcast();
  final StreamController<PeerStatus> _peerStatusController =
      StreamController<PeerStatus>.broadcast();

  WebSocketP2pClientTransport({
    required this.clientEndpointId,
    required this.hostAddress,
    this.port = WebSocketP2pTransport.defaultPort,
    this.autoReconnect = true,
    this.initialBackoff = const Duration(milliseconds: 500),
    this.maxBackoff = const Duration(seconds: 10),
    this.maxReconnectAttempts = 10,
    this.connectTimeout = const Duration(seconds: 5),
  }) : _currentBackoff = initialBackoff;

  @override
  String get endpointId => clientEndpointId;

  @override
  bool get isConnected => _isConnected;

  @override
  Stream<P2pPacket> get incomingPackets => _incomingController.stream;

  @override
  Stream<PeerStatus> get peerStatusStream => _peerStatusController.stream;

  /// Initiate connection to the remote Host WebSocket server.
  Future<void> connect() async {
    if (_isExplicitDisconnect) return;

    _peerStatusController.add(PeerStatus(
      peerId: clientEndpointId,
      state: _reconnectAttempts > 0
          ? PeerConnectionState.reconnecting
          : PeerConnectionState.connecting,
      message: 'Connecting to ws://$hostAddress:$port/pod',
    ));

    try {
      final uri = Uri(
        scheme: 'ws',
        host: hostAddress,
        port: port,
        path: WebSocketP2pTransport.podPath,
        queryParameters: {'endpointId': clientEndpointId},
      );

      final socket = await WebSocket.connect(uri.toString())
          .timeout(connectTimeout);

      _socket = socket;
      _isConnected = true;
      _reconnectAttempts = 0;
      _currentBackoff = initialBackoff;

      _peerStatusController.add(PeerStatus(
        peerId: clientEndpointId,
        state: PeerConnectionState.connected,
        message: 'Connected to host at $hostAddress:$port',
      ));

      _socketSubscription = socket.listen(
        (data) {
          try {
            final raw = data is String ? data : utf8.decode(data as List<int>);
            final packet = P2pPacket.decode(raw);
            _incomingController.add(packet);
          } catch (_) {}
        },
        onError: (err) {
          _handleDisconnect(reason: 'Socket error: $err');
        },
        onDone: () {
          _handleDisconnect(reason: 'Server closed connection');
        },
        cancelOnError: false,
      );
    } catch (e) {
      _handleDisconnect(reason: 'Connection failed: $e');
    }
  }

  void _handleDisconnect({String? reason}) {
    _isConnected = false;
    _socket = null;
    _socketSubscription?.cancel();
    _socketSubscription = null;

    if (_isExplicitDisconnect) {
      _peerStatusController.add(PeerStatus(
        peerId: clientEndpointId,
        state: PeerConnectionState.disconnected,
        message: reason ?? 'Explicitly disconnected',
      ));
      return;
    }

    if (!autoReconnect || _reconnectAttempts >= maxReconnectAttempts) {
      _peerStatusController.add(PeerStatus(
        peerId: clientEndpointId,
        state: PeerConnectionState.disconnected,
        message:
            'Max reconnect attempts ($maxReconnectAttempts) reached. $reason',
      ));
      return;
    }

    _reconnectAttempts++;
    final backoffDuration = _currentBackoff;

    _peerStatusController.add(PeerStatus(
      peerId: clientEndpointId,
      state: PeerConnectionState.reconnecting,
      latencyMs: backoffDuration.inMilliseconds,
      message:
          'Reconnecting attempt $_reconnectAttempts in ${backoffDuration.inMilliseconds}ms',
    ));

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(backoffDuration, () {
      _currentBackoff = Duration(
        milliseconds: (_currentBackoff.inMilliseconds * 1.5).toInt().clamp(
              initialBackoff.inMilliseconds,
              maxBackoff.inMilliseconds,
            ),
      );
      connect();
    });
  }

  @override
  Future<void> sendPacket(P2pPacket packet) async {
    if (!_isConnected || _socket == null) {
      throw StateError('Cannot send packet: Client is not connected');
    }
    _socket!.add(packet.encode());
  }

  @override
  Future<void> broadcastPacket(P2pPacket packet) async {
    await sendPacket(packet);
  }

  @override
  Future<void> broadcast(P2pPacket packet) => broadcastPacket(packet);

  @override
  Future<void> sendTo(String targetPeerId, P2pPacket packet) async {
    await sendPacket(packet);
  }

  @override
  Future<void> disconnect() async {
    await close();
  }

  @override
  Future<void> close() async {
    _isExplicitDisconnect = true;
    _isConnected = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    await _socketSubscription?.cancel();
    _socketSubscription = null;

    try {
      await _socket?.close(
          WebSocketStatus.normalClosure, 'Client disconnecting');
    } catch (_) {}
    _socket = null;

    _peerStatusController.add(PeerStatus(
      peerId: clientEndpointId,
      state: PeerConnectionState.disconnected,
      message: 'Disconnected by user',
    ));
  }

  void dispose() {
    close();
    _incomingController.close();
    _peerStatusController.close();
  }
}
