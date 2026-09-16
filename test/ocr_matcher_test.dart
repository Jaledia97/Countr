import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/scanner/domain/ocr_heuristic_matcher.dart';
import 'package:countr/features/scanner/domain/adaptive_auto_adjust_controller.dart';
import 'package:countr/features/scanner/utils/camera_image_converter.dart';

void main() {
  group('OcrHeuristicMatcher', () {
    test('extracts fraction collector numbers (MTG style)', () {
      final lines = [
        'Black Lotus',
        'Artifact',
        'Tap, Sacrifice Black Lotus: Add three mana of any one color.',
        'Illus. Christopher Rush',
        '232/250',
      ];

      final result = OcrHeuristicMatcher.parseLines(lines);

      expect(result.primaryName, equals('Black Lotus'));
      expect(result.collectorNumber, equals('232'));
      expect(result.totalInSet, equals('250'));
    });

    test('extracts set-dash collector numbers (Pokémon / One Piece style)', () {
      final lines = [
        'Charizard ex',
        'HP 330',
        'Slash 60',
        'Infernal Reign',
        'SV03-125',
      ];

      final result = OcrHeuristicMatcher.parseLines(lines);

      expect(result.candidateNames, contains('Charizard ex'));
      expect(result.setCode, equals('SV03'));
      expect(result.collectorNumber, equals('125'));
    });

    test('extracts hash collector numbers (#007, No. 25)', () {
      final lines = [
        'Pikachu',
        'No. 25 Mouse Pokémon',
        'Thunderbolt 100',
        '#025',
      ];

      final result = OcrHeuristicMatcher.parseLines(lines);

      expect(result.primaryName, equals('Pikachu'));
      expect(result.collectorNumber, equals('25'));
    });

    test('cleans OCR artifacts and filters out card type noise', () {
      final lines = [
        '© 2023 Wizards of the Coast',
        'Creature — Dragon',
        '| Shivan Dragon |',
        'Flying, +1/+0 firebreathing',
        '5/5',
      ];

      final result = OcrHeuristicMatcher.parseLines(lines);

      expect(result.candidateNames, contains('Shivan Dragon'));
      expect(result.candidateNames, isNot(contains('Creature — Dragon')));
      expect(result.candidateNames, isNot(contains('© 2023 Wizards of the Coast')));
    });
  });

  group('AdaptiveAutoAdjustController', () {
    test('initial state has step 0 and 0.0 offset', () {
      final controller = AdaptiveAutoAdjustController();

      expect(controller.isEnabled, isTrue);
      expect(controller.currentStep, equals(0));
      expect(controller.currentOffset, equals(0.0));

      controller.dispose();
    });

    test('steps through negative exposures when frames fail to match over threshold', () async {
      final controller = AdaptiveAutoAdjustController(
        noMatchThreshold: const Duration(milliseconds: 20),
      );

      // Initial frame with no match
      await controller.onFrameResult(matched: false);
      expect(controller.currentStep, equals(0));

      // Wait past threshold and send next non-matching frame
      await Future.delayed(const Duration(milliseconds: 30));
      await controller.onFrameResult(matched: false);
      expect(controller.currentStep, equals(1));
      expect(controller.currentOffset, equals(-0.5));

      // Wait past threshold and step to -1.0
      await Future.delayed(const Duration(milliseconds: 30));
      await controller.onFrameResult(matched: false);
      expect(controller.currentStep, equals(2));
      expect(controller.currentOffset, equals(-1.0));

      // Wait past threshold and step to -1.5
      await Future.delayed(const Duration(milliseconds: 30));
      await controller.onFrameResult(matched: false);
      expect(controller.currentStep, equals(3));
      expect(controller.currentOffset, equals(-1.5));

      // Subsequent failures stay at max step (-1.5)
      await Future.delayed(const Duration(milliseconds: 30));
      await controller.onFrameResult(matched: false);
      expect(controller.currentStep, equals(3));

      // Successful match resets immediately to 0.0
      await controller.onFrameResult(matched: true);
      expect(controller.currentStep, equals(0));
      expect(controller.currentOffset, equals(0.0));

      controller.dispose();
    });

    test('toggle disables and resets auto adjust', () async {
      final controller = AdaptiveAutoAdjustController(
        noMatchThreshold: const Duration(milliseconds: 20),
      );

      await Future.delayed(const Duration(milliseconds: 30));
      await controller.onFrameResult(matched: false);
      expect(controller.currentStep, equals(1));

      controller.toggle();
      expect(controller.isEnabled, isFalse);
      expect(controller.currentStep, equals(0));
      expect(controller.currentOffset, equals(0.0));

      controller.dispose();
    });
  });

  group('CameraImageConverter', () {
    test('calculateRotation handles back and front camera orientations', () {
      const backCamera = CameraDescription(
        name: 'back',
        lensDirection: CameraLensDirection.back,
        sensorOrientation: 90,
      );

      expect(
        CameraImageConverter.calculateRotation(backCamera, DeviceOrientation.portraitUp),
        equals(InputImageRotation.rotation90deg),
      );

      expect(
        CameraImageConverter.calculateRotation(backCamera, DeviceOrientation.landscapeLeft),
        equals(InputImageRotation.rotation0deg),
      );

      const frontCamera = CameraDescription(
        name: 'front',
        lensDirection: CameraLensDirection.front,
        sensorOrientation: 270,
      );

      expect(
        CameraImageConverter.calculateRotation(frontCamera, DeviceOrientation.portraitUp),
        equals(InputImageRotation.rotation270deg),
      );
    });
  });

  group('Requirement R2: Multi-Factor Match Gate (passesMultiFactorGate)', () {
    test('rejects single 4-character words alone (Ring, Fire, Dark, Fog)', () {
      expect(
        OcrHeuristicMatcher.passesMultiFactorGate(
          cardName: 'Sol Ring',
          ocrLines: ['Ring'],
        ),
        isFalse,
      );

      expect(
        OcrHeuristicMatcher.passesMultiFactorGate(
          cardName: 'Fire // Ice',
          ocrLines: ['Fire'],
        ),
        isFalse,
      );

      expect(
        OcrHeuristicMatcher.passesMultiFactorGate(
          cardName: 'Dark Ritual',
          ocrLines: ['Dark'],
        ),
        isFalse,
      );

      expect(
        OcrHeuristicMatcher.passesMultiFactorGate(
          cardName: 'Fog',
          ocrLines: ['Fog'],
        ),
        isFalse,
      );

      // Even with extra whitespace or single noise tokens <= 4 chars
      expect(
        OcrHeuristicMatcher.passesMultiFactorGate(
          cardName: 'Ring',
          ocrLines: ['  Ring  '],
        ),
        isFalse,
      );
    });

    test('accepts Condition 1: Name Match + Collector Number', () {
      // Direct collector line match
      expect(
        OcrHeuristicMatcher.passesMultiFactorGate(
          cardName: 'Sol Ring',
          ocrLines: ['Sol Ring', '400'],
          collectorNumber: '400',
        ),
        isTrue,
      );

      // Fraction collector number format (MTG style 232/250)
      expect(
        OcrHeuristicMatcher.passesMultiFactorGate(
          cardName: 'Black Lotus',
          ocrLines: ['Black Lotus', '232/250'],
          collectorNumber: '232',
        ),
        isTrue,
      );

      // Hash collector format (#025)
      expect(
        OcrHeuristicMatcher.passesMultiFactorGate(
          cardName: 'Pikachu',
          ocrLines: ['Pikachu', '#025'],
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

      // Name Match + Collector Number without explicit collectorNumber param
      expect(
        OcrHeuristicMatcher.passesMultiFactorGate(
          cardName: 'Sol Ring',
          ocrLines: ['Sol Ring', '400'],
        ),
        isTrue,
      );
    });

    test('accepts Condition 2: Name Match + Card Type / MTG Keyword across all 7 canonical types', () {
      final mtgKeywords = [
        'Instant',
        'Sorcery',
        'Creature',
        'Artifact',
        'Enchantment',
        'Land',
        'Planeswalker',
      ];

      for (final keyword in mtgKeywords) {
        expect(
          OcrHeuristicMatcher.passesMultiFactorGate(
            cardName: 'Test Card',
            ocrLines: ['Test Card', keyword],
            typeLine: keyword,
          ),
          isTrue,
          reason: 'Expected Condition 2 to accept MTG keyword $keyword',
        );

        // Also accepts without explicit typeLine parameter
        expect(
          OcrHeuristicMatcher.passesMultiFactorGate(
            cardName: 'Test Card',
            ocrLines: ['Test Card', keyword],
          ),
          isTrue,
          reason: 'Expected Condition 2 to accept MTG keyword $keyword in OCR lines',
        );

        // Case-insensitive within complex type phrase
        expect(
          OcrHeuristicMatcher.passesMultiFactorGate(
            cardName: 'Test Card',
            ocrLines: ['Test Card', 'Legendary $keyword — Dragon'],
          ),
          isTrue,
          reason: 'Expected Condition 2 to accept composite type containing $keyword',
        );
      }
    });

    test('accepts Condition 3: Name Match + Exact Set Code', () {
      expect(
        OcrHeuristicMatcher.passesMultiFactorGate(
          cardName: 'Sol Ring',
          ocrLines: ['Sol Ring', 'CMM'],
          setCode: 'CMM',
        ),
        isTrue,
      );

      expect(
        OcrHeuristicMatcher.passesMultiFactorGate(
          cardName: 'Charizard ex',
          ocrLines: ['Charizard ex', 'SV03'],
          setCode: 'SV03',
        ),
        isTrue,
      );

      // Rejects when setCode parameter is omitted (exact setCode validation required)
      expect(
        OcrHeuristicMatcher.passesMultiFactorGate(
          cardName: 'Sol Ring',
          ocrLines: ['Sol Ring', 'CMM'],
        ),
        isFalse,
      );
    });

    test('rejects frame when Name Match is missing', () {
      // Collector number present, but no card name
      expect(
        OcrHeuristicMatcher.passesMultiFactorGate(
          cardName: 'Sol Ring',
          ocrLines: ['Random Noise Line', '400'],
          collectorNumber: '400',
        ),
        isFalse,
      );

      // Card type present, but no card name
      expect(
        OcrHeuristicMatcher.passesMultiFactorGate(
          cardName: 'Sol Ring',
          ocrLines: ['Random Noise Line', 'Artifact'],
          typeLine: 'Artifact',
        ),
        isFalse,
      );

      // Set code present, but no card name
      expect(
        OcrHeuristicMatcher.passesMultiFactorGate(
          cardName: 'Sol Ring',
          ocrLines: ['Random Noise Line', 'CMM'],
          setCode: 'CMM',
        ),
        isFalse,
      );

      // Secondary factors present together, but still no card name
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
    });

    test('rejects frame when secondary factor is missing', () {
      // Only card name present without collector number, type, or set code
      expect(
        OcrHeuristicMatcher.passesMultiFactorGate(
          cardName: 'Sol Ring',
          ocrLines: ['Sol Ring'],
        ),
        isFalse,
      );

      expect(
        OcrHeuristicMatcher.passesMultiFactorGate(
          cardName: 'Black Lotus',
          ocrLines: ['Black Lotus'],
        ),
        isFalse,
      );

      expect(
        OcrHeuristicMatcher.passesMultiFactorGate(
          cardName: 'Fog',
          ocrLines: ['Fog'],
        ),
        isFalse,
      );

      // Card name present but secondary factor does not match expected
      expect(
        OcrHeuristicMatcher.passesMultiFactorGate(
          cardName: 'Sol Ring',
          ocrLines: ['Sol Ring', '999'],
          collectorNumber: '400',
        ),
        isFalse,
      );

      expect(
        OcrHeuristicMatcher.passesMultiFactorGate(
          cardName: 'Sol Ring',
          ocrLines: ['Sol Ring', 'ABC'],
          setCode: 'CMM',
        ),
        isFalse,
      );
    });
  });

  group('Requirement R2: VaultDao.matchScannedCard Multi-Factor Gate Integration', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await db.vaultDao.clearAllItems();

      // Seed test cards in catalog
      await db.vaultDao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'mtg-sol-ring',
              collectionType: 'mtg',
              name: 'Sol Ring',
              setOrSeries: 'CMM',
              imageUrl: 'https://example.com/solring.jpg',
              acquiredPrice: 1.5,
              acquiredDate: DateTime.now(),
              quantity: const Value(0),
              condition: 'NM',
              isGraded: const Value(false),
              currentMarketPrice: 2.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData:
                  '{"collector_number":"400","rarity":"uncommon","type_line":"Artifact","set":"CMM"}',
            ),
          );

      await db.vaultDao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'mtg-fog',
              collectionType: 'mtg',
              name: 'Fog',
              setOrSeries: 'EMA',
              imageUrl: 'https://example.com/fog.jpg',
              acquiredPrice: 0.25,
              acquiredDate: DateTime.now(),
              quantity: const Value(0),
              condition: 'NM',
              isGraded: const Value(false),
              currentMarketPrice: 0.35,
              lastPriceUpdate: DateTime.now(),
              dynamicData:
                  '{"collector_number":"123","rarity":"common","type_line":"Instant","set":"EMA"}',
            ),
          );

      await db.vaultDao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'mtg-ring',
              collectionType: 'mtg',
              name: 'Ring',
              setOrSeries: 'LEA',
              imageUrl: 'https://example.com/ring.jpg',
              acquiredPrice: 0.5,
              acquiredDate: DateTime.now(),
              quantity: const Value(0),
              condition: 'NM',
              isGraded: const Value(false),
              currentMarketPrice: 0.75,
              lastPriceUpdate: DateTime.now(),
              dynamicData:
                  '{"collector_number":"211","rarity":"rare","type_line":"Artifact","set":"LEA"}',
            ),
          );
    });

    tearDown(() async {
      await db.close();
    });

    test('baseline behavior remains unaffected when enforceMultiFactor: false', () async {
      // Single word 'Fog' alone matches without multi-factor gate
      final matchFog = await db.vaultDao.matchScannedCard(
        ['Fog'],
        'mtg',
        enforceMultiFactor: false,
      );
      expect(matchFog, isNotNull);
      expect(matchFog!.name, equals('Fog'));

      // Single word 'Ring' matches without multi-factor gate
      final matchRing = await db.vaultDao.matchScannedCard(
        ['Ring'],
        'mtg',
        enforceMultiFactor: false,
      );
      expect(matchRing, isNotNull);
      expect(matchRing!.name, equals('Ring'));

      // Collector number alone without card title matches without multi-factor gate
      final matchCollector = await db.vaultDao.matchScannedCard(
        ['Random Unrelated Line'],
        'mtg',
        collectorNumber: '400',
        enforceMultiFactor: false,
      );
      expect(matchCollector, isNotNull);
      expect(matchCollector!.name, equals('Sol Ring'));
    });

    test('enforceMultiFactor: true rejects single 4-character words and false positives', () async {
      // Single 4-character words alone are rejected
      final matchFog = await db.vaultDao.matchScannedCard(
        ['Fog'],
        'mtg',
        enforceMultiFactor: true,
      );
      expect(matchFog, isNull);

      final matchRing = await db.vaultDao.matchScannedCard(
        ['Ring'],
        'mtg',
        enforceMultiFactor: true,
      );
      expect(matchRing, isNull);

      // Card title alone without secondary factor is rejected
      final matchSolRingAlone = await db.vaultDao.matchScannedCard(
        ['Sol Ring'],
        'mtg',
        enforceMultiFactor: true,
      );
      expect(matchSolRingAlone, isNull);

      // Collector number without title is rejected
      final matchCollectorAlone = await db.vaultDao.matchScannedCard(
        ['Random Unrelated Line', '400'],
        'mtg',
        enforceMultiFactor: true,
      );
      expect(matchCollectorAlone, isNull);
    });

    test('enforceMultiFactor: true accepts Condition 1 (Name + Collector Number)', () async {
      final match = await db.vaultDao.matchScannedCard(
        ['Sol Ring', '400'],
        'mtg',
        enforceMultiFactor: true,
      );
      expect(match, isNotNull);
      expect(match!.id, equals('mtg-sol-ring'));
      expect(match.name, equals('Sol Ring'));
    });

    test('enforceMultiFactor: true accepts Condition 2 (Name + MTG Keyword / Type)', () async {
      final matchArtifact = await db.vaultDao.matchScannedCard(
        ['Sol Ring', 'Artifact'],
        'mtg',
        enforceMultiFactor: true,
      );
      expect(matchArtifact, isNotNull);
      expect(matchArtifact!.name, equals('Sol Ring'));

      final matchInstant = await db.vaultDao.matchScannedCard(
        ['Fog', 'Instant'],
        'mtg',
        enforceMultiFactor: true,
      );
      expect(matchInstant, isNotNull);
      expect(matchInstant!.name, equals('Fog'));
    });

    test('enforceMultiFactor: true accepts Condition 3 (Name + Exact Set Code)', () async {
      final match = await db.vaultDao.matchScannedCard(
        ['Sol Ring', 'CMM'],
        'mtg',
        enforceMultiFactor: true,
      );
      expect(match, isNotNull);
      expect(match!.name, equals('Sol Ring'));
    });
  });
}
