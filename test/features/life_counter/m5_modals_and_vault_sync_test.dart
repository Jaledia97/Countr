// Copyright (c) 2026 Countr. All rights reserved.
// Milestone 5: Floating Mana/Storm, Dice & Smart Reset Modals with SQLite Deck W/L/D Sync.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';

import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/life_counter/domain/models/pod_state.dart';
import 'package:countr/features/life_counter/domain/services/dice_roller_service.dart';
import 'package:countr/features/life_counter/presentation/controllers/pod_controller.dart';
import 'package:countr/features/life_counter/presentation/widgets/floating_mana_drawer_widget.dart';
import 'package:countr/features/life_counter/presentation/dialogs/randomizer_hub_modal.dart';
import 'package:countr/features/life_counter/presentation/dialogs/reset_game_dialog.dart';
import 'package:countr/features/life_counter/presentation/widgets/center_hub_button.dart';
import 'package:countr/features/life_counter/presentation/widgets/player_quadrant_widget.dart';
import 'package:countr/features/life_counter/presentation/widgets/pod_scaffold_widget.dart';

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

  PodPlayerState createTestPlayer({
    String id = 'p1',
    int seatIndex = 0,
    String name = 'Alice',
    int life = 40,
    String? deckId,
    Map<String, int>? mana,
    int storm = 0,
  }) {
    return PodPlayerState(
      id: id,
      seatIndex: seatIndex,
      name: name,
      deckId: deckId,
      life: life,
      floatingMana: mana ?? {'W': 0, 'U': 0, 'B': 0, 'R': 0, 'G': 0, 'C': 0},
      stormCount: storm,
    );
  }

  // ===========================================================================
  // GROUP 1: R5.1 Floating Mana & Storm Drawer Tests
  // ===========================================================================
  group('R5.1: Floating Mana & Storm Drawer', () {
    testWidgets('1.1: Renders all 6 WUBRGC mana rows vertically and Storm counter at bottom', (tester) async {
      final player = createTestPlayer(
        mana: {'W': 1, 'U': 2, 'B': 3, 'R': 4, 'G': 5, 'C': 6},
        storm: 7,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FloatingManaDrawerWidget(
              player: player,
              onManaDelta: (color, delta) {},
              onStormDelta: (delta) {},
              onManaClear: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check all 6 mana rows and values
      for (final color in ['W', 'U', 'B', 'R', 'G', 'C']) {
        expect(find.byKey(Key('mana_val_${color}_${player.id}')), findsOneWidget);
        expect(find.byKey(Key('mana_inc_${color}_${player.id}')), findsOneWidget);
        expect(find.byKey(Key('mana_dec_${color}_${player.id}')), findsOneWidget);
      }
      expect(find.text('1'), findsOneWidget); // W
      expect(find.text('2'), findsOneWidget); // U
      expect(find.text('3'), findsOneWidget); // B
      expect(find.text('4'), findsOneWidget); // R
      expect(find.text('5'), findsOneWidget); // G
      expect(find.text('6'), findsOneWidget); // C

      // Storm row and buttons
      expect(find.byKey(Key('storm_count_${player.id}')), findsOneWidget);
      expect(find.textContaining('7'), findsOneWidget);
      expect(find.byKey(Key('storm_inc_${player.id}')), findsOneWidget);
      expect(find.byKey(Key('storm_dec_${player.id}')), findsOneWidget);

      // Verify dedicated Close button and red Clear button
      expect(find.byKey(const Key('mana_drawer_close_button')), findsOneWidget);
      expect(find.byKey(const Key('mana_drawer_clear_button')), findsOneWidget);
      expect(find.byKey(Key('clear_pool_btn_${player.id}')), findsOneWidget);
    });

    testWidgets('1.2: Steppers trigger onManaDelta and onStormDelta callbacks', (tester) async {
      final player = createTestPlayer();
      String? recordedColor;
      int? recordedManaDelta;
      int? recordedStormDelta;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FloatingManaDrawerWidget(
              player: player,
              onManaDelta: (color, delta) {
                recordedColor = color;
                recordedManaDelta = delta;
              },
              onStormDelta: (delta) {
                recordedStormDelta = delta;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Blue +
      await tester.tap(find.byKey(Key('mana_inc_U_${player.id}')));
      expect(recordedColor, 'U');
      expect(recordedManaDelta, 1);

      // Tap Red -
      await tester.tap(find.byKey(Key('mana_dec_R_${player.id}')));
      expect(recordedColor, 'R');
      expect(recordedManaDelta, -1);

      // Tap Storm +
      await tester.tap(find.byKey(Key('storm_inc_${player.id}')));
      expect(recordedStormDelta, 1);

      // Tap Storm -
      await tester.tap(find.byKey(Key('storm_dec_${player.id}')));
      expect(recordedStormDelta, -1);
    });

    testWidgets('1.3: Close button and Clear button callbacks work correctly', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final player = createTestPlayer();
      bool clearInvoked = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                key: const Key('open_sheet'),
                onPressed: () {
                  showModalBottomSheet(
                    context: ctx,
                    isScrollControlled: true,
                    builder: (modalCtx) => FloatingManaDrawerWidget(
                      player: player,
                      onManaDelta: (color, delta) {},
                      onManaClear: () {
                        clearInvoked = true;
                      },
                      autoCloseOnClear: true,
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      // Open sheet
      await tester.tap(find.byKey(const Key('open_sheet')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('mana_drawer_close_button')), findsOneWidget);

      // Tap close button pops sheet
      await tester.tap(find.byKey(const Key('mana_drawer_close_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('mana_drawer_close_button')), findsNothing);

      // Open again to test clear button
      await tester.tap(find.byKey(const Key('open_sheet')));
      await tester.pumpAndSettle();

      // Tap clear button
      await tester.tap(find.byKey(const Key('mana_drawer_clear_button')));
      await tester.pumpAndSettle();
      expect(clearInvoked, isTrue);
      // Sheet auto-closed
      expect(find.byKey(const Key('mana_drawer_clear_button')), findsNothing);
    });

    testWidgets('1.4: Renders cleanly without overflow in constrained viewport (280x500 at 1.8x text scale)', (tester) async {
      tester.view.physicalSize = const Size(280, 500);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final player = createTestPlayer(
        mana: {'W': 10, 'U': 20, 'B': 30, 'R': 40, 'G': 50, 'C': 60},
        storm: 99,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            textTheme: const TextTheme(
              bodyMedium: TextStyle(fontSize: 24),
            ),
          ),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(280, 500),
              textScaler: TextScaler.linear(1.8),
            ),
            child: Scaffold(
              body: FloatingManaDrawerWidget(
                player: player,
                onManaDelta: (color, delta) {},
                onStormDelta: (delta) {},
                onManaClear: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('1.5: PodScaffoldWidget integrates mana drawer with StatefulBuilder reactivity', (tester) async {
      final p1 = createTestPlayer(id: 'p1', name: 'Alice');
      final podState = PodState(
        sessionId: 'test_pod_session',
        format: 'commander',
        startingLife: 40,
        players: [p1],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PodScaffoldWidget(
              podState: podState,
              onManaDelta: (pId, color, delta) {},
              onStormDelta: (pId, delta) {},
              onManaClear: (pId) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open mana drawer from central hub mana button
      expect(find.byKey(const Key('central_hub_mana_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('central_hub_mana_button')));
      await tester.pumpAndSettle();

      // Drawer is open
      expect(find.byKey(const Key('mana_drawer_close_button')), findsOneWidget);
      expect(find.byKey(const Key('storm_count_p1')), findsOneWidget);

      // Steppers are rendered because onStormDelta was provided
      expect(find.byKey(const Key('storm_inc_p1')), findsOneWidget);

      // Close drawer
      await tester.tap(find.byKey(const Key('mana_drawer_close_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('mana_drawer_close_button')), findsNothing);
    });
  });

  // ===========================================================================
  // GROUP 2: R5.2 Dice, Coins & Randomizers Hub Modal Tests
  // ===========================================================================
  group('R5.2: Dice, Coins & Randomizers Hub Modal', () {
    test('2.1: RandomizerService.rollCustomDice clamps to >= 2 and records history', () {
      final service = RandomizerService();

      // Test with valid sides
      for (int i = 0; i < 20; i++) {
        final roll = service.rollCustomDice(30);
        expect(roll, inInclusiveRange(1, 30));
      }

      // Test with clamped minimum sides (0 or 1 should clamp to 2)
      final rollClamp1 = service.rollCustomDice(1);
      expect(rollClamp1, inInclusiveRange(1, 2));

      final rollClamp0 = service.rollCustomDice(-5);
      expect(rollClamp0, inInclusiveRange(1, 2));

      // Check recentRolls getter returns last 5 entries
      expect(service.recentRolls.length, 5);
      expect(service.recentRolls.first.summary, contains('D2 Roll:'));
    });

    testWidgets('2.2: RandomizerHubModal custom dice stepper and roll button work interactively', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                key: const Key('open_hub'),
                onPressed: () => RandomizerHubModal.show(context: ctx, playerCount: 4),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('open_hub')));
      await tester.pumpAndSettle();

      // Check custom dice stepper widgets exist
      expect(find.byKey(const Key('custom_dice_minus_btn')), findsOneWidget);
      expect(find.byKey(const Key('custom_dice_sides_text')), findsOneWidget);
      expect(find.byKey(const Key('custom_dice_plus_btn')), findsOneWidget);
      expect(find.byKey(const Key('custom_dice_roll_btn')), findsOneWidget);
      expect(find.text('D20'), findsWidgets);

      // Tap + button 3 times -> D23
      await tester.tap(find.byKey(const Key('custom_dice_plus_btn')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('custom_dice_plus_btn')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('custom_dice_plus_btn')));
      await tester.pump();
      expect(find.text('D23'), findsOneWidget);

      // Tap Roll button
      await tester.tap(find.byKey(const Key('custom_dice_roll_btn')));
      await tester.pump(const Duration(milliseconds: 350));

      // Banner shows result
      expect(find.byKey(const Key('randomizer_result_text')), findsOneWidget);
      final bannerText = tester.widget<Text>(find.byKey(const Key('randomizer_result_text'))).data!;
      expect(bannerText, contains('D23 Roll:'));

      // Result history strip reflects the roll
      expect(find.byKey(const Key('randomizer_history_strip')), findsOneWidget);
      expect(find.byKey(const Key('recent_roll_0')), findsOneWidget);
    });

    testWidgets('2.3: Random opponent button is disabled when playerCount < 3 and enabled when >= 3', (tester) async {
      // 2 players: opponent button should be disabled
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                key: const Key('open_hub_2p'),
                onPressed: () => RandomizerHubModal.show(context: ctx, playerCount: 2),
                child: const Text('Open 2P'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('open_hub_2p')));
      await tester.pumpAndSettle();

      final btn2p = tester.widget<ElevatedButton>(find.byKey(const Key('random_opponent_btn')));
      expect(btn2p.onPressed, isNull); // disabled

      // Close modal
      Navigator.of(tester.element(find.byKey(const Key('randomizer_hub_modal')))).pop();
      await tester.pumpAndSettle();

      // 4 players: opponent button should be enabled
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                key: const Key('open_hub_4p'),
                onPressed: () => RandomizerHubModal.show(context: ctx, playerCount: 4),
                child: const Text('Open 4P'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('open_hub_4p')));
      await tester.pumpAndSettle();

      final btn4p = tester.widget<ElevatedButton>(find.byKey(const Key('random_opponent_btn')));
      expect(btn4p.onPressed, isNotNull); // enabled
    });

    testWidgets('2.4: Standard dice buttons and coin flip work as expected', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                key: const Key('open_hub'),
                onPressed: () => RandomizerHubModal.show(context: ctx, playerCount: 4),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('open_hub')));
      await tester.pumpAndSettle();

      // Flip coin
      await tester.tap(find.byKey(const Key('coin_flip_btn')));
      await tester.pump(const Duration(milliseconds: 760));
      expect(find.byKey(const Key('randomizer_result_text')), findsOneWidget);

      // Roll D6
      await tester.tap(find.byKey(const Key('dice_d6_btn')));
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byKey(const Key('randomizer_result_text')), findsOneWidget);
      final d6Text = tester.widget<Text>(find.byKey(const Key('randomizer_result_text'))).data!;
      expect(d6Text, contains('D6 Roll:'));
    });
  });

  // ===========================================================================
  // GROUP 3: R5.2 Board Highlighting Tests
  // ===========================================================================
  group('R5.2: Board Highlighting & PlayerQuadrantWidget', () {
    testWidgets('3.1: PlayerQuadrantWidget renders AppColors.accentGold border and shadow when isHighlighted is true', (tester) async {
      final player = createTestPlayer();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: PlayerQuadrantWidget(
                player: player,
                isTablet: false,
                opponents: const [],
                isHighlighted: true,
                onLifeDelta: (delta) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the AnimatedContainer
      final animContainerFinder = find.descendant(
        of: find.byType(PlayerQuadrantWidget),
        matching: find.byType(AnimatedContainer),
      );
      expect(animContainerFinder, findsWidgets);

      final animContainer = tester.widget<AnimatedContainer>(animContainerFinder.first);
      final decoration = animContainer.decoration as BoxDecoration;
      expect(decoration.border, isNotNull);
      final border = decoration.border as Border;
      expect(border.top.color, AppColors.accentGold);
      expect(border.top.width, 3.5);
      expect(decoration.boxShadow, isNotNull);
      expect(decoration.boxShadow!.first.color, AppColors.accentGold.withValues(alpha: 0.6));
    });

    testWidgets('3.2: PlayerQuadrantWidget renders standard border when isHighlighted is false', (tester) async {
      final player = createTestPlayer();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 300,
              child: PlayerQuadrantWidget(
                player: player,
                isTablet: false,
                opponents: const [],
                isHighlighted: false,
                onLifeDelta: (delta) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final animContainerFinder = find.descendant(
        of: find.byType(PlayerQuadrantWidget),
        matching: find.byType(AnimatedContainer),
      );
      final animContainer = tester.widget<AnimatedContainer>(animContainerFinder.first);
      final decoration = animContainer.decoration as BoxDecoration;
      final border = decoration.border as Border;
      expect(border.top.color, isNot(AppColors.accentGold));
      expect(decoration.boxShadow, isNull);
    });

    testWidgets('3.3: PodScaffoldWidget quick random player highlights quadrant and auto-clears after 3000ms', (tester) async {
      final p1 = createTestPlayer(id: 'p1', seatIndex: 0, name: 'Alice');
      final podState = PodState(
        sessionId: 'test_pod_highlight',
        format: 'commander',
        startingLife: 40,
        players: [p1],
      );

      int? selectedPlayerIndex;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PodScaffoldWidget(
              podState: podState,
              onPlayerSelected: (idx) {
                selectedPlayerIndex = idx;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Long press central hub die button to trigger quick starting player roll
      await tester.longPress(find.byType(CenterHubButton));
      await tester.pump();

      // Player 0 should be selected and highlighted
      expect(selectedPlayerIndex, 0);

      // Verify PlayerQuadrantWidget received isHighlighted: true
      final quadFinder = find.byType(PlayerQuadrantWidget);
      expect(quadFinder, findsOneWidget);
      final quadWidget = tester.widget<PlayerQuadrantWidget>(quadFinder);
      expect(quadWidget.isHighlighted, isTrue);

      // Fast-forward 3000ms
      await tester.pump(const Duration(milliseconds: 3000));

      // After 3000ms, isHighlighted auto-clears to false
      final quadWidgetAfter = tester.widget<PlayerQuadrantWidget>(quadFinder);
      expect(quadWidgetAfter.isHighlighted, isFalse);
    });
  });

  // ===========================================================================
  // GROUP 4: R5.3 Smart Reset Game Modal & SQLite Deck W/L/D Sync Tests
  // ===========================================================================
  group('R5.3: Smart Reset Game Modal & SQLite Sync', () {
    test('4.1: VaultDao.recordDeckMatchResults atomically increments wins/losses and logs outbox sync', () async {
      final now = DateTime.now();
      // Create 3 decks in SQLite
      await db.into(db.decks).insert(
            DecksCompanion.insert(
              id: 'deck_winner',
              name: 'Omnath Ramp',
              format: 'commander',
              createdAt: now,
            ),
          );
      await db.into(db.decks).insert(
            DecksCompanion.insert(
              id: 'deck_loser_1',
              name: 'Krenko Goblins',
              format: 'commander',
              createdAt: now,
            ),
          );
      await db.into(db.decks).insert(
            DecksCompanion.insert(
              id: 'deck_loser_2',
              name: 'Urza Artifacts',
              format: 'commander',
              createdAt: now,
            ),
          );

      // Record match results
      await vaultDao.recordDeckMatchResults(
        winningDeckId: 'deck_winner',
        losingDeckIds: ['deck_loser_1', 'deck_loser_2'],
      );

      // Verify decks table
      final winnerDeck = await (db.select(db.decks)..where((t) => t.id.equals('deck_winner'))).getSingle();
      expect(winnerDeck.wins, 1);
      expect(winnerDeck.losses, 0);
      expect(winnerDeck.draws, 0);
      expect(winnerDeck.updatedAt, isNotNull);

      final loser1 = await (db.select(db.decks)..where((t) => t.id.equals('deck_loser_1'))).getSingle();
      expect(loser1.wins, 0);
      expect(loser1.losses, 1);
      expect(loser1.draws, 0);

      final loser2 = await (db.select(db.decks)..where((t) => t.id.equals('deck_loser_2'))).getSingle();
      expect(loser2.wins, 0);
      expect(loser2.losses, 1);
      expect(loser2.draws, 0);

      // Verify syncQueue entries
      final syncEntries = await db.select(db.syncQueue).get();
      expect(syncEntries.length, 3);
      for (final entry in syncEntries) {
        expect(entry.entityType, 'deck');
        expect(entry.operation, 'UPDATE');
      }
    });

    test('4.2: VaultDao.recordDeckMatchResults increments draws correctly', () async {
      final now = DateTime.now();
      await db.into(db.decks).insert(
            DecksCompanion.insert(
              id: 'deck_draw_1',
              name: 'Deck A',
              format: 'commander',
              createdAt: now,
            ),
          );
      await db.into(db.decks).insert(
            DecksCompanion.insert(
              id: 'deck_draw_2',
              name: 'Deck B',
              format: 'commander',
              createdAt: now,
            ),
          );

      await vaultDao.recordDeckMatchResults(
        drawDeckIds: ['deck_draw_1', 'deck_draw_2'],
      );

      final d1 = await (db.select(db.decks)..where((t) => t.id.equals('deck_draw_1'))).getSingle();
      expect(d1.draws, 1);
      expect(d1.wins, 0);
      expect(d1.losses, 0);

      final d2 = await (db.select(db.decks)..where((t) => t.id.equals('deck_draw_2'))).getSingle();
      expect(d2.draws, 1);
    });

    test('4.3: PodController randomizeSeats shuffles seats and preserves profiles', () {
      final pod = PodState(
        sessionId: 's1',
        format: 'commander',
        startingLife: 40,
        players: [
          createTestPlayer(id: 'p1', seatIndex: 0, name: 'Alice', deckId: 'd1'),
          createTestPlayer(id: 'p2', seatIndex: 1, name: 'Bob', deckId: 'd2'),
          createTestPlayer(id: 'p3', seatIndex: 2, name: 'Charlie', deckId: 'd3'),
          createTestPlayer(id: 'p4', seatIndex: 3, name: 'Dave', deckId: 'd4'),
        ],
      );

      final controller = PodController(initialState: pod);
      controller.randomizeSeats();

      final playersAfter = controller.state.players;
      expect(playersAfter.length, 4);

      // Verify each seatIndex is unique in 0..3
      final seatIndices = playersAfter.map((p) => p.seatIndex).toList();
      expect(seatIndices, containsAll([0, 1, 2, 3]));

      // Verify profiles remain intact
      final alice = playersAfter.firstWhere((p) => p.id == 'p1');
      expect(alice.name, 'Alice');
      expect(alice.deckId, 'd1');
    });

    test('4.4: PodController clearProfiles resets custom profiles back to defaults', () {
      final pod = PodState(
        sessionId: 's1',
        format: 'commander',
        startingLife: 40,
        players: [
          createTestPlayer(id: 'p1', seatIndex: 0, name: 'Alice', deckId: 'd1'),
          createTestPlayer(id: 'p2', seatIndex: 1, name: 'Bob', deckId: 'd2'),
        ],
      );

      final controller = PodController(initialState: pod);
      controller.clearProfiles();

      final p1 = controller.state.players[0];
      expect(p1.name, 'Player 1');
      expect(p1.deckId, isNull);
      expect(p1.commanderCardId, isNull);

      final p2 = controller.state.players[1];
      expect(p2.name, 'Player 2');
      expect(p2.deckId, isNull);
    });

    testWidgets('4.5: ResetGameDialog renders prompt text, winner selection pills, draw pill, and 4 action buttons', (tester) async {
      final players = [
        createTestPlayer(id: 'p1', name: 'Alice', life: 40),
        createTestPlayer(id: 'p2', name: 'Bob', life: 12),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                key: const Key('open_reset'),
                onPressed: () => ResetGameDialog.show(
                  ctx,
                  startingLife: 40,
                  players: players,
                ),
                child: const Text('Open Reset'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('open_reset')));
      await tester.pumpAndSettle();

      // Dialog container & prompt text
      expect(find.byKey(const Key('reset_game_dialog')), findsOneWidget);
      expect(find.byKey(const Key('reset_game_prompt_text')), findsOneWidget);

      // Winner selection pills
      expect(find.byKey(const Key('reset_winner_pill_p1')), findsOneWidget);
      expect(find.byKey(const Key('reset_winner_pill_p2')), findsOneWidget);
      expect(find.text('Alice  40'), findsOneWidget);
      expect(find.text('Bob  12'), findsOneWidget);

      // Draw pill
      expect(find.byKey(const Key('reset_draw_pill')), findsOneWidget);
      expect(find.text('Draw'), findsOneWidget);

      // 4 Action Buttons
      expect(find.byKey(const Key('confirm_reset_game_btn')), findsOneWidget);
      expect(find.byKey(const Key('reset_randomize_seats_btn')), findsOneWidget);
      expect(find.byKey(const Key('reset_clear_profiles_btn')), findsOneWidget);
      expect(find.byKey(const Key('cancel_reset_game_btn')), findsOneWidget);
    });

    testWidgets('4.6: ResetGameDialog winner and draw pill selection toggling', (tester) async {
      final players = [
        createTestPlayer(id: 'p1', name: 'Alice', life: 40),
        createTestPlayer(id: 'p2', name: 'Bob', life: 12),
      ];

      ResetGameResult? finalResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                key: const Key('open_reset'),
                onPressed: () => ResetGameDialog.show(
                  ctx,
                  startingLife: 40,
                  players: players,
                  onConfirmAction: (res) {
                    finalResult = res;
                  },
                ),
                child: const Text('Open Reset'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('open_reset')));
      await tester.pumpAndSettle();

      // Select Alice as winner
      await tester.tap(find.byKey(const Key('reset_winner_pill_p1')));
      await tester.pump();

      // Now tap Draw: should deselect winner and select draw
      await tester.tap(find.byKey(const Key('reset_draw_pill')));
      await tester.pump();

      // Now tap Bob: should deselect draw and select Bob
      await tester.tap(find.byKey(const Key('reset_winner_pill_p2')));
      await tester.pump();

      // Confirm Reset
      await tester.tap(find.byKey(const Key('confirm_reset_game_btn')));
      await tester.pumpAndSettle();

      expect(finalResult, isNotNull);
      expect(finalResult!.action, ResetGameAction.reset);
      expect(finalResult!.winningPlayerId, 'p2');
      expect(finalResult!.isDraw, isFalse);
    });

    testWidgets('4.7: ResetGameDialog SQLite sync executes when winner is selected', (tester) async {
      final now = DateTime.now();
      // Insert 2 decks
      await db.into(db.decks).insert(
            DecksCompanion.insert(
              id: 'deck_p1',
              name: 'Alice EDH',
              format: 'commander',
              createdAt: now,
            ),
          );
      await db.into(db.decks).insert(
            DecksCompanion.insert(
              id: 'deck_p2',
              name: 'Bob EDH',
              format: 'commander',
              createdAt: now,
            ),
          );

      final players = [
        createTestPlayer(id: 'p1', name: 'Alice', deckId: 'deck_p1', life: 35),
        createTestPlayer(id: 'p2', name: 'Bob', deckId: 'deck_p2', life: 0),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                key: const Key('open_reset'),
                onPressed: () => ResetGameDialog.show(
                  ctx,
                  startingLife: 40,
                  players: players,
                  vaultDao: vaultDao,
                ),
                child: const Text('Open Reset'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('open_reset')));
      await tester.pumpAndSettle();

      // Select Alice as winner
      await tester.tap(find.byKey(const Key('reset_winner_pill_p1')));
      await tester.pump();

      // Confirm Reset + Randomize Seats
      await tester.tap(find.byKey(const Key('reset_randomize_seats_btn')));
      await tester.pumpAndSettle();

      // Verify SQLite match results were recorded
      final p1Deck = await (db.select(db.decks)..where((t) => t.id.equals('deck_p1'))).getSingle();
      expect(p1Deck.wins, 1);
      expect(p1Deck.losses, 0);

      final p2Deck = await (db.select(db.decks)..where((t) => t.id.equals('deck_p2'))).getSingle();
      expect(p2Deck.wins, 0);
      expect(p2Deck.losses, 1);
    });
  });
}
