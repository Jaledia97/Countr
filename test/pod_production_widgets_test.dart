// Copyright (c) 2026 Countr. All rights reserved.
// Production widget verification test for Milestone 3 widgets under lib/features/life_counter/presentation/widgets/

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/features/life_counter/domain/models/pod_state.dart';
import 'package:countr/features/life_counter/presentation/widgets/center_hub_button.dart';
import 'package:countr/features/life_counter/presentation/widgets/floating_mana_drawer_widget.dart';
import 'package:countr/features/life_counter/presentation/widgets/player_quadrant_widget.dart';
import 'package:countr/features/life_counter/presentation/widgets/pod_layout_engine.dart';
import 'package:countr/features/life_counter/presentation/widgets/pod_scaffold_widget.dart';
import 'package:countr/features/life_counter/presentation/widgets/tool_drawer_or_rail.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Production CenterHubButton Tests', () {
    testWidgets('renders 48x48 circular button and responds to tap', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CenterHubButton(
                onPressed: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      final finder = find.byKey(const Key('center_hub_button'));
      expect(finder, findsOneWidget);
      final size = tester.getSize(find.byType(CenterHubButton));
      expect(size.width, 48.0);
      expect(size.height, 48.0);

      await tester.tap(finder);
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('supports custom size, icon, and colors', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: CenterHubButton(
                size: 56.0,
                icon: Icons.refresh,
                iconColor: Colors.cyan,
                backgroundColor: Colors.black,
              ),
            ),
          ),
        ),
      );

      final size = tester.getSize(find.byType(CenterHubButton));
      expect(size.width, 56.0);
      expect(size.height, 56.0);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });
  });

  group('Production FloatingManaDrawerWidget Tests', () {
    const player = PodPlayerState(
      id: 'p1',
      seatIndex: 0,
      name: 'Alice',
      life: 40,
      floatingMana: {'W': 1, 'U': 2, 'B': 3, 'R': 0, 'G': 0, 'C': 0},
      stormCount: 4,
    );

    testWidgets('displays WUBRGC mana values and storm count', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FloatingManaDrawerWidget(player: player),
          ),
        ),
      );

      expect(find.byKey(const Key('mana_drawer_sheet_p1')), findsOneWidget);
      expect(find.byKey(const Key('mana_val_W_p1')), findsOneWidget);
      expect(find.text('1'), findsOneWidget); // W: 1
      expect(find.byKey(const Key('mana_val_U_p1')), findsOneWidget);
      expect(find.text('2'), findsOneWidget); // U: 2
      expect(find.byKey(const Key('storm_count_p1')), findsOneWidget);
      expect(find.text('Storm Count: 4'), findsOneWidget);
    });

    testWidgets('triggers onManaDelta on stepper tap', (tester) async {
      String? adjustedColor;
      int? adjustedDelta;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FloatingManaDrawerWidget(
              player: player,
              onManaDelta: (color, delta) {
                adjustedColor = color;
                adjustedDelta = delta;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('mana_inc_U_p1')));
      await tester.pump();
      expect(adjustedColor, 'U');
      expect(adjustedDelta, 1);

      await tester.tap(find.byKey(const Key('mana_dec_W_p1')));
      await tester.pump();
      expect(adjustedColor, 'W');
      expect(adjustedDelta, -1);
    });

    testWidgets('triggers onManaClear on Clear Pool button tap', (tester) async {
      bool cleared = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FloatingManaDrawerWidget(
              player: player,
              onManaClear: () => cleared = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('clear_pool_btn_p1')));
      await tester.pump();
      expect(cleared, isTrue);
    });
  });

  group('Production ToolDrawerOrRail Tests', () {
    const player = PodPlayerState(
      id: 'p1',
      seatIndex: 0,
      name: 'Alice',
      life: 40,
      poison: 3,
      energy: 5,
      experience: 2,
      commanderDamageTaken: {'p2': 21, 'p3': 5},
    );
    const opponents = [
      PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40),
      PodPlayerState(id: 'p3', seatIndex: 2, name: 'Charlie', life: 40),
    ];

    testWidgets('renders opponent commander buttons and secondary counter steppers', (tester) async {
      String? cmdOppId;
      int? cmdDelta;
      String? counterType;
      int? counterDelta;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ToolDrawerOrRail(
              player: player,
              opponents: opponents,
              isTablet: true,
              onCommanderDamage: (oppId, delta) {
                cmdOppId = oppId;
                cmdDelta = delta;
              },
              onCounterDelta: (type, delta) {
                counterType = type;
                counterDelta = delta;
              },
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('cmd_damage_btn_p1_from_p2')), findsOneWidget);
      expect(find.byKey(const Key('cmd_damage_btn_p1_from_p3')), findsOneWidget);
      expect(find.byKey(const Key('val_poison_p1')), findsOneWidget);
      expect(find.byKey(const Key('val_energy_p1')), findsOneWidget);
      expect(find.byKey(const Key('val_xp_p1')), findsOneWidget);

      // Tap commander damage button
      await tester.tap(find.byKey(const Key('cmd_damage_btn_p1_from_p3')));
      await tester.pump();
      expect(cmdOppId, 'p3');
      expect(cmdDelta, 1);

      // Increment energy
      await tester.tap(find.byKey(const Key('inc_energy_p1')));
      await tester.pump();
      expect(counterType, 'energy');
      expect(counterDelta, 1);
    });
  });

  group('Production PlayerQuadrantWidget Tests', () {
    const player = PodPlayerState(
      id: 'p1',
      seatIndex: 0,
      name: 'Alice',
      life: 40,
      isMonarch: true,
      hasInitiative: true,
      commanderTax: 2,
    );
    const opponents = [
      PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40),
    ];

    testWidgets('renders life total, name, tax, monarch & initiative chips', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PlayerQuadrantWidget(
              player: player,
              isTablet: true,
              opponents: opponents,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('life_display_p1')), findsOneWidget);
      expect(find.text('40'), findsOneWidget);
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Tax: +4'), findsOneWidget);
      expect(find.text('👑 Monarch'), findsOneWidget);
      expect(find.text('🗡 Initiative'), findsOneWidget);
    });

    testWidgets('split hitboxes dispatch life deltas and show transient delta badge', (tester) async {
      int receivedDelta = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlayerQuadrantWidget(
              player: player,
              isTablet: true,
              opponents: opponents,
              onLifeDelta: (delta) => receivedDelta += delta,
            ),
          ),
        ),
      );

      // Increment life
      await tester.tap(find.byKey(const Key('hitbox_plus_p1')));
      await tester.pump();
      expect(receivedDelta, 1);
      expect(find.byKey(const Key('delta_badge_p1')), findsOneWidget);
      expect(find.text('+1'), findsOneWidget);

      // Auto fade badge after 1500ms
      await tester.pump(const Duration(milliseconds: 1600));
      expect(find.byKey(const Key('delta_badge_p1')), findsNothing);
    });

    testWidgets('displays commander lethal banner at >=21 damage', (tester) async {
      final lethalPlayer = player.copyWith(
        commanderDamageTaken: {'p2': 21},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlayerQuadrantWidget(
              player: lethalPlayer,
              isTablet: true,
              opponents: opponents,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('commander_lethal_alert_p1')), findsOneWidget);
      expect(find.text('LETHAL COMMANDER DAMAGE (21+)'), findsOneWidget);
    });

    testWidgets('displays poison lethal banner at >=10 poison', (tester) async {
      final poisonPlayer = player.copyWith(poison: 10);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlayerQuadrantWidget(
              player: poisonPlayer,
              isTablet: true,
              opponents: opponents,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('poison_lethal_alert_p1')), findsOneWidget);
      expect(find.text('LETHAL POISON (10+)'), findsOneWidget);
    });

    testWidgets('displays ELIMINATED overlay when isEliminated is true', (tester) async {
      final deadPlayer = player.copyWith(isEliminated: true);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlayerQuadrantWidget(
              player: deadPlayer,
              isTablet: true,
              opponents: opponents,
            ),
          ),
        ),
      );

      expect(find.text('ELIMINATED'), findsOneWidget);
    });
  });

  group('Production PodLayoutEngine Tests', () {
    final players = List.generate(
      6,
      (i) => PodPlayerState(id: 'p${i + 1}', seatIndex: i, name: 'P${i + 1}', life: 40),
    );

    Widget buildTestQuadrant(
      BuildContext context,
      PodPlayerState player, {
      required bool isTopRow,
      required bool isTablet,
    }) {
      return Container(
        key: Key('quadrant_${player.id}'),
        child: Text('${player.name}: top=$isTopRow, tab=$isTablet'),
      );
    }

    testWidgets('resolves layout types accurately', (tester) async {
      expect(PodLayoutEngine.resolveLayoutType(1), PodLayoutType.solo);
      expect(PodLayoutEngine.resolveLayoutType(2), PodLayoutType.oneVsOne);
      expect(PodLayoutEngine.resolveLayoutType(3), PodLayoutType.threePlayer);
      expect(PodLayoutEngine.resolveLayoutType(4), PodLayoutType.fourPlayer);
      expect(PodLayoutEngine.resolveLayoutType(5), PodLayoutType.fivePlayer);
      expect(PodLayoutEngine.resolveLayoutType(6), PodLayoutType.sixPlayer);
    });

    testWidgets('1v1 layout rotates seat 1 by 180°', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PodLayoutEngine(
              players: players.sublist(0, 2),
              isTablet: false,
              quadrantBuilder: buildTestQuadrant,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('quadrant_p1')), findsOneWidget);
      expect(find.byKey(const Key('quadrant_p2')), findsOneWidget);

      final p2Rotated = tester.widget<RotatedBox>(
        find.ancestor(of: find.byKey(const Key('quadrant_p2')), matching: find.byType(RotatedBox)),
      );
      expect(p2Rotated.quarterTurns, 2);

      expect(
        find.ancestor(of: find.byKey(const Key('quadrant_p1')), matching: find.byType(RotatedBox)),
        findsNothing,
      );
    });

    testWidgets('6-player layout renders all 6 seats without overflow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PodLayoutEngine(
              players: players,
              isTablet: true,
              quadrantBuilder: buildTestQuadrant,
            ),
          ),
        ),
      );

      for (int i = 1; i <= 6; i++) {
        expect(find.byKey(Key('quadrant_p$i')), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  });

  group('Production PodScaffoldWidget Tests', () {
    const podState4P = PodState(
      sessionId: 'prod_test_session',
      format: 'commander',
      startingLife: 40,
      players: [
        PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40),
        PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40),
        PodPlayerState(id: 'p3', seatIndex: 2, name: 'Charlie', life: 40),
        PodPlayerState(id: 'p4', seatIndex: 3, name: 'Diana', life: 40),
      ],
    );

    testWidgets('mounts 4 quadrants and center crossroads button', (tester) async {
      bool randomizerTriggered = false;

      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: PodScaffoldWidget(
            podState: podState4P,
            onRandomizerPressed: () => randomizerTriggered = true,
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('quadrant_p1')), findsOneWidget);
      expect(find.byKey(const Key('quadrant_p2')), findsOneWidget);
      expect(find.byKey(const Key('quadrant_p3')), findsOneWidget);
      expect(find.byKey(const Key('quadrant_p4')), findsOneWidget);
      expect(find.byKey(const Key('center_hub_button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('center_hub_button')));
      await tester.pump();
      expect(randomizerTriggered, isTrue);
    });

    testWidgets('responsive switching: phone (<600dp) renders drawer toggle, tablet (>=600dp) renders rail', (tester) async {
      // Phone size
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: PodScaffoldWidget(podState: podState4P),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('drawer_toggle_p1')), findsOneWidget);
      expect(find.byKey(const Key('drawer_panel_p1')), findsNothing);

      // Open drawer
      await tester.tap(find.byKey(const Key('drawer_toggle_p1')));
      await tester.pump();
      expect(find.byKey(const Key('drawer_panel_p1')), findsOneWidget);

      // Tablet size
      tester.view.physicalSize = const Size(800, 1200);
      await tester.pumpWidget(
        const MaterialApp(
          home: PodScaffoldWidget(podState: podState4P),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('drawer_toggle_p1')), findsNothing);
      expect(find.byKey(const Key('val_poison_p1')), findsOneWidget);
    });
  });
}
