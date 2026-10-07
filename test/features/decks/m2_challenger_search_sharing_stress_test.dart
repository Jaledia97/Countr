import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/decks/data/daos/explore_deck_dao.dart';
import 'package:countr/features/decks/domain/models/deck_summary.dart';
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
    List<DeckSummary>? initialSummaries,
  }) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        vaultDaoProvider.overrideWithValue(vaultDao),
        exploreDeckDaoProvider.overrideWithValue(exploreDao),
        if (initialSummaries != null)
          deckSummariesProvider.overrideWith((ref) => Stream.value(initialSummaries)),
      ],
      child: const MaterialApp(
        home: DecksScreen(),
      ),
    );
  }

  group('M2 Empirical Challenger: Search Partitioning, Invariants & Sharing', () {
    // -------------------------------------------------------------------------
    // 1. Search Partitioning & Visual Dividers
    // -------------------------------------------------------------------------
    testWidgets('1.1 Search partitioning: Tier 1 only matches render "in Deck Name" and NO divider',
        (tester) async {
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      // Search for "Mono-Green" (only in deck name "Modern Mono-Green Tron")
      await tester.enterText(find.byKey(const Key('my_decks_search_input')), 'Mono-Green');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('my_decks_search_header_name')), findsOneWidget);
      expect(find.text('Modern Mono-Green Tron'), findsOneWidget);
      expect(find.byKey(const Key('my_decks_search_header_cards')), findsNothing);
      // Divider must NOT be rendered when only Tier 1 has matches
      expect(find.byType(Divider), findsNothing);
    });

    testWidgets('1.2 Search partitioning: Tier 2 only matches render "contains Card" with chip and NO divider',
        (tester) async {
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      // "Sol Ring" is in Edgar Markov cards, not in any deck name
      await tester.enterText(find.byKey(const Key('my_decks_search_input')), 'Sol Ring');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('my_decks_search_header_name')), findsNothing);
      expect(find.byKey(const Key('my_decks_search_header_cards')), findsOneWidget);
      expect(find.text('Edgar Markov Aristocrats'), findsOneWidget);

      final chipFinder = find.byKey(const Key('deck_card_match_chip_deck-edgar-markov'));
      expect(chipFinder, findsOneWidget);
      expect(
        find.descendant(of: chipFinder, matching: find.text('Contains: Sol Ring (x1)')),
        findsOneWidget,
      );

      // Divider must NOT be rendered when only Tier 2 has matches
      expect(find.byType(Divider), findsNothing);
    });

    testWidgets('1.3 Search partitioning: Dual tier matches render both headers AND visual divider line break',
        (tester) async {
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      // "Tron" matches "Modern Mono-Green Tron" in deck name, and "Patron of the Vein" in Edgar Markov cards
      await tester.enterText(find.byKey(const Key('my_decks_search_input')), 'Tron');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('my_decks_search_header_name')), findsOneWidget);
      expect(find.text('Modern Mono-Green Tron'), findsOneWidget);
      expect(find.byKey(const Key('my_decks_search_header_cards')), findsOneWidget);
      expect(find.text('Edgar Markov Aristocrats'), findsOneWidget);

      // Visual divider must be present between the two sections
      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets('1.4 Deduplication invariant: Deck matching in Deck Name does NOT repeat under contains Card',
        (tester) async {
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      // "Charizard" matches "Charizard ex / Pidgeot ex" deck name AND contains card "Charizard ex"
      await tester.enterText(find.byKey(const Key('my_decks_search_input')), 'Charizard');
      await tester.pumpAndSettle();

      // Deck should appear under "in Deck Name"
      expect(find.byKey(const Key('my_decks_search_header_name')), findsOneWidget);
      expect(find.text('Charizard ex / Pidgeot ex'), findsOneWidget);

      // Deduplication invariant: Must NOT duplicate under "contains Card"
      expect(find.byKey(const Key('my_decks_search_header_cards')), findsNothing);
      expect(find.byKey(const Key('deck_card_match_chip_deck-charizard-ex')), findsNothing);
      expect(find.byType(Divider), findsNothing);
    });

    testWidgets('1.5 SQLite-persisted deck and card search: matches cards from database with exact quantity',
        (tester) async {
      // Insert a custom deck with cards into SQLite
      await db.into(db.decks).insert(
        DecksCompanion.insert(
          id: 'deck-db-goblins',
          name: 'Legacy Goblins Aggro',
          format: 'Legacy',
          tcgDomain: const Value('mtg'),
          createdAt: DateTime.now(),
        ),
      );
      await db.into(db.deckVersions).insert(
        DeckVersionsCompanion.insert(
          id: 'ver-goblins-1',
          deckId: 'deck-db-goblins',
          versionNumber: 1,
          isActive: const Value(true),
          createdAt: DateTime.now(),
        ),
      );
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-piledriver-1',
          collectionType: 'mtg',
          name: 'Goblin Piledriver',
          setOrSeries: 'ONS',
          imageUrl: 'https://example.com/piledriver.jpg',
          acquiredPrice: 4.0,
          acquiredDate: DateTime.now(),
          quantity: const Value(4),
          condition: 'NM',
          currentMarketPrice: 5.0,
          lastPriceUpdate: DateTime.now(),
          dynamicData: '{"name":"Goblin Piledriver"}',
        ),
      );
      await db.into(db.deckVersionItems).insert(
        DeckVersionItemsCompanion.insert(
          id: 'dvi-piledriver-1',
          versionId: 'ver-goblins-1',
          vaultItemId: 'card-piledriver-1',
          boardZone: 'Mainboard',
          quantity: const Value(4),
        ),
      );

      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      // Search for "Piledriver"
      await tester.enterText(find.byKey(const Key('my_decks_search_input')), 'Piledriver');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('my_decks_search_header_cards')), findsOneWidget);
      expect(find.text('Legacy Goblins Aggro'), findsOneWidget);

      final chipFinder = find.byKey(const Key('deck_card_match_chip_deck-db-goblins'));
      expect(chipFinder, findsOneWidget);
      expect(
        find.descendant(of: chipFinder, matching: find.text('Contains: Goblin Piledriver (x4)')),
        findsOneWidget,
      );
    });

    // -------------------------------------------------------------------------
    // 2. Boundary Search Strings & Special Characters
    // -------------------------------------------------------------------------
    testWidgets('2.1 Boundary search: Empty string and whitespace queries keep standard view intact',
        (tester) async {
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      final searchInput = find.byKey(const Key('my_decks_search_input'));

      // Empty string
      await tester.enterText(searchInput, '');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('my_decks_search_header_name')), findsNothing);
      expect(find.byKey(const Key('my_decks_search_header_cards')), findsNothing);
      expect(find.byKey(const Key('deck_item_deck-edgar-markov')), findsOneWidget);

      // Whitespace only
      await tester.enterText(searchInput, '     ');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('my_decks_search_header_name')), findsNothing);
      expect(find.byKey(const Key('my_decks_search_header_cards')), findsNothing);
      expect(find.byKey(const Key('deck_item_deck-edgar-markov')), findsOneWidget);
    });

    testWidgets('2.2 Boundary search: Regex meta-characters do not throw exceptions or crash',
        (tester) async {
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      final searchInput = find.byKey(const Key('my_decks_search_input'));

      // Query with regex meta-characters
      final regexPatterns = ['.*', '[a-z]+', '(', r'\d+', r'^deck$', '(?=.*)'];
      for (final pattern in regexPatterns) {
        await tester.enterText(searchInput, pattern);
        await tester.pumpAndSettle();

        // No uncaught exception, UI shows "No decks found"
        expect(find.text('No decks found'), findsOneWidget);
        expect(find.text('No personal decks or cards match "$pattern".'), findsOneWidget);
      }
    });

    testWidgets('2.3 Boundary search: Punctuation, commas, apostrophes, and slashes match accurately',
        (tester) async {
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      final searchInput = find.byKey(const Key('my_decks_search_input'));

      // Apostrophe in "Tiger's" matches "Yuriko, the Tiger's Shadow"
      await tester.enterText(searchInput, "Tiger's");
      await tester.pumpAndSettle();
      expect(find.text("Yuriko, the Tiger's Shadow"), findsOneWidget);

      // Just an apostrophe "'" matches
      await tester.enterText(searchInput, "'");
      await tester.pumpAndSettle();
      expect(find.text("Yuriko, the Tiger's Shadow"), findsOneWidget);

      // Slash and space in "ex /" matches "Charizard ex / Pidgeot ex"
      await tester.enterText(searchInput, "ex /");
      await tester.pumpAndSettle();
      expect(find.text('Charizard ex / Pidgeot ex'), findsOneWidget);

      // Comma in "Yuriko," matches
      await tester.enterText(searchInput, "Yuriko,");
      await tester.pumpAndSettle();
      expect(find.text("Yuriko, the Tiger's Shadow"), findsOneWidget);
    });

    testWidgets('2.4 Boundary search: Unicode emojis and multi-byte characters are handled gracefully',
        (tester) async {
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      final searchInput = find.byKey(const Key('my_decks_search_input'));

      // Emojis
      await tester.enterText(searchInput, '🔥🐉⚡️');
      await tester.pumpAndSettle();
      expect(find.text('No decks found'), findsOneWidget);
      expect(find.text('No personal decks or cards match "🔥🐉⚡️".'), findsOneWidget);

      // Japanese kanji / hiragana
      await tester.enterText(searchInput, '百合子');
      await tester.pumpAndSettle();
      expect(find.text('No decks found'), findsOneWidget);
    });

    testWidgets('2.5 Boundary search: Single character queries match across multiple decks smoothly',
        (tester) async {
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      final searchInput = find.byKey(const Key('my_decks_search_input'));

      // Single character 'z' matches Charizard
      await tester.enterText(searchInput, 'z');
      await tester.pumpAndSettle();
      expect(find.text('Charizard ex / Pidgeot ex'), findsOneWidget);

      // Single character 'e' matches multiple deck names
      await tester.enterText(searchInput, 'e');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('my_decks_search_header_name')), findsOneWidget);
      expect(find.text('Edgar Markov Aristocrats'), findsOneWidget);
      expect(find.text('Charizard ex / Pidgeot ex'), findsOneWidget);
    });

    testWidgets('2.6 Boundary search: Extremely long query string does not cause UI overflow',
        (tester) async {
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      final longQuery = 'A' * 180;
      await tester.enterText(find.byKey(const Key('my_decks_search_input')), longQuery);
      await tester.pumpAndSettle();

      expect(find.text('No decks found'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    // -------------------------------------------------------------------------
    // 3. Press-and-Hold Selection Mode & Lifecycle
    // -------------------------------------------------------------------------
    testWidgets('3.1 Selection mode entry: Long-press activates footer, shows checkboxes, hides FAB',
        (tester) async {
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      // Initially: FAB is visible, footer is not
      expect(find.byKey(const Key('decks_new_deck_fab')), findsOneWidget);
      expect(find.byKey(const Key('my_decks_selection_footer')), findsNothing);

      // Long press Edgar Markov
      await tester.longPress(find.byKey(const Key('deck_item_deck-edgar-markov')));
      await tester.pumpAndSettle();

      // Selection footer is visible with "1 selected"
      expect(find.byKey(const Key('my_decks_selection_footer')), findsOneWidget);
      expect(find.text('1 selected'), findsOneWidget);

      // Checkbox is displayed
      final checkboxFinder = find.byKey(const Key('deck_checkbox_deck-edgar-markov'));
      expect(checkboxFinder, findsOneWidget);
      final checkbox = tester.widget<Checkbox>(checkboxFinder);
      expect(checkbox.value, isTrue);

      // FAB is hidden while in selection mode
      expect(find.byKey(const Key('decks_new_deck_fab')), findsNothing);
    });

    testWidgets('3.2 Selection mode toggling: Tapping decks in selection mode toggles state without navigating',
        (tester) async {
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      // Enter selection mode
      await tester.longPress(find.byKey(const Key('deck_item_deck-edgar-markov')));
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsOneWidget);

      // Tap second deck (Charizard)
      await tester.tap(find.byKey(const Key('deck_item_deck-charizard-ex')));
      await tester.pumpAndSettle();
      expect(find.text('2 selected'), findsOneWidget);

      // Tap third deck (Yuriko)
      await tester.tap(find.byKey(const Key('deck_item_deck-yuriko')));
      await tester.pumpAndSettle();
      expect(find.text('3 selected'), findsOneWidget);

      // Tap Charizard again to deselect
      await tester.tap(find.byKey(const Key('deck_item_deck-charizard-ex')));
      await tester.pumpAndSettle();
      expect(find.text('2 selected'), findsOneWidget);

      // Tap Edgar Markov to deselect
      await tester.tap(find.byKey(const Key('deck_item_deck-edgar-markov')));
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsOneWidget);
    });

    testWidgets('3.3 Selection mode exit: Tapping cancel button clears selection and restores FAB',
        (tester) async {
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      await tester.longPress(find.byKey(const Key('deck_item_deck-edgar-markov')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('my_decks_selection_footer')), findsOneWidget);
      expect(find.byKey(const Key('decks_new_deck_fab')), findsNothing);

      // Tap cancel button in footer
      await tester.tap(find.byKey(const Key('selection_cancel_button')));
      await tester.pumpAndSettle();

      // Footer is dismissed, checkboxes gone, FAB returns
      expect(find.byKey(const Key('my_decks_selection_footer')), findsNothing);
      expect(find.byKey(const Key('deck_checkbox_deck-edgar-markov')), findsNothing);
      expect(find.byKey(const Key('decks_new_deck_fab')), findsOneWidget);
    });

    testWidgets('3.4 Selection mode exit: Deselecting all decks to 0 automatically dismisses selection footer',
        (tester) async {
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      await tester.longPress(find.byKey(const Key('deck_item_deck-edgar-markov')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('my_decks_selection_footer')), findsOneWidget);

      // Tap the only selected deck to uncheck it
      await tester.tap(find.byKey(const Key('deck_item_deck-edgar-markov')));
      await tester.pumpAndSettle();

      // Footer automatically dismisses and FAB returns
      expect(find.byKey(const Key('my_decks_selection_footer')), findsNothing);
      expect(find.byKey(const Key('decks_new_deck_fab')), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // 4. Single-Deck Rule Invariant for Footer Sharing
    // -------------------------------------------------------------------------
    testWidgets('4.1 Single-deck rule invariant: Share button strictly enabled at count==1, disabled at count>1',
        (tester) async {
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      final shareBtnFinder = find.byKey(const Key('selection_share_to_explore_button'));

      // 1 Selected -> ENABLED
      await tester.longPress(find.byKey(const Key('deck_item_deck-edgar-markov')));
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsOneWidget);
      var shareBtn = tester.widget<ElevatedButton>(shareBtnFinder);
      expect(shareBtn.onPressed, isNotNull, reason: 'Share button must be ENABLED when exactly 1 deck selected');

      // 2 Selected -> DISABLED
      await tester.tap(find.byKey(const Key('deck_item_deck-charizard-ex')));
      await tester.pumpAndSettle();
      expect(find.text('2 selected'), findsOneWidget);
      shareBtn = tester.widget<ElevatedButton>(shareBtnFinder);
      expect(shareBtn.onPressed, isNull, reason: 'Share button must be DISABLED when 2 decks selected');

      // 3 Selected -> DISABLED
      await tester.tap(find.byKey(const Key('deck_item_deck-yuriko')));
      await tester.pumpAndSettle();
      expect(find.text('3 selected'), findsOneWidget);
      shareBtn = tester.widget<ElevatedButton>(shareBtnFinder);
      expect(shareBtn.onPressed, isNull, reason: 'Share button must be DISABLED when 3 decks selected');

      // Deselect down to 2 -> DISABLED
      await tester.tap(find.byKey(const Key('deck_item_deck-yuriko')));
      await tester.pumpAndSettle();
      expect(find.text('2 selected'), findsOneWidget);
      shareBtn = tester.widget<ElevatedButton>(shareBtnFinder);
      expect(shareBtn.onPressed, isNull, reason: 'Share button must be DISABLED when 2 decks selected');

      // Deselect down to 1 -> RE-ENABLED
      await tester.tap(find.byKey(const Key('deck_item_deck-charizard-ex')));
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsOneWidget);
      shareBtn = tester.widget<ElevatedButton>(shareBtnFinder);
      expect(shareBtn.onPressed, isNotNull, reason: 'Share button must RE-ENABLE when reduced back to 1 selected');
    });

    testWidgets('4.2 Footer share execution: Exports selected deck to SQLite explore tables and resets selection',
        (tester) async {
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      await tester.longPress(find.byKey(const Key('deck_item_deck-charizard-ex')));
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsOneWidget);

      // Tap "Share to Explore"
      await tester.tap(find.byKey(const Key('selection_share_to_explore_button')));
      await tester.pumpAndSettle();

      // Confirmation SnackBar appears
      expect(find.text('Deck "Charizard ex / Pidgeot ex" shared to Explore!'), findsOneWidget);

      // Selection mode automatically exits
      expect(find.byKey(const Key('my_decks_selection_footer')), findsNothing);
      expect(find.byKey(const Key('decks_new_deck_fab')), findsOneWidget);

      // Verify deck is persisted in Explore SQLite database
      final exploreDecks = await exploreDao.watchExploreDecks().first;
      expect(exploreDecks.any((d) => d.id == 'explore_shared_deck-charizard-ex'), isTrue);
    });

    // -------------------------------------------------------------------------
    // 5. 3-Dot Overflow Menu Sharing & SQLite Export
    // -------------------------------------------------------------------------
    testWidgets('5.1 3-Dot overflow menu: Share mock deck exports to SQLite explore_decks with user_shared type',
        (tester) async {
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      // Open menu on Yuriko deck
      final menuFinder = find.byKey(const Key('deck_card_menu_deck-yuriko'));
      expect(menuFinder, findsOneWidget);
      await tester.tap(menuFinder);
      await tester.pumpAndSettle();

      // Tap "Share to Explore"
      final shareItem = find.byKey(const Key('deck_menu_share_explore_deck-yuriko'));
      expect(shareItem, findsOneWidget);
      await tester.tap(shareItem);
      await tester.pumpAndSettle();

      // Feedback SnackBar appears
      expect(find.text('Deck "Yuriko, the Tiger\'s Shadow" shared to Explore!'), findsOneWidget);

      // SQLite check
      final sharedDecks = await exploreDao.watchExploreDecks().first;
      final yurikoShared = sharedDecks.firstWhere((d) => d.id == 'explore_shared_deck-yuriko');
      expect(yurikoShared.deck.sourceType, 'user_shared');
      expect(yurikoShared.deck.name, "Yuriko, the Tiger's Shadow");
    });

    testWidgets('5.2 3-Dot overflow menu: Share SQLite-persisted custom deck exports cards to explore_deck_items',
        (tester) async {
      // Create and persist a custom deck with cards in SQLite
      await db.into(db.decks).insert(
        DecksCompanion.insert(
          id: 'deck-db-reanimator',
          name: 'Dimir Reanimator DB',
          format: 'Legacy',
          tcgDomain: const Value('mtg'),
          createdAt: DateTime.now(),
        ),
      );
      await db.into(db.deckVersions).insert(
        DeckVersionsCompanion.insert(
          id: 'ver-reanimator-1',
          deckId: 'deck-db-reanimator',
          versionNumber: 1,
          isActive: const Value(true),
          createdAt: DateTime.now(),
        ),
      );
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-griselbrand-1',
          collectionType: 'mtg',
          name: 'Griselbrand',
          setOrSeries: 'AVR',
          imageUrl: 'https://example.com/griselbrand.jpg',
          acquiredPrice: 15.0,
          acquiredDate: DateTime.now(),
          quantity: const Value(4),
          condition: 'NM',
          currentMarketPrice: 20.0,
          lastPriceUpdate: DateTime.now(),
          dynamicData: '{"name":"Griselbrand"}',
        ),
      );
      await db.into(db.deckVersionItems).insert(
        DeckVersionItemsCompanion.insert(
          id: 'dvi-griselbrand-1',
          versionId: 'ver-reanimator-1',
          vaultItemId: 'card-griselbrand-1',
          boardZone: 'Mainboard',
          quantity: const Value(4),
        ),
      );

      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      // Share custom deck via 3-dot overflow menu
      await tester.tap(find.byKey(const Key('deck_card_menu_deck-db-reanimator')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('deck_menu_share_explore_deck-db-reanimator')));
      await tester.pumpAndSettle();

      expect(find.text('Deck "Dimir Reanimator DB" shared to Explore!'), findsOneWidget);

      // Verify deck items in SQLite explore_deck_items
      final exploreCards = await exploreDao.getExploreDeckItems('explore_shared_deck-db-reanimator');
      expect(exploreCards.isNotEmpty, isTrue);
      expect(exploreCards.any((c) => c.cardName == 'Griselbrand' && c.quantity == 4), isTrue);
    });

    // -------------------------------------------------------------------------
    // 6. Adversarial Interplay: Selection Mode within Search & Cross-Filter
    // -------------------------------------------------------------------------
    testWidgets('6.1 Interplay: Selection mode operates seamlessly inside search results view',
        (tester) async {
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      // Enter search query
      await tester.enterText(find.byKey(const Key('my_decks_search_input')), 'Tron');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('my_decks_search_header_name')), findsOneWidget);
      expect(find.byKey(const Key('my_decks_search_header_cards')), findsOneWidget);

      // Long-press Tron search result
      await tester.longPress(find.byKey(const Key('deck_item_deck-tron')));
      await tester.pumpAndSettle();

      // Selection footer appears inside search view
      expect(find.byKey(const Key('my_decks_selection_footer')), findsOneWidget);
      expect(find.text('1 selected'), findsOneWidget);

      // Tap Edgar Markov search result
      await tester.tap(find.byKey(const Key('deck_item_deck-edgar-markov')));
      await tester.pumpAndSettle();
      expect(find.text('2 selected'), findsOneWidget);

      // Share button disabled at count == 2
      final shareBtn = tester.widget<ElevatedButton>(
        find.byKey(const Key('selection_share_to_explore_button')),
      );
      expect(shareBtn.onPressed, isNull);

      // Tap cancel exits selection mode while PRESERVING search results
      await tester.tap(find.byKey(const Key('selection_cancel_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('my_decks_selection_footer')), findsNothing);
      expect(find.byKey(const Key('my_decks_search_header_name')), findsOneWidget);
      expect(find.byKey(const Key('my_decks_search_header_cards')), findsOneWidget);
    });

    testWidgets('6.2 Interplay: TCG domain context filters personal search results',
        (tester) async {
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      // Switch TCG domain filter to Pokémon
      await tester.tap(find.byKey(const Key('decks_tcg_context_switcher')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tcg_filter_pokemon')));
      await tester.pumpAndSettle();

      // Search for MTG deck "Mono-Green" -> No Pokémon decks match
      await tester.enterText(find.byKey(const Key('my_decks_search_input')), 'Mono-Green');
      await tester.pumpAndSettle();
      expect(find.text('No decks found'), findsOneWidget);

      // Search for Pokémon deck "Charizard" -> Matches Charizard
      await tester.enterText(find.byKey(const Key('my_decks_search_input')), 'Charizard');
      await tester.pumpAndSettle();
      expect(find.text('Charizard ex / Pidgeot ex'), findsOneWidget);

      // Clear search button restores Pokémon deck list
      await tester.tap(find.byKey(const Key('my_decks_search_clear_button')));
      await tester.pumpAndSettle();
      expect(find.text('Charizard ex / Pidgeot ex'), findsOneWidget);
      expect(find.text('Lost Zone Giratina VSTAR'), findsOneWidget);
      expect(find.text('Edgar Markov Aristocrats'), findsNothing);
    });

    testWidgets('6.3 Empirical challenge finding: MockDeckData defaults unmapped decks (e.g. Lost Zone Giratina) to Edgar Markov MTG cards',
        (tester) async {
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      // Switch to Pokémon domain
      await tester.tap(find.byKey(const Key('decks_tcg_context_switcher')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tcg_filter_pokemon')));
      await tester.pumpAndSettle();

      // Search for "Sol Ring" (a Magic card in Edgar Markov items)
      await tester.enterText(find.byKey(const Key('my_decks_search_input')), 'Sol Ring');
      await tester.pumpAndSettle();

      // EMPIRICAL OBSERVATION: Lost Zone Giratina VSTAR (a Pokémon deck) is returned
      // because MockDeckData.getDeckItems('deck-lost-zone') falls back to _edgarMarkovItems!
      expect(find.text('Lost Zone Giratina VSTAR'), findsOneWidget);
      expect(find.byKey(const Key('deck_card_match_chip_deck-lost-zone')), findsOneWidget);
      expect(find.text('Contains: Sol Ring (x1)'), findsOneWidget);
    });
  });
}
