// Copyright (c) 2026 Countr. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/features/life_counter/domain/models/pod_state.dart';
import 'package:countr/features/life_counter/presentation/controllers/pod_controller.dart';
import 'package:countr/features/life_counter/presentation/dialogs/reset_game_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ResetGameDialog & PodController Reset Integration Tests', () {
    testWidgets('ResetGameDialog displays prompt and confirms reset', (tester) async {
      bool resetConfirmed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                key: const Key('trigger_reset_btn'),
                onPressed: () {
                  ResetGameDialog.show(
                    ctx,
                    startingLife: 40,
                    onConfirm: () => resetConfirmed = true,
                  );
                },
                child: const Text('Reset'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('trigger_reset_btn')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('reset_game_dialog')), findsOneWidget);
      expect(
        find.text(
          'Reset current game? Life totals will return to 40 and all counters/mana will be cleared. Seating and commanders will be preserved.',
        ),
        findsOneWidget,
      );

      // Tap confirm
      await tester.tap(find.byKey(const Key('confirm_reset_game_btn')));
      await tester.pumpAndSettle();

      expect(resetConfirmed, isTrue);
      expect(find.byKey(const Key('reset_game_dialog')), findsNothing);
    });

    testWidgets('ResetGameDialog cancel button dismisses without confirming', (tester) async {
      bool resetConfirmed = false;
      bool resetCancelled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                key: const Key('trigger_reset_btn'),
                onPressed: () {
                  ResetGameDialog.show(
                    ctx,
                    startingLife: 40,
                    onConfirm: () => resetConfirmed = true,
                    onCancel: () => resetCancelled = true,
                  );
                },
                child: const Text('Reset'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('trigger_reset_btn')));
      await tester.pumpAndSettle();

      // Tap cancel
      await tester.tap(find.byKey(const Key('cancel_reset_game_btn')));
      await tester.pumpAndSettle();

      expect(resetConfirmed, isFalse);
      expect(resetCancelled, isTrue);
      expect(find.byKey(const Key('reset_game_dialog')), findsNothing);
    });

    test('PodController.resetGame restores life and clears counters while preserving seating and deck profiles', () async {
      final initialPod = PodState(
        sessionId: 'session_reset_test',
        format: 'commander',
        startingLife: 40,
        players: [
          const PodPlayerState(
            id: 'p1',
            seatIndex: 0,
            name: 'Alice',
            deckId: 'deck_alice',
            commanderName: 'Atraxa',
            commanderArtCropUrl: 'https://example.com/atraxa.jpg',
            life: 14,
            poison: 4,
            energy: 3,
            experience: 2,
            commanderTax: 4,
            isMonarch: true,
            hasInitiative: false,
            commanderDamageTaken: {'p2': 18},
            floatingMana: {'W': 2, 'U': 1, 'B': 0, 'R': 0, 'G': 0, 'C': 0},
            stormCount: 5,
          ),
          const PodPlayerState(
            id: 'p2',
            seatIndex: 1,
            name: 'Bob',
            deckId: 'deck_bob',
            commanderName: 'Urza',
            commanderArtCropUrl: 'https://example.com/urza.jpg',
            life: 28,
            poison: 0,
            energy: 1,
            experience: 0,
            commanderTax: 2,
            isMonarch: false,
            hasInitiative: true,
            commanderDamageTaken: {'p1': 6},
            floatingMana: {'W': 0, 'U': 4, 'B': 0, 'R': 0, 'G': 0, 'C': 2},
            stormCount: 2,
          ),
        ],
      );

      final controller = PodController(initialState: initialPod);

      // Verify dirty board state
      expect(controller.state.players[0].life, 14);
      expect(controller.state.players[0].poison, 4);
      expect(controller.state.players[0].isMonarch, isTrue);
      expect(controller.state.players[0].stormCount, 5);

      // Execute Reset Game
      await controller.resetGame();

      final resetPod = controller.state;
      expect(resetPod.startingLife, 40);

      // Player 1 assertions
      final p1 = resetPod.players[0];
      expect(p1.life, 40);
      expect(p1.poison, 0);
      expect(p1.energy, 0);
      expect(p1.experience, 0);
      expect(p1.commanderTax, 0);
      expect(p1.isMonarch, isFalse);
      expect(p1.hasInitiative, isFalse);
      expect(p1.commanderDamageTaken.isEmpty, isTrue);
      expect(p1.floatingMana, {'W': 0, 'U': 0, 'B': 0, 'R': 0, 'G': 0, 'C': 0});
      expect(p1.stormCount, 0);
      // Strictly preserved seating & metadata
      expect(p1.id, 'p1');
      expect(p1.seatIndex, 0);
      expect(p1.name, 'Alice');
      expect(p1.deckId, 'deck_alice');
      expect(p1.commanderName, 'Atraxa');
      expect(p1.commanderArtCropUrl, 'https://example.com/atraxa.jpg');

      // Player 2 assertions
      final p2 = resetPod.players[1];
      expect(p2.life, 40);
      expect(p2.poison, 0);
      expect(p2.commanderTax, 0);
      expect(p2.hasInitiative, isFalse);
      expect(p2.commanderDamageTaken.isEmpty, isTrue);
      // Strictly preserved seating & metadata
      expect(p2.id, 'p2');
      expect(p2.seatIndex, 1);
      expect(p2.name, 'Bob');
      expect(p2.deckId, 'deck_bob');
      expect(p2.commanderName, 'Urza');
      expect(p2.commanderArtCropUrl, 'https://example.com/urza.jpg');
    });

    test('PodController.resetGame with startingLifeOverride changes life template', () async {
      final initialPod = PodState(
        sessionId: 'session_override_test',
        format: 'commander',
        startingLife: 40,
        players: [
          const PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 12),
        ],
      );

      final controller = PodController(initialState: initialPod);
      await controller.resetGame(20);

      expect(controller.state.startingLife, 20);
      expect(controller.state.players[0].life, 20);
    });
  });
}
