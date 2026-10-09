import 'dart:convert';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/core/cache/countr_cached_image.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/data/models/precon_deck_dto.dart';
import 'package:countr/features/decks/data/services/mtgjson_precon_parser.dart';
import 'package:countr/features/decks/data/services/precon_hydration_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Challenger M1-R2-1: Adversarial Verification of Art Series Elimination & Non-Latin Slugs', () {
    // =========================================================================
    // SECTION 1: Adversarial dynamicData Sanitization & Art Series Elimination
    // =========================================================================
    group('1. Art Series Leakage Elimination & dynamicData Deep Sanitization', () {
      test('1.1 Card with layout=="art_series" and nested dynamicData art URLs completely sanitized in SQLite', () async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(() => db.close());

        final preconPayload = {
          'name': 'Art Series Sanitization Stress Deck',
          'format': 'Commander',
          'code': 'NEO',
          'mainBoard': [
            {
              'name': 'The Wandering Emperor',
              'scryfall_id': 'wandering-emperor-art-uuid',
              'layout': 'art_series',
              'type_line': 'Card // Art Series',
              'image_url': 'https://cards.scryfall.io/art_series/front/w/e/wandering_emperor.jpg',
              'art_crop_url': 'https://cards.scryfall.io/art_series/crop/w/e/wandering_emperor_crop.jpg',
              'dynamicData': {
                'layout': 'art_series',
                'image_uris': {
                  'small': 'https://cards.scryfall.io/art_series/small/front/w/e/wandering_emperor.jpg',
                  'normal': 'https://cards.scryfall.io/art_series/normal/front/w/e/wandering_emperor.jpg',
                  'large': 'https://cards.scryfall.io/art_series/large/front/w/e/wandering_emperor.jpg',
                  'art_crop': 'https://cards.scryfall.io/art_series/crop/w/e/wandering_emperor_crop.jpg',
                  'border_crop': 'https://cards.scryfall.io/art_series/border/front/w/e/wandering_emperor.jpg',
                },
                'card_faces': [
                  {
                    'name': 'The Wandering Emperor Art Card',
                    'image_uris': {
                      'normal': 'https://cards.scryfall.io/art_series/normal/front/w/e/wandering_emperor.jpg'
                    }
                  }
                ]
              }
            }
          ]
        };

        final precons = MtgjsonPreconParser.parseJson(jsonEncode(preconPayload));
        expect(precons.length, equals(1));

        await PreconHydrationService.seedHistoricalPrecons(
          db,
          force: true,
          customPrecons: precons,
        );

        final vaultItem = await (db.select(db.vaultItems)
              ..where((v) => v.id.equals('wandering-emperor-art-uuid')))
            .getSingle();

        // 1. Check top-level vault_items.imageUrl
        expect(vaultItem.imageUrl.contains('art_series'), isFalse,
            reason: 'vault_items.imageUrl must never contain art_series');
        expect(
          vaultItem.imageUrl,
          equals(CountrCachedImage.buildScryfallNamedUrl('The Wandering Emperor', version: 'normal')),
        );

        // 2. Adversarially verify raw serialized dynamicData string contains ZERO art_series references
        expect(vaultItem.dynamicData.contains('art_series'), isFalse,
            reason: 'vault_items.dynamicData string must contain zero art_series occurrences');

        // 3. Inspect deserialized JSON fields
        final dynamicMap = jsonDecode(vaultItem.dynamicData) as Map<String, dynamic>;
        expect(dynamicMap['layout'], equals('normal'),
            reason: 'dynamicData layout must be sanitized to normal');

        final imageUris = dynamicMap['image_uris'] as Map<String, dynamic>;
        for (final entry in imageUris.entries) {
          expect(entry.value.toString().contains('art_series'), isFalse,
              reason: 'image_uris["${entry.key}"] must not contain art_series');
        }
        expect(imageUris['normal'], equals(vaultItem.imageUrl));

        // card_faces containing art_series must be purged
        expect(dynamicMap.containsKey('card_faces'), isFalse,
            reason: 'card_faces with art_series assets must be removed');
      });

      test('1.2 Card with type_line variants ("Art Card", "Double-Faced Art Card", "Art Series") sanitized', () async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(() => db.close());

        final preconPayload = {
          'name': 'TypeLine Art Variants Deck',
          'format': 'Commander',
          'code': 'MH2',
          'mainBoard': [
            {
              'name': 'Grief (Art Card)',
              'scryfall_id': 'grief-art-card-id',
              'type_line': 'Art Card',
              'dynamicData': {
                'layout': 'art_series',
                'image_uris': {
                  'normal': 'https://cards.scryfall.io/art_series/front/g/r/grief.jpg'
                }
              }
            },
            {
              'name': 'Dauthi Voidwalker // Art Card',
              'scryfall_id': 'dauthi-dfc-art-id',
              'type_line': 'Double-Faced Art Card',
              'dynamicData': {
                'layout': 'art_series',
                'image_uris': {
                  'normal': 'https://cards.scryfall.io/art_series/front/d/a/dauthi.jpg'
                }
              }
            },
            {
              'name': 'Subtlety - Art Series',
              'scryfall_id': 'subtlety-art-id',
              'type_line': 'Card // Art Series',
              'dynamicData': {
                'layout': 'art_series',
                'image_uris': {
                  'normal': 'https://cards.scryfall.io/art_series/front/s/u/subtlety.jpg'
                }
              }
            }
          ]
        };

        final precons = MtgjsonPreconParser.parseJson(jsonEncode(preconPayload));
        await PreconHydrationService.seedHistoricalPrecons(
          db,
          force: true,
          customPrecons: precons,
        );

        final items = await (db.select(db.vaultItems)
              ..where((v) => v.id.isIn(['grief-art-card-id', 'dauthi-dfc-art-id', 'subtlety-art-id'])))
            .get();

        expect(items.length, equals(3));
        for (final item in items) {
          expect(item.imageUrl.contains('art_series'), isFalse);
          expect(item.dynamicData.contains('art_series'), isFalse,
              reason: 'DynamicData must not contain art_series for card ${item.name}');

          final dyn = jsonDecode(item.dynamicData) as Map<String, dynamic>;
          expect(dyn['layout'], equals('normal'));
        }

        // Check clean name extraction
        final grief = items.firstWhere((i) => i.id == 'grief-art-card-id');
        expect(grief.name, equals('Grief'));
        expect(grief.imageUrl, equals(CountrCachedImage.buildScryfallNamedUrl('Grief', version: 'normal')));

        final dauthi = items.firstWhere((i) => i.id == 'dauthi-dfc-art-id');
        expect(dauthi.name, equals('Dauthi Voidwalker'));
        expect(dauthi.imageUrl, equals(CountrCachedImage.buildScryfallNamedUrl('Dauthi Voidwalker', version: 'normal')));

        final subtlety = items.firstWhere((i) => i.id == 'subtlety-art-id');
        expect(subtlety.name, equals('Subtlety'));
        expect(subtlety.imageUrl, equals(CountrCachedImage.buildScryfallNamedUrl('Subtlety', version: 'normal')));
      });

      test('1.3 Set codes starting with "A" (4+ char art series sets vs 3-char playable sets)', () {
        // Art Series sets: AMH1, AMH2, AAFR, ASTX, AMID, AVOW, ANEO, AONE
        final artCards = [
          {'name': 'Urza, Lord High Artificer', 'scryfall_id': 'urza-art', 'setCode': 'AMH1'},
          {'name': 'Ragavan, Nimble Pilferer', 'scryfall_id': 'ragavan-art', 'setCode': 'AMH2'},
          {'name': 'Tiamat', 'scryfall_id': 'tiamat-art', 'setCode': 'AAFR'},
          {'name': 'Galazeth Prismari', 'scryfall_id': 'galazeth-art', 'setCode': 'ASTX'},
          {'name': 'Elesh Norn, Mother of Machines', 'scryfall_id': 'elesh-art', 'setCode': 'AONE'},
        ];

        for (final c in artCards) {
          final parsed = PreconCardDto.fromMap(c);
          expect(parsed.layout, equals('normal'), reason: 'Set ${c['setCode']} must normalize layout to normal');
          expect(parsed.imageUrl!.contains('api.scryfall.com'), isTrue,
              reason: 'Set ${c['setCode']} must resolve named playable Scryfall URL');
          expect(parsed.toDynamicDataMap()['layout'], equals('normal'));
        }

        // Standard playable 3-char sets starting with 'A': AKH (Amonkhet), AER (Aether Revolt), AFR (Forgotten Realms), ARN (Arabian Nights)
        final playableCards = [
          {'name': 'Anointed Procession', 'scryfall_id': 'proc-akh-uuid', 'setCode': 'AKH'},
          {'name': 'Fatal Push', 'scryfall_id': 'push-aer-uuid', 'setCode': 'AER'},
          {'name': 'Old Gnawbone', 'scryfall_id': 'gnaw-afr-uuid', 'setCode': 'AFR'},
          {'name': 'Juzam Djinn', 'scryfall_id': 'juzam-arn-uuid', 'setCode': 'ARN'},
        ];

        for (final c in playableCards) {
          final parsed = PreconCardDto.fromMap(c);
          expect(parsed.layout, equals('normal'));
          // Playable sets with valid scryfallId must map to standard CDN URL, NOT forced named search URL
          expect(parsed.imageUrl!.contains('/normal/front/'), isTrue,
              reason: 'Playable set ${c['setCode']} must use standard Scryfall CDN image path');
        }
      });
    });

    // =========================================================================
    // SECTION 2: Adversarial Non-Latin & Emoji Deck Slugs & SQLite Collisions
    // =========================================================================
    group('2. Non-Latin & Emoji Deck Slugs & SQLite Non-Collision Invariants', () {
      test('2.1 Non-Latin & pure emoji deck names produce deterministic, non-empty, distinct IDs', () {
        final testCases = <String, String>{
          '青白コントロール': 'precon-war-deck-d72d39e1', // Japanese Azorius Control
          '黒赤アグロ': 'precon-war-deck-59eafe16',       // Japanese Rakdos Aggro
          '緑単ストンピィ': 'precon-war-deck-9214ae8e',   // Japanese Mono-Green
          'Синий Контроль': 'precon-war-deck-b28da13e',  // Russian Blue Control
          'Черная Агро': 'precon-war-deck-a8d6b9f2',     // Russian Black Aggro
          'قوة النار': 'precon-war-deck-42f896b0',       // Arabic Fire Power
          'שליטה כחולה': 'precon-war-deck-535d72f9',     // Hebrew Blue Control
          'Έλεγχος': 'precon-war-deck-fa03e8ff',         // Greek Control
          '타락한 제국': 'precon-war-deck-201a43a0',     // Korean Fallen Empires
          '🔥💀': 'precon-war-deck-e144a106',            // Fire Skull Emoji
          '⚡🌊': 'precon-war-deck-e8bcbbd8',            // Lightning Wave Emoji
          '🌲☀️': 'precon-war-deck-7fa254da',            // Forest Sun Emoji
          '👑': 'precon-war-deck-e89a38eb',              // Crown Emoji
        };

        final generatedIds = <String>{};

        for (final entry in testCases.entries) {
          final name = entry.key;
          final id = MtgjsonPreconParser.buildDeterministicDeckId(setCode: 'WAR', name: name);

          // 1. ID must never be empty or trailing hyphen
          expect(id, isNot(equals('precon-war-')));
          expect(id, startsWith('precon-war-deck-'));

          // 2. ID must be deterministic across calls
          final idAgain = MtgjsonPreconParser.buildDeterministicDeckId(setCode: 'WAR', name: name);
          expect(idAgain, equals(id));

          // 3. ID must be distinct across different non-Latin titles
          expect(generatedIds.contains(id), isFalse,
              reason: 'ID $id for "$name" collided with previously generated ID');
          generatedIds.add(id);
        }

        expect(generatedIds.length, equals(testCases.length));
      });

      test('2.2 Batch SQLite ingestion of 10 non-Latin/emoji decks in the SAME set prevents overwriting', () async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(() => db.close());

        final deckNames = [
          '青白コントロール',
          '黒赤アグロ',
          '緑単ストンピィ',
          'Синий Контроль',
          'Черная Агро',
          'قوة النار',
          'שליטה כחולה',
          'Έλεγχος',
          '타락한 제국',
          '🔥💀⚡',
        ];

        final preconsList = <PreconDeckDto>[];
        for (var i = 0; i < deckNames.length; i++) {
          final deckName = deckNames[i];
          final deckPayload = {
            'name': deckName,
            'format': 'Commander',
            'code': 'WAR',
            'cards': [
              {
                'name': 'Card $i',
                'scryfall_id': 'scryfall-card-uuid-$i',
                'count': 10 + i,
              }
            ]
          };
          preconsList.add(MtgjsonPreconParser.parseDeck(deckPayload));
        }

        // Verify all 10 decks have distinct IDs before DB insertion
        final distinctDeckIds = preconsList.map((d) => d.id).toSet();
        expect(distinctDeckIds.length, equals(10), reason: 'All 10 decks must have distinct IDs');

        // Atomically seed into SQLite
        await PreconHydrationService.seedHistoricalPrecons(
          db,
          force: true,
          customPrecons: preconsList,
        );

        // Query decks table
        final seededDecks = await (db.select(db.decks)
              ..where((d) => d.tcgDomain.equals('mtg') & d.id.like('precon-war-%')))
            .get();

        expect(seededDecks.length, equals(10),
            reason: 'SQLite must contain exactly 10 distinct non-Latin decks without any overwrites');

        // Verify each deck has its active version
        final seededVersions = await (db.select(db.deckVersions)
              ..where((v) => v.deckId.like('precon-war-%')))
            .get();
        expect(seededVersions.length, equals(10));

        // Verify each deck preserved its cards
        final seededItems = await (db.select(db.deckVersionItems)
              ..where((i) => i.versionId.like('precon-war-%-v1')))
            .get();
        expect(seededItems.length, equals(10));

        // Idempotency: re-running with force=true must still result in exactly 10 decks
        await PreconHydrationService.seedHistoricalPrecons(
          db,
          force: true,
          customPrecons: preconsList,
        );

        final postReRunDecks = await (db.select(db.decks)
              ..where((d) => d.tcgDomain.equals('mtg') & d.id.like('precon-war-%')))
            .get();
        expect(postReRunDecks.length, equals(10),
            reason: 'Idempotent re-seeding must not duplicate or lose decks');
      });

      test('2.3 Pure punctuation and whitespace deck names handle slug fallback cleanly', () {
        final punctDeck1 = MtgjsonPreconParser.buildDeterministicDeckId(setCode: 'TST', name: '---');
        final punctDeck2 = MtgjsonPreconParser.buildDeterministicDeckId(setCode: 'TST', name: '...');
        final punctDeck3 = MtgjsonPreconParser.buildDeterministicDeckId(setCode: 'TST', name: '***');

        expect(punctDeck1, startsWith('precon-tst-deck-'));
        expect(punctDeck2, startsWith('precon-tst-deck-'));
        expect(punctDeck3, startsWith('precon-tst-deck-'));

        expect(punctDeck1, isNot(equals(punctDeck2)));
        expect(punctDeck2, isNot(equals(punctDeck3)));
      });
    });
  });
}
