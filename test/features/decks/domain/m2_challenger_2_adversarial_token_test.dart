import 'package:flutter_test/flutter_test.dart';
import 'package:countr/features/decks/domain/deck_token_extractor.dart';

void main() {
  group('Empirical Challenger 2: Adversarial DeckTokenExtractor Tests', () {
    test('parses compound creation: "create a Food token and a Clue token"', () {
      final tokens = DeckTokenExtractor.extractRequiredTokens([
        'create a Food token and a Clue token',
      ]);
      expect(tokens, ['Clue', 'Food']);
    });

    test('parses word-based counts: "create two 1/1 red Goblin creature tokens", "create three 0/0 Construct tokens"', () {
      final tokens = DeckTokenExtractor.extractRequiredTokens([
        'create two 1/1 red Goblin creature tokens',
        'create three 0/0 Construct tokens',
      ]);
      expect(tokens, ['Construct', 'Goblin']);
    });

    test('parses additional number words: one, four, five, ten', () {
      final tokens = DeckTokenExtractor.extractRequiredTokens([
        'create one 1/1 white Soldier creature token',
        'create four 2/2 green Wolf creature tokens',
        'create five 1/1 black Bat creature tokens with flying',
        'create ten 1/1 blue Thopter artifact creature tokens',
      ]);
      expect(tokens, ['Bat', 'Soldier', 'Thopter', 'Wolf']);
    });

    test('parses complex mixed list with Treasure, Blood, Incubator, Role, Walker and deduplicates & sorts alphabetically', () {
      final texts = [
        'Whenever an opponent attacks, create a Treasure token.',
        'create two 1/1 red Goblin creature tokens',
        'create a Food token and a Clue token',
        'create three 0/0 Construct tokens',
        'create a Blood token',
        'create an Incubator token with two +1/+1 counters',
        'create a Monster Role token attached to target creature',
        'create a 2/2 black Walker creature token',
        'Whenever you cast a spell, create a Treasure token.', // duplicate
        'create a Food token', // duplicate
      ];
      final tokens = DeckTokenExtractor.extractRequiredTokens(texts);
      expect(tokens, [
        'Blood',
        'Clue',
        'Construct',
        'Food',
        'Goblin',
        'Incubator',
        'Role',
        'Treasure',
        'Walker',
      ]);
    });

    test('handles case insensitivity, verbs (creates, creating), and ALL-CAPS', () {
      final texts = [
        'He creates a Treasure token.',
        'Whenever you attack, creating a 1/1 white Soldier creature token.',
        'CREATE AN INCUBATOR TOKEN.',
      ];
      final tokens = DeckTokenExtractor.extractRequiredTokens(texts);
      expect(tokens, ['Incubator', 'Soldier', 'Treasure']);
    });

    test('rejects non-creation token actions', () {
      final texts = [
        'Whenever a token is put into a graveyard, draw a card.',
        'Sacrifice two tokens.',
        'Destroy all tokens.',
        'Create a copy of target creature, except it\'s not a token.',
      ];
      final tokens = DeckTokenExtractor.extractRequiredTokens(texts);
      expect(tokens, isEmpty);
    });

    test('extracts from DFC dynamic JSON payloads safely', () {
      const dfcJson = '''
      {
        "card_faces": [
          {"name": "Front", "oracle_text": "Create a Food token."},
          {"name": "Back", "oracle_text": "Create a Clue token."}
        ]
      }
      ''';
      final texts = DeckTokenExtractor.extractOracleTextsFromCardData(dfcJson);
      final tokens = DeckTokenExtractor.extractRequiredTokens(texts);
      expect(tokens, ['Clue', 'Food']);
    });

    test('handles empty, null-like, and whitespace inputs gracefully', () {
      expect(DeckTokenExtractor.extractRequiredTokens([]), isEmpty);
      expect(DeckTokenExtractor.extractRequiredTokens(['', '   ', '\n\t']), isEmpty);
      expect(DeckTokenExtractor.extractOracleTextsFromCardData(null), isEmpty);
      expect(DeckTokenExtractor.extractOracleTextsFromCardData(''), isEmpty);
      expect(DeckTokenExtractor.extractOracleTextsFromCardData('invalid json {{{'), isEmpty);
      expect(DeckTokenExtractor.extractOracleTextsFromCardData(12345), isEmpty);
    });
  });
}
