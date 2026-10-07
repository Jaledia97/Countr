import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/cache/countr_cached_image.dart';
import 'package:countr/core/cache/countr_image_cache_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FailedImageRegistry.instance.clear();
  });

  tearDown(() {
    FailedImageRegistry.instance.clear();
  });

  group('Milestone 4 Reviewer 2 Adversarial Stress Tests: Auto-Fallback & Loop Defense', () {
    testWidgets('Adv-1: Automatic post-frame transition switches from failing primary to candidateFallback without tap', (tester) async {
      const primaryUrl = 'https://example.com/art_fails.jpg';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CountrCachedImage(
              imageUrl: primaryUrl,
              cardName: 'Force of Will',
              tcgDomain: 'mtg',
              width: 36,
              height: 50,
            ),
          ),
        ),
      );

      // Frame 1: NetworkImage fails in test mode, triggering errorBuilder which schedules post-frame callback
      await tester.pump();

      // Next frame: addPostFrameCallback sets _useFallback = true and transitions to candidate fallback
      await tester.pump();

      // Settle
      await tester.pumpAndSettle();

      final imgWidgets = tester.widgetList<Image>(find.byType(Image)).toList();
      expect(imgWidgets.isNotEmpty, isTrue);
      final lastImage = imgWidgets.last;
      expect(lastImage.image, isA<NetworkImage>());
      final url = (lastImage.image as NetworkImage).url;
      expect(url, contains('api.scryfall.com/cards/named'));
      expect(url, contains('Force%20of%20Will'));
      expect(url, contains('version=normal'));
    });

    testWidgets('Adv-2: Double-fault resilience — When both primary and fallback fail, loop terminates immediately with 0 timer leaks', (tester) async {
      const primaryUrl = 'https://example.com/dead_primary.jpg';
      final fallbackUrl = CountrCachedImage.buildScryfallNamedUrl('Gaea\'s Cradle', version: 'normal');

      // Pre-mark fallback as also failed to simulate both URLs failing
      FailedImageRegistry.instance.markTerminal(fallbackUrl, statusCode: 404, type: ImageFailureType.terminalNotFound);

      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                buildCount++;
                return const CountrCachedImage(
                  imageUrl: primaryUrl,
                  cardName: 'Gaea\'s Cradle',
                  tcgDomain: 'mtg',
                  width: 36,
                  height: 50,
                  errorWidget: Text('TERMINAL_DOUBLE_FAULT'),
                );
              },
            ),
          ),
        ),
      );

      // Pump through potential post-frame callbacks
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      // Must display terminal error without infinite re-render loop
      expect(find.text('TERMINAL_DOUBLE_FAULT'), findsOneWidget);
      expect(tester.binding.transientCallbackCount, equals(0));
      // Builder should not be called in a loop
      expect(buildCount, lessThanOrEqualTo(3));
    });

    testWidgets('Adv-3: Pre-failed candidate fallback short-circuits instantly on Frame 0 with 0 callbacks', (tester) async {
      const primaryUrl = 'https://example.com/bad_primary.jpg';
      final fallbackUrl = CountrCachedImage.buildScryfallNamedUrl('Mox Diamond', version: 'normal');

      // Both primary and candidate fallback are already marked failed
      FailedImageRegistry.instance.markTerminal(primaryUrl, statusCode: 404);
      FailedImageRegistry.instance.markTerminal(fallbackUrl, statusCode: 404);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CountrCachedImage(
              imageUrl: primaryUrl,
              cardName: 'Mox Diamond',
              tcgDomain: 'mtg',
              width: 36,
              height: 50,
              errorWidget: Text('IMMEDIATE_SHORT_CIRCUIT'),
            ),
          ),
        ),
      );

      // Immediate short-circuit on frame 0
      expect(find.text('IMMEDIATE_SHORT_CIRCUIT'), findsOneWidget);
      expect(tester.binding.transientCallbackCount, equals(0));

      await tester.pumpAndSettle();
      expect(find.text('IMMEDIATE_SHORT_CIRCUIT'), findsOneWidget);
    });

    testWidgets('Adv-4: Primary URL identical to candidate fallback does not schedule loop callback', (tester) async {
      final scryfallUrl = CountrCachedImage.buildScryfallNamedUrl('Black Lotus', version: 'normal');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CountrCachedImage(
              imageUrl: scryfallUrl,
              cardName: 'Black Lotus',
              tcgDomain: 'mtg',
              width: 36,
              height: 50,
              errorWidget: const Text('ERROR_NO_LOOP'),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      // Error rendered without infinite post-frame callback oscillation
      expect(find.text('ERROR_NO_LOOP'), findsOneWidget);
      expect(tester.binding.transientCallbackCount, equals(0));
    });

    testWidgets('Adv-5: Non-MTG domain or missing card name cleanly terminates without Scryfall fallback attempt', (tester) async {
      const primaryUrl = 'https://example.com/pokemon_card.jpg';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CountrCachedImage(
              imageUrl: primaryUrl,
              cardName: 'Charizard',
              tcgDomain: 'pokemon',
              width: 36,
              height: 50,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      // Displays styled initials placeholder 'CH' (first 2 letters of single-word name)
      expect(find.text('CH'), findsOneWidget);
      // No fallback Image network requested
      expect(tester.binding.transientCallbackCount, equals(0));
    });

    testWidgets('Adv-6: Rapid unmount during scheduled post-frame callback does not throw unmounted setState error', (tester) async {
      const primaryUrl = 'https://example.com/slow_fail.jpg';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CountrCachedImage(
              imageUrl: primaryUrl,
              cardName: 'Lightning Bolt',
              tcgDomain: 'mtg',
              width: 36,
              height: 50,
            ),
          ),
        ),
      );

      // Unmount immediately before next frame runs
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox.shrink(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      // Zero exceptions thrown (mounted check guarded setState safely)
      expect(tester.takeException(), isNull);
    });

    testWidgets('Adv-7: manualRetry clears both primary and fallback from FailedImageRegistry', (tester) async {
      const primaryUrl = 'https://example.com/retry_test.jpg';
      final fallbackUrl = CountrCachedImage.buildScryfallNamedUrl('Dark Ritual', version: 'normal');

      FailedImageRegistry.instance.markTerminal(primaryUrl, statusCode: 500);
      FailedImageRegistry.instance.markTerminal(fallbackUrl, statusCode: 500);

      expect(FailedImageRegistry.instance.isFailed(primaryUrl), isTrue);
      expect(FailedImageRegistry.instance.isFailed(fallbackUrl), isTrue);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CountrCachedImage(
              imageUrl: primaryUrl,
              cardName: 'Dark Ritual',
              tcgDomain: 'mtg',
              width: 36,
              height: 50,
              errorWidget: Text('RETRY_TARGET'),
            ),
          ),
        ),
      );

      expect(find.text('RETRY_TARGET'), findsOneWidget);

      // Tap on error widget to trigger manualRetry
      await tester.tap(find.text('RETRY_TARGET'));
      await tester.pump();

      // Both primary and candidate fallback must be cleared in registry
      expect(FailedImageRegistry.instance.isFailed(primaryUrl), isFalse);
      expect(FailedImageRegistry.instance.isFailed(fallbackUrl), isFalse);
    });

    testWidgets('Adv-8: When cardId is provided, primary failure must transition to candidate fallback without being locked by primary cacheKey', (tester) async {
      const primaryUrl = 'https://example.com/broken_primary.jpg';
      const cardId = 'card-adv8-sol-ring';
      final primaryCacheKey = CountrImageCacheManager.cardArtKey(cardId);

      // Primary URL and its cacheKey failed
      FailedImageRegistry.instance.markTerminal(primaryUrl, cacheKey: primaryCacheKey, statusCode: 404);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CountrCachedImage(
              imageUrl: primaryUrl,
              cardId: cardId,
              cardName: 'Sol Ring',
              tcgDomain: 'mtg',
              width: 36,
              height: 50,
              errorWidget: Text('LOCKED_ERROR'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The candidate fallback should be rendered, NOT the error widget LOCKED_ERROR
      final imgWidgets = tester.widgetList<Image>(find.byType(Image)).toList();
      expect(imgWidgets.isNotEmpty, isTrue, reason: 'Candidate fallback should render instead of short-circuiting on primary cacheKey');
      expect(find.text('LOCKED_ERROR'), findsNothing);
    });
  });
}
