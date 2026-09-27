// Copyright (c) 2026 Countr. All rights reserved.
// Production implementation of P2pSyncEngine for local offline MTG pod synchronization.

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:countr/features/life_counter/domain/models/pod_state.dart';
import 'package:countr/features/life_counter/domain/models/p2p_packet.dart';
import 'package:countr/features/life_counter/data/network/p2p_transport.dart';
import 'package:countr/features/life_counter/data/repositories/match_session_repository.dart';

/// Represents an optimistic local action on a client device awaiting confirmation from the Host.
@immutable
class PendingAction {
  final String actionId;
  final P2pPacketType type;
  final String? targetPlayerId;
  final int delta;
  final int value;
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  const PendingAction({
    required this.actionId,
    required this.type,
    this.targetPlayerId,
    this.delta = 0,
    this.value = 0,
    this.payload = const {},
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'action_id': actionId,
        'type': type.wireName,
        'target_player_id': targetPlayerId,
        'delta': delta,
        'value': value,
        'payload': payload,
        'created_at': createdAt.toIso8601String(),
      };
}

/// In-memory cache entry of confirmed events maintained by Host for fast catch-up responses.
@immutable
class EventLogEntry {
  final int sequenceNumber;
  final P2pPacket packet;
  final DateTime timestamp;

  const EventLogEntry({
    required this.sequenceNumber,
    required this.packet,
    required this.timestamp,
  });
}

/// Event Sourcing engine for P2P state synchronization in local offline MTG pods.
///
/// Responsibilities:
/// 1. **Host Sequencing**: The Host acts as the single source of truth, assigning
///    monotonically increasing sequence numbers to all incoming and local actions.
/// 2. **Delta-Based Event Sourcing**: Life changes, counter modifications, commander damage,
///    and mana pool adjustments are transmitted as commutative deltas.
/// 3. **Client Optimistic Updates**: Clients apply local mutations immediately (0ms UI latency),
///    queuing [PendingAction] items and reconciling when confirmed host packets arrive.
/// 4. **Token Exclusivity**: Manages atomic pod-wide transfers for Monarch and Initiative tokens
///    ensuring at most one player holds each token at any time.
/// 5. **Day / Night Synchronization**: Maintains a shared pod-wide Day/Night cycle toggle.
/// 6. **Reconnection & Catch-Up Replay**: Reconnected clients request missing event slices
///    starting from their last known sequence number and replay events bit-for-bit.
/// 7. **Drift Database Integration**: Integrates directly with [MatchSessionRepositoryInterface]
///    to automatically persist all confirmed transactions to local SQLite.
class P2pSyncEngine {
  PodState _state;
  final P2pTransport transport;
  final bool isHost;
  final String? localPlayerId;
  final MatchSessionRepositoryInterface? repository;
  void Function(PodState newState)? onStateChanged;

  StreamSubscription<P2pPacket>? _packetSubscription;
  final List<PendingAction> _pendingActions = [];
  final List<EventLogEntry> _eventLog = [];
  final Map<int, P2pPacket> _outOfOrderBuffer = {};

  static const int _maxEventLogSize = 300;
  bool _isDisposed = false;

  P2pSyncEngine({
    required PodState initialState,
    required this.transport,
    required this.isHost,
    this.localPlayerId,
    this.repository,
    this.onStateChanged,
  }) : _state = initialState {
    _packetSubscription = transport.incomingPackets.listen(
      _handleIncomingPacket,
      onError: (error) {
        debugPrint('[P2pSyncEngine] Transport stream error: $error');
      },
    );
  }

  /// Current immutable domain state of the pod.
  PodState get state => _state;

  /// Unmodifiable view of client pending unconfirmed actions.
  List<PendingAction> get pendingActions => List.unmodifiable(_pendingActions);

  /// Unmodifiable view of host confirmed event log.
  List<EventLogEntry> get eventLog => List.unmodifiable(_eventLog);

  /// Whether the engine has been disposed.
  bool get isDisposed => _isDisposed;

  // ===========================================================================
  // INCOMING PACKET DISPATCHER
  // ===========================================================================

  void _handleIncomingPacket(P2pPacket packet) {
    if (_isDisposed) return;

    switch (packet.type) {
      case P2pPacketType.syncState:
        _handleSyncState(packet);
        break;

      case P2pPacketType.lifeDelta:
        _handleLifeDelta(packet);
        break;

      case P2pPacketType.commanderDamage:
        _handleCommanderDamage(packet);
        break;

      case P2pPacketType.counterDelta:
        _handleCounterDelta(packet);
        break;

      case P2pPacketType.manaDelta:
        _handleManaDelta(packet);
        break;

      case P2pPacketType.manaClear:
        _handleManaClear(packet);
        break;

      case P2pPacketType.dayNightToggle:
        _handleDayNightToggle(packet);
        break;

      case P2pPacketType.claimToken:
        _handleClaimToken(packet);
        break;

      case P2pPacketType.resetGame:
        _handleResetGame(packet);
        break;

      case P2pPacketType.catchupRequest:
        _handleCatchupRequest(packet);
        break;

      case P2pPacketType.catchupResponse:
        _handleCatchupResponse(packet);
        break;

      case P2pPacketType.heartbeat:
        _handleHeartbeat(packet);
        break;

      default:
        break;
    }
  }

  // ===========================================================================
  // PACKET HANDLERS
  // ===========================================================================

