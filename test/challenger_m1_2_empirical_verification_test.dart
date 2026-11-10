// Copyright (c) 2026 Countr. All rights reserved.
// Challenger 2 (challenger_m1_2) Empirical Verification & Stress Test Suite for Milestone 1.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/features/life_counter/domain/models/pod_state.dart';
import 'package:countr/features/life_counter/presentation/widgets/player_quadrant_widget.dart';
import 'package:countr/features/life_counter/presentation/widgets/pod_scaffold_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  PodState createPod(int playerCount, {int startingLife = 40}) {
    return PodState(
      sessionId: 'challenger_m1_2_session',
      format: 'commander',
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

  Future<void> pumpPodWithSize(
    WidgetTester tester, {
    required PodState state,
    required Size size,
    bool isOledMode = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: MediaQuery(
          data: MediaQueryData(size: size),
          child: PodScaffoldWidget(
            podState: state,
            isOledMode: isOledMode,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('Requirement 2: Narrow Viewports Zero-Overflow Verification (280x653 and 360x640)', () {
    testWidgets('6P mode on Foldable Cover Narrow (280x653) has 0 RenderFlex overflow', (tester) async {
      final state = createPod(6);
      await pumpPodWithSize(tester, state: state, size: const Size(280, 653));

      for (int i = 1; i <= 6; i++) {
        expect(find.byKey(Key('quadrant_p$i')), findsOneWidget);
        expect(find.byKey(Key('life_display_p$i')), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('6P mode on Budget Android (360x640) has 0 RenderFlex overflow', (tester) async {
      final state = createPod(6);
      await pumpPodWithSize(tester, state: state, size: const Size(360, 640));

      for (int i = 1; i <= 6; i++) {
        expect(find.byKey(Key('quadrant_p$i')), findsOneWidget);
        expect(find.byKey(Key('life_display_p$i')), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });

    for (final count in [1, 2, 3, 4, 5, 6]) {
      testWidgets('$count-Player on 280x653 has 0 RenderFlex overflow', (tester) async {
        final state = createPod(count);
        await pumpPodWithSize(tester, state: state, size: const Size(280, 653));
        expect(tester.takeException(), isNull);
      });

      testWidgets('$count-Player on 360x640 has 0 RenderFlex overflow', (tester) async {
        final state = createPod(count);
        await pumpPodWithSize(tester, state: state, size: const Size(360, 640));
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Requirement 3: Lifetap Rounded Card Styling Verification', () {
    testWidgets('PlayerQuadrantWidget has 4px margin, BorderRadius.circular(16), 1.5px border, and antiAlias clip', (tester) async {
      const player = PodPlayerState(
        id: 'p1',
        seatIndex: 0,
        name: 'Player 1',
        life: 40,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 300,
              child: PlayerQuadrantWidget(
                player: player,
                opponents: const [],
                isTablet: false,
                isOledMode: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Find the card container
      final containerFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.margin == const EdgeInsets.all(4.0) &&
            widget.clipBehavior == Clip.antiAlias,
      );
      expect(containerFinder, findsOneWidget);

      final container = tester.widget<Container>(containerFinder);
      expect(container.margin, const EdgeInsets.all(4.0));
      expect(container.clipBehavior, Clip.antiAlias);

      final decoration = container.decoration as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(16.0));

      final border = decoration.border as Border;
      expect(border.top.width, 1.5);
      expect(border.bottom.width, 1.5);
      expect(border.left.width, 1.5);
      expect(border.right.width, 1.5);
      expect(tester.takeException(), isNull);
    });

    testWidgets('PlayerQuadrantWidget thickens border to 3.0px redAccent when lethal commander damage is present', (tester) async {
      const lethalPlayer = PodPlayerState(
        id: 'p1',
        seatIndex: 0,
        name: 'Player 1',
        life: 40,
        commanderDamageTaken: {'p2': 21}, // Lethal cmd damage
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 300,
              child: PlayerQuadrantWidget(
                player: lethalPlayer,
                opponents: const [],
                isTablet: false,
                isOledMode: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final containerFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.margin == const EdgeInsets.all(4.0) &&
            widget.clipBehavior == Clip.antiAlias,
      );
      expect(containerFinder, findsOneWidget);

      final container = tester.widget<Container>(containerFinder);
      final decoration = container.decoration as BoxDecoration;
      final border = decoration.border as Border;
      expect(border.top.width, 3.0);
      expect(border.top.color, Colors.redAccent);
      expect(tester.takeException(), isNull);
    });
  });

  group('Adversarial Failure Mode Reproduction: Extreme Landscape Viewports with Unbounded Column Layout', () {
    testWidgets('CONFIRMED BUG: 2P on Tiny Landscape (480x320) throws RenderFlex overflow because Column does not constrain FittedBox height', (tester) async {
      final List<FlutterErrorDetails> errors = [];
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) => errors.add(details);

      final state = createPod(2);
      await pumpPodWithSize(tester, state: state, size: const Size(480, 320));

      FlutterError.onError = oldHandler;

      expect(errors.isNotEmpty, isTrue);
      expect(errors.any((e) => e.toString().contains('RenderFlex overflowed by 17 pixels')), isTrue);
    });

    testWidgets('CONFIRMED BUG: 6P on Foldable Landscape (653x280) throws RenderFlex overflow', (tester) async {
      final List<FlutterErrorDetails> errors = [];
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) => errors.add(details);

      final state = createPod(6);
      await pumpPodWithSize(tester, state: state, size: const Size(653, 280));

      FlutterError.onError = oldHandler;

      expect(errors.isNotEmpty, isTrue);
      expect(errors.any((e) => e.toString().contains('RenderFlex overflowed by 37 pixels')), isTrue);
    });
  });
}
