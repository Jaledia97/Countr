// Copyright (c) 2026 Countr. All rights reserved.
// Adversarial empirical stress tests for ScryfallSymbolCatalog and Asset Bundle loading.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/features/symbology/data/scryfall_symbol_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Empirical Stress: Asset Bundle Packaging & rootBundle Loading', () {
    testWidgets('rootBundle loads explicit assets W.svg, WU.svg, HALF.svg without error',
        (tester) async {
      final wSvg = await rootBundle.loadString('assets/symbology/W.svg', cache: false);
      expect(wSvg, isNotEmpty);
      expect(wSvg, contains('<svg'));
      expect(wSvg, contains('</svg>'));

      final wuSvg = await rootBundle.loadString('assets/symbology/WU.svg', cache: false);
      expect(wuSvg, isNotEmpty);
      expect(wuSvg, contains('<svg'));
      expect(wuSvg, contains('</svg>'));

      final halfSvg = await rootBundle.loadString('assets/symbology/HALF.svg', cache: false);
      expect(halfSvg, isNotEmpty);
      expect(halfSvg, contains('<svg'));
      expect(halfSvg, contains('</svg>'));
    });

    testWidgets('rootBundle successfully loads every single canonical symbol asset (84/84)',
        (tester) async {
      await tester.runAsync(() async {
        int loadedCount = 0;
        for (final symbol in ScryfallSymbolCatalog.symbols.values) {
          final content = await rootBundle.loadString(symbol.assetPath, cache: false);
          expect(content, isNotEmpty);
          expect(content, contains('<svg'));
          expect(content, contains('</svg>'));
          loadedCount++;
        }
        expect(loadedCount, equals(84));
      });
    });

    testWidgets('rootBundle throws FlutterError when attempting to load nonexistent asset',
        (tester) async {
      expect(
        () async => await rootBundle.loadString('assets/symbology/NONEXISTENT_ASSET.svg'),
        throwsA(isA<FlutterError>()),
      );
    });

    testWidgets('SvgPicture.asset successfully renders bundled symbology assets in widget tree',
        (tester) async {
      final testAssets = [
        'assets/symbology/W.svg',
        'assets/symbology/WU.svg',
        'assets/symbology/HALF.svg',
        'assets/symbology/INFINITY.svg',
        'assets/symbology/1000000.svg',
        'assets/symbology/BGP.svg',
        'assets/symbology/2W.svg',
        'assets/symbology/T.svg',
      ];

      for (final assetPath in testAssets) {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: SvgPicture.asset(
              assetPath,
              width: 24,
              height: 24,
            ),
          ),
        );
        expect(tester.takeException(), isNull,
            reason: 'SvgPicture failed to render $assetPath');
      }
    });
  });

  group('Empirical Stress: ScryfallSymbolCatalog Extreme Inputs', () {
    test('Extreme input 1: {1000000} (Un-set massive mana)', () {
      const input = '{1000000}';
      expect(ScryfallSymbolCatalog.extractSymbols(input), equals(['1000000']));
      expect(ScryfallSymbolCatalog.calculateManaValue(input), equals(1000000.0));
      expect(ScryfallSymbolCatalog.resolveAssetPath(input),
          equals('assets/symbology/1000000.svg'));
      expect(ScryfallSymbolCatalog.resolveFilename(input), equals('1000000.svg'));

      final symbol = ScryfallSymbolCatalog.findBySymbol(input);
      expect(symbol, isNotNull);
      expect(symbol!.isFunny, isTrue);
      expect(symbol.manaValue, equals(1000000.0));
    });

    test('Extreme input 2: {∞} (Infinite generic mana)', () {
      const input = '{∞}';
      expect(ScryfallSymbolCatalog.extractSymbols(input), equals(['∞']));
      // In Scryfall specifications, infinite mana has manaValue null
      expect(ScryfallSymbolCatalog.calculateManaValue(input), isNull);
      expect(ScryfallSymbolCatalog.resolveAssetPath(input),
          equals('assets/symbology/INFINITY.svg'));
      expect(ScryfallSymbolCatalog.resolveFilename(input), equals('INFINITY.svg'));

      final symbol = ScryfallSymbolCatalog.findBySymbol(input);
      expect(symbol, isNotNull);
      expect(symbol!.manaValue, isNull);
      expect(symbol.isFunny, isTrue);
    });

    test('Extreme input 3: {½} (Little Girl half mana)', () {
      const input = '{½}';
      expect(ScryfallSymbolCatalog.extractSymbols(input), equals(['½']));
      expect(ScryfallSymbolCatalog.calculateManaValue(input), equals(0.5));
      expect(ScryfallSymbolCatalog.resolveAssetPath(input),
          equals('assets/symbology/HALF.svg'));
      expect(ScryfallSymbolCatalog.resolveFilename(input), equals('HALF.svg'));

      final symbol = ScryfallSymbolCatalog.findBySymbol(input);
      expect(symbol, isNotNull);
      expect(symbol!.manaValue, equals(0.5));
      expect(symbol.isFunny, isTrue);
    });

    test('Extreme input 4: {15} (Emrakul, the Aeons Torn high cost)', () {
      const input = '{15}';
      expect(ScryfallSymbolCatalog.extractSymbols(input), equals(['15']));
      expect(ScryfallSymbolCatalog.calculateManaValue(input), equals(15.0));
      expect(ScryfallSymbolCatalog.resolveAssetPath(input),
          equals('assets/symbology/15.svg'));
      expect(ScryfallSymbolCatalog.resolveFilename(input), equals('15.svg'));

      final symbol = ScryfallSymbolCatalog.findBySymbol(input);
      expect(symbol, isNotNull);
      expect(symbol!.manaValue, equals(15.0));
      expect(symbol.isFunny, isFalse);
    });

    test('Extreme input 5: Contiguous {2/W}{W/U}{B/G/P}{T}', () {
      const input = '{2/W}{W/U}{B/G/P}{T}';
      expect(ScryfallSymbolCatalog.extractSymbols(input),
          equals(['2/W', 'W/U', 'B/G/P', 'T']));
      // 2.0 ({2/W}) + 1.0 ({W/U}) + 1.0 ({B/G/P}) + 0.0 ({T}) = 4.0
      expect(ScryfallSymbolCatalog.calculateManaValue(input), equals(4.0));

      expect(ScryfallSymbolCatalog.resolveAssetPath('2/W'),
          equals('assets/symbology/2W.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('W/U'),
          equals('assets/symbology/WU.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('B/G/P'),
          equals('assets/symbology/BGP.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('T'),
          equals('assets/symbology/T.svg'));
    });

    test('Extreme input 6: {invalid}', () {
      const input = '{invalid}';
      expect(ScryfallSymbolCatalog.extractSymbols(input, validate: true), isEmpty);
      expect(ScryfallSymbolCatalog.extractSymbols(input, validate: false),
          equals(['invalid']));
      expect(ScryfallSymbolCatalog.calculateManaValue(input), isNull);
      expect(ScryfallSymbolCatalog.resolveAssetPath(input), isNull);
      expect(ScryfallSymbolCatalog.resolveFilename(input), isNull);
      expect(ScryfallSymbolCatalog.findBySymbol(input), isNull);
    });

    test('Combined extreme inputs: massive mana calculation', () {
      const input = '{1000000}{100}{15}{½}{2/W}{W/U}{B/G/P}{T}';
      // 1000000 + 100 + 15 + 0.5 + 2.0 + 1.0 + 1.0 + 0.0 = 1000119.5
      expect(ScryfallSymbolCatalog.calculateManaValue(input), equals(1000119.5));
      expect(ScryfallSymbolCatalog.extractSymbols(input).length, equals(8));
    });

    test('Combined extreme inputs: infinity poisons total CMC to null', () {
      const input = '{1000000}{∞}{W}';
      expect(ScryfallSymbolCatalog.calculateManaValue(input), isNull);
      expect(ScryfallSymbolCatalog.extractSymbols(input),
          equals(['1000000', '∞', 'W']));
    });

    test('Combined extreme inputs: invalid token poisons total CMC to null', () {
      const input = '{2}{U}{invalid}{B}';
      expect(ScryfallSymbolCatalog.calculateManaValue(input), isNull);
      expect(ScryfallSymbolCatalog.extractSymbols(input, validate: true),
          equals(['2', 'U', 'B']));
      expect(ScryfallSymbolCatalog.extractSymbols(input, validate: false),
          equals(['2', 'U', 'invalid', 'B']));
    });
  });

  group('Empirical Stress: Boundary & Adversarial Parsing Cases', () {
    test('Empty string returns 0.0 CMC and empty symbol list', () {
      expect(ScryfallSymbolCatalog.calculateManaValue(''), equals(0.0));
      expect(ScryfallSymbolCatalog.extractSymbols(''), isEmpty);
      expect(ScryfallSymbolCatalog.findBySymbol(''), isNull);
    });

    test('Whitespace-only strings behave predictably', () {
      expect(ScryfallSymbolCatalog.findBySymbol('   '), isNull);
      expect(ScryfallSymbolCatalog.isValidSymbol('   '), isFalse);
      expect(ScryfallSymbolCatalog.extractSymbols('   ', validate: true), isEmpty);
    });

    test('Empty braces {} do not match valid symbols', () {
      expect(ScryfallSymbolCatalog.extractSymbols('{}', validate: true), isEmpty);
      expect(ScryfallSymbolCatalog.findBySymbol('{}'), isNull);
    });

    test('Unclosed and malformed braces pass through safely', () {
      expect(ScryfallSymbolCatalog.extractSymbols('{2/W', validate: true), isEmpty);
      expect(ScryfallSymbolCatalog.extractSymbols('W}', validate: true), isEmpty);
      expect(ScryfallSymbolCatalog.extractSymbols('{W}{', validate: true), equals(['W']));
      expect(ScryfallSymbolCatalog.extractSymbols('}{W}{', validate: true), equals(['W']));
    });

    test('Numeric boundary inputs outside standard catalog return null', () {
      // 0 to 20, 100, 1000000 are valid
      expect(ScryfallSymbolCatalog.isValidSymbol('{0}'), isTrue);
      expect(ScryfallSymbolCatalog.isValidSymbol('{20}'), isTrue);
      expect(ScryfallSymbolCatalog.isValidSymbol('{100}'), isTrue);
      expect(ScryfallSymbolCatalog.isValidSymbol('{1000000}'), isTrue);

      // Numbers outside standard catalog
      expect(ScryfallSymbolCatalog.isValidSymbol('{21}'), isFalse);
      expect(ScryfallSymbolCatalog.isValidSymbol('{99}'), isFalse);
      expect(ScryfallSymbolCatalog.isValidSymbol('{-1}'), isFalse);
      expect(ScryfallSymbolCatalog.isValidSymbol('{1000001}'), isFalse);
      expect(ScryfallSymbolCatalog.calculateManaValue('{21}'), isNull);
    });

    test('All 10 two-color hybrid transpositions resolve symmetrically', () {
      final pairs = [
        ['W/U', 'U/W', 'WU.svg'],
        ['W/B', 'B/W', 'WB.svg'],
        ['B/R', 'R/B', 'BR.svg'],
        ['B/G', 'G/B', 'BG.svg'],
        ['U/B', 'B/U', 'UB.svg'],
        ['U/R', 'R/U', 'UR.svg'],
        ['R/G', 'G/R', 'RG.svg'],
        ['R/W', 'W/R', 'RW.svg'],
        ['G/W', 'W/G', 'GW.svg'],
        ['G/U', 'U/G', 'GU.svg'],
      ];

      for (final pair in pairs) {
        final canonical = pair[0];
        final reversed = pair[1];
        final expectedSvg = pair[2];

        expect(ScryfallSymbolCatalog.resolveFilename(canonical), equals(expectedSvg));
        expect(ScryfallSymbolCatalog.resolveFilename(reversed), equals(expectedSvg));
        expect(ScryfallSymbolCatalog.calculateManaValue('{$canonical}'), equals(1.0));
        expect(ScryfallSymbolCatalog.calculateManaValue('{$reversed}'), equals(1.0));
      }
    });

    test('All 5 twobrid transpositions resolve symmetrically', () {
      final twobrids = [
        ['2/W', 'W/2', '2W.svg'],
        ['2/U', 'U/2', '2U.svg'],
        ['2/B', 'B/2', '2B.svg'],
        ['2/R', 'R/2', '2R.svg'],
        ['2/G', 'G/2', '2G.svg'],
      ];

      for (final item in twobrids) {
        expect(ScryfallSymbolCatalog.resolveFilename(item[0]), equals(item[2]));
        expect(ScryfallSymbolCatalog.resolveFilename(item[1]), equals(item[2]));
        expect(ScryfallSymbolCatalog.calculateManaValue('{${item[0]}}'), equals(2.0));
        expect(ScryfallSymbolCatalog.calculateManaValue('{${item[1]}}'), equals(2.0));
      }
    });

    test('All 5 colorless hybrid transpositions resolve symmetrically', () {
      final colorlessHybrids = [
        ['C/W', 'W/C', 'CW.svg'],
        ['C/U', 'U/C', 'CU.svg'],
        ['C/B', 'B/C', 'CB.svg'],
        ['C/R', 'R/C', 'CR.svg'],
        ['C/G', 'G/C', 'CG.svg'],
      ];

      for (final item in colorlessHybrids) {
        expect(ScryfallSymbolCatalog.resolveFilename(item[0]), equals(item[2]));
        expect(ScryfallSymbolCatalog.resolveFilename(item[1]), equals(item[2]));
        expect(ScryfallSymbolCatalog.calculateManaValue('{${item[0]}}'), equals(1.0));
        expect(ScryfallSymbolCatalog.calculateManaValue('{${item[1]}}'), equals(1.0));
      }
    });

    test('All 6 monocolor/colorless Phyrexian transpositions resolve symmetrically', () {
      final phyrexians = [
        ['W/P', 'P/W', 'WP.svg'],
        ['U/P', 'P/U', 'UP.svg'],
        ['B/P', 'P/B', 'BP.svg'],
        ['R/P', 'P/R', 'RP.svg'],
        ['G/P', 'P/G', 'GP.svg'],
        ['C/P', 'P/C', 'CP.svg'],
      ];

      for (final item in phyrexians) {
        expect(ScryfallSymbolCatalog.resolveFilename(item[0]), equals(item[2]));
        expect(ScryfallSymbolCatalog.resolveFilename(item[1]), equals(item[2]));
        expect(ScryfallSymbolCatalog.calculateManaValue('{${item[0]}}'), equals(1.0));
        expect(ScryfallSymbolCatalog.calculateManaValue('{${item[1]}}'), equals(1.0));
      }
    });

    test('All permutations of 3-component hybrid Phyrexian resolve to same asset and CMC', () {
      // Test {B/G/P} and all 6 permutations: BGP, BPG, GBP, GPB, PBG, PGB
      final bgpPermutations = [
        'B/G/P', 'B/P/G', 'G/B/P', 'G/P/B', 'P/B/G', 'P/G/B'
      ];

      for (final perm in bgpPermutations) {
        expect(ScryfallSymbolCatalog.resolveFilename(perm), equals('BGP.svg'),
            reason: 'Permutation {$perm} did not resolve to BGP.svg');
        expect(ScryfallSymbolCatalog.calculateManaValue('{$perm}'), equals(1.0),
            reason: 'Permutation {$perm} did not calculate CMC 1.0');
      }
    });

    test('High-throughput generator: 1,000 concatenated symbols performance and precision', () {
      // 100 repeats of a 10-symbol sequence:
      // {W}{U}{B}{R}{G}{2/W}{W/U}{B/G/P}{1000000}{15}
      // CMC per unit: 1 + 1 + 1 + 1 + 1 + 2 + 1 + 1 + 1000000 + 15 = 1000024.0
      // 100 units = 1000 symbols. Total CMC = 100,002,400.0
      final unit = '{W}{U}{B}{R}{G}{2/W}{W/U}{B/G/P}{1000000}{15}';
      final massiveCost = StringBuffer();
      for (int i = 0; i < 100; i++) {
        massiveCost.write(unit);
      }

      final stopwatch = Stopwatch()..start();
      final extracted = ScryfallSymbolCatalog.extractSymbols(massiveCost.toString());
      final cmc = ScryfallSymbolCatalog.calculateManaValue(massiveCost.toString());
      stopwatch.stop();

      expect(extracted.length, equals(1000));
      expect(cmc, equals(100002400.0));
      // Should easily complete in under 50ms on any modern machine
      expect(stopwatch.elapsedMilliseconds, lessThan(100),
          reason: 'Parsing 1,000 symbols took excessively long: ${stopwatch.elapsedMilliseconds}ms');
    });
  });
}