  /// Full authoritative snapshot from host.
  void _handleSyncState(P2pPacket packet) {
    if (isHost) return;

    final stateData = packet.payload['state'];
    if (stateData is Map<String, dynamic>) {
      final receivedState = PodState.fromJson(stateData);

      // Preserve local player device binding
      final updatedPlayers = receivedState.players.map((p) {
        final wasLocal = _state.getPlayer(p.id)?.isLocalDevice ?? false;
        final isLocal =
            (localPlayerId != null && p.id == localPlayerId) || wasLocal;
        if (p.isLocalDevice != isLocal) {
          return p.copyWith(isLocalDevice: isLocal);
        }
        return p;
      }).toList();

      var reconciledState = receivedState.copyWith(players: updatedPlayers);

      // Re-apply any pending unconfirmed local actions on top of host snapshot
      for (final pending in _pendingActions) {
        reconciledState = _applyPendingActionToState(reconciledState, pending);
      }

      _state = reconciledState;
      _outOfOrderBuffer.clear();
      onStateChanged?.call(_state);
    }
  }

  /// Life delta adjustment packet.
  void _handleLifeDelta(P2pPacket packet) {
    final targetId = packet.targetPlayerId;
    if (targetId == null) return;

    if (isHost) {
      final nextSeq = _state.sequenceNumber + 1;
      _applyLifeDeltaInternal(targetId, packet.delta, nextSeq);

      final confirmedPacket = P2pPacket(
        type: P2pPacketType.lifeDelta,
        senderId: transport.endpointId,
        sequenceNumber: nextSeq,
        targetPlayerId: targetId,
        delta: packet.delta,
        payload: Map<String, dynamic>.from(packet.payload),
      );

      _recordEventInLog(confirmedPacket);
      transport.broadcastPacket(confirmedPacket);

      repository?.recordLifeDelta(
        sessionId: _state.sessionId,
        playerId: targetId,
        delta: packet.delta,
        sequenceNumber: nextSeq,
      );
    } else {
      // Client reconciliation
      final actionId = packet.payload['action_id'] as String?;
      final pendingIndex = actionId != null
          ? _pendingActions.indexWhere((a) => a.actionId == actionId)
          : -1;

      if (pendingIndex != -1) {
        // Confirmation of client's own optimistic update
        _pendingActions.removeAt(pendingIndex);
        _state = _state.copyWith(sequenceNumber: packet.sequenceNumber);
        onStateChanged?.call(_state);
      } else {
        // External update from host or another peer
        _applyLifeDeltaInternal(targetId, packet.delta, packet.sequenceNumber);
      }
      _checkAndDrainOutOfOrderBuffer();
    }
  }

  /// Commander combat damage packet.
  void _handleCommanderDamage(P2pPacket packet) {
    final targetId = packet.targetPlayerId;
    final sourceId = packet.payload['source_player_id'] as String? ??
        packet.payload['sourcePlayerId'] as String?;
    if (targetId == null || sourceId == null) return;

    if (isHost) {
      final nextSeq = _state.sequenceNumber + 1;
      _applyCommanderDamageInternal(
        targetPlayerId: targetId,
        sourcePlayerId: sourceId,
        damageDelta: packet.delta,
        newSequence: nextSeq,
      );

      final confirmedPacket = P2pPacket(
        type: P2pPacketType.commanderDamage,
        senderId: transport.endpointId,
        sequenceNumber: nextSeq,
        targetPlayerId: targetId,
        delta: packet.delta,
        payload: {'source_player_id': sourceId, ...packet.payload},
      );

      _recordEventInLog(confirmedPacket);
      transport.broadcastPacket(confirmedPacket);

      repository?.recordCommanderDamage(
        sessionId: _state.sessionId,
        targetPlayerId: targetId,
        sourcePlayerId: sourceId,
        delta: packet.delta,
        sequenceNumber: nextSeq,
      );
    } else {
      final actionId = packet.payload['action_id'] as String?;
      final pendingIndex = actionId != null
          ? _pendingActions.indexWhere((a) => a.actionId == actionId)
          : -1;

      if (pendingIndex != -1) {
        _pendingActions.removeAt(pendingIndex);
        _state = _state.copyWith(sequenceNumber: packet.sequenceNumber);
        onStateChanged?.call(_state);
      } else {
        _applyCommanderDamageInternal(
          targetPlayerId: targetId,
          sourcePlayerId: sourceId,
          damageDelta: packet.delta,
          newSequence: packet.sequenceNumber,
        );
      }
      _checkAndDrainOutOfOrderBuffer();
    }
  }

  /// Secondary counter modification (poison, energy, xp, commander_tax).
  void _handleCounterDelta(P2pPacket packet) {
    final targetId = packet.targetPlayerId;
    final counterType = packet.payload['counter_type'] as String?;
    if (targetId == null || counterType == null) return;

    if (isHost) {
      final nextSeq = _state.sequenceNumber + 1;
      _applyCounterDeltaInternal(
        targetPlayerId: targetId,
        counterType: counterType,
        delta: packet.delta,
        newSequence: nextSeq,
      );

      final confirmedPacket = P2pPacket(
        type: P2pPacketType.counterDelta,
        senderId: transport.endpointId,
        sequenceNumber: nextSeq,
        targetPlayerId: targetId,
        delta: packet.delta,
        payload: {'counter_type': counterType, ...packet.payload},
      );

      _recordEventInLog(confirmedPacket);
      transport.broadcastPacket(confirmedPacket);

      repository?.recordCounterChange(
        sessionId: _state.sessionId,
        playerId: targetId,
        counterType: counterType,
        delta: packet.delta,
        sequenceNumber: nextSeq,
      );
    } else {
      final actionId = packet.payload['action_id'] as String?;
      final pendingIndex = actionId != null
          ? _pendingActions.indexWhere((a) => a.actionId == actionId)
          : -1;

      if (pendingIndex != -1) {
        _pendingActions.removeAt(pendingIndex);
        _state = _state.copyWith(sequenceNumber: packet.sequenceNumber);
        onStateChanged?.call(_state);
      } else {
        _applyCounterDeltaInternal(
          targetPlayerId: targetId,
          counterType: counterType,
          delta: packet.delta,
          newSequence: packet.sequenceNumber,
        );
      }
      _checkAndDrainOutOfOrderBuffer();
    }
  }

