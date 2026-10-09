import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/cache/countr_cached_image.dart';
import 'package:countr/features/decks/data/models/precon_deck_dto.dart';
import 'package:countr/features/decks/data/services/mtgjson_precon_parser.dart';

void main() {
  group('MTGJSON & Bundled Precon Parser Tests', () {
    // =========================================================================
    // GROUP 1: Bundled Assets Parsing (assets/decks/precons.json)
    // =========================================================================
    group('Bundled Precon Schema Ingestion', () {
      test('Parses full assets/decks/precons.json with all 12 decks', () {
        final file = File('assets/decks/precons.json');
        expect(file.existsSync(), isTrue, reason: 'precons.json must exist in assets/decks/');

        final jsonString = file.readAsStringSync();
        final precons = MtgjsonPreconParser.parseJson(jsonString);

        expect(precons.length, equals(12), reason: 'Expected exactly 12 bundled precons');

        final expectedFormats = {
          'Commander': 4,
          'Challenger': 2,
          'Starter Kit': 2,
          'Duel Decks': 2,
          'Planechase': 1,
          'Archenemy': 1,
        };

        final formatCounts = <String, int>{};
        for (final p in precons) {
          formatCounts[p.format] = (formatCounts[p.format] ?? 0) + 1;
        }

        expect(formatCounts, equals(expectedFormats));
      });

      test('Extracts complete commander and card metadata on Draconic Domination', () {
        final file = File('assets/decks/precons.json');
        final precons = MtgjsonPreconParser.parseJson(file.readAsStringSync());

        final c17 = precons.firstWhere((p) => p.id == 'precon-c17-draconic-domination');
        expect(c17.name, equals('Draconic Domination'));
        expect(c17.format, equals('Commander'));
        expect(c17.setCode, equals('C17'));
        expect(c17.releaseYear, equals(2017));
        expect(c17.colorIdentity, equals(['W', 'U', 'B', 'R', 'G']));
        expect(c17.totalCardCount, equals(100));

        // Commander check
        expect(c17.commanderCards.length, equals(1));
        final cmdr = c17.primaryCommander!;
        expect(cmdr.name, equals('The Ur-Dragon'));
        expect(cmdr.scryfallId, equals('7e78b70b-0c67-4f14-8ad7-c9f8e3f59743'));
        expect(cmdr.boardZone, equals('Commander'));
        expect(cmdr.isCommander, isTrue);
        expect(cmdr.manaCost, equals('{4}{W}{U}{B}{R}{G}'));
        expect(cmdr.cmc, equals(9.0));
        expect(cmdr.colors, equals(['W', 'U', 'B', 'R', 'G']));

        // Mainboard check
        expect(c17.mainboardCards.length, greaterThan(20));
        expect(c17.sideboardCards, isEmpty);

        final scion = c17.mainboardCards.firstWhere((c) => c.name == 'Scion of the Ur-Dragon');
        expect(scion.count, equals(1));
        expect(scion.boardZone, equals('Mainboard'));
        expect(scion.isMainboard, isTrue);
      });

      test('Extracts sideboard cards accurately on Challenger decks', () {
        final file = File('assets/decks/precons.json');
        final precons = MtgjsonPreconParser.parseJson(file.readAsStringSync());

        final monoWhite = precons.firstWhere((p) => p.id == 'precon-q06-mono-white-aggro');
        expect(monoWhite.format, equals('Challenger'));
        expect(monoWhite.sideboardCards.isNotEmpty, isTrue);

        expect(monoWhite.sideboardCards.length, equals(4));
        final totalSideboardCount =
            monoWhite.sideboardCards.fold<int>(0, (sum, c) => sum + c.count);
        expect(totalSideboardCount, equals(8),
            reason: 'Bundled Challenger deck sideboard contains 4 distinct cards totaling 8 cards');

        for (final sbCard in monoWhite.sideboardCards) {
          expect(sbCard.boardZone, equals('Sideboard'));
          expect(sbCard.isSideboard, isTrue);
        }
      });
    });

    // =========================================================================
    // GROUP 2: MTGJSON AllDeckFiles Official Schema
    // =========================================================================
    group('Official MTGJSON Schema Ingestion', () {
      test('Parses MTGJSON AllDeckFiles format with nested data envelope', () {
        final mtgjsonMap = {
          'data': {
            'name': 'Eldrazi Unbound',
            'code': 'CMM',
            'type': 'Commander',
            'releaseDate': '2023-08-04',
            'commander': [
              {
                'name': 'Zhulodok, Void Gorger',
                'count': 1,
                'uuid': 'cmm-uuid-001',
                'setCode': 'CMM',
                'number': '704',
                'finishes': ['foil'],
                'isFoil': true,
                'manaCost': '{6}',
                'manaValue': 6.0,
                'type': 'Legendary Creature — Eldrazi',
                'colors': <String>[],
                'colorIdentity': <String>[],
                'layout': 'normal',
                'identifiers': {
                  'scryfallId': 'a015461d-4214-4feb-8b06-517c4c233c57',
                  'scryfallOracleId': 'oracle-zhulodok-uuid',
                },
              }
            ],
            'mainBoard': [
              {
                'name': 'Kozilek, the Great Distortion',
                'count': 1,
                'uuid': 'cmm-uuid-002',
                'setCode': 'CMM',
                'number': '705',
                'finishes': ['nonfoil'],
                'manaCost': '{8}{C}{C}',
                'manaValue': 10.0,
                'type': 'Legendary Creature — Eldrazi',
                'colors': <String>[],
                'layout': 'normal',
                'identifiers': {
                  'scryfallId': 'kozilek-scryfall-uuid',
                },
              },
              {
                'name': 'Wastes',
                'count': 35,
                'uuid': 'cmm-uuid-wastes',
                'setCode': 'CMM',
                'number': '710',
                'finishes': ['nonfoil'],
                'type': 'Basic Land',
                'colors': <String>[],
                'identifiers': {
                  'scryfallId': 'wastes-scryfall-uuid',
                },
              }
            ],
            'sideBoard': <Map<String, dynamic>>[],
          }
        };

        final precons = MtgjsonPreconParser.parseJson(jsonEncode(mtgjsonMap));
        expect(precons.length, equals(1));

        final deck = precons.first;
        expect(deck.id, equals('precon-cmm-eldrazi-unbound'));
        expect(deck.name, equals('Eldrazi Unbound'));
        expect(deck.format, equals('Commander'));
        expect(deck.setCode, equals('CMM'));
        expect(deck.releaseDate, equals(DateTime.parse('2023-08-04')));
        expect(deck.commanderCards.length, equals(1));
        expect(deck.commanderCards.first.name, equals('Zhulodok, Void Gorger'));
        expect(deck.commanderCards.first.scryfallId, equals('a015461d-4214-4feb-8b06-517c4c233c57'));
        expect(deck.commanderCards.first.isFoil, isTrue);
        expect(deck.mainboardCards.length, equals(2));
        expect(deck.totalCardCount, equals(37));
      });

      test('Parses multi-deck dictionary grouped by set code', () {
        final groupedJson = {
          'data': {
            'C17': {
              'decks': [
                {
                  'name': 'Draconic Domination',
                  'code': 'C17',
                  'type': 'Commander',
                  'mainBoard': [
                    {'name': 'Sol Ring', 'count': 1, 'identifiers': {'scryfallId': 'sol-ring-id'}}
                  ]
                },
                {
                  'name': 'Feline Ferocity',
                  'code': 'C17',
                  'type': 'Commander',
                  'mainBoard': [
                    {'name': 'Sol Ring', 'count': 1, 'identifiers': {'scryfallId': 'sol-ring-id'}}
                  ]
                }
              ]
            }
          }
        };

        final precons = MtgjsonPreconParser.parseJson(jsonEncode(groupedJson));
        expect(precons.length, equals(2));
        expect(precons[0].name, equals('Draconic Domination'));
        expect(precons[1].name, equals('Feline Ferocity'));
      });
    });

    // =========================================================================
    // GROUP 3: Gzip Byte Stream Ingestion
    // =========================================================================
    group('Gzip Stream Decompression', () {
      test('Decompresses and parses gzipped JSON byte stream transparently', () {
        final sampleDeck = [
          {
            'id': 'precon-test-deck',
            'name': 'Gzip Test Deck',
            'format': 'Commander',
            'cards': [
              {
                'name': 'Arcane Signet',
                'scryfallId': 'arcane-signet-uuid',
                'count': 1,
                'board_zone': 'Mainboard',
              }
            ]
          }
        ];

        final rawJson = jsonEncode(sampleDeck);
        final uncompressedBytes = Uint8List.fromList(utf8.encode(rawJson));
        final compressedBytes = Uint8List.fromList(gzip.encode(uncompressedBytes));

        // Verify magic bytes
        expect(compressedBytes[0], equals(0x1F));
        expect(compressedBytes[1], equals(0x8B));

        // Ingest compressed bytes
        final parsed = MtgjsonPreconParser.parseBytes(compressedBytes);
        expect(parsed.length, equals(1));
        expect(parsed.first.id, equals('precon-test-deck'));
        expect(parsed.first.name, equals('Gzip Test Deck'));
        expect(parsed.first.mainboardCards.first.name, equals('Arcane Signet'));

        // Ingest uncompressed bytes
        final parsedUncompressed = MtgjsonPreconParser.parseBytes(uncompressedBytes);
        expect(parsedUncompressed.length, equals(1));
        expect(parsedUncompressed.first.name, equals('Gzip Test Deck'));
      });
    });

    // =========================================================================
    // GROUP 4: Strict Art Series Exclusion (Requirement R5)
    // =========================================================================
    group('Art Series Non-Playable Card Filtering', () {
      test('Replaces art_series layout with normal and falls back to named normal CDN url', () {
        final artCardMap = {
          'name': 'Black Lotus',
          'scryfall_id': 'art-series-lotus-uuid',
          'count': 1,
          'board_zone': 'Mainboard',
          'layout': 'art_series',
          'type_line': 'Card // Art Series',
          'image_url': 'https://cards.scryfall.io/art_crop/front/a/r/art-series.jpg',
        };

        final card = PreconCardDto.fromMap(artCardMap);

        expect(card.layout, equals('normal'), reason: 'art_series must be converted to normal layout');
        expect(
          card.imageUrl,
          equals(CountrCachedImage.buildScryfallNamedUrl('Black Lotus', version: 'normal')),
          reason: 'Art card must fall back to playable standard Scryfall named normal redirect',
        );
        expect(
          card.artCropUrl,
          equals(CountrCachedImage.buildScryfallNamedUrl('Black Lotus', version: 'art_crop')),
        );

        final dynamicData = card.toDynamicDataMap();
        expect(dynamicData['layout'], equals('normal'));
      });
    });

    // =========================================================================
    // GROUP 5: Normalization & Deterministic IDs
    // =========================================================================
    group('Normalization & Deterministic IDs', () {
      test('Normalizes various format string representations', () {
        expect(MtgjsonPreconParser.normalizeFormat('Commander'), equals('Commander'));
        expect(MtgjsonPreconParser.normalizeFormat('commander deck'), equals('Commander'));
        expect(MtgjsonPreconParser.normalizeFormat('EDH'), equals('Commander'));
        expect(MtgjsonPreconParser.normalizeFormat('Challenger Decks'), equals('Challenger'));
        expect(MtgjsonPreconParser.normalizeFormat('Arena Starter Kit'), equals('Starter Kit'));
        expect(MtgjsonPreconParser.normalizeFormat('Duel Decks'), equals('Duel Decks'));
        expect(MtgjsonPreconParser.normalizeFormat('Planechase'), equals('Planechase'));
        expect(MtgjsonPreconParser.normalizeFormat('Archenemy'), equals('Archenemy'));
      });

      test('Builds deterministic deck IDs', () {
        expect(
          MtgjsonPreconParser.buildDeterministicDeckId(
            setCode: 'C17',
            name: 'Draconic Domination',
          ),
          equals('precon-c17-draconic-domination'),
        );

        expect(
          MtgjsonPreconParser.buildDeterministicDeckId(
            setCode: null,
            name: 'Atraxa, Praetors\' Voice (Custom!)',
          ),
          equals('precon-mtg-atraxa-praetors-voice-custom'),
        );
      });
    });
  });
}
