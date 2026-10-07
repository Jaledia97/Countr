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

  group('Milestone 2: My Decks Search, Badges & Sharing Tests', () {
    testWidgets('1. Assembly status badges render correct styling and icons for Draft, Ready, Assembled',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Insert custom ready (60/60) and draft (20/60) decks
      final now = DateTime.now();
      final readySummary = DeckSummary(
        id: 'deck-test-ready',
        name: 'Simic Ramp Ready',
        format: 'Standard',
        tcgDomain: 'mtg',
        isRegistered: false,
        isCompetitive: false,
        createdAt: now,
        cardCount: 60,
        targetCardCount: 60,
        completeness: 1.0,
        assemblyStatus: 'Ready',
        deck: Deck(
          id: 'deck-test-ready',
          name: 'Simic Ramp Ready',
          format: 'Standard',
          tcgDomain: 'mtg',
          isRegistered: false,
          isAssembled: false,
          isCompetitive: false,
          createdAt: now,
          wins: 0,
          losses: 0,
          draws: 0,
          isCloned: false,
          isDeleted: false,
        ),
      );

      final draftSummary = DeckSummary(
        id: 'deck-test-draft',
        name: 'Simic Ramp Draft',
        format: 'Standard',
        tcgDomain: 'mtg',
        isRegistered: false,
        isCompetitive: false,
        createdAt: now,
        cardCount: 20,
        targetCardCount: 60,
        completeness: 20 / 60,
        assemblyStatus: 'Draft',
        deck: Deck(
          id: 'deck-test-draft',
          name: 'Simic Ramp Draft',
          format: 'Standard',
          tcgDomain: 'mtg',
          isRegistered: false,
          isAssembled: false,
          isCompetitive: false,
          createdAt: now,
          wins: 0,
          losses: 0,
          draws: 0,
          isCloned: false,
          isDeleted: false,
        ),
      );

      await tester.pumpWidget(createSubject(initialSummaries: [readySummary, draftSummary]));
      await tester.pumpAndSettle();

      // Edgar Markov is registered -> "Assembled"
      final assembledPill = find.byKey(const Key('deck_assembly_status_deck-edgar-markov'));
      expect(assembledPill, findsOneWidget);
      expect(find.descendant(of: assembledPill, matching: find.text('Assembled')), findsOneWidget);
      expect(find.descendant(of: assembledPill, matching: find.byIcon(Icons.verified_rounded)), findsOneWidget);

      // Ready deck -> "Ready"
      final readyPill = find.byKey(const Key('deck_assembly_status_deck-test-ready'));
      expect(readyPill, findsOneWidget);
      expect(find.descendant(of: readyPill, matching: find.text('Ready')), findsOneWidget);
      expect(find.descendant(of: readyPill, matching: find.byIcon(Icons.check_circle_outline_rounded)), findsOneWidget);

      // Draft deck -> "Draft"
      final draftPill = find.byKey(const Key('deck_assembly_status_deck-test-draft'));
      expect(draftPill, findsOneWidget);
      expect(find.descendant(of: draftPill, matching: find.text('Draft')), findsOneWidget);
      expect(find.descendant(of: draftPill, matching: find.byIcon(Icons.edit_note_rounded)), findsOneWidget);
    });

    testWidgets('2. Multi-tier personal search: Query by Deck Name renders under "in Deck Name"',
        (tester) async {
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      // Search for "Mono-Green" (only matches "Modern Mono-Green Tron" title, not contained in any card names)
      await tester.enterText(find.byKey(const Key('my_decks_search_input')), 'Mono-Green');
      await tester.pumpAndSettle();

      // Should show "in Deck Name" header
      expect(find.byKey(const Key('my_decks_search_header_name')), findsOneWidget);
      expect(find.text('Modern Mono-Green Tron'), findsOneWidget);

      // Should not show "contains Card" if no card matches
      expect(find.byKey(const Key('my_decks_search_header_cards')), findsNothing);
    });

    testWidgets('3. Multi-tier personal search: Query by Contained Card renders under "contains Card" with chip',
        (tester) async {
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      // Edgar Markov deck contains "Sol Ring" (x1). Deck name is "Edgar Markov Aristocrats" (no "Sol Ring" in title).
      await tester.enterText(find.byKey(const Key('my_decks_search_input')), 'Sol Ring');
      await tester.pumpAndSettle();

      // Header "contains Card" should be rendered
      expect(find.byKey(const Key('my_decks_search_header_cards')), findsOneWidget);
      expect(find.text('Edgar Markov Aristocrats'), findsOneWidget);

      // Matched card chip indicator should show card name and quantity
      final chipFinder = find.byKey(const Key('deck_card_match_chip_deck-edgar-markov'));
      expect(chipFinder, findsOneWidget);
      expect(
        find.descendant(of: chipFinder, matching: find.text('Contains: Sol Ring (x1)')),
        findsOneWidget,
      );

      // Header "in Deck Name" should not appear for Sol Ring
      expect(find.byKey(const Key('my_decks_search_header_name')), findsNothing);
    });

    testWidgets('4. Visual line-break divider separates "in Deck Name" and "contains Card" matches',
        (tester) async {
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      // "Tron" matches "Modern Mono-Green Tron" in deck name, and matches "Patron of the Vein" in Edgar Markov cards
      await tester.enterText(find.byKey(const Key('my_decks_search_input')), 'Tron');
      await tester.pumpAndSettle();

      // Both headers and the dividing line break must appear simultaneously
      expect(find.byKey(const Key('my_decks_search_header_name')), findsOneWidget);
      expect(find.byKey(const Key('my_decks_search_header_cards')), findsOneWidget);
      expect(find.byType(Divider), findsOneWidget);

      // Clear search restores all decks
      await tester.tap(find.byKey(const Key('my_decks_search_clear_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('deck_item_deck-edgar-markov')), findsOneWidget);
      expect(find.byKey(const Key('deck_item_deck-charizard-ex')), findsOneWidget);
    });

    testWidgets('5. 3-dot overflow menu: "Share to Explore" triggers DAO share and displays SnackBar',
        (tester) async {
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      final menuFinder = find.byKey(const Key('deck_card_menu_deck-edgar-markov'));
      expect(menuFinder, findsOneWidget);

      // Open menu
      await tester.tap(menuFinder);
      await tester.pumpAndSettle();

      // Find and tap "Share to Explore"
      final shareItemFinder = find.byKey(const Key('deck_menu_share_explore_deck-edgar-markov'));
      expect(shareItemFinder, findsOneWidget);
      await tester.tap(shareItemFinder);
      await tester.pumpAndSettle();

      // SnackBar feedback is presented
      expect(find.text('Deck "Edgar Markov Aristocrats" shared to Explore!'), findsOneWidget);

      // Verify the deck is now stored in SQLite explore_decks
      final sharedDecks = await exploreDao.watchExploreDecks().first;
      expect(sharedDecks.any((d) => d.id == 'explore_shared_deck-edgar-markov'), isTrue);
    });

    testWidgets('6. Press-and-hold selection mode: long-press opens footer, enables Share strictly on 1 deck',
        (tester) async {
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      // Footer is not visible initially
      expect(find.byKey(const Key('my_decks_selection_footer')), findsNothing);

      // Long-press Edgar Markov card
      await tester.longPress(find.byKey(const Key('deck_item_deck-edgar-markov')));
      await tester.pumpAndSettle();

      // Selection footer appears with "1 selected"
      expect(find.byKey(const Key('my_decks_selection_footer')), findsOneWidget);
      expect(find.text('1 selected'), findsOneWidget);

      // "Share to Explore" button is ENABLED
      final shareBtn1 = tester.widget<ElevatedButton>(
        find.byKey(const Key('selection_share_to_explore_button')),
      );
      expect(shareBtn1.onPressed, isNotNull);

      // Tap Charizard card to select a 2nd deck
      await tester.tap(find.byKey(const Key('deck_item_deck-charizard-ex')));
      await tester.pumpAndSettle();

      // Footer now shows "2 selected"
      expect(find.text('2 selected'), findsOneWidget);

      // "Share to Explore" button is now DISABLED (count > 1)
      final shareBtn2 = tester.widget<ElevatedButton>(
        find.byKey(const Key('selection_share_to_explore_button')),
      );
      expect(shareBtn2.onPressed, isNull);

      // Tap Charizard card again to deselect
      await tester.tap(find.byKey(const Key('deck_item_deck-charizard-ex')));
      await tester.pumpAndSettle();

      // Back to 1 selected -> Share button re-enabled
      expect(find.text('1 selected'), findsOneWidget);
      final shareBtn3 = tester.widget<ElevatedButton>(
        find.byKey(const Key('selection_share_to_explore_button')),
      );
      expect(shareBtn3.onPressed, isNotNull);

      // Tapping "Share to Explore" in footer shares the deck and exits selection mode
      await tester.tap(find.byKey(const Key('selection_share_to_explore_button')));
      await tester.pumpAndSettle();

      expect(find.text('Deck "Edgar Markov Aristocrats" shared to Explore!'), findsOneWidget);
      expect(find.byKey(const Key('my_decks_selection_footer')), findsNothing);
    });

    testWidgets('7. Cancel button exits selection mode and restores standard navigation',
        (tester) async {
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      // Long-press to enter selection mode
      await tester.longPress(find.byKey(const Key('deck_item_deck-edgar-markov')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('my_decks_selection_footer')), findsOneWidget);

      // Tap cancel button
      await tester.tap(find.byKey(const Key('selection_cancel_button')));
      await tester.pumpAndSettle();

      // Footer is dismissed
      expect(find.byKey(const Key('my_decks_selection_footer')), findsNothing);
    });
  });
}
