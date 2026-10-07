import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/state/settings_state.dart';
import 'package:countr/features/decks/domain/models/deck_item_with_card.dart';
import 'package:countr/features/values/domain/services/deck_values_calculator.dart';
import 'package:countr/features/values/domain/services/trimmed_average_calculator.dart';
import 'package:countr/features/vault/domain/vault_pricing_helper.dart';

void main() {
  group('Empirical Challenger 1: Milestone 3 Finish Isolation & Monetary Valuation', () {
    // Shared benchmark payload specified in dispatch
    final benchmarkPrices = {
      'usd': '1.00',
      'usd_foil': '20.00',
    };
    final benchmarkDynamicData = jsonEncode({'prices': benchmarkPrices});

    // =========================================================================
    // 1. Regular vs Foil Finish Isolation (Core Dispatch Mandate)
    // =========================================================================
    group('1. Regular vs. Foil Finish Isolation', () {
      test('Regular card evaluates to exactly \$1.00 USD across all layers', () {
        // VaultPricingHelper
        final vaultPrice = VaultPricingHelper.resolveHierarchicalPrice(
          benchmarkPrices,
          finish: 'nonfoil',
        );
        expect(vaultPrice, equals(1.00));

        // TrimmedAverageCalculator
        final trimmedPrice = TrimmedAverageCalculator.computeFromPayload(
          benchmarkDynamicData,
          finish: 'nonfoil',
        );
        expect(trimmedPrice, equals(1.00));

        // DeckItemWithCard
        final regularItem = DeckItemWithCard.fromRow({
          'id': 'reg-card-1',
          'name': 'Sol Ring',
          'dynamic_data': benchmarkDynamicData,
          'current_market_price': 0.0,
          'is_foil': 0,
          'finish': 'nonfoil',
          'deck_quantity': 3,
        });

        expect(regularItem.isFoil, isFalse);
        expect(regularItem.finish, equals('nonfoil'));
        expect(regularItem.resolveMarketPrice(AppCurrency.usd), equals(1.00));
        expect(regularItem.lineMarketValue(AppCurrency.usd), equals(3.00));
      });

      test('Foil card evaluates to exactly \$20.00 USD across all layers', () {
        // VaultPricingHelper
        final vaultPrice = VaultPricingHelper.resolveHierarchicalPrice(
          benchmarkPrices,
          finish: 'foil',
        );
        expect(vaultPrice, equals(20.00));

        // TrimmedAverageCalculator
        final trimmedPrice = TrimmedAverageCalculator.computeFromPayload(
          benchmarkDynamicData,
          finish: 'foil',
        );
        expect(trimmedPrice, equals(20.00));

        // DeckItemWithCard
        final foilItem = DeckItemWithCard.fromRow({
          'id': 'foil-card-1',
          'name': 'Sol Ring (Foil)',
          'dynamic_data': benchmarkDynamicData,
          'current_market_price': 0.0,
          'is_foil': 1,
          'finish': 'foil',
          'deck_quantity': 3,
        });

        expect(foilItem.isFoil, isTrue);
        expect(foilItem.finish, equals('foil'));
        expect(foilItem.resolveMarketPrice(AppCurrency.usd), equals(20.00));
        expect(foilItem.lineMarketValue(AppCurrency.usd), equals(60.00));
      });

      test('Strict Isolation: regular cards NEVER leak foil prices when nonfoil price is missing', () {
        final foilOnlyPrices = {
          'usd_foil': '20.00',
        };
        final foilOnlyDyn = jsonEncode({'prices': foilOnlyPrices});

        expect(
          VaultPricingHelper.resolveHierarchicalPrice(foilOnlyPrices, finish: 'nonfoil'),
          equals(0.0),
        );
        expect(
          TrimmedAverageCalculator.computeFromPayload(foilOnlyDyn, finish: 'nonfoil'),
          equals(0.0),
        );

        final item = DeckItemWithCard.fromRow({
          'id': 'foil-only-card',
          'name': 'Rare Promo',
          'dynamic_data': foilOnlyDyn,
          'finish': 'nonfoil',
          'is_foil': 0,
        });
        expect(item.resolveMarketPrice(AppCurrency.usd), equals(0.0));
      });

      test('Strict Isolation: foil cards NEVER leak non-foil prices when foil price is missing', () {
        final nonfoilOnlyPrices = {
          'usd': '1.00',
        };
        final nonfoilOnlyDyn = jsonEncode({'prices': nonfoilOnlyPrices});

        expect(
          VaultPricingHelper.resolveHierarchicalPrice(nonfoilOnlyPrices, finish: 'foil'),
          equals(0.0),
        );
        expect(
          TrimmedAverageCalculator.computeFromPayload(nonfoilOnlyDyn, finish: 'foil'),
          equals(0.0),
        );

        final item = DeckItemWithCard.fromRow({
          'id': 'nonfoil-only-card',
          'name': 'Common Card',
          'dynamic_data': nonfoilOnlyDyn,
          'finish': 'foil',
          'is_foil': 1,
        });
        expect(item.resolveMarketPrice(AppCurrency.usd), equals(0.0));
      });

      test('Subtle variations in finish labeling resolve deterministically', () {
        // Variants for nonfoil
        for (final nonfoilLabel in ['nonfoil', 'NonFoil', 'regular', 'REGULAR', 'normal', ' normal ']) {
          final item = DeckItemWithCard.fromRow({
            'id': 'test-$nonfoilLabel',
            'name': 'Card',
            'dynamic_data': benchmarkDynamicData,
            'finish': nonfoilLabel,
          });
          expect(item.isFoil, isFalse, reason: 'Failed for label: $nonfoilLabel');
          expect(item.finish, equals('nonfoil'), reason: 'Failed for label: $nonfoilLabel');
          expect(item.resolveMarketPrice(AppCurrency.usd), equals(1.00), reason: 'Failed for label: $nonfoilLabel');
        }

        // Variants for foil
        for (final foilLabel in ['foil', 'FOIL', 'Traditional Foil', ' traditional foil ', 'foil-etched']) {
          final item = DeckItemWithCard.fromRow({
            'id': 'test-$foilLabel',
            'name': 'Card',
            'dynamic_data': benchmarkDynamicData,
            'finish': foilLabel,
          });
          expect(item.isFoil, isTrue, reason: 'Failed for label: $foilLabel');
          expect(item.finish, equals('foil'), reason: 'Failed for label: $foilLabel');
          expect(item.resolveMarketPrice(AppCurrency.usd), equals(20.00), reason: 'Failed for label: $foilLabel');
        }
      });
    });

    // =========================================================================
    // 2. Etched Finish Resolution
    // =========================================================================
    group('2. Etched Finish Resolution', () {
      final triplePrices = {
        'usd': '1.00',
        'usd_foil': '20.00',
        'usd_etched': '15.00',
      };

      test('Etched finish resolves to usd_etched in VaultPricingHelper', () {
        expect(
          VaultPricingHelper.resolveHierarchicalPrice(triplePrices, finish: 'etched'),
          equals(15.00),
        );
      });

      test('Etched finish falls back to usd_foil if usd_etched is absent', () {
        final noEtchedPrice = {
          'usd': '1.00',
          'usd_foil': '20.00',
        };
        expect(
          VaultPricingHelper.resolveHierarchicalPrice(noEtchedPrice, finish: 'etched'),
          equals(20.00),
        );
      });

      test('Etched finish resolves to 0.0 if only regular non-foil price is present', () {
        final regularOnly = {
          'usd': '1.00',
        };
        expect(
          VaultPricingHelper.resolveHierarchicalPrice(regularOnly, finish: 'etched'),
          equals(0.0),
        );
      });

      test('Etched card in DeckItemWithCard with only usd_etched resolves correctly', () {
        final etchedOnlyDyn = jsonEncode({
          'prices': {
            'usd': '1.00',
            'usd_etched': '15.00',
          }
        });
        final etchedItem = DeckItemWithCard.fromRow({
          'id': 'etched-1',
          'name': 'Etched Commander',
          'dynamic_data': etchedOnlyDyn,
          'finish': 'etched',
        });

        expect(etchedItem.isFoil, isTrue);
        expect(etchedItem.resolveMarketPrice(AppCurrency.usd), equals(15.00));
      });
    });

    // =========================================================================
    // 3. Missing Currency Keys & Zero Unhandled Exceptions
    // =========================================================================
    group('3. Missing Currency Keys & Exception Resilience', () {
      test('Empty prices map returns 0.0 with zero exceptions', () {
        expect(VaultPricingHelper.resolveHierarchicalPrice({}, finish: 'nonfoil'), equals(0.0));
        expect(VaultPricingHelper.resolveHierarchicalPrice({}, finish: 'foil'), equals(0.0));
        expect(VaultPricingHelper.resolveHierarchicalPrice({}, finish: 'etched'), equals(0.0));
        expect(VaultPricingHelper.resolveHierarchicalPrice({}, finish: null), equals(0.0));
      });

      test('Null or malformed prices return 0.0 with zero exceptions', () {
        final malformedPrices = {
          'usd': 'null',
          'usd_foil': 'NaN',
          'usd_etched': 'Infinity',
          'eur': '-5.00',
          'eur_foil': '0.00',
        };
        expect(VaultPricingHelper.resolveHierarchicalPrice(malformedPrices, finish: 'nonfoil'), equals(0.0));
        expect(VaultPricingHelper.resolveHierarchicalPrice(malformedPrices, finish: 'foil'), equals(0.0));
        expect(TrimmedAverageCalculator.computeFromPayload(jsonEncode({'prices': malformedPrices})), equals(0.0));
      });

      test('Corrupted or non-JSON dynamicData returns 0.0 with zero exceptions', () {
        final corruptedPayloads = [
          null,
          '',
          '   ',
          'not json',
          '{bad_json: true',
          '[]',
          '12345',
        ];

        for (final badPayload in corruptedPayloads) {
          expect(
            VaultPricingHelper.extractFromDynamicData(badPayload, finish: 'nonfoil'),
            equals(0.0),
          );
          expect(
            TrimmedAverageCalculator.computeFromPayload(badPayload, finish: 'nonfoil'),
            equals(0.0),
          );

          final item = DeckItemWithCard.fromRow({
            'id': 'bad-payload',
            'name': 'Corrupted Card',
            'dynamic_data': badPayload,
          });
          expect(item.resolveMarketPrice(AppCurrency.usd), equals(0.0));
        }
      });

      test('Double-faced card resolves price from first card_face', () {
        final dfcData = jsonEncode({
          'card_faces': [
            {
              'name': 'Front Face',
              'prices': {
                'usd': '4.50',
                'usd_foil': '18.00',
              }
            },
            {
              'name': 'Back Face',
            }
          ]
        });

        expect(
          VaultPricingHelper.extractFromDynamicData(dfcData, finish: 'nonfoil'),
          equals(4.50),
        );
        expect(
          VaultPricingHelper.extractFromDynamicData(dfcData, finish: 'foil'),
          equals(18.00),
        );
        expect(
          TrimmedAverageCalculator.computeFromPayload(dfcData, finish: 'nonfoil'),
          equals(4.50),
        );
        expect(
          TrimmedAverageCalculator.computeFromPayload(dfcData, finish: 'foil'),
          equals(18.00),
        );
      });
    });

    // =========================================================================
    // 4. DeckValuesCalculator Quantity Multiplication & Pareto Ranking
    // =========================================================================
    group('4. Aggregate Valuation & Quantity Multiplier Stress Test', () {
      test('Complete deck aggregation with mixed finishes, quantities, and edge cases', () {
        final deckItems = [
          // 4x Regular card: 4 * $1.00 = $4.00
          DeckItemWithCard.fromRow({
            'id': 'card-regular-4x',
            'name': 'Lightning Bolt',
            'deck_quantity': 4,
            'finish': 'nonfoil',
            'dynamic_data': benchmarkDynamicData,
            'purchase_price': 0.50,
            'board_zone': 'Mainboard',
          }),
          // 2x Foil card: 2 * $20.00 = $40.00
          DeckItemWithCard.fromRow({
            'id': 'card-foil-2x',
            'name': 'Scalding Tarn',
            'deck_quantity': 2,
            'finish': 'foil',
            'is_foil': 1,
            'dynamic_data': benchmarkDynamicData,
            'purchase_price': 10.00,
            'board_zone': 'Mainboard',
          }),
          // 1x Etched card with usd_etched: 1 * $15.00 = $15.00
          DeckItemWithCard.fromRow({
            'id': 'card-etched-1x',
            'name': 'Jeweled Lotus',
            'deck_quantity': 1,
            'finish': 'etched',
            'dynamic_data': jsonEncode({
              'prices': {
                'usd': '1.00',
                'usd_etched': '15.00',
              }
            }),
            'purchase_price': 8.00,
            'board_zone': 'Commander',
          }),
          // 1x Missing price card: 1 * $0.00 = $0.00
          DeckItemWithCard.fromRow({
            'id': 'card-missing-1x',
            'name': 'Unknown Token',
            'deck_quantity': 1,
            'dynamic_data': '{}',
            'purchase_price': 0.00,
            'board_zone': 'Sideboard',
          }),
        ];

        final summary = DeckValuesCalculator.calculate(
          deckId: 'deck-challenger-m3',
          items: deckItems,
          currency: AppCurrency.usd,
        );

        // Expected totals:
        // Total Market = 4.00 + 40.00 + 15.00 + 0.00 = 59.00 USD
        // Total Cost = (4 * 0.50) + (2 * 10.00) + (1 * 8.00) + 0.00 = 2.00 + 20.00 + 8.00 = 30.00 USD
        // Dollar Return = 59.00 - 30.00 = 29.00 USD
        // Percentage Return = (29.00 / 30.00) * 100 = 96.67%
        // Total Card Count = 4 + 2 + 1 + 1 = 8 cards
        // Unique Card Count = 4 cards
        expect(summary.totalMarketValue, equals(59.00));
        expect(summary.totalCostBasis, equals(30.00));
        expect(summary.dollarReturn, closeTo(29.00, 0.001));
        expect(summary.percentageReturn, closeTo((29.0 / 30.0) * 100.0, 0.01));
        expect(summary.totalCardCount, equals(8));
        expect(summary.uniqueCardCount, equals(4));

        // Pareto Ranking verification:
        // Rank 1: Scalding Tarn (2x @ $20.00 = $40.00)
        // Rank 2: Jeweled Lotus (1x @ $15.00 = $15.00)
        // Rank 3: Lightning Bolt (4x @ $1.00 = $4.00)
        // Rank 4: Unknown Token (1x @ $0.00 = $0.00)
        expect(summary.heavyHitters.length, equals(4));
        expect(summary.heavyHitters[0].cardName, equals('Scalding Tarn'));
        expect(summary.heavyHitters[0].lineValue, equals(40.00));
        expect(summary.heavyHitters[0].quantity, equals(2));
        expect(summary.heavyHitters[0].unitPrice, equals(20.00));

        expect(summary.heavyHitters[1].cardName, equals('Jeweled Lotus'));
        expect(summary.heavyHitters[1].lineValue, equals(15.00));
        expect(summary.heavyHitters[1].quantity, equals(1));

        expect(summary.heavyHitters[2].cardName, equals('Lightning Bolt'));
        expect(summary.heavyHitters[2].lineValue, equals(4.00));
        expect(summary.heavyHitters[2].quantity, equals(4));

        expect(summary.heavyHitters[3].cardName, equals('Unknown Token'));
        expect(summary.heavyHitters[3].lineValue, equals(0.00));
      });
    });
  });
}
