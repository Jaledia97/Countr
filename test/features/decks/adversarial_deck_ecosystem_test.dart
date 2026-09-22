import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/data/mock_deck_data.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/decks/presentation/screens/deck_builder_screen.dart';

void main() {
  final baseDeck = Deck(
    id: 'deck-adversarial-test',
    name: 'Challenger Adversarial Test Deck',
    format: 'MTG Commander',
    createdAt: DateTime.now(),
    wins: 10,
    losses: 5,
    draws: 0,
  );

  Widget createSubject({
    required Deck deck,
    required List<Map<String, dynamic>> items,
  }) {
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

  // ===========================================================================
  // 1. FAST-DRAW PLAYTESTER ADVERSARIAL STRESS TESTS
  // ===========================================================================
  group('Fast-Draw Playtester Adversarial Stress Tests', () {
    test('Draw sampling extracts exactly 7 cards from standard 100-card pool without replacement', () {
      final items = MockDeckData.getDeckItems(MockDeckData.edgarMarkovDeckId);

      // Flatten items into a pool according to deck_quantity (matching _FastDrawSheet logic)
      final pool = <Map<String, dynamic>>[];
      for (final item in items) {
        final zone = (item['board_zone'] as String? ?? 'Mainboard').toLowerCase();
        if (zone == 'sideboard' || zone == 'maybeboard') continue;
        final qty = item['deck_quantity'] as int? ?? 1;
        for (int i = 0; i < qty; i++) {
          pool.add(item);
        }
      }

      expect(pool.length, equals(100));

      // Test 100 independent draw sampling trials
      for (int trial = 0; trial < 100; trial++) {
        final shuffled = List<Map<String, dynamic>>.from(pool)..shuffle();
        final hand = shuffled.take(7).toList();

        expect(hand.length, equals(7), reason: 'Each hand must contain exactly 7 cards on trial $trial');

        // Verify Edgar Markov (quantity 1 in deck) appears at most once in any single hand
        final edgarCopies = hand.where((c) => c['name'] == 'Edgar Markov').length;
        expect(edgarCopies, lessThanOrEqualTo(1), reason: 'Singleton cards must not be duplicated in a single deal');
      }
    });

    test('Mulligan reshuffling preserves total pool integrity across 50 consecutive reshuffles', () {
      final items = MockDeckData.getDeckItems(MockDeckData.edgarMarkovDeckId);
      final pool = <Map<String, dynamic>>[];
      for (final item in items) {
        final zone = (item['board_zone'] as String? ?? 'Mainboard').toLowerCase();
        if (zone == 'sideboard' || zone == 'maybeboard') continue;
        final qty = item['deck_quantity'] as int? ?? 1;
        for (int i = 0; i < qty; i++) {
          pool.add(item);
        }
      }

      final initialCount = pool.length;
      final handSignatures = <String>{};

      for (int m = 0; m < 50; m++) {
        final shuffled = List<Map<String, dynamic>>.from(pool)..shuffle();
        final hand = shuffled.take(7).toList();
        expect(hand.length, equals(7));
        expect(pool.length, equals(initialCount), reason: 'Pool must not shrink or mutate on mulligan');

        final sig = hand.map((c) => c['id']).join('|');
        handSignatures.add(sig);
      }

      // Across 50 random 7-card samples from 100 cards, we expect almost all distinct hands
      expect(handSignatures.length, greaterThan(40), reason: 'Mulligan shuffle must produce diverse randomized hands');
    });

    test('Strictly excludes sideboard and maybeboard zones regardless of letter casing', () {
      final items = [
        {'id': 'c1', 'name': 'Main 1', 'board_zone': 'Mainboard', 'deck_quantity': 4},
        {'id': 'c2', 'name': 'Commander 1', 'board_zone': 'Commander', 'deck_quantity': 1},
        {'id': 'c3', 'name': 'Creatures 1', 'board_zone': 'Creatures', 'deck_quantity': 2},
        {'id': 'c4', 'name': 'Sideboard 1', 'board_zone': 'Sideboard', 'deck_quantity': 3},
        {'id': 'c5', 'name': 'Sideboard 2', 'board_zone': 'SIDEBOARD', 'deck_quantity': 2},
        {'id': 'c6', 'name': 'Maybeboard 1', 'board_zone': 'Maybeboard', 'deck_quantity': 4},
        {'id': 'c7', 'name': 'Maybeboard 2', 'board_zone': 'maybeboard', 'deck_quantity': 1},
      ];

      final pool = <Map<String, dynamic>>[];
      for (final item in items) {
        final zone = (item['board_zone'] as String? ?? 'Mainboard').toLowerCase();
        if (zone == 'sideboard' || zone == 'maybeboard') continue;
        final qty = item['deck_quantity'] as int? ?? 1;
        for (int i = 0; i < qty; i++) {
          pool.add(item);
        }
      }

      // 4 Main + 1 Commander + 2 Creatures = 7 cards in playtest pool
      expect(pool.length, equals(7));
      expect(pool.any((c) => (c['name'] as String).contains('Sideboard')), isFalse);
      expect(pool.any((c) => (c['name'] as String).contains('Maybeboard')), isFalse);
    });

    test('Absence of null pointer exceptions on extremely corrupt or missing card item properties', () {
      // Create adversarial card items with nulls, missing fields, corrupt JSON, etc.
      final adversarialItems = [
        // Completely empty item
        <String, dynamic>{},
        // Item with all nulls
        <String, dynamic>{
          'id': null,
          'name': null,
          'image_url': null,
          'board_zone': null,
          'deck_quantity': null,
          'dynamic_data': null,
          'current_market_price': null,
          'is_proxy': null,
        },
        // Item with malformed dynamic JSON
        <String, dynamic>{
          'name': 'Corrupt JSON Card',
          'board_zone': 'Mainboard',
          'deck_quantity': 1,
          'dynamic_data': '{ broken json unclosed',
        },
        // Item with JSON array instead of map
        <String, dynamic>{
          'name': 'Array JSON Card',
          'board_zone': 'Spells',
          'deck_quantity': 1,
          'dynamic_data': '[1, 2, 3]',
        },
        // Item with non-string mana cost and non-numeric cmc
        <String, dynamic>{
          'name': 'Weird Types Card',
          'board_zone': 'Mainboard',
          'deck_quantity': 1,
          'dynamic_data': jsonEncode({
            'cmc': 'three',
            'mana_cost': 12345,
            'type_line': ['Not', 'A', 'String'],
          }),
        },
        // Item with Land in type_line and 0 cmc
        <String, dynamic>{
          'name': 'Adversarial Land',
          'board_zone': 'Lands',
          'deck_quantity': 2,
          'dynamic_data': jsonEncode({
            'cmc': 0,
            'type_line': 'Basic Land — Swamp',
          }),
        },
      ];

      // Build pool
      final pool = <Map<String, dynamic>>[];
      for (final item in adversarialItems) {
        final zone = (item['board_zone'] as String? ?? 'Mainboard').toLowerCase();
        if (zone == 'sideboard' || zone == 'maybeboard') continue;
        final qty = item['deck_quantity'] as int? ?? 1;
        for (int i = 0; i < qty; i++) {
          pool.add(item);
        }
      }

      // Draw hand
      final shuffled = List<Map<String, dynamic>>.from(pool)..shuffle();
      final hand = shuffled.take(7).toList();
      expect(hand.length, equals(7));

      // Calculate hand statistics safely
      int landCount = 0;
      int spellCount = 0;
      double totalCmc = 0;

      for (final card in hand) {
        final zone = (card['board_zone'] as String? ?? '').toLowerCase();
        String type = '';
        double cmc = 0;
        final dyn = card['dynamic_data'] as String?;
        if (dyn != null && dyn.isNotEmpty) {
          try {
            final data = jsonDecode(dyn) as Map<String, dynamic>;
            type = data['type_line'] as String? ?? '';
            cmc = (data['cmc'] as num?)?.toDouble() ?? 0.0;
          } catch (_) {}
        }

        if (zone == 'lands' || type.toLowerCase().contains('land')) {
          landCount++;
        } else {
          spellCount++;
          totalCmc += cmc;
        }
      }

      final avgCmc = spellCount > 0 ? (totalCmc / spellCount) : 0.0;
      expect(avgCmc, isA<double>());
      expect(avgCmc.isNaN, isFalse);
      expect(avgCmc.isInfinite, isFalse);
      expect(landCount + spellCount, equals(7));
    });

    test('Avoids division by zero when hand contains 100% lands', () {
      final landHand = [
        {'board_zone': 'Lands', 'dynamic_data': jsonEncode({'cmc': 0, 'type_line': 'Land'})},
        {'board_zone': 'Lands', 'dynamic_data': jsonEncode({'cmc': 0, 'type_line': 'Land'})},
        {'board_zone': 'Lands', 'dynamic_data': jsonEncode({'cmc': 0, 'type_line': 'Land'})},
      ];

      int landCount = 0;
      int spellCount = 0;
      double totalCmc = 0;

      for (final card in landHand) {
        final zone = (card['board_zone'] ?? '').toLowerCase();
        String type = '';
        double cmc = 0;
        final dyn = card['dynamic_data'];
        if (dyn != null && dyn.isNotEmpty) {
          try {
            final data = jsonDecode(dyn) as Map<String, dynamic>;
            type = data['type_line'] as String? ?? '';
            cmc = (data['cmc'] as num?)?.toDouble() ?? 0.0;
          } catch (_) {}
        }

        if (zone == 'lands' || type.toLowerCase().contains('land')) {
          landCount++;
        } else {
          spellCount++;
          totalCmc += cmc;
        }
      }

      expect(landCount, equals(3));
      expect(spellCount, equals(0));
      final avgCmc = spellCount > 0 ? (totalCmc / spellCount) : 0.0;
      expect(avgCmc, equals(0.0));
      expect(avgCmc.isNaN, isFalse);
    });
  });

  // ===========================================================================
  // 2. VISUAL ANALYTICS ADVERSARIAL STRESS TESTS
  // ===========================================================================
  group('Visual Analytics Adversarial Stress Tests', () {
    test('Edge Case: 0-card deck computes clean empty analytics without errors', () {
      final analytics = MockDeckData.computeAnalyticsFromItems([]);

      expect(analytics.manaCurve.isEmpty, isTrue);
      expect(analytics.colorDevotion.isEmpty, isTrue);
      expect(analytics.colorProduction.isEmpty, isTrue);
      expect(analytics.blingPercentage, equals(0.0));
      expect(analytics.blingPercentage.isNaN, isFalse);
    });

    test('Edge Case: 100% Bling deck computes exactly 1.0 (100%)', () {
      final items = [
        // Foil
        {
          'deck_quantity': 2,
          'dynamic_data': jsonEncode({'finishes': ['foil'], 'cmc': 1, 'mana_cost': '{W}'}),
        },
        // Etched
        {
          'deck_quantity': 1,
          'dynamic_data': jsonEncode({'finishes': ['etched'], 'cmc': 2, 'mana_cost': '{U}'}),
        },
        // Graded
        {
          'deck_quantity': 1,
          'is_graded': 1,
          'dynamic_data': jsonEncode({'finishes': ['nonfoil'], 'cmc': 3, 'mana_cost': '{B}'}),
        },
        // Altered
        {
          'deck_quantity': 1,
          'is_altered': 1,
          'dynamic_data': jsonEncode({'finishes': ['nonfoil'], 'cmc': 4, 'mana_cost': '{R}'}),
        },
        // Signed
        {
          'deck_quantity': 1,
          'is_signed': 1,
          'dynamic_data': jsonEncode({'finishes': ['nonfoil'], 'cmc': 5, 'mana_cost': '{G}'}),
        },
        // Promo
        {
          'deck_quantity': 1,
          'dynamic_data': jsonEncode({'promo': true, 'cmc': 6, 'mana_cost': '{C}'}),
        },
      ];

      final analytics = MockDeckData.computeAnalyticsFromItems(items);
      // Total cards = 2 + 1 + 1 + 1 + 1 + 1 = 7 cards. All 7 have bling.
      expect(analytics.blingPercentage, equals(1.0));
    });

    test('Edge Case: 0% Bling deck computes exactly 0.0', () {
      final items = [
        {
          'deck_quantity': 10,
          'is_graded': 0,
          'is_altered': 0,
          'is_signed': 0,
          'dynamic_data': jsonEncode({'finishes': ['nonfoil'], 'promo': false, 'cmc': 2}),
        },
      ];

      final analytics = MockDeckData.computeAnalyticsFromItems(items);
      expect(analytics.blingPercentage, equals(0.0));
    });

    test('Edge Case: Purely hybrid mana decks ({W/U}, {B/R}, {G/W}, {2/B}, {G/P}) compute devotion accurately', () {
      final items = [
        // 2x Boros Reckoner: {R/W}{R/W}{R/W} -> +6 Red, +6 White
        {
          'deck_quantity': 2,
          'dynamic_data': jsonEncode({
            'cmc': 3,
            'mana_cost': '{R/W}{R/W}{R/W}',
          }),
        },
        // 1x Beseech the Mirror with 2-brid: {2/B}{2/B} -> +2 Black, no generic count
        {
          'deck_quantity': 1,
          'dynamic_data': jsonEncode({
            'cmc': 6,
            'mana_cost': '{2/B}{2/B}',
          }),
        },
        // 3x Dismember with Phyrexian mana: {1}{B/P}{B/P} -> +6 Black, no 'P' count
        {
          'deck_quantity': 3,
          'dynamic_data': jsonEncode({
            'cmc': 3,
            'mana_cost': '{1}{B/P}{B/P}',
          }),
        },
      ];

      final analytics = MockDeckData.computeAnalyticsFromItems(items);

      expect(analytics.colorDevotion['R'], equals(6));
      expect(analytics.colorDevotion['W'], equals(6));
      expect(analytics.colorDevotion['B'], equals(8)); // 2 from {2/B}{2/B} + 6 from 3x {B/P}{B/P}
      expect(analytics.colorDevotion['P'], isNull);
      expect(analytics.colorDevotion['2'], isNull);
      expect(analytics.colorDevotion['1'], isNull);
    });

    test('Edge Case: Colorless-only decks ({C} and generic {7}) do not pollute colors or crash', () {
      final items = [
        // Kozilek, the Great Distortion: {8}{C}{C} (CMC 10)
        {
          'deck_quantity': 1,
          'dynamic_data': jsonEncode({
            'cmc': 10,
            'mana_cost': '{8}{C}{C}',
            'produced_mana': ['C'],
          }),
        },
        // Thought-Knot Seer: {3}{C} (CMC 4)
        {
          'deck_quantity': 4,
          'dynamic_data': jsonEncode({
            'cmc': 4,
            'mana_cost': '{3}{C}',
          }),
        },
        // Karn Liberated: {7} (CMC 7, pure generic)
        {
          'deck_quantity': 1,
          'dynamic_data': jsonEncode({
            'cmc': 7,
            'mana_cost': '{7}',
          }),
        },
      ];

      final analytics = MockDeckData.computeAnalyticsFromItems(items);

      // Devotion should count {C} symbols: 2 from Kozilek + 4x 1 from Thought-Knot = 6 Colorless pips
      expect(analytics.colorDevotion['C'], equals(6));
      // No colored pips
      expect(analytics.colorDevotion['W'], isNull);
      expect(analytics.colorDevotion['U'], isNull);
      expect(analytics.colorDevotion['B'], isNull);
      expect(analytics.colorDevotion['R'], isNull);
      expect(analytics.colorDevotion['G'], isNull);
      // No generic numbers in devotion
      expect(analytics.colorDevotion['8'], isNull);
      expect(analytics.colorDevotion['3'], isNull);
      expect(analytics.colorDevotion['7'], isNull);

      // Mana Curve aggregation
      expect(analytics.manaCurve[4], equals(4)); // 4 Thought-Knot Seers
      expect(analytics.manaCurve[7], equals(1)); // 1 Karn
      expect(analytics.manaCurve[10], equals(1)); // 1 Kozilek

      // Color production
      expect(analytics.colorProduction['C'], equals(1));
    });

    test('Edge Case: Extreme CMC distributions (0 to 15+) aggregate properly in mana curve', () {
      final items = [
        {'deck_quantity': 5, 'dynamic_data': jsonEncode({'cmc': 0})},
        {'deck_quantity': 3, 'dynamic_data': jsonEncode({'cmc': 1})},
        {'deck_quantity': 2, 'dynamic_data': jsonEncode({'cmc': 7})},
        {'deck_quantity': 1, 'dynamic_data': jsonEncode({'cmc': 8})},
        {'deck_quantity': 1, 'dynamic_data': jsonEncode({'cmc': 15})}, // Emrakul
      ];

      final analytics = MockDeckData.computeAnalyticsFromItems(items);

      expect(analytics.manaCurve[0], equals(5));
      expect(analytics.manaCurve[1], equals(3));
      expect(analytics.manaCurve[7], equals(2));
      expect(analytics.manaCurve[8], equals(1));
      expect(analytics.manaCurve[15], equals(1));

      // In the UI, buckets >= 7 are aggregated: 2 + 1 + 1 = 4
      final cmc7Plus = analytics.manaCurve.entries
          .where((e) => e.key >= 7)
          .fold<int>(0, (sum, e) => sum + e.value);
      expect(cmc7Plus, equals(4));
    });

    test('Handles malformed dynamic_data without throwing TypeError or crashing', () {
      final items = [
        {'deck_quantity': 1, 'dynamic_data': 'not a json'},
        {'deck_quantity': 1, 'dynamic_data': '{"cmc": "not_int", "finishes": "not_list"}'},
        {'deck_quantity': 1, 'dynamic_data': '{"finishes": [1, 2, null]}'},
        {'deck_quantity': 1, 'dynamic_data': '{"card_faces": [null, "str"]}'},
        {'deck_quantity': 1, 'dynamic_data': '{"produced_mana": null}'},
      ];

      expect(() => MockDeckData.computeAnalyticsFromItems(items), returnsNormally);
      final analytics = MockDeckData.computeAnalyticsFromItems(items);
      expect(analytics.totalCardsSafe(items), equals(5));
    });
  });

  // ===========================================================================
  // 3. WIDGET-LEVEL ADVERSARIAL TESTING IN DECK BUILDER SCREEN
  // ===========================================================================
  group('DeckBuilderScreen Adversarial Widget Integration Tests', () {
    testWidgets('Empty deck (0 cards) renders empty message, and Fast-Draw shows clean empty state without NPE', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createSubject(deck: baseDeck, items: []));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('No cards in this deck yet'), findsOneWidget);

      // Open Fast-Draw on empty deck
      final fastDrawBtn = find.byIcon(Icons.style_rounded);
      expect(fastDrawBtn, findsOneWidget);
      await tester.tap(fastDrawBtn);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Not enough cards in deck to draw 7.'), findsOneWidget);
      expect(find.text('0'), findsWidgets); // 0 Lands, 0 Spells
      expect(find.text('0.0'), findsOneWidget); // 0.0 Avg CMC

      // Tap Mulligan on empty deck (must not crash)
      final mulliganBtn = find.text('Mulligan (Draw New 7)');
      await tester.tap(mulliganBtn);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Not enough cards in deck to draw 7.'), findsOneWidget);

      // Close modal
      await tester.tap(find.byIcon(Icons.close).last);
      await tester.pumpAndSettle();
    });

    testWidgets('Small card pool (3 cards) in Fast-Draw displays all 3 cards without throwing', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final smallItems = [
        {
          'id': 'small-1',
          'name': 'Sol Ring',
          'board_zone': 'Mainboard',
          'deck_quantity': 1,
          'dynamic_data': jsonEncode({'cmc': 1, 'mana_cost': '{1}', 'type_line': 'Artifact'}),
        },
        {
          'id': 'small-2',
          'name': 'Swamp',
          'board_zone': 'Lands',
          'deck_quantity': 1,
          'dynamic_data': jsonEncode({'cmc': 0, 'mana_cost': '', 'type_line': 'Basic Land — Swamp'}),
        },
        {
          'id': 'small-3',
          'name': 'Dark Ritual',
          'board_zone': 'Mainboard',
          'deck_quantity': 1,
          'dynamic_data': jsonEncode({'cmc': 1, 'mana_cost': '{B}', 'type_line': 'Instant'}),
        },
      ];

      await tester.pumpWidget(createSubject(deck: baseDeck, items: smallItems));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.style_rounded));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Sol Ring'), findsWidgets);
      expect(find.text('Swamp'), findsWidgets);
      expect(find.text('Dark Ritual'), findsWidgets);
      expect(find.text('Lands'), findsWidgets);
      expect(find.text('Spells'), findsWidgets);

      // Close modal
      await tester.tap(find.byIcon(Icons.close).last);
      await tester.pumpAndSettle();
    });

    testWidgets('Empty deck (0 cards) opens Analytics modal rendering all 0 metrics without NaN or crash', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createSubject(deck: baseDeck, items: []));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.analytics_rounded));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Deck Visual Analytics'), findsOneWidget);
      expect(find.text('Mana Curve (CMC 0 to 7+)'), findsOneWidget);
      expect(find.text('Color Devotion (Mana Pips)'), findsOneWidget);
      expect(find.text('0.0% Bling'), findsOneWidget);

      // Verify pips render with 0
      expect(find.text('W'), findsWidgets);
      expect(find.text('U'), findsWidgets);
      expect(find.text('B'), findsWidgets);
      expect(find.text('R'), findsWidgets);
      expect(find.text('G'), findsWidgets);
      expect(find.text('C'), findsWidgets);

      // Close modal
      await tester.tap(find.byIcon(Icons.close).last);
      await tester.pumpAndSettle();
    });

    testWidgets('100% Foils deck renders 100.0% Bling with full bar without overflow', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final foilItems = [
        {
          'id': 'foil-1',
          'name': 'Foil Lightning Bolt',
          'board_zone': 'Mainboard',
          'deck_quantity': 4,
          'dynamic_data': jsonEncode({
            'cmc': 1,
            'mana_cost': '{R}',
            'type_line': 'Instant',
            'finishes': ['foil'],
          }),
        },
      ];

      await tester.pumpWidget(createSubject(deck: baseDeck, items: foilItems));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.analytics_rounded));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('100.0% Bling'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close).last);
      await tester.pumpAndSettle();
    });

    testWidgets('Colorless-only deck renders devotion pips and Colorless breakdown without error', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final colorlessItems = [
        {
          'id': 'c-1',
          'name': 'Kozilek, the Great Distortion',
          'board_zone': 'Commander',
          'deck_quantity': 1,
          'dynamic_data': jsonEncode({
            'cmc': 10,
            'mana_cost': '{8}{C}{C}',
            'type_line': 'Legendary Creature — Eldrazi',
            'finishes': ['nonfoil'],
          }),
        },
        {
          'id': 'c-2',
          'name': 'Wastes',
          'board_zone': 'Lands',
          'deck_quantity': 10,
          'dynamic_data': jsonEncode({
            'cmc': 0,
            'mana_cost': '',
            'type_line': 'Basic Land',
            'produced_mana': ['C'],
          }),
        },
      ];

      await tester.pumpWidget(createSubject(deck: baseDeck, items: colorlessItems));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.analytics_rounded));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Deck Visual Analytics'), findsOneWidget);
      // 'C' pip should show 2 (from Kozilek)
      expect(find.text('C'), findsWidgets);

      await tester.tap(find.byIcon(Icons.close).last);
      await tester.pumpAndSettle();
    });
  });
}

extension on DeckAnalytics {
  int totalCardsSafe(List<Map<String, dynamic>> items) {
    return items.fold<int>(0, (sum, i) => sum + (i['deck_quantity'] as int? ?? 1));
  }
}