  /// Floating mana adjustment and storm tracker.
  void _handleManaDelta(P2pPacket packet) {
    final targetId = packet.targetPlayerId;
    final color = packet.payload['color'] as String?;
    if (targetId == null || color == null) return;

    if (isHost) {
      final nextSeq = _state.sequenceNumber + 1;
      _applyManaDeltaInternal(
        targetPlayerId: targetId,
        color: color,
        delta: packet.delta,
        newSequence: nextSeq,
      );

      final confirmedPacket = P2pPacket(
        type: P2pPacketType.manaDelta,
        senderId: transport.endpointId,
        sequenceNumber: nextSeq,
        targetPlayerId: targetId,
        delta: packet.delta,
        payload: {'color': color, ...packet.payload},
      );

      _recordEventInLog(confirmedPacket);
      transport.broadcastPacket(confirmedPacket);

      repository?.recordManaChange(
        sessionId: _state.sessionId,
        playerId: targetId,
        color: color,
        delta: packet.delta,
        sequenceNumber: nextSeq,
      );
      if (packet.delta > 0) {
        repository?.recordStormChange(
          sessionId: _state.sessionId,
          playerId: targetId,
          delta: 1,
          sequenceNumber: nextSeq,
        );
      }
    } else {
      final actionId = packet.payload['action_id'] as String?;
      final pendingIndex = actionId != null
          ? _pendingActions.indexWhere((a) => a.actionId == actionId)
          : -1;

      if (pendingIndex != -1) {
        _pendingActions.removeAt(pendingIndex);
        _state = _state.copyWith(sequenceNumber: packet.sequenceNumber);
        onStateChanged?.call(_state);
      } else {
        _applyManaDeltaInternal(
          targetPlayerId: targetId,
          color: color,
          delta: packet.delta,
          newSequence: packet.sequenceNumber,
        );
      }
      _checkAndDrainOutOfOrderBuffer();
    }
  }

  /// Clears a player's floating mana pool and storm count.
  void _handleManaClear(P2pPacket packet) {
    final targetId = packet.targetPlayerId;
    if (targetId == null) return;

    if (isHost) {
      final nextSeq = _state.sequenceNumber + 1;
      _applyManaClearInternal(targetId, nextSeq);

      final confirmedPacket = P2pPacket(
        type: P2pPacketType.manaClear,
        senderId: transport.endpointId,
        sequenceNumber: nextSeq,
        targetPlayerId: targetId,
        payload: Map<String, dynamic>.from(packet.payload),
      );

      _recordEventInLog(confirmedPacket);
      transport.broadcastPacket(confirmedPacket);

      repository?.clearManaPool(
        sessionId: _state.sessionId,
        playerId: targetId,
        sequenceNumber: nextSeq,
      );
    } else {
      final actionId = packet.payload['action_id'] as String?;
      if (actionId != null) {
        _pendingActions.removeWhere((a) => a.actionId == actionId);
      }
      _applyManaClearInternal(targetId, packet.sequenceNumber);
      _checkAndDrainOutOfOrderBuffer();
    }
  }

  /// Pod-wide shared Day/Night toggle.
  void _handleDayNightToggle(P2pPacket packet) {
    if (isHost) {
      final nextSeq = _state.sequenceNumber + 1;
      final newDay = !_state.isDay;
      _state = _state.copyWith(isDay: newDay, sequenceNumber: nextSeq);
      onStateChanged?.call(_state);

      final confirmedPacket = P2pPacket(
        type: P2pPacketType.dayNightToggle,
        senderId: transport.endpointId,
        sequenceNumber: nextSeq,
        payload: {
          'is_day': newDay,
          if (packet.payload['action_id'] != null)
            'action_id': packet.payload['action_id'],
        },
      );

      _recordEventInLog(confirmedPacket);
      transport.broadcastPacket(confirmedPacket);

      repository?.recordDayNightToggle(
        sessionId: _state.sessionId,
        isDay: newDay,
        sequenceNumber: nextSeq,
      );
    } else {
      final actionId = packet.payload['action_id'] as String?;
      if (actionId != null) {
        _pendingActions.removeWhere((a) => a.actionId == actionId);
      }
      final authoritativeDay =
          packet.payload['is_day'] as bool? ?? !_state.isDay;
      _state = _state.copyWith(
        isDay: authoritativeDay,
        sequenceNumber: packet.sequenceNumber,
      );
      onStateChanged?.call(_state);
      _checkAndDrainOutOfOrderBuffer();
    }
  }

  /// Pod-wide exclusive token claim (Monarch, Initiative).
  void _handleClaimToken(P2pPacket packet) {
    final claimantId = packet.targetPlayerId;
    final tokenType = packet.payload['token_type'] as String?;
    if (claimantId == null || tokenType == null) return;

    if (isHost) {
      final nextSeq = _state.sequenceNumber + 1;
      _applyClaimTokenInternal(
        tokenType: tokenType,
        claimantId: claimantId,
        newSequence: nextSeq,
      );

      final confirmedPacket = P2pPacket(
        type: P2pPacketType.claimToken,
        senderId: transport.endpointId,
        sequenceNumber: nextSeq,
        targetPlayerId: claimantId,
        payload: {'token_type': tokenType, ...packet.payload},
      );

      _recordEventInLog(confirmedPacket);
      transport.broadcastPacket(confirmedPacket);

      repository?.recordCounterChange(
        sessionId: _state.sessionId,
        playerId: claimantId,
        counterType: tokenType,
        delta: 1,
        sequenceNumber: nextSeq,
      );
    } else {
      final actionId = packet.payload['action_id'] as String?;
      if (actionId != null) {
        _pendingActions.removeWhere((a) => a.actionId == actionId);
      }
      _applyClaimTokenInternal(
        tokenType: tokenType,
        claimantId: claimantId,
        newSequence: packet.sequenceNumber,
      );
      _checkAndDrainOutOfOrderBuffer();
    }
  }

