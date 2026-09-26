import 'package:flutter/foundation.dart';
import 'package:countr/core/database/app_database.dart';
import 'dart:convert';

class LegalityRequest {
  final String format;
  final List<VaultItem> items;

  LegalityRequest(this.format, this.items);
}

class LegalityResult {
  final bool isLegal;
  final List<String> violations;

  LegalityResult(this.isLegal, this.violations);
}

class LegalityEnforcer {
  static Future<LegalityResult> checkLegality(String format, List<VaultItem> items) async {
    // Run in a background isolate
    return await compute(_checkLegalityIsolate, LegalityRequest(format, items));
  }

  static LegalityResult _checkLegalityIsolate(LegalityRequest request) {
    final format = request.format.toLowerCase();
    final violations = <String>[];

    for (final item in request.items) {
      if (item.dynamicData.isNotEmpty) {
        try {
          final data = jsonDecode(item.dynamicData);
          if (data['legalities'] != null) {
            final legalities = data['legalities'] as Map<String, dynamic>;
            final status = legalities[format];
            if (status != 'legal' && status != 'restricted') {
              violations.add('${item.name} is not legal in $format (Status: $status)');
            }
          }
        } catch (e, stackTrace) {
          debugPrint('[LegalityEnforcer] Error parsing legalities for ${item.name}: $e\n$stackTrace');
          // If parsing fails, skip
        }
      }
    }

    return LegalityResult(violations.isEmpty, violations);
  }
}

enum LegalityStatus {
  legal,
  notLegal,
  banned,
  restricted,
  unknown,
}

class CardLegality {
  final LegalityStatus status;
  final String format;
  final String rawStatus;

  const CardLegality({
    required this.status,
    required this.format,
    required this.rawStatus,
  });

  bool get isLegal => status == LegalityStatus.legal;
  bool get isBanned => status == LegalityStatus.banned;
  bool get isRestricted => status == LegalityStatus.restricted;
  bool get isNotLegal => status == LegalityStatus.notLegal;
  bool get hasWarning => !isLegal && status != LegalityStatus.unknown;

  String get badgeLabel {
    switch (status) {
      case LegalityStatus.banned:
        return 'BANNED';
      case LegalityStatus.restricted:
        return 'RESTRICTED';
      case LegalityStatus.notLegal:
        return 'NOT LEGAL';
      case LegalityStatus.legal:
        return 'LEGAL';
      case LegalityStatus.unknown:
        return 'UNKNOWN';
    }
  }

  /// Normalizes user or deck format string into Scryfall canonical format keys.
  static String normalizeFormat(String format) {
    final lower = format.toLowerCase().trim();
    if (lower.contains('commander') || lower.contains('edh')) return 'commander';
    if (lower.contains('modern')) return 'modern';
    if (lower.contains('standard')) return 'standard';
    if (lower.contains('pioneer')) return 'pioneer';
    if (lower.contains('pauper')) return 'pauper';
    if (lower.contains('legacy')) return 'legacy';
    if (lower.contains('vintage')) return 'vintage';
    if (lower.contains('brawl')) return 'brawl';
    if (lower.contains('historic')) return 'historic';
    if (lower.contains('penny')) return 'penny';
    if (lower.contains('alchemy')) return 'alchemy';
    return lower;
  }

  /// Evaluates legality from either:
  /// - A dynamicData JSON string containing a 'legalities' object
  /// - A `Map<String, dynamic>` representing dynamicData or a legalities map
  static CardLegality evaluate(dynamic dynamicDataOrLegalities, String deckFormat) {
    final formatKey = normalizeFormat(deckFormat);
    if (dynamicDataOrLegalities == null) {
      return CardLegality(
        status: LegalityStatus.unknown,
        format: formatKey,
        rawStatus: 'unknown',
      );
    }

    Map<String, dynamic>? data;
    if (dynamicDataOrLegalities is String) {
      if (dynamicDataOrLegalities.trim().isEmpty) {
        return CardLegality(
          status: LegalityStatus.unknown,
          format: formatKey,
          rawStatus: 'unknown',
        );
      }
      try {
        final decoded = jsonDecode(dynamicDataOrLegalities);
        if (decoded is Map<String, dynamic>) {
          data = decoded;
        } else if (decoded is Map) {
          data = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        return CardLegality(
          status: LegalityStatus.unknown,
          format: formatKey,
          rawStatus: 'unknown',
        );
      }
    } else if (dynamicDataOrLegalities is Map<String, dynamic>) {
      data = dynamicDataOrLegalities;
    } else if (dynamicDataOrLegalities is Map) {
      data = Map<String, dynamic>.from(dynamicDataOrLegalities);
    }

    if (data == null) {
      return CardLegality(
        status: LegalityStatus.unknown,
        format: formatKey,
        rawStatus: 'unknown',
      );
    }

    Map<String, dynamic>? legalities;
    if (data.containsKey('legalities')) {
      final legVal = data['legalities'];
      if (legVal is Map) {
        legalities = Map<String, dynamic>.from(legVal);
      } else {
        return CardLegality(
          status: LegalityStatus.unknown,
          format: formatKey,
          rawStatus: 'unknown',
        );
      }
    } else if (data.containsKey('standard') ||
        data.containsKey('commander') ||
        data.containsKey('modern') ||
        data.containsKey('legacy') ||
        data.containsKey('vintage') ||
        data.containsKey('pauper') ||
        data.containsKey('pioneer') ||
        data.containsKey('historic') ||
        data.containsKey('brawl') ||
        data.containsKey('alchemy') ||
        data.containsKey('penny')) {
      legalities = data;
    } else {
      return CardLegality(
        status: LegalityStatus.unknown,
        format: formatKey,
        rawStatus: 'unknown',
      );
    }

    if (legalities.isEmpty) {
      return CardLegality(
        status: LegalityStatus.unknown,
        format: formatKey,
        rawStatus: 'unknown',
      );
    }

    final raw = legalities[formatKey]?.toString().toLowerCase();
    if (raw == null) {
      return CardLegality(
        status: LegalityStatus.notLegal,
        format: formatKey,
        rawStatus: 'not_legal',
      );
    }

    switch (raw) {
      case 'legal':
        return CardLegality(status: LegalityStatus.legal, format: formatKey, rawStatus: raw);
      case 'banned':
        return CardLegality(status: LegalityStatus.banned, format: formatKey, rawStatus: raw);
      case 'restricted':
        return CardLegality(status: LegalityStatus.restricted, format: formatKey, rawStatus: raw);
      case 'not_legal':
      default:
        return CardLegality(status: LegalityStatus.notLegal, format: formatKey, rawStatus: raw);
    }
  }
}

