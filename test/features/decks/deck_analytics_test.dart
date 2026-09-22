import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/decks/data/mock_deck_data.dart';

void main() {
  group('DeckAnalytics Provider & Calculation Tests', () {
    test('Calculates genuine Mana Curve, Devotion, and Bling for Edgar Markov', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Await stream provider to emit
      await container.read(deckItemsProvider(MockDeckData.edgarMarkovDeckId).future);
      final asyncAnalytics = container.read(deckAnalyticsProvider(MockDeckData.edgarMarkovDeckId));
      expect(asyncAnalytics.hasValue, isTrue);

      final analytics = asyncAnalytics.value!;
      expect(analytics.manaCurve.isNotEmpty, isTrue);
      // Lands at CMC 0
      expect(analytics.manaCurve[0], equals(35));
      // Non-land spells distributed across 1 to 9
      expect(analytics.manaCurve[1], greaterThan(0));
      expect(analytics.manaCurve[2], greaterThan(0));
      expect(analytics.manaCurve[3], greaterThan(0));
      expect(analytics.manaCurve[4], greaterThan(0));
      expect(analytics.manaCurve[6], greaterThan(0)); // Edgar Markov

      // Mardu Color Devotion
      expect(analytics.colorDevotion['W'], greaterThan(10));
      expect(analytics.colorDevotion['B'], greaterThan(25));
      expect(analytics.colorDevotion['R'], greaterThan(5));
      expect(analytics.colorDevotion['G'], isNull);

      // Bling percentage
      expect(analytics.blingPercentage, greaterThan(0.20));
      expect(analytics.blingPercentage, lessThan(0.60));

      // Color production from lands and rocks
      expect(analytics.colorProduction['W'], greaterThan(0));
      expect(analytics.colorProduction['B'], greaterThan(0));
      expect(analytics.colorProduction['R'], greaterThan(0));
    });

    test('Correctly parses hybrid mana symbols ({W/U}, {B/R}) into respective color devotions', () {
      final items = [
        {
          'deck_quantity': 2,
          'is_graded': 0,
          'dynamic_data': jsonEncode({
            'cmc': 2,
            'mana_cost': '{W/U}{B/R}',
            'finishes': ['nonfoil'],
          }),
        },
      ];

      final analytics = MockDeckData.computeAnalyticsFromItems(items);
      // 2 copies with {W/U} -> +2 W, +2 U
      expect(analytics.colorDevotion['W'], equals(2));
      expect(analytics.colorDevotion['U'], equals(2));
      // 2 copies with {B/R} -> +2 B, +2 R
      expect(analytics.colorDevotion['B'], equals(2));
      expect(analytics.colorDevotion['R'], equals(2));
    });

    test('Correctly parses 2-brid and Phyrexian mana symbols ({2/W}, {B/P}, {G/P})', () {
      final items = [
        {
          'deck_quantity': 1,
          'is_graded': 0,
          'dynamic_data': jsonEncode({
            'cmc': 3,
            'mana_cost': '{2/W}{B/P}{G/P}',
            'finishes': ['nonfoil'],
          }),
        },
      ];

      final analytics = MockDeckData.computeAnalyticsFromItems(items);
      expect(analytics.colorDevotion['W'], equals(1));
      expect(analytics.colorDevotion['B'], equals(1));
      expect(analytics.colorDevotion['G'], equals(1));
      expect(analytics.colorDevotion['P'], isNull);
      expect(analytics.colorDevotion['2'], isNull);
    });

    test('Parses DFCs and adventure cards from card_faces when top-level mana_cost is empty', () {
      final items = [
        {
          'deck_quantity': 1,
          'is_graded': 0,
          'dynamic_data': jsonEncode({
            'cmc': 3,
            'mana_cost': '',
            'card_faces': [
              {
                'name': 'Murderous Rider',
                'mana_cost': '{1}{B}{B}',
              },
              {
                'name': 'Swift End',
                'mana_cost': '{1}{B}{B}',
              },
            ],
            'finishes': ['nonfoil'],
          }),
        },
      ];

      final analytics = MockDeckData.computeAnalyticsFromItems(items);
      // Both faces contribute {B} pips
      expect(analytics.colorDevotion['B'], equals(4));
    });

    test('Accurately computes bling percentage across foils, etched, promos, graded, and altered cards', () {
      final items = [
        // Card 1: Normal nonfoil (no bling)
        {
          'deck_quantity': 1,
          'is_graded': 0,
          'is_altered': 0,
          'is_signed': 0,
          'dynamic_data': jsonEncode({
            'cmc': 1,
            'finishes': ['nonfoil'],
          }),
        },
        // Card 2: Foil finish (bling)
        {
          'deck_quantity': 1,
          'is_graded': 0,
          'dynamic_data': jsonEncode({
            'cmc': 2,
            'finishes': ['foil'],
          }),
        },
        // Card 3: Etched finish (bling)
        {
          'deck_quantity': 1,
          'is_graded': 0,
          'dynamic_data': jsonEncode({
            'cmc': 3,
            'finishes': ['etched'],
          }),
        },
        // Card 4: Graded card (bling)
        {
          'deck_quantity': 1,
          'is_graded': 1,
          'dynamic_data': jsonEncode({
            'cmc': 4,
            'finishes': ['nonfoil'],
          }),
        },
        // Card 5: Altered card (bling)
        {
          'deck_quantity': 1,
          'is_graded': 0,
          'is_altered': 1,
          'dynamic_data': jsonEncode({
            'cmc': 5,
            'finishes': ['nonfoil'],
          }),
        },
      ];

      final analytics = MockDeckData.computeAnalyticsFromItems(items);
      // 4 out of 5 cards have bling = 80.0%
      expect(analytics.blingPercentage, closeTo(0.80, 0.001));
    });

    test('Handles empty item list gracefully with 0.0 bling and empty collections', () {
      final analytics = MockDeckData.computeAnalyticsFromItems([]);
      expect(analytics.manaCurve.isEmpty, isTrue);
      expect(analytics.colorDevotion.isEmpty, isTrue);
      expect(analytics.colorProduction.isEmpty, isTrue);
      expect(analytics.blingPercentage, equals(0.0));
    });
  });
}
