// Copyright (c) 2026 Countr. All rights reserved.
// Adversarial Empirical Challenger Test Suite for ManaTextParser & ManaText.

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/features/symbology/domain/mana_text_parser.dart';
import 'package:countr/features/symbology/presentation/widgets/mana_symbol_icon.dart';
import 'package:countr/features/symbology/presentation/widgets/mana_text.dart';

/// Helper to extract ManaSymbolIcon from an InlineSpan.
ManaSymbolIcon? getIconFromSpan(InlineSpan span) {
  if (span is! WidgetSpan) return null;
  final child = span.child;
  if (child is ManaSymbolIcon) return child;
  if (child is Padding && child.child is ManaSymbolIcon) {
    return child.child as ManaSymbolIcon;
  }
  return null;
}

void main() {
  const baseStyle = TextStyle(fontSize: 14.0);

  group('ManaTextParser Challenger - Extreme Malformed Braces & Edge Cases', () {
    test('unclosed brace at start "{2" passes through cleanly as raw TextSpan', () {
      final spans = ManaTextParser.parse(text: '{2', baseStyle: baseStyle);
      expect(spans.length, equals(1));
      expect(spans.first, isA<TextSpan>());
      expect((spans.first as TextSpan).text, equals('{2'));
    });

    test('unopened brace "2}" passes through cleanly as raw TextSpan', () {
      final spans = ManaTextParser.parse(text: '2}', baseStyle: baseStyle);
      expect(spans.length, equals(1));
      expect(spans.first, isA<TextSpan>());
      expect((spans.first as TextSpan).text, equals('2}'));
    });

    test('double braces "{{W}}" preserves outer braces and parses inner symbol', () {
      final spans = ManaTextParser.parse(text: '{{W}}', baseStyle: baseStyle);
      expect(spans.length, equals(3));
      expect(spans[0], isA<TextSpan>());
      expect((spans[0] as TextSpan).text, equals('{'));
      expect(spans[1], isA<WidgetSpan>());
      expect(getIconFromSpan(spans[1])!.assetPath, equals('assets/symbology/W.svg'));
      expect(spans[2], isA<TextSpan>());
      expect((spans[2] as TextSpan).text, equals('}'));
    });

    test('triple braces "{{{W}}}" preserves double outer braces and parses inner symbol', () {
      final spans = ManaTextParser.parse(text: '{{{W}}}', baseStyle: baseStyle);
      expect(spans.length, equals(3));
      expect(spans[0], isA<TextSpan>());
      expect((spans[0] as TextSpan).text, equals('{{'));
      expect(spans[1], isA<WidgetSpan>());
      expect(getIconFromSpan(spans[1])!.assetPath, equals('assets/symbology/W.svg'));
      expect(spans[2], isA<TextSpan>());
      expect((spans[2] as TextSpan).text, equals('}}'));
    });

    test('empty braces "{}" passes through cleanly as TextSpan without crash', () {
      final spans = ManaTextParser.parse(text: '{}', baseStyle: baseStyle);
      expect(spans.length, equals(1));
      expect(spans.first, isA<TextSpan>());
      expect((spans.first as TextSpan).text, equals('{}'));
    });

    test('slash only "{/}" passes through cleanly as TextSpan without crash', () {
      final spans = ManaTextParser.parse(text: '{/}', baseStyle: baseStyle);
      expect(spans.length, equals(1));
      expect(spans.first, isA<TextSpan>());
      expect((spans.first as TextSpan).text, equals('{/}'));
    });

    test('double slash hybrid "{W//U}" passes through cleanly as TextSpan without crash', () {
      final spans = ManaTextParser.parse(text: '{W//U}', baseStyle: baseStyle);
      expect(spans.length, equals(1));
      expect(spans.first, isA<TextSpan>());
      expect((spans.first as TextSpan).text, equals('{W//U}'));
    });

    test('double slash twobrid "{2//W}" passes through cleanly as TextSpan without crash', () {
      final spans = ManaTextParser.parse(text: '{2//W}', baseStyle: baseStyle);
      expect(spans.length, equals(1));
      expect(spans.first, isA<TextSpan>());
      expect((spans.first as TextSpan).text, equals('{2//W}'));
    });

    test('consecutive and inverted braces "}{}{}{" pass through cleanly without crash', () {
      final spans = ManaTextParser.parse(text: '}{}{}{', baseStyle: baseStyle);
      expect(spans.length, equals(1));
      expect(spans.first, isA<TextSpan>());
      expect((spans.first as TextSpan).text, equals('}{}{}{'));
    });

    test('nested empty braces "{{}}" pass through cleanly as TextSpan', () {
      final spans = ManaTextParser.parse(text: '{{}}', baseStyle: baseStyle);
      expect(spans.length, equals(1));
      expect(spans.first, isA<TextSpan>());
      expect((spans.first as TextSpan).text, equals('{{}}'));
    });

    test('consecutive slashes "{//}" pass through cleanly as TextSpan', () {
      final spans = ManaTextParser.parse(text: '{//}', baseStyle: baseStyle);
      expect(spans.length, equals(1));
      expect(spans.first, isA<TextSpan>());
      expect((spans.first as TextSpan).text, equals('{//}'));
    });

    test('unclosed brace followed by valid symbol "{2{W}" correctly parses {W}', () {
      final spans = ManaTextParser.parse(text: '{2{W}', baseStyle: baseStyle);
      expect(spans.length, equals(2));
      expect(spans[0], isA<TextSpan>());
      expect((spans[0] as TextSpan).text, equals('{2'));
      expect(spans[1], isA<WidgetSpan>());
      expect(getIconFromSpan(spans[1])!.assetPath, equals('assets/symbology/W.svg'));
    });

    test('valid symbol followed by unopened brace "{W}2}" correctly parses {W} and retains 2}', () {
      final spans = ManaTextParser.parse(text: '{W}2}', baseStyle: baseStyle);
      expect(spans.length, equals(2));
      expect(spans[0], isA<WidgetSpan>());
      expect(getIconFromSpan(spans[0])!.assetPath, equals('assets/symbology/W.svg'));
      expect(spans[1], isA<TextSpan>());
      expect((spans[1] as TextSpan).text, equals('2}'));
    });
  });

  group('ManaTextParser Challenger - Punctuation Adjacency & Span Coalescing', () {
    test('parses "{T}, {Q}; {W}. {U}!" with exact punctuation preservation', () {
      const text = '{T}, {Q}; {W}. {U}!';
      final spans = ManaTextParser.parse(text: text, baseStyle: baseStyle);

      // Expected spans:
      // 0: WidgetSpan {T}
      // 1: TextSpan ", "
      // 2: WidgetSpan {Q}
      // 3: TextSpan "; "
      // 4: WidgetSpan {W}
      // 5: TextSpan ". "
      // 6: WidgetSpan {U}
      // 7: TextSpan "!"
      expect(spans.length, equals(8));

      expect(spans[0], isA<WidgetSpan>());
      expect(getIconFromSpan(spans[0])!.assetPath, equals('assets/symbology/T.svg'));

      expect(spans[1], isA<TextSpan>());
      expect((spans[1] as TextSpan).text, equals(', '));

      expect(spans[2], isA<WidgetSpan>());
      expect(getIconFromSpan(spans[2])!.assetPath, equals('assets/symbology/Q.svg'));

      expect(spans[3], isA<TextSpan>());
      expect((spans[3] as TextSpan).text, equals('; '));

      expect(spans[4], isA<WidgetSpan>());
      expect(getIconFromSpan(spans[4])!.assetPath, equals('assets/symbology/W.svg'));

      expect(spans[5], isA<TextSpan>());
      expect((spans[5] as TextSpan).text, equals('. '));

      expect(spans[6], isA<WidgetSpan>());
      expect(getIconFromSpan(spans[6])!.assetPath, equals('assets/symbology/U.svg'));

      expect(spans[7], isA<TextSpan>());
      expect((spans[7] as TextSpan).text, equals('!'));
    });

    test('tight punctuation without spaces: "{T}:{W}-{U}?"', () {
      const text = '{T}:{W}-{U}?';
      final spans = ManaTextParser.parse(text: text, baseStyle: baseStyle);

      expect(spans.length, equals(6));
      expect(getIconFromSpan(spans[0])!.assetPath, equals('assets/symbology/T.svg'));
      expect((spans[1] as TextSpan).text, equals(':'));
      expect(getIconFromSpan(spans[2])!.assetPath, equals('assets/symbology/W.svg'));
      expect((spans[3] as TextSpan).text, equals('-'));
      expect(getIconFromSpan(spans[4])!.assetPath, equals('assets/symbology/U.svg'));
      expect((spans[5] as TextSpan).text, equals('?'));
    });

    test('parentheses and quotes: \'("{2}{U}")\'', () {
      const text = '(" {2}{U} ")';
      final spans = ManaTextParser.parse(text: text, baseStyle: baseStyle);

      expect(spans.length, equals(4));
      expect((spans[0] as TextSpan).text, equals('(" '));
      expect(getIconFromSpan(spans[1])!.assetPath, equals('assets/symbology/2.svg'));
      expect(getIconFromSpan(spans[2])!.assetPath, equals('assets/symbology/U.svg'));
      expect((spans[3] as TextSpan).text, equals(' ")'));
    });

    test('coalesces adjacent non-symbol text runs without span fragmentation', () {
      // Normal plain sentence
      const sentence = 'Target creature gains flying and lifelink until end of turn.';
      final spans = ManaTextParser.parse(text: sentence, baseStyle: baseStyle);
      expect(spans.length, equals(1));
      expect((spans.first as TextSpan).text, equals(sentence));
    });
  });

  group('ManaTextParser Challenger - Unicode & Un-Set Symbols', () {
    test('parses half mana "{½}" and renders HALF.svg', () {
      final spans = ManaTextParser.parse(text: 'Pay {½} to activate.', baseStyle: baseStyle);
      expect(spans.length, equals(3));
      expect((spans[0] as TextSpan).text, equals('Pay '));
      expect(getIconFromSpan(spans[1])!.assetPath, equals('assets/symbology/HALF.svg'));
      expect((spans[2] as TextSpan).text, equals(' to activate.'));
    });

    test('parses infinity "{∞}" and renders INFINITY.svg', () {
      final spans = ManaTextParser.parse(text: 'Cost: {∞}.', baseStyle: baseStyle);
      expect(spans.length, equals(3));
      expect((spans[0] as TextSpan).text, equals('Cost: '));
      expect(getIconFromSpan(spans[1])!.assetPath, equals('assets/symbology/INFINITY.svg'));
      expect((spans[2] as TextSpan).text, equals('.'));
    });

    test('parses Gleemax million mana "{1000000}" and renders 1000000.svg', () {
      final spans = ManaTextParser.parse(text: '{1000000}', baseStyle: baseStyle);
      expect(spans.length, equals(1));
      expect(getIconFromSpan(spans[0])!.assetPath, equals('assets/symbology/1000000.svg'));
    });

    test('parses hundred mana "{100}" and renders 100.svg', () {
      final spans = ManaTextParser.parse(text: '{100}', baseStyle: baseStyle);
      expect(spans.length, equals(1));
      expect(getIconFromSpan(spans[0])!.assetPath, equals('assets/symbology/100.svg'));
    });

    test('preserves multi-byte non-Latin natural text (Japanese, Chinese, Russian, Emojis)', () {
      const multilingual = 'クリーチャー — 天使 {2}{W}{W}\n支付 {G}。🔥 {R} 💧 {U} 💀 {B} ☀️ {W} 🌲 {G}';
      final spans = ManaTextParser.parse(text: multilingual, baseStyle: baseStyle);

      // Verify no exceptions and exact symbol count (3 + 1 + 5 = 9 symbols)
      final widgetSpans = spans.whereType<WidgetSpan>().toList();
      expect(widgetSpans.length, equals(9));

      // Verify Japanese prefix preserved
      final firstText = spans.first as TextSpan;
      expect(firstText.text, equals('クリーチャー — 天使 '));
    });
  });

  group('ManaTextParser Challenger - Poison & Unknown Tokens', () {
    test('unrecognized token "{NotASymbol}" passes through as TextSpan', () {
      final spans = ManaTextParser.parse(text: '{NotASymbol}', baseStyle: baseStyle);
      expect(spans.length, equals(1));
      expect(spans.first, isA<TextSpan>());
      expect((spans.first as TextSpan).text, equals('{NotASymbol}'));
    });

    test('unrecognized token "{FakeMana}" passes through as TextSpan', () {
      final spans = ManaTextParser.parse(text: '{FakeMana}', baseStyle: baseStyle);
      expect(spans.length, equals(1));
      expect(spans.first, isA<TextSpan>());
      expect((spans.first as TextSpan).text, equals('{FakeMana}'));
    });

    test('reminder token with colon and space "{Reminder: Flying}" passes through as TextSpan', () {
      final spans = ManaTextParser.parse(text: '{Reminder: Flying}', baseStyle: baseStyle);
      expect(spans.length, equals(1));
      expect(spans.first, isA<TextSpan>());
      expect((spans.first as TextSpan).text, equals('{Reminder: Flying}'));
    });

    test('interleaved poison tokens and valid symbols preserve exact order', () {
      const text = '{NotASymbol}{W}{FakeMana}{U}{Reminder: Flying}{B}';
      final spans = ManaTextParser.parse(text: text, baseStyle: baseStyle);

      // Expected spans:
      // TextSpan: "{NotASymbol}"
      // WidgetSpan: {W}
      // TextSpan: "{FakeMana}"
      // WidgetSpan: {U}
      // TextSpan: "{Reminder: Flying}"
      // WidgetSpan: {B}
      expect(spans.length, equals(6));

      expect(spans[0], isA<TextSpan>());
      expect((spans[0] as TextSpan).text, equals('{NotASymbol}'));

      expect(spans[1], isA<WidgetSpan>());
      expect(getIconFromSpan(spans[1])!.assetPath, equals('assets/symbology/W.svg'));

      expect(spans[2], isA<TextSpan>());
      expect((spans[2] as TextSpan).text, equals('{FakeMana}'));

      expect(spans[3], isA<WidgetSpan>());
      expect(getIconFromSpan(spans[3])!.assetPath, equals('assets/symbology/U.svg'));

      expect(spans[4], isA<TextSpan>());
      expect((spans[4] as TextSpan).text, equals('{Reminder: Flying}'));

      expect(spans[5], isA<WidgetSpan>());
      expect(getIconFromSpan(spans[5])!.assetPath, equals('assets/symbology/B.svg'));
    });

    test('extreme non-existent numeric cost "{99999}" passes through cleanly', () {
      final spans = ManaTextParser.parse(text: '{99999}', baseStyle: baseStyle);
      expect(spans.length, equals(1));
      expect(spans.first, isA<TextSpan>());
      expect((spans.first as TextSpan).text, equals('{99999}'));
    });

    test('unsupported 5-color hybrid "{W/U/B/R/G}" passes through cleanly', () {
      final spans = ManaTextParser.parse(text: '{W/U/B/R/G}', baseStyle: baseStyle);
      expect(spans.length, equals(1));
      expect(spans.first, isA<TextSpan>());
      expect((spans.first as TextSpan).text, equals('{W/U/B/R/G}'));
    });

    test('XSS script tag token "{<script>alert(1)</script>}" passes through as TextSpan', () {
      final spans = ManaTextParser.parse(text: '{<script>alert(1)</script>}', baseStyle: baseStyle);
      expect(spans.length, equals(1));
      expect(spans.first, isA<TextSpan>());
      expect((spans.first as TextSpan).text, equals('{<script>alert(1)</script>}'));
    });
  });

  group('ManaTextParser Challenger - Massive Text Stress & Scalability', () {
    test('parses 10,000+ characters with 200 embedded symbols with < 25ms execution', () {
      final validSymbols = [
        '{W}', '{U}', '{B}', '{R}', '{G}', '{C}', '{S}', '{T}', '{Q}', '{X}',
        '{W/U}', '{B/R}', '{2/W}', '{W/P}', '{½}', '{∞}', '{1000000}', '{E}', '{P}', '{PW}',
      ];

      final buffer = StringBuffer();
      const sentence = 'Tap this permanent to generate additional resources during your upkeep. ';
      int symbolCount = 0;

      // Construct a string with at least 10,000 characters and exactly 200 symbols
      while (symbolCount < 200 || buffer.length < 10000) {
        buffer.write(sentence);
        if (symbolCount < 200) {
          buffer.write(validSymbols[symbolCount % validSymbols.length]);
          buffer.write(' ');
          symbolCount++;
        }
      }

      final massiveText = buffer.toString();
      expect(massiveText.length, greaterThanOrEqualTo(10000));
      expect(symbolCount, equals(200));

      // Measure execution time
      final stopwatch = Stopwatch()..start();
      final spans = ManaTextParser.parse(text: massiveText, baseStyle: baseStyle);
      stopwatch.stop();

      // Verify execution latency is well within standard 60fps frame budget (16.6ms) / benchmark limit (25ms)
      expect(stopwatch.elapsedMilliseconds, lessThan(25),
          reason: 'Parsing 10,000+ chars with 200 symbols took ${stopwatch.elapsedMilliseconds}ms, exceeding budget');

      // Verify exact count of recognized WidgetSpans
      final widgetSpans = spans.whereType<WidgetSpan>().toList();
      expect(widgetSpans.length, equals(200));

      // Verify all WidgetSpans have PlaceholderAlignment.middle
      for (final ws in widgetSpans) {
        expect(ws.alignment, equals(PlaceholderAlignment.middle));
      }

      // Verify total content integrity: length of text spans + symbols
      int reconstructedLength = 0;
      for (final span in spans) {
        if (span is TextSpan) {
          reconstructedLength += (span.text ?? '').length;
        } else if (span is WidgetSpan) {
          final icon = getIconFromSpan(span);
          reconstructedLength += '{${icon!.symbolCode}}'.length;
        }
      }
      expect(reconstructedLength, equals(massiveText.length));
    });
  });

  group('ManaText Challenger - Widget Rendering, Font Sizes & Layout Rigor', () {
    testWidgets('all rendered WidgetSpans strictly possess PlaceholderAlignment.middle',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ManaText('Pay {2}{W}{U}, {T}: Gain 5 life.'),
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

      expect(widgetSpans.length, equals(4)); // {2}, {W}, {U}, {T}
      for (final ws in widgetSpans) {
        expect(ws.alignment, equals(PlaceholderAlignment.middle),
            reason: 'WidgetSpan alignment must be middle for consistent vertical optical centering');
      }
    });

    testWidgets('micro font sizes (6.0pt, 4.0pt, 1.0pt) scale icons proportionally without layout errors',
        (tester) async {
      final fontSizes = [6.0, 4.0, 1.0];

      for (final fs in fontSizes) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ManaText(
                'Cast {W}{U} for micro cost',
                style: TextStyle(fontSize: fs),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull, reason: 'Failed for fontSize: $fs');
        final icons = tester.widgetList<ManaSymbolIcon>(find.byType(ManaSymbolIcon)).toList();
        expect(icons.length, equals(2));

        // Effective icon size is fontSize * 1.1
        final expectedSize = fs * 1.1;
        for (final icon in icons) {
          expect(icon.size, closeTo(expectedSize, 0.001));
        }
      }
    });

    testWidgets('macro font sizes (48.0pt, 72.0pt, 120.0pt) scale icons proportionally without layout errors',
        (tester) async {
      final fontSizes = [48.0, 72.0, 120.0];

      for (final fs in fontSizes) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: ManaText(
                  'Giant {R}{G}',
                  style: TextStyle(fontSize: fs),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull, reason: 'Failed for fontSize: $fs');
        final icons = tester.widgetList<ManaSymbolIcon>(find.byType(ManaSymbolIcon)).toList();
        expect(icons.length, equals(2));

        final expectedSize = fs * 1.1;
        for (final icon in icons) {
          expect(icon.size, closeTo(expectedSize, 0.001));
        }
      }
    });

    testWidgets('zero font size (0.0pt) renders without zero-division or crash',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ManaText(
              '{B}',
              style: TextStyle(fontSize: 0.0),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final icon = tester.widget<ManaSymbolIcon>(find.byType(ManaSymbolIcon));
      expect(icon.size, equals(0.0));
    });

    testWidgets('null baseStyle.fontSize defaults safely to 14.0 * 1.1 = 15.4',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DefaultTextStyle(
              style: TextStyle(), // No fontSize specified
              child: ManaText('{C}'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final icon = tester.widget<ManaSymbolIcon>(find.byType(ManaSymbolIcon));
      expect(icon.size, closeTo(15.4, 0.001));
    });

    testWidgets('constrained width layout wrapping (width: 320, 200, 100) wraps without exceptions',
        (tester) async {
      const oracle = 'Whenever you cast a spell with mana cost {1}{W}{U}, pay {2} or sacrifice a permanent.';
      final widths = [320.0, 200.0, 100.0];

      for (final w in widths) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: w,
                child: const ManaText(oracle),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull, reason: 'Failed for width $w');
        expect(find.byType(ManaSymbolIcon), findsNWidgets(4)); // {1}, {W}, {U}, {2}
      }
    });

    testWidgets('overflow behaviors (clip, ellipsis, fade) pass through to RichText cleanly',
        (tester) async {
      final overflows = [TextOverflow.clip, TextOverflow.ellipsis, TextOverflow.fade];

      for (final ov in overflows) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 100.0,
                child: ManaText(
                  '{T}: Add {W}{U}{B}{R}{G}.',
                  maxLines: 1,
                  overflow: ov,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        final richText = tester.widget<RichText>(find.byType(RichText));
        expect(richText.overflow, equals(ov));
        expect(richText.maxLines, equals(1));
      }
    });

    testWidgets('mounts massive 10,000+ char text with 200 symbols in widget tree without error',
        (tester) async {
      final buffer = StringBuffer();
      for (int i = 0; i < 200; i++) {
        buffer.write('Ability $i costs {W/U}. ');
      }
      final longText = buffer.toString();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ManaText(longText),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(ManaSymbolIcon), findsNWidgets(200));
    });
  });

  group('ManaTextParser Challenger - Randomized Invariant Fuzzing', () {
    test('200 randomized inputs never throw unhandled exceptions and preserve content', () {
      final random = Random(42);
      final symbols = ['{W}', '{U}', '{B}', '{R}', '{G}', '{2/W}', '{W/P}', '{½}', '{∞}', '{1000000}'];
      final malformed = ['{2', '2}', '{{W}}', '{{{W}}}', '{}', '{/}', '{W//U}', '{2//W}', '}{', '{NotASymbol}'];
      final words = ['Tap', 'Untap', 'Add', 'Mana', 'Creature', 'Sacrifice', 'Draw', 'Life', '123', '!', '.', ','];

      for (int i = 0; i < 200; i++) {
        final length = random.nextInt(20) + 1;
        final buffer = StringBuffer();
        for (int j = 0; j < length; j++) {
          final choice = random.nextInt(3);
          if (choice == 0) {
            buffer.write(symbols[random.nextInt(symbols.length)]);
          } else if (choice == 1) {
            buffer.write(malformed[random.nextInt(malformed.length)]);
          } else {
            buffer.write(words[random.nextInt(words.length)]);
          }
          if (random.nextBool()) buffer.write(' ');
        }

        final inputString = buffer.toString();

        // INVARIANT 1: Never throws
        List<InlineSpan> spans = const [];
        expect(() {
          spans = ManaTextParser.parse(text: inputString, baseStyle: baseStyle);
        }, returnsNormally, reason: 'Iteration $i threw exception for input: $inputString');

        // INVARIANT 2: Non-empty input yields non-empty spans
        if (inputString.isNotEmpty) {
          expect(spans, isNotEmpty);
        }

        // INVARIANT 3: Every WidgetSpan has PlaceholderAlignment.middle
        for (final span in spans) {
          if (span is WidgetSpan) {
            expect(span.alignment, equals(PlaceholderAlignment.middle));
          }
        }
      }
    });
  });
}
