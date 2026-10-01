import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/cache/countr_cached_image.dart';
import 'package:countr/features/decks/data/mock_deck_data.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/decks/presentation/screens/deck_builder_screen.dart';
import 'package:countr/features/decks/presentation/screens/decks_screen.dart';
import 'deck_test_helpers.dart';

void main() {
  group('DecksScreen Commander Card Art & Caching Tests', () {
    testWidgets('DecksScreen renders commander card art with valid URLs and deterministic cache keys', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: DecksScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify DecksScreen renders
      expect(find.byType(DecksScreen), findsOneWidget);
      expect(find.text('Edgar Markov Aristocrats'), findsOneWidget);

      // Verify CountrCachedImage instances are rendered for commander art
      final cachedImages = tester.widgetList<CountrCachedImage>(find.byType(CountrCachedImage)).toList();
      expect(cachedImages.isNotEmpty, isTrue);

      // Verify Edgar Markov cover art
      final edgarImage = cachedImages.firstWhere(
        (img) => img.cacheKey == 'deck_cover_deck-edgar-markov',
      );
      expect(
        edgarImage.imageUrl.contains('cards.scryfall.io') ||
            edgarImage.imageUrl.contains('api.scryfall.com/cards/named'),
        isTrue,
      );
      expect(edgarImage.cacheKey, equals('deck_cover_deck-edgar-markov'));

      // Verify Yuriko cover art
      final yurikoImage = cachedImages.firstWhere(
        (img) => img.cacheKey == 'deck_cover_deck-yuriko',
      );
      expect(
        yurikoImage.imageUrl.contains('cards.scryfall.io') ||
            yurikoImage.imageUrl.contains('api.scryfall.com/cards/named'),
        isTrue,
      );
      expect(yurikoImage.cacheKey, equals('deck_cover_deck-yuriko'));
    });
  });

  group('DeckBuilderScreen Card Art Rendering & Fallbacks', () {
    final testDeck = createTestDeck(
      id: 'deck-edgar-markov',
      name: 'Edgar Markov Aristocrats',
      format: 'MTG Commander',
      createdAt: DateTime.now(),
    );

    testWidgets('DeckBuilderScreen renders card tiles with card_art cacheKey and no broken image icons', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deckItemsProvider(testDeck.id).overrideWith(
              (ref) => Stream.value(MockDeckData.getDeckItems(testDeck.id)),
            ),
          ],
          child: MaterialApp(
            home: DeckBuilderScreen(deck: testDeck),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Edgar Markov title and card items
      expect(find.text(testDeck.name), findsOneWidget);
      expect(find.text('Edgar Markov'), findsOneWidget);

      // Verify CountrCachedImage widgets exist with deterministic cache keys
      final cardImages = tester.widgetList<CountrCachedImage>(find.byType(CountrCachedImage)).toList();
      expect(cardImages.isNotEmpty, isTrue);

      final hasCardArtKey = cardImages.any(
        (img) => img.cacheKey != null && img.cacheKey!.startsWith('card_art_'),
      );
      expect(hasCardArtKey, isTrue);

      // Critical requirement: Icons.image_not_supported MUST NOT appear anywhere
      expect(find.byIcon(Icons.image_not_supported), findsNothing);
      expect(find.byIcon(Icons.image_not_supported_outlined), findsNothing);
    });

    testWidgets('DeckBuilderScreen tile extracts image from dynamic_data when image_url is missing', (tester) async {
      final customItem = {
        'id': 'card-test-dyn',
        'name': 'Dark Ritual',
        'set_or_series': 'EMA',
        'image_url': '', // Empty image_url
        'collection_type': 'mtg',
        'vault_quantity': 1,
        'deck_quantity': 1,
        'board_zone': 'Spells',
        'current_market_price': 2.50,
        'dynamic_data': '{"image_uris":{"art_crop":"https://example.com/dark_ritual_art.jpg"}}',
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deckItemsProvider('test-custom-deck').overrideWith(
              (ref) => Stream.value([customItem]),
            ),
          ],
          child: MaterialApp(
            home: DeckBuilderScreen(
              deck: createTestDeck(id: 'test-custom-deck', name: 'Test Custom Deck'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cardImages = tester.widgetList<CountrCachedImage>(find.byType(CountrCachedImage)).toList();
      final ritualImg = cardImages.firstWhere(
        (img) => img.cacheKey == 'card_art_card-test-dyn',
      );
      expect(ritualImg.imageUrl, equals('https://example.com/dark_ritual_art.jpg'));
    });

    testWidgets('DeckBuilderScreen tile falls back to Scryfall named redirect when both image_url and dynamic_data are empty', (tester) async {
      final emptyArtItem = {
        'id': 'card-test-fallback',
        'name': 'Lightning Bolt',
        'set_or_series': 'LEA',
        'image_url': '',
        'collection_type': 'mtg',
        'vault_quantity': 1,
        'deck_quantity': 1,
        'board_zone': 'Spells',
        'current_market_price': 4.00,
        'dynamic_data': '',
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deckItemsProvider('test-fallback-deck').overrideWith(
              (ref) => Stream.value([emptyArtItem]),
            ),
          ],
          child: MaterialApp(
            home: DeckBuilderScreen(
              deck: createTestDeck(id: 'test-fallback-deck', name: 'Test Fallback Deck'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cardImages = tester.widgetList<CountrCachedImage>(find.byType(CountrCachedImage)).toList();
      final boltImg = cardImages.firstWhere(
        (img) => img.cacheKey == 'card_art_card-test-fallback',
      );
      expect(boltImg.imageUrl, contains('api.scryfall.com/cards/named'));
      expect(boltImg.imageUrl, contains('Lightning%20Bolt'));
    });
  });

  group('MockDeckData URL Sanitization & Integrity Tests', () {
    test('Zero cards in Edgar Markov 100-card deck point to 404 back.jpg', () {
      final items = MockDeckData.getDeckItems('deck-edgar-markov');
      expect(items.length, equals(100));

      for (final item in items) {
        final imgUrl = item['image_url'] as String? ?? '';
        expect(imgUrl.isNotEmpty, isTrue);
        expect(imgUrl, isNot(contains('/back.jpg')));

        final dynStr = item['dynamic_data'] as String?;
        expect(dynStr, isNotNull);
        expect(dynStr, isNot(contains('/back.jpg')));
      }
    });

    test('Modern Tron deck cards do not point to 404 back.jpg or stale hashes', () {
      final tronItems = MockDeckData.getDeckItems('deck-tron');
      for (final card in tronItems) {
        final imgUrl = card['image_url'] as String? ?? '';
        expect(imgUrl.isNotEmpty, isTrue);
        expect(imgUrl, isNot(contains('/back.jpg')));
      }
    });
  });
}
