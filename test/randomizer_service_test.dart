// Copyright (c) 2026 Countr. All rights reserved.

import 'dart:math';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/features/life_counter/domain/models/randomizer_models.dart';
import 'package:countr/features/life_counter/domain/services/dice_roller_service.dart';

void main() {
  group('RandomizerService Domain & Unit Tests', () {
    test('flipCoin returns valid CoinSide and tracks tally correctly', () {
      final service = RandomizerService();
      expect(service.headsCount, 0);
      expect(service.tailsCount, 0);
      expect(service.totalFlips, 0);

      final result = service.flipCoin();
      expect(result == CoinSide.heads || result == CoinSide.tails, isTrue);
      expect(service.totalFlips, 1);

      if (result.isHeads) {
        expect(service.headsCount, 1);
        expect(service.tailsCount, 0);
      } else {
        expect(service.headsCount, 0);
        expect(service.tailsCount, 1);
      }
    });

    test('flipCoin statistical distribution across 1000 flips is reasonable', () {
      final service = RandomizerService(Random(42));
      for (int i = 0; i < 1000; i++) {
        service.flipCoin();
      }

      expect(service.totalFlips, 1000);
      // Expected around 500; wide bounds 400..600 verify statistical soundness
      expect(service.headsCount, inInclusiveRange(400, 600));
      expect(service.tailsCount, inInclusiveRange(400, 600));
      expect(service.headsCount + service.tailsCount, 1000);
      expect(service.headsRatio, inInclusiveRange(0.4, 0.6));
    });

    test('resetTally zeroes flip counts without clearing other history', () {
      final service = RandomizerService();
      service.flipCoin();
      service.rollDice(DiceType.d20);
      expect(service.totalFlips, 1);
      expect(service.history.length, 2);

      service.resetTally();
      expect(service.totalFlips, 0);
      expect(service.headsCount, 0);
      expect(service.tailsCount, 0);
      expect(service.history.length, 2);
    });

    test('polyhedral dice return results strictly within bounds [1, sides]', () {
      final service = RandomizerService();
      for (final type in DiceType.values) {
        for (int i = 0; i < 50; i++) {
          final roll = service.rollDice(type);
          expect(roll, greaterThanOrEqualTo(1));
          expect(roll, lessThanOrEqualTo(type.sides));
        }
      }
    });

    test('D4 roll strictly bounded in 1..4 across 50 iterations', () {
      final service = RandomizerService();
      for (int i = 0; i < 50; i++) {
        final roll = service.rollDice(DiceType.d4);
        expect(roll, inInclusiveRange(1, 4));
      }
    });

    test('D100 roll strictly bounded in 1..100 across 50 iterations', () {
      final service = RandomizerService();
      for (int i = 0; i < 50; i++) {
        final roll = service.rollDice(DiceType.d100);
        expect(roll, inInclusiveRange(1, 100));
      }
    });

    test('rollDiceDetailed captures critical success and critical fumble flags', () {
      final service = RandomizerService();
      bool foundCriticalSuccess = false;
      bool foundCriticalFumble = false;

      for (int i = 0; i < 300; i++) {
        final detailed = service.rollDiceDetailed(DiceType.d20);
        if (detailed.value == 20) {
          expect(detailed.isCriticalSuccess, isTrue);
          expect(detailed.isCriticalFumble, isFalse);
          foundCriticalSuccess = true;
        } else if (detailed.value == 1) {
          expect(detailed.isCriticalSuccess, isFalse);
          expect(detailed.isCriticalFumble, isTrue);
          foundCriticalFumble = true;
        }
        if (foundCriticalSuccess && foundCriticalFumble) break;
      }
      expect(foundCriticalSuccess || foundCriticalFumble, isTrue);
    });

    test('selectRandomPlayerIndex boundary handling', () {
      final service = RandomizerService();
      // Negative and zero playerCount gracefully return 0
      expect(service.selectRandomPlayerIndex(0), 0);
      expect(service.selectRandomPlayerIndex(-1), 0);

      // Single player always returns 0
      expect(service.selectRandomPlayerIndex(1), 0);

      // 4-player pod returns in range 0..3
      for (int i = 0; i < 50; i++) {
        final seat = service.selectRandomPlayerIndex(4);
        expect(seat, inInclusiveRange(0, 3));
      }
    });

    test('selectRandomOpponentIndex never picks self seat', () {
      final service = RandomizerService();
      const playerCount = 4;
      const selfSeat = 2;

      for (int i = 0; i < 50; i++) {
        final picked = service.selectRandomOpponentIndex(playerCount, selfSeat);
        expect(picked, isNot(equals(selfSeat)));
        expect(picked, inInclusiveRange(0, 3));
      }
    });

    test('selectRandomOpponentIndex with 1 player returns selfSeat', () {
      final service = RandomizerService();
      expect(service.selectRandomOpponentIndex(1, 0), 0);
    });

    test('selectRandomOpponentIndex with 2 players toggles strictly between seats', () {
      final service = RandomizerService();
      for (int i = 0; i < 10; i++) {
        expect(service.selectRandomOpponentIndex(2, 0), 1);
        expect(service.selectRandomOpponentIndex(2, 1), 0);
      }
    });

    test('history tracks entries in reverse chronological order and is unmodifiable', () {
      final service = RandomizerService();
      service.flipCoin();
      service.rollDice(DiceType.d6);
      service.selectRandomPlayerIndex(4);

      expect(service.history.length, 3);
      expect(service.history.first.type, RandomizerEntryType.playerSelection);
      expect(service.history[1].type, RandomizerEntryType.dice);
      expect(service.history[2].type, RandomizerEntryType.coin);

      // Unmodifiable check
      expect(() => service.history.clear(), throwsUnsupportedError);
    });

    test('clearHistory zeroes counts and clears history list', () {
      final service = RandomizerService();
      service.flipCoin();
      service.rollDice(DiceType.d12);
      expect(service.history.length, 2);
      expect(service.totalFlips, 1);

      service.clearHistory();
      expect(service.history.isEmpty, isTrue);
      expect(service.totalFlips, 0);
    });

    test('DiceRollResult and CoinFlipResult JSON serialization and equality', () {
      final now = DateTime.now();
      final roll = DiceRollResult(type: DiceType.d20, value: 15, timestamp: now);
      final jsonRoll = roll.toJson();
      final restoredRoll = DiceRollResult.fromJson(jsonRoll);
      expect(restoredRoll, roll);
      expect(restoredRoll.displayString, 'D20 Roll: 15');

      final flip = CoinFlipResult(side: CoinSide.heads, timestamp: now);
      final jsonFlip = flip.toJson();
      final restoredFlip = CoinFlipResult.fromJson(jsonFlip);
      expect(restoredFlip, flip);
      expect(restoredFlip.displayString, 'Coin Flip: HEADS');
    });
  });
}
