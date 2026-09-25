// Copyright (c) 2026 Countr. All rights reserved.
// Empirical Adversarial Stress Test Suite for DeckBuilderScreen & ManaCostBar.
// Tests constrained columns (80px, 60px, 40px, 25px), massive mana costs,
// and Fast-Draw playtester preview under extreme card scenarios.

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

  const progenitusCost = '{W}{W}{U}{U}{B}{B}{R}{R}{G}{G}'; // 10 symbols
  const urDragonCost = '{4}{W}{U}{B}{R}{G}'; // 6 symbols
  const gleemaxCost = '{1000000}'; // 1M generic symbol
  const reaperKingCost = '{2/W}{2/U}{2/B}{2/R}{2/G}'; // 5 twobrid symbols
  const synthetic20Cost =
      '{W}{U}{B}{R}{G}{W}{U}{B}{R}{G}{W}{U}{B}{R}{G}{W}{U}{B}{R}{G}'; // 20 symbols
  const synthetic50Cost =
      '{W}{U}{B}{R}{G}{W}{U}{B}{R}{G}{W}{U}{B}{R}{G}{W}{U}{B}{R}{G}'
      '{W}{U}{B}{R}{G}{W}{U}{B}{R}{G}{W}{U}{B}{R}{G}{W}{U}{B}{R}{G}'
      '{W}{U}{B}{R}{G}{W}{U}{B}{R}{G}'; // 50 symbols

  final testDeck = createTestDeck(
    id: 'deck-adversarial-mana',
    name: 'Adversarial Mana Stress Deck',
    format: 'Commander',
  );

  List<Map<String, dynamic>> makeExtremeDeckItems() {
    return [
      {
        'id': 'item-progenitus',
        'name': 'Progenitus',
        'board_zone': 'commander',
        'deck_quantity': 1,
        'acquired_price': 14.50,
        'dynamic_data': jsonEncode({
          'mana_cost': progenitusCost,
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
          'mana_cost': urDragonCost,
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
          'mana_cost': gleemaxCost,
          'cmc': 1000000,
          'type_line': 'Legendary Artifact',
          'rarity': 'rare',
        }),
      },
      {
        'id': 'item-reaper-king',
        'name': 'Reaper King',
        'board_zone': 'mainboard',
        'deck_quantity': 1,
        'acquired_price': 8.50,
        'dynamic_data': jsonEncode({
          'mana_cost': reaperKingCost,
          'cmc': 10,
          'type_line': 'Legendary Artifact Creature — Scarecrow',
          'rarity': 'rare',
        }),
      },
      {
        'id': 'item-synthetic-20',
        'name': 'Synthetic 20-Cost Titan',
        'board_zone': 'mainboard',
        'deck_quantity': 1,
        'acquired_price': 99.99,
        'dynamic_data': jsonEncode({
          'mana_cost': synthetic20Cost,
          'cmc': 20,
          'type_line': 'Artifact Creature — Colossus Juggernaut Construct',
          'rarity': 'mythic',
        }),
      },
      {
        'id': 'item-synthetic-50',
        'name': 'Synthetic 50-Cost Leviathan',
        'board_zone': 'mainboard',
        'deck_quantity': 1,
        'acquired_price': 150.00,
        'dynamic_data': jsonEncode({
          'mana_cost': synthetic50Cost,
          'cmc': 50,
          'type_line': 'Creature — Eldrazi Mega Titan',
          'rarity': 'mythic',
        }),
      },
      {
        'id': 'item-unrecognized-mana',
        'name': 'Malformed Cost Anomaly',
        'board_zone': 'mainboard',
        'deck_quantity': 1,
        'acquired_price': 0.50,
        'dynamic_data': jsonEncode({
          'mana_cost': '{NotASymbol}{X/Y/Z}{999}',
          'cmc': 0,
          'type_line': 'Sorcery',
          'rarity': 'common',
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

  group('DeckBuilderScreen - Empirical Trailing Column Width Constraints', () {
    final constraintWidths = [80.0, 60.0, 40.0, 25.0];
    final testCosts = {
      'Progenitus (10 symbols)': progenitusCost,
      'Ur-Dragon (6 symbols)': urDragonCost,
      'Gleemax (1M)': gleemaxCost,
      'Reaper King (5 twobrid)': reaperKingCost,
      'Synthetic 20-symbol': synthetic20Cost,
      'Synthetic 50-symbol': synthetic50Cost,
    };

    for (final width in constraintWidths) {
      group('Constraint maxWidth: ${width}px', () {
        for (final entry in testCosts.entries) {
          testWidgets('renders ${entry.key} within maxWidth ${width}px without RenderFlex overflow', (tester) async {
            // Emulate the exact widget hierarchy in DeckBuilderScreen card row trailing metrics
            await tester.pumpWidget(
              MaterialApp(
                home: Scaffold(
                  body: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: width),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: ManaCostBar(
                              manaCost: entry.value,
                              symbolSize: 11.5,
                            ),
                          ),
                          const SizedBox(height: 3),
                          const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '\$12.34',
                              style: TextStyle(fontSize: 11.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );

            await tester.pumpAndSettle();

            // Verification: Zero exceptions thrown during layout or paint
            expect(tester.takeException(), isNull);

            // Verify ManaCostBar is present and FittedBox is active
            final costBar = tester.widget<ManaCostBar>(find.byType(ManaCostBar));
            expect(costBar.enableFittedBox, isTrue);

            // Verify rendered size does not exceed the constraint width
            final constrainedBoxFinder = find.ancestor(
              of: find.byType(ManaCostBar),
              matching: find.byType(ConstrainedBox),
            );
            final renderBox = tester.renderObject<RenderBox>(constrainedBoxFinder.first);
            expect(renderBox.size.width, lessThanOrEqualTo(width));
          });
        }
      });
    }
  });

  group('DeckBuilderScreen - Full Screen Extreme Cards Stress Test', () {
    testWidgets('mounts all extreme cards under standard viewport (360x800) with zero RenderFlex overflows', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createSubject(deck: testDeck, items: makeExtremeDeckItems()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Verify all card names appear or can be scrolled to
      expect(find.text('Progenitus'), findsOneWidget);
      expect(find.text('The Ur-Dragon'), findsOneWidget);
      expect(find.text('Gleemax'), findsOneWidget);
      expect(find.text('Reaper King'), findsOneWidget);

      // Scroll to reveal the synthetic cost items
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(find.text('Synthetic 20-Cost Titan'), findsOneWidget);
      expect(find.text('Synthetic 50-Cost Leviathan'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('mounts all extreme cards under narrow viewport (320x640) with zero RenderFlex overflows', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createSubject(deck: testDeck, items: makeExtremeDeckItems()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Scroll through entire list to force layout of every single card row
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('mounts all extreme cards under ultra-narrow viewport (280x600) with zero RenderFlex overflows', (tester) async {
      tester.view.physicalSize = const Size(280, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createSubject(deck: testDeck, items: makeExtremeDeckItems()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('DeckBuilderScreen - Fast-Draw Playtester Preview Stress Testing', () {
    testWidgets('Fast-Draw modal with standard cards (Progenitus 10-symbol, Ur-Dragon, Gleemax, Reaper King) has zero RenderFlex overflows', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final standardExtremeItems = [
        {
          'id': 'item-progenitus',
          'name': 'Progenitus',
          'board_zone': 'mainboard',
          'deck_quantity': 2,
          'acquired_price': 14.50,
          'dynamic_data': jsonEncode({
            'mana_cost': progenitusCost, // 10 symbols
            'cmc': 10,
            'type_line': 'Legendary Creature — Hydra Avatar',
            'rarity': 'mythic',
          }),
        },
        {
          'id': 'item-ur-dragon',
          'name': 'The Ur-Dragon',
          'board_zone': 'mainboard',
          'deck_quantity': 2,
          'acquired_price': 22.00,
          'dynamic_data': jsonEncode({
            'mana_cost': urDragonCost, // 6 symbols
            'cmc': 9,
            'type_line': 'Legendary Creature — Dragon Avatar',
            'rarity': 'mythic',
          }),
        },
        {
          'id': 'item-gleemax',
          'name': 'Gleemax',
          'board_zone': 'mainboard',
          'deck_quantity': 2,
          'acquired_price': 5.00,
          'dynamic_data': jsonEncode({
            'mana_cost': gleemaxCost, // 1M
            'cmc': 1000000,
            'type_line': 'Legendary Artifact',
            'rarity': 'rare',
          }),
        },
        {
          'id': 'item-reaper-king',
          'name': 'Reaper King',
          'board_zone': 'mainboard',
          'deck_quantity': 2,
          'acquired_price': 8.50,
          'dynamic_data': jsonEncode({
            'mana_cost': reaperKingCost, // 5 twobrid
            'cmc': 10,
            'type_line': 'Legendary Artifact Creature — Scarecrow',
            'rarity': 'rare',
          }),
        },
      ];

      await tester.pumpWidget(createSubject(deck: testDeck, items: standardExtremeItems));
      await tester.pumpAndSettle();

      final fastDrawButton = find.byIcon(Icons.style_rounded);
      expect(fastDrawButton, findsOneWidget);
      await tester.tap(fastDrawButton);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Opening 7 Playtester'), findsOneWidget);

      final mulliganBtn = find.text('Mulligan (Draw New 7)');
      for (int i = 0; i < 3; i++) {
        await tester.tap(mulliganBtn);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('Fast-Draw modal with 20-symbol synthetic card has zero RenderFlex overflows due to ConstrainedBox on ManaCostBar', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final synthetic20Items = [
        {
          'id': 'item-synthetic-20',
          'name': 'Synthetic 20-Cost Titan',
          'board_zone': 'mainboard',
          'deck_quantity': 7,
          'acquired_price': 99.99,
          'dynamic_data': jsonEncode({
            'mana_cost': synthetic20Cost, // 20 symbols
            'cmc': 20,
            'type_line': 'Artifact Creature — Colossus',
            'rarity': 'mythic',
          }),
        },
      ];

      await tester.pumpWidget(createSubject(deck: testDeck, items: synthetic20Items));
      await tester.pumpAndSettle();

      final fastDrawButton = find.byIcon(Icons.style_rounded);
      await tester.tap(fastDrawButton);
      await tester.pumpAndSettle();

      // With ConstrainedBox(constraints: BoxConstraints(maxWidth: 100)) wrapping ManaCostBar in _FastDrawSheet,
      // the 20-symbol synthetic cost scales down to 100px, producing 0 RenderFlex overflows.
      expect(tester.takeException(), isNull);
      expect(find.text('Opening 7 Playtester'), findsOneWidget);
      expect(find.text('Synthetic 20-Cost Titan'), findsWidgets);
    });

    testWidgets('Fast-Draw modal with 50-symbol synthetic card has zero RenderFlex overflows due to ConstrainedBox on ManaCostBar', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final synthetic50Items = [
        {
          'id': 'item-synthetic-50-fastdraw',
          'name': 'Synthetic 50-Cost Leviathan',
          'board_zone': 'mainboard',
          'deck_quantity': 7,
          'acquired_price': 199.99,
          'dynamic_data': jsonEncode({
            'mana_cost': synthetic50Cost, // 50 symbols
            'cmc': 50,
            'type_line': 'Creature — Leviathan Avatar',
            'rarity': 'mythic',
          }),
        },
      ];

      await tester.pumpWidget(createSubject(deck: testDeck, items: synthetic50Items));
      await tester.pumpAndSettle();

      final fastDrawButton = find.byIcon(Icons.style_rounded);
      await tester.tap(fastDrawButton);
      await tester.pumpAndSettle();

      // With ConstrainedBox(constraints: BoxConstraints(maxWidth: 100)) wrapping ManaCostBar in _FastDrawSheet,
      // the 50-symbol synthetic cost scales down smoothly to 100px, producing 0 RenderFlex overflows.
      expect(tester.takeException(), isNull);
      expect(find.text('Opening 7 Playtester'), findsOneWidget);
      expect(find.text('Synthetic 50-Cost Leviathan'), findsWidgets);

      // Verify reshuffle / mulligan with 50-symbol cards maintains zero overflows
      final mulliganBtn = find.text('Mulligan (Draw New 7)');
      for (int i = 0; i < 3; i++) {
        await tester.tap(mulliganBtn);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('Fast-Draw modal with 50-symbol synthetic card on narrow 320x640 viewport has zero RenderFlex overflows', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final synthetic50Items = [
        {
          'id': 'item-synthetic-50-narrow',
          'name': 'Synthetic 50-Cost Leviathan',
          'board_zone': 'mainboard',
          'deck_quantity': 7,
          'acquired_price': 199.99,
          'dynamic_data': jsonEncode({
            'mana_cost': synthetic50Cost, // 50 symbols
            'cmc': 50,
            'type_line': 'Creature — Leviathan Avatar',
            'rarity': 'mythic',
          }),
        },
      ];

      await tester.pumpWidget(createSubject(deck: testDeck, items: synthetic50Items));
      await tester.pumpAndSettle();

      final fastDrawButton = find.byIcon(Icons.style_rounded);
      await tester.tap(fastDrawButton);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Opening 7 Playtester'), findsOneWidget);
      expect(find.text('Synthetic 50-Cost Leviathan'), findsWidgets);
    });

    testWidgets('Fast-Draw modal with 50-symbol synthetic card on ultra-narrow 280x600 viewport has zero RenderFlex overflows', (tester) async {
      tester.view.physicalSize = const Size(280, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final synthetic50Items = [
        {
          'id': 'item-synthetic-50-ultranarrow',
          'name': 'Synthetic 50-Cost Leviathan',
          'board_zone': 'mainboard',
          'deck_quantity': 7,
          'acquired_price': 199.99,
          'dynamic_data': jsonEncode({
            'mana_cost': synthetic50Cost, // 50 symbols
            'cmc': 50,
            'type_line': 'Creature — Leviathan Avatar',
            'rarity': 'mythic',
          }),
        },
      ];

      await tester.pumpWidget(createSubject(deck: testDeck, items: synthetic50Items));
      await tester.pumpAndSettle();

      final fastDrawButton = find.byIcon(Icons.style_rounded);
      await tester.tap(fastDrawButton);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Opening 7 Playtester'), findsOneWidget);
      expect(find.text('Synthetic 50-Cost Leviathan'), findsWidgets);
    });

    testWidgets('Fast-Draw modal with mixed 20-symbol, 50-symbol, and long title cards has zero RenderFlex overflows', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final mixedExtremeItems = [
        {
          'id': 'item-mix-1',
          'name': 'Extremely Long Named Legendary Artifact Creature From Another Realm',
          'board_zone': 'mainboard',
          'deck_quantity': 4,
          'acquired_price': 10.0,
          'dynamic_data': jsonEncode({
            'mana_cost': synthetic20Cost,
            'cmc': 20,
            'type_line': 'Legendary Artifact Creature — Elder Avatar Dragon',
          }),
        },
        {
          'id': 'item-mix-2',
          'name': 'Unfathomable Infinite Titan of Doom and Chaos Across Dimensions',
          'board_zone': 'mainboard',
          'deck_quantity': 4,
          'acquired_price': 50.0,
          'dynamic_data': jsonEncode({
            'mana_cost': synthetic50Cost,
            'cmc': 50,
            'type_line': 'Legendary Creature — Cosmic Leviathan God',
          }),
        },
      ];

      await tester.pumpWidget(createSubject(deck: testDeck, items: mixedExtremeItems));
      await tester.pumpAndSettle();

      final fastDrawButton = find.byIcon(Icons.style_rounded);
      await tester.tap(fastDrawButton);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Opening 7 Playtester'), findsOneWidget);

      final mulliganBtn = find.text('Mulligan (Draw New 7)');
      for (int i = 0; i < 3; i++) {
        await tester.tap(mulliganBtn);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });

  });
}

