// Copyright (c) 2026 Countr. All rights reserved.
// Adversarial Responsive & Touch Isolation Challenger Stress Test Suite
// Authored by m3_challenger_responsive_2

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/features/life_counter/domain/models/pod_state.dart';
import 'package:countr/features/life_counter/presentation/widgets/pod_scaffold_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Helper function to pump PodScaffoldWidget with arbitrary viewport size
  Future<void> pumpPodHarness(
    WidgetTester tester, {
    required PodState state,
    required Size size,
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
        theme: ThemeData.dark(),
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
  // SECTION 1: Responsive Breakpoint Switching (599.0dp vs 600.0dp)
  // ===========================================================================
  group('1. Responsive Breakpoint Switching (599.0dp vs 600.0dp)', () {
    const pod2P = PodState(
      sessionId: 'test_breakpoint_2p',
      format: 'standard',
      startingLife: 20,
      players: [
        PodPlayerState(id: 'p1', seatIndex: 0, name: 'P1', life: 20),
        PodPlayerState(id: 'p2', seatIndex: 1, name: 'P2', life: 20),
      ],
    );

    testWidgets('Portrait exactly 599.0dp shortest side -> Phone mode (drawer_toggle visible, drawer collapsed)', (tester) async {
      await pumpPodHarness(tester, state: pod2P, size: const Size(599.0, 900.0));

      expect(find.byKey(const Key('drawer_toggle_p1')), findsOneWidget);
      expect(find.byKey(const Key('drawer_panel_p1')), findsNothing);
      expect(find.byKey(const Key('val_poison_p1')), findsNothing);

      // Open drawer
      await tester.tap(find.byKey(const Key('drawer_toggle_p1')));
      await tester.pump();
      expect(find.byKey(const Key('drawer_panel_p1')), findsOneWidget);
      expect(find.byKey(const Key('val_poison_p1')), findsOneWidget);

      // Close drawer
      await tester.tap(find.byKey(const Key('drawer_toggle_p1')));
      await tester.pump();
      expect(find.byKey(const Key('drawer_panel_p1')), findsNothing);
    });

    testWidgets('Portrait exactly 600.0dp shortest side -> Tablet mode (perpetual tool rail visible)', (tester) async {
      await pumpPodHarness(tester, state: pod2P, size: const Size(600.0, 900.0));

      expect(find.byKey(const Key('drawer_toggle_p1')), findsNothing);
      expect(find.byKey(const Key('val_poison_p1')), findsOneWidget);
    });

    testWidgets('Landscape shortest side 599.0dp (width 900, height 599) -> Phone mode', (tester) async {
      await pumpPodHarness(tester, state: pod2P, size: const Size(900.0, 599.0));

      expect(find.byKey(const Key('drawer_toggle_p1')), findsOneWidget);
      expect(find.byKey(const Key('val_poison_p1')), findsNothing);
    });

    testWidgets('Landscape shortest side 600.0dp (width 900, height 600) -> Tablet mode', (tester) async {
      await pumpPodHarness(tester, state: pod2P, size: const Size(900.0, 600.0));

      expect(find.byKey(const Key('drawer_toggle_p1')), findsNothing);
      expect(find.byKey(const Key('val_poison_p1')), findsOneWidget);
    });

    testWidgets('Sub-pixel boundary 599.9dp shortest side -> Phone mode', (tester) async {
      await pumpPodHarness(tester, state: pod2P, size: const Size(599.9, 900.0));

      expect(find.byKey(const Key('drawer_toggle_p1')), findsOneWidget);
      expect(find.byKey(const Key('val_poison_p1')), findsNothing);
    });
  });

  // ===========================================================================
  // SECTION 2: CenterHubButton Hit-Testing & Touch Isolation Stress
  // ===========================================================================
  group('2. CenterHubButton Hit-Testing & Touch Isolation Stress', () {
    const pod4P = PodState(
      sessionId: 'test_isolation_4p',
      format: 'commander',
      startingLife: 40,
      players: [
        PodPlayerState(id: 'p1', seatIndex: 0, name: 'P1', life: 40),
        PodPlayerState(id: 'p2', seatIndex: 1, name: 'P2', life: 40),
        PodPlayerState(id: 'p3', seatIndex: 2, name: 'P3', life: 40),
        PodPlayerState(id: 'p4', seatIndex: 3, name: 'P4', life: 40),
      ],
    );

    testWidgets('Rapid concurrent taps on adjacent quadrants do NOT trigger center hub', (tester) async {
      int hubTapCount = 0;
      final Map<String, int> lifeChanges = {'p1': 0, 'p2': 0, 'p3': 0, 'p4': 0};

      await pumpPodHarness(
        tester,
        state: pod4P,
        size: const Size(400, 800),
        onRandomizerPressed: () => hubTapCount++,
        onLifeDelta: (id, delta) => lifeChanges[id] = (lifeChanges[id] ?? 0) + delta,
      );

      // Perform 20 rapid taps across all 4 quadrants
      for (int i = 0; i < 5; i++) {
        await tester.tap(find.byKey(const Key('hitbox_plus_p1')));
        await tester.tap(find.byKey(const Key('hitbox_minus_p2')));
        await tester.tap(find.byKey(const Key('hitbox_plus_p3')));
        await tester.tap(find.byKey(const Key('hitbox_minus_p4')));
      }
      await tester.pump();

      expect(hubTapCount, 0, reason: 'Center hub should never be triggered by quadrant taps');
      expect(lifeChanges['p1'], 5);
      expect(lifeChanges['p2'], -5);
      expect(lifeChanges['p3'], 5);
      expect(lifeChanges['p4'], -5);
    });

    testWidgets('Rapid taps on CenterHubButton do NOT trigger adjacent player life deltas', (tester) async {
      int hubTapCount = 0;
      int totalLifeDeltas = 0;

      await pumpPodHarness(
        tester,
        state: pod4P,
        size: const Size(400, 800),
        onRandomizerPressed: () => hubTapCount++,
        onLifeDelta: (id, delta) => totalLifeDeltas += delta.abs(),
      );

      final centerBtn = find.byKey(const Key('center_hub_button'));
      expect(centerBtn, findsOneWidget);

      // Perform 15 rapid taps directly on the center hub button
      for (int i = 0; i < 15; i++) {
        await tester.tap(centerBtn);
      }
      await tester.pump();

      expect(hubTapCount, 15);
      expect(totalLifeDeltas, 0, reason: 'No player life changes should occur from hub taps');
    });

    testWidgets('Boundary hit-testing: within radius (20px from center) hits hub, outside radius (30px) does not hit hub', (tester) async {
      int hubTapCount = 0;
      await pumpPodHarness(
        tester,
        state: pod4P,
        size: const Size(400, 800),
        onRandomizerPressed: () => hubTapCount++,
      );

      final center = tester.getCenter(find.byKey(const Key('center_hub_button')));
      expect(center, const Offset(200.0, 400.0));

      // Tap 20px above center (inside 48px circle, r=24px)
      await tester.tapAt(center + const Offset(0, -20));
      await tester.pump();
      expect(hubTapCount, 1, reason: 'Tap at 20px from center should hit the 48px hub');

      // Tap 30px above center (outside 48px circle, r=24px)
      await tester.tapAt(center + const Offset(0, -30));
      await tester.pump();
      expect(hubTapCount, 1, reason: 'Tap at 30px from center should NOT hit the 48px hub');
    });

    testWidgets('Interleaved rapid taps between center hub and quadrant hitboxes maintain strict state isolation', (tester) async {
      int hubTapCount = 0;
      int p1Deltas = 0;

      await pumpPodHarness(
        tester,
        state: pod4P,
        size: const Size(400, 800),
        onRandomizerPressed: () => hubTapCount++,
        onLifeDelta: (id, delta) {
          if (id == 'p1') p1Deltas += delta;
        },
      );

      final centerBtn = find.byKey(const Key('center_hub_button'));
      final p1Plus = find.byKey(const Key('hitbox_plus_p1'));

      for (int i = 0; i < 10; i++) {
        await tester.tap(centerBtn);
        await tester.tap(p1Plus);
      }
      await tester.pump();

      expect(hubTapCount, 10);
      expect(p1Deltas, 10);
    });
  });

  // ===========================================================================
  // SECTION 3: Extreme Life Totals & FittedBox Dynamic Scaling Verification
  // ===========================================================================
  group('3. Extreme Life Totals & FittedBox Dynamic Scaling', () {
    testWidgets('1v1 layout handles negative life (-50) and extreme life (99999) without overflow on 360x640', (tester) async {
      const pod1v1 = PodState(
        sessionId: 'test_extreme_1v1',
        format: 'standard',
        startingLife: 20,
        players: [
          PodPlayerState(id: 'p1', seatIndex: 0, name: 'P1', life: -50),
          PodPlayerState(id: 'p2', seatIndex: 1, name: 'P2', life: 99999),
        ],
      );

      await pumpPodHarness(tester, state: pod1v1, size: const Size(360, 640));

      expect(find.text('-50'), findsOneWidget);
      expect(find.text('99999'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Remediated: 4-Player pod with life 99999 on 360x640 phone renders without overflow', (tester) async {
      const pod4P = PodState(
        sessionId: 'test_extreme_4p',
        format: 'commander',
        startingLife: 40,
        players: [
          PodPlayerState(id: 'p1', seatIndex: 0, name: 'P1', life: 99999),
          PodPlayerState(id: 'p2', seatIndex: 1, name: 'P2', life: 40),
          PodPlayerState(id: 'p3', seatIndex: 2, name: 'P3', life: 40),
          PodPlayerState(id: 'p4', seatIndex: 3, name: 'P4', life: 40),
        ],
      );

      await pumpPodHarness(tester, state: pod4P, size: const Size(360, 640));

      expect(find.text('99999'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Remediated: 4-Player pod with negative life -50 on 360x640 phone renders without overflow', (tester) async {
      const pod4P = PodState(
        sessionId: 'test_extreme_4p_neg',
        format: 'commander',
        startingLife: 40,
        players: [
          PodPlayerState(id: 'p1', seatIndex: 0, name: 'P1', life: -50),
          PodPlayerState(id: 'p2', seatIndex: 1, name: 'P2', life: 40),
          PodPlayerState(id: 'p3', seatIndex: 2, name: 'P3', life: 40),
          PodPlayerState(id: 'p4', seatIndex: 3, name: 'P4', life: 40),
        ],
      );

      await pumpPodHarness(tester, state: pod4P, size: const Size(360, 640));

      expect(find.text('-50'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Remediated: 6-Player pod on 360x640 phone renders without overflow', (tester) async {
      final pod6P = PodState(
        sessionId: 'test_extreme_6p',
        format: 'commander',
        startingLife: 40,
        players: List.generate(
          6,
          (i) => PodPlayerState(
            id: 'p$i',
            seatIndex: i,
            name: 'P$i',
            life: 40,
          ),
        ),
      );

      await pumpPodHarness(tester, state: pod6P, size: const Size(360, 640));

      expect(tester.takeException(), isNull);
    });

    testWidgets('Tablet mode (768x1024) provides sufficient width and renders extreme life 99999 without overflow', (tester) async {
      const pod4PTablet = PodState(
        sessionId: 'test_tablet_extreme',
        format: 'commander',
        startingLife: 40,
        players: [
          PodPlayerState(id: 'p1', seatIndex: 0, name: 'P1', life: 99999),
          PodPlayerState(id: 'p2', seatIndex: 1, name: 'P2', life: -50),
          PodPlayerState(id: 'p3', seatIndex: 2, name: 'P3', life: 40),
          PodPlayerState(id: 'p4', seatIndex: 3, name: 'P4', life: 40),
        ],
      );

      await pumpPodHarness(tester, state: pod4PTablet, size: const Size(768, 1024));

      expect(find.text('99999'), findsOneWidget);
      expect(find.text('-50'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
