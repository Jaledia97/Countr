// Copyright (c) 2026 Countr. All rights reserved.

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/features/life_counter/domain/models/randomizer_models.dart';
import 'package:countr/features/life_counter/domain/services/dice_roller_service.dart';
import 'package:countr/features/life_counter/presentation/dialogs/randomizer_hub_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Milestone 5 Adversarial Stress & Statistical Testing Suite', () {
    // -------------------------------------------------------------------------
    // 1. Monte Carlo Statistical Distribution Testing (10,000 Coin Flips)
    // -------------------------------------------------------------------------
    group('1. Monte Carlo Statistical Distribution Testing (10,000 Coin Flips)', () {
      test('10,000 unseeded coin flips remain strictly within 50% +/- 3% (47% - 53%)', () {
        final service = RandomizerService();

        for (int i = 0; i < 10000; i++) {
          final side = service.flipCoin();
          expect(side == CoinSide.heads || side == CoinSide.tails, isTrue);
        }

        expect(service.totalFlips, 10000);
        expect(service.headsCount + service.tailsCount, 10000);

        final headsRatio = service.headsRatio;
        final headsPercentage = headsRatio * 100.0;
        final tailsRatio = service.tailsCount / 10000.0;
        final tailsPercentage = tailsRatio * 100.0;

        // Expectation: Distribution stays within 50% +/- 3% (47% - 53%)
        expect(
          headsRatio,
          inInclusiveRange(0.47, 0.53),
          reason: 'Heads percentage was $headsPercentage%, expected within [47%, 53%]',
        );
        expect(
          tailsRatio,
          inInclusiveRange(0.47, 0.53),
          reason: 'Tails percentage was $tailsPercentage%, expected within [47%, 53%]',
        );
        expect(
          service.headsCount,
          inInclusiveRange(4700, 5300),
          reason: 'Heads count was ${service.headsCount}, expected within [4700, 5300]',
        );
        expect(
          service.tailsCount,
          inInclusiveRange(4700, 5300),
          reason: 'Tails count was ${service.tailsCount}, expected within [4700, 5300]',
        );

        // Verify history bounds: max 100 entries retained (no memory blowup)
        expect(service.history.length, 100);
        expect(service.history.first.type, RandomizerEntryType.coin);
      });

      test('Multiple independent runs of 10,000 coin flips consistently pass 47%-53% bound', () {
        // Run with distinct pseudo-random seeds
        for (final seed in [1337, 42, 99999, 2026]) {
          final service = RandomizerService(Random(seed));
          for (int i = 0; i < 10000; i++) {
            service.flipCoin();
          }
          expect(service.totalFlips, 10000);
          expect(
            service.headsRatio,
            inInclusiveRange(0.47, 0.53),
            reason: 'Seed $seed failed 47%-53% bound with ratio ${service.headsRatio}',
          );
        }
      });

      test('Coin flip detailed metadata records timestamps, labels and critical invariants', () {
        final service = RandomizerService();
        final result = service.flipCoinDetailed();

        expect(result.displayString, anyOf('Coin Flip: HEADS', 'Coin Flip: TAILS'));
        expect(result.side == CoinSide.heads || result.side == CoinSide.tails, isTrue);
        expect(result.isHeads, result.side == CoinSide.heads);
        expect(result.isTails, result.side == CoinSide.tails);
        expect(result.timestamp.isBefore(DateTime.now().add(const Duration(seconds: 1))), isTrue);
      });
    });

    // -------------------------------------------------------------------------
    // 2. 10,000 Rolls of Polyhedral Dice (D4, D6, D8, D10, D12, D20, D100)
    // -------------------------------------------------------------------------
    group('2. Polyhedral Dice 10,000 Rolls Bounds and Uniformity', () {
      for (final dice in DiceType.values) {
        test('10,000 rolls of ${dice.label} strictly bounded in [1, ${dice.sides}] with uniform distribution', () {
          final service = RandomizerService();
          final counts = <int, int>{};
          for (int side = 1; side <= dice.sides; side++) {
            counts[side] = 0;
          }

          const rollCount = 10000;
          for (int i = 0; i < rollCount; i++) {
            final roll = service.rollDice(dice);

            // Boundary validation
            expect(roll, greaterThanOrEqualTo(1), reason: 'Roll $roll below 1');
            expect(roll, lessThanOrEqualTo(dice.sides), reason: 'Roll $roll exceeded max ${dice.sides}');

            counts[roll] = (counts[roll] ?? 0) + 1;
          }

          // Verify every face appeared at least once
          for (int side = 1; side <= dice.sides; side++) {
            expect(
              counts[side],
              greaterThan(0),
              reason: '${dice.label} face $side never appeared in $rollCount rolls!',
            );
          }

          // Chi-Square goodness-of-fit test for discrete uniform distribution
          // H0: All sides have equal probability p = 1 / sides
          final expectedPerSide = rollCount / dice.sides;
          double chiSquare = 0.0;
          for (int side = 1; side <= dice.sides; side++) {
            final observed = counts[side]!;
            final diff = observed - expectedPerSide;
            chiSquare += (diff * diff) / expectedPerSide;
          }

          // Degrees of freedom = sides - 1
          // Generous critical thresholds for alpha = 0.0001
          final Map<DiceType, double> chiSquareThresholds = {
            DiceType.d4: 30.0,    // df = 3
            DiceType.d6: 35.0,    // df = 5
            DiceType.d8: 45.0,    // df = 7
            DiceType.d10: 55.0,   // df = 9
            DiceType.d12: 65.0,   // df = 11
            DiceType.d20: 95.0,   // df = 19
            DiceType.d100: 220.0, // df = 99
          };

          expect(
            chiSquare,
            lessThan(chiSquareThresholds[dice]!),
            reason: '${dice.label} Chi-Square statistic ($chiSquare) exceeded critical threshold (${chiSquareThresholds[dice]})',
          );
        });
      }

      test('rollDiceDetailed captures critical success and critical fumble precisely', () {
        final service = RandomizerService();

        for (final dice in DiceType.values) {
          bool observedMax = false;
          bool observedMin = false;

          // Perform enough rolls to see both min (1) and max (sides)
          final maxAttempts = max(dice.sides * 50, 200);
          for (int i = 0; i < maxAttempts; i++) {
            final result = service.rollDiceDetailed(dice);

            expect(result.type, equals(dice));
            expect(result.value, inInclusiveRange(1, dice.sides));

            if (result.value == dice.sides) {
              expect(result.isCriticalSuccess, isTrue);
              expect(result.isCriticalFumble, dice.sides == 1);
              observedMax = true;
            } else {
              expect(result.isCriticalSuccess, isFalse);
            }

            if (result.value == 1) {
              expect(result.isCriticalFumble, isTrue);
              observedMin = true;
            } else {
              expect(result.isCriticalFumble, isFalse);
            }

            if (observedMax && observedMin) break;
          }

          expect(observedMax, isTrue, reason: 'Failed to observe critical success for ${dice.label}');
          expect(observedMin, isTrue, reason: 'Failed to observe critical fumble for ${dice.label}');
        }
      });
    });

    // -------------------------------------------------------------------------
    // 3. Random Player and Opponent Selection Across 1v1, 3P, 4P, 5P, 6P Pods
    // -------------------------------------------------------------------------
    group('3. Player & Opponent Selection Across Pod Sizes (1v1 to 6P)', () {
      final podSizes = [2, 3, 4, 5, 6];

      test('selectRandomPlayerIndex covers all seats uniformly across 1v1, 3P, 4P, 5P, 6P', () {
        final service = RandomizerService();

        for (final podSize in podSizes) {
          final seatTally = <int, int>{};
          for (int seat = 0; seat < podSize; seat++) {
            seatTally[seat] = 0;
          }

          const iterations = 5000;
          for (int i = 0; i < iterations; i++) {
            final picked = service.selectRandomPlayerIndex(podSize);
            expect(picked, inInclusiveRange(0, podSize - 1));
            seatTally[picked] = (seatTally[picked] ?? 0) + 1;
          }

          // Every seat must be chosen
          for (int seat = 0; seat < podSize; seat++) {
            expect(
              seatTally[seat],
              greaterThan(0),
              reason: 'PodSize $podSize seat $seat was never picked!',
            );
          }

          // Chi-square test on seat distribution
          final expected = iterations / podSize;
          double chiSquare = 0.0;
          for (int seat = 0; seat < podSize; seat++) {
            final diff = seatTally[seat]! - expected;
            chiSquare += (diff * diff) / expected;
          }
          expect(chiSquare, lessThan(40.0));
        }
      });

      test('selectRandomOpponentIndex strictly NEVER picks self seat across all pods and seats', () {
        final service = RandomizerService();

        for (final podSize in podSizes) {
          for (int selfSeat = 0; selfSeat < podSize; selfSeat++) {
            final opponentCounts = <int, int>{};
            for (int seat = 0; seat < podSize; seat++) {
              if (seat != selfSeat) opponentCounts[seat] = 0;
            }

            const iterations = 2000;
            for (int i = 0; i < iterations; i++) {
              final picked = service.selectRandomOpponentIndex(podSize, selfSeat);

              // STRICT GUARANTEE: Never self seat
              expect(
                picked,
                isNot(equals(selfSeat)),
                reason: 'CRITICAL FAILURE: Opponent selection picked self seat $selfSeat in $podSize-player pod!',
              );

              // Must be in valid bounds [0, podSize - 1]
              expect(picked, inInclusiveRange(0, podSize - 1));

              opponentCounts[picked] = (opponentCounts[picked] ?? 0) + 1;
            }

            // In 1v1 pod (podSize 2), opponent is deterministically the other player 100% of the time
            if (podSize == 2) {
              final expectedOpponent = 1 - selfSeat;
              expect(opponentCounts[expectedOpponent], iterations);
            } else {
              // For multiplayer pods (3P..6P), all other opponents must be selected
              for (int otherSeat = 0; otherSeat < podSize; otherSeat++) {
                if (otherSeat != selfSeat) {
                  expect(
                    opponentCounts[otherSeat],
                    greaterThan(0),
                    reason: 'Pod $podSize seat $selfSeat never selected opponent $otherSeat',
                  );
                }
              }
            }
          }
        }
      });

      test('Boundary and degenerate inputs for player and opponent selection', () {
        final service = RandomizerService();

        // 1 player pod
        expect(service.selectRandomPlayerIndex(1), 0);
        expect(service.selectRandomOpponentIndex(1, 0), 0);

        // 0 player pod
        expect(service.selectRandomPlayerIndex(0), 0);
        expect(service.selectRandomOpponentIndex(0, 0), 0);

        // Negative player pod
        expect(service.selectRandomPlayerIndex(-3), 0);
        expect(service.selectRandomOpponentIndex(-1, 2), 2);
      });
    });

    // -------------------------------------------------------------------------
    // 4. Rapid Multi-Tap Stress on Coin Flip & Dice in RandomizerHubModal
    // -------------------------------------------------------------------------
    group('4. Rapid Multi-Tap Stress on RandomizerHubModal UI', () {
      testWidgets('Burst tapping coin_flip_btn 50 times in rapid succession without animation corruption', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: RandomizerHubModal(playerCount: 4, selfSeatIndex: 0),
            ),
          ),
        );

        // Rapid burst taps with 10ms micro-pumps (mid-animation taps)
        for (int i = 0; i < 50; i++) {
          await tester.tap(find.byKey(const Key('coin_flip_btn')));
          await tester.pump(const Duration(milliseconds: 10));

          // Text must immediately reflect latest flip without crash
          expect(find.byKey(const Key('randomizer_result_text')), findsOneWidget);
          expect(find.textContaining('Coin Flip:'), findsOneWidget);
        }

        // Let the animation finish cleanly
        await tester.pumpAndSettle();

        // Verify tally recorded all 50 flips
        expect(find.textContaining('(50 total)'), findsOneWidget);
      });

      testWidgets('Burst tapping dice_d20_btn 50 times in rapid succession without animation corruption', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: RandomizerHubModal(playerCount: 4, selfSeatIndex: 0),
            ),
          ),
        );

        for (int i = 0; i < 50; i++) {
          await tester.tap(find.byKey(const Key('dice_d20_btn')));
          await tester.pump(const Duration(milliseconds: 10));

          expect(find.byKey(const Key('randomizer_result_text')), findsOneWidget);
          expect(find.textContaining('D20 Roll:'), findsOneWidget);
        }

        await tester.pumpAndSettle();
      });

      testWidgets('Interleaved chaotic multi-tap stress across all dice and randomizers', (tester) async {
        int playerCallbacks = 0;
        int opponentCallbacks = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RandomizerHubModal(
                playerCount: 6,
                selfSeatIndex: 2,
                onPlayerSelected: (_) => playerCallbacks++,
                onOpponentSelected: (_) => opponentCallbacks++,
              ),
            ),
          ),
        );

        final buttonsToTap = [
          const Key('coin_flip_btn'),
          const Key('dice_d4_btn'),
          const Key('dice_d6_btn'),
          const Key('dice_d8_btn'),
          const Key('dice_d10_btn'),
          const Key('dice_d12_btn'),
          const Key('dice_d20_btn'),
          const Key('dice_d100_btn'),
          const Key('random_player_btn'),
          const Key('random_opponent_btn'),
        ];

        // 100 rapid interleaved taps
        for (int i = 0; i < 100; i++) {
          final targetKey = buttonsToTap[i % buttonsToTap.length];
          await tester.tap(find.byKey(targetKey));
          await tester.pump(const Duration(milliseconds: 15));
        }

        // Settle all running controllers
        await tester.pumpAndSettle();

        expect(playerCallbacks, 10);
        expect(opponentCallbacks, 10);
        expect(find.byKey(const Key('randomizer_result_text')), findsOneWidget);
      });

      testWidgets('Reset tally while coin flip animation is active does not throw', (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: RandomizerHubModal(playerCount: 4),
            ),
          ),
        );

        // Start coin flip
        await tester.tap(find.byKey(const Key('coin_flip_btn')));
        await tester.pump(const Duration(milliseconds: 100)); // mid-flight

        // Reset tally while animation running
        await tester.tap(find.byKey(const Key('reset_tally_btn')));
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.textContaining('(0 total)'), findsOneWidget);

        await tester.pumpAndSettle();
      });

      testWidgets('Modal disposal mid-animation does not leak tickers or throw exceptions', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  key: const Key('open_hub'),
                  onPressed: () {
                    RandomizerHubModal.show(
                      context: context,
                      playerCount: 4,
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );

        // Open modal bottom sheet
        await tester.tap(find.byKey(const Key('open_hub')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('randomizer_hub_modal')), findsOneWidget);

        // Trigger coin flip animation
        await tester.tap(find.byKey(const Key('coin_flip_btn')));
        await tester.pump(const Duration(milliseconds: 100)); // mid-flip

        // Immediately close the modal bottom sheet while animation is actively ticking
        Navigator.of(tester.element(find.byKey(const Key('randomizer_hub_modal')))).pop();
        await tester.pumpAndSettle();

        // Modal should be disposed cleanly without any TickerCanceled or pending timer error
        expect(find.byKey(const Key('randomizer_hub_modal')), findsNothing);
      });
    });

    // -------------------------------------------------------------------------
    // 5. Memory Boundedness & Domain Invariants Under Heavy Load
    // -------------------------------------------------------------------------
    group('5. Memory Boundedness & Domain Invariants Under Heavy Load', () {
      test('History buffer stays strictly clamped to 100 entries after 10,000 mixed operations', () {
        final service = RandomizerService();

        for (int i = 0; i < 2000; i++) {
          service.flipCoin();
          service.rollDice(DiceType.d20);
          service.rollDice(DiceType.d100);
          service.selectRandomPlayerIndex(4);
          service.selectRandomOpponentIndex(4, 0);
        }

        // Total 10,000 operations performed
        expect(service.history.length, 100);
        expect(service.totalFlips, 2000);

        // Attempting to modify unmodifiable history throws UnsupportedError
        expect(() => service.history.clear(), throwsUnsupportedError);
        expect(() => service.history.add(service.history.first), throwsUnsupportedError);
        expect(() => service.history.removeAt(0), throwsUnsupportedError);

        // JSON round-trip of history entries
        for (final entry in service.history) {
          final json = entry.toJson();
          expect(json['id'], isNotNull);
          expect(json['type'], isNotNull);
          expect(json['summary'], isNotNull);
          expect(json['timestamp'], isNotNull);
        }
      });
    });
  });
}
