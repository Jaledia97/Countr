// Copyright (c) 2026 Countr. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/features/life_counter/domain/models/pod_state.dart';
import 'package:countr/features/life_counter/presentation/controllers/pod_controller.dart';
import 'package:countr/features/life_counter/presentation/dialogs/commander_damage_matrix_dialog.dart';
import 'package:countr/features/life_counter/presentation/dialogs/player_status_drawer_sheet.dart';
import 'package:countr/features/life_counter/presentation/widgets/commander_spatial_mini_grid.dart';
import 'package:countr/features/life_counter/presentation/widgets/player_quadrant_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrapWithScaffold(Widget child, {Size size = const Size(400, 800)}) {
    return ProviderScope(
      child: MaterialApp(
        theme: ThemeData.dark(),
        home: MediaQuery(
          data: MediaQueryData(size: size),
          child: Scaffold(
            backgroundColor: Colors.black,
            body: child,
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // CHALLENGE 1: Commander Damage Lethal Boundary (20 vs 21)
  // ===========================================================================
  group('1. Commander Damage Lethal Boundary (20 vs 21)', () {
    test('Domain boundary: 20 dmg is non-lethal, 21 dmg triggers lethal', () {
      const p1 = PodPlayerState(
        id: 'p1',
        seatIndex: 0,
        name: 'Alice',
        life: 20,
        commanderDamageTaken: {'p2': 20},
      );
      expect(p1.isCommanderDamageLethalFrom('p2'), isFalse);
      expect(p1.hasAnyLethalCommanderDamage, isFalse);
      expect(p1.isLethal, isFalse);
      expect(p1.isEliminated, isFalse);

      final p1At21 = p1.copyWith(
        life: 19,
        commanderDamageTaken: {'p2': 21},
      );
      expect(p1At21.isCommanderDamageLethalFrom('p2'), isTrue);
      expect(p1At21.hasAnyLethalCommanderDamage, isTrue);
      expect(p1At21.isLethal, isTrue);
    });

    test('PodController: advancing from 20 to 21 triggers autoKo elimination', () async {
      const initialPod = PodState(
        sessionId: 'cmd_boundary_session',
        format: 'commander',
        startingLife: 40,
        autoKo: true,
        players: [
          PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40),
          PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40),
        ],
      );
      final controller = PodController(initialState: initialPod);

      // Record exactly 20 commander damage
      await controller.recordCommanderDamage(
        targetPlayerId: 'p1',
        sourcePlayerId: 'p2',
        damageDelta: 20,
      );

      var p1 = controller.state.getPlayer('p1')!;
      expect(p1.commanderDamageTaken['p2'], 20);
      expect(p1.life, 20);
      expect(p1.hasAnyLethalCommanderDamage, isFalse);
      expect(p1.isEliminated, isFalse);

      // Record +1 commander damage (reaching 21)
      await controller.recordCommanderDamage(
        targetPlayerId: 'p1',
        sourcePlayerId: 'p2',
        damageDelta: 1,
      );

      p1 = controller.state.getPlayer('p1')!;
      expect(p1.commanderDamageTaken['p2'], 21);
      expect(p1.life, 19);
      expect(p1.hasAnyLethalCommanderDamage, isTrue);
      expect(p1.isEliminated, isTrue);
    });

    test('Overkill boundary: massive commander damage (0 -> 40) is lethal and updates life', () async {
      const initialPod = PodState(
        sessionId: 'cmd_overkill_session',
        format: 'commander',
        startingLife: 40,
        autoKo: true,
        players: [
          PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40),
          PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40),
        ],
      );
      final controller = PodController(initialState: initialPod);

      await controller.recordCommanderDamage(
        targetPlayerId: 'p1',
        sourcePlayerId: 'p2',
        damageDelta: 40,
      );

      final p1 = controller.state.getPlayer('p1')!;
      expect(p1.commanderDamageTaken['p2'], 40);
      expect(p1.life, 0);
      expect(p1.hasAnyLethalCommanderDamage, isTrue);
      expect(p1.isEliminated, isTrue);
    });

    testWidgets('UI boundary: 20 dmg shows NO alert/overlay; 21 dmg renders lethal banner & Auto-KO overlay', (tester) async {
      final p1NonLethal = const PodPlayerState(
        id: 'p1',
        seatIndex: 0,
        name: 'Alice',
        life: 20,
        commanderDamageTaken: {'p2': 20},
      );
      final opponents = const [
        PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40),
      ];

      // 1. Test 20 damage: No alert, no overlay
      await tester.pumpWidget(wrapWithScaffold(
        PlayerQuadrantWidget(
          player: p1NonLethal,
          isTablet: false,
          opponents: opponents,
        ),
      ));

      expect(find.byKey(const Key('commander_lethal_alert_p1')), findsNothing);
      expect(find.text('ELIMINATED'), findsNothing);
      expect(find.byKey(const Key('death_reason_p1')), findsNothing);

      // 2. Test 21 damage: Alert banner AND Eliminated overlay appear
      final p1Lethal = const PodPlayerState(
        id: 'p1',
        seatIndex: 0,
        name: 'Alice',
        life: 19,
        commanderDamageTaken: {'p2': 21},
        isEliminated: true,
      );

      await tester.pumpWidget(wrapWithScaffold(
        PlayerQuadrantWidget(
          player: p1Lethal,
          isTablet: false,
          opponents: opponents,
        ),
      ));

      expect(find.byKey(const Key('commander_lethal_alert_p1')), findsOneWidget);
      expect(find.text('LETHAL COMMANDER DAMAGE (21+)'), findsOneWidget);
      expect(find.text('ELIMINATED'), findsOneWidget);
      expect(find.byKey(const Key('death_reason_p1')), findsOneWidget);
      expect(find.text('Knocked Out: 21 Commander Damage'), findsOneWidget);
    });
  });

  // ===========================================================================
  // CHALLENGE 2: Partner A vs Partner B Independent Lethal
  // ===========================================================================
  group('2. Partner A vs Partner B Independent Lethal (CR 903.10a)', () {
    test('Domain rule: 20 from Partner A + 20 from Partner B = 40 total is NON-lethal; 21 on B alone is lethal', () {
      // 20 from Partner A and 20 from Partner B
      const p1 = PodPlayerState(
        id: 'p1',
        seatIndex: 0,
        name: 'Alice',
        life: 20, // started at 60
        commanderDamageTaken: {
          'p2': 20,
          'p2_partner': 20,
        },
      );

      expect(p1.totalCommanderDamageFrom('p2'), 40);
      expect(p1.maxCommanderDamageFrom('p2'), 20);
      expect(p1.isCommanderDamageLethalFrom('p2'), isFalse);
      expect(p1.isCommanderDamageLethalFrom('p2_partner'), isFalse);
      expect(p1.isLethalFromOpponent('p2'), isFalse);
      expect(p1.hasAnyLethalCommanderDamage, isFalse);
      expect(p1.isLethal, isFalse);

      // Advance Partner B alone to 21
      final p1PartnerLethal = p1.copyWith(
        commanderDamageTaken: {
          'p2': 20,
          'p2_partner': 21,
        },
      );
      expect(p1PartnerLethal.totalCommanderDamageFrom('p2'), 41);
      expect(p1PartnerLethal.maxCommanderDamageFrom('p2'), 21);
      expect(p1PartnerLethal.isCommanderDamageLethalFrom('p2'), isFalse);
      expect(p1PartnerLethal.isCommanderDamageLethalFrom('p2_partner'), isTrue);
      expect(p1PartnerLethal.isLethalFromOpponent('p2'), isTrue);
      expect(p1PartnerLethal.hasAnyLethalCommanderDamage, isTrue);
      expect(p1PartnerLethal.isLethal, isTrue);
    });

    test('PodController: independent partner damage tracking and partner lethal trigger', () async {
      const initialPod = PodState(
        sessionId: 'partner_session',
        format: 'commander',
        startingLife: 60, // higher starting life to isolate commander damage from life <= 0
        autoKo: true,
        players: [
          PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 60),
          PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40),
        ],
      );
      final controller = PodController(initialState: initialPod);

      // Partner A deals 20
      await controller.recordCommanderDamage(
        targetPlayerId: 'p1',
        sourcePlayerId: 'p2',
        damageDelta: 20,
      );
      // Partner B deals 20
      await controller.recordCommanderDamage(
        targetPlayerId: 'p1',
        sourcePlayerId: 'p2_partner',
        damageDelta: 20,
      );

      var p1 = controller.state.getPlayer('p1')!;
      expect(p1.commanderDamageTaken['p2'], 20);
      expect(p1.commanderDamageTaken['p2_partner'], 20);
      expect(p1.life, 20); // 60 - 20 - 20 = 20
      expect(p1.hasAnyLethalCommanderDamage, isFalse);
      expect(p1.isEliminated, isFalse);

      // Now Partner B deals 1 more damage (reaches 21)
      await controller.recordCommanderDamage(
        targetPlayerId: 'p1',
        sourcePlayerId: 'p2_partner',
        damageDelta: 1,
      );

      p1 = controller.state.getPlayer('p1')!;
      expect(p1.commanderDamageTaken['p2'], 20);
      expect(p1.commanderDamageTaken['p2_partner'], 21);
      expect(p1.life, 19);
      expect(p1.hasAnyLethalCommanderDamage, isTrue);
      expect(p1.isEliminated, isTrue);
    });

    testWidgets('UI Matrix: Partner A=20 and Partner B=20 shows 40 in mini-grid, NO lethal badge; B=21 shows lethal badge', (tester) async {
      final p1 = const PodPlayerState(
        id: 'p1',
        seatIndex: 0,
        name: 'Alice',
        life: 20,
        commanderDamageTaken: {'p2': 20, 'p2_partner': 20},
      );
      final opponents = const [
        PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40),
      ];

      // Spatial mini-grid displays total 40
      await tester.pumpWidget(wrapWithScaffold(
        CommanderSpatialMiniGrid(
          player: p1,
          opponents: opponents,
          colorize: true,
        ),
      ));
      expect(find.text('40'), findsOneWidget);

      // Open Matrix Dialog
      await tester.pumpWidget(wrapWithScaffold(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => CommanderDamageMatrixDialog.show(
              context,
              targetPlayer: p1,
              opponents: opponents,
              onDamageDelta: (oppId, delta) {},
            ),
            child: const Text('Open Matrix'),
          ),
        ),
      ));

      await tester.tap(find.text('Open Matrix'));
      await tester.pumpAndSettle();

      // Partner B is auto-expanded because dmgB > 0
      expect(find.byKey(const Key('cmd_damage_val_p1_from_p2')), findsOneWidget);
      expect(find.byKey(const Key('cmd_damage_val_p1_from_p2_partner')), findsOneWidget);
      expect(find.text('20'), findsNWidgets(2));

      // No lethal badge because neither is 21
      expect(find.byKey(const Key('cmd_lethal_badge_p1_from_p2')), findsNothing);

      // Now close and open with Partner B at 21
      Navigator.of(tester.element(find.byKey(const Key('cmd_damage_val_p1_from_p2')))).pop();
      await tester.pumpAndSettle();

      final p1LethalB = p1.copyWith(
        commanderDamageTaken: {'p2': 20, 'p2_partner': 21},
      );
      await tester.pumpWidget(wrapWithScaffold(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => CommanderDamageMatrixDialog.show(
              context,
              targetPlayer: p1LethalB,
              opponents: opponents,
              onDamageDelta: (oppId, delta) {},
            ),
            child: const Text('Open Matrix Lethal B'),
          ),
        ),
      ));

      await tester.tap(find.text('Open Matrix Lethal B'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('cmd_lethal_badge_p1_from_p2')), findsOneWidget);
      expect(find.text('21+ LETHAL COMMANDER DAMAGE'), findsOneWidget);
    });
  });

  // ===========================================================================
  // CHALLENGE 3: Commander Damage Underflow Clamp & Life Protection
  // ===========================================================================
  group('3. Commander Damage Underflow Clamp & Life Protection', () {
    test('PodController prevents commander damage below 0 and prevents life inflation on negative delta at 0 dmg', () async {
      const initialPod = PodState(
        sessionId: 'underflow_session',
        format: 'commander',
        startingLife: 40,
        commanderDamageLifeLoss: true,
        players: [
          PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40),
          PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40),
        ],
      );
      final controller = PodController(initialState: initialPod);

      // Decrementing when damage is 0
      await controller.recordCommanderDamage(
        targetPlayerId: 'p1',
        sourcePlayerId: 'p2',
        damageDelta: -1,
      );

      var p1 = controller.state.getPlayer('p1')!;
      expect(p1.commanderDamageTaken['p2'] ?? 0, 0);
      expect(p1.life, 40); // CRITICAL: Life must NOT become 41!

      // Large negative delta: -100
      await controller.recordCommanderDamage(
        targetPlayerId: 'p1',
        sourcePlayerId: 'p2',
        damageDelta: -100,
      );

      p1 = controller.state.getPlayer('p1')!;
      expect(p1.commanderDamageTaken['p2'] ?? 0, 0);
      expect(p1.life, 40); // Must remain exactly 40

      // Add 5 damage (life drops to 35)
      await controller.recordCommanderDamage(
        targetPlayerId: 'p1',
        sourcePlayerId: 'p2',
        damageDelta: 5,
      );
      p1 = controller.state.getPlayer('p1')!;
      expect(p1.commanderDamageTaken['p2'], 5);
      expect(p1.life, 35);

      // Decrement by 10 (exceeds current 5 damage): should clamp at 0 and restore ONLY 5 life (to 40, not 45!)
      await controller.recordCommanderDamage(
        targetPlayerId: 'p1',
        sourcePlayerId: 'p2',
        damageDelta: -10,
      );
      p1 = controller.state.getPlayer('p1')!;
      expect(p1.commanderDamageTaken['p2'], 0);
      expect(p1.life, 40); // 35 + 5 = 40 (only restored actual delta of 5, not 10!)
    });

    test('Partner B underflow protection: negative delta on Partner B at 0 does not reduce below 0 or inflate life', () async {
      const initialPod = PodState(
        sessionId: 'partner_underflow_session',
        format: 'commander',
        startingLife: 40,
        commanderDamageLifeLoss: true,
        players: [
          PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40),
          PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40),
        ],
      );
      final controller = PodController(initialState: initialPod);

      await controller.recordCommanderDamage(
        targetPlayerId: 'p1',
        sourcePlayerId: 'p2_partner',
        damageDelta: -5,
      );

      final p1 = controller.state.getPlayer('p1')!;
      expect(p1.commanderDamageTaken['p2_partner'] ?? 0, 0);
      expect(p1.life, 40);
    });
  });

  // ===========================================================================
  // CHALLENGE 4: commanderDamageLifeLoss Toggle Decoupling
  // ===========================================================================
  group('4. commanderDamageLifeLoss Toggle Decoupling', () {
    test('Toggling commanderDamageLifeLoss cleanly decouples life changes from commander damage', () async {
      const initialPod = PodState(
        sessionId: 'decouple_session',
        format: 'commander',
        startingLife: 40,
        commanderDamageLifeLoss: true,
        players: [
          PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40),
          PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40),
        ],
      );
      final controller = PodController(initialState: initialPod);

      // Default: life loss is active
      expect(controller.state.commanderDamageLifeLoss, isTrue);
      await controller.recordCommanderDamage(
        targetPlayerId: 'p1',
        sourcePlayerId: 'p2',
        damageDelta: 6,
      );
      expect(controller.state.getPlayer('p1')!.life, 34);
      expect(controller.state.getPlayer('p1')!.commanderDamageTaken['p2'], 6);

      // Toggle to FALSE
      controller.toggleCommanderDamageLifeLoss(false);
      expect(controller.state.commanderDamageLifeLoss, isFalse);

      // Add 8 commander damage: commander damage increases, life remains 34
      await controller.recordCommanderDamage(
        targetPlayerId: 'p1',
        sourcePlayerId: 'p2',
        damageDelta: 8,
      );
      expect(controller.state.getPlayer('p1')!.commanderDamageTaken['p2'], 14);
      expect(controller.state.getPlayer('p1')!.life, 34); // Unchanged!

      // Subtract 4 commander damage: commander damage decreases to 10, life remains 34
      await controller.recordCommanderDamage(
        targetPlayerId: 'p1',
        sourcePlayerId: 'p2',
        damageDelta: -4,
      );
      expect(controller.state.getPlayer('p1')!.commanderDamageTaken['p2'], 10);
      expect(controller.state.getPlayer('p1')!.life, 34); // Unchanged!

      // Toggle back to TRUE
      controller.toggleCommanderDamageLifeLoss(true);
      expect(controller.state.commanderDamageLifeLoss, isTrue);

      // Add 2 commander damage: life reduces again (34 -> 32)
      await controller.recordCommanderDamage(
        targetPlayerId: 'p1',
        sourcePlayerId: 'p2',
        damageDelta: 2,
      );
      expect(controller.state.getPlayer('p1')!.commanderDamageTaken['p2'], 12);
      expect(controller.state.getPlayer('p1')!.life, 32);
    });
  });

  // ===========================================================================
  // CHALLENGE 5: Auto-KO Death Reasons
  // ===========================================================================
  group('5. Auto-KO Death Reasons Exact String Verification', () {
    testWidgets('0 Life shows "Knocked Out: 0 Life"', (tester) async {
      final p = const PodPlayerState(
        id: 'p1',
        seatIndex: 0,
        name: 'Alice',
        life: 0,
        poison: 0,
      );
      await tester.pumpWidget(wrapWithScaffold(
        PlayerQuadrantWidget(
          player: p,
          isTablet: false,
          opponents: const [],
        ),
      ));

      expect(find.byKey(const Key('death_reason_p1')), findsOneWidget);
      expect(find.text('Knocked Out: 0 Life'), findsOneWidget);
    });

    testWidgets('Negative Life shows "Knocked Out: -7 Life"', (tester) async {
      final p = const PodPlayerState(
        id: 'p1',
        seatIndex: 0,
        name: 'Alice',
        life: -7,
        poison: 0,
      );
      await tester.pumpWidget(wrapWithScaffold(
        PlayerQuadrantWidget(
          player: p,
          isTablet: false,
          opponents: const [],
        ),
      ));

      expect(find.byKey(const Key('death_reason_p1')), findsOneWidget);
      expect(find.text('Knocked Out: -7 Life'), findsOneWidget);
    });

    testWidgets('10 Poison shows "Knocked Out: 10 Poison"', (tester) async {
      final p = const PodPlayerState(
        id: 'p1',
        seatIndex: 0,
        name: 'Alice',
        life: 30,
        poison: 10,
      );
      await tester.pumpWidget(wrapWithScaffold(
        PlayerQuadrantWidget(
          player: p,
          isTablet: false,
          opponents: const [],
        ),
      ));

      expect(find.byKey(const Key('death_reason_p1')), findsOneWidget);
      expect(find.text('Knocked Out: 10 Poison'), findsOneWidget);
    });

    testWidgets('15 Poison shows "Knocked Out: 15 Poison"', (tester) async {
      final p = const PodPlayerState(
        id: 'p1',
        seatIndex: 0,
        name: 'Alice',
        life: 25,
        poison: 15,
      );
      await tester.pumpWidget(wrapWithScaffold(
        PlayerQuadrantWidget(
          player: p,
          isTablet: false,
          opponents: const [],
        ),
      ));

      expect(find.byKey(const Key('death_reason_p1')), findsOneWidget);
      expect(find.text('Knocked Out: 15 Poison'), findsOneWidget);
    });

    testWidgets('21 Commander Damage shows "Knocked Out: 21 Commander Damage"', (tester) async {
      final p = const PodPlayerState(
        id: 'p1',
        seatIndex: 0,
        name: 'Alice',
        life: 19,
        commanderDamageTaken: {'p2': 21},
      );
      await tester.pumpWidget(wrapWithScaffold(
        PlayerQuadrantWidget(
          player: p,
          isTablet: false,
          opponents: const [
            PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40),
          ],
        ),
      ));

      expect(find.byKey(const Key('death_reason_p1')), findsOneWidget);
      expect(find.text('Knocked Out: 21 Commander Damage'), findsOneWidget);
    });

    testWidgets('Priority order: 0 Life takes precedence over 10 Poison', (tester) async {
      final p = const PodPlayerState(
        id: 'p1',
        seatIndex: 0,
        name: 'Alice',
        life: 0,
        poison: 10,
      );
      await tester.pumpWidget(wrapWithScaffold(
        PlayerQuadrantWidget(
          player: p,
          isTablet: false,
          opponents: const [],
        ),
      ));

      expect(find.byKey(const Key('death_reason_p1')), findsOneWidget);
      expect(find.text('Knocked Out: 0 Life'), findsOneWidget);
    });

    testWidgets('Priority order: 10 Poison takes precedence over 21 Commander Damage when life > 0', (tester) async {
      final p = const PodPlayerState(
        id: 'p1',
        seatIndex: 0,
        name: 'Alice',
        life: 15,
        poison: 10,
        commanderDamageTaken: {'p2': 21},
      );
      await tester.pumpWidget(wrapWithScaffold(
        PlayerQuadrantWidget(
          player: p,
          isTablet: false,
          opponents: const [
            PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40),
          ],
        ),
      ));

      expect(find.byKey(const Key('death_reason_p1')), findsOneWidget);
      expect(find.text('Knocked Out: 10 Poison'), findsOneWidget);
    });

    testWidgets('Manual Elimination shows "Knocked Out: Eliminated"', (tester) async {
      final p = const PodPlayerState(
        id: 'p1',
        seatIndex: 0,
        name: 'Alice',
        life: 40,
        isEliminated: true,
      );
      await tester.pumpWidget(wrapWithScaffold(
        PlayerQuadrantWidget(
          player: p,
          isTablet: false,
          opponents: const [],
        ),
      ));

      expect(find.byKey(const Key('death_reason_p1')), findsOneWidget);
      expect(find.text('Knocked Out: Eliminated'), findsOneWidget);
    });
  });

  // ===========================================================================
  // CHALLENGE 6: Ignore/Revive Override and Non-Lethal Auto-Recovery
  // ===========================================================================
  group('6. Ignore/Revive Override and Non-Lethal Auto-Recovery', () {
    test('PodController full lifecycle: 0 Life -> Ignore KO -> Heal -> Lethal again triggers Auto-KO', () async {
      const initialPod = PodState(
        sessionId: 'revive_session',
        format: 'commander',
        startingLife: 40,
        autoKo: true,
        players: [
          PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40),
          PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40),
        ],
      );
      final controller = PodController(initialState: initialPod);

      // 1. Take lethal damage to 0 life
      await controller.adjustLife('p1', -40);
      var p1 = controller.state.getPlayer('p1')!;
      expect(p1.life, 0);
      expect(p1.isEliminated, isTrue);
      expect(p1.isKoIgnored, isFalse);

      // 2. Ignore KO (Platinum Angel effect)
      controller.ignoreKo('p1');
      p1 = controller.state.getPlayer('p1')!;
      expect(p1.isKoIgnored, isTrue);
      expect(p1.isEliminated, isFalse);

      // 3. Heal above lethal (+10 life -> 10)
      await controller.adjustLife('p1', 10);
      p1 = controller.state.getPlayer('p1')!;
      expect(p1.life, 10);
      expect(p1.isEliminated, isFalse);
      // Auto-recovery MUST reset isKoIgnored back to false!
      expect(p1.isKoIgnored, isFalse);

      // 4. Knocked out again (-10 life -> 0)
      await controller.adjustLife('p1', -10);
      p1 = controller.state.getPlayer('p1')!;
      expect(p1.life, 0);
      // Auto-KO MUST trigger again!
      expect(p1.isEliminated, isTrue);
      expect(p1.isKoIgnored, isFalse);
    });

    test('PodController commander damage recovery: 21 cmd dmg -> Ignore KO -> Lower dmg -> 21 again triggers Auto-KO', () async {
      const initialPod = PodState(
        sessionId: 'cmd_revive_session',
        format: 'commander',
        startingLife: 40,
        autoKo: true,
        players: [
          PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40),
          PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40),
        ],
      );
      final controller = PodController(initialState: initialPod);

      // Reaches 21 commander damage (life decoupled or > 0)
      controller.toggleCommanderDamageLifeLoss(false);
      await controller.recordCommanderDamage(
        targetPlayerId: 'p1',
        sourcePlayerId: 'p2',
        damageDelta: 21,
      );
      var p1 = controller.state.getPlayer('p1')!;
      expect(p1.commanderDamageTaken['p2'], 21);
      expect(p1.isEliminated, isTrue);
      expect(p1.isKoIgnored, isFalse);

      // Ignore KO
      controller.ignoreKo('p1');
      p1 = controller.state.getPlayer('p1')!;
      expect(p1.isKoIgnored, isTrue);
      expect(p1.isEliminated, isFalse);

      // Lower commander damage to 15 (undo or correction)
      await controller.recordCommanderDamage(
        targetPlayerId: 'p1',
        sourcePlayerId: 'p2',
        damageDelta: -6,
      );
      p1 = controller.state.getPlayer('p1')!;
      expect(p1.commanderDamageTaken['p2'], 15);
      expect(p1.hasAnyLethalCommanderDamage, isFalse);
      // Non-lethal state resets isKoIgnored to false!
      expect(p1.isKoIgnored, isFalse);

      // Take 6 damage again to reach 21
      await controller.recordCommanderDamage(
        targetPlayerId: 'p1',
        sourcePlayerId: 'p2',
        damageDelta: 6,
      );
      p1 = controller.state.getPlayer('p1')!;
      expect(p1.commanderDamageTaken['p2'], 21);
      expect(p1.isEliminated, isTrue);
      expect(p1.isKoIgnored, isFalse);
    });

    test('PodController poison recovery: 10 poison -> Ignore KO -> Lower poison -> 10 again triggers Auto-KO', () async {
      const initialPod = PodState(
        sessionId: 'poison_revive_session',
        format: 'commander',
        startingLife: 40,
        autoKo: true,
        players: [
          PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40),
          PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40),
        ],
      );
      final controller = PodController(initialState: initialPod);

      // 10 poison
      await controller.adjustCounter(playerId: 'p1', counterType: 'poison', delta: 10);
      expect(controller.state.getPlayer('p1')!.isEliminated, isTrue);

      // Ignore KO
      controller.ignoreKo('p1');
      expect(controller.state.getPlayer('p1')!.isKoIgnored, isTrue);

      // Reduce poison to 8 (non-lethal)
      await controller.adjustCounter(playerId: 'p1', counterType: 'poison', delta: -2);
      expect(controller.state.getPlayer('p1')!.isPoisonLethal, isFalse);
      expect(controller.state.getPlayer('p1')!.isKoIgnored, isFalse); // Reset!

      // Increase poison back to 10
      await controller.adjustCounter(playerId: 'p1', counterType: 'poison', delta: 2);
      expect(controller.state.getPlayer('p1')!.isPoisonLethal, isTrue);
      expect(controller.state.getPlayer('p1')!.isEliminated, isTrue);
    });

    test('Compound lethal state: healing life does NOT reset isKoIgnored if 21 commander damage remains', () async {
      const initialPod = PodState(
        sessionId: 'compound_session',
        format: 'commander',
        startingLife: 40,
        autoKo: true,
        commanderDamageLifeLoss: false, // decouple to independently manage life and cmd dmg
        players: [
          PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40),
          PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40),
        ],
      );
      final controller = PodController(initialState: initialPod);

      // Both life=0 and cmdDmg=21
      await controller.adjustLife('p1', -40);
      await controller.recordCommanderDamage(
        targetPlayerId: 'p1',
        sourcePlayerId: 'p2',
        damageDelta: 21,
      );
      expect(controller.state.getPlayer('p1')!.life, 0);
      expect(controller.state.getPlayer('p1')!.commanderDamageTaken['p2'], 21);

      // Ignore KO
      controller.ignoreKo('p1');
      expect(controller.state.getPlayer('p1')!.isKoIgnored, isTrue);

      // Heal life to 20: commander damage is STILL 21!
      await controller.adjustLife('p1', 20);
      var p1 = controller.state.getPlayer('p1')!;
      expect(p1.life, 20);
      // Invariant: isKoIgnored MUST remain true because the player is still in a lethal commander damage state
      expect(p1.isKoIgnored, isTrue);
    });

    testWidgets('Tapping "Ignore / Revive" button in UI dismisses overlay', (tester) async {
      bool ignoreCalled = false;
      final p = const PodPlayerState(
        id: 'p1',
        seatIndex: 0,
        name: 'Alice',
        life: 0,
      );

      await tester.pumpWidget(wrapWithScaffold(
        PlayerQuadrantWidget(
          player: p,
          isTablet: false,
          opponents: const [],
          onIgnoreKo: () => ignoreCalled = true,
        ),
      ));

      expect(find.byKey(const Key('btn_ignore_revive_p1')), findsOneWidget);
      await tester.tap(find.byKey(const Key('btn_ignore_revive_p1')));
      await tester.pump();
      expect(ignoreCalled, isTrue);

      // When state has isKoIgnored: true, overlay is gone
      final ignored = p.copyWith(isKoIgnored: true, isEliminated: false);
      await tester.pumpWidget(wrapWithScaffold(
        PlayerQuadrantWidget(
          player: ignored,
          isTablet: false,
          opponents: const [],
        ),
      ));

      expect(find.text('ELIMINATED'), findsNothing);
      expect(find.byKey(const Key('btn_ignore_revive_p1')), findsNothing);
    });
  });

  // ===========================================================================
  // CHALLENGE 7: Secondary Counters (+rad clamp, tax +2, exclusive monarch/init)
  // ===========================================================================
  group('7. Secondary Counters & Pod-Wide Token Invariants', () {
    test('Radiation counter underflow clamp at 0 across aliases (rad, rad_counters, radiation)', () async {
      const initialPod = PodState(
        sessionId: 'rad_session',
        format: 'commander',
        startingLife: 40,
        players: [
          PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40, radCounters: 3),
        ],
      );
      final controller = PodController(initialState: initialPod);

      // Subtract 5 (clamps to 0)
      await controller.adjustCounter(playerId: 'p1', counterType: 'rad', delta: -5);
      expect(controller.state.players.first.radCounters, 0);

      // Decrementing from 0 stays 0
      await controller.adjustCounter(playerId: 'p1', counterType: 'rad', delta: -1);
      expect(controller.state.players.first.radCounters, 0);

      // Increment with 'radiation' alias
      await controller.adjustCounter(playerId: 'p1', counterType: 'radiation', delta: 4);
      expect(controller.state.players.first.radCounters, 4);

      // Decrement with 'rad_counters' alias
      await controller.adjustCounter(playerId: 'p1', counterType: 'rad_counters', delta: -2);
      expect(controller.state.players.first.radCounters, 2);
    });

    test('Energy and Experience underflow clamp at 0', () async {
      const initialPod = PodState(
        sessionId: 'energy_xp_session',
        format: 'commander',
        startingLife: 40,
        players: [
          PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40, energy: 2, experience: 1),
        ],
      );
      final controller = PodController(initialState: initialPod);

      await controller.adjustCounter(playerId: 'p1', counterType: 'energy', delta: -10);
      expect(controller.state.players.first.energy, 0);

      await controller.adjustCounter(playerId: 'p1', counterType: 'experience', delta: -10);
      expect(controller.state.players.first.experience, 0);
    });

    test('Commander tax stepper increment (+2 mana per cast) and underflow clamp', () async {
      const initialPod = PodState(
        sessionId: 'tax_session',
        format: 'commander',
        startingLife: 40,
        players: [
          PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40, commanderTax: 0),
        ],
      );
      final controller = PodController(initialState: initialPod);

      // Decrement at 0 clamps to 0
      await controller.adjustCounter(playerId: 'p1', counterType: 'commandertax', delta: -1);
      expect(controller.state.players.first.commanderTax, 0);

      // 3 casts (+6 mana tax)
      await controller.adjustCounter(playerId: 'p1', counterType: 'commander_tax', delta: 1);
      await controller.adjustCounter(playerId: 'p1', counterType: 'commanderTax', delta: 2);
      expect(controller.state.players.first.commanderTax, 3);
    });

    test('Exclusive Monarch and Initiative: claim steals, toggle-off clears', () async {
      const initialPod = PodState(
        sessionId: 'tokens_session',
        format: 'commander',
        startingLife: 40,
        players: [
          PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40),
          PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40),
          PodPlayerState(id: 'p3', seatIndex: 2, name: 'Charlie', life: 40),
        ],
      );
      final controller = PodController(initialState: initialPod);

      // 1. Player 1 claims Monarch
      await controller.claimToken(tokenType: 'monarch', claimantId: 'p1');
      expect(controller.state.getPlayer('p1')!.isMonarch, isTrue);
      expect(controller.state.getPlayer('p2')!.isMonarch, isFalse);
      expect(controller.state.getPlayer('p3')!.isMonarch, isFalse);

      // 2. Player 2 claims Monarch -> stolen from P1
      await controller.claimToken(tokenType: 'monarch', claimantId: 'p2');
      expect(controller.state.getPlayer('p1')!.isMonarch, isFalse);
      expect(controller.state.getPlayer('p2')!.isMonarch, isTrue);
      expect(controller.state.getPlayer('p3')!.isMonarch, isFalse);

      // 3. Player 2 taps Monarch again -> toggles OFF
      await controller.claimToken(tokenType: 'monarch', claimantId: 'p2');
      expect(controller.state.getPlayer('p1')!.isMonarch, isFalse);
      expect(controller.state.getPlayer('p2')!.isMonarch, isFalse);
      expect(controller.state.getPlayer('p3')!.isMonarch, isFalse);

      // 4. Player 3 claims Initiative
      await controller.claimToken(tokenType: 'initiative', claimantId: 'p3');
      expect(controller.state.getPlayer('p3')!.hasInitiative, isTrue);
      expect(controller.state.getPlayer('p1')!.hasInitiative, isFalse);

      // 5. Player 1 claims Initiative -> stolen from P3
      await controller.claimToken(tokenType: 'initiative', claimantId: 'p1');
      expect(controller.state.getPlayer('p1')!.hasInitiative, isTrue);
      expect(controller.state.getPlayer('p3')!.hasInitiative, isFalse);

      // 6. Player 1 can hold both Monarch AND Initiative simultaneously
      await controller.claimToken(tokenType: 'monarch', claimantId: 'p1');
      expect(controller.state.getPlayer('p1')!.isMonarch, isTrue);
      expect(controller.state.getPlayer('p1')!.hasInitiative, isTrue);
    });

    testWidgets('UI Drawer & Badges: tax renders "+4", rad renders "☢ 4", Monarch/Initiative pills render and claim', (tester) async {
      final counterDeltas = <String, int>{};
      bool claimedMonarch = false;
      bool claimedInit = false;

      final p = const PodPlayerState(
        id: 'p1',
        seatIndex: 0,
        name: 'Alice',
        life: 40,
        commanderTax: 2, // displays as +4
        radCounters: 4,
        isMonarch: true,
        hasInitiative: true,
      );

      // Check drawer UI
      await tester.pumpWidget(wrapWithScaffold(
        PlayerStatusDrawerContent(
          player: p,
          onCounterDelta: (t, d) => counterDeltas[t] = d,
          onClaimMonarch: () => claimedMonarch = true,
          onClaimInitiative: () => claimedInit = true,
        ),
      ));

      expect(find.byKey(const Key('val_tax_p1')), findsOneWidget);
      expect(find.text('+4'), findsOneWidget);

      expect(find.byKey(const Key('val_rad_p1')), findsOneWidget);
      expect(find.text('4'), findsOneWidget);

      // Tap tax increment
      await tester.tap(find.byKey(const Key('inc_tax_p1')));
      expect(counterDeltas['commanderTax'], 1);

      // Tap rad decrement
      await tester.tap(find.byKey(const Key('dec_rad_p1')));
      expect(counterDeltas['rad'], -1);

      // Tap monarch toggle
      await tester.tap(find.byKey(const Key('toggle_monarch_p1')));
      expect(claimedMonarch, isTrue);

      // Tap initiative toggle
      await tester.tap(find.byKey(const Key('toggle_initiative_p1')));
      expect(claimedInit, isTrue);
    });
  });

  // ===========================================================================
  // CHALLENGE 8: Spatial Mini-Grid Layouts Across 2P-6P & Card Densities
  // ===========================================================================
  group('8. Spatial Mini-Grid Layouts Across 2P-6P & Card Density Modes', () {
    final player = const PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40);

    testWidgets('2P: 1 opponent cell', (tester) async {
      final opponents = const [
        PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40),
      ];

      await tester.pumpWidget(wrapWithScaffold(
        CommanderSpatialMiniGrid(
          player: player,
          opponents: opponents,
        ),
      ));

      expect(find.byKey(const Key('cmd_mini_grid_p1')), findsOneWidget);
      expect(find.byKey(const Key('cmd_mini_slot_p2')), findsOneWidget);
    });

    testWidgets('3P: 2 opponent cells in 1 row', (tester) async {
      final opponents = const [
        PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40),
        PodPlayerState(id: 'p3', seatIndex: 2, name: 'Charlie', life: 40),
      ];

      await tester.pumpWidget(wrapWithScaffold(
        CommanderSpatialMiniGrid(
          player: player,
          opponents: opponents,
        ),
      ));

      expect(find.byKey(const Key('cmd_mini_grid_p1')), findsOneWidget);
      expect(find.byKey(const Key('cmd_mini_slot_p2')), findsOneWidget);
      expect(find.byKey(const Key('cmd_mini_slot_p3')), findsOneWidget);
    });

    testWidgets('4P: 2x2 grid (3 opponents + 1 self placeholder)', (tester) async {
      final opponents = const [
        PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40),
        PodPlayerState(id: 'p3', seatIndex: 2, name: 'Charlie', life: 40),
        PodPlayerState(id: 'p4', seatIndex: 3, name: 'Diana', life: 40),
      ];

      await tester.pumpWidget(wrapWithScaffold(
        CommanderSpatialMiniGrid(
          player: player,
          opponents: opponents,
        ),
      ));

      expect(find.byKey(const Key('cmd_mini_grid_p1')), findsOneWidget);
      expect(find.byKey(const Key('cmd_mini_slot_p2')), findsOneWidget);
      expect(find.byKey(const Key('cmd_mini_slot_p3')), findsOneWidget);
      expect(find.byKey(const Key('cmd_mini_slot_p4')), findsOneWidget);
    });

    testWidgets('5P: 2 rows of 2 opponents', (tester) async {
      final opponents = const [
        PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40),
        PodPlayerState(id: 'p3', seatIndex: 2, name: 'Charlie', life: 40),
        PodPlayerState(id: 'p4', seatIndex: 3, name: 'Diana', life: 40),
        PodPlayerState(id: 'p5', seatIndex: 4, name: 'Evan', life: 40),
      ];

      await tester.pumpWidget(wrapWithScaffold(
        CommanderSpatialMiniGrid(
          player: player,
          opponents: opponents,
        ),
      ));

      expect(find.byKey(const Key('cmd_mini_grid_p1')), findsOneWidget);
      expect(find.byKey(const Key('cmd_mini_slot_p2')), findsOneWidget);
      expect(find.byKey(const Key('cmd_mini_slot_p3')), findsOneWidget);
      expect(find.byKey(const Key('cmd_mini_slot_p4')), findsOneWidget);
      expect(find.byKey(const Key('cmd_mini_slot_p5')), findsOneWidget);
    });

    testWidgets('6P: 2 rows (3 top, 2 bottom) for 5 opponents', (tester) async {
      final opponents = const [
        PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40),
        PodPlayerState(id: 'p3', seatIndex: 2, name: 'Charlie', life: 40),
        PodPlayerState(id: 'p4', seatIndex: 3, name: 'Diana', life: 40),
        PodPlayerState(id: 'p5', seatIndex: 4, name: 'Evan', life: 40),
        PodPlayerState(id: 'p6', seatIndex: 5, name: 'Fiona', life: 40),
      ];

      await tester.pumpWidget(wrapWithScaffold(
        CommanderSpatialMiniGrid(
          player: player,
          opponents: opponents,
        ),
      ));

      expect(find.byKey(const Key('cmd_mini_grid_p1')), findsOneWidget);
      expect(find.byKey(const Key('cmd_mini_slot_p2')), findsOneWidget);
      expect(find.byKey(const Key('cmd_mini_slot_p3')), findsOneWidget);
      expect(find.byKey(const Key('cmd_mini_slot_p4')), findsOneWidget);
      expect(find.byKey(const Key('cmd_mini_slot_p5')), findsOneWidget);
      expect(find.byKey(const Key('cmd_mini_slot_p6')), findsOneWidget);
    });

    testWidgets('Card density gating: Default shows mini-grid; Name only and Big font hide mini-grid', (tester) async {
      final opponents = const [
        PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40),
      ];

      // 1. Default: mini-grid visible
      await tester.pumpWidget(wrapWithScaffold(
        PlayerQuadrantWidget(
          player: player,
          isTablet: false,
          opponents: opponents,
          cardDensity: 'Default',
        ),
      ));
      expect(find.byKey(const Key('cmd_mini_grid_p1')), findsOneWidget);

      // 2. Name only: mini-grid hidden
      await tester.pumpWidget(wrapWithScaffold(
        PlayerQuadrantWidget(
          player: player,
          isTablet: false,
          opponents: opponents,
          cardDensity: 'Name only',
        ),
      ));
      expect(find.byKey(const Key('cmd_mini_grid_p1')), findsNothing);

      // 3. Big font: mini-grid hidden
      await tester.pumpWidget(wrapWithScaffold(
        PlayerQuadrantWidget(
          player: player,
          isTablet: false,
          opponents: opponents,
          cardDensity: 'Big font',
        ),
      ));
      expect(find.byKey(const Key('cmd_mini_grid_p1')), findsNothing);
    });

    testWidgets('Mini-grid slot tap triggers onCommanderDamage callback', (tester) async {
      String? damagedOppId;
      int? reportedDelta;

      final opponents = const [
        PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40),
      ];

      await tester.pumpWidget(wrapWithScaffold(
        PlayerQuadrantWidget(
          player: player,
          isTablet: false,
          opponents: opponents,
          onCommanderDamage: (oppId, delta) {
            damagedOppId = oppId;
            reportedDelta = delta;
          },
        ),
      ));

      await tester.tap(find.byKey(const Key('cmd_damage_btn_p1_from_p2')));
      await tester.pump();

      expect(damagedOppId, 'p2');
      expect(reportedDelta, 1);
    });

    testWidgets('Colorize mini-grid cells tints opponent background correctly', (tester) async {
      final opponents = const [
        PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40, colorTheme: 'U'),
      ];

      // With colorize = true
      await tester.pumpWidget(wrapWithScaffold(
        CommanderSpatialMiniGrid(
          player: player,
          opponents: opponents,
          colorize: true,
        ),
      ));

      final containerFinder = find.byKey(const Key('cmd_mini_slot_p2'));
      expect(containerFinder, findsOneWidget);
      final Container container = tester.widget(containerFinder);
      final BoxDecoration dec = container.decoration as BoxDecoration;
      expect(dec.color, equals(const Color(0xFF0E68AB).withValues(alpha: 0.28)));

      // When lethal (21 dmg), redAccent overrides the opponent color
      final lethalP1 = player.copyWith(commanderDamageTaken: {'p2': 21});
      await tester.pumpWidget(wrapWithScaffold(
        CommanderSpatialMiniGrid(
          player: lethalP1,
          opponents: opponents,
          colorize: true,
        ),
      ));

      final Container lethalContainer = tester.widget(containerFinder);
      final BoxDecoration lethalDec = lethalContainer.decoration as BoxDecoration;
      expect(lethalDec.color, equals(Colors.redAccent.withValues(alpha: 0.85)));
    });
  });
}
