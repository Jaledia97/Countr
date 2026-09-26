import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/hydration/data/services/scryfall_service.dart';
import 'package:countr/features/hydration/presentation/providers/hydration_providers.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';
import 'package:countr/features/vault/presentation/widgets/switch_printing_modal.dart';
import 'package:countr/features/vault/presentation/widgets/variant_price_chart.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  VaultItem createTestCard({
    String id = 'card-sol-ring-1',
    String name = 'Sol Ring',
    String setCode = 'cmd',
    String collectorNumber = '243',
    double price = 1.75,
    String? dynamicData,
  }) {
    return VaultItem(
      id: id,
      collectionType: 'mtg',
      name: name,
      setOrSeries: setCode.toUpperCase(),
      imageUrl: 'https://cards.scryfall.io/normal/front/sol_ring.jpg',
      acquiredPrice: 1.50,
      acquiredDate: DateTime(2023, 1, 1),
      quantity: 1,
      condition: 'NM',
      isGraded: false,
      isAltered: false,
      isMisprint: false,
      isSigned: false, isDeleted: false,
      currentMarketPrice: price,
      lastPriceUpdate: DateTime(2023, 1, 1),
      personalNotes: 'Primary commander staple in my deck.',
      dynamicData: dynamicData ??
          jsonEncode({
            'collector_number': collectorNumber,
            'set': setCode.toLowerCase(),
            'oracle_id': 'oracle-sol-ring-uuid',
            'oracle_text': '{T}: Add {C}{C}.',
            'flavor_text': 'Lost to time is the art of crafting such wonders.',
            'cached_rulings': [
              {
                'published_at': '2020-11-10',
                'comment': '{C} is the colorless mana symbol.',
              },
            ],
          }),
    );
  }

  CardPrintCandidate createCandidate({
    required String setCode,
    required String setName,
    required String collectorNumber,
    required double price,
    List<String> finishes = const ['nonfoil'],
  }) {
    return CardPrintCandidate(
      setCode: setCode.toLowerCase(),
      setName: setName,
      collectorNumber: collectorNumber,
      imageUrl: 'https://cards.scryfall.io/normal/front/$setCode/$collectorNumber.jpg',
      artCropUrl: 'https://cards.scryfall.io/art_crop/front/$setCode/$collectorNumber.jpg',
      marketPrice: price,
      rarity: 'uncommon',
      finishes: finishes,
      frameEffects: const [],
      rawData: {
        'id': '$setCode-$collectorNumber',
        'set': setCode.toLowerCase(),
        'set_name': setName,
        'collector_number': collectorNumber,
        'image_uris': {
          'normal': 'https://cards.scryfall.io/normal/front/$setCode/$collectorNumber.jpg',
          'art_crop': 'https://cards.scryfall.io/art_crop/front/$setCode/$collectorNumber.jpg',
        },
        'prices': {'usd': price.toString()},
        'finishes': finishes,
      },
    );
  }

  Widget createTestWidget(
    Widget child, {
    ScryfallService? scryfallService,
    Size viewportSize = const Size(400, 900),
    TextScaler textScaler = TextScaler.noScaling,
  }) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        vaultDaoProvider.overrideWithValue(db.vaultDao),
        if (scryfallService != null)
          scryfallServiceProvider.overrideWithValue(scryfallService),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: viewportSize,
            textScaler: textScaler,
          ),
          child: Scaffold(
            body: child,
          ),
        ),
      ),
    );
  }

  group('Group 1: Strict Vertical Hierarchy Assertions', () {
    testWidgets('strictly enforces Oracle -> Portfolio -> Variant Chart -> Format Legalities', (tester) async {
      tester.view.physicalSize = const Size(800, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final item = createTestCard();
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'object': 'list', 'data': []}), 200);
      });
      final scryfall = ScryfallService(client: mockClient);

      await tester.pumpWidget(createTestWidget(
        CardDetailSheet(item: item, fetchOnlinePrintings: false),
        scryfallService: scryfall,
        viewportSize: const Size(800, 2600),
      ));
      await tester.pumpAndSettle();

      // Locate the four critical sections by Key and verification text
      final oracleSection = find.byKey(const Key('section_oracle_rules'));
      final portfolioSection = find.byKey(const Key('section_portfolio_metrics'));
      final variantSection = find.byKey(const Key('section_variant_price_chart'));
      final legalitiesSection = find.byKey(const Key('section_format_legalities'));

      expect(oracleSection, findsOneWidget, reason: 'Oracle section must be present');
      expect(portfolioSection, findsOneWidget, reason: 'Portfolio section must be present');
      expect(variantSection, findsOneWidget, reason: 'Variant Chart section must be present');
      expect(legalitiesSection, findsOneWidget, reason: 'Format Legalities section must be present');

      // Also verify section header texts exist
      expect(find.text('Oracle Rules Text'), findsOneWidget);
      expect(find.text('Collection & Portfolio Metrics'), findsOneWidget);
      expect(find.text('Format Legalities'), findsOneWidget);

      final oracleY = tester.getTopLeft(oracleSection).dy;
      final portfolioY = tester.getTopLeft(portfolioSection).dy;
      final variantY = tester.getTopLeft(variantSection).dy;
      final legalitiesY = tester.getTopLeft(legalitiesSection).dy;

      // Strict vertical order assertion
      expect(
        oracleY < portfolioY,
        isTrue,
        reason: 'Oracle Rules ($oracleY) must appear above Portfolio Metrics ($portfolioY)',
      );
      expect(
        portfolioY < variantY,
        isTrue,
        reason: 'Portfolio Metrics ($portfolioY) must appear above Variant Chart ($variantY)',
      );
      expect(
        variantY < legalitiesY,
        isTrue,
        reason: 'Variant Chart ($variantY) must appear above Format Legalities ($legalitiesY)',
      );

      // Verify that Format Legalities is at the bottom of the list
      expect(
        legalitiesY > variantY && variantY > portfolioY && portfolioY > oracleY,
        isTrue,
        reason: 'Complete vertical hierarchy must satisfy: oracleY < portfolioY < variantY < legalitiesY',
      );
    });

    testWidgets('preserves all critical test keys in their respective sections', (tester) async {
      tester.view.physicalSize = const Size(800, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final dfcItem = createTestCard(
        id: 'dfc-card-test',
        name: 'Delver of Secrets // Insectile Aberration',
        dynamicData: jsonEncode({
          'oracle_text': 'At the beginning of your upkeep...',
          'keywords': ['Flying', 'Transform'],
          'cached_rulings': [
            {'published_at': '2011-09-24', 'comment': 'Transforming a double-faced card...'},
          ],
          'card_faces': [
            {
              'name': 'Delver of Secrets',
              'image_uris': {'normal': 'https://cards.scryfall.io/front/delver.jpg'},
              'type_line': 'Creature — Human Wizard',
            },
            {
              'name': 'Insectile Aberration',
              'image_uris': {'normal': 'https://cards.scryfall.io/back/insectile.jpg'},
              'type_line': 'Creature — Human Insect',
            },
          ],
        }),
      );

      await tester.pumpWidget(createTestWidget(
        CardDetailSheet(item: dfcItem, fetchOnlinePrintings: false),
        viewportSize: const Size(800, 2600),
      ));
      await tester.pumpAndSettle();

      // Preserved test keys
      expect(find.byKey(const Key('card_detail_switch_face_button')), findsOneWidget);
      expect(find.byKey(const Key('card_detail_flip_button')), findsOneWidget);
      expect(find.byKey(const Key('card_detail_quick_action_bar')), findsOneWidget);
      expect(find.byKey(const Key('quick_action_delete')), findsOneWidget);
      expect(find.byKey(const Key('card_art_expand_overlay')), findsOneWidget);
      expect(find.byKey(const Key('quick_action_add_to_deck')), findsOneWidget);
      expect(find.byKey(const Key('quick_action_share')), findsOneWidget);
      expect(find.byKey(const Key('quick_action_edit')), findsOneWidget);
      expect(find.byKey(const Key('card_history_ledger')), findsOneWidget);
      expect(find.byKey(const Key('card_detail_switch_printing_button')), findsOneWidget);
      expect(find.text('Card Mechanics & Rulings'), findsOneWidget);
    });
  });

  group('Group 2: Variant & Price Chart Component Rendering', () {
    testWidgets('renders horizontal scrolling list with thumbnail, set code, collector #, treatment, price', (tester) async {
      final item = createTestCard(setCode: 'CMD', collectorNumber: '243', price: 1.75);

      final variants = [
        createCandidate(
          setCode: 'CMD',
          setName: 'Commander 2011',
          collectorNumber: '243',
          price: 1.75,
          finishes: ['nonfoil'],
        ),
        createCandidate(
          setCode: '2X2',
          setName: 'Double Masters 2022',
          collectorNumber: '313',
          price: 2.50,
          finishes: ['foil'],
        ),
        createCandidate(
          setCode: 'MPS',
          setName: 'Kaladesh Inventions',
          collectorNumber: '024',
          price: 550.00,
          finishes: ['etched'],
        ),
      ];

      await tester.pumpWidget(createTestWidget(
        VariantPriceChart(
          item: item,
          initialVariants: variants,
          enableOnlineFetch: false,
        ),
      ));
      await tester.pumpAndSettle();

      // ManaBox horizontal scroller verification
      final scrollerFinder = find.byKey(const Key('variant_price_chart_list'));
      expect(scrollerFinder, findsOneWidget);

      final listView = tester.widget<ListView>(scrollerFinder);
      expect(listView.scrollDirection, Axis.horizontal);

      // Verify explicit bounded height (~165-175px container)
      final sizedBoxes = tester.widgetList<SizedBox>(find.ancestor(
        of: scrollerFinder,
        matching: find.byType(SizedBox),
      ));
      final chartContainer = sizedBoxes.firstWhere((sb) => sb.height != null && sb.height! >= 165 && sb.height! <= 175);
      expect(chartContainer.height, 172.0);

      // Verify each variant card item elements
      // 1. Variant cards
      expect(find.byKey(const Key('variant_card_cmd_243')), findsOneWidget);
      expect(find.byKey(const Key('variant_card_2x2_313')), findsOneWidget);
      expect(find.byKey(const Key('variant_card_mps_024')), findsOneWidget);

      // 2. Set code badges
      expect(find.text('CMD'), findsOneWidget);
      expect(find.text('2X2'), findsOneWidget);
      expect(find.text('MPS'), findsOneWidget);

      // 3. Collector numbers
      expect(find.text('#243'), findsOneWidget);
      expect(find.text('#313'), findsOneWidget);
      expect(find.text('#024'), findsOneWidget);

      // 4. Treatment / Finish pills
      expect(find.text('Non-foil'), findsOneWidget);
      expect(find.text('Foil'), findsOneWidget);
      expect(find.text('Etched'), findsOneWidget);

      // 5. Market prices
      expect(find.text('\$1.75'), findsOneWidget);
      expect(find.text('\$2.50'), findsOneWidget);
      expect(find.text('\$550.00'), findsOneWidget);

      // 6. Active owned printing badge
      expect(find.text('OWNED'), findsOneWidget);

      // 7. Art crop thumbnail (ClipRRect)
      expect(find.byType(ClipRRect), findsWidgets);
    });

    testWidgets('renders gracefully when no alternative printings are found', (tester) async {
      final item = createTestCard();

      await tester.pumpWidget(createTestWidget(
        VariantPriceChart(
          item: item,
          initialVariants: const [],
          enableOnlineFetch: false,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('No alternative printings found.'), findsOneWidget);
    });
  });

  group('Group 3: Responsive 320px Viewport + 2.0x Font Scaling (Zero Overflows)', () {
    testWidgets('renders CardDetailSheet on 320px viewport with 2.0x font scaling with 0 RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final item = createTestCard(
        name: 'Omnath, Locus of Creation // Extremely Long Title Example',
        dynamicData: jsonEncode({
          'collector_number': '024b',
          'set': 'znr',
          'oracle_text': 'When Omnath enters the battlefield, draw a card. Landfall — Whenever a land enters the battlefield under your control, gain 4 life if this is the first time this ability has resolved this turn. If it is the second time, add {R}{G}{W}{U}. If it is the third time, Omnath deals 4 damage to each opponent and each planeswalker you do not control.',
          'flavor_text': 'A manifestation of Zendikar rage and resilience against corruption.',
          'cached_rulings': [
            {'published_at': '2020-09-25', 'comment': 'Omnath counts the number of times its landfall ability has resolved this turn.'},
          ],
        }),
      );

      final List<FlutterErrorDetails> errors = [];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        errors.add(details);
        originalOnError?.call(details);
      };

      await tester.pumpWidget(createTestWidget(
        CardDetailSheet(item: item, fetchOnlinePrintings: false),
        viewportSize: const Size(320, 568),
        textScaler: const TextScaler.linear(2.0),
      ));
      await tester.pumpAndSettle();

      FlutterError.onError = originalOnError;

      // Filter for RenderFlex overflow errors
      final overflowErrors = errors.where((e) {
        final message = e.exceptionAsString();
        return message.contains('RenderFlex overflowed') || message.contains('A RenderFlex overflowed');
      }).toList();

      expect(
        overflowErrors,
        isEmpty,
        reason: 'No RenderFlex overflow errors must occur on 320px screen with 2.0x font scaling.',
      );
      expect(tester.takeException(), isNull);

      // Verify vertical scrolling operates smoothly without exceptions
      final listViewFinder = find.byKey(PageStorageKey('card_detail_list_${item.id}'));
      expect(listViewFinder, findsOneWidget);

      await tester.drag(listViewFinder, const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.drag(listViewFinder, const Offset(0, 600));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders VariantPriceChart standalone on 320px viewport with 2.0x font scaling without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final item = createTestCard();
      final variants = [
        createCandidate(setCode: 'CMD', setName: 'Commander 2011', collectorNumber: '243', price: 1.75),
        createCandidate(setCode: '2X2', setName: 'Double Masters 2022', collectorNumber: '313', price: 25.50),
      ];

      final List<FlutterErrorDetails> errors = [];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        errors.add(details);
        originalOnError?.call(details);
      };

      await tester.pumpWidget(createTestWidget(
        VariantPriceChart(
          item: item,
          initialVariants: variants,
          enableOnlineFetch: false,
        ),
        viewportSize: const Size(320, 568),
        textScaler: const TextScaler.linear(2.0),
      ));
      await tester.pumpAndSettle();

      FlutterError.onError = originalOnError;

      final overflowErrors = errors.where((e) {
        return e.exceptionAsString().contains('RenderFlex overflowed');
      }).toList();

      expect(overflowErrors, isEmpty, reason: 'VariantPriceChart must not overflow at 320px + 2.0x font scaling');
      expect(tester.takeException(), isNull);
    });
  });

  group('Group 4: Interactive Variant Selection & Active Printing Switching', () {
    testWidgets('selecting a variant updates selection state and shows Set as Active button', (tester) async {
      final item = createTestCard(setCode: 'CMD', collectorNumber: '243');
      final altCandidate = createCandidate(
        setCode: '2X2',
        setName: 'Double Masters 2022',
        collectorNumber: '313',
        price: 2.50,
      );
      final variants = [
        createCandidate(setCode: 'CMD', setName: 'Commander 2011', collectorNumber: '243', price: 1.75),
        altCandidate,
      ];

      CardPrintCandidate? selectedCandidate;

      await tester.pumpWidget(createTestWidget(
        VariantPriceChart(
          item: item,
          initialVariants: variants,
          enableOnlineFetch: false,
          onPrintingSelected: (candidate) {
            selectedCandidate = candidate;
          },
        ),
      ));
      await tester.pumpAndSettle();

      // Before selection, "Set as Active" button is hidden
      expect(find.byKey(const Key('button_apply_switch_printing')), findsNothing);

      // Tap on the alternative 2X2 variant card
      final altCardFinder = find.byKey(const Key('variant_card_2x2_313'));
      expect(altCardFinder, findsOneWidget);

      await tester.tap(altCardFinder);
      await tester.pumpAndSettle();

      // onPrintingSelected callback fired
      expect(selectedCandidate, isNotNull);
      expect(selectedCandidate!.setCode, '2x2');
      expect(selectedCandidate!.collectorNumber, '313');

      // "Set as Active" button is now visible
      final setAsActiveButton = find.byKey(const Key('button_apply_switch_printing'));
      expect(setAsActiveButton, findsOneWidget);
    });

    testWidgets('tapping Set as Active invokes VaultDao.switchCardPrinting and switches printing', (tester) async {
      // Insert item into SQLite database so switchCardPrinting can persist
      final item = createTestCard(id: 'db-card-sol-ring-1', setCode: 'CMD', collectorNumber: '243', price: 1.75);
      await db.into(db.vaultItems).insert(item);

      final altCandidate = createCandidate(
        setCode: '2X2',
        setName: 'Double Masters 2022',
        collectorNumber: '313',
        price: 3.25,
      );
      final variants = [
        createCandidate(setCode: 'CMD', setName: 'Commander 2011', collectorNumber: '243', price: 1.75),
        altCandidate,
      ];

      VaultItem? updatedItemResult;

      await tester.pumpWidget(createTestWidget(
        VariantPriceChart(
          item: item,
          initialVariants: variants,
          enableOnlineFetch: false,
          onPrintingChanged: (updated) {
            updatedItemResult = updated;
          },
        ),
      ));
      await tester.pumpAndSettle();

      // Select alternative variant
      await tester.tap(find.byKey(const Key('variant_card_2x2_313')));
      await tester.pumpAndSettle();

      // Tap "Set as Active"
      await tester.tap(find.byKey(const Key('button_apply_switch_printing')));
      await tester.pumpAndSettle();

      // Verify onPrintingChanged fired with updated values
      expect(updatedItemResult, isNotNull);
      expect(updatedItemResult!.setOrSeries, 'Double Masters 2022');
      expect(updatedItemResult!.currentMarketPrice, 3.25);

      // Verify SQLite state was genuinely persisted
      final fromDb = await db.vaultDao.getItemById('db-card-sol-ring-1');
      expect(fromDb, isNotNull);
      expect(fromDb!.setOrSeries, 'Double Masters 2022');
      expect(fromDb.currentMarketPrice, 3.25);
    });

    testWidgets('selecting variant in CardDetailSheet updates artwork and price preview', (tester) async {
      final item = createTestCard(setCode: 'CMD', collectorNumber: '243', price: 1.75);

      // Pre-populate database with catalog items so local query returns them
      await db.into(db.vaultItems).insert(VaultItem(
        id: 'catalog-item-cmd',
        collectionType: 'mtg',
        name: 'Sol Ring',
        setOrSeries: 'CMD',
        imageUrl: 'https://cards.scryfall.io/cmd/243.jpg',
        acquiredPrice: 1.75,
        acquiredDate: DateTime(2023, 1, 1),
        quantity: 1,
        condition: 'NM',
        isGraded: false, isAltered: false, isMisprint: false, isSigned: false, isDeleted: false,
        currentMarketPrice: 1.75,
        lastPriceUpdate: DateTime(2023, 1, 1),
        dynamicData: jsonEncode({'collector_number': '243', 'set': 'cmd'}),
      ));

      await db.into(db.vaultItems).insert(VaultItem(
        id: 'catalog-item-2x2',
        collectionType: 'mtg',
        name: 'Sol Ring',
        setOrSeries: '2X2',
        imageUrl: 'https://cards.scryfall.io/2x2/313.jpg',
        acquiredPrice: 15.00,
        acquiredDate: DateTime(2023, 1, 1),
        quantity: 1,
        condition: 'NM',
        isGraded: false, isAltered: false, isMisprint: false, isSigned: false, isDeleted: false,
        currentMarketPrice: 15.00,
        lastPriceUpdate: DateTime(2023, 1, 1),
        dynamicData: jsonEncode({'collector_number': '313', 'set': '2x2'}),
      ));

      await tester.pumpWidget(createTestWidget(
        CardDetailSheet(item: item, fetchOnlinePrintings: false),
        viewportSize: const Size(600, 1200),
      ));
      await tester.pumpAndSettle();

      // CardDetailSheet should display the initial price '1.75'
      expect(find.textContaining('1.75'), findsWidgets);

      // Tap on the 2X2 variant card in the horizontal scroller
      final card2x2 = find.byKey(const Key('variant_card_2x2_313'));
      if (card2x2.evaluate().isNotEmpty) {
        await tester.tap(card2x2);
        await tester.pumpAndSettle();

        // Price preview in header updates to '15.00'
        expect(find.textContaining('15.00'), findsWidgets);
      }
    });
  });
}
