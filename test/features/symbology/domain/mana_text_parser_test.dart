// Copyright (c) 2026 Countr. All rights reserved.
// Comprehensive unit test suite for ManaTextParser domain engine.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/features/symbology/domain/mana_text_parser.dart';
import 'package:countr/features/symbology/presentation/widgets/mana_symbol_icon.dart';

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

  group('ManaTextParser - Single Mana Symbols', () {
    test('parses all traditional colored mana symbols into WidgetSpans', () {
      final colors = ['W', 'U', 'B', 'R', 'G'];
      for (final c in colors) {
        final spans = ManaTextParser.parse(
          text: '{$c}',
          baseStyle: baseStyle,
        );

        expect(spans.length, equals(1), reason: 'Failed for {$c}');
        expect(spans.first, isA<WidgetSpan>());

        final widgetSpan = spans.first as WidgetSpan;
        expect(widgetSpan.alignment, equals(PlaceholderAlignment.middle));

        final icon = getIconFromSpan(widgetSpan);
        expect(icon, isNotNull);
        expect(icon!.assetPath, equals('assets/symbology/$c.svg'));
        expect(icon.size, closeTo(14.0 * 1.1, 0.001));
      }
    });

    test('parses colorless {C} and snow {S} mana symbols', () {
      for (final sym in ['C', 'S']) {
        final spans = ManaTextParser.parse(text: '{$sym}', baseStyle: baseStyle);
        expect(spans.length, equals(1));
        final icon = getIconFromSpan(spans.first);
        expect(icon, isNotNull);
        expect(icon!.assetPath, equals('assets/symbology/$sym.svg'));
      }
    });

    test('parses generic numeric mana symbols {0} through {20}', () {
      for (int i = 0; i <= 20; i++) {
        final spans = ManaTextParser.parse(text: '{$i}', baseStyle: baseStyle);
        expect(spans.length, equals(1), reason: 'Failed for {$i}');
        final icon = getIconFromSpan(spans.first);
        expect(icon, isNotNull);
        expect(icon!.assetPath, equals('assets/symbology/$i.svg'));
      }
    });

    test('parses generic variable symbols {X}, {Y}, {Z}', () {
      for (final v in ['X', 'Y', 'Z']) {
        final spans = ManaTextParser.parse(text: '{$v}', baseStyle: baseStyle);
        expect(spans.length, equals(1));
        final icon = getIconFromSpan(spans.first);
        expect(icon, isNotNull);
        expect(icon!.assetPath, equals('assets/symbology/$v.svg'));
      }
    });
  });

  group('ManaTextParser - Contiguous Mana Costs', () {
    test('parses contiguous costs without intervening TextSpans', () {
      final spans = ManaTextParser.parse(
        text: '{2}{U}{B}',
        baseStyle: baseStyle,
      );

      expect(spans.length, equals(3));
      expect(spans.every((s) => s is WidgetSpan), isTrue);

      final icon0 = getIconFromSpan(spans[0])!;
      final icon1 = getIconFromSpan(spans[1])!;
      final icon2 = getIconFromSpan(spans[2])!;

      expect(icon0.assetPath, equals('assets/symbology/2.svg'));
      expect(icon1.assetPath, equals('assets/symbology/U.svg'));
      expect(icon2.assetPath, equals('assets/symbology/B.svg'));
    });

    test('parses 3-color contiguous cost {1}{G}{W}', () {
      final spans = ManaTextParser.parse(
        text: '{1}{G}{W}',
        baseStyle: baseStyle,
      );

      expect(spans.length, equals(3));
      expect(getIconFromSpan(spans[0])!.assetPath, equals('assets/symbology/1.svg'));
      expect(getIconFromSpan(spans[1])!.assetPath, equals('assets/symbology/G.svg'));
      expect(getIconFromSpan(spans[2])!.assetPath, equals('assets/symbology/W.svg'));
    });

    test('parses 6-symbol massive contiguous cost {4}{W}{U}{B}{R}{G}', () {
      final spans = ManaTextParser.parse(
        text: '{4}{W}{U}{B}{R}{G}',
        baseStyle: baseStyle,
      );

      expect(spans.length, equals(6));
      final expectedAssets = [
        'assets/symbology/4.svg',
        'assets/symbology/W.svg',
        'assets/symbology/U.svg',
        'assets/symbology/B.svg',
        'assets/symbology/R.svg',
        'assets/symbology/G.svg',
      ];
      for (int i = 0; i < 6; i++) {
        expect(getIconFromSpan(spans[i])!.assetPath, equals(expectedAssets[i]));
      }
    });
  });

  group('ManaTextParser - Hybrid, Twobrid & Phyrexian Symbols', () {
    test('parses two-color guild hybrids and their reversed transpositions', () {
      final pairs = [
        ['{W/U}', '{U/W}', 'assets/symbology/WU.svg'],
        ['{B/R}', '{R/B}', 'assets/symbology/BR.svg'],
        ['{G/W}', '{W/G}', 'assets/symbology/GW.svg'],
      ];

      for (final pair in pairs) {
        final spansCanonical = ManaTextParser.parse(text: pair[0], baseStyle: baseStyle);
        final spansReversed = ManaTextParser.parse(text: pair[1], baseStyle: baseStyle);

        expect(getIconFromSpan(spansCanonical.first)!.assetPath, equals(pair[2]));
        expect(getIconFromSpan(spansReversed.first)!.assetPath, equals(pair[2]));
      }
    });

    test('parses monocolored twobrids {2/W} and reversed {W/2}', () {
      final canonical = ManaTextParser.parse(text: '{2/W}', baseStyle: baseStyle);
      final reversed = ManaTextParser.parse(text: '{W/2}', baseStyle: baseStyle);

      expect(getIconFromSpan(canonical.first)!.assetPath, equals('assets/symbology/2W.svg'));
      expect(getIconFromSpan(reversed.first)!.assetPath, equals('assets/symbology/2W.svg'));
    });

    test('parses Phyrexian mana and transposed {P/B} alias', () {
      final canonical = ManaTextParser.parse(text: '{W/P}', baseStyle: baseStyle);
      final transposed = ManaTextParser.parse(text: '{P/B}', baseStyle: baseStyle);

      expect(getIconFromSpan(canonical.first)!.assetPath, equals('assets/symbology/WP.svg'));
      expect(getIconFromSpan(transposed.first)!.assetPath, equals('assets/symbology/BP.svg'));
    });

    test('parses 3-component hybrid Phyrexian {G/U/P} and permutations', () {
      final spans1 = ManaTextParser.parse(text: '{G/U/P}', baseStyle: baseStyle);
      final spans2 = ManaTextParser.parse(text: '{U/G/P}', baseStyle: baseStyle);
      final spans3 = ManaTextParser.parse(text: '{P/U/G}', baseStyle: baseStyle);

      expect(getIconFromSpan(spans1.first)!.assetPath, equals('assets/symbology/GUP.svg'));
      expect(getIconFromSpan(spans2.first)!.assetPath, equals('assets/symbology/GUP.svg'));
      expect(getIconFromSpan(spans3.first)!.assetPath, equals('assets/symbology/GUP.svg'));
    });
  });

  group('ManaTextParser - Action, Mechanics & Game Counter Symbols', () {
    test('parses tap {T} and untap {Q} symbols', () {
      final t = ManaTextParser.parse(text: '{T}', baseStyle: baseStyle);
      final q = ManaTextParser.parse(text: '{Q}', baseStyle: baseStyle);

      expect(getIconFromSpan(t.first)!.assetPath, equals('assets/symbology/T.svg'));
      expect(getIconFromSpan(q.first)!.assetPath, equals('assets/symbology/Q.svg'));
    });

    test('parses energy {E}, pawprint {P}, planeswalker {PW}, chaos {CHAOS}', () {
      final mechanics = {
        '{E}': 'assets/symbology/E.svg',
        '{P}': 'assets/symbology/P.svg',
        '{PW}': 'assets/symbology/PW.svg',
        '{CHAOS}': 'assets/symbology/CHAOS.svg',
        '{TK}': 'assets/symbology/TK.svg',
        '{A}': 'assets/symbology/A.svg',
      };

      mechanics.forEach((code, expectedAsset) {
        final spans = ManaTextParser.parse(text: code, baseStyle: baseStyle);
        expect(getIconFromSpan(spans.first)!.assetPath, equals(expectedAsset),
            reason: 'Failed for $code');
      });
    });
  });

  group('ManaTextParser - Un-Set & Special Unicode Symbols', () {
    test('parses half mana {½}', () {
      final spans = ManaTextParser.parse(text: '{½}', baseStyle: baseStyle);
      expect(getIconFromSpan(spans.first)!.assetPath, equals('assets/symbology/HALF.svg'));
    });

    test('parses infinite generic mana {∞}', () {
      final spans = ManaTextParser.parse(text: '{∞}', baseStyle: baseStyle);
      expect(getIconFromSpan(spans.first)!.assetPath, equals('assets/symbology/INFINITY.svg'));
    });

    test('parses Gleemax million mana {1000000} and {100}', () {
      final spansMillion = ManaTextParser.parse(text: '{1000000}', baseStyle: baseStyle);
      final spansHundred = ManaTextParser.parse(text: '{100}', baseStyle: baseStyle);

      expect(getIconFromSpan(spansMillion.first)!.assetPath, equals('assets/symbology/1000000.svg'));
      expect(getIconFromSpan(spansHundred.first)!.assetPath, equals('assets/symbology/100.svg'));
    });
  });

  group('ManaTextParser - Malformed Brackets & Fallback Behavior', () {
    test('unclosed opening bracket at start "{2 and tap" returns raw TextSpan without crash', () {
      final spans = ManaTextParser.parse(text: '{2 and tap', baseStyle: baseStyle);
      expect(spans.length, equals(1));
      expect(spans.first, isA<TextSpan>());
      expect((spans.first as TextSpan).text, equals('{2 and tap'));
    });

    test('unclosed opening bracket at end "Costs {W" returns raw TextSpan without crash', () {
      final spans = ManaTextParser.parse(text: 'Costs {W', baseStyle: baseStyle);
      expect(spans.length, equals(1));
      expect(spans.first, isA<TextSpan>());
      expect((spans.first as TextSpan).text, equals('Costs {W'));
    });

    test('unrecognized bracketed text "{NotASymbol}" returns raw TextSpan without crash', () {
      final spans = ManaTextParser.parse(text: '{NotASymbol}', baseStyle: baseStyle);
      expect(spans.length, equals(1));
      expect(spans.first, isA<TextSpan>());
      expect((spans.first as TextSpan).text, equals('{NotASymbol}'));
    });

    test('empty braces "{}" returns raw TextSpan without crash', () {
      final spans = ManaTextParser.parse(text: '{}', baseStyle: baseStyle);
      expect(spans.length, equals(1));
      expect(spans.first, isA<TextSpan>());
      expect((spans.first as TextSpan).text, equals('{}'));
    });

    test('nested braces "{{W}}" cleanly extracts inner symbol and keeps outer braces', () {
      final spans = ManaTextParser.parse(text: '{{W}}', baseStyle: baseStyle);
      expect(spans.length, equals(3));
      expect(spans[0], isA<TextSpan>());
      expect((spans[0] as TextSpan).text, equals('{'));
      expect(spans[1], isA<WidgetSpan>());
      expect(getIconFromSpan(spans[1])!.assetPath, equals('assets/symbology/W.svg'));
      expect(spans[2], isA<TextSpan>());
      expect((spans[2] as TextSpan).text, equals('}'));
    });

    test('empty string returns empty spans list', () {
      final spans = ManaTextParser.parse(text: '', baseStyle: baseStyle);
      expect(spans, isEmpty);
    });

    test('pure whitespace returns single TextSpan', () {
      final spans = ManaTextParser.parse(text: '   ', baseStyle: baseStyle);
      expect(spans.length, equals(1));
      expect(spans.first, isA<TextSpan>());
      expect((spans.first as TextSpan).text, equals('   '));
    });
  });

  group('ManaTextParser - Mixed Natural Oracle Rules Text', () {
    test('parses "{T}: Add {G}." into 4 sequential spans', () {
      final spans = ManaTextParser.parse(text: '{T}: Add {G}.', baseStyle: baseStyle);

      expect(spans.length, equals(4));
      expect(spans[0], isA<WidgetSpan>());
      expect(getIconFromSpan(spans[0])!.assetPath, equals('assets/symbology/T.svg'));

      expect(spans[1], isA<TextSpan>());
      expect((spans[1] as TextSpan).text, equals(': Add '));

      expect(spans[2], isA<WidgetSpan>());
      expect(getIconFromSpan(spans[2])!.assetPath, equals('assets/symbology/G.svg'));

      expect(spans[3], isA<TextSpan>());
      expect((spans[3] as TextSpan).text, equals('.'));
    });

    test('parses "When this enters, pay {1}{W}{U}."', () {
      final spans = ManaTextParser.parse(
        text: 'When this enters, pay {1}{W}{U}.',
        baseStyle: baseStyle,
      );

      expect(spans.length, equals(5));
      expect((spans[0] as TextSpan).text, equals('When this enters, pay '));
      expect(getIconFromSpan(spans[1])!.assetPath, equals('assets/symbology/1.svg'));
      expect(getIconFromSpan(spans[2])!.assetPath, equals('assets/symbology/W.svg'));
      expect(getIconFromSpan(spans[3])!.assetPath, equals('assets/symbology/U.svg'));
      expect((spans[4] as TextSpan).text, equals('.'));
    });

    test('parses multi-line text with newlines without dropping breaks', () {
      const oracle = 'Vigilance\n{T}: Add {C}.';
      final spans = ManaTextParser.parse(text: oracle, baseStyle: baseStyle);

      expect(spans.length, equals(5));
      expect((spans[0] as TextSpan).text, equals('Vigilance\n'));
      expect(getIconFromSpan(spans[1])!.assetPath, equals('assets/symbology/T.svg'));
      expect((spans[2] as TextSpan).text, equals(': Add '));
      expect(getIconFromSpan(spans[3])!.assetPath, equals('assets/symbology/C.svg'));
      expect((spans[4] as TextSpan).text, equals('.'));
    });

    test('pure rules text without brackets returns 1 TextSpan', () {
      const oracle = 'Flying, first strike, lifelink, haste';
      final spans = ManaTextParser.parse(text: oracle, baseStyle: baseStyle);

      expect(spans.length, equals(1));
      expect(spans.first, isA<TextSpan>());
      expect((spans.first as TextSpan).text, equals(oracle));
    });
  });

  group('ManaTextParser - Font Sizing, Scaling & Padding Controls', () {
    test('dynamically computes effective size based on fontSize * scaleFactor', () {
      const style10 = TextStyle(fontSize: 10.0);
      final spans10 = ManaTextParser.parse(text: '{W}', baseStyle: style10, scaleFactor: 1.1);
      expect(getIconFromSpan(spans10.first)!.size, closeTo(11.0, 0.001));

      const style20 = TextStyle(fontSize: 20.0);
      final spans20 = ManaTextParser.parse(text: '{W}', baseStyle: style20, scaleFactor: 1.1);
      expect(getIconFromSpan(spans20.first)!.size, closeTo(22.0, 0.001));
    });

    test('explicit symbolSize overrides scaleFactor calculation', () {
      const style14 = TextStyle(fontSize: 14.0);
      final spans = ManaTextParser.parse(
        text: '{W}',
        baseStyle: style14,
        symbolSize: 18.0,
      );
      expect(getIconFromSpan(spans.first)!.size, equals(18.0));
    });

    test('null baseStyle.fontSize falls back safely to 14.0 default', () {
      const styleNoSize = TextStyle();
      final spans = ManaTextParser.parse(text: '{W}', baseStyle: styleNoSize);
      expect(getIconFromSpan(spans.first)!.size, closeTo(14.0 * 1.1, 0.001));
    });

    test('applies custom symbolPadding to the WidgetSpan child Padding', () {
      const customPadding = EdgeInsets.symmetric(horizontal: 4.0, vertical: 1.0);
      final spans = ManaTextParser.parse(
        text: '{W}',
        baseStyle: baseStyle,
        symbolPadding: customPadding,
      );

      final widgetSpan = spans.first as WidgetSpan;
      expect(widgetSpan.child, isA<Padding>());
      final paddingWidget = widgetSpan.child as Padding;
      expect(paddingWidget.padding, equals(customPadding));
    });

    test('ManaSymbolSpan preserves canonical bracketed tokens in computeToPlainText / toPlainText', () {
      final spans = ManaTextParser.parse(
        text: '{T}: Add {G}. Pay {2}{W}{U} to draw.',
        baseStyle: baseStyle,
      );

      final rootSpan = TextSpan(children: spans);
      expect(
        rootSpan.toPlainText(),
        equals('{T}: Add {G}. Pay {2}{W}{U} to draw.'),
        reason: 'computeToPlainText must emit canonical bracketed tokens for test finder compatibility',
      );
    });
  });
}
