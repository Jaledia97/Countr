import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/database/app_database.dart';

/// Supported color match modes for Magic: The Gathering filtering.
enum ColorMatchMode {
  /// Card colors must match selected colors exactly.
  exactly,

  /// Card colors must be a subset of selected colors.
  atMost,

  /// Selected colors must be a subset of card colors.
  including,

  /// Card color identity must be legal in a deck with commander of selected colors.
  commander,
}

/// Target card attribute for color filtering.
enum ColorTarget {
  /// Filter against card casting colors (dynamicData['colors']).
  cardColor,

  /// Filter against card Commander color identity (dynamicData['color_identity']).
  colorIdentity,
}

/// Filter criteria on a numeric or variable card stat (power, toughness, loyalty, defense).
class MtgStatFilter {
  /// Target stat attribute name: 'power', 'toughness', 'loyalty', or 'defense'.
  final String stat;

  /// Comparison operator: '=', '>', '<', '>=', '<=', '!='.
  final String operator;

  /// Target value to compare against (e.g. '3', '2.5', '*').
  final String value;

  const MtgStatFilter({
    required this.stat,
    String? operator,
    String? op,
    required this.value,
  }) : operator = operator ?? op ?? '=';

  /// Alias for [operator].
  String get op => operator;

  /// Evaluates whether the given decoded card dynamicData map matches this stat filter.
  /// Supports both single-faced attributes and multi-faced card attributes ('card_faces').
  bool matches(Map<String, dynamic> dyn) {
    if (_matchesSingleMap(dyn)) return true;

    // Defensively check card_faces for multi-faced cards (Transform, MDFC, Flip, Split, Adventure)
    if (dyn['card_faces'] is List) {
      for (final face in dyn['card_faces'] as List) {
        if (face is Map<String, dynamic> && _matchesSingleMap(face)) {
          return true;
        } else if (face is Map &&
            _matchesSingleMap(Map<String, dynamic>.from(face))) {
          return true;
        }
      }
    }
    return false;
  }

  bool _matchesSingleMap(Map<String, dynamic> data) {
    final rawStat = data[stat]?.toString().trim();
    if (rawStat == null) return false;

    // Special non-numeric or variable values (e.g. '*')
    if (value == '*' || rawStat == '*') {
      if (operator == '=' || operator == '==') return rawStat == value;
      if (operator == '!=') return rawStat != value;
      return false;
    }

    final targetVal = double.tryParse(value);
    final actualVal = double.tryParse(rawStat);
    if (targetVal == null || actualVal == null) {
      // String comparison fallback
      if (operator == '=' || operator == '==') return rawStat == value;
      if (operator == '!=') return rawStat != value;
      return false;
    }

    switch (operator) {
      case '>':
        return actualVal > targetVal;
      case '<':
        return actualVal < targetVal;
      case '>=':
        return actualVal >= targetVal;
      case '<=':
        return actualVal <= targetVal;
      case '!=':
        return actualVal != targetVal;
      case '=':
      case '==':
      default:
        return actualVal == targetVal;
    }
  }

