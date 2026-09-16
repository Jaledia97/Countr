import 'dart:convert';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/scanner/domain/card_perimeter_calculator.dart';
import 'package:countr/features/scanner/domain/ocr_heuristic_matcher.dart';
import 'package:countr/features/scanner/presentation/screens/scanner_modal.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';

import 'e2e/test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.vaultDao.clearAllItems();

    // 1. Sol Ring (Artifact, CMM, collector 400)
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
            dynamicData: jsonEncode({
              'collector_number': '400',
              'rarity': 'uncommon',
              'type_line': 'Artifact',
              'set': 'CMM',
            }),
          ),
        );

    // 2. Fog (Instant, EMA, collector 123)
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
            dynamicData: jsonEncode({
              'collector_number': '123',
              'rarity': 'common',
              'type_line': 'Instant',
              'set': 'EMA',
            }),
          ),
        );

    // 3. Ring (Artifact, LEA, collector 211)
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
            dynamicData: jsonEncode({
              'collector_number': '211',
              'rarity': 'rare',
              'type_line': 'Artifact',
              'set': 'LEA',
            }),
          ),
        );

    // 4. Fire // Ice (Instant, APC, collector 128)
    await db.vaultDao.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'mtg-fire-ice',
            collectionType: 'mtg',
            name: 'Fire // Ice',
            setOrSeries: 'APC',
            imageUrl: 'https://example.com/fireice.jpg',
            acquiredPrice: 1.0,
            acquiredDate: DateTime.now(),
            quantity: const Value(0),
            condition: 'NM',
            isGraded: const Value(false),
            currentMarketPrice: 1.5,
            lastPriceUpdate: DateTime.now(),
            dynamicData: jsonEncode({
              'collector_number': '128',
              'rarity': 'uncommon',
              'type_line': 'Instant',
              'set': 'APC',
            }),
          ),
        );

    // 5. Sol Ring (Retro Frame) (Artifact, BRR, collector 056)
    await db.vaultDao.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'mtg-sol-ring-retro',
            collectionType: 'mtg',
            name: 'Sol Ring (Retro Frame)',
            setOrSeries: 'BRR',
            imageUrl: 'https://example.com/solringretro.jpg',
            acquiredPrice: 5.0,
            acquiredDate: DateTime.now(),
            quantity: const Value(0),
            condition: 'NM',
            isGraded: const Value(false),
            currentMarketPrice: 6.0,
            lastPriceUpdate: DateTime.now(),
            dynamicData: jsonEncode({
              'collector_number': '056',
              'rarity': 'mythic',
              'type_line': 'Artifact',
              'set': 'BRR',
            }),
          ),
        );

    // 6. Charizard ex (Pokemon, OBF, collector 125)
    await db.vaultDao.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'pkm-charizard-ex',
            collectionType: 'pokemon',
            name: 'Charizard ex',
            setOrSeries: 'OBF',
            imageUrl: 'https://example.com/charizard.jpg',
            acquiredPrice: 40.0,
            acquiredDate: DateTime.now(),
            quantity: const Value(0),
            condition: 'NM',
            isGraded: const Value(false),
            currentMarketPrice: 45.0,
            lastPriceUpdate: DateTime.now(),
            dynamicData: jsonEncode({
              'collector_number': '125',
              'set': 'OBF',
            }),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  Widget createScannerHarness() {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        vaultDaoProvider.overrideWithValue(db.vaultDao),
        activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
      ],
      child: const MaterialApp(
        home: ScannerModal(),
      ),
    );
  }

  group('Empirical Challenge 1: Object-First Fallback & Exception Handling', () {
    testWidgets('ScannerModal initializes with useObjectDetectionFallback = false', (tester) async {
      await tester.pumpWidget(createScannerHarness());
      await tester.pump(const Duration(milliseconds: 200));

      final state = tester.state(find.byType(ScannerModal)) as dynamic;
      expect(state.useObjectDetectionFallback, isFalse);

      // Verify toggle/setter works for headless testing mode
      state.useObjectDetectionFallback = true;
      expect(state.useObjectDetectionFallback, isTrue);

      state.useObjectDetectionFallback = false;
      expect(state.useObjectDetectionFallback, isFalse);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });

    test('ObjectDetector platform channel throws PlatformException when model unavailable', () async {
      // Simulate platform channel returning PlatformException for object detector
      const channel = MethodChannel('google_mlkit_object_detector');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'vision#startObjectDetector') {
          throw PlatformException(
            code: 'MODEL_UNAVAILABLE',
            message: 'ML Kit object detection model binary not downloaded on device.',
          );
        }
        if (call.method == 'vision#closeObjectDetector') {
          return null;
        }
        return null;
      });

      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      final detector = ObjectDetector(
        options: ObjectDetectorOptions(
          mode: DetectionMode.stream,
          classifyObjects: false,
          multipleObjects: false,
        ),
      );

      // Verify that calling processImage throws PlatformException
      final fakeInput = InputImage.fromBytes(
        bytes: Uint8List.fromList(List.filled(100, 0)),
        metadata: InputImageMetadata(
          size: const Size(10, 10),
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.nv21,
          bytesPerRow: 10,
        ),
      );

      bool caughtException = false;
      try {
        await detector.processImage(fakeInput);
      } catch (e) {
        caughtException = true;
        expect(e, isA<PlatformException>());
      }
      expect(caughtException, isTrue);

      await detector.close();
    });

    testWidgets('ScannerModal closes ObjectDetector cleanly upon dispose', (tester) async {
      bool closeCalled = false;
      const channel = MethodChannel('google_mlkit_object_detector');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'vision#closeObjectDetector') {
          closeCalled = true;
          return null;
        }
        return null;
      });

      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      await tester.pumpWidget(createScannerHarness());
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(ScannerModal), findsOneWidget);

      // Unmount modal to trigger dispose
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));

      expect(closeCalled, isTrue, reason: 'dispose() must invoke vision#closeObjectDetector');
    });

    test('CardPerimeterCalculator fallback behaves correctly when object detection is bypassed', () {
      final blocks = [
        TextBlock(
          text: 'Sol Ring',
          lines: const [],
          boundingBox: const Rect.fromLTWH(50, 100, 200, 40),
          recognizedLanguages: const [],
          cornerPoints: const [],
        ),
        TextBlock(
          text: 'Artifact',
          lines: const [],
          boundingBox: const Rect.fromLTWH(50, 300, 150, 30),
          recognizedLanguages: const [],
          cornerPoints: const [],
        ),
        TextBlock(
          text: '400',
          lines: const [],
          boundingBox: const Rect.fromLTWH(50, 600, 80, 20),
          recognizedLanguages: const [],
          cornerPoints: const [],
        ),
      ];

      final perimeter = CardPerimeterCalculator.calculatePerimeter(
        blocks,
        imageSize: const Size(720, 1280),
      );

      expect(perimeter, isNotNull);
      expect(perimeter!.left, lessThan(perimeter.right));
      expect(perimeter.top, lessThan(perimeter.bottom));

      // Screen mapping
      final screenRect = CardPerimeterCalculator.mapImageRectToScreen(
        imageRect: perimeter,
        imageSize: const Size(720, 1280),
        screenSize: const Size(360, 640),
      );
      expect(screenRect.width, greaterThan(0));
      expect(screenRect.height, greaterThan(0));
    });
  });

  group('Empirical Challenge 2: Early Frame Abort when objects.isEmpty', () {
    test('ObjectDetector returns empty list when no object detected', () async {
      const channel = MethodChannel('google_mlkit_object_detector');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'vision#startObjectDetector') {
          return <dynamic>[]; // Empty list: no object detected
        }
        return null;
      });

      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      final detector = ObjectDetector(
        options: ObjectDetectorOptions(
          mode: DetectionMode.stream,
          classifyObjects: false,
          multipleObjects: false,
        ),
      );

      final fakeInput = InputImage.fromBytes(
        bytes: Uint8List.fromList(List.filled(100, 0)),
        metadata: InputImageMetadata(
          size: const Size(10, 10),
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.nv21,
          bytesPerRow: 10,
        ),
      );

      final objects = await detector.processImage(fakeInput);
      expect(objects, isEmpty);

      await detector.close();
    });

    testWidgets('ScannerModal safely skips processing when camera is uninitialized in test environment',
        (tester) async {
      await tester.pumpWidget(createScannerHarness());
      await tester.pump(const Duration(milliseconds: 200));

      final state = tester.state(find.byType(ScannerModal)) as dynamic;
      final dummyImage = createMockCameraImage();

      // Frames 1..9: skipped by modulo 10
      for (int i = 1; i <= 9; i++) {
        await state.processCameraFrameForTesting(dummyImage);
        expect(state.frameCount, i);
        expect(state.isProcessing, isFalse);
      }

      // Frame 10: processed, cameraController is null in test runner -> returns safely without throw
      await state.processCameraFrameForTesting(dummyImage);
      expect(state.frameCount, 10);
      expect(state.isProcessing, isFalse);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });
  });

  group('Empirical Challenge 3: VaultDao.matchScannedCard with enforceMultiFactor: true', () {
    test('Rejects single 4-character words alone (Fog, Ring, Fire, Dark, Bolt)', () async {
      final wordsToReject = ['Fog', 'Ring', 'Fire', 'Dark', 'Bolt', 'Snow', 'Mana'];

      for (final word in wordsToReject) {
        final match = await db.vaultDao.matchScannedCard(
          [word],
          'mtg',
          enforceMultiFactor: true,
        );
        expect(match, isNull, reason: 'Single word "$word" must be rejected under enforceMultiFactor: true');
      }
    });

    test('Rejects full card title alone when secondary verifying factor is missing', () async {
      // "Sol Ring" is 8 characters, but lacks secondary factor
      final matchSolRing = await db.vaultDao.matchScannedCard(
        ['Sol Ring'],
        'mtg',
        enforceMultiFactor: true,
      );
      expect(matchSolRing, isNull);

      // "Charizard ex" alone lacks secondary factor
      final matchCharizard = await db.vaultDao.matchScannedCard(
        ['Charizard ex'],
        'pokemon',
        enforceMultiFactor: true,
      );
      expect(matchCharizard, isNull);
    });

    test('Rejects frame when secondary factor does NOT match the card in database', () async {
      // 1. Wrong collector number: Sol Ring has 400, frame has 999
      final matchWrongCollector = await db.vaultDao.matchScannedCard(
        ['Sol Ring', '999'],
        'mtg',
        enforceMultiFactor: true,
      );
      expect(matchWrongCollector, isNull);

      // 2. Wrong set code: Sol Ring has CMM, frame has NEO
      final matchWrongSet = await db.vaultDao.matchScannedCard(
        ['Sol Ring', 'NEO'],
        'mtg',
        enforceMultiFactor: true,
      );
      expect(matchWrongSet, isNull);

      // 3. Wrong type: Sol Ring is an Artifact, frame has Sorcery (and card type_line is Artifact)
      final matchWrongType = await db.vaultDao.matchScannedCard(
        ['Sol Ring', 'Sorcery'],
        'mtg',
        enforceMultiFactor: true,
      );
      expect(matchWrongType, isNull);

      // 4. Numeric noise line alone (not a set code)
      final matchNumericNoise = await db.vaultDao.matchScannedCard(
        ['Sol Ring', '2023'],
        'mtg',
        enforceMultiFactor: true,
      );
      expect(matchNumericNoise, isNull);

      // 5. Random OCR noise lines without valid secondary factors
      final matchNoise = await db.vaultDao.matchScannedCard(
        ['Sol Ring', 'Tap to add mana', 'Illus Mark Tedin'],
        'mtg',
        enforceMultiFactor: true,
      );
      expect(matchNoise, isNull);
    });

    test('Accepts Condition 1: Name + Correct Collector Number', () async {
      // Exact number
      final match1 = await db.vaultDao.matchScannedCard(
        ['Sol Ring', '400'],
        'mtg',
        enforceMultiFactor: true,
      );
      expect(match1, isNotNull);
      expect(match1!.id, equals('mtg-sol-ring'));

      // Zero-padded collector number (056 vs 56)
      final match2 = await db.vaultDao.matchScannedCard(
        ['Sol Ring (Retro Frame)', '56'],
        'mtg',
        enforceMultiFactor: true,
      );
      expect(match2, isNotNull);
      expect(match2!.id, equals('mtg-sol-ring-retro'));

      // Fraction collector format (123/250)
      final match3 = await db.vaultDao.matchScannedCard(
        ['Fog', '123/250'],
        'mtg',
        enforceMultiFactor: true,
      );
      expect(match3, isNotNull);
      expect(match3!.id, equals('mtg-fog'));

      // Pokemon card with collector number
      final match4 = await db.vaultDao.matchScannedCard(
        ['Charizard ex', '125'],
        'pokemon',
        enforceMultiFactor: true,
      );
      expect(match4, isNotNull);
      expect(match4!.id, equals('pkm-charizard-ex'));
    });

    test('Accepts Condition 2: Name + Correct MTG Card Type Keyword', () async {
      // Artifact
      final matchArtifact = await db.vaultDao.matchScannedCard(
        ['Sol Ring', 'Artifact'],
        'mtg',
        enforceMultiFactor: true,
      );
      expect(matchArtifact, isNotNull);
      expect(matchArtifact!.name, equals('Sol Ring'));

      // Instant
      final matchInstant = await db.vaultDao.matchScannedCard(
        ['Fog', 'Instant'],
        'mtg',
        enforceMultiFactor: true,
      );
      expect(matchInstant, isNotNull);
      expect(matchInstant!.name, equals('Fog'));

      // Composite type line containing keyword
      final matchComposite = await db.vaultDao.matchScannedCard(
        ['Sol Ring', 'Legendary Artifact — Equipment'],
        'mtg',
        enforceMultiFactor: true,
      );
      expect(matchComposite, isNotNull);
      expect(matchComposite!.name, equals('Sol Ring'));
    });

    test('Accepts Condition 3: Name + Correct Set Code', () async {
      // Sol Ring from CMM
      final matchCmm = await db.vaultDao.matchScannedCard(
        ['Sol Ring', 'CMM'],
        'mtg',
        enforceMultiFactor: true,
      );
      expect(matchCmm, isNotNull);
      expect(matchCmm!.name, equals('Sol Ring'));

      // Fog from EMA
      final matchEma = await db.vaultDao.matchScannedCard(
        ['Fog', 'EMA'],
        'mtg',
        enforceMultiFactor: true,
      );
      expect(matchEma, isNotNull);
      expect(matchEma!.name, equals('Fog'));

      // Pokemon set code OBF
      final matchObf = await db.vaultDao.matchScannedCard(
        ['Charizard ex', 'OBF'],
        'pokemon',
        enforceMultiFactor: true,
      );
      expect(matchObf, isNotNull);
      expect(matchObf!.name, equals('Charizard ex'));
    });

    test('Handles split card names with adventure/split delimiter (//)', () async {
      // Fire // Ice with Instant type
      final match = await db.vaultDao.matchScannedCard(
        ['Fire', 'Instant'],
        'mtg',
        enforceMultiFactor: true,
      );
      expect(match, isNotNull);
      expect(match!.id, equals('mtg-fire-ice'));
      expect(match.name, equals('Fire // Ice'));
    });

    test('RESOLVED: Multiple card editions with same title match the edition satisfying multi-factor gate', () async {
      // Seed two editions of Counterspell: EMA and ICE
      await db.vaultDao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'mtg-counterspell-ema',
              collectionType: 'mtg',
              name: 'Counterspell',
              setOrSeries: 'EMA',
              imageUrl: 'https://example.com/cs_ema.jpg',
              acquiredPrice: 1.0,
              acquiredDate: DateTime.now(),
              quantity: const Value(0),
              condition: 'NM',
              isGraded: const Value(false),
              currentMarketPrice: 1.5,
              lastPriceUpdate: DateTime.now(),
              dynamicData: jsonEncode({
                'collector_number': '045',
                'rarity': 'common',
                'type_line': 'Instant',
                'set': 'EMA',
              }),
            ),
          );

      await db.vaultDao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'mtg-counterspell-ice',
              collectionType: 'mtg',
              name: 'Counterspell',
              setOrSeries: 'ICE',
              imageUrl: 'https://example.com/cs_ice.jpg',
              acquiredPrice: 2.0,
              acquiredDate: DateTime.now(),
              quantity: const Value(0),
              condition: 'NM',
              isGraded: const Value(false),
              currentMarketPrice: 2.5,
              lastPriceUpdate: DateTime.now(),
              dynamicData: jsonEncode({
                'collector_number': '062',
                'rarity': 'common',
                'type_line': 'Instant',
                'set': 'ICE',
              }),
            ),
          );

      // Scanning Counterspell from ICE with exact set code ICE:
      // When verifyCandidatesForLine evaluates candidates, EMA fails Condition 3 (ICE != EMA),
      // and ICE satisfies Condition 3 (ICE == ICE).
      // The filter checks all candidates and correctly returns mtg-counterspell-ice.
      final match = await db.vaultDao.matchScannedCard(
        ['Counterspell', 'ICE'],
        'mtg',
        enforceMultiFactor: true,
      );

      expect(
        match?.id,
        equals('mtg-counterspell-ice'),
        reason: 'Multi-edition candidate verification in VaultDao.matchScannedCard must return Counterspell (ICE)',
      );
    });

    test('passesMultiFactorGate edge cases: single line containing both name and secondary factor', () {
      // Name and fraction collector in single line
      expect(
        OcrHeuristicMatcher.passesMultiFactorGate(
          cardName: 'Sol Ring',
          ocrLines: ['Sol Ring 400/250'],
          collectorNumber: '400',
        ),
        isTrue,
      );

      // Name and card type in single line
      expect(
        OcrHeuristicMatcher.passesMultiFactorGate(
          cardName: 'Sol Ring',
          ocrLines: ['Sol Ring Artifact'],
          typeLine: 'Artifact',
        ),
        isTrue,
      );

      // Name and set code in single line
      expect(
        OcrHeuristicMatcher.passesMultiFactorGate(
          cardName: 'Sol Ring',
          ocrLines: ['Sol Ring CMM'],
          setCode: 'CMM',
        ),
        isTrue,
      );
    });

    test('passesMultiFactorGate edge cases: empty, whitespace, and null handling', () {
      expect(
        OcrHeuristicMatcher.passesMultiFactorGate(
          cardName: '',
          ocrLines: ['Sol Ring', '400'],
        ),
        isFalse,
      );

      expect(
        OcrHeuristicMatcher.passesMultiFactorGate(
          cardName: '   ',
          ocrLines: ['Sol Ring', '400'],
        ),
        isFalse,
      );

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
          ocrLines: ['', '   '],
        ),
        isFalse,
      );
    });

    test('Baseline backward compatibility: enforceMultiFactor: false preserves legacy matches', () async {
      // Single 4-character words match when enforceMultiFactor: false
      final matchFog = await db.vaultDao.matchScannedCard(
        ['Fog'],
        'mtg',
        enforceMultiFactor: false,
      );
      expect(matchFog, isNotNull);
      expect(matchFog!.name, equals('Fog'));

      final matchRing = await db.vaultDao.matchScannedCard(
        ['Ring'],
        'mtg',
        enforceMultiFactor: false,
      );
      expect(matchRing, isNotNull);
      expect(matchRing!.name, equals('Ring'));

      // Card title alone matches when enforceMultiFactor: false
      final matchSolRing = await db.vaultDao.matchScannedCard(
        ['Sol Ring'],
        'mtg',
        enforceMultiFactor: false,
      );
      expect(matchSolRing, isNotNull);
      expect(matchSolRing!.name, equals('Sol Ring'));
    });
  });
}