  /// Global match reset.
  void _handleResetGame(P2pPacket packet) {
    final startingLife = packet.value > 0 ? packet.value : _state.startingLife;

    if (isHost) {
      final nextSeq = _state.sequenceNumber + 1;
      _applyResetGameInternal(startingLife, nextSeq);

      final confirmedPacket = P2pPacket(
        type: P2pPacketType.resetGame,
        senderId: transport.endpointId,
        sequenceNumber: nextSeq,
        value: startingLife,
        payload: Map<String, dynamic>.from(packet.payload),
      );

      _recordEventInLog(confirmedPacket);
      transport.broadcastPacket(confirmedPacket);

      repository?.resetSession(_state.sessionId, startingLife);
    } else {
      _pendingActions.clear();
      _outOfOrderBuffer.clear();
      _applyResetGameInternal(startingLife, packet.sequenceNumber);
      _checkAndDrainOutOfOrderBuffer();
    }
  }

  /// Host responds to client catch-up request.
  void _handleCatchupRequest(P2pPacket packet) {
    if (!isHost) return;

    final fromSeq = (packet.payload['from_sequence'] as num? ??
            packet.payload['from_sequence_number'] as num?)
        ?.toInt() ??
        packet.sequenceNumber;

    if (fromSeq < _state.sequenceNumber) {
      // Find missed events in the log
      final missed =
          _eventLog.where((e) => e.sequenceNumber > fromSeq).toList();

      if (missed.isNotEmpty && missed.first.sequenceNumber == fromSeq + 1) {
        // Delta catchup slice
        final response = P2pPacket(
          type: P2pPacketType.catchupResponse,
          senderId: transport.endpointId,
          sequenceNumber: _state.sequenceNumber,
          payload: {
            'from_sequence': fromSeq,
            'to_sequence': _state.sequenceNumber,
            'events': missed.map((e) => e.packet.toJson()).toList(),
          },
        );
        transport.sendPacket(response);
      } else {
        // Gap is too wide or event log pruned: send full authoritative snapshot
        final snapshot = P2pPacket(
          type: P2pPacketType.syncState,
          senderId: transport.endpointId,
          sequenceNumber: _state.sequenceNumber,
          payload: {'state': _state.toJson()},
        );
        transport.sendPacket(snapshot);
      }
    }
  }

  /// Client replays missed events from host catch-up response.
  void _handleCatchupResponse(P2pPacket packet) {
    if (isHost) return;

    final rawEvents = packet.payload['events'];
    if (rawEvents is List) {
      for (final eventMap in rawEvents) {
        if (eventMap is Map<String, dynamic>) {
          final eventPacket = P2pPacket.fromJson(eventMap);
          if (eventPacket.sequenceNumber > _state.sequenceNumber) {
            _handleIncomingPacket(eventPacket);
          }
        }
      }
    }
  }

  /// Heartbeat ping/pong.
  void _handleHeartbeat(P2pPacket packet) {
    final isPing = packet.payload['is_ping'] as bool? ?? true;
    if (isPing) {
      // Reply with pong
      transport.sendPacket(P2pPacket(
        type: P2pPacketType.heartbeat,
        senderId: transport.endpointId,
        sequenceNumber: _state.sequenceNumber,
        payload: {'is_ping': false, 'last_seq': _state.sequenceNumber},
      ));
    }
  }

  // ===========================================================================
  // PUBLIC MUTATION APIS (INVOKED BY LOCAL UI / CONTROLLER)
  // ===========================================================================

  /// Sends a life delta adjustment for [playerId].
  Future<void> sendLifeAdjustment(String playerId, int delta) async {
    final actionId = const Uuid().v4();

    if (isHost) {
      final nextSeq = _state.sequenceNumber + 1;
      _applyLifeDeltaInternal(playerId, delta, nextSeq);

      final packet = P2pPacket(
        type: P2pPacketType.lifeDelta,
        senderId: transport.endpointId,
        sequenceNumber: nextSeq,
        targetPlayerId: playerId,
        delta: delta,
        payload: {'action_id': actionId},
      );

      _recordEventInLog(packet);
      await transport.broadcastPacket(packet);

      repository?.recordLifeDelta(
        sessionId: _state.sessionId,
        playerId: playerId,
        delta: delta,
        sequenceNumber: nextSeq,
      );
    } else {
      // Optimistic update on client
      final pendingAction = PendingAction(
        actionId: actionId,
        type: P2pPacketType.lifeDelta,
        targetPlayerId: playerId,
        delta: delta,
        createdAt: DateTime.now(),
      );
      _pendingActions.add(pendingAction);
      _applyLifeDeltaInternal(playerId, delta, _state.sequenceNumber);

      final packet = P2pPacket(
        type: P2pPacketType.lifeDelta,
        senderId: transport.endpointId,
        sequenceNumber: _state.sequenceNumber + 1,
        targetPlayerId: playerId,
        delta: delta,
        payload: {'action_id': actionId},
      );
      await transport.sendPacket(packet);
    }
  }

