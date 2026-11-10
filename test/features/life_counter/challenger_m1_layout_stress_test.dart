// Copyright (c) 2026 Countr. All rights reserved.
// Challenger M1 Empirical Stress Test Suite
// Requirements Under Test:
// 1. CenterHubButton exact geometric centering (viewportWidth / 2, viewportHeight / 2) across viewports and player counts
// 2. Touch isolation: top-left area has no overlapping exit button occluding Player 2's quadrant
// 3. CentralUtilityBar Key('life_counter_exit_button') pops the screen cleanly without error
// 4. CentralUtilityBar 6 actions + center die hub with tap & long-press quick roll
// 5. Lifetap rounded card styling (16px radius, 4px margin, 1.5px border, 3.0px lethal border) & pitch-black canvas
// 6. Zero RenderFlex overflow under extreme 320x480 narrow viewport with 6 players

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/features/life_counter/domain/models/pod_state.dart';
import 'package:countr/features/life_counter/presentation/widgets/center_hub_button.dart';
import 'package:countr/features/life_counter/presentation/widgets/central_utility_bar.dart';
import 'package:countr/features/life_counter/presentation/widgets/player_quadrant_widget.dart';
import 'package:countr/features/life_counter/presentation/widgets/pod_scaffold_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  PodState createPod(int playerCount, {int startingLife = 40}) {
    return PodState(
      sessionId: 'challenger_m1_pod_${playerCount}p',
      format: playerCount == 2 ? 'standard' : 'commander',
      startingLife: startingLife,
      players: List.generate(
        playerCount,
        (i) => PodPlayerState(
          id: 'p${i + 1}',
          seatIndex: i,
          name: 'Player ${i + 1}',
          life: startingLife,
        ),
      ),
    );
  }

  Future<void> pumpPodWithViewport(
    WidgetTester tester, {
    required PodState state,
    required Size size,
    VoidCallback? onExitApp,
    VoidCallback? onResetGame,
    VoidCallback? onRandomizerPressed,
    void Function(int)? onPlayerSelected,
    void Function(String, int)? onLifeDelta,
    void Function(String, String, int)? onCommanderDamage,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: PodScaffoldWidget(
            podState: state,
            onResetGame: onResetGame,
            onRandomizerPressed: onRandomizerPressed,
            onPlayerSelected: onPlayerSelected,
            onLifeDelta: onLifeDelta,
            onCommanderDamage: onCommanderDamage,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  // ===========================================================================
  // REQUIREMENT 1: Geometric Centering Oracle
  // ===========================================================================
  group('1. Geometric Centering Oracle (CenterHubButton at exact midpoint)', () {
    final testViewports = <String, Size>{
      '360x640 (Compact Android)': const Size(360, 640),
      '390x844 (iPhone 14)': const Size(390, 844),
      '412x915 (Pixel 7)': const Size(412, 915),
      '768x1024 (iPad)': const Size(768, 1024),
      '800x1280 (10-inch Tablet)': const Size(800, 1280),
      '1024x768 (Tablet Landscape)': const Size(1024, 768),
      '844x390 (Phone Landscape)': const Size(844, 390),
      '320x480 (Legacy Small)': const Size(320, 480),
      '377x811 (Odd Dimensions)': const Size(377, 811),
    };

    for (final entry in testViewports.entries) {
      final name = entry.key;
      final size = entry.value;

      testWidgets('CenterHubButton is at exact geometric center on $name', (tester) async {
        final pod = createPod(4);
        await pumpPodWithViewport(tester, state: pod, size: size);

        final hubFinder = find.byKey(const Key('center_hub_button'));
        expect(hubFinder, findsOneWidget);

        final center = tester.getCenter(hubFinder);
        final expectedX = size.width / 2.0;
        final expectedY = size.height / 2.0;

        expect(
          (center.dx - expectedX).abs(),
          lessThan(0.5),
          reason: 'X coordinate ${center.dx} must match expected $expectedX within 0.5px on $name',
        );
        expect(
          (center.dy - expectedY).abs(),
          lessThan(0.5),
          reason: 'Y coordinate ${center.dy} must match expected $expectedY within 0.5px on $name',
        );
      });
    }

    testWidgets('CenterHubButton centering invariant holds across 1P, 2P, 3P, 4P, 5P, 6P pods', (tester) async {
      const size = Size(400, 800);
      for (int count = 1; count <= 6; count++) {
        final pod = createPod(count);
        await pumpPodWithViewport(tester, state: pod, size: size);

        final hubFinder = find.byKey(const Key('center_hub_button'));
        expect(hubFinder, findsOneWidget);

        final center = tester.getCenter(hubFinder);
        expect((center.dx - 200.0).abs(), lessThan(0.5));
        expect((center.dy - 400.0).abs(), lessThan(0.5));
      }
    });

    testWidgets('Standalone CentralUtilityBar places CenterHubButton at exact midpoint of its Stack', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                height: 100,
                child: CentralUtilityBar(
                  playerCount: 4,
                  onOpenRandomizer: () {},
                ),
              ),
            ),
          ),
        ),
      );

      final barCenter = tester.getCenter(find.byType(CentralUtilityBar));
      final hubCenter = tester.getCenter(find.byKey(const Key('center_hub_button')));

      expect((barCenter.dx - hubCenter.dx).abs(), lessThan(0.5));
      expect((barCenter.dy - hubCenter.dy).abs(), lessThan(0.5));
    });
  });

  // ===========================================================================
  // REQUIREMENT 2: Touch Isolation & Top-Left Area Invariants
  // ===========================================================================
  group('2. Touch Isolation & Top-Left Area Verification', () {
    testWidgets('Top-left corner contains NO exit button occluding Player 2 quadrant', (tester) async {
      final pod4P = createPod(4);
      await pumpPodWithViewport(tester, state: pod4P, size: const Size(400, 800));

      final exitFinder = find.byKey(const Key('life_counter_exit_button'));
      expect(exitFinder, findsOneWidget);

      final exitCenter = tester.getCenter(exitFinder);
      // Exit button must NOT be in top-left region (x < 100, y < 100)
      expect(
        exitCenter.dx > 100 || exitCenter.dy > 100,
        isTrue,
        reason: 'Exit button must not be positioned in top-left (actual: $exitCenter)',
      );

      // Verify exit button is located inside CentralUtilityBar near vertical center (~400px)
      expect(exitCenter.dy, closeTo(400.0, 30.0));
    });

    testWidgets('Tapping anywhere in top-left area (12, 12) to (50, 50) hits Player 2 and NEVER triggers exit', (tester) async {
      final pod4P = createPod(4);
      await pumpPodWithViewport(tester, state: pod4P, size: const Size(400, 800));

      // Tap at coordinates where legacy exit button used to reside
      await tester.tapAt(const Offset(12.0, 12.0));
      await tester.pump();
      await tester.tapAt(const Offset(24.0, 24.0));
      await tester.pump();
      await tester.tapAt(const Offset(40.0, 40.0));
      await tester.pump();

      // Screen remains cleanly mounted and active
      expect(find.byType(PodScaffoldWidget), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Player 2 hitboxes in top-left quadrant respond cleanly to taps without interference', (tester) async {
      int p2LifeDelta = 0;
      final pod4P = createPod(4);

      await pumpPodWithViewport(
        tester,
        state: pod4P,
        size: const Size(400, 800),
        onLifeDelta: (id, delta) {
          if (id == 'p2') p2LifeDelta += delta;
        },
      );

      // Player 2 is at top-left
      final p2Minus = find.byKey(const Key('hitbox_minus_p2'));
      final p2Plus = find.byKey(const Key('hitbox_plus_p2'));
      expect(p2Minus, findsOneWidget);
      expect(p2Plus, findsOneWidget);

      // Tap P2 minus 5 times
      for (int i = 0; i < 5; i++) {
        await tester.tap(p2Minus);
      }
      // Tap P2 plus 2 times
      for (int i = 0; i < 2; i++) {
        await tester.tap(p2Plus);
      }
      await tester.pump();

      expect(p2LifeDelta, -3);
      expect(find.byType(PodScaffoldWidget), findsOneWidget);
    });
  });

  // ===========================================================================
  // REQUIREMENT 3: CentralUtilityBar Exit Button Clean Pop
  // ===========================================================================
  group('3. Exit Button Clean Pop & Routing Verification', () {
    testWidgets('Key(life_counter_exit_button) cleanly pops the route in Navigator stack', (tester) async {
      bool poppedCleanly = false;
      final pod = createPod(4);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  key: const Key('open_tracker_button'),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => PodScaffoldWidget(podState: pod),
                      ),
                    ).then((_) {
                      poppedCleanly = true;
                    });
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to PodScaffoldWidget
      await tester.tap(find.byKey(const Key('open_tracker_button')));
      await tester.pumpAndSettle();
      expect(find.byType(PodScaffoldWidget), findsOneWidget);

      // Tap exit button on CentralUtilityBar
      final exitBtn = find.byKey(const Key('life_counter_exit_button'));
      expect(exitBtn, findsOneWidget);
      await tester.tap(exitBtn);
      await tester.pumpAndSettle();

      // Screen popped cleanly
      expect(poppedCleanly, isTrue);
      expect(find.byType(PodScaffoldWidget), findsNothing);
      expect(find.byKey(const Key('open_tracker_button')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('CentralUtilityBar with custom onExitApp callback invokes callback without popping automatically', (tester) async {
      bool customExitCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CentralUtilityBar(
                playerCount: 4,
                onExitApp: () => customExitCalled = true,
              ),
            ),
          ),
        ),
      );

      final exitBtn = find.byKey(const Key('life_counter_exit_button'));
      await tester.tap(exitBtn);
      await tester.pump();

      expect(customExitCalled, isTrue);
    });

    testWidgets('Rapid double-tap on exit button executes safely without uncaught exceptions', (tester) async {
      final pod = createPod(4);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  key: const Key('open_tracker'),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => PodScaffoldWidget(podState: pod),
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_tracker')));
      await tester.pumpAndSettle();

      final exitBtn = find.byKey(const Key('life_counter_exit_button'));
      await tester.tap(exitBtn);
      await tester.tap(exitBtn, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(PodScaffoldWidget), findsNothing);
    });
  });

  // ===========================================================================
  // REQUIREMENT 4: CentralUtilityBar Actions & Long-Press
  // ===========================================================================
  group('4. CentralUtilityBar Actions & Symmetrical Wings', () {
    testWidgets('All 7 utility keys are present, distinct, and trigger independent callbacks', (tester) async {
      bool exitTriggered = false;
      bool resetTriggered = false;
      bool settingsTriggered = false;
      bool randomizerTriggered = false;
      bool quickRollTriggered = false;
      bool manaTriggered = false;
      bool historyTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CentralUtilityBar(
                playerCount: 4,
                onExitApp: () => exitTriggered = true,
                onResetGame: () => resetTriggered = true,
                onOpenSettings: () => settingsTriggered = true,
                onOpenRandomizer: () => randomizerTriggered = true,
                onQuickRandomPlayer: () => quickRollTriggered = true,
                onOpenMana: () => manaTriggered = true,
                onOpenHistory: () => historyTriggered = true,
              ),
            ),
          ),
        ),
      );

      // Verify all 7 keys
      expect(find.byKey(const Key('life_counter_exit_button')), findsOneWidget);
      expect(find.byKey(const Key('central_hub_reset_button')), findsOneWidget);
      expect(find.byKey(const Key('central_hub_settings_button')), findsOneWidget);
      expect(find.byKey(const Key('center_hub_button')), findsOneWidget);
      expect(find.byKey(const Key('central_hub_mana_button')), findsOneWidget);
      expect(find.byKey(const Key('central_hub_history_button')), findsOneWidget);
      expect(find.byKey(const Key('central_hub_quick_roll_button')), findsOneWidget);

      // Tap Exit
      await tester.tap(find.byKey(const Key('life_counter_exit_button')));
      expect(exitTriggered, isTrue);

      // Tap Reset
      await tester.tap(find.byKey(const Key('central_hub_reset_button')));
      expect(resetTriggered, isTrue);

      // Tap Settings
      await tester.tap(find.byKey(const Key('central_hub_settings_button')));
      expect(settingsTriggered, isTrue);

      // Tap Mana
      await tester.tap(find.byKey(const Key('central_hub_mana_button')));
      expect(manaTriggered, isTrue);

      // Tap History
      await tester.tap(find.byKey(const Key('central_hub_history_button')));
      expect(historyTriggered, isTrue);

      // Tap Quick Roll
      await tester.tap(find.byKey(const Key('central_hub_quick_roll_button')));
      expect(quickRollTriggered, isTrue);

      // Tap Center Hub
      await tester.tap(find.byKey(const Key('center_hub_button')));
      expect(randomizerTriggered, isTrue);
    });

    testWidgets('Long-pressing CenterHubButton triggers onQuickRandomPlayer', (tester) async {
      bool quickRollCalled = false;
      bool randomizerCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CenterHubButton(
                onPressed: () => randomizerCalled = true,
                onLongPress: () => quickRollCalled = true,
              ),
            ),
          ),
        ),
      );

      await tester.longPress(find.byKey(const Key('center_hub_button')));
      await tester.pump();

      expect(quickRollCalled, isTrue);
      expect(randomizerCalled, isFalse);
    });

    testWidgets('CentralUtilityBar settings badge displays correct player count text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CentralUtilityBar(
                playerCount: 6,
                onOpenSettings: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('6'), findsOneWidget);
    });
  });

  // ===========================================================================
  // REQUIREMENT 5: Lifetap Rounded Card Styling & Card Encapsulation
  // ===========================================================================
  group('5. Lifetap Rounded Card Styling & Invariants', () {
    testWidgets('PlayerQuadrantWidget renders with 4px margin, circular(16) radius, and subtle border', (tester) async {
      const player = PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PlayerQuadrantWidget(
              player: player,
              isTablet: false,
              opponents: [],
            ),
          ),
        ),
      );

      final outerContainerFinder = find.descendant(
        of: find.byType(PlayerQuadrantWidget),
        matching: find.byType(Container),
      ).first;

      final container = tester.widget<Container>(outerContainerFinder);
      expect(container.margin, const EdgeInsets.all(4.0));

      final decoration = container.decoration as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(16.0));
      final border = decoration.border as Border;
      expect(border.top.width, 1.5);
    });

    testWidgets('PlayerQuadrantWidget lethal commander damage triggers redAccent 3.0px border', (tester) async {
      const lethalPlayer = PodPlayerState(
        id: 'p1',
        seatIndex: 0,
        name: 'Alice',
        life: 40,
        commanderDamageTaken: {'p2': 21},
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PlayerQuadrantWidget(
              player: lethalPlayer,
              isTablet: false,
              opponents: [],
            ),
          ),
        ),
      );

      final outerContainerFinder = find.descendant(
        of: find.byType(PlayerQuadrantWidget),
        matching: find.byType(Container),
      ).first;

      final container = tester.widget<Container>(outerContainerFinder);
      final decoration = container.decoration as BoxDecoration;
      final border = decoration.border as Border;
      expect(border.top.color, Colors.redAccent);
      expect(border.top.width, 3.0);
    });

    testWidgets('PodScaffoldWidget canvas background is pure black Color(0xFF000000)', (tester) async {
      final pod = createPod(4);
      await pumpPodWithViewport(tester, state: pod, size: const Size(400, 800));

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.backgroundColor, Colors.black);
    });
  });

  // ===========================================================================
  // REQUIREMENT 6: Extreme Layout Stress & Overflow Immunity
  // ===========================================================================
  group('6. Extreme Layout Stress & Overflow Immunity', () {
    testWidgets('6-Player pod on 320x480 narrow viewport renders with ZERO RenderFlex overflow', (tester) async {
      final pod6P = createPod(6);
      await pumpPodWithViewport(tester, state: pod6P, size: const Size(320, 480));

      for (int i = 1; i <= 6; i++) {
        expect(find.byKey(Key('quadrant_p$i')), findsOneWidget);
      }
      expect(find.byKey(const Key('center_hub_button')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Commander mini-grid with long opponent list renders cleanly without overflow on 360x640', (tester) async {
      final opponents = List.generate(
        5,
        (i) => PodPlayerState(
          id: 'opp_$i',
          seatIndex: i + 1,
          name: 'Long Opponent Name $i',
          life: 40,
        ),
      );

      const player = PodPlayerState(
        id: 'p1',
        seatIndex: 0,
        name: 'Player One With Very Long Commander Title The Archmage',
        life: 40,
        commanderDamageTaken: {'opp_0': 5, 'opp_1': 10, 'opp_2': 15, 'opp_3': 20, 'opp_4': 21},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 180,
              height: 200,
              child: PlayerQuadrantWidget(
                player: player,
                isTablet: false,
                opponents: opponents,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('cmd_mini_grid_p1')), findsOneWidget);
    });
  });
}
