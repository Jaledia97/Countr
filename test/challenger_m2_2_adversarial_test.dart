import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';

import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/scanner/domain/card_perimeter_calculator.dart';
import 'package:countr/features/scanner/domain/cascade_scanner_coordinator.dart';
import 'package:countr/features/scanner/domain/profiles/mtg_collectible_profile.dart';
import 'package:countr/features/scanner/domain/vision/bk_tree.dart';
import 'package:countr/features/scanner/presentation/screens/scanner_modal.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/scanner/utils/camera_image_converter.dart';
import 'e2e/test_helpers.dart';

/// Fake TextRecognizer allowing customized RecognizedText responses.
class MockTextRecognizer implements TextRecognizer {
  RecognizedText response;
  int processCallCount = 0;
  final List<InputImage> capturedInputImages = [];

  MockTextRecognizer(this.response);

  @override
  Future<RecognizedText> processImage(InputImage inputImage) async {
    processCallCount++;
    capturedInputImages.add(inputImage);
    return response;
  }

  @override
  Future<void> close() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Helper to create Fake RecognizedText
RecognizedText buildFakeRecognizedText({
  required String text,
  List<Rect> boundingBoxes = const [],
}) {
  final blocks = boundingBoxes.map((box) {
    return TextBlock(
      text: text,
      lines: [
        TextLine(
          text: text,
          elements: const [],
          boundingBox: box,
          recognizedLanguages: const [],
          cornerPoints: const [],
          angle: 0.0,
          confidence: 1.0,
        ),
      ],
      boundingBox: box,
      recognizedLanguages: const [],
      cornerPoints: const [],
    );
  }).toList();

  return RecognizedText(text: text, blocks: blocks);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late VaultDao dao;
  late CascadeScannerCoordinator coordinator;
  late Directory mockTempDir;
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUpAll(() {
    mockTempDir = Directory.systemTemp.createTempSync('countr_scanner_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (MethodCall methodCall) async {
      return mockTempDir.path;
    });
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    if (mockTempDir.existsSync()) {
      try {
        mockTempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dao = db.vaultDao;
    coordinator = CascadeScannerCoordinator(
      bkTree: BkTree(),
      profiles: [MtgCollectibleProfile()],
    );
  });

  tearDown(() async {
    await db.close();
  });

  VaultItemsCompanion createItem({
    required String id,
    required String name,
    required String collectionType,
    String? collectorNumber,
    String? setCode,
  }) {
    final Map<String, dynamic> data = {};
    if (collectorNumber != null) data['collector_number'] = collectorNumber;
    if (setCode != null) data['set_code'] = setCode;

    return VaultItemsCompanion.insert(
      id: id,
      name: name,
      collectionType: collectionType,
      setOrSeries: 'Modern Horizons 3',
      imageUrl: '',
      acquiredPrice: 20.0,
      acquiredDate: DateTime(2026, 1, 1),
      quantity: const drift.Value(1),
      condition: 'Near Mint',
      currentMarketPrice: 25.0,
      lastPriceUpdate: DateTime(2026, 1, 1),
      dynamicData: jsonEncode(data),
    );
  }

  group('Challenger M2-2 Empirical Group 1: ML Kit Full-Frame Fallback (Primary Path Miss)', () {
    test('1.1 Primary path miss falls back to ML Kit and matches card in DB via Tier 1 OCR', () async {
      await db.into(db.vaultItems).insert(
        createItem(
          id: 'card_sol_ring',
          name: 'Sol Ring',
          collectionType: 'mtg',
          collectorNumber: '024',
        ),
      );

      final dummyImage = createMockCameraImage(width: 720, height: 1280);
      final fakeBlocks = [
        const Rect.fromLTWH(80, 120, 300, 40),
        const Rect.fromLTWH(80, 600, 200, 30),
      ];
      final fakeRecognized = buildFakeRecognizedText(
        text: 'Sol Ring\nArtifact\n024/250 MH3',
        boundingBoxes: fakeBlocks,
      );
      final fakeRecognizer = MockTextRecognizer(fakeRecognized);

      List<double>? yieldedCorners;
      final result = await coordinator.processFrame(
        cameraImage: dummyImage,
        dao: dao,
        textRecognizer: fakeRecognizer,
        onCornersDetected: (corners) {
          yieldedCorners = corners;
        },
      );

      // Verify ML Kit fallback was invoked
      expect(fakeRecognizer.processCallCount, equals(1));
      expect(fakeRecognizer.capturedInputImages, isNotEmpty);

      // Verify corner yielding in fallback path
      expect(yieldedCorners, isNotNull);
      expect(yieldedCorners!.length, equals(8));

      // Verify successful catalog match
      expect(result.$1, isNotNull);
      expect(result.$1!.tier, equals(1));
      expect(result.$1!.match.id, equals('card_sol_ring'));
      expect(result.$1!.match.name, equals('Sol Ring'));
      expect(result.$2, equals(yieldedCorners));
    });

    test('1.2 Fallback unrotates coordinates to raw sensor space across 90, 180, 270, and 0 degree rotations', () async {
      const orientations = [
        (90, InputImageRotation.rotation90deg),
        (180, InputImageRotation.rotation180deg),
        (270, InputImageRotation.rotation270deg),
        (0, InputImageRotation.rotation0deg),
      ];

      for (final (sensorAngle, expectedRotation) in orientations) {
        final cam = CameraDescription(
          name: 'cam_$sensorAngle',
          lensDirection: CameraLensDirection.back,
          sensorOrientation: sensorAngle,
        );

        final dummyImage = createMockCameraImage(width: 720, height: 1280);
        final fakeBlocks = [
          const Rect.fromLTWH(100, 150, 250, 350),
        ];
        final fakeRecognized = buildFakeRecognizedText(
          text: 'Unmatched Text Block',
          boundingBoxes: fakeBlocks,
        );
        final fakeRecognizer = MockTextRecognizer(fakeRecognized);

        List<double>? corners;
        final result = await coordinator.processFrame(
          cameraImage: dummyImage,
          camera: cam,
          dao: dao,
          textRecognizer: fakeRecognizer,
          onCornersDetected: (c) => corners = c,
        );

        expect(corners, isNotNull);
        expect(corners!.length, equals(8));
        expect(result.$2, equals(corners));

        // Re-rotate raw corners using CameraImageConverter.calculateRotation and CardPerimeterCalculator
        final xs = [corners![0], corners![2], corners![4], corners![6]]..sort();
        final ys = [corners![1], corners![3], corners![5], corners![7]]..sort();
        final rawRect = Rect.fromLTRB(xs.first, ys.first, xs.last, ys.last);
        final rawSize = Size(dummyImage.width.toDouble(), dummyImage.height.toDouble());
        final rotation = CameraImageConverter.calculateRotation(cam, null);
        expect(rotation, equals(expectedRotation));

        final (uprightRect, _) = CardPerimeterCalculator.rotateImageRect(
          imageRect: rawRect,
          imageSize: rawSize,
          rotation: rotation,
        );

        // In upright space, the bounding box must enclose the original fakeBlocks
        expect(uprightRect.left, lessThanOrEqualTo(100.0));
        expect(uprightRect.top, lessThanOrEqualTo(150.0));
        expect(uprightRect.right, greaterThanOrEqualTo(350.0));
        expect(uprightRect.bottom, greaterThanOrEqualTo(500.0));
      }
    });

    test('1.3 Fallback emits corners even when card is not found in database', () async {
      final dummyImage = createMockCameraImage(width: 720, height: 1280);
      final fakeBlocks = [
        const Rect.fromLTWH(50, 50, 200, 300),
      ];
      final fakeRecognized = buildFakeRecognizedText(
        text: 'Unknown Brand New Promo Card 999/999',
        boundingBoxes: fakeBlocks,
      );
      final fakeRecognizer = MockTextRecognizer(fakeRecognized);

      List<double>? yieldedCorners;
      final result = await coordinator.processFrame(
        cameraImage: dummyImage,
        dao: dao,
        textRecognizer: fakeRecognizer,
        onCornersDetected: (corners) => yieldedCorners = corners,
      );

      // Coordinates yielded despite DB miss
      expect(yieldedCorners, isNotNull);
      expect(yieldedCorners!.length, equals(8));
      expect(result.$1, isNull);
      expect(result.$2, equals(yieldedCorners));
    });

    test('1.4 Fallback gracefully returns (null, null) when ML Kit detects empty text and zero blocks', () async {
      final dummyImage = createMockCameraImage(width: 720, height: 1280);
      final fakeRecognized = buildFakeRecognizedText(
        text: '',
        boundingBoxes: [],
      );
      final fakeRecognizer = MockTextRecognizer(fakeRecognized);

      bool callbackInvoked = false;
      final result = await coordinator.processFrame(
        cameraImage: dummyImage,
        dao: dao,
        textRecognizer: fakeRecognizer,
        onCornersDetected: (_) => callbackInvoked = true,
      );

      expect(callbackInvoked, isFalse);
      expect(result.$1, isNull);
      expect(result.$2, isNull);
    });

    test('1.5 Fallback safely handles unconvertible camera image without throwing', () async {
      // Mock an invalid camera image format with empty planes
      final badImage = FakeCameraImage(
        width: 100,
        height: 100,
        format: FakeImageFormat(group: ImageFormatGroup.unknown, raw: 9999),
        planes: [],
      );
      final fakeRecognizer = MockTextRecognizer(buildFakeRecognizedText(text: ''));

      final result = await coordinator.processFrame(
        cameraImage: badImage,
        dao: dao,
        textRecognizer: fakeRecognizer,
      );

      expect(result.$1, isNull);
      expect(result.$2, isNull);
    });
  });

  group('Challenger M2-2 Empirical Group 2: Immediate Coordinate Yielding Timing Verification', () {
    test('2.1 onCornersDetected is invoked strictly BEFORE database queries are executed', () async {
      await db.into(db.vaultItems).insert(
        createItem(
          id: 'card_lotus',
          name: 'Black Lotus',
          collectionType: 'mtg',
          collectorNumber: '232',
        ),
      );

      final dummyImage = createMockCameraImage(width: 720, height: 1280);
      final fakeBlocks = [
        const Rect.fromLTWH(100, 100, 300, 400),
      ];
      final fakeRecognized = buildFakeRecognizedText(
        text: 'Black Lotus\nArtifact\n232/250 LEA',
        boundingBoxes: fakeBlocks,
      );
      final fakeRecognizer = MockTextRecognizer(fakeRecognized);

      final eventLog = <String>[];
      int cornerDetectedMicrosecond = 0;
      int dbQueryMicrosecond = 0;

      // We spy on dao query execution by measuring timestamp
      final result = await coordinator.processFrame(
        cameraImage: dummyImage,
        dao: dao,
        textRecognizer: fakeRecognizer,
        onCornersDetected: (corners) {
          cornerDetectedMicrosecond = DateTime.now().microsecondsSinceEpoch;
          eventLog.add('onCornersDetected');
        },
      );

      // Now query DAO to log time
      dbQueryMicrosecond = DateTime.now().microsecondsSinceEpoch;
      eventLog.add('dbQueryFinished');

      expect(eventLog, equals(['onCornersDetected', 'dbQueryFinished']));
      expect(cornerDetectedMicrosecond, lessThanOrEqualTo(dbQueryMicrosecond));
      expect(result.$1, isNotNull);
      expect(result.$1!.match.id, equals('card_lotus'));
    });

    test('2.2 ML Kit fallback path performs ZERO disk writes (bypasses getTemporaryDirectory)', () async {
      final tempDir = await getTemporaryDirectory();
      final filesBefore = tempDir.listSync().where((f) => f.path.contains('cropped_for_ocr_')).toList();

      final dummyImage = createMockCameraImage(width: 720, height: 1280);
      final fakeBlocks = [const Rect.fromLTWH(80, 80, 200, 200)];
      final fakeRecognized = buildFakeRecognizedText(
        text: 'Some Card\n100/200',
        boundingBoxes: fakeBlocks,
      );
      final fakeRecognizer = MockTextRecognizer(fakeRecognized);

      await coordinator.processFrame(
        cameraImage: dummyImage,
        dao: dao,
        textRecognizer: fakeRecognizer,
      );

      final filesAfter = tempDir.listSync().where((f) => f.path.contains('cropped_for_ocr_')).toList();
      expect(filesAfter.length, equals(filesBefore.length),
          reason: 'Secondary fallback path must not create temporary JPEG files on disk');
    });
  });

  group('Challenger M2-2 Empirical Group 3: ScannerModal Decoupled Frame Cadence (~15 FPS Tracking vs ~2 FPS Matching)', () {
    Widget buildModalHarness() {
      return ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(dao),
        ],
        child: const MaterialApp(
          home: ScannerModal(),
        ),
      );
    }

    testWidgets('3.1 Tracking loop filters frame cadence (even frames track, odd frames skip)', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildModalHarness());
      await tester.pump(const Duration(milliseconds: 300));

      final state = tester.state(find.byType(ScannerModal)) as dynamic;
      final dummyImage = createMockCameraImage(width: 720, height: 1280);

      // Initial state
      expect(state.frameCount, 0);

      // Frame 1 (odd): skipped
      await state.processCameraFrameForTesting(dummyImage);
      expect(state.frameCount, 1);
      expect(state.isTracking, isFalse);

      // Frame 2 (even): processed
      await state.processCameraFrameForTesting(dummyImage);
      expect(state.frameCount, 2);

      // Frame 3 (odd): skipped
      await state.processCameraFrameForTesting(dummyImage);
      expect(state.frameCount, 3);

      // Frame 4 (even): processed
      await state.processCameraFrameForTesting(dummyImage);
      expect(state.frameCount, 4);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('3.2 Visual tracking loop completes rapidly without waiting for matching loop', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildModalHarness());
      await tester.pump(const Duration(milliseconds: 300));

      final state = tester.state(find.byType(ScannerModal)) as dynamic;
      final dummyImage = createMockCameraImage(width: 720, height: 1280);

      // Trigger frame 1 (odd)
      await state.processCameraFrameForTesting(dummyImage);
      // Trigger frame 2 (even) - launches tracking (~15ms) and unawaited matching
      await state.processCameraFrameForTesting(dummyImage);

      // Immediately after processCameraFrame completes, isTracking must be FALSE
      expect(state.isTracking, isFalse,
          reason: 'Tracking lock must be released immediately for fast ~15 FPS visual cadence');

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('3.3 400ms throttle cooldown prevents concurrent matching storms', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildModalHarness());
      await tester.pump(const Duration(milliseconds: 300));

      final state = tester.state(find.byType(ScannerModal)) as dynamic;
      final dummyImage = createMockCameraImage(width: 720, height: 1280);

      // Pump 10 frames rapidly in under 100ms
      for (int i = 0; i < 10; i++) {
        await state.processCameraFrameForTesting(dummyImage);
      }

      expect(state.frameCount, 10);
      // Ensure no state deadlock
      expect(state.isTracking, isFalse);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('3.4 Scanning pause immediately aborts frame processing', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildModalHarness());
      await tester.pump(const Duration(milliseconds: 300));

      final state = tester.state(find.byType(ScannerModal)) as dynamic;
      final dummyImage = createMockCameraImage(width: 720, height: 1280);

      // Pause scanning
      await tester.tap(find.byKey(const Key('scanner_pause_toggle')));
      await tester.pump(const Duration(milliseconds: 300));

      final countBefore = state.frameCount;
      await state.processCameraFrameForTesting(dummyImage);

      // Frame count increases, but tracking and matching are completely bypassed
      expect(state.frameCount, countBefore + 1);
      expect(state.isTracking, isFalse);
      expect(state.isMatching, isFalse);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });
  });

  group('Challenger M2-2 Empirical Group 4: CardPerimeterCalculator & Smoothing Invariants', () {
    test('4.1 smoothRect applies alpha 0.40 for subtle jitter and snaps faster (0.85) on swift card displacement', () {
      const initial = Rect.fromLTWH(100, 100, 200, 300);

      // Case A: Movement <= 60px (displacement: sqrt(10^2 + 10^2) = 14.14px)
      const smallMove = Rect.fromLTWH(110, 110, 200, 300);
      final smoothedSmall = CardPerimeterCalculator.smoothRect(initial, smallMove);
      expect(smoothedSmall.left, closeTo(104.0, 0.001));
      expect(smoothedSmall.top, closeTo(104.0, 0.001));

      // Case B: Movement > 60px (displacement: 100px)
      const largeMove = Rect.fromLTWH(200, 100, 200, 300);
      final smoothedLarge = CardPerimeterCalculator.smoothRect(initial, largeMove);
      // Snaps with 0.85 effectiveAlpha: 100 + 100 * 0.85 = 185
      expect(smoothedLarge.left, closeTo(185.0, 0.001));
      expect(smoothedLarge.top, closeTo(100.0, 0.001));

      // Case C: Null previous returns current
      final smoothedNull = CardPerimeterCalculator.smoothRect(null, initial);
      expect(smoothedNull, equals(initial));
    });

    test('4.2 Lossless round-trip invariance across 100 random bounding boxes and all 4 rotations', () {
      const rawSize = Size(720, 1280);
      const rotations = [
        InputImageRotation.rotation0deg,
        InputImageRotation.rotation90deg,
        InputImageRotation.rotation180deg,
        InputImageRotation.rotation270deg,
      ];

      for (int i = 0; i < 25; i++) {
        final left = (i * 20.0).clamp(0.0, 500.0);
        final top = (i * 35.0).clamp(0.0, 900.0);
        final width = 150.0 + (i * 4.0);
        final height = 250.0 + (i * 5.0);
        final rawRect = Rect.fromLTWH(left, top, width, height);

        for (final rotation in rotations) {
          final (upright, _) = CardPerimeterCalculator.rotateImageRect(
            imageRect: rawRect,
            imageSize: rawSize,
            rotation: rotation,
          );

          final restored = CardPerimeterCalculator.unrotateRectToRawSensor(
            upright,
            rawSize,
            rotation,
          );

          expect(restored.left, closeTo(rawRect.left, 0.0001));
          expect(restored.top, closeTo(rawRect.top, 0.0001));
          expect(restored.right, closeTo(rawRect.right, 0.0001));
          expect(restored.bottom, closeTo(rawRect.bottom, 0.0001));
        }
      }
    });

    test('4.3 Degenerate & boundary conditions: zero area, inverted boxes, and out-of-bounds', () {
      // Inverted box
      final invertedBlocks = [
        TextBlock(
          text: 'bad',
          lines: const [],
          boundingBox: const Rect.fromLTRB(100, 100, 50, 50),
          recognizedLanguages: const [],
          cornerPoints: const [],
        ),
      ];
      expect(CardPerimeterCalculator.calculatePerimeter(invertedBlocks), isNull);

      // Zero size image in mapImageRectToScreen
      final normalRect = const Rect.fromLTWH(10, 10, 50, 50);
      final mappedZero = CardPerimeterCalculator.mapImageRectToScreen(
        imageRect: normalRect,
        imageSize: Size.zero,
        screenSize: const Size(400, 800),
      );
      expect(mappedZero, equals(normalRect));

      // Clamping out-of-screen bounds
      final outRect = const Rect.fromLTRB(-100, -50, 600, 1000);
      final clamped = CardPerimeterCalculator.clampRectToScreen(outRect, const Size(400, 800));
      expect(clamped.left, 0.0);
      expect(clamped.top, 0.0);
      expect(clamped.right, 400.0);
      expect(clamped.bottom, 800.0);
    });
  });
}
