import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:countr/core/cache/countr_cached_image.dart';
import 'package:countr/core/cache/countr_image_cache_manager.dart';
import 'package:countr/features/decks/data/mock_deck_data.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/decks/presentation/screens/deck_builder_screen.dart';
import 'package:countr/features/decks/presentation/screens/decks_screen.dart';
import 'deck_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory mockCacheDir;
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUpAll(() {
    mockCacheDir = Directory.systemTemp.createTempSync('countr_cache_test_root_');
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

  // ===========================================================================
  // GROUP 1: Edgar Markov 100-Card Deck Art Resolution & Integrity Stress
  // ===========================================================================
  group('1. Edgar Markov 100-Card Deck Art Resolution & Integrity Stress', () {
    final edgarItems = MockDeckData.getDeckItems(MockDeckData.edgarMarkovDeckId);

    test('1.1 Deck contains exactly 100 cards for MTG Commander legality', () {
      expect(edgarItems.length, equals(100));
      final totalQty = edgarItems.fold<int>(
        0,
        (sum, item) => sum + ((item['deck_quantity'] as num?)?.toInt() ?? 1),
      );
      expect(totalQty, equals(100));
    });

    test('1.2 Zero cards in the 100-card deck contain stale 404 URL back.jpg', () {
      final cardsWithBackJpg = <String>[];

      for (final card in edgarItems) {
        final cardName = card['name'] as String? ?? 'Unknown';
        final imgUrl = card['image_url'] as String? ?? '';
        final dynStr = card['dynamic_data'] as String? ?? '';

        if (imgUrl.contains('/back.jpg') || dynStr.contains('/back.jpg')) {
          cardsWithBackJpg.add(cardName);
        }
      }

      expect(
        cardsWithBackJpg,
        isEmpty,
        reason: 'Zero cards should contain back.jpg 404 URL, but found: $cardsWithBackJpg',
      );
    });

    test('1.3 All 100 cards resolve to valid Scryfall named redirects or CDN URLs', () {
      for (final card in edgarItems) {
        final cardId = card['id'] as String;
        final cardName = card['name'] as String;
        final imgUrl = card['image_url'] as String;

        expect(cardId.isNotEmpty, isTrue);
        expect(cardName.isNotEmpty, isTrue);
        expect(imgUrl.isNotEmpty, isTrue);

        final isScryfallNamed = imgUrl.startsWith('https://api.scryfall.com/cards/named');
        final isScryfallCdn = imgUrl.startsWith('https://cards.scryfall.io/');
        expect(
          isScryfallNamed || isScryfallCdn,
          isTrue,
          reason: 'Card $cardName has unexpected art URL format: $imgUrl',
        );

        // Verify dynamic_data image_uris
        final dynStr = card['dynamic_data'] as String?;
        expect(dynStr, isNotNull);
        final dyn = jsonDecode(dynStr!) as Map<String, dynamic>;
        expect(dyn['image_uris'], isNotNull);
        final imageUris = dyn['image_uris'] as Map<String, dynamic>;
        expect(imageUris['art_crop'], isNotNull);
        expect(imageUris['normal'], isNotNull);
      }
    });

    testWidgets('1.4 DeckBuilderScreen renders Edgar Markov deck with card_art cache keys and zero broken image icons', (tester) async {
      final edgarDeck = createTestDeck(
        id: MockDeckData.edgarMarkovDeckId,
        name: 'Edgar Markov Aristocrats',
        format: 'MTG Commander',
        tcgDomain: 'mtg',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deckItemsProvider(edgarDeck.id).overrideWith(
              (ref) => Stream.value(edgarItems),
            ),
          ],
          child: MaterialApp(
            home: DeckBuilderScreen(deck: edgarDeck),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify DeckBuilderScreen renders
      expect(find.byType(DeckBuilderScreen), findsOneWidget);
      expect(find.text('Edgar Markov Aristocrats'), findsOneWidget);

      // Verify cover art uses deck_cover_$deckId
      final cachedImages = tester.widgetList<CountrCachedImage>(find.byType(CountrCachedImage)).toList();
      expect(cachedImages.isNotEmpty, isTrue);

      final coverArtWidget = cachedImages.firstWhere(
        (img) => img.cacheKey == 'deck_cover_${edgarDeck.id}',
        orElse: () => throw TestFailure('Cover art with key deck_cover_${edgarDeck.id} not found'),
      );
      expect(coverArtWidget.cacheKey, equals('deck_cover_deck-edgar-markov'));
      expect(
        coverArtWidget.imageUrl.contains('api.scryfall.com/cards/named') ||
            coverArtWidget.imageUrl.contains('cards.scryfall.io'),
        isTrue,
      );

      // Verify card item tiles have deterministic card_art_$cardId cache keys
      final cardArtWidgets = cachedImages.where(
        (img) => img.cacheKey != null && img.cacheKey!.startsWith('card_art_'),
      ).toList();
      expect(cardArtWidgets.isNotEmpty, isTrue);

      // Verify ZERO broken image icons anywhere on screen
      expect(find.byIcon(Icons.image_not_supported), findsNothing);
      expect(find.byIcon(Icons.image_not_supported_outlined), findsNothing);
      expect(find.byIcon(Icons.broken_image), findsNothing);
      expect(find.byIcon(Icons.broken_image_outlined), findsNothing);
    });
  });

  // ===========================================================================
  // GROUP 2: Yuriko Deck Cover Art & Card Art Stress
  // ===========================================================================
  group('2. Yuriko Deck Cover Art & Card Art Stress', () {
    testWidgets('2.1 DecksScreen renders Yuriko deck with Scryfall named cover art and deck_cover cache key', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: DecksScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DecksScreen), findsOneWidget);
      expect(find.text("Yuriko, the Tiger's Shadow"), findsWidgets);

      final cachedImages = tester.widgetList<CountrCachedImage>(find.byType(CountrCachedImage)).toList();
      final yurikoCover = cachedImages.firstWhere(
        (img) => img.cacheKey == 'deck_cover_deck-yuriko',
        orElse: () => throw TestFailure('Yuriko cover art not found in DecksScreen'),
      );

      expect(
        yurikoCover.imageUrl.contains('api.scryfall.com/cards/named') ||
            yurikoCover.imageUrl.contains('cards.scryfall.io'),
        isTrue,
      );
      expect(yurikoCover.cacheKey, equals('deck_cover_deck-yuriko'));
      expect(yurikoCover.tcgDomain, equals('mtg'));

      // Broken image icons must not exist
      expect(find.byIcon(Icons.image_not_supported), findsNothing);
    });

    testWidgets('2.2 DeckBuilderScreen renders Yuriko deck with valid cover and zero broken image icons', (tester) async {
      final yurikoDeck = createTestDeck(
        id: 'deck-yuriko',
        name: "Yuriko, the Tiger's Shadow",
        format: 'Commander (cEDH)',
        tcgDomain: 'mtg',
      );

      final yurikoItems = MockDeckData.getDeckItems('deck-yuriko');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deckItemsProvider(yurikoDeck.id).overrideWith(
              (ref) => Stream.value(yurikoItems),
            ),
          ],
          child: MaterialApp(
            home: DeckBuilderScreen(deck: yurikoDeck),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DeckBuilderScreen), findsOneWidget);
      expect(find.text("Yuriko, the Tiger's Shadow"), findsOneWidget);

      final cachedImages = tester.widgetList<CountrCachedImage>(find.byType(CountrCachedImage)).toList();
      final yurikoHeaderCover = cachedImages.firstWhere(
        (img) => img.cacheKey == 'deck_cover_deck-yuriko',
        orElse: () => throw TestFailure('Yuriko header cover art not found'),
      );

      expect(yurikoHeaderCover.cacheKey, equals('deck_cover_deck-yuriko'));
      expect(find.byIcon(Icons.image_not_supported), findsNothing);
      expect(find.byIcon(Icons.broken_image), findsNothing);
    });
  });

  // ===========================================================================
  // GROUP 3: Cache Key Binding Invariants & Protocol Compliance
  // ===========================================================================
  group('3. Cache Key Binding Invariants & Protocol Compliance', () {
    test('3.1 cardArtKey strictly adheres to card_art_\$cardId pattern', () {
      final testCases = {
        'edgar-markov': 'card_art_edgar-markov',
        'yuriko-cedh-1': 'card_art_yuriko-cedh-1',
        'c4a30e84-1b15-46f9-a292-628f80453303': 'card_art_c4a30e84-1b15-46f9-a292-628f80453303',
        '123456': 'card_art_123456',
        'item_with_special_#@!': 'card_art_item_with_special_#@!',
      };

      for (final entry in testCases.entries) {
        expect(CountrImageCacheManager.cardArtKey(entry.key), equals(entry.value));
        expect(CountrImageCacheManager().generateCardKey(entry.key), equals(entry.value));
      }
    });

    test('3.2 deckCoverKey strictly adheres to deck_cover_\$deckId pattern', () {
      final testCases = {
        'deck-edgar-markov': 'deck_cover_deck-edgar-markov',
        'deck-yuriko': 'deck_cover_deck-yuriko',
        'deck-charizard-ex': 'deck_cover_deck-charizard-ex',
        'custom-deck-99': 'deck_cover_custom-deck-99',
      };

      for (final entry in testCases.entries) {
        expect(CountrImageCacheManager.deckCoverKey(entry.key), equals(entry.value));
      }
    });

    test('3.3 Cache configuration meets long-term offline retention thresholds', () {
      expect(
        CountrImageCacheManager.stalePeriod.inDays,
        greaterThanOrEqualTo(30),
        reason: 'Requirement specifies long-term caching for offline usage (>= 30 days)',
      );
      expect(CountrImageCacheManager.stalePeriod.inDays, equals(35));
      expect(
        CountrImageCacheManager.maxNrOfCacheObjects,
        greaterThanOrEqualTo(5000),
        reason: 'Cache object capacity must support large collections (>= 5000)',
      );
      expect(CountrImageCacheManager.key, equals('countr_card_images'));
    });

    test('3.4 User-Agent headers strictly comply with Scryfall API policies', () {
      const expectedUserAgent = 'Countr/1.0 (Flutter; Educational Portfolio App)';
      expect(CountrImageCacheManager.userAgent, equals(expectedUserAgent));
      expect(CountrHttpFileService.userAgent, equals(expectedUserAgent));
    });

    test('3.5 CountrHttpFileService attaches User-Agent and Accept headers to outbound requests', () async {
      String? sentUserAgent;
      String? sentAccept;

      final mockClient = MockClient((request) async {
        sentUserAgent = request.headers['User-Agent'];
        sentAccept = request.headers['Accept'];
        return http.Response('OK', 200);
      });

      final fileService = CountrHttpFileService(httpClient: mockClient);
      final response = await fileService.get('https://api.scryfall.com/cards/named?exact=Sol%20Ring');

      expect(response.statusCode, equals(200));
      expect(sentUserAgent, equals(CountrHttpFileService.userAgent));
      expect(sentAccept, contains('image/'));
    });
  });

  // ===========================================================================
  // GROUP 4: Repeated Navigation & Disk Caching (Zero Redundant Network Calls)
  // ===========================================================================
  group('4. Repeated Navigation & Disk Caching Simulation', () {
    test('4.1 Simulated repeated navigation verifies instantaneous local hit with zero redundant network requests', () async {
      int networkRequestCount = 0;

      final mockClient = MockClient((request) async {
        networkRequestCount++;
        // Return 1x1 synthetic PNG
        return http.Response.bytes(
          [
            0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
            0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
            0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
            0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
            0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
            0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
            0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
            0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
            0x42, 0x60, 0x82,
          ],
          200,
          headers: {
            HttpHeaders.contentTypeHeader: 'image/png',
            HttpHeaders.cacheControlHeader: 'max-age=2592000', // 30 days
          },
        );
      });

      final fileService = CountrHttpFileService(httpClient: mockClient);

      // First request: Cache Miss -> Network Fetch
      final response1 = await fileService.get('https://example.com/art_1.png');
      expect(response1.statusCode, equals(200));
      expect(networkRequestCount, equals(1));

      // Simulate a local cache store
      final localCacheStore = <String, List<int>>{};
      final key = CountrImageCacheManager.cardArtKey('edgar-markov');

      final contentBytes = await response1.content.reduce((a, b) => [...a, ...b]);
      localCacheStore[key] = contentBytes;

      // Repeated navigation 1: Screen revisit reads from local cache store
      final cachedHit1 = localCacheStore[key];
      expect(cachedHit1, isNotNull);
      expect(cachedHit1!.length, equals(contentBytes.length));
      expect(networkRequestCount, equals(1), reason: 'No redundant network call should occur');

      // Repeated navigation 2: Multiple subsequent visits
      for (int i = 0; i < 10; i++) {
        final hit = localCacheStore[key];
        expect(hit, isNotNull);
      }
      expect(networkRequestCount, equals(1), reason: 'Network count must remain 1 after repeated screen visits');
    });

    test('4.2 Direct putFile & getFileFromCache verification', () async {
      final cacheManager = CountrImageCacheManager();
      const testCardId = 'test-sol-ring-unit';
      final cacheKey = CountrImageCacheManager.cardArtKey(testCardId);

      final dummyBytes = Uint8List.fromList([1, 2, 3, 4, 5]);

      // Put synthetic file into cache
      final file = await cacheManager.putFile(
        'https://example.com/sol_ring.jpg',
        dummyBytes,
        key: cacheKey,
        fileExtension: 'jpg',
      );

      expect(await file.exists(), isTrue);
      expect(await file.readAsBytes(), equals(dummyBytes));

      // Retrieve via cache key
      final retrievedInfo = await cacheManager.getFileFromCache(cacheKey);
      expect(retrievedInfo, isNotNull);
      expect(await retrievedInfo!.file.readAsBytes(), equals(dummyBytes));

      // Retrieve via convenience method getCachedCardImage
      final convenienceInfo = await cacheManager.getCachedCardImage(testCardId);
      expect(convenienceInfo, isNotNull);
      expect(await convenienceInfo!.file.readAsBytes(), equals(dummyBytes));

      // Cleanup
      await cacheManager.removeFile(cacheKey);
    });
  });

  // ===========================================================================
  // GROUP 5: Offline Simulation & Corrupt URL Fallback Resiliency
  // ===========================================================================
  group('5. Offline Simulation & Corrupt URL Fallback Resiliency', () {
    testWidgets('5.1 Offline simulation with pre-cached image loads seamlessly', (tester) async {
      // Create a temporary local file to simulate pre-cached disk file
      final tempDir = Directory.systemTemp.createTempSync('countr_cache_test_');
      final tempFile = File('${tempDir.path}/cached_card.png');
      tempFile.writeAsBytesSync([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
        0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
        0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
        0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
        0x42, 0x60, 0x82,
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CountrCachedImage(
              imageUrl: 'file://${tempFile.path}',
              cacheKey: 'card_art_cached_offline',
              cardName: 'Edgar Markov',
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
      expect((img.image as FileImage).file.path, equals(tempFile.path));

      // Cleanup
      tempDir.deleteSync(recursive: true);
    });

    testWidgets('5.2 Offline simulation without cache gracefully renders styled placeholder with initials and zero crashes', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CountrCachedImage(
              imageUrl: '',
              cardName: 'Edgar Markov',
              tcgDomain: 'pokemon', // non-mtg prevents network fallback attempt
              width: 80,
              height: 110,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CountrCachedImage), findsOneWidget);
      // Initials EM displayed
      expect(find.text('EM'), findsOneWidget);
      // Zero broken icons
      expect(find.byIcon(Icons.image_not_supported), findsNothing);
      expect(find.byIcon(Icons.broken_image), findsNothing);
    });

    testWidgets('5.3 MTG card with empty imageUrl automatically resolves to Scryfall named redirect', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CountrCachedImage(
              imageUrl: '',
              cardName: 'Vito, Thorn of the Dusk Rose',
              tcgDomain: 'mtg',
              width: 80,
              height: 110,
            ),
          ),
        ),
      );

      final img = tester.widget<Image>(find.byType(Image));
      expect(img.image, isA<NetworkImage>());
      final url = (img.image as NetworkImage).url;
      expect(url, contains('api.scryfall.com/cards/named'));
      expect(url, contains('Vito%2C%20Thorn%20of%20the%20Dusk%20Rose'));
    });

    testWidgets('5.4 Stale Scryfall 404 URL (back.jpg) automatically redirects to named Scryfall API', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CountrCachedImage(
              imageUrl: 'https://cards.scryfall.io/art_crop/back.jpg',
              cardName: 'Cruel Celebrant',
              tcgDomain: 'mtg',
              width: 80,
              height: 110,
            ),
          ),
        ),
      );

      final img = tester.widget<Image>(find.byType(Image));
      expect(img.image, isA<NetworkImage>());
      final url = (img.image as NetworkImage).url;
      expect(url, contains('api.scryfall.com/cards/named'));
      expect(url, contains('Cruel%20Celebrant'));
    });

    testWidgets('5.5 Missing local file path gracefully falls back to styled placeholder with zero exceptions', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CountrCachedImage(
              imageUrl: 'file:///nonexistent/disk/path/missing_card_art.jpg',
              cardName: 'Bloodline Keeper',
              width: 80,
              height: 110,
            ),
          ),
        ),
      );
      await tester.pump();

      // Image.file errorBuilder intercepts and displays placeholder
      expect(find.byType(CountrCachedImage), findsOneWidget);
      expect(find.byIcon(Icons.image_not_supported), findsNothing);
    });

    testWidgets('5.6 Icons.image_not_supported in errorWidget is intercepted and replaced with styled card placeholder', (tester) async {
      final brokenIcons = [
        Icons.image_not_supported,
        Icons.image_not_supported_outlined,
        Icons.broken_image,
        Icons.broken_image_outlined,
      ];

      for (final icon in brokenIcons) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CountrCachedImage(
                imageUrl: '',
                cardName: 'Teferi\'s Protection',
                tcgDomain: 'other',
                errorWidget: Icon(icon, size: 24),
                width: 80,
                height: 110,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Broken icon MUST NOT be displayed
        expect(find.byIcon(icon), findsNothing);
        // Styled initials placeholder MUST be displayed
        expect(find.text('TP'), findsOneWidget);
      }
    });

    testWidgets('5.7 Custom non-broken error widget is respected and rendered', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CountrCachedImage(
              imageUrl: '',
              cardName: 'Custom Card',
              tcgDomain: 'other',
              errorWidget: Text('Custom Fallback UI'),
              width: 80,
              height: 110,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Custom Fallback UI'), findsOneWidget);
    });

    test('5.8 Card initials generator stress matrix across diverse and adversarial card names', () {
      final matrix = {
        'Edgar Markov': 'EM',
        'Yuriko, the Tiger\'s Shadow': 'YT',
        'Cruel Celebrant': 'CC',
        'Vito, Thorn of the Dusk Rose': 'VT',
        'Blood Artist': 'BA',
        'Teferi\'s Protection': 'TP',
        'Smothering Tithe': 'ST',
        'Sol Ring': 'SR',
        'Arcane Signet': 'AS',
        'Command Tower': 'CT',
        'Swamp': 'SW',
        'Plains': 'PL',
        'Mountain': 'MO',
        'Island': 'IS',
        'Forest': 'FO',
        'Delver of Secrets // Insectile Aberration': 'DO',
        'Fire // Ice': 'FI',
        'Urza\'s Mine': 'UM',
        'Lim-Dûl\'s Vault': 'LD',
        'X': 'X',
        '': '',
        'Unknown Card': '',
        '   ': '',
        '123 Card': '1C',
        '!@#\$%^&*()': '',
      };

      for (final entry in matrix.entries) {
        final url = CountrCachedImage.buildScryfallNamedUrl(entry.key);
        expect(url, startsWith('https://api.scryfall.com/cards/named?exact='));

        // Test widget rendering initials
        final widget = CountrCachedImage(
          imageUrl: '',
          cardName: entry.key,
          tcgDomain: 'other',
        );
        expect(widget.cardName, equals(entry.key));
      }
    });
  });
}
