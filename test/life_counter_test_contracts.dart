// Copyright (c) 2026 Countr. All rights reserved.
// Opaque-box contract interfaces, models, networking, persistence, and UI harnesses
// for Phase 4.7 "Variant 1" Lifetap MTG Life Counter.
// Derived strictly from PROJECT.md § Interface Contracts & ORIGINAL_REQUEST.md.

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';

// =============================================================================
// 1. DOMAIN MODELS & ENUMS
// =============================================================================

enum MatchFormat {
  commander('commander', 40, 'Commander / EDH'),
  standard('standard', 20, 'Standard (60-Card)'),
  brawl('brawl', 30, 'Brawl'),
  draft('draft', 20, 'Limited / Draft'),
  custom('custom', 40, 'Custom');

  final String id;
  final int defaultStartingLife;
  final String label;

  const MatchFormat(this.id, this.defaultStartingLife, this.label);

  static MatchFormat fromId(String? id) {
    if (id == null) return MatchFormat.commander;
    return MatchFormat.values.firstWhere(
      (f) => f.id.toLowerCase() == id.toLowerCase(),
      orElse: () => MatchFormat.commander,
    );
  }
}

/// Immutable state of an individual player in the pod.
class PodPlayerState {
  final String id;
  final int seatIndex;
  final String name;
  final String? deckId;
  final String? commanderCardId;
  final String? commanderName;
  final String? commanderArtCropUrl;
  final int life;
  final int poison;
  final int energy;
  final int experience;
  final int commanderTax;
  final bool isMonarch;
  final bool hasInitiative;
  final Map<String, int> commanderDamageTaken; // opponentPlayerId -> damage
  final Map<String, int> floatingMana; // 'W', 'U', 'B', 'R', 'G', 'C'
  final int stormCount;
  final bool isEliminated;

  const PodPlayerState({
    required this.id,
    required this.seatIndex,
    required this.name,
    this.deckId,
    this.commanderCardId,
    this.commanderName,
    this.commanderArtCropUrl,
    required this.life,
    this.poison = 0,
    this.energy = 0,
    this.experience = 0,
    this.commanderTax = 0,
    this.isMonarch = false,
    this.hasInitiative = false,
    this.commanderDamageTaken = const {},
    this.floatingMana = const {'W': 0, 'U': 0, 'B': 0, 'R': 0, 'G': 0, 'C': 0},
    this.stormCount = 0,
    this.isEliminated = false,
  });

  bool get isPoisonLethal => poison >= 10;

  bool isCommanderDamageLethalFrom(String opponentId) =>
      (commanderDamageTaken[opponentId] ?? 0) >= 21;

  bool get hasAnyLethalCommanderDamage =>
      commanderDamageTaken.values.any((dmg) => dmg >= 21);

  bool get isLethal => life <= 0 || isPoisonLethal || hasAnyLethalCommanderDamage;

  PodPlayerState copyWith({
    String? id,
    int? seatIndex,
    String? name,
    String? deckId,
    String? commanderCardId,
    String? commanderName,
    String? commanderArtCropUrl,
    int? life,
    int? poison,
    int? energy,
    int? experience,
    int? commanderTax,
    bool? isMonarch,
    bool? hasInitiative,
    Map<String, int>? commanderDamageTaken,
    Map<String, int>? floatingMana,
    int? stormCount,
    bool? isEliminated,
  }) {
    return PodPlayerState(
      id: id ?? this.id,
      seatIndex: seatIndex ?? this.seatIndex,
      name: name ?? this.name,
      deckId: deckId ?? this.deckId,
      commanderCardId: commanderCardId ?? this.commanderCardId,
      commanderName: commanderName ?? this.commanderName,
      commanderArtCropUrl: commanderArtCropUrl ?? this.commanderArtCropUrl,
      life: life ?? this.life,
      poison: poison ?? this.poison,
      energy: energy ?? this.energy,
      experience: experience ?? this.experience,
      commanderTax: commanderTax ?? this.commanderTax,
      isMonarch: isMonarch ?? this.isMonarch,
      hasInitiative: hasInitiative ?? this.hasInitiative,
      commanderDamageTaken: commanderDamageTaken ?? Map.from(this.commanderDamageTaken),
      floatingMana: floatingMana ?? Map.from(this.floatingMana),
      stormCount: stormCount ?? this.stormCount,
      isEliminated: isEliminated ?? this.isEliminated,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'seat_index': seatIndex,
        'name': name,
        'deck_id': deckId,
        'commander_card_id': commanderCardId,
        'commander_name': commanderName,
        'commander_art_crop_url': commanderArtCropUrl,
        'life': life,
        'poison': poison,
        'energy': energy,
        'experience': experience,
        'commander_tax': commanderTax,
        'is_monarch': isMonarch,
        'has_initiative': hasInitiative,
        'commander_damage_taken': commanderDamageTaken,
        'floating_mana': floatingMana,
        'storm_count': stormCount,
        'is_eliminated': isEliminated,
      };

  factory PodPlayerState.fromJson(Map<String, dynamic> json) {
    return PodPlayerState(
      id: json['id'] as String,
      seatIndex: json['seat_index'] as int,
      name: json['name'] as String,
      deckId: json['deck_id'] as String?,
      commanderCardId: json['commander_card_id'] as String?,
      commanderName: json['commander_name'] as String?,
      commanderArtCropUrl: json['commander_art_crop_url'] as String?,
      life: json['life'] as int,
      poison: json['poison'] as int? ?? 0,
      energy: json['energy'] as int? ?? 0,
      experience: json['experience'] as int? ?? 0,
      commanderTax: json['commander_tax'] as int? ?? 0,
      isMonarch: json['is_monarch'] as bool? ?? false,
      hasInitiative: json['has_initiative'] as bool? ?? false,
      commanderDamageTaken: Map<String, int>.from(
          json['commander_damage_taken'] as Map? ?? {}),
      floatingMana: Map<String, int>.from(
          json['floating_mana'] as Map? ?? {'W': 0, 'U': 0, 'B': 0, 'R': 0, 'G': 0, 'C': 0}),
      stormCount: json['storm_count'] as int? ?? 0,
      isEliminated: json['is_eliminated'] as bool? ?? false,
    );
  }
}

/// Full game state of the pod.
class PodState {
  final String sessionId;
  final String format;
  final int startingLife;
  final List<PodPlayerState> players;
  final bool isDay;
  final bool isP2pHost;
  final String? roomCode;
  final int sequenceNumber;

  const PodState({
    required this.sessionId,
    required this.format,
    required this.startingLife,
    required this.players,
    this.isDay = true,
    this.isP2pHost = true,
    this.roomCode,
    this.sequenceNumber = 0,
  });

  int get playerCount => players.length;