  /// Records combat damage from [sourcePlayerId] commander onto [targetPlayerId].
  Future<void> sendCommanderDamage({
    required String targetPlayerId,
    required String sourcePlayerId,
    required int damageDelta,
  }) async {
    final actionId = const Uuid().v4();

    if (isHost) {
      final nextSeq = _state.sequenceNumber + 1;
      _applyCommanderDamageInternal(
        targetPlayerId: targetPlayerId,
        sourcePlayerId: sourcePlayerId,
        damageDelta: damageDelta,
        newSequence: nextSeq,
      );

      final packet = P2pPacket(
        type: P2pPacketType.commanderDamage,
        senderId: transport.endpointId,
        sequenceNumber: nextSeq,
        targetPlayerId: targetPlayerId,
        delta: damageDelta,
        payload: {'source_player_id': sourcePlayerId, 'action_id': actionId},
      );

      _recordEventInLog(packet);
      await transport.broadcastPacket(packet);

      repository?.recordCommanderDamage(
        sessionId: _state.sessionId,
        targetPlayerId: targetPlayerId,
        sourcePlayerId: sourcePlayerId,
        delta: damageDelta,
        sequenceNumber: nextSeq,
      );
    } else {
      final pendingAction = PendingAction(
        actionId: actionId,
        type: P2pPacketType.commanderDamage,
        targetPlayerId: targetPlayerId,
        delta: damageDelta,
        payload: {'source_player_id': sourcePlayerId},
        createdAt: DateTime.now(),
      );
      _pendingActions.add(pendingAction);
      _applyCommanderDamageInternal(
        targetPlayerId: targetPlayerId,
        sourcePlayerId: sourcePlayerId,
        damageDelta: damageDelta,
        newSequence: _state.sequenceNumber,
      );

      final packet = P2pPacket(
        type: P2pPacketType.commanderDamage,
        senderId: transport.endpointId,
        sequenceNumber: _state.sequenceNumber + 1,
        targetPlayerId: targetPlayerId,
        delta: damageDelta,
        payload: {'source_player_id': sourcePlayerId, 'action_id': actionId},
      );
      await transport.sendPacket(packet);
    }
  }

  /// Modifies secondary counters (poison, energy, experience, commander_tax).
  Future<void> sendCounterDelta({
    required String targetPlayerId,
    required String counterType,
    required int delta,
  }) async {
    final actionId = const Uuid().v4();

    if (isHost) {
      final nextSeq = _state.sequenceNumber + 1;
      _applyCounterDeltaInternal(
        targetPlayerId: targetPlayerId,
        counterType: counterType,
        delta: delta,
        newSequence: nextSeq,
      );

      final packet = P2pPacket(
        type: P2pPacketType.counterDelta,
        senderId: transport.endpointId,
        sequenceNumber: nextSeq,
        targetPlayerId: targetPlayerId,
        delta: delta,
        payload: {'counter_type': counterType, 'action_id': actionId},
      );

      _recordEventInLog(packet);
      await transport.broadcastPacket(packet);

      repository?.recordCounterChange(
        sessionId: _state.sessionId,
        playerId: targetPlayerId,
        counterType: counterType,
        delta: delta,
        sequenceNumber: nextSeq,
      );
    } else {
      final pendingAction = PendingAction(
        actionId: actionId,
        type: P2pPacketType.counterDelta,
        targetPlayerId: targetPlayerId,
        delta: delta,
        payload: {'counter_type': counterType},
        createdAt: DateTime.now(),
      );
      _pendingActions.add(pendingAction);
      _applyCounterDeltaInternal(
        targetPlayerId: targetPlayerId,
        counterType: counterType,
        delta: delta,
        newSequence: _state.sequenceNumber,
      );

      final packet = P2pPacket(
        type: P2pPacketType.counterDelta,
        senderId: transport.endpointId,
        sequenceNumber: _state.sequenceNumber + 1,
        targetPlayerId: targetPlayerId,
        delta: delta,
        payload: {'counter_type': counterType, 'action_id': actionId},
      );
      await transport.sendPacket(packet);
    }
  }

  /// Modifies a player's floating mana pool ('W', 'U', 'B', 'R', 'G', 'C').
  Future<void> sendManaDelta({
    required String targetPlayerId,
    required String color,
    required int delta,
  }) async {
    final actionId = const Uuid().v4();

    if (isHost) {
      final nextSeq = _state.sequenceNumber + 1;
      _applyManaDeltaInternal(
        targetPlayerId: targetPlayerId,
        color: color,
        delta: delta,
        newSequence: nextSeq,
      );

      final packet = P2pPacket(
        type: P2pPacketType.manaDelta,
        senderId: transport.endpointId,
        sequenceNumber: nextSeq,
        targetPlayerId: targetPlayerId,
        delta: delta,
        payload: {'color': color, 'action_id': actionId},
      );

      _recordEventInLog(packet);
      await transport.broadcastPacket(packet);

      repository?.recordManaChange(
        sessionId: _state.sessionId,
        playerId: targetPlayerId,
        color: color,
        delta: delta,
        sequenceNumber: nextSeq,
      );
      if (delta > 0) {
        repository?.recordStormChange(
          sessionId: _state.sessionId,
          playerId: targetPlayerId,
          delta: 1,
          sequenceNumber: nextSeq,
        );
      }
    } else {
      final pendingAction = PendingAction(
        actionId: actionId,
        type: P2pPacketType.manaDelta,
        targetPlayerId: targetPlayerId,
        delta: delta,
        payload: {'color': color},
        createdAt: DateTime.now(),
      );
      _pendingActions.add(pendingAction);
      _applyManaDeltaInternal(
        targetPlayerId: targetPlayerId,
        color: color,
        delta: delta,
        newSequence: _state.sequenceNumber,
      );

      final packet = P2pPacket(
        type: P2pPacketType.manaDelta,
        senderId: transport.endpointId,
        sequenceNumber: _state.sequenceNumber + 1,
        targetPlayerId: targetPlayerId,
        delta: delta,
        payload: {'color': color, 'action_id': actionId},
      );
      await transport.sendPacket(packet);
    }
  }

