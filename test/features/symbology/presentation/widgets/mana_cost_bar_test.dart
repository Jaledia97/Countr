// Copyright (c) 2026 Countr. All rights reserved.
// Widget test suite for ManaCostBar component.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/features/symbology/presentation/widgets/mana_cost_bar.dart';
import 'package:countr/features/symbology/presentation/widgets/mana_symbol_icon.dart';

void main() {
  group('ManaCostBar - Single and Multi-Symbol Rendering', () {
    testWidgets('renders single symbol {W} with default size 13.0', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ManaCostBar(manaCost: '{W}'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ManaCostBar), findsOneWidget);
      expect(find.byType(ManaSymbolIcon), findsOneWidget);

      final icon = tester.widget<ManaSymbolIcon>(find.byType(ManaSymbolIcon));
      expect(icon.assetPath, equals('assets/symbology/W.svg'));
      expect(icon.size, equals(13.0));
    });

    testWidgets('renders contiguous mana cost {2}{U}{B} in correct sequence',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ManaCostBar(manaCost: '{2}{U}{B}'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ManaSymbolIcon), findsNWidgets(3));

      final icons = tester
          .widgetList<ManaSymbolIcon>(find.byType(ManaSymbolIcon))
          .toList();
      expect(icons[0].assetPath, equals('assets/symbology/2.svg'));
      expect(icons[1].assetPath, equals('assets/symbology/U.svg'));
      expect(icons[2].assetPath, equals('assets/symbology/B.svg'));
    });

    testWidgets('renders hybrid and Phyrexian contiguous cost {W/U}{B/G/P}{P/B}',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ManaCostBar(manaCost: '{W/U}{B/G/P}{P/B}'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ManaSymbolIcon), findsNWidgets(3));
      final icons = tester
          .widgetList<ManaSymbolIcon>(find.byType(ManaSymbolIcon))
          .toList();
      expect(icons[0].assetPath, equals('assets/symbology/WU.svg'));
      expect(icons[1].assetPath, equals('assets/symbology/BGP.svg'));
      expect(icons[2].assetPath, equals('assets/symbology/BP.svg'));
    });
  });

  group('ManaCostBar - Sizing and Spacing Configuration', () {
    testWidgets('applies custom symbolSize to all rendered icons', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ManaCostBar(
              manaCost: '{1}{G}',
              symbolSize: 18.0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final icons = tester
          .widgetList<ManaSymbolIcon>(find.byType(ManaSymbolIcon))
          .toList();
      expect(icons[0].size, equals(18.0));
      expect(icons[1].size, equals(18.0));
    });

    testWidgets('applies custom spacing between icons', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ManaCostBar(
              manaCost: '{R}{G}',
              spacing: 6.0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final sizedBoxes = tester
          .widgetList<SizedBox>(find.descendant(
            of: find.byType(ManaCostBar),
            matching: find.byType(SizedBox),
          ))
          .where((box) => box.width == 6.0)
          .toList();

      expect(sizedBoxes.length, greaterThanOrEqualTo(1));
    });
  });

  group('ManaCostBar - FittedBox Scale-Down & Narrow Constraint Protection', () {
    testWidgets('renders 6-symbol massive cost inside 80px container without RenderFlex overflow',
        (tester) async {
      // 6 symbols @ 14px + 5 * 2px spacing = 94px > 80px constraint
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 80.0,
              height: 30.0,
              child: ManaCostBar(
                manaCost: '{4}{W}{U}{B}{R}{G}',
                symbolSize: 14.0,
                enableFittedBox: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Zero RenderFlex overflow exceptions
      expect(tester.takeException(), isNull);
      final scaleDownFinder = find.byWidgetPredicate(
        (widget) => widget is FittedBox && widget.fit == BoxFit.scaleDown,
      );
      expect(scaleDownFinder, findsOneWidget);

      final fittedBox = tester.widget<FittedBox>(scaleDownFinder);
      expect(fittedBox.fit, equals(BoxFit.scaleDown));
    });

    testWidgets('renders 5-symbol cost in extreme 50px width without overflow',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 50.0,
              height: 25.0,
              child: ManaCostBar(
                manaCost: '{W}{U}{B}{R}{G}',
                symbolSize: 13.0,
                enableFittedBox: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final scaleDownFinder = find.byWidgetPredicate(
        (widget) => widget is FittedBox && widget.fit == BoxFit.scaleDown,
      );
      expect(scaleDownFinder, findsOneWidget);
    });

    testWidgets('disabling enableFittedBox renders raw Row without FittedBox',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ManaCostBar(
              manaCost: '{U}{R}',
              enableFittedBox: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scaleDownFinder = find.byWidgetPredicate(
        (widget) => widget is FittedBox && widget.fit == BoxFit.scaleDown,
      );
      expect(scaleDownFinder, findsNothing);
      expect(find.descendant(of: find.byType(ManaCostBar), matching: find.byType(Row)),
          findsOneWidget);
    });
  });

  group('ManaCostBar - Edge Cases and Fallbacks', () {
    testWidgets('empty manaCost renders SizedBox.shrink without icons', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ManaCostBar(manaCost: ''),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ManaSymbolIcon), findsNothing);
    });

    testWidgets('unbracketed single symbol "W" parses safely into icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ManaCostBar(manaCost: 'W'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ManaSymbolIcon), findsOneWidget);
      final icon = tester.widget<ManaSymbolIcon>(find.byType(ManaSymbolIcon));
      expect(icon.assetPath, equals('assets/symbology/W.svg'));
    });

    testWidgets('invalid manaCost string "Unlisted" falls back to text without crashing',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ManaCostBar(manaCost: 'Unlisted'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(ManaSymbolIcon), findsNothing);
      expect(find.text('Unlisted'), findsOneWidget);
    });
  });
}
