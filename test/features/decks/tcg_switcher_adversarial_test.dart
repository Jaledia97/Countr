import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/data/mock_deck_data.dart';
import 'package:countr/features/decks/presentation/screens/decks_screen.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/decks/presentation/widgets/deck_setup_wizard_modal.dart';
import 'package:countr/features/decks/presentation/widgets/deck_thumbnail_picker_modal.dart';
import 'package:countr/features/decks/presentation/widgets/proportional_bubble_scrollbar.dart';

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

      testWidgets('3.4. Tapping FAB launches DeckSetupWizardModal when in empty state', (tester) async {
        await tester.pumpWidget(buildTestWidget(initialFilter: 'pokemon'));
        await tester.pumpAndSettle();

        // Enter empty state in Draft tab
        await tester.tap(find.byKey(const Key('decks_tab_draft')));
        await tester.pumpAndSettle();
        expect(find.text('No decks found'), findsOneWidget);

        // Tap FAB to open wizard modal
        await tester.tap(find.byKey(const Key('decks_new_deck_fab')));
        await tester.pumpAndSettle();

        // Verify DeckSetupWizardModal is displayed with Pokémon domain
        expect(find.byType(DeckSetupWizardModal), findsOneWidget);
        expect(find.text('New Deck Setup'), findsOneWidget);

        // Close modal
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();
        expect(find.byType(DeckSetupWizardModal), findsNothing);
      });
    });

    // =========================================================================
    // 4. FAB Creation Stress & Ruleset / Domain Binding
    // =========================================================================
    group('4. FAB Creation Stress & Ruleset / Domain Binding', () {
      testWidgets('4.1. Tapping FAB across TCG domains launches DeckSetupWizardModal with appropriate domain preset', (tester) async {
        await tester.pumpWidget(buildTestWidget(initialFilter: 'all'));
        await tester.pumpAndSettle();

        final fabFinder = find.byKey(const Key('decks_new_deck_fab'));

        // 1. In 'all' domain: tap FAB -> opens wizard with default MTG format (Commander)
        await tester.tap(fabFinder);
        await tester.pumpAndSettle();
        expect(find.byType(DeckSetupWizardModal), findsOneWidget);
        expect(find.text('Commander'), findsOneWidget);
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();

        // 2. Switch to 'pokemon': tap FAB -> opens wizard with Pokémon Standard
        await tester.tap(find.byKey(const Key('decks_tcg_context_switcher')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('tcg_filter_pokemon')));
        await tester.pumpAndSettle();

        await tester.tap(fabFinder);
        await tester.pumpAndSettle();
        expect(find.byType(DeckSetupWizardModal), findsOneWidget);
        expect(find.text('Pokémon Standard'), findsOneWidget);
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();

        // 3. Switch to 'lorcana': tap FAB -> opens wizard with Disney Lorcana Core
        await tester.tap(find.byKey(const Key('decks_tcg_context_switcher')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('tcg_filter_lorcana')));
        await tester.pumpAndSettle();

        await tester.tap(fabFinder);
        await tester.pumpAndSettle();
        expect(find.byType(DeckSetupWizardModal), findsOneWidget);
        expect(find.text('Disney Lorcana Core'), findsOneWidget);
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();

        // 4. Switch to 'mtg': tap FAB -> opens wizard with MTG Commander
        await tester.tap(find.byKey(const Key('decks_tcg_context_switcher')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('tcg_filter_mtg')));
        await tester.pumpAndSettle();

        await tester.tap(fabFinder);
        await tester.pumpAndSettle();
        expect(find.byType(DeckSetupWizardModal), findsOneWidget);
        expect(find.text('Commander'), findsOneWidget);
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();
      });

      testWidgets('4.2. DeckSetupWizardModal launched via FAB exposes format options and input fields', (tester) async {
        await tester.pumpWidget(buildTestWidget(initialFilter: 'lorcana'));
        await tester.pumpAndSettle();

        // Tap FAB to open wizard for Lorcana
        await tester.tap(find.byKey(const Key('decks_new_deck_fab')));
        await tester.pumpAndSettle();

        expect(find.byType(DeckSetupWizardModal), findsOneWidget);
        expect(find.byKey(const Key('deck_wizard_name_input')), findsOneWidget);
        expect(find.byKey(const Key('deck_wizard_format_dropdown')), findsOneWidget);
        expect(find.byKey(const Key('deck_wizard_create_button')), findsOneWidget);

        // Pop back to DecksScreen
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();
        expect(find.byType(DecksScreen), findsOneWidget);
        expect(find.byType(DeckSetupWizardModal), findsNothing);

        // Unmount cleanly to flush Drift stream timer
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      });
    });

    // =========================================================================
    // 5. Patch 4.8 R3 Bug Fixes & UI Enhancements Verification
    // =========================================================================
    group('5. Patch 4.8 R3 Bug Fixes & UI Enhancements Verification', () {
      testWidgets('5.1. DeckThumbnailPickerModal renders inside showModalBottomSheet without layout crash', (tester) async {
        final mockDeck = Deck(
          id: 'test-deck-cover',
          name: 'Edgar Test Deck',
          format: 'MTG Commander',
          tcgDomain: 'mtg',
          wins: 0,
          losses: 0,
          draws: 0,
          isRegistered: false,
          isCompetitive: false,
          isAssembled: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isDeleted: false,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              deckProvider(mockDeck.id).overrideWith((ref) => Stream.value(mockDeck)),
              deckItemsProvider(mockDeck.id).overrideWith((ref) => Stream.value([])),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () => DeckThumbnailPickerModal.show(context, deck: mockDeck),
                    child: const Text('Open Modal'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap button to launch modal via showModalBottomSheet
        await tester.tap(find.text('Open Modal'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull, reason: 'RenderFlex crash when opening DeckThumbnailPickerModal');
        expect(find.byType(DeckThumbnailPickerModal), findsOneWidget);
        expect(find.text('Customize Deck Cover'), findsOneWidget);
        expect(find.byType(TabBarView), findsOneWidget);

        // Close modal
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();
        expect(find.byType(DeckThumbnailPickerModal), findsNothing);
      });

      test('5.2. MockDeckData items contain authentic Oracle rules text for key cards', () {
        final edgarItems = MockDeckData.getDeckItems(MockDeckData.edgarMarkovDeckId);

        // Verify Edgar Markov has authentic oracle_text
        final edgarCard = edgarItems.firstWhere((c) => c['id'] == 'edgar-markov');
        final edgarDyn = jsonDecode(edgarCard['dynamic_data'] as String) as Map<String, dynamic>;
        expect(edgarDyn['oracle_text'], isNotNull);
        expect(
          edgarDyn['oracle_text'],
          contains('Eminence — As long as Edgar Markov is in the command zone'),
        );

        // Verify Blood Artist
        final artistCard = edgarItems.firstWhere((c) => c['id'] == 'blood-artist');
        final artistDyn = jsonDecode(artistCard['dynamic_data'] as String) as Map<String, dynamic>;
        expect(artistDyn['oracle_text'], isNotNull);
        expect(artistDyn['oracle_text'], contains('Whenever Blood Artist or another creature dies'));

        // Verify Sol Ring
        final solCard = edgarItems.firstWhere((c) => c['id'] == 'sol-ring');
        final solDyn = jsonDecode(solCard['dynamic_data'] as String) as Map<String, dynamic>;
        expect(solDyn['oracle_text'], equals('{T}: Add {C}{C}.'));

        // Verify Command Tower
        final towerCard = edgarItems.firstWhere((c) => c['id'] == 'command-tower');
        final towerDyn = jsonDecode(towerCard['dynamic_data'] as String) as Map<String, dynamic>;
        expect(towerDyn['oracle_text'], contains("Add one mana of any color in your commander's color identity"));

        // Verify Teferi's Protection
        final teferiCard = edgarItems.firstWhere((c) => c['id'] == 'teferis-protection');
        final teferiDyn = jsonDecode(teferiCard['dynamic_data'] as String) as Map<String, dynamic>;
        expect(teferiDyn['oracle_text'], contains('your life total can\'t change and you gain protection from everything'));
      });

      testWidgets('5.3. ProportionalBubbleScrollbar renders thin rail spine centered in gesture area', (tester) async {
        final sections = [
          ScrollbarSection(label: 'Commander', count: 1, onTap: () {}),
          ScrollbarSection(label: 'Creatures', count: 32, onTap: () {}),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 400,
                width: 50,
                child: ProportionalBubbleScrollbar(
                  sections: sections,
                  railWidth: 26,
                  railColor: Colors.blueGrey,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        // Find Positioned with 5.0 dp width
        final positionedFinder = find.byWidgetPredicate(
          (widget) => widget is Positioned && widget.width == 5.0,
        );
        expect(positionedFinder, findsOneWidget);
      });
    });
  });
}
