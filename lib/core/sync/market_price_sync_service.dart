import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../../features/vault/data/daos/vault_dao.dart';

/// Metadata model reflecting Firestore doc `system/market_sync`
class MarketSyncMetadata {
  final int timestamp;
  final String version;
  final String? checksum;
  final int? cardCount;
  final String storagePath;

  const MarketSyncMetadata({
    required this.timestamp,
    required this.version,
    this.checksum,
    this.cardCount,
    this.storagePath = 'market_prices/latest.json.gz',
  });

  factory MarketSyncMetadata.fromMap(Map<String, dynamic> map) {
    int parsedTimestamp = 0;
    final rawTs = map['timestamp'];
    if (rawTs is int) {
      parsedTimestamp = rawTs;
    } else if (rawTs is String) {
      parsedTimestamp = DateTime.tryParse(rawTs)?.millisecondsSinceEpoch ?? 0;
    } else if (rawTs is DateTime) {
      parsedTimestamp = rawTs.millisecondsSinceEpoch;
    } else if (rawTs != null) {
      final dynamic dyn = rawTs;
      bool parsed = false;
      try {
        final dt = dyn.toDate();
        if (dt is DateTime) {
          parsedTimestamp = dt.millisecondsSinceEpoch;
          parsed = true;
        }
      } catch (_) {}
      if (!parsed) {
        try {
          final ms = dyn.millisecondsSinceEpoch;
          if (ms is int) {
            parsedTimestamp = ms;
          }
        } catch (_) {}
      }
    }

    return MarketSyncMetadata(
      timestamp: parsedTimestamp,
      version: map['version']?.toString() ?? 'v1',
      checksum: map['checksum']?.toString(),
      cardCount: map['cardCount'] is num ? (map['cardCount'] as num).toInt() : null,
      storagePath: map['storagePath']?.toString() ?? 'market_prices/latest.json.gz',
    );
  }
}

/// Result status of market price synchronization
enum MarketPriceSyncStatus {
  success,
  alreadyUpToDate,
  networkUnavailable,
  failed,
}

class MarketPriceSyncResult {
  final MarketPriceSyncStatus status;
  final int cardsUpdated;
  final int? timestamp;
  final String? errorMessage;

  const MarketPriceSyncResult({
    required this.status,
    this.cardsUpdated = 0,
    this.timestamp,
    this.errorMessage,
  });

  factory MarketPriceSyncResult.success({required int cardsUpdated, required int timestamp}) =>
      MarketPriceSyncResult(
        status: MarketPriceSyncStatus.success,
        cardsUpdated: cardsUpdated,
        timestamp: timestamp,
      );

  factory MarketPriceSyncResult.alreadyUpToDate({required int timestamp}) =>
      MarketPriceSyncResult(
        status: MarketPriceSyncStatus.alreadyUpToDate,
        timestamp: timestamp,
      );

  factory MarketPriceSyncResult.networkUnavailable({String? message}) =>
      MarketPriceSyncResult(
        status: MarketPriceSyncStatus.networkUnavailable,
        errorMessage: message ?? 'Network unavailable',
      );

  factory MarketPriceSyncResult.failed(String error) =>
      MarketPriceSyncResult(
        status: MarketPriceSyncStatus.failed,
        errorMessage: error,
      );
}

/// Abstract contract for Firestore metadata client (enables 100% unit testing)
abstract class FirestorePriceSyncClient {
  Future<MarketSyncMetadata?> getMarketSyncMetadata();
}

/// Abstract contract for Storage binary download client
abstract class StoragePriceSyncClient {
  Future<Uint8List> downloadGzipPrices(String storagePath);
}

/// Abstract contract for Local Preferences
abstract class SyncPreferences {
  Future<int?> getLastPriceSyncTimestamp();
  Future<void> setLastPriceSyncTimestamp(int timestamp);
}

/// In-memory implementation of SyncPreferences for testing & fallback
class InMemorySyncPreferences implements SyncPreferences {
  int? _timestamp;

  InMemorySyncPreferences([this._timestamp]);

  @override
  Future<int?> getLastPriceSyncTimestamp() async => _timestamp;

  @override
  Future<void> setLastPriceSyncTimestamp(int timestamp) async {
    _timestamp = timestamp;
  }
}

/// Core Market Price Synchronization Engine
class MarketPriceSyncService {
  final FirestorePriceSyncClient _firestoreClient;
  final StoragePriceSyncClient _storageClient;
  final SyncPreferences _preferences;
  final AppDatabase _db;
  final VaultDao? _vaultDao;

  bool _isSyncing = false;

  MarketPriceSyncService({
    required FirestorePriceSyncClient firestoreClient,
    required StoragePriceSyncClient storageClient,
    required SyncPreferences preferences,
    required AppDatabase db,
    VaultDao? vaultDao,
  })  : _firestoreClient = firestoreClient,
        _storageClient = storageClient,
        _preferences = preferences,
        _db = db,
        _vaultDao = vaultDao;

  VaultDao? get vaultDao => _vaultDao;
  bool get isSyncing => _isSyncing;