  PodPlayerState? getPlayer(String id) {
    for (final p in players) {
      if (p.id == id) return p;
    }
    return null;
  }

  PodPlayerState? getPlayerBySeat(int seatIndex) {
    for (final p in players) {
      if (p.seatIndex == seatIndex) return p;
    }
    return null;
  }

  PodState copyWith({
    String? sessionId,
    String? format,
    int? startingLife,
    List<PodPlayerState>? players,
    bool? isDay,
    bool? isP2pHost,
    String? roomCode,
    int? sequenceNumber,
  }) {
    return PodState(
      sessionId: sessionId ?? this.sessionId,
      format: format ?? this.format,
      startingLife: startingLife ?? this.startingLife,
      players: players ?? List.from(this.players),
      isDay: isDay ?? this.isDay,
      isP2pHost: isP2pHost ?? this.isP2pHost,
      roomCode: roomCode ?? this.roomCode,
      sequenceNumber: sequenceNumber ?? this.sequenceNumber,
    );
  }

  Map<String, dynamic> toJson() => {
        'session_id': sessionId,
        'format': format,
        'starting_life': startingLife,
        'players': players.map((p) => p.toJson()).toList(),
        'is_day': isDay,
        'is_p2p_host': isP2pHost,
        'room_code': roomCode,
        'sequence_number': sequenceNumber,
      };

  factory PodState.fromJson(Map<String, dynamic> json) {
    return PodState(
      sessionId: json['session_id'] as String,
      format: json['format'] as String,
      startingLife: json['starting_life'] as int,
      players: (json['players'] as List)
          .map((p) => PodPlayerState.fromJson(p as Map<String, dynamic>))
          .toList(),
      isDay: json['is_day'] as bool? ?? true,
      isP2pHost: json['is_p2p_host'] as bool? ?? true,
      roomCode: json['room_code'] as String?,
      sequenceNumber: json['sequence_number'] as int? ?? 0,
    );
  }
}

// =============================================================================
// 2. PERSISTENCE & MATCH DAO CONTRACT
// =============================================================================

class MatchEventRecord {
  final int? id;
  final String sessionId;
  final String eventType;
  final int sequenceNumber;
  final String? targetPlayerId;
  final String? sourcePlayerId;
  final int delta;
  final int value;
  final Map<String, dynamic>? payload;
  final DateTime timestamp;

  MatchEventRecord({
    this.id,
    required this.sessionId,
    required this.eventType,
    required this.sequenceNumber,
    this.targetPlayerId,
    this.sourcePlayerId,
    this.delta = 0,
    this.value = 0,
    this.payload,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'session_id': sessionId,
        'event_type': eventType,
        'sequence_number': sequenceNumber,
        'target_player_id': targetPlayerId,
        'source_player_id': sourcePlayerId,
        'delta': delta,
        'value': value,
        'payload': payload,
        'timestamp': timestamp.toIso8601String(),
      };
}

abstract class MatchDaoInterface {
  Future<String> createSession({
    required String format,
    required int startingLife,
    required int playerCount,
    required List<PodPlayerState> players,
    bool isP2pHost = false,
    String? p2pSessionCode,
  });

  Stream<PodState?> watchActiveSession();
  Future<PodState?> getActiveSession();
  Stream<List<PodPlayerState>> watchPlayersForSession(String sessionId);
  Future<List<PodPlayerState>> getPlayersForSession(String sessionId);

  Future<void> recordEvent({
    required String sessionId,
    required String eventType,
    required int sequenceNumber,
    String? targetPlayerId,
    String? sourcePlayerId,
    int delta = 0,
    int value = 0,
    Map<String, dynamic>? payload,
  });

  Future<void> updatePlayerLife(String playerId, int newLife);
  Future<void> updatePlayerCounter(String playerId, String counterType, int newValue);
  Future<void> completeSession(String sessionId);
  Future<void> abandonSession(String sessionId);
  Future<void> resetSession(String sessionId, int startingLife);
}

/// In-memory reactive implementation of MatchDaoInterface for reliable unit & E2E tests.
class MockMatchDao implements MatchDaoInterface {
  PodState? _activeSession;
  final List<MatchEventRecord> _eventLog = [];
  final StreamController<PodState?> _sessionController =
      StreamController<PodState?>.broadcast();
  final StreamController<List<PodPlayerState>> _playersController =
      StreamController<List<PodPlayerState>>.broadcast();

  List<MatchEventRecord> get eventLog => List.unmodifiable(_eventLog);

  @override
  Future<String> createSession({
    required String format,
    required int startingLife,
    required int playerCount,
    required List<PodPlayerState> players,
    bool isP2pHost = false,
    String? p2pSessionCode,
  }) async {
    final sessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
    _activeSession = PodState(
      sessionId: sessionId,
      format: format,
      startingLife: startingLife,
      players: players,
      isP2pHost: isP2pHost,
      roomCode: p2pSessionCode,
      sequenceNumber: 0,
    );
    _sessionController.add(_activeSession);
    _playersController.add(players);
    return sessionId;
  }

  @override
  Future<PodState?> getActiveSession() async => _activeSession;

  @override
  Stream<PodState?> watchActiveSession() => _sessionController.stream;

  @override
  Future<List<PodPlayerState>> getPlayersForSession(String sessionId) async {
    if (_activeSession?.sessionId == sessionId) {
      return _activeSession!.players;
    }
    return [];
  }

  @override
  Stream<List<PodPlayerState>> watchPlayersForSession(String sessionId) =>
      _playersController.stream;

  @override
  Future<void> recordEvent({
    required String sessionId,
    required String eventType,
    required int sequenceNumber,
    String? targetPlayerId,
    String? sourcePlayerId,
    int delta = 0,
    int value = 0,
    Map<String, dynamic>? payload,
  }) async {
    final record = MatchEventRecord(
      id: _eventLog.length + 1,
      sessionId: sessionId,
      eventType: eventType,
      sequenceNumber: sequenceNumber,
      targetPlayerId: targetPlayerId,
      sourcePlayerId: sourcePlayerId,
      delta: delta,
      value: value,
      payload: payload,
    );
    _eventLog.add(record);
  }

  @override
  Future<void> updatePlayerLife(String playerId, int newLife) async {
    if (_activeSession == null) return;
    final updatedPlayers = _activeSession!.players.map((p) {
      if (p.id == playerId) {
        return p.copyWith(life: newLife);
      }
      return p;
    }).toList();
    _activeSession = _activeSession!.copyWith(
      players: updatedPlayers,
      sequenceNumber: _activeSession!.sequenceNumber + 1,
    );
    _sessionController.add(_activeSession);
    _playersController.add(updatedPlayers);
  }

