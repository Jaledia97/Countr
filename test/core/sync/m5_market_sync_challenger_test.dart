import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/sync/market_price_sync_service.dart';

class ChallengerFirestoreClient implements FirestorePriceSyncClient {
  MarketSyncMetadata? metadata;
  Exception? throwError;
  int readCount = 0;
  Duration? simulatedDelay;

  @override
  Future<MarketSyncMetadata?> getMarketSyncMetadata() async {
    readCount++;
    if (simulatedDelay != null) {
      await Future<void>.delayed(simulatedDelay!);
    }
    if (throwError != null) throw throwError!;
    return metadata;
  }
}

class ChallengerStorageClient implements StoragePriceSyncClient {
  Uint8List? payload;
  Exception? throwError;
  int downloadCount = 0;
  String? lastPath;
  Duration? simulatedDelay;

  @override
  Future<Uint8List> downloadGzipPrices(String storagePath) async {
    downloadCount++;
    lastPath = storagePath;
    if (simulatedDelay != null) {
      await Future<void>.delayed(simulatedDelay!);
    }
    if (throwError != null) throw throwError!;
    return payload ?? Uint8List(0);
  }
}

class ChallengerPreferences implements SyncPreferences {
  int? _timestamp;
  int getCount = 0;
  int setCount = 0;

  ChallengerPreferences([this._timestamp]);

  @override
  Future<int?> getLastPriceSyncTimestamp() async {
    getCount++;
    return _timestamp;
  }

  @override
  Future<void> setLastPriceSyncTimestamp(int timestamp) async {
    setCount++;
    _timestamp = timestamp;
  }
}

