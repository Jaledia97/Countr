import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/data/mock_deck_data.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/decks/presentation/screens/deck_builder_screen.dart';
import 'package:countr/features/decks/presentation/widgets/inline_deck_analytics_card.dart';
import 'deck_test_helpers.dart';

void main() {
  final testDeck = createTestDeck(
    id: MockDeckData.edgarMarkovDeckId,
    name: 'Edgar Markov Aristocrats',
    format: 'MTG Commander',
    createdAt: DateTime.now(),
    wins: 10,
    losses: 4,
  );

  Widget createSubject({required Deck deck, List<Map<String, dynamic>>? customItems}) {
    return ProviderScope(
      overrides: [
        deckItemsProvider(deck.id).overrideWith(
          (ref) => Stream.value(customItems ?? MockDeckData.getDeckItems(deck.id)),
        ),
      ],
      child: MaterialApp(
        home: DeckBuilderScreen(deck: deck),
      ),
    );
  }

  group('InlineDeckAnalyticsCard Component Unit Tests', () {
    testWidgets('Renders collapsed state with compact summary and responds to callbacks', (tester) async {
      bool toggleCalled = false;
      bool modalCalled = false;

      final sampleAnalytics = MockDeckData.computeAnalyticsFromItems(
        MockDeckData.getDeckItems(MockDeckData.edgarMarkovDeckId),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InlineDeckAnalyticsCard(
              analytics: sampleAnalytics,
              isExpanded: false,
              onToggleExpand: () => toggleCalled = true,
              onOpenModal: () => modalCalled = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Card header should exist
      expect(find.byKey(const Key('deck_builder_inline_analytics_card')), findsOneWidget);
      expect(find.text('Deck Analytics'), findsOneWidget);

      // Detailed sections should be hidden when collapsed
      expect(find.byType(ManaCurveChartWidget), findsNothing);
      expect(find.byType(ColorDevotionPipsWidget), findsNothing);
      expect(find.byType(BlingMeterWidget), findsNothing);

      // Tap toggle button
      await tester.tap(find.byKey(const Key('inline_analytics_collapse_toggle')));
      expect(toggleCalled, isTrue);

      // Tap modal button
      await tester.tap(find.byKey(const Key('inline_analytics_expand_modal_button')));
      expect(modalCalled, isTrue);
    });

    testWidgets('Renders expanded state with Mana Curve, Color Devotion, and Bling meter', (tester) async {
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
                onOpenModal: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // All charts, user notes, and titles should be present
      expect(find.byType(ManaCurveChartWidget), findsOneWidget);
      expect(find.byType(ColorDevotionPipsWidget), findsOneWidget);
      expect(find.byType(BlingMeterWidget), findsOneWidget);
      expect(find.text('Mana Curve'), findsOneWidget);
      expect(find.text('Color Devotion'), findsOneWidget);
      expect(find.text('Deck Bling'), findsOneWidget);
      expect(find.text('User Notes'), findsOneWidget);
      expect(find.byKey(const Key('inline_analytics_user_notes_container')), findsOneWidget);
    });

    testWidgets('Renders custom userNotes in User Notes container when provided', (tester) async {
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
                onOpenModal: () {},
                userNotes: 'Aggro strategy: curve out vampires early and drain.',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('User Notes'), findsOneWidget);
      expect(find.byKey(const Key('inline_analytics_user_notes_container')), findsOneWidget);
      expect(find.text('Aggro strategy: curve out vampires early and drain.'), findsOneWidget);
    });
  });

  group('DeckBuilderScreen Inline Analytics Integration Tests', () {
    testWidgets('Embeds inline card and anchor chip when deck has cards', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createSubject(deck: testDeck));
      await tester.pumpAndSettle();

      // Verify anchor chip is rendered
      final anchorChip = find.byKey(const Key('deck_builder_anchor_analytics_chip'));
      expect(anchorChip, findsOneWidget);
      expect(find.text('Jump to Analytics'), findsOneWidget);

      // Verify inline card is rendered
      final inlineCard = find.byKey(const Key('deck_builder_inline_analytics_card'));
      expect(inlineCard, findsOneWidget);

      // Initially collapsed, toggle it to expand
      final toggleButton = find.byKey(const Key('inline_analytics_collapse_toggle'));
      expect(toggleButton, findsOneWidget);
      await tester.tap(toggleButton);
      await tester.pumpAndSettle();

      // After expanding, Mana Curve and Devotion widgets appear inline
      expect(find.byType(ManaCurveChartWidget), findsOneWidget);
      expect(find.byType(ColorDevotionPipsWidget), findsOneWidget);
      expect(find.byType(BlingMeterWidget), findsOneWidget);

      // Tap modal button on inline card to launch full modal sheet
      final modalButton = find.byKey(const Key('inline_analytics_expand_modal_button'));
      expect(modalButton, findsOneWidget);
      await tester.tap(modalButton);
      await tester.pumpAndSettle();

      // Verify modal bottom sheet is open
      expect(find.text('Deck Visual Analytics'), findsOneWidget);
      expect(find.text('Mana Curve (CMC 0 to 7+)'), findsOneWidget);

      // Close modal
      await tester.tap(find.byIcon(Icons.close).last);
      await tester.pumpAndSettle();
      expect(find.text('Deck Visual Analytics'), findsNothing);
    });

    testWidgets('Tapping anchor chip auto-expands collapsed inline analytics', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createSubject(deck: testDeck));
      await tester.pumpAndSettle();

      // Charts are initially hidden because card is collapsed
      expect(find.byType(ManaCurveChartWidget), findsNothing);

      // Tap anchor chip
      final anchorChip = find.byKey(const Key('deck_builder_anchor_analytics_chip'));
      await tester.tap(anchorChip);
      await tester.pumpAndSettle();

      // Tapping anchor chip auto-expands the card
      expect(find.byType(ManaCurveChartWidget), findsOneWidget);
      expect(find.byType(ColorDevotionPipsWidget), findsOneWidget);
    });

    testWidgets('Empty deck does not render inline analytics card or anchor chip', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final emptyDeck = createTestDeck(id: 'deck-empty-1', name: 'Empty Deck');
      await tester.pumpWidget(createSubject(deck: emptyDeck, customItems: []));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('deck_builder_anchor_analytics_chip')), findsNothing);
      expect(find.byKey(const Key('deck_builder_inline_analytics_card')), findsNothing);
      expect(find.textContaining('No cards in this deck yet'), findsOneWidget);
    });
  });
}
