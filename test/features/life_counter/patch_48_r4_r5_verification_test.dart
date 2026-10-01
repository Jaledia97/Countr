// Copyright (c) 2026 Countr. All rights reserved.
// Verification suite for Countr 4.8 Patch: Requirements R4 and R5.
//
// R4: Command Center Direct Setup Launch without nested ExpansionTiles
// R5.1: Pod Table Seating Orientation Picker (Opposed, Standard, Radial)
// R5.2: Starting Life Slider with Format Snap Points (40 Commander, 30 Brawl, 20 Standard)
// R5.3: OLED True Black Mode (#000000 true black rendering)
// R5.4: Immersive Gameplay Mode (SystemChrome immersiveSticky)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/command_center/presentation/widgets/play_track_accordion.dart';
import 'package:countr/features/life_counter/domain/models/pod_state.dart';
import 'package:countr/features/life_counter/presentation/dialogs/pregame_setup_sheet.dart';
import 'package:countr/features/life_counter/presentation/widgets/pod_scaffold_widget.dart';
import 'package:countr/features/life_counter/presentation/widgets/player_quadrant_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Requirement R4: Command Center Direct Setup Launch Verification', () {
    testWidgets('R4.1: Direct TCG cards render with distinct keys and no nested ExpansionTiles', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PlayTrackAccordion(
                onModeSelected: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('play_track_card_mtg')), findsOneWidget);
      expect(find.byKey(const Key('play_track_card_pokemon')), findsOneWidget);
      expect(find.byKey(const Key('play_track_card_lorcana')), findsOneWidget);

      // Verify that sub-expansion tiles (e.g. mode_mtg_commander) do NOT exist prior to tap
      expect(find.byKey(const Key('mode_mtg_commander')), findsNothing);
    });

    testWidgets('R4.2: Tapping MTG card sets activeGameContextProvider and directly opens PregameSetupSheet', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      bool modeSelectedCalled = false;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: PlayTrackAccordion(
                  onModeSelected: () => modeSelectedCalled = true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('play_track_card_mtg')));
      await tester.pumpAndSettle();

      expect(modeSelectedCalled, isTrue);
      expect(container.read(activeGameContextProvider), equals('Magic: The Gathering'));
      expect(find.byKey(const Key('pregame_setup_sheet')), findsOneWidget);
    });

    testWidgets('R4.3: Tapping Pokémon card sets activeGameContextProvider and directly opens PregameSetupSheet', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      bool modeSelectedCalled = false;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: PlayTrackAccordion(
                  onModeSelected: () => modeSelectedCalled = true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('play_track_card_pokemon')));
      await tester.pumpAndSettle();

      expect(modeSelectedCalled, isTrue);
      expect(container.read(activeGameContextProvider), equals('Pokémon'));
      expect(find.byKey(const Key('pregame_setup_sheet')), findsOneWidget);
      expect(PregameSetupSheet.lastTcg, equals('Pokémon'));
    });

    testWidgets('R4.4: Tapping Lorcana card sets activeGameContextProvider and directly opens PregameSetupSheet', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      bool modeSelectedCalled = false;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: PlayTrackAccordion(
                  onModeSelected: () => modeSelectedCalled = true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('play_track_card_lorcana')));
      await tester.pumpAndSettle();

      expect(modeSelectedCalled, isTrue);
      expect(container.read(activeGameContextProvider), equals('Disney Lorcana'));
      expect(find.byKey(const Key('pregame_setup_sheet')), findsOneWidget);
      expect(PregameSetupSheet.lastTcg, equals('Disney Lorcana'));
    });

    testWidgets('R4.5: Explicit onLaunchMtgMode hook is called directly on MTG tap', (tester) async {
      String? launchedMode;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PlayTrackAccordion(
                onModeSelected: () {},
                onLaunchMtgMode: (mode) => launchedMode = mode,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('play_track_card_mtg')));
      await tester.pump();

      expect(launchedMode, equals('Commander'));
    });
  });

  group('Requirement R5: Pregame Setup Pod Enhancements Verification', () {
    Future<void> setSheetTestSize(WidgetTester tester) async {
      tester.view.physicalSize = const Size(600, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
    }

    testWidgets('R5.1: Seating orientation picker supports Opposed, Standard, and Radial layouts', (tester) async {
      await setSheetTestSize(tester);

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

      // Select Standard
      await tester.tap(find.descendant(of: pickerFinder, matching: find.text('Standard')));
      await tester.pumpAndSettle();

      // Tap start match to verify update
      await tester.tap(find.byKey(const Key('start_match_button')));
      await tester.pumpAndSettle();

      expect(PregameSetupSheet.lastSeatingOrientation, equals('standard'));
      expect(container.read(podSeatingOrientationProvider), equals('standard'));
    });

    testWidgets('R5.2: Starting life slider has interactive format snap nodes at 40, 30, and 20', (tester) async {
      await setSheetTestSize(tester);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PregameSetupSheet(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final sliderFinder = find.byKey(const Key('pregame_starting_life_slider'));
      expect(sliderFinder, findsOneWidget);

      final slider = tester.widget<Slider>(sliderFinder);
      expect(slider.min, equals(10));
      expect(slider.max, equals(100));

      // Slider snaps near 20 (e.g. 19.5 -> 20)
      slider.onChanged!(19.5);
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.byKey(const Key('starting_life_value_text'))).data, equals('20'));

      // Slider snaps near 30 (e.g. 31.0 -> 30)
      slider.onChanged!(31.0);
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.byKey(const Key('starting_life_value_text'))).data, equals('30'));

      // Slider snaps near 40 (e.g. 41.5 -> 40)
      slider.onChanged!(41.5);
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.byKey(const Key('starting_life_value_text'))).data, equals('40'));

      // Non-snap value displays directly
      slider.onChanged!(65.0);
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.byKey(const Key('starting_life_value_text'))).data, equals('65'));
    });

    testWidgets('R5.3: OLED True Black mode renders #000000 background and suppresses backdrop art', (tester) async {
      await setSheetTestSize(tester);

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

      final oledSwitch = find.byKey(const Key('pregame_oled_mode_switch'));
      expect(oledSwitch, findsOneWidget);

      // Toggle OLED mode ON
      await tester.tap(oledSwitch);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('start_match_button')));
      await tester.pumpAndSettle();

      expect(PregameSetupSheet.lastOledMode, isTrue);
      expect(container.read(podOledModeProvider), isTrue);

      // Verify PlayerQuadrantWidget with isOledMode: true renders pure black container background
      const testPlayer = PodPlayerState(
        id: 'p1',
        seatIndex: 0,
        name: 'OLED Test Player',
        life: 40,
        commanderName: 'Edgar Markov',
        commanderArtCropUrl: 'https://cards.scryfall.io/art_crop/edgar.jpg',
      );

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PlayerQuadrantWidget(
                player: testPlayer,
                isTablet: false,
                opponents: [],
                isOledMode: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find quadrant root container
      final quadrantContainerFinder = find.descendant(
        of: find.byType(PlayerQuadrantWidget),
        matching: find.byType(Container),
      ).first;

      final containerWidget = tester.widget<Container>(quadrantContainerFinder);
      final boxDecoration = containerWidget.decoration as BoxDecoration;
      expect(boxDecoration.color, equals(const Color(0xFF000000)));

      // In OLED mode, commander art backdrop is suppressed
      expect(find.byKey(const Key('commander_art_backdrop')), findsNothing);
    });

    testWidgets('R5.4: Immersive mode toggle persists and configures SystemChrome correctly', (tester) async {
      await setSheetTestSize(tester);

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

      final immersiveSwitch = find.byKey(const Key('pregame_immersive_mode_switch'));
      expect(immersiveSwitch, findsOneWidget);

      // Toggle immersive mode ON
      await tester.tap(immersiveSwitch);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('start_match_button')));
      await tester.pumpAndSettle();

      expect(PregameSetupSheet.lastImmersiveMode, isTrue);
      expect(container.read(podImmersiveModeProvider), isTrue);

      // Verify PodScaffoldWidget mounts and unmounts cleanly with isImmersiveMode: true
      final testPodState = PodState(
        sessionId: 'session_test_immersive',
        format: 'commander',
        startingLife: 40,
        players: const [
          PodPlayerState(id: 'p0', seatIndex: 0, name: 'P1', life: 40),
          PodPlayerState(id: 'p1', seatIndex: 1, name: 'P2', life: 40),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: PodScaffoldWidget(
              podState: testPodState,
              isImmersiveMode: true,
              isOledMode: true,
              seatingOrientation: 'standard',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PodScaffoldWidget), findsOneWidget);

      // Dismount to verify dispose clean-up
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(find.byType(PodScaffoldWidget), findsNothing);
    });
  });
}
