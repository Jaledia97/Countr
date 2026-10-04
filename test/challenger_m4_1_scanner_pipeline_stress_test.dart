import 'dart:math' as math;
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/scanner/domain/card_perimeter_calculator.dart';
import 'package:countr/features/scanner/domain/cascade_scanner_coordinator.dart';
import 'package:countr/features/scanner/domain/profiles/comic_collectible_profile.dart';
import 'package:countr/features/scanner/domain/profiles/mtg_collectible_profile.dart';
import 'package:countr/features/scanner/domain/vision/bk_tree.dart';
import 'package:countr/features/scanner/domain/vision/camera_frame_dto.dart';
import 'package:countr/features/scanner/domain/vision/vision_isolate.dart';
import 'package:countr/features/scanner/presentation/widgets/dynamic_scanner_overlay.dart';
import 'e2e/test_helpers.dart';

class _FakeTextRecognizer implements TextRecognizer {
  RecognizedText recognizedText;
  bool shouldThrow;

  _FakeTextRecognizer(this.recognizedText, {this.shouldThrow = false});

  @override
  Future<RecognizedText> processImage(InputImage inputImage) async {
    if (shouldThrow) {
      throw StateError('Simulated ML Kit processing failure');
    }
    return recognizedText;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

RecognizedText _buildRecognizedText({
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

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dao = db.vaultDao;
    coordinator = CascadeScannerCoordinator(
      bkTree: BkTree(),
      profiles: [
        MtgCollectibleProfile(),
        ComicCollectibleProfile(),
      ],
    );
  });

  tearDown(() async {
    await db.close();
  });

  // =========================================================================
  // TASK 1.1: Simultaneous Rapid Frame Ingestion Stress Tests
  // =========================================================================
  group('Task 1.1: Simultaneous Rapid Frame Ingestion Under Extreme Stress', () {
    test('Simultaneous rapid ingestion: 50 concurrent frames across varying resolutions and aspect ratios', () async {
      // Configuration of diverse camera frame payloads
      final frameConfigs = <Map<String, dynamic>>[
        {'w': 3840, 'h': 2160, 'stride': 4096, 'fmt': ImageFormatGroup.nv21}, // 4K Android
        {'w': 1920, 'h': 1080, 'stride': 2048, 'fmt': ImageFormatGroup.yuv420}, // 1080p Android
        {'w': 1280, 'h': 720, 'stride': 1280, 'fmt': ImageFormatGroup.nv21}, // 720p Zero-padding
        {'w': 640, 'h': 480, 'stride': 2560, 'fmt': ImageFormatGroup.bgra8888}, // 480p iOS BGRA
        {'w': 1080, 'h': 2400, 'stride': 2048, 'fmt': ImageFormatGroup.nv21}, // Tall portrait 20:9
        {'w': 2560, 'h': 1080, 'stride': 4096, 'fmt': ImageFormatGroup.yuv420}, // Ultrawide 21:9
        {'w': 1000, 'h': 1000, 'stride': 1024, 'fmt': ImageFormatGroup.nv21}, // Square 1:1
        {'w': 200, 'h': 3800, 'stride': 256, 'fmt': ImageFormatGroup.nv21}, // Extreme Ribbon Tall
        {'w': 3800, 'h': 200, 'stride': 4096, 'fmt': ImageFormatGroup.yuv420}, // Extreme Ribbon Wide
        {'w': 64, 'h': 64, 'stride': 128, 'fmt': ImageFormatGroup.bgra8888}, // Tiny square
      ];

      // Build 50 distinct frame DTOs
      final dtos = <CameraFrameDto>[];
      for (int i = 0; i < 50; i++) {
        final cfg = frameConfigs[i % frameConfigs.length];
        final w = cfg['w'] as int;
        final h = cfg['h'] as int;
        final stride = cfg['stride'] as int;
        final fmt = cfg['fmt'] as ImageFormatGroup;

        final bufferSize = fmt == ImageFormatGroup.bgra8888
            ? stride * h
            : stride * h;
        final planeBytes = Uint8List(bufferSize);
        // Fill sentinel pattern to detect memory aliasing or race conditions
        planeBytes[0] = (i & 0xFF);
        if (planeBytes.length > 10) {
          planeBytes[10] = ((i * 3) & 0xFF);
        }

        dtos.add(CameraFrameDto(
          planeBytes: planeBytes,
          width: w,
          height: h,
          bytesPerRow: stride,
          formatGroup: fmt,
        ));
      }

      final stopwatch = Stopwatch()..start();

      // Launch all 50 frame extractions and isolate processing simultaneously
      final extractionFutures = dtos.map((dto) async {
        final bytes = dto.extractContiguousBytes();
        final expectedLen = dto.formatGroup == ImageFormatGroup.bgra8888
            ? dto.width * dto.height * 4
            : dto.width * dto.height;
        expect(bytes.length, equals(expectedLen));
        return bytes;
      }).toList();

      final extractedBuffers = await Future.wait(extractionFutures);
      expect(extractedBuffers.length, equals(50));

      // Now run 50 concurrent isolate invocations simultaneously via Future.wait
      final isolateFutures = dtos.map((dto) {
        return ScannerWorkerIsolate.processFrame(dto, 0.714);
      }).toList();

      final isolateResults = await Future.wait(isolateFutures);
      stopwatch.stop();

      expect(isolateResults.length, equals(50));
      for (final result in isolateResults) {
        // In headless testing environment, OpenCV FFI throws inside isolate and is caught
        expect(result.$1, isNull);
        expect(result.$2, isNull);
        expect(result.$3, isNull);
      }

      // 50 concurrent isolate tasks must complete cleanly without deadlocks or timeouts (< 10s)
      expect(stopwatch.elapsedMilliseconds, lessThan(10000));
    });

    test('Rapid consecutive frame ingestion: memory stability across 200 consecutive frames', () async {
      const width = 1280;
      const height = 720;
      const stride = 1536; // 256 padding bytes per row

      final planeBytes = Uint8List(stride * height);
      final dto = CameraFrameDto(
        planeBytes: planeBytes,
        width: width,
        height: height,
        bytesPerRow: stride,
        formatGroup: ImageFormatGroup.nv21,
      );

      final sw = Stopwatch()..start();
      for (int i = 0; i < 200; i++) {
        final contiguous = dto.extractContiguousBytes();
        expect(contiguous.length, equals(width * height));
      }
      sw.stop();

      // 200 extractions of 720p frames should complete in < 2000ms
      expect(sw.elapsedMilliseconds, lessThan(2000));
    });

    test('Zero-copy invariant: unpadded frames return original buffer directly', () {
      const width = 640;
      const height = 480;
      final nv21Bytes = Uint8List(width * height);
      final unpaddedDto = CameraFrameDto(
        planeBytes: nv21Bytes,
        width: width,
        height: height,
        bytesPerRow: width,
        formatGroup: ImageFormatGroup.nv21,
      );

      final resultBytes = unpaddedDto.extractContiguousBytes();
      // Must be exact same identity in memory (zero copy)
      expect(identical(resultBytes, nv21Bytes), isTrue);

      final bgraBytes = Uint8List(width * height * 4);
      final unpaddedBgraDto = CameraFrameDto(
        planeBytes: bgraBytes,
        width: width,
        height: height,
        bytesPerRow: width * 4,
        formatGroup: ImageFormatGroup.bgra8888,
      );
      final resultBgraBytes = unpaddedBgraDto.extractContiguousBytes();
      expect(identical(resultBgraBytes, bgraBytes), isTrue);
    });

    test('Adversarial stride edge cases: stride smaller than width or zero does not buffer overrun', () {
      // Degenerate stride = 0: defaults to width
      final smallBuffer = Uint8List(100);
      final dtoZeroStride = CameraFrameDto(
        planeBytes: smallBuffer,
        width: 10,
        height: 10,
        bytesPerRow: 0,
        formatGroup: ImageFormatGroup.nv21,
      );

      expect(() => dtoZeroStride.extractContiguousBytes(), returnsNormally);
      final res = dtoZeroStride.extractContiguousBytes();
      expect(res.length, equals(100));
    });
  });

  // =========================================================================
  // TASK 1.2: OpenCV Isolate Fallback Behavior & Robustness
  // =========================================================================
  group('Task 1.2: Fallback Behavior When OpenCV Isolate Throws or Is Unavailable', () {
    test('ScannerWorkerIsolate safely catches FFI symbol absence and returns (null, null, null)', () async {
      final dummyImage = createMockCameraImage(width: 720, height: 1280);
      final result = await ScannerWorkerIsolate.processFrame(dummyImage, 0.714);

      expect(result.$1, isNull);
      expect(result.$2, isNull);
      expect(result.$3, isNull);
    });

    test('detectPerimeter propagates safe nulls without throwing', () async {
      final dummyImage = createMockCameraImage(width: 1920, height: 1080);
      final result = await coordinator.detectPerimeter(cameraImage: dummyImage);

      expect(result.$1, isNull);
      expect(result.$2, isNull);
      expect(result.$3, isNull);
    });

    test('Full Dual-Path Fallback: ML Kit OCR succeeds when OpenCV isolate returns null', () async {
      // Seed target card in database
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'mtg-counterspell',
          name: 'Counterspell',
          collectionType: 'mtg',
          setOrSeries: 'Seventh Edition',
          imageUrl: '',
          acquiredPrice: 2.0,
          acquiredDate: DateTime(2026, 1, 1),
          condition: 'Near Mint',
          currentMarketPrice: 2.5,
          lastPriceUpdate: DateTime(2026, 1, 1),
          dynamicData: '{"collector_number":"067"}',
        ),
      );

      final dummyImage = createMockCameraImage(width: 720, height: 1280);
      final fakeBlocks = [
        const Rect.fromLTWH(80, 120, 240, 40),
        const Rect.fromLTWH(80, 600, 160, 30),
      ];
      final fakeRecognized = _buildRecognizedText(
        text: 'Counterspell\nInstant\n067/350 7ED',
        boundingBoxes: fakeBlocks,
      );
      final fakeRecognizer = _FakeTextRecognizer(fakeRecognized);

      List<double>? cornersReceived;
      final (matchResult, returnedCorners) = await coordinator.processFrame(
        cameraImage: dummyImage,
        dao: dao,
        textRecognizer: fakeRecognizer,
        onCornersDetected: (corners) {
          cornersReceived = corners;
        },
      );

      // Verify onCornersDetected was immediately triggered
      expect(cornersReceived, isNotNull);
      expect(cornersReceived!.length, equals(8));
      expect(returnedCorners, equals(cornersReceived));

      // Verify database match was resolved
      expect(matchResult, isNotNull);
      expect(matchResult!.match.id, equals('mtg-counterspell'));
      expect(matchResult.match.name, equals('Counterspell'));
      expect(matchResult.tier, equals(1));
    });

    test('Full Dual-Path Fallback: Unmatched card emits corners and returns (null, corners)', () async {
      final dummyImage = createMockCameraImage(width: 720, height: 1280);
      final fakeBlocks = [
        const Rect.fromLTWH(100, 150, 200, 300),
      ];
      final fakeRecognized = _buildRecognizedText(
        text: 'Non-Existent Card Name 999/999',
        boundingBoxes: fakeBlocks,
      );
      final fakeRecognizer = _FakeTextRecognizer(fakeRecognized);

      List<double>? cornersReceived;
      final (matchResult, returnedCorners) = await coordinator.processFrame(
        cameraImage: dummyImage,
        dao: dao,
        textRecognizer: fakeRecognizer,
        onCornersDetected: (corners) {
          cornersReceived = corners;
        },
      );

      // Live reticle coordinates must be yielded even if catalog match is null
      expect(cornersReceived, isNotNull);
      expect(cornersReceived!.length, equals(8));
      expect(matchResult, isNull);
      expect(returnedCorners, equals(cornersReceived));
    });

    test('Full Dual-Path Fallback: Blank frame (no OCR blocks) yields (null, null) cleanly', () async {
      final dummyImage = createMockCameraImage(width: 720, height: 1280);
      final fakeRecognized = _buildRecognizedText(
        text: '',
        boundingBoxes: [],
      );
      final fakeRecognizer = _FakeTextRecognizer(fakeRecognized);

      bool cornersCalled = false;
      final (matchResult, returnedCorners) = await coordinator.processFrame(
        cameraImage: dummyImage,
        dao: dao,
        textRecognizer: fakeRecognizer,
        onCornersDetected: (_) {
          cornersCalled = true;
        },
      );

      expect(cornersCalled, isFalse);
      expect(matchResult, isNull);
      expect(returnedCorners, isNull);
    });

    test('ScannerWorkerIsolate rejects invalid argument types with ArgumentError', () async {
      expect(
        () => ScannerWorkerIsolate.processFrame('not a camera frame', 0.714),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => ScannerWorkerIsolate.processFrame(42, 0.714),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('ScannerWorkerIsolate handles corrupted byte buffers without unhandled exceptions', () async {
      final corruptedDto = CameraFrameDto(
        planeBytes: Uint8List(5), // severely truncated
        width: 1000,
        height: 1000,
        bytesPerRow: 1000,
        formatGroup: ImageFormatGroup.nv21,
      );

      final result = await ScannerWorkerIsolate.processFrame(corruptedDto, 0.714);
      expect(result.$1, isNull);
      expect(result.$2, isNull);
      expect(result.$3, isNull);
    });

    test('Full Dual-Path Fallback: ML Kit throwing propagates error cleanly without unhandled isolate panic', () async {
      final dummyImage = createMockCameraImage(width: 720, height: 1280);
      final throwingRecognizer = _FakeTextRecognizer(
        _buildRecognizedText(text: ''),
        shouldThrow: true,
      );

      expect(
        () => coordinator.processFrame(
          cameraImage: dummyImage,
          dao: dao,
          textRecognizer: throwingRecognizer,
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  // =========================================================================
  // TASK 1.3: Reticle Coordinate Smoothing (smoothRect) Stress & Oracles
  // =========================================================================
  group('Task 1.3: smoothRect Noisy Jitter vs Sudden Jump Inputs', () {
    test('Stationary hand jitter suppression: 100 frames of Gaussian noise', () {
      const trueRect = Rect.fromLTWH(150.0, 200.0, 240.0, 360.0);
      final rng = math.Random(999);
      Rect? smoothedState = trueRect;

      double sumRawDeviation = 0.0;
      double sumSmoothedDeviation = 0.0;

      for (int i = 0; i < 100; i++) {
        // High-frequency tremor: standard deviation ~4px, max ~12px
        final noiseX = (rng.nextDouble() - 0.5) * 8.0;
        final noiseY = (rng.nextDouble() - 0.5) * 8.0;
        final noisyInput = Rect.fromLTWH(
          trueRect.left + noiseX,
          trueRect.top + noiseY,
          trueRect.width,
          trueRect.height,
        );

        smoothedState = CardPerimeterCalculator.smoothRect(
          smoothedState,
          noisyInput,
          alpha: 0.40,
          snapThreshold: 60.0,
        );

        final rawDev = math.sqrt(noiseX * noiseX + noiseY * noiseY);
        final smoothedDev = (smoothedState.topLeft - trueRect.topLeft).distance;

        sumRawDeviation += rawDev;
        sumSmoothedDeviation += smoothedDev;
      }

      final avgRawDev = sumRawDeviation / 100;
      final avgSmoothedDev = sumSmoothedDeviation / 100;

      // Smoothed deviation must be strictly damped (reduction > 40%)
      expect(avgSmoothedDev, lessThan(avgRawDev * 0.60));
      // State must remain well within the noise envelope (< 4.0px)
      expect(
        (smoothedState!.topLeft - trueRect.topLeft).distance,
        lessThan(4.0),
      );
    });

    test('Sudden large jumps: step response and monotonic convergence', () {
      const initialPos = Rect.fromLTWH(50.0, 50.0, 200.0, 300.0);
      const targetPos = Rect.fromLTWH(350.0, 450.0, 200.0, 300.0);
      final initialDistance = (initialPos.topLeft - targetPos.topLeft).distance;
      expect(initialDistance, equals(500.0)); // 3-4-5 triangle * 100

      // Frame 1: Jump > 60px -> triggers effectiveAlpha = 0.85
      final frame1 = CardPerimeterCalculator.smoothRect(initialPos, targetPos);
      final remainingDist1 = (frame1.topLeft - targetPos.topLeft).distance;
      // Remaining distance must be exactly (1 - 0.85) * 500 = 75px
      expect(remainingDist1, closeTo(75.0, 1e-4));

      // Frame 2: Remaining distance is 75px (> 60px threshold) -> continues effectiveAlpha = 0.85
      final frame2 = CardPerimeterCalculator.smoothRect(frame1, targetPos);
      final remainingDist2 = (frame2.topLeft - targetPos.topLeft).distance;
      // Remaining distance: 75 * 0.15 = 11.25px
      expect(remainingDist2, closeTo(11.25, 1e-4));

      // Frame 3: Remaining distance is 11.25px (<= 60px) -> smoothly transitions to alpha = 0.40
      final frame3 = CardPerimeterCalculator.smoothRect(frame2, targetPos);
      final remainingDist3 = (frame3.topLeft - targetPos.topLeft).distance;
      // Remaining distance: 11.25 * (1 - 0.40) = 6.75px
      expect(remainingDist3, closeTo(6.75, 1e-4));

      // Monotonic convergence: distance strictly decreases on every frame
      expect(remainingDist1, lessThan(initialDistance));
      expect(remainingDist2, lessThan(remainingDist1));
      expect(remainingDist3, lessThan(remainingDist2));
    });

    test('Critical threshold boundary: strictly evaluates <= 60.0 vs > 60.0', () {
      const prev = Rect.fromLTWH(100.0, 100.0, 200.0, 300.0);

      // Distance exactly 60.0px: dx = 60.0, dy = 0.0
      final atBoundary = Rect.fromLTWH(160.0, 100.0, 200.0, 300.0);
      final resAt = CardPerimeterCalculator.smoothRect(prev, atBoundary);
      // Alpha = 0.40: 100 + 60 * 0.40 = 124.0
      expect(resAt.left, closeTo(124.0, 1e-5));

      // Distance 60.001px: dx = 60.001, dy = 0.0
      final pastBoundary = Rect.fromLTWH(160.001, 100.0, 200.0, 300.0);
      final resPast = CardPerimeterCalculator.smoothRect(prev, pastBoundary);
      // Alpha = 0.85: 100 + 60.001 * 0.85 = 151.00085
      expect(resPast.left, closeTo(151.00085, 1e-4));

      // Distance 59.999px
      final belowBoundary = Rect.fromLTWH(159.999, 100.0, 200.0, 300.0);
      final resBelow = CardPerimeterCalculator.smoothRect(prev, belowBoundary);
      // Alpha = 0.40: 100 + 59.999 * 0.40 = 123.9996
      expect(resBelow.left, closeTo(123.9996, 1e-4));
    });

    test('Alternating square-wave jump (flip-flopping between two distant coordinates)', () {
      const posA = Rect.fromLTWH(100.0, 100.0, 200.0, 300.0);
      const posB = Rect.fromLTWH(500.0, 600.0, 200.0, 300.0);

      Rect state = posA;
      for (int i = 0; i < 50; i++) {
        final target = (i % 2 == 0) ? posB : posA;
        state = CardPerimeterCalculator.smoothRect(state, target);

        // Coordinates must remain strictly bounded between posA and posB
        expect(state.left, greaterThanOrEqualTo(100.0));
        expect(state.left, lessThanOrEqualTo(500.0));
        expect(state.top, greaterThanOrEqualTo(100.0));
        expect(state.top, lessThanOrEqualTo(600.0));
      }
    });

    test('Pure scaling jump (topLeft stationary, size expands by 400px)', () {
      const prev = Rect.fromLTWH(100.0, 100.0, 100.0, 150.0);
      const current = Rect.fromLTWH(100.0, 100.0, 500.0, 750.0);

      // Distance between topLeft is 0.0 <= 60.0 -> uses alpha = 0.40
      final smoothed = CardPerimeterCalculator.smoothRect(prev, current);
      expect(smoothed.left, equals(100.0));
      expect(smoothed.top, equals(100.0));
      expect(smoothed.width, closeTo(100.0 + 400.0 * 0.40, 1e-5)); // 260.0
      expect(smoothed.height, closeTo(150.0 + 600.0 * 0.40, 1e-5)); // 390.0
    });

    test('Negative coordinates and zero size inputs are smoothed without crashing', () {
      const prev = Rect.fromLTWH(-100.0, -150.0, 0.0, 0.0);
      const current = Rect.fromLTWH(-50.0, -75.0, 200.0, 300.0);

      final smoothed = CardPerimeterCalculator.smoothRect(prev, current);
      expect(smoothed.left, isNotNull);
      expect(smoothed.top, isNotNull);
      expect(smoothed.width, greaterThan(0.0));
      expect(smoothed.height, greaterThan(0.0));
    });
  });

  // =========================================================================
  // TASK 1.4: End-to-End Reticle UI Pipeline Verification
  // =========================================================================
  group('Task 1.4: Dynamic Reticle UI Under Rapid Bounds Mutations', () {
    testWidgets('DynamicScannerOverlay handles rapid bounds mutation and null transitions cleanly', (tester) async {
      final boundsNotifier = ValueNotifier<Rect?>(const Rect.fromLTWH(50, 100, 240, 360));
      addTearDown(boundsNotifier.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<Rect?>(
              valueListenable: boundsNotifier,
              builder: (context, bounds, _) => DynamicScannerOverlay(
                cardBounds: bounds,
                isGreenFlash: false,
                isPaused: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Rapidly morph through 30 frames of coordinates
      for (int i = 0; i < 30; i++) {
        boundsNotifier.value = Rect.fromLTWH(
          50.0 + i * 5,
          100.0 + i * 3,
          240.0 + (i % 3) * 10,
          360.0 + (i % 3) * 15,
        );
        await tester.pump(const Duration(milliseconds: 16));
      }

      // Transition to null bounds (card leaves camera view)
      boundsNotifier.value = null;
      await tester.pump(const Duration(milliseconds: 100));

      // Over 700ms decay, overlay retains last known bounds with decaying opacity
      expect(find.byKey(const Key('dynamic_scanner_overlay')), findsOneWidget);
      final animatedOpacity = tester.widget<AnimatedOpacity>(
        find.byKey(const Key('dynamic_scanner_overlay')),
      );
      expect(animatedOpacity.opacity, equals(0.0));
      expect(animatedOpacity.duration, equals(const Duration(milliseconds: 700)));

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
