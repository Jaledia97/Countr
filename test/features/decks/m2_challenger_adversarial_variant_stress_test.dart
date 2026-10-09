import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:countr/core/cache/countr_cached_image.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/decks/data/daos/explore_deck_dao.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/decks/presentation/providers/explore_deck_providers.dart';
import 'package:countr/features/decks/presentation/screens/read_only_deck_screen.dart';
import 'package:countr/features/decks/presentation/screens/deck_builder_screen.dart';
import 'package:countr/features/decks/data/models/precon_deck_dto.dart';
import 'deck_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  late AppDatabase db;
  late VaultDao vaultDao;
  late ExploreDeckDao exploreDao;

  const testDeckId = 'adversarial_stress_test_deck';
  const testDeckName = 'Adversarial Stress Test Deck';

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    vaultDao = VaultDao(db);
    exploreDao = ExploreDeckDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildTestApp({required Widget child}) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        vaultDaoProvider.overrideWithValue(vaultDao),
        exploreDeckDaoProvider.overrideWithValue(exploreDao),
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('Challenger M2-1 Adversarial Stress Test: Variant Preservation & Art Series Filtering', () {
    // -------------------------------------------------------------------------
    // 1. Subtle Art Series Casing & Edge Cases
    // -------------------------------------------------------------------------
    testWidgets('1.1 Obscure casing on layout: Art_Series and ART_SERIES are caught and sanitized', (tester) async {
      final now = DateTime.now();

      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: testDeckId,
          name: testDeckName,
          format: 'Commander',
          tcgDomain: const Value('mtg'),
          commanderName: const Value('Morophon, the Boundless'),
          cardCount: const Value(100),
          createdAt: now,
          updatedAt: Value(now),
        ),
      );

      // Card with Mixed Case "Art_Series" in dynamicData
      await db.into(db.exploreDeckItems).insert(
        ExploreDeckItemsCompanion.insert(
          id: 'item_mixed_casing_layout',
          exploreDeckId: testDeckId,
          cardName: 'Ragavan, Nimble Pilferer',
          quantity: const Value(1),
          boardZone: const Value('Creatures'),
          typeLine: const Value('Legendary Creature — Monkey Pirate'),
          imageUrl: const Value('https://cards.scryfall.io/art_crop/front/ragavan_art.jpg'),
          dynamicData: Value(jsonEncode({
            'layout': 'Art_Series',
          })),
        ),
      );

      // Card with Uppercase "ART_SERIES" in dynamicData
      await db.into(db.exploreDeckItems).insert(
        ExploreDeckItemsCompanion.insert(
          id: 'item_upper_casing_layout',
          exploreDeckId: testDeckId,
          cardName: 'Sol Ring',
          quantity: const Value(1),
          boardZone: const Value('Artifacts'),
          typeLine: const Value('Artifact'),
          imageUrl: const Value('https://cards.scryfall.io/art_crop/front/sol_ring_art.jpg'),
          dynamicData: Value(jsonEncode({
            'layout': 'ART_SERIES',
          })),
        ),
      );

      await tester.pumpWidget(
        buildTestApp(child: ReadOnlyDeckScreen(exploreDeckId: testDeckId)),
      );
      await tester.pumpAndSettle();

      final cachedImages = tester.widgetList<CountrCachedImage>(find.byType(CountrCachedImage)).toList();

      final ragavanImage = cachedImages.firstWhere((img) => img.cardName == 'Ragavan, Nimble Pilferer');
      expect(ragavanImage.imageUrl, contains('api.scryfall.com/cards/named'));
      expect(ragavanImage.imageUrl, contains('Ragavan%2C%20Nimble%20Pilferer'));
      expect(ragavanImage.imageUrl, contains('version=normal'));
      expect(ragavanImage.cacheKey, equals('explore_item_item_mixed_casing_layout_fallback'));

      final solImage = cachedImages.firstWhere((img) => img.cardName == 'Sol Ring');
      expect(solImage.imageUrl, contains('api.scryfall.com/cards/named'));
      expect(solImage.imageUrl, contains('Sol%20Ring'));
      expect(solImage.imageUrl, contains('version=normal'));
      expect(solImage.cacheKey, equals('explore_item_item_upper_casing_layout_fallback'));
    });

    testWidgets('1.2 Art card name variations: (Art Card), (Art Series), - Art Card, and lowercase (art card) are cleaned cleanly', (tester) async {
      final now = DateTime.now();

      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: testDeckId,
          name: testDeckName,
          format: 'Commander',
          tcgDomain: const Value('mtg'),
          commanderName: const Value('Morophon, the Boundless'),
          cardCount: const Value(100),
          createdAt: now,
          updatedAt: Value(now),
        ),
      );

      final variations = [
        ('var_1', 'Ragavan (Art Card)', 'Ragavan'),
        ('var_2', 'Ragavan (Art Series)', 'Ragavan'),
        ('var_3', 'Ragavan - Art Card', 'Ragavan'),
        ('var_4', 'Ragavan - Art Series', 'Ragavan'),
        ('var_5', 'Ragavan (art card)', 'Ragavan'),
        ('var_6', 'Ragavan (ART SERIES)', 'Ragavan'),
        ('var_7', 'Ragavan, Nimble Pilferer // Ragavan, Nimble Pilferer', 'Ragavan, Nimble Pilferer'),
      ];

      for (final (id, inputName, _) in variations) {
        await db.into(db.exploreDeckItems).insert(
          ExploreDeckItemsCompanion.insert(
            id: id,
            exploreDeckId: testDeckId,
            cardName: inputName,
            quantity: const Value(1),
            boardZone: const Value('Creatures'),
            typeLine: const Value('Card // Card'),
            imageUrl: const Value('https://cards.scryfall.io/art_crop/front/sample.jpg'),
            dynamicData: Value(jsonEncode({'layout': 'art_series'})),
          ),
        );
      }

      await tester.pumpWidget(
        buildTestApp(child: ReadOnlyDeckScreen(exploreDeckId: testDeckId)),
      );
      await tester.pumpAndSettle();

      final cachedImages = tester.widgetList<CountrCachedImage>(find.byType(CountrCachedImage)).toList();

      for (final (id, inputName, expectedClean) in variations) {
        final img = cachedImages.firstWhere((i) => i.cardName == inputName);
        expect(img.imageUrl, contains('api.scryfall.com/cards/named'),
            reason: 'Card $inputName must resolve to Scryfall named endpoint');
        expect(img.imageUrl, contains(Uri.encodeComponent(expectedClean)),
            reason: 'Clean name in URL must be $expectedClean without art suffixes');
        expect(img.imageUrl, isNot(contains('Art%20Card')),
            reason: 'URL must not contain Art Card');
        expect(img.imageUrl, isNot(contains('Art%20Series')),
            reason: 'URL must not contain Art Series');
        expect(img.imageUrl, contains('version=normal'),
            reason: 'Must request version=normal for playable face');
        expect(img.cacheKey, equals('explore_item_${id}_fallback'),
            reason: 'Cache key must be isolated with _fallback');
      }
    });

    testWidgets('1.3 Comprehensive Art Series set codes: amh1, amh2, aafr, astx, akhm, aznr, amid, avow, aneo, asnc, aclb, admu, abro, aone, amom, awoe, alci, amkm, aotj, amh3, ablb, adsk, afdn, with mixed casing', (tester) async {
      final now = DateTime.now();

      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: testDeckId,
          name: testDeckName,
          format: 'Commander',
          tcgDomain: const Value('mtg'),
          commanderName: const Value('Morophon, the Boundless'),
          cardCount: const Value(100),
          createdAt: now,
          updatedAt: Value(now),
        ),
      );

      final artSetCodes = [
        'amh1', 'AMH2', 'aafr', 'ASTX', 'akhm', 'aznr', 'aMID',
        'avow', 'aneo', 'asnc', 'aclb', 'admu', 'abro', 'aone',
        'amom', 'awoe', 'alci', 'amkm', 'aotj', 'amh3', 'ablb',
        'adsk', 'afdn',
      ];

      for (int i = 0; i < artSetCodes.length; i++) {
        final code = artSetCodes[i];
        await db.into(db.exploreDeckItems).insert(
          ExploreDeckItemsCompanion.insert(
            id: 'art_set_$i',
            exploreDeckId: testDeckId,
            cardName: 'Card From $code',
            quantity: const Value(1),
            boardZone: const Value('Mainboard'),
            typeLine: const Value('Card'),
            imageUrl: const Value('https://cards.scryfall.io/front/art_set_sample.jpg'),
            dynamicData: Value(jsonEncode({'set': code})),
          ),
        );
      }

      await tester.pumpWidget(
        buildTestApp(child: ReadOnlyDeckScreen(exploreDeckId: testDeckId)),
      );
      await tester.pumpAndSettle();

      final cachedImages = tester.widgetList<CountrCachedImage>(find.byType(CountrCachedImage)).toList();

      for (int i = 0; i < artSetCodes.length; i++) {
        final code = artSetCodes[i];
        final img = cachedImages.firstWhere((c) => c.cardName == 'Card From $code');
        expect(img.imageUrl, contains('api.scryfall.com/cards/named'),
            reason: 'Card from art series set $code must fall back to Scryfall named endpoint');
        expect(img.imageUrl, contains('version=normal'));
        expect(img.cacheKey, equals('explore_item_art_set_${i}_fallback'));
      }
    });

    testWidgets('1.4 DynamicData nested image_uris containing art_series URL are detected and filtered', (tester) async {
      final now = DateTime.now();

      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: testDeckId,
          name: testDeckName,
          format: 'Commander',
          tcgDomain: const Value('mtg'),
          commanderName: const Value('Morophon, the Boundless'),
          cardCount: const Value(100),
          createdAt: now,
          updatedAt: Value(now),
        ),
      );

      // Card with clean name and normal layout, but nested image_uris has art_series URL
      await db.into(db.exploreDeckItems).insert(
        ExploreDeckItemsCompanion.insert(
          id: 'nested_art_uris',
          exploreDeckId: testDeckId,
          cardName: 'Chandra, Dressed to Kill',
          quantity: const Value(1),
          boardZone: const Value('Planeswalkers'),
          typeLine: const Value('Legendary Planeswalker — Chandra'),
          imageUrl: const Value(null),
          dynamicData: Value(jsonEncode({
            'layout': 'normal',
            'image_uris': {
              'normal': 'https://cards.scryfall.io/art_series/front/chandra_art.jpg',
            },
          })),
        ),
      );

      await tester.pumpWidget(
        buildTestApp(child: ReadOnlyDeckScreen(exploreDeckId: testDeckId)),
      );
      await tester.pumpAndSettle();

      final cachedImages = tester.widgetList<CountrCachedImage>(find.byType(CountrCachedImage)).toList();
      final chandra = cachedImages.firstWhere((i) => i.cardName == 'Chandra, Dressed to Kill');

      expect(chandra.imageUrl, isNot(contains('art_series/front/chandra_art.jpg')));
      expect(chandra.imageUrl, contains('api.scryfall.com/cards/named'));
      expect(chandra.imageUrl, contains('Chandra%2C%20Dressed%20to%20Kill'));
      expect(chandra.imageUrl, contains('version=normal'));
      expect(chandra.cacheKey, equals('explore_item_nested_art_uris_fallback'));
    });

    testWidgets('1.5 Banner art with DFC commander or (Art Card) commander name sanitizes name properly', (tester) async {
      final now = DateTime.now();

      // Deck 1: DFC Commander with art_series URL
      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: 'deck_dfc_banner',
          name: 'Aang DFC Deck',
          format: 'Commander',
          tcgDomain: const Value('mtg'),
          commanderName: const Value('Aang and Katara // Aang and Katara'),
          commanderArtCrop: const Value('https://cards.scryfall.io/art_series/front/aang.jpg'),
          cardCount: const Value(100),
          createdAt: now,
          updatedAt: Value(now),
        ),
      );

      await tester.pumpWidget(
        buildTestApp(child: ReadOnlyDeckScreen(exploreDeckId: 'deck_dfc_banner')),
      );
      await tester.pumpAndSettle();

      final cachedImages = tester.widgetList<CountrCachedImage>(find.byType(CountrCachedImage)).toList();
      final bannerImg = cachedImages.firstWhere((i) => i.cardName == 'Aang and Katara // Aang and Katara');

      expect(bannerImg.imageUrl, contains('api.scryfall.com/cards/named'));
      expect(bannerImg.imageUrl, contains('Aang%20and%20Katara'));
      expect(bannerImg.imageUrl, isNot(contains('%2F%2F')));
      expect(bannerImg.imageUrl, contains('version=art_crop'));
      expect(bannerImg.cacheKey, equals('explore_cover_deck_dfc_banner_fallback'));
    });

    testWidgets('1.6 Multi-signal art series detection protects against mixed-casing image URLs (via layout or set)', (tester) async {
      final now = DateTime.now();

      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: 'deck_mixed_url',
          name: 'Mixed URL Deck',
          format: 'Commander',
          tcgDomain: const Value('mtg'),
          commanderName: const Value('Morophon, the Boundless'),
          cardCount: const Value(100),
          createdAt: now,
          updatedAt: Value(now),
        ),
      );

      // Card with mixed-case URL AND layout: art_series
      await db.into(db.exploreDeckItems).insert(
        ExploreDeckItemsCompanion.insert(
          id: 'item_mixed_url_with_layout',
          exploreDeckId: 'deck_mixed_url',
          cardName: 'Sol Ring',
          quantity: const Value(1),
          boardZone: const Value('Artifacts'),
          typeLine: const Value('Artifact'),
          imageUrl: const Value('https://cdn.example.com/Art_Series/front/sol_ring.jpg'),
          dynamicData: Value(jsonEncode({'layout': 'art_series'})),
        ),
      );

      // Card with mixed-case URL AND set: AMH2
      await db.into(db.exploreDeckItems).insert(
        ExploreDeckItemsCompanion.insert(
          id: 'item_mixed_url_with_set',
          exploreDeckId: 'deck_mixed_url',
          cardName: 'Mana Crypt',
          quantity: const Value(1),
          boardZone: const Value('Artifacts'),
          typeLine: const Value('Artifact'),
          imageUrl: const Value('https://cdn.example.com/ART_SERIES/front/mana_crypt.jpg'),
          dynamicData: Value(jsonEncode({'set': 'AMH2'})),
        ),
      );

      await tester.pumpWidget(
        buildTestApp(child: ReadOnlyDeckScreen(exploreDeckId: 'deck_mixed_url')),
      );
      await tester.pumpAndSettle();

      final cachedImages = tester.widgetList<CountrCachedImage>(find.byType(CountrCachedImage)).toList();

      final solImg = cachedImages.firstWhere((i) => i.cardName == 'Sol Ring');
      expect(solImg.imageUrl, contains('api.scryfall.com/cards/named'),
          reason: 'Layout art_series catches card even if image URL has mixed-casing');
      expect(solImg.imageUrl, contains('version=normal'));
      expect(solImg.cacheKey, equals('explore_item_item_mixed_url_with_layout_fallback'));

      final cryptImg = cachedImages.firstWhere((i) => i.cardName == 'Mana Crypt');
      expect(cryptImg.imageUrl, contains('api.scryfall.com/cards/named'),
          reason: 'Set AMH2 catches card even if image URL has uppercase ART_SERIES');
      expect(cryptImg.imageUrl, contains('version=normal'));
      expect(cryptImg.cacheKey, equals('explore_item_item_mixed_url_with_set_fallback'));
    });

    // -------------------------------------------------------------------------
    // 2. Genuine Variant Preservation Stress-Tests
    // -------------------------------------------------------------------------
    testWidgets('2.1 Genuine 3-letter sets starting with "a" (afr, aer, akh, ala, arb, arc, all) are NEVER misidentified as art cards', (tester) async {
      final now = DateTime.now();

      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: testDeckId,
          name: testDeckName,
          format: 'Commander',
          tcgDomain: const Value('mtg'),
          commanderName: const Value('Morophon, the Boundless'),
          cardCount: const Value(100),
          createdAt: now,
          updatedAt: Value(now),
        ),
      );

      final genuineASets = [
        ('afr_card', 'Tiamat', 'afr', 'https://cards.scryfall.io/normal/front/tiamat_afr.jpg'),
        ('aer_card', 'Heart of Kiran', 'aer', 'https://cards.scryfall.io/normal/front/heart_of_kiran.jpg'),
        ('akh_card', 'Hazoret the Fervent', 'akh', 'https://cards.scryfall.io/normal/front/hazoret.jpg'),
        ('ala_card', 'Rafiq of the Many', 'ala', 'https://cards.scryfall.io/normal/front/rafiq.jpg'),
        ('arb_card', 'Bloodbraid Elf', 'arb', 'https://cards.scryfall.io/normal/front/bloodbraid.jpg'),
        ('arc_card', 'Mantis Engine', 'arc', 'https://cards.scryfall.io/normal/front/mantis.jpg'),
        ('all_card', 'Force of Will', 'all', 'https://cards.scryfall.io/normal/front/force_of_will.jpg'),
      ];

      for (final (id, cardName, setCode, url) in genuineASets) {
        await db.into(db.exploreDeckItems).insert(
          ExploreDeckItemsCompanion.insert(
            id: id,
            exploreDeckId: testDeckId,
            cardName: cardName,
            quantity: const Value(1),
            boardZone: const Value('Mainboard'),
            typeLine: const Value('Creature'),
            imageUrl: Value(url),
            dynamicData: Value(jsonEncode({'set': setCode})),
          ),
        );
      }

      await tester.pumpWidget(
        buildTestApp(child: ReadOnlyDeckScreen(exploreDeckId: testDeckId)),
      );
      await tester.pumpAndSettle();

      final cachedImages = tester.widgetList<CountrCachedImage>(find.byType(CountrCachedImage)).toList();

      for (final (id, cardName, setCode, url) in genuineASets) {
        final img = cachedImages.firstWhere((c) => c.cardName == cardName);
        expect(img.imageUrl, equals(url),
            reason: 'Genuine set $setCode must preserve exact CDN image URL');
        expect(img.cacheKey, equals('explore_item_$id'),
            reason: 'Genuine set $setCode must use standard cache key without _fallback');
      }
    });

    testWidgets('2.2 Genuine variants: showcase, borderless, retro frame, extended art, promos preserve exact CDN URLs', (tester) async {
      final now = DateTime.now();

      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: testDeckId,
          name: testDeckName,
          format: 'Commander',
          tcgDomain: const Value('mtg'),
          commanderName: const Value('Morophon, the Boundless'),
          cardCount: const Value(100),
          createdAt: now,
          updatedAt: Value(now),
        ),
      );

      final variants = [
        ('var_showcase', 'Brazen Borrower', 'https://cards.scryfall.io/normal/front/showcase_123.jpg'),
        ('var_borderless', 'Ragavan, Nimble Pilferer', 'https://cards.scryfall.io/normal/front/borderless_456.jpg'),
        ('var_retro', 'Lightning Bolt', 'https://cards.scryfall.io/normal/front/retro_789.jpg'),
        ('var_extended', 'Deep-Cavern Bat', 'https://cards.scryfall.io/normal/front/extended_012.jpg'),
        ('var_promo', 'Teferi, Hero of Dominaria', 'https://cards.scryfall.io/normal/front/promo_345.jpg'),
      ];

      for (final (id, cardName, url) in variants) {
        await db.into(db.exploreDeckItems).insert(
          ExploreDeckItemsCompanion.insert(
            id: id,
            exploreDeckId: testDeckId,
            cardName: cardName,
            quantity: const Value(1),
            boardZone: const Value('Mainboard'),
            typeLine: const Value('Creature'),
            imageUrl: Value(url),
          ),
        );
      }

      await tester.pumpWidget(
        buildTestApp(child: ReadOnlyDeckScreen(exploreDeckId: testDeckId)),
      );
      await tester.pumpAndSettle();

      final cachedImages = tester.widgetList<CountrCachedImage>(find.byType(CountrCachedImage)).toList();

      for (final (id, cardName, url) in variants) {
        final img = cachedImages.firstWhere((c) => c.cardName == cardName);
        expect(img.imageUrl, equals(url),
            reason: 'Variant for $cardName must retain exact printing URL');
        expect(img.cacheKey, equals('explore_item_$id'),
            reason: 'Cache key must not have _fallback for genuine variants');
      }
    });

    testWidgets('2.3 Genuine DFC and Adventure cards preserve exact printing URLs without fallback', (tester) async {
      final now = DateTime.now();

      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: testDeckId,
          name: testDeckName,
          format: 'Commander',
          tcgDomain: const Value('mtg'),
          commanderName: const Value('Morophon, the Boundless'),
          cardCount: const Value(100),
          createdAt: now,
          updatedAt: Value(now),
        ),
      );

      final dfcCards = [
        ('dfc_1', 'Delver of Secrets // Insectile Aberration', 'https://cards.scryfall.io/normal/front/delver_front.jpg'),
        ('dfc_2', 'Valki, God of Lies // Tibalt, Cosmic Impostor', 'https://cards.scryfall.io/normal/front/valki_front.jpg'),
        ('adv_1', 'Brazen Borrower // Petty Theft', 'https://cards.scryfall.io/normal/front/borrower_adventure.jpg'),
      ];

      for (final (id, cardName, url) in dfcCards) {
        await db.into(db.exploreDeckItems).insert(
          ExploreDeckItemsCompanion.insert(
            id: id,
            exploreDeckId: testDeckId,
            cardName: cardName,
            quantity: const Value(1),
            boardZone: const Value('Mainboard'),
            typeLine: const Value('Creature // Planeswalker'),
            imageUrl: Value(url),
          ),
        );
      }

      await tester.pumpWidget(
        buildTestApp(child: ReadOnlyDeckScreen(exploreDeckId: testDeckId)),
      );
      await tester.pumpAndSettle();

      final cachedImages = tester.widgetList<CountrCachedImage>(find.byType(CountrCachedImage)).toList();

      for (final (id, cardName, url) in dfcCards) {
        final img = cachedImages.firstWhere((c) => c.cardName == cardName);
        expect(img.imageUrl, equals(url),
            reason: 'Card $cardName must retain exact front face URL');
        expect(img.cacheKey, equals('explore_item_$id'));
      }
    });

    // -------------------------------------------------------------------------
    // 3. DeckBuilderScreen Adversarial Invariants
    // -------------------------------------------------------------------------
    testWidgets('3.1 DeckBuilderScreen grid cell strictly filters art series and preserves variants', (tester) async {
      final activeDeck = createTestDeck(
        id: 'deck-builder-grid-test',
        name: 'Grid Test Deck',
        format: 'Commander',
        tcgDomain: 'mtg',
      );

      final items = [
        // Art Series item
        {
          'id': 'grid-art-card',
          'vault_item_id': 'grid-art-card',
          'name': 'Grief (Art Card)',
          'set_or_series': 'AMH2',
          'image_url': 'https://cards.scryfall.io/art_series/front/grief.jpg',
          'collection_type': 'mtg',
          'vault_quantity': 1,
          'deck_quantity': 1,
          'board_zone': 'Creatures',
          'current_market_price': 20.00,
          'dynamic_data': jsonEncode({'layout': 'art_series'}),
        },
        // Genuine Showcase item
        {
          'id': 'grid-showcase-card',
          'vault_item_id': 'grid-showcase-card',
          'name': 'Brazen Borrower',
          'set_or_series': 'ELD',
          'image_url': 'https://cards.scryfall.io/normal/front/borrower_showcase.jpg',
          'collection_type': 'mtg',
          'vault_quantity': 1,
          'deck_quantity': 1,
          'board_zone': 'Creatures',
          'current_market_price': 15.00,
          'dynamic_data': jsonEncode({'layout': 'normal'}),
        },
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deckItemsProvider(activeDeck.id).overrideWith(
              (ref) => Stream.value(items),
            ),
          ],
          child: MaterialApp(
            home: DeckBuilderScreen(deck: activeDeck),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cachedImages = tester.widgetList<CountrCachedImage>(find.byType(CountrCachedImage)).toList();

      final griefImg = cachedImages.firstWhere((i) => i.cardName == 'Grief (Art Card)');
      expect(griefImg.cacheKey, equals('card_art_grid-art-card_fallback'),
          reason: 'Art series card must use fallback cache key');
      expect(griefImg.imageUrl, contains('api.scryfall.com/cards/named'));
      expect(griefImg.imageUrl, contains('Grief'));
      expect(griefImg.imageUrl, isNot(contains('Art%20Card')));
      expect(griefImg.imageUrl, contains('version=normal'));

      final brazenImg = cachedImages.firstWhere((i) => i.cardName == 'Brazen Borrower');
      expect(brazenImg.cacheKey, equals('card_art_grid-showcase-card'),
          reason: 'Genuine variant must preserve standard cache key');
      expect(brazenImg.imageUrl, equals('https://cards.scryfall.io/normal/front/borrower_showcase.jpg'),
          reason: 'Genuine variant must preserve exact CDN image URL');
    });

    // -------------------------------------------------------------------------
    // 4. PreconCardDto Model Ingestion Adversarial Tests
    // -------------------------------------------------------------------------
    test('4.1 PreconCardDto sanitizes art series cards at ingestion time', () {
      final artCardMap = {
        'name': 'The Ur-Dragon (Art Card)',
        'layout': 'art_series',
        'setCode': 'amh2',
        'type': 'Card // Card',
        'imageUrl': 'https://cards.scryfall.io/art_series/front/ur_dragon.jpg',
        'artCropUrl': 'https://cards.scryfall.io/art_series/front/ur_dragon_crop.jpg',
        'dynamicData': {
          'layout': 'art_series',
          'set': 'amh2',
        },
      };

      final dto = PreconCardDto.fromMap(artCardMap, defaultZone: 'Commander');

      expect(dto.name, equals('The Ur-Dragon'),
          reason: 'Art card name suffix must be stripped at DTO ingestion');
      expect(dto.layout, equals('normal'),
          reason: 'Layout must be normalized to normal');
      expect(dto.imageUrl, contains('api.scryfall.com/cards/named'));
      expect(dto.imageUrl, contains('The%20Ur-Dragon'));
      expect(dto.imageUrl, contains('version=normal'));
      expect(dto.artCropUrl, contains('version=art_crop'));
    });

    test('4.2 PreconCardDto strictly preserves genuine variant printings', () {
      final showcaseMap = {
        'name': 'Brazen Borrower // Petty Theft',
        'layout': 'adventure',
        'setCode': 'eld',
        'type': 'Creature — Faerie Rogue // Instant',
        'imageUrl': 'https://cards.scryfall.io/normal/front/borrower_showcase.jpg',
        'artCropUrl': 'https://cards.scryfall.io/art_crop/front/borrower_showcase.jpg',
      };

      final dto = PreconCardDto.fromMap(showcaseMap, defaultZone: 'Mainboard');

      expect(dto.name, equals('Brazen Borrower // Petty Theft'));
      expect(dto.layout, equals('adventure'));
      expect(dto.imageUrl, equals('https://cards.scryfall.io/normal/front/borrower_showcase.jpg'),
          reason: 'Genuine showcase URL must be strictly preserved');
      expect(dto.artCropUrl, equals('https://cards.scryfall.io/art_crop/front/borrower_showcase.jpg'));
    });
  });
}
