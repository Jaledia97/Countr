// Copyright (c) 2026 Countr. All rights reserved.
// Adversarial Stress Test Suite for FloatingManaDrawerWidget & PodController (Milestone 4 Challenger 2).

import 'dart:async';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/life_counter/domain/models/pod_state.dart';
import 'package:countr/features/life_counter/domain/models/p2p_packet.dart';
import 'package:countr/features/life_counter/data/network/p2p_transport.dart';
import 'package:countr/features/life_counter/data/network/p2p_sync_engine.dart';
import 'package:countr/features/life_counter/data/repositories/match_session_repository.dart';
import 'package:countr/features/life_counter/presentation/controllers/pod_controller.dart';
import 'package:countr/features/life_counter/presentation/widgets/floating_mana_drawer_widget.dart';
import 'package:countr/features/symbology/presentation/widgets/mana_symbol_icon.dart';

// =============================================================================
// TEST MOCK INFRASTRUCTURE (IN-MEMORY P2P MESH)
// =============================================================================

class StressTestP2pMesh {
  final Map<String, StressTestP2pTransport> _nodes = {};
  String hostEndpointId = 'host_node';

  StressTestP2pTransport createNode(String endpointId) {
    final transport = StressTestP2pTransport(endpointId, this);
    _nodes[endpointId] = transport;
    return transport;
  }

  void routePacket(P2pPacket packet, String senderEndpoint, {String? targetEndpoint}) {
    if (targetEndpoint != null) {
      final target = _nodes[targetEndpoint];
      if (target != null && target.isConnected) {
        target.receivePacket(packet);
      }
    } else if (senderEndpoint != hostEndpointId) {
      final host = _nodes[hostEndpointId];
      if (host != null && host.isConnected) {
        host.receivePacket(packet);
      }
    } else {
      for (final entry in _nodes.entries) {
        if (entry.key != senderEndpoint && entry.value.isConnected) {
          entry.value.receivePacket(packet);
        }
      }
    }
  }

  void removeNode(String endpointId) {
    _nodes.remove(endpointId);
  }
}

class StressTestP2pTransport implements P2pTransport {
  @override
  final String endpointId;
  final StressTestP2pMesh _mesh;
  final StreamController<P2pPacket> _incomingController = StreamController<P2pPacket>.broadcast();
  final StreamController<PeerStatus> _statusController = StreamController<PeerStatus>.broadcast();
  bool _connected = true;

  StressTestP2pTransport(this.endpointId, this._mesh);

  @override
  bool get isConnected => _connected;

  @override
  Stream<P2pPacket> get incomingPackets => _incomingController.stream;

  @override
  Stream<PeerStatus> get peerStatusStream => _statusController.stream;

  @override
  Future<void> sendPacket(P2pPacket packet) async {
    if (!_connected) throw StateError('Disconnected');
    _mesh.routePacket(packet, endpointId);
  }

  @override
  Future<void> broadcastPacket(P2pPacket packet) async {
    await sendPacket(packet);
  }

  @override
  Future<void> sendTo(String targetPeerId, P2pPacket packet) async {
    if (!_connected) throw StateError('Disconnected');
    _mesh.routePacket(packet, endpointId, targetEndpoint: targetPeerId);
  }

  @override
  Future<void> broadcast(P2pPacket packet) async {
    await broadcastPacket(packet);
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    _mesh.removeNode(endpointId);
    await _incomingController.close();
    await _statusController.close();
  }

  @override
  Future<void> close() => disconnect();

