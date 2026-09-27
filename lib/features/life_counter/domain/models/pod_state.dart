import 'package:flutter/foundation.dart';

/// Configuration for initializing a player when creating a new match session.
class PlayerSetupConfig {
  final String id;
  final int seatOrder;
  final String name;
  final String? deckId;
  final String? commanderCardId;
  final String? commanderName;
  final String? artCropUrl;
  final String? colorTheme;
  final int startingLife;
  final bool isLocalDevice;
  final String? peerDeviceId;

  const PlayerSetupConfig({
    required this.id,
    required this.seatOrder,
    required this.name,
    this.deckId,
    this.commanderCardId,
    this.commanderName,
    this.artCropUrl,
    this.colorTheme,
    required this.startingLife,
    this.isLocalDevice = true,
    this.peerDeviceId,
  });
}

/// Immutable domain state representing an individual player in an MTG life counter pod.
@immutable
class PodPlayerState {
  final String id;
  final int seatIndex;
  final String name;
  final String? deckId;
  final String? commanderCardId;
  final String? commanderName;
  final String? commanderArtCropUrl;
  final String? colorTheme;
  final int life;
  final int poison;
  final int energy;
  final int experience;
  final int commanderTax;
  final bool isMonarch;
  final bool hasInitiative;
  final Map<String, int> commanderDamageTaken; // sourcePlayerId -> damage
  final Map<String, int> floatingMana; // 'W', 'U', 'B', 'R', 'G', 'C' -> count
  final int stormCount;
  final bool isEliminated;
  final bool isLocalDevice;
  final String? peerDeviceId;

  const PodPlayerState({
    required this.id,
    required this.seatIndex,
    required this.name,
    this.deckId,
    this.commanderCardId,
    this.commanderName,
    this.commanderArtCropUrl,
    this.colorTheme,
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
    this.isLocalDevice = true,
    this.peerDeviceId,
  });

  /// Whether the player has received 10 or more poison counters.
  bool get isPoisonLethal => poison >= 10;

  /// Whether the player has received 21 or more commander damage from a specific opponent.
  bool isCommanderDamageLethalFrom(String opponentId) =>
      (commanderDamageTaken[opponentId] ?? 0) >= 21;

  /// Whether the player has received 21 or more commander damage from any opponent.
  bool get hasAnyLethalCommanderDamage =>
      commanderDamageTaken.values.any((dmg) => dmg >= 21);

  /// Whether the player is in a lethal state (0 or negative life, 10+ poison, 21+ cmd damage, or eliminated).
  bool get isLethal =>
      life <= 0 || isPoisonLethal || hasAnyLethalCommanderDamage || isEliminated;

