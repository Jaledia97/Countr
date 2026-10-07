import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/settings_state.dart';
import 'package:countr/features/decks/domain/models/deck_item_with_card.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/decks/presentation/screens/deck_builder_screen.dart';
import 'package:countr/features/vault/domain/vault_pricing_helper.dart';
import 'package:countr/features/values/domain/services/deck_values_calculator.dart';
import 'package:countr/features/values/domain/services/pareto_distribution_calculator.dart';
import 'package:countr/features/values/domain/exchange_rate_service.dart';
import 'package:countr/features/values/presentation/widgets/pareto_distribution_widget.dart';
import 'deck_test_helpers.dart';

void main() {
  group('Empirical Challenger 2: Quantity Multiplication, Pareto Ranking & Deck Summation', () {
    // =========================================================================
    // 1. Quantity Multiplication & Summation Across Multiple Copies
    // =========================================================================
    group('1. Quantity Multiplication & Deck Summation', () {
      test('4x Lightning Bolt at \$2.50 = \$10.00 market value and \$6.00 cost basis', () {
        final bolt = DeckItemWithCard.fromRow({
          'id': 'bolt-4x',
          'name': 'Lightning Bolt',
          'deck_quantity': 4,
          'current_market_price': 2.50,
          'purchase_price': 1.50,
          'board_zone': 'Mainboard',
        });

        expect(bolt.deckQuantity, equals(4));
        expect(bolt.resolveMarketPrice(AppCurrency.usd), equals(2.50));
        expect(bolt.effectiveCostBasis, equals(1.50));
        expect(bolt.lineMarketValue(AppCurrency.usd), equals(10.00));
        expect(bolt.lineCostBasis, equals(6.00));

        final summary = DeckValuesCalculator.calculate(
          deckId: 'deck-bolt',
          items: [bolt],
          currency: AppCurrency.usd,
        );

        expect(summary.totalCardCount, equals(4));
        expect(summary.uniqueCardCount, equals(1));
        expect(summary.totalMarketValue, equals(10.00));
        expect(summary.totalCostBasis, equals(6.00));
        expect(summary.dollarReturn, equals(4.00));
        expect(summary.percentageReturn, closeTo((4.00 / 6.00) * 100.0, 0.001));
      });

      test('Multi-copy 100-card Commander deck exact mathematical summation', () {
        // Construct a realistic deck with various quantities and prices:
        // - 1x Commander: $50.00 (cost $30.00) -> Line $50.00, Cost $30.00
        // - 4x Lightning Bolt: $2.50 (cost $1.50) -> Line $10.00, Cost $6.00
        // - 35x Relentless Rats: $3.25 (cost $2.00) -> Line $113.75, Cost $70.00
        // - 20x Swamp: $0.25 (cost $0.10) -> Line $5.00, Cost $2.00
        // - 40x Basic Lands: $0.10 (cost $0.05) -> Line $4.00, Cost $2.00
        // Total cards = 1 + 4 + 35 + 20 + 40 = 100 cards
        // Total market = 50.00 + 10.00 + 113.75 + 5.00 + 4.00 = 182.75
        // Total cost = 30.00 + 6.00 + 70.00 + 2.00 + 2.00 = 110.00
        final items = [
          DeckItemWithCard.fromRow({
            'id': 'cmd-1',
            'name': 'Marrow-Gnawer',
            'deck_quantity': 1,
            'current_market_price': 50.00,
            'purchase_price': 30.00,
            'board_zone': 'Commander',
          }),
          DeckItemWithCard.fromRow({
            'id': 'bolt-4',
            'name': 'Lightning Bolt',
            'deck_quantity': 4,
            'current_market_price': 2.50,
            'purchase_price': 1.50,
            'board_zone': 'Mainboard',
          }),
          DeckItemWithCard.fromRow({
            'id': 'rats-35',
            'name': 'Relentless Rats',
            'deck_quantity': 35,
            'current_market_price': 3.25,
            'purchase_price': 2.00,
            'board_zone': 'Mainboard',
          }),
          DeckItemWithCard.fromRow({
            'id': 'swamp-20',
            'name': 'Swamp (Foil)',
            'deck_quantity': 20,
            'finish': 'foil',
            'is_foil': 1,
            'dynamic_data': jsonEncode({
              'prices': {'usd': '0.10', 'usd_foil': '0.25'}
            }),
            'purchase_price': 0.10,
            'board_zone': 'Mainboard',
          }),
          DeckItemWithCard.fromRow({
            'id': 'swamp-40',
            'name': 'Basic Swamp',
            'deck_quantity': 40,
            'finish': 'nonfoil',
            'current_market_price': 0.10,
            'purchase_price': 0.05,
            'board_zone': 'Mainboard',
          }),
        ];

        final summary = DeckValuesCalculator.calculate(
          deckId: 'deck-100-cards',
          items: items,
          currency: AppCurrency.usd,
        );

        expect(summary.totalCardCount, equals(100));
        expect(summary.uniqueCardCount, equals(5));
        expect(summary.totalMarketValue, closeTo(182.75, 0.001));
        expect(summary.totalCostBasis, closeTo(110.00, 0.001));
        expect(summary.dollarReturn, closeTo(72.75, 0.001));
        expect(summary.percentageReturn, closeTo((72.75 / 110.00) * 100.0, 0.001));
      });
    });

    // =========================================================================
    // 2. Zero Quantities, Negative Quantities, and Extreme Price Boundaries
    // =========================================================================
    group('2. Zero Quantities & Extreme Price Boundaries', () {
      test('Zero and negative quantities default defensively to 1 in calculation engine', () {
        // Defensive sanitation: items present in deck list but with 0 or negative quantity
        final zeroItem = DeckItemWithCard.fromRow({
          'id': 'card-zero-qty',
          'name': 'Zero Qty Card',
          'deck_quantity': 0,
          'current_market_price': 15.00,
          'purchase_price': 10.00,
        });

        final negItem = DeckItemWithCard.fromRow({
          'id': 'card-neg-qty',
          'name': 'Neg Qty Card',
          'deck_quantity': -3,
          'current_market_price': 25.00,
          'purchase_price': 20.00,
        });

        final summary = DeckValuesCalculator.calculate(
          deckId: 'deck-qty-sanitize',
          items: [zeroItem, negItem],
          currency: AppCurrency.usd,
        );

        // Both are sanitized to qty 1
        expect(summary.totalCardCount, equals(2));
        expect(summary.uniqueCardCount, equals(2));
        expect(summary.totalMarketValue, equals(40.00)); // 15 + 25
        expect(summary.totalCostBasis, equals(30.00)); // 10 + 20
      });

      test('Extreme high price boundary: \$1,250,000 Vintage Black Lotus with 99 basic lands', () {
        final lotus = DeckItemWithCard.fromRow({
          'id': 'lotus-alpha',
          'name': 'Black Lotus Alpha',
          'deck_quantity': 1,
          'current_market_price': 1250000.00,
          'purchase_price': 800000.00,
        });

        final lands = List.generate(
          99,
          (i) => DeckItemWithCard.fromRow({
            'id': 'land-$i',
            'name': 'Island #$i',
            'deck_quantity': 1,
            'current_market_price': 0.10,
            'purchase_price': 0.05,
          }),
        );

        final summary = DeckValuesCalculator.calculate(
          deckId: 'deck-whale',
          items: [lotus, ...lands],
          currency: AppCurrency.usd,
        );

        // Total Market = 1,250,000.00 + (99 * 0.10) = 1,250,009.90
        // Total Cost = 800,000.00 + (99 * 0.05) = 800,004.95
        expect(summary.totalCardCount, equals(100));
        expect(summary.uniqueCardCount, equals(100));
        expect(summary.totalMarketValue, closeTo(1250009.90, 0.01));
        expect(summary.totalCostBasis, closeTo(800004.95, 0.01));
        expect(summary.dollarReturn, closeTo(450004.95, 0.01));

        // Black Lotus represents > 99.99% of deck value
        expect(summary.heavyHitters.first.cardName, equals('Black Lotus Alpha'));
        expect(summary.heavyHitters.first.lineValue, equals(1250000.00));
        expect(summary.heavyHitters.first.shareOfTotal, greaterThan(99.99));
        expect(summary.paretoConcentration, greaterThan(99.99));
      });

      test('Extreme low price boundary: Fractional cents (\$0.0001) and \$0.00 tokens', () {
        final microCards = [
          DeckItemWithCard.fromRow({
            'id': 'micro-1',
            'name': 'Micro Cent Card 1',
            'deck_quantity': 100,
            'current_market_price': 0.0001,
            'purchase_price': 0.0,
          }),
          DeckItemWithCard.fromRow({
            'id': 'zero-1',
            'name': 'Free Token Card',
            'deck_quantity': 50,
            'current_market_price': 0.0,
            'purchase_price': 0.0,
          }),
        ];

        final summary = DeckValuesCalculator.calculate(
          deckId: 'deck-micro',
          items: microCards,
          currency: AppCurrency.usd,
        );

        // 100 * 0.0001 = 0.01
        // 50 * 0.0 = 0.00
        expect(summary.totalCardCount, equals(150));
        expect(summary.uniqueCardCount, equals(2));
        expect(summary.totalMarketValue, closeTo(0.01, 0.0001));
        expect(summary.totalCostBasis, equals(0.0));
        expect(summary.percentageReturn, equals(0.0)); // Division-by-zero defense
      });

      test('Float sanitization: NaN, Infinity, -Infinity are clamped to 0.0 without throwing', () {
        final corruptItems = [
          DeckItemWithCard.fromRow({
            'id': 'nan-1',
            'name': 'NaN Price Card',
            'deck_quantity': 4,
            'current_market_price': double.nan,
            'purchase_price': double.nan,
          }),
          DeckItemWithCard.fromRow({
            'id': 'inf-1',
            'name': 'Inf Price Card',
            'deck_quantity': 2,
            'current_market_price': double.infinity,
            'purchase_price': double.negativeInfinity,
          }),
          DeckItemWithCard.fromRow({
            'id': 'neg-1',
            'name': 'Negative Price Card',
            'deck_quantity': 1,
            'current_market_price': -50.0,
            'purchase_price': -20.0,
          }),
        ];

        final summary = DeckValuesCalculator.calculate(
          deckId: 'deck-corrupt',
          items: corruptItems,
          currency: AppCurrency.usd,
        );

        expect(summary.totalMarketValue, equals(0.0));
        expect(summary.totalCostBasis, equals(0.0));
        expect(summary.dollarReturn, equals(0.0));
        expect(summary.percentageReturn, equals(0.0));
        expect(summary.paretoConcentration, equals(0.0));
      });
    });

    // =========================================================================
    // 3. Pareto Ranking: Line Value (unitPrice * qty) vs Unit Price
    // =========================================================================
    group('3. Pareto Distribution Line Value Ranking Verification', () {
      test('Pareto ranking ranks cards by LINE VALUE (unitPrice * qty) rather than unit price alone', () {
        // Construct 4 cards where unit price ordering opposes line value ordering:
        // Card A: unitPrice $50.00, qty 1  -> Line Value = $50.00
        // Card B: unitPrice $15.00, qty 4  -> Line Value = $60.00
        // Card C: unitPrice $100.00, qty 1 -> Line Value = $100.00
        // Card D: unitPrice $2.00, qty 35  -> Line Value = $70.00
        //
        // Unit Price Ranking:  C ($100) > A ($50) > B ($15) > D ($2)
        // Line Value Ranking:  C ($100) > D ($70) > B ($60) > A ($50)
        final cards = [
          DeckItemWithCard.fromRow({
            'id': 'card-A',
            'name': 'A - Mana Vault',
            'deck_quantity': 1,
            'current_market_price': 50.00,
          }),
          DeckItemWithCard.fromRow({
            'id': 'card-B',
            'name': 'B - Scalding Tarn',
            'deck_quantity': 4,
            'current_market_price': 15.00,
          }),
          DeckItemWithCard.fromRow({
            'id': 'card-C',
            'name': 'C - Mox Diamond',
            'deck_quantity': 1,
            'current_market_price': 100.00,
          }),
          DeckItemWithCard.fromRow({
            'id': 'card-D',
            'name': 'D - Relentless Rats',
            'deck_quantity': 35,
            'current_market_price': 2.00,
          }),
        ];

        // 1. Verify DeckValuesCalculator Heavy Hitters Ranking
        final summary = DeckValuesCalculator.calculate(
          deckId: 'deck-pareto-test',
          items: cards,
          currency: AppCurrency.usd,
        );

        final hitters = summary.heavyHitters;
        expect(hitters.length, equals(4));

        // Rank 1: C - Mox Diamond ($100.00 line value)
        expect(hitters[0].cardName, equals('C - Mox Diamond'));
        expect(hitters[0].lineValue, equals(100.00));
        expect(hitters[0].unitPrice, equals(100.00));
        expect(hitters[0].quantity, equals(1));
        expect(hitters[0].rank, equals(1));

        // Rank 2: D - Relentless Rats ($70.00 line value, even though unit price is only $2.00!)
        expect(hitters[1].cardName, equals('D - Relentless Rats'));
        expect(hitters[1].lineValue, equals(70.00));
        expect(hitters[1].unitPrice, equals(2.00));
        expect(hitters[1].quantity, equals(35));
        expect(hitters[1].rank, equals(2));

        // Rank 3: B - Scalding Tarn ($60.00 line value, beats Card A's $50.00 line value!)
        expect(hitters[2].cardName, equals('B - Scalding Tarn'));
        expect(hitters[2].lineValue, equals(60.00));
        expect(hitters[2].unitPrice, equals(15.00));
        expect(hitters[2].quantity, equals(4));
        expect(hitters[2].rank, equals(3));

        // Rank 4: A - Mana Vault ($50.00 line value, ranked LAST despite second-highest unit price!)
        expect(hitters[3].cardName, equals('A - Mana Vault'));
        expect(hitters[3].lineValue, equals(50.00));
        expect(hitters[3].unitPrice, equals(50.00));
        expect(hitters[3].quantity, equals(1));
        expect(hitters[3].rank, equals(4));

        // 2. Verify ParetoDistributionCalculator Ranking
        final paretoInputs = cards
            .map((c) => ParetoCardInput.fromDeckItemWithCard(c, AppCurrency.usd))
            .toList();
        final paretoResult = ParetoDistributionCalculator.calculate(
          cards: paretoInputs,
          targetK: 4,
          currency: AppCurrency.usd,
        );

        expect(paretoResult.topCards.length, equals(4));
        expect(paretoResult.topCards[0].name, equals('C - Mox Diamond'));
        expect(paretoResult.topCards[0].lineValue, equals(100.00));

        expect(paretoResult.topCards[1].name, equals('D - Relentless Rats'));
        expect(paretoResult.topCards[1].lineValue, equals(70.00));

        expect(paretoResult.topCards[2].name, equals('B - Scalding Tarn'));
        expect(paretoResult.topCards[2].lineValue, equals(60.00));

        expect(paretoResult.topCards[3].name, equals('A - Mana Vault'));
        expect(paretoResult.topCards[3].lineValue, equals(50.00));
      });

      test('Deterministic tie-breaking when line values are identical: name ascending then unit price descending', () {
        // 3 cards all with line value = $40.00:
        // - "Alpha Wolf": 1x @ $40.00 = $40.00
        // - "Bravo Bear": 4x @ $10.00 = $40.00
        // - "Charlie Cat": 2x @ $20.00 = $40.00
        final tiedCards = [
          DeckItemWithCard.fromRow({'id': '3', 'name': 'Charlie Cat', 'deck_quantity': 2, 'current_market_price': 20.00}),
          DeckItemWithCard.fromRow({'id': '1', 'name': 'Alpha Wolf', 'deck_quantity': 1, 'current_market_price': 40.00}),
          DeckItemWithCard.fromRow({'id': '2', 'name': 'Bravo Bear', 'deck_quantity': 4, 'current_market_price': 10.00}),
        ];

        final summary = DeckValuesCalculator.calculate(
          deckId: 'deck-tie',
          items: tiedCards,
          currency: AppCurrency.usd,
        );

        expect(summary.heavyHitters[0].cardName, equals('Alpha Wolf'));
        expect(summary.heavyHitters[1].cardName, equals('Bravo Bear'));
        expect(summary.heavyHitters[2].cardName, equals('Charlie Cat'));
      });
    });

    // =========================================================================
    // 4. Widget Invariants: _buildValuesTab Aggregate and Zone Sum Equivalence
    // =========================================================================
    group('4. DeckBuilderScreen _buildValuesTab Aggregate Summation Widget Invariants', () {
      final testDeck = createTestDeck(
        id: 'deck-empirical-val',
        name: 'Monetary Valuation Test Deck',
        format: 'Modern',
        createdAt: DateTime.now(),
      );

      // Create test cards spread across Commander, Mainboard, Sideboard:
      // Zone 'Commander': 1x @ $50.00 (cost $30.00) = $50.00 (cost $30.00)
      // Zone 'Mainboard':
      //   - 4x Lightning Bolt @ $2.50 (cost $1.50) = $10.00 (cost $6.00)
      //   - 2x Scalding Tarn @ $20.00 (cost $12.00) = $40.00 (cost $24.00)
      // Zone 'Sideboard':
      //   - 3x Veil of Summer @ $5.00 (cost $3.00) = $15.00 (cost $9.00)
      //
      // Total Deck Market Value = 50.00 + 10.00 + 40.00 + 15.00 = 115.00 USD
      // Total Deck Cost Basis = 30.00 + 6.00 + 24.00 + 9.00 = 69.00 USD
      // Commander Zone Market Value = 50.00 USD
      // Mainboard Zone Market Value = 50.00 USD
      // Sideboard Zone Market Value = 15.00 USD
      // Total Cards = 1 + 4 + 2 + 3 = 10 cards (4 unique)
      final mockTestItems = <Map<String, dynamic>>[
        DeckItemWithCard.fromRow({
          'id': 'c-cmd',
          'vault_item_id': 'v-cmd',
          'name': 'Ragavan, Nimble Pilferer',
          'deck_quantity': 1,
          'current_market_price': 50.00,
          'purchase_price': 30.00,
          'board_zone': 'Commander',
        }),
        DeckItemWithCard.fromRow({
          'id': 'c-bolt',
          'vault_item_id': 'v-bolt',
          'name': 'Lightning Bolt',
          'deck_quantity': 4,
          'current_market_price': 2.50,
          'purchase_price': 1.50,
          'board_zone': 'Mainboard',
        }),
        DeckItemWithCard.fromRow({
          'id': 'c-tarn',
          'vault_item_id': 'v-tarn',
          'name': 'Scalding Tarn',
          'deck_quantity': 2,
          'current_market_price': 20.00,
          'purchase_price': 12.00,
          'board_zone': 'Mainboard',
        }),
        DeckItemWithCard.fromRow({
          'id': 'c-veil',
          'vault_item_id': 'v-veil',
          'name': 'Veil of Summer',
          'deck_quantity': 3,
          'current_market_price': 5.00,
          'purchase_price': 3.00,
          'board_zone': 'Sideboard',
        }),
      ];

      Widget createValuesTabSubject({
        required Deck deck,
        AppCurrency currency = AppCurrency.usd,
      }) {
        return ProviderScope(
          overrides: [
            deckProvider(deck.id).overrideWith((ref) => Stream.value(deck)),
            deckItemsProvider(deck.id).overrideWith((ref) => Stream.value(mockTestItems)),
            baseCurrencyProvider.overrideWith((ref) => currency),
            privacyModeProvider.overrideWith((ref) => false),
          ],
          child: MaterialApp(
            home: DeckBuilderScreen(deck: deck),
          ),
        );
      }

      testWidgets('Aggregate Deck Valuation card matches exact sum of line values (\$115.00)', (tester) async {
        tester.view.physicalSize = const Size(600, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(createValuesTabSubject(deck: testDeck));
        await tester.pumpAndSettle();

        // Switch to Values tab
        final valuesTab = find.byKey(const Key('deck_builder_tab_values'));
        expect(valuesTab, findsOneWidget);
        await tester.tap(valuesTab);
        await tester.pumpAndSettle();

        // 1. Verify Aggregate Card is present
        expect(find.byKey(const Key('deck_values_aggregate_card')), findsOneWidget);
        expect(find.text('AGGREGATE DECK VALUATION'), findsOneWidget);

        // 2. Verify Exact Total Valuation: $115.00
        expect(find.text('\$115.00'), findsWidgets);

        // 3. Verify Exact Total Cost Basis: $69.00
        expect(find.text('\$69.00'), findsWidgets);

        // 4. Verify Total Cards: 10 (4 unique)
        expect(find.text('10 (4 unique)'), findsOneWidget);

        // 5. Verify Valuation by Zone breakdown headers and rows
        expect(find.text('VALUATION BY ZONE'), findsOneWidget);
        expect(find.text('Commander'), findsWidgets);
        expect(find.text('Mainboard'), findsWidgets);
        expect(find.text('Sideboard'), findsWidgets);

        // Commander zone: $50.00
        // Mainboard zone: $50.00 (10 + 40)
        // Sideboard zone: $15.00
        expect(find.text('\$50.00'), findsWidgets);
        expect(find.text('\$15.00'), findsWidgets);

        // 6. Verify Pareto Distribution Widget mounts and displays top cards ranked by line value
        expect(find.byType(ParetoDistributionWidget), findsOneWidget);
        expect(find.text('Ragavan, Nimble Pilferer'), findsWidgets);
        expect(find.text('Scalding Tarn'), findsWidgets);
        expect(find.text('Veil of Summer'), findsWidgets);
        expect(find.text('Lightning Bolt'), findsWidgets);
      });

      testWidgets('Switching Base Currency to EUR updates Aggregate and Zone Totals accurately', (tester) async {
        tester.view.physicalSize = const Size(600, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(createValuesTabSubject(deck: testDeck, currency: AppCurrency.eur));
        await tester.pumpAndSettle();

        // Switch to Values tab
        await tester.tap(find.byKey(const Key('deck_builder_tab_values')));
        await tester.pumpAndSettle();

        // Rates: EUR rate is ~0.92
        // $115.00 * 0.92 = €105.80
        final convertedAmount = ExchangeRateService.convert(
          115.00,
          from: AppCurrency.usd,
          to: AppCurrency.eur,
        );
        final formattedTotal = VaultPricingHelper.formatAmount(
          convertedAmount,
          currency: AppCurrency.eur,
          isPrivacyMode: false,
          allowZero: true,
        );
        expect(find.text(formattedTotal), findsWidgets);
      });
    });
  });
}
