// Copyright (c) 2026 Countr. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/features/life_counter/domain/models/pod_state.dart';
import 'package:countr/features/life_counter/presentation/dialogs/pregame_setup_sheet.dart';
import 'package:countr/features/life_counter/presentation/widgets/pod_scaffold_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  List<PodPlayerState> makePlayers(int count) {
    return List.generate(
      count,
      (i) => PodPlayerState(
        id: 'p$i',
        seatIndex: i,
        name: 'Player ${i + 1}',
        life: 40,
      ),
    );
  }

  Widget testHarness({
    required int playerCount,
    String layoutVariant = 'opposed',
    bool isCameraMode = false,
    String seatingOrientation = 'opposed',
  }) {
    final pod = PodState(
      sessionId: 'test_session',
      format: 'commander',
      startingLife: 40,
      players: makePlayers(playerCount),
    );

    return MaterialApp(
      home: PodScaffoldWidget(
        podState: pod,
        layoutVariant: layoutVariant,
        isCameraMode: isCameraMode,
        seatingOrientation: seatingOrientation,
      ),
    );
  }

  group('Milestone 2: PodLayoutEngine 1P to 6P Geometries & Layout Variants', () {
    testWidgets('1P Solo: Fullscreen upright seat with 0 RotatedBoxes', (tester) async {
      await tester.pumpWidget(testHarness(playerCount: 1));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('quadrant_p0')), findsOneWidget);
      // Solo mode must NOT wrap upright player in RotatedBox
      expect(
        find.ancestor(
          of: find.byKey(const Key('quadrant_p0')),
          matching: find.byType(RotatedBox),
        ),
        findsNothing,
      );
    });

    testWidgets('2P Layout A (Face-to-Face) vs Layout B (Side-by-Side)', (tester) async {
      // 2P Layout A: Top seat p1 has quarterTurns 2, bottom p0 has quarterTurns 0
      await tester.pumpWidget(testHarness(playerCount: 2, layoutVariant: 'A'));
      await tester.pumpAndSettle();

      final p1BoxA = tester.widget<RotatedBox>(
        find.ancestor(
          of: find.byKey(const Key('quadrant_p1')),
          matching: find.byType(RotatedBox),
        ),
      );
      expect(p1BoxA.quarterTurns, equals(2));
      expect(
        find.ancestor(
          of: find.byKey(const Key('quadrant_p0')),
          matching: find.byType(RotatedBox),
        ),
        findsNothing,
      );

      // 2P Layout B: Left seat p0 has quarterTurns 1, right seat p1 has quarterTurns 3
      await tester.pumpWidget(testHarness(playerCount: 2, layoutVariant: 'B'));
      await tester.pumpAndSettle();

      final p0BoxB = tester.widget<RotatedBox>(
        find.ancestor(
          of: find.byKey(const Key('quadrant_p0')),
          matching: find.byType(RotatedBox),
        ),
      );
      final p1BoxB = tester.widget<RotatedBox>(
        find.ancestor(
          of: find.byKey(const Key('quadrant_p1')),
          matching: find.byType(RotatedBox),
        ),
      );
      expect(p0BoxB.quarterTurns, equals(1));
      expect(p1BoxB.quarterTurns, equals(3));
    });

    testWidgets('3P Layout A (Top 1 & 3, Bot 0) vs Layout B (Top 2, Bot 0 & 0)', (tester) async {
      // 3P Layout A: Top-left p1 turns 1, Top-right p2 turns 3, Bot p0 turns 0
      await tester.pumpWidget(testHarness(playerCount: 3, layoutVariant: 'A'));
      await tester.pumpAndSettle();

      final p1A = tester.widget<RotatedBox>(
        find.ancestor(
          of: find.byKey(const Key('quadrant_p1')),
          matching: find.byType(RotatedBox),
        ),
      );
      final p2A = tester.widget<RotatedBox>(
        find.ancestor(
          of: find.byKey(const Key('quadrant_p2')),
          matching: find.byType(RotatedBox),
        ),
      );
      expect(p1A.quarterTurns, equals(1));
      expect(p2A.quarterTurns, equals(3));
      expect(
        find.ancestor(
          of: find.byKey(const Key('quadrant_p0')),
          matching: find.byType(RotatedBox),
        ),
        findsNothing,
      );

      // 3P Layout B: Top p1 turns 2, Bot-left p0 turns 0, Bot-right p2 turns 0
      await tester.pumpWidget(testHarness(playerCount: 3, layoutVariant: 'B'));
      await tester.pumpAndSettle();

      final p1B = tester.widget<RotatedBox>(
        find.ancestor(
          of: find.byKey(const Key('quadrant_p1')),
          matching: find.byType(RotatedBox),
        ),
      );
      expect(p1B.quarterTurns, equals(2));
      expect(
        find.ancestor(
          of: find.byKey(const Key('quadrant_p0')),
          matching: find.byType(RotatedBox),
        ),
        findsNothing,
      );
      expect(
        find.ancestor(
          of: find.byKey(const Key('quadrant_p2')),
          matching: find.byType(RotatedBox),
        ),
        findsNothing,
      );
    });

    testWidgets('4P Layout A (2x2 Grid Side Seating) vs Layout B (Head-of-Table)', (tester) async {
      // 4P Layout A: Left col (p1, p0) turn 1, Right col (p2, p3) turn 3
      await tester.pumpWidget(testHarness(playerCount: 4, layoutVariant: 'A'));
      await tester.pumpAndSettle();

      final p0A = tester.widget<RotatedBox>(
        find.ancestor(
          of: find.byKey(const Key('quadrant_p0')),
          matching: find.byType(RotatedBox),
        ),
      );
      final p1A = tester.widget<RotatedBox>(
        find.ancestor(
          of: find.byKey(const Key('quadrant_p1')),
          matching: find.byType(RotatedBox),
        ),
      );
      final p2A = tester.widget<RotatedBox>(
        find.ancestor(
          of: find.byKey(const Key('quadrant_p2')),
          matching: find.byType(RotatedBox),
        ),
      );
      final p3A = tester.widget<RotatedBox>(
        find.ancestor(
          of: find.byKey(const Key('quadrant_p3')),
          matching: find.byType(RotatedBox),
        ),
      );
      expect(p0A.quarterTurns, equals(1));
      expect(p1A.quarterTurns, equals(1));
      expect(p2A.quarterTurns, equals(3));
      expect(p3A.quarterTurns, equals(3));

      // 4P Layout B: Top p2 turns 2, Mid-left p1 turns 1, Mid-right p3 turns 3, Bot p0 turns 0
      await tester.pumpWidget(testHarness(playerCount: 4, layoutVariant: 'B'));
      await tester.pumpAndSettle();

      final p1B = tester.widget<RotatedBox>(
        find.ancestor(
          of: find.byKey(const Key('quadrant_p1')),
          matching: find.byType(RotatedBox),
        ),
      );
      final p2B = tester.widget<RotatedBox>(
        find.ancestor(
          of: find.byKey(const Key('quadrant_p2')),
          matching: find.byType(RotatedBox),
        ),
      );
      final p3B = tester.widget<RotatedBox>(
        find.ancestor(
          of: find.byKey(const Key('quadrant_p3')),
          matching: find.byType(RotatedBox),
        ),
      );
      expect(p1B.quarterTurns, equals(2));
      expect(p2B.quarterTurns, equals(1));
      expect(p3B.quarterTurns, equals(3));
      expect(
        find.ancestor(
          of: find.byKey(const Key('quadrant_p0')),
          matching: find.byType(RotatedBox),
        ),
        findsNothing,
      );
    });

    testWidgets('5P Layout A (Grid) vs Layout B (Opposed)', (tester) async {
      // 5P Layout A: Top p1(1), p2(3); Mid p3(1), p4(3); Bot p0(0)
      await tester.pumpWidget(testHarness(playerCount: 5, layoutVariant: 'A'));
      await tester.pumpAndSettle();

      final p1A = tester.widget<RotatedBox>(find.ancestor(of: find.byKey(const Key('quadrant_p1')), matching: find.byType(RotatedBox)));
      final p2A = tester.widget<RotatedBox>(find.ancestor(of: find.byKey(const Key('quadrant_p2')), matching: find.byType(RotatedBox)));
      final p3A = tester.widget<RotatedBox>(find.ancestor(of: find.byKey(const Key('quadrant_p3')), matching: find.byType(RotatedBox)));
      final p4A = tester.widget<RotatedBox>(find.ancestor(of: find.byKey(const Key('quadrant_p4')), matching: find.byType(RotatedBox)));
      expect(p1A.quarterTurns, equals(1));
      expect(p2A.quarterTurns, equals(3));
      expect(p3A.quarterTurns, equals(1));
      expect(p4A.quarterTurns, equals(3));
      expect(find.ancestor(of: find.byKey(const Key('quadrant_p0')), matching: find.byType(RotatedBox)), findsNothing);

      // 5P Layout B: Top p1(2), p2(2); Bot p0(0), p3(0), p4(0)
      await tester.pumpWidget(testHarness(playerCount: 5, layoutVariant: 'B'));
      await tester.pumpAndSettle();

      final p1B = tester.widget<RotatedBox>(find.ancestor(of: find.byKey(const Key('quadrant_p1')), matching: find.byType(RotatedBox)));
      final p2B = tester.widget<RotatedBox>(find.ancestor(of: find.byKey(const Key('quadrant_p2')), matching: find.byType(RotatedBox)));
      expect(p1B.quarterTurns, equals(2));
      expect(p2B.quarterTurns, equals(2));
      expect(find.ancestor(of: find.byKey(const Key('quadrant_p0')), matching: find.byType(RotatedBox)), findsNothing);
      expect(find.ancestor(of: find.byKey(const Key('quadrant_p3')), matching: find.byType(RotatedBox)), findsNothing);
      expect(find.ancestor(of: find.byKey(const Key('quadrant_p4')), matching: find.byType(RotatedBox)), findsNothing);
    });

    testWidgets('6P Layout A (2x3 Side Grid) vs Layout B (Head-of-Table)', (tester) async {
      // 6P Layout A: Left col (p1, p3, p0) all turn 1; Right col (p2, p4, p5) all turn 3
      await tester.pumpWidget(testHarness(playerCount: 6, layoutVariant: 'A'));
      await tester.pumpAndSettle();

      final p1A = tester.widget<RotatedBox>(find.ancestor(of: find.byKey(const Key('quadrant_p1')), matching: find.byType(RotatedBox)));
      final p3A = tester.widget<RotatedBox>(find.ancestor(of: find.byKey(const Key('quadrant_p3')), matching: find.byType(RotatedBox)));
      final p0A = tester.widget<RotatedBox>(find.ancestor(of: find.byKey(const Key('quadrant_p0')), matching: find.byType(RotatedBox)));
      final p2A = tester.widget<RotatedBox>(find.ancestor(of: find.byKey(const Key('quadrant_p2')), matching: find.byType(RotatedBox)));
      final p4A = tester.widget<RotatedBox>(find.ancestor(of: find.byKey(const Key('quadrant_p4')), matching: find.byType(RotatedBox)));
      final p5A = tester.widget<RotatedBox>(find.ancestor(of: find.byKey(const Key('quadrant_p5')), matching: find.byType(RotatedBox)));
      expect(p1A.quarterTurns, equals(1));
      expect(p3A.quarterTurns, equals(1));
      expect(p0A.quarterTurns, equals(1));
      expect(p2A.quarterTurns, equals(3));
      expect(p4A.quarterTurns, equals(3));
      expect(p5A.quarterTurns, equals(3));

      // 6P Layout B: Top p1 turns 2, Mid 2x2 (p2, p4 turn 1, p3, p5 turn 3), Bot p0 turns 0
      await tester.pumpWidget(testHarness(playerCount: 6, layoutVariant: 'B'));
      await tester.pumpAndSettle();

      final p1B = tester.widget<RotatedBox>(find.ancestor(of: find.byKey(const Key('quadrant_p1')), matching: find.byType(RotatedBox)));
      final p2B = tester.widget<RotatedBox>(find.ancestor(of: find.byKey(const Key('quadrant_p2')), matching: find.byType(RotatedBox)));
      final p3B = tester.widget<RotatedBox>(find.ancestor(of: find.byKey(const Key('quadrant_p3')), matching: find.byType(RotatedBox)));
      final p4B = tester.widget<RotatedBox>(find.ancestor(of: find.byKey(const Key('quadrant_p4')), matching: find.byType(RotatedBox)));
      final p5B = tester.widget<RotatedBox>(find.ancestor(of: find.byKey(const Key('quadrant_p5')), matching: find.byType(RotatedBox)));
      expect(p1B.quarterTurns, equals(2));
      expect(p2B.quarterTurns, equals(1));
      expect(p3B.quarterTurns, equals(3));
      expect(p4B.quarterTurns, equals(1));
      expect(p5B.quarterTurns, equals(3));
      expect(find.ancestor(of: find.byKey(const Key('quadrant_p0')), matching: find.byType(RotatedBox)), findsNothing);
    });
  });

  group('Milestone 2: Camera Mode (Overhead Streaming) Bypass', () {
    for (int count = 1; count <= 6; count++) {
      testWidgets('Camera Mode for ${count}P bypasses all RotatedBoxes', (tester) async {
        await tester.pumpWidget(testHarness(
          playerCount: count,
          layoutVariant: 'A',
          isCameraMode: true,
        ));
        await tester.pumpAndSettle();

        // When isCameraMode is true, NO RotatedBox widgets should exist for player seats
        expect(find.byType(RotatedBox), findsNothing);
      });
    }
  });

  group('Milestone 2: PregameSetupSheet 1P Solo & Camera Mode Preferences', () {
    testWidgets('1P Solo mode button is selectable and updates player count', (tester) async {
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

      final soloBtn = find.byKey(const Key('player_count_btn_1'));
      expect(soloBtn, findsOneWidget);
      expect(find.text('1P'), findsOneWidget);

      await tester.tap(soloBtn);
      await tester.pumpAndSettle();

      expect(find.text('Solo'), findsWidgets);
    });

    testWidgets('Camera Mode Switch toggles and persists state', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: PregameSetupSheet(initialCameraMode: false),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final switchFinder = find.byKey(const Key('pregame_camera_mode_switch'));
      expect(switchFinder, findsOneWidget);

      expect(PregameSetupSheet.lastCameraMode, isFalse);
      expect(container.read(podCameraModeProvider), isFalse);

      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(PregameSetupSheet.lastCameraMode, isTrue);

      // Hit Start Match button
      await tester.tap(find.byKey(const Key('start_match_button')));
      await tester.pumpAndSettle();

      expect(PregameSetupSheet.lastCameraMode, isTrue);
      expect(container.read(podCameraModeProvider), isTrue);
    });
  });
}
