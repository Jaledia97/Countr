// Copyright (c) 2026 Countr. All rights reserved.
// Unit and Widget test suite for FloatingManaDrawerWidget (Features 40 & 41).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/features/life_counter/domain/models/pod_state.dart';
import 'package:countr/features/life_counter/presentation/widgets/floating_mana_drawer_widget.dart';
import 'package:countr/features/symbology/presentation/widgets/mana_symbol_icon.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const testPlayer = PodPlayerState(
    id: 'p1',
    seatIndex: 0,
    name: 'Teferi Player',
    life: 40,
    floatingMana: {'W': 2, 'U': 4, 'B': 0, 'R': 1, 'G': 0, 'C': 3},
    stormCount: 5,
  );

  group('Feature 40: Floating Mana Drawer & Symbology Integration', () {
    testWidgets('renders all 6 WUBRGC ManaSymbolIcon vector widgets', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FloatingManaDrawerWidget(player: testPlayer),
          ),
        ),
      );

      // Verify sheet container
      expect(find.byKey(const Key('mana_drawer_sheet_p1')), findsOneWidget);

      // Verify 6 ManaSymbolIcon widgets are rendered
      expect(find.byType(ManaSymbolIcon), findsNWidgets(6));

      // Verify exact values for each color
      expect(find.byKey(const Key('mana_val_W_p1')), findsOneWidget);
      expect(find.text('2'), findsOneWidget); // W = 2
      expect(find.byKey(const Key('mana_val_U_p1')), findsOneWidget);
      expect(find.text('4'), findsOneWidget); // U = 4
      expect(find.byKey(const Key('mana_val_R_p1')), findsOneWidget);
      expect(find.text('1'), findsOneWidget); // R = 1
      expect(find.byKey(const Key('mana_val_C_p1')), findsOneWidget);
      expect(find.text('3'), findsOneWidget); // C = 3
    });

    testWidgets('stepper increments and decrements trigger onManaDelta callbacks', (tester) async {
      String? updatedColor;
      int? updatedDelta;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FloatingManaDrawerWidget(
              player: testPlayer,
              onManaDelta: (color, delta) {
                updatedColor = color;
                updatedDelta = delta;
              },
            ),
          ),
        ),
      );

      // Increment Blue mana
      await tester.tap(find.byKey(const Key('mana_inc_U_p1')));
      await tester.pump();
      expect(updatedColor, 'U');
      expect(updatedDelta, 1);

      // Decrement White mana
      await tester.tap(find.byKey(const Key('mana_dec_W_p1')));
      await tester.pump();
      expect(updatedColor, 'W');
      expect(updatedDelta, -1);
    });

    testWidgets('renders storm counter with flash icon and value', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FloatingManaDrawerWidget(player: testPlayer),
          ),
        ),
      );

      expect(find.byKey(const Key('storm_count_p1')), findsOneWidget);
      expect(find.text('Storm Count: 5'), findsOneWidget);
      expect(find.byIcon(Icons.flash_on), findsOneWidget);
    });

    testWidgets('storm steppers trigger onStormDelta when provided', (tester) async {
      int? stormDelta;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FloatingManaDrawerWidget(
              player: testPlayer,
              onStormDelta: (delta) => stormDelta = delta,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('storm_inc_p1')));
      await tester.pump();
      expect(stormDelta, 1);

      await tester.tap(find.byKey(const Key('storm_dec_p1')));
      await tester.pump();
      expect(stormDelta, -1);
    });
  });

  group('Feature 41: One-Tap Clear Pool Action & Undo Support', () {
    testWidgets('tapping Clear Pool invokes onManaClear callback', (tester) async {
      bool cleared = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FloatingManaDrawerWidget(
              player: testPlayer,
              autoCloseOnClear: false,
              onManaClear: () => cleared = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('clear_pool_btn_p1')));
      await tester.pump();

      expect(cleared, isTrue);
    });

    testWidgets('tapping Clear Pool shows Undo SnackBar when onUndo provided', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      bool undoCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FloatingManaDrawerWidget(
              player: testPlayer,
              autoCloseOnClear: false,
              onManaClear: () {},
              onUndo: () => undoCalled = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('clear_pool_btn_p1')));
      await tester.pumpAndSettle(); // Wait for SnackBar slide-in animation

      expect(find.text('Cleared mana pool for Teferi Player'), findsOneWidget);
      expect(find.text('UNDO'), findsOneWidget);

      await tester.tap(find.text('UNDO'));
      await tester.pumpAndSettle();

      expect(undoCalled, isTrue);
    });

    testWidgets('tapping inline Undo button triggers onUndo callback', (tester) async {
      bool undoCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FloatingManaDrawerWidget(
              player: testPlayer,
              onUndo: () => undoCalled = true,
            ),
          ),
        ),
      );

      final undoBtn = find.byKey(const Key('undo_pool_btn_p1'));
      expect(undoBtn, findsOneWidget);

      await tester.tap(undoBtn);
      await tester.pump();

      expect(undoCalled, isTrue);
    });
  });

  group('Responsive Layout & Zero Overflow', () {
    testWidgets('renders in compact 320px width without RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FloatingManaDrawerWidget(player: testPlayer),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('mana_drawer_sheet_p1')), findsOneWidget);
    });
  });
}
