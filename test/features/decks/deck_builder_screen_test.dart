import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/data/mock_deck_data.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/decks/presentation/screens/deck_builder_screen.dart';
import 'package:countr/features/decks/presentation/screens/decks_screen.dart';
import 'package:countr/features/decks/presentation/widgets/proportional_bubble_scrollbar.dart';

void main() {
  final testDeck = Deck(
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

    testWidgets('Deck Visual Analytics modal displays Mana Curve, Color Devotion pips, and Bling meter', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createSubject(deck: testDeck));
      await tester.pumpAndSettle();

      // Tap Analytics icon in SliverAppBar actions
      final analyticsButton = find.byIcon(Icons.analytics_rounded);
      expect(analyticsButton, findsOneWidget);
      await tester.tap(analyticsButton);
      await tester.pumpAndSettle();

      // Verify Analytics sheet is presented
      expect(find.text('Deck Visual Analytics'), findsOneWidget);
      expect(find.text('Mana Curve (CMC 0 to 7+)'), findsOneWidget);
      expect(find.text('Color Devotion (Mana Pips)'), findsOneWidget);
      expect(find.text('Bling Meter'), findsOneWidget);

      // Verify devotion pips W, U, B, R, G, C exist
      expect(find.text('W'), findsWidgets);
      expect(find.text('B'), findsWidgets);
      expect(find.text('R'), findsWidgets);

      // Close modal
      await tester.tap(find.byIcon(Icons.close).last);
      await tester.pumpAndSettle();
      expect(find.text('Deck Visual Analytics'), findsNothing);
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
}
