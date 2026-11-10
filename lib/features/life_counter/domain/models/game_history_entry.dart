// Copyright (c) 2026 Countr. All rights reserved.

import 'package:flutter/foundation.dart';

/// Immutable domain model representing a single committed action in the life counter turn log.
@immutable
class GameHistoryEntry {
  final String id;
  final DateTime timestamp;
  final String playerId;
  final String playerName;
  final String? playerColor;
  final String entryType; // 'life', 'commander_damage', 'counter', 'reset', etc.
  final int startValue;
  final int endValue;
  final int delta;
  final String description;
  final String? sourcePlayerId;
  final String? sourcePlayerName;
  final String? counterType;
  final bool isPartner;

  const GameHistoryEntry({
    required this.id,
    required this.timestamp,
    required this.playerId,
    required this.playerName,
    this.playerColor,
    this.entryType = 'life',
    required this.startValue,
    required this.endValue,
    required this.delta,
    required this.description,
    this.sourcePlayerId,
    this.sourcePlayerName,
    this.counterType,
    this.isPartner = false,
  });

  /// Factory creating a consolidated life change entry from a debounced interaction burst.
  factory GameHistoryEntry.lifeChange({
    required String playerId,
    String playerName = 'Player',
    String? playerColor,
    required int startLife,
    required int endLife,
    required int netDelta,
    DateTime? timestamp,
  }) {
    final effectiveTime = timestamp ?? DateTime.now();
    final action = netDelta < 0 ? 'lost ${netDelta.abs()}' : 'gained $netDelta';
    return GameHistoryEntry(
      id: 'hist_${effectiveTime.microsecondsSinceEpoch}_$playerId',
      timestamp: effectiveTime,
      playerId: playerId,
      playerName: playerName,
      playerColor: playerColor,
      entryType: 'life',
      startValue: startLife,
      endValue: endLife,
      delta: netDelta,
      description: '$playerName $action life ($startLife -> $endLife)',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'playerId': playerId,
        'playerName': playerName,
        'playerColor': playerColor,
        'entryType': entryType,
        'startValue': startValue,
        'endValue': endValue,
        'delta': delta,
        'description': description,
        'sourcePlayerId': sourcePlayerId,
        'sourcePlayerName': sourcePlayerName,
        'counterType': counterType,
        'isPartner': isPartner,
      };

  factory GameHistoryEntry.fromJson(Map<String, dynamic> json) => GameHistoryEntry(
        id: json['id'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        playerId: json['playerId'] as String,
        playerName: json['playerName'] as String,
        playerColor: json['playerColor'] as String?,
        entryType: json['entryType'] as String? ?? 'life',
        startValue: json['startValue'] as int? ?? 0,
        endValue: json['endValue'] as int? ?? 0,
        delta: json['delta'] as int? ?? 0,
        description: json['description'] as String,
        sourcePlayerId: json['sourcePlayerId'] as String?,
        sourcePlayerName: json['sourcePlayerName'] as String?,
        counterType: json['counterType'] as String?,
        isPartner: json['isPartner'] as bool? ?? false,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameHistoryEntry &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          playerId == other.playerId &&
          startValue == other.startValue &&
          endValue == other.endValue &&
          delta == other.delta &&
          description == other.description;

  @override
  int get hashCode => Object.hash(id, playerId, startValue, endValue, delta, description);
}
