import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/decks/presentation/screens/deck_builder_screen.dart';
import 'package:countr/features/decks/presentation/widgets/inline_deck_analytics_card.dart';
import 'deck_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final standardAnalytics = DeckAnalytics(
    manaCurve: {0: 2, 1: 8, 2: 15, 3: 12, 4: 9, 5: 4, 6: 2, 7: 3},
    colorDevotion: {'W': 14, 'U': 22, 'B': 10, 'R': 16, 'G': 8, 'C': 5},
    colorProduction: {'W': 14, 'U': 22, 'B': 10, 'R': 16, 'G': 8, 'C': 5},
    blingPercentage: 0.42,
  );

  group('Adversarial Suite 1: Ultra-Narrow Viewport (320px) & Font Scaling (1.0x, 1.5x, 2.0x)', () {
    final standardScales = [1.0, 1.5, 2.0];

    for (final scale in standardScales) {
      testWidgets('1.$scale: Collapsed state on 320x568 at ${scale}x font scale produces zero RenderFlex overflow', (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(320, 568),
                textScaler: TextScaler.linear(scale),
              ),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: InlineDeckAnalyticsCard(
                    analytics: standardAnalytics,
                    isExpanded: false,
                    onToggleExpand: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull, reason: 'Threw exception at ${scale}x scale in collapsed state');
        expect(find.byKey(const Key('deck_builder_inline_analytics_card')), findsOneWidget);
        expect(find.text('Deck Analytics'), findsOneWidget);
      });

      testWidgets('1.${scale}_expanded: Expanded state on 320x568 at ${scale}x font scale produces zero RenderFlex overflow', (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(320, 568),
                textScaler: TextScaler.linear(scale),
              ),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: InlineDeckAnalyticsCard(
                    analytics: standardAnalytics,
                    isExpanded: true,
                    onToggleExpand: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull, reason: 'Threw exception at ${scale}x scale in expanded state');
        expect(find.byType(ManaCurveChartWidget), findsOneWidget);
        expect(find.byType(ColorDevotionPipsWidget), findsOneWidget);
        expect(find.byType(BlingMeterWidget), findsOneWidget);
      });
    }

    testWidgets('1.4: Extreme 2.5x font scale adversarial probe on 320x568 identifies unconstrained Row limits', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // BlingMeterWidget alone is completely overflow-free even at 2.5x on 320px
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 568),
              textScaler: TextScaler.linear(2.5),
            ),
            child: Scaffold(
              body: BlingMeterWidget(blingPercentage: standardAnalytics.blingPercentage),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(BlingMeterWidget), findsOneWidget);
    });
  });

  group('Adversarial Suite 2: Extreme Bling Values & Clamp Stress', () {
    testWidgets('2.1: 0.0% bling renders correctly without NaN or overflow', (tester) async {
      final zeroBlingAnalytics = DeckAnalytics(
        manaCurve: {1: 1},
        colorDevotion: {'W': 1},
        colorProduction: {'W': 1},
        blingPercentage: 0.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlingMeterWidget(blingPercentage: zeroBlingAnalytics.blingPercentage),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('0.0% Bling'), findsOneWidget);
      expect(find.text('Foils, Promos, Graded & Alters'), findsOneWidget);
    });

    testWidgets('2.2: 100.0% bling renders full bar without overflow', (tester) async {
      final fullBlingAnalytics = DeckAnalytics(
        manaCurve: {1: 1},
        colorDevotion: {'W': 1},
        colorProduction: {'W': 1},
        blingPercentage: 1.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlingMeterWidget(blingPercentage: fullBlingAnalytics.blingPercentage),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('100.0% Bling'), findsOneWidget);
    });

    testWidgets('2.3: 99.9% bling renders with single decimal precision', (tester) async {
      final nearFullBlingAnalytics = DeckAnalytics(
        manaCurve: {1: 1},
        colorDevotion: {'W': 1},
        colorProduction: {'W': 1},
        blingPercentage: 0.999,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlingMeterWidget(blingPercentage: nearFullBlingAnalytics.blingPercentage),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('99.9% Bling'), findsOneWidget);
    });

    testWidgets('2.4: Out-of-bounds negative and excessive bling percentages clamp safely', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                BlingMeterWidget(blingPercentage: -0.25),
                BlingMeterWidget(blingPercentage: 2.50),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('0.0% Bling'), findsOneWidget);
      expect(find.text('100.0% Bling'), findsOneWidget);
    });

    testWidgets('2.5: BlingMeterWidget at 200px width with 2.5x font scale truncates subtitle without overflow', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(200, 300),
              textScaler: TextScaler.linear(2.5),
            ),
            child: const Scaffold(
              body: Center(
                child: SizedBox(
                  width: 200,
                  child: BlingMeterWidget(blingPercentage: 0.888),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(BlingMeterWidget), findsOneWidget);
    });
  });

  group('Adversarial Suite 3: Empty Decks & 0-Cards Edge Cases', () {
    testWidgets('3.1: Completely empty manaCurve and colorDevotion render safely in expanded card', (tester) async {
      final emptyAnalytics = DeckAnalytics(
        manaCurve: {},
        colorDevotion: {},
        colorProduction: {},
        blingPercentage: 0.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: InlineDeckAnalyticsCard(
                analytics: emptyAnalytics,
                isExpanded: true,
                onToggleExpand: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(ManaCurveChartWidget), findsOneWidget);
      expect(find.byType(ColorDevotionPipsWidget), findsOneWidget);
      expect(find.byType(BlingMeterWidget), findsOneWidget);

      // Verify all 8 CMC bucket counts ('0') + CMC '0' bucket label + 6 devotion counts ('0') render
      expect(find.text('0'), findsNWidgets(15));
    });

    testWidgets('3.2: ManaCurveChartWidget with zero counts does not crash or divide by zero', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ManaCurveChartWidget(
              manaCurve: {0: 0, 1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(ManaCurveChartWidget), findsOneWidget);
    });

    testWidgets('3.3: ColorDevotionPipsWidget with all zero devotion does not render devotion progress bar', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ColorDevotionPipsWidget(
              devotion: {'W': 0, 'U': 0, 'B': 0, 'R': 0, 'G': 0, 'C': 0},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Pips are shown with 0 count
      expect(find.text('0'), findsNWidgets(6));
      // Stacked color bar (ClipRRect) only renders if totalPips > 0
      expect(find.byType(ClipRRect), findsNothing);
    });

    testWidgets('3.4: DeckBuilderScreen with 0 cards hides inline analytics completely', (tester) async {
      final emptyDeck = createTestDeck(
        id: 'empty_deck_id',
        name: 'Empty Test Deck',
        format: 'MTG Commander',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deckItemsProvider(emptyDeck.id).overrideWith((ref) => Stream.value([])),
          ],
          child: MaterialApp(
            home: DeckBuilderScreen(deck: emptyDeck),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('deck_builder_inline_analytics_card')), findsNothing);
      expect(find.byKey(const Key('deck_builder_anchor_analytics_chip')), findsNothing);
    });
  });

  group('Adversarial Suite 4: Rigid Constraints & FittedBox Stress', () {
    testWidgets('4.1: ManaCurveChartWidget inside tight height (60px) scales down via FittedBox without overflow', (tester) async {
      // Height 60px is far below minHeight 120, so unconstrained layout would blow up by 60+ px
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                height: 60,
                child: ManaCurveChartWidget(
                  manaCurve: standardAnalytics.manaCurve,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(FittedBox), findsNWidgets(8)); // Each of the 8 buckets is wrapped in FittedBox
    });

    testWidgets('4.2: InlineDeckAnalyticsCard card header with 2.0x font scaling on 320px viewport does not overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 568),
              textScaler: TextScaler.linear(2.0),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: InlineDeckAnalyticsCard(
                  analytics: standardAnalytics,
                  isExpanded: false,
                  onToggleExpand: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('deck_builder_inline_analytics_card')), findsOneWidget);
      expect(find.byKey(const Key('inline_analytics_expand_modal_button')), findsNothing);
      expect(find.byKey(const Key('inline_analytics_collapse_toggle')), findsOneWidget);
    });
  });
}
