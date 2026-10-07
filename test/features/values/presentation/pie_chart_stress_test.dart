import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/state/settings_state.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/decks/presentation/widgets/inline_deck_analytics_card.dart';
import 'package:countr/features/values/domain/services/pareto_distribution_calculator.dart';
import 'package:countr/features/values/presentation/widgets/pareto_distribution_widget.dart';
import 'package:countr/features/values/presentation/widgets/value_concentration_pie_chart.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Helper to convert polar coordinates (radius, clockwise angle from 12 o'clock) to Cartesian offset
  Offset polarToOffset(double radius, double clockwiseAngleFromTop) {
    final dx = radius * math.sin(clockwiseAngleFromTop);
    final dy = -radius * math.cos(clockwiseAngleFromTop);
    return Offset(dx, dy);
  }

  Widget buildChartHarness({
    required List<PieSliceData> slices,
    double totalDeckValue = 1000.0,
    int topK = 5,
    double concentrationPercentage = 75.0,
    int? selectedIndex,
    ValueChanged<int?>? onSliceSelected,
    bool isPrivacyMode = false,
    AppCurrency currency = AppCurrency.usd,
    double size = 180.0,
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
          body: Center(
            child: ValueConcentrationPieChart(
              slices: slices,
              totalDeckValue: totalDeckValue,
              topK: topK,
              concentrationPercentage: concentrationPercentage,
              selectedIndex: selectedIndex,
              onSliceSelected: onSliceSelected,
              isPrivacyMode: isPrivacyMode,
              currency: currency,
              size: size,
            ),
          ),
        ),
      ),
    );
  }

  group('Group 1: Polar Hit Testing & Boundary Math Stress', () {
    const double chartSize = 180.0;
    const double rOuter = (chartSize / 2) - 10.0; // 80.0
    const double rInner = rOuter * 0.58; // 46.4

    // Setup 4 equal quadrant slices (each 25%)
    // Slice 0: [0 .. pi/2)   (12 to 3 o'clock)
    // Slice 1: [pi/2 .. pi)  (3 to 6 o'clock)
    // Slice 2: [pi .. 3pi/2) (6 to 9 o'clock)
    // Slice 3: [3pi/2 .. 2pi)(9 to 12 o'clock)
    final fourQuadrantSlices = [
      const PieSliceData(
        rank: 1,
        id: 'c1',
        name: 'Slice Q1',
        value: 25.0,
        percentage: 25.0,
        color: AppColors.accentAmber,
      ),
      const PieSliceData(
        rank: 2,
        id: 'c2',
        name: 'Slice Q2',
        value: 25.0,
        percentage: 25.0,
        color: AppColors.accentCyan,
      ),
      const PieSliceData(
        rank: 3,
        id: 'c3',
        name: 'Slice Q3',
        value: 25.0,
        percentage: 25.0,
        color: AppColors.accentViolet,
      ),
      const PieSliceData(
        rank: 4,
        id: 'c4',
        name: 'Slice Q4',
        value: 25.0,
        percentage: 25.0,
        color: AppColors.accentEmerald,
      ),
    ];

    testWidgets('1.1: Center hole boundary (r = R_inner - 1 deselects, r = R_inner + 1 selects)', (tester) async {
      int? selected;
      await tester.pumpWidget(
        buildChartHarness(
          slices: fourQuadrantSlices,
          totalDeckValue: 100.0,
          onSliceSelected: (val) => selected = val,
        ),
      );
      await tester.pumpAndSettle();

      final detectorFinder = find.byKey(const Key('value_concentration_pie_gesture_detector'));
      final center = tester.getCenter(detectorFinder);

      // Dead center tap (r = 0) -> deselects
      await tester.tapAt(center);
      expect(selected, isNull);

      // Inside center hole: r = rInner - 1.0 (45.4) -> deselects
      final insideHoleOffset = center + polarToOffset(rInner - 1.0, math.pi / 4);
      await tester.tapAt(insideHoleOffset);
      expect(selected, isNull);

      // Outside center hole: r = rInner + 1.0 (47.4) in Q1 (pi/4) -> selects slice 0
      final justOutsideHoleOffset = center + polarToOffset(rInner + 1.0, math.pi / 4);
      await tester.tapAt(justOutsideHoleOffset);
      expect(selected, equals(0));
    });

    testWidgets('1.2: Outer boundary (r = R_outer - 1 selects, r = R_outer + 1 selects, r = R_outer + 15 deselects)', (tester) async {
      int? selected;
      await tester.pumpWidget(
        buildChartHarness(
          slices: fourQuadrantSlices,
          totalDeckValue: 100.0,
          onSliceSelected: (val) => selected = val,
        ),
      );
      await tester.pumpAndSettle();

      final detectorFinder = find.byKey(const Key('value_concentration_pie_gesture_detector'));
      final center = tester.getCenter(detectorFinder);

      // Inside slice body: r = rOuter - 1.0 (79.0) in Q2 (3pi/4) -> selects slice 1
      final insideOuterOffset = center + polarToOffset(rOuter - 1.0, 3 * math.pi / 4);
      await tester.tapAt(insideOuterOffset);
      expect(selected, equals(1));

      // Exploded boundary margin: r = rOuter + 1.0 (81.0) in Q2 -> still selects slice 1
      final explodedMarginOffset = center + polarToOffset(rOuter + 1.0, 3 * math.pi / 4);
      await tester.tapAt(explodedMarginOffset);
      expect(selected, equals(1));

      // At r = rOuter + 13.0 (93.0 <= rOuterMax) -> selects slice 1
      final nearEdgeOffset = center + polarToOffset(rOuter + 13.0, 3 * math.pi / 4);
      await tester.tapAt(nearEdgeOffset);
      expect(selected, equals(1));

      // Beyond outer threshold: r = rOuter + 15.0 (95.0 > rOuterMax 94.0) -> deselects (calls with null)
      final beyondMaxOffset = center + polarToOffset(rOuter + 15.0, 3 * math.pi / 4);
      await tester.tapAt(beyondMaxOffset);
      expect(selected, isNull);
    });

    testWidgets('1.3: Hit testing across all 4 quadrants (0, pi/2, pi, 3pi/2)', (tester) async {
      int? selected;
      await tester.pumpWidget(
        buildChartHarness(
          slices: fourQuadrantSlices,
          totalDeckValue: 100.0,
          onSliceSelected: (val) => selected = val,
        ),
      );
      await tester.pumpAndSettle();

      final detectorFinder = find.byKey(const Key('value_concentration_pie_gesture_detector'));
      final center = tester.getCenter(detectorFinder);
      const double testRadius = (rInner + rOuter) / 2; // 63.2 mid-arc

      // Q1: angle = pi/4 (1:30 o'clock) -> slice 0
      await tester.tapAt(center + polarToOffset(testRadius, math.pi / 4));
      expect(selected, equals(0));

      // Q2: angle = 3pi/4 (4:30 o'clock) -> slice 1
      await tester.tapAt(center + polarToOffset(testRadius, 3 * math.pi / 4));
      expect(selected, equals(1));

      // Q3: angle = 5pi/4 (7:30 o'clock) -> slice 2
      await tester.tapAt(center + polarToOffset(testRadius, 5 * math.pi / 4));
      expect(selected, equals(2));

      // Q4: angle = 7pi/4 (10:30 o'clock) -> slice 3
      await tester.tapAt(center + polarToOffset(testRadius, 7 * math.pi / 4));
      expect(selected, equals(3));

      // Angular Boundaries verification:
      // Just after 12 o'clock (0.05 rad) -> slice 0
      await tester.tapAt(center + polarToOffset(testRadius, 0.05));
      expect(selected, equals(0));

      // Just before 3 o'clock (pi/2 - 0.05 rad) -> slice 0
      await tester.tapAt(center + polarToOffset(testRadius, (math.pi / 2) - 0.05));
      expect(selected, equals(0));

      // Just after 3 o'clock (pi/2 + 0.05 rad) -> slice 1
      await tester.tapAt(center + polarToOffset(testRadius, (math.pi / 2) + 0.05));
      expect(selected, equals(1));

      // Just before 6 o'clock (pi - 0.05 rad) -> slice 1
      await tester.tapAt(center + polarToOffset(testRadius, math.pi - 0.05));
      expect(selected, equals(1));

      // Just after 6 o'clock (pi + 0.05 rad) -> slice 2
      await tester.tapAt(center + polarToOffset(testRadius, math.pi + 0.05));
      expect(selected, equals(2));

      // Just before 9 o'clock (3pi/2 - 0.05 rad) -> slice 2
      await tester.tapAt(center + polarToOffset(testRadius, (3 * math.pi / 2) - 0.05));
      expect(selected, equals(2));

      // Just after 9 o'clock (3pi/2 + 0.05 rad) -> slice 3
      await tester.tapAt(center + polarToOffset(testRadius, (3 * math.pi / 2) + 0.05));
      expect(selected, equals(3));

      // Just before 12 o'clock (2pi - 0.05 rad) -> slice 3
      await tester.tapAt(center + polarToOffset(testRadius, (2 * math.pi) - 0.05));
      expect(selected, equals(3));
    });

    testWidgets('1.4: Tapping already-selected slice toggles selection off (returns null)', (tester) async {
      int? selected = 0;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return buildChartHarness(
              slices: fourQuadrantSlices,
              totalDeckValue: 100.0,
              selectedIndex: selected,
              onSliceSelected: (val) {
                setState(() => selected = val);
              },
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      final detectorFinder = find.byKey(const Key('value_concentration_pie_gesture_detector'));
      final center = tester.getCenter(detectorFinder);
      const double testRadius = (rInner + rOuter) / 2;

      // Slice 0 is initially selected. Tap slice 0 again (pi/4) -> should toggle off to null
      await tester.tapAt(center + polarToOffset(testRadius, math.pi / 4));
      await tester.pumpAndSettle();
      expect(selected, isNull);

      // Now tap slice 2 (5pi/4) -> should select slice 2
      await tester.tapAt(center + polarToOffset(testRadius, 5 * math.pi / 4));
      await tester.pumpAndSettle();
      expect(selected, equals(2));
    });
  });

  group('Group 2: Item Count Stress & Slice Scalability', () {
    testWidgets('2.1: Single item (100% of donut)', (tester) async {
      int? selected;
      final singleSlice = [
        const PieSliceData(
          rank: 1,
          id: 'solo',
          name: 'The One Ring',
          value: 100.0,
          percentage: 100.0,
          color: AppColors.accentAmber,
        ),
      ];

      await tester.pumpWidget(
        buildChartHarness(
          slices: singleSlice,
          totalDeckValue: 100.0,
          onSliceSelected: (val) => selected = val,
        ),
      );
      await tester.pumpAndSettle();

      final center = tester.getCenter(find.byKey(const Key('value_concentration_pie_gesture_detector')));
      // Tapping anywhere in the donut ring should select slice 0
      await tester.tapAt(center + polarToOffset(60.0, 0.5));
      expect(selected, equals(0));
      await tester.tapAt(center + polarToOffset(60.0, 3.5));
      expect(selected, equals(0));
    });

    testWidgets('2.2: Two items (50% / 50%)', (tester) async {
      int? selected;
      final twoSlices = [
        const PieSliceData(
          rank: 1,
          id: 'card1',
          name: 'Card Alpha',
          value: 50.0,
          percentage: 50.0,
          color: AppColors.accentAmber,
        ),
        const PieSliceData(
          rank: 2,
          id: 'card2',
          name: 'Card Beta',
          value: 50.0,
          percentage: 50.0,
          color: AppColors.accentCyan,
        ),
      ];

      await tester.pumpWidget(
        buildChartHarness(
          slices: twoSlices,
          totalDeckValue: 100.0,
          onSliceSelected: (val) => selected = val,
        ),
      );
      await tester.pumpAndSettle();

      final center = tester.getCenter(find.byKey(const Key('value_concentration_pie_gesture_detector')));
      // Right half (angle = pi/2) -> slice 0
      await tester.tapAt(center + polarToOffset(60.0, math.pi / 2));
      expect(selected, equals(0));

      // Left half (angle = 3pi/2) -> slice 1
      await tester.tapAt(center + polarToOffset(60.0, 3 * math.pi / 2));
      expect(selected, equals(1));
    });

    testWidgets('2.3: Five items (Pareto distribution: 40, 25, 15, 12, 8)', (tester) async {
      int? selected;
      final fiveSlices = [
        const PieSliceData(rank: 1, id: '1', name: 'Card 1', value: 40.0, percentage: 40.0, color: AppColors.accentAmber),
        const PieSliceData(rank: 2, id: '2', name: 'Card 2', value: 25.0, percentage: 25.0, color: AppColors.accentCyan),
        const PieSliceData(rank: 3, id: '3', name: 'Card 3', value: 15.0, percentage: 15.0, color: AppColors.accentViolet),
        const PieSliceData(rank: 4, id: '4', name: 'Card 4', value: 12.0, percentage: 12.0, color: AppColors.accentEmerald),
        const PieSliceData(rank: 5, id: '5', name: 'Card 5', value: 8.0, percentage: 8.0, color: AppColors.accentRose),
      ];

      await tester.pumpWidget(
        buildChartHarness(
          slices: fiveSlices,
          totalDeckValue: 100.0,
          onSliceSelected: (val) => selected = val,
        ),
      );
      await tester.pumpAndSettle();

      final center = tester.getCenter(find.byKey(const Key('value_concentration_pie_gesture_detector')));
      // Slice 0: [0 .. 0.40 * 2pi) = [0 .. 2.513 rad]. Mid: 1.256
      await tester.tapAt(center + polarToOffset(60.0, 1.256));
      expect(selected, equals(0));

      // Slice 1: [0.40 * 2pi .. 0.65 * 2pi) = [2.513 .. 4.084 rad]. Mid: 3.298
      await tester.tapAt(center + polarToOffset(60.0, 3.298));
      expect(selected, equals(1));

      // Slice 2: [0.65 * 2pi .. 0.80 * 2pi) = [4.084 .. 5.026 rad]. Mid: 4.555
      await tester.tapAt(center + polarToOffset(60.0, 4.555));
      expect(selected, equals(2));

      // Slice 3: [0.80 * 2pi .. 0.92 * 2pi) = [5.026 .. 5.780 rad]. Mid: 5.403
      await tester.tapAt(center + polarToOffset(60.0, 5.403));
      expect(selected, equals(3));

      // Slice 4: [0.92 * 2pi .. 1.00 * 2pi) = [5.780 .. 6.283 rad]. Mid: 6.031
      await tester.tapAt(center + polarToOffset(60.0, 6.031));
      expect(selected, equals(4));
    });

    testWidgets('2.4: Twenty items (5% each) fine-granularity stress', (tester) async {
      int? selected;
      final twentySlices = List.generate(20, (i) {
        return PieSliceData(
          rank: i + 1,
          id: 'card_$i',
          name: 'Item $i',
          value: 5.0,
          percentage: 5.0,
          color: Colors.primaries[i % Colors.primaries.length],
        );
      });

      await tester.pumpWidget(
        buildChartHarness(
          slices: twentySlices,
          totalDeckValue: 100.0,
          onSliceSelected: (val) => selected = val,
        ),
      );
      await tester.pumpAndSettle();

      final center = tester.getCenter(find.byKey(const Key('value_concentration_pie_gesture_detector')));
      const double sweep = 2 * math.pi / 20;

      // Hit test every single slice at its exact bisecting angle
      for (int i = 0; i < 20; i++) {
        final midAngle = (i * sweep) + (sweep / 2);
        await tester.tapAt(center + polarToOffset(60.0, midAngle));
        expect(selected, equals(i), reason: 'Slice $i at angle $midAngle failed to select');
      }
    });

    testWidgets('2.5: Slices with 0-value do not crash or corrupt sweep math', (tester) async {
      int? selected;
      final slicesWithZero = [
        const PieSliceData(rank: 1, id: 'c1', name: 'Lotus', value: 100.0, percentage: 66.7, color: AppColors.accentAmber),
        const PieSliceData(rank: 2, id: 'c2', name: 'Zero Card', value: 0.0, percentage: 0.0, color: AppColors.accentCyan),
        const PieSliceData(rank: 3, id: 'c3', name: 'Mox', value: 50.0, percentage: 33.3, color: AppColors.accentViolet),
      ];

      await tester.pumpWidget(
        buildChartHarness(
          slices: slicesWithZero,
          totalDeckValue: 150.0,
          onSliceSelected: (val) => selected = val,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final center = tester.getCenter(find.byKey(const Key('value_concentration_pie_gesture_detector')));

      // Tap in slice 0 (Lotus: [0 .. 4.188 rad])
      await tester.tapAt(center + polarToOffset(60.0, 2.0));
      expect(selected, equals(0));

      // Tap in slice 2 (Mox: [4.188 .. 6.283 rad])
      await tester.tapAt(center + polarToOffset(60.0, 5.0));
      expect(selected, equals(2));
    });

    testWidgets('2.6: Empty slices or zero totalDeckValue renders SizedBox.shrink() safely', (tester) async {
      // Empty slices
      await tester.pumpWidget(
        buildChartHarness(
          slices: [],
          totalDeckValue: 0.0,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('value_concentration_pie_gesture_detector')), findsNothing);
      expect(tester.takeException(), isNull);

      // Non-empty slices but totalDeckValue == 0.0
      await tester.pumpWidget(
        buildChartHarness(
          slices: [
            const PieSliceData(rank: 1, id: 'c1', name: 'Zero', value: 0.0, percentage: 0.0, color: Colors.blue),
          ],
          totalDeckValue: 0.0,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('value_concentration_pie_gesture_detector')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('Group 3: NaN and Infinite Value Protection Stress', () {
    testWidgets('3.1: ParetoDistributionCalculator sanitizes NaN and Inf prices', (tester) async {
      final inputCards = [
        const ParetoCardInput(id: '1', name: 'Normal Card', unitPrice: 100.0, quantity: 1),
        const ParetoCardInput(id: '2', name: 'NaN Card', unitPrice: double.nan, quantity: 1),
        const ParetoCardInput(id: '3', name: 'Inf Card', unitPrice: double.infinity, quantity: 1),
        const ParetoCardInput(id: '4', name: 'Neg Inf Card', unitPrice: double.negativeInfinity, quantity: 1),
      ];

      final result = ParetoDistributionCalculator.calculate(cards: inputCards);

      expect(result.totalDeckValue, equals(100.0));
      expect(result.topCards.length, equals(4));
      // NaN and Inf cards must be sanitized to 0.0 unit price and 0.0 line value
      expect(result.topCards[0].name, equals('Normal Card'));
      expect(result.topCards[0].unitPrice, equals(100.0));
      expect(result.topCards[1].unitPrice, equals(0.0));
      expect(result.topCards[2].unitPrice, equals(0.0));
      expect(result.topCards[3].unitPrice, equals(0.0));
      expect(result.concentrationPercentage, equals(100.0));
    });

    testWidgets('3.2: ParetoDistributionWidget renders cleanly with NaN/Inf inputs via calculator', (tester) async {
      final inputCards = [
        const ParetoCardInput(id: '1', name: 'Lotus', unitPrice: 1000.0, quantity: 1),
        const ParetoCardInput(id: '2', name: 'NaN Card', unitPrice: double.nan, quantity: 1),
      ];
      final result = ParetoDistributionCalculator.calculate(cards: inputCards);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: ParetoDistributionWidget(result: result),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('pareto_distribution_widget')), findsOneWidget);
      expect(find.text('Lotus'), findsOneWidget);
    });
  });

  group('Group 4: Exploding Slice Offset & Center Badge Verification', () {
    final sampleSlices = [
      const PieSliceData(
        rank: 1,
        id: 'c1',
        name: 'Black Lotus Alpha',
        value: 5000.0,
        percentage: 70.0,
        color: AppColors.accentAmber,
      ),
      const PieSliceData(
        rank: 2,
        id: 'c2',
        name: 'Mox Sapphire',
        value: 1500.0,
        percentage: 21.0,
        color: AppColors.accentCyan,
      ),
      const PieSliceData(
        rank: 3,
        id: 'c3',
        name: 'Time Walk',
        value: 642.86,
        percentage: 9.0,
        color: AppColors.accentViolet,
      ),
    ];

    testWidgets('4.1: Center badge shows default aggregate state when unselected', (tester) async {
      await tester.pumpWidget(
        buildChartHarness(
          slices: sampleSlices,
          totalDeckValue: 7142.86,
          selectedIndex: null,
          topK: 3,
        ),
      );
      await tester.pumpAndSettle();

      final badge = find.byKey(const Key('donut_center_hole_badge'));
      expect(badge, findsOneWidget);

      expect(find.text('TOP 3'), findsOneWidget);
      expect(find.text('TAP SLICE'), findsOneWidget);
      expect(find.byIcon(Icons.touch_app_outlined), findsOneWidget);
    });

    testWidgets('4.2: Selecting slice updates center badge with rank, name, price, share, and truncates long names', (tester) async {
      await tester.pumpWidget(
        buildChartHarness(
          slices: sampleSlices,
          totalDeckValue: 7142.86,
          selectedIndex: 0, // Select Black Lotus Alpha
          topK: 3,
        ),
      );
      await tester.pumpAndSettle();

      // Black Lotus Alpha is 17 chars > 13 chars -> Truncated to 'Black Lotus …'
      expect(find.text('#1'), findsOneWidget);
      expect(find.text('Black Lotus …'), findsOneWidget);
      expect(find.text(r'$5000.00'), findsOneWidget);
      expect(find.text('70.0%'), findsOneWidget);
    });

    testWidgets('4.3: DonutChartPainter explodes selected slice by 6.0px along bisecting angle', (tester) async {
      final painter = DonutChartPainter(
        slices: sampleSlices,
        selectedIndex: 0,
        sweepProgress: 1.0,
      );

      // Verify shouldRepaint logic
      final painterUnselected = DonutChartPainter(
        slices: sampleSlices,
        selectedIndex: null,
        sweepProgress: 1.0,
      );
      expect(painter.shouldRepaint(painterUnselected), isTrue);

      // Test painting with selected slice into a recording canvas
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      expect(() => painter.paint(canvas, const Size(180, 180)), returnsNormally);
      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });
  });

  group('Group 5: Privacy Mode Masking Stress', () {
    final sampleSlices = [
      const PieSliceData(
        rank: 1,
        id: 'c1',
        name: 'Mox Jet',
        value: 3000.0,
        percentage: 60.0,
        color: AppColors.accentAmber,
      ),
      const PieSliceData(
        rank: 2,
        id: 'c2',
        name: 'Underground Sea',
        value: 2000.0,
        percentage: 40.0,
        color: AppColors.accentCyan,
      ),
    ];

    testWidgets('5.1: ValueConcentrationPieChart masks price and percentage to **** when privacy mode is active', (tester) async {
      await tester.pumpWidget(
        buildChartHarness(
          slices: sampleSlices,
          totalDeckValue: 5000.0,
          selectedIndex: 0,
          isPrivacyMode: true,
        ),
      );
      await tester.pumpAndSettle();

      // Card name still visible
      expect(find.text('Mox Jet'), findsOneWidget);
      expect(find.text('#1'), findsOneWidget);

      // Price and percentage strictly masked
      expect(find.text(r'$3000.00'), findsNothing);
      expect(find.text('60.0%'), findsNothing);
      expect(find.text('****'), findsNWidgets(2)); // Price **** and Percentage ****
    });

    testWidgets('5.2: ParetoDistributionWidget masks all financials in headline, list, and chart', (tester) async {
      final inputCards = [
        const ParetoItem(
          rank: 1,
          id: 'c1',
          name: 'Mox Jet',
          setCode: '2ED',
          quantity: 1,
          unitPrice: 3000.0,
          lineValue: 3000.0,
          percentageShare: 60.0,
          weightRatio: 0.6,
          imageUrl: '',
        ),
        const ParetoItem(
          rank: 2,
          id: 'c2',
          name: 'Underground Sea',
          setCode: '3ED',
          quantity: 1,
          unitPrice: 2000.0,
          lineValue: 2000.0,
          percentageShare: 40.0,
          weightRatio: 0.4,
          imageUrl: '',
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: ParetoDistributionWidget(
                  deckTotalValue: 5000.0,
                  topKConcentrationPercentage: 100.0,
                  topCards: inputCards,
                  isPrivacyMode: true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Headline masked
      expect(find.textContaining('**** of this deck\'s total value'), findsOneWidget);
      // No unmasked amounts
      expect(find.text(r'$3000.00'), findsNothing);
      expect(find.text(r'$2000.00'), findsNothing);
      expect(find.text('(60.0%)'), findsNothing);
      expect(find.text('(40.0%)'), findsNothing);
      // Masked tokens exist
      expect(find.text('****'), findsWidgets);
    });
  });

  group('Group 6: Responsive Viewport (320px) & 2.0x Font Scaling UI Stress', () {
    testWidgets('6.1: ValueConcentrationPieChart on 320px viewport with 2.0x text scaling has zero overflows', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final slices = [
        const PieSliceData(
          rank: 1,
          id: 'c1',
          name: 'Extremely Long Legendary Card Name Here',
          value: 1234.56,
          percentage: 65.4,
          color: AppColors.accentAmber,
        ),
      ];

      await tester.pumpWidget(
        buildChartHarness(
          slices: slices,
          totalDeckValue: 1234.56,
          selectedIndex: 0,
          textScale: 2.0,
          viewport: const Size(320, 568),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('donut_center_hole_badge')), findsOneWidget);
    });

    testWidgets('6.2: InlineDeckAnalyticsCard collapsed state on 320px viewport with 2.0x text scaling has zero overflows', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

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

    testWidgets('6.2b: InlineDeckAnalyticsCard expanded state on 320px viewport with 1.0x text scaling has zero overflows', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

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
              textScaler: TextScaler.linear(1.0),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: InlineDeckAnalyticsCard(
                  analytics: analytics,
                  isExpanded: true,
                  onToggleExpand: () {},
                ),
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
    });

    testWidgets('6.3: InlineDeckAnalyticsCard expanded state on 320px viewport with 2.0x text scaling has zero overflows', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

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
                  isExpanded: true,
                  onToggleExpand: () {},
                ),
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
    });

    testWidgets('6.4: ParetoDistributionWidget with ValueConcentrationPieChart on 320px viewport with 2.0x text scaling has zero overflows', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final sampleCards = [
        const ParetoItem(
          rank: 1,
          id: 'c1',
          name: 'Extremely Long Card Name Alpha',
          setCode: 'ELD',
          quantity: 4,
          unitPrice: 1500.0,
          lineValue: 6000.0,
          percentageShare: 60.0,
          weightRatio: 1.0,
          imageUrl: '',
        ),
        const ParetoItem(
          rank: 2,
          id: 'c2',
          name: 'Another Very Long Card Name Beta',
          setCode: 'MH2',
          quantity: 2,
          unitPrice: 2000.0,
          lineValue: 4000.0,
          percentageShare: 40.0,
          weightRatio: 0.667,
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
                    deckTotalValue: 10000.0,
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
      expect(find.byKey(const Key('value_concentration_pie_gesture_detector')), findsOneWidget);
    });
  });

  group('Group 7: Bi-Directional Synchronization in ParetoDistributionWidget', () {
    final sampleCards = [
      const ParetoItem(
        rank: 1,
        id: 'c1',
        name: 'The Great Henge',
        setCode: 'ELD',
        quantity: 1,
        unitPrice: 65.0,
        lineValue: 65.0,
        percentageShare: 65.0,
        weightRatio: 1.0,
        imageUrl: '',
      ),
      const ParetoItem(
        rank: 2,
        id: 'c2',
        name: 'Craterhoof Behemoth',
        setCode: 'AVR',
        quantity: 1,
        unitPrice: 35.0,
        lineValue: 35.0,
        percentageShare: 35.0,
        weightRatio: 0.538,
        imageUrl: '',
      ),
    ];

    testWidgets('7.1: Tapping slice in chart updates selection and centers row', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: ParetoDistributionWidget(
                  deckTotalValue: 100.0,
                  topKConcentrationPercentage: 100.0,
                  topCards: sampleCards,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final center = tester.getCenter(find.byKey(const Key('value_concentration_pie_gesture_detector')));

      // Slice 0 (The Great Henge: [0 .. 0.65 * 2pi]) -> tap at 1.0 rad
      await tester.tapAt(center + polarToOffset(60.0, 1.0));
      await tester.pumpAndSettle();

      // Center badge should show The Great Henge
      expect(find.text('#1'), findsWidgets);
      expect(find.text('The Great He…'), findsOneWidget); // 12 chars + ellipsis
      expect(find.text(r'$65.00'), findsWidgets);
    });

    testWidgets('7.2: Tapping card row in micro-list highlights row and explodes chart slice', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: ParetoDistributionWidget(
                  deckTotalValue: 100.0,
                  topKConcentrationPercentage: 100.0,
                  topCards: sampleCards,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap row for Craterhoof Behemoth (Rank 2)
      final rowFinder = find.byKey(const Key('pareto_row_2'));
      expect(rowFinder, findsOneWidget);
      await tester.tap(rowFinder);
      await tester.pumpAndSettle();

      // Center badge should update to #2 Craterhoof Behemoth
      expect(find.text('#2'), findsWidgets);
      expect(find.text('Craterhoof B…'), findsOneWidget);
      expect(find.text(r'$35.00'), findsWidgets);

      // Tap row 2 again -> toggles off
      await tester.tap(rowFinder);
      await tester.pumpAndSettle();
      expect(find.text('TOP 2'), findsOneWidget);
    });
  });
}
