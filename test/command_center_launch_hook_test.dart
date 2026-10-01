// Copyright (c) 2026 Countr. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/command_center/presentation/widgets/play_track_accordion.dart';
import 'package:countr/features/decks/domain/models/deck_summary.dart';
import 'package:countr/features/life_counter/domain/models/pod_state.dart';
import 'package:countr/features/life_counter/presentation/dialogs/randomizer_hub_modal.dart';
import 'package:countr/features/life_counter/presentation/widgets/center_hub_button.dart';
import 'package:countr/features/life_counter/presentation/widgets/pod_scaffold_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testPodState4P = const PodState(
    sessionId: 'test_session_hook_4p',
    format: 'commander',
    startingLife: 40,
    players: [
      PodPlayerState(id: 'p1', seatIndex: 0, name: 'Alice', life: 40),
      PodPlayerState(id: 'p2', seatIndex: 1, name: 'Bob', life: 40),
      PodPlayerState(id: 'p3', seatIndex: 2, name: 'Charlie', life: 40),
      PodPlayerState(id: 'p4', seatIndex: 3, name: 'David', life: 40),
    ],
  );

  group('Feature 47: Command Center Launch Hook & Backward Compatibility', () {
    testWidgets('1. PlayTrackAccordion backward compatibility: compiles and renders with onModeSelected only', (tester) async {
      bool modeSelectedCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PlayTrackAccordion(
                onModeSelected: () => modeSelectedCalled = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Play / Track +'), findsOneWidget);
      expect(find.text('MTG'), findsOneWidget);
      expect(find.text('Pokémon'), findsOneWidget);
      expect(find.text('Lorcana'), findsOneWidget);
      expect(modeSelectedCalled, isFalse);
    });

    testWidgets('2. Non-MTG formats trigger onModeSelected and directly launch PregameSetupSheet', (tester) async {
      bool modeSelectedCalled = false;

      await tester.pumpWidget(
        ProviderScope(
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

      // Tap Pokémon card directly without nested expansion (R4)
      await tester.tap(find.text('Pokémon'));
      await tester.pumpAndSettle();

      expect(modeSelectedCalled, isTrue);
      expect(find.byKey(const Key('pregame_setup_sheet')), findsOneWidget);
    });

    testWidgets('3. MTG formats invoke onLaunchMtgMode hook directly without nested expansion', (tester) async {
      String? launchedFormat;
      bool modeSelectedCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PlayTrackAccordion(
                onModeSelected: () => modeSelectedCalled = true,
                onLaunchMtgMode: (format) => launchedFormat = format,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap MTG card directly without nested expansion (R4)
      await tester.tap(find.text('MTG'));
      await tester.pump();

      expect(modeSelectedCalled, isTrue);
      expect(launchedFormat, 'Commander');
    });

    testWidgets('4. Default launch opens PregameSetupSheet when onLaunchMtgMode is null', (tester) async {
      bool modeSelectedCalled = false;

      final dummyDecks = [
        DeckSummary(
          id: 'deck_1',
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
            id: 'deck_1',
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
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: PlayTrackAccordion(
                  onModeSelected: () => modeSelectedCalled = true,
                  injectedDecks: dummyDecks,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap MTG directly without nested expansion (R4)
      await tester.tap(find.text('MTG'));
      await tester.pumpAndSettle();

      expect(modeSelectedCalled, isTrue);
      expect(find.byKey(const Key('pregame_setup_sheet')), findsOneWidget);
    });
  });

  group('Feature 24: Center Crossroads Hub Wire-Up to RandomizerHubModal', () {
    testWidgets('1. Custom onRandomizerPressed override is strictly honored', (tester) async {
      bool customRandomizerCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PodScaffoldWidget(
              podState: testPodState4P,
              onRandomizerPressed: () => customRandomizerCalled = true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CenterHubButton), findsOneWidget);

      await tester.tap(find.byType(CenterHubButton));
      await tester.pump();

      expect(customRandomizerCalled, isTrue);
      expect(find.byKey(const Key('randomizer_hub_modal')), findsNothing);
    });

    testWidgets('2. Default tap opens production RandomizerHubModal bottom sheet', (tester) async {
      bool resetExecuted = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PodScaffoldWidget(
              podState: testPodState4P,
              onResetGame: () => resetExecuted = true,
            ),
          ),
        ),
      );
      await tester.pump();

      // Tap Center crossroads button
      await tester.tap(find.byType(CenterHubButton));
      await tester.pumpAndSettle();

      // RandomizerHubModal is now presented
      expect(find.byType(RandomizerHubModal), findsOneWidget);
      expect(find.byKey(const Key('randomizer_hub_modal')), findsOneWidget);
      expect(find.byKey(const Key('coin_flip_btn')), findsOneWidget);
      expect(find.byKey(const Key('dice_d20_btn')), findsOneWidget);
      expect(find.byKey(const Key('reset_game_btn')), findsOneWidget);

      // Verify reset game invokes onResetGame passed from PodScaffoldWidget
      await tester.tap(find.byKey(const Key('reset_game_btn')));
      await tester.pumpAndSettle();

      expect(resetExecuted, isTrue);
      expect(find.byKey(const Key('randomizer_hub_modal')), findsNothing);
    });
  });
}