  void receivePacket(P2pPacket packet) {
    if (_connected && !_incomingController.isClosed) {
      _incomingController.add(packet);
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const basePlayer = PodPlayerState(
    id: 'p1',
    seatIndex: 0,
    name: 'Teferi Player',
    life: 40,
    floatingMana: {'W': 3, 'U': 5, 'B': 0, 'R': 2, 'G': 1, 'C': 4},
    stormCount: 7,
  );

  // ===========================================================================
  // GROUP 1: FLOATING MANA DRAWER ADVERSARIAL STRESS TESTS
  // ===========================================================================
  group('Adversarial Group 1: FloatingManaDrawerWidget UI & Boundaries', () {
    testWidgets('WUBRGC mana steppers: zero clamping and decrement callbacks', (tester) async {
      final decrementedColors = <String>[];
      final decrementedDeltas = <int>[];

      const zeroPlayer = PodPlayerState(
        id: 'p1',
        seatIndex: 0,
        name: 'Zero Mana Player',
        life: 40,
        floatingMana: {'W': 0, 'U': 0, 'B': 0, 'R': 0, 'G': 0, 'C': 0},
        stormCount: 0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FloatingManaDrawerWidget(
              player: zeroPlayer,
              onManaDelta: (color, delta) {
                decrementedColors.add(color);
                decrementedDeltas.add(delta);
              },
            ),
          ),
        ),
      );

      // Decrement all 6 colors starting at 0
      for (final color in FloatingManaDrawerWidget.manaColors) {
        final decKey = Key('mana_dec_${color}_p1');
        expect(find.byKey(decKey), findsOneWidget);
        await tester.tap(find.byKey(decKey));
        await tester.pump();
      }

      expect(decrementedColors, ['W', 'U', 'B', 'R', 'G', 'C']);
      expect(decrementedDeltas, [-1, -1, -1, -1, -1, -1]);
    });

    testWidgets('WUBRGC mana steppers: high value boundary handling with horizontal scrolling', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const extremePlayer = PodPlayerState(
        id: 'p1',
        seatIndex: 0,
        name: 'Omniscience Player With Very Long Name',
        life: 99999,
        floatingMana: {
          'W': 999999,
          'U': 1000000,
          'B': 888888,
          'R': 777777,
          'G': 666666,
          'C': 555555,
        },
        stormCount: 99999,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FloatingManaDrawerWidget(player: extremePlayer),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('mana_drawer_sheet_p1')), findsOneWidget);
      expect(find.byType(ManaSymbolIcon), findsNWidgets(6));
      expect(find.text('999999'), findsOneWidget);
      expect(find.text('1000000'), findsOneWidget);
      expect(find.text('Storm Count: 99999'), findsOneWidget);

      // Verify horizontal scrolling of mana pips
      final scrollFinder = find.byType(SingleChildScrollView).first;
      await tester.drag(scrollFinder, const Offset(-150, 0));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('VULNERABILITY: Storm counter row on 280px width at 1.8x text scale must not trigger RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(280, 500);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const stormPlayer = PodPlayerState(
        id: 'p1',
        seatIndex: 0,
        name: 'Storm Player',
        life: 40,
        floatingMana: {'W': 0, 'U': 0, 'B': 0, 'R': 0, 'G': 0, 'C': 0},
        stormCount: 99999,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(280, 500), textScaler: TextScaler.linear(1.8)),
            child: Scaffold(
              body: FloatingManaDrawerWidget(
                player: stormPlayer,
                onStormDelta: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final exception = tester.takeException();
      expect(
        exception,
        isNull,
        reason: 'FloatingManaDrawerWidget._buildStormCounter overflowed on 280px width at 1.8x text scale: Row missing FittedBox or constraint wrapping',
      );
    });

    testWidgets('Storm counter: increments, decrements, and static rendering when callbacks omitted', (tester) async {
      int stormDeltas = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FloatingManaDrawerWidget(
              player: basePlayer,
              onStormDelta: (delta) => stormDeltas += delta,
            ),
          ),
        ),
      );

      // Test increments
      await tester.tap(find.byKey(const Key('storm_inc_p1')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('storm_inc_p1')));
      await tester.pump();
      expect(stormDeltas, 2);

      // Test decrements
      await tester.tap(find.byKey(const Key('storm_dec_p1')));
      await tester.pump();
      expect(stormDeltas, 1);

      // Test static rendering without steppers when onStormDelta is null
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FloatingManaDrawerWidget(player: basePlayer),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('storm_count_p1')), findsOneWidget);
      expect(find.byKey(const Key('storm_inc_p1')), findsNothing);
      expect(find.byKey(const Key('storm_dec_p1')), findsNothing);
      expect(find.byIcon(Icons.flash_on), findsOneWidget);
    });

    testWidgets('One-Tap Clear Pool: zeroes all mana and storm, triggers SnackBar undo action, and restores values on undo tap', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Stateful test wrapper verifying state restoration round-trip
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                // Interactive state simulating controller
                return _InteractiveManaTestHarness();
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initial state: W=3, U=5, B=0, R=2, G=1, C=4, Storm=7
      expect(find.text('3'), findsOneWidget); // W
      expect(find.text('5'), findsOneWidget); // U
      expect(find.text('Storm Count: 7'), findsOneWidget);

      // Tap "Clear Pool" button
      await tester.tap(find.byKey(const Key('clear_pool_btn_p1')));
      await tester.pumpAndSettle();

      // Verify all mana pools and storm count are ZERO in the UI
      expect(find.text('Storm Count: 0'), findsOneWidget);
      expect(find.text('0'), findsWidgets); // All 6 colors are 0

      // Verify SnackBar appeared with undo button
      expect(find.text('Cleared mana pool for Teferi Player'), findsOneWidget);
      final undoActionFinder = find.text('UNDO');
      expect(undoActionFinder, findsOneWidget);

      // Tap UNDO in the SnackBar
      await tester.tap(undoActionFinder);
      await tester.pumpAndSettle();

      // Verify state was completely RESTORED
      expect(find.text('Storm Count: 7'), findsOneWidget);
      expect(find.text('3'), findsOneWidget); // W restored
      expect(find.text('5'), findsOneWidget); // U restored
      expect(find.text('2'), findsOneWidget); // R restored
      expect(find.text('1'), findsOneWidget); // G restored
      expect(find.text('4'), findsOneWidget); // C restored
    });

    testWidgets('One-Tap Clear Pool: header inline Undo button also triggers restoration', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _InteractiveManaTestHarness(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Clear pool
      await tester.tap(find.byKey(const Key('clear_pool_btn_p1')));
      await tester.pumpAndSettle();
      expect(find.text('Storm Count: 0'), findsOneWidget);

      // Tap inline Undo button in the header
      final inlineUndoBtn = find.byKey(const Key('undo_pool_btn_p1'));
      expect(inlineUndoBtn, findsOneWidget);
      await tester.tap(inlineUndoBtn);
      await tester.pumpAndSettle();

      // Verify restoration
      expect(find.text('Storm Count: 7'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('Clear Pool on already empty pool executes cleanly without throw', (tester) async {
      const emptyPlayer = PodPlayerState(
        id: 'p1',
        seatIndex: 0,
        name: 'Empty Player',
        life: 40,
        floatingMana: {'W': 0, 'U': 0, 'B': 0, 'R': 0, 'G': 0, 'C': 0},
        stormCount: 0,
      );

      bool cleared = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FloatingManaDrawerWidget(
              player: emptyPlayer,
              autoCloseOnClear: false,
              onManaClear: () => cleared = true,
              onUndo: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('clear_pool_btn_p1')));
      await tester.pumpAndSettle();

      expect(cleared, isTrue);
      expect(tester.takeException(), isNull);
    });
  });

  // ===========================================================================
  // GROUP 2: POD CONTROLLER CONCURRENCY & STATE MUTATIONS
  // ===========================================================================
  group('Adversarial Group 2: PodController Concurrency & Edge Invariants', () {
    late PodState initialPod;
    late PodController controller;

    setUp(() {
      initialPod = const PodState(
        sessionId: 'test_pod_session',
        format: 'commander',
        startingLife: 40,
        players: [
          PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40),
          PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40),
          PodPlayerState(id: 'p3', seatIndex: 2, name: 'Charlie', life: 40),
          PodPlayerState(id: 'p4', seatIndex: 3, name: 'David', life: 40),
        ],
      );
      controller = PodController(initialState: initialPod);
    });

    tearDown(() {
      controller.dispose();
    });

    test('Rapid concurrent 100 life mutations maintain strict sequence ordering and mathematical sum', () async {
      // 50 +1 adjustments and 50 -2 adjustments (net: -50)
      final futures = <Future<void>>[];
      for (int i = 0; i < 50; i++) {
        futures.add(controller.adjustLife('p1', 1));
        futures.add(controller.adjustLife('p1', -2));
      }

      await Future.wait(futures);

      final p1 = controller.state.getPlayer('p1')!;
      // Starting life 40 + 50 - 100 = -10
      expect(p1.life, -10);
      expect(p1.isEliminated, isTrue);
      expect(controller.state.sequenceNumber, 100);
    });

    test('Rapid concurrent multi-player and multi-counter storm of 100 actions executes safely', () async {
      final futures = <Future<void>>[];

      for (int i = 0; i < 20; i++) {
        futures.add(controller.adjustLife('p1', -1));
        futures.add(controller.adjustMana(playerId: 'p2', color: 'U', delta: 1));
        futures.add(controller.adjustCounter(playerId: 'p3', counterType: 'poison', delta: 1));
        futures.add(controller.recordCommanderDamage(targetPlayerId: 'p4', sourcePlayerId: 'p1', damageDelta: 1));
        futures.add(controller.adjustCounter(playerId: 'p2', counterType: 'energy', delta: 2));
      }

      await Future.wait(futures);

      expect(controller.state.sequenceNumber, 100);

      final p1 = controller.state.getPlayer('p1')!;
      expect(p1.life, 20); // 40 - 20

      final p2 = controller.state.getPlayer('p2')!;
      expect(p2.floatingMana['U'], 20);
      expect(p2.stormCount, 20);
      expect(p2.energy, 40);

      final p3 = controller.state.getPlayer('p3')!;
      expect(p3.poison, 20);
      expect(p3.isEliminated, isTrue); // Poison >= 10

      final p4 = controller.state.getPlayer('p4')!;
      expect(p4.life, 20); // 40 - 20 commander damage
      expect(p4.commanderDamageTaken['p1'], 20);
      expect(p4.isEliminated, isFalse); // 20 is not lethal yet!
    });

    test('Zero deltas are strict no-ops and preserve sequence number', () async {
      final initialSeq = controller.state.sequenceNumber;

      await controller.adjustLife('p1', 0);
      await controller.adjustMana(playerId: 'p1', color: 'W', delta: 0);
      await controller.adjustStorm('p1', 0);
      await controller.recordCommanderDamage(targetPlayerId: 'p1', sourcePlayerId: 'p2', damageDelta: 0);
      await controller.adjustCounter(playerId: 'p1', counterType: 'poison', delta: 0);

      expect(controller.state.sequenceNumber, initialSeq);
    });

    test('WUBRGC mana and storm invariants: negative clamping and clear pool', () async {
      // Clamp negative mana to 0
      await controller.adjustMana(playerId: 'p1', color: 'W', delta: -5);
      expect(controller.state.getPlayer('p1')!.floatingMana['W'], 0);

      // Positive mana increments storm
      await controller.adjustMana(playerId: 'p1', color: 'W', delta: 3);
      expect(controller.state.getPlayer('p1')!.floatingMana['W'], 3);
      expect(controller.state.getPlayer('p1')!.stormCount, 1);

      // Negative mana does NOT increment storm
      await controller.adjustMana(playerId: 'p1', color: 'W', delta: -1);
      expect(controller.state.getPlayer('p1')!.floatingMana['W'], 2);
      expect(controller.state.getPlayer('p1')!.stormCount, 1);

      // Direct storm adjustment clamping
      await controller.adjustStorm('p1', -10);
      expect(controller.state.getPlayer('p1')!.stormCount, 0);

      await controller.adjustStorm('p1', 4);
      expect(controller.state.getPlayer('p1')!.stormCount, 4);

      // Clear pool
      await controller.clearManaPool('p1');
      final p1 = controller.state.getPlayer('p1')!;
      expect(p1.floatingMana['W'], 0);
      expect(p1.stormCount, 0);
      expect(p1.life, 40); // untouched
    });

    test('Commander lethal damage threshold 21 activates isEliminated; revival clears isEliminated', () async {
      await controller.recordCommanderDamage(targetPlayerId: 'p1', sourcePlayerId: 'p2', damageDelta: 20);
      expect(controller.state.getPlayer('p1')!.isEliminated, isFalse);

      await controller.recordCommanderDamage(targetPlayerId: 'p1', sourcePlayerId: 'p2', damageDelta: 1);
      expect(controller.state.getPlayer('p1')!.commanderDamageTaken['p2'], 21);
      expect(controller.state.getPlayer('p1')!.isEliminated, isTrue);

      // Manual concession / revival toggle
      controller.toggleEliminated('p1');
      expect(controller.state.getPlayer('p1')!.isEliminated, isFalse);
    });
  });

  // ===========================================================================
  // GROUP 3: MATCH SESSION REPOSITORY & UNDO LEDGER STRESS TESTS
  // ===========================================================================
  group('Adversarial Group 3: MatchSessionRepository & SQLite Undo Ledger', () {
    late AppDatabase db;
    late MatchSessionRepository repository;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      repository = MatchSessionRepository(db: db);
    });

    tearDown(() async {
      repository.dispose();
      await db.close();
    });

    test('SQLite event ledger records mana clear and correctly restores state on undo()', () async {
      final initialPod = await repository.createSession(
        format: 'commander',
        startingLife: 40,
        players: const [
          PlayerSetupConfig(id: 'p1', name: 'Alice', seatOrder: 0, startingLife: 40),
          PlayerSetupConfig(id: 'p2', name: 'Bob', seatOrder: 1, startingLife: 40),
        ],
      );

      final controller = PodController(
        initialState: initialPod,
        repository: repository,
      );

      // Step 1: Adjust mana for Alice (W: +4, storm = 1)
      await controller.adjustMana(playerId: 'p1', color: 'W', delta: 4);
      expect(controller.state.getPlayer('p1')!.floatingMana['W'], 4);
      expect(controller.state.getPlayer('p1')!.stormCount, 1);

      // Step 2: Adjust mana for Alice (U: +2, storm = 2)
      await controller.adjustMana(playerId: 'p1', color: 'U', delta: 2);
      expect(controller.state.getPlayer('p1')!.floatingMana['U'], 2);
      expect(controller.state.getPlayer('p1')!.stormCount, 2);

      // Step 3: One-Tap Clear Pool
      await controller.clearManaPool('p1');
      expect(controller.state.getPlayer('p1')!.floatingMana['W'], 0);
      expect(controller.state.getPlayer('p1')!.floatingMana['U'], 0);
      expect(controller.state.getPlayer('p1')!.stormCount, 0);

      // Step 4: Undo Clear Pool -> Must restore W: 4, U: 2, and storm: 2!
      final undoClearSuccess = await controller.undo();
      expect(undoClearSuccess, isTrue);

      final restoredP1 = controller.state.getPlayer('p1')!;
      expect(restoredP1.floatingMana['W'], 4);
      expect(restoredP1.floatingMana['U'], 2);
      expect(restoredP1.stormCount, 2);

      // Verify SQLite state matches controller
      final dbRestored = await repository.restoreActiveSession();
      expect(dbRestored, isNotNull);
      expect(dbRestored!.getPlayer('p1')!.floatingMana['W'], 4);
      expect(dbRestored.getPlayer('p1')!.floatingMana['U'], 2);
      expect(dbRestored.getPlayer('p1')!.stormCount, 2);

      controller.dispose();
    });

    test('Undo ledger rolls back across multi-event history to initial state', () async {
      final initialPod = await repository.createSession(
        format: 'commander',
        startingLife: 40,
        players: const [
          PlayerSetupConfig(id: 'p1', name: 'Alice', seatOrder: 0, startingLife: 40),
          PlayerSetupConfig(id: 'p2', name: 'Bob', seatOrder: 1, startingLife: 40),
        ],
      );

      final controller = PodController(initialState: initialPod, repository: repository);

      // 1. Life adjustment
      await controller.adjustLife('p1', -5);
      expect(controller.state.getPlayer('p1')!.life, 35);

      // 2. Commander damage
      await controller.recordCommanderDamage(targetPlayerId: 'p1', sourcePlayerId: 'p2', damageDelta: 3);
      expect(controller.state.getPlayer('p1')!.life, 32);
      expect(controller.state.getPlayer('p1')!.commanderDamageTaken['p2'], 3);

      // Undo commander damage
      final u1 = await controller.undo();
      expect(u1, isTrue);
      expect(controller.state.getPlayer('p1')!.life, 35);
      expect(controller.state.getPlayer('p1')!.commanderDamageTaken['p2'] ?? 0, 0);

      // Undo life adjustment
      final u2 = await controller.undo();
      expect(u2, isTrue);
      expect(controller.state.getPlayer('p1')!.life, 40);

      // Undo when no more events exist: must return false (no events undone)
      final u3 = await controller.undo();
      expect(
        u3,
        isFalse,
        reason: 'MatchSessionRepository.undoLastEvent ignored null from MatchDao.undoLastEvent and unconditionally returned restoreActiveSession(), causing PodController.undo() to falsely return true when ledger was empty',
      );
      expect(controller.state.getPlayer('p1')!.life, 40);

      controller.dispose();
    });

    test('Concurrent 40 SQLite mutations serialize safely through repository write queue', () async {
      final initialPod = await repository.createSession(
        format: 'commander',
        startingLife: 40,
        players: const [
          PlayerSetupConfig(id: 'p1', name: 'Alice', seatOrder: 0, startingLife: 40),
          PlayerSetupConfig(id: 'p2', name: 'Bob', seatOrder: 1, startingLife: 40),
        ],
      );

      final controller = PodController(initialState: initialPod, repository: repository);

      final futures = <Future<void>>[];
      for (int i = 0; i < 40; i++) {
        futures.add(controller.adjustLife('p1', 1));
      }
      await Future.wait(futures);
      await repository.flush();

      expect(controller.state.getPlayer('p1')!.life, 80);

      final dbState = await repository.restoreActiveSession();
      expect(dbState!.getPlayer('p1')!.life, 80);

      controller.dispose();
    });
  });

  // ===========================================================================
  // GROUP 4: P2P SYNC ENGINE & MESH SYNCHRONIZATION
  // ===========================================================================
  group('Adversarial Group 4: P2pSyncEngine Synchronization with PodController', () {
    late StressTestP2pMesh mesh;
    late StressTestP2pTransport hostTransport;
    late StressTestP2pTransport clientTransport;
    late P2pSyncEngine hostEngine;
    late P2pSyncEngine clientEngine;
    late PodController hostController;
    late PodController clientController;

    setUp(() {
      mesh = StressTestP2pMesh();
      hostTransport = mesh.createNode('host_node');
      clientTransport = mesh.createNode('client_node');

      const initialPod = PodState(
        sessionId: 'p2p_test_session',
        format: 'commander',
        startingLife: 40,
        isP2pHost: true,
        sequenceNumber: 1,
        players: [
          PodPlayerState(id: 'p1', seatIndex: 0, name: 'Host Player', life: 40),
          PodPlayerState(id: 'p2', seatIndex: 1, name: 'Client Player', life: 40),
        ],
      );

      hostEngine = P2pSyncEngine(
        initialState: initialPod,
        transport: hostTransport,
        isHost: true,
        localPlayerId: 'p1',
      );

      clientEngine = P2pSyncEngine(
        initialState: initialPod.copyWith(isP2pHost: false),
        transport: clientTransport,
        isHost: false,
        localPlayerId: 'p2',
      );

      hostController = PodController(initialState: initialPod, syncEngine: hostEngine);
      clientController = PodController(initialState: initialPod.copyWith(isP2pHost: false), syncEngine: clientEngine);
    });

    tearDown(() async {
      hostController.dispose();
      clientController.dispose();
      await hostTransport.disconnect();
      await clientTransport.disconnect();
    });

    test('Host mana adjustment propagates to Client and synchronizes both controllers', () async {
      // Host adds 3 Blue mana for player p1
      await hostController.adjustMana(playerId: 'p1', color: 'U', delta: 3);
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(hostController.state.getPlayer('p1')!.floatingMana['U'], 3);
      expect(clientController.state.getPlayer('p1')!.floatingMana['U'], 3);
      expect(hostController.state.getPlayer('p1')!.stormCount, 1);
      expect(clientController.state.getPlayer('p1')!.stormCount, 1);
    });

    test('VULNERABILITY: Client mana adjustment causes double application on client node', () async {
      // Client adds 3 Blue mana for player p2
      await clientController.adjustMana(playerId: 'p2', color: 'U', delta: 3);

      // Wait a microtask tick for packet routing
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(hostController.state.getPlayer('p2')!.floatingMana['U'], 3);
      expect(
        clientController.state.getPlayer('p2')!.floatingMana['U'],
        equals(3),
        reason: 'P2pSyncEngine double-applied mana delta on client: sendManaDelta omitted PendingAction, and _handleManaDeltaPacket reapplied incoming delta without reconciliation (expected 3, got ${clientController.state.getPlayer('p2')!.floatingMana['U']})',
      );
      expect(hostController.state.getPlayer('p2')!.stormCount, 1);
      expect(clientController.state.getPlayer('p2')!.stormCount, 1);
    });

    test('Client Clear Pool propagates to Host and zeroes mana/storm on both controllers', () async {
      // First, host gives p2 some mana
      await hostController.adjustMana(playerId: 'p2', color: 'R', delta: 5);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(clientController.state.getPlayer('p2')!.floatingMana['R'], 5);

      // Client taps Clear Pool
      await clientController.clearManaPool('p2');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(hostController.state.getPlayer('p2')!.floatingMana['R'], 0);
      expect(clientController.state.getPlayer('p2')!.floatingMana['R'], 0);
      expect(hostController.state.getPlayer('p2')!.stormCount, 0);
      expect(clientController.state.getPlayer('p2')!.stormCount, 0);
    });

    test('Pod-wide Monarch token exclusivity is maintained across P2P controllers', () async {
      // Host claims Monarch
      await hostController.claimToken(tokenType: 'monarch', claimantId: 'p1');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(hostController.state.getPlayer('p1')!.isMonarch, isTrue);
      expect(clientController.state.getPlayer('p1')!.isMonarch, isTrue);

      // Client steals Monarch
      await clientController.claimToken(tokenType: 'monarch', claimantId: 'p2');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(hostController.state.getPlayer('p1')!.isMonarch, isFalse);
      expect(hostController.state.getPlayer('p2')!.isMonarch, isTrue);
      expect(clientController.state.getPlayer('p1')!.isMonarch, isFalse);
      expect(clientController.state.getPlayer('p2')!.isMonarch, isTrue);
    });
  });
}

