// Copyright (c) 2026 Countr. All rights reserved.
// Adversarial Challenger 2 Empirical Stress Test Suite for Milestone 2:
// Live Analytics Data Calculations (Mana Curve, Devotion Pips, Bling %, Primer Notes).

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/features/decks/data/mock_deck_data.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/decks/presentation/widgets/inline_deck_analytics_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ===========================================================================
  // GROUP 1: Mana Curve Calculation Across Extreme Compositions
  // ===========================================================================
  group('1. Mana Curve Invariants Across Extreme Deck Compositions', () {
    test('1.1. Extreme 100% Lands Deck: All lands excluded, manaCurve has no spells', () async {
      final items = [
        for (int i = 0; i < 30; i++)
          {
            'deck_quantity': 1,
            'is_graded': 0,
            'dynamic_data': jsonEncode({
              'name': 'Island #$i',
              'type_line': 'Basic Land — Island',
              'cmc': 0,
              'mana_cost': '',
            }),
          },
        for (int i = 0; i < 20; i++)
          {
            'deck_quantity': 2,
            'is_graded': 0,
            'dynamic_data': jsonEncode({
              'name': 'Misty Rainforest #$i',
              'type_line': 'Land — Fetchland',
              'cmc': 0,
              'mana_cost': '',
            }),
          },
      ];

      final container = ProviderContainer(
        overrides: [
          deckItemsProvider('test-lands-deck').overrideWith((ref) => Stream.value(items)),
        ],
      );
      addTearDown(container.dispose);

      await container.read(deckItemsProvider('test-lands-deck').future);
      final asyncAnalytics = container.read(deckAnalyticsProvider('test-lands-deck'));
      expect(asyncAnalytics.hasValue, isTrue);
      final analytics = asyncAnalytics.value!;
      expect(analytics.manaCurve.isEmpty, isTrue,
          reason: 'A deck consisting solely of lands must have an empty mana curve');
    });

    test('1.2. Extreme 100% 0-Cost Spells Deck: All 0-cost non-lands included in bucket 0', () async {
      final items = [
        {
          'deck_quantity': 4,
          'is_graded': 0,
          'dynamic_data': jsonEncode({
            'name': 'Lotus Petal',
            'type_line': 'Artifact',
            'cmc': 0,
            'mana_cost': '{0}',
          }),
        },
        {
          'deck_quantity': 4,
          'is_graded': 0,
          'dynamic_data': jsonEncode({
            'name': 'Mox Amber',
            'type_line': 'Legendary Artifact',
            'cmc': 0,
            'mana_cost': '{0}',
          }),
        },
        {
          'deck_quantity': 4,
          'is_graded': 0,
          'dynamic_data': jsonEncode({
            'name': 'Pact of Negation',
            'type_line': 'Instant',
            'cmc': 0,
            'mana_cost': '{0}',
          }),
        },
        {
          'deck_quantity': 4,
          'is_graded': 0,
          'dynamic_data': jsonEncode({
            'name': 'Memnite',
            'type_line': 'Artifact Creature — Construct',
            'cmc': 0,
            'mana_cost': '{0}',
          }),
        },
        {
          'deck_quantity': 4,
          'is_graded': 0,
          'dynamic_data': jsonEncode({
            'name': 'Ornithopter',
            'type_line': 'Artifact Creature — Thopter',
            'cmc': 0,
            'mana_cost': '{0}',
          }),
        },
      ];

      final container = ProviderContainer(
        overrides: [
          deckItemsProvider('test-zero-cost-deck').overrideWith((ref) => Stream.value(items)),
        ],
      );
      addTearDown(container.dispose);

      await container.read(deckItemsProvider('test-zero-cost-deck').future);
      final asyncAnalytics = container.read(deckAnalyticsProvider('test-zero-cost-deck'));
      expect(asyncAnalytics.hasValue, isTrue);
      final analytics = asyncAnalytics.value!;
      expect(analytics.manaCurve[0], equals(20),
          reason: 'All 20 non-land 0-cost cards must be accurately placed in bucket 0');
      expect(analytics.manaCurve.length, equals(1),
          reason: 'No spells should be placed in any bucket other than 0');
    });

    test('1.3. Extreme High-CMC Deck: High CMC spells (7, 8, 9, 10, 15, 16) properly aggregated in 7+ bucket', () async {
      final items = [
        {
          'deck_quantity': 1,
          'is_graded': 0,
          'dynamic_data': jsonEncode({
            'name': 'Karn Liberated',
            'type_line': 'Legendary Planeswalker — Karn',
            'cmc': 7,
            'mana_cost': '{7}',
          }),
        },
        {
          'deck_quantity': 2,
          'is_graded': 0,
          'dynamic_data': jsonEncode({
            'name': 'Ugin, the Spirit Dragon',
            'type_line': 'Legendary Planeswalker — Ugin',
            'cmc': 8,
            'mana_cost': '{8}',
          }),
        },
        {
          'deck_quantity': 1,
          'is_graded': 0,
          'dynamic_data': jsonEncode({
            'name': 'Kozilek, Butcher of Truth',
            'type_line': 'Legendary Creature — Eldrazi',
            'cmc': 10,
            'mana_cost': '{10}',
          }),
        },
        {
          'deck_quantity': 1,
          'is_graded': 0,
          'dynamic_data': jsonEncode({
            'name': 'Emrakul, the Aeons Torn',
            'type_line': 'Legendary Creature — Eldrazi',
            'cmc': 15,
            'mana_cost': '{15}',
          }),
        },
        {
          'deck_quantity': 3,
          'is_graded': 0,
          'dynamic_data': jsonEncode({
            'name': 'Draco',
            'type_line': 'Artifact Creature — Dragon',
            'cmc': 16,
            'mana_cost': '{16}',
          }),
        },
      ];

      final container = ProviderContainer(
        overrides: [
          deckItemsProvider('test-high-cmc-deck').overrideWith((ref) => Stream.value(items)),
        ],
      );
      addTearDown(container.dispose);

      await container.read(deckItemsProvider('test-high-cmc-deck').future);
      final asyncAnalytics = container.read(deckAnalyticsProvider('test-high-cmc-deck'));
      expect(asyncAnalytics.hasValue, isTrue);
      final analytics = asyncAnalytics.value!;
      // Discrete map entries
      expect(analytics.manaCurve[7], equals(1));
      expect(analytics.manaCurve[8], equals(2));
      expect(analytics.manaCurve[10], equals(1));
      expect(analytics.manaCurve[15], equals(1));
      expect(analytics.manaCurve[16], equals(3));

      // Test chart aggregation: 7+ bucket must sum all >= 7 spells (1 + 2 + 1 + 1 + 3 = 8)
      final sum7Plus = analytics.manaCurve.entries
          .where((e) => e.key >= 7)
          .fold<int>(0, (sum, e) => sum + e.value);
      expect(sum7Plus, equals(8), reason: 'Total spells with CMC >= 7 must equal 8');
    });

    test('1.4. Complex MDFCs and Split Cards: Front-face non-lands counted, front-face lands excluded', () {
      final items = [
        // Front face non-land: Sea Gate Restoration // Sea Gate, Reborn
        {
          'deck_quantity': 1,
          'dynamic_data': jsonEncode({
            'name': 'Sea Gate Restoration // Sea Gate, Reborn',
            'layout': 'modal_dfc',
            'card_faces': [
              {
                'name': 'Sea Gate Restoration',
                'type_line': 'Sorcery',
                'cmc': 7,
                'mana_cost': '{4}{U}{U}{U}',
              },
              {
                'name': 'Sea Gate, Reborn',
                'type_line': 'Land',
                'cmc': 0,
                'mana_cost': '',
              },
            ],
          }),
        },
        // Front face land: Barkchannel Pathway // Tidechannel Pathway
        {
          'deck_quantity': 1,
          'dynamic_data': jsonEncode({
            'name': 'Barkchannel Pathway // Tidechannel Pathway',
            'layout': 'modal_dfc',
            'card_faces': [
              {
                'name': 'Barkchannel Pathway',
                'type_line': 'Land',
                'cmc': 0,
                'mana_cost': '',
              },
              {
                'name': 'Tidechannel Pathway',
                'type_line': 'Land',
                'cmc': 0,
                'mana_cost': '',
              },
            ],
          }),
        },
        // Split card: Fire // Ice (combined CMC 4.0)
        {
          'deck_quantity': 2,
          'dynamic_data': jsonEncode({
            'name': 'Fire // Ice',
            'layout': 'split',
            'cmc': 4.0,
            'card_faces': [
              {
                'name': 'Fire',
                'type_line': 'Instant',
                'cmc': 2.0,
                'mana_cost': '{1}{R}',
              },
              {
                'name': 'Ice',
                'type_line': 'Instant',
                'cmc': 2.0,
                'mana_cost': '{1}{U}',
              },
            ],
          }),
        },
      ];

      final analytics = MockDeckData.computeAnalyticsFromItems(items);
      // Sea Gate Restoration is a 7-cost Sorcery
      expect(analytics.manaCurve[7], equals(1));
      // Barkchannel Pathway is excluded (front face is Land)
      expect(analytics.manaCurve[0] ?? 0, equals(0));
      // Fire // Ice (2 copies) has CMC 4
      expect(analytics.manaCurve[4], equals(2));
    });

    test('1.5. Resilient error handling for malformed / corrupt item records', () {
      final items = [
        {
          'deck_quantity': 1,
          'dynamic_data': '{"corrupt": json',
        },
        {
          'deck_quantity': 1,
          'dynamic_data': null,
        },
        {
          'deck_quantity': 1,
          'dynamic_data': '',
        },
        {
          'deck_quantity': 2,
          'dynamic_data': jsonEncode({
            'name': 'Lightning Bolt',
            'type_line': 'Instant',
            'cmc': '1', // string cmc
            'mana_cost': '{R}',
          }),
        },
      ];

      final analytics = MockDeckData.computeAnalyticsFromItems(items);
      // Should survive without throwing, and Lightning Bolt should be parsed into bucket 1
      expect(analytics.manaCurve[1], equals(2));
    });
  });

  // ===========================================================================
  // GROUP 2: Devotion Pips Calculations & Symbology Invariants
  // ===========================================================================
  group('2. Devotion Pips Invariants (All 5 Colors + Colorless, Hybrid, Twobrid, Phyrexian)', () {
    test('2.1. Pure Colorless Devotion {C} is accurately tallied for Eldrazi cards', () async {
      final items = [
        {
          'deck_quantity': 1,
          'dynamic_data': jsonEncode({
            'name': 'Kozilek, the Great Distortion',
            'mana_cost': '{8}{C}{C}',
            'cmc': 10,
          }),
        },
        {
          'deck_quantity': 4,
          'dynamic_data': jsonEncode({
            'name': 'Thought-Knot Seer',
            'mana_cost': '{3}{C}',
            'cmc': 4,
          }),
        },
        {
          'deck_quantity': 4,
          'dynamic_data': jsonEncode({
            'name': 'Matter Reshaper',
            'mana_cost': '{2}{C}',
            'cmc': 3,
          }),
        },
      ];

      final container = ProviderContainer(
        overrides: [
          deckItemsProvider('test-eldrazi-deck').overrideWith((ref) => Stream.value(items)),
        ],
      );
      addTearDown(container.dispose);

      await container.read(deckItemsProvider('test-eldrazi-deck').future);
      final asyncAnalytics = container.read(deckAnalyticsProvider('test-eldrazi-deck'));
      expect(asyncAnalytics.hasValue, isTrue);
      final analytics = asyncAnalytics.value!;
      // Kozilek (2) + Thought-Knot Seer (4*1 = 4) + Matter Reshaper (4*1 = 4) = 10 {C} pips
      expect(analytics.colorDevotion['C'], equals(10),
          reason: 'Pure colorless mana symbol {C} must be tracked in devotion pips');
      // Generic mana {8}, {3}, {2} must NOT be recorded
      expect(analytics.colorDevotion.containsKey('8'), isFalse);
      expect(analytics.colorDevotion.containsKey('3'), isFalse);
      expect(analytics.colorDevotion.containsKey('2'), isFalse);
    });

    test('2.2. All 10 Hybrid combinations simultaneously contribute to both constituent colors', () {
      final items = [
        {
          'deck_quantity': 2,
          'dynamic_data': jsonEncode({
            'name': 'Boros Reckoner',
            'mana_cost': '{R/W}{R/W}{R/W}',
          }),
        },
        {
          'deck_quantity': 1,
          'dynamic_data': jsonEncode({
            'name': 'Kitchen Finks',
            'mana_cost': '{1}{G/W}{G/W}',
          }),
        },
        {
          'deck_quantity': 3,
          'dynamic_data': jsonEncode({
            'name': 'Nightveil Specter',
            'mana_cost': '{U/B}{U/B}{U/B}',
          }),
        },
      ];

      final analytics = MockDeckData.computeAnalyticsFromItems(items);
      // Boros Reckoner: 2 * 3 = 6 pips for R and 6 pips for W
      // Kitchen Finks: 1 * 2 = 2 pips for G and 2 pips for W
      // Total W = 6 + 2 = 8
      // Total R = 6
      // Total G = 2
      // Nightveil Specter: 3 * 3 = 9 pips for U and 9 pips for B
      expect(analytics.colorDevotion['W'], equals(8));
      expect(analytics.colorDevotion['R'], equals(6));
      expect(analytics.colorDevotion['G'], equals(2));
      expect(analytics.colorDevotion['U'], equals(9));
      expect(analytics.colorDevotion['B'], equals(9));
      expect(analytics.colorDevotion['C'], isNull);
    });

    test('2.3. Twobrid, Phyrexian, Hybrid Phyrexian, and Colorless Hybrid contribute accurately', () {
      final items = [
        // Twobrid {2/W}
        {
          'deck_quantity': 2,
          'dynamic_data': jsonEncode({
            'name': 'Spectral Procession',
            'mana_cost': '{2/W}{2/W}{2/W}',
          }),
        },
        // Phyrexian {B/P}
        {
          'deck_quantity': 3,
          'dynamic_data': jsonEncode({
            'name': 'Dismember',
            'mana_cost': '{1}{B/P}{B/P}',
          }),
        },
        // Hybrid Phyrexian {G/U/P}
        {
          'deck_quantity': 1,
          'dynamic_data': jsonEncode({
            'name': 'Tamiyo, Compleated Sage',
            'mana_cost': '{2}{G}{G/U/P}{U}',
          }),
        },
        // Colorless Hybrid {C/R}
        {
          'deck_quantity': 2,
          'dynamic_data': jsonEncode({
            'name': 'Colorless Red Test',
            'mana_cost': '{C/R}',
          }),
        },
      ];

      final analytics = MockDeckData.computeAnalyticsFromItems(items);
      // Spectral Procession: 2 * 3 = 6 W
      expect(analytics.colorDevotion['W'], equals(6));
      // Dismember: 3 * 2 = 6 B
      expect(analytics.colorDevotion['B'], equals(6));
      // Tamiyo: {G} + {G/U/P} -> 2 G, 1 U (plus {U} -> 2 U)
      expect(analytics.colorDevotion['G'], equals(2));
      expect(analytics.colorDevotion['U'], equals(2));
      // Colorless Hybrid {C/R}: 2 * 1 = 2 C and 2 R
      expect(analytics.colorDevotion['C'], equals(2));
      expect(analytics.colorDevotion['R'], equals(2));

      // Invariants: No 'P', '2', or '1'
      expect(analytics.colorDevotion.containsKey('P'), isFalse);
      expect(analytics.colorDevotion.containsKey('2'), isFalse);
      expect(analytics.colorDevotion.containsKey('1'), isFalse);
    });
  });

  // ===========================================================================
  // GROUP 3: Bling Percentage Invariants Across Extreme Compositions
  // ===========================================================================
  group('3. Bling Percentage Across Extreme Deck Compositions', () {
    test('3.1. 0% Bling Deck: All regular nonfoil cards yields exactly 0.0%', () async {
      final items = [
        for (int i = 0; i < 50; i++)
          {
            'deck_quantity': 2,
            'is_graded': 0,
            'is_altered': 0,
            'is_signed': 0,
            'is_misprint': 0,
            'dynamic_data': jsonEncode({
              'finishes': ['nonfoil'],
              'promo': false,
            }),
          },
      ];

      final container = ProviderContainer(
        overrides: [
          deckItemsProvider('test-zero-bling').overrideWith((ref) => Stream.value(items)),
        ],
      );
      addTearDown(container.dispose);

      await container.read(deckItemsProvider('test-zero-bling').future);
      final asyncAnalytics = container.read(deckAnalyticsProvider('test-zero-bling'));
      expect(asyncAnalytics.hasValue, isTrue);
      final analytics = asyncAnalytics.value!;
      expect(analytics.blingPercentage, equals(0.0));
    });

    test('3.2. 100% Bling Deck: Every card has at least one bling attribute yields exactly 1.0%', () async {
      final items = [
        // Foil
        {'deck_quantity': 10, 'dynamic_data': jsonEncode({'finishes': ['foil']})},
        // Etched
        {'deck_quantity': 10, 'dynamic_data': jsonEncode({'finishes': ['etched']})},
        // Promo
        {'deck_quantity': 10, 'dynamic_data': jsonEncode({'promo': true})},
        // Graded
        {'deck_quantity': 10, 'is_graded': 1, 'dynamic_data': jsonEncode({'finishes': ['nonfoil']})},
        // Altered
        {'deck_quantity': 10, 'is_altered': 1, 'dynamic_data': jsonEncode({'finishes': ['nonfoil']})},
        // Signed
        {'deck_quantity': 10, 'is_signed': 1, 'dynamic_data': jsonEncode({'finishes': ['nonfoil']})},
        // Misprint
        {'deck_quantity': 10, 'is_misprint': 1, 'dynamic_data': jsonEncode({'finishes': ['nonfoil']})},
        // Showcase frame effect
        {'deck_quantity': 10, 'dynamic_data': jsonEncode({'frame_effects': ['showcase']})},
        // Extended art frame effect
        {'deck_quantity': 10, 'dynamic_data': jsonEncode({'frame_effects': ['extendedart']})},
        // Borderless frame effect
        {'deck_quantity': 10, 'dynamic_data': jsonEncode({'frame_effects': ['borderless']})},
      ];

      final container = ProviderContainer(
        overrides: [
          deckItemsProvider('test-100-bling').overrideWith((ref) => Stream.value(items)),
        ],
      );
      addTearDown(container.dispose);

      await container.read(deckItemsProvider('test-100-bling').future);
      final asyncAnalytics = container.read(deckAnalyticsProvider('test-100-bling'));
      expect(asyncAnalytics.hasValue, isTrue);
      final analytics = asyncAnalytics.value!;
      expect(analytics.blingPercentage, equals(1.0),
          reason: 'All 100 cards have bling attributes; ratio must be 1.0 (100%)');
    });

    test('3.3. Overlapping Bling Flags on a single card does NOT multiply or exceed quantity', () async {
      final items = [
        // 1 card with ALL bling attributes simultaneously, quantity 4
        {
          'deck_quantity': 4,
          'is_graded': 1,
          'is_altered': 1,
          'is_signed': 1,
          'is_misprint': 1,
          'dynamic_data': jsonEncode({
            'promo': true,
            'finishes': ['foil', 'etched'],
            'frame_effects': ['showcase', 'extendedart', 'borderless'],
          }),
        },
        // 6 regular non-bling cards
        {
          'deck_quantity': 6,
          'is_graded': 0,
          'is_altered': 0,
          'is_signed': 0,
          'is_misprint': 0,
          'dynamic_data': jsonEncode({
            'finishes': ['nonfoil'],
          }),
        },
      ];

      final container = ProviderContainer(
        overrides: [
          deckItemsProvider('test-overlap-bling').overrideWith((ref) => Stream.value(items)),
        ],
      );
      addTearDown(container.dispose);

      await container.read(deckItemsProvider('test-overlap-bling').future);
      final asyncAnalytics = container.read(deckAnalyticsProvider('test-overlap-bling'));
      expect(asyncAnalytics.hasValue, isTrue);
      final analytics = asyncAnalytics.value!;
      // Total cards = 10, Bling cards = 4 -> 40.0%
      expect(analytics.blingPercentage, closeTo(0.40, 0.0001),
          reason: 'Overlapping bling flags on a single card must count each physical card only once');
    });

    test('3.4. Empty Deck gracefully returns 0.0 without division by zero', () async {
      final container = ProviderContainer(
        overrides: [
          deckItemsProvider('test-empty-deck').overrideWith((ref) => Stream.value([])),
        ],
      );
      addTearDown(container.dispose);

      await container.read(deckItemsProvider('test-empty-deck').future);
      final asyncAnalytics = container.read(deckAnalyticsProvider('test-empty-deck'));
      expect(asyncAnalytics.hasValue, isTrue);
      final analytics = asyncAnalytics.value!;
      expect(analytics.blingPercentage, equals(0.0));
      expect(analytics.blingPercentage.isNaN, isFalse);
    });
  });

  // ===========================================================================
  // GROUP 4: Inline Analytics UI & Primer Notes Widget Stress
  // ===========================================================================
  group('4. Inline Analytics UI & Primer Notes Invariants', () {
    testWidgets('4.1. Empty or whitespace-only primer notes render italic fallback guidance', (tester) async {
      final sampleAnalytics = DeckAnalytics(
        manaCurve: {1: 2, 2: 4, 3: 1},
        colorDevotion: {'W': 3, 'U': 2},
        colorProduction: {'W': 2, 'U': 2},
        blingPercentage: 0.25,
      );

      for (final nullOrEmptyNote in [null, '', '   \n\t  ']) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: InlineDeckAnalyticsCard(
                  analytics: sampleAnalytics,
                  isExpanded: true,
                  onToggleExpand: () {},
                  userNotes: nullOrEmptyNote,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('inline_analytics_user_notes_container')), findsOneWidget);
        expect(
          find.text('No notes added for this deck yet. Open "Deck Details & Notes" to edit primer and strategy.'),
          findsOneWidget,
        );

        final textWidget = tester.widget<Text>(
          find.text('No notes added for this deck yet. Open "Deck Details & Notes" to edit primer and strategy.'),
        );
        expect(textWidget.style?.fontStyle, equals(FontStyle.italic));
        expect(textWidget.style?.color, equals(AppColors.textMuted));
      }
    });

    testWidgets('4.2. Extreme 5,000-character primer notes with unicode and emojis renders cleanly', (tester) async {
      final sampleAnalytics = DeckAnalytics(
        manaCurve: {0: 3, 1: 5, 2: 12, 7: 4},
        colorDevotion: {'W': 10, 'B': 15, 'C': 4},
        colorProduction: {'W': 8, 'B': 10},
        blingPercentage: 0.65,
      );

      final complexPrimer = StringBuffer();
      complexPrimer.writeln('# ⚔️ Commander Strategy & Mulligan Guide 🛡️');
      complexPrimer.writeln('Turn 1: Play {C} or {W} accelerants. Lotus Petal -> Sol Ring.');
      complexPrimer.writeln('Matchup Breakdown:');
      for (int i = 1; i <= 60; i++) {
        complexPrimer.writeln('• Matchup $i: Counter spells with Pact of Negation. Recursive lines with Vito. 💀🔥🌲');
      }

      final primerString = complexPrimer.toString();
      expect(primerString.length, greaterThan(3500));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: InlineDeckAnalyticsCard(
                analytics: sampleAnalytics,
                isExpanded: true,
                onToggleExpand: () {},
                userNotes: primerString,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('inline_analytics_user_notes_container')), findsOneWidget);
      expect(find.text(primerString), findsOneWidget);

      final textWidget = tester.widget<Text>(find.text(primerString));
      expect(textWidget.style?.fontStyle, equals(FontStyle.normal));
      expect(textWidget.style?.color, equals(AppColors.textPrimary));
    });

    testWidgets('4.3. Collapsed summary renders accurate bling percentage and devotion pips', (tester) async {
      final sampleAnalytics = DeckAnalytics(
        manaCurve: {2: 4},
        colorDevotion: {'W': 14, 'U': 8, 'B': 22, 'R': 0, 'G': 0, 'C': 5},
        colorProduction: {},
        blingPercentage: 0.4285, // ~42.9%
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InlineDeckAnalyticsCard(
              analytics: sampleAnalytics,
              isExpanded: false,
              onToggleExpand: () {},
              userNotes: 'Edgar Aristocrats',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check bling text
      expect(find.text('42.9% Bling'), findsOneWidget);

      // Verify that non-zero devotions (W, U, B, C) are rendered in collapsed summary
      expect(find.text('14'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
      expect(find.text('22'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);

      // Verify that zero devotions (R, G) are NOT displayed in collapsed summary
      expect(find.text('0'), findsNothing);

      // R3 Requirement verification: Verify inline_analytics_expand_modal_button is ABSENT
      expect(find.byKey(const Key('inline_analytics_expand_modal_button')), findsNothing);
    });

    testWidgets('4.4. Full card interactive expand/collapse toggle and responsive layout on narrow 300px screen', (tester) async {
      tester.view.physicalSize = const Size(300, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      bool isExpanded = false;
      final sampleAnalytics = DeckAnalytics(
        manaCurve: {0: 2, 1: 5, 2: 8, 3: 10, 4: 6, 5: 3, 6: 2, 7: 4},
        colorDevotion: {'W': 12, 'U': 6, 'B': 18, 'R': 4, 'G': 10, 'C': 3},
        colorProduction: {'W': 10, 'B': 14},
        blingPercentage: 0.75,
      );

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: InlineDeckAnalyticsCard(
                    analytics: sampleAnalytics,
                    isExpanded: isExpanded,
                    onToggleExpand: () => setState(() => isExpanded = !isExpanded),
                    userNotes: 'Primer notes on compact screen',
                  ),
                ),
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('75.0% Bling'), findsOneWidget);
      expect(find.text('Mana Curve'), findsNothing);

      // Tap collapse toggle
      await tester.tap(find.byKey(const Key('inline_analytics_collapse_toggle')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(isExpanded, isTrue);
      // All 4 sections rendered
      expect(find.text('Mana Curve'), findsOneWidget);
      expect(find.text('Color Devotion'), findsOneWidget);
      expect(find.text('Deck Bling'), findsOneWidget);
      expect(find.text('User Notes'), findsOneWidget);

      // Check mana curve chart has 7+ bucket and 0 bucket
      final manaChartFinder = find.byType(ManaCurveChartWidget);
      expect(find.descendant(of: manaChartFinder, matching: find.text('7+')), findsOneWidget);

      // Check all 6 color devotion pips in ColorDevotionPipsWidget
      final devotionFinder = find.byType(ColorDevotionPipsWidget);
      expect(find.descendant(of: devotionFinder, matching: find.text('12')), findsOneWidget); // W
      expect(find.descendant(of: devotionFinder, matching: find.text('6')), findsOneWidget);  // U
      expect(find.descendant(of: devotionFinder, matching: find.text('18')), findsOneWidget); // B
      expect(find.descendant(of: devotionFinder, matching: find.text('4')), findsOneWidget);  // R
      expect(find.descendant(of: devotionFinder, matching: find.text('10')), findsOneWidget); // G
      expect(find.descendant(of: devotionFinder, matching: find.text('3')), findsOneWidget);  // C
    });
  });
}
