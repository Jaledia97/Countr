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

  group('CountrCachedImage: Scryfall URL Builders & Cache Key Resolution', () {
    test('buildScryfallNamedUrl generates canonical named image redirect URL', () {
      final url = CountrCachedImage.buildScryfallNamedUrl('Edgar Markov');
      expect(
        url,
        equals('https://api.scryfall.com/cards/named?exact=Edgar%20Markov&format=image&version=art_crop'),
      );

      final normalUrl = CountrCachedImage.buildScryfallNamedUrl('Sol Ring', version: 'normal');
      expect(
        normalUrl,
        equals('https://api.scryfall.com/cards/named?exact=Sol%20Ring&format=image&version=normal'),
      );
    });

    test('buildScryfallNamedUrl safely handles double-faced card names', () {
      final url = CountrCachedImage.buildScryfallNamedUrl('Delver of Secrets // Insectile Aberration');
      expect(
        url,
        equals('https://api.scryfall.com/cards/named?exact=Delver%20of%20Secrets&format=image&version=art_crop'),
      );
    });

    test('buildScryfallNamedUrl safely handles special characters and quotes in names', () {
      final url = CountrCachedImage.buildScryfallNamedUrl("Urza's Tower");
      expect(
        url,
        equals("https://api.scryfall.com/cards/named?exact=Urza's%20Tower&format=image&version=art_crop"),
      );
    });

    test('effectiveCacheKey resolves correctly from cardId using CountrImageCacheManager.cardArtKey', () {
      const widget = CountrCachedImage(
        imageUrl: 'https://example.com/art.jpg',
        cardId: 'card-abc-123',
      );
      expect(widget.effectiveCacheKey, equals('card_art_card-abc-123'));
    });

    test('effectiveCacheKey prioritizes explicit cacheKey over cardId', () {
      const widget = CountrCachedImage(
        imageUrl: 'https://example.com/art.jpg',
        cardId: 'card-abc-123',
        cacheKey: 'custom_key_456',
      );
      expect(widget.effectiveCacheKey, equals('custom_key_456'));
    });

    test('effectiveCacheKey resolves deckId prefixed with deck- to deckCoverKey', () {
      const widget = CountrCachedImage(
        imageUrl: 'https://example.com/art.jpg',
        cardId: 'deck-edgar-markov',
      );
      expect(widget.effectiveCacheKey, equals('deck_cover_deck-edgar-markov'));
    });
  });

  group('CountrCachedImage: Basic Rendering & Scryfall Fallback', () {
    testWidgets('Renders network image when valid imageUrl is provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CountrCachedImage(
              imageUrl: 'https://example.com/valid_art.jpg',
              cacheKey: 'card_art_test1',
              width: 100,
              height: 140,
            ),
          ),
        ),
      );

      expect(find.byType(CountrCachedImage), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      final img = tester.widget<Image>(find.byType(Image));
      expect(img.image, isA<NetworkImage>());
      expect((img.image as NetworkImage).url, equals('https://example.com/valid_art.jpg'));
    });

    testWidgets('Supports local file:// paths and renders FileImage', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CountrCachedImage(
              imageUrl: 'file:///local/storage/card_art.jpg',
              cacheKey: 'card_art_local',
              width: 100,
              height: 140,
            ),
          ),
        ),
      );

      expect(find.byType(CountrCachedImage), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      final img = tester.widget<Image>(find.byType(Image));
      expect(img.image, isA<FileImage>());
      expect((img.image as FileImage).file.path, equals('/local/storage/card_art.jpg'));
    });

    testWidgets('Falls back to Scryfall named redirect for MTG cards when imageUrl points to 404 back.jpg', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CountrCachedImage(
              imageUrl: 'https://cards.scryfall.io/art_crop/back.jpg',
              cardName: 'Edgar Markov',
              tcgDomain: 'mtg',
              width: 100,
              height: 140,
            ),
          ),
        ),
      );

      expect(find.byType(CountrCachedImage), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      final img = tester.widget<Image>(find.byType(Image));
      expect(img.image, isA<NetworkImage>());
      final resolvedUrl = (img.image as NetworkImage).url;
      expect(resolvedUrl, contains('api.scryfall.com/cards/named'));
      expect(resolvedUrl, contains('Edgar%20Markov'));
    });

    testWidgets('Falls back to Scryfall named redirect for MTG cards when imageUrl is empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CountrCachedImage(
              imageUrl: '',
              cardName: 'Cruel Celebrant',
              tcgDomain: 'mtg',
              width: 100,
              height: 140,
            ),
          ),
        ),
      );

      expect(find.byType(CountrCachedImage), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      final img = tester.widget<Image>(find.byType(Image));
      expect(img.image, isA<NetworkImage>());
      final resolvedUrl = (img.image as NetworkImage).url;
      expect(resolvedUrl, contains('api.scryfall.com/cards/named'));
      expect(resolvedUrl, contains('Cruel%20Celebrant'));
    });

    testWidgets('Renders elegant styled card placeholder with card initials when card art is unavailable', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CountrCachedImage(
              imageUrl: '',
              cardName: 'Edgar Markov',
              tcgDomain: 'other', // not mtg, so no named scryfall fallback
              width: 100,
              height: 140,
            ),
          ),
        ),
      );

      expect(find.byType(CountrCachedImage), findsOneWidget);
      expect(find.text('EM'), findsOneWidget);
      expect(find.byIcon(Icons.image_not_supported), findsNothing);
    });

    testWidgets('Intercepts Icons.image_not_supported in errorWidget and replaces with styled card placeholder', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CountrCachedImage(
              imageUrl: '',
              cardName: 'Vampire Nighthawk',
              tcgDomain: 'other',
              errorWidget: Icon(
                Icons.image_not_supported,
                size: 18,
                color: Colors.white24,
              ),
              width: 100,
              height: 140,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.image_not_supported), findsNothing);
      expect(find.text('VN'), findsOneWidget);
    });
  });

  group('CountrCachedImage: Immediate Short-Circuit on Registered Failed URLs', () {
    testWidgets('URL in FailedImageRegistry renders errorWidget immediately with 0 timers and 0 frames delay', (tester) async {
      const failedUrl = 'https://cards.scryfall.io/art/dead_link.jpg';
      FailedImageRegistry.instance.markTerminal(
        failedUrl,
        statusCode: 404,
        type: ImageFailureType.terminalNotFound,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CountrCachedImage(
              imageUrl: failedUrl,
              cardName: 'Dead Card',
              tcgDomain: 'other',
              width: 100,
              height: 140,
              errorWidget: const Text('ERROR_LOCKED'),
            ),
          ),
        ),
      );

      // Frame 0 immediately shows errorWidget
      expect(find.text('ERROR_LOCKED'), findsOneWidget);

      // Verify NO pending transient timers exist
      expect(tester.binding.transientCallbackCount, equals(0));

      // Settle completes instantly without timer delay
      await tester.pumpAndSettle();
      expect(find.text('ERROR_LOCKED'), findsOneWidget);
    });

    testWidgets('Dual-key short circuit: CacheKey marked failed short-circuits image load by URL', (tester) async {
      const url = 'https://cards.scryfall.io/art/sol_ring.jpg';
      const cardId = 'mtg-sol-ring-fail';
      final cacheKey = CountrImageCacheManager.cardArtKey(cardId);

      FailedImageRegistry.instance.linkKeys(url, cacheKey);
      FailedImageRegistry.instance.markTerminal(cacheKey, statusCode: 404, type: ImageFailureType.terminalNotFound);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CountrCachedImage(
              imageUrl: url,
              cardId: cardId,
              cardName: 'Sol Ring',
              tcgDomain: 'other',
              width: 100,
              height: 140,
              errorWidget: const Text('DUAL_KEY_LOCKED'),
            ),
          ),
        ),
      );

      expect(find.text('DUAL_KEY_LOCKED'), findsOneWidget);
    });
  });

  group('CountrCachedImage: Loop Termination & Unmount/Remount Persistence', () {
    testWidgets('Unmounting and remounting preserves failed state without re-initiating retry loop', (tester) async {
      const failedUrl = 'https://cards.scryfall.io/art/unmount_test.jpg';
      FailedImageRegistry.instance.markTerminal(failedUrl, statusCode: 404, type: ImageFailureType.terminalNotFound);

      // 1. Initial mount
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CountrCachedImage(
              key: const ValueKey('persist_test'),
              imageUrl: failedUrl,
              cardName: 'Persist Card',
              tcgDomain: 'other',
              width: 100,
              height: 140,
              errorWidget: const Text('PERMANENT_ERROR'),
            ),
          ),
        ),
      );
      expect(find.text('PERMANENT_ERROR'), findsOneWidget);

      // 2. Unmount widget (simulate scroll off-screen)
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox.shrink())));
      expect(find.text('PERMANENT_ERROR'), findsNothing);

      // 3. Remount widget (simulate scroll back into view)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CountrCachedImage(
              key: const ValueKey('persist_test'),
              imageUrl: failedUrl,
              cardName: 'Persist Card',
              tcgDomain: 'other',
              width: 100,
              height: 140,
              errorWidget: const Text('PERMANENT_ERROR'),
            ),
          ),
        ),
      );

      // Renders immediately in error state without restarted retries
      expect(find.text('PERMANENT_ERROR'), findsOneWidget);
      expect(tester.binding.transientCallbackCount, equals(0));
    });

    testWidgets('Eliminates post-frame rebuild cascade inside error state', (tester) async {
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                buildCount++;
                return const CountrCachedImage(
                  imageUrl: '',
                  cardName: 'Stable Card',
                  tcgDomain: 'other',
                  width: 100,
                  height: 140,
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      // Parent builder should not be triggered in a post-frame rebuild loop
      expect(buildCount, equals(1));
    });
  });

  group('CountrCachedImage: Zero Layout Shift & Dimension Stability', () {
    testWidgets('Placeholder and errorWidget share identical bounding box dimensions', (tester) async {
      const explicitWidth = 120.0;
      const explicitHeight = 160.0;

      // 1. Loading Placeholder state
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CountrCachedImage(
              imageUrl: 'https://example.com/loading_art.jpg',
              width: explicitWidth,
              height: explicitHeight,
              placeholder: Container(
                key: const ValueKey('placeholder_box'),
                color: Colors.grey,
              ),
            ),
          ),
        ),
      );

      final placeholderSize = tester.getSize(find.byType(CountrCachedImage));
      expect(placeholderSize.width, equals(explicitWidth));
      expect(placeholderSize.height, equals(explicitHeight));

      // 2. Error state
      FailedImageRegistry.instance.markTerminal('https://example.com/error_art.jpg', statusCode: 404);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CountrCachedImage(
              imageUrl: 'https://example.com/error_art.jpg',
              width: explicitWidth,
              height: explicitHeight,
              errorWidget: Container(
                key: const ValueKey('error_box'),
                color: Colors.red,
              ),
            ),
          ),
        ),
      );

      final errorSize = tester.getSize(find.byType(CountrCachedImage));
      expect(errorSize.width, equals(explicitWidth));
      expect(errorSize.height, equals(explicitHeight));

      // Zero layout shift assertion: width and height match with 0.0 delta
      expect(errorSize, equals(placeholderSize));
    });

    testWidgets('LayoutBuilder adaptive placeholder prevents RenderFlex overflow in compact 40x50 tile', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 40,
              height: 50,
              child: CountrCachedImage(
                imageUrl: '',
                cardName: 'Very Long Complex Card Name That Would Overflow',
                tcgDomain: 'other',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // No RenderFlex overflow exception thrown
      expect(tester.takeException(), isNull);
      expect(find.byType(CountrCachedImage), findsOneWidget);
    });
  });

  group('CountrCachedImage: Manual Retry Protocol & Gesture Hit-Testing', () {
    testWidgets('Tapping error widget executes manualRetry, resets registry, and re-enables loading', (tester) async {
      const url = 'https://example.com/retry_card.jpg';
      FailedImageRegistry.instance.markTerminal(url, statusCode: 404, type: ImageFailureType.terminalNotFound);
      expect(FailedImageRegistry.instance.isFailed(url), isTrue);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CountrCachedImage(
              imageUrl: url,
              cardName: 'Retry Card',
              tcgDomain: 'other',
              width: 100,
              height: 140,
              errorWidget: const Text('TAP_TO_RETRY'),
            ),
          ),
        ),
      );

      expect(find.text('TAP_TO_RETRY'), findsOneWidget);

      // Perform tap on error widget
      await tester.tap(find.text('TAP_TO_RETRY'));
      await tester.pump();

      // Registry entry must be reset
      expect(FailedImageRegistry.instance.isFailed(url), isFalse);
      expect(FailedImageRegistry.instance.getAttempts(url), equals(0));
    });

    testWidgets('HitTestBehavior is opaque ensuring taps on empty margins register reliably', (tester) async {
      const url = 'https://example.com/tap_margin.jpg';
      FailedImageRegistry.instance.markTerminal(url, statusCode: 404);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CountrCachedImage(
                imageUrl: url,
                cardName: 'Margin Card',
                tcgDomain: 'other',
                width: 150,
                height: 200,
              ),
            ),
          ),
        ),
      );

      // Tap at top-left edge of the image bounds
      final topLeft = tester.getTopLeft(find.byType(CountrCachedImage)) + const Offset(5, 5);
      await tester.tapAt(topLeft);
      await tester.pump();

      expect(FailedImageRegistry.instance.isFailed(url), isFalse);
    });
  });

  group('CountrCachedImage: Milestone 4 (R4) Automatic Fallback & Aspect Ratio Calibration', () {
    testWidgets('fallbackVersion defaults to normal producing playable card URL', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CountrCachedImage(
              imageUrl: '',
              cardName: 'Counterspell',
              tcgDomain: 'mtg',
              width: 36,
              height: 50,
              fit: BoxFit.cover,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final img = tester.widget<Image>(find.byType(Image));
      expect(img.image, isA<NetworkImage>());
      final url = (img.image as NetworkImage).url;
      expect(url, contains('api.scryfall.com/cards/named'));
      expect(url, contains('Counterspell'));
      expect(url, contains('version=normal'));
    });

    testWidgets('Automatically transitions to candidate fallback without requiring manual tap', (tester) async {
      const primaryUrl = 'https://example.com/failing_primary_card.jpg';
      FailedImageRegistry.instance.markTerminal(primaryUrl, statusCode: 500, type: ImageFailureType.exhaustedRetries);

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
      await tester.pumpAndSettle();

      // Verify that candidate fallback was automatically mounted without any tap gesture
      expect(find.byType(Image), findsOneWidget);
      final img = tester.widget<Image>(find.byType(Image));
      final url = (img.image as NetworkImage).url;
      expect(url, contains('api.scryfall.com/cards/named'));
      expect(url, contains('Sol%20Ring'));
      expect(url, contains('version=normal'));
    });

    testWidgets('Respects calibrated 0.714 aspect ratio and BoxFit.cover dimensional constraints', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: CountrCachedImage(
                imageUrl: 'https://example.com/normal_card.jpg',
                cardName: 'Black Lotus',
                tcgDomain: 'mtg',
                width: 36,
                height: 50,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      );

      final imageWidget = tester.widget<Image>(find.byType(Image));
      expect(imageWidget.fit, equals(BoxFit.cover));
      expect(imageWidget.width, equals(36));
      expect(imageWidget.height, equals(50));

      final size = tester.getSize(find.byType(CountrCachedImage));
      expect(size.width, equals(36));
      expect(size.height, equals(50));
      // Aspect ratio: 36 / 50 = 0.72 (calibrated standard playing card ratio)
      expect(size.width / size.height, closeTo(0.714, 0.01));
    });
  });
}
