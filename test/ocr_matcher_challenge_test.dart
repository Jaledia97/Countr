import 'dart:convert';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/scanner/domain/ocr_heuristic_matcher.dart';

void main() {
  group('Empirical Challenge: passesMultiFactorGate Adversarial Stress Test', () {
    // -------------------------------------------------------------------------
    // 1. Single 4-character words alone (must ALL reject)
    // -------------------------------------------------------------------------
    test('rejects single 4-character words alone without secondary factors', () {
      const fourCharWords = [
        'Ring',
        'Fire',
        'Tomb',
        'Dark',
        'Pact',
        'Bolt',
        'Bird',
        'Bear',
      ];

      for (final word in fourCharWords) {
        // Plain word
        expect(
          OcrHeuristicMatcher.passesMultiFactorGate(
            cardName: word,
            ocrLines: [word],
          ),
          isFalse,
          reason: 'Expected single word "$word" alone to be rejected',
        );

        // Plain word against a composite card name (e.g. "Ring" vs "Sol Ring")
        expect(
          OcrHeuristicMatcher.passesMultiFactorGate(
            cardName: 'Sol $word',
            ocrLines: [word],
          ),
          isFalse,
          reason: 'Expected single word "$word" alone against composite name to be rejected',
        );

        // With surrounding whitespace
        expect(
          OcrHeuristicMatcher.passesMultiFactorGate(
            cardName: word,
            ocrLines: ['  $word  '],
          ),
          isFalse,
          reason: 'Expected whitespace-padded word "$word" to be rejected',
        );

        // With punctuation / symbols
        expect(
          OcrHeuristicMatcher.passesMultiFactorGate(
            cardName: word,
            ocrLines: ['[$word]!'],
          ),
          isFalse,
          reason: 'Expected punctuation-wrapped word "$word" to be rejected',
        );

        // Lowercase and uppercase variants
        expect(
          OcrHeuristicMatcher.passesMultiFactorGate(
            cardName: word,
            ocrLines: [word.toLowerCase()],
          ),
          isFalse,
        );
        expect(
          OcrHeuristicMatcher.passesMultiFactorGate(
            cardName: word,
            ocrLines: [word.toUpperCase()],
          ),
          isFalse,
        );
      }
    });

    // -------------------------------------------------------------------------
    // 2. 3-letter words and short tokens alone (must ALL reject)
    // -------------------------------------------------------------------------
    test('rejects 3-letter words and short tokens alone without secondary factors', () {
      const shortWords = [
        'Fog',
        'Ice',
        'Air',
        'Web',
        'End',
        'Ox',
        'Go',
        'Up',
        'In',
        'A',
      ];

      for (final word in shortWords) {
        expect(
          OcrHeuristicMatcher.passesMultiFactorGate(
            cardName: word,
            ocrLines: [word],
          ),
          isFalse,
          reason: 'Expected short word "$word" alone to be rejected',
        );

        expect(
          OcrHeuristicMatcher.passesMultiFactorGate(
            cardName: word,
            ocrLines: ['   $word   \n'],
          ),
          isFalse,
        );
      }

      // Empty inputs
      expect(
        OcrHeuristicMatcher.passesMultiFactorGate(
          cardName: 'Sol Ring',
          ocrLines: [],
        ),
        isFalse,
      );

      expect(
        OcrHeuristicMatcher.passesMultiFactorGate(
          cardName: 'Sol Ring',
          ocrLines: ['', '   ', '\t\n'],
        ),
        isFalse,
      );

      expect(
        OcrHeuristicMatcher.passesMultiFactorGate(
          cardName: '',
          ocrLines: ['Sol Ring', '400'],
        ),
        isFalse,
      );
    });

    // -------------------------------------------------------------------------
    // 3. Nonsense OCR lines with numbers that do NOT match collector numbers
    // -------------------------------------------------------------------------
    test('rejects nonsense OCR lines with numbers not matching collector number', () {
      const card = 'Sol Ring';
      const expectedCollector = '400';
      const expectedSet = 'CMM';
      const expectedType = 'Artifact';

      final nonMatchingOcrLinesScenarios = [
        // Different number
        ['Sol Ring', '123'],
        ['Sol Ring', '9999'],
        ['Sol Ring', '0399'],
        ['Sol Ring', '401'],
        ['Sol Ring', '40'],
        ['Sol Ring', '4000'],
        // Fractions not matching
        ['Sol Ring', '001/250'],
        ['Sol Ring', '100/100'],
        // Hashes not matching
        ['Sol Ring', '#025'],
        ['Sol Ring', '#123'],
        // Set-dashes not matching
        ['Sol Ring', 'SV01-050'],
        ['Sol Ring', 'LTR-001'],
        // Creature stats / combat text
        ['Sol Ring', 'Attack 50', 'Defense 80'],
        ['Sol Ring', '10/10'],
        ['Sol Ring', '3/3'],
        // Dates, prices, phone numbers
        ['Sol Ring', '2024-09-16'],
        ['Sol Ring', 'Phone 555-1234'],
        ['Sol Ring', r'Price $4.99'],
        ['Sol Ring', 'Quantity: 4'],
        // Random alphanumeric noise lines
        ['Sol Ring', 'Random Fluff Text', 'Illus. Mark Poole'],
      ];

      for (final lines in nonMatchingOcrLinesScenarios) {
        final result = OcrHeuristicMatcher.passesMultiFactorGate(
          cardName: card,
          ocrLines: lines,
          collectorNumber: expectedCollector,
          setCode: expectedSet,
          typeLine: expectedType,
        );

        expect(
          result,
          isFalse,
          reason: 'Expected OCR lines $lines to be rejected for Sol Ring ($expectedCollector, $expectedSet, $expectedType)',
        );
      }
    });

    // -------------------------------------------------------------------------
    // 4. Genuine 2-data-point matches: Name + Collector Number
    // -------------------------------------------------------------------------
    test('accepts genuine 2-data-point matches: Name + Collector Number', () {
      // Sol Ring: collector 400
      expect(
        OcrHeuristicMatcher.passesMultiFactorGate(
          cardName: 'Sol Ring',
          ocrLines: ['Sol Ring', '400'],
          collectorNumber: '400',
        ),
        isTrue,
      );

      // Padded zero in card data (e.g. 025 vs 25)
      expect(
        OcrHeuristicMatcher.passesMultiFactorGate(
          cardName: 'Pikachu',
          ocrLines: ['Pikachu', '25'],
          collectorNumber: '025',
        ),
        isTrue,
      );

      expect(
        OcrHeuristicMatcher.passesMultiFactorGate(
          cardName: 'Sol Ring',
          ocrLines: ['Sol Ring', '400'],
          collectorNumber: '0400',
        ),
        isTrue,
      );

      // Fraction format (MTG style: 232/250)
      expect(
        OcrHeuristicMatcher.passesMultiFactorGate(
          cardName: 'Black Lotus',
          ocrLines: ['Black Lotus', '232/250'],
          collectorNumber: '232',
        ),
        isTrue,
      );

      // Hash format (#025)
      expect(
        OcrHeuristicMatcher.passesMultiFactorGate(
          cardName: 'Pikachu',
          ocrLines: ['Pikachu', '#025'],
          collectorNumber: '25',
        ),
        isTrue,
      );

      // "No." format (No. 25)
      expect(
        OcrHeuristicMatcher.passesMultiFactorGate(
          cardName: 'Pikachu',
          ocrLines: ['Pikachu', 'No. 25'],
          collectorNumber: '25',
        ),
        isTrue,
      );

      // Set-dash format (SV03-125)
      expect(
        OcrHeuristicMatcher.passesMultiFactorGate(
          cardName: 'Charizard ex',
          ocrLines: ['Charizard ex', 'SV03-125'],
          collectorNumber: '125',
        ),
        isTrue,
      );

      // Collector number embedded in bottom card metadata line
      expect(
        OcrHeuristicMatcher.passesMultiFactorGate(
          cardName: 'Sol Ring',
          ocrLines: ['Sol Ring', '400 CMM EN Chris Rahn'],
          collectorNumber: '400',
        ),
        isTrue,
      );
    });

    // -------------------------------------------------------------------------
    // 5. Genuine 2-data-point matches: Name + Card Type
    // -------------------------------------------------------------------------
    test('accepts genuine 2-data-point matches: Name + Card Type across all 7 canonical types', () {
      final typeTestCases = [
        ('Lightning Bolt', 'Instant', 'Instant'),
        ('Demonic Tutor', 'Sorcery', 'Sorcery'),
        ('Birds of Paradise', 'Creature', 'Creature — Bird'),
        ('Mox Diamond', 'Artifact', 'Artifact'),
        ('Rhystic Study', 'Enchantment', 'Enchantment'),
        ('Ancient Tomb', 'Land', 'Land'),
        ('Jace, the Mind Sculptor', 'Planeswalker', 'Legendary Planeswalker — Jace'),
      ];

      for (final (name, keyword, fullType) in typeTestCases) {
        // Direct keyword line
        expect(
          OcrHeuristicMatcher.passesMultiFactorGate(
            cardName: name,
            ocrLines: [name, keyword],
            typeLine: fullType,
          ),
          isTrue,
          reason: 'Expected $name + $keyword to pass',
        );

        // Full type line in OCR
        expect(
          OcrHeuristicMatcher.passesMultiFactorGate(
            cardName: name,
            ocrLines: [name, fullType],
            typeLine: fullType,
          ),
          isTrue,
          reason: 'Expected $name + "$fullType" to pass',
        );

        // Lowercase keyword
        expect(
          OcrHeuristicMatcher.passesMultiFactorGate(
            cardName: name,
            ocrLines: [name, keyword.toLowerCase()],
            typeLine: fullType,
          ),
          isTrue,
        );

        // Uppercase keyword
        expect(
          OcrHeuristicMatcher.passesMultiFactorGate(
            cardName: name,
            ocrLines: [name, keyword.toUpperCase()],
            typeLine: fullType,
          ),
          isTrue,
        );
      }
    });

    // -------------------------------------------------------------------------
    // 6. Genuine 2-data-point matches: Name + Set Code (CMM, MH3, LTR)
    // -------------------------------------------------------------------------
    test('accepts genuine 2-data-point matches: Name + Set Code (CMM, MH3, LTR)', () {
      // CMM (Commander Masters)
      expect(
        OcrHeuristicMatcher.passesMultiFactorGate(
          cardName: 'Sol Ring',
          ocrLines: ['Sol Ring', 'CMM'],
          setCode: 'CMM',
        ),
        isTrue,
      );

      // MH3 (Modern Horizons 3)
      expect(
        OcrHeuristicMatcher.passesMultiFactorGate(
          cardName: 'Ulamog, the Defiler',
          ocrLines: ['Ulamog, the Defiler', 'MH3'],
          setCode: 'MH3',
        ),
        isTrue,
      );

      // LTR (The Lord of the Rings)
      expect(
        OcrHeuristicMatcher.passesMultiFactorGate(
          cardName: 'The One Ring',
          ocrLines: ['The One Ring', 'LTR'],
          setCode: 'LTR',
        ),
        isTrue,
      );

      // Case insensitive
      expect(
        OcrHeuristicMatcher.passesMultiFactorGate(
          cardName: 'Sol Ring',
          ocrLines: ['Sol Ring', 'cmm'],
          setCode: 'CMM',
        ),
        isTrue,
      );

      // Embedded set code in line with symbols/parens
      expect(
        OcrHeuristicMatcher.passesMultiFactorGate(
          cardName: 'Sol Ring',
          ocrLines: ['Sol Ring', '(CMM)'],
          setCode: 'CMM',
        ),
        isTrue,
      );

      expect(
        OcrHeuristicMatcher.passesMultiFactorGate(
          cardName: 'The One Ring',
          ocrLines: ['The One Ring', 'LTR • EN'],
          setCode: 'LTR',
        ),
        isTrue,
      );
    });

    // -------------------------------------------------------------------------
    // 7. Rejection when Name Match is missing
    // -------------------------------------------------------------------------
    test('rejects frames where Name Match is missing even if secondary factors are present', () {
      expect(
        OcrHeuristicMatcher.passesMultiFactorGate(
          cardName: 'Sol Ring',
          ocrLines: ['Artifact', 'CMM', '400'],
          collectorNumber: '400',
          setCode: 'CMM',
          typeLine: 'Artifact',
        ),
        isFalse,
      );

      expect(
        OcrHeuristicMatcher.passesMultiFactorGate(
          cardName: 'Lightning Bolt',
          ocrLines: ['Instant', 'M10', '141'],
          collectorNumber: '141',
          setCode: 'M10',
          typeLine: 'Instant',
        ),
        isFalse,
      );
    });

    // -------------------------------------------------------------------------
    // 8. Rejection when Secondary Factor is missing
    // -------------------------------------------------------------------------
    test('rejects frames where Name is present but secondary factor is missing or incorrect', () {
      // Card name alone
      expect(
        OcrHeuristicMatcher.passesMultiFactorGate(
          cardName: 'Sol Ring',
          ocrLines: ['Sol Ring'],
          collectorNumber: '400',
          setCode: 'CMM',
          typeLine: 'Artifact',
        ),
        isFalse,
      );

      // Card name + unrelated line
      expect(
        OcrHeuristicMatcher.passesMultiFactorGate(
          cardName: 'Sol Ring',
          ocrLines: ['Sol Ring', 'Tap to add two mana'],
          collectorNumber: '400',
          setCode: 'CMM',
          typeLine: 'Artifact',
        ),
        isFalse,
      );

      // Card name + incorrect set code
      expect(
        OcrHeuristicMatcher.passesMultiFactorGate(
          cardName: 'Sol Ring',
          ocrLines: ['Sol Ring', 'XYZ'],
          collectorNumber: '400',
          setCode: 'CMM',
          typeLine: 'Artifact',
        ),
        isFalse,
      );

      // Card name + incorrect card type
      expect(
        OcrHeuristicMatcher.passesMultiFactorGate(
          cardName: 'Sol Ring',
          ocrLines: ['Sol Ring', 'Instant'],
          collectorNumber: '400',
          setCode: 'CMM',
          typeLine: 'Artifact',
        ),
        isFalse,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // End-to-End VaultDao Integration Stress Test
  // ---------------------------------------------------------------------------
  group('Empirical Challenge: VaultDao.matchScannedCard Multi-Factor Stress Test', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await db.vaultDao.clearAllItems();

      // Seed realistic catalog items
      final cards = [
        (
          id: 'mtg-ring',
          name: 'Ring',
          set: 'LEA',
          collector: '211',
          type: 'Artifact',
        ),
        (
          id: 'mtg-sol-ring',
          name: 'Sol Ring',
          set: 'CMM',
          collector: '400',
          type: 'Artifact',
        ),
        (
          id: 'mtg-fire-ice',
          name: 'Fire // Ice',
          set: 'APC',
          collector: '128',
          type: 'Instant',
        ),
        (
          id: 'mtg-fog',
          name: 'Fog',
          set: 'EMA',
          collector: '123',
          type: 'Instant',
        ),
        (
          id: 'mtg-dark-ritual',
          name: 'Dark Ritual',
          set: 'LEA',
          collector: '082',
          type: 'Instant',
        ),
        (
          id: 'mtg-lightning-bolt',
          name: 'Lightning Bolt',
          set: 'M10',
          collector: '141',
          type: 'Instant',
        ),
        (
          id: 'mtg-birds-of-paradise',
          name: 'Birds of Paradise',
          set: '4ED',
          collector: '168',
          type: 'Creature',
        ),
        (
          id: 'mtg-ancient-tomb',
          name: 'Ancient Tomb',
          set: 'TMP',
          collector: '305',
          type: 'Land',
        ),
        (
          id: 'mtg-pact-of-negation',
          name: 'Pact of Negation',
          set: 'FUT',
          collector: '042',
          type: 'Instant',
        ),
      ];

      for (final c in cards) {
        await db.vaultDao.into(db.vaultItems).insert(
              VaultItemsCompanion.insert(
                id: c.id,
                collectionType: 'mtg',
                name: c.name,
                setOrSeries: c.set,
                imageUrl: 'https://example.com/${c.id}.jpg',
                acquiredPrice: 1.0,
                acquiredDate: DateTime.now(),
                quantity: const Value(0),
                condition: 'NM',
                isGraded: const Value(false),
                currentMarketPrice: 2.0,
                lastPriceUpdate: DateTime.now(),
                dynamicData: jsonEncode({
                  'collector_number': c.collector,
                  'set': c.set,
                  'type_line': c.type,
                }),
              ),
            );
      }
    });

    tearDown(() async {
      await db.close();
    });

    test('enforceMultiFactor: true strictly rejects all single-word OCR inputs across catalog', () async {
      final singleWords = [
        'Ring',
        'Fire',
        'Fog',
        'Dark',
        'Bolt',
        'Bird',
        'Tomb',
        'Pact',
      ];

      for (final word in singleWords) {
        final match = await db.vaultDao.matchScannedCard(
          [word],
          'mtg',
          enforceMultiFactor: true,
        );
        expect(
          match,
          isNull,
          reason: 'Expected single word "$word" to be rejected by multi-factor gate',
        );
      }
    });

    test('enforceMultiFactor: true strictly rejects OCR lines with non-matching numbers', () async {
      final nonMatchingFrames = [
        // Sol Ring (collector 400, set CMM, type Artifact)
        ['Sol Ring', '123'],
        ['Sol Ring', '9999'],
        ['Sol Ring', '0399'],
        ['Sol Ring', 'Attack 50'],
        // Lightning Bolt (collector 141, set M10, type Instant)
        ['Lightning Bolt', '999'],
        ['Lightning Bolt', '001/250'],
        // Ancient Tomb (collector 305, set TMP, type Land)
        ['Ancient Tomb', '100'],
      ];

      for (final frame in nonMatchingFrames) {
        final match = await db.vaultDao.matchScannedCard(
          frame,
          'mtg',
          enforceMultiFactor: true,
        );
        expect(
          match,
          isNull,
          reason: 'Expected frame $frame to be rejected due to mismatched secondary factor',
        );
      }
    });

    test('enforceMultiFactor: true accepts verified 2-factor combinations for all seeded cards', () async {
      // 1. Name + Collector Number
      final solRingByCollector = await db.vaultDao.matchScannedCard(
        ['Sol Ring', '400'],
        'mtg',
        enforceMultiFactor: true,
      );
      expect(solRingByCollector, isNotNull);
      expect(solRingByCollector!.id, equals('mtg-sol-ring'));

      final boltByCollector = await db.vaultDao.matchScannedCard(
        ['Lightning Bolt', '141'],
        'mtg',
        enforceMultiFactor: true,
      );
      expect(boltByCollector, isNotNull);
      expect(boltByCollector!.id, equals('mtg-lightning-bolt'));

      // 2. Name + Card Type
      final solRingByType = await db.vaultDao.matchScannedCard(
        ['Sol Ring', 'Artifact'],
        'mtg',
        enforceMultiFactor: true,
      );
      expect(solRingByType, isNotNull);
      expect(solRingByType!.id, equals('mtg-sol-ring'));

      final boltByType = await db.vaultDao.matchScannedCard(
        ['Lightning Bolt', 'Instant'],
        'mtg',
        enforceMultiFactor: true,
      );
      expect(boltByType, isNotNull);
      expect(boltByType!.id, equals('mtg-lightning-bolt'));

      final tombByType = await db.vaultDao.matchScannedCard(
        ['Ancient Tomb', 'Land'],
        'mtg',
        enforceMultiFactor: true,
      );
      expect(tombByType, isNotNull);
      expect(tombByType!.id, equals('mtg-ancient-tomb'));

      final birdsByType = await db.vaultDao.matchScannedCard(
        ['Birds of Paradise', 'Creature'],
        'mtg',
        enforceMultiFactor: true,
      );
      expect(birdsByType, isNotNull);
      expect(birdsByType!.id, equals('mtg-birds-of-paradise'));

      // 3. Name + Set Code
      final solRingBySet = await db.vaultDao.matchScannedCard(
        ['Sol Ring', 'CMM'],
        'mtg',
        enforceMultiFactor: true,
      );
      expect(solRingBySet, isNotNull);
      expect(solRingBySet!.id, equals('mtg-sol-ring'));

      final boltBySet = await db.vaultDao.matchScannedCard(
        ['Lightning Bolt', 'M10'],
        'mtg',
        enforceMultiFactor: true,
      );
      expect(boltBySet, isNotNull);
      expect(boltBySet!.id, equals('mtg-lightning-bolt'));

      final tombBySet = await db.vaultDao.matchScannedCard(
        ['Ancient Tomb', 'TMP'],
        'mtg',
        enforceMultiFactor: true,
      );
      expect(tombBySet, isNotNull);
      expect(tombBySet!.id, equals('mtg-ancient-tomb'));
    });
  });

  // ---------------------------------------------------------------------------
  // Empirical Vulnerability Demonstrations (Flaws Resolved)
  // ---------------------------------------------------------------------------
  group('Empirical Vulnerability Demonstrations (Flaws Resolved)', () {
    test('VULNERABILITY 1: Denominator (set total) does NOT match as collector number', () {
      // Card has collectorNumber '400' (e.g. Sol Ring 400).
      // Camera scans a card with collector '123' and set total '400' ('123/400').
      // OcrHeuristicMatcher.parseLines extracts collectorNumber: '123' and totalInSet: '400'.
      // passesMultiFactorGate must NOT match denominator 400 for card 400.
      final result = OcrHeuristicMatcher.passesMultiFactorGate(
        cardName: 'Sol Ring',
        ocrLines: ['Sol Ring', '123/400'],
        collectorNumber: '400',
        setCode: 'CMM',
        typeLine: 'Artifact',
      );

      expect(
        result,
        isFalse,
        reason: 'Denominator total (400) must NOT match as collector number when card collector is 400 and scanned is 123/400',
      );

      // Verify genuine numerator match succeeds
      final numeratorMatch = OcrHeuristicMatcher.passesMultiFactorGate(
        cardName: 'Sol Ring',
        ocrLines: ['Sol Ring', '123/400'],
        collectorNumber: '123',
      );
      expect(numeratorMatch, isTrue);
    });

    test('VULNERABILITY 2: 4-digit zero-padded collector numbers match correctly', () {
      // Modern sets and OCR engines frequently yield 4-digit zero-padded numbers like '0400'.
      // When card has collectorNumber '400', passesMultiFactorGate should match '0400'.
      final zeroPaddedResult = OcrHeuristicMatcher.passesMultiFactorGate(
        cardName: 'Sol Ring',
        ocrLines: ['Sol Ring', '0400'],
        collectorNumber: '400',
        setCode: 'CMM',
        typeLine: 'Artifact',
      );

      expect(
        zeroPaddedResult,
        isTrue,
        reason: '0400 in OCR lines should match collectorNumber 400',
      );

      // Also verify reverse: collectorNumber 0400 matches OCR line 400
      final reverseResult = OcrHeuristicMatcher.passesMultiFactorGate(
        cardName: 'Sol Ring',
        ocrLines: ['Sol Ring', '400'],
        collectorNumber: '0400',
      );
      expect(reverseResult, isTrue);
    });

    test('VULNERABILITY 3: When setCode is omitted or null, arbitrary 3-5 character tokens are rejected', () {
      // If setCode is not provided (or empty), passesMultiFactorGate must NOT allow
      // arbitrary 3-5 character alphanumeric uppercase tokens (e.g. 'XYZ') to fulfill Condition 3.
      final arbitraryTokenResult = OcrHeuristicMatcher.passesMultiFactorGate(
        cardName: 'Sol Ring',
        ocrLines: ['Sol Ring', 'XYZ'],
        collectorNumber: '400', // Non-matching collector
        // setCode omitted
      );

      expect(
        arbitraryTokenResult,
        isFalse,
        reason: 'Arbitrary token "XYZ" must NOT pass as valid set code when setCode param is null',
      );

      // Passing exact setCode must succeed
      final exactSetResult = OcrHeuristicMatcher.passesMultiFactorGate(
        cardName: 'Sol Ring',
        ocrLines: ['Sol Ring', 'XYZ'],
        setCode: 'XYZ',
      );
      expect(exactSetResult, isTrue);
    });
  });
}

