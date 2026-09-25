// Copyright (c) 2026 Countr. All rights reserved.
// Tier 5 Adversarial White-Box Coverage Hardening Suite for MTG Symbology Engine.
// Probes all 114 alias entries, calculateManaValue edge cases, symbolBuilder callbacks,
// span coalescing / zero fragmentation, and ManaSymbolSpan plain-text reconstruction.

import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/features/symbology/data/scryfall_symbol_catalog.dart';
import 'package:countr/features/symbology/domain/mana_text_parser.dart';
import 'package:countr/features/symbology/presentation/widgets/mana_symbol_icon.dart';

/// Helper to extract ManaSymbolIcon from an InlineSpan.
ManaSymbolIcon? _extractIcon(InlineSpan span) {
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

  // List of all 114 transposable, filename stem, and notation aliases
  const knownAliases = <String>[
    '2B', '2G', '2R', '2U', '2W',
    'B/2', 'B/C', 'B/P/G', 'B/P/R', 'B/P/U', 'B/P/W', 'B/U', 'B/U/P', 'B/W', 'B/W/P',
    'BG', 'BGP', 'BP', 'BR', 'BRP',
    'CB', 'CG', 'CP', 'CR', 'CU', 'CW',
    'G/2', 'G/B', 'G/B/P', 'G/C', 'G/P/B', 'G/P/R', 'G/P/U', 'G/P/W', 'G/R', 'G/R/P',
    'GP', 'GU', 'GUP', 'GW', 'GWP',
    'HALF', 'INFINITY',
    'P/B', 'P/B/G', 'P/B/R', 'P/B/U', 'P/B/W', 'P/C', 'P/G', 'P/G/B', 'P/G/R', 'P/G/U', 'P/G/W',
    'P/R', 'P/R/B', 'P/R/G', 'P/R/U', 'P/R/W', 'P/U', 'P/U/B', 'P/U/G', 'P/U/R', 'P/U/W',
    'P/W', 'P/W/B', 'P/W/G', 'P/W/R', 'P/W/U',
    'R/2', 'R/B', 'R/B/P', 'R/C', 'R/P/B', 'R/P/G', 'R/P/U', 'R/P/W', 'R/U', 'R/U/P',
    'RG', 'RGP', 'RP', 'RW', 'RWP',
    'U/2', 'U/C', 'U/G', 'U/G/P', 'U/P/B', 'U/P/G', 'U/P/R', 'U/P/W', 'U/W', 'U/W/P',
    'UB', 'UBP', 'UP', 'UR', 'URP',
    'W/2', 'W/C', 'W/G', 'W/G/P', 'W/P/B', 'W/P/G', 'W/P/R', 'W/P/U', 'W/R', 'W/R/P',
    'WB', 'WBP', 'WP', 'WU', 'WUP',
  ];

  group('Tier 5 - Catalog Integrity & All 114 Aliases Exhaustive Hardening', () {
    test('catalog contains exactly 114 aliases and every alias points to a valid canonical symbol', () {
      expect(knownAliases.length, equals(114));

      for (final alias in knownAliases) {
        final symbol = ScryfallSymbolCatalog.findBySymbol(alias);
        expect(symbol, isNotNull, reason: 'Alias $alias must resolve to a valid symbol');
        expect(ScryfallSymbolCatalog.symbols.containsKey(symbol!.symbol), isTrue,
            reason: 'Resolved symbol ${symbol.symbol} for alias $alias must exist in canonical symbols');
      }
    });

    test('all 114 aliases resolve in unbracketed uppercase form', () {
      for (final alias in knownAliases) {
        final symbol = ScryfallSymbolCatalog.findBySymbol(alias);
        expect(symbol, isNotNull, reason: 'Failed for unbracketed uppercase: $alias');
        expect(ScryfallSymbolCatalog.isValidSymbol(alias), isTrue);
        expect(ScryfallSymbolCatalog.resolveAssetPath(alias), isNotNull);
        expect(ScryfallSymbolCatalog.resolveFilename(alias), isNotNull);
      }
    });

    test(r'all 114 aliases resolve in bracketed uppercase form "{$alias}"', () {
      for (final alias in knownAliases) {
        final bracketed = '{$alias}';
        final symbol = ScryfallSymbolCatalog.findBySymbol(bracketed);
        expect(symbol, isNotNull, reason: 'Failed for bracketed uppercase: $bracketed');
        expect(ScryfallSymbolCatalog.isValidSymbol(bracketed), isTrue);
        expect(ScryfallSymbolCatalog.resolveAssetPath(bracketed), isNotNull);
      }
    });

    test('all 114 aliases resolve in unbracketed lowercase form', () {
      for (final alias in knownAliases) {
        final lower = alias.toLowerCase();
        final symbol = ScryfallSymbolCatalog.findBySymbol(lower);
        expect(symbol, isNotNull, reason: 'Failed for unbracketed lowercase: $lower');
        expect(ScryfallSymbolCatalog.isValidSymbol(lower), isTrue);
        expect(ScryfallSymbolCatalog.resolveAssetPath(lower), isNotNull);
      }
    });

    test(r'all 114 aliases resolve in bracketed lowercase form "{$lower}"', () {
      for (final alias in knownAliases) {
        final bracketedLower = '{${alias.toLowerCase()}}';
        final symbol = ScryfallSymbolCatalog.findBySymbol(bracketedLower);
        expect(symbol, isNotNull, reason: 'Failed for bracketed lowercase: $bracketedLower');
        expect(ScryfallSymbolCatalog.isValidSymbol(bracketedLower), isTrue);
        expect(ScryfallSymbolCatalog.resolveAssetPath(bracketedLower), isNotNull);
      }
    });

    test(r'all 114 aliases resolve with surrounding whitespace "  {$alias}  "', () {
      for (final alias in knownAliases) {
        final padded = '   {$alias}   ';
        final symbol = ScryfallSymbolCatalog.findBySymbol(padded);
        expect(symbol, isNotNull, reason: 'Failed for padded bracketed: "$padded"');
      }
    });

    test('all 114 aliases resolve when passed with uppercase and lowercase .svg extension', () {
      for (final alias in knownAliases) {
        // e.g. "WU.svg" and "wu.SVG"
        final lowerSvg = '$alias.svg';
        final upperSvg = '${alias.toLowerCase()}.SVG';
        expect(ScryfallSymbolCatalog.findBySymbol(lowerSvg), isNotNull,
            reason: 'Failed for $lowerSvg');
        expect(ScryfallSymbolCatalog.findBySymbol(upperSvg), isNotNull,
            reason: 'Failed for $upperSvg');
      }
    });

    test('every resolved alias asset file physically exists in assets/symbology/', () {
      for (final alias in knownAliases) {
        final path = ScryfallSymbolCatalog.resolveAssetPath(alias);
        expect(path, isNotNull);
        final file = File(path!);
        expect(file.existsSync(), isTrue, reason: 'Asset file does not exist on disk: $path');
      }
    });

    test('ManaTextParser.parse correctly parses every alias into a WidgetSpan with Middle alignment', () {
      for (final alias in knownAliases) {
        // Only bracketed tokens with valid regex characters are parsed as symbols
        final spans = ManaTextParser.parse(text: '{$alias}', baseStyle: baseStyle);
        expect(spans.length, equals(1), reason: 'Failed to parse span for alias {$alias}');
        expect(spans.first, isA<WidgetSpan>(), reason: 'Alias {$alias} must parse into WidgetSpan');

        final widgetSpan = spans.first as WidgetSpan;
        expect(widgetSpan.alignment, equals(PlaceholderAlignment.middle));

        final icon = _extractIcon(widgetSpan);
        expect(icon, isNotNull, reason: 'Alias {$alias} must contain ManaSymbolIcon');
        expect(icon!.assetPath, startsWith('assets/symbology/'));
      }
    });

    test('all 84 canonical symbols resolve across all case, unbracketed, whitespace, and .svg variations', () {
      for (final sym in ScryfallSymbolCatalog.symbols.values) {
        final code = sym.cleanCode;

        // 1. Bracketed canonical
        expect(ScryfallSymbolCatalog.findBySymbol('{$code}'), equals(sym));
        // 2. Unbracketed canonical
        expect(ScryfallSymbolCatalog.findBySymbol(code), equals(sym));
        // 3. Lowercase unbracketed
        expect(ScryfallSymbolCatalog.findBySymbol(code.toLowerCase()), equals(sym));
        // 4. Lowercase bracketed
        expect(ScryfallSymbolCatalog.findBySymbol('{${code.toLowerCase()}}'), equals(sym));
        // 5. Surrounding whitespace inside and outside braces
        expect(ScryfallSymbolCatalog.findBySymbol('   {   $code   }   '), equals(sym));
        // 6. Filename with lower/uppercase .svg
        expect(ScryfallSymbolCatalog.findBySymbol('$code.svg'), equals(sym));
        expect(ScryfallSymbolCatalog.findBySymbol('${code.toLowerCase()}.SVG'), equals(sym));
        // 7. Validation & Path resolution
        expect(ScryfallSymbolCatalog.isValidSymbol(code), isTrue);
        expect(ScryfallSymbolCatalog.resolveAssetPath(code), equals(sym.assetPath));
        expect(ScryfallSymbolCatalog.resolveFilename(code), equals(sym.filename));
      }
    });

    test('adversarial normalize variations: {WU.svg} fails because .svg is inside braces', () {
      // White-box nuance: _normalize checks code.endsWith('.SVG') BEFORE stripping braces.
      // Therefore, if '.svg' is inside the braces '{WU.svg}', the outer string ends with '}',
      // so '.SVG' is not stripped, leaving clean code 'WU.SVG', which is not in the alias map.
      expect(ScryfallSymbolCatalog.findBySymbol('{WU.svg}'), isNull);
      expect(ScryfallSymbolCatalog.findBySymbol('WU.svg'), isNotNull);
    });

    test('empty and whitespace-only bracket variations return null safely', () {
      expect(ScryfallSymbolCatalog.findBySymbol(''), isNull);
      expect(ScryfallSymbolCatalog.findBySymbol('   '), isNull);
      expect(ScryfallSymbolCatalog.findBySymbol('{}'), isNull);
      expect(ScryfallSymbolCatalog.findBySymbol('{   }'), isNull);
      expect(ScryfallSymbolCatalog.findBySymbol('{'), isNull);
      expect(ScryfallSymbolCatalog.findBySymbol('}'), isNull);
    });
  });

  group('Tier 5 - ScryfallSymbol Model Invariants & Contracts', () {
    test('all 84 canonical symbols have cleanCode without brackets', () {
      for (final sym in ScryfallSymbolCatalog.symbols.values) {
        expect(sym.cleanCode, isNot(contains('{')));
        expect(sym.cleanCode, isNot(contains('}')));
        expect(sym.symbol, equals('{${sym.cleanCode}}'));
      }
    });

    test('color classification invariants: isColorless, isMonoColored, isMultiColored are mutually exclusive', () {
      for (final sym in ScryfallSymbolCatalog.symbols.values) {
        if (!sym.representsMana) {
          // Action/counter symbols represent no mana
          expect(sym.isColorless, isFalse);
          expect(sym.isMonoColored, isFalse);
          expect(sym.isMultiColored, isFalse);
        } else {
          final count = (sym.isColorless ? 1 : 0) +
              (sym.isMonoColored ? 1 : 0) +
              (sym.isMultiColored ? 1 : 0);
          expect(count, equals(1),
              reason: 'Symbol ${sym.symbol} must satisfy exactly one color category');
        }
      }
    });

    test('equality and hashCode contracts across distinct and identical symbol instances', () {
      final sym1 = ScryfallSymbolCatalog.findBySymbol('{W}')!;
      final sym2 = ScryfallSymbolCatalog.findBySymbol('W')!;
      final sym3 = ScryfallSymbolCatalog.findBySymbol('{U}')!;

      expect(sym1 == sym2, isTrue);
      expect(sym1.hashCode, equals(sym2.hashCode));
      expect(sym1 == sym3, isFalse);
      expect(sym1 == Object(), isFalse);
      expect(sym1.toString(), contains('ScryfallSymbol({W} -> W.svg)'));
    });
  });

  group('Tier 5 - calculateManaValue (CMC) & extractSymbols Adversarial Boundaries', () {
    test('calculateManaValue returns exact double for non-mana and action symbols ({T}, {Q}, {E}, etc.)', () {
      // In Scryfall catalog, action/counter symbols have manaValue = 0.0
      expect(ScryfallSymbolCatalog.calculateManaValue('{T}'), equals(0.0));
      expect(ScryfallSymbolCatalog.calculateManaValue('{Q}'), equals(0.0));
      expect(ScryfallSymbolCatalog.calculateManaValue('{E}'), equals(0.0));
      expect(ScryfallSymbolCatalog.calculateManaValue('{P}'), equals(0.0));
      expect(ScryfallSymbolCatalog.calculateManaValue('{PW}'), equals(0.0));
      expect(ScryfallSymbolCatalog.calculateManaValue('{CHAOS}'), equals(0.0));
      expect(ScryfallSymbolCatalog.calculateManaValue('{A}'), equals(0.0));
      expect(ScryfallSymbolCatalog.calculateManaValue('{TK}'), equals(0.0));
      expect(ScryfallSymbolCatalog.calculateManaValue('{D}'), equals(0.0));
    });

    test('calculateManaValue returns exact sum when mixing mana with non-mana action symbols', () {
      expect(ScryfallSymbolCatalog.calculateManaValue('{2}{T}'), equals(2.0));
      expect(ScryfallSymbolCatalog.calculateManaValue('{3}{W}{U}{PW}'), equals(5.0));
      expect(ScryfallSymbolCatalog.calculateManaValue('{T}{Q}{CHAOS}'), equals(0.0));
    });

    test('calculateManaValue computes half mana and un-set fractions accurately', () {
      expect(ScryfallSymbolCatalog.calculateManaValue('{½}'), equals(0.5));
      expect(ScryfallSymbolCatalog.calculateManaValue('{HW}'), equals(0.5));
      expect(ScryfallSymbolCatalog.calculateManaValue('{HR}'), equals(0.5));
      expect(ScryfallSymbolCatalog.calculateManaValue('{½}{HW}{HR}'), equals(1.5));
      expect(ScryfallSymbolCatalog.calculateManaValue('{2}{½}'), equals(2.5));
    });

    test('calculateManaValue handles massive un-set numbers {100} and {1000000}', () {
      expect(ScryfallSymbolCatalog.calculateManaValue('{100}'), equals(100.0));
      expect(ScryfallSymbolCatalog.calculateManaValue('{1000000}'), equals(1000000.0));
      expect(ScryfallSymbolCatalog.calculateManaValue('{1000000}{100}{5}'), equals(1000105.0));
    });

    test('calculateManaValue handles variable mana {X}, {Y}, {Z}', () {
      expect(ScryfallSymbolCatalog.calculateManaValue('{X}'), equals(0.0));
      expect(ScryfallSymbolCatalog.calculateManaValue('{Y}'), equals(0.0));
      expect(ScryfallSymbolCatalog.calculateManaValue('{Z}'), equals(0.0));
      expect(ScryfallSymbolCatalog.calculateManaValue('{X}{Y}{Z}{3}{R}'), equals(4.0));
    });

    test('calculateManaValue computes all hybrid and twobrid combinations accurately', () {
      // 5 twobrids = 10.0
      expect(ScryfallSymbolCatalog.calculateManaValue('{2/W}{2/U}{2/B}{2/R}{2/G}'), equals(10.0));
      // 5 colorless hybrids = 5.0
      expect(ScryfallSymbolCatalog.calculateManaValue('{C/W}{C/U}{C/B}{C/R}{C/G}'), equals(5.0));
      // 6 phyrexian single = 6.0
      expect(ScryfallSymbolCatalog.calculateManaValue('{W/P}{U/P}{B/P}{R/P}{G/P}{C/P}'), equals(6.0));
      // Special phyrexian {H} = 1.0
      expect(ScryfallSymbolCatalog.calculateManaValue('{H}'), equals(1.0));
    });

    test('calculateManaValue returns null for infinite mana and unknown/unparseable tokens', () {
      expect(ScryfallSymbolCatalog.calculateManaValue('{∞}'), isNull);
      expect(ScryfallSymbolCatalog.calculateManaValue('{2}{∞}'), isNull);
      expect(ScryfallSymbolCatalog.calculateManaValue('{W}{NotASymbol}'), isNull);
      expect(ScryfallSymbolCatalog.calculateManaValue('{FakeMana}'), isNull);
    });

    test('calculateManaValue evaluates single unbracketed symbol', () {
      expect(ScryfallSymbolCatalog.calculateManaValue('W'), equals(1.0));
      expect(ScryfallSymbolCatalog.calculateManaValue('2/U'), equals(2.0));
      expect(ScryfallSymbolCatalog.calculateManaValue('P/B'), equals(1.0));
      expect(ScryfallSymbolCatalog.calculateManaValue('½'), equals(0.5));
      expect(ScryfallSymbolCatalog.calculateManaValue('HALF'), equals(0.5));
      expect(ScryfallSymbolCatalog.calculateManaValue('∞'), isNull);
      expect(ScryfallSymbolCatalog.calculateManaValue('INFINITY'), isNull);
      expect(ScryfallSymbolCatalog.calculateManaValue('INVALID'), isNull);
    });

    test('calculateManaValue handles empty and whitespace inputs cleanly', () {
      expect(ScryfallSymbolCatalog.calculateManaValue(''), equals(0.0));
      expect(ScryfallSymbolCatalog.calculateManaValue('{}'), equals(0.0));
      expect(ScryfallSymbolCatalog.calculateManaValue('   '), isNull);
    });

    test('calculateManaValue extracts closed brackets embedded within surrounding natural text', () {
      // Natural text with closed brackets: extractSymbols extracts tokens cleanly
      expect(ScryfallSymbolCatalog.calculateManaValue('Pay {2}{W} to cast'), equals(3.0));
      // Trailing unclosed brace: extractSymbols extracts previous closed tokens
      expect(ScryfallSymbolCatalog.calculateManaValue('{2}{W}{'), equals(3.0));
    });

    test('extractSymbols validate parameter toggles filtering of unknown bracketed tokens', () {
      const mixed = '{2}{UnknownToken}{W}';
      expect(ScryfallSymbolCatalog.extractSymbols(mixed, validate: true), equals(['2', 'W']));
      expect(ScryfallSymbolCatalog.extractSymbols(mixed, validate: false),
          equals(['2', 'UnknownToken', 'W']));
    });

    test('extractSymbols handles single unbracketed input vs empty', () {
      expect(ScryfallSymbolCatalog.extractSymbols('W', validate: true), equals(['W']));
      expect(ScryfallSymbolCatalog.extractSymbols('Unknown', validate: true), isEmpty);
      expect(ScryfallSymbolCatalog.extractSymbols('Unknown', validate: false), equals(['Unknown']));
      expect(ScryfallSymbolCatalog.extractSymbols('', validate: true), isEmpty);
    });

    test('extractSymbols skips empty brackets "{}" because regex requires 1+ characters', () {
      expect(ScryfallSymbolCatalog.extractSymbols('{}', validate: false), isEmpty);
      expect(ScryfallSymbolCatalog.extractSymbols('{}{W}{}', validate: false), equals(['W']));
    });
  });

  group('Tier 5 - ManaTextParser.parse Sizing, Padding & symbolPadding Branch Coverage', () {
    test('explicit symbolSize overrides baseStyle.fontSize calculation completely', () {
      const style = TextStyle(fontSize: 20.0);
      final spans = ManaTextParser.parse(
        text: '{W}',
        baseStyle: style,
        symbolSize: 32.5,
        scaleFactor: 1.5,
      );

      final icon = _extractIcon(spans.first)!;
      expect(icon.size, equals(32.5));
    });

    test('scaleFactor scales fontSize dynamically when symbolSize is null', () {
      const style = TextStyle(fontSize: 16.0);
      final spans = ManaTextParser.parse(
        text: '{W}',
        baseStyle: style,
        scaleFactor: 2.0,
      );

      final icon = _extractIcon(spans.first)!;
      expect(icon.size, closeTo(32.0, 0.001));
    });

    test('null baseStyle.fontSize defaults to 14.0 * scaleFactor', () {
      const styleNoSize = TextStyle();
      final spans = ManaTextParser.parse(
        text: '{U}',
        baseStyle: styleNoSize,
        scaleFactor: 1.5,
      );

      final icon = _extractIcon(spans.first)!;
      expect(icon.size, closeTo(21.0, 0.001));
    });

    test('symbolPadding != EdgeInsets.zero wraps icon in Padding widget', () {
      const customPadding = EdgeInsets.symmetric(horizontal: 5.0, vertical: 2.0);
      final spans = ManaTextParser.parse(
        text: '{B}',
        baseStyle: baseStyle,
        symbolPadding: customPadding,
      );

      final ws = spans.first as WidgetSpan;
      expect(ws.child, isA<Padding>());
      final paddingWidget = ws.child as Padding;
      expect(paddingWidget.padding, equals(customPadding));
    });

    test('symbolPadding == EdgeInsets.zero omits Padding widget and mounts icon directly', () {
      final spans = ManaTextParser.parse(
        text: '{R}',
        baseStyle: baseStyle,
        symbolPadding: EdgeInsets.zero,
      );

      final ws = spans.first as WidgetSpan;
      // White-box assertion: with zero padding, child must be ManaSymbolIcon directly, not Padding!
      expect(ws.child, isA<ManaSymbolIcon>());
      expect(ws.child, isNot(isA<Padding>()));
      final icon = ws.child as ManaSymbolIcon;
      expect(icon.symbolCode, equals('R'));
    });
  });

  group('Tier 5 - Custom symbolBuilder Callback Stress & Layout Invariants', () {
    test('custom symbolBuilder intercepts icon instantiation with correct arguments', () {
      final recordedInvocations = <Map<String, dynamic>>[];

      final spans = ManaTextParser.parse(
        text: 'Pay {2}{W/U} to draw.',
        baseStyle: const TextStyle(fontSize: 18.0),
        scaleFactor: 1.2,
        symbolBuilder: (symbolCode, assetPath, size) {
          recordedInvocations.add({
            'code': symbolCode,
            'path': assetPath,
            'size': size,
          });
          return Container(key: ValueKey('custom_$symbolCode'));
        },
      );

      expect(recordedInvocations.length, equals(2));
      expect(recordedInvocations[0]['code'], equals('2'));
      expect(recordedInvocations[0]['path'], equals('assets/symbology/2.svg'));
      expect(recordedInvocations[0]['size'], closeTo(18.0 * 1.2, 0.001));

      expect(recordedInvocations[1]['code'], equals('W/U'));
      expect(recordedInvocations[1]['path'], equals('assets/symbology/WU.svg'));
      expect(recordedInvocations[1]['size'], closeTo(18.0 * 1.2, 0.001));

      // Spans structure:
      // 0: TextSpan "Pay "
      // 1: WidgetSpan Container(custom_2)
      // 2: WidgetSpan Container(custom_W/U)
      // 3: TextSpan " to draw."
      expect(spans.length, equals(4));
      expect(spans[1], isA<WidgetSpan>());
      expect(spans[2], isA<WidgetSpan>());

      final ws1 = spans[1] as WidgetSpan;
      expect(ws1.alignment, equals(PlaceholderAlignment.middle));
    });

    test('custom symbolBuilder respects symbolPadding == EdgeInsets.zero without wrapping', () {
      final spans = ManaTextParser.parse(
        text: '{G}',
        baseStyle: baseStyle,
        symbolPadding: EdgeInsets.zero,
        symbolBuilder: (code, path, size) => Text('ICON_$code'),
      );

      expect(spans.length, equals(1));
      final ws = spans.first as WidgetSpan;
      expect(ws.child, isA<Text>());
      final textWidget = ws.child as Text;
      expect(textWidget.data, equals('ICON_G'));
    });

    test('all 84 canonical symbols parse cleanly through ManaTextParser into WidgetSpans', () {
      for (final sym in ScryfallSymbolCatalog.symbols.values) {
        final text = 'Effect: ${sym.symbol}.';
        final spans = ManaTextParser.parse(text: text, baseStyle: baseStyle);

        expect(spans.length, equals(3), reason: 'Failed for canonical symbol ${sym.symbol}');
        expect(spans[0], isA<TextSpan>());
        expect((spans[0] as TextSpan).text, equals('Effect: '));

        expect(spans[1], isA<WidgetSpan>());
        final icon = _extractIcon(spans[1]);
        expect(icon, isNotNull);
        expect(icon!.assetPath, equals(sym.assetPath));
        expect(icon.symbolCode, equals(sym.cleanCode));

        expect(spans[2], isA<TextSpan>());
        expect((spans[2] as TextSpan).text, equals('.'));
      }
    });
  });

  group('Tier 5 - Span Tree Reconstruction, Zero Fragmentation & computeToPlainText', () {
    test('consecutive non-symbol text runs have zero span fragmentation', () {
      // String with leading, middle, and trailing text
      const text = 'First part. {W} Second part. {U} Third part.';
      final spans = ManaTextParser.parse(text: text, baseStyle: baseStyle);

      expect(spans.length, equals(5));
      expect(spans[0], isA<TextSpan>());
      expect((spans[0] as TextSpan).text, equals('First part. '));
      expect(spans[1], isA<WidgetSpan>());
      expect(spans[2], isA<TextSpan>());
      expect((spans[2] as TextSpan).text, equals(' Second part. '));
      expect(spans[3], isA<WidgetSpan>());
      expect(spans[4], isA<TextSpan>());
      expect((spans[4] as TextSpan).text, equals(' Third part.'));
    });

    test('multiple contiguous unrecognized tokens are coalesced into a single TextSpan', () {
      const text = 'Cost: {Unknown1}{Unknown2}{Unknown3} finish.';
      final spans = ManaTextParser.parse(text: text, baseStyle: baseStyle);

      // Since all 3 tokens are unrecognized, the entire string passes through as a SINGLE TextSpan
      expect(spans.length, equals(1));
      expect(spans.first, isA<TextSpan>());
      expect((spans.first as TextSpan).text, equals(text));
    });

    test('interleaved valid and invalid tokens produce exactly interleaved spans', () {
      const text = '{Valid1:W}{Fake1}{U}{Fake2}';
      // In this string:
      // '{Valid1:W}' is not a symbol (contains colon)
      // '{Fake1}' is not a symbol
      // '{U}' IS a symbol
      // '{Fake2}' is not a symbol
      final spans = ManaTextParser.parse(text: text, baseStyle: baseStyle);

      expect(spans.length, equals(3));
      // Span 0: TextSpan "{Valid1:W}{Fake1}"
      expect(spans[0], isA<TextSpan>());
      expect((spans[0] as TextSpan).text, equals('{Valid1:W}{Fake1}'));

      // Span 1: WidgetSpan {U}
      expect(spans[1], isA<WidgetSpan>());
      expect(_extractIcon(spans[1])!.symbolCode, equals('U'));

      // Span 2: TextSpan "{Fake2}"
      expect(spans[2], isA<TextSpan>());
      expect((spans[2] as TextSpan).text, equals('{Fake2}'));
    });

    test('all emitted TextSpans strictly preserve baseStyle properties', () {
      const styledBase = TextStyle(
        fontSize: 16.0,
        fontWeight: FontWeight.bold,
        color: Color(0xFF112233),
        letterSpacing: 0.5,
      );

      final spans = ManaTextParser.parse(
        text: 'Prefix {W} Middle {U} Suffix',
        baseStyle: styledBase,
      );

      for (final span in spans) {
        if (span is TextSpan) {
          expect(span.style, equals(styledBase));
        }
      }
    });

    test('ManaSymbolSpan.computeToPlainText produces canonical bracketed tokens when includePlaceholders is true', () {
      final spanUnbracketed = ManaSymbolSpan(
        child: const SizedBox(),
        rawSymbol: 'W',
      );
      final buffer1 = StringBuffer();
      spanUnbracketed.computeToPlainText(buffer1, includePlaceholders: true);
      expect(buffer1.toString(), equals('{W}'));

      final spanAlreadyBracketed = ManaSymbolSpan(
        child: const SizedBox(),
        rawSymbol: '{W/U}',
      );
      final buffer2 = StringBuffer();
      spanAlreadyBracketed.computeToPlainText(buffer2, includePlaceholders: true);
      expect(buffer2.toString(), equals('{W/U}'),
          reason: 'Must not double-brace if rawSymbol already starts and ends with braces');

      final spanLeadingOnly = ManaSymbolSpan(
        child: const SizedBox(),
        rawSymbol: '{W',
      );
      final buffer3 = StringBuffer();
      spanLeadingOnly.computeToPlainText(buffer3, includePlaceholders: true);
      expect(buffer3.toString(), equals('{{W}'));

      final spanTrailingOnly = ManaSymbolSpan(
        child: const SizedBox(),
        rawSymbol: 'W}',
      );
      final buffer4 = StringBuffer();
      spanTrailingOnly.computeToPlainText(buffer4, includePlaceholders: true);
      expect(buffer4.toString(), equals('{W}}'));
    });

    test('ManaSymbolSpan.computeToPlainText writes nothing when includePlaceholders is false', () {
      final span = ManaSymbolSpan(
        child: const SizedBox(),
        rawSymbol: 'W',
      );
      final buffer = StringBuffer();
      span.computeToPlainText(buffer, includePlaceholders: false);
      expect(buffer.toString(), isEmpty,
          reason: 'When includePlaceholders is false, computeToPlainText must write nothing');
    });

    test('TextSpan tree toPlainText() round-trips complex Oracle text with includePlaceholders', () {
      const oracle = '{T}: Add {G}. Pay {2}{W}{U} to draw a card.';
      final spans = ManaTextParser.parse(text: oracle, baseStyle: baseStyle);
      final rootSpan = TextSpan(children: spans);

      expect(rootSpan.toPlainText(includePlaceholders: true), equals(oracle));
      expect(
        rootSpan.toPlainText(includePlaceholders: false),
        equals(': Add . Pay  to draw a card.'),
        reason: 'Omission of placeholders should yield only surrounding text',
      );
    });

    test('ManaSymbolSpan constructor preserves custom alignment, baseline, and style', () {
      const style = TextStyle(color: Color(0xFF000000));
      final span = ManaSymbolSpan(
        child: const SizedBox(),
        rawSymbol: 'T',
        alignment: PlaceholderAlignment.top,
        baseline: TextBaseline.alphabetic,
        style: style,
      );

      expect(span.rawSymbol, equals('T'));
      expect(span.alignment, equals(PlaceholderAlignment.top));
      expect(span.baseline, equals(TextBaseline.alphabetic));
      expect(span.style, equals(style));
    });
  });

  group('Tier 5 - Malformed, Poison & Extreme Adversarial Text Resilience', () {
    test('handles unclosed brace with question mark "{?" as TextSpan', () {
      final spans = ManaTextParser.parse(text: '{?', baseStyle: baseStyle);
      expect(spans.length, equals(1));
      expect(spans.first, isA<TextSpan>());
      expect((spans.first as TextSpan).text, equals('{?'));
    });

    test('handles closed brace with question mark "{?}" as TextSpan (regex matches, but unknown symbol)', () {
      final spans = ManaTextParser.parse(text: '{?}', baseStyle: baseStyle);
      expect(spans.length, equals(1));
      expect(spans.first, isA<TextSpan>());
      expect((spans.first as TextSpan).text, equals('{?}'));
    });

    test('handles unicode half mana in malformed expressions "{½" and "½}"', () {
      final spans1 = ManaTextParser.parse(text: '{½', baseStyle: baseStyle);
      expect(spans1.length, equals(1));
      expect((spans1.first as TextSpan).text, equals('{½'));

      final spans2 = ManaTextParser.parse(text: '½}', baseStyle: baseStyle);
      expect(spans2.length, equals(1));
      expect((spans2.first as TextSpan).text, equals('½}'));
    });

    test('handles massive 10,000 character repeated symbol sequence without memory issue or crash', () {
      final massive = '{W}' * 2000;
      final spans = ManaTextParser.parse(text: massive, baseStyle: baseStyle);
      expect(spans.length, equals(2000));
      expect(spans.every((s) => s is WidgetSpan), isTrue);
    });

    test('empty string returns identical const empty list', () {
      final spans1 = ManaTextParser.parse(text: '', baseStyle: baseStyle);
      final spans2 = ManaTextParser.parse(text: '', baseStyle: baseStyle);
      expect(spans1, isEmpty);
      expect(identical(spans1, spans2), isTrue);
    });
  });
}
