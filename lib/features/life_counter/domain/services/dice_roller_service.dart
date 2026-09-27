// Copyright (c) 2026 Countr. All rights reserved.

import 'dart:math';
import 'package:countr/features/life_counter/domain/models/randomizer_models.dart';

/// Tabletop randomizer utility engine for Magic: The Gathering.
///
/// Features:
/// 1. Cryptographic/Deterministic pseudorandom generation with injectable [Random].
/// 2. Coin flipping with bounded statistical distribution.
/// 3. Polyhedral dice rolling (D4, D6, D8, D10, D12, D20, D100).
/// 4. Fair random player and opponent seat selection.
/// 5. In-memory history ledger and running coin flip tally.
/// 6. Strictly passive: Zero turn-passing or turn-timer mechanisms.
class RandomizerService {
  final Random _random;
  final List<RandomizerHistoryEntry> _history = [];

  int _headsCount = 0;
  int _tailsCount = 0;

  RandomizerService([Random? random]) : _random = random ?? Random();

  /// Total count of Heads flips recorded in the current session.
  int get headsCount => _headsCount;

  /// Total count of Tails flips recorded in the current session.
  int get tailsCount => _tailsCount;

  /// Total count of all coin flips recorded.
  int get totalFlips => _headsCount + _tailsCount;

  /// Ratio of Heads flips (0.0 to 1.0), or 0.5 if no flips have occurred.
  double get headsRatio => totalFlips == 0 ? 0.5 : _headsCount / totalFlips;

  /// Read-only snapshot of the past randomizer history (most recent first).
  List<RandomizerHistoryEntry> get history => List.unmodifiable(_history);

  /// Resets the running coin flip tally.
  void resetTally() {
    _headsCount = 0;
    _tailsCount = 0;
  }

  /// Clears the history log and resets tallies.
  void clearHistory() {
    _history.clear();
    resetTally();
  }

  /// Flips a standard 2-sided coin.
  ///
  /// Contract invariant: Returns [CoinSide.heads] or [CoinSide.tails].
  CoinSide flipCoin() {
    final isHeads = _random.nextBool();
    final side = isHeads ? CoinSide.heads : CoinSide.tails;

    if (side.isHeads) {
      _headsCount++;
    } else {
      _tailsCount++;
    }

    final result = CoinFlipResult(side: side);
    _recordHistory(
      RandomizerHistoryEntry(
        id: 'flip_${DateTime.now().microsecondsSinceEpoch}',
        type: RandomizerEntryType.coin,
        summary: result.displayString,
        timestamp: result.timestamp,
        coinResult: result,
      ),
    );

    return side;
  }

  /// Detailed coin flip returning metadata and timestamps.
  CoinFlipResult flipCoinDetailed() {
    flipCoin();
    return _history.first.coinResult!;
  }

  /// Rolls a polyhedral die of [type] (D4 through D100).
  ///
  /// Contract invariant: Returns an integer strictly in the range `1..type.sides`.
  int rollDice(DiceType type) {
    final value = _random.nextInt(type.sides) + 1;
    final result = DiceRollResult(type: type, value: value);

    _recordHistory(
      RandomizerHistoryEntry(
        id: 'roll_${DateTime.now().microsecondsSinceEpoch}',
        type: RandomizerEntryType.dice,
        summary: result.displayString,
        timestamp: result.timestamp,
        diceResult: result,
      ),
    );

    return value;
  }

  /// Detailed dice roll returning metadata including critical success/fumble flags.
  DiceRollResult rollDiceDetailed(DiceType type) {
    rollDice(type);
    return _history.first.diceResult!;
  }

  /// Selects a random player seat index from active players (`0` to `activePlayerCount - 1`).
  ///
  /// Returns `0` if [activePlayerCount] <= 0.
  int selectRandomPlayerIndex(int activePlayerCount) {
    if (activePlayerCount <= 0) return 0;
    final picked = _random.nextInt(activePlayerCount);

    _recordHistory(
      RandomizerHistoryEntry(
        id: 'player_${DateTime.now().microsecondsSinceEpoch}',
        type: RandomizerEntryType.playerSelection,
        summary: 'Chosen Player: Seat ${picked + 1}',
        timestamp: DateTime.now(),
        selectedPlayerIndex: picked,
      ),
    );

    return picked;
  }

  /// Selects a random opponent seat index, strictly excluding [selfSeatIndex].
  ///
  /// Contract invariant: If [activePlayerCount] <= 1, returns [selfSeatIndex].
  /// Otherwise, picked index is in `0..activePlayerCount - 1` and never equals [selfSeatIndex].
  int selectRandomOpponentIndex(int activePlayerCount, int selfSeatIndex) {
    if (activePlayerCount <= 1) return selfSeatIndex;

    int picked = _random.nextInt(activePlayerCount - 1);
    if (picked >= selfSeatIndex) {
      picked++;
    }

    _recordHistory(
      RandomizerHistoryEntry(
        id: 'opponent_${DateTime.now().microsecondsSinceEpoch}',
        type: RandomizerEntryType.opponentSelection,
        summary: 'Chosen Opponent: Seat ${picked + 1}',
        timestamp: DateTime.now(),
        selectedPlayerIndex: picked,
      ),
    );

    return picked;
  }

  void _recordHistory(RandomizerHistoryEntry entry) {
    _history.insert(0, entry);
    // Keep history bounded to 100 entries
    if (_history.length > 100) {
      _history.removeLast();
    }
  }
}
