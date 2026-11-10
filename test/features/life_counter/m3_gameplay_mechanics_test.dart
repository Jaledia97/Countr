// Copyright (c) 2026 Countr. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/features/life_counter/domain/models/game_history_entry.dart';
import 'package:countr/features/life_counter/domain/models/pod_state.dart';
import 'package:countr/features/life_counter/presentation/controllers/pod_controller.dart';
import 'package:countr/features/life_counter/presentation/dialogs/commander_damage_matrix_dialog.dart';
import 'package:countr/features/life_counter/presentation/dialogs/game_history_modal.dart';
import 'package:countr/features/life_counter/presentation/dialogs/player_status_drawer_sheet.dart';
import 'package:countr/features/life_counter/presentation/widgets/commander_spatial_mini_grid.dart';
import 'package:countr/features/life_counter/presentation/widgets/player_quadrant_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  group('R3.1: Transient Life Display, Hold Ticker & Debounce Inactivity', () {
    testWidgets('Single tap ±1 updates display immediately and shows transient delta badge', (tester) async {
      int? reportedDelta;
      final player = const PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40);

      await tester.pumpWidget(wrapWithScaffold(
        PlayerQuadrantWidget(
          player: player,
          isTablet: false,
          opponents: const [
            PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40),
          ],
          onLifeDelta: (d) => reportedDelta = d,
        ),
      ));

      expect(find.byKey(const Key('life_display_p1')), findsOneWidget);
      expect(find.text('40'), findsOneWidget);
      expect(find.byKey(const Key('delta_badge_p1')), findsNothing);

      // Tap decrement
      await tester.tap(find.byKey(const Key('hitbox_minus_p1')));
      await tester.pump();

      expect(reportedDelta, -1);
      expect(find.byKey(const Key('delta_badge_p1')), findsOneWidget);
      expect(find.text('-1'), findsOneWidget);

      // Tap increment twice
      await tester.tap(find.byKey(const Key('hitbox_plus_p1')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('hitbox_plus_p1')));
      await tester.pump();

      expect(find.byKey(const Key('delta_badge_p1')), findsOneWidget);
      expect(find.text('+1'), findsOneWidget);
    });

    testWidgets('Holding down minus triggers 250ms periodic hold (±5) and accelerates (±10 after 2s)', (tester) async {
      final deltas = <int>[];
      final player = const PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40);

      await tester.pumpWidget(wrapWithScaffold(
        PlayerQuadrantWidget(
          player: player,
          isTablet: false,
          opponents: const [],
          onLifeDelta: (d) => deltas.add(d),
        ),
      ));

      final minusGesture = await tester.startGesture(tester.getCenter(find.byKey(const Key('hitbox_minus_p1'))));
      // Trigger long-press recognizer timeout
      await tester.pump(const Duration(milliseconds: 500));
      expect(deltas, equals([-5]));

      // Advance 250ms -> second tick -5
      await tester.pump(const Duration(milliseconds: 250));
      expect(deltas, equals([-5, -5]));

      // Advance 500ms -> ticks at 250ms intervals
      await tester.pump(const Duration(milliseconds: 500));
      expect(deltas.length, 4);
      expect(deltas.every((d) => d == -5), isTrue);

      // Advance past 2000ms threshold (total elapsed >= 2000ms)
      await tester.pump(const Duration(milliseconds: 1300));
      // Now ticks should accelerate to -10
      expect(deltas.last, -10);

      await minusGesture.up();
      await tester.pump();
    });

    testWidgets('1500ms inactivity debounce commits GameHistoryEntry and dismisses delta badge', (tester) async {
      String? committedPlayerId;
      int? committedStartLife;
      int? committedEndLife;
      int? committedNetDelta;

      final player = const PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40);

      await tester.pumpWidget(wrapWithScaffold(
        PlayerQuadrantWidget(
          player: player,
          isTablet: false,
          opponents: const [],
          onCommitLifeHistory: ({
            required String playerId,
            required int startLife,
            required int endLife,
            required int netDelta,
          }) {
            committedPlayerId = playerId;
            committedStartLife = startLife;
            committedEndLife = endLife;
            committedNetDelta = netDelta;
          },
        ),
      ));

      // Tap minus 3 times (-3)
      await tester.tap(find.byKey(const Key('hitbox_minus_p1')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('hitbox_minus_p1')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('hitbox_minus_p1')));
      await tester.pump();

      expect(find.byKey(const Key('delta_badge_p1')), findsOneWidget);
      expect(find.text('-3'), findsOneWidget);

      // 1000ms elapsed (less than 1500ms debounce threshold)
      await tester.pump(const Duration(milliseconds: 1000));
      expect(committedNetDelta, isNull);
      expect(find.byKey(const Key('delta_badge_p1')), findsOneWidget);

      // 600ms more elapsed (total 1600ms > 1500ms)
      await tester.pump(const Duration(milliseconds: 600));

      expect(committedPlayerId, 'p1');
      expect(committedStartLife, 40);
      expect(committedEndLife, 37);
      expect(committedNetDelta, -3);

      // Delta badge should now be dismissed
      expect(find.byKey(const Key('delta_badge_p1')), findsNothing);
    });
  });

  group('R3.1: Game History Modal & Turn Log', () {
    testWidgets('GameHistoryModal renders empty state when no history exists', (tester) async {
      await tester.pumpWidget(wrapWithScaffold(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => GameHistoryModal.show(context, gameHistory: const []),
            child: const Text('Open History'),
          ),
        ),
      ));

      await tester.tap(find.text('Open History'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('game_history_modal')), findsOneWidget);
      expect(find.byKey(const Key('game_history_empty')), findsOneWidget);
      expect(find.text('No committed game actions yet.'), findsOneWidget);

      // Close button dismisses modal
      await tester.tap(find.byKey(const Key('game_history_close_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('game_history_modal')), findsNothing);
    });

    testWidgets('GameHistoryModal renders populated entries and triggers clear history', (tester) async {
      bool clearTriggered = false;
      final entries = [
        GameHistoryEntry.lifeChange(
          playerId: 'p1',
          playerName: 'Alice',
          startLife: 40,
          endLife: 35,
          netDelta: -5,
          timestamp: DateTime(2026, 4, 17, 14, 30),
        ),
        GameHistoryEntry.lifeChange(
          playerId: 'p2',
          playerName: 'Bob',
          startLife: 40,
          endLife: 43,
          netDelta: 3,
          timestamp: DateTime(2026, 4, 17, 14, 31),
        ),
      ];

      await tester.pumpWidget(wrapWithScaffold(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => GameHistoryModal.show(
              context,
              gameHistory: entries,
              onClearHistory: () => clearTriggered = true,
            ),
            child: const Text('Open History'),
          ),
        ),
      ));

      await tester.tap(find.text('Open History'));
      await tester.pumpAndSettle();

      expect(find.byKey(Key('history_item_${entries[0].id}')), findsOneWidget);
      expect(find.byKey(Key('history_item_${entries[1].id}')), findsOneWidget);
      expect(find.textContaining('Alice'), findsWidgets);
      expect(find.textContaining('Bob'), findsWidgets);
      expect(find.text('-5'), findsOneWidget);
      expect(find.text('+3'), findsOneWidget);
      expect(find.textContaining('40 -> 35'), findsWidgets);

      // Tap clear history
      await tester.tap(find.byKey(const Key('game_history_clear_button')));
      await tester.pumpAndSettle();
      expect(clearTriggered, isTrue);
    });
  });

  group('R3.2: Spatial Commander Damage Mini-Grid & Matrix Dialog', () {
    testWidgets('CommanderSpatialMiniGrid renders relative seating and triggers callbacks', (tester) async {
      String? tappedOppId;
      final player = const PodPlayerState(
        id: 'p1',
        seatIndex: 0,
        name: 'Alice',
        life: 40,
        commanderDamageTaken: {'p2': 5, 'p3': 21},
      );
      final List<PodPlayerState> opponents = [
        const PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40, colorTheme: 'U'),
        const PodPlayerState(id: 'p3', seatIndex: 2, name: 'Charlie', life: 40, colorTheme: 'R'),
        const PodPlayerState(id: 'p4', seatIndex: 3, name: 'Diana', life: 40, colorTheme: 'G'),
      ];

      await tester.pumpWidget(wrapWithScaffold(
        CommanderSpatialMiniGrid(
          player: player,
          opponents: opponents,
          colorize: true,
          onOpponentTap: (oppId) => tappedOppId = oppId,
        ),
      ));

      expect(find.byKey(const Key('cmd_mini_grid_p1')), findsOneWidget);
      expect(find.byKey(const Key('cmd_damage_btn_p1_from_p2')), findsOneWidget);
      expect(find.byKey(const Key('cmd_damage_btn_p1_from_p3')), findsOneWidget);
      expect(find.byKey(const Key('cmd_damage_btn_p1_from_p4')), findsOneWidget);

      expect(find.text('5'), findsOneWidget);
      expect(find.text('21'), findsOneWidget);

      // Tap slot
      await tester.tap(find.byKey(const Key('cmd_damage_btn_p1_from_p2')));
      await tester.pump();
      expect(tappedOppId, 'p2');
    });

    testWidgets('CommanderDamageMatrixDialog supports Partner A & B steppers and 21 lethal badge', (tester) async {
      final deltas = <String, int>{};
      final target = const PodPlayerState(
        id: 'p1',
        seatIndex: 0,
        name: 'Alice',
        life: 40,
        commanderDamageTaken: {'p2': 20, 'p2_partner': 0},
      );
      final List<PodPlayerState> opponents = [
        const PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40),
      ];

      await tester.pumpWidget(wrapWithScaffold(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => CommanderDamageMatrixDialog.show(
              context,
              targetPlayer: target,
              opponents: opponents,
              onDamageDelta: (oppId, delta) {
                deltas[oppId] = (deltas[oppId] ?? 0) + delta;
              },
            ),
            child: const Text('Open Matrix'),
          ),
        ),
      ));

      await tester.tap(find.text('Open Matrix'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cmd_damage_dialog_p1')), findsOneWidget);
      expect(find.byKey(const Key('cmd_damage_card_p2')), findsOneWidget);
      expect(find.byKey(const Key('cmd_damage_val_p1_from_p2')), findsOneWidget);
      expect(find.text('20'), findsOneWidget);

      // Partner B is initially hidden
      expect(find.byKey(const Key('cmd_damage_val_p1_from_p2_partner')), findsNothing);

      // Toggle partner
      await tester.tap(find.byKey(const Key('cmd_partner_toggle_p2')));
      await tester.pumpAndSettle();

      // Partner B is now revealed
      expect(find.byKey(const Key('cmd_damage_val_p1_from_p2_partner')), findsOneWidget);

      // Increment Partner A
      await tester.tap(find.byKey(const Key('cmd_damage_inc_p1_from_p2')));
      await tester.pump();
      expect(deltas['p2'], 1);

      // Increment Partner B
      await tester.tap(find.byKey(const Key('cmd_damage_inc_p1_from_p2_partner')));
      await tester.pump();
      expect(deltas['p2_partner'], 1);
    });

    test('recordCommanderDamage respects commanderDamageLifeLoss and prevents negative underflow', () async {
      const initialPod = PodState(
        sessionId: 'cmd_dmg_session',
        format: 'commander',
        startingLife: 40,
        players: [
          PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40),
          PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40),
        ],
      );
      final controller = PodController(initialState: initialPod);

      // Normal recording: commanderDamageLifeLoss is true by default
      await controller.recordCommanderDamage(
        targetPlayerId: 'p1',
        sourcePlayerId: 'p2',
        damageDelta: 5,
      );
      expect(controller.state.players.first.commanderDamageTaken['p2'], 5);
      expect(controller.state.players.first.life, 35); // 40 - 5 = 35

      // Underflow protection: decrementing from 0 damage should clamp at 0 and not increase life
      await controller.recordCommanderDamage(
        targetPlayerId: 'p2',
        sourcePlayerId: 'p1',
        damageDelta: -1,
      );
      expect(controller.state.players[1].commanderDamageTaken['p1'] ?? 0, 0);
      expect(controller.state.players[1].life, 40); // Life stays 40, not 41

      // Toggle commanderDamageLifeLoss to false
      controller.toggleCommanderDamageLifeLoss();
      expect(controller.state.commanderDamageLifeLoss, isFalse);

      await controller.recordCommanderDamage(
        targetPlayerId: 'p1',
        sourcePlayerId: 'p2',
        damageDelta: 3,
      );
      expect(controller.state.players.first.commanderDamageTaken['p2'], 8);
      expect(controller.state.players.first.life, 35); // Life total did not reduce further
    });
  });

  group('R3.3 & R3.4: Player Status Drawer Sheet, Secondary Counters & Exclusive Tokens', () {
    testWidgets('PlayerStatusDrawerSheet allows profile edit, vault linking, counters, and token toggles', (tester) async {
      String? changedName;
      String? changedColor;
      final counterDeltas = <String, int>{};
      bool claimedMonarch = false;
      bool claimedInitiative = false;

      final player = const PodPlayerState(
        id: 'p1',
        seatIndex: 0,
        name: 'Alice',
        life: 40,
        poison: 2,
        energy: 3,
        experience: 1,
        commanderTax: 2,
        radCounters: 4,
        colorTheme: 'red',
      );

      await tester.pumpWidget(wrapWithScaffold(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => PlayerStatusDrawerSheet.show(
              context,
              player: player,
              opponents: const [],
              onNameChanged: (n) => changedName = n,
              onColorChanged: (c) => changedColor = c,
              onCounterDelta: (t, d) => counterDeltas[t] = d,
              onClaimMonarch: () => claimedMonarch = true,
              onClaimInitiative: () => claimedInitiative = true,
            ),
            child: const Text('Open Status Drawer'),
          ),
        ),
      ));

      await tester.tap(find.text('Open Status Drawer'));
      await tester.pumpAndSettle();

      // Name editing
      expect(find.byKey(const Key('player_name_input_p1')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('player_name_input_p1')), 'Alicia');
      expect(changedName, 'Alicia');

      // Color picker
      expect(find.byKey(const Key('color_picker_p1_blue')), findsOneWidget);
      await tester.tap(find.byKey(const Key('color_picker_p1_blue')));
      await tester.pump();
      expect(changedColor, 'blue');

      // Vault Deck link button
      expect(find.byKey(const Key('link_vault_deck_button_p1')), findsOneWidget);

      // Secondary counters: Poison, Tax, Energy, XP, Rad
      expect(find.byKey(const Key('val_poison_p1')), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      await tester.tap(find.byKey(const Key('inc_poison_p1')));
      await tester.pump();
      expect(counterDeltas['poison'], 1);

      expect(find.byKey(const Key('val_tax_p1')), findsOneWidget);
      expect(find.text('+4'), findsOneWidget);
      await tester.tap(find.byKey(const Key('inc_tax_p1')));
      await tester.pump();
      expect(counterDeltas['commanderTax'], 1);

      expect(find.byKey(const Key('val_energy_p1')), findsOneWidget);
      await tester.tap(find.byKey(const Key('inc_energy_p1')));
      await tester.pump();
      expect(counterDeltas['energy'], 1);

      expect(find.byKey(const Key('val_xp_p1')), findsOneWidget);
      await tester.tap(find.byKey(const Key('inc_xp_p1')));
      await tester.pump();
      expect(counterDeltas['experience'], 1);

      expect(find.byKey(const Key('val_rad_p1')), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      await tester.tap(find.byKey(const Key('inc_rad_p1')));
      await tester.pump();
      expect(counterDeltas['rad'], 1);

      // Exclusive Tokens
      await tester.tap(find.byKey(const Key('toggle_monarch_p1')));
      await tester.pump();
      expect(claimedMonarch, isTrue);

      await tester.tap(find.byKey(const Key('toggle_initiative_p1')));
      await tester.pump();
      expect(claimedInitiative, isTrue);
    });

    testWidgets('Active badge pills flank drawer_toggle on phone bottom bar', (tester) async {
      final player = const PodPlayerState(
        id: 'p1',
        seatIndex: 0,
        name: 'Alice',
        life: 40,
        isMonarch: true,
        hasInitiative: true,
        commanderTax: 2,
        poison: 3,
        energy: 4,
        experience: 5,
        radCounters: 6,
      );

      await tester.pumpWidget(wrapWithScaffold(
        PlayerQuadrantWidget(
          player: player,
          isTablet: false,
          opponents: const [],
        ),
      ));

      // Left Flanking Pills
      expect(find.byKey(const Key('pill_monarch_p1')), findsOneWidget);
      expect(find.byKey(const Key('chip_monarch')), findsOneWidget);
      expect(find.byKey(const Key('pill_initiative_p1')), findsOneWidget);
      expect(find.byKey(const Key('chip_initiative')), findsOneWidget);
      expect(find.byKey(const Key('pill_tax_p1')), findsOneWidget);
      expect(find.text('Tax: +4'), findsOneWidget);

      // Center Drawer Toggle
      expect(find.byKey(const Key('drawer_toggle_p1')), findsOneWidget);

      // Right Flanking Pills
      expect(find.byKey(const Key('pill_poison_p1')), findsOneWidget);
      expect(find.byKey(const Key('val_poison_p1')), findsOneWidget);
      expect(find.byKey(const Key('pill_energy_p1')), findsOneWidget);
      expect(find.byKey(const Key('val_energy_p1')), findsOneWidget);
      expect(find.byKey(const Key('pill_xp_p1')), findsOneWidget);
      expect(find.byKey(const Key('val_xp_p1')), findsOneWidget);
      expect(find.byKey(const Key('pill_rad_p1')), findsOneWidget);
      expect(find.byKey(const Key('val_rad_p1')), findsOneWidget);
      expect(find.text('☢ 6'), findsOneWidget);
    });
  });

  group('R3.4: Auto-KO Defeat State Overlay & Revive Override', () {
    testWidgets('Auto-KO overlay displays death reason for 0 life', (tester) async {
      final lethalPlayer = const PodPlayerState(
        id: 'p1',
        seatIndex: 0,
        name: 'Alice',
        life: 0,
      );

      await tester.pumpWidget(wrapWithScaffold(
        PlayerQuadrantWidget(
          player: lethalPlayer,
          isTablet: false,
          opponents: const [],
        ),
      ));

      expect(find.text('ELIMINATED'), findsOneWidget);
      expect(find.byKey(const Key('death_reason_p1')), findsOneWidget);
      expect(find.text('Knocked Out: 0 Life'), findsOneWidget);
      expect(find.byKey(const Key('btn_ignore_revive_p1')), findsOneWidget);
    });

    testWidgets('Auto-KO overlay displays death reason for 10 poison', (tester) async {
      final poisonLethalPlayer = const PodPlayerState(
        id: 'p1',
        seatIndex: 0,
        name: 'Alice',
        life: 25,
        poison: 10,
      );

      await tester.pumpWidget(wrapWithScaffold(
        PlayerQuadrantWidget(
          player: poisonLethalPlayer,
          isTablet: false,
          opponents: const [],
        ),
      ));

      expect(find.text('ELIMINATED'), findsOneWidget);
      expect(find.byKey(const Key('death_reason_p1')), findsOneWidget);
      expect(find.text('Knocked Out: 10 Poison'), findsOneWidget);
    });

    testWidgets('Auto-KO overlay displays death reason for 21 commander damage', (tester) async {
      final cmdLethalPlayer = const PodPlayerState(
        id: 'p1',
        seatIndex: 0,
        name: 'Alice',
        life: 19,
        commanderDamageTaken: {'p2': 21},
      );

      await tester.pumpWidget(wrapWithScaffold(
        PlayerQuadrantWidget(
          player: cmdLethalPlayer,
          isTablet: false,
          opponents: const [
            PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40),
          ],
        ),
      ));

      expect(find.text('ELIMINATED'), findsOneWidget);
      expect(find.byKey(const Key('death_reason_p1')), findsOneWidget);
      expect(find.text('Knocked Out: 21 Commander Damage'), findsOneWidget);
    });

    testWidgets('Ignore / Revive button dismisses overlay and allows gameplay', (tester) async {
      bool ignoreKoCalled = false;
      final lethalPlayer = const PodPlayerState(
        id: 'p1',
        seatIndex: 0,
        name: 'Alice',
        life: 0,
      );

      await tester.pumpWidget(wrapWithScaffold(
        PlayerQuadrantWidget(
          player: lethalPlayer,
          isTablet: false,
          opponents: const [],
          onIgnoreKo: () => ignoreKoCalled = true,
        ),
      ));

      expect(find.byKey(const Key('btn_ignore_revive_p1')), findsOneWidget);
      await tester.tap(find.byKey(const Key('btn_ignore_revive_p1')));
      await tester.pump();

      expect(ignoreKoCalled, isTrue);

      // When player has isKoIgnored: true, overlay is not rendered
      final ignoredPlayer = lethalPlayer.copyWith(isKoIgnored: true, isEliminated: false);
      await tester.pumpWidget(wrapWithScaffold(
        PlayerQuadrantWidget(
          player: ignoredPlayer,
          isTablet: false,
          opponents: const [],
        ),
      ));

      expect(find.text('ELIMINATED'), findsNothing);
      expect(find.byKey(const Key('death_reason_p1')), findsNothing);
    });

    test('PodController ignoreKo sets isKoIgnored and resets when state recovers', () async {
      const initialPod = PodState(
        sessionId: 'ko_session',
        format: 'commander',
        startingLife: 40,
        players: [
          PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40),
          PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40),
        ],
      );
      final controller = PodController(initialState: initialPod);

      // Bring player to 0 life
      await controller.adjustLife('p1', -40);
      expect(controller.state.players.first.life, 0);
      expect(controller.state.players.first.isEliminated, isTrue);
      expect(controller.state.players.first.isKoIgnored, isFalse);

      // Ignore KO
      controller.ignoreKo('p1');
      expect(controller.state.players.first.isKoIgnored, isTrue);
      expect(controller.state.players.first.isEliminated, isFalse);

      // Adjust life back to non-lethal (heal to 10)
      await controller.adjustLife('p1', 10);
      expect(controller.state.players.first.life, 10);
      expect(controller.state.players.first.isEliminated, isFalse);
      expect(controller.state.players.first.isKoIgnored, isFalse); // Reset for future lethal events

      // Knock out again (-10 life -> 0)
      await controller.adjustLife('p1', -10);
      expect(controller.state.players.first.life, 0);
      expect(controller.state.players.first.isEliminated, isTrue);
      expect(controller.state.players.first.isKoIgnored, isFalse);
    });
  });
}