  MtgStatFilter copyWith({
    String? stat,
    String? operator,
    String? op,
    String? value,
  }) {
    return MtgStatFilter(
      stat: stat ?? this.stat,
      operator: operator ?? op ?? this.operator,
      value: value ?? this.value,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MtgStatFilter &&
          runtimeType == other.runtimeType &&
          stat == other.stat &&
          (operator == other.operator || operator == other.op) &&
          value == other.value;

  @override
  int get hashCode => stat.hashCode ^ operator.hashCode ^ value.hashCode;

  @override
  String toString() => '$stat $operator $value';
}

/// Comprehensive filter state for Magic: The Gathering catalog & vault items.
class MtgFilterState {
  // Colors & Identity
  final ColorMatchMode colorMatchMode;
  final ColorTarget colorTarget;
  final Set<String> colors; // 'W', 'U', 'B', 'R', 'G', 'C'
  final RangeValues colorCountRange; // 0 to 5

  // Types & Text
  final String typeLine;
  final List<String> oracleTextClauses;

  // Cost & CMC
  final String manaCost;
  final RangeValues cmcRange; // 0 to 16+

  // Sets & Rarity
  final String setCode;
  final String setOperator; // '=', '!='
  final Set<String> rarities; // 'common', 'uncommon', 'rare', 'mythic', 'special', 'bonus'

  // Stats
  final List<MtgStatFilter> statFilters;

  // Layouts
  final Set<String> layouts; // 'normal', 'split', 'flip', 'transform', 'modal_dfc', 'adventure', 'meld', 'leveler'

  // Treatments & Finishes
  final bool? isReserved;
  final bool? isUniversesBeyond;
  final bool? isPromo;
  final bool? isReprint;
  final bool? isAltered;
  final bool? isMisprint;
  final Set<String> finishes; // 'foil', 'nonfoil', 'etched'

  // Collection
  final Set<String> conditions; // 'Mint', 'NM', 'EX', 'Good', 'LP', 'Played', 'Poor'
  final Set<String> languages; // 'EN', 'ES', 'JP', 'FR', 'DE', 'IT', 'PT', 'RU'
  final bool? isGraded;
  final bool? isSigned;

  const MtgFilterState({
    this.colorMatchMode = ColorMatchMode.including,
    this.colorTarget = ColorTarget.cardColor,
    this.colors = const {},
    this.colorCountRange = const RangeValues(0, 5),
    this.cmcRange = const RangeValues(0, 16),
    this.typeLine = '',
    this.oracleTextClauses = const [],
    this.manaCost = '',
    this.setCode = '',
    this.setOperator = '=',
    this.rarities = const {},
    this.layouts = const {},
    this.finishes = const {},
    this.conditions = const {},
    this.languages = const {},
    List<MtgStatFilter>? statFilters,
    List<MtgStatFilter>? stats,
    this.isReserved,
    this.isUniversesBeyond,
    this.isPromo,
    this.isReprint,
    this.isAltered,
    this.isMisprint,
    this.isGraded,
    this.isSigned,
  }) : statFilters = statFilters ?? stats ?? const [];

  /// Alias for [statFilters].
  List<MtgStatFilter> get stats => statFilters;

  /// True if any filter criteria is active (diverges from initial blank state).
  bool get isActive => activeCount > 0;

  /// Returns total count of active filter dimensions.
  int get activeCount {
    int count = 0;
    if (colors.isNotEmpty) count++;
    if (colorCountRange.start > 0 || colorCountRange.end < 5) count++;
    if (cmcRange.start > 0 || cmcRange.end < 16) count++;
    if (typeLine.trim().isNotEmpty) count++;
    if (oracleTextClauses.isNotEmpty) {
      count += oracleTextClauses.where((c) => c.trim().isNotEmpty).length;
    }
    if (manaCost.trim().isNotEmpty) count++;
    if (setCode.trim().isNotEmpty) count++;
    if (rarities.isNotEmpty) count++;
    if (layouts.isNotEmpty) count++;
    if (finishes.isNotEmpty) count++;
    if (conditions.isNotEmpty) count++;
    if (languages.isNotEmpty) count++;
    if (statFilters.isNotEmpty) count += statFilters.length;
    if (isReserved != null) count++;
    if (isUniversesBeyond != null) count++;
    if (isPromo != null) count++;
    if (isReprint != null) count++;
    if (isAltered != null) count++;
    if (isMisprint != null) count++;
    if (isGraded != null) count++;
    if (isSigned != null) count++;
    return count;
  }

  /// Resets all filter fields back to default state.
  MtgFilterState reset() => const MtgFilterState();

  /// Creates a copy of this state with specified fields updated.
  /// Supports both raw boolean values (`isPromo: true`) and closures (`isPromo: () => true`).
  MtgFilterState copyWith({
    ColorMatchMode? colorMatchMode,
    ColorTarget? colorTarget,
    Set<String>? colors,
    RangeValues? colorCountRange,
    RangeValues? cmcRange,
    String? typeLine,
    List<String>? oracleTextClauses,
    String? manaCost,
    String? setCode,
    String? setOperator,
    Set<String>? rarities,
    Set<String>? layouts,
    Set<String>? finishes,
    Set<String>? conditions,
    Set<String>? languages,
    List<MtgStatFilter>? statFilters,
    List<MtgStatFilter>? stats,
    Object? isReserved = _sentinel,
    Object? isUniversesBeyond = _sentinel,
    Object? isPromo = _sentinel,
    Object? isReprint = _sentinel,
    Object? isAltered = _sentinel,
    Object? isMisprint = _sentinel,
    Object? isGraded = _sentinel,
    Object? isSigned = _sentinel,
  }) {
    return MtgFilterState(
      colorMatchMode: colorMatchMode ?? this.colorMatchMode,
      colorTarget: colorTarget ?? this.colorTarget,
      colors: colors ?? this.colors,
      colorCountRange: colorCountRange ?? this.colorCountRange,
      cmcRange: cmcRange ?? this.cmcRange,
      typeLine: typeLine ?? this.typeLine,
      oracleTextClauses: oracleTextClauses ?? this.oracleTextClauses,
      manaCost: manaCost ?? this.manaCost,
      setCode: setCode ?? this.setCode,
      setOperator: setOperator ?? this.setOperator,
      rarities: rarities ?? this.rarities,
      layouts: layouts ?? this.layouts,
      finishes: finishes ?? this.finishes,
      conditions: conditions ?? this.conditions,
      languages: languages ?? this.languages,
      statFilters: statFilters ?? stats ?? this.statFilters,
      isReserved: _resolveBoolProp(isReserved, this.isReserved),
      isUniversesBeyond:
          _resolveBoolProp(isUniversesBeyond, this.isUniversesBeyond),
      isPromo: _resolveBoolProp(isPromo, this.isPromo),
      isReprint: _resolveBoolProp(isReprint, this.isReprint),
      isAltered: _resolveBoolProp(isAltered, this.isAltered),
      isMisprint: _resolveBoolProp(isMisprint, this.isMisprint),
      isGraded: _resolveBoolProp(isGraded, this.isGraded),
      isSigned: _resolveBoolProp(isSigned, this.isSigned),
    );
  }

  /// Determines whether a [VaultItem] matches this filter state.
  bool matches(VaultItem item) {
    Map<String, dynamic> dyn = {};
    if (item.dynamicData.isNotEmpty) {
      try {
        dyn = jsonDecode(item.dynamicData) as Map<String, dynamic>;
      } catch (_) {}
    }

    // 1. Universes Beyond filter
    if (isUniversesBeyond != null) {
      final isUb = _resolveIsUniversesBeyond(item, dyn);
      if (isUb != isUniversesBeyond) return false;
    }

    // 2. Set Code filter
    if (setCode.trim().isNotEmpty) {
      final cardSet = (dyn['set']?.toString() ??
              dyn['set_code']?.toString() ??
              item.setOrSeries)
          .toLowerCase();
      final targetSet = setCode.trim().toLowerCase();
      final matchesSet = cardSet == targetSet;
      if (setOperator == '=' && !matchesSet) return false;
      if (setOperator == '!=' && matchesSet) return false;
    }

    // 3. Layouts filter
    if (layouts.isNotEmpty) {
      final cardLayout = (dyn['layout']?.toString() ?? 'normal').toLowerCase();
      if (!layouts.map((l) => l.toLowerCase()).contains(cardLayout)) {
        return false;
      }
    }

    // 4. Rarities filter
    if (rarities.isNotEmpty) {
      final cardRarity = (dyn['rarity']?.toString() ?? '').toLowerCase();
      if (!rarities.map((r) => r.toLowerCase()).contains(cardRarity)) {
        return false;
      }
    }

    // 5. Finishes filter
    if (finishes.isNotEmpty) {
      final rawFinishes = dyn['finishes'];
      Set<String> cardFinishes = {};
      if (rawFinishes is List) {
        cardFinishes =
            rawFinishes.map((f) => f.toString().toLowerCase()).toSet();
      } else if (rawFinishes is String) {
        cardFinishes = {rawFinishes.toLowerCase()};
      }
      final targetFinishes = finishes.map((f) => f.toLowerCase()).toSet();
      if (!cardFinishes.any(targetFinishes.contains)) {
        return false;
      }
    }

    // 6. Conditions filter (with bidirectional alias normalization)
    if (conditions.isNotEmpty) {
      final rawItemCondition = item.condition.toUpperCase().trim();
      final normItemCondition =
          _conditionMap[rawItemCondition] ?? rawItemCondition;
      final matchesCond = conditions.any((c) {
        final rawTarget = c.toUpperCase().trim();
        final normTarget = _conditionMap[rawTarget] ?? rawTarget;
        return rawTarget == rawItemCondition ||
            normTarget == normItemCondition ||
            rawTarget == normItemCondition ||
            normTarget == rawItemCondition;
      });
      if (!matchesCond) return false;
    }

    // 7. Languages filter (with code and name normalization)
    if (languages.isNotEmpty) {
      final cardLang = (dyn['lang']?.toString() ??
              dyn['language']?.toString() ??
              'en')
          .toUpperCase()
          .trim();
      final normCardLang = _langMap[cardLang] ?? cardLang;
      final matchesLang = languages.any((l) {
        final rawTarget = l.toUpperCase().trim();
        final normTarget = _langMap[rawTarget] ?? rawTarget;
        return rawTarget == cardLang ||
            normTarget == normCardLang ||
            rawTarget == normCardLang ||
            normTarget == cardLang;
      });
      if (!matchesLang) return false;
    }

    // 8. Type line filter (evaluates root and card_faces)
    if (typeLine.trim().isNotEmpty) {
      final allTypeLines = StringBuffer();
      if (dyn['type_line'] != null) {
        allTypeLines.writeln(dyn['type_line'].toString());
      }
      if (dyn['card_faces'] is List) {
        for (final face in dyn['card_faces'] as List) {
          if (face is Map && face['type_line'] != null) {
            allTypeLines.writeln(face['type_line'].toString());
          }
        }
      }
      final combinedTypeLine = allTypeLines.toString().toLowerCase();
      final searchParts =
          typeLine.toLowerCase().trim().split(RegExp(r'\s+'));
      for (final part in searchParts) {
        if (!combinedTypeLine.contains(part)) return false;
      }
    }

    // 9. Oracle text clauses filter (evaluates root and card_faces)
    if (oracleTextClauses.isNotEmpty) {
      final allOracle = StringBuffer();
      if (dyn['oracle_text'] != null) {
        allOracle.writeln(dyn['oracle_text'].toString());
      }
      if (dyn['card_faces'] is List) {
        for (final face in dyn['card_faces'] as List) {
          if (face is Map && face['oracle_text'] != null) {
            allOracle.writeln(face['oracle_text'].toString());
          }
        }
      }
      final combinedOracle = allOracle.toString().toLowerCase();
      for (final clause in oracleTextClauses) {
        final clean = clause.trim().toLowerCase();
        if (clean.isNotEmpty && !combinedOracle.contains(clean)) {
          return false;
        }
      }
    }

    // 10. Mana cost filter (evaluates root and card_faces)
    if (manaCost.trim().isNotEmpty) {
      final allCosts = StringBuffer();
      if (dyn['mana_cost'] != null) {
        allCosts.write(dyn['mana_cost'].toString().replaceAll(' ', ''));
      }
      if (dyn['card_faces'] is List) {
        for (final face in dyn['card_faces'] as List) {
          if (face is Map && face['mana_cost'] != null) {
            allCosts.write(face['mana_cost'].toString().replaceAll(' ', ''));
          }
        }
      }
      final combinedCosts = allCosts.toString();
      final targetCost = manaCost.replaceAll(' ', '');
      if (!combinedCosts.contains(targetCost)) return false;
    }

    // 11. CMC (Mana Value) range filter
    final cmcVal = double.tryParse(dyn['cmc']?.toString() ?? '') ??
        _inferCmcFromManaCost(dyn, item);
    if (cmcVal < cmcRange.start || cmcVal > cmcRange.end) {
      return false;
    }

    // 12. Colors / Color Identity & Color Count filter
    final cardColors = _resolveCardColors(dyn, colorTarget);
    final cardColorCount = _resolveColorCount(cardColors);

    if (colorCountRange.start > 0 || colorCountRange.end < 5) {
      if (cardColorCount < colorCountRange.start ||
          cardColorCount > colorCountRange.end) {
        return false;
      }
    }

    if (colors.isNotEmpty) {
      final isCardColorless = cardColors.isEmpty ||
          (cardColors.length == 1 && cardColors.contains('C'));
      final filterOnlyC = colors.length == 1 && colors.contains('C');

      switch (colorMatchMode) {
        case ColorMatchMode.exactly:
          if (filterOnlyC) {
            if (!isCardColorless) return false;
          } else {
            if (isCardColorless) return false;
            final effectiveCard =
                cardColors.where((c) => c != 'C').toSet();
            final effectiveFilter =
                colors.where((c) => c != 'C').toSet();
            if (!setEquals(effectiveCard, effectiveFilter)) return false;
          }
          break;

        case ColorMatchMode.atMost:
          if (filterOnlyC) {
            if (!isCardColorless) return false;
          } else {
            if (!isCardColorless) {
              final effectiveCard =
                  cardColors.where((c) => c != 'C').toSet();
              final effectiveFilter =
                  colors.where((c) => c != 'C').toSet();
              if (!effectiveFilter.containsAll(effectiveCard)) return false;
            }
          }
          break;

        case ColorMatchMode.including:
          if (filterOnlyC) {
            if (!isCardColorless) return false;
          } else {
            if (isCardColorless) return false;
            final effectiveCard =
                cardColors.where((c) => c != 'C').toSet();
            final effectiveFilter =
                colors.where((c) => c != 'C').toSet();
            if (!effectiveCard.containsAll(effectiveFilter)) return false;
          }
          break;

        case ColorMatchMode.commander:
          if (filterOnlyC) {
            if (!isCardColorless) return false;
          } else {
            // In Commander, colorless cards are legal in any colored commander deck.
            // Colored cards must have an identity that is a subset of the commander's identity.
            if (!isCardColorless) {
              final effectiveCard =
                  cardColors.where((c) => c != 'C').toSet();
              final effectiveCommander =
                  colors.where((c) => c != 'C').toSet();
              if (!effectiveCommander.containsAll(effectiveCard)) return false;
            }
          }
          break;
      }
    }

    // 13. Stat filters (Power, Toughness, Loyalty, Defense)
    for (final sf in statFilters) {
      if (!sf.matches(dyn)) return false;
    }

    // 14. Boolean flags
    if (isReserved != null) {
      final reserved = dyn['reserved'] == true;
      if (reserved != isReserved) return false;
    }
    if (isPromo != null) {
      final promo = dyn['promo'] == true ||
          (dyn['promo_types'] is List &&
              (dyn['promo_types'] as List).isNotEmpty);
      if (promo != isPromo) return false;
    }
    if (isReprint != null) {
      final reprint = dyn['reprint'] == true;
      if (reprint != isReprint) return false;
    }
    if (isAltered != null && item.isAltered != isAltered) return false;
    if (isMisprint != null && item.isMisprint != isMisprint) return false;
    if (isGraded != null && item.isGraded != isGraded) return false;
    if (isSigned != null && item.isSigned != isSigned) return false;

    return true;
  }

  // --- Static Helper Evaluation Methods ---

  static bool _resolveIsUniversesBeyond(
      VaultItem item, Map<String, dynamic> dyn) {
    if (dyn['is_universes_beyond'] == true) return true;

    final promoTypes = dyn['promo_types'];
    if (promoTypes is List &&
        promoTypes.any((p) {
          final s = p?.toString().toLowerCase() ?? '';
          return s == 'universes_beyond' || s == 'universesbeyond';
        })) {
      return true;
    }

    final frameEffects = dyn['frame_effects'];
    if (frameEffects is List &&
        frameEffects.any((f) {
          final s = f?.toString().toLowerCase() ?? '';
          return s == 'universesbeyond' || s == 'universes_beyond';
        })) {
      return true;
    }

    final securityStamp = dyn['security_stamp']?.toString().toLowerCase();
    if (securityStamp == 'triangle') return true;

    // Check card faces defensively
    if (dyn['card_faces'] is List) {
      for (final face in dyn['card_faces'] as List) {
        if (face is Map) {
          final fPromo = face['promo_types'];
          if (fPromo is List &&
              fPromo.any((p) {
                final s = p?.toString().toLowerCase() ?? '';
                return s == 'universes_beyond' || s == 'universesbeyond';
              })) {
            return true;
          }
          final fEffects = face['frame_effects'];
          if (fEffects is List &&
              fEffects.any((f) {
                final s = f?.toString().toLowerCase() ?? '';
                return s == 'universesbeyond' || s == 'universes_beyond';
              })) {
            return true;
          }
          if (face['security_stamp']?.toString().toLowerCase() == 'triangle') {
            return true;
          }
        }
      }
    }

    return false;
  }

  static Set<String> _resolveCardColors(
      Map<String, dynamic> dyn, ColorTarget target) {
    List<dynamic>? colorList;
    if (target == ColorTarget.colorIdentity) {
      colorList = dyn['color_identity'] as List<dynamic>?;
    } else {
      colorList = dyn['colors'] as List<dynamic>?;
    }

    if (colorList != null && colorList.isNotEmpty) {
      return colorList.map((c) => c.toString().toUpperCase()).toSet();
    }

    // Check card_faces if root colors was empty
    if (dyn['card_faces'] is List) {
      final faceColors = <String>{};
      for (final face in dyn['card_faces'] as List) {
        if (face is Map) {
          final list = (target == ColorTarget.colorIdentity
                  ? face['color_identity']
                  : face['colors']) as List<dynamic>?;
          if (list != null) {
            for (final c in list) {
              faceColors.add(c.toString().toUpperCase());
            }
          }
        }
      }
      if (faceColors.isNotEmpty) return faceColors;
    }

    // Fallback: derive from mana_cost symbols
    final costBuf = StringBuffer();
    if (dyn['mana_cost'] != null) {
      costBuf.write(dyn['mana_cost'].toString());
    }
    if (dyn['card_faces'] is List) {
      for (final face in dyn['card_faces'] as List) {
        if (face is Map && face['mana_cost'] != null) {
          costBuf.write(face['mana_cost'].toString());
        }
      }
    }
    final cost = costBuf.toString();
    final derived = <String>{};
    if (cost.contains('W')) derived.add('W');
    if (cost.contains('U')) derived.add('U');
    if (cost.contains('B')) derived.add('B');
    if (cost.contains('R')) derived.add('R');
    if (cost.contains('G')) derived.add('G');
    if (derived.isEmpty) derived.add('C');
    return derived;
  }

  static int _resolveColorCount(Set<String> cardColors) {
    if (cardColors.isEmpty ||
        (cardColors.length == 1 && cardColors.contains('C'))) {
      return 0;
    }
    return cardColors.where((c) => c != 'C').length;
  }

  static double _inferCmcFromManaCost(
      Map<String, dynamic> dyn, VaultItem item) {
    String cost = dyn['mana_cost']?.toString() ?? '';
    if (cost.isEmpty &&
        dyn['card_faces'] is List &&
        (dyn['card_faces'] as List).isNotEmpty) {
      final face0 = (dyn['card_faces'] as List)[0];
      if (face0 is Map && face0['mana_cost'] != null) {
        cost = face0['mana_cost'].toString();
      }
    }
    if (cost.isEmpty) return 0.0;
    double cmc = 0.0;
    final matches = RegExp(r'\{([^}]+)\}').allMatches(cost);
    for (final m in matches) {
      final val = m.group(1) ?? '';
      final numVal = double.tryParse(val);
      if (numVal != null) {
        cmc += numVal;
      } else if (val != 'X' && val != 'Y' && val != 'Z') {
        cmc += 1.0;
      }
    }
    return cmc;
  }

  static bool setEquals<T>(Set<T>? a, Set<T>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    return a.containsAll(b);
  }

  static bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static const Map<String, String> _conditionMap = {
    'MINT': 'MINT',
    'M': 'MINT',
    'NEAR MINT': 'NM',
    'NEAR_MINT': 'NM',
    'NM': 'NM',
    'EXCELLENT': 'EX',
    'EX': 'EX',
    'LIGHT PLAYED': 'LP',
    'LIGHTLY PLAYED': 'LP',
    'LIGHT_PLAYED': 'LP',
    'LP': 'LP',
    'GOOD': 'GD',
    'GD': 'GD',
    'PLAYED': 'PL',
    'PL': 'PL',
    'POOR': 'PO',
    'PO': 'PO',
    'DAMAGED': 'PO',
  };

  static const Map<String, String> _langMap = {
    'EN': 'EN',
    'ENGLISH': 'EN',
    'ES': 'ES',
    'SPANISH': 'ES',
    'JP': 'JA',
    'JA': 'JA',
    'JAPANESE': 'JA',
    'FR': 'FR',
    'FRENCH': 'FR',
    'DE': 'DE',
    'GERMAN': 'DE',
    'IT': 'IT',
    'ITALIAN': 'IT',
    'PT': 'PT',
    'PORTUGUESE': 'PT',
    'RU': 'RU',
    'RUSSIAN': 'RU',
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MtgFilterState &&
          runtimeType == other.runtimeType &&
          colorMatchMode == other.colorMatchMode &&
          colorTarget == other.colorTarget &&
          setEquals(colors, other.colors) &&
          colorCountRange == other.colorCountRange &&
          cmcRange == other.cmcRange &&
          typeLine == other.typeLine &&
          _listEquals(oracleTextClauses, other.oracleTextClauses) &&
          manaCost == other.manaCost &&
          setCode == other.setCode &&
          setOperator == other.setOperator &&
          setEquals(rarities, other.rarities) &&
          setEquals(layouts, other.layouts) &&
          setEquals(finishes, other.finishes) &&
          setEquals(conditions, other.conditions) &&
          setEquals(languages, other.languages) &&
          _listEquals(statFilters, other.statFilters) &&
          isReserved == other.isReserved &&
          isUniversesBeyond == other.isUniversesBeyond &&
          isPromo == other.isPromo &&
          isReprint == other.isReprint &&
          isAltered == other.isAltered &&
          isMisprint == other.isMisprint &&
          isGraded == other.isGraded &&
          isSigned == other.isSigned;

  @override
  int get hashCode => Object.hashAll([
        colorMatchMode,
        colorTarget,
        Object.hashAll(colors),
        colorCountRange,
        cmcRange,
        typeLine,
        Object.hashAll(oracleTextClauses),
        manaCost,
        setCode,
        setOperator,
        Object.hashAll(rarities),
        Object.hashAll(layouts),
        Object.hashAll(finishes),
        Object.hashAll(conditions),
        Object.hashAll(languages),
        Object.hashAll(statFilters),
        isReserved,
        isUniversesBeyond,
        isPromo,
        isReprint,
        isAltered,
        isMisprint,
        isGraded,
        isSigned,
      ]);
}

/// Sentinel object to distinguish omitted arguments from explicit nulls in copyWith.
const Object _sentinel = Object();

bool? _resolveBoolProp(Object? input, bool? current) {
  if (identical(input, _sentinel)) {
    return current;
  }
  if (input is bool? Function()) {
    return input();
  }
  if (input is bool) {
    return input;
  }
  if (input == null) {
    return null;
  }
  return current;
}

/// Riverpod StateNotifier managing [MtgFilterState].
class MtgFilterNotifier extends StateNotifier<MtgFilterState> {
  MtgFilterNotifier([MtgFilterState? initial])
      : super(initial ?? const MtgFilterState());

  /// Overwrites the full filter state.
  void setFilter(MtgFilterState newState) => state = newState;

  /// Resets all filter criteria back to empty/default.
  void reset() => state = const MtgFilterState();

  /// Toggles a mana color symbol ('W', 'U', 'B', 'R', 'G', 'C').
  void toggleColor(String color) {
    final newColors = Set<String>.from(state.colors);
    if (newColors.contains(color)) {
      newColors.remove(color);
    } else {
      newColors.add(color);
    }
    state = state.copyWith(colors: newColors);
  }

  /// Sets the color match mode.
  void setColorMatchMode(ColorMatchMode mode) {
    state = state.copyWith(colorMatchMode: mode);
  }

  /// Sets the color target (card color vs commander color identity).
  void setColorTarget(ColorTarget target) {
    state = state.copyWith(colorTarget: target);
  }

  /// Updates CMC (Mana Value) range.
  void setCmcRange(RangeValues range) {
    state = state.copyWith(cmcRange: range);
  }

  /// Updates Color Count range slider (0 to 5).
  void setColorCountRange(RangeValues range) {
    state = state.copyWith(colorCountRange: range);
  }

  /// Updates the type line search string.
  void setTypeLine(String typeLine) {
    state = state.copyWith(typeLine: typeLine);
  }

  /// Adds an oracle text clause.
  void addOracleTextClause(String clause) {
    if (clause.trim().isEmpty) return;
    state = state.copyWith(
      oracleTextClauses: [...state.oracleTextClauses, clause.trim()],
    );
  }

  /// Removes an oracle text clause by index.
  void removeOracleTextClause(int index) {
    if (index < 0 || index >= state.oracleTextClauses.length) return;
    final updated = List<String>.from(state.oracleTextClauses)..removeAt(index);
    state = state.copyWith(oracleTextClauses: updated);
  }

  /// Updates the exact mana cost filter string.
  void setManaCost(String cost) {
    state = state.copyWith(manaCost: cost);
  }

  /// Updates the set code and operator ('=' or '!=').
  void setSetCode(String setCode, {String operator = '='}) {
    state = state.copyWith(setCode: setCode, setOperator: operator);
  }

  /// Toggles a rarity pill selection.
  void toggleRarity(String rarity) {
    final updated = Set<String>.from(state.rarities);
    if (updated.contains(rarity)) {
      updated.remove(rarity);
    } else {
      updated.add(rarity);
    }
    state = state.copyWith(rarities: updated);
  }

  /// Toggles a layout pill selection.
  void toggleLayout(String layout) {
    final updated = Set<String>.from(state.layouts);
    if (updated.contains(layout)) {
      updated.remove(layout);
    } else {
      updated.add(layout);
    }
    state = state.copyWith(layouts: updated);
  }

  /// Toggles a finish pill selection ('foil', 'nonfoil', 'etched').
  void toggleFinish(String finish) {
    final updated = Set<String>.from(state.finishes);
    if (updated.contains(finish)) {
      updated.remove(finish);
    } else {
      updated.add(finish);
    }
    state = state.copyWith(finishes: updated);
  }

  /// Toggles a condition pill selection.
  void toggleCondition(String condition) {
    final updated = Set<String>.from(state.conditions);
    if (updated.contains(condition)) {
      updated.remove(condition);
    } else {
      updated.add(condition);
    }
    state = state.copyWith(conditions: updated);
  }

  /// Toggles a language pill selection.
  void toggleLanguage(String language) {
    final updated = Set<String>.from(state.languages);
    if (updated.contains(language)) {
      updated.remove(language);
    } else {
      updated.add(language);
    }
    state = state.copyWith(languages: updated);
  }

  /// Adds a stat filter.
  void addStatFilter(MtgStatFilter filter) {
    state = state.copyWith(statFilters: [...state.statFilters, filter]);
  }

  /// Removes a stat filter by index.
  void removeStatFilter(int index) {
    if (index < 0 || index >= state.statFilters.length) return;
    final updated = List<MtgStatFilter>.from(state.statFilters)..removeAt(index);
    state = state.copyWith(statFilters: updated);
  }

  /// Sets Universes Beyond boolean flag.
  void setUniversesBeyond(bool? value) {
    state = state.copyWith(isUniversesBeyond: () => value);
  }

  /// Sets Reserved List boolean flag.
  void setReserved(bool? value) {
    state = state.copyWith(isReserved: () => value);
  }

  /// Sets Promo boolean flag.
  void setPromo(bool? value) {
    state = state.copyWith(isPromo: () => value);
  }

  /// Sets Reprint boolean flag.
  void setReprint(bool? value) {
    state = state.copyWith(isReprint: () => value);
  }

  /// Sets Altered card flag.
  void setAltered(bool? value) {
    state = state.copyWith(isAltered: () => value);
  }

  /// Sets Misprint card flag.
  void setMisprint(bool? value) {
    state = state.copyWith(isMisprint: () => value);
  }

  /// Sets Graded card flag.
  void setGraded(bool? value) {
    state = state.copyWith(isGraded: () => value);
  }

  /// Sets Signed card flag.
  void setSigned(bool? value) {
    state = state.copyWith(isSigned: () => value);
  }

  /// Functional update helper.
  void update(MtgFilterState Function(MtgFilterState current) updater) {
    state = updater(state);
  }
}

/// Global Riverpod StateNotifierProvider for [MtgFilterState].
final mtgFilterProvider =
    StateNotifierProvider<MtgFilterNotifier, MtgFilterState>((ref) {
  return MtgFilterNotifier();
});

/// Convenience selector provider indicating if any MTG filter is active.
final isMtgFilterActiveProvider = Provider<bool>((ref) {
  return ref.watch(mtgFilterProvider.select((s) => s.isActive));
});

/// Convenience selector provider for the active filter count.
final mtgFilterActiveCountProvider = Provider<int>((ref) {
  return ref.watch(mtgFilterProvider.select((s) => s.activeCount));
});
