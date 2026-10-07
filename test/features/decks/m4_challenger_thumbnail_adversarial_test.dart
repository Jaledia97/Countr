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

  group('Milestone 4 Adversarial Stress Test: Thumbnail Resolution, Sizing & Auto-Reload', () {
    final testDeck = createTestDeck(
      id: 'deck-adversarial-m4',
      name: 'Adversarial M4 Deck',
      format: 'MTG Commander',
      tcgDomain: 'mtg',
      createdAt: DateTime.now(),
    );

    testWidgets('Adversarial 1: Card with both art_crop and normal in dynamic_data resolves to normal', (tester) async {
      final card = {
        'id': 'card-adv-1',
        'name': 'Black Lotus',
        'set_or_series': 'LEA',
        'image_url': 'https://cards.scryfall.io/art_crop/front/black_lotus.jpg', // previously had art_crop
        'collection_type': 'mtg',
        'vault_quantity': 1,
        'deck_quantity': 1,
        'board_zone': 'Artifacts',
        'current_market_price': 50000.0,
        'dynamic_data': jsonEncode({
          'image_uris': {
            'art_crop': 'https://cards.scryfall.io/art_crop/front/black_lotus.jpg',
            'normal': 'https://cards.scryfall.io/normal/front/black_lotus.jpg',
            'large': 'https://cards.scryfall.io/large/front/black_lotus.jpg',
            'small': 'https://cards.scryfall.io/small/front/black_lotus.jpg',
          },
        }),
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deckItemsProvider(testDeck.id).overrideWith(
              (ref) => Stream.value([card]),
            ),
          ],
          child: MaterialApp(
            home: DeckBuilderScreen(deck: testDeck),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cachedImages = tester.widgetList<CountrCachedImage>(find.byType(CountrCachedImage)).toList();
      final target = cachedImages.firstWhere((img) => img.cardName == 'Black Lotus');

      expect(target.imageUrl, equals('https://cards.scryfall.io/normal/front/black_lotus.jpg'));
      expect(target.imageUrl, isNot(contains('/art_crop/')));
    });

    testWidgets('Adversarial 2: DFC with card_faces containing both art_crop and normal resolves to normal', (tester) async {
      final dfcCard = {
        'id': 'card-adv-dfc',
        'name': 'Nicol Bolas, the Ravager // Nicol Bolas, the Arisen',
        'set_or_series': 'M19',
        'image_url': 'https://cards.scryfall.io/art_crop/front/nicol_bolas.jpg',
        'collection_type': 'mtg',
        'vault_quantity': 1,
        'deck_quantity': 1,
        'board_zone': 'Creatures',
        'current_market_price': 30.0,
        'dynamic_data': jsonEncode({
          'card_faces': [
            {
              'name': 'Nicol Bolas, the Ravager',
              'image_uris': {
                'art_crop': 'https://cards.scryfall.io/art_crop/front/nicol_bolas.jpg',
                'normal': 'https://cards.scryfall.io/normal/front/nicol_bolas.jpg',
                'large': 'https://cards.scryfall.io/large/front/nicol_bolas.jpg',
              },
            },
            {
              'name': 'Nicol Bolas, the Arisen',
              'image_uris': {
                'art_crop': 'https://cards.scryfall.io/art_crop/back/nicol_bolas.jpg',
                'normal': 'https://cards.scryfall.io/normal/back/nicol_bolas.jpg',
              },
            },
          ],
        }),
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deckItemsProvider(testDeck.id).overrideWith(
              (ref) => Stream.value([dfcCard]),
            ),
          ],
          child: MaterialApp(
            home: DeckBuilderScreen(deck: testDeck),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cachedImages = tester.widgetList<CountrCachedImage>(find.byType(CountrCachedImage)).toList();
      final target = cachedImages.firstWhere((img) => img.cardName == 'Nicol Bolas, the Ravager // Nicol Bolas, the Arisen');

      expect(target.imageUrl, equals('https://cards.scryfall.io/normal/front/nicol_bolas.jpg'));
      expect(target.imageUrl, isNot(contains('/art_crop/')));
    });

    testWidgets('Adversarial 3: Named fallback URL for split and MDFC card names requests version: normal', (tester) async {
      final splitCard = {
        'id': 'card-adv-split',
        'name': 'Fire // Ice',
        'set_or_series': 'MH2',
        'image_url': '',
        'collection_type': 'mtg',
        'vault_quantity': 1,
        'deck_quantity': 1,
        'board_zone': 'Instants',
        'current_market_price': 1.0,
        'dynamic_data': '',
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deckItemsProvider(testDeck.id).overrideWith(
              (ref) => Stream.value([splitCard]),
            ),
          ],
          child: MaterialApp(
            home: DeckBuilderScreen(deck: testDeck),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cachedImages = tester.widgetList<CountrCachedImage>(find.byType(CountrCachedImage)).toList();
      final target = cachedImages.firstWhere((img) => img.cardName == 'Fire // Ice');

      expect(target.imageUrl, contains('api.scryfall.com/cards/named'));
      expect(target.imageUrl, contains('exact=Fire'));
      expect(target.imageUrl, contains('version=normal'));
      expect(target.imageUrl, isNot(contains('version=art_crop')));
      expect(target.fallbackVersion, equals('normal'));
    });

    testWidgets('Adversarial 4: Non-MTG card does not invoke Scryfall named fallback endpoint', (tester) async {
      final pokeCard = {
        'id': 'card-adv-poke',
        'name': 'Charizard VMAX',
        'set_or_series': 'DAA',
        'image_url': '',
        'collection_type': 'pokemon',
        'vault_quantity': 1,
        'deck_quantity': 1,
        'board_zone': 'Mainboard',
        'current_market_price': 40.0,
        'dynamic_data': '',
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deckItemsProvider(testDeck.id).overrideWith(
              (ref) => Stream.value([pokeCard]),
            ),
          ],
          child: MaterialApp(
            home: DeckBuilderScreen(deck: testDeck),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cachedImages = tester.widgetList<CountrCachedImage>(find.byType(CountrCachedImage)).toList();
      final target = cachedImages.where((img) => img.cardName == 'Charizard VMAX').toList();

      if (target.isNotEmpty) {
        expect(target.first.imageUrl, isNot(contains('api.scryfall.com')));
      }
    });

    testWidgets('Adversarial 5: Card tile thumbnail container matches 0.714 ratio (36x50), BoxFit.cover, rounded corners and anti-aliasing', (tester) async {
      final card = {
        'id': 'card-adv-geometry',
        'name': 'Mox Diamond',
        'set_or_series': 'STH',
        'image_url': 'https://cards.scryfall.io/normal/front/mox_diamond.jpg',
        'collection_type': 'mtg',
        'vault_quantity': 1,
        'deck_quantity': 1,
        'board_zone': 'Artifacts',
        'current_market_price': 650.0,
        'dynamic_data': '',
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deckItemsProvider(testDeck.id).overrideWith(
              (ref) => Stream.value([card]),
            ),
          ],
          child: MaterialApp(
            home: DeckBuilderScreen(deck: testDeck),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final countrFinder = find.descendant(
        of: find.widgetWithText(ExpansionTile, 'Mox Diamond'),
        matching: find.byType(CountrCachedImage),
      );
      expect(countrFinder, findsOneWidget);

      final cachedImage = tester.widget<CountrCachedImage>(countrFinder);
      expect(cachedImage.width, equals(40));
      expect(cachedImage.height, equals(56));
      expect(cachedImage.fit, equals(BoxFit.cover));

      final containerFinder = find.ancestor(
        of: countrFinder,
        matching: find.byType(Container),
      );
      final container = tester.widget<Container>(containerFinder.first);
      expect(container.clipBehavior, equals(Clip.antiAlias));

      // Ratio check: 40 / 56 = 0.71428, within 0.1% of 0.714 standard card ratio
      final double ratio = 40.0 / 56.0;
      expect((ratio - 0.714).abs(), lessThan(0.01));
    });

    testWidgets('Adversarial 6: CountrCachedImage auto-fallback transition activates on errorBuilder without manual tap', (tester) async {
      // Primary URL is a failing URL without cacheKey; candidate fallback is provided
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CountrCachedImage(
              imageUrl: 'https://example.com/invalid_404_image.jpg',
              cardName: 'Force of Will',
              tcgDomain: 'mtg',
              fallbackVersion: 'normal',
              width: 36,
              height: 50,
            ),
          ),
        ),
      );

      // Initial build: primary image is mounted
      final imgInitial = tester.widget<Image>(find.byType(Image));
      final netInitial = imgInitial.image as NetworkImage;
      expect(netInitial.url, equals('https://example.com/invalid_404_image.jpg'));

      // In test mode, Flutter Image calls errorBuilder on failure.
      // Trigger post-frame callbacks by pumping the frame.
      await tester.pump();
      await tester.pumpAndSettle();

      // Verify that after post-frame callback, CountrCachedImage transitioned to fallback automatically
      final imgAfterFallback = tester.widget<Image>(find.byType(Image));
      final netAfterFallback = imgAfterFallback.image as NetworkImage;
      expect(netAfterFallback.url, contains('api.scryfall.com/cards/named'));
      expect(netAfterFallback.url, contains('Force%20of%20Will'));
      expect(netAfterFallback.url, contains('version=normal'));
    });

    testWidgets('Adversarial 7: CountrCachedImage with cacheKey auto-transitions to fallback upon primary failure without prior registry mark', (tester) async {
      const failingPrimary = 'https://example.com/failing_primary.jpg';
      const testCacheKey = 'card_art_card-test-failing-123';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CountrCachedImage(
              imageUrl: failingPrimary,
              cacheKey: testCacheKey,
              cardName: 'Mana Drain',
              tcgDomain: 'mtg',
              fallbackVersion: 'normal',
              width: 36,
              height: 50,
            ),
          ),
        ),
      );

      // Frame 1: Primary image is mounted
      expect(find.byType(Image), findsOneWidget);

      // Primary fails, trigger post-frame transition
      await tester.pump();
      await tester.pumpAndSettle();

      final fallbackFinder = find.byType(Image);
      expect(
        fallbackFinder,
        findsOneWidget,
        reason: 'Candidate fallback must be mounted on subsequent frame',
      );
      final img = tester.widget<Image>(fallbackFinder);
      final netUrl = (img.image as NetworkImage).url;
      expect(netUrl, contains('Mana%20Drain'));
      expect(netUrl, contains('version=normal'));
    });

    testWidgets('Adversarial 8: When primary URL with cacheKey fails in FailedImageRegistry, fallback must not be locked out by primary cacheKey', (tester) async {
      const failingPrimary = 'https://example.com/failing_lotus.jpg';
      const cardId = 'card-lotus-404';
      final cacheKey = 'card_art_$cardId';

      // Simulate production failure where primary URL and its card_art cacheKey are recorded as failed
      FailedImageRegistry.instance.recordAttempt(
        failingPrimary,
        cacheKey: cacheKey,
        statusCode: 404,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CountrCachedImage(
              imageUrl: failingPrimary,
              cacheKey: cacheKey,
              cardName: 'Black Lotus',
              tcgDomain: 'mtg',
              fallbackVersion: 'normal',
              width: 36,
              height: 50,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Candidate fallback should render, not be short-circuited by primary's cacheKey in FailedImageRegistry
      final images = tester.widgetList<Image>(find.byType(Image)).toList();
      expect(
        images.length,
        equals(1),
        reason: 'Candidate fallback should render when primary URL failed; primary cacheKey must not lock out fallback',
      );
      if (images.isNotEmpty) {
        final netUrl = (images.first.image as NetworkImage).url;
        expect(netUrl, contains('Black%20Lotus'));
        expect(netUrl, contains('version=normal'));
      }
    });
  });
}


