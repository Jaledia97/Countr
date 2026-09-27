// Copyright (c) 2026 Countr. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/features/life_counter/domain/models/pod_state.dart';
import 'package:countr/features/life_counter/presentation/dialogs/player_roulette_overlay.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mockPlayers = [
    const PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40),
    const PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40),
    const PodPlayerState(id: 'p3', seatIndex: 2, name: 'Charlie', life: 40),
    const PodPlayerState(id: 'p4', seatIndex: 3, name: 'David', life: 40),
  ];

  group('PlayerRouletteOverlay Widget Tests', () {
    testWidgets('Initializes with pod seats and renders roulette_spin_btn', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlayerRouletteOverlay(
              players: mockPlayers,
              playerCount: 4,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('player_roulette_overlay')), findsOneWidget);
      expect(find.byKey(const Key('roulette_spin_btn')), findsOneWidget);
      expect(find.byKey(const Key('roulette_seat_card_0')), findsOneWidget);
      expect(find.byKey(const Key('roulette_seat_card_1')), findsOneWidget);
      expect(find.byKey(const Key('roulette_seat_card_2')), findsOneWidget);
      expect(find.byKey(const Key('roulette_seat_card_3')), findsOneWidget);
      expect(find.byKey(const Key('chosen_player_banner')), findsNothing);
    });

    testWidgets('Tapping roulette_spin_btn executes cycling animation and selects target seat', (tester) async {
      int? selectedSeat;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlayerRouletteOverlay(
              players: mockPlayers,
              playerCount: 4,
              targetSeatIndex: 2, // Charlie
              spinDuration: const Duration(milliseconds: 600),
              onPlayerSelected: (seat) => selectedSeat = seat,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('roulette_spin_btn')));
      await tester.pump();

      // Halfway through animation: cycling active
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Decelerating...'), findsOneWidget);

      // Finish animation
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      // Celebration fanfare banner displayed
      expect(find.byKey(const Key('chosen_player_banner')), findsOneWidget);
      expect(find.text('Charlie Goes First!'), findsOneWidget);
      expect(find.text('Chosen Player: Seat 3'), findsOneWidget);
      expect(selectedSeat, 2);
    });

    testWidgets('Roulette properly adapts to 2-player 1v1 and 6-player pod configurations', (tester) async {
      // 2-player
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PlayerRouletteOverlay(playerCount: 2),
          ),
        ),
      );
      expect(find.byKey(const Key('roulette_seat_card_0')), findsOneWidget);
      expect(find.byKey(const Key('roulette_seat_card_1')), findsOneWidget);
      expect(find.byKey(const Key('roulette_seat_card_2')), findsNothing);

      // 6-player
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PlayerRouletteOverlay(playerCount: 6),
          ),
        ),
      );
      expect(find.byKey(const Key('roulette_seat_card_0')), findsOneWidget);
      expect(find.byKey(const Key('roulette_seat_card_1')), findsOneWidget);
      expect(find.byKey(const Key('roulette_seat_card_2')), findsOneWidget);
      expect(find.byKey(const Key('roulette_seat_card_3')), findsOneWidget);
      expect(find.byKey(const Key('roulette_seat_card_4')), findsOneWidget);
      expect(find.byKey(const Key('roulette_seat_card_5')), findsOneWidget);
    });

    testWidgets('Roulette supports excludedSeatIndex for opponent selection', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlayerRouletteOverlay(
              players: mockPlayers,
              playerCount: 4,
              excludedSeatIndex: 1, // Exclude Bob
            ),
          ),
        ),
      );

      expect(find.text('(Self - Excluded)'), findsOneWidget);
    });

    testWidgets('Static show helper opens bottom sheet modal', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                key: const Key('open_roulette_btn'),
                onPressed: () {
                  PlayerRouletteOverlay.show(
                    ctx,
                    players: mockPlayers,
                    autoStart: false,
                  );
                },
                child: const Text('Open Roulette'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('open_roulette_btn')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('player_roulette_overlay')), findsOneWidget);
    });
  });
}
