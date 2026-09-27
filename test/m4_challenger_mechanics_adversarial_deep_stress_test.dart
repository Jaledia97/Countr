// Copyright (c) 2026 Countr. All rights reserved.
// Deep Adversarial Stress Suite for Milestone 4 Iteration 2 Gate:
// Exhaustive empirical verification of:
// 1. 6-player pod Commander Damage matrix (100 total damage distributed vs 21 single threshold)
// 2. Poison 10-point lethal boundary and recovery behavior
// 3. Multi-commander and multi-vector simultaneous lethal trigger layouts
// 4. 6-player P2P Mesh Monarch and Initiative token stealing exclusivity
// 5. 6-player P2P Mesh Day/Night synchronization and sequence ordering

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/features/life_counter/data/network/in_memory_p2p_mesh.dart';
import 'package:countr/features/life_counter/data/network/p2p_sync_engine.dart';
import 'package:countr/features/life_counter/domain/models/pod_state.dart';
import 'package:countr/features/life_counter/presentation/controllers/pod_controller.dart';
import 'package:countr/features/life_counter/presentation/widgets/commander_damage_matrix.dart';
import 'package:countr/features/life_counter/presentation/widgets/player_quadrant_widget.dart';

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
  // GROUP 1: 6-PLAYER POD COMMANDER DAMAGE STRESS & MTG RULE 903.10a
  // ===========================================================================
  group('Challenger Deep Stress 1: 6-Player Commander Damage Invariants', () {
    final opponents = List.generate(
      5,
      (i) => PodPlayerState(
        id: 'p${i + 2}',
        seatIndex: i + 1,
        name: 'Player ${i + 2}',
        life: 40,
        commanderArtCropUrl: 'https://cards.scryfall.io/art_crop/p${i + 2}.jpg',
      ),
    );

    test('6-player pod: 20 damage each from 5 opponents (100 total cmd dmg) is NOT lethal', () {
      final targetPlayer = PodPlayerState(
        id: 'p1',
        seatIndex: 0,
        name: 'Target Alice',
        life: 150, // plenty of life
        commanderDamageTaken: {
          'p2': 20,
          'p3': 20,
          'p4': 20,
          'p5': 20,
          'p6': 20,
        },
      );

      // Verify each opponent separately
      for (final opp in opponents) {
        expect(targetPlayer.isCommanderDamageLethalFrom(opp.id), isFalse);
      }
      expect(targetPlayer.hasAnyLethalCommanderDamage, isFalse);
      expect(targetPlayer.isLethal, isFalse);
      expect(targetPlayer.isEliminated, isFalse);
    });

    testWidgets('6-player pod widget: 5 opponents at 20 damage show NO red alert buttons and NO banner',
        (tester) async {
      final targetPlayer = PodPlayerState(
        id: 'p1',
        seatIndex: 0,
        name: 'Target Alice',
        life: 150,
        commanderDamageTaken: {
          'p2': 20,
          'p3': 20,
          'p4': 20,
          'p5': 20,
          'p6': 20,
        },
      );

      await tester.pumpWidget(
        buildTestHarness(
          CommanderDamageMatrixWidget(
            player: targetPlayer,
            opponents: opponents,
            isTablet: true,
          ),
          size: const Size(1000, 600),
        ),
      );

      // Verify none of the 5 buttons are red
      for (final opp in opponents) {
        final btnFinder = find.byKey(Key('cmd_damage_btn_p1_from_${opp.id}'));
        expect(btnFinder, findsOneWidget);
        final containerFinder = find.descendant(of: btnFinder, matching: find.byType(AnimatedContainer));
        final animContainer = tester.widget<AnimatedContainer>(containerFinder.first);
        final dec = animContainer.decoration as BoxDecoration;
        expect(dec.color, isNot(equals(Colors.red.shade700)));
      }
    });

    testWidgets('6-player pod widget: exactly one opponent reaches 21, ONLY that button turns red',
        (tester) async {
      final targetPlayer = PodPlayerState(
        id: 'p1',
        seatIndex: 0,
        name: 'Target Alice',
        life: 150,
        commanderDamageTaken: {
          'p2': 20,
          'p3': 20,
          'p4': 21, // Exactly p4 is lethal!
          'p5': 19,
          'p6': 20,
        },
      );

      await tester.pumpWidget(
        buildTestHarness(
          CommanderDamageMatrixWidget(
            player: targetPlayer,
            opponents: opponents,
            isTablet: true,
          ),
          size: const Size(1000, 600),
        ),
      );

      // P4 button MUST be red
      final p4Btn = find.byKey(const Key('cmd_damage_btn_p1_from_p4'));
      final p4ContainerFinder = find.descendant(of: p4Btn, matching: find.byType(AnimatedContainer));
      final p4Anim = tester.widget<AnimatedContainer>(p4ContainerFinder.first);
      final p4Dec = p4Anim.decoration as BoxDecoration;
      expect(p4Dec.color, equals(Colors.red.shade700));

      // All other buttons must NOT be red
      for (final opp in opponents.where((o) => o.id != 'p4')) {
        final btn = find.byKey(Key('cmd_damage_btn_p1_from_${opp.id}'));
        final contFinder = find.descendant(of: btn, matching: find.byType(AnimatedContainer));
        final anim = tester.widget<AnimatedContainer>(contFinder.first);
        final dec = anim.decoration as BoxDecoration;
        expect(dec.color, isNot(equals(Colors.red.shade700)));
      }
    });

    test('PodController: 21 commander damage sets isEliminated; reducing to 20 clears isEliminated', () async {
      final controller = PodController(
        initialState: const PodState(
          sessionId: 'cmd_recovery_session',
          format: 'commander',
          startingLife: 40,
          players: [
            PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40),
            PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40),
          ],
        ),
      );

      // Inflict 21 commander damage from Bob
      await controller.recordCommanderDamage(
        targetPlayerId: 'p1',
        sourcePlayerId: 'p2',
        damageDelta: 21,
      );

      expect(controller.state.getPlayer('p1')!.life, 19);
      expect(controller.state.getPlayer('p1')!.commanderDamageTaken['p2'], 21);
      expect(controller.state.getPlayer('p1')!.isEliminated, isTrue);

      // Decrement commander damage by 1 (e.g. user error correction)
      await controller.recordCommanderDamage(
        targetPlayerId: 'p1',
        sourcePlayerId: 'p2',
        damageDelta: -1,
      );

      expect(controller.state.getPlayer('p1')!.life, 20);
      expect(controller.state.getPlayer('p1')!.commanderDamageTaken['p2'], 20);
      expect(controller.state.getPlayer('p1')!.hasAnyLethalCommanderDamage, isFalse);
      expect(controller.state.getPlayer('p1')!.isEliminated, isFalse);

      controller.dispose();
    });
  });

  // ===========================================================================
  // GROUP 2: POISON LETHAL BOUNDARY & RECOVERY
  // ===========================================================================
  group('Challenger Deep Stress 2: Poison Boundary & Recovery', () {
    test('PodController: Poison increments to 10 eliminates player; decrementing to 9 revives player', () async {
      final controller = PodController(
        initialState: const PodState(
          sessionId: 'poison_recovery_session',
          format: 'commander',
          startingLife: 40,
          players: [
            PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 30, poison: 8),
          ],
        ),
      );

      // +1 poison -> 9 (not eliminated)
      await controller.adjustCounter(playerId: 'p1', counterType: 'poison', delta: 1);
      expect(controller.state.getPlayer('p1')!.poison, 9);
      expect(controller.state.getPlayer('p1')!.isPoisonLethal, isFalse);
      expect(controller.state.getPlayer('p1')!.isEliminated, isFalse);

      // +1 poison -> 10 (eliminated)
      await controller.adjustCounter(playerId: 'p1', counterType: 'poison', delta: 1);
      expect(controller.state.getPlayer('p1')!.poison, 10);
      expect(controller.state.getPlayer('p1')!.isPoisonLethal, isTrue);
      expect(controller.state.getPlayer('p1')!.isEliminated, isTrue);

      // +5 poison -> 15 (still eliminated)
      await controller.adjustCounter(playerId: 'p1', counterType: 'poison', delta: 5);
      expect(controller.state.getPlayer('p1')!.poison, 15);
      expect(controller.state.getPlayer('p1')!.isEliminated, isTrue);

      // -6 poison -> back to 9 (revives)
      await controller.adjustCounter(playerId: 'p1', counterType: 'poison', delta: -6);
      expect(controller.state.getPlayer('p1')!.poison, 9);
      expect(controller.state.getPlayer('p1')!.isPoisonLethal, isFalse);
      expect(controller.state.getPlayer('p1')!.isEliminated, isFalse);

      controller.dispose();
    });
  });

  // ===========================================================================
  // GROUP 3: MULTI-COMMANDER & MULTI-VECTOR SIMULTANEOUS LETHAL TRIGGERS
  // ===========================================================================
  group('Challenger Deep Stress 3: Simultaneous Multi-Lethal Stress', () {
    const opp2 = PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40);
    const opp3 = PodPlayerState(id: 'p3', seatIndex: 2, name: 'Charlie', life: 40);

    testWidgets('Quadruple lethal on narrow mobile screen (320x500) renders cleanly with no overflow',
        (tester) async {
      // Alice is lethal via:
      // 1. Life <= 0 (-10)
      // 2. Poison >= 10 (14)
      // 3. Commander Bob >= 21 (22)
      // 4. Commander Charlie >= 21 (25)
      const quadLethalPlayer = PodPlayerState(
        id: 'p1',
        seatIndex: 0,
        name: 'Alice Quad Lethal',
        life: -10,
        poison: 14,
        commanderDamageTaken: {'p2': 22, 'p3': 25},
        isEliminated: true,
      );

      await tester.pumpWidget(
        buildTestHarness(
          const PlayerQuadrantWidget(
            player: quadLethalPlayer,
            isTablet: false, // mobile layout
            opponents: [opp2, opp3],
          ),
          size: const Size(320, 500),
        ),
      );

      // Verify banners and alerts
      expect(find.byKey(const Key('commander_lethal_alert_p1')), findsOneWidget);
      expect(find.byKey(const Key('poison_lethal_alert_p1')), findsOneWidget);
      expect(find.text('ELIMINATED'), findsOneWidget);
      expect(find.text('-10'), findsOneWidget);

      // Verify ZERO exceptions / overflows
      expect(tester.takeException(), isNull);
    });
  });

  // ===========================================================================
  // GROUP 4: 6-PLAYER POD MONARCH & INITIATIVE STEALING IN P2P MESH
  // ===========================================================================
  group('Challenger Deep Stress 4: 6-Player P2P Mesh Token Stealing', () {
    late InMemoryP2pMesh mesh;
    late List<InMemoryP2pTransport> transports;
    late List<P2pSyncEngine> engines;

    setUp(() {
      mesh = InMemoryP2pMesh();
      final playerStates = List.generate(
        6,
        (i) => PodPlayerState(
          id: 'p${i + 1}',
          seatIndex: i,
          name: 'Player ${i + 1}',
          life: 40,
        ),
      );

      final initialPod = PodState(
        sessionId: 'mesh_6p_token_session',
        format: 'commander',
        startingLife: 40,
        players: playerStates,
      );

      transports = List.generate(6, (i) => mesh.createNode('node_${i + 1}'));
      engines = List.generate(
        6,
        (i) => P2pSyncEngine(
          initialState: initialPod,
          transport: transports[i],
          isHost: i == 0, // node_1 is host
        ),
      );
    });

    tearDown(() {
      for (final engine in engines) {
        engine.dispose();
      }
    });

    test('6-Player sequential Monarch stealing maintains pod-wide exclusivity on ALL nodes', () async {
      void verifyPodMonarchAcrossAllNodes(String expectedHolderId) {
        for (int i = 0; i < engines.length; i++) {
          final state = engines[i].state;
          final monarchs = state.players.where((p) => p.isMonarch).toList();
          expect(
            monarchs.length,
            1,
            reason: 'Node $i must see exactly 1 monarch',
          );
          expect(
            monarchs.first.id,
            expectedHolderId,
            reason: 'Node $i must see $expectedHolderId as Monarch',
          );
        }
      }

      // Players 1 through 6 sequentially claim Monarch from each other
      for (int i = 0; i < 6; i++) {
        final claimantId = 'p${i + 1}';
        await engines[i].claimToken(tokenType: 'monarch', claimantId: claimantId);
        await Future.delayed(Duration.zero);
        verifyPodMonarchAcrossAllNodes(claimantId);
      }
    });

    test('6-Player concurrent interleaving of Monarch and Initiative maintains independence', () async {
      // P2 claims Monarch
      await engines[1].claimToken(tokenType: 'monarch', claimantId: 'p2');
      await Future.delayed(Duration.zero);

      // P5 claims Initiative
      await engines[4].claimToken(tokenType: 'initiative', claimantId: 'p5');
      await Future.delayed(Duration.zero);

      // Verify on all nodes
      for (int i = 0; i < engines.length; i++) {
        final state = engines[i].state;
        expect(state.getPlayer('p2')!.isMonarch, isTrue);
        expect(state.getPlayer('p5')!.hasInitiative, isTrue);
        expect(state.players.where((p) => p.isMonarch).length, 1);
        expect(state.players.where((p) => p.hasInitiative).length, 1);
      }

      // P5 claims Monarch too -> P5 now has BOTH tokens!
      await engines[4].claimToken(tokenType: 'monarch', claimantId: 'p5');
      await Future.delayed(Duration.zero);

      for (int i = 0; i < engines.length; i++) {
        final state = engines[i].state;
        expect(state.getPlayer('p5')!.isMonarch, isTrue);
        expect(state.getPlayer('p5')!.hasInitiative, isTrue);
        expect(state.getPlayer('p2')!.isMonarch, isFalse);
        expect(state.players.where((p) => p.isMonarch).length, 1);
        expect(state.players.where((p) => p.hasInitiative).length, 1);
      }

      // P1 steals Initiative from P5 -> P5 retains Monarch, P1 gets Initiative!
      await engines[0].claimToken(tokenType: 'initiative', claimantId: 'p1');
      await Future.delayed(Duration.zero);

      for (int i = 0; i < engines.length; i++) {
        final state = engines[i].state;
        expect(state.getPlayer('p5')!.isMonarch, isTrue, reason: 'P5 must retain Monarch');
        expect(state.getPlayer('p5')!.hasInitiative, isFalse);
        expect(state.getPlayer('p1')!.hasInitiative, isTrue, reason: 'P1 must have Initiative');
        expect(state.getPlayer('p1')!.isMonarch, isFalse);
      }
    });

    test('Stress invariant: 120 rapid claims across 6 players in P2P mesh preserve invariants', () async {
      final playerIds = ['p1', 'p2', 'p3', 'p4', 'p5', 'p6'];

      for (int step = 0; step < 120; step++) {
        final engineIdx = step % 6;
        final claimant = playerIds[(step * 2) % 6];
        final token = (step % 2 == 0) ? 'monarch' : 'initiative';

        await engines[engineIdx].claimToken(tokenType: token, claimantId: claimant);
      }
      await Future.delayed(Duration.zero);

      // Verify invariants across all 6 nodes
      for (int i = 0; i < engines.length; i++) {
        final state = engines[i].state;
        final monarchCount = state.players.where((p) => p.isMonarch).length;
        final initiativeCount = state.players.where((p) => p.hasInitiative).length;

        expect(monarchCount, lessThanOrEqualTo(1));
        expect(initiativeCount, lessThanOrEqualTo(1));
      }
    });
  });

  // ===========================================================================
  // GROUP 5: 6-PLAYER POD DAY/NIGHT SYNCHRONIZATION IN P2P MESH
  // ===========================================================================
  group('Challenger Deep Stress 5: 6-Player P2P Mesh Day/Night Synchronization', () {
    late InMemoryP2pMesh mesh;
    late List<InMemoryP2pTransport> transports;
    late List<P2pSyncEngine> engines;

    setUp(() {
      mesh = InMemoryP2pMesh();
      final playerStates = List.generate(
        6,
        (i) => PodPlayerState(
          id: 'p${i + 1}',
          seatIndex: i,
          name: 'Player ${i + 1}',
          life: 40,
        ),
      );

      final initialPod = PodState(
        sessionId: 'mesh_6p_daynight_session',
        format: 'commander',
        startingLife: 40,
        players: playerStates,
        isDay: true,
      );

      transports = List.generate(6, (i) => mesh.createNode('node_${i + 1}'));
      engines = List.generate(
        6,
        (i) => P2pSyncEngine(
          initialState: initialPod,
          transport: transports[i],
          isHost: i == 0,
        ),
      );
    });

    tearDown(() {
      for (final engine in engines) {
        engine.dispose();
      }
    });

    test('DEFECT VERIFICATION: Client toggling Day/Night desynchronizes Host and Client', () async {
      final minimalMesh = InMemoryP2pMesh();
      final hostNode = minimalMesh.createNode('host');
      final clientNode = minimalMesh.createNode('client');

      final initialPod = const PodState(
        sessionId: 'test_session',
        format: 'commander',
        startingLife: 40,
        players: [
          PodPlayerState(id: 'p1', seatIndex: 0, name: 'Host', life: 40),
          PodPlayerState(id: 'p2', seatIndex: 1, name: 'Client', life: 40),
        ],
        isDay: true,
      );

      final hostEngine = P2pSyncEngine(
        initialState: initialPod,
        transport: hostNode,
        isHost: true,
      );
      final clientEngine = P2pSyncEngine(
        initialState: initialPod,
        transport: clientNode,
        isHost: false,
      );

      expect(hostEngine.state.isDay, isTrue);
      expect(clientEngine.state.isDay, isTrue);

      // Client toggles Day/Night
      await clientEngine.toggleDayNight();
      await Future.delayed(Duration.zero);

      // Host authoritatively toggled to Night (false)
      expect(hostEngine.state.isDay, isFalse, reason: 'Host must be Night');
      // Client must also be Night (false)
      expect(clientEngine.state.isDay, isFalse, reason: 'Client must be Night');
    });

    test('Host toggling Day/Night synchronizes all 6 nodes simultaneously', () async {
      expect(engines[0].state.isDay, isTrue);

      // Host flips to Night
      await engines[0].toggleDayNight();
      await Future.delayed(Duration.zero);

      for (int i = 0; i < 6; i++) {
        expect(engines[i].state.isDay, isFalse, reason: 'Node $i must be Night');
      }

      // Host flips back to Day
      await engines[0].toggleDayNight();
      await Future.delayed(Duration.zero);

      for (int i = 0; i < 6; i++) {
        expect(engines[i].state.isDay, isTrue, reason: 'Node $i must be Day');
      }
    });
  });
}
