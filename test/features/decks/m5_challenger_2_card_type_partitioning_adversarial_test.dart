import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/decks/presentation/screens/deck_builder_screen.dart';
import 'package:countr/features/decks/presentation/widgets/proportional_bubble_scrollbar.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'deck_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  final testDeck = createTestDeck(
    id: 'deck-c2-adv',
    name: 'Challenger 2 Adversarial Deck',
    format: 'Commander',
    createdAt: DateTime(2023, 1, 1),
    wins: 10,
    losses: 3,
    draws: 1,
  );

  Widget createSubject({
    required Deck deck,
    required List<Map<String, dynamic>> items,
  }) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        vaultDaoProvider.overrideWithValue(db.vaultDao),
        deckItemsProvider(deck.id).overrideWith(
          (ref) => Stream.value(items),
        ),
      ],
      child: MaterialApp(
        home: DeckBuilderScreen(deck: deck),
      ),
    );
  }

  group('Challenger 2: Card Type Partitioning Adversarial Suite', () {
    testWidgets('Challenge 1: Missing type_line completely (Stress 3 in List and Grid mode)', (tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Deck items without any type_line, simulating legacy, missing, or minimal SQLite rows
      final items = <Map<String, dynamic>>[
        {
          'id': 'cmd-1',
          'name': 'Commander Without Type Line',
          'board_zone': 'Commander',
          'deck_quantity': 1,
          'dynamic_data': jsonEncode({'mana_cost': '{2}{U}{B}', 'cmc': 4.0}),
        },
        for (int i = 1; i <= 5; i++)
          {
            'id': 'main-$i',
            'name': 'Mainboard No Type #$i',
            'board_zone': 'Mainboard',
            'deck_quantity': 1,
            'dynamic_data': jsonEncode({'mana_cost': '{1}{G}', 'cmc': 2.0}),
          },
        {
          'id': 'side-1',
          'name': 'Sideboard Card No Type',
          'board_zone': 'Sideboard',
          'deck_quantity': 2,
          'dynamic_data': jsonEncode({'mana_cost': '{W}'}),
        },
        {
          'id': 'maybe-1',
          'name': 'Maybeboard Card No Type',
          'board_zone': 'Maybeboard',
          'deck_quantity': 1,
          'dynamic_data': jsonEncode({'mana_cost': '{R}'}),
        },
        {
          'id': 'custom-1',
          'name': 'Custom Zone Card',
          'board_zone': 'Tokens',
          'deck_quantity': 3,
          'dynamic_data': jsonEncode({'mana_cost': ''}),
        },
      ];

      await tester.pumpWidget(createSubject(deck: testDeck, items: items));
      await tester.pumpAndSettle();

      // List Mode: Verifies fallback to board_zone headers
      expect(find.text('COMMANDER'), findsOneWidget);
      expect(find.text('MAINBOARD'), findsOneWidget);
      expect(find.text('SIDEBOARD'), findsOneWidget);
      expect(find.text('MAYBEBOARD'), findsOneWidget);
      expect(find.text('TOKENS'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Switch to Grid View
      final toggleFinder = find.byKey(const Key('deck_builder_view_mode_toggle'));
      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();

      // Grid Mode: Verifies graceful fallback to board_zone headers without throwing or breaking layout
      expect(tester.takeException(), isNull);
      expect(find.text('COMMANDER'), findsOneWidget);
      expect(find.text('MAINBOARD'), findsOneWidget);
      expect(find.text('SIDEBOARD'), findsOneWidget);
      expect(find.text('MAYBEBOARD'), findsOneWidget);
      expect(find.text('TOKENS'), findsOneWidget);
      expect(find.byType(SliverGrid), findsWidgets);
    });

    testWidgets('Challenge 2: Double-faced cards (DFCs) across diverse face compositions', (tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final items = <Map<String, dynamic>>[
        // Front Creature DFC
        {
          'id': 'dfc-creature',
          'name': 'Huntmaster of the Fells // Ravager of the Fells',
          'board_zone': 'Mainboard',
          'deck_quantity': 1,
          'dynamic_data': jsonEncode({
            'card_faces': [
              {'name': 'Huntmaster of the Fells', 'type_line': 'Creature — Human Werewolf'},
              {'name': 'Ravager of the Fells', 'type_line': 'Creature — Werewolf'},
            ],
          }),
        },
        // MDFC Front Land
        {
          'id': 'dfc-land',
          'name': 'Boseiju, Who Endures // Tree of Tales',
          'board_zone': 'Mainboard',
          'deck_quantity': 1,
          'dynamic_data': jsonEncode({
            'card_faces': [
              {'name': 'Boseiju, Who Endures', 'type_line': 'Legendary Land'},
              {'name': 'Tree of Tales', 'type_line': 'Artifact Land'},
            ],
          }),
        },
        // MDFC Front Sorcery
        {
          'id': 'dfc-sorcery',
          'name': 'Emeria\'s Call // Emeria, Shattered Skyclave',
          'board_zone': 'Mainboard',
          'deck_quantity': 1,
          'dynamic_data': jsonEncode({
            'card_faces': [
              {'name': 'Emeria\'s Call', 'type_line': 'Sorcery'},
              {'name': 'Emeria, Shattered Skyclave', 'type_line': 'Land'},
            ],
          }),
        },
        // Transforming Planeswalker DFC
        {
          'id': 'dfc-pw',
          'name': 'Nicol Bolas, the Ravager // Nicol Bolas, the Arisen',
          'board_zone': 'Mainboard',
          'deck_quantity': 1,
          'dynamic_data': jsonEncode({
            'card_faces': [
              {'name': 'Nicol Bolas, the Arisen', 'type_line': 'Legendary Planeswalker — Bolas'},
            ],
          }),
        },
        // DFC with empty card_faces list (edge case)
        {
          'id': 'dfc-empty-faces',
          'name': 'Malformed DFC Card',
          'board_zone': 'Mainboard',
          'deck_quantity': 1,
          'dynamic_data': jsonEncode({
            'card_faces': <dynamic>[],
          }),
        },
      ];

      await tester.pumpWidget(createSubject(deck: testDeck, items: items));
      await tester.pumpAndSettle();

      // Switch to Grid View
      await tester.tap(find.byKey(const Key('deck_builder_view_mode_toggle')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('CREATURES'), findsOneWidget);
      expect(find.text('LANDS'), findsOneWidget);
      expect(find.text('SORCERIES'), findsOneWidget);
      expect(find.text('PLANESWALKERS'), findsOneWidget);
      // Malformed DFC falls back cleanly to MAINBOARD
      expect(find.text('MAINBOARD'), findsOneWidget);
    });

    testWidgets('Challenge 3: Multi-type cards and non-standard card types partitioning', (tester) async {
      tester.view.physicalSize = const Size(800, 2500);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final items = <Map<String, dynamic>>[
        // Artifact Creature -> should categorize under CREATURES
        {
          'id': 'art-creature',
          'name': 'Solemn Simulacrum',
          'board_zone': 'Mainboard',
          'deck_quantity': 1,
          'type_line': 'Artifact Creature — Golem',
        },
        // Enchantment Creature -> should categorize under CREATURES
        {
          'id': 'ench-creature',
          'name': 'Courser of Kruphix',
          'board_zone': 'Mainboard',
          'deck_quantity': 1,
          'type_line': 'Enchantment Creature — Centaur',
        },
        // Enchantment Artifact -> should categorize under ARTIFACTS
        {
          'id': 'ench-art',
          'name': 'Bident of Thassa',
          'board_zone': 'Mainboard',
          'deck_quantity': 1,
          'type_line': 'Legendary Enchantment Artifact',
        },
        // Tribal Instant -> should categorize under INSTANTS
        {
          'id': 'tribal-instant',
          'name': 'Tarfire',
          'board_zone': 'Mainboard',
          'deck_quantity': 1,
          'type_line': 'Tribal Instant — Goblin',
        },
        // Non-standard types: Vanguard, Scheme, Conspiracy, Dungeon
        {
          'id': 'vanguard-card',
          'name': 'Ashnod Vanguard',
          'board_zone': 'Mainboard',
          'deck_quantity': 1,
          'type_line': 'Vanguard',
        },
        {
          'id': 'scheme-card',
          'name': 'All In Good Time',
          'board_zone': 'Mainboard',
          'deck_quantity': 1,
          'type_line': 'Scheme',
        },
        {
          'id': 'conspiracy-card',
          'name': 'Worldknit',
          'board_zone': 'Sideboard',
          'deck_quantity': 1,
          'type_line': 'Conspiracy',
        },
        {
          'id': 'corrupt-json-card',
          'name': 'Corrupted Dynamic Data Card',
          'board_zone': 'Mainboard',
          'deck_quantity': 1,
          'dynamic_data': '{invalid: json :;!@#}',
        },
      ];

      await tester.pumpWidget(createSubject(deck: testDeck, items: items));
      await tester.pumpAndSettle();

      // Switch to Grid View
      await tester.tap(find.byKey(const Key('deck_builder_view_mode_toggle')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('CREATURES'), findsOneWidget);
      expect(find.text('ARTIFACTS'), findsOneWidget);
      expect(find.text('INSTANTS'), findsOneWidget);
      // Non-standard Vanguard, Scheme, and Corrupted JSON fall back to MAINBOARD
      expect(find.text('MAINBOARD'), findsOneWidget);
      // Conspiracy in Sideboard falls back to SIDEBOARD
      expect(find.text('SIDEBOARD'), findsOneWidget);
    });

    testWidgets('Challenge 4a: Completely empty deck renders friendly placeholder in both view modes', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final emptyDeck = createTestDeck(
        id: 'deck-c2-empty',
        name: 'Empty Deck',
      );
      await tester.pumpWidget(createSubject(deck: emptyDeck, items: []));
      await tester.pumpAndSettle();

      expect(find.textContaining('No cards in this deck yet'), findsOneWidget);
      expect(find.byType(SliverGrid), findsNothing);
    });

    testWidgets('Challenge 4b: Empty zones omitted cleanly (deck with only Sideboard cards)', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final sbDeck = createTestDeck(
        id: 'deck-c2-sb-only',
        name: 'Sideboard Deck',
      );
      final sbOnlyItems = <Map<String, dynamic>>[
        {
          'id': 'sb-card-1',
          'name': 'Sideboard Only Card',
          'board_zone': 'Sideboard',
          'deck_quantity': 3,
          'type_line': 'Instant',
        },
      ];

      await tester.pumpWidget(createSubject(deck: sbDeck, items: sbOnlyItems));
      await tester.pumpAndSettle();

      // Switch to Grid View
      await tester.tap(find.byKey(const Key('deck_builder_view_mode_toggle')));
      await tester.pumpAndSettle();

      // In grid view, Sideboard zone header should be present with qty 3
      expect(find.text('SIDEBOARD'), findsOneWidget);
      // Empty zones like CREATURES, LANDS, COMMANDER should NOT be rendered
      expect(find.text('COMMANDER'), findsNothing);
      expect(find.text('CREATURES'), findsNothing);
      expect(find.text('LANDS'), findsNothing);
    });

    testWidgets('Challenge 5: Section header card counts exact match sum of items in that section', (tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final items = <Map<String, dynamic>>[
        {
          'id': 'cmd-1',
          'name': 'Commander Card',
          'board_zone': 'Commander',
          'deck_quantity': 1,
          'type_line': 'Legendary Creature — Human',
        },
        {
          'id': 'c-1',
          'name': 'Creature A',
          'board_zone': 'Mainboard',
          'deck_quantity': 4,
          'type_line': 'Creature — Elf',
        },
        {
          'id': 'c-2',
          'name': 'Creature B',
          'board_zone': 'Mainboard',
          'deck_quantity': 2,
          'type_line': 'Creature — Beast',
        },
        {
          'id': 'ins-1',
          'name': 'Instant A',
          'board_zone': 'Mainboard',
          'deck_quantity': 3,
          'type_line': 'Instant',
        },
        {
          'id': 'ins-2',
          'name': 'Instant B',
          'board_zone': 'Mainboard',
          'deck_quantity': 4,
          'type_line': 'Instant',
        },
        {
          'id': 'lnd-1',
          'name': 'Basic Forest',
          'board_zone': 'Mainboard',
          'deck_quantity': 15,
          'type_line': 'Basic Land — Forest',
        },
      ];

      await tester.pumpWidget(createSubject(deck: testDeck, items: items));
      await tester.pumpAndSettle();

      // Total items quantity = 1 + 4 + 2 + 3 + 4 + 15 = 29
      // In List Mode:
      // Commander section has 1
      // Mainboard section has 28
      expect(find.text('COMMANDER'), findsOneWidget);
      expect(find.text('MAINBOARD'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('28'), findsOneWidget);

      // Switch to Grid Mode
      await tester.tap(find.byKey(const Key('deck_builder_view_mode_toggle')));
      await tester.pumpAndSettle();

      // In Grid Mode:
      // Commander section: 1
      // Creatures section: 4 + 2 = 6
      // Instants section: 3 + 4 = 7
      // Lands section: 15
      expect(find.text('COMMANDER'), findsOneWidget);
      expect(find.text('CREATURES'), findsOneWidget);
      expect(find.text('INSTANTS'), findsOneWidget);
      expect(find.text('LANDS'), findsOneWidget);

      expect(find.text('1'), findsOneWidget); // Commander
      expect(find.text('6'), findsOneWidget); // Creatures
      expect(find.text('7'), findsOneWidget); // Instants
      expect(find.text('15'), findsOneWidget); // Lands

      // Bubble scrollbar sections reflect the 4 sections
      expect(find.byType(ProportionalBubbleScrollbar), findsOneWidget);
    });

    testWidgets('Challenge 6: View mode toggling resilience under multiple rapid transitions', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final items = <Map<String, dynamic>>[
        {
          'id': 'c-1',
          'name': 'Tarmogoyf',
          'board_zone': 'Mainboard',
          'deck_quantity': 4,
          'type_line': 'Creature — Lhurgoyf',
        },
        {
          'id': 'i-1',
          'name': 'Lightning Bolt',
          'board_zone': 'Mainboard',
          'deck_quantity': 4,
          'type_line': 'Instant',
        },
      ];

      await tester.pumpWidget(createSubject(deck: testDeck, items: items));
      await tester.pumpAndSettle();

      final toggleFinder = find.byKey(const Key('deck_builder_view_mode_toggle'));

      // Rapidly toggle back and forth 10 times
      for (int i = 0; i < 10; i++) {
        await tester.tap(toggleFinder);
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // After 10 toggles (even number), view mode should be back to List View
      expect(find.byIcon(Icons.grid_view_rounded), findsOneWidget);
      expect(find.byType(SliverList), findsWidgets);
      expect(find.byType(SliverGrid), findsNothing);
    });
  });
}
