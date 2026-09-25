// Copyright (c) 2026 Countr. All rights reserved.
// Widget test suite for ManaText component.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/features/symbology/presentation/widgets/mana_symbol_icon.dart';
import 'package:countr/features/symbology/presentation/widgets/mana_text.dart';

void main() {
  group('ManaText - Widget Tree Mounting & Rendering', () {
    testWidgets('renders mixed Oracle text with inline ManaSymbolIcons inside MaterialApp',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ManaText('{T}: Add {G}.'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ManaText), findsOneWidget);
      expect(find.byType(RichText), findsOneWidget);
      expect(find.byType(ManaSymbolIcon), findsNWidgets(2));
    });

    testWidgets('renders pure text without symbols without creating ManaSymbolIcons',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ManaText('Destroy target creature with power 4 or greater.'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ManaText), findsOneWidget);
      expect(find.byType(ManaSymbolIcon), findsNothing);
    });
  });

  group('ManaText - Span Structure & PlaceholderAlignment.middle', () {
    testWidgets('all rendered WidgetSpans have PlaceholderAlignment.middle',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ManaText('Pay {2}{U}, {T}: Draw two cards.'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final richTextWidget = tester.widget<RichText>(find.byType(RichText));
      final rootSpan = richTextWidget.text as TextSpan;
      final effectiveSpan = (rootSpan.children != null &&
              rootSpan.children!.length == 1 &&
              rootSpan.children!.first is TextSpan)
          ? rootSpan.children!.first as TextSpan
          : rootSpan;

      final widgetSpans = effectiveSpan.children!.whereType<WidgetSpan>().toList();
      expect(widgetSpans.length, equals(3)); // {2}, {U}, {T}

      for (final span in widgetSpans) {
        expect(span.alignment, equals(PlaceholderAlignment.middle),
            reason: 'WidgetSpan alignment must be middle for vertical cap-height alignment');
      }
    });
  });

  group('ManaText - Font Sizing & Typography Inheritance', () {
    testWidgets('inherits fontSize from ambient DefaultTextStyle', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DefaultTextStyle(
              style: TextStyle(fontSize: 20.0),
              child: ManaText('{W}'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final icon = tester.widget<ManaSymbolIcon>(find.byType(ManaSymbolIcon));
      // 20.0 * 1.1 = 22.0
      expect(icon.size, closeTo(22.0, 0.001));
    });

    testWidgets('explicit style overrides DefaultTextStyle fontSize and scales icons',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ManaText(
              '{B}',
              style: TextStyle(fontSize: 30.0),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final icon = tester.widget<ManaSymbolIcon>(find.byType(ManaSymbolIcon));
      // 30.0 * 1.1 = 33.0
      expect(icon.size, closeTo(33.0, 0.001));
    });

    testWidgets('explicit symbolSize overrides font scale factor', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ManaText(
              '{R}',
              style: TextStyle(fontSize: 24.0),
              symbolSize: 16.0,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final icon = tester.widget<ManaSymbolIcon>(find.byType(ManaSymbolIcon));
      expect(icon.size, equals(16.0));
    });

    testWidgets('custom symbolScale is applied to font size', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ManaText(
              '{G}',
              style: TextStyle(fontSize: 10.0),
              symbolScale: 1.5,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final icon = tester.widget<ManaSymbolIcon>(find.byType(ManaSymbolIcon));
      // 10.0 * 1.5 = 15.0
      expect(icon.size, closeTo(15.0, 0.001));
    });
  });

  group('ManaText - Text Property Delegation', () {
    testWidgets('delegates textAlign, maxLines, and overflow to RichText', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ManaText(
              '{T}: Add one mana of any color.',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final richText = tester.widget<RichText>(find.byType(RichText));
      expect(richText.textAlign, equals(TextAlign.center));
      expect(richText.maxLines, equals(2));
      expect(richText.overflow, equals(TextOverflow.ellipsis));
    });
  });

  group('ManaText - Real-World Card Scenarios', () {
    testWidgets('Scenario 1: Black Lotus ability "{T}, Sacrifice: Add three mana..."',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ManaText('{T}, Sacrifice Black Lotus: Add three mana of any one color.'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ManaSymbolIcon), findsOneWidget);
      final icon = tester.widget<ManaSymbolIcon>(find.byType(ManaSymbolIcon));
      expect(icon.assetPath, equals('assets/symbology/T.svg'));
    });

    testWidgets('Scenario 2: Teferi planeswalker lines with multi-line loyalty abilities',
        (tester) async {
      const teferiRules =
          '+1: Draw a card. At the beginning of the next end step, untap up to two lands.\n'
          '-3: Put target nonland permanent into its owner\'s library third from the top.\n'
          '-8: You get an emblem with "Whenever you draw a card, exile target permanent."';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ManaText(teferiRules),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(RichText), findsOneWidget);
    });

    testWidgets('Scenario 3: Tamiyo, Compleated Sage hybrid Phyrexian cost in rules',
        (tester) async {
      const tamiyoRules = '+1: Tap up to one target artifact or creature. Pay {G/U/P}.';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ManaText(tamiyoRules),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ManaSymbolIcon), findsOneWidget);
      final icon = tester.widget<ManaSymbolIcon>(find.byType(ManaSymbolIcon));
      expect(icon.assetPath, equals('assets/symbology/GUP.svg'));
    });
  });

  group('ManaText - Fallback & Fault Tolerance', () {
    testWidgets('handles empty string without throwing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ManaText(''),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(ManaSymbolIcon), findsNothing);
    });

    testWidgets('handles malformed brackets and unknown tokens gracefully in UI',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ManaText('Pay {2 and tap {NotASymbol} to activate.'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(ManaSymbolIcon), findsNothing);
    });
  });
}
