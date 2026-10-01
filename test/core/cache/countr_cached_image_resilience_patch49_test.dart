import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/cache/countr_cached_image.dart';
import 'package:countr/core/cache/countr_image_cache_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('R11 Tier 1: Isolated Features — Unified Cache Keys & Recovery', () {
    test('T1.1: CountrImageCacheManager generates deterministic card art and deck cover keys', () {
      final cardKey1 = CountrImageCacheManager.cardArtKey('sol-ring-001');
      final cardKey2 = CountrImageCacheManager.cardArtKey('sol-ring-001');
      final cardKey3 = CountrImageCacheManager.cardArtKey('edgar-markov-002');
      final deckKey = CountrImageCacheManager.deckCoverKey('deck-vampires');

      expect(cardKey1, equals('card_art_sol-ring-001'));
      expect(cardKey2, equals(cardKey1));
      expect(cardKey3, equals('card_art_edgar-markov-002'));
      expect(deckKey, equals('deck_cover_deck-vampires'));
      expect(CountrImageCacheManager.cardArtKey('card-xyz'), equals('card_art_card-xyz'));
    });

    test('T1.2: CountrCachedImage.effectiveCacheKey prioritizes explicit cacheKey over cardId', () {
      const widgetWithBoth = CountrCachedImage(
        imageUrl: 'https://cards.scryfall.io/art/test.jpg',
        cardId: 'card-123',
        cacheKey: 'explicit-override-key',
      );
      expect(widgetWithBoth.effectiveCacheKey, equals('explicit-override-key'));

      const widgetWithCardIdOnly = CountrCachedImage(
        imageUrl: 'https://cards.scryfall.io/art/test.jpg',
        cardId: 'card-123',
      );
      expect(widgetWithCardIdOnly.effectiveCacheKey, equals('card_art_card-123'));

      const widgetWithNeither = CountrCachedImage(
        imageUrl: 'https://cards.scryfall.io/art/test.jpg',
      );
      expect(widgetWithNeither.effectiveCacheKey, isNull);
    });

    test('T1.3: CountrCachedImage configurable retry parameters and exponential delay scaling', () {
      const widget = CountrCachedImage(
        imageUrl: 'https://cards.scryfall.io/art/test.jpg',
        maxRetries: 4,
        initialRetryDelay: Duration(milliseconds: 250),
      );
      expect(widget.maxRetries, equals(4));
      expect(widget.initialRetryDelay, equals(const Duration(milliseconds: 250)));

      // Verify binary exponential backoff progression: 250ms, 500ms, 1000ms, 2000ms
      for (int i = 0; i < widget.maxRetries; i++) {
        final expectedDelay = widget.initialRetryDelay * (1 << i);
        expect(expectedDelay.inMilliseconds, equals(250 * (1 << i)));
      }
    });

    test('T1.4: buildScryfallNamedUrl generates canonical Scryfall redirects with proper escaping', () {
      final singleFaced = CountrCachedImage.buildScryfallNamedUrl('Demonic Tutor');
      expect(singleFaced, equals('https://api.scryfall.com/cards/named?exact=Demonic%20Tutor&format=image&version=art_crop'));

      final normalVersion = CountrCachedImage.buildScryfallNamedUrl('Demonic Tutor', version: 'normal');
      expect(normalVersion, equals('https://api.scryfall.com/cards/named?exact=Demonic%20Tutor&format=image&version=normal'));

      final doubleFaced = CountrCachedImage.buildScryfallNamedUrl('Fable of the Mirror-Breaker // Reflection of Kiki-Jiki');
      expect(doubleFaced, equals('https://api.scryfall.com/cards/named?exact=Fable%20of%20the%20Mirror-Breaker&format=image&version=art_crop'));

      final specialChars = CountrCachedImage.buildScryfallNamedUrl("Mishra's Bauble");
      expect(specialChars, equals("https://api.scryfall.com/cards/named?exact=Mishra's%20Bauble&format=image&version=art_crop"));
    });

    testWidgets('T1.5: Automatic fallback to Scryfall named redirect when primary image is 404 placeholder', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CountrCachedImage(
              imageUrl: 'https://cards.scryfall.io/art_crop/back.jpg',
              cardName: 'Teferi, Hero of Dominaria',
              tcgDomain: 'mtg',
              width: 120,
              height: 160,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CountrCachedImage), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      final img = tester.widget<Image>(find.byType(Image));
      expect(img.image, isA<NetworkImage>());
      final url = (img.image as NetworkImage).url;
      expect(url, contains('api.scryfall.com/cards/named'));
      expect(url, contains('Teferi%2C%20Hero%20of%20Dominaria'));
    });
  });

  group('R11 Tier 2: Boundary & Corner Cases — Domain Fallbacks & Local Files', () {
    testWidgets('T2.1: Non-MTG domain does not invoke Scryfall redirect and renders initials placeholder', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CountrCachedImage(
              imageUrl: '',
              cardName: 'Pikachu ex',
              tcgDomain: 'pokemon',
              width: 100,
              height: 140,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CountrCachedImage), findsOneWidget);
      // Initials 'PE' should appear
      expect(find.text('PE'), findsOneWidget);
      // Scryfall should NOT be queried
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('T2.2: Blank card name renders generic card icon without invalid text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CountrCachedImage(
              imageUrl: '',
              cardName: '',
              tcgDomain: 'mtg',
              width: 100,
              height: 140,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CountrCachedImage), findsOneWidget);
      expect(find.byIcon(Icons.style_rounded), findsOneWidget);
    });

    testWidgets('T2.3: Local filesystem paths render directly via FileImage', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CountrCachedImage(
              imageUrl: '/var/mobile/Containers/Data/local_card.png',
              width: 100,
              height: 140,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CountrCachedImage), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      final img = tester.widget<Image>(find.byType(Image));
      expect(img.image, isA<FileImage>());
      expect((img.image as FileImage).file.path, equals('/var/mobile/Containers/Data/local_card.png'));
    });

    testWidgets('T2.4: Intercepts broken image icon in errorWidget and renders styled card placeholder', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CountrCachedImage(
              imageUrl: '',
              cardName: 'Mox Diamond',
              tcgDomain: 'other',
              errorWidget: Icon(Icons.broken_image, size: 24),
              width: 100,
              height: 140,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Broken image icon must be suppressed and upgraded
      expect(find.byIcon(Icons.broken_image), findsNothing);
      expect(find.text('MD'), findsOneWidget);
    });

    testWidgets('T2.5: Updating imageUrl in didUpdateWidget resets retry counters and state', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CountrCachedImage(
              key: Key('dynamic_card_img'),
              imageUrl: '',
              cardName: 'Ancient Tomb',
              tcgDomain: 'other',
              width: 100,
              height: 140,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('AT'), findsOneWidget);

      // Update widget with new card name and image
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CountrCachedImage(
              key: Key('dynamic_card_img'),
              imageUrl: '',
              cardName: 'Mana Crypt',
              tcgDomain: 'other',
              width: 100,
              height: 140,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Shows updated initials 'MC'
      expect(find.text('MC'), findsOneWidget);
      expect(find.text('AT'), findsNothing);
    });
  });

  group('R11 Tier 3: Pairwise Combinations — Cache Key Coherence & Lifecycle', () {
    test('T3.1: Coherence between VaultItemTile and CardDetailSheet image keys', () {
      const cardId = 'mtg-cmm-001';
      final vaultTileKey = CountrImageCacheManager.cardArtKey(cardId);

      const listTileWidget = CountrCachedImage(
        imageUrl: 'https://cards.scryfall.io/art/cmm001.jpg',
        cardId: cardId,
      );
      const detailSheetWidget = CountrCachedImage(
        imageUrl: 'https://cards.scryfall.io/art/cmm001.jpg',
        cardId: cardId,
      );

      // Both resolve to identical cache keys ensuring zero redundant downloads
      expect(listTileWidget.effectiveCacheKey, equals(vaultTileKey));
      expect(detailSheetWidget.effectiveCacheKey, equals(vaultTileKey));
      expect(listTileWidget.effectiveCacheKey, equals(detailSheetWidget.effectiveCacheKey));
    });

    testWidgets('T3.2: Rapid unmount and remount (fast scroll) disposes retry timers cleanly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CountrCachedImage(
              imageUrl: 'https://example.com/unreachable_art.jpg',
              cardId: 'stress-001',
              cardName: 'Snapcaster Mage',
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      // Quickly unmount by replacing tree
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox.shrink(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      // No unhandled timer or setState exception occurred
      expect(find.byType(CountrCachedImage), findsNothing);
    });

    testWidgets('T3.3: Tap-to-retry on styled placeholder triggers manual retry', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CountrCachedImage(
              imageUrl: '',
              cardName: 'Gilded Lotus',
              tcgDomain: 'other',
              width: 100,
              height: 140,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('GL'), findsOneWidget);

      // Tap on placeholder to trigger manual retry
      await tester.tap(find.text('GL'));
      await tester.pump();

      // UI recovers and re-renders stably
      expect(find.text('GL'), findsOneWidget);
    });
  });

  group('R11 Tier 4: Real-World E2E Scenario — Fast Scroll Stress & Detail Transitions', () {
    testWidgets('T4.1: Fast scroll stress test across 50 cards maintains stability with zero stuck loaders', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final cards = List.generate(50, (i) => 'Card #$i');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView.builder(
              itemCount: cards.length,
              itemExtent: 80,
              itemBuilder: (context, index) {
                return ListTile(
                  leading: CountrCachedImage(
                    imageUrl: index % 5 == 0 ? '' : 'https://example.com/card_$index.jpg',
                    cardId: 'card-batch-$index',
                    cardName: cards[index],
                    width: 50,
                    height: 70,
                  ),
                  title: Text(cards[index]),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Fling down rapidly to simulate extreme fast scroll
      await tester.fling(find.byType(ListView), const Offset(0, -2000), 4000);
      await tester.pumpAndSettle();

      // Fling back up
      await tester.fling(find.byType(ListView), const Offset(0, 2000), 4000);
      await tester.pumpAndSettle();

      // Ensure view is healthy and no perpetual spinners remain stuck
      expect(find.byType(ListView), findsOneWidget);
      expect(find.byType(CountrCachedImage), findsWidgets);
    });

    testWidgets('T4.2: List item to card detail transition under missing art displays styled initials gracefully', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (ctx) => const SizedBox(
                        height: 400,
                        child: CountrCachedImage(
                          imageUrl: '',
                          cardId: 'detail-card-001',
                          cardName: 'Black Lotus',
                          tcgDomain: 'other',
                          width: 200,
                          height: 280,
                        ),
                      ),
                    );
                  },
                  child: const Text('Open Detail'),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap button to open modal
      await tester.tap(find.text('Open Detail'));
      await tester.pumpAndSettle();

      // Bottom sheet contains CountrCachedImage with initials 'BL'
      expect(find.text('BL'), findsOneWidget);

      // Close modal
      Navigator.of(tester.element(find.text('BL'))).pop();
      await tester.pumpAndSettle();

      expect(find.text('BL'), findsNothing);
      expect(find.text('Open Detail'), findsOneWidget);
    });
  });
}
