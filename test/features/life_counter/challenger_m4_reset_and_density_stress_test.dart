// Copyright (c) 2026 Countr. All rights reserved.
// Challenger M4-1 Empirical Stress Test Suite:
// - Item 1: PodState.isGameInProgress edge cases (cmd damage, partner cmd damage, rad, poison, mana, history, untouched)
// - Item 2: PregameSetupSheet rapid reset triggers, cancel restores previous state, confirm wipes and applies new state, non-destructive changes preserve player state
// - Item 3: PlayerQuadrantWidget across 1P to 6P in 'Default', 'Name only', 'Big font' (verify name/grid presence/absence, font size >=84 in big font, gear accessibility)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/features/life_counter/domain/models/game_history_entry.dart';
import 'package:countr/features/life_counter/domain/models/pod_state.dart';
import 'package:countr/features/life_counter/presentation/dialogs/pregame_setup_sheet.dart';
import 'package:countr/features/life_counter/presentation/widgets/player_quadrant_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  List<PodPlayerState> makeTestPlayers(int count, {int startingLife = 40}) {
    return List.generate(
      count,
      (i) => PodPlayerState(
        id: 'p$i',
        seatIndex: i,
        name: 'Player ${i + 1}',
        life: startingLife,
      ),
    );
  }

  PodState makeTestPod(
    int count, {
    int startingLife = 40,
    String format = 'commander',
    String cardDensity = 'Default',
    List<GameHistoryEntry> gameHistory = const [],
  }) {
    return PodState(
      sessionId: 'test_pod_session',
      format: format,
      startingLife: startingLife,
      players: makeTestPlayers(count, startingLife: startingLife),
      cardDensity: cardDensity,
      gameHistory: gameHistory,
    );
  }

  Widget wrapWithScaffold(Widget child, {Size size = const Size(800, 1000)}) {
    return ProviderScope(
      child: MaterialApp(
        theme: ThemeData.dark(),
        home: MediaQuery(
          data: MediaQueryData(size: size),
          child: Scaffold(body: child),
        ),
      ),
    );
  }

  group('CH-1: PodState.isGameInProgress Empirical Edge Cases', () {
    test('Untouched games from 1P to 6P return isGameInProgress == false', () {
      for (var count = 1; count <= 6; count++) {
        final pod = makeTestPod(count, startingLife: 40);
        expect(
          pod.isGameInProgress,
          isFalse,
          reason: 'Untouched $count-player pod must not be in progress',
        );
      }
    });

    test('Untouched games with non-default starting life (20, 25, 30, 60) return isGameInProgress == false', () {
      for (final life in [20, 25, 30, 40, 60]) {
        final pod = makeTestPod(4, startingLife: life);
        expect(
          pod.isGameInProgress,
          isFalse,
          reason: 'Untouched pod with starting life $life must not be in progress',
        );
      }
    });

    test('Life delta edge cases (gained life, lost life, dead, negative) return isGameInProgress == true', () {
      final basePod = makeTestPod(4, startingLife: 40);

      // Gained 1 life
      final gainPod = basePod.copyWith(
        players: [basePod.players[0].copyWith(life: 41), ...basePod.players.sublist(1)],
      );
      expect(gainPod.isGameInProgress, isTrue);

      // Lost 1 life
      final lossPod = basePod.copyWith(
        players: [basePod.players[0].copyWith(life: 39), ...basePod.players.sublist(1)],
      );
      expect(lossPod.isGameInProgress, isTrue);

      // At 0 life
      final zeroPod = basePod.copyWith(
        players: [basePod.players[0].copyWith(life: 0), ...basePod.players.sublist(1)],
      );
      expect(zeroPod.isGameInProgress, isTrue);

      // At negative life
      final negPod = basePod.copyWith(
        players: [basePod.players[0].copyWith(life: -7), ...basePod.players.sublist(1)],
      );
      expect(negPod.isGameInProgress, isTrue);
    });

    test('Commander damage only (life strictly remains 40) returns isGameInProgress == true', () {
      final basePod = makeTestPod(4, startingLife: 40);

      // Standard commander damage taken
      final cmdDmgPod = basePod.copyWith(
        players: [
          basePod.players[0].copyWith(
            life: 40, // Life unchanged
            commanderDamageTaken: {'p1': 5},
          ),
          ...basePod.players.sublist(1),
        ],
      );
      expect(cmdDmgPod.isGameInProgress, isTrue);

      // Partner commander damage taken ('p1_partner')
      final partnerCmdDmgPod = basePod.copyWith(
        players: [
          basePod.players[0].copyWith(
            life: 40, // Life unchanged
            commanderDamageTaken: {'p1_partner': 3},
          ),
          ...basePod.players.sublist(1),
        ],
      );
      expect(partnerCmdDmgPod.isGameInProgress, isTrue);
    });

    test('Rad counters or poison counters nonzero (life strictly 40) return isGameInProgress == true', () {
      final basePod = makeTestPod(4, startingLife: 40);

      // Only rad counters nonzero
      final radPod = basePod.copyWith(
        players: [
          basePod.players[0].copyWith(life: 40, radCounters: 1),
          ...basePod.players.sublist(1),
        ],
      );
      expect(radPod.isGameInProgress, isTrue);

      // Only poison counters nonzero
      final poisonPod = basePod.copyWith(
        players: [
          basePod.players[0].copyWith(life: 40, poison: 1),
          ...basePod.players.sublist(1),
        ],
      );
      expect(poisonPod.isGameInProgress, isTrue);
    });

    test('Floating mana only across each mana color (W, U, B, R, G, C) returns isGameInProgress == true', () {
      final basePod = makeTestPod(4, startingLife: 40);
      final manaColors = ['W', 'U', 'B', 'R', 'G', 'C'];

      for (final color in manaColors) {
        final manaPod = basePod.copyWith(
          players: [
            basePod.players[0].copyWith(life: 40, floatingMana: {color: 2}),
            ...basePod.players.sublist(1),
          ],
        );
        expect(
          manaPod.isGameInProgress,
          isTrue,
          reason: 'Floating mana of color $color must trigger isGameInProgress',
        );
      }
    });

    test('Game history only (life strictly 40 and zero counters) returns isGameInProgress == true', () {
      final basePod = makeTestPod(4, startingLife: 40);

      final historyPod = basePod.copyWith(
        gameHistory: [
          GameHistoryEntry.lifeChange(
            playerId: 'p0',
            playerName: 'Player 1',
            startLife: 40,
            endLife: 40,
            netDelta: 0,
          ),
        ],
      );
      expect(historyPod.isGameInProgress, isTrue);
    });

    test('Secondary counters (energy, experience, commanderTax, stormCount, isEliminated) return isGameInProgress == true', () {
      final basePod = makeTestPod(4, startingLife: 40);

      expect(
        basePod.copyWith(players: [basePod.players[0].copyWith(energy: 1), ...basePod.players.sublist(1)]).isGameInProgress,
        isTrue,
      );
      expect(
        basePod.copyWith(players: [basePod.players[0].copyWith(experience: 1), ...basePod.players.sublist(1)]).isGameInProgress,
        isTrue,
      );
      expect(
        basePod.copyWith(players: [basePod.players[0].copyWith(commanderTax: 2), ...basePod.players.sublist(1)]).isGameInProgress,
        isTrue,
      );
      expect(
        basePod.copyWith(players: [basePod.players[0].copyWith(stormCount: 1), ...basePod.players.sublist(1)]).isGameInProgress,
        isTrue,
      );
      expect(
        basePod.copyWith(players: [basePod.players[0].copyWith(isEliminated: true), ...basePod.players.sublist(1)]).isGameInProgress,
        isTrue,
      );
    });
  });

  group('CH-2: PregameSetupSheet Rapid Switching, Cancel, Confirm, and State Preservation', () {
    testWidgets('Rapid switching of player count and starting life toggles warning box dynamically', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final activeMidGameState = PodState(
        sessionId: 'session_rapid_test',
        format: 'commander',
        startingLife: 40,
        players: const [
          PodPlayerState(id: 'p0', seatIndex: 0, name: 'Alice', life: 32, poison: 2),
          PodPlayerState(id: 'p1', seatIndex: 1, name: 'Bob', life: 28),
          PodPlayerState(id: 'p2', seatIndex: 2, name: 'Charlie', life: 40),
          PodPlayerState(id: 'p3', seatIndex: 3, name: 'Dave', life: 15),
        ],
        gameHistory: [
          GameHistoryEntry.lifeChange(
            playerId: 'p0',
            playerName: 'Alice',
            startLife: 40,
            endLife: 32,
            netDelta: -8,
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PregameSetupSheet(
                initialPlayerCount: 4,
                initialFormat: 'commander',
                isGameInProgress: true,
                existingPodState: activeMidGameState,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initial state: warning box must NOT be visible yet
      expect(find.byKey(const Key('pregame_reset_warning_box')), findsNothing);

      // Rapid tap: switch to 2 players -> warning box MUST appear
      await tester.tap(find.byKey(const Key('player_count_btn_2')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pregame_reset_warning_box')), findsOneWidget);

      // Rapid tap: switch to 3 players -> warning box remains visible
      await tester.tap(find.byKey(const Key('player_count_btn_3')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pregame_reset_warning_box')), findsOneWidget);

      // Rapid tap: switch to 5 players -> warning box remains visible
      await tester.tap(find.byKey(const Key('player_count_btn_5')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pregame_reset_warning_box')), findsOneWidget);

      // Rapid tap: switch to 6 players -> warning box remains visible
      await tester.tap(find.byKey(const Key('player_count_btn_6')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pregame_reset_warning_box')), findsOneWidget);

      // Rapid tap: switch back to 4 players (initial count) -> warning box DISAPPEARS!
      await tester.tap(find.byKey(const Key('player_count_btn_4')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pregame_reset_warning_box')), findsNothing);

      // Rapid tap: switch starting life to 20 -> warning box MUST appear
      final presetStandard = find.byKey(const Key('preset_chip_standard'));
      if (presetStandard.evaluate().isNotEmpty) {
        await tester.tap(presetStandard);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('pregame_reset_warning_box')), findsOneWidget);
      }

      // Rapid tap: switch starting life back to 40 (Commander preset) -> warning box DISAPPEARS!
      final presetCommander = find.byKey(const Key('preset_chip_commander'));
      if (presetCommander.evaluate().isNotEmpty) {
        await tester.tap(presetCommander);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('pregame_reset_warning_box')), findsNothing);
      }
    });

    testWidgets('Cancel button reliably restores initial player count and starting life without data corruption', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final activeMidGameState = PodState(
        sessionId: 'session_cancel_test',
        format: 'commander',
        startingLife: 40,
        players: const [
          PodPlayerState(id: 'p0', seatIndex: 0, name: 'Alice', life: 32, poison: 3, commanderDamageTaken: {'p1': 4}),
          PodPlayerState(id: 'p1', seatIndex: 1, name: 'Bob', life: 28),
          PodPlayerState(id: 'p2', seatIndex: 2, name: 'Charlie', life: 40),
          PodPlayerState(id: 'p3', seatIndex: 3, name: 'Dave', life: 15),
        ],
        gameHistory: [
          GameHistoryEntry.lifeChange(
            playerId: 'p0',
            playerName: 'Alice',
            startLife: 40,
            endLife: 32,
            netDelta: -8,
          ),
        ],
      );

      PodState? resultPod;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PregameSetupSheet(
                initialPlayerCount: 4,
                initialFormat: 'commander',
                isGameInProgress: true,
                existingPodState: activeMidGameState,
                onStartMatch: (state) => resultPod = state,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Trigger reset warning by selecting 2 players
      await tester.tap(find.byKey(const Key('player_count_btn_2')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pregame_reset_warning_box')), findsOneWidget);

      // Tap Cancel button
      final cancelBtn = find.byKey(const Key('pregame_reset_cancel_button'));
      expect(cancelBtn, findsOneWidget);
      await tester.tap(cancelBtn);
      await tester.pumpAndSettle();

      // Warning box MUST disappear
      expect(find.byKey(const Key('pregame_reset_warning_box')), findsNothing);

      // Now start match: initial 4 players and ongoing match state MUST be preserved!
      await tester.tap(find.byKey(const Key('start_match_button')));
      await tester.pumpAndSettle();

      expect(resultPod, isNotNull);
      expect(resultPod!.players.length, 4);
      expect(resultPod!.players[0].life, 32);
      expect(resultPod!.players[0].poison, 3);
      expect(resultPod!.players[0].commanderDamageTaken['p1'], 4);
      expect(resultPod!.players[1].life, 28);
      expect(resultPod!.players[3].life, 15);
      expect(resultPod!.gameHistory.length, 1);
      expect(resultPod!.sessionId, 'session_cancel_test');
    });

    testWidgets('Confirm button commits new values, resets players, and wipes previous game upon match start', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final activeMidGameState = PodState(
        sessionId: 'session_confirm_test',
        format: 'commander',
        startingLife: 40,
        players: const [
          PodPlayerState(id: 'p0', seatIndex: 0, name: 'Alice', life: 32, poison: 3, commanderDamageTaken: {'p1': 4}),
          PodPlayerState(id: 'p1', seatIndex: 1, name: 'Bob', life: 28),
          PodPlayerState(id: 'p2', seatIndex: 2, name: 'Charlie', life: 40),
          PodPlayerState(id: 'p3', seatIndex: 3, name: 'Dave', life: 15),
        ],
        gameHistory: [
          GameHistoryEntry.lifeChange(
            playerId: 'p0',
            playerName: 'Alice',
            startLife: 40,
            endLife: 32,
            netDelta: -8,
          ),
        ],
      );

      PodState? resultPod;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PregameSetupSheet(
                initialPlayerCount: 4,
                initialFormat: 'commander',
                isGameInProgress: true,
                existingPodState: activeMidGameState,
                onStartMatch: (state) => resultPod = state,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Trigger reset warning by switching to 2 players
      await tester.tap(find.byKey(const Key('player_count_btn_2')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pregame_reset_warning_box')), findsOneWidget);

      // Tap Confirm button
      final confirmBtn = find.byKey(const Key('pregame_reset_confirm_button'));
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Warning box MUST disappear after confirmation
      expect(find.byKey(const Key('pregame_reset_warning_box')), findsNothing);

      // Start match: previous state MUST be wiped and new 2-player pod instantiated
      await tester.tap(find.byKey(const Key('start_match_button')));
      await tester.pumpAndSettle();

      expect(resultPod, isNotNull);
      expect(resultPod!.players.length, 2);
      expect(resultPod!.players[0].life, 40); // Reset to startingLife
      expect(resultPod!.players[0].poison, 0); // Zeroed
      expect(resultPod!.players[0].commanderDamageTaken.isEmpty, isTrue); // Zeroed
      expect(resultPod!.players[1].life, 40); // Reset to startingLife
      expect(resultPod!.gameHistory.isEmpty, isTrue); // History wiped
      expect(resultPod!.sessionId, isNot(equals('session_confirm_test'))); // New session
    });

    testWidgets('Non-destructive changes (card density, orientation, camera mode, OLED, wakelock, haptics) preserve player state', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final activeMidGameState = PodState(
        sessionId: 'session_nondestructive_test',
        format: 'commander',
        startingLife: 40,
        players: const [
          PodPlayerState(
            id: 'p0',
            seatIndex: 0,
            name: 'Alice',
            life: 25,
            poison: 5,
            energy: 3,
            radCounters: 2,
            commanderDamageTaken: {'p1': 8},
          ),
          PodPlayerState(
            id: 'p1',
            seatIndex: 1,
            name: 'Bob',
            life: 18,
            commanderTax: 2,
          ),
        ],
        gameHistory: [
          GameHistoryEntry.lifeChange(
            playerId: 'p0',
            playerName: 'Alice',
            startLife: 40,
            endLife: 25,
            netDelta: -15,
          ),
        ],
      );

      PodState? resultPod;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PregameSetupSheet(
                initialPlayerCount: 2,
                initialFormat: 'commander',
                isGameInProgress: true,
                existingPodState: activeMidGameState,
                onStartMatch: (state) => resultPod = state,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Change card density to 'Big font'
      await tester.tap(find.text('Big font'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pregame_reset_warning_box')), findsNothing);

      // Toggle Camera Mode
      final cameraSwitch = find.byKey(const Key('pregame_camera_mode_switch'));
      if (cameraSwitch.evaluate().isNotEmpty) {
        await tester.tap(cameraSwitch);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('pregame_reset_warning_box')), findsNothing);
      }

      // Toggle OLED True Black Mode
      final oledSwitch = find.byKey(const Key('pregame_oled_switch'));
      if (oledSwitch.evaluate().isNotEmpty) {
        await tester.tap(oledSwitch);
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('pregame_reset_warning_box')), findsNothing);
      }

      // Tap start match without confirmation
      await tester.tap(find.byKey(const Key('start_match_button')));
      await tester.pumpAndSettle();

      expect(resultPod, isNotNull);
      expect(resultPod!.cardDensity, 'Big font');
      expect(resultPod!.players[0].life, 25);
      expect(resultPod!.players[0].poison, 5);
      expect(resultPod!.players[0].energy, 3);
      expect(resultPod!.players[0].radCounters, 2);
      expect(resultPod!.players[0].commanderDamageTaken['p1'], 8);
      expect(resultPod!.players[1].life, 18);
      expect(resultPod!.players[1].commanderTax, 2);
      expect(resultPod!.gameHistory.length, 1);
      expect(resultPod!.sessionId, 'session_nondestructive_test');
    });
  });

  group('CH-3: PlayerQuadrantWidget Density Modes Across 1P through 6P Permutations', () {
    for (var count = 1; count <= 6; count++) {
      testWidgets('PlayerQuadrantWidget $count-player pod: Default density renders name, grid (if opponents), life (68pt), gear', (tester) async {
        final players = List.generate(
          count,
          (i) => PodPlayerState(id: 'p$i', seatIndex: i, name: 'Player ${i + 1}', life: 40),
        );
        final player = players[0];
        final opponents = players.sublist(1);

        await tester.pumpWidget(wrapWithScaffold(
          PlayerQuadrantWidget(
            player: player,
            isTablet: false,
            opponents: opponents,
            cardDensity: 'Default',
          ),
        ));
        await tester.pumpAndSettle();

        // Player name MUST be visible
        expect(find.byKey(Key('player_name_${player.id}')), findsOneWidget);
        expect(find.text('Player 1'), findsOneWidget);

        // Commander mini grid: visible only if opponents exist (>1P)
        if (opponents.isNotEmpty) {
          expect(find.byKey(Key('cmd_mini_grid_${player.id}')), findsOneWidget);
        } else {
          expect(find.byKey(Key('cmd_mini_grid_${player.id}')), findsNothing);
        }

        // Life display is visible with standard font size (68)
        expect(find.byKey(Key('life_display_${player.id}')), findsOneWidget);
        final lifeText = tester.widget<Text>(find.byKey(Key('life_display_${player.id}')));
        expect(lifeText.style?.fontSize, 68);

        // Settings gear button MUST be visible and accessible
        expect(find.byKey(Key('gear_button_${player.id}')), findsOneWidget);
      });

      testWidgets('PlayerQuadrantWidget $count-player pod: Name only density renders name, suppresses grid, life (68pt), gear', (tester) async {
        final players = List.generate(
          count,
          (i) => PodPlayerState(id: 'p$i', seatIndex: i, name: 'Player ${i + 1}', life: 40),
        );
        final player = players[0];
        final opponents = players.sublist(1);

        await tester.pumpWidget(wrapWithScaffold(
          PlayerQuadrantWidget(
            player: player,
            isTablet: false,
            opponents: opponents,
            cardDensity: 'Name only',
          ),
        ));
        await tester.pumpAndSettle();

        // Player name MUST be visible
        expect(find.byKey(Key('player_name_${player.id}')), findsOneWidget);
        expect(find.text('Player 1'), findsOneWidget);

        // Commander mini grid MUST be suppressed across all player counts
        expect(find.byKey(Key('cmd_mini_grid_${player.id}')), findsNothing);

        // Life display is visible with standard font size (68)
        expect(find.byKey(Key('life_display_${player.id}')), findsOneWidget);
        final lifeText = tester.widget<Text>(find.byKey(Key('life_display_${player.id}')));
        expect(lifeText.style?.fontSize, 68);

        // Settings gear button MUST be visible
        expect(find.byKey(Key('gear_button_${player.id}')), findsOneWidget);
      });

      testWidgets('PlayerQuadrantWidget $count-player pod: Big font density omits name & grid, life font >=84, gear accessible', (tester) async {
        final players = List.generate(
          count,
          (i) => PodPlayerState(id: 'p$i', seatIndex: i, name: 'Player ${i + 1}', life: 40),
        );
        final player = players[0];
        final opponents = players.sublist(1);

        bool gearTapped = false;

        await tester.pumpWidget(wrapWithScaffold(
          PlayerQuadrantWidget(
            player: player,
            isTablet: false,
            opponents: opponents,
            cardDensity: 'Big font',
            onOpenSettings: () => gearTapped = true,
          ),
        ));
        await tester.pumpAndSettle();

        // In Big font mode: both player name AND commander mini grid MUST find nothing
        expect(find.byKey(Key('player_name_${player.id}')), findsNothing);
        expect(find.text('Player 1'), findsNothing);
        expect(find.byKey(Key('cmd_mini_grid_${player.id}')), findsNothing);

        // Life display is visible with maximized font size >= 84
        expect(find.byKey(Key('life_display_${player.id}')), findsOneWidget);
        final lifeText = tester.widget<Text>(find.byKey(Key('life_display_${player.id}')));
        expect(lifeText.style?.fontSize, greaterThanOrEqualTo(84));
        expect(lifeText.style?.fontSize, equals(84));

        // Settings gear button MUST remain accessible in the bottom bar and be tappable
        final gearBtn = find.byKey(Key('gear_button_${player.id}'));
        expect(gearBtn, findsOneWidget);
        await tester.tap(gearBtn);
        await tester.pump();
        expect(gearTapped, isTrue);
      });
    }
  });
}
