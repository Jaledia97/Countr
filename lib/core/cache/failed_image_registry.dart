import 'dart:math' as math;

/// Enumerates the classifications of image loading failures in Countr.
enum ImageFailureType {
  /// Permanent 404 Not Found from CDN or image endpoint.
  terminalNotFound,

  /// Permanent client error (400 Bad Request, 403 Forbidden, 410 Gone, 422 Unprocessable).
  terminalClientError,

  /// Malformed URL, unsupported URI scheme, or empty URI.
  terminalInvalidUri,

  /// Exhausted maximum transient retry attempts across the application session.
  exhaustedRetries,

  /// Transient network error (SocketException, Timeout, 5xx server error, 429 rate limit).
  transientNetwork,
}

/// Record tracking attempt counts, terminal status, timestamps, and error reasons for an image.
class ImageFailureRecord {
  final String key;
  int attemptCount;
  bool isTerminal;
  ImageFailureType failureType;
  int? httpStatusCode;
  String? errorDescription;
  final DateTime firstFailedAt;
  DateTime lastFailedAt;

  ImageFailureRecord({
    required this.key,
    this.attemptCount = 1,
    this.isTerminal = false,
    this.failureType = ImageFailureType.transientNetwork,
    this.httpStatusCode,
    this.errorDescription,
    DateTime? firstFailedAt,
    DateTime? lastFailedAt,
  })  : firstFailedAt = firstFailedAt ?? DateTime.now(),
        lastFailedAt = lastFailedAt ?? DateTime.now();

  /// Whether the image is currently considered in a failed state given [maxAttempts].
  bool isFailed(int maxAttempts) => isTerminal || attemptCount >= maxAttempts;

  /// Marks this record permanently terminal.
  void markTerminal({
    int? statusCode,
    ImageFailureType type = ImageFailureType.terminalClientError,
    String? reason,
    int? maxAttempts,
  }) {
    isTerminal = true;
    failureType = type;
    if (statusCode != null) httpStatusCode = statusCode;
    if (reason != null) errorDescription = reason;
    if (attemptCount < 1) attemptCount = 1;
    if (maxAttempts != null && attemptCount < maxAttempts) {
      attemptCount = maxAttempts;
    }
    lastFailedAt = DateTime.now();
  }

  /// Increments attempt count and applies terminal locking rules.
  void recordAttempt({
    int? statusCode,
    Object? error,
    int maxAttempts = 3,
  }) {
    if (isTerminal && attemptCount >= maxAttempts) {
      return;
    }
    attemptCount++;
    lastFailedAt = DateTime.now();
    if (statusCode != null) httpStatusCode = statusCode;
    if (error != null) errorDescription = error.toString();

    if (statusCode == 404) {
      isTerminal = true;
      failureType = ImageFailureType.terminalNotFound;
    } else if (statusCode != null &&
        statusCode >= 400 &&
        statusCode < 500 &&
        statusCode != 429) {
      isTerminal = true;
      failureType = ImageFailureType.terminalClientError;
    } else if (attemptCount >= maxAttempts) {
      isTerminal = true;
      failureType = ImageFailureType.exhaustedRetries;
    }
  }
}

/// Global session-level registry tracking failed image loads, attempt counts,
/// and permanent terminal locks across Countr.
class FailedImageRegistry {
  static final FailedImageRegistry _instance = FailedImageRegistry._();
  static FailedImageRegistry get instance => _instance;
  factory FailedImageRegistry() => _instance;

  FailedImageRegistry._();

  /// Default session retry cap: strictly 2-3 attempts across session.
  static const int defaultMaxAttempts = 3;

  int _maxAttempts = defaultMaxAttempts;

  /// Maximum allowed attempts before permanent lock (clamped 1..5).
  int get maxAttempts => _maxAttempts;
  set maxAttempts(int value) {
    _maxAttempts = value.clamp(1, 5);
  }

  final Map<String, ImageFailureRecord> _records = {};
  final Map<String, String> _urlToCacheKey = {};
  final Map<String, String> _cacheKeyToUrl = {};

