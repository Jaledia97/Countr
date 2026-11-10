// Copyright (c) 2026 Countr. All rights reserved.
// Challenger 2 (challenger_m1_2) Adversarial Stress Test Suite for Milestone 1 (R1).
// Challenges: Feed variants, SinglePullPostBody image rendering, PostComposerModal variant binding,
// CardDetailSheet hydration under DFC/unowned cards, Scryfall API fallback network timeouts,
// 404 responses for synthetic UUIDs, and permanent SQLite backfill.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';

import 'package:countr/core/cache/card_image_and_data_cache_resolver.dart';
import 'package:countr/core/cache/countr_cached_image.dart';
import 'package:countr/core/cache/failed_image_registry.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/hydration/data/services/scryfall_service.dart';
import 'package:countr/features/hydration/presentation/providers/hydration_providers.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';
import 'package:countr/features/feed/presentation/widgets/single_pull_post_body.dart';
import 'package:countr/features/feed/presentation/widgets/post_composer_modal.dart';
import 'package:countr/features/profile/presentation/providers/profile_providers.dart';

/// Configurable mock Scryfall service for adversarial testing (timeouts, socket errors, 404s).
class AdversarialScryfallService extends ScryfallService {
  final Map<String, Map<String, dynamic>> mockCardsById;
  final Map<String, Map<String, dynamic>> mockCardsByName;
  bool shouldTimeout = false;
  bool shouldThrowSocketException = false;
  int fetchCallCount = 0;

  AdversarialScryfallService({
    this.mockCardsById = const {},
    this.mockCardsByName = const {},
    this.shouldTimeout = false,
    this.shouldThrowSocketException = false,
  });

  @override
  Future<Map<String, dynamic>?> fetchCardDetails({
    String? scryfallId,
    String? name,
  }) async {
    fetchCallCount++;
    if (shouldTimeout) {
      throw TimeoutException('Simulated Scryfall API network timeout (15s limit reached)');
    }
    if (shouldThrowSocketException) {
      throw const SocketException('Simulated network socket exception: connection reset by peer');
    }
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
    return null; // HTTP 404 representation
  }
}

