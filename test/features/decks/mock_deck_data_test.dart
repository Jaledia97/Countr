import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/features/decks/data/mock_deck_data.dart';

void main() {
  group('MockDeckData Repository Tests', () {
    test('Canonical Edgar Markov deck contains exactly 100 cards', () {
      final items = MockDeckData.getDeckItems(MockDeckData.edgarMarkovDeckId);
      expect(items.isNotEmpty, isTrue);

      final totalQuantity = items.fold<int>(
        0,
        (sum, item) => sum + (item['deck_quantity'] as int? ?? 1),
      );
      expect(totalQuantity, equals(100));
    });

    test('Edgar Markov deck has Commander, Creatures, Spells, Artifacts & Enchantments, and Lands', () {
      final items = MockDeckData.getDeckItems('deck-edgar-markov');
      final zones = <String, int>{};
      for (final item in items) {
        final zone = item['board_zone'] as String;
        final qty = item['deck_quantity'] as int;
        zones[zone] = (zones[zone] ?? 0) + qty;
      }

      expect(zones['Commander'], equals(1));
      expect(zones['Creatures'], equals(32));
      expect(zones['Spells'], equals(18));
      expect(zones['Artifacts & Enchantments'], equals(14));
      expect(zones['Lands'], equals(35));
    });

    test('Commander card is Edgar Markov with mythic rarity, foil/etched finish, and graded status', () {
      final items = MockDeckData.getDeckItems('deck-edgar-markov');
      final commander = items.firstWhere((i) => i['board_zone'] == 'Commander');

      expect(commander['name'], equals('Edgar Markov'));
      expect(commander['is_graded'], equals(1));
      expect(commander['current_market_price'], greaterThan(100.0));

      final dynamicData = jsonDecode(commander['dynamic_data'] as String) as Map<String, dynamic>;
      expect(dynamicData['cmc'], equals(6));
      expect(dynamicData['mana_cost'], equals('{3}{R}{W}{B}'));
      expect(dynamicData['rarity'], equals('mythic'));
      expect(dynamicData['colors'], containsAll(['W', 'B', 'R']));
      expect(dynamicData['finishes'], containsAll(['foil', 'etched']));
    });

    test('All 100 cards contain valid Scryfall dynamic data with legalities and images', () {
      final items = MockDeckData.getDeckItems('deck-edgar-markov');
      for (final item in items) {
        expect(item['id'], isNotNull);
        expect(item['name'], isNotNull);
        expect(item['image_url'], isNotEmpty);
        expect(item['current_market_price'], isNonNegative);

        final dynStr = item['dynamic_data'] as String?;
        expect(dynStr, isNotNull);
        expect(dynStr!.isNotEmpty, isTrue);

        final data = jsonDecode(dynStr) as Map<String, dynamic>;
        expect(data['cmc'], isNotNull);
        expect(data['rarity'], isNotNull);
        expect(data['type_line'], isNotNull);
        expect(data['legalities'], isA<Map<String, dynamic>>());
        expect(data['legalities']['commander'], equals('legal'));
      }
    });

    test('Fast-Draw pool includes all main deck zones and excludes sideboard/maybeboard', () {
      final items = MockDeckData.getDeckItems('deck-edgar-markov');
      final pool = items.where((i) {
        final zone = (i['board_zone'] as String).toLowerCase();
        return zone != 'sideboard' && zone != 'maybeboard';
      }).toList();

      final totalPlaytestCards = pool.fold<int>(
        0,
        (sum, item) => sum + (item['deck_quantity'] as int),
      );
      expect(totalPlaytestCards, equals(100));
    });

    test('Contains special mana and layout cards (hybrid, Phyrexian, and DFC)', () {
      final items = MockDeckData.getDeckItems('deck-edgar-markov');

      // Hybrid mana card: Anguished Unmaking {1}{W/B}{B}
      final hybridCard = items.firstWhere((i) => i['name'] == 'Anguished Unmaking');
      final hybridDyn = jsonDecode(hybridCard['dynamic_data'] as String);
      expect(hybridDyn['mana_cost'], contains('{1}{W/B}{B}'));

      // Phyrexian mana card: Dismember {1}{B/P}{B/P}
      final phyrexianCard = items.firstWhere((i) => i['name'] == 'Dismember');
      final phyrexianDyn = jsonDecode(phyrexianCard['dynamic_data'] as String);
      expect(phyrexianDyn['mana_cost'], contains('{B/P}'));

      // DFC card: Bloodline Keeper
      final dfcCard = items.firstWhere((i) => (i['name'] as String).contains('Bloodline Keeper'));
      final dfcDyn = jsonDecode(dfcCard['dynamic_data'] as String);
      expect(dfcDyn['card_faces'], isA<List>());
      expect((dfcDyn['card_faces'] as List).length, equals(2));
    });

    test('Multi-format mock decks return format-specific card lists', () {
      final charizardItems = MockDeckData.getDeckItems('deck-charizard-ex');
      expect(charizardItems.any((i) => i['name'] == 'Charizard ex'), isTrue);

      final tronItems = MockDeckData.getDeckItems('deck-tron');
      expect(tronItems.any((i) => i['name'] == 'Karn Liberated'), isTrue);

      // Unknown ID defaults to Edgar Markov 100-card deck
      final fallbackItems = MockDeckData.getDeckItems('some-random-id-12345');
      expect(fallbackItems.length, equals(itemsCountForEdgar(fallbackItems)));
    });

    test('getMockVersions returns valid version history with active version', () {
      final versions = MockDeckData.getMockVersions('deck-edgar-markov');
      expect(versions.length, equals(3));
      expect(versions.where((v) => v.isActive).length, equals(1));
      expect(versions.first.versionNumber, equals(3));
      expect(versions.first.versionNote, isNotEmpty);
    });

    test('getMockMatchups returns strategic matchup records', () {
      final matchups = MockDeckData.getMockMatchups('deck-edgar-markov');
      expect(matchups.length, equals(3));
      for (final m in matchups) {
        expect(m.opponentArchetype, isNotEmpty);
        expect(m.notes, isNotNull);
        expect(m.swapInItemIds, isNotNull);
      }
    });

    test('getMockAnalytics computes real analytics from items', () {
      final analytics = MockDeckData.getMockAnalytics('deck-edgar-markov');
      expect(analytics.manaCurve.isNotEmpty, isTrue);
      expect(analytics.colorDevotion['W'], greaterThan(0));
      expect(analytics.colorDevotion['B'], greaterThan(0));
      expect(analytics.colorDevotion['R'], greaterThan(0));
      expect(analytics.blingPercentage, greaterThan(0.20));
      expect(analytics.colorProduction.isNotEmpty, isTrue);
    });
  });
}

int itemsCountForEdgar(List<Map<String, dynamic>> items) {
  return items.fold<int>(0, (sum, i) => sum + (i['deck_quantity'] as int? ?? 1));
}