  @override
  Future<void> updatePlayerCounter(
      String playerId, String counterType, int newValue) async {
    if (_activeSession == null) return;
    final updatedPlayers = _activeSession!.players.map((p) {
      if (p.id == playerId) {
        switch (counterType.toLowerCase()) {
          case 'poison':
            return p.copyWith(poison: newValue);
          case 'energy':
            return p.copyWith(energy: newValue);
          case 'experience':
          case 'xp':
            return p.copyWith(experience: newValue);
          case 'commander_tax':
            return p.copyWith(commanderTax: newValue);
          default:
            return p;
        }
      }
      return p;
    }).toList();
    _activeSession = _activeSession!.copyWith(
      players: updatedPlayers,
      sequenceNumber: _activeSession!.sequenceNumber + 1,
    );
    _sessionController.add(_activeSession);
    _playersController.add(updatedPlayers);
  }

  @override
  Future<void> completeSession(String sessionId) async {
    if (_activeSession?.sessionId == sessionId) {
      _activeSession = null;
      _sessionController.add(null);
      _playersController.add([]);
    }
  }

  @override
  Future<void> abandonSession(String sessionId) async {
    await completeSession(sessionId);
  }

  @override
  Future<void> resetSession(String sessionId, int startingLife) async {
    if (_activeSession?.sessionId == sessionId) {
      final resetPlayers = _activeSession!.players.map((p) {
        return p.copyWith(
          life: startingLife,
          poison: 0,
          energy: 0,
          experience: 0,
          commanderTax: 0,
          isMonarch: false,
          hasInitiative: false,
          commanderDamageTaken: {},
          floatingMana: {'W': 0, 'U': 0, 'B': 0, 'R': 0, 'G': 0, 'C': 0},
          stormCount: 0,
          isEliminated: false,
        );
      }).toList();
      _activeSession = _activeSession!.copyWith(
        startingLife: startingLife,
        players: resetPlayers,
        isDay: true,
        sequenceNumber: _activeSession!.sequenceNumber + 1,
      );
      _sessionController.add(_activeSession);
      _playersController.add(resetPlayers);
    }
  }

  void dispose() {
    _sessionController.close();
    _playersController.close();
  }
}

// =============================================================================
// 3. P2P NETWORKING, PACKET SCHEMAS & IN-MEMORY MESH
// =============================================================================

enum P2pPacketType {
  handshakeRequest('handshake_request'),
  handshakeResponse('handshake_response'),
  syncState('sync_state'),
  lifeDelta('life_delta'),
  commanderDamage('commander_damage'),
  counterDelta('counter_delta'),
  manaDelta('mana_delta'),
  manaClear('mana_clear'),
  dayNightToggle('day_night_toggle'),
  claimToken('claim_token'),
  resetGame('reset_game'),
  heartbeat('heartbeat');

  final String wireName;
  const P2pPacketType(this.wireName);

  static P2pPacketType fromWireName(String name) {
    return P2pPacketType.values.firstWhere(
      (t) => t.wireName == name,
      orElse: () => P2pPacketType.heartbeat,
    );
  }
}

class P2pPacket {
  final P2pPacketType type;
  final String senderId;
  final int sequenceNumber;
  final String? targetPlayerId;
  final int delta;
  final int value;
  final Map<String, dynamic> payload;
  final int timestamp;

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

  factory P2pPacket.fromJson(Map<String, dynamic> json) {
    return P2pPacket(
      type: P2pPacketType.fromWireName(json['type'] as String),
      senderId: json['sender_id'] as String,
      sequenceNumber: json['sequence_number'] as int? ?? 0,
      targetPlayerId: json['target_player_id'] as String?,
      delta: json['delta'] as int? ?? 0,
      value: json['value'] as int? ?? 0,
      payload: Map<String, dynamic>.from(json['payload'] as Map? ?? {}),
      timestamp: json['timestamp'] as int? ?? 0,
    );
  }

  String encode() => jsonEncode(toJson());

  static P2pPacket decode(String raw) =>
      P2pPacket.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

abstract class P2pTransport {
  Stream<P2pPacket> get incomingPackets;
  Future<void> sendPacket(P2pPacket packet);
  Future<void> broadcastPacket(P2pPacket packet);
  Future<void> disconnect();
  bool get isConnected;
  String get endpointId;
}

/// In-memory mesh enabling fully headless, deterministic P2P network testing.
class InMemoryP2pMesh {
  final Map<String, InMemoryP2pTransport> _nodes = {};

  InMemoryP2pTransport createNode(String endpointId) {
    final node = InMemoryP2pTransport(endpointId, this);
    _nodes[endpointId] = node;
    return node;
  }

  void _routePacket(P2pPacket packet, String fromEndpoint) {
    for (final entry in _nodes.entries) {
      if (entry.key != fromEndpoint && entry.value.isConnected) {
        entry.value._receivePacket(packet);
      }
    }
  }

  void _removeNode(String endpointId) {
    _nodes.remove(endpointId);
  }
}

class InMemoryP2pTransport implements P2pTransport {
  @override
  final String endpointId;
  final InMemoryP2pMesh _mesh;
  final StreamController<P2pPacket> _incomingController =
      StreamController<P2pPacket>.broadcast();
  bool _connected = true;

  InMemoryP2pTransport(this.endpointId, this._mesh);

  @override
  bool get isConnected => _connected;

  @override
  Stream<P2pPacket> get incomingPackets => _incomingController.stream;

  @override
  Future<void> sendPacket(P2pPacket packet) async {
    if (!_connected) throw StateError('Transport is disconnected');
    _mesh._routePacket(packet, endpointId);
  }

  @override
  Future<void> broadcastPacket(P2pPacket packet) async {
    await sendPacket(packet);
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    _mesh._removeNode(endpointId);
  }

  void reconnect() {
    _connected = true;
    _mesh._nodes[endpointId] = this;
  }

  void dispose() {
    _incomingController.close();
  }

  void _receivePacket(P2pPacket packet) {
    if (_connected && !_incomingController.isClosed) {
      _incomingController.add(packet);
    }
  }
}

/// Event Sourcing engine for P2P state synchronization.
class P2pSyncEngine {
  PodState _state;
  final P2pTransport transport;
  final bool isHost;
  final void Function(PodState newState)? onStateChanged;

  P2pSyncEngine({
    required PodState initialState,
    required this.transport,
    required this.isHost,
    this.onStateChanged,
  }) : _state = initialState {
    transport.incomingPackets.listen(_handleIncomingPacket);
  }

  PodState get state => _state;