  /// Clears floating mana pool and storm counter for [targetPlayerId].
  Future<void> sendManaClear(String targetPlayerId) async {
    final actionId = const Uuid().v4();

    if (isHost) {
      final nextSeq = _state.sequenceNumber + 1;
      _applyManaClearInternal(targetPlayerId, nextSeq);

      final packet = P2pPacket(
        type: P2pPacketType.manaClear,
        senderId: transport.endpointId,
        sequenceNumber: nextSeq,
        targetPlayerId: targetPlayerId,
        payload: {'action_id': actionId},
      );

      _recordEventInLog(packet);
      await transport.broadcastPacket(packet);

      repository?.clearManaPool(
        sessionId: _state.sessionId,
        playerId: targetPlayerId,
        sequenceNumber: nextSeq,
      );
    } else {
      final pendingAction = PendingAction(
        actionId: actionId,
        type: P2pPacketType.manaClear,
        targetPlayerId: targetPlayerId,
        createdAt: DateTime.now(),
      );
      _pendingActions.add(pendingAction);
      _applyManaClearInternal(targetPlayerId, _state.sequenceNumber);

      final packet = P2pPacket(
        type: P2pPacketType.manaClear,
        senderId: transport.endpointId,
        sequenceNumber: _state.sequenceNumber + 1,
        targetPlayerId: targetPlayerId,
        payload: {'action_id': actionId},
      );
      await transport.sendPacket(packet);
    }
  }

  /// Claims Monarch or Initiative token for [claimantId].
  /// Enforces pod-wide exclusivity: all other players lose the token.
  Future<void> claimToken(
      {required String tokenType, required String claimantId}) async {
    final actionId = const Uuid().v4();

    if (isHost) {
      final nextSeq = _state.sequenceNumber + 1;
      _applyClaimTokenInternal(
        tokenType: tokenType,
        claimantId: claimantId,
        newSequence: nextSeq,
      );

      final packet = P2pPacket(
        type: P2pPacketType.claimToken,
        senderId: transport.endpointId,
        sequenceNumber: nextSeq,
        targetPlayerId: claimantId,
        payload: {'token_type': tokenType, 'action_id': actionId},
      );

      _recordEventInLog(packet);
      await transport.broadcastPacket(packet);

      repository?.recordCounterChange(
        sessionId: _state.sessionId,
        playerId: claimantId,
        counterType: tokenType,
        delta: 1,
        sequenceNumber: nextSeq,
      );
    } else {
      final pendingAction = PendingAction(
        actionId: actionId,
        type: P2pPacketType.claimToken,
        targetPlayerId: claimantId,
        payload: {'token_type': tokenType},
        createdAt: DateTime.now(),
      );
      _pendingActions.add(pendingAction);
      _applyClaimTokenInternal(
        tokenType: tokenType,
        claimantId: claimantId,
        newSequence: _state.sequenceNumber,
      );

      final packet = P2pPacket(
        type: P2pPacketType.claimToken,
        senderId: transport.endpointId,
        sequenceNumber: _state.sequenceNumber + 1,
        targetPlayerId: claimantId,
        payload: {'token_type': tokenType, 'action_id': actionId},
      );
      await transport.sendPacket(packet);
    }
  }

  /// Toggles shared Day/Night cycle across the pod.
  Future<void> toggleDayNight() async {
    final actionId = const Uuid().v4();

    if (isHost) {
      final nextSeq = _state.sequenceNumber + 1;
      final newDay = !_state.isDay;
      _state = _state.copyWith(isDay: newDay, sequenceNumber: nextSeq);
      onStateChanged?.call(_state);

      final packet = P2pPacket(
        type: P2pPacketType.dayNightToggle,
        senderId: transport.endpointId,
        sequenceNumber: nextSeq,
        payload: {'is_day': newDay, 'action_id': actionId},
      );

      _recordEventInLog(packet);
      await transport.broadcastPacket(packet);

      repository?.recordDayNightToggle(
        sessionId: _state.sessionId,
        isDay: newDay,
        sequenceNumber: nextSeq,
      );
    } else {
      final pendingAction = PendingAction(
        actionId: actionId,
        type: P2pPacketType.dayNightToggle,
        createdAt: DateTime.now(),
      );
      _pendingActions.add(pendingAction);
      _state = _state.copyWith(isDay: !_state.isDay);
      onStateChanged?.call(_state);

      final packet = P2pPacket(
        type: P2pPacketType.dayNightToggle,
        senderId: transport.endpointId,
        sequenceNumber: _state.sequenceNumber + 1,
        payload: {'action_id': actionId},
      );
      await transport.sendPacket(packet);
    }
  }

  /// Resets all players to starting life and clears counters while preserving pod seating.
  Future<void> resetGame([int? startingLifeOverride]) async {
    final targetLife = startingLifeOverride ?? _state.startingLife;
    final actionId = const Uuid().v4();

    if (isHost) {
      final nextSeq = _state.sequenceNumber + 1;
      _applyResetGameInternal(targetLife, nextSeq);

      final packet = P2pPacket(
        type: P2pPacketType.resetGame,
        senderId: transport.endpointId,
        sequenceNumber: nextSeq,
        value: targetLife,
        payload: {'action_id': actionId},
      );

      _recordEventInLog(packet);
      await transport.broadcastPacket(packet);

      repository?.resetSession(_state.sessionId, targetLife);
    } else {
      _applyResetGameInternal(targetLife, _state.sequenceNumber);

      final packet = P2pPacket(
        type: P2pPacketType.resetGame,
        senderId: transport.endpointId,
        sequenceNumber: _state.sequenceNumber + 1,
        value: targetLife,
        payload: {'action_id': actionId},
      );
      await transport.sendPacket(packet);
    }
  }

