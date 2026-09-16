/// Static dictionary and extraction utilities for beginner-friendly MTG keyword mechanics.
class MtgKeywordGlossary {
  const MtgKeywordGlossary._();

  /// Beginner-friendly, jargon-free explanations for 12 common MTG mechanics.
  static const Map<String, String> dictionary = {
    'Vigilance': "Attacking doesn't cause this creature to tap, allowing it to still block on opponents' turns.",
    'Flying': 'This creature can only be blocked by other creatures with flying or reach.',
    'Trample': "Excess combat damage beyond what's needed to destroy blockers is dealt directly to the defending player or planeswalker.",
    'Haste': 'This creature can attack and tap to activate abilities immediately the turn it enters the battlefield.',
    'Lifelink': 'Damage dealt by this creature also heals you for that same amount of life.',
    'Deathtouch': 'Any amount of damage this creature deals to another creature is lethal and destroys it.',
    'First Strike': 'This creature deals combat damage before creatures without first strike.',
    'Double Strike': 'This creature deals damage twice in combat: once before normal creatures, and again during normal combat damage.',
    'Reach': 'This creature can block creatures that have flying.',
    'Menace': 'This creature cannot be blocked except by two or more creatures.',
    'Ward': "Whenever this creature is targeted by an opponent's spell or ability, counter that effect unless they pay the ward cost.",
    'Hexproof': 'This creature cannot be targeted by spells or abilities your opponents control.',
  };

  /// Returns the definition for a given keyword if present in the dictionary.
  static String? getDefinition(String keyword) {
    if (dictionary.containsKey(keyword)) {
      return dictionary[keyword];
    }
    for (final entry in dictionary.entries) {
      if (entry.key.toLowerCase() == keyword.toLowerCase()) {
        return entry.value;
      }
    }
    return null;
  }

  /// Extracts keywords from both the [keywords] list and regex-parsing [oracleText]
  /// (using word boundaries `\b`, case-insensitive).
  ///
  /// Returns deduplicated canonical keyword names present in the dictionary.
  static List<String> extractKeywords({
    List<dynamic>? keywords,
    String? oracleText,
  }) {
    final result = <String>{};

    // 1. Process keywords list
    if (keywords != null) {
      for (final item in keywords) {
        if (item == null) continue;
        final raw = item.toString().trim();
        if (raw.isEmpty) continue;

        for (final canonical in dictionary.keys) {
          if (canonical.toLowerCase() == raw.toLowerCase() ||
              RegExp(r'\b' + RegExp.escape(canonical) + r'\b', caseSensitive: false).hasMatch(raw)) {
            result.add(canonical);
          }
        }
      }
    }

    // 2. Process oracleText with regex word boundaries
    if (oracleText != null && oracleText.isNotEmpty) {
      final matches = <MapEntry<int, String>>[];
      for (final canonical in dictionary.keys) {
        final pattern = RegExp(r'\b' + RegExp.escape(canonical) + r'\b', caseSensitive: false);
        for (final m in pattern.allMatches(oracleText)) {
          matches.add(MapEntry(m.start, canonical));
        }
      }

      // Sort by position in oracle text to maintain natural reading order
      matches.sort((a, b) => a.key.compareTo(b.key));
      for (final entry in matches) {
        result.add(entry.value);
      }
    }

    return result.toList();
  }
}
