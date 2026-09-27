// Copyright (c) 2026 Countr. All rights reserved.
// Production implementation of P2P transport interfaces in Countr Phase 4.7.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:countr/features/life_counter/domain/models/p2p_packet.dart';

/// Connection states for a peer node in the local P2P mesh.
enum PeerConnectionState {
  /// Node is not connected to the pod mesh.
  disconnected,

  /// Node is broadcasting or listening for UDP discovery beacons.
  discovering,

  /// Node is negotiating initial WebSocket TCP handshake with the host.
  connecting,

  /// Node is fully connected, synchronized, and actively exchanging packets.
  connected,

  /// Connection dropped temporarily; node is attempting automatic recovery.
  reconnecting;

  /// Whether the node is in a functional connected state.
  bool get isActive => this == PeerConnectionState.connected;
}

/// Status record tracking the connection health, identity, and latency of a mesh peer.
@immutable
class PeerStatus {
  /// Unique endpoint identifier of the peer device.
  final String peerId;

  /// Display name of the player associated with this peer node, if registered.
  final String? playerName;

  /// Active connection lifecycle state.
  final PeerConnectionState state;

  /// Round-trip ping latency in milliseconds.
  final int latencyMs;

  /// Timestamp in milliseconds since epoch of the most recent status update.
  final int timestamp;

  /// Informational status message (e.g. error or state description).
  final String? message;

  const PeerStatus({
    required this.peerId,
    this.playerName,
    required this.state,
    this.latencyMs = 0,
    int? timestamp,
    this.message,
  }) : timestamp = timestamp ?? 0;

  PeerStatus copyWith({
    String? peerId,
    String? playerName,
    PeerConnectionState? state,
    int? latencyMs,
    int? timestamp,
    String? message,
  }) {
    return PeerStatus(
      peerId: peerId ?? this.peerId,
      playerName: playerName ?? this.playerName,
      state: state ?? this.state,
      latencyMs: latencyMs ?? this.latencyMs,
      timestamp: timestamp ?? this.timestamp,
      message: message ?? this.message,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'peer_id': peerId,
      'state': state.name,
      'latency_ms': latencyMs,
      'timestamp': timestamp,
    };
    if (playerName != null) {
      map['player_name'] = playerName;
    }
    if (message != null) {
      map['message'] = message;
    }
    return map;
  }

  factory PeerStatus.fromJson(Map<String, dynamic> json) => PeerStatus(
    peerId: (json['peer_id'] ?? json['peerId'] ?? '').toString(),
    playerName: (json['player_name'] ?? json['playerName']) as String?,
    state: PeerConnectionState.values.firstWhere(
      (s) => s.name == (json['state'] as String?),
      orElse: () => PeerConnectionState.disconnected,
    ),
    latencyMs:
        (json['latency_ms'] ?? json['latencyMs'] as num?)?.toInt() ?? 0,
    timestamp: (json['timestamp'] as num?)?.toInt() ?? 0,
    message: (json['message'] ?? json['msg']) as String?,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PeerStatus &&
          runtimeType == other.runtimeType &&
          peerId == other.peerId &&
          playerName == other.playerName &&
          state == other.state &&
          latencyMs == other.latencyMs &&
          timestamp == other.timestamp &&
          message == other.message;

  @override
  int get hashCode =>
      Object.hash(peerId, playerName, state, latencyMs, timestamp, message);

  @override
  String toString() =>
      'PeerStatus(peerId: $peerId, player: $playerName, state: ${state.name}, latency: ${latencyMs}ms, msg: $message)';
}

/// Abstract contract defining bidirectional peer-to-peer transport capabilities.
///
/// Designed with complete dependency inversion to support both real network
/// implementations (`dart:io` WebSockets and UDP beacons) and 100% headless
/// mock implementations (`InMemoryP2pTransport`) for automated testing.
abstract class P2pTransport {
  /// Unique endpoint identifier for this transport node.
  String get endpointId;

  /// Whether this transport node is currently active and connected to the mesh.
  bool get isConnected;

  /// Stream of all incoming validated packets received by this node from the mesh.
  Stream<P2pPacket> get incomingPackets;

  /// Stream of connection state updates for peers in the mesh.
  Stream<PeerStatus> get peerStatusStream;

  /// Transmits a packet into the mesh (to host if client, or to peers if host).
  ///
  /// Throws [StateError] if called while [isConnected] is false.
  Future<void> sendPacket(P2pPacket packet);

  /// Broadcasts a packet to all connected peers in the mesh.
  ///
  /// Throws [StateError] if called while [isConnected] is false.
  Future<void> broadcastPacket(P2pPacket packet);

  /// Disconnects from the mesh, unregisters the endpoint, and stops listeners.
  Future<void> disconnect();

  // ---------------------------------------------------------------------------
  // Ergonomic Aliases & Contract Bridge Methods
  // ---------------------------------------------------------------------------

  /// Targeted transmission to a specific peer endpoint.
  ///
  /// In star topology, defaults to [sendPacket] with routing handled by the mesh.
  Future<void> sendTo(String targetPeerId, P2pPacket packet) =>
      sendPacket(packet);

  /// Alias for [broadcastPacket] supporting survey specification syntax.
  Future<void> broadcast(P2pPacket packet) => broadcastPacket(packet);

  /// Alias for [disconnect] releasing all underlying resources and sockets.
  Future<void> close() => disconnect();
}
