// Copyright (c) 2026 Countr. All rights reserved.
// Art Series & Memorabilia Sanitization Test Suite (Requirement 4).
// Verifying strict ban on Art Series, memorabilia, and duplicate art cards,
// playable Scryfall normal image resolution, and SQLite startup repair pass.

import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart' hide isNull, isNotNull, Column;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/core/cache/countr_cached_image.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/data/models/precon_deck_dto.dart';
import 'package:countr/features/decks/data/services/fallback_explore_seeds.dart';
import 'package:countr/features/decks/data/services/precon_hydration_service.dart';
import 'package:countr/features/decks/domain/models/explore_deck_models.dart';
import 'package:countr/features/decks/presentation/widgets/explore/explore_deck_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  // ===========================================================================
  // 1. R4.1: STRICT BAN ON ART SERIES / MEMORABILIA & "X // X" CARDS
  // ===========================================================================
  group('1. R4.1 Strict Ban on Art Series / Memorabilia & "X // X" Cards', () {
    test('1.1 PreconCardDto sanitizes art_series and double_faced_token layouts to normal', () {
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

    test('1.2 PreconCardDto sanitizes set_type == memorabilia cards', () {
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

    test('1.3 PreconCardDto strictly sanitizes split names where front equals back across casing and whitespace', () {
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

    test('1.4 PreconCardDto strictly PRESERVES legitimate split and DFC cards', () {
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

    test('1.5 Art series set codes are banned, historical non-art "a" sets preserved', () {
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
  });

  // ===========================================================================
  // 2. R4.2: PLAYABLE PRINTING & FULL-FRAME IMAGE (UR-DRAGON / DRACONIC DOMINATION)
  // ===========================================================================
  group('2. R4.2 Playable Printing & Full-Frame Image (Draconic Domination / The Ur-Dragon)', () {
    test('2.1 The Ur-Dragon in Draconic Domination resolves to genuine playable card image', () {
      final fallbackDragon = FallbackExploreSeeds.allSeeds
          .firstWhere((d) => d['id'] == 'precon-c17-draconic-domination');
      expect(fallbackDragon['name'], equals('Draconic Domination'));
      expect(fallbackDragon['commander']['name'], equals('The Ur-Dragon'));
      final fallbackImg = fallbackDragon['commander']['image_url'] as String;
      expect(fallbackImg, isNot(contains('art_series')));
      expect(fallbackImg, isNot(contains('/art_crop/')));
      expect(fallbackImg, contains('normal'));

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

    testWidgets('2.2 ExploreDeckCard resolves 63/88 aspect ratio and intercepts art series / art crop in commander banner', (tester) async {
      final now = DateTime.now();
      final contaminatedDeck = ExploreDeckWithVote(
        deck: ExploreDeck(
          id: 'test-draconic-widget',
          name: 'Draconic Domination',
          format: 'Commander',
          sourceType: 'official',
          creatorName: 'Official WotC',
          featuredCategory: 'Featured Precons',
          commanderName: 'The Ur-Dragon // The Ur-Dragon',
          commanderImageUrl: 'https://cards.scryfall.io/art_series/front/1/2/12.jpg',
          commanderArtCrop: 'https://cards.scryfall.io/art_crop/front/1/2/12.jpg',
          tcgDomain: 'mtg',
          cardCount: 100,
          colorIdentity: jsonEncode(['W', 'U', 'B', 'R', 'G']),
          estimatedPrice: 150.0,
          upvotes: 42,
          downvotes: 1,
          score: 41,
          createdAt: now,
          updatedAt: now,
          isDeleted: false,
        ),
        userVote: 0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExploreDeckCard(
              deckWithVote: contaminatedDeck,
            ),
          ),
        ),
      );
      await tester.pump();

      // Verify AspectRatio widget with 63.0 / 88.0 ratio exists
      final aspectRatios = tester.widgetList<AspectRatio>(find.byType(AspectRatio)).toList();
      final bannerAspect = aspectRatios.firstWhere(
        (ar) => (ar.aspectRatio - (63.0 / 88.0)).abs() < 0.001,
        orElse: () => throw TestFailure('63/88 aspect ratio not found in ExploreDeckCard'),
      );
      expect(bannerAspect.aspectRatio, closeTo(63.0 / 88.0, 0.001));

      // Verify CountrCachedImage resolved away from art series
      final cachedImage = tester.widget<CountrCachedImage>(find.byType(CountrCachedImage));
      expect(cachedImage.imageUrl, isNot(contains('art_series')));
      expect(cachedImage.imageUrl, contains('api.scryfall.com/cards/named'));
      expect(cachedImage.imageUrl, contains('The%20Ur-Dragon'));
      expect(cachedImage.imageUrl, contains('version=normal'));
    });
  });

  // ===========================================================================
  // 3. R4.3: SQLITE STARTUP REPAIR PASS
  // ===========================================================================
  group('3. R4.3 SQLite Startup Repair Pass', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('3.1 PreconHydrationService.repairArtSeriesCards cleans contaminated explore_decks, explore_deck_items, and vault_items', () async {
      final now = DateTime.now();

      // Seed contaminated explore_decks
      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: 'repair_deck_ur_dragon',
          name: 'Draconic Domination Dirty',
          format: 'Commander',
          commanderName: const Value('The Ur-Dragon // The Ur-Dragon'),
          commanderImageUrl: const Value('https://cards.scryfall.io/art_series/front/1/2/123.jpg'),
          commanderArtCrop: const Value('https://cards.scryfall.io/art_crop/front/1/2/123.jpg'),
          createdAt: now,
          updatedAt: Value(now),
        ),
      );

      // Seed contaminated explore_deck_items
      await db.into(db.exploreDeckItems).insert(
        ExploreDeckItemsCompanion.insert(
          id: 'repair_item_solring',
          exploreDeckId: 'repair_deck_ur_dragon',
          cardName: 'Sol Ring (Art Series)',
          imageUrl: const Value('https://cards.scryfall.io/art_crop/front/5/6/567.jpg'),
          quantity: const Value(1),
          boardZone: const Value('Mainboard'),
          isCommander: const Value(false),
          isDeleted: const Value(false),
        ),
      );

      // Seed contaminated vault_items
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'repair_vault_tithe',
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

      // Execute repair pass
      await PreconHydrationService.repairArtSeriesCards(db);

      // Assert explore_decks remediated
      final deck = await (db.select(db.exploreDecks)..where((t) => t.id.equals('repair_deck_ur_dragon'))).getSingle();
      expect(deck.commanderName, equals('The Ur-Dragon'));
      expect(deck.commanderImageUrl, contains('version=normal'));
      expect(deck.commanderImageUrl, isNot(contains('art_series')));
      expect(deck.commanderImageUrl, isNot(contains('/art_crop/')));

      // Assert explore_deck_items remediated
      final item = await (db.select(db.exploreDeckItems)..where((t) => t.id.equals('repair_item_solring'))).getSingle();
      expect(item.cardName, equals('Sol Ring'));
      expect(item.imageUrl, contains('version=normal'));

      // Assert vault_items remediated
      final vault = await (db.select(db.vaultItems)..where((t) => t.id.equals('repair_vault_tithe'))).getSingle();
      expect(vault.name, equals('Smothering Tithe'));
      expect(vault.imageUrl, contains('version=normal'));
      final dyn = jsonDecode(vault.dynamicData);
      expect(dyn['layout'], equals('normal'));
    });

    test('3.2 repairArtSeriesCards is strictly idempotent', () async {
      final now = DateTime.now();

      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: 'idempotent_repair_test',
          name: 'Dragon Test',
          format: 'Commander',
          commanderName: const Value('The Ur-Dragon // The Ur-Dragon'),
          commanderImageUrl: const Value('https://cards.scryfall.io/art_series/front/1/2/123.jpg'),
          createdAt: now,
          updatedAt: Value(now),
        ),
      );

      // Pass 1
      await PreconHydrationService.repairArtSeriesCards(db);
      final p1 = await (db.select(db.exploreDecks)..where((t) => t.id.equals('idempotent_repair_test'))).getSingle();
      expect(p1.commanderName, equals('The Ur-Dragon'));
      expect(p1.commanderImageUrl, contains('version=normal'));

      // Pass 2
      await PreconHydrationService.repairArtSeriesCards(db);
      final p2 = await (db.select(db.exploreDecks)..where((t) => t.id.equals('idempotent_repair_test'))).getSingle();
      expect(p2.commanderName, equals(p1.commanderName));
      expect(p2.commanderImageUrl, equals(p1.commanderImageUrl));
    });
  });
}
