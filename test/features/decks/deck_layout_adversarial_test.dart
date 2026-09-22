import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/data/mock_deck_data.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/decks/presentation/screens/deck_builder_screen.dart';
import 'package:countr/features/decks/presentation/screens/decks_screen.dart';
import 'package:countr/features/decks/presentation/widgets/proportional_bubble_scrollbar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Helper to wrap widget in ProviderScope, Directionality, and custom MediaQuery (320px width & 2.0x text scale)
  Widget createAdversarialSubject({
    required Widget child,
    Size size = const Size(320, 568),
    double textScale = 2.0,
    List<Override> overrides = const [],
  }) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: child,
        ),
      ),
    );
  }

  group('Adversarial Layout Stress Tests', () {
    testWidgets('Stress 1: Ultra-narrow viewport (320px) + 2.0x text scale + ultra-long deck name (300 chars)', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final longName = 'A' * 150 + ' ' + 'SuperUltraMegaDeckWithExtremelyLongNameThatShouldNeverCrashTheRenderTree' * 3;
      final deck = Deck(
        id: 'deck-adversarial-1',
        name: longName,
        format: 'MTG Commander',
        createdAt: DateTime.now(),
        wins: 9999,
        losses: 8888,
        draws: 777,
      );

      await tester.pumpWidget(
        createAdversarialSubject(
          child: DeckBuilderScreen(deck: deck),
          size: const Size(320, 568),
          textScale: 2.0,
          overrides: [
            deckItemsProvider(deck.id).overrideWith(
              (ref) => Stream.value(MockDeckData.getDeckItems('deck-mock-1')),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'RenderFlex or layout exception occurred with 300-char name');
      expect(find.byType(DeckBuilderScreen), findsOneWidget);
    });

    testWidgets('Stress 2: 100-character format name in DeckBuilderScreen and DecksScreen under 320px width + 2.0x text scale', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final hundredCharFormat = 'Format_' + ('X' * 93);
      expect(hundredCharFormat.length, equals(100));

      final deck = Deck(
        id: 'deck-adversarial-2',
        name: 'Standard Deck',
        format: hundredCharFormat,
        createdAt: DateTime.now(),
        wins: 10,
        losses: 5,
        draws: 0,
      );

      // Test DeckBuilderScreen with 100-char format
      await tester.pumpWidget(
        createAdversarialSubject(
          child: DeckBuilderScreen(deck: deck),
          size: const Size(320, 568),
          textScale: 2.0,
          overrides: [
            deckItemsProvider(deck.id).overrideWith(
              (ref) => Stream.value(MockDeckData.getDeckItems('deck-mock-1')),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      final deckBuilderException = tester.takeException();
      print('DEBUG: Stress 2 DeckBuilder format exception: $deckBuilderException');
      expect(deckBuilderException, isNull, reason: 'Exception in DeckBuilderScreen with 100-char format: $deckBuilderException');
    });

    testWidgets('Stress 2b: DecksScreen under 320px width + 2.0x text scale (tabs & cards list)', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        createAdversarialSubject(
          child: const DecksScreen(),
          size: const Size(320, 568),
          textScale: 2.0,
        ),
      );
      await tester.pumpAndSettle();
      final decksScreenException = tester.takeException();
      print('DEBUG: Stress 2b DecksScreen exception: $decksScreenException');
      expect(decksScreenException, isNull, reason: 'Exception in DecksScreen with 320px & 2.0x text scale: $decksScreenException');
      expect(find.byType(DecksScreen), findsOneWidget);
    });

    testWidgets('Stress 3: Extreme section distributions: 1 card in Commander, 99 in Mainboard', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final items = <Map<String, dynamic>>[
        {
          'id': 'c-1',
          'name': 'Commander Card',
          'board_zone': 'Commander',
          'deck_quantity': 1,
          'vault_quantity': 1,
          'set_or_series': 'MTG',
          'dynamic_data': jsonEncode({'mana_cost': '{2}{W}{U}', 'cmc': 4.0}),
          'current_market_price': 25.0,
          'is_proxy': 0,
        },
        for (int i = 1; i <= 99; i++)
          {
            'id': 'm-$i',
            'name': 'Mainboard Card #$i',
            'board_zone': 'Mainboard',
            'deck_quantity': 1,
            'vault_quantity': 1,
            'set_or_series': 'MTG',
            'dynamic_data': jsonEncode({'mana_cost': '{1}{G}', 'cmc': 2.0}),
            'current_market_price': 1.0,
            'is_proxy': 0,
          },
      ];

      final deck = Deck(
        id: 'deck-1-99',
        name: 'Commander 1 vs 99',
        format: 'Commander',
        createdAt: DateTime.now(),
        wins: 1,
        losses: 0,
        draws: 0,
      );

      await tester.pumpWidget(
        createAdversarialSubject(
          child: DeckBuilderScreen(deck: deck),
          size: const Size(320, 568),
          textScale: 2.0,
          overrides: [
            deckItemsProvider(deck.id).overrideWith(
              (ref) => Stream.value(items),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'Exception on 1 vs 99 distribution');
      expect(find.text('COMMANDER'), findsOneWidget);
      expect(find.text('MAINBOARD'), findsOneWidget);
      expect(find.byType(ProportionalBubbleScrollbar), findsOneWidget);
    });

    testWidgets('Stress 4: Extreme distribution: 0 cards (empty deck) under 320px + 2.0x text scale', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final deck = Deck(
        id: 'deck-empty',
        name: 'Empty Deck With Zero Cards',
        format: 'MTG Standard',
        createdAt: DateTime.now(),
        wins: 0,
        losses: 0,
        draws: 0,
      );

      await tester.pumpWidget(
        createAdversarialSubject(
          child: DeckBuilderScreen(deck: deck),
          size: const Size(320, 568),
          textScale: 2.0,
          overrides: [
            deckItemsProvider(deck.id).overrideWith(
              (ref) => Stream.value([]),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'Exception on 0 cards empty deck');
      expect(find.textContaining('No cards in this deck yet'), findsOneWidget);
    });

    testWidgets('Stress 5: Extreme distribution: 50 distinct sections under 320px viewport + 2.0x text scale', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final items = <Map<String, dynamic>>[];
      for (int s = 1; s <= 50; s++) {
        items.add({
          'id': 'card-$s',
          'name': 'Card In Section $s',
          'board_zone': 'Section $s',
          'deck_quantity': 1,
          'vault_quantity': 1,
          'set_or_series': 'MTG',
          'dynamic_data': jsonEncode({'mana_cost': '{1}', 'cmc': 1.0}),
          'current_market_price': 1.5,
          'is_proxy': 0,
        });
      }

      final deck = Deck(
        id: 'deck-50-sections',
        name: 'Deck With 50 Distinct Sections',
        format: 'MTG Custom',
        createdAt: DateTime.now(),
        wins: 5,
        losses: 5,
        draws: 0,
      );

      await tester.pumpWidget(
        createAdversarialSubject(
          child: DeckBuilderScreen(deck: deck),
          size: const Size(320, 568),
          textScale: 2.0,
          overrides: [
            deckItemsProvider(deck.id).overrideWith(
              (ref) => Stream.value(items),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'Exception on 50 distinct sections');
      expect(find.byType(ProportionalBubbleScrollbar), findsOneWidget);
    });

    testWidgets('Stress 6: Fast-Draw Playtester under 320px viewport + 2.0x text scale with long mana costs and card names', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final items = <Map<String, dynamic>>[
        for (int i = 1; i <= 15; i++)
          {
            'id': 'fd-$i',
            'name': 'Extremely Long Card Name That Might Wrap Or Overflow The Row #$i',
            'board_zone': 'Mainboard',
            'deck_quantity': 1,
            'vault_quantity': 1,
            'set_or_series': 'MTG',
            'dynamic_data': jsonEncode({
              'mana_cost': '{3}{W}{U}{B}{R}{G}',
              'cmc': 8.0,
              'type_line': 'Legendary Creature — Elder Dragon Wizard Noble Warrior',
            }),
            'current_market_price': 50.0,
            'is_proxy': 0,
          },
      ];

      final deck = Deck(
        id: 'deck-fd-stress',
        name: 'Fast-Draw Stress Test Deck',
        format: 'Commander',
        createdAt: DateTime.now(),
        wins: 1,
        losses: 0,
        draws: 0,
      );

      await tester.pumpWidget(
        createAdversarialSubject(
          child: DeckBuilderScreen(deck: deck),
          size: const Size(320, 568),
          textScale: 2.0,
          overrides: [
            deckItemsProvider(deck.id).overrideWith(
              (ref) => Stream.value(items),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Clear any exception from DeckBuilderScreen rendering
      final initialException = tester.takeException();
      print('DEBUG: Stress 6 initial exception from DeckBuilder: $initialException');

      // Open Fast-Draw Playtester
      final fastDrawBtn = find.byIcon(Icons.style_rounded);
      expect(fastDrawBtn, findsOneWidget);
      await tester.tap(fastDrawBtn);
      await tester.pumpAndSettle();

      final modalException = tester.takeException();
      print('DEBUG: Stress 6 modal exception: $modalException');
      expect(modalException, isNull, reason: 'RenderFlex or layout exception in Fast-Draw Playtester under 320px & 2.0x text scale: $modalException');
      expect(find.text('Opening 7 Playtester'), findsOneWidget);

      // Tap Mulligan in-place
      final mulliganBtn = find.text('Mulligan (Draw New 7)');
      expect(mulliganBtn, findsOneWidget);
      await tester.tap(mulliganBtn);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'Exception on Mulligan in Fast-Draw under 320px & 2.0x text scale');

      // Close modal
      await tester.tap(find.byIcon(Icons.close).last);
      await tester.pumpAndSettle();
    });

    testWidgets('Stress 7: Visual Analytics modal under 320px viewport + 2.0x text scale with full mana curve & devotion', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final deck = Deck(
        id: 'deck-analytics-stress',
        name: 'Analytics Stress Deck',
        format: 'Commander',
        createdAt: DateTime.now(),
        wins: 2,
        losses: 1,
        draws: 0,
      );

      final fullAnalytics = DeckAnalytics(
        manaCurve: {0: 3, 1: 8, 2: 15, 3: 20, 4: 12, 5: 6, 6: 4, 7: 5},
        colorDevotion: {'W': 18, 'U': 14, 'B': 22, 'R': 10, 'G': 8, 'C': 5},
        colorProduction: {'W': 10, 'U': 10, 'B': 12, 'R': 8, 'G': 6},
        blingPercentage: 0.85,
      );

      await tester.pumpWidget(
        createAdversarialSubject(
          child: DeckBuilderScreen(deck: deck),
          size: const Size(320, 568),
          textScale: 2.0,
          overrides: [
            deckItemsProvider(deck.id).overrideWith(
              (ref) => Stream.value(MockDeckData.getDeckItems('deck-mock-1')),
            ),
            deckAnalyticsProvider(deck.id).overrideWith(
              (ref) => AsyncData(fullAnalytics),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Clear any exception from DeckBuilderScreen rendering
      final initialException = tester.takeException();
      print('DEBUG: Stress 7 initial exception from DeckBuilder: $initialException');

      // Open Visual Analytics modal
      final analyticsBtn = find.byIcon(Icons.analytics_rounded);
      expect(analyticsBtn, findsOneWidget);
      await tester.tap(analyticsBtn);
      await tester.pumpAndSettle();

      final modalException = tester.takeException();
      print('DEBUG: Stress 7 modal exception: $modalException');
      expect(modalException, isNull, reason: 'RenderFlex or layout exception in Visual Analytics under 320px & 2.0x text scale: $modalException');
      expect(find.text('Deck Visual Analytics'), findsOneWidget);

      // Close modal
      await tester.tap(find.byIcon(Icons.close).last);
      await tester.pumpAndSettle();
    });

    testWidgets('Stress 8: Scroll custom scroll view to collapse SliverAppBar on 320px viewport + 2.0x text scale', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final deck = Deck(
        id: 'deck-scroll-stress',
        name: 'Super Long Deck Name Collapsing Into Toolbar Mode On Narrow Viewport',
        format: 'Commander',
        createdAt: DateTime.now(),
        wins: 100,
        losses: 50,
        draws: 2,
      );

      await tester.pumpWidget(
        createAdversarialSubject(
          child: DeckBuilderScreen(deck: deck),
          size: const Size(320, 568),
          textScale: 2.0,
          overrides: [
            deckItemsProvider(deck.id).overrideWith(
              (ref) => Stream.value(MockDeckData.getDeckItems('deck-mock-1')),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Drag up by 300px to collapse SliverAppBar
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'Exception when collapsing SliverAppBar');

      // Drag back down
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 300));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'Exception when expanding SliverAppBar');
    });

    testWidgets('Stress 9: Extremely long section / zone name in _buildZoneHeader under 320px + 2.0x text scale', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final longZoneName = 'Super Ultra Mega Extended Zone Label That Stretches Beyond Standard Screen Limits';
      final items = <Map<String, dynamic>>[
        {
          'id': 'zone-item-1',
          'name': 'Test Card In Long Zone',
          'board_zone': longZoneName,
          'deck_quantity': 4,
          'vault_quantity': 4,
          'set_or_series': 'MTG',
          'dynamic_data': jsonEncode({'mana_cost': '{1}', 'cmc': 1.0}),
          'current_market_price': 2.0,
          'is_proxy': 0,
        },
      ];

      final deck = Deck(
        id: 'deck-zone-stress',
        name: 'Zone Header Stress',
        format: 'Modern',
        createdAt: DateTime.now(),
        wins: 1,
        losses: 0,
        draws: 0,
      );

      await tester.pumpWidget(
        createAdversarialSubject(
          child: DeckBuilderScreen(deck: deck),
          size: const Size(320, 568),
          textScale: 2.0,
          overrides: [
            deckItemsProvider(deck.id).overrideWith(
              (ref) => Stream.value(items),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'Exception on ultra long zone name in zone header');
    });

    testWidgets('Stress 10: Extremely long card name, huge price, and complex mana cost under 320px + 2.0x text scale', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final items = <Map<String, dynamic>>[
        {
          'id': 'extreme-card-1',
          'name': 'Asmoranomardicadaistinaculdacar The Ultimate Long Named Card In All Of Magic History',
          'board_zone': 'Main',
          'deck_quantity': 4,
          'vault_quantity': 4,
          'set_or_series': 'SUPER_LONG_SET_CODE',
          'dynamic_data': jsonEncode({
            'mana_cost': '{10}{W}{W}{U}{U}{B}{B}{R}{R}{G}{G}',
            'cmc': 20.0,
            'type_line': 'Legendary Creature — Human Wizard Noble Artificer Berserker',
          }),
          'current_market_price': 999999.99,
          'is_proxy': 1,
        },
      ];

      final deck = Deck(
        id: 'deck-card-tile-stress',
        name: 'Tile Stress',
        format: 'Modern',
        createdAt: DateTime.now(),
        wins: 0,
        losses: 0,
        draws: 0,
      );

      await tester.pumpWidget(
        createAdversarialSubject(
          child: DeckBuilderScreen(deck: deck),
          size: const Size(320, 568),
          textScale: 2.0,
          overrides: [
            deckItemsProvider(deck.id).overrideWith(
              (ref) => Stream.value(items),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final tileException = tester.takeException();
      print('DEBUG: Stress 10 tile exception: $tileException');
      expect(tileException, isNull, reason: 'Exception in card tile layout: $tileException');
    });
  });
}
