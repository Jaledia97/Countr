// Copyright (c) 2026 Countr. All rights reserved.
// Milestone 5 Gate: Challenger M5-2 Empirical Adversarial Stress Suite for Smart Reset & SQLite Sync.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;

import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/life_counter/domain/models/pod_state.dart';
import 'package:countr/features/life_counter/presentation/controllers/pod_controller.dart';
import 'package:countr/features/life_counter/presentation/dialogs/reset_game_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late VaultDao vaultDao;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    vaultDao = VaultDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  /// Helper to instantiate a realistic test player with full secondary counters.
  PodPlayerState createPlayer({
    required String id,
    required int seatIndex,
    required String name,
    int life = 40,
    String? deckId,
    String? commanderName,
    String? colorTheme,
    int poison = 0,
    int energy = 0,
    int experience = 0,
    int commanderTax = 0,
    int radCounters = 0,
    bool isMonarch = false,
    bool hasInitiative = false,
    Map<String, int>? commanderDamage,
    Map<String, int>? mana,
    int storm = 0,
  }) {
    return PodPlayerState(
      id: id,
      seatIndex: seatIndex,
      name: name,
      deckId: deckId,
      commanderName: commanderName,
      colorTheme: colorTheme,
      life: life,
      poison: poison,
      energy: energy,
      experience: experience,
      commanderTax: commanderTax,
      radCounters: radCounters,
      isMonarch: isMonarch,
      hasInitiative: hasInitiative,
      commanderDamageTaken: commanderDamage ?? {},
      floatingMana: mana ?? {'W': 0, 'U': 0, 'B': 0, 'R': 0, 'G': 0, 'C': 0},
      stormCount: storm,
    );
  }

  /// Helper to seed decks into the SQLite database.
  Future<void> seedDecks(List<String> deckIds) async {
    final now = DateTime.now().subtract(const Duration(hours: 1));
    for (final id in deckIds) {
      await db.into(db.decks).insert(
            DecksCompanion.insert(
              id: id,
              name: 'Deck $id',
              format: 'commander',
              createdAt: now,
              updatedAt: drift.Value(now),
              wins: const drift.Value(0),
              losses: const drift.Value(0),
              draws: const drift.Value(0),
            ),
          );
    }
  }

  // ===========================================================================
  // GROUP 1: Dialog Interactions — Winner & Draw Pills Selection & Toggling
  // ===========================================================================
  group('Group 1: Dialog Winner & Draw Pills Interaction Stress', () {
    testWidgets('1.1: Winner selection pill displays correct data and applies gold highlight', (tester) async {
      final players = [
        createPlayer(id: 'p1', seatIndex: 0, name: 'Alice', life: 34),
        createPlayer(id: 'p2', seatIndex: 1, name: 'Bob', life: 0),
        createPlayer(id: 'p3', seatIndex: 2, name: 'Charlie', life: 19),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                key: const Key('open_dialog_btn'),
                onPressed: () => ResetGameDialog.show(
                  ctx,
                  startingLife: 40,
                  players: players,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('open_dialog_btn')));
      await tester.pumpAndSettle();

      // Verify pills rendered
      expect(find.byKey(const Key('reset_winner_pill_p1')), findsOneWidget);
      expect(find.byKey(const Key('reset_winner_pill_p2')), findsOneWidget);
      expect(find.byKey(const Key('reset_winner_pill_p3')), findsOneWidget);
      expect(find.text('Alice  34'), findsOneWidget);
      expect(find.text('Bob  0'), findsOneWidget);
      expect(find.text('Charlie  19'), findsOneWidget);

      // Initially no trophy icon
      expect(find.byIcon(Icons.emoji_events), findsNothing);

      // Tap Alice's pill
      await tester.tap(find.byKey(const Key('reset_winner_pill_p1')));
      await tester.pump();

      // Now trophy icon appears
      expect(find.byIcon(Icons.emoji_events), findsOneWidget);

      // Verify container styling for Alice (selected)
      final aliceContainer = tester.widget<Container>(
        find.descendant(
          of: find.byKey(const Key('reset_winner_pill_p1')),
          matching: find.byType(Container),
        ),
      );
      final aliceDecoration = aliceContainer.decoration as BoxDecoration;
      final aliceBorder = aliceDecoration.border as Border;
      expect(aliceBorder.top.color, AppColors.accentGold);
      expect(aliceBorder.top.width, 1.5);
      expect(aliceDecoration.color, AppColors.accentGold.withValues(alpha: 0.25));

      // Verify container styling for Bob (unselected)
      final bobContainer = tester.widget<Container>(
        find.descendant(
          of: find.byKey(const Key('reset_winner_pill_p2')),
          matching: find.byType(Container),
        ),
      );
      final bobDecoration = bobContainer.decoration as BoxDecoration;
      final bobBorder = bobDecoration.border as Border;
      expect(bobBorder.top.color, Colors.white24);
      expect(bobBorder.top.width, 1.0);
    });

    testWidgets('1.2: Draw pill highlights with cyan and deselects winner', (tester) async {
      final players = [
        createPlayer(id: 'p1', seatIndex: 0, name: 'Alice', life: 25),
        createPlayer(id: 'p2', seatIndex: 1, name: 'Bob', life: 25),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                key: const Key('open_dialog_btn'),
                onPressed: () => ResetGameDialog.show(
                  ctx,
                  startingLife: 40,
                  players: players,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('open_dialog_btn')));
      await tester.pumpAndSettle();

      // Tap Alice (Winner)
      await tester.tap(find.byKey(const Key('reset_winner_pill_p1')));
      await tester.pump();
      expect(find.byIcon(Icons.emoji_events), findsOneWidget);
      expect(find.byIcon(Icons.handshake), findsNothing);

      // Tap Draw pill
      await tester.tap(find.byKey(const Key('reset_draw_pill')));
      await tester.pump();

      // Winner is deselected (no trophy icon), Draw is selected (handshake icon visible)
      expect(find.byIcon(Icons.emoji_events), findsNothing);
      expect(find.byIcon(Icons.handshake), findsOneWidget);

      // Verify Draw container decoration
      final drawContainer = tester.widget<Container>(
        find.descendant(
          of: find.byKey(const Key('reset_draw_pill')),
          matching: find.byType(Container),
        ),
      );
      final drawDecoration = drawContainer.decoration as BoxDecoration;
      final drawBorder = drawDecoration.border as Border;
      expect(drawBorder.top.color, AppColors.accentCyan);
      expect(drawBorder.top.width, 1.5);
      expect(drawDecoration.color, AppColors.accentCyan.withValues(alpha: 0.25));
    });

    testWidgets('1.3: Mutual exclusion & de-selection on re-tap stress', (tester) async {
      final players = [
        createPlayer(id: 'p1', seatIndex: 0, name: 'Alice', life: 40),
        createPlayer(id: 'p2', seatIndex: 1, name: 'Bob', life: 30),
      ];

      ResetGameResult? finalResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                key: const Key('open_dialog_btn'),
                onPressed: () => ResetGameDialog.show(
                  ctx,
                  startingLife: 40,
                  players: players,
                  onConfirmAction: (res) => finalResult = res,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('open_dialog_btn')));
      await tester.pumpAndSettle();

      // Step A: Tap Alice -> Alice selected
      await tester.tap(find.byKey(const Key('reset_winner_pill_p1')));
      await tester.pump();
      expect(find.byIcon(Icons.emoji_events), findsOneWidget);

      // Step B: Re-tap Alice -> Alice deselected!
      await tester.tap(find.byKey(const Key('reset_winner_pill_p1')));
      await tester.pump();
      expect(find.byIcon(Icons.emoji_events), findsNothing);
      expect(find.byIcon(Icons.handshake), findsNothing);

      // Step C: Tap Draw -> Draw selected
      await tester.tap(find.byKey(const Key('reset_draw_pill')));
      await tester.pump();
      expect(find.byIcon(Icons.handshake), findsOneWidget);

      // Step D: Re-tap Draw -> Draw deselected!
      await tester.tap(find.byKey(const Key('reset_draw_pill')));
      await tester.pump();
      expect(find.byIcon(Icons.handshake), findsNothing);

      // Step E: Tap Draw, then tap Bob -> Draw deselected, Bob selected
      await tester.tap(find.byKey(const Key('reset_draw_pill')));
      await tester.pump();
      expect(find.byIcon(Icons.handshake), findsOneWidget);

      await tester.tap(find.byKey(const Key('reset_winner_pill_p2')));
      await tester.pump();
      expect(find.byIcon(Icons.handshake), findsNothing);
      expect(find.byIcon(Icons.emoji_events), findsOneWidget);

      // Step F: Tap Alice -> Bob deselected, Alice selected
      await tester.tap(find.byKey(const Key('reset_winner_pill_p1')));
      await tester.pump();
      expect(find.byIcon(Icons.emoji_events), findsOneWidget);

      // Re-tap Alice to leave no winner selected
      await tester.tap(find.byKey(const Key('reset_winner_pill_p1')));
      await tester.pump();
      expect(find.byIcon(Icons.emoji_events), findsNothing);

      // Confirm Reset without winner or draw
      await tester.tap(find.byKey(const Key('confirm_reset_game_btn')));
      await tester.pumpAndSettle();

      expect(finalResult, isNotNull);
      expect(finalResult!.action, ResetGameAction.reset);
      expect(finalResult!.winningPlayerId, isNull);
      expect(finalResult!.isDraw, isFalse);
    });
  });

  // ===========================================================================
  // GROUP 2: Dialog Interactions — All 4 Action Buttons & State Transformations
  // ===========================================================================
  group('Group 2: Dialog Action Buttons & State Transformations Stress', () {
    testWidgets('2.1: Action 1 (Reset) resets life and counters, preserves seats and profiles', (tester) async {
      final complexPod = PodState(
        sessionId: 'test_pod_reset_action',
        format: 'commander',
        startingLife: 40,
        players: [
          createPlayer(
            id: 'p1',
            seatIndex: 0,
            name: 'Alice',
            life: 11,
            deckId: 'deck_alice',
            commanderName: 'Atraxa',
            colorTheme: 'cyan',
            poison: 4,
            energy: 6,
            experience: 2,
            commanderTax: 4,
            radCounters: 3,
            isMonarch: true,
            hasInitiative: false,
            commanderDamage: {'p2': 18},
            mana: {'W': 2, 'U': 0, 'B': 1, 'R': 0, 'G': 3, 'C': 0},
            storm: 4,
          ),
          createPlayer(
            id: 'p2',
            seatIndex: 1,
            name: 'Bob',
            life: 28,
            deckId: 'deck_bob',
            commanderName: 'Urza',
            colorTheme: 'blue',
            poison: 0,
            energy: 10,
            experience: 0,
            commanderTax: 2,
            radCounters: 0,
            isMonarch: false,
            hasInitiative: true,
            commanderDamage: {'p1': 8},
            mana: {'W': 0, 'U': 5, 'B': 0, 'R': 0, 'G': 0, 'C': 2},
            storm: 2,
          ),
        ],
      );

      final controller = PodController(initialState: complexPod);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                key: const Key('open_dialog_btn'),
                onPressed: () => ResetGameDialog.show(
                  ctx,
                  startingLife: controller.state.startingLife,
                  players: controller.state.players,
                  onConfirmAction: (res) {
                    if (res.action == ResetGameAction.reset) {
                      controller.resetGame();
                    }
                  },
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('open_dialog_btn')));
      await tester.pumpAndSettle();

      // Tap Reset button
      await tester.tap(find.byKey(const Key('confirm_reset_game_btn')));
      await tester.pumpAndSettle();

      final state = controller.state;
      expect(state.players.length, 2);

      // Verify Player 1 counters reset and profiles preserved
      final p1 = state.players[0];
      expect(p1.id, 'p1');
      expect(p1.seatIndex, 0);
      expect(p1.name, 'Alice');
      expect(p1.deckId, 'deck_alice');
      expect(p1.commanderName, 'Atraxa');
      expect(p1.colorTheme, 'cyan');
      expect(p1.life, 40);
      expect(p1.poison, 0);
      expect(p1.energy, 0);
      expect(p1.experience, 0);
      expect(p1.commanderTax, 0);
      expect(p1.radCounters, 0);
      expect(p1.isMonarch, isFalse);
      expect(p1.hasInitiative, isFalse);
      expect(p1.commanderDamageTaken.isEmpty, isTrue);
      expect(p1.floatingMana, {'W': 0, 'U': 0, 'B': 0, 'R': 0, 'G': 0, 'C': 0});
      expect(p1.stormCount, 0);

      // Verify Player 2
      final p2 = state.players[1];
      expect(p2.id, 'p2');
      expect(p2.seatIndex, 1);
      expect(p2.name, 'Bob');
      expect(p2.deckId, 'deck_bob');
      expect(p2.commanderName, 'Urza');
      expect(p2.colorTheme, 'blue');
      expect(p2.life, 40);
      expect(p2.poison, 0);
      expect(p2.energy, 0);
      expect(p2.commanderTax, 0);
      expect(p2.isMonarch, isFalse);
      expect(p2.hasInitiative, isFalse);
      expect(p2.commanderDamageTaken.isEmpty, isTrue);
    });

    testWidgets('2.2: Action 2 (Reset + randomize seats) shuffles seats, re-indexes 0..N-1, preserves profiles', (tester) async {
      final pod = PodState(
        sessionId: 'test_pod_randomize',
        format: 'commander',
        startingLife: 40,
        players: [
          createPlayer(id: 'p1', seatIndex: 0, name: 'Alice', deckId: 'deck_1', life: 10, poison: 5),
          createPlayer(id: 'p2', seatIndex: 1, name: 'Bob', deckId: 'deck_2', life: 20, poison: 2),
          createPlayer(id: 'p3', seatIndex: 2, name: 'Charlie', deckId: 'deck_3', life: 30, poison: 1),
          createPlayer(id: 'p4', seatIndex: 3, name: 'Dave', deckId: 'deck_4', life: 40, poison: 0),
        ],
      );

      final controller = PodController(initialState: pod);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                key: const Key('open_dialog_btn'),
                onPressed: () => ResetGameDialog.show(
                  ctx,
                  startingLife: controller.state.startingLife,
                  players: controller.state.players,
                  onConfirmAction: (res) {
                    if (res.action == ResetGameAction.resetRandomizeSeats) {
                      controller.resetAndRandomizeSeats();
                    }
                  },
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('open_dialog_btn')));
      await tester.pumpAndSettle();

      // Tap Reset + randomize seats
      await tester.tap(find.byKey(const Key('reset_randomize_seats_btn')));
      await tester.pumpAndSettle();

      final state = controller.state;
      expect(state.players.length, 4);

      // Verify all seat indices are strictly 0, 1, 2, 3
      final seatIndices = state.players.map((p) => p.seatIndex).toList();
      expect(seatIndices, equals([0, 1, 2, 3]));

      // Verify every player's life was reset to 40 and poison to 0
      for (final p in state.players) {
        expect(p.life, 40);
        expect(p.poison, 0);
      }

      // Verify each player retains their original profile attached to their ID
      final alice = state.players.firstWhere((p) => p.id == 'p1');
      expect(alice.name, 'Alice');
      expect(alice.deckId, 'deck_1');

      final bob = state.players.firstWhere((p) => p.id == 'p2');
      expect(bob.name, 'Bob');
      expect(bob.deckId, 'deck_2');

      final charlie = state.players.firstWhere((p) => p.id == 'p3');
      expect(charlie.name, 'Charlie');
      expect(charlie.deckId, 'deck_3');

      final dave = state.players.firstWhere((p) => p.id == 'p4');
      expect(dave.name, 'Dave');
      expect(dave.deckId, 'deck_4');
    });

    testWidgets('2.3: Action 3 (Reset + clear profiles) resets names to Player N and nullifies deckId', (tester) async {
      final pod = PodState(
        sessionId: 'test_pod_clear_profiles',
        format: 'commander',
        startingLife: 40,
        players: [
          createPlayer(id: 'p1', seatIndex: 0, name: 'Alice', deckId: 'deck_1', commanderName: 'Atraxa', colorTheme: 'cyan', life: 12),
          createPlayer(id: 'p2', seatIndex: 1, name: 'Bob', deckId: 'deck_2', commanderName: 'Urza', colorTheme: 'blue', life: 23),
          createPlayer(id: 'p3', seatIndex: 2, name: 'Charlie', deckId: 'deck_3', commanderName: 'Krenko', colorTheme: 'red', life: 34),
        ],
      );

      final controller = PodController(initialState: pod);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                key: const Key('open_dialog_btn'),
                onPressed: () => ResetGameDialog.show(
                  ctx,
                  startingLife: controller.state.startingLife,
                  players: controller.state.players,
                  onConfirmAction: (res) {
                    if (res.action == ResetGameAction.resetClearProfiles) {
                      controller.resetAndClearProfiles();
                    }
                  },
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('open_dialog_btn')));
      await tester.pumpAndSettle();

      // Tap Reset + clear profiles
      await tester.tap(find.byKey(const Key('reset_clear_profiles_btn')));
      await tester.pumpAndSettle();

      final state = controller.state;
      expect(state.players.length, 3);

      expect(state.players[0].name, 'Player 1');
      expect(state.players[0].deckId, isNull);
      expect(state.players[0].commanderName, isNull);
      expect(state.players[0].colorTheme, isNull);
      expect(state.players[0].life, 40);

      expect(state.players[1].name, 'Player 2');
      expect(state.players[1].deckId, isNull);
      expect(state.players[1].commanderName, isNull);
      expect(state.players[1].colorTheme, isNull);
      expect(state.players[1].life, 40);

      expect(state.players[2].name, 'Player 3');
      expect(state.players[2].deckId, isNull);
      expect(state.players[2].commanderName, isNull);
      expect(state.players[2].colorTheme, isNull);
      expect(state.players[2].life, 40);
    });

    testWidgets('2.4: Action 4 (Cancel) dismisses dialog, invokes onCancel callback, preserves state', (tester) async {
      bool cancelInvoked = false;
      bool confirmInvoked = false;
      ResetGameResult? resultReceived;

      final pod = PodState(
        sessionId: 'test_cancel_pod',
        format: 'commander',
        startingLife: 40,
        players: [
          createPlayer(id: 'p1', seatIndex: 0, name: 'Alice', life: 17, poison: 4),
        ],
      );

      final controller = PodController(initialState: pod);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                key: const Key('open_dialog_btn'),
                onPressed: () async {
                  final res = await ResetGameDialog.show(
                    ctx,
                    startingLife: controller.state.startingLife,
                    players: controller.state.players,
                    onConfirm: () => confirmInvoked = true,
                    onConfirmAction: (r) => resultReceived = r,
                    onCancel: () => cancelInvoked = true,
                  );
                  if (res != null) {
                    controller.resetGame();
                  }
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('open_dialog_btn')));
      await tester.pumpAndSettle();

      // Tap Cancel
      await tester.tap(find.byKey(const Key('cancel_reset_game_btn')));
      await tester.pumpAndSettle();

      expect(cancelInvoked, isTrue);
      expect(confirmInvoked, isFalse);
      expect(resultReceived, isNull);
      expect(find.byKey(const Key('reset_game_dialog')), findsNothing);

      // Verify controller state is unchanged
      expect(controller.state.players[0].life, 17);
      expect(controller.state.players[0].poison, 4);
    });
  });

  // ===========================================================================
  // GROUP 3: SQLite Database Sync — Invariants, Nulls, & Edge Cases
  // ===========================================================================
  group('Group 3: VaultDao.recordDeckMatchResults Direct SQLite Stress', () {
    test('3.1: Single winner: winner wins += 1, losers losses += 1, updatedAt bumped, syncQueue populated', () async {
      await seedDecks(['deck_a', 'deck_b', 'deck_c', 'deck_d']);

      final before = DateTime.now();

      await vaultDao.recordDeckMatchResults(
        winningDeckId: 'deck_a',
        losingDeckIds: ['deck_b', 'deck_c', 'deck_d'],
      );

      // Deck A (Winner)
      final deckA = await (db.select(db.decks)..where((t) => t.id.equals('deck_a'))).getSingle();
      expect(deckA.wins, 1);
      expect(deckA.losses, 0);
      expect(deckA.draws, 0);
      expect(deckA.updatedAt, isNotNull);
      expect(deckA.updatedAt!.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);

      // Decks B, C, D (Losers)
      for (final loserId in ['deck_b', 'deck_c', 'deck_d']) {
        final loser = await (db.select(db.decks)..where((t) => t.id.equals(loserId))).getSingle();
        expect(loser.wins, 0);
        expect(loser.losses, 1);
        expect(loser.draws, 0);
      }

      // Check syncQueue entries
      final outbox = await db.select(db.syncQueue).get();
      expect(outbox.length, 4);
      final outboxDeckIds = outbox.map((e) => e.entityId).toSet();
      expect(outboxDeckIds, containsAll(['deck_a', 'deck_b', 'deck_c', 'deck_d']));
      for (final entry in outbox) {
        expect(entry.entityType, 'deck');
        expect(entry.operation, 'UPDATE');
      }
    });

    test('3.2: Draw: all linked decks draws += 1', () async {
      await seedDecks(['deck_1', 'deck_2']);

      await vaultDao.recordDeckMatchResults(
        drawDeckIds: ['deck_1', 'deck_2'],
      );

      final d1 = await (db.select(db.decks)..where((t) => t.id.equals('deck_1'))).getSingle();
      expect(d1.wins, 0);
      expect(d1.losses, 0);
      expect(d1.draws, 1);

      final d2 = await (db.select(db.decks)..where((t) => t.id.equals('deck_2'))).getSingle();
      expect(d2.wins, 0);
      expect(d2.losses, 0);
      expect(d2.draws, 1);

      final outbox = await db.select(db.syncQueue).get();
      expect(outbox.length, 2);
    });

    test('3.3: No winner and no draw (all parameters null/empty) produces 0 deck updates and 0 syncQueue writes', () async {
      await seedDecks(['deck_x', 'deck_y']);

      await vaultDao.recordDeckMatchResults(
        winningDeckId: null,
        losingDeckIds: const [],
        drawDeckIds: const [],
      );

      final dx = await (db.select(db.decks)..where((t) => t.id.equals('deck_x'))).getSingle();
      expect(dx.wins, 0);
      expect(dx.losses, 0);
      expect(dx.draws, 0);

      final outbox = await db.select(db.syncQueue).get();
      expect(outbox.isEmpty, isTrue);
    });

    test('3.4: Unlinked players (null or empty deckId) and non-existent deck IDs handled gracefully', () async {
      await seedDecks(['deck_valid_1', 'deck_valid_2']);

      // Call with empty string deckId, null winning deck, and a non-existent deck
      await vaultDao.recordDeckMatchResults(
        winningDeckId: '',
        losingDeckIds: ['deck_valid_1', '', 'non_existent_deck_999'],
        drawDeckIds: const [],
      );

      // deck_valid_1 should have 1 loss
      final d1 = await (db.select(db.decks)..where((t) => t.id.equals('deck_valid_1'))).getSingle();
      expect(d1.losses, 1);

      // deck_valid_2 was not in losing list, stays 0
      final d2 = await (db.select(db.decks)..where((t) => t.id.equals('deck_valid_2'))).getSingle();
      expect(d2.losses, 0);

      // Outbox contains deck_valid_1 and non_existent_deck_999, but NOT empty strings
      final outbox = await db.select(db.syncQueue).get();
      for (final entry in outbox) {
        expect(entry.entityId.isNotEmpty, isTrue);
      }
    });

    test('3.5: Convenience helpers (incrementDeckWins, incrementDeckLosses, incrementDeckDraws) function accurately', () async {
      await seedDecks(['deck_solo']);

      await vaultDao.incrementDeckWins('deck_solo');
      await vaultDao.incrementDeckWins('deck_solo');
      await vaultDao.incrementDeckLosses('deck_solo');
      await vaultDao.incrementDeckDraws('deck_solo');

      final deck = await (db.select(db.decks)..where((t) => t.id.equals('deck_solo'))).getSingle();
      expect(deck.wins, 2);
      expect(deck.losses, 1);
      expect(deck.draws, 1);

      final outbox = await db.select(db.syncQueue).get();
      expect(outbox.length, 4);
    });
  });

  // ===========================================================================
  // GROUP 4: SQLite Database Sync — Concurrency & High-Frequency Multi-Match Stress
  // ===========================================================================
  group('Group 4: SQLite Database Sync Concurrency & Multi-Match Stress', () {
    test('4.1: Sequential 20-match tournament executes without drift or corruption', () async {
      await seedDecks(['deck_alpha', 'deck_beta', 'deck_gamma', 'deck_delta']);

      // 20 simulated matches:
      // Matches 1-8: Alpha wins, Beta, Gamma, Delta lose (8 wins for Alpha, 8 losses for each other)
      // Matches 9-14: Beta wins, Alpha, Gamma, Delta lose (6 wins for Beta)
      // Matches 15-18: Draw among all 4 (4 draws each)
      // Matches 19-20: Gamma wins, Alpha, Beta, Delta lose (2 wins for Gamma)

      for (int i = 0; i < 8; i++) {
        await vaultDao.recordDeckMatchResults(
          winningDeckId: 'deck_alpha',
          losingDeckIds: ['deck_beta', 'deck_gamma', 'deck_delta'],
        );
      }

      for (int i = 0; i < 6; i++) {
        await vaultDao.recordDeckMatchResults(
          winningDeckId: 'deck_beta',
          losingDeckIds: ['deck_alpha', 'deck_gamma', 'deck_delta'],
        );
      }

      for (int i = 0; i < 4; i++) {
        await vaultDao.recordDeckMatchResults(
          drawDeckIds: ['deck_alpha', 'deck_beta', 'deck_gamma', 'deck_delta'],
        );
      }

      for (int i = 0; i < 2; i++) {
        await vaultDao.recordDeckMatchResults(
          winningDeckId: 'deck_gamma',
          losingDeckIds: ['deck_alpha', 'deck_beta', 'deck_delta'],
        );
      }

      final alpha = await (db.select(db.decks)..where((t) => t.id.equals('deck_alpha'))).getSingle();
      expect(alpha.wins, 8);
      expect(alpha.losses, 6 + 2); // 8
      expect(alpha.draws, 4);

      final beta = await (db.select(db.decks)..where((t) => t.id.equals('deck_beta'))).getSingle();
      expect(beta.wins, 6);
      expect(beta.losses, 8 + 2); // 10
      expect(beta.draws, 4);

      final gamma = await (db.select(db.decks)..where((t) => t.id.equals('deck_gamma'))).getSingle();
      expect(gamma.wins, 2);
      expect(gamma.losses, 8 + 6); // 14
      expect(gamma.draws, 4);

      final delta = await (db.select(db.decks)..where((t) => t.id.equals('deck_delta'))).getSingle();
      expect(delta.wins, 0);
      expect(delta.losses, 8 + 6 + 2); // 16
      expect(delta.draws, 4);

      // Verify syncQueue total count: (8*4) + (6*4) + (4*4) + (2*4) = 32 + 24 + 16 + 8 = 80
      final syncEntries = await db.select(db.syncQueue).get();
      expect(syncEntries.length, 80);
    });

    test('4.2: Highly concurrent match recordings do not trigger SQLite locks or race condition losses', () async {
      await seedDecks(['deck_c1', 'deck_c2', 'deck_c3']);

      // Launch 15 concurrent updates simultaneously via Future.wait
      // 5 concurrent wins for deck_c1
      // 5 concurrent wins for deck_c2
      // 5 concurrent draws for all
      final futures = <Future<void>>[];

      for (int i = 0; i < 5; i++) {
        futures.add(vaultDao.recordDeckMatchResults(
          winningDeckId: 'deck_c1',
          losingDeckIds: ['deck_c2', 'deck_c3'],
        ));
        futures.add(vaultDao.recordDeckMatchResults(
          winningDeckId: 'deck_c2',
          losingDeckIds: ['deck_c1', 'deck_c3'],
        ));
        futures.add(vaultDao.recordDeckMatchResults(
          drawDeckIds: ['deck_c1', 'deck_c2', 'deck_c3'],
        ));
      }

      await Future.wait(futures);

      final c1 = await (db.select(db.decks)..where((t) => t.id.equals('deck_c1'))).getSingle();
      expect(c1.wins, 5);
      expect(c1.losses, 5);
      expect(c1.draws, 5);

      final c2 = await (db.select(db.decks)..where((t) => t.id.equals('deck_c2'))).getSingle();
      expect(c2.wins, 5);
      expect(c2.losses, 5);
      expect(c2.draws, 5);

      final c3 = await (db.select(db.decks)..where((t) => t.id.equals('deck_c3'))).getSingle();
      expect(c3.wins, 0);
      expect(c3.losses, 10);
      expect(c3.draws, 5);

      // Verify total sync queue rows: 15 calls * 3 decks = 45 rows
      final syncQueueRows = await db.select(db.syncQueue).get();
      expect(syncQueueRows.length, 45);
    });
  });

  // ===========================================================================
  // GROUP 5: End-to-End Dialog + PodController + SQLite Integration
  // ===========================================================================
  group('Group 5: End-to-End Reset Dialog, PodController, and SQLite Sync', () {
    testWidgets('5.1: Reset dialog with partial deck links syncs only linked decks on winner selection', (tester) async {
      await seedDecks(['deck_alice', 'deck_bob']);

      // 4-player pod: Alice & Bob have linked decks, Charlie has unlinked deck (null), Dave has empty deckId ('')
      final players = [
        createPlayer(id: 'p1', seatIndex: 0, name: 'Alice', deckId: 'deck_alice', life: 38),
        createPlayer(id: 'p2', seatIndex: 1, name: 'Bob', deckId: 'deck_bob', life: 0),
        createPlayer(id: 'p3', seatIndex: 2, name: 'Charlie', deckId: null, life: 12),
        createPlayer(id: 'p4', seatIndex: 3, name: 'Dave', deckId: '', life: 5),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                key: const Key('open_dialog_btn'),
                onPressed: () => ResetGameDialog.show(
                  ctx,
                  startingLife: 40,
                  players: players,
                  vaultDao: vaultDao,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('open_dialog_btn')));
      await tester.pumpAndSettle();

      // Select Alice as winner
      await tester.tap(find.byKey(const Key('reset_winner_pill_p1')));
      await tester.pump();

      // Tap Reset
      await tester.tap(find.byKey(const Key('confirm_reset_game_btn')));
      await tester.pumpAndSettle();

      // Verify Alice has 1 win, Bob has 1 loss
      final aliceDeck = await (db.select(db.decks)..where((t) => t.id.equals('deck_alice'))).getSingle();
      expect(aliceDeck.wins, 1);
      expect(aliceDeck.losses, 0);

      final bobDeck = await (db.select(db.decks)..where((t) => t.id.equals('deck_bob'))).getSingle();
      expect(bobDeck.wins, 0);
      expect(bobDeck.losses, 1);

      // Verify syncQueue logged exactly 2 rows (Alice and Bob)
      final outbox = await db.select(db.syncQueue).get();
      expect(outbox.length, 2);
      expect(outbox.map((e) => e.entityId).toSet(), equals({'deck_alice', 'deck_bob'}));
    });

    testWidgets('5.2: Reset dialog when unlinked player wins updates losing linked decks with losses', (tester) async {
      await seedDecks(['deck_p1', 'deck_p2']);

      // Charlie (unlinked) wins!
      final players = [
        createPlayer(id: 'p1', seatIndex: 0, name: 'Alice', deckId: 'deck_p1', life: 0),
        createPlayer(id: 'p2', seatIndex: 1, name: 'Bob', deckId: 'deck_p2', life: 0),
        createPlayer(id: 'p3', seatIndex: 2, name: 'Charlie', deckId: null, life: 25),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                key: const Key('open_dialog_btn'),
                onPressed: () => ResetGameDialog.show(
                  ctx,
                  startingLife: 40,
                  players: players,
                  vaultDao: vaultDao,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('open_dialog_btn')));
      await tester.pumpAndSettle();

      // Select Charlie as winner
      await tester.tap(find.byKey(const Key('reset_winner_pill_p3')));
      await tester.pump();

      // Tap Reset
      await tester.tap(find.byKey(const Key('confirm_reset_game_btn')));
      await tester.pumpAndSettle();

      // Linked decks should have 1 loss each
      final p1Deck = await (db.select(db.decks)..where((t) => t.id.equals('deck_p1'))).getSingle();
      expect(p1Deck.wins, 0);
      expect(p1Deck.losses, 1);

      final p2Deck = await (db.select(db.decks)..where((t) => t.id.equals('deck_p2'))).getSingle();
      expect(p2Deck.wins, 0);
      expect(p2Deck.losses, 1);

      final outbox = await db.select(db.syncQueue).get();
      expect(outbox.length, 2);
    });

    testWidgets('5.3: Reset dialog Draw with partial deck links records draws only for linked decks', (tester) async {
      await seedDecks(['deck_linked']);

      final players = [
        createPlayer(id: 'p1', seatIndex: 0, name: 'Alice', deckId: 'deck_linked', life: 10),
        createPlayer(id: 'p2', seatIndex: 1, name: 'Bob', deckId: null, life: 10),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                key: const Key('open_dialog_btn'),
                onPressed: () => ResetGameDialog.show(
                  ctx,
                  startingLife: 40,
                  players: players,
                  vaultDao: vaultDao,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('open_dialog_btn')));
      await tester.pumpAndSettle();

      // Select Draw
      await tester.tap(find.byKey(const Key('reset_draw_pill')));
      await tester.pump();

      // Confirm Reset + Randomize Seats
      await tester.tap(find.byKey(const Key('reset_randomize_seats_btn')));
      await tester.pumpAndSettle();

      final deck = await (db.select(db.decks)..where((t) => t.id.equals('deck_linked'))).getSingle();
      expect(deck.draws, 1);
      expect(deck.wins, 0);
      expect(deck.losses, 0);

      final outbox = await db.select(db.syncQueue).get();
      expect(outbox.length, 1);
      expect(outbox.first.entityId, 'deck_linked');
    });

    testWidgets('5.4: Reset dialog Cancel does not perform SQLite sync or modify tables', (tester) async {
      await seedDecks(['deck_safe']);

      final players = [
        createPlayer(id: 'p1', seatIndex: 0, name: 'Alice', deckId: 'deck_safe', life: 40),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                key: const Key('open_dialog_btn'),
                onPressed: () => ResetGameDialog.show(
                  ctx,
                  startingLife: 40,
                  players: players,
                  vaultDao: vaultDao,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('open_dialog_btn')));
      await tester.pumpAndSettle();

      // Select Alice
      await tester.tap(find.byKey(const Key('reset_winner_pill_p1')));
      await tester.pump();

      // Tap Cancel
      await tester.tap(find.byKey(const Key('cancel_reset_game_btn')));
      await tester.pumpAndSettle();

      // Check SQLite table has 0 wins and 0 outbox entries
      final deck = await (db.select(db.decks)..where((t) => t.id.equals('deck_safe'))).getSingle();
      expect(deck.wins, 0);
      expect(deck.losses, 0);
      expect(deck.draws, 0);

      final outbox = await db.select(db.syncQueue).get();
      expect(outbox.isEmpty, isTrue);
    });
  });
}
