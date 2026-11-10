// Copyright (c) 2026 Countr. All rights reserved.
// Challenger M2 Empirical Adversarial Stress Test Suite
// Requirements Under Test (ORIGINAL_REQUEST.md - R2):
// 1. All seating layouts and orientations for 1P to 6P (Layout A & Layout B)
// 2. Exact RotatedBox counts and quarterTurns geometry:
//    - 1P Solo: 0 RotatedBoxes (upright 0°)
//    - 2P Layout A (Face-to-Face): 1 RotatedBox (Top p1: 2, Bot p0: 0)
//    - 2P Layout B (Side-by-Side): 2 RotatedBoxes (Left p0: 1, Right p1: 3)
//    - 3P Layout A (Side-by-Side + Head): 2 RotatedBoxes (Top-L p1: 1, Top-R p2: 3, Bot p0: 0)
//    - 3P Layout B (Opposed): 1 RotatedBox (Top p1: 2, Bot-L p0: 0, Bot-R p2: 0)
//    - 4P Layout A (2x2 Grid Side): 4 RotatedBoxes (L p1: 1, p0: 1; R p2: 3, p3: 3)
//    - 4P Layout B (Head-of-Table): 3 RotatedBoxes (Top p1: 2, Mid-L p2: 1, Mid-R p3: 3, Bot p0: 0)
//    - 5P Layout A (Grid): 4 RotatedBoxes (Top p1: 1, p2: 3; Mid p3: 1, p4: 3; Bot p0: 0)
//    - 5P Layout B (Opposed): 2 RotatedBoxes (Top p1: 2, p2: 2; Bot p0: 0, p3: 0, p4: 0)
//    - 6P Layout A (2x3 Side Grid): 6 RotatedBoxes (Left col: p1: 1, p3: 1, p0: 1; Right col: p2: 3, p4: 3, p5: 3)
//    - 6P Layout B (Head-of-Table): 5 RotatedBoxes (Top p1: 2; Mid 2x2: p2: 1, p3: 3, p4: 1, p5: 3; Bot p0: 0)
// 3. Camera Mode override: ALL 1P-6P configs (Layout A & B) must have EXACTLY 0 RotatedBoxes.
// 4. Multi-viewport zero-RenderFlex-overflow stress:
//    - Small phone (320x568)
//    - Standard phone (390x844)
//    - Landscape phone (844x390)
//    - Tablet portrait (800x1280)
//    - Tablet landscape (1280x800)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/features/life_counter/domain/models/pod_state.dart';
import 'package:countr/features/life_counter/presentation/widgets/pod_scaffold_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  List<PodPlayerState> createPlayers(int count) {
    return List.generate(
      count,
      (i) => PodPlayerState(
        id: 'p$i',
        seatIndex: i,
        name: 'Player ${i + 1}',
        life: 40,
        commanderDamageTaken: i > 0 ? {'p0': 3 * i} : const {},
      ),
    );
  }

  Widget createPodHarness({
    required int playerCount,
    required String layoutVariant,
    bool isCameraMode = false,
  }) {
    final pod = PodState(
      sessionId: 'challenger_m2_${playerCount}p_$layoutVariant',
      format: 'commander',
      startingLife: 40,
      players: createPlayers(playerCount),
    );

    return ProviderScope(
      child: MaterialApp(
        home: PodScaffoldWidget(
          podState: pod,
          layoutVariant: layoutVariant,
          isCameraMode: isCameraMode,
        ),
      ),
    );
  }

  // ===========================================================================
  // GROUP 1: Exact RotatedBox Counts & QuarterTurns Oracle (1P to 6P, Layout A & B)
  // ===========================================================================
  group('1. Seating Layouts & Orientations Oracle (Layout A & Layout B)', () {
    testWidgets('1P: Solo layout has 0 RotatedBoxes for both Layout A and Layout B', (tester) async {
      for (final variant in ['A', 'B']) {
        await tester.pumpWidget(createPodHarness(playerCount: 1, layoutVariant: variant));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('quadrant_p0')), findsOneWidget);
        expect(find.byType(RotatedBox), findsNothing,
            reason: '1P Solo in Layout $variant must not have any RotatedBox wrappers');
      }
    });

    testWidgets('2P Layout A (Face-to-Face): Top p1 (quarterTurns: 2), Bot p0 (0 RotatedBox)', (tester) async {
      await tester.pumpWidget(createPodHarness(playerCount: 2, layoutVariant: 'A'));
      await tester.pumpAndSettle();

      expect(find.byType(RotatedBox), findsNWidgets(1),
          reason: '2P Layout A should have exactly 1 RotatedBox for the inverted top seat');

      final p1Box = tester.widget<RotatedBox>(
        find.ancestor(of: find.byKey(const Key('quadrant_p1')), matching: find.byType(RotatedBox)),
      );
      expect(p1Box.quarterTurns, equals(2));

      expect(
        find.ancestor(of: find.byKey(const Key('quadrant_p0')), matching: find.byType(RotatedBox)),
        findsNothing,
      );
    });

    testWidgets('2P Layout B (Side-by-Side): Left p0 (quarterTurns: 1), Right p1 (quarterTurns: 3)', (tester) async {
      await tester.pumpWidget(createPodHarness(playerCount: 2, layoutVariant: 'B'));
      await tester.pumpAndSettle();

      expect(find.byType(RotatedBox), findsNWidgets(2),
          reason: '2P Layout B should have exactly 2 RotatedBoxes');

      final p0Box = tester.widget<RotatedBox>(
        find.ancestor(of: find.byKey(const Key('quadrant_p0')), matching: find.byType(RotatedBox)),
      );
      final p1Box = tester.widget<RotatedBox>(
        find.ancestor(of: find.byKey(const Key('quadrant_p1')), matching: find.byType(RotatedBox)),
      );
      expect(p0Box.quarterTurns, equals(1));
      expect(p1Box.quarterTurns, equals(3));
    });

    testWidgets('3P Layout A: Top-L p1 (1), Top-R p2 (3), Bot p0 (0) -> 2 RotatedBoxes total', (tester) async {
      await tester.pumpWidget(createPodHarness(playerCount: 3, layoutVariant: 'A'));
      await tester.pumpAndSettle();

      expect(find.byType(RotatedBox), findsNWidgets(2),
          reason: '3P Layout A should have exactly 2 RotatedBoxes');

      final p1Box = tester.widget<RotatedBox>(
        find.ancestor(of: find.byKey(const Key('quadrant_p1')), matching: find.byType(RotatedBox)),
      );
      final p2Box = tester.widget<RotatedBox>(
        find.ancestor(of: find.byKey(const Key('quadrant_p2')), matching: find.byType(RotatedBox)),
      );
      expect(p1Box.quarterTurns, equals(1));
      expect(p2Box.quarterTurns, equals(3));

      expect(
        find.ancestor(of: find.byKey(const Key('quadrant_p0')), matching: find.byType(RotatedBox)),
        findsNothing,
      );
    });

    testWidgets('3P Layout B: Top p1 (2), Bot-L p0 (0), Bot-R p2 (0) -> 1 RotatedBox total', (tester) async {
      await tester.pumpWidget(createPodHarness(playerCount: 3, layoutVariant: 'B'));
      await tester.pumpAndSettle();

      expect(find.byType(RotatedBox), findsNWidgets(1),
          reason: '3P Layout B should have exactly 1 RotatedBox');

      final p1Box = tester.widget<RotatedBox>(
        find.ancestor(of: find.byKey(const Key('quadrant_p1')), matching: find.byType(RotatedBox)),
      );
      expect(p1Box.quarterTurns, equals(2));

      expect(
        find.ancestor(of: find.byKey(const Key('quadrant_p0')), matching: find.byType(RotatedBox)),
        findsNothing,
      );
      expect(
        find.ancestor(of: find.byKey(const Key('quadrant_p2')), matching: find.byType(RotatedBox)),
        findsNothing,
      );
    });

    testWidgets('4P Layout A (2x2 Grid Side): p1 (1), p0 (1), p2 (3), p3 (3) -> 4 RotatedBoxes total', (tester) async {
      await tester.pumpWidget(createPodHarness(playerCount: 4, layoutVariant: 'A'));
      await tester.pumpAndSettle();

      expect(find.byType(RotatedBox), findsNWidgets(4),
          reason: '4P Layout A should have exactly 4 RotatedBoxes');

      final p0Box = tester.widget<RotatedBox>(find.ancestor(of: find.byKey(const Key('quadrant_p0')), matching: find.byType(RotatedBox)));
      final p1Box = tester.widget<RotatedBox>(find.ancestor(of: find.byKey(const Key('quadrant_p1')), matching: find.byType(RotatedBox)));
      final p2Box = tester.widget<RotatedBox>(find.ancestor(of: find.byKey(const Key('quadrant_p2')), matching: find.byType(RotatedBox)));
      final p3Box = tester.widget<RotatedBox>(find.ancestor(of: find.byKey(const Key('quadrant_p3')), matching: find.byType(RotatedBox)));

      expect(p1Box.quarterTurns, equals(1));
      expect(p0Box.quarterTurns, equals(1));
      expect(p2Box.quarterTurns, equals(3));
      expect(p3Box.quarterTurns, equals(3));
    });

    testWidgets('4P Layout B (Head-of-Table): Top p1 (2), Mid-L p2 (1), Mid-R p3 (3), Bot p0 (0) -> 3 RotatedBoxes total', (tester) async {
      await tester.pumpWidget(createPodHarness(playerCount: 4, layoutVariant: 'B'));
      await tester.pumpAndSettle();

      expect(find.byType(RotatedBox), findsNWidgets(3),
          reason: '4P Layout B should have exactly 3 RotatedBoxes');

      final p1Box = tester.widget<RotatedBox>(find.ancestor(of: find.byKey(const Key('quadrant_p1')), matching: find.byType(RotatedBox)));
      final p2Box = tester.widget<RotatedBox>(find.ancestor(of: find.byKey(const Key('quadrant_p2')), matching: find.byType(RotatedBox)));
      final p3Box = tester.widget<RotatedBox>(find.ancestor(of: find.byKey(const Key('quadrant_p3')), matching: find.byType(RotatedBox)));

      expect(p1Box.quarterTurns, equals(2));
      expect(p2Box.quarterTurns, equals(1));
      expect(p3Box.quarterTurns, equals(3));

      expect(
        find.ancestor(of: find.byKey(const Key('quadrant_p0')), matching: find.byType(RotatedBox)),
        findsNothing,
      );
    });

    testWidgets('5P Layout A (Grid): Top p1 (1), p2 (3); Mid p3 (1), p4 (3); Bot p0 (0) -> 4 RotatedBoxes total', (tester) async {
      await tester.pumpWidget(createPodHarness(playerCount: 5, layoutVariant: 'A'));
      await tester.pumpAndSettle();

      expect(find.byType(RotatedBox), findsNWidgets(4),
          reason: '5P Layout A should have exactly 4 RotatedBoxes');

      final p1Box = tester.widget<RotatedBox>(find.ancestor(of: find.byKey(const Key('quadrant_p1')), matching: find.byType(RotatedBox)));
      final p2Box = tester.widget<RotatedBox>(find.ancestor(of: find.byKey(const Key('quadrant_p2')), matching: find.byType(RotatedBox)));
      final p3Box = tester.widget<RotatedBox>(find.ancestor(of: find.byKey(const Key('quadrant_p3')), matching: find.byType(RotatedBox)));
      final p4Box = tester.widget<RotatedBox>(find.ancestor(of: find.byKey(const Key('quadrant_p4')), matching: find.byType(RotatedBox)));

      expect(p1Box.quarterTurns, equals(1));
      expect(p2Box.quarterTurns, equals(3));
      expect(p3Box.quarterTurns, equals(1));
      expect(p4Box.quarterTurns, equals(3));

      expect(
        find.ancestor(of: find.byKey(const Key('quadrant_p0')), matching: find.byType(RotatedBox)),
        findsNothing,
      );
    });

    testWidgets('5P Layout B (Opposed): Top p1 (2), p2 (2); Bot p0 (0), p3 (0), p4 (0) -> 2 RotatedBoxes total', (tester) async {
      await tester.pumpWidget(createPodHarness(playerCount: 5, layoutVariant: 'B'));
      await tester.pumpAndSettle();

      expect(find.byType(RotatedBox), findsNWidgets(2),
          reason: '5P Layout B should have exactly 2 RotatedBoxes');

      final p1Box = tester.widget<RotatedBox>(find.ancestor(of: find.byKey(const Key('quadrant_p1')), matching: find.byType(RotatedBox)));
      final p2Box = tester.widget<RotatedBox>(find.ancestor(of: find.byKey(const Key('quadrant_p2')), matching: find.byType(RotatedBox)));

      expect(p1Box.quarterTurns, equals(2));
      expect(p2Box.quarterTurns, equals(2));

      expect(find.ancestor(of: find.byKey(const Key('quadrant_p0')), matching: find.byType(RotatedBox)), findsNothing);
      expect(find.ancestor(of: find.byKey(const Key('quadrant_p3')), matching: find.byType(RotatedBox)), findsNothing);
      expect(find.ancestor(of: find.byKey(const Key('quadrant_p4')), matching: find.byType(RotatedBox)), findsNothing);
    });

    testWidgets('6P Layout A (2x3 Side Grid): Left col p1, p3, p0 (1); Right col p2, p4, p5 (3) -> 6 RotatedBoxes total', (tester) async {
      await tester.pumpWidget(createPodHarness(playerCount: 6, layoutVariant: 'A'));
      await tester.pumpAndSettle();

      expect(find.byType(RotatedBox), findsNWidgets(6),
          reason: '6P Layout A should have exactly 6 RotatedBoxes');

      final p1Box = tester.widget<RotatedBox>(find.ancestor(of: find.byKey(const Key('quadrant_p1')), matching: find.byType(RotatedBox)));
      final p3Box = tester.widget<RotatedBox>(find.ancestor(of: find.byKey(const Key('quadrant_p3')), matching: find.byType(RotatedBox)));
      final p0Box = tester.widget<RotatedBox>(find.ancestor(of: find.byKey(const Key('quadrant_p0')), matching: find.byType(RotatedBox)));

      final p2Box = tester.widget<RotatedBox>(find.ancestor(of: find.byKey(const Key('quadrant_p2')), matching: find.byType(RotatedBox)));
      final p4Box = tester.widget<RotatedBox>(find.ancestor(of: find.byKey(const Key('quadrant_p4')), matching: find.byType(RotatedBox)));
      final p5Box = tester.widget<RotatedBox>(find.ancestor(of: find.byKey(const Key('quadrant_p5')), matching: find.byType(RotatedBox)));

      expect(p1Box.quarterTurns, equals(1));
      expect(p3Box.quarterTurns, equals(1));
      expect(p0Box.quarterTurns, equals(1));

      expect(p2Box.quarterTurns, equals(3));
      expect(p4Box.quarterTurns, equals(3));
      expect(p5Box.quarterTurns, equals(3));
    });

    testWidgets('6P Layout B (Head-of-Table): Top p1 (2); Mid p2 (1), p3 (3), p4 (1), p5 (3); Bot p0 (0) -> 5 RotatedBoxes total', (tester) async {
      await tester.pumpWidget(createPodHarness(playerCount: 6, layoutVariant: 'B'));
      await tester.pumpAndSettle();

      expect(find.byType(RotatedBox), findsNWidgets(5),
          reason: '6P Layout B should have exactly 5 RotatedBoxes');

      final p1Box = tester.widget<RotatedBox>(find.ancestor(of: find.byKey(const Key('quadrant_p1')), matching: find.byType(RotatedBox)));
      final p2Box = tester.widget<RotatedBox>(find.ancestor(of: find.byKey(const Key('quadrant_p2')), matching: find.byType(RotatedBox)));
      final p3Box = tester.widget<RotatedBox>(find.ancestor(of: find.byKey(const Key('quadrant_p3')), matching: find.byType(RotatedBox)));
      final p4Box = tester.widget<RotatedBox>(find.ancestor(of: find.byKey(const Key('quadrant_p4')), matching: find.byType(RotatedBox)));
      final p5Box = tester.widget<RotatedBox>(find.ancestor(of: find.byKey(const Key('quadrant_p5')), matching: find.byType(RotatedBox)));

      expect(p1Box.quarterTurns, equals(2));
      expect(p2Box.quarterTurns, equals(1));
      expect(p3Box.quarterTurns, equals(3));
      expect(p4Box.quarterTurns, equals(1));
      expect(p5Box.quarterTurns, equals(3));

      expect(
        find.ancestor(of: find.byKey(const Key('quadrant_p0')), matching: find.byType(RotatedBox)),
        findsNothing,
      );
    });
  });

  // ===========================================================================
  // GROUP 2: Camera Mode Override across all 1P-6P (Layout A & Layout B)
  // ===========================================================================
  group('2. Camera Mode Override Invariant (0 RotatedBoxes across all 1P-6P)', () {
    for (int count = 1; count <= 6; count++) {
      for (final variant in ['A', 'B']) {
        testWidgets('Camera Mode for ${count}P Layout $variant overrides all rotations to 0 RotatedBoxes', (tester) async {
          await tester.pumpWidget(createPodHarness(
            playerCount: count,
            layoutVariant: variant,
            isCameraMode: true,
          ));
          await tester.pumpAndSettle();

          // Camera mode must strictly bypass all RotatedBox wrappers
          expect(find.byType(RotatedBox), findsNothing,
              reason: 'Camera mode active on ${count}P Layout $variant must produce exactly 0 RotatedBoxes');

          // Ensure all player quadrants are still rendered and visible
          for (int i = 0; i < count; i++) {
            expect(find.byKey(Key('quadrant_p$i')), findsOneWidget);
          }
        });
      }
    }
  });

  // ===========================================================================
  // GROUP 3: Multi-Viewport RenderFlex Stress Testing (No Overflows)
  // ===========================================================================
  group('3. Multi-Viewport Adversarial RenderFlex Stress Tests', () {
    final Map<String, Size> viewports = {
      'Small Phone (320x568)': const Size(320, 568),
      'Standard Phone (390x844)': const Size(390, 844),
      'Landscape Phone (844x390)': const Size(844, 390),
      'Tablet Portrait (800x1280)': const Size(800, 1280),
      'Tablet Landscape (1280x800)': const Size(1280, 800),
    };

    for (final entry in viewports.entries) {
      final vpName = entry.key;
      final vpSize = entry.value;

      group('Viewport: $vpName', () {
        for (int count = 1; count <= 6; count++) {
          testWidgets('${count}P Layout A & B render with ZERO RenderFlex overflow', (tester) async {
            tester.view.physicalSize = vpSize;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(() => tester.view.resetPhysicalSize());

            for (final variant in ['A', 'B']) {
              await tester.pumpWidget(createPodHarness(
                playerCount: count,
                layoutVariant: variant,
                isCameraMode: false,
              ));
              await tester.pump();

              expect(tester.takeException(), isNull,
                  reason: 'No overflow or exception allowed on $vpName for ${count}P Layout $variant');

              for (int i = 0; i < count; i++) {
                final quadrantFinder = find.byKey(Key('quadrant_p$i'));
                expect(quadrantFinder, findsOneWidget);
                final rect = tester.getRect(quadrantFinder);
                expect(rect.width, greaterThan(0));
                expect(rect.height, greaterThan(0));
              }
            }
          });

          testWidgets('${count}P Camera Mode renders with ZERO RenderFlex overflow', (tester) async {
            tester.view.physicalSize = vpSize;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(() => tester.view.resetPhysicalSize());

            await tester.pumpWidget(createPodHarness(
              playerCount: count,
              layoutVariant: 'A',
              isCameraMode: true,
            ));
            await tester.pump();

            expect(tester.takeException(), isNull,
                reason: 'No overflow allowed on $vpName for ${count}P Camera Mode');

            for (int i = 0; i < count; i++) {
              final quadrantFinder = find.byKey(Key('quadrant_p$i'));
              expect(quadrantFinder, findsOneWidget);
              final rect = tester.getRect(quadrantFinder);
              expect(rect.width, greaterThan(0));
              expect(rect.height, greaterThan(0));
            }
          });
        }
      });
    }
  });

  // ===========================================================================
  // GROUP 4: Dynamic Reconfiguration & Mutation Stress
  // ===========================================================================
  group('4. Dynamic Reconfiguration & Mutation Stress', () {
    testWidgets('Toggling Camera Mode on the fly dynamically inserts and strips RotatedBoxes', (tester) async {
      final pod = PodState(
        sessionId: 'dynamic_cam_test',
        format: 'commander',
        startingLife: 40,
        players: createPlayers(4),
      );

      // 1. Initial State: Camera Mode FALSE, Layout A -> 4 RotatedBoxes
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
      expect(find.byType(RotatedBox), findsNWidgets(4));

      // 2. Toggle Camera Mode TRUE -> 0 RotatedBoxes
      await tester.pumpWidget(
        MaterialApp(
          home: PodScaffoldWidget(
            podState: pod,
            layoutVariant: 'A',
            isCameraMode: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(RotatedBox), findsNothing);

      // 3. Toggle back to FALSE -> 4 RotatedBoxes restored cleanly
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
      expect(find.byType(RotatedBox), findsNWidgets(4));
    });

    testWidgets('Switching Layout A to Layout B on the fly recalculates rotations without overflow', (tester) async {
      final pod = PodState(
        sessionId: 'dynamic_variant_test',
        format: 'commander',
        startingLife: 40,
        players: createPlayers(4),
      );

      // Layout A: 4 RotatedBoxes
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
      expect(find.byType(RotatedBox), findsNWidgets(4));

      // Switch to Layout B: 3 RotatedBoxes
      await tester.pumpWidget(
        MaterialApp(
          home: PodScaffoldWidget(
            podState: pod,
            layoutVariant: 'B',
            isCameraMode: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(RotatedBox), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Dynamic player count scaling from 1P to 6P maintains layout integrity', (tester) async {
      for (int count = 1; count <= 6; count++) {
        final pod = PodState(
          sessionId: 'scaling_test_$count',
          format: 'commander',
          startingLife: 40,
          players: createPlayers(count),
        );

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
        for (int i = 0; i < count; i++) {
          expect(find.byKey(Key('quadrant_p$i')), findsOneWidget);
        }
      }
    });
  });
}
