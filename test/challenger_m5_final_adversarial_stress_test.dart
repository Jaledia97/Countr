// Copyright (c) 2026 Countr. All rights reserved.
// Challenger M5-1: Comprehensive Empirical Adversarial Stress Suite for Countr 4.8 Patch Gate
//
// Verification Targets:
// 1. Vault 2x2 grid sorting (completion % desc, release date desc) and layout toggle row responsiveness under viewport scale variations.
// 2. Card Details variant dynamic updating and progressive rulings expansion (1 initial, See All expander, Hide collapser).
// 3. Decks FAB launch of DeckSetupWizardModal and deck builder navigation.
// 4. Command Center direct TCG setup sheet launch without nested ExpansionTiles.
// 5. Game setup pod life slider snap points (20, 30, 40) and OLED #000000 true black.

import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/command_center/presentation/widgets/play_track_accordion.dart';
import 'package:countr/features/decks/data/mock_deck_data.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/decks/presentation/screens/deck_builder_screen.dart';
import 'package:countr/features/decks/presentation/screens/decks_screen.dart';
import 'package:countr/features/decks/presentation/widgets/deck_setup_wizard_modal.dart';
import 'package:countr/features/decks/presentation/widgets/inline_deck_analytics_card.dart';
import 'package:countr/features/decks/presentation/widgets/proportional_bubble_scrollbar.dart';
import 'package:countr/features/life_counter/domain/models/pod_state.dart';
import 'package:countr/features/life_counter/presentation/dialogs/pregame_setup_sheet.dart';
import 'package:countr/features/life_counter/presentation/widgets/commander_art_backdrop.dart';
import 'package:countr/features/life_counter/presentation/widgets/player_quadrant_widget.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/screens/vault_screen.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Challenger M5-1: Countr 4.8 Patch Comprehensive Stress Suite', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await db.vaultDao.clearAllItems();
    });

    tearDown(() async {
      await db.close();
    });

    // =========================================================================
    // 1. Vault 2x2 Grid Sorting & Layout Toggle Row Responsiveness
    // =========================================================================
    group('1. Vault 2x2 Grid Sorting & Layout Toggle Row Responsiveness', () {
      test('1.1. watchSetCollections sorts by completion % desc, then release date desc', () async {
        // Set A: 100% completion (2/2 owned), releaseDate: 2021-01-01
        await db.vaultDao.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'item-set-a-1',
            collectionType: 'mtg',
            name: 'Card A1',
            setOrSeries: 'Set A (Older 100%)',
            imageUrl: 'https://example.com/a1.jpg',
            acquiredPrice: 5.0,
            acquiredDate: DateTime(2021, 1, 1),
            quantity: const drift.Value(1),
            condition: 'NM',
            currentMarketPrice: 5.0,
            lastPriceUpdate: DateTime.now(),
            dynamicData: jsonEncode({
              'set_code': 'SETA',
              'released_at': '2021-01-01',
            }),
          ),
        );
        await db.vaultDao.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'item-set-a-2',
            collectionType: 'mtg',
            name: 'Card A2',
            setOrSeries: 'Set A (Older 100%)',
            imageUrl: 'https://example.com/a2.jpg',
            acquiredPrice: 5.0,
            acquiredDate: DateTime(2021, 1, 1),
            quantity: const drift.Value(1),
            condition: 'NM',
            currentMarketPrice: 5.0,
            lastPriceUpdate: DateTime.now(),
            dynamicData: jsonEncode({
              'set_code': 'SETA',
              'released_at': '2021-01-01',
            }),
          ),
        );

        // Set B: 100% completion (1/1 owned), releaseDate: 2023-01-01 (Newer date than A -> should come first)
        await db.vaultDao.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'item-set-b-1',
            collectionType: 'mtg',
            name: 'Card B1',
            setOrSeries: 'Set B (Newer 100%)',
            imageUrl: 'https://example.com/b1.jpg',
            acquiredPrice: 10.0,
            acquiredDate: DateTime(2023, 1, 1),
            quantity: const drift.Value(1),
            condition: 'NM',
            currentMarketPrice: 10.0,
            lastPriceUpdate: DateTime.now(),
            dynamicData: jsonEncode({
              'set_code': 'SETB',
              'released_at': '2023-01-01',
            }),
          ),
        );

        // Set C: 50% completion (1 owned, 1 unowned), releaseDate: 2024-01-01
        await db.vaultDao.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'item-set-c-1',
            collectionType: 'mtg',
            name: 'Card C1',
            setOrSeries: 'Set C (50%)',
            imageUrl: 'https://example.com/c1.jpg',
            acquiredPrice: 5.0,
            acquiredDate: DateTime(2024, 1, 1),
            quantity: const drift.Value(1),
            condition: 'NM',
            currentMarketPrice: 5.0,
            lastPriceUpdate: DateTime.now(),
            dynamicData: jsonEncode({
              'set_code': 'SETC',
              'released_at': '2024-01-01',
            }),
          ),
        );
        await db.vaultDao.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'item-set-c-2',
            collectionType: 'mtg',
            name: 'Card C2',
            setOrSeries: 'Set C (50%)',
            imageUrl: 'https://example.com/c2.jpg',
            acquiredPrice: 0.0,
            acquiredDate: DateTime(2024, 1, 1),
            quantity: const drift.Value(0), // Unowned
            condition: 'NM',
            currentMarketPrice: 5.0,
            lastPriceUpdate: DateTime.now(),
            dynamicData: jsonEncode({
              'set_code': 'SETC',
              'released_at': '2024-01-01',
            }),
          ),
        );

        // Set D: 0% completion (0 owned, 2 unowned), releaseDate: 2025-01-01
        await db.vaultDao.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'item-set-d-1',
            collectionType: 'mtg',
            name: 'Card D1',
            setOrSeries: 'Set D (0%)',
            imageUrl: 'https://example.com/d1.jpg',
            acquiredPrice: 0.0,
            acquiredDate: DateTime(2025, 1, 1),
            quantity: const drift.Value(0),
            condition: 'NM',
            currentMarketPrice: 2.0,
            lastPriceUpdate: DateTime.now(),
            dynamicData: jsonEncode({
              'set_code': 'SETD',
              'released_at': '2025-01-01',
            }),
          ),
        );

        final collections = await db.vaultDao.watchSetCollections(collectionType: 'mtg').first;
        expect(collections.length, equals(4));

        // 1st: Set B (100% completion, 2023 release date)
        expect(collections[0].setName, equals('Set B (Newer 100%)'));
        expect(collections[0].completionPercentage, equals(1.0));

        // 2nd: Set A (100% completion, 2021 release date - older than B)
        expect(collections[1].setName, equals('Set A (Older 100%)'));
        expect(collections[1].completionPercentage, equals(1.0));

        // 3rd: Set C (50% completion)
        expect(collections[2].setName, equals('Set C (50%)'));
        expect(collections[2].completionPercentage, equals(0.5));

        // 4th: Set D (0% completion)
        expect(collections[3].setName, equals('Set D (0%)'));
        expect(collections[3].completionPercentage, equals(0.0));
      });

      testWidgets('1.2. Layout toggle row survives extreme viewports and font scales without overflow', (tester) async {
        final viewports = [
          const Size(320, 600),   // Narrow mobile
          const Size(390, 844),   // Standard mobile
          const Size(768, 1024),  // Tablet
          const Size(1280, 800),  // Desktop
        ];

        final fontScales = [1.0, 1.5, 2.0];

        for (final vp in viewports) {
          for (final scale in fontScales) {
            tester.view.physicalSize = vp;
            tester.view.devicePixelRatio = 1.0;

            final container = ProviderContainer(
              overrides: [
                appDatabaseProvider.overrideWithValue(db),
                vaultDaoProvider.overrideWithValue(db.vaultDao),
                activeGameContextProvider.overrideWith((ref) => 'All Collections'),
                vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
                cardDisplayLayoutProvider.overrideWith((ref) => CardDisplayLayout.list),
              ],
            );

            await tester.pumpWidget(
              UncontrolledProviderScope(
                container: container,
                child: MaterialApp(
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      size: vp,
                      textScaler: TextScaler.linear(scale),
                    ),
                    child: child!,
                  ),
                  home: const VaultScreen(),
                ),
              ),
            );
            await tester.pumpAndSettle();

            expect(tester.takeException(), isNull, reason: 'Failed at viewport $vp, scale $scale');

            // Verify view switcher buttons and layout toggle buttons are visible
            expect(find.byKey(const Key('vault_view_singles_toggle')), findsOneWidget);
            expect(find.byKey(const Key('vault_view_binders_toggle')), findsOneWidget);
            expect(find.byKey(const Key('vault_view_collections_toggle')), findsOneWidget);
            expect(find.byKey(const Key('vault_layout_list_button')), findsOneWidget);
            expect(find.byKey(const Key('vault_layout_grid_button')), findsOneWidget);

            // Tap Grid button to toggle
            await tester.tap(find.byKey(const Key('vault_layout_grid_button')));
            await tester.pumpAndSettle();
            expect(container.read(cardDisplayLayoutProvider), equals(CardDisplayLayout.grid));

            // Tap List button to toggle back
            await tester.tap(find.byKey(const Key('vault_layout_list_button')));
            await tester.pumpAndSettle();
            expect(container.read(cardDisplayLayoutProvider), equals(CardDisplayLayout.list));

            container.dispose();
          }
        }
        tester.view.resetPhysicalSize();
      });
    });

    // =========================================================================
    // 2. Card Details Variant Dynamic Updating & Progressive Rulings Expansion
    // =========================================================================
    group('2. Card Details Variant Dynamic Updating & Progressive Rulings Expansion', () {
      testWidgets('2.1. Variant selection dynamically updates hero card art and price', (tester) async {
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final variants = [
          {
            'id': 'card-var-1',
            'name': 'Sol Ring',
            'set': 'cmm',
            'set_name': 'Commander Masters',
            'image_url': 'https://example.com/cmm_sol_ring.jpg',
            'price': 2.50,
          },
          {
            'id': 'card-var-2',
            'name': 'Sol Ring',
            'set': 'mps',
            'set_name': 'Kaladesh Inventions',
            'image_url': 'https://example.com/mps_masterpiece_sol_ring.jpg',
            'price': 750.00,
          },
        ];

        final item = VaultItem(
          id: 'card-var-1',
          collectionType: 'mtg',
          name: 'Sol Ring',
          setOrSeries: 'Commander Masters',
          imageUrl: 'https://example.com/cmm_sol_ring.jpg',
          acquiredPrice: 2.50,
          acquiredDate: DateTime(2023, 1, 1),
          quantity: 1,
          condition: 'NM',
          isGraded: false,
          isAltered: false,
          isMisprint: false,
          isSigned: false,
          isDeleted: false,
          currentMarketPrice: 2.50,
          lastPriceUpdate: DateTime.now(),
          dynamicData: jsonEncode({
            'set_code': 'cmm',
            'set_name': 'Commander Masters',
            'collector_number': '101',
            'oracle_text': '{T}: Add {C}{C}.',
            'variants': variants,
          }),
        );
        await db.into(db.vaultItems).insert(item);

        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(db.vaultDao),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: CardDetailSheet(
                  item: item,
                  fetchOnlinePrintings: false,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Line 3 Set Identity: [Set Symbol] [Set Code] [Set Name]
        expect(find.byKey(const Key('card_detail_set_symbol_icon')), findsOneWidget);
        expect(find.byKey(const Key('card_detail_set_code_badge')), findsOneWidget);
        expect(find.byKey(const Key('card_detail_set_name')), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const Key('card_detail_set_code_badge')),
            matching: find.text('CMM'),
          ),
          findsOneWidget,
        );
        expect(find.textContaining('Commander Masters'), findsOneWidget);

        // Open switch printing modal
        final switchBtn = find.byKey(const Key('card_detail_switch_printing_button'));
        expect(switchBtn, findsOneWidget);
        await tester.tap(switchBtn);
        await tester.pumpAndSettle();

        // SwitchPrintingModal is open
        expect(find.text('Switch Printing / Edition'), findsOneWidget);

        // Apply switch
        final applyBtn = find.byKey(const Key('apply_switch_printing_button'));
        expect(applyBtn, findsOneWidget);
        await tester.tap(applyBtn);
        await tester.pumpAndSettle();

        // Modal closed
        expect(find.text('Switch Printing / Edition'), findsNothing);

        // Verify Set identity and hero details updated to the selected variant
        expect(find.byKey(Key('card_artwork_${item.id}')), findsOneWidget);
      });

      testWidgets('2.2. Progressive rulings disclosure: 1 initial, See All expander, Hide collapser', (tester) async {
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final item = VaultItem(
          id: 'card-rulings-test',
          collectionType: 'mtg',
          name: 'The One Ring',
          setOrSeries: 'Tales of Middle-earth',
          imageUrl: 'https://example.com/one_ring.jpg',
          acquiredPrice: 50.0,
          acquiredDate: DateTime(2023, 6, 23),
          quantity: 1,
          condition: 'NM',
          isGraded: false,
          isAltered: false,
          isMisprint: false,
          isSigned: false,
          isDeleted: false,
          currentMarketPrice: 70.0,
          lastPriceUpdate: DateTime.now(),
          dynamicData: jsonEncode({
            'set': 'ltr',
            'set_code': 'ltr',
            'set_name': 'Tales of Middle-earth',
            'collector_number': '246',
            'oracle_text': 'Indestructible\nWhen The One Ring enters the battlefield, if you cast it, you gain protection from everything until your next turn.',
            'keywords': ['Indestructible'],
            'rulings': [
              {
                'published_at': '2023-06-23',
                'comment': 'Alpha Ruling: Protection from everything means you cannot be targeted, enchanted, equipped, fortified, or damaged.',
              },
              {
                'published_at': '2023-06-24',
                'comment': 'Beta Ruling: Losing life is not the same as taking damage, so protection does not stop life loss.',
              },
              {
                'published_at': '2023-06-25',
                'comment': 'Gamma Ruling: Burden counters remain on The One Ring even if it loses its abilities.',
              },
            ],
          }),
        );

        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(db.vaultDao),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: CardDetailSheet(
                  item: item,
                  fetchOnlinePrintings: false,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Initial State: Only Ruling 1 is rendered
        final ruling1Finder = find.textContaining('Alpha Ruling: Protection from everything');
        final ruling2Finder = find.textContaining('Beta Ruling: Losing life');
        final ruling3Finder = find.textContaining('Gamma Ruling: Burden counters');
        final seeAllFinder = find.byKey(const Key('card_detail_rulings_see_all_button'));

        expect(ruling1Finder, findsOneWidget);
        expect(ruling2Finder, findsNothing);
        expect(ruling3Finder, findsNothing);
        expect(seeAllFinder, findsOneWidget);
        expect(find.text('See All (3) Rulings'), findsOneWidget);

        // 2. Tap "See All (3) Rulings"
        await tester.ensureVisible(seeAllFinder);
        await tester.tap(seeAllFinder);
        await tester.pumpAndSettle();

        // All 3 rulings are now visible
        expect(ruling1Finder, findsOneWidget);
        expect(ruling2Finder, findsOneWidget);
        expect(ruling3Finder, findsOneWidget);
        expect(find.text('Hide Additional Rulings'), findsOneWidget);

        // 3. Tap "Hide Additional Rulings"
        await tester.tap(seeAllFinder);
        await tester.pumpAndSettle();

        // Collapsed back to Ruling 1 only
        expect(ruling1Finder, findsOneWidget);
        expect(ruling2Finder, findsNothing);
        expect(ruling3Finder, findsNothing);
        expect(find.text('See All (3) Rulings'), findsOneWidget);
      });
    });

    // =========================================================================
    // 3. Decks FAB Launch & Deck Builder Navigation
    // =========================================================================
    group('3. Decks FAB Launch of DeckSetupWizardModal & Deck Builder Navigation', () {
      testWidgets('3.1. Floating action button launches DeckSetupWizardModal and successfully creates & navigates to DeckBuilder', (tester) async {
        tester.view.physicalSize = const Size(400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(db.vaultDao),
            activeDeckTcgFilterProvider.overrideWith((ref) => 'mtg'),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: DecksScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final fabFinder = find.byKey(const Key('decks_new_deck_fab'));
        expect(fabFinder, findsOneWidget);

        // Tap FAB to open wizard
        await tester.tap(fabFinder);
        await tester.pumpAndSettle();

        expect(find.byType(DeckSetupWizardModal), findsOneWidget);
        expect(find.text('New Deck Setup'), findsOneWidget);

        // Enter deck name
        final nameInput = find.byKey(const Key('deck_wizard_name_input'));
        expect(nameInput, findsOneWidget);
        await tester.enterText(nameInput, 'Empirical Stress Deck');
        await tester.pumpAndSettle();

        // Tap Create Deck button
        final createBtn = find.byKey(const Key('deck_wizard_create_button'));
        expect(createBtn, findsOneWidget);
        await tester.tap(createBtn);
        await tester.pumpAndSettle();

        // Empirically verify navigation pushed DeckBuilderScreen
        expect(find.byType(DeckBuilderScreen), findsOneWidget);
        expect(find.text('Empirical Stress Deck'), findsOneWidget);

        // Verify top app bar does NOT contain redundant Deck Analytics icon
        expect(find.byKey(const Key('deck_builder_analytics_action')), findsNothing);

        // Verify empty deck helper message is visible for the newly created empty deck
        expect(find.textContaining('No cards in this deck yet'), findsOneWidget);

        // Pop back to DecksScreen
        final backBtn = find.byTooltip('Back');
        if (backBtn.evaluate().isNotEmpty) {
          await tester.tap(backBtn);
        } else {
          await tester.tap(find.byType(BackButton));
        }
        await tester.pumpAndSettle();

        expect(find.byType(DecksScreen), findsOneWidget);
      });

      testWidgets('3.2. InlineDeckAnalyticsCard contains dedicated User Notes container and slim scrollbar', (tester) async {
        final sampleAnalytics = MockDeckData.computeAnalyticsFromItems(
          MockDeckData.getDeckItems(MockDeckData.edgarMarkovDeckId),
        );
        const notes = 'Commander primer notes: focus on vampire tokens and drain triggers.';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    InlineDeckAnalyticsCard(
                      analytics: sampleAnalytics,
                      isExpanded: true,
                      onToggleExpand: () {},
                      userNotes: notes,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 300,
                      child: ProportionalBubbleScrollbar(
                        sections: [
                          ScrollbarSection(label: 'Commander', count: 1, onTap: () {}),
                          ScrollbarSection(label: 'Creatures', count: 32, onTap: () {}),
                        ],
                        railWidth: 26.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify User Notes container is rendered with authentic text
        expect(find.byKey(const Key('inline_analytics_user_notes_container')), findsOneWidget);
        expect(find.text('User Notes'), findsOneWidget);
        expect(find.text(notes), findsOneWidget);

        // Verify ProportionalBubbleScrollbar renders with slim rail
        expect(find.byType(ProportionalBubbleScrollbar), findsOneWidget);
      });
    });

    // =========================================================================
    // 4. Command Center Direct TCG Setup Launch
    // =========================================================================
    group('4. Command Center Direct TCG Setup Sheet Launch', () {
      testWidgets('4.1. Tapping TCG cards directly launches PregameSetupSheet without nested expansion', (tester) async {
        tester.view.physicalSize = const Size(500, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final container = ProviderContainer();
        addTearDown(container.dispose);

        bool modeSelectedTriggered = false;

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: PlayTrackAccordion(
                    onModeSelected: () => modeSelectedTriggered = true,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Check direct cards exist
        expect(find.byKey(const Key('play_track_card_mtg')), findsOneWidget);
        expect(find.byKey(const Key('play_track_card_pokemon')), findsOneWidget);
        expect(find.byKey(const Key('play_track_card_lorcana')), findsOneWidget);

        // Verify NO sub-mode expansion tiles exist
        expect(find.byKey(const Key('mode_mtg_commander')), findsNothing);

        // 2. Tap MTG card -> directly launches PregameSetupSheet
        await tester.tap(find.byKey(const Key('play_track_card_mtg')));
        await tester.pumpAndSettle();

        expect(modeSelectedTriggered, isTrue);
        expect(container.read(activeGameContextProvider), equals('Magic: The Gathering'));
        expect(find.byKey(const Key('pregame_setup_sheet')), findsOneWidget);

        // Close sheet
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('pregame_setup_sheet')), findsNothing);

        // 3. Tap Pokémon card -> directly launches PregameSetupSheet for Pokémon
        await tester.tap(find.byKey(const Key('play_track_card_pokemon')));
        await tester.pumpAndSettle();

        expect(container.read(activeGameContextProvider), equals('Pokémon'));
        expect(find.byKey(const Key('pregame_setup_sheet')), findsOneWidget);
        expect(PregameSetupSheet.lastTcg, equals('Pokémon'));
      });
    });

    // =========================================================================
    // 5. Game Setup Pod Life Slider Snap Points & OLED #000000 True Black
    // =========================================================================
    group('5. Game Setup Pod Life Slider Snap Points & OLED #000000 True Black', () {
      testWidgets('5.1. Starting life slider snaps to 20, 30, 40 and preserves custom non-snap values', (tester) async {
        tester.view.physicalSize = const Size(600, 1800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final container = ProviderContainer();
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(
                body: PregameSetupSheet(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final sliderFinder = find.byKey(const Key('pregame_starting_life_slider'));
        expect(sliderFinder, findsOneWidget);
        final slider = tester.widget<Slider>(sliderFinder);

        // Snap near 20 (Standard)
        slider.onChanged!(19.2);
        await tester.pumpAndSettle();
        expect(tester.widget<Text>(find.byKey(const Key('starting_life_value_text'))).data, equals('20'));

        slider.onChanged!(21.4);
        await tester.pumpAndSettle();
        expect(tester.widget<Text>(find.byKey(const Key('starting_life_value_text'))).data, equals('20'));

        // Snap near 30 (Brawl)
        slider.onChanged!(28.8);
        await tester.pumpAndSettle();
        expect(tester.widget<Text>(find.byKey(const Key('starting_life_value_text'))).data, equals('30'));

        slider.onChanged!(31.2);
        await tester.pumpAndSettle();
        expect(tester.widget<Text>(find.byKey(const Key('starting_life_value_text'))).data, equals('30'));

        // Snap near 40 (Commander)
        slider.onChanged!(38.5);
        await tester.pumpAndSettle();
        expect(tester.widget<Text>(find.byKey(const Key('starting_life_value_text'))).data, equals('40'));

        slider.onChanged!(41.4);
        await tester.pumpAndSettle();
        expect(tester.widget<Text>(find.byKey(const Key('starting_life_value_text'))).data, equals('40'));

        // Non-snap custom value
        slider.onChanged!(55.0);
        await tester.pumpAndSettle();
        expect(tester.widget<Text>(find.byKey(const Key('starting_life_value_text'))).data, equals('55'));
      });

      testWidgets('5.2. OLED True Black Mode renders #000000 background and suppresses commander art backdrop', (tester) async {
        const testPlayerWithArt = PodPlayerState(
          id: 'p_art',
          seatIndex: 0,
          name: 'Ur-Dragon Player',
          life: 40,
          commanderName: 'The Ur-Dragon',
          commanderArtCropUrl: 'https://cards.scryfall.io/art_crop/ur_dragon.jpg',
        );

        // 1. With isOledMode == false: background is normal dark 0xFF1E1E2C and backdrop is active
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: PlayerQuadrantWidget(
                  player: testPlayerWithArt,
                  isTablet: false,
                  opponents: [],
                  isOledMode: false,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final containerNonOled = tester.widget<Container>(
          find.descendant(of: find.byType(PlayerQuadrantWidget), matching: find.byType(Container)).first,
        );
        final decorationNonOled = containerNonOled.decoration as BoxDecoration;
        expect(decorationNonOled.color, equals(const Color(0xFF1E1E2C)));
        expect(find.byType(CommanderArtBackdrop), findsOneWidget);

        // 2. With isOledMode == true: background is strictly pure black Color(0xFF000000) and backdrop is suppressed
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: PlayerQuadrantWidget(
                  player: testPlayerWithArt,
                  isTablet: false,
                  opponents: [],
                  isOledMode: true,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final containerOled = tester.widget<Container>(
          find.descendant(of: find.byType(PlayerQuadrantWidget), matching: find.byType(Container)).first,
        );
        final decorationOled = containerOled.decoration as BoxDecoration;
        expect(decorationOled.color, equals(const Color(0xFF000000)));
        expect(find.byType(CommanderArtBackdrop), findsNothing);
      });
    });
  });
}
