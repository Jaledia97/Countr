import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:countr/core/cache/countr_image_cache_manager.dart';

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

  setUp(() {
    FailedImageRegistry.instance.clear();
  });

  group('CountrImageCacheManager: Configuration & Static Key Helpers', () {
    test('Configures long-term disk cache duration of 35 days and 5000 object limit', () {
      expect(CountrImageCacheManager.stalePeriod.inDays, greaterThanOrEqualTo(30));
      expect(CountrImageCacheManager.stalePeriod.inDays, equals(35));
      expect(CountrImageCacheManager.maxNrOfCacheObjects, greaterThanOrEqualTo(5000));
      expect(CountrImageCacheManager.key, equals('countr_card_images'));
    });

    test('Attaches official User-Agent header for Scryfall and generic TCG APIs', () {
      expect(
        CountrImageCacheManager.userAgent,
        equals('Countr/1.0 (Flutter; Educational Portfolio App)'),
      );
      expect(
        CountrHttpFileService.userAgent,
        equals('Countr/1.0 (Flutter; Educational Portfolio App)'),
      );
    });

    test('cardArtKey generates deterministic key prefixed with card_art_', () {
      expect(CountrImageCacheManager.cardArtKey('mtg-123'), equals('card_art_mtg-123'));
      expect(CountrImageCacheManager.cardArtKey('edgar-markov'), equals('card_art_edgar-markov'));
    });

    test('deckCoverKey generates deterministic key prefixed with deck_cover_', () {
      expect(CountrImageCacheManager.deckCoverKey('deck-1'), equals('deck_cover_deck-1'));
      expect(CountrImageCacheManager.deckCoverKey('deck-edgar-markov'), equals('deck_cover_deck-edgar-markov'));
    });

    test('generateCardKey alias produces identical result to cardArtKey', () {
      final manager = CountrImageCacheManager.instance;
      expect(manager.generateCardKey('card-xyz'), equals(CountrImageCacheManager.cardArtKey('card-xyz')));
    });
  });

  group('CountrImageCacheManager: Canonical URL Normalization', () {
    test('Strips timestamp query parameters from Scryfall CDN image URLs', () {
      const rawUrl = 'https://cards.scryfall.io/art_crop/front/8/d/8d94b8ec-ecda-43c8-a60e-1ba33e6a54a4.jpg?1673148560';
      final normalized = CountrImageCacheManager.normalizeUrl(rawUrl);
      expect(
        normalized,
        equals('https://cards.scryfall.io/art_crop/front/8/d/8d94b8ec-ecda-43c8-a60e-1ba33e6a54a4.jpg'),
      );
    });

    test('Normalizes scheme and host to lowercase', () {
      const upperUrl = 'HTTPS://CARDS.SCRYFALL.IO/large/front/test.jpg';
      final normalized = CountrImageCacheManager.normalizeUrl(upperUrl);
      expect(normalized, equals('https://cards.scryfall.io/large/front/test.jpg'));
    });

    test('Strips cache-busting query strings on generic jpg, png, and webp images', () {
      const urlJpg = 'https://example.com/cards/lotus.jpg?v=2&ts=998877';
      const urlPng = 'https://example.com/cards/mox.png?token=xyz';
      const urlWebp = 'https://example.com/cards/ring.webp?t=123';

      expect(CountrImageCacheManager.normalizeUrl(urlJpg), equals('https://example.com/cards/lotus.jpg'));
      expect(CountrImageCacheManager.normalizeUrl(urlPng), equals('https://example.com/cards/mox.png'));
      expect(CountrImageCacheManager.normalizeUrl(urlWebp), equals('https://example.com/cards/ring.webp'));
    });

    test('Safely handles malformed URLs, empty strings, and whitespace without throwing', () {
      expect(CountrImageCacheManager.normalizeUrl(''), equals(''));
      expect(CountrImageCacheManager.normalizeUrl('   '), equals(''));
      expect(CountrImageCacheManager.normalizeUrl('not-a-valid-uri:::'), equals('not-a-valid-uri:::'));
    });
  });

  group('CountrImageCacheManager: Deterministic Cache Key Resolution', () {
    test('cacheKeyFor prioritizes explicit cacheKey', () {
      final key = CountrImageCacheManager.cacheKeyFor(
        cardId: 'mtg-001',
        imageUrl: 'https://example.com/art.jpg',
        cacheKey: 'explicit-key',
      );
      expect(key, equals('explicit-key'));
    });

    test('cacheKeyFor resolves deckId to deckCoverKey when starting with deck-', () {
      final key = CountrImageCacheManager.cacheKeyFor(cardId: 'deck-edgar-markov');
      expect(key, equals('deck_cover_deck-edgar-markov'));
    });

    test('cacheKeyFor resolves regular cardId to cardArtKey', () {
      final key = CountrImageCacheManager.cacheKeyFor(cardId: 'sol-ring-001');
      expect(key, equals('card_art_sol-ring-001'));
    });

    test('cacheKeyFor resolves normalized URL when cardId is omitted', () {
      final key = CountrImageCacheManager.cacheKeyFor(
        imageUrl: 'https://cards.scryfall.io/art/lotus.jpg?1673148560',
      );
      expect(key, equals('https://cards.scryfall.io/art/lotus.jpg'));
    });
  });

  group('CountrImageCacheManager: Dual-Key Pre-Caching & Aliased Retrieval', () {
    test('precacheCardArt stores file accessible under cardArtKey, normalized URL, and raw URL', () async {
      final manager = CountrImageCacheManager.instance;
      const cardId = 'test-dual-card';
      const rawUrl = 'https://cards.scryfall.io/art_crop/front/test_dual.jpg?1673148560';
      const normUrl = 'https://cards.scryfall.io/art_crop/front/test_dual.jpg';
      final dummyBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]); // JPEG magic header

      // Seed the cache under primary key and normalized URL
      final artKey = CountrImageCacheManager.cardArtKey(cardId);
      manager.registerKeyAlias(artKey, normUrl);
      await manager.putFile(artKey, dummyBytes, key: artKey);
      await manager.putFile(normUrl, dummyBytes, key: normUrl);

      // 1. Direct cardArtKey lookup
      final fileById = await manager.getFileFromCache(artKey);
      expect(fileById, isNotNull);
      expect(await fileById!.file.exists(), isTrue);

      // 2. Normalized URL lookup
      final fileByNormUrl = await manager.getFileFromCache(normUrl);
      expect(fileByNormUrl, isNotNull);
      expect(await fileByNormUrl!.file.exists(), isTrue);

      // 3. Raw URL with timestamp lookup (triggers normalization fallback)
      final fileByRawUrl = await manager.getFileFromCache(rawUrl);
      expect(fileByRawUrl, isNotNull);
      expect(await fileByRawUrl!.file.exists(), isTrue);
    });

    test('precacheDeckCover stores file accessible under deckCoverKey and URL', () async {
      final manager = CountrImageCacheManager.instance;
      const deckId = 'deck-edgar-test';
      const normUrl = 'https://cards.scryfall.io/art_crop/front/deck_edgar.jpg';
      final deckKey = CountrImageCacheManager.deckCoverKey(deckId);
      final dummyBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]);

      manager.registerKeyAlias(deckKey, normUrl);
      await manager.putFile(deckKey, dummyBytes, key: deckKey);
      await manager.putFile(normUrl, dummyBytes, key: normUrl);

      final fileByDeckKey = await manager.getFileFromCache(deckKey);
      expect(fileByDeckKey, isNotNull);

      final fileByUrl = await manager.getFileFromCache(normUrl);
      expect(fileByUrl, isNotNull);
    });
  });

  group('CountrHttpFileService: Network Interception & Failure Registry Integration', () {
    test('Throws HttpExceptionWithStatus(404) immediately without HTTP request for blocked URLs', () async {
      const blockedUrl = 'https://cards.scryfall.io/art/blocked_404.jpg';
      FailedImageRegistry.instance.markTerminal(
        blockedUrl,
        statusCode: 404,
        type: ImageFailureType.terminalNotFound,
      );

      bool networkCalled = false;
      final mockClient = MockClient((request) async {
        networkCalled = true;
        return http.Response('OK', 200);
      });

      final service = CountrHttpFileService(httpClient: mockClient);

      expect(
        () => service.get(blockedUrl),
        throwsA(isA<HttpExceptionWithStatus>().having((e) => e.statusCode, 'statusCode', 404)),
      );
      expect(networkCalled, isFalse, reason: 'Outbound network call must be short-circuited');
    });

    test('Intercepts HTTP 404 response and registers terminal failure in FailedImageRegistry', () async {
      const failingUrl = 'https://cards.scryfall.io/art/remote_404.jpg';
      final mockClient = MockClient((request) async {
        return http.Response('Not Found', 404);
      });

      final service = CountrHttpFileService(httpClient: mockClient);

      try {
        await service.get(failingUrl);
      } catch (_) {}

      expect(FailedImageRegistry.instance.isFailed(failingUrl), isTrue);
      expect(FailedImageRegistry.instance.isTerminal(failingUrl), isTrue);
    });

    test('Intercepts HTTP 500 response and increments attempt count as transient failure', () async {
      const serverErrorUrl = 'https://cards.scryfall.io/art/server_error.jpg';
      final mockClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final service = CountrHttpFileService(httpClient: mockClient);

      try {
        await service.get(serverErrorUrl);
      } catch (_) {}

      expect(FailedImageRegistry.instance.getAttempts(serverErrorUrl), equals(1));
      expect(FailedImageRegistry.instance.isFailed(serverErrorUrl), isFalse);
    });
  });
}
