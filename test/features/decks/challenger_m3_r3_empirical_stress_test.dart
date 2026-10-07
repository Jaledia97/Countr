import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/data/mock_deck_data.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/decks/presentation/screens/deck_builder_screen.dart';
import 'package:countr/features/decks/presentation/screens/decks_screen.dart';
import 'package:countr/features/decks/presentation/widgets/deck_setup_wizard_modal.dart';
import 'package:countr/features/decks/presentation/widgets/deck_thumbnail_picker_modal.dart';
import 'package:countr/features/decks/presentation/widgets/inline_deck_analytics_card.dart';
import 'package:countr/features/decks/presentation/widgets/proportional_bubble_scrollbar.dart';
import 'deck_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Challenger M3-1 Empirical Stress Suite (Requirement R3)', () {
    // =========================================================================
    // 1. DeckThumbnailPickerModal Layout Constraints & Bottom Sheet Stress
    // =========================================================================
    group('1. DeckThumbnailPickerModal Bottom Sheet & Layout Stress', () {
      testWidgets('1.1. showModalBottomSheet(isScrollControlled: true) launches without RenderFlex or unbounded height errors', (tester) async {
        final mockDeck = createTestDeck(
          id: MockDeckData.edgarMarkovDeckId,
          name: 'Edgar Markov Aristocrats',
        );

        final items = MockDeckData.getDeckItems(mockDeck.id);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              deckProvider(mockDeck.id).overrideWith((ref) => Stream.value(mockDeck)),
              deckItemsProvider(mockDeck.id).overrideWith((ref) => Stream.value(items)),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    key: const Key('trigger_picker_btn'),
                    onPressed: () => DeckThumbnailPickerModal.show(context, deck: mockDeck),
                    child: const Text('Launch Picker'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap to open bottom sheet
        await tester.tap(find.byKey(const Key('trigger_picker_btn')));
        await tester.pumpAndSettle();

        // Empirically verify no RenderFlex or unbounded height assertions
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('deck_thumbnail_picker_modal')), findsOneWidget);
        expect(find.text('Customize Deck Cover'), findsOneWidget);
        expect(find.text('Edgar Markov Aristocrats'), findsOneWidget);

        // Verify TabBar and TabBarView are rendered
        expect(find.byKey(const Key('tab_cards_in_deck')), findsOneWidget);
        expect(find.byKey(const Key('tab_search_catalog')), findsOneWidget);

        // Switch to Search Catalog tab
        await tester.tap(find.byKey(const Key('tab_search_catalog')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('deck_thumbnail_catalog_search_input')), findsOneWidget);
        expect(find.text('Type a card name to search the MTG catalog.'), findsOneWidget);

        // Enter search text
        await tester.enterText(find.byKey(const Key('deck_thumbnail_catalog_search_input')), 'Sol Ring');
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();

        // Dismiss modal cleanly
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('deck_thumbnail_picker_modal')), findsNothing);
      });

      testWidgets('1.2. Picker survives narrow (320x480) viewport + 1.5x font scale + keyboard inset (250dp) without overflow', (tester) async {
        tester.view.physicalSize = const Size(320, 480);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final mockDeck = createTestDeck(
          id: MockDeckData.edgarMarkovDeckId,
          name: 'Edgar Markov Narrow Screen',
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              deckProvider(mockDeck.id).overrideWith((ref) => Stream.value(mockDeck)),
              deckItemsProvider(mockDeck.id).overrideWith((ref) => Stream.value([])),
            ],
            child: MaterialApp(
              home: MediaQuery(
                data: const MediaQueryData(
                  size: Size(320, 480),
                  textScaler: TextScaler.linear(1.5),
                  viewInsets: EdgeInsets.only(bottom: 250),
                ),
                child: Scaffold(
                  body: Builder(
                    builder: (context) => ElevatedButton(
                      key: const Key('open_narrow_btn'),
                      onPressed: () => DeckThumbnailPickerModal.show(context, deck: mockDeck),
                      child: const Text('Open'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('open_narrow_btn')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('deck_thumbnail_picker_modal')), findsOneWidget);
        expect(find.text('Customize Deck Cover'), findsOneWidget);

        // Close modal
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();
      });

      testWidgets('1.3. Opening picker directly from DeckBuilderScreen cover art button functions without crash', (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final testDeck = createTestDeck(
          id: MockDeckData.edgarMarkovDeckId,
          name: 'Edgar Markov Aristocrats',
        );

        final items = MockDeckData.getDeckItems(testDeck.id);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              deckProvider(testDeck.id).overrideWith((ref) => Stream.value(testDeck)),
              deckItemsProvider(testDeck.id).overrideWith((ref) => Stream.value(items)),
            ],
            child: MaterialApp(
              home: DeckBuilderScreen(deck: testDeck),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Find Cover Art button in SliverAppBar
        final coverArtButton = find.byKey(const Key('deck_thumbnail_picker_button'));
        expect(coverArtButton, findsOneWidget);
        await tester.tap(coverArtButton);
        await tester.pumpAndSettle();

        // Verify modal appears
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('deck_thumbnail_picker_modal')), findsOneWidget);

        // Close modal
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('deck_thumbnail_picker_modal')), findsNothing);
      });

      testWidgets('1.4. Picker inside UnconstrainedBox survives unbounded vertical incoming constraints', (tester) async {
        final mockDeck = createTestDeck(
          id: MockDeckData.edgarMarkovDeckId,
          name: 'Unconstrained Stress Deck',
          coverItemId: 'edgar-markov',
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              deckProvider(mockDeck.id).overrideWith((ref) => Stream.value(mockDeck)),
              deckItemsProvider(mockDeck.id).overrideWith((ref) => Stream.value([])),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: DeckThumbnailPickerModal(deck: mockDeck),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('deck_thumbnail_picker_modal')), findsOneWidget);
        // Reset button is visible because coverItemId is set
        expect(find.byKey(const Key('reset_deck_cover_button')), findsOneWidget);
      });
    });

    // =========================================================================
    // 2. Oracle Rules Text Integrity (Mock Deck Data & SQLite Vault DAO)
    // =========================================================================
    group('2. Oracle Rules Text Integrity across Mock & DB', () {
      test('2.1. MockDeckData items contain authentic Scryfall rules text for key cards', () {
        final items = MockDeckData.getDeckItems(MockDeckData.edgarMarkovDeckId);

        // 1. Edgar Markov
        final edgar = items.firstWhere((i) => i['id'] == 'edgar-markov');
        final edgarDyn = jsonDecode(edgar['dynamic_data'] as String) as Map<String, dynamic>;
        final edgarOracle = edgarDyn['oracle_text'] as String?;
        expect(edgarOracle, isNotNull);
        expect(edgarOracle, contains('Eminence — As long as Edgar Markov is in the command zone or on the battlefield, whenever you cast another Vampire spell, create a 1/1 black Vampire creature token.'));
        expect(edgarOracle, contains('First strike, haste'));
        expect(edgarOracle, contains('Whenever Edgar Markov attacks, put a +1/+1 counter on each Vampire you control.'));

        // 2. Blood Artist
        final artist = items.firstWhere((i) => i['id'] == 'blood-artist');
        final artistDyn = jsonDecode(artist['dynamic_data'] as String) as Map<String, dynamic>;
        final artistOracle = artistDyn['oracle_text'] as String?;
        expect(artistOracle, isNotNull);
        expect(artistOracle, contains('Whenever Blood Artist or another creature dies, target player loses 1 life and you gain 1 life.'));

        // 3. Sol Ring
        final sol = items.firstWhere((i) => i['id'] == 'sol-ring');
        final solDyn = jsonDecode(sol['dynamic_data'] as String) as Map<String, dynamic>;
        expect(solDyn['oracle_text'], equals('{T}: Add {C}{C}.'));

        // 4. Command Tower
        final tower = items.firstWhere((i) => i['id'] == 'command-tower');
        final towerDyn = jsonDecode(tower['dynamic_data'] as String) as Map<String, dynamic>;
        expect(towerDyn['oracle_text'], contains("Add one mana of any color in your commander's color identity."));

        // 5. Teferi's Protection
        final teferi = items.firstWhere((i) => i['id'] == 'teferis-protection');
        final teferiDyn = jsonDecode(teferi['dynamic_data'] as String) as Map<String, dynamic>;
        expect(teferiDyn['oracle_text'], contains('your life total can\'t change and you gain protection from everything. All permanents you control phase out.'));
      });

      test('2.2. VaultDao seeded records in SQLite database contain authentic Oracle rules text', () async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(() => db.close());

        // Run starter seed
        await db.vaultDao.seedDatabase();

        // 1. Verify Edgar Markov in vault_items
        final edgarItem = await (db.select(db.vaultItems)..where((t) => t.id.equals('edgar-markov'))).getSingleOrNull();
        expect(edgarItem, isNotNull);
        expect(edgarItem!.dynamicData, isNotNull);
        final edgarData = jsonDecode(edgarItem.dynamicData!) as Map<String, dynamic>;
        expect(edgarData['oracle_text'], isNotNull);
        expect(edgarData['oracle_text'], contains('Eminence — As long as Edgar Markov is in the command zone'));
        expect(edgarData['oracle_text'], contains('First strike, haste'));
        expect(edgarData['oracle_text'], contains('Whenever Edgar Markov attacks, put a +1/+1 counter on each Vampire you control.'));
        expect(edgarData['power'], equals('4'));
        expect(edgarData['toughness'], equals('4'));

        // 2. Verify Yuriko, the Tiger's Shadow
        final yurikoItem = await (db.select(db.vaultItems)..where((t) => t.id.equals('card-yuriko'))).getSingleOrNull();
        expect(yurikoItem, isNotNull);
        final yurikoData = jsonDecode(yurikoItem!.dynamicData!) as Map<String, dynamic>;
        expect(yurikoData['oracle_text'], contains('Commander ninjutsu {U}{B}'));

        // 3. Verify Karn Liberated (card-tron)
        final tronItem = await (db.select(db.vaultItems)..where((t) => t.id.equals('card-tron'))).getSingleOrNull();
        expect(tronItem, isNotNull);
        expect(tronItem!.name, equals('Karn Liberated'));
        final tronData = jsonDecode(tronItem.dynamicData!) as Map<String, dynamic>;
        expect(tronData['oracle_text'], contains('Target player exiles a card from their hand.'));
        expect(tronData['oracle_text'], contains('Exile target permanent.'));
        expect(tronData['loyalty'], equals('6'));

        // 4. Verify The One Ring
        final ringItem = await (db.select(db.vaultItems)..where((t) => t.id.equals('item-mtg-one-ring'))).getSingleOrNull();
        expect(ringItem, isNotNull);
        final ringData = jsonDecode(ringItem!.dynamicData!) as Map<String, dynamic>;
        expect(ringData['oracle_text'], contains('Indestructible'));
        expect(ringData['oracle_text'], contains('gain protection from everything until your next turn.'));
        expect(ringData['oracle_text'], contains('burden counter on The One Ring'));
      });

      test('2.3. Exhaustive check of all seeded MTG cards in SQLite for populated oracle_text', () async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(() => db.close());

        await db.vaultDao.seedDatabase();

        final allItems = await (db.select(db.vaultItems)
              ..where((t) => t.collectionType.equals('mtg'))
              ..where((t) => t.isDeleted.equals(false)))
            .get();

        expect(allItems.length, greaterThanOrEqualTo(10));

        for (final item in allItems) {
          expect(item.dynamicData, isNotNull, reason: 'Card ${item.name} (${item.id}) dynamicData must not be null');
          final dyn = jsonDecode(item.dynamicData!) as Map<String, dynamic>;
          final oracle = dyn['oracle_text'] as String?;
          expect(oracle, isNotNull, reason: 'Card ${item.name} (${item.id}) oracle_text must not be null');
          expect(oracle!.trim().isNotEmpty, isTrue, reason: 'Card ${item.name} (${item.id}) oracle_text must not be empty');
        }
      });
    });

    // =========================================================================
    // 3. Floating Action Button (decks_new_deck_fab) & Wizard Presentation
    // =========================================================================
    group('3. Floating Action Button (decks_new_deck_fab) Wiring', () {
      testWidgets('3.1. Tapping FAB launches DeckSetupWizardModal with preselected domain', (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: DecksScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final fabFinder = find.byKey(const Key('decks_new_deck_fab'));
        expect(fabFinder, findsOneWidget);
        expect(find.text('New Deck'), findsOneWidget);

        // Tap FAB
        await tester.tap(fabFinder);
        await tester.pumpAndSettle();

        // DeckSetupWizardModal must appear
        expect(find.byType(DeckSetupWizardModal), findsOneWidget);
        expect(find.text('New Deck Setup'), findsOneWidget);
        expect(find.text('FORMAT'), findsOneWidget);
        expect(find.text('Commander'), findsOneWidget);

        // Close wizard modal
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();
        expect(find.byType(DeckSetupWizardModal), findsNothing);
      });

      testWidgets('3.2. FAB launches wizard with domain-specific formats when switching TCG filters', (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: DecksScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final fabFinder = find.byKey(const Key('decks_new_deck_fab'));

        // 1. Switch to Pokémon
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

        // 2. Switch to Lorcana
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
      });
    });

    // =========================================================================
    // 4. App Bar Actions & Inline Deck Analytics User Notes Container
    // =========================================================================
    group('4. App Bar Actions & Inline Analytics User Notes', () {
      testWidgets('4.1. Top SliverAppBar does NOT contain analytics icon button', (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final testDeck = createTestDeck(
          id: MockDeckData.edgarMarkovDeckId,
          name: 'Edgar Markov Aristocrats',
        );

        final items = MockDeckData.getDeckItems(testDeck.id);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              deckProvider(testDeck.id).overrideWith((ref) => Stream.value(testDeck)),
              deckItemsProvider(testDeck.id).overrideWith((ref) => Stream.value(items)),
            ],
            child: MaterialApp(
              home: DeckBuilderScreen(deck: testDeck),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify SliverAppBar actions: Icons.analytics_rounded MUST NOT be in the app bar
        final appBars = find.byType(SliverAppBar);
        expect(appBars, findsOneWidget);

        final analyticsIconInAppBar = find.descendant(
          of: appBars,
          matching: find.byIcon(Icons.analytics_rounded),
        );
        expect(analyticsIconInAppBar, findsNothing, reason: 'Redundant analytics icon button should be removed from app bar');

        // Fast-Draw and More Actions buttons should exist in SliverAppBar actions
        expect(find.byIcon(Icons.style_rounded), findsOneWidget);
        expect(find.byIcon(Icons.more_vert), findsOneWidget);
      });

      testWidgets('4.2. InlineDeckAnalyticsCard renders User Notes container with deck description when expanded', (tester) async {
        final sampleAnalytics = MockDeckData.computeAnalyticsFromItems(
          MockDeckData.getDeckItems(MockDeckData.edgarMarkovDeckId),
        );

        const customNotes = 'Aristocrats strategy: sacrifice vampire tokens to Blood Artist, draining opponents repeatedly.';

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: InlineDeckAnalyticsCard(
                  analytics: sampleAnalytics,
                  isExpanded: true,
                  onToggleExpand: () {},
                  userNotes: customNotes,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify User Notes section header and container
        expect(find.text('User Notes'), findsOneWidget);
        final notesContainer = find.byKey(const Key('inline_analytics_user_notes_container'));
        expect(notesContainer, findsOneWidget);
        expect(find.text(customNotes), findsOneWidget);
      });

      testWidgets('4.3. InlineDeckAnalyticsCard renders fallback italic text when userNotes is null or empty', (tester) async {
        final sampleAnalytics = MockDeckData.computeAnalyticsFromItems(
          MockDeckData.getDeckItems(MockDeckData.edgarMarkovDeckId),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: InlineDeckAnalyticsCard(
                  analytics: sampleAnalytics,
                  isExpanded: true,
                  onToggleExpand: () {},
                  userNotes: null,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('inline_analytics_user_notes_container')), findsOneWidget);
        expect(
          find.text('No notes added for this deck yet. Open "Deck Details & Notes" to edit primer and strategy.'),
          findsOneWidget,
        );
      });

      testWidgets('4.4. InlineDeckAnalyticsCard renders huge 3,000 char primer notes without overflow', (tester) async {
        final sampleAnalytics = MockDeckData.computeAnalyticsFromItems(
          MockDeckData.getDeckItems(MockDeckData.edgarMarkovDeckId),
        );

        final hugeNotes = List.generate(50, (i) => 'Line $i: Detailed strategic decision point for Edgar Markov token recursion.').join('\n');

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: InlineDeckAnalyticsCard(
                  analytics: sampleAnalytics,
                  isExpanded: true,
                  onToggleExpand: () {},
                  userNotes: hugeNotes,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('inline_analytics_user_notes_container')), findsOneWidget);
        expect(find.text(hugeNotes), findsOneWidget);
      });
    });

    // =========================================================================
    // 5. ProportionalBubbleScrollbar 5dp Spine Thickness & Geometry
    // =========================================================================
    group('5. ProportionalBubbleScrollbar 5dp Spine Thickness', () {
      testWidgets('5.1. Rail track spine is rendered with exactly 5.0 dp width and centered horizontally', (tester) async {
        const double railWidth = 26.0;
        final sections = [
          ScrollbarSection(label: 'Commander', count: 1, onTap: () {}),
          ScrollbarSection(label: 'Creatures', count: 32, onTap: () {}),
          ScrollbarSection(label: 'Lands', count: 35, onTap: () {}),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 500,
                width: 60,
                child: ProportionalBubbleScrollbar(
                  sections: sections,
                  railWidth: railWidth,
                  railColor: Colors.grey,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        // Find the Positioned widget representing the rail spine
        final positionedFinder = find.byWidgetPredicate((widget) {
          if (widget is Positioned) {
            return widget.width == 5.0 &&
                widget.top == 0 &&
                widget.bottom == 0 &&
                widget.left == (railWidth - 5.0) / 2;
          }
          return false;
        });
        expect(positionedFinder, findsOneWidget, reason: 'Rail spine must be centered with width 5.0dp');

        // Check spine decoration borderRadius
        final decoratedBoxFinder = find.descendant(
          of: positionedFinder,
          matching: find.byType(DecoratedBox),
        );
        expect(decoratedBoxFinder, findsOneWidget);
        final decoratedBox = tester.widget<DecoratedBox>(decoratedBoxFinder);
        final boxDecoration = decoratedBox.decoration as BoxDecoration;
        expect(boxDecoration.borderRadius, equals(BorderRadius.circular(2.5)));
      });

      testWidgets('5.2. Rail spine maintains 5.0 dp width and centers across various railWidth configurations', (tester) async {
        for (final double customRailWidth in [16.0, 30.0, 42.0]) {
          final sections = [
            ScrollbarSection(label: 'Spells', count: 20, onTap: () {}),
          ];

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  height: 300,
                  width: customRailWidth + 10,
                  child: ProportionalBubbleScrollbar(
                    sections: sections,
                    railWidth: customRailWidth,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final expectedLeft = (customRailWidth - 5.0) / 2;
          final spineFinder = find.byWidgetPredicate((widget) {
            return widget is Positioned &&
                widget.width == 5.0 &&
                widget.left == expectedLeft;
          });
          expect(spineFinder, findsOneWidget);
        }
      });
    });
  });
}
