// Copyright (c) 2026 Countr. All rights reserved.
// Bespoke empirical stress verification test by m3_challenger_responsive_2_it2
// Verifying breakpoint switching, touch isolation, extreme life values, and drawer panel scrolling on small screens.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/features/life_counter/domain/models/pod_state.dart';
import 'package:countr/features/life_counter/presentation/widgets/pod_scaffold_widget.dart';
import 'package:countr/features/life_counter/presentation/widgets/center_hub_button.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpHarness(
    WidgetTester tester, {
    required PodState state,
    required Size size,
    void Function(String playerId, int delta)? onLifeDelta,
    VoidCallback? onRandomizerPressed,
    void Function(String playerId, String counterType, int delta)? onCounterDelta,
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
          onRandomizerPressed: onRandomizerPressed,
          onCounterDelta: onCounterDelta,
        ),
      ),
    );
    await tester.pump();
  }

  group('Focus 1: Responsive Breakpoint Switching (599dp vs 600dp & Subpixel)', () {
    const pod = PodState(
      sessionId: 'bp_test',
      format: 'commander',
      startingLife: 40,
      players: [
        PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40),
        PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40),
      ],
    );

    testWidgets('599.0dp shortest side in portrait activates Phone mode', (tester) async {
      await pumpHarness(tester, state: pod, size: const Size(599.0, 800.0));
      expect(find.byKey(const Key('drawer_toggle_p1')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('599.99dp shortest side in portrait activates Phone mode', (tester) async {
      await pumpHarness(tester, state: pod, size: const Size(599.99, 800.0));
      expect(find.byKey(const Key('drawer_toggle_p1')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('600.0dp shortest side in portrait activates Tablet mode', (tester) async {
      await pumpHarness(tester, state: pod, size: const Size(600.0, 800.0));
      expect(find.byKey(const Key('drawer_toggle_p1')), findsNothing);
      expect(find.byKey(const Key('val_poison_p1')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('599.0dp shortest side in landscape (800x599) activates Phone mode', (tester) async {
      await pumpHarness(tester, state: pod, size: const Size(800.0, 599.0));
      expect(find.byKey(const Key('drawer_toggle_p1')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('600.0dp shortest side in landscape (800x600) activates Tablet mode', (tester) async {
      await pumpHarness(tester, state: pod, size: const Size(800.0, 600.0));
      expect(find.byKey(const Key('drawer_toggle_p1')), findsNothing);
      expect(find.byKey(const Key('val_poison_p1')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Focus 2: CenterHubButton Strict Hit-Testing & Touch Isolation', () {
    const pod4 = PodState(
      sessionId: 'iso_test',
      format: 'commander',
      startingLife: 40,
      players: [
        PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40),
        PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40),
        PodPlayerState(id: 'p3', seatIndex: 2, name: 'Charlie', life: 40),
        PodPlayerState(id: 'p4', seatIndex: 3, name: 'Dana', life: 40),
      ],
    );

    testWidgets('Geometric center tap and circular boundary fall-off', (tester) async {
      int hubTaps = 0;
      int lifeTaps = 0;

      await pumpHarness(
        tester,
        state: pod4,
        size: const Size(400, 800),
        onRandomizerPressed: () => hubTaps++,
        onLifeDelta: (id, delta) => lifeTaps++,
      );

      final center = tester.getCenter(find.byType(CenterHubButton));
      expect(center, const Offset(200.0, 400.0));

      // Exact center
      await tester.tapAt(center);
      await tester.pump();
      expect(hubTaps, 1);
      expect(lifeTaps, 0);

      // Within 23px radius (button is 48px circle, radius is 24px)
      await tester.tapAt(center + const Offset(15, 15)); // distance = sqrt(450) ~ 21.2px < 24px
      await tester.pump();
      expect(hubTaps, 2);
      expect(lifeTaps, 0);

      // Outside radius at 35px from center (e.g. into quadrant area)
      await tester.tapAt(center + const Offset(35, 35));
      await tester.pump();
      // Should hit quadrant life plus or minus, NOT center hub
      expect(hubTaps, 2);
      expect(lifeTaps, 1);
    });
  });

  group('Focus 3: Extreme Life Totals Dynamic Scaling (-50 to 1,000,000)', () {
    testWidgets('6-player pod with extreme life values on 320x480 tiny screen has 0 overflow', (tester) async {
      const pod6 = PodState(
        sessionId: 'extreme_6p',
        format: 'commander',
        startingLife: 40,
        players: [
          PodPlayerState(id: 'p1', seatIndex: 0, name: 'P1', life: -50),
          PodPlayerState(id: 'p2', seatIndex: 1, name: 'P2', life: 40),
          PodPlayerState(id: 'p3', seatIndex: 2, name: 'P3', life: 99999),
          PodPlayerState(id: 'p4', seatIndex: 3, name: 'P4', life: -999),
          PodPlayerState(id: 'p5', seatIndex: 4, name: 'P5', life: 1000000),
          PodPlayerState(id: 'p6', seatIndex: 5, name: 'P6', life: 0),
        ],
      );

      await pumpHarness(tester, state: pod6, size: const Size(320, 480));

      expect(find.text('-50'), findsOneWidget);
      expect(find.text('40'), findsOneWidget);
      expect(find.text('99999'), findsOneWidget);
      expect(find.text('-999'), findsOneWidget);
      expect(find.text('1000000'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Focus 4: Drawer Panel Scrolling & Hit-Testing on Small Screens', () {
    final pod6 = PodState(
      sessionId: 'drawer_scroll_6p',
      format: 'commander',
      startingLife: 40,
      players: List.generate(
        6,
        (i) => PodPlayerState(
          id: 'p${i + 1}',
          seatIndex: i,
          name: 'Player ${i + 1}',
          life: 40,
          poison: 0,
        ),
      ),
    );

    testWidgets('Drawer opens and scrolls vertically without overflow on 320x480 tiny phone', (tester) async {
      int poisonDeltas = 0;

      await pumpHarness(
        tester,
        state: pod6,
        size: const Size(320, 480),
        onCounterDelta: (playerId, type, delta) {
          if (playerId == 'p1' && type == 'poison') {
            poisonDeltas += delta;
          }
        },
      );

      // Open drawer for p1
      final toggleP1 = find.byKey(const Key('drawer_toggle_p1'));
      expect(toggleP1, findsOneWidget);
      await tester.tap(toggleP1);
      await tester.pump();

      // Drawer panel is mounted
      expect(find.byKey(const Key('drawer_panel_p1')), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Scroll inside the drawer panel
      final drawerScrollable = find.descendant(
        of: find.byKey(const Key('drawer_panel_p1')),
        matching: find.byType(Scrollable),
      );
      expect(drawerScrollable, findsOneWidget);

      // Drag to verify scrollability
      await tester.drag(drawerScrollable, const Offset(0, -50));
      await tester.pump();
      expect(tester.takeException(), isNull);

      // Tap poison increment inside drawer
      final plusPoison = find.byKey(const Key('inc_poison_p1'));
      expect(plusPoison, findsOneWidget);
      await tester.tap(plusPoison);
      await tester.pump();
      expect(poisonDeltas, 1);
    });

    testWidgets('Drawer opens and scrolls without overflow on 480x320 tiny landscape', (tester) async {
      await pumpHarness(tester, state: pod6, size: const Size(480, 320));

      final toggleP1 = find.byKey(const Key('drawer_toggle_p1'));
      expect(toggleP1, findsOneWidget);
      await tester.tap(toggleP1);
      await tester.pump();

      expect(find.byKey(const Key('drawer_panel_p1')), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Drag inside drawer scrollable
      final drawerScrollable = find.descendant(
        of: find.byKey(const Key('drawer_panel_p1')),
        matching: find.byType(Scrollable),
      );
      expect(drawerScrollable, findsOneWidget);

      await tester.drag(drawerScrollable, const Offset(0, -30));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
