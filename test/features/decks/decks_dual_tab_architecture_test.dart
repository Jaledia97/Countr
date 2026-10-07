import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/decks/data/daos/explore_deck_dao.dart';
import 'package:countr/features/decks/domain/models/explore_deck_models.dart';
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

  Widget createSubject({
    int initialTopTab = 0,
    String initialTcgFilter = 'all',
    List<ExploreDeckWithVote>? customExploreDecks,
  }) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        vaultDaoProvider.overrideWithValue(vaultDao),
        exploreDeckDaoProvider.overrideWithValue(exploreDao),
        decksTopTabProvider.overrideWith((ref) => initialTopTab),
        activeDeckTcgFilterProvider.overrideWith((ref) => initialTcgFilter),
        if (customExploreDecks != null)
          exploreDecksStreamProvider.overrideWith((ref) => Stream.value(customExploreDecks)),
      ],
      child: const MaterialApp(
        home: DecksScreen(),
      ),
    );
  }

  group('Milestone 2: Dual-Tab Architecture Tests', () {
    testWidgets('1. TabBar renders with "My Decks" and "Explore Decks" tabs, defaulting to Tab 0',
        (tester) async {
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      // Top TabBar with specific keys
      final myDecksTabFinder = find.byKey(const Key('decks_top_tab_my_decks'));
      final exploreTabFinder = find.byKey(const Key('decks_top_tab_explore'));

      expect(myDecksTabFinder, findsOneWidget);
      expect(exploreTabFinder, findsOneWidget);
      expect(find.descendant(of: myDecksTabFinder, matching: find.text('My Decks')), findsOneWidget);
      expect(find.descendant(of: exploreTabFinder, matching: find.text('Explore Decks')), findsOneWidget);

      // Default active tab is My Decks: personal filters, search bar, and deck cards are visible
      expect(find.byKey(const Key('my_decks_search_input')), findsOneWidget);
      expect(find.byKey(const Key('decks_tab_all')), findsOneWidget);
      expect(find.byKey(const Key('decks_tab_competitive')), findsOneWidget);
      expect(find.byKey(const Key('decks_tab_draft')), findsOneWidget);
      expect(find.byKey(const Key('deck_item_deck-edgar-markov')), findsOneWidget);

      // FAB is visible on Tab 0
      expect(find.byKey(const Key('decks_new_deck_fab')), findsOneWidget);
    });

    testWidgets('2. Tapping "Explore Decks" switches to Explore tab and hides FAB', (tester) async {
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      // Tap Explore Decks tab
      await tester.tap(find.byKey(const Key('decks_top_tab_explore')));
      await tester.pumpAndSettle();

      // Explore Category Pills should now be mounted
      expect(find.byKey(const Key('explore_pill_all')), findsOneWidget);
      expect(find.byKey(const Key('explore_pill_official')), findsOneWidget);
      expect(find.byKey(const Key('explore_pill_community')), findsOneWidget);

      // FAB should be hidden on Tab 1
      expect(find.byKey(const Key('decks_new_deck_fab')), findsNothing);

      // Tap back to My Decks
      await tester.tap(find.byKey(const Key('decks_top_tab_my_decks')));
      await tester.pumpAndSettle();

      // FAB is restored on Tab 0
      expect(find.byKey(const Key('decks_new_deck_fab')), findsOneWidget);
      expect(find.byKey(const Key('deck_item_deck-edgar-markov')), findsOneWidget);
    });

    testWidgets('3. Swiping between tabs navigates smoothly via TabBarView', (tester) async {
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('my_decks_search_input')), findsOneWidget);

      // Swipe left from Tab 0 to Tab 1
      await tester.fling(find.byType(TabBarView), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();

      // Now on Explore Decks
      expect(find.byKey(const Key('explore_pill_all')), findsOneWidget);
      expect(find.byKey(const Key('decks_new_deck_fab')), findsNothing);

      // Swipe right back to Tab 0
      await tester.fling(find.byType(TabBarView), const Offset(400, 0), 1000);
      await tester.pumpAndSettle();

      // Back on My Decks
      expect(find.byKey(const Key('my_decks_search_input')), findsOneWidget);
      expect(find.byKey(const Key('decks_new_deck_fab')), findsOneWidget);
    });

    testWidgets('4. State Isolation: My Decks search query and filters persist across tab switches',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(vaultDao),
          exploreDeckDaoProvider.overrideWithValue(exploreDao),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: DecksScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Enter search query in My Decks
      await tester.enterText(find.byKey(const Key('my_decks_search_input')), 'Edgar');
      await tester.pumpAndSettle();

      expect(container.read(myDecksSearchQueryProvider), 'Edgar');

      // Switch to Explore tab
      await tester.tap(find.byKey(const Key('decks_top_tab_explore')));
      await tester.pumpAndSettle();

      // Select category in Explore tab
      await tester.tap(find.byKey(const Key('explore_pill_community')));
      await tester.pumpAndSettle();

      expect(container.read(activeExploreCategoryProvider), ExploreCategory.community);
      // Explore search query remains clean/isolated
      expect(container.read(exploreSearchQueryProvider), '');

      // Switch back to My Decks
      await tester.tap(find.byKey(const Key('decks_top_tab_my_decks')));
      await tester.pumpAndSettle();

      // My Decks search query and text field are preserved
      expect(container.read(myDecksSearchQueryProvider), 'Edgar');
      final searchField = tester.widget<TextField>(find.byKey(const Key('my_decks_search_input')));
      expect(searchField.controller?.text, 'Edgar');
    });

    testWidgets('5. Scroll offset preservation across tab switches via PageStorageKey', (tester) async {
      // Create a tall list of mock decks in DB
      for (int i = 0; i < 20; i++) {
        await db.into(db.decks).insert(
          DecksCompanion.insert(
            id: 'scroll-deck-$i',
            name: 'Scrollable Deck #$i',
            format: 'MTG Commander',
            tcgDomain: const Value('mtg'),
            createdAt: DateTime.now(),
          ),
        );
      }

      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      final scrollFinder = find.byKey(const PageStorageKey('my_decks_scroll_key'));
      expect(scrollFinder, findsOneWidget);

      // Scroll down by 400 pixels
      await tester.drag(scrollFinder, const Offset(0, -400));
      await tester.pumpAndSettle();

      final scrollableState = tester.state<ScrollableState>(
        find.descendant(of: scrollFinder, matching: find.byType(Scrollable)),
      );
      final initialOffset = scrollableState.position.pixels;
      expect(initialOffset, greaterThan(200));

      // Switch to Explore tab
      await tester.tap(find.byKey(const Key('decks_top_tab_explore')));
      await tester.pumpAndSettle();

      // Switch back to My Decks tab
      await tester.tap(find.byKey(const Key('decks_top_tab_my_decks')));
      await tester.pumpAndSettle();

      // Assert scroll position was preserved exactly
      final restoredScrollableState = tester.state<ScrollableState>(
        find.descendant(of: scrollFinder, matching: find.byType(Scrollable)),
      );
      expect(restoredScrollableState.position.pixels, closeTo(initialOffset, 1.0));
    });

    testWidgets('6. AppBar actions persist across both tabs', (tester) async {
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      // On Tab 0
      expect(find.byKey(const Key('decks_tcg_context_switcher')), findsOneWidget);
      expect(find.byKey(const Key('decks_privacy_mode_button')), findsOneWidget);
      expect(find.byKey(const Key('deck_setup_wizard_button')), findsOneWidget);

      // On Tab 1
      await tester.tap(find.byKey(const Key('decks_top_tab_explore')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('decks_tcg_context_switcher')), findsOneWidget);
      expect(find.byKey(const Key('decks_privacy_mode_button')), findsOneWidget);
      expect(find.byKey(const Key('deck_setup_wizard_button')), findsOneWidget);
    });
  });
}
