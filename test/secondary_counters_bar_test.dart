// Copyright (c) 2026 Countr. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/features/life_counter/domain/models/pod_state.dart';
import 'package:countr/features/life_counter/presentation/widgets/day_night_toggle_widget.dart';
import 'package:countr/features/life_counter/presentation/widgets/secondary_counters_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestHarness(Widget child, {Size size = const Size(800, 600)}) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: MediaQuery(
              data: MediaQueryData(size: size),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  group('SecondaryCountersBar Tests (Features 35, 36, 37)', () {
    const safePlayer = PodPlayerState(
      id: 'p1',
      seatIndex: 0,
      name: 'Alice',
      life: 40,
      poison: 3,
      energy: 5,
      experience: 2,
      commanderTax: 3, // Tax = 6
    );

    const lethalPoisonPlayer = PodPlayerState(
      id: 'p1',
      seatIndex: 0,
      name: 'Alice',
      life: 30,
      poison: 10,
      energy: 0,
      experience: 0,
      commanderTax: 0,
    );

    testWidgets('renders poison, energy, xp, tax steppers and mana button', (tester) async {
      String? updatedCounter;
      int updatedDelta = 0;

      await tester.pumpWidget(
        buildTestHarness(
          SecondaryCountersBar(
            player: safePlayer,
            isTablet: true,
            onCounterDelta: (counter, delta) {
              updatedCounter = counter;
              updatedDelta = delta;
            },
          ),
        ),
      );

      // Verify counter displays
      expect(find.byKey(const Key('val_poison_p1')), findsOneWidget);
      expect(find.text('☠️ 3'), findsOneWidget);

      expect(find.byKey(const Key('val_energy_p1')), findsOneWidget);
      expect(find.text('⚡ 5'), findsOneWidget);

      expect(find.byKey(const Key('val_xp_p1')), findsOneWidget);
      expect(find.text('XP 2'), findsOneWidget);

      expect(find.byKey(const Key('val_tax_p1')), findsOneWidget);
      expect(find.text('Tax: +6'), findsOneWidget);

      expect(find.byKey(const Key('mana_drawer_btn_p1')), findsOneWidget);

      // Increment poison
      await tester.tap(find.byKey(const Key('inc_poison_p1')));
      await tester.pump();
      expect(updatedCounter, 'poison');
      expect(updatedDelta, 1);

      // Decrement poison
      await tester.tap(find.byKey(const Key('dec_poison_p1')));
      await tester.pump();
      expect(updatedCounter, 'poison');
      expect(updatedDelta, -1);

      // Increment energy
      await tester.tap(find.byKey(const Key('inc_energy_p1')));
      await tester.pump();
      expect(updatedCounter, 'energy');
      expect(updatedDelta, 1);

      // Increment experience
      await tester.tap(find.byKey(const Key('inc_xp_p1')));
      await tester.pump();
      expect(updatedCounter, 'xp');
      expect(updatedDelta, 1);

      // Increment commander tax
      await tester.tap(find.byKey(const Key('inc_tax_p1')));
      await tester.pump();
      expect(updatedCounter, 'commanderTax');
      expect(updatedDelta, 1);

      // Decrement commander tax
      await tester.tap(find.byKey(const Key('dec_tax_p1')));
      await tester.pump();
      expect(updatedCounter, 'commanderTax');
      expect(updatedDelta, -1);
    });

    testWidgets('lethal poison displays red accent styling', (tester) async {
      await tester.pumpWidget(
        buildTestHarness(
          const SecondaryCountersBar(
            player: lethalPoisonPlayer,
            isTablet: true,
          ),
        ),
      );

      final poisonTextFinder = find.text('☠️ 10');
      expect(poisonTextFinder, findsOneWidget);
      final textWidget = tester.widget<Text>(poisonTextFinder);
      expect(textWidget.style?.color, equals(Colors.redAccent));
    });

    testWidgets('phone mode renders Wrap layout', (tester) async {
      await tester.pumpWidget(
        buildTestHarness(
          const SecondaryCountersBar(
            player: safePlayer,
            isTablet: false,
          ),
          size: const Size(360, 600),
        ),
      );

      expect(find.byType(Wrap), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsNothing);
    });
  });

  group('DayNightToggleWidget Tests (Feature 39)', () {
    testWidgets('toggles between Day and Night visually with haptic feedback', (tester) async {
      bool isDayState = true;

      await tester.pumpWidget(
        buildTestHarness(
          StatefulBuilder(
            builder: (context, setState) {
              return DayNightToggleWidget(
                isDay: isDayState,
                onToggle: () {
                  setState(() {
                    isDayState = !isDayState;
                  });
                },
              );
            },
          ),
        ),
      );

      // Day state
      expect(find.byKey(const Key('day_night_toggle')), findsOneWidget);
      expect(find.text('Day'), findsOneWidget);
      expect(find.byIcon(Icons.wb_sunny), findsOneWidget);

      // Tap toggle -> flips to Night
      await tester.tap(find.byKey(const Key('day_night_toggle')));
      await tester.pumpAndSettle();

      expect(isDayState, isFalse);
      expect(find.text('Night'), findsOneWidget);
      expect(find.byIcon(Icons.nightlight_round), findsOneWidget);
    });
  });
}
