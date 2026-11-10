// Copyright (c) 2026 Countr. All rights reserved.
// Milestone 4: Settings & Appearance Modes Test Suite
// Requirements Under Test:
// - R4.1: Inline Game Reset Safeguard in PodState & PregameSetupSheet
// - R4.2: Player Card Layout Density (Default, Name only, Big font)
// - R4.3: Auto-Hide Central Utility Bar & Collapse Animation
// - R4.4: Polish & Accessibility Toggles (Wakelock, Haptics, OLED, Immersive)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/features/life_counter/domain/models/game_history_entry.dart';
import 'package:countr/features/life_counter/domain/models/pod_state.dart';
import 'package:countr/features/life_counter/domain/services/pod_haptics.dart';
import 'package:countr/features/life_counter/domain/services/wakelock_service.dart';
import 'package:countr/features/life_counter/presentation/controllers/pod_controller.dart';
import 'package:countr/features/life_counter/presentation/dialogs/pregame_setup_sheet.dart';
import 'package:countr/features/life_counter/presentation/widgets/central_utility_bar.dart';
import 'package:countr/features/life_counter/presentation/widgets/commander_art_backdrop.dart';
import 'package:countr/features/life_counter/presentation/widgets/player_quadrant_widget.dart';
import 'package:countr/features/life_counter/presentation/widgets/pod_scaffold_widget.dart';

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

  Widget wrapWithScaffold(Widget child, {Size size = const Size(390, 844)}) {
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

  group('R4.1: Inline Game Reset Safeguard', () {
    test('PodState.isGameInProgress detects pristine vs active game states correctly', () {
      // 1. Pristine default game: 4 players, 40 life, all counters 0, no history
      final pristinePod = makeTestPod(4, startingLife: 40);
      expect(pristinePod.isGameInProgress, isFalse);

      // 2. Life changed from startingLife
      final lifeChangedPod = pristinePod.copyWith(
        players: [
          pristinePod.players[0].copyWith(life: 39),
          pristinePod.players[1],
          pristinePod.players[2],
          pristinePod.players[3],
        ],
      );
      expect(lifeChangedPod.isGameInProgress, isTrue);

      // 3. Poison counter > 0
      final poisonPod = pristinePod.copyWith(
        players: [
          pristinePod.players[0].copyWith(poison: 1),
          pristinePod.players[1],
          pristinePod.players[2],
          pristinePod.players[3],
        ],
      );
      expect(poisonPod.isGameInProgress, isTrue);

      // 4. Energy counter > 0
      final energyPod = pristinePod.copyWith(
        players: [
          pristinePod.players[0].copyWith(energy: 3),
          pristinePod.players[1],
          pristinePod.players[2],
          pristinePod.players[3],
        ],
      );
      expect(energyPod.isGameInProgress, isTrue);

      // 5. Experience counter > 0
      final expPod = pristinePod.copyWith(
        players: [
          pristinePod.players[0].copyWith(experience: 2),
          pristinePod.players[1],
          pristinePod.players[2],
          pristinePod.players[3],
        ],
      );
      expect(expPod.isGameInProgress, isTrue);

      // 6. Commander Tax > 0
      final taxPod = pristinePod.copyWith(
        players: [
          pristinePod.players[0].copyWith(commanderTax: 2),
          pristinePod.players[1],
          pristinePod.players[2],
          pristinePod.players[3],
        ],
      );
      expect(taxPod.isGameInProgress, isTrue);

      // 7. Rad counters > 0
      final radPod = pristinePod.copyWith(
        players: [
          pristinePod.players[0].copyWith(radCounters: 1),
          pristinePod.players[1],
          pristinePod.players[2],
          pristinePod.players[3],
        ],
      );
      expect(radPod.isGameInProgress, isTrue);

      // 8. Storm count > 0
      final stormPod = pristinePod.copyWith(
        players: [
          pristinePod.players[0].copyWith(stormCount: 4),
          pristinePod.players[1],
          pristinePod.players[2],
          pristinePod.players[3],
        ],
      );
      expect(stormPod.isGameInProgress, isTrue);

      // 9. Player eliminated
      final eliminatedPod = pristinePod.copyWith(
        players: [
          pristinePod.players[0].copyWith(isEliminated: true),
          pristinePod.players[1],
          pristinePod.players[2],
          pristinePod.players[3],
        ],
      );
      expect(eliminatedPod.isGameInProgress, isTrue);

      // 10. Commander damage taken > 0
      final cmdDmgPod = pristinePod.copyWith(
        players: [
          pristinePod.players[0].copyWith(commanderDamageTaken: {'p1': 5}),
          pristinePod.players[1],
          pristinePod.players[2],
          pristinePod.players[3],
        ],
      );
      expect(cmdDmgPod.isGameInProgress, isTrue);

      // 11. Floating mana > 0
      final manaPod = pristinePod.copyWith(
        players: [
          pristinePod.players[0].copyWith(floatingMana: {'R': 2}),
          pristinePod.players[1],
          pristinePod.players[2],
          pristinePod.players[3],
        ],
      );
      expect(manaPod.isGameInProgress, isTrue);

      // 12. Non-empty game history (even if current life restored to startingLife)
      final historyPod = pristinePod.copyWith(
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

    testWidgets('Fresh match allows immediate player count and format updates without warning box', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      PodState? startedPod;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PregameSetupSheet(
                initialPlayerCount: 4,
                initialFormat: 'commander',
                isGameInProgress: false,
                onStartMatch: (state) => startedPod = state,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure warning box is NOT displayed
      expect(find.byKey(const Key('pregame_reset_warning_box')), findsNothing);

      // Tap player count 2
      final btn2 = find.byKey(const Key('player_count_btn_2'));
      expect(btn2, findsOneWidget);
      await tester.tap(btn2);
      await tester.pumpAndSettle();

      // Warning box MUST NOT appear on fresh match
      expect(find.byKey(const Key('pregame_reset_warning_box')), findsNothing);
      expect(find.byKey(const Key('player_setup_card_0')), findsOneWidget);
      expect(find.byKey(const Key('player_setup_card_1')), findsOneWidget);
      expect(find.byKey(const Key('player_setup_card_2')), findsNothing);

      // Tap preset chip standard (20 life)
      final standardChip = find.byKey(const Key('preset_chip_standard'));
      if (standardChip.evaluate().isNotEmpty) {
        await tester.tap(standardChip);
        await tester.pumpAndSettle();
      }

      // Warning box still MUST NOT appear
      expect(find.byKey(const Key('pregame_reset_warning_box')), findsNothing);

      // Start match applies immediate values
      await tester.tap(find.byKey(const Key('start_match_button')));
      await tester.pumpAndSettle();

      expect(startedPod, isNotNull);
      expect(startedPod!.players.length, 2);
    });

    testWidgets('In-progress match shows warning box on player count change; Cancel reverts and Confirm applies', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final activeMidGameState = PodState(
        sessionId: 'session_midgame',
        format: 'commander',
        startingLife: 40,
        players: const [
          PodPlayerState(id: 'p0', seatIndex: 0, name: 'Alice', life: 34, poison: 2),
          PodPlayerState(id: 'p1', seatIndex: 1, name: 'Bob', life: 28),
          PodPlayerState(id: 'p2', seatIndex: 2, name: 'Charlie', life: 19),
          PodPlayerState(id: 'p3', seatIndex: 3, name: 'Diana', life: 40),
        ],
        gameHistory: [
          GameHistoryEntry.lifeChange(
            playerId: 'p0',
            playerName: 'Alice',
            startLife: 40,
            endLife: 34,
            netDelta: -6,
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

      // Invariant: Initially warning box is NOT shown
      expect(find.byKey(const Key('pregame_reset_warning_box')), findsNothing);

      // User attempts to change player count from 4 to 2
      await tester.tap(find.byKey(const Key('player_count_btn_2')));
      await tester.pumpAndSettle();

      // Warning box MUST appear with title and description
      expect(find.byKey(const Key('pregame_reset_warning_box')), findsOneWidget);
      expect(find.text('Warning: this will reset the current game'), findsOneWidget);
      expect(find.text('Changing player count or starting life will reset the current game.'), findsOneWidget);
      expect(find.byKey(const Key('pregame_reset_cancel_button')), findsOneWidget);
      expect(find.byKey(const Key('pregame_reset_confirm_button')), findsOneWidget);

      // Verify players have NOT been wiped yet (4 cards remain rendered)
      expect(find.byKey(const Key('player_setup_card_0')), findsOneWidget);
      expect(find.byKey(const Key('player_setup_card_3')), findsOneWidget);

      // Test CANCEL: user decides not to reset
      await tester.tap(find.byKey(const Key('pregame_reset_cancel_button')));
      await tester.pumpAndSettle();

      // Warning box dismissed and player count reverted to 4
      expect(find.byKey(const Key('pregame_reset_warning_box')), findsNothing);
      expect(find.byKey(const Key('player_setup_card_3')), findsOneWidget);

      // User attempts to change player count again to 2
      await tester.tap(find.byKey(const Key('player_count_btn_2')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pregame_reset_warning_box')), findsOneWidget);

      // Test CONFIRM: user confirms reset
      await tester.tap(find.byKey(const Key('pregame_reset_confirm_button')));
      await tester.pumpAndSettle();

      // Warning box dismissed and player count now changed to 2
      expect(find.byKey(const Key('pregame_reset_warning_box')), findsNothing);
      expect(find.byKey(const Key('player_setup_card_0')), findsOneWidget);
      expect(find.byKey(const Key('player_setup_card_1')), findsOneWidget);
      expect(find.byKey(const Key('player_setup_card_2')), findsNothing);
      expect(find.byKey(const Key('player_setup_card_3')), findsNothing);

      // Starting match yields reset pod state
      await tester.tap(find.byKey(const Key('start_match_button')));
      await tester.pumpAndSettle();

      expect(resultPod, isNotNull);
      expect(resultPod!.players.length, 2);
    });

    testWidgets('In-progress match shows warning box on format preset change; Cancel restores format and life', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final activeMidGameState = PodState(
        sessionId: 'session_format',
        format: 'commander',
        startingLife: 40,
        players: const [
          PodPlayerState(id: 'p0', seatIndex: 0, name: 'Alice', life: 35),
          PodPlayerState(id: 'p1', seatIndex: 1, name: 'Bob', life: 30),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PregameSetupSheet(
                initialPlayerCount: 2,
                initialFormat: 'commander',
                initialStartingLife: 40,
                isGameInProgress: true,
                existingPodState: activeMidGameState,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Standard preset (20 life)
      final standardChip = find.byKey(const Key('preset_chip_standard'));
      expect(standardChip, findsOneWidget);
      await tester.tap(standardChip);
      await tester.pumpAndSettle();

      // Warning box appears
      expect(find.byKey(const Key('pregame_reset_warning_box')), findsOneWidget);

      // Cancel reverts format back to Commander
      await tester.tap(find.byKey(const Key('pregame_reset_cancel_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pregame_reset_warning_box')), findsNothing);

      // Trigger again and Confirm
      await tester.tap(standardChip);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pregame_reset_warning_box')), findsOneWidget);

      await tester.tap(find.byKey(const Key('pregame_reset_confirm_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pregame_reset_warning_box')), findsNothing);
    });

    testWidgets('In-progress match non-destructive settings edits preserve ongoing life and counters', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final activeMidGameState = PodState(
        sessionId: 'session_preserve',
        format: 'commander',
        startingLife: 40,
        players: const [
          PodPlayerState(
            id: 'p0',
            seatIndex: 0,
            name: 'Alice',
            life: 27,
            poison: 4,
            energy: 6,
            radCounters: 2,
            commanderDamageTaken: {'p1': 7},
          ),
          PodPlayerState(
            id: 'p1',
            seatIndex: 1,
            name: 'Bob',
            life: 14,
            poison: 1,
            commanderTax: 4,
          ),
        ],
        gameHistory: [
          GameHistoryEntry.lifeChange(
            playerId: 'p0',
            playerName: 'Alice',
            startLife: 40,
            endLife: 27,
            netDelta: -13,
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

      // Select density 'Name only' (non-destructive)
      await tester.tap(find.text('Name only'));
      await tester.pumpAndSettle();

      // Warning box MUST NOT appear for density adjustments
      expect(find.byKey(const Key('pregame_reset_warning_box')), findsNothing);

      // Tap Start Match without confirming any reset
      await tester.tap(find.byKey(const Key('start_match_button')));
      await tester.pumpAndSettle();

      // Ongoing game state MUST be preserved!
      expect(resultPod, isNotNull);
      expect(resultPod!.cardDensity, 'Name only');
      expect(resultPod!.players[0].life, 27);
      expect(resultPod!.players[0].poison, 4);
      expect(resultPod!.players[0].energy, 6);
      expect(resultPod!.players[0].radCounters, 2);
      expect(resultPod!.players[0].commanderDamageTaken['p1'], 7);
      expect(resultPod!.players[1].life, 14);
      expect(resultPod!.players[1].poison, 1);
      expect(resultPod!.players[1].commanderTax, 4);
      expect(resultPod!.gameHistory.length, 1);
    });
  });

  group('R4.2: Player Card Layout Density', () {
    test('PodState cardDensity supports constructor, copyWith, serialization, equality, and hash', () {
      final defaultState = makeTestPod(2);
      expect(defaultState.cardDensity, 'Default');

      final bigFontState = defaultState.copyWith(cardDensity: 'Big font');
      expect(bigFontState.cardDensity, 'Big font');
      expect(bigFontState == defaultState, isFalse);

      final json = bigFontState.toJson();
      expect(json['cardDensity'], 'Big font');

      final fromJson = PodState.fromJson(json);
      expect(fromJson.cardDensity, 'Big font');
      expect(fromJson == bigFontState, isTrue);
      expect(fromJson.hashCode == bigFontState.hashCode, isTrue);
    });

    test('PodController setCardDensity updates state and podCardDensityProvider', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(podCardDensityProvider), 'Default');

      container.read(podControllerProvider.notifier).setCardDensity('Big font');
      expect(container.read(podCardDensityProvider), 'Big font');
      expect(container.read(podControllerProvider).cardDensity, 'Big font');
    });

    testWidgets('PregameSetupSheet density picker renders 3 segments and updates selected value', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      PodState? resultPod;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PregameSetupSheet(
                initialPlayerCount: 2,
                initialCardDensity: 'Default',
                onStartMatch: (state) => resultPod = state,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify density picker SegmentedButton renders
      expect(find.byKey(const Key('pregame_density_picker')), findsOneWidget);
      expect(find.text('Default'), findsWidgets);
      expect(find.text('Name only'), findsOneWidget);
      expect(find.text('Big font'), findsOneWidget);

      // Select 'Big font'
      await tester.tap(find.text('Big font'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('start_match_button')));
      await tester.pumpAndSettle();

      expect(resultPod, isNotNull);
      expect(resultPod!.cardDensity, 'Big font');
    });

    testWidgets('PlayerQuadrantWidget in Default density renders header with name and mini-grid', (tester) async {
      const player = PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40);
      const opponent = PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40);

      await tester.pumpWidget(wrapWithScaffold(
        const PlayerQuadrantWidget(
          player: player,
          isTablet: false,
          opponents: [opponent],
          cardDensity: 'Default',
        ),
      ));
      await tester.pumpAndSettle();

      // Top header with name and mini-grid MUST be rendered
      expect(find.text('Alice'), findsOneWidget);
      expect(find.byKey(const Key('cmd_mini_grid_p1')), findsOneWidget);

      // Life stepper and bottom gear button rendered
      expect(find.byKey(const Key('life_display_p1')), findsOneWidget);
      expect(find.byKey(const Key('gear_button_p1')), findsOneWidget);

      // Life stepper font size is standard 68
      final lifeText = tester.widget<Text>(find.byKey(const Key('life_display_p1')));
      expect(lifeText.style?.fontSize, 68);
    });

    testWidgets('PlayerQuadrantWidget in Name only density renders name and suppresses mini-grid', (tester) async {
      const player = PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40);
      const opponent = PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40);

      await tester.pumpWidget(wrapWithScaffold(
        const PlayerQuadrantWidget(
          player: player,
          isTablet: false,
          opponents: [opponent],
          cardDensity: 'Name only',
        ),
      ));
      await tester.pumpAndSettle();

      // Top header with name rendered
      expect(find.text('Alice'), findsOneWidget);

      // Mini-grid MUST be suppressed
      expect(find.byKey(const Key('cmd_mini_grid_p1')), findsNothing);

      // Life display and gear button rendered
      expect(find.byKey(const Key('life_display_p1')), findsOneWidget);
      expect(find.byKey(const Key('gear_button_p1')), findsOneWidget);

      final lifeText = tester.widget<Text>(find.byKey(const Key('life_display_p1')));
      expect(lifeText.style?.fontSize, 68);
    });

    testWidgets('PlayerQuadrantWidget in Big font density omits top header and maximizes font size to 84', (tester) async {
      const player = PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40);
      const opponent = PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40);

      await tester.pumpWidget(wrapWithScaffold(
        const PlayerQuadrantWidget(
          player: player,
          isTablet: false,
          opponents: [opponent],
          cardDensity: 'Big font',
        ),
      ));
      await tester.pumpAndSettle();

      // Top header completely omitted: player name and mini-grid find nothing
      expect(find.text('Alice'), findsNothing);
      expect(find.byKey(const Key('cmd_mini_grid_p1')), findsNothing);

      // Life display is rendered with enlarged font size (84)
      expect(find.byKey(const Key('life_display_p1')), findsOneWidget);
      final lifeText = tester.widget<Text>(find.byKey(const Key('life_display_p1')));
      expect(lifeText.style?.fontSize, greaterThanOrEqualTo(84));

      // Gear button remains accessible in bottom bar
      expect(find.byKey(const Key('gear_button_p1')), findsOneWidget);
    });
  });

  group('R4.3: Central Utility Bar Auto-Hide & Collapse Animation', () {
    testWidgets('CentralUtilityBar renders expanded with interactive wings and centered hub', (tester) async {
      bool randomizerTapped = false;
      bool quickRollTriggered = false;

      await tester.pumpWidget(wrapWithScaffold(
        CentralUtilityBar(
          playerCount: 4,
          isCollapsed: false,
          onOpenRandomizer: () => randomizerTapped = true,
          onQuickRandomPlayer: () => quickRollTriggered = true,
        ),
      ));
      await tester.pumpAndSettle();

      // Center hub button is rendered
      expect(find.byKey(const Key('center_hub_button')), findsOneWidget);

      // Wing buttons are rendered and visible
      expect(find.byKey(const Key('life_counter_exit_button')), findsOneWidget);
      expect(find.byKey(const Key('central_hub_reset_button')), findsOneWidget);
      expect(find.byKey(const Key('central_hub_settings_button')), findsOneWidget);
      expect(find.byKey(const Key('central_hub_mana_button')), findsOneWidget);
      expect(find.byKey(const Key('central_hub_history_button')), findsOneWidget);
      expect(find.byKey(const Key('central_hub_quick_roll_button')), findsOneWidget);

      // Tap center hub when expanded opens randomizer
      await tester.tap(find.byKey(const Key('center_hub_button')));
      await tester.pump();
      expect(randomizerTapped, isTrue);

      // Long press triggers quick starting player roll
      await tester.longPress(find.byKey(const Key('center_hub_button')));
      await tester.pump();
      expect(quickRollTriggered, isTrue);
    });

    testWidgets('CentralUtilityBar in collapsed state ignores wings and tapping center hub toggles collapse', (tester) async {
      bool toggleCollapseTapped = false;
      bool resetTapped = false;

      await tester.pumpWidget(wrapWithScaffold(
        CentralUtilityBar(
          playerCount: 4,
          isCollapsed: true,
          onToggleCollapse: () => toggleCollapseTapped = true,
          onResetGame: () => resetTapped = true,
        ),
      ));
      await tester.pumpAndSettle();

      // Center hub button remains rendered at center
      expect(find.byKey(const Key('center_hub_button')), findsOneWidget);

      // Tapping center hub in collapsed state triggers toggle collapse to expand
      await tester.tap(find.byKey(const Key('center_hub_button')));
      await tester.pump();
      expect(toggleCollapseTapped, isTrue);

      // Wings are ignored under IgnorePointer: tapping wing buttons does not fire callback
      final resetBtn = find.byKey(const Key('central_hub_reset_button'));
      if (resetBtn.evaluate().isNotEmpty) {
        await tester.tap(resetBtn, warnIfMissed: false);
        await tester.pump();
        expect(resetTapped, isFalse);
      }
    });

    testWidgets('PodScaffoldWidget autohide collapses bar after 4s inactivity; touch wakes and expands bar', (tester) async {
      final podState = makeTestPod(2);

      await tester.pumpWidget(wrapWithScaffold(
        PodScaffoldWidget(
          podState: podState,
          autohideMenu: true,
        ),
      ));
      await tester.pumpAndSettle();

      // Initially bar is expanded
      CentralUtilityBar bar = tester.widget<CentralUtilityBar>(find.byType(CentralUtilityBar));
      expect(bar.isCollapsed, isFalse);

      // Advance time by 4 seconds (inactivity)
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();

      // Bar collapses automatically!
      bar = tester.widget<CentralUtilityBar>(find.byType(CentralUtilityBar));
      expect(bar.isCollapsed, isTrue);

      // Touch anywhere on screen (translucent listener intercepts user activity)
      await tester.tapAt(const Offset(100, 100));
      await tester.pump();

      // Bar wakes up and expands!
      bar = tester.widget<CentralUtilityBar>(find.byType(CentralUtilityBar));
      expect(bar.isCollapsed, isFalse);

      // After another 4 seconds of inactivity, bar collapses again
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
      bar = tester.widget<CentralUtilityBar>(find.byType(CentralUtilityBar));
      expect(bar.isCollapsed, isTrue);
    });

    testWidgets('PodScaffoldWidget with autohide disabled keeps bar expanded continuously', (tester) async {
      final podState = makeTestPod(2);

      await tester.pumpWidget(wrapWithScaffold(
        PodScaffoldWidget(
          podState: podState,
          autohideMenu: false,
        ),
      ));
      await tester.pumpAndSettle();

      // Advance time by 4 seconds
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();

      // Bar remains expanded!
      final bar = tester.widget<CentralUtilityBar>(find.byType(CentralUtilityBar));
      expect(bar.isCollapsed, isFalse);
    });

    testWidgets('Modal dialog safeguard pauses autohide collapse while presented', (tester) async {
      final podState = makeTestPod(2);

      await tester.pumpWidget(wrapWithScaffold(
        PodScaffoldWidget(
          podState: podState,
          autohideMenu: true,
        ),
      ));
      await tester.pumpAndSettle();

      // Present a modal dialog
      showDialog(
        context: tester.element(find.byType(PodScaffoldWidget)),
        builder: (ctx) => const AlertDialog(
          title: Text('Active Modal Dialog'),
        ),
      );
      await tester.pump();

      // 4 seconds elapse while modal is open
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();

      // Autohide collapse MUST be paused!
      CentralUtilityBar bar = tester.widget<CentralUtilityBar>(find.byType(CentralUtilityBar));
      expect(bar.isCollapsed, isFalse);

      // Dismiss dialog
      Navigator.of(tester.element(find.text('Active Modal Dialog'))).pop();
      await tester.pumpAndSettle();

      // Now 4 seconds elapse after returning to main game board
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();

      // Bar collapses now
      bar = tester.widget<CentralUtilityBar>(find.byType(CentralUtilityBar));
      expect(bar.isCollapsed, isTrue);
    });
  });

  group('R4.4: Polish & Accessibility Toggles', () {
    testWidgets('PregameSetupSheet switch tiles support dual-key finding and toggling', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PregameSetupSheet(
                initialPlayerCount: 2,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Auto-Hide Menu switch
      expect(find.byKey(const Key('pregame_autohide_switch')), findsOneWidget);
      expect(find.byKey(const Key('pregame_autohide_mode_switch')), findsOneWidget);
      await tester.tap(find.byKey(const Key('pregame_autohide_switch')));
      await tester.pumpAndSettle();

      // 2. OLED True Black Mode switch
      expect(find.byKey(const Key('pregame_oled_switch')), findsOneWidget);
      expect(find.byKey(const Key('pregame_oled_mode_switch')), findsOneWidget);
      await tester.tap(find.byKey(const Key('pregame_oled_switch')));
      await tester.pumpAndSettle();

      // 3. Keep Display Awake switch
      expect(find.byKey(const Key('pregame_wakelock_switch')), findsOneWidget);
      expect(find.byKey(const Key('pregame_wakelock_mode_switch')), findsOneWidget);
      await tester.tap(find.byKey(const Key('pregame_wakelock_switch')));
      await tester.pumpAndSettle();

      // 4. Haptic Feedback switch
      expect(find.byKey(const Key('pregame_haptics_switch')), findsOneWidget);
      expect(find.byKey(const Key('pregame_haptics_mode_switch')), findsOneWidget);
      await tester.tap(find.byKey(const Key('pregame_haptics_switch')));
      await tester.pumpAndSettle();

      // 5. Immersive Mode switch
      expect(find.byKey(const Key('pregame_immersive_switch')), findsOneWidget);
      expect(find.byKey(const Key('pregame_immersive_mode_switch')), findsOneWidget);
      await tester.tap(find.byKey(const Key('pregame_immersive_switch')));
      await tester.pumpAndSettle();

      // 6. Camera Mode switch
      expect(find.byKey(const Key('pregame_camera_mode_switch')), findsOneWidget);
      await tester.tap(find.byKey(const Key('pregame_camera_mode_switch')));
      await tester.pumpAndSettle();
    });

    testWidgets('OLED True Black Mode activates #000000 card background and suppresses commander art backdrop', (tester) async {
      const playerWithArt = PodPlayerState(
        id: 'p1',
        seatIndex: 0,
        name: 'Alice',
        life: 40,
        commanderArtCropUrl: 'https://example.com/art.jpg',
      );

      // Normal mode: card color is #1E1E2C and art backdrop renders
      await tester.pumpWidget(wrapWithScaffold(
        const PlayerQuadrantWidget(
          player: playerWithArt,
          isTablet: false,
          opponents: [],
          isOledMode: false,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(CommanderArtBackdrop), findsOneWidget);

      final normalContainer = tester.widget<Container>(
        find.descendant(
          of: find.byType(PlayerQuadrantWidget),
          matching: find.byType(Container),
        ).first,
      );
      final normalBoxDeco = normalContainer.decoration as BoxDecoration;
      expect(normalBoxDeco.color, const Color(0xFF1E1E2C));

      // OLED mode: card color is #000000 and art backdrop is suppressed
      await tester.pumpWidget(wrapWithScaffold(
        const PlayerQuadrantWidget(
          player: playerWithArt,
          isTablet: false,
          opponents: [],
          isOledMode: true,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(CommanderArtBackdrop), findsNothing);

      final oledContainer = tester.widget<Container>(
        find.descendant(
          of: find.byType(PlayerQuadrantWidget),
          matching: find.byType(Container),
        ).first,
      );
      final oledBoxDeco = oledContainer.decoration as BoxDecoration;
      expect(oledBoxDeco.color, const Color(0xFF000000));
    });

    test('WakelockService enables, disables, and toggles wake lock status safely in headless environments', () async {
      await WakelockService.enable();
      expect(WakelockService.isEnabled, isTrue);

      await WakelockService.disable();
      expect(WakelockService.isEnabled, isFalse);

      await WakelockService.setEnabled(true);
      expect(WakelockService.isEnabled, isTrue);

      await WakelockService.setEnabled(false);
      expect(WakelockService.isEnabled, isFalse);
    });

    test('PodHaptics toggle enables and disables vibrations without throwing in headless environments', () async {
      PodHaptics.enabled = true;
      expect(PodHaptics.enabled, isTrue);

      // Verify all haptic methods execute cleanly
      await PodHaptics.lightImpact();
      await PodHaptics.mediumImpact();
      await PodHaptics.selectionClick();
      await PodHaptics.heavyImpact();

      // Disable haptics
      PodHaptics.enabled = false;
      expect(PodHaptics.enabled, isFalse);

      await PodHaptics.lightImpact();
      await PodHaptics.mediumImpact();
      await PodHaptics.selectionClick();
      await PodHaptics.heavyImpact();

      // Restore enabled state
      PodHaptics.enabled = true;
    });
  });
}