  void _handleIncomingPacket(P2pPacket packet) {
    switch (packet.type) {
      case P2pPacketType.syncState:
        if (!isHost) {
          _state = PodState.fromJson(packet.payload['state'] as Map<String, dynamic>);
          onStateChanged?.call(_state);
        }
        break;

      case P2pPacketType.lifeDelta:
        _applyLifeDelta(packet.targetPlayerId!, packet.delta, packet.sequenceNumber);
        if (isHost) {
          transport.broadcastPacket(P2pPacket(
            type: P2pPacketType.lifeDelta,
            senderId: transport.endpointId,
            sequenceNumber: _state.sequenceNumber,
            targetPlayerId: packet.targetPlayerId,
            delta: packet.delta,
          ));
        }
        break;

      case P2pPacketType.commanderDamage:
        _applyCommanderDamage(
          targetPlayerId: packet.targetPlayerId!,
          sourcePlayerId: packet.payload['source_player_id'] as String,
          damageDelta: packet.delta,
          newSequence: packet.sequenceNumber,
        );
        if (isHost) {
          transport.broadcastPacket(packet);
        }
        break;

      case P2pPacketType.counterDelta:
        _applyCounterDelta(
          targetPlayerId: packet.targetPlayerId!,
          counterType: packet.payload['counter_type'] as String,
          delta: packet.delta,
          newSequence: packet.sequenceNumber,
        );
        if (isHost) transport.broadcastPacket(packet);
        break;

      case P2pPacketType.manaDelta:
        _applyManaDelta(
          targetPlayerId: packet.targetPlayerId!,
          color: packet.payload['color'] as String,
          delta: packet.delta,
        );
        if (isHost) transport.broadcastPacket(packet);
        break;

      case P2pPacketType.manaClear:
        _applyManaClear(packet.targetPlayerId!);
        if (isHost) transport.broadcastPacket(packet);
        break;

      case P2pPacketType.dayNightToggle:
        _state = _state.copyWith(
          isDay: !_state.isDay,
          sequenceNumber: isHost ? _state.sequenceNumber + 1 : packet.sequenceNumber,
        );
        onStateChanged?.call(_state);
        if (isHost) transport.broadcastPacket(packet);
        break;

      case P2pPacketType.claimToken:
        _applyClaimToken(
          tokenType: packet.payload['token_type'] as String,
          claimantId: packet.targetPlayerId!,
        );
        if (isHost) transport.broadcastPacket(packet);
        break;

      case P2pPacketType.resetGame:
        _applyResetGame(packet.value > 0 ? packet.value : _state.startingLife);
        if (isHost) transport.broadcastPacket(packet);
        break;

      default:
        break;
    }
  }

  void _applyLifeDelta(String playerId, int delta, int sequence) {
    final nextSeq = isHost ? _state.sequenceNumber + 1 : sequence;
    final updatedPlayers = _state.players.map((p) {
      if (p.id == playerId) {
        return p.copyWith(life: p.life + delta);
      }
      return p;
    }).toList();

    _state = _state.copyWith(players: updatedPlayers, sequenceNumber: nextSeq);
    onStateChanged?.call(_state);
  }

  void _applyCommanderDamage({
    required String targetPlayerId,
    required String sourcePlayerId,
    required int damageDelta,
    required int newSequence,
  }) {
    final nextSeq = isHost ? _state.sequenceNumber + 1 : newSequence;
    final updatedPlayers = _state.players.map((p) {
      if (p.id == targetPlayerId) {
        final currentDmg = p.commanderDamageTaken[sourcePlayerId] ?? 0;
        final newDmg = max(0, currentDmg + damageDelta);
        final newMap = Map<String, int>.from(p.commanderDamageTaken);
        newMap[sourcePlayerId] = newDmg;
        return p.copyWith(
          life: p.life - damageDelta, // Commander damage automatically reduces life
          commanderDamageTaken: newMap,
        );
      }
      return p;
    }).toList();

    _state = _state.copyWith(players: updatedPlayers, sequenceNumber: nextSeq);
    onStateChanged?.call(_state);
  }

  void _applyCounterDelta({
    required String targetPlayerId,
    required String counterType,
    required int delta,
    required int newSequence,
  }) {
    final nextSeq = isHost ? _state.sequenceNumber + 1 : newSequence;
    final updatedPlayers = _state.players.map((p) {
      if (p.id == targetPlayerId) {
        switch (counterType.toLowerCase()) {
          case 'poison':
            return p.copyWith(poison: max(0, p.poison + delta));
          case 'energy':
            return p.copyWith(energy: max(0, p.energy + delta));
          case 'experience':
          case 'xp':
            return p.copyWith(experience: max(0, p.experience + delta));
          case 'commander_tax':
            return p.copyWith(commanderTax: max(0, p.commanderTax + delta));
        }
      }
      return p;
    }).toList();

    _state = _state.copyWith(players: updatedPlayers, sequenceNumber: nextSeq);
    onStateChanged?.call(_state);
  }

  void _applyManaDelta({
    required String targetPlayerId,
    required String color,
    required int delta,
  }) {
    final updatedPlayers = _state.players.map((p) {
      if (p.id == targetPlayerId) {
        final current = p.floatingMana[color] ?? 0;
        final newPool = Map<String, int>.from(p.floatingMana);
        newPool[color] = max(0, current + delta);
        final newStorm = delta > 0 ? p.stormCount + 1 : p.stormCount;
        return p.copyWith(floatingMana: newPool, stormCount: newStorm);
      }
      return p;
    }).toList();

    _state = _state.copyWith(players: updatedPlayers);
    onStateChanged?.call(_state);
  }

  void _applyManaClear(String targetPlayerId) {
    final updatedPlayers = _state.players.map((p) {
      if (p.id == targetPlayerId) {
        return p.copyWith(
          floatingMana: {'W': 0, 'U': 0, 'B': 0, 'R': 0, 'G': 0, 'C': 0},
          stormCount: 0,
        );
      }
      return p;
    }).toList();

    _state = _state.copyWith(players: updatedPlayers);
    onStateChanged?.call(_state);
  }

  void _applyClaimToken({required String tokenType, required String claimantId}) {
    final isMonarch = tokenType == 'monarch';
    final isInit = tokenType == 'initiative';

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

    _state = _state.copyWith(players: updatedPlayers);
    onStateChanged?.call(_state);
  }

  void _applyResetGame(int startingLife) {
    final resetPlayers = _state.players.map((p) {
      return p.copyWith(
        life: startingLife,
        poison: 0,
        energy: 0,
        experience: 0,
        commanderTax: 0,
        isMonarch: false,
        hasInitiative: false,
        commanderDamageTaken: {},
        floatingMana: {'W': 0, 'U': 0, 'B': 0, 'R': 0, 'G': 0, 'C': 0},
        stormCount: 0,
        isEliminated: false,
      );
    }).toList();

    _state = _state.copyWith(
      startingLife: startingLife,
      players: resetPlayers,
      isDay: true,
      sequenceNumber: isHost ? _state.sequenceNumber + 1 : _state.sequenceNumber,
    );
    onStateChanged?.call(_state);
  }

