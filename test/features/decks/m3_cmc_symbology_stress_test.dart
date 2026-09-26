// Copyright (c) 2026 Countr. All rights reserved.
// Empirical stress test suite for Mana Curve CMC, MTG CR 202.3e, MTG CR 709.4,
// dynamicData parsing resilience, and MTG SVG Symbology invariants.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/features/decks/data/mock_deck_data.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/decks/presentation/widgets/inline_deck_analytics_card.dart';
import 'package:countr/features/symbology/data/scryfall_symbol_catalog.dart';
import 'package:countr/features/symbology/presentation/widgets/mana_symbol_icon.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ===========================================================================
  // GROUP 1: Twobrid Mana Symbols (MTG CR 202.3e)
  // ===========================================================================
  group('MTG CR 202.3e - Twobrid Mana Values & Invariants', () {
    test('Individual twobrids evaluate to exactly 2.0 CMC regardless of payment option', () {
      expect(ScryfallSymbolCatalog.calculateManaValue('{2/W}'), equals(2.0));
      expect(ScryfallSymbolCatalog.calculateManaValue('{2/U}'), equals(2.0));
      expect(ScryfallSymbolCatalog.calculateManaValue('{2/B}'), equals(2.0));
      expect(ScryfallSymbolCatalog.calculateManaValue('{2/R}'), equals(2.0));
      expect(ScryfallSymbolCatalog.calculateManaValue('{2/G}'), equals(2.0));
    });

    test('Transposed twobrid aliases evaluate to exactly 2.0 CMC', () {
      expect(ScryfallSymbolCatalog.calculateManaValue('{W/2}'), equals(2.0));
      expect(ScryfallSymbolCatalog.calculateManaValue('{U/2}'), equals(2.0));
      expect(ScryfallSymbolCatalog.calculateManaValue('{B/2}'), equals(2.0));
      expect(ScryfallSymbolCatalog.calculateManaValue('{R/2}'), equals(2.0));
      expect(ScryfallSymbolCatalog.calculateManaValue('{G/2}'), equals(2.0));
    });

    test('All 5 twobrids combined {2/W}{2/U}{2/B}{2/R}{2/G} evaluate to total CMC = 10.0', () {
      const reaperKingCost = '{2/W}{2/U}{2/B}{2/R}{2/G}';
      expect(ScryfallSymbolCatalog.calculateManaValue(reaperKingCost), equals(10.0));

      final cardData = {
        'name': 'Reaper King',
        'type_line': 'Artifact Creature — Scarecrow',
        'mana_cost': reaperKingCost,
      };
      expect(ScryfallSymbolCatalog.resolveCardCmc(cardData), equals(10.0));
    });

    test('Multiple identical twobrids (Beseech the Queen, Spectral Procession) calculate accurately', () {
      // Beseech the Queen: {2/B}{2/B}{2/B} -> 6.0
      expect(ScryfallSymbolCatalog.calculateManaValue('{2/B}{2/B}{2/B}'), equals(6.0));
      // Spectral Procession: {2/W}{2/W}{2/W} -> 6.0
      expect(ScryfallSymbolCatalog.calculateManaValue('{2/W}{2/W}{2/W}'), equals(6.0));
      // Flame Javelin: {2/R}{2/R}{2/R} -> 6.0
      expect(ScryfallSymbolCatalog.calculateManaValue('{2/R}{2/R}{2/R}'), equals(6.0));
    });

    test('Twobrid cards contribute color devotion to their colored component but not to 2', () {
      final items = [
        {
          'deck_quantity': 1,
          'dynamic_data': jsonEncode({
            'name': 'Reaper King',
            'type_line': 'Artifact Creature — Scarecrow',
            'mana_cost': '{2/W}{2/U}{2/B}{2/R}{2/G}',
          }),
        },
      ];

      final analytics = MockDeckData.computeAnalyticsFromItems(items);
      expect(analytics.manaCurve[10], equals(1));
      expect(analytics.colorDevotion['W'], equals(1));
      expect(analytics.colorDevotion['U'], equals(1));
      expect(analytics.colorDevotion['B'], equals(1));
      expect(analytics.colorDevotion['R'], equals(1));
      expect(analytics.colorDevotion['G'], equals(1));
      expect(analytics.colorDevotion['2'], isNull);
    });
  });

  // ===========================================================================
  // GROUP 2: Hybrid & Phyrexian Mana Symbols
  // ===========================================================================
  group('Hybrid & Phyrexian Mana CMC Invariants', () {
    test('Hybrid combinations {W/U}{B/R} evaluate to total CMC = 2.0', () {
      expect(ScryfallSymbolCatalog.calculateManaValue('{W/U}{B/R}'), equals(2.0));
    });

    test('All 10 guild hybrids evaluate to CMC = 1.0 each', () {
      final guildHybrids = [
        '{W/U}', '{W/B}', '{B/R}', '{B/G}', '{U/B}',
        '{U/R}', '{R/G}', '{R/W}', '{G/W}', '{G/U}',
      ];
      for (final sym in guildHybrids) {
        expect(ScryfallSymbolCatalog.calculateManaValue(sym), equals(1.0),
            reason: '$sym must have CMC 1.0');
      }
      expect(ScryfallSymbolCatalog.calculateManaValue(guildHybrids.join()), equals(10.0));
    });

    test('Colorless hybrids {C/W}, {C/U}, {C/B}, {C/R}, {C/G} evaluate to CMC = 1.0', () {
      final colorlessHybrids = ['{C/W}', '{C/U}', '{C/B}', '{C/R}', '{C/G}'];
      for (final sym in colorlessHybrids) {
        expect(ScryfallSymbolCatalog.calculateManaValue(sym), equals(1.0));
      }
    });

    test('Phyrexian mana {W/P} and all monocolor/colorless Phyrexians evaluate to CMC = 1.0', () {
      expect(ScryfallSymbolCatalog.calculateManaValue('{W/P}'), equals(1.0));
      expect(ScryfallSymbolCatalog.calculateManaValue('{U/P}'), equals(1.0));
      expect(ScryfallSymbolCatalog.calculateManaValue('{B/P}'), equals(1.0));
      expect(ScryfallSymbolCatalog.calculateManaValue('{R/P}'), equals(1.0));
      expect(ScryfallSymbolCatalog.calculateManaValue('{G/P}'), equals(1.0));
      expect(ScryfallSymbolCatalog.calculateManaValue('{C/P}'), equals(1.0));
      expect(ScryfallSymbolCatalog.calculateManaValue('{H}'), equals(1.0));
    });

    test('Hybrid Phyrexian mana symbols evaluate to CMC = 1.0', () {
      expect(ScryfallSymbolCatalog.calculateManaValue('{B/G/P}'), equals(1.0));
      expect(ScryfallSymbolCatalog.calculateManaValue('{W/U/P}'), equals(1.0));
      expect(ScryfallSymbolCatalog.calculateManaValue('{R/W/P}'), equals(1.0));
      expect(ScryfallSymbolCatalog.calculateManaValue('{G/U/P}'), equals(1.0));
    });

    test('Phyrexian staple cards evaluate accurate CMCs', () {
      // Gitaxian Probe: {U/P} -> 1.0
      expect(ScryfallSymbolCatalog.calculateManaValue('{U/P}'), equals(1.0));
      // Dismember: {1}{B/P}{B/P} -> 3.0
      expect(ScryfallSymbolCatalog.calculateManaValue('{1}{B/P}{B/P}'), equals(3.0));
      // Birthing Pod: {3}{G/P} -> 4.0
      expect(ScryfallSymbolCatalog.calculateManaValue('{3}{G/P}'), equals(4.0));
      // Mental Misstep: {U/P} -> 1.0
      expect(ScryfallSymbolCatalog.calculateManaValue('{U/P}'), equals(1.0));
      // Karrthus / Tamiyo, Compleated Sage: {2}{G}{G/U/P}{U} -> 5.0
      expect(ScryfallSymbolCatalog.calculateManaValue('{2}{G}{G/U/P}{U}'), equals(5.0));
    });
  });

  // ===========================================================================
  // GROUP 3: Variable Mana Costs ({X}, {Y}, {Z})
  // ===========================================================================
  group('Variable Mana Costs ({X}, {Y}, {Z}) CMC Invariants', () {
    test('{X}{X}{R} evaluates to CMC = 1.0 in deck/library zone', () {
      expect(ScryfallSymbolCatalog.calculateManaValue('{X}{X}{R}'), equals(1.0));
    });

    test('Multiple variables {X}{Y}{Z}{U}{G} evaluate variable symbols to 0.0', () {
      expect(ScryfallSymbolCatalog.calculateManaValue('{X}{Y}{Z}{U}{G}'), equals(2.0));
    });

    test('Walking Ballista {X}{X} evaluates to CMC = 0.0', () {
      final ballistaData = {
        'name': 'Walking Ballista',
        'type_line': 'Artifact Creature — Construct',
        'mana_cost': '{X}{X}',
        'cmc': 0,
      };
      expect(ScryfallSymbolCatalog.resolveCardCmc(ballistaData), equals(0.0));
    });

    test('Crackle with Power {X}{X}{X}{R}{R} evaluates to CMC = 2.0', () {
      expect(ScryfallSymbolCatalog.calculateManaValue('{X}{X}{X}{R}{R}'), equals(2.0));
    });
  });

  // ===========================================================================
  // GROUP 4: Split Cards (MTG CR 709.4) & Aftermath Cards
  // ===========================================================================
  group('MTG CR 709.4 - Split Cards & Aftermath Sum of Faces', () {
    test('Fire // Ice evaluates to CMC = 4.0 by summing faces (Fire {1}{R} + Ice {1}{U})', () {
      // Scenario A: Missing top-level cmc, calculated from card_faces
      final fireIceNoCmc = {
        'name': 'Fire // Ice',
        'layout': 'split',
        'card_faces': [
          {'name': 'Fire', 'mana_cost': '{1}{R}', 'cmc': 2.0},
          {'name': 'Ice', 'mana_cost': '{1}{U}', 'cmc': 2.0},
        ],
      };
      expect(ScryfallSymbolCatalog.resolveCardCmc(fireIceNoCmc), equals(4.0));

      // Scenario B: With official Scryfall top-level cmc
      final fireIceOfficial = {
        'name': 'Fire // Ice',
        'layout': 'split',
        'cmc': 4.0,
        'card_faces': [
          {'name': 'Fire', 'mana_cost': '{1}{R}'},
          {'name': 'Ice', 'mana_cost': '{1}{U}'},
        ],
      };
      expect(ScryfallSymbolCatalog.resolveCardCmc(fireIceOfficial), equals(4.0));

      // Scenario C: Combined mana_cost string "{1}{R} // {1}{U}"
      final fireIceCombinedString = {
        'name': 'Fire // Ice',
        'mana_cost': '{1}{R} // {1}{U}',
      };
      expect(ScryfallSymbolCatalog.resolveCardCmc(fireIceCombinedString), equals(4.0));
    });

    test('Boom // Bust evaluates to CMC = 8.0 (Boom {1}{R} + Bust {5}{R})', () {
      final boomBust = {
        'name': 'Boom // Bust',
        'layout': 'split',
        'card_faces': [
          {'name': 'Boom', 'mana_cost': '{1}{R}'},
          {'name': 'Bust', 'mana_cost': '{5}{R}'},
        ],
      };
      expect(ScryfallSymbolCatalog.resolveCardCmc(boomBust), equals(8.0));
    });

    test('Wear // Tear evaluates to CMC = 3.0 (Wear {1}{R} + Tear {W})', () {
      final wearTear = {
        'name': 'Wear // Tear',
        'layout': 'split',
        'card_faces': [
          {'name': 'Wear', 'mana_cost': '{1}{R}'},
          {'name': 'Tear', 'mana_cost': '{W}'},
        ],
      };
      expect(ScryfallSymbolCatalog.resolveCardCmc(wearTear), equals(3.0));
    });

    test('Aftermath cards (Destined // Lead) evaluate to sum of both faces', () {
      final destinedLead = {
        'name': 'Destined // Lead',
        'layout': 'aftermath',
        'card_faces': [
          {'name': 'Destined', 'mana_cost': '{1}{B}'},
          {'name': 'Lead', 'mana_cost': '{3}{G}'},
        ],
      };
      // Destined (2.0) + Lead (4.0) = 6.0
      expect(ScryfallSymbolCatalog.resolveCardCmc(destinedLead), equals(6.0));
    });

    test('Aftermath card Cut // Ribbons ({1}{R} // {X}{B}{B}) evaluates to CMC = 4.0', () {
      final cutRibbons = {
        'name': 'Cut // Ribbons',
        'layout': 'aftermath',
        'card_faces': [
          {'name': 'Cut', 'mana_cost': '{1}{R}'},
          {'name': 'Ribbons', 'mana_cost': '{X}{B}{B}'},
        ],
      };
      // Cut (2.0) + Ribbons (2.0) = 4.0
      expect(ScryfallSymbolCatalog.resolveCardCmc(cutRibbons), equals(4.0));
    });
  });

  // ===========================================================================
  // GROUP 5: Adventure Cards (MTG CR 716.4)
  // ===========================================================================
  group('MTG CR 716.4 - Adventure Cards Normal Creature Face Precedence', () {
    test('Brazen Borrower // Petty Theft evaluates to creature face CMC = 3.0', () {
      final brazenBorrower = {
        'name': 'Brazen Borrower // Petty Theft',
        'layout': 'adventure',
        'cmc': 3.0,
        'card_faces': [
          {
            'name': 'Brazen Borrower',
            'type_line': 'Creature — Faerie Rogue',
            'mana_cost': '{1}{U}{U}',
            'cmc': 3.0,
          },
          {
            'name': 'Petty Theft',
            'type_line': 'Instant — Adventure',
            'mana_cost': '{1}{U}',
            'cmc': 2.0,
          },
        ],
      };
      expect(ScryfallSymbolCatalog.resolveCardCmc(brazenBorrower), equals(3.0));
      expect(ScryfallSymbolCatalog.isLandCard(brazenBorrower), isFalse);
    });

    test('Adventure card with missing top-level cmc defaults to front face CMC (not sum)', () {
      final murderousRider = {
        'name': 'Murderous Rider // Swift End',
        'layout': 'adventure',
        'card_faces': [
          {
            'name': 'Murderous Rider',
            'type_line': 'Creature — Zombie Knight',
            'mana_cost': '{1}{B}{B}',
          },
          {
            'name': 'Swift End',
            'type_line': 'Instant — Adventure',
            'mana_cost': '{1}{B}{B}',
          },
        ],
      };
      // Murderous Rider face cost is {1}{B}{B} = 3.0 (NOT 6.0 sum!)
      expect(ScryfallSymbolCatalog.resolveCardCmc(murderousRider), equals(3.0));
    });

    test('Bonecrusher Giant // Stomp evaluates to creature CMC = 3.0', () {
      final bonecrusher = {
        'name': 'Bonecrusher Giant // Stomp',
        'layout': 'adventure',
        'card_faces': [
          {
            'name': 'Bonecrusher Giant',
            'type_line': 'Creature — Giant Berserker',
            'mana_cost': '{2}{R}',
          },
          {
            'name': 'Stomp',
            'type_line': 'Instant — Adventure',
            'mana_cost': '{1}{R}',
          },
        ],
      };
      expect(ScryfallSymbolCatalog.resolveCardCmc(bonecrusher), equals(3.0));
    });
  });

  // ===========================================================================
  // GROUP 6: Modal Double-Faced Cards (MDFCs) (MTG CR 712.8a)
  // ===========================================================================
  group('MTG CR 712.8a - MDFCs Front Face Characteristics & Land Classification', () {
    test('Turntimber Symbiosis // Turntimber, Serpentine Wood: front face CMC = 7.0 and NOT land', () {
      final turntimber = {
        'name': 'Turntimber Symbiosis // Turntimber, Serpentine Wood',
        'layout': 'modal_dfc',
        'type_line': 'Sorcery // Land',
        'card_faces': [
          {
            'name': 'Turntimber Symbiosis',
            'type_line': 'Sorcery',
            'mana_cost': '{4}{G}{G}{G}',
            'cmc': 7.0,
          },
          {
            'name': 'Turntimber, Serpentine Wood',
            'type_line': 'Land',
            'mana_cost': '',
            'cmc': 0.0,
          },
        ],
      };

      // Under CR 712.8a, front face Sorcery determines characteristics in library/deck
      expect(ScryfallSymbolCatalog.resolveCardCmc(turntimber), equals(7.0));
      expect(ScryfallSymbolCatalog.isLandCard(turntimber), isFalse,
          reason: 'Front face is a Sorcery, so card must NOT be classified as land');

      // Verify DeckAnalytics places Turntimber in bucket 7
      final items = [
        {
          'deck_quantity': 1,
          'dynamic_data': jsonEncode(turntimber),
        },
      ];
      final analytics = MockDeckData.computeAnalyticsFromItems(items);
      expect(analytics.manaCurve[7], equals(1));
      expect(analytics.manaCurve[0] ?? 0, equals(0));
    });

    test('Sea Gate Restoration // Sea Gate, Reborn: front face CMC = 7.0, NOT land', () {
      final seaGate = {
        'name': 'Sea Gate Restoration // Sea Gate, Reborn',
        'layout': 'modal_dfc',
        'type_line': 'Sorcery // Land',
        'card_faces': [
          {
            'name': 'Sea Gate Restoration',
            'type_line': 'Sorcery',
            'mana_cost': '{4}{U}{U}{U}',
            'cmc': 7.0,
          },
          {
            'name': 'Sea Gate, Reborn',
            'type_line': 'Land',
            'mana_cost': '',
            'cmc': 0.0,
          },
        ],
      };
      expect(ScryfallSymbolCatalog.resolveCardCmc(seaGate), equals(7.0));
      expect(ScryfallSymbolCatalog.isLandCard(seaGate), isFalse);
    });

    test('Barkchannel Pathway // Tidechannel Pathway: front face IS land -> classified as land', () {
      final barkchannel = {
        'name': 'Barkchannel Pathway // Tidechannel Pathway',
        'layout': 'modal_dfc',
        'type_line': 'Land // Land',
        'card_faces': [
          {
            'name': 'Barkchannel Pathway',
            'type_line': 'Land',
            'mana_cost': '',
            'cmc': 0.0,
          },
          {
            'name': 'Tidechannel Pathway',
            'type_line': 'Land',
            'mana_cost': '',
            'cmc': 0.0,
          },
        ],
      };
      expect(ScryfallSymbolCatalog.isLandCard(barkchannel), isTrue);

      final items = [
        {
          'deck_quantity': 1,
          'dynamic_data': jsonEncode(barkchannel),
        },
      ];
      final analytics = MockDeckData.computeAnalyticsFromItems(items);
      // Lands must be completely excluded from spell curve
      expect(analytics.manaCurve.isEmpty, isTrue);
    });

    test('Transforming DFCs (Bloodline Keeper // Lord of Lineage) use front face', () {
      final bloodlineKeeper = {
        'name': 'Bloodline Keeper // Lord of Lineage',
        'layout': 'transform',
        'type_line': 'Creature — Vampire // Creature — Vampire',
        'card_faces': [
          {
            'name': 'Bloodline Keeper',
            'type_line': 'Creature — Vampire',
            'mana_cost': '{2}{B}{B}',
            'cmc': 4.0,
          },
          {
            'name': 'Lord of Lineage',
            'type_line': 'Creature — Vampire',
            'mana_cost': '',
            'cmc': 0.0,
          },
        ],
      };
      expect(ScryfallSymbolCatalog.resolveCardCmc(bloodlineKeeper), equals(4.0));
      expect(ScryfallSymbolCatalog.isLandCard(bloodlineKeeper), isFalse);
    });
  });

  // ===========================================================================
  // GROUP 7: Non-Land 0-Cost Spell Preservation vs Land Exclusion
  // ===========================================================================
  group('Non-Land 0-Cost Spell Preservation vs Land Exclusion', () {
    test('Preserves all 0-cost non-land spells in bucket 0 and excludes all lands', () {
      final nonLandZeroSpells = [
        {'name': 'Lotus Petal', 'type_line': 'Artifact', 'mana_cost': '{0}', 'cmc': 0},
        {'name': 'Pact of Negation', 'type_line': 'Instant', 'mana_cost': '{0}', 'cmc': 0},
        {'name': 'Memnite', 'type_line': 'Artifact Creature — Construct', 'mana_cost': '{0}', 'cmc': 0},
        {'name': 'Mox Amber', 'type_line': 'Legendary Artifact', 'mana_cost': '{0}', 'cmc': 0},
        {'name': 'Ornithopter', 'type_line': 'Artifact Creature — Thopter', 'mana_cost': '{0}', 'cmc': 0},
        {'name': "Mishra's Bauble", 'type_line': 'Artifact', 'mana_cost': '{0}', 'cmc': 0},
        {'name': "Urza's Bauble", 'type_line': 'Artifact', 'mana_cost': '{0}', 'cmc': 0},
        {'name': 'Zuran Orb', 'type_line': 'Artifact', 'mana_cost': '{0}', 'cmc': 0},
        {'name': 'Everflowing Chalice', 'type_line': 'Artifact', 'mana_cost': '{0}', 'cmc': 0},
      ];

      final lands = [
        {'name': 'Plains', 'type_line': 'Basic Land — Plains', 'cmc': 0},
        {'name': 'Island', 'type_line': 'Basic Land — Island', 'cmc': 0},
        {'name': 'Swamp', 'type_line': 'Basic Land — Swamp', 'cmc': 0},
        {'name': 'Mountain', 'type_line': 'Basic Land — Mountain', 'cmc': 0},
        {'name': 'Forest', 'type_line': 'Basic Land — Forest', 'cmc': 0},
        {'name': 'Command Tower', 'type_line': 'Land', 'cmc': 0},
        {'name': 'Urborg, Tomb of Yawgmoth', 'type_line': 'Legendary Land', 'cmc': 0},
        {'name': 'Dryad Arbor', 'type_line': 'Land Creature — Forest Dryad', 'cmc': 0},
        {'name': 'Boseiju, Who Endures', 'type_line': 'Legendary Land', 'cmc': 0},
        {'name': 'Ancient Tomb', 'type_line': 'Land', 'cmc': 0},
      ];

      // Verify each non-land is not a land
      for (final spell in nonLandZeroSpells) {
        expect(ScryfallSymbolCatalog.isLandCard(spell), isFalse,
            reason: '${spell['name']} should NOT be considered a land');
        expect(ScryfallSymbolCatalog.resolveCardCmc(spell), equals(0.0));
      }

      // Verify each land is identified as a land
      for (final land in lands) {
        expect(ScryfallSymbolCatalog.isLandCard(land), isTrue,
            reason: '${land['name']} MUST be classified as a land');
      }

      // Build mock deck items with 1 copy of each non-land and 4 copies of each land
      final deckItems = <Map<String, dynamic>>[];
      for (final spell in nonLandZeroSpells) {
        deckItems.add({
          'deck_quantity': 1,
          'dynamic_data': jsonEncode(spell),
        });
      }
      for (final land in lands) {
        deckItems.add({
          'deck_quantity': 4,
          'dynamic_data': jsonEncode(land),
        });
      }

      final analytics = MockDeckData.computeAnalyticsFromItems(deckItems);

      // Bucket 0 MUST contain exactly the 9 non-land spells, 0 from the 40 lands
      expect(analytics.manaCurve[0], equals(9),
          reason: 'Mana curve bucket 0 must contain exactly the 9 non-land 0-cost spells');
      // No spells in buckets 1-16
      for (int i = 1; i <= 16; i++) {
        expect(analytics.manaCurve[i], isNull);
      }
    });

    test('Dryad Arbor (Land Creature) is strictly excluded from spell mana curve', () {
      final dryadArbor = {
        'name': 'Dryad Arbor',
        'type_line': 'Land Creature — Forest Dryad',
        'cmc': 0,
      };
      expect(ScryfallSymbolCatalog.isLandCard(dryadArbor), isTrue);

      final items = [
        {
          'deck_quantity': 1,
          'dynamic_data': jsonEncode(dryadArbor),
        },
      ];
      final analytics = MockDeckData.computeAnalyticsFromItems(items);
      expect(analytics.manaCurve[0] ?? 0, equals(0));
    });
  });

  // ===========================================================================
  // GROUP 8: String vs Num dynamicData Coercion & Resilient Parsing Stress
  // ===========================================================================
  group('String vs Num dynamicData Coercion & Stress Parsing', () {
    test('Parses cmc formatted as string ("0", "3.5", "4", " 6 ")', () {
      expect(ScryfallSymbolCatalog.resolveCardCmc({'cmc': '0'}), equals(0.0));
      expect(ScryfallSymbolCatalog.resolveCardCmc({'cmc': '3.5'}), equals(3.5));
      expect(ScryfallSymbolCatalog.resolveCardCmc({'cmc': '4'}), equals(4.0));
      expect(ScryfallSymbolCatalog.resolveCardCmc({'cmc': ' 6 '}), equals(6.0));
      expect(ScryfallSymbolCatalog.resolveCardCmc({'cmc': '12.0'}), equals(12.0));
    });

    test('Parses cmc formatted as num (int or double: 0, 4, 3.5, 10.0)', () {
      expect(ScryfallSymbolCatalog.resolveCardCmc({'cmc': 0}), equals(0.0));
      expect(ScryfallSymbolCatalog.resolveCardCmc({'cmc': 4}), equals(4.0));
      expect(ScryfallSymbolCatalog.resolveCardCmc({'cmc': 3.5}), equals(3.5));
      expect(ScryfallSymbolCatalog.resolveCardCmc({'cmc': 10.0}), equals(10.0));
    });

    test('Handles cmc: null gracefully by falling back to mana_cost or 0.0', () {
      expect(ScryfallSymbolCatalog.resolveCardCmc({'cmc': null, 'mana_cost': '{2}{U}'}), equals(3.0));
      expect(ScryfallSymbolCatalog.resolveCardCmc({'cmc': null, 'mana_cost': ''}), equals(0.0));
      expect(ScryfallSymbolCatalog.resolveCardCmc({'cmc': null}), equals(0.0));
    });

    test('Handles malformed, invalid, or corrupt cmc strings without throwing', () {
      expect(ScryfallSymbolCatalog.resolveCardCmc({'cmc': 'invalid', 'mana_cost': '{3}{R}'}), equals(4.0));
      expect(ScryfallSymbolCatalog.resolveCardCmc({'cmc': 'not_a_number'}), equals(0.0));
      expect(ScryfallSymbolCatalog.resolveCardCmc({'cmc': ''}), equals(0.0));
      expect(ScryfallSymbolCatalog.resolveCardCmc({'cmc': '   '}), equals(0.0));
    });

    test('Deck analytics gracefully recovers from corrupted dynamicData JSON strings', () {
      final items = [
        {
          'deck_quantity': 1,
          'dynamic_data': '{ corrupt: json,', // Invalid JSON syntax
        },
        {
          'deck_quantity': 1,
          'dynamic_data': '', // Empty string
        },
        {
          'deck_quantity': 1,
          'dynamic_data': jsonEncode({
            'name': 'Sol Ring',
            'type_line': 'Artifact',
            'cmc': '1',
            'mana_cost': '{1}',
          }),
        },
      ];

      // Must not crash, should parse valid Sol Ring
      final analytics = MockDeckData.computeAnalyticsFromItems(items);
      expect(analytics.manaCurve[1], equals(1));
    });
  });

  // ===========================================================================
  // GROUP 9: Devotion Tallying Across Complex Multicolor Mana Costs
  // ===========================================================================
  group('Devotion Tallying Across Complex Multicolor Mana Costs', () {
    test('Accurately tallies devotion across 5-color and hybrid combinations', () {
      final items = [
        // Niv-Mizzet Reborn: {W}{U}{B}{R}{G}
        {
          'deck_quantity': 1,
          'dynamic_data': jsonEncode({
            'name': 'Niv-Mizzet Reborn',
            'mana_cost': '{W}{U}{B}{R}{G}',
            'cmc': 5,
          }),
        },
        // Progenitus: {W}{W}{U}{U}{B}{B}{R}{R}{G}{G}
        {
          'deck_quantity': 1,
          'dynamic_data': jsonEncode({
            'name': 'Progenitus',
            'mana_cost': '{W}{W}{U}{U}{B}{B}{R}{R}{G}{G}',
            'cmc': 10,
          }),
        },
      ];

      final analytics = MockDeckData.computeAnalyticsFromItems(items);
      expect(analytics.colorDevotion['W'], equals(3));
      expect(analytics.colorDevotion['U'], equals(3));
      expect(analytics.colorDevotion['B'], equals(3));
      expect(analytics.colorDevotion['R'], equals(3));
      expect(analytics.colorDevotion['G'], equals(3));
    });

    test('Tallies devotion for multi-component hybrid, twobrid, and colorless hybrids', () {
      final items = [
        {
          'deck_quantity': 1,
          'dynamic_data': jsonEncode({
            'name': 'Complex Multi',
            'mana_cost': '{2/W}{W/U}{B/P}{B/G/P}{C/R}',
            'cmc': 5,
          }),
        },
      ];

      final analytics = MockDeckData.computeAnalyticsFromItems(items);
      // {2/W} -> W: 1
      // {W/U} -> W: 1, U: 1
      // {B/P} -> B: 1
      // {B/G/P} -> B: 1, G: 1
      // {C/R} -> C: 1, R: 1
      expect(analytics.colorDevotion['W'], equals(2));
      expect(analytics.colorDevotion['U'], equals(1));
      expect(analytics.colorDevotion['B'], equals(2));
      expect(analytics.colorDevotion['G'], equals(1));
      expect(analytics.colorDevotion['R'], equals(1));
      expect(analytics.colorDevotion['C'], equals(1));
      expect(analytics.colorDevotion['P'], isNull);
      expect(analytics.colorDevotion['2'], isNull);
    });

    test('Non-color symbols ({T}, {Q}, {E}, {X}, {S}) do not leak into devotion', () {
      final items = [
        {
          'deck_quantity': 1,
          'dynamic_data': jsonEncode({
            'name': 'Utility Artifact',
            'mana_cost': '{X}{X}{T}{Q}{E}{S}{R}',
            'cmc': 1,
          }),
        },
      ];

      final analytics = MockDeckData.computeAnalyticsFromItems(items);
      expect(analytics.colorDevotion['R'], equals(1));
      expect(analytics.colorDevotion['X'], isNull);
      expect(analytics.colorDevotion['T'], isNull);
      expect(analytics.colorDevotion['Q'], isNull);
      expect(analytics.colorDevotion['E'], isNull);
      expect(analytics.colorDevotion['S'], isNull);
    });
  });

  // ===========================================================================
  // GROUP 10: ManaSymbolIcon Vector SVG Rendering (Widget Tests)
  // ===========================================================================
  group('ManaSymbolIcon - Vector SVG Rendering Verification', () {
    testWidgets('renders canonical colored mana symbols ({W}, {U}, {B}, {R}, {G}, {C})',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                ManaSymbolIcon(symbolCode: '{W}', size: 24.0),
                ManaSymbolIcon(symbolCode: '{U}', size: 24.0),
                ManaSymbolIcon(symbolCode: '{B}', size: 24.0),
                ManaSymbolIcon(symbolCode: '{R}', size: 24.0),
                ManaSymbolIcon(symbolCode: '{G}', size: 24.0),
                ManaSymbolIcon(symbolCode: '{C}', size: 24.0),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(ManaSymbolIcon), findsNWidgets(6));
      expect(find.byType(SvgPicture), findsNWidgets(6));

      final icons = tester.widgetList<ManaSymbolIcon>(find.byType(ManaSymbolIcon)).toList();
      expect(icons[0].assetPath, equals('assets/symbology/W.svg'));
      expect(icons[1].assetPath, equals('assets/symbology/U.svg'));
      expect(icons[2].assetPath, equals('assets/symbology/B.svg'));
      expect(icons[3].assetPath, equals('assets/symbology/R.svg'));
      expect(icons[4].assetPath, equals('assets/symbology/G.svg'));
      expect(icons[5].assetPath, equals('assets/symbology/C.svg'));
    });

    testWidgets('renders all 5 twobrid symbols cleanly ({2/W}, {2/U}, {2/B}, {2/R}, {2/G})',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                ManaSymbolIcon(symbolCode: '{2/W}', size: 26.0),
                ManaSymbolIcon(symbolCode: '{2/U}', size: 26.0),
                ManaSymbolIcon(symbolCode: '{2/B}', size: 26.0),
                ManaSymbolIcon(symbolCode: '{2/R}', size: 26.0),
                ManaSymbolIcon(symbolCode: '{2/G}', size: 26.0),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(ManaSymbolIcon), findsNWidgets(5));
      expect(find.byType(SvgPicture), findsNWidgets(5));

      final icons = tester.widgetList<ManaSymbolIcon>(find.byType(ManaSymbolIcon)).toList();
      expect(icons[0].assetPath, equals('assets/symbology/2W.svg'));
      expect(icons[1].assetPath, equals('assets/symbology/2U.svg'));
      expect(icons[2].assetPath, equals('assets/symbology/2B.svg'));
      expect(icons[3].assetPath, equals('assets/symbology/2R.svg'));
      expect(icons[4].assetPath, equals('assets/symbology/2G.svg'));
    });

    testWidgets('supports both symbolCode and symbol constructor parameters interchangeably',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                ManaSymbolIcon(symbolCode: '{W}'),
                ManaSymbolIcon(symbol: '{U}'),
                ManaSymbolIcon(symbol: 'B'),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final icons = tester.widgetList<ManaSymbolIcon>(find.byType(ManaSymbolIcon)).toList();
      expect(icons[0].symbolCode, equals('{W}'));
      expect(icons[1].symbolCode, equals('{U}'));
      expect(icons[2].symbolCode, equals('B'));
      expect(icons[2].assetPath, equals('assets/symbology/B.svg'));
    });

    testWidgets('renders unbracketed, lowercase, and transposed alias inputs cleanly',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                ManaSymbolIcon(symbolCode: 'w', size: 20.0),
                ManaSymbolIcon(symbolCode: 'w/u', size: 20.0),
                ManaSymbolIcon(symbolCode: 'P/B', size: 20.0),
                ManaSymbolIcon(symbolCode: '2w', size: 20.0),
                ManaSymbolIcon(symbolCode: 'HALF', size: 20.0),
                ManaSymbolIcon(symbolCode: 'INFINITY', size: 20.0),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final icons = tester.widgetList<ManaSymbolIcon>(find.byType(ManaSymbolIcon)).toList();
      expect(icons[0].assetPath, equals('assets/symbology/W.svg'));
      expect(icons[1].assetPath, equals('assets/symbology/WU.svg'));
      expect(icons[2].assetPath, equals('assets/symbology/BP.svg'));
      expect(icons[3].assetPath, equals('assets/symbology/2W.svg'));
      expect(icons[4].assetPath, equals('assets/symbology/HALF.svg'));
      expect(icons[5].assetPath, equals('assets/symbology/INFINITY.svg'));
    });

    testWidgets('respects circular flag (ClipOval vs unclipped)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                ManaSymbolIcon(symbolCode: '{W}', circular: true),
                ManaSymbolIcon(symbolCode: '{U}', circular: false),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ClipOval), findsOneWidget);
    });

    testWidgets('populates accessible semantics label from ScryfallSymbol english',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ManaSymbolIcon(symbolCode: '{W/U}'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final semanticsFinder = find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'one white or blue mana',
      );
      expect(semanticsFinder, findsOneWidget);
    });

    testWidgets('gracefully renders fallback badge for unknown symbols without throwing',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ManaSymbolIcon(symbolCode: '{UNKNOWN_PIP}', size: 24.0),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Fallback text badge renders clean token
      expect(find.text('UNKNOWN_PIP'), findsOneWidget);
    });

    testWidgets('custom fallbackBuilder is invoked when symbol is unrecognized',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ManaSymbolIcon(
              symbolCode: '{XYZ}',
              fallbackBuilder: (ctx, code, sz) => Text('CustomFallback: $code'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CustomFallback: {XYZ}'), findsOneWidget);
    });
  });

  // ===========================================================================
  // GROUP 11: deckAnalyticsProvider Riverpod Integration Stream Verification
  // ===========================================================================
  group('deckAnalyticsProvider - Riverpod Stream Verification', () {
    test('Calculates curve and devotion through real Riverpod provider stream with land exclusion', () async {
      final testItems = [
        {
          'deck_quantity': 2,
          'is_graded': 0,
          'is_altered': 0,
          'is_signed': 0,
          'dynamic_data': jsonEncode({
            'name': 'Lotus Petal',
            'type_line': 'Artifact',
            'cmc': 0,
            'mana_cost': '{0}',
          }),
        },
        {
          'deck_quantity': 1,
          'is_graded': 0,
          'is_altered': 0,
          'is_signed': 0,
          'dynamic_data': jsonEncode({
            'name': 'Fire // Ice',
            'layout': 'split',
            'card_faces': [
              {'name': 'Fire', 'mana_cost': '{1}{R}', 'cmc': 2.0},
              {'name': 'Ice', 'mana_cost': '{1}{U}', 'cmc': 2.0},
            ],
          }),
        },
        {
          'deck_quantity': 1,
          'is_graded': 0,
          'is_altered': 0,
          'is_signed': 0,
          'dynamic_data': jsonEncode({
            'name': 'Reaper King',
            'type_line': 'Artifact Creature — Scarecrow',
            'mana_cost': '{2/W}{2/U}{2/B}{2/R}{2/G}',
          }),
        },
        {
          'deck_quantity': 4,
          'is_graded': 0,
          'is_altered': 0,
          'is_signed': 0,
          'dynamic_data': jsonEncode({
            'name': 'Swamp',
            'type_line': 'Basic Land — Swamp',
            'cmc': 0,
          }),
        },
      ];

      final container = ProviderContainer(
        overrides: [
          deckItemsProvider('stress-test-deck').overrideWith(
            (ref) => Stream.value(testItems),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(deckItemsProvider('stress-test-deck').future);
      final asyncAnalytics = container.read(deckAnalyticsProvider('stress-test-deck'));
      expect(asyncAnalytics.hasValue, isTrue);

      final analytics = asyncAnalytics.value!;
      // Lotus Petal (2 copies) in bucket 0
      expect(analytics.manaCurve[0], equals(2));
      // Fire // Ice (1 copy) in bucket 4
      expect(analytics.manaCurve[4], equals(1));
      // Reaper King (1 copy) in bucket 10
      expect(analytics.manaCurve[10], equals(1));
      // Swamp (4 copies) excluded from curve
      expect(analytics.manaCurve[0], equals(2)); // not 6!

      // Devotion:
      // Fire // Ice has {1}{R} and {1}{U}
      expect(analytics.colorDevotion['R'], equals(2)); // 1 from Fire + 1 from Reaper King
      expect(analytics.colorDevotion['U'], equals(2)); // 1 from Ice + 1 from Reaper King
      expect(analytics.colorDevotion['W'], equals(1)); // from Reaper King
      expect(analytics.colorDevotion['B'], equals(1)); // from Reaper King
      expect(analytics.colorDevotion['G'], equals(1)); // from Reaper King
    });
  });

  // ===========================================================================
  // GROUP 12: InlineDeckAnalyticsCard Widget Rendering & Symbology Integration
  // ===========================================================================
  group('InlineDeckAnalyticsCard - Widget Rendering with Mana Curve & Symbology Pips', () {
    testWidgets('renders expanded InlineDeckAnalyticsCard with ManaCurve bars and devotion pips',
        (tester) async {
      final analytics = DeckAnalytics(
        manaCurve: {0: 3, 1: 5, 2: 8, 3: 4, 4: 2, 6: 1, 7: 2},
        colorDevotion: {'W': 10, 'U': 5, 'B': 15, 'R': 8, 'G': 2, 'C': 0},
        colorProduction: {'W': 5, 'U': 2, 'B': 8, 'R': 4, 'G': 1},
        blingPercentage: 0.35,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: InlineDeckAnalyticsCard(
                analytics: analytics,
                isExpanded: true,
                onToggleExpand: () {},
                onOpenModal: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(InlineDeckAnalyticsCard), findsOneWidget);
      expect(find.byType(ManaCurveChartWidget), findsOneWidget);
      expect(find.byType(ColorDevotionPipsWidget), findsOneWidget);
      expect(find.byType(BlingMeterWidget), findsOneWidget);

      // Verify devotion pips contain ManaSymbolIcon
      expect(find.descendant(of: find.byType(ColorDevotionPipsWidget), matching: find.byType(ManaSymbolIcon)),
          findsNWidgets(6));

      // Verify histogram displays bucket 0 (with 3 cards)
      expect(find.text('3'), findsWidgets);
      // Verify bucket '7+'
      expect(find.text('7+'), findsOneWidget);
    });

    testWidgets('renders collapsed InlineDeckAnalyticsCard with mini symbology preview',
        (tester) async {
      final analytics = DeckAnalytics(
        manaCurve: {0: 3, 2: 8},
        colorDevotion: {'W': 10, 'B': 15, 'R': 8},
        colorProduction: {},
        blingPercentage: 0.25,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InlineDeckAnalyticsCard(
              analytics: analytics,
              isExpanded: false,
              onToggleExpand: () {},
              onOpenModal: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('25.0% Bling'), findsOneWidget);
      // Collapsed preview shows non-zero devotion pips as mini ManaSymbolIcons
      expect(find.byType(ManaSymbolIcon), findsNWidgets(3));
    });
  });
}
