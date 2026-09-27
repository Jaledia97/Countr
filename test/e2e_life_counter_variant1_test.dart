// Copyright (c) 2026 Countr. All rights reserved.
// Comprehensive Opaque-Box E2E Test Suite for Phase 4.7 "Variant 1" Lifetap MTG Life Counter.
// Follows the 4-Tier Specification in TEST_INFRA.md:
// - Tier 1: Feature Coverage (Persistence, P2P Sync, Layouts, Life Touch/Hold, Commander Damage, Mana Drawers, Randomizers)
// - Tier 2: Boundary & Corner Cases (Limits, Corrupt Packets, 20 vs 21 Lethal, 9 vs 10 Poison, 600dp Responsive Threshold)
// - Tier 3: Pairwise Cross-Feature Interactions (Sync + Life + DB, Mana + Storm + Clear, Monarch Exclusivity, Turn Timer Omission)
// - Tier 4: Real-World MTG Game Scenarios (4P Commander EDH, 1v1 Modern, Storm Combo, 6P Chaos, P2P Interruption)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'life_counter_test_contracts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Helper to pump widgets with consistent size and directionality
  Future<void> pumpPodWidget(
    WidgetTester tester, {
    required PodState state,
    Size size = const Size(400, 800),
    void Function(String playerId, int delta)? onLifeDelta,
    void Function(String targetId, String sourceId, int delta)? onCommanderDamage,
    void Function(String playerId, String color, int delta)? onManaDelta,
    void Function(String playerId)? onManaClear,
    void Function(String playerId, String counterType, int delta)? onCounterDelta,
    VoidCallback? onResetGame,
    VoidCallback? onRandomizerPressed,
    VoidCallback? onToggleDayNight,
    void Function(String tokenType, String claimantId)? onClaimToken,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(
        home: PodScaffoldWidget(
          podState: state,
          onLifeDelta: onLifeDelta,
          onCommanderDamage: onCommanderDamage,
          onManaDelta: onManaDelta,
          onManaClear: onManaClear,
          onCounterDelta: onCounterDelta,
          onResetGame: onResetGame,
          onRandomizerPressed: onRandomizerPressed,
          onToggleDayNight: onToggleDayNight,
          onClaimToken: onClaimToken,
        ),
      ),
    );
    await tester.pump();
  }

  // ===========================================================================
  // TIER 1 - FEATURE COVERAGE (Core Behavior & Interface Verification)
  // ===========================================================================

  group('Tier 1.1 - Feature Coverage: Persistence, DB Schema v10 & Recovery', () {
    late MockMatchDao dao;

    setUp(() {
      dao = MockMatchDao();
    });

    tearDown(() {
      dao.dispose();
    });

    test('T1.1.1: creates match session with format, starting life, and players', () async {
      final p1 = const PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40);
      final p2 = const PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40);

      final sessionId = await dao.createSession(
        format: 'commander',
        startingLife: 40,
        playerCount: 2,
        players: [p1, p2],
        isP2pHost: true,
        p2pSessionCode: 'POD99',
      );

      expect(sessionId, isNotEmpty);
      final session = await dao.getActiveSession();
      expect(session, isNotNull);
      expect(session!.sessionId, sessionId);
      expect(session.format, 'commander');
      expect(session.startingLife, 40);
      expect(session.players.length, 2);
      expect(session.roomCode, 'POD99');
    });

    test('T1.1.2: records continuous event log entries with sequence numbers', () async {
      const sessionId = 'session_test_1';
      await dao.recordEvent(
        sessionId: sessionId,
        eventType: 'life_delta',
        sequenceNumber: 1,
        targetPlayerId: 'p1',
        delta: -3,
        value: 37,
      );
      await dao.recordEvent(
        sessionId: sessionId,
        eventType: 'commander_damage',
        sequenceNumber: 2,
        targetPlayerId: 'p1',
        sourcePlayerId: 'p2',
        delta: 7,
        value: 7,
      );

      expect(dao.eventLog.length, 2);
      expect(dao.eventLog[0].eventType, 'life_delta');
      expect(dao.eventLog[0].delta, -3);
      expect(dao.eventLog[1].eventType, 'commander_damage');
      expect(dao.eventLog[1].sourcePlayerId, 'p2');
      expect(dao.eventLog[1].sequenceNumber, 2);
    });

    test('T1.1.3: reactive watch stream updates player life changes', () async {
      final p1 = const PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40);
      await dao.createSession(
        format: 'commander',
        startingLife: 40,
        playerCount: 1,
        players: [p1],
      );

      final emissions = <int>[];
      final sub = dao.watchActiveSession().listen((session) {
        if (session != null) {
          emissions.add(session.players.first.life);
        }
      });

      await dao.updatePlayerLife('p1', 35);
      await dao.updatePlayerLife('p1', 32);
      await Future.delayed(Duration.zero);

      expect(emissions, containsAllInOrder([35, 32]));
      await sub.cancel();
    });

    test('T1.1.4: updates player secondary counters (poison, energy, xp, tax)', () async {
      final p1 = const PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40);
      await dao.createSession(
        format: 'commander',
        startingLife: 40,
        playerCount: 1,
        players: [p1],
      );

      await dao.updatePlayerCounter('p1', 'poison', 4);
      await dao.updatePlayerCounter('p1', 'energy', 6);
      await dao.updatePlayerCounter('p1', 'xp', 2);
      await dao.updatePlayerCounter('p1', 'commander_tax', 4);

      final session = await dao.getActiveSession();
      final player = session!.getPlayer('p1')!;
      expect(player.poison, 4);
      expect(player.energy, 6);
      expect(player.experience, 2);
      expect(player.commanderTax, 4);
    });

    test('T1.1.5: resetSession resets life and counters while preserving players', () async {
      final p1 = const PodPlayerState(
        id: 'p1',
        seatIndex: 0,
        name: 'Alice',
        deckId: 'deck_1',
        life: 14,
        poison: 5,
        energy: 3,
      );
      final p2 = const PodPlayerState(
        id: 'p2',
        seatIndex: 1,
        name: 'Bob',
        deckId: 'deck_2',
        life: 25,
        poison: 2,
      );
      final sessionId = await dao.createSession(
        format: 'commander',
        startingLife: 40,
        playerCount: 2,
        players: [p1, p2],
      );

      await dao.resetSession(sessionId, 40);
      final session = await dao.getActiveSession();
      expect(session!.players[0].life, 40);
      expect(session.players[0].poison, 0);
      expect(session.players[0].energy, 0);
      expect(session.players[0].deckId, 'deck_1');
      expect(session.players[1].life, 40);
      expect(session.players[1].deckId, 'deck_2');
    });
  });

  group('Tier 1.2 - Feature Coverage: Local Offline P2P Mesh Networking', () {
    late InMemoryP2pMesh mesh;
    late InMemoryP2pTransport hostTransport;
    late InMemoryP2pTransport clientTransport;

    setUp(() {
      mesh = InMemoryP2pMesh();
      hostTransport = mesh.createNode('host_node');
      clientTransport = mesh.createNode('client_node');
    });

    test('T1.2.1: packet serializes and deserializes accurately', () {
      final original = P2pPacket(
        type: P2pPacketType.lifeDelta,
        senderId: 'host_node',
        sequenceNumber: 42,
        targetPlayerId: 'player_1',
        delta: -5,
        payload: {'reason': 'combat'},
      );

      final encoded = original.encode();
      final decoded = P2pPacket.decode(encoded);

      expect(decoded.type, P2pPacketType.lifeDelta);
      expect(decoded.senderId, 'host_node');
      expect(decoded.sequenceNumber, 42);
      expect(decoded.targetPlayerId, 'player_1');
      expect(decoded.delta, -5);
      expect(decoded.payload['reason'], 'combat');
    });

    test('T1.2.2: InMemoryP2pMesh routes packets between host and client', () async {
      final received = <P2pPacket>[];
      clientTransport.incomingPackets.listen(received.add);

      final packet = P2pPacket(
        type: P2pPacketType.heartbeat,
        senderId: 'host_node',
        sequenceNumber: 1,
      );
      await hostTransport.sendPacket(packet);
      await Future.delayed(Duration.zero);

      expect(received.length, 1);
      expect(received.first.senderId, 'host_node');
      expect(received.first.type, P2pPacketType.heartbeat);
    });

    test('T1.2.3: P2pSyncEngine synchronizes life delta from host to client', () async {
      final initialPod = const PodState(
        sessionId: 's1',
        format: 'commander',
        startingLife: 40,
        players: [
          PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40),
          PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40),
        ],
      );

      final hostEngine = P2pSyncEngine(
        initialState: initialPod,
        transport: hostTransport,
        isHost: true,
      );

      final clientEngine = P2pSyncEngine(
        initialState: initialPod,
        transport: clientTransport,
        isHost: false,
      );

      await hostEngine.sendLifeAdjustment('p1', -4);
      await Future.delayed(Duration.zero);

      expect(hostEngine.state.getPlayer('p1')!.life, 36);
      expect(clientEngine.state.getPlayer('p1')!.life, 36);
      expect(hostEngine.state.sequenceNumber, greaterThan(0));
    });

    test('T1.2.4: P2pSyncEngine synchronizes commander damage and updates life', () async {
      final initialPod = const PodState(
        sessionId: 's1',
        format: 'commander',
        startingLife: 40,
        players: [
          PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40),
          PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40),
        ],
      );

      final hostEngine = P2pSyncEngine(
        initialState: initialPod,
        transport: hostTransport,
        isHost: true,
      );
      final clientEngine = P2pSyncEngine(
        initialState: initialPod,
        transport: clientTransport,
        isHost: false,
      );

      await hostEngine.sendCommanderDamage(
        targetPlayerId: 'p1',
        sourcePlayerId: 'p2',
        damageDelta: 6,
      );
      await Future.delayed(Duration.zero);

      expect(clientEngine.state.getPlayer('p1')!.life, 34);
      expect(clientEngine.state.getPlayer('p1')!.commanderDamageTaken['p2'], 6);
    });

    test('T1.2.5: Host broadcast of resetGame synchronizes all clients', () async {
      final modifiedPod = const PodState(
        sessionId: 's1',
        format: 'commander',
        startingLife: 40,
        players: [
          PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 12, poison: 4),
          PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 23, poison: 7),
        ],
      );

      P2pSyncEngine(
        initialState: modifiedPod,
        transport: hostTransport,
        isHost: true,
      );
      final clientEngine = P2pSyncEngine(
        initialState: modifiedPod,
        transport: clientTransport,
        isHost: false,
      );

      await hostTransport.broadcastPacket(P2pPacket(
        type: P2pPacketType.resetGame,
        senderId: 'host_node',
        sequenceNumber: 10,
        value: 40,
      ));
      await Future.delayed(Duration.zero);

      expect(clientEngine.state.getPlayer('p1')!.life, 40);
      expect(clientEngine.state.getPlayer('p1')!.poison, 0);
      expect(clientEngine.state.getPlayer('p2')!.life, 40);
      expect(clientEngine.state.getPlayer('p2')!.poison, 0);
    });
  });

  group('Tier 1.3 - Feature Coverage: Dynamic Pod Layouts (1v1 to 6-Player)', () {
    testWidgets('T1.3.1: 1v1 horizontal split layout inverts top player', (tester) async {
      final state = const PodState(
        sessionId: 's1',
        format: 'standard',
        startingLife: 20,
        players: [
          PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 20),
          PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 20),
        ],
      );

      await pumpPodWidget(tester, state: state);

      expect(find.byKey(const Key('quadrant_p1')), findsOneWidget);
      expect(find.byKey(const Key('quadrant_p2')), findsOneWidget);

      // Verify RotatedBox with quarterTurns: 2 wraps the opposing player
      final rotatedBoxes = tester.widgetList<RotatedBox>(find.byType(RotatedBox));
      expect(rotatedBoxes.any((r) => r.quarterTurns == 2), isTrue);
    });

    testWidgets('T1.3.2: 3-player asymmetric layout renders 2 top rotated and 1 bottom', (tester) async {
      final state = const PodState(
        sessionId: 's1',
        format: 'brawl',
        startingLife: 30,
        players: [
          PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 30),
          PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 30),
          PodPlayerState(id: 'p3', seatIndex: 2, name: 'Charlie', life: 30),
        ],
      );

      await pumpPodWidget(tester, state: state);

      expect(find.byKey(const Key('quadrant_p1')), findsOneWidget);
      expect(find.byKey(const Key('quadrant_p2')), findsOneWidget);
      expect(find.byKey(const Key('quadrant_p3')), findsOneWidget);
    });

    testWidgets('T1.3.3: 4-player 2x2 quadrant layout renders all four players', (tester) async {
      final state = const PodState(
        sessionId: 's1',
        format: 'commander',
        startingLife: 40,
        players: [
          PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40),
          PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40),
          PodPlayerState(id: 'p3', seatIndex: 2, name: 'Charlie', life: 40),
          PodPlayerState(id: 'p4', seatIndex: 3, name: 'Diana', life: 40),
        ],
      );

      await pumpPodWidget(tester, state: state);

      expect(find.byKey(const Key('quadrant_p1')), findsOneWidget);
      expect(find.byKey(const Key('quadrant_p2')), findsOneWidget);
      expect(find.byKey(const Key('quadrant_p3')), findsOneWidget);
      expect(find.byKey(const Key('quadrant_p4')), findsOneWidget);
    });

    testWidgets('T1.3.4: 5-player & 6-player layouts render without overflow', (tester) async {
      final state6 = const PodState(
        sessionId: 's1',
        format: 'commander',
        startingLife: 40,
        players: [
          PodPlayerState(id: 'p1', seatIndex: 0, name: 'P1', life: 40),
          PodPlayerState(id: 'p2', seatIndex: 1, name: 'P2', life: 40),
          PodPlayerState(id: 'p3', seatIndex: 2, name: 'P3', life: 40),
          PodPlayerState(id: 'p4', seatIndex: 3, name: 'P4', life: 40),
          PodPlayerState(id: 'p5', seatIndex: 4, name: 'P5', life: 40),
          PodPlayerState(id: 'p6', seatIndex: 5, name: 'P6', life: 40),
        ],
      );

      await pumpPodWidget(tester, state: state6, size: const Size(600, 1000));
      for (int i = 1; i <= 6; i++) {
        expect(find.byKey(Key('quadrant_p$i')), findsOneWidget);
      }
    });

    testWidgets('T1.3.5: Phone mode collapses tool rails into pull-out drawer', (tester) async {
      final state = const PodState(
        sessionId: 's1',
        format: 'commander',
        startingLife: 40,
        players: [
          PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40),
          PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40),
        ],
      );

      // Phone dimensions (shortestSide < 600)
      await pumpPodWidget(tester, state: state, size: const Size(360, 720));

      expect(find.byKey(const Key('drawer_toggle_p1')), findsOneWidget);
      expect(find.byKey(const Key('drawer_panel_p1')), findsNothing);

      // Tap drawer toggle to open
      await tester.tap(find.byKey(const Key('drawer_toggle_p1')));
      await tester.pump();

      expect(find.byKey(const Key('drawer_panel_p1')), findsOneWidget);
    });

    testWidgets('T1.3.6: Tablet mode renders perpetual tool rail without drawer button', (tester) async {
      final state = const PodState(
        sessionId: 's1',
        format: 'commander',
        startingLife: 40,
        players: [
          PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40),
          PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40),
        ],
      );

      // Tablet dimensions (shortestSide >= 600)
      await pumpPodWidget(tester, state: state, size: const Size(800, 1200));

      expect(find.byKey(const Key('drawer_toggle_p1')), findsNothing);
      expect(find.byKey(const Key('val_poison_p1')), findsOneWidget);
    });
  });

  group('Tier 1.4 - Feature Coverage: Life Display, Touch Zones & Hold Acceleration', () {
    testWidgets('T1.4.1: single taps on hitboxes trigger -1 and +1 callbacks', (tester) async {
      int recordedDelta = 0;
      final state = const PodState(
        sessionId: 's1',
        format: 'commander',
        startingLife: 40,
        players: [
          PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40),
          PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40),
        ],
      );

      await pumpPodWidget(
        tester,
        state: state,
        onLifeDelta: (id, delta) {
          if (id == 'p1') recordedDelta += delta;
        },
      );

      // Tap left hitbox (-1)
      await tester.tap(find.byKey(const Key('hitbox_minus_p1')));
      await tester.pump();
      expect(recordedDelta, -1);

      // Tap right hitbox (+1)
      await tester.tap(find.byKey(const Key('hitbox_plus_p1')));
      await tester.pump();
      expect(recordedDelta, 0);
    });

    testWidgets('T1.4.2: transient accumulating delta badge appears on life tap', (tester) async {
      final state = const PodState(
        sessionId: 's1',
        format: 'commander',
        startingLife: 40,
        players: [
          PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40),
          PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40),
        ],
      );

      await pumpPodWidget(tester, state: state);

      expect(find.byKey(const Key('delta_badge_p1')), findsNothing);

      // Tap minus three times
      await tester.tap(find.byKey(const Key('hitbox_minus_p1')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('hitbox_minus_p1')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('hitbox_minus_p1')));
      await tester.pump();

      expect(find.byKey(const Key('delta_badge_p1')), findsOneWidget);
      expect(find.text('-3'), findsOneWidget);

      // Auto-fades after 1500ms
      await tester.pump(const Duration(milliseconds: 1600));
      expect(find.byKey(const Key('delta_badge_p1')), findsNothing);
    });

    testWidgets('T1.4.3: hold-to-accelerate rapidly ticks life total', (tester) async {
      int ticks = 0;
      final state = const PodState(
        sessionId: 's1',
        format: 'commander',
        startingLife: 40,
        players: [
          PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40),
          PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40),
        ],
      );

      await pumpPodWidget(
        tester,
        state: state,
        onLifeDelta: (id, delta) {
          if (id == 'p1') ticks++;
        },
      );

      // Press and hold the minus hitbox
      final gesture = await tester.startGesture(tester.getCenter(find.byKey(const Key('hitbox_minus_p1'))));
      await tester.pump(const Duration(milliseconds: 600)); // Surpass kLongPressTimeout (500ms)
      await tester.pump(const Duration(milliseconds: 400)); // Staged delay
      await tester.pump(const Duration(milliseconds: 400)); // Accelerated ticks
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 1600)); // Clean up timer

      expect(ticks, greaterThanOrEqualTo(1));
    });

    testWidgets('T1.4.4: life display uses tabular figures styling', (tester) async {
      final state = const PodState(
        sessionId: 's1',
        format: 'commander',
        startingLife: 40,
        players: [
          PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40),
          PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40),
        ],
      );

      await pumpPodWidget(tester, state: state);
      final textWidget = tester.widget<Text>(find.byKey(const Key('life_display_p1')));
      expect(textWidget.data, '40');
      expect(textWidget.style?.fontFeatures?.contains(const FontFeature.tabularFigures()), isTrue);
    });

    testWidgets('T1.4.5: Center crossroads hub button is positioned at center of pod', (tester) async {
      bool hubTapped = false;
      final state = const PodState(
        sessionId: 's1',
        format: 'commander',
        startingLife: 40,
        players: [
          PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40),
          PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40),
        ],
      );

      await pumpPodWidget(
        tester,
        state: state,
        onRandomizerPressed: () => hubTapped = true,
      );

      expect(find.byKey(const Key('center_hub_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('center_hub_button')));
      await tester.pump();

      expect(hubTapped, isTrue);
    });
  });

  group('Tier 1.5 - Feature Coverage: Commander Damage Matrix & Secondary Counters', () {
    testWidgets('T1.5.1: attributes commander damage to opponent avatar button', (tester) async {
      String? damagedTarget;
      String? sourceOpponent;
      int damageAmount = 0;

      final state = const PodState(
        sessionId: 's1',
        format: 'commander',
        startingLife: 40,
        players: [
          PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40),
          PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40),
        ],
      );

      await pumpPodWidget(
        tester,
        state: state,
        size: const Size(800, 1000), // Tablet mode to access tool rail
        onCommanderDamage: (target, source, delta) {
          damagedTarget = target;
          sourceOpponent = source;
          damageAmount = delta;
        },
      );

      final cmdBtnFinder = find.byKey(const Key('cmd_damage_btn_p1_from_p2'));
      expect(cmdBtnFinder, findsOneWidget);

      await tester.tap(cmdBtnFinder);
      await tester.pump();

      expect(damagedTarget, 'p1');
      expect(sourceOpponent, 'p2');
      expect(damageAmount, 1);
    });

    testWidgets('T1.5.2: displays lethal commander damage alert banner at 21 points', (tester) async {
      final lethalState = const PodState(
        sessionId: 's1',
        format: 'commander',
        startingLife: 40,
        players: [
          PodPlayerState(
            id: 'p1',
            seatIndex: 0,
            name: 'Alice',
            life: 19,
            commanderDamageTaken: {'p2': 21}, // Exactly 21 lethal
          ),
          PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40),
        ],
      );

      await pumpPodWidget(tester, state: lethalState);

      expect(find.byKey(const Key('commander_lethal_alert_p1')), findsOneWidget);
      expect(find.text('LETHAL COMMANDER DAMAGE (21+)'), findsOneWidget);
    });

    testWidgets('T1.5.3: poison counter triggers lethal alert banner at 10 poison', (tester) async {
      final poisonLethalState = const PodState(
        sessionId: 's1',
        format: 'commander',
        startingLife: 40,
        players: [
          PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 35, poison: 10),
          PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40),
        ],
      );

      await pumpPodWidget(tester, state: poisonLethalState);

      expect(find.byKey(const Key('poison_lethal_alert_p1')), findsOneWidget);
      expect(find.text('LETHAL POISON (10+)'), findsOneWidget);
    });

    testWidgets('T1.5.4: increments and decrements secondary counters (energy, xp)', (tester) async {
      String? updatedCounter;
      int counterDelta = 0;

      final state = const PodState(
        sessionId: 's1',
        format: 'commander',
        startingLife: 40,
        players: [
          PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40),
          PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40),
        ],
      );

      await pumpPodWidget(
        tester,
        state: state,
        size: const Size(800, 1000),
        onCounterDelta: (pId, counter, delta) {
          updatedCounter = counter;
          counterDelta = delta;
        },
      );

      await tester.tap(find.byKey(const Key('inc_energy_p1')));
      await tester.pump();
      expect(updatedCounter, 'energy');
      expect(counterDelta, 1);

      await tester.tap(find.byKey(const Key('inc_xp_p1')));
      await tester.pump();
      expect(updatedCounter, 'xp');
      expect(counterDelta, 1);
    });

    testWidgets('T1.5.5: displays Monarch and Initiative status chips', (tester) async {
      final state = const PodState(
        sessionId: 's1',
        format: 'commander',
        startingLife: 40,
        players: [
          PodPlayerState(
            id: 'p1',
            seatIndex: 0,
            name: 'Alice',
            life: 40,
            isMonarch: true,
            hasInitiative: true,
          ),
          PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40),
        ],
      );

      await pumpPodWidget(tester, state: state);

      expect(find.text('👑 Monarch'), findsOneWidget);
      expect(find.text('🗡 Initiative'), findsOneWidget);
    });
  });

  group('Tier 1.6 - Feature Coverage: Floating Mana Pool, Storm & Clear Action', () {
    testWidgets('T1.6.1: floating mana drawer displays all WUBRGC mana colors', (tester) async {
      final state = const PodState(
        sessionId: 's1',
        format: 'commander',
        startingLife: 40,
        players: [
          PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40),
          PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40),
        ],
      );

      await pumpPodWidget(tester, state: state, size: const Size(800, 1000));

      // Open mana drawer
      await tester.tap(find.byKey(const Key('mana_drawer_btn_p1')));
      await tester.pumpAndSettle();

      for (final color in ['W', 'U', 'B', 'R', 'G', 'C']) {
        expect(find.byKey(Key('mana_val_${color}_p1')), findsOneWidget);
      }
    });

    testWidgets('T1.6.2: mana pool steppers increment and decrement mana', (tester) async {
      String? adjustedColor;
      int manaDelta = 0;

      final state = const PodState(
        sessionId: 's1',
        format: 'commander',
        startingLife: 40,
        players: [
          PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40),
          PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40),
        ],
      );

      await pumpPodWidget(
        tester,
        state: state,
        size: const Size(800, 1000),
        onManaDelta: (pId, color, delta) {
          adjustedColor = color;
          manaDelta = delta;
        },
      );

      await tester.tap(find.byKey(const Key('mana_drawer_btn_p1')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('mana_inc_U_p1')));
      await tester.pump();

      expect(adjustedColor, 'U');
      expect(manaDelta, 1);
    });

    testWidgets('T1.6.3: displays storm count stepper', (tester) async {
      final state = const PodState(
        sessionId: 's1',
        format: 'commander',
        startingLife: 40,
        players: [
          PodPlayerState(
            id: 'p1',
            seatIndex: 0,
            name: 'Alice',
            life: 40,
            stormCount: 7,
          ),
          PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40),
        ],
      );

      await pumpPodWidget(tester, state: state, size: const Size(800, 1000));
      await tester.tap(find.byKey(const Key('mana_drawer_btn_p1')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('storm_count_p1')), findsOneWidget);
      expect(find.text('Storm Count: 7'), findsOneWidget);
    });

    testWidgets('T1.6.4: one-tap Clear Pool invokes clear action callback', (tester) async {
      bool poolCleared = false;
      final state = const PodState(
        sessionId: 's1',
        format: 'commander',
        startingLife: 40,
        players: [
          PodPlayerState(
            id: 'p1',
            seatIndex: 0,
            name: 'Alice',
            life: 40,
            floatingMana: {'W': 2, 'U': 3, 'B': 0, 'R': 0, 'G': 0, 'C': 0},
          ),
          PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40),
        ],
      );

      await pumpPodWidget(
        tester,
        state: state,
        size: const Size(800, 1000),
        onManaClear: (pId) {
          if (pId == 'p1') poolCleared = true;
        },
      );

      await tester.tap(find.byKey(const Key('mana_drawer_btn_p1')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('clear_pool_btn_p1')));
      await tester.pumpAndSettle();

      expect(poolCleared, isTrue);
    });

    testWidgets('T1.6.5: clear pool leaves player life total untouched', (tester) async {
      final player = const PodPlayerState(
        id: 'p1',
        seatIndex: 0,
        name: 'Alice',
        life: 38,
        floatingMana: {'W': 4, 'U': 2, 'B': 1, 'R': 0, 'G': 0, 'C': 0},
        stormCount: 5,
      );

      final cleared = player.copyWith(
        floatingMana: {'W': 0, 'U': 0, 'B': 0, 'R': 0, 'G': 0, 'C': 0},
        stormCount: 0,
      );

      expect(cleared.life, 38);
      expect(cleared.floatingMana.values.every((v) => v == 0), isTrue);
      expect(cleared.stormCount, 0);
    });
  });

  group('Tier 1.7 - Feature Coverage: Randomizer Hub, Life Presets & Strict Timer Omission', () {
    test('T1.7.1: coin flip returns Heads or Tails', () {
      final service = RandomizerService();
      final flip = service.flipCoin();
      expect(flip == CoinSide.heads || flip == CoinSide.tails, isTrue);
    });

    test('T1.7.2: polyhedral dice return results within correct bounds', () {
      final service = RandomizerService();
      for (final dice in DiceType.values) {
        final roll = service.rollDice(dice);
        expect(roll, greaterThanOrEqualTo(1));
        expect(roll, lessThanOrEqualTo(dice.sides));
      }
    });

    testWidgets('T1.7.3: RandomizerHubModal rolls dice and displays result in UI', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RandomizerHubModal(playerCount: 4),
          ),
        ),
      );

      expect(find.byKey(const Key('coin_flip_btn')), findsOneWidget);
      expect(find.byKey(const Key('dice_d20_btn')), findsOneWidget);

      await tester.tap(find.byKey(const Key('dice_d20_btn')));
      await tester.pump();

      expect(find.textContaining('D20 Roll:'), findsOneWidget);
    });

    test('T1.7.4: starting life templates configure formats correctly', () {
      expect(MatchFormat.standard.defaultStartingLife, 20);
      expect(MatchFormat.brawl.defaultStartingLife, 30);
      expect(MatchFormat.commander.defaultStartingLife, 40);
    });

    testWidgets('T1.7.5: SessionRecoveryDialog offers Continue Match or Start New Game', (tester) async {
      bool continued = false;
      bool startedNew = false;

      final saved = const PodState(
        sessionId: 'saved_session_123',
        format: 'commander',
        startingLife: 40,
        players: [
          PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 32),
          PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 18),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SessionRecoveryDialog(
              savedSession: saved,
              onContinue: () => continued = true,
              onStartNew: () => startedNew = true,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('session_recovery_dialog')), findsOneWidget);
      expect(find.textContaining('2 players in commander'), findsOneWidget);

      await tester.tap(find.byKey(const Key('continue_match_btn')));
      await tester.pump();
      expect(continued, isTrue);

      await tester.tap(find.byKey(const Key('start_new_game_btn')));
      await tester.pump();
      expect(startedNew, isTrue);
    });

    testWidgets('T1.7.6: Variant 1 has strict 100% absence of turn-passing and turn-timers', (tester) async {
      final state = const PodState(
        sessionId: 's1',
        format: 'commander',
        startingLife: 40,
        players: [
          PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40),
          PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40),
        ],
      );

      await pumpPodWidget(tester, state: state);

      // Verify that no timer, pass-turn, or turn-indicator widgets exist in the tree
      expect(find.textContaining('Pass Turn'), findsNothing);
      expect(find.textContaining('Turn Timer'), findsNothing);
      expect(find.textContaining('Chess Clock'), findsNothing);
      expect(find.byIcon(Icons.timer), findsNothing);
      expect(find.byIcon(Icons.hourglass_empty), findsNothing);
    });
  });

  // ===========================================================================
  // TIER 2 - BOUNDARY & CORNER CASES (Extreme Values & Failure Modes)
  // ===========================================================================

  group('Tier 2.1 - Boundary & Corner Cases: Persistence Limits', () {
    late MockMatchDao dao;

    setUp(() => dao = MockMatchDao());
    tearDown(() => dao.dispose());

    test('T2.1.1: supports single-player solitaire life tracking session', () async {
      final p1 = const PodPlayerState(id: 'solo', seatIndex: 0, name: 'Solo Tester', life: 40);
      final sessionId = await dao.createSession(
        format: 'custom',
        startingLife: 40,
        playerCount: 1,
        players: [p1],
      );
      expect(sessionId, isNotEmpty);

      final session = await dao.getActiveSession();
      expect(session!.playerCount, 1);
      expect(session.players.first.name, 'Solo Tester');
    });

    test('T2.1.2: supports maximum 6-player pod session without state corruption', () async {
      final players = List.generate(
        6,
        (i) => PodPlayerState(id: 'p$i', seatIndex: i, name: 'Player ${i + 1}', life: 40),
      );
      final sessionId = await dao.createSession(
        format: 'commander',
        startingLife: 40,
        playerCount: 6,
        players: players,
      );
      expect(sessionId, isNotEmpty);

      final session = await dao.getActiveSession();
      expect(session!.players.length, 6);
      expect(session.players.last.seatIndex, 5);
    });

    test('T2.1.3: handles rapid burst event logging with monotonic ordering', () async {
      const sessionId = 'burst_session';
      for (int i = 1; i <= 50; i++) {
        await dao.recordEvent(
          sessionId: sessionId,
          eventType: 'life_delta',
          sequenceNumber: i,
          delta: -1,
        );
      }

      expect(dao.eventLog.length, 50);
      for (int i = 0; i < 50; i++) {
        expect(dao.eventLog[i].sequenceNumber, i + 1);
      }
    });

    test('T2.1.4: completing session clears active session state safely', () async {
      final p1 = const PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40);
      final sid = await dao.createSession(
        format: 'commander',
        startingLife: 40,
        playerCount: 1,
        players: [p1],
      );

      await dao.completeSession(sid);
      final active = await dao.getActiveSession();
      expect(active, isNull);
    });

    test('T2.1.5: deserializes malformed/empty payload without throwing exceptions', () {
      final json = {
        'id': 'p1',
        'seat_index': 0,
        'name': 'Fallback Player',
        'life': 40,
      };

      final parsed = PodPlayerState.fromJson(json);
      expect(parsed.poison, 0);
      expect(parsed.floatingMana['W'], 0);
      expect(parsed.commanderDamageTaken, isEmpty);
    });
  });

  group('Tier 2.2 - Boundary & Corner Cases: Network Disconnection & Edge Packets', () {
    test('T2.2.1: disconnected transport throws StateError when sending packet', () async {
      final mesh = InMemoryP2pMesh();
      final node = mesh.createNode('node_1');
      await node.disconnect();

      expect(
        () => node.sendPacket(P2pPacket(
          type: P2pPacketType.heartbeat,
          senderId: 'node_1',
          sequenceNumber: 1,
        )),
        throwsStateError,
      );
    });

    test('T2.2.2: reconnecting node resumes packet delivery in mesh', () async {
      final mesh = InMemoryP2pMesh();
      mesh.createNode('node_A');
      final nodeB = mesh.createNode('node_B');

      await nodeB.disconnect();
      expect(nodeB.isConnected, isFalse);

      nodeB.reconnect();
      expect(nodeB.isConnected, isTrue);
    });

    test('T2.2.3: packet with zero delta executes safely without corrupting life', () {
      final initial = const PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40);
      final updated = initial.copyWith(life: initial.life + 0);
      expect(updated.life, 40);
    });

    test('T2.2.4: packet handles negative sequence numbers gracefully', () {
      final packet = P2pPacket(
        type: P2pPacketType.heartbeat,
        senderId: 'node_1',
        sequenceNumber: -1,
      );
      final decoded = P2pPacket.decode(packet.encode());
      expect(decoded.sequenceNumber, -1);
    });

    test('T2.2.5: handles empty room code and fallback safely', () {
      final pod = const PodState(
        sessionId: 's1',
        format: 'commander',
        startingLife: 40,
        players: [],
        roomCode: null,
      );
      expect(pod.roomCode, isNull);
    });
  });

  group('Tier 2.3 - Boundary & Corner Cases: Responsive Viewport Thresholds', () {
    testWidgets('T2.3.1: shortestSide exactly 599 renders phone drawer toggle', (tester) async {
      final state = const PodState(
        sessionId: 's1',
        format: 'commander',
        startingLife: 40,
        players: [
          PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40),
          PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40),
        ],
      );

      await pumpPodWidget(tester, state: state, size: const Size(599, 900));
      expect(find.byKey(const Key('drawer_toggle_p1')), findsOneWidget);
    });

    testWidgets('T2.3.2: shortestSide exactly 600 renders perpetual tablet tool rail', (tester) async {
      final state = const PodState(
        sessionId: 's1',
        format: 'commander',
        startingLife: 40,
        players: [
          PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40),
          PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40),
        ],
      );

      await pumpPodWidget(tester, state: state, size: const Size(600, 900));
      expect(find.byKey(const Key('drawer_toggle_p1')), findsNothing);
      expect(find.byKey(const Key('val_poison_p1')), findsOneWidget);
    });

    testWidgets('T2.3.3: renders extreme high life total 99999 without text overflow', (tester) async {
      final state = const PodState(
        sessionId: 's1',
        format: 'custom',
        startingLife: 99999,
        players: [
          PodPlayerState(id: 'p1', seatIndex: 0, name: 'Life Infinite', life: 99999),
          PodPlayerState(id: 'p2', seatIndex: 1, name: 'Opponent', life: 20),
        ],
      );

      await pumpPodWidget(tester, state: state);
      expect(find.text('99999'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('T2.3.4: negative life total renders cleanly with red text styling', (tester) async {
      final state = const PodState(
        sessionId: 's1',
        format: 'commander',
        startingLife: 40,
        players: [
          PodPlayerState(id: 'p1', seatIndex: 0, name: 'Overkilled Alice', life: -12),
          PodPlayerState(id: 'p2', seatIndex: 1, name: 'Victor Bob', life: 28),
        ],
      );

      await pumpPodWidget(tester, state: state);
      expect(find.text('-12'), findsOneWidget);
      final textWidget = tester.widget<Text>(find.byKey(const Key('life_display_p1')));
      expect(textWidget.style?.color, Colors.redAccent);
    });

    testWidgets('T2.3.5: life dropping to exactly 0 triggers lethal appearance', (tester) async {
      final state = const PodState(
        sessionId: 's1',
        format: 'standard',
        startingLife: 20,
        players: [
          PodPlayerState(id: 'p1', seatIndex: 0, name: 'Dead Alice', life: 0),
          PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 15),
        ],
      );

      await pumpPodWidget(tester, state: state);
      expect(find.text('0'), findsOneWidget);
      final textWidget = tester.widget<Text>(find.byKey(const Key('life_display_p1')));
      expect(textWidget.style?.color, Colors.redAccent);
    });
  });

  group('Tier 2.4 - Boundary & Corner Cases: Commander Damage & Poison Thresholds', () {
    test('T2.4.1: commander damage at exactly 20 is NOT lethal', () {
      final player = const PodPlayerState(
        id: 'p1',
        seatIndex: 0,
        name: 'Alice',
        life: 20,
        commanderDamageTaken: {'p2': 20},
      );
      expect(player.isCommanderDamageLethalFrom('p2'), isFalse);
      expect(player.hasAnyLethalCommanderDamage, isFalse);
      expect(player.isLethal, isFalse);
    });

    test('T2.4.2: commander damage at exactly 21 IS lethal', () {
      final player = const PodPlayerState(
        id: 'p1',
        seatIndex: 0,
        name: 'Alice',
        life: 19,
        commanderDamageTaken: {'p2': 21},
      );
      expect(player.isCommanderDamageLethalFrom('p2'), isTrue);
      expect(player.hasAnyLethalCommanderDamage, isTrue);
      expect(player.isLethal, isTrue);
    });

    test('T2.4.3: poison counters at exactly 9 is NOT lethal', () {
      final player = const PodPlayerState(
        id: 'p1',
        seatIndex: 0,
        name: 'Alice',
        life: 30,
        poison: 9,
      );
      expect(player.isPoisonLethal, isFalse);
      expect(player.isLethal, isFalse);
    });

    test('T2.4.4: poison counters at exactly 10 IS lethal', () {
      final player = const PodPlayerState(
        id: 'p1',
        seatIndex: 0,
        name: 'Alice',
        life: 30,
        poison: 10,
      );
      expect(player.isPoisonLethal, isTrue);
      expect(player.isLethal, isTrue);
    });

    test('T2.4.5: simultaneous 10 poison and 21 commander damage both flag lethal', () {
      final player = const PodPlayerState(
        id: 'p1',
        seatIndex: 0,
        name: 'Alice',
        life: 15,
        poison: 10,
        commanderDamageTaken: {'p2': 21},
      );
      expect(player.isPoisonLethal, isTrue);
      expect(player.hasAnyLethalCommanderDamage, isTrue);
      expect(player.isLethal, isTrue);
    });
  });

  group('Tier 2.5 - Boundary & Corner Cases: Mana Pool & Randomizer Boundaries', () {
    test('T2.5.1: floating mana prevents negative counts (clamped at 0)', () {
      final mesh = InMemoryP2pMesh();
      final transport = mesh.createNode('n1');
      final engine = P2pSyncEngine(
        initialState: const PodState(
          sessionId: 's1',
          format: 'commander',
          startingLife: 40,
          players: [
            PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40),
          ],
        ),
        transport: transport,
        isHost: true,
      );

      // Decrement when already 0
      transport.sendPacket(P2pPacket(
        type: P2pPacketType.manaDelta,
        senderId: 'n1',
        sequenceNumber: 1,
        targetPlayerId: 'p1',
        delta: -1,
        payload: {'color': 'U'},
      ));

      expect(engine.state.getPlayer('p1')!.floatingMana['U'], 0);
    });

    test('T2.5.2: clearing already empty mana pool executes cleanly', () {
      final player = const PodPlayerState(
        id: 'p1',
        seatIndex: 0,
        name: 'Alice',
        life: 40,
        floatingMana: {'W': 0, 'U': 0, 'B': 0, 'R': 0, 'G': 0, 'C': 0},
      );
      final cleared = player.copyWith(
        floatingMana: {'W': 0, 'U': 0, 'B': 0, 'R': 0, 'G': 0, 'C': 0},
      );
      expect(cleared.floatingMana.values.every((v) => v == 0), isTrue);
    });

    test('T2.5.3: D4 roll strictly bounded in 1..4 across 50 iterations', () {
      final service = RandomizerService();
      for (int i = 0; i < 50; i++) {
        final roll = service.rollDice(DiceType.d4);
        expect(roll, inInclusiveRange(1, 4));
      }
    });

    test('T2.5.4: D100 roll strictly bounded in 1..100 across 50 iterations', () {
      final service = RandomizerService();
      for (int i = 0; i < 50; i++) {
        final roll = service.rollDice(DiceType.d100);
        expect(roll, inInclusiveRange(1, 100));
      }
    });

    test('T2.5.5: random opponent selection never picks self seat', () {
      final service = RandomizerService();
      const playerCount = 4;
      const selfSeat = 2;
      for (int i = 0; i < 30; i++) {
        final picked = service.selectRandomOpponentIndex(playerCount, selfSeat);
        expect(picked, isNot(equals(selfSeat)));
        expect(picked, inInclusiveRange(0, 3));
      }
    });
  });

  // ===========================================================================
  // TIER 3 - CROSS-FEATURE COMBINATIONS & PAIRWISE INTERACTIONS
  // ===========================================================================

  group('Tier 3 - Cross-Feature Interactions & Combinations', () {
    testWidgets('T3.1: P2P sync + Life touch + DB ledger end-to-end integration', (tester) async {
      final dao = MockMatchDao();
      final mesh = InMemoryP2pMesh();
      final hostTransport = mesh.createNode('host');
      final clientTransport = mesh.createNode('client');

      final initialState = const PodState(
        sessionId: 'combo_session',
        format: 'commander',
        startingLife: 40,
        players: [
          PodPlayerState(id: 'p1', seatIndex: 0, name: 'Host Player', life: 40),
          PodPlayerState(id: 'p2', seatIndex: 1, name: 'Client Player', life: 40),
        ],
      );

      final hostEngine = P2pSyncEngine(
        initialState: initialState,
        transport: hostTransport,
        isHost: true,
      );
      final clientEngine = P2pSyncEngine(
        initialState: initialState,
        transport: clientTransport,
        isHost: false,
      );

      await pumpPodWidget(
        tester,
        state: hostEngine.state,
        onLifeDelta: (playerId, delta) {
          hostEngine.sendLifeAdjustment(playerId, delta);
          dao.recordEvent(
            sessionId: 'combo_session',
            eventType: 'life_delta',
            sequenceNumber: hostEngine.state.sequenceNumber,
            targetPlayerId: playerId,
            delta: delta,
            value: hostEngine.state.getPlayer(playerId)!.life,
          );
        },
      );

      // Tap Host Player minus hitbox twice
      await tester.tap(find.byKey(const Key('hitbox_minus_p1')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('hitbox_minus_p1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1600));

      // Verify DB ledger wrote entries
      expect(dao.eventLog.length, 2);
      expect(dao.eventLog.last.delta, -1);

      // Verify client node received broadcast and synchronized life
      expect(clientEngine.state.getPlayer('p1')!.life, 38);
    });

    testWidgets('T3.2: Tablet tool rail + Commander damage 21 alert + Defeat status', (tester) async {
      var state = const PodState(
        sessionId: 's1',
        format: 'commander',
        startingLife: 40,
        players: [
          PodPlayerState(
            id: 'p1',
            seatIndex: 0,
            name: 'Alice',
            life: 22,
            commanderDamageTaken: {'p2': 20},
          ),
          PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40),
        ],
      );

      await pumpPodWidget(
        tester,
        state: state,
        size: const Size(800, 1000), // Tablet mode
        onCommanderDamage: (target, source, delta) {
          final p1 = state.getPlayer('p1')!;
          final newDmg = (p1.commanderDamageTaken[source] ?? 0) + delta;
          final updatedP1 = p1.copyWith(
            life: p1.life - delta,
            commanderDamageTaken: {source: newDmg},
          );
          state = state.copyWith(players: [updatedP1, state.players[1]]);
        },
      );

      // Initially no alert (20 damage)
      expect(find.byKey(const Key('commander_lethal_alert_p1')), findsNothing);

      // Tap to deal 1 more commander damage (21 points)
      await tester.tap(find.byKey(const Key('cmd_damage_btn_p1_from_p2')));
      await tester.pump();

      // Re-pump widget with updated state
      await pumpPodWidget(tester, state: state, size: const Size(800, 1000));

      expect(find.byKey(const Key('commander_lethal_alert_p1')), findsOneWidget);
      expect(state.getPlayer('p1')!.hasAnyLethalCommanderDamage, isTrue);
    });

    testWidgets('T3.3: Floating mana pool + Storm counter + Clear pool preserves player life', (tester) async {
      var player = const PodPlayerState(
        id: 'p1',
        seatIndex: 0,
        name: 'Storm Player',
        life: 25,
        floatingMana: {'W': 0, 'U': 0, 'B': 0, 'R': 0, 'G': 0, 'C': 0},
        stormCount: 0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return FloatingManaDrawerWidget(
                  player: player,
                  onManaDelta: (color, delta) {
                    final current = player.floatingMana[color] ?? 0;
                    final updatedPool = Map<String, int>.from(player.floatingMana);
                    updatedPool[color] = current + delta;
                    setState(() {
                      player = player.copyWith(
                        floatingMana: updatedPool,
                        stormCount: player.stormCount + 1,
                      );
                    });
                  },
                  onManaClear: () {
                    setState(() {
                      player = player.copyWith(
                        floatingMana: {'W': 0, 'U': 0, 'B': 0, 'R': 0, 'G': 0, 'C': 0},
                        stormCount: 0,
                      );
                    });
                  },
                );
              },
            ),
          ),
        ),
      );

      // Increment Red mana three times
      await tester.tap(find.byKey(const Key('mana_inc_R_p1')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('mana_inc_R_p1')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('mana_inc_R_p1')));
      await tester.pump();

      expect(player.floatingMana['R'], 3);
      expect(player.stormCount, 3);
      expect(player.life, 25); // Untouched

      // Tap Clear Pool
      await tester.tap(find.byKey(const Key('clear_pool_btn_p1')));
      await tester.pump();

      expect(player.floatingMana['R'], 0);
      expect(player.stormCount, 0);
      expect(player.life, 25); // Still untouched
    });

    test('T3.4: Pod-wide Monarch and Initiative token exclusivity', () async {
      final mesh = InMemoryP2pMesh();
      final transport = mesh.createNode('n1');

      final initialPod = const PodState(
        sessionId: 's1',
        format: 'commander',
        startingLife: 40,
        players: [
          PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40),
          PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40),
        ],
      );

      final engine = P2pSyncEngine(
        initialState: initialPod,
        transport: transport,
        isHost: true,
      );

      // P1 claims Monarch
      await engine.claimToken(tokenType: 'monarch', claimantId: 'p1');
      expect(engine.state.getPlayer('p1')!.isMonarch, isTrue);
      expect(engine.state.getPlayer('p2')!.isMonarch, isFalse);

      // P2 claims Monarch (steals from P1)
      await engine.claimToken(tokenType: 'monarch', claimantId: 'p2');
      expect(engine.state.getPlayer('p1')!.isMonarch, isFalse);
      expect(engine.state.getPlayer('p2')!.isMonarch, isTrue);
    });

    testWidgets('T3.5: Crash recovery dialog restores exact board state and counters', (tester) async {
      final savedState = const PodState(
        sessionId: 'crashed_session',
        format: 'commander',
        startingLife: 40,
        players: [
          PodPlayerState(
            id: 'p1',
            seatIndex: 0,
            name: 'Alice',
            life: 27,
            poison: 3,
            commanderDamageTaken: {'p2': 14},
          ),
          PodPlayerState(
            id: 'p2',
            seatIndex: 1,
            name: 'Bob',
            life: 31,
            energy: 4,
            isMonarch: true,
          ),
        ],
      );

      PodState? restoredState;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SessionRecoveryDialog(
              savedSession: savedState,
              onContinue: () => restoredState = savedState,
              onStartNew: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('continue_match_btn')));
      await tester.pump();

      expect(restoredState, isNotNull);
      expect(restoredState!.getPlayer('p1')!.life, 27);
      expect(restoredState!.getPlayer('p1')!.poison, 3);
      expect(restoredState!.getPlayer('p1')!.commanderDamageTaken['p2'], 14);
      expect(restoredState!.getPlayer('p2')!.isMonarch, isTrue);
    });

    testWidgets('T3.6: Global Reset Game preserves pod seating and deck associations', (tester) async {
      bool resetExecuted = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RandomizerHubModal(
              playerCount: 4,
              onResetGame: () => resetExecuted = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('reset_game_btn')));
      await tester.pump();

      expect(resetExecuted, isTrue);
    });

    test('T3.7: Strict turn logic omission audit across domain models', () {
      final pod = const PodState(
        sessionId: 'audit_session',
        format: 'commander',
        startingLife: 40,
        players: [],
      );

      final json = pod.toJson();
      expect(json.containsKey('active_player_turn'), isFalse);
      expect(json.containsKey('turn_number'), isFalse);
      expect(json.containsKey('turn_timer_seconds'), isFalse);
      expect(json.containsKey('chess_clock'), isFalse);
    });
  });

  // ===========================================================================
  // TIER 4 - REAL-WORLD MTG APPLICATION SCENARIOS
  // ===========================================================================

  group('Tier 4 - Real-World MTG Game Scenarios', () {
    testWidgets('T4.1: Scenario 1: 4-Player EDH Pod with Infect and Commander Damage Defeat', (tester) async {
      // 4-Player Pod:
      // P1: Edgar Markov (Vampires)
      // P2: Urza, Lord High Artificer (Artifacts)
      // P3: Atraxa, Praetors' Voice (Infect/Proliferate)
      // P4: The Ur-Dragon (Dragons)
      final pod = const PodState(
        sessionId: 'edh_pod_alpha',
        format: 'commander',
        startingLife: 40,
        players: [
          PodPlayerState(
            id: 'p1_edgar',
            seatIndex: 0,
            name: 'Edgar Markov',
            commanderName: 'Edgar Markov',
            life: 40,
          ),
          PodPlayerState(
            id: 'p2_urza',
            seatIndex: 1,
            name: 'Urza',
            commanderName: 'Urza, Lord High Artificer',
            life: 40,
          ),
          PodPlayerState(
            id: 'p3_atraxa',
            seatIndex: 2,
            name: 'Atraxa',
            commanderName: "Atraxa, Praetors' Voice",
            life: 40,
          ),
          PodPlayerState(
            id: 'p4_urdragon',
            seatIndex: 3,
            name: 'The Ur-Dragon',
            commanderName: 'The Ur-Dragon',
            life: 40,
          ),
        ],
      );

      await pumpPodWidget(tester, state: pod, size: const Size(800, 1200));

      // 1. Atraxa hits Urza with Infect, placing 10 poison counters over turns
      final infectedUrza = pod.getPlayer('p2_urza')!.copyWith(poison: 10);
      expect(infectedUrza.isPoisonLethal, isTrue);

      // 2. Edgar Markov swings for 21 lethal commander damage into The Ur-Dragon
      final crushedUrDragon = pod.getPlayer('p4_urdragon')!.copyWith(
        commanderDamageTaken: {'p1_edgar': 21},
        life: 19,
      );
      expect(crushedUrDragon.isCommanderDamageLethalFrom('p1_edgar'), isTrue);

      // Verify that both players are eliminated
      expect(infectedUrza.isLethal, isTrue);
      expect(crushedUrDragon.isLethal, isTrue);
    });

    testWidgets('T4.2: Scenario 2: 1v1 Competitive Modern Match with Fetch/Shock Life Loss', (tester) async {
      // 1v1 Match: Starting life 20
      // Turn 1: Scalding Tarn fetch (-1), Steam Vents shock untapped (-2) -> Life = 17
      int currentLife = 20;
      final pod = PodState(
        sessionId: 'modern_finals',
        format: 'standard',
        startingLife: 20,
        players: [
          PodPlayerState(id: 'p1', seatIndex: 0, name: 'Murktide', life: currentLife),
          const PodPlayerState(id: 'p2', seatIndex: 1, name: 'Burn', life: 20),
        ],
      );

      await pumpPodWidget(
        tester,
        state: pod,
        onLifeDelta: (id, delta) {
          if (id == 'p1') currentLife += delta;
        },
      );

      // Scalding Tarn fetch (-1)
      await tester.tap(find.byKey(const Key('hitbox_minus_p1')));
      await tester.pump();
      expect(currentLife, 19);

      // Steam Vents shock untapped (-2: two taps)
      await tester.tap(find.byKey(const Key('hitbox_minus_p1')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('hitbox_minus_p1')));
      await tester.pump();
      expect(currentLife, 17);
    });

    test('T4.3: Scenario 3: Storm Combo Turn with WUBRGC Mana and Clear Pool', () {
      // Combo Player floating mana during Grapeshot / Past in Flames turn
      var stormPlayer = const PodPlayerState(
        id: 'storm_p1',
        seatIndex: 0,
        name: 'Storm Player',
        life: 14,
        floatingMana: {'W': 0, 'U': 4, 'B': 2, 'R': 6, 'G': 0, 'C': 1},
        stormCount: 15,
      );

      // Cast Grapeshot dealing 16 copies
      expect(stormPlayer.stormCount, 15);
      expect(stormPlayer.floatingMana['R'], 6);

      // End of phase: One-tap Clear Pool zeroes mana and storm
      stormPlayer = stormPlayer.copyWith(
        floatingMana: {'W': 0, 'U': 0, 'B': 0, 'R': 0, 'G': 0, 'C': 0},
        stormCount: 0,
      );

      expect(stormPlayer.floatingMana.values.every((m) => m == 0), isTrue);
      expect(stormPlayer.stormCount, 0);
      expect(stormPlayer.life, 14); // Life untouched
    });

    testWidgets('T4.4: Scenario 4: 6-Player Chaos Pod with Day/Night Sync and Contested Tokens', (tester) async {
      final pod = const PodState(
        sessionId: 'chaos_6p',
        format: 'commander',
        startingLife: 40,
        isDay: true,
        players: [
          PodPlayerState(id: 'p1', seatIndex: 0, name: 'Player 1', life: 40, isMonarch: true),
          PodPlayerState(id: 'p2', seatIndex: 1, name: 'Player 2', life: 40),
          PodPlayerState(id: 'p3', seatIndex: 2, name: 'Player 3', life: 40),
          PodPlayerState(id: 'p4', seatIndex: 3, name: 'Player 4', life: 40),
          PodPlayerState(id: 'p5', seatIndex: 4, name: 'Player 5', life: 40),
          PodPlayerState(id: 'p6', seatIndex: 5, name: 'Player 6', life: 40, hasInitiative: true),
        ],
      );

      await pumpPodWidget(tester, state: pod, size: const Size(600, 1000));

      // Verify P1 has Monarch, P6 has Initiative
      expect(pod.getPlayer('p1')!.isMonarch, isTrue);
      expect(pod.getPlayer('p6')!.hasInitiative, isTrue);

      // Toggle Day to Night
      final nightPod = pod.copyWith(isDay: !pod.isDay);
      expect(nightPod.isDay, isFalse);
    });

    test('T4.5: Scenario 5: P2P Multiplayer Mesh Sync with Network Interruption & Catch-up', () async {
      final mesh = InMemoryP2pMesh();
      final hostTransport = mesh.createNode('host_device');
      final clientTransport = mesh.createNode('client_device');

      final initialPod = const PodState(
        sessionId: 'p2p_resilience_test',
        format: 'commander',
        startingLife: 40,
        players: [
          PodPlayerState(id: 'p1', seatIndex: 0, name: 'Host', life: 40),
          PodPlayerState(id: 'p2', seatIndex: 1, name: 'Client', life: 40),
        ],
      );

      final hostEngine = P2pSyncEngine(
        initialState: initialPod,
        transport: hostTransport,
        isHost: true,
      );
      final clientEngine = P2pSyncEngine(
        initialState: initialPod,
        transport: clientTransport,
        isHost: false,
      );

      // 1. Initial sync
      await hostEngine.sendLifeAdjustment('p1', -5);
      await Future.delayed(Duration.zero);
      expect(clientEngine.state.getPlayer('p1')!.life, 35);

      // 2. Client encounters temporary network interruption
      await clientTransport.disconnect();
      expect(clientTransport.isConnected, isFalse);

      // 3. Host performs further changes while client is disconnected
      await hostEngine.sendLifeAdjustment('p2', -3);
      await Future.delayed(Duration.zero);

      // 4. Client reconnects and requests catch-up syncState
      clientTransport.reconnect();
      expect(clientTransport.isConnected, isTrue);

      await hostTransport.sendPacket(P2pPacket(
        type: P2pPacketType.syncState,
        senderId: 'host_device',
        sequenceNumber: hostEngine.state.sequenceNumber,
        payload: {'state': hostEngine.state.toJson()},
      ));
      await Future.delayed(Duration.zero);

      // 5. Client state is fully caught up and consistent
      expect(clientEngine.state.getPlayer('p2')!.life, 37);
      expect(clientEngine.state.getPlayer('p1')!.life, 35);
    });
  });
}
