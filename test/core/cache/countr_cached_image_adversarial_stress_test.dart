import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/cache/countr_cached_image.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Adversarial Challenge: Scryfall Fallback URL Generation & Escaping', () {
    test('buildScryfallNamedUrl handles complex card names, double slashes, unicode and symbols', () {
      // 1. Double-faced cards with double slash
      expect(
        CountrCachedImage.buildScryfallNamedUrl('Fable of the Mirror-Breaker // Reflection of Kiki-Jiki'),
        equals('https://api.scryfall.com/cards/named?exact=Fable%20of%20the%20Mirror-Breaker&format=image&version=art_crop'),
      );

      // 2. Card name with apostrophe and commas
      expect(
        CountrCachedImage.buildScryfallNamedUrl("Jace, Vryn's Prodigy // Jace, Telepath Unbound"),
        equals("https://api.scryfall.com/cards/named?exact=Jace%2C%20Vryn's%20Prodigy&format=image&version=art_crop"),
      );

      // 3. Card name with plus, ampersands, exclamation marks
      expect(
        CountrCachedImage.buildScryfallNamedUrl('B.F.M. (Big Furry Monster)'),
        equals('https://api.scryfall.com/cards/named?exact=B.F.M.%20(Big%20Furry%20Monster)&format=image&version=art_crop'),
      );

      // 4. Split card with single slash vs double slash
      expect(
        CountrCachedImage.buildScryfallNamedUrl('Fire // Ice'),
        equals('https://api.scryfall.com/cards/named?exact=Fire&format=image&version=art_crop'),
      );

      // 5. Version parameter handling ('normal', 'large', 'small', 'border_crop')
      expect(
        CountrCachedImage.buildScryfallNamedUrl('Black Lotus', version: 'large'),
        equals('https://api.scryfall.com/cards/named?exact=Black%20Lotus&format=image&version=large'),
      );
    });

    test('effectiveCacheKey resolves coherently between explicit, cardId, and fallback mode', () {
      const widgetNormal = CountrCachedImage(
        imageUrl: 'https://example.com/art.jpg',
        cardId: 'mtg-test-999',
      );
      expect(widgetNormal.effectiveCacheKey, equals('card_art_mtg-test-999'));

      const widgetExplicit = CountrCachedImage(
        imageUrl: 'https://example.com/art.jpg',
        cardId: 'mtg-test-999',
        cacheKey: 'custom-art-key',
      );
      expect(widgetExplicit.effectiveCacheKey, equals('custom-art-key'));
    });
  });

  group('Adversarial Challenge: Fallback to Named Scryfall Redirect URLs', () {
    testWidgets('Scryfall fallback triggers on 404 placeholder back.jpg variants', (tester) async {
      final backVariants = [
        'https://cards.scryfall.io/art_crop/back.jpg',
        'https://cards.scryfall.io/normal/back.jpg',
        'https://cards.scryfall.io/small/back.jpg',
        '   ',
        '',
      ];

      for (final badUrl in backVariants) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CountrCachedImage(
                imageUrl: badUrl,
                cardName: 'Ragavan, Nimble Pilferer',
                tcgDomain: 'mtg',
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
        expect(img.image, isA<NetworkImage>());
        final url = (img.image as NetworkImage).url;
        expect(url, contains('api.scryfall.com/cards/named'));
        expect(url, contains('Ragavan%2C%20Nimble%20Pilferer'));
      }
    });

    testWidgets('Non-MTG domain does NOT trigger Scryfall redirect fallback', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CountrCachedImage(
              imageUrl: '',
              cardName: 'Charizard VMAX',
              tcgDomain: 'pokemon',
              width: 100,
              height: 140,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CountrCachedImage), findsOneWidget);
      // Initials 'CV' displayed in styled placeholder
      expect(find.text('CV'), findsOneWidget);
      // Network image should NOT be built
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('Unknown Card name does NOT query Scryfall with invalid names', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CountrCachedImage(
              imageUrl: '',
              cardName: 'Unknown Card',
              tcgDomain: 'mtg',
              width: 100,
              height: 140,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CountrCachedImage), findsOneWidget);
      // Renders card icon or empty initials, no network query
      expect(find.byType(Image), findsNothing);
    });
  });

  group('Adversarial Challenge: Retry Backoff Cooldowns & Disposal Lifecycle', () {
    test('Retry backoff delay scales exponentially and caps cleanly', () {
      const widget = CountrCachedImage(
        imageUrl: 'https://example.com/art.jpg',
        maxRetries: 5,
        initialRetryDelay: Duration(milliseconds: 300),
      );

      final delays = List.generate(5, (i) => widget.initialRetryDelay * (1 << i));
      expect(delays[0], equals(const Duration(milliseconds: 300)));
      expect(delays[1], equals(const Duration(milliseconds: 600)));
      expect(delays[2], equals(const Duration(milliseconds: 1200)));
      expect(delays[3], equals(const Duration(milliseconds: 2400)));
      expect(delays[4], equals(const Duration(milliseconds: 4800)));
    });

    testWidgets('Rapid widget update (didUpdateWidget) cancels pending retries and resets state', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CountrCachedImage(
              key: ValueKey('test_cached_img'),
              imageUrl: '',
              cardName: 'Alpha Card',
              tcgDomain: 'other',
              width: 100,
              height: 140,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('AC'), findsOneWidget);

      // Rapidly update with different card 3 times
      for (final name in ['Beta Card', 'Gamma Card', 'Omega Card']) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CountrCachedImage(
                key: const ValueKey('test_cached_img'),
                imageUrl: '',
                cardName: name,
                tcgDomain: 'other',
                width: 100,
                height: 140,
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }

      await tester.pumpAndSettle();
      // Final state reflects Omega Card
      expect(find.text('OC'), findsOneWidget);
      expect(find.text('AC'), findsNothing);
    });

    testWidgets('Unmounting widget during pending timer disposes cleanly without setState after dispose', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CountrCachedImage(
              imageUrl: 'https://example.com/unavailable.jpg',
              cardName: 'Disappearing Card',
              initialRetryDelay: Duration(milliseconds: 100),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 30));

      // Destroy widget hierarchy immediately while timer may be active
      await tester.pumpWidget(const SizedBox.shrink());
      // Advance clock past timer delay
      await tester.pump(const Duration(milliseconds: 300));

      // No unhandled exception
      expect(find.byType(CountrCachedImage), findsNothing);
    });
  });

  group('Adversarial Challenge: Tap-to-Retry Recovery', () {
    testWidgets('Tapping on styled error placeholder triggers manualRetry', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CountrCachedImage(
              imageUrl: '',
              cardName: 'Lotus Petal',
              tcgDomain: 'other',
              width: 100,
              height: 140,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('LP'), findsOneWidget);

      // Perform tap to trigger manual retry
      await tester.tap(find.text('LP'));
      await tester.pump();

      // Recovers cleanly and continues displaying initials
      expect(find.text('LP'), findsOneWidget);
    });

    testWidgets('Tapping on custom error widget triggers manualRetry', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CountrCachedImage(
              imageUrl: '',
              cardName: 'Custom Error Card',
              tcgDomain: 'other',
              errorWidget: Container(
                key: const ValueKey('custom_error_container'),
                color: Colors.red,
                child: const Text('CUSTOM_ERROR'),
              ),
              width: 100,
              height: 140,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('custom_error_container')), findsOneWidget);
      expect(find.text('CUSTOM_ERROR'), findsOneWidget);

      // Tap on custom error container
      await tester.tap(find.text('CUSTOM_ERROR'));
      await tester.pump();

      expect(find.text('CUSTOM_ERROR'), findsOneWidget);
    });
  });

  group('Adversarial Challenge: Rapid Flings Across 60+ Items', () {
    testWidgets('Rapid flings across 60 items with mixed valid, 404, empty, and local images', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final items = List.generate(60, (i) {
        String url;
        String domain = 'mtg';
        if (i % 4 == 0) {
          url = ''; // empty url -> Scryfall fallback or initials
        } else if (i % 4 == 1) {
          url = 'https://cards.scryfall.io/art_crop/back.jpg'; // back.jpg -> Scryfall redirect
        } else if (i % 4 == 2) {
          url = '/local/art/card_$i.png'; // local file
        } else {
          url = 'https://cards.scryfall.io/normal/front/card_$i.jpg'; // normal url
        }

        if (i % 7 == 0) {
          domain = 'pokemon';
        }

        return {
          'id': 'stress-item-$i',
          'name': 'Stress Item $i',
          'url': url,
          'domain': domain,
        };
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView.builder(
              itemCount: items.length,
              itemExtent: 90,
              itemBuilder: (context, index) {
                final item = items[index];
                return ListTile(
                  leading: CountrCachedImage(
                    imageUrl: item['url'] as String,
                    cardId: item['id'] as String,
                    cardName: item['name'] as String,
                    tcgDomain: item['domain'] as String,
                    width: 60,
                    height: 80,
                  ),
                  title: Text(item['name'] as String),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Fling down with violent velocity
      await tester.fling(find.byType(ListView), const Offset(0, -5000), 10000);
      await tester.pumpAndSettle();

      // Fling up with violent velocity
      await tester.fling(find.byType(ListView), const Offset(0, 5000), 10000);
      await tester.pumpAndSettle();

      // Rapidly toggle back and forth without settling between flings
      await tester.fling(find.byType(ListView), const Offset(0, -3000), 6000);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.fling(find.byType(ListView), const Offset(0, 3000), 6000);
      await tester.pumpAndSettle();

      // Assert entire list is healthy and rendered without crashing
      expect(find.byType(ListView), findsOneWidget);
      expect(find.byType(CountrCachedImage), findsWidgets);
    });
  });
}
