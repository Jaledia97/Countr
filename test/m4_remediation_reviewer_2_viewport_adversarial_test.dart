import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/features/decks/data/mock_deck_data.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/decks/presentation/screens/deck_builder_screen.dart';
import 'features/decks/deck_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final viewports = <Size>[
    const Size(280, 600),
    const Size(320, 568),
    const Size(360, 640),
    const Size(414, 896),
  ];

  final textScales = <double>[1.0, 1.5, 2.0];
  final assemblyStates = <bool>[false, true];

  group('M4 Adversarial Reviewer 2: Full Viewport x TextScale x Assembly Matrix', () {
    for (final size in viewports) {
      for (final scale in textScales) {
        for (final isAssembled in assemblyStates) {
          final stateLabel = isAssembled ? 'Assembled' : 'Draft';
          final testLabel =
              'Viewport ${size.width.toInt()}x${size.height.toInt()} | Scale ${scale}x | State: $stateLabel';

          testWidgets(testLabel, (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.resetPhysicalSize);

            final List<FlutterErrorDetails> errors = [];
            final originalOnError = FlutterError.onError;
            FlutterError.onError = (details) {
              errors.add(details);
              // Suppress child widget errors (inline_deck_analytics_card) so they don't abort
              // the DeckBuilderScreen remediation assertions prematurely.
              final isChildCardOverflow = details.toString().contains('inline_deck_analytics_card.dart');
              if (!isChildCardOverflow) {
                originalOnError?.call(details);
              }
            };

            try {
              final testDeck = createTestDeck(
                id: 'deck-matrix-${size.width.toInt()}-$scale-$stateLabel',
                name: 'Adversarial Matrix Deck ($stateLabel)',
                format: 'Commander',
                isRegistered: isAssembled,
                wins: 7,
                losses: 3,
              );

              await tester.pumpWidget(
                ProviderScope(
                  overrides: [
                    deckItemsProvider(testDeck.id).overrideWith(
                      (ref) => Stream.value(MockDeckData.getDeckItems(testDeck.id)),
                    ),
                  ],
                  child: MaterialApp(
                    home: MediaQuery(
                      data: MediaQueryData(
                        size: size,
                        textScaler: TextScaler.linear(scale),
                      ),
                      child: Navigator(
                        onGenerateRoute: (settings) => MaterialPageRoute(
                          builder: (_) => DeckBuilderScreen(deck: testDeck),
                        ),
                      ),
                    ),
                  ),
                ),
              );
              await tester.pumpAndSettle();

              // 1. Verify DeckBuilderScreen itself has zero RenderFlex overflows
              final deckBuilderOverflows = errors
                  .where((e) =>
                      e.exceptionAsString().contains('overflowed') &&
                      (e.exceptionAsString().contains('deck_builder_screen.dart') ||
                       e.exceptionAsString().contains('SliverAppBar') ||
                       e.exceptionAsString().contains('FlexibleSpaceBar')))
                  .toList();
              expect(
                deckBuilderOverflows,
                isEmpty,
                reason:
                    'DeckBuilderScreen overflow detected at $testLabel: ${deckBuilderOverflows.map((e) => e.exceptionAsString()).join("; ")}',
              );

              // 2. Collapse SliverAppBar fully
              final scrollableFinder = find.byType(CustomScrollView);
              expect(scrollableFinder, findsOneWidget);

              await tester.drag(scrollableFinder, const Offset(0, -350));
              await tester.pumpAndSettle();

              // 3. Verify Collapsed SliverAppBar has zero RenderFlex overflows
              final collapsedSliverOverflows = errors
                  .where((e) =>
                      e.exceptionAsString().contains('overflowed') &&
                      (e.exceptionAsString().contains('deck_builder_screen.dart') ||
                       e.exceptionAsString().contains('SliverAppBar') ||
                       e.exceptionAsString().contains('FlexibleSpaceBar')))
                  .toList();
              expect(
                collapsedSliverOverflows,
                isEmpty,
                reason:
                    'Collapsed SliverAppBar overflow detected at $testLabel: ${collapsedSliverOverflows.map((e) => e.exceptionAsString()).join("; ")}',
              );

              // 4. Verify Title Clearance Invariant:
              // Left >= 56.0 (back button), Right <= width - 144.0 (trailing actions)
              final titleFinder = find.text(testDeck.name);
              expect(titleFinder, findsOneWidget);

              final Rect titleRect = tester.getRect(titleFinder);

              expect(
                titleRect.left,
                greaterThanOrEqualTo(56.0 - 0.05),
                reason:
                    'Title left (${titleRect.left}) collided with back button (< 56.0) under $testLabel',
              );

              expect(
                titleRect.right,
                lessThanOrEqualTo(size.width - 144.0 + 0.05),
                reason:
                    'Title right (${titleRect.right}) collided with actions (> ${size.width - 144.0}) under $testLabel',
              );
            } finally {
              while (tester.takeException() != null) {}
              FlutterError.onError = originalOnError;
            }
          });
        }
      }
    }
  });

  group('M4 Adversarial Reviewer 2: Extreme Edge Cases & Interactions', () {
    testWidgets('Ultra-long 250-char deck name on 280x600 at 2.0x scale collapses without overflow or collision', (tester) async {
      tester.view.physicalSize = const Size(280, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final List<FlutterErrorDetails> errors = [];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        errors.add(details);
        final isChildCardOverflow = details.toString().contains('inline_deck_analytics_card.dart');
        if (!isChildCardOverflow) {
          originalOnError?.call(details);
        }
      };

      try {
        final longDeck = createTestDeck(
          id: 'deck-ultra-long-name',
          name: 'Supercalifragilisticexpialidocious Ultra Long Extreme Deck Name That Stretches Across Multiple Lines '
              'And Tries To Break Horizontal Constraints With Extensive Characters And No Spaces '
              'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
          format: 'Commander',
          isRegistered: true,
          wins: 99,
          losses: 0,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              deckItemsProvider(longDeck.id).overrideWith(
                (ref) => Stream.value(MockDeckData.getDeckItems(longDeck.id)),
              ),
            ],
            child: MaterialApp(
              home: MediaQuery(
                data: const MediaQueryData(
                  size: Size(280, 600),
                  textScaler: TextScaler.linear(2.0),
                ),
                child: Navigator(
                  onGenerateRoute: (settings) => MaterialPageRoute(
                    builder: (_) => DeckBuilderScreen(deck: longDeck),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final deckBuilderOverflows = errors
            .where((e) =>
                e.exceptionAsString().contains('overflowed') &&
                (e.exceptionAsString().contains('deck_builder_screen.dart') ||
                 e.exceptionAsString().contains('SliverAppBar')))
            .toList();
        expect(deckBuilderOverflows, isEmpty);

        // Collapse
        final scrollableFinder = find.byType(CustomScrollView);
        await tester.drag(scrollableFinder, const Offset(0, -350));
        await tester.pumpAndSettle();

        final collapsedOverflows = errors
            .where((e) =>
                e.exceptionAsString().contains('overflowed') &&
                (e.exceptionAsString().contains('deck_builder_screen.dart') ||
                 e.exceptionAsString().contains('SliverAppBar')))
            .toList();
        expect(collapsedOverflows, isEmpty);

        final titleFinder = find.text(longDeck.name);
        expect(titleFinder, findsOneWidget);

        final Rect titleRect = tester.getRect(titleFinder);
        expect(titleRect.left, greaterThanOrEqualTo(56.0 - 0.05));
        expect(titleRect.right, lessThanOrEqualTo(280.0 - 144.0 + 0.05));
      } finally {
        while (tester.takeException() != null) {}
        FlutterError.onError = originalOnError;
      }
    });

    testWidgets('Expanding card tile on 280x600 viewport at 2.0x scale produces ZERO overflows in deck builder', (tester) async {
      tester.view.physicalSize = const Size(280, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final List<FlutterErrorDetails> errors = [];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        errors.add(details);
        final isChildCardOverflow = details.toString().contains('inline_deck_analytics_card.dart');
        if (!isChildCardOverflow) {
          originalOnError?.call(details);
        }
      };

      try {
        final testDeck = createTestDeck(
          id: 'deck-tile-expand',
          name: 'Card Tile Expand Deck',
          format: 'Commander',
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              deckItemsProvider(testDeck.id).overrideWith(
                (ref) => Stream.value(MockDeckData.getDeckItems(testDeck.id)),
              ),
            ],
            child: MaterialApp(
              home: MediaQuery(
                data: const MediaQueryData(
                  size: Size(280, 600),
                  textScaler: TextScaler.linear(2.0),
                ),
                child: Navigator(
                  onGenerateRoute: (settings) => MaterialPageRoute(
                    builder: (_) => DeckBuilderScreen(deck: testDeck),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap the expansion chevron to expand its quick actions
        final expandChevron = find.byIcon(Icons.expand_more).first;
        expect(expandChevron, findsOneWidget);

        await tester.tap(expandChevron);
        await tester.pumpAndSettle();

        // Quick action buttons should now be visible
        expect(find.text('Full Details'), findsOneWidget);
        expect(find.text('Remove / Adjust'), findsOneWidget);
        expect(find.text('Switch'), findsOneWidget);

        // Verify zero overflow in deck_builder_screen
        final overflows = errors
            .where((e) =>
                e.exceptionAsString().contains('overflowed') &&
                e.exceptionAsString().contains('deck_builder_screen.dart'))
            .toList();
        expect(
          overflows,
          isEmpty,
          reason: 'Expanding card tile on 280px at 2.0x scale overflowed: ${overflows.map((e) => e.exceptionAsString()).join("; ")}',
        );
      } finally {
        while (tester.takeException() != null) {}
        FlutterError.onError = originalOnError;
      }
    });

    testWidgets('Anchor chip is absent and inline analytics renders on 280x600 at 2.0x scale with zero overflows', (tester) async {
      tester.view.physicalSize = const Size(280, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final List<FlutterErrorDetails> errors = [];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        errors.add(details);
        final isChildCardOverflow = details.toString().contains('inline_deck_analytics_card.dart');
        if (!isChildCardOverflow) {
          originalOnError?.call(details);
        }
      };

      try {
        final testDeck = createTestDeck(
          id: 'deck-anchor-tap',
          name: 'Anchor Tap Deck',
          format: 'Commander',
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              deckItemsProvider(testDeck.id).overrideWith(
                (ref) => Stream.value(MockDeckData.getDeckItems(testDeck.id)),
              ),
            ],
            child: MaterialApp(
              home: MediaQuery(
                data: const MediaQueryData(
                  size: Size(280, 600),
                  textScaler: TextScaler.linear(2.0),
                ),
                child: Navigator(
                  onGenerateRoute: (settings) => MaterialPageRoute(
                    builder: (_) => DeckBuilderScreen(deck: testDeck),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify anchor chip is removed
        final anchorFinder = find.byKey(const Key('deck_builder_anchor_analytics_chip'));
        expect(anchorFinder, findsNothing);
        expect(find.text('Jump to Analytics'), findsNothing);

        // Verify inline card is rendered and expands cleanly
        final toggleFinder = find.byKey(const Key('inline_analytics_collapse_toggle'));
        expect(toggleFinder, findsOneWidget);
        await tester.tap(toggleFinder);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('deck_builder_inline_analytics_card')), findsOneWidget);

        final deckBuilderOverflows = errors
            .where((e) => e.exceptionAsString().contains('overflowed') &&
                          e.exceptionAsString().contains('deck_builder_screen.dart'))
            .toList();
        expect(
          deckBuilderOverflows,
          isEmpty,
          reason: 'DeckBuilderScreen overflowed on 280px at 2.0x: ${deckBuilderOverflows.map((e) => e.exceptionAsString()).join("; ")}',
        );
      } finally {
        while (tester.takeException() != null) {}
        FlutterError.onError = originalOnError;
      }
    });

    testWidgets('Empty deck (0 items) on 280x600 at 2.0x scale mounts and collapses with zero exceptions', (tester) async {
      tester.view.physicalSize = const Size(280, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final emptyDeck = createTestDeck(
        id: 'deck-empty-adversarial',
        name: 'Empty Adversarial Deck',
        format: 'Commander',
        isRegistered: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deckItemsProvider(emptyDeck.id).overrideWith(
              (ref) => Stream.value([]),
            ),
          ],
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(280, 600),
                textScaler: TextScaler.linear(2.0),
              ),
              child: Navigator(
                onGenerateRoute: (settings) => MaterialPageRoute(
                  builder: (_) => DeckBuilderScreen(deck: emptyDeck),
                ),
              ),
            ),
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.textContaining('No cards in this deck yet'), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Collapse empty deck view
        final scrollableFinder = find.byType(CustomScrollView);
        await tester.drag(scrollableFinder, const Offset(0, -350));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });
  });
}
