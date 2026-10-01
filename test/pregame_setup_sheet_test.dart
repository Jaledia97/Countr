// Copyright (c) 2026 Countr. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/domain/models/deck_summary.dart';
import 'package:countr/features/life_counter/domain/models/pod_state.dart';
import 'package:countr/features/life_counter/presentation/dialogs/pregame_setup_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testEdgarDeck = DeckSummary(
    id: 'deck-edgar',
    name: 'Edgar Aristocrats',
    format: 'Commander',
    tcgDomain: 'mtg',
    isRegistered: true,
    isCompetitive: false,
    createdAt: DateTime(2024, 1, 1),
    commanderCardId: 'edgar-markov-id',
    commanderName: 'Edgar Markov',
    commanderImageUrl: 'https://cards.scryfall.io/art_crop/edgar.jpg',
    commanderArtCrop: 'https://cards.scryfall.io/art_crop/edgar.jpg',
    colorIdentity: const ['W', 'B', 'R'],
    cardCount: 100,
    targetCardCount: 100,
    completeness: 1.0,
    assemblyStatus: 'Assembled',
    deck: Deck(
      id: 'deck-edgar',
      name: 'Edgar Aristocrats',
      format: 'Commander',
      tcgDomain: 'mtg',
      isRegistered: true,
      isAssembled: true,
      isCompetitive: false,
      createdAt: DateTime(2024, 1, 1),
      wins: 0,
      losses: 0,
      draws: 0,
      isDeleted: false,
    ),
  );

  final testStandardBurnDeck = DeckSummary(
    id: 'deck-burn',
    name: 'Mono Red Aggro',
    format: 'Standard',
    tcgDomain: 'mtg',
    isRegistered: false,
    isCompetitive: true,
    createdAt: DateTime(2024, 2, 1),
    cardCount: 60,
    targetCardCount: 60,
    completeness: 1.0,
    assemblyStatus: 'Ready',
    deck: Deck(
      id: 'deck-burn',
      name: 'Mono Red Aggro',
      format: 'Standard',
      tcgDomain: 'mtg',
      isRegistered: false,
      isAssembled: false,
      isCompetitive: true,
      createdAt: DateTime(2024, 2, 1),
      wins: 0,
      losses: 0,
      draws: 0,
      isDeleted: false,
    ),
  );

  group('PregameSetupSheet Widget Tests (Feature 29)', () {
    Future<void> setTestSize(WidgetTester tester) async {
      tester.view.physicalSize = const Size(600, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
    }

    testWidgets('T29.1: renders initial setup with default 4 players, Commander format, and 40 life',
        (tester) async {
      await setTestSize(tester);
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PregameSetupSheet(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('pregame_setup_sheet')), findsOneWidget);
      expect(find.text('Match Setup'), findsOneWidget);
      expect(find.text('Pod Size (Player Count)'), findsOneWidget);
      expect(find.byKey(const Key('starting_life_value_text')), findsOneWidget);
      expect(find.text('40'), findsOneWidget);

      // Verify 4 player cards exist (P0 to P3)
      expect(find.byKey(const Key('player_setup_card_0')), findsOneWidget);
      expect(find.byKey(const Key('player_setup_card_1')), findsOneWidget);
      expect(find.byKey(const Key('player_setup_card_2')), findsOneWidget);
      expect(find.byKey(const Key('player_setup_card_3')), findsOneWidget);
      expect(find.byKey(const Key('player_setup_card_4')), findsNothing);

      // Verify Start Match button exists
      expect(find.byKey(const Key('start_match_button')), findsOneWidget);
    });

    testWidgets('T29.2: player count selector dynamically adjusts seat count (from 4P to 1v1 and 6P)',
        (tester) async {
      await setTestSize(tester);
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PregameSetupSheet(),
            ),
          ),
        ),
      );
      await tester.pump();

      // Switch to 1v1 (2 players)
      await tester.tap(find.byKey(const Key('player_count_btn_2')));
      await tester.pump();

      expect(find.byKey(const Key('player_setup_card_0')), findsOneWidget);
      expect(find.byKey(const Key('player_setup_card_1')), findsOneWidget);
      expect(find.byKey(const Key('player_setup_card_2')), findsNothing);

      // Switch to 6P
      await tester.tap(find.byKey(const Key('player_count_btn_6')));
      await tester.pump();

      expect(find.byKey(const Key('player_setup_card_0')), findsOneWidget);
      expect(find.byKey(const Key('player_setup_card_5')), findsOneWidget);
    });

    testWidgets('T29.3: format preset chip updates format and starting life preset',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PregameSetupSheet(),
            ),
          ),
        ),
      );
      await tester.pump();

      // Tap Standard (20 life)
      await tester.tap(find.byKey(const Key('preset_chip_standard')));
      await tester.pump();

      expect(find.text('20'), findsOneWidget);
      expect(find.textContaining('Start Match (standard • 20 Life)'), findsOneWidget);

      // Tap Brawl (30 life)
      await tester.tap(find.byKey(const Key('preset_chip_brawl')));
      await tester.pump();

      expect(find.text('30'), findsOneWidget);
      expect(find.textContaining('Start Match (brawl • 30 Life)'), findsOneWidget);
    });

    testWidgets('T29.4: custom starting life stepper modifies starting life by +/-5',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PregameSetupSheet(initialStartingLife: 40),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('40'), findsOneWidget);

      // Increment (+5)
      await tester.tap(find.byKey(const Key('life_inc_btn')));
      await tester.pump();

      expect(find.text('45'), findsOneWidget);

      // Decrement twice (-10)
      await tester.tap(find.byKey(const Key('life_dec_btn')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('life_dec_btn')));
      await tester.pump();

      expect(find.text('35'), findsOneWidget);
    });

    testWidgets('T29.5: selecting a saved deck auto-populates player name, commander, art_crop, and format',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PregameSetupSheet(
                injectedDecks: [testEdgarDeck, testStandardBurnDeck],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Seat 0 is initially unlinked
      expect(find.byKey(const Key('select_deck_btn_0')), findsOneWidget);

      // Tap select deck for seat 0
      await tester.tap(find.byKey(const Key('select_deck_btn_0')));
      await tester.pumpAndSettle();

      // Picker sheet should show testEdgarDeck
      expect(find.byKey(const Key('deck_picker_tile_deck-edgar')), findsOneWidget);

      // Select Edgar deck
      await tester.tap(find.byKey(const Key('deck_picker_tile_deck-edgar')));
      await tester.pumpAndSettle();

      // Verify auto-populated metadata
      expect(find.byKey(const Key('deck_title_0')), findsOneWidget);
      expect(find.text('Edgar Aristocrats'), findsWidgets); // Both name input & deck title
      expect(find.text('Cmd: Edgar Markov'), findsOneWidget);
      expect(find.byKey(const Key('clear_deck_btn_0')), findsOneWidget);
    });

    testWidgets('T29.6: unlinking a deck resets commander details and restores default player name',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PregameSetupSheet(
                injectedDecks: [testEdgarDeck],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Link deck
      await tester.tap(find.byKey(const Key('select_deck_btn_0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('deck_picker_tile_deck-edgar')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('deck_title_0')), findsOneWidget);

      // Tap unlink button
      await tester.tap(find.byKey(const Key('clear_deck_btn_0')));
      await tester.pump();

      // Seat 0 is unlinked again
      expect(find.byKey(const Key('select_deck_btn_0')), findsOneWidget);
      expect(find.byKey(const Key('deck_title_0')), findsNothing);
      expect(find.text('Player 1'), findsOneWidget);
    });

    testWidgets('T29.7: tapping Start Match emits complete PodState with configured players',
        (tester) async {
      PodState? emittedPodState;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PregameSetupSheet(
                initialPlayerCount: 2,
                injectedDecks: [testEdgarDeck],
                onStartMatch: (podState) {
                  emittedPodState = podState;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Link deck to P0
      await tester.tap(find.byKey(const Key('select_deck_btn_0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('deck_picker_tile_deck-edgar')));
      await tester.pumpAndSettle();

      // Tap Start Match button
      await tester.tap(find.byKey(const Key('start_match_button')));
      await tester.pump();

      expect(emittedPodState, isNotNull);
      expect(emittedPodState!.players.length, equals(2));
      expect(emittedPodState!.format, equals('commander'));
      expect(emittedPodState!.startingLife, equals(40));

      final p0 = emittedPodState!.players[0];
      expect(p0.name, equals('Edgar Aristocrats'));
      expect(p0.deckId, equals('deck-edgar'));
      expect(p0.commanderCardId, equals('edgar-markov-id'));
      expect(p0.commanderName, equals('Edgar Markov'));
      expect(p0.commanderArtCropUrl, equals('https://cards.scryfall.io/art_crop/edgar.jpg'));
      expect(p0.life, equals(40));

      final p1 = emittedPodState!.players[1];
      expect(p1.name, equals('Player 2'));
      expect(p1.deckId, isNull);
      expect(p1.commanderArtCropUrl, isNull);
    });

    testWidgets('T29.8: seating orientation picker toggles Opposed, Standard, and Radial layouts',
        (tester) async {
      await setTestSize(tester);
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PregameSetupSheet(),
            ),
          ),
        ),
      );
      await tester.pump();

      final pickerFinder = find.byKey(const Key('pregame_seating_orientation_picker'));
      expect(pickerFinder, findsOneWidget);

      // Default is Opposed
      expect(find.text('Opposed'), findsOneWidget);
      expect(find.text('Radial'), findsOneWidget);

      // Select Standard orientation
      await tester.tap(find.descendant(of: pickerFinder, matching: find.text('Standard')));
      await tester.pumpAndSettle();

      // Select Radial orientation
      await tester.tap(find.descendant(of: pickerFinder, matching: find.text('Radial')));
      await tester.pumpAndSettle();

      // Tap Start Match to verify persistence to static state
      await tester.tap(find.byKey(const Key('start_match_button')));
      await tester.pumpAndSettle();

      expect(PregameSetupSheet.lastSeatingOrientation, equals('radial'));
    });

    testWidgets('T29.9: starting life slider updates starting life value and format snap points',
        (tester) async {
      await setTestSize(tester);
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PregameSetupSheet(),
            ),
          ),
        ),
      );
      await tester.pump();

      final sliderFinder = find.byKey(const Key('pregame_starting_life_slider'));
      expect(sliderFinder, findsOneWidget);

      // Initial value is 40
      expect(find.byKey(const Key('starting_life_value_text')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('starting_life_value_text'))).data, equals('40'));

      // Slider exists and is interactive
      final slider = tester.widget<Slider>(sliderFinder);
      expect(slider.min, equals(10));
      expect(slider.max, equals(100));
      expect(slider.value, equals(40.0));

      // Programmatically invoke onChanged or drag to 21 (snaps to 20 Standard)
      slider.onChanged!(21.0);
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.byKey(const Key('starting_life_value_text'))).data, equals('20'));

      // Change to 29 (snaps to 30 Brawl)
      slider.onChanged!(29.0);
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.byKey(const Key('starting_life_value_text'))).data, equals('30'));

      // Change to 50 (no snap, displays 50)
      slider.onChanged!(50.0);
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.byKey(const Key('starting_life_value_text'))).data, equals('50'));
    });

    testWidgets('T29.10: OLED True Black mode switch toggles on and off and persists selection',
        (tester) async {
      await setTestSize(tester);
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PregameSetupSheet(),
            ),
          ),
        ),
      );
      await tester.pump();

      final oledSwitchFinder = find.byKey(const Key('pregame_oled_mode_switch'));
      expect(oledSwitchFinder, findsOneWidget);

      // Default is false
      SwitchListTile oledTile = tester.widget<SwitchListTile>(oledSwitchFinder);
      expect(oledTile.value, isFalse);

      // Toggle to true
      await tester.tap(oledSwitchFinder);
      await tester.pumpAndSettle();

      oledTile = tester.widget<SwitchListTile>(oledSwitchFinder);
      expect(oledTile.value, isTrue);

      // Tap Start Match to verify persistence to static state
      await tester.tap(find.byKey(const Key('start_match_button')));
      await tester.pumpAndSettle();

      expect(PregameSetupSheet.lastOledMode, isTrue);
    });

    testWidgets('T29.11: Immersive mode switch toggles on and off and persists selection',
        (tester) async {
      await setTestSize(tester);
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PregameSetupSheet(),
            ),
          ),
        ),
      );
      await tester.pump();

      final immersiveSwitchFinder = find.byKey(const Key('pregame_immersive_mode_switch'));
      expect(immersiveSwitchFinder, findsOneWidget);

      // Default is false
      SwitchListTile immersiveTile = tester.widget<SwitchListTile>(immersiveSwitchFinder);
      expect(immersiveTile.value, isFalse);

      // Toggle to true
      await tester.tap(immersiveSwitchFinder);
      await tester.pumpAndSettle();

      immersiveTile = tester.widget<SwitchListTile>(immersiveSwitchFinder);
      expect(immersiveTile.value, isTrue);

      // Tap Start Match to verify persistence to static state
      await tester.tap(find.byKey(const Key('start_match_button')));
      await tester.pumpAndSettle();

      expect(PregameSetupSheet.lastImmersiveMode, isTrue);
    });
  });
}
