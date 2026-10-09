import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/features/decks/data/models/precon_deck_dto.dart';
import 'package:countr/features/decks/data/services/mtgjson_precon_parser.dart';
import 'package:countr/features/decks/domain/models/board_zone.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Challenger M1-R2-2: PreconSafeCast & Parser Adversarial Stress Tests', () {
    // =========================================================================
    // SUITE 1: PreconSafeCast Direct Primitive Adversarial Matrix
    // =========================================================================
    group('Suite 1: PreconSafeCast Pure Function Edge Cases', () {
      test('1.1 PreconSafeCast.string handles all primitives, collections, and extremes', () {
        // Null & Empty
        expect(PreconSafeCast.string(null), isNull);
        expect(PreconSafeCast.string(null, fallback: 'fb'), equals('fb'));
        expect(PreconSafeCast.string(''), isNull);
        expect(PreconSafeCast.string('', fallback: 'fb'), equals('fb'));
        expect(PreconSafeCast.string('   \t\n  '), isNull);
        expect(PreconSafeCast.string('   \t\n  ', fallback: 'fb'), equals('fb'));

        // Numbers
        expect(PreconSafeCast.string(0), equals('0'));
        expect(PreconSafeCast.string(12345), equals('12345'));
        expect(PreconSafeCast.string(-999), equals('-999'));
        expect(PreconSafeCast.string(3.14159), equals('3.14159'));
        expect(PreconSafeCast.string(double.nan), equals('NaN'));
        expect(PreconSafeCast.string(double.infinity), equals('Infinity'));
        expect(PreconSafeCast.string(double.negativeInfinity), equals('-Infinity'));

        // Booleans
        expect(PreconSafeCast.string(true), equals('true'));
        expect(PreconSafeCast.string(false), equals('false'));

        // Collections: Map and List MUST return fallback (never stringify container)
        expect(PreconSafeCast.string({'key': 'val'}), isNull);
        expect(PreconSafeCast.string({'key': 'val'}, fallback: 'fallback'), equals('fallback'));
        expect(PreconSafeCast.string([1, 2, 3]), isNull);
        expect(PreconSafeCast.string([1, 2, 3], fallback: 'fallback'), equals('fallback'));
        expect(PreconSafeCast.string(<dynamic, dynamic>{}), isNull);
        expect(PreconSafeCast.string(<dynamic>[]), isNull);

        // Unicode, CJK, Emojis
        expect(PreconSafeCast.string('  青白コントロール  '), equals('青白コントロール'));
        expect(PreconSafeCast.string('  🔥🔥🔥  '), equals('🔥🔥🔥'));
      });

      test('1.2 PreconSafeCast.integer handles num, string, float-strings, non-numerics', () {
        // Null
        expect(PreconSafeCast.integer(null), isNull);
        expect(PreconSafeCast.integer(null, fallback: 1), equals(1));

        // Int
        expect(PreconSafeCast.integer(42), equals(42));
        expect(PreconSafeCast.integer(0), equals(0));
        expect(PreconSafeCast.integer(-7), equals(-7));

        // Double / Num
        expect(PreconSafeCast.integer(4.0), equals(4));
        expect(PreconSafeCast.integer(4.99), equals(4));
        expect(PreconSafeCast.integer(-3.2), equals(-3));

        // String representations
        expect(PreconSafeCast.integer('100'), equals(100));
        expect(PreconSafeCast.integer('  -50  '), equals(-50));
        expect(PreconSafeCast.integer('4.0'), equals(4));
        expect(PreconSafeCast.integer('  99.99  '), equals(99));

        // Non-numeric strings
        expect(PreconSafeCast.integer('abc'), isNull);
        expect(PreconSafeCast.integer('abc', fallback: 5), equals(5));
        expect(PreconSafeCast.integer(''), isNull);
        expect(PreconSafeCast.integer('   '), isNull);
        expect(PreconSafeCast.integer('\$4'), isNull);

        // Collections and Booleans
        expect(PreconSafeCast.integer(true), isNull);
        expect(PreconSafeCast.integer(false), isNull);
        expect(PreconSafeCast.integer({'count': 4}), isNull);
        expect(PreconSafeCast.integer([4]), isNull);
      });

      test('1.3 PreconSafeCast.integer handles Infinity and NaN without crashing', () {
        // Zero-crash contract on non-finite values:
        expect(PreconSafeCast.integer('Infinity'), isNull);
        expect(PreconSafeCast.integer('Infinity', fallback: 0), equals(0));
        expect(PreconSafeCast.integer('-Infinity'), isNull);
        expect(PreconSafeCast.integer('NaN'), isNull);
        expect(PreconSafeCast.integer('NaN', fallback: 1), equals(1));
        expect(PreconSafeCast.integer(double.infinity), isNull);
        expect(PreconSafeCast.integer(double.negativeInfinity), isNull);
        expect(PreconSafeCast.integer(double.nan), isNull);
        expect(PreconSafeCast.integer(double.nan, fallback: 99), equals(99));
      });

      test('1.4 PreconSafeCast.float handles double, int, currency strings, non-numerics', () {
        // Null
        expect(PreconSafeCast.float(null), isNull);
        expect(PreconSafeCast.float(null, fallback: 0.0), equals(0.0));

        // Doubles and Ints
        expect(PreconSafeCast.float(3.14), equals(3.14));
        expect(PreconSafeCast.float(10), equals(10.0));
        expect(PreconSafeCast.float(0), equals(0.0));
        expect(PreconSafeCast.float(-5.5), equals(-5.5));

        // Strings with currency / formatting
        expect(PreconSafeCast.float('3.14'), equals(3.14));
        expect(PreconSafeCast.float('  \$19.99  '), equals(19.99));
        expect(PreconSafeCast.float('\$0.50'), equals(0.50));
        expect(PreconSafeCast.float('  100  '), equals(100.0));
        expect(PreconSafeCast.float('\$0'), equals(0.0));

        // Invalid strings
        expect(PreconSafeCast.float(''), isNull);
        expect(PreconSafeCast.float('   '), isNull);
        expect(PreconSafeCast.float('\$'), isNull);
        expect(PreconSafeCast.float('free'), isNull);
        expect(PreconSafeCast.float('N/A', fallback: 1.0), equals(1.0));

        // Collections and Booleans
        expect(PreconSafeCast.float(true), isNull);
        expect(PreconSafeCast.float(false), isNull);
        expect(PreconSafeCast.float({'price': 10}), isNull);
        expect(PreconSafeCast.float([10.5]), isNull);
      });

      test('1.5 PreconSafeCast.boolean handles bool, numeric flags, string variants, collections', () {
        // Null
        expect(PreconSafeCast.boolean(null), isNull);
        expect(PreconSafeCast.boolean(null, fallback: false), isFalse);

        // Booleans
        expect(PreconSafeCast.boolean(true), isTrue);
        expect(PreconSafeCast.boolean(false), isFalse);

        // Numeric truthiness
        expect(PreconSafeCast.boolean(1), isTrue);
        expect(PreconSafeCast.boolean(0), isFalse);
        expect(PreconSafeCast.boolean(-1), isTrue);
        expect(PreconSafeCast.boolean(100), isTrue);
        expect(PreconSafeCast.boolean(0.0), isFalse);

        // Strings
        expect(PreconSafeCast.boolean('true'), isTrue);
        expect(PreconSafeCast.boolean('TRUE'), isTrue);
        expect(PreconSafeCast.boolean('  True  '), isTrue);
        expect(PreconSafeCast.boolean('1'), isTrue);
        expect(PreconSafeCast.boolean('yes'), isTrue);
        expect(PreconSafeCast.boolean('YES'), isTrue);
        expect(PreconSafeCast.boolean('foil'), isTrue);
        expect(PreconSafeCast.boolean('FOIL'), isTrue);

        expect(PreconSafeCast.boolean('false'), isFalse);
        expect(PreconSafeCast.boolean('FALSE'), isFalse);
        expect(PreconSafeCast.boolean('0'), isFalse);
        expect(PreconSafeCast.boolean('no'), isFalse);
        expect(PreconSafeCast.boolean('NO'), isFalse);
        expect(PreconSafeCast.boolean('nonfoil'), isFalse);
        expect(PreconSafeCast.boolean('NONFOIL'), isFalse);

        // Invalid strings
        expect(PreconSafeCast.boolean('maybe'), isNull);
        expect(PreconSafeCast.boolean(''), isNull);
        expect(PreconSafeCast.boolean('random', fallback: true), isTrue);

        // Collections
        expect(PreconSafeCast.boolean({'isFoil': true}), isNull);
        expect(PreconSafeCast.boolean([true]), isNull);
      });

      test('1.6 PreconSafeCast.stringMap handles non-string keys safely', () {
        expect(PreconSafeCast.stringMap(null), isNull);
        expect(PreconSafeCast.stringMap(123), isNull);
        expect(PreconSafeCast.stringMap('not a map'), isNull);
        expect(PreconSafeCast.stringMap([1, 2, 3]), isNull);
        expect(PreconSafeCast.stringMap(true), isNull);

        // Map<String, dynamic>
        final typed = <String, dynamic>{'a': 1, 'b': 'two'};
        expect(PreconSafeCast.stringMap(typed), equals(typed));

        // Generic Map with String keys
        final generic = <dynamic, dynamic>{'scryfallId': 'xyz-123'};
        final result = PreconSafeCast.stringMap(generic);
        expect(result, isNotNull);
        expect(result!['scryfallId'], equals('xyz-123'));

        // Generic Map with non-string keys safely converted to String keys
        final nonStringKeys = <dynamic, dynamic>{123: 'val', true: 'other'};
        final converted = PreconSafeCast.stringMap(nonStringKeys);
        expect(converted, isNotNull);
        expect(converted!['123'], equals('val'));
        expect(converted['true'], equals('other'));
      });

      test('1.7 PreconSafeCast.stringList handles lists of mixed types, comma strings, non-lists', () {
        // Null & Empty
        expect(PreconSafeCast.stringList(null), isEmpty);
        expect(PreconSafeCast.stringList(''), isEmpty);
        expect(PreconSafeCast.stringList('   '), isEmpty);

        // Comma-separated strings
        expect(
          PreconSafeCast.stringList('W, U, B, R, G'),
          equals(['W', 'U', 'B', 'R', 'G']),
        );
        expect(
          PreconSafeCast.stringList('foil, nonfoil, etched'),
          equals(['foil', 'nonfoil', 'etched']),
        );
        expect(
          PreconSafeCast.stringList('  single_item  '),
          equals(['single_item']),
        );
        expect(
          PreconSafeCast.stringList(',,,,'),
          isEmpty,
        );

        // Lists of mixed types
        final mixedList = [
          'W',
          '  U  ',
          123,
          4.5,
          true,
          null,
          '',
          '   ',
          {'nested': 'map'},
        ];
        final listResult = PreconSafeCast.stringList(mixedList);
        expect(listResult, contains('W'));
        expect(listResult, contains('U'));
        expect(listResult, contains('123'));
        expect(listResult, contains('4.5'));
        expect(listResult, contains('true'));
        expect(listResult, isNot(contains('')));
        expect(listResult, isNot(contains(null)));

        // Non-list, non-string
        expect(PreconSafeCast.stringList(42), isEmpty);
        expect(PreconSafeCast.stringList(true), isEmpty);
        expect(PreconSafeCast.stringList({'colors': ['W']}), isEmpty);
      });
    });

    // =========================================================================
    // SUITE 2: PreconCardDto.fromMap Extreme Malformed Primitives Injection
    // =========================================================================
    group('Suite 2: PreconCardDto.fromMap Primitive Corruption Matrix', () {
      test('2.1 Numeric deck card: all String fields passed as int/double', () {
        final corruptedCard = <String, dynamic>{
          'name': 99999,
          'count': 3.0,
          'setCode': 123,
          'number': 456,
          'finishes': 789,
          'isFoil': 1,
          'layout': 100,
          'type_line': 111,
          'image_url': 222,
          'art_crop_url': 333,
          'mana_cost': 444,
          'cmc': '5.0',
          'colors': 555,
          'price': '12.50',
          'board_zone': 666,
          'identifiers': <String, dynamic>{'scryfallId': 777},
        };

        expect(() => PreconCardDto.fromMap(corruptedCard), returnsNormally);
        final card = PreconCardDto.fromMap(corruptedCard);

        expect(card.name, equals('99999'));
        expect(card.count, equals(3));
        expect(card.setCode, equals('123'));
        expect(card.number, equals('456'));
        expect(card.isFoil, isTrue);
        expect(card.layout, equals('100'));
        expect(card.typeLine, equals('111'));
        expect(card.manaCost, equals('444'));
        expect(card.cmc, equals(5.0));
        expect(card.price, equals(12.50));
        expect(card.boardZone, equals(BoardZone.mainboard.value));
        expect(card.scryfallId, equals('777'));

        // Verify serialization does not throw
        expect(() => card.toDynamicDataMap(), returnsNormally);
        expect(() => card.toDynamicDataJson(), returnsNormally);
      });

      test('2.2 Boolean corruption: all String fields passed as booleans', () {
        final corruptedCard = <String, dynamic>{
          'name': true,
          'count': false, // fallback to 1
          'setCode': false,
          'number': true,
          'finishes': true,
          'isFoil': 'nonfoil',
          'layout': false,
          'type': true,
          'image_url': false,
          'art_crop_url': true,
          'mana_cost': false,
          'cmc': true,
          'colors': false,
          'price': true,
          'board_zone': false,
          'identifiers': false,
        };

        expect(() => PreconCardDto.fromMap(corruptedCard), returnsNormally);
        final card = PreconCardDto.fromMap(corruptedCard);

        expect(card.name, equals('true'));
        expect(card.count, equals(1)); // boolean count falls back to 1
        expect(card.setCode, equals('false'));
        expect(card.isFoil, isFalse);
        expect(card.colors, isEmpty);
        expect(card.boardZone, equals(BoardZone.mainboard.value));

        expect(() => card.toDynamicDataMap(), returnsNormally);
      });

      test('2.3 Container corruption: all primitive fields passed as Maps and Lists', () {
        final corruptedCard = <String, dynamic>{
          'name': {'nested': 'name'}, // Map triggers fallback to 'Unknown Card'
          'count': [1, 2, 3], // List triggers fallback to 1
          'setCode': ['ABC'],
          'number': {'num': 1},
          'finishes': [{'finish': 'foil'}], // List of maps
          'isFoil': {'foil': true},
          'layout': ['normal'],
          'type_line': {'type': 'Creature'},
          'image_url': {'url': 'http://image.png'},
          'art_crop_url': ['http://art.png'],
          'mana_cost': {'cost': '{1}{U}'},
          'cmc': [3.0],
          'colors': [{'c': 'U'}], // List of maps
          'price': {'usd': 1.50},
          'board_zone': ['Mainboard'],
          'dynamicData': [1, 2, 3], // non-map dynamicData
        };

        expect(() => PreconCardDto.fromMap(corruptedCard), returnsNormally);
        final card = PreconCardDto.fromMap(corruptedCard);

        expect(card.name, equals('Unknown Card'));
        expect(card.count, equals(1));
        expect(card.setCode, isNull);
        expect(card.number, isNull);
        expect(card.isFoil, isFalse);
        expect(card.layout, equals('normal'));
        expect(card.typeLine, isNull);
        expect(card.manaCost, isNull);
        expect(card.cmc, isNull);
        expect(card.price, isNull);
        expect(card.boardZone, equals(BoardZone.mainboard.value));

        expect(() => card.toDynamicDataMap(), returnsNormally);
        expect(() => card.toDynamicDataJson(), returnsNormally);
      });

      test('2.4 Extreme Null & Empty map: complete emptiness survives zero-crash', () {
        final emptyMap = <String, dynamic>{};

        expect(() => PreconCardDto.fromMap(emptyMap), returnsNormally);
        final card = PreconCardDto.fromMap(emptyMap);

        expect(card.name, equals('Unknown Card'));
        expect(card.count, equals(1));
        expect(card.scryfallId, equals(''));
        expect(card.setCode, isNull);
        expect(card.number, isNull);
        expect(card.finishes, equals(['nonfoil']));
        expect(card.isFoil, isFalse);
        expect(card.layout, equals('normal'));
        expect(card.colors, isEmpty);
        expect(card.boardZone, equals(BoardZone.mainboard.value));

        final dyn = card.toDynamicDataMap();
        expect(dyn['name'], equals('Unknown Card'));
        expect(dyn['layout'], equals('normal'));
        expect(dyn['finishes'], equals(['nonfoil']));
      });

      test('2.5 Art Series edge cases under primitive corruption', () {
        // Art Series layout with non-string identifiers and corrupted set code
        final artSeriesCard = <String, dynamic>{
          'name': 'Black Lotus (Art Card)',
          'layout': 'art_series',
          'setCode': 1234,
          'image_url': 'https://cards.scryfall.io/art_series/front/a/b/test.jpg',
          'dynamicData': jsonEncode({
            'layout': 'art_series',
            'image_uris': {'normal': 'https://cards.scryfall.io/art_series/...'},
          }),
        };

        expect(() => PreconCardDto.fromMap(artSeriesCard), returnsNormally);
        final card = PreconCardDto.fromMap(artSeriesCard);

        // Verified Requirement R5: layout must be normalized to 'normal'
        expect(card.layout, equals('normal'));
        expect(card.name, equals('Black Lotus'));
        expect(card.imageUrl, contains('api.scryfall.com/cards/named'));
        expect(card.imageUrl, isNot(contains('art_series')));

        final dyn = card.toDynamicDataMap();
        expect(dyn['layout'], equals('normal'));
        expect(dyn['image_uris']['normal'], isNot(contains('art_series')));
      });

      test('2.6 PreconCardDto.fromMap safely parses identifiers with non-String keys', () {
        final cardWithBadIdentifiers = {
          'name': 'Sol Ring',
          'identifiers': <dynamic, dynamic>{
            123: 'abc', // non-string key
            'scryfallId': 'test-uuid-123',
          },
        };

        expect(() => PreconCardDto.fromMap(cardWithBadIdentifiers), returnsNormally);
        final card = PreconCardDto.fromMap(cardWithBadIdentifiers);
        expect(card.name, equals('Sol Ring'));
        expect(card.scryfallId, equals('test-uuid-123'));
      });
    });

    // =========================================================================
    // SUITE 3: MtgjsonPreconParser Adversarial Stress Matrix
    // =========================================================================
    group('Suite 3: MtgjsonPreconParser Full Payload Ingestion Matrix', () {
      test('3.1 Completely corrupted deck with all primitive types inverted', () {
        final corruptedPayload = {
          'name': 98765,
          'type': 42,
          'format': 3.1415,
          'id': 12345,
          'releaseDate': 2024,
          'releaseYear': '2024',
          'setCode': 999,
          'description': 1234,
          'colorIdentity': [1, 2, 3],
          'tags': [100, 200],
          'estimatedPrice': '\$49.99',
          'creatorName': 555,
          'sourceType': 777,
          'cards': [
            {
              'name': 111,
              'count': '4',
              'finishes': 'foil, nonfoil',
              'colors': 'W,U',
              'cmc': '3.0',
              'price': '\$5.25',
              'isFoil': 'yes',
              'board_zone': 'Commander',
            },
            {
              'name': 222,
              'count': 2.0,
              'finishes': [1, true, null],
              'colors': [false, 42],
              'cmc': 4,
              'price': 10,
              'isCommander': 1,
            },
          ],
        };

        final jsonStr = jsonEncode(corruptedPayload);
        expect(() => MtgjsonPreconParser.parseJson(jsonStr), returnsNormally);

        final decks = MtgjsonPreconParser.parseJson(jsonStr);
        expect(decks.length, equals(1));
        final deck = decks.first;

        expect(deck.name, equals('98765'));
        expect(deck.id, equals('12345'));
        expect(deck.releaseYear, equals(2024));
        expect(deck.estimatedPrice, equals(49.99));
        expect(deck.creatorName, equals('555'));
        expect(deck.sourceType, equals('777'));
        expect(deck.tags, equals(['100', '200']));
        expect(deck.colorIdentity, equals(['1', '2', '3']));

        // Cards verified
        expect(deck.allCards.length, equals(2));
        expect(deck.totalCardCount, equals(6)); // 4 + 2

        final card1 = deck.allCards[0];
        expect(card1.name, equals('111'));
        expect(card1.count, equals(4));
        expect(card1.finishes, equals(['foil', 'nonfoil']));
        expect(card1.colors, equals(['W', 'U']));
        expect(card1.cmc, equals(3.0));
        expect(card1.price, equals(5.25));
        expect(card1.isFoil, isTrue);
        expect(card1.isCommander, isTrue);

        final card2 = deck.allCards[1];
        expect(card2.name, equals('222'));
        expect(card2.count, equals(2));
        expect(card2.finishes, contains('1'));
        expect(card2.finishes, contains('true'));
        expect(card2.isCommander, isTrue);
      });

      test('3.2 MTGJSON AllDeckFiles schema with mixed-type zones and wrappers', () {
        final mtgjsonPayload = {
          'data': {
            'name': true,
            'code': 404,
            'type': false,
            'releaseDate': '2024-05-01',
            'mainBoard': [
              {
                'name': 'Forest',
                'count': '38',
                'identifiers': {'scryfallId': 12345},
              },
              // Non-map entries in mainBoard must be safely skipped without throwing
              123,
              'invalid string',
              null,
              [1, 2],
              true,
            ],
            'commander': [
              {
                'name': 'Gwenna, Eyes of Gaea',
                'count': 1,
                'identifiers': {'scryfallId': 'gwenna-uuid'},
              },
              null, // skipped safely
            ],
            'sideBoard': 'not a list', // corrupted sideboard zone must not throw
          },
        };

        final jsonStr = jsonEncode(mtgjsonPayload);
        expect(() => MtgjsonPreconParser.parseJson(jsonStr), returnsNormally);

        final decks = MtgjsonPreconParser.parseJson(jsonStr);
        expect(decks.length, equals(1));
        final deck = decks.first;

        expect(deck.name, equals('true'));
        expect(deck.setCode, equals('404'));
        expect(deck.mainboardCards.length, equals(1));
        expect(deck.mainboardCards.first.name, equals('Forest'));
        expect(deck.mainboardCards.first.count, equals(38));
        expect(deck.mainboardCards.first.scryfallId, equals('12345'));
        expect(deck.commanderCards.length, equals(1));
        expect(deck.commanderCards.first.name, equals('Gwenna, Eyes of Gaea'));
        expect(deck.sideboardCards, isEmpty);
      });

      test('3.3 Deck without name field is recognized as single deck with fallback name', () {
        final unnamedDeck = jsonEncode({
          'code': 'C17',
          'cards': [
            {'name': 'Sol Ring', 'count': 1},
            {'name': 'Command Tower', 'count': 1},
          ],
        });

        final decks = MtgjsonPreconParser.parseJson(unnamedDeck);
        expect(decks.length, equals(1));
        final deck = decks.first;
        expect(deck.name, equals('Untitled Deck'));
        expect(deck.setCode, equals('C17'));
        expect(deck.totalCardCount, equals(2));
        expect(deck.allCards.map((c) => c.name).toList(), equals(['Sol Ring', 'Command Tower']));
      });

      test('3.4 Gzip compressed bytes with malformed payload parses without crash', () {
        final corruptedPayload = {
          'name': 99999,
          'format': 123,
          'cards': [
            {'name': 888, 'count': 1}
          ]
        };
        final jsonStr = jsonEncode(corruptedPayload);
        final rawBytes = utf8.encode(jsonStr);
        final gzipBytes = gzip.encode(rawBytes);

        final decks = MtgjsonPreconParser.parseBytes(Uint8List.fromList(gzipBytes));
        expect(decks.length, equals(1));
        expect(decks.first.name, equals('99999'));
        expect(decks.first.allCards.first.name, equals('888'));
      });

      test('3.5 MtgjsonPreconParser.parseJson safely falls back on "Infinity" count without crashing', () {
        final payload = jsonEncode({
          'name': 'Infinity Deck',
          'cards': [
            {'name': 'Sol Ring', 'count': 'Infinity'}
          ]
        });

        expect(() => MtgjsonPreconParser.parseJson(payload), returnsNormally);
        final decks = MtgjsonPreconParser.parseJson(payload);
        expect(decks.length, equals(1));
        final deck = decks.first;
        expect(deck.name, equals('Infinity Deck'));
        expect(deck.allCards.length, equals(1));
        expect(deck.allCards.first.name, equals('Sol Ring'));
        expect(deck.allCards.first.count, equals(1));
      });
    });
  });
}
