import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/decks/data/mock_deck_data.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/decks/presentation/screens/decks_screen.dart';
import 'package:countr/features/decks/presentation/screens/deck_builder_screen.dart';
import 'package:countr/features/decks/presentation/widgets/deck_thumbnail_picker_modal.dart';
import 'package:countr/features/decks/presentation/widgets/deck_setup_wizard_modal.dart';
import 'package:countr/features/decks/presentation/widgets/inline_deck_analytics_card.dart';
import 'package:countr/features/decks/presentation/widgets/proportional_bubble_scrollbar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('M3 Patch 4.8 R3 Adversarial Review & Critic Suite', () {
    // -------------------------------------------------------------------------
    // 1. DeckThumbnailPickerModal Layout Constraints & Crash Immunity
    // -------------------------------------------------------------------------
    group('1. DeckThumbnailPickerModal Stress-Testing', () {
      final sampleDeck = Deck(
        id: 'deck-adv-cover-1',
        name: 'Adversarial Cover Test Deck',
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

      testWidgets('Renders inside showModalBottomSheet on compact screen (320x480) with zero overflow', (tester) async {
        tester.view.physicalSize = const Size(320, 480);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              deckProvider(sampleDeck.id).overrideWith((ref) => Stream.value(sampleDeck)),
              deckItemsProvider(sampleDeck.id).overrideWith((ref) => Stream.value([])),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (ctx) => ElevatedButton(
                    onPressed: () => DeckThumbnailPickerModal.show(ctx, deck: sampleDeck),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(DeckThumbnailPickerModal), findsOneWidget);
        expect(find.byType(TabBarView), findsOneWidget);

        // Verify height constraint matches 0.85 * screenHeight
        final sizedBox = tester.widget<SizedBox>(
          find.ancestor(
            of: find.byKey(const Key('deck_thumbnail_picker_modal')),
            matching: find.byType(SizedBox),
          ).first,
        );
        expect(sizedBox.height, closeTo(480 * 0.85, 0.01));

        // Close
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();
      });

      testWidgets('Tab switching between "Cards in Deck" and "Search Catalog" operates smoothly', (tester) async {
        final mockItems = [
          <String, dynamic>{
            'id': 'edgar-markov',
            'vault_item_id': 'edgar-markov',
            'name': 'Edgar Markov',
            'set_or_series': 'C17',
            'quantity': 1,
            'image_url': 'https://cards.scryfall.io/art_crop/front/8/d/8d94b8ec-ecda-43c8-a60e-1ba33e6a54a4.jpg',
            'dynamic_data': jsonEncode({
              'mana_cost': '{3}{R}{W}{B}',
              'image_uris': {
                'art_crop': 'https://cards.scryfall.io/art_crop/front/8/d/8d94b8ec-ecda-43c8-a60e-1ba33e6a54a4.jpg',
              },
            }),
          },
        ];

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              deckProvider(sampleDeck.id).overrideWith((ref) => Stream.value(sampleDeck)),
              deckItemsProvider(sampleDeck.id).overrideWith((ref) => Stream.value(mockItems)),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (ctx) => ElevatedButton(
                    onPressed: () => DeckThumbnailPickerModal.show(ctx, deck: sampleDeck),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        // Switch to Search Catalog tab
        await tester.tap(find.byKey(const Key('tab_search_catalog')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('deck_thumbnail_catalog_search_input')), findsOneWidget);

        // Switch back to Cards in Deck tab
        await tester.tap(find.byKey(const Key('tab_cards_in_deck')));
        await tester.pumpAndSettle();
        expect(find.text('Edgar Markov'), findsWidgets);

        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();
      });
    });

    // -------------------------------------------------------------------------
    // 2. Oracle Rules Text Integrity Verification (VaultDao & MockDeckData)
    // -------------------------------------------------------------------------
    group('2. Oracle Rules Text Integrity', () {
      test('MockDeckData contains authentic oracle_text for all 5 key cards', () {
        final items = MockDeckData.getDeckItems(MockDeckData.edgarMarkovDeckId);

        // Edgar Markov
        final edgar = items.firstWhere((c) => c['id'] == 'edgar-markov');
        final edgarDyn = jsonDecode(edgar['dynamic_data'] as String);
        expect(edgarDyn['oracle_text'], isNotNull);
        expect(edgarDyn['oracle_text'], contains('Eminence — As long as Edgar Markov is in the command zone'));
        expect(edgarDyn['oracle_text'], contains('First strike, haste'));

        // Blood Artist
        final artist = items.firstWhere((c) => c['id'] == 'blood-artist');
        final artistDyn = jsonDecode(artist['dynamic_data'] as String);
        expect(artistDyn['oracle_text'], isNotNull);
        expect(artistDyn['oracle_text'], contains('Whenever Blood Artist or another creature dies'));

        // Sol Ring
        final sol = items.firstWhere((c) => c['id'] == 'sol-ring');
        final solDyn = jsonDecode(sol['dynamic_data'] as String);
        expect(solDyn['oracle_text'], equals('{T}: Add {C}{C}.'));

        // Command Tower
        final tower = items.firstWhere((c) => c['id'] == 'command-tower');
        final towerDyn = jsonDecode(tower['dynamic_data'] as String);
        expect(towerDyn['oracle_text'], isNotNull);
        expect(towerDyn['oracle_text'], contains('Add one mana of any color in your commander\'s color identity'));

        // Teferi's Protection
        final teferi = items.firstWhere((c) => c['id'] == 'teferis-protection');
        final teferiDyn = jsonDecode(teferi['dynamic_data'] as String);
        expect(teferiDyn['oracle_text'], isNotNull);
        expect(teferiDyn['oracle_text'], contains('your life total can\'t change and you gain protection from everything'));
      });

      test('VaultDao database seed contains authentic oracle_text for seeded cards', () async {
        final db = AppDatabase(NativeDatabase.memory());
        final dao = VaultDao(db);
        await dao.seedDatabase();

        final items = await dao.select(dao.vaultItems).get();

        // Check Edgar Markov
        final edgar = items.firstWhere((i) => i.id == 'edgar-markov');
        final edgarDyn = jsonDecode(edgar.dynamicData!) as Map<String, dynamic>;
        expect(edgarDyn['oracle_text'], isNotNull);
        expect(edgarDyn['oracle_text'], contains('Eminence'));

        // Check Yuriko
        final yuriko = items.firstWhere((i) => i.id == 'card-yuriko');
        final yurikoDyn = jsonDecode(yuriko.dynamicData!) as Map<String, dynamic>;
        expect(yurikoDyn['oracle_text'], isNotNull);
        expect(yurikoDyn['oracle_text'], contains('Commander ninjutsu'));

        // Check Sol Ring
        final sol = items.firstWhere((i) => i.id == 'item-mtg-sol-ring');
        final solDyn = jsonDecode(sol.dynamicData!) as Map<String, dynamic>;
        expect(solDyn['oracle_text'], equals('{T}: Add {C}{C}.'));

        // Check Karn Liberated (card-tron)
        final tron = items.firstWhere((i) => i.id == 'card-tron');
        final tronDyn = jsonDecode(tron.dynamicData!) as Map<String, dynamic>;
        expect(tronDyn['oracle_text'], isNotNull);
        expect(tronDyn['oracle_text'], contains('Restart the game'));

        await db.close();
      });
    });

    // -------------------------------------------------------------------------
    // 3. decks_new_deck_fab Production Wiring
    // -------------------------------------------------------------------------
    group('3. decks_new_deck_fab Production Wiring', () {
      testWidgets('FAB launches DeckSetupWizardModal with domain preselected', (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              activeDeckTcgFilterProvider.overrideWith((ref) => 'pokemon'),
            ],
            child: const MaterialApp(
              home: DecksScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Find FAB and tap
        final fab = find.byKey(const Key('decks_new_deck_fab'));
        expect(fab, findsOneWidget);
        await tester.tap(fab);
        await tester.pumpAndSettle();

        // Modal should open
        expect(find.byType(DeckSetupWizardModal), findsOneWidget);
        expect(find.byKey(const Key('deck_wizard_name_input')), findsOneWidget);

        // Close wizard
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();
        expect(find.byType(DeckSetupWizardModal), findsNothing);

        // Clean unmount
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(milliseconds: 100));
      });
    });

    // -------------------------------------------------------------------------
    // 4. Deck Builder App Bar De-duplication
    // -------------------------------------------------------------------------
    group('4. Deck Builder App Bar De-duplication', () {
      testWidgets('AppBar actions do NOT contain redundant analytics button', (tester) async {
        final testDeck = Deck(
          id: 'deck-appbar-test',
          name: 'App Bar Test Deck',
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
              deckProvider(testDeck.id).overrideWith((ref) => Stream.value(testDeck)),
              deckItemsProvider(testDeck.id).overrideWith((ref) => Stream.value([])),
            ],
            child: MaterialApp(
              home: DeckBuilderScreen(deck: testDeck),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify SliverAppBar actions has no analytics_rounded icon
        final appbarActions = find.descendant(
          of: find.byType(SliverAppBar),
          matching: find.byIcon(Icons.analytics_rounded),
        );
        expect(appbarActions, findsNothing);
      });
    });

    // -------------------------------------------------------------------------
    // 5. User Notes Container in Inline Deck Analytics
    // -------------------------------------------------------------------------
    group('5. User Notes Container in Inline Deck Analytics', () {
      final sampleAnalytics = MockDeckData.computeAnalyticsFromItems(
        MockDeckData.getDeckItems(MockDeckData.edgarMarkovDeckId),
      );

      testWidgets('Renders custom notes when provided', (tester) async {
        const customNote = 'Mulligan aggressively for 1-drop vampires and mana rocks.';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: InlineDeckAnalyticsCard(
                  analytics: sampleAnalytics,
                  isExpanded: true,
                  onToggleExpand: () {},
                  onOpenModal: () {},
                  userNotes: customNote,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('inline_analytics_user_notes_container')), findsOneWidget);
        expect(find.text(customNote), findsOneWidget);

        // Verify primary text color is used for user content
        final textWidget = tester.widget<Text>(find.text(customNote));
        expect(textWidget.style?.color, equals(AppColors.textPrimary));
        expect(textWidget.style?.fontStyle, equals(FontStyle.normal));
      });

      testWidgets('Renders italic placeholder text when notes are null or empty', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: InlineDeckAnalyticsCard(
                  analytics: sampleAnalytics,
                  isExpanded: true,
                  onToggleExpand: () {},
                  onOpenModal: () {},
                  userNotes: '   ',
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('inline_analytics_user_notes_container')), findsOneWidget);
        final placeholderFinder = find.text('No notes added for this deck yet. Open "Deck Details & Notes" to edit primer and strategy.');
        expect(placeholderFinder, findsOneWidget);

        final textWidget = tester.widget<Text>(placeholderFinder);
        expect(textWidget.style?.color, equals(AppColors.textMuted));
        expect(textWidget.style?.fontStyle, equals(FontStyle.italic));
      });

      testWidgets('Does not render user notes container when collapsed', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: InlineDeckAnalyticsCard(
                  analytics: sampleAnalytics,
                  isExpanded: false,
                  onToggleExpand: () {},
                  onOpenModal: () {},
                  userNotes: 'Some notes',
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('inline_analytics_user_notes_container')), findsNothing);
      });
    });

    // -------------------------------------------------------------------------
    // 6. Proportional Bubble Scrollbar Rail Spine & Touch Target
    // -------------------------------------------------------------------------
    group('6. Proportional Bubble Scrollbar Rail Spine', () {
      final sections = [
        ScrollbarSection(label: 'Commander', count: 1, onTap: () {}),
        ScrollbarSection(label: 'Creatures', count: 35, onTap: () {}),
        ScrollbarSection(label: 'Spells', count: 24, onTap: () {}),
        ScrollbarSection(label: 'Lands', count: 40, onTap: () {}),
      ];

      testWidgets('Centered 5.0 dp spine rendered inside 26.0 dp gesture target', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 500,
                width: 40,
                child: ProportionalBubbleScrollbar(
                  sections: sections,
                  railWidth: 26.0,
                  railColor: Colors.grey,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Gesture container retains railWidth 26.0
        final railFinder = find.byWidgetPredicate(
          (w) => w is Container && w.constraints?.maxWidth == 26.0,
        );
        expect(railFinder, findsOneWidget);

        // 2. Rail spine is Positioned with width: 5.0 and left: (26.0 - 5.0) / 2 = 10.5
        final spineFinder = find.byWidgetPredicate(
          (w) => w is Positioned && w.width == 5.0 && w.left == 10.5,
        );
        expect(spineFinder, findsOneWidget);

        // 3. DecoratedBox has borderRadius 2.5
        final decorFinder = find.descendant(
          of: spineFinder,
          matching: find.byType(DecoratedBox),
        );
        expect(decorFinder, findsOneWidget);
        final decor = tester.widget<DecoratedBox>(decorFinder).decoration as BoxDecoration;
        expect(decor.borderRadius, equals(BorderRadius.circular(2.5)));
      });

      testWidgets('Scrub gestures on the outer rail boundary (x=2.0) work correctly', (tester) async {
        final scrollController = ScrollController();
        double? scrubOffset;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 400,
                child: Row(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: 100,
                        itemExtent: 50,
                        itemBuilder: (context, i) => ListTile(title: Text('Item $i')),
                      ),
                    ),
                    SizedBox(
                      height: 400,
                      width: 26.0,
                      child: ProportionalBubbleScrollbar(
                        sections: sections,
                        controller: scrollController,
                        railWidth: 26.0,
                        onScrubUpdate: (offset) => scrubOffset = offset,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap/drag near the left edge of the 26dp rail (x=2.0 inside rail)
        final railTopLeft = tester.getTopLeft(find.byType(ProportionalBubbleScrollbar));
        final edgeGesture = await tester.startGesture(railTopLeft + const Offset(2.0, 50.0));
        await edgeGesture.moveBy(const Offset(0, 100));
        await tester.pump();
        await edgeGesture.up();
        await tester.pump();

        expect(scrubOffset, isNotNull);
        expect(scrollController.offset, greaterThan(0.0));
      });
    });
  });
}
