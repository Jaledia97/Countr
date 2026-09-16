import 'package:flutter_test/flutter_test.dart';
import 'package:countr/features/vault/domain/mtg_keyword_glossary.dart';

void main() {
  group('MtgKeywordGlossary Dictionary Definition Lookups', () {
    const expectedKeywords = [
      'Vigilance',
      'Flying',
      'Trample',
      'Haste',
      'Lifelink',
      'Deathtouch',
      'First Strike',
      'Double Strike',
      'Reach',
      'Menace',
      'Ward',
      'Hexproof',
    ];

    test('dictionary contains all 12 required MTG mechanics', () {
      expect(MtgKeywordGlossary.dictionary.length, equals(12));
      for (final keyword in expectedKeywords) {
        expect(
          MtgKeywordGlossary.dictionary.containsKey(keyword),
          isTrue,
          reason: 'Missing definition for $keyword',
        );
        expect(
          MtgKeywordGlossary.dictionary[keyword],
          isNotNull,
        );
        expect(
          MtgKeywordGlossary.dictionary[keyword]!.trim().isNotEmpty,
          isTrue,
          reason: 'Empty definition for $keyword',
        );
      }
    });

    test('definitions are beginner-friendly and jargon-free', () {
      expect(MtgKeywordGlossary.dictionary['Flying'], contains('blocked'));
      expect(MtgKeywordGlossary.dictionary['Trample'], contains('Excess combat damage'));
      expect(MtgKeywordGlossary.dictionary['Vigilance'], contains('tap'));
      expect(MtgKeywordGlossary.dictionary['Lifelink'], contains('heals'));
      expect(MtgKeywordGlossary.dictionary['Deathtouch'], contains('lethal'));
      expect(MtgKeywordGlossary.dictionary['Reach'], contains('flying'));
      expect(MtgKeywordGlossary.dictionary['Menace'], contains('two or more'));
      expect(MtgKeywordGlossary.dictionary['Ward'], contains('ward cost'));
      expect(MtgKeywordGlossary.dictionary['Hexproof'], contains('targeted'));
    });

    test('getDefinition retrieves definition case-insensitively', () {
      expect(
        MtgKeywordGlossary.getDefinition('Flying'),
        equals(MtgKeywordGlossary.dictionary['Flying']),
      );
      expect(
        MtgKeywordGlossary.getDefinition('flying'),
        equals(MtgKeywordGlossary.dictionary['Flying']),
      );
      expect(
        MtgKeywordGlossary.getDefinition('DOUBLE STRIKE'),
        equals(MtgKeywordGlossary.dictionary['Double Strike']),
      );
      expect(
        MtgKeywordGlossary.getDefinition('UnknownMechanic'),
        isNull,
      );
    });
  });

  group('MtgKeywordGlossary Extraction from keywords list', () {
    test('extracts canonical keywords from list', () {
      final result = MtgKeywordGlossary.extractKeywords(
        keywords: ['Flying', 'Trample', 'Vigilance'],
      );
      expect(result, equals(['Flying', 'Trample', 'Vigilance']));
    });

    test('extracts keywords with case-insensitivity in list', () {
      final result = MtgKeywordGlossary.extractKeywords(
        keywords: ['flying', 'HASTE', 'deathtouch', 'first strike'],
      );
      expect(result, equals(['Flying', 'Haste', 'Deathtouch', 'First Strike']));
    });

    test('filters out unrecognized mechanics from keywords list', () {
      final result = MtgKeywordGlossary.extractKeywords(
        keywords: ['Flying', 'Banding', 'Storm', 'Cascade', 'Lifelink'],
      );
      expect(result, equals(['Flying', 'Lifelink']));
    });

    test('handles whitespace and null entries gracefully in keywords list', () {
      final result = MtgKeywordGlossary.extractKeywords(
        keywords: ['  Hexproof  ', null, '', '   ', 'Menace'],
      );
      expect(result, equals(['Hexproof', 'Menace']));
    });
  });

  group('MtgKeywordGlossary Extraction from oracleText regex parsing', () {
    test('extracts keywords from simple oracle text', () {
      final result = MtgKeywordGlossary.extractKeywords(
        oracleText: 'Flying\nWhen this creature enters the battlefield, draw a card.',
      );
      expect(result, equals(['Flying']));
    });

    test('extracts multiple comma-separated keywords in natural reading order', () {
      final result = MtgKeywordGlossary.extractKeywords(
        oracleText: 'Flying, trample, haste',
      );
      expect(result, equals(['Flying', 'Trample', 'Haste']));
    });

    test('extracts keywords embedded inside sentence text', () {
      final result = MtgKeywordGlossary.extractKeywords(
        oracleText: 'Target creature gains lifelink and vigilance until end of turn.',
      );
      expect(result, equals(['Lifelink', 'Vigilance']));
    });

    test('case-insensitively parses uppercase and lowercase mechanics in text', () {
      final result = MtgKeywordGlossary.extractKeywords(
        oracleText: 'DEATHTOUCH\nThis creature cannot be blocked.',
      );
      expect(result, equals(['Deathtouch']));
    });
  });

  group('Compound vs Sub-string Disambiguation', () {
    test('Double Strike does not falsely trigger First Strike', () {
      final result = MtgKeywordGlossary.extractKeywords(
        oracleText: 'Double strike\nWhenever this creature attacks, you gain 1 life.',
      );
      expect(result, equals(['Double Strike']));
      expect(result.contains('First Strike'), isFalse);
    });

    test('First Strike does not trigger Double Strike', () {
      final result = MtgKeywordGlossary.extractKeywords(
        oracleText: 'First strike\nWhen this creature dies, deal 2 damage.',
      );
      expect(result, equals(['First Strike']));
      expect(result.contains('Double Strike'), isFalse);
    });

    test('Text with both First strike and Double strike extracts both in order', () {
      final result = MtgKeywordGlossary.extractKeywords(
        oracleText: 'First strike\nIf this creature is enchanted, it has double strike instead.',
      );
      expect(result, equals(['First Strike', 'Double Strike']));
    });

    test('Ward with cost (e.g. Ward {2}, Ward {3}, Ward—Pay 3 life) extracts Ward', () {
      final result = MtgKeywordGlossary.extractKeywords(
        oracleText: 'Flying, ward {2}\nWhenever this creature attacks...',
      );
      expect(result, equals(['Flying', 'Ward']));
    });

    test('Words containing "ward" as a substring do not trigger Ward', () {
      final result = MtgKeywordGlossary.extractKeywords(
        oracleText: 'Return target card from your graveyard to the battlefield. Forward momentum rewards you.',
      );
      expect(result, isEmpty);
      expect(result.contains('Ward'), isFalse);
    });

    test('Reach does not match words containing "reach" as a substring', () {
      final nonMatches = MtgKeywordGlossary.extractKeywords(
        oracleText: 'Breach the Multiverse to preach unity with far-reaching outreach.',
      );
      expect(nonMatches, isEmpty);
      expect(nonMatches.contains('Reach'), isFalse);

      final match = MtgKeywordGlossary.extractKeywords(
        oracleText: 'Reach\nThis creature can block creatures with flying.',
      );
      expect(match, equals(['Reach', 'Flying']));
    });

    test('Haste and Menace word boundaries do not match substrings', () {
      final result = MtgKeywordGlossary.extractKeywords(
        oracleText: 'A chaste maiden was menaced by shadows, but hastened to the exit.',
      );
      expect(result, isEmpty);
    });
  });

  group('Empty and Null Inputs', () {
    test('null keywords and null oracleText returns empty list', () {
      final result = MtgKeywordGlossary.extractKeywords(
        keywords: null,
        oracleText: null,
      );
      expect(result, isEmpty);
    });

    test('empty keywords list and empty oracleText returns empty list', () {
      final result = MtgKeywordGlossary.extractKeywords(
        keywords: [],
        oracleText: '',
      );
      expect(result, isEmpty);
    });

    test('card with no recognized MTG keywords returns empty list', () {
      final result = MtgKeywordGlossary.extractKeywords(
        keywords: ['Pikachu', 'Electric'],
        oracleText: '{T}: Add {C}{C}. Draw a card.',
      );
      expect(result, isEmpty);
    });
  });

  group('Deduplication and Combined Extraction', () {
    test('deduplicates keywords present in both keywords list and oracleText', () {
      final result = MtgKeywordGlossary.extractKeywords(
        keywords: ['Flying', 'Trample'],
        oracleText: 'Flying\nTrample\nWhen this creature attacks, it deals 1 damage.',
      );
      expect(result, equals(['Flying', 'Trample']));
    });

    test('combines unique keywords from both sources without duplicates', () {
      final result = MtgKeywordGlossary.extractKeywords(
        keywords: ['Vigilance'],
        oracleText: 'Lifelink, reach',
      );
      expect(result, equals(['Vigilance', 'Lifelink', 'Reach']));
    });
  });
}
