import 'dart:convert';
import 'package:flutter/foundation.dart';

/// LRU-bounded memoization cache for parsed dynamic data JSON maps.
///
/// Eliminates synchronous [jsonDecode] invocations during scroll layout passes
/// and [Widget.build] loops across lists and grids.
class ParsedJsonCache {
  ParsedJsonCache._();

  static final Map<String, Map<String, dynamic>> _cache = {};
  static const int maxCapacity = 50000;

  /// Retrieves a memoized [Map<String, dynamic>] from [jsonString], or parses
  /// and caches it if not already present.
  ///
  /// Returns an empty map on empty, invalid, or malformed inputs without throwing.
  static Map<String, dynamic> parse(String? jsonString) {
    if (jsonString == null || jsonString.isEmpty) {
      return const {};
    }

    final cached = _cache[jsonString];
    if (cached != null) {
      return cached;
    }

    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is Map<String, dynamic>) {
        if (_cache.length >= maxCapacity) {
          _cache.remove(_cache.keys.first);
        }
        _cache[jsonString] = decoded;
        return decoded;
      }
    } catch (e, stackTrace) {
      debugPrint('[ParsedJsonCache] Failed parsing JSON: $e\n$stackTrace');
    }

    return const {};
  }

  /// Clears all entries in the parsed JSON cache.
  static void clear() {
    _cache.clear();
  }

  /// The number of currently memoized JSON entries in the cache.
  static int get count => _cache.length;
}
