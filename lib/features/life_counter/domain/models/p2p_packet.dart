// Copyright (c) 2026 Countr. All rights reserved.
// Production implementation for P2P network packet protocol in Countr Phase 4.7.

import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Enumeration of all P2P network packet types exchanged across the local mesh.
///
/// Implements bidirectional mapping with standard wire protocol string identifiers.
enum P2pPacketType {
  /// Initial client connection request containing player and deck metadata.
  handshakeRequest('handshake_request'),

  /// Host response confirming or rejecting seat assignment.
  handshakeResponse('handshake_response'),

  /// Full authoritative pod snapshot broadcast by the host during join or recovery.
  syncState('sync_state'),

  /// Atomic commutative life delta (+/- integer adjustment).
  lifeDelta('life_delta'),

  /// Commander combat damage ledger adjustment attributed to specific opponent commander.
  commanderDamage('commander_damage'),

  /// Secondary counter modification (poison, energy, experience, commander tax).
  counterDelta('counter_delta'),

  /// Floating mana pool modification for a specific WUBRGC color pip.
  manaDelta('mana_delta'),

  /// Instantaneous zeroing of floating mana pool and storm count for a player.
  manaClear('mana_clear'),

  /// Pod-wide toggle between Day and Night cycles.
  dayNightToggle('day_night_toggle'),

  /// Exclusive pod-wide token claim (Monarch or Initiative).
  claimToken('claim_token'),

  /// Global pod reset resetting life totals and counters while preserving seating.
  resetGame('reset_game'),

  /// Liveness probe and latency tracking ping/pong packet.
  heartbeat('heartbeat'),

  /// Reconnected client request for missed event log starting from last known sequence.
  catchupRequest('catchup_request'),

  /// Host reply containing missed event ledger entries.
  catchupResponse('catchup_response');

  /// Wire protocol string identifier used in serialized JSON payloads.
  final String wireName;

  const P2pPacketType(this.wireName);

  /// Resolves a [P2pPacketType] from a wire protocol string identifier.
  ///
  /// Supports case-insensitive matching and hyphen/underscore normalization.
  /// Falls back safely to [P2pPacketType.heartbeat] for unrecognized names.
  static P2pPacketType fromWireName(String name) {
    final normalized = name.trim().toLowerCase().replaceAll('-', '_');
    return P2pPacketType.values.firstWhere(
      (t) => t.wireName == normalized || t.name.toLowerCase() == normalized,
      orElse: () => P2pPacketType.heartbeat,
    );
  }

  /// Whether this packet represents a commutative tabletop state mutation.
  bool get isStateMutation =>
      this == P2pPacketType.lifeDelta ||
      this == P2pPacketType.commanderDamage ||
      this == P2pPacketType.counterDelta ||
      this == P2pPacketType.manaDelta ||
      this == P2pPacketType.manaClear ||
      this == P2pPacketType.dayNightToggle ||
      this == P2pPacketType.claimToken ||
      this == P2pPacketType.resetGame;

  /// Whether this packet is part of network lifecycle and handshaking.
  bool get isLobbyControl =>
      this == P2pPacketType.handshakeRequest ||
      this == P2pPacketType.handshakeResponse ||
      this == P2pPacketType.syncState ||
      this == P2pPacketType.heartbeat ||
      this == P2pPacketType.catchupRequest ||
      this == P2pPacketType.catchupResponse;
}

/// Immutable typed network envelope for local offline P2P mesh synchronization.
///
/// Encapsulates event metadata, host sequence numbers, target player references,
/// atomic integer deltas, and arbitrary JSON payloads.
@immutable
class P2pPacket {
  /// Packet categorization indicating intent and payload schema.
  final P2pPacketType type;

  /// Unique identifier of the transmitting node (peer/device endpoint).
  final String senderId;

  /// Monotonically increasing sequence number assigned by the host node.
  final int sequenceNumber;

  /// Target player identifier in the pod state (e.g., 'p1', 'p2'), if applicable.
  final String? targetPlayerId;

  /// Primary atomic numerical change (+/- life, +/- counters, +/- mana).
  final int delta;

  /// Resulting absolute value or secondary numerical parameter.
  final int value;

  /// Structured metadata dictionary specific to the packet type.
  final Map<String, dynamic> payload;

  /// Milliseconds since Unix epoch when packet was constructed.
  final int timestamp;

