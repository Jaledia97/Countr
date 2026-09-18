import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_card.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_tile.dart';

import 'mtg_filter_contract.dart';
import 'phase_3_9_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late VaultDao dao;

  setUp(() async {
    db = createPhase39TestDatabase();
    dao = db.vaultDao;
    await seedPhase39Catalog(dao);
  });

  tearDown(() async {
    await db.close();
  });

  Widget wrapWithHarness(
    Widget child, {
    UserPersona persona = UserPersona.investor,
  }) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        vaultDaoProvider.overrideWithValue(dao),
        userPersonaProvider.overrideWith((ref) => persona),
        cardDisplayLayoutProvider.overrideWith((ref) => CardDisplayLayout.grid),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: child,
        ),
      ),
    );
  }

  group('Tier 4: Real-World Application Workloads & End-to-End User Journeys', () {
    // -------------------------------------------------------------------------
    // Scenario 1: Secret Lair Collector Journey
    // -------------------------------------------------------------------------
    testWidgets('Scenario 1: Secret Lair Collector Journey (sld search, flavor name, unlisted pricing, 3x badge)', (tester) async {
      // 1. Seed database with Secret Lair drop cards
      final sldSolRing = createPhase39Card(
        id: 'sld-the-one-ring',
        name: 'Sol Ring',
        flavorName: 'The One Ring',
        setOrSeries: 'Secret Lair Drop: Special Guests',
        quantity: 3,
        currentMarketPrice: 0.0,
        dynamicDataMap: {
          'flavor_name': 'The One Ring',
          'set': 'sld',
          'set_name': 'Secret Lair Drop: Special Guests',
          'collector_number': '1001',
          'image_uris': {
            'normal': 'https://cards.scryfall.io/normal/front/sld-ring.jpg',
            'small': 'https://cards.scryfall.io/small/front/sld-ring.jpg',
          },
          'prices': {'usd': '0.00', 'usd_foil': null, 'eur': '0.00'}, // Zero/missing price -> Unlisted
        },
      );

      final sldLlanowar = createPhase39Card(
        id: 'sld-llanowar',
        name: 'Llanowar Elves',
        flavorName: 'Elves of Deep Shadow',
        setOrSeries: 'Secret Lair Drop',
        quantity: 1,
        currentMarketPrice: 24.50,
        dynamicDataMap: {
          'flavor_name': 'Elves of Deep Shadow',
          'set': 'sld',
          'set_name': 'Secret Lair Drop',
          'collector_number': '1002',
          'image_uris': {
            'normal': 'https://cards.scryfall.io/normal/front/sld-elves.jpg',
            'small': 'https://cards.scryfall.io/small/front/sld-elves.jpg',
          },
          'prices': {'usd': '24.50'},
        },
      );

      final standardCard = createPhase39Card(
        id: 'm21-sol-ring',
        name: 'Sol Ring',
        setOrSeries: 'Core Set 2021',
        quantity: 1,
        currentMarketPrice: 1.50,
        dynamicDataMap: {
          'set': 'm21',
          'set_name': 'Core Set 2021',
          'collector_number': '240',
          'prices': {'usd': '1.50'},
        },
      );

      final allVaultItems = [sldSolRing, sldLlanowar, standardCard];

      // 2. Secret Lair set code search ('sld')
      final sldResults = allVaultItems.where((item) {
        final rawJson = jsonDecode(item.dynamicData.isEmpty ? '{}' : item.dynamicData) as Map<String, dynamic>;
        final setCode = (rawJson['set'] ?? '').toString().toLowerCase();
        return setCode == 'sld';
      }).toList();

      expect(sldResults.length, equals(2));
      expect(sldResults.map((e) => e.id), containsAll(['sld-the-one-ring', 'sld-llanowar']));

      // 3. Flavor name lookup ('The One Ring' and 'Elves of Deep Shadow')
      const flavorQuery = 'The One Ring';
      final flavorMatches = allVaultItems.where((item) {
        final rawJson = jsonDecode(item.dynamicData.isEmpty ? '{}' : item.dynamicData) as Map<String, dynamic>;
        final flavor = (rawJson['flavor_name'] ?? '').toString().toLowerCase();
        return flavor.contains(flavorQuery.toLowerCase());
      }).toList();

      expect(flavorMatches.length, equals(1));
      expect(flavorMatches.first.id, equals('sld-the-one-ring'));

      // 4. Verify unlisted pricing fallback for sldSolRing
      final rawSldRingJson = jsonDecode(sldSolRing.dynamicData.isEmpty ? '{}' : sldSolRing.dynamicData) as Map<String, dynamic>;
      final ringPrices = rawSldRingJson['prices'] as Map<String, dynamic>?;
      final ringPriceVal = resolveHierarchicalPrice(ringPrices);
      expect(ringPriceVal, equals(0.0));
      expect(formatMarketPriceLabel(ringPriceVal), equals('Unlisted'));

      // 5. Verify 3x duplicate badge in 3-column singles grid
      await tester.pumpWidget(wrapWithHarness(
        Center(
          child: SizedBox(
            width: 180,
            height: 260,
            child: VaultItemTile(
              item: sldSolRing,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final badgeFinder = find.byKey(Key('vault_tile_duplicate_badge_${sldSolRing.id}'));
      expect(badgeFinder, findsOneWidget);
      expect(find.descendant(of: badgeFinder, matching: find.text('3x')), findsOneWidget);
      expect(find.text('Check'), findsNothing);

      // 6. Inspect inside CardDetailSheet
      await tester.pumpWidget(wrapWithHarness(
        CardDetailSheet(item: sldSolRing),
      ));
      await tester.pumpAndSettle();

      // Sol Ring details displayed with flavor name
      expect(find.text('Sol Ring'), findsWidgets);
      expect(find.text('The One Ring'), findsWidgets);
      expect(find.text('Check'), findsNothing);
    });

    // -------------------------------------------------------------------------
    // Scenario 2: Universes Beyond Commander Filter
    // -------------------------------------------------------------------------
    testWidgets('Scenario 2: Universes Beyond Commander Filter (UB identity, CMC slider, reactive DAO, thumbnails)', (tester) async {
      // 1. Target criteria: Commander color identity Esper {W, U, B}, UB treatment = true, CMC between 2.0 and 4.0
      const commanderColors = {'W', 'U', 'B'};
      const filter = MtgFilterState(
        isUniversesBeyond: true,
        colorMatchMode: ColorMatchMode.commander,
        colors: commanderColors,
        cmcRange: RangeValues(2.0, 4.0),
      );

      // 2. Seed initial card collection
      final card1 = createPhase39Card(
        id: 'ub-esper-cmc3',
        name: 'Inquisitor Greyfax',
        dynamicDataMap: {
          'is_universes_beyond': true,
          'colors': ['W', 'U', 'B'],
          'cmc': 3.0,
          'image_uris': {
            'normal': 'https://cards.scryfall.io/normal/front/greyfax.jpg',
            'small': 'https://cards.scryfall.io/small/front/greyfax.jpg',
          },
        },
      );

      final card2 = createPhase39Card(
        id: 'ub-green-cmc3',
        name: 'Gimli, Counter of Kills',
        dynamicDataMap: {
          'is_universes_beyond': true,
          'colors': ['R', 'G'], // Contains Red/Green not in Esper
          'cmc': 3.0,
        },
      );

      final card3 = createPhase39Card(
        id: 'regular-esper-cmc3',
        name: 'Esper Charm',
        dynamicDataMap: {
          'is_universes_beyond': false, // Not Universes Beyond
          'colors': ['W', 'U', 'B'],
          'cmc': 3.0,
        },
      );

      final card4 = createPhase39Card(
        id: 'ub-esper-cmc5',
        name: 'The Golden Throne',
        dynamicDataMap: {
          'is_universes_beyond': true,
          'colors': <String>[], // Colorless fits in Esper, but CMC is 5.0 (outside 2-4)
          'cmc': 5.0,
        },
      );

      final initialCards = [card1, card2, card3, card4];
      final matches = initialCards.where(filter.matches).toList();

      expect(matches.length, equals(1));
      expect(matches.first.id, equals('ub-esper-cmc3'));

      // 3. Verify reactive DAO update when a new matching UB card is inserted
      final initialCount = (await dao.getItemsByCollection('mtg')).length;
      await dao.into(dao.vaultItems).insertOnConflictUpdate(card1);
      await dao.into(dao.vaultItems).insertOnConflictUpdate(card2);

      final itemsBefore = await dao.getItemsByCollection('mtg');
      expect(itemsBefore.length, equals(initialCount + 2));

      // Insert new matching card
      final card5 = createPhase39Card(
        id: 'ub-esper-cmc2',
        name: 'Cyberman Patrol',
        dynamicDataMap: {
          'is_universes_beyond': true,
          'colors': ['U', 'B'],
          'cmc': 2.0,
          'image_uris': {
            'normal': 'https://cards.scryfall.io/normal/front/cyberman.jpg',
            'small': 'https://cards.scryfall.io/small/front/cyberman.jpg',
          },
        },
      );

      await dao.into(dao.vaultItems).insertOnConflictUpdate(card5);
      final itemsAfter = await dao.getItemsByCollection('mtg');
      expect(itemsAfter.length, equals(initialCount + 3));

      final updatedMatches = itemsAfter.where(filter.matches).toList();
      expect(updatedMatches.map((c) => c.id), containsAll(['ub-esper-cmc3', 'ub-esper-cmc2']));

      // 4. Verify list view (VaultItemTile) displays thumbnails
      await tester.pumpWidget(wrapWithHarness(
        ListView(
          children: [
            SizedBox(height: 220, child: VaultItemTile(item: card1)),
            SizedBox(height: 220, child: VaultItemTile(item: card5)),
          ],
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Inquisitor Greyfax'), findsWidgets);
      expect(find.text('Cyberman Patrol'), findsWidgets);
      expect(find.byType(VaultItemTile), findsNWidgets(2));
    });

    // -------------------------------------------------------------------------
    // Scenario 3: Adventure Card Inspection
    // -------------------------------------------------------------------------
    testWidgets('Scenario 3: Adventure Card Inspection (Grid tap, rules box, flip absence, swipe to DFC, flip DFC)', (tester) async {
      // 1. Seed Adventure card and DFC card
      final adventureJson = createScryfallAdventureJson(
        id: 'adv-borrower',
        name: 'Brazen Borrower // Petty Theft',
      );
      // Enrich with full card_faces and oracle text for inspection
      adventureJson['oracle_text'] =
          'Flash\nFlying\nBrazen Borrower can block only creatures with flying. // Return target nonland permanent an opponent controls to its owner\'s hand.';
      adventureJson['card_faces'] = [
        {
          'name': 'Brazen Borrower',
          'mana_cost': '{1}{U}{U}',
          'type_line': 'Creature — Faerie Rogue',
          'oracle_text': 'Flash\nFlying\nBrazen Borrower can block only creatures with flying.',
          'power': '3',
          'toughness': '1',
        },
        {
          'name': 'Petty Theft',
          'mana_cost': '{1}{U}',
          'type_line': 'Instant — Adventure',
          'oracle_text': 'Return target nonland permanent an opponent controls to its owner\'s hand.',
        },
      ];

      final dfcJson = createScryfallDfcJson(
        id: 'dfc-nicol-bolas',
        name: 'Nicol Bolas, the Ravager // Nicol Bolas, the Arisen',
      );
      dfcJson['card_faces'] = [
        {
          'name': 'Nicol Bolas, the Ravager',
          'mana_cost': '{1}{U}{B}{R}',
          'type_line': 'Legendary Creature — Elder Dragon',
          'oracle_text': 'Flying\nWhen Nicol Bolas, the Ravager enters the battlefield, each opponent discards a card.',
          'image_uris': {'normal': 'https://cards.scryfall.io/normal/front/bolas_front.jpg'},
        },
        {
          'name': 'Nicol Bolas, the Arisen',
          'type_line': 'Legendary Planeswalker — Bolas',
          'oracle_text': '+2: Draw two cards.\n-3: Deal 10 damage to target creature or planeswalker.',
          'image_uris': {'normal': 'https://cards.scryfall.io/normal/front/bolas_back.jpg'},
        }
      ];
      dfcJson['back_image_url'] = 'https://cards.scryfall.io/normal/front/bolas_back.jpg';

      final adventureCard = createPhase39Card(
        id: 'adv-borrower',
        name: 'Brazen Borrower // Petty Theft',
        dynamicDataMap: adventureJson,
      );

      final dfcCard = createPhase39Card(
        id: 'dfc-nicol-bolas',
        name: 'Nicol Bolas, the Ravager // Nicol Bolas, the Arisen',
        dynamicDataMap: dfcJson,
      );

      final cards = [adventureCard, dfcCard];

      // 2. Mount swiping harness at index 0 (Adventure card)
      await tester.pumpWidget(wrapWithHarness(
        CardDetailSwipingTestHarness(
          items: cards,
          initialIndex: 0,
        ),
      ));
      await tester.pumpAndSettle();

      // Verify Adventure layout:
      // - Both creature and adventure spell details are displayed
      expect(find.text('Brazen Borrower // Petty Theft'), findsWidgets);
      expect(find.textContaining('Return target nonland permanent'), findsWidgets);
      // - Flip button MUST NOT be present for Adventure cards
      expect(find.byKey(const Key('card_detail_flip_button')), findsNothing);

      // 3. Tap swipe next to transition to DFC card (index 1)
      await tester.tap(find.byKey(const Key('swipe_next_button')));
      await tester.pumpAndSettle();

      // Verify DFC layout:
      // - Front face name and rules displayed
      expect(find.text('Nicol Bolas, the Ravager // Nicol Bolas, the Arisen'), findsWidgets);
      expect(find.textContaining('enters the battlefield'), findsWidgets);

      // - Flip button MUST be present for DFC cards
      final flipFinder = find.byKey(const Key('card_detail_flip_button'));
      expect(flipFinder, findsOneWidget);

      // 4. Tap flip button to reveal back face
      await tester.tap(flipFinder);
      await tester.pump(const Duration(milliseconds: 200));

      // - Back face rules displayed
      expect(find.textContaining('Draw two cards'), findsWidgets);
    });

    // -------------------------------------------------------------------------
    // Scenario 4: Continuous Vault Swiping & Background Sync
    // -------------------------------------------------------------------------
    testWidgets('Scenario 4: Continuous Vault Swiping & Background Sync (20 cards, swipe 10, offset sync, dismiss)', (tester) async {
      // 1. Generate a 20-card Vault collection
      final twentyCards = List.generate(20, (i) {
        return createPhase39Card(
          id: 'card-$i',
          name: 'Card Number $i',
          currentMarketPrice: (i + 1).toDouble(),
          dynamicDataMap: {
            'cmc': i.toDouble(),
            'prices': {'usd': '${i + 1}.00'},
          },
        );
      });

      final scrollCtrl = ScrollController();
      int lastReportedIndex = 0;
      bool isModalOpen = true;
      StateSetter? modalSetState;

      // 2. Mount background list with 20 items and foreground modal in a Stack
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              modalSetState = setState;
              return Stack(
                children: [
                  SizedBox(
                    width: 300,
                    child: ListView.builder(
                      controller: scrollCtrl,
                      itemCount: 20,
                      itemBuilder: (ctx, i) => SizedBox(
                        height: 120,
                        child: Text('Row $i'),
                      ),
                    ),
                  ),
                  if (isModalOpen)
                    Positioned.fill(
                      child: ProviderScope(
                        overrides: [
                          appDatabaseProvider.overrideWithValue(db),
                          vaultDaoProvider.overrideWithValue(dao),
                          userPersonaProvider.overrideWith((ref) => UserPersona.investor),
                          cardDisplayLayoutProvider.overrideWith((ref) => CardDisplayLayout.grid),
                        ],
                        child: CardDetailSwipingTestHarness(
                          items: twentyCards,
                          initialIndex: 0,
                          backgroundScrollController: scrollCtrl,
                          onPageChanged: (idx) {
                            lastReportedIndex = idx;
                          },
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(scrollCtrl.offset, equals(0.0));
      expect(lastReportedIndex, equals(0));

      // 3. Continuously swipe through 10 cards
      for (int step = 1; step <= 10; step++) {
        await tester.tap(find.byKey(const Key('swipe_next_button')));
        await tester.pumpAndSettle();
        expect(lastReportedIndex, equals(step));
      }

      // 4. Verify background scroll controller offset synchronized to index 10 (10 * 120.0 = 1200.0)
      expect(scrollCtrl.offset, closeTo(1200.0, 1.0));
      expect(find.text('Card Number 10'), findsWidgets);

      // 5. Dismiss swiper modal (set isModalOpen to false)
      modalSetState!(() {
        isModalOpen = false;
      });
      await tester.pumpAndSettle();

      // Underlying scroll offset remains preserved at 1200.0 without jumping back to 0.0
      expect(scrollCtrl.offset, closeTo(1200.0, 1.0));
      expect(find.text('Row 10'), findsWidgets);

      scrollCtrl.dispose();
    });

    // -------------------------------------------------------------------------
    // Scenario 5: FullScreen Immersive Zoom & Flip Flow
    // -------------------------------------------------------------------------
    testWidgets('Scenario 5: FullScreen Immersive Zoom & Flip Flow (Index 4, zoom, swipe next, foil toggle, flip face)', (tester) async {
      // 1. Seed 6 cards into FullScreenSwipingTestHarness:
      // index 4: standard card
      // index 5: DFC card with foil
      final cards = [
        createPhase39Card(id: 'c-0', name: 'Card 0'),
        createPhase39Card(id: 'c-1', name: 'Card 1'),
        createPhase39Card(id: 'c-2', name: 'Card 2'),
        createPhase39Card(id: 'c-3', name: 'Card 3'),
        createPhase39Card(
          id: 'c-4',
          name: 'Card 4 Hero',
          dynamicDataMap: {
            'image_uris': {'normal': 'https://example.com/c4.jpg'},
          },
        ),
        createPhase39Card(
          id: 'c-5',
          name: 'Card 5 DFC Foil',
          dynamicDataMap: {
            'layout': 'transform',
            'card_faces': [
              {'name': 'Front Side', 'image_uris': {'normal': 'https://example.com/c5_f.jpg'}},
              {'name': 'Back Side', 'image_uris': {'normal': 'https://example.com/c5_b.jpg'}},
            ],
            'back_image_url': 'https://example.com/c5_b.jpg',
          },
        ),
      ];

      // 2. Mount harness at initialIndex 4
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: FullScreenSwipingTestHarness(
            items: cards,
            initialIndex: 4,
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 100));

      // Verify interactive viewer for zoom exists
      final interactiveViewer = find.byType(InteractiveViewer);
      expect(interactiveViewer, findsWidgets);

      // Verify initial card is Card 4 Hero
      expect(find.text('Card 4 Hero'), findsWidgets);

      // 3. Swipe to index 5
      await tester.tap(find.byKey(const Key('fs_swipe_next_button')));
      await tester.pumpAndSettle();

      expect(find.text('Front Side'), findsWidgets);

      // 4. Toggle foil shader
      final foilButton = find.byKey(const Key('fullscreen_foil_toggle'));
      expect(foilButton, findsOneWidget);
      await tester.tap(foilButton);
      // Pump without settle to avoid infinite repeat animation timeout
      await tester.pump(const Duration(milliseconds: 150));

      // 5. Flip face on DFC card
      final flipButton = find.byKey(const Key('fullscreen_appbar_flip_button'));
      expect(flipButton, findsOneWidget);
      await tester.tap(flipButton);
      await tester.pump(const Duration(milliseconds: 150));

      expect(find.text('Back Side'), findsWidgets);

      // Toggle foil back off to clean up controller animation
      await tester.tap(foilButton);
      await tester.pump(const Duration(milliseconds: 100));
    });

    // -------------------------------------------------------------------------
    // Scenario 6: ManaBox Advanced Filter Combinatorial Query
    // -------------------------------------------------------------------------
    test('Scenario 6: ManaBox Advanced Filter Combinatorial Query (Exactly {W,U}, CMC 2-4, Creature, Power>2, NM)', () {
      // 1. Configure the comprehensive multi-faceted ManaBox query
      const filter = MtgFilterState(
        colors: {'W', 'U'},
        colorMatchMode: ColorMatchMode.exactly, // Exactly W and U (no B, R, G, or mono-colored)
        cmcRange: RangeValues(2.0, 4.0),
        typeLine: 'Creature',
        rarities: {'rare', 'mythic'},
        statFilters: [
          MtgStatFilter(stat: 'power', operator: '>', value: '2'),
        ],
        conditions: {'Near Mint'},
      );

      // 2. Test candidates:
      // A: Perfect match (Azorius Creature, CMC 3, Rare, Power 3, Near Mint)
      final cardA = createPhase39Card(
        id: 'perfect-match',
        name: 'Geist of Saint Traft',
        condition: 'Near Mint',
        dynamicDataMap: {
          'colors': ['W', 'U'],
          'cmc': 3.0,
          'type_line': 'Legendary Creature — Spirit Cleric',
          'rarity': 'mythic',
          'power': '3',
          'toughness': '2',
        },
      );

      // B: Wrong colors: Esper {W, U, B} (fails ColorMatchMode.exactly)
      final cardB = createPhase39Card(
        id: 'fail-color-superset',
        name: 'Esper Sentinel Plus',
        condition: 'Near Mint',
        dynamicDataMap: {
          'colors': ['W', 'U', 'B'],
          'cmc': 3.0,
          'type_line': 'Artifact Creature — Human Soldier',
          'rarity': 'rare',
          'power': '3',
        },
      );

      // C: Wrong colors: Mono-White {W} (fails ColorMatchMode.exactly)
      final cardC = createPhase39Card(
        id: 'fail-color-subset',
        name: 'Adeline, Resplendent Cathar',
        condition: 'Near Mint',
        dynamicDataMap: {
          'colors': ['W'],
          'cmc': 3.0,
          'type_line': 'Legendary Creature — Human Knight',
          'rarity': 'rare',
          'power': '3',
        },
      );

      // D: Out of CMC bounds (CMC 5.0)
      final cardD = createPhase39Card(
        id: 'fail-cmc',
        name: 'Dovin, Grand Arbiter Form',
        condition: 'Near Mint',
        dynamicDataMap: {
          'colors': ['W', 'U'],
          'cmc': 5.0,
          'type_line': 'Creature — Vedalken',
          'rarity': 'rare',
          'power': '4',
        },
      );

      // E: Wrong type (Instant, not Creature)
      final cardE = createPhase39Card(
        id: 'fail-type',
        name: 'Dovin\'s Veto',
        condition: 'Near Mint',
        dynamicDataMap: {
          'colors': ['W', 'U'],
          'cmc': 2.0,
          'type_line': 'Instant',
          'rarity': 'rare',
          'power': null,
        },
      );

      // F: Power <= 2 (Power 2 fails greaterThan 2)
      final cardF = createPhase39Card(
        id: 'fail-power',
        name: 'Reflector Mage',
        condition: 'Near Mint',
        dynamicDataMap: {
          'colors': ['W', 'U'],
          'cmc': 3.0,
          'type_line': 'Creature — Human Wizard',
          'rarity': 'rare',
          'power': '2',
        },
      );

      // G: Wrong condition ('Damaged' fails 'Near Mint')
      final cardG = createPhase39Card(
        id: 'fail-condition',
        name: 'Geist of Saint Traft (Damaged)',
        condition: 'Damaged',
        dynamicDataMap: {
          'colors': ['W', 'U'],
          'cmc': 3.0,
          'type_line': 'Legendary Creature — Spirit Cleric',
          'rarity': 'mythic',
          'power': '3',
        },
      );

      // 3. Assert exact filter evaluation across all candidates
      expect(filter.matches(cardA), isTrue, reason: 'Card A matches all predicates');
      expect(filter.matches(cardB), isFalse, reason: 'Card B has extra color B');
      expect(filter.matches(cardC), isFalse, reason: 'Card C lacks U');
      expect(filter.matches(cardD), isFalse, reason: 'Card D CMC 5 is > 4');
      expect(filter.matches(cardE), isFalse, reason: 'Card E is Instant not Creature');
      expect(filter.matches(cardF), isFalse, reason: 'Card F power 2 is not > 2');
      expect(filter.matches(cardG), isFalse, reason: 'Card G condition Damaged is not Near Mint');
    });

    // -------------------------------------------------------------------------
    // Scenario 7: Zero Price Edge Cases & Fallback Chain
    // -------------------------------------------------------------------------
    testWidgets('Scenario 7: Zero Price Edge Cases & Fallback Chain (Multi-currency chain, Unlisted fallback, no Check)', (tester) async {
      // 1. Hierarchy: usd -> usd_foil -> usd_etched -> eur -> eur_foil -> 0.0 / 'Unlisted'
      // Test payload A: usd: 0.00 -> usd_foil: null -> usd_etched: 12.50
      final pricesA = {'usd': '0.00', 'usd_foil': null, 'usd_etched': '12.50', 'eur': '8.00'};
      final priceA = resolveHierarchicalPrice(pricesA);
      expect(priceA, equals(12.50));
      expect(formatMarketPriceLabel(priceA), equals('\$12.50'));

      // Test payload B: usd: 0.00 -> usd_foil: 0.00 -> usd_etched: null -> eur: 8.75
      final pricesB = {'usd': '0.00', 'usd_foil': '0.00', 'usd_etched': null, 'eur': '8.75'};
      final priceB = resolveHierarchicalPrice(pricesB);
      expect(priceB, equals(8.75));
      expect(formatMarketPriceLabel(priceB), equals('\$8.75'));

      // Test payload C: usd, usd_foil, usd_etched, eur all missing -> eur_foil: 4.20
      final pricesC = {'eur_foil': '4.20'};
      final priceC = resolveHierarchicalPrice(pricesC);
      expect(priceC, equals(4.20));
      expect(formatMarketPriceLabel(priceC), equals('\$4.20'));

      // Test payload D: Completely missing or zero -> 0.0 -> 'Unlisted'
      final pricesD = {'usd': '0.00', 'usd_foil': '0.00', 'eur': '0.00'};
      final priceD = resolveHierarchicalPrice(pricesD);
      expect(priceD, equals(0.0));
      expect(formatMarketPriceLabel(priceD), equals('Unlisted'));

      // Test payload E: Special floating point cases (NaN, Infinity, Negative)
      expect(formatMarketPriceLabel(double.nan), equals('Unlisted'));
      expect(formatMarketPriceLabel(double.infinity), equals('Unlisted'));
      expect(formatMarketPriceLabel(-5.00), equals('Unlisted'));

      // 2. Render widgets for Card A and Card D in VaultItemTile and VaultItemCard
      final cardItemA = createPhase39Card(
        id: 'price-a',
        name: 'Card With Etched Fallback',
        currentMarketPrice: priceA,
        dynamicDataMap: {'prices': pricesA},
      );
      final cardItemD = createPhase39Card(
        id: 'price-d',
        name: 'Card Fully Unlisted',
        currentMarketPrice: 0.0,
        dynamicDataMap: {'prices': pricesD},
      );

      await tester.pumpWidget(wrapWithHarness(
        ListView(
          children: [
            SizedBox(height: 220, child: VaultItemTile(item: cardItemA)),
            SizedBox(height: 220, child: VaultItemTile(item: cardItemD)),
            VaultItemCard(item: cardItemA),
          ],
        ),
      ));
      await tester.pumpAndSettle();

      // Assert \$12.50 is rendered for Card A
      expect(find.text('\$12.50'), findsWidgets);
      // Assert 'Check' is NEVER rendered
      expect(find.text('Check'), findsNothing);
      expect(find.textContaining('Check'), findsNothing);
    });

    // -------------------------------------------------------------------------
    // Scenario 8: Dynamic Grid View Resize & Badge Alignment
    // -------------------------------------------------------------------------
    testWidgets('Scenario 8: Dynamic Grid View Resize & Badge Alignment (3-col grid vs list view, badge placement, image fallback)', (tester) async {
      // 1. Card with quantity 4 and missing primary image URI (null image_uris)
      final duplicateCard = createPhase39Card(
        id: 'dup-4x',
        name: 'Lightning Bolt',
        quantity: 4,
        currentMarketPrice: 3.50,
        dynamicDataMap: {
          'prices': {'usd': '3.50'},
          'image_uris': null, // Forces image fallback handling
        },
      );

      // 2. Render 3-column singles grid layout
      await tester.pumpWidget(wrapWithHarness(
        LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = constraints.maxWidth / 3;
            return GridView.count(
              crossAxisCount: 3,
              childAspectRatio: 0.7,
              children: [
                SizedBox(
                  width: itemWidth,
                  child: VaultItemTile(
                    item: duplicateCard,
                  ),
                ),
              ],
            );
          },
        ),
      ));
      await tester.pumpAndSettle();

      // Verify grid duplicate badge exists with 4x
      final gridBadge = find.byKey(Key('vault_tile_duplicate_badge_${duplicateCard.id}'));
      expect(gridBadge, findsOneWidget);
      expect(find.descendant(of: gridBadge, matching: find.text('4x')), findsOneWidget);

      // Verify market price is rendered alongside badge
      expect(find.text('\$3.50'), findsOneWidget);

      // 3. Switch layout dynamically to List view
      await tester.pumpWidget(wrapWithHarness(
        ListView(
          children: [
            VaultItemCard(
              item: duplicateCard,
            ),
          ],
        ),
      ));
      await tester.pumpAndSettle();

      // Verify list duplicate badge exists with 4x
      final cardBadge = find.byKey(Key('vault_item_duplicate_badge_${duplicateCard.id}'));
      expect(cardBadge, findsOneWidget);
      expect(find.descendant(of: cardBadge, matching: find.text('4x')), findsOneWidget);

      // Verify card name and market price rendered without overflow or error
      expect(find.text('Lightning Bolt'), findsOneWidget);
      expect(find.text('\$3.50'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // Scenario 9: Filter Reset & Vault Reactive Restoration
    // -------------------------------------------------------------------------
    testWidgets('Scenario 9: Filter Reset & Vault Reactive Restoration (5 active filters, count badge, reset, restore full list)', (tester) async {
      // 1. Create collection of 25 cards
      final fullVault = List.generate(25, (i) {
        final isMatch = (i == 3 || i == 7); // only 2 cards match the 5 filters
        return createPhase39Card(
          id: 'card-$i',
          name: 'Card $i',
          dynamicDataMap: {
            'colors': isMatch ? ['G', 'R'] : ['W'],
            'cmc': isMatch ? 2.0 : 5.0,
            'type_line': isMatch ? 'Sorcery' : 'Instant',
            'rarity': isMatch ? 'rare' : 'common',
            'finishes': isMatch ? ['foil'] : ['nonfoil'],
          },
        );
      });

      // 2. Set up 5 active filter criteria
      MtgFilterState activeFilter = const MtgFilterState(
        colors: {'G', 'R'},
        colorMatchMode: ColorMatchMode.including,
        cmcRange: RangeValues(1.0, 3.0),
        typeLine: 'Sorcery',
        rarities: {'rare'},
        finishes: {'foil'},
      );

      // Verify 5 active filter criteria count
      expect(activeFilter.activeCount, equals(5));

      // 3. Mount UI with filter count badge and reset button
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              final visibleCards = fullVault.where((c) => activeFilter.matches(c)).toList();
              return Column(
                children: [
                  if (activeFilter.activeCount > 0)
                    Container(
                      key: const Key('active_filter_count_badge'),
                      child: Text('${activeFilter.activeCount}'),
                    ),
                  Text('Visible Count: ${visibleCards.length}'),
                  ElevatedButton(
                    key: const Key('filter_reset_button'),
                    onPressed: () {
                      setState(() {
                        activeFilter = activeFilter.reset();
                      });
                    },
                    child: const Text('Reset All'),
                  ),
                ],
              );
            },
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Verify active filter count badge reflects 5
      final badgeFinder = find.byKey(const Key('active_filter_count_badge'));
      expect(badgeFinder, findsOneWidget);
      expect(find.descendant(of: badgeFinder, matching: find.text('5')), findsOneWidget);

      // Verify only 2 matching cards are visible
      expect(find.text('Visible Count: 2'), findsOneWidget);

      // 4. Trigger Reset All button
      final resetButton = find.byKey(const Key('filter_reset_button'));
      expect(resetButton, findsOneWidget);
      await tester.tap(resetButton);
      await tester.pumpAndSettle();

      // Verify filter state reset to default
      expect(activeFilter.activeCount, equals(0));
      expect(activeFilter.isActive, isFalse);

      // Active count badge should no longer be rendered
      expect(find.byKey(const Key('active_filter_count_badge')), findsNothing);

      // 5. Verify full vault list is completely restored
      expect(find.text('Visible Count: 25'), findsOneWidget);
      final restoredResults = fullVault.where((c) => activeFilter.matches(c)).toList();
      expect(restoredResults.length, equals(25));
    });
  });
}
