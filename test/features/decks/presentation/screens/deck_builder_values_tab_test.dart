import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/settings_state.dart';
import 'package:countr/features/decks/data/mock_deck_data.dart';
import 'package:countr/features/decks/domain/models/deck_item_with_card.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/decks/presentation/screens/deck_builder_screen.dart';
import 'package:countr/features/decks/presentation/widgets/proportional_bubble_scrollbar.dart';
import 'package:countr/features/values/presentation/widgets/locked_values_view.dart';
import 'package:countr/features/values/presentation/widgets/pareto_distribution_widget.dart';
import '../../deck_test_helpers.dart';

void main() {
  final testDeck = createTestDeck(
    id: 'deck-edgar-markov',
    name: 'Edgar Markov Aristocrats',
    format: 'Commander',
    createdAt: DateTime.now(),
    wins: 14,
    losses: 6,
    draws: 1,
  );

  final List<Map<String, dynamic>> mockItems = MockDeckData.getDeckItems(testDeck.id)
      .map<Map<String, dynamic>>(DeckItemWithCard.fromMap)
      .toList();

  Widget createSubject({
    required Deck deck,
    bool isPrivacyMode = false,
  }) {
    return ProviderScope(
      overrides: [
        deckItemsProvider(deck.id).overrideWith(
          (ref) => Stream.value(mockItems),
        ),
        privacyModeProvider.overrideWith((ref) => isPrivacyMode),
      ],
      child: MaterialApp(
        home: DeckBuilderScreen(deck: deck),
      ),
    );
  }

  group('DeckBuilderScreen Values Tab Tests', () {
    testWidgets('TC-DECK-VALUES-01: Switching segmented control toggles between Details list and Values dashboard', (tester) async {
      await tester.pumpWidget(createSubject(deck: testDeck));
      await tester.pumpAndSettle();

      // Initially in Details tab
      expect(find.byType(ProportionalBubbleScrollbar), findsOneWidget);
      expect(find.byKey(const Key('deck_values_aggregate_card')), findsNothing);

      // Tap Values tab
      final valuesTab = find.byKey(const Key('deck_builder_tab_values'));
      expect(valuesTab, findsOneWidget);
      await tester.tap(valuesTab);
      await tester.pumpAndSettle();

      // Now in Values tab
      expect(find.byKey(const Key('deck_values_aggregate_card')), findsOneWidget);
      expect(find.byType(ProportionalBubbleScrollbar), findsNothing);

      // Switch back to Details tab
      final detailsTab = find.byKey(const Key('deck_builder_tab_details'));
      expect(detailsTab, findsOneWidget);
      await tester.tap(detailsTab);
      await tester.pumpAndSettle();

      expect(find.byType(ProportionalBubbleScrollbar), findsOneWidget);
      expect(find.byKey(const Key('deck_values_aggregate_card')), findsNothing);
    });

    testWidgets('TC-DECK-VALUES-02: Values tab shows aggregate P&L summary and zone valuation breakdowns', (tester) async {
      tester.view.physicalSize = const Size(600, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createSubject(deck: testDeck));
      await tester.pumpAndSettle();

      // Tap Values tab
      await tester.tap(find.byKey(const Key('deck_builder_tab_values')));
      await tester.pumpAndSettle();

      // Aggregate valuation card elements
      expect(find.text('AGGREGATE DECK VALUATION'), findsOneWidget);
      expect(find.text('TOTAL COST BASIS'), findsOneWidget);
      expect(find.text('TOTAL CARDS'), findsOneWidget);

      // Zone Breakdown header and rows
      expect(find.text('VALUATION BY ZONE'), findsOneWidget);
      expect(find.text('Commander'), findsWidgets);
    });

    testWidgets('TC-DECK-VALUES-03: Shows LockedValuesView when privacy mode is active', (tester) async {
      await tester.pumpWidget(createSubject(deck: testDeck, isPrivacyMode: true));
      await tester.pumpAndSettle();

      // Tap Values tab
      await tester.tap(find.byKey(const Key('deck_builder_tab_values')));
      await tester.pumpAndSettle();

      // Should show LockedValuesView
      expect(find.byType(LockedValuesView), findsOneWidget);
      expect(find.byKey(const Key('deck_builder_values_locked_container')), findsOneWidget);
      expect(find.byKey(const Key('deck_values_aggregate_card')), findsNothing);
    });

    testWidgets('TC-DECK-VALUES-04: ParetoDistributionWidget is mounted and displays top cards', (tester) async {
      await tester.pumpWidget(createSubject(deck: testDeck));
      await tester.pumpAndSettle();

      // Switch to Values tab
      await tester.tap(find.byKey(const Key('deck_builder_tab_values')));
      await tester.pumpAndSettle();

      // Verify ParetoDistributionWidget is mounted
      expect(find.byType(ParetoDistributionWidget), findsOneWidget);
      expect(find.byKey(const Key('pareto_distribution_widget')), findsOneWidget);
    });
  });
}
