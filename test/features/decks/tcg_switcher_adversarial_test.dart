import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/features/decks/presentation/screens/decks_screen.dart';
import 'package:countr/features/decks/presentation/screens/deck_builder_screen.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestWidget({
    Size size = const Size(390, 844),
    double textScale = 1.0,
    String initialFilter = 'all',
  }) {
    return ProviderScope(
      overrides: [
        activeDeckTcgFilterProvider.overrideWith((ref) => initialFilter),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: const DecksScreen(),
        ),
      ),
    );
  }

  group('Adversarial TCG Switcher & Layout Stress Suite', () {
    // =========================================================================
    // 1. Extreme Layout Constraints (300px and 320px + 2.0x Text Scale)
    // =========================================================================
    group('1. Extreme Layout Constraints (300px & 320px + 2.0x Text Scale)', () {
      testWidgets('1.1. DecksScreen under 300px viewport + 2.0x text scale renders with zero RenderFlex overflow', (tester) async {
        tester.view.physicalSize = const Size(300, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(buildTestWidget(
          size: const Size(300, 600),
          textScale: 2.0,
        ));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull, reason: 'RenderFlex overflow occurred on 300px viewport + 2.0x text scale');
        expect(find.byType(DecksScreen), findsOneWidget);
        expect(find.byKey(const Key('decks_tcg_context_switcher')), findsOneWidget);
        expect(find.byKey(const Key('decks_new_deck_fab')), findsOneWidget);

        // Subheader tabs should be horizontally scrollable without crashing
        expect(find.byKey(const Key('decks_tab_all')), findsOneWidget);
        expect(find.byKey(const Key('decks_tab_competitive')), findsOneWidget);
        expect(find.byKey(const Key('decks_tab_draft')), findsOneWidget);
      });

      testWidgets('1.2. DecksScreen under 320px viewport + 2.0x text scale renders with zero RenderFlex overflow', (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(buildTestWidget(
          size: const Size(320, 568),
          textScale: 2.0,
        ));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull, reason: 'RenderFlex overflow occurred on 320px viewport + 2.0x text scale');
        expect(find.byType(DecksScreen), findsOneWidget);
        expect(find.byKey(const Key('decks_tcg_context_switcher')), findsOneWidget);
        expect(find.byKey(const Key('decks_new_deck_fab')), findsOneWidget);
      });

      testWidgets('1.3. Popup menu under 300px viewport + 2.0x text scale opens without overflow', (tester) async {
        tester.view.physicalSize = const Size(300, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(buildTestWidget(
          size: const Size(300, 600),
          textScale: 2.0,
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('decks_tcg_context_switcher')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull, reason: 'Popup menu overflowed on 300px viewport');
        expect(find.byKey(const Key('tcg_filter_all')), findsOneWidget);
        expect(find.byKey(const Key('tcg_filter_mtg')), findsOneWidget);
        expect(find.byKey(const Key('tcg_filter_pokemon')), findsOneWidget);
        expect(find.byKey(const Key('tcg_filter_lorcana')), findsOneWidget);

        // Close menu
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
      });

      testWidgets('1.4. Popup menu under 320px viewport + 2.0x text scale opens without overflow', (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(buildTestWidget(
          size: const Size(320, 568),
          textScale: 2.0,
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('decks_tcg_context_switcher')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull, reason: 'Popup menu overflowed on 320px viewport');
        expect(find.byKey(const Key('tcg_filter_all')), findsOneWidget);
        expect(find.byKey(const Key('tcg_filter_mtg')), findsOneWidget);
        expect(find.byKey(const Key('tcg_filter_pokemon')), findsOneWidget);
        expect(find.byKey(const Key('tcg_filter_lorcana')), findsOneWidget);

        // Close menu
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
      });

      testWidgets('1.5. Empty state under constrained viewport (300x400) + 2.0x text scale does not overflow vertically', (tester) async {
        tester.view.physicalSize = const Size(300, 400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(buildTestWidget(
          size: const Size(300, 400),
          textScale: 2.0,
          initialFilter: 'lorcana',
        ));
        await tester.pumpAndSettle();

        // Switch to Competitive (Tab 1) -> 0 decks in Lorcana domain
        final compTabFinder = find.byKey(const Key('decks_tab_competitive'));
        await tester.ensureVisible(compTabFinder);
        await tester.pumpAndSettle();
        await tester.tap(compTabFinder);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull, reason: 'Empty state overflowed vertically under 300x400 + 2.0x text scale');
        expect(find.text('No decks found'), findsOneWidget);
        expect(find.text('Tap "+ New Deck" to create one.'), findsOneWidget);
      });
    });

    // =========================================================================
    // 2. Rapid Multi-Selection & Tab Switching Permutations
    // =========================================================================
    group('2. Rapid Multi-Selection Switching & Tab Permutations', () {
      testWidgets('2.1. Exhaustive 4 domains x 3 tabs (12 permutations) rapid switching behaves correctly', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        final domains = [
          {'id': 'all', 'name': 'All Decks', 'total': 6, 'comp': 3, 'draft': 3},
          {'id': 'mtg', 'name': 'Magic: The Gathering', 'total': 3, 'comp': 1, 'draft': 2},
          {'id': 'pokemon', 'name': 'Pokémon', 'total': 2, 'comp': 2, 'draft': 0},
          {'id': 'lorcana', 'name': 'Disney Lorcana', 'total': 1, 'comp': 0, 'draft': 1},
        ];

        for (final domain in domains) {
          final domainId = domain['id'] as String;
          final domainName = domain['name'] as String;
          final expectedTotal = domain['total'] as int;
          final expectedComp = domain['comp'] as int;
          final expectedDraft = domain['draft'] as int;

          // Open dropdown and select domain
          await tester.tap(find.byKey(const Key('decks_tcg_context_switcher')));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(Key('tcg_filter_$domainId')));
          await tester.pumpAndSettle();

          // Verify Dropdown title
          expect(find.text(domainName), findsOneWidget);
          // Verify Tab 0 count
          expect(find.text('All Decks ($expectedTotal)'), findsOneWidget);

          // Test Tab 0 (All)
          await tester.tap(find.byKey(const Key('decks_tab_all')));
          await tester.pumpAndSettle();
          if (expectedTotal == 0) {
            expect(find.text('No decks found'), findsOneWidget);
          } else {
            expect(find.byType(ListView), findsOneWidget);
          }

          // Test Tab 1 (Competitive)
          await tester.tap(find.byKey(const Key('decks_tab_competitive')));
          await tester.pumpAndSettle();
          if (expectedComp == 0) {
            expect(find.text('No decks found'), findsOneWidget);
          } else {
            expect(find.byType(ListView), findsOneWidget);
          }

          // Test Tab 2 (Draft)
          await tester.tap(find.byKey(const Key('decks_tab_draft')));
          await tester.pumpAndSettle();
          if (expectedDraft == 0) {
            expect(find.text('No decks found'), findsOneWidget);
          } else {
            expect(find.byType(ListView), findsOneWidget);
          }
        }
      });

      testWidgets('2.2. Reverse order domain hopping preserves checkmark and active filter state', (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        final hopSequence = ['lorcana', 'pokemon', 'mtg', 'all', 'pokemon', 'lorcana'];

        for (final targetDomain in hopSequence) {
          await tester.tap(find.byKey(const Key('decks_tcg_context_switcher')));
          await tester.pumpAndSettle();

          await tester.tap(find.byKey(Key('tcg_filter_$targetDomain')));
          await tester.pumpAndSettle();

          // Re-open menu to verify checkmark icon on active item
          await tester.tap(find.byKey(const Key('decks_tcg_context_switcher')));
          await tester.pumpAndSettle();

          expect(
            find.descendant(
              of: find.byKey(Key('tcg_filter_$targetDomain')),
              matching: find.byIcon(Icons.check_rounded),
            ),
            findsOneWidget,
            reason: 'Checkmark missing for active domain $targetDomain',
          );

          // Close popup menu
          await tester.tapAt(const Offset(10, 10));
          await tester.pumpAndSettle();
        }
      });
    });

    // =========================================================================
    // 3. Empty State Verification & Recovery
    // =========================================================================
    group('3. Empty State Stress & Domain Combinations', () {
      testWidgets('3.1. Lorcana + Competitive (Tab 1) renders empty state with correct messaging and icon', (tester) async {
        await tester.pumpWidget(buildTestWidget(initialFilter: 'lorcana'));
        await tester.pumpAndSettle();

        // Lorcana has 1 mock deck (Ruby / Amethyst Bounce Control), which has isCompetitive: false
        await tester.tap(find.byKey(const Key('decks_tab_competitive')));
        await tester.pumpAndSettle();

        expect(find.text('No decks found'), findsOneWidget);
        expect(find.text('Tap "+ New Deck" to create one.'), findsOneWidget);
        expect(find.byIcon(Icons.style_outlined), findsOneWidget);
        expect(find.text('Ruby / Amethyst Bounce Control'), findsNothing);
      });

      testWidgets('3.2. Pokémon + Draft / In-Progress (Tab 2) renders empty state', (tester) async {
        await tester.pumpWidget(buildTestWidget(initialFilter: 'pokemon'));
        await tester.pumpAndSettle();

        // Both Pokemon mock decks have isRegistered: true (Charizard and Lost Zone Giratina)
        await tester.tap(find.byKey(const Key('decks_tab_draft')));
        await tester.pumpAndSettle();

        expect(find.text('No decks found'), findsOneWidget);
        expect(find.text('Tap "+ New Deck" to create one.'), findsOneWidget);
        expect(find.byIcon(Icons.style_outlined), findsOneWidget);
        expect(find.text('Charizard ex / Pidgeot ex'), findsNothing);
        expect(find.text('Lost Zone Giratina VSTAR'), findsNothing);
      });

      testWidgets('3.3. Empty state recovery via tab switching restores deck list immediately', (tester) async {
        await tester.pumpWidget(buildTestWidget(initialFilter: 'pokemon'));
        await tester.pumpAndSettle();

        // Enter empty state (Draft tab)
        await tester.tap(find.byKey(const Key('decks_tab_draft')));
        await tester.pumpAndSettle();
        expect(find.text('No decks found'), findsOneWidget);

        // Switch to Competitive (Tab 1) -> 2 Pokemon decks appear
        await tester.tap(find.byKey(const Key('decks_tab_competitive')));
        await tester.pumpAndSettle();
        expect(find.text('No decks found'), findsNothing);
        expect(find.text('Charizard ex / Pidgeot ex'), findsOneWidget);
        expect(find.text('Lost Zone Giratina VSTAR'), findsOneWidget);

        // Switch to All Decks (Tab 0) -> 2 Pokemon decks appear
        await tester.tap(find.byKey(const Key('decks_tab_all')));
        await tester.pumpAndSettle();
        expect(find.text('Charizard ex / Pidgeot ex'), findsOneWidget);
        expect(find.text('Lost Zone Giratina VSTAR'), findsOneWidget);
      });

      testWidgets('3.4. Creating deck via FAB while in empty state dynamically updates list in Draft tab', (tester) async {
        await tester.pumpWidget(buildTestWidget(initialFilter: 'pokemon'));
        await tester.pumpAndSettle();

        // Enter empty state in Draft tab
        await tester.tap(find.byKey(const Key('decks_tab_draft')));
        await tester.pumpAndSettle();
        expect(find.text('No decks found'), findsOneWidget);

        // Tap FAB to create new deck (created with isRegistered: false)
        await tester.tap(find.byKey(const Key('decks_new_deck_fab')));
        await tester.pumpAndSettle();

        // Since newly created deck is Draft (isRegistered == false), it should appear immediately!
        expect(find.text('No decks found'), findsNothing);
        expect(find.textContaining('Pokémon Standard • 0/60'), findsOneWidget);
        // All Decks count should have incremented from 2 to 3
        expect(find.text('All Decks (3)'), findsOneWidget);
      });
    });

    // =========================================================================
    // 4. FAB Creation Stress & Ruleset / Domain Binding
    // =========================================================================
    group('4. FAB Creation Stress & Ruleset / Domain Binding', () {
      testWidgets('4.1. Rapid multi-domain deck creation generates correct formats, card counts, and domain bindings', (tester) async {
        await tester.pumpWidget(buildTestWidget(initialFilter: 'all'));
        await tester.pumpAndSettle();

        final fabFinder = find.byKey(const Key('decks_new_deck_fab'));

        // 1. In 'all' domain: create deck -> defaults to MTG Commander, 0/100
        await tester.tap(fabFinder);
        await tester.pumpAndSettle();
        expect(find.text('All Decks (7)'), findsOneWidget);
        expect(find.textContaining('MTG Commander • 0/100'), findsOneWidget);

        // 2. Switch to 'pokemon': initial count 2 -> create deck -> 3
        await tester.tap(find.byKey(const Key('decks_tcg_context_switcher')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('tcg_filter_pokemon')));
        await tester.pumpAndSettle();

        expect(find.text('All Decks (2)'), findsOneWidget);
        await tester.tap(fabFinder);
        await tester.pumpAndSettle();

        expect(find.text('All Decks (3)'), findsOneWidget);
        expect(find.textContaining('Pokémon Standard • 0/60'), findsOneWidget);

        // 3. Switch to 'lorcana': initial count 1 -> create deck -> 2
        await tester.tap(find.byKey(const Key('decks_tcg_context_switcher')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('tcg_filter_lorcana')));
        await tester.pumpAndSettle();

        expect(find.text('All Decks (1)'), findsOneWidget);
        await tester.tap(fabFinder);
        await tester.pumpAndSettle();

        expect(find.text('All Decks (2)'), findsOneWidget);
        expect(find.textContaining('Disney Lorcana Core • 0/60'), findsOneWidget);

        // 4. Switch to 'mtg': initial count 3 + 1 from step 1 = 4 -> create deck -> 5
        await tester.tap(find.byKey(const Key('decks_tcg_context_switcher')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('tcg_filter_mtg')));
        await tester.pumpAndSettle();

        expect(find.text('All Decks (4)'), findsOneWidget);
        await tester.tap(fabFinder);
        await tester.pumpAndSettle();

        expect(find.text('All Decks (5)'), findsOneWidget);

        // 5. Switch back to 'all': total should now be 6 (original) + 4 (created) = 10
        await tester.tap(find.byKey(const Key('decks_tcg_context_switcher')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('tcg_filter_all')));
        await tester.pumpAndSettle();

        expect(find.text('All Decks (10)'), findsOneWidget);

        // 6. Switch to Draft tab (Tab 2) in 'all': original had 3 drafts + 4 created = 7 drafts
        await tester.tap(find.byKey(const Key('decks_tab_draft')));
        await tester.pumpAndSettle();

        // Newly created decks must all appear under Draft tab
        expect(find.textContaining('Disney Lorcana Core • 0/60'), findsOneWidget);
        expect(find.textContaining('Pokémon Standard • 0/60'), findsOneWidget);
        expect(find.textContaining('MTG Commander • 0/100'), findsWidgets);
      });

      testWidgets('4.2. Newly created decks from each domain construct valid typed Deck models for DeckBuilderScreen', (tester) async {
        await tester.pumpWidget(buildTestWidget(initialFilter: 'lorcana'));
        await tester.pumpAndSettle();

        // Create Lorcana deck
        await tester.tap(find.byKey(const Key('decks_new_deck_fab')));
        await tester.pumpAndSettle();

        // Tap the created Lorcana deck
        await tester.tap(find.textContaining('Disney Lorcana Core • 0/60'));
        await tester.pumpAndSettle();

        // Verify DeckBuilderScreen received typed Deck with correct attributes
        expect(find.byType(DeckBuilderScreen), findsOneWidget);
        final lorcanaBuilder = tester.widget<DeckBuilderScreen>(find.byType(DeckBuilderScreen));
        expect(lorcanaBuilder.deck.tcgDomain, equals('lorcana'));
        expect(lorcanaBuilder.deck.format, equals('Disney Lorcana Core'));
        expect(lorcanaBuilder.deck.isRegistered, isFalse);
        expect(lorcanaBuilder.deck.isCompetitive, isFalse);

        // Pop back to DecksScreen
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.byType(DecksScreen), findsOneWidget);

        // Unmount cleanly to flush Drift stream timer
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      });
    });
  });
}
