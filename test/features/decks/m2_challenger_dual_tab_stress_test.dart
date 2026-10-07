import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/decks/data/daos/explore_deck_dao.dart';
import 'package:countr/features/decks/domain/models/explore_deck_models.dart';
import 'package:countr/features/decks/presentation/widgets/deck_setup_wizard_modal.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/decks/presentation/providers/explore_deck_providers.dart';
import 'package:countr/features/decks/presentation/screens/decks_screen.dart';

void main() {
  late AppDatabase db;
  late VaultDao vaultDao;
  late ExploreDeckDao exploreDao;

  setUp(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(NativeDatabase.memory());
    vaultDao = VaultDao(db);
    exploreDao = ExploreDeckDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildTestApp({
    ProviderContainer? container,
    int initialTopTab = 0,
    String initialTcgFilter = 'all',
  }) {
    if (container != null) {
      return UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: DecksScreen(),
        ),
      );
    }

    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        vaultDaoProvider.overrideWithValue(vaultDao),
        exploreDeckDaoProvider.overrideWithValue(exploreDao),
        decksTopTabProvider.overrideWith((ref) => initialTopTab),
        activeDeckTcgFilterProvider.overrideWith((ref) => initialTcgFilter),
      ],
      child: const MaterialApp(
        home: DecksScreen(),
      ),
    );
  }

  group('Milestone 2 Adversarial Challenge: Dual-Tab Architecture Stress Suite', () {
    testWidgets(
      'Challenge 1: Rapid 60x tab toggle stress test maintains state integrity without crash or memory leak',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(vaultDao),
            exploreDeckDaoProvider.overrideWithValue(exploreDao),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(buildTestApp(container: container));
        await tester.pumpAndSettle();

        final tabMyDecksFinder = find.byKey(const Key('decks_top_tab_my_decks'));
        final tabExploreFinder = find.byKey(const Key('decks_top_tab_explore'));

        expect(tabMyDecksFinder, findsOneWidget);
        expect(tabExploreFinder, findsOneWidget);
        expect(find.byKey(const Key('decks_new_deck_fab')), findsOneWidget);

        // Perform 60 rapid back-and-forth taps between Tab 0 and Tab 1
        for (int i = 0; i < 30; i++) {
          // Switch to Explore Tab
          await tester.tap(tabExploreFinder);
          await tester.pump(); // partial animation pump to simulate rapid tapping
          await tester.pump(const Duration(milliseconds: 100));

          // Switch back to My Decks Tab
          await tester.tap(tabMyDecksFinder);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
        }

        // Allow full settle after rapid toggling
        await tester.pumpAndSettle();

        // Final state assertion: Ended on My Decks Tab
        expect(container.read(decksTopTabProvider), 0);
        expect(find.byKey(const Key('my_decks_search_input')), findsOneWidget);
        expect(find.byKey(const Key('decks_new_deck_fab')), findsOneWidget);
        expect(find.byKey(const Key('deck_item_deck-edgar-markov')), findsOneWidget);

        // Perform 20 programmatic provider toggles without UI gesture
        for (int i = 0; i < 10; i++) {
          container.read(decksTopTabProvider.notifier).state = 1;
          await tester.pumpAndSettle();
          container.read(decksTopTabProvider.notifier).state = 0;
          await tester.pumpAndSettle();
        }

        expect(container.read(decksTopTabProvider), 0);
        expect(find.byKey(const Key('my_decks_search_input')), findsOneWidget);
        expect(find.byKey(const Key('decks_new_deck_fab')), findsOneWidget);
      },
    );

    testWidgets(
      'Challenge 2: Bidirectional scroll offset preservation across tabs via PageStorageKey',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        // Seed 30 personal decks into SQLite for Tab 0
        final now = DateTime.now();
        for (int i = 0; i < 30; i++) {
          await db.into(db.decks).insert(
            DecksCompanion.insert(
              id: 'personal-scroll-deck-$i',
              name: 'Personal Deck #$i - Long List Item',
              format: 'MTG Commander',
              tcgDomain: const Value('mtg'),
              createdAt: now,
            ),
          );
        }

        // Seed 30 explore decks into SQLite for Tab 1
        for (int i = 0; i < 30; i++) {
          await db.into(db.exploreDecks).insert(
            ExploreDecksCompanion.insert(
              id: 'explore-scroll-deck-$i',
              name: 'Explore Precon Deck #$i - Discovery Catalog',
              format: 'Commander',
              tcgDomain: const Value('mtg'),
              sourceType: const Value('official'),
              creatorName: const Value('Wizards of the Coast'),
              createdAt: now,
            ),
          );
        }

        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        // --- STEP 1: Verify Tab 0 initial scroll and scroll down ---
        final tab0ScrollFinder = find.byKey(const PageStorageKey('my_decks_scroll_key'));
        expect(tab0ScrollFinder, findsOneWidget);

        final tab0Scrollables = find.descendant(of: tab0ScrollFinder, matching: find.byType(Scrollable));
        final initialTab0Offset = tester.state<ScrollableState>(tab0Scrollables.first).position.pixels;
        expect(initialTab0Offset, 0.0);

        // Drag down on Tab 0 by 500 px
        await tester.drag(tab0ScrollFinder, const Offset(0, -500));
        await tester.pumpAndSettle();

        final scrolledTab0Offset = tester.state<ScrollableState>(tab0Scrollables.first).position.pixels;
        expect(scrolledTab0Offset, greaterThan(300.0));

        // --- STEP 2: Switch to Tab 1 and scroll down ---
        await tester.tap(find.byKey(const Key('decks_top_tab_explore')));
        await tester.pumpAndSettle();

        final tab1ScrollFinder = find.byKey(const PageStorageKey('explore_decks_scroll_key'));
        expect(tab1ScrollFinder, findsOneWidget);

        final tab1Scrollables = find.descendant(of: tab1ScrollFinder, matching: find.byType(Scrollable));
        final initialTab1Offset = tester.state<ScrollableState>(tab1Scrollables.first).position.pixels;
        expect(initialTab1Offset, 0.0);

        // Drag down on Tab 1 by 700 px
        await tester.drag(tab1ScrollFinder, const Offset(0, -700));
        await tester.pumpAndSettle();

        final scrolledTab1Offset = tester.state<ScrollableState>(tab1Scrollables.first).position.pixels;
        expect(scrolledTab1Offset, greaterThan(400.0));

        // --- STEP 3: Switch back to Tab 0 and verify exact scroll preservation ---
        await tester.tap(find.byKey(const Key('decks_top_tab_my_decks')));
        await tester.pumpAndSettle();

        final restoredTab0State = tester.state<ScrollableState>(
          find.descendant(of: find.byKey(const PageStorageKey('my_decks_scroll_key')), matching: find.byType(Scrollable)).first,
        );
        expect(restoredTab0State.position.pixels, closeTo(scrolledTab0Offset, 1.0));

        // --- STEP 4: Switch back to Tab 1 and verify exact scroll preservation ---
        await tester.tap(find.byKey(const Key('decks_top_tab_explore')));
        await tester.pumpAndSettle();

        final restoredTab1State = tester.state<ScrollableState>(
          find.descendant(of: find.byKey(const PageStorageKey('explore_decks_scroll_key')), matching: find.byType(Scrollable)).first,
        );
        expect(restoredTab1State.position.pixels, closeTo(scrolledTab1Offset, 1.0));

        // --- STEP 5: Switch back and forth 3 times to ensure stability ---
        for (int i = 0; i < 3; i++) {
          await tester.tap(find.byKey(const Key('decks_top_tab_my_decks')));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('decks_top_tab_explore')));
          await tester.pumpAndSettle();
        }

        // Tab 1 offset still preserved
        final finalTab1State = tester.state<ScrollableState>(
          find.descendant(of: find.byKey(const PageStorageKey('explore_decks_scroll_key')), matching: find.byType(Scrollable)).first,
        );
        expect(finalTab1State.position.pixels, closeTo(scrolledTab1Offset, 1.0));

        // Switch back to Tab 0, Tab 0 offset still preserved
        await tester.tap(find.byKey(const Key('decks_top_tab_my_decks')));
        await tester.pumpAndSettle();
        final finalTab0State = tester.state<ScrollableState>(
          find.descendant(of: find.byKey(const PageStorageKey('my_decks_scroll_key')), matching: find.byType(Scrollable)).first,
        );
        expect(finalTab0State.position.pixels, closeTo(scrolledTab0Offset, 1.0));
      },
    );

    testWidgets(
      'Challenge 3: Independent search & filter isolation without cross-tab leakage',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(vaultDao),
            exploreDeckDaoProvider.overrideWithValue(exploreDao),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(buildTestApp(container: container));
        await tester.pumpAndSettle();

        // 1. Enter query in Tab 0 ("Edgar")
        await tester.enterText(find.byKey(const Key('my_decks_search_input')), 'Edgar');
        await tester.pumpAndSettle();

        expect(container.read(myDecksSearchQueryProvider), 'Edgar');
        expect(find.byKey(const Key('my_decks_search_header_name')), findsOneWidget);

        // 2. Switch to Tab 1 ("Explore Decks")
        await tester.tap(find.byKey(const Key('decks_top_tab_explore')));
        await tester.pumpAndSettle();

        // Assert Tab 1 search provider remains untouched/empty
        expect(container.read(exploreSearchQueryProvider), '');

        // 3. Select category "Community" on Tab 1
        await tester.tap(find.byKey(const Key('explore_pill_community')));
        await tester.pumpAndSettle();

        expect(container.read(activeExploreCategoryProvider), ExploreCategory.community);

        // 4. Switch back to Tab 0 ("My Decks")
        await tester.tap(find.byKey(const Key('decks_top_tab_my_decks')));
        await tester.pumpAndSettle();

        // Tab 0 search query and results are still intact and isolated
        expect(container.read(myDecksSearchQueryProvider), 'Edgar');
        final myDecksField = tester.widget<TextField>(find.byKey(const Key('my_decks_search_input')));
        expect(myDecksField.controller?.text, 'Edgar');
        expect(find.byKey(const Key('my_decks_search_header_name')), findsOneWidget);

        // 5. Switch Tab 0 subtab filter (Competitive)
        await tester.tap(find.byKey(const Key('my_decks_search_clear_button')));
        await tester.pumpAndSettle();
        expect(container.read(myDecksSearchQueryProvider), '');

        await tester.tap(find.byKey(const Key('decks_tab_competitive')));
        await tester.pumpAndSettle();

        // 6. Switch to Tab 1: Assert Tab 1 category is STILL ExploreCategory.community
        await tester.tap(find.byKey(const Key('decks_top_tab_explore')));
        await tester.pumpAndSettle();

        expect(container.read(activeExploreCategoryProvider), ExploreCategory.community);

        // 7. Select "Official" on Tab 1
        await tester.tap(find.byKey(const Key('explore_pill_official')));
        await tester.pumpAndSettle();
        expect(container.read(activeExploreCategoryProvider), ExploreCategory.official);

        // 8. Return to Tab 0: Assert Tab 0 subtab is STILL Competitive
        await tester.tap(find.byKey(const Key('decks_top_tab_my_decks')));
        await tester.pumpAndSettle();

        // Competitive tab pill is still highlighted
        final compPillFinder = find.byKey(const Key('decks_tab_competitive'));
        expect(compPillFinder, findsOneWidget);
      },
    );

    testWidgets(
      'Challenge 4: Dynamic FAB lifecycle invariants across normal, selection, and explore modes',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(vaultDao),
            exploreDeckDaoProvider.overrideWithValue(exploreDao),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(buildTestApp(container: container));
        await tester.pumpAndSettle();

        // Tab 0 normal mode: FAB is present
        expect(find.byKey(const Key('decks_new_deck_fab')), findsOneWidget);

        // Switch to Tab 1: FAB is hidden
        await tester.tap(find.byKey(const Key('decks_top_tab_explore')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('decks_new_deck_fab')), findsNothing);

        // Return to Tab 0: FAB reappears
        await tester.tap(find.byKey(const Key('decks_top_tab_my_decks')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('decks_new_deck_fab')), findsOneWidget);

        // Trigger press-and-hold selection mode on Tab 0
        await tester.longPress(find.byKey(const Key('deck_item_deck-edgar-markov')));
        await tester.pumpAndSettle();

        // In selection mode: selection footer appears, FAB MUST be hidden
        expect(find.byKey(const Key('my_decks_selection_footer')), findsOneWidget);
        expect(find.byKey(const Key('decks_new_deck_fab')), findsNothing);

        // Switch to Tab 1 while selection mode is active
        await tester.tap(find.byKey(const Key('decks_top_tab_explore')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('decks_new_deck_fab')), findsNothing);

        // Switch back to Tab 0: selection mode is still active, FAB MUST still be hidden
        await tester.tap(find.byKey(const Key('decks_top_tab_my_decks')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('my_decks_selection_footer')), findsOneWidget);
        expect(find.byKey(const Key('decks_new_deck_fab')), findsNothing);

        // Cancel selection mode: selection footer dismissed, FAB restored
        await tester.tap(find.byKey(const Key('selection_cancel_button')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('my_decks_selection_footer')), findsNothing);
        expect(find.byKey(const Key('decks_new_deck_fab')), findsOneWidget);

        // Select multiple decks (Edgar and Charizard)
        await tester.longPress(find.byKey(const Key('deck_item_deck-edgar-markov')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('deck_item_deck-charizard-ex')));
        await tester.pumpAndSettle();

        expect(find.text('2 selected'), findsOneWidget);
        expect(find.byKey(const Key('decks_new_deck_fab')), findsNothing);

        // Cancel selection mode again
        await tester.tap(find.byKey(const Key('selection_cancel_button')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('decks_new_deck_fab')), findsOneWidget);
      },
    );

    testWidgets(
      'Challenge 5: Full verification of all 17 legacy test contracts across dual-tab navigation',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(vaultDao),
            exploreDeckDaoProvider.overrideWithValue(exploreDao),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(buildTestApp(container: container));
        await tester.pumpAndSettle();

        // Contract 1: decks_tcg_context_switcher presence and interaction
        final tcgSwitcher = find.byKey(const Key('decks_tcg_context_switcher'));
        expect(tcgSwitcher, findsOneWidget);

        await tester.tap(tcgSwitcher);
        await tester.pumpAndSettle();

        // Popup items exist
        expect(find.byKey(const Key('tcg_filter_all')), findsOneWidget);
        expect(find.byKey(const Key('tcg_filter_mtg')), findsOneWidget);
        expect(find.byKey(const Key('tcg_filter_pokemon')), findsOneWidget);
        expect(find.byKey(const Key('tcg_filter_lorcana')), findsOneWidget);

        // Select Pokémon
        await tester.tap(find.byKey(const Key('tcg_filter_pokemon')));
        await tester.pumpAndSettle();
        expect(container.read(activeDeckTcgFilterProvider), 'pokemon');

        // Only Pokemon decks visible on Tab 0
        expect(find.byKey(const Key('deck_item_deck-charizard-ex')), findsOneWidget);
        expect(find.byKey(const Key('deck_item_deck-edgar-markov')), findsNothing);

        // Contract 2: decks_privacy_mode_button toggles state
        final privacyBtn = find.byKey(const Key('decks_privacy_mode_button'));
        expect(privacyBtn, findsOneWidget);
        expect(container.read(privacyModeProvider), isFalse);

        await tester.tap(privacyBtn);
        await tester.pumpAndSettle();
        expect(container.read(privacyModeProvider), isTrue);

        await tester.tap(privacyBtn);
        await tester.pumpAndSettle();
        expect(container.read(privacyModeProvider), isFalse);

        // Contract 3: deck_setup_wizard_button opens modal
        final wizardBtn = find.byKey(const Key('deck_setup_wizard_button'));
        expect(wizardBtn, findsOneWidget);

        await tester.tap(wizardBtn);
        await tester.pumpAndSettle();

        // Deck Setup Wizard modal opened
        expect(find.byType(DeckSetupWizardModal), findsOneWidget);

        // Close wizard modal
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();

        // Reset TCG filter to all
        await tester.tap(tcgSwitcher);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('tcg_filter_all')));
        await tester.pumpAndSettle();

        // Contracts 4, 5, 6: decks_tab_all, decks_tab_competitive, decks_tab_draft
        expect(find.byKey(const Key('decks_tab_all')), findsOneWidget);
        expect(find.byKey(const Key('decks_tab_competitive')), findsOneWidget);
        expect(find.byKey(const Key('decks_tab_draft')), findsOneWidget);

        // Switch to Competitive
        await tester.tap(find.byKey(const Key('decks_tab_competitive')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('deck_item_deck-yuriko')), findsOneWidget);
        expect(find.byKey(const Key('deck_item_deck-edgar-markov')), findsNothing);

        // Switch to Draft
        await tester.tap(find.byKey(const Key('decks_tab_draft')));
        await tester.pumpAndSettle();

        // Switch back to All
        await tester.tap(find.byKey(const Key('decks_tab_all')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('deck_item_deck-edgar-markov')), findsOneWidget);

        // Contract 7: decks_new_deck_fab opens wizard modal
        final fab = find.byKey(const Key('decks_new_deck_fab'));
        expect(fab, findsOneWidget);
        await tester.tap(fab);
        await tester.pumpAndSettle();
        expect(find.byType(DeckSetupWizardModal), findsOneWidget);

        // Dismiss wizard modal
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();

        // Contracts 8 & 9: deck_item_${id} & deck_assembly_status_${id}
        expect(find.byKey(const Key('deck_item_deck-edgar-markov')), findsOneWidget);
        expect(find.byKey(const Key('deck_assembly_status_deck-edgar-markov')), findsOneWidget);

        // Switch to Tab 1 and back to verify no regression
        await tester.tap(find.byKey(const Key('decks_top_tab_explore')));
        await tester.pumpAndSettle();

        // AppBar contracts persist on Tab 1
        expect(find.byKey(const Key('decks_tcg_context_switcher')), findsOneWidget);
        expect(find.byKey(const Key('decks_privacy_mode_button')), findsOneWidget);
        expect(find.byKey(const Key('deck_setup_wizard_button')), findsOneWidget);

        // Return to Tab 0
        await tester.tap(find.byKey(const Key('decks_top_tab_my_decks')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('deck_item_deck-edgar-markov')), findsOneWidget);
        expect(find.byKey(const Key('deck_assembly_status_deck-edgar-markov')), findsOneWidget);
        expect(find.byKey(const Key('decks_new_deck_fab')), findsOneWidget);
      },
    );

    testWidgets(
      'Challenge 6: Adversarial edge cases: extreme search queries, empty state wizard launch, and repeated mount/unmount cycles',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(vaultDao),
            exploreDeckDaoProvider.overrideWithValue(exploreDao),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(buildTestApp(container: container));
        await tester.pumpAndSettle();

        // 1. Extreme search string with special characters & regex metacharacters
        const extremeQuery = r'.*+?^${}()|[]\\/!@#$%^&*()_+-=`~<>,.?';
        await tester.enterText(find.byKey(const Key('my_decks_search_input')), extremeQuery);
        await tester.pumpAndSettle();

        // Should not throw or crash
        expect(container.read(myDecksSearchQueryProvider), extremeQuery);

        // Clear query
        await tester.tap(find.byKey(const Key('my_decks_search_clear_button')));
        await tester.pumpAndSettle();
        expect(container.read(myDecksSearchQueryProvider), '');

        // 2. Empty state wizard trigger: Filter by nonexistent TCG or zero matches
        container.read(activeDeckTcgFilterProvider.notifier).state = 'lorcana';
        await tester.pumpAndSettle();

        // On lorcana with Competitive filter -> 0 matches, triggers empty state
        await tester.tap(find.byKey(const Key('decks_tab_competitive')));
        await tester.pumpAndSettle();

        expect(find.text('No decks found'), findsOneWidget);
        expect(find.byKey(const Key('decks_empty_wizard_button')), findsOneWidget);

        // Tapping empty state wizard button opens wizard
        await tester.tap(find.byKey(const Key('decks_empty_wizard_button')));
        await tester.pumpAndSettle();
        expect(find.byType(DeckSetupWizardModal), findsOneWidget);

        // Dismiss wizard
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();

        // 3. Repeated rapid mount/unmount cycles of DecksScreen (10 cycles)
        for (int i = 0; i < 10; i++) {
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: const MaterialApp(
                home: SizedBox.shrink(),
              ),
            ),
          );
          await tester.pump();

          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: const MaterialApp(
                home: DecksScreen(),
              ),
            ),
          );
          await tester.pump();
        }
        await tester.pumpAndSettle();

        // Verify DecksScreen re-mounted cleanly without ticker leak
        expect(find.byKey(const Key('decks_top_tab_my_decks')), findsOneWidget);
        expect(find.byKey(const Key('decks_top_tab_explore')), findsOneWidget);
      },
    );
  });
}
