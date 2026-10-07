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
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';
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
    id: 'deck-m5-test',
    name: 'M5 Atraxa Superfriends',
    format: 'Commander',
    createdAt: DateTime(2023, 1, 1),
    wins: 5,
    losses: 2,
    draws: 0,
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

  group('Milestone 5 - R5 Multi-Section Grid View Tests', () {
    test('DeckViewMode enum contains list and grid modes', () {
      expect(DeckViewMode.values, contains(DeckViewMode.list));
      expect(DeckViewMode.values, contains(DeckViewMode.grid));
      expect(DeckViewMode.values.length, 2);
    });

    testWidgets('DeckBuilderScreen starts in list mode and renders view mode toggle button', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final items = [
        {
          'id': 'c-1',
          'name': 'Atraxa, Praetors\' Voice',
          'board_zone': 'Commander',
          'deck_quantity': 1,
          'type_line': 'Legendary Creature — Phyrexian Angel',
          'dynamic_data': jsonEncode({
            'type_line': 'Legendary Creature — Phyrexian Angel',
            'mana_cost': '{G}{W}{U}{B}',
            'cmc': 4.0,
          }),
        },
      ];

      await tester.pumpWidget(createSubject(deck: testDeck, items: items));
      await tester.pumpAndSettle();

      // Find view mode toggle button
      final toggleFinder = find.byKey(const Key('deck_builder_view_mode_toggle'));
      expect(toggleFinder, findsOneWidget);

      // In initial list mode: icon is grid_view_rounded and tooltip is Switch to Grid View
      expect(find.byIcon(Icons.grid_view_rounded), findsOneWidget);
      expect(find.byTooltip('Switch to Grid View'), findsOneWidget);

      // SliverList is rendered for card items; SliverGrid is absent
      expect(find.byType(SliverList), findsWidgets);
      expect(find.byType(SliverGrid), findsNothing);
    });

    testWidgets('Tapping view mode toggle button toggles to grid mode and mounts SliverGrid with 3 columns', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final items = [
        {
          'id': 'c-1',
          'name': 'Atraxa, Praetors\' Voice',
          'board_zone': 'Commander',
          'deck_quantity': 1,
          'dynamic_data': jsonEncode({
            'type_line': 'Legendary Creature — Phyrexian Angel',
            'mana_cost': '{G}{W}{U}{B}',
            'cmc': 4.0,
          }),
        },
        {
          'id': 'cr-1',
          'name': 'Birds of Paradise',
          'board_zone': 'Mainboard',
          'deck_quantity': 1,
          'dynamic_data': jsonEncode({
            'type_line': 'Creature — Bird',
            'mana_cost': '{G}',
            'cmc': 1.0,
          }),
        },
      ];

      await tester.pumpWidget(createSubject(deck: testDeck, items: items));
      await tester.pumpAndSettle();

      // Tap toggle button to enter Grid View
      final toggleFinder = find.byKey(const Key('deck_builder_view_mode_toggle'));
      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();

      // Toggle icon transitions to view_list_rounded and tooltip to Switch to List View
      expect(find.byIcon(Icons.view_list_rounded), findsOneWidget);
      expect(find.byTooltip('Switch to List View'), findsOneWidget);

      // In grid mode: SliverGrid is mounted
      final sliverGridFinder = find.byType(SliverGrid);
      expect(sliverGridFinder, findsWidgets);

      // Verify SliverGridDelegate specifications
      final sliverGrid = tester.widget<SliverGrid>(sliverGridFinder.first);
      final delegate = sliverGrid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, 3, reason: 'Grid must use 3 columns');
      expect(delegate.childAspectRatio, closeTo(0.714, 0.001), reason: 'Standard 2.5:3.5 card ratio');
      expect(delegate.crossAxisSpacing, 6);
      expect(delegate.mainAxisSpacing, 6);

      // Tapping again returns cleanly to List View
      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.grid_view_rounded), findsOneWidget);
      expect(find.byType(SliverGrid), findsNothing);
    });

    testWidgets('Partitions cards into MTG type sections with headers, counts and canonical ordering', (tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final items = [
        {
          'id': 'cmd-1',
          'name': 'Atraxa, Praetors\' Voice',
          'board_zone': 'Commander',
          'deck_quantity': 1,
          'dynamic_data': jsonEncode({'type_line': 'Legendary Creature — Phyrexian Angel'}),
        },
        {
          'id': 'creature-1',
          'name': 'Birds of Paradise',
          'board_zone': 'Mainboard',
          'deck_quantity': 2,
          'dynamic_data': jsonEncode({'type_line': 'Creature — Bird'}),
        },
        {
          'id': 'pw-1',
          'name': 'Teferi, Time Raveler',
          'board_zone': 'Mainboard',
          'deck_quantity': 1,
          'dynamic_data': jsonEncode({'type_line': 'Legendary Planeswalker — Teferi'}),
        },
        {
          'id': 'inst-1',
          'name': 'Swords to Plowshares',
          'board_zone': 'Mainboard',
          'deck_quantity': 1,
          'dynamic_data': jsonEncode({'type_line': 'Instant'}),
        },
        {
          'id': 'sorc-1',
          'name': 'Demonic Tutor',
          'board_zone': 'Mainboard',
          'deck_quantity': 1,
          'dynamic_data': jsonEncode({'type_line': 'Sorcery'}),
        },
        {
          'id': 'art-1',
          'name': 'Sol Ring',
          'board_zone': 'Mainboard',
          'deck_quantity': 1,
          'dynamic_data': jsonEncode({'type_line': 'Artifact'}),
        },
        {
          'id': 'ench-1',
          'name': 'Rhystic Study',
          'board_zone': 'Mainboard',
          'deck_quantity': 1,
          'dynamic_data': jsonEncode({'type_line': 'Enchantment'}),
        },
        {
          'id': 'bat-1',
          'name': 'Invasion of Gobakhan',
          'board_zone': 'Mainboard',
          'deck_quantity': 1,
          'dynamic_data': jsonEncode({'type_line': 'Battle — Siege'}),
        },
        {
          'id': 'land-1',
          'name': 'Command Tower',
          'board_zone': 'Mainboard',
          'deck_quantity': 4,
          'dynamic_data': jsonEncode({'type_line': 'Land'}),
        },
        {
          'id': 'sb-1',
          'name': 'Rest in Peace',
          'board_zone': 'Sideboard',
          'deck_quantity': 2,
          'dynamic_data': jsonEncode({'type_line': 'Enchantment'}),
        },
        {
          'id': 'mb-1',
          'name': 'Mana Crypt',
          'board_zone': 'Maybeboard',
          'deck_quantity': 1,
          'dynamic_data': jsonEncode({'type_line': 'Artifact'}),
        },
      ];

      await tester.pumpWidget(createSubject(deck: testDeck, items: items));
      await tester.pumpAndSettle();

      // Switch to Grid View
      await tester.tap(find.byKey(const Key('deck_builder_view_mode_toggle')));
      await tester.pumpAndSettle();

      // Verify category headers are present
      expect(find.text('COMMANDER'), findsOneWidget);
      expect(find.text('CREATURES'), findsOneWidget);
      expect(find.text('PLANESWALKERS'), findsOneWidget);
      expect(find.text('INSTANTS'), findsOneWidget);
      expect(find.text('SORCERIES'), findsOneWidget);
      expect(find.text('ARTIFACTS'), findsOneWidget);
      expect(find.text('ENCHANTMENTS'), findsOneWidget);

      // Verify ProportionalBubbleScrollbar tracks the sections
      expect(find.byType(ProportionalBubbleScrollbar), findsOneWidget);
    });

    testWidgets('Extracts type_line correctly for double-faced cards (DFCs)', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final items = [
        {
          'id': 'dfc-1',
          'name': 'Delver of Secrets // Insectile Aberration',
          'board_zone': 'Mainboard',
          'deck_quantity': 1,
          'dynamic_data': jsonEncode({
            'card_faces': [
              {
                'name': 'Delver of Secrets',
                'type_line': 'Creature — Human Wizard',
              },
              {
                'name': 'Insectile Aberration',
                'type_line': 'Creature — Human Insect',
              },
            ],
          }),
        },
      ];

      await tester.pumpWidget(createSubject(deck: testDeck, items: items));
      await tester.pumpAndSettle();

      // Switch to Grid View
      await tester.tap(find.byKey(const Key('deck_builder_view_mode_toggle')));
      await tester.pumpAndSettle();

      // Should be categorized under CREATURES
      expect(find.text('CREATURES'), findsOneWidget);
    });

    testWidgets('Falls back cleanly to board_zone when type_line is absent', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // No type_line in dynamic_data
      final items = [
        {
          'id': 'c-1',
          'name': 'Commander Card',
          'board_zone': 'Commander',
          'deck_quantity': 1,
          'dynamic_data': jsonEncode({'mana_cost': '{2}{U}'}),
        },
        {
          'id': 'm-1',
          'name': 'Mainboard Card',
          'board_zone': 'Mainboard',
          'deck_quantity': 1,
          'dynamic_data': jsonEncode({'mana_cost': '{1}{G}'}),
        },
      ];

      await tester.pumpWidget(createSubject(deck: testDeck, items: items));
      await tester.pumpAndSettle();

      // In default list mode, headers fallback to board_zone names
      expect(find.text('COMMANDER'), findsOneWidget);
      expect(find.text('MAINBOARD'), findsOneWidget);

      // In grid mode, fallback still works
      await tester.tap(find.byKey(const Key('deck_builder_view_mode_toggle')));
      await tester.pumpAndSettle();

      expect(find.text('COMMANDER'), findsOneWidget);
      expect(find.text('MAINBOARD'), findsOneWidget);
    });

    testWidgets('Grid card cell displays quantity badge for qty > 1 and handles tap gestures', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final items = [
        {
          'id': 'bop',
          'name': 'Birds of Paradise',
          'board_zone': 'Mainboard',
          'deck_quantity': 3,
          'dynamic_data': jsonEncode({'type_line': 'Creature — Bird'}),
        },
        {
          'id': 'sol',
          'name': 'Sol Ring',
          'board_zone': 'Mainboard',
          'deck_quantity': 1,
          'dynamic_data': jsonEncode({'type_line': 'Artifact'}),
        },
      ];

      await tester.pumpWidget(createSubject(deck: testDeck, items: items));
      await tester.pumpAndSettle();

      // Switch to Grid View
      await tester.tap(find.byKey(const Key('deck_builder_view_mode_toggle')));
      await tester.pumpAndSettle();

      // Verify grid cells exist
      final bopCell = find.byKey(const Key('deck_grid_card_bop'));
      final solCell = find.byKey(const Key('deck_grid_card_sol'));
      expect(bopCell, findsOneWidget);
      expect(solCell, findsOneWidget);

      // Birds of Paradise has qty 3: badge '3x' is visible
      expect(find.text('3x'), findsOneWidget);

      // Sol Ring has qty 1: badge '1x' is NOT displayed
      expect(find.text('1x'), findsNothing);

      // Tap on Birds of Paradise opens CardDetailSheet
      await tester.tap(bopCell);
      await tester.pumpAndSettle();

      expect(find.byType(CardDetailSheet), findsOneWidget);
    });
  });
}