Uint8List createGzip(dynamic data) {
  final jsonStr = jsonEncode(data);
  return Uint8List.fromList(GZipCodec().encode(utf8.encode(jsonStr)));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ChallengerFirestoreClient firestoreClient;
  late ChallengerStorageClient storageClient;
  late ChallengerPreferences preferences;
  late MarketPriceSyncService service;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    firestoreClient = ChallengerFirestoreClient();
    storageClient = ChallengerStorageClient();
    preferences = ChallengerPreferences();
    service = MarketPriceSyncService(
      firestoreClient: firestoreClient,
      storageClient: storageClient,
      preferences: preferences,
      db: db,
    );

    // Seed baseline inventory
    await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'card-lotus',
            name: 'Black Lotus',
            collectionType: 'mtg',
            setOrSeries: 'LEA',
            imageUrl: 'https://example.com/lotus.jpg',
            acquiredPrice: 1000.0,
            acquiredDate: DateTime.utc(2026, 1, 1),
            condition: 'NM',
            currentMarketPrice: 5000.0,
            lastPriceUpdate: DateTime.utc(2026, 1, 1),
            dynamicData: '{}',
          ),
        );
    await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'card-mox',
            name: 'Mox Pearl',
            collectionType: 'mtg',
            setOrSeries: 'LEA',
            imageUrl: 'https://example.com/mox.jpg',
            acquiredPrice: 500.0,
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

  group('Adversarial Challenge 1: Corrupt & Truncated Gzip Data', () {
    test('Truncated gzip byte stream fails gracefully and does not throw unhandled error', () async {
      final validPayload = createGzip({
        'prices': {'card-lotus': 9999.0}
      });
      // Truncate halfway through gzip stream
      final truncatedBytes = validPayload.sublist(0, validPayload.length ~/ 2);

      firestoreClient.metadata = const MarketSyncMetadata(
        timestamp: 2000,
        version: 'v1',
      );
      storageClient.payload = truncatedBytes;

      final result = await service.checkAndUpdatePrices();

      expect(result.status, equals(MarketPriceSyncStatus.failed));
      expect(result.errorMessage, contains('Failed to decompress or parse gzip payload'));

      // Verify SQLite was NOT corrupted or modified
      final card = await (db.select(db.vaultItems)..where((t) => t.id.equals('card-lotus'))).getSingle();
      expect(card.currentMarketPrice, equals(5000.0));
      expect(card.lastPriceUpdate.toUtc(), equals(DateTime.utc(2026, 1, 1)));
    });

    test('Valid gzip stream containing invalid UTF-8 bytes fails gracefully', () async {
      // Gzip compress raw non-UTF8 binary data (0xFF 0xFE invalid UTF-8)
      final invalidUtf8Bytes = Uint8List.fromList([0xFF, 0xFE, 0xFD, 0xFC, 0x80, 0x81]);
      final gzipped = Uint8List.fromList(GZipCodec().encode(invalidUtf8Bytes));

      firestoreClient.metadata = const MarketSyncMetadata(timestamp: 3000, version: 'v1');
      storageClient.payload = gzipped;

      final result = await service.checkAndUpdatePrices();

      expect(result.status, equals(MarketPriceSyncStatus.failed));
      expect(result.errorMessage, contains('Failed to decompress or parse gzip payload'));

      // Check SQLite remains intact
      final card = await (db.select(db.vaultItems)..where((t) => t.id.equals('card-lotus'))).getSingle();
      expect(card.currentMarketPrice, equals(5000.0));
    });

    test('Valid gzip stream containing malformed JSON syntax fails gracefully', () async {
      // Compress unclosed/broken JSON string
      const brokenJson = '{"prices": {"card-lotus": 7777.0, broken_json...';
      final gzipped = Uint8List.fromList(GZipCodec().encode(utf8.encode(brokenJson)));

      firestoreClient.metadata = const MarketSyncMetadata(timestamp: 4000, version: 'v1');
      storageClient.payload = gzipped;

      final result = await service.checkAndUpdatePrices();

      expect(result.status, equals(MarketPriceSyncStatus.failed));
      expect(result.errorMessage, contains('Failed to decompress or parse gzip payload'));
    });

    test('Valid gzip stream containing non-map root (array or primitive) returns failed', () async {
      final gzippedArray = createGzip([1, 2, 3, 4, 5]);

      firestoreClient.metadata = const MarketSyncMetadata(timestamp: 5000, version: 'v1');
      storageClient.payload = gzippedArray;

      final result = await service.checkAndUpdatePrices();

      expect(result.status, equals(MarketPriceSyncStatus.failed));
      expect(result.errorMessage, contains('Parsed 0 card prices from payload'));
    });

    test('Gzip failure cleanly resets isSyncing flag allowing next sync to execute', () async {
      firestoreClient.metadata = const MarketSyncMetadata(timestamp: 5000, version: 'v1');
      storageClient.payload = Uint8List.fromList([1, 2, 3]); // invalid gzip

      // First run: fails
      final failResult = await service.checkAndUpdatePrices();
      expect(failResult.status, equals(MarketPriceSyncStatus.failed));
      expect(service.isSyncing, isFalse);

      // Second run with valid data: should succeed immediately
      storageClient.payload = createGzip({
        'prices': {'card-lotus': 6500.0}
      });
      final okResult = await service.checkAndUpdatePrices(force: true);
      expect(okResult.status, equals(MarketPriceSyncStatus.success));

      final card = await (db.select(db.vaultItems)..where((t) => t.id.equals('card-lotus'))).getSingle();
      expect(card.currentMarketPrice, equals(6500.0));
    });
  });

  group('Adversarial Challenge 2: Extreme Price Values & Boundary Filtering', () {
    test('Negative numbers and zero are strictly excluded', () async {
      final payload = createGzip({
        'prices': {
          'card-negative-1': -100.0,
          'card-negative-2': -0.01,
          'card-zero-1': 0.0,
          'card-zero-2': 0,
          'card-zero-str': {'usd': '0.00'},
          'card-neg-str': {'usd': '-12.50'},
          'card-lotus': 5200.0,
        }
      });

      firestoreClient.metadata = const MarketSyncMetadata(timestamp: 6000, version: 'v1');
      storageClient.payload = payload;

      final result = await service.checkAndUpdatePrices();
      expect(result.status, equals(MarketPriceSyncStatus.success));
      // Only card-lotus is valid
      expect(result.cardsUpdated, equals(1));

      final lotus = await (db.select(db.vaultItems)..where((t) => t.id.equals('card-lotus'))).getSingle();
      expect(lotus.currentMarketPrice, equals(5200.0));
    });

    test('NaN, Infinity, -Infinity, nulls, and non-numeric strings are rejected', () async {
      final payload = createGzip({
        'prices': {
          'card-nan-str': {'usd': 'NaN'},
          'card-inf-str': {'usd': 'Infinity'},
          'card-neg-inf': {'usd': '-Infinity'},
          'card-null': null,
          'card-map-nulls': {'usd': null, 'usd_foil': null, 'eur': null},
          'card-free': 'free',
          'card-text': {'usd': 'Priceless'},
          'card-symbols': {'usd': r'$$$'},
          'card-empty-str': {'usd': ''},
          'card-spaces': {'usd': '   '},
          'card-mox': 2100.0,
        }
      });

      firestoreClient.metadata = const MarketSyncMetadata(timestamp: 7000, version: 'v1');
      storageClient.payload = payload;

      final result = await service.checkAndUpdatePrices();
      expect(result.status, equals(MarketPriceSyncStatus.success));
      expect(result.cardsUpdated, equals(1));

      final mox = await (db.select(db.vaultItems)..where((t) => t.id.equals('card-mox'))).getSingle();
      expect(mox.currentMarketPrice, equals(2100.0));
    });

    test('Scientific notation values are parsed accurately into double', () async {
      final payload = createGzip({
        'prices': {
          'card-lotus': 1.5e4, // 15,000.0
          'card-mox': {'usd': '2.5e3'}, // 2,500.0
        }
      });

      firestoreClient.metadata = const MarketSyncMetadata(timestamp: 8000, version: 'v1');
      storageClient.payload = payload;

      final result = await service.checkAndUpdatePrices();
      expect(result.status, equals(MarketPriceSyncStatus.success));
      expect(result.cardsUpdated, equals(2));

      final lotus = await (db.select(db.vaultItems)..where((t) => t.id.equals('card-lotus'))).getSingle();
      expect(lotus.currentMarketPrice, equals(15000.0));

      final mox = await (db.select(db.vaultItems)..where((t) => t.id.equals('card-mox'))).getSingle();
      expect(mox.currentMarketPrice, equals(2500.0));
    });

    test('Astronomical price values (\$999,999.99 and \$10,000,000.00) commit to SQLite', () async {
      final payload = createGzip({
        'prices': {
          'card-lotus': 999999.99,
          'card-mox': {'usd': '10000000.00'},
        }
      });

      firestoreClient.metadata = const MarketSyncMetadata(timestamp: 9000, version: 'v1');
      storageClient.payload = payload;

      final result = await service.checkAndUpdatePrices();
      expect(result.status, equals(MarketPriceSyncStatus.success));

      final lotus = await (db.select(db.vaultItems)..where((t) => t.id.equals('card-lotus'))).getSingle();
      expect(lotus.currentMarketPrice, equals(999999.99));

      final mox = await (db.select(db.vaultItems)..where((t) => t.id.equals('card-mox'))).getSingle();
      expect(mox.currentMarketPrice, equals(10000000.0));
    });

    test('Price hierarchy cascades properly when higher priority entries contain corrupt or invalid values', () async {
      final payload = createGzip({
        'prices': {
          // usd is invalid string, usd_foil is 0, usd_etched is null, eur is 88.50
          'card-lotus': {
            'usd': 'INVALID_PRICE',
            'usd_foil': '0.00',
            'usd_etched': null,
            'eur': '88.50',
            'eur_foil': '120.00',
          },
        }
      });

      firestoreClient.metadata = const MarketSyncMetadata(timestamp: 10000, version: 'v1');
      storageClient.payload = payload;

      final result = await service.checkAndUpdatePrices();
      expect(result.status, equals(MarketPriceSyncStatus.success));

      final lotus = await (db.select(db.vaultItems)..where((t) => t.id.equals('card-lotus'))).getSingle();
      expect(lotus.currentMarketPrice, equals(88.50));
    });
  });

  group('Adversarial Challenge 3: Large Payloads & 500-Card Chunking', () {
    test('Simulates 5,250 cards and verifies 500-card chunking batch transactions commit completely', () async {
      final totalCards = 5250;
      final Map<String, dynamic> prices = {};

      // Seed 5 cards into SQLite spread across chunks
      final seededIndices = [1, 500, 501, 2500, 5000, 5250];
      for (final idx in seededIndices) {
        await db.into(db.vaultItems).insert(
              VaultItemsCompanion.insert(
                id: 'card-$idx',
                name: 'Test Card $idx',
                collectionType: 'mtg',
                setOrSeries: 'SET',
                imageUrl: 'https://example.com/$idx.jpg',
                acquiredPrice: 1.0,
                acquiredDate: DateTime.utc(2026, 1, 1),
                condition: 'NM',
                currentMarketPrice: 1.0,
                lastPriceUpdate: DateTime.utc(2026, 1, 1),
                dynamicData: '{}',
              ),
            );
      }

      for (var i = 1; i <= totalCards; i++) {
        prices['card-$i'] = (i * 2.5);
      }

      firestoreClient.metadata = const MarketSyncMetadata(timestamp: 55000, version: 'v1');
      storageClient.payload = createGzip({'prices': prices});

      final reportedSteps = <int>[];
      final result = await service.checkAndUpdatePrices(
        onProgress: (processed, total) {
          reportedSteps.add(processed);
        },
      );

      expect(result.status, equals(MarketPriceSyncStatus.success));
      expect(result.cardsUpdated, equals(5250));

      // Verify exact 500-card chunking increments
      // 5250 / 500 = 10 full chunks (500, 1000, ..., 5000) + 1 partial chunk (5250)
      expect(
        reportedSteps,
        equals([500, 1000, 1500, 2000, 2500, 3000, 3500, 4000, 4500, 5000, 5250]),
      );

      // Verify each boundary card in SQLite was updated accurately
      for (final idx in seededIndices) {
        final card = await (db.select(db.vaultItems)..where((t) => t.id.equals('card-$idx'))).getSingle();
        expect(card.currentMarketPrice, equals(idx * 2.5));
        expect(card.lastPriceUpdate.isAfter(DateTime.utc(2026, 1, 1)), isTrue);
      }
    });
  });

  group('Adversarial Challenge 4: Concurrency & Race Conditions', () {
    test('Simultaneous concurrent sync calls allow only 1 execution and reject others with in-progress status', () async {
      firestoreClient.simulatedDelay = const Duration(milliseconds: 50);
      firestoreClient.metadata = const MarketSyncMetadata(timestamp: 77777, version: 'v1');
      storageClient.payload = createGzip({
        'prices': {'card-lotus': 8000.0}
      });

      // Fire 5 concurrent calls simultaneously
      final futures = [
        service.checkAndUpdatePrices(),
        service.checkAndUpdatePrices(),
        service.checkAndUpdatePrices(),
        service.checkAndUpdatePrices(),
        service.checkAndUpdatePrices(),
      ];

      final results = await Future.wait(futures);

      // Exactly 1 should succeed
      final successResults = results.where((r) => r.status == MarketPriceSyncStatus.success).toList();
      final rejectedResults = results.where((r) => r.errorMessage == 'Sync already in progress').toList();

      expect(successResults.length, equals(1));
      expect(rejectedResults.length, equals(4));
      expect(firestoreClient.readCount, equals(1));
      expect(storageClient.downloadCount, equals(1));

      // After completion, isSyncing is false
      expect(service.isSyncing, isFalse);

      final lotus = await (db.select(db.vaultItems)..where((t) => t.id.equals('card-lotus'))).getSingle();
      expect(lotus.currentMarketPrice, equals(8000.0));
    });

    test('Sequential rapid app opens: first sync writes, second sync exits after 1 Firestore read', () async {
      firestoreClient.metadata = const MarketSyncMetadata(timestamp: 88888, version: 'v1');
      storageClient.payload = createGzip({
        'prices': {'card-lotus': 8500.0}
      });

      // Open 1
      final res1 = await service.checkAndUpdatePrices();
      expect(res1.status, equals(MarketPriceSyncStatus.success));
      expect(firestoreClient.readCount, equals(1));
      expect(storageClient.downloadCount, equals(1));

      // Open 2 immediately (simulating user reopening app seconds later)
      final res2 = await service.checkAndUpdatePrices();
      expect(res2.status, equals(MarketPriceSyncStatus.alreadyUpToDate));
      expect(firestoreClient.readCount, equals(2));
      expect(storageClient.downloadCount, equals(1)); // Storage was NOT touched second time
    });

    test('Failed network call safely resets isSyncing enabling recovery on next trigger', () async {
      firestoreClient.throwError = Exception('SocketException: Connection timed out');

      final failResult = await service.checkAndUpdatePrices();
      expect(failResult.status, equals(MarketPriceSyncStatus.networkUnavailable));
      expect(service.isSyncing, isFalse);

      // Now restore network
      firestoreClient.throwError = null;
      firestoreClient.metadata = const MarketSyncMetadata(timestamp: 99999, version: 'v1');
      storageClient.payload = createGzip({
        'prices': {'card-lotus': 9000.0}
      });

      final recoverResult = await service.checkAndUpdatePrices();
      expect(recoverResult.status, equals(MarketPriceSyncStatus.success));
      expect(service.isSyncing, isFalse);
    });
  });

  group('Adversarial Challenge 5: Edge Case Timestamps & Metadata Formats', () {
    test('Missing timestamp in metadata defaults to 0 and executes sync on fresh install', () async {
      final meta = MarketSyncMetadata.fromMap({
        'version': 'v1',
        'storagePath': 'market_prices/custom.json.gz',
      });
      expect(meta.timestamp, equals(0));

      firestoreClient.metadata = meta;
      storageClient.payload = createGzip({
        'prices': {'card-lotus': 5100.0}
      });

      final result = await service.checkAndUpdatePrices();
      expect(result.status, equals(MarketPriceSyncStatus.success));

      final lotus = await (db.select(db.vaultItems)..where((t) => t.id.equals('card-lotus'))).getSingle();
      expect(lotus.currentMarketPrice, equals(5100.0));
    });

    test('Corrupt date string timestamp defaults safely to 0', () {
      final meta = MarketSyncMetadata.fromMap({
        'timestamp': 'NOT_A_VALID_DATE_STRING_XYZ',
        'version': 'v1',
      });
      expect(meta.timestamp, equals(0));
    });

    test('Future timestamp (e.g. year 2100) commits and updates cache', () async {
      final futureMillis = DateTime.utc(2100, 1, 1).millisecondsSinceEpoch;
      firestoreClient.metadata = MarketSyncMetadata(
        timestamp: futureMillis,
        version: 'v1',
      );
      storageClient.payload = createGzip({
        'prices': {'card-lotus': 9500.0}
      });

      final result = await service.checkAndUpdatePrices();
      expect(result.status, equals(MarketPriceSyncStatus.success));

      final cached = await preferences.getLastPriceSyncTimestamp();
      expect(cached, equals(futureMillis));

      // Subsequent call with older or same timestamp should exit early
      final res2 = await service.checkAndUpdatePrices();
      expect(res2.status, equals(MarketPriceSyncStatus.alreadyUpToDate));
      expect(storageClient.downloadCount, equals(1));
    });

    test('Epoch 0 timestamp is handled cleanly without infinite loops', () async {
      firestoreClient.metadata = const MarketSyncMetadata(timestamp: 0, version: 'v1');
      storageClient.payload = createGzip({
        'prices': {'card-lotus': 5300.0}
      });

      // Force sync with epoch 0
      final result = await service.checkAndUpdatePrices(force: true);
      expect(result.status, equals(MarketPriceSyncStatus.success));
      expect(result.timestamp, equals(0));
    });

    test('Custom timestamp object with millisecondsSinceEpoch getter parses accurately', () {
      final dummyTs = _MockTimestampWithMillis(1793415600000);
      final meta = MarketSyncMetadata.fromMap({
        'timestamp': dummyTs,
        'version': 'v2',
      });
      expect(meta.timestamp, equals(1793415600000));
    });

    test('DEFECT PROOF: Firestore Timestamp object with toDate() fails to parse (evaluates dyn.millisecondsSinceEpoch throwing NoSuchMethodError before toDate is checked)', () {
      final dummyFirestoreTimestamp = _MockFirestoreTimestamp(DateTime.utc(2026, 10, 31, 3, 0));
      final meta = MarketSyncMetadata.fromMap({
        'timestamp': dummyFirestoreTimestamp,
        'version': 'v2',
      });
      // EXPECTATION: Should parse to 1793415600000.
      // ACTUAL: Returns 0 because NoSuchMethodError on millisecondsSinceEpoch aborts the try-block before toDate() can be called.
      expect(meta.timestamp, equals(DateTime.utc(2026, 10, 31, 3, 0).millisecondsSinceEpoch));
    });
  });

  group('Adversarial Challenge 6: Missing Card IDs in Local Database & Sparse Inventory', () {
    test('Payload containing 1,000 cards on a 2-card database modifies only existing cards with zero phantom rows', () async {
      final Map<String, dynamic> prices = {};
      // 998 unowned cards
      for (var i = 1; i <= 998; i++) {
        prices['unowned-card-$i'] = 15.0 + i;
      }
      // 2 owned cards
      prices['card-lotus'] = 6200.0;
      prices['card-mox'] = 2400.0;

      firestoreClient.metadata = const MarketSyncMetadata(timestamp: 111111, version: 'v1');
      storageClient.payload = createGzip({'prices': prices});

      final countBefore = (await db.select(db.vaultItems).get()).length;

      final result = await service.checkAndUpdatePrices();
      expect(result.status, equals(MarketPriceSyncStatus.success));
      expect(result.cardsUpdated, equals(1000));

      // Verify the 2 existing cards are updated
      final lotus = await (db.select(db.vaultItems)..where((t) => t.id.equals('card-lotus'))).getSingle();
      expect(lotus.currentMarketPrice, equals(6200.0));

      final mox = await (db.select(db.vaultItems)..where((t) => t.id.equals('card-mox'))).getSingle();
      expect(mox.currentMarketPrice, equals(2400.0));

      // Verify NO phantom rows were inserted
      final allCards = await db.select(db.vaultItems).get();
      expect(allCards.length, equals(countBefore));
      expect(allCards.any((c) => c.id == 'card-lotus'), isTrue);
      expect(allCards.any((c) => c.id == 'card-mox'), isTrue);
    });

    test('Sync against a completely empty local database succeeds cleanly with 0 rows inserted', () async {
      // Clear out all cards from SQLite
      await db.delete(db.vaultItems).go();
      final countBefore = (await db.select(db.vaultItems).get()).length;
      expect(countBefore, equals(0));

      firestoreClient.metadata = const MarketSyncMetadata(timestamp: 122222, version: 'v1');
      storageClient.payload = createGzip({
        'prices': {
          'card-unknown-1': 100.0,
          'card-unknown-2': 200.0,
        }
      });

      final result = await service.checkAndUpdatePrices();
      expect(result.status, equals(MarketPriceSyncStatus.success));

      final countAfter = (await db.select(db.vaultItems).get()).length;
      expect(countAfter, equals(0));
    });
  });
}

class _MockFirestoreTimestamp {
  final DateTime _dateTime;
  _MockFirestoreTimestamp(this._dateTime);

  DateTime toDate() => _dateTime;
}

class _MockTimestampWithMillis {
  final int millisecondsSinceEpoch;
  _MockTimestampWithMillis(this.millisecondsSinceEpoch);
}

