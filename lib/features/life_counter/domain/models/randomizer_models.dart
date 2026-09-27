// Copyright (c) 2026 Countr. All rights reserved.

import 'package:flutter/foundation.dart';

/// Enumeration of coin sides for MTG randomizer mechanics.
enum CoinSide {
  heads('HEADS', 'Heads'),
  tails('TAILS', 'Tails');

  final String code;
  final String label;
  const CoinSide(this.code, this.label);

  bool get isHeads => this == CoinSide.heads;
  bool get isTails => this == CoinSide.tails;
}

/// Supported polyhedral dice types for Magic: The Gathering tabletop play.
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

  int get minRoll => 1;
  int get maxRoll => sides;
}

/// Immutable result of a single polyhedral dice roll.
@immutable
class DiceRollResult {
  final DiceType type;
  final int value;
  final DateTime timestamp;
  final String? note;

  DiceRollResult({
    required this.type,
    required this.value,
    DateTime? timestamp,
    this.note,
  })  : timestamp = timestamp ?? DateTime.now(),
        assert(value >= 1 && value <= type.sides, 'Roll value must be within bounds [1, ${type.sides}]');

  /// Indicates a maximum outcome (e.g. Natural 20 on D20).
  bool get isCriticalSuccess => value == type.sides;

  /// Indicates a minimum outcome (e.g. Natural 1 on D20).
  bool get isCriticalFumble => value == 1;

  /// Formatted display label conforming to test expectations: `'${type.label} Roll: $value'`.
  String get displayString => '${type.label} Roll: $value';

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'value': value,
        'timestamp': timestamp.toIso8601String(),
        'note': note,
      };

  factory DiceRollResult.fromJson(Map<String, dynamic> json) {
    return DiceRollResult(
      type: DiceType.values.byName(json['type'] as String),
      value: json['value'] as int,
      timestamp: DateTime.parse(json['timestamp'] as String),
      note: json['note'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiceRollResult &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          value == other.value &&
          timestamp == other.timestamp;

  @override
  int get hashCode => Object.hash(type, value, timestamp);
}

/// Immutable result of a single coin flip.
@immutable
class CoinFlipResult {
  final CoinSide side;
  final DateTime timestamp;

  CoinFlipResult({
    required this.side,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get isHeads => side.isHeads;
  bool get isTails => side.isTails;

  /// Formatted display label: `'Coin Flip: HEADS'` or `'Coin Flip: TAILS'`.
  String get displayString => 'Coin Flip: ${side.code}';

  Map<String, dynamic> toJson() => {
        'side': side.name,
        'timestamp': timestamp.toIso8601String(),
      };

  factory CoinFlipResult.fromJson(Map<String, dynamic> json) {
    return CoinFlipResult(
      side: CoinSide.values.byName(json['side'] as String),
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CoinFlipResult &&
          runtimeType == other.runtimeType &&
          side == other.side &&
          timestamp == other.timestamp;

  @override
  int get hashCode => Object.hash(side, timestamp);
}

/// Entry types stored in the randomizer history log.
enum RandomizerEntryType {
  coin,
  dice,
  playerSelection,
  opponentSelection,
}

/// Historical record of a randomizer operation for ledger and audit purposes.
@immutable
class RandomizerHistoryEntry {
  final String id;
  final RandomizerEntryType type;
  final String summary;
  final DateTime timestamp;
  final DiceRollResult? diceResult;
  final CoinFlipResult? coinResult;
  final int? selectedPlayerIndex;

  const RandomizerHistoryEntry({
    required this.id,
    required this.type,
    required this.summary,
    required this.timestamp,
    this.diceResult,
    this.coinResult,
    this.selectedPlayerIndex,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'summary': summary,
        'timestamp': timestamp.toIso8601String(),
        'diceResult': diceResult?.toJson(),
        'coinResult': coinResult?.toJson(),
        'selectedPlayerIndex': selectedPlayerIndex,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RandomizerHistoryEntry &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
