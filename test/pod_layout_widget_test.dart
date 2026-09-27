// Copyright (c) 2026 Countr. All rights reserved.
// Comprehensive Widget Test Suite for Milestone 3 Responsive Dynamic Pod Layout Engine.
// Covers:
// - CenterHubButton component specifications, styling, sizing, semantics, and tap events
// - 1v1 horizontal split layout geometry & opposing player 180° rotation
// - 3-player asymmetric layout geometry (2 top 180°, 1 bottom 0°)
// - 4-player 2x2 quadrant grid layout geometry (top row 180°, bottom row 0°)
// - 5-player hybrid layout geometry (3 top 180°, 2 bottom 0°)
// - 6-player 2x3 grid layout geometry (3 top 180°, 3 bottom 0°)
// - CenterHubButton crossroads positioning and tap callback dispatch
// - Touch hit-test non-interference between hub button and player quadrants
// - Responsive switching between Phone (<600dp) drawers and Tablet (>=600dp) tool rails
// - Exact boundary threshold (599dp vs 600dp)
// - Dynamic orientation switching (Portrait vs Landscape)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/features/life_counter/domain/models/pod_state.dart';
import 'package:countr/features/life_counter/presentation/widgets/center_hub_button.dart';
import 'package:countr/features/life_counter/presentation/widgets/pod_scaffold_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Helper function to pump PodScaffoldWidget with deterministic viewport size
  Future<void> pumpPodHarness(
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
  // GROUP 1: CenterHubButton Component Tests (Feature 24)
  // ===========================================================================
  group('CenterHubButton Component Tests (Feature 24)', () {
    testWidgets('renders 48x48 circular button with dice icon and dark background', (tester) async {
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

      final buttonFinder = find.byKey(const Key('center_hub_button'));
      expect(buttonFinder, findsOneWidget);

      // Verify exact 48x48px dimensions
      final containerFinder = find.ancestor(
        of: buttonFinder,
        matching: find.byType(Container),
      );
      expect(containerFinder, findsOneWidget);
      final RenderBox renderBox = tester.renderObject(containerFinder);
      expect(renderBox.size.width, 48.0);
      expect(renderBox.size.height, 48.0);

      // Verify icon presence
      expect(find.byIcon(Icons.casino), findsOneWidget);

      // Verify tap callback
      await tester.tap(buttonFinder);
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('handles null onPressed callback gracefully (disabled state)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: CenterHubButton(onPressed: null),
            ),
          ),
        ),
      );

      final buttonFinder = find.byKey(const Key('center_hub_button'));
      expect(buttonFinder, findsOneWidget);

      // Tapping disabled button does not throw
      await tester.tap(buttonFinder);
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  // ===========================================================================
  // GROUP 2: 1v1 Split Pod Layout (Feature 16 & Feature 21)
  // ===========================================================================
  group('1v1 Split Pod Layout (Feature 16 & Feature 21)', () {
    const state1v1 = PodState(
      sessionId: 'test_1v1',
      format: 'standard',
      startingLife: 20,
      players: [
        PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 20),
        PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 20),
      ],
    );

    testWidgets('renders two player quadrants split vertically across table', (tester) async {
      await pumpPodHarness(tester, state: state1v1);

      expect(find.byKey(const Key('quadrant_p1')), findsOneWidget);
      expect(find.byKey(const Key('quadrant_p2')), findsOneWidget);

      // Alice (p1, seat 0) is at bottom; Bob (p2, seat 1) is at top
      final p1Center = tester.getCenter(find.byKey(const Key('quadrant_p1')));
      final p2Center = tester.getCenter(find.byKey(const Key('quadrant_p2')));
      expect(p2Center.dy, lessThan(p1Center.dy));
      expect(p2Center.dy, closeTo(200.0, 5.0));
      expect(p1Center.dy, closeTo(600.0, 5.0));
    });

    testWidgets('inverts opposing top player by 180 degrees (quarterTurns: 2)', (tester) async {
      await pumpPodHarness(tester, state: state1v1);

      // Verify Bob (top player, p2) is wrapped in RotatedBox with quarterTurns == 2
      final p2RotatedBox = tester.widget<RotatedBox>(
        find.ancestor(
          of: find.byKey(const Key('quadrant_p2')),
          matching: find.byType(RotatedBox),
        ),
      );
      expect(p2RotatedBox.quarterTurns, 2);

      // Verify Alice (bottom player, p1) is NOT wrapped in a RotatedBox
      final p1RotatedBoxFinder = find.ancestor(
        of: find.byKey(const Key('quadrant_p1')),
        matching: find.byType(RotatedBox),
      );
      expect(p1RotatedBoxFinder, findsNothing);
    });

    testWidgets('renders horizontal divider between top and bottom quadrants', (tester) async {
      await pumpPodHarness(tester, state: state1v1);
      expect(find.byType(Divider), findsOneWidget);
    });
  });

  // ===========================================================================
  // GROUP 3: 3-Player Asymmetric Pod Layout (Feature 17 & Feature 21)
  // ===========================================================================
  group('3-Player Asymmetric Pod Layout (Feature 17 & Feature 21)', () {
    const state3P = PodState(
      sessionId: 'test_3p',
      format: 'brawl',
      startingLife: 30,
      players: [
        PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 30),
        PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 30),
        PodPlayerState(id: 'p3', seatIndex: 2, name: 'Charlie', life: 30),
      ],
    );

    testWidgets('renders 2 top players (180°) and 1 bottom player (0°)', (tester) async {
      await pumpPodHarness(tester, state: state3P);

      expect(find.byKey(const Key('quadrant_p1')), findsOneWidget);
      expect(find.byKey(const Key('quadrant_p2')), findsOneWidget);
      expect(find.byKey(const Key('quadrant_p3')), findsOneWidget);

      // Verify top row players (p2, p3) have quarterTurns == 2
      final p2Rotated = tester.widget<RotatedBox>(
        find.ancestor(
          of: find.byKey(const Key('quadrant_p2')),
          matching: find.byType(RotatedBox),
        ),
      );
      final p3Rotated = tester.widget<RotatedBox>(
        find.ancestor(
          of: find.byKey(const Key('quadrant_p3')),
          matching: find.byType(RotatedBox),
        ),
      );
      expect(p2Rotated.quarterTurns, 2);
      expect(p3Rotated.quarterTurns, 2);

      // Verify bottom player (p1) is unrotated
      final p1Rotated = find.ancestor(
        of: find.byKey(const Key('quadrant_p1')),
        matching: find.byType(RotatedBox),
      );
      expect(p1Rotated, findsNothing);
    });

    testWidgets('top row players split width equally (50% each), bottom player spans 100%', (tester) async {
      await pumpPodHarness(tester, state: state3P, size: const Size(400, 800));

      final p2Size = tester.getSize(find.byKey(const Key('quadrant_p2')));
      final p3Size = tester.getSize(find.byKey(const Key('quadrant_p3')));
      final p1Size = tester.getSize(find.byKey(const Key('quadrant_p1')));

      // Top two quadrants share width (~199px each allowing for 2px divider)
      expect(p2Size.width, closeTo(199.0, 2.0));
      expect(p3Size.width, closeTo(199.0, 2.0));

      // Bottom quadrant spans full screen width
      expect(p1Size.width, 400.0);
    });

    testWidgets('renders vertical divider between top players and horizontal divider between rows', (tester) async {
      await pumpPodHarness(tester, state: state3P);
      expect(find.byType(VerticalDivider), findsOneWidget);
      expect(find.byType(Divider), findsOneWidget);
    });
  });

  // ===========================================================================
  // GROUP 4: 4-Player 2x2 Quadrant Layout (Feature 18 & Feature 21)
  // ===========================================================================
  group('4-Player 2x2 Quadrant Layout (Feature 18 & Feature 21)', () {
    const state4P = PodState(
      sessionId: 'test_4p',
      format: 'commander',
      startingLife: 40,
      players: [
        PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40),
        PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40),
        PodPlayerState(id: 'p3', seatIndex: 2, name: 'Charlie', life: 40),
        PodPlayerState(id: 'p4', seatIndex: 3, name: 'Diana', life: 40),
      ],
    );

    testWidgets('renders all 4 quadrants in a balanced 2x2 grid', (tester) async {
      await pumpPodHarness(tester, state: state4P);

      expect(find.byKey(const Key('quadrant_p1')), findsOneWidget);
      expect(find.byKey(const Key('quadrant_p2')), findsOneWidget);
      expect(find.byKey(const Key('quadrant_p3')), findsOneWidget);
      expect(find.byKey(const Key('quadrant_p4')), findsOneWidget);
    });

    testWidgets('top row (p2, p3) rotated 180°, bottom row (p1, p4) unrotated 0°', (tester) async {
      await pumpPodHarness(tester, state: state4P);

      final p2Rotated = tester.widget<RotatedBox>(
        find.ancestor(of: find.byKey(const Key('quadrant_p2')), matching: find.byType(RotatedBox)),
      );
      final p3Rotated = tester.widget<RotatedBox>(
        find.ancestor(of: find.byKey(const Key('quadrant_p3')), matching: find.byType(RotatedBox)),
      );
      expect(p2Rotated.quarterTurns, 2);
      expect(p3Rotated.quarterTurns, 2);

      expect(
        find.ancestor(of: find.byKey(const Key('quadrant_p1')), matching: find.byType(RotatedBox)),
        findsNothing,
      );
      expect(
        find.ancestor(of: find.byKey(const Key('quadrant_p4')), matching: find.byType(RotatedBox)),
        findsNothing,
      );
    });

    testWidgets('quadrants sit in distinct grid positions without overlap', (tester) async {
      await pumpPodHarness(tester, state: state4P, size: const Size(400, 800));

      final p2Center = tester.getCenter(find.byKey(const Key('quadrant_p2'))); // Top-Left
      final p3Center = tester.getCenter(find.byKey(const Key('quadrant_p3'))); // Top-Right
      final p1Center = tester.getCenter(find.byKey(const Key('quadrant_p1'))); // Bottom-Left
      final p4Center = tester.getCenter(find.byKey(const Key('quadrant_p4'))); // Bottom-Right

      // Top row vs Bottom row (Y bounds)
      expect(p2Center.dy, closeTo(200.0, 5.0));
      expect(p3Center.dy, closeTo(200.0, 5.0));
      expect(p1Center.dy, closeTo(600.0, 5.0));
      expect(p4Center.dy, closeTo(600.0, 5.0));

      // Left column vs Right column (X bounds)
      expect(p2Center.dx, closeTo(100.0, 5.0));
      expect(p1Center.dx, closeTo(100.0, 5.0));
      expect(p3Center.dx, closeTo(300.0, 5.0));
      expect(p4Center.dx, closeTo(300.0, 5.0));
    });

    testWidgets('renders 2 vertical dividers and 1 horizontal divider', (tester) async {
      await pumpPodHarness(tester, state: state4P);
      expect(find.byType(VerticalDivider), findsNWidgets(2));
      expect(find.byType(Divider), findsOneWidget);
    });
  });

  // ===========================================================================
  // GROUP 5: 5-Player Hybrid Pod Layout (Feature 19 & Feature 21)
  // ===========================================================================
  group('5-Player Hybrid Pod Layout (Feature 19 & Feature 21)', () {
    const state5P = PodState(
      sessionId: 'test_5p',
      format: 'commander',
      startingLife: 40,
      players: [
        PodPlayerState(id: 'p1', seatIndex: 0, name: 'P1', life: 40),
        PodPlayerState(id: 'p2', seatIndex: 1, name: 'P2', life: 40),
        PodPlayerState(id: 'p3', seatIndex: 2, name: 'P3', life: 40),
        PodPlayerState(id: 'p4', seatIndex: 3, name: 'P4', life: 40),
        PodPlayerState(id: 'p5', seatIndex: 4, name: 'P5', life: 40),
      ],
    );

    testWidgets('renders 3 top players (180°) and 2 bottom players (0°)', (tester) async {
      await pumpPodHarness(tester, state: state5P, size: const Size(600, 900));

      for (int i = 1; i <= 5; i++) {
        expect(find.byKey(Key('quadrant_p$i')), findsOneWidget);
      }

      // Top row: p2, p3, p4 rotated 180°
      for (final id in ['p2', 'p3', 'p4']) {
        final rotated = tester.widget<RotatedBox>(
          find.ancestor(of: find.byKey(Key('quadrant_$id')), matching: find.byType(RotatedBox)),
        );
        expect(rotated.quarterTurns, 2);
      }

      // Bottom row: p1, p5 unrotated 0°
      for (final id in ['p1', 'p5']) {
        expect(
          find.ancestor(of: find.byKey(Key('quadrant_$id')), matching: find.byType(RotatedBox)),
          findsNothing,
        );
      }

      expect(tester.takeException(), isNull);
    });

    testWidgets('top row has 2 vertical dividers and bottom row has 1 vertical divider', (tester) async {
      await pumpPodHarness(tester, state: state5P);
      expect(find.byType(VerticalDivider), findsNWidgets(3));
      expect(find.byType(Divider), findsOneWidget);
    });
  });

  // ===========================================================================
  // GROUP 6: 6-Player 2x3 Grid Layout (Feature 20 & Feature 21)
  // ===========================================================================
  group('6-Player 2x3 Grid Layout (Feature 20 & Feature 21)', () {
    const state6P = PodState(
      sessionId: 'test_6p',
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

    testWidgets('renders all 6 quadrants in 2x3 grid without layout overflow', (tester) async {
      await pumpPodHarness(tester, state: state6P, size: const Size(600, 1000));

      for (int i = 1; i <= 6; i++) {
        expect(find.byKey(Key('quadrant_p$i')), findsOneWidget);
      }

      // Top row (p2, p3, p4) rotated 180°
      for (final id in ['p2', 'p3', 'p4']) {
        final rotated = tester.widget<RotatedBox>(
          find.ancestor(of: find.byKey(Key('quadrant_$id')), matching: find.byType(RotatedBox)),
        );
        expect(rotated.quarterTurns, 2);
      }

      // Bottom row (p1, p5, p6) unrotated
      for (final id in ['p1', 'p5', 'p6']) {
        expect(
          find.ancestor(of: find.byKey(Key('quadrant_$id')), matching: find.byType(RotatedBox)),
          findsNothing,
        );
      }

      expect(tester.takeException(), isNull);
    });

    testWidgets('renders 4 vertical dividers (2 top row, 2 bottom row) and 1 horizontal divider', (tester) async {
      await pumpPodHarness(tester, state: state6P);
      expect(find.byType(VerticalDivider), findsNWidgets(4));
      expect(find.byType(Divider), findsOneWidget);
    });
  });

  // ===========================================================================
  // GROUP 7: Center Crossroads Hub Button Interactions & Touch Isolation
  // ===========================================================================
  group('Center Crossroads Hub Button Interactions & Touch Isolation', () {
    const state4P = PodState(
      sessionId: 'test_hub',
      format: 'commander',
      startingLife: 40,
      players: [
        PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40),
        PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40),
        PodPlayerState(id: 'p3', seatIndex: 2, name: 'Charlie', life: 40),
        PodPlayerState(id: 'p4', seatIndex: 3, name: 'Diana', life: 40),
      ],
    );

    testWidgets('CenterHubButton is positioned at the geometric center of viewport', (tester) async {
      await pumpPodHarness(tester, state: state4P, size: const Size(400, 800));

      final centerBtn = find.byKey(const Key('center_hub_button'));
      expect(centerBtn, findsOneWidget);

      final centerPoint = tester.getCenter(centerBtn);
      expect(centerPoint.dx, 200.0);
      expect(centerPoint.dy, 400.0);
    });

    testWidgets('tapping CenterHubButton invokes onRandomizerPressed callback', (tester) async {
      bool hubTapped = false;

      await pumpPodHarness(
        tester,
        state: state4P,
        size: const Size(400, 800),
        onRandomizerPressed: () => hubTapped = true,
      );

      await tester.tap(find.byKey(const Key('center_hub_button')));
      await tester.pump();

      expect(hubTapped, isTrue);
    });

    testWidgets('touch isolation: tapping player life zone does NOT trigger CenterHubButton', (tester) async {
      bool hubTapped = false;
      int lifeDelta = 0;

      await pumpPodHarness(
        tester,
        state: state4P,
        size: const Size(400, 800),
        onRandomizerPressed: () => hubTapped = true,
        onLifeDelta: (id, delta) {
          if (id == 'p1') lifeDelta += delta;
        },
      );

      // Tap Player 1's decrement hitbox
      final minusTouchFinder = find.byKey(const Key('hitbox_minus_p1'));
      expect(minusTouchFinder, findsOneWidget);

      await tester.tap(minusTouchFinder);
      await tester.pump();

      // Verify life was modified but center hub was NOT triggered
      expect(lifeDelta, -1);
      expect(hubTapped, isFalse);
    });

    testWidgets('touch isolation: tapping CenterHubButton does NOT trigger player life modifications', (tester) async {
      bool hubTapped = false;
      int recordedDeltas = 0;

      await pumpPodHarness(
        tester,
        state: state4P,
        size: const Size(400, 800),
        onRandomizerPressed: () => hubTapped = true,
        onLifeDelta: (id, delta) {
          recordedDeltas += delta;
        },
      );

      await tester.tap(find.byKey(const Key('center_hub_button')));
      await tester.pump();

      expect(hubTapped, isTrue);
      expect(recordedDeltas, 0);
    });

    testWidgets('CenterHubButton is present and tappable in 1v1 and 6P pods', (tester) async {
      bool hubTapped1v1 = false;
      const state1v1 = PodState(
        sessionId: 'test_1v1_hub',
        format: 'standard',
        startingLife: 20,
        players: [
          PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 20),
          PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 20),
        ],
      );
      await pumpPodHarness(
        tester,
        state: state1v1,
        onRandomizerPressed: () => hubTapped1v1 = true,
      );
      expect(find.byKey(const Key('center_hub_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('center_hub_button')));
      await tester.pump();
      expect(hubTapped1v1, isTrue);

      bool hubTapped6P = false;
      const state6P = PodState(
        sessionId: 'test_6p_hub',
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
      await pumpPodHarness(
        tester,
        state: state6P,
        size: const Size(600, 1000),
        onRandomizerPressed: () => hubTapped6P = true,
      );
      expect(find.byKey(const Key('center_hub_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('center_hub_button')));
      await tester.pump();
      expect(hubTapped6P, isTrue);
    });
  });

  // ===========================================================================
  // GROUP 8: Responsive Form Factor Switching (Phone vs Tablet)
  // ===========================================================================
  group('Responsive Form Factor Switching (Phone vs Tablet)', () {
    const state = PodState(
      sessionId: 'test_responsive',
      format: 'commander',
      startingLife: 40,
      players: [
        PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40),
        PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40),
      ],
    );

    testWidgets('Phone mode (<600dp shortestSide): drawer toggle visible, drawer panel initially closed', (tester) async {
      // Dimensions with shortestSide 375 < 600
      await pumpPodHarness(tester, state: state, size: const Size(375, 812));

      expect(find.byKey(const Key('drawer_toggle_p1')), findsOneWidget);
      expect(find.byKey(const Key('drawer_panel_p1')), findsNothing);

      // Tap drawer toggle to open panel
      await tester.tap(find.byKey(const Key('drawer_toggle_p1')));
      await tester.pump();

      expect(find.byKey(const Key('drawer_panel_p1')), findsOneWidget);
    });

    testWidgets('Tablet mode (>=600dp shortestSide): perpetual tool rail rendered, drawer toggle hidden', (tester) async {
      // Dimensions with shortestSide 768 >= 600
      await pumpPodHarness(tester, state: state, size: const Size(768, 1024));

      expect(find.byKey(const Key('drawer_toggle_p1')), findsNothing);
      expect(find.byKey(const Key('val_poison_p1')), findsOneWidget);
    });

    testWidgets('exact boundary: 599dp activates Phone mode, 600dp activates Tablet mode', (tester) async {
      // 599dp boundary -> Phone
      await pumpPodHarness(tester, state: state, size: const Size(599, 900));
      expect(find.byKey(const Key('drawer_toggle_p1')), findsOneWidget);
      expect(find.byKey(const Key('val_poison_p1')), findsNothing);

      // 600dp boundary -> Tablet
      await pumpPodHarness(tester, state: state, size: const Size(600, 900));
      expect(find.byKey(const Key('drawer_toggle_p1')), findsNothing);
      expect(find.byKey(const Key('val_poison_p1')), findsOneWidget);
    });
  });

  // ===========================================================================
  // GROUP 9: Orientation Changes (Portrait vs Landscape)
  // ===========================================================================
  group('Orientation Changes (Portrait vs Landscape)', () {
    const state4P = PodState(
      sessionId: 'test_orientation',
      format: 'commander',
      startingLife: 40,
      players: [
        PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40),
        PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40),
        PodPlayerState(id: 'p3', seatIndex: 2, name: 'Charlie', life: 40),
        PodPlayerState(id: 'p4', seatIndex: 3, name: 'Diana', life: 40),
      ],
    );

    testWidgets('renders cleanly in portrait mode without layout overflow', (tester) async {
      await pumpPodHarness(tester, state: state4P, size: const Size(400, 800));

      expect(find.byKey(const Key('quadrant_p1')), findsOneWidget);
      expect(find.byKey(const Key('quadrant_p2')), findsOneWidget);
      expect(find.byKey(const Key('quadrant_p3')), findsOneWidget);
      expect(find.byKey(const Key('quadrant_p4')), findsOneWidget);
      expect(find.byKey(const Key('center_hub_button')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('dynamically adapts to landscape mode and maintains centered hub button', (tester) async {
      await pumpPodHarness(tester, state: state4P, size: const Size(800, 400));

      expect(find.byKey(const Key('quadrant_p1')), findsOneWidget);
      expect(find.byKey(const Key('quadrant_p2')), findsOneWidget);
      expect(find.byKey(const Key('quadrant_p3')), findsOneWidget);
      expect(find.byKey(const Key('quadrant_p4')), findsOneWidget);

      final centerBtn = find.byKey(const Key('center_hub_button'));
      expect(centerBtn, findsOneWidget);
      final centerPoint = tester.getCenter(centerBtn);
      expect(centerPoint.dx, 400.0);
      expect(centerPoint.dy, 200.0);
      expect(tester.takeException(), isNull);
    });
  });
}