  Future<void> sendLifeAdjustment(String playerId, int delta) async {
    final packet = P2pPacket(
      type: P2pPacketType.lifeDelta,
      senderId: transport.endpointId,
      sequenceNumber: _state.sequenceNumber + 1,
      targetPlayerId: playerId,
      delta: delta,
    );
    if (isHost) {
      _applyLifeDelta(playerId, delta, packet.sequenceNumber);
      await transport.broadcastPacket(packet);
    } else {
      await transport.sendPacket(packet);
    }
  }

  Future<void> sendCommanderDamage({
    required String targetPlayerId,
    required String sourcePlayerId,
    required int damageDelta,
  }) async {
    final packet = P2pPacket(
      type: P2pPacketType.commanderDamage,
      senderId: transport.endpointId,
      sequenceNumber: _state.sequenceNumber + 1,
      targetPlayerId: targetPlayerId,
      delta: damageDelta,
      payload: {'source_player_id': sourcePlayerId},
    );
    if (isHost) {
      _applyCommanderDamage(
        targetPlayerId: targetPlayerId,
        sourcePlayerId: sourcePlayerId,
        damageDelta: damageDelta,
        newSequence: packet.sequenceNumber,
      );
      await transport.broadcastPacket(packet);
    } else {
      await transport.sendPacket(packet);
    }
  }

  Future<void> claimToken({required String tokenType, required String claimantId}) async {
    final packet = P2pPacket(
      type: P2pPacketType.claimToken,
      senderId: transport.endpointId,
      sequenceNumber: _state.sequenceNumber + 1,
      targetPlayerId: claimantId,
      payload: {'token_type': tokenType},
    );
    if (isHost) {
      _applyClaimToken(tokenType: tokenType, claimantId: claimantId);
      await transport.broadcastPacket(packet);
    } else {
      await transport.sendPacket(packet);
    }
  }
}

// =============================================================================
// 4. RANDOMIZER ENGINE
// =============================================================================

enum DiceType {
  d4(4, 'D4'),
  d6(6, 'D6'),
  d8(8, 'D8'),
  d10(10, 'D10'),
  d12(12, 'D12'),
  d20(20, 'D20'),
  d100(100, 'D100');

  final int sides;
  final String label;
  const DiceType(this.sides, this.label);
}

enum CoinSide { heads, tails }

class RandomizerService {
  final Random _random;

  RandomizerService([Random? random]) : _random = random ?? Random();

  CoinSide flipCoin() {
    return _random.nextBool() ? CoinSide.heads : CoinSide.tails;
  }

  int rollDice(DiceType type) {
    return _random.nextInt(type.sides) + 1;
  }

  int selectRandomPlayerIndex(int activePlayerCount) {
    if (activePlayerCount <= 0) return 0;
    return _random.nextInt(activePlayerCount);
  }

  int selectRandomOpponentIndex(int activePlayerCount, int selfSeatIndex) {
    if (activePlayerCount <= 1) return selfSeatIndex;
    int picked = _random.nextInt(activePlayerCount - 1);
    if (picked >= selfSeatIndex) picked++;
    return picked;
  }
}

// =============================================================================
// 5. TEST HARNESS WIDGETS (OPAQUE-BOX UI CONTRACT HARNESSES)
// =============================================================================

/// Dynamic responsive pod screen rendering layouts (1v1, 3P, 4P, 5P, 6P)
/// and switching between Phone (drawers) and Tablet (perpetual rails).
class PodScaffoldWidget extends StatefulWidget {
  final PodState podState;
  final void Function(String playerId, int delta)? onLifeDelta;
  final void Function(String targetId, String sourceId, int delta)? onCommanderDamage;
  final void Function(String playerId, String color, int delta)? onManaDelta;
  final void Function(String playerId)? onManaClear;
  final void Function(String playerId, String counterType, int delta)? onCounterDelta;
  final VoidCallback? onResetGame;
  final VoidCallback? onRandomizerPressed;
  final VoidCallback? onToggleDayNight;
  final void Function(String tokenType, String claimantId)? onClaimToken;

  const PodScaffoldWidget({
    super.key,
    required this.podState,
    this.onLifeDelta,
    this.onCommanderDamage,
    this.onManaDelta,
    this.onManaClear,
    this.onCounterDelta,
    this.onResetGame,
    this.onRandomizerPressed,
    this.onToggleDayNight,
    this.onClaimToken,
  });

  @override
  State<PodScaffoldWidget> createState() => _PodScaffoldWidgetState();
}

class _PodScaffoldWidgetState extends State<PodScaffoldWidget> {
  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isTablet = mediaQuery.size.shortestSide >= 600;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Grid layout
          _buildPodLayout(isTablet),

          // Central crossroads hub button
          Center(
            child: CenterHubButton(
              onPressed: widget.onRandomizerPressed,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPodLayout(bool isTablet) {
    final players = widget.podState.players;
    final count = players.length;

    switch (count) {
      case 2:
        return _build1v1Layout(players, isTablet);
      case 3:
        return _build3PlayerLayout(players, isTablet);
      case 4:
        return _build4PlayerLayout(players, isTablet);
      case 5:
        return _build5PlayerLayout(players, isTablet);
      case 6:
      default:
        return _build6PlayerLayout(players, isTablet);
    }
  }

  Widget _build1v1Layout(List<PodPlayerState> players, bool isTablet) {
    return Column(
      children: [
        Expanded(
          child: RotatedBox(
            quarterTurns: 2, // Opponent inverted
            child: _buildQuadrant(players[1], isTablet, isTopRow: true),
          ),
        ),
        const Divider(height: 2, color: Colors.white24),
        Expanded(
          child: _buildQuadrant(players[0], isTablet, isTopRow: false),
        ),
      ],
    );
  }

  Widget _build3PlayerLayout(List<PodPlayerState> players, bool isTablet) {
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: RotatedBox(
                  quarterTurns: 2,
                  child: _buildQuadrant(players[1], isTablet, isTopRow: true),
                ),
              ),
              const VerticalDivider(width: 2, color: Colors.white24),
              Expanded(
                child: RotatedBox(
                  quarterTurns: 2,
                  child: _buildQuadrant(players[2], isTablet, isTopRow: true),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 2, color: Colors.white24),
        Expanded(
          child: _buildQuadrant(players[0], isTablet, isTopRow: false),
        ),
      ],
    );
  }

