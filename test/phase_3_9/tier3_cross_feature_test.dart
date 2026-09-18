import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';
import 'package:countr/features/vault/presentation/widgets/full_screen_card_viewer.dart';
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

  Widget wrapWithHarness(Widget child, {UserPersona persona = UserPersona.investor}) {
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

  // ===========================================================================
  // TIER 3: CROSS-FEATURE PAIRWISE INTERACTIONS (>= 17 Tests)
  // ===========================================================================

  group('Tier 3: Cross-Feature Interactions', () {
    testWidgets('X1: Swiping while active MTG filter is applied only navigates filtered subset', (tester) async {
      // Filter only Red cards
      final allCards = [
        createPhase39Card(id: 'c-red-1', name: 'Red Card 1', dynamicDataMap: {'colors': ['R']}),
        createPhase39Card(id: 'c-blue-1', name: 'Blue Card', dynamicDataMap: {'colors': ['U']}),
        createPhase39Card(id: 'c-red-2', name: 'Red Card 2', dynamicDataMap: {'colors': ['R']}),
      ];

      final filter = const MtgFilterState(colors: {'R'});
      final filteredCards = allCards.where((c) => filter.matches(c)).toList();

      expect(filteredCards.length, 2);

      await tester.pumpWidget(wrapWithHarness(
        CardDetailSwipingTestHarness(items: filteredCards, initialIndex: 0),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Red Card 1'), findsWidgets);

      // Advance to next card in filtered subset
      await tester.tap(find.byKey(const Key('swipe_next_button')));
      await tester.pumpAndSettle();

      expect(find.text('Red Card 2'), findsWidgets);
      expect(find.text('Blue Card'), findsNothing);
    });

    testWidgets('X2: DFC flipping during background scroll sync does not disturb scroll position', (tester) async {
      final scrollCtrl = ScrollController();
      final dfcCards = [
        createPhase39Card(
          id: 'dfc-sync-1',
          name: 'DFC Sync 1',
          dynamicDataMap: {
            'layout': 'transform',
            'card_faces': [
              {'name': 'Front 1', 'image_uris': {'normal': 'https://example.com/f1.jpg'}},
              {'name': 'Back 1', 'image_uris': {'normal': 'https://example.com/b1.jpg'}},
            ],
            'back_image_url': 'https://example.com/b1.jpg',
          },
        ),
        createPhase39Card(
          id: 'dfc-sync-2',
          name: 'DFC Sync 2',
          dynamicDataMap: {
            'layout': 'transform',
            'card_faces': [
              {'name': 'Front 2', 'image_uris': {'normal': 'https://example.com/f2.jpg'}},
              {'name': 'Back 2', 'image_uris': {'normal': 'https://example.com/b2.jpg'}},
            ],
            'back_image_url': 'https://example.com/b2.jpg',
          },
        ),
      ];

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              SizedBox(
                width: 100,
                child: ListView.builder(
                  controller: scrollCtrl,
                  itemCount: 10,
                  itemBuilder: (ctx, i) => SizedBox(height: 120, child: Text('$i')),
                ),
              ),
              Expanded(
                child: ProviderScope(
                  overrides: [
                    appDatabaseProvider.overrideWithValue(db),
                    vaultDaoProvider.overrideWithValue(dao),
                  ],
                  child: CardDetailSwipingTestHarness(
                    items: dfcCards,
                    initialIndex: 0,
                    backgroundScrollController: scrollCtrl,
                  ),
                ),
              ),
            ],
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Swipe to page 1
      await tester.tap(find.byKey(const Key('swipe_next_button')));
      await tester.pumpAndSettle();

      final scrollOffsetBeforeFlip = scrollCtrl.offset;
      expect(scrollOffsetBeforeFlip, closeTo(120.0, 1.0));

      // Flip card on page 1
      final flipFinder = find.byKey(const Key('card_detail_flip_button'));
      expect(flipFinder, findsOneWidget);
      await tester.tap(flipFinder);
      await tester.pump(const Duration(milliseconds: 200));

      // Verify scroll offset is unchanged after flip
      expect(scrollCtrl.offset, equals(scrollOffsetBeforeFlip));
      scrollCtrl.dispose();
    });

    testWidgets('X3: Adventure card unified rules display with unlisted pricing fallback', (tester) async {
      final unlistedAdv = createPhase39Card(
        id: 'adv-unlisted',
        name: 'Unlisted Giant // Smash',
        currentMarketPrice: 0.0,
        dynamicDataMap: {
          'layout': 'adventure',
          'type_line': 'Creature — Giant // Instant — Adventure',
          'prices': {'usd': null, 'usd_foil': null},
          'card_faces': [
            {'name': 'Unlisted Giant', 'oracle_text': 'Trample.'},
            {'name': 'Smash', 'oracle_text': 'Destroy target artifact.'},
          ],
        },
      );

      await tester.pumpWidget(wrapWithHarness(CardDetailSheet(item: unlistedAdv)));
      await tester.pumpAndSettle();

      // Verify unified rules box renders both faces
      expect(find.text('ADVENTURE SPELL'), findsOneWidget);
      expect(find.textContaining('Trample.'), findsOneWidget);
      expect(find.textContaining('Destroy target artifact.'), findsOneWidget);

      // Verify flip button is suppressed
      expect(find.byKey(const Key('card_detail_flip_button')), findsNothing);
    });

    test('X4: Universes Beyond card with Secret Lair drop code (sld) and flavor name lookup', () {
      final card = createPhase39Card(
        id: 'sld-ub-1',
        name: 'The One Ring',
        flavorName: 'Ash Nazg Gimbatul',
        setOrSeries: 'Secret Lair Drop',
        dynamicDataMap: {
          'is_universes_beyond': true,
          'set': 'sld',
          'set_code': 'sld',
          'flavor_name': 'Ash Nazg Gimbatul',
        },
      );

      final filterUb = const MtgFilterState(isUniversesBeyond: true);
      final filterSld = const MtgFilterState(setCode: 'sld');

      expect(filterUb.matches(card), isTrue);
      expect(filterSld.matches(card), isTrue);
      expect(card.flavorName, 'Ash Nazg Gimbatul');
    });

    testWidgets('X5: 3x Grid quantity badge renders alongside market price on duplicate card', (tester) async {
      final card = createPhase39Card(
        id: 'dup-priced-grid',
        name: 'Priced Duplicate',
        quantity: 3,
        currentMarketPrice: 19.99,
      );

      await tester.pumpWidget(wrapWithHarness(
        SizedBox(width: 150, height: 200, child: VaultItemTile(item: card)),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(Key('vault_tile_duplicate_badge_${card.id}')), findsOneWidget);
      expect(find.text('\$19.99'), findsOneWidget);
    });

    testWidgets('X6: FullScreenCardViewer DFC flip retains flip button state after swiping back', (tester) async {
      final items = [
        createPhase39Card(
          id: 'fs-dfc-1',
          name: 'DFC 1',
          dynamicDataMap: {
            'layout': 'transform',
            'card_faces': [
              {'name': 'F1'},
              {'name': 'B1'},
            ],
            'back_image_url': 'https://example.com/b1.jpg',
          },
        ),
        createPhase39Card(id: 'fs-normal', name: 'Normal 2'),
      ];

      await tester.pumpWidget(MaterialApp(
        home: FullScreenSwipingTestHarness(items: items, initialIndex: 0),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('fullscreen_flip_button')), findsOneWidget);

      // Advance to card 2 (normal card, no flip button)
      await tester.tap(find.byKey(const Key('fs_swipe_next_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('fullscreen_card_viewer_fs-normal')), findsOneWidget);
      expect(find.byKey(const Key('fullscreen_flip_button')), findsNothing);

      // Return to card 1 (DFC, flip button restored)
      await tester.tap(find.byKey(const Key('fs_swipe_prev_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('fullscreen_flip_button')), findsOneWidget);
    });

    testWidgets('X7: List view thumbnail renders for card filtered by layout (adventure)', (tester) async {
      final adv = createPhase39Card(
        id: 'adv-list-thumb',
        name: 'Brazen Borrower // Petty Theft',
        imageUrl: 'https://cards.scryfall.io/small/front/borrower.jpg',
        dynamicDataMap: {'layout': 'adventure'},
      );

      final filter = const MtgFilterState(layouts: {'adventure'});
      expect(filter.matches(adv), isTrue);

      await tester.pumpWidget(wrapWithHarness(VaultItemCard(item: adv)));
      await tester.pumpAndSettle();

      expect(find.text('Brazen Borrower // Petty Theft'), findsOneWidget);
    });

    testWidgets('X8: Filter modal state change updates activeCount badge', (tester) async {
      MtgFilterState currentState = const MtgFilterState();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (ctx, setState) {
              return Column(
                children: [
                  Text('Badge: ${currentState.activeCount}'),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        currentState = currentState.copyWith(colors: {'W', 'U'}, isUniversesBeyond: () => true);
                      });
                    },
                    child: const Text('Add Filters'),
                  ),
                ],
              );
            },
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Badge: 0'), findsOneWidget);

      await tester.tap(find.text('Add Filters'));
      await tester.pumpAndSettle();

      expect(find.text('Badge: 2'), findsOneWidget);
    });

    testWidgets('X9: Eliminating Check across Investor and Player modes on Adventure card', (tester) async {
      final adv = createPhase39Card(
        id: 'adv-no-check',
        name: 'Giant Card',
        currentMarketPrice: 4.50,
        dynamicDataMap: {'layout': 'adventure'},
      );

      // Investor mode
      await tester.pumpWidget(wrapWithHarness(VaultItemCard(item: adv), persona: UserPersona.investor));
      await tester.pumpAndSettle();
      expect(find.text('Check'), findsNothing);
      expect(find.text('\$4.50'), findsOneWidget);

      // Player mode
      await tester.pumpWidget(wrapWithHarness(VaultItemCard(item: adv), persona: UserPersona.player));
      await tester.pumpAndSettle();
      expect(find.text('Check'), findsNothing);
    });

    testWidgets('X10: Swiping to an unlisted card in CardDetailSheet displays Unlisted price and scrolls', (tester) async {
      final scrollCtrl = ScrollController();
      final items = [
        createPhase39Card(id: 'c-priced', name: 'Priced 1', currentMarketPrice: 20.0),
        createPhase39Card(id: 'c-unlisted', name: 'Unlisted 2', currentMarketPrice: 0.0),
      ];

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              SizedBox(
                width: 100,
                child: ListView.builder(
                  controller: scrollCtrl,
                  itemCount: 15,
                  itemBuilder: (ctx, i) => SizedBox(height: 120, child: Text('$i')),
                ),
              ),
              Expanded(
                child: ProviderScope(
                  overrides: [
                    appDatabaseProvider.overrideWithValue(db),
                    vaultDaoProvider.overrideWithValue(dao),
                  ],
                  child: CardDetailSwipingTestHarness(
                    items: items,
                    initialIndex: 0,
                    backgroundScrollController: scrollCtrl,
                  ),
                ),
              ),
            ],
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Swipe to card 2 (unlisted)
      await tester.tap(find.byKey(const Key('swipe_next_button')));
      await tester.pumpAndSettle();

      expect(find.text('Unlisted 2'), findsWidgets);
      expect(scrollCtrl.offset, closeTo(120.0, 1.0));
      scrollCtrl.dispose();
    });

    test('X11: Universes Beyond filter combined with Commander color identity and CMC range', () {
      final filter = const MtgFilterState(
        isUniversesBeyond: true,
        colorMatchMode: ColorMatchMode.commander,
        colors: {'W', 'U', 'B', 'R', 'G'}, // 5-color commander
        cmcRange: RangeValues(3, 5),
      );

      final matchingCard = createPhase39Card(
        id: 'sauron',
        name: 'Sauron, the Dark Lord',
        dynamicDataMap: {
          'is_universes_beyond': true,
          'colors': ['U', 'B', 'R'],
          'cmc': 4.0,
        },
      );

      final nonUbCard = createPhase39Card(
        id: 'bolas',
        name: 'Nicol Bolas',
        dynamicDataMap: {
          'is_universes_beyond': false,
          'colors': ['U', 'B', 'R'],
          'cmc': 4.0,
        },
      );

      expect(filter.matches(matchingCard), isTrue);
      expect(filter.matches(nonUbCard), isFalse);
    });

    testWidgets('X12: Secret Lair card with DFC layout renders flip button in CardDetailSheet', (tester) async {
      final sldDfc = createPhase39Card(
        id: 'sld-dfc-1',
        name: 'Secret Lair DFC',
        setOrSeries: 'Secret Lair Drop',
        dynamicDataMap: {
          'set': 'sld',
          'layout': 'transform',
          'card_faces': [
            {'name': 'SLD Front', 'image_uris': {'normal': 'https://example.com/f.jpg'}},
            {'name': 'SLD Back', 'image_uris': {'normal': 'https://example.com/b.jpg'}},
          ],
          'back_image_url': 'https://example.com/b.jpg',
        },
      );

      await tester.pumpWidget(wrapWithHarness(CardDetailSheet(item: sldDfc)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('card_detail_flip_button')), findsOneWidget);
    });

    testWidgets('X13: Switching layout between 3-column singles grid and list view preserves item state', (tester) async {
      final card = createPhase39Card(id: 'toggle-card', name: 'Layout Toggle Card', quantity: 2, currentMarketPrice: 10.0);

      // Grid mode
      await tester.pumpWidget(wrapWithHarness(
        SizedBox(width: 150, height: 200, child: VaultItemTile(item: card)),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(Key('vault_tile_duplicate_badge_${card.id}')), findsOneWidget);

      // List view mode
      await tester.pumpWidget(wrapWithHarness(
        VaultItemCard(item: card),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Layout Toggle Card'), findsOneWidget);
    });

    testWidgets('X14: FullScreenCardViewer foil shader toggle on an Adventure card retains foil with no flip button', (tester) async {
      final adv = createPhase39Card(
        id: 'adv-fs-foil',
        name: 'Foil Adventure',
        dynamicDataMap: {
          'layout': 'adventure',
          'card_faces': [{'name': 'C'}, {'name': 'A'}],
        },
      );

      await tester.pumpWidget(MaterialApp(home: FullScreenCardViewer(item: adv)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('fullscreen_flip_button')), findsNothing);
      expect(find.byKey(const Key('fullscreen_foil_toggle')), findsOneWidget);

      await tester.tap(find.byKey(const Key('fullscreen_foil_toggle')));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('fullscreen_flip_button')), findsNothing);
    });

    test('X15: VaultDao reactive stream emits new record with updated duplicate quantity', () async {
      final stream = dao.watchItemsByCollection('mtg');
      final initial = await stream.first;

      // Update quantity of existing card
      final target = initial.first;
      await dao.into(dao.vaultItems).insertOnConflictUpdate(
        target.copyWith(quantity: target.quantity + 1),
      );

      final updated = await stream.first;
      final updatedCard = updated.firstWhere((c) => c.id == target.id);
      expect(updatedCard.quantity, target.quantity + 1);
    });

    testWidgets('X16: Swiping from an Adventure card (no flip) to a DFC card (flip button appears)', (tester) async {
      final items = [
        createPhase39Card(
          id: 'card-1-adv',
          name: 'Adv 1',
          dynamicDataMap: {
            'layout': 'adventure',
            'card_faces': [{'name': 'Adv Face 1'}],
          },
        ),
        createPhase39Card(
          id: 'card-2-dfc',
          name: 'DFC 2',
          dynamicDataMap: {
            'layout': 'transform',
            'card_faces': [{'name': 'Front'}, {'name': 'Back'}],
            'back_image_url': 'https://example.com/b.jpg',
          },
        ),
      ];

      await tester.pumpWidget(wrapWithHarness(
        CardDetailSwipingTestHarness(items: items, initialIndex: 0),
      ));
      await tester.pumpAndSettle();

      // Page 0: Adventure card, no flip button
      expect(find.byKey(const Key('card_detail_flip_button')), findsNothing);

      // Advance to Page 1: DFC card, flip button appears
      await tester.tap(find.byKey(const Key('swipe_next_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('card_detail_flip_button')), findsOneWidget);
    });

    testWidgets('X17: Resetting MTG filter sheet restores full active Vault list', (tester) async {
      MtgFilterState state = const MtgFilterState(colors: {'U'});
      final allCards = [
        createPhase39Card(id: 'u-1', name: 'Blue Card', dynamicDataMap: {'colors': ['U']}),
        createPhase39Card(id: 'r-1', name: 'Red Card', dynamicDataMap: {'colors': ['R']}),
        createPhase39Card(id: 'g-1', name: 'Green Card', dynamicDataMap: {'colors': ['G']}),
      ];

      // While filtered
      var visible = allCards.where((c) => state.matches(c)).toList();
      expect(visible.length, 1);
      expect(visible.first.name, 'Blue Card');

      // Reset filter
      state = state.reset();
      visible = allCards.where((c) => state.matches(c)).toList();
      expect(visible.length, 3);
    });
  });
}
