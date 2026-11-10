import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/cache/card_image_and_data_cache_resolver.dart';
import 'package:countr/core/cache/countr_cached_image.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/hydration/data/services/scryfall_service.dart';
import 'package:countr/features/hydration/presentation/providers/hydration_providers.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';
import 'package:countr/features/feed/presentation/widgets/single_pull_post_body.dart';
import 'package:countr/features/feed/presentation/widgets/post_composer_modal.dart';
import 'package:countr/features/profile/presentation/providers/profile_providers.dart';

class FakeScryfallService extends ScryfallService {
  final Map<String, Map<String, dynamic>> mockCardsById;
  final Map<String, Map<String, dynamic>> mockCardsByName;
  int fetchCallCount = 0;

  FakeScryfallService({
    this.mockCardsById = const {},
    this.mockCardsByName = const {},
  });

  @override
  Future<Map<String, dynamic>?> fetchCardDetails({
    String? scryfallId,
    String? name,
  }) async {
    fetchCallCount++;
    if (scryfallId != null && mockCardsById.containsKey(scryfallId)) {
      return mockCardsById[scryfallId];
    }
    if (name != null) {
      final clean = name.contains('//')
          ? name.split('//').first.trim().toLowerCase()
          : name.trim().toLowerCase();
      for (final entry in mockCardsByName.entries) {
        if (entry.key.toLowerCase() == clean ||
            entry.key.toLowerCase() == name.trim().toLowerCase()) {
          return entry.value;
        }
      }
    }
    return null;
  }
}

