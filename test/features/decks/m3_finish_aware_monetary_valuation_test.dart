import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/state/settings_state.dart';
import 'package:countr/features/decks/domain/models/deck_item_with_card.dart';
import 'package:countr/features/values/domain/services/deck_values_calculator.dart';
import 'package:countr/features/vault/domain/vault_pricing_helper.dart';

void main() {
  group('Milestone 3 (R6): Accurate Monetary Value Calculation & Finish Resolution', () {
    // -------------------------------------------------------------------------
    // 1. VaultPricingHelper Finish Awareness
    // -------------------------------------------------------------------------
    group('1. VaultPricingHelper Finish Resolution', () {
      final prices = {
        'usd': '2.00',
        'usd_foil': '25.00',
        'usd_etched': '30.00',
        'eur': '1.80',
        'eur_foil': '22.00',
      };

      test('Non-foil finishes only resolve non-foil keys (usd, eur)', () {
        expect(
          VaultPricingHelper.resolveHierarchicalPrice(prices, finish: 'nonfoil'),
          2.00,
        );

        final eurOnlyNonfoil = {
          'usd': null,
          'usd_foil': '25.00',
          'eur': '1.80',
        };
        expect(
          VaultPricingHelper.resolveHierarchicalPrice(eurOnlyNonfoil, finish: 'nonfoil'),
          1.80,
        );

        final foilOnly = {
          'usd_foil': '25.00',
        };
        // Should not fall back to foil price for nonfoil card
        expect(
          VaultPricingHelper.resolveHierarchicalPrice(foilOnly, finish: 'nonfoil'),
          0.0,
        );
      });

      test('Foil finishes only resolve foil keys (usd_foil, usd_etched, eur_foil)', () {
        expect(
          VaultPricingHelper.resolveHierarchicalPrice(prices, finish: 'foil'),
          25.00,
        );

        final nonfoilOnly = {
          'usd': '2.00',
          'eur': '1.80',
        };
        // Should not fall back to nonfoil price for foil card
        expect(
          VaultPricingHelper.resolveHierarchicalPrice(nonfoilOnly, finish: 'foil'),
          0.0,
        );
      });

      test('Etched finishes prioritize usd_etched', () {
        expect(
          VaultPricingHelper.resolveHierarchicalPrice(prices, finish: 'etched'),
          30.00,
        );
      });

      test('Null finish preserves legacy fallback hierarchy', () {
        expect(
          VaultPricingHelper.resolveHierarchicalPrice(prices, finish: null),
          2.00,
        );
        final noUsd = {
          'usd_foil': '25.00',
          'eur': '1.80',
        };
        expect(
          VaultPricingHelper.resolveHierarchicalPrice(noUsd, finish: null),
          25.00,
        );
      });
    });

    // -------------------------------------------------------------------------
    // 2. DeckItemWithCard Finish Resolution
    // -------------------------------------------------------------------------
    group('2. DeckItemWithCard Dynamic Price Resolution', () {
      final mixedDynamicData = jsonEncode({
        'prices': {
          'usd': '1.00',
          'usd_foil': '20.00',
        }
      });

      test('Regular non-foil card resolves strictly to non-foil price (\\\$1.00)', () {
        final regularItem = DeckItemWithCard.fromRow({
          'id': 'card-regular',
          'name': 'Sol Ring',
          'dynamic_data': mixedDynamicData,
          'current_market_price': 0.0,
          'is_foil': 0,
          'finish': 'nonfoil',
        });

        expect(regularItem.isFoil, isFalse);
        expect(regularItem.finish, 'nonfoil');
        expect(regularItem.resolveMarketPrice(AppCurrency.usd), 1.00);
      });

      test('Foil card resolves strictly to foil price (\\\$20.00)', () {
        final foilItem = DeckItemWithCard.fromRow({
          'id': 'card-foil',
          'name': 'Sol Ring (Foil)',
          'dynamic_data': mixedDynamicData,
          'current_market_price': 0.0,
          'is_foil': 1,
          'finish': 'foil',
        });

        expect(foilItem.isFoil, isTrue);
        expect(foilItem.finish, 'foil');
        expect(foilItem.resolveMarketPrice(AppCurrency.usd), 20.00);
      });

      test('Foil detected via finish name containing foil', () {
        final foilByFinishName = DeckItemWithCard.fromRow({
          'id': 'card-foil-finish',
          'name': 'Sol Ring',
          'dynamic_data': mixedDynamicData,
          'finish': 'Traditional Foil',
        });

        expect(foilByFinishName.isFoil, isTrue);
        expect(foilByFinishName.resolveMarketPrice(AppCurrency.usd), 20.00);
      });

      test('Foil detected via condition containing foil', () {
        final foilByCondition = DeckItemWithCard.fromRow({
          'id': 'card-foil-cond',
          'name': 'Sol Ring',
          'dynamic_data': mixedDynamicData,
          'condition': 'NM Foil',
        });

        expect(foilByCondition.isFoil, isTrue);
        expect(foilByCondition.resolveMarketPrice(AppCurrency.usd), 20.00);
      });
    });

    // -------------------------------------------------------------------------
    // 3. DeckValuesCalculator Quantity Summation & Aggregate Accuracy
    // -------------------------------------------------------------------------
    group('3. DeckValuesCalculator Quantity Multiplication & Totals', () {
      test('Accurately multiplies unit price by deck quantity and sums aggregate total', () {
        final items = [
          // 4x Lightning Bolt @ $2.00 (Cost $1.00)
          DeckItemWithCard.fromRow({
            'id': 'bolt',
            'name': 'Lightning Bolt',
            'deck_quantity': 4,
            'current_market_price': 2.00,
            'purchase_price': 1.00,
            'board_zone': 'Mainboard',
          }),
          // 2x Foil Scalding Tarn @ $35.00 (Cost $20.00)
          DeckItemWithCard.fromRow({
            'id': 'tarn',
            'name': 'Scalding Tarn',
            'deck_quantity': 2,
            'is_foil': 1,
            'finish': 'foil',
            'dynamic_data': jsonEncode({
              'prices': {'usd': '15.00', 'usd_foil': '35.00'}
            }),
            'purchase_price': 20.00,
            'board_zone': 'Mainboard',
          }),
          // 1x Non-foil Scalding Tarn @ $15.00 (Cost $10.00)
          DeckItemWithCard.fromRow({
            'id': 'tarn-reg',
            'name': 'Scalding Tarn Nonfoil',
            'deck_quantity': 1,
            'finish': 'nonfoil',
            'dynamic_data': jsonEncode({
              'prices': {'usd': '15.00', 'usd_foil': '35.00'}
            }),
            'purchase_price': 10.00,
            'board_zone': 'Mainboard',
          }),
        ];

        final summary = DeckValuesCalculator.calculate(
          deckId: 'deck-quant-test',
          items: items,
          currency: AppCurrency.usd,
        );

        // Card 1: 4 * $2.00 = $8.00 market, 4 * $1.00 = $4.00 cost
        // Card 2: 2 * $35.00 = $70.00 market, 2 * $20.00 = $40.00 cost
        // Card 3: 1 * $15.00 = $15.00 market, 1 * $10.00 = $10.00 cost
        // Total Market = 8.00 + 70.00 + 15.00 = 93.00
        // Total Cost = 4.00 + 40.00 + 10.00 = 54.00
        // Return = 93.00 - 54.00 = +39.00 (+72.22%)
        // Total Card Count = 4 + 2 + 1 = 7 cards
        // Unique Count = 3
        expect(summary.totalMarketValue, 93.00);
        expect(summary.totalCostBasis, 54.00);
        expect(summary.dollarReturn, closeTo(39.00, 0.001));
        expect(summary.percentageReturn, closeTo((39.0 / 54.0) * 100.0, 0.01));
        expect(summary.totalCardCount, 7);
        expect(summary.uniqueCardCount, 3);

        // Pareto Ranking: Tarn Foil ($70.00) > Tarn Nonfoil ($15.00) > Bolt ($8.00)
        expect(summary.heavyHitters.length, 3);
        expect(summary.heavyHitters[0].cardName, 'Scalding Tarn');
        expect(summary.heavyHitters[0].lineValue, 70.00);
        expect(summary.heavyHitters[0].quantity, 2);
        expect(summary.heavyHitters[0].unitPrice, 35.00);

        expect(summary.heavyHitters[1].cardName, 'Scalding Tarn Nonfoil');
        expect(summary.heavyHitters[1].lineValue, 15.00);

        expect(summary.heavyHitters[2].cardName, 'Lightning Bolt');
        expect(summary.heavyHitters[2].lineValue, 8.00);
      });
    });
  });
}
