import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/cache/countr_cached_image.dart';
import 'package:countr/core/cache/failed_image_registry.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/decks/presentation/screens/deck_builder_screen.dart';
import 'deck_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FailedImageRegistry.instance.clear();
  });

  tearDown(() {
    FailedImageRegistry.instance.clear();
  });

  group('Milestone 4 (R4): Card Play Thumbnail Resolution, Full-Height Sizing & Auto-Reload Tests', () {
    final testDeck = createTestDeck(
      id: 'deck-m4-test',
      name: 'M4 Play Thumbnail Test Deck',
      format: 'MTG Commander',
      tcgDomain: 'mtg',
      createdAt: DateTime.now(),
    );

    testWidgets('DeckBuilderScreen card tile prioritizes normal/large/small card face over art_crop', (tester) async {
      final dualArtCard = {
        'id': 'card-dual-art-1',
        'name': 'Sol Ring',
        'set_or_series': 'C21',
        'image_url': 'https://cards.scryfall.io/art_crop/front/sol_ring.jpg',
        'collection_type': 'mtg',
        'vault_quantity': 1,
        'deck_quantity': 1,
        'board_zone': 'Artifacts',
        'current_market_price': 1.50,
        'dynamic_data': jsonEncode({
          'image_uris': {
            'art_crop': 'https://cards.scryfall.io/art_crop/front/sol_ring.jpg',
            'normal': 'https://cards.scryfall.io/normal/front/sol_ring.jpg',
            'large': 'https://cards.scryfall.io/large/front/sol_ring.jpg',
            'small': 'https://cards.scryfall.io/small/front/sol_ring.jpg',
          },
        }),
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deckItemsProvider(testDeck.id).overrideWith(
              (ref) => Stream.value([dualArtCard]),
            ),
          ],
          child: MaterialApp(
            home: DeckBuilderScreen(deck: testDeck),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cachedImages = tester.widgetList<CountrCachedImage>(find.byType(CountrCachedImage)).toList();
      expect(cachedImages.isNotEmpty, isTrue);

      final solRingImage = cachedImages.firstWhere(
        (img) => img.cardName == 'Sol Ring',
      );
      // Prioritizes real play card faces (normal), not art_crop!
      expect(solRingImage.imageUrl, equals('https://cards.scryfall.io/normal/front/sol_ring.jpg'));
      expect(solRingImage.fit, equals(BoxFit.cover));
      expect(solRingImage.width, equals(40));
      expect(solRingImage.height, equals(56));
    });

    testWidgets('DeckBuilderScreen card tile falls back to Scryfall named with version: normal', (tester) async {
      final namedFallbackCard = {
        'id': 'card-named-fallback-1',
        'name': 'Demonic Tutor',
        'set_or_series': 'UMA',
        'image_url': '',
        'collection_type': 'mtg',
        'vault_quantity': 1,
        'deck_quantity': 1,
        'board_zone': 'Spells',
        'current_market_price': 45.00,
        'dynamic_data': '',
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deckItemsProvider(testDeck.id).overrideWith(
              (ref) => Stream.value([namedFallbackCard]),
            ),
          ],
          child: MaterialApp(
            home: DeckBuilderScreen(deck: testDeck),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cachedImages = tester.widgetList<CountrCachedImage>(find.byType(CountrCachedImage)).toList();
      final tutorImage = cachedImages.firstWhere(
        (img) => img.cardName == 'Demonic Tutor',
      );
      // Named redirect URL must specify version=normal
      expect(tutorImage.imageUrl, contains('api.scryfall.com/cards/named'));
      expect(tutorImage.imageUrl, contains('Demonic%20Tutor'));
      expect(tutorImage.imageUrl, contains('version=normal'));
    });

    testWidgets('DeckBuilderScreen card tile strictly excludes art_series cards and falls back to standard playable printing', (tester) async {
      final artSeriesCard = {
        'id': 'art-series-card-1',
        'name': 'Esper Sentinel',
        'set_or_series': 'AMH2',
        'image_url': 'https://cards.scryfall.io/art_crop/front/esper_sentinel_art.jpg',
        'collection_type': 'mtg',
        'vault_quantity': 1,
        'deck_quantity': 1,
        'board_zone': 'Creatures',
        'current_market_price': 25.00,
        'dynamic_data': jsonEncode({
          'layout': 'art_series',
          'image_uris': {
            'normal': 'https://cards.scryfall.io/normal/front/esper_sentinel_art.jpg',
            'large': 'https://cards.scryfall.io/large/front/esper_sentinel_art.jpg',
          },
        }),
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deckItemsProvider(testDeck.id).overrideWith(
              (ref) => Stream.value([artSeriesCard]),
            ),
          ],
          child: MaterialApp(
            home: DeckBuilderScreen(deck: testDeck),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cachedImages = tester.widgetList<CountrCachedImage>(find.byType(CountrCachedImage)).toList();
      final sentinelImage = cachedImages.firstWhere(
        (img) => img.cardName == 'Esper Sentinel',
      );
      // Bypasses the art_series card image and falls back to standard playable printing!
      expect(sentinelImage.imageUrl, isNot(contains('esper_sentinel_art.jpg')));
      expect(sentinelImage.imageUrl, contains('api.scryfall.com/cards/named'));
      expect(sentinelImage.imageUrl, contains('Esper%20Sentinel'));
      expect(sentinelImage.imageUrl, contains('version=normal'));
    });

    testWidgets('DeckBuilderScreen card tile preserves intentional playable variants (showcase, borderless, retro)', (tester) async {
      final borderlessVariantCard = {
        'id': 'borderless-variant-1',
        'name': 'Force of Negation',
        'set_or_series': '2X2',
        'image_url': 'https://cards.scryfall.io/normal/front/force_of_negation_borderless.jpg',
        'collection_type': 'mtg',
        'vault_quantity': 1,
        'deck_quantity': 1,
        'board_zone': 'Instants',
        'current_market_price': 55.00,
        'dynamic_data': jsonEncode({
          'layout': 'normal',
          'border_color': 'borderless',
          'frame_effects': ['showcase'],
          'image_uris': {
            'normal': 'https://cards.scryfall.io/normal/front/force_of_negation_borderless.jpg',
          },
        }),
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deckItemsProvider(testDeck.id).overrideWith(
              (ref) => Stream.value([borderlessVariantCard]),
            ),
          ],
          child: MaterialApp(
            home: DeckBuilderScreen(deck: testDeck),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cachedImages = tester.widgetList<CountrCachedImage>(find.byType(CountrCachedImage)).toList();
      final forceImage = cachedImages.firstWhere(
        (img) => img.cardName == 'Force of Negation',
      );
      // Exact intentional playable variant must be preserved!
      expect(forceImage.imageUrl, equals('https://cards.scryfall.io/normal/front/force_of_negation_borderless.jpg'));
    });

    testWidgets('Thumbnail container fills full height (40x56) with BoxFit.cover and clipBehavior', (tester) async {
      final item = {
        'id': 'card-size-test-1',
        'name': 'Mana Crypt',
        'set_or_series': '2XM',
        'image_url': 'https://cards.scryfall.io/normal/front/mana_crypt.jpg',
        'collection_type': 'mtg',
        'vault_quantity': 1,
        'deck_quantity': 1,
        'board_zone': 'Artifacts',
        'current_market_price': 180.00,
        'dynamic_data': '',
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deckItemsProvider(testDeck.id).overrideWith(
              (ref) => Stream.value([item]),
            ),
          ],
          child: MaterialApp(
            home: DeckBuilderScreen(deck: testDeck),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final countrFinder = find.descendant(
        of: find.widgetWithText(ExpansionTile, 'Mana Crypt'),
        matching: find.byType(CountrCachedImage),
      );
      final cachedImgWidget = tester.widget<CountrCachedImage>(countrFinder.first);
      expect(cachedImgWidget.width, equals(40));
      expect(cachedImgWidget.height, equals(56));
      expect(cachedImgWidget.fit, equals(BoxFit.cover));

      final size = tester.getSize(countrFinder.first);
      expect(size.width, equals(40));
      expect(size.height, equals(56));

      // Container wrapping CountrCachedImage has width 40 and height 56
      final container = tester.widget<Container>(
        find.ancestor(
          of: countrFinder.first,
          matching: find.byType(Container),
        ).first,
      );
      expect(container.clipBehavior, equals(Clip.antiAlias));
    });

    testWidgets('Empty imageUrl with known card name mounts CountrCachedImage rather than bypassing it', (tester) async {
      final item = {
        'id': 'card-pending-art',
        'name': 'Rhystic Study',
        'set_or_series': 'JMP',
        'image_url': '',
        'collection_type': 'mtg',
        'vault_quantity': 1,
        'deck_quantity': 1,
        'board_zone': 'Enchantments',
        'current_market_price': 35.00,
        'dynamic_data': '',
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deckItemsProvider(testDeck.id).overrideWith(
              (ref) => Stream.value([item]),
            ),
          ],
          child: MaterialApp(
            home: DeckBuilderScreen(deck: testDeck),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // CountrCachedImage must be mounted for the pending art card
      final countrImages = tester.widgetList<CountrCachedImage>(find.byType(CountrCachedImage)).toList();
      final rhysticImg = countrImages.where((img) => img.cardName == 'Rhystic Study');
      expect(rhysticImg.isNotEmpty, isTrue);
      expect(rhysticImg.first.imageUrl, contains('api.scryfall.com/cards/named'));
      expect(rhysticImg.first.imageUrl, contains('version=normal'));
    });
  });
}