  /// Sends catch-up request to Host asking for missing event log slice.
  Future<void> requestCatchup([int? fromSequenceNumber]) async {
    final fromSeq = fromSequenceNumber ?? _state.sequenceNumber;
    final packet = P2pPacket(
      type: P2pPacketType.catchupRequest,
      senderId: transport.endpointId,
      sequenceNumber: fromSeq,
      payload: {
        'from_sequence': fromSeq,
        'from_sequence_number': fromSeq,
      },
    );
    await transport.sendPacket(packet);
  }

  /// Broadcasts authoritative [syncState] snapshot to connected peers.
  Future<void> broadcastSyncState() async {
    if (!isHost) return;
    final packet = P2pPacket(
      type: P2pPacketType.syncState,
      senderId: transport.endpointId,
      sequenceNumber: _state.sequenceNumber,
      payload: {'state': _state.toJson()},
    );
    await transport.broadcastPacket(packet);
  }

  // ===========================================================================
  // INTERNAL STATE APPLICATORS (PURE FUNCTIONAL MUTATIONS)
  // ===========================================================================

  void _applyLifeDeltaInternal(String playerId, int delta, int sequence) {
    final updatedPlayers = _state.players.map((p) {
      if (p.id == playerId) {
        final newLife = p.life + delta;
        final isCmdLethal = p.commanderDamageTaken.values.any((d) => d >= 21);
        final isEliminated = newLife <= 0 || p.poison >= 10 || isCmdLethal;
        return p.copyWith(life: newLife, isEliminated: isEliminated);
      }
      return p;
    }).toList();

    _state = _state.copyWith(players: updatedPlayers, sequenceNumber: sequence);
    onStateChanged?.call(_state);
  }

  void _applyCommanderDamageInternal({
    required String targetPlayerId,
    required String sourcePlayerId,
    required int damageDelta,
    required int newSequence,
  }) {
    final updatedPlayers = _state.players.map((p) {
      if (p.id == targetPlayerId) {
        final currentDmg = p.commanderDamageTaken[sourcePlayerId] ?? 0;
        final newDmg = math.max(0, currentDmg + damageDelta);
        final newMap = Map<String, int>.from(p.commanderDamageTaken);
        newMap[sourcePlayerId] = newDmg;

        final newLife = p.life - damageDelta;
        final isCmdLethal = newMap.values.any((d) => d >= 21);
        final isEliminated = newLife <= 0 || p.poison >= 10 || isCmdLethal;

        return p.copyWith(
          life: newLife,
          commanderDamageTaken: newMap,
          isEliminated: isEliminated,
        );
      }
      return p;
    }).toList();

    _state =
        _state.copyWith(players: updatedPlayers, sequenceNumber: newSequence);
    onStateChanged?.call(_state);
  }

  void _applyCounterDeltaInternal({
    required String targetPlayerId,
    required String counterType,
    required int delta,
    required int newSequence,
  }) {
    final updatedPlayers = _state.players.map((p) {
      if (p.id == targetPlayerId) {
        switch (counterType.toLowerCase()) {
          case 'poison':
            final newPoison = math.max(0, p.poison + delta);
            final isCmdLethal =
                p.commanderDamageTaken.values.any((d) => d >= 21);
            final isEliminated = p.life <= 0 || newPoison >= 10 || isCmdLethal;
            return p.copyWith(poison: newPoison, isEliminated: isEliminated);
          case 'energy':
            return p.copyWith(energy: math.max(0, p.energy + delta));
          case 'experience':
          case 'xp':
            return p.copyWith(experience: math.max(0, p.experience + delta));
          case 'commander_tax':
            return p.copyWith(
                commanderTax: math.max(0, p.commanderTax + delta));
        }
      }
      return p;
    }).toList();

    _state =
        _state.copyWith(players: updatedPlayers, sequenceNumber: newSequence);
    onStateChanged?.call(_state);
  }

  void _applyManaDeltaInternal({
    required String targetPlayerId,
    required String color,
    required int delta,
    required int newSequence,
  }) {
    final updatedPlayers = _state.players.map((p) {
      if (p.id == targetPlayerId) {
        final current = p.floatingMana[color] ?? 0;
        final newPool = Map<String, int>.from(p.floatingMana);
        newPool[color] = math.max(0, current + delta);
        final newStorm = delta > 0 ? p.stormCount + 1 : p.stormCount;
        return p.copyWith(floatingMana: newPool, stormCount: newStorm);
      }
      return p;
    }).toList();

    _state =
        _state.copyWith(players: updatedPlayers, sequenceNumber: newSequence);
    onStateChanged?.call(_state);
  }

  void _applyManaClearInternal(String targetPlayerId, int newSequence) {
    final updatedPlayers = _state.players.map((p) {
      if (p.id == targetPlayerId) {
        return p.copyWith(
          floatingMana: const {
            'W': 0,
            'U': 0,
            'B': 0,
            'R': 0,
            'G': 0,
            'C': 0
          },
          stormCount: 0,
        );
      }
      return p;
    }).toList();

    _state =
        _state.copyWith(players: updatedPlayers, sequenceNumber: newSequence);
    onStateChanged?.call(_state);
  }

  void _applyClaimTokenInternal({
    required String tokenType,
    required String claimantId,
    required int newSequence,
  }) {
    final isMonarch = tokenType.toLowerCase() == 'monarch';
    final isInit = tokenType.toLowerCase() == 'initiative';

    final updatedPlayers = _state.players.map((p) {
      if (p.id == claimantId) {
        return p.copyWith(
          isMonarch: isMonarch ? true : p.isMonarch,
          hasInitiative: isInit ? true : p.hasInitiative,
        );
      } else {
        return p.copyWith(
          isMonarch: isMonarch ? false : p.isMonarch,
          hasInitiative: isInit ? false : p.hasInitiative,
        );
      }
    }).toList();

    _state =
        _state.copyWith(players: updatedPlayers, sequenceNumber: newSequence);
    onStateChanged?.call(_state);
  }

