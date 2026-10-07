import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/features/decks/data/mock_deck_data.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/decks/presentation/screens/deck_builder_screen.dart';
import 'deck_test_helpers.dart';

void main() {
  final testDeck = createTestDeck(
    id: 'deck-adversarial-deep-m1',
    name: 'Adversarial Deep Deck',
    format: 'MTG Commander',
  );

  Widget createHarness({required Widget child}) {
    return ProviderScope(
      overrides: [
        deckItemsProvider(testDeck.id).overrideWith(
          (ref) => Stream.value(MockDeckData.getDeckItems(testDeck.id)),
        ),
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('M1 Deep Adversarial Stress: PopScope, Root Routes & Navigator Cascades', () {
    testWidgets('Adversarial 1: Rapid 50x handlePopRoute() hammering on isolated root route terminates safely', (tester) async {
      await tester.pumpWidget(
        createHarness(
          child: DeckBuilderScreen(deck: testDeck),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DeckBuilderScreen), findsOneWidget);

      // Hammer handlePopRoute 50 times in rapid succession
      for (int i = 0; i < 50; i++) {
        final handled = await tester.binding.handlePopRoute();
        expect(handled, isTrue, reason: 'Iteration $i: Root PopScope must intercept system back without crashing');
      }
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(DeckBuilderScreen), findsOneWidget);
    });

    testWidgets('Adversarial 2: Tapping leading back button on isolated root route does not throw or crash', (tester) async {
      await tester.pumpWidget(
        createHarness(
          child: DeckBuilderScreen(deck: testDeck),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DeckBuilderScreen), findsOneWidget);

      final backButton = find.byKey(const Key('deck_builder_back_button'));
      expect(backButton, findsOneWidget);

      // Tap back button when canPop is false
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(DeckBuilderScreen), findsOneWidget);
    });

    testWidgets('Adversarial 3a: Deep 3-tier nested navigators with rootNavigator: true pops cleanly on system back', (tester) async {
      final tier1Key = GlobalKey<NavigatorState>();
      final tier2Key = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        createHarness(
          child: Navigator(
            key: tier1Key,
            onGenerateRoute: (settings) => MaterialPageRoute(
              builder: (tier1Context) => Navigator(
                key: tier2Key,
                onGenerateRoute: (settings) => MaterialPageRoute(
                  builder: (tier2Context) => Scaffold(
                    body: ElevatedButton(
                      key: const Key('open_deck_deep_root'),
                      onPressed: () {
                        // Project architecture: rootNavigator: true
                        Navigator.of(tier2Context, rootNavigator: true).push(
                          MaterialPageRoute(
                            builder: (_) => DeckBuilderScreen(deck: testDeck),
                          ),
                        );
                      },
                      child: const Text('Open Deck Deep Root'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('open_deck_deep_root')), findsOneWidget);

      await tester.tap(find.byKey(const Key('open_deck_deep_root')));
      await tester.pumpAndSettle();

      expect(find.byType(DeckBuilderScreen), findsOneWidget);

      final didPop = await tester.binding.handlePopRoute();
      expect(didPop, isTrue);
      await tester.pumpAndSettle();

      expect(find.byType(DeckBuilderScreen), findsNothing);
      expect(find.byKey(const Key('open_deck_deep_root')), findsOneWidget);
    });

    testWidgets('Adversarial 3b: Nested navigator without rootNavigator pops cleanly via leading back button', (tester) async {
      final nestedKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        createHarness(
          child: Navigator(
            key: nestedKey,
            onGenerateRoute: (settings) => MaterialPageRoute(
              builder: (nestedContext) => Scaffold(
                body: ElevatedButton(
                  key: const Key('open_deck_nested'),
                  onPressed: () {
                    Navigator.of(nestedContext, rootNavigator: false).push(
                      MaterialPageRoute(
                        builder: (_) => DeckBuilderScreen(deck: testDeck),
                      ),
                    );
                  },
                  child: const Text('Open Deck Nested'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_deck_nested')));
      await tester.pumpAndSettle();

      expect(find.byType(DeckBuilderScreen), findsOneWidget);

      // Tap leading back button: should use nav.canPop() which resolves to nestedKey
      final backButton = find.byKey(const Key('deck_builder_back_button'));
      expect(backButton, findsOneWidget);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      expect(find.byType(DeckBuilderScreen), findsNothing);
      expect(find.byKey(const Key('open_deck_nested')), findsOneWidget);
    });

    testWidgets('Adversarial 4: 10x repeated Push/Pop thrashing cycle maintains integrity', (tester) async {
      await tester.pumpWidget(
        createHarness(
          child: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                key: const Key('push_btn'),
                onPressed: () {
                  Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(
                      builder: (_) => DeckBuilderScreen(deck: testDeck),
                    ),
                  );
                },
                child: const Text('Push Deck'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (int i = 0; i < 10; i++) {
        await tester.tap(find.byKey(const Key('push_btn')));
        await tester.pumpAndSettle();
        expect(find.byType(DeckBuilderScreen), findsOneWidget);

        if (i % 2 == 0) {
          // Pop via system back
          final handled = await tester.binding.handlePopRoute();
          expect(handled, isTrue);
        } else {
          // Pop via leading button
          final backBtn = find.byKey(const Key('deck_builder_back_button'));
          await tester.tap(backBtn);
        }
        await tester.pumpAndSettle();
        expect(find.byType(DeckBuilderScreen), findsNothing);
        expect(find.byKey(const Key('push_btn')), findsOneWidget);
      }

      expect(tester.takeException(), isNull);
    });

    testWidgets('Adversarial 5: Stacked modal dialogs over DeckBuilderScreen pop FIFO before screen pops', (tester) async {
      await tester.pumpWidget(
        createHarness(
          child: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                key: const Key('push_btn'),
                onPressed: () {
                  Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(
                      builder: (_) => DeckBuilderScreen(deck: testDeck),
                    ),
                  );
                },
                child: const Text('Push Deck'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('push_btn')));
      await tester.pumpAndSettle();
      expect(find.byType(DeckBuilderScreen), findsOneWidget);

      final screenCtx = tester.element(find.byType(DeckBuilderScreen));

      // Push Dialog 1
      showDialog(
        context: screenCtx,
        builder: (_) => const AlertDialog(title: Text('Dialog 1')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Dialog 1'), findsOneWidget);

      // Push Dialog 2
      showDialog(
        context: screenCtx,
        builder: (_) => const AlertDialog(title: Text('Dialog 2')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Dialog 2'), findsOneWidget);

      // First back pops Dialog 2
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(find.text('Dialog 2'), findsNothing);
      expect(find.text('Dialog 1'), findsOneWidget);
      expect(find.byType(DeckBuilderScreen), findsOneWidget);

      // Second back pops Dialog 1
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(find.text('Dialog 1'), findsNothing);
      expect(find.byType(DeckBuilderScreen), findsOneWidget);

      // Third back pops DeckBuilderScreen
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(find.byType(DeckBuilderScreen), findsNothing);
      expect(find.byKey(const Key('push_btn')), findsOneWidget);
    });
  });
}
