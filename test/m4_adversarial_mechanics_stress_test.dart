// Copyright (c) 2026 Countr. All rights reserved.
// Adversarial Stress Test Suite for Milestone 4 Gate:
// 1. Commander Damage 21-point lethal threshold (single vs combined damage)
// 2. Poison 10-point lethal threshold & boundary transitions
// 3. Simultaneous multi-lethal triggers (dual & triple lethal without layout collision)
// 4. Monarch & Initiative pod-wide exclusive token stealing & cross-token non-interference
// 5. Day/Night cycle pod synchronization & state invariant integrity

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/features/life_counter/domain/models/pod_state.dart';
import 'package:countr/features/life_counter/presentation/controllers/pod_controller.dart';
import 'package:countr/features/life_counter/presentation/widgets/commander_damage_matrix.dart';
import 'package:countr/features/life_counter/presentation/widgets/day_night_toggle_widget.dart';
import 'package:countr/features/life_counter/presentation/widgets/player_quadrant_widget.dart';
import 'package:countr/features/life_counter/presentation/widgets/secondary_counters_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestHarness(Widget child, {Size size = const Size(800, 600)}) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: MediaQuery(
              data: MediaQueryData(size: size),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // SECTION 1: COMMANDER DAMAGE 21-POINT LETHAL THRESHOLD & MATRIX
  // ===========================================================================
  group('Adversarial 1: Commander Damage 21-Point Threshold & Matrix', () {
    const opp2 = PodPlayerState(
      id: 'p2',
      seatIndex: 1,
      name: 'Bob',
      life: 40,
      commanderArtCropUrl: 'https://cards.scryfall.io/art_crop/front/b/o/bob.jpg',
    );
    const opp3 = PodPlayerState(
      id: 'p3',
      seatIndex: 2,
      name: 'Charlie',
      life: 40,
    );
    const opp4 = PodPlayerState(
      id: 'p4',
      seatIndex: 3,
      name: 'Diana',
      life: 40,
    );

    test('Domain boundary: 20 commander damage from single opponent is NOT lethal', () {
      const p = PodPlayerState(
        id: 'p1',
        seatIndex: 0,
        name: 'Alice',
        life: 20,
        commanderDamageTaken: {'p2': 20},
      );
      expect(p.isCommanderDamageLethalFrom('p2'), isFalse);
      expect(p.hasAnyLethalCommanderDamage, isFalse);
      expect(p.isLethal, isFalse);
    });

    test('Domain boundary: exactly 21 commander damage from single opponent IS lethal', () {
      const p = PodPlayerState(
        id: 'p1',
        seatIndex: 0,
        name: 'Alice',
        life: 19,
        commanderDamageTaken: {'p2': 21},
      );
      expect(p.isCommanderDamageLethalFrom('p2'), isTrue);
      expect(p.hasAnyLethalCommanderDamage, isTrue);
      expect(p.isLethal, isTrue);
    });

    test('CRITICAL MTG RULE: Combined damage from multiple commanders does NOT trigger lethal', () {
      // Alice takes 15 from Bob, 15 from Charlie, 15 from Diana (total 45 commander damage taken)
      const p = PodPlayerState(
        id: 'p1',
        seatIndex: 0,
        name: 'Alice',
        life: 10,
        commanderDamageTaken: {'p2': 15, 'p3': 15, 'p4': 15},
      );

      // MTG Rule 903.10a: Each commander's damage is tracked separately!
      expect(p.isCommanderDamageLethalFrom('p2'), isFalse);
      expect(p.isCommanderDamageLethalFrom('p3'), isFalse);
      expect(p.isCommanderDamageLethalFrom('p4'), isFalse);
      expect(p.hasAnyLethalCommanderDamage, isFalse);
      // Life is 10, no poison, no single commander >= 21
      expect(p.isLethal, isFalse);
      expect(p.isEliminated, isFalse);
    });

    test('CRITICAL MTG RULE: Extreme combined damage (20+20+20 = 60) does NOT trigger commander lethal', () {
      const p = PodPlayerState(
        id: 'p1',
        seatIndex: 0,
        name: 'Alice',
        life: 40, // assume life gained back
        commanderDamageTaken: {'p2': 20, 'p3': 20, 'p4': 20},
      );

      expect(p.isCommanderDamageLethalFrom('p2'), isFalse);
      expect(p.isCommanderDamageLethalFrom('p3'), isFalse);
      expect(p.isCommanderDamageLethalFrom('p4'), isFalse);
      expect(p.hasAnyLethalCommanderDamage, isFalse);
      expect(p.isLethal, isFalse);
    });

    testWidgets('Widget stress: combined damage (15+15+15) shows NO lethal alert and NO red styling',
        (tester) async {
      const combinedDmgPlayer = PodPlayerState(
        id: 'p1',
        seatIndex: 0,
        name: 'Alice',
        life: 10,
        commanderDamageTaken: {'p2': 15, 'p3': 15, 'p4': 15},
      );

      await tester.pumpWidget(
        buildTestHarness(
          const CommanderDamageMatrixWidget(
            player: combinedDmgPlayer,
            opponents: [opp2, opp3, opp4],
            isTablet: true,
          ),
        ),
      );

      // Check Bob's button styling
      final bobBtnFinder = find.ancestor(
        of: find.text('Bob: 15'),
        matching: find.byType(AnimatedContainer),
      );
      expect(bobBtnFinder, findsOneWidget);
      final bobContainer = tester.widget<AnimatedContainer>(bobBtnFinder);
      final bobDec = bobContainer.decoration as BoxDecoration;
      expect(bobDec.color, isNot(equals(Colors.red.shade700)));

      // Check Charlie's button styling
      final charlieBtnFinder = find.ancestor(
        of: find.text('Cha: 15'),
        matching: find.byType(AnimatedContainer),
      );
      expect(charlieBtnFinder, findsOneWidget);
      final charlieContainer = tester.widget<AnimatedContainer>(charlieBtnFinder);
      final charlieDec = charlieContainer.decoration as BoxDecoration;
      expect(charlieDec.color, isNot(equals(Colors.red.shade700)));

      // Check Diana's button styling
      final dianaBtnFinder = find.ancestor(
        of: find.text('Dia: 15'),
        matching: find.byType(AnimatedContainer),
      );
      expect(dianaBtnFinder, findsOneWidget);
      final dianaContainer = tester.widget<AnimatedContainer>(dianaBtnFinder);
      final dianaDec = dianaContainer.decoration as BoxDecoration;
      expect(dianaDec.color, isNot(equals(Colors.red.shade700)));
    });

    testWidgets('Widget stress: single commander reaches 21, exactly its button turns red',
        (tester) async {
      const partialLethalPlayer = PodPlayerState(
        id: 'p1',
        seatIndex: 0,
        name: 'Alice',
        life: 10,
        commanderDamageTaken: {'p2': 21, 'p3': 18},
      );

      await tester.pumpWidget(
        buildTestHarness(
          const CommanderDamageMatrixWidget(
            player: partialLethalPlayer,
            opponents: [opp2, opp3],
            isTablet: true,
          ),
        ),
      );

      // Bob reached 21 -> RED alert styling
      final bobBtnFinder = find.ancestor(
        of: find.text('Bob: 21'),
        matching: find.byType(AnimatedContainer),
      );
      final bobContainer = tester.widget<AnimatedContainer>(bobBtnFinder);
      final bobDec = bobContainer.decoration as BoxDecoration;
      expect(bobDec.color, equals(Colors.red.shade700));

      // Charlie has 18 -> NOT red alert
      final charlieBtnFinder = find.ancestor(
        of: find.text('Cha: 18'),
        matching: find.byType(AnimatedContainer),
      );
      final charlieContainer = tester.widget<AnimatedContainer>(charlieBtnFinder);
      final charlieDec = charlieContainer.decoration as BoxDecoration;
      expect(charlieDec.color, isNot(equals(Colors.red.shade700)));
    });

    testWidgets('Quadrant banner: combined damage (15+15) does NOT display commander lethal banner',
        (tester) async {
      const nonLethalPlayer = PodPlayerState(
        id: 'p1',
        seatIndex: 0,
        name: 'Alice',
        life: 10,
        commanderDamageTaken: {'p2': 15, 'p3': 15},
      );

      await tester.pumpWidget(
        buildTestHarness(
          const PlayerQuadrantWidget(
            player: nonLethalPlayer,
            isTablet: true,
            opponents: [opp2, opp3],
          ),
        ),
      );

      expect(find.byKey(const Key('commander_lethal_alert_p1')), findsNothing);
      expect(find.text('LETHAL COMMANDER DAMAGE (21+)'), findsNothing);
    });

    testWidgets('Quadrant banner: single commander reaching 21 DOES display commander lethal banner',
        (tester) async {
      const lethalPlayer = PodPlayerState(
        id: 'p1',
        seatIndex: 0,
        name: 'Alice',
        life: 19,
        commanderDamageTaken: {'p2': 21, 'p3': 5},
      );

      await tester.pumpWidget(
        buildTestHarness(
          const PlayerQuadrantWidget(
            player: lethalPlayer,
            isTablet: true,
            opponents: [opp2, opp3],
          ),
        ),
      );

      expect(find.byKey(const Key('commander_lethal_alert_p1')), findsOneWidget);
      expect(find.text('LETHAL COMMANDER DAMAGE (21+)'), findsOneWidget);
    });

    test('PodController: recordCommanderDamage reaching 21 sets isEliminated to true', () async {
      final controller = PodController(
        initialState: const PodState(
          sessionId: 'stress_cmd_session',
          format: 'commander',
          startingLife: 40,
          players: [
            PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40),
            PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40),
            PodPlayerState(id: 'p3', seatIndex: 2, name: 'Charlie', life: 40),
          ],
        ),
      );

      // Deal 15 damage from Bob
      await controller.recordCommanderDamage(
        targetPlayerId: 'p1',
        sourcePlayerId: 'p2',
        damageDelta: 15,
      );
      expect(controller.state.getPlayer('p1')!.life, 25);
      expect(controller.state.getPlayer('p1')!.isEliminated, isFalse);

      // Deal 15 damage from Charlie (total cmd dmg = 30)
      await controller.recordCommanderDamage(
        targetPlayerId: 'p1',
        sourcePlayerId: 'p3',
        damageDelta: 15,
      );
      expect(controller.state.getPlayer('p1')!.life, 10);
      expect(controller.state.getPlayer('p1')!.hasAnyLethalCommanderDamage, isFalse);
      expect(controller.state.getPlayer('p1')!.isEliminated, isFalse);

      // Deal 6 more from Bob -> Bob reaches 21
      await controller.recordCommanderDamage(
        targetPlayerId: 'p1',
        sourcePlayerId: 'p2',
        damageDelta: 6,
      );
      final p1 = controller.state.getPlayer('p1')!;
      expect(p1.commanderDamageTaken['p2'], 21);
      expect(p1.commanderDamageTaken['p3'], 15);
      expect(p1.hasAnyLethalCommanderDamage, isTrue);
      expect(p1.isEliminated, isTrue);

      controller.dispose();
    });
  });

  // ===========================================================================
  // SECTION 2: POISON 10-POINT LETHAL THRESHOLD & BOUNDARY TRANSITIONS
  // ===========================================================================
  group('Adversarial 2: Poison 10-Point Lethal Threshold & Boundaries', () {
    test('Boundary 9 poison is NOT lethal; exactly 10 poison IS lethal', () {
      const p9 = PodPlayerState(
        id: 'p1',
        seatIndex: 0,
        name: 'Alice',
        life: 40,
        poison: 9,
      );
      expect(p9.isPoisonLethal, isFalse);
      expect(p9.isLethal, isFalse);

      const p10 = PodPlayerState(
        id: 'p1',
        seatIndex: 0,
        name: 'Alice',
        life: 40,
        poison: 10,
      );
      expect(p10.isPoisonLethal, isTrue);
      expect(p10.isLethal, isTrue);

      const p15 = PodPlayerState(
        id: 'p1',
        seatIndex: 0,
        name: 'Alice',
        life: 40,
        poison: 15,
      );
      expect(p15.isPoisonLethal, isTrue);
      expect(p15.isLethal, isTrue);
    });

    testWidgets('Widget boundary: poison at 9 has green accent, transitions to red accent at 10',
        (tester) async {
      var currentPlayer = const PodPlayerState(
        id: 'p1',
        seatIndex: 0,
        name: 'Alice',
        life: 40,
        poison: 9,
      );

      await tester.pumpWidget(
        buildTestHarness(
          StatefulBuilder(
            builder: (context, setState) {
              return SecondaryCountersBar(
                player: currentPlayer,
                isTablet: true,
                onCounterDelta: (counter, delta) {
                  if (counter == 'poison') {
                    setState(() {
                      currentPlayer = currentPlayer.copyWith(
                        poison: currentPlayer.poison + delta,
                      );
                    });
                  }
                },
              );
            },
          ),
        ),
      );

      // Verify initial 9 poison has green accent styling
      final textFinder9 = find.text('☠️ 9');
      expect(textFinder9, findsOneWidget);
      final textWidget9 = tester.widget<Text>(textFinder9);
      expect(textWidget9.style?.color, equals(Colors.greenAccent));

      // Tap increment to hit 10
      await tester.tap(find.byKey(const Key('inc_poison_p1')));
      await tester.pump();

      // Verify 10 poison now has red accent styling
      final textFinder10 = find.text('☠️ 10');
      expect(textFinder10, findsOneWidget);
      final textWidget10 = tester.widget<Text>(textFinder10);
      expect(textWidget10.style?.color, equals(Colors.redAccent));

      // Decrement back to 9 -> reverts to green accent
      await tester.tap(find.byKey(const Key('dec_poison_p1')));
      await tester.pump();

      final textFinderReverted = find.text('☠️ 9');
      expect(textFinderReverted, findsOneWidget);
      final textWidgetReverted = tester.widget<Text>(textFinderReverted);
      expect(textWidgetReverted.style?.color, equals(Colors.greenAccent));
    });

    test('PodController: incrementing poison to 10 sets isEliminated to true', () async {
      final controller = PodController(
        initialState: const PodState(
          sessionId: 'poison_session',
          format: 'commander',
          startingLife: 40,
          players: [
            PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40, poison: 9),
          ],
        ),
      );

      expect(controller.state.getPlayer('p1')!.isEliminated, isFalse);

      await controller.adjustCounter(playerId: 'p1', counterType: 'poison', delta: 1);
      final p1 = controller.state.getPlayer('p1')!;
      expect(p1.poison, 10);
      expect(p1.isPoisonLethal, isTrue);
      expect(p1.isEliminated, isTrue);

      controller.dispose();
    });
  });

  // ===========================================================================
  // SECTION 3: SIMULTANEOUS MULTI-LETHAL TRIGGERS
  // ===========================================================================
  group('Adversarial 3: Simultaneous Multi-Lethal Triggers', () {
    const opp2 = PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40);

    testWidgets('Dual lethal: 10 Poison AND 21 Commander Damage render BOTH banners simultaneously',
        (tester) async {
      const dualLethalPlayer = PodPlayerState(
        id: 'p1',
        seatIndex: 0,
        name: 'Alice',
        life: 15,
        poison: 10,
        commanderDamageTaken: {'p2': 21},
        isEliminated: true,
      );

      await tester.pumpWidget(
        buildTestHarness(
          const PlayerQuadrantWidget(
            player: dualLethalPlayer,
            isTablet: true,
            opponents: [opp2],
          ),
        ),
      );

      // Both lethal alerts are rendered
      expect(find.byKey(const Key('commander_lethal_alert_p1')), findsOneWidget);
      expect(find.text('LETHAL COMMANDER DAMAGE (21+)'), findsOneWidget);

      expect(find.byKey(const Key('poison_lethal_alert_p1')), findsOneWidget);
      expect(find.text('LETHAL POISON (10+)'), findsOneWidget);

      // ELIMINATED overlay rendered
      expect(find.text('ELIMINATED'), findsOneWidget);

      // Zero RenderFlex overflows
      expect(tester.takeException(), isNull);
    });

    testWidgets('Triple lethal: 0 Life AND 10 Poison AND 21 Commander Damage render cleanly',
        (tester) async {
      const tripleLethalPlayer = PodPlayerState(
        id: 'p1',
        seatIndex: 0,
        name: 'Alice',
        life: 0,
        poison: 12,
        commanderDamageTaken: {'p2': 23},
        isEliminated: true,
      );

      await tester.pumpWidget(
        buildTestHarness(
          const PlayerQuadrantWidget(
            player: tripleLethalPlayer,
            isTablet: false, // test phone compact mode
            opponents: [opp2],
          ),
          size: const Size(380, 500),
        ),
      );

      expect(find.byKey(const Key('commander_lethal_alert_p1')), findsOneWidget);
      expect(find.byKey(const Key('poison_lethal_alert_p1')), findsOneWidget);
      expect(find.text('ELIMINATED'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('PodController: simultaneous lethal states maintain elimination invariant', () async {
      final controller = PodController(
        initialState: const PodState(
          sessionId: 'multi_lethal_session',
          format: 'commander',
          startingLife: 40,
          players: [
            PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 1, poison: 10),
            PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40),
          ],
        ),
      );

      // Player 1 has 10 poison. Now takes lethal commander damage too.
      await controller.recordCommanderDamage(
        targetPlayerId: 'p1',
        sourcePlayerId: 'p2',
        damageDelta: 21,
      );

      final p1 = controller.state.getPlayer('p1')!;
      expect(p1.life, -20);
      expect(p1.poison, 10);
      expect(p1.isPoisonLethal, isTrue);
      expect(p1.hasAnyLethalCommanderDamage, isTrue);
      expect(p1.isLethal, isTrue);
      expect(p1.isEliminated, isTrue);

      controller.dispose();
    });
  });

  // ===========================================================================
  // SECTION 4: MONARCH & INITIATIVE POD-WIDE EXCLUSIVE TOKEN STEALING
  // ===========================================================================
  group('Adversarial 4: Monarch & Initiative Token Exclusivity & Non-Interference', () {
    test('Monarch Pod-Wide Exclusivity: claiming steals from previous holder atomically', () async {
      final controller = PodController(
        initialState: const PodState(
          sessionId: 'token_session',
          format: 'commander',
          startingLife: 40,
          players: [
            PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40),
            PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40),
            PodPlayerState(id: 'p3', seatIndex: 2, name: 'Charlie', life: 40),
            PodPlayerState(id: 'p4', seatIndex: 3, name: 'Diana', life: 40),
          ],
        ),
      );

      // Invariant helper
      void assertMonarchCount(int expectedCount, String? expectedHolderId) {
        final monarchs = controller.state.players.where((p) => p.isMonarch).toList();
        expect(monarchs.length, expectedCount);
        if (expectedHolderId != null) {
          expect(monarchs.first.id, expectedHolderId);
        }
      }

      // Step 0: Initially nobody is Monarch
      assertMonarchCount(0, null);

      // Step 1: P1 claims Monarch
      await controller.claimToken(tokenType: 'monarch', claimantId: 'p1');
      assertMonarchCount(1, 'p1');

      // Step 2: P2 steals Monarch
      await controller.claimToken(tokenType: 'monarch', claimantId: 'p2');
      assertMonarchCount(1, 'p2');
      expect(controller.state.getPlayer('p1')!.isMonarch, isFalse);

      // Step 3: P3 steals Monarch
      await controller.claimToken(tokenType: 'monarch', claimantId: 'p3');
      assertMonarchCount(1, 'p3');
      expect(controller.state.getPlayer('p2')!.isMonarch, isFalse);

      // Step 4: P4 steals Monarch
      await controller.claimToken(tokenType: 'monarch', claimantId: 'p4');
      assertMonarchCount(1, 'p4');
      expect(controller.state.getPlayer('p3')!.isMonarch, isFalse);

      // Step 5: P1 re-steals Monarch
      await controller.claimToken(tokenType: 'monarch', claimantId: 'p1');
      assertMonarchCount(1, 'p1');
      expect(controller.state.getPlayer('p4')!.isMonarch, isFalse);

      controller.dispose();
    });

    test('Initiative Pod-Wide Exclusivity: claiming steals from previous holder atomically', () async {
      final controller = PodController(
        initialState: const PodState(
          sessionId: 'init_session',
          format: 'commander',
          startingLife: 40,
          players: [
            PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40),
            PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40),
            PodPlayerState(id: 'p3', seatIndex: 2, name: 'Charlie', life: 40),
          ],
        ),
      );

      void assertInitCount(int expectedCount, String? expectedHolderId) {
        final holders = controller.state.players.where((p) => p.hasInitiative).toList();
        expect(holders.length, expectedCount);
        if (expectedHolderId != null) {
          expect(holders.first.id, expectedHolderId);
        }
      }

      assertInitCount(0, null);

      // P1 claims Initiative
      await controller.claimToken(tokenType: 'initiative', claimantId: 'p1');
      assertInitCount(1, 'p1');

      // P3 claims Initiative
      await controller.claimToken(tokenType: 'initiative', claimantId: 'p3');
      assertInitCount(1, 'p3');
      expect(controller.state.getPlayer('p1')!.hasInitiative, isFalse);

      controller.dispose();
    });

    test('Cross-Token Independence: Claiming Monarch does NOT affect Initiative (and vice versa)', () async {
      final controller = PodController(
        initialState: const PodState(
          sessionId: 'cross_token_session',
          format: 'commander',
          startingLife: 40,
          players: [
            PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40),
            PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40),
            PodPlayerState(id: 'p3', seatIndex: 2, name: 'Charlie', life: 40),
          ],
        ),
      );

      // P1 claims Monarch
      await controller.claimToken(tokenType: 'monarch', claimantId: 'p1');
      // P2 claims Initiative
      await controller.claimToken(tokenType: 'initiative', claimantId: 'p2');

      expect(controller.state.getPlayer('p1')!.isMonarch, isTrue);
      expect(controller.state.getPlayer('p1')!.hasInitiative, isFalse);
      expect(controller.state.getPlayer('p2')!.isMonarch, isFalse);
      expect(controller.state.getPlayer('p2')!.hasInitiative, isTrue);

      // P3 claims Monarch -> P1 loses Monarch, P2 MUST KEEP Initiative!
      await controller.claimToken(tokenType: 'monarch', claimantId: 'p3');
      expect(controller.state.getPlayer('p3')!.isMonarch, isTrue);
      expect(controller.state.getPlayer('p1')!.isMonarch, isFalse);
      expect(controller.state.getPlayer('p2')!.hasInitiative, isTrue,
          reason: 'P2 must retain Initiative when P3 claims Monarch!');

      // P3 claims Initiative too -> P3 now holds BOTH tokens!
      await controller.claimToken(tokenType: 'initiative', claimantId: 'p3');
      expect(controller.state.getPlayer('p3')!.isMonarch, isTrue);
      expect(controller.state.getPlayer('p3')!.hasInitiative, isTrue);
      expect(controller.state.getPlayer('p2')!.hasInitiative, isFalse);

      // P1 claims Monarch back -> P3 loses Monarch, but P3 MUST KEEP Initiative!
      await controller.claimToken(tokenType: 'monarch', claimantId: 'p1');
      expect(controller.state.getPlayer('p1')!.isMonarch, isTrue);
      expect(controller.state.getPlayer('p3')!.isMonarch, isFalse);
      expect(controller.state.getPlayer('p3')!.hasInitiative, isTrue,
          reason: 'P3 must retain Initiative when P1 claims Monarch!');

      controller.dispose();
    });

    test('Stress invariant: 100 rapid random token claims preserve single-holder invariant', () async {
      final controller = PodController(
        initialState: const PodState(
          sessionId: 'rapid_token_session',
          format: 'commander',
          startingLife: 40,
          players: [
            PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40),
            PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40),
            PodPlayerState(id: 'p3', seatIndex: 2, name: 'Charlie', life: 40),
            PodPlayerState(id: 'p4', seatIndex: 3, name: 'Diana', life: 40),
          ],
        ),
      );

      final players = ['p1', 'p2', 'p3', 'p4'];
      for (int i = 0; i < 100; i++) {
        final claimant = players[i % players.length];
        final token = (i % 2 == 0) ? 'monarch' : 'initiative';
        await controller.claimToken(tokenType: token, claimantId: claimant);

        final monarchHolders = controller.state.players.where((p) => p.isMonarch).length;
        final initiativeHolders = controller.state.players.where((p) => p.hasInitiative).length;

        expect(monarchHolders, lessThanOrEqualTo(1));
        expect(initiativeHolders, lessThanOrEqualTo(1));
      }

      controller.dispose();
    });
  });

  // ===========================================================================
  // SECTION 5: DAY/NIGHT POD SYNCHRONIZATION
  // ===========================================================================
  group('Adversarial 5: Day/Night Pod Synchronization & State Integrity', () {
    test('PodController: toggleDayNight flips isDay and increments sequence monotonically', () async {
      final controller = PodController(
        initialState: const PodState(
          sessionId: 'day_night_session',
          format: 'commander',
          startingLife: 40,
          players: [
            PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40),
            PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40),
          ],
          isDay: true,
          sequenceNumber: 10,
        ),
      );

      expect(controller.state.isDay, isTrue);

      // Flip to Night
      await controller.toggleDayNight();
      expect(controller.state.isDay, isFalse);
      expect(controller.state.sequenceNumber, 11);

      // Flip to Day
      await controller.toggleDayNight();
      expect(controller.state.isDay, isTrue);
      expect(controller.state.sequenceNumber, 12);

      // Flip to Night again
      await controller.toggleDayNight();
      expect(controller.state.isDay, isFalse);
      expect(controller.state.sequenceNumber, 13);

      controller.dispose();
    });

    testWidgets('Widget: DayNightToggleWidget visually reflects isDay state and invokes callback',
        (tester) async {
      bool isDay = false;
      int toggleCount = 0;

      await tester.pumpWidget(
        buildTestHarness(
          StatefulBuilder(
            builder: (context, setState) {
              return DayNightToggleWidget(
                isDay: isDay,
                onToggle: () {
                  setState(() {
                    isDay = !isDay;
                    toggleCount++;
                  });
                },
              );
            },
          ),
        ),
      );

      // Starts at Night
      expect(find.text('Night'), findsOneWidget);
      expect(find.byIcon(Icons.nightlight_round), findsOneWidget);

      // Tap to toggle
      await tester.tap(find.byKey(const Key('day_night_toggle')));
      await tester.pumpAndSettle();

      expect(toggleCount, 1);
      expect(isDay, isTrue);
      expect(find.text('Day'), findsOneWidget);
      expect(find.byIcon(Icons.wb_sunny), findsOneWidget);
    });
  });
}
