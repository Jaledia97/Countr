// Copyright (c) 2026 Countr. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/features/life_counter/presentation/dialogs/starting_life_templates_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StartingLifeTemplatesSheet Widget Tests', () {
    testWidgets('Renders all preset chips and default starting life', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StartingLifeTemplatesSheet(
              currentStartingLife: 40,
              currentFormat: 'commander',
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('starting_life_templates_sheet')), findsOneWidget);
      expect(find.byKey(const Key('preset_chip_standard')), findsOneWidget);
      expect(find.byKey(const Key('preset_chip_brawl')), findsOneWidget);
      expect(find.byKey(const Key('preset_chip_commander')), findsOneWidget);
      expect(find.byKey(const Key('preset_chip_custom')), findsOneWidget);
      expect(find.byKey(const Key('starting_life_value_text')), findsOneWidget);
      expect(find.text('Selected: 40 Life'), findsOneWidget);
    });

    testWidgets('Tapping Standard chip switches life to 20', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StartingLifeTemplatesSheet(
              currentStartingLife: 40,
              currentFormat: 'commander',
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('preset_chip_standard')));
      await tester.pump();

      expect(find.text('Selected: 20 Life'), findsOneWidget);
    });

    testWidgets('Tapping Brawl chip switches life to 30', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StartingLifeTemplatesSheet(
              currentStartingLife: 40,
              currentFormat: 'commander',
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('preset_chip_brawl')));
      await tester.pump();

      expect(find.text('Selected: 30 Life'), findsOneWidget);
    });

    testWidgets('Stepper increment and decrement adjust life by 5', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StartingLifeTemplatesSheet(
              currentStartingLife: 40,
              currentFormat: 'commander',
            ),
          ),
        ),
      );

      // Decrement by 5 -> 35
      await tester.tap(find.byKey(const Key('life_dec_btn')));
      await tester.pump();
      expect(find.text('Selected: 35 Life'), findsOneWidget);

      // Increment by 5 twice -> 45
      await tester.tap(find.byKey(const Key('life_inc_btn')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('life_inc_btn')));
      await tester.pump();
      expect(find.text('Selected: 45 Life'), findsOneWidget);
    });

    testWidgets('Custom text input updates starting life dynamically', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StartingLifeTemplatesSheet(
              currentStartingLife: 40,
              currentFormat: 'commander',
            ),
          ),
        ),
      );

      await tester.enterText(find.byKey(const Key('custom_life_input')), '75');
      await tester.pump();

      expect(find.text('Selected: 75 Life'), findsOneWidget);
    });

    testWidgets('Applying template triggers onApply callback and returns map', (tester) async {
      int? appliedLife;
      String? appliedFormat;
      bool? appliedUpdate;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                key: const Key('open_sheet_btn'),
                onPressed: () {
                  StartingLifeTemplatesSheet.show(
                    ctx,
                    currentStartingLife: 40,
                    isMidGame: true,
                    onApply: (life, format, update) {
                      appliedLife = life;
                      appliedFormat = format;
                      appliedUpdate = update;
                    },
                  );
                },
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('open_sheet_btn')));
      await tester.pumpAndSettle();

      // Tap standard (20)
      await tester.tap(find.byKey(const Key('preset_chip_standard')));
      await tester.pump();

      // Tap apply
      await tester.tap(find.byKey(const Key('apply_starting_life_btn')));
      await tester.pumpAndSettle();

      expect(appliedLife, 20);
      expect(appliedFormat, 'standard');
      expect(appliedUpdate, isTrue);
      expect(find.byKey(const Key('starting_life_templates_sheet')), findsNothing);
    });
  });
}
