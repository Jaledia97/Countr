import 'dart:convert';

/// High-performance parser that extracts required physical tokens from MTG Oracle rules texts.
class DeckTokenExtractor {
  DeckTokenExtractor._();

  /// Known predefined token types that may appear without power/toughness stats.
  static const Set<String> predefinedTokens = {
    'Treasure',
    'Food',
    'Clue',
    'Blood',
    'Map',
    'Incubator',
    'Powerstone',
    'Role',
    'Walker',
  };

  /// Non-creature descriptors, colors, types, and qualifiers to filter out from candidate names.
  static const Set<String> _descriptors = {
    'a',
    'an',
    'and',
    'that',
    'many',
    'x',
    'one',
    'two',
    'three',
    'four',
    'five',
    'six',
    'seven',
    'eight',
    'nine',
    'ten',
    'colorless',
    'white',
    'blue',
    'black',
    'red',
    'green',
    'artifact',
    'creature',
    'enchantment',
    'token',
    'tokens',
    'tapped',
    'attacking',
    'legendary',
    'with',
    'named',
  };

  /// Regex matching predefined artifact/enchantment/special token creation.
  /// Matches: "create a Treasure token", "create two Food tokens", "create an Incubator token",
  /// "create a Royal Role token", "create a 2/2 black Walker creature token", etc.
  static final RegExp _predefinedRegex = RegExp(
    r'\b(?:create[s]?|creating)\s+(?:[A-Za-z0-9—/\-]+\s+)*(Treasure|Food|Clue|Blood|Map|Incubator|Powerstone|Role|Walker)\s+(?:artifact\s+|creature\s+|enchantment\s+)?tokens?\b',
    caseSensitive: false,
  );

  /// Regex matching generic creature/artifact token creation patterns with stats or types.
  /// Matches: "create a 0/0 colorless Construct artifact creature token",
  /// "create two 1/1 red Goblin creature tokens", "create X 1/1 green Saproling creature tokens", etc.
  static final RegExp _generalTokenRegex = RegExp(
    r'\b(?:create[s]?|creating)\s+(?:a|an|\d+|X|[a-z]+)?\s*(?:tapped\s+|attacking\s+|legendary\s+)?([0-9/X*]+)?\s*([A-Za-z0-9\s—/\-]+?)\s+(?:artifact\s+|creature\s+|enchantment\s+)?tokens?\b',
    caseSensitive: false,
  );

  /// Extracts an alphabetically sorted, deduplicated list of unique token names required by the cards.
  static List<String> extractRequiredTokens(List<String> oracleTexts) {
    if (oracleTexts.isEmpty) return const [];

    final tokens = <String>{};

    for (final text in oracleTexts) {
      if (text.trim().isEmpty) continue;

      // 1. Check for predefined special tokens first
      final predefinedMatches = _predefinedRegex.allMatches(text);
      for (final match in predefinedMatches) {
        final rawToken = match.group(1)?.trim();
        if (rawToken != null && rawToken.isNotEmpty) {
          final normalized = _normalizeTokenName(rawToken);
          if (normalized.isNotEmpty) {
            tokens.add(normalized);
          }
        }
      }

      // 2. Check for general creature / custom token patterns
      final generalMatches = _generalTokenRegex.allMatches(text);
      for (final match in generalMatches) {
        final captured = match.group(2)?.trim();
        if (captured != null && captured.isNotEmpty) {
          final words = captured.split(RegExp(r'\s+'));
          final candidates = words.where((w) {
            final lower = w.toLowerCase();
            if (_descriptors.contains(lower)) return false;
            if (RegExp(r'^[0-9/X*]+$').hasMatch(w)) return false;
            return true;
          }).toList();

          if (candidates.isNotEmpty) {
            final candidate = _normalizeTokenName(candidates.last);
            if (candidate.isNotEmpty) {
              tokens.add(candidate);
            }
          }
        }
      }
    }

    final result = tokens.toList()..sort();
    return result;
  }

  /// Helper to extract Oracle texts safely from dynamic Scryfall payloads.
  /// Handles both single-faced cards (`oracle_text`) and dual-faced cards (`card_faces[].oracle_text`).
  static List<String> extractOracleTextsFromCardData(dynamic dynamicData) {
    if (dynamicData == null) return const [];
    Map<String, dynamic> data;
    if (dynamicData is String) {
      if (dynamicData.trim().isEmpty) return const [];
      try {
        data = jsonDecode(dynamicData) as Map<String, dynamic>;
      } catch (_) {
        return const [];
      }
    } else if (dynamicData is Map<String, dynamic>) {
      data = dynamicData;
    } else {
      return const [];
    }

    final texts = <String>[];
    if (data['oracle_text'] is String) {
      texts.add(data['oracle_text'] as String);
    }
    if (data['card_faces'] is List) {
      for (final face in data['card_faces']) {
        if (face is Map && face['oracle_text'] is String) {
          texts.add(face['oracle_text'] as String);
        }
      }
    }
    return texts;
  }

  static String _normalizeTokenName(String raw) {
    if (raw.isEmpty) return raw;
    final clean = raw.replaceAll(RegExp(r'[^A-Za-z0-9\s]'), '').trim();
    if (clean.isEmpty) return '';
    return clean[0].toUpperCase() + clean.substring(1).toLowerCase();
  }
}
