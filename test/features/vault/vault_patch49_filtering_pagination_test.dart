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
import 'package:countr/features/vault/presentation/screens/vault_screen.dart';

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

  VaultItem createCardFixture({
    required String id,
    required String name,
    String collectionType = 'mtg',
    String setOrSeries = 'MH3',
    int quantity = 1,
    double price = 5.0,
    List<String> colors = const [],
    List<String> colorIdentity = const [],
    String typeLine = 'Creature',
    List<String> formats = const ['commander', 'modern'],
    Map<String, dynamic>? extraData,
  }) {
    final dynamicMap = {
      'colors': colors,
      'color_identity': colorIdentity,
      'type_line': typeLine,
      'type': typeLine,
      'legalities': {for (final f in formats) f: 'legal'},
      'rarity': 'rare',
      'released_at': '2024-06-14',
      'border_crop': 'https://cards.scryfall.io/border_crop/$id.jpg',
      ...?extraData,
    };

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
      dynamicData: jsonEncode(dynamicMap),
    );
  }

  // ===========================================================================
  // TIER 1 — ISOLATED FEATURE TESTS (R1: Full Scryfall Catalog Filtering)
  // ===========================================================================
  group('R1 — Tier 1: Isolated Catalog Filtering Features', () {
    test('R1-T1-1: Color filter for red ("R") matches red cards and excludes non-red with "r" substrings', () async {
      // Non-red cards whose dynamicData contains "rarity", "released_at", "border_crop"
      final blueCard = createCardFixture(
        id: 'blue-1',
        name: 'Counterspell',
        colors: ['U'],
        colorIdentity: ['U'],
        typeLine: 'Instant',
      );
      final greenCard = createCardFixture(
        id: 'green-1',
        name: 'Birds of Paradise',
        colors: ['G'],
        colorIdentity: ['G'],
        typeLine: 'Creature',
      );
      final redCard = createCardFixture(
        id: 'red-1',
        name: 'Lightning Bolt',
        colors: ['R'],
        colorIdentity: ['R'],
        typeLine: 'Instant',
      );

      await dao.into(dao.vaultItems).insert(blueCard);
      await dao.into(dao.vaultItems).insert(greenCard);
      await dao.into(dao.vaultItems).insert(redCard);

      final filter = const MtgFilterState(
        colors: {'R'},
        colorMatchMode: ColorMatchMode.including,
      );

      final results = await dao.getItemsByCollection('mtg', mtgFilter: filter);
      expect(results.length, equals(1));
      expect(results.first.id, equals('red-1'));
      expect(results.first.name, equals('Lightning Bolt'));
    });

    test('R1-T1-2: Multi-color filtering with ColorMatchMode.including matches multi-color cards', () async {
      final izzetCard = createCardFixture(
        id: 'izzet-1',
        name: 'Electrolyze',
        colors: ['U', 'R'],
        colorIdentity: ['U', 'R'],
        typeLine: 'Instant',
      );
      final monoRed = createCardFixture(
        id: 'red-2',
        name: 'Shock',
        colors: ['R'],
        colorIdentity: ['R'],
      );
      final monoBlue = createCardFixture(
        id: 'blue-2',
        name: 'Opt',
        colors: ['U'],
        colorIdentity: ['U'],
      );

      await dao.into(dao.vaultItems).insert(izzetCard);
      await dao.into(dao.vaultItems).insert(monoRed);
      await dao.into(dao.vaultItems).insert(monoBlue);

      final filter = const MtgFilterState(
        colors: {'U', 'R'},
        colorMatchMode: ColorMatchMode.including,
      );

      final results = await dao.getItemsByCollection('mtg', mtgFilter: filter);
      expect(results.length, equals(1));
      expect(results.first.id, equals('izzet-1'));
    });

    test('R1-T1-3: Colorless filtering matches artifacts and lands with empty colors array', () async {
      final solRing = createCardFixture(
        id: 'artifact-1',
        name: 'Sol Ring',
        colors: [],
        colorIdentity: [],
        typeLine: 'Artifact',
      );
      final coloredArtifact = createCardFixture(
        id: 'artifact-colored',
        name: 'Baleful Strix',
        colors: ['U', 'B'],
        colorIdentity: ['U', 'B'],
        typeLine: 'Artifact Creature',
      );

      await dao.into(dao.vaultItems).insert(solRing);
      await dao.into(dao.vaultItems).insert(coloredArtifact);

      final filter = const MtgFilterState(
        colors: {'C'},
        colorMatchMode: ColorMatchMode.including,
      );

      final results = await dao.getItemsByCollection('mtg', mtgFilter: filter);
      expect(results.length, equals(1));
      expect(results.first.id, equals('artifact-1'));
    });

    test('R1-T1-4: Format filter isolates cards legal in target format', () async {
      final commanderLegal = createCardFixture(
        id: 'cmd-legal',
        name: 'Command Tower',
        formats: ['commander', 'legacy', 'vintage'],
      );
      final standardOnly = createCardFixture(
        id: 'std-legal',
        name: 'Standard Staple',
        formats: ['standard', 'pioneer'],
      );

      await dao.into(dao.vaultItems).insert(commanderLegal);
      await dao.into(dao.vaultItems).insert(standardOnly);

      final filter = const MtgFilterState(
        formats: {'commander'},
      );

      final results = await dao.getItemsByCollection('mtg', mtgFilter: filter);
      expect(results.length, equals(1));
      expect(results.first.id, equals('cmd-legal'));
    });

    test('R1-T1-5: Type line filter isolates card by type string', () async {
      final creature = createCardFixture(
        id: 'type-creature',
        name: 'Llanowar Elves',
        typeLine: 'Creature — Elf Druid',
      );
      final enchantment = createCardFixture(
        id: 'type-enchantment',
        name: 'Sylvan Library',
        typeLine: 'Enchantment',
      );

      await dao.into(dao.vaultItems).insert(creature);
      await dao.into(dao.vaultItems).insert(enchantment);

      final filter = const MtgFilterState(typeLine: 'Enchantment');
      final results = await dao.getItemsByCollection('mtg', mtgFilter: filter);
      expect(results.length, equals(1));
      expect(results.first.id, equals('type-enchantment'));
    });
  });

  // ===========================================================================
  // TIER 2 — BOUNDARY & CORNER CASES (R1: 12-Item Choke, Dual-Faced, Limits)
  // ===========================================================================
  group('R1 — Tier 2: Boundary & Corner Cases', () {
    test('R1-T2-1: 60 non-red cards + 40 red cards returns all 40 red cards beyond 12-record limit', () async {
      // Seed 60 non-red cards first (which caused premature SQLite limit truncation)
      for (int i = 0; i < 60; i++) {
        await dao.into(dao.vaultItems).insert(
          createCardFixture(
            id: 'blue-batch-$i',
            name: 'Blue Specimen $i',
            colors: ['U'],
            colorIdentity: ['U'],
            typeLine: 'Sorcery',
          ),
        );
      }

      // Seed 40 red cards
      for (int i = 0; i < 40; i++) {
        await dao.into(dao.vaultItems).insert(
          createCardFixture(
            id: 'red-batch-$i',
            name: 'Red Specimen $i',
            colors: ['R'],
            colorIdentity: ['R'],
            typeLine: 'Instant',
          ),
        );
      }

      final filter = const MtgFilterState(
        colors: {'R'},
        colorMatchMode: ColorMatchMode.including,
      );

      // Query with limit 50: must return 40 red cards rather than cutting off at <= 12
      final results = await dao.getItemsByCollection('mtg', mtgFilter: filter, limit: 50);
      expect(results.length, equals(40));
      for (final card in results) {
        final dyn = jsonDecode(card.dynamicData) as Map<String, dynamic>;
        final colors = List<String>.from(dyn['colors'] as List);
        expect(colors.contains('R'), isTrue);
      }
    });

    test('R1-T2-2: Dual-faced card with red on face 0 or face 1 matches red filter', () async {
      final dfcTransform = createCardFixture(
        id: 'dfc-1',
        name: 'Delver of Secrets // Insectile Aberration',
        colors: ['U'],
        extraData: {
          'card_faces': [
            {'name': 'Delver of Secrets', 'colors': ['U']},
            {'name': 'Insectile Aberration', 'colors': ['U']},
          ],
        },
      );

      final dfcRedFace = createCardFixture(
        id: 'dfc-red',
        name: 'Vance\'s Blasting Cannons // Spitfire Bastion',
        colors: ['R'],
        extraData: {
          'card_faces': [
            {'name': 'Vance\'s Blasting Cannons', 'colors': ['R']},
            {'name': 'Spitfire Bastion', 'colors': <String>[]},
          ],
        },
      );

      await dao.into(dao.vaultItems).insert(dfcTransform);
      await dao.into(dao.vaultItems).insert(dfcRedFace);

      final filter = const MtgFilterState(
        colors: {'R'},
        colorMatchMode: ColorMatchMode.including,
      );

      final results = await dao.getItemsByCollection('mtg', mtgFilter: filter);
      expect(results.length, equals(1));
      expect(results.first.id, equals('dfc-red'));
    });

    test('R1-T2-3: Empty database returns empty result list safely', () async {
      final filter = const MtgFilterState(colors: {'W'});
      final results = await dao.getItemsByCollection('mtg', mtgFilter: filter);
      expect(results, isEmpty);
    });

    test('R1-T2-4: Filter matching zero records returns empty list without deadlock', () async {
      await dao.into(dao.vaultItems).insert(
        createCardFixture(id: 'c1', name: 'Plains', colors: ['W']),
      );

      final filter = const MtgFilterState(
        colors: {'B'},
        typeLine: 'Planeswalker',
      );

      final results = await dao.getItemsByCollection('mtg', mtgFilter: filter);
      expect(results, isEmpty);
    });

    test('R1-T2-5: Pagination window larger than match count returns exact match count', () async {
      for (int i = 0; i < 15; i++) {
        await dao.into(dao.vaultItems).insert(
          createCardFixture(
            id: 'red-$i',
            name: 'Red Spell $i',
            colors: ['R'],
          ),
        );
      }
      for (int i = 0; i < 30; i++) {
        await dao.into(dao.vaultItems).insert(
          createCardFixture(
            id: 'black-$i',
            name: 'Black Spell $i',
            colors: ['B'],
          ),
        );
      }

      final filter = const MtgFilterState(colors: {'R'});
      final results = await dao.getItemsByCollection('mtg', mtgFilter: filter, limit: 50);
      expect(results.length, equals(15));
    });
  });

  // ===========================================================================
  // TIER 3 — PAIRWISE / CROSS-FEATURE COMBINATIONS
  // ===========================================================================
  group('R1 — Tier 3: Pairwise & Cross-Feature Combinations', () {
    test('R1-T3-1: Conjoint Color ("R") + Type ("Instant") + Format ("modern") filtering', () async {
      final matchTarget = createCardFixture(
        id: 'target-card',
        name: 'Unholy Heat',
        colors: ['R'],
        colorIdentity: ['R'],
        typeLine: 'Instant',
        formats: ['modern', 'commander'],
      );
      final wrongType = createCardFixture(
        id: 'wrong-type',
        name: 'Ragavan, Nimble Pilferer',
        colors: ['R'],
        colorIdentity: ['R'],
        typeLine: 'Legendary Creature — Monkey Pirate',
        formats: ['modern', 'commander'],
      );
      final wrongColor = createCardFixture(
        id: 'wrong-color',
        name: 'Fatal Push',
        colors: ['B'],
        colorIdentity: ['B'],
        typeLine: 'Instant',
        formats: ['modern', 'commander'],
      );
      final wrongFormat = createCardFixture(
        id: 'wrong-format',
        name: 'Chaos Warp',
        colors: ['R'],
        colorIdentity: ['R'],
        typeLine: 'Instant',
        formats: ['commander', 'legacy'], // not modern
      );

      await dao.into(dao.vaultItems).insert(matchTarget);
      await dao.into(dao.vaultItems).insert(wrongType);
      await dao.into(dao.vaultItems).insert(wrongColor);
      await dao.into(dao.vaultItems).insert(wrongFormat);

      final filter = const MtgFilterState(
        colors: {'R'},
        colorMatchMode: ColorMatchMode.including,
        typeLine: 'Instant',
        formats: {'modern'},
      );

      final results = await dao.getItemsByCollection('mtg', mtgFilter: filter);
      expect(results.length, equals(1));
      expect(results.first.id, equals('target-card'));
    });

    test('R1-T3-2: ColorMatchMode comparison: exactly vs atMost vs including', () async {
      final monoRed = createCardFixture(id: 'c-r', name: 'Mono Red', colors: ['R']);
      final redGreen = createCardFixture(id: 'c-rg', name: 'Gruul', colors: ['R', 'G']);
      final redGreenWhite = createCardFixture(id: 'c-rgw', name: 'Naya', colors: ['R', 'G', 'W']);

      await dao.into(dao.vaultItems).insert(monoRed);
      await dao.into(dao.vaultItems).insert(redGreen);
      await dao.into(dao.vaultItems).insert(redGreenWhite);

      // Exactly {'R'}
      final exactFilter = const MtgFilterState(
        colors: {'R'},
        colorMatchMode: ColorMatchMode.exactly,
      );
      final exactResults = await dao.getItemsByCollection('mtg', mtgFilter: exactFilter);
      expect(exactResults.map((c) => c.id).toList(), equals(['c-r']));

      // At Most {'R', 'G'}
      final atMostFilter = const MtgFilterState(
        colors: {'R', 'G'},
        colorMatchMode: ColorMatchMode.atMost,
      );
      final atMostResults = await dao.getItemsByCollection('mtg', mtgFilter: atMostFilter);
      expect(atMostResults.map((c) => c.id).toSet(), equals({'c-r', 'c-rg'}));

      // Including {'R', 'G'}
      final includingFilter = const MtgFilterState(
        colors: {'R', 'G'},
        colorMatchMode: ColorMatchMode.including,
      );
      final includingResults = await dao.getItemsByCollection('mtg', mtgFilter: includingFilter);
      expect(includingResults.map((c) => c.id).toSet(), equals({'c-rg', 'c-rgw'}));
    });
  });

  // ===========================================================================
  // TIER 4 — REAL-WORLD WORKLOAD SCENARIOS & E2E FLOWS
  // ===========================================================================
  group('R1 — Tier 4: Real-World Workload Scenarios & E2E Flows', () {
    test('R1-T4-1: Large catalog pagination stream receives updates up to active window', () async {
      // Seed 80 mixed cards: 35 Red, 45 Non-red
      for (int i = 0; i < 45; i++) {
        await dao.into(dao.vaultItems).insert(
          createCardFixture(id: 'other-$i', name: 'Other $i', colors: ['W']),
        );
      }
      for (int i = 0; i < 35; i++) {
        await dao.into(dao.vaultItems).insert(
          createCardFixture(id: 'red-$i', name: 'Red $i', colors: ['R']),
        );
      }

      final filter = const MtgFilterState(colors: {'R'});

      // Window 1: limit 20
      final window1 = await dao.getItemsByCollection('mtg', mtgFilter: filter, limit: 20);
      expect(window1.length, equals(20));

      // Window 2: limit 50 (should return all 35 red cards without getting stuck)
      final window2 = await dao.getItemsByCollection('mtg', mtgFilter: filter, limit: 50);
      expect(window2.length, equals(35));
    });

    testWidgets('R1-T4-2: VaultScreen UI updates reactively when active filter is applied', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (int i = 0; i < 5; i++) {
        await dao.into(dao.vaultItems).insert(
          createCardFixture(id: 'blue-ui-$i', name: 'Blue UI $i', colors: ['U']),
        );
      }
      for (int i = 0; i < 5; i++) {
        await dao.into(dao.vaultItems).insert(
          createCardFixture(id: 'red-ui-$i', name: 'Red UI $i', colors: ['R']),
        );
      }

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(dao),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: VaultScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially all cards present
      expect(find.text('Red UI 0'), findsWidgets);
      expect(find.text('Blue UI 0'), findsWidgets);

      // Now apply red filter to mtgFilterProvider
      container.read(mtgFilterProvider.notifier).setFilter(const MtgFilterState(
        colors: {'R'},
        colorMatchMode: ColorMatchMode.including,
      ));
      await tester.pumpAndSettle();

      // Only red cards should remain in view
      expect(find.text('Red UI 0'), findsWidgets);
      expect(find.text('Blue UI 0'), findsNothing);
    });
  });
}
