import 'dart:typed_data';
import 'package:flutter_cache_manager/file.dart' show File;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:countr/core/cache/failed_image_registry.dart';

export 'package:countr/core/cache/failed_image_registry.dart';

/// Custom HTTP file service that attaches official User-Agent headers
/// and intercepts failed URLs to prevent repeated network flooding.
class CountrHttpFileService extends HttpFileService {
  static const String userAgent =
      'Countr/1.0 (Flutter; Educational Portfolio App)';

  CountrHttpFileService({super.httpClient});

  @override
  Future<FileServiceResponse> get(String url, {Map<String, String>? headers}) async {
    // 1. Short-circuit if previously recorded as failed in FailedImageRegistry
    if (FailedImageRegistry.instance.isFailed(url)) {
      throw HttpExceptionWithStatus(
        404,
        'URL blocked by FailedImageRegistry: ',
        uri: Uri.tryParse(url),
      );
    }

    try {
      final mergedHeaders = <String, String>{
        'User-Agent': userAgent,
        'Accept': 'image/jpeg,image/png,image/*;q=0.8',
        ...?headers,
      };
      final response = await super.get(url, headers: mergedHeaders);

      // 2. Intercept response status codes
      final statusCode = response.statusCode;
      if (statusCode == 404) {
        FailedImageRegistry.instance.markTerminal(
          url,
          statusCode: 404,
          type: ImageFailureType.terminalNotFound,
          reason: 'HTTP 404 Not Found',
        );
      } else if (statusCode >= 400 && statusCode < 500 && statusCode != 429) {
        FailedImageRegistry.instance.markTerminal(
          url,
          statusCode: statusCode,
          type: ImageFailureType.terminalClientError,
          reason: 'HTTP  Client Error',
        );
      } else if (statusCode >= 500 || statusCode == 429) {
        FailedImageRegistry.instance.recordAttempt(
          url,
          statusCode: statusCode,
          error: 'HTTP ',
        );
      }

      return response;
    } catch (e) {
      if (e is HttpExceptionWithStatus) {
        if (e.statusCode == 404) {
          FailedImageRegistry.instance.markTerminal(
            url,
            statusCode: 404,
            type: ImageFailureType.terminalNotFound,
            reason: e.message,
          );
        } else if (e.statusCode >= 400 && e.statusCode < 500 && e.statusCode != 429) {
          FailedImageRegistry.instance.markTerminal(
            url,
            statusCode: e.statusCode,
            type: ImageFailureType.terminalClientError,
            reason: e.message,
          );
        } else {
          FailedImageRegistry.instance.recordAttempt(
            url,
            statusCode: e.statusCode,
            error: e,
          );
        }
      } else {
        FailedImageRegistry.instance.recordAttempt(url, error: e);
      }
      rethrow;
    }
  }
}

/// Custom [CacheManager] tailored for MTG and collectible card imagery.
/// Enforces a 35+ day retention policy, 5,000 maximum cached objects on disk,
/// canonical URL normalization, deterministic key aliasing, and dual-key pre-caching.
class CountrImageCacheManager extends CacheManager with ImageCacheManager {
  static const String key = 'countr_card_images';
  static const Duration stalePeriod = Duration(days: 35);
  static const int maxNrOfCacheObjects = 5000;
  static const String userAgent = CountrHttpFileService.userAgent;

  static final CountrImageCacheManager _instance = CountrImageCacheManager._();
  static CountrImageCacheManager get instance => _instance;
  factory CountrImageCacheManager() => _instance;

  /// Direct accessor for the global failure registry.
  static FailedImageRegistry get failedRegistry => FailedImageRegistry.instance;

  final Map<String, Set<String>> _aliases = {};

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

