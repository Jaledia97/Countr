import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/painting.dart';
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
  final Map<String, File> _memoryFiles = {};
  final Map<String, Set<String>> _cardNameCacheKeys = {};
  static bool _memoryCacheConfigured = false;

  /// Expands Flutter's in-memory decoded [ImageCache] so card thumbnails
  /// remain decoded in RAM while scrolling through large decklists and the Vault.
  static void ensureMemoryImageCacheConfigured() {
    if (_memoryCacheConfigured) return;
    try {
      final imageCache = PaintingBinding.instance.imageCache;
      if (imageCache.maximumSize < 2500) {
        imageCache.maximumSize = 2500;
      }
      if (imageCache.maximumSizeBytes < 256 * 1024 * 1024) {
        imageCache.maximumSizeBytes = 256 * 1024 * 1024;
      }
      _memoryCacheConfigured = true;
    } catch (_) {}
  }

  CountrImageCacheManager._()
      : super(
          Config(
            key,
            stalePeriod: stalePeriod,
            maxNrOfCacheObjects: maxNrOfCacheObjects,
            repo: JsonCacheInfoRepository(databaseName: key),
            fileService: CountrHttpFileService(),
          ),
        ) {
    ensureMemoryImageCacheConfigured();
  }

  /// Helper to generate a deterministic cache key for a card record id,
  /// scoped by image version ('normal', 'small', 'art_crop') and face (front vs back).
  static String cardArtKey(
    String cardId, {
    String version = 'normal',
    bool isBack = false,
  }) {
    final cleanId = cardId.trim();
    final faceSuffix = isBack ? '_back' : '';
    final normVersion = version.trim().toLowerCase();
    if (normVersion.isNotEmpty && normVersion != 'normal' && normVersion != 'large') {
      return 'card_art_${normVersion}_$cleanId$faceSuffix';
    }
    return 'card_art_$cleanId$faceSuffix';
  }

  /// Helper to generate a deterministic cache key for a deck cover.
  static String deckCoverKey(String deckId) => 'deck_cover_$deckId';

  /// Helper to generate a canonical card-name + version key for fallback lookups.
  static String cardNameKey(String cardName, {String version = 'normal'}) {
    final clean = cardName.contains('//')
        ? cardName.split('//').first.trim().toLowerCase()
        : cardName.trim().toLowerCase();
    if (clean.isEmpty || clean == 'unknown card') return '';
    return 'card_name_${version.trim().toLowerCase()}_$clean';
  }

  /// Infers the Scryfall image version ('art_crop', 'small', 'large', 'normal') from a URL.
  static String inferImageVersion(String url, {String fallback = 'normal'}) {
    final lower = url.toLowerCase();
    if (lower.contains('/small/') || lower.contains('version=small')) {
      return 'small';
    }
    if (lower.contains('/art_crop/') || lower.contains('version=art_crop')) {
      return 'art_crop';
    }
    if (lower.contains('/large/') || lower.contains('version=large')) {
      return 'large';
    }
    if (lower.contains('/normal/') || lower.contains('version=normal')) {
      return 'normal';
    }
    return fallback;
  }

  /// Extracts `(cardName, version)` if [url] is a Scryfall named card redirect URL.
  static ({String name, String version})? parseScryfallNamedUrl(String url) {
    final trimmed = url.trim();
    if (!trimmed.contains('api.scryfall.com/cards/named')) return null;
    try {
      final uri = Uri.parse(trimmed);
      final exact = uri.queryParameters['exact'] ?? uri.queryParameters['fuzzy'];
      if (exact == null || exact.trim().isEmpty) return null;
      final version = uri.queryParameters['version'] ?? 'normal';
      return (name: exact.trim(), version: version.trim());
    } catch (_) {
      return null;
    }
  }

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
    String version = 'normal',
    bool isBack = false,
  }) {
    if (cacheKey != null && cacheKey.isNotEmpty) return cacheKey;
    if (cardId != null && cardId.isNotEmpty) {
      if (cardId.startsWith('deck-')) {
        return deckCoverKey(cardId);
      }
      final effectiveVersion = imageUrl != null && imageUrl.isNotEmpty
          ? inferImageVersion(imageUrl, fallback: version)
          : version;
      final isBackFace = isBack || (imageUrl?.toLowerCase().contains('/back/') ?? false);
      return cardArtKey(cardId, version: effectiveVersion, isBack: isBackFace);
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

  /// Registers all cross-instance identifiers for a card (`cacheKey`, `cardId`,
  /// `imageUrl`, and `cardName`) so that any instance of the same card printing
  /// across the Vault, My Decks, Explore Decks, and Precons resolves from the
  /// shared cache first before ever hitting the network.
  void registerCardAliases({
    String? cacheKey,
    String? cardId,
    String? imageUrl,
    String? cardName,
    String version = 'normal',
    bool isArtSeries = false,
    bool isBack = false,
  }) {
    final cleanKey = cacheKey?.trim() ?? '';
    final cleanCardId = cardId?.trim() ?? '';
    final cleanUrl = imageUrl?.trim() ?? '';
    final cleanName = cardName?.trim() ?? '';

    final effectiveVersion = inferImageVersion(cleanUrl, fallback: version);
    final isBackFace = isBack ||
        cleanUrl.toLowerCase().contains('/back/') ||
        cleanUrl.toLowerCase().contains('/back.jpg');

    final String scopedCardKey = cleanCardId.isNotEmpty
        ? (cleanCardId.startsWith('deck-')
            ? deckCoverKey(cleanCardId)
            : cardArtKey(cleanCardId, version: effectiveVersion, isBack: isBackFace))
        : '';

    if (cleanKey.isNotEmpty && cleanUrl.isNotEmpty) {
      registerKeyAlias(cleanKey, cleanUrl);
    }

    if (!isArtSeries && scopedCardKey.isNotEmpty) {
      if (cleanUrl.isNotEmpty && !cleanUrl.contains('art_series')) {
        registerKeyAlias(scopedCardKey, cleanUrl);
      }
      if (cleanKey.isNotEmpty && !cleanKey.endsWith('_fallback')) {
        registerKeyAlias(scopedCardKey, cleanKey);
      }
    }

    if (cleanName.isNotEmpty && cleanName != 'Unknown Card') {
      final nameKey = cardNameKey(cleanName, version: effectiveVersion);
      if (nameKey.isNotEmpty) {
        if (cleanUrl.isNotEmpty && !cleanUrl.contains('art_series')) {
          final normUrl = normalizeUrl(cleanUrl);
          (_cardNameCacheKeys[nameKey] ??= <String>{})
              .add(normUrl.isNotEmpty ? normUrl : cleanUrl);
        }
        if (cleanKey.isNotEmpty && (!isArtSeries || cleanKey.endsWith('_fallback'))) {
          (_cardNameCacheKeys[nameKey] ??= <String>{}).add(cleanKey);
        }
      }
    }
  }

  void _recordMemoryFile(String key, File file) {
    final clean = key.trim();
    if (clean.isEmpty) return;
    _memoryFiles[clean] = file;
    final lower = clean.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      final norm = normalizeUrl(clean);
      if (norm.isNotEmpty) {
        _memoryFiles[norm] = file;
      }
      final parsedNamed = parseScryfallNamedUrl(clean);
      if (parsedNamed != null) {
        final nameKey = cardNameKey(parsedNamed.name, version: parsedNamed.version);
        if (nameKey.isNotEmpty) {
          (_cardNameCacheKeys[nameKey] ??= <String>{}).add(clean);
          _memoryFiles[nameKey] = file;
        }
      }
    }
  }

  FileInfo _ensureFreshFileInfo(FileInfo info) {
    final minValid = DateTime.now().add(const Duration(days: 1));
    if (info.validTill.isBefore(minValid)) {
      return FileInfo(
        info.file,
        info.source,
        DateTime.now().add(stalePeriod),
        info.originalUrl,
      );
    }
    return info;
  }

  /// Synchronously returns an already-resolved local [File] from memory if
  /// this card image has already been encountered in the current session.
  /// Enables 0ms Frame-0 rendering when scrolling back and forth.
  File? getMemoryCachedFile(
    String? key, {
    String? imageUrl,
    String? cardId,
    String? cardName,
    String version = 'normal',
    bool isBack = false,
  }) {
    final candidates = <String>[];
    final visited = <String>{};

    void addCandidate(String? k) {
      if (k == null) return;
      final trimmed = k.trim();
      if (trimmed.isEmpty) return;
      if (visited.add(trimmed)) {
        candidates.add(trimmed);
      }
      final lower = trimmed.toLowerCase();
      if (lower.startsWith('http://') || lower.startsWith('https://')) {
        final norm = normalizeUrl(trimmed);
        if (norm.isNotEmpty && visited.add(norm)) {
          candidates.add(norm);
        }
      }
    }

    addCandidate(key);
    addCandidate(imageUrl);
    if (cardId != null && cardId.trim().isNotEmpty) {
      final cid = cardId.trim();
      if (cid.startsWith('deck-')) {
        addCandidate(deckCoverKey(cid));
      } else {
        final effVer = imageUrl != null && imageUrl.trim().isNotEmpty
            ? inferImageVersion(imageUrl, fallback: version)
            : version;
        final isBackFace = isBack || (imageUrl?.toLowerCase().contains('/back/') ?? false);
        addCandidate(cardArtKey(cid, version: effVer, isBack: isBackFace));
      }
    }

    var head = 0;
    while (head < candidates.length) {
      final cand = candidates[head++];
      final memFile = _memoryFiles[cand];
      if (memFile != null) {
        if (memFile.existsSync()) {
          if (key != null && key.trim().isNotEmpty) {
            _memoryFiles[key.trim()] = memFile;
          }
          return memFile;
        } else {
          _memoryFiles.remove(cand);
        }
      }
      final aliases = _aliases[cand];
      if (aliases != null) {
        for (final a in aliases) {
          addCandidate(a);
        }
      }
    }

    final checkUrl = (imageUrl ?? key ?? '').trim();
    final parsedNamed = parseScryfallNamedUrl(checkUrl);
    if (parsedNamed != null) {
      final nameKey = cardNameKey(parsedNamed.name, version: parsedNamed.version);
      if (nameKey.isNotEmpty) {
        final directNameFile = _memoryFiles[nameKey];
        if (directNameFile != null && directNameFile.existsSync()) {
          return directNameFile;
        }
        final nameCandidates = _cardNameCacheKeys[nameKey];
        if (nameCandidates != null) {
          for (final cand in nameCandidates) {
            final memFile = _memoryFiles[cand];
            if (memFile != null && memFile.existsSync()) {
              if (key != null && key.trim().isNotEmpty) {
                _memoryFiles[key.trim()] = memFile;
              }
              return memFile;
            }
          }
        }
      }
    }

    return null;
  }

  /// Resolves registered alias for [key] if one exists.
  String? resolveKeyAlias(String key) => _aliases[key.trim()]?.firstOrNull;

  /// Resolves all registered aliases for [key].
  Set<String> resolveKeyAliases(String key) => _aliases[key.trim()] ?? const {};

  /// Alias-aware cache lookup that checks the key, its registered aliases,
  /// normalized URLs, repo storage for raw query-parameterized URLs, and
  /// card-name fallbacks for generic Scryfall named lookups.
  @override
  Future<FileInfo?> getFileFromCache(String key, {bool ignoreMemCache = false}) async {
    final cleanKey = key.trim();
    if (cleanKey.isEmpty) return null;

    // 0. Fast in-memory verified file lookup
    if (!ignoreMemCache) {
      final memFile = _memoryFiles[cleanKey];
      if (memFile != null) {
        if (await memFile.exists()) {
          return FileInfo(
            memFile,
            FileSource.Cache,
            DateTime.now().add(stalePeriod),
            cleanKey,
          );
        } else {
          _memoryFiles.remove(cleanKey);
        }
      }
    }

    // 1. Direct lookup
    var info = await super.getFileFromCache(cleanKey, ignoreMemCache: ignoreMemCache);
    if (info != null && await info.file.exists()) {
      _recordMemoryFile(cleanKey, info.file);
      return _ensureFreshFileInfo(info);
    }

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
      if (!ignoreMemCache) {
        final candMemFile = _memoryFiles[cand];
        if (candMemFile != null && await candMemFile.exists()) {
          if (cand != cleanKey) {
            registerKeyAlias(cleanKey, cand);
          }
          _recordMemoryFile(cleanKey, candMemFile);
          return FileInfo(
            candMemFile,
            FileSource.Cache,
            DateTime.now().add(stalePeriod),
            cand,
          );
        }
      }

      info = await super.getFileFromCache(cand, ignoreMemCache: ignoreMemCache);
      if (info != null && await info.file.exists()) {
        if (cand != cleanKey) {
          registerKeyAlias(cleanKey, cand);
        }
        _recordMemoryFile(cleanKey, info.file);
        _recordMemoryFile(cand, info.file);
        return _ensureFreshFileInfo(info);
      }

      final candAliases = _aliases[cand];
      if (candAliases != null) {
        for (final alias in candAliases) {
          enqueue(alias);
        }
      }
    }

    // 3. Fallback for generic Scryfall named URLs (e.g. Precon / fallback cards):
    // If any playable printing of the same card name + image version is already cached,
    // return that cached image immediately without hitting the network.
    for (final v in visited) {
      final parsedNamed = parseScryfallNamedUrl(v);
      if (parsedNamed != null) {
        final nameKey = cardNameKey(parsedNamed.name, version: parsedNamed.version);
        final nameCandidates = _cardNameCacheKeys[nameKey];
        if (nameCandidates != null) {
          for (final cand in nameCandidates.toList()) {
            if (visited.contains(cand)) continue;
            info = await super.getFileFromCache(cand, ignoreMemCache: ignoreMemCache);
            if (info != null && await info.file.exists()) {
              _recordMemoryFile(cleanKey, info.file);
              _recordMemoryFile(nameKey, info.file);
              return _ensureFreshFileInfo(info);
            }
          }
        }
      }
    }

    return null;
  }

  /// Overrides getSingleFile so all callers check the multi-alias cache first.
  @override
  Future<File> getSingleFile(
    String url, {
    String? key,
    Map<String, String>? headers,
  }) async {
    final cleanUrl = url.trim();
    final effectiveKey =
        (key != null && key.trim().isNotEmpty) ? key.trim() : cleanUrl;
    if (cleanUrl.isNotEmpty && effectiveKey.isNotEmpty) {
      registerKeyAlias(effectiveKey, cleanUrl);
    }
    var cacheFile = await getFileFromCache(effectiveKey);
    if (cacheFile == null && cleanUrl.isNotEmpty && cleanUrl != effectiveKey) {
      cacheFile = await getFileFromCache(cleanUrl);
    }
    if (cacheFile != null && await cacheFile.file.exists()) {
      _recordMemoryFile(effectiveKey, cacheFile.file);
      return cacheFile.file;
    }
    final downloaded = await downloadFile(
      cleanUrl,
      key: effectiveKey,
      authHeaders: headers,
    );
    _recordMemoryFile(effectiveKey, downloaded.file);
    return downloaded.file;
  }

  /// Overrides getFileStream so CachedNetworkImage always checks all aliases
  /// in the cache FIRST and never re-downloads an image once cached on disk.
  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) {
    final cleanUrl = url.trim();
    final effectiveKey =
        (key != null && key.trim().isNotEmpty) ? key.trim() : cleanUrl;
    if (cleanUrl.isNotEmpty && effectiveKey.isNotEmpty) {
      registerKeyAlias(effectiveKey, cleanUrl);
    }
    final parsedNamed = parseScryfallNamedUrl(cleanUrl);
    if (parsedNamed != null) {
      registerCardAliases(
        cacheKey: effectiveKey,
        imageUrl: cleanUrl,
        cardName: parsedNamed.name,
        version: parsedNamed.version,
      );
    }

    final streamController = StreamController<FileResponse>();
    _pushCardFileToStream(
      streamController,
      cleanUrl,
      effectiveKey,
      headers,
      withProgress,
    );
    return streamController.stream;
  }

  Future<void> _pushCardFileToStream(
    StreamController<FileResponse> streamController,
    String url,
    String key,
    Map<String, String>? headers,
    bool withProgress,
  ) async {
    FileInfo? cacheFile;
    try {
      cacheFile = await getFileFromCache(key);
      if (cacheFile == null && url.isNotEmpty && url != key) {
        cacheFile = await getFileFromCache(url);
      }
      if (cacheFile != null && await cacheFile.file.exists()) {
        _recordMemoryFile(key, cacheFile.file);
        if (url.isNotEmpty) {
          _recordMemoryFile(url, cacheFile.file);
        }
        if (!streamController.isClosed) {
          streamController.add(_ensureFreshFileInfo(cacheFile));
          await streamController.close();
        }
        return;
      }
    } on Object catch (_) {}

    try {
      await for (final response in webHelper.downloadFile(
        url,
        key: key,
        authHeaders: headers,
      )) {
        if (streamController.isClosed) break;
        if (response is DownloadProgress && withProgress) {
          streamController.add(response);
        }
        if (response is FileInfo) {
          _recordMemoryFile(key, response.file);
          if (url.isNotEmpty) {
            _recordMemoryFile(url, response.file);
            final normUrl = normalizeUrl(url);
            if (normUrl.isNotEmpty && normUrl != key) {
              registerKeyAlias(key, normUrl);
            }
          }
          streamController.add(_ensureFreshFileInfo(response));
        }
      }
    } on Object catch (e) {
      if (cacheFile == null && streamController.hasListener) {
        streamController.addError(e);
      }
    }
    await streamController.close();
  }

  /// Overrides putFile to ensure images cached directly via putFile under raw URLs
  /// automatically register bidirectional aliases with their canonical normalized URLs,
  /// dual-caches under the normalized URL, and populates in-memory file references.
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
    _recordMemoryFile(effectiveKey, file);
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
          _recordMemoryFile(norm, file);
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
    final file = await super.putFileStream(
      url,
      source,
      key: key,
      eTag: eTag,
      maxAge: maxAge,
      fileExtension: fileExtension,
    );
    _recordMemoryFile(cleanKey, file);
    if (url.trim().isNotEmpty) {
      _recordMemoryFile(url.trim(), file);
    }
    return file;
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
      if (cleanUrl.isNotEmpty && cleanKey.isNotEmpty) {
        registerKeyAlias(cleanKey, cleanUrl);
      }
    }
    final info = await super.downloadFile(
      url,
      key: key,
      authHeaders: authHeaders,
      force: force,
    );
    if (cleanUrl.isNotEmpty) {
      _recordMemoryFile(cleanUrl, info.file);
    }
    if (key != null && key.trim().isNotEmpty) {
      _recordMemoryFile(key.trim(), info.file);
    }
    return _ensureFreshFileInfo(info);
  }

  @override
  Future<void> removeFile(String key) async {
    final clean = key.trim();
    _memoryFiles.remove(clean);
    final lower = clean.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      _memoryFiles.remove(normalizeUrl(clean));
    }
    await super.removeFile(key);
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
    final keys = [
      cardArtKey(cardId),
      cardArtKey(cardId, isBack: true),
      cardArtKey(cardId, version: 'small'),
      cardArtKey(cardId, version: 'art_crop'),
    ];
    for (final key in keys) {
      await removeFile(key);
      final aliases = _aliases.remove(key) ?? const <String>{};
      for (final alias in aliases) {
        await removeFile(alias);
        _aliases[alias]?.remove(key);
        FailedImageRegistry.instance.reset(alias, cacheKey: key);
      }
      FailedImageRegistry.instance.reset(null, cacheKey: key);
    }
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
