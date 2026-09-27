// Copyright (c) 2026 Countr. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/features/life_counter/domain/models/randomizer_models.dart';
import 'package:countr/features/life_counter/presentation/dialogs/randomizer_hub_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RandomizerHubModal Widget Tests', () {
    testWidgets('Renders all required controls and initial placeholder text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RandomizerHubModal(playerCount: 4),
          ),
        ),
      );

      expect(find.byKey(const Key('randomizer_hub_modal')), findsOneWidget);
      expect(find.byKey(const Key('coin_flip_btn')), findsOneWidget);
      expect(find.byKey(const Key('dice_d20_btn')), findsOneWidget);
      expect(find.byKey(const Key('reset_game_btn')), findsOneWidget);
      expect(find.byKey(const Key('random_player_btn')), findsOneWidget);
      expect(find.byKey(const Key('random_opponent_btn')), findsOneWidget);
      expect(find.byKey(const Key('randomizer_result_text')), findsOneWidget);
      expect(find.text('Select a tool to roll or flip'), findsOneWidget);

      for (final dice in DiceType.values) {
        expect(find.byKey(Key('dice_${dice.name}_btn')), findsOneWidget);
      }
    });

    testWidgets('Coin flip updates UI synchronously and increments tally', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RandomizerHubModal(playerCount: 4),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('coin_flip_btn')));
      await tester.pump();

      expect(
        find.textContaining('Coin Flip:'),
        findsOneWidget,
      );

      // Settle animation
      await tester.pumpAndSettle();
      expect(find.textContaining('(1 total)'), findsOneWidget);

      // Reset tally
      await tester.tap(find.byKey(const Key('reset_tally_btn')));
      await tester.pump();
      expect(find.textContaining('(0 total)'), findsOneWidget);
    });

    testWidgets('Polyhedral dice rolls update UI synchronously with single pump', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RandomizerHubModal(playerCount: 4),
          ),
        ),
      );

      // D20 roll
      await tester.tap(find.byKey(const Key('dice_d20_btn')));
      await tester.pump();
      expect(find.textContaining('D20 Roll:'), findsOneWidget);

      // D6 roll
      await tester.tap(find.byKey(const Key('dice_d6_btn')));
      await tester.pump();
      expect(find.textContaining('D6 Roll:'), findsOneWidget);

      // D100 roll
      await tester.tap(find.byKey(const Key('dice_d100_btn')));
      await tester.pump();
      expect(find.textContaining('D100 Roll:'), findsOneWidget);

      await tester.pumpAndSettle();
    });

    testWidgets('Random player and opponent buttons invoke callbacks and update banner', (tester) async {
      int? pickedPlayer;
      int? pickedOpponent;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RandomizerHubModal(
              playerCount: 4,
              selfSeatIndex: 1,
              onPlayerSelected: (seat) => pickedPlayer = seat,
              onOpponentSelected: (seat) => pickedOpponent = seat,
            ),
          ),
        ),
      );

      // Random player
      await tester.tap(find.byKey(const Key('random_player_btn')));
      await tester.pump();
      expect(find.textContaining('Chosen Player: Seat'), findsOneWidget);
      expect(pickedPlayer, isNotNull);
      expect(pickedPlayer!, inInclusiveRange(0, 3));

      // Random opponent (excluding selfSeatIndex = 1)
      await tester.tap(find.byKey(const Key('random_opponent_btn')));
      await tester.pump();
      expect(find.textContaining('Chosen Opponent: Seat'), findsOneWidget);
      expect(pickedOpponent, isNotNull);
      expect(pickedOpponent, isNot(equals(1)));
      expect(pickedOpponent!, inInclusiveRange(0, 3));
    });

    testWidgets('Reset game button triggers callback and closes modal', (tester) async {
      bool resetTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                key: const Key('open_hub_btn'),
                onPressed: () {
                  RandomizerHubModal.show(
                    context: context,
                    playerCount: 4,
                    onResetGame: () => resetTriggered = true,
                  );
                },
                child: const Text('Open Hub'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('open_hub_btn')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('randomizer_hub_modal')), findsOneWidget);

      await tester.tap(find.byKey(const Key('reset_game_btn')));
      await tester.pumpAndSettle();

      expect(resetTriggered, isTrue);
      expect(find.byKey(const Key('randomizer_hub_modal')), findsNothing);
    });
  });
}
