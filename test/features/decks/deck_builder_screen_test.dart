import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'deck_test_helpers.dart';
import 'package:countr/features/decks/data/mock_deck_data.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/decks/presentation/screens/deck_builder_screen.dart';
import 'package:countr/features/decks/presentation/screens/decks_screen.dart';
import 'package:countr/core/cache/countr_cached_image.dart';
import 'package:countr/features/decks/domain/models/deck_summary.dart';
import 'package:countr/features/decks/presentation/widgets/proportional_bubble_scrollbar.dart';
import 'package:countr/features/decks/presentation/widgets/inline_deck_analytics_card.dart';

void main() {
  final testDeck = createTestDeck(
    id: 'deck-edgar-markov',
    name: 'Edgar Markov Aristocrats Long Name That Could Overflow',
    format: 'MTG Commander',
    createdAt: DateTime.now(),
    wins: 14,
    losses: 6,
    draws: 1,
  );

  Widget createSubject({required Deck deck}) {
    return ProviderScope(
      overrides: [
        deckItemsProvider(deck.id).overrideWith(
          (ref) => Stream.value(MockDeckData.getDeckItems(deck.id)),
        ),
      ],
      child: MaterialApp(
        home: DeckBuilderScreen(deck: deck),
      ),
    );
  }

  group('DeckBuilderScreen UI & Interaction Tests', () {
    testWidgets('Renders on narrow viewport (360x640) without RenderFlex overflow in SliverAppBar', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createSubject(deck: testDeck));
      await tester.pumpAndSettle();

      // Verify zero layout overflow exceptions
      expect(tester.takeException(), isNull);

      // Verify title is rendered (ellipsized safely inside ConstrainedBox / Flexible)
      expect(find.text(testDeck.name), findsOneWidget);
      expect(find.text('W:14 L:6'), findsOneWidget);

      // Verify card list renders cards
      expect(find.text('Edgar Markov'), findsOneWidget);
      expect(find.byType(ProportionalBubbleScrollbar), findsOneWidget);
    });

    group('Feature 15 Empirical Challenge: SliverAppBar Collapse Bounds', () {
      final testWidths = [320.0, 360.0, 400.0, 414.0];

      for (final width in testWidths) {
        testWidgets('Title bounds never overlap x < 56.0 or x > width - 144.0 when collapsed (w=${width.toInt()})', (tester) async {
          tester.view.physicalSize = Size(width, 800);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          // Pushed route scenario where leading back button exists (hasLeading = true)
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                deckItemsProvider(testDeck.id).overrideWith(
                  (ref) => Stream.value(MockDeckData.getDeckItems(testDeck.id)),
                ),
              ],
              child: MaterialApp(
                home: Navigator(
                  onGenerateRoute: (settings) => MaterialPageRoute(
                    builder: (_) => DeckBuilderScreen(deck: testDeck),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final scrollableFinder = find.byType(CustomScrollView);
          expect(scrollableFinder, findsOneWidget);

          // Scroll to collapse the SliverAppBar completely
          await tester.drag(scrollableFinder, const Offset(0, -300));
          await tester.pumpAndSettle();

          final titleTextFinder = find.text(testDeck.name);
          expect(titleTextFinder, findsOneWidget);

          final Rect titleRect = tester.getRect(titleTextFinder);

          // Assert that title bounds never overlap x < 56.0 or x > constraints.maxWidth - 144.0
          expect(
            titleRect.left,
            greaterThanOrEqualTo(56.0 - 0.01),
            reason: 'Collapsed title left edge (${titleRect.left}) must not overlap leading back button (x < 56.0) on w=$width',
          );
          expect(
            titleRect.right,
            lessThanOrEqualTo(width - 144.0 + 0.01),
            reason: 'Collapsed title right edge (${titleRect.right}) must not overlap trailing action buttons (x > ${width - 144.0}) on w=$width',
          );
          expect(tester.takeException(), isNull);
        });
      }
    });

    testWidgets('Fast-Draw 7 Playtester opens, displays 7 cards, hand stats, and reshuffles on Mulligan', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createSubject(deck: testDeck));
      await tester.pumpAndSettle();

      // Tap Fast-Draw icon in SliverAppBar actions
      final fastDrawButton = find.byIcon(Icons.style_rounded);
      expect(fastDrawButton, findsOneWidget);
      await tester.tap(fastDrawButton);
      await tester.pumpAndSettle();

      // Verify Playtester sheet is presented
      expect(find.text('Opening 7 Playtester'), findsOneWidget);
      expect(find.text('Lands'), findsWidgets);
      expect(find.text('Spells'), findsWidgets);
      expect(find.text('Avg CMC'), findsOneWidget);

      // Verify Mulligan button exists and tapping it re-deals without errors
      final mulliganButton = find.text('Mulligan (Draw New 7)');
      expect(mulliganButton, findsOneWidget);

      await tester.tap(mulliganButton);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Opening 7 Playtester'), findsOneWidget);

      // Close bottom sheet
      await tester.tap(find.byIcon(Icons.close).last);
      await tester.pumpAndSettle();
      expect(find.text('Opening 7 Playtester'), findsNothing);
    });

    testWidgets('Inline Deck Analytics displays Mana Curve, Color Devotion pips, and Bling meter without modal', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createSubject(deck: testDeck));
      await tester.pumpAndSettle();

      // Verify Modal button and modal sheet are removed
      expect(find.byKey(const Key('inline_analytics_expand_modal_button')), findsNothing);
      expect(find.text('Deck Visual Analytics'), findsNothing);

      // Expand inline analytics card
      final toggleButton = find.byKey(const Key('inline_analytics_collapse_toggle'));
      expect(toggleButton, findsOneWidget);
      await tester.tap(toggleButton);
      await tester.pumpAndSettle();

      // Verify charts are presented directly inline
      expect(find.byType(ManaCurveChartWidget), findsOneWidget);
      expect(find.byType(ColorDevotionPipsWidget), findsOneWidget);
      expect(find.byType(BlingMeterWidget), findsOneWidget);
      expect(find.text('Mana Curve'), findsOneWidget);
      expect(find.text('Color Devotion'), findsOneWidget);
      expect(find.text('Deck Bling'), findsOneWidget);

      // Verify devotion pips W, B, R exist
      expect(find.text('W'), findsWidgets);
      expect(find.text('B'), findsWidgets);
      expect(find.text('R'), findsWidgets);
    });

    testWidgets('DecksScreen subheader tabs scroll horizontally on narrow viewports without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
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

      // Verify zero horizontal RenderFlex overflow
      expect(tester.takeException(), isNull);
      expect(find.text('All Decks (6)'), findsOneWidget);
      expect(find.text('Competitive'), findsOneWidget);
      expect(find.text('Draft / In-Progress'), findsOneWidget);
    });
  });

  group('Milestone 1: Navigation PopScope & Cover Art Resolution', () {
    testWidgets('Physical system back button (handlePopRoute) cleanly pops DeckBuilderScreen', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deckItemsProvider(testDeck.id).overrideWith(
              (ref) => Stream.value(MockDeckData.getDeckItems(testDeck.id)),
            ),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute(
                        builder: (_) => DeckBuilderScreen(deck: testDeck),
                      ),
                    );
                  },
                  child: const Text('Open Deck'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Deck'));
      await tester.pumpAndSettle();

      expect(find.byType(DeckBuilderScreen), findsOneWidget);

      final didPop = await tester.binding.handlePopRoute();
      expect(didPop, isTrue);
      await tester.pumpAndSettle();

      expect(find.byType(DeckBuilderScreen), findsNothing);
      expect(find.text('Open Deck'), findsOneWidget);
    });

    testWidgets('AppBar leading back button cleanly pops DeckBuilderScreen', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deckItemsProvider(testDeck.id).overrideWith(
              (ref) => Stream.value(MockDeckData.getDeckItems(testDeck.id)),
            ),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute(
                        builder: (_) => DeckBuilderScreen(deck: testDeck),
                      ),
                    );
                  },
                  child: const Text('Open Deck'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Deck'));
      await tester.pumpAndSettle();

      expect(find.byType(DeckBuilderScreen), findsOneWidget);

      final backButton = find.byIcon(Icons.arrow_back);
      expect(backButton, findsOneWidget);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      expect(find.byType(DeckBuilderScreen), findsNothing);
      expect(find.text('Open Deck'), findsOneWidget);
    });

    testWidgets('Custom coverItemId takes highest priority over default commander art in sliver header', (tester) async {
      final deckWithCustomCover = createTestDeck(
        id: 'deck-custom-cover-test',
        name: 'Custom Cover Deck',
        coverItemId: 'custom-cover-card-id',
      );

      final commanderItem = {
        'id': 'dvi-commander',
        'vault_item_id': 'commander-card-id',
        'name': 'Default Commander',
        'image_url': 'https://cards.scryfall.io/art_crop/commander.jpg',
        'dynamic_data': '{"image_uris":{"art_crop":"https://cards.scryfall.io/art_crop/commander.jpg"}}',
        'board_zone': 'Commander',
      };

      final customCoverItem = {
        'id': 'dvi-custom',
        'vault_item_id': 'custom-cover-card-id',
        'name': 'Custom Cover Art Card',
        'image_url': 'https://cards.scryfall.io/art_crop/custom_cover.jpg',
        'dynamic_data': '{"image_uris":{"art_crop":"https://cards.scryfall.io/art_crop/custom_cover.jpg"}}',
        'board_zone': 'Mainboard',
      };

      final mockSummary = DeckSummary(
        id: deckWithCustomCover.id,
        name: deckWithCustomCover.name,
        format: 'Commander',
        tcgDomain: 'mtg',
        isRegistered: false,
        isCompetitive: false,
        createdAt: DateTime.now(),
        commanderCardId: 'commander-card-id',
        commanderName: 'Default Commander',
        commanderArtCrop: 'https://cards.scryfall.io/art_crop/commander.jpg',
        commanderImageUrl: 'https://cards.scryfall.io/art_crop/commander.jpg',
        cardCount: 2,
        targetCardCount: 100,
        completeness: 0.02,
        assemblyStatus: 'Draft',
        deck: deckWithCustomCover,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deckProvider(deckWithCustomCover.id).overrideWith(
              (ref) => Stream.value(deckWithCustomCover),
            ),
            deckSummariesProvider.overrideWith(
              (ref) => Stream.value([mockSummary]),
            ),
            deckItemsProvider(deckWithCustomCover.id).overrideWith(
              (ref) => Stream.value([commanderItem, customCoverItem]),
            ),
          ],
          child: MaterialApp(
            home: DeckBuilderScreen(deck: deckWithCustomCover),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final headerImages = tester.widgetList<CountrCachedImage>(find.byType(CountrCachedImage)).where(
        (img) => img.cacheKey == 'deck_cover_${deckWithCustomCover.id}_${deckWithCustomCover.coverItemId}',
      ).toList();

      expect(headerImages.isNotEmpty, isTrue);
      final coverWidget = headerImages.first;
      expect(coverWidget.imageUrl, equals('https://cards.scryfall.io/art_crop/custom_cover.jpg'));
      expect(coverWidget.cacheKey, equals('deck_cover_deck-custom-cover-test_custom-cover-card-id'));
      expect(coverWidget.key, equals(const ValueKey('deck_cover_deck-custom-cover-test_custom-cover-card-id')));
    });

    testWidgets('Header cover art uses deck_cover_deckId when coverItemId is null', (tester) async {
      final defaultCoverDeck = createTestDeck(
        id: 'deck-default-cover-test',
        name: 'Default Cover Deck',
        coverItemId: null,
      );

      final commanderItem = {
        'id': 'dvi-comm',
        'vault_item_id': 'card-comm',
        'name': 'Commander Card',
        'image_url': 'https://cards.scryfall.io/art_crop/comm.jpg',
        'dynamic_data': '{"image_uris":{"art_crop":"https://cards.scryfall.io/art_crop/comm.jpg"}}',
        'board_zone': 'Commander',
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deckProvider(defaultCoverDeck.id).overrideWith(
              (ref) => Stream.value(defaultCoverDeck),
            ),
            deckItemsProvider(defaultCoverDeck.id).overrideWith(
              (ref) => Stream.value([commanderItem]),
            ),
          ],
          child: MaterialApp(
            home: DeckBuilderScreen(deck: defaultCoverDeck),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final headerImages = tester.widgetList<CountrCachedImage>(find.byType(CountrCachedImage)).where(
        (img) => img.cacheKey == 'deck_cover_${defaultCoverDeck.id}',
      ).toList();

      expect(headerImages.isNotEmpty, isTrue);
      final coverWidget = headerImages.first;
      expect(coverWidget.imageUrl, equals('https://cards.scryfall.io/art_crop/comm.jpg'));
      expect(coverWidget.cacheKey, equals('deck_cover_deck-default-cover-test'));
      expect(coverWidget.key, equals(const ValueKey('deck_cover_deck-default-cover-test')));
    });
  });
}
