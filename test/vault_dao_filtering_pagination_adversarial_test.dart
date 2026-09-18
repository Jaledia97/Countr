import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/presentation/providers/mtg_filter_state.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late VaultDao dao;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dao = db.vaultDao;
    // Wipe default mock seeds so tests run against exact deterministic test fixtures
    await dao.delete(dao.vaultItems).go();
  });

  tearDown(() async {
    await db.close();
  });

  VaultItem createTestCard({
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

  group('1. Dual-Stage SQL Pushdown vs In-Memory Correctness', () {
    test('1.1 Direct SQLite column pushdown matches in-memory results without dropping cards', () async {
      await dao.into(dao.vaultItems).insert(
        createTestCard(
          id: 'card-graded',
          name: 'Graded Black Lotus',
          isGraded: true,
          dynamicDataMap: {'cmc': 0, 'colors': <String>[]},
        ),
      );
      await dao.into(dao.vaultItems).insert(
        createTestCard(
          id: 'card-signed',
          name: 'Signed Mox Sapphire',
          isSigned: true,
          dynamicDataMap: {'cmc': 0, 'colors': <String>[]},
        ),
      );
      await dao.into(dao.vaultItems).insert(
        createTestCard(
          id: 'card-altered',
          name: 'Altered Sol Ring',
          isAltered: true,
          dynamicDataMap: {'cmc': 1, 'colors': <String>[]},
        ),
      );
      await dao.into(dao.vaultItems).insert(
        createTestCard(
          id: 'card-misprint',
          name: 'Misprinted Lightning Bolt',
          isMisprint: true,
          dynamicDataMap: {'cmc': 1, 'colors': ['R']},
        ),
      );
      await dao.into(dao.vaultItems).insert(
        createTestCard(
          id: 'card-plain',
          name: 'Plain Mountain',
          dynamicDataMap: {'cmc': 0, 'colors': ['R']},
        ),
      );

      // Filter Graded
      final gradedFilter = const MtgFilterState(isGraded: true);
      final gradedResults = await dao.getItemsByCollection('mtg', mtgFilter: gradedFilter);
      expect(gradedResults.map((c) => c.id).toList(), equals(['card-graded']));

      // Filter Signed
      final signedFilter = const MtgFilterState(isSigned: true);
      final signedResults = await dao.getItemsByCollection('mtg', mtgFilter: signedFilter);
      expect(signedResults.map((c) => c.id).toList(), equals(['card-signed']));

      // Filter Altered
      final alteredFilter = const MtgFilterState(isAltered: true);
      final alteredResults = await dao.getItemsByCollection('mtg', mtgFilter: alteredFilter);
      expect(alteredResults.map((c) => c.id).toList(), equals(['card-altered']));

      // Filter Misprint
      final misprintFilter = const MtgFilterState(isMisprint: true);
      final misprintResults = await dao.getItemsByCollection('mtg', mtgFilter: misprintFilter);
      expect(misprintResults.map((c) => c.id).toList(), equals(['card-misprint']));
    });

    test('1.2 Type line pushdown correctly handles multi-word, single-faced and multi-faced cards', () async {
      // Single-face legendary angel
      await dao.into(dao.vaultItems).insert(
        createTestCard(
          id: 'card-angel',
          name: 'Avacyn, Angel of Hope',
          dynamicDataMap: {
            'type_line': 'Legendary Creature — Angel',
            'oracle_text': 'Flying, vigilance, indestructible',
          },
        ),
      );

      // Multi-face adventure card (Creature // Instant)
      await dao.into(dao.vaultItems).insert(
        createTestCard(
          id: 'card-giant',
          name: 'Bonecrusher Giant // Stomp',
          dynamicDataMap: {
            'layout': 'adventure',
            'type_line': 'Creature — Giant // Instant — Adventure',
            'card_faces': [
              {
                'name': 'Bonecrusher Giant',
                'type_line': 'Creature — Giant',
                'oracle_text': 'Target damage',
              },
              {
                'name': 'Stomp',
                'type_line': 'Instant — Adventure',
                'oracle_text': 'Damage cannot be prevented',
              }
            ],
          },
        ),
      );

      // False-positive candidate for SQL pushdown: has "Angel" in oracle text, but type is Sorcery
      await dao.into(dao.vaultItems).insert(
        createTestCard(
          id: 'card-entreat',
          name: 'Entreat the Angels',
          dynamicDataMap: {
            'type_line': 'Sorcery',
            'oracle_text': 'Create 4/4 white Angel creature tokens with flying.',
          },
        ),
      );

      // 1. Query for "Legendary Creature Angel": SQL pushdown must find 'card-angel', Stage 2 must keep it
      final angelFilter = const MtgFilterState(typeLine: 'Legendary Angel');
      final angelResults = await dao.getItemsByCollection('mtg', mtgFilter: angelFilter);
      expect(angelResults.map((c) => c.id).toList(), equals(['card-angel']));

      // 2. Query for "Adventure": multi-face card must be matched without drop
      final advFilter = const MtgFilterState(typeLine: 'Adventure');
      final advResults = await dao.getItemsByCollection('mtg', mtgFilter: advFilter);
      expect(advResults.map((c) => c.id).toList(), equals(['card-giant']));

      // 3. Query for "Angel": 'card-entreat' matches SQL LIKE '%Angel%' but Stage 2 MUST filter it out because type is Sorcery!
      final angelTypeFilter = const MtgFilterState(typeLine: 'Angel');
      final angelTypeResults = await dao.getItemsByCollection('mtg', mtgFilter: angelTypeFilter);
      expect(angelTypeResults.map((c) => c.id).toList(), equals(['card-angel']));
      expect(angelTypeResults.any((c) => c.id == 'card-entreat'), isFalse,
          reason: 'Stage 2 must prune false positives passed through SQL pushdown');
    });

    test('1.3 Oracle text pushdown handles single, multiple clauses and multi-faced cards', () async {
      await dao.into(dao.vaultItems).insert(
        createTestCard(
          id: 'card-draw-discard',
          name: 'Faithless Looting',
          dynamicDataMap: {
            'oracle_text': 'Draw two cards, then discard two cards. Flashback {2}{R}',
          },
        ),
      );

      await dao.into(dao.vaultItems).insert(
        createTestCard(
          id: 'card-draw-only',
          name: 'Divination',
          dynamicDataMap: {
            'oracle_text': 'Draw two cards.',
          },
        ),
      );

      // Multi-face card with oracle text split across faces
      await dao.into(dao.vaultItems).insert(
        createTestCard(
          id: 'card-delver',
          name: 'Delver of Secrets // Insectile Aberration',
          dynamicDataMap: {
            'layout': 'transform',
            'card_faces': [
              {
                'name': 'Delver of Secrets',
                'oracle_text': 'Look at the top card of your library. You may reveal an instant or sorcery.',
              },
              {
                'name': 'Insectile Aberration',
                'oracle_text': 'Flying',
              },
            ],
          },
        ),
      );

      // Single clause
      final drawFilter = const MtgFilterState(oracleTextClauses: ['Draw two cards']);
      final drawResults = await dao.getItemsByCollection('mtg', mtgFilter: drawFilter);
      expect(drawResults.map((c) => c.id).toSet(), equals({'card-draw-discard', 'card-draw-only'}));

      // Multiple clauses: both must match
      final bothFilter = const MtgFilterState(oracleTextClauses: ['Draw two cards', 'discard']);
      final bothResults = await dao.getItemsByCollection('mtg', mtgFilter: bothFilter);
      expect(bothResults.map((c) => c.id).toList(), equals(['card-draw-discard']));

      // Multi-face face 2 oracle text
      final flyingFilter = const MtgFilterState(oracleTextClauses: ['Flying']);
      final flyingResults = await dao.getItemsByCollection('mtg', mtgFilter: flyingFilter);
      expect(flyingResults.map((c) => c.id).toList(), equals(['card-delver']));
    });

    test('1.4 Universes Beyond pushdown covers all 4 indicators without dropping cards', () async {
      // 1. Explicit boolean flag
      await dao.into(dao.vaultItems).insert(
        createTestCard(
          id: 'ub-flag',
          name: 'The One Ring (Flag)',
          dynamicDataMap: {'is_universes_beyond': true},
        ),
      );

      // 2. promo_types contains 'universes_beyond'
      await dao.into(dao.vaultItems).insert(
        createTestCard(
          id: 'ub-promo',
          name: 'Gandalf the Grey (Promo)',
          dynamicDataMap: {'promo_types': ['universes_beyond']},
        ),
      );

      // 3. frame_effects contains 'universesbeyond'
      await dao.into(dao.vaultItems).insert(
        createTestCard(
          id: 'ub-frame',
          name: 'Frodo Baggins (Frame)',
          dynamicDataMap: {'frame_effects': ['universesbeyond']},
        ),
      );

      // 4. security_stamp is 'triangle'
      await dao.into(dao.vaultItems).insert(
        createTestCard(
          id: 'ub-stamp',
          name: 'Warhammer Space Marine (Stamp)',
          dynamicDataMap: {'security_stamp': 'triangle'},
        ),
      );

      // Standard non-UB card
      await dao.into(dao.vaultItems).insert(
        createTestCard(
          id: 'non-ub',
          name: 'Lightning Bolt',
          dynamicDataMap: {'security_stamp': 'oval'},
        ),
      );

      // Filter Universes Beyond = true
      final ubFilter = const MtgFilterState(isUniversesBeyond: true);
      final ubResults = await dao.getItemsByCollection('mtg', mtgFilter: ubFilter);
      final ubIds = ubResults.map((c) => c.id).toSet();
      expect(ubIds, equals({'ub-flag', 'ub-promo', 'ub-frame', 'ub-stamp'}));
      expect(ubIds.contains('non-ub'), isFalse);

      // Filter Universes Beyond = false
      final nonUbFilter = const MtgFilterState(isUniversesBeyond: false);
      final nonUbResults = await dao.getItemsByCollection('mtg', mtgFilter: nonUbFilter);
      expect(nonUbResults.map((c) => c.id).toList(), equals(['non-ub']));
    });

    test('1.5 Set code pushdown handles normal sets, SLD alias, and != operator correctly', () async {
      await dao.into(dao.vaultItems).insert(
        createTestCard(
          id: 'card-mh3',
          name: 'Ugin\'s Labyrinth',
          setOrSeries: 'MH3',
          dynamicDataMap: {'set': 'mh3'},
        ),
      );
      await dao.into(dao.vaultItems).insert(
        createTestCard(
          id: 'card-sld-1',
          name: 'Sol Ring SLD',
          setOrSeries: 'Secret Lair Drop',
          dynamicDataMap: {'set': 'sld'},
        ),
      );
      await dao.into(dao.vaultItems).insert(
        createTestCard(
          id: 'card-sld-2',
          name: 'The Ozolith SLD',
          setOrSeries: 'SLD',
          dynamicDataMap: {'set': 'sld'},
        ),
      );
      await dao.into(dao.vaultItems).insert(
        createTestCard(
          id: 'card-dmu',
          name: 'Sheoldred, the Apocalypse',
          setOrSeries: 'DMU',
          dynamicDataMap: {'set': 'dmu'},
        ),
      );

      // Normal set query '='
      final mh3Filter = const MtgFilterState(setCode: 'mh3', setOperator: '=');
      final mh3Results = await dao.getItemsByCollection('mtg', mtgFilter: mh3Filter);
      expect(mh3Results.map((c) => c.id).toList(), equals(['card-mh3']));

      // Secret Lair Drop query '='
      final sldFilter = const MtgFilterState(setCode: 'sld', setOperator: '=');
      final sldResults = await dao.getItemsByCollection('mtg', mtgFilter: sldFilter);
      expect(sldResults.map((c) => c.id).toSet(), equals({'card-sld-1', 'card-sld-2'}));

      // Negative operator '!=': Stage 1 defers pushdown so rows are not starved, Stage 2 enforces
      final notMh3Filter = const MtgFilterState(setCode: 'mh3', setOperator: '!=');
      final notMh3Results = await dao.getItemsByCollection('mtg', mtgFilter: notMh3Filter);
      final notMh3Ids = notMh3Results.map((c) => c.id).toSet();
      expect(notMh3Ids.contains('card-mh3'), isFalse);
      expect(notMh3Ids.contains('card-sld-1'), isTrue);
      expect(notMh3Ids.contains('card-sld-2'), isTrue);
      expect(notMh3Ids.contains('card-dmu'), isTrue);
    });

    test('1.6 Condition pushdown preserves cards with matching conditions', () async {
      await dao.into(dao.vaultItems).insert(
        createTestCard(id: 'cond-nm', name: 'Card NM', condition: 'NM'),
      );
      await dao.into(dao.vaultItems).insert(
        createTestCard(id: 'cond-lp', name: 'Card LP', condition: 'LP'),
      );
      await dao.into(dao.vaultItems).insert(
        createTestCard(id: 'cond-po', name: 'Card PO', condition: 'PO'),
      );

      final filter = const MtgFilterState(conditions: {'NM', 'LP'});
      final results = await dao.getItemsByCollection('mtg', mtgFilter: filter);
      expect(results.map((c) => c.id).toSet(), equals({'cond-nm', 'cond-lp'}));
    });

    test('1.7 Complex Stage 2 evaluations (Commander colors & Stats) survive SQL pushdown without dropping valid cards', () async {
      // White-Blue card
      await dao.into(dao.vaultItems).insert(
        createTestCard(
          id: 'card-wu-esper',
          name: 'Teferi, Hero of Dominaria',
          dynamicDataMap: {
            'colors': ['W', 'U'],
            'color_identity': ['W', 'U'],
            'cmc': 5,
            'power': null,
          },
        ),
      );

      // Colorless Artifact with power 4
      await dao.into(dao.vaultItems).insert(
        createTestCard(
          id: 'card-c-golem',
          name: 'Solemn Simulacrum',
          dynamicDataMap: {
            'colors': <String>[],
            'color_identity': <String>[],
            'cmc': 4,
            'power': '2',
            'toughness': '2',
          },
        ),
      );

      // Green creature with power 4
      await dao.into(dao.vaultItems).insert(
        createTestCard(
          id: 'card-g-beast',
          name: 'Questing Beast',
          dynamicDataMap: {
            'colors': ['G'],
            'color_identity': ['G'],
            'cmc': 4,
            'power': '4',
            'toughness': '4',
          },
        ),
      );

      // Commander mode: commander colors {W, U}. Colorless cards and WU cards are legal; G is not.
      final cmdFilter = const MtgFilterState(
        colors: {'W', 'U'},
        colorMatchMode: ColorMatchMode.commander,
        colorTarget: ColorTarget.colorIdentity,
      );
      final cmdResults = await dao.getItemsByCollection('mtg', mtgFilter: cmdFilter);
      final cmdIds = cmdResults.map((c) => c.id).toSet();
      expect(cmdIds, equals({'card-wu-esper', 'card-c-golem'}),
          reason: 'Colorless cards must be included in commander color identity queries alongside valid subsets');

      // Stat filter: power >= 4
      final statFilter = const MtgFilterState(
        statFilters: [
          MtgStatFilter(stat: 'power', operator: '>=', value: '4'),
        ],
      );
      final statResults = await dao.getItemsByCollection('mtg', mtgFilter: statFilter);
      expect(statResults.map((c) => c.id).toList(), equals(['card-g-beast']));
    });
  });

  group('2. Pagination Starvation Prevention (Crucial Requirement)', () {
    test('2.1 Seed 50 cards: cards 1-20 non-matching, cards 21-30 matching; limit=10 returns exactly 10 cards', () async {
      // Seed 50 cards with acquiredDate ordered so cards 1-20 are fetched first by SQLite ordering
      // (Ordering is acquiredDate DESC, name ASC)
      final baseDate = DateTime(2026, 1, 1);

      for (int i = 1; i <= 50; i++) {
        final id = 'seed-card-${i.toString().padLeft(3, '0')}';
        // Earlier items (1-20) have newer acquiredDate so they rank first in SQLite candidate list
        final date = baseDate.add(Duration(days: 100 - i));

        final bool isMatching = (i >= 21 && i <= 30);

        await dao.into(dao.vaultItems).insert(
          createTestCard(
            id: id,
            name: 'Card $i',
            acquiredDate: date,
            // In-memory filter criteria: layout == 'transform' and oracle contains 'special-secret-token'
            dynamicDataMap: {
              'layout': isMatching ? 'transform' : 'normal',
              'oracle_text': isMatching ? 'special-secret-token draw 2' : 'vanilla spell',
              'cmc': isMatching ? 2 : 5,
            },
          ),
        );
      }

      // Filter targeting layout 'transform' and oracle text 'special-secret-token'
      final filter = const MtgFilterState(
        layouts: {'transform'},
        oracleTextClauses: ['special-secret-token'],
      );

      // Query with limit = 10
      final results = await dao.getItemsByCollection('mtg', mtgFilter: filter, limit: 10);

      // EMPIRICAL PROOF OF STARVATION PREVENTION:
      // If limit=10 was applied at SQLite level before Stage 2, items 1-10 would be returned from SQL,
      // all 10 would fail Stage 2, and results.length would be 0 (Starvation bug!).
      // With post-filtering pagination, candidate rows are filtered first, yielding all 10 matching items!
      expect(results.length, equals(10),
          reason: 'Pagination must not be starved by non-matching rows earlier in database ordering');

      final expectedIds = List.generate(10, (idx) => 'seed-card-${(idx + 21).toString().padLeft(3, '0')}');
      expect(results.map((c) => c.id).toList(), equals(expectedIds));
    });

    test('2.2 Post-filtering pagination with offset and limit', () async {
      final baseDate = DateTime(2026, 1, 1);

      // Seed 20 non-matching cards followed by 30 matching cards
      for (int i = 1; i <= 50; i++) {
        final id = 'card-off-${i.toString().padLeft(3, '0')}';
        final date = baseDate.add(Duration(days: 100 - i));
        final isMatching = i > 20; // 30 cards match (21 to 50)

        await dao.into(dao.vaultItems).insert(
          createTestCard(
            id: id,
            name: 'Card $i',
            acquiredDate: date,
            dynamicDataMap: {
              'rarity': isMatching ? 'mythic' : 'common',
            },
          ),
        );
      }

      final filter = const MtgFilterState(rarities: {'mythic'});

      // Page 1: limit 5, offset 0 -> cards 21 to 25
      final page1 = await dao.getItemsByCollection('mtg', mtgFilter: filter, limit: 5, offset: 0);
      expect(page1.length, equals(5));
      expect(page1.first.id, equals('card-off-021'));
      expect(page1.last.id, equals('card-off-025'));

      // Page 2: limit 5, offset 5 -> cards 26 to 30
      final page2 = await dao.getItemsByCollection('mtg', mtgFilter: filter, limit: 5, offset: 5);
      expect(page2.length, equals(5));
      expect(page2.first.id, equals('card-off-026'));
      expect(page2.last.id, equals('card-off-030'));

      // Empty page: offset exceeding matched items
      final emptyPage = await dao.getItemsByCollection('mtg', mtgFilter: filter, limit: 10, offset: 50);
      expect(emptyPage, isEmpty);
    });

    test('2.3 Reactive stream pagination (watchItemsByCollection) prevents starvation', () async {
      final baseDate = DateTime(2026, 1, 1);

      for (int i = 1; i <= 30; i++) {
        final id = 'stream-seed-${i.toString().padLeft(3, '0')}';
        final date = baseDate.add(Duration(days: 50 - i));
        final isMatching = (i >= 15 && i <= 24); // 10 cards match

        await dao.into(dao.vaultItems).insert(
          createTestCard(
            id: id,
            name: 'Stream Card $i',
            acquiredDate: date,
            dynamicDataMap: {
              'finishes': isMatching ? ['foil'] : ['nonfoil'],
            },
          ),
        );
      }

      final filter = const MtgFilterState(finishes: {'foil'});
      final stream = dao.watchItemsByCollection('mtg', mtgFilter: filter, limit: 10);

      final firstEmission = await stream.first;
      expect(firstEmission.length, equals(10));
      expect(firstEmission.every((item) {
        final dyn = jsonDecode(item.dynamicData) as Map<String, dynamic>;
        return (dyn['finishes'] as List).contains('foil');
      }), isTrue);
    });

    test('2.4 Needle in haystack starvation test: 100 cards with isolated matches at index 50 and 100', () async {
      final baseDate = DateTime(2026, 1, 1);

      for (int i = 1; i <= 100; i++) {
        final date = baseDate.add(Duration(days: 200 - i));
        final bool isMatch = (i == 50 || i == 100);

        await dao.into(dao.vaultItems).insert(
          createTestCard(
            id: 'haystack-card-$i',
            name: 'Card $i',
            acquiredDate: date,
            dynamicDataMap: {
              'oracle_text': isMatch ? 'needle found in haystack' : 'common hay',
            },
          ),
        );
      }

      final needleFilter = const MtgFilterState(oracleTextClauses: ['needle found']);

      // Fetch first needle (limit: 1)
      final needle1 = await dao.getItemsByCollection('mtg', mtgFilter: needleFilter, limit: 1);
      expect(needle1.length, equals(1));
      expect(needle1.first.id, equals('haystack-card-50'));

      // Fetch second needle via offset: 1, limit: 1
      final needle2 = await dao.getItemsByCollection('mtg', mtgFilter: needleFilter, limit: 1, offset: 1);
      expect(needle2.length, equals(1));
      expect(needle2.first.id, equals('haystack-card-100'));

      // Offset beyond matching items
      final needleEmpty = await dao.getItemsByCollection('mtg', mtgFilter: needleFilter, limit: 1, offset: 2);
      expect(needleEmpty, isEmpty);
    });
  });

  group('3. Multi-Game Collection Isolation & Robustness', () {
    setUp(() async {
      // Seed multi-game items
      // 1. MTG cards
      await dao.into(dao.vaultItems).insert(
        createTestCard(
          id: 'mtg-card-1',
          name: 'Counterspell',
          collectionType: 'mtg',
          dynamicDataMap: {
            'colors': ['U'],
            'cmc': 2,
            'oracle_text': 'Counter target spell.',
          },
        ),
      );

      // 2. Pokemon cards
      await dao.into(dao.vaultItems).insert(
        createTestCard(
          id: 'poke-card-1',
          name: 'Charizard ex',
          collectionType: 'pokemon',
          dynamicDataMap: {
            'hp': '330',
            'types': ['Darkness'],
            'attacks': [
              {'name': 'Burning Darkness', 'damage': '180+'},
            ],
            'weakness': {'type': 'Grass', 'value': 'x2'},
          },
        ),
      );
      await dao.into(dao.vaultItems).insert(
        createTestCard(
          id: 'poke-card-2',
          name: 'Pikachu',
          collectionType: 'pokemon',
          dynamicDataMap: {
            'hp': '60',
            'types': ['Lightning'],
            'attacks': [
              {'name': 'Thunder Jolt', 'damage': '30'},
            ],
          },
        ),
      );

      // 3. Yu-Gi-Oh cards
      await dao.into(dao.vaultItems).insert(
        createTestCard(
          id: 'ygo-card-1',
          name: 'Dark Magician',
          collectionType: 'yugioh',
          dynamicDataMap: {
            'atk': 2500,
            'def': 2100,
            'level': 7,
            'attribute': 'DARK',
            'race': 'Spellcaster',
          },
        ),
      );

      // 4. Lorcana cards
      await dao.into(dao.vaultItems).insert(
        createTestCard(
          id: 'lorcana-card-1',
          name: 'Elsa - Spirit of Winter',
          collectionType: 'lorcana',
          dynamicDataMap: {
            'ink_cost': 8,
            'inkwell': false,
            'lore': 3,
            'color': 'Amethyst',
            'strength': 4,
            'willpower': 6,
          },
        ),
      );
    });

    test('3.1 MTG filter scoped to mtg collection returns only MTG items', () async {
      final filter = const MtgFilterState(colors: {'U'});
      final results = await dao.getItemsByCollection('mtg', mtgFilter: filter);

      expect(results.length, equals(1));
      expect(results.first.id, equals('mtg-card-1'));
      expect(results.first.collectionType, equals('mtg'));
    });

    test('3.2 Non-MTG collection queries survive if MTG filter is passed without crashing', () async {
      final filter = const MtgFilterState(
        colors: {'R'},
        cmcRange: RangeValues(2, 4),
      );

      // Must not throw any FormatException or crash
      final pokeResults = await dao.getItemsByCollection('pokemon', mtgFilter: filter);
      expect(pokeResults, isA<List<VaultItem>>());
    });

    test('3.3 Hostile and malformed dynamicData does not crash evaluator or DAO', () async {
      // Card with malformed non-JSON dynamicData
      await dao.into(dao.vaultItems).insert(
        VaultItem(
          id: 'malformed-json',
          collectionType: 'mtg',
          name: 'Corrupted Card',
          flavorName: null,
          setOrSeries: 'TEST',
          imageUrl: '',
          acquiredPrice: 1.0,
          acquiredDate: DateTime.now(),
          quantity: 1,
          condition: 'NM',
          isGraded: false,
          isAltered: false,
          isMisprint: false,
          isSigned: false,
          personalNotes: null,
          primaryBinderId: null,
          currentMarketPrice: 1.0,
          lastPriceUpdate: DateTime.now(),
          dynamicData: '{bad json syntax: true,',
        ),
      );

      // Card with completely empty dynamicData
      await dao.into(dao.vaultItems).insert(
        VaultItem(
          id: 'empty-dynamic-data',
          collectionType: 'mtg',
          name: 'Empty Dynamic Data Card',
          flavorName: null,
          setOrSeries: 'TEST',
          imageUrl: '',
          acquiredPrice: 1.0,
          acquiredDate: DateTime.now(),
          quantity: 1,
          condition: 'NM',
          isGraded: false,
          isAltered: false,
          isMisprint: false,
          isSigned: false,
          personalNotes: null,
          primaryBinderId: null,
          currentMarketPrice: 1.0,
          lastPriceUpdate: DateTime.now(),
          dynamicData: '',
        ),
      );

      // Card with null fields inside JSON
      await dao.into(dao.vaultItems).insert(
        createTestCard(
          id: 'null-fields-json',
          name: 'Null Fields Card',
          dynamicDataMap: {
            'colors': null,
            'card_faces': null,
            'oracle_text': null,
            'mana_cost': null,
            'cmc': null,
          },
        ),
      );

      final filter = const MtgFilterState(colors: {'W', 'U'});
      final results = await dao.getItemsByCollection('mtg', mtgFilter: filter);

      // Corrupted items must be cleanly skipped without throwing an unhandled exception
      expect(results.any((c) => c.id == 'malformed-json'), isFalse);
      expect(results.any((c) => c.id == 'empty-dynamic-data'), isFalse);
    });

    test('3.4 Simultaneous cross-game mutations keep collections strictly isolated', () async {
      // Batch insert cross-game items
      await dao.batch((b) {
        b.insertAll(dao.vaultItems, [
          createTestCard(
            id: 'batch-mtg-1',
            name: 'Sol Ring Batch',
            collectionType: 'mtg',
            dynamicDataMap: {'colors': <String>[], 'cmc': 1},
          ),
          createTestCard(
            id: 'batch-lorcana-1',
            name: 'Mickey Mouse - Brave Little Tailor',
            collectionType: 'lorcana',
            dynamicDataMap: {'ink_cost': 8, 'lore': 4},
          ),
        ]);
      });

      // MTG query
      final mtgFilter = const MtgFilterState(cmcRange: RangeValues(1, 2));
      final mtgItems = await dao.getItemsByCollection('mtg', mtgFilter: mtgFilter);
      expect(mtgItems.any((i) => i.id == 'batch-mtg-1'), isTrue);
      expect(mtgItems.any((i) => i.collectionType != 'mtg'), isFalse);

      // Lorcana query
      final lorcanaItems = await dao.getItemsByCollection('lorcana');
      expect(lorcanaItems.any((i) => i.id == 'batch-lorcana-1'), isTrue);
      expect(lorcanaItems.any((i) => i.collectionType != 'lorcana'), isFalse);
    });
  });

  group('4. Stream Emission Reactivity & Concurrency', () {
    test('4.1 Sequential filter updates emit expected subsets cleanly without race conditions', () async {
      // Seed 5 distinct MTG cards
      await dao.into(dao.vaultItems).insert(
        createTestCard(
          id: 'mtg-w',
          name: 'Savannah Lions',
          dynamicDataMap: {'colors': ['W'], 'cmc': 1, 'oracle_text': 'Vigilance'},
        ),
      );
      await dao.into(dao.vaultItems).insert(
        createTestCard(
          id: 'mtg-u',
          name: 'Counterspell',
          dynamicDataMap: {'colors': ['U'], 'cmc': 2, 'oracle_text': 'Counter target spell'},
        ),
      );
      await dao.into(dao.vaultItems).insert(
        createTestCard(
          id: 'mtg-b',
          name: 'Dark Ritual',
          dynamicDataMap: {'colors': ['B'], 'cmc': 1, 'oracle_text': 'Add {B}{B}{B}'},
        ),
      );
      await dao.into(dao.vaultItems).insert(
        createTestCard(
          id: 'mtg-r',
          name: 'Lightning Bolt',
          dynamicDataMap: {'colors': ['R'], 'cmc': 1, 'oracle_text': 'Deal 3 damage'},
        ),
      );
      await dao.into(dao.vaultItems).insert(
        createTestCard(
          id: 'mtg-g',
          name: 'Birds of Paradise',
          dynamicDataMap: {'colors': ['G'], 'cmc': 1, 'oracle_text': 'Flying, tap: add one mana of any color'},
        ),
      );

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(dao),
          activeGameContextProvider.overrideWith((ref) => 'mtg'),
          vaultShowCatalogProvider.overrideWith((ref) => false),
          vaultSearchQueryProvider.overrideWith((ref) => ''),
          vaultPaginationLimitProvider.overrideWith((ref) => 50),
        ],
      );
      addTearDown(container.dispose);

      // Initial state: all 5 cards
      var items = await container.read(vaultItemsStreamProvider.future);
      expect(items.length, equals(5));

      // Filter 1: White
      container.read(mtgFilterProvider.notifier).state =
          const MtgFilterState(colors: {'W'}, colorMatchMode: ColorMatchMode.including);
      items = await container.read(vaultItemsStreamProvider.future);
      expect(items.map((i) => i.id).toList(), equals(['mtg-w']));

      // Filter 2: Blue
      container.read(mtgFilterProvider.notifier).state =
          const MtgFilterState(colors: {'U'}, colorMatchMode: ColorMatchMode.including);
      items = await container.read(vaultItemsStreamProvider.future);
      expect(items.map((i) => i.id).toList(), equals(['mtg-u']));

      // Filter 3: Black
      container.read(mtgFilterProvider.notifier).state =
          const MtgFilterState(colors: {'B'}, colorMatchMode: ColorMatchMode.including);
      items = await container.read(vaultItemsStreamProvider.future);
      expect(items.map((i) => i.id).toList(), equals(['mtg-b']));

      // Filter 4: Oracle text "Counter"
      container.read(mtgFilterProvider.notifier).state =
          const MtgFilterState(oracleTextClauses: ['Counter']);
      items = await container.read(vaultItemsStreamProvider.future);
      expect(items.map((i) => i.id).toList(), equals(['mtg-u']));

      // Filter 5: Reset back to all
      container.read(mtgFilterProvider.notifier).state = const MtgFilterState();
      items = await container.read(vaultItemsStreamProvider.future);
      expect(items.length, equals(5));
    });

    test('4.2 Stress test: 20 rapid back-to-back updates resolve cleanly without deadlock', () async {
      await dao.into(dao.vaultItems).insert(
        createTestCard(
          id: 'card-a',
          name: 'Card A',
          dynamicDataMap: {'colors': ['W'], 'cmc': 1},
        ),
      );
      await dao.into(dao.vaultItems).insert(
        createTestCard(
          id: 'card-b',
          name: 'Card B',
          dynamicDataMap: {'colors': ['U'], 'cmc': 2},
        ),
      );

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(dao),
          activeGameContextProvider.overrideWith((ref) => 'mtg'),
          vaultShowCatalogProvider.overrideWith((ref) => false),
          vaultSearchQueryProvider.overrideWith((ref) => ''),
          vaultPaginationLimitProvider.overrideWith((ref) => 50),
        ],
      );
      addTearDown(container.dispose);

      // Keep stream alive
      final sub = container.listen(vaultItemsStreamProvider, (previous, next) {});
      addTearDown(sub.close);

      // Rapidly flip between filters 20 times in a tight loop
      for (int i = 0; i < 20; i++) {
        final color = (i % 2 == 0) ? 'W' : 'U';
        container.read(mtgFilterProvider.notifier).state =
            MtgFilterState(colors: {color}, colorMatchMode: ColorMatchMode.including);
      }

      // Final state: set to 'W'
      container.read(mtgFilterProvider.notifier).state =
          const MtgFilterState(colors: {'W'}, colorMatchMode: ColorMatchMode.including);

      // Allow microtasks and stream controllers to flush
      await Future.delayed(const Duration(milliseconds: 100));

      final finalItems = await container.read(vaultItemsStreamProvider.future);
      expect(finalItems.length, equals(1));
      expect(finalItems.first.id, equals('card-a'));
    });

    test('4.3 Active stream reacts to live database insertions matching current filter', () async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(dao),
          activeGameContextProvider.overrideWith((ref) => 'mtg'),
          vaultShowCatalogProvider.overrideWith((ref) => false),
          vaultSearchQueryProvider.overrideWith((ref) => ''),
          vaultPaginationLimitProvider.overrideWith((ref) => 50),
        ],
      );
      addTearDown(container.dispose);

      // Filter for Red cards
      container.read(mtgFilterProvider.notifier).state =
          const MtgFilterState(colors: {'R'}, colorMatchMode: ColorMatchMode.including);

      final emissions = <List<VaultItem>>[];
      final sub = container.listen<AsyncValue<List<VaultItem>>>(
        vaultItemsStreamProvider,
        (_, next) {
          next.whenData((items) => emissions.add(items));
        },
        fireImmediately: true,
      );
      addTearDown(sub.close);

      await Future.delayed(const Duration(milliseconds: 50));
      expect(emissions.last, isEmpty);

      // Insert matching Red card
      await dao.into(dao.vaultItems).insert(
        createTestCard(
          id: 'red-phoenix',
          name: 'Arclight Phoenix',
          dynamicDataMap: {'colors': ['R'], 'cmc': 4},
        ),
      );

      await Future.delayed(const Duration(milliseconds: 50));
      expect(emissions.last.length, equals(1));
      expect(emissions.last.first.id, equals('red-phoenix'));

      // Insert non-matching Blue card
      await dao.into(dao.vaultItems).insert(
        createTestCard(
          id: 'blue-bird',
          name: 'Murktide Regent',
          dynamicDataMap: {'colors': ['U'], 'cmc': 7},
        ),
      );

      await Future.delayed(const Duration(milliseconds: 50));
      expect(emissions.last.length, equals(1), reason: 'Non-matching card must not appear in stream');
    });

    test('4.4 Game context switching cleanly disables and reenables MTG filtering', () async {
      await dao.into(dao.vaultItems).insert(
        createTestCard(
          id: 'mtg-sol-ring',
          name: 'Sol Ring',
          collectionType: 'mtg',
          dynamicDataMap: {'colors': <String>[], 'cmc': 1},
        ),
      );
      await dao.into(dao.vaultItems).insert(
        createTestCard(
          id: 'poke-charizard',
          name: 'Charizard',
          collectionType: 'pokemon',
          dynamicDataMap: {'types': ['Fire']},
        ),
      );

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(dao),
          activeGameContextProvider.overrideWith((ref) => 'mtg'),
          vaultShowCatalogProvider.overrideWith((ref) => false),
          vaultSearchQueryProvider.overrideWith((ref) => ''),
          vaultPaginationLimitProvider.overrideWith((ref) => 50),
        ],
      );
      addTearDown(container.dispose);

      // In MTG context: returns Sol Ring
      final mtgItems = await container.read(vaultItemsStreamProvider.future);
      expect(mtgItems.map((c) => c.id).toList(), equals(['mtg-sol-ring']));

      // Switch context to Pokemon
      container.read(activeGameContextProvider.notifier).state = 'pokemon';
      await Future.delayed(const Duration(milliseconds: 50));

      final pokeItems = await container.read(vaultItemsStreamProvider.future);
      expect(pokeItems.map((c) => c.id).toList(), equals(['poke-charizard']));
    });

    test('4.5 Simultaneous search query and MTG filter combination', () async {
      await dao.into(dao.vaultItems).insert(
        createTestCard(
          id: 'jace-mind-sculptor',
          name: 'Jace, the Mind Sculptor',
          dynamicDataMap: {'colors': ['U'], 'cmc': 4, 'type_line': 'Legendary Planeswalker — Jace'},
        ),
      );
      await dao.into(dao.vaultItems).insert(
        createTestCard(
          id: 'jace-beleren',
          name: 'Jace Beleren',
          dynamicDataMap: {'colors': ['U'], 'cmc': 3, 'type_line': 'Legendary Planeswalker — Jace'},
        ),
      );
      await dao.into(dao.vaultItems).insert(
        createTestCard(
          id: 'chandra-torch',
          name: 'Chandra, Torch of Defiance',
          dynamicDataMap: {'colors': ['R'], 'cmc': 4, 'type_line': 'Legendary Planeswalker — Chandra'},
        ),
      );

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(dao),
          activeGameContextProvider.overrideWith((ref) => 'mtg'),
          vaultShowCatalogProvider.overrideWith((ref) => false),
          vaultSearchQueryProvider.overrideWith((ref) => 'Jace'),
          vaultPaginationLimitProvider.overrideWith((ref) => 50),
        ],
      );
      addTearDown(container.dispose);

      // Search = Jace, Filter = CMC 4..4
      container.read(mtgFilterProvider.notifier).state =
          const MtgFilterState(cmcRange: RangeValues(4, 4));

      final results = await container.read(vaultItemsStreamProvider.future);
      expect(results.length, equals(1));
      expect(results.first.id, equals('jace-mind-sculptor'));
    });

    test('4.6 Catalog Mode toggle with active MTG filter correctly includes unowned reference items', () async {
      // Owned card (qty 1)
      await dao.into(dao.vaultItems).insert(
        createTestCard(
          id: 'owned-card',
          name: 'Owned Mythic',
          quantity: 1,
          dynamicDataMap: {'rarity': 'mythic'},
        ),
      );

      // Unowned card (qty 0)
      await dao.into(dao.vaultItems).insert(
        createTestCard(
          id: 'unowned-card',
          name: 'Unowned Mythic',
          quantity: 0,
          dynamicDataMap: {'rarity': 'mythic'},
        ),
      );

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(dao),
          activeGameContextProvider.overrideWith((ref) => 'mtg'),
          vaultShowCatalogProvider.overrideWith((ref) => false), // My Vault mode
          vaultSearchQueryProvider.overrideWith((ref) => ''),
          vaultPaginationLimitProvider.overrideWith((ref) => 50),
        ],
      );
      addTearDown(container.dispose);

      container.read(mtgFilterProvider.notifier).state =
          const MtgFilterState(rarities: {'mythic'});

      // In My Vault mode: only owned card is returned
      final vaultItems = await container.read(vaultItemsStreamProvider.future);
      expect(vaultItems.map((c) => c.id).toList(), equals(['owned-card']));

      // Toggle to Catalog mode
      container.read(vaultShowCatalogProvider.notifier).state = true;
      final catalogItems = await container.read(vaultItemsStreamProvider.future);
      expect(catalogItems.map((c) => c.id).toSet(), equals({'owned-card', 'unowned-card'}));
    });
  });
}