  /// Standard constructor matching the test contract specification exactly.
  P2pPacket({
    required this.type,
    required this.senderId,
    required this.sequenceNumber,
    this.targetPlayerId,
    this.delta = 0,
    this.value = 0,
    this.payload = const {},
    int? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;

  // ---------------------------------------------------------------------------
  // Typed Factory Constructors for Ergonomic Packet Creation
  // ---------------------------------------------------------------------------

  /// Creates a [P2pPacketType.handshakeRequest] packet.
  factory P2pPacket.handshakeRequest({
    required String senderId,
    required String playerName,
    String? deckId,
    String? deckName,
    String? commanderName,
    String? commanderCardId,
    String? commanderArtCropUrl,
    String? preferredColorHex,
    String? clientAppVersion,
  }) {
    final payload = <String, dynamic>{'playerName': playerName};
    if (deckId != null) payload['deckId'] = deckId;
    if (deckName != null) payload['deckName'] = deckName;
    if (commanderName != null) payload['commanderName'] = commanderName;
    if (commanderCardId != null) payload['commanderCardId'] = commanderCardId;
    if (commanderArtCropUrl != null) {
      payload['commanderArtCropUrl'] = commanderArtCropUrl;
    }
    if (preferredColorHex != null) {
      payload['preferredColorHex'] = preferredColorHex;
    }
    if (clientAppVersion != null) {
      payload['clientAppVersion'] = clientAppVersion;
    }
    return P2pPacket(
      type: P2pPacketType.handshakeRequest,
      senderId: senderId,
      sequenceNumber: 0,
      payload: payload,
    );
  }

  /// Creates a [P2pPacketType.handshakeResponse] packet.
  factory P2pPacket.handshakeResponse({
    required String senderId,
    required String status,
    String? assignedPlayerId,
    String? hostPlayerId,
    String? roomCode,
    int? seatIndex,
    String? rejectionReason,
  }) {
    final payload = <String, dynamic>{'status': status};
    if (assignedPlayerId != null) {
      payload['assignedPlayerId'] = assignedPlayerId;
    }
    if (hostPlayerId != null) payload['hostPlayerId'] = hostPlayerId;
    if (roomCode != null) payload['roomCode'] = roomCode;
    if (seatIndex != null) payload['seatIndex'] = seatIndex;
    if (rejectionReason != null) {
      payload['rejectionReason'] = rejectionReason;
    }
    return P2pPacket(
      type: P2pPacketType.handshakeResponse,
      senderId: senderId,
      sequenceNumber: 0,
      payload: payload,
    );
  }

  /// Creates a [P2pPacketType.syncState] packet encapsulating a full pod snapshot.
  factory P2pPacket.syncState({
    required String senderId,
    required int sequenceNumber,
    required Map<String, dynamic> stateJson,
  }) {
    return P2pPacket(
      type: P2pPacketType.syncState,
      senderId: senderId,
      sequenceNumber: sequenceNumber,
      payload: {'state': stateJson},
    );
  }

  /// Creates a [P2pPacketType.lifeDelta] packet.
  factory P2pPacket.lifeDelta({
    required String senderId,
    required int sequenceNumber,
    required String targetPlayerId,
    required int delta,
    int value = 0,
    String? reason,
  }) {
    final payload = <String, dynamic>{};
    if (reason != null) payload['reason'] = reason;
    return P2pPacket(
      type: P2pPacketType.lifeDelta,
      senderId: senderId,
      sequenceNumber: sequenceNumber,
      targetPlayerId: targetPlayerId,
      delta: delta,
      value: value,
      payload: payload,
    );
  }

  /// Creates a [P2pPacketType.commanderDamage] packet.
  factory P2pPacket.commanderDamage({
    required String senderId,
    required int sequenceNumber,
    required String targetPlayerId,
    required String sourcePlayerId,
    required int damageDelta,
    int? newTotal,
    bool? isLethal,
  }) {
    final payload = <String, dynamic>{'source_player_id': sourcePlayerId};
    if (newTotal != null) payload['new_total'] = newTotal;
    if (isLethal != null) payload['is_lethal'] = isLethal;
    return P2pPacket(
      type: P2pPacketType.commanderDamage,
      senderId: senderId,
      sequenceNumber: sequenceNumber,
      targetPlayerId: targetPlayerId,
      delta: damageDelta,
      payload: payload,
    );
  }

  /// Creates a [P2pPacketType.counterDelta] packet.
  factory P2pPacket.counterDelta({
    required String senderId,
    required int sequenceNumber,
    required String targetPlayerId,
    required String counterType,
    required int delta,
    int? newValue,
  }) {
    final payload = <String, dynamic>{'counter_type': counterType};
    if (newValue != null) payload['new_value'] = newValue;
    return P2pPacket(
      type: P2pPacketType.counterDelta,
      senderId: senderId,
      sequenceNumber: sequenceNumber,
      targetPlayerId: targetPlayerId,
      delta: delta,
      payload: payload,
    );
  }

  /// Creates a [P2pPacketType.manaDelta] packet.
  factory P2pPacket.manaDelta({
    required String senderId,
    required int sequenceNumber,
    required String targetPlayerId,
    required String color,
    required int delta,
  }) {
    return P2pPacket(
      type: P2pPacketType.manaDelta,
      senderId: senderId,
      sequenceNumber: sequenceNumber,
      targetPlayerId: targetPlayerId,
      delta: delta,
      payload: {'color': color},
    );
  }

  /// Creates a [P2pPacketType.manaClear] packet.
  factory P2pPacket.manaClear({
    required String senderId,
    required int sequenceNumber,
    required String targetPlayerId,
  }) {
    return P2pPacket(
      type: P2pPacketType.manaClear,
      senderId: senderId,
      sequenceNumber: sequenceNumber,
      targetPlayerId: targetPlayerId,
    );
  }

  /// Creates a [P2pPacketType.dayNightToggle] packet.
  factory P2pPacket.dayNightToggle({
    required String senderId,
    required int sequenceNumber,
    bool? isDay,
  }) {
    final payload = <String, dynamic>{};
    if (isDay != null) payload['is_day'] = isDay;
    return P2pPacket(
      type: P2pPacketType.dayNightToggle,
      senderId: senderId,
      sequenceNumber: sequenceNumber,
      payload: payload,
    );
  }

  /// Creates a [P2pPacketType.claimToken] packet.
  factory P2pPacket.claimToken({
    required String senderId,
    required int sequenceNumber,
    required String tokenType,
    required String claimantId,
  }) {
    return P2pPacket(
      type: P2pPacketType.claimToken,
      senderId: senderId,
      sequenceNumber: sequenceNumber,
      targetPlayerId: claimantId,
      payload: {'token_type': tokenType},
    );
  }

  /// Creates a [P2pPacketType.resetGame] packet.
  factory P2pPacket.resetGame({
    required String senderId,
    required int sequenceNumber,
    int startingLife = 40,
  }) {
    return P2pPacket(
      type: P2pPacketType.resetGame,
      senderId: senderId,
      sequenceNumber: sequenceNumber,
      value: startingLife,
    );
  }

  /// Creates a [P2pPacketType.heartbeat] packet.
  factory P2pPacket.heartbeat({
    required String senderId,
    required int sequenceNumber,
    bool isPing = true,
    int? lastReceivedSequence,
  }) {
    final payload = <String, dynamic>{'is_ping': isPing};
    if (lastReceivedSequence != null) {
      payload['last_received_seq'] = lastReceivedSequence;
    }
    return P2pPacket(
      type: P2pPacketType.heartbeat,
      senderId: senderId,
      sequenceNumber: sequenceNumber,
      payload: payload,
    );
  }

  /// Creates a [P2pPacketType.catchupRequest] packet.
  factory P2pPacket.catchupRequest({
    required String senderId,
    required int fromSequenceNumber,
  }) {
    return P2pPacket(
      type: P2pPacketType.catchupRequest,
      senderId: senderId,
      sequenceNumber: 0,
      payload: {
        'from_sequence': fromSequenceNumber,
        'from_sequence_number': fromSequenceNumber,
      },
    );
  }

  /// Creates a [P2pPacketType.catchupResponse] packet.
  factory P2pPacket.catchupResponse({
    required String senderId,
    required int sequenceNumber,
    required List<Map<String, dynamic>> events,
  }) {
    return P2pPacket(
      type: P2pPacketType.catchupResponse,
      senderId: senderId,
      sequenceNumber: sequenceNumber,
      payload: {'events': events},
    );
  }

  // ---------------------------------------------------------------------------
  // Serialization & Deserialization
  // ---------------------------------------------------------------------------

  /// Serializes packet to JSON map using standard contract wire keys.
  Map<String, dynamic> toJson() => {
    'type': type.wireName,
    'sender_id': senderId,
    'sequence_number': sequenceNumber,
    'target_player_id': targetPlayerId,
    'delta': delta,
    'value': value,
    'payload': payload,
    'timestamp': timestamp,
  };

  /// Safely coerces a dynamic value to an [int], tolerating [num], [String],
  /// and stringified numbers. Throws [FormatException] if the value cannot be coerced.
  static int _parseInt(dynamic v, [int fallback = 0]) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) {
      final trimmed = v.trim();
      final directInt = int.tryParse(trimmed);
      if (directInt != null) return directInt;
      final asDouble = double.tryParse(trimmed);
      if (asDouble != null && !asDouble.isNaN && !asDouble.isInfinite) {
        return asDouble.toInt();
      }
      throw FormatException('Invalid integer string: $v');
    }
    throw FormatException('Invalid integer type: ${v.runtimeType}');
  }

