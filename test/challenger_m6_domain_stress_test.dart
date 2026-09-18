import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/hydration/domain/isolate/scryfall_parser.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/domain/vault_pricing_helper.dart';
import 'package:countr/features/vault/presentation/providers/mtg_filter_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Challenger M6 Group 1: VaultPricingHelper Hardened Stress Tests', () {
    test('1.1 parsePositivePrice rejects negative values and zero representations', () {
      expect(VaultPricingHelper.parsePositivePrice(-0.01), isNull);
      expect(VaultPricingHelper.parsePositivePrice(-100.0), isNull);
      expect(VaultPricingHelper.parsePositivePrice('-0.01'), isNull);
      expect(VaultPricingHelper.parsePositivePrice('-5.00'), isNull);
      expect(VaultPricingHelper.parsePositivePrice(0), isNull);
      expect(VaultPricingHelper.parsePositivePrice(0.0), isNull);
      expect(VaultPricingHelper.parsePositivePrice('0'), isNull);
      expect(VaultPricingHelper.parsePositivePrice('0.0'), isNull);
      expect(VaultPricingHelper.parsePositivePrice('0.00'), isNull);
      expect(VaultPricingHelper.parsePositivePrice('0.000000'), isNull);
      expect(VaultPricingHelper.parsePositivePrice('   0.00   '), isNull);
    });

    test('1.2 parsePositivePrice rejects non-numeric, special IEEE, and symbol strings', () {
      expect(VaultPricingHelper.parsePositivePrice('NaN'), isNull);
      expect(VaultPricingHelper.parsePositivePrice('Infinity'), isNull);
      expect(VaultPricingHelper.parsePositivePrice('-Infinity'), isNull);
      expect(VaultPricingHelper.parsePositivePrice(double.nan), isNull);
      expect(VaultPricingHelper.parsePositivePrice(double.infinity), isNull);
      expect(VaultPricingHelper.parsePositivePrice(double.negativeInfinity), isNull);
      expect(VaultPricingHelper.parsePositivePrice(''), isNull);
      expect(VaultPricingHelper.parsePositivePrice('   '), isNull);
      expect(VaultPricingHelper.parsePositivePrice(null), isNull);
      expect(VaultPricingHelper.parsePositivePrice('\$12.50'), isNull);
      expect(VaultPricingHelper.parsePositivePrice('12,50'), isNull);
      expect(VaultPricingHelper.parsePositivePrice('free'), isNull);
      expect(VaultPricingHelper.parsePositivePrice(true), isNull);
      expect(VaultPricingHelper.parsePositivePrice(['12.50']), isNull);
      expect(VaultPricingHelper.parsePositivePrice({'price': 12.5}), isNull);
    });

    test('1.3 parsePositivePrice accepts valid positive numbers and strings', () {
      expect(VaultPricingHelper.parsePositivePrice('0.01'), equals(0.01));
      expect(VaultPricingHelper.parsePositivePrice(0.01), equals(0.01));
      expect(VaultPricingHelper.parsePositivePrice('12.50'), equals(12.50));
      expect(VaultPricingHelper.parsePositivePrice('  999.99  '), equals(999.99));
      expect(VaultPricingHelper.parsePositivePrice(42), equals(42.0));
      expect(VaultPricingHelper.parsePositivePrice(1000000.5), equals(1000000.5));
    });

    test('1.4 resolveHierarchicalPrice strictly respects pricing hierarchy order', () {
      // 1. usd present
      final p1 = {
        'usd': '10.00',
        'usd_foil': '20.00',
        'usd_etched': '30.00',
        'eur': '8.00',
        'eur_foil': '16.00',
      };
      expect(VaultPricingHelper.resolveHierarchicalPrice(p1), equals(10.00));

      // 2. usd is zero string -> fallback to usd_foil
      final p2 = {
        'usd': '0.00',
        'usd_foil': '25.00',
        'usd_etched': '35.00',
        'eur': '20.00',
      };
      expect(VaultPricingHelper.resolveHierarchicalPrice(p2), equals(25.00));

      // 3. usd is null, usd_foil is zero string -> fallback to usd_etched
      final p3 = {
        'usd': null,
        'usd_foil': '0.00',
        'usd_etched': '45.50',
        'eur': '30.00',
      };
      expect(VaultPricingHelper.resolveHierarchicalPrice(p3), equals(45.50));

      // 4. usd, usd_foil, usd_etched invalid -> fallback to eur
      final p4 = {
        'usd': '',
        'usd_foil': null,
        'usd_etched': '-5.00',
        'eur': '7.25',
        'eur_foil': '14.00',
      };
      expect(VaultPricingHelper.resolveHierarchicalPrice(p4), equals(7.25));

      // 5. eur is zero string -> fallback to eur_foil
      final p5 = {
        'usd': '0.0',
        'usd_foil': 'NaN',
        'usd_etched': null,
        'eur': '0.00',
        'eur_foil': '18.99',
      };
      expect(VaultPricingHelper.resolveHierarchicalPrice(p5), equals(18.99));

      // 6. all invalid or empty -> returns 0.0
      expect(VaultPricingHelper.resolveHierarchicalPrice(null), equals(0.0));
      expect(VaultPricingHelper.resolveHierarchicalPrice({}), equals(0.0));
      expect(
        VaultPricingHelper.resolveHierarchicalPrice({
          'usd': '0.00',
          'usd_foil': null,
          'usd_etched': '',
          'eur': '0',
          'eur_foil': '-1.0',
        }),
        equals(0.0),
      );
    });

    test('1.5 formatMarketPriceLabel and formatMarketHeaderLabel never emit "Check"', () {
      final testCases = [
        0.0,
        -0.0,
        -1.0,
        -999.99,
        double.nan,
        double.infinity,
        double.negativeInfinity,
      ];

      for (final val in testCases) {
        final label = VaultPricingHelper.formatMarketPriceLabel(val);
        expect(label, equals('Unlisted'));
        expect(label.toLowerCase(), isNot(contains('check')));

        final header = VaultPricingHelper.formatMarketHeaderLabel(val);
        expect(header, equals('Market: Unlisted'));
        expect(header.toLowerCase(), isNot(contains('check')));
      }

      // Valid prices format correctly
      expect(VaultPricingHelper.formatMarketPriceLabel(12.5), equals('\$12.50'));
      expect(VaultPricingHelper.formatMarketPriceLabel(0.01), equals('\$0.01'));
      expect(VaultPricingHelper.formatMarketHeaderLabel(12.5), equals('Market: \$12.50'));
    });

    test('1.6 extractFromDynamicData handles malformed JSON and card_faces gracefully', () {
      expect(VaultPricingHelper.extractFromDynamicData(null), equals(0.0));
      expect(VaultPricingHelper.extractFromDynamicData(''), equals(0.0));
      expect(VaultPricingHelper.extractFromDynamicData('{invalid_json: true'), equals(0.0));
      expect(VaultPricingHelper.extractFromDynamicData(123), equals(0.0));
      expect(VaultPricingHelper.extractFromDynamicData(['not', 'a', 'map']), equals(0.0));

      // Root prices
      final validJson = jsonEncode({
        'prices': {'usd': null, 'usd_foil': '19.95'}
      });
      expect(VaultPricingHelper.extractFromDynamicData(validJson), equals(19.95));

      // card_faces prices fallback
      final cardFacesJson = jsonEncode({
        'card_faces': [
          {
            'prices': {'usd': '34.50'}
          }
        ]
      });
      expect(VaultPricingHelper.extractFromDynamicData(cardFacesJson), equals(34.50));
    });
  });

  group('Challenger M6 Group 2: Scryfall Parser Multi-Face Layouts & Metadata Stress', () {
    test('2.1 Adventure card: combines oracle text and strictly suppresses backImageUrl', () {
      final adventureCard = {
        'id': 'adv-bonecrusher',
        'name': 'Bonecrusher Giant // Stomp',
        'set': 'eld',
        'set_name': 'Throne of Eldraine',
        'layout': 'adventure',
        'image_uris': {
          'normal': 'https://cards.scryfall.io/large/front/b/o/bonecrusher.jpg',
        },
        'card_faces': [
          {
            'name': 'Bonecrusher Giant',
            'mana_cost': '{2}{R}',
            'type_line': 'Creature — Giant Berserker',
            'oracle_text': 'Whenever Bonecrusher Giant becomes the target of a spell, it deals 2 damage to that spell\'s controller.',
            'power': '4',
            'toughness': '3',
          },
          {
            'name': 'Stomp',
            'mana_cost': '{1}{R}',
            'type_line': 'Instant — Adventure',
            'oracle_text': 'Damage can\'t be prevented this turn. Stomp deals 2 damage to any target.',
          },
        ],
        'prices': {'usd': '1.25'},
      };

      final companion = mapScryfallCardToCompanion(adventureCard);
      expect(companion.name.value, equals('Bonecrusher Giant // Stomp'));
      expect(companion.imageUrl.value, equals('https://cards.scryfall.io/large/front/b/o/bonecrusher.jpg'));

      final dyn = jsonDecode(companion.dynamicData.value) as Map<String, dynamic>;
      expect(dyn['layout'], equals('adventure'));
      expect(
        dyn['oracle_text'],
        equals('Whenever Bonecrusher Giant becomes the target of a spell, it deals 2 damage to that spell\'s controller. // Damage can\'t be prevented this turn. Stomp deals 2 damage to any target.'),
      );
      // Because neither face provides separate image_uris, back_image_url must be null
      expect(dyn['back_image_url'], isNull);
    });

    test('2.2 Transforming DFC: populates both front image and back_image_url', () {
      final dfcCard = {
        'id': 'dfc-delver',
        'name': 'Delver of Secrets // Insectile Aberration',
        'set': 'isd',
        'set_name': 'Innistrad',
        'layout': 'transform',
        'card_faces': [
          {
            'name': 'Delver of Secrets',
            'mana_cost': '{U}',
            'type_line': 'Creature — Human Wizard',
            'oracle_text': 'At the beginning of your upkeep, look at the top card of your library...',
            'power': '1',
            'toughness': '1',
            'image_uris': {
              'normal': 'https://cards.scryfall.io/front/delver.jpg',
            },
          },
          {
            'name': 'Insectile Aberration',
            'type_line': 'Creature — Human Insect',
            'oracle_text': 'Flying',
            'power': '3',
            'toughness': '2',
            'image_uris': {
              'normal': 'https://cards.scryfall.io/back/delver.jpg',
            },
          },
        ],
        'prices': {'usd': '0.75'},
      };

      final companion = mapScryfallCardToCompanion(dfcCard);
      expect(companion.imageUrl.value, equals('https://cards.scryfall.io/front/delver.jpg'));

      final dyn = jsonDecode(companion.dynamicData.value) as Map<String, dynamic>;
      expect(dyn['layout'], equals('transform'));
      expect(dyn['back_image_url'], equals('https://cards.scryfall.io/back/delver.jpg'));
      expect(dyn['oracle_text'], contains('Flying'));
      expect((dyn['card_faces'] as List)[1]['name'], equals('Insectile Aberration'));
    });

    test('2.3 Secret Lair Drop set code and set name indexing', () {
      final sldCard = {
        'id': 'sld-sol-ring',
        'name': 'Sol Ring',
        'set': 'SLD',
        'set_name': 'Secret Lair Drop',
        'layout': 'normal',
        'prices': {'usd_foil': '45.00'},
      };

      final companion = mapScryfallCardToCompanion(sldCard);
      expect(companion.setOrSeries.value, equals('Secret Lair Drop'));

      final dyn = jsonDecode(companion.dynamicData.value) as Map<String, dynamic>;
      expect(dyn['set'], equals('sld'));
      expect(dyn['set_code'], equals('sld'));
      expect(dyn['set_name'], equals('Secret Lair Drop'));
    });

    test('2.4 Universes Beyond detection across weird variations and face levels', () {
      // 1. Root promo_types with spacing / mixed case
      final ub1 = mapScryfallCardToCompanion({
        'id': 'ub-1',
        'name': 'Card 1',
        'promo_types': ['Universes_Beyond'],
      });
      expect((jsonDecode(ub1.dynamicData.value) as Map)['is_universes_beyond'], isTrue);

      // 2. Root frame_effects with 'universesbeyond'
      final ub2 = mapScryfallCardToCompanion({
        'id': 'ub-2',
        'name': 'Card 2',
        'frame_effects': ['universesbeyond'],
      });
      expect((jsonDecode(ub2.dynamicData.value) as Map)['is_universes_beyond'], isTrue);

      // 3. Root security_stamp == 'triangle'
      final ub3 = mapScryfallCardToCompanion({
        'id': 'ub-3',
        'name': 'Card 3',
        'security_stamp': 'TRIANGLE',
      });
      expect((jsonDecode(ub3.dynamicData.value) as Map)['is_universes_beyond'], isTrue);

      // 4. Face-level promo_types
      final ub4 = mapScryfallCardToCompanion({
        'id': 'ub-4',
        'name': 'Card 4',
        'card_faces': [
          {
            'name': 'Face 1',
            'promo_types': ['universesbeyond'],
          },
        ],
      });
      expect((jsonDecode(ub4.dynamicData.value) as Map)['is_universes_beyond'], isTrue);

      // 5. Face-level security_stamp
      final ub5 = mapScryfallCardToCompanion({
        'id': 'ub-5',
        'name': 'Card 5',
        'card_faces': [
          {
            'name': 'Face 1',
            'security_stamp': 'triangle',
          },
        ],
      });
      expect((jsonDecode(ub5.dynamicData.value) as Map)['is_universes_beyond'], isTrue);

      // 6. Negative control: standard card
      final regular = mapScryfallCardToCompanion({
        'id': 'reg-1',
        'name': 'Regular Card',
        'promo_types': ['boosterfun'],
        'frame_effects': ['showcase'],
        'security_stamp': 'oval',
      });
      expect((jsonDecode(regular.dynamicData.value) as Map)['is_universes_beyond'], isFalse);
    });

    test('2.5 Flavor name extraction at root level and multi-face joining', () {
      // Root level flavor name (e.g. Godzilla / Universes Beyond styles)
      final card1 = mapScryfallCardToCompanion({
        'id': 'fn-1',
        'name': 'The Ozolith',
        'flavor_name': 'Adamantium Bonding Tank',
      });
      expect(card1.flavorName.value, equals('Adamantium Bonding Tank'));
      final dyn1 = jsonDecode(card1.dynamicData.value) as Map<String, dynamic>;
      expect(dyn1['flavor_name'], equals('Adamantium Bonding Tank'));

      // Face level flavor names
      final card2 = mapScryfallCardToCompanion({
        'id': 'fn-2',
        'name': 'Front // Back',
        'card_faces': [
          {'name': 'Front', 'flavor_name': 'Mecha Front'},
          {'name': 'Back', 'flavor_name': 'Mecha Back'},
        ],
      });
      expect(card2.flavorName.value, equals('Mecha Front // Mecha Back'));
    });
  });

  group('Challenger M6 Group 3: MtgFilterState & MtgStatFilter Adversarial Stress Tests', () {
    VaultItem makeItem({
      required String id,
      required String name,
      Map<String, dynamic>? dynamicData,
      String condition = 'NM',
      bool isGraded = false,
      bool isAltered = false,
      bool isMisprint = false,
      bool isSigned = false,
    }) {
      return VaultItem(
        id: id,
        collectionType: 'mtg',
        name: name,
        flavorName: null,
        setOrSeries: 'MH3',
        imageUrl: '',
        acquiredPrice: 5.0,
        acquiredDate: DateTime(2026, 9, 18),
        quantity: 1,
        condition: condition,
        isGraded: isGraded,
        isAltered: isAltered,
        isMisprint: isMisprint,
        isSigned: isSigned,
        currentMarketPrice: 10.0,
        lastPriceUpdate: DateTime(2026, 9, 18),
        dynamicData: jsonEncode(dynamicData ?? {}),
      );
    }

    test('3.1 Negative power & toughness comparison (Spinal Parasite, Char-Rumbler)', () {
      final negativeStatsCard = makeItem(
        id: 'spinal-parasite',
        name: 'Spinal Parasite',
        dynamicData: {
          'power': '-1',
          'toughness': '-1',
          'type_line': 'Artifact Creature — Insect',
        },
      );

      // power = -1
      expect(
        const MtgStatFilter(stat: 'power', operator: '=', value: '-1').matches(
          jsonDecode(negativeStatsCard.dynamicData),
        ),
        isTrue,
      );

      // power < 0
      expect(
        const MtgStatFilter(stat: 'power', operator: '<', value: '0').matches(
          jsonDecode(negativeStatsCard.dynamicData),
        ),
        isTrue,
      );

      // power > -2
      expect(
        const MtgStatFilter(stat: 'power', operator: '>', value: '-2').matches(
          jsonDecode(negativeStatsCard.dynamicData),
        ),
        isTrue,
      );

      // power >= -1
      expect(
        const MtgStatFilter(stat: 'power', operator: '>=', value: '-1').matches(
          jsonDecode(negativeStatsCard.dynamicData),
        ),
        isTrue,
      );

      // power != 0
      expect(
        const MtgStatFilter(stat: 'power', operator: '!=', value: '0').matches(
          jsonDecode(negativeStatsCard.dynamicData),
        ),
        isTrue,
      );

      // power > 0 is false
      expect(
        const MtgStatFilter(stat: 'power', operator: '>', value: '0').matches(
          jsonDecode(negativeStatsCard.dynamicData),
        ),
        isFalse,
      );
    });

    test('3.2 Variable stats (*) and fractional stats (0.5 Little Girl)', () {
      final starCard = makeItem(
        id: 'tarmogoyf',
        name: 'Tarmogoyf',
        dynamicData: {
          'power': '*',
          'toughness': '1+*',
        },
      );

      final dynStar = jsonDecode(starCard.dynamicData) as Map<String, dynamic>;

      // power = *
      expect(
        const MtgStatFilter(stat: 'power', operator: '=', value: '*').matches(dynStar),
        isTrue,
      );
      // power != 3
      expect(
        const MtgStatFilter(stat: 'power', operator: '!=', value: '3').matches(dynStar),
        isTrue,
      );
      // power > 2 fails gracefully without unhandled exception
      expect(
        const MtgStatFilter(stat: 'power', operator: '>', value: '2').matches(dynStar),
        isFalse,
      );

      // Fractional stat
      final halfCard = makeItem(
        id: 'little-girl',
        name: 'Little Girl',
        dynamicData: {'power': '0.5', 'toughness': '0.5'},
      );
      final dynHalf = jsonDecode(halfCard.dynamicData) as Map<String, dynamic>;
      expect(
        const MtgStatFilter(stat: 'power', operator: '<', value: '1').matches(dynHalf),
        isTrue,
      );
      expect(
        const MtgStatFilter(stat: 'power', operator: '>', value: '0').matches(dynHalf),
        isTrue,
      );
      expect(
        const MtgStatFilter(stat: 'power', operator: '=', value: '0.5').matches(dynHalf),
        isTrue,
      );
    });

    test('3.3 Multi-faced card stat resolution across card_faces', () {
      final transformingCard = makeItem(
        id: 'werewolf',
        name: 'Daybreak Ranger // Nightfall Predator',
        dynamicData: {
          'card_faces': [
            {'name': 'Daybreak Ranger', 'power': '2', 'toughness': '2'},
            {'name': 'Nightfall Predator', 'power': '4', 'toughness': '4'},
          ],
        },
      );
      final dynWerewolf = jsonDecode(transformingCard.dynamicData) as Map<String, dynamic>;

      // Matches if face 0 matches
      expect(
        const MtgStatFilter(stat: 'power', operator: '=', value: '2').matches(dynWerewolf),
        isTrue,
      );

      // Matches if face 1 matches
      expect(
        const MtgStatFilter(stat: 'power', operator: '=', value: '4').matches(dynWerewolf),
        isTrue,
      );

      // Does not match non-existent stat
      expect(
        const MtgStatFilter(stat: 'power', operator: '=', value: '7').matches(dynWerewolf),
        isFalse,
      );
    });

    test('3.4 Colorless C filtering and ColorMatchMode permutations', () {
      final colorlessCard = makeItem(
        id: 'wastes',
        name: 'Wastes',
        dynamicData: {
          'colors': <String>[],
          'color_identity': <String>[],
        },
      );

      final coloredCard = makeItem(
        id: 'counterspell',
        name: 'Counterspell',
        dynamicData: {
          'colors': ['U'],
          'color_identity': ['U'],
        },
      );

      // Filter: colors = {'C'}, mode = exactly
      final filterExactC = const MtgFilterState(
        colors: {'C'},
        colorMatchMode: ColorMatchMode.exactly,
      );
      expect(filterExactC.matches(colorlessCard), isTrue);
      expect(filterExactC.matches(coloredCard), isFalse);

      // Filter: colors = {'C'}, mode = atMost
      final filterAtMostC = const MtgFilterState(
        colors: {'C'},
        colorMatchMode: ColorMatchMode.atMost,
      );
      expect(filterAtMostC.matches(colorlessCard), isTrue);
      expect(filterAtMostC.matches(coloredCard), isFalse);

      // Filter: colors = {'U'}, mode = atMost
      // In MTG, a colorless card has at most {U} (it has 0 colors, which is a subset of {U})
      final filterAtMostU = const MtgFilterState(
        colors: {'U'},
        colorMatchMode: ColorMatchMode.atMost,
      );
      expect(filterAtMostU.matches(colorlessCard), isTrue);
      expect(filterAtMostU.matches(coloredCard), isTrue);

      // Filter: colors = {'U'}, mode = commander
      // In commander, colorless cards can be played in a mono-U commander deck
      final filterCommanderU = const MtgFilterState(
        colors: {'U'},
        colorMatchMode: ColorMatchMode.commander,
      );
      expect(filterCommanderU.matches(colorlessCard), isTrue);
      expect(filterCommanderU.matches(coloredCard), isTrue);
    });

    test('3.5 activeCount and reset() accuracy across all filter dimensions', () {
      const empty = MtgFilterState();
      expect(empty.isActive, isFalse);
      expect(empty.activeCount, equals(0));

      // Test individual activations
      expect(empty.copyWith(colors: {'W'}).activeCount, equals(1));
      expect(empty.copyWith(colorCountRange: const RangeValues(1, 5)).activeCount, equals(1));
      expect(empty.copyWith(colorCountRange: const RangeValues(0, 4)).activeCount, equals(1));
      expect(empty.copyWith(colorCountRange: const RangeValues(0, 5)).activeCount, equals(0)); // default
      expect(empty.copyWith(cmcRange: const RangeValues(2, 16)).activeCount, equals(1));
      expect(empty.copyWith(cmcRange: const RangeValues(0, 10)).activeCount, equals(1));
      expect(empty.copyWith(cmcRange: const RangeValues(0, 16)).activeCount, equals(0)); // default
      expect(empty.copyWith(typeLine: 'Creature').activeCount, equals(1));
      expect(empty.copyWith(typeLine: '   ').activeCount, equals(0));
      expect(empty.copyWith(oracleTextClauses: ['draw a card']).activeCount, equals(1));
      expect(empty.copyWith(oracleTextClauses: ['   ', '']).activeCount, equals(0));
      expect(empty.copyWith(manaCost: '{1}{U}').activeCount, equals(1));
      expect(empty.copyWith(setCode: 'MH3').activeCount, equals(1));
      expect(empty.copyWith(rarities: {'mythic'}).activeCount, equals(1));
      expect(empty.copyWith(layouts: {'transform'}).activeCount, equals(1));
      expect(empty.copyWith(finishes: {'foil'}).activeCount, equals(1));
      expect(empty.copyWith(conditions: {'NM'}).activeCount, equals(1));
      expect(empty.copyWith(languages: {'EN'}).activeCount, equals(1));
      expect(
        empty.copyWith(
          statFilters: [
            const MtgStatFilter(stat: 'power', operator: '>', value: '3'),
            const MtgStatFilter(stat: 'toughness', operator: '<', value: '2'),
          ],
        ).activeCount,
        equals(2),
      );
      expect(empty.copyWith(isReserved: true).activeCount, equals(1));
      expect(empty.copyWith(isUniversesBeyond: true).activeCount, equals(1));
      expect(empty.copyWith(isPromo: false).activeCount, equals(1));
      expect(empty.copyWith(isReprint: true).activeCount, equals(1));
      expect(empty.copyWith(isAltered: true).activeCount, equals(1));
      expect(empty.copyWith(isMisprint: true).activeCount, equals(1));
      expect(empty.copyWith(isGraded: true).activeCount, equals(1));
      expect(empty.copyWith(isSigned: true).activeCount, equals(1));

      // Reset restores empty state
      final full = empty.copyWith(
        colors: {'W', 'U'},
        typeLine: 'Angel',
        setCode: 'MH3',
        rarities: {'mythic'},
        isUniversesBeyond: true,
      );
      expect(full.isActive, isTrue);
      expect(full.activeCount, equals(5));

      final resetState = full.reset();
      expect(resetState.isActive, isFalse);
      expect(resetState.activeCount, equals(0));
    });
  });

  group('Challenger M6 Group 4: VaultDao Dual-Stage SQL Pushdown & Starvation Tests', () {
    late AppDatabase db;
    late VaultDao dao;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      dao = db.vaultDao;
      await dao.delete(dao.vaultItems).go();
    });

    tearDown(() async {
      await db.close();
    });

    VaultItem makeDaoItem({
      required String id,
      required String name,
      String collectionType = 'mtg',
      String setOrSeries = 'MH3',
      String? flavorName,
      int quantity = 1,
      String condition = 'NM',
      bool isGraded = false,
      bool isAltered = false,
      bool isMisprint = false,
      bool isSigned = false,
      DateTime? acquiredDate,
      Map<String, dynamic>? dynamicDataMap,
    }) {
      return VaultItem(
        id: id,
        collectionType: collectionType,
        name: name,
        flavorName: flavorName,
        setOrSeries: setOrSeries,
        imageUrl: 'https://cards.scryfall.io/test/$id.jpg',
        acquiredPrice: 5.0,
        acquiredDate: acquiredDate ?? DateTime(2026, 1, 1),
        quantity: quantity,
        condition: condition,
        isGraded: isGraded,
        isAltered: isAltered,
        isMisprint: isMisprint,
        isSigned: isSigned,
        personalNotes: null,
        primaryBinderId: null,
        currentMarketPrice: 10.0,
        lastPriceUpdate: DateTime.now(),
        dynamicData: jsonEncode(dynamicDataMap ?? {}),
      );
    }

    test('4.1 Deep pagination starvation prevention: 200 items with only 5 scattered matches', () async {
      final baseDate = DateTime(2026, 1, 1);

      // Insert 200 cards where ONLY indices 20, 60, 100, 140, 180 match
      // an in-memory-only filter (power = 7, colors = {'G'})
      for (int i = 1; i <= 200; i++) {
        final isMatch = (i == 20 || i == 60 || i == 100 || i == 140 || i == 180);
        await dao.into(dao.vaultItems).insert(
          makeDaoItem(
            id: 'card-${i.toString().padLeft(3, '0')}',
            name: 'Card $i',
            acquiredDate: baseDate.add(Duration(days: 300 - i)),
            dynamicDataMap: {
              'power': isMatch ? '7' : '2',
              'toughness': isMatch ? '7' : '2',
              'colors': isMatch ? ['G'] : ['U'],
              'cmc': isMatch ? 6.0 : 2.0,
            },
          ),
        );
      }

      final filter = const MtgFilterState(
        colors: {'G'},
        colorMatchMode: ColorMatchMode.exactly,
        statFilters: [
          MtgStatFilter(stat: 'power', operator: '=', value: '7'),
        ],
      );

      // Page 1: limit 2, offset 0 -> matches cards 20 and 60
      final page1 = await dao.getItemsByCollection('mtg', mtgFilter: filter, limit: 2, offset: 0);
      expect(page1.length, equals(2));
      expect(page1[0].id, equals('card-020'));
      expect(page1[1].id, equals('card-060'));

      // Page 2: limit 2, offset 2 -> matches cards 100 and 140
      final page2 = await dao.getItemsByCollection('mtg', mtgFilter: filter, limit: 2, offset: 2);
      expect(page2.length, equals(2));
      expect(page2[0].id, equals('card-100'));
      expect(page2[1].id, equals('card-140'));

      // Page 3: limit 2, offset 4 -> matches card 180
      final page3 = await dao.getItemsByCollection('mtg', mtgFilter: filter, limit: 2, offset: 4);
      expect(page3.length, equals(1));
      expect(page3[0].id, equals('card-180'));

      // Page 4: offset beyond all matches -> empty
      final page4 = await dao.getItemsByCollection('mtg', mtgFilter: filter, limit: 2, offset: 6);
      expect(page4, isEmpty);
    });

    test('4.2 Reactive stream pagination under continuous updates', () async {
      final baseDate = DateTime(2026, 1, 1);

      // Insert 20 initial cards, 5 matching
      for (int i = 1; i <= 20; i++) {
        await dao.into(dao.vaultItems).insert(
          makeDaoItem(
            id: 'stream-$i',
            name: 'Stream $i',
            acquiredDate: baseDate.add(Duration(days: 50 - i)),
            dynamicDataMap: {
              'rarity': (i % 4 == 0) ? 'mythic' : 'common',
            },
          ),
        );
      }

      final filter = const MtgFilterState(rarities: {'mythic'});
      final stream = dao.watchItemsByCollection('mtg', mtgFilter: filter, limit: 10);

      // First emission has 5 mythics (4, 8, 12, 16, 20)
      final initialItems = await stream.first;
      expect(initialItems.length, equals(5));

      // Insert 2 new mythics
      await dao.into(dao.vaultItems).insert(
        makeDaoItem(
          id: 'stream-new-1',
          name: 'New Mythic 1',
          acquiredDate: baseDate.add(const Duration(days: 60)),
          dynamicDataMap: {'rarity': 'mythic'},
        ),
      );

      final updatedItems = await stream.first;
      expect(updatedItems.length, equals(6));
      expect(updatedItems.first.id, equals('stream-new-1'));
    });

    test('4.3 Search query injection resistance and special character handling', () async {
      await dao.into(dao.vaultItems).insert(
        makeDaoItem(
          id: 'card-quote',
          name: 'Urza\'s Mine',
          flavorName: 'Mining in "Tomb"',
          dynamicDataMap: {'oracle_text': 'Add {C}.'},
        ),
      );
      await dao.into(dao.vaultItems).insert(
        makeDaoItem(
          id: 'card-percent',
          name: '100% Guaranteed Win',
          dynamicDataMap: {'oracle_text': 'Win the game.'},
        ),
      );
      await dao.into(dao.vaultItems).insert(
        makeDaoItem(
          id: 'card-emoji',
          name: 'Fire Dragon 🔥⚔️',
          dynamicDataMap: {'oracle_text': 'Fly and breathe fire.'},
        ),
      );

      // SQL injection pattern
      final resInjection = await dao.getItemsByCollection('mtg', searchQuery: '\' OR 1=1 --');
      expect(resInjection, isEmpty);

      // Literal quote search
      final resQuote = await dao.getItemsByCollection('mtg', searchQuery: 'Urza\'s');
      expect(resQuote.length, equals(1));
      expect(resQuote.first.name, equals('Urza\'s Mine'));

      // Percent literal search
      final resPercent = await dao.getItemsByCollection('mtg', searchQuery: '100%');
      expect(resPercent.length, equals(1));
      expect(resPercent.first.id, equals('card-percent'));

      // Emoji search
      final resEmoji = await dao.getItemsByCollection('mtg', searchQuery: '🔥⚔️');
      expect(resEmoji.length, equals(1));
      expect(resEmoji.first.id, equals('card-emoji'));
    });

    test('4.4 Secret Lair Drop keyword and alias search resilience', () async {
      await dao.into(dao.vaultItems).insert(
        makeDaoItem(
          id: 'sld-1',
          name: 'Mox Opal',
          setOrSeries: 'Secret Lair Drop',
          dynamicDataMap: {'set': 'sld', 'set_code': 'sld'},
        ),
      );
      await dao.into(dao.vaultItems).insert(
        makeDaoItem(
          id: 'sld-2',
          name: 'Lightning Bolt',
          setOrSeries: 'SLD',
          dynamicDataMap: {'set': 'sld', 'set_code': 'sld'},
        ),
      );
      await dao.into(dao.vaultItems).insert(
        makeDaoItem(
          id: 'other-1',
          name: 'Birds of Paradise',
          setOrSeries: 'Modern Horizons 3',
          dynamicDataMap: {'set': 'mh3', 'set_code': 'mh3'},
        ),
      );

      // Search 'sld'
      final resSld = await dao.getItemsByCollection('mtg', searchQuery: 'sld');
      expect(resSld.length, equals(2));
      expect(resSld.any((c) => c.id == 'sld-1'), isTrue);
      expect(resSld.any((c) => c.id == 'sld-2'), isTrue);

      // Search 'Secret Lair'
      final resSecretLair = await dao.getItemsByCollection('mtg', searchQuery: 'Secret Lair');
      expect(resSecretLair.length, equals(2));

      // Filter setCode: 'sld'
      final filterSld = const MtgFilterState(setCode: 'sld');
      final resFiltered = await dao.getItemsByCollection('mtg', mtgFilter: filterSld);
      expect(resFiltered.length, equals(2));
    });
  });
}
