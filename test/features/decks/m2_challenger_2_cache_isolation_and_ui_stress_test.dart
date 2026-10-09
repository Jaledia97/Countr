// Copyright (c) 2026 Countr. All rights reserved.
// Challenger M2-2 Empirical Stress Test: Cache Key Isolation & UI Robustness.

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:countr/core/cache/countr_cached_image.dart';
import 'package:countr/core/cache/countr_image_cache_manager.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/decks/data/daos/explore_deck_dao.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/decks/presentation/providers/explore_deck_providers.dart';
import 'package:countr/features/decks/presentation/screens/read_only_deck_screen.dart';
import 'package:countr/features/decks/presentation/screens/deck_builder_screen.dart';
import 'package:countr/features/symbology/presentation/widgets/mana_cost_bar.dart';
import 'deck_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory mockCacheDir;
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    mockCacheDir = Directory.systemTemp.createTempSync('countr_challenger_cache_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (MethodCall methodCall) async {
      return mockCacheDir.path;
    });
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    if (mockCacheDir.existsSync()) {
      try {
        mockCacheDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  late AppDatabase db;
  late VaultDao vaultDao;
  late ExploreDeckDao exploreDao;

  const testDeckId = 'challenger_m2_2_stress_deck';
  const testDeckName = 'Challenger M2-2 Stress Test Deck';

  setUp(() async {
    FailedImageRegistry.instance.clear();
    db = AppDatabase(NativeDatabase.memory());
    vaultDao = VaultDao(db);
    exploreDao = ExploreDeckDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildTestApp({
    required Widget child,
    Size viewportSize = const Size(400, 800),
  }) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        vaultDaoProvider.overrideWithValue(vaultDao),
        exploreDeckDaoProvider.overrideWithValue(exploreDao),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: viewportSize),
          child: child,
        ),
      ),
    );
  }

  Future<void> seedBaseExploreDeck({double estimatedPrice = 120.0}) async {
    final now = DateTime.now();
    await db.into(db.exploreDecks).insert(
      ExploreDecksCompanion.insert(
        id: testDeckId,
        name: testDeckName,
        format: 'Commander',
        tcgDomain: const Value('mtg'),
        commanderName: const Value('Morophon, the Boundless'),
        commanderArtCrop: const Value('https://cards.scryfall.io/art_crop/front/morophon.jpg'),
        cardCount: const Value(100),
        estimatedPrice: Value(estimatedPrice),
        createdAt: now,
        updatedAt: Value(now),
      ),
    );
  }

  group('Group 1: Cache Key Isolation & Multi-Variant Printing Resolution', () {
    test('1.1 card_art_\${cardId}_fallback strictly isolates disk cache from standard card_art_\${cardId}', () async {
      final cacheManager = CountrImageCacheManager.instance;
      const testCardId = 'test_art_series_card_uuid_999';
      final standardKey = CountrImageCacheManager.cardArtKey(testCardId);
      final fallbackKey = '${standardKey}_fallback';

      expect(standardKey, equals('card_art_test_art_series_card_uuid_999'));
      expect(fallbackKey, equals('card_art_test_art_series_card_uuid_999_fallback'));

      // Put dummy bytes under standardKey
      await cacheManager.putFile(
        'https://cards.scryfall.io/art_series/front/dummy_art.jpg',
        utf8.encode('DUMMY_ART_SERIES_IMAGE_BYTES'),
        key: standardKey,
      );

      // Verify standardKey exists in disk cache
      final standardInfo = await cacheManager.getFileFromCache(standardKey);
      expect(standardInfo, isNotNull, reason: 'Standard key must exist in cache');

      // Verify fallbackKey does NOT hit the standard art series cache entry
      final fallbackInfo = await cacheManager.getFileFromCache(fallbackKey);
      expect(fallbackInfo, isNull,
          reason: 'Fallback key must NOT collide with or resolve from standard art series cache entry');

      // Verify aliases map does not cross-link standardKey and fallbackKey
      expect(cacheManager.resolveKeyAliases(standardKey).contains(fallbackKey), isFalse);
      expect(cacheManager.resolveKeyAliases(fallbackKey).contains(standardKey), isFalse);

      // Clean up test entries
      await cacheManager.removeFile(standardKey);
      await cacheManager.removeFile(fallbackKey);
    });

    testWidgets('1.2 ReadOnlyDeckScreen preserves exact variant printings when a deck contains multiple printings of the same card name', (tester) async {
      await seedBaseExploreDeck();

      // Seed 4 distinct printings of "Lightning Bolt" from 4 different sets
      final variants = [
        {
          'id': 'bolt_lea_alpha',
          'name': 'Lightning Bolt',
          'url': 'https://cards.scryfall.io/normal/front/bolt_lea.jpg',
          'zone': 'Instants & Sorceries',
        },
        {
          'id': 'bolt_3ed_revised',
          'name': 'Lightning Bolt',
          'url': 'https://cards.scryfall.io/normal/front/bolt_3ed.jpg',
          'zone': 'Instants & Sorceries',
        },
        {
          'id': 'bolt_mm2_modern',
          'name': 'Lightning Bolt',
          'url': 'https://cards.scryfall.io/normal/front/bolt_mm2.jpg',
          'zone': 'Instants & Sorceries',
        },
        {
          'id': 'bolt_retro_frame',
          'name': 'Lightning Bolt',
          'url': 'https://cards.scryfall.io/normal/front/bolt_retro.jpg',
          'zone': 'Instants & Sorceries',
        },
      ];

      for (final v in variants) {
        await db.into(db.exploreDeckItems).insert(
          ExploreDeckItemsCompanion.insert(
            id: v['id']!,
            exploreDeckId: testDeckId,
            cardName: v['name']!,
            quantity: const Value(1),
            boardZone: Value(v['zone']!),
            typeLine: const Value('Instant'),
            imageUrl: Value(v['url']!),
          ),
        );
      }

      await tester.pumpWidget(
        buildTestApp(
          child: ReadOnlyDeckScreen(exploreDeckId: testDeckId),
        ),
      );
      await tester.pumpAndSettle();

      final cachedImages = tester.widgetList<CountrCachedImage>(find.byType(CountrCachedImage)).toList();
      final boltImages = cachedImages.where((img) => img.cardName == 'Lightning Bolt').toList();

      expect(boltImages.length, equals(4),
          reason: 'All 4 Lightning Bolt variants must be rendered in ReadOnlyDeckScreen');

      // Verify each variant retains its unique URL and unique item cache key
      for (final v in variants) {
        final matched = boltImages.firstWhere(
          (img) => img.imageUrl == v['url'] && img.cacheKey == 'explore_item_${v['id']}',
        );
        expect(matched.imageUrl, equals(v['url']));
        expect(matched.cacheKey, equals('explore_item_${v['id']}'));
      }
    });

    testWidgets('1.3 DeckBuilderScreen preserves exact variant printings across multiple copies of the same card name', (tester) async {
      final activeDeck = createTestDeck(
        id: 'deck-multi-variant-test',
        name: 'Multi Variant Deck',
        format: 'Modern',
        tcgDomain: 'mtg',
      );

      final variants = [
        {
          'id': 'item-bolt-1',
          'vault_item_id': 'v-bolt-1',
          'name': 'Lightning Bolt',
          'image_url': 'https://cards.scryfall.io/normal/front/bolt_lea.jpg',
          'set_or_series': 'lea',
          'quantity': 1,
          'deck_quantity': 1,
        },
        {
          'id': 'item-bolt-2',
          'vault_item_id': 'v-bolt-2',
          'name': 'Lightning Bolt',
          'image_url': 'https://cards.scryfall.io/normal/front/bolt_3ed.jpg',
          'set_or_series': '3ed',
          'quantity': 1,
          'deck_quantity': 1,
        },
        {
          'id': 'item-bolt-3',
          'vault_item_id': 'v-bolt-3',
          'name': 'Lightning Bolt',
          'image_url': 'https://cards.scryfall.io/normal/front/bolt_mm2.jpg',
          'set_or_series': 'mm2',
          'quantity': 1,
          'deck_quantity': 1,
        },
        {
          'id': 'item-bolt-4',
          'vault_item_id': 'v-bolt-4',
          'name': 'Lightning Bolt',
          'image_url': 'https://cards.scryfall.io/normal/front/bolt_retro.jpg',
          'set_or_series': 'retro',
          'quantity': 1,
          'deck_quantity': 1,
        },
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(vaultDao),
            deckItemsProvider(activeDeck.id).overrideWith(
              (ref) => Stream.value(variants),
            ),
          ],
          child: MaterialApp(
            home: DeckBuilderScreen(deck: activeDeck),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cachedImages = tester.widgetList<CountrCachedImage>(find.byType(CountrCachedImage)).toList();
      final boltImages = cachedImages.where((img) => img.cardName == 'Lightning Bolt').toList();

      expect(boltImages.length, equals(4),
          reason: 'All 4 Lightning Bolt variants must be rendered in DeckBuilderScreen');

      for (final v in variants) {
        final matched = boltImages.firstWhere(
          (img) => img.imageUrl == v['image_url'] && img.cacheKey == 'card_art_${v['id']}',
        );
        expect(matched.imageUrl, equals(v['image_url']));
        expect(matched.cacheKey, equals('card_art_${v['id']}'));
      }
    });
  });

  group('Group 2: UI Layout Robustness & Boundary Stress Testing in ReadOnlyDeckScreen', () {
    testWidgets('2.1 Extreme card names (100-chars, unicode emojis, split cards) do not overflow Row in standard viewports', (tester) async {
      await seedBaseExploreDeck();

      const ultraLongName = 'Our Market Research Shows That Players Like Really Long Card Names So We Made this Card to Have the Absolute Longest Name in Magic History';
      const unicodeEmojiName = '⚡️🔥 氷と炎の龍 / Dragon of Ice & Fire 🐉✨';
      const splitCardName = 'Fire // Ice';
      const dfcCardName = 'Boseiju, Who Endures // Boseiju, Who Shelters All';

      final items = [
        {
          'id': 'extreme_long',
          'name': ultraLongName,
          'mana': '{2}{R}{U}',
          'price': 4.99,
        },
        {
          'id': 'extreme_unicode',
          'name': unicodeEmojiName,
          'mana': '{3}{U}{R}',
          'price': 12.50,
        },
        {
          'id': 'extreme_split',
          'name': splitCardName,
          'mana': '{1}{R} // {1}{U}',
          'price': 1.25,
        },
        {
          'id': 'extreme_dfc',
          'name': dfcCardName,
          'mana': '{1}{G}',
          'price': 35.00,
        },
      ];

      for (final item in items) {
        await db.into(db.exploreDeckItems).insert(
          ExploreDeckItemsCompanion.insert(
            id: item['id'] as String,
            exploreDeckId: testDeckId,
            cardName: item['name'] as String,
            quantity: const Value(1),
            boardZone: const Value('Mainboard'),
            manaCost: Value(item['mana'] as String),
            price: Value(item['price'] as double),
            imageUrl: const Value('https://cards.scryfall.io/normal/front/card.jpg'),
          ),
        );
      }

      // Test on standard viewport (400x800)
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestApp(
          child: ReadOnlyDeckScreen(exploreDeckId: testDeckId),
          viewportSize: const Size(400, 800),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'Must render without layout exception on 400px width');
    });

    testWidgets('2.2 Price edge cases (null, zero, negative, ultra-large) render gracefully without invalid text', (tester) async {
      await seedBaseExploreDeck(estimatedPrice: 500000.0);

      final priceCases = [
        {
          'id': 'price_null',
          'name': 'Card Null Price',
          'price': null,
          'qty': 1,
        },
        {
          'id': 'price_zero',
          'name': 'Card Zero Price',
          'price': 0.0,
          'qty': 1,
        },
        {
          'id': 'price_negative',
          'name': 'Card Negative Price',
          'price': -4.50,
          'qty': 1,
        },
        {
          'id': 'price_huge',
          'name': 'Black Lotus Supreme',
          'price': 125000.00,
          'qty': 4,
        },
      ];

      for (final p in priceCases) {
        await db.into(db.exploreDeckItems).insert(
          ExploreDeckItemsCompanion.insert(
            id: p['id'] as String,
            exploreDeckId: testDeckId,
            cardName: p['name'] as String,
            quantity: Value(p['qty'] as int),
            boardZone: const Value('Mainboard'),
            price: Value(p['price'] as double?),
            imageUrl: const Value('https://cards.scryfall.io/normal/front/card.jpg'),
          ),
        );
      }

      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestApp(
          child: ReadOnlyDeckScreen(exploreDeckId: testDeckId),
          viewportSize: const Size(360, 640),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'Price edge cases must not crash');

      // Verify card row prices: Card row price uses AppColors.textSecondary styling
      final rowPriceTexts = tester.widgetList<Text>(
        find.byWidgetPredicate(
          (w) => w is Text && w.style?.color == AppColors.textSecondary,
        ),
      ).map((t) => t.data).toList();

      expect(rowPriceTexts.contains('\$0.00'), isFalse,
          reason: 'Zero price must not be rendered in card row');
      expect(rowPriceTexts.any((t) => t != null && t.contains('-\$')), isFalse,
          reason: 'Negative price must not be rendered in card row');

      // Verify huge price calculation: $125,000 * 4 = $500,000.00 in card row
      expect(rowPriceTexts.contains('\$500000.00'), isTrue,
          reason: 'Large price must accurately multiply quantity in card row');
    });

    testWidgets('2.3 ManaCostBar resilience under malformed, unparseable and exotic strings', (tester) async {
      final testCases = [
        '{W/U}',
        '{2/W}',
        '{C}',
        '{S}',
        '{X}',
        '{100}',
        '{NotASymbol}',
        'WUBRG',
        '{W',
        '',
        '   ',
        '{W}{U}{B}{R}{G}',
      ];

      for (final tc in testCases) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 150,
                  child: ManaCostBar(manaCost: tc),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: 'ManaCostBar should never crash or throw on "$tc"');
      }
    });

    testWidgets('2.4 Progenitus 10-symbol mana cost in 360px mobile viewport renders cleanly with zero RenderFlex overflows in ReadOnlyDeckScreen', (tester) async {
      await seedBaseExploreDeck();

      await db.into(db.exploreDeckItems).insert(
        ExploreDeckItemsCompanion.insert(
          id: 'item_progenitus_overflow',
          exploreDeckId: testDeckId,
          cardName: 'Progenitus',
          quantity: const Value(1),
          boardZone: const Value('Commander'),
          manaCost: const Value('{W}{W}{U}{U}{B}{B}{R}{R}{G}{G}'),
          price: const Value(5.50),
          imageUrl: const Value('https://cards.scryfall.io/normal/front/progenitus.jpg'),
        ),
      );

      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      String? caughtOverflowMessage;
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.summary.toString().contains('A RenderFlex overflowed')) {
          caughtOverflowMessage = details.summary.toString();
        } else {
          originalOnError?.call(details);
        }
      };
      addTearDown(() => FlutterError.onError = originalOnError);

      await tester.pumpWidget(
        buildTestApp(
          child: ReadOnlyDeckScreen(exploreDeckId: testDeckId),
          viewportSize: const Size(360, 640),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(caughtOverflowMessage, isNull,
          reason: 'Constrained ManaCostBar in ReadOnlyDeckScreen._buildCardRow must prevent RenderFlex overflow when a card has 10 mana symbols on 360px viewport');
    });

    testWidgets('2.5 Split card with long name, 6 mana symbols and price in 320px viewport renders cleanly with zero RenderFlex overflows in ReadOnlyDeckScreen', (tester) async {
      await seedBaseExploreDeck();

      await db.into(db.exploreDeckItems).insert(
        ExploreDeckItemsCompanion.insert(
          id: 'compound_stress_item',
          exploreDeckId: testDeckId,
          cardName: 'Extremely Long Split Card Name Super Special Edition // Other Side of The Ultra Long Split Card',
          quantity: const Value(4),
          boardZone: const Value('Mainboard'),
          manaCost: const Value('{2}{W/U}{B/R} // {3}{G}{G}'),
          price: const Value(25000.0),
          imageUrl: const Value('https://cards.scryfall.io/normal/front/split.jpg'),
        ),
      );

      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      String? caughtOverflowMessage;
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.summary.toString().contains('A RenderFlex overflowed')) {
          caughtOverflowMessage = details.summary.toString();
        } else {
          originalOnError?.call(details);
        }
      };
      addTearDown(() => FlutterError.onError = originalOnError);

      await tester.pumpWidget(
        buildTestApp(
          child: ReadOnlyDeckScreen(exploreDeckId: testDeckId),
          viewportSize: const Size(320, 640),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(caughtOverflowMessage, isNull,
          reason: 'Constrained ManaCostBar must prevent RenderFlex overflow on 320px viewport for compound stress split card');
    });
  });
}