  /// Safely coerces a dynamic value to a nullable [String], preserving null
  /// if missing or null, and converting non-string values via `.toString()`.
  static String? _parseString(dynamic v) {
    if (v == null) return null;
    if (v is String) return v;
    return v.toString();
  }

  /// Deserializes a packet from JSON map, tolerating both snake_case and camelCase keys.
  factory P2pPacket.fromJson(Map<String, dynamic> json) {
    final rawType = json['type'] ?? json['packet_type'] ?? 'heartbeat';
    final type = rawType is P2pPacketType
        ? rawType
        : P2pPacketType.fromWireName(rawType.toString());

    final senderId =
        _parseString(json['sender_id'] ?? json['senderId']) ?? '';

    final sequenceNumber =
        _parseInt(json['sequence_number'] ?? json['sequenceNumber'], 0);

    final targetPlayerId =
        _parseString(json['target_player_id'] ?? json['targetPlayerId']);

    final delta = _parseInt(json['delta'], 0);
    final value = _parseInt(json['value'], 0);

    final rawPayload = json['payload'];
    final payload = rawPayload is Map
        ? Map<String, dynamic>.from(rawPayload)
        : const <String, dynamic>{};

    final timestamp =
        _parseInt(json['timestamp'], DateTime.now().millisecondsSinceEpoch);

    return P2pPacket(
      type: type,
      senderId: senderId,
      sequenceNumber: sequenceNumber,
      targetPlayerId: targetPlayerId,
      delta: delta,
      value: value,
      payload: payload,
      timestamp: timestamp,
    );
  }

