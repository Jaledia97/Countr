import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/state/settings_state.dart';
import 'package:countr/features/values/domain/services/pareto_distribution_calculator.dart';
import 'package:countr/features/values/presentation/widgets/pareto_distribution_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleTopCards = [
    const ParetoItem(
      rank: 1,
      id: 'c1',
      name: 'Black Lotus',
      setCode: 'LEA',
      quantity: 1,
      unitPrice: 5000.0,
      lineValue: 5000.0,
      percentageShare: 70.0,
      weightRatio: 1.0,
      imageUrl: '',
    ),
    const ParetoItem(
      rank: 2,
      id: 'c2',
      name: 'Mox Sapphire',
      setCode: 'LEA',
      quantity: 1,
      unitPrice: 1500.0,
      lineValue: 1500.0,
      percentageShare: 21.0,
      weightRatio: 0.3,
      imageUrl: '',
    ),
    const ParetoItem(
      rank: 3,
      id: 'c3',
      name: 'Time Walk',
      setCode: '2ED',
      quantity: 1,
      unitPrice: 642.86,
      lineValue: 642.86,
      percentageShare: 9.0,
      weightRatio: 0.128,
      imageUrl: '',
    ),
  ];

  Widget buildWidget({
    double deckTotalValue = 7142.86,
    double topKConcentrationPercentage = 100.0,
    List<ParetoItem>? topCards,
    bool isPrivacyMode = false,
    AppCurrency currency = AppCurrency.usd,
    double textScale = 1.0,
    Size viewport = const Size(390, 844),
  }) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: viewport,
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(
          body: SingleChildScrollView(
            child: ParetoDistributionWidget(
              deckTotalValue: deckTotalValue,
              topKConcentrationPercentage: topKConcentrationPercentage,
              topCards: topCards ?? sampleTopCards,
              isPrivacyMode: isPrivacyMode,
              currency: currency,
            ),
          ),
        ),
      ),
    );
  }

  group('ParetoDistributionWidget Widget Tests', () {
    testWidgets('TC-PARETO-UI-01: renders headline banner and top cards micro-list', (tester) async {
      await tester.pumpWidget(buildWidget());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pareto_distribution_widget')), findsOneWidget);
      expect(find.byKey(const Key('pareto_headline_banner')), findsOneWidget);

      // Headline contains top cards count and percentage
      expect(find.textContaining('top 3 cards represent'), findsOneWidget);
      expect(find.textContaining('100.0%'), findsOneWidget);

      // Card names
      expect(find.text('Black Lotus'), findsOneWidget);
      expect(find.text('Mox Sapphire'), findsOneWidget);
      expect(find.text('Time Walk'), findsOneWidget);

      // Rank badges
      expect(find.byKey(const Key('pareto_rank_badge_1')), findsOneWidget);
      expect(find.byKey(const Key('pareto_rank_badge_2')), findsOneWidget);
      expect(find.byKey(const Key('pareto_rank_badge_3')), findsOneWidget);

      // Formatted values
      expect(find.text(r'$5000.00'), findsOneWidget);
      expect(find.text('(70.0%)'), findsOneWidget);
    });

    testWidgets('TC-PARETO-UI-02: redacts financial values to **** when privacy mode is active', (tester) async {
      await tester.pumpWidget(buildWidget(isPrivacyMode: true));
      await tester.pumpAndSettle();

      // In privacy mode: card names remain visible, but dollar values and percentages are ****
      expect(find.text('Black Lotus'), findsOneWidget);
      expect(find.text('Mox Sapphire'), findsOneWidget);

      // Financials should be masked to ****
      expect(find.text(r'$5000.00'), findsNothing);
      expect(find.text('70.0%'), findsNothing);
      expect(find.text('****'), findsWidgets);

      // Headline should also mask percentage to ****
      expect(find.textContaining('**** of this deck\'s total value'), findsOneWidget);
    });

    testWidgets('TC-PARETO-UI-03: renders empty state when no cards exist', (tester) async {
      await tester.pumpWidget(
        buildWidget(
          deckTotalValue: 0.0,
          topKConcentrationPercentage: 0.0,
          topCards: [],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pareto_empty_state')), findsOneWidget);
      expect(find.text('No cards in this deck to analyze.'), findsOneWidget);
    });

    testWidgets('TC-PARETO-UI-04: zero RenderFlex overflows on 320x568 at 2.0x font scaling', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildWidget(
          textScale: 2.0,
          viewport: const Size(320, 568),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('pareto_distribution_widget')), findsOneWidget);
    });

    testWidgets('TC-PARETO-UI-05: respects foreign currency formatting', (tester) async {
      await tester.pumpWidget(
        buildWidget(currency: AppCurrency.eur),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('€'), findsWidgets);
    });
  });
}