  Widget _build4PlayerLayout(List<PodPlayerState> players, bool isTablet) {
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: RotatedBox(
                  quarterTurns: 2,
                  child: _buildQuadrant(players[1], isTablet, isTopRow: true),
                ),
              ),
              const VerticalDivider(width: 2, color: Colors.white24),
              Expanded(
                child: RotatedBox(
                  quarterTurns: 2,
                  child: _buildQuadrant(players[2], isTablet, isTopRow: true),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 2, color: Colors.white24),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: _buildQuadrant(players[0], isTablet, isTopRow: false),
              ),
              const VerticalDivider(width: 2, color: Colors.white24),
              Expanded(
                child: _buildQuadrant(players[3], isTablet, isTopRow: false),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _build5PlayerLayout(List<PodPlayerState> players, bool isTablet) {
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: RotatedBox(
                  quarterTurns: 2,
                  child: _buildQuadrant(players[1], isTablet, isTopRow: true),
                ),
              ),
              const VerticalDivider(width: 2, color: Colors.white24),
              Expanded(
                child: RotatedBox(
                  quarterTurns: 2,
                  child: _buildQuadrant(players[2], isTablet, isTopRow: true),
                ),
              ),
              const VerticalDivider(width: 2, color: Colors.white24),
              Expanded(
                child: RotatedBox(
                  quarterTurns: 2,
                  child: _buildQuadrant(players[3], isTablet, isTopRow: true),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 2, color: Colors.white24),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: _buildQuadrant(players[0], isTablet, isTopRow: false),
              ),
              const VerticalDivider(width: 2, color: Colors.white24),
              Expanded(
                child: _buildQuadrant(players[4], isTablet, isTopRow: false),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _build6PlayerLayout(List<PodPlayerState> players, bool isTablet) {
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: RotatedBox(
                  quarterTurns: 2,
                  child: _buildQuadrant(players[1], isTablet, isTopRow: true),
                ),
              ),
              const VerticalDivider(width: 2, color: Colors.white24),
              Expanded(
                child: RotatedBox(
                  quarterTurns: 2,
                  child: _buildQuadrant(players[2], isTablet, isTopRow: true),
                ),
              ),
              const VerticalDivider(width: 2, color: Colors.white24),
              Expanded(
                child: RotatedBox(
                  quarterTurns: 2,
                  child: _buildQuadrant(players[3], isTablet, isTopRow: true),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 2, color: Colors.white24),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: _buildQuadrant(players[0], isTablet, isTopRow: false),
              ),
              const VerticalDivider(width: 2, color: Colors.white24),
              Expanded(
                child: _buildQuadrant(players[4], isTablet, isTopRow: false),
              ),
              const VerticalDivider(width: 2, color: Colors.white24),
              Expanded(
                child: _buildQuadrant(players[5], isTablet, isTopRow: false),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuadrant(PodPlayerState player, bool isTablet, {required bool isTopRow}) {
    return PlayerQuadrantWidget(
      key: Key('quadrant_${player.id}'),
      player: player,
      isTablet: isTablet,
      opponents: widget.podState.players.where((p) => p.id != player.id).toList(),
      onLifeDelta: (delta) => widget.onLifeDelta?.call(player.id, delta),
      onCommanderDamage: (oppId, delta) =>
          widget.onCommanderDamage?.call(player.id, oppId, delta),
      onManaDelta: (color, delta) => widget.onManaDelta?.call(player.id, color, delta),
      onManaClear: () => widget.onManaClear?.call(player.id),
      onCounterDelta: (counter, delta) =>
          widget.onCounterDelta?.call(player.id, counter, delta),
      onClaimMonarch: () => widget.onClaimToken?.call('monarch', player.id),
      onClaimInitiative: () => widget.onClaimToken?.call('initiative', player.id),
    );
  }
}

/// Player quadrant displaying commander art backdrop, massive life display,
/// touch zones, transient delta indicator, commander damage matrix, secondary counters,
/// and floating mana drawer.
class PlayerQuadrantWidget extends StatefulWidget {
  final PodPlayerState player;
  final bool isTablet;
  final List<PodPlayerState> opponents;
  final void Function(int delta)? onLifeDelta;
  final void Function(String opponentId, int delta)? onCommanderDamage;
  final void Function(String color, int delta)? onManaDelta;
  final VoidCallback? onManaClear;
  final void Function(String counterType, int delta)? onCounterDelta;
  final VoidCallback? onClaimMonarch;
  final VoidCallback? onClaimInitiative;

  const PlayerQuadrantWidget({
    super.key,
    required this.player,
    required this.isTablet,
    required this.opponents,
    this.onLifeDelta,
    this.onCommanderDamage,
    this.onManaDelta,
    this.onManaClear,
    this.onCounterDelta,
    this.onClaimMonarch,
    this.onClaimInitiative,
  });

  @override
  State<PlayerQuadrantWidget> createState() => _PlayerQuadrantWidgetState();
}

class _PlayerQuadrantWidgetState extends State<PlayerQuadrantWidget> {
  int _transientDelta = 0;
  Timer? _deltaFadeTimer;
  Timer? _accelerationTimer;
  bool _isDrawerOpen = false;

  void _handleLifeTap(int delta) {
    widget.onLifeDelta?.call(delta);
    setState(() {
      _transientDelta += delta;
    });
    _deltaFadeTimer?.cancel();
    _deltaFadeTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _transientDelta = 0;
        });
      }
    });
  }

  void _startAcceleration(int delta) {
    _handleLifeTap(delta);
    int step = 0;
    _accelerationTimer = Timer(const Duration(milliseconds: 350), () {
      void tick() {
        step++;
        final multiplier = step > 5 ? 5 : 1;
        _handleLifeTap(delta * multiplier);
        final nextDelay = step > 10
            ? 60
            : step > 5
                ? 80
                : 120;
        _accelerationTimer = Timer(Duration(milliseconds: nextDelay), tick);
      }

      tick();
    });
  }

  void _stopAcceleration() {
    _accelerationTimer?.cancel();
  }

