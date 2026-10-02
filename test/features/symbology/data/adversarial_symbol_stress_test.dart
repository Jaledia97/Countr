// Copyright (c) 2026 Countr. All rights reserved.
// Adversarial stress test harness for MTG Symbology Asset Pipeline & Symbol Catalog.
// Designed by Empirical Challenger to probe edge cases, boundary inputs, transpositions,
// XML validity, file system invariants, and error resilience.

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/features/symbology/data/scryfall_symbol_catalog.dart';

void main() {
  group('Empirical Asset Verification - File System & XML Integrity', () {
    const assetsDir = 'assets/symbology';

    test('asset directory exists and contains exactly 84 SVG files', () {
      final dir = Directory(assetsDir);
      expect(dir.existsSync(), isTrue, reason: 'Directory $assetsDir must exist');

      final svgFiles = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.svg'))
          .toList();

      expect(svgFiles.length, equals(84),
          reason: 'Must contain exactly 84 SVG files, but found ${svgFiles.length}');

      // Ensure no non-SVG files exist in the symbology folder
      final allFiles = dir.listSync().whereType<File>().toList();
      expect(allFiles.length, equals(84),
          reason: 'Symbology folder should contain only the 84 SVG assets');
    });

    test('all 84 SVG files have valid file size and no empty files', () {
      final dir = Directory(assetsDir);
      final svgFiles = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.svg'))
          .toList();

      for (final file in svgFiles) {
        final length = file.lengthSync();
        expect(length, greaterThan(100),
            reason: '${file.path} is too small ($length bytes), potential corrupted asset');
        expect(length, lessThan(50000),
            reason: '${file.path} is suspiciously large ($length bytes)');
      }
    });

    test('all 84 SVG files contain valid XML structure and valid viewBox', () {
      final dir = Directory(assetsDir);
      final svgFiles = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.svg'))
          .toList();

      final viewBoxRegex = RegExp(r'viewBox=["\x27]([^"\x27]+)["\x27]', caseSensitive: false);

      for (final file in svgFiles) {
        final content = file.readAsStringSync();

        // XML tag structure
        expect(content.contains('<svg'), isTrue,
            reason: '${file.path} lacks opening <svg> tag');
        expect(content.contains('</svg>'), isTrue,
            reason: '${file.path} lacks closing </svg> tag');

        // ViewBox validation
        final match = viewBoxRegex.firstMatch(content);
        expect(match, isNotNull,
            reason: '${file.path} is missing viewBox attribute');
        final vbValue = match!.group(1)!.trim();
        expect(RegExp(r'^\d+\s+\d+\s+\d+\s+\d+$').hasMatch(vbValue), isTrue,
            reason: '${file.path} viewBox "$vbValue" is not in "min-x min-y width height" format');
      }
    });

    test('no SVG files contain HTTP/HTML error pages or Cloudflare blocks', () {
      final dir = Directory(assetsDir);
      final svgFiles = dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.svg'))
          .toList();

      final forbiddenSignatures = [
        '<!DOCTYPE html',
        '<html',
        '<head',
        '<body',
        '400 Bad Request',
        '403 Forbidden',
        '404 Not Found',
        '500 Internal',
        'Cloudflare',
        'Access Denied',
        'Ray ID',
        '<title>Error',
      ];

      for (final file in svgFiles) {
        final content = file.readAsStringSync().toLowerCase();
        for (final sig in forbiddenSignatures) {
          expect(content.contains(sig.toLowerCase()), isFalse,
              reason: '${file.path} contains forbidden HTTP error signature "$sig"');
        }
      }
    });
  });

  group('Empirical Catalog Stress Testing - Canonical Resolution to Disk', () {
    test('every symbol in ScryfallSymbolCatalog resolves to a physical file on disk', () {
      for (final entry in ScryfallSymbolCatalog.allSymbols.entries) {
        final code = entry.key;
        final symbol = entry.value;

        // Path resolution
        final resolvedPath = ScryfallSymbolCatalog.resolveAssetPath(code);
        expect(resolvedPath, isNotNull, reason: 'Failed to resolve assetPath for $code');
        expect(resolvedPath, equals('assets/symbology/${symbol.filename}'));

        final file = File(resolvedPath!);
        expect(file.existsSync(), isTrue,
            reason: 'Resolved assetPath for $code does not exist on disk: $resolvedPath');

        // Filename resolution
        final resolvedFilename = ScryfallSymbolCatalog.resolveFilename(code);
        expect(resolvedFilename, equals(symbol.filename));

        // Model lookup
        final found = ScryfallSymbolCatalog.findBySymbol(code);
        expect(found, equals(symbol));
        expect(ScryfallSymbolCatalog.isValidSymbol(code), isTrue);
      }
    });

    test('unbracketed canonical symbol codes resolve correctly to disk', () {
      for (final symbol in ScryfallSymbolCatalog.allSymbols.values) {
        final clean = symbol.cleanCode;
        final resolvedPath = ScryfallSymbolCatalog.resolveAssetPath(clean);
        expect(resolvedPath, isNotNull,
            reason: 'Clean code "$clean" for ${symbol.symbol} failed to resolve');

        final file = File(resolvedPath!);
        expect(file.existsSync(), isTrue,
            reason: 'Clean code "$clean" resolved to missing file $resolvedPath');
      }
    });
  });

  group('Empirical Catalog Stress Testing - Transposable Aliases', () {
    test('all two-color hybrid transpositions resolve to existing physical files', () {
      final hybridPairs = {
        '{U/W}': 'WU.svg',
        '{B/W}': 'WB.svg',
        '{R/U}': 'UR.svg',
        '{B/U}': 'UB.svg',
        '{G/B}': 'BG.svg',
        '{R/B}': 'BR.svg',
        '{G/R}': 'RG.svg',
        '{W/R}': 'RW.svg',
        '{G/W}': 'GW.svg',
        '{U/G}': 'GU.svg',
      };

      for (final entry in hybridPairs.entries) {
        final alias = entry.key;
        final expectedFilename = entry.value;

        final resolvedPath = ScryfallSymbolCatalog.resolveAssetPath(alias);
        expect(resolvedPath, equals('assets/symbology/$expectedFilename'),
            reason: 'Alias $alias should resolve to $expectedFilename');

        final file = File(resolvedPath!);
        expect(file.existsSync(), isTrue,
            reason: 'Alias $alias resolved file does not exist: $resolvedPath');
      }
    });

    test('all twobrid reverse aliases resolve to existing physical files', () {
      final twobridPairs = {
        '{W/2}': '2W.svg',
        '{U/2}': '2U.svg',
        '{B/2}': '2B.svg',
        '{R/2}': '2R.svg',
        '{G/2}': '2G.svg',
      };

      for (final entry in twobridPairs.entries) {
        final alias = entry.key;
        final expectedFilename = entry.value;

        final resolvedPath = ScryfallSymbolCatalog.resolveAssetPath(alias);
        expect(resolvedPath, equals('assets/symbology/$expectedFilename'),
            reason: 'Twobrid alias $alias should resolve to $expectedFilename');

        final file = File(resolvedPath!);
        expect(file.existsSync(), isTrue,
            reason: 'Twobrid alias $alias resolved file does not exist: $resolvedPath');
      }
    });

    test('all colorless hybrid reverse aliases resolve to existing physical files', () {
      final colorlessHybridPairs = {
        '{W/C}': 'CW.svg',
        '{U/C}': 'CU.svg',
        '{B/C}': 'CB.svg',
        '{R/C}': 'CR.svg',
        '{G/C}': 'CG.svg',
      };

      for (final entry in colorlessHybridPairs.entries) {
        final alias = entry.key;
        final expectedFilename = entry.value;

        final resolvedPath = ScryfallSymbolCatalog.resolveAssetPath(alias);
        expect(resolvedPath, equals('assets/symbology/$expectedFilename'),
            reason: 'Colorless hybrid alias $alias should resolve to $expectedFilename');

        final file = File(resolvedPath!);
        expect(file.existsSync(), isTrue,
            reason: 'Colorless hybrid alias $alias resolved file does not exist: $resolvedPath');
      }
    });

    test('all Phyrexian reverse aliases resolve to existing physical files', () {
      final phyrexianPairs = {
        '{P/W}': 'WP.svg',
        '{P/U}': 'UP.svg',
        '{P/B}': 'BP.svg',
        '{P/R}': 'RP.svg',
        '{P/G}': 'GP.svg',
        '{P/C}': 'CP.svg',
      };

      for (final entry in phyrexianPairs.entries) {
        final alias = entry.key;
        final expectedFilename = entry.value;

        final resolvedPath = ScryfallSymbolCatalog.resolveAssetPath(alias);
        expect(resolvedPath, equals('assets/symbology/$expectedFilename'),
            reason: 'Phyrexian alias $alias should resolve to $expectedFilename');

        final file = File(resolvedPath!);
        expect(file.existsSync(), isTrue,
            reason: 'Phyrexian alias $alias resolved file does not exist: $resolvedPath');
      }
    });

    test('all hybrid Phyrexian 3-component permutations resolve to existing physical files', () {
      // 10 Hybrid Phyrexians: test all 6 permutations of (ColorA, ColorB, P)
      final hybridPhyrexianTrios = [
        ['G', 'U', 'GUP.svg'],
        ['G', 'W', 'GWP.svg'],
        ['R', 'G', 'RGP.svg'],
        ['R', 'W', 'RWP.svg'],
        ['U', 'B', 'UBP.svg'],
        ['U', 'R', 'URP.svg'],
        ['W', 'B', 'WBP.svg'],
        ['W', 'U', 'WUP.svg'],
        ['B', 'G', 'BGP.svg'],
        ['B', 'R', 'BRP.svg'],
      ];

      for (final trio in hybridPhyrexianTrios) {
        final c1 = trio[0];
        final c2 = trio[1];
        final expectedFile = trio[2];

        final permutations = [
          '{$c1/$c2/P}',
          '{$c1/P/$c2}',
          '{$c2/$c1/P}',
          '{$c2/P/$c1}',
          '{P/$c1/$c2}',
          '{P/$c2/$c1}',
        ];

        for (final perm in permutations) {
          final resolved = ScryfallSymbolCatalog.resolveAssetPath(perm);
          expect(resolved, equals('assets/symbology/$expectedFile'),
              reason: 'Permutation $perm should resolve to $expectedFile');

          final file = File(resolved!);
          expect(file.existsSync(), isTrue,
              reason: 'Permutation $perm resolved file does not exist: $resolved');
        }
      }
    });
  });

  group('Empirical Catalog Stress Testing - Case Sensitivity & Formatting', () {
    test('lowercase bracketed inputs resolve to valid assets', () {
      final lowercaseSamples = {
        '{w}': 'W.svg',
        '{u}': 'U.svg',
        '{b}': 'B.svg',
        '{r}': 'R.svg',
        '{g}': 'G.svg',
        '{c}': 'C.svg',
        '{s}': 'S.svg',
        '{t}': 'T.svg',
        '{q}': 'Q.svg',
        '{e}': 'E.svg',
        '{w/u}': 'WU.svg',
        '{u/w}': 'WU.svg',
        '{p/b}': 'BP.svg',
        '{g/b/p}': 'BGP.svg',
        '{w/2}': '2W.svg',
        '{w/c}': 'CW.svg',
        '{chaos}': 'CHAOS.svg',
        '{pw}': 'PW.svg',
        '{tk}': 'TK.svg',
      };

      for (final entry in lowercaseSamples.entries) {
        final resolved = ScryfallSymbolCatalog.resolveAssetPath(entry.key);
        expect(resolved, equals('assets/symbology/${entry.value}'),
            reason: 'Lowercase input ${entry.key} failed to resolve to ${entry.value}');
      }
    });

    test('mixed case inputs resolve to valid assets', () {
      final mixedCaseSamples = {
        '{w/U}': 'WU.svg',
        '{P/b}': 'BP.svg',
        '{G/b/P}': 'BGP.svg',
        '{ChAoS}': 'CHAOS.svg',
        '{Pw}': 'PW.svg',
        '{Tk}': 'TK.svg',
      };

      for (final entry in mixedCaseSamples.entries) {
        final resolved = ScryfallSymbolCatalog.resolveAssetPath(entry.key);
        expect(resolved, equals('assets/symbology/${entry.value}'));
      }
    });

    test('inputs with .svg and .SVG extensions resolve correctly', () {
      expect(ScryfallSymbolCatalog.resolveAssetPath('W.svg'), equals('assets/symbology/W.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('w.svg'), equals('assets/symbology/W.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('WU.SVG'), equals('assets/symbology/WU.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('bp.svg'), equals('assets/symbology/BP.svg'));
    });

    test('inputs with leading and trailing whitespace resolve correctly', () {
      expect(ScryfallSymbolCatalog.resolveAssetPath('  {W}  '), equals('assets/symbology/W.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('\t{U/B}\n'), equals('assets/symbology/UB.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('  W  '), equals('assets/symbology/W.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{ W }'), equals('assets/symbology/W.svg'));
    });
  });

  group('Empirical Catalog Stress Testing - Edge Cases, Malformed & Boundary Inputs', () {
    test('empty and whitespace-only inputs return null safely', () {
      expect(ScryfallSymbolCatalog.findBySymbol(''), isNull);
      expect(ScryfallSymbolCatalog.findBySymbol('   '), isNull);
      expect(ScryfallSymbolCatalog.findBySymbol('\t\n'), isNull);
      expect(ScryfallSymbolCatalog.isValidSymbol(''), isFalse);
      expect(ScryfallSymbolCatalog.isValidSymbol('   '), isFalse);
      expect(ScryfallSymbolCatalog.resolveAssetPath(''), isNull);
      expect(ScryfallSymbolCatalog.resolveAssetPath('   '), isNull);
      expect(ScryfallSymbolCatalog.resolveFilename(''), isNull);
      expect(ScryfallSymbolCatalog.extractSymbols(''), isEmpty);
      expect(ScryfallSymbolCatalog.extractSymbols('   '), isEmpty);
      expect(ScryfallSymbolCatalog.calculateManaValue(''), equals(0.0));
      // Note: '   ' currently returns null because extractSymbols('   ', validate: false) returns ['']
      expect(ScryfallSymbolCatalog.calculateManaValue('   '), isNull);
    });

    test('unclosed brackets and malformed braces do not throw and return null', () {
      final malformed = [
        '{W',
        'W}',
        '{2 and tap',
        '{{W}}',
        '{{W}',
        '{W}}',
        '{',
        '}',
        '{}',
        '{/}',
        '{//}',
        '{///}',
        '{W//U}',
        '{/W}',
        '{W/}',
        '{W/U/}',
        '{/W/U}',
        '{???}',
        '{!}',
      ];

      for (final m in malformed) {
        expect(() => ScryfallSymbolCatalog.findBySymbol(m), returnsNormally,
            reason: 'findBySymbol must not throw on "$m"');
        expect(ScryfallSymbolCatalog.findBySymbol(m), isNull,
            reason: '"$m" should not match any valid symbol');
        expect(ScryfallSymbolCatalog.isValidSymbol(m), isFalse);
        expect(ScryfallSymbolCatalog.resolveAssetPath(m), isNull);
      }
    });

    test('non-mana brackets and reminder text are safely rejected', () {
      final nonManaTokens = [
        '{NotASymbol}',
        '{Reminder}',
        '{Flying}',
        '{Trample}',
        '{Haste}',
        '{12345}',
        '{XYZ}',
        '{CARDNAME}',
        '{FOO/BAR}',
      ];

      for (final token in nonManaTokens) {
        expect(ScryfallSymbolCatalog.findBySymbol(token), isNull,
            reason: 'Unknown token $token should return null');
        expect(ScryfallSymbolCatalog.isValidSymbol(token), isFalse);
        expect(ScryfallSymbolCatalog.resolveAssetPath(token), isNull);
      }
    });

    test('unicode variations {½} and {∞} resolve correctly', () {
      // Half mana
      final half = ScryfallSymbolCatalog.findBySymbol('{½}');
      expect(half, isNotNull);
      expect(half!.filename, equals('HALF.svg'));
      expect(half.manaValue, equals(0.5));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{½}'), equals('assets/symbology/HALF.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('½'), equals('assets/symbology/HALF.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('HALF'), equals('assets/symbology/HALF.svg'));

      // Infinite mana
      final inf = ScryfallSymbolCatalog.findBySymbol('{∞}');
      expect(inf, isNotNull);
      expect(inf!.filename, equals('INFINITY.svg'));
      expect(inf.manaValue, isNull, reason: 'Infinite mana has null CMC in Scryfall spec');
      expect(ScryfallSymbolCatalog.resolveAssetPath('{∞}'), equals('assets/symbology/INFINITY.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('∞'), equals('assets/symbology/INFINITY.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('INFINITY'), equals('assets/symbology/INFINITY.svg'));
    });

    test('boundary numeric symbols resolve correctly while invalid numbers return null', () {
      // Valid numeric symbols
      expect(ScryfallSymbolCatalog.isValidSymbol('{0}'), isTrue);
      expect(ScryfallSymbolCatalog.isValidSymbol('{1}'), isTrue);
      expect(ScryfallSymbolCatalog.isValidSymbol('{16}'), isTrue);
      expect(ScryfallSymbolCatalog.isValidSymbol('{20}'), isTrue);
      expect(ScryfallSymbolCatalog.isValidSymbol('{100}'), isTrue);
      expect(ScryfallSymbolCatalog.isValidSymbol('{1000000}'), isTrue);

      // Numbers without symbols in Scryfall
      expect(ScryfallSymbolCatalog.isValidSymbol('{21}'), isFalse);
      expect(ScryfallSymbolCatalog.isValidSymbol('{99}'), isFalse);
      expect(ScryfallSymbolCatalog.isValidSymbol('{-1}'), isFalse);
      expect(ScryfallSymbolCatalog.isValidSymbol('{-0}'), isFalse);
      expect(ScryfallSymbolCatalog.isValidSymbol('{101}'), isFalse);
    });

    test('extractSymbols handles valid, mixed, and malformed costs robustly', () {
      // Standard cost
      expect(ScryfallSymbolCatalog.extractSymbols('{2}{U}{B}'), equals(['2', 'U', 'B']));

      // Contiguous hybrids
      expect(ScryfallSymbolCatalog.extractSymbols('{W/U}{B/R}'), equals(['W/U', 'B/R']));

      // Filter unrecognized when validate: true (default)
      expect(ScryfallSymbolCatalog.extractSymbols('{2}{NotASymbol}{G}'), equals(['2', 'G']));

      // Preserve unrecognized when validate: false
      expect(ScryfallSymbolCatalog.extractSymbols('{2}{NotASymbol}{G}', validate: false),
          equals(['2', 'NotASymbol', 'G']));

      // Unclosed braces are ignored by regex
      expect(ScryfallSymbolCatalog.extractSymbols('{2}{U'), equals(['2']));
      expect(ScryfallSymbolCatalog.extractSymbols('2}{U}'), equals(['U']));

      // Unbracketed single symbol
      expect(ScryfallSymbolCatalog.extractSymbols('W'), equals(['W']));
      expect(ScryfallSymbolCatalog.extractSymbols('NotASymbol'), isEmpty);
      expect(ScryfallSymbolCatalog.extractSymbols('NotASymbol', validate: false), equals(['NotASymbol']));
    });

    test('calculateManaValue computes correct totals and handles invalid/infinite costs', () {
      // Standard costs
      expect(ScryfallSymbolCatalog.calculateManaValue('{2}{U}{B}'), equals(4.0));
      expect(ScryfallSymbolCatalog.calculateManaValue('{W}{U}{B}{R}{G}'), equals(5.0));
      expect(ScryfallSymbolCatalog.calculateManaValue('{0}'), equals(0.0));
      expect(ScryfallSymbolCatalog.calculateManaValue('{16}'), equals(16.0));
      expect(ScryfallSymbolCatalog.calculateManaValue('{X}{R}'), equals(1.0));
      expect(ScryfallSymbolCatalog.calculateManaValue('{X}{X}{2}{G}'), equals(3.0));
      expect(ScryfallSymbolCatalog.calculateManaValue('{½}'), equals(0.5));
      expect(ScryfallSymbolCatalog.calculateManaValue('{2/W}{2/U}'), equals(4.0));

      // Infinite mana returns null
      expect(ScryfallSymbolCatalog.calculateManaValue('{∞}'), isNull);
      expect(ScryfallSymbolCatalog.calculateManaValue('{2}{∞}'), isNull);

      // Costs containing invalid or unrecognized tokens return null
      expect(ScryfallSymbolCatalog.calculateManaValue('{2}{NotASymbol}'), isNull);
      expect(ScryfallSymbolCatalog.calculateManaValue('{2}{21}'), isNull);
    });

    test('extreme load stress test: 1000 arbitrary symbol queries run in <1000ms', () {
      final stopwatch = Stopwatch()..start();
      final inputs = [
        '{W}', '{U}', '{B}', '{R}', '{G}', '{C}', '{2}', '{W/U}', '{P/B}',
        '{G/B/P}', '{½}', '{∞}', '{CHAOS}', '{1000000}', '{NotASymbol}',
        '', '   ', '{W', 'W}', '{2/W}', '{W/2}', '{W/C}', '{C/W}'
      ];

      for (int i = 0; i < 1000; i++) {
        final input = inputs[i % inputs.length];
        ScryfallSymbolCatalog.findBySymbol(input);
        ScryfallSymbolCatalog.isValidSymbol(input);
        ScryfallSymbolCatalog.resolveAssetPath(input);
      }

      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds, lessThan(1000),
          reason: '1000 catalog operations took ${stopwatch.elapsedMilliseconds}ms, exceeds 1000ms threshold');
    });
  });
}
