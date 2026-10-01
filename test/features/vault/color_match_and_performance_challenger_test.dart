import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/presentation/providers/mtg_filter_state.dart';

VaultItem createItem({
  required String id,
  required String name,
  String collectionType = 'mtg',
  String setOrSeries = 'Core Set',
  String condition = 'NM',
  Map<String, dynamic>? dynamicData,
  String? rawDynamicData,
}) {
  return VaultItem(
    id: id,
    collectionType: collectionType,
    name: name,
    flavorName: null,
    setOrSeries: setOrSeries,
    imageUrl: 'https://cards.scryfall.io/large/front/$id.jpg',
    acquiredPrice: 1.0,
    acquiredDate: DateTime(2026, 9, 28),
    quantity: 1,
    condition: condition,
    isGraded: false,
    isAltered: false,
    isMisprint: false,
    isSigned: false,
    isDeleted: false,
    personalNotes: null,
    primaryBinderId: null,
    currentMarketPrice: 2.0,
    lastPriceUpdate: DateTime(2026, 9, 28),
    dynamicData: rawDynamicData ?? jsonEncode(dynamicData ?? {}),
  );
}

void main() {
  group('Empirical Challenger 1: Colorless "C" Alone vs Colored Cards', () {
    final solRing = createItem(
      id: 'sol-ring',
      name: 'Sol Ring',
      dynamicData: {
        'mana_cost': '{1}',
        'colors': [],
        'color_identity': [],
        'type_line': 'Artifact',
        'oracle_text': '{T}: Add {C}{C}.',
        'cmc': 1.0,
      },
    );

    final wastes = createItem(
      id: 'wastes',
      name: 'Wastes',
      dynamicData: {
        'mana_cost': '',
        'colors': [],
        'color_identity': [],
        'type_line': 'Basic Land — Wastes',
        'oracle_text': '{T}: Add {C}.',
        'cmc': 0.0,
      },
    );

    final spellbook = createItem(
      id: 'spellbook',
      name: 'Spellbook',
      dynamicData: {
        'mana_cost': '{0}',
        'colors': [],
        'color_identity': [],
        'type_line': 'Artifact',
        'oracle_text': 'You have no maximum hand size.',
        'cmc': 0.0,
      },
    );

    final kozilek = createItem(
      id: 'kozilek-distortion',
      name: 'Kozilek, the Great Distortion',
      dynamicData: {
        'mana_cost': '{8}{C}{C}',
        'colors': [],
        'color_identity': [],
        'type_line': 'Legendary Creature — Eldrazi',
        'oracle_text': 'When you cast this spell, if you have fewer than seven cards in hand, draw cards equal to the difference.\nMenace',
        'cmc': 10.0,
      },
    );

    final opt = createItem(
      id: 'opt',
      name: 'Opt',
      dynamicData: {
        'mana_cost': '{U}',
        'colors': ['U'],
        'color_identity': ['U'],
        'type_line': 'Instant',
        'cmc': 1.0,
      },
    );

    final savannahLions = createItem(
      id: 'savannah-lions',
      name: 'Savannah Lions',
      dynamicData: {
        'mana_cost': '{W}',
        'colors': ['W'],
        'color_identity': ['W'],
        'type_line': 'Creature — Cat',
        'cmc': 1.0,
      },
    );

    final dovinBaan = createItem(
      id: 'dovin-baan',
      name: 'Dovin Baan',
      dynamicData: {
        'mana_cost': '{1}{W}{U}',
        'colors': ['W', 'U'],
        'color_identity': ['W', 'U'],
        'type_line': 'Legendary Planeswalker — Dovin',
        'cmc': 3.0,
      },
    );

    final plains = createItem(
      id: 'plains',
      name: 'Plains',
      dynamicData: {
        'mana_cost': '',
        'colors': [],
        'color_identity': ['W'],
        'type_line': 'Basic Land — Plains',
        'oracle_text': '({T}: Add {W}.)',
        'cmc': 0.0,
      },
    );

    test('Filter with colors: {C} alone in exactly mode matches all colorless cards and rejects colored cards', () {
      const filterExactC = MtgFilterState(
        colors: {'C'},
        colorMatchMode: ColorMatchMode.exactly,
      );

      // Colorless cards must match
      expect(filterExactC.matches(solRing), isTrue, reason: 'Sol Ring is colorless');
      expect(filterExactC.matches(wastes), isTrue, reason: 'Wastes is colorless land');
      expect(filterExactC.matches(spellbook), isTrue, reason: 'Spellbook {0} is colorless');
      expect(filterExactC.matches(kozilek), isTrue, reason: 'Kozilek is colorless Eldrazi');

      // Colored cards must be rejected
      expect(filterExactC.matches(opt), isFalse, reason: 'Opt is blue');
      expect(filterExactC.matches(savannahLions), isFalse, reason: 'Lions is white');
      expect(filterExactC.matches(dovinBaan), isFalse, reason: 'Dovin is white/blue');
    });

    test('Plains behavior: colorless in cardColor, but mono-white in colorIdentity', () {
      const filterExactCCardColor = MtgFilterState(
        colors: {'C'},
        colorTarget: ColorTarget.cardColor,
        colorMatchMode: ColorMatchMode.exactly,
      );
      // Lands have no casting cost and no colors list -> card color is colorless
      expect(filterExactCCardColor.matches(plains), isTrue);

      const filterExactCColorIdentity = MtgFilterState(
        colors: {'C'},
        colorTarget: ColorTarget.colorIdentity,
        colorMatchMode: ColorMatchMode.exactly,
      );
      // Under colorIdentity, Plains has 'W' identity -> must NOT match {C}
      expect(filterExactCColorIdentity.matches(plains), isFalse);

      const filterWhiteColorIdentity = MtgFilterState(
        colors: {'W'},
        colorTarget: ColorTarget.colorIdentity,
        colorMatchMode: ColorMatchMode.exactly,
      );
      expect(filterWhiteColorIdentity.matches(plains), isTrue);
    });
  });

  group('Empirical Challenger 1: Colorless "C" Combined with Colors ("C" + "U" and "C" + "R")', () {
    final deepfathomSkulker = createItem(
      id: 'deepfathom-skulker',
      name: 'Deepfathom Skulker',
      dynamicData: {
        'mana_cost': '{5}{U}',
        'colors': ['U'],
        'color_identity': ['U'],
        'type_line': 'Creature — Eldrazi Drone',
        'oracle_text': 'Devoid\nWhenever a creature you control deals combat damage to a player, you may draw a card.\n{1}{C}: Target creature can\'t be blocked this turn.',
        'cmc': 6.0,
      },
    );

    final eldraziObligator = createItem(
      id: 'eldrazi-obligator',
      name: 'Eldrazi Obligator',
      dynamicData: {
        'mana_cost': '{2}{R}',
        'colors': ['R'],
        'color_identity': ['R'],
        'type_line': 'Creature — Eldrazi',
        'oracle_text': 'When you cast this spell, you may pay {1}{C}. If you do, gain control of target creature until end of turn, untap that creature, and it gains haste until end of turn.\nHaste',
        'cmc': 3.0,
      },
    );

    final opt = createItem(
      id: 'opt',
      name: 'Opt',
      dynamicData: {
        'mana_cost': '{U}',
        'colors': ['U'],
        'color_identity': ['U'],
        'type_line': 'Instant',
        'cmc': 1.0,
      },
    );

    final lightningBolt = createItem(
      id: 'lightning-bolt',
      name: 'Lightning Bolt',
      dynamicData: {
        'mana_cost': '{R}',
        'colors': ['R'],
        'color_identity': ['R'],
        'type_line': 'Instant',
        'cmc': 1.0,
      },
    );

    final solRing = createItem(
      id: 'sol-ring',
      name: 'Sol Ring',
      dynamicData: {
        'mana_cost': '{1}',
        'colors': [],
        'color_identity': [],
        'type_line': 'Artifact',
        'oracle_text': '{T}: Add {C}{C}.',
        'cmc': 1.0,
      },
    );

    final izzetCharm = createItem(
      id: 'izzet-charm',
      name: 'Izzet Charm',
      dynamicData: {
        'mana_cost': '{U}{R}',
        'colors': ['U', 'R'],
        'color_identity': ['U', 'R'],
        'type_line': 'Instant',
        'cmc': 2.0,
      },
    );

    test('ColorMatchMode.exactly with {C, U} under colorIdentity requires both C and U', () {
      const filterExactCU = MtgFilterState(
        colors: {'C', 'U'},
        colorTarget: ColorTarget.colorIdentity,
        colorMatchMode: ColorMatchMode.exactly,
      );

      // Deepfathom Skulker has U in colors and {C} in oracle text -> identity has {U, C}
      expect(filterExactCU.matches(deepfathomSkulker), isTrue);

      // Opt has only U, missing C
      expect(filterExactCU.matches(opt), isFalse);

      // Sol Ring has only C, missing U
      expect(filterExactCU.matches(solRing), isFalse);

      // Eldrazi Obligator has {C, R}, wrong color R != U
      expect(filterExactCU.matches(eldraziObligator), isFalse);

      // Izzet Charm has {U, R}, missing C and extra R
      expect(filterExactCU.matches(izzetCharm), isFalse);
    });

    test('ColorMatchMode.atMost (subset) with {C, U} under colorIdentity', () {
      const filterAtMostCU = MtgFilterState(
        colors: {'C', 'U'},
        colorTarget: ColorTarget.colorIdentity,
        colorMatchMode: ColorMatchMode.atMost,
      );

      // Allowed subsets of {C, U}: {C}, {U}, {C, U}
      expect(filterAtMostCU.matches(deepfathomSkulker), isTrue, reason: '{C, U} is subset of {C, U}');
      expect(filterAtMostCU.matches(opt), isTrue, reason: '{U} is subset of {C, U}');
      expect(filterAtMostCU.matches(solRing), isTrue, reason: '{C} is subset of {C, U}');

      // Disallowed: contains R
      expect(filterAtMostCU.matches(eldraziObligator), isFalse, reason: 'Contains R');
      expect(filterAtMostCU.matches(lightningBolt), isFalse, reason: 'Contains R');
      expect(filterAtMostCU.matches(izzetCharm), isFalse, reason: 'Contains R');
    });

    test('ColorMatchMode.including (superset) with {C, U} under colorIdentity', () {
      const filterIncludingCU = MtgFilterState(
        colors: {'C', 'U'},
        colorTarget: ColorTarget.colorIdentity,
        colorMatchMode: ColorMatchMode.including,
      );

      // Must include both C and U
      expect(filterIncludingCU.matches(deepfathomSkulker), isTrue);

      // Opt lacks C
      expect(filterIncludingCU.matches(opt), isFalse);

      // Sol Ring lacks U
      expect(filterIncludingCU.matches(solRing), isFalse);

      // Obligator lacks U
      expect(filterIncludingCU.matches(eldraziObligator), isFalse);
    });

    test('ColorMatchMode.exactly with {C, R} under colorIdentity', () {
      const filterExactCR = MtgFilterState(
        colors: {'C', 'R'},
        colorTarget: ColorTarget.colorIdentity,
        colorMatchMode: ColorMatchMode.exactly,
      );

      expect(filterExactCR.matches(eldraziObligator), isTrue);
      expect(filterExactCR.matches(lightningBolt), isFalse);
      expect(filterExactCR.matches(solRing), isFalse);
      expect(filterExactCR.matches(deepfathomSkulker), isFalse);
    });

    test('ColorMatchMode.atMost with {C, R} under colorIdentity', () {
      const filterAtMostCR = MtgFilterState(
        colors: {'C', 'R'},
        colorTarget: ColorTarget.colorIdentity,
        colorMatchMode: ColorMatchMode.atMost,
      );

      // Subsets: {C}, {R}, {C, R}
      expect(filterAtMostCR.matches(eldraziObligator), isTrue);
      expect(filterAtMostCR.matches(lightningBolt), isTrue);
      expect(filterAtMostCR.matches(solRing), isTrue);
      expect(filterAtMostCR.matches(opt), isFalse);
      expect(filterAtMostCR.matches(deepfathomSkulker), isFalse);
    });
  });

  group('Empirical Challenger 1: True Colorless {C} Mana vs Generic Numbers & Lands', () {
    final wastes = createItem(
      id: 'wastes',
      name: 'Wastes',
      dynamicData: {
        'mana_cost': '',
        'type_line': 'Basic Land — Wastes',
        'oracle_text': '{T}: Add {C}.',
      },
    );

    final solRing = createItem(
      id: 'sol-ring',
      name: 'Sol Ring',
      dynamicData: {
        'mana_cost': '{1}',
        'type_line': 'Artifact',
        'oracle_text': '{T}: Add {C}{C}.',
      },
    );

    final spellbook = createItem(
      id: 'spellbook',
      name: 'Spellbook',
      dynamicData: {
        'mana_cost': '{0}',
        'type_line': 'Artifact',
        'oracle_text': 'You have no maximum hand size.',
      },
    );

    final kozilek = createItem(
      id: 'kozilek',
      name: 'Kozilek, the Great Distortion',
      dynamicData: {
        'mana_cost': '{8}{C}{C}',
        'type_line': 'Legendary Creature — Eldrazi',
        'oracle_text': 'Menace',
      },
    );

    final darksteelCitadel = createItem(
      id: 'darksteel-citadel',
      name: 'Darksteel Citadel',
      dynamicData: {
        'mana_cost': '',
        'type_line': 'Artifact Land',
        'oracle_text': 'Indestructible\n{T}: Add {C}.',
      },
    );

    test('Filtering by explicit mana_cost {C} differentiates true {C} pips from generic numbers', () {
      // Searching for cards that require {C} in their casting cost
      const filterManaC = MtgFilterState(manaCost: '{C}');

      expect(filterManaC.matches(kozilek), isTrue, reason: 'Kozilek costs {8}{C}{C}');
      expect(filterManaC.matches(solRing), isFalse, reason: 'Sol Ring costs generic {1}, not {C}');
      expect(filterManaC.matches(spellbook), isFalse, reason: 'Spellbook costs {0}');
      expect(filterManaC.matches(wastes), isFalse, reason: 'Wastes has no mana cost');
      expect(filterManaC.matches(darksteelCitadel), isFalse, reason: 'Citadel has no mana cost');
    });

    test('Filtering by oracle text {C} finds mana generators and cards producing/requiring {C}', () {
      const filterOracleC = MtgFilterState(oracleTextClauses: ['{C}']);

      expect(filterOracleC.matches(wastes), isTrue, reason: 'Wastes produces {C}');
      expect(filterOracleC.matches(solRing), isTrue, reason: 'Sol Ring produces {C}{C}');
      expect(filterOracleC.matches(darksteelCitadel), isTrue, reason: 'Darksteel Citadel produces {C}');
      expect(filterOracleC.matches(spellbook), isFalse, reason: 'Spellbook has no {C} in text');
      expect(filterOracleC.matches(kozilek), isFalse, reason: 'Kozilek text does not contain {C}');
    });

    test('Colorless lands with various abilities all evaluate as colorless', () {
      final reliquaryTower = createItem(
        id: 'reliquary-tower',
        name: 'Reliquary Tower',
        dynamicData: {
          'mana_cost': '',
          'type_line': 'Land',
          'oracle_text': 'You have no maximum hand size.\n{T}: Add {C}.',
          'colors': [],
          'color_identity': [],
        },
      );

      final darkDepths = createItem(
        id: 'dark-depths',
        name: 'Dark Depths',
        dynamicData: {
          'mana_cost': '',
          'type_line': 'Legendary Snow Land',
          'oracle_text': 'Dark Depths enters the battlefield with ten ice counters...',
          'colors': [],
          'color_identity': [],
        },
      );

      const filterExactC = MtgFilterState(colors: {'C'}, colorMatchMode: ColorMatchMode.exactly);

      expect(filterExactC.matches(wastes), isTrue);
      expect(filterExactC.matches(darksteelCitadel), isTrue);
      expect(filterExactC.matches(reliquaryTower), isTrue);
      expect(filterExactC.matches(darkDepths), isTrue);
    });
  });

  group('Empirical Challenger 1: Exact Match vs Subset Match (AtMost) Matrix', () {
    final whiteCard = createItem(
      id: 'w',
      name: 'White Card',
      dynamicData: {'colors': ['W'], 'color_identity': ['W'], 'mana_cost': '{W}'},
    );
    final blueCard = createItem(
      id: 'u',
      name: 'Blue Card',
      dynamicData: {'colors': ['U'], 'color_identity': ['U'], 'mana_cost': '{U}'},
    );
    final azoriusCard = createItem(
      id: 'wu',
      name: 'Azorius Card',
      dynamicData: {'colors': ['W', 'U'], 'color_identity': ['W', 'U'], 'mana_cost': '{W}{U}'},
    );
    final esperCard = createItem(
      id: 'wub',
      name: 'Esper Card',
      dynamicData: {'colors': ['W', 'U', 'B'], 'color_identity': ['W', 'U', 'B'], 'mana_cost': '{W}{U}{B}'},
    );
    final colorlessCard = createItem(
      id: 'c',
      name: 'Colorless Card',
      dynamicData: {'colors': [], 'color_identity': [], 'mana_cost': '{2}'},
    );

    test('Exact match requires identical color set; subset match permits any subset including empty', () {
      // 1. Exact Match {W, U}
      const exactWU = MtgFilterState(colors: {'W', 'U'}, colorMatchMode: ColorMatchMode.exactly);
      expect(exactWU.matches(azoriusCard), isTrue);
      expect(exactWU.matches(whiteCard), isFalse);
      expect(exactWU.matches(blueCard), isFalse);
      expect(exactWU.matches(esperCard), isFalse);
      expect(exactWU.matches(colorlessCard), isFalse);

      // 2. Subset Match (AtMost) {W, U}
      const atMostWU = MtgFilterState(colors: {'W', 'U'}, colorMatchMode: ColorMatchMode.atMost);
      expect(atMostWU.matches(azoriusCard), isTrue);
      expect(atMostWU.matches(whiteCard), isTrue);
      expect(atMostWU.matches(blueCard), isTrue);
      expect(atMostWU.matches(colorlessCard), isTrue);
      expect(atMostWU.matches(esperCard), isFalse);

      // 3. Exact Match {W}
      const exactW = MtgFilterState(colors: {'W'}, colorMatchMode: ColorMatchMode.exactly);
      expect(exactW.matches(whiteCard), isTrue);
      expect(exactW.matches(blueCard), isFalse);
      expect(exactW.matches(azoriusCard), isFalse);
      expect(exactW.matches(colorlessCard), isFalse);

      // 4. Subset Match (AtMost) {W}
      const atMostW = MtgFilterState(colors: {'W'}, colorMatchMode: ColorMatchMode.atMost);
      expect(atMostW.matches(whiteCard), isTrue);
      expect(atMostW.matches(colorlessCard), isTrue);
      expect(atMostW.matches(blueCard), isFalse);
      expect(atMostW.matches(azoriusCard), isFalse);
    });
  });

  group('Empirical Challenger 1: Performance Benchmark & UI Responsiveness', () {
    test('10,000 items evaluated through MtgFilterState in sub-second time without blocking', () {
      // Generate 10,000 realistic cards with diverse attributes
      final colorPillPalette = [
        ['W'],
        ['U'],
        ['B'],
        ['R'],
        ['G'],
        ['W', 'U'],
        ['U', 'B'],
        ['B', 'R'],
        ['R', 'G'],
        ['G', 'W'],
        ['W', 'U', 'B', 'R', 'G'],
        <String>[],
      ];

      final raritiesList = ['common', 'uncommon', 'rare', 'mythic', 'special'];

      final largeCardList = List.generate(10000, (i) {
        final colors = colorPillPalette[i % colorPillPalette.length];
        final rarity = raritiesList[i % raritiesList.length];
        return createItem(
          id: 'card-$i',
          name: 'Synthetic Card $i',
          dynamicData: {
            'colors': colors,
            'color_identity': colors,
            'rarity': rarity,
            'layout': i % 100 == 0 ? 'art_series' : 'normal',
            'cmc': (i % 10).toDouble(),
            'type_line': i % 2 == 0 ? 'Creature — Human' : 'Instant',
            'legalities': {
              'commander': i % 3 == 0 ? 'legal' : 'not_legal',
              'modern': i % 2 == 0 ? 'legal' : 'not_legal',
            },
            'finishes': i % 4 == 0 ? ['foil'] : ['nonfoil'],
          },
        );
      });

      // Benchmark 1: Color filter {C} alone
      const filterColorless = MtgFilterState(
        colors: {'C'},
        colorMatchMode: ColorMatchMode.exactly,
      );
      final sw1 = Stopwatch()..start();
      var countColorless = 0;
      for (final item in largeCardList) {
        if (filterColorless.matches(item)) countColorless++;
      }
      sw1.stop();

      // Benchmark 2: Complex multi-attribute filter
      final complexFilter = const MtgFilterState(
        colors: {'W', 'U'},
        colorMatchMode: ColorMatchMode.atMost,
        rarities: {'rare', 'mythic'},
        formats: {'modern'},
        finishes: {'foil'},
      );
      final sw2 = Stopwatch()..start();
      var countComplex = 0;
      for (final item in largeCardList) {
        if (complexFilter.matches(item)) countComplex++;
      }
      sw2.stop();

      // Output diagnostics
      debugPrint('[Benchmark] 10,000 cards colorless filter: ${sw1.elapsedMilliseconds}ms (matched: $countColorless)');
      debugPrint('[Benchmark] 10,000 cards complex multi-filter: ${sw2.elapsedMilliseconds}ms (matched: $countComplex)');

      // Sub-second verification (< 1000ms)
      expect(sw1.elapsedMilliseconds, lessThan(1000), reason: 'Colorless filter must run in sub-second time');
      expect(sw2.elapsedMilliseconds, lessThan(1000), reason: 'Complex filter must run in sub-second time');
    });
  });

  group('Empirical Challenger 1: Devoid Cards Behavior', () {
    final kozileksReturn = createItem(
      id: 'kozileks-return',
      name: "Kozilek's Return",
      dynamicData: {
        'mana_cost': '{2}{R}',
        'colors': [],
        'color_identity': ['R'],
        'type_line': 'Instant',
        'oracle_text': 'Devoid (This card has no color.)\nKozilek\'s Return deals 2 damage to each creature.',
      },
    );

    test('Devoid card color identity vs casting cost behavior', () {
      // Under color identity, it is Red
      const filterIdentityRed = MtgFilterState(
        colors: {'R'},
        colorTarget: ColorTarget.colorIdentity,
        colorMatchMode: ColorMatchMode.exactly,
      );
      expect(filterIdentityRed.matches(kozileksReturn), isTrue);

      const filterIdentityColorless = MtgFilterState(
        colors: {'C'},
        colorTarget: ColorTarget.colorIdentity,
        colorMatchMode: ColorMatchMode.exactly,
      );
      expect(filterIdentityColorless.matches(kozileksReturn), isFalse);
    });
  });

  group('Empirical Challenger 1: UI Thread Responsiveness & Rapid Pill Toggling', () {
    testWidgets('Rapid filter state creation and evaluation does not hang UI frame', (tester) async {
      final sw = Stopwatch()..start();
      MtgFilterState state = const MtgFilterState();

      // Simulate rapid user tapping 50 times across color pills and match modes
      final sequence = ['W', 'U', 'B', 'R', 'G', 'C'];
      for (int i = 0; i < 50; i++) {
        final color = sequence[i % sequence.length];
        final nextColors = Set<String>.from(state.colors);
        if (nextColors.contains(color)) {
          nextColors.remove(color);
        } else {
          nextColors.add(color);
        }
        state = state.copyWith(
          colors: nextColors,
          colorMatchMode: ColorMatchMode.values[i % ColorMatchMode.values.length],
        );
      }
      sw.stop();

      debugPrint('[Benchmark] 50 rapid filter state transitions: ${sw.elapsedMilliseconds}ms');
      expect(sw.elapsedMilliseconds, lessThan(50), reason: 'UI state mutations must complete in under 50ms');
    });
  });
}

