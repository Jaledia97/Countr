import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/core/cache/countr_cached_image.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/data/models/precon_deck_dto.dart';
import 'package:countr/features/decks/data/services/fallback_explore_seeds.dart';
import 'package:countr/features/decks/data/services/mtgjson_precon_parser.dart';
import 'package:countr/features/decks/data/services/precon_hydration_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Challenger M1-2: MTGJSON Precon Parser & Hydration Stress Tests', () {
    // =========================================================================
    // GROUP 1: Malformed & Boundary JSON Payloads
    // =========================================================================
    group('1. Malformed & Boundary JSON Payloads', () {
      test('1.1 Empty strings and whitespace-only payloads return empty list', () {
        expect(MtgjsonPreconParser.parseJson(''), isEmpty);
        expect(MtgjsonPreconParser.parseJson('   '), isEmpty);
        expect(MtgjsonPreconParser.parseJson('\n\t\r'), isEmpty);
      });

      test('1.2 Empty JSON array and empty JSON object return empty list', () {
        expect(MtgjsonPreconParser.parseJson('[]'), isEmpty);
        expect(MtgjsonPreconParser.parseJson('{}'), isEmpty);
      });

      test('1.3 Non-collection root JSON primitives return empty list without throwing', () {
        expect(MtgjsonPreconParser.parseJson('123'), isEmpty);
        expect(MtgjsonPreconParser.parseJson('true'), isEmpty);
        expect(MtgjsonPreconParser.parseJson('false'), isEmpty);
        expect(MtgjsonPreconParser.parseJson('"just a string"'), isEmpty);
        expect(MtgjsonPreconParser.parseJson('null'), isEmpty);
      });

      test('1.4 Syntactically invalid JSON throws FormatException cleanly', () {
        expect(() => MtgjsonPreconParser.parseJson('{not valid json'), throwsFormatException);
        expect(() => MtgjsonPreconParser.parseJson('{"name": "broken", [}'), throwsFormatException);
        expect(() => MtgjsonPreconParser.parseJson('[{"incomplete":'), throwsFormatException);
      });

      test('1.5 Envelope variations: data null, decks non-list, empty nested dictionaries', () {
        expect(MtgjsonPreconParser.parseJson('{"data": null}'), isEmpty);
        expect(MtgjsonPreconParser.parseJson('{"data": []}'), isEmpty);
        expect(MtgjsonPreconParser.parseJson('{"data": {}}'), isEmpty);
        expect(MtgjsonPreconParser.parseJson('{"decks": null}'), isEmpty);
        expect(MtgjsonPreconParser.parseJson('{"decks": "not a list"}'), isEmpty);
        expect(MtgjsonPreconParser.parseJson('{"a": {"b": {"c": {}}}}'), isEmpty);
      });

      test('1.6 List containing mixed non-map types filters safely without crashing', () {
        final mixedJson = jsonEncode([
          123,
          'not a deck',
          null,
          true,
          {
            'name': 'Valid Deck in Mixed List',
            'format': 'Commander',
            'cards': [
              {'name': 'Sol Ring', 'scryfallId': 'sol-uuid', 'count': 1}
            ]
          },
          ['nested list']
        ]);

        final precons = MtgjsonPreconParser.parseJson(mixedJson);
        expect(precons.length, equals(1));
        expect(precons.first.name, equals('Valid Deck in Mixed List'));
      });

      test('1.7 Non-string primitive fields in deck map parse cleanly without TypeError', () {
        final numericFieldsDeck = {
          'name': 12345,
          'cards': [
            {'name': 'Sol Ring', 'scryfallId': 'sol-id', 'count': 1}
          ]
        };

        final deck = MtgjsonPreconParser.parseDeck(numericFieldsDeck);
        expect(deck.name, equals('12345'));
        expect(deck.allCards.length, equals(1));
        expect(deck.allCards.first.name, equals('Sol Ring'));
      });
    });

    // =========================================================================
    // GROUP 2: Missing Zones, Missing Fields & Zero-Quantity Cards
    // =========================================================================
    group('2. Missing Zones, Missing Fields & Zero-Quantity Cards', () {
      test('2.1 Deck with missing commander zone parses and seeds with null coverItemId', () async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(() => db.close());

        final deckJson = {
          'name': 'Pauper Burn (No Commander)',
          'type': 'Pauper',
          'code': 'PPR',
          'mainBoard': [
            {'name': 'Lightning Bolt', 'count': 4, 'identifiers': {'scryfallId': 'bolt-uuid'}},
            {'name': 'Mountain', 'count': 20, 'identifiers': {'scryfallId': 'mountain-uuid'}},
          ],
        };

        final precons = MtgjsonPreconParser.parseJson(jsonEncode(deckJson));
        expect(precons.length, equals(1));
        final precon = precons.first;

        expect(precon.commanderCards, isEmpty);
        expect(precon.primaryCommander, isNull);
        expect(precon.sideboardCards, isEmpty);
        expect(precon.totalCardCount, equals(24));

        // Seed into SQLite
        await PreconHydrationService.seedHistoricalPrecons(
          db,
          force: true,
          customPrecons: precons,
        );

        final seededDeck = await (db.select(db.decks)..where((d) => d.id.equals(precon.id))).getSingle();
        expect(seededDeck.coverItemId, isNull, reason: 'Decks with no commander must have null coverItemId');
        expect(seededDeck.format, equals('Pauper'));

        final seededItems = await (db.select(db.deckVersionItems)
              ..where((i) => i.versionId.equals('${precon.id}-v1')))
            .get();
        expect(seededItems.length, equals(2));
        expect(seededItems.every((i) => i.boardZone == 'Mainboard'), isTrue);
      });

      test('2.2 Deck with missing sideboard zone parses cleanly with empty sideboardCards', () {
        final deckJson = {
          'name': 'Mainboard Only Starter',
          'format': 'Standard',
          'code': 'STA',
          'mainBoard': [
            {'name': 'Plains', 'count': 60, 'identifiers': {'scryfallId': 'plains-uuid'}},
          ],
        };

        final precons = MtgjsonPreconParser.parseJson(jsonEncode(deckJson));
        expect(precons.first.sideboardCards, isEmpty);
        expect(precons.first.mainboardCards.length, equals(1));
      });

      test('2.3 Deck with 0-quantity cards in mainboard and sideboard', () async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(() => db.close());

        final deckJson = {
          'name': 'Zero Quantity Stress Deck',
          'format': 'Modern',
          'code': 'ZER',
          'mainBoard': [
            {'name': 'Zero Count Card', 'count': 0, 'identifiers': {'scryfallId': 'zero-card-uuid'}},
            {'name': 'Normal Card', 'count': 4, 'identifiers': {'scryfallId': 'normal-card-uuid'}},
          ],
          'sideBoard': [
            {'name': 'Zero Sideboard Card', 'count': 0, 'identifiers': {'scryfallId': 'zero-sb-uuid'}},
          ]
        };

        final precons = MtgjsonPreconParser.parseJson(jsonEncode(deckJson));
        final deck = precons.first;

        // Card with count 0
        final zeroCard = deck.mainboardCards.firstWhere((c) => c.name == 'Zero Count Card');
        expect(zeroCard.count, equals(0));

        // totalCardCount should only sum 4 (0 + 4 + 0)
        expect(deck.totalCardCount, equals(4));

        // Seed to SQLite and verify no DB constraint violation
        await PreconHydrationService.seedHistoricalPrecons(
          db,
          force: true,
          customPrecons: precons,
        );

        final items = await (db.select(db.deckVersionItems)
              ..where((i) => i.versionId.equals('${deck.id}-v1')))
            .get();
        expect(items.length, equals(3));
        final zeroItem = items.firstWhere((i) => i.vaultItemId == 'zero-card-uuid');
        expect(zeroItem.quantity, equals(0));
      });

      test('2.4 Card with missing scryfallId, name, and setCode uses safe fallbacks without crash', () {
        final minimalCard = <String, dynamic>{};
        final card = PreconCardDto.fromMap(minimalCard);

        expect(card.name, equals('Unknown Card'));
        expect(card.scryfallId, equals(''));
        expect(card.count, equals(1));
        expect(card.layout, equals('normal'));
        expect(card.imageUrl, isNull);
        expect(card.artCropUrl, isNull);
        expect(card.boardZone, equals('Mainboard'));

        final dynamicData = card.toDynamicDataMap();
        expect(dynamicData['name'], equals('Unknown Card'));
        expect(dynamicData['scryfall_id'], equals(''));
      });
    });

    // =========================================================================
    // GROUP 3: Format Strings, Set Codes & Special Characters
    // =========================================================================
    group('3. Format Strings, Set Codes & Special Characters', () {
      test('3.1 Unknown format strings preserve capitalized/trimmed representation without crashing', () {
        expect(MtgjsonPreconParser.normalizeFormat('Tiny Leaders'), equals('Tiny Leaders'));
        expect(MtgjsonPreconParser.normalizeFormat('Oathbreaker'), equals('Oathbreaker'));
        expect(MtgjsonPreconParser.normalizeFormat('Custom Cube 2026'), equals('Custom Cube 2026'));
        expect(MtgjsonPreconParser.normalizeFormat('12345'), equals('12345'));
        expect(MtgjsonPreconParser.normalizeFormat('!@#\$%^&*()'), equals('!@#\$%^&*()'));
        expect(MtgjsonPreconParser.normalizeFormat(null), equals('Commander'));
        expect(MtgjsonPreconParser.normalizeFormat(''), equals('Commander'));
        expect(MtgjsonPreconParser.normalizeFormat('   '), equals('Commander'));
      });

      test('3.2 Format normalization is case-insensitive and trims whitespace', () {
        expect(MtgjsonPreconParser.normalizeFormat('  cOmMaNdEr   '), equals('Commander'));
        expect(MtgjsonPreconParser.normalizeFormat('  brawl  '), equals('Commander'));
        expect(MtgjsonPreconParser.normalizeFormat('  CHALLENGER DECK  '), equals('Challenger'));
        expect(MtgjsonPreconParser.normalizeFormat('  arena starter kit  '), equals('Starter Kit'));
        expect(MtgjsonPreconParser.normalizeFormat('  DUEL DECKS  '), equals('Duel Decks'));
        expect(MtgjsonPreconParser.normalizeFormat('  planechase 2012  '), equals('Planechase'));
        expect(MtgjsonPreconParser.normalizeFormat('  archenemy: nicol bolas  '), equals('Archenemy'));
      });

      test('3.3 Deck names with quotes, slashes, and complex punctuation produce valid slug IDs', () {
        final id1 = MtgjsonPreconParser.buildDeterministicDeckId(
          setCode: 'NEO',
          name: 'Satoru\'s "Ninja-Strike" / Shadow & Smoke [v2.0]',
        );
        expect(id1, equals('precon-neo-satoru-s-ninja-strike-shadow-smoke-v2-0'));

        final id2 = MtgjsonPreconParser.buildDeterministicDeckId(
          setCode: null,
          name: '---Leading-and-Trailing-Dashes---',
        );
        expect(id2, equals('precon-mtg-leading-and-trailing-dashes'));
      });

      test('3.4 CJK Unicode or pure emoji deck names produce fallback slug', () {
        final cjkId = MtgjsonPreconParser.buildDeterministicDeckId(
          setCode: 'WAR',
          name: '青白コントロール',
        );
        expect(cjkId, startsWith('precon-war-deck-'));
        expect(cjkId, isNot(equals('precon-war-')));

        final emojiId = MtgjsonPreconParser.buildDeterministicDeckId(
          setCode: 'DOM',
          name: '🔥 Red Deck Wins ⚡',
        );
        expect(emojiId, equals('precon-dom-red-deck-wins'));
      });
    });

    // =========================================================================
    // GROUP 4: Byte Stream & Gzip Decompression Stress
    // =========================================================================
    group('4. Byte Stream & Gzip Decompression Stress', () {
      test('4.1 Empty byte buffer returns empty list', () {
        expect(MtgjsonPreconParser.parseBytes(Uint8List(0)), isEmpty);
      });

      test('4.2 Truncated gzip header behavior', () {
        // Sub-10-byte incomplete header without payload returns empty list gracefully
        final magicOnly = Uint8List.fromList([0x1F, 0x8B]);
        expect(MtgjsonPreconParser.parseBytes(magicOnly), isEmpty);

        final sixBytes = Uint8List.fromList([0x1F, 0x8B, 0x08, 0x00, 0x00, 0x00]);
        expect(MtgjsonPreconParser.parseBytes(sixBytes), isEmpty);

        final elevenBytes = Uint8List.fromList([
          0x1F, 0x8B, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x12,
        ]);
        expect(MtgjsonPreconParser.parseBytes(elevenBytes), isEmpty);
      });

      test('4.3 Corrupted gzip stream throws exception', () {
        // Gzip header followed by random garbage
        final corruptedStream = Uint8List.fromList([
          0x1F, 0x8B, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03,
          0xFF, 0xFE, 0xFD, 0xFC, 0xFB, 0xFA, 0x00, 0x11, 0x22, 0x33,
        ]);

        expect(
          () => MtgjsonPreconParser.parseBytes(corruptedStream),
          throwsA(anyOf(isA<FormatException>(), isA<Exception>())),
        );
      });

      test('4.4 Non-gzipped invalid UTF-8 bytes throws FormatException', () {
        // Invalid UTF-8 sequence
        final invalidUtf8 = Uint8List.fromList([0xC0, 0xAF, 0xFF, 0xFE]);
        expect(
          () => MtgjsonPreconParser.parseBytes(invalidUtf8),
          throwsFormatException,
        );
      });

      test('4.5 PreconHydrationService.loadAndParseBundledPrecons falls back safely on corrupted asset', () async {
        // Create temporary corrupt file to simulate a damaged precons.json
        final tempDir = await Directory.systemTemp.createTemp('precon_corrupt_test_');
        final corruptFile = File('${tempDir.path}/corrupt_precons.json');
        await corruptFile.writeAsBytes([0x1F, 0x8B, 0x99, 0x88, 0x77]);

        try {
          final result = await PreconHydrationService.loadAndParseBundledPrecons(
            assetPath: corruptFile.path,
          );

          // Must NOT crash; must fall back to FallbackExploreSeeds
          expect(result.isNotEmpty, isTrue);
          expect(result.length, equals(FallbackExploreSeeds.preconSeeds.length));
        } finally {
          await tempDir.delete(recursive: true);
        }
      });
    });

    // =========================================================================
    // GROUP 5: Art Series Layout Filtering & Double-Faced Normalization (R5)
    // =========================================================================
    group('5. Art Series Layout Filtering & Double-Faced Normalization', () {
      test('5.1 Explicit art_series card layout is converted to normal and URLs normalized', () {
        final artCard = {
          'name': 'The Meathook Massacre',
          'scryfall_id': 'art-series-meathook-uuid',
          'layout': 'art_series',
          'type_line': 'Card // Art Series',
          'image_url': 'https://cards.scryfall.io/art_series/front/m/e/art_meathook.jpg',
          'art_crop_url': 'https://cards.scryfall.io/art_series/crop/m/e/art_meathook_crop.jpg',
        };

        final parsed = PreconCardDto.fromMap(artCard);

        expect(parsed.layout, equals('normal'), reason: 'art_series layout must normalize to normal');
        expect(
          parsed.imageUrl,
          equals(CountrCachedImage.buildScryfallNamedUrl('The Meathook Massacre', version: 'normal')),
        );
        expect(
          parsed.artCropUrl,
          equals(CountrCachedImage.buildScryfallNamedUrl('The Meathook Massacre', version: 'art_crop')),
        );
        expect(parsed.imageUrl!.contains('art_series'), isFalse,
            reason: 'imageUrl must never contain art_series path');
        expect(parsed.artCropUrl!.contains('art_series'), isFalse,
            reason: 'artCropUrl must never contain art_series path');
      });

      test('5.2 Double-faced card with Art Series suffix in name extracts clean front card name', () {
        final dfcArtCard = {
          'name': 'Arlinn, the Pack\'s Hope // Arlinn Art Series Card',
          'scryfall_id': 'dfc-art-uuid-1',
          'layout': 'art_series',
          'type_line': 'Card // Art Series',
          'image_url': 'https://cards.scryfall.io/art_series/front/a/r/arlinn.jpg',
        };

        final parsed = PreconCardDto.fromMap(dfcArtCard);

        expect(parsed.layout, equals('normal'));
        expect(
          parsed.imageUrl,
          equals(CountrCachedImage.buildScryfallNamedUrl('Arlinn, the Pack\'s Hope', version: 'normal')),
        );
        expect(parsed.imageUrl!.contains('exact=Arlinn%2C%20the%20Pack\'s%20Hope'), isTrue,
            reason: 'Named Scryfall URL must isolate the front face name before //');
      });

      test('5.3 Art series card inside seeded precon maps to vault_items with playable CDN url', () async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(() => db.close());

        final preconPayload = {
          'name': 'Midnight Hunt Precon with Art Card',
          'format': 'Commander',
          'code': 'MID',
          'commander': {
            'name': 'Sigarda, Champion of Light',
            'scryfallId': 'sigarda-cmdr-uuid',
            'layout': 'normal',
          },
          'mainBoard': [
            {
              'name': 'Lier, Disciple of the Drowned',
              'scryfallId': 'lier-art-card-uuid',
              'count': 1,
              'layout': 'art_series',
              'type_line': 'Card // Art Series',
              'image_url': 'https://cards.scryfall.io/art_series/front/l/i/lier.jpg',
            }
          ]
        };

        final precons = MtgjsonPreconParser.parseJson(jsonEncode(preconPayload));
        await PreconHydrationService.seedHistoricalPrecons(
          db,
          force: true,
          customPrecons: precons,
        );

        final lierVaultItem = await (db.select(db.vaultItems)
              ..where((v) => v.id.equals('lier-art-card-uuid')))
            .getSingle();

        expect(lierVaultItem.imageUrl.contains('art_series'), isFalse,
            reason: 'vault_items.imageUrl must never contain art_series');
        expect(
          lierVaultItem.imageUrl,
          equals(CountrCachedImage.buildScryfallNamedUrl('Lier, Disciple of the Drowned', version: 'normal')),
        );

        // Verify dynamicData
        final dynData = jsonDecode(lierVaultItem.dynamicData) as Map<String, dynamic>;
        expect(dynData['layout'], equals('normal'),
            reason: 'dynamicData layout must be normalized to normal');
      });

      test('5.4 Dynamic data leakage test: Pre-populated art_series dynamicData layout and image_uris are sanitized', () {
        final leakedArtCard = {
          'name': 'Ragavan, Nimble Pilferer',
          'scryfall_id': 'ragavan-art-uuid',
          'layout': 'art_series',
          'dynamicData': {
            'layout': 'art_series',
            'image_uris': {
              'normal': 'https://cards.scryfall.io/art_series/front/r/a/ragavan.jpg',
              'art_crop': 'https://cards.scryfall.io/art_series/crop/r/a/ragavan_crop.jpg',
            }
          }
        };

        final parsed = PreconCardDto.fromMap(leakedArtCard);
        final dynamicMap = parsed.toDynamicDataMap();

        final dynLayout = dynamicMap['layout'];
        final dynImageUris = dynamicMap['image_uris'] as Map<String, dynamic>?;

        expect(parsed.layout, equals('normal'), reason: 'PreconCardDto.layout is normal');
        expect(parsed.imageUrl!.contains('art_series'), isFalse);

        expect(dynLayout, equals('normal'),
            reason: 'dynamicData layout must be sanitized to normal');
        expect(dynImageUris!['normal'].toString().contains('art_series'), isFalse,
            reason: 'dynamicData image URIs must never leak art_series URLs');
        expect(dynImageUris['normal'], equals(parsed.imageUrl));
      });

      test('5.5 Type line "Art Card" or "Double-Faced Art Card" detection', () {
        final artCardWithoutLayout = {
          'name': 'Grist, the Hunger Tide',
          'scryfall_id': 'grist-art-uuid',
          'type_line': 'Art Card',
        };

        final parsed = PreconCardDto.fromMap(artCardWithoutLayout);
        expect(parsed.layout, equals('normal'));
        expect(parsed.imageUrl?.contains('api.scryfall.com'), isTrue,
            reason: 'Art card with type_line "Art Card" must normalize to Scryfall named playable URL');
        expect(
          parsed.imageUrl,
          equals(CountrCachedImage.buildScryfallNamedUrl('Grist, the Hunger Tide', version: 'normal')),
        );
      });

      test('5.6 Art Series set code starting with A (e.g. AMH2) without explicit layout', () {
        final artSeriesSetCard = {
          'name': 'Dauthi Voidwalker',
          'scryfall_id': 'dauthi-art-uuid',
          'setCode': 'AMH2',
          'type_line': 'Card',
        };

        final parsed = PreconCardDto.fromMap(artSeriesSetCard);
        expect(parsed.layout, equals('normal'));
        expect(parsed.imageUrl?.contains('api.scryfall.com'), isTrue,
            reason: 'Art card with setCode AMH2 must normalize to Scryfall named playable URL');
        expect(
          parsed.imageUrl,
          equals(CountrCachedImage.buildScryfallNamedUrl('Dauthi Voidwalker', version: 'normal')),
        );
      });
    });

    // =========================================================================
    // GROUP 6: Concurrency & Database Idempotency Stress
    // =========================================================================
    group('6. Concurrency & Database Idempotency Stress', () {
      test('6.1 Concurrent simultaneous seedHistoricalPrecons calls do not collide or fail', () async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(() => db.close());

        // Launch two concurrent seedings simultaneously
        final future1 = PreconHydrationService.seedHistoricalPrecons(db, force: true);
        final future2 = PreconHydrationService.seedHistoricalPrecons(db, force: true);

        await Future.wait([future1, future2]);

        final preconDecks = await (db.select(db.decks)..where((t) => t.id.like('precon-%'))).get();
        expect(preconDecks.length, equals(12),
            reason: 'Concurrent seeding must produce exactly 12 precon decks without duplicating');
      });

      test('6.2 Multiple decks with same slug but different set codes get distinct IDs', () {
        final idC17 = MtgjsonPreconParser.buildDeterministicDeckId(
          setCode: 'C17',
          name: 'Draconic Domination',
        );
        final idC19 = MtgjsonPreconParser.buildDeterministicDeckId(
          setCode: 'C19',
          name: 'Draconic Domination',
        );

        expect(idC17, isNot(equals(idC19)));
        expect(idC17, equals('precon-c17-draconic-domination'));
        expect(idC19, equals('precon-c19-draconic-domination'));
      });
    });
  });
}
