import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/features/trades/domain/models/trade_fairness.dart';
import 'package:countr/features/trades/domain/models/trade_participant.dart';
import 'package:countr/features/trades/domain/services/trade_pricing_calculator.dart';
import 'trade_test_helpers.dart';

void main() {
  group('TradePricingCalculator - Finish & Variant Aware Pricing', () {
    test('resolves non-foil pricing from dynamic data', () {
      final card = createTestCard(
        id: 'card-1',
        name: 'Mox Diamond',
        currentMarketPrice: 50.0,
        dynamicData: jsonEncode({
          'finish': 'non_foil',
          'prices': {'usd': '55.00', 'usd_foil': '120.00'},
        }),
      );

      final finish = TradePricingCalculator.resolveFinish(card);
      expect(finish, equals('non_foil'));

      final price = TradePricingCalculator.calculateCardPrice(card);
      expect(price, equals(55.0));
    });

    test('resolves foil pricing from dynamic data', () {
      final card = createTestCard(
        id: 'card-2',
        name: 'Sol Ring',
        currentMarketPrice: 2.0,
        dynamicData: jsonEncode({
          'finish': 'foil',
          'prices': {'usd': '2.50', 'usd_foil': '25.00'},
        }),
      );

      final finish = TradePricingCalculator.resolveFinish(card);
      expect(finish, equals('foil'));

      final price = TradePricingCalculator.calculateCardPrice(card);
      expect(price, equals(25.0));
    });

    test('resolves etched foil pricing from finishes array in dynamic data', () {
      final card = createTestCard(
        id: 'card-3',
        name: 'Jeweled Lotus',
        currentMarketPrice: 80.0,
        dynamicData: jsonEncode({
          'finishes': ['etched'],
          'prices': {'usd': '80.00', 'usd_etched': '140.00'},
        }),
      );

      final finish = TradePricingCalculator.resolveFinish(card);
      expect(finish, equals('etched'));

      final price = TradePricingCalculator.calculateCardPrice(card);
      expect(price, equals(140.0));
    });

    test('falls back to currentMarketPrice when dynamicData has no prices', () {
      final card = createTestCard(
        id: 'card-4',
        name: 'Mana Crypt',
        currentMarketPrice: 180.0,
        dynamicData: '{}',
      );

      final price = TradePricingCalculator.calculateCardPrice(card);
      expect(price, equals(180.0));
    });
  });

  group('TradeFairnessCalculator & TradeFairnessResult', () {
    final userA = createTestUser(id: 'user-a', username: 'alice', displayName: 'Alice');
    final userB = createTestUser(id: 'user-b', username: 'bob', displayName: 'Bob');
    final userC = createTestUser(id: 'user-c', username: 'charlie', displayName: 'Charlie');

    test('Equal trade: sending \$50, receiving \$50 -> 0% gap, Green tier (fair)', () {
      final pA = TradeParticipant(
        user: userA,
        sendingTotalValue: 50.0,
        receivingTotalValue: 50.0,
      );
      final pB = TradeParticipant(
        user: userB,
        sendingTotalValue: 50.0,
        receivingTotalValue: 50.0,
      );

      expect(pA.netDelta, equals(0.0));
      expect(pA.percentageDelta, equals(0.0));
      expect(pA.hasLargeValueGap, isFalse);

      final fairness = TradeFairnessResult.evaluate([pA, pB]);
      expect(fairness.tier, equals(TradeFairnessTier.fair));
      expect(fairness.maxGapPercent, equals(0.0));
      expect(fairness.maxDollarGap, equals(0.0));
      expect(fairness.isLargeGap, isFalse);
    });

    test('Minor gap: sending \$50, receiving \$46 -> \$4 gap, 8% gap, Green tier (fair)', () {
      final pA = TradeParticipant(
        user: userA,
        sendingTotalValue: 50.0,
        receivingTotalValue: 46.0,
      );
      final pB = TradeParticipant(
        user: userB,
        sendingTotalValue: 46.0,
        receivingTotalValue: 50.0,
      );

      expect(pA.netDelta, equals(-4.0));
      expect(pA.absoluteDollarGap, equals(4.0));
      // 4 / 50 * 100 = 8.0%
      expect(pA.percentageDelta, closeTo(8.0, 0.01));
      // < 15% and < $10 -> not large gap
      expect(pA.hasLargeValueGap, isFalse);

      final fairness = TradeFairnessResult.evaluate([pA, pB]);
      expect(fairness.tier, equals(TradeFairnessTier.fair));
      expect(fairness.maxGapPercent, closeTo(8.0, 0.01));
      expect(fairness.maxDollarGap, equals(4.0));
      expect(fairness.isLargeGap, isFalse);
    });

    test('Amber gap: sending \$50, receiving \$40 -> \$10 gap, 20% gap, Amber tier (moderate) & isLargeGap == true', () {
      final pA = TradeParticipant(
        user: userA,
        sendingTotalValue: 50.0,
        receivingTotalValue: 40.0,
      );
      final pB = TradeParticipant(
        user: userB,
        sendingTotalValue: 40.0,
        receivingTotalValue: 50.0,
      );

      expect(pA.netDelta, equals(-10.0));
      expect(pA.absoluteDollarGap, equals(10.0));
      // 10 / 50 * 100 = 20.0%
      expect(pA.percentageDelta, closeTo(20.0, 0.01));
      // >= 15% and >= $10.00 -> large gap triggers
      expect(pA.hasLargeValueGap, isTrue);

      final fairness = TradeFairnessResult.evaluate([pA, pB]);
      expect(fairness.tier, equals(TradeFairnessTier.moderate));
      expect(fairness.maxGapPercent, closeTo(20.0, 0.01));
      expect(fairness.maxDollarGap, equals(10.0));
      expect(fairness.isLargeGap, isTrue);
    });

    test('Red gap: sending \$100, receiving \$70 -> \$30 gap, 30% gap, Red tier (lopsided) & isLargeGap == true', () {
      final pA = TradeParticipant(
        user: userA,
        sendingTotalValue: 100.0,
        receivingTotalValue: 70.0,
      );
      final pB = TradeParticipant(
        user: userB,
        sendingTotalValue: 70.0,
        receivingTotalValue: 100.0,
      );

      expect(pA.netDelta, equals(-30.0));
      expect(pA.absoluteDollarGap, equals(30.0));
      // 30 / 100 * 100 = 30.0%
      expect(pA.percentageDelta, closeTo(30.0, 0.01));
      expect(pA.hasLargeValueGap, isTrue);

      final fairness = TradeFairnessResult.evaluate([pA, pB]);
      expect(fairness.tier, equals(TradeFairnessTier.lopsided));
      expect(fairness.maxGapPercent, closeTo(30.0, 0.01));
      expect(fairness.maxDollarGap, equals(30.0));
      expect(fairness.isLargeGap, isTrue);
    });

    test('3-Way Pod Trade: asymmetric routing A->B, B->C, C->A evaluation', () {
      // User A gives $100 to B, receives $90 from C -> net -$10 (10% gap)
      // User B gives $95 to C, receives $100 from A -> net +$5 (5% gap)
      // User C gives $90 to A, receives $95 from B -> net +$5 (5.26% gap)
      final pA = TradeParticipant(
        user: userA,
        sendingTotalValue: 100.0,
        receivingTotalValue: 90.0,
      );
      final pB = TradeParticipant(
        user: userB,
        sendingTotalValue: 95.0,
        receivingTotalValue: 100.0,
      );
      final pC = TradeParticipant(
        user: userC,
        sendingTotalValue: 90.0,
        receivingTotalValue: 95.0,
      );

      expect(pA.netDelta, equals(-10.0));
      expect(pA.percentageDelta, closeTo(10.0, 0.01));
      // pA dollar gap is $10.00 -> triggers large value gap safeguard
      expect(pA.hasLargeValueGap, isTrue);

      final fairness = TradeFairnessResult.evaluate([pA, pB, pC]);
      // Max percent is 10.0% -> Fair tier (<= 10%), but max dollar gap is $10.00 -> isLargeGap == true
      expect(fairness.tier, equals(TradeFairnessTier.fair));
      expect(fairness.maxDollarGap, equals(10.0));
      expect(fairness.isLargeGap, isTrue);
    });
  });
}
