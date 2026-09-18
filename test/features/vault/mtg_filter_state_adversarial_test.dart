import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/presentation/providers/mtg_filter_state.dart';

VaultItem createCard({
  required String id,
  required String name,
  String collectionType = 'mtg',
  String setOrSeries = 'Core Set',
  String condition = 'NM',
  bool isGraded = false,
  bool isAltered = false,
  bool isMisprint = false,
  bool isSigned = false,
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
    acquiredPrice: 5.0,
    acquiredDate: DateTime(2026, 9, 18),
    quantity: 1,
    condition: condition,
    isGraded: isGraded,
    isAltered: isAltered,
    isMisprint: isMisprint,
    isSigned: isSigned,
    personalNotes: null,
    primaryBinderId: null,
    currentMarketPrice: 10.0,
    lastPriceUpdate: DateTime(2026, 9, 18),
    dynamicData: rawDynamicData ?? jsonEncode(dynamicData ?? {}),
  );
}

void main() {
  group('1. Color Identity vs Card Color', () {
    test('Hybrid Mana: Kitchen Finks has card color GW and color identity GW', () {
      final card = createCard(
        id: 'kitchen-finks',
        name: 'Kitchen Finks',
        dynamicData: {
          'mana_cost': '{1}{G/W}{G/W}',
          'colors': ['G', 'W'],
          'color_identity': ['G', 'W'],
          'type_line': 'Creature — Ouphe',
          'cmc': 3.0,
        },
      );

      // Card color target
      final filterExactGW = const MtgFilterState(
        colors: {'G', 'W'},
        colorTarget: ColorTarget.cardColor,
        colorMatchMode: ColorMatchMode.exactly,
      );
      expect(filterExactGW.matches(card), isTrue);

      final filterExactG = const MtgFilterState(
        colors: {'G'},
        colorTarget: ColorTarget.cardColor,
        colorMatchMode: ColorMatchMode.exactly,
      );
      expect(filterExactG.matches(card), isFalse);

      // Color Identity target
      final filterIdentityGW = const MtgFilterState(
        colors: {'G', 'W'},
        colorTarget: ColorTarget.colorIdentity,
        colorMatchMode: ColorMatchMode.exactly,
      );
      expect(filterIdentityGW.matches(card), isTrue);

      // Derived fallback if colors/identity omitted from Scryfall JSON
      final cardOmittedColors = createCard(
        id: 'kitchen-finks-derived',
        name: 'Kitchen Finks Derived',
        dynamicData: {
          'mana_cost': '{1}{G/W}{G/W}',
          'type_line': 'Creature — Ouphe',
        },
      );
      expect(filterExactGW.matches(cardOmittedColors), isTrue);
    });

    test('Phyrexian Mana: Dismember and Gitaxian Probe preserve base mana colors', () {
      final dismember = createCard(
        id: 'dismember',
        name: 'Dismember',
        dynamicData: {
          'mana_cost': '{1}{B/P}{B/P}',
          'colors': ['B'],
          'color_identity': ['B'],
          'type_line': 'Instant',
          'cmc': 3.0,
        },
      );
      final gitaxianProbe = createCard(
        id: 'gitaxian-probe',
        name: 'Gitaxian Probe',
        dynamicData: {
          'mana_cost': '{U/P}',
          'colors': ['U'],
          'color_identity': ['U'],
          'type_line': 'Sorcery',
          'cmc': 1.0,
        },
      );

      final filterBlack = const MtgFilterState(
        colors: {'B'},
        colorTarget: ColorTarget.cardColor,
        colorMatchMode: ColorMatchMode.exactly,
      );
      final filterBlue = const MtgFilterState(
        colors: {'U'},
        colorTarget: ColorTarget.cardColor,
        colorMatchMode: ColorMatchMode.exactly,
      );
      final filterColorless = const MtgFilterState(
        colors: {'C'},
        colorTarget: ColorTarget.cardColor,
        colorMatchMode: ColorMatchMode.exactly,
      );

      expect(filterBlack.matches(dismember), isTrue);
      expect(filterBlue.matches(dismember), isFalse);
      expect(filterColorless.matches(dismember), isFalse);

      expect(filterBlue.matches(gitaxianProbe), isTrue);
      expect(filterBlack.matches(gitaxianProbe), isFalse);
      expect(filterColorless.matches(gitaxianProbe), isFalse);
    });

    test('Off-Color Activated Abilities: Kenrith is white card with 5-color identity', () {
      final kenrith = createCard(
        id: 'kenrith',
        name: 'Kenrith, the Returned King',
        dynamicData: {
          'mana_cost': '{4}{W}',
          'colors': ['W'],
          'color_identity': ['W', 'U', 'B', 'R', 'G'],
          'type_line': 'Legendary Creature — Human Noble',
          'oracle_text':
              '{R}: All creatures gain trample and haste until end of turn.\n'
              '{1}{G}: Put a +1/+1 counter on target creature.\n'
              '{2}{W}: Target player gains 5 life.\n'
              '{3}{U}: Target player draws a card.\n'
              '{4}{B}: Put target creature card from a graveyard onto the battlefield under its owner\'s control.',
          'cmc': 5.0,
        },
      );

      // 1. ColorTarget.cardColor: should be strictly White
      final filterCardWhite = const MtgFilterState(
        colors: {'W'},
        colorTarget: ColorTarget.cardColor,
        colorMatchMode: ColorMatchMode.exactly,
      );
      expect(filterCardWhite.matches(kenrith), isTrue);

      final filterCardFiveColor = const MtgFilterState(
        colors: {'W', 'U', 'B', 'R', 'G'},
        colorTarget: ColorTarget.cardColor,
        colorMatchMode: ColorMatchMode.exactly,
      );
      expect(filterCardFiveColor.matches(kenrith), isFalse);

      // 2. ColorTarget.colorIdentity: should be strictly WUBRG
      final filterIdentityWhite = const MtgFilterState(
        colors: {'W'},
        colorTarget: ColorTarget.colorIdentity,
        colorMatchMode: ColorMatchMode.exactly,
      );
      expect(filterIdentityWhite.matches(kenrith), isFalse);

      final filterIdentityFiveColor = const MtgFilterState(
        colors: {'W', 'U', 'B', 'R', 'G'},
        colorTarget: ColorTarget.colorIdentity,
        colorMatchMode: ColorMatchMode.exactly,
      );
      expect(filterIdentityFiveColor.matches(kenrith), isTrue);

      // 3. Commander match mode with Azorius commander: Kenrith cannot fit into Azorius deck
      final filterAzoriusCommander = const MtgFilterState(
        colors: {'W', 'U'},
        colorTarget: ColorTarget.colorIdentity,
        colorMatchMode: ColorMatchMode.commander,
      );
      expect(filterAzoriusCommander.matches(kenrith), isFalse);
    });

    test('Off-Color Activated Abilities: Tasigur is black card with BUG identity', () {
      final tasigur = createCard(
        id: 'tasigur',
        name: 'Tasigur, the Golden Fang',
        dynamicData: {
          'mana_cost': '{5}{B}',
          'colors': ['B'],
          'color_identity': ['B', 'G', 'U'],
          'type_line': 'Legendary Creature — Human Shaman',
          'oracle_text': '{2}{G/U}{G/U}: Mill two cards, then target opponent puts a nonland card from your graveyard into your hand.',
          'cmc': 6.0,
        },
      );

      final filterCardBlack = const MtgFilterState(
        colors: {'B'},
        colorTarget: ColorTarget.cardColor,
        colorMatchMode: ColorMatchMode.exactly,
      );
      expect(filterCardBlack.matches(tasigur), isTrue);

      final filterIdentityBUG = const MtgFilterState(
        colors: {'B', 'G', 'U'},
        colorTarget: ColorTarget.colorIdentity,
        colorMatchMode: ColorMatchMode.exactly,
      );
      expect(filterIdentityBUG.matches(tasigur), isTrue);

      final filterIdentityBlackOnly = const MtgFilterState(
        colors: {'B'},
        colorTarget: ColorTarget.colorIdentity,
        colorMatchMode: ColorMatchMode.exactly,
      );
      expect(filterIdentityBlackOnly.matches(tasigur), isFalse);
    });

    test('Off-Color Activated Abilities: Golos is colorless card with 5-color identity', () {
      final golos = createCard(
        id: 'golos',
        name: 'Golos, Tireless Pilgrim',
        dynamicData: {
          'mana_cost': '{5}',
          'colors': [],
          'color_identity': ['W', 'U', 'B', 'R', 'G'],
          'type_line': 'Legendary Artifact Creature — Scout',
          'oracle_text': '{2}{W}{U}{B}{R}{G}: Exile the top three cards of your library.',
          'cmc': 5.0,
        },
      );

      final filterCardColorless = const MtgFilterState(
        colors: {'C'},
        colorTarget: ColorTarget.cardColor,
        colorMatchMode: ColorMatchMode.exactly,
      );
      expect(filterCardColorless.matches(golos), isTrue);

      final filterIdentityFiveColor = const MtgFilterState(
        colors: {'W', 'U', 'B', 'R', 'G'},
        colorTarget: ColorTarget.colorIdentity,
        colorMatchMode: ColorMatchMode.exactly,
      );
      expect(filterIdentityFiveColor.matches(golos), isTrue);

      // In Azorius commander deck, Golos is illegal due to 5-color identity
      final filterAzoriusCommander = const MtgFilterState(
        colors: {'W', 'U'},
        colorTarget: ColorTarget.colorIdentity,
        colorMatchMode: ColorMatchMode.commander,
      );
      expect(filterAzoriusCommander.matches(golos), isFalse);
    });

    test('Bident of Thassa: on-color ability preserves mono-blue identity', () {
      final bident = createCard(
        id: 'bident-of-thassa',
        name: 'Bident of Thassa',
        dynamicData: {
          'mana_cost': '{2}{U}{U}',
          'colors': ['U'],
          'color_identity': ['U'],
          'type_line': 'Legendary Enchantment Artifact',
          'oracle_text': 'Whenever a creature you control deals combat damage to a player, you may draw a card.\n{1}{U}, {T}: Creatures your opponents control attack this turn if able.',
          'cmc': 4.0,
        },
      );

      final filterCardBlue = const MtgFilterState(
        colors: {'U'},
        colorTarget: ColorTarget.cardColor,
        colorMatchMode: ColorMatchMode.exactly,
      );
      final filterIdentityBlue = const MtgFilterState(
        colors: {'U'},
        colorTarget: ColorTarget.colorIdentity,
        colorMatchMode: ColorMatchMode.exactly,
      );
      expect(filterCardBlue.matches(bident), isTrue);
      expect(filterIdentityBlue.matches(bident), isTrue);
    });
  });

  group('2. Color Match Modes', () {
    final cardSolRing = createCard(
      id: 'sol-ring',
      name: 'Sol Ring',
      dynamicData: {
        'mana_cost': '{1}',
        'colors': [],
        'color_identity': [],
        'type_line': 'Artifact',
        'cmc': 1.0,
      },
    );
    final cardWhite = createCard(
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
    final cardBlue = createCard(
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
    final cardAzorius = createCard(
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
    final cardEsper = createCard(
      id: 'esper-charm',
      name: 'Esper Charm',
      dynamicData: {
        'mana_cost': '{W}{U}{B}',
        'colors': ['W', 'U', 'B'],
        'color_identity': ['W', 'U', 'B'],
        'type_line': 'Instant',
        'cmc': 3.0,
      },
    );
    final cardFiveColor = createCard(
      id: 'progenitus',
      name: 'Progenitus',
      dynamicData: {
        'mana_cost': '{W}{W}{U}{U}{B}{B}{R}{R}{G}{G}',
        'colors': ['W', 'U', 'B', 'R', 'G'],
        'color_identity': ['W', 'U', 'B', 'R', 'G'],
        'type_line': 'Legendary Creature — Hydra Avatar',
        'cmc': 10.0,
      },
    );

    test('ColorMatchMode.exactly enforces strict set equality', () {
      final exactWU = const MtgFilterState(
        colors: {'W', 'U'},
        colorMatchMode: ColorMatchMode.exactly,
      );
      expect(exactWU.matches(cardAzorius), isTrue);
      expect(exactWU.matches(cardWhite), isFalse);
      expect(exactWU.matches(cardBlue), isFalse);
      expect(exactWU.matches(cardEsper), isFalse);
      expect(exactWU.matches(cardSolRing), isFalse);
      expect(exactWU.matches(cardFiveColor), isFalse);

      final exactC = const MtgFilterState(
        colors: {'C'},
        colorMatchMode: ColorMatchMode.exactly,
      );
      expect(exactC.matches(cardSolRing), isTrue);
      expect(exactC.matches(cardWhite), isFalse);
      expect(exactC.matches(cardAzorius), isFalse);
      expect(exactC.matches(cardFiveColor), isFalse);

      final exact5C = const MtgFilterState(
        colors: {'W', 'U', 'B', 'R', 'G'},
        colorMatchMode: ColorMatchMode.exactly,
      );
      expect(exact5C.matches(cardFiveColor), isTrue);
      expect(exact5C.matches(cardEsper), isFalse);
      expect(exact5C.matches(cardSolRing), isFalse);
    });

    test('ColorMatchMode.atMost enforces subset relationship and allows colorless cards', () {
      final atMostWU = const MtgFilterState(
        colors: {'W', 'U'},
        colorMatchMode: ColorMatchMode.atMost,
      );
      // Subsets of {W, U}: {}, {W}, {U}, {W, U}
      expect(atMostWU.matches(cardSolRing), isTrue, reason: 'Colorless is subset of {W, U}');
      expect(atMostWU.matches(cardWhite), isTrue, reason: '{W} is subset of {W, U}');
      expect(atMostWU.matches(cardBlue), isTrue, reason: '{U} is subset of {W, U}');
      expect(atMostWU.matches(cardAzorius), isTrue, reason: '{W, U} is subset of {W, U}');
      expect(atMostWU.matches(cardEsper), isFalse, reason: '{W, U, B} has extra color B');
      expect(atMostWU.matches(cardFiveColor), isFalse, reason: '5C has extra colors B, R, G');

      final atMostC = const MtgFilterState(
        colors: {'C'},
        colorMatchMode: ColorMatchMode.atMost,
      );
      expect(atMostC.matches(cardSolRing), isTrue);
      expect(atMostC.matches(cardWhite), isFalse);
      expect(atMostC.matches(cardAzorius), isFalse);

      final atMost5C = const MtgFilterState(
        colors: {'W', 'U', 'B', 'R', 'G'},
        colorMatchMode: ColorMatchMode.atMost,
      );
      // Every MTG card is a subset of all 5 colors
      expect(atMost5C.matches(cardSolRing), isTrue);
      expect(atMost5C.matches(cardWhite), isTrue);
      expect(atMost5C.matches(cardAzorius), isTrue);
      expect(atMost5C.matches(cardEsper), isTrue);
      expect(atMost5C.matches(cardFiveColor), isTrue);
    });

    test('ColorMatchMode.including enforces superset relationship', () {
      final incWU = const MtgFilterState(
        colors: {'W', 'U'},
        colorMatchMode: ColorMatchMode.including,
      );
      // Card colors must contain both W and U
      expect(incWU.matches(cardAzorius), isTrue);
      expect(incWU.matches(cardEsper), isTrue);
      expect(incWU.matches(cardFiveColor), isTrue);
      expect(incWU.matches(cardWhite), isFalse);
      expect(incWU.matches(cardBlue), isFalse);
      expect(incWU.matches(cardSolRing), isFalse);

      final incC = const MtgFilterState(
        colors: {'C'},
        colorMatchMode: ColorMatchMode.including,
      );
      expect(incC.matches(cardSolRing), isTrue);
      expect(incC.matches(cardWhite), isFalse);
      expect(incC.matches(cardAzorius), isFalse);

      final inc5C = const MtgFilterState(
        colors: {'W', 'U', 'B', 'R', 'G'},
        colorMatchMode: ColorMatchMode.including,
      );
      expect(inc5C.matches(cardFiveColor), isTrue);
      expect(inc5C.matches(cardEsper), isFalse);
      expect(inc5C.matches(cardAzorius), isFalse);
      expect(inc5C.matches(cardSolRing), isFalse);
    });

    test('ColorMatchMode.commander legality with colored vs colorless commander', () {
      final azoriusCommander = const MtgFilterState(
        colors: {'W', 'U'},
        colorMatchMode: ColorMatchMode.commander,
      );
      // Legal in Azorius deck: colorless, pure W, pure U, WU
      expect(azoriusCommander.matches(cardSolRing), isTrue);
      expect(azoriusCommander.matches(cardWhite), isTrue);
      expect(azoriusCommander.matches(cardBlue), isTrue);
      expect(azoriusCommander.matches(cardAzorius), isTrue);
      expect(azoriusCommander.matches(cardEsper), isFalse);
      expect(azoriusCommander.matches(cardFiveColor), isFalse);

      final colorlessCommander = const MtgFilterState(
        colors: {'C'},
        colorMatchMode: ColorMatchMode.commander,
      );
      expect(colorlessCommander.matches(cardSolRing), isTrue);
      expect(colorlessCommander.matches(cardWhite), isFalse);
      expect(colorlessCommander.matches(cardAzorius), isFalse);
    });

    test('colorCountRange boundary values (0 to 5)', () {
      final onlyColorless = const MtgFilterState(colorCountRange: RangeValues(0, 0));
      expect(onlyColorless.matches(cardSolRing), isTrue);
      expect(onlyColorless.matches(cardWhite), isFalse);

      final exactlyTwoColors = const MtgFilterState(colorCountRange: RangeValues(2, 2));
      expect(exactlyTwoColors.matches(cardAzorius), isTrue);
      expect(exactlyTwoColors.matches(cardWhite), isFalse);
      expect(exactlyTwoColors.matches(cardEsper), isFalse);
      expect(exactlyTwoColors.matches(cardSolRing), isFalse);

      final exactlyFiveColors = const MtgFilterState(colorCountRange: RangeValues(5, 5));
      expect(exactlyFiveColors.matches(cardFiveColor), isTrue);
      expect(exactlyFiveColors.matches(cardEsper), isFalse);
      expect(exactlyFiveColors.matches(cardSolRing), isFalse);
    });
  });

  group('3. Multi-face Card Inspection', () {
    test('Transform DFC: Delver of Secrets // Insectile Aberration traverses both faces', () {
      final delver = createCard(
        id: 'delver-of-secrets',
        name: 'Delver of Secrets // Insectile Aberration',
        dynamicData: {
          'layout': 'transform',
          'card_faces': [
            {
              'name': 'Delver of Secrets',
              'mana_cost': '{U}',
              'type_line': 'Creature — Human Wizard',
              'oracle_text': 'At the beginning of your upkeep, look at the top card of your library...',
              'power': '1',
              'toughness': '1',
              'colors': ['U'],
            },
            {
              'name': 'Insectile Aberration',
              'mana_cost': '',
              'type_line': 'Creature — Human Insect',
              'oracle_text': 'Flying',
              'power': '3',
              'toughness': '2',
              'colors': ['U'],
            }
          ],
        },
      );

      // Front face type 'Wizard' and back face type 'Insect'
      expect(const MtgFilterState(typeLine: 'Wizard').matches(delver), isTrue);
      expect(const MtgFilterState(typeLine: 'Insect').matches(delver), isTrue);
      expect(const MtgFilterState(typeLine: 'Dragon').matches(delver), isFalse);

      // Front face text 'upkeep' and back face text 'Flying'
      expect(const MtgFilterState(oracleTextClauses: ['upkeep']).matches(delver), isTrue);
      expect(const MtgFilterState(oracleTextClauses: ['Flying']).matches(delver), isTrue);
      expect(const MtgFilterState(oracleTextClauses: ['Trample']).matches(delver), isFalse);

      // Front face stat 1/1 and back face stat 3/2
      final statPower1 = const MtgFilterState(
        statFilters: [MtgStatFilter(stat: 'power', operator: '=', value: '1')],
      );
      final statPower3 = const MtgFilterState(
        statFilters: [MtgStatFilter(stat: 'power', operator: '=', value: '3')],
      );
      final statPower4 = const MtgFilterState(
        statFilters: [MtgStatFilter(stat: 'power', operator: '=', value: '4')],
      );
      final statToughness2 = const MtgFilterState(
        statFilters: [MtgStatFilter(stat: 'toughness', operator: '=', value: '2')],
      );

      expect(statPower1.matches(delver), isTrue);
      expect(statPower3.matches(delver), isTrue);
      expect(statPower4.matches(delver), isFalse);
      expect(statToughness2.matches(delver), isTrue);
    });

    test('Modal DFC: Valki // Tibalt traverses creature front and planeswalker back', () {
      final valki = createCard(
        id: 'valki-tibalt',
        name: 'Valki, God of Lies // Tibalt, Cosmic Impostor',
        dynamicData: {
          'layout': 'modal_dfc',
          'card_faces': [
            {
              'name': 'Valki, God of Lies',
              'mana_cost': '{1}{B}',
              'type_line': 'Legendary Creature — God',
              'oracle_text': 'When Valki enters the battlefield, each opponent exiles a creature card...',
              'power': '2',
              'toughness': '1',
              'colors': ['B'],
            },
            {
              'name': 'Tibalt, Cosmic Impostor',
              'mana_cost': '{5}{B}{R}',
              'type_line': 'Legendary Planeswalker — Tibalt',
              'oracle_text': 'As Tibalt enters the battlefield, you get an emblem...',
              'loyalty': '5',
              'colors': ['B', 'R'],
            }
          ],
        },
      );

      // Type checks across faces
      expect(const MtgFilterState(typeLine: 'God').matches(valki), isTrue);
      expect(const MtgFilterState(typeLine: 'Planeswalker').matches(valki), isTrue);
      expect(const MtgFilterState(typeLine: 'Artifact').matches(valki), isFalse);

      // Stats: Valki power 2, Tibalt loyalty 5
      final filterPower2 = const MtgFilterState(
        statFilters: [MtgStatFilter(stat: 'power', operator: '=', value: '2')],
      );
      final filterLoyalty5 = const MtgFilterState(
        statFilters: [MtgStatFilter(stat: 'loyalty', operator: '=', value: '5')],
      );
      final filterLoyalty7 = const MtgFilterState(
        statFilters: [MtgStatFilter(stat: 'loyalty', operator: '=', value: '7')],
      );

      expect(filterPower2.matches(valki), isTrue);
      expect(filterLoyalty5.matches(valki), isTrue);
      expect(filterLoyalty7.matches(valki), isFalse);

      // Mana cost across faces
      expect(const MtgFilterState(manaCost: '{1}{B}').matches(valki), isTrue);
      expect(const MtgFilterState(manaCost: '{5}{B}{R}').matches(valki), isTrue);
      expect(const MtgFilterState(manaCost: '{3}{U}').matches(valki), isFalse);
    });

    test('Adventure Card: Bonecrusher Giant // Stomp traverses creature and adventure spell', () {
      final bonecrusher = createCard(
        id: 'bonecrusher-giant',
        name: 'Bonecrusher Giant // Stomp',
        dynamicData: {
          'layout': 'adventure',
          'type_line': 'Creature — Giant // Instant — Adventure',
          'mana_cost': '{2}{R}',
          'oracle_text': 'Whenever Bonecrusher Giant becomes target... // Damage cannot be prevented this turn.',
          'card_faces': [
            {
              'name': 'Bonecrusher Giant',
              'type_line': 'Creature — Giant',
              'mana_cost': '{2}{R}',
              'power': '4',
              'toughness': '3',
            },
            {
              'name': 'Stomp',
              'type_line': 'Instant — Adventure',
              'mana_cost': '{1}{R}',
              'oracle_text': 'Damage cannot be prevented this turn. Stomp deals 2 damage.',
            }
          ],
        },
      );

      expect(const MtgFilterState(typeLine: 'Giant').matches(bonecrusher), isTrue);
      expect(const MtgFilterState(typeLine: 'Instant').matches(bonecrusher), isTrue);
      expect(const MtgFilterState(typeLine: 'Adventure').matches(bonecrusher), isTrue);
      expect(const MtgFilterState(oracleTextClauses: ['prevented']).matches(bonecrusher), isTrue);

      final statPower4 = const MtgFilterState(
        statFilters: [MtgStatFilter(stat: 'power', operator: '>=', value: '4')],
      );
      expect(statPower4.matches(bonecrusher), isTrue);
    });

    test('Split Card: Fire // Ice traverses split mana costs and effects', () {
      final fireIce = createCard(
        id: 'fire-ice',
        name: 'Fire // Ice',
        dynamicData: {
          'layout': 'split',
          'mana_cost': '{1}{R} // {1}{U}',
          'colors': ['R', 'U'],
          'type_line': 'Instant // Instant',
          'card_faces': [
            {
              'name': 'Fire',
              'mana_cost': '{1}{R}',
              'colors': ['R'],
              'oracle_text': 'Fire deals 2 damage divided as you choose among one or two targets.',
            },
            {
              'name': 'Ice',
              'mana_cost': '{1}{U}',
              'colors': ['U'],
              'oracle_text': 'Tap target permanent. Draw a card.',
            }
          ],
        },
      );

      expect(const MtgFilterState(oracleTextClauses: ['Draw a card']).matches(fireIce), isTrue);
      expect(const MtgFilterState(oracleTextClauses: ['damage divided']).matches(fireIce), isTrue);
      expect(const MtgFilterState(manaCost: '{1}{R}').matches(fireIce), isTrue);
      expect(const MtgFilterState(manaCost: '{1}{U}').matches(fireIce), isTrue);
    });

    test('Flip Card: Akki Lavarunner // Tok-Tok checks untransformed and transformed stats', () {
      final flipCard = createCard(
        id: 'akki-lavarunner',
        name: 'Akki Lavarunner // Tok-Tok, Volcano Born',
        dynamicData: {
          'layout': 'flip',
          'card_faces': [
            {
              'name': 'Akki Lavarunner',
              'type_line': 'Creature — Goblin Warrior',
              'power': '1',
              'toughness': '1',
            },
            {
              'name': 'Tok-Tok, Volcano Born',
              'type_line': 'Legendary Creature — Goblin Shaman',
              'power': '2',
              'toughness': '2',
            }
          ],
        },
      );

      expect(const MtgFilterState(typeLine: 'Warrior').matches(flipCard), isTrue);
      expect(const MtgFilterState(typeLine: 'Shaman').matches(flipCard), isTrue);

      final statPower1 = const MtgFilterState(
        statFilters: [MtgStatFilter(stat: 'power', operator: '=', value: '1')],
      );
      final statPower2 = const MtgFilterState(
        statFilters: [MtgStatFilter(stat: 'power', operator: '=', value: '2')],
      );
      expect(statPower1.matches(flipCard), isTrue);
      expect(statPower2.matches(flipCard), isTrue);
    });
  });

  group('4. Stat Filters & Boundary Conditions', () {
    test('Comparison operators: =, ==, >, <, >=, <=, != on standard creature', () {
      final bear = createCard(
        id: 'grizzly-bears',
        name: 'Grizzly Bears',
        dynamicData: {
          'power': '2',
          'toughness': '2',
          'type_line': 'Creature — Bear',
        },
      );

      // Equality
      expect(const MtgFilterState(statFilters: [MtgStatFilter(stat: 'power', operator: '=', value: '2')]).matches(bear), isTrue);
      expect(const MtgFilterState(statFilters: [MtgStatFilter(stat: 'power', operator: '==', value: '2')]).matches(bear), isTrue);
      expect(const MtgFilterState(statFilters: [MtgStatFilter(stat: 'power', operator: '=', value: '3')]).matches(bear), isFalse);

      // Greater than
      expect(const MtgFilterState(statFilters: [MtgStatFilter(stat: 'power', operator: '>', value: '1')]).matches(bear), isTrue);
      expect(const MtgFilterState(statFilters: [MtgStatFilter(stat: 'power', operator: '>', value: '2')]).matches(bear), isFalse);

      // Greater than or equal
      expect(const MtgFilterState(statFilters: [MtgStatFilter(stat: 'power', operator: '>=', value: '2')]).matches(bear), isTrue);
      expect(const MtgFilterState(statFilters: [MtgStatFilter(stat: 'power', operator: '>=', value: '3')]).matches(bear), isFalse);

      // Less than
      expect(const MtgFilterState(statFilters: [MtgStatFilter(stat: 'power', operator: '<', value: '3')]).matches(bear), isTrue);
      expect(const MtgFilterState(statFilters: [MtgStatFilter(stat: 'power', operator: '<', value: '2')]).matches(bear), isFalse);

      // Less than or equal
      expect(const MtgFilterState(statFilters: [MtgStatFilter(stat: 'power', operator: '<=', value: '2')]).matches(bear), isTrue);
      expect(const MtgFilterState(statFilters: [MtgStatFilter(stat: 'power', operator: '<=', value: '1')]).matches(bear), isFalse);

      // Not equal
      expect(const MtgFilterState(statFilters: [MtgStatFilter(stat: 'power', operator: '!=', value: '3')]).matches(bear), isTrue);
      expect(const MtgFilterState(statFilters: [MtgStatFilter(stat: 'power', operator: '!=', value: '2')]).matches(bear), isFalse);
    });

    test('Null stats: Spells and non-creatures gracefully evaluate to false', () {
      final spell = createCard(
        id: 'wrath-of-god',
        name: 'Wrath of God',
        dynamicData: {
          'mana_cost': '{2}{W}{W}',
          'type_line': 'Sorcery',
          'oracle_text': 'Destroy all creatures. They can\'t be regenerated.',
        },
      );

      // Stat filters on non-creatures/non-planeswalkers must evaluate to false
      expect(const MtgFilterState(statFilters: [MtgStatFilter(stat: 'power', operator: '=', value: '3')]).matches(spell), isFalse);
      expect(const MtgFilterState(statFilters: [MtgStatFilter(stat: 'power', operator: '!=', value: '3')]).matches(spell), isFalse);
      expect(const MtgFilterState(statFilters: [MtgStatFilter(stat: 'power', operator: '>', value: '0')]).matches(spell), isFalse);
      expect(const MtgFilterState(statFilters: [MtgStatFilter(stat: 'loyalty', operator: '=', value: '4')]).matches(spell), isFalse);
      expect(const MtgFilterState(statFilters: [MtgStatFilter(stat: 'defense', operator: '=', value: '4')]).matches(spell), isFalse);
    });

    test('Zero values: 0-power and 0-toughness creatures', () {
      final birds = createCard(
        id: 'birds-of-paradise',
        name: 'Birds of Paradise',
        dynamicData: {
          'power': '0',
          'toughness': '1',
          'type_line': 'Creature — Bird',
        },
      );

      expect(const MtgFilterState(statFilters: [MtgStatFilter(stat: 'power', operator: '=', value: '0')]).matches(birds), isTrue);
      expect(const MtgFilterState(statFilters: [MtgStatFilter(stat: 'power', operator: '<=', value: '0')]).matches(birds), isTrue);
      expect(const MtgFilterState(statFilters: [MtgStatFilter(stat: 'power', operator: '>=', value: '0')]).matches(birds), isTrue);
      expect(const MtgFilterState(statFilters: [MtgStatFilter(stat: 'power', operator: '<', value: '0')]).matches(birds), isFalse);
      expect(const MtgFilterState(statFilters: [MtgStatFilter(stat: 'power', operator: '>', value: '0')]).matches(birds), isFalse);
      expect(const MtgFilterState(statFilters: [MtgStatFilter(stat: 'power', operator: '!=', value: '0')]).matches(birds), isFalse);
      expect(const MtgFilterState(statFilters: [MtgStatFilter(stat: 'power', operator: '!=', value: '1')]).matches(birds), isTrue);
    });

    test('Negative values: Char-Rumbler has negative base power (-1)', () {
      final charRumbler = createCard(
        id: 'char-rumbler',
        name: 'Char-Rumbler',
        dynamicData: {
          'power': '-1',
          'toughness': '3',
          'type_line': 'Creature — Elemental',
        },
      );

      expect(const MtgFilterState(statFilters: [MtgStatFilter(stat: 'power', operator: '=', value: '-1')]).matches(charRumbler), isTrue);
      expect(const MtgFilterState(statFilters: [MtgStatFilter(stat: 'power', operator: '<', value: '0')]).matches(charRumbler), isTrue);
      expect(const MtgFilterState(statFilters: [MtgStatFilter(stat: 'power', operator: '<=', value: '-1')]).matches(charRumbler), isTrue);
      expect(const MtgFilterState(statFilters: [MtgStatFilter(stat: 'power', operator: '>', value: '-2')]).matches(charRumbler), isTrue);
      expect(const MtgFilterState(statFilters: [MtgStatFilter(stat: 'power', operator: '>', value: '0')]).matches(charRumbler), isFalse);
      expect(const MtgFilterState(statFilters: [MtgStatFilter(stat: 'power', operator: '>=', value: '0')]).matches(charRumbler), isFalse);
      expect(const MtgFilterState(statFilters: [MtgStatFilter(stat: 'power', operator: '!=', value: '0')]).matches(charRumbler), isTrue);
    });

    test('Asterisks (*): Variable stats like Tarmogoyf or Serra Avatar', () {
      final goyf = createCard(
        id: 'tarmogoyf',
        name: 'Tarmogoyf',
        dynamicData: {
          'power': '*',
          'toughness': '1+*',
          'type_line': 'Creature — Lhurgoyf',
        },
      );

      // Power is '*'
      expect(const MtgFilterState(statFilters: [MtgStatFilter(stat: 'power', operator: '=', value: '*')]).matches(goyf), isTrue);
      expect(const MtgFilterState(statFilters: [MtgStatFilter(stat: 'power', operator: '!=', value: '*')]).matches(goyf), isFalse);
      expect(const MtgFilterState(statFilters: [MtgStatFilter(stat: 'power', operator: '!=', value: '3')]).matches(goyf), isTrue);
      expect(const MtgFilterState(statFilters: [MtgStatFilter(stat: 'power', operator: '=', value: '3')]).matches(goyf), isFalse);
      expect(const MtgFilterState(statFilters: [MtgStatFilter(stat: 'power', operator: '>', value: '3')]).matches(goyf), isFalse);
      expect(const MtgFilterState(statFilters: [MtgStatFilter(stat: 'power', operator: '<', value: '3')]).matches(goyf), isFalse);

      // Normal card checked against '*'
      final bear = createCard(
        id: 'bear',
        name: 'Bear',
        dynamicData: {'power': '2', 'toughness': '2'},
      );
      expect(const MtgFilterState(statFilters: [MtgStatFilter(stat: 'power', operator: '=', value: '*')]).matches(bear), isFalse);
      expect(const MtgFilterState(statFilters: [MtgStatFilter(stat: 'power', operator: '!=', value: '*')]).matches(bear), isTrue);
    });

    test('Fractional values: Little Girl has 0.5 power and 0.5 toughness', () {
      final littleGirl = createCard(
        id: 'little-girl',
        name: 'Little Girl',
        dynamicData: {
          'power': '0.5',
          'toughness': '0.5',
          'type_line': 'Creature — Human Child',
        },
      );

      expect(const MtgFilterState(statFilters: [MtgStatFilter(stat: 'power', operator: '=', value: '0.5')]).matches(littleGirl), isTrue);
      expect(const MtgFilterState(statFilters: [MtgStatFilter(stat: 'power', operator: '<', value: '1')]).matches(littleGirl), isTrue);
      expect(const MtgFilterState(statFilters: [MtgStatFilter(stat: 'power', operator: '>', value: '0')]).matches(littleGirl), isTrue);
      expect(const MtgFilterState(statFilters: [MtgStatFilter(stat: 'power', operator: '>', value: '0.5')]).matches(littleGirl), isFalse);
    });

    test('Battle Defense: Invasion of Gobakhan has defense 4', () {
      final battle = createCard(
        id: 'invasion-of-gobakhan',
        name: 'Invasion of Gobakhan',
        dynamicData: {
          'type_line': 'Battle — Siege',
          'defense': '4',
        },
      );

      expect(const MtgFilterState(statFilters: [MtgStatFilter(stat: 'defense', operator: '=', value: '4')]).matches(battle), isTrue);
      expect(const MtgFilterState(statFilters: [MtgStatFilter(stat: 'defense', operator: '>', value: '3')]).matches(battle), isTrue);
      expect(const MtgFilterState(statFilters: [MtgStatFilter(stat: 'defense', operator: '<=', value: '4')]).matches(battle), isTrue);
      expect(const MtgFilterState(statFilters: [MtgStatFilter(stat: 'defense', operator: '>', value: '4')]).matches(battle), isFalse);
    });
  });

  group('5. Oracle Text Clauses', () {
    final complexCard = createCard(
      id: 'teferi-hero',
      name: 'Teferi, Hero of Dominaria',
      dynamicData: {
        'type_line': 'Legendary Planeswalker — Teferi',
        'oracle_text':
            '+1: Draw a card. At the beginning of the next end step, untap up to two lands.\n'
            '−3: Put target nonland permanent into its owner\'s library third from the top.\n'
            '−8: You get an emblem with "Whenever you draw a card, exile target permanent an opponent controls."',
      },
    );

    test('Case insensitivity across multi-case clauses', () {
      expect(const MtgFilterState(oracleTextClauses: ['DRAW A CARD']).matches(complexCard), isTrue);
      expect(const MtgFilterState(oracleTextClauses: ['dRaW a CaRd']).matches(complexCard), isTrue);
      expect(const MtgFilterState(oracleTextClauses: ['ExIlE tArGeT']).matches(complexCard), isTrue);
      expect(const MtgFilterState(oracleTextClauses: ['nonexistent text']).matches(complexCard), isFalse);
    });

    test('Multi-line text matching across newline boundaries', () {
      expect(const MtgFilterState(oracleTextClauses: ['untap up to two lands']).matches(complexCard), isTrue);
      expect(const MtgFilterState(oracleTextClauses: ['third from the top']).matches(complexCard), isTrue);
      expect(const MtgFilterState(oracleTextClauses: ['emblem with']).matches(complexCard), isTrue);
    });

    test('Special characters, symbols, and punctuation', () {
      final symbolCard = createCard(
        id: 'llanowar-elves',
        name: 'Llanowar Elves',
        dynamicData: {
          'type_line': 'Creature — Elf Druid',
          'oracle_text': '{T}: Add {G}. (This creature can\'t attack the turn it enters.)\n[+1/+1 counter: special].',
        },
      );

      // Mana symbol syntax
      expect(const MtgFilterState(oracleTextClauses: ['{T}: Add {G}.']).matches(symbolCard), isTrue);

      // Parentheses (reminder text)
      expect(const MtgFilterState(oracleTextClauses: ['(This creature can\'t attack']).matches(symbolCard), isTrue);

      // Brackets, plus sign, slash, colon
      expect(const MtgFilterState(oracleTextClauses: ['[+1/+1 counter: special]']).matches(symbolCard), isTrue);

      // Em dash and quote handling on Teferi
      expect(const MtgFilterState(oracleTextClauses: ['"Whenever you draw']).matches(complexCard), isTrue);
    });

    test('Regex characters and metacharacters do not throw exceptions', () {
      // Clauses containing raw regex characters: .*+?^$()[]{}|\\
      const trickyFilter = MtgFilterState(
        oracleTextClauses: ['.*', '+1', '(?)', '[a-z]', 'c++'],
      );

      // Should safely evaluate without crashing
      expect(() => trickyFilter.matches(complexCard), returnsNormally);
    });

    test('Multiple clauses enforce strict AND conjunction', () {
      // Both clauses present
      final filterBothPresent = const MtgFilterState(
        oracleTextClauses: ['draw a card', 'untap up to two lands'],
      );
      expect(filterBothPresent.matches(complexCard), isTrue);

      // One present, one absent
      final filterOneMissing = const MtgFilterState(
        oracleTextClauses: ['draw a card', 'trample'],
      );
      expect(filterOneMissing.matches(complexCard), isFalse);

      // Empty and whitespace clauses are ignored
      final filterWithWhitespace = const MtgFilterState(
        oracleTextClauses: ['draw a card', '   ', ''],
      );
      expect(filterWithWhitespace.matches(complexCard), isTrue);
    });
  });

  group('6. Active Count & Reset', () {
    test('Initial blank state has activeCount == 0 and isActive == false', () {
      const state = MtgFilterState();
      expect(state.activeCount, 0);
      expect(state.isActive, isFalse);
    });

    test('Each individual filter dimension increments activeCount independently', () {
      // 1. colors
      expect(const MtgFilterState(colors: {'W'}).activeCount, 1);
      // 2. colorCountRange (non-default 0-5)
      expect(const MtgFilterState(colorCountRange: RangeValues(1, 5)).activeCount, 1);
      expect(const MtgFilterState(colorCountRange: RangeValues(0, 4)).activeCount, 1);
      expect(const MtgFilterState(colorCountRange: RangeValues(0, 5)).activeCount, 0); // default
      // 3. cmcRange (non-default 0-16)
      expect(const MtgFilterState(cmcRange: RangeValues(1, 16)).activeCount, 1);
      expect(const MtgFilterState(cmcRange: RangeValues(0, 15)).activeCount, 1);
      expect(const MtgFilterState(cmcRange: RangeValues(0, 16)).activeCount, 0); // default
      // 4. typeLine
      expect(const MtgFilterState(typeLine: 'Creature').activeCount, 1);
      expect(const MtgFilterState(typeLine: '   ').activeCount, 0); // whitespace ignored
      // 5. oracleTextClauses
      expect(const MtgFilterState(oracleTextClauses: ['flying']).activeCount, 1);
      expect(const MtgFilterState(oracleTextClauses: ['flying', 'haste']).activeCount, 2);
      expect(const MtgFilterState(oracleTextClauses: ['   ']).activeCount, 0);
      // 6. manaCost
      expect(const MtgFilterState(manaCost: '{1}{U}').activeCount, 1);
      expect(const MtgFilterState(manaCost: '  ').activeCount, 0);
      // 7. setCode
      expect(const MtgFilterState(setCode: 'm21').activeCount, 1);
      expect(const MtgFilterState(setCode: '  ').activeCount, 0);
      // 8. rarities
      expect(const MtgFilterState(rarities: {'rare'}).activeCount, 1);
      // 9. layouts
      expect(const MtgFilterState(layouts: {'transform'}).activeCount, 1);
      // 10. finishes
      expect(const MtgFilterState(finishes: {'foil'}).activeCount, 1);
      // 11. conditions
      expect(const MtgFilterState(conditions: {'NM'}).activeCount, 1);
      // 12. languages
      expect(const MtgFilterState(languages: {'JA'}).activeCount, 1);
      // 13. statFilters
      expect(const MtgFilterState(statFilters: [MtgStatFilter(stat: 'power', value: '3')]).activeCount, 1);
      expect(const MtgFilterState(statFilters: [
        MtgStatFilter(stat: 'power', value: '3'),
        MtgStatFilter(stat: 'toughness', value: '3'),
      ]).activeCount, 2);
      // 14. isReserved
      expect(const MtgFilterState(isReserved: true).activeCount, 1);
      expect(const MtgFilterState(isReserved: false).activeCount, 1);
      // 15. isUniversesBeyond
      expect(const MtgFilterState(isUniversesBeyond: true).activeCount, 1);
      // 16. isPromo
      expect(const MtgFilterState(isPromo: true).activeCount, 1);
      // 17. isReprint
      expect(const MtgFilterState(isReprint: false).activeCount, 1);
      // 18. isAltered
      expect(const MtgFilterState(isAltered: true).activeCount, 1);
      // 19. isMisprint
      expect(const MtgFilterState(isMisprint: false).activeCount, 1);
      // 20. isGraded
      expect(const MtgFilterState(isGraded: true).activeCount, 1);
      // 21. isSigned
      expect(const MtgFilterState(isSigned: false).activeCount, 1);
    });

    test('Cumulative activeCount aggregates all dimensions simultaneously', () {
      final fullState = const MtgFilterState(
        colors: {'W', 'U'}, // 1
        colorCountRange: RangeValues(1, 3), // 1
        cmcRange: RangeValues(2, 6), // 1
        typeLine: 'Creature', // 1
        oracleTextClauses: ['draw', 'flying'], // 2
        manaCost: '{1}{U}', // 1
        setCode: 'm21', // 1
        rarities: {'rare'}, // 1
        layouts: {'normal'}, // 1
        finishes: {'foil'}, // 1
        conditions: {'NM'}, // 1
        languages: {'English'}, // 1
        statFilters: [
          MtgStatFilter(stat: 'power', operator: '>', value: '2'),
          MtgStatFilter(stat: 'toughness', operator: '>', value: '2'),
        ], // 2
        isReserved: false, // 1
        isUniversesBeyond: true, // 1
        isPromo: false, // 1
        isReprint: false, // 1
        isAltered: false, // 1
        isMisprint: false, // 1
        isGraded: false, // 1
        isSigned: false, // 1
      );

      // Total: 1+1+1+1+2+1+1+1+1+1+1+1+2+1+1+1+1+1+1+1+1 = 23
      expect(fullState.activeCount, 23);
      expect(fullState.isActive, isTrue);

      // Reset clears everything back to 0
      final clean = fullState.reset();
      expect(clean.activeCount, 0);
      expect(clean.isActive, isFalse);
      expect(clean.colors, isEmpty);
      expect(clean.colorCountRange, const RangeValues(0, 5));
      expect(clean.cmcRange, const RangeValues(0, 16));
      expect(clean.typeLine, isEmpty);
      expect(clean.oracleTextClauses, isEmpty);
      expect(clean.statFilters, isEmpty);
      expect(clean.isUniversesBeyond, isNull);
    });

    test('reset() idempotency across multiple invocations', () {
      var state = const MtgFilterState(colors: {'W', 'B'}, typeLine: 'Angel');
      state = state.reset();
      state = state.reset();
      state = state.reset();
      expect(state.activeCount, 0);
      expect(state.isActive, isFalse);
    });
  });

  group('7. Adversarial Malformed & Edge Inputs', () {
    test('Corrupted dynamicData does not crash evaluator', () {
      final corruptedCard = createCard(
        id: 'corrupted',
        name: 'Corrupted JSON Card',
        rawDynamicData: r'{this is not valid json!@#$%',
      );

      const filter = MtgFilterState(typeLine: 'Creature', colors: {'W'});
      expect(() => filter.matches(corruptedCard), returnsNormally);
      expect(filter.matches(corruptedCard), isFalse);
    });

    test('Malformed card_faces (non-maps, numbers) handled defensively', () {
      final weirdCard = createCard(
        id: 'weird-faces',
        name: 'Weird Card Faces',
        dynamicData: {
          'card_faces': [
            'not a map',
            12345,
            null,
            {'name': 'Valid Face', 'type_line': 'Artifact'},
          ],
        },
      );

      expect(const MtgFilterState(typeLine: 'Artifact').matches(weirdCard), isTrue);
      expect(const MtgFilterState(typeLine: 'Creature').matches(weirdCard), isFalse);
    });

    test('Set operator != properly inverts match condition', () {
      final m21Card = createCard(
        id: 'm21-card',
        name: 'M21 Card',
        dynamicData: {'set': 'm21'},
      );
      final neoCard = createCard(
        id: 'neo-card',
        name: 'NEO Card',
        dynamicData: {'set': 'neo'},
      );

      final filterNotM21 = const MtgFilterState(setCode: 'm21', setOperator: '!=');
      expect(filterNotM21.matches(m21Card), isFalse);
      expect(filterNotM21.matches(neoCard), isTrue);

      final filterEqualsM21 = const MtgFilterState(setCode: 'm21', setOperator: '=');
      expect(filterEqualsM21.matches(m21Card), isTrue);
      expect(filterEqualsM21.matches(neoCard), isFalse);
    });

    test('Condition normalization across aliases', () {
      final nmCard = createCard(id: 'c1', name: 'Card 1', condition: 'Near Mint');
      final lpCard = createCard(id: 'c2', name: 'Card 2', condition: 'Lightly Played');
      final poCard = createCard(id: 'c3', name: 'Card 3', condition: 'Damaged');

      expect(const MtgFilterState(conditions: {'NM'}).matches(nmCard), isTrue);
      expect(const MtgFilterState(conditions: {'NEAR MINT'}).matches(nmCard), isTrue);
      expect(const MtgFilterState(conditions: {'LP'}).matches(lpCard), isTrue);
      expect(const MtgFilterState(conditions: {'LIGHT PLAYED'}).matches(lpCard), isTrue);
      expect(const MtgFilterState(conditions: {'PO'}).matches(poCard), isTrue);
      expect(const MtgFilterState(conditions: {'POOR'}).matches(poCard), isTrue);
      expect(const MtgFilterState(conditions: {'MINT'}).matches(nmCard), isFalse);
    });

    test('Language normalization across codes and full names', () {
      final jpCard = createCard(
        id: 'c-jp',
        name: 'Japanese Card',
        dynamicData: {'lang': 'ja'},
      );
      final enCard = createCard(
        id: 'c-en',
        name: 'English Card',
        dynamicData: {'lang': 'en'},
      );

      expect(const MtgFilterState(languages: {'Japanese'}).matches(jpCard), isTrue);
      expect(const MtgFilterState(languages: {'JA'}).matches(jpCard), isTrue);
      expect(const MtgFilterState(languages: {'JP'}).matches(jpCard), isTrue);
      expect(const MtgFilterState(languages: {'EN'}).matches(jpCard), isFalse);
      expect(const MtgFilterState(languages: {'English'}).matches(enCard), isTrue);
    });

    test('Collection boolean flags: isGraded, isAltered, isMisprint, isSigned', () {
      final customCard = createCard(
        id: 'custom',
        name: 'Custom Card',
        isGraded: true,
        isAltered: false,
        isMisprint: true,
        isSigned: false,
      );

      expect(const MtgFilterState(isGraded: true).matches(customCard), isTrue);
      expect(const MtgFilterState(isGraded: false).matches(customCard), isFalse);
      expect(const MtgFilterState(isAltered: false).matches(customCard), isTrue);
      expect(const MtgFilterState(isAltered: true).matches(customCard), isFalse);
      expect(const MtgFilterState(isMisprint: true).matches(customCard), isTrue);
      expect(const MtgFilterState(isMisprint: false).matches(customCard), isFalse);
      expect(const MtgFilterState(isSigned: false).matches(customCard), isTrue);
      expect(const MtgFilterState(isSigned: true).matches(customCard), isFalse);
    });
  });
}
