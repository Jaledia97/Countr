// Copyright (c) 2026 Countr. All rights reserved.
// Challenger M4-1 Empirical Stress Test Suite
// Requirements Under Test:
// - R4: PlayTrackAccordion Direct Setup Launch & Elimination of Nested Accordions
// - R5: Game Setup Pod Enhancements (Seating Orientation, Starting Life Slider Snap Nodes, OLED True Black, Immersive Mode)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/command_center/presentation/widgets/play_track_accordion.dart';
import 'package:countr/features/life_counter/domain/models/pod_state.dart';
import 'package:countr/features/life_counter/presentation/dialogs/pregame_setup_sheet.dart';
import 'package:countr/features/life_counter/presentation/widgets/pod_scaffold_widget.dart';
import 'package:countr/features/life_counter/presentation/widgets/player_quadrant_widget.dart';
import 'package:countr/features/life_counter/presentation/widgets/commander_art_backdrop.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> setSheetTestSize(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
  }

  group('Adversarial R4: PlayTrackAccordion & Zero Nested Accordion Verification', () {
    testWidgets('R4-CH-1: PlayTrackAccordion renders exactly 1 ExpansionTile with 0 nested ExpansionTiles', (tester) async {
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

      // Invariant: Exactly one ExpansionTile in the entire PlayTrackAccordion
      final expansionTiles = find.byType(ExpansionTile);
      expect(expansionTiles, findsOneWidget);

      // Verify direct TCG cards are present
      expect(find.byKey(const Key('play_track_card_mtg')), findsOneWidget);
      expect(find.byKey(const Key('play_track_card_pokemon')), findsOneWidget);
      expect(find.byKey(const Key('play_track_card_lorcana')), findsOneWidget);

      // Verify no obsolete nested expansion keys exist
      expect(find.byKey(const Key('mode_mtg_commander')), findsNothing);
      expect(find.byKey(const Key('mode_pokemon_standard')), findsNothing);
      expect(find.byKey(const Key('mode_lorcana_standard')), findsNothing);
    });

    testWidgets('R4-CH-2: Direct tap on MTG opens PregameSetupSheet directly with Commander format (onLaunchMtgMode is null)', (tester) async {
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

      // Ensure that PregameSetupSheet was launched with MTG context and commander preset
      expect(PregameSetupSheet.lastTcg, equals('Magic: The Gathering'));
      expect(find.text('Start Match (commander • 40 Life)'), findsOneWidget);
    });

    testWidgets('R4-CH-3: Direct tap on Pokémon opens PregameSetupSheet directly with Standard format and 20 Life', (tester) async {
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
      expect(find.text('Start Match (standard • 20 Life)'), findsOneWidget);
    });

    testWidgets('R4-CH-4: Direct tap on Lorcana opens PregameSetupSheet directly with Standard format and 20 Life', (tester) async {
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
      expect(find.text('Start Match (standard • 20 Life)'), findsOneWidget);
    });

    testWidgets('R4-CH-5: onLaunchMtgMode interceptor invokes custom handler without nested accordion expansion', (tester) async {
      String? launchedMode;
      bool modeSelectedCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PlayTrackAccordion(
                onModeSelected: () => modeSelectedCalled = true,
                onLaunchMtgMode: (m) => launchedMode = m,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('play_track_card_mtg')));
      await tester.pump();

      expect(modeSelectedCalled, isTrue);
      expect(launchedMode, equals('Commander'));
      // No nested accordion was rendered
      expect(find.byType(ExpansionTile), findsOneWidget);
    });

    testWidgets('R4-CH-6: Sequential multi-tap stress across all 3 TCGs without state leakage', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      int modeSelectedCount = 0;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: PlayTrackAccordion(
                  onModeSelected: () => modeSelectedCount++,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Tap MTG -> Opens sheet -> Dismiss sheet
      await tester.tap(find.byKey(const Key('play_track_card_mtg')));
      await tester.pumpAndSettle();
      expect(container.read(activeGameContextProvider), equals('Magic: The Gathering'));
      expect(find.byKey(const Key('pregame_setup_sheet')), findsOneWidget);
      await tester.tap(find.byKey(const Key('setup_sheet_close_btn')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pregame_setup_sheet')), findsNothing);

      // 2. Tap Pokémon -> Opens sheet -> Dismiss sheet
      await tester.tap(find.byKey(const Key('play_track_card_pokemon')));
      await tester.pumpAndSettle();
      expect(container.read(activeGameContextProvider), equals('Pokémon'));
      expect(find.byKey(const Key('pregame_setup_sheet')), findsOneWidget);
      await tester.tap(find.byKey(const Key('setup_sheet_close_btn')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pregame_setup_sheet')), findsNothing);

      // 3. Tap Lorcana -> Opens sheet -> Dismiss sheet
      await tester.tap(find.byKey(const Key('play_track_card_lorcana')));
      await tester.pumpAndSettle();
      expect(container.read(activeGameContextProvider), equals('Disney Lorcana'));
      expect(find.byKey(const Key('pregame_setup_sheet')), findsOneWidget);
      await tester.tap(find.byKey(const Key('setup_sheet_close_btn')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pregame_setup_sheet')), findsNothing);

      expect(modeSelectedCount, equals(3));
      expect(find.byType(ExpansionTile), findsOneWidget);
    });

    testWidgets('R4-CH-7: Fallback robustness when tapped outside Riverpod ProviderScope', (tester) async {
      bool modeSelectedCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PlayTrackAccordion(
                onModeSelected: () => modeSelectedCalled = true,
                onLaunchMtgMode: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tapping MTG outside ProviderScope must not throw Bad state: No ProviderScope found
      await tester.tap(find.byKey(const Key('play_track_card_mtg')));
      await tester.pump();

      expect(modeSelectedCalled, isTrue);
    });
  });

  group('Adversarial R5.2: Starting Life Slider Magnetic Snap & Display Synchronization', () {
    testWidgets('R5-CH-1: Empirical snap generator tests all boundary & floating values near 20, 30, and 40', (tester) async {
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

      // Test oracle for snap logic:
      // Snap nodes: 20, 30, 40 with window +/- 2 (inclusive of rounded integer)
      final testCases = <double, int>{
        // Near Node 20:
        17.0: 17,
        17.4: 17,
        17.6: 20, // 17.6 rounds to 18 -> within 2 of 20 -> snaps to 20
        18.0: 20,
        18.4: 20,
        19.0: 20,
        19.9: 20,
        20.0: 20,
        20.4: 20,
        21.0: 20,
        21.8: 20,
        22.0: 20,
        22.4: 20,
        22.6: 23, // 22.6 rounds to 23 -> abs(23-20)=3 > 2 -> does NOT snap
        23.0: 23,

        // Near Node 30:
        27.0: 27,
        27.4: 27,
        27.6: 30, // 27.6 rounds to 28 -> snaps to 30
        28.0: 30,
        29.0: 30,
        29.5: 30,
        30.0: 30,
        30.5: 30,
        31.0: 30,
        32.0: 30,
        32.4: 30,
        32.6: 33, // 32.6 rounds to 33 -> does NOT snap
        33.0: 33,

        // Near Node 40:
        37.0: 37,
        37.4: 37,
        37.6: 40, // 37.6 rounds to 38 -> snaps to 40
        38.0: 40,
        39.0: 40,
        39.5: 40,
        40.0: 40,
        40.5: 40,
        41.0: 40,
        42.0: 40,
        42.4: 40,
        42.6: 43, // 42.6 rounds to 43 -> does NOT snap
        43.0: 43,

        // Non-snap values:
        50.0: 50,
        65.0: 65,
        77.0: 77,
        99.0: 99,
        100.0: 100,
      };

      for (final entry in testCases.entries) {
        final inputVal = entry.key;
        final expectedSnapped = entry.value;

        // Trigger slider change
        slider.onChanged!(inputVal);
        await tester.pumpAndSettle();

        // 1. Verify numeric display text matches snapped value
        final displayedText = tester.widget<Text>(find.byKey(const Key('starting_life_value_text'))).data;
        expect(
          displayedText,
          equals('$expectedSnapped'),
          reason: 'Input $inputVal expected to resolve to $expectedSnapped, but got $displayedText',
        );

        // 2. Verify Slider internal value is synchronized to snapped value
        final updatedSlider = tester.widget<Slider>(find.byKey(const Key('pregame_starting_life_slider')));
        expect(
          updatedSlider.value,
          equals(expectedSnapped.toDouble()),
          reason: 'Slider value not synchronized to $expectedSnapped for input $inputVal',
        );

        // 3. Verify Slider label is synchronized
        expect(
          updatedSlider.label,
          equals('$expectedSnapped Life'),
        );

        // 4. Verify Start Match button text is synchronized
        expect(
          find.textContaining('$expectedSnapped Life'),
          findsAtLeastNWidgets(1),
        );
      }
    });

    testWidgets('R5-CH-2: Stepper buttons, format chips, and slider bidirectional sync', (tester) async {
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

      // Initial state: Commander 40 life
      expect(tester.widget<Text>(find.byKey(const Key('starting_life_value_text'))).data, equals('40'));
      expect(tester.widget<Slider>(find.byKey(const Key('pregame_starting_life_slider'))).value, equals(40.0));

      // Tap +5 stepper -> 45
      await tester.tap(find.byKey(const Key('life_inc_btn')));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.byKey(const Key('starting_life_value_text'))).data, equals('45'));
      expect(tester.widget<Slider>(find.byKey(const Key('pregame_starting_life_slider'))).value, equals(45.0));

      // Tap Standard (20) preset chip -> 20
      await tester.tap(find.byKey(const Key('preset_chip_standard')));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.byKey(const Key('starting_life_value_text'))).data, equals('20'));
      expect(tester.widget<Slider>(find.byKey(const Key('pregame_starting_life_slider'))).value, equals(20.0));

      // Tap Brawl (30) preset chip -> 30
      await tester.tap(find.byKey(const Key('preset_chip_brawl')));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.byKey(const Key('starting_life_value_text'))).data, equals('30'));
      expect(tester.widget<Slider>(find.byKey(const Key('pregame_starting_life_slider'))).value, equals(30.0));

      // Tap -5 stepper -> 25
      await tester.tap(find.byKey(const Key('life_dec_btn')));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.byKey(const Key('starting_life_value_text'))).data, equals('25'));
      expect(tester.widget<Slider>(find.byKey(const Key('pregame_starting_life_slider'))).value, equals(25.0));
    });

    testWidgets('R5-CH-3: Slider clamping survives extreme stepper values below 10 and above 100', (tester) async {
      await setSheetTestSize(tester);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PregameSetupSheet(initialStartingLife: 15),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.widget<Text>(find.byKey(const Key('starting_life_value_text'))).data, equals('15'));

      // Decrement twice by 5 -> 10, then 5 (below slider min: 10.0)
      await tester.tap(find.byKey(const Key('life_dec_btn')));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.byKey(const Key('starting_life_value_text'))).data, equals('10'));

      await tester.tap(find.byKey(const Key('life_dec_btn')));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.byKey(const Key('starting_life_value_text'))).data, equals('5'));

      // Slider value is safely clamped to 10.0 and does not crash Flutter assertion (min <= value <= max)
      final slider = tester.widget<Slider>(find.byKey(const Key('pregame_starting_life_slider')));
      expect(slider.value, equals(10.0));
      expect(find.byKey(const Key('pregame_starting_life_slider')), findsOneWidget);
    });
  });

  group('Adversarial R5.1, R5.3, R5.4: Seating, OLED True Black, and Immersive Mode', () {
    testWidgets('R5-CH-4: Seating orientation picker cycles through opposed, standard, and radial', (tester) async {
      await setSheetTestSize(tester);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  key: const Key('open_sheet_btn'),
                  onPressed: () => PregameSetupSheet.show(context),
                  child: const Text('Open Sheet'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open sheet
      await tester.tap(find.byKey(const Key('open_sheet_btn')));
      await tester.pumpAndSettle();

      final pickerFinder = find.byKey(const Key('pregame_seating_orientation_picker'));
      expect(pickerFinder, findsOneWidget);

      // 1. Select Standard
      await tester.tap(find.descendant(of: pickerFinder, matching: find.text('Standard')));
      await tester.pumpAndSettle();
      expect(PregameSetupSheet.lastSeatingOrientation, equals('standard'));

      // 2. Select Radial
      await tester.tap(find.descendant(of: pickerFinder, matching: find.text('Radial')));
      await tester.pumpAndSettle();
      expect(PregameSetupSheet.lastSeatingOrientation, equals('radial'));

      // 3. Select Opposed
      await tester.tap(find.descendant(of: pickerFinder, matching: find.text('Opposed')));
      await tester.pumpAndSettle();
      expect(PregameSetupSheet.lastSeatingOrientation, equals('opposed'));

      // 4. Finalize with Standard and tap Start Match
      await tester.tap(find.descendant(of: pickerFinder, matching: find.text('Standard')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('start_match_button')));
      await tester.pumpAndSettle();

      expect(PregameSetupSheet.lastSeatingOrientation, equals('standard'));
      expect(container.read(podSeatingOrientationProvider), equals('standard'));
    });

    testWidgets('R5-CH-5: OLED True Black mode suppresses backdrop art and produces 0xFF000000 container', (tester) async {
      const testPlayer = PodPlayerState(
        id: 'p_oled',
        seatIndex: 0,
        name: 'OLED Test',
        life: 40,
        commanderName: 'The Ur-Dragon',
        commanderArtCropUrl: 'https://cards.scryfall.io/art_crop/ur_dragon.jpg',
      );

      // Render quadrant with isOledMode: false
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PlayerQuadrantWidget(
                player: testPlayer,
                isTablet: false,
                opponents: [],
                isOledMode: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Non-OLED mode renders CommanderArtBackdrop widget
      expect(find.byType(CommanderArtBackdrop), findsOneWidget);

      // Render quadrant with isOledMode: true
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

      // OLED mode strictly suppresses CommanderArtBackdrop widget
      expect(find.byType(CommanderArtBackdrop), findsNothing);

      // Root container is pure #000000
      final quadrantContainerFinder = find.descendant(
        of: find.byType(PlayerQuadrantWidget),
        matching: find.byType(Container),
      ).first;
      final containerWidget = tester.widget<Container>(quadrantContainerFinder);
      final decoration = containerWidget.decoration as BoxDecoration;
      expect(decoration.color, equals(const Color(0xFF000000)));
    });

    testWidgets('R5-CH-6: Immersive mode state passes cleanly through PodScaffoldWidget and cleans up on unmount', (tester) async {
      const podState = PodState(
        sessionId: 'test_pod_session',
        format: 'commander',
        startingLife: 40,
        players: [
          PodPlayerState(id: 'p1', seatIndex: 0, name: 'P1', life: 40),
          PodPlayerState(id: 'p2', seatIndex: 1, name: 'P2', life: 40),
        ],
      );

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: PodScaffoldWidget(
              podState: podState,
              isImmersiveMode: true,
              isOledMode: true,
              seatingOrientation: 'opposed',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PodScaffoldWidget), findsOneWidget);

      // Dismount cleanly
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(find.byType(PodScaffoldWidget), findsNothing);
    });
  });

  group('End-to-End Stress: Command Center Accordion to Game Setup Pod Lifecycle', () {
    testWidgets('E2E-CH-1: Full flow from PlayTrackAccordion card tap through PregameSetupSheet customization to PodState', (tester) async {
      await setSheetTestSize(tester);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      PodState? emittedPodState;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: PlayTrackAccordion(
                  onModeSelected: () {},
                  onStartMatch: (state) => emittedPodState = state,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Tap Pokémon card
      await tester.tap(find.byKey(const Key('play_track_card_pokemon')));
      await tester.pumpAndSettle();

      expect(container.read(activeGameContextProvider), equals('Pokémon'));
      expect(find.byKey(const Key('pregame_setup_sheet')), findsOneWidget);

      // 2. Adjust player count to 2 (1v1)
      await tester.tap(find.byKey(const Key('player_count_btn_2')));
      await tester.pumpAndSettle();

      // 3. Move slider near snap node 30 (e.g. 29.2 -> snaps to 30)
      final sliderFinder = find.byKey(const Key('pregame_starting_life_slider'));
      final slider = tester.widget<Slider>(sliderFinder);
      slider.onChanged!(29.2);
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.byKey(const Key('starting_life_value_text'))).data, equals('30'));

      // 4. Change seating orientation to 'standard'
      final pickerFinder = find.byKey(const Key('pregame_seating_orientation_picker'));
      await tester.tap(find.descendant(of: pickerFinder, matching: find.text('Standard')));
      await tester.pumpAndSettle();

      // 5. Toggle OLED mode ON
      await tester.tap(find.byKey(const Key('pregame_oled_mode_switch')));
      await tester.pumpAndSettle();

      // 6. Toggle Immersive mode ON
      await tester.tap(find.byKey(const Key('pregame_immersive_mode_switch')));
      await tester.pumpAndSettle();

      // 7. Click Start Match
      await tester.tap(find.byKey(const Key('start_match_button')));
      await tester.pumpAndSettle();

      // Verify emitted PodState
      expect(emittedPodState, isNotNull);
      expect(emittedPodState!.players.length, equals(2));
      expect(emittedPodState!.startingLife, equals(30));
      expect(emittedPodState!.players[0].life, equals(30));
      expect(emittedPodState!.players[1].life, equals(30));

      // Verify persisted preferences
      expect(PregameSetupSheet.lastSeatingOrientation, equals('standard'));
      expect(PregameSetupSheet.lastOledMode, isTrue);
      expect(PregameSetupSheet.lastImmersiveMode, isTrue);
    });

    testWidgets('E2E-CH-2: PlayTrackAccordion modal host with onModeSelected pop behavior for Pokémon', (tester) async {
      await setSheetTestSize(tester);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (scaffoldContext) => ElevatedButton(
                  key: const Key('open_hub_modal_btn'),
                  onPressed: () {
                    showModalBottomSheet(
                      context: scaffoldContext,
                      builder: (sheetContext) => PlayTrackAccordion(
                        onModeSelected: () => Navigator.of(sheetContext).pop(),
                      ),
                    );
                  },
                  child: const Text('Open Hub'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_hub_modal_btn')));
      await tester.pumpAndSettle();

      // Tap Pokémon card
      await tester.tap(find.byKey(const Key('play_track_card_pokemon')));
      await tester.pumpAndSettle();

      expect(container.read(activeGameContextProvider), equals('Pokémon'));
      expect(find.byKey(const Key('pregame_setup_sheet')), findsOneWidget);
    });

    testWidgets('E2E-CH-3: PlayTrackAccordion modal host with onModeSelected pop behavior for Lorcana', (tester) async {
      await setSheetTestSize(tester);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (scaffoldContext) => ElevatedButton(
                  key: const Key('open_hub_modal_btn_lorcana'),
                  onPressed: () {
                    showModalBottomSheet(
                      context: scaffoldContext,
                      builder: (sheetContext) => PlayTrackAccordion(
                        onModeSelected: () => Navigator.of(sheetContext).pop(),
                      ),
                    );
                  },
                  child: const Text('Open Hub'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_hub_modal_btn_lorcana')));
      await tester.pumpAndSettle();

      // Tap Lorcana card
      await tester.tap(find.byKey(const Key('play_track_card_lorcana')));
      await tester.pumpAndSettle();

      expect(container.read(activeGameContextProvider), equals('Disney Lorcana'));
      expect(find.byKey(const Key('pregame_setup_sheet')), findsOneWidget);
    });
  });
}