// =============================================================================
// INTERACTIVE TEST HARNESS WIDGET
// =============================================================================

class _InteractiveManaTestHarness extends StatefulWidget {
  @override
  State<_InteractiveManaTestHarness> createState() => _InteractiveManaTestHarnessState();
}

class _InteractiveManaTestHarnessState extends State<_InteractiveManaTestHarness> {
  PodPlayerState player = const PodPlayerState(
    id: 'p1',
    seatIndex: 0,
    name: 'Teferi Player',
    life: 40,
    floatingMana: {'W': 3, 'U': 5, 'B': 0, 'R': 2, 'G': 1, 'C': 4},
    stormCount: 7,
  );

  PodPlayerState? _savedSnapshot;

  void _clearPool() {
    _savedSnapshot = player;
    setState(() {
      player = player.copyWith(
        floatingMana: const {'W': 0, 'U': 0, 'B': 0, 'R': 0, 'G': 0, 'C': 0},
        stormCount: 0,
      );
    });
  }

  void _undo() {
    if (_savedSnapshot != null) {
      setState(() {
        player = _savedSnapshot!;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FloatingManaDrawerWidget(
      player: player,
      autoCloseOnClear: false,
      onManaDelta: (color, delta) {
        final current = player.floatingMana[color] ?? 0;
        final newMap = Map<String, int>.from(player.floatingMana);
        newMap[color] = current + delta;
        setState(() {
          player = player.copyWith(floatingMana: newMap);
        });
      },
      onManaClear: _clearPool,
      onStormDelta: (delta) {
        setState(() {
          player = player.copyWith(stormCount: player.stormCount + delta);
        });
      },
      onUndo: _undo,
    );
  }
}