  /// Primary sync execution method.
  /// 
  /// 1. Reads `system/market_sync` from Firestore (1 read).
  /// 2. Compares timestamp against local cached timestamp in SharedPreferences.
  /// 3. Downloads `market_prices/latest.json.gz` from Firebase Storage.
  /// 4. Background decompression & parsing in `Isolate.run` (never blocks UI).
  /// 5. Batch updates Drift `vault_items` in SQLite transactions using chunks of 500 cards.
  Future<MarketPriceSyncResult> checkAndUpdatePrices({
    bool force = false,
    void Function(int processed, int total)? onProgress,
  }) async {
    if (_isSyncing) {
      return const MarketPriceSyncResult(
        status: MarketPriceSyncStatus.alreadyUpToDate,
        errorMessage: 'Sync already in progress',
      );
    }

    _isSyncing = true;
    try {
      // Step 1: Read system/market_sync (1 Firestore read)
      final MarketSyncMetadata? metadata;
      try {
        metadata = await _firestoreClient.getMarketSyncMetadata();
      } catch (e) {
        return MarketPriceSyncResult.networkUnavailable(message: e.toString());
      }

      if (metadata == null) {
        return MarketPriceSyncResult.failed('Failed to read system/market_sync metadata');
      }

      // Step 2: Compare against local cached timestamp
      final cachedTimestamp = await _preferences.getLastPriceSyncTimestamp() ?? 0;
      if (!force && metadata.timestamp <= cachedTimestamp && cachedTimestamp > 0) {
        return MarketPriceSyncResult.alreadyUpToDate(timestamp: cachedTimestamp);
      }

      // Step 3: Download gzip stream from Firebase Storage
      final Uint8List gzipBytes;
      try {
        gzipBytes = await _storageClient.downloadGzipPrices(metadata.storagePath);
      } catch (e) {
        return MarketPriceSyncResult.networkUnavailable(message: e.toString());
      }

      if (gzipBytes.isEmpty) {
        return MarketPriceSyncResult.failed('Empty gzip payload downloaded from storage');
      }

      // Step 4: Background Isolate decompression & parsing (0 main thread jank)
      final Map<String, double> priceMap;
      try {
        priceMap = await parseGzipPricesInIsolate(gzipBytes);
      } catch (e) {
        return MarketPriceSyncResult.failed('Failed to decompress or parse gzip payload: $e');
      }

      if (priceMap.isEmpty) {
        return MarketPriceSyncResult.failed('Parsed 0 card prices from payload');
      }

      // Step 5: Chunked SQLite updates in batches of 500
      final updatedCount = await _batchUpdateDatabaseChunked(
        priceMap,
        chunkSize: 500,
        onProgress: onProgress,
      );

      // Step 6: Persist updated timestamp
      await _preferences.setLastPriceSyncTimestamp(metadata.timestamp);

      return MarketPriceSyncResult.success(
        cardsUpdated: updatedCount,
        timestamp: metadata.timestamp,
      );
    } catch (e) {
      return MarketPriceSyncResult.failed(e.toString());
    } finally {
      _isSyncing = false;
    }
  }

  /// Worker isolate function for gzip decompression and price map extraction
  static Future<Map<String, double>> parseGzipPricesInIsolate(Uint8List gzipBytes) async {
    return Isolate.run(() {
      final decompressed = GZipCodec().decode(gzipBytes);
      final jsonStr = utf8.decode(decompressed);
      final dynamic decoded = jsonDecode(jsonStr);

      final Map<String, dynamic> rawPrices;
      if (decoded is Map && decoded['prices'] is Map) {
        rawPrices = Map<String, dynamic>.from(decoded['prices'] as Map);
      } else if (decoded is Map) {
        rawPrices = Map<String, dynamic>.from(decoded);
      } else {
        return <String, double>{};
      }

      final result = <String, double>{};
      for (final entry in rawPrices.entries) {
        final val = entry.value;
        if (val is num) {
          final p = val.toDouble();
          if (p > 0 && !p.isNaN && !p.isInfinite) {
            result[entry.key] = p;
          }
        } else if (val is Map) {
          final p = _extractPriceFromMap(val);
          if (p > 0 && !p.isNaN && !p.isInfinite) {
            result[entry.key] = p;
          }
        }
      }
      return result;
    });
  }

  /// Extracts price using canonical hierarchy: usd -> usd_foil -> usd_etched -> eur -> eur_foil
  static double _extractPriceFromMap(Map<dynamic, dynamic> map) {
    const keys = ['usd', 'usd_foil', 'usd_etched', 'eur', 'eur_foil'];
    for (final k in keys) {
      final raw = map[k];
      if (raw != null) {
        final parsed = double.tryParse(raw.toString());
        if (parsed != null && parsed > 0 && !parsed.isNaN && !parsed.isInfinite) {
          return parsed;
        }
      }
    }
    return 0.0;
  }

  /// Chunked batch update into Drift SQLite
  Future<int> _batchUpdateDatabaseChunked(
    Map<String, double> priceMap, {
    int chunkSize = 500,
    void Function(int processed, int total)? onProgress,
  }) async {
    final entries = priceMap.entries.toList();
    final total = entries.length;
    var processed = 0;
    final now = DateTime.now().toUtc();

    for (var i = 0; i < total; i += chunkSize) {
      final end = (i + chunkSize < total) ? i + chunkSize : total;
      final chunk = entries.sublist(i, end);

      await _db.batch((b) {
        for (final item in chunk) {
          b.update(
            _db.vaultItems,
            VaultItemsCompanion(
              currentMarketPrice: Value(item.value),
              lastPriceUpdate: Value(now),
            ),
            where: (t) => t.id.equals(item.key),
          );
        }
      });

      processed += chunk.length;
      onProgress?.call(processed, total);
    }

    return processed;
  }
}
