import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/cache/countr_image_cache_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory mockCacheDir;
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUpAll(() {
    mockCacheDir = Directory.systemTemp.createTempSync('countr_m1_it2_challenger_');
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

  final dummyBytes = Uint8List.fromList([
    0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,
  ]);

  group('Adversarial 1: Deep Transitive Traversal (Chains, Diamonds, Cycles)', () {
    test('5-hop linear alias chain: A -> B -> C -> D -> E resolves file cached ONLY at E', () async {
      final manager = CountrImageCacheManager.instance;
      const keyA = 'key_hop_A';
      const keyB = 'key_hop_B';
      const keyC = 'key_hop_C';
      const keyD = 'key_hop_D';
      const keyE = 'key_hop_E';

      manager.registerKeyAlias(keyA, keyB);
      manager.registerKeyAlias(keyB, keyC);
      manager.registerKeyAlias(keyC, keyD);
      manager.registerKeyAlias(keyD, keyE);

      // Store file ONLY at keyE
      await manager.putFile(keyE, dummyBytes, key: keyE);

      // Lookup from head of chain: keyA
      final fileInfo = await manager.getFileFromCache(keyA);
      expect(fileInfo, isNotNull, reason: '5-hop chain must resolve file at tail keyE');
      expect(await fileInfo!.file.exists(), isTrue);

      // Verify transitive alias memoization: keyA now directly knows keyE
      expect(manager.resolveKeyAliases(keyA).contains(keyE), isTrue,
          reason: 'Transitive hit must register direct alias for O(1) subsequent lookup');
    });

    test('Diamond alias topology: A -> (B, C) -> D -> E resolves without duplicate stalls', () async {
      final manager = CountrImageCacheManager.instance;
      const keyA = 'diamond_A';
      const keyB = 'diamond_B';
      const keyC = 'diamond_C';
      const keyD = 'diamond_D';
      const keyE = 'diamond_E';

      manager.registerKeyAlias(keyA, keyB);
      manager.registerKeyAlias(keyA, keyC);
      manager.registerKeyAlias(keyB, keyD);
      manager.registerKeyAlias(keyC, keyD);
      manager.registerKeyAlias(keyD, keyE);

      await manager.putFile(keyE, dummyBytes, key: keyE);

      final fileInfo = await manager.getFileFromCache(keyA);
      expect(fileInfo, isNotNull, reason: 'Diamond topology must find keyE');
      expect(await fileInfo!.file.exists(), isTrue);
    });

    test('Cyclic alias topology: A -> B -> C -> A terminates cleanly without infinite loop', () async {
      final manager = CountrImageCacheManager.instance;
      const keyA = 'cycle_A';
      const keyB = 'cycle_B';
      const keyC = 'cycle_C';

      manager.registerKeyAlias(keyA, keyB);
      manager.registerKeyAlias(keyB, keyC);
      manager.registerKeyAlias(keyC, keyA);

      // Case 1: No file anywhere in the cycle -> returns null within milliseconds
      final stopwatch = Stopwatch()..start();
      final nullResult = await manager.getFileFromCache(keyA);
      stopwatch.stop();

      expect(nullResult, isNull);
      expect(stopwatch.elapsedMilliseconds, lessThan(200),
          reason: 'Cyclic graph without cached file must terminate promptly');

      // Case 2: File at keyC -> finds it immediately
      await manager.putFile(keyC, dummyBytes, key: keyC);
      final hitResult = await manager.getFileFromCache(keyA);
      expect(hitResult, isNotNull);
      expect(await hitResult!.file.exists(), isTrue);
    });

    test('Disconnected components: Querying keyX in component 1 never leaks to component 2', () async {
      final manager = CountrImageCacheManager.instance;
      const comp1A = 'c1_A';
      const comp1B = 'c1_B';
      const comp2C = 'c2_C';
      const comp2D = 'c2_D';

      manager.registerKeyAlias(comp1A, comp1B);
      manager.registerKeyAlias(comp2C, comp2D);

      await manager.putFile(comp2D, dummyBytes, key: comp2D);

      final result = await manager.getFileFromCache(comp1A);
      expect(result, isNull, reason: 'Disconnected component must not resolve');
    });
  });

  group('Adversarial 2: Tri-Key Permutation Robustness & Storage Combinations', () {
    test('Storage under canonical URL only: retrievable via raw URL and primary key regardless of alias order', () async {
      final manager = CountrImageCacheManager.instance;
      const cardId = 'tri_perm_001';
      const primaryKey = 'card_art_tri_perm_001';
      const normUrl = 'https://cards.scryfall.io/art_crop/front/tri_perm_001.jpg';
      const rawUrl = 'https://cards.scryfall.io/art_crop/front/tri_perm_001.jpg?1673148560';

      // Register aliases in reversed order
      manager.registerKeyAlias(rawUrl, normUrl);
      manager.registerKeyAlias(primaryKey, rawUrl);
      manager.registerKeyAlias(primaryKey, normUrl);

      // Store ONLY in normUrl
      await manager.putFile(normUrl, dummyBytes, key: normUrl);

      // Lookup via primaryKey
      final byPrimary = await manager.getFileFromCache(primaryKey);
      expect(byPrimary, isNotNull, reason: 'Must resolve primaryKey -> normUrl');

      // Lookup via rawUrl
      final byRaw = await manager.getFileFromCache(rawUrl);
      expect(byRaw, isNotNull, reason: 'Must resolve rawUrl -> normUrl');

      // Lookup via cardArtKey convenience
      final byConvenience = await manager.getCachedCardImage(cardId);
      expect(byConvenience, isNotNull, reason: 'getCachedCardImage must succeed');
    });

    test('Storage under raw URL only: retrievable via primary key and canonical URL', () async {
      final manager = CountrImageCacheManager.instance;
      const primaryKey = 'card_art_tri_raw_only';
      const normUrl = 'https://cards.scryfall.io/art_crop/front/tri_raw_only.jpg';
      const rawUrl = 'https://cards.scryfall.io/art_crop/front/tri_raw_only.jpg?1673148560';

      manager.registerKeyAlias(primaryKey, normUrl);
      manager.registerKeyAlias(primaryKey, rawUrl);
      manager.registerKeyAlias(rawUrl, normUrl);

      // Store ONLY in rawUrl
      await manager.putFile(rawUrl, dummyBytes, key: rawUrl);

      // Lookup via primaryKey
      final byPrimary = await manager.getFileFromCache(primaryKey);
      expect(byPrimary, isNotNull, reason: 'Must resolve primaryKey -> rawUrl');

      // Lookup via normUrl
      final byNorm = await manager.getFileFromCache(normUrl);
      expect(byNorm, isNotNull, reason: 'Must resolve normUrl -> rawUrl');
    });
  });

  group('Adversarial 3: URL Case Sensitivity, Encodings & Scheme Variations', () {
    test('Mixed-case scheme and host in raw URL resolves correctly to canonical lowercase entry', () async {
      final manager = CountrImageCacheManager.instance;
      const primaryKey = 'card_art_mixed_case';
      const normUrl = 'https://cards.scryfall.io/art_crop/front/case_test.jpg';
      const weirdUrl = 'HtTpS://CaRdS.ScRyFaLl.Io/art_crop/front/case_test.jpg?1673148560&v=1';

      manager.registerKeyAlias(primaryKey, normUrl);
      await manager.putFile(normUrl, dummyBytes, key: normUrl);

      // Querying weirdUrl should normalize scheme/host to lowercase, strip query string, and match normUrl
      final result = await manager.getFileFromCache(weirdUrl);
      expect(result, isNotNull, reason: 'Weird case scheme and host URL must resolve to normalized cached entry');
    });

    test('Percent-encoded spaces in URL paths preserved accurately', () {
      const url = 'https://cards.scryfall.io/art%20crop/front/card.jpg?12345';
      final norm = CountrImageCacheManager.normalizeUrl(url);
      expect(norm, equals('https://cards.scryfall.io/art%20crop/front/card.jpg'));
    });

    test('Non-CDN Scryfall named query URL retains query parameters intact', () {
      const namedUrl = 'https://api.scryfall.com/cards/named?exact=Black+Lotus&format=image&version=art_crop';
      final norm = CountrImageCacheManager.normalizeUrl(namedUrl);
      // Query parameters must NOT be stripped because host is api.scryfall.com and does not end in .jpg/.png
      expect(norm, equals(namedUrl), reason: 'Named card queries must not have query params stripped');
    });

    test('Generic PNG/WEBP with cache-busting params strips query cleanly', () {
      const pngUrl = 'https://storage.googleapis.com/countr-assets/card_art/lotus.png?v=999';
      const webpUrl = 'https://tcg-cdn.example.org/card_art/mox.webp?token=abc';

      expect(CountrImageCacheManager.normalizeUrl(pngUrl),
          equals('https://storage.googleapis.com/countr-assets/card_art/lotus.png'));
      expect(CountrImageCacheManager.normalizeUrl(webpUrl),
          equals('https://tcg-cdn.example.org/card_art/mox.webp'));
    });
  });

  group('Adversarial 4: Reverse Aliasing with High-Volume Repo Scan', () {
    test('Fallback repo scan locates raw URL among 50 distinct cached objects in repo', () async {
      final manager = CountrImageCacheManager.instance;
      const targetCardId = 'repo_scan_target';
      final targetPrimaryKey = CountrImageCacheManager.cardArtKey(targetCardId);
      const targetNormUrl = 'https://cards.scryfall.io/art_crop/front/target_card.jpg';
      const targetRawUrl = 'https://cards.scryfall.io/art_crop/front/target_card.jpg?ts=99887766';

      // Seed 50 decoy files in cache under various raw URLs
      for (int i = 0; i < 50; i++) {
        final decoyUrl = 'https://cards.scryfall.io/art_crop/front/decoy_$i.jpg?ts=$i';
        await manager.putFile(decoyUrl, dummyBytes, key: decoyUrl);
      }

      // Seed the target file under targetRawUrl
      await manager.putFile(targetRawUrl, dummyBytes, key: targetRawUrl);

      // Only link targetPrimaryKey to targetNormUrl (simulating widget knowing only cardId and canonical URL)
      manager.registerKeyAlias(targetPrimaryKey, targetNormUrl);

      // Look up targetPrimaryKey: must trigger repo scan, find targetRawUrl, and succeed
      final result = await manager.getFileFromCache(targetPrimaryKey);
      expect(result, isNotNull, reason: 'Repo scan must find raw URL matching normalized target URL');
      expect(await result!.file.exists(), isTrue);

      // Subsequent lookup should be O(1) without repo scan because alias was registered
      final fastResult = await manager.getFileFromCache(targetPrimaryKey);
      expect(fastResult, isNotNull);
    });
  });

  group('Adversarial 5: Concurrency, High Contention & Race Conditions', () {
    test('50 concurrent getFileFromCache calls on transitive alias execute safely without exceptions', () async {
      final manager = CountrImageCacheManager.instance;
      const keyA = 'concurrent_A';
      const keyB = 'concurrent_B';
      const keyC = 'concurrent_C';

      manager.registerKeyAlias(keyA, keyB);
      manager.registerKeyAlias(keyB, keyC);
      await manager.putFile(keyC, dummyBytes, key: keyC);

      final futures = List.generate(50, (_) => manager.getFileFromCache(keyA));
      final results = await Future.wait(futures);

      for (final res in results) {
        expect(res, isNotNull);
        expect(await res!.file.exists(), isTrue);
      }
    });

    test('Concurrent putFile and getFileFromCache on aliased keys does not deadlock or corrupt', () async {
      final manager = CountrImageCacheManager.instance;
      const primaryKey = 'concurrent_put_art';
      const normUrl = 'https://cards.scryfall.io/art_crop/front/concurrent_put.jpg';

      manager.registerKeyAlias(primaryKey, normUrl);

      final putFutures = List.generate(20, (i) => manager.putFile(primaryKey, dummyBytes, key: primaryKey));
      final getFutures = List.generate(20, (i) => manager.getFileFromCache(normUrl));

      await Future.wait([...putFutures, ...getFutures]);

      final verify = await manager.getFileFromCache(normUrl);
      expect(verify, isNotNull);
    });
  });

  group('Adversarial 6: Full Lifecycle Eviction & Registry Synchronization', () {
    test('evictCardArt removes disk cache, cleans alias graph, and resets failure registry', () async {
      final manager = CountrImageCacheManager.instance;
      const cardId = 'lifecycle_card_001';
      const primaryKey = 'card_art_lifecycle_card_001';
      const normUrl = 'https://cards.scryfall.io/art_crop/front/lifecycle_001.jpg';
      const rawUrl = 'https://cards.scryfall.io/art_crop/front/lifecycle_001.jpg?1673148560';

      manager.registerKeyAlias(primaryKey, normUrl);
      manager.registerKeyAlias(primaryKey, rawUrl);
      await manager.putFile(primaryKey, dummyBytes, key: primaryKey);
      await manager.putFile(normUrl, dummyBytes, key: normUrl);

      // Record a failure status
      FailedImageRegistry.instance.recordAttempt(normUrl, cacheKey: primaryKey, statusCode: 500);
      expect(FailedImageRegistry.instance.getAttempts(normUrl), equals(1));

      // Evict
      await manager.evictCardArt(cardId);

      // Verify files gone
      expect(await manager.getFileFromCache(primaryKey), isNull);
      expect(await manager.getFileFromCache(normUrl), isNull);

      // Verify failure registry reset
      expect(FailedImageRegistry.instance.getAttempts(primaryKey), equals(0));
      expect(FailedImageRegistry.instance.getAttempts(normUrl), equals(0));
    });

    test('evictUrl cleans normalized URL, raw URL, and linked primary keys', () async {
      final manager = CountrImageCacheManager.instance;
      const cardId = 'evict_url_card';
      final primaryKey = CountrImageCacheManager.cardArtKey(cardId);
      const rawUrl = 'https://cards.scryfall.io/art_crop/front/evict_url.jpg?1673148560';
      const normUrl = 'https://cards.scryfall.io/art_crop/front/evict_url.jpg';

      manager.registerKeyAlias(primaryKey, normUrl);
      manager.registerKeyAlias(primaryKey, rawUrl);
      await manager.putFile(normUrl, dummyBytes, key: normUrl);
      await manager.putFile(rawUrl, dummyBytes, key: rawUrl);

      FailedImageRegistry.instance.markTerminal(rawUrl, cacheKey: primaryKey, statusCode: 404);
      expect(FailedImageRegistry.instance.isFailed(rawUrl), isTrue);

      await manager.evictUrl(rawUrl);

      expect(await manager.getFileFromCache(rawUrl), isNull);
      expect(await manager.getFileFromCache(normUrl), isNull);
      expect(FailedImageRegistry.instance.isFailed(rawUrl), isFalse);
    });
  });

  group('Adversarial 7: Multi-Card Shared CDN URL Normalization & Collision Avoidance', () {
    test('Two different cardIds sharing the same Scryfall image URL resolve to same disk cache', () async {
      final manager = CountrImageCacheManager.instance;
      const cardId1 = 'mtg-sol-ring-printing-1';
      const cardId2 = 'mtg-sol-ring-printing-2';
      const rawUrl1 = 'https://cards.scryfall.io/art_crop/front/s/o/sol_ring.jpg?1673148560';
      const rawUrl2 = 'https://cards.scryfall.io/art_crop/front/s/o/sol_ring.jpg?1699999999';
      const normUrl = 'https://cards.scryfall.io/art_crop/front/s/o/sol_ring.jpg';

      final artKey1 = CountrImageCacheManager.cardArtKey(cardId1);
      final artKey2 = CountrImageCacheManager.cardArtKey(cardId2);

      // Card 1 pre-cached
      manager.registerKeyAlias(artKey1, normUrl);
      manager.registerKeyAlias(artKey1, rawUrl1);
      await manager.putFile(normUrl, dummyBytes, key: normUrl);

      // Card 2 registered with rawUrl2
      manager.registerKeyAlias(artKey2, normUrl);
      manager.registerKeyAlias(artKey2, rawUrl2);

      // Card 2 should find the file cached by Card 1 via normUrl
      final card2File = await manager.getFileFromCache(artKey2);
      expect(card2File, isNotNull, reason: 'Card 2 must find shared artwork cached via Card 1 canonical URL');
      expect(await card2File!.file.exists(), isTrue);

      // Card 2 raw URL should also find the file
      final card2RawFile = await manager.getFileFromCache(rawUrl2);
      expect(card2RawFile, isNotNull, reason: 'Card 2 raw URL must normalize and find shared artwork');
    });
  });

  group('Adversarial 8: Terminal Failure Propagation Across Full Tri-Key Alias Graph', () {
    test('Marking primaryKey terminal propagates to canonical URL and raw URL in registry', () {
      final manager = CountrImageCacheManager.instance;
      final registry = FailedImageRegistry.instance;
      const primaryKey = 'card_art_term_prop_01';
      const normUrl = 'https://cards.scryfall.io/art_crop/front/term_prop_01.jpg';
      const rawUrl = 'https://cards.scryfall.io/art_crop/front/term_prop_01.jpg?ts=123';

      manager.registerKeyAlias(primaryKey, normUrl);
      manager.registerKeyAlias(primaryKey, rawUrl);
      manager.registerKeyAlias(rawUrl, normUrl);

      registry.markTerminal(primaryKey, statusCode: 404, type: ImageFailureType.terminalNotFound);

      expect(registry.isFailed(primaryKey), isTrue);
      expect(registry.isTerminal(primaryKey), isTrue);
      expect(registry.isFailed(normUrl), isTrue, reason: 'Terminal status must propagate to normUrl');
      expect(registry.isTerminal(normUrl), isTrue);
      expect(registry.isFailed(rawUrl), isTrue, reason: 'Terminal status must propagate to rawUrl');
      expect(registry.isTerminal(rawUrl), isTrue);
    });

    test('Marking raw URL terminal propagates to primaryKey and canonical URL', () {
      final manager = CountrImageCacheManager.instance;
      final registry = FailedImageRegistry.instance;
      const primaryKey = 'card_art_term_prop_02';
      const normUrl = 'https://cards.scryfall.io/art_crop/front/term_prop_02.jpg';
      const rawUrl = 'https://cards.scryfall.io/art_crop/front/term_prop_02.jpg?ts=456';

      manager.registerKeyAlias(primaryKey, normUrl);
      manager.registerKeyAlias(primaryKey, rawUrl);
      manager.registerKeyAlias(rawUrl, normUrl);

      registry.markTerminal(rawUrl, statusCode: 404, type: ImageFailureType.terminalNotFound);

      expect(registry.isFailed(rawUrl), isTrue);
      expect(registry.isTerminal(rawUrl), isTrue);
      expect(registry.isFailed(normUrl), isTrue);
      expect(registry.isTerminal(normUrl), isTrue);
      expect(registry.isFailed(primaryKey), isTrue);
      expect(registry.isTerminal(primaryKey), isTrue);
    });
  });

  group('Adversarial 9: Edge Case Key Resolution & Null Safety Invariants', () {
    test('cacheKeyFor invariants with boundary conditions', () {
      // Nulls and empties
      expect(CountrImageCacheManager.cacheKeyFor(), equals(''));
      expect(CountrImageCacheManager.cacheKeyFor(cardId: '', imageUrl: '', cacheKey: ''), equals(''));
      expect(CountrImageCacheManager.cacheKeyFor(cardId: null, imageUrl: null, cacheKey: null), equals(''));

      // Explicit key takes top priority
      expect(
        CountrImageCacheManager.cacheKeyFor(
          cacheKey: 'explicit_key_wins',
          cardId: 'card-123',
          imageUrl: 'https://example.com/art.jpg',
        ),
        equals('explicit_key_wins'),
      );

      // deck- prefix
      expect(
        CountrImageCacheManager.cacheKeyFor(cardId: 'deck-my-deck'),
        equals('deck_cover_deck-my-deck'),
      );

      // regular cardId
      expect(
        CountrImageCacheManager.cacheKeyFor(cardId: 'lotus-001'),
        equals('card_art_lotus-001'),
      );

      // imageUrl fallback with normalization
      expect(
        CountrImageCacheManager.cacheKeyFor(
          imageUrl: 'https://cards.scryfall.io/art/crop.jpg?1673148560',
        ),
        equals('https://cards.scryfall.io/art/crop.jpg'),
      );
    });

    test('isImageCacheHealthy accurately reflects cache presence', () async {
      final manager = CountrImageCacheManager.instance;
      const testCardId = 'item-health-test-01';
      final artKey = CountrImageCacheManager.cardArtKey(testCardId);

      // Initially false
      expect(await manager.isImageCacheHealthy(sampleCardIds: [testCardId]), isFalse);

      // Put art in cache
      await manager.putFile(artKey, dummyBytes, key: artKey);

      // Now true
      expect(await manager.isImageCacheHealthy(sampleCardIds: [testCardId]), isTrue);
    });
  });
}