VaultItemsCompanion makeTestCardCompanion({
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
        Directory.systemTemp.createTempSync('challenger_m1_2_test_root_');
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
    FailedImageRegistry.instance.clear();
  });

  tearDown(() async {
    FailedImageRegistry.instance.clear();
    await db.close();
  });

  // =========================================================================
  // GROUP 1: CARD RESOLVER TIMEOUTS, 404s, DFC & SQLITE BACKFILL (UNIT TESTS)
  // =========================================================================
  group('Challenger 1: CardImageAndDataCacheResolver Network Fallbacks & Backfill', () {
    test('1.1: Network timeout in Step 2 is caught gracefully, returns original item', () async {
      final stubItem = VaultItem(
        id: 'stub-timeout-uuid',
        collectionType: 'mtg',
        name: 'Timeout Card',
        setOrSeries: '',
        imageUrl: '',
        acquiredPrice: 0.0,
        acquiredDate: DateTime.now(),
        quantity: 1,
        condition: 'NM',
        isGraded: false,
        isAltered: false,
        isMisprint: false,
        isSigned: false,
        isDeleted: false,
        currentMarketPrice: 0.0,
        lastPriceUpdate: DateTime.now(),
        dynamicData: '{}',
      );

      final timeoutScryfall = AdversarialScryfallService(shouldTimeout: true);
      final resolver = CardImageAndDataCacheResolver(vaultDao, timeoutScryfall);

      final result = await resolver.resolveCardDataAndImage(stubItem);

      expect(timeoutScryfall.fetchCallCount, equals(1));
      expect(result.id, equals('stub-timeout-uuid'));
      expect(result.name, equals('Timeout Card'));
    });

    test('1.2: Socket exception in Step 2 is caught gracefully, returns original item', () async {
      final stubItem = VaultItem(
        id: 'stub-socket-uuid',
        collectionType: 'mtg',
        name: 'Socket Error Card',
        setOrSeries: '',
        imageUrl: '',
        acquiredPrice: 0.0,
        acquiredDate: DateTime.now(),
        quantity: 1,
        condition: 'NM',
        isGraded: false,
        isAltered: false,
        isMisprint: false,
        isSigned: false,
        isDeleted: false,
        currentMarketPrice: 0.0,
        lastPriceUpdate: DateTime.now(),
        dynamicData: '{}',
      );

      final socketScryfall = AdversarialScryfallService(shouldThrowSocketException: true);
      final resolver = CardImageAndDataCacheResolver(vaultDao, socketScryfall);

      final result = await resolver.resolveCardDataAndImage(stubItem);

      expect(socketScryfall.fetchCallCount, equals(1));
      expect(result.id, equals('stub-socket-uuid'));
      expect(result.name, equals('Socket Error Card'));
    });

    test('1.3: HTTP 404 response on synthetic UUID returns original item without error', () async {
      const syntheticUuid = 'ffffffff-ffff-ffff-ffff-ffffffffffff';
      final stubItem = VaultItem(
        id: syntheticUuid,
        collectionType: 'mtg',
        name: 'Non Existent Card',
        setOrSeries: '',
        imageUrl: '',
        acquiredPrice: 0.0,
        acquiredDate: DateTime.now(),
        quantity: 1,
        condition: 'NM',
        isGraded: false,
        isAltered: false,
        isMisprint: false,
        isSigned: false,
        isDeleted: false,
        currentMarketPrice: 0.0,
        lastPriceUpdate: DateTime.now(),
        dynamicData: '{}',
      );

      final emptyScryfall = AdversarialScryfallService(); // returns null (404)
      final resolver = CardImageAndDataCacheResolver(vaultDao, emptyScryfall);

      final result = await resolver.resolveCardDataAndImage(stubItem);

      expect(emptyScryfall.fetchCallCount, equals(1));
      expect(result.id, equals(syntheticUuid));
    });

    test('1.4: DFC remote card payload resolves front face image and persists catalog companion', () async {
      const dfcScryfallId = 'dfc-scryfall-nicol-bolas-uuid';
      final dfcPayload = {
        'id': dfcScryfallId,
        'oracle_id': 'oracle-nicol-bolas',
        'name': 'Nicol Bolas, the Ravager // Nicol Bolas, the Arisen',
        'layout': 'transform',
        'prices': {'usd': '38.50'},
        'card_faces': [
          {
            'name': 'Nicol Bolas, the Ravager',
            'mana_cost': '{1}{U}{B}{R}',
            'type_line': 'Legendary Creature — Elder Dragon',
            'oracle_text': 'Flying\nWhen enters battlefield discard.',
            'image_uris': {
              'normal': 'https://cards.scryfall.io/normal/nicol-front.jpg',
              'large': 'https://cards.scryfall.io/large/nicol-front.jpg',
            },
          },
          {
            'name': 'Nicol Bolas, the Arisen',
            'mana_cost': '',
            'type_line': 'Legendary Planeswalker — Bolas',
            'oracle_text': '+2: Draw two cards.',
            'image_uris': {
              'normal': 'https://cards.scryfall.io/normal/nicol-back.jpg',
            },
          },
        ],
      };

      // User has a stub card in database
      await db.into(db.vaultItems).insert(makeTestCardCompanion(
            id: 'user-stub-bolas',
            name: 'Nicol Bolas, the Ravager // Nicol Bolas, the Arisen',
            quantity: 1,
            imageUrl: '',
            dynamicData: '{}',
          ));

      final stub = (await vaultDao.getItemById('user-stub-bolas'))!;

      final fakeScryfall = AdversarialScryfallService(
        mockCardsByName: {
          'Nicol Bolas, the Ravager // Nicol Bolas, the Arisen': dfcPayload,
        },
      );
      final resolver = CardImageAndDataCacheResolver(vaultDao, fakeScryfall);

      final repaired = await resolver.resolveCardDataAndImage(stub);

      // Verify front face image was extracted
      expect(repaired.imageUrl, equals('https://cards.scryfall.io/normal/nicol-front.jpg'));
      expect(repaired.currentMarketPrice, equals(38.50));

      final dynamicMap = jsonDecode(repaired.dynamicData);
      expect(dynamicMap['card_faces'], isList);
      expect((dynamicMap['card_faces'] as List).length, equals(2));

      // Verify catalog card was permanently upserted in SQLite
      final catalogRow = await vaultDao.getItemById(dfcScryfallId);
      expect(catalogRow, isNotNull);
      expect(catalogRow!.quantity, equals(0));
      expect(catalogRow.imageUrl, equals('https://cards.scryfall.io/normal/nicol-front.jpg'));
    });

    test('1.5: Permanent SQLite backfill idempotency: Step 2 network call is never repeated', () async {
      const cardScryfallId = 'permanent-backfill-sheoldred-uuid';
      final cardPayload = {
        'id': cardScryfallId,
        'name': 'Sheoldred, the Apocalypse',
        'mana_cost': '{2}{B}{B}',
        'type_line': 'Legendary Creature — Phyrexian Praetor',
        'oracle_text': 'Deathtouch\nWhenever you draw a card, you gain 2 life.',
        'prices': {'usd': '90.00'},
        'image_uris': {
          'normal': 'https://cards.scryfall.io/normal/sheoldred.jpg',
        },
      };

      // User stub in DB
      await db.into(db.vaultItems).insert(makeTestCardCompanion(
            id: 'user-sheoldred-stub-1',
            name: 'Sheoldred, the Apocalypse',
            quantity: 1,
            imageUrl: '',
            dynamicData: '{}',
          ));

      final stub1 = (await vaultDao.getItemById('user-sheoldred-stub-1'))!;
      final fakeScryfall = AdversarialScryfallService(
        mockCardsByName: {'Sheoldred, the Apocalypse': cardPayload},
      );
      final resolver = CardImageAndDataCacheResolver(vaultDao, fakeScryfall);

      // First resolution -> Triggers Step 2 (Scryfall API)
      final repaired1 = await resolver.resolveCardDataAndImage(stub1);
      expect(fakeScryfall.fetchCallCount, equals(1));
      expect(repaired1.imageUrl, equals('https://cards.scryfall.io/normal/sheoldred.jpg'));

      // Check catalog entry was permanently created in SQLite
      final catalogCard = await vaultDao.getItemById(cardScryfallId);
      expect(catalogCard, isNotNull);
      expect(catalogCard!.quantity, equals(0));

      // Second user stub for same card added later
      await db.into(db.vaultItems).insert(makeTestCardCompanion(
            id: 'user-sheoldred-stub-2',
            name: 'Sheoldred, the Apocalypse',
            quantity: 1,
            imageUrl: '',
            dynamicData: '{}',
          ));

      final stub2 = (await vaultDao.getItemById('user-sheoldred-stub-2'))!;

      // Second resolution -> Must be served entirely by Step 1 local catalog!
      final repaired2 = await resolver.resolveCardDataAndImage(stub2);
      expect(repaired2.imageUrl, equals('https://cards.scryfall.io/normal/sheoldred.jpg'));
      // Network call count must remain 1!
      expect(fakeScryfall.fetchCallCount, equals(1));
    });

    test('1.6: Pathological malformed dynamicData strings handled safely without crashing', () async {
      final pathologicalDynamicValues = [
        '{not a valid json string}',
        '[]',
        '""',
        '12345',
        'null',
        '{"oracle_text": null, "card_faces": null, "type_line": null}',
        '{"oracle_text": "   "}',
      ];

      final fakeScryfall = AdversarialScryfallService();
      final resolver = CardImageAndDataCacheResolver(vaultDao, fakeScryfall);

      for (final badDynamic in pathologicalDynamicValues) {
        final item = VaultItem(
          id: 'bad-dynamic-card-${badDynamic.hashCode}',
          collectionType: 'mtg',
          name: 'Pathological Card',
          setOrSeries: '',
          imageUrl: 'https://example.com/art.jpg',
          acquiredPrice: 0.0,
          acquiredDate: DateTime.now(),
          quantity: 1,
          condition: 'NM',
          isGraded: false,
          isAltered: false,
          isMisprint: false,
          isSigned: false,
          isDeleted: false,
          currentMarketPrice: 0.0,
          lastPriceUpdate: DateTime.now(),
          dynamicData: badDynamic,
        );

        // isCardComplete should safely return false without throwing FormatException
        final isComplete = resolver.isCardComplete(item);
        expect(isComplete, isFalse, reason: 'Failed on dynamicData: "$badDynamic"');
      }
    });
  });

  // =========================================================================
  // GROUP 2: POST COMPOSER MODAL EXACT VARIANT BINDING & NOVEL CARDS
  // =========================================================================
  group('Challenger 2: PostComposerModal Exact Variant Binding', () {
    testWidgets('2.1: Pre-bound initialCardId & initialCardImageUrl persist directly to feed_posts', (tester) async {
      const variantCardId = 'exact-variant-sheoldred-uuid';
      const variantImageUrl = 'https://cards.scryfall.io/large/front/s/h/sheoldred_showcase.jpg';

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            currentUserIdProvider.overrideWith((ref) => 'user-challenger-1'),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                floatingActionButton: FloatingActionButton(
                  onPressed: () => PostComposerModal.show(
                    context,
                    cardId: variantCardId,
                    cardImageUrl: variantImageUrl,
                    cardTitle: 'Sheoldred, the Apocalypse',
                    postType: 'single_pull',
                    estimatedValue: 95.00,
                  ),
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

      // Add commentary
      await tester.enterText(
        find.byKey(const Key('post_composer_text_input')),
        'Showcase foil pull from Collector Booster pack!',
      );

      // Publish post
      await tester.tap(find.byKey(const Key('post_composer_publish_button')));
      await tester.pumpAndSettle();

      // Query SQLite feed_posts table
      final posts = await (db.select(db.feedPosts)..where((t) => t.isDeleted.equals(false))).get();
      expect(posts.length, equals(1));

      final post = posts.first;
      expect(post.type, equals('single_pull'));
      expect(post.cardTitle, equals('Sheoldred, the Apocalypse'));
      expect(post.cardId, equals(variantCardId), reason: 'Variant cardId was overwritten or dropped');
      expect(post.cardImageUrl, equals(variantImageUrl), reason: 'Variant cardImageUrl was overwritten or dropped');
      expect(post.estimatedValue, equals(95.00));
    });

    testWidgets('2.2: Catalog card discovery binds catalog ID and imageUrl when not pre-provided', (tester) async {
      const catalogId = 'catalog-cyclonic-rift-uuid';
      const catalogImg = 'https://cards.scryfall.io/normal/cyclonic.jpg';

      // Seed catalog row (quantity = 0)
      await db.into(db.vaultItems).insert(makeTestCardCompanion(
            id: catalogId,
            name: 'Cyclonic Rift',
            quantity: 0,
            imageUrl: catalogImg,
            currentMarketPrice: 35.00,
            dynamicData: jsonEncode({'oracle_text': 'Return target nonland permanent.'}),
          ));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            currentUserIdProvider.overrideWith((ref) => 'user-challenger-2'),
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
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Switch to card pull
      await tester.tap(find.text('Card Pull / Showcase'));
      await tester.pumpAndSettle();

      // Enter card name present in catalog
      await tester.enterText(find.byKey(const Key('post_composer_card_title_input')), 'Cyclonic Rift');
      await tester.enterText(find.byKey(const Key('post_composer_text_input')), 'Look what I pulled!');
      await tester.pumpAndSettle();

      // Publish
      await tester.tap(find.byKey(const Key('post_composer_publish_button')));
      await tester.pumpAndSettle();

      final posts = await (db.select(db.feedPosts)..where((t) => t.isDeleted.equals(false))).get();
      expect(posts.length, equals(1));

      final post = posts.first;
      expect(post.cardTitle, equals('Cyclonic Rift'));
      expect(post.cardId, equals(catalogId));
      expect(post.cardImageUrl, equals(catalogImg));
    });

    testWidgets('2.3: Novel/uncataloged card synthesizes deterministic ID and Scryfall named URL', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            currentUserIdProvider.overrideWith((ref) => 'user-challenger-3'),
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
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Card Pull / Showcase'));
      await tester.pumpAndSettle();

      // Novel card with comma and space
      await tester.enterText(
          find.byKey(const Key('post_composer_card_title_input')),
          'Ragavan, Nimble Pilferer');
      await tester.enterText(
          find.byKey(const Key('post_composer_text_input')),
          'Monkey time!');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('post_composer_publish_button')));
      await tester.pumpAndSettle();

      final posts = await (db.select(db.feedPosts)..where((t) => t.isDeleted.equals(false))).get();
      expect(posts.length, equals(1));

      final post = posts.first;
      expect(post.cardTitle, equals('Ragavan, Nimble Pilferer'));
      expect(post.cardId, equals('card_ragavan__nimble_pilferer'));
      expect(
        post.cardImageUrl,
        equals(CountrCachedImage.buildScryfallNamedUrl('Ragavan, Nimble Pilferer')),
      );
    });

    testWidgets('2.4: Text post mode keeps card fields null', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            currentUserIdProvider.overrideWith((ref) => 'user-challenger-4'),
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
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Stay on text post mode
      await tester.enterText(
        find.byKey(const Key('post_composer_text_input')),
        'Just brewed a spicy 5-color deck {W}{U}{B}{R}{G}!',
      );

      await tester.tap(find.byKey(const Key('post_composer_publish_button')));
      await tester.pumpAndSettle();

      final posts = await (db.select(db.feedPosts)..where((t) => t.isDeleted.equals(false))).get();
      expect(posts.length, equals(1));

      final post = posts.first;
      expect(post.type, equals('text'));
      expect(post.textContent, contains('{W}{U}{B}{R}{G}'));
      expect(post.cardId, isNull);
      expect(post.cardTitle, isNull);
      expect(post.cardImageUrl, isNull);
      expect(post.estimatedValue, isNull);
    });

    testWidgets('2.5: Empty content and card title cleanly abort publish without insert', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            currentUserIdProvider.overrideWith((ref) => 'user-challenger-5'),
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
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Immediately tap publish without typing anything
      await tester.tap(find.byKey(const Key('post_composer_publish_button')));
      await tester.pumpAndSettle();

      final count = await (db.select(db.feedPosts)).get();
      expect(count.isEmpty, isTrue);
    });
  });

  // =========================================================================
  // GROUP 3: CARD DETAIL SHEET HYDRATION DEFECT (DFC & UNOWNED CARDS)
  // =========================================================================
  group('Challenger 3: CardDetailSheet Hydration Under DFC & Unowned Cards', () {
    testWidgets('3.1: Unowned card retains identity and metadata after _hydrateCardFromDatabase', (tester) async {
      // Seed SQLite with multiple owned cards including Sol Ring at row 1
      await db.into(db.vaultItems).insert(makeTestCardCompanion(
            id: 'owned-card-sol-ring-1',
            name: 'Sol Ring',
            quantity: 1,
            imageUrl: 'https://example.com/sol-ring.jpg',
            currentMarketPrice: 2.00,
            dynamicData: jsonEncode({
              'oracle_text': '{T}: Add {C}{C}.',
              'type_line': 'Artifact',
            }),
          ));

      await db.into(db.vaultItems).insert(makeTestCardCompanion(
            id: 'owned-card-black-lotus-2',
            name: 'Black Lotus',
            quantity: 1,
            imageUrl: 'https://example.com/lotus.jpg',
            currentMarketPrice: 25000.00,
            dynamicData: jsonEncode({
              'oracle_text': '{T}, Sacrifice Black Lotus: Add three mana of any one color.',
              'type_line': 'Artifact',
            }),
          ));

      // Pass an unowned card (Rhystic Study) not in the database
      final unownedCard = VaultItem(
        id: 'unowned-rhystic-study-print-999',
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
        currentMarketPrice: 45.00,
        lastPriceUpdate: DateTime.now(),
        dynamicData: jsonEncode({
          'oracle_text':
              'Whenever an opponent casts a spell, you may draw a card unless that player pays {1}.',
          'type_line': 'Enchantment',
          'mana_cost': '{2}{U}',
          'rarity': 'Rare',
        }),
      );

      final fakeScryfall = AdversarialScryfallService();

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
                item: unownedCard,
                cardId: 'unowned-rhystic-study-print-999',
                fetchOnlinePrintings: false,
              ),
            ),
          ),
        ),
      );

      // Run post-frame callbacks and settle
      await tester.pumpAndSettle();

      // Invariant: Must retain Rhystic Study, never swap for Sol Ring or Black Lotus
      expect(find.text('Rhystic Study'), findsWidgets);
      expect(find.text('Sol Ring'), findsNothing);
      expect(find.text('Black Lotus'), findsNothing);
      expect(
        find.text('Whenever an opponent casts a spell, you may draw a card unless that player pays {1}.'),
        findsOneWidget,
      );
    });

    testWidgets('3.2: Double-Faced Card (DFC) unowned retains card faces and toggles flip correctly', (tester) async {
      // Seed Sol Ring as row 1 in SQLite
      await db.into(db.vaultItems).insert(makeTestCardCompanion(
            id: 'sol-ring-row-1',
            name: 'Sol Ring',
            quantity: 1,
            imageUrl: 'https://example.com/sol-ring.jpg',
            currentMarketPrice: 2.00,
            dynamicData: jsonEncode({'oracle_text': '{T}: Add {C}{C}.'}),
          ));

      // Unowned DFC card
      final dfcNicolBolas = VaultItem(
        id: 'unowned-nicol-bolas-dfc-uuid',
        collectionType: 'mtg',
        name: 'Nicol Bolas, the Ravager // Nicol Bolas, the Arisen',
        setOrSeries: 'Core Set 2019',
        imageUrl: 'https://cards.scryfall.io/normal/front/n/b/nicol-bolas-front.jpg',
        acquiredPrice: 0.0,
        acquiredDate: DateTime.now(),
        quantity: 0,
        condition: 'Near Mint',
        isGraded: false,
        isAltered: false,
        isMisprint: false,
        isSigned: false,
        isDeleted: false,
        currentMarketPrice: 38.00,
        lastPriceUpdate: DateTime.now(),
        dynamicData: jsonEncode({
          'layout': 'transform',
          'card_faces': [
            {
              'name': 'Nicol Bolas, the Ravager',
              'mana_cost': '{1}{U}{B}{R}',
              'type_line': 'Legendary Creature — Elder Dragon',
              'oracle_text': 'Flying\nWhen Nicol Bolas, the Ravager enters the battlefield, each opponent discards a card.',
              'image_url': 'https://cards.scryfall.io/normal/front/n/b/nicol-bolas-front.jpg',
              'image_uris': {
                'normal': 'https://cards.scryfall.io/normal/front/n/b/nicol-bolas-front.jpg',
              },
            },
            {
              'name': 'Nicol Bolas, the Arisen',
              'mana_cost': '',
              'type_line': 'Legendary Planeswalker — Bolas',
              'oracle_text': '+2: Draw two cards.\n-3: Nicol Bolas, the Arisen deals 10 damage.',
              'image_url': 'https://cards.scryfall.io/normal/back/n/b/nicol-bolas-back.jpg',
              'image_uris': {
                'normal': 'https://cards.scryfall.io/normal/back/n/b/nicol-bolas-back.jpg',
              },
            },
          ],
        }),
      );

      final fakeScryfall = AdversarialScryfallService();

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
                item: dfcNicolBolas,
                cardId: 'unowned-nicol-bolas-dfc-uuid',
                fetchOnlinePrintings: false,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Front face renders initially (broken into paragraphs in ManaText)
      expect(find.text('Flying'), findsWidgets);
      expect(find.text('When Nicol Bolas, the Ravager enters the battlefield, each opponent discards a card.'), findsWidgets);
      expect(find.text('Sol Ring'), findsNothing);

      // Flip button must be present for DFC
      final flipFinder = find.byKey(const Key('card_detail_flip_button'));
      expect(flipFinder, findsOneWidget);

      // Tap flip button
      await tester.tap(flipFinder);
      await tester.pumpAndSettle();

      // Back face oracle text paragraphs are now displayed
      expect(find.text('+2: Draw two cards.'), findsWidgets);
      expect(find.text('-3: Nicol Bolas, the Arisen deals 10 damage.'), findsWidgets);

      // Ensure Sol Ring was still never loaded
      expect(find.text('Sol Ring'), findsNothing);
    });

    testWidgets('3.3: Swiping across list of mixed owned and unowned cards preserves card isolation', (tester) async {
      final itemOwnedSolRing = VaultItem(
        id: 'owned-sol-ring-item',
        collectionType: 'mtg',
        name: 'Sol Ring',
        setOrSeries: 'Commander',
        imageUrl: 'https://example.com/sol-ring.jpg',
        acquiredPrice: 2.00,
        acquiredDate: DateTime.now(),
        quantity: 1,
        condition: 'Near Mint',
        isGraded: false,
        isAltered: false,
        isMisprint: false,
        isSigned: false,
        isDeleted: false,
        currentMarketPrice: 2.00,
        lastPriceUpdate: DateTime.now(),
        dynamicData: jsonEncode({'oracle_text': '{T}: Add {C}{C}.'}),
      );

      final itemUnownedRhystic = VaultItem(
        id: 'unowned-rhystic-item',
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
        currentMarketPrice: 42.00,
        lastPriceUpdate: DateTime.now(),
        dynamicData: jsonEncode({'oracle_text': 'Whenever an opponent casts a spell'}),
      );

      await db.into(db.vaultItems).insert(makeTestCardCompanion(
            id: 'owned-sol-ring-item',
            name: 'Sol Ring',
            quantity: 1,
            imageUrl: 'https://example.com/sol-ring.jpg',
            currentMarketPrice: 2.00,
            dynamicData: jsonEncode({'oracle_text': '{T}: Add {C}{C}.'}),
          ));

      final fakeScryfall = AdversarialScryfallService();

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
                items: [itemOwnedSolRing, itemUnownedRhystic],
                initialIndex: 0,
                fetchOnlinePrintings: false,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Initially on Sol Ring
      expect(find.text('Sol Ring'), findsWidgets);

      // Swipe to page 1 (Rhystic Study)
      await tester.drag(find.byType(PageView), const Offset(-500, 0));
      await tester.pumpAndSettle();

      // Now on Rhystic Study: It should NOT have reverted to Sol Ring!
      expect(find.text('Rhystic Study'), findsWidgets);
      expect(find.text('Whenever an opponent casts a spell'), findsOneWidget);
    });

    testWidgets('3.4: Full card description renders immediately on frame 1 without image gating', (tester) async {
      final cardItem = VaultItem(
        id: 'decoupled-card-id',
        collectionType: 'mtg',
        name: 'Demonic Tutor',
        setOrSeries: 'Revised Edition',
        imageUrl: '', // Missing image
        acquiredPrice: 45.0,
        acquiredDate: DateTime.now(),
        quantity: 1,
        condition: 'Near Mint',
        isGraded: false,
        isAltered: false,
        isMisprint: false,
        isSigned: false,
        isDeleted: false,
        currentMarketPrice: 45.0,
        lastPriceUpdate: DateTime.now(),
        dynamicData: jsonEncode({
          'oracle_text': 'Search your library for a card, put that card into your hand, then shuffle.',
          'type_line': 'Sorcery',
          'mana_cost': '{1}{B}',
          'rarity': 'Uncommon',
        }),
      );

      final fakeScryfall = AdversarialScryfallService();

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

      // Frame 1 pump (no pumpAndSettle)
      await tester.pump();

      expect(find.text('Oracle Rules Text'), findsOneWidget);
      expect(
        find.text('Search your library for a card, put that card into your hand, then shuffle.'),
        findsOneWidget,
      );
      expect(find.text('Demonic Tutor'), findsWidgets);
    });
  });

  // =========================================================================
  // GROUP 4: FEED VARIANTS & SINGLE PULL POST BODY IMAGE RENDERING
  // =========================================================================
  group('Challenger 4: Feed Variants & SinglePullPostBody Image Rendering', () {
    testWidgets('4.1: Exact variant artwork display across diverse printing variants', (tester) async {
      final variants = [
        {
          'title': 'The One Ring (Serialized #007/100)',
          'id': 'one-ring-serialized-uuid',
          'url': 'https://cards.scryfall.io/large/front/d/5/serialized-one-ring.jpg',
          'price': '\$1,200.00',
        },
        {
          'title': 'Sheoldred, the Apocalypse (Showcase)',
          'id': 'sheoldred-showcase-uuid',
          'url': 'https://cards.scryfall.io/large/front/s/h/sheoldred-showcase.jpg',
          'price': '\$95.00',
        },
        {
          'title': 'Lightning Bolt (Retro Frame Foil)',
          'id': 'bolt-retro-uuid',
          'url': 'https://cards.scryfall.io/large/front/b/o/bolt-retro.jpg',
          'price': '\$24.00',
        },
      ];

      for (final v in variants) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: SinglePullPostBody(
                  cardTitle: v['title'],
                  cardId: v['id'],
                  imageUrl: v['url'],
                  estimatedValue: v['price'],
                  commentary: 'Testing variant ${v['title']}',
                ),
              ),
            ),
          ),
        );

        await tester.pump();

        final cachedImageFinder = find.byType(CountrCachedImage);
        expect(cachedImageFinder, findsOneWidget, reason: 'Failed mounting CountrCachedImage for ${v['title']}');

        final cachedImage = tester.widget<CountrCachedImage>(cachedImageFinder);
        expect(cachedImage.imageUrl, equals(v['url']));
        expect(cachedImage.cardId, equals(v['id']));
        expect(cachedImage.cardName, equals(v['title']));
        expect(cachedImage.fit, equals(BoxFit.cover));

        expect(find.text(v['title']!), findsOneWidget);
        expect(find.text(v['price']!), findsOneWidget);
      }
    });

    testWidgets('4.2: Fallback scan graphic renders when imageUrl and cardId are empty/null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SinglePullPostBody(
                cardTitle: 'Mysterious Unscanned Card',
                cardId: null,
                imageUrl: null,
                estimatedValue: '\$5.00',
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // CountrCachedImage should NOT be built when both imageUrl and cardId are empty/null
      expect(find.byType(CountrCachedImage), findsNothing);
      expect(find.text('VERIFIED SCAN'), findsOneWidget);
      expect(find.text('HIGH-RES RAW CARD'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('4.3: Card tap opens CardDetailSheet with fallbackItem and does NOT substitute Sol Ring', (tester) async {
      // Seed Sol Ring in the database as row 1 to challenge the old defect
      await db.into(db.vaultItems).insert(makeTestCardCompanion(
            id: 'sol-ring-first-row',
            name: 'Sol Ring',
            quantity: 1,
            imageUrl: 'https://example.com/sol-ring.jpg',
            currentMarketPrice: 2.00,
            dynamicData: jsonEncode({
              'oracle_text': '{T}: Add {C}{C}.',
              'type_line': 'Artifact',
            }),
          ));

      final fakeScryfall = AdversarialScryfallService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(vaultDao),
            scryfallServiceProvider.overrideWithValue(fakeScryfall),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: SinglePullPostBody(
                  cardTitle: 'Custom Unowned Sheoldred',
                  cardSubtitle: 'Dominaria United Showcase',
                  cardId: 'sheoldred-unowned-post-uuid',
                  imageUrl: 'https://cards.scryfall.io/large/sheoldred.jpg',
                  estimatedValue: '\$89.50',
                  commentary: 'Check out my sick pull!',
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Tap the card header area of InkWell (outside central CountrCachedImage retry zone)
      final cardFinder = find.byKey(const Key('single_pull_card_sheoldred-unowned-post-uuid'));
      await tester.tapAt(tester.getTopLeft(cardFinder) + const Offset(20, 20));
      await tester.pumpAndSettle();

      // CardDetailSheet is presented
      expect(find.byType(CardDetailSheet), findsOneWidget);

      // Crucial assertion: Must display Sheoldred and NOT Sol Ring!
      expect(find.text('Custom Unowned Sheoldred'), findsWidgets);
      expect(find.text('Sol Ring'), findsNothing);
      expect(find.text('{T}: Add {C}{C}.'), findsNothing);
    });

    testWidgets('4.4: Custom onCardTap callback intercepts tap and prevents default sheet launch', (tester) async {
      bool customTapInvoked = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SinglePullPostBody(
                cardTitle: 'Intercepted Card',
                cardId: 'intercepted-uuid',
                onCardTap: () {
                  customTapInvoked = true;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      final cardFinder = find.byKey(const Key('single_pull_card_intercepted-uuid'));
      await tester.tapAt(tester.getTopLeft(cardFinder) + const Offset(20, 20));
      await tester.pumpAndSettle();

      expect(customTapInvoked, isTrue);
      expect(find.byType(CardDetailSheet), findsNothing);
    });

    testWidgets('4.5: Pathological commentary and extreme estimated values render without overflow', (tester) async {
      final extremeValues = [
        '\$1,234,567,890.00',
        'FREE',
        'N/A',
        '',
        '-\$50.00',
        '\$0.01',
      ];

      for (final val in extremeValues) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: SinglePullPostBody(
                  cardTitle: 'Extreme Value Card',
                  estimatedValue: val.isNotEmpty ? val : null,
                  commentary: 'Pathological Mana Commentary: {W}{U}{B}{R}{G}{C}{T}{X} ' * 8,
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'Failed on value "$val"');
      }
    });
  });
}
