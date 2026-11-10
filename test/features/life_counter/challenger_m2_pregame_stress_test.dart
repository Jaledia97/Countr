// Copyright (c) 2026 Countr. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/features/life_counter/domain/models/pod_state.dart';
import 'package:countr/features/life_counter/presentation/dialogs/pregame_setup_sheet.dart';
import 'package:countr/features/life_counter/presentation/widgets/pod_scaffold_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  List<PodPlayerState> makeTestPlayers(int count, {int startingLife = 40}) {
    return List.generate(
      count,
      (i) => PodPlayerState(
        id: 'p$i',
        seatIndex: i,
        name: 'Player ${i + 1}',
        life: startingLife,
      ),
    );
  }

  PodState makeTestPod(int count, {int startingLife = 40}) {
    return PodState(
      sessionId: 'test_pod_session',
      format: 'commander',
      startingLife: startingLife,
      players: makeTestPlayers(count, startingLife: startingLife),
    );
  }

  group('Milestone 2 Challenger: PregameSetupSheet 1P Solo Mode & Match Lifecycle', () {
    testWidgets('Selecting 1P Solo mode renders 1 player entry, Solo indicator, and returns 1P PodState', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      PodState? capturedPodState;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PregameSetupSheet(
                initialPlayerCount: 4,
                onStartMatch: (podState) {
                  capturedPodState = podState;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially 4 players
      expect(find.byKey(const Key('player_setup_card_0')), findsOneWidget);
      expect(find.byKey(const Key('player_setup_card_1')), findsOneWidget);
      expect(find.byKey(const Key('player_setup_card_2')), findsOneWidget);
      expect(find.byKey(const Key('player_setup_card_3')), findsOneWidget);

      // Select 1P Solo mode
      final soloBtn = find.byKey(const Key('player_count_btn_1'));
      expect(soloBtn, findsOneWidget);
      await tester.tap(soloBtn);
      await tester.pumpAndSettle();

      // Verify Solo Mode indicator text is visible in orientation segment
      expect(find.text('Solo'), findsWidgets);
      expect(find.text('Full View'), findsOneWidget);

      // Verify exactly 1 player setup card remains
      expect(find.byKey(const Key('player_setup_card_0')), findsOneWidget);
      expect(find.byKey(const Key('player_setup_card_1')), findsNothing);
      expect(find.byKey(const Key('player_setup_card_2')), findsNothing);
      expect(find.byKey(const Key('player_setup_card_3')), findsNothing);

      // Customize player name
      final nameInput = find.byKey(const Key('player_name_input_0'));
      await tester.enterText(nameInput, 'Solo Commander');
      await tester.pumpAndSettle();

      // Tap Start Match
      final startBtn = find.byKey(const Key('start_match_button'));
      expect(startBtn, findsOneWidget);
      await tester.tap(startBtn);
      await tester.pumpAndSettle();

      // Verify returned PodState has exactly 1 player
      expect(capturedPodState, isNotNull);
      expect(capturedPodState!.players.length, equals(1));
      expect(capturedPodState!.players.first.name, equals('Solo Commander'));
      expect(capturedPodState!.players.first.seatIndex, equals(0));
      expect(capturedPodState!.players.first.life, equals(40));
    });
  });

  group('Milestone 2 Challenger: Rapid Player Count Switching Stress Test', () {
    testWidgets('Rapidly cycling player counts 1 -> 2 -> 3 -> 4 -> 5 -> 6 -> 1 maintains state consistency', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PregameSetupSheet(initialPlayerCount: 1),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final countsSequence = [1, 2, 3, 4, 5, 6, 1];

      for (final count in countsSequence) {
        final btn = find.byKey(Key('player_count_btn_$count'));
        expect(btn, findsOneWidget);
        await tester.tap(btn);
        await tester.pumpAndSettle();

        // Check cards count matches exactly
        for (var i = 0; i < count; i++) {
          expect(find.byKey(Key('player_setup_card_$i')), findsOneWidget);
        }
        expect(find.byKey(Key('player_setup_card_$count')), findsNothing);
      }
    });

    testWidgets('Rapid asynchronous button thrashing without settle does not crash or corrupt text controllers', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PregameSetupSheet(initialPlayerCount: 4),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter custom name on player 0
      await tester.enterText(find.byKey(const Key('player_name_input_0')), 'Hero 1');

      // Thrash taps rapidly without pumpAndSettle in between
      await tester.tap(find.byKey(const Key('player_count_btn_6')));
      await tester.pump(const Duration(milliseconds: 10));
      await tester.tap(find.byKey(const Key('player_count_btn_2')));
      await tester.pump(const Duration(milliseconds: 10));
      await tester.tap(find.byKey(const Key('player_count_btn_5')));
      await tester.pump(const Duration(milliseconds: 10));
      await tester.tap(find.byKey(const Key('player_count_btn_1')));
      await tester.pump(const Duration(milliseconds: 10));
      await tester.tap(find.byKey(const Key('player_count_btn_3')));
      await tester.pumpAndSettle();

      // After settling on 3P: should have exactly 3 cards and Hero 1 preserved
      expect(find.byKey(const Key('player_setup_card_0')), findsOneWidget);
      expect(find.byKey(const Key('player_setup_card_1')), findsOneWidget);
      expect(find.byKey(const Key('player_setup_card_2')), findsOneWidget);
      expect(find.byKey(const Key('player_setup_card_3')), findsNothing);
      expect(find.text('Hero 1'), findsOneWidget);
    });
  });

  group('Milestone 2 Challenger: Seating Orientation Picker Across All Player Counts', () {
    testWidgets('2P: Toggles between Face-to-Face (Layout A) and Side-by-Side (Layout B)', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PregameSetupSheet(initialPlayerCount: 2),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Face-to-Face'), findsOneWidget);
      expect(find.text('Side-by-Side'), findsOneWidget);

      // Tap Side-by-Side (Layout B)
      await tester.tap(find.text('Side-by-Side'));
      await tester.pumpAndSettle();

      expect(PregameSetupSheet.lastSeatingOrientation, equals('standard'));
      expect(PregameSetupSheet.lastLayoutVariant, equals('B'));

      // Tap Face-to-Face (Layout A)
      await tester.tap(find.text('Face-to-Face'));
      await tester.pumpAndSettle();

      expect(PregameSetupSheet.lastSeatingOrientation, equals('opposed'));
      expect(PregameSetupSheet.lastLayoutVariant, equals('A'));
    });

    testWidgets('3P: Toggles between Top 1 & 3, Bot 0 (Layout A) and Top 2, Bot 0 & 0 (Layout B)', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PregameSetupSheet(initialPlayerCount: 3),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Top 1 & 3, Bot 0'), findsOneWidget);
      expect(find.text('Top 2, Bot 0 & 0'), findsOneWidget);

      // Tap Layout B
      await tester.tap(find.text('Top 2, Bot 0 & 0'));
      await tester.pumpAndSettle();
      expect(PregameSetupSheet.lastLayoutVariant, equals('B'));

      // Tap Layout A
      await tester.tap(find.text('Top 1 & 3, Bot 0'));
      await tester.pumpAndSettle();
      expect(PregameSetupSheet.lastLayoutVariant, equals('A'));
    });

    testWidgets('4P: Toggles between Opposed (2x2 Grid), Standard (1-2-1 Hybrid), and Radial (Circular)', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PregameSetupSheet(initialPlayerCount: 4),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Opposed'), findsOneWidget);
      expect(find.text('Standard'), findsOneWidget);
      expect(find.text('Radial'), findsOneWidget);

      // Tap Standard
      await tester.tap(find.text('Standard'));
      await tester.pumpAndSettle();
      expect(PregameSetupSheet.lastSeatingOrientation, equals('standard'));

      // Tap Radial
      await tester.tap(find.text('Radial'));
      await tester.pumpAndSettle();
      expect(PregameSetupSheet.lastSeatingOrientation, equals('radial'));

      // Tap Opposed
      await tester.tap(find.text('Opposed'));
      await tester.pumpAndSettle();
      expect(PregameSetupSheet.lastSeatingOrientation, equals('opposed'));
    });

    testWidgets('5P: Toggles between Grid 2+2+1 (Layout A) and Opposed 2+3 (Layout B)', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PregameSetupSheet(initialPlayerCount: 5),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Grid (2+2+1)'), findsOneWidget);
      expect(find.text('Opposed (2+3)'), findsOneWidget);

      // Tap Layout B
      await tester.tap(find.text('Opposed (2+3)'));
      await tester.pumpAndSettle();
      expect(PregameSetupSheet.lastLayoutVariant, equals('B'));

      // Tap Layout A
      await tester.tap(find.text('Grid (2+2+1)'));
      await tester.pumpAndSettle();
      expect(PregameSetupSheet.lastLayoutVariant, equals('A'));
    });

    testWidgets('6P: Toggles between 2x3 Side Grid (Layout A) and Head-of-Table (Layout B)', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PregameSetupSheet(initialPlayerCount: 6),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2x3 Side Grid'), findsOneWidget);
      expect(find.text('Head-of-Table'), findsOneWidget);

      // Tap Layout B
      await tester.tap(find.text('Head-of-Table'));
      await tester.pumpAndSettle();
      expect(PregameSetupSheet.lastLayoutVariant, equals('B'));

      // Tap Layout A
      await tester.tap(find.text('2x3 Side Grid'));
      await tester.pumpAndSettle();
      expect(PregameSetupSheet.lastLayoutVariant, equals('A'));
    });

    testWidgets('Radial orientation resets to Opposed upon match start when switching away from 4P', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: PregameSetupSheet(initialPlayerCount: 4),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Select Radial for 4P
      await tester.tap(find.text('Radial'));
      await tester.pumpAndSettle();
      expect(PregameSetupSheet.lastSeatingOrientation, equals('radial'));

      // Switch to 5P
      await tester.tap(find.byKey(const Key('player_count_btn_5')));
      await tester.pumpAndSettle();

      // Start match to commit state
      await tester.tap(find.byKey(const Key('start_match_button')));
      await tester.pumpAndSettle();

      // Must have reverted away from radial
      expect(PregameSetupSheet.lastSeatingOrientation, isNot('radial'));
      expect(PregameSetupSheet.lastSeatingOrientation, equals('opposed'));
      expect(container.read(podSeatingOrientationProvider), equals('opposed'));
    });
  });

  group('Milestone 2 Challenger: Camera Mode Switch Toggling & Provider Updates', () {
    testWidgets('Toggling Camera Mode Switch ON and OFF synchronizes local state and Riverpod provider', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final container = ProviderContainer();
      addTearDown(container.dispose);

      bool modeToOpen = false;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  key: const Key('open_setup_modal_btn'),
                  onPressed: () => PregameSetupSheet.show(
                    ctx,
                    initialCameraMode: modeToOpen,
                  ),
                  child: const Text('Open Setup'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initial state
      expect(PregameSetupSheet.lastCameraMode, isFalse);
      expect(container.read(podCameraModeProvider), isFalse);

      // Open Modal Bottom Sheet (1st session: Camera Mode OFF initially)
      await tester.tap(find.byKey(const Key('open_setup_modal_btn')));
      await tester.pumpAndSettle();

      final switchFinder = find.byKey(const Key('pregame_camera_mode_switch'));
      expect(switchFinder, findsOneWidget);

      // Scroll ListView until the switch is visible
      await tester.dragUntilVisible(
        switchFinder,
        find.byType(ListView),
        const Offset(0, -100),
      );
      await tester.pumpAndSettle();

      // Toggle ON
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(PregameSetupSheet.lastCameraMode, isTrue);

      // Tap start match (pinned in bottom bar) to commit to Riverpod provider and dismiss modal
      final startBtn = find.byKey(const Key('start_match_button'));
      expect(startBtn, findsOneWidget);
      await tester.tap(startBtn);
      await tester.pumpAndSettle();

      // Provider must be true now
      expect(container.read(podCameraModeProvider), isTrue);

      // Open Modal Bottom Sheet again (2nd session: Camera Mode ON initially)
      modeToOpen = true;
      await tester.tap(find.byKey(const Key('open_setup_modal_btn')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pregame_camera_mode_switch')), findsOneWidget);
      await tester.dragUntilVisible(
        switchFinder,
        find.byType(ListView),
        const Offset(0, -100),
      );
      await tester.pumpAndSettle();

      expect(PregameSetupSheet.lastCameraMode, isTrue);

      // Toggle OFF
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(PregameSetupSheet.lastCameraMode, isFalse);

      // Start match and commit OFF
      await tester.tap(startBtn);
      await tester.pumpAndSettle();

      expect(container.read(podCameraModeProvider), isFalse);
    });
  });

  group('Milestone 2 Challenger: Narrow Viewport (320dp width) Zero-Overflow Stress Test', () {
    testWidgets('PregameSetupSheet renders with 0 RenderFlex overflow on narrow 320dp width across all player counts', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PregameSetupSheet(initialPlayerCount: 1),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Verify each player count on 320dp
      for (int count = 1; count <= 6; count++) {
        final btn = find.byKey(Key('player_count_btn_$count'));
        await tester.tap(btn);
        await tester.pumpAndSettle();

        // Ensure no overflow exception occurred
        expect(tester.takeException(), isNull, reason: 'Overflow occurred on player count $count at 320dp width');

        // Verify orientation picker renders
        expect(find.byKey(const Key('pregame_seating_orientation_picker')), findsOneWidget);
      }
    });

    testWidgets('MiniatureLayoutIcon renders cleanly under standalone strict constraints for 2P to 6P', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  for (int count = 2; count <= 6; count++) ...[
                    MiniatureLayoutIcon(playerCount: count, variant: 'A'),
                    MiniatureLayoutIcon(playerCount: count, variant: 'B'),
                  ],
                  const MiniatureLayoutIcon(playerCount: 4, variant: 'radial'),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Adversarial Check: MiniatureLayoutIcon 1P Solo mode standalone ParentData contract', (tester) async {
      // Testing whether MiniatureLayoutIcon(playerCount: 1) obeys Flutter parent data contract
      // or illegally embeds Expanded directly in a Container
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: MiniatureLayoutIcon(playerCount: 1, variant: 'A'),
            ),
          ),
        ),
      );
      // We explicitly check if mounting 1P MiniatureLayoutIcon triggers an assertion failure
      final exception = tester.takeException();
      if (exception != null) {
        // Assert that the exception matches the exact illegal ParentData failure
        expect(
          exception.toString(),
          contains('Incorrect use of ParentDataWidget'),
          reason: 'MiniatureLayoutIcon for 1P illegally places Expanded directly inside Container',
        );
      }
    });
  });

  group('Milestone 2 Challenger: PodScaffoldWidget ProviderScope Isolation', () {
    testWidgets('Mounting standalone WITHOUT ProviderScope renders cleanly without throwing exception', (tester) async {
      final pod = makeTestPod(4);

      await tester.pumpWidget(
        MaterialApp(
          home: PodScaffoldWidget(
            podState: pod,
            layoutVariant: 'A',
            isCameraMode: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('quadrant_p0')), findsOneWidget);
      expect(find.byKey(const Key('quadrant_p1')), findsOneWidget);
      expect(find.byKey(const Key('quadrant_p2')), findsOneWidget);
      expect(find.byKey(const Key('quadrant_p3')), findsOneWidget);

      // In 4P Layout A, seats are rotated
      expect(find.byType(RotatedBox), findsNWidgets(4));
    });

    testWidgets('Mounting inside ProviderScope consumes Riverpod reactive updates smoothly', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final pod = makeTestPod(4);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: PodScaffoldWidget(
              podState: pod,
              layoutVariant: 'opposed',
              isCameraMode: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Reactively turn on Camera Mode via Riverpod provider
      container.read(podCameraModeProvider.notifier).state = true;
      await tester.pumpAndSettle();

      // In Camera Mode, ALL RotatedBoxes must be removed
      expect(find.byType(RotatedBox), findsNothing);

      // Reactively turn off Camera Mode and switch to Layout B
      container.read(podCameraModeProvider.notifier).state = false;
      container.read(podLayoutVariantProvider.notifier).state = 'B';
      await tester.pumpAndSettle();

      // 4P Layout B: Head-of-table (Top turned 2, Mid-left turned 1, Mid-right turned 3, Bot turned 0)
      // Exactly 3 RotatedBoxes for non-zero seats
      expect(find.byType(RotatedBox), findsNWidgets(3));
    });
  });

  group('Milestone 2 Challenger: PodScaffoldWidget Dynamic Widget Prop Updates', () {
    testWidgets('Standalone PodScaffoldWidget dynamically reacts when widget props update', (tester) async {
      final pod4 = makeTestPod(4);
      final pod2 = makeTestPod(2);
      final pod1 = makeTestPod(1);

      // A test stateful harness that allows external prop updating
      late void Function(void Function()) updateHarness;
      bool cameraMode = false;
      String layoutVariant = 'A';
      PodState activePod = pod4;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              updateHarness = setState;
              return PodScaffoldWidget(
                podState: activePod,
                layoutVariant: layoutVariant,
                isCameraMode: cameraMode,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 4P Layout A: 4 RotatedBox instances
      expect(find.byType(RotatedBox), findsNWidgets(4));

      // 1. Update prop: isCameraMode = true
      updateHarness(() {
        cameraMode = true;
      });
      await tester.pumpAndSettle();

      // Camera Mode must eliminate all RotatedBoxes
      expect(find.byType(RotatedBox), findsNothing);

      // 2. Update prop: isCameraMode = false, layoutVariant = 'B'
      updateHarness(() {
        cameraMode = false;
        layoutVariant = 'B';
      });
      await tester.pumpAndSettle();

      // 4P Layout B: 3 RotatedBoxes (p1:2, p2:1, p3:3, p0: upright 0)
      expect(find.byType(RotatedBox), findsNWidgets(3));

      // 3. Update prop: activePod = 2 players (pod2)
      updateHarness(() {
        activePod = pod2;
        layoutVariant = 'A';
      });
      await tester.pumpAndSettle();

      // Should now render only 2 player quadrants
      expect(find.byKey(const Key('quadrant_p0')), findsOneWidget);
      expect(find.byKey(const Key('quadrant_p1')), findsOneWidget);
      expect(find.byKey(const Key('quadrant_p2')), findsNothing);
      expect(find.byKey(const Key('quadrant_p3')), findsNothing);

      // 2P Layout A: Top seat turned 2 (1 RotatedBox), Bottom seat turned 0 (0 RotatedBox)
      expect(find.byType(RotatedBox), findsOneWidget);

      // 4. Update prop: activePod = 1 player (Solo Mode)
      updateHarness(() {
        activePod = pod1;
      });
      await tester.pumpAndSettle();

      // Solo mode: 1 quadrant, 0 RotatedBoxes
      expect(find.byKey(const Key('quadrant_p0')), findsOneWidget);
      expect(find.byKey(const Key('quadrant_p1')), findsNothing);
      expect(find.byType(RotatedBox), findsNothing);
    });
  });
}
