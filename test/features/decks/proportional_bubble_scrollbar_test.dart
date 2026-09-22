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
      // 1 card on a 150px height yields a 1.5px bubble.
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
  });
}
