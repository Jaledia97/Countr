// Copyright (c) 2026 Countr. All rights reserved.
// Adversarial empirical stress tests for ManaCostBar under narrow width constraints and edge cases.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/features/symbology/presentation/widgets/mana_cost_bar.dart';
import 'package:countr/features/symbology/presentation/widgets/mana_symbol_icon.dart';

void main() {
  group('ManaCostBar Empirical Stress Tests - Narrow Width Constraints', () {
    const urDragon = '{4}{W}{U}{B}{R}{G}';
    const progenitus = '{W}{W}{U}{U}{B}{B}{R}{R}{G}{G}';
    const ultraMassive20 = '{W}{W}{U}{U}{B}{B}{R}{R}{G}{G}{W}{W}{U}{U}{B}{B}{R}{R}{G}{G}';

    testWidgets('DeckBuilder trailing column constraint (width: 80px): The Ur-Dragon has 0 overflows',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 80.0,
                height: 40.0,
                child: ManaCostBar(
                  manaCost: urDragon,
                  symbolSize: 13.0,
                  spacing: 2.0,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.byWidgetPredicate((w) => w is FittedBox && w.fit == BoxFit.scaleDown),
        findsOneWidget,
      );
      expect(find.byType(ManaSymbolIcon), findsNWidgets(6));

      // Verify bounds fit within 80px width
      final renderBox = tester.renderObject<RenderBox>(find.byType(ManaCostBar));
      expect(renderBox.size.width, lessThanOrEqualTo(80.0));
    });

    testWidgets('DeckBuilder trailing column constraint (width: 80px): Progenitus (10 symbols) has 0 overflows',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 80.0,
                height: 40.0,
                child: ManaCostBar(
                  manaCost: progenitus,
                  symbolSize: 13.0,
                  spacing: 2.0,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.byWidgetPredicate((w) => w is FittedBox && w.fit == BoxFit.scaleDown),
        findsOneWidget,
      );
      expect(find.byType(ManaSymbolIcon), findsNWidgets(10));

      final renderBox = tester.renderObject<RenderBox>(find.byType(ManaCostBar));
      expect(renderBox.size.width, lessThanOrEqualTo(80.0));
    });

    testWidgets('Extreme narrow constraint (width: 50px): The Ur-Dragon has 0 overflows',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 50.0,
                height: 30.0,
                child: ManaCostBar(
                  manaCost: urDragon,
                  symbolSize: 13.0,
                  spacing: 2.0,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(ManaSymbolIcon), findsNWidgets(6));
      final renderBox = tester.renderObject<RenderBox>(find.byType(ManaCostBar));
      expect(renderBox.size.width, lessThanOrEqualTo(50.0));
    });

    testWidgets('Extreme narrow constraint (width: 50px): Progenitus has 0 overflows',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 50.0,
                height: 30.0,
                child: ManaCostBar(
                  manaCost: progenitus,
                  symbolSize: 13.0,
                  spacing: 2.0,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(ManaSymbolIcon), findsNWidgets(10));
      final renderBox = tester.renderObject<RenderBox>(find.byType(ManaCostBar));
      expect(renderBox.size.width, lessThanOrEqualTo(50.0));
    });

    testWidgets('Microscopic constraint (width: 30px): The Ur-Dragon has 0 overflows',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 30.0,
                height: 20.0,
                child: ManaCostBar(
                  manaCost: urDragon,
                  symbolSize: 13.0,
                  spacing: 2.0,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(ManaSymbolIcon), findsNWidgets(6));
      final renderBox = tester.renderObject<RenderBox>(find.byType(ManaCostBar));
      expect(renderBox.size.width, lessThanOrEqualTo(30.0));
    });

    testWidgets('Microscopic constraint (width: 30px): Progenitus has 0 overflows',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 30.0,
                height: 20.0,
                child: ManaCostBar(
                  manaCost: progenitus,
                  symbolSize: 13.0,
                  spacing: 2.0,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(ManaSymbolIcon), findsNWidgets(10));
      final renderBox = tester.renderObject<RenderBox>(find.byType(ManaCostBar));
      expect(renderBox.size.width, lessThanOrEqualTo(30.0));
    });

    testWidgets('Ultra-massive 20-symbol cost inside 30px constraint has 0 overflows',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 30.0,
                height: 20.0,
                child: ManaCostBar(
                  manaCost: ultraMassive20,
                  symbolSize: 14.0,
                  spacing: 2.0,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(ManaSymbolIcon), findsNWidgets(20));
      final renderBox = tester.renderObject<RenderBox>(find.byType(ManaCostBar));
      expect(renderBox.size.width, lessThanOrEqualTo(30.0));
    });

    testWidgets('Adversarial microscopic bounds (width: 10px, 5px, 1px) scale cleanly without crashing',
        (tester) async {
      for (final w in [10.0, 5.0, 1.0]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: w,
                height: 10.0,
                child: const ManaCostBar(
                  manaCost: progenitus,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull, reason: 'Failed at width: $w');
        final renderBox = tester.renderObject<RenderBox>(find.byType(ManaCostBar));
        expect(renderBox.size.width, lessThanOrEqualTo(w));
      }
    });

    testWidgets('Negative Control: without FittedBox, Progenitus inside 80px triggers RenderFlex overflow',
        (tester) async {
      final originalOnError = FlutterError.onError;
      FlutterErrorDetails? caughtDetails;
      FlutterError.onError = (details) {
        caughtDetails = details;
      };

      try {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 80.0,
                height: 30.0,
                child: ManaCostBar(
                  manaCost: progenitus,
                  enableFittedBox: false,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Progenitus natural width: 10 * 13 + 9 * 2 = 148px > 80px => overflows by ~68px
        expect(caughtDetails, isNotNull);
        expect(caughtDetails!.toString(), contains('A RenderFlex overflowed'));
      } finally {
        FlutterError.onError = originalOnError;
      }
    });
  });

  group('ManaCostBar Empirical Stress Tests - Symbol Sequencing and Spacing', () {
    testWidgets('strictly preserves symbol order for The Ur-Dragon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ManaCostBar(manaCost: '{4}{W}{U}{B}{R}{G}'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final icons = tester
          .widgetList<ManaSymbolIcon>(find.byType(ManaSymbolIcon))
          .toList();
      expect(icons.length, equals(6));
      expect(icons[0].symbolCode, equals('4'));
      expect(icons[0].assetPath, equals('assets/symbology/4.svg'));
      expect(icons[1].symbolCode, equals('W'));
      expect(icons[1].assetPath, equals('assets/symbology/W.svg'));
      expect(icons[2].symbolCode, equals('U'));
      expect(icons[2].assetPath, equals('assets/symbology/U.svg'));
      expect(icons[3].symbolCode, equals('B'));
      expect(icons[3].assetPath, equals('assets/symbology/B.svg'));
      expect(icons[4].symbolCode, equals('R'));
      expect(icons[4].assetPath, equals('assets/symbology/R.svg'));
      expect(icons[5].symbolCode, equals('G'));
      expect(icons[5].assetPath, equals('assets/symbology/G.svg'));
    });

    testWidgets('strictly preserves symbol order for Progenitus', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ManaCostBar(manaCost: '{W}{W}{U}{U}{B}{B}{R}{R}{G}{G}'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final icons = tester
          .widgetList<ManaSymbolIcon>(find.byType(ManaSymbolIcon))
          .toList();
      expect(icons.length, equals(10));
      final expectedCodes = ['W', 'W', 'U', 'U', 'B', 'B', 'R', 'R', 'G', 'G'];
      for (int i = 0; i < expectedCodes.length; i++) {
        expect(icons[i].symbolCode, equals(expectedCodes[i]));
        expect(icons[i].assetPath, equals('assets/symbology/${expectedCodes[i]}.svg'));
      }
    });

    testWidgets('preserves exact spacing between consecutive symbols', (tester) async {
      const customSpacing = 4.5;
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ManaCostBar(
              manaCost: '{1}{U}{R}',
              spacing: customSpacing,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final spacers = tester
          .widgetList<SizedBox>(find.descendant(
            of: find.byType(Row),
            matching: find.byType(SizedBox),
          ))
          .where((box) => box.width == customSpacing)
          .toList();

      // Between 3 symbols, exactly 2 spacers must exist
      expect(spacers.length, equals(2));
    });
  });

  group('ManaCostBar Empirical Stress Tests - Empty Strings & Whitespace', () {
    testWidgets('empty string "" renders cleanly as SizedBox.shrink with 0 dimensions',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: ManaCostBar(manaCost: ''),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(ManaSymbolIcon), findsNothing);
      expect(find.byType(Text), findsNothing);
      expect(find.byType(FittedBox), findsNothing);

      final renderBox = tester.renderObject<RenderBox>(find.byType(ManaCostBar));
      expect(renderBox.size, equals(Size.zero));
    });

    testWidgets('whitespace strings render cleanly as SizedBox.shrink with 0 dimensions',
        (tester) async {
      final whitespaceInputs = [
        '   ',
        '\t',
        '\n',
        '  \t \n \r\n  ',
      ];

      for (final ws in whitespaceInputs) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: ManaCostBar(manaCost: ws),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(ManaSymbolIcon), findsNothing);
        expect(find.byType(Text), findsNothing);
        expect(find.byType(FittedBox), findsNothing);

        final renderBox = tester.renderObject<RenderBox>(find.byType(ManaCostBar));
        expect(renderBox.size, equals(Size.zero));
      }
    });
  });

  group('ManaCostBar Empirical Stress Tests - Unbracketed & Non-Standard Fallbacks', () {
    testWidgets('unbracketed string "3W" falls back to Text without throwing',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ManaCostBar(manaCost: '3W'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(ManaSymbolIcon), findsNothing);
      expect(find.text('3W'), findsOneWidget);
    });

    testWidgets('unbracketed word "Free" falls back to Text without throwing',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ManaCostBar(manaCost: 'Free'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(ManaSymbolIcon), findsNothing);
      expect(find.text('Free'), findsOneWidget);
    });

    testWidgets('unbracketed non-standard phrases ("No Cost", "Check") fall back cleanly',
        (tester) async {
      for (final phrase in ['No Cost', 'Check', 'N/A', '—']) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ManaCostBar(manaCost: phrase),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(ManaSymbolIcon), findsNothing);
        expect(find.text(phrase), findsOneWidget);
      }
    });

    testWidgets('malformed brackets without matching close bracket "{2W" fall back to Text',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ManaCostBar(manaCost: '{2W'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(ManaSymbolIcon), findsNothing);
      expect(find.text('{2W'), findsOneWidget);
    });

    testWidgets('empty brackets "{}" fall back to Text without throwing',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ManaCostBar(manaCost: '{}'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(ManaSymbolIcon), findsNothing);
      expect(find.text('{}'), findsOneWidget);
    });
  });

  group('ManaCostBar Empirical Stress Tests - Accessibility Semantics', () {
    testWidgets('The Ur-Dragon generates composite spoken mana cost label', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ManaCostBar(manaCost: '{4}{W}{U}{B}{R}{G}'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final semanticsFinder = find.byWidgetPredicate(
        (w) => w is Semantics && (w.properties.label?.startsWith('Mana cost:') ?? false),
      );
      expect(semanticsFinder, findsOneWidget);

      final semantics = tester.widget<Semantics>(semanticsFinder);
      expect(semantics.properties.label, contains('four generic mana'));
      expect(semantics.properties.label, contains('one white mana'));
      expect(semantics.properties.label, contains('one blue mana'));
      expect(semantics.properties.label, contains('one black mana'));
      expect(semantics.properties.label, contains('one red mana'));
      expect(semantics.properties.label, contains('one green mana'));
    });

    testWidgets('Custom semanticLabel overrides auto-generated label', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ManaCostBar(
              manaCost: '{W}{U}',
              semanticLabel: 'Azorius guild cost',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final semantics = tester.widget<Semantics>(
        find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Azorius guild cost'),
      );
      expect(semantics.properties.label, equals('Azorius guild cost'));
    });
  });

  group('ManaCostBar Empirical Stress Tests - Realistic DeckBuilder Integration & Alignment', () {
    const urDragon = '{4}{W}{U}{B}{R}{G}';
    const progenitus = '{W}{W}{U}{U}{B}{B}{R}{R}{G}{G}';

    testWidgets('Full DeckBuilder card row at 320px viewport with Progenitus has 0 overflows',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320.0,
                child: Row(
                  children: [
                    // 1. Thumbnail (40x56)
                    Container(width: 40, height: 56, color: Colors.grey),
                    const SizedBox(width: 10),
                    // 2. Card details (Expanded)
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Progenitus', overflow: TextOverflow.ellipsis),
                          Text('Legendary Creature — Hydra Avatar',
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 3. Trailing Metrics column (maxWidth: 80)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 80),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ManaCostBar(
                            manaCost: progenitus,
                            alignment: Alignment.centerRight,
                          ),
                          SizedBox(height: 4),
                          Text(r'$14.99', style: TextStyle(fontSize: 10)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(ManaSymbolIcon), findsNWidgets(10));
      final barFinder = find.byType(ManaCostBar);
      expect(barFinder, findsOneWidget);
      final renderBox = tester.renderObject<RenderBox>(barFinder);
      expect(renderBox.size.width, lessThanOrEqualTo(80.0));
    });

    testWidgets('Full DeckBuilder card row at 320px viewport with The Ur-Dragon has 0 overflows',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320.0,
                child: Row(
                  children: [
                    Container(width: 40, height: 56, color: Colors.grey),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text('The Ur-Dragon', overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 80),
                      child: const ManaCostBar(
                        manaCost: urDragon,
                        alignment: Alignment.centerRight,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(ManaSymbolIcon), findsNWidgets(6));
      final renderBox = tester.renderObject<RenderBox>(find.byType(ManaCostBar));
      expect(renderBox.size.width, lessThanOrEqualTo(80.0));
    });

    testWidgets('Extreme oversized symbolSize (32.0px) under 50px constraint scales down without overflow',
        (tester) async {
      // 10 symbols @ 32px + 9 * 4px spacing = 356px inside 50px constraint
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 50.0,
              height: 40.0,
              child: ManaCostBar(
                manaCost: progenitus,
                symbolSize: 32.0,
                spacing: 4.0,
                enableFittedBox: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(ManaSymbolIcon), findsNWidgets(10));
      final renderBox = tester.renderObject<RenderBox>(find.byType(ManaCostBar));
      expect(renderBox.size.width, lessThanOrEqualTo(50.0));
    });

    testWidgets('Fallback text under 30px constraint renders without RenderFlex exception',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 30.0,
              height: 20.0,
              child: ManaCostBar(
                manaCost: 'UnlistedCost',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('UnlistedCost'), findsOneWidget);
    });
  });
}

