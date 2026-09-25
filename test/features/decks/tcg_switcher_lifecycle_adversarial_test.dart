import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/features/decks/presentation/screens/decks_screen.dart';
import 'package:countr/features/decks/presentation/screens/deck_builder_screen.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';

void main() {
  Widget buildDecksScreenHarness({
    String initialFilter = 'all',
    List<Override> additionalOverrides = const [],
  }) {
    return ProviderScope(
      overrides: [
        activeDeckTcgFilterProvider.overrideWith((ref) => initialFilter),
        ...additionalOverrides,
      ],
      child: const MaterialApp(
        home: DecksScreen(),
      ),
    );
  }

  Future<void> cleanDriftStreamDisposal(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('Adversarial Category A: Typed Deck Model Integrity & Navigation Under FAB Creation', () {
    testWidgets('A1. MTG domain FAB creation: verifies typed Deck model integrity and safe DeckBuilderScreen navigation', (tester) async {
      await tester.pumpWidget(buildDecksScreenHarness(initialFilter: 'mtg'));
      await tester.pumpAndSettle();

      expect(find.text('All Decks (3)'), findsOneWidget);

      // Tap FAB to create new MTG deck
      final fab = find.byKey(const Key('decks_new_deck_fab'));
      await tester.tap(fab);
      await tester.pumpAndSettle();

      expect(find.text('All Decks (4)'), findsOneWidget);

      final newDeckFinder = find.textContaining('MTG Commander • 0/100');
      expect(newDeckFinder, findsOneWidget);

      // Tap new deck item
      await tester.tap(newDeckFinder);
      await tester.pumpAndSettle();

      // Verify DeckBuilderScreen is mounted
      expect(find.byType(DeckBuilderScreen), findsOneWidget);
      final builder = tester.widget<DeckBuilderScreen>(find.byType(DeckBuilderScreen));
      final deck = builder.deck;

      // Exhaustive field assertion
      expect(deck.id, isNotEmpty);
      expect(deck.id.startsWith('deck-'), isTrue);
      expect(deck.name, startsWith('New MTG Commander Brew'));
      expect(deck.format, equals('MTG Commander'));
      expect(deck.tcgDomain, equals('mtg'));
      expect(deck.isRegistered, isFalse);
      expect(deck.isCompetitive, isFalse);
      expect(deck.wins, equals(0));
      expect(deck.losses, equals(0));
      expect(deck.draws, equals(0));
      expect(deck.createdAt, isNotNull);

      // Verify no runtime exceptions
      expect(tester.takeException(), isNull);

      // Pop DeckBuilderScreen back to DecksScreen
      Navigator.pop(tester.element(find.byType(DeckBuilderScreen)));
      await tester.pumpAndSettle();

      expect(find.byType(DeckBuilderScreen), findsNothing);
      expect(find.byType(DecksScreen), findsOneWidget);

      await cleanDriftStreamDisposal(tester);
    });

    testWidgets('A2. Pokémon domain FAB creation: verifies typed Deck model with Pokémon ruleset and safe navigation', (tester) async {
      await tester.pumpWidget(buildDecksScreenHarness(initialFilter: 'pokemon'));
      await tester.pumpAndSettle();

      expect(find.text('All Decks (2)'), findsOneWidget);

      final fab = find.byKey(const Key('decks_new_deck_fab'));
      await tester.tap(fab);
      await tester.pumpAndSettle();

      expect(find.text('All Decks (3)'), findsOneWidget);

      final newDeckFinder = find.textContaining('Pokémon Standard • 0/60');
      expect(newDeckFinder, findsOneWidget);

      await tester.tap(newDeckFinder);
      await tester.pumpAndSettle();

      expect(find.byType(DeckBuilderScreen), findsOneWidget);
      final builder = tester.widget<DeckBuilderScreen>(find.byType(DeckBuilderScreen));
      final deck = builder.deck;

      expect(deck.id, isNotEmpty);
      expect(deck.name, startsWith('New Pokémon Standard Brew'));
      expect(deck.format, equals('Pokémon Standard'));
      expect(deck.tcgDomain, equals('pokemon'));
      expect(deck.isRegistered, isFalse);
      expect(deck.isCompetitive, isFalse);
      expect(deck.wins, equals(0));
      expect(deck.losses, equals(0));
      expect(deck.draws, equals(0));
      expect(deck.createdAt, isNotNull);

      expect(tester.takeException(), isNull);

      Navigator.pop(tester.element(find.byType(DeckBuilderScreen)));
      await tester.pumpAndSettle();

      expect(find.byType(DeckBuilderScreen), findsNothing);
      expect(find.byType(DecksScreen), findsOneWidget);

      await cleanDriftStreamDisposal(tester);
    });

    testWidgets('A3. Disney Lorcana domain FAB creation: verifies typed Deck model with Lorcana ruleset and safe navigation', (tester) async {
      await tester.pumpWidget(buildDecksScreenHarness(initialFilter: 'lorcana'));
      await tester.pumpAndSettle();

      expect(find.text('All Decks (1)'), findsOneWidget);

      final fab = find.byKey(const Key('decks_new_deck_fab'));
      await tester.tap(fab);
      await tester.pumpAndSettle();

      expect(find.text('All Decks (2)'), findsOneWidget);

      final newDeckFinder = find.textContaining('Disney Lorcana Core • 0/60');
      expect(newDeckFinder, findsOneWidget);

      await tester.tap(newDeckFinder);
      await tester.pumpAndSettle();

      expect(find.byType(DeckBuilderScreen), findsOneWidget);
      final builder = tester.widget<DeckBuilderScreen>(find.byType(DeckBuilderScreen));
      final deck = builder.deck;

      expect(deck.id, isNotEmpty);
      expect(deck.name, startsWith('New Disney Lorcana Core Brew'));
      expect(deck.format, equals('Disney Lorcana Core'));
      expect(deck.tcgDomain, equals('lorcana'));
      expect(deck.isRegistered, isFalse);
      expect(deck.isCompetitive, isFalse);
      expect(deck.wins, equals(0));
      expect(deck.losses, equals(0));
      expect(deck.draws, equals(0));
      expect(deck.createdAt, isNotNull);

      expect(tester.takeException(), isNull);

      Navigator.pop(tester.element(find.byType(DeckBuilderScreen)));
      await tester.pumpAndSettle();

      expect(find.byType(DeckBuilderScreen), findsNothing);
      expect(find.byType(DecksScreen), findsOneWidget);

      await cleanDriftStreamDisposal(tester);
    });

    testWidgets('A4. Default "all" domain FAB creation: verifies MTG Commander defaults and model integrity', (tester) async {
      await tester.pumpWidget(buildDecksScreenHarness(initialFilter: 'all'));
      await tester.pumpAndSettle();

      expect(find.text('All Decks (6)'), findsOneWidget);

      final fab = find.byKey(const Key('decks_new_deck_fab'));
      await tester.tap(fab);
      await tester.pumpAndSettle();

      expect(find.text('All Decks (7)'), findsOneWidget);

      final newDeckFinder = find.textContaining('MTG Commander • 0/100');
      expect(newDeckFinder, findsOneWidget);

      await tester.tap(newDeckFinder);
      await tester.pumpAndSettle();

      expect(find.byType(DeckBuilderScreen), findsOneWidget);
      final builder = tester.widget<DeckBuilderScreen>(find.byType(DeckBuilderScreen));
      expect(builder.deck.tcgDomain, equals('mtg'));
      expect(builder.deck.format, equals('MTG Commander'));
      expect(builder.deck.isRegistered, isFalse);
      expect(builder.deck.isCompetitive, isFalse);

      expect(tester.takeException(), isNull);

      Navigator.pop(tester.element(find.byType(DeckBuilderScreen)));
      await tester.pumpAndSettle();

      await cleanDriftStreamDisposal(tester);
    });

    testWidgets('A5. Pre-populated mock decks navigation: passes domain, status, and competitive flags accurately', (tester) async {
      await tester.pumpWidget(buildDecksScreenHarness(initialFilter: 'all'));
      await tester.pumpAndSettle();

      // 1. Edgar Markov (MTG, registered, casual)
      await tester.tap(find.text('Edgar Markov Aristocrats'));
      await tester.pumpAndSettle();
      var builder = tester.widget<DeckBuilderScreen>(find.byType(DeckBuilderScreen));
      expect(builder.deck.tcgDomain, equals('mtg'));
      expect(builder.deck.isRegistered, isTrue);
      expect(builder.deck.isCompetitive, isFalse);
      Navigator.pop(tester.element(find.byType(DeckBuilderScreen)));
      await tester.pumpAndSettle();

      // 2. Charizard ex (Pokemon, registered, competitive)
      await tester.tap(find.text('Charizard ex / Pidgeot ex'));
      await tester.pumpAndSettle();
      builder = tester.widget<DeckBuilderScreen>(find.byType(DeckBuilderScreen));
      expect(builder.deck.tcgDomain, equals('pokemon'));
      expect(builder.deck.isRegistered, isTrue);
      expect(builder.deck.isCompetitive, isTrue);
      Navigator.pop(tester.element(find.byType(DeckBuilderScreen)));
      await tester.pumpAndSettle();

      // 3. Yuriko (MTG, draft/unregistered, competitive)
      await tester.tap(find.text('Yuriko, the Tiger\'s Shadow'));
      await tester.pumpAndSettle();
      builder = tester.widget<DeckBuilderScreen>(find.byType(DeckBuilderScreen));
      expect(builder.deck.tcgDomain, equals('mtg'));
      expect(builder.deck.isRegistered, isFalse);
      expect(builder.deck.isCompetitive, isTrue);
      Navigator.pop(tester.element(find.byType(DeckBuilderScreen)));
      await tester.pumpAndSettle();

      // 4. Ruby / Amethyst (Lorcana, draft/unregistered, casual)
      await tester.tap(find.text('Ruby / Amethyst Bounce Control'));
      await tester.pumpAndSettle();
      builder = tester.widget<DeckBuilderScreen>(find.byType(DeckBuilderScreen));
      expect(builder.deck.tcgDomain, equals('lorcana'));
      expect(builder.deck.isRegistered, isFalse);
      expect(builder.deck.isCompetitive, isFalse);
      Navigator.pop(tester.element(find.byType(DeckBuilderScreen)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await cleanDriftStreamDisposal(tester);
    });
  });

  group('Adversarial Category B: Riverpod Provider Lifecycle, State Reset & Edge Cases', () {
    test('B1. ProviderContainer: activeDeckTcgFilterProvider resets to "all" on invalidate and refresh', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Default value is 'all'
      expect(container.read(activeDeckTcgFilterProvider), equals('all'));

      // Mutate state to 'pokemon'
      container.read(activeDeckTcgFilterProvider.notifier).state = 'pokemon';
      expect(container.read(activeDeckTcgFilterProvider), equals('pokemon'));

      // Invalidate provider and verify clean reset to default 'all'
      container.invalidate(activeDeckTcgFilterProvider);
      expect(container.read(activeDeckTcgFilterProvider), equals('all'));

      // Mutate to 'lorcana'
      container.read(activeDeckTcgFilterProvider.notifier).state = 'lorcana';
      expect(container.read(activeDeckTcgFilterProvider), equals('lorcana'));

      // Refresh provider and verify it returns 'all'
      final refreshed = container.refresh(activeDeckTcgFilterProvider);
      expect(refreshed, equals('all'));
      expect(container.read(activeDeckTcgFilterProvider), equals('all'));
    });

    testWidgets('B2. UI Reactivity on programmatic provider mutation & reset without setState', (tester) async {
      late WidgetRef capturedRef;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Column(
              children: [
                Consumer(
                  builder: (context, ref, child) {
                    capturedRef = ref;
                    return const SizedBox.shrink();
                  },
                ),
                const Expanded(child: DecksScreen()),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially 'All Decks' and count 6
      expect(find.text('All Decks (6)'), findsOneWidget);

      // External programmatic update to 'pokemon'
      capturedRef.read(activeDeckTcgFilterProvider.notifier).state = 'pokemon';
      await tester.pumpAndSettle();

      // Dropdown title and count update reactively
      expect(find.text('Pokémon'), findsOneWidget);
      expect(find.text('All Decks (2)'), findsOneWidget);

      // Invalidate provider back to 'all'
      capturedRef.invalidate(activeDeckTcgFilterProvider);
      await tester.pumpAndSettle();

      expect(find.text('All Decks (6)'), findsOneWidget);
      expect(find.text('All Decks'), findsWidgets);

      await cleanDriftStreamDisposal(tester);
    });

    testWidgets('B3. Adversarial unexpected / invalid domain filter values gracefully fallback', (tester) async {
      // Test invalid strings like 'yugioh', empty '', and uppercase 'POKEMON'
      final testCases = ['yugioh', '', 'POKEMON', 'random_domain_xyz'];

      for (final invalidDomain in testCases) {
        await tester.pumpWidget(buildDecksScreenHarness(initialFilter: invalidDomain));
        await tester.pumpAndSettle();

        // Dropdown title falls back to 'All Decks'
        expect(find.text('All Decks'), findsWidgets);

        // Deck list filters to 0 decks and renders empty state
        expect(find.text('No decks found'), findsOneWidget);
        expect(find.text('Tap "+ New Deck" to create one.'), findsOneWidget);

        // Tapping FAB falls back to MTG Commander default
        final fab = find.byKey(const Key('decks_new_deck_fab'));
        await tester.tap(fab);
        await tester.pumpAndSettle();

        // Verify SnackBar confirmation appeared without crash
        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.textContaining('Deck created! Total decks:'), findsOneWidget);

        expect(tester.takeException(), isNull);
        await cleanDriftStreamDisposal(tester);
      }
    });
  });

  group('Adversarial Category C: Multi-View Navigation Lifecycle & Memory / Drift Stream Cleanup', () {
    testWidgets('C1. Cross-domain push/pop stress cycle: 8 consecutive entries and exits across all filters', (tester) async {
      await tester.pumpWidget(buildDecksScreenHarness());
      await tester.pumpAndSettle();

      final domainsToTest = ['mtg', 'pokemon', 'lorcana', 'all'];

      // Perform 2 complete cycles (8 total push and pop transitions)
      for (int cycle = 0; cycle < 2; cycle++) {
        for (final domain in domainsToTest) {
          // Switch domain via dropdown
          await tester.tap(find.byKey(const Key('decks_tcg_context_switcher')));
          await tester.pumpAndSettle();

          await tester.tap(find.byKey(Key('tcg_filter_$domain')));
          await tester.pumpAndSettle();

          // Locate first available deck in list using deck_item_ key prefix
          final deckItem = find.byWidgetPredicate(
            (widget) =>
                widget is InkWell &&
                widget.key is ValueKey<String> &&
                (widget.key as ValueKey<String>).value.startsWith('deck_item_'),
          ).first;
          await tester.tap(deckItem);
          await tester.pumpAndSettle();

          // Verify DeckBuilderScreen is mounted
          expect(find.byType(DeckBuilderScreen), findsOneWidget);

          // Pop back to DecksScreen
          Navigator.pop(tester.element(find.byType(DeckBuilderScreen)));
          await tester.pumpAndSettle();

          // Verify DecksScreen restored
          expect(find.byType(DeckBuilderScreen), findsNothing);
          expect(find.byType(DecksScreen), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      }

      await cleanDriftStreamDisposal(tester);
    });

    testWidgets('C2. Rapid consecutive FAB deck creations followed by sequential deep entry and exit', (tester) async {
      await tester.pumpWidget(buildDecksScreenHarness(initialFilter: 'pokemon'));
      await tester.pumpAndSettle();

      expect(find.text('All Decks (2)'), findsOneWidget);

      final fab = find.byKey(const Key('decks_new_deck_fab'));

      // Rapidly tap FAB 4 times
      for (int i = 0; i < 4; i++) {
        await tester.tap(fab);
        await tester.pumpAndSettle();
      }

      // Count is now 2 + 4 = 6
      expect(find.text('All Decks (6)'), findsOneWidget);

      // Verify and tap into the 4 newly created decks sequentially
      for (int i = 0; i < 3; i++) {
        final newDeckTiles = find.textContaining('Pokémon Standard • 0/60');
        expect(newDeckTiles, findsWidgets);

        await tester.tap(newDeckTiles.at(i));
        await tester.pumpAndSettle();

        expect(find.byType(DeckBuilderScreen), findsOneWidget);
        final screen = tester.widget<DeckBuilderScreen>(find.byType(DeckBuilderScreen));
        expect(screen.deck.tcgDomain, equals('pokemon'));
        expect(screen.deck.format, equals('Pokémon Standard'));

        Navigator.pop(tester.element(find.byType(DeckBuilderScreen)));
        await tester.pumpAndSettle();
        expect(find.byType(DecksScreen), findsOneWidget);
      }

      expect(tester.takeException(), isNull);
      await cleanDriftStreamDisposal(tester);
    });

    testWidgets('C3. Filter switching while subheader tab is active (Competitive / Draft) handles zero-match states', (tester) async {
      await tester.pumpWidget(buildDecksScreenHarness(initialFilter: 'all'));
      await tester.pumpAndSettle();

      // Switch to Draft tab (index 2)
      await tester.tap(find.byKey(const Key('decks_tab_draft')));
      await tester.pumpAndSettle();

      // In All Decks, drafts exist (Yuriko, Ruby/Amethyst, Tron)
      expect(find.text('Yuriko, the Tiger\'s Shadow'), findsOneWidget);

      // Switch dropdown to Pokemon (where both mock decks are registered, 0 drafts)
      await tester.tap(find.byKey(const Key('decks_tcg_context_switcher')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tcg_filter_pokemon')));
      await tester.pumpAndSettle();

      // Empty state renders cleanly
      expect(find.text('No decks found'), findsOneWidget);
      expect(find.text('Tap "+ New Deck" to create one.'), findsOneWidget);

      // Create new draft deck via FAB while in Draft tab
      final fab = find.byKey(const Key('decks_new_deck_fab'));
      await tester.tap(fab);
      await tester.pumpAndSettle();

      // The new draft deck (isRegistered: false) immediately appears in Draft tab!
      expect(find.textContaining('Pokémon Standard • 0/60'), findsOneWidget);

      // Tap newly created draft deck and verify navigation
      await tester.tap(find.textContaining('Pokémon Standard • 0/60'));
      await tester.pumpAndSettle();

      expect(find.byType(DeckBuilderScreen), findsOneWidget);
      final builder = tester.widget<DeckBuilderScreen>(find.byType(DeckBuilderScreen));
      expect(builder.deck.isRegistered, isFalse);
      expect(builder.deck.tcgDomain, equals('pokemon'));

      Navigator.pop(tester.element(find.byType(DeckBuilderScreen)));
      await tester.pumpAndSettle();

      expect(find.byType(DecksScreen), findsOneWidget);
      expect(tester.takeException(), isNull);

      await cleanDriftStreamDisposal(tester);
    });

    testWidgets('C4. Abrupt unmount during active DeckBuilderScreen stream disposal', (tester) async {
      await tester.pumpWidget(buildDecksScreenHarness(initialFilter: 'mtg'));
      await tester.pumpAndSettle();

      // Tap deck to push DeckBuilderScreen
      await tester.tap(find.text('Edgar Markov Aristocrats'));
      await tester.pumpAndSettle();

      expect(find.byType(DeckBuilderScreen), findsOneWidget);

      // Abruptly unmount the entire tree without popping
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));

      // Invariant: zero unhandled exceptions or dangling controllers
      expect(tester.takeException(), isNull);
    });
  });
}
