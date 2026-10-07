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

  group('Adversarial Test Suite for Milestone 4 (R4)', () {
    testWidgets('Challenge 1: Primary URL runtime errorBuilder trigger transitions to candidate fallback without cardId', (tester) async {
      const primaryUrl = 'https://example.com/primary_404_no_key.jpg';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CountrCachedImage(
              imageUrl: primaryUrl,
              cardName: 'Sol Ring',
              tcgDomain: 'mtg',
              width: 36,
              height: 50,
            ),
          ),
        ),
      );

      // Frame 0: Image mounted with primary URL
      var imgFinder = find.byType(Image);
      expect(imgFinder, findsOneWidget);
      var img = tester.widget<Image>(imgFinder);
      expect((img.image as NetworkImage).url, equals(primaryUrl));
      expect(img.errorBuilder, isNotNull);

      // Invoke errorBuilder simulating network 404
      final element = tester.element(imgFinder);
      img.errorBuilder!(
        element,
        NetworkImageLoadException(statusCode: 404, uri: Uri.parse(primaryUrl)),
        StackTrace.current,
      );

      // Pump frame 1 to execute postFrameCallback (which calls setState)
      await tester.pump();
      // Pump frame 2 to execute rebuild triggered by setState
      await tester.pump();

      // Now on next frame: should be displaying candidate fallback automatically
      imgFinder = find.byType(Image);
      expect(imgFinder, findsOneWidget, reason: 'Candidate fallback should automatically render on next frame');
      img = tester.widget<Image>(imgFinder);
      final fallbackUrl = (img.image as NetworkImage).url;
      expect(fallbackUrl, contains('api.scryfall.com/cards/named'));
      expect(fallbackUrl, contains('Sol%20Ring'));
      expect(fallbackUrl, contains('version=normal'));
    });

    testWidgets('Challenge 2: Primary URL runtime errorBuilder trigger transitions to candidate fallback WITH cardId/cacheKey', (tester) async {
      const primaryUrl = 'https://example.com/primary_404_with_key.jpg';
      const cardId = 'card-sol-ring-fail';

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
            ),
          ),
        ),
      );

      // Frame 0: Image mounted with primary URL
      var imgFinder = find.byType(Image);
      expect(imgFinder, findsOneWidget);
      var img = tester.widget<Image>(imgFinder);
      expect((img.image as NetworkImage).url, equals(primaryUrl));
      expect(img.errorBuilder, isNotNull);

      // In production, when primary URL fails, errorWidget records attempt / marks terminal in FailedImageRegistry
      final cacheKey = CountrImageCacheManager.cardArtKey(cardId);
      FailedImageRegistry.instance.recordAttempt(
        primaryUrl,
        cacheKey: cacheKey,
        statusCode: 404,
      );

      // Invoke errorBuilder simulating network 404
      final element = tester.element(imgFinder);
      img.errorBuilder!(
        element,
        NetworkImageLoadException(statusCode: 404, uri: Uri.parse(primaryUrl)),
        StackTrace.current,
      );

      // Pump frame 1 to process postFrameCallback
      await tester.pump();
      // Pump frame 2 to process setState rebuild
      await tester.pump();

      // Next frame: should be candidate fallback
      imgFinder = find.byType(Image);
      expect(imgFinder, findsOneWidget, reason: 'Candidate fallback must render on next frame even when cardId/cacheKey was linked to primary failure');
      img = tester.widget<Image>(imgFinder);
      final fallbackUrl = (img.image as NetworkImage).url;
      expect(fallbackUrl, contains('api.scryfall.com/cards/named'));
      expect(fallbackUrl, contains('Sol%20Ring'));
    });

    testWidgets('Challenge 3: Dual failure (primary + fallback fail) terminates gracefully without infinite rebuild loop', (tester) async {
      const primaryUrl = 'https://example.com/dual_fail_primary.jpg';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CountrCachedImage(
              imageUrl: primaryUrl,
              cardName: 'NonExistent Card 12345',
              tcgDomain: 'mtg',
              width: 36,
              height: 50,
            ),
          ),
        ),
      );

      // 1. Primary failure
      var imgFinder = find.byType(Image);
      expect(imgFinder, findsOneWidget);
      var img = tester.widget<Image>(imgFinder);
      img.errorBuilder!(
        tester.element(imgFinder),
        NetworkImageLoadException(statusCode: 404, uri: Uri.parse(primaryUrl)),
        StackTrace.current,
      );

      // Pump next frame: fallback mounts
      await tester.pump();

      // 2. Fallback failure
      imgFinder = find.byType(Image);
      expect(imgFinder, findsOneWidget);
      img = tester.widget<Image>(imgFinder);
      final fallbackUrl = (img.image as NetworkImage).url;

      img.errorBuilder!(
        tester.element(imgFinder),
        NetworkImageLoadException(statusCode: 404, uri: Uri.parse(fallbackUrl)),
        StackTrace.current,
      );

      // Pump frames - should NOT enter an infinite post-frame callback loop
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should render error placeholder cleanly
      expect(find.byType(CountrCachedImage), findsOneWidget);
      expect(tester.binding.transientCallbackCount, equals(0));
    });

    testWidgets('Challenge 4: Candidate fallback identical to primaryUrl does not trigger loop or remount', (tester) async {
      final namedUrl = CountrCachedImage.buildScryfallNamedUrl('Demonic Tutor', version: 'normal');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CountrCachedImage(
              imageUrl: namedUrl,
              fallbackUrl: namedUrl, // Fallback identical to primary
              cardName: 'Demonic Tutor',
              tcgDomain: 'mtg',
              width: 36,
              height: 50,
            ),
          ),
        ),
      );

      var imgFinder = find.byType(Image);
      expect(imgFinder, findsOneWidget);
      var img = tester.widget<Image>(imgFinder);

      // Trigger errorBuilder
      img.errorBuilder!(
        tester.element(imgFinder),
        NetworkImageLoadException(statusCode: 404, uri: Uri.parse(namedUrl)),
        StackTrace.current,
      );

      await tester.pump();
      expect(tester.binding.transientCallbackCount, equals(0));
    });

    testWidgets('Challenge 5: manualRetry resets both primary and fallback in FailedImageRegistry', (tester) async {
      const primaryUrl = 'https://example.com/retry_primary.jpg';
      const fallbackUrl = 'https://example.com/retry_fallback.jpg';

      FailedImageRegistry.instance.markTerminal(primaryUrl, statusCode: 404);
      FailedImageRegistry.instance.markTerminal(fallbackUrl, statusCode: 404);

      expect(FailedImageRegistry.instance.isFailed(primaryUrl), isTrue);
      expect(FailedImageRegistry.instance.isFailed(fallbackUrl), isTrue);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CountrCachedImage(
              imageUrl: primaryUrl,
              fallbackUrl: fallbackUrl,
              cardName: 'Retry Card',
              tcgDomain: 'mtg',
              width: 36,
              height: 50,
              errorWidget: const Text('MANUAL_RETRY_TARGET'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('MANUAL_RETRY_TARGET'), findsOneWidget);

      // Tap manual retry
      await tester.tap(find.text('MANUAL_RETRY_TARGET'));
      await tester.pump();

      // Both primary and fallback should be reset in the registry
      expect(FailedImageRegistry.instance.isFailed(primaryUrl), isFalse);
      expect(FailedImageRegistry.instance.isFailed(fallbackUrl), isFalse);
    });

    testWidgets('Challenge 6: Recycling widget via didUpdateWidget resets _useFallback state', (tester) async {
      const badUrl = 'https://example.com/recycled_bad.jpg';
      const goodUrl = 'https://example.com/recycled_good.jpg';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return CountrCachedImage(
                  key: const ValueKey('recycled_widget'),
                  imageUrl: badUrl,
                  cardName: 'Sol Ring',
                  tcgDomain: 'mtg',
                  width: 36,
                  height: 50,
                );
              },
            ),
          ),
        ),
      );

      // Trigger error on badUrl to switch to fallback
      var imgFinder = find.byType(Image);
      var img = tester.widget<Image>(imgFinder);
      img.errorBuilder!(
        tester.element(imgFinder),
        NetworkImageLoadException(statusCode: 404, uri: Uri.parse(badUrl)),
        StackTrace.current,
      );
      await tester.pump();
      await tester.pump();

      // Verify fallback is active
      img = tester.widget<Image>(find.byType(Image));
      expect((img.image as NetworkImage).url, contains('api.scryfall.com/cards/named'));

      // Now recycle widget with new card data (goodUrl)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CountrCachedImage(
              key: const ValueKey('recycled_widget'),
              imageUrl: goodUrl,
              cardName: 'Mox Ruby',
              tcgDomain: 'mtg',
              width: 36,
              height: 50,
            ),
          ),
        ),
      );
      await tester.pump();

      // Recycled widget should render goodUrl, not the previous fallback
      img = tester.widget<Image>(find.byType(Image));
      expect((img.image as NetworkImage).url, equals(goodUrl));
    });

    test('Challenge 7: FailedImageRegistry linkKeys and alias synchronization is consistent without memory leakage', () {
      final registry = FailedImageRegistry.instance;
      registry.clear();

      const url1 = 'https://example.com/card_1.jpg';
      const key1 = 'card_art_card_1';

      // 1. Link keys before failure
      registry.linkKeys(url1, key1);
      expect(registry.isFailed(url1), isFalse);
      expect(registry.isFailed(null, cacheKey: key1), isFalse);

      // 2. Mark URL terminal
      registry.markTerminal(url1, statusCode: 404);
      expect(registry.isFailed(url1), isTrue);
      expect(registry.isFailed(null, cacheKey: key1), isTrue);
      expect(registry.isTerminal(url1), isTrue);
      expect(registry.isTerminal(null, cacheKey: key1), isTrue);

      // 3. Clear and verify clean state
      registry.clear();
      expect(registry.failedCount, equals(0));
      expect(registry.allFailedKeys.isEmpty, isTrue);
    });

    testWidgets('Challenge 8: Pre-failed primary card art in DeckBuilderScreen card tile fails to transition to Scryfall fallback due to cacheKey lock', (tester) async {
      const failingUrl = 'https://example.com/bad_sol_ring.jpg';
      const cardId = 'card-fail-sol-ring';
      final cacheKey = CountrImageCacheManager.cardArtKey(cardId);

      // Simulate prior failure of primary URL with its card_art cacheKey
      FailedImageRegistry.instance.markTerminal(
        failingUrl,
        cacheKey: cacheKey,
        statusCode: 404,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CountrCachedImage(
              imageUrl: failingUrl,
              cacheKey: cacheKey,
              cardName: 'Sol Ring',
              tcgDomain: 'mtg',
              width: 36,
              height: 50,
              errorWidget: const Text('TILE_PLACEHOLDER'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Expected requirement: Auto-transition to Scryfall fallback image
      // Actual bug: Displays error widget (TILE_PLACEHOLDER) and zero Images!
      final images = tester.widgetList<Image>(find.byType(Image)).toList();
      expect(images.length, equals(1), reason: 'Deck card tile thumbnail should render fallback Scryfall image when primary URL failed');
    });
  });
}
