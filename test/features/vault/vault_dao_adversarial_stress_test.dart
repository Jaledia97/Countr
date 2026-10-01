import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/presentation/providers/mtg_filter_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  VaultItem createItem({
    required String id,
    required String name,
    String collectionType = 'mtg',
    String setOrSeries = 'MH3',
    int quantity = 1,
    double price = 2.0,
    List<String> colors = const [],
    List<String> colorIdentity = const [],
    String typeLine = 'Creature',
    Map<String, dynamic>? legalities,
    String? rawDynamicData,
    Map<String, dynamic>? extraData,
  }) {
    String dynamicStr;
    if (rawDynamicData != null) {
      dynamicStr = rawDynamicData;
    } else {
      final map = {
        'colors': colors,
        'color_identity': colorIdentity,
        'type_line': typeLine,
        'type': typeLine,
        'legalities': legalities ?? {'commander': 'legal', 'modern': 'legal'},
        'rarity': 'rare',
        'released_at': '2024-06-14',
        'border_crop': 'https://cards.scryfall.io/border_crop/$id.jpg',
        ...?extraData,
      };
      dynamicStr = jsonEncode(map);
    }

    return VaultItem(
      id: id,
      collectionType: collectionType,
      name: name,
      setOrSeries: setOrSeries,
      imageUrl: 'https://cards.scryfall.io/normal/$id.jpg',
      acquiredPrice: price,
      acquiredDate: DateTime(2026, 1, 1),
      quantity: quantity,
      condition: 'NM',
      isGraded: false,
      isAltered: false,
      isMisprint: false,
      isSigned: false,
      isDeleted: false,
      personalNotes: null,
      primaryBinderId: null,
      currentMarketPrice: price,
      lastPriceUpdate: DateTime(2026, 1, 1),
      dynamicData: dynamicStr,
    );
  }

  group('Adversarial Challenge: Color Filtering Case-Sensitivity across W, U, B, R, G, C', () {
    test('Case-sensitivity prevents false positive substring collisions for all colors', () async {
      // Create adversarial cards with lowercase letters in JSON fields
      // 'w': showcase, power, claw
      // 'u': uncommon, creature, rules
      // 'b': black, border, bonus
      // 'r': rarity, rare, released_at, border_crop
      // 'g': gathering, game, graveyard
      // 'c': common, collector_number
      final trickyColorlessCard = createItem(
        id: 'colorless-tricky',
        name: 'Tricky Power Claw Booster',
        colors: [],
        extraData: {
          'rarity': 'uncommon',
          'released_at': '2023-01-01',
          'border_crop': 'https://cards.scryfall.io/border_crop/c.jpg',
          'collector_number': '123',
          'power': '2',
          'watermark': 'showcase',
          'game': 'paper',
          'rules': 'draw a card from your graveyard',
        },
      );

      final pureWhite = createItem(id: 'c-w', name: 'White Knight', colors: ['W']);
      final pureBlue = createItem(id: 'c-u', name: 'Counterspell', colors: ['U']);
      final pureBlack = createItem(id: 'c-b', name: 'Dark Ritual', colors: ['B']);
      final pureRed = createItem(id: 'c-r', name: 'Lightning Bolt', colors: ['R']);
      final pureGreen = createItem(id: 'c-g', name: 'Giant Growth', colors: ['G']);

      for (final card in [trickyColorlessCard, pureWhite, pureBlue, pureBlack, pureRed, pureGreen]) {
        await dao.into(dao.vaultItems).insert(card);
      }

      // 1. Red filter ('R') matches pureRed, excludes trickyColorlessCard despite 'r' in rarity/released_at
      final redFilter = const MtgFilterState(colors: {'R'});
      final redResults = await dao.getItemsByCollection('mtg', mtgFilter: redFilter);
      expect(redResults.map((c) => c.id).toList(), equals(['c-r']));

      // 2. White filter ('W') matches pureWhite, excludes trickyColorlessCard despite 'w' in showcase/claw/power
      final whiteFilter = const MtgFilterState(colors: {'W'});
      final whiteResults = await dao.getItemsByCollection('mtg', mtgFilter: whiteFilter);
      expect(whiteResults.map((c) => c.id).toList(), equals(['c-w']));

      // 3. Blue filter ('U') matches pureBlue, excludes trickyColorlessCard despite 'u' in uncommon/rules
      final blueFilter = const MtgFilterState(colors: {'U'});
      final blueResults = await dao.getItemsByCollection('mtg', mtgFilter: blueFilter);
      expect(blueResults.map((c) => c.id).toList(), equals(['c-u']));

      // 4. Black filter ('B') matches pureBlack, excludes trickyColorlessCard despite 'b' in booster/border
      final blackFilter = const MtgFilterState(colors: {'B'});
      final blackResults = await dao.getItemsByCollection('mtg', mtgFilter: blackFilter);
      expect(blackResults.map((c) => c.id).toList(), equals(['c-b']));

      // 5. Green filter ('G') matches pureGreen, excludes trickyColorlessCard despite 'g' in game/graveyard
      final greenFilter = const MtgFilterState(colors: {'G'});
      final greenResults = await dao.getItemsByCollection('mtg', mtgFilter: greenFilter);
      expect(greenResults.map((c) => c.id).toList(), equals(['c-g']));

      // 6. Colorless filter ('C') matches trickyColorlessCard (empty colors array), excludes colored cards
      final colorlessFilter = const MtgFilterState(colors: {'C'});
      final colorlessResults = await dao.getItemsByCollection('mtg', mtgFilter: colorlessFilter);
      expect(colorlessResults.map((c) => c.id).toList(), equals(['colorless-tricky']));
    });

    test('Color matching handles dual-faced cards where color is only on one face', () async {
      final transformCard = createItem(
        id: 'dfc-green-face',
        name: 'Mayor of Avabruck // Howlpack Alpha',
        colors: ['G'],
        extraData: {
          'card_faces': [
            {'name': 'Mayor of Avabruck', 'colors': ['G']},
            {'name': 'Howlpack Alpha', 'colors': ['G']},
          ],
        },
      );

      final frontColorlessBackRed = createItem(
        id: 'dfc-land-red',
        name: 'Vance\'s Cannons // Bastion',
        colors: [],
        extraData: {
          'card_faces': [
            {'name': 'Vance\'s Blasting Cannons', 'colors': ['R']},
            {'name': 'Spitfire Bastion', 'colors': <String>[]},
          ],
        },
      );

      await dao.into(dao.vaultItems).insert(transformCard);
      await dao.into(dao.vaultItems).insert(frontColorlessBackRed);

      // Filtering by 'R' matches dfc-land-red because card_faces[0].colors has 'R'
      final redFilter = const MtgFilterState(colors: {'R'});
      final redResults = await dao.getItemsByCollection('mtg', mtgFilter: redFilter);
      expect(redResults.map((c) => c.id).toList(), equals(['dfc-land-red']));

      // Filtering by 'G' matches dfc-green-face
      final greenFilter = const MtgFilterState(colors: {'G'});
      final greenResults = await dao.getItemsByCollection('mtg', mtgFilter: greenFilter);
      expect(greenResults.map((c) => c.id).toList(), equals(['dfc-green-face']));
    });
  });

  group('Adversarial Challenge: Multi-Color Modes (exactly vs atMost vs including)', () {
    late VaultItem cardColorless;
    late VaultItem cardWhite;
    late VaultItem cardBlue;
    late VaultItem cardBlack;
    late VaultItem cardRed;
    late VaultItem cardGreen;
    late VaultItem cardGruul; // R, G
    late VaultItem cardIzzet; // U, R
    late VaultItem cardNaya;  // R, G, W
    late VaultItem cardWubrg; // W, U, B, R, G

    setUp(() async {
      cardColorless = createItem(id: 'c-0', name: 'Sol Ring', colors: []);
      cardWhite = createItem(id: 'c-w', name: 'White Card', colors: ['W']);
      cardBlue = createItem(id: 'c-u', name: 'Blue Card', colors: ['U']);
      cardBlack = createItem(id: 'c-b', name: 'Black Card', colors: ['B']);
      cardRed = createItem(id: 'c-r', name: 'Red Card', colors: ['R']);
      cardGreen = createItem(id: 'c-g', name: 'Green Card', colors: ['G']);
      cardGruul = createItem(id: 'c-rg', name: 'Gruul Card', colors: ['R', 'G']);
      cardIzzet = createItem(id: 'c-ur', name: 'Izzet Card', colors: ['U', 'R']);
      cardNaya = createItem(id: 'c-rgw', name: 'Naya Card', colors: ['R', 'G', 'W']);
      cardWubrg = createItem(id: 'c-wubrg', name: '5-Color Card', colors: ['W', 'U', 'B', 'R', 'G']);

      for (final c in [
        cardColorless,
        cardWhite,
        cardBlue,
        cardBlack,
        cardRed,
        cardGreen,
        cardGruul,
        cardIzzet,
        cardNaya,
        cardWubrg,
      ]) {
        await dao.into(dao.vaultItems).insert(c);
      }
    });

    test('ColorMatchMode.exactly matches ONLY exact color combinations', () async {
      // 1. exactly {'R'} -> only mono-red
      final exactR = const MtgFilterState(colors: {'R'}, colorMatchMode: ColorMatchMode.exactly);
      final rResults = await dao.getItemsByCollection('mtg', mtgFilter: exactR);
      expect(rResults.map((c) => c.id).toList(), equals(['c-r']));

      // 2. exactly {'R', 'G'} -> only Gruul
      final exactRG = const MtgFilterState(colors: {'R', 'G'}, colorMatchMode: ColorMatchMode.exactly);
      final rgResults = await dao.getItemsByCollection('mtg', mtgFilter: exactRG);
      expect(rgResults.map((c) => c.id).toList(), equals(['c-rg']));

      // 3. exactly {'C'} -> only Colorless
      final exactC = const MtgFilterState(colors: {'C'}, colorMatchMode: ColorMatchMode.exactly);
      final cResults = await dao.getItemsByCollection('mtg', mtgFilter: exactC);
      expect(cResults.map((c) => c.id).toList(), equals(['c-0']));
    });

    test('ColorMatchMode.atMost matches subsets including colorless but excludes extra colors', () async {
      // 1. atMost {'R'} -> mono-red AND colorless
      final atMostR = const MtgFilterState(colors: {'R'}, colorMatchMode: ColorMatchMode.atMost);
      final rResults = await dao.getItemsByCollection('mtg', mtgFilter: atMostR);
      expect(rResults.map((c) => c.id).toSet(), equals({'c-0', 'c-r'}));

      // 2. atMost {'R', 'G'} -> colorless, mono-red, mono-green, Gruul
      final atMostRG = const MtgFilterState(colors: {'R', 'G'}, colorMatchMode: ColorMatchMode.atMost);
      final rgResults = await dao.getItemsByCollection('mtg', mtgFilter: atMostRG);
      expect(rgResults.map((c) => c.id).toSet(), equals({'c-0', 'c-r', 'c-g', 'c-rg'}));

      // 3. atMost {'C'} -> colorless only
      final atMostC = const MtgFilterState(colors: {'C'}, colorMatchMode: ColorMatchMode.atMost);
      final cResults = await dao.getItemsByCollection('mtg', mtgFilter: atMostC);
      expect(cResults.map((c) => c.id).toList(), equals(['c-0']));
    });

    test('ColorMatchMode.including matches supersets containing specified colors', () async {
      // 1. including {'R'} -> mono-red, Gruul, Izzet, Naya, WUBRG
      final incR = const MtgFilterState(colors: {'R'}, colorMatchMode: ColorMatchMode.including);
      final rResults = await dao.getItemsByCollection('mtg', mtgFilter: incR);
      expect(rResults.map((c) => c.id).toSet(), equals({'c-r', 'c-rg', 'c-ur', 'c-rgw', 'c-wubrg'}));

      // 2. including {'R', 'G'} -> Gruul, Naya, WUBRG (NOT mono-red or mono-green)
      final incRG = const MtgFilterState(colors: {'R', 'G'}, colorMatchMode: ColorMatchMode.including);
      final rgResults = await dao.getItemsByCollection('mtg', mtgFilter: incRG);
      expect(rgResults.map((c) => c.id).toSet(), equals({'c-rg', 'c-rgw', 'c-wubrg'}));

      // 3. including {'C'} -> colorless only
      final incC = const MtgFilterState(colors: {'C'}, colorMatchMode: ColorMatchMode.including);
      final cResults = await dao.getItemsByCollection('mtg', mtgFilter: incC);
      expect(cResults.map((c) => c.id).toList(), equals(['c-0']));
    });
  });

  group('Adversarial Challenge: Format Legalities and Conjunctions', () {
    test('Format legalities filter recognizes legal and restricted, rejects banned and not_legal', () async {
      final legalInCmd = createItem(
        id: 'f-cmd',
        name: 'Sol Ring',
        legalities: {'commander': 'legal', 'vintage': 'restricted', 'legacy': 'banned', 'standard': 'not_legal'},
      );
      final legalInStd = createItem(
        id: 'f-std',
        name: 'Sheoldred, the Apocalypse',
        legalities: {'standard': 'legal', 'pioneer': 'legal', 'modern': 'legal', 'commander': 'legal'},
      );
      final bannedEverywhere = createItem(
        id: 'f-banned',
        name: 'Shahrazad',
        legalities: {'vintage': 'banned', 'legacy': 'banned', 'commander': 'banned'},
      );

      await dao.into(dao.vaultItems).insert(legalInCmd);
      await dao.into(dao.vaultItems).insert(legalInStd);
      await dao.into(dao.vaultItems).insert(bannedEverywhere);

      // 1. Vintage filter matches restricted Sol Ring
      final vintageFilter = const MtgFilterState(formats: {'vintage'});
      final vintageResults = await dao.getItemsByCollection('mtg', mtgFilter: vintageFilter);
      expect(vintageResults.map((c) => c.id).toList(), equals(['f-cmd']));

      // 2. Standard filter matches Sheoldred, excludes Sol Ring and Shahrazad
      final standardFilter = const MtgFilterState(formats: {'standard'});
      final standardResults = await dao.getItemsByCollection('mtg', mtgFilter: standardFilter);
      expect(standardResults.map((c) => c.id).toList(), equals(['f-std']));

      // 3. Conjoined formats {'commander', 'modern'} requires BOTH formats to be legal
      final conjoinedFilter = const MtgFilterState(formats: {'commander', 'modern'});
      final conjoinedResults = await dao.getItemsByCollection('mtg', mtgFilter: conjoinedFilter);
      expect(conjoinedResults.map((c) => c.id).toList(), equals(['f-std']));
    });

    test('Format filter handles case variation gracefully', () async {
      final card = createItem(
        id: 'f-pauper',
        name: 'Lightning Bolt',
        legalities: {'pauper': 'legal'},
      );
      await dao.into(dao.vaultItems).insert(card);

      // Uppercase or mixed-case format filter name
      final pauperFilter = const MtgFilterState(formats: {'Pauper'});
      final results = await dao.getItemsByCollection('mtg', mtgFilter: pauperFilter);
      expect(results.length, equals(1));
      expect(results.first.id, equals('f-pauper'));
    });
  });

  group('Adversarial Challenge: Boundary Pagination with Late-Appearing Rows (120+ cards)', () {
    test('120 non-matching rows followed by 40 matching rows paginates without starvation or choking', () async {
      // Insert 120 blue cards first
      for (int i = 0; i < 120; i++) {
        await dao.into(dao.vaultItems).insert(
          createItem(
            id: 'blue-$i',
            name: 'Blue Specimen $i',
            colors: ['U'],
            quantity: 1,
          ),
        );
      }

      // Insert 40 red cards late in the dataset
      for (int i = 0; i < 40; i++) {
        await dao.into(dao.vaultItems).insert(
          createItem(
            id: 'red-$i',
            name: 'Red Late Specimen $i',
            colors: ['R'],
            quantity: 1,
          ),
        );
      }

      final redFilter = const MtgFilterState(
        colors: {'R'},
        colorMatchMode: ColorMatchMode.including,
      );

      // Page 1: limit 15, offset 0 -> returns first 15 red cards
      final page1 = await dao.getItemsByCollection('mtg', mtgFilter: redFilter, limit: 15, offset: 0);
      expect(page1.length, equals(15));
      expect(page1.every((c) => c.id.startsWith('red-')), isTrue);

      // Page 2: limit 20, offset 15 -> returns next 20 red cards (15..34)
      final page2 = await dao.getItemsByCollection('mtg', mtgFilter: redFilter, limit: 20, offset: 15);
      expect(page2.length, equals(20));
      expect(page2.every((c) => c.id.startsWith('red-')), isTrue);

      // Page 3: limit 20, offset 35 -> returns last 5 red cards (35..39)
      final page3 = await dao.getItemsByCollection('mtg', mtgFilter: redFilter, limit: 20, offset: 35);
      expect(page3.length, equals(5));
      expect(page3.every((c) => c.id.startsWith('red-')), isTrue);

      // Verification of watchItemsByCollection stream pagination under same condition
      final streamResults = await dao
          .watchItemsByCollection('mtg', mtgFilter: redFilter, limit: 30, offset: 0)
          .first;
      expect(streamResults.length, equals(30));
      expect(streamResults.every((c) => c.id.startsWith('red-')), isTrue);
    });

    test('Boundary pagination with ColorMatchMode.atMost where SQLite stage 1 pushdown is wide', () async {
      // In atMost {'R'}, stage 1 does not filter by color pushdown, so all rows are evaluated in Stage 2
      // 100 blue cards + 25 red cards
      for (int i = 0; i < 100; i++) {
        await dao.into(dao.vaultItems).insert(
          createItem(id: 'blue-stage2-$i', name: 'Blue Card $i', colors: ['U']),
        );
      }
      for (int i = 0; i < 25; i++) {
        await dao.into(dao.vaultItems).insert(
          createItem(id: 'red-stage2-$i', name: 'Red Card $i', colors: ['R']),
        );
      }

      final atMostRed = const MtgFilterState(
        colors: {'R'},
        colorMatchMode: ColorMatchMode.atMost,
      );

      // Limit 20 should collect 20 red cards despite starting after 100 blue cards
      final results = await dao.getItemsByCollection('mtg', mtgFilter: atMostRed, limit: 20);
      expect(results.length, equals(20));
      expect(results.every((c) => c.id.startsWith('red-stage2-')), isTrue);
    });
  });

  group('Adversarial Challenge: Malformed dynamicData JSON Strings', () {
    test('Handles malformed, corrupted, empty, or non-object JSON without SQLite errors or crashes', () async {
      final malformedCards = [
        createItem(id: 'bad-1', name: 'Truncated JSON', rawDynamicData: '{"name": "broken", "colors": ['),
        createItem(id: 'bad-2', name: 'Unquoted key', rawDynamicData: '{name: broken}'),
        createItem(id: 'bad-3', name: 'Empty string', rawDynamicData: ''),
        createItem(id: 'bad-4', name: 'Whitespace string', rawDynamicData: '   '),
        createItem(id: 'bad-5', name: 'Raw string literal', rawDynamicData: '"just a string"'),
        createItem(id: 'bad-6', name: 'JSON array not object', rawDynamicData: '["item1", "item2"]'),
        createItem(id: 'bad-7', name: 'Number literal', rawDynamicData: '42.5'),
        createItem(id: 'bad-8', name: 'Null values for expected collections', rawDynamicData: '{"colors": null, "legalities": null, "card_faces": null}'),
        createItem(id: 'bad-9', name: 'String instead of list for colors', rawDynamicData: '{"colors": "red", "legalities": "legal"}'),
        createItem(id: 'bad-10', name: 'SQL Injection attempt in JSON', rawDynamicData: '{"colors": ["\'); DROP TABLE vault_items;--"]}'),
      ];

      for (final card in malformedCards) {
        await dao.into(dao.vaultItems).insert(card);
      }

      // Add one legitimate red card to ensure query executes and finds valid records
      final validCard = createItem(id: 'good-red', name: 'Real Red Card', colors: ['R']);
      await dao.into(dao.vaultItems).insert(validCard);

      // 1. Color query with active filter does not throw on bad JSON
      final redFilter = const MtgFilterState(colors: {'R'});
      expect(() async {
        final results = await dao.getItemsByCollection('mtg', mtgFilter: redFilter);
        expect(results.length, equals(1));
        expect(results.first.id, equals('good-red'));
      }, returnsNormally);

      // 2. Format query does not throw on bad JSON
      final cmdFilter = const MtgFilterState(formats: {'commander'});
      expect(() async {
        final results = await dao.getItemsByCollection('mtg', mtgFilter: cmdFilter);
        expect(results.length, equals(1));
        expect(results.first.id, equals('good-red'));
      }, returnsNormally);

      // 3. watchItemsByCollection stream does not emit errors or crash
      final streamResult = await dao.watchItemsByCollection('mtg', mtgFilter: redFilter).first;
      expect(streamResult.length, equals(1));
      expect(streamResult.first.id, equals('good-red'));
    });
  });
}
