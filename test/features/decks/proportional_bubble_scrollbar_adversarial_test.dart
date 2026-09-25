import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/decks/presentation/screens/deck_builder_screen.dart';
import 'package:countr/features/decks/presentation/widgets/proportional_bubble_scrollbar.dart';
import 'deck_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProportionalBubbleScrollbar Adversarial Stress Suite', () {
    // =========================================================================
    // 1. Mathematical Invariance & Water-Filling Partition Invariants
    // =========================================================================
    group('1. Mathematical Invariance & Water-Filling Partition', () {
      test('Invariance under extreme 1:99 ratio on varied rails', () {
        for (final railHeight in [600.0, 300.0, 200.0, 100.0, 50.0, 48.01, 48.0, 47.99, 24.0]) {
          final heights = ProportionalBubbleScrollbar.computeSectionHeights(
            counts: [1, 99],
            totalHeight: railHeight,
            minHeight: 24.0,
          );

          expect(heights.length, equals(2));
          final sum = heights.fold<double>(0.0, (acc, h) => acc + h);
          expect(sum, closeTo(railHeight, 1e-6), reason: 'Sum failed for railHeight=$railHeight');

          if (railHeight > 48.0) {
            expect(heights[0], equals(24.0), reason: 'Section 0 should clamp to minHeight');
            expect(heights[1], closeTo(railHeight - 24.0, 1e-6));
          } else {
            // Guard triggers: equi-partition
            expect(heights[0], closeTo(railHeight / 2, 1e-6));
            expect(heights[1], closeTo(railHeight / 2, 1e-6));
          }
        }
      });

      test('Invariance under extreme 1:200 ratio on varied rails', () {
        for (final railHeight in [800.0, 400.0, 200.0, 100.0, 49.0, 48.0]) {
          final heights = ProportionalBubbleScrollbar.computeSectionHeights(
            counts: [1, 200],
            totalHeight: railHeight,
            minHeight: 24.0,
          );

          expect(heights.length, equals(2));
          final sum = heights.fold<double>(0.0, (acc, h) => acc + h);
          expect(sum, closeTo(railHeight, 1e-6), reason: 'Sum failed for railHeight=$railHeight');

          if (railHeight > 48.0) {
            expect(heights[0], equals(24.0));
            expect(heights[1], closeTo(railHeight - 24.0, 1e-6));
          } else {
            expect(heights[0], closeTo(railHeight / 2, 1e-6));
            expect(heights[1], closeTo(railHeight / 2, 1e-6));
          }
        }
      });

      test('Invariance under 50 sections on 200px rail (dense rail guard)', () {
        // 50 * 24 = 1200 > 200 -> equi-partition guard
        final counts = List.generate(50, (i) => (i % 5) + 1);
        final heights = ProportionalBubbleScrollbar.computeSectionHeights(
          counts: counts,
          totalHeight: 200.0,
          minHeight: 24.0,
        );

        expect(heights.length, equals(50));
        for (final h in heights) {
          expect(h, equals(4.0));
        }
        final sum = heights.fold<double>(0.0, (acc, h) => acc + h);
        expect(sum, closeTo(200.0, 1e-6));
      });

      test('Fuzz: 1,000 randomized configurations verify mathematical conservation law', () {
        final rng = Random(42);
        for (int testRun = 0; testRun < 1000; testRun++) {
          final sectionCount = rng.nextInt(30) + 1; // 1 to 30 sections
          final counts = List.generate(sectionCount, (_) => rng.nextInt(200) + 1);
          final railHeight = rng.nextDouble() * 1200.0 + 10.0; // 10.0 to 1210.0 px
          const minHeight = 24.0;

          final heights = ProportionalBubbleScrollbar.computeSectionHeights(
            counts: counts,
            totalHeight: railHeight,
            minHeight: minHeight,
          );

          expect(heights.length, equals(sectionCount));
          final sum = heights.fold<double>(0.0, (acc, h) => acc + h);
          expect(sum, closeTo(railHeight, 1e-5),
              reason: 'Conservation law violated on run $testRun: sum=$sum vs totalHeight=$railHeight');

          // If rail is large enough to support all at minHeight, every section must be >= minHeight
          if (sectionCount * minHeight < railHeight) {
            for (int i = 0; i < sectionCount; i++) {
              expect(heights[i], greaterThanOrEqualTo(minHeight - 1e-6),
                  reason: 'Section $i height ${heights[i]} < minHeight $minHeight on run $testRun');
            }
          } else {
            // Otherwise all sections must be equi-partitioned
            final expected = railHeight / sectionCount;
            for (int i = 0; i < sectionCount; i++) {
              expect(heights[i], closeTo(expected, 1e-6),
                  reason: 'Dense partition mismatch on run $testRun');
            }
          }
        }
      });
    });

    // =========================================================================
    // 2. Drag Scrubbing, Double-Tap Jump & Active Thumb Synchronization
    // =========================================================================
    group('2. Drag Scrubbing, Double-Tap Jump & Active Thumb Synchronization', () {
      testWidgets('Drag scrubbing out-of-bounds clamps correctly to [0, maxScrollExtent]', (tester) async {
        final scrollController = ScrollController();
        final scrubOffsets = <double>[];
        final sections = [
          ScrollbarSection(label: 'Commander', count: 1, onTap: () {}),
          ScrollbarSection(label: 'Creatures', count: 50, onTap: () {}),
          ScrollbarSection(label: 'Lands', count: 49, onTap: () {}),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 400,
                child: Row(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: 100,
                        itemExtent: 50.0,
                        itemBuilder: (ctx, i) => Text('Row $i'),
                      ),
                    ),
                    SizedBox(
                      height: 400,
                      width: 26,
                      child: ProportionalBubbleScrollbar(
                        sections: sections,
                        controller: scrollController,
                        railWidth: 26,
                        onScrubUpdate: (offset) => scrubOffsets.add(offset),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        final maxScroll = scrollController.position.maxScrollExtent;
        expect(maxScroll, greaterThan(0));

        final railCenter = tester.getCenter(find.byType(ProportionalBubbleScrollbar));
        final gesture = await tester.startGesture(railCenter);

        // Drag violently upwards far past the rail top
        await gesture.moveBy(const Offset(0, -600));
        await tester.pump();
        expect(scrollController.offset, equals(0.0));
        expect(scrubOffsets.last, equals(0.0));

        // Drag violently downwards far past the rail bottom
        await gesture.moveBy(const Offset(0, 1200));
        await tester.pump();
        expect(scrollController.offset, equals(maxScroll));
        expect(scrubOffsets.last, equals(maxScroll));

        await gesture.up();
        await tester.pump();
      });

      testWidgets('Double-tap jump animates cleanly to target section depth', (tester) async {
        final scrollController = ScrollController();
        double? jumpTargetOffset;
        final sections = [
          ScrollbarSection(label: 'Commander', count: 1, onTap: () {}),
          ScrollbarSection(label: 'Lands', count: 99, onTap: () {}),
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
                        itemCount: 80,
                        itemExtent: 50.0,
                        itemBuilder: (ctx, i) => Text('Row $i'),
                      ),
                    ),
                    SizedBox(
                      height: 300,
                      width: 26,
                      child: ProportionalBubbleScrollbar(
                        sections: sections,
                        controller: scrollController,
                        railWidth: 26,
                        onDoubleTapJump: (offset) => jumpTargetOffset = offset,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        final scrollbarFinder = find.byType(ProportionalBubbleScrollbar);
        final topCenter = tester.getTopRight(scrollbarFinder) - const Offset(13, -150);

        // First tap
        await tester.tapAt(topCenter);
        await tester.pump(const Duration(milliseconds: 100));
        // Second tap within 350ms
        await tester.tapAt(topCenter);
        await tester.pumpAndSettle();

        expect(jumpTargetOffset, isNotNull);
        expect(jumpTargetOffset!, greaterThan(0.0));
        expect(scrollController.offset, equals(jumpTargetOffset));
      });

      testWidgets('Active thumb synchronization bounds remain within [0, totalHeight - 16] across scrolling', (tester) async {
        final scrollController = ScrollController();
        final sections = [
          ScrollbarSection(label: 'Sec 1', count: 10, onTap: () {}),
          ScrollbarSection(label: 'Sec 2', count: 90, onTap: () {}),
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
                        itemCount: 200,
                        itemExtent: 50.0,
                        itemBuilder: (ctx, i) => Text('Card $i'),
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

        final thumbFinder = find.byKey(const Key('scrollbar_thumb'));
        expect(thumbFinder, findsOneWidget);

        // 1. Initial top position
        var thumbRect = tester.getRect(thumbFinder);
        expect(thumbRect.top, equals(0.0));
        expect(thumbRect.bottom, equals(16.0));

        // 2. Jump to halfway
        final maxScroll = scrollController.position.maxScrollExtent;
        scrollController.jumpTo(maxScroll / 2);
        await tester.pump();

        thumbRect = tester.getRect(thumbFinder);
        expect(thumbRect.top, closeTo((300.0 - 16.0) / 2, 1.0));

        // 3. Jump to bottom
        scrollController.jumpTo(maxScroll);
        await tester.pump();

        thumbRect = tester.getRect(thumbFinder);
        expect(thumbRect.bottom, closeTo(300.0, 1.0));
        expect(thumbRect.top, closeTo(300.0 - 16.0, 1.0));
      });
    });

    // =========================================================================
    // 3. Layout Responsiveness & RenderFlex Overflow Assertion (300px & 320px)
    // =========================================================================
    group('3. Layout Responsiveness & Zero RenderFlex Overflow (300px & 320px)', () {
      testWidgets('DeckBuilderScreen on 300px viewport with 2.0x font scaling has ZERO overflows', (tester) async {
        tester.view.physicalSize = const Size(300, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final deck = createTestDeck(
          id: 'deck-adversarial-300px',
          name: 'Extremely Long Deck Title Under 300px Constraint',
          format: 'MTG Commander',
          wins: 142,
          losses: 89,
        );

        final items = <Map<String, dynamic>>[
          {
            'id': 'cmd-1',
            'name': 'The Ur-Dragon, Prime Dragon Avatar',
            'board_zone': 'Commander',
            'deck_quantity': 1,
            'vault_quantity': 1,
            'set_or_series': 'c17',
            'dynamic_data': jsonEncode({
              'mana_cost': '{4}{W}{U}{B}{R}{G}',
              'type_line': 'Legendary Creature — Dragon Avatar',
              'image_uris': {'small': 'https://cards.scryfall.io/small/1.jpg'},
            }),
            'current_market_price': 55.0,
            'is_proxy': 0,
          },
          for (int i = 1; i <= 30; i++)
            {
              'id': 'card-$i',
              'name': 'Creature Dragon Card #$i With Very Long Name',
              'board_zone': 'Creatures',
              'deck_quantity': 1,
              'vault_quantity': 1,
              'set_or_series': 'dtk',
              'dynamic_data': jsonEncode({
                'mana_cost': '{3}{R}{G}',
                'type_line': 'Creature — Dragon',
                'image_uris': {'small': 'https://cards.scryfall.io/small/2.jpg'},
              }),
              'current_market_price': 2.5,
              'is_proxy': 0,
            },
          for (int i = 1; i <= 20; i++)
            {
              'id': 'land-$i',
              'name': 'Basic Land #$i',
              'board_zone': 'Lands',
              'deck_quantity': 1,
              'vault_quantity': 4,
              'set_or_series': 'cmm',
              'dynamic_data': jsonEncode({
                'mana_cost': '',
                'type_line': 'Basic Land — Mountain',
                'image_uris': {'small': 'https://cards.scryfall.io/small/3.jpg'},
              }),
              'current_market_price': 0.25,
              'is_proxy': 0,
            },
        ];

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              deckItemsProvider(deck.id).overrideWith((ref) => Stream.value(items)),
            ],
            child: MaterialApp(
              home: MediaQuery(
                data: const MediaQueryData(
                  size: Size(300, 600),
                  textScaler: TextScaler.linear(2.0),
                ),
                child: DeckBuilderScreen(deck: deck),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Assert strictly zero RenderFlex or layout exceptions occurred
        expect(tester.takeException(), isNull, reason: 'RenderFlex overflow detected at 300px + 2.0x font scaling');
        expect(find.byType(DeckBuilderScreen), findsOneWidget);
        expect(find.byType(ProportionalBubbleScrollbar), findsOneWidget);
      });

      testWidgets('DeckBuilderScreen on 320px viewport with 2.0x font scaling and 1:99 extreme ratio has ZERO overflows', (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final deck = createTestDeck(
          id: 'deck-adversarial-320px',
          name: 'Massive 1:99 Commander Deck',
          format: 'MTG Commander',
          wins: 5,
          losses: 1,
        );

        final items = <Map<String, dynamic>>[
          {
            'id': 'cmd-1',
            'name': 'Solitary Commander',
            'board_zone': 'Commander',
            'deck_quantity': 1,
            'vault_quantity': 1,
            'set_or_series': 'mtg',
            'dynamic_data': jsonEncode({
              'mana_cost': '{W}{U}{B}{R}{G}',
              'type_line': 'Legendary Creature',
            }),
            'current_market_price': 10.0,
            'is_proxy': 0,
          },
          for (int i = 1; i <= 99; i++)
            {
              'id': 'main-$i',
              'name': 'Mainboard Card #$i',
              'board_zone': 'Mainboard',
              'deck_quantity': 1,
              'vault_quantity': 1,
              'set_or_series': 'mtg',
              'dynamic_data': jsonEncode({'mana_cost': '{1}'}),
              'current_market_price': 0.5,
              'is_proxy': 0,
            },
        ];

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              deckItemsProvider(deck.id).overrideWith((ref) => Stream.value(items)),
            ],
            child: MaterialApp(
              home: MediaQuery(
                data: const MediaQueryData(
                  size: Size(320, 568),
                  textScaler: TextScaler.linear(2.0),
                ),
                child: DeckBuilderScreen(deck: deck),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull, reason: 'RenderFlex overflow detected at 320px + 2.0x font scaling');
        expect(find.byType(DeckBuilderScreen), findsOneWidget);
        expect(find.byType(ProportionalBubbleScrollbar), findsOneWidget);
      });

      testWidgets('ProportionalBubbleScrollbar standalone on 300px constraint with 50 sections has ZERO overflows', (tester) async {
        final sections = List.generate(
          50,
          (i) => ScrollbarSection(
            label: 'Section $i',
            count: i + 1,
            onTap: () {},
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MediaQuery(
                data: const MediaQueryData(
                  size: Size(300, 500),
                  textScaler: TextScaler.linear(2.0),
                ),
                child: SizedBox(
                  height: 200,
                  width: 26,
                  child: ProportionalBubbleScrollbar(
                    sections: sections,
                    railWidth: 26,
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull, reason: 'RenderFlex or layout error on 50 sections on 200px rail');
        expect(find.byType(ProportionalBubbleScrollbar), findsOneWidget);
      });
    });
  });
}
