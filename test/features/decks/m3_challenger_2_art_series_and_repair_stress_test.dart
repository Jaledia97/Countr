// Copyright (c) 2026 Countr. All rights reserved.
// Milestone 3 Challenger 2: Adversarial Stress Test Suite
// Testing Art Series & Memorabilia Ban Invariants, Precon Ingestion, and SQLite Startup Repair.

import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart' hide isNull, isNotNull, Column;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/data/models/precon_deck_dto.dart';
import 'package:countr/features/decks/data/services/explore_seeder_service.dart';
import 'package:countr/features/decks/data/services/fallback_explore_seeds.dart';
import 'package:countr/features/decks/data/services/precon_hydration_service.dart';
import 'package:countr/features/decks/domain/models/explore_deck_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('Milestone 3 Challenger 2: Art Series & Memorabilia Ban Invariants (R4)', () {
    test('PreconCardDto.fromMap sanitizes art_series and double_faced_token layouts to normal', () {
      final artSeriesCard = PreconCardDto.fromMap({
        'name': 'Ur-Dragon Art Card',
        'layout': 'art_series',
        'identifiers': {'scryfallId': '11111111-2222-3333-4444-555555555555'},
      });

      expect(artSeriesCard.layout, equals('normal'));
      expect(artSeriesCard.imageUrl, contains('version=normal'));
      expect(artSeriesCard.artCropUrl, contains('version=art_crop'));

      final dynamicMap = artSeriesCard.toDynamicDataMap();
      expect(dynamicMap['layout'], equals('normal'));
      expect(dynamicMap['image_uris']['normal'], contains('version=normal'));

      final dfcTokenCard = PreconCardDto.fromMap({
        'name': 'Dragon Token // Dragon Token',
        'layout': 'double_faced_token',
      });

      expect(dfcTokenCard.layout, equals('normal'));
      expect(dfcTokenCard.name, equals('Dragon Token'));
      expect(dfcTokenCard.imageUrl, contains('version=normal'));
    });

    test('PreconCardDto.fromMap sanitizes set_type == memorabilia cards', () {
      final memorabiliaCard = PreconCardDto.fromMap({
        'name': 'Black Lotus',
        'set_type': 'memorabilia',
        'imageUrl': 'https://cards.scryfall.io/art_crop/front/a/b/memorabilia.jpg',
      });

      expect(memorabiliaCard.layout, equals('normal'));
      expect(memorabiliaCard.imageUrl, contains('version=normal'));
      expect(memorabiliaCard.artCropUrl, contains('version=art_crop'));
      expect(memorabiliaCard.name, equals('Black Lotus'));
    });

    test('PreconCardDto.fromMap strictly sanitizes split names where front equals back across casing and whitespace variations', () {
      final variations = [
        'The Ur-Dragon // The Ur-Dragon',
        '  The Ur-Dragon   //   the ur-dragon  ',
        'THE UR-DRAGON // the ur-dragon',
        'The Ur-Dragon // the ur-dragon // The Ur-Dragon',
        'The Ur-Dragon (Art Card)',
        'The Ur-Dragon - Art Series',
        'Rhystic Study // Rhystic Study',
        '  rhystic study   //   RHYSTIC STUDY  ',
        'Rhystic Study (Art Series)',
        'Sol Ring - Art Card',
      ];

      for (final raw in variations) {
        final card = PreconCardDto.fromMap({'name': raw});
        final cleanExpected = raw.toLowerCase().contains('dragon')
            ? (raw.startsWith(' ') || raw.startsWith('the') ? raw.split('//').first.trim() : 'The Ur-Dragon')
            : (raw.toLowerCase().contains('rhystic') ? (raw.startsWith(' ') || raw.startsWith('rhystic') ? raw.split('//').first.trim() : 'Rhystic Study') : 'Sol Ring');

        expect(card.name.toLowerCase(), contains(cleanExpected.toLowerCase()));
        expect(card.name, isNot(contains('//')));
        expect(card.name, isNot(contains('(Art Card)')));
        expect(card.name, isNot(contains('- Art Series')));
        expect(card.layout, equals('normal'));
        expect(card.imageUrl, contains('version=normal'));
      }
    });

    test('PreconCardDto.fromMap strictly PRESERVES legitimate split and DFC cards', () {
      final legitSplit = PreconCardDto.fromMap({
        'name': 'Fire // Ice',
        'layout': 'split',
        'scryfall_id': '11111111-2222-3333-4444-555555555555',
      });

      expect(legitSplit.name, equals('Fire // Ice'), reason: 'Split card name must be preserved');
      expect(legitSplit.layout, equals('split'), reason: 'Split card layout must not be overridden');

      final legitAdventure = PreconCardDto.fromMap({
        'name': 'Brazen Borrower // Petty Theft',
        'layout': 'adventure',
        'scryfall_id': '22222222-3333-4444-5555-666666666666',
      });

      expect(legitAdventure.name, equals('Brazen Borrower // Petty Theft'));
      expect(legitAdventure.layout, equals('adventure'));

      final legitTransform = PreconCardDto.fromMap({
        'name': 'Delver of Secrets // Insectile Aberration',
        'layout': 'transform',
        'scryfall_id': '33333333-4444-5555-6666-777777777777',
      });

      expect(legitTransform.name, equals('Delver of Secrets // Insectile Aberration'));
      expect(legitTransform.layout, equals('transform'));

      final legitMdfc = PreconCardDto.fromMap({
        'name': 'Blex, Vexing Pest // Search for Blex',
        'layout': 'modal_dfc',
        'scryfall_id': '44444444-5555-6666-7777-888888888888',
      });

      expect(legitMdfc.name, equals('Blex, Vexing Pest // Search for Blex'));
      expect(legitMdfc.layout, equals('modal_dfc'));
    });

    test('Set code regex permutations: art series sets are banned, historical non-art "a" sets are preserved', () {
      final artSeriesSets = [
        'acmm', 'amh1', 'amh2', 'aafr', 'amid', 'astx', 'aclb',
        'avow', 'asnc', 'admu', 'abro', 'aone', 'amom', 'awoe',
        'alci', 'amkm', 'aotj', 'ablb', 'adsk',
      ];

      for (final setCode in artSeriesSets) {
        final card = PreconCardDto.fromMap({
          'name': 'Counterspell',
          'setCode': setCode,
        });
        expect(card.imageUrl, contains('version=normal'),
            reason: 'Art series set $setCode must force Scryfall named normal resolution');
        expect(card.layout, equals('normal'));
      }

      final legitSetsStartingWithA = [
        'arn', 'atq', 'all', 'ala', 'avr', 'akh', 'aer',
        'afc', 'anc', 'a25', 'apc', 'arb', 'arc', 'ana', 'anb',
      ];

      for (final setCode in legitSetsStartingWithA) {
        final card = PreconCardDto.fromMap({
          'name': 'Kird Ape',
          'setCode': setCode,
          'layout': 'normal',
          'scryfall_id': '55555555-6666-7777-8888-999999999999',
        });
        expect(card.imageUrl, contains('55555555-6666-7777-8888-999999999999.jpg'),
            reason: 'Legitimate set $setCode must NOT be falsely identified as art series');
        expect(card.name, equals('Kird Ape'));
      }
    });

    test('ExploreSeederService.seedFromRawDecks sanitizes commander cards with art series names or URLs', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      final dirtySeed = [
        {
          'id': 'dirty-deck-1',
          'name': 'Dirty Commander Deck',
          'format': 'Commander',
          'source_type': 'official',
          'commander': {
            'name': 'The Ur-Dragon // The Ur-Dragon',
            'image_url': 'https://cards.scryfall.io/art_crop/front/1/2/12.jpg',
            'art_crop_url': 'https://cards.scryfall.io/art_series/front/1/2/12.jpg',
            'is_commander': true,
          },
          'cards': <Map<String, dynamic>>[],
        }
      ];

      await ExploreSeederService.seedFromRawDecks(db, dirtySeed);

      final seededDeck = await db.exploreDeckDao.getExploreDeck('dirty-deck-1');
      expect(seededDeck, isNotNull);
      expect(seededDeck!.deck.commanderName, equals('The Ur-Dragon'));
      expect(seededDeck.deck.commanderImageUrl, contains('version=normal'));
      expect(seededDeck.deck.commanderArtCrop, contains('version=art_crop'));
    });
  });

  group('Milestone 3 Challenger 2: Precon Bundle Ingestion & Data Integrity (R3.B)', () {
    test('assets/data/official_precons.json.gz exists, is valid GZIP, and decompresses into 500+ preconstructed decks', () {
      final file = File('assets/data/official_precons.json.gz');
      expect(file.existsSync(), isTrue, reason: 'official_precons.json.gz must exist at assets/data/');

      final bytes = file.readAsBytesSync();
      expect(bytes.length, greaterThan(100000), reason: 'Bundle size must be substantial (>100KB)');

      // Validate GZIP magic header: 0x1f, 0x8b
      expect(bytes[0], equals(0x1f));
      expect(bytes[1], equals(0x8b));

      final decompressed = gzip.decode(bytes);
      expect(decompressed.isNotEmpty, isTrue);

      final jsonStr = utf8.decode(decompressed);
      final list = jsonDecode(jsonStr);
      expect(list, isA<List>());

      final decks = (list as List).cast<Map<String, dynamic>>();
      expect(decks.length, greaterThanOrEqualTo(500),
          reason: 'Expected at least 500 preconstructed decks, got ${decks.length}');
    });

    test('Draconic Domination / The Ur-Dragon resolves to playable normal card image across datasets', () {
      // 1. Check in FallbackExploreSeeds
      final fallbackDragon = FallbackExploreSeeds.allSeeds
          .firstWhere((d) => d['id'] == 'precon-c17-draconic-domination');
      expect(fallbackDragon['name'], equals('Draconic Domination'));
      expect(fallbackDragon['commander']['name'], equals('The Ur-Dragon'));
      final fallbackImg = fallbackDragon['commander']['image_url'] as String;
      expect(fallbackImg, isNot(contains('art_series')));
      expect(fallbackImg, isNot(contains('/art_crop/')));
      expect(fallbackImg, contains('normal'));

      // 2. Check in assets/data/official_precons.json.gz
      final bytes = File('assets/data/official_precons.json.gz').readAsBytesSync();
      final decks = (jsonDecode(utf8.decode(gzip.decode(bytes))) as List)
          .cast<Map<String, dynamic>>();

      final dragonDecks = decks.where((d) => (d['name'] as String).contains('Draconic Domination')).toList();
      expect(dragonDecks.isNotEmpty, isTrue, reason: 'Draconic Domination must exist in precons bundle');

      for (final d in dragonDecks) {
        final commander = d['commander'] as Map<String, dynamic>?;
        expect(commander, isNotNull);
        expect(commander!['name'], equals('The Ur-Dragon'));
        final img = commander['image_url']?.toString() ?? '';
        expect(img, isNot(contains('art_series')), reason: 'The Ur-Dragon image must not be an art series card');
        expect(img, isNot(contains('/art_crop/')), reason: 'The Ur-Dragon commander cover must be normal full card');
      }
    });

    test('Global Art Series Ban verification across entire 500+ official precon catalog', () {
      final bytes = File('assets/data/official_precons.json.gz').readAsBytesSync();
      final decks = (jsonDecode(utf8.decode(gzip.decode(bytes))) as List)
          .cast<Map<String, dynamic>>();

      int totalCardsInspected = 0;

      for (final deck in decks) {
        expect(deck['id'], isNotNull);
        expect(deck['name'], isNotNull);
        expect(deck['format'], isNotNull);

        final commander = deck['commander'] as Map<String, dynamic>?;
        final cards = (deck['cards'] as List? ?? []).cast<Map<String, dynamic>>();

        final allCardsInDeck = [
          ?commander,
          ...cards,
        ];

        for (final card in allCardsInDeck) {
          totalCardsInspected++;
          final name = card['name']?.toString() ?? '';
          final layout = card['layout']?.toString().toLowerCase();
          final setType = card['set_type']?.toString().toLowerCase();
          final setCode = card['set_code']?.toString().toLowerCase();
          final imageUrl = card['image_url']?.toString() ?? '';

          // 1. Layout must never be art_series or double_faced_token
          expect(layout, isNot('art_series'), reason: 'Card "$name" in "${deck['name']}" has layout art_series');
          expect(layout, isNot('double_faced_token'));

          // 2. Set type must not be memorabilia
          expect(setType, isNot('memorabilia'));

          // 3. Set code must not match art-series pattern
          if (setCode != null) {
            expect(RegExp(r'^a[a-z0-9]{3,4}$').hasMatch(setCode), isFalse,
                reason: 'Card "$name" in "${deck['name']}" has art series setCode "$setCode"');
          }

          // 4. Name must not be identical split faces
          if (name.contains(' // ')) {
            final parts = name.split(' // ');
            expect(parts[0].trim().toLowerCase(), isNot(equals(parts[1].trim().toLowerCase())),
                reason: 'Card "$name" in "${deck['name']}" has identical split faces');
          }

          // 5. Image URL must not be art series
          expect(imageUrl, isNot(contains('art_series')));
        }
      }

      expect(totalCardsInspected, greaterThan(25000),
          reason: 'Expected at least 25,000 cards verified across 500+ preconstructed decks');
    });

    test('ExploreSeederService.hydrateFullCatalogIfNeeded loads 500+ preconstructed decks into SQLite', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      expect(await db.exploreDeckDao.getExploreDeckCount(), equals(0));

      await ExploreSeederService.hydrateFullCatalogIfNeeded(db, force: true);

      final totalDecks = await db.exploreDeckDao.getExploreDeckCount();
      expect(totalDecks, greaterThanOrEqualTo(500),
          reason: 'Database must contain 500+ preconstructed decks after catalog hydration');

      // Verify querying ExploreCategory.all works smoothly on 500+ decks
      final feed = await db.exploreDeckDao.watchExploreDecks(
        category: ExploreCategory.all,
        limit: 20,
      ).first;

      expect(feed.length, equals(20));
      for (final item in feed) {
        expect(item.deck.name.isNotEmpty, isTrue);
      }
    });
  });

  group('Milestone 3 Challenger 2: SQLite Startup Repair Pass (R4)', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('repairArtSeriesCards remediates contaminated explore_decks, explore_deck_items, and vault_items', () async {
      final now = DateTime.now();

      // Seed contaminated explore_decks
      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: 'dirty_deck_dragon',
          name: 'Dirty Dragon Precon',
          format: 'Commander',
          commanderName: const Value('The Ur-Dragon // The Ur-Dragon'),
          commanderImageUrl: const Value('https://cards.scryfall.io/art_series/front/1/2/123.jpg'),
          commanderArtCrop: const Value('https://cards.scryfall.io/art_crop/front/1/2/123.jpg'),
          createdAt: now,
          updatedAt: Value(now),
        ),
      );

      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: 'dirty_deck_rhystic',
          name: 'Dirty Rhystic Deck',
          format: 'Commander',
          commanderName: const Value('Rhystic Study (Art Card)'),
          commanderImageUrl: const Value('https://cards.scryfall.io/art_crop/front/3/4/345.jpg'),
          createdAt: now,
          updatedAt: Value(now),
        ),
      );

      // Seed contaminated explore_deck_items
      await db.into(db.exploreDeckItems).insert(
        ExploreDeckItemsCompanion.insert(
          id: 'dirty_item_solring',
          exploreDeckId: 'dirty_deck_dragon',
          cardName: 'Sol Ring (Art Series)',
          imageUrl: const Value('https://cards.scryfall.io/art_crop/front/5/6/567.jpg'),
          quantity: const Value(1),
          boardZone: const Value('Mainboard'),
          isCommander: const Value(false),
          isDeleted: const Value(false),
        ),
      );

      await db.into(db.exploreDeckItems).insert(
        ExploreDeckItemsCompanion.insert(
          id: 'dirty_item_tutor',
          exploreDeckId: 'dirty_deck_dragon',
          cardName: 'Demonic Tutor // Demonic Tutor',
          imageUrl: const Value('https://cards.scryfall.io/art_series/front/7/8/789.jpg'),
          quantity: const Value(1),
          boardZone: const Value('Mainboard'),
          isCommander: const Value(false),
          isDeleted: const Value(false),
        ),
      );

      // Seed contaminated vault_items
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'dirty_vault_tithe',
          name: 'Smothering Tithe // Smothering Tithe',
          collectionType: 'mtg',
          setOrSeries: 'Commander',
          condition: 'NM',
          imageUrl: 'https://cards.scryfall.io/art_crop/front/a/b/ab.jpg',
          dynamicData: jsonEncode({
            'layout': 'art_series',
            'set_type': 'memorabilia',
          }),
          acquiredPrice: 20.0,
          currentMarketPrice: 20.0,
          acquiredDate: now,
          lastPriceUpdate: now,
          isDeleted: const Value(false),
          updatedAt: Value(now),
        ),
      );

      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'dirty_vault_rift',
          name: 'Cyclonic Rift - Art Series',
          collectionType: 'mtg',
          setOrSeries: 'Commander',
          condition: 'NM',
          imageUrl: 'https://cards.scryfall.io/art_series/front/c/d/cd.jpg',
          dynamicData: jsonEncode({'layout': 'art_series'}),
          acquiredPrice: 15.0,
          currentMarketPrice: 15.0,
          acquiredDate: now,
          lastPriceUpdate: now,
          isDeleted: const Value(false),
          updatedAt: Value(now),
        ),
      );

      // Execute repair pass
      await PreconHydrationService.repairArtSeriesCards(db);

      // Assert explore_decks remediated
      final deck1 = await (db.select(db.exploreDecks)..where((t) => t.id.equals('dirty_deck_dragon'))).getSingle();
      expect(deck1.commanderName, equals('The Ur-Dragon'));
      expect(deck1.commanderImageUrl, contains('version=normal'));
      expect(deck1.commanderImageUrl, isNot(contains('art_series')));
      expect(deck1.commanderImageUrl, isNot(contains('/art_crop/')));

      final deck2 = await (db.select(db.exploreDecks)..where((t) => t.id.equals('dirty_deck_rhystic'))).getSingle();
      expect(deck2.commanderName, equals('Rhystic Study'));
      expect(deck2.commanderImageUrl, contains('version=normal'));

      // Assert explore_deck_items remediated
      final item1 = await (db.select(db.exploreDeckItems)..where((t) => t.id.equals('dirty_item_solring'))).getSingle();
      expect(item1.cardName, equals('Sol Ring'));
      expect(item1.imageUrl, contains('version=normal'));

      final item2 = await (db.select(db.exploreDeckItems)..where((t) => t.id.equals('dirty_item_tutor'))).getSingle();
      expect(item2.cardName, equals('Demonic Tutor'));
      expect(item2.imageUrl, contains('version=normal'));

      // Assert vault_items remediated
      final vault1 = await (db.select(db.vaultItems)..where((t) => t.id.equals('dirty_vault_tithe'))).getSingle();
      expect(vault1.name, equals('Smothering Tithe'));
      expect(vault1.imageUrl, contains('version=normal'));
      final dyn1 = jsonDecode(vault1.dynamicData);
      expect(dyn1['layout'], equals('normal'));

      final vault2 = await (db.select(db.vaultItems)..where((t) => t.id.equals('dirty_vault_rift'))).getSingle();
      expect(vault2.name, equals('Cyclonic Rift'));
      expect(vault2.imageUrl, contains('version=normal'));
      final dyn2 = jsonDecode(vault2.dynamicData);
      expect(dyn2['layout'], equals('normal'));
    });

    test('Strict Idempotency: repeated executions of repairArtSeriesCards produce identical results', () async {
      final now = DateTime.now();

      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: 'deck_idempotent_test',
          name: 'Dragon Test',
          format: 'Commander',
          commanderName: const Value('The Ur-Dragon // The Ur-Dragon'),
          commanderImageUrl: const Value('https://cards.scryfall.io/art_series/front/1/2/123.jpg'),
          createdAt: now,
          updatedAt: Value(now),
        ),
      );

      // Run 1
      await PreconHydrationService.repairArtSeriesCards(db);
      final pass1 = await (db.select(db.exploreDecks)..where((t) => t.id.equals('deck_idempotent_test'))).getSingle();
      expect(pass1.commanderName, equals('The Ur-Dragon'));
      expect(pass1.commanderImageUrl, contains('version=normal'));

      // Run 2
      await PreconHydrationService.repairArtSeriesCards(db);
      final pass2 = await (db.select(db.exploreDecks)..where((t) => t.id.equals('deck_idempotent_test'))).getSingle();
      expect(pass2.commanderName, equals(pass1.commanderName));
      expect(pass2.commanderImageUrl, equals(pass1.commanderImageUrl));

      // Run 3
      await PreconHydrationService.repairArtSeriesCards(db);
      final pass3 = await (db.select(db.exploreDecks)..where((t) => t.id.equals('deck_idempotent_test'))).getSingle();
      expect(pass3.commanderName, equals(pass1.commanderName));
      expect(pass3.commanderImageUrl, equals(pass1.commanderImageUrl));
    });

    test('Performance & stress test: repairArtSeriesCards cleans 300 contaminated items rapidly without hanging', () async {
      final now = DateTime.now();

      await db.transaction(() async {
        for (int i = 0; i < 100; i++) {
          await db.into(db.exploreDecks).insert(
            ExploreDecksCompanion.insert(
              id: 'stress_deck_$i',
              name: 'Stress Deck $i',
              format: 'Commander',
              commanderName: Value(i.isEven ? 'The Ur-Dragon // The Ur-Dragon' : 'Clean Commander $i'),
              commanderImageUrl: Value(i.isEven ? 'https://cards.scryfall.io/art_series/123.jpg' : 'https://cards.scryfall.io/normal/123.jpg'),
              createdAt: now,
              updatedAt: Value(now),
            ),
          );
        }

        for (int i = 0; i < 100; i++) {
          await db.into(db.exploreDeckItems).insert(
            ExploreDeckItemsCompanion.insert(
              id: 'stress_item_$i',
              exploreDeckId: 'stress_deck_$i',
              cardName: i.isEven ? 'Sol Ring (Art Series)' : 'Clean Card $i',
              imageUrl: Value(i.isEven ? 'https://cards.scryfall.io/art_crop/123.jpg' : 'https://cards.scryfall.io/normal/123.jpg'),
              quantity: const Value(1),
              boardZone: const Value('Mainboard'),
              isCommander: const Value(false),
              isDeleted: const Value(false),
            ),
          );
        }

        for (int i = 0; i < 100; i++) {
          await db.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'stress_vault_$i',
              name: i.isEven ? 'Smothering Tithe // Smothering Tithe' : 'Clean Vault $i',
              collectionType: 'mtg',
              setOrSeries: 'Commander',
              condition: 'NM',
              imageUrl: i.isEven ? 'https://cards.scryfall.io/art_series/123.jpg' : 'https://cards.scryfall.io/normal/123.jpg',
              dynamicData: jsonEncode({'layout': i.isEven ? 'art_series' : 'normal'}),
              acquiredPrice: 5.0,
              currentMarketPrice: 5.0,
              acquiredDate: now,
              lastPriceUpdate: now,
              isDeleted: const Value(false),
              updatedAt: Value(now),
            ),
          );
        }
      });

      final stopwatch = Stopwatch()..start();
      await PreconHydrationService.repairArtSeriesCards(db);
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(3000),
          reason: 'Repair pass took ${stopwatch.elapsedMilliseconds}ms; must complete under 3000ms');

      // Verify dirty items were cleaned
      final dirtyDecksLeft = await (db.select(db.exploreDecks)
            ..where((t) => t.commanderName.contains('//') | t.commanderImageUrl.contains('art_series')))
          .get();
      expect(dirtyDecksLeft, isEmpty);
    });

    test('behavior of legitimate split/DFC cards in repairArtSeriesCards', () async {
      final now = DateTime.now();

      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'legit_dfc_delver',
          name: 'Delver of Secrets // Insectile Aberration',
          collectionType: 'mtg',
          setOrSeries: 'Innistrad',
          condition: 'NM',
          imageUrl: 'https://cards.scryfall.io/normal/front/1/1/delver.jpg',
          dynamicData: jsonEncode({
            'layout': 'transform',
            'card_faces': [
              {'name': 'Delver of Secrets'},
              {'name': 'Insectile Aberration'},
            ]
          }),
          acquiredPrice: 2.0,
          currentMarketPrice: 2.0,
          acquiredDate: now,
          lastPriceUpdate: now,
          isDeleted: const Value(false),
          updatedAt: Value(now),
        ),
      );

      await PreconHydrationService.repairArtSeriesCards(db);

      final vaultDelver = await (db.select(db.vaultItems)..where((t) => t.id.equals('legit_dfc_delver'))).getSingle();
      final dyn = jsonDecode(vaultDelver.dynamicData) as Map<String, dynamic>;
      expect(dyn['image_uris']['normal'], contains('version=normal'));
      // Observe what happened to layout and name
      expect(vaultDelver.name, equals('Delver of Secrets // Insectile Aberration'));
      // Note: Scryfall named query works for Delver of Secrets // Insectile Aberration
      expect(vaultDelver.imageUrl, contains('version=normal'));
    });
  });
}
