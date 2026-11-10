import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/domain/models/explore_deck_models.dart';
import 'package:countr/features/decks/presentation/providers/explore_deck_providers.dart';
import 'package:countr/features/decks/presentation/widgets/explore/explore_category_drill_down_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  List<ExploreDeckWithVote> generateMockDecks(int count, {String category = 'Suggested Commanders'}) {
    final now = DateTime.now();
    return List.generate(
      count,
      (i) => ExploreDeckWithVote(
        deck: ExploreDeck(
          id: 'mock_deck_$i',
          name: 'Mock Deck $i',
          format: 'Commander',
          tcgDomain: 'mtg',
          featuredCategory: category,
          sourceType: 'community',
          creatorName: '@Creator$i',
          colorIdentity: '["W","U","B"]',
          commanderName: 'Atraxa',
          commanderImageUrl: null,
          cardCount: 100,
          estimatedPrice: 250.0 + i,
          upvotes: 10 + i,
          downvotes: 1,
          score: 9 + i,
          isDeleted: false,
          createdAt: now.subtract(Duration(minutes: i)),
        ),
        userVote: 0,
      ),
    );
  }

  Widget createHarness({
    required double width,
    required double height,
    required double textScale,
    required String category,
    List<ExploreDeckWithVote>? customDecks,
    VoidCallback? onBack,
    ValueChanged<ExploreDeckWithVote>? onTapDeck,
    ProviderContainer? container,
  }) {
    final widget = MediaQuery(
      data: MediaQueryData(
        size: Size(width, height),
        textScaler: TextScaler.linear(textScale),
      ),
      child: MaterialApp(
        home: Scaffold(
          body: ExploreCategoryDrillDownView(
            category: category,
            customDecks: customDecks,
            onBack: onBack,
            onTapDeck: onTapDeck,
          ),
        ),
      ),
    );

    if (container != null) {
      return UncontrolledProviderScope(container: container, child: widget);
    }
    return ProviderScope(child: widget);
  }

  group('Challenger 2 Matrix: Header Sweep across Viewports & Text Scaling', () {
    final widths = [200.0, 240.0, 280.0, 300.0, 320.0, 360.0, 375.0, 390.0, 414.0, 420.0, 500.0, 539.0, 540.0, 600.0, 768.0, 1024.0];
    final scalers = [0.8, 1.0, 1.2, 1.21, 1.35, 1.5, 2.0, 2.5, 3.0];

    for (final width in widths) {
      for (final scale in scalers) {
        testWidgets('Header width ${width}px @ ${scale}x scale: zero RenderFlex overflow', (tester) async {
          tester.view.physicalSize = Size(width, 700);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          await tester.pumpWidget(
            createHarness(
              width: width,
              height: 700,
              textScale: scale,
              category: 'Suggested Commanders',
              customDecks: const [],
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull,
              reason: 'Header overflow occurred on width: ${width}px with textScale: ${scale}x');

          // Verify header key contracts exist
          expect(find.byKey(const Key('explore_drill_down_back_button')), findsOneWidget);
          expect(find.byKey(const Key('explore_drill_down_title')), findsOneWidget);
          expect(find.byKey(const Key('explore_decks_count_badge')), findsOneWidget);
          expect(find.byKey(const Key('explore_drill_down_count_badge')), findsOneWidget);
          expect(find.byKey(const Key('explore_drill_down_reset_button')), findsOneWidget);
        });
      }
    }
  });

  group('Challenger 2 Real Device Viewports with Decks (300px to 420px up to 2.0x scale)', () {
    final mobileWidths = [300.0, 320.0, 360.0, 375.0, 390.0, 414.0];
    final scales = [1.0, 1.2, 1.5, 2.0];

    for (final width in mobileWidths) {
      for (final scale in scales) {
        testWidgets('Mobile ${width}px @ ${scale}x scale with cards: zero overflow', (tester) async {
          tester.view.physicalSize = Size(width, 700);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          final decks = generateMockDecks(6);
          await tester.pumpWidget(
            createHarness(
              width: width,
              height: 700,
              textScale: scale,
              category: 'Suggested Commanders',
              customDecks: decks,
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull,
              reason: 'Overflow on mobile width ${width}px @ ${scale}x scale');
        });
      }
    }
  });

  group('Challenger 2 Edge Invariants: Deck Counts & Extreme Titles', () {
    testWidgets('Extreme deck counts (0 to 999,999) under 300px viewport @ 2.0x text scale', (tester) async {
      tester.view.physicalSize = const Size(300, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final testCounts = [0, 1, 42, 999, 12345, 999999];
      for (final count in testCounts) {
        final decks = generateMockDecks(count > 6 ? 6 : count);
        final container = ProviderContainer(
          overrides: [
            featuredCategoryDeckCountProvider('Suggested Commanders')
                .overrideWith((ref) => Stream.value(count)),
            featuredCategoryDecksStreamProvider('Suggested Commanders')
                .overrideWith((ref) => Stream.value(decks)),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          createHarness(
            width: 300,
            height: 600,
            textScale: 2.0,
            category: 'Suggested Commanders',
            container: container,
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull,
            reason: 'Overflow on count: $count under 300px @ 2.0x scale');
        expect(find.byKey(const Key('explore_drill_down_count_badge')), findsOneWidget);
        expect(find.text('$count decks'), findsOneWidget);
      }
    });

    testWidgets('Ultra-long 150-char category title with emojis on 300px viewport @ 2.0x scale', (tester) async {
      tester.view.physicalSize = const Size(300, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const longTitle = '🔥🛡️ Extremely Long Category Name With Special Characters & Emojis That Spans Multiple Lines If Not Constrained Ellipsis Testing 🚀';
      final decks = generateMockDecks(4, category: longTitle);

      await tester.pumpWidget(
        createHarness(
          width: 300,
          height: 600,
          textScale: 2.0,
          category: longTitle,
          customDecks: decks,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('explore_drill_down_title')), findsOneWidget);
      expect(find.text(longTitle), findsOneWidget);
    });

    testWidgets('Empty category title string does not crash layout', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        createHarness(
          width: 320,
          height: 568,
          textScale: 1.0,
          category: '',
          customDecks: [],
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('explore_drill_down_title')), findsOneWidget);
    });
  });

  group('Challenger 2 Interaction & Orientation Stress', () {
    testWidgets('Tap interactions on back, reset, and card tiles are responsive across narrow and wide modes', (tester) async {
      for (final width in [300.0, 420.0, 600.0]) {
        tester.view.physicalSize = Size(width, 700);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        int backTaps = 0;
        ExploreDeckWithVote? tappedDeck;

        final decks = generateMockDecks(4);
        await tester.pumpWidget(
          createHarness(
            width: width,
            height: 700,
            textScale: 1.2,
            category: 'Suggested Commanders',
            customDecks: decks,
            onBack: () => backTaps++,
            onTapDeck: (deck) => tappedDeck = deck,
          ),
        );
        await tester.pumpAndSettle();

        // Tap back button
        await tester.tap(find.byKey(const Key('explore_drill_down_back_button')));
        await tester.pumpAndSettle();
        expect(backTaps, equals(1), reason: 'Back button tap failed on width $width');

        // Tap reset button
        await tester.tap(find.byKey(const Key('explore_drill_down_reset_button')));
        await tester.pumpAndSettle();
        expect(backTaps, equals(2), reason: 'Reset button tap failed on width $width');

        // Tap first deck card
        await tester.tap(find.text('Mock Deck 0'));
        await tester.pumpAndSettle();
        expect(tappedDeck, isNotNull, reason: 'Deck card tap failed on width $width');
        expect(tappedDeck!.id, equals('mock_deck_0'));
      }
    });

    testWidgets('Dynamic resize / orientation change mid-session preserves layout integrity without exceptions', (tester) async {
      final decks = generateMockDecks(8);
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Start on narrow portrait 300x600 @ 1.5x scale
      tester.view.physicalSize = const Size(300, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        createHarness(
          width: 300,
          height: 600,
          textScale: 1.5,
          category: 'Suggested Commanders',
          customDecks: decks,
          container: container,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Rotate to landscape 600x300
      tester.view.physicalSize = const Size(600, 300);
      await tester.pumpWidget(
        createHarness(
          width: 600,
          height: 300,
          textScale: 1.5,
          category: 'Suggested Commanders',
          customDecks: decks,
          container: container,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Expand to tablet 1024x768 @ 1.0x scale
      tester.view.physicalSize = const Size(1024, 768);
      await tester.pumpWidget(
        createHarness(
          width: 1024,
          height: 768,
          textScale: 1.0,
          category: 'Suggested Commanders',
          customDecks: decks,
          container: container,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Reset'), findsOneWidget); // showTextReset is active on 1024px

      // Shrink back to 280x500 @ 2.0x scale
      tester.view.physicalSize = const Size(280, 500);
      await tester.pumpWidget(
        createHarness(
          width: 280,
          height: 500,
          textScale: 2.0,
          category: 'Suggested Commanders',
          customDecks: const [], // empty decks on sub-300px
          container: container,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget); // compact icon reset
    });
  });
}
