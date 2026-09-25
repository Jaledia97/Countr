// Copyright (c) 2026 Countr. All rights reserved.
// Unit tests for ScryfallSymbolCatalog and ScryfallSymbol data model.

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/features/symbology/data/scryfall_symbol_catalog.dart';

void main() {
  group('ScryfallSymbolCatalog - Asset & Catalog Integrity', () {
    test('contains exactly 84 official MTG symbols in symbols and allSymbols', () {
      expect(ScryfallSymbolCatalog.symbols.length, equals(84));
      expect(ScryfallSymbolCatalog.allSymbols.length, equals(84));
    });

    test('all 84 catalog asset files physically exist on disk and contain valid SVG XML', () {
      expect(Directory('assets/symbology').existsSync(), isTrue);

      for (final symbol in ScryfallSymbolCatalog.allSymbols.values) {
        final file = File('assets/symbology/${symbol.filename}');
        expect(file.existsSync(), isTrue, reason: 'Missing SVG asset: ${symbol.filename}');
        final content = file.readAsStringSync();
        expect(content.length, greaterThanOrEqualTo(100),
            reason: 'SVG asset ${symbol.filename} is suspiciously small');
        expect(content, contains('<svg'),
            reason: 'SVG asset ${symbol.filename} is missing opening <svg> tag');
        expect(content, contains('</svg>'),
            reason: 'SVG asset ${symbol.filename} is missing closing </svg> tag');
        expect(content, isNot(contains('<!DOCTYPE html')),
            reason: 'SVG asset ${symbol.filename} contains HTML doctype');
      }
    });

    test('all 84 symbols have unique filenames', () {
      final filenames = ScryfallSymbolCatalog.allSymbols.values.map((s) => s.filename).toSet();
      expect(filenames.length, equals(84));
    });
  });

  group('ScryfallSymbol - Model Properties & Behavioral Methods', () {
    test('standard mana symbol properties are populated accurately', () {
      final blue = ScryfallSymbolCatalog.findBySymbol('{U}');
      expect(blue, isNotNull);
      expect(blue!.symbol, equals('{U}'));
      expect(blue.filename, equals('U.svg'));
      expect(blue.english, equals('one blue mana'));
      expect(blue.manaValue, equals(1.0));
      expect(blue.representsMana, isTrue);
      expect(blue.appearsInManaCosts, isTrue);
      expect(blue.isHybrid, isFalse);
      expect(blue.isPhyrexian, isFalse);
      expect(blue.colors, equals(['U']));
      expect(blue.assetPath, equals('assets/symbology/U.svg'));
      expect(blue.cleanCode, equals('U'));
      expect(blue.isMonoColored, isTrue);
      expect(blue.isMultiColored, isFalse);
      expect(blue.isColorless, isFalse);
    });

    test('hybrid symbol properties are populated accurately', () {
      final wu = ScryfallSymbolCatalog.findBySymbol('{W/U}');
      expect(wu, isNotNull);
      expect(wu!.isHybrid, isTrue);
      expect(wu.isPhyrexian, isFalse);
      expect(wu.colors, equals(['W', 'U']));
      expect(wu.isMonoColored, isFalse);
      expect(wu.isMultiColored, isTrue);
      expect(wu.manaValue, equals(1.0));
      expect(wu.cleanCode, equals('W/U'));
    });

    test('phyrexian symbol properties are populated accurately', () {
      final bp = ScryfallSymbolCatalog.findBySymbol('{B/P}');
      expect(bp, isNotNull);
      expect(bp!.isPhyrexian, isTrue);
      expect(bp.isHybrid, isFalse);
      expect(bp.colors, equals(['B']));
      expect(bp.manaValue, equals(1.0));
    });

    test('action and counter symbols have representsMana false and zero mana value', () {
      final tap = ScryfallSymbolCatalog.findBySymbol('{T}');
      expect(tap, isNotNull);
      expect(tap!.representsMana, isFalse);
      expect(tap.appearsInManaCosts, isFalse);
      expect(tap.manaValue, equals(0.0));

      final energy = ScryfallSymbolCatalog.findBySymbol('{E}');
      expect(energy, isNotNull);
      expect(energy!.representsMana, isFalse);
      expect(energy.appearsInManaCosts, isFalse);
    });

    test('colorless mana symbol has isColorless true', () {
      final c = ScryfallSymbolCatalog.findBySymbol('{C}');
      expect(c, isNotNull);
      expect(c!.colors, isEmpty);
      expect(c.representsMana, isTrue);
      expect(c.isColorless, isTrue);
      expect(c.isMonoColored, isFalse);
    });

    test('equality, hashCode, and toString work as expected', () {
      final sym1 = ScryfallSymbolCatalog.findBySymbol('{W}');
      final sym2 = ScryfallSymbolCatalog.findBySymbol('W');
      expect(sym1, equals(sym2));
      expect(sym1.hashCode, equals(sym2.hashCode));
      expect(sym1.toString(), contains('ScryfallSymbol({W} -> W.svg)'));
    });
  });

  group('ScryfallSymbolCatalog - Canonical Symbol Resolution', () {
    test('resolves traditional colored mana symbols', () {
      expect(ScryfallSymbolCatalog.resolveAssetPath('{W}'), equals('assets/symbology/W.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{U}'), equals('assets/symbology/U.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{B}'), equals('assets/symbology/B.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{R}'), equals('assets/symbology/R.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{G}'), equals('assets/symbology/G.svg'));
    });

    test('resolves colorless and snow mana symbols', () {
      expect(ScryfallSymbolCatalog.resolveAssetPath('{C}'), equals('assets/symbology/C.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{S}'), equals('assets/symbology/S.svg'));
    });

    test('resolves generic numeric symbols from 0 to 20, 100, and 1000000', () {
      expect(ScryfallSymbolCatalog.resolveAssetPath('{0}'), equals('assets/symbology/0.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{1}'), equals('assets/symbology/1.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{2}'), equals('assets/symbology/2.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{10}'), equals('assets/symbology/10.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{20}'), equals('assets/symbology/20.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{100}'), equals('assets/symbology/100.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{1000000}'), equals('assets/symbology/1000000.svg'));
    });

    test('resolves variable mana symbols X, Y, Z', () {
      expect(ScryfallSymbolCatalog.resolveAssetPath('{X}'), equals('assets/symbology/X.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{Y}'), equals('assets/symbology/Y.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{Z}'), equals('assets/symbology/Z.svg'));
    });

    test('resolves all 10 two-color guild hybrids', () {
      expect(ScryfallSymbolCatalog.resolveAssetPath('{W/U}'), equals('assets/symbology/WU.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{W/B}'), equals('assets/symbology/WB.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{B/R}'), equals('assets/symbology/BR.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{B/G}'), equals('assets/symbology/BG.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{U/B}'), equals('assets/symbology/UB.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{U/R}'), equals('assets/symbology/UR.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{R/G}'), equals('assets/symbology/RG.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{R/W}'), equals('assets/symbology/RW.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{G/W}'), equals('assets/symbology/GW.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{G/U}'), equals('assets/symbology/GU.svg'));
    });

    test('resolves all 5 colorless hybrids', () {
      expect(ScryfallSymbolCatalog.resolveAssetPath('{C/W}'), equals('assets/symbology/CW.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{C/U}'), equals('assets/symbology/CU.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{C/B}'), equals('assets/symbology/CB.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{C/R}'), equals('assets/symbology/CR.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{C/G}'), equals('assets/symbology/CG.svg'));
    });

    test('resolves all 5 monocolored twobrids', () {
      expect(ScryfallSymbolCatalog.resolveAssetPath('{2/W}'), equals('assets/symbology/2W.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{2/U}'), equals('assets/symbology/2U.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{2/B}'), equals('assets/symbology/2B.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{2/R}'), equals('assets/symbology/2R.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{2/G}'), equals('assets/symbology/2G.svg'));
    });

    test('resolves all 6 single-color and colorless Phyrexian symbols plus {H}', () {
      expect(ScryfallSymbolCatalog.resolveAssetPath('{W/P}'), equals('assets/symbology/WP.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{U/P}'), equals('assets/symbology/UP.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{B/P}'), equals('assets/symbology/BP.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{R/P}'), equals('assets/symbology/RP.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{G/P}'), equals('assets/symbology/GP.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{C/P}'), equals('assets/symbology/CP.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{H}'), equals('assets/symbology/H.svg'));
    });

    test('resolves all 10 hybrid Phyrexian symbols', () {
      expect(ScryfallSymbolCatalog.resolveAssetPath('{B/G/P}'), equals('assets/symbology/BGP.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{B/R/P}'), equals('assets/symbology/BRP.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{G/U/P}'), equals('assets/symbology/GUP.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{G/W/P}'), equals('assets/symbology/GWP.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{R/G/P}'), equals('assets/symbology/RGP.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{R/W/P}'), equals('assets/symbology/RWP.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{U/B/P}'), equals('assets/symbology/UBP.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{U/R/P}'), equals('assets/symbology/URP.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{W/B/P}'), equals('assets/symbology/WBP.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{W/U/P}'), equals('assets/symbology/WUP.svg'));
    });

    test('resolves action and keyword symbols', () {
      expect(ScryfallSymbolCatalog.resolveAssetPath('{T}'), equals('assets/symbology/T.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{Q}'), equals('assets/symbology/Q.svg'));
    });

    test('resolves game counters', () {
      expect(ScryfallSymbolCatalog.resolveAssetPath('{E}'), equals('assets/symbology/E.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{P}'), equals('assets/symbology/P.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{PW}'), equals('assets/symbology/PW.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{CHAOS}'), equals('assets/symbology/CHAOS.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{TK}'), equals('assets/symbology/TK.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{A}'), equals('assets/symbology/A.svg'));
    });

    test('resolves playtest and half mana symbols', () {
      expect(ScryfallSymbolCatalog.resolveAssetPath('{HW}'), equals('assets/symbology/HW.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{HR}'), equals('assets/symbology/HR.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{L}'), equals('assets/symbology/L.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{D}'), equals('assets/symbology/D.svg'));
    });
  });

  group('ScryfallSymbolCatalog - Special Unicode & ASCII Aliases', () {
    test('resolves half mana symbol from unicode and ASCII aliases', () {
      expect(ScryfallSymbolCatalog.resolveAssetPath('{½}'), equals('assets/symbology/HALF.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('½'), equals('assets/symbology/HALF.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('HALF'), equals('assets/symbology/HALF.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{half}'), equals('assets/symbology/HALF.svg'));
    });

    test('resolves infinite mana symbol from unicode and ASCII aliases', () {
      expect(ScryfallSymbolCatalog.resolveAssetPath('{∞}'), equals('assets/symbology/INFINITY.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('∞'), equals('assets/symbology/INFINITY.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('INFINITY'), equals('assets/symbology/INFINITY.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{infinity}'), equals('assets/symbology/INFINITY.svg'));
    });
  });

  group('ScryfallSymbolCatalog - Transposable Aliases & Formatting Tolerance', () {
    test('resolves reversed Phyrexian notation (e.g. {P/B} -> BP.svg)', () {
      expect(ScryfallSymbolCatalog.resolveAssetPath('{P/B}'), equals('assets/symbology/BP.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{P/W}'), equals('assets/symbology/WP.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{P/U}'), equals('assets/symbology/UP.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{P/R}'), equals('assets/symbology/RP.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{P/G}'), equals('assets/symbology/GP.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{P/C}'), equals('assets/symbology/CP.svg'));
    });

    test('resolves reversed hybrid notations (e.g. {U/W} -> WU.svg)', () {
      expect(ScryfallSymbolCatalog.resolveAssetPath('{U/W}'), equals('assets/symbology/WU.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{B/W}'), equals('assets/symbology/WB.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{R/B}'), equals('assets/symbology/BR.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{G/B}'), equals('assets/symbology/BG.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{B/U}'), equals('assets/symbology/UB.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{R/U}'), equals('assets/symbology/UR.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{G/R}'), equals('assets/symbology/RG.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{W/R}'), equals('assets/symbology/RW.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{W/G}'), equals('assets/symbology/GW.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{U/G}'), equals('assets/symbology/GU.svg'));
    });

    test('resolves reversed twobrids (e.g. {W/2} -> 2W.svg)', () {
      expect(ScryfallSymbolCatalog.resolveAssetPath('{W/2}'), equals('assets/symbology/2W.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{U/2}'), equals('assets/symbology/2U.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{B/2}'), equals('assets/symbology/2B.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{R/2}'), equals('assets/symbology/2R.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{G/2}'), equals('assets/symbology/2G.svg'));
    });

    test('resolves reversed colorless hybrids (e.g. {W/C} -> CW.svg)', () {
      expect(ScryfallSymbolCatalog.resolveAssetPath('{W/C}'), equals('assets/symbology/CW.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{U/C}'), equals('assets/symbology/CU.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{B/C}'), equals('assets/symbology/CB.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{R/C}'), equals('assets/symbology/CR.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{G/C}'), equals('assets/symbology/CG.svg'));
    });

    test('resolves hybrid Phyrexian permutations (3 components)', () {
      expect(ScryfallSymbolCatalog.resolveAssetPath('{G/B/P}'), equals('assets/symbology/BGP.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{P/B/G}'), equals('assets/symbology/BGP.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{P/G/B}'), equals('assets/symbology/BGP.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{B/P/G}'), equals('assets/symbology/BGP.svg'));
    });

    test('handles lowercase, unbracketed, and whitespace variations', () {
      expect(ScryfallSymbolCatalog.resolveAssetPath('w'), equals('assets/symbology/W.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('{w}'), equals('assets/symbology/W.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('  {w/u}  '), equals('assets/symbology/WU.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('p/b'), equals('assets/symbology/BP.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('WU.svg'), equals('assets/symbology/WU.svg'));
      expect(ScryfallSymbolCatalog.resolveAssetPath('wu.svg'), equals('assets/symbology/WU.svg'));
    });

    test('returns null for unknown tokens and malformed input without throwing', () {
      expect(ScryfallSymbolCatalog.resolveAssetPath('{NotASymbol}'), isNull);
      expect(ScryfallSymbolCatalog.resolveAssetPath(''), isNull);
      expect(ScryfallSymbolCatalog.resolveAssetPath('   '), isNull);
      expect(ScryfallSymbolCatalog.resolveAssetPath('{W'), isNull);
      expect(ScryfallSymbolCatalog.resolveAssetPath('W}'), isNull);
      expect(ScryfallSymbolCatalog.resolveAssetPath('{}'), isNull);
    });

    test('resolveFilename returns filename directly', () {
      expect(ScryfallSymbolCatalog.resolveFilename('{W/U}'), equals('WU.svg'));
      expect(ScryfallSymbolCatalog.resolveFilename('P/B'), equals('BP.svg'));
      expect(ScryfallSymbolCatalog.resolveFilename('invalid'), isNull);
    });
  });

  group('ScryfallSymbolCatalog - extractSymbols and calculateManaValue', () {
    test('extractSymbols parses bracketed mana strings into tokens', () {
      expect(ScryfallSymbolCatalog.extractSymbols('{2}{U}{B}'), equals(['2', 'U', 'B']));
      expect(ScryfallSymbolCatalog.extractSymbols('{W/U}{G/P}'), equals(['W/U', 'G/P']));
      expect(ScryfallSymbolCatalog.extractSymbols('{X}{W}{W}'), equals(['X', 'W', 'W']));
      expect(ScryfallSymbolCatalog.extractSymbols(''), isEmpty);
    });

    test('extractSymbols filters invalid tokens when validate is true', () {
      expect(ScryfallSymbolCatalog.extractSymbols('{2}{FakeSymbol}{U}', validate: true),
          equals(['2', 'U']));
      expect(ScryfallSymbolCatalog.extractSymbols('{2}{FakeSymbol}{U}', validate: false),
          equals(['2', 'FakeSymbol', 'U']));
    });

    test('extractSymbols handles single unbracketed valid symbol', () {
      expect(ScryfallSymbolCatalog.extractSymbols('W'), equals(['W']));
      expect(ScryfallSymbolCatalog.extractSymbols('W/U'), equals(['W/U']));
      expect(ScryfallSymbolCatalog.extractSymbols('invalid'), isEmpty);
    });

    test('calculateManaValue computes correct total CMC', () {
      expect(ScryfallSymbolCatalog.calculateManaValue('{2}{U}{B}'), equals(4.0));
      expect(ScryfallSymbolCatalog.calculateManaValue('{W/U}{G}'), equals(2.0));
      expect(ScryfallSymbolCatalog.calculateManaValue('{2/W}{2/U}'), equals(4.0));
      expect(ScryfallSymbolCatalog.calculateManaValue('{½}'), equals(0.5));
      expect(ScryfallSymbolCatalog.calculateManaValue('{X}{R}'), equals(1.0));
      expect(ScryfallSymbolCatalog.calculateManaValue(''), equals(0.0));
    });

    test('calculateManaValue returns null for infinite mana or unknown symbols', () {
      expect(ScryfallSymbolCatalog.calculateManaValue('{∞}'), isNull);
      expect(ScryfallSymbolCatalog.calculateManaValue('{2}{∞}'), isNull);
      expect(ScryfallSymbolCatalog.calculateManaValue('{2}{FakeSymbol}'), isNull);
    });
  });
}