  PodPlayerState copyWith({
    String? id,
    int? seatIndex,
    String? name,
    String? deckId,
    String? commanderCardId,
    String? commanderName,
    String? commanderArtCropUrl,
    String? colorTheme,
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
    bool? isLocalDevice,
    String? peerDeviceId,
  }) {
    return PodPlayerState(
      id: id ?? this.id,
      seatIndex: seatIndex ?? this.seatIndex,
      name: name ?? this.name,
      deckId: deckId ?? this.deckId,
      commanderCardId: commanderCardId ?? this.commanderCardId,
      commanderName: commanderName ?? this.commanderName,
      commanderArtCropUrl: commanderArtCropUrl ?? this.commanderArtCropUrl,
      colorTheme: colorTheme ?? this.colorTheme,
      life: life ?? this.life,
      poison: poison ?? this.poison,
      energy: energy ?? this.energy,
      experience: experience ?? this.experience,
      commanderTax: commanderTax ?? this.commanderTax,
      isMonarch: isMonarch ?? this.isMonarch,
      hasInitiative: hasInitiative ?? this.hasInitiative,
      commanderDamageTaken: commanderDamageTaken != null
          ? Map.unmodifiable(commanderDamageTaken)
          : this.commanderDamageTaken,
      floatingMana: floatingMana != null
          ? Map.unmodifiable(floatingMana)
          : this.floatingMana,
      stormCount: stormCount ?? this.stormCount,
      isEliminated: isEliminated ?? this.isEliminated,
      isLocalDevice: isLocalDevice ?? this.isLocalDevice,
      peerDeviceId: peerDeviceId ?? this.peerDeviceId,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'seatIndex': seatIndex,
    'name': name,
    'deckId': deckId,
    'commanderCardId': commanderCardId,
    'commanderName': commanderName,
    'commanderArtCropUrl': commanderArtCropUrl,
    'colorTheme': colorTheme,
    'life': life,
    'poison': poison,
    'energy': energy,
    'experience': experience,
    'commanderTax': commanderTax,
    'isMonarch': isMonarch,
    'hasInitiative': hasInitiative,
    'commanderDamageTaken': commanderDamageTaken,
    'floatingMana': floatingMana,
    'stormCount': stormCount,
    'isEliminated': isEliminated,
    'isLocalDevice': isLocalDevice,
    'peerDeviceId': peerDeviceId,
  };

  factory PodPlayerState.fromJson(Map<String, dynamic> json) => PodPlayerState(
    id: json['id'] as String,
    seatIndex: json['seatIndex'] as int,
    name: json['name'] as String,
    deckId: json['deckId'] as String?,
    commanderCardId: json['commanderCardId'] as String?,
    commanderName: json['commanderName'] as String?,
    commanderArtCropUrl: json['commanderArtCropUrl'] as String?,
    colorTheme: json['colorTheme'] as String?,
    life: json['life'] as int,
    poison: json['poison'] as int? ?? 0,
    energy: json['energy'] as int? ?? 0,
    experience: json['experience'] as int? ?? 0,
    commanderTax: json['commanderTax'] as int? ?? 0,
    isMonarch: json['isMonarch'] as bool? ?? false,
    hasInitiative: json['hasInitiative'] as bool? ?? false,
    commanderDamageTaken: (json['commanderDamageTaken'] as Map<String, dynamic>?)
            ?.map((k, v) => MapEntry(k, (v as num).toInt())) ??
        const {},
    floatingMana: (json['floatingMana'] as Map<String, dynamic>?)
            ?.map((k, v) => MapEntry(k, (v as num).toInt())) ??
        const {'W': 0, 'U': 0, 'B': 0, 'R': 0, 'G': 0, 'C': 0},
    stormCount: json['stormCount'] as int? ?? 0,
    isEliminated: json['isEliminated'] as bool? ?? false,
    isLocalDevice: json['isLocalDevice'] as bool? ?? true,
    peerDeviceId: json['peerDeviceId'] as String?,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PodPlayerState &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          seatIndex == other.seatIndex &&
          name == other.name &&
          deckId == other.deckId &&
          commanderCardId == other.commanderCardId &&
          commanderName == other.commanderName &&
          commanderArtCropUrl == other.commanderArtCropUrl &&
          colorTheme == other.colorTheme &&
          life == other.life &&
          poison == other.poison &&
          energy == other.energy &&
          experience == other.experience &&
          commanderTax == other.commanderTax &&
          isMonarch == other.isMonarch &&
          hasInitiative == other.hasInitiative &&
          mapEquals(commanderDamageTaken, other.commanderDamageTaken) &&
          mapEquals(floatingMana, other.floatingMana) &&
          stormCount == other.stormCount &&
          isEliminated == other.isEliminated &&
          isLocalDevice == other.isLocalDevice &&
          peerDeviceId == other.peerDeviceId;

  @override
  int get hashCode => Object.hash(
        id,
        seatIndex,
        name,
        deckId,
        commanderCardId,
        commanderName,
        commanderArtCropUrl,
        colorTheme,
        life,
        poison,
        energy,
        experience,
        commanderTax,
        isMonarch,
        hasInitiative,
        stormCount,
        isEliminated,
        isLocalDevice,
        peerDeviceId,
      );
}

/// Immutable top-level domain state representing an entire MTG life counter pod.
@immutable
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
    this.isP2pHost = false,
    this.roomCode,
    this.sequenceNumber = 0,
  });

  /// Finds a player by unique [id], or null if not found.
  PodPlayerState? getPlayer(String id) {
    for (final p in players) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Finds a player by physical [seatIndex] (0..5), or null if not found.
  PodPlayerState? getPlayerBySeat(int seatIndex) {
    for (final p in players) {
      if (p.seatIndex == seatIndex) return p;
    }
    return null;
  }

  /// Total number of active players seated in the pod.
  int get playerCount => players.length;

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
      players: players ?? this.players,
      isDay: isDay ?? this.isDay,
      isP2pHost: isP2pHost ?? this.isP2pHost,
      roomCode: roomCode ?? this.roomCode,
      sequenceNumber: sequenceNumber ?? this.sequenceNumber,
    );
  }

  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'format': format,
    'startingLife': startingLife,
    'players': players.map((p) => p.toJson()).toList(),
    'isDay': isDay,
    'isP2pHost': isP2pHost,
    'roomCode': roomCode,
    'sequenceNumber': sequenceNumber,
  };

  factory PodState.fromJson(Map<String, dynamic> json) => PodState(
    sessionId: json['sessionId'] as String,
    format: json['format'] as String,
    startingLife: json['startingLife'] as int,
    players: (json['players'] as List<dynamic>)
        .map((p) => PodPlayerState.fromJson(p as Map<String, dynamic>))
        .toList(),
    isDay: json['isDay'] as bool? ?? true,
    isP2pHost: json['isP2pHost'] as bool? ?? false,
    roomCode: json['roomCode'] as String?,
    sequenceNumber: json['sequenceNumber'] as int? ?? 0,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PodState &&
          runtimeType == other.runtimeType &&
          sessionId == other.sessionId &&
          format == other.format &&
          startingLife == other.startingLife &&
          listEquals(players, other.players) &&
          isDay == other.isDay &&
          isP2pHost == other.isP2pHost &&
          roomCode == other.roomCode &&
          sequenceNumber == other.sequenceNumber;

  @override
  int get hashCode => Object.hash(
        sessionId,
        format,
        startingLife,
        Object.hashAll(players),
        isDay,
        isP2pHost,
        roomCode,
        sequenceNumber,
      );
}
