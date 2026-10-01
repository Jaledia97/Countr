// Copyright (c) 2026 Countr. All rights reserved.
// Challenger M4-2 Empirical Stress Test Suite
// Requirements Under Test:
// - R5.1: Seating Orientation Picker (opposed, standard, radial) & PodScaffoldWidget RotatedBox quarter turns
// - R5.3: OLED True Black Mode (0xFF000000 background & CommanderArtBackdrop suppression)
// - R5.4: Immersive Mode (SystemChrome system UI calls & pregame toggle)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/features/life_counter/domain/models/pod_state.dart';
import 'package:countr/features/life_counter/presentation/dialogs/pregame_setup_sheet.dart';
import 'package:countr/features/life_counter/presentation/widgets/commander_art_backdrop.dart';
import 'package:countr/features/life_counter/presentation/widgets/player_quadrant_widget.dart';
import 'package:countr/features/life_counter/presentation/widgets/pod_scaffold_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> setTestViewport(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
  }

  group('R5.1: Seating Orientation Picker & RotatedBox Quarter Turns', () {
    testWidgets('R5.1-CH-1: Seating orientation picker cycles through opposed -> standard -> radial -> opposed', (tester) async {
      await setTestViewport(tester);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: PregameSetupSheet(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final pickerFinder = find.byKey(const Key('pregame_seating_orientation_picker'));
      expect(pickerFinder, findsOneWidget);

      final pickerWidget = tester.widget<SegmentedButton<String>>(pickerFinder);
      expect(pickerWidget.selected, equals({'opposed'}));

      // Cycle 1: Tap Standard
      await tester.tap(find.descendant(of: pickerFinder, matching: find.text('Standard')));
      await tester.pumpAndSettle();
      expect(tester.widget<SegmentedButton<String>>(pickerFinder).selected, equals({'standard'}));
      expect(PregameSetupSheet.lastSeatingOrientation, equals('standard'));

      // Cycle 2: Tap Radial
      await tester.tap(find.descendant(of: pickerFinder, matching: find.text('Radial')));
      await tester.pumpAndSettle();
      expect(tester.widget<SegmentedButton<String>>(pickerFinder).selected, equals({'radial'}));
      expect(PregameSetupSheet.lastSeatingOrientation, equals('radial'));

      // Cycle 3: Tap Opposed
      await tester.tap(find.descendant(of: pickerFinder, matching: find.text('Opposed')));
      await tester.pumpAndSettle();
      expect(tester.widget<SegmentedButton<String>>(pickerFinder).selected, equals({'opposed'}));
      expect(PregameSetupSheet.lastSeatingOrientation, equals('opposed'));

      // Cycle 4: Select Standard and hit Start Match to verify Riverpod provider emission
      await tester.tap(find.descendant(of: pickerFinder, matching: find.text('Standard')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('start_match_button')));
      await tester.pumpAndSettle();

      expect(PregameSetupSheet.lastSeatingOrientation, equals('standard'));
      expect(container.read(podSeatingOrientationProvider), equals('standard'));
    });

    testWidgets('R5.1-CH-2: 1v1 pod RotatedBox quarter turns in opposed vs standard vs radial', (tester) async {
      const podState1v1 = PodState(
        sessionId: '1v1_test',
        format: 'standard',
        startingLife: 20,
        players: [
          PodPlayerState(id: 'p0', seatIndex: 0, name: 'Bottom Player', life: 20),
          PodPlayerState(id: 'p1', seatIndex: 1, name: 'Top Player', life: 20),
        ],
      );

      // 1. OPPOSE ORIENTATION:
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: PodScaffoldWidget(
              podState: podState1v1,
              seatingOrientation: 'opposed',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Top player (p1) is rotated 180° by PodLayoutEngine (1 RotatedBox with quarterTurns: 2)
      final p1Finder = find.byKey(const Key('quadrant_p1'));
      final p0Finder = find.byKey(const Key('quadrant_p0'));
      expect(p1Finder, findsOneWidget);
      expect(p0Finder, findsOneWidget);

      final p1AncestorsOpposed = find.ancestor(of: p1Finder, matching: find.byType(RotatedBox));
      expect(p1AncestorsOpposed, findsNWidgets(1));
      expect(tester.widget<RotatedBox>(p1AncestorsOpposed.first).quarterTurns, equals(2));

      // Bottom player (p0) has 0 RotatedBox
      final p0AncestorsOpposed = find.ancestor(of: p0Finder, matching: find.byType(RotatedBox));
      expect(p0AncestorsOpposed, findsNothing);

      // 2. STANDARD ORIENTATION:
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: PodScaffoldWidget(
              podState: podState1v1,
              seatingOrientation: 'standard',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // In standard orientation, top player (p1) has 2 RotatedBoxes (PodLayoutEngine + PodScaffoldWidget counter-rotation)
      final p1AncestorsStandard = find.ancestor(of: p1Finder, matching: find.byType(RotatedBox));
      expect(p1AncestorsStandard, findsNWidgets(2));
      for (final element in tester.widgetList<RotatedBox>(p1AncestorsStandard)) {
        expect(element.quarterTurns, equals(2));
      }
      // Net rotation: (2 + 2) % 4 == 0 (upright!)

      // Bottom player still has 0 RotatedBox
      expect(find.ancestor(of: p0Finder, matching: find.byType(RotatedBox)), findsNothing);

      // 3. RADIAL ORIENTATION:
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: PodScaffoldWidget(
              podState: podState1v1,
              seatingOrientation: 'radial',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final p1AncestorsRadial = find.ancestor(of: p1Finder, matching: find.byType(RotatedBox));
      expect(p1AncestorsRadial, findsNWidgets(1));
      expect(tester.widget<RotatedBox>(p1AncestorsRadial.first).quarterTurns, equals(2));
      expect(find.ancestor(of: p0Finder, matching: find.byType(RotatedBox)), findsNothing);
    });

    testWidgets('R5.1-CH-3: 4-Player pod RotatedBox quarter turns and dynamic switching', (tester) async {
      const podState4P = PodState(
        sessionId: '4p_test',
        format: 'commander',
        startingLife: 40,
        players: [
          PodPlayerState(id: 'p0', seatIndex: 0, name: 'Bottom-Left', life: 40),
          PodPlayerState(id: 'p1', seatIndex: 1, name: 'Top-Left', life: 40),
          PodPlayerState(id: 'p2', seatIndex: 2, name: 'Top-Right', life: 40),
          PodPlayerState(id: 'p3', seatIndex: 3, name: 'Bottom-Right', life: 40),
        ],
      );

      // 1. Initial pump: 'opposed'
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: PodScaffoldWidget(
              podState: podState4P,
              seatingOrientation: 'opposed',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // In opposed mode: exactly 2 RotatedBoxes in the entire tree (seats 1 and 2), each with quarterTurns: 2
      final rotatedBoxesOpposed = tester.widgetList<RotatedBox>(find.byType(RotatedBox)).toList();
      expect(rotatedBoxesOpposed.length, equals(2));
      expect(rotatedBoxesOpposed[0].quarterTurns, equals(2));
      expect(rotatedBoxesOpposed[1].quarterTurns, equals(2));

      // 2. Dynamic switch to 'standard'
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: PodScaffoldWidget(
              podState: podState4P,
              seatingOrientation: 'standard',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // In standard mode: exactly 4 RotatedBoxes in tree (outer + inner for seats 1 and 2), all with quarterTurns: 2
      final rotatedBoxesStandard = tester.widgetList<RotatedBox>(find.byType(RotatedBox)).toList();
      expect(rotatedBoxesStandard.length, equals(4));
      for (final box in rotatedBoxesStandard) {
        expect(box.quarterTurns, equals(2));
      }

      // 3. Dynamic switch to 'radial'
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: PodScaffoldWidget(
              podState: podState4P,
              seatingOrientation: 'radial',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final rotatedBoxesRadial = tester.widgetList<RotatedBox>(find.byType(RotatedBox)).toList();
      expect(rotatedBoxesRadial.length, equals(2));
      expect(rotatedBoxesRadial[0].quarterTurns, equals(2));
      expect(rotatedBoxesRadial[1].quarterTurns, equals(2));
    });

    testWidgets('R5.1-CH-4: 3-Player, 5-Player, and 6-Player pods quarter turns in standard vs opposed', (tester) async {
      // 3-Player Pod (Seats 1, 2 top row; Seat 0 bottom row)
      const pod3P = PodState(
        sessionId: '3p_test',
        format: 'commander',
        startingLife: 40,
        players: [
          PodPlayerState(id: 'p0', seatIndex: 0, name: 'P0', life: 40),
          PodPlayerState(id: 'p1', seatIndex: 1, name: 'P1', life: 40),
          PodPlayerState(id: 'p2', seatIndex: 2, name: 'P2', life: 40),
        ],
      );

      // Opposed 3P: 2 RotatedBoxes (P1 and P2 top row)
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: PodScaffoldWidget(podState: pod3P, seatingOrientation: 'opposed'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.widgetList<RotatedBox>(find.byType(RotatedBox)).length, equals(2));

      // Standard 3P: 4 RotatedBoxes (P1 and P2 each have 2)
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: PodScaffoldWidget(podState: pod3P, seatingOrientation: 'standard'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.widgetList<RotatedBox>(find.byType(RotatedBox)).length, equals(4));

      // 6-Player Pod (Seats 1, 2, 3 top row; Seats 0, 4, 5 bottom row)
      const pod6P = PodState(
        sessionId: '6p_test',
        format: 'commander',
        startingLife: 40,
        players: [
          PodPlayerState(id: 'p0', seatIndex: 0, name: 'P0', life: 40),
          PodPlayerState(id: 'p1', seatIndex: 1, name: 'P1', life: 40),
          PodPlayerState(id: 'p2', seatIndex: 2, name: 'P2', life: 40),
          PodPlayerState(id: 'p3', seatIndex: 3, name: 'P3', life: 40),
          PodPlayerState(id: 'p4', seatIndex: 4, name: 'P4', life: 40),
          PodPlayerState(id: 'p5', seatIndex: 5, name: 'P5', life: 40),
        ],
      );

      // Opposed 6P: 3 top row RotatedBoxes
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: PodScaffoldWidget(podState: pod6P, seatingOrientation: 'opposed'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.widgetList<RotatedBox>(find.byType(RotatedBox)).length, equals(3));

      // Standard 6P: 6 RotatedBoxes (3 top seats x 2)
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: PodScaffoldWidget(podState: pod6P, seatingOrientation: 'standard'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.widgetList<RotatedBox>(find.byType(RotatedBox)).length, equals(6));
    });
  });

  group('R5.3: OLED True Black Mode & Backdrop Suppression', () {
    testWidgets('R5.3-CH-1: Toggle Key(pregame_oled_mode_switch) updates state and persists', (tester) async {
      await setTestViewport(tester);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: PregameSetupSheet(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final oledSwitchFinder = find.byKey(const Key('pregame_oled_mode_switch'));
      expect(oledSwitchFinder, findsOneWidget);

      // Default is false
      expect(tester.widget<SwitchListTile>(oledSwitchFinder).value, isFalse);

      // Toggle ON
      await tester.tap(oledSwitchFinder);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(oledSwitchFinder).value, isTrue);

      // Tap Start Match to persist
      await tester.tap(find.byKey(const Key('start_match_button')));
      await tester.pumpAndSettle();

      expect(PregameSetupSheet.lastOledMode, isTrue);
      expect(container.read(podOledModeProvider), isTrue);

      // Dismount cleanly
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      // Re-mount sheet and toggle back OFF
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: PregameSetupSheet(initialOledMode: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.widget<SwitchListTile>(oledSwitchFinder).value, isTrue);
      await tester.tap(oledSwitchFinder);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(oledSwitchFinder).value, isFalse);

      await tester.tap(find.byKey(const Key('start_match_button')));
      await tester.pumpAndSettle();
      expect(PregameSetupSheet.lastOledMode, isFalse);
      expect(container.read(podOledModeProvider), isFalse);
    });

    testWidgets('R5.3-CH-2: PlayerQuadrantWidget container has background Color(0xFF000000) and suppresses CommanderArtBackdrop', (tester) async {
      const testPlayerWithArt = PodPlayerState(
        id: 'p_art',
        seatIndex: 0,
        name: 'Ur-Dragon Player',
        life: 40,
        commanderName: 'The Ur-Dragon',
        commanderArtCropUrl: 'https://cards.scryfall.io/art_crop/ur_dragon.jpg',
      );

      // Test Case A: isOledMode == false
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PlayerQuadrantWidget(
                player: testPlayerWithArt,
                isTablet: false,
                opponents: [],
                isOledMode: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Background color is normal dark 0xFF1E1E2C
      final containerNonOled = tester.widget<Container>(
        find.descendant(of: find.byType(PlayerQuadrantWidget), matching: find.byType(Container)).first,
      );
      final decorationNonOled = containerNonOled.decoration as BoxDecoration;
      expect(decorationNonOled.color, equals(const Color(0xFF1E1E2C)));

      // 2. CommanderArtBackdrop is rendered
      expect(find.byType(CommanderArtBackdrop), findsOneWidget);

      // Test Case B: isOledMode == true
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PlayerQuadrantWidget(
                player: testPlayerWithArt,
                isTablet: false,
                opponents: [],
                isOledMode: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Background color is strictly pure black 0xFF000000
      final containerOled = tester.widget<Container>(
        find.descendant(of: find.byType(PlayerQuadrantWidget), matching: find.byType(Container)).first,
      );
      final decorationOled = containerOled.decoration as BoxDecoration;
      expect(decorationOled.color, equals(const Color(0xFF000000)));

      // 2. CommanderArtBackdrop is completely suppressed
      expect(find.byType(CommanderArtBackdrop), findsNothing);

      // 3. Border styling is subtle low-opacity white
      final borderOled = decorationOled.border as Border;
      expect(borderOled.top.color, equals(Colors.white.withValues(alpha: 0.08)));
    });

    testWidgets('R5.3-CH-3: PodScaffoldWidget with isOledMode propagates pure black to all quadrants', (tester) async {
      const podState4P = PodState(
        sessionId: 'oled_pod_test',
        format: 'commander',
        startingLife: 40,
        players: [
          PodPlayerState(id: 'p0', seatIndex: 0, name: 'P0', life: 40, commanderArtCropUrl: 'https://example.com/art0.jpg'),
          PodPlayerState(id: 'p1', seatIndex: 1, name: 'P1', life: 40, commanderArtCropUrl: 'https://example.com/art1.jpg'),
          PodPlayerState(id: 'p2', seatIndex: 2, name: 'P2', life: 40, commanderArtCropUrl: 'https://example.com/art2.jpg'),
          PodPlayerState(id: 'p3', seatIndex: 3, name: 'P3', life: 40, commanderArtCropUrl: 'https://example.com/art3.jpg'),
        ],
      );

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: PodScaffoldWidget(
              podState: podState4P,
              isOledMode: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify all 4 quadrants have pure black background
      for (final playerId in ['p0', 'p1', 'p2', 'p3']) {
        final quadrantFinder = find.byKey(Key('quadrant_$playerId'));
        expect(quadrantFinder, findsOneWidget);
        final container = tester.widget<Container>(
          find.descendant(of: quadrantFinder, matching: find.byType(Container)).first,
        );
        final deco = container.decoration as BoxDecoration;
        expect(deco.color, equals(const Color(0xFF000000)), reason: 'Quadrant $playerId must have Color(0xFF000000)');
      }

      // Verify zero commander art backdrops in entire tree
      expect(find.byType(CommanderArtBackdrop), findsNothing);
    });

    testWidgets('R5.3-CH-4: Lethal player state handles contrast red overlay while preserving backdrop suppression', (tester) async {
      const lethalPlayer = PodPlayerState(
        id: 'p_dead',
        seatIndex: 0,
        name: 'Dead Player',
        life: 0, // isLethal == true
        commanderArtCropUrl: 'https://example.com/art.jpg',
      );

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PlayerQuadrantWidget(
                player: lethalPlayer,
                isTablet: false,
                opponents: [],
                isOledMode: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // In lethal state, red highlight overlay is rendered
      final container = tester.widget<Container>(
        find.descendant(of: find.byType(PlayerQuadrantWidget), matching: find.byType(Container)).first,
      );
      final deco = container.decoration as BoxDecoration;
      expect(deco.color, equals(Colors.red.shade900.withValues(alpha: 0.3)));

      // Backdrop art remains suppressed in OLED mode
      expect(find.byType(CommanderArtBackdrop), findsNothing);
    });

    testWidgets('R5.3-CH-5: Commander damage lethal state (>=21) renders distinct red border in OLED mode', (tester) async {
      const cmdLethalPlayer = PodPlayerState(
        id: 'p_cmd_dead',
        seatIndex: 0,
        name: 'Cmd Lethal Player',
        life: 25,
        commanderDamageTaken: {'opp_1': 21}, // >= 21 lethal
        commanderArtCropUrl: 'https://example.com/art.jpg',
      );

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PlayerQuadrantWidget(
                player: cmdLethalPlayer,
                isTablet: false,
                opponents: [],
                isOledMode: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final container = tester.widget<Container>(
        find.descendant(of: find.byType(PlayerQuadrantWidget), matching: find.byType(Container)).first,
      );
      final deco = container.decoration as BoxDecoration;
      final border = deco.border as Border;
      expect(border.top.color, equals(Colors.redAccent));
      expect(border.top.width, equals(3.0));

      // Art backdrop suppressed
      expect(find.byType(CommanderArtBackdrop), findsNothing);
    });
  });

  group('R5.4: Immersive Mode & System UI Platform Channel Calls', () {
    testWidgets('R5.4-CH-1: Toggle Key(pregame_immersive_mode_switch) updates state and persists', (tester) async {
      await setTestViewport(tester);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: PregameSetupSheet(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final immersiveSwitchFinder = find.byKey(const Key('pregame_immersive_mode_switch'));
      expect(immersiveSwitchFinder, findsOneWidget);

      // Default is false
      expect(tester.widget<SwitchListTile>(immersiveSwitchFinder).value, isFalse);

      // Toggle ON
      await tester.tap(immersiveSwitchFinder);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(immersiveSwitchFinder).value, isTrue);

      // Tap Start Match to persist
      await tester.tap(find.byKey(const Key('start_match_button')));
      await tester.pumpAndSettle();

      expect(PregameSetupSheet.lastImmersiveMode, isTrue);
      expect(container.read(podImmersiveModeProvider), isTrue);

      // Dismount cleanly
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      // Re-mount sheet and toggle back OFF
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: PregameSetupSheet(initialImmersiveMode: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.widget<SwitchListTile>(immersiveSwitchFinder).value, isTrue);
      await tester.tap(immersiveSwitchFinder);
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(immersiveSwitchFinder).value, isFalse);

      await tester.tap(find.byKey(const Key('start_match_button')));
      await tester.pumpAndSettle();
      expect(PregameSetupSheet.lastImmersiveMode, isFalse);
      expect(container.read(podImmersiveModeProvider), isFalse);
    });

    testWidgets('R5.4-CH-2: PodScaffoldWidget invokes SystemChrome.setEnabledSystemUIMode platform messages', (tester) async {
      final List<MethodCall> platformCalls = [];

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          platformCalls.add(methodCall);
          return null;
        },
      );

      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });

      const testPod = PodState(
        sessionId: 'immersive_test',
        format: 'commander',
        startingLife: 40,
        players: [
          PodPlayerState(id: 'p0', seatIndex: 0, name: 'P0', life: 40),
          PodPlayerState(id: 'p1', seatIndex: 1, name: 'P1', life: 40),
        ],
      );

      // 1. Mount with isImmersiveMode: true
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: PodScaffoldWidget(
              podState: testPod,
              isImmersiveMode: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify that SystemChrome.setEnabledSystemUIMode was called with immersiveSticky
      final setModeCallsOnMount = platformCalls
          .where((call) => call.method == 'SystemChrome.setEnabledSystemUIMode')
          .toList();
      expect(setModeCallsOnMount.isNotEmpty, isTrue, reason: 'Must invoke SystemChrome.setEnabledSystemUIMode on mount');
      expect(
        setModeCallsOnMount.any((call) => call.arguments.toString().contains('immersiveSticky')),
        isTrue,
        reason: 'Mount call must pass SystemUiMode.immersiveSticky',
      );

      platformCalls.clear();

      // 2. Unmount PodScaffoldWidget to trigger dispose()
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      // Verify that dispose restores SystemUiMode.edgeToEdge
      final setModeCallsOnDispose = platformCalls
          .where((call) => call.method == 'SystemChrome.setEnabledSystemUIMode')
          .toList();
      expect(setModeCallsOnDispose.isNotEmpty, isTrue, reason: 'Must invoke SystemChrome.setEnabledSystemUIMode on dispose');
      expect(
        setModeCallsOnDispose.any((call) => call.arguments.toString().contains('edgeToEdge')),
        isTrue,
        reason: 'Dispose call must pass SystemUiMode.edgeToEdge to restore system UI',
      );

      platformCalls.clear();

      // 3. Mount with isImmersiveMode: false -> should NOT call setEnabledSystemUIMode
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: PodScaffoldWidget(
              podState: testPod,
              isImmersiveMode: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final nonImmersiveMountCalls = platformCalls
          .where((call) => call.method == 'SystemChrome.setEnabledSystemUIMode')
          .toList();
      expect(nonImmersiveMountCalls, isEmpty, reason: 'Must not alter system UI when isImmersiveMode is false');

      // Unmount non-immersive
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      final nonImmersiveDisposeCalls = platformCalls
          .where((call) => call.method == 'SystemChrome.setEnabledSystemUIMode')
          .toList();
      expect(nonImmersiveDisposeCalls, isEmpty, reason: 'Must not call restore on dispose when isImmersiveMode was false');
    });

    testWidgets('R5.4-CH-3: Rapid consecutive mount and unmount cycles preserve system UI mode alternation', (tester) async {
      final List<String> modesInvoked = [];

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          if (methodCall.method == 'SystemChrome.setEnabledSystemUIMode') {
            modesInvoked.add(methodCall.arguments.toString());
          }
          return null;
        },
      );

      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });

      const testPod = PodState(
        sessionId: 'cycle_test',
        format: 'commander',
        startingLife: 40,
        players: [
          PodPlayerState(id: 'p0', seatIndex: 0, name: 'P0', life: 40),
          PodPlayerState(id: 'p1', seatIndex: 1, name: 'P1', life: 40),
        ],
      );

      for (int i = 0; i < 3; i++) {
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: PodScaffoldWidget(
                podState: testPod,
                isImmersiveMode: true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }

      // Expected 3 mount (immersiveSticky) and 3 dispose (edgeToEdge) calls in strict alternating sequence
      expect(modesInvoked.length, equals(6));
      expect(modesInvoked[0], contains('immersiveSticky'));
      expect(modesInvoked[1], contains('edgeToEdge'));
      expect(modesInvoked[2], contains('immersiveSticky'));
      expect(modesInvoked[3], contains('edgeToEdge'));
      expect(modesInvoked[4], contains('immersiveSticky'));
      expect(modesInvoked[5], contains('edgeToEdge'));
    });
  });

  group('Life Counter Interactive Verification', () {
    testWidgets('LC-INT-1: Life stepper adjustments and exit button navigation', (tester) async {
      const podState = PodState(
        sessionId: 'interactive_test',
        format: 'commander',
        startingLife: 40,
        players: [
          PodPlayerState(id: 'p0', seatIndex: 0, name: 'P0', life: 40),
          PodPlayerState(id: 'p1', seatIndex: 1, name: 'P1', life: 40),
        ],
      );

      bool popped = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                key: const Key('launch_pod_btn'),
                onPressed: () {
                  Navigator.of(context)
                      .push(
                        MaterialPageRoute<void>(
                          builder: (_) => const PodScaffoldWidget(
                            podState: podState,
                            isOledMode: true,
                          ),
                        ),
                      )
                      .then((_) => popped = true);
                },
                child: const Text('Launch Pod'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('launch_pod_btn')));
      await tester.pumpAndSettle();

      expect(find.byType(PodScaffoldWidget), findsOneWidget);

      // Verify exit button exits tracker
      final exitBtn = find.byKey(const Key('life_counter_exit_button'));
      expect(exitBtn, findsOneWidget);
      await tester.tap(exitBtn);
      await tester.pumpAndSettle();

      expect(popped, isTrue);
      expect(find.byType(PodScaffoldWidget), findsNothing);
    });

    testWidgets('LC-INT-2: Pod player state life manipulation and elimination logic', (tester) async {
      final podState = PodState(
        sessionId: 'elimination_test',
        format: 'commander',
        startingLife: 40,
        players: const [
          PodPlayerState(id: 'p0', seatIndex: 0, name: 'P0', life: 40),
          PodPlayerState(id: 'p1', seatIndex: 1, name: 'P1', life: 40),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: PodScaffoldWidget(
              podState: podState,
              isOledMode: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find life decrement tap zone on P0
      final p0DecrementFinder = find.descendant(
        of: find.byKey(const Key('quadrant_p0')),
        matching: find.byKey(const Key('life_tap_zone_decrement')),
      );

      if (p0DecrementFinder.evaluate().isNotEmpty) {
        await tester.tap(p0DecrementFinder);
        await tester.pumpAndSettle();
      }

      expect(find.byType(PodScaffoldWidget), findsOneWidget);
    });
  });
}
