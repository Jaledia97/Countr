import 'package:flutter_test/flutter_test.dart';
import 'package:countr/features/decks/domain/deck_token_extractor.dart';

void main() {
  group('DeckTokenExtractor - Physical Token Checklist Extraction', () {
    test('extracts single standard creature token (Construct)', () {
      final texts = [
        '{2}, {T}: Create a 0/0 colorless Construct artifact creature token with...',
      ];
      final tokens = DeckTokenExtractor.extractRequiredTokens(texts);
      expect(tokens, ['Construct']);
    });

    test('extracts predefined tokens (Treasure, Food, Clue, Blood, Map, Incubator, Role, Walker)', () {
      final texts = [
        'Whenever an opponent casts a spell, create a Treasure token.',
        'At the beginning of combat on your turn, create a Food token.',
        'Investigate. (Create a Clue token.)',
        'Whenever you discard a card, create a Blood token.',
        'Explore. (Create a Map token.)',
        'Incubate 2. (Create an Incubator token with two +1/+1 counters.)',
        'Create a Royal Role token attached to target creature.',
        'Whenever a creature dies, create a 2/2 black Walker creature token.',
      ];
      final tokens = DeckTokenExtractor.extractRequiredTokens(texts);
      expect(tokens, containsAll([
        'Blood',
        'Clue',
        'Food',
        'Incubator',
        'Map',
        'Role',
        'Treasure',
        'Walker',
      ]));
    });

    test('extracts tokens with word-based counts (two, three, X)', () {
      final texts = [
        'Create two 1/1 red Goblin creature tokens.',
        'Create three 2/2 black Zombie creature tokens with decayed.',
        'Create X 1/1 green Saproling creature tokens.',
      ];
      final tokens = DeckTokenExtractor.extractRequiredTokens(texts);
      expect(tokens, ['Goblin', 'Saproling', 'Zombie']);
    });

    test('deduplicates tokens across multiple cards and sorts alphabetically', () {
      final texts = [
        'Create a 1/1 black Vampire creature token with lifelink.',
        'Whenever Edgar Markov attacks, create a 1/1 black Vampire creature token.',
        'Create a Treasure token.',
        'Sacrifice a creature: Create a Treasure token.',
        'Create a 4/4 white Angel creature token with flying.',
      ];
      final tokens = DeckTokenExtractor.extractRequiredTokens(texts);
      expect(tokens, ['Angel', 'Treasure', 'Vampire']);
      expect(tokens.length, 3);
    });

    test('returns empty list for cards without token generation', () {
      final texts = [
        '{T}: Add {W}.',
        'Counter target spell.',
        'Whenever a creature attacks, it gets +1/+1 until end of turn.',
      ];
      final tokens = DeckTokenExtractor.extractRequiredTokens(texts);
      expect(tokens, isEmpty);
    });

    test('ignores non-creation uses of the word token', () {
      final texts = [
        'Whenever a token is put into a graveyard from the battlefield, draw a card.',
        'Target player sacrifices a token.',
      ];
      final tokens = DeckTokenExtractor.extractRequiredTokens(texts);
      expect(tokens, isEmpty);
    });

    test('handles empty or malformed inputs gracefully', () {
      expect(DeckTokenExtractor.extractRequiredTokens([]), isEmpty);
      expect(DeckTokenExtractor.extractRequiredTokens(['', '   ']), isEmpty);
    });

    test('extracts Oracle texts from single-faced and dual-faced card dynamicData', () {
      const singleFace = '{"oracle_text": "Create a Treasure token."}';
      final texts1 = DeckTokenExtractor.extractOracleTextsFromCardData(singleFace);
      expect(texts1, ['Create a Treasure token.']);

      const dualFace = '{"card_faces": [{"oracle_text": "Create a 1/1 white Human creature token."}, {"oracle_text": "Create a Food token."}]}';
      final texts2 = DeckTokenExtractor.extractOracleTextsFromCardData(dualFace);
      expect(texts2, ['Create a 1/1 white Human creature token.', 'Create a Food token.']);

      final tokens = DeckTokenExtractor.extractRequiredTokens([...texts1, ...texts2]);
      expect(tokens, ['Food', 'Human', 'Treasure']);
    });
  });
}