  void _applyResetGameInternal(int startingLife, int newSequence) {
    final resetPlayers = _state.players.map((p) {
      return p.copyWith(
        life: startingLife,
        poison: 0,
        energy: 0,
        experience: 0,
        commanderTax: 0,
        isMonarch: false,
        hasInitiative: false,
        commanderDamageTaken: const {},
        floatingMana: const {'W': 0, 'U': 0, 'B': 0, 'R': 0, 'G': 0, 'C': 0},
        stormCount: 0,
        isEliminated: false,
      );
    }).toList();

    _state = _state.copyWith(
      startingLife: startingLife,
      players: resetPlayers,
      isDay: true,
      sequenceNumber: newSequence,
    );
    onStateChanged?.call(_state);
  }

  PodState _applyPendingActionToState(PodState base, PendingAction pending) {
    if (pending.type == P2pPacketType.dayNightToggle) {
      return base.copyWith(isDay: !base.isDay);
    }

    final targetId = pending.targetPlayerId;
    if (targetId == null) return base;

    if (pending.type == P2pPacketType.claimToken) {
      final tokenType = pending.payload['token_type'] as String?;
      if (tokenType == null) return base;
      final isMonarch = tokenType.toLowerCase() == 'monarch';
      final isInit = tokenType.toLowerCase() == 'initiative';

      final updatedPlayers = base.players.map((p) {
        if (p.id == targetId) {
          return p.copyWith(
            isMonarch: isMonarch ? true : p.isMonarch,
            hasInitiative: isInit ? true : p.hasInitiative,
          );
        } else {
          return p.copyWith(
            isMonarch: isMonarch ? false : p.isMonarch,
            hasInitiative: isInit ? false : p.hasInitiative,
          );
        }
      }).toList();

      return base.copyWith(players: updatedPlayers);
    }

    final updatedPlayers = base.players.map((p) {
      if (p.id == targetId) {
        switch (pending.type) {
          case P2pPacketType.lifeDelta:
            final newLife = p.life + pending.delta;
            final isCmdLethal =
                p.commanderDamageTaken.values.any((d) => d >= 21);
            final isEliminated = newLife <= 0 || p.poison >= 10 || isCmdLethal;
            return p.copyWith(life: newLife, isEliminated: isEliminated);

          case P2pPacketType.commanderDamage:
            final sourceId = pending.payload['source_player_id'] as String?;
            if (sourceId != null) {
              final cur = p.commanderDamageTaken[sourceId] ?? 0;
              final newMap = Map<String, int>.from(p.commanderDamageTaken);
              newMap[sourceId] = math.max(0, cur + pending.delta);
              final newLife = p.life - pending.delta;
              final isCmdLethal = newMap.values.any((d) => d >= 21);
              final isEliminated =
                  newLife <= 0 || p.poison >= 10 || isCmdLethal;
              return p.copyWith(
                life: newLife,
                commanderDamageTaken: newMap,
                isEliminated: isEliminated,
              );
            }
            break;

          case P2pPacketType.counterDelta:
            final cType = pending.payload['counter_type'] as String?;
            if (cType == 'poison') {
              final newPoison = math.max(0, p.poison + pending.delta);
              final isCmdLethal =
                  p.commanderDamageTaken.values.any((d) => d >= 21);
              final isEliminated =
                  p.life <= 0 || newPoison >= 10 || isCmdLethal;
              return p.copyWith(poison: newPoison, isEliminated: isEliminated);
            }
            if (cType == 'energy') {
              return p.copyWith(energy: math.max(0, p.energy + pending.delta));
            }
            if (cType == 'experience' || cType == 'xp') {
              return p.copyWith(
                  experience: math.max(0, p.experience + pending.delta));
            }
            if (cType == 'commander_tax') {
              return p.copyWith(
                  commanderTax: math.max(0, p.commanderTax + pending.delta));
            }
            break;

          case P2pPacketType.manaDelta:
            final color = pending.payload['color'] as String?;
            if (color != null) {
              final cur = p.floatingMana[color] ?? 0;
              final newPool = Map<String, int>.from(p.floatingMana);
              newPool[color] = math.max(0, cur + pending.delta);
              final newStorm =
                  pending.delta > 0 ? p.stormCount + 1 : p.stormCount;
              return p.copyWith(floatingMana: newPool, stormCount: newStorm);
            }
            break;

          case P2pPacketType.manaClear:
            return p.copyWith(
              floatingMana: const {
                'W': 0, 'U': 0, 'B': 0, 'R': 0, 'G': 0, 'C': 0
              },
              stormCount: 0,
            );

          default:
            break;
        }
      }
      return p;
    }).toList();

    return base.copyWith(players: updatedPlayers);
  }

  void _recordEventInLog(P2pPacket packet) {
    _eventLog.add(EventLogEntry(
      sequenceNumber: packet.sequenceNumber,
      packet: packet,
      timestamp: DateTime.now(),
    ));
    if (_eventLog.length > _maxEventLogSize) {
      _eventLog.removeRange(0, _eventLog.length - _maxEventLogSize);
    }
  }

  void _checkAndDrainOutOfOrderBuffer() {
    int nextExpected = _state.sequenceNumber + 1;
    while (_outOfOrderBuffer.containsKey(nextExpected)) {
      final buffered = _outOfOrderBuffer.remove(nextExpected)!;
      _handleIncomingPacket(buffered);
      nextExpected = _state.sequenceNumber + 1;
    }
  }

  /// Cleans up subscriptions and resources.
  void dispose() {
    _isDisposed = true;
    _packetSubscription?.cancel();
    _packetSubscription = null;
    _pendingActions.clear();
    _outOfOrderBuffer.clear();
  }
}