  /// Normalizes an image URL by trimming and stripping cache-busting query params from CDN images.
  static String normalizeUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return '';
    try {
      final uri = Uri.parse(trimmed);
      final host = uri.host.toLowerCase();
      final path = uri.path.toLowerCase();
      // Strip cache-busting query strings from CDN card images (Scryfall or common image formats)
      if (host.contains('scryfall.io') ||
          path.endsWith('.jpg') ||
          path.endsWith('.jpeg') ||
          path.endsWith('.png') ||
          path.endsWith('.webp')) {
        return Uri(
          scheme: uri.scheme.toLowerCase(),
          host: host,
          port: uri.hasPort ? uri.port : null,
          path: uri.path,
        ).toString();
      }
      return uri.toString();
    } catch (_) {
      return trimmed;
    }
  }

  /// Resolves the canonical cache key given optional cardId, imageUrl, or explicit cacheKey.
  static String cacheKeyFor({
    String? cardId,
    String? imageUrl,
    String? cacheKey,
  }) {
    if (cacheKey != null && cacheKey.isNotEmpty) return cacheKey;
    if (cardId != null && cardId.isNotEmpty) {
      if (cardId.startsWith('deck-')) {
        return deckCoverKey(cardId);
      }
      return cardArtKey(cardId);
    }
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return normalizeUrl(imageUrl);
    }
    return '';
  }

  /// Registers a bidirectional key alias between [key1] and [key2].
  void registerKeyAlias(String key1, String key2) {
    final k1 = key1.trim();
    final k2 = key2.trim();
    if (k1.isEmpty || k2.isEmpty || k1 == k2) return;
    (_aliases[k1] ??= <String>{}).add(k2);
    (_aliases[k2] ??= <String>{}).add(k1);
    FailedImageRegistry.instance.linkKeys(k1, k2);

    // If either key is an HTTP/HTTPS URL, also link with its canonical normalized form
    for (final pair in [(k1, k2), (k2, k1)]) {
      final key = pair.$1;
      final other = pair.$2;
      final lower = key.toLowerCase();
      if (lower.startsWith('http://') || lower.startsWith('https://')) {
        final norm = normalizeUrl(key);
        if (norm.isNotEmpty && norm != key) {
          (_aliases[key] ??= <String>{}).add(norm);
          (_aliases[norm] ??= <String>{}).add(key);
          (_aliases[norm] ??= <String>{}).add(other);
          (_aliases[other] ??= <String>{}).add(norm);
          FailedImageRegistry.instance.linkKeys(norm, other);
          FailedImageRegistry.instance.linkKeys(norm, key);
        }
      }
    }
  }

  /// Resolves registered alias for [key] if one exists.
  String? resolveKeyAlias(String key) => _aliases[key.trim()]?.firstOrNull;

  /// Resolves all registered aliases for [key].
  Set<String> resolveKeyAliases(String key) => _aliases[key.trim()] ?? const {};

  /// Alias-aware cache lookup that checks the key, its registered aliases,
  /// normalized URLs, and repo storage for raw query-parameterized URLs.
  @override
  Future<FileInfo?> getFileFromCache(String key, {bool ignoreMemCache = false}) async {
    final cleanKey = key.trim();
    if (cleanKey.isEmpty) return null;

    // 1. Direct lookup
    var info = await super.getFileFromCache(cleanKey, ignoreMemCache: ignoreMemCache);
    if (info != null && await info.file.exists()) return info;

    // 2. Candidate collection with transitive alias traversal and URL normalization
    final visited = <String>{cleanKey};
    final queue = <String>[];

    void enqueue(String candidate) {
      final trimmed = candidate.trim();
      if (trimmed.isNotEmpty && visited.add(trimmed)) {
        queue.add(trimmed);
        final lower = trimmed.toLowerCase();
        if (lower.startsWith('http://') || lower.startsWith('https://')) {
          final norm = normalizeUrl(trimmed);
          if (norm.isNotEmpty && visited.add(norm)) {
            queue.add(norm);
          }
        }
      }
    }

    final lowerClean = cleanKey.toLowerCase();
    if (lowerClean.startsWith('http://') || lowerClean.startsWith('https://')) {
      final normClean = normalizeUrl(cleanKey);
      if (normClean.isNotEmpty && visited.add(normClean)) {
        queue.add(normClean);
      }
    }

    final directAliases = _aliases[cleanKey] ?? const <String>{};
    for (final alias in directAliases) {
      enqueue(alias);
    }

    var head = 0;
    while (head < queue.length) {
      final cand = queue[head++];
      info = await super.getFileFromCache(cand, ignoreMemCache: ignoreMemCache);
      if (info != null && await info.file.exists()) {
        if (cand != cleanKey) {
          registerKeyAlias(cleanKey, cand);
        }
        return info;
      }

      final candAliases = _aliases[cand];
      if (candAliases != null) {
        for (final alias in candAliases) {
          enqueue(alias);
        }
      }
    }

    // 3. Fallback repository scan for raw URLs with query parameters (Reverse Aliasing)
    final urlTargets = <String>{};
    for (final v in visited) {
      final lower = v.toLowerCase();
      if (lower.startsWith('http://') || lower.startsWith('https://')) {
        final norm = normalizeUrl(v);
        if (norm.isNotEmpty) {
          urlTargets.add(norm);
        }
      }
    }

    if (urlTargets.isNotEmpty) {
      try {
        final objects = await config.repo.getAllObjects();
        for (final obj in objects) {
          final normObjKey = normalizeUrl(obj.key);
          if (urlTargets.contains(normObjKey)) {
            info = await super.getFileFromCache(obj.key, ignoreMemCache: ignoreMemCache);
            if (info != null && await info.file.exists()) {
              registerKeyAlias(cleanKey, obj.key);
              return info;
            }
          }
        }
      } catch (_) {}
    }

    return null;
  }

  /// Overrides putFile to ensure images cached directly via putFile under raw URLs
  /// automatically register bidirectional aliases with their canonical normalized URLs,
  /// and dual-caches under the normalized URL.
  @override
  Future<File> putFile(
    String url,
    Uint8List fileBytes, {
    String? key,
    String? eTag,
    Duration maxAge = const Duration(days: 30),
    String fileExtension = 'file',
  }) async {
    final effectiveKey = (key ?? url).trim();
    final lowerKey = effectiveKey.toLowerCase();
    if (lowerKey.startsWith('http://') || lowerKey.startsWith('https://')) {
      final norm = normalizeUrl(effectiveKey);
      if (norm.isNotEmpty && norm != effectiveKey) {
        registerKeyAlias(effectiveKey, norm);
      }
    }
    final file = await super.putFile(
      url,
      fileBytes,
      key: key,
      eTag: eTag,
      maxAge: maxAge,
      fileExtension: fileExtension,
    );
    if (lowerKey.startsWith('http://') || lowerKey.startsWith('https://')) {
      final norm = normalizeUrl(effectiveKey);
      if (norm.isNotEmpty && norm != effectiveKey) {
        try {
          await super.putFile(
            norm,
            fileBytes,
            key: norm,
            eTag: eTag,
            maxAge: maxAge,
            fileExtension: fileExtension,
          );
        } catch (_) {}
      }
    }
    return file;
  }

  /// Overrides putFileStream to automatically record URL normalizations into the alias map.
  @override
  Future<File> putFileStream(
    String url,
    Stream<List<int>> source, {
    String? key,
    String? eTag,
    Duration maxAge = const Duration(days: 30),
    String fileExtension = 'file',
  }) async {
    final cleanKey = (key ?? url).trim();
    final lowerKey = cleanKey.toLowerCase();
    if (lowerKey.startsWith('http://') || lowerKey.startsWith('https://')) {
      final norm = normalizeUrl(cleanKey);
      if (norm.isNotEmpty && norm != cleanKey) {
        registerKeyAlias(cleanKey, norm);
      }
    }
    return super.putFileStream(
      url,
      source,
      key: key,
      eTag: eTag,
      maxAge: maxAge,
      fileExtension: fileExtension,
    );
  }

  /// Overrides downloadFile to automatically record URL normalizations into the alias map.
  @override
  Future<FileInfo> downloadFile(
    String url, {
    String? key,
    Map<String, String>? authHeaders,
    bool force = false,
  }) async {
    final cleanUrl = url.trim();
    final lowerUrl = cleanUrl.toLowerCase();
    if (lowerUrl.startsWith('http://') || lowerUrl.startsWith('https://')) {
      final norm = normalizeUrl(cleanUrl);
      if (norm.isNotEmpty && norm != cleanUrl) {
        registerKeyAlias(cleanUrl, norm);
      }
    }
    if (key != null) {
      final cleanKey = key.trim();
      final lowerKey = cleanKey.toLowerCase();
      if (lowerKey.startsWith('http://') || lowerKey.startsWith('https://')) {
        final norm = normalizeUrl(cleanKey);
        if (norm.isNotEmpty && norm != cleanKey) {
          registerKeyAlias(cleanKey, norm);
        }
      }
    }
    return super.downloadFile(
      url,
      key: key,
      authHeaders: authHeaders,
      force: force,
    );
  }

  /// Convenience lookup for a cached card image file by cardId.
  Future<FileInfo?> getCachedCardImage(String cardId) async {
    return getFileFromCache(cardArtKey(cardId));
  }

  /// Pre-caches card art under both deterministic key and normalized URL for dual lookup.
  Future<File> precacheCardArt(String cardId, String imageUrl) async {
    final primaryKey = cardArtKey(cardId);
    final cleanUrl = imageUrl.trim();
    final normUrl = normalizeUrl(cleanUrl);

    registerKeyAlias(primaryKey, normUrl);
    if (normUrl != cleanUrl) {
      registerKeyAlias(primaryKey, cleanUrl);
      registerKeyAlias(cleanUrl, normUrl);
    }

    final fileInfo = await downloadFile(cleanUrl, key: primaryKey);

    // Dual-cache under normalized URL so callers querying by URL hit disk cache
    try {
      final bytes = await fileInfo.file.readAsBytes();
      await putFile(normUrl, bytes, key: normUrl);
      if (normUrl != cleanUrl) {
        await putFile(cleanUrl, bytes, key: cleanUrl);
      }
    } catch (_) {
      // Non-fatal if secondary cache put fails; primaryKey is saved
    }

    return fileInfo.file;
  }

  /// Pre-caches deck cover art under both deterministic key and normalized URL.
  Future<File> precacheDeckCover(String deckId, String imageUrl) async {
    final primaryKey = deckCoverKey(deckId);
    final cleanUrl = imageUrl.trim();
    final normUrl = normalizeUrl(cleanUrl);

    registerKeyAlias(primaryKey, normUrl);
    if (normUrl != cleanUrl) {
      registerKeyAlias(primaryKey, cleanUrl);
      registerKeyAlias(cleanUrl, normUrl);
    }

    final fileInfo = await downloadFile(cleanUrl, key: primaryKey);

    // Dual-cache under normalized URL so callers querying by URL hit disk cache
    try {
      final bytes = await fileInfo.file.readAsBytes();
      await putFile(normUrl, bytes, key: normUrl);
      if (normUrl != cleanUrl) {
        await putFile(cleanUrl, bytes, key: cleanUrl);
      }
    } catch (_) {
      // Non-fatal if secondary cache put fails; primaryKey is saved
    }

    return fileInfo.file;
  }

  /// Evicts a specific card image from cache and clears failure registry records.
  Future<void> evictCardArt(String cardId) async {
    final key = cardArtKey(cardId);
    await removeFile(key);
    final aliases = _aliases.remove(key) ?? const <String>{};
    for (final alias in aliases) {
      await removeFile(alias);
      _aliases[alias]?.remove(key);
      FailedImageRegistry.instance.reset(alias, cacheKey: key);
    }
    FailedImageRegistry.instance.reset(null, cacheKey: key);
  }

  /// Evicts a specific deck cover from cache and clears failure registry records.
  Future<void> evictDeckCover(String deckId) async {
    final key = deckCoverKey(deckId);
    await removeFile(key);
    final aliases = _aliases.remove(key) ?? const <String>{};
    for (final alias in aliases) {
      await removeFile(alias);
      _aliases[alias]?.remove(key);
      FailedImageRegistry.instance.reset(alias, cacheKey: key);
    }
    FailedImageRegistry.instance.reset(null, cacheKey: key);
  }

  /// Evicts an image by URL and clears failure registry records.
  Future<void> evictUrl(String url) async {
    final cleanUrl = url.trim();
    await removeFile(cleanUrl);
    final norm = normalizeUrl(cleanUrl);
    if (norm != cleanUrl) {
      await removeFile(norm);
    }
    final aliases = <String>{
      ...?_aliases.remove(cleanUrl),
      if (norm != cleanUrl) ...?_aliases.remove(norm),
    };
    for (final alias in aliases) {
      await removeFile(alias);
      _aliases[alias]?.remove(cleanUrl);
      if (norm != cleanUrl) _aliases[alias]?.remove(norm);
      FailedImageRegistry.instance.reset(cleanUrl, cacheKey: alias);
    }
    FailedImageRegistry.instance.reset(cleanUrl, cacheKey: norm);
  }

  /// Verifies if primary card art files exist on disk.
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
