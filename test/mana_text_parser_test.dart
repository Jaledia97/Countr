// Copyright (c) 2026 Countr. All rights reserved.
// Root-level test runner and discovery aliasing domain and widget symbology tests.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/features/symbology/data/scryfall_symbol_catalog.dart';
import 'package:countr/features/symbology/domain/mana_text_parser.dart';
import 'features/symbology/domain/mana_text_parser_test.dart' as parser_suite;

void main() {
  group('Root Alias Runner - ManaTextParser Verification', () {
    test('catalog manifests 84 official symbols at root discovery', () {
      expect(ScryfallSymbolCatalog.symbols.length, equals(84));
    });

    test('parser smoke check parses {2}{U}{B} from root entrypoint', () {
      final spans = ManaTextParser.parse(
        text: '{2}{U}{B}',
        baseStyle: const TextStyle(fontSize: 14.0),
      );
      expect(spans.length, equals(3));
    });
  });

  // Forward execution to comprehensive domain parser test suite
  parser_suite.main();
}
