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
        } catch (_) {
          // If parsing fails, skip
        }
      }
    }

    return LegalityResult(violations.isEmpty, violations);
  }
}
