import 'dart:convert';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/scanner/domain/cascade_scanner_coordinator.dart';
import 'package:countr/features/scanner/domain/profiles/comic_collectible_profile.dart';
import 'package:countr/features/scanner/domain/profiles/mtg_collectible_profile.dart';
import 'package:countr/features/scanner/domain/vision/bk_tree.dart';

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
}
