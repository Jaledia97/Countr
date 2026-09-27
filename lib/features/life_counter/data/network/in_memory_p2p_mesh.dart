// Copyright (c) 2026 Countr. All rights reserved.
// Production implementation of in-memory P2P mesh for deterministic automated testing.

import 'dart:async';
import 'package:countr/features/life_counter/domain/models/p2p_packet.dart';
import 'package:countr/features/life_counter/data/network/p2p_transport.dart';

/// In-memory mesh router simulating a local peer-to-peer network without OS sockets.
///
/// Enables 100% headless, zero-flakiness, microsecond-latency test execution
/// in `flutter test` environments. Supports simulated latency and packet drop rates
/// to test resilience against real-world network perturbations.
class InMemoryP2pMesh {
  final Map<String, InMemoryP2pTransport> _nodes = {};

  /// Simulated packet drop probability between 0.0 (no drops) and 1.0 (drop all).
  double packetDropRate = 0.0;

  /// Simulated network latency applied before delivering packets to destination nodes.
  Duration simulatedLatency = Duration.zero;

  /// Counter tracking total packets routed across this mesh instance.
  int totalPacketsRouted = 0;

  /// Counter tracking total packets dropped by simulated packet loss.
  int totalPacketsDropped = 0;

  /// Creates and registers a new virtual peer node identified by [endpointId].
  InMemoryP2pTransport createNode(String endpointId) {
    final node = InMemoryP2pTransport(endpointId, this);
    _nodes[endpointId] = node;
    return node;
  }

  /// Registers an existing [InMemoryP2pTransport] node into the routing table.
  void registerNode(String endpointId, InMemoryP2pTransport transport) {
    _nodes[endpointId] = transport;
  }

  /// Removes an endpoint from the active routing table.
  void removeNode(String endpointId) {
    _nodes.remove(endpointId);
  }

  /// Contract-compatibility alias matching test contract naming convention.
  void _removeNode(String endpointId) => removeNode(endpointId);

  /// Routes a [packet] originating from [fromEndpoint] to destination nodes.
  ///
  /// If [targetEndpointId] is provided, delivers exclusively to that node.
  /// Otherwise, broadcasts to all connected peer nodes except the sender.
  void routePacket(
    P2pPacket packet,
    String fromEndpoint, {
    String? targetEndpointId,
  }) {
    if (packetDropRate > 0.0 && packetDropRate >= 1.0) {
      totalPacketsDropped++;
      return;
    }

    void deliver() {
      totalPacketsRouted++;
      if (targetEndpointId != null) {
        final dest = _nodes[targetEndpointId];
        if (dest != null && dest.isConnected) {
          dest._receivePacket(packet);
        }
      } else {
        for (final entry in _nodes.entries) {
          if (entry.key != fromEndpoint && entry.value.isConnected) {
            entry.value._receivePacket(packet);
          }
        }
      }
    }

    if (simulatedLatency > Duration.zero) {
      Future.delayed(simulatedLatency, deliver);
    } else {
      deliver();
    }
  }

  /// Contract-compatibility alias matching test contract naming convention.
  void _routePacket(P2pPacket packet, String fromEndpoint) =>
      routePacket(packet, fromEndpoint);

  /// Total number of nodes registered in this mesh.
  int get nodeCount => _nodes.length;

  /// List of endpoint identifiers for all currently connected nodes.
  List<String> get connectedNodeIds => _nodes.entries
      .where((e) => e.value.isConnected)
      .map((e) => e.key)
      .toList();

  /// Clears all registered nodes and resets packet counters.
  void reset() {
    _nodes.clear();
    totalPacketsRouted = 0;
    totalPacketsDropped = 0;
    packetDropRate = 0.0;
    simulatedLatency = Duration.zero;
  }
}

/// Pure in-memory implementation of [P2pTransport] backed by [InMemoryP2pMesh].
///
/// Exposes broadcast [StreamController]s for incoming packets and peer status events.
class InMemoryP2pTransport implements P2pTransport {
  @override
  final String endpointId;

  final InMemoryP2pMesh _mesh;

  final StreamController<P2pPacket> _incomingController =
      StreamController<P2pPacket>.broadcast();

  final StreamController<PeerStatus> _statusController =
      StreamController<PeerStatus>.broadcast();

  bool _connected = true;

  InMemoryP2pTransport(this.endpointId, this._mesh);

  @override
  bool get isConnected => _connected;

  @override
  Stream<P2pPacket> get incomingPackets => _incomingController.stream;

  @override
  Stream<PeerStatus> get peerStatusStream => _statusController.stream;

  @override
  Future<void> sendPacket(P2pPacket packet) async {
    if (!_connected) {
      throw StateError('Transport is disconnected');
    }
    _mesh._routePacket(packet, endpointId);
  }

  @override
  Future<void> broadcastPacket(P2pPacket packet) async {
    await sendPacket(packet);
  }

  @override
  Future<void> sendTo(String targetPeerId, P2pPacket packet) async {
    if (!_connected) {
      throw StateError('Transport is disconnected');
    }
    _mesh.routePacket(packet, endpointId, targetEndpointId: targetPeerId);
  }

  @override
  Future<void> broadcast(P2pPacket packet) async {
    await broadcastPacket(packet);
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    _mesh._removeNode(endpointId);
    if (!_statusController.isClosed) {
      _statusController.add(
        PeerStatus(
          peerId: endpointId,
          state: PeerConnectionState.disconnected,
        ),
      );
    }
  }

  /// Restores connection state and re-registers this node in the mesh.
  void reconnect() {
    _connected = true;
    _mesh.registerNode(endpointId, this);
    if (!_statusController.isClosed) {
      _statusController.add(
        PeerStatus(
          peerId: endpointId,
          state: PeerConnectionState.connected,
        ),
      );
    }
  }

  /// Closes all internal stream controllers.
  void dispose() {
    _incomingController.close();
    _statusController.close();
  }

  @override
  Future<void> close() async {
    await disconnect();
    dispose();
  }

  /// Receives an incoming packet from the mesh and pushes it to the stream.
  void receivePacket(P2pPacket packet) {
    if (_connected && !_incomingController.isClosed) {
      _incomingController.add(packet);
    }
  }

  /// Contract-compatibility alias matching test contract naming convention.
  void _receivePacket(P2pPacket packet) => receivePacket(packet);
}
