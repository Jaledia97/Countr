import 'dart:async';
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
    mockCacheDir = Directory.systemTemp.createTempSync('countr_m1_challenger_1_');
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
    FailedImageRegistry.instance.maxAttempts = 3;
  });

  tearDown(() {
    FailedImageRegistry.instance.clear();
  });

  final dummyJpegBytes = Uint8List.fromList([
    0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,
  ]);

  group('Dimension 1: Key Aliasing Invariant (Pre-cache art & multi-path retrieval)', () {
    test('Pre-cached art under cardId is retrievable via all 4 required query variants', () async {
      final manager = CountrImageCacheManager.instance;
      const cardId = 'mtg-sol-ring-001';
      const rawUrlWithTimestamp = 'https://cards.scryfall.io/art_crop/front/0/1/01234567-abcd.jpg?1673148560';
      const canonicalNormUrl = 'https://cards.scryfall.io/art_crop/front/0/1/01234567-abcd.jpg';
      const rawUrlWithMultiParams = 'https://cards.scryfall.io/art_crop/front/0/1/01234567-abcd.jpg?1673148560&v=2&format=art_crop&utm_source=tcg';

      final artKey = CountrImageCacheManager.cardArtKey(cardId);

      // Simulate full dual-key pre-caching behavior
      manager.registerKeyAlias(artKey, canonicalNormUrl);
      manager.registerKeyAlias(artKey, rawUrlWithTimestamp);
      manager.registerKeyAlias(rawUrlWithTimestamp, canonicalNormUrl);

      await manager.putFile(artKey, dummyJpegBytes, key: artKey);
      await manager.putFile(canonicalNormUrl, dummyJpegBytes, key: canonicalNormUrl);
      await manager.putFile(rawUrlWithTimestamp, dummyJpegBytes, key: rawUrlWithTimestamp);

      // Path a: cardArtKey(cardId)
      final resA = await manager.getFileFromCache(artKey);
      expect(resA, isNotNull, reason: 'Path (a) cardArtKey must hit disk cache');
      expect(await resA!.file.exists(), isTrue);

      // Path b: canonical normalized URL
      final resB = await manager.getFileFromCache(canonicalNormUrl);
      expect(resB, isNotNull, reason: 'Path (b) canonical normalized URL must hit disk cache');
      expect(await resB!.file.exists(), isTrue);

      // Path c: raw URL with timestamp query parameter
      final resC = await manager.getFileFromCache(rawUrlWithTimestamp);
      expect(resC, isNotNull, reason: 'Path (c) raw URL with timestamp must hit disk cache');
      expect(await resC!.file.exists(), isTrue);

      // Path d: raw URL with multiple query parameters (relies on normalization fallback)
      final resD = await manager.getFileFromCache(rawUrlWithMultiParams);
      expect(resD, isNotNull, reason: 'Path (d) raw URL with multiple params must normalize and hit disk cache');
      expect(await resD!.file.exists(), isTrue);
    });

    test('Upper-cased scheme and host in URL query normalizes and retrieves pre-cached art', () async {
      final manager = CountrImageCacheManager.instance;
      const cardId = 'mtg-upper-test-002';
      const normUrl = 'https://cards.scryfall.io/art_crop/front/upper.jpg';
      const upperRawUrl = 'HTTPS://CARDS.SCRYFALL.IO/art_crop/front/upper.jpg?1673148560&other=xyz';

      final artKey = CountrImageCacheManager.cardArtKey(cardId);
      manager.registerKeyAlias(artKey, normUrl);
      await manager.putFile(normUrl, dummyJpegBytes, key: normUrl);

      final file = await manager.getFileFromCache(upperRawUrl);
      expect(file, isNotNull, reason: 'URL with upper-case scheme/host must resolve via canonical normalization');
    });

    test('Key aliasing invariant when art is stored ONLY under primary cardArtKey', () async {
      final manager = CountrImageCacheManager.instance;
      const cardId = 'mtg-primary-only-003';
      const normUrl = 'https://cards.scryfall.io/art_crop/front/primary_only.jpg';
      const rawUrlWithTimestamp = 'https://cards.scryfall.io/art_crop/front/primary_only.jpg?1673148560';

      final artKey = CountrImageCacheManager.cardArtKey(cardId);

      // Only link primary key and canonical URL without seeding secondary URL cache
      manager.registerKeyAlias(artKey, normUrl);
      await manager.putFile(artKey, dummyJpegBytes, key: artKey);

      // Direct lookup
      final resPrimary = await manager.getFileFromCache(artKey);
      expect(resPrimary, isNotNull);

      // Lookup via normUrl should resolve to primary key via registered alias
      final resNorm = await manager.getFileFromCache(normUrl);
      expect(
        resNorm,
        isNotNull,
        reason: 'Lookup via normUrl must find item stored under artKey via registered alias',
      );

      // Lookup via rawUrlWithTimestamp should normalize to normUrl and find artKey
      final resRaw = await manager.getFileFromCache(rawUrlWithTimestamp);
      expect(
        resRaw,
        isNotNull,
        reason: 'Lookup via raw URL with timestamp must normalize and resolve artKey via alias',
      );
    });

    test('Tri-key aliasing sequence: Pre-cache registration severs primaryKey link when file is only in primaryKey', () async {
      final manager = CountrImageCacheManager.instance;
      const cardId = 'mtg-tri-alias-card-004';
      const normUrl = 'https://cards.scryfall.io/art_crop/front/tri_alias.jpg';
      const rawUrl = 'https://cards.scryfall.io/art_crop/front/tri_alias.jpg?1673148560';

      final primaryKey = CountrImageCacheManager.cardArtKey(cardId);

      // This is the EXACT sequence executed in precacheCardArt lines 232-236:
      manager.registerKeyAlias(primaryKey, normUrl);
      manager.registerKeyAlias(primaryKey, rawUrl);
      manager.registerKeyAlias(rawUrl, normUrl);

      // File is stored only under primaryKey
      await manager.putFile(primaryKey, dummyJpegBytes, key: primaryKey);

      // Querying by normUrl should retrieve the card art via alias
      final fileByNorm = await manager.getFileFromCache(normUrl);
      expect(
        fileByNorm,
        isNotNull,
        reason: 'normUrl must resolve to primaryKey even after tri-key alias registration',
      );

      // Querying by rawUrl should retrieve the card art via alias
      final fileByRaw = await manager.getFileFromCache(rawUrl);
      expect(
        fileByRaw,
        isNotNull,
        reason: 'rawUrl must resolve to primaryKey even after tri-key alias registration',
      );
    });
  });

  group('Dimension 2: Reverse Aliasing (Cache by URL, Retrieve by cardId)', () {
    test('Image cached under canonical URL is retrievable by cardId', () async {
      final manager = CountrImageCacheManager.instance;
      const cardId = 'mtg-reverse-card-001';
      const normUrl = 'https://cards.scryfall.io/art_crop/front/reverse_art.jpg';

      final artKey = CountrImageCacheManager.cardArtKey(cardId);

      // Cache directly under URL
      await manager.putFile(normUrl, dummyJpegBytes, key: normUrl);

      // Register alias between cardId key and URL
      manager.registerKeyAlias(artKey, normUrl);

      // Retrieve via cardArtKey
      final cachedInfo = await manager.getFileFromCache(artKey);
      expect(cachedInfo, isNotNull, reason: 'Retrieving by cardArtKey must find file stored under canonical URL');
      expect(await cachedInfo!.file.exists(), isTrue);

      // Also verify convenience accessor getCachedCardImage
      final convenienceInfo = await manager.getCachedCardImage(cardId);
      expect(convenienceInfo, isNotNull, reason: 'getCachedCardImage must succeed via reverse alias');
    });

    test('Image cached under raw URL with query params is retrievable by cardId', () async {
      final manager = CountrImageCacheManager.instance;
      const cardId = 'mtg-reverse-raw-002';
      const rawUrl = 'https://cards.scryfall.io/art_crop/front/reverse_raw.jpg?1673148560';
      const normUrl = 'https://cards.scryfall.io/art_crop/front/reverse_raw.jpg';

      final artKey = CountrImageCacheManager.cardArtKey(cardId);

      // File was cached under raw URL
      await manager.putFile(rawUrl, dummyJpegBytes, key: rawUrl);

      // Linked with normUrl and/or rawUrl
      manager.registerKeyAlias(artKey, normUrl);

      // Retrieve via cardArtKey
      final cachedInfo = await manager.getFileFromCache(artKey);
      expect(
        cachedInfo,
        isNotNull,
        reason: 'Retrieving by cardArtKey must find file stored under raw URL via alias and normalization',
      );
    });

    test('evictCardArt clears both primary key, alias entry, and failed registry status', () async {
      final manager = CountrImageCacheManager.instance;
      const cardId = 'mtg-evict-card-002';
      const normUrl = 'https://cards.scryfall.io/art_crop/front/evict_art.jpg';

      final artKey = CountrImageCacheManager.cardArtKey(cardId);
      manager.registerKeyAlias(artKey, normUrl);
      await manager.putFile(artKey, dummyJpegBytes, key: artKey);
      await manager.putFile(normUrl, dummyJpegBytes, key: normUrl);
      FailedImageRegistry.instance.recordAttempt(artKey, statusCode: 500);

      // Evict card art
      await manager.evictCardArt(cardId);

      // Both should be evicted from disk cache
      final checkArt = await manager.getFileFromCache(artKey);
      final checkUrl = await manager.getFileFromCache(normUrl);
      expect(checkArt, isNull);
      expect(checkUrl, isNull);

      // Failure registry should be reset
      expect(FailedImageRegistry.instance.getAttempts(artKey), equals(0));
    });
  });

  group('Dimension 3: Deck Cover Pre-Cache & Aliased Retrieval', () {
    test('Starter deck cover pre-cached file is retrievable under deck_cover_deckId and URLs', () async {
      final manager = CountrImageCacheManager.instance;
      const deckId = 'deck-starter-commander-001';
      const normUrl = 'https://cards.scryfall.io/art_crop/front/commander_edgar.jpg';
      const rawUrl = 'https://cards.scryfall.io/art_crop/front/commander_edgar.jpg?1673148560';

      final deckKey = CountrImageCacheManager.deckCoverKey(deckId);
      expect(deckKey, equals('deck_cover_deck-starter-commander-001'));

      // Pre-cache under deckCoverKey and URL
      manager.registerKeyAlias(deckKey, normUrl);
      manager.registerKeyAlias(deckKey, rawUrl);
      manager.registerKeyAlias(rawUrl, normUrl);

      await manager.putFile(deckKey, dummyJpegBytes, key: deckKey);
      await manager.putFile(normUrl, dummyJpegBytes, key: normUrl);

      // 1. Direct deck cover key lookup
      final resDeckKey = await manager.getFileFromCache(deckKey);
      expect(resDeckKey, isNotNull, reason: 'deck_cover_$deckId must hit disk cache');
      expect(await resDeckKey!.file.exists(), isTrue);

      // 2. Canonical URL lookup
      final resNorm = await manager.getFileFromCache(normUrl);
      expect(resNorm, isNotNull, reason: 'Canonical URL must hit disk cache');

      // 3. Raw URL with timestamp lookup
      final resRaw = await manager.getFileFromCache(rawUrl);
      expect(resRaw, isNotNull, reason: 'Raw URL must resolve via normalization');

      // 4. Verify cacheKeyFor handles deck- prefix
      final computedKey = CountrImageCacheManager.cacheKeyFor(cardId: deckId);
      expect(computedKey, equals(deckKey));
    });

    test('evictDeckCover cleans up disk cache and failure registry', () async {
      final manager = CountrImageCacheManager.instance;
      const deckId = 'deck-evict-002';
      const normUrl = 'https://cards.scryfall.io/art_crop/front/deck_evict.jpg';
      final deckKey = CountrImageCacheManager.deckCoverKey(deckId);

      manager.registerKeyAlias(deckKey, normUrl);
      await manager.putFile(deckKey, dummyJpegBytes, key: deckKey);
      await manager.putFile(normUrl, dummyJpegBytes, key: normUrl);

      await manager.evictDeckCover(deckId);

      expect(await manager.getFileFromCache(deckKey), isNull);
      expect(await manager.getFileFromCache(normUrl), isNull);
    });
  });

  group('Dimension 4: Massive Failed Image Registry Stress (Scale, Throughput, Zero Leaks)', () {
    test('Registering 200 distinct failed URLs scales cleanly with O(1) instant lookup', () {
      final registry = FailedImageRegistry.instance;
      registry.clear();

      final urls = List.generate(200, (i) => 'https://cards.scryfall.io/art_crop/front/failed_$i.jpg');

      // 1. Register 200 failed URLs across various statuses and linkings
      for (int i = 0; i < 200; i++) {
        final url = urls[i];
        final cacheKey = 'card_art_bulk_$i';
        if (i % 4 == 0) {
          // Terminal 404
          registry.markTerminal(url, cacheKey: cacheKey, statusCode: 404, type: ImageFailureType.terminalNotFound);
        } else if (i % 4 == 1) {
          // Terminal client error (400, 403, 410, 422)
          final code = [400, 403, 410, 422][i % 4];
          registry.markTerminal(url, cacheKey: cacheKey, statusCode: code, type: ImageFailureType.terminalClientError);
        } else if (i % 4 == 2) {
          // Exhausted retries (transient repeated 3 times)
          registry.recordAttempt(url, cacheKey: cacheKey, statusCode: 500);
          registry.recordAttempt(url, cacheKey: cacheKey, statusCode: 500);
          registry.recordAttempt(url, cacheKey: cacheKey, statusCode: 500);
        } else {
          // Inherent invalid URI
          registry.markTerminal('invalid_scheme_$i://bad', cacheKey: cacheKey, type: ImageFailureType.terminalInvalidUri);
        }
      }

      // Assert registry tracks distinct failures
      expect(registry.failedCount, equals(200), reason: 'All 200 URLs must be tracked as failed');

      // 2. High-throughput query benchmark (10,000 lookups)
      final stopwatch = Stopwatch()..start();
      for (int cycle = 0; cycle < 50; cycle++) {
        for (int i = 0; i < 200; i++) {
          final url = urls[i];
          final cacheKey = 'card_art_bulk_$i';
          final failed = registry.isFailed(url, cacheKey: cacheKey);
          expect(failed, isTrue);
          final terminal = registry.isTerminal(url, cacheKey: cacheKey);
          expect(terminal, isTrue);
        }
      }
      stopwatch.stop();

      // 10,000 lookups should take less than 150ms in memory (pure O(1) map lookups)
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(500),
        reason: '10,000 registry queries must complete within 500ms; actual: ${stopwatch.elapsedMilliseconds}ms',
      );
    });

    test('Zero memory leak: Selective reset and global clear completely release records', () {
      final registry = FailedImageRegistry.instance;
      registry.clear();

      final urls = List.generate(200, (i) => 'https://example.com/leak_test_$i.jpg');
      for (int i = 0; i < 200; i++) {
        registry.markTerminal(urls[i], cacheKey: 'key_$i', statusCode: 404);
      }
      expect(registry.failedCount, equals(200));

      // Selective reset of 50 items
      for (int i = 0; i < 50; i++) {
        registry.reset(urls[i], cacheKey: 'key_$i');
        expect(registry.isFailed(urls[i]), isFalse);
        expect(registry.isTerminal(urls[i]), isFalse);
      }
      expect(registry.failedCount, equals(150));

      // Global clear drops all remaining 150 items
      registry.clear();
      expect(registry.failedCount, equals(0));
      expect(registry.allFailedKeys, isEmpty);

      // Re-verify that queried keys return cleanly without residual state
      for (int i = 0; i < 200; i++) {
        expect(registry.isFailed(urls[i]), isFalse);
        expect(registry.getRecord(urls[i]), isNull);
        expect(registry.getAttempts(urls[i]), equals(0));
      }
    });
  });

  group('Dimension 5: HTTP Status Code Rigor & Interception Matrix', () {
    test('Simulated HTTP 404: Terminal lock on first attempt, short-circuits network calls', () async {
      const url = 'https://cards.scryfall.io/art/simulated_404.jpg';
      int networkCallCount = 0;

      final mockClient = MockClient((request) async {
        networkCallCount++;
        return http.Response('Not Found', 404);
      });

      final service = CountrHttpFileService(httpClient: mockClient);

      // Attempt 1: Call service.get(url). The service captures status 404 and marks terminal.
      final response1 = await service.get(url);
      expect(response1.statusCode, equals(404));
      expect(networkCallCount, equals(1));
      expect(FailedImageRegistry.instance.isFailed(url), isTrue);
      expect(FailedImageRegistry.instance.isTerminal(url), isTrue);
      expect(
        FailedImageRegistry.instance.getRecord(url)!.failureType,
        equals(ImageFailureType.terminalNotFound),
      );

      // Attempt 2: Frame-0 short circuit (throws HttpExceptionWithStatus, NO network call)
      try {
        await service.get(url);
        fail('Attempt 2 must throw HttpExceptionWithStatus because URL is blocked');
      } catch (e) {
        expect(e, isA<HttpExceptionWithStatus>());
        expect((e as HttpExceptionWithStatus).statusCode, equals(404));
      }
      expect(networkCallCount, equals(1), reason: 'Subsequent attempt must not reach network');
    });

    test('Simulated Client Errors (400, 403, 410, 422): Immediate terminalClientError lock', () async {
      final codes = [400, 403, 410, 422];

      for (final code in codes) {
        final url = 'https://example.com/art_status_$code.jpg';
        int networkCallCount = 0;
        final mockClient = MockClient((request) async {
          networkCallCount++;
          return http.Response('Client Error $code', code);
        });

        final service = CountrHttpFileService(httpClient: mockClient);

        final response = await service.get(url);
        expect(response.statusCode, equals(code));
        expect(networkCallCount, equals(1));

        expect(FailedImageRegistry.instance.isFailed(url), isTrue, reason: 'HTTP $code must lock');
        expect(FailedImageRegistry.instance.isTerminal(url), isTrue, reason: 'HTTP $code must be terminal');
        final record = FailedImageRegistry.instance.getRecord(url);
        expect(record, isNotNull);
        expect(record!.failureType, equals(ImageFailureType.terminalClientError));
        expect(record.httpStatusCode, equals(code));

        // Subsequent attempt short-circuits
        try {
          await service.get(url);
          fail('Blocked URL must throw on subsequent get');
        } catch (e) {
          expect(e, isA<HttpExceptionWithStatus>());
        }
        expect(networkCallCount, equals(1), reason: 'Network must not be called after terminal lock');
      }
    });

    test('Simulated Rate Limit (429): Transient backoff behavior across 3 attempts', () async {
      const url = 'https://api.scryfall.com/art_rate_limit_429.jpg';
      int networkCallCount = 0;

      final mockClient = MockClient((request) async {
        networkCallCount++;
        return http.Response('Too Many Requests', 429);
      });

      final service = CountrHttpFileService(httpClient: mockClient);

      // Attempt 1: Transient failure
      final resp1 = await service.get(url);
      expect(resp1.statusCode, equals(429));
      expect(networkCallCount, equals(1));
      expect(FailedImageRegistry.instance.getAttempts(url), equals(1));
      expect(FailedImageRegistry.instance.isFailed(url), isFalse, reason: 'Attempt 1 of 429 must not lock');
      expect(FailedImageRegistry.instance.isTerminal(url), isFalse);

      // Attempt 2: Still transient
      final resp2 = await service.get(url);
      expect(resp2.statusCode, equals(429));
      expect(networkCallCount, equals(2));
      expect(FailedImageRegistry.instance.getAttempts(url), equals(2));
      expect(FailedImageRegistry.instance.isFailed(url), isFalse, reason: 'Attempt 2 of 429 must not lock');

      // Attempt 3: Exhausts session cap (3) -> Locks as terminal
      final resp3 = await service.get(url);
      expect(resp3.statusCode, equals(429));
      expect(networkCallCount, equals(3));
      expect(FailedImageRegistry.instance.getAttempts(url), equals(3));
      expect(FailedImageRegistry.instance.isFailed(url), isTrue, reason: 'Attempt 3 must reach cap and lock');
      expect(FailedImageRegistry.instance.isTerminal(url), isTrue);
      expect(
        FailedImageRegistry.instance.getRecord(url)!.failureType,
        equals(ImageFailureType.exhaustedRetries),
      );

      // Attempt 4: Short-circuited without network request
      try {
        await service.get(url);
        fail('Attempt 4 must throw because retries are exhausted');
      } catch (e) {
        expect(e, isA<HttpExceptionWithStatus>());
      }
      expect(networkCallCount, equals(3), reason: 'Attempt 4 must be blocked at frame-0 without network call');
    });

    test('Simulated Server Errors (500, 503): Transient retry backoff and capped lock', () async {
      final serverCodes = [500, 503];

      for (final code in serverCodes) {
        final url = 'https://cards.scryfall.io/art/server_$code.jpg';
        int networkCallCount = 0;

        final mockClient = MockClient((request) async {
          networkCallCount++;
          return http.Response('Server Error $code', code);
        });

        final service = CountrHttpFileService(httpClient: mockClient);

        // Attempt 1
        final r1 = await service.get(url);
        expect(r1.statusCode, equals(code));
        expect(FailedImageRegistry.instance.isFailed(url), isFalse);
        expect(networkCallCount, equals(1));

        // Attempt 2
        final r2 = await service.get(url);
        expect(r2.statusCode, equals(code));
        expect(FailedImageRegistry.instance.isFailed(url), isFalse);
        expect(networkCallCount, equals(2));

        // Attempt 3 (Reaches cap of 3)
        final r3 = await service.get(url);
        expect(r3.statusCode, equals(code));
        expect(FailedImageRegistry.instance.isFailed(url), isTrue);
        expect(FailedImageRegistry.instance.isTerminal(url), isTrue);
        expect(
          FailedImageRegistry.instance.getRecord(url)!.failureType,
          equals(ImageFailureType.exhaustedRetries),
        );
        expect(networkCallCount, equals(3));

        // Attempt 4 is blocked
        try {
          await service.get(url);
          fail('Attempt 4 must be blocked');
        } catch (e) {
          expect(e, isA<HttpExceptionWithStatus>());
        }
        expect(networkCallCount, equals(3));
      }
    });

    test('Simulated SocketException & TimeoutException handled as transient retries', () async {
      const url = 'https://cards.scryfall.io/art/timeout.jpg';
      int networkCallCount = 0;

      final mockClient = MockClient((request) async {
        networkCallCount++;
        if (networkCallCount == 1) {
          throw const SocketException('Network unreachable');
        } else if (networkCallCount == 2) {
          throw TimeoutException('Request timed out after 5000ms');
        } else {
          throw const SocketException('Connection reset by peer');
        }
      });

      final service = CountrHttpFileService(httpClient: mockClient);

      // Attempt 1: SocketException
      try {
        await service.get(url);
        fail('Should throw SocketException');
      } catch (e) {
        expect(e, isA<SocketException>());
      }
      expect(networkCallCount, equals(1));
      expect(FailedImageRegistry.instance.getAttempts(url), equals(1));
      expect(FailedImageRegistry.instance.isFailed(url), isFalse);

      // Attempt 2: TimeoutException
      try {
        await service.get(url);
        fail('Should throw TimeoutException');
      } catch (e) {
        expect(e, isA<TimeoutException>());
      }
      expect(networkCallCount, equals(2));
      expect(FailedImageRegistry.instance.getAttempts(url), equals(2));
      expect(FailedImageRegistry.instance.isFailed(url), isFalse);

      // Attempt 3: Cap exhausted
      try {
        await service.get(url);
        fail('Should throw SocketException');
      } catch (e) {
        expect(e, isA<SocketException>());
      }
      expect(networkCallCount, equals(3));
      expect(FailedImageRegistry.instance.getAttempts(url), equals(3));
      expect(FailedImageRegistry.instance.isFailed(url), isTrue);
      expect(FailedImageRegistry.instance.isTerminal(url), isTrue);
    });
  });

  group('Dimension 6: Adversarial Boundary & Hostile Input Tests', () {
    test('Non-HTTP/HTTPS invalid URI schemes are rejected immediately as terminalInvalidUri', () {
      final registry = FailedImageRegistry.instance;
      final hostileUris = [
        'javascript:alert(1)',
        'data:image/svg+xml;base64,PHN2Zz48L3N2Zz4=',
        'ftp://anonymous@ftp.example.com/card.png',
        'about:blank',
        'ws://realtime-images.example.com',
        'blob:http://localhost/uuid',
        'chrome://settings',
      ];

      for (final badUri in hostileUris) {
        expect(
          registry.isFailed(badUri),
          isTrue,
          reason: '$badUri must be recognized as inherently invalid URI',
        );
        expect(
          registry.isTerminal(badUri),
          isTrue,
          reason: '$badUri must be recognized as terminal invalid URI',
        );
      }
    });

    test('Whitespace-padded and empty URLs handled gracefully without state corruption', () {
      final registry = FailedImageRegistry.instance;
      expect(registry.isFailed(''), isTrue);
      expect(registry.isFailed('   '), isTrue);
      expect(registry.isTerminal(''), isTrue);
      expect(registry.isTerminal('   '), isTrue);

      const paddedUrl = '  https://cards.scryfall.io/art/padded.jpg   ';
      const cleanUrl = 'https://cards.scryfall.io/art/padded.jpg';

      registry.markTerminal(paddedUrl, statusCode: 404);
      expect(registry.isFailed(cleanUrl), isTrue, reason: 'Trimmed query must match padded registration');
      expect(registry.isFailed(paddedUrl), isTrue);
    });

    test('Bidirectional linkKeys propagates terminal failure regardless of order of registration', () {
      final registry = FailedImageRegistry.instance;
      const url = 'https://cards.scryfall.io/art/ordered_test.jpg';
      const cacheKey = 'card_art_ordered_test';

      // Record failure on cacheKey FIRST before linking
      registry.recordAttempt(cacheKey, statusCode: 404);
      expect(registry.isFailed(cacheKey), isTrue);
      expect(registry.isFailed(url), isFalse);

      // Now link
      registry.linkKeys(url, cacheKey);

      // Both should now be marked failed and terminal
      expect(registry.isFailed(url), isTrue);
      expect(registry.isTerminal(url), isTrue);
      expect(registry.isFailed(cacheKey), isTrue);
      expect(registry.isTerminal(cacheKey), isTrue);
    });
  });
}
