// Copyright (c) 2026 Countr. All rights reserved.
// Milestone 5 Gate: Adversarial Reset Game, Seating Persistence & Integration Stress Suite.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;

import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/life_counter/domain/models/pod_state.dart';
import 'package:countr/features/life_counter/data/repositories/match_session_repository.dart';
import 'package:countr/features/life_counter/presentation/controllers/pod_controller.dart';
import 'package:countr/features/life_counter/presentation/dialogs/reset_game_dialog.dart';
import 'package:countr/features/life_counter/presentation/dialogs/randomizer_hub_modal.dart';
import 'package:countr/features/life_counter/presentation/widgets/center_hub_button.dart';
import 'package:countr/features/life_counter/presentation/widgets/pod_scaffold_widget.dart';
import 'package:countr/features/command_center/presentation/widgets/play_track_accordion.dart';
import 'package:countr/features/life_counter/presentation/dialogs/pregame_setup_sheet.dart';
import 'package:countr/features/decks/domain/models/deck_summary.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Helper generating a 6-player pod with complex, heavily modified mid-game states.
  PodState createComplex6PlayerPod({int startingLife = 40}) {
    return PodState(
      sessionId: 'session_adv_stress_6p',
      format: 'commander',
      startingLife: startingLife,
      players: [
        // Player 0: Alice (Atraxa) - Life 52, Monarch
        const PodPlayerState(
          id: 'p0',
          seatIndex: 0,
          name: 'Alice',
          deckId: 'deck_alice_edh',
          commanderCardId: 'cmd_atraxa_id',
          commanderName: 'Atraxa, Praetors\' Voice',
          commanderArtCropUrl: 'https://cards.scryfall.io/art_crop/atraxa.jpg',
          colorTheme: 'cyan',
          life: 52,
          poison: 0,
          energy: 0,
          experience: 0,
          commanderTax: 0,
          isMonarch: true,
          hasInitiative: false,
          commanderDamageTaken: {},
          floatingMana: {'W': 0, 'U': 0, 'B': 0, 'R': 0, 'G': 0, 'C': 0},
          stormCount: 0,
          isEliminated: false,
        ),
        // Player 1: Bob (Urza) - Life 12, Poison 9 (near lethal)
        const PodPlayerState(
          id: 'p1',
          seatIndex: 1,
          name: 'Bob',
          deckId: 'deck_bob_edh',
          commanderCardId: 'cmd_urza_id',
          commanderName: 'Urza, Lord High Artificer',
          commanderArtCropUrl: 'https://cards.scryfall.io/art_crop/urza.jpg',
          colorTheme: 'blue',
          life: 12,
          poison: 9,
          energy: 4,
          experience: 1,
          commanderTax: 2,
          isMonarch: false,
          hasInitiative: false,
          commanderDamageTaken: {'p0': 14},
          floatingMana: {'W': 0, 'U': 3, 'B': 0, 'R': 0, 'G': 0, 'C': 2},
          stormCount: 2,
          isEliminated: false,
        ),
        // Player 2: Charlie (Krenko) - Life 8, Energy 50
        const PodPlayerState(
          id: 'p2',
          seatIndex: 2,
          name: 'Charlie',
          deckId: 'deck_charlie_edh',
          commanderCardId: 'cmd_krenko_id',
          commanderName: 'Krenko, Mob Boss',
          commanderArtCropUrl: 'https://cards.scryfall.io/art_crop/krenko.jpg',
          colorTheme: 'red',
          life: 8,
          poison: 2,
          energy: 50,
          experience: 5,
          commanderTax: 4,
          isMonarch: false,
          hasInitiative: false,
          commanderDamageTaken: {'p1': 8},
          floatingMana: {'W': 0, 'U': 0, 'B': 0, 'R': 12, 'G': 0, 'C': 0},
          stormCount: 6,
          isEliminated: false,
        ),
        // Player 3: David (Muldrotha) - Life 3, Commander Tax 8, Initiative claimed
        const PodPlayerState(
          id: 'p3',
          seatIndex: 3,
          name: 'David',
          deckId: 'deck_david_edh',
          commanderCardId: 'cmd_muldrotha_id',
          commanderName: 'Muldrotha, the Gravetide',
          commanderArtCropUrl: 'https://cards.scryfall.io/art_crop/muldrotha.jpg',
          colorTheme: 'green',
          life: 3,
          poison: 0,
          energy: 0,
          experience: 3,
          commanderTax: 8,
          isMonarch: false,
          hasInitiative: true,
          commanderDamageTaken: {'p0': 6, 'p2': 11},
          floatingMana: {'W': 0, 'U': 1, 'B': 2, 'R': 0, 'G': 2, 'C': 0},
          stormCount: 1,
          isEliminated: false,
        ),
        // Player 4: Eve (Edgar) - Life 29, 20 commander dmg from 3 opponents (p0, p1, p2)
        const PodPlayerState(
          id: 'p4',
          seatIndex: 4,
          name: 'Eve',
          deckId: 'deck_eve_edh',
          commanderCardId: 'cmd_edgar_id',
          commanderName: 'Edgar Markov',
          commanderArtCropUrl: 'https://cards.scryfall.io/art_crop/edgar.jpg',
          colorTheme: 'amber',
          life: 29,
          poison: 1,
          energy: 2,
          experience: 0,
          commanderTax: 6,
          isMonarch: false,
          hasInitiative: false,
          commanderDamageTaken: {'p0': 20, 'p1': 20, 'p2': 20},
          floatingMana: {'W': 1, 'U': 0, 'B': 3, 'R': 2, 'G': 0, 'C': 0},
          stormCount: 3,
          isEliminated: false,
        ),
        // Player 5: Frank (Omnath) - Life 41, floating mana in all 6 colors, storm 15
        const PodPlayerState(
          id: 'p5',
          seatIndex: 5,
          name: 'Frank',
          deckId: 'deck_frank_edh',
          commanderCardId: 'cmd_omnath_id',
          commanderName: 'Omnath, Locus of All',
          commanderArtCropUrl: 'https://cards.scryfall.io/art_crop/omnath.jpg',
          colorTheme: 'purple',
          life: 41,
          poison: 0,
          energy: 10,
          experience: 4,
          commanderTax: 2,
          isMonarch: false,
          hasInitiative: false,
          commanderDamageTaken: {'p3': 7},
          floatingMana: {'W': 3, 'U': 4, 'B': 2, 'R': 5, 'G': 6, 'C': 1},
          stormCount: 15,
          isEliminated: false,
        ),
      ],
      isDay: false,
      sequenceNumber: 120,
    );
  }

  // ===========================================================================
  // GROUP 1: 6-Player Pod Complex State & PodController Reset Game (Feature 46)
  // ===========================================================================
  group('Adversarial Group 1: 6-Player Pod Complex State & PodController.resetGame()', () {
    test('T1.1: ResetGame(40) restores all 6 players to 40 life and zeroes all counters', () async {
      final initialPod = createComplex6PlayerPod(startingLife: 40);
      final controller = PodController(initialState: initialPod);

      // Verify dirty pre-reset state
      expect(controller.state.players[0].life, 52);
      expect(controller.state.players[0].isMonarch, isTrue);
      expect(controller.state.players[1].poison, 9);
      expect(controller.state.players[2].energy, 50);
      expect(controller.state.players[3].commanderTax, 8);
      expect(controller.state.players[3].hasInitiative, isTrue);
      expect(controller.state.players[4].commanderDamageTaken['p0'], 20);
      expect(controller.state.players[4].commanderDamageTaken['p1'], 20);
      expect(controller.state.players[4].commanderDamageTaken['p2'], 20);
      expect(controller.state.players[5].floatingMana, {'W': 3, 'U': 4, 'B': 2, 'R': 5, 'G': 6, 'C': 1});
      expect(controller.state.players[5].stormCount, 15);
      expect(controller.state.isDay, isFalse);

      // Execute global Reset Game to 40 life
      await controller.resetGame(40);

      final resetState = controller.state;
      expect(resetState.startingLife, 40);
      expect(resetState.isDay, isTrue, reason: 'Reset game must revert Day/Night cycle to daytime');
      expect(resetState.players.length, 6);

      // Assert all 6 players have completely reset operational counters
      for (int i = 0; i < 6; i++) {
        final p = resetState.players[i];
        expect(p.life, 40, reason: 'Player $i life must return to 40');
        expect(p.poison, 0, reason: 'Player $i poison must be cleared');
        expect(p.energy, 0, reason: 'Player $i energy must be cleared');
        expect(p.experience, 0, reason: 'Player $i experience must be cleared');
        expect(p.commanderTax, 0, reason: 'Player $i commander tax must be cleared');
        expect(p.isMonarch, isFalse, reason: 'Player $i monarch token must be stripped');
        expect(p.hasInitiative, isFalse, reason: 'Player $i initiative token must be stripped');
        expect(p.commanderDamageTaken.isEmpty, isTrue, reason: 'Player $i commander damage must be cleared');
        expect(p.floatingMana, {'W': 0, 'U': 0, 'B': 0, 'R': 0, 'G': 0, 'C': 0});
        expect(p.stormCount, 0, reason: 'Player $i storm count must be cleared');
        expect(p.isEliminated, isFalse, reason: 'Player $i elimination flag must be cleared');
      }

      controller.dispose();
    });

    test('T1.2: Seating positions (0..5), names, deck IDs, and commander art crops strictly preserved', () async {
      final initialPod = createComplex6PlayerPod(startingLife: 40);
      final controller = PodController(initialState: initialPod);

      await controller.resetGame(40);
      final resetState = controller.state;

      final expectedMetadata = [
        ('p0', 0, 'Alice', 'deck_alice_edh', 'cmd_atraxa_id', 'Atraxa, Praetors\' Voice', 'https://cards.scryfall.io/art_crop/atraxa.jpg'),
        ('p1', 1, 'Bob', 'deck_bob_edh', 'cmd_urza_id', 'Urza, Lord High Artificer', 'https://cards.scryfall.io/art_crop/urza.jpg'),
        ('p2', 2, 'Charlie', 'deck_charlie_edh', 'cmd_krenko_id', 'Krenko, Mob Boss', 'https://cards.scryfall.io/art_crop/krenko.jpg'),
        ('p3', 3, 'David', 'deck_david_edh', 'cmd_muldrotha_id', 'Muldrotha, the Gravetide', 'https://cards.scryfall.io/art_crop/muldrotha.jpg'),
        ('p4', 4, 'Eve', 'deck_eve_edh', 'cmd_edgar_id', 'Edgar Markov', 'https://cards.scryfall.io/art_crop/edgar.jpg'),
        ('p5', 5, 'Frank', 'deck_frank_edh', 'cmd_omnath_id', 'Omnath, Locus of All', 'https://cards.scryfall.io/art_crop/omnath.jpg'),
      ];

      for (int i = 0; i < 6; i++) {
        final p = resetState.players[i];
        final expected = expectedMetadata[i];

        expect(p.id, expected.$1, reason: 'Seat $i player ID must not mutate');
        expect(p.seatIndex, expected.$2, reason: 'Seat index $i must be strictly preserved');
        expect(p.name, expected.$3, reason: 'Seat $i player name must be preserved');
        expect(p.deckId, expected.$4, reason: 'Seat $i deck association must be preserved');
        expect(p.commanderCardId, expected.$5, reason: 'Seat $i commander ID must be preserved');
        expect(p.commanderName, expected.$6, reason: 'Seat $i commander name must be preserved');
        expect(p.commanderArtCropUrl, expected.$7, reason: 'Seat $i commander art crop must be preserved');
      }

      controller.dispose();
    });

    test('T1.3: Starting life override parameters (20, 30, 50) cleanly apply to all 6 players', () async {
      final initialPod = createComplex6PlayerPod(startingLife: 40);
      final controller = PodController(initialState: initialPod);

      // Reset to 20 (Standard / Draft format)
      await controller.resetGame(20);
      expect(controller.state.startingLife, 20);
      for (final p in controller.state.players) {
        expect(p.life, 20);
      }

      // Reset to 30 (Brawl format)
      await controller.resetGame(30);
      expect(controller.state.startingLife, 30);
      for (final p in controller.state.players) {
        expect(p.life, 30);
      }

      // Reset to 50 (Custom format)
      await controller.resetGame(50);
      expect(controller.state.startingLife, 50);
      for (final p in controller.state.players) {
        expect(p.life, 50);
      }

      controller.dispose();
    });
  });

  // ===========================================================================
  // GROUP 2: SQLite-Backed MatchSessionRepository 6-Player Reset & Seating Persistence
  // ===========================================================================
  group('Adversarial Group 2: SQLite MatchSessionRepository 6-Player Reset & Drift Persistence', () {
    late AppDatabase database;
    late MatchSessionRepository repository;

    setUp(() async {
      database = AppDatabase(NativeDatabase.memory());
      await database.customSelect('SELECT 1').get();
      repository = MatchSessionRepository(db: database);
    });

    tearDown(() async {
      repository.dispose();
      await database.close();
    });

    test('T2.1: Full Drift Schema v10 6-player session lifecycle: create -> dirty writes -> resetSession(40)', () async {
      final playerConfigs = [
        const PlayerSetupConfig(id: 'p0', seatOrder: 0, name: 'Alice', startingLife: 40, deckId: 'd0', artCropUrl: 'https://ex.com/0.jpg'),
        const PlayerSetupConfig(id: 'p1', seatOrder: 1, name: 'Bob', startingLife: 40, deckId: 'd1', artCropUrl: 'https://ex.com/1.jpg'),
        const PlayerSetupConfig(id: 'p2', seatOrder: 2, name: 'Charlie', startingLife: 40, deckId: 'd2', artCropUrl: 'https://ex.com/2.jpg'),
        const PlayerSetupConfig(id: 'p3', seatOrder: 3, name: 'David', startingLife: 40, deckId: 'd3', artCropUrl: 'https://ex.com/3.jpg'),
        const PlayerSetupConfig(id: 'p4', seatOrder: 4, name: 'Eve', startingLife: 40, deckId: 'd4', artCropUrl: 'https://ex.com/4.jpg'),
        const PlayerSetupConfig(id: 'p5', seatOrder: 5, name: 'Frank', startingLife: 40, deckId: 'd5', artCropUrl: 'https://ex.com/5.jpg'),
      ];

      final createdPod = await repository.createSession(
        format: 'commander',
        startingLife: 40,
        players: playerConfigs,
      );
      final sessionId = createdPod.sessionId;

      // Apply complex dirty states across all 6 players
      await repository.recordLifeDelta(sessionId: sessionId, playerId: 'p0', delta: 12, sequenceNumber: 1); // 52
      await repository.recordCounterChange(sessionId: sessionId, playerId: 'p1', counterType: 'poison', delta: 9, sequenceNumber: 2);
      await repository.recordCounterChange(sessionId: sessionId, playerId: 'p2', counterType: 'energy', delta: 50, sequenceNumber: 3);
      await repository.recordCounterChange(sessionId: sessionId, playerId: 'p3', counterType: 'commander_tax', delta: 8, sequenceNumber: 4);
      await repository.recordCommanderDamage(sessionId: sessionId, targetPlayerId: 'p4', sourcePlayerId: 'p0', delta: 20, sequenceNumber: 5);
      await repository.recordCommanderDamage(sessionId: sessionId, targetPlayerId: 'p4', sourcePlayerId: 'p1', delta: 20, sequenceNumber: 6);
      await repository.recordCommanderDamage(sessionId: sessionId, targetPlayerId: 'p4', sourcePlayerId: 'p2', delta: 20, sequenceNumber: 7);
      await repository.recordManaChange(sessionId: sessionId, playerId: 'p5', color: 'G', delta: 6, sequenceNumber: 8);
      await repository.recordStormChange(sessionId: sessionId, playerId: 'p5', delta: 15, sequenceNumber: 9);
      await repository.flush();

      // Trigger repository.resetSession(40)
      final resetPod = await repository.resetSession(sessionId, 40);

      // Verify reset state returned from repository
      expect(resetPod.startingLife, 40);
      expect(resetPod.players.length, 6);

      for (int i = 0; i < 6; i++) {
        final p = resetPod.players[i];
        expect(p.life, 40);
        expect(p.poison, 0);
        expect(p.energy, 0);
        expect(p.experience, 0);
        expect(p.commanderTax, 0);
        expect(p.commanderDamageTaken.isEmpty, isTrue);
        expect(p.stormCount, 0);
        expect(p.isEliminated, isFalse);

        // Verify seating and profile preservation in returned PodState
        expect(p.seatIndex, i);
        expect(p.id, 'p$i');
        expect(p.name, playerConfigs[i].name);
        expect(p.deckId, playerConfigs[i].deckId);
        expect(p.commanderArtCropUrl, playerConfigs[i].artCropUrl);
      }

      // Reconstitute state directly from fresh SQLite query via restoreActiveSession
      final reconstituted = await repository.restoreActiveSession();
      expect(reconstituted, isNotNull);
      expect(reconstituted!.startingLife, 40);
      expect(reconstituted.players.length, 6);

      for (int i = 0; i < 6; i++) {
        final p = reconstituted.players[i];
        expect(p.life, 40);
        expect(p.poison, 0);
        expect(p.energy, 0);
        expect(p.seatIndex, i);
        expect(p.deckId, playerConfigs[i].deckId);
        expect(p.commanderArtCropUrl, playerConfigs[i].artCropUrl);
      }

      // Direct Drift table inspection
      final dbPlayers = await (database.select(database.matchPlayers)
            ..where((t) => t.sessionId.equals(sessionId) & t.isDeleted.equals(false))
            ..orderBy([(t) => drift.OrderingTerm(expression: t.seatOrder)]))
          .get();

      expect(dbPlayers.length, 6);
      for (int i = 0; i < 6; i++) {
        final dbP = dbPlayers[i];
        expect(dbP.currentLife, 40);
        expect(dbP.poison, 0);
        expect(dbP.energy, 0);
        expect(dbP.seatOrder, i);
        expect(dbP.deckId, playerConfigs[i].deckId);
        expect(dbP.commanderDamageJson, '{}');
      }
    });

    test('T2.2: ResetSession inserts administrative reset event into matchEvents ledger', () async {
      final createdPod = await repository.createSession(
        format: 'commander',
        startingLife: 40,
        players: [
          const PlayerSetupConfig(id: 'p0', seatOrder: 0, name: 'Alice', startingLife: 40),
          const PlayerSetupConfig(id: 'p1', seatOrder: 1, name: 'Bob', startingLife: 40),
        ],
      );
      final sessionId = createdPod.sessionId;

      await repository.recordLifeDelta(sessionId: sessionId, playerId: 'p0', delta: 5, sequenceNumber: 1);
      await repository.resetSession(sessionId, 40);

      final events = await (database.select(database.matchEvents)
            ..where((t) => t.sessionId.equals(sessionId) & t.isDeleted.equals(false))
            ..orderBy([(t) => drift.OrderingTerm(expression: t.sequenceNumber)]))
          .get();

      final resetEvents = events.where((e) => e.eventType == 'reset').toList();
      expect(resetEvents.length, 1);
      expect(resetEvents.first.value, 40);
      expect(resetEvents.first.payloadJson, contains('lobby_reset'));
    });
  });

  // ===========================================================================
  // GROUP 3: ResetGameDialog UI & PodScaffoldWidget 6-Player Integration
  // ===========================================================================
  group('Adversarial Group 3: ResetGameDialog UI & PodScaffoldWidget 6-Player Integration', () {
    testWidgets('T3.1A: ResetGameDialog cancel button dismisses dialog and invokes onCancel callback', (tester) async {
      bool resetConfirmed = false;
      bool resetCancelled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                key: const Key('open_dialog_btn'),
                onPressed: () {
                  ResetGameDialog.show(
                    ctx,
                    startingLife: 40,
                    onConfirm: () => resetConfirmed = true,
                    onCancel: () => resetCancelled = true,
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.byKey(const Key('open_dialog_btn')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('reset_game_dialog')), findsOneWidget);
      expect(
        find.text(
          'Reset current game? Life totals will return to 40 and all counters/mana will be cleared. Seating and commanders will be preserved.',
        ),
        findsOneWidget,
      );

      // Test Cancel dismissal
      await tester.tap(find.byKey(const Key('cancel_reset_game_btn')));
      await tester.pumpAndSettle();

      expect(resetConfirmed, isFalse);
      expect(resetCancelled, isTrue);
      expect(find.byKey(const Key('reset_game_dialog')), findsNothing);
    });

    testWidgets('T3.1B: ResetGameDialog confirm button invokes onConfirm callback', (tester) async {
      bool resetConfirmed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                key: const Key('open_dialog_btn'),
                onPressed: () {
                  ResetGameDialog.show(
                    ctx,
                    startingLife: 40,
                    onConfirm: () => resetConfirmed = true,
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.byKey(const Key('open_dialog_btn')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('reset_game_dialog')), findsOneWidget);

      // Tap confirm
      await tester.tap(find.byKey(const Key('confirm_reset_game_btn')));
      await tester.pumpAndSettle();

      expect(resetConfirmed, isTrue);
      expect(find.byKey(const Key('reset_game_dialog')), findsNothing);
    });

    testWidgets('T3.1C: ResetGameDialog.show single-pop dismisses dialog and preserves host navigator route', (tester) async {
      // Verifies that ResetGameDialog.show() passes onConfirm and onCancel directly
      // without wrapping them in extra Navigator.pop(ctx) calls, ensuring only a single
      // pop occurs upon dialog dismissal and the host match screen is preserved.
      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          home: const Scaffold(
            body: Text('Root Screen'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Push active game screen
      navigatorKey.currentState!.push(
        MaterialPageRoute<void>(
          builder: (ctx) => Scaffold(
            body: Column(
              children: [
                const Text('Active Match Screen'),
                ElevatedButton(
                  key: const Key('trigger_reset_btn'),
                  onPressed: () {
                    ResetGameDialog.show(
                      ctx,
                      startingLife: 40,
                      onConfirm: () {},
                      onCancel: () {},
                    );
                  },
                  child: const Text('Reset'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Active Match Screen'), findsOneWidget);

      // Open Reset Game dialog
      await tester.tap(find.byKey(const Key('trigger_reset_btn')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('reset_game_dialog')), findsOneWidget);

      // Tap Cancel: User only wants to cancel the reset and stay in the match
      await tester.tap(find.byKey(const Key('cancel_reset_game_btn')));
      await tester.pumpAndSettle();

      // Dialog is dismissed
      expect(find.byKey(const Key('reset_game_dialog')), findsNothing);

      // Verified: 'Active Match Screen' is preserved on top of the navigator stack
      final hostScreenSurvived = find.text('Active Match Screen').evaluate().isNotEmpty;
      expect(hostScreenSurvived, isTrue, reason: 'Remediation verified: host match screen survived dialog dismissal');
      expect(find.text('Active Match Screen'), findsOneWidget);
    });

    testWidgets('T3.1D: ResetGameDialog.show confirmation dismisses dialog and preserves host navigator route', (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      bool resetConfirmed = false;

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          home: const Scaffold(
            body: Text('Root Screen'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Push active game screen
      navigatorKey.currentState!.push(
        MaterialPageRoute<void>(
          builder: (ctx) => Scaffold(
            body: Column(
              children: [
                const Text('Active Match Screen'),
                ElevatedButton(
                  key: const Key('trigger_reset_btn'),
                  onPressed: () {
                    ResetGameDialog.show(
                      ctx,
                      startingLife: 40,
                      onConfirm: () => resetConfirmed = true,
                      onCancel: () {},
                    );
                  },
                  child: const Text('Reset'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Active Match Screen'), findsOneWidget);

      // Open Reset Game dialog
      await tester.tap(find.byKey(const Key('trigger_reset_btn')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('reset_game_dialog')), findsOneWidget);

      // Tap Confirm
      await tester.tap(find.byKey(const Key('confirm_reset_game_btn')));
      await tester.pumpAndSettle();

      // Dialog is dismissed and callback executed
      expect(find.byKey(const Key('reset_game_dialog')), findsNothing);
      expect(resetConfirmed, isTrue);

      // Verified: 'Active Match Screen' is preserved on top of the navigator stack
      final hostScreenSurvived = find.text('Active Match Screen').evaluate().isNotEmpty;
      expect(hostScreenSurvived, isTrue, reason: 'Remediation verified: host match screen survived dialog confirmation');
      expect(find.text('Active Match Screen'), findsOneWidget);
    });

    testWidgets('T3.2: 6-Player PodScaffoldWidget center crossroads button opens RandomizerHubModal and triggers reset callback', (tester) async {
      bool resetExecuted = false;
      final pod6P = createComplex6PlayerPod(startingLife: 40);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PodScaffoldWidget(
              podState: pod6P,
              onResetGame: () => resetExecuted = true,
            ),
          ),
        ),
      );
      await tester.pump();

      // Find center hub crossroads button
      expect(find.byType(CenterHubButton), findsOneWidget);

      // Tap crossroads button to present RandomizerHubModal
      await tester.tap(find.byType(CenterHubButton));
      await tester.pumpAndSettle();

      expect(find.byType(RandomizerHubModal), findsOneWidget);
      expect(find.byKey(const Key('reset_game_btn')), findsOneWidget);

      // Tap reset game button
      await tester.tap(find.byKey(const Key('reset_game_btn')));
      await tester.pumpAndSettle();

      expect(resetExecuted, isTrue);
      expect(find.byType(RandomizerHubModal), findsNothing);
    });

    testWidgets('T3.3: Live 6-Player interactive widget tree reflects 40 life after reset confirmation', (tester) async {
      PodState activePod = createComplex6PlayerPod(startingLife: 40);

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              home: Scaffold(
                body: PodScaffoldWidget(
                  podState: activePod,
                  onResetGame: () {
                    setState(() {
                      final resetPlayers = activePod.players.map((p) {
                        return p.copyWith(
                          life: 40,
                          poison: 0,
                          energy: 0,
                          experience: 0,
                          commanderTax: 0,
                          isMonarch: false,
                          hasInitiative: false,
                          commanderDamageTaken: const {},
                          floatingMana: const {'W': 0, 'U': 0, 'B': 0, 'R': 0, 'G': 0, 'C': 0},
                          stormCount: 0,
                          isEliminated: false,
                        );
                      }).toList();
                      activePod = activePod.copyWith(
                        startingLife: 40,
                        players: resetPlayers,
                        isDay: true,
                      );
                    });
                  },
                ),
              ),
            );
          },
        ),
      );
      await tester.pump();

      // Verify dirty pre-reset life visible in tree (e.g. 52, 12, 8, 3, 29, 41)
      expect(find.text('52'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);

      // Open Center Crossroads -> RandomizerHubModal -> Reset Game
      await tester.tap(find.byType(CenterHubButton));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('reset_game_btn')));
      await tester.pumpAndSettle();

      // All 6 players now display 40 life in the widget tree
      expect(find.text('40'), findsNWidgets(6));
      expect(find.text('52'), findsNothing);
      expect(find.text('12'), findsNothing);
      expect(find.text('8'), findsNothing);
      expect(find.text('3'), findsNothing);
    });
  });

  // ===========================================================================
  // GROUP 4: Repeated Rapid Reset-Undo Cycles Stress Harness
  // ===========================================================================
  group('Adversarial Group 4: Repeated Rapid Reset-Undo Cycles Stress Harness', () {
    test('T4.1: Standalone PodController 30 rapid alternating delta-reset cycles maintain invariant monotonicity', () async {
      final initialPod = createComplex6PlayerPod(startingLife: 40);
      final controller = PodController(initialState: initialPod);

      for (int cycle = 0; cycle < 30; cycle++) {
        // Step A: Modify player life
        await controller.adjustLife('p0', 5);
        expect(controller.state.getPlayer('p0')!.life, 45 + (cycle == 0 ? 12 : 0));

        // Step B: Reset game to 40
        await controller.resetGame(40);
        expect(controller.state.startingLife, 40);
        expect(controller.state.getPlayer('p0')!.life, 40);

        // Step C: Verify undo() gracefully returns false without repository
        final undoResult = await controller.undo();
        expect(undoResult, isFalse);

        // Seating order invariant preserved
        for (int s = 0; s < 6; s++) {
          expect(controller.state.players[s].seatIndex, s);
          expect(controller.state.players[s].id, 'p$s');
        }
      }

      controller.dispose();
    });

    test('T4.2: SQLite repository-backed 20 rapid alternating life delta -> undo -> reset cycles without deadlock or corrupt ledger', () async {
      final db = AppDatabase(NativeDatabase.memory());
      await db.customSelect('SELECT 1').get();
      final repo = MatchSessionRepository(db: db);

      final pod = await repo.createSession(
        format: 'commander',
        startingLife: 40,
        players: [
          const PlayerSetupConfig(id: 'p0', seatOrder: 0, name: 'Alice', startingLife: 40, deckId: 'd0', artCropUrl: 'https://ex.com/0.jpg'),
          const PlayerSetupConfig(id: 'p1', seatOrder: 1, name: 'Bob', startingLife: 40, deckId: 'd1', artCropUrl: 'https://ex.com/1.jpg'),
        ],
      );

      final controller = PodController(initialState: pod, repository: repo);

      for (int cycle = 1; cycle <= 20; cycle++) {
        // 1. Adjust Alice life by +3
        await controller.adjustLife('p0', 3);
        expect(controller.state.getPlayer('p0')!.life, 43);

        // 2. Undo: undo rolls back the preceding life delta back to 40
        final undone = await controller.undo();
        expect(undone, isTrue);
        expect(controller.state.getPlayer('p0')!.life, 40);

        // 3. Reset game back to 40
        await controller.resetGame(40);
        expect(controller.state.getPlayer('p0')!.life, 40);

        // 4. Verify seating remains completely intact
        expect(controller.state.players[0].seatIndex, 0);
        expect(controller.state.players[0].name, 'Alice');
        expect(controller.state.players[1].seatIndex, 1);
        expect(controller.state.players[1].name, 'Bob');
      }

      controller.dispose();
      repo.dispose();
      await db.close();
    });

    test('T4.3: Rapid starting life template switching (40 -> 20 -> 30 -> 100 -> 40) preserves player profile identity', () async {
      final initialPod = createComplex6PlayerPod(startingLife: 40);
      final controller = PodController(initialState: initialPod);

      final templates = [20, 30, 100, 40, 25, 50, 40];

      for (final template in templates) {
        await controller.resetGame(template);
        expect(controller.state.startingLife, template);
        for (int i = 0; i < 6; i++) {
          expect(controller.state.players[i].life, template);
          expect(controller.state.players[i].seatIndex, i);
          expect(controller.state.players[i].id, 'p$i');
          expect(controller.state.players[i].deckId, contains('deck_'));
        }
      }

      controller.dispose();
    });
  });

  // ===========================================================================
  // GROUP 5: PlayTrackAccordion Rapid Expansion/Collapse & Screen Constraint Stress
  // ===========================================================================
  group('Adversarial Group 5: PlayTrackAccordion Rapid Expansion/Collapse & Screen Constraints', () {
    testWidgets('T5.1: Rapid accordion expansion/collapse stress: 20 sequential toggles across MTG, Pokémon, Lorcana', (tester) async {
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

      for (int i = 0; i < 20; i++) {
        // Tap MTG
        await tester.tap(find.text('MTG'));
        await tester.pump(const Duration(milliseconds: 100));

        // Tap Pokémon
        await tester.tap(find.text('Pokémon'));
        await tester.pump(const Duration(milliseconds: 100));

        // Tap Lorcana
        await tester.tap(find.text('Lorcana'));
        await tester.pump(const Duration(milliseconds: 100));
      }

      await tester.pumpAndSettle();
      expect(find.text('Play / Track +'), findsOneWidget);
    });

    testWidgets('T5.2: Screen constraint stress: renders cleanly without overflow across 5 standard & extreme viewports', (tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final viewports = [
        const Size(320, 480),   // Compact mobile
        const Size(390, 844),   // Standard iPhone
        const Size(768, 1024),  // Tablet portrait
        const Size(1024, 768),  // Tablet landscape
        const Size(1920, 1080), // Desktop ultra-wide
      ];

      for (final size in viewports) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: PlayTrackAccordion(
                  key: ValueKey('accordion_${size.width.toInt()}_${size.height.toInt()}'),
                  onModeSelected: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Play / Track +'), findsOneWidget);
        expect(find.text('MTG'), findsOneWidget);

        // Tap MTG directly launches PregameSetupSheet
        await tester.tap(find.text('MTG'));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('pregame_setup_sheet')), findsOneWidget);

        // Close the bottom sheet for next viewport
        await tester.tap(find.byIcon(Icons.close).first);
        await tester.pumpAndSettle();
      }
    });

    testWidgets('T5.3: MTG format launch hooks: tapping MTG card directly invokes onLaunchMtgMode with Commander format', (tester) async {
      String? launchedFormat;
      int launchCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PlayTrackAccordion(
                onModeSelected: () {},
                onLaunchMtgMode: (format) {
                  launchedFormat = format;
                  launchCount++;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap MTG directly
      await tester.tap(find.text('MTG'));
      await tester.pump();
      expect(launchedFormat, 'Commander');
      expect(launchCount, 1);
    });

    testWidgets('T5.4: Fallback launch presents PregameSetupSheet when onLaunchMtgMode is null', (tester) async {
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

      // Tap MTG directly launches PregameSetupSheet
      await tester.tap(find.text('MTG'));
      await tester.pumpAndSettle();

      expect(modeSelectedCalled, isTrue);
      expect(find.byKey(const Key('pregame_setup_sheet')), findsOneWidget);
    });

    testWidgets('T5.5: Non-MTG formats trigger onModeSelected and directly launch PregameSetupSheet with appropriate TCG context', (tester) async {
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

      // Tap Lorcana directly
      await tester.tap(find.text('Lorcana'));
      await tester.pumpAndSettle();

      expect(modeSelectedCalled, isTrue);
      expect(find.byKey(const Key('pregame_setup_sheet')), findsOneWidget);
      expect(PregameSetupSheet.lastTcg, equals('Disney Lorcana'));
    });
  });
}
