import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/settings_state.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';
import 'package:countr/features/vault/presentation/widgets/versions_printings_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  VaultItem createCard({
    String id = 'owned-card-1',
    String name = 'The One Ring',
    String setCode = 'LTR',
    String collectorNumber = '0269',
    double price = 65.00,
    int quantity = 1,
    List<String> finishes = const ['nonfoil', 'foil', 'etched', 'surgefoil', 'textured'],
    Map<String, dynamic>? pricesMap,
  }) {
    return VaultItem(
      id: id,
      collectionType: 'mtg',
      name: name,
      setOrSeries: setCode.toUpperCase(),
      imageUrl: 'https://cards.scryfall.io/normal/front/the_one_ring.jpg',
      acquiredPrice: price,
      acquiredDate: DateTime(2023, 1, 1),
      quantity: quantity,
      condition: 'NM',
      isGraded: false,
      isAltered: false,
      isMisprint: false,
      isSigned: false,
      isDeleted: false,
      currentMarketPrice: price,
      lastPriceUpdate: DateTime(2023, 1, 1),
      dynamicData: jsonEncode({
        'collector_number': collectorNumber,
        'set': setCode.toLowerCase(),
        'oracle_text': 'Indestructible. Protection from everything.',
        'finishes': finishes,
        'prices': pricesMap ?? {
          'usd': '65.00',
          'usd_foil': '95.00',
          'usd_etched': '120.00',
          'usd_surge': '250.00',
          'usd_textured': '350.00',
        },
        'finish': 'nonfoil',
        'treatment': 'Non-Foil',
      }),
    );
  }

  void configureLargeViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget createHarness(
    Widget child, {
    bool isPrivacyMode = false,
    Size viewportSize = const Size(800, 2600),
    TextScaler textScaler = TextScaler.noScaling,
  }) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        vaultDaoProvider.overrideWithValue(db.vaultDao),
        privacyModeProvider.overrideWith((ref) => isPrivacyMode),
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

  group('Feature 25: Inline Treatments & 1-Tap Finish Update', () {
    testWidgets('Renders Treatments section wrapped in Key("section_variant_price_chart") with finish chips and prices', (tester) async {
      configureLargeViewport(tester);
      final card = createCard();
      await db.into(db.vaultItems).insert(card);

      await tester.pumpWidget(
        createHarness(
          CardDetailSheet(item: card, fetchOnlinePrintings: false),
        ),
      );
      await tester.pumpAndSettle();

      // Treatments container key
      expect(find.byKey(const Key('section_variant_price_chart')), findsOneWidget);
      expect(find.text('Treatments'), findsOneWidget);

      // Finish chips rendered
      expect(find.byKey(const Key('treatment_chip_nonfoil')), findsOneWidget);
      expect(find.byKey(const Key('treatment_chip_foil')), findsOneWidget);
      expect(find.byKey(const Key('treatment_chip_etched')), findsOneWidget);
      expect(find.byKey(const Key('treatment_chip_surge')), findsOneWidget);
      expect(find.byKey(const Key('treatment_chip_textured')), findsOneWidget);

      // Prices rendered
      expect(find.text('\$65.00'), findsWidgets);
      expect(find.text('\$95.00'), findsOneWidget);
      expect(find.text('\$120.00'), findsOneWidget);
      expect(find.text('\$250.00'), findsOneWidget);
      expect(find.text('\$350.00'), findsOneWidget);
    });

    testWidgets('Privacy Mode masks finish prices with ****', (tester) async {
      configureLargeViewport(tester);
      final card = createCard();
      await db.into(db.vaultItems).insert(card);

      await tester.pumpWidget(
        createHarness(
          CardDetailSheet(item: card, fetchOnlinePrintings: false),
          isPrivacyMode: true,
        ),
      );
      await tester.pumpAndSettle();

      // Unmasked prices should not be found
      expect(find.text('\$95.00'), findsNothing);
      expect(find.text('\$120.00'), findsNothing);

      // **** should be found on all treatment chips
      expect(find.text('****'), findsWidgets);
    });

    testWidgets('1-Tap finish update for owned card updates SQLite, market price, and shows SnackBar', (tester) async {
      configureLargeViewport(tester);
      final card = createCard();
      await db.into(db.vaultItems).insert(card);

      await tester.pumpWidget(
        createHarness(
          CardDetailSheet(item: card, fetchOnlinePrintings: false),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Traditional Foil chip ($95.00)
      await tester.tap(find.byKey(const Key('treatment_chip_foil')));
      await tester.pumpAndSettle();

      // Verify SnackBar displayed
      expect(find.text('Finish updated to Traditional Foil!'), findsOneWidget);

      // Verify SQLite state persisted
      final inDb = await db.vaultDao.getItemById(card.id);
      expect(inDb, isNotNull);
      expect(inDb!.currentMarketPrice, equals(95.00));
      final dynamicMap = jsonDecode(inDb.dynamicData);
      expect(dynamicMap['finish'], equals('foil'));
      expect(dynamicMap['treatment'], equals('Traditional Foil'));
    });

    testWidgets('1-Tap finish update for unowned card optimistically updates local preview without SQLite error', (tester) async {
      configureLargeViewport(tester);
      final unowned = createCard(id: 'unowned-ring', quantity: 0);

      await tester.pumpWidget(
        createHarness(
          CardDetailSheet(item: unowned, fetchOnlinePrintings: false),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Etched Foil chip ($120.00)
      await tester.tap(find.byKey(const Key('treatment_chip_etched')));
      await tester.pumpAndSettle();

      // Verify no exception was thrown
      expect(tester.takeException(), isNull);
    });
  });

  group('Feature 26 & 27: Lazy-Loaded [See More] Modal & Upper-Left Back Button', () {
    testWidgets('[See More Versions & Printings] button is rendered beneath Treatments', (tester) async {
      configureLargeViewport(tester);
      final card = createCard();
      await db.into(db.vaultItems).insert(card);

      await tester.pumpWidget(
        createHarness(
          CardDetailSheet(item: card, fetchOnlinePrintings: false),
        ),
      );
      await tester.pumpAndSettle();

      final seeMoreButton = find.byKey(const Key('card_detail_see_more_versions_button'));
      expect(seeMoreButton, findsOneWidget);
      expect(find.text('See More Versions & Printings'), findsOneWidget);

      // Verify it is positioned inside/beneath the treatments section
      final treatmentsTop = tester.getTopLeft(find.byKey(const Key('section_variant_price_chart'))).dy;
      final buttonTop = tester.getTopLeft(seeMoreButton).dy;
      expect(buttonTop > treatmentsTop, isTrue);
    });

    testWidgets('Tapping [See More] opens lazy-loaded modal with Versions & Printings tabs and upper-left Back button', (tester) async {
      configureLargeViewport(tester);
      final card = createCard();
      await db.into(db.vaultItems).insert(card);

      // Seed alternative printings in catalog
      final alt1 = VaultItem(
        id: 'alt-ring-borderless',
        collectionType: 'mtg',
        name: 'The One Ring',
        setOrSeries: 'LTR',
        imageUrl: 'https://cards.scryfall.io/borderless.jpg',
        acquiredPrice: 150.0,
        acquiredDate: DateTime(2023, 1, 1),
        quantity: 0,
        condition: 'NM',
        isGraded: false,
        isAltered: false,
        isMisprint: false,
        isSigned: false,
        isDeleted: false,
        currentMarketPrice: 150.0,
        lastPriceUpdate: DateTime(2023, 1, 1),
        dynamicData: jsonEncode({
          'set': 'ltr',
          'set_name': 'The Lord of the Rings',
          'collector_number': '0451',
          'border_color': 'borderless',
          'frame_effects': ['showcase'],
          'finishes': ['foil'],
          'prices': {'usd': '150.00'},
        }),
      );
      await db.into(db.vaultItems).insert(alt1);

      await tester.pumpWidget(
        createHarness(
          CardDetailSheet(item: card, fetchOnlinePrintings: false),
        ),
      );
      await tester.pumpAndSettle();

      // Before tapping See More, VersionsAndPrintingsModal is NOT in tree
      expect(find.byType(VersionsAndPrintingsModal), findsNothing);

      // Tap [See More Versions & Printings]
      await tester.tap(find.byKey(const Key('card_detail_see_more_versions_button')));
      await tester.pumpAndSettle();

      // Modal is now open
      expect(find.byType(VersionsAndPrintingsModal), findsOneWidget);
      expect(find.text('Versions'), findsOneWidget);
      expect(find.text('Printings'), findsOneWidget);

      // Upper-left Back Button (Feature 27) exists in the modal header
      final backButton = find.byKey(const Key('versions_printings_back_button'));
      expect(backButton, findsOneWidget);

      // Switch to Printings tab
      await tester.tap(find.text('Printings'));
      await tester.pumpAndSettle();

      // Verify set badge and details rendered
      expect(find.text('LTR'), findsWidgets);

      // Tap upper-left Back Button: cleanly dismisses modal returning to CardDetailSheet
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // Modal dismissed
      expect(find.byType(VersionsAndPrintingsModal), findsNothing);

      // CardDetailSheet is still open and visible!
      expect(find.byType(CardDetailSheet), findsOneWidget);
      expect(find.byKey(const Key('card_detail_see_more_versions_button')), findsOneWidget);
    });

    testWidgets('Zero RenderFlex overflow on 320px viewport with 2.0x font scaling', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final card = createCard();
      await db.into(db.vaultItems).insert(card);

      await tester.pumpWidget(
        createHarness(
          CardDetailSheet(item: card, fetchOnlinePrintings: false),
          viewportSize: const Size(320, 800),
          textScaler: const TextScaler.linear(2.0),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
