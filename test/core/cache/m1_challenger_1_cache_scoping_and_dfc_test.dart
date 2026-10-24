import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/core/cache/countr_cached_image.dart';
import 'package:countr/core/cache/countr_image_cache_manager.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/presentation/widgets/full_screen_card_viewer.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_card.dart';

VaultItem createChallengerVaultItem({
  required String id,
  required String name,
  String collectionType = 'mtg',
  String setOrSeries = 'MH2',
  String imageUrl = 'https://cards.scryfall.io/normal/front/1/2/12345.jpg',
  double currentMarketPrice = 25.0,
  int quantity = 1,
  Map<String, dynamic>? dynamicDataMap,
}) {
  return VaultItem(
    id: id,
    collectionType: collectionType,
    name: name,
    setOrSeries: setOrSeries,
    imageUrl: imageUrl,
    acquiredPrice: 20.0,
    acquiredDate: DateTime(2022, 1, 1),
    quantity: quantity,
    condition: 'NM',
    isGraded: false,
    isAltered: false,
    isMisprint: false,
    isSigned: false,
    isDeleted: false,
    currentMarketPrice: currentMarketPrice,
    lastPriceUpdate: DateTime(2022, 1, 1),
    dynamicData: jsonEncode(dynamicDataMap ?? {
      'layout': 'normal',
      'mana_cost': '{1}{U}',
      'type_line': 'Creature',
      'rarity': 'rare',
    }),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory mockCacheDir;
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUpAll(() {
    mockCacheDir = Directory.systemTemp.createTempSync('countr_m1_c1_cache_');
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

  tearDown(() {
    FailedImageRegistry.instance.clear();
  });

  group('Dimension 1: Cache Key Scoping & Small Thumbnail Isolation', () {
    test('1.1: cardArtKey isolates small, art_crop, and normal/large keys', () {
      const cardId = 'card-uuid-101';
      expect(
        CountrImageCacheManager.cardArtKey(cardId, version: 'normal'),
        equals('card_art_card-uuid-101'),
      );
      expect(
        CountrImageCacheManager.cardArtKey(cardId, version: 'large'),
        equals('card_art_card-uuid-101'),
      );
      expect(
        CountrImageCacheManager.cardArtKey(cardId, version: 'small'),
        equals('card_art_small_card-uuid-101'),
      );
      expect(
        CountrImageCacheManager.cardArtKey(cardId, version: 'art_crop'),
        equals('card_art_art_crop_card-uuid-101'),
      );
    });

    test('1.2: Caching small thumbnail in memory does not satisfy normal key lookups', () async {
      final manager = CountrImageCacheManager.instance;
      const cardId = 'card-iso-202';
      const smallUrl = 'https://cards.scryfall.io/small/front/a/b/ab123.jpg';
      const normalUrl = 'https://cards.scryfall.io/normal/front/a/b/ab123.jpg';

      final smallBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x01]);
      final smallFile = File('${mockCacheDir.path}/small_$cardId.jpg')..writeAsBytesSync(smallBytes);

      // Register small thumbnail
      final smallKey = CountrImageCacheManager.cardArtKey(cardId, version: 'small');
      manager.registerCardAliases(
        cacheKey: smallKey,
        cardId: cardId,
        imageUrl: smallUrl,
        version: 'small',
      );
      await manager.putFile(smallUrl, smallBytes, key: smallKey);

      // Verify normal lookup returns null (no memory hit, no alias collision)
      final normalHit = manager.getMemoryCachedFile(
        null,
        cardId: cardId,
        imageUrl: normalUrl,
        version: 'normal',
      );
      expect(normalHit, isNull, reason: 'Small thumbnail must never pollute normal card art key');

      // Verify direct normal key file lookup in cache is null
      final normalFile = await manager.getFileFromCache(CountrImageCacheManager.cardArtKey(cardId, version: 'normal'));
      expect(normalFile, isNull);

      // Verify small key file lookup succeeds
      final smallFileRetrieved = await manager.getFileFromCache(smallKey);
      expect(smallFileRetrieved, isNotNull);

      // Clean up temp file
      if (smallFile.existsSync()) smallFile.deleteSync();
    });

    test('1.3: cardNameKey isolates card names across versions', () {
      final normalNameKey = CountrImageCacheManager.cardNameKey('Ragavan, Nimble Pilferer', version: 'normal');
      final smallNameKey = CountrImageCacheManager.cardNameKey('Ragavan, Nimble Pilferer', version: 'small');
      final artCropNameKey = CountrImageCacheManager.cardNameKey('Ragavan, Nimble Pilferer', version: 'art_crop');

      expect(normalNameKey, equals('card_name_normal_ragavan, nimble pilferer'));
      expect(smallNameKey, equals('card_name_small_ragavan, nimble pilferer'));
      expect(artCropNameKey, equals('card_name_art_crop_ragavan, nimble pilferer'));
      expect(normalNameKey, isNot(equals(smallNameKey)));
      expect(normalNameKey, isNot(equals(artCropNameKey)));
    });

    test('1.4: Alias sets for small and normal keys remain strictly disjoint', () {
      final manager = CountrImageCacheManager.instance;
      const cardId = 'card-disjoint-303';
      const smallUrl = 'https://cards.scryfall.io/small/front/9/9/small.jpg';
      const normalUrl = 'https://cards.scryfall.io/normal/front/9/9/normal.jpg';

      manager.registerCardAliases(
        cacheKey: CountrImageCacheManager.cardArtKey(cardId, version: 'small'),
        imageUrl: smallUrl,
        version: 'small',
      );

      manager.registerCardAliases(
        cacheKey: CountrImageCacheManager.cardArtKey(cardId, version: 'normal'),
        imageUrl: normalUrl,
        version: 'normal',
      );

      final normalAliases = manager.resolveKeyAliases(CountrImageCacheManager.cardArtKey(cardId, version: 'normal'));
      final smallAliases = manager.resolveKeyAliases(CountrImageCacheManager.cardArtKey(cardId, version: 'small'));

      expect(normalAliases.contains(smallUrl), isFalse);
      expect(normalAliases.contains(CountrImageCacheManager.cardArtKey(cardId, version: 'small')), isFalse);
      expect(smallAliases.contains(normalUrl), isFalse);
      expect(smallAliases.contains(CountrImageCacheManager.cardArtKey(cardId, version: 'normal')), isFalse);
    });
  });

  group('Dimension 2: DFC Front vs Back Cache Key Isolation', () {
    test('2.1: cardArtKey isolates front vs back face keys', () {
      const cardId = 'dfc-card-404';
      final frontKey = CountrImageCacheManager.cardArtKey(cardId, isBack: false);
      final backKey = CountrImageCacheManager.cardArtKey(cardId, isBack: true);
      final smallFrontKey = CountrImageCacheManager.cardArtKey(cardId, version: 'small', isBack: false);
      final smallBackKey = CountrImageCacheManager.cardArtKey(cardId, version: 'small', isBack: true);

      expect(frontKey, equals('card_art_dfc-card-404'));
      expect(backKey, equals('card_art_dfc-card-404_back'));
      expect(smallFrontKey, equals('card_art_small_dfc-card-404'));
      expect(smallBackKey, equals('card_art_small_dfc-card-404_back'));
      expect(frontKey, isNot(equals(backKey)));
      expect(smallFrontKey, isNot(equals(smallBackKey)));
    });

    test('2.2: cacheKeyFor auto-infers isBack from URL paths containing /back/', () {
      const cardId = 'dfc-card-505';
      const backUrl = 'https://cards.scryfall.io/normal/back/7/2/722a12.jpg';
      const frontUrl = 'https://cards.scryfall.io/normal/front/7/2/722a12.jpg';

      final inferredBackKey = CountrImageCacheManager.cacheKeyFor(cardId: cardId, imageUrl: backUrl);
      final inferredFrontKey = CountrImageCacheManager.cacheKeyFor(cardId: cardId, imageUrl: frontUrl);

      expect(inferredBackKey, equals('card_art_dfc-card-505_back'));
      expect(inferredFrontKey, equals('card_art_dfc-card-505'));
    });

    test('2.3: Memory cache and disk cache preserve front vs back distinction', () async {
      final manager = CountrImageCacheManager.instance;
      const cardId = 'dfc-delver-606';
      const frontUrl = 'https://cards.scryfall.io/normal/front/d/e/delver_front.jpg';
      const backUrl = 'https://cards.scryfall.io/normal/back/d/e/delver_back.jpg';

      final frontBytes = Uint8List.fromList([0xAA, 0xBB, 0xCC, 0xDD]);
      final backBytes = Uint8List.fromList([0x11, 0x22, 0x33, 0x44]);

      final frontKey = CountrImageCacheManager.cardArtKey(cardId, isBack: false);
      final backKey = CountrImageCacheManager.cardArtKey(cardId, isBack: true);

      manager.registerCardAliases(
        cacheKey: frontKey,
        cardId: cardId,
        imageUrl: frontUrl,
        cardName: 'Delver of Secrets',
        isBack: false,
      );
      manager.registerCardAliases(
        cacheKey: backKey,
        cardId: cardId,
        imageUrl: backUrl,
        cardName: 'Insectile Aberration',
        isBack: true,
      );

      await manager.putFile(frontUrl, frontBytes, key: frontKey);
      await manager.putFile(backUrl, backBytes, key: backKey);

      final frontResult = await manager.getFileFromCache(frontKey);
      final backResult = await manager.getFileFromCache(backKey);

      expect(frontResult, isNotNull);
      expect(backResult, isNotNull);
      expect(await frontResult!.file.readAsBytes(), equals(frontBytes));
      expect(await backResult!.file.readAsBytes(), equals(backBytes));

      // Querying front face with isBack: true must return back or null, not frontBytes
      final memFrontQuery = manager.getMemoryCachedFile(null, cardId: cardId, isBack: false);
      final memBackQuery = manager.getMemoryCachedFile(null, cardId: cardId, isBack: true);

      expect(memFrontQuery, isNotNull);
      expect(memBackQuery, isNotNull);
      expect(memFrontQuery!.path, isNot(equals(memBackQuery!.path)));
    });

    test('2.4: evictCardArt cleanly purges both front and back faces from cache', () async {
      final manager = CountrImageCacheManager.instance;
      const cardId = 'dfc-purge-707';
      final frontKey = CountrImageCacheManager.cardArtKey(cardId, isBack: false);
      final backKey = CountrImageCacheManager.cardArtKey(cardId, isBack: true);

      final dummyBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]);
      await manager.putFile(frontKey, dummyBytes, key: frontKey);
      await manager.putFile(backKey, dummyBytes, key: backKey);

      expect(await manager.getFileFromCache(frontKey), isNotNull);
      expect(await manager.getFileFromCache(backKey), isNotNull);

      await manager.evictCardArt(cardId);

      expect(await manager.getFileFromCache(frontKey), isNull);
      expect(await manager.getFileFromCache(backKey), isNull);
    });
  });

  group('Dimension 3: inferImageVersion Robustness & Boundary Matrix', () {
    test('3.1: Standard path-based Scryfall URLs resolve exact versions', () {
      expect(
        CountrImageCacheManager.inferImageVersion('https://cards.scryfall.io/small/front/1/2/3.jpg'),
        equals('small'),
      );
      expect(
        CountrImageCacheManager.inferImageVersion('https://cards.scryfall.io/normal/front/1/2/3.jpg'),
        equals('normal'),
      );
      expect(
        CountrImageCacheManager.inferImageVersion('https://cards.scryfall.io/large/front/1/2/3.jpg'),
        equals('large'),
      );
      expect(
        CountrImageCacheManager.inferImageVersion('https://cards.scryfall.io/art_crop/front/1/2/3.jpg'),
        equals('art_crop'),
      );
    });

    test('3.2: Query-string parameterized Scryfall named URLs resolve versions', () {
      expect(
        CountrImageCacheManager.inferImageVersion(
          'https://api.scryfall.com/cards/named?exact=Black+Lotus&format=image&version=small',
        ),
        equals('small'),
      );
      expect(
        CountrImageCacheManager.inferImageVersion(
          'https://api.scryfall.com/cards/named?exact=Black+Lotus&format=image&version=normal',
        ),
        equals('normal'),
      );
      expect(
        CountrImageCacheManager.inferImageVersion(
          'https://api.scryfall.com/cards/named?exact=Black+Lotus&format=image&version=large',
        ),
        equals('large'),
      );
      expect(
        CountrImageCacheManager.inferImageVersion(
          'https://api.scryfall.com/cards/named?exact=Black+Lotus&format=image&version=art_crop',
        ),
        equals('art_crop'),
      );
    });

    test('3.3: Case insensitivity and cache-busting query suffixes', () {
      expect(
        CountrImageCacheManager.inferImageVersion('HTTPS://CARDS.SCRYFALL.IO/SMALL/FRONT/1/2/3.JPG?1674420387'),
        equals('small'),
      );
      expect(
        CountrImageCacheManager.inferImageVersion('https://cards.scryfall.io/Art_Crop/front/1/2/3.jpg?ts=999'),
        equals('art_crop'),
      );
      expect(
        CountrImageCacheManager.inferImageVersion('https://api.scryfall.com/cards/named?exact=Card&VERSION=SMALL'),
        equals('small'),
      );
    });

    test('3.4: Fallback behavior for non-standard or malformed URLs', () {
      expect(
        CountrImageCacheManager.inferImageVersion('https://images.pokemontcg.io/base1/4.png'),
        equals('normal'),
      );
      expect(
        CountrImageCacheManager.inferImageVersion('https://example.com/art.png', fallback: 'art_crop'),
        equals('art_crop'),
      );
      expect(
        CountrImageCacheManager.inferImageVersion('', fallback: 'small'),
        equals('small'),
      );
      expect(
        CountrImageCacheManager.inferImageVersion('   ', fallback: 'normal'),
        equals('normal'),
      );
    });
  });

  group('Dimension 4: CountrCachedImage Widget Invariants & Scoping', () {
    testWidgets('4.1: Computes version- and face-scoped effectiveCacheKey', (tester) async {
      const widgetNormal = CountrCachedImage(
        imageUrl: 'https://cards.scryfall.io/normal/front/1/2/3.jpg',
        cardId: 'card-calc-1',
      );
      expect(widgetNormal.effectiveCacheKey, equals('card_art_card-calc-1'));

      const widgetSmall = CountrCachedImage(
        imageUrl: 'https://cards.scryfall.io/small/front/1/2/3.jpg',
        cardId: 'card-calc-1',
      );
      expect(widgetSmall.effectiveCacheKey, equals('card_art_small_card-calc-1'));

      const widgetBackFaceExplicit = CountrCachedImage(
        imageUrl: 'https://cards.scryfall.io/normal/front/1/2/3.jpg',
        cardId: 'card-calc-1',
        isBackFace: true,
      );
      expect(widgetBackFaceExplicit.effectiveCacheKey, equals('card_art_card-calc-1_back'));

      const widgetBackFaceUrl = CountrCachedImage(
        imageUrl: 'https://cards.scryfall.io/normal/back/1/2/3.jpg',
        cardId: 'card-calc-1',
      );
      expect(widgetBackFaceUrl.effectiveCacheKey, equals('card_art_card-calc-1_back'));

      const widgetSmallBack = CountrCachedImage(
        imageUrl: 'https://cards.scryfall.io/small/back/1/2/3.jpg',
        cardId: 'card-calc-1',
      );
      expect(widgetSmallBack.effectiveCacheKey, equals('card_art_small_card-calc-1_back'));
    });

    testWidgets('4.2: Resolves Scryfall named candidate fallback when imageUrl is empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CountrCachedImage(
              imageUrl: '',
              cardName: 'Black Lotus',
              fallbackVersion: 'normal',
            ),
          ),
        ),
      );

      // In test mode, CountrCachedImage renders an Image widget using the candidate fallback URL
      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);

      final imageWidget = tester.widget<Image>(imageFinder);
      expect(imageWidget.image, isA<NetworkImage>());
      final networkImage = imageWidget.image as NetworkImage;
      expect(
        networkImage.url,
        equals('https://api.scryfall.com/cards/named?exact=Black%20Lotus&format=image&version=normal'),
      );
    });
  });

  group('Dimension 5: FullScreenCardViewer Fallback & DFC Invariants', () {
    testWidgets('5.1: Mounts CountrCachedImage when imageUrl is empty and cardName is present', (tester) async {
      final item = createChallengerVaultItem(
        id: 'fs-empty-url-1',
        name: 'Mox Sapphire',
        imageUrl: '',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: FullScreenCardViewer(
            items: [item],
            initialIndex: 0,
          ),
        ),
      );

      // Verify that FullScreenCardViewer mounts CountrCachedImage rather than static text placeholder
      expect(find.byType(CountrCachedImage), findsOneWidget);

      final cachedImage = tester.widget<CountrCachedImage>(find.byType(CountrCachedImage));
      expect(cachedImage.cardName, equals('Mox Sapphire'));
      expect(cachedImage.fallbackVersion, equals('normal'));
      expect(cachedImage.isBackFace, isFalse);
    });

    testWidgets('5.2: Gracefully renders placeholder when both imageUrl and cardName are empty', (tester) async {
      final item = createChallengerVaultItem(
        id: 'fs-blank-1',
        name: '',
        imageUrl: '',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: FullScreenCardViewer(
            items: [item],
            initialIndex: 0,
          ),
        ),
      );

      // Neither imageUrl nor effectiveName are present -> renders _buildPlaceholder
      expect(find.byType(CountrCachedImage), findsNothing);
      expect(find.byIcon(Icons.style_rounded), findsOneWidget);
    });

    testWidgets('5.3: DFC flipping toggles front vs back face isolation in FullScreenCardViewer', (tester) async {
      final dfcItem = createChallengerVaultItem(
        id: 'dfc-huntmaster-99',
        name: 'Huntmaster of the Fells // Ravager of the Fells',
        imageUrl: 'https://cards.scryfall.io/normal/front/h/u/huntmaster.jpg',
        dynamicDataMap: {
          'layout': 'transform',
          'card_faces': [
            {
              'name': 'Huntmaster of the Fells',
              'image_uris': {
                'normal': 'https://cards.scryfall.io/normal/front/h/u/huntmaster.jpg',
              },
            },
            {
              'name': 'Ravager of the Fells',
              'image_uris': {
                'normal': 'https://cards.scryfall.io/normal/back/h/u/ravager.jpg',
              },
            },
          ],
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: FullScreenCardViewer(
            items: [dfcItem],
            initialIndex: 0,
          ),
        ),
      );

      // Initial state: Front face rendered
      expect(find.textContaining('Face 1 of 2'), findsOneWidget);
      expect(find.textContaining('Huntmaster of the Fells'), findsWidgets);

      var cachedImageFinder = find.byType(CountrCachedImage);
      expect(cachedImageFinder, findsOneWidget);
      var cachedImageWidget = tester.widget<CountrCachedImage>(cachedImageFinder);
      expect(cachedImageWidget.isBackFace, isFalse);
      expect(cachedImageWidget.cardName, equals('Huntmaster of the Fells'));
      expect(cachedImageWidget.effectiveCacheKey, equals('card_art_dfc-huntmaster-99'));

      // Tap on the card artwork to flip to Face 2
      final tapTarget = find.bySemanticsLabel('Card artwork, tap to flip');
      expect(tapTarget, findsOneWidget);
      await tester.tap(tapTarget);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400)); // Complete flip animation

      // Post-flip state: Face 2 rendered
      expect(find.textContaining('Face 2 of 2'), findsOneWidget);
      expect(find.textContaining('Ravager of the Fells'), findsWidgets);

      cachedImageFinder = find.byType(CountrCachedImage);
      expect(cachedImageFinder, findsOneWidget);
      cachedImageWidget = tester.widget<CountrCachedImage>(cachedImageFinder);
      expect(cachedImageWidget.isBackFace, isTrue);
      expect(cachedImageWidget.cardName, equals('Ravager of the Fells'));
      expect(cachedImageWidget.effectiveCacheKey, equals('card_art_dfc-huntmaster-99_back'));
    });

    testWidgets('5.4: Adjacent cards in PageView use scoped Hero tags to prevent collision', (tester) async {
      final cardA = createChallengerVaultItem(id: 'hero-card-a', name: 'Card A');
      final cardB = createChallengerVaultItem(id: 'hero-card-b', name: 'Card B');

      await tester.pumpWidget(
        MaterialApp(
          home: FullScreenCardViewer(
            items: [cardA, cardB],
            initialIndex: 0,
          ),
        ),
      );

      // Hero tag for current active card
      expect(find.byWidgetPredicate((w) => w is Hero && w.tag == 'card_artwork_hero-card-a'), findsOneWidget);

      // Adjacent card Hero tag is scoped with index prefix and does NOT collide with 'card_artwork_hero-card-b'
      expect(find.byWidgetPredicate((w) => w is Hero && w.tag == 'card_artwork_hero-card-b'), findsNothing);
    });
  });

  group('Dimension 6: VaultItemCard Thumbnail Scoping', () {
    testWidgets('6.1: VaultItemCard configures leading thumbnail with small cacheKey and memCacheWidth: 120', (tester) async {
      final item = createChallengerVaultItem(
        id: 'vic-thumb-1',
        name: 'Dark Ritual',
        imageUrl: 'https://cards.scryfall.io/small/front/d/a/dark_ritual.jpg',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: VaultItemCard(
                item: item,
                isSelectionMode: false,
                isSelected: false,
              ),
            ),
          ),
        ),
      );

      final cachedImageFinder = find.descendant(
        of: find.byKey(Key('vault_card_leading_thumbnail_${item.id}')),
        matching: find.byType(CountrCachedImage),
      );
      expect(cachedImageFinder, findsOneWidget);

      final cachedImage = tester.widget<CountrCachedImage>(cachedImageFinder);
      expect(cachedImage.fallbackVersion, equals('small'));
      expect(cachedImage.cacheKey, equals('card_art_small_vic-thumb-1'));
      expect(cachedImage.memCacheWidth, equals(120));
    });
  });
}
