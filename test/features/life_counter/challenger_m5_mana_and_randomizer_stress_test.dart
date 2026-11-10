// Copyright (c) 2026 Countr. All rights reserved.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/features/life_counter/domain/models/pod_state.dart';
import 'package:countr/features/life_counter/domain/services/dice_roller_service.dart';
import 'package:countr/features/life_counter/presentation/dialogs/randomizer_hub_modal.dart';
import 'package:countr/features/life_counter/presentation/widgets/center_hub_button.dart';
import 'package:countr/features/life_counter/presentation/widgets/floating_mana_drawer_widget.dart';
import 'package:countr/features/life_counter/presentation/widgets/player_quadrant_widget.dart';
import 'package:countr/features/life_counter/presentation/widgets/pod_scaffold_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  PodPlayerState createTestPlayer({
    String id = 'p1',
    int seatIndex = 0,
    String name = 'Alice',
    int life = 40,
    Map<String, int>? mana,
    int storm = 0,
  }) {
    return PodPlayerState(
      id: id,
      seatIndex: seatIndex,
      name: name,
      life: life,
      floatingMana: mana ?? {'W': 0, 'U': 0, 'B': 0, 'R': 0, 'G': 0, 'C': 0},
      stormCount: storm,
    );
  }

  // ===========================================================================
  // GROUP 1: Floating Mana & Storm Drawer Adversarial Stress (R5.1)
  // ===========================================================================
  group('Challenger M5-1: Floating Mana & Storm Drawer Adversarial Stress (R5.1)', () {
    // 1.1 Multi-Viewport & Text Scaler Stress Matrix
    for (final scenario in [
      (
        desc: 'Ultra-compact viewport (240x400 @ 2.0x text scale)',
        size: const Size(240, 400),
        scale: 2.0,
      ),
      (
        desc: 'Constrained mobile viewport (280x500 @ 1.8x text scale)',
        size: const Size(280, 500),
        scale: 1.8,
      ),
      (
        desc: 'Compact iPhone SE viewport (320x568 @ 1.5x text scale)',
        size: const Size(320, 568),
        scale: 1.5,
      ),
      (
        desc: 'Standard Android viewport (360x640 @ 1.0x text scale)',
        size: const Size(360, 640),
        scale: 1.0,
      ),
    ]) {
      testWidgets('1.1: Layout stability with zero overflows on ${scenario.desc}', (tester) async {
        tester.view.physicalSize = scenario.size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final player = createTestPlayer(
          name: 'Archmage Alexandria of the Infinite Storms',
          mana: {'W': 99, 'U': 99, 'B': 99, 'R': 99, 'G': 99, 'C': 99},
          storm: 99,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: scenario.size,
                textScaler: TextScaler.linear(scenario.scale),
              ),
              child: Scaffold(
                body: FloatingManaDrawerWidget(
                  player: player,
                  onManaDelta: (_, delta) {},
                  onStormDelta: (_) {},
                  onManaClear: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Zero RenderFlex overflows allowed
        expect(tester.takeException(), isNull);

        // Header, all 6 rows, storm counter, close button, and clear button render
        expect(find.byKey(Key('mana_drawer_sheet_${player.id}')), findsOneWidget);
        for (final color in FloatingManaDrawerWidget.manaColors) {
          expect(find.byKey(Key('mana_row_${color}_${player.id}')), findsOneWidget);
          expect(find.byKey(Key('mana_inc_${color}_${player.id}')), findsOneWidget);
          expect(find.byKey(Key('mana_dec_${color}_${player.id}')), findsOneWidget);
        }
        expect(find.byKey(Key('storm_count_${player.id}')), findsOneWidget);
        expect(find.byKey(const Key('mana_drawer_close_button')), findsOneWidget);
        expect(find.byKey(const Key('mana_drawer_clear_button')), findsOneWidget);
      });
    }

    // 1.2 Rapid multi-color tapping and zero-clamping stress
    testWidgets('1.2: Rapid tapping across all 6 colors and strict clamping at 0', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      var player = createTestPlayer();
      late StateSetter setHostState;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (ctx, setState) {
                setHostState = setState;
                return FloatingManaDrawerWidget(
                  player: player,
                  onManaDelta: (color, delta) {
                    final cur = player.floatingMana[color] ?? 0;
                    final updated = Map<String, int>.from(player.floatingMana);
                    updated[color] = math.max(0, cur + delta);
                    setHostState(() {
                      player = player.copyWith(floatingMana: updated);
                    });
                  },
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify initial state is 0 for all colors
      for (final color in FloatingManaDrawerWidget.manaColors) {
        expect(find.byKey(Key('mana_val_${color}_${player.id}')), findsOneWidget);
        final textWidget = tester.widget<Text>(find.byKey(Key('mana_val_${color}_${player.id}')));
        expect(textWidget.data, '0');
      }

      // Decrement from 0 on all 6 colors (must clamp at 0)
      for (final color in FloatingManaDrawerWidget.manaColors) {
        for (int i = 0; i < 5; i++) {
          await tester.tap(find.byKey(Key('mana_dec_${color}_${player.id}')));
        }
      }
      await tester.pump();

      for (final color in FloatingManaDrawerWidget.manaColors) {
        expect(player.floatingMana[color], 0);
        final textWidget = tester.widget<Text>(find.byKey(Key('mana_val_${color}_${player.id}')));
        expect(textWidget.data, '0');
      }

      // Rapidly increment White 25 times
      for (int i = 0; i < 25; i++) {
        await tester.tap(find.byKey(Key('mana_inc_W_${player.id}')));
      }
      await tester.pump();
      expect(player.floatingMana['W'], 25);
      expect(tester.widget<Text>(find.byKey(Key('mana_val_W_${player.id}'))).data, '25');

      // Rapidly decrement White 30 times (should clamp at 0, not -5)
      for (int i = 0; i < 30; i++) {
        await tester.tap(find.byKey(Key('mana_dec_W_${player.id}')));
      }
      await tester.pump();
      expect(player.floatingMana['W'], 0);
      expect(tester.widget<Text>(find.byKey(Key('mana_val_W_${player.id}'))).data, '0');

      // Interleaved rapid tapping across all colors
      for (final color in FloatingManaDrawerWidget.manaColors) {
        await tester.tap(find.byKey(Key('mana_inc_${color}_${player.id}')));
        await tester.tap(find.byKey(Key('mana_inc_${color}_${player.id}')));
      }
      await tester.pump();

      for (final color in FloatingManaDrawerWidget.manaColors) {
        expect(player.floatingMana[color], 2);
        expect(tester.widget<Text>(find.byKey(Key('mana_val_${color}_${player.id}'))).data, '2');
      }
    });

    // 1.3 Independent Storm Counter Stepper and Zero-Clamping
    testWidgets('1.3: Independent storm counter stepper and clamping at 0', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      var player = createTestPlayer();
      late StateSetter setHostState;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (ctx, setState) {
                setHostState = setState;
                return FloatingManaDrawerWidget(
                  player: player,
                  onStormDelta: (delta) {
                    setHostState(() {
                      player = player.copyWith(
                        stormCount: math.max(0, player.stormCount + delta),
                      );
                    });
                  },
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initial storm count is 0
      expect(find.byKey(Key('storm_count_${player.id}')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(Key('storm_count_${player.id}'))).data, 'Storm Count: 0');

      // Tapping decrement at 0 clamps to 0
      for (int i = 0; i < 10; i++) {
        await tester.tap(find.byKey(Key('storm_dec_${player.id}')));
      }
      await tester.pump();
      expect(player.stormCount, 0);
      expect(tester.widget<Text>(find.byKey(Key('storm_count_${player.id}'))).data, 'Storm Count: 0');

      // Rapidly increment storm to 15
      for (int i = 0; i < 15; i++) {
        await tester.tap(find.byKey(Key('storm_inc_${player.id}')));
      }
      await tester.pump();
      expect(player.stormCount, 15);
      expect(tester.widget<Text>(find.byKey(Key('storm_count_${player.id}'))).data, 'Storm Count: 15');

      // Rapidly decrement storm 20 times (clamps at 0)
      for (int i = 0; i < 20; i++) {
        await tester.tap(find.byKey(Key('storm_dec_${player.id}')));
      }
      await tester.pump();
      expect(player.stormCount, 0);
      expect(tester.widget<Text>(find.byKey(Key('storm_count_${player.id}'))).data, 'Storm Count: 0');
    });

    // 1.4 Atomic Clear Button Resets All 6 Mana Pools and Storm Count Simultaneously
    testWidgets('1.4: Atomic Clear button zeroes all 6 mana pools and storm counter simultaneously', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      var player = createTestPlayer(
        mana: {'W': 5, 'U': 10, 'B': 15, 'R': 20, 'G': 25, 'C': 30},
        storm: 42,
      );
      late StateSetter setHostState;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (ctx, setState) {
                setHostState = setState;
                return FloatingManaDrawerWidget(
                  player: player,
                  autoCloseOnClear: false,
                  onManaClear: () {
                    setHostState(() {
                      player = player.copyWith(
                        floatingMana: const {'W': 0, 'U': 0, 'B': 0, 'R': 0, 'G': 0, 'C': 0},
                        stormCount: 0,
                      );
                    });
                  },
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify non-zero initial values
      expect(player.floatingMana['W'], 5);
      expect(player.floatingMana['C'], 30);
      expect(player.stormCount, 42);

      // Verify both clear button finders locate the red clear button
      expect(find.byKey(const Key('mana_drawer_clear_button')), findsOneWidget);
      expect(find.byKey(Key('clear_pool_btn_${player.id}')), findsOneWidget);

      // Tap Clear Button
      await tester.tap(find.byKey(const Key('mana_drawer_clear_button')));
      await tester.pump();

      // All 6 pools and storm count reset to 0 in one atomic tap
      for (final color in FloatingManaDrawerWidget.manaColors) {
        expect(player.floatingMana[color], 0);
        final valWidget = tester.widget<Text>(find.byKey(Key('mana_val_${color}_${player.id}')));
        expect(valWidget.data, '0');
      }
      expect(player.stormCount, 0);
      expect(tester.widget<Text>(find.byKey(Key('storm_count_${player.id}'))).data, 'Storm Count: 0');
    });

    // 1.5 Dedicated Close Button Pops Modal Sheet
    testWidgets('1.5: Dedicated Close button dismisses modal sheet', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final player = createTestPlayer();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                key: const Key('open_mana_btn'),
                onPressed: () {
                  showModalBottomSheet<void>(
                    context: ctx,
                    isScrollControlled: true,
                    builder: (_) => FloatingManaDrawerWidget(player: player),
                  );
                },
                child: const Text('Open Mana Sheet'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open sheet
      await tester.tap(find.byKey(const Key('open_mana_btn')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('mana_drawer_close_button')), findsOneWidget);

      // Tap Close button
      await tester.tap(find.byKey(const Key('mana_drawer_close_button')));
      await tester.pumpAndSettle();

      // Sheet is dismissed
      expect(find.byKey(const Key('mana_drawer_close_button')), findsNothing);
    });

    // 1.6 Real-Time Live UI Reactivity Inside PodScaffoldWidget Modal Sheet
    testWidgets('1.6: PodScaffoldWidget real-time UI reactivity inside showModalBottomSheet', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final p1 = createTestPlayer(id: 'p1', name: 'Alice');
      final podState = PodState(
        sessionId: 'mana_live_session',
        format: 'commander',
        players: [p1, createTestPlayer(id: 'p2', name: 'Bob', seatIndex: 1)],
        startingLife: 40,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PodScaffoldWidget(podState: podState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open mana drawer via CentralUtilityBar mana button
      final manaBarBtn = find.byKey(const Key('central_hub_mana_button'));
      expect(manaBarBtn, findsOneWidget);
      await tester.tap(manaBarBtn);
      await tester.pumpAndSettle();

      // Drawer is open
      expect(find.byKey(const Key('mana_drawer_sheet_p1')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('mana_val_W_p1'))).data, '0');
      expect(tester.widget<Text>(find.byKey(const Key('storm_count_p1'))).data, 'Storm Count: 0');

      // Tap White + twice without closing sheet
      await tester.tap(find.byKey(const Key('mana_inc_W_p1')));
      await tester.pump();
      expect(tester.widget<Text>(find.byKey(const Key('mana_val_W_p1'))).data, '1');

      await tester.tap(find.byKey(const Key('mana_inc_W_p1')));
      await tester.pump();
      expect(tester.widget<Text>(find.byKey(const Key('mana_val_W_p1'))).data, '2');

      // Tap Storm + 3 times without closing sheet
      await tester.tap(find.byKey(const Key('storm_inc_p1')));
      await tester.tap(find.byKey(const Key('storm_inc_p1')));
      await tester.tap(find.byKey(const Key('storm_inc_p1')));
      await tester.pump();
      expect(tester.widget<Text>(find.byKey(const Key('storm_count_p1'))).data, 'Storm Count: 3');

      // Tap Clear button (auto-closes and clears)
      await tester.tap(find.byKey(const Key('mana_drawer_clear_button')));
      await tester.pumpAndSettle();

      // Sheet dismissed
      expect(find.byKey(const Key('mana_drawer_sheet_p1')), findsNothing);

      // Reopen to confirm 0s persisted
      await tester.tap(manaBarBtn);
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.byKey(const Key('mana_val_W_p1'))).data, '0');
      expect(tester.widget<Text>(find.byKey(const Key('storm_count_p1'))).data, 'Storm Count: 0');

      // Close cleanly
      await tester.tap(find.byKey(const Key('mana_drawer_close_button')));
      await tester.pumpAndSettle();
    });
  });

  // ===========================================================================
  // GROUP 2: Randomizer Hub & Highlight Adversarial Stress (R5.2)
  // ===========================================================================
  group('Challenger M5-1: Randomizer Hub & Highlight Adversarial Stress (R5.2)', () {
    // 2.1 Custom Dice Stepper Clamping at 2 and Stepping to 100
    testWidgets('2.1: Custom dice stepper clamps at 2 and steps up to 100 with valid roll output', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RandomizerHubModal(playerCount: 4),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initial custom sides is D20
      expect(find.byKey(const Key('custom_dice_sides_text')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const Key('custom_dice_sides_text'))).data, 'D20');

      // Tap minus 25 times: should clamp at D2 and never decrease to D1 or D0
      for (int i = 0; i < 25; i++) {
        await tester.tap(find.byKey(const Key('custom_dice_minus_btn')));
      }
      await tester.pump();
      expect(tester.widget<Text>(find.byKey(const Key('custom_dice_sides_text'))).data, 'D2');

      // Roll custom D2 die
      await tester.tap(find.byKey(const Key('custom_dice_roll_btn')));
      await tester.pump();

      final d2ResultText = tester.widget<Text>(find.byKey(const Key('randomizer_result_text'))).data!;
      expect(d2ResultText, matches(RegExp(r'^D2 Roll: (1|2)$')));

      // Step up to D100: tap plus 98 times (2 + 98 = 100)
      for (int i = 0; i < 98; i++) {
        await tester.tap(find.byKey(const Key('custom_dice_plus_btn')));
      }
      await tester.pump();
      expect(tester.widget<Text>(find.byKey(const Key('custom_dice_sides_text'))).data, 'D100');

      // Roll custom D100 die
      await tester.tap(find.byKey(const Key('custom_dice_roll_btn')));
      await tester.pump();

      final d100ResultText = tester.widget<Text>(find.byKey(const Key('randomizer_result_text'))).data!;
      expect(d100ResultText, matches(RegExp(r'^D100 Roll: (\d+)$')));
      final match = RegExp(r'^D100 Roll: (\d+)$').firstMatch(d100ResultText);
      final rolledVal = int.parse(match!.group(1)!);
      expect(rolledVal >= 1 && rolledVal <= 100, isTrue);

      // Verify history strip shows the D100 roll
      expect(find.byKey(const Key('randomizer_history_strip')), findsOneWidget);
      expect(find.byKey(const Key('recent_roll_0')), findsOneWidget);
      final roll0Text = tester.widget<Text>(find.descendant(
        of: find.byKey(const Key('recent_roll_0')),
        matching: find.byType(Text),
      )).data!;
      expect(roll0Text, 'D100: $rolledVal');
    });

    // 2.2 RandomizerService Adversarial Domain Inputs (Negative, Zero, Massive Sides)
    test('2.2: RandomizerService handles adversarial inputs robustly without crash or range violation', () {
      final service = RandomizerService();

      // Negative sides -> clamps to >= 2
      final negResult = service.rollCustomDice(-50);
      expect(negResult >= 1 && negResult <= 2, isTrue);

      // Zero sides -> clamps to >= 2
      final zeroResult = service.rollCustomDice(0);
      expect(zeroResult >= 1 && zeroResult <= 2, isTrue);

      // 1 side -> clamps to >= 2
      final oneResult = service.rollCustomDice(1);
      expect(oneResult >= 1 && oneResult <= 2, isTrue);

      // Massive sides
      final hugeResult = service.rollCustomDice(1000000);
      expect(hugeResult >= 1 && hugeResult <= 1000000, isTrue);

      // selectRandomPlayerIndex with 0 or negative players returns 0 safely
      expect(service.selectRandomPlayerIndex(0), 0);
      expect(service.selectRandomPlayerIndex(-5), 0);

      // selectRandomOpponentIndex with <= 1 player returns selfSeatIndex safely
      expect(service.selectRandomOpponentIndex(1, 0), 0);
      expect(service.selectRandomOpponentIndex(0, 0), 0);
    });

    // 2.3 5-Roll History Strip FIFO Ordering and 5-Entry Cap Under Continuous Rolling
    testWidgets('2.3: History strip displays strictly the 5 most recent entries in newest-first order', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final service = RandomizerService();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RandomizerHubModal(
              playerCount: 4,
              randomizerService: service,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Execute 8 rolls/flips in sequence
      // 1. Flip Coin
      await tester.tap(find.byKey(const Key('coin_flip_btn')));
      await tester.pump();

      // 2. D4
      await tester.tap(find.byKey(const Key('dice_d4_btn')));
      await tester.pump();

      // 3. D6
      await tester.tap(find.byKey(const Key('dice_d6_btn')));
      await tester.pump();

      // 4. D8
      await tester.tap(find.byKey(const Key('dice_d8_btn')));
      await tester.pump();

      // 5. D10
      await tester.tap(find.byKey(const Key('dice_d10_btn')));
      await tester.pump();

      // 6. D12
      await tester.tap(find.byKey(const Key('dice_d12_btn')));
      await tester.pump();

      // 7. D20
      await tester.tap(find.byKey(const Key('dice_d20_btn')));
      await tester.pump();

      // 8. Custom D20 Roll
      await tester.tap(find.byKey(const Key('custom_dice_roll_btn')));
      await tester.pump();

      // Verify exactly 5 entries rendered in recent rolls strip (recent_roll_0 .. 4)
      expect(find.byKey(const Key('recent_roll_0')), findsOneWidget);
      expect(find.byKey(const Key('recent_roll_1')), findsOneWidget);
      expect(find.byKey(const Key('recent_roll_2')), findsOneWidget);
      expect(find.byKey(const Key('recent_roll_3')), findsOneWidget);
      expect(find.byKey(const Key('recent_roll_4')), findsOneWidget);
      expect(find.byKey(const Key('recent_roll_5')), findsNothing);

      // Verify service recentRolls has exactly 5 items
      expect(service.recentRolls.length, 5);

      // Verify newest-first ordering:
      // index 0: Custom D20
      // index 1: D20
      // index 2: D12
      // index 3: D10
      // index 4: D8
      // Older items (D6, D4, Coin) pushed out
      final roll0 = tester.widget<Text>(find.descendant(
        of: find.byKey(const Key('recent_roll_0')),
        matching: find.byType(Text),
      )).data!;
      expect(roll0, startsWith('D20:'));

      final roll1 = tester.widget<Text>(find.descendant(
        of: find.byKey(const Key('recent_roll_1')),
        matching: find.byType(Text),
      )).data!;
      expect(roll1, startsWith('D20:'));

      final roll2 = tester.widget<Text>(find.descendant(
        of: find.byKey(const Key('recent_roll_2')),
        matching: find.byType(Text),
      )).data!;
      expect(roll2, startsWith('D12:'));

      final roll3 = tester.widget<Text>(find.descendant(
        of: find.byKey(const Key('recent_roll_3')),
        matching: find.byType(Text),
      )).data!;
      expect(roll3, startsWith('D10:'));

      final roll4 = tester.widget<Text>(find.descendant(
        of: find.byKey(const Key('recent_roll_4')),
        matching: find.byType(Text),
      )).data!;
      expect(roll4, startsWith('D8:'));
    });

    // 2.4 Opponent Selector Gating (Disabled in 1P & 2P, Enabled in 3P+)
    testWidgets('2.4: Opponent selector strictly disabled for 1P and 2P pods, enabled for 3P+ pods', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // 1P Pod -> Disabled
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RandomizerHubModal(playerCount: 1),
          ),
        ),
      );
      await tester.pumpAndSettle();
      var opponentBtn = tester.widget<ElevatedButton>(find.byKey(const Key('random_opponent_btn')));
      expect(opponentBtn.onPressed, isNull);

      // 2P Pod -> Disabled
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RandomizerHubModal(playerCount: 2),
          ),
        ),
      );
      await tester.pumpAndSettle();
      opponentBtn = tester.widget<ElevatedButton>(find.byKey(const Key('random_opponent_btn')));
      expect(opponentBtn.onPressed, isNull);

      // 3P Pod -> Enabled
      int? selectedOpponent;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RandomizerHubModal(
              playerCount: 3,
              selfSeatIndex: 0,
              onOpponentSelected: (idx) {
                selectedOpponent = idx;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      opponentBtn = tester.widget<ElevatedButton>(find.byKey(const Key('random_opponent_btn')));
      expect(opponentBtn.onPressed, isNotNull);

      // Tap opponent selector
      await tester.tap(find.byKey(const Key('random_opponent_btn')));
      await tester.pump();
      expect(selectedOpponent, isNotNull);
      // For 3P pod with selfSeatIndex = 0, opponent must be Seat 1 or 2 (never 0)
      expect(selectedOpponent == 1 || selectedOpponent == 2, isTrue);

      final resultText = tester.widget<Text>(find.byKey(const Key('randomizer_result_text'))).data!;
      expect(resultText, anyOf('Chosen Opponent: Seat 2', 'Chosen Opponent: Seat 3'));

      // 4P Pod -> Enabled
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RandomizerHubModal(playerCount: 4),
          ),
        ),
      );
      await tester.pumpAndSettle();
      opponentBtn = tester.widget<ElevatedButton>(find.byKey(const Key('random_opponent_btn')));
      expect(opponentBtn.onPressed, isNotNull);

      // 6P Pod -> Enabled
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RandomizerHubModal(playerCount: 6),
          ),
        ),
      );
      await tester.pumpAndSettle();
      opponentBtn = tester.widget<ElevatedButton>(find.byKey(const Key('random_opponent_btn')));
      expect(opponentBtn.onPressed, isNotNull);
    });

    // 2.5 Long-Press Central Hub Die Button Triggers Quick Starting Player Roll & Gold Highlight
    testWidgets('2.5: Long-press central hub button applies AppColors.accentGold 3.5px border and shadow', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      int? highlightedPlayerSeat;
      final podState = PodState(
        sessionId: 'highlight_session',
        format: 'commander',
        players: [
          createTestPlayer(id: 'p1', name: 'Alice', seatIndex: 0),
          createTestPlayer(id: 'p2', name: 'Bob', seatIndex: 1),
          createTestPlayer(id: 'p3', name: 'Charlie', seatIndex: 2),
          createTestPlayer(id: 'p4', name: 'Diana', seatIndex: 3),
        ],
        startingLife: 40,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PodScaffoldWidget(
              podState: podState,
              onPlayerSelected: (seat) {
                highlightedPlayerSeat = seat;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Before long-press: all 4 quadrants have isHighlighted == false
      final quadrantsBefore = tester.widgetList<PlayerQuadrantWidget>(find.byType(PlayerQuadrantWidget)).toList();
      expect(quadrantsBefore.length, 4);
      for (final q in quadrantsBefore) {
        expect(q.isHighlighted, isFalse);
      }

      // Long press CenterHubButton
      final centerHubFinder = find.byType(CenterHubButton);
      expect(centerHubFinder, findsOneWidget);
      await tester.longPress(centerHubFinder);
      await tester.pump();

      // A player was selected
      expect(highlightedPlayerSeat, isNotNull);
      expect(highlightedPlayerSeat! >= 0 && highlightedPlayerSeat! < 4, isTrue);

      // Verify exactly ONE quadrant is highlighted
      final quadrantsActive = tester.widgetList<PlayerQuadrantWidget>(find.byType(PlayerQuadrantWidget)).toList();
      int highlightedCount = 0;
      for (int i = 0; i < quadrantsActive.length; i++) {
        if (quadrantsActive[i].isHighlighted) {
          highlightedCount++;
          expect(quadrantsActive[i].player.seatIndex, highlightedPlayerSeat);
        }
      }
      expect(highlightedCount, 1);

      // Verify the highlighted quadrant container has gold border (3.5px) and glowing shadow
      final animContainers = tester.widgetList<AnimatedContainer>(
        find.descendant(
          of: find.byType(PlayerQuadrantWidget),
          matching: find.byType(AnimatedContainer),
        ),
      ).toList();

      bool foundGoldBorder = false;
      bool foundGoldShadow = false;

      for (final ac in animContainers) {
        final dec = ac.decoration as BoxDecoration?;
        if (dec != null && dec.border != null) {
          final border = dec.border as Border;
          if (border.top.color == AppColors.accentGold && border.top.width == 3.5) {
            foundGoldBorder = true;
          }
          if (dec.boxShadow != null && dec.boxShadow!.isNotEmpty) {
            final shadow = dec.boxShadow!.first;
            if (shadow.color == AppColors.accentGold.withValues(alpha: 0.6) &&
                shadow.blurRadius == 16 &&
                shadow.spreadRadius == 2) {
              foundGoldShadow = true;
            }
          }
        }
      }

      expect(foundGoldBorder, isTrue);
      expect(foundGoldShadow, isTrue);
    });

    // 2.6 Board Highlight Auto-Clear 3000ms Lifecycle Timing
    testWidgets('2.6: Board highlight persists at 2900ms and auto-clears at 3000ms', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final podState = PodState(
        sessionId: 'timer_session',
        format: 'commander',
        players: [
          createTestPlayer(id: 'p1', name: 'Alice', seatIndex: 0),
          createTestPlayer(id: 'p2', name: 'Bob', seatIndex: 1),
        ],
        startingLife: 40,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PodScaffoldWidget(podState: podState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Trigger quick random player via CenterHubButton long press
      await tester.longPress(find.byType(CenterHubButton));
      await tester.pump();

      // Active highlight present
      expect(
        tester.widgetList<PlayerQuadrantWidget>(find.byType(PlayerQuadrantWidget))
            .any((q) => q.isHighlighted),
        isTrue,
      );

      // Note: tester.longPress pumps kLongPressTimeout (500ms) + kPressTimeout (100ms).
      // onLongPress fired at 500ms, so 100ms already elapsed when longPress returned.
      // Advance by 1500ms -> 1600ms elapsed since timer started (still highlighted)
      await tester.pump(const Duration(milliseconds: 1500));
      expect(
        tester.widgetList<PlayerQuadrantWidget>(find.byType(PlayerQuadrantWidget))
            .any((q) => q.isHighlighted),
        isTrue,
      );

      // Advance by 1200ms -> 2800ms elapsed since timer started (still highlighted)
      await tester.pump(const Duration(milliseconds: 1200));
      expect(
        tester.widgetList<PlayerQuadrantWidget>(find.byType(PlayerQuadrantWidget))
            .any((q) => q.isHighlighted),
        isTrue,
      );

      // Advance by 300ms -> 3100ms elapsed (> 3000ms timer duration), highlight auto-clears
      await tester.pump(const Duration(milliseconds: 300));
      for (final q in tester.widgetList<PlayerQuadrantWidget>(find.byType(PlayerQuadrantWidget))) {
        expect(q.isHighlighted, isFalse);
      }
    });

    // 2.7 Rapid Consecutive Long-Presses Stress Test
    testWidgets('2.7: Rapid consecutive long-presses reset highlight timer cleanly without leakage or crash', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final podState = PodState(
        sessionId: 'rapid_long_press_session',
        format: 'commander',
        players: [
          createTestPlayer(id: 'p1', name: 'Alice', seatIndex: 0),
          createTestPlayer(id: 'p2', name: 'Bob', seatIndex: 1),
          createTestPlayer(id: 'p3', name: 'Charlie', seatIndex: 2),
        ],
        startingLife: 40,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PodScaffoldWidget(podState: podState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final hubFinder = find.byType(CenterHubButton);

      // 5 consecutive rapid long presses with 500ms intervals (each cancels and restarts timer)
      for (int i = 0; i < 5; i++) {
        await tester.longPress(hubFinder);
        await tester.pump(const Duration(milliseconds: 500));
        expect(
          tester.widgetList<PlayerQuadrantWidget>(find.byType(PlayerQuadrantWidget))
              .any((q) => q.isHighlighted),
          isTrue,
        );
      }

      // Now wait the full 3000ms from the last long-press
      await tester.pump(const Duration(milliseconds: 3000));

      // After 3000ms, all highlights are cleared
      for (final q in tester.widgetList<PlayerQuadrantWidget>(find.byType(PlayerQuadrantWidget))) {
        expect(q.isHighlighted, isFalse);
      }
      expect(tester.takeException(), isNull);
    });
  });
}
