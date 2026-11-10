import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/sync/market_price_sync_service.dart';

class MockFirestorePriceSyncClient implements FirestorePriceSyncClient {
  MarketSyncMetadata? metadata;
  Exception? throwError;
  int readCount = 0;

  @override
  Future<MarketSyncMetadata?> getMarketSyncMetadata() async {
    readCount++;
    if (throwError != null) throw throwError!;
    return metadata;
  }
}

class MockStoragePriceSyncClient implements StoragePriceSyncClient {
  Uint8List? payload;
  Exception? throwError;
  int downloadCount = 0;
  String? lastPath;

  @override
  Future<Uint8List> downloadGzipPrices(String storagePath) async {
    downloadCount++;
    lastPath = storagePath;
    if (throwError != null) throw throwError!;
    return payload ?? Uint8List(0);
  }
}

Uint8List createGzipPayload(Map<String, dynamic> data) {
  final jsonStr = jsonEncode(data);
  return Uint8List.fromList(GZipCodec().encode(utf8.encode(jsonStr)));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late MockFirestorePriceSyncClient firestoreClient;
  late MockStoragePriceSyncClient storageClient;
  late InMemorySyncPreferences preferences;
  late MarketPriceSyncService service;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    firestoreClient = MockFirestorePriceSyncClient();
    storageClient = MockStoragePriceSyncClient();
    preferences = InMemorySyncPreferences();
    service = MarketPriceSyncService(
      firestoreClient: firestoreClient,
      storageClient: storageClient,
      preferences: preferences,
      db: db,
    );

    // Seed test cards in vault_items
    await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'card-1',
            name: 'Black Lotus',
            collectionType: 'mtg',
            setOrSeries: 'LEA',
            imageUrl: 'https://example.com/lotus.jpg',
            acquiredPrice: 100.0,
            acquiredDate: DateTime.utc(2026, 1, 1),
            condition: 'NM',
            currentMarketPrice: 5000.0,
            lastPriceUpdate: DateTime.utc(2026, 1, 1),
            dynamicData: '{}',
          ),
        );
    await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'card-2',
            name: 'Mox Sapphire',
            collectionType: 'mtg',
            setOrSeries: 'LEA',
            imageUrl: 'https://example.com/mox.jpg',
            acquiredPrice: 50.0,
            acquiredDate: DateTime.utc(2026, 1, 1),
            condition: 'NM',
            currentMarketPrice: 2000.0,
            lastPriceUpdate: DateTime.utc(2026, 1, 1),
            dynamicData: '{}',
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  group('MarketPriceSyncService - Core Flow & Tiers', () {
    test('Tier 1: Sync exits early after 1 Firestore read when cached timestamp is newer or equal', () async {
      await preferences.setLastPriceSyncTimestamp(1000);
      firestoreClient.metadata = const MarketSyncMetadata(
        timestamp: 1000,
        version: 'v1',
        storagePath: 'market_prices/latest.json.gz',
      );

      final result = await service.checkAndUpdatePrices();

      expect(result.status, equals(MarketPriceSyncStatus.alreadyUpToDate));
      expect(firestoreClient.readCount, equals(1));
      expect(storageClient.downloadCount, equals(0));
    });

    test('Tier 1: Sync downloads gzip, decompresses, and updates database when remote timestamp is newer', () async {
      await preferences.setLastPriceSyncTimestamp(1000);
      firestoreClient.metadata = const MarketSyncMetadata(
        timestamp: 2000,
        version: 'v1',
        storagePath: 'market_prices/latest.json.gz',
      );

      final payloadData = {
        'version': 'v1',
        'updatedAt': '2026-10-30T03:00:00Z',
        'prices': {
          'card-1': 5500.0,
          'card-2': {'usd': '2200.00', 'usd_foil': '3500.00'},
        },
      };
      storageClient.payload = createGzipPayload(payloadData);

      final result = await service.checkAndUpdatePrices();

      expect(result.status, equals(MarketPriceSyncStatus.success));
      expect(result.cardsUpdated, equals(2));
      expect(firestoreClient.readCount, equals(1));
      expect(storageClient.downloadCount, equals(1));

      // Verify database updated
      final card1 = await (db.select(db.vaultItems)..where((t) => t.id.equals('card-1'))).getSingle();
      expect(card1.currentMarketPrice, equals(5500.0));

      final card2 = await (db.select(db.vaultItems)..where((t) => t.id.equals('card-2'))).getSingle();
      expect(card2.currentMarketPrice, equals(2200.0));

      // Verify preferences updated
      final savedTs = await preferences.getLastPriceSyncTimestamp();
      expect(savedTs, equals(2000));
    });

    test('Tier 1: force=true forces download and database write even if timestamp matches cached value', () async {
      await preferences.setLastPriceSyncTimestamp(2000);
      firestoreClient.metadata = const MarketSyncMetadata(
        timestamp: 2000,
        version: 'v1',
      );

      final payloadData = {
        'prices': {
          'card-1': 5999.0,
        },
      };
      storageClient.payload = createGzipPayload(payloadData);

      final result = await service.checkAndUpdatePrices(force: true);

      expect(result.status, equals(MarketPriceSyncStatus.success));
      expect(storageClient.downloadCount, equals(1));

      final card1 = await (db.select(db.vaultItems)..where((t) => t.id.equals('card-1'))).getSingle();
      expect(card1.currentMarketPrice, equals(5999.0));
    });

    test('Tier 2: Filters out non-positive, negative, NaN, and Infinite prices in isolate', () async {
      final payloadData = {
        'prices': {
          'card-valid': 12.50,
          'card-negative': -10.0,
          'card-zero': 0.0,
          'card-nan': 'NaN',
          'card-map-zero': {'usd': '0.00'},
          'card-map-valid': {'usd': null, 'usd_foil': '45.00'},
        },
      };
      final gzipped = createGzipPayload(payloadData);

      final map = await MarketPriceSyncService.parseGzipPricesInIsolate(gzipped);

      expect(map.containsKey('card-valid'), isTrue);
      expect(map['card-valid'], equals(12.50));
      expect(map.containsKey('card-map-valid'), isTrue);
      expect(map['card-map-valid'], equals(45.00));
      expect(map.containsKey('card-negative'), isFalse);
      expect(map.containsKey('card-zero'), isFalse);
      expect(map.containsKey('card-nan'), isFalse);
      expect(map.containsKey('card-map-zero'), isFalse);
    });

    test('Tier 2: Handles empty price payload gracefully', () async {
      firestoreClient.metadata = const MarketSyncMetadata(
        timestamp: 5000,
        version: 'v1',
      );
      storageClient.payload = createGzipPayload({'prices': {}});

      final result = await service.checkAndUpdatePrices();

      expect(result.status, equals(MarketPriceSyncStatus.failed));
      expect(result.errorMessage, contains('Parsed 0 card prices'));
    });

    test('Tier 2: Deserializes flexible metadata formats (int, ISO string, DateTime)', () {
      final meta1 = MarketSyncMetadata.fromMap({
        'timestamp': 1698700000000,
        'version': 'v1',
      });
      expect(meta1.timestamp, equals(1698700000000));

      final meta2 = MarketSyncMetadata.fromMap({
        'timestamp': '2026-10-30T03:00:00Z',
        'version': 'v1',
      });
      expect(meta2.timestamp, equals(DateTime.parse('2026-10-30T03:00:00Z').millisecondsSinceEpoch));
    });

    test('Tier 3: Dual-format normalization obeys hierarchy (usd -> usd_foil -> usd_etched -> eur -> eur_foil)', () async {
      final payloadData = {
        'prices': {
          'foil-only': {'usd': null, 'usd_foil': '99.50', 'eur': '80.00'},
          'eur-only': {'usd': null, 'usd_foil': null, 'eur': '15.00'},
        },
      };
      final gzipped = createGzipPayload(payloadData);
      final map = await MarketPriceSyncService.parseGzipPricesInIsolate(gzipped);

      expect(map['foil-only'], equals(99.50));
      expect(map['eur-only'], equals(15.00));
    });

    test('Tier 4: Chunked batch update processes large batches with progress callback', () async {
      firestoreClient.metadata = const MarketSyncMetadata(
        timestamp: 99999,
        version: 'v1',
      );

      // Create 1200 dummy price entries
      final Map<String, double> bigPriceMap = {};
      for (var i = 1; i <= 1200; i++) {
        bigPriceMap['card-$i'] = i.toDouble();
      }
      storageClient.payload = createGzipPayload({'prices': bigPriceMap});

      final progressSteps = <int>[];
      final result = await service.checkAndUpdatePrices(
        onProgress: (processed, total) {
          progressSteps.add(processed);
        },
      );

      expect(result.status, equals(MarketPriceSyncStatus.success));
      expect(result.cardsUpdated, equals(1200));
      // 1200 items chunked by 500 produces steps: 500, 1000, 1200
      expect(progressSteps, equals([500, 1000, 1200]));
    });

    test('Tier 5: Corrupted gzip bytes caught safely and database untouched', () async {
      firestoreClient.metadata = const MarketSyncMetadata(
        timestamp: 8888,
        version: 'v1',
      );
      storageClient.payload = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7]); // invalid gzip

      final result = await service.checkAndUpdatePrices();

      expect(result.status, equals(MarketPriceSyncStatus.failed));
      expect(result.errorMessage, contains('Failed to decompress or parse gzip payload'));

      // Check database remained intact
      final card1 = await (db.select(db.vaultItems)..where((t) => t.id.equals('card-1'))).getSingle();
      expect(card1.currentMarketPrice, equals(5000.0));
    });

    test('Tier 5: Network error during Firestore or Storage returns networkUnavailable', () async {
      firestoreClient.throwError = Exception('Connection refused');

      final result = await service.checkAndUpdatePrices();

      expect(result.status, equals(MarketPriceSyncStatus.networkUnavailable));
      expect(result.errorMessage, contains('Connection refused'));
    });
  });
}
