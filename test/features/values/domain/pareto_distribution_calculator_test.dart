import 'package:flutter_test/flutter_test.dart';
import 'package:countr/features/values/domain/pareto_analytics_calculator.dart';

void main() {
  group('ParetoDistributionCalculator Unit Tests', () {
    test('TC-PARETO-01: calculates concentration and sorts descending by line value', () {
      final cards = [
        const ParetoCardInput(id: '1', name: 'Sol Ring', unitPrice: 2.0, quantity: 1),
        const ParetoCardInput(id: '2', name: 'Black Lotus', unitPrice: 1000.0, quantity: 1),
        const ParetoCardInput(id: '3', name: 'Mox Sapphire', unitPrice: 500.0, quantity: 1),
        const ParetoCardInput(id: '4', name: 'Lightning Bolt', unitPrice: 1.0, quantity: 4),
        const ParetoCardInput(id: '5', name: 'Counterspell', unitPrice: 1.5, quantity: 2),
      ];

      final result = ParetoDistributionCalculator.calculate(cards: cards, targetK: 3);

      // Total deck value = 2 + 1000 + 500 + 4 + 3 = 1509.0
      expect(result.totalDeckValue, closeTo(1509.0, 0.01));
      expect(result.topCards.length, equals(3));
      expect(result.topCards[0].name, equals('Black Lotus'));
      expect(result.topCards[0].lineValue, equals(1000.0));
      expect(result.topCards[1].name, equals('Mox Sapphire'));
      expect(result.topCards[1].lineValue, equals(500.0));
      expect(result.topCards[2].name, equals('Lightning Bolt'));
      expect(result.topCards[2].lineValue, equals(4.0));

      // Top 3 value = 1000 + 500 + 4 = 1504.0
      // 1504.0 / 1509.0 * 100 = 99.668...%
      expect(result.concentrationPercentage, closeTo(99.67, 0.05));
    });

    test('TC-PARETO-02: deterministic tie-breaking by card name ascending on equal line values', () {
      final cards = [
        const ParetoCardInput(id: '1', name: 'Zendikar Resurgent', unitPrice: 10.0, quantity: 1),
        const ParetoCardInput(id: '2', name: 'Avacyn, Angel of Hope', unitPrice: 10.0, quantity: 1),
        const ParetoCardInput(id: '3', name: 'Mana Vault', unitPrice: 10.0, quantity: 1),
      ];

      final result = ParetoDistributionCalculator.calculate(cards: cards, targetK: 3);

      expect(result.topCards[0].name, equals('Avacyn, Angel of Hope'));
      expect(result.topCards[1].name, equals('Mana Vault'));
      expect(result.topCards[2].name, equals('Zendikar Resurgent'));
      expect(result.concentrationPercentage, equals(100.0));
    });

    test('TC-PARETO-03: single item deck handles 100% concentration cleanly', () {
      final cards = [
        const ParetoCardInput(id: '1', name: 'Mox Diamond', unitPrice: 650.0, quantity: 1),
      ];

      final result = ParetoDistributionCalculator.calculate(cards: cards, targetK: 5);

      expect(result.totalDeckValue, equals(650.0));
      expect(result.topCards.length, equals(1));
      expect(result.concentrationPercentage, equals(100.0));
    });

    test('TC-PARETO-04: empty item list handles zero total value without NaN or division by zero', () {
      final result = ParetoDistributionCalculator.calculate(cards: [], targetK: 5);

      expect(result.totalDeckValue, equals(0.0));
      expect(result.topCards, isEmpty);
      expect(result.concentrationPercentage, equals(0.0));
    });

    test('TC-PARETO-05: deck with all zero value items returns 0.0% concentration safely', () {
      final cards = [
        const ParetoCardInput(id: '1', name: 'Basic Island', unitPrice: 0.0, quantity: 20),
        const ParetoCardInput(id: '2', name: 'Basic Mountain', unitPrice: 0.0, quantity: 20),
      ];

      final result = ParetoDistributionCalculator.calculate(cards: cards, targetK: 5);

      expect(result.totalDeckValue, equals(0.0));
      expect(result.concentrationPercentage, equals(0.0));
      expect(result.concentrationPercentage.isNaN, isFalse);
      expect(result.concentrationPercentage.isInfinite, isFalse);
    });

    test('TC-PARETO-06: items with zero quantities default to quantity 1 safely', () {
      final cards = [
        const ParetoCardInput(id: '1', name: 'Valid Card', unitPrice: 50.0, quantity: 1),
        const ParetoCardInput(id: '2', name: 'Fallback Qty', unitPrice: 100.0, quantity: 0),
      ];

      final result = ParetoDistributionCalculator.calculate(cards: cards, targetK: 3);

      expect(result.topCards.length, equals(2));
      expect(result.topCards[0].name, equals('Fallback Qty'));
      expect(result.topCards[0].lineValue, equals(100.0));
    });

    test('TC-PARETO-07: ParetoAnalyticsCalculator computeConcentration & headline', () {
      final lineValues = [50000.0, 10000.0, 800.0, 100.0];

      final concentration = ParetoAnalyticsCalculator.computeConcentration(
        itemLineValues: lineValues,
        topK: 2,
      );

      // Total = 50000 + 10000 + 800 + 100 = 60900.0
      // Top 2 = 60000.0
      // 60000 / 60900 * 100 = 98.52%
      expect(concentration, closeTo(98.52, 0.05));

      final headline = ParetoAnalyticsCalculator.generateHeadline(concentration, topK: 2);
      expect(headline, contains('98.5%'));
      expect(headline, contains('The top 2 cards represent'));
    });
  });
}
