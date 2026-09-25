import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/features/decks/presentation/widgets/proportional_bubble_scrollbar.dart';

void main() {
  group('ProportionalBubbleScrollbar Widget Tests', () {
    testWidgets('Renders sections proportionally without errors', (tester) async {
      int tapCount = 0;
      final sections = [
        ScrollbarSection(label: 'Commander', count: 1, onTap: () => tapCount++),
        ScrollbarSection(label: 'Creatures', count: 32, onTap: () => tapCount++),
        ScrollbarSection(label: 'Spells', count: 18, onTap: () => tapCount++),
        ScrollbarSection(label: 'Lands', count: 35, onTap: () => tapCount++),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 400,
              width: 30,
              child: ProportionalBubbleScrollbar(
                sections: sections,
                railWidth: 26,
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(ProportionalBubbleScrollbar), findsOneWidget);
    });

    testWidgets('Prevents negative constraints and RenderFlex overflow on extreme proportions (1 card vs 99 cards)', (tester) async {
      // 1 card on a 150px height yields a clamped 24.0px bubble.
      // Container margins or child text must never trigger negative constraints or overflow.
      final sections = [
        ScrollbarSection(label: 'Tiny', count: 1, onTap: () {}),
        ScrollbarSection(label: 'Huge', count: 99, onTap: () {}),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 150,
              width: 24,
              child: ProportionalBubbleScrollbar(
                sections: sections,
                railWidth: 24,
              ),
            ),
          ),
        ),
      );

      // Verify zero layout or assertion exceptions were thrown
      expect(tester.takeException(), isNull);
    });

    testWidgets('Handles empty sections and 0-count sections gracefully', (tester) async {
      // Empty list
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 300,
              width: 24,
              child: ProportionalBubbleScrollbar(
                sections: [],
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        find.descendant(
          of: find.byType(ProportionalBubbleScrollbar),
          matching: find.byType(Stack),
        ),
        findsNothing,
      );

      // List with only 0-count sections
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 300,
              width: 24,
              child: ProportionalBubbleScrollbar(
                sections: [
                  ScrollbarSection(label: 'Zero', count: 0, onTap: () {}),
                ],
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        find.descendant(
          of: find.byType(ProportionalBubbleScrollbar),
          matching: find.byType(Stack),
        ),
        findsNothing,
      );
    });

    testWidgets('Tapping bubble triggers both section.onTap and onSectionTap callbacks', (tester) async {
      bool sectionTapped = false;
      int? tappedIndex;

      final sections = [
        ScrollbarSection(
          label: 'Spells',
          count: 50,
          onTap: () => sectionTapped = true,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 300,
              width: 40,
              child: ProportionalBubbleScrollbar(
                sections: sections,
                onSectionTap: (idx) => tappedIndex = idx,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(GestureDetector).first);
      await tester.pump();

      expect(sectionTapped, isTrue);
      expect(tappedIndex, equals(0));
    });

    testWidgets('Rotated text in large sections scales safely with FittedBox', (tester) async {
      final sections = [
        ScrollbarSection(
          label: 'Very Long Section Label That Could Overflow',
          count: 100,
          onTap: () {},
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 200,
              width: 24,
              child: ProportionalBubbleScrollbar(
                sections: sections,
                railWidth: 24,
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Very Long Section Label That Could Overflow'), findsOneWidget);
    });

    // Feature 16 Tests: Crown icon and abbreviated labels
    testWidgets('Feature 16: Commander section renders upright Crown icon with FittedBox', (tester) async {
      final sections = [
        ScrollbarSection(
          label: 'Commander',
          count: 1,
          onTap: () {},
        ),
        ScrollbarSection(
          label: 'Creatures',
          count: 35,
          onTap: () {},
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 300,
              width: 26,
              child: ProportionalBubbleScrollbar(
                sections: sections,
                railWidth: 26,
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.workspace_premium_rounded), findsOneWidget);
      final iconWidget = tester.widget<Icon>(find.byIcon(Icons.workspace_premium_rounded));
      expect(iconWidget.color, equals(Colors.white));

      // Assert that Commander icon is inside a FittedBox without rotation
      final fittedBoxFinder = find.ancestor(
        of: find.byIcon(Icons.workspace_premium_rounded),
        matching: find.byType(FittedBox),
      );
      expect(fittedBoxFinder, findsOneWidget);

      // RotatedBox should NOT be an ancestor of the Crown icon
      final rotatedBoxAncestor = find.ancestor(
        of: find.byIcon(Icons.workspace_premium_rounded),
        matching: find.byType(RotatedBox),
      );
      expect(rotatedBoxAncestor, findsNothing);
    });

    testWidgets('Feature 16: Abbreviates standard MTG zone labels (Cr, L, Sp, A&E, PW)', (tester) async {
      final sections = [
        ScrollbarSection(label: 'Creatures', count: 20, onTap: () {}),
        ScrollbarSection(label: 'Lands', count: 20, onTap: () {}),
        ScrollbarSection(label: 'Spells', count: 20, onTap: () {}),
        ScrollbarSection(label: 'Artifacts & Enchantments', count: 20, onTap: () {}),
        ScrollbarSection(label: 'Planeswalkers', count: 20, onTap: () {}),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 500,
              width: 30,
              child: ProportionalBubbleScrollbar(
                sections: sections,
                railWidth: 26,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Cr'), findsOneWidget);
      expect(find.text('L'), findsOneWidget);
      expect(find.text('Sp'), findsOneWidget);
      expect(find.text('A&E'), findsOneWidget);
      expect(find.text('PW'), findsOneWidget);
    });

    // Feature 18 Tests: Minimum padding clamp with water-filling partition
    test('Feature 18: computeSectionHeights partitions rail with water-filling algorithm', () {
      // 100-card Commander deck: 1 commander, 99 mainboard on 300px rail
      final heights = ProportionalBubbleScrollbar.computeSectionHeights(
        counts: [1, 99],
        totalHeight: 300.0,
        minHeight: 24.0,
      );

      expect(heights.length, equals(2));
      expect(heights[0], equals(24.0)); // 1 card clamped to 24.0px
      expect(heights[1], equals(276.0)); // remaining 276.0px
      expect(heights[0] + heights[1], equals(300.0)); // Exact sum invariant
    });

    test('Feature 18: computeSectionHeights handles multiple clamped sections and dense rails', () {
      // Partner Commander deck: 1, 1, 98 on 400px rail
      final heightsPartner = ProportionalBubbleScrollbar.computeSectionHeights(
        counts: [1, 1, 98],
        totalHeight: 400.0,
        minHeight: 24.0,
      );
      expect(heightsPartner[0], equals(24.0));
      expect(heightsPartner[1], equals(24.0));
      expect(heightsPartner[2], equals(352.0));
      expect(heightsPartner.fold<double>(0, (s, h) => s + h), equals(400.0));

      // Dense layout: 50 sections on 300px rail (50 * 24 = 1200 > 300)
      final denseCounts = List.filled(50, 2);
      final heightsDense = ProportionalBubbleScrollbar.computeSectionHeights(
        counts: denseCounts,
        totalHeight: 300.0,
        minHeight: 24.0,
      );
      expect(heightsDense.length, equals(50));
      for (final h in heightsDense) {
        expect(h, equals(6.0)); // Equi-partitioned without overflow
      }
      expect(heightsDense.fold<double>(0, (s, h) => s + h), closeTo(300.0, 0.001));
    });

    testWidgets('Feature 18: 1-card category receives minimum 24px touch target height in widget', (tester) async {
      final sections = [
        ScrollbarSection(label: 'Commander', count: 1, onTap: () {}),
        ScrollbarSection(label: 'Mainboard', count: 99, onTap: () {}),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 300,
              width: 26,
              child: ProportionalBubbleScrollbar(
                sections: sections,
                railWidth: 26,
              ),
            ),
          ),
        ),
      );

      final bubble0 = tester.getRect(find.byKey(const Key('scrollbar_bubble_0')));
      expect(bubble0.height, greaterThanOrEqualTo(24.0));
    });

    // Feature 19 Tests: Active thumb indicator, drag-to-scrub, and double-tap jump
    testWidgets('Feature 19: Active thumb indicator renders and tracks scroll controller offset', (tester) async {
      final scrollController = ScrollController();
      final sections = [
        ScrollbarSection(label: 'Commander', count: 1, onTap: () {}),
        ScrollbarSection(label: 'Mainboard', count: 99, onTap: () {}),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 300,
              child: Row(
                children: [
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: 50,
                      itemExtent: 50,
                      itemBuilder: (context, i) => ListTile(title: Text('Item $i')),
                    ),
                  ),
                  SizedBox(
                    height: 300,
                    width: 26,
                    child: ProportionalBubbleScrollbar(
                      sections: sections,
                      controller: scrollController,
                      railWidth: 26,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('scrollbar_thumb')), findsOneWidget);
      final initialThumbRect = tester.getRect(find.byKey(const Key('scrollbar_thumb')));
      expect(initialThumbRect.top, equals(0.0));

      // Scroll the list down
      scrollController.jumpTo(500);
      await tester.pump();

      final scrolledThumbRect = tester.getRect(find.byKey(const Key('scrollbar_thumb')));
      expect(scrolledThumbRect.top, greaterThan(0.0));
      expect(scrolledThumbRect.bottom, lessThanOrEqualTo(300.0));
    });

    testWidgets('Feature 19: Drag-to-scrub jumps list offset proportionally', (tester) async {
      final scrollController = ScrollController();
      double? lastScrubOffset;
      final sections = [
        ScrollbarSection(label: 'Section 1', count: 50, onTap: () {}),
        ScrollbarSection(label: 'Section 2', count: 50, onTap: () {}),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 300,
              child: Row(
                children: [
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: 100,
                      itemExtent: 50,
                      itemBuilder: (context, i) => ListTile(title: Text('Item $i')),
                    ),
                  ),
                  SizedBox(
                    height: 300,
                    width: 26,
                    child: ProportionalBubbleScrollbar(
                      sections: sections,
                      controller: scrollController,
                      railWidth: 26,
                      onScrubUpdate: (offset) => lastScrubOffset = offset,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Drag from middle of rail
      final railCenter = tester.getCenter(find.byType(ProportionalBubbleScrollbar));
      final gesture = await tester.startGesture(railCenter);
      await gesture.moveBy(const Offset(0, 50));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(lastScrubOffset, isNotNull);
      expect(scrollController.offset, greaterThan(0.0));
    });

    testWidgets('Feature 19: Double-tapping bubble triggers double-tap callback', (tester) async {
      int doubleTapCount = 0;
      int? doubleTapSectionIndex;
      final sections = [
        ScrollbarSection(
          label: 'Spells',
          count: 50,
          onTap: () {},
          onDoubleTap: () => doubleTapCount++,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 300,
              width: 30,
              child: ProportionalBubbleScrollbar(
                sections: sections,
                onSectionDoubleTap: (idx) => doubleTapSectionIndex = idx,
              ),
            ),
          ),
        ),
      );

      final bubble = find.byKey(const Key('scrollbar_bubble_0'));
      await tester.tap(bubble);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(bubble);
      await tester.pump();

      expect(doubleTapCount, equals(1));
      expect(doubleTapSectionIndex, equals(0));
    });
  });
}
