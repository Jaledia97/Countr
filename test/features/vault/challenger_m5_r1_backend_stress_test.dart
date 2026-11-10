import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/cache/card_image_and_data_cache_resolver.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/settings_state.dart';
import 'package:countr/features/hydration/data/services/scryfall_service.dart';
import 'package:countr/features/hydration/presentation/providers/hydration_providers.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';

class MockScryfallService extends ScryfallService {
  final Map<String, Map<String, dynamic>> cardsById;
  final Map<String, Map<String, dynamic>> cardsByName;
  int callCount = 0;

  MockScryfallService({
    this.cardsById = const {},
    this.cardsByName = const {},
  });

  @override
  Future<Map<String, dynamic>?> fetchCardDetails({
    String? scryfallId,
    String? name,
  }) async {
    callCount++;
    if (scryfallId != null && cardsById.containsKey(scryfallId)) {
      return cardsById[scryfallId];
    }
    if (name != null && cardsByName.containsKey(name)) {
      return cardsByName[name];
    }
    return null;
  }
}

VaultItem createStressCard({
  required String id,
  required String name,
  String collectionType = 'mtg',
  String setOrSeries = 'LTR',
  String imageUrl = 'https://cards.scryfall.io/normal/front/card.jpg',
  double acquiredPrice = 10.0,
  double currentMarketPrice = 20.0,
  int quantity = 1,
  String condition = 'NM',
  String dynamicData = '{}',
}) {
  final now = DateTime.now();
  return VaultItem(
    id: id,
    collectionType: collectionType,
    name: name,
    setOrSeries: setOrSeries,
    imageUrl: imageUrl,
    acquiredPrice: acquiredPrice,
    acquiredDate: now,
    quantity: quantity,
    condition: condition,
    isGraded: false,
    isAltered: false,
    isMisprint: false,
    isSigned: false,
    isDeleted: false,
    currentMarketPrice: currentMarketPrice,
    lastPriceUpdate: now,
    dynamicData: dynamicData,
  );
}

VaultItemsCompanion createStressCompanion({
  required String id,
  required String name,
  String collectionType = 'mtg',
  String setOrSeries = 'LTR',
  String imageUrl = 'https://cards.scryfall.io/normal/front/card.jpg',
  double acquiredPrice = 10.0,
  double currentMarketPrice = 20.0,
  int quantity = 1,
  String condition = 'NM',
  String dynamicData = '{}',
}) {
  final now = DateTime.now();
  return VaultItemsCompanion.insert(
    id: id,
    collectionType: collectionType,
    name: name,
    setOrSeries: setOrSeries,
    imageUrl: imageUrl,
    acquiredPrice: acquiredPrice,
    acquiredDate: now,
    quantity: drift.Value(quantity),
    condition: condition,
    currentMarketPrice: currentMarketPrice,
    lastPriceUpdate: now,
    dynamicData: dynamicData,
  );
}

void configureLargeViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget wrapWithHarness(
  Widget child, {
  required AppDatabase db,
  ScryfallService? scryfallService,
  bool isPrivacyMode = false,
  Size viewportSize = const Size(800, 2600),
}) {
  return ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      vaultDaoProvider.overrideWithValue(db.vaultDao),
      if (scryfallService != null)
        scryfallServiceProvider.overrideWithValue(scryfallService),
      privacyModeProvider.overrideWith((ref) => isPrivacyMode),
    ],
    child: MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: viewportSize),
        child: Scaffold(
          body: child,
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory mockCacheDir;
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUpAll(() {
    mockCacheDir = Directory.systemTemp.createTempSync('countr_m5_stress_root_');
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
  late VaultDao dao;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dao = db.vaultDao;
  });

  tearDown(() async {
    await db.close();
  });

  // ===========================================================================
  // Part 1: VaultDao.updateItemFinish Stress Tests
  // ===========================================================================
  group('Part 1: VaultDao.updateItemFinish Stress & Integrity Tests', () {
    test('1.1 Whitelist validation succeeds across all 6 valid finishes and normalizes whitespace/case', () async {
      const validFinishes = [
        'nonfoil',
        'foil',
        'etched',
        'surge',
        'surgefoil',
        'textured',
      ];

      for (int i = 0; i < validFinishes.length; i++) {
        final finish = validFinishes[i];
        final id = 'card-whitelist-$i';
        await db.into(db.vaultItems).insert(createStressCompanion(
              id: id,
              name: 'Whitelist Card $finish',
              dynamicData: jsonEncode({
                'finish': 'nonfoil',
                'finishes': ['nonfoil'],
                'prices': {'usd': '10.00'},
              }),
            ));

        // Test with uppercase and trailing/leading whitespace
        final inputWithNoise = '  ${finish.toUpperCase()}  ';
        await dao.updateItemFinish(id, inputWithNoise);

        final updated = await dao.getItemById(id);
        expect(updated, isNotNull);
        final data = jsonDecode(updated!.dynamicData) as Map<String, dynamic>;
        expect(data['finish'], equals(finish.toLowerCase()));
        expect(data['treatment'], equals(finish.toLowerCase()));
        final finishesList = (data['finishes'] as List).cast<String>();
        expect(finishesList.contains(finish.toLowerCase()), isTrue);
      }
    });

    test('1.2 Finish update updates currentMarketPrice in SQLite according to finish pricing in dynamicData', () async {
      const id = 'card-pricing-sync-1';
      final pricesMap = {
        'usd': '15.00',
        'usd_foil': '32.50',
        'usd_etched': '48.00',
        'usd_surge': '95.00',
      };

      await db.into(db.vaultItems).insert(createStressCompanion(
            id: id,
            name: 'The One Ring Dynamic Pricing',
            currentMarketPrice: 15.00,
            dynamicData: jsonEncode({
              'finish': 'nonfoil',
              'finishes': ['nonfoil', 'foil', 'etched', 'surge', 'surgefoil'],
              'prices': pricesMap,
            }),
          ));

      // 1. Switch to 'foil' -> price should become 32.50
      await dao.updateItemFinish(id, 'foil');
      var item = await dao.getItemById(id);
      expect(item!.currentMarketPrice, equals(32.50));

      // 2. Switch to 'etched' -> price should become 48.00
      await dao.updateItemFinish(id, 'etched');
      item = await dao.getItemById(id);
      expect(item!.currentMarketPrice, equals(48.00));

      // 3. Switch to 'surge' -> price should become 95.00 (from usd_surge)
      await dao.updateItemFinish(id, 'surge');
      item = await dao.getItemById(id);
      expect(item!.currentMarketPrice, equals(95.00));

      // 4. Switch to 'surgefoil' -> price should also map to 95.00 (from usd_surge)
      await dao.updateItemFinish(id, 'surgefoil');
      item = await dao.getItemById(id);
      expect(item!.currentMarketPrice, equals(95.00));

      // 5. Switch back to 'nonfoil' -> price should return to 15.00 (from usd)
      await dao.updateItemFinish(id, 'nonfoil');
      item = await dao.getItemById(id);
      expect(item!.currentMarketPrice, equals(15.00));

      // 6. Explicit marketPrice argument takes strict precedence over dynamicData['prices']
      await dao.updateItemFinish(id, 'foil', marketPrice: 199.99);
      item = await dao.getItemById(id);
      expect(item!.currentMarketPrice, equals(199.99));

      // 7. Explicit marketPrice for 'textured' finish
      await dao.updateItemFinish(id, 'textured', marketPrice: 350.00);
      item = await dao.getItemById(id);
      expect(item!.currentMarketPrice, equals(350.00));
      final dynamicJson = jsonDecode(item.dynamicData);
      expect(dynamicJson['finish'], equals('textured'));
    });

    test('1.3 Invalid finish values are rejected with ArgumentError without corrupting SQLite records', () async {
      const id = 'card-anti-corruption-1';
      final initialDynamic = jsonEncode({
        'finish': 'nonfoil',
        'finishes': ['nonfoil'],
        'prices': {'usd': '25.00'},
      });

      await db.into(db.vaultItems).insert(createStressCompanion(
            id: id,
            name: 'Immaculate Card',
            currentMarketPrice: 25.00,
            dynamicData: initialDynamic,
          ));

      final invalidFinishes = [
        'gold_foil',
        'masterpiece',
        'glitter',
        'serialized',
        '',
        '   ',
        'foil_etched',
        'rainbow_foil',
        'unknown',
      ];

      for (final invalid in invalidFinishes) {
        expect(
          () => dao.updateItemFinish(id, invalid),
          throwsA(isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('Invalid finish'),
          )),
        );

        // Verify SQLite record is completely untouched / uncorrupted
        final check = await dao.getItemById(id);
        expect(check, isNotNull);
        expect(check!.currentMarketPrice, equals(25.00));
        expect(check.dynamicData, equals(initialDynamic));
      }

      // Verify non-existent ID throws StateError without creating spurious records
      expect(
        () => dao.updateItemFinish('non-existent-uuid-999', 'foil'),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('not found'),
        )),
      );
    });
  });

  // ===========================================================================
  // Part 2: CardDetailSheet._hydrateCardFromDatabase Stress Tests
  // ===========================================================================
  group('Part 2: CardDetailSheet._hydrateCardFromDatabase Hydration & Swiping Tests', () {
    testWidgets('2.1 Hydration with unowned stub cards (not in DB) falls back to findCatalogCard and preserves in-memory card and price', (tester) async {
      configureLargeViewport(tester);

      // Seed catalog card in SQLite with quantity = 0
      const catalogScryfallId = 'catalog-scryfall-stub-1';
      await db.into(db.vaultItems).insert(createStressCompanion(
            id: catalogScryfallId,
            name: 'Rhystic Study',
            quantity: 0,
            setOrSeries: 'WOT',
            currentMarketPrice: 42.00,
            dynamicData: jsonEncode({
              'id': catalogScryfallId,
              'scryfall_id': catalogScryfallId,
              'oracle_id': 'oracle-rhystic-study-id',
              'set': 'wot',
              'collector_number': '0025',
              'oracle_text': 'Whenever an opponent casts a spell, you may draw a card unless that player pays {1}.',
              'type_line': 'Enchantment',
              'legalities': {'commander': 'legal', 'vintage': 'legal'},
              'prices': {'usd': '42.00', 'usd_foil': '65.00'},
              'finishes': ['nonfoil', 'foil'],
            }),
          ));

      // Create in-memory stub card that is NOT in the database
      final inMemoryStub = createStressCard(
        id: 'unowned-in-memory-stub-uuid',
        name: 'Rhystic Study',
        quantity: 0,
        setOrSeries: 'WOT',
        currentMarketPrice: 42.00,
        dynamicData: jsonEncode({
          'scryfall_id': catalogScryfallId,
          'set': 'wot',
          'collector_number': '0025',
        }),
      );

      await tester.pumpWidget(wrapWithHarness(
        CardDetailSheet(
          item: inMemoryStub,
          fetchOnlinePrintings: false,
        ),
        db: db,
      ));
      await tester.pumpAndSettle();

      // Verify the sheet mounted cleanly and hydrated from catalog fallback
      expect(find.text('Rhystic Study'), findsWidgets);
      expect(find.text('Enchantment'), findsOneWidget);
      expect(
        find.text('Whenever an opponent casts a spell, you may draw a card unless that player pays {1}.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('section_variant_price_chart')), findsOneWidget);
    });

    testWidgets('2.2 Hydration with uncataloged stub preserves in-memory card without throwing or crashing', (tester) async {
      configureLargeViewport(tester);

      // Create card completely unknown to SQLite
      final brandNewStub = createStressCard(
        id: 'stub-completely-unknown-999',
        name: 'Brand New Preview Card',
        currentMarketPrice: 88.50,
        quantity: 0,
        dynamicData: jsonEncode({
          'oracle_text': 'Flying. Lifelink. Hexproof.',
          'type_line': 'Legendary Creature — Dragon Angel',
          'set': 'dft',
          'collector_number': '0001',
          'finishes': ['nonfoil'],
          'prices': {'usd': '88.50'},
          'legalities': {'commander': 'legal'},
        }),
      );

      await tester.pumpWidget(wrapWithHarness(
        CardDetailSheet(
          item: brandNewStub,
          fetchOnlinePrintings: false,
        ),
        db: db,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Brand New Preview Card'), findsWidgets);
      expect(find.text('Legendary Creature — Dragon Angel'), findsOneWidget);
      expect(find.text('Flying. Lifelink. Hexproof.'), findsOneWidget);
      expect(find.text('\$88.50'), findsWidgets);
    });

    testWidgets('2.3 Cards with synthetic UUIDs (12a34567...) do not trigger unhandled crashes', (tester) async {
      configureLargeViewport(tester);

      final syntheticCard = createStressCard(
        id: '12a34567-e89b-12d3-a456-426614174000',
        name: 'Synthetic Test Item',
        imageUrl: 'https://cards.scryfall.io/front/12a34567_preview.jpg',
        currentMarketPrice: 12.00,
        quantity: 1,
        dynamicData: jsonEncode({
          'id': '12a34567-e89b-12d3-a456-426614174000',
          'oracle_text': 'Synthetic test oracle text.',
          'type_line': 'Artifact',
          'legalities': {'commander': 'legal'},
          'finishes': ['nonfoil'],
          'prices': {'usd': '12.00'},
        }),
      );

      // Also test a 722a3456 synthetic ID
      final syntheticCard2 = createStressCard(
        id: '722a3456-synthetic-variant-02',
        name: 'Secondary Synthetic Item',
        imageUrl: 'https://cards.scryfall.io/front/722a3456_variant.jpg',
        currentMarketPrice: 19.50,
        quantity: 1,
        dynamicData: jsonEncode({
          'oracle_text': 'Secondary test oracle text.',
          'type_line': 'Sorcery',
          'legalities': {'vintage': 'legal'},
          'finishes': ['nonfoil'],
        }),
      );

      await tester.pumpWidget(wrapWithHarness(
        CardDetailSheet(
          items: [syntheticCard, syntheticCard2],
          initialIndex: 0,
          fetchOnlinePrintings: false,
        ),
        db: db,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Synthetic Test Item'), findsWidgets);
      expect(find.text('Artifact'), findsOneWidget);

      // Fling horizontally to advance to second synthetic item
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();

      expect(find.text('Secondary Synthetic Item'), findsWidgets);
      expect(find.text('Sorcery'), findsOneWidget);
    });

    testWidgets('2.4 Carousel swiping updates active card ID properly and never falls back to arbitrary table row 0', (tester) async {
      configureLargeViewport(tester);

      // Seed 3 distinct cards into SQLite
      final cardA = createStressCard(
        id: 'db-card-row-0',
        name: 'Row 0 Card Alpha',
        currentMarketPrice: 10.00,
        dynamicData: jsonEncode({
          'set': 'one',
          'collector_number': '001',
          'oracle_text': 'Alpha oracle text.',
          'type_line': 'Creature — Elf',
          'legalities': {'commander': 'legal'},
          'finishes': ['nonfoil'],
          'prices': {'usd': '10.00'},
        }),
      );

      final cardB = createStressCard(
        id: 'db-card-row-1',
        name: 'Row 1 Card Beta',
        currentMarketPrice: 200.00,
        dynamicData: jsonEncode({
          'set': 'one',
          'collector_number': '002',
          'oracle_text': 'Beta oracle text.',
          'type_line': 'Instant',
          'legalities': {'commander': 'legal'},
          'finishes': ['nonfoil'],
          'prices': {'usd': '200.00'},
        }),
      );

      final cardC = createStressCard(
        id: 'db-card-row-2',
        name: 'Row 2 Card Gamma',
        currentMarketPrice: 50.00,
        dynamicData: jsonEncode({
          'set': 'one',
          'collector_number': '003',
          'oracle_text': 'Gamma oracle text.',
          'type_line': 'Enchantment',
          'legalities': {'commander': 'legal'},
          'finishes': ['nonfoil'],
          'prices': {'usd': '50.00'},
        }),
      );

      await db.into(db.vaultItems).insert(createStressCompanion(
            id: cardA.id,
            name: cardA.name,
            currentMarketPrice: cardA.currentMarketPrice,
            dynamicData: cardA.dynamicData,
          ));
      await db.into(db.vaultItems).insert(createStressCompanion(
            id: cardB.id,
            name: cardB.name,
            currentMarketPrice: cardB.currentMarketPrice,
            dynamicData: cardB.dynamicData,
          ));
      await db.into(db.vaultItems).insert(createStressCompanion(
            id: cardC.id,
            name: cardC.name,
            currentMarketPrice: cardC.currentMarketPrice,
            dynamicData: cardC.dynamicData,
          ));

      int? pageChangedIndex;
      await tester.pumpWidget(wrapWithHarness(
        CardDetailSheet(
          items: [cardA, cardB, cardC],
          initialIndex: 0,
          onPageChanged: (idx) => pageChangedIndex = idx,
          fetchOnlinePrintings: false,
        ),
        db: db,
      ));
      await tester.pumpAndSettle();

      // Page 0: Card Alpha active
      expect(find.text('Row 0 Card Alpha'), findsWidgets);
      expect(find.text('Creature — Elf'), findsOneWidget);

      // Swipe horizontally to Page 1: Card Beta
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();

      expect(pageChangedIndex, equals(1));
      expect(find.text('Row 1 Card Beta'), findsWidgets);
      expect(find.text('Instant'), findsOneWidget);
      expect(find.text('\$200.00'), findsWidgets);

      // Verify re-hydration does NOT fall back to arbitrary row 0
      // In CardDetailSheet, tapping treatment or calling state hydration preserves Card Beta
      await tester.tap(find.byKey(const Key('treatment_chip_nonfoil')));
      await tester.pumpAndSettle();

      expect(find.text('Row 1 Card Beta'), findsWidgets);
      expect(find.text('Instant'), findsOneWidget);
      expect(find.text('Row 0 Card Alpha'), findsNothing);

      // Swipe horizontally to Page 2: Card Gamma
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();

      expect(pageChangedIndex, equals(2));
      expect(find.text('Row 2 Card Gamma'), findsWidgets);
      expect(find.text('Enchantment'), findsOneWidget);
      expect(find.text('\$50.00'), findsWidgets);
    });
  });

  // ===========================================================================
  // Part 3: CardImageAndDataCacheResolver.isCardComplete & Catalog Fallback Tests
  // ===========================================================================
  group('Part 3: CardImageAndDataCacheResolver Completeness & Fallback Tests', () {
    late CardImageAndDataCacheResolver resolver;
    late MockScryfallService mockScryfall;

    setUp(() {
      mockScryfall = MockScryfallService();
      resolver = CardImageAndDataCacheResolver(dao, mockScryfall);
    });

    test('3.1 Complete card classification returns true', () {
      final card = createStressCard(
        id: 'complete-card-1',
        name: 'Sol Ring',
        imageUrl: 'https://cards.scryfall.io/normal/front/sol_ring.jpg',
        dynamicData: jsonEncode({
          'oracle_text': '{T}: Add {C}{C}.',
          'type_line': 'Artifact',
          'legalities': {'commander': 'legal', 'vintage': 'restricted'},
        }),
      );

      expect(resolver.isCardComplete(card), isTrue);
    });

    test('3.2 Missing oracle text (and no card faces / empty typeLine) returns false', () {
      final incomplete = createStressCard(
        id: 'missing-oracle-card',
        name: 'Stub Card',
        imageUrl: 'https://cards.scryfall.io/normal/front/stub.jpg',
        dynamicData: jsonEncode({
          'oracle_text': '',
          'type_line': '',
          'legalities': {'commander': 'legal'},
        }),
      );

      expect(resolver.isCardComplete(incomplete), isFalse);
    });

    test('3.3 Cards with synthetic UUIDs or URLs return false', () {
      // 1. Synthetic 12a34567 in image URL
      final synthetic1 = createStressCard(
        id: 'synthetic-id-1',
        name: 'Synthetic Card 1',
        imageUrl: 'https://cards.scryfall.io/front/12a34567_art.jpg',
        dynamicData: jsonEncode({
          'oracle_text': 'Valid oracle text.',
          'type_line': 'Instant',
          'legalities': {'commander': 'legal'},
        }),
      );
      expect(resolver.isCardComplete(synthetic1), isFalse);

      // 2. Synthetic 722a3456 in image URL
      final synthetic2 = createStressCard(
        id: 'synthetic-id-2',
        name: 'Synthetic Card 2',
        imageUrl: 'https://cards.scryfall.io/front/722a3456_art.jpg',
        dynamicData: jsonEncode({
          'oracle_text': 'Valid oracle text.',
          'type_line': 'Sorcery',
          'legalities': {'commander': 'legal'},
        }),
      );
      expect(resolver.isCardComplete(synthetic2), isFalse);

      // 3. Non-http image URL
      final nonHttp = createStressCard(
        id: 'non-http-card',
        name: 'Non-HTTP Card',
        imageUrl: 'file:///data/user/0/cache/image.jpg',
        dynamicData: jsonEncode({
          'oracle_text': 'Valid oracle text.',
          'type_line': 'Creature',
          'legalities': {'commander': 'legal'},
        }),
      );
      expect(resolver.isCardComplete(nonHttp), isFalse);

      // 4. Empty image URL
      final emptyImg = createStressCard(
        id: 'empty-img-card',
        name: 'Empty Image Card',
        imageUrl: '',
        dynamicData: jsonEncode({
          'oracle_text': 'Valid oracle text.',
          'type_line': 'Creature',
          'legalities': {'commander': 'legal'},
        }),
      );
      expect(resolver.isCardComplete(emptyImg), isFalse);
    });

    test('3.4 Cards missing legalities maps return false', () {
      // 1. legalities is null
      final nullLegalities = createStressCard(
        id: 'null-legalities-card',
        name: 'Null Legalities Card',
        imageUrl: 'https://cards.scryfall.io/normal/front/card.jpg',
        dynamicData: jsonEncode({
          'oracle_text': 'Valid oracle text.',
          'type_line': 'Creature',
          'legalities': null,
        }),
      );
      expect(resolver.isCardComplete(nullLegalities), isFalse);

      // 2. legalities is empty map
      final emptyLegalities = createStressCard(
        id: 'empty-legalities-card',
        name: 'Empty Legalities Card',
        imageUrl: 'https://cards.scryfall.io/normal/front/card.jpg',
        dynamicData: jsonEncode({
          'oracle_text': 'Valid oracle text.',
          'type_line': 'Creature',
          'legalities': {},
        }),
      );
      expect(resolver.isCardComplete(emptyLegalities), isFalse);

      // 3. legalities key is omitted completely
      final omittedLegalities = createStressCard(
        id: 'omitted-legalities-card',
        name: 'Omitted Legalities Card',
        imageUrl: 'https://cards.scryfall.io/normal/front/card.jpg',
        dynamicData: jsonEncode({
          'oracle_text': 'Valid oracle text.',
          'type_line': 'Creature',
        }),
      );
      expect(resolver.isCardComplete(omittedLegalities), isFalse);
    });

    test('3.5 Multi-face structures with card_faces return true even if top-level oracle_text is empty', () {
      final dfcCard = createStressCard(
        id: 'dfc-card-1',
        name: 'Nicol Bolas, the Ravager // Nicol Bolas, the Arisen',
        imageUrl: 'https://cards.scryfall.io/normal/front/nicol_bolas.jpg',
        dynamicData: jsonEncode({
          'oracle_text': '', // empty top level
          'type_line': 'Legendary Creature — Elder Dragon // Legendary Planeswalker',
          'card_faces': [
            {
              'name': 'Nicol Bolas, the Ravager',
              'oracle_text': 'Flying. When Nicol Bolas, the Ravager enters the battlefield, each opponent discards a card.',
            },
            {
              'name': 'Nicol Bolas, the Arisen',
              'oracle_text': '+2: Draw two cards.',
            },
          ],
          'legalities': {'commander': 'legal', 'modern': 'legal'},
        }),
      );

      expect(resolver.isCardComplete(dfcCard), isTrue);
    });

    test('3.6 Malformed or non-map dynamicData returns false gracefully', () {
      final malformed1 = createStressCard(
        id: 'malformed-1',
        name: 'Bad JSON Card',
        imageUrl: 'https://cards.scryfall.io/normal/front/card.jpg',
        dynamicData: 'not-valid-json-string',
      );
      expect(resolver.isCardComplete(malformed1), isFalse);

      final malformed2 = createStressCard(
        id: 'malformed-2',
        name: 'List JSON Card',
        imageUrl: 'https://cards.scryfall.io/normal/front/card.jpg',
        dynamicData: '[1, 2, 3]',
      );
      expect(resolver.isCardComplete(malformed2), isFalse);

      final malformed3 = createStressCard(
        id: 'malformed-3',
        name: 'Empty JSON Card',
        imageUrl: 'https://cards.scryfall.io/normal/front/card.jpg',
        dynamicData: '{}',
      );
      expect(resolver.isCardComplete(malformed3), isFalse);
    });

    test('3.7 Catalog repair backfills missing oracle rules and legalities without overwriting existing owned card purchase/market prices', () async {
      const ownedCardId = 'owned-rhystic-study-id';
      const catalogScryfallId = '4747ebc7-2c97-4402-9ae1-b7d15fc245d6';

      // 1. Seed catalog reference card (quantity = 0)
      await db.into(db.vaultItems).insert(createStressCompanion(
            id: catalogScryfallId,
            name: 'Rhystic Study',
            quantity: 0,
            imageUrl: 'https://cards.scryfall.io/normal/front/rhystic_study.jpg',
            acquiredPrice: 0.0,
            currentMarketPrice: 20.00, // catalog reference price
            dynamicData: jsonEncode({
              'id': catalogScryfallId,
              'scryfall_id': catalogScryfallId,
              'oracle_id': 'oracle-rhystic-study-id',
              'name': 'Rhystic Study',
              'mana_cost': '{2}{U}',
              'type_line': 'Enchantment',
              'oracle_text':
                  'Whenever an opponent casts a spell, you may draw a card unless that player pays {1}.',
              'legalities': {'commander': 'legal', 'vintage': 'legal'},
              'prices': {'usd': '20.00'},
            }),
          ));

      // 2. Seed owned collection card missing oracle text and legalities
      // Acquired by user for $45.00, current market valuation is $55.00
      await db.into(db.vaultItems).insert(createStressCompanion(
            id: ownedCardId,
            name: 'Rhystic Study',
            quantity: 1,
            acquiredPrice: 45.00,
            currentMarketPrice: 55.00,
            imageUrl: '', // missing image
            dynamicData: jsonEncode({
              'scryfall_id': catalogScryfallId,
              'oracle_id': 'oracle-rhystic-study-id',
              // missing oracle_text and legalities!
            }),
          ));

      final ownedCard = (await dao.getItemById(ownedCardId))!;
      expect(resolver.isCardComplete(ownedCard), isFalse);

      // 3. Run resolver pipeline
      final resolved = await resolver.resolveCardDataAndImage(ownedCard);

      // Verify oracle rules, typeLine, and legalities are backfilled
      expect(resolver.isCardComplete(resolved), isTrue);
      final resolvedData = jsonDecode(resolved.dynamicData) as Map<String, dynamic>;
      expect(
        resolvedData['oracle_text'],
        equals('Whenever an opponent casts a spell, you may draw a card unless that player pays {1}.'),
      );
      expect(resolvedData['legalities'], isNotNull);
      expect(resolvedData['legalities']['commander'], equals('legal'));

      // Crucially: verify user's existing acquiredPrice and currentMarketPrice were NOT overwritten!
      final inDb = (await dao.getItemById(ownedCardId))!;
      expect(inDb.acquiredPrice, equals(45.00), reason: 'Acquired price must remain unchanged');
      expect(inDb.currentMarketPrice, equals(55.00), reason: 'Owned card market price must not be overwritten by catalog 20.00');

      // 4. Test zero-price card adopts catalog market price
      const zeroPriceCardId = 'owned-zero-price-card';
      await db.into(db.vaultItems).insert(createStressCompanion(
            id: zeroPriceCardId,
            name: 'Rhystic Study',
            quantity: 1,
            acquiredPrice: 0.0,
            currentMarketPrice: 0.0,
            dynamicData: jsonEncode({
              'scryfall_id': catalogScryfallId,
            }),
          ));

      final zeroPriceCard = (await dao.getItemById(zeroPriceCardId))!;
      final resolvedZero = await resolver.resolveCardDataAndImage(zeroPriceCard);
      expect(resolvedZero.currentMarketPrice, equals(20.00), reason: 'Zero-price card should adopt catalog market price');
    });
  });
}