  @override
  void dispose() {
    _deltaFadeTimer?.cancel();
    _accelerationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = widget.player;
    final isLethal = player.isLethal;

    return Container(
      decoration: BoxDecoration(
        color: isLethal ? Colors.red.shade900.withValues(alpha: 0.3) : const Color(0xFF1E1E2C),
        border: player.hasAnyLethalCommanderDamage
            ? Border.all(color: Colors.redAccent, width: 3)
            : null,
      ),
      child: Stack(
        children: [
          // Commander Art Backdrop with gradient vignette
          if (player.commanderArtCropUrl != null)
            Opacity(
              opacity: 0.30,
              child: Image.network(
                player.commanderArtCropUrl!,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (_, _, _) => Container(color: Colors.transparent),
              ),
            ),

          // Player Header Bar
          Positioned(
            top: 8,
            left: 12,
            right: 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    player.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                Wrap(
                  spacing: 4,
                  children: [
                    if (player.isMonarch)
                      const Chip(
                        label: Text('👑 Monarch', style: TextStyle(fontSize: 10)),
                        backgroundColor: Colors.amber,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: EdgeInsets.zero,
                      ),
                    if (player.hasInitiative)
                      const Chip(
                        label: Text('🗡 Initiative', style: TextStyle(fontSize: 10)),
                        backgroundColor: Colors.lightBlue,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: EdgeInsets.zero,
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Massive Life Display + Split Hitboxes
          Positioned.fill(
            child: Row(
              children: [
                // Left Hitbox: Decrement Life (-1)
                Expanded(
                  child: GestureDetector(
                    key: Key('hitbox_minus_${player.id}'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _handleLifeTap(-1),
                    onLongPressStart: (_) => _startAcceleration(-1),
                    onLongPressEnd: (_) => _stopAcceleration(),
                    child: Container(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(left: 16),
                      child: const Icon(Icons.remove, color: Colors.white24, size: 36),
                    ),
                  ),
                ),

                // Center: Big Life Total
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${player.life}',
                      key: Key('life_display_${player.id}'),
                      style: TextStyle(
                        fontSize: 64,
                        fontWeight: FontWeight.bold,
                        color: isLethal ? Colors.redAccent : Colors.white,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        shadows: const [
                          Shadow(
                            blurRadius: 10.0,
                            color: Colors.black,
                            offset: Offset(2.0, 2.0),
                          ),
                        ],
                      ),
                    ),

                    // Transient accumulating delta badge
                    if (_transientDelta != 0)
                      Container(
                        key: Key('delta_badge_${player.id}'),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _transientDelta > 0 ? Colors.green : Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _transientDelta > 0 ? '+$_transientDelta' : '$_transientDelta',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                  ],
                ),

                // Right Hitbox: Increment Life (+1)
                Expanded(
                  child: GestureDetector(
                    key: Key('hitbox_plus_${player.id}'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _handleLifeTap(1),
                    onLongPressStart: (_) => _startAcceleration(1),
                    onLongPressEnd: (_) => _stopAcceleration(),
                    child: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 16),
                      child: const Icon(Icons.add, color: Colors.white24, size: 36),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Secondary Trackers & Commander Damage
          if (widget.isTablet)
            // Perpetual Tool Rail for Tablets
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: _buildToolRail(player),
            )
          else
            // Pull-out drawer toggle button for Phones
            Positioned(
              bottom: 8,
              right: 8,
              child: IconButton(
                key: Key('drawer_toggle_${player.id}'),
                icon: Icon(
                  _isDrawerOpen ? Icons.close : Icons.tune,
                  color: Colors.white70,
                ),
                onPressed: () {
                  setState(() {
                    _isDrawerOpen = !_isDrawerOpen;
                  });
                },
              ),
            ),

          // Phone drawer overlay
          if (!widget.isTablet && _isDrawerOpen)
            Positioned(
              bottom: 48,
              left: 0,
              right: 0,
              child: Container(
                key: Key('drawer_panel_${player.id}'),
                padding: const EdgeInsets.all(8),
                color: Colors.black87,
                child: _buildToolRail(player),
              ),
            ),

          // 21 Commander Damage Lethal Banner
          if (player.hasAnyLethalCommanderDamage)
            Positioned(
              top: 36,
              left: 0,
              right: 0,
              child: Container(
                key: Key('commander_lethal_alert_${player.id}'),
                color: Colors.redAccent.withValues(alpha: 0.85),
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.warning, color: Colors.white, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'LETHAL COMMANDER DAMAGE (21+)',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 10 Poison Lethal Alert
          if (player.isPoisonLethal)
            Positioned(
              top: 56,
              left: 0,
              right: 0,
              child: Container(
                key: Key('poison_lethal_alert_${player.id}'),
                color: Colors.green.shade800.withValues(alpha: 0.85),
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.dangerous, color: Colors.white, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'LETHAL POISON (10+)',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildToolRail(PodPlayerState player) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Opponent Commander Damage Buttons
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: widget.opponents.map((opp) {
              final dmg = player.commanderDamageTaken[opp.id] ?? 0;
              final isLethalFromThis = dmg >= 21;
              return GestureDetector(
                key: Key('cmd_damage_btn_${player.id}_from_${opp.id}'),
                onTap: () => widget.onCommanderDamage?.call(opp.id, 1),
                onLongPress: () => widget.onCommanderDamage?.call(opp.id, -1),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: isLethalFromThis ? Colors.red : Colors.white12,
                    borderRadius: BorderRadius.circular(8),
                    border: isLethalFromThis ? Border.all(color: Colors.white) : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.shield, size: 14, color: Colors.white70),
                      const SizedBox(width: 4),
                      Text(
                        '${opp.name.substring(0, min(3, opp.name.length))}: $dmg',
                        style: TextStyle(
                          fontSize: 11,
                          color: isLethalFromThis ? Colors.white : Colors.white70,
                          fontWeight: isLethalFromThis ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 6),

        // Secondary Counters: Poison, Energy, XP, Mana, Clear
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Poison
              _buildCounterStepper(
                keyName: 'poison_${player.id}',
                label: '☠️',
                value: player.poison,
                onIncrement: () => widget.onCounterDelta?.call('poison', 1),
                onDecrement: () => widget.onCounterDelta?.call('poison', -1),
              ),
              const SizedBox(width: 4),
              // Energy
              _buildCounterStepper(
                keyName: 'energy_${player.id}',
                label: '⚡',
                value: player.energy,
                onIncrement: () => widget.onCounterDelta?.call('energy', 1),
                onDecrement: () => widget.onCounterDelta?.call('energy', -1),
              ),
              const SizedBox(width: 4),
              // XP
              _buildCounterStepper(
                keyName: 'xp_${player.id}',
                label: 'XP',
                value: player.experience,
                onIncrement: () => widget.onCounterDelta?.call('xp', 1),
                onDecrement: () => widget.onCounterDelta?.call('xp', -1),
              ),
              // Mana drawer button
              IconButton(
                key: Key('mana_drawer_btn_${player.id}'),
                icon: const Icon(Icons.bubble_chart, color: Colors.cyanAccent, size: 20),
                onPressed: () => _openManaModal(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCounterStepper({
    required String keyName,
    required String label,
    required int value,
    required VoidCallback onIncrement,
    required VoidCallback onDecrement,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          key: Key('dec_$keyName'),
          onTap: onDecrement,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: const Icon(Icons.remove_circle_outline, color: Colors.white54, size: 16),
          ),
        ),
        Text(
          '$label $value',
          key: Key('val_$keyName'),
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
        GestureDetector(
          key: Key('inc_$keyName'),
          onTap: onIncrement,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: const Icon(Icons.add_circle_outline, color: Colors.white54, size: 16),
          ),
        ),
      ],
    );
  }

  void _openManaModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2C),
      builder: (_) {
        return FloatingManaDrawerWidget(
          player: widget.player,
          onManaDelta: (color, delta) => widget.onManaDelta?.call(color, delta),
          onManaClear: widget.onManaClear,
        );
      },
    );
  }
}

/// Floating Mana Drawer displaying WUBRGC mana pips, steppers, storm counter, and "Clear Pool" button.
class FloatingManaDrawerWidget extends StatelessWidget {
  final PodPlayerState player;
  final void Function(String color, int delta)? onManaDelta;
  final VoidCallback? onManaClear;

  const FloatingManaDrawerWidget({
    super.key,
    required this.player,
    this.onManaDelta,
    this.onManaClear,
  });

  static const List<String> manaColors = ['W', 'U', 'B', 'R', 'G', 'C'];

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('mana_drawer_sheet_${player.id}'),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Mana Pool & Storm: ${player.name}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                key: Key('clear_pool_btn_${player.id}'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.clear_all, size: 18),
                label: const Text('Clear Pool'),
                onPressed: () {
                  onManaClear?.call();
                  Navigator.maybePop(context);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // WUBRGC Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: manaColors.map((color) {
                final count = player.floatingMana[color] ?? 0;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: _getManaColor(color),
                        child: Text(
                          color,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: color == 'W' ? Colors.black : Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$count',
                        key: Key('mana_val_${color}_${player.id}'),
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            key: Key('mana_dec_${color}_${player.id}'),
                            icon: const Icon(Icons.remove, size: 16, color: Colors.white54),
                            onPressed: () => onManaDelta?.call(color, -1),
                          ),
                          IconButton(
                            key: Key('mana_inc_${color}_${player.id}'),
                            icon: const Icon(Icons.add, size: 16, color: Colors.white54),
                            onPressed: () => onManaDelta?.call(color, 1),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

          const Divider(color: Colors.white24, height: 24),

          // Storm Count
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.flash_on, color: Colors.amberAccent),
              const SizedBox(width: 8),
              Text(
                'Storm Count: ${player.stormCount}',
                key: Key('storm_count_${player.id}'),
                style: const TextStyle(
                  color: Colors.amberAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getManaColor(String color) {
    switch (color) {
      case 'W':
        return const Color(0xFFF9FAF4);
      case 'U':
        return const Color(0xFF0E68AB);
      case 'B':
        return const Color(0xFF150B00);
      case 'R':
        return const Color(0xFFD3202A);
      case 'G':
        return const Color(0xFF00733E);
      case 'C':
      default:
        return const Color(0xFFCCC2AB);
    }
  }
}

/// Central crossroads floating hub button (48px) for neutral access to Randomizers & Lobby Menu.
class CenterHubButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const CenterHubButton({super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C40),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white38, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        key: const Key('center_hub_button'),
        padding: EdgeInsets.zero,
        icon: const Icon(Icons.casino, color: Colors.amberAccent, size: 24),
        onPressed: onPressed,
      ),
    );
  }
}

/// Modal dialog providing Coin Flip, Polyhedral Dice Suite (D4..D100), Random Player Selector,
/// and Global "Reset Game" action. Strictly NO active turn-passing or turn-timer logic.
class RandomizerHubModal extends StatefulWidget {
  final int playerCount;
  final VoidCallback? onResetGame;
  final void Function(int pickedSeatIndex)? onPlayerSelected;

  const RandomizerHubModal({
    super.key,
    required this.playerCount,
    this.onResetGame,
    this.onPlayerSelected,
  });

  @override
  State<RandomizerHubModal> createState() => _RandomizerHubModalState();
}

class _RandomizerHubModalState extends State<RandomizerHubModal> {
  final RandomizerService _randomizer = RandomizerService();
  String _lastResult = 'Select a tool to roll or flip';

  void _flipCoin() {
    final result = _randomizer.flipCoin();
    setState(() {
      _lastResult = 'Coin Flip: ${result == CoinSide.heads ? "HEADS" : "TAILS"}';
    });
  }

  void _rollDice(DiceType type) {
    final roll = _randomizer.rollDice(type);
    setState(() {
      _lastResult = '${type.label} Roll: $roll';
    });
  }

  void _chooseRandomPlayer() {
    final seat = _randomizer.selectRandomPlayerIndex(widget.playerCount);
    setState(() {
      _lastResult = 'Chosen Player: Seat ${seat + 1}';
    });
    widget.onPlayerSelected?.call(seat);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('randomizer_hub_modal'),
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E2C),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Utilities & Randomizers',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black38,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _lastResult,
              key: const Key('randomizer_result_text'),
              style: const TextStyle(
                color: Colors.amberAccent,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Polyhedral Dice & Coin Row
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              ElevatedButton(
                key: const Key('coin_flip_btn'),
                onPressed: _flipCoin,
                child: const Text('Coin'),
              ),
              ...DiceType.values.map((d) {
                return ElevatedButton(
                  key: Key('dice_${d.name}_btn'),
                  onPressed: () => _rollDice(d),
                  child: Text(d.label),
                );
              }),
            ],
          ),
          const SizedBox(height: 16),

          // Player selection
          ElevatedButton.icon(
            key: const Key('random_player_btn'),
            icon: const Icon(Icons.person_pin),
            label: const Text('Choose Random Player'),
            onPressed: _chooseRandomPlayer,
          ),
          const SizedBox(height: 16),

          // Global Reset Game
          ElevatedButton.icon(
            key: const Key('reset_game_btn'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade800,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.replay),
            label: const Text('Reset Game (Preserve Pod)'),
            onPressed: () {
              widget.onResetGame?.call();
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

/// Prompt dialog presented upon relaunching app after an interruption:
/// "Continue Match" or "Start New Game".
class SessionRecoveryDialog extends StatelessWidget {
  final PodState savedSession;
  final VoidCallback onContinue;
  final VoidCallback onStartNew;

  const SessionRecoveryDialog({
    super.key,
    required this.savedSession,
    required this.onContinue,
    required this.onStartNew,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('session_recovery_dialog'),
      backgroundColor: const Color(0xFF1E1E2C),
      title: const Text(
        'Active Match Detected',
        style: TextStyle(color: Colors.white),
      ),
      content: Text(
        'A previous match with ${savedSession.playerCount} players in ${savedSession.format} format was recovered.\nWould you like to continue?',
        style: const TextStyle(color: Colors.white70),
      ),
      actions: [
        TextButton(
          key: const Key('start_new_game_btn'),
          onPressed: onStartNew,
          child: const Text('Start New Game', style: TextStyle(color: Colors.redAccent)),
        ),
        ElevatedButton(
          key: const Key('continue_match_btn'),
          onPressed: onContinue,
          child: const Text('Continue Match'),
        ),
      ],
    );
  }
}
