import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/features/decks/data/mock_deck_data.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/decks/presentation/screens/deck_builder_screen.dart';
import 'package:countr/features/decks/presentation/screens/decks_screen.dart';
import 'deck_test_helpers.dart';

void main() {
  final testDeck = createTestDeck(
    id: 'deck-challenger-m1-test',
    name: 'Challenger Test Deck',
    format: 'MTG Commander',
    createdAt: DateTime.now(),
    wins: 10,
    losses: 2,
    draws: 0,
  );

  Widget createTestHarness({
    required Widget child,
    List<Override> overrides = const [],
  }) {
    return ProviderScope(
      overrides: [
        deckItemsProvider(testDeck.id).overrideWith(
          (ref) => Stream.value(MockDeckData.getDeckItems(testDeck.id)),
        ),
        ...overrides,
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('M1 Adversarial Challenge: PopScope & Back Navigation Routing', () {
    testWidgets('1. Standard push: System back (handlePopRoute) cleanly pops DeckBuilderScreen without exiting app', (tester) async {
      await tester.pumpWidget(
        createTestHarness(
          child: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                key: const Key('open_deck_button'),
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
      );
      await tester.pumpAndSettle();

      // Verify parent screen is mounted
      expect(find.byKey(const Key('open_deck_button')), findsOneWidget);
      expect(find.byType(DeckBuilderScreen), findsNothing);

      // Open DeckBuilderScreen
      await tester.tap(find.byKey(const Key('open_deck_button')));
      await tester.pumpAndSettle();

      expect(find.byType(DeckBuilderScreen), findsOneWidget);

      // Trigger system back via handlePopRoute()
      final handled = await tester.binding.handlePopRoute();
      expect(handled, isTrue, reason: 'handlePopRoute must return true indicating back was intercepted and handled');
      await tester.pumpAndSettle();

      // Verify DeckBuilderScreen is popped and parent screen remains visible
      expect(find.byType(DeckBuilderScreen), findsNothing);
      expect(find.byKey(const Key('open_deck_button')), findsOneWidget);
    });

    testWidgets('2. Standard push: AppBar leading back button behaves identically to system back', (tester) async {
      await tester.pumpWidget(
        createTestHarness(
          child: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                key: const Key('open_deck_button'),
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
      );
      await tester.pumpAndSettle();

      // Open DeckBuilderScreen
      await tester.tap(find.byKey(const Key('open_deck_button')));
      await tester.pumpAndSettle();

      expect(find.byType(DeckBuilderScreen), findsOneWidget);

      // Tap AppBar leading back button
      final backButton = find.descendant(
        of: find.byType(SliverAppBar),
        matching: find.byType(IconButton),
      );
      expect(backButton, findsOneWidget);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // Verify DeckBuilderScreen is popped and parent screen is visible
      expect(find.byType(DeckBuilderScreen), findsNothing);
      expect(find.byKey(const Key('open_deck_button')), findsOneWidget);
    });

    testWidgets('3. Nested modal over DeckBuilderScreen: system back pops modal first, second back pops DeckBuilderScreen', (tester) async {
      await tester.pumpWidget(
        createTestHarness(
          child: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                key: const Key('open_deck_button'),
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
      );
      await tester.pumpAndSettle();

      // Open DeckBuilderScreen
      await tester.tap(find.byKey(const Key('open_deck_button')));
      await tester.pumpAndSettle();
      expect(find.byType(DeckBuilderScreen), findsOneWidget);

      // Open a modal bottom sheet on top of DeckBuilderScreen
      final BuildContext builderContext = tester.element(find.byType(DeckBuilderScreen));
      showModalBottomSheet(
        context: builderContext,
        builder: (_) => const Scaffold(
          body: Center(child: Text('Nested Sheet Content')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nested Sheet Content'), findsOneWidget);

      // First system back: must dismiss the bottom sheet, NOT DeckBuilderScreen
      final firstPopHandled = await tester.binding.handlePopRoute();
      expect(firstPopHandled, isTrue);
      await tester.pumpAndSettle();

      expect(find.text('Nested Sheet Content'), findsNothing);
      expect(find.byType(DeckBuilderScreen), findsOneWidget, reason: 'DeckBuilderScreen must stay active after sheet dismissal');

      // Second system back: must pop DeckBuilderScreen
      final secondPopHandled = await tester.binding.handlePopRoute();
      expect(secondPopHandled, isTrue);
      await tester.pumpAndSettle();

      expect(find.byType(DeckBuilderScreen), findsNothing);
      expect(find.byKey(const Key('open_deck_button')), findsOneWidget);
    });

    testWidgets('4. Nested Shell / Multi-Navigator hierarchy: system back cleanly pops DeckBuilderScreen to nested shell', (tester) async {
      // Simulate GoRouter ShellRoute with nested navigator inside tab scaffold
      final shellNavigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        createTestHarness(
          child: Scaffold(
            appBar: AppBar(title: const Text('Shell Root')),
            body: Navigator(
              key: shellNavigatorKey,
              onGenerateRoute: (settings) => MaterialPageRoute(
                builder: (shellContext) => Scaffold(
                  body: ElevatedButton(
                    key: const Key('open_deck_from_shell'),
                    onPressed: () {
                      // Uses rootNavigator: true as implemented in DecksScreen
                      Navigator.of(shellContext, rootNavigator: true).push(
                        MaterialPageRoute(
                          builder: (_) => DeckBuilderScreen(deck: testDeck),
                        ),
                      );
                    },
                    child: const Text('Open Deck From Shell'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Shell Root'), findsOneWidget);
      expect(find.byKey(const Key('open_deck_from_shell')), findsOneWidget);

      // Tap button to open DeckBuilderScreen over root navigator
      await tester.tap(find.byKey(const Key('open_deck_from_shell')));
      await tester.pumpAndSettle();

      expect(find.byType(DeckBuilderScreen), findsOneWidget);

      // Physical system back button press
      final popHandled = await tester.binding.handlePopRoute();
      expect(popHandled, isTrue);
      await tester.pumpAndSettle();

      // DeckBuilderScreen popped, shell screen intact
      expect(find.byType(DeckBuilderScreen), findsNothing);
      expect(find.text('Shell Root'), findsOneWidget);
      expect(find.byKey(const Key('open_deck_from_shell')), findsOneWidget);
    });

    testWidgets('5. Wizard push scenario: DeckSetupWizardModal -> DeckBuilderScreen -> System Back returns to DecksScreen', (tester) async {
      // Mount DecksScreen and trigger wizard push
      await tester.pumpWidget(
        createTestHarness(
          child: const DecksScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DecksScreen), findsOneWidget);

      // Simulate pushing DeckBuilderScreen from wizard directly as implemented in deck_setup_wizard_modal.dart:200
      final BuildContext decksContext = tester.element(find.byType(DecksScreen));
      Navigator.of(decksContext, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (_) => DeckBuilderScreen(deck: testDeck),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DeckBuilderScreen), findsOneWidget);

      // System back
      final popResult = await tester.binding.handlePopRoute();
      expect(popResult, isTrue);
      await tester.pumpAndSettle();

      // Verify clean return to DecksScreen
      expect(find.byType(DeckBuilderScreen), findsNothing);
      expect(find.byType(DecksScreen), findsOneWidget);
    });

    testWidgets('6. Wizard push scenario: DeckSetupWizardModal -> DeckBuilderScreen -> AppBar leading back returns to DecksScreen', (tester) async {
      await tester.pumpWidget(
        createTestHarness(
          child: const DecksScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DecksScreen), findsOneWidget);

      // Direct tap on deck card in DecksScreen to test decks_screen.dart:614 push
      final deckCard = find.byKey(Key('deck_item_${testDeck.id}'));
      if (deckCard.evaluate().isNotEmpty) {
        await tester.tap(deckCard);
      } else {
        // Tap first available deck item
        final firstDeck = find.byKey(const Key('deck_item_deck-edgar-markov'));
        expect(firstDeck, findsOneWidget);
        await tester.tap(firstDeck);
      }
      await tester.pumpAndSettle();

      expect(find.byType(DeckBuilderScreen), findsOneWidget);

      // Tap AppBar leading back button
      final backButton = find.descendant(
        of: find.byType(SliverAppBar),
        matching: find.byType(IconButton),
      );
      expect(backButton, findsOneWidget);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      expect(find.byType(DeckBuilderScreen), findsNothing);
      expect(find.byType(DecksScreen), findsOneWidget);
    });

    testWidgets('7. Stress test: Rapid double system back press does not throw unhandled exceptions', (tester) async {
      await tester.pumpWidget(
        createTestHarness(
          child: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                key: const Key('open_deck_button'),
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
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_deck_button')));
      await tester.pumpAndSettle();

      expect(find.byType(DeckBuilderScreen), findsOneWidget);

      // Rapidly fire handlePopRoute twice in immediate sequence without settling between
      final future1 = tester.binding.handlePopRoute();
      final future2 = tester.binding.handlePopRoute();
      await Future.wait([future1, future2]);
      await tester.pumpAndSettle();

      // No unhandled exceptions thrown
      expect(tester.takeException(), isNull);
      expect(find.byType(DeckBuilderScreen), findsNothing);
      expect(find.byKey(const Key('open_deck_button')), findsOneWidget);
    });

    testWidgets('8. Isolated Root Route scenario: DeckBuilderScreen as root does not infinite loop on system back', (tester) async {
      // In standalone scenario where DeckBuilderScreen is root route (canPop = false)
      await tester.pumpWidget(
        createTestHarness(
          child: DeckBuilderScreen(deck: testDeck),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DeckBuilderScreen), findsOneWidget);

      // System back on root route
      final handled = await tester.binding.handlePopRoute();
      expect(handled, isTrue);
      // Should not throw StackOverflowError or infinite loop
      expect(tester.takeException(), isNull);
    });
  });
}
