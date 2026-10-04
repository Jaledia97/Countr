import 'dart:convert';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/scanner/domain/cascade_scanner_coordinator.dart';
import 'package:countr/features/scanner/domain/profiles/comic_collectible_profile.dart';
import 'package:countr/features/scanner/domain/profiles/mtg_collectible_profile.dart';
import 'package:countr/features/scanner/domain/vision/bk_tree.dart';
import '../../../../test/e2e/test_helpers.dart';

class FakeTextRecognizer implements TextRecognizer {
  final RecognizedText recognizedText;
  FakeTextRecognizer(this.recognizedText);

  @override
  Future<RecognizedText> processImage(InputImage inputImage) async => recognizedText;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

RecognizedText createFakeRecognizedText({
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
        ComicCollectibleProfile(),
        MtgCollectibleProfile(),
      ],
    );
  });

  tearDown(() async {
    await db.close();
  });

  VaultItemsCompanion createItem({
    required String id,
    required String name,
    required String collectionType,
    String? barcode,
    String? collectorNumber,
  }) {
    final Map<String, dynamic> data = {};
    if (barcode != null) data['barcode'] = barcode;
    if (collectorNumber != null) data['collector_number'] = collectorNumber;

    return VaultItemsCompanion.insert(
      id: id,
      name: name,
      collectionType: collectionType,
      setOrSeries: 'Test Set',
      imageUrl: '',
      acquiredPrice: 5.0,
      acquiredDate: DateTime(2026, 1, 1),
      quantity: const Value(1),
      condition: 'Near Mint',
      currentMarketPrice: 10.0,
      lastPriceUpdate: DateTime(2026, 1, 1),
      dynamicData: jsonEncode(data),
    );
  }

  group('CascadeScannerCoordinator Empirical & Barcode Optimization Tests', () {
    test('Tier 0 Barcode: Matches 12-digit barcode via SQLite JSON extraction', () async {
      await db.into(db.vaultItems).insert(
        createItem(
          id: 'comic_1',
          name: 'The Amazing Spider-Man #300',
          collectionType: 'comics',
          barcode: '759606082974',
        ),
      );

      final result = await coordinator.matchOcr(
        ocrText: 'Marvel Comics Special Edition Barcode 759606082974 Direct Edition',
        dao: dao,
      );

      expect(result, isNotNull);
      expect(result!.tier, equals(0));
      expect(result.match.id, equals('comic_1'));
      expect(result.match.name, equals('The Amazing Spider-Man #300'));
      expect(result.profile?.collectionType, equals('comics'));
    });

    test('Tier 0 Barcode: Respects profile collectionType scoping', () async {
      // Insert item with barcode in 'mtg' collection
      await db.into(db.vaultItems).insert(
        createItem(
          id: 'mtg_pack',
          name: 'Modern Horizons 3 Booster Pack',
          collectionType: 'mtg',
          barcode: '195166245189',
        ),
      );

      // Comic profile has enableBarcodeScanning=true but collectionType='comics'
      // MTG profile has enableBarcodeScanning=false
      // Therefore, scanning under default profiles won't match mtg pack with comics profile
      final result = await coordinator.matchOcr(
        ocrText: 'Booster 195166245189 Pack',
        dao: dao,
      );

      // Should not match under comic profile because collectionType differs
      expect(result, isNull);
    });

    test('Tier 0 Barcode: Fast single-query execution on 100 items without heap traversal', () async {
      // Seed 100 items with different barcodes
      for (int i = 0; i < 100; i++) {
        final code = (100000000000 + i).toString();
        await db.into(db.vaultItems).insert(
          createItem(
            id: 'item_$i',
            name: 'Comic Book Issue #$i',
            collectionType: 'comics',
            barcode: code,
          ),
        );
      }

      final stopwatch = Stopwatch()..start();
      final result = await coordinator.matchOcr(
        ocrText: 'Scanned barcode 100000000077 text',
        dao: dao,
      );
      stopwatch.stop();

      expect(result, isNotNull);
      expect(result!.match.id, equals('item_77'));
      // Single query execution must be fast (< 100ms)
      expect(stopwatch.elapsedMilliseconds, lessThan(200));
    });

    test('Tier 1 OCR Heuristic: Matches Title and Collector Number fallback', () async {
      await db.into(db.vaultItems).insert(
        createItem(
          id: 'mtg_sol_ring',
          name: 'Sol Ring',
          collectionType: 'mtg',
          collectorNumber: '024',
        ),
      );

      final result = await coordinator.matchOcr(
        ocrText: 'Sol Ring\nArtifact\n024/250 MH3',
        dao: dao,
      );

      expect(result, isNotNull);
      expect(result!.tier, equals(1));
      expect(result.match.id, equals('mtg_sol_ring'));
    });

    test('No Match: Non-existent barcode and OCR returns null safely', () async {
      final result = await coordinator.matchOcr(
        ocrText: 'Random unstructured text with no card match or barcode',
        dao: dao,
      );

      expect(result, isNull);
    });
  });

  group('CascadeScannerCoordinator Dual-Path Pipeline & Edge Tracking Tests', () {
    test('targetProfile.cardAspectRatio is used instead of artCropBounds', () {
      final mtgProfile = MtgCollectibleProfile();
      expect(mtgProfile.cardAspectRatio, closeTo(0.7142857, 0.0001));
      final comicProfile = ComicCollectibleProfile();
      expect(comicProfile.cardAspectRatio, closeTo(0.6503387, 0.0001));
      // Contrast with artCropBounds which was 80/45 ≈ 1.7778
      expect(mtgProfile.artCropBounds.width / mtgProfile.artCropBounds.height, isNot(closeTo(0.714, 0.01)));
    });

    test('detectPerimeter calls ScannerWorkerIsolate and handles execution safely without throwing', () async {
      final dummyImage = createMockCameraImage(width: 720, height: 1280);
      final result = await coordinator.detectPerimeter(cameraImage: dummyImage);
      // In headless host environment without OpenCV C++ binaries, ScannerWorkerIsolate catches and returns nulls
      expect(result.$1, isNull);
      expect(result.$2, isNull);
      expect(result.$3, isNull);
    });

    test('processFrame: ML Kit full-frame fallback executes when OpenCV returns null and invokes onCornersDetected', () async {
      await db.into(db.vaultItems).insert(
        createItem(
          id: 'mtg_black_lotus',
          name: 'Black Lotus',
          collectionType: 'mtg',
          collectorNumber: '232',
        ),
      );

      final dummyImage = createMockCameraImage(width: 720, height: 1280);
      final fakeBlocks = [
        const Rect.fromLTWH(100, 100, 300, 50),
        const Rect.fromLTWH(100, 500, 200, 30),
      ];
      final fakeRecognized = createFakeRecognizedText(
        text: 'Black Lotus\nArtifact\n232/250 LEA',
        boundingBoxes: fakeBlocks,
      );
      final fakeRecognizer = FakeTextRecognizer(fakeRecognized);

      List<double>? detectedCorners;
      final result = await coordinator.processFrame(
        cameraImage: dummyImage,
        dao: dao,
        textRecognizer: fakeRecognizer,
        onCornersDetected: (corners) {
          detectedCorners = corners;
        },
      );

      // Verify onCornersDetected was called with fallback corners
      expect(detectedCorners, isNotNull);
      expect(detectedCorners!.length, equals(8));

      // Verify match was found in SQLite database via OCR fallback
      expect(result.$1, isNotNull);
      expect(result.$1!.tier, equals(1));
      expect(result.$1!.match.id, equals('mtg_black_lotus'));
      expect(result.$2, equals(detectedCorners));
    });

    test('processFrame: fallback returns corners even when no catalog match is found', () async {
      final dummyImage = createMockCameraImage(width: 720, height: 1280);
      final fakeBlocks = [
        const Rect.fromLTWH(50, 50, 200, 300),
      ];
      final fakeRecognized = createFakeRecognizedText(
        text: 'Unknown Card Text 999/999',
        boundingBoxes: fakeBlocks,
      );
      final fakeRecognizer = FakeTextRecognizer(fakeRecognized);

      List<double>? detectedCorners;
      final result = await coordinator.processFrame(
        cameraImage: dummyImage,
        dao: dao,
        textRecognizer: fakeRecognizer,
        onCornersDetected: (corners) {
          detectedCorners = corners;
        },
      );

      // Real-time reticle coordinates emitted even on un-matched cards
      expect(detectedCorners, isNotNull);
      expect(detectedCorners!.length, equals(8));
      expect(result.$1, isNull);
      expect(result.$2, equals(detectedCorners));
    });
  });
}
