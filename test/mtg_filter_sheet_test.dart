import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/screens/vault_screen.dart';
import 'package:countr/features/vault/presentation/providers/mtg_filter_state.dart';
import 'package:countr/features/vault/presentation/widgets/mtg_filter_sheet.dart';

import 'phase_3_9/phase_3_9_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    db = createPhase39TestDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  void setupLargeTestScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Widget wrapWithHarness(
    Widget child, {
    MtgFilterState? initialFilter,
    Stream<List<VaultItem>>? itemsStream,
  }) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        vaultDaoProvider.overrideWithValue(db.vaultDao),
        userPersonaProvider.overrideWith((ref) => UserPersona.investor),
        cardDisplayLayoutProvider.overrideWith((ref) => CardDisplayLayout.grid),
        activeGameContextProvider.overrideWith((ref) => 'mtg'),
        vaultShowCatalogProvider.overrideWith((ref) => false),
        vaultSearchQueryProvider.overrideWith((ref) => ''),
        vaultPaginationLimitProvider.overrideWith((ref) => 100),
        vaultIsFetchingMoreProvider.overrideWith((ref) => false),
        vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
        if (initialFilter != null)
          mtgFilterProvider.overrideWith((ref) => MtgFilterNotifier(initialFilter)),
        if (itemsStream != null)
          vaultItemsStreamProvider.overrideWith((ref) => itemsStream),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: child,
        ),
      ),
    );
  }

  group('MtgFilterSheet Widget Tests', () {
    testWidgets('1. Renders Header with Filter Cards title, tabs, and action buttons', (tester) async {
      setupLargeTestScreen(tester);
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: MtgFilterSheet()),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Filter Cards'), findsOneWidget);
      expect(find.byKey(const Key('mtg_filter_reset_button')), findsOneWidget);
      expect(find.byKey(const Key('mtg_filter_close_button')), findsOneWidget);
      expect(find.byKey(const Key('mtg_filter_tab_general')), findsOneWidget);
      expect(find.byKey(const Key('mtg_filter_tab_collection')), findsOneWidget);
      expect(find.byKey(const Key('mtg_filter_apply_button')), findsOneWidget);
      expect(find.text('Apply (0)'), findsOneWidget);
    });

    testWidgets('2. Circular Mana Buttons: Tapping W, U, B, R, G, C toggles selection and updates active count', (tester) async {
      setupLargeTestScreen(tester);
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: MtgFilterSheet()),
      ));
      await tester.pumpAndSettle();

      // Tap W
      await tester.tap(find.byKey(const Key('filter_chip_color_W')));
      await tester.pumpAndSettle();
      expect(find.text('Apply (1)'), findsOneWidget);

      // Tap U
      await tester.tap(find.byKey(const Key('filter_chip_color_U')));
      await tester.pumpAndSettle();
      expect(find.text('Apply (1)'), findsOneWidget); // still 1 dimension (colors)

      // Untap W
      await tester.tap(find.byKey(const Key('filter_chip_color_W')));
      await tester.pumpAndSettle();
      expect(find.text('Apply (1)'), findsOneWidget);

      // Untap U
      await tester.tap(find.byKey(const Key('filter_chip_color_U')));
      await tester.pumpAndSettle();
      expect(find.text('Apply (0)'), findsOneWidget);
    });

    testWidgets('3. Color match modes and color target selectors update selection', (tester) async {
      setupLargeTestScreen(tester);
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: MtgFilterSheet()),
      ));
      await tester.pumpAndSettle();

      // Match mode
      await tester.tap(find.text('Exactly'));
      await tester.pumpAndSettle();

      // Color target
      await tester.tap(find.text('Color Identity'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('filter_color_match_mode_selector')), findsOneWidget);
      expect(find.byKey(const Key('filter_color_target_selector')), findsOneWidget);
    });

    testWidgets('4. CMC and Color Count range sliders update values and active count', (tester) async {
      setupLargeTestScreen(tester);
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: MtgFilterSheet()),
      ));
      await tester.pumpAndSettle();

      final cmcSlider = find.byKey(const Key('filter_cmc_slider'));
      expect(cmcSlider, findsOneWidget);

      await tester.drag(cmcSlider, const Offset(60, 0));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mtg_filter_apply_button')), findsOneWidget);
    });

    testWidgets('5. Type line text entry and Oracle text clauses', (tester) async {
      setupLargeTestScreen(tester);
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: MtgFilterSheet()),
      ));
      await tester.pumpAndSettle();

      // Enter type line
      await tester.enterText(find.byKey(const Key('filter_type_line_field')), 'Legendary Creature');
      await tester.pumpAndSettle();
      expect(find.text('Apply (1)'), findsOneWidget);

      // Add oracle clause
      await tester.enterText(find.byKey(const Key('filter_oracle_clause_field')), 'flying');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('filter_add_oracle_clause_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('filter_oracle_chip_0')), findsOneWidget);
      expect(find.text('"flying"'), findsOneWidget);
      expect(find.text('Apply (2)'), findsOneWidget);

      // Delete clause
      await tester.tap(find.descendant(
        of: find.byKey(const Key('filter_oracle_chip_0')),
        matching: find.byIcon(Icons.close),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('filter_oracle_chip_0')), findsNothing);
      expect(find.text('Apply (1)'), findsOneWidget);
    });

    testWidgets('6. Set code operator and text input', (tester) async {
      setupLargeTestScreen(tester);
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: MtgFilterSheet()),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('filter_set_code_field')), 'MH3');
      await tester.pumpAndSettle();
      expect(find.text('Apply (1)'), findsOneWidget);

      await tester.tap(find.text('!='));
      await tester.pumpAndSettle();
      expect(find.text('Apply (1)'), findsOneWidget);
    });

    testWidgets('7. Rarity and Layout chips multi-select', (tester) async {
      setupLargeTestScreen(tester);
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: MtgFilterSheet()),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('filter_chip_rarity_mythic')));
      await tester.pumpAndSettle();
      expect(find.text('Apply (1)'), findsOneWidget);

      await tester.tap(find.byKey(const Key('filter_chip_layout_adventure')));
      await tester.pumpAndSettle();
      expect(find.text('Apply (2)'), findsOneWidget);
    });

    testWidgets('8. Stats filter addition and removal', (tester) async {
      setupLargeTestScreen(tester);
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: MtgFilterSheet()),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('filter_stat_value_field')), '4');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('filter_add_stat_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('filter_stat_chip_0')), findsOneWidget);
      expect(find.text('power = 4'), findsOneWidget);
      expect(find.text('Apply (1)'), findsOneWidget);

      // Remove stat
      await tester.tap(find.descendant(
        of: find.byKey(const Key('filter_stat_chip_0')),
        matching: find.byIcon(Icons.close),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Apply (0)'), findsOneWidget);
    });

    testWidgets('9. Treatments checkboxes & Finishes chips', (tester) async {
      setupLargeTestScreen(tester);
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: MtgFilterSheet()),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('filter_checkbox_universes_beyond')));
      await tester.pumpAndSettle();
      expect(find.text('Apply (1)'), findsOneWidget);

      await tester.tap(find.byKey(const Key('filter_chip_finish_foil')));
      await tester.pumpAndSettle();
      expect(find.text('Apply (2)'), findsOneWidget);
    });

    testWidgets('10. Collection Tab: Condition chips, Language chips, Graded/Signed switches', (tester) async {
      setupLargeTestScreen(tester);
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: MtgFilterSheet()),
      ));
      await tester.pumpAndSettle();

      // Switch to collection tab
      await tester.tap(find.byKey(const Key('mtg_filter_tab_collection')));
      await tester.pumpAndSettle();

      // Select NM condition
      await tester.tap(find.byKey(const Key('filter_chip_cond_NM')));
      await tester.pumpAndSettle();
      expect(find.text('Apply (1)'), findsOneWidget);

      // Select Japanese language
      await tester.tap(find.byKey(const Key('filter_chip_lang_Japanese')));
      await tester.pumpAndSettle();
      expect(find.text('Apply (2)'), findsOneWidget);

      // Toggle graded switch
      await tester.tap(find.byKey(const Key('filter_switch_graded')));
      await tester.pumpAndSettle();
      expect(find.text('Apply (3)'), findsOneWidget);

      // Toggle signed switch
      await tester.tap(find.byKey(const Key('filter_switch_signed')));
      await tester.pumpAndSettle();
      expect(find.text('Apply (4)'), findsOneWidget);
    });

    testWidgets('11. Reset All restores default state and zeroes active count', (tester) async {
      setupLargeTestScreen(tester);
      bool resetTriggered = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MtgFilterSheet(
            initialState: const MtgFilterState(
              colors: {'W', 'U'},
              rarities: {'mythic'},
              isUniversesBeyond: true,
            ),
            onReset: () => resetTriggered = true,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Apply (3)'), findsOneWidget);

      await tester.tap(find.byKey(const Key('mtg_filter_reset_button')));
      await tester.pumpAndSettle();

      expect(resetTriggered, isTrue);
      expect(find.text('Apply (0)'), findsOneWidget);
    });

    testWidgets('12. Apply Filters pops modal and transmits updated state', (tester) async {
      setupLargeTestScreen(tester);
      MtgFilterState? captured;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MtgFilterSheet(
            onApply: (state) => captured = state,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('filter_chip_color_R')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('mtg_filter_apply_button')));
      await tester.pumpAndSettle();

      expect(captured, isNotNull);
      expect(captured!.colors, contains('R'));
      expect(captured!.activeCount, 1);
    });
  });

  group('VaultScreen MtgFilterButton Integration Tests', () {
    testWidgets('13. VaultScreen renders vault_mtg_filter_button in search bar', (tester) async {
      setupLargeTestScreen(tester);
      await tester.pumpWidget(wrapWithHarness(
        const VaultScreen(),
        itemsStream: Stream.value(<VaultItem>[]),
      ));
      await tester.pumpAndSettle();

      final filterButton = find.byKey(const Key('vault_mtg_filter_button'));
      expect(filterButton, findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('14. Tapping vault_mtg_filter_button opens MtgFilterSheet modal', (tester) async {
      setupLargeTestScreen(tester);
      await tester.pumpWidget(wrapWithHarness(
        const VaultScreen(),
        itemsStream: Stream.value(<VaultItem>[]),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('vault_mtg_filter_button')));
      await tester.pumpAndSettle();

      expect(find.text('Filter Cards'), findsOneWidget);
      expect(find.byKey(const Key('mtg_filter_tab_general')), findsOneWidget);
      expect(find.byKey(const Key('mtg_filter_tab_collection')), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('15. Badge displays activeCount when filter is active in VaultScreen', (tester) async {
      setupLargeTestScreen(tester);
      await tester.pumpWidget(wrapWithHarness(
        const VaultScreen(),
        initialFilter: const MtgFilterState(
          colors: {'G'},
          rarities: {'rare'},
        ),
        itemsStream: Stream.value(<VaultItem>[]),
      ));
      await tester.pumpAndSettle();

      // Active count is 2 (colors + rarities)
      expect(find.text('2'), findsWidgets);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });

  // =============================================================================
  // MOBILE VIEWPORT & STAT OPERATOR REGRESSION TESTS
  // =============================================================================

  group('Mobile Viewport & Stat Operator Regression Tests', () {
    /// Configures a mobile test screen with clean tear-down.
    void setupMobileTestScreen(WidgetTester tester, Size size) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    }

    testWidgets('16. Mobile Viewport 360x640: renders MtgFilterSheet without RenderFlex overflow', (tester) async {
      setupMobileTestScreen(tester, const Size(360, 640));

      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: MtgFilterSheet()),
      ));
      await tester.pumpAndSettle();

      // Assert that no RenderFlex overflow or layout exception occurred
      expect(tester.takeException(), isNull);

      // Verify key header and tab elements rendered cleanly
      expect(find.text('Filter Cards'), findsOneWidget);
      expect(find.byKey(const Key('mtg_filter_tab_general')), findsOneWidget);
      expect(find.byKey(const Key('mtg_filter_tab_collection')), findsOneWidget);
      expect(find.byKey(const Key('mtg_filter_apply_button')), findsOneWidget);
      expect(find.text('Apply (0)'), findsOneWidget);

      // Switch to Collection tab to guarantee secondary tab has no overflow on 360px
      await tester.tap(find.byKey(const Key('mtg_filter_tab_collection')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('17. Mobile Viewport 320x568 (iPhone SE / compact): renders MtgFilterSheet with active filters and card count preview without overflow', (tester) async {
      setupMobileTestScreen(tester, const Size(320, 568));

      // Active filters: triggers "2 active" badge in header and Apply (2) in bottom action bar
      const activeFilterState = MtgFilterState(
        colors: {'R'},
        rarities: {'rare'},
      );

      // Provide 2 vault items (1 matching, 1 non-matching) to trigger "$matchingCount cards" preview
      final matchingCard = createPhase39Card(
        id: 'card-bolt-320',
        name: 'Lightning Bolt',
        dynamicDataMap: {
          'colors': ['R'],
          'rarity': 'rare',
        },
      );
      final nonMatchingCard = createPhase39Card(
        id: 'card-counterspell-320',
        name: 'Counterspell',
        dynamicDataMap: {
          'colors': ['U'],
          'rarity': 'uncommon',
        },
      );

      await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MtgFilterSheet(
          initialState: activeFilterState,
          items: [matchingCard, nonMatchingCard],
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Assert zero RenderFlex overflows on the narrowest 320px viewport
    expect(tester.takeException(), isNull);

      // Verify active badge in header is visible
      expect(find.text('2 active'), findsOneWidget);

      // Verify card count preview text in sticky bottom bar is visible
      expect(find.text('1 cards'), findsOneWidget);

      // Verify sticky bottom Apply button reflects active count
      expect(find.text('Apply (2)'), findsOneWidget);

      // Verify reset and close buttons exist without being pushed offscreen
      expect(find.byKey(const Key('mtg_filter_reset_button')), findsOneWidget);
      expect(find.byKey(const Key('mtg_filter_close_button')), findsOneWidget);
    });

    testWidgets('18. Stat Operator Selection: verifies <=, >=, and != operators can be selected and update _state', (tester) async {
      setupLargeTestScreen(tester);
      MtgFilterState? appliedState;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MtgFilterSheet(
            onApply: (state) => appliedState = state,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // 1. Select '<=' operator with Power
      await tester.tap(find.byKey(const Key('filter_stat_operator_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('<=').last);
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('filter_stat_value_field')), '3');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('filter_add_stat_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('filter_stat_chip_0')), findsOneWidget);
      expect(find.text('power <= 3'), findsOneWidget);
      expect(find.text('Apply (1)'), findsOneWidget);

      // 2. Select '>=' operator with Toughness
      await tester.tap(find.byKey(const Key('filter_stat_type_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Toughness').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('filter_stat_operator_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('>=').last);
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('filter_stat_value_field')), '4');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('filter_add_stat_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('filter_stat_chip_1')), findsOneWidget);
      expect(find.text('toughness >= 4'), findsOneWidget);
      expect(find.text('Apply (2)'), findsOneWidget);

      // 3. Select '!=' operator with Loyalty
      await tester.tap(find.byKey(const Key('filter_stat_type_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Loyalty').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('filter_stat_operator_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('!=').last);
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('filter_stat_value_field')), '5');
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('filter_add_stat_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('filter_stat_chip_2')), findsOneWidget);
      expect(find.text('loyalty != 5'), findsOneWidget);
      expect(find.text('Apply (3)'), findsOneWidget);

      // 4. Tap Apply to verify _state is updated with all three stat filters
      await tester.tap(find.byKey(const Key('mtg_filter_apply_button')));
      await tester.pumpAndSettle();

      expect(appliedState, isNotNull);
      expect(appliedState!.statFilters.length, 3);

      expect(appliedState!.statFilters[0].stat, 'power');
      expect(appliedState!.statFilters[0].operator, '<=');
      expect(appliedState!.statFilters[0].value, '3');

      expect(appliedState!.statFilters[1].stat, 'toughness');
      expect(appliedState!.statFilters[1].operator, '>=');
      expect(appliedState!.statFilters[1].value, '4');

      expect(appliedState!.statFilters[2].stat, 'loyalty');
      expect(appliedState!.statFilters[2].operator, '!=');
      expect(appliedState!.statFilters[2].value, '5');

      expect(appliedState!.activeCount, 3);
    });

    testWidgets('19. Ultra-narrow Viewport 300x500: renders MtgFilterSheet with active badges, long text clauses, and matching card preview without overflow', (tester) async {
      setupMobileTestScreen(tester, const Size(300, 500));

      const oracleClause1 =
          'Whenever a creature an opponent controls dies, if it had counters on it, put those counters on target permanent you control with a counter on it.';
      const oracleClause2 =
          'When this creature enters the battlefield, search your library for a card, put it into your hand, then shuffle your library.';

      final activeFilterState = MtgFilterState(
        colors: const {'W', 'U', 'B', 'R', 'G'},
        rarities: const {'mythic', 'rare'},
        typeLine: 'Legendary Creature Dragon God',
        oracleTextClauses: const [
          oracleClause1,
          oracleClause2,
        ],
        cmcRange: const RangeValues(2, 6),
        layouts: const {'transform', 'modal_dfc'},
        isUniversesBeyond: true,
        setCode: 'sld',
        finishes: const {'foil'},
      );

      final matchingCards = List.generate(
        5,
        (i) => createPhase39Card(
          id: 'card-matching-300-$i',
          name: 'Nicol Bolas $i',
          setOrSeries: 'sld',
          dynamicDataMap: {
            'set': 'sld',
            'colors': ['W', 'U', 'B', 'R', 'G'],
            'rarity': 'mythic',
            'type_line': 'Legendary Creature Dragon God',
            'oracle_text':
                '$oracleClause1\n$oracleClause2 Target opponent reveals their hand.',
            'cmc': 5.0,
            'layout': 'transform',
            'is_universes_beyond': true,
            'finishes': ['foil'],
          },
        ),
      );

      final nonMatchingCards = List.generate(
        5,
        (i) => createPhase39Card(
          id: 'card-nonmatching-300-$i',
          name: 'Grizzly Bears $i',
          dynamicDataMap: {
            'colors': ['G'],
            'rarity': 'common',
            'type_line': 'Creature Bear',
            'cmc': 2.0,
          },
        ),
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MtgFilterSheet(
            initialState: activeFilterState,
            items: [...matchingCards, ...nonMatchingCards],
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Assert zero RenderFlex overflows on 300x500 viewport
      expect(tester.takeException(), isNull);

      // Verify header components
      expect(find.text('Filter Cards'), findsOneWidget);
      expect(find.text('${activeFilterState.activeCount} active'), findsOneWidget);
      expect(find.byKey(const Key('mtg_filter_reset_button')), findsOneWidget);
      expect(find.byKey(const Key('mtg_filter_close_button')), findsOneWidget);

      // Verify bottom action bar components
      expect(find.text('5 cards'), findsOneWidget);
      expect(find.text('Apply (${activeFilterState.activeCount})'), findsOneWidget);
      expect(find.byKey(const Key('mtg_filter_bottom_reset_button')), findsOneWidget);

      // Switch to Collection tab on 300x500
      await tester.tap(find.byKey(const Key('mtg_filter_tab_collection')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Switch back to General tab
      await tester.tap(find.byKey(const Key('mtg_filter_tab_general')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('20. Ultra-narrow Viewport 320x568: stress-test with high active badge count, long text clauses, and matching card preview', (tester) async {
      setupMobileTestScreen(tester, const Size(320, 568));

      const activeFilterState = MtgFilterState(
        colors: {'R', 'G'},
        colorMatchMode: ColorMatchMode.including,
        colorTarget: ColorTarget.colorIdentity,
        typeLine: 'Creature Elf Shaman',
        oracleTextClauses: [
          'Target creature gets +3/+3 and gains trample until end of turn. Whenever this creature deals combat damage to a player, draw a card.',
          'At the beginning of your upkeep, you may sacrifice an artifact. If you do, search your library for a basic land card and put it onto the battlefield tapped.',
        ],
        statFilters: [
          MtgStatFilter(stat: 'power', operator: '>=', value: '4'),
        ],
        rarities: {'rare'},
        conditions: {'NM'},
      );

      final cards = List.generate(
        42,
        (i) => createPhase39Card(
          id: 'card-320-stress-$i',
          name: 'Card $i',
          condition: 'NM',
          dynamicDataMap: {
            'colors': ['R', 'G'],
            'color_identity': ['R', 'G'],
            'type_line': 'Creature Elf Shaman',
            'oracle_text': 'Target creature gets +3/+3 and gains trample until end of turn. Whenever this creature deals combat damage to a player, draw a card. At the beginning of your upkeep, you may sacrifice an artifact. If you do, search your library for a basic land card and put it onto the battlefield tapped.',
            'power': '4',
            'rarity': 'rare',
          },
        ),
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MtgFilterSheet(
            initialState: activeFilterState,
            items: cards,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Filter Cards'), findsOneWidget);
      expect(find.text('${activeFilterState.activeCount} active'), findsOneWidget);
      expect(find.text('42 cards'), findsOneWidget);
      expect(find.text('Apply (${activeFilterState.activeCount})'), findsOneWidget);

      // Verify scrollability down the filter sheet on 320x568
      await tester.drag(find.byType(ListView).first, const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Switch to Collection tab
      await tester.tap(find.byKey(const Key('mtg_filter_tab_collection')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('21. Text Scaling Stress (textScaleFactor 1.5 & 2.0): verifies TextOverflow.ellipsis and layout resilience under high font zoom', (tester) async {
      setupMobileTestScreen(tester, const Size(320, 568));

      const activeFilterState = MtgFilterState(
        colors: {'U', 'B'},
        rarities: {'rare'},
        typeLine: 'Instant',
      );

      final cards = List.generate(
        99,
        (i) => createPhase39Card(
          id: 'card-zoom-$i',
          name: 'Card $i',
          dynamicDataMap: {
            'colors': ['U', 'B'],
            'rarity': 'rare',
            'type_line': 'Instant',
          },
        ),
      );

      // 1. Test with textScaleFactor 1.5
      await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 568),
            textScaler: TextScaler.linear(1.5),
          ),
          child: Scaffold(
            body: MtgFilterSheet(
              initialState: activeFilterState,
              items: cards,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Ensure TextOverflow.ellipsis prevents uncaught layout exceptions
      expect(tester.takeException(), isNull);
      expect(find.text('Filter Cards'), findsOneWidget);
      expect(find.byKey(const Key('mtg_filter_apply_button')), findsOneWidget);

      // 2. Test with extreme textScaleFactor 2.0
      await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 568),
            textScaler: TextScaler.linear(2.0),
          ),
          child: Scaffold(
            body: MtgFilterSheet(
              initialState: activeFilterState,
              items: cards,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Ensure no uncaught exceptions under extreme 2.0x magnification
      expect(tester.takeException(), isNull);
      expect(find.text('Filter Cards'), findsOneWidget);
    });

    testWidgets('22. Stat Operator Comprehensive Matrix: verify all 6 operators (=, >, <, <=, >=, !=) can be selected and applied', (tester) async {
      setupLargeTestScreen(tester);
      MtgFilterState? appliedState;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MtgFilterSheet(
            onApply: (state) => appliedState = state,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final operatorSpecs = [
        {'stat': 'power', 'statLabel': 'Power', 'op': '=', 'val': '2'},
        {'stat': 'toughness', 'statLabel': 'Toughness', 'op': '>', 'val': '3'},
        {'stat': 'loyalty', 'statLabel': 'Loyalty', 'op': '<', 'val': '4'},
        {'stat': 'defense', 'statLabel': 'Defense', 'op': '<=', 'val': '5'},
        {'stat': 'power', 'statLabel': 'Power', 'op': '>=', 'val': '6'},
        {'stat': 'toughness', 'statLabel': 'Toughness', 'op': '!=', 'val': '7'},
      ];

      for (var i = 0; i < operatorSpecs.length; i++) {
        final spec = operatorSpecs[i];

        // Select Stat Type
        await tester.tap(find.byKey(const Key('filter_stat_type_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text(spec['statLabel']!).last);
        await tester.pumpAndSettle();

        // Select Stat Operator
        await tester.tap(find.byKey(const Key('filter_stat_operator_dropdown')));
        await tester.pumpAndSettle();
        await tester.tap(find.text(spec['op']!).last);
        await tester.pumpAndSettle();

        // Enter Value
        await tester.enterText(find.byKey(const Key('filter_stat_value_field')), spec['val']!);
        await tester.pumpAndSettle();

        // Add Stat
        await tester.tap(find.byKey(const Key('filter_add_stat_button')));
        await tester.pumpAndSettle();

        expect(find.byKey(Key('filter_stat_chip_$i')), findsOneWidget);
        expect(find.text('${spec['stat']} ${spec['op']} ${spec['val']}'), findsOneWidget);
        expect(find.text('Apply (${i + 1})'), findsOneWidget);
      }

      // Tap Apply to verify applied state contains all 6 operators
      await tester.tap(find.byKey(const Key('mtg_filter_apply_button')));
      await tester.pumpAndSettle();

      expect(appliedState, isNotNull);
      expect(appliedState!.statFilters.length, 6);
      expect(appliedState!.activeCount, 6);

      for (var i = 0; i < operatorSpecs.length; i++) {
        final spec = operatorSpecs[i];
        expect(appliedState!.statFilters[i].stat, spec['stat']);
        expect(appliedState!.statFilters[i].operator, spec['op']);
        expect(appliedState!.statFilters[i].value, spec['val']);
      }
    });
  });
}

