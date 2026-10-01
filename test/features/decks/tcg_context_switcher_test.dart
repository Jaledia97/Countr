import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/features/decks/presentation/screens/decks_screen.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/decks/presentation/widgets/deck_setup_wizard_modal.dart';

void main() {
  Widget createSubject({
    String initialFilter = 'all',
  }) {
    return ProviderScope(
      overrides: [
        activeDeckTcgFilterProvider.overrideWith((ref) => initialFilter),
      ],
      child: const MaterialApp(
        home: DecksScreen(),
      ),
    );
  }

  group('TCG Context Switcher & FAB Ruleset Binding Tests', () {
    testWidgets('1. Dropdown renders in AppBar defaulting to "All Decks" with chevron icon', (tester) async {
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      final dropdownFinder = find.byKey(const Key('decks_tcg_context_switcher'));
      expect(dropdownFinder, findsOneWidget);
      expect(find.text('All Decks'), findsWidgets); // Title and Tab 0
      expect(find.byIcon(Icons.arrow_drop_down_rounded), findsOneWidget);
    });

    testWidgets('2. Tapping dropdown opens popup menu displaying all 4 TCG options', (tester) async {
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('decks_tcg_context_switcher')));
      await tester.pumpAndSettle();

      // Check all 4 options exist in popup menu
      expect(find.byKey(const Key('tcg_filter_all')), findsOneWidget);
      expect(find.byKey(const Key('tcg_filter_mtg')), findsOneWidget);
      expect(find.byKey(const Key('tcg_filter_pokemon')), findsOneWidget);
      expect(find.byKey(const Key('tcg_filter_lorcana')), findsOneWidget);

      expect(find.widgetWithText(PopupMenuItem<String>, 'All Decks'), findsOneWidget);
      expect(find.widgetWithText(PopupMenuItem<String>, 'Magic: The Gathering'), findsOneWidget);
      expect(find.widgetWithText(PopupMenuItem<String>, 'Pokémon'), findsOneWidget);
      expect(find.widgetWithText(PopupMenuItem<String>, 'Disney Lorcana'), findsOneWidget);

      // Active item 'all' has checkmark
      expect(find.descendant(
        of: find.byKey(const Key('tcg_filter_all')),
        matching: find.byIcon(Icons.check_rounded),
      ), findsOneWidget);
    });

    testWidgets('3. Selecting "Magic: The Gathering" filters deck list to 3 MTG decks and updates tab count', (tester) async {
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('decks_tcg_context_switcher')));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(PopupMenuItem<String>, 'Magic: The Gathering'));
      await tester.pumpAndSettle();

      // Title updated
      expect(find.text('Magic: The Gathering'), findsOneWidget);

      // Tab count updated to 3
      expect(find.text('All Decks (3)'), findsOneWidget);

      // Verify only MTG decks appear
      expect(find.text('Edgar Markov Aristocrats'), findsOneWidget);
      expect(find.text('Yuriko, the Tiger\'s Shadow'), findsOneWidget);
      expect(find.text('Modern Mono-Green Tron'), findsOneWidget);
      expect(find.text('Charizard ex / Pidgeot ex'), findsNothing);
      expect(find.text('Ruby / Amethyst Bounce Control'), findsNothing);
      expect(find.text('Lost Zone Giratina VSTAR'), findsNothing);
    });

    testWidgets('4. Selecting "Pokémon" filters deck list to 2 Pokémon decks and updates tab count', (tester) async {
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('decks_tcg_context_switcher')));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(PopupMenuItem<String>, 'Pokémon'));
      await tester.pumpAndSettle();

      // Title updated
      expect(find.text('Pokémon'), findsOneWidget);

      // Tab count updated to 2
      expect(find.text('All Decks (2)'), findsOneWidget);

      // Verify only Pokémon decks appear
      expect(find.text('Charizard ex / Pidgeot ex'), findsOneWidget);
      expect(find.text('Lost Zone Giratina VSTAR'), findsOneWidget);
      expect(find.text('Edgar Markov Aristocrats'), findsNothing);
      expect(find.text('Ruby / Amethyst Bounce Control'), findsNothing);
    });

    testWidgets('5. Selecting "Disney Lorcana" filters deck list to 1 Lorcana deck and updates tab count', (tester) async {
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('decks_tcg_context_switcher')));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(PopupMenuItem<String>, 'Disney Lorcana'));
      await tester.pumpAndSettle();

      // Title updated
      expect(find.text('Disney Lorcana'), findsOneWidget);

      // Tab count updated to 1
      expect(find.text('All Decks (1)'), findsOneWidget);

      // Verify only Lorcana deck appears
      expect(find.text('Ruby / Amethyst Bounce Control'), findsOneWidget);
      expect(find.text('Edgar Markov Aristocrats'), findsNothing);
      expect(find.text('Charizard ex / Pidgeot ex'), findsNothing);
    });

    testWidgets('6. Subheader tabs filter by Competitive and Draft within active domain and show empty state when 0 match', (tester) async {
      await tester.pumpWidget(createSubject(initialFilter: 'pokemon'));
      await tester.pumpAndSettle();

      // All Decks tab has 2 decks
      expect(find.text('Charizard ex / Pidgeot ex'), findsOneWidget);
      expect(find.text('Lost Zone Giratina VSTAR'), findsOneWidget);

      // Tap Competitive tab
      await tester.tap(find.byKey(const Key('decks_tab_competitive')));
      await tester.pumpAndSettle();
      expect(find.text('Charizard ex / Pidgeot ex'), findsOneWidget);
      expect(find.text('Lost Zone Giratina VSTAR'), findsOneWidget);

      // Tap Draft tab (both pokemon decks are registered, so 0 drafts exist)
      await tester.tap(find.byKey(const Key('decks_tab_draft')));
      await tester.pumpAndSettle();

      expect(find.text('No decks found'), findsOneWidget);
      expect(find.text('Tap "+ New Deck" to create one.'), findsOneWidget);
      expect(find.text('Charizard ex / Pidgeot ex'), findsNothing);
    });

    testWidgets('7. Tab count maintains backwards compatibility ("All Decks (6)") when initial domain is "all"', (tester) async {
      await tester.pumpWidget(createSubject(initialFilter: 'all'));
      await tester.pumpAndSettle();

      expect(find.text('All Decks (6)'), findsOneWidget);
      expect(find.text('Competitive'), findsOneWidget);
      expect(find.text('Draft / In-Progress'), findsOneWidget);
    });

    testWidgets('8. FAB tap in MTG filter launches DeckSetupWizardModal with Commander format', (tester) async {
      await tester.pumpWidget(createSubject(initialFilter: 'mtg'));
      await tester.pumpAndSettle();

      expect(find.text('All Decks (3)'), findsOneWidget);

      final fab = find.byKey(const Key('decks_new_deck_fab'));
      expect(fab, findsOneWidget);

      await tester.tap(fab);
      await tester.pumpAndSettle();

      // Opens DeckSetupWizardModal with Commander format
      expect(find.byType(DeckSetupWizardModal), findsOneWidget);
      expect(find.text('Commander'), findsOneWidget);
      expect(find.byKey(const Key('deck_wizard_name_input')), findsOneWidget);
      expect(find.byKey(const Key('deck_wizard_create_button')), findsOneWidget);

      // Close modal
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(DeckSetupWizardModal), findsNothing);
      expect(find.byType(DecksScreen), findsOneWidget);

      // Unmount widget tree and flush Drift stream disposal timer
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('9. FAB tap in Pokémon filter launches DeckSetupWizardModal with Pokémon Standard format', (tester) async {
      await tester.pumpWidget(createSubject(initialFilter: 'pokemon'));
      await tester.pumpAndSettle();

      expect(find.text('All Decks (2)'), findsOneWidget);

      final fab = find.byKey(const Key('decks_new_deck_fab'));
      await tester.tap(fab);
      await tester.pumpAndSettle();

      // Opens DeckSetupWizardModal with Pokémon Standard format
      expect(find.byType(DeckSetupWizardModal), findsOneWidget);
      expect(find.text('Pokémon Standard'), findsOneWidget);
      expect(find.byKey(const Key('deck_wizard_name_input')), findsOneWidget);
      expect(find.byKey(const Key('deck_wizard_create_button')), findsOneWidget);

      // Close modal
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(DeckSetupWizardModal), findsNothing);
      expect(find.byType(DecksScreen), findsOneWidget);

      // Unmount widget tree and flush Drift stream disposal timer
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('10. FAB tap in Lorcana filter launches DeckSetupWizardModal with Disney Lorcana Core format', (tester) async {
      await tester.pumpWidget(createSubject(initialFilter: 'lorcana'));
      await tester.pumpAndSettle();

      expect(find.text('All Decks (1)'), findsOneWidget);

      final fab = find.byKey(const Key('decks_new_deck_fab'));
      await tester.tap(fab);
      await tester.pumpAndSettle();

      // Opens DeckSetupWizardModal with Disney Lorcana Core format
      expect(find.byType(DeckSetupWizardModal), findsOneWidget);
      expect(find.text('Disney Lorcana Core'), findsOneWidget);
      expect(find.byKey(const Key('deck_wizard_name_input')), findsOneWidget);
      expect(find.byKey(const Key('deck_wizard_create_button')), findsOneWidget);

      // Close modal
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(DeckSetupWizardModal), findsNothing);
      expect(find.byType(DecksScreen), findsOneWidget);

      // Unmount widget tree and flush Drift stream disposal timer
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('11. FAB tap in "all" filter defaults to MTG Commander in DeckSetupWizardModal', (tester) async {
      await tester.pumpWidget(createSubject(initialFilter: 'all'));
      await tester.pumpAndSettle();

      expect(find.text('All Decks (6)'), findsOneWidget);

      final fab = find.byKey(const Key('decks_new_deck_fab'));
      await tester.tap(fab);
      await tester.pumpAndSettle();

      // Opens DeckSetupWizardModal defaulting to Commander format
      expect(find.byType(DeckSetupWizardModal), findsOneWidget);
      expect(find.text('Commander'), findsOneWidget);
      expect(find.byKey(const Key('deck_wizard_name_input')), findsOneWidget);
      expect(find.byKey(const Key('deck_wizard_create_button')), findsOneWidget);

      // Close modal
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(DeckSetupWizardModal), findsNothing);
      expect(find.byType(DecksScreen), findsOneWidget);

      // Unmount widget tree and flush Drift stream disposal timer
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('12. Adversarial Layout Stress: Ultra-narrow viewport (320px) + 2.0x text scale renders title, dropdown, tabs, and FAB without RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 568),
            textScaler: TextScaler.linear(2.0),
          ),
          child: const ProviderScope(
            child: MaterialApp(
              home: DecksScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Zero layout overflow exceptions
      expect(tester.takeException(), isNull);
      expect(find.byType(DecksScreen), findsOneWidget);
      expect(find.byKey(const Key('decks_tcg_context_switcher')), findsOneWidget);
      expect(find.byKey(const Key('decks_new_deck_fab')), findsOneWidget);
    });
  });
}
