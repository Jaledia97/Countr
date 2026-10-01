import 'dart:io';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Custom HTTP file service that attaches official User-Agent headers
/// conforming to Scryfall and generic TCG API requirements.
class CountrHttpFileService extends HttpFileService {
  static const String userAgent =
      'Countr/1.0 (Flutter; Educational Portfolio App)';

  CountrHttpFileService({super.httpClient});

  @override
  Future<FileServiceResponse> get(String url, {Map<String, String>? headers}) {
    final mergedHeaders = <String, String>{
      'User-Agent': userAgent,
      'Accept': 'image/jpeg,image/png,image/*;q=0.8',
      ...?headers,
    };
    return super.get(url, headers: mergedHeaders);
  }
}

/// Custom [CacheManager] tailored for MTG and collectible card imagery.
/// Enforces a 35+ day retention policy and 5,000 maximum cached objects on disk
/// to ensure complete offline resilience.
class CountrImageCacheManager extends CacheManager with ImageCacheManager {
  static const String key = 'countr_card_images';
  static const Duration stalePeriod = Duration(days: 35);
  static const int maxNrOfCacheObjects = 5000;
  static const String userAgent = CountrHttpFileService.userAgent;

  static final CountrImageCacheManager _instance = CountrImageCacheManager._();
  static CountrImageCacheManager get instance => _instance;
  factory CountrImageCacheManager() => _instance;

  CountrImageCacheManager._()
      : super(
          Config(
            key,
            stalePeriod: stalePeriod,
            maxNrOfCacheObjects: maxNrOfCacheObjects,
            repo: JsonCacheInfoRepository(databaseName: key),
            fileService: CountrHttpFileService(),
          ),
        );

  /// Helper to generate a deterministic cache key for a card record id.
  static String cardArtKey(String cardId) => 'card_art_$cardId';

  /// Helper to generate a deterministic cache key for a deck cover.
  static String deckCoverKey(String deckId) => 'deck_cover_$deckId';

  /// Instance alias for card art key generation.
  String generateCardKey(String cardId) => cardArtKey(cardId);

  /// Convenience lookup for a cached card image file by cardId.
  Future<FileInfo?> getCachedCardImage(String cardId) async {
    return getFileFromCache(cardArtKey(cardId));
  }

  /// Convenience pre-cache method for card art.
  Future<File> precacheCardArt(String cardId, String imageUrl) async {
    final fileInfo = await downloadFile(
      imageUrl,
      key: cardArtKey(cardId),
    );
    return fileInfo.file;
  }

  /// Evicts a specific card image from cache to force re-fetch.
  Future<void> evictCardArt(String cardId) async {
    await removeFile(cardArtKey(cardId));
  }

  /// Verifies if primary card art files exist on disk.
  /// If the cache was cleared or wiped (e.g. system settings, disk cleanup),
  /// returns false to signal that reproduction / re-caching is needed.
  Future<bool> isImageCacheHealthy({List<String>? sampleCardIds}) async {
    final testIds = sampleCardIds ??
        ['item-mtg-one-ring', 'deck-edgar-markov', 'edgar-markov'];
    for (final id in testIds) {
      try {
        final info = await getCachedCardImage(id);
        if (info != null && await info.file.exists()) {
          return true;
        }
        final deckInfo = await getFileFromCache(deckCoverKey(id));
        if (deckInfo != null && await deckInfo.file.exists()) {
          return true;
        }
      } catch (_) {}
    }
    return false;
  }
}

