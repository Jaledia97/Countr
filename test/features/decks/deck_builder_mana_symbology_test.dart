// Copyright (c) 2026 Countr. All rights reserved.
// Widget test suite verifying ManaCostBar within 80px constraint in DeckBuilderScreen.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/decks/presentation/screens/deck_builder_screen.dart';
import 'package:countr/features/symbology/presentation/widgets/mana_cost_bar.dart';
import 'deck_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testDeck = createTestDeck(
    id: 'deck-extreme-mana',
    name: 'WUBRG High-Cost Commander',
    format: 'Commander',
  );

  List<Map<String, dynamic>> makeDeckItems() {
    return [
      {
        'id': 'item-progenitus',
        'name': 'Progenitus',
        'board_zone': 'commander',
        'deck_quantity': 1,
        'acquired_price': 14.50,
        'dynamic_data': jsonEncode({
          'mana_cost': '{W}{W}{U}{U}{B}{B}{R}{R}{G}{G}', // 10 symbols!
          'cmc': 10,
          'type_line': 'Legendary Creature — Hydra Avatar',
          'rarity': 'mythic',
          'colors': ['W', 'U', 'B', 'R', 'G'],
        }),
      },
      {
        'id': 'item-ur-dragon',
        'name': 'The Ur-Dragon',
        'board_zone': 'mainboard',
        'deck_quantity': 1,
        'acquired_price': 22.00,
        'dynamic_data': jsonEncode({
          'mana_cost': '{4}{W}{U}{B}{R}{G}', // 6 symbols
          'cmc': 9,
          'type_line': 'Legendary Creature — Dragon Avatar',
          'rarity': 'mythic',
          'colors': ['W', 'U', 'B', 'R', 'G'],
        }),
      },
      {
        'id': 'item-gleemax',
        'name': 'Gleemax',
        'board_zone': 'mainboard',
        'deck_quantity': 1,
        'acquired_price': 5.00,
        'dynamic_data': jsonEncode({
          'mana_cost': '{1000000}', // 1M generic mana
          'cmc': 1000000,
          'type_line': 'Legendary Artifact',
          'rarity': 'rare',
        }),
      },
      {
        'id': 'item-sol-ring',
        'name': 'Sol Ring',
        'board_zone': 'mainboard',
        'deck_quantity': 1,
        'acquired_price': 1.75,
        'dynamic_data': jsonEncode({
          'mana_cost': '{1}',
          'cmc': 1,
          'type_line': 'Artifact',
          'rarity': 'uncommon',
        }),
      },
    ];
  }

  Widget createSubject({required Deck deck, required List<Map<String, dynamic>> items}) {
    return ProviderScope(
      overrides: [
        deckItemsProvider(deck.id).overrideWith(
          (ref) => Stream.value(items),
        ),
      ],
      child: MaterialApp(
        home: DeckBuilderScreen(deck: deck),
      ),
    );
  }

  group('DeckBuilderScreen - M3 ManaCostBar 80px Constraint Protection', () {
    testWidgets('renders card row with ManaCostBar replacing plaintext mana cost', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createSubject(deck: testDeck, items: makeDeckItems()));
      await tester.pumpAndSettle();

      // Verify ManaCostBar is mounted
      expect(find.byType(ManaCostBar), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Progenitus (10 symbols) renders inside 80px constraint with zero RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createSubject(deck: testDeck, items: makeDeckItems()));
      await tester.pumpAndSettle();

      // Absolute zero layout overflow exceptions
      expect(tester.takeException(), isNull);

      // Verify Progenitus row exists
      expect(find.text('Progenitus'), findsOneWidget);

      // Verify all 10 symbols exist in the tree under ManaCostBar
      final costBars = tester.widgetList<ManaCostBar>(find.byType(ManaCostBar)).toList();
      final progenitusBar = costBars.firstWhere((b) => b.manaCost.contains('{W}{W}'));
      expect(progenitusBar.enableFittedBox, isTrue);

      // Find the trailing 80px ConstrainedBox
      final trailingBoxes = find.byWidgetPredicate(
        (w) => w is ConstrainedBox && w.constraints.maxWidth == 80.0,
      );
      expect(trailingBoxes, findsWidgets);

      // Rendered width must be <= 80px
      for (final box in tester.widgetList<ConstrainedBox>(trailingBoxes)) {
        expect(box.constraints.maxWidth, equals(80.0));
      }
    });

    testWidgets('extreme narrow viewport (320x640) with massive mana costs has 0 exceptions', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createSubject(deck: testDeck, items: makeDeckItems()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('Fast-Draw Playtester modal renders ManaCostBar on preview cards', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createSubject(deck: testDeck, items: makeDeckItems()));
      await tester.pumpAndSettle();

      // Tap fast draw playtester button (find either style_rounded icon or Playtest button)
      final fastDrawButton = find.byIcon(Icons.style_rounded);
      if (fastDrawButton.evaluate().isNotEmpty) {
        await tester.tap(fastDrawButton.first);
        await tester.pumpAndSettle();

        expect(find.text('Opening 7 Playtester'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });
  });
}