VaultItemsCompanion createTestCompanion({
  required String id,
  required String name,
  String collectionType = 'mtg',
  String setOrSeries = 'PRM',
  String imageUrl = '',
  String? flavorName,
  int quantity = 1,
  double currentMarketPrice = 0.0,
  String dynamicData = '{}',
}) {
  final now = DateTime.now();
  return VaultItemsCompanion.insert(
    id: id,
    collectionType: collectionType,
    name: name,
    setOrSeries: setOrSeries,
    imageUrl: imageUrl,
    flavorName: flavorName != null
        ? drift.Value(flavorName)
        : const drift.Value.absent(),
    acquiredPrice: 0.0,
    acquiredDate: now,
    quantity: drift.Value(quantity),
    condition: 'NM',
    currentMarketPrice: currentMarketPrice,
    lastPriceUpdate: now,
    dynamicData: dynamicData,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory mockCacheDir;
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUpAll(() {
    mockCacheDir =
        Directory.systemTemp.createTempSync('countr_cache_test_root_');
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

  late AppDatabase db;
  late VaultDao vaultDao;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    vaultDao = db.vaultDao;
  });

  tearDown(() async {
    await db.close();
  });

  group('M1: Step 1 — Local Catalog Repair', () {
    test(
        'Repairs stub Rhystic Study with dynamicData: "{}" from local catalog by scryfall_id',
        () async {
      // Seed complete catalog reference card (quantity = 0)
      const catalogScryfallId = '4747ebc7-2c97-4402-9ae1-b7d15fc245d6';
      final catalogDynamic = jsonEncode({
        'id': catalogScryfallId,
        'scryfall_id': catalogScryfallId,
        'oracle_id': 'oracle-rhystic-study-id',
        'name': 'Rhystic Study',
        'mana_cost': '{2}{U}',
        'type_line': 'Enchantment',
        'oracle_text':
            'Whenever an opponent casts a spell, you may draw a card unless that player pays {1}.',
        'rarity': 'Rare',
        'layout': 'normal',
        'legalities': {'commander': 'legal', 'vintage': 'legal'},
        'prices': {'usd': '42.50'},
      });

      await db.into(db.vaultItems).insert(createTestCompanion(
            id: catalogScryfallId,
            name: 'Rhystic Study',
            quantity: 0,
            imageUrl:
                'https://cards.scryfall.io/normal/front/4/7/4747ebc7.jpg',
            currentMarketPrice: 42.50,
            dynamicData: catalogDynamic,
          ));

      // Create owned stub collection card (quantity = 1, dynamicData: '{}')
      const stubItemId = 'item-edh-rhystic-study';
      await db.into(db.vaultItems).insert(createTestCompanion(
            id: stubItemId,
            name: 'Rhystic Study',
            quantity: 1,
            imageUrl:
                'https://cards.scryfall.io/normal/front/1/2/12a34567-rhystic-study.jpg',
            currentMarketPrice: 42.50,
            dynamicData: jsonEncode({'scryfall_id': catalogScryfallId}),
          ));

      final stubItem = await vaultDao.getItemById(stubItemId);
      expect(stubItem, isNotNull);

      final fakeScryfall = FakeScryfallService();
      final resolver = CardImageAndDataCacheResolver(vaultDao, fakeScryfall);

      // Verify stub is incomplete initially
      expect(resolver.isCardComplete(stubItem!), isFalse);

      // Execute Step 1 Resolution
      final repairedItem = await resolver.resolveCardDataAndImage(stubItem);

      // Assertions
      expect(repairedItem.id, equals(stubItemId));
      expect(repairedItem.imageUrl,
          equals('https://cards.scryfall.io/normal/front/4/7/4747ebc7.jpg'));
      expect(repairedItem.currentMarketPrice, equals(42.50));

      final repairedDynamic =
          jsonDecode(repairedItem.dynamicData) as Map<String, dynamic>;
      expect(repairedDynamic['oracle_text'],
          contains('Whenever an opponent casts a spell'));
      expect(repairedDynamic['mana_cost'], equals('{2}{U}'));
      expect(repairedDynamic['type_line'], equals('Enchantment'));
      expect(repairedDynamic['legalities']?['commander'], equals('legal'));

      // Verify SQLite row was permanently updated
      final inDb = await vaultDao.getItemById(stubItemId);
      expect(inDb, isNotNull);
      expect(inDb!.dynamicData, equals(repairedItem.dynamicData));
      expect(inDb.imageUrl, equals(repairedItem.imageUrl));

      // Network was never called because Step 1 local repair succeeded
      expect(fakeScryfall.fetchCallCount, equals(0));
    });

    test(
        'Repairs stub card from local catalog by oracle_id when scryfall_id differs',
        () async {
      const oracleId = 'oracle-rhystic-study-id';
      final catalogDynamic = jsonEncode({
        'id': 'scryfall-variant-1',
        'oracle_id': oracleId,
        'name': 'Rhystic Study',
        'mana_cost': '{2}{U}',
        'type_line': 'Enchantment',
        'oracle_text':
            'Whenever an opponent casts a spell, you may draw a card unless that player pays {1}.',
      });

      await db.into(db.vaultItems).insert(createTestCompanion(
            id: 'catalog-rhystic-1',
            name: 'Rhystic Study',
            quantity: 0,
            imageUrl: 'https://cards.scryfall.io/normal/front/cat1.jpg',
            currentMarketPrice: 40.0,
            dynamicData: catalogDynamic,
          ));

      // Stub with only oracle_id in dynamic_data
      await db.into(db.vaultItems).insert(createTestCompanion(
            id: 'user-rhystic-oracle',
            name: 'Rhystic Study',
            quantity: 1,
            imageUrl: '',
            dynamicData: jsonEncode({'oracle_id': oracleId}),
          ));

      final userItem = (await vaultDao.getItemById('user-rhystic-oracle'))!;
      final fakeScryfall = FakeScryfallService();
      final resolver = CardImageAndDataCacheResolver(vaultDao, fakeScryfall);

      final repaired = await resolver.resolveCardDataAndImage(userItem);
      expect(repaired.imageUrl,
          equals('https://cards.scryfall.io/normal/front/cat1.jpg'));
      final dynamicMap = jsonDecode(repaired.dynamicData);
      expect(dynamicMap['oracle_text'],
          contains('Whenever an opponent casts a spell'));
      expect(fakeScryfall.fetchCallCount, equals(0));
    });

    test(
        'Repairs stub card by case-insensitive exact name, excluding art_series',
        () async {
      // 1. Seed non-playable Art Series card (should be skipped!)
      final artSeriesDynamic = jsonEncode({
        'id': 'art-series-rhystic',
        'name': 'Rhystic Study // Art Series',
        'layout': 'art_series',
        'oracle_text': '',
      });
      await db.into(db.vaultItems).insert(createTestCompanion(
            id: 'art-series-rhystic',
            name: 'Rhystic Study Art Card',
            quantity: 0,
            imageUrl: 'https://cards.scryfall.io/art/rhystic.jpg',
            dynamicData: artSeriesDynamic,
          ));

      // 2. Seed standard playable card (should match!)
      final playableDynamic = jsonEncode({
        'id': 'playable-rhystic-uuid',
        'name': 'Rhystic Study',
        'layout': 'normal',
        'mana_cost': '{2}{U}',
        'type_line': 'Enchantment',
        'oracle_text':
            'Whenever an opponent casts a spell, you may draw a card unless that player pays {1}.',
      });
      await db.into(db.vaultItems).insert(createTestCompanion(
            id: 'playable-rhystic-uuid',
            name: 'Rhystic Study',
            quantity: 0,
            imageUrl: 'https://cards.scryfall.io/normal/playable-rhystic.jpg',
            currentMarketPrice: 45.0,
            dynamicData: playableDynamic,
          ));

      // Stub with empty dynamicData: '{}' and no ID
      await db.into(db.vaultItems).insert(createTestCompanion(
            id: 'user-stub-no-id',
            name: 'rhystic study', // lower case
            quantity: 1,
            imageUrl: '',
            dynamicData: '{}',
          ));

      final stub = (await vaultDao.getItemById('user-stub-no-id'))!;
      final fakeScryfall = FakeScryfallService();
      final resolver = CardImageAndDataCacheResolver(vaultDao, fakeScryfall);

      final repaired = await resolver.resolveCardDataAndImage(stub);
      expect(repaired.imageUrl,
          equals('https://cards.scryfall.io/normal/playable-rhystic.jpg'));
      final data = jsonDecode(repaired.dynamicData);
      expect(data['type_line'], equals('Enchantment'));
      expect(data['layout'], equals('normal'));
      expect(fakeScryfall.fetchCallCount, equals(0));
    });
  });

  group('M1: Step 2 — On-Demand Network Hydration Fallback', () {
    test(
        'Falls back to Scryfall API when local catalog is missing, upserts catalog and backfills item',
        () async {
      // Local DB has only stub, NO catalog entries
      await db.into(db.vaultItems).insert(createTestCompanion(
            id: 'item-new-pull-cyclonic-rift',
            name: 'Cyclonic Rift',
            quantity: 1,
            imageUrl: '',
            dynamicData: '{}',
          ));

      final stub = (await vaultDao.getItemById('item-new-pull-cyclonic-rift'))!;

      final scryfallPayload = {
        'id': 'da8a108f-2926-4c2b-8149-745c674d08c7',
        'oracle_id': 'oracle-cyclonic-rift',
        'name': 'Cyclonic Rift',
        'mana_cost': '{1}{U}',
        'type_line': 'Instant',
        'oracle_text':
            'Return target nonland permanent you don\'t control to its owner\'s hand.\nOverload {6}{U}',
        'rarity': 'Rare',
        'set': 'rtr',
        'set_name': 'Return to Ravnica',
        'image_uris': {
          'normal': 'https://cards.scryfall.io/normal/cyclonic-rift.jpg',
          'large': 'https://cards.scryfall.io/large/cyclonic-rift.jpg',
        },
        'prices': {'usd': '34.50'},
        'legalities': {'commander': 'legal', 'modern': 'legal'},
      };

      final fakeScryfall = FakeScryfallService(
        mockCardsByName: {'Cyclonic Rift': scryfallPayload},
      );
      final resolver = CardImageAndDataCacheResolver(vaultDao, fakeScryfall);

      final repaired = await resolver.resolveCardDataAndImage(stub);

      // Assert Scryfall API was queried
      expect(fakeScryfall.fetchCallCount, equals(1));

      // Assert item was updated
      expect(repaired.imageUrl,
          equals('https://cards.scryfall.io/normal/cyclonic-rift.jpg'));
      expect(repaired.currentMarketPrice, equals(34.50));
      final dynamicData = jsonDecode(repaired.dynamicData);
      expect(dynamicData['type_line'], equals('Instant'));
      expect(dynamicData['oracle_text'], contains('Overload {6}{U}'));

      // Assert catalog entry (quantity = 0) was permanently upserted in SQLite
      final catalogEntry = await vaultDao
          .getItemById('da8a108f-2926-4c2b-8149-745c674d08c7');
      expect(catalogEntry, isNotNull);
      expect(catalogEntry!.quantity, equals(0));
      expect(catalogEntry.name, equals('Cyclonic Rift'));

      // Assert second call utilizes Step 1 and does NOT call network again
      final secondResolution =
          await resolver.resolveCardDataAndImage(repaired);
      expect(secondResolution, isNotNull);
      expect(fakeScryfall.fetchCallCount, equals(1)); // count did not increment
    });

    test('Gracefully handles offline failure without crashing', () async {
      await db.into(db.vaultItems).insert(createTestCompanion(
            id: 'item-offline-card',
            name: 'Unknown Offline Mystery Card',
            quantity: 1,
            imageUrl: '',
            dynamicData: '{}',
          ));

      final stub = (await vaultDao.getItemById('item-offline-card'))!;
      final fakeScryfall = FakeScryfallService(); // returns null for everything
      final resolver = CardImageAndDataCacheResolver(vaultDao, fakeScryfall);

      final result = await resolver.resolveCardDataAndImage(stub);
      expect(result.id, equals('item-offline-card'));
      expect(result.name, equals('Unknown Offline Mystery Card'));
    });

    test('resolveVariantImageUrl resolves exact printing variant artwork',
        () async {
      const variantScryfallId = 'variant-uuid-showcase-123';
      final scryfallPayload = {
        'id': variantScryfallId,
        'name': 'Sheoldred, the Apocalypse',
        'image_uris': {
          'normal': 'https://cards.scryfall.io/normal/sheoldred-showcase.jpg',
        },
      };

      final fakeScryfall = FakeScryfallService(
        mockCardsById: {variantScryfallId: scryfallPayload},
      );
      final resolver = CardImageAndDataCacheResolver(vaultDao, fakeScryfall);

      final url = await resolver.resolveVariantImageUrl(
          scryfallId: variantScryfallId);
      expect(url,
          equals('https://cards.scryfall.io/normal/sheoldred-showcase.jpg'));
    });
  });

  group('M1: Decoupled Oracle Rendering & Card Details Sheet', () {
    testWidgets(
        'CardDetailSheet renders full Oracle text immediately even when image is missing or offline',
        (tester) async {
      final cardItem = VaultItem(
        id: 'item-rhystic-decoupled',
        collectionType: 'mtg',
        name: 'Rhystic Study',
        setOrSeries: 'Prophecy',
        imageUrl: '', // NO image URL or offline
        acquiredPrice: 40.0,
        acquiredDate: DateTime.now(),
        quantity: 1,
        condition: 'Near Mint',
        isGraded: false,
        isAltered: false,
        isMisprint: false,
        isSigned: false,
        isDeleted: false,
        currentMarketPrice: 40.0,
        lastPriceUpdate: DateTime.now(),
        dynamicData: jsonEncode({
          'oracle_text':
              'Whenever an opponent casts a spell, you may draw a card unless that player pays {1}.',
          'type_line': 'Enchantment',
          'mana_cost': '{2}{U}',
          'rarity': 'Rare',
        }),
      );

      final fakeScryfall = FakeScryfallService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(vaultDao),
            scryfallServiceProvider.overrideWithValue(fakeScryfall),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: CardDetailSheet(
                item: cardItem,
                fetchOnlinePrintings: false,
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Full Oracle text and metadata render immediately on the initial frame
      expect(find.text('Oracle Rules Text'), findsOneWidget);
      expect(
          find.text(
              'Whenever an opponent casts a spell, you may draw a card unless that player pays {1}.'),
          findsOneWidget);
    });

    testWidgets(
        '_hydrateCardFromDatabase does NOT overwrite with arbitrary table row when lookup is null',
        (tester) async {
      // Seed an arbitrary card in the database (e.g. Sol Ring)
      await db.into(db.vaultItems).insert(createTestCompanion(
            id: 'first-db-card-sol-ring',
            name: 'Sol Ring',
            quantity: 1,
            imageUrl: 'https://example.com/sol-ring.jpg',
            currentMarketPrice: 2.0,
            dynamicData: jsonEncode({
              'oracle_text': '{T}: Add {C}{C}.',
              'type_line': 'Artifact',
            }),
          ));

      // Pass an unowned card (Rhystic Study) whose ID is NOT in the database
      final unownedCard = VaultItem(
        id: 'unowned-rhystic-catalog-print',
        collectionType: 'mtg',
        name: 'Rhystic Study',
        setOrSeries: 'Prophecy',
        imageUrl: 'https://example.com/rhystic.jpg',
        acquiredPrice: 0.0,
        acquiredDate: DateTime.now(),
        quantity: 0,
        condition: 'Near Mint',
        isGraded: false,
        isAltered: false,
        isMisprint: false,
        isSigned: false,
        isDeleted: false,
        currentMarketPrice: 42.50,
        lastPriceUpdate: DateTime.now(),
        dynamicData: jsonEncode({
          'oracle_text':
              'Whenever an opponent casts a spell, you may draw a card unless that player pays {1}.',
          'type_line': 'Enchantment',
        }),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(vaultDao),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: CardDetailSheet(
                item: unownedCard,
                cardId: 'unowned-rhystic-catalog-print',
                fetchOnlinePrintings: false,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Crucial test assertion: CardDetailSheet must NOT have overwritten Rhystic Study with Sol Ring!
      expect(find.text('Rhystic Study'), findsWidgets);
      expect(find.text('Sol Ring'), findsNothing);
      expect(
          find.text(
              'Whenever an opponent casts a spell, you may draw a card unless that player pays {1}.'),
          findsOneWidget);
      expect(find.text('{T}: Add {C}{C}.'), findsNothing);
    });
  });

  group('M1: Exact Variant Artwork on Feed & PostComposerModal', () {
    testWidgets(
        'SinglePullPostBody renders CountrCachedImage with exact variant artwork',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SinglePullPostBody(
                cardTitle: 'The One Ring (Serialized #007/100)',
                cardId: 'item-one-ring-serialized',
                imageUrl:
                    'https://cards.scryfall.io/large/front/d/5/d5806e68.jpg',
                estimatedValue: '\$1,200.00',
                commentary: 'Cracked the 1-of-100 serialized One Ring!',
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // CountrCachedImage is mounted with exact imageUrl and cardId
      final imageFinder = find.byType(CountrCachedImage);
      expect(imageFinder, findsOneWidget);

      final countrImage = tester.widget<CountrCachedImage>(imageFinder);
      expect(countrImage.imageUrl,
          equals('https://cards.scryfall.io/large/front/d/5/d5806e68.jpg'));
      expect(countrImage.cardId, equals('item-one-ring-serialized'));
    });

    testWidgets(
        'PostComposerModal populates exact cardId and cardImageUrl for card pulls',
        (tester) async {
      // Seed a catalog card for auto-resolution
      await db.into(db.vaultItems).insert(createTestCompanion(
            id: 'catalog-rhystic-exact-uuid',
            name: 'Rhystic Study',
            quantity: 0,
            imageUrl: 'https://cards.scryfall.io/normal/rhystic-exact.jpg',
            currentMarketPrice: 42.50,
            dynamicData: jsonEncode({
              'oracle_text':
                  'Whenever an opponent casts a spell, you may draw a card unless that player pays {1}.',
            }),
          ));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            currentUserIdProvider.overrideWith((ref) => 'test-user-1'),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                floatingActionButton: FloatingActionButton(
                  onPressed: () => PostComposerModal.show(context),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open modal
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Switch to Card Pull
      await tester.tap(find.text('Card Pull / Showcase'));
      await tester.pumpAndSettle();

      // Enter card title
      await tester.enterText(
          find.byKey(const Key('post_composer_card_title_input')),
          'Rhystic Study');
      await tester.pumpAndSettle();

      // Publish post
      await tester.tap(find.byKey(const Key('post_composer_publish_button')));
      await tester.pumpAndSettle();

      // Verify post was created in SQLite with populated cardId and cardImageUrl
      final posts = await (db.select(db.feedPosts)
            ..where((t) => t.isDeleted.equals(false)))
          .get();
      expect(posts.isNotEmpty, isTrue);

      final post = posts.first;
      expect(post.cardTitle, equals('Rhystic Study'));
      expect(post.cardId, equals('catalog-rhystic-exact-uuid'));
      expect(post.cardImageUrl,
          equals('https://cards.scryfall.io/normal/rhystic-exact.jpg'));
    });
  });
}