  /// Associates an image URL with its deterministic cacheKey (e.g. card_art_$cardId).
  void linkKeys(String url, String cacheKey) {
    final cleanUrl = url.trim();
    final cleanKey = cacheKey.trim();
    if (cleanUrl.isEmpty || cleanKey.isEmpty || cleanUrl == cleanKey) return;

    _urlToCacheKey[cleanUrl] = cleanKey;
    _cacheKeyToUrl[cleanKey] = cleanUrl;

    // Synchronize existing records if either was already recorded
    final recordUrl = _records[cleanUrl];
    final recordKey = _records[cleanKey];

    if (recordUrl != null && recordKey == null) {
      _records[cleanKey] = recordUrl;
    } else if (recordKey != null && recordUrl == null) {
      _records[cleanUrl] = recordKey;
    } else if (recordUrl != null && recordKey != null && recordUrl != recordKey) {
      final merged = ImageFailureRecord(
        key: cleanUrl,
        attemptCount: math.max(recordUrl.attemptCount, recordKey.attemptCount),
        isTerminal: recordUrl.isTerminal || recordKey.isTerminal,
        failureType: recordUrl.isTerminal ? recordUrl.failureType : recordKey.failureType,
        httpStatusCode: recordUrl.httpStatusCode ?? recordKey.httpStatusCode,
        errorDescription: recordUrl.errorDescription ?? recordKey.errorDescription,
        firstFailedAt: recordUrl.firstFailedAt.isBefore(recordKey.firstFailedAt)
            ? recordUrl.firstFailedAt
            : recordKey.firstFailedAt,
        lastFailedAt: recordUrl.lastFailedAt.isAfter(recordKey.lastFailedAt)
            ? recordUrl.lastFailedAt
            : recordKey.lastFailedAt,
      );
      _records[cleanUrl] = merged;
      _records[cleanKey] = merged;
    }
  }

  String? _findAlias(String key) {
    return _urlToCacheKey[key] ?? _cacheKeyToUrl[key];
  }

  /// Retrieves record for [key] or its linked alias if one exists.
  ImageFailureRecord? getRecord(String? key) {
    if (key == null) return null;
    final direct = _records[key];
    if (direct != null) return direct;
    final clean = key.trim();
    final cleanDirect = _records[clean];
    if (cleanDirect != null) return cleanDirect;
    final alias = _findAlias(clean);
    if (alias != null) return _records[alias];
    return null;
  }

  /// Determines whether [url] or [cacheKey] is currently considered failed.
  bool isFailed(String? url, {String? cacheKey}) {
    if (url != null && _isInherentlyInvalidUri(url)) {
      return true;
    }

    final recordUrl = getRecord(url);
    if (recordUrl != null && recordUrl.isFailed(_maxAttempts)) {
      return true;
    }

    final recordKey = getRecord(cacheKey);
    if (recordKey != null && recordKey.isFailed(_maxAttempts)) {
      return true;
    }

    return false;
  }

  /// Determines whether [url] or [cacheKey] is permanently dead.
  bool isTerminal(String? url, {String? cacheKey}) {
    if (url != null && _isInherentlyInvalidUri(url)) {
      return true;
    }
    final recordUrl = getRecord(url);
    if (recordUrl != null && recordUrl.isTerminal) return true;
    final recordKey = getRecord(cacheKey);
    if (recordKey != null && recordKey.isTerminal) return true;
    return false;
  }

  /// Returns the attempt count recorded for [url] or [cacheKey].
  int getAttempts(String? url, {String? cacheKey}) {
    final recordUrl = getRecord(url);
    final recordKey = getRecord(cacheKey);
    return math.max(
      recordUrl?.attemptCount ?? 0,
      recordKey?.attemptCount ?? 0,
    );
  }

