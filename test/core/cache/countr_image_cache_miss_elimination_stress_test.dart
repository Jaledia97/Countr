import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/cache/countr_image_cache_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory mockCacheDir;
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUpAll(() {
    mockCacheDir = Directory.systemTemp.createTempSync('countr_cache_miss_stress_');
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

  group('Milestone 2 R2 Challenger: Cache Miss Resolution Without getAllObjects() (F9)', () {
    late CountrImageCacheManager cacheManager;

    setUp(() {
      cacheManager = CountrImageCacheManager.instance;
      FailedImageRegistry.instance.clear();
    });

    test('200 rapid cache misses complete with zero disk stall (< 250ms)', () async {
      final stopwatch = Stopwatch()..start();

      // Trigger 200 distinct cache misses
      for (int i = 0; i < 200; i++) {
        final nonExistentKey = 'non_existent_key_$i';
        final file = await cacheManager.getFileFromCache(nonExistentKey);
        expect(file, isNull);
      }
      stopwatch.stop();

      // All 200 misses should finish in well under 250ms (average < 1.25ms per miss)
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(250),
        reason: 'Cache misses must resolve in sub-millisecond time without scanning table records',
      );
    });

    test('Cache hit integrity remains preserved after cache miss elimination', () async {
      const cardId = 'test-scryfall-card-hit';
      const rawUrl = 'https://cards.scryfall.io/normal/front/a/b/ab123456.jpg?167890';
      final normUrl = CountrImageCacheManager.normalizeUrl(rawUrl);
      final artKey = CountrImageCacheManager.cardArtKey(cardId);

      // Pre-create dummy cached file
      final tempFile = File('${mockCacheDir.path}/test_cached_card.jpg');
      await tempFile.writeAsBytes(List.filled(100, 42));

      // Put file into cache manager
      await cacheManager.putFile(
        artKey,
        tempFile.readAsBytesSync(),
        key: artKey,
      );

      cacheManager.registerCardAliases(
        cardId: cardId,
        imageUrl: rawUrl,
        cacheKey: artKey,
        cardName: 'Counterspell',
        version: 'normal',
      );

      // Lookup by direct artKey
      final hitByKey = await cacheManager.getFileFromCache(artKey);
      expect(hitByKey, isNotNull);
      expect(await hitByKey!.file.exists(), isTrue);

      // Lookup by normalized URL
      final hitByUrl = await cacheManager.getFileFromCache(normUrl);
      expect(hitByUrl, isNotNull);
      expect(await hitByUrl!.file.exists(), isTrue);

      // Subsequent miss does not break cache
      final miss = await cacheManager.getFileFromCache('random_miss_key');
      expect(miss, isNull);

      // Cache hit still succeeds
      final hitAgain = await cacheManager.getFileFromCache(artKey);
      expect(hitAgain, isNotNull);
    });
  });
}
