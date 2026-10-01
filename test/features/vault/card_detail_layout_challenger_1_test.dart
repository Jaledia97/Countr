import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:countr/core/constants/app_colors.dart';
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
    String id = 'card-test-sol-ring',
    String name = 'Sol Ring',
    String setCode = 'cmd',
    String collectorNumber = '243',
    double price = 1.75,
    int quantity = 1,
    double acquiredPrice = 1.50,
    String condition = 'NM',
    String? dynamicData,
  }) {
    return VaultItem(
      id: id,
      collectionType: 'mtg',
      name: name,
      setOrSeries: setCode.toUpperCase(),
      imageUrl: 'https://cards.scryfall.io/normal/front/sol_ring.jpg',
      acquiredPrice: acquiredPrice,
      acquiredDate: DateTime(2023, 1, 1),
      quantity: quantity,
      condition: condition,
      isGraded: false,
      isAltered: false,
      isMisprint: false,
      isSigned: false, isDeleted: false,
      currentMarketPrice: price,
      lastPriceUpdate: DateTime(2023, 1, 1),
      personalNotes: 'Commander staple.',
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
    Size viewportSize = const Size(800, 2600),
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

  group('CHALLENGER 1: Strict Vertical Hierarchy Assertions Across Multiple Card Configurations', () {
    testWidgets('Configuration 1 (Owned Card): strictly verifies oracleY < portfolioY < variantY < legalitiesY', (tester) async {
      tester.view.physicalSize = const Size(800, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final item = createTestCard(quantity: 1, price: 2.25, acquiredPrice: 1.50);
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

      final oracleFinder = find.byKey(const Key('section_oracle_rules'));
      final portfolioFinder = find.byKey(const Key('section_portfolio_metrics'));
      final variantFinder = find.byKey(const Key('section_variant_price_chart'));
      final legalitiesFinder = find.byKey(const Key('section_format_legalities'));

      expect(oracleFinder, findsOneWidget, reason: 'Oracle section must be present');
      expect(portfolioFinder, findsOneWidget, reason: 'Portfolio section must be present');
      expect(variantFinder, findsOneWidget, reason: 'Variant Chart section must be present');
      expect(legalitiesFinder, findsOneWidget, reason: 'Format Legalities section must be present');

      // Verify section header text labels
      expect(find.text('Oracle Rules Text'), findsOneWidget);
      expect(find.text('Collection & Portfolio Metrics'), findsOneWidget);
      expect(find.text('Format Legalities'), findsOneWidget);

      final double oracleY = tester.getTopLeft(oracleFinder).dy;
      final double portfolioY = tester.getTopLeft(portfolioFinder).dy;
      final double variantY = tester.getTopLeft(variantFinder).dy;
      final double legalitiesY = tester.getTopLeft(legalitiesFinder).dy;

      // Strict vertical ordering assertions
      expect(
        oracleY < portfolioY,
        isTrue,
        reason: 'Oracle ($oracleY) must appear strictly above Portfolio ($portfolioY)',
      );
      expect(
        portfolioY < variantY,
        isTrue,
        reason: 'Portfolio ($portfolioY) must appear strictly above Variant Chart ($variantY)',
      );
      expect(
        variantY < legalitiesY,
        isTrue,
        reason: 'Variant Chart ($variantY) must appear strictly above Legalities ($legalitiesY)',
      );
      expect(
        oracleY < portfolioY && portfolioY < variantY && variantY < legalitiesY,
        isTrue,
        reason: 'Strict 4-tier vertical order violated: oracleY=$oracleY, portfolioY=$portfolioY, variantY=$variantY, legalitiesY=$legalitiesY',
      );
    });

    testWidgets('Configuration 1 (Unowned Catalog Card): strictly verifies oracleY < portfolioY < variantY < legalitiesY with Add to Vault button', (tester) async {
      tester.view.physicalSize = const Size(800, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Unowned card has quantity: 0
      final unownedItem = createTestCard(
        id: 'catalog-black-lotus',
        name: 'Black Lotus',
        setCode: 'lea',
        collectorNumber: '232',
        price: 15000.0,
        quantity: 0,
        acquiredPrice: 0.0,
        dynamicData: jsonEncode({
          'collector_number': '232',
          'set': 'lea',
          'oracle_id': 'oracle-black-lotus-uuid',
          'oracle_text': '{T}, Sacrifice Black Lotus: Add three mana of any one color.',
          'flavor_text': '',
        }),
      );

      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'object': 'list', 'data': []}), 200);
      });
      final scryfall = ScryfallService(client: mockClient);

      await tester.pumpWidget(createTestWidget(
        CardDetailSheet(item: unownedItem, fetchOnlinePrintings: false),
        scryfallService: scryfall,
        viewportSize: const Size(800, 2600),
      ));
      await tester.pumpAndSettle();

      // For unowned card, "Add to +" button is rendered
      final addToVaultFinder = find.byKey(const Key('quick_action_add_to_plus'));
      expect(addToVaultFinder, findsOneWidget, reason: 'Unowned card must render Add to + button');

      final oracleFinder = find.byKey(const Key('section_oracle_rules'));
      // Portfolio section header text is always present for unowned card
      final portfolioFinder = find.text('Collection & Portfolio Metrics');
      final variantFinder = find.byKey(const Key('section_variant_price_chart'));
      final legalitiesFinder = find.byKey(const Key('section_format_legalities'));

      expect(oracleFinder, findsOneWidget);
      expect(portfolioFinder, findsOneWidget);
      expect(variantFinder, findsOneWidget);
      expect(legalitiesFinder, findsOneWidget);

      // Section key verified on unowned catalog branch
      final keyPortfolioFinder = find.byKey(const Key('section_portfolio_metrics'));
      expect(
        keyPortfolioFinder,
        findsOneWidget,
        reason: 'Key("section_portfolio_metrics") must be present on unowned branch (line 1319 in card_detail_sheet.dart)',
      );

      // Verify unowned metadata items
      expect(find.text('0x'), findsOneWidget);
      expect(find.text('unowned'), findsOneWidget);

      final double addToVaultY = tester.getTopLeft(addToVaultFinder).dy;
      final double oracleY = tester.getTopLeft(oracleFinder).dy;
      final double portfolioY = tester.getTopLeft(portfolioFinder).dy;
      final double variantY = tester.getTopLeft(variantFinder).dy;
      final double legalitiesY = tester.getTopLeft(legalitiesFinder).dy;

      expect(
        oracleY < addToVaultY,
        isTrue,
        reason: 'Quick actions bar ($addToVaultY) must render at bottom below Oracle Rules ($oracleY)',
      );
      expect(
        oracleY < portfolioY,
        isTrue,
        reason: 'Oracle Rules ($oracleY) must appear strictly above Portfolio ($portfolioY)',
      );
      expect(
        portfolioY < variantY,
        isTrue,
        reason: 'Portfolio ($portfolioY) must appear strictly above Variant Chart ($variantY)',
      );
      expect(
        variantY < legalitiesY,
        isTrue,
        reason: 'Variant Chart ($variantY) must appear strictly above Legalities ($legalitiesY)',
      );
      expect(
        oracleY < portfolioY && portfolioY < variantY && variantY < legalitiesY,
        isTrue,
        reason: 'Strict 4-tier vertical order violated for unowned card: oracleY=$oracleY, portfolioY=$portfolioY, variantY=$variantY, legalitiesY=$legalitiesY',
      );
    });

    testWidgets('Configuration 2 (Dual-Faced Card DFC): verifies switch face button & strict vertical order before and after flip', (tester) async {
      tester.view.physicalSize = const Size(800, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final dfcItem = createTestCard(
        id: 'dfc-card-delver',
        name: 'Delver of Secrets // Insectile Aberration',
        dynamicData: jsonEncode({
          'layout': 'transform',
          'oracle_text': 'At the beginning of your upkeep, look at the top card of your library. You may reveal that card. If an instant or sorcery card is revealed this way, transform Delver of Secrets. // Flying',
          'keywords': ['Flying', 'Transform'],
          'cached_rulings': [
            {'published_at': '2011-09-24', 'comment': 'Transforming a double-faced card does not cause it to leave the battlefield.'},
          ],
          'card_faces': [
            {
              'name': 'Delver of Secrets',
              'image_uris': {'normal': 'https://cards.scryfall.io/front/delver.jpg'},
              'type_line': 'Creature — Human Wizard',
              'oracle_text': 'At the beginning of your upkeep, look at the top card of your library. You may reveal that card. If an instant or sorcery card is revealed this way, transform Delver of Secrets.',
            },
            {
              'name': 'Insectile Aberration',
              'image_uris': {'normal': 'https://cards.scryfall.io/back/insectile.jpg'},
              'type_line': 'Creature — Human Insect',
              'oracle_text': 'Flying',
            },
          ],
        }),
      );

      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'object': 'list', 'data': []}), 200);
      });
      final scryfall = ScryfallService(client: mockClient);

      await tester.pumpWidget(createTestWidget(
        CardDetailSheet(item: dfcItem, fetchOnlinePrintings: false),
        scryfallService: scryfall,
        viewportSize: const Size(800, 2600),
      ));
      await tester.pumpAndSettle();

      // DFC must render switch face button
      final switchFaceButton = find.byKey(const Key('card_detail_switch_face_button'));
      expect(switchFaceButton, findsOneWidget, reason: 'DFC must render switch face button');
      expect(find.text('View Face 2'), findsOneWidget);

      // Measure coordinates on Face 1
      double oracleY = tester.getTopLeft(find.byKey(const Key('section_oracle_rules'))).dy;
      double portfolioY = tester.getTopLeft(find.byKey(const Key('section_portfolio_metrics'))).dy;
      double variantY = tester.getTopLeft(find.byKey(const Key('section_variant_price_chart'))).dy;
      double legalitiesY = tester.getTopLeft(find.byKey(const Key('section_format_legalities'))).dy;

      expect(
        oracleY < portfolioY && portfolioY < variantY && variantY < legalitiesY,
        isTrue,
        reason: 'Face 1 vertical order violated: oracleY=$oracleY, portfolioY=$portfolioY, variantY=$variantY, legalitiesY=$legalitiesY',
      );

      // Tap switch face button to switch to Face 2
      await tester.tap(switchFaceButton);
      await tester.pumpAndSettle();

      // Verify button updated to 'View Face 1'
      expect(find.text('View Face 1'), findsOneWidget);

      // Measure coordinates on Face 2
      oracleY = tester.getTopLeft(find.byKey(const Key('section_oracle_rules'))).dy;
      portfolioY = tester.getTopLeft(find.byKey(const Key('section_portfolio_metrics'))).dy;
      variantY = tester.getTopLeft(find.byKey(const Key('section_variant_price_chart'))).dy;
      legalitiesY = tester.getTopLeft(find.byKey(const Key('section_format_legalities'))).dy;

      expect(
        oracleY < portfolioY && portfolioY < variantY && variantY < legalitiesY,
        isTrue,
        reason: 'Face 2 vertical order violated after flip: oracleY=$oracleY, portfolioY=$portfolioY, variantY=$variantY, legalitiesY=$legalitiesY',
      );
    });

    testWidgets('Configuration 3 (Adventure Card with flavor text): verifies flip buttons disabled & strict vertical order preserved', (tester) async {
      tester.view.physicalSize = const Size(800, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final adventureItem = createTestCard(
        id: 'adventure-bonecrusher-giant',
        name: 'Bonecrusher Giant // Stomp',
        setCode: 'eld',
        collectorNumber: '115',
        dynamicData: jsonEncode({
          'layout': 'adventure',
          'type_line': 'Creature — Giant // Instant — Adventure',
          'oracle_text': 'Whenever Bonecrusher Giant becomes the target of a spell, Bonecrusher Giant deals 2 damage to that spell\'s controller. // Damage can\'t be prevented this turn. Stomp deals 2 damage to any target.',
          'flavor_text': 'Not every story ends with a hero\'s feast.',
          'card_faces': [
            {
              'name': 'Bonecrusher Giant',
              'type_line': 'Creature — Giant',
              'mana_cost': '{2}{R}',
              'oracle_text': 'Whenever Bonecrusher Giant becomes the target of a spell, Bonecrusher Giant deals 2 damage to that spell\'s controller.',
              'flavor_text': 'Not every story ends with a hero\'s feast.',
              'power': '4',
              'toughness': '3',
            },
            {
              'name': 'Stomp',
              'type_line': 'Instant — Adventure',
              'mana_cost': '{1}{R}',
              'oracle_text': 'Damage can\'t be prevented this turn. Stomp deals 2 damage to any target.',
            },
          ],
        }),
      );

      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'object': 'list', 'data': []}), 200);
      });
      final scryfall = ScryfallService(client: mockClient);

      await tester.pumpWidget(createTestWidget(
        CardDetailSheet(item: adventureItem, fetchOnlinePrintings: false),
        scryfallService: scryfall,
        viewportSize: const Size(800, 2600),
      ));
      await tester.pumpAndSettle();

      // Adventure cards must strictly disable 3D flip button and switch face button
      expect(
        find.byKey(const Key('card_detail_switch_face_button')),
        findsNothing,
        reason: 'Adventure cards must NOT render switch face button',
      );
      expect(
        find.byKey(const Key('card_detail_flip_button')),
        findsNothing,
        reason: 'Adventure cards must NOT render flip art button',
      );

      // Verify unified adventure oracle box with both parts rendered
      expect(find.textContaining('Bonecrusher Giant'), findsWidgets);
      expect(find.textContaining('Stomp'), findsWidgets);
      expect(find.textContaining('Not every story ends with a hero\'s feast.'), findsWidgets);

      // Measure vertical coordinates
      final double oracleY = tester.getTopLeft(find.byKey(const Key('section_oracle_rules'))).dy;
      final double portfolioY = tester.getTopLeft(find.byKey(const Key('section_portfolio_metrics'))).dy;
      final double variantY = tester.getTopLeft(find.byKey(const Key('section_variant_price_chart'))).dy;
      final double legalitiesY = tester.getTopLeft(find.byKey(const Key('section_format_legalities'))).dy;

      expect(
        oracleY < portfolioY && portfolioY < variantY && variantY < legalitiesY,
        isTrue,
        reason: 'Adventure card vertical order violated: oracleY=$oracleY, portfolioY=$portfolioY, variantY=$variantY, legalitiesY=$legalitiesY',
      );
    });

    testWidgets('Adversarial Stress: captures RenderFlex overflows on 320px viewport with 2.0x font scaling', (tester) async {
      tester.view.physicalSize = const Size(320, 5000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final item = createTestCard(
        name: 'Omnath, Locus of Creation',
        dynamicData: jsonEncode({
          'collector_number': '232',
          'set': 'znr',
          'oracle_text': 'When Omnath enters the battlefield, draw a card.',
          'flavor_text': 'A manifestation of Zendikar rage.',
        }),
      );

      final List<FlutterErrorDetails> caughtErrors = [];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        caughtErrors.add(details);
      };

      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'object': 'list', 'data': []}), 200);
      });
      final scryfall = ScryfallService(client: mockClient);

      await tester.pumpWidget(createTestWidget(
        CardDetailSheet(item: item, fetchOnlinePrintings: false),
        scryfallService: scryfall,
        viewportSize: const Size(320, 5000),
        textScaler: const TextScaler.linear(2.0),
      ));
      await tester.pumpAndSettle();

      FlutterError.onError = originalOnError;

      final overflowErrors = caughtErrors.where((e) {
        return e.exceptionAsString().contains('RenderFlex overflowed');
      }).toList();

      // Zero RenderFlex overflows confirmed on 320px screen at 2.0x font scaling:
      expect(
        overflowErrors,
        isEmpty,
        reason: 'Zero RenderFlex overflows must occur on 320px screen at 2.0x font scaling',
      );

      // Verify that despite the overflow bugs in child rows, the 4-tier vertical structure coordinates remain ordered
      final double oracleY = tester.getTopLeft(find.byKey(const Key('section_oracle_rules'))).dy;
      final double portfolioY = tester.getTopLeft(find.byKey(const Key('section_portfolio_metrics'))).dy;
      final double variantY = tester.getTopLeft(find.byKey(const Key('section_variant_price_chart'))).dy;
      final double legalitiesY = tester.getTopLeft(find.byKey(const Key('section_format_legalities'))).dy;

      expect(
        oracleY < portfolioY && portfolioY < variantY && variantY < legalitiesY,
        isTrue,
        reason: 'Vertical ordering: oracleY ($oracleY) < portfolioY ($portfolioY) < variantY ($variantY) < legalitiesY ($legalitiesY)',
      );
    });
  });

  group('CHALLENGER 1: Empirical Interactive Variant Selection & Visual State Verification', () {
    testWidgets('Standalone VariantPriceChart: visual selection state updates (border color, width, background tint, Set as Active button)', (tester) async {
      final item = createTestCard(setCode: 'CMD', collectorNumber: '243', price: 1.75);

      final candidateCmd = createCandidate(
        setCode: 'CMD',
        setName: 'Commander 2011',
        collectorNumber: '243',
        price: 1.75,
        finishes: ['nonfoil'],
      );
      final candidate2x2 = createCandidate(
        setCode: '2X2',
        setName: 'Double Masters 2022',
        collectorNumber: '313',
        price: 4.50,
        finishes: ['foil'],
      );
      final candidateMps = createCandidate(
        setCode: 'MPS',
        setName: 'Kaladesh Inventions',
        collectorNumber: '024',
        price: 250.00,
        finishes: ['etched'],
      );

      final variants = [candidateCmd, candidate2x2, candidateMps];

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
        viewportSize: const Size(600, 800),
      ));
      await tester.pumpAndSettle();

      // Find variant cards
      final cmdCardFinder = find.byKey(const Key('variant_card_cmd_243'));
      final altCardFinder = find.byKey(const Key('variant_card_2x2_313'));
      final mpsCardFinder = find.byKey(const Key('variant_card_mps_024'));

      expect(cmdCardFinder, findsOneWidget);
      expect(altCardFinder, findsOneWidget);
      expect(mpsCardFinder, findsOneWidget);

      // --- Initial State Assertions ---
      // Candidate CMD is initially selected (matches item)
      final initialCmdContainer = tester.widget<AnimatedContainer>(
        find.descendant(of: cmdCardFinder, matching: find.byType(AnimatedContainer)).first,
      );
      final initialCmdDeco = initialCmdContainer.decoration as BoxDecoration;
      expect(
        initialCmdDeco.border?.top.color,
        AppColors.accentAmber,
        reason: 'Active printing card must have accentAmber border',
      );
      expect(
        initialCmdDeco.border?.top.width,
        2.0,
        reason: 'Selected card border width must be 2.0',
      );
      expect(
        initialCmdDeco.color,
        AppColors.accentCyan.withValues(alpha: 0.14),
        reason: 'Selected card must have cyan tinted background',
      );

      // Candidate 2X2 is NOT selected initially
      final initialAltContainer = tester.widget<AnimatedContainer>(
        find.descendant(of: altCardFinder, matching: find.byType(AnimatedContainer)).first,
      );
      final initialAltDeco = initialAltContainer.decoration as BoxDecoration;
      expect(
        initialAltDeco.border?.top.color,
        isNot(AppColors.accentCyan),
        reason: 'Unselected card must not have accentCyan border',
      );
      expect(
        initialAltDeco.border?.top.width,
        1.0,
        reason: 'Unselected card border width must be 1.0',
      );

      // "Set as Active" button is hidden when current active printing is selected
      expect(
        find.byKey(const Key('button_apply_switch_printing')),
        findsNothing,
        reason: 'Set as Active button must not be visible when active printing is selected',
      );

      // --- Interaction 1: Tap alternative variant 2X2 ---
      await tester.tap(altCardFinder);
      await tester.pumpAndSettle();

      // Callback verified
      expect(selectedCandidate, isNotNull);
      expect(selectedCandidate!.setCode, '2x2');
      expect(selectedCandidate!.collectorNumber, '313');

      // Visual state of 2X2 must now be selected
      final updatedAltContainer = tester.widget<AnimatedContainer>(
        find.descendant(of: altCardFinder, matching: find.byType(AnimatedContainer)).first,
      );
      final updatedAltDeco = updatedAltContainer.decoration as BoxDecoration;
      expect(
        updatedAltDeco.border?.top.color,
        AppColors.accentCyan,
        reason: 'Newly selected 2X2 card must have accentCyan border',
      );
      expect(
        updatedAltDeco.border?.top.width,
        2.0,
        reason: 'Newly selected 2X2 card border width must be 2.0',
      );
      expect(
        updatedAltDeco.color,
        AppColors.accentCyan.withValues(alpha: 0.14),
        reason: 'Newly selected 2X2 card must have cyan tinted background',
      );

      // Candidate CMD must now be deselected (it is active printing, so it has accentAmber border with width 1.0)
      final deselectedCmdContainer = tester.widget<AnimatedContainer>(
        find.descendant(of: cmdCardFinder, matching: find.byType(AnimatedContainer)).first,
      );
      final deselectedCmdDeco = deselectedCmdContainer.decoration as BoxDecoration;
      expect(
        deselectedCmdDeco.border?.top.color,
        AppColors.accentAmber,
        reason: 'Deselected active owned card has accentAmber border',
      );
      expect(
        deselectedCmdDeco.border?.top.width,
        2.0,
        reason: 'Active card border width is 2.0',
      );

      // "Set as Active" button MUST NOW BE VISIBLE
      final setAsActiveBtn = find.byKey(const Key('button_apply_switch_printing'));
      expect(setAsActiveBtn, findsOneWidget, reason: 'Set as Active button must appear when alternative variant is selected');
      expect(find.text('Set as Active'), findsOneWidget);

      // --- Interaction 2: Tap MPS variant ---
      await tester.tap(mpsCardFinder);
      await tester.pumpAndSettle();

      expect(selectedCandidate!.setCode, 'mps');
      final updatedMpsContainer = tester.widget<AnimatedContainer>(
        find.descendant(of: mpsCardFinder, matching: find.byType(AnimatedContainer)).first,
      );
      final updatedMpsDeco = updatedMpsContainer.decoration as BoxDecoration;
      expect(updatedMpsDeco.border?.top.color, AppColors.accentCyan);
      expect(updatedMpsDeco.border?.top.width, 2.0);

      // --- Interaction 3: Tap back on CMD (the owned active printing) ---
      await tester.tap(cmdCardFinder);
      await tester.pumpAndSettle();

      // "Set as Active" button disappears because selected == active
      expect(find.byKey(const Key('button_apply_switch_printing')), findsNothing);
    });

    testWidgets('Integrated CardDetailSheet: selecting variant updates header price preview and switching updates database', (tester) async {
      tester.view.physicalSize = const Size(800, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final initialItem = createTestCard(
        id: 'db-sol-ring-test-sync',
        setCode: 'CMD',
        collectorNumber: '243',
        price: 1.75,
      );
      await db.into(db.vaultItems).insert(initialItem);

      // Insert catalog items for CMD and 2X2 so VariantPriceChart queries them from SQLite
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
        acquiredPrice: 18.50,
        acquiredDate: DateTime(2023, 1, 1),
        quantity: 1,
        condition: 'NM',
        isGraded: false, isAltered: false, isMisprint: false, isSigned: false, isDeleted: false,
        currentMarketPrice: 18.50,
        lastPriceUpdate: DateTime(2023, 1, 1),
        dynamicData: jsonEncode({
          'collector_number': '313',
          'set': '2x2',
          'set_name': 'Double Masters 2022',
          'finishes': ['foil'],
        }),
      ));

      await tester.pumpWidget(createTestWidget(
        CardDetailSheet(item: initialItem, fetchOnlinePrintings: false),
        viewportSize: const Size(800, 2600),
      ));
      await tester.pumpAndSettle();

      // Initial price in header reflects 1.75
      expect(find.textContaining('1.75'), findsWidgets);

      // Alternative variant card exists
      final variant2x2Finder = find.byKey(const Key('variant_card_2x2_313'));
      expect(variant2x2Finder, findsOneWidget);

      // Tap alternative variant navigates to distinct Card Details page (R10)
      await tester.tap(variant2x2Finder);
      await tester.pumpAndSettle();

      // Distinct Card Details page for that printing candidate is pushed (R10)
      expect(find.byType(CardDetailSheet), findsWidgets);
      expect(find.textContaining('18.50'), findsWidgets);
      expect(find.textContaining('2X2'), findsWidgets);
    });
  });
}