  /// Records an attempt against [url] and optional [cacheKey].
  void recordAttempt(
    String url, {
    String? cacheKey,
    int? statusCode,
    Object? error,
  }) {
    final cleanUrl = url.trim();
    if (cacheKey != null && cacheKey.trim().isNotEmpty) {
      linkKeys(url, cacheKey);
    }

    if (_isInherentlyInvalidUri(url)) {
      markTerminal(
        url,
        cacheKey: cacheKey,
        statusCode: statusCode,
        type: ImageFailureType.terminalInvalidUri,
        reason: error?.toString() ?? 'Malformed URI or invalid scheme',
      );
      return;
    }

    final existing = getRecord(url) ?? getRecord(cacheKey);
    final record = existing ??
        ImageFailureRecord(
          key: cleanUrl,
          attemptCount: 0,
        );

    record.recordAttempt(
      statusCode: statusCode,
      error: error,
      maxAttempts: _maxAttempts,
    );

    _records[url] = record;
    _records[cleanUrl] = record;
    final alias = _findAlias(cleanUrl);
    if (alias != null) _records[alias] = record;
    if (cacheKey != null) {
      _records[cacheKey] = record;
      _records[cacheKey.trim()] = record;
    }
  }

  /// Immediately locks [url] and optional [cacheKey] as a terminal failure.
  void markTerminal(
    String url, {
    String? cacheKey,
    int? statusCode,
    ImageFailureType type = ImageFailureType.terminalNotFound,
    String? reason,
  }) {
    final cleanUrl = url.trim();
    if (cacheKey != null && cacheKey.trim().isNotEmpty) {
      linkKeys(url, cacheKey);
    }

    final existing = getRecord(url) ?? getRecord(cacheKey);
    final record = existing ??
        ImageFailureRecord(
          key: cleanUrl,
          attemptCount: _maxAttempts,
          isTerminal: true,
          failureType: type,
          httpStatusCode: statusCode,
          errorDescription: reason,
        );

    record.markTerminal(
      statusCode: statusCode,
      type: type,
      reason: reason,
      maxAttempts: _maxAttempts,
    );

    _records[url] = record;
    _records[cleanUrl] = record;
    final alias = _findAlias(cleanUrl);
    if (alias != null) _records[alias] = record;
    if (cacheKey != null) {
      _records[cacheKey] = record;
      _records[cacheKey.trim()] = record;
    }
  }

  /// Resets failure state for [url], [cacheKey], and any linked alias.
  void reset(String? url, {String? cacheKey}) {
    if (url != null) {
      final cleanUrl = url.trim();
      final alias = _findAlias(cleanUrl);
      _records.remove(url);
      _records.remove(cleanUrl);
      if (alias != null) _records.remove(alias);
    }
    if (cacheKey != null) {
      final cleanKey = cacheKey.trim();
      final alias = _findAlias(cleanKey);
      _records.remove(cacheKey);
      _records.remove(cleanKey);
      if (alias != null) _records.remove(alias);
    }
  }

  /// Clears all recorded failures, links, and resets session state.
  void clear() {
    _records.clear();
    _urlToCacheKey.clear();
    _cacheKeyToUrl.clear();
  }

  /// Diagnostics: number of distinct failed image targets.
  int get failedCount => _records.values.where((r) => r.isFailed(_maxAttempts)).toSet().length;

  /// Diagnostics: list of all failed URLs/keys currently blocked.
  List<String> get allFailedKeys => _records.entries
      .where((e) => e.value.isFailed(_maxAttempts))
      .map((e) => e.key)
      .toList();

  static bool _isInherentlyInvalidUri(String uriString) {
    final trimmed = uriString.trim();
    if (trimmed.isEmpty) return true;
    if (trimmed.startsWith('card_art_') || trimmed.startsWith('deck_cover_')) {
      return false;
    }
    if (trimmed.contains(' ') && (trimmed.startsWith('http') || trimmed.contains('://'))) {
      return true;
    }
    final parsed = Uri.tryParse(trimmed);
    if (parsed == null) return true;
    if (parsed.hasScheme) {
      final scheme = parsed.scheme.toLowerCase();
      return scheme != 'http' && scheme != 'https' && scheme != 'file';
    }
    if (trimmed.contains('://')) {
      return true;
    }
    return false;
  }
}
