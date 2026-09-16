import 'package:flutter_test/flutter_test.dart';
import 'package:countr/features/vault/domain/mtg_keyword_glossary.dart';

void main() {
  group('Challenger M4-1: Substring Collision Empirical Tests', () {
    test('rejects words with "reach" as prefix, suffix, or inner substring', () {
      final nonCollidingStrings = [
        'outreach',
        'breach',
        'preach',
        'overreach',
        'reachout',
        'far-reaching',
        'impeach',
        'bleach',
      ];

      for (final candidate in nonCollidingStrings) {
        final result = MtgKeywordGlossary.extractKeywords(oracleText: candidate);
        expect(
          result.contains('Reach'),
          isFalse,
          reason: 'Word "$candidate" falsely triggered Reach keyword extraction',
        );
      }
    });

    test('rejects words with "ward" as substring', () {
      final nonCollidingStrings = [
        'graveyard',
        'reward',
        'rewards',
        'rewarding',
        'forward',
        'forwards',
        'steward',
        'stewardship',
        'skyward',
        'downward',
        'upward',
        'backward',
        'awkward',
        'coward',
        'towards',
        'warden',
        'wardens',
        'sward',
        'swarthy',
        'award',
        'awards',
      ];

      for (final candidate in nonCollidingStrings) {
        final result = MtgKeywordGlossary.extractKeywords(oracleText: candidate);
        expect(
          result.contains('Ward'),
          isFalse,
          reason: 'Word "$candidate" falsely triggered Ward keyword extraction',
        );
      }
    });

    test('rejects words with "haste" as substring or inflection', () {
      final nonCollidingStrings = [
        'hasty',
        'hastily',
        'chaste',
        'chastity',
        'chastened',
        'hastened',
        'hastening',
      ];

      for (final candidate in nonCollidingStrings) {
        final result = MtgKeywordGlossary.extractKeywords(oracleText: candidate);
        expect(
          result.contains('Haste'),
          isFalse,
          reason: 'Word "$candidate" falsely triggered Haste keyword extraction',
        );
      }
    });

    test('rejects words with "trample" inflections', () {
      final nonCollidingStrings = [
        'trampled',
        'tramples',
        'trampling',
      ];

      for (final candidate in nonCollidingStrings) {
        final result = MtgKeywordGlossary.extractKeywords(oracleText: candidate);
        expect(
          result.contains('Trample'),
          isFalse,
          reason: 'Word "$candidate" falsely triggered Trample keyword extraction',
        );
      }
    });

    test('rejects other keyword inflections and substrings', () {
      final inflectionMap = {
        'Vigilance': ['vigilant', 'vigilantly', 'vigil'],
        'Flying': ['fly', 'flier', 'fliers', 'flyingly'],
        'Lifelink': ['lifelinker', 'lifelinked', 'life', 'link'],
        'Deathtouch': ['deathtoucher', 'death', 'touch'],
        'First Strike': ['strike', 'first', 'unstriking'],
        'Double Strike': ['double', 'strike', 'doubling'],
        'Menace': ['menaced', 'menacing', 'menacingly'],
        'Hexproof': ['hexproofed', 'hex', 'proof'],
      };

      for (final entry in inflectionMap.entries) {
        for (final word in entry.value) {
          final result = MtgKeywordGlossary.extractKeywords(oracleText: word);
          expect(
            result.contains(entry.key),
            isFalse,
            reason: 'Word "$word" falsely triggered ${entry.key} keyword extraction',
          );
        }
      }
    });

    test('composite sentence with multiple substring collisions yields empty list', () {
      const sentence =
          'Return target card from your graveyard to forward position. Outreach into the breach with hasty momentum rewards a vigilant steward menaced by shadows.';
      final result = MtgKeywordGlossary.extractKeywords(oracleText: sentence);
      expect(result, isEmpty);
    });
  });

  group('Challenger M4-1: Complex Oracle Text with Activated/Triggered Abilities', () {
    test('extracts lifelink and hexproof from activated ability granting them', () {
      const oracle =
          'Pay {1}: Target creature gains lifelink and hexproof until end of turn.';
      final result = MtgKeywordGlossary.extractKeywords(oracleText: oracle);
      expect(result, equals(['Lifelink', 'Hexproof']));
    });

    test('extracts mechanics from modal choices with bullet points', () {
      const oracle =
          'Choose one —\n• Target creature gains vigilance until end of turn.\n• Target creature gains menace and deathtouch until end of turn.';
      final result = MtgKeywordGlossary.extractKeywords(oracleText: oracle);
      expect(result, equals(['Vigilance', 'Menace', 'Deathtouch']));
    });

    test('extracts mechanics from triggered abilities with conditional costs', () {
      const oracle =
          'Whenever this creature attacks, you may pay {R}{W}. When you do, it gains first strike and trample until end of turn.';
      final result = MtgKeywordGlossary.extractKeywords(oracleText: oracle);
      expect(result, equals(['First Strike', 'Trample']));
    });

    test('extracts mechanics from complex multi-ability planeswalker loyalty text', () {
      const oracle =
          '+1: Up to one target creature gains flying and haste until end of turn.\n'
          '-2: Create a 3/3 green Beast creature token with trample.\n'
          '-7: You get an emblem with "Creatures you control have double strike and reach."';
      final result = MtgKeywordGlossary.extractKeywords(oracleText: oracle);
      expect(result, equals(['Flying', 'Haste', 'Trample', 'Double Strike', 'Reach']));
    });

    test('extracts mechanics from non-English punctuation like curly quotes and dashes', () {
      const oracle =
          '“Whenever a creature attacks, it gains ‘haste’ and ‘lifelink’ until end of turn.” — Akroma';
      final result = MtgKeywordGlossary.extractKeywords(oracleText: oracle);
      expect(result, equals(['Haste', 'Lifelink']));
    });
  });

  group('Challenger M4-1: Case Sensitivity Stress Tests', () {
    test('extracts UPPERCASE mechanics', () {
      const oracle = 'HASTE, FLYING, DEATHTOUCH';
      final result = MtgKeywordGlossary.extractKeywords(oracleText: oracle);
      expect(result, equals(['Haste', 'Flying', 'Deathtouch']));
    });

    test('extracts lowercase mechanics', () {
      const oracle = 'haste, flying, deathtouch';
      final result = MtgKeywordGlossary.extractKeywords(oracleText: oracle);
      expect(result, equals(['Haste', 'Flying', 'Deathtouch']));
    });

    test('extracts mixed mOdE cAsInG mechanics', () {
      const oracle = 'DeAtHtOuCh, vIgIlAnCe, tRaMpLe, DoUbLe StRiKe';
      final result = MtgKeywordGlossary.extractKeywords(oracleText: oracle);
      expect(result, equals(['Deathtouch', 'Vigilance', 'Trample', 'Double Strike']));
    });

    test('keywords list handles extreme casing and leading/trailing whitespace', () {
      final result = MtgKeywordGlossary.extractKeywords(
        keywords: ['  HASTE  ', 'fLyInG', '   DeAtHtOuCh   ', 'HEXPROOF'],
      );
      expect(result, equals(['Haste', 'Flying', 'Deathtouch', 'Hexproof']));
    });
  });

  group('Challenger M4-1: Trailing Punctuation & Parameterized Mechanics', () {
    test('extracts Ward {2}, vigilance, and double strike with trailing period', () {
      const oracle = 'Ward {2}, vigilance, and double strike.';
      final result = MtgKeywordGlossary.extractKeywords(oracleText: oracle);
      expect(result, equals(['Ward', 'Vigilance', 'Double Strike']));
    });

    test('extracts Ward with various cost formats', () {
      final wardFormats = [
        'Ward {1}',
        'Ward {2}',
        'Ward {3}',
        'Ward {X}',
        'Ward—Pay 2 life.',
        'Ward—Discard a card.',
        'Ward — Pay 3 life.',
        'Ward: 2 mana.',
      ];

      for (final format in wardFormats) {
        final result = MtgKeywordGlossary.extractKeywords(oracleText: format);
        expect(
          result.contains('Ward'),
          isTrue,
          reason: 'Failed to extract Ward from "$format"',
        );
      }
    });

    test('handles extreme trailing punctuation marks', () {
      const oracle =
          'Flying! Trample? Haste... Vigilance: Lifelink; Deathtouch/Reach (Hexproof) [Menace] {Ward {1}} "Double Strike" \'First Strike\'';
      final result = MtgKeywordGlossary.extractKeywords(oracleText: oracle);
      expect(result.length, equals(12));
      expect(result, containsAll(MtgKeywordGlossary.dictionary.keys));
    });
  });

  group('Challenger M4-1: Deduplication, Ordering, and Boundary Cases', () {
    test('preserves first-occurrence order from oracleText', () {
      const oracle = 'Menace, trample, flying, vigilance';
      final result = MtgKeywordGlossary.extractKeywords(oracleText: oracle);
      expect(result, equals(['Menace', 'Trample', 'Flying', 'Vigilance']));
    });

    test('repeated keywords in oracleText are deduplicated', () {
      const oracle =
          'Flying\nWhenever a creature with flying attacks, target creature gains flying until end of turn.';
      final result = MtgKeywordGlossary.extractKeywords(oracleText: oracle);
      expect(result, equals(['Flying']));
    });

    test('keywords list and oracleText merge without duplicate entries', () {
      final result = MtgKeywordGlossary.extractKeywords(
        keywords: ['Flying', 'Vigilance'],
        oracleText: 'Whenever a creature with flying or vigilance attacks, it gains trample.',
      );
      expect(result, equals(['Flying', 'Vigilance', 'Trample']));
    });

    test('handles null and empty values gracefully', () {
      expect(MtgKeywordGlossary.extractKeywords(), isEmpty);
      expect(MtgKeywordGlossary.extractKeywords(keywords: null, oracleText: null), isEmpty);
      expect(MtgKeywordGlossary.extractKeywords(keywords: [], oracleText: ''), isEmpty);
      expect(MtgKeywordGlossary.extractKeywords(keywords: [null, ''], oracleText: '   '), isEmpty);
    });

    test('handles non-string dynamic elements in keywords list gracefully', () {
      final result = MtgKeywordGlossary.extractKeywords(
        keywords: [123, true, {'key': 'Flying'}, ['Haste'], 'Lifelink'],
      );
      // 'Lifelink' is string and matches.
      expect(result.contains('Lifelink'), isTrue);
    });
  });
}
