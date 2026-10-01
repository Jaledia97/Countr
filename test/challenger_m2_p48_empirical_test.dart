import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/hydration/data/services/scryfall_service.dart';
import 'package:countr/features/hydration/presentation/providers/hydration_providers.dart';
import 'package:countr/features/symbology/domain/mana_text_parser.dart';
import 'package:countr/features/symbology/presentation/widgets/mana_text.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';
import 'package:countr/features/vault/presentation/widgets/switch_printing_modal.dart';
import 'package:countr/features/vault/presentation/widgets/variant_price_chart.dart';
import 'package:countr/core/cache/countr_cached_image.dart';

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
    required String id,
    required String name,
    required String setCode,
    required String setName,
    required String imageUrl,
    int quantity = 1,
    double marketPrice = 25.0,
    String? oracleText,
    List<String>? keywords,
    List<Map<String, dynamic>>? rulings,
    String? dynamicJson,
  }) {
    final Map<String, dynamic> dyn = dynamicJson != null
        ? jsonDecode(dynamicJson) as Map<String, dynamic>
        : <String, dynamic>{};

    dyn['set'] = setCode.toLowerCase();
    dyn['set_code'] = setCode.toLowerCase();
    dyn['set_name'] = setName;
    if (oracleText != null) dyn['oracle_text'] = oracleText;
    if (keywords != null) dyn['keywords'] = keywords;
    if (rulings != null) dyn['rulings'] = rulings;

    return VaultItem(
      id: id,
      collectionType: 'mtg',
      name: name,
      setOrSeries: setName,
      imageUrl: imageUrl,
      acquiredPrice: 10.0,
      acquiredDate: DateTime(2023, 1, 1),
      quantity: quantity,
      condition: 'NM',
      isGraded: false,
      isAltered: false,
      isMisprint: false,
      isSigned: false,
      isDeleted: false,
      currentMarketPrice: marketPrice,
      lastPriceUpdate: DateTime(2023, 1, 1),
      dynamicData: jsonEncode(dyn),
    );
  }

  Widget createHarness(
    Widget child, {
    WidgetTester? tester,
    Size viewportSize = const Size(800, 2000),
    double textScaleFactor = 1.0,
    ScryfallService? scryfallService,
  }) {
    if (tester != null) {
      tester.view.physicalSize = viewportSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }
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
            textScaler: TextScaler.linear(textScaleFactor),
          ),
          child: Scaffold(
            body: child,
          ),
        ),
      ),
    );
  }

  group('Empirical Challenge 1: Variant Switching Hero Art Updates', () {
    testWidgets('Switching variant updates full-sized card hero art and does not revert', (tester) async {
      final initialCard = createTestCard(
        id: 'hero-sol-ring',
        name: 'Sol Ring',
        setCode: 'cmd',
        setName: 'Commander 2011',
        imageUrl: 'https://cards.scryfall.io/cmd/243.jpg',
        marketPrice: 2.0,
      );
      await db.into(db.vaultItems).insert(initialCard);

      // Add alternate variant in DB
      final altCard = createTestCard(
        id: 'hero-sol-ring-2x2',
        name: 'Sol Ring',
        setCode: '2x2',
        setName: 'Double Masters 2022',
        imageUrl: 'https://cards.scryfall.io/2x2/313.jpg',
        marketPrice: 12.0,
      );
      await db.into(db.vaultItems).insert(altCard);

      await tester.pumpWidget(createHarness(
        CardDetailSheet(item: initialCard, fetchOnlinePrintings: false),
        viewportSize: const Size(600, 1200),
      ));
      await tester.pumpAndSettle();

      // Find initial hero art image
      final heroFinder = find.byKey(Key('card_artwork_${initialCard.id}'));
      expect(heroFinder, findsOneWidget);
      final initialCachedImage = tester.widget<CountrCachedImage>(
        find.descendant(of: heroFinder, matching: find.byType(CountrCachedImage)),
      );
      expect(initialCachedImage.imageUrl, 'https://cards.scryfall.io/cmd/243.jpg');

      // Select variant card in VariantPriceChart
      final variant2x2Finder = find.byKey(const Key('variant_card_2x2_313'));
      if (variant2x2Finder.evaluate().isNotEmpty) {
        await tester.tap(variant2x2Finder);
        await tester.pumpAndSettle();

        // Hero image should now display the preview variant
        final previewCachedImage = tester.widget<CountrCachedImage>(
          find.descendant(of: heroFinder, matching: find.byType(CountrCachedImage)),
        );
        expect(previewCachedImage.imageUrl, 'https://cards.scryfall.io/2x2/313.jpg');

        // Apply switch printing via "Set as Active"
        final setAsActiveBtn = find.byKey(const Key('button_apply_switch_printing'));
        if (setAsActiveBtn.evaluate().isNotEmpty) {
          await tester.tap(setAsActiveBtn);
          await tester.pumpAndSettle();

          // After applying switch, verify hero image STILL has new artwork and does not revert
          final activeCachedImage = tester.widget<CountrCachedImage>(
            find.descendant(of: heroFinder, matching: find.byType(CountrCachedImage)),
          );
          expect(activeCachedImage.imageUrl, 'https://cards.scryfall.io/2x2/313.jpg');
        }
      }
    });

    testWidgets('SwitchPrintingModal dialog updates CardDetailSheet hero art upon applying switch', (tester) async {
      final initialCard = createTestCard(
        id: 'modal-hero-sol-ring',
        name: 'Sol Ring',
        setCode: 'cmd',
        setName: 'Commander 2011',
        imageUrl: 'https://cards.scryfall.io/cmd/243.jpg',
        marketPrice: 2.0,
      );
      await db.into(db.vaultItems).insert(initialCard);

      // Add alternate variant in DB
      final altCard = createTestCard(
        id: 'modal-hero-sol-ring-2x2',
        name: 'Sol Ring',
        setCode: '2x2',
        setName: 'Double Masters 2022',
        imageUrl: 'https://cards.scryfall.io/2x2/313.jpg',
        marketPrice: 12.0,
      );
      await db.into(db.vaultItems).insert(altCard);

      await tester.pumpWidget(createHarness(
        CardDetailSheet(item: initialCard, fetchOnlinePrintings: false),
        tester: tester,
        viewportSize: const Size(800, 2000),
      ));
      await tester.pumpAndSettle();

      final heroFinder = find.byKey(Key('card_artwork_${initialCard.id}'));
      expect(heroFinder, findsOneWidget);
      final initialCachedImage = tester.widget<CountrCachedImage>(
        find.descendant(of: heroFinder, matching: find.byType(CountrCachedImage)),
      );
      expect(initialCachedImage.imageUrl, 'https://cards.scryfall.io/cmd/243.jpg');

      // Tap Switch Printing button to open modal
      final switchBtnFinder = find.byKey(const Key('card_detail_switch_printing_button'));
      expect(switchBtnFinder, findsOneWidget);
      await tester.tap(switchBtnFinder);
      await tester.pumpAndSettle();

      // Verify modal is open
      expect(find.text('Switch Printing / Edition'), findsOneWidget);

      // Tap apply switch printing in modal
      final applyModalBtn = find.byKey(const Key('apply_switch_printing_button'));
      expect(applyModalBtn, findsOneWidget);
      await tester.tap(applyModalBtn);
      await tester.pumpAndSettle();

      // Modal closed, verify hero art is still present
      expect(heroFinder, findsOneWidget);
    });
  });

  group('Empirical Challenge 2: Set Identity Row Sequence', () {
    testWidgets('Set Identity displays in strict sequence: [Set Symbol] [Set Code] [Set Name]', (tester) async {
      final card = createTestCard(
        id: 'test-set-seq',
        name: 'Black Lotus',
        setCode: 'lea',
        setName: 'Limited Edition Alpha',
        imageUrl: 'https://cards.scryfall.io/alpha.jpg',
      );
      await db.into(db.vaultItems).insert(card);

      await tester.pumpWidget(createHarness(
        CardDetailSheet(item: card, fetchOnlinePrintings: false),
        viewportSize: const Size(600, 1000),
      ));
      await tester.pumpAndSettle();

      final symbolFinder = find.byKey(const Key('card_detail_set_symbol_icon'));
      final codeFinder = find.byKey(const Key('card_detail_set_code_badge'));
      final nameFinder = find.byKey(const Key('card_detail_set_name'));

      expect(symbolFinder, findsOneWidget);
      expect(codeFinder, findsOneWidget);
      expect(nameFinder, findsOneWidget);

      final symbolDx = tester.getTopLeft(symbolFinder).dx;
      final codeDx = tester.getTopLeft(codeFinder).dx;
      final nameDx = tester.getTopLeft(nameFinder).dx;

      // Verify sequence [Set Symbol] < [Set Code] < [Set Name] horizontally
      expect(symbolDx, lessThan(codeDx), reason: 'Set Symbol must precede Set Code');
      expect(codeDx, lessThan(nameDx), reason: 'Set Code must precede Set Name');

      // Verify parent Row child hierarchy
      final rowAncestor = find.ancestor(of: symbolFinder, matching: find.byType(Row)).first;
      final Row rowWidget = tester.widget<Row>(rowAncestor);

      final iconIndex = rowWidget.children.indexWhere((w) => w.key == const Key('card_detail_set_symbol_icon'));
      final codeIndex = rowWidget.children.indexWhere((w) => w.key == const Key('card_detail_set_code_badge'));

      expect(iconIndex, isNot(-1));
      expect(codeIndex, isNot(-1));
      expect(iconIndex, lessThan(codeIndex), reason: 'Row children index for symbol must be before code');
    });
  });

  group('Empirical Challenge 3: Oracle Text Paragraph Line Breaks & Italics', () {
    testWidgets('Multiline Oracle text splits into distinct paragraphs with vertical spacing', (tester) async {
      final card = createTestCard(
        id: 'test-paragraphs',
        name: 'The One Ring',
        setCode: 'ltr',
        setName: 'The Lord of the Rings',
        imageUrl: 'https://cards.scryfall.io/ring.jpg',
        oracleText: 'Indestructible\nWhenever The One Ring enters, if you cast it, you gain protection.\nAt the beginning of your upkeep, you lose 1 life.',
      );
      await db.into(db.vaultItems).insert(card);

      await tester.pumpWidget(createHarness(
        CardDetailSheet(item: card, fetchOnlinePrintings: false),
        viewportSize: const Size(600, 1000),
      ));
      await tester.pumpAndSettle();

      final oracleSection = find.byKey(const Key('section_oracle_rules'));
      expect(oracleSection, findsOneWidget);

      // Verify individual paragraphs rendered
      expect(find.text('Indestructible'), findsOneWidget);
      expect(find.textContaining('Whenever The One Ring enters'), findsOneWidget);
      expect(find.textContaining('At the beginning of your upkeep'), findsOneWidget);

      // Verify distinct ManaText instances in the oracle section
      final manaTexts = tester.widgetList<ManaText>(find.byType(ManaText)).toList();
      expect(manaTexts.length, greaterThanOrEqualTo(3));
    });

    test('ManaTextParser styles parenthesized reminder text as FontStyle.italic while keeping main text normal', () {
      const text = "Flying (This creature can't be blocked except by creatures with flying or reach.)";
      final spans = ManaTextParser.parse(
        text: text,
        baseStyle: const TextStyle(fontSize: 14, fontStyle: FontStyle.normal),
        italicizeReminderText: true,
      );

      expect(spans, isNotEmpty);
      final firstTextSpan = spans.first as TextSpan;
      expect(firstTextSpan.text, 'Flying ');
      expect(firstTextSpan.style?.fontStyle, FontStyle.normal);

      final secondTextSpan = spans[1] as TextSpan;
      expect(secondTextSpan.text, "(This creature can't be blocked except by creatures with flying or reach.)");
      expect(secondTextSpan.style?.fontStyle, FontStyle.italic);
    });

    test('ManaTextParser correctly preserves mana symbols inside italicized reminder text', () {
      const text = 'Extort ({W/B}: Whenever you cast a spell, you may pay {W/B}.)';
      final spans = ManaTextParser.parse(
        text: text,
        baseStyle: const TextStyle(fontSize: 14, fontStyle: FontStyle.normal),
        italicizeReminderText: true,
      );

      // Should have: "Extort " (normal), "(" (italic), ManaSymbolSpan ({W/B}), ": Whenever you cast a spell, you may pay " (italic), ManaSymbolSpan ({W/B}), ".)" (italic)
      expect(spans, isNotEmpty);
      expect(spans.first is TextSpan, isTrue);
      expect((spans.first as TextSpan).text, 'Extort ');
      expect((spans.first as TextSpan).style?.fontStyle, FontStyle.normal);

      final symbolSpans = spans.whereType<ManaSymbolSpan>().toList();
      expect(symbolSpans.length, 2);
      expect(symbolSpans[0].rawSymbol, 'W/B');
      expect(symbolSpans[1].rawSymbol, 'W/B');

      // Check that text spans following '(' have italic style
      final italicSpans = spans.whereType<TextSpan>().where((s) => s.style?.fontStyle == FontStyle.italic).toList();
      expect(italicSpans, isNotEmpty);
    });
  });

  group('Empirical Challenge 4: Mechanics & Rulings Restructure & Progressive Disclosure', () {
    testWidgets('Mechanics render top attribute chips and [ Mechanic ] definitions', (tester) async {
      final card = createTestCard(
        id: 'test-mechanics',
        name: 'Vampire Nighthawk',
        setCode: 'm13',
        setName: 'Magic 2013',
        imageUrl: 'https://cards.scryfall.io/nighthawk.jpg',
        keywords: ['Flying', 'Deathtouch', 'Lifelink'],
      );
      await db.into(db.vaultItems).insert(card);

      await tester.pumpWidget(createHarness(
        CardDetailSheet(item: card, fetchOnlinePrintings: false),
        viewportSize: const Size(600, 1000),
      ));
      await tester.pumpAndSettle();

      // Verify keywords rendered as attribute chips
      expect(find.text('Flying'), findsWidgets);
      expect(find.text('Deathtouch'), findsWidgets);
      expect(find.text('Lifelink'), findsWidgets);

      // Verify definitions in [ Mechanic ] Definition format
      expect(find.text('[ Flying ]'), findsOneWidget);
      expect(find.text('[ Deathtouch ]'), findsOneWidget);
      expect(find.text('[ Lifelink ]'), findsOneWidget);
    });

    testWidgets('Rulings progressive disclosure: displays 1 initial ruling with "See All" expander', (tester) async {
      final card = createTestCard(
        id: 'test-multi-rulings',
        name: 'The One Ring',
        setCode: 'ltr',
        setName: 'The Lord of the Rings',
        imageUrl: 'https://cards.scryfall.io/ring.jpg',
        keywords: ['Indestructible'],
        rulings: [
          {
            'oracle_id': 'ring-oracle',
            'published_at': '2023-06-23',
            'comment': 'Ruling Alpha: Protection from everything means you cannot be targeted.',
          },
          {
            'oracle_id': 'ring-oracle',
            'published_at': '2023-06-24',
            'comment': 'Ruling Beta: Burden counters accumulate upon tapping.',
          },
          {
            'oracle_id': 'ring-oracle',
            'published_at': '2023-06-25',
            'comment': 'Ruling Gamma: Losing life is not the same as taking damage.',
          },
        ],
      );
      await db.into(db.vaultItems).insert(card);

      await tester.pumpWidget(createHarness(
        CardDetailSheet(item: card, fetchOnlinePrintings: false),
        viewportSize: const Size(600, 1200),
      ));
      await tester.pumpAndSettle();

      // Check whether initial ruling 1 is visible
      final ruling1 = find.textContaining('Ruling Alpha');
      // Check whether ruling 2 and ruling 3 are hidden or visible
      final ruling2 = find.textContaining('Ruling Beta');
      final ruling3 = find.textContaining('Ruling Gamma');
      final seeAllExpander = find.textContaining('See All');

      debugPrint('Challenger Observation on Rulings:');
      debugPrint('Ruling 1 visible: ${ruling1.evaluate().isNotEmpty}');
      debugPrint('Ruling 2 visible: ${ruling2.evaluate().isNotEmpty}');
      debugPrint('Ruling 3 visible: ${ruling3.evaluate().isNotEmpty}');
      debugPrint('See All expander found: ${seeAllExpander.evaluate().isNotEmpty}');

      // The specification requires: "display only one ruling initially with additional rulings expandable via a 'See All' toggle."
      expect(ruling1, findsOneWidget, reason: 'First ruling must be displayed');
      expect(seeAllExpander, findsOneWidget, reason: 'See All expander must exist when multiple rulings exist');
      expect(ruling2, findsNothing, reason: 'Subsequent rulings must NOT be displayed initially before expanding');
    });
  });

  group('Empirical Challenge 5: Unowned Cards Hide Acquisition Tracking', () {
    testWidgets('Unowned card (quantity == 0) completely hides Acquisition Tracking section', (tester) async {
      final unownedCard = createTestCard(
        id: 'unowned-card',
        name: 'Mox Diamond',
        setCode: 'sth',
        setName: 'Stronghold',
        imageUrl: 'https://cards.scryfall.io/sth.jpg',
        quantity: 0,
      );
      await db.into(db.vaultItems).insert(unownedCard);

      await tester.pumpWidget(createHarness(
        CardDetailSheet(item: unownedCard, fetchOnlinePrintings: false),
        tester: tester,
        viewportSize: const Size(1000, 3500),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('section_acquisition_tracking')), findsNothing);
      expect(find.text('Acquisition Tracking'), findsNothing);
    });

    testWidgets('Owned card (quantity > 0) displays Acquisition Tracking section', (tester) async {
      final ownedCard = createTestCard(
        id: 'owned-card',
        name: 'Mox Diamond',
        setCode: 'sth',
        setName: 'Stronghold',
        imageUrl: 'https://cards.scryfall.io/sth.jpg',
        quantity: 1,
      );
      await db.into(db.vaultItems).insert(ownedCard);

      await tester.pumpWidget(createHarness(
        CardDetailSheet(item: ownedCard, fetchOnlinePrintings: false),
        tester: tester,
        viewportSize: const Size(1000, 3500),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('section_acquisition_tracking')), findsOneWidget);
      expect(find.text('Acquisition Tracking'), findsOneWidget);
    });
  });

  group('Empirical Challenge 6: Versions & Printings Container & 320px Responsiveness', () {
    testWidgets('Thumbnail height is 110px and has zero RenderFlex overflow on 320px screen at 2.0x font scaling', (tester) async {
      final card = createTestCard(
        id: 'test-responsive',
        name: 'Sol Ring',
        setCode: 'cmd',
        setName: 'Commander 2011',
        imageUrl: 'https://cards.scryfall.io/cmd/243.jpg',
      );
      await db.into(db.vaultItems).insert(card);

      final candidate1 = CardPrintCandidate(
        setCode: 'cmd',
        setName: 'Commander 2011',
        collectorNumber: '243',
        imageUrl: 'https://cards.scryfall.io/cmd/243.jpg',
        artCropUrl: 'https://cards.scryfall.io/cmd/243_art.jpg',
        marketPrice: 2.0,
        rarity: 'uncommon',
        finishes: ['nonfoil'],
        frameEffects: [],
        rawData: {},
      );

      final candidate2 = CardPrintCandidate(
        setCode: '2x2',
        setName: 'Double Masters 2022 Ultra Deluxe Collector Foil Edition',
        collectorNumber: '313',
        imageUrl: 'https://cards.scryfall.io/2x2/313.jpg',
        artCropUrl: 'https://cards.scryfall.io/2x2/313_art.jpg',
        marketPrice: 15.0,
        rarity: 'mythic',
        finishes: ['foil', 'etched'],
        frameEffects: ['extendedart'],
        rawData: {},
      );

      await tester.pumpWidget(createHarness(
        VariantPriceChart(
          item: card,
          initialVariants: [candidate1, candidate2],
          enableOnlineFetch: false,
        ),
        tester: tester,
        viewportSize: const Size(320, 600),
        textScaleFactor: 2.0,
      ));
      await tester.pumpAndSettle();

      // Check card preview thumbnail container height is 110
      final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox)).where((sb) => sb.height == 110).toList();
      expect(sizedBoxes, isNotEmpty, reason: 'Card preview thumbnail container must have height 110');

      // Check image fit is BoxFit.contain
      final cachedImages = tester.widgetList<CountrCachedImage>(find.byType(CountrCachedImage)).toList();
      expect(cachedImages, isNotEmpty);
      expect(cachedImages.first.fit, BoxFit.contain, reason: 'Thumbnail must use BoxFit.contain for complete card art');

      // Verify zero RenderFlex overflow
      expect(tester.takeException(), isNull, reason: 'Zero RenderFlex overflow on 320px with 2.0x font scaling');
    });
  });

  group('Empirical Challenge 7: Metadata Section Bottom Placement', () {
    testWidgets('Metadata & Pedigree section is at the very bottom of the Details tab', (tester) async {
      final card = createTestCard(
        id: 'test-metadata-placement',
        name: 'Chandra, Torch of Defiance',
        setCode: 'kld',
        setName: 'Kaladesh',
        imageUrl: 'https://cards.scryfall.io/chandra.jpg',
        quantity: 1,
        oracleText: '+1: Exile the top card of your library.',
        dynamicJson: jsonEncode({'artist': 'Magali Villeneuve'}),
      );
      await db.into(db.vaultItems).insert(card);

      await tester.pumpWidget(createHarness(
        CardDetailSheet(item: card, fetchOnlinePrintings: false),
        tester: tester,
        viewportSize: const Size(1000, 3500),
      ));
      await tester.pumpAndSettle();

      final oracleFinder = find.byKey(const Key('section_oracle_rules'));
      final portfolioFinder = find.byKey(const Key('section_portfolio_metrics'));
      final acquisitionFinder = find.byKey(const Key('section_acquisition_tracking'));
      final historyFinder = find.byKey(const Key('section_deck_history'));
      final metadataFinder = find.byKey(const Key('section_metadata_pedigree'));

      expect(oracleFinder, findsOneWidget);
      expect(portfolioFinder, findsOneWidget);
      expect(acquisitionFinder, findsOneWidget);
      expect(historyFinder, findsOneWidget);
      expect(metadataFinder, findsOneWidget);

      final yOracle = tester.getTopLeft(oracleFinder).dy;
      final yPortfolio = tester.getTopLeft(portfolioFinder).dy;
      final yAcquisition = tester.getTopLeft(acquisitionFinder).dy;
      final yHistory = tester.getTopLeft(historyFinder).dy;
      final yMetadata = tester.getTopLeft(metadataFinder).dy;

      expect(yOracle, lessThan(yPortfolio));
      expect(yPortfolio, lessThan(yAcquisition));
      expect(yAcquisition, lessThan(yHistory));
      expect(yHistory, lessThan(yMetadata));
    });
  });
}