  /// Encodes this packet into a wire-ready JSON string.
  String encode() => jsonEncode(toJson());

  /// Decodes a wire-ready JSON string into a [P2pPacket].
  static P2pPacket decode(String raw) =>
      P2pPacket.fromJson(jsonDecode(raw) as Map<String, dynamic>);

  // ---------------------------------------------------------------------------
  // Immutability, Copying & Value Equality
  // ---------------------------------------------------------------------------

  /// Creates a copy of this packet with optional field overrides.
  P2pPacket copyWith({
    P2pPacketType? type,
    String? senderId,
    int? sequenceNumber,
    String? targetPlayerId,
    int? delta,
    int? value,
    Map<String, dynamic>? payload,
    int? timestamp,
  }) {
    return P2pPacket(
      type: type ?? this.type,
      senderId: senderId ?? this.senderId,
      sequenceNumber: sequenceNumber ?? this.sequenceNumber,
      targetPlayerId: targetPlayerId ?? this.targetPlayerId,
      delta: delta ?? this.delta,
      value: value ?? this.value,
      payload: payload != null ? Map.unmodifiable(payload) : this.payload,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is P2pPacket &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          senderId == other.senderId &&
          sequenceNumber == other.sequenceNumber &&
          targetPlayerId == other.targetPlayerId &&
          delta == other.delta &&
          value == other.value &&
          mapEquals(payload, other.payload) &&
          timestamp == other.timestamp;

  @override
  int get hashCode => Object.hash(
    type,
    senderId,
    sequenceNumber,
    targetPlayerId,
    delta,
    value,
    timestamp,
  );

  @override
  String toString() =>
      'P2pPacket(type: ${type.wireName}, seq: $sequenceNumber, from: $senderId, target: $targetPlayerId, delta: $delta)';
}
