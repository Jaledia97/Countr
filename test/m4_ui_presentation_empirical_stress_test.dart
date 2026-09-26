import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/decks/data/mock_deck_data.dart';
import 'package:countr/features/decks/domain/models/deck_item_with_card.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/decks/presentation/screens/deck_builder_screen.dart';
import 'package:countr/features/decks/presentation/widgets/proportional_bubble_scrollbar.dart';
import 'package:countr/features/hydration/data/services/scryfall_service.dart';
import 'package:countr/features/hydration/presentation/providers/hydration_providers.dart';
import 'package:countr/features/values/domain/services/pareto_distribution_calculator.dart';
import 'package:countr/features/values/presentation/widgets/locked_values_view.dart';
import 'package:countr/features/values/presentation/widgets/pareto_distribution_widget.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/screens/vault_screen.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';

import 'features/decks/deck_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Strict multi-currency regex scanning for currency symbol + numeric amount:
  /// e.g., $10, $10.50, €25, £99.99, CA$120.00
  final currencyRegex = RegExp(r'(\$|€|£|CA\$)\s*\d+(\.\d+)?');

  void assertZeroPrivacyLeaks(WidgetTester tester) {
    final textWidgets = tester.widgetList<Text>(find.byType(Text));
    for (final text in textWidgets) {
      final data = text.data;
      if (data != null) {
        final match = currencyRegex.firstMatch(data);
        expect(
          match,
          isNull,
          reason: 'Privacy leak detected in Text widget: "$data"',
        );
      }
      final textSpan = text.textSpan;
      if (textSpan != null) {
        final plainText = textSpan.toPlainText();
        final match = currencyRegex.firstMatch(plainText);
        expect(
          match,
          isNull,
          reason: 'Privacy leak detected in Text.textSpan: "$plainText"',
        );
      }
    }

    final richTextWidgets = tester.widgetList<RichText>(find.byType(RichText));
    for (final rich in richTextWidgets) {
      final plainText = rich.text.toPlainText();
      final match = currencyRegex.firstMatch(plainText);
      expect(
        match,
        isNull,
        reason: 'Privacy leak detected in RichText widget: "$plainText"',
      );
    }
  }

  late AppDatabase db;
  late ScryfallService mockScryfall;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.vaultDao.clearAllItems();
    await db.vaultDao.seedDatabase();

    mockScryfall = ScryfallService(
      client: MockClient((request) async {
        return http.Response(jsonEncode({'object': 'list', 'data': []}), 200);
      }),
    );
  });

  tearDown(() async {
    await db.close();
  });

  VaultItem createTestCard({
    String id = 'card-black-lotus-stress',
    String name = 'Black Lotus',
    String setCode = 'lea',
    String collectorNumber = '232',
    double price = 50000.0,
    int quantity = 1,
    double acquiredPrice = 12000.0,
    String condition = 'NM',
    String? protectionStatus = 'Double Sleeved + Toploader',
    int? binderPage = 1,
    String? binderSlot = 'A1',
    String? notes = 'Pristine Alpha Lotus investment piece.',
  }) {
    return VaultItem(
      id: id,
      collectionType: 'mtg',
      name: name,
      setOrSeries: setCode.toUpperCase(),
      imageUrl: 'https://cards.scryfall.io/normal/front/black_lotus.jpg',
      acquiredPrice: acquiredPrice,
      purchasePrice: acquiredPrice,
      acquiredDate: DateTime(2022, 1, 15),
      dateObtained: DateTime(2022, 1, 15),
      quantity: quantity,
      condition: condition,
      protectionStatus: protectionStatus,
      binderPage: binderPage,
      binderSlot: binderSlot,
      notes: notes,
      personalNotes: notes,
      isGraded: false,
      isAltered: false,
      isMisprint: false,
      isSigned: false, isDeleted: false,
      currentMarketPrice: price,
      lastPriceUpdate: DateTime(2026, 9, 24),
      dynamicData: jsonEncode({
        'collector_number': collectorNumber,
        'set': setCode.toLowerCase(),
        'artist': 'Christopher Rush',
        'border_color': 'black',
        'frame_effects': ['showcase'],
        'finishes': ['nonfoil'],
        'oracle_text': '{T}, Sacrifice Black Lotus: Add three mana of any one color.',
        'flavor_text': 'Treasured artifact of unmatched power.',
        'cached_rulings': [
          {
            'published_at': '2004-10-04',
            'comment': 'Black Lotus is a mana source and can be tapped whenever you could play an instant.',
          },
        ],
      }),
    );
  }

  final testDeck = createTestDeck(
    id: 'deck-stress-commander',
    name: 'Edgar Markov Aristocrats Tournament Deck',
    format: 'Commander',
    createdAt: DateTime.now(),
    wins: 25,
    losses: 4,
    draws: 2,
  );

  final List<Map<String, dynamic>> mockDeckItems = MockDeckData.getDeckItems(testDeck.id)
      .map<Map<String, dynamic>>(DeckItemWithCard.fromMap)
      .toList();

  final sampleTopCards = [
    const ParetoItem(
      rank: 1,
      id: 'c1',
      name: 'Black Lotus Alpha Edition',
      setCode: 'LEA',
      quantity: 1,
      unitPrice: 50000.0,
      lineValue: 50000.0,
      percentageShare: 72.4,
      weightRatio: 1.0,
      imageUrl: '',
    ),
    const ParetoItem(
      rank: 2,
      id: 'c2',
      name: 'Mox Sapphire Limited Beta',
      setCode: 'LEB',
      quantity: 1,
      unitPrice: 12000.0,
      lineValue: 12000.0,
      percentageShare: 17.4,
      weightRatio: 0.24,
      imageUrl: '',
    ),
    const ParetoItem(
      rank: 3,
      id: 'c3',
      name: 'Timetwister Collector Series',
      setCode: '2ED',
      quantity: 1,
      unitPrice: 4500.0,
      lineValue: 4500.0,
      percentageShare: 6.5,
      weightRatio: 0.09,
      imageUrl: '',
    ),
    const ParetoItem(
      rank: 4,
      id: 'c4',
      name: 'Underground Sea Dual Land',
      setCode: '3ED',
      quantity: 2,
      unitPrice: 900.0,
      lineValue: 1800.0,
      percentageShare: 2.6,
      weightRatio: 0.036,
      imageUrl: '',
    ),
    const ParetoItem(
      rank: 5,
      id: 'c5',
      name: 'Volcanic Island Dual Land',
      setCode: '3ED',
      quantity: 1,
      unitPrice: 750.0,
      lineValue: 750.0,
      percentageShare: 1.1,
      weightRatio: 0.015,
      imageUrl: '',
    ),
  ];

  group('STRESS SUITE 1: Ultra-Narrow Viewport (320x568 at 2.0x Font Scaling)', () {
    const narrowSize = Size(320, 568);
    const extremeTextScaler = TextScaler.linear(2.0);

    testWidgets('1.1: ParetoDistributionWidget renders with ZERO overflows on 320x568 @ 2.0x font scaling', (tester) async {
      tester.view.physicalSize = narrowSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: narrowSize,
                textScaler: extremeTextScaler,
              ),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: ParetoDistributionWidget(
                    deckTotalValue: 69050.0,
                    topKConcentrationPercentage: 100.0,
                    topCards: sampleTopCards,
                    isPrivacyMode: false,
                    currency: AppCurrency.usd,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'Zero exceptions/overflows in ParetoDistributionWidget');
      expect(find.byKey(const Key('pareto_distribution_widget')), findsOneWidget);
      expect(find.byKey(const Key('pareto_headline_banner')), findsOneWidget);
      expect(find.byKey(const Key('pareto_micro_list')), findsOneWidget);
      expect(find.byKey(const Key('pareto_row_1')), findsOneWidget);
    });

    testWidgets('1.2: DeckBuilderScreen Details mode renders with ZERO overflows on 320x568 @ 2.0x font scaling', (tester) async {
      tester.view.physicalSize = narrowSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deckItemsProvider(testDeck.id).overrideWith((ref) => Stream.value(mockDeckItems)),
            privacyModeProvider.overrideWith((ref) => false),
          ],
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: narrowSize,
                textScaler: extremeTextScaler,
              ),
              child: DeckBuilderScreen(deck: testDeck),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'Zero exceptions/overflows in DeckBuilderScreen Details mode');
      expect(find.byKey(const Key('deck_builder_tab_details')), findsOneWidget);
      expect(find.byType(ProportionalBubbleScrollbar), findsOneWidget);
    });

    testWidgets('1.3: DeckBuilderScreen Values mode renders with ZERO overflows on 320x568 @ 2.0x font scaling', (tester) async {
      tester.view.physicalSize = narrowSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deckItemsProvider(testDeck.id).overrideWith((ref) => Stream.value(mockDeckItems)),
            privacyModeProvider.overrideWith((ref) => false),
          ],
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: narrowSize,
                textScaler: extremeTextScaler,
              ),
              child: DeckBuilderScreen(deck: testDeck),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Values tab
      await tester.tap(find.byKey(const Key('deck_builder_tab_values')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'Zero exceptions/overflows in DeckBuilderScreen Values mode');
      expect(find.byKey(const Key('deck_values_aggregate_card')), findsOneWidget);

      // In a 568px height screen with 2.0x text scaling, ParetoDistributionWidget is below the fold.
      // Scroll down to verify it builds and renders with zero overflows.
      await tester.scrollUntilVisible(
        find.byType(ParetoDistributionWidget),
        200.0,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'Zero exceptions/overflows when scrolling ParetoDistributionWidget into view');
      expect(find.byType(ParetoDistributionWidget), findsOneWidget);
      expect(find.byKey(const Key('pareto_distribution_widget')), findsOneWidget);
    });

    testWidgets('1.4: CardDetailSheet Details mode renders with ZERO overflows on 320x568 @ 2.0x font scaling', (tester) async {
      tester.view.physicalSize = narrowSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final item = createTestCard();
      await db.into(db.vaultItems).insert(item);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(db.vaultDao),
            scryfallServiceProvider.overrideWithValue(mockScryfall),
            privacyModeProvider.overrideWith((ref) => false),
          ],
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: narrowSize,
                textScaler: extremeTextScaler,
              ),
              child: Scaffold(
                body: CardDetailSheet(item: item, fetchOnlinePrintings: false),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'Zero exceptions/overflows in CardDetailSheet Details mode');
      expect(find.byKey(const Key('card_detail_tab_details')), findsOneWidget);
      expect(find.byKey(const Key('section_oracle_rules')), findsOneWidget);
    });

    testWidgets('1.5: CardDetailSheet Values mode renders with ZERO overflows on 320x568 @ 2.0x font scaling', (tester) async {
      tester.view.physicalSize = narrowSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final item = createTestCard();
      await db.into(db.vaultItems).insert(item);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(db.vaultDao),
            scryfallServiceProvider.overrideWithValue(mockScryfall),
            privacyModeProvider.overrideWith((ref) => false),
          ],
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: narrowSize,
                textScaler: extremeTextScaler,
              ),
              child: Scaffold(
                body: CardDetailSheet(item: item, fetchOnlinePrintings: false),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Values tab
      await tester.tap(find.byKey(const Key('card_detail_tab_values')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'Zero exceptions/overflows in CardDetailSheet Values mode');
      expect(find.byKey(const Key('market_valuation_header')), findsOneWidget);
      expect(find.text('Cost Basis'), findsOneWidget);
      expect(find.text('P&L Return'), findsOneWidget);
    });

    testWidgets('1.6: VaultScreen renders with ZERO overflows on 320x568 @ 2.0x font scaling', (tester) async {
      tester.view.physicalSize = narrowSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(db.vaultDao),
            activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
            privacyModeProvider.overrideWith((ref) => false),
          ],
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: narrowSize,
                textScaler: extremeTextScaler,
              ),
              child: const VaultScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'Zero exceptions/overflows in VaultScreen Binders mode');
      expect(find.byKey(const Key('vault_portfolio_summary_card')), findsOneWidget);

      // Switch to Singles mode
      await tester.tap(find.byKey(const Key('vault_view_singles_toggle')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'Zero exceptions/overflows in VaultScreen Singles mode');
    });
  });

  group('STRESS SUITE 2: Privacy Mode & Multi-Currency Regex Leak Verification', () {
    testWidgets('2.1: CardDetailSheet Values tab renders LockedValuesView and zero privacy leaks', (tester) async {
      final item = createTestCard();
      await db.into(db.vaultItems).insert(item);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(db.vaultDao),
            scryfallServiceProvider.overrideWithValue(mockScryfall),
            privacyModeProvider.overrideWith((ref) => true),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: CardDetailSheet(item: item, fetchOnlinePrintings: false),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Values tab
      await tester.tap(find.byKey(const Key('card_detail_tab_values')));
      await tester.pumpAndSettle();

      // Verify LockedValuesView is rendered
      expect(find.byType(LockedValuesView), findsOneWidget);
      expect(find.byKey(const Key('card_detail_values_locked_container')), findsOneWidget);
      expect(find.text('Values hidden. Disable Privacy Mode to view market data.'), findsOneWidget);
      expect(find.byKey(const Key('locked_values_disable_privacy_button')), findsOneWidget);
      expect(find.byKey(const Key('market_valuation_header')), findsNothing);

      // Multi-currency regex scan across all widgets
      assertZeroPrivacyLeaks(tester);
    });

    testWidgets('2.2: DeckBuilderScreen Values tab renders LockedValuesView and zero privacy leaks', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deckItemsProvider(testDeck.id).overrideWith((ref) => Stream.value(mockDeckItems)),
            privacyModeProvider.overrideWith((ref) => true),
          ],
          child: MaterialApp(
            home: DeckBuilderScreen(deck: testDeck),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Values tab
      await tester.tap(find.byKey(const Key('deck_builder_tab_values')));
      await tester.pumpAndSettle();

      // Verify LockedValuesView is rendered
      expect(find.byType(LockedValuesView), findsOneWidget);
      expect(find.byKey(const Key('deck_builder_values_locked_container')), findsOneWidget);
      expect(find.text('Values hidden. Disable Privacy Mode to view market data.'), findsOneWidget);
      expect(find.byKey(const Key('deck_values_aggregate_card')), findsNothing);

      // Multi-currency regex scan across all widgets
      assertZeroPrivacyLeaks(tester);
    });

    testWidgets('2.3: DeckBuilderScreen Details tab strictly masks prices to **** and zero privacy leaks', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deckItemsProvider(testDeck.id).overrideWith((ref) => Stream.value(mockDeckItems)),
            privacyModeProvider.overrideWith((ref) => true),
          ],
          child: MaterialApp(
            home: DeckBuilderScreen(deck: testDeck),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Details tab card tiles should mask prices to ****
      expect(find.text('****'), findsWidgets);

      // Multi-currency regex scan across all widgets
      assertZeroPrivacyLeaks(tester);
    });

    testWidgets('2.4: VaultScreen strictly masks headline valuation & P&L and zero privacy leaks', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(db.vaultDao),
            activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
            privacyModeProvider.overrideWith((ref) => true),
          ],
          child: const MaterialApp(
            home: VaultScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Privacy icon should show visibility_off
      expect(find.byIcon(Icons.visibility_off), findsOneWidget);

      // Valuation and P&L must be masked to ****
      expect(find.text('****'), findsWidgets);

      // Multi-currency regex scan across all widgets
      assertZeroPrivacyLeaks(tester);
    });

    testWidgets('2.5: ParetoDistributionWidget masks all prices, percentages, headline across multi-currencies', (tester) async {
      final currencies = [
        AppCurrency.usd,
        AppCurrency.eur,
        AppCurrency.gbp,
        AppCurrency.cad,
      ];

      for (final curr in currencies) {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: ParetoDistributionWidget(
                    deckTotalValue: 69050.0,
                    topKConcentrationPercentage: 100.0,
                    topCards: sampleTopCards,
                    isPrivacyMode: true,
                    currency: curr,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Headline masks percentage to ****
        expect(find.textContaining('**** of this deck\'s total value'), findsOneWidget);

        // Prices and shares masked to ****
        expect(find.text('****'), findsWidgets);

        // Zero privacy leaks for this currency
        assertZeroPrivacyLeaks(tester);
      }
    });
  });

  group('STRESS SUITE 3: Vertical Order Invariant on CardDetailSheet Details Tab', () {
    testWidgets('3.1: Confirms strict 4-tier vertical hierarchy: oracleY < portfolioY < variantY < legalitiesY', (tester) async {
      tester.view.physicalSize = const Size(800, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final item = createTestCard();
      await db.into(db.vaultItems).insert(item);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(db.vaultDao),
            scryfallServiceProvider.overrideWithValue(mockScryfall),
            privacyModeProvider.overrideWith((ref) => false),
          ],
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(size: Size(800, 2600)),
              child: Scaffold(
                body: CardDetailSheet(item: item, fetchOnlinePrintings: false),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final oracleSection = find.byKey(const Key('section_oracle_rules'));
      final portfolioSection = find.byKey(const Key('section_portfolio_metrics'));
      final variantSection = find.byKey(const Key('section_variant_price_chart'));
      final legalitiesSection = find.byKey(const Key('section_format_legalities'));

      expect(oracleSection, findsOneWidget, reason: 'section_oracle_rules must exist');
      expect(portfolioSection, findsOneWidget, reason: 'section_portfolio_metrics must exist');
      expect(variantSection, findsOneWidget, reason: 'section_variant_price_chart must exist');
      expect(legalitiesSection, findsOneWidget, reason: 'section_format_legalities must exist');

      final oracleY = tester.getTopLeft(oracleSection).dy;
      final portfolioY = tester.getTopLeft(portfolioSection).dy;
      final variantY = tester.getTopLeft(variantSection).dy;
      final legalitiesY = tester.getTopLeft(legalitiesSection).dy;

      expect(oracleY < portfolioY, isTrue,
          reason: 'Invariant failed: oracleY ($oracleY) must be strictly above portfolioY ($portfolioY)');
      expect(portfolioY < variantY, isTrue,
          reason: 'Invariant failed: portfolioY ($portfolioY) must be strictly above variantY ($variantY)');
      expect(variantY < legalitiesY, isTrue,
          reason: 'Invariant failed: variantY ($variantY) must be strictly above legalitiesY ($legalitiesY)');
    });

    testWidgets('3.2: Vertical hierarchy holds in Deck Scope with DeckGearSection mounted', (tester) async {
      tester.view.physicalSize = const Size(800, 4500);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final item = createTestCard();
      await db.into(db.vaultItems).insert(item);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(db.vaultDao),
            scryfallServiceProvider.overrideWithValue(mockScryfall),
            privacyModeProvider.overrideWith((ref) => false),
          ],
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(size: Size(800, 4500)),
              child: Scaffold(
                body: CardDetailSheet(
                  item: item,
                  fetchOnlinePrintings: false,
                  deckId: 'deck-stress-commander',
                  deck: testDeck,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final oracleSection = find.byKey(const Key('section_oracle_rules'));
      final portfolioSection = find.byKey(const Key('section_portfolio_metrics'));
      final variantSection = find.byKey(const Key('section_variant_price_chart'));
      final legalitiesSection = find.byKey(const Key('section_format_legalities'));

      expect(oracleSection, findsOneWidget);
      expect(portfolioSection, findsOneWidget);
      expect(variantSection, findsOneWidget);
      expect(legalitiesSection, findsOneWidget);

      final oracleY = tester.getTopLeft(oracleSection).dy;
      final portfolioY = tester.getTopLeft(portfolioSection).dy;
      final variantY = tester.getTopLeft(variantSection).dy;
      final legalitiesY = tester.getTopLeft(legalitiesSection).dy;

      expect(oracleY < portfolioY, isTrue, reason: 'oracleY < portfolioY in Deck scope');
      expect(portfolioY < variantY, isTrue, reason: 'portfolioY < variantY in Deck scope');
      expect(variantY < legalitiesY, isTrue, reason: 'variantY < legalitiesY in Deck scope');
    });
  });

  group('STRESS SUITE 4: Deep Vertical Scrolling & Dynamic Privacy Toggling', () {
    const narrowSize = Size(320, 568);
    const extremeTextScaler = TextScaler.linear(2.0);

    testWidgets('4.1: CardDetailSheet Details mode deep scroll from top to bottom on 320x568 @ 2.0x font scaling', (tester) async {
      tester.view.physicalSize = narrowSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final item = createTestCard();
      await db.into(db.vaultItems).insert(item);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(db.vaultDao),
            scryfallServiceProvider.overrideWithValue(mockScryfall),
            privacyModeProvider.overrideWith((ref) => false),
          ],
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: narrowSize,
                textScaler: extremeTextScaler,
              ),
              child: Scaffold(
                body: CardDetailSheet(item: item, fetchOnlinePrintings: false),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scrollableFinder = find.byType(Scrollable).first;
      for (int i = 0; i < 6; i++) {
        await tester.drag(scrollableFinder, const Offset(0, -350));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Overflow occurred during deep scroll step $i in Details mode');
      }
    });

    testWidgets('4.2: CardDetailSheet Values mode deep scroll from top to bottom on 320x568 @ 2.0x font scaling', (tester) async {
      tester.view.physicalSize = narrowSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final item = createTestCard();
      await db.into(db.vaultItems).insert(item);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(db.vaultDao),
            scryfallServiceProvider.overrideWithValue(mockScryfall),
            privacyModeProvider.overrideWith((ref) => false),
          ],
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: narrowSize,
                textScaler: extremeTextScaler,
              ),
              child: Scaffold(
                body: CardDetailSheet(item: item, fetchOnlinePrintings: false),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Values tab
      await tester.tap(find.byKey(const Key('card_detail_tab_values')));
      await tester.pumpAndSettle();

      final scrollableFinder = find.byType(Scrollable).first;
      for (int i = 0; i < 6; i++) {
        await tester.drag(scrollableFinder, const Offset(0, -350));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'Overflow occurred during deep scroll step $i in Values mode');
      }
    });

    testWidgets('4.3: Dynamic Privacy Toggle: unlock via button, verify values, re-lock, verify zero leaks', (tester) async {
      final item = createTestCard();
      await db.into(db.vaultItems).insert(item);

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          scryfallServiceProvider.overrideWithValue(mockScryfall),
        ],
      );
      addTearDown(container.dispose);

      // Start with privacy mode active
      container.read(privacyModeProvider.notifier).state = true;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: CardDetailSheet(item: item, fetchOnlinePrintings: false),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Values tab -> Should be locked
      await tester.tap(find.byKey(const Key('card_detail_tab_values')));
      await tester.pumpAndSettle();

      expect(find.byType(LockedValuesView), findsOneWidget);
      assertZeroPrivacyLeaks(tester);

      // Tap Disable Privacy Mode button
      await tester.tap(find.byKey(const Key('locked_values_disable_privacy_button')));
      await tester.pumpAndSettle();

      // Now unlocked
      expect(container.read(privacyModeProvider), isFalse);
      expect(find.byType(LockedValuesView), findsNothing);
      expect(find.byKey(const Key('market_valuation_header')), findsOneWidget);

      // Dynamically re-lock privacy mode
      container.read(privacyModeProvider.notifier).state = true;
      await tester.pumpAndSettle();

      // Should immediately revert to locked view with zero leaks
      expect(find.byType(LockedValuesView), findsOneWidget);
      assertZeroPrivacyLeaks(tester);
    });

    testWidgets('4.4: ParetoDistributionWidget handles single card (100% concentration, topK=1)', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ParetoDistributionWidget(
                deckTotalValue: 1000.0,
                topKConcentrationPercentage: 100.0,
                topCards: [
                  ParetoItem(
                    rank: 1,
                    id: 'single-1',
                    name: 'Sol Ring Masterpiece',
                    setCode: 'KLD',
                    quantity: 1,
                    unitPrice: 1000.0,
                    lineValue: 1000.0,
                    percentageShare: 100.0,
                    weightRatio: 1.0,
                    imageUrl: '',
                  ),
                ],
                isPrivacyMode: false,
                currency: AppCurrency.usd,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('The top card represents 100.0% of this deck\'s total value.'), findsOneWidget);
      expect(find.byKey(const Key('pareto_row_1')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('4.5: ParetoDistributionWidget handles astronomical values without overflow on 320x568 @ 2.0x text scaling', (tester) async {
      tester.view.physicalSize = narrowSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: narrowSize,
                textScaler: extremeTextScaler,
              ),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: ParetoDistributionWidget(
                    deckTotalValue: 999999999.0,
                    topKConcentrationPercentage: 99.9,
                    topCards: [
                      ParetoItem(
                        rank: 1,
                        id: 'huge-1',
                        name: 'Black Lotus Alpha Pristine Gem Mint 10 Special Artwork Collector Edition',
                        setCode: 'LEA',
                        quantity: 4,
                        unitPrice: 249999999.75,
                        lineValue: 999999999.0,
                        percentageShare: 99.9,
                        weightRatio: 1.0,
                        imageUrl: '',
                      ),
                    ],
                    isPrivacyMode: false,
                    currency: AppCurrency.usd,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'Zero overflows for astronomical numbers under 320x568 @ 2.0x font scaling');
      expect(find.byKey(const Key('pareto_headline_banner')), findsOneWidget);
      expect(find.byKey(const Key('pareto_row_1')), findsOneWidget);
    });
  });
}

