import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/features/decks/data/mock_deck_data.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/decks/presentation/screens/deck_builder_screen.dart';
import 'package:countr/features/decks/presentation/widgets/inline_deck_analytics_card.dart';
import 'package:countr/features/symbology/data/scryfall_symbol_catalog.dart';
import 'package:countr/features/values/domain/services/pareto_distribution_calculator.dart';
import 'package:countr/features/values/presentation/widgets/pareto_distribution_widget.dart';
import 'package:countr/features/values/presentation/widgets/value_concentration_pie_chart.dart';
import 'deck_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Offset polarToOffset(double radius, double clockwiseAngleFromTop) {
    final dx = radius * math.sin(clockwiseAngleFromTop);
    final dy = -radius * math.cos(clockwiseAngleFromTop);
    return Offset(dx, dy);
  }

  group('Section 1: ValueConcentrationPieChart Edge Cases', () {
    testWidgets('1.1: Single item deck (100% slice angle = 2*pi) renders and hit tests correctly', (tester) async {
      int? selected;
      final singleSlice = [
        const PieSliceData(
          rank: 1,
          id: 'single_card',
          name: 'Black Lotus',
          value: 100000.0,
          percentage: 100.0,
          color: Color(0xFFFF7A00),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ValueConcentrationPieChart(
                slices: singleSlice,
                totalDeckValue: 100000.0,
                topK: 1,
                concentrationPercentage: 100.0,
                selectedIndex: selected,
                onSliceSelected: (idx) => selected = idx,
                size: 180.0,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(ValueConcentrationPieChart), findsOneWidget);
      expect(find.byKey(const Key('donut_center_hole_badge')), findsOneWidget);
      expect(find.text('TOP 1'), findsOneWidget);

      final center = tester.getCenter(find.byKey(const Key('value_concentration_pie_gesture_detector')));

      // Tap slice at 3 o'clock (angle = pi/2, r = 60px inside donut)
      await tester.tapAt(center + polarToOffset(60.0, math.pi / 2));
      await tester.pumpAndSettle();
      expect(selected, equals(0));

      // Re-pump with selectedIndex = 0
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ValueConcentrationPieChart(
                slices: singleSlice,
                totalDeckValue: 100000.0,
                topK: 1,
                concentrationPercentage: 100.0,
                selectedIndex: 0,
                onSliceSelected: (idx) => selected = idx,
                size: 180.0,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Center badge displays details
      expect(find.text('#1'), findsOneWidget);
      expect(find.text('Black Lotus'), findsOneWidget);
      expect(find.text(r'$100000.00'), findsOneWidget);
      expect(find.text('100.0%'), findsOneWidget);

      // Tap center hole (r = 20px) -> should deselect (returns null)
      await tester.tapAt(center + polarToOffset(20.0, 0.0));
      await tester.pumpAndSettle();
      expect(selected, isNull);
    });

    testWidgets(r'1.2: All items equal value ($0.01 each) distributes arcs evenly', (tester) async {
      final equalSlices = List.generate(
        5,
        (i) => PieSliceData(
          rank: i + 1,
          id: 'card_$i',
          name: 'Penny Card $i',
          value: 0.01,
          percentage: 20.0,
          color: Colors.primaries[i % Colors.primaries.length],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ValueConcentrationPieChart(
                slices: equalSlices,
                totalDeckValue: 0.05,
                topK: 5,
                concentrationPercentage: 100.0,
                selectedIndex: 2,
                size: 180.0,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('#3'), findsOneWidget);
      expect(find.text('Penny Card 2'), findsOneWidget);
      expect(find.text(r'$0.01'), findsOneWidget);
      expect(find.text('20.0%'), findsOneWidget);
    });

    testWidgets('1.3: Zero-value items and empty deck behavior', (tester) async {
      // Empty deck
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: ValueConcentrationPieChart(
                slices: [],
                totalDeckValue: 0.0,
                topK: 0,
                concentrationPercentage: 0.0,
                size: 180.0,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('donut_center_hole_badge')), findsNothing);

      // Deck with totalDeckValue <= 0
      final zeroSlice = [
        const PieSliceData(
          rank: 1,
          id: 'free_card',
          name: 'Free Card',
          value: 0.0,
          percentage: 0.0,
          color: Colors.grey,
        ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ValueConcentrationPieChart(
                slices: zeroSlice,
                totalDeckValue: 0.0,
                topK: 1,
                concentrationPercentage: 0.0,
                size: 180.0,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('donut_center_hole_badge')), findsNothing);
    });

    testWidgets('1.4: Ultra-narrow viewports (320px) and extreme accessibility text scaling (2.0x)', (tester) async {
      final sampleCards = [
        const ParetoItem(
          rank: 1,
          id: 'c1',
          name: 'Extremely Long Card Name That Might Overflow Narrow Screens',
          setCode: 'ELD',
          quantity: 1,
          unitPrice: 150.0,
          lineValue: 150.0,
          percentageShare: 75.0,
          weightRatio: 1.0,
          imageUrl: '',
        ),
        const ParetoItem(
          rank: 2,
          id: 'c2',
          name: 'Short Card',
          setCode: 'AVR',
          quantity: 1,
          unitPrice: 50.0,
          lineValue: 50.0,
          percentageShare: 25.0,
          weightRatio: 0.33,
          imageUrl: '',
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 568),
                textScaler: TextScaler.linear(2.0),
              ),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: ParetoDistributionWidget(
                    deckTotalValue: 200.0,
                    topKConcentrationPercentage: 100.0,
                    topCards: sampleCards,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('pareto_distribution_widget')), findsOneWidget);
      expect(find.byType(ValueConcentrationPieChart), findsOneWidget);
    });

    testWidgets('1.5: Privacy mode prevents monetary leaks across chart and list', (tester) async {
      final sampleCards = [
        const ParetoItem(
          rank: 1,
          id: 'c1',
          name: 'Mox Diamond',
          setCode: 'STH',
          quantity: 1,
          unitPrice: 650.0,
          lineValue: 650.0,
          percentageShare: 65.0,
          weightRatio: 1.0,
          imageUrl: '',
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: ParetoDistributionWidget(
                  deckTotalValue: 1000.0,
                  topKConcentrationPercentage: 65.0,
                  topCards: sampleCards,
                  isPrivacyMode: true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Banner should redact concentration percentage to ****
      expect(find.textContaining(r'65%'), findsNothing);
      expect(find.textContaining(r'65.0%'), findsNothing);
      expect(find.textContaining('****'), findsWidgets);

      // Micro list card line value must be ****
      expect(find.text(r'$650.00'), findsNothing);
      expect(find.text(r'650'), findsNothing);

      // Tap row 1 to select in chart
      await tester.tap(find.byKey(const Key('pareto_row_1')));
      await tester.pumpAndSettle();

      // Center badge must NOT display $650.00 or 65.0%
      expect(find.text(r'$650.00'), findsNothing);
      expect(find.text(r'65.0%'), findsNothing);
    });
  });

  group('Section 2: ScryfallSymbolCatalog.resolveCardCmc Edge Cases', () {
    test('2.1: Split and aftermath cards sum faces correctly (CR 709.4)', () {
      // Split card: Fire // Ice
      final fireIce = {
        'layout': 'split',
        'card_faces': [
          {'name': 'Fire', 'mana_cost': '{1}{R}', 'cmc': 2.0},
          {'name': 'Ice', 'mana_cost': '{1}{U}', 'cmc': 2.0},
        ],
      };
      expect(ScryfallSymbolCatalog.resolveCardCmc(fireIce), equals(4.0));

      // Aftermath card: Cut // Ribbons
      final cutRibbons = {
        'layout': 'aftermath',
        'card_faces': [
          {'name': 'Cut', 'mana_cost': '{1}{R}', 'cmc': 2.0},
          {'name': 'Ribbons', 'mana_cost': '{X}{B}{B}', 'cmc': 2.0},
        ],
      };
      expect(ScryfallSymbolCatalog.resolveCardCmc(cutRibbons), equals(4.0));
    });

    test('2.2: Adventure, MDFC, and transform cards take front face CMC', () {
      // Adventure card: Murderous Rider
      final adventure = {
        'layout': 'adventure',
        'cmc': 3.0,
        'card_faces': [
          {'name': 'Murderous Rider', 'mana_cost': '{1}{B}{B}', 'cmc': 3.0},
          {'name': 'Swift End', 'mana_cost': '{1}{B}', 'cmc': 2.0},
        ],
      };
      expect(ScryfallSymbolCatalog.resolveCardCmc(adventure), equals(3.0));

      // MDFC without top-level cmc: Sea Gate Restoration // Sea Gate, Reborn
      final mdfcNoCmc = {
        'layout': 'modal_dfc',
        'card_faces': [
          {'name': 'Sea Gate Restoration', 'mana_cost': '{4}{U}{U}{U}', 'cmc': 7.0},
          {'name': 'Sea Gate, Reborn', 'mana_cost': '', 'cmc': 0.0},
        ],
      };
      expect(ScryfallSymbolCatalog.resolveCardCmc(mdfcNoCmc), equals(7.0));

      // Transform card: Delver of Secrets // Insectile Aberration
      final transform = {
        'layout': 'transform',
        'card_faces': [
          {'name': 'Delver of Secrets', 'mana_cost': '{U}', 'cmc': 1.0},
          {'name': 'Insectile Aberration', 'mana_cost': '', 'cmc': 0.0},
        ],
      };
      expect(ScryfallSymbolCatalog.resolveCardCmc(transform), equals(1.0));
    });

    test('2.3: String CMCs with whitespace, decimals, scientific notation, and invalid input', () {
      expect(ScryfallSymbolCatalog.resolveCardCmc({'cmc': ' 4.0 '}), equals(4.0));
      expect(ScryfallSymbolCatalog.resolveCardCmc({'cmc': '2.5'}), equals(2.5));
      expect(ScryfallSymbolCatalog.resolveCardCmc({'cmc': '1e1'}), equals(10.0));
      expect(ScryfallSymbolCatalog.resolveCardCmc({'cmc': 'invalid', 'mana_cost': '{2}{G}'}), equals(3.0));
      expect(ScryfallSymbolCatalog.resolveCardCmc({'cmc': 'garbage'}), equals(0.0));
    });

    test('2.4: Null, empty, and missing dynamicData payloads', () {
      expect(ScryfallSymbolCatalog.resolveCardCmc({}), equals(0.0));
      expect(ScryfallSymbolCatalog.resolveCardCmc({'cmc': null, 'mana_cost': null}), equals(0.0));
      expect(ScryfallSymbolCatalog.resolveCardCmc({'card_faces': []}), equals(0.0));
      expect(ScryfallSymbolCatalog.resolveCardCmc({'card_faces': [null]}), equals(0.0));
    });

    test('2.5: isLandCard edge cases', () {
      // Normal Land
      expect(ScryfallSymbolCatalog.isLandCard({'type_line': 'Basic Land — Island'}), isTrue);

      // Non-land card
      expect(ScryfallSymbolCatalog.isLandCard({'type_line': 'Artifact Creature — Construct'}), isFalse);

      // MDFC Land on front face
      expect(ScryfallSymbolCatalog.isLandCard({
        'layout': 'modal_dfc',
        'card_faces': [
          {'type_line': 'Land'},
          {'type_line': 'Land'},
        ],
      }), isTrue);

      // MDFC Spell on front face, Land on back face (Sea Gate Restoration)
      expect(ScryfallSymbolCatalog.isLandCard({
        'layout': 'modal_dfc',
        'type_line': 'Sorcery // Land',
        'card_faces': [
          {'type_line': 'Sorcery'},
          {'type_line': 'Land'},
        ],
      }), isFalse);
    });
  });

  group('Section 3: InlineDeckAnalyticsCard Edge Cases', () {
    testWidgets('3.1: Collapsed state under 320x568 at 2.0x font scaling renders without overflow', (tester) async {
      final analytics = DeckAnalytics(
        manaCurve: {0: 1, 1: 5, 2: 12, 3: 8, 4: 6, 5: 3, 6: 2, 7: 1},
        colorDevotion: {'W': 10, 'U': 15, 'B': 8, 'R': 12, 'G': 6, 'C': 4},
        colorProduction: {'W': 10, 'U': 15, 'B': 8, 'R': 12, 'G': 6, 'C': 4},
        blingPercentage: 0.45,
      );

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
                  analytics: analytics,
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
      expect(find.text('Deck Analytics'), findsOneWidget);
    });

    testWidgets('3.2: Rapid tab switching between Details and Values tabs does not leak or crash', (tester) async {
      final testDeck = createTestDeck(
        id: MockDeckData.edgarMarkovDeckId,
        name: 'Edgar Markov Aristocrats',
        format: 'MTG Commander',
        createdAt: DateTime.now(),
        wins: 10,
        losses: 4,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: DeckBuilderScreen(deck: testDeck),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find tabs
      final detailsTabFinder = find.text('Details');
      final valuesTabFinder = find.text('Values');
      expect(detailsTabFinder, findsOneWidget);
      expect(valuesTabFinder, findsOneWidget);

      // Rapidly toggle between Details and Values 8 times
      for (int i = 0; i < 8; i++) {
        await tester.tap(valuesTabFinder);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tap(detailsTabFinder);
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Ensure we are back on Details tab with inline analytics, without anchor chip
      expect(find.byKey(const Key('deck_builder_anchor_analytics_chip')), findsNothing);
      expect(find.byKey(const Key('deck_builder_inline_analytics_card')), findsOneWidget);
    });
  });
}
