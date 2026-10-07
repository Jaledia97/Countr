import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/decks/presentation/screens/deck_builder_screen.dart';
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
    id: 'deck-adversarial-m5',
    name: 'Adversarial M5 Challenge Deck',
    format: 'Commander',
    createdAt: DateTime(2023, 1, 1),
    wins: 10,
    losses: 3,
    draws: 0,
  );

  Widget createSubject({
    required Deck deck,
    required List<Map<String, dynamic>> items,
    Key? screenKey,
    StreamController<List<Map<String, dynamic>>>? itemsController,
  }) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        vaultDaoProvider.overrideWithValue(db.vaultDao),
        deckItemsProvider(deck.id).overrideWith(
          (ref) => itemsController != null
              ? itemsController.stream
              : Stream.value(items),
        ),
      ],
      child: MaterialApp(
        home: DeckBuilderScreen(
          key: screenKey,
          deck: deck,
        ),
      ),
    );
  }

  group('M5 Challenger - Adversarial Grid View Verification', () {
    testWidgets('1. Verification of 3-column SliverGrid layout parameters across all sections', (tester) async {
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
          'name': 'Llanowar Elves',
          'board_zone': 'Mainboard',
          'deck_quantity': 1,
          'dynamic_data': jsonEncode({'type_line': 'Creature — Elf Druid'}),
        },
        {
          'id': 'creature-2',
          'name': 'Noble Hierarch',
          'board_zone': 'Mainboard',
          'deck_quantity': 1,
          'dynamic_data': jsonEncode({'type_line': 'Creature — Human Druid'}),
        },
        {
          'id': 'inst-1',
          'name': 'Counterspell',
          'board_zone': 'Mainboard',
          'deck_quantity': 1,
          'dynamic_data': jsonEncode({'type_line': 'Instant'}),
        },
        {
          'id': 'land-1',
          'name': 'Island',
          'board_zone': 'Mainboard',
          'deck_quantity': 4,
          'dynamic_data': jsonEncode({'type_line': 'Basic Land — Island'}),
        },
      ];

      await tester.pumpWidget(createSubject(deck: testDeck, items: items));
      await tester.pumpAndSettle();

      // Enter Grid View
      final toggleFinder = find.byKey(const Key('deck_builder_view_mode_toggle'));
      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();

      // Find all SliverGrids rendered
      final gridFinders = find.byType(SliverGrid);
      expect(gridFinders, findsWidgets);

      final gridCount = tester.widgetList<SliverGrid>(gridFinders).length;
      expect(gridCount, 4, reason: 'Must have 4 active sections: Commander, Creatures, Instants, Lands');

      // Verify every single SliverGrid adheres strictly to 3 columns and 0.714 aspect ratio
      for (final gridWidget in tester.widgetList<SliverGrid>(gridFinders)) {
        final delegate = gridWidget.gridDelegate;
        expect(delegate, isA<SliverGridDelegateWithFixedCrossAxisCount>());
        final gridDelegate = delegate as SliverGridDelegateWithFixedCrossAxisCount;
        expect(gridDelegate.crossAxisCount, 3, reason: 'Must be exactly 3 columns');
        expect(gridDelegate.childAspectRatio, closeTo(0.714, 0.001), reason: 'Standard TCG 2.5:3.5 aspect ratio');
        expect(gridDelegate.crossAxisSpacing, 6.0);
        expect(gridDelegate.mainAxisSpacing, 6.0);
      }
    });

    testWidgets('2. Adversarial rapid toggling stress test between list and grid views (20 toggles)', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final items = [
        {
          'id': 'card-1',
          'name': 'Sol Ring',
          'board_zone': 'Mainboard',
          'deck_quantity': 1,
          'dynamic_data': jsonEncode({'type_line': 'Artifact'}),
        },
        {
          'id': 'card-2',
          'name': 'Arcane Signet',
          'board_zone': 'Mainboard',
          'deck_quantity': 1,
          'dynamic_data': jsonEncode({'type_line': 'Artifact'}),
        },
      ];

      await tester.pumpWidget(createSubject(deck: testDeck, items: items));
      await tester.pumpAndSettle();

      final toggleFinder = find.byKey(const Key('deck_builder_view_mode_toggle'));

      // Perform 20 rapid toggles back and forth
      for (int i = 0; i < 20; i++) {
        await tester.tap(toggleFinder);
        await tester.pump(); // Fast frame rebuild without waiting for animations
      }
      await tester.pumpAndSettle();

      // After 20 toggles (even number), we should be back in list view
      expect(find.byIcon(Icons.grid_view_rounded), findsOneWidget);
      expect(find.byType(SliverGrid), findsNothing);
      expect(find.byType(SliverList), findsWidgets);

      // Perform 1 more toggle -> enters grid view
      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.view_list_rounded), findsOneWidget);
      expect(find.byType(SliverGrid), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'No unhandled exceptions during rapid toggling');
    });

    testWidgets('3. Scroll state and toggle resilience when scrolled down', (tester) async {
      tester.view.physicalSize = const Size(390, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Generate 30 cards across multiple types to make view easily scrollable
      final items = List.generate(30, (i) => {
        'id': 'card-$i',
        'name': 'Card $i',
        'board_zone': 'Mainboard',
        'deck_quantity': 1,
        'dynamic_data': jsonEncode({
          'type_line': i < 15 ? 'Creature — Human' : 'Sorcery',
        }),
      });

      await tester.pumpWidget(createSubject(deck: testDeck, items: items));
      await tester.pumpAndSettle();

      // Scroll down by 250px
      final scrollableFinder = find.byType(CustomScrollView);
      expect(scrollableFinder, findsOneWidget);
      await tester.drag(scrollableFinder, const Offset(0, -250));
      await tester.pumpAndSettle();

      // Toggle to grid mode while scrolled down
      final toggleFinder = find.byKey(const Key('deck_builder_view_mode_toggle'));
      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();

      // Ensure SliverGrid is mounted without out-of-bounds scroll assertion or exception
      expect(find.byType(SliverGrid), findsWidgets);
      expect(tester.takeException(), isNull);

      // Scroll up and down inside grid mode
      await tester.drag(scrollableFinder, const Offset(0, -200));
      await tester.pumpAndSettle();
      await tester.drag(scrollableFinder, const Offset(0, 300));
      await tester.pumpAndSettle();

      // Toggle back to list mode
      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();

      expect(find.byType(SliverList), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('4. Dynamic stream card mutations during grid mode', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final streamController = StreamController<List<Map<String, dynamic>>>();
      addTearDown(() => streamController.close());

      final initialItems = [
        {
          'id': 'c-1',
          'name': 'Swords to Plowshares',
          'board_zone': 'Mainboard',
          'deck_quantity': 1,
          'dynamic_data': jsonEncode({'type_line': 'Instant'}),
        },
      ];

      await tester.pumpWidget(createSubject(
        deck: testDeck,
        items: initialItems,
        itemsController: streamController,
      ));

      // Emit initial cards
      streamController.add(initialItems);
      await tester.pumpAndSettle();

      // Switch to Grid View
      final toggleFinder = find.byKey(const Key('deck_builder_view_mode_toggle'));
      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();

      expect(find.text('INSTANTS'), findsOneWidget);
      expect(find.text('CREATURES'), findsNothing);

      // Emit updated card list adding Creatures
      final updatedItems = [
        ...initialItems,
        {
          'id': 'c-2',
          'name': 'Dark Confidant',
          'board_zone': 'Mainboard',
          'deck_quantity': 1,
          'dynamic_data': jsonEncode({'type_line': 'Creature — Human Wizard'}),
        },
      ];
      streamController.add(updatedItems);
      await tester.pumpAndSettle();

      // Now both Instants and Creatures sections should appear in grid mode
      expect(find.text('INSTANTS'), findsOneWidget);
      expect(find.text('CREATURES'), findsOneWidget);
      expect(find.byKey(const Key('deck_grid_card_c-2')), findsOneWidget);
    });

    testWidgets('5. Card quantity badge rules: hide on qty <= 1, show on qty > 1 (2x, 4x, 99x)', (tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final items = [
        {
          'id': 'single-qty',
          'name': 'Single Card',
          'board_zone': 'Mainboard',
          'deck_quantity': 1,
          'dynamic_data': jsonEncode({'type_line': 'Artifact'}),
        },
        {
          'id': 'double-qty',
          'name': 'Double Card',
          'board_zone': 'Mainboard',
          'deck_quantity': 2,
          'dynamic_data': jsonEncode({'type_line': 'Artifact'}),
        },
        {
          'id': 'four-qty',
          'name': 'Playset Card',
          'board_zone': 'Mainboard',
          'deck_quantity': 4,
          'dynamic_data': jsonEncode({'type_line': 'Artifact'}),
        },
        {
          'id': 'high-qty',
          'name': 'Relentless Rats',
          'board_zone': 'Mainboard',
          'deck_quantity': 99,
          'dynamic_data': jsonEncode({'type_line': 'Creature — Rat'}),
        },
        {
          'id': 'fallback-qty',
          'name': 'Fallback Quantity Card',
          'board_zone': 'Mainboard',
          // deck_quantity omitted; quantity = 3
          'quantity': 3,
          'dynamic_data': jsonEncode({'type_line': 'Sorcery'}),
        },
      ];

      await tester.pumpWidget(createSubject(deck: testDeck, items: items));
      await tester.pumpAndSettle();

      // Switch to Grid View
      await tester.tap(find.byKey(const Key('deck_builder_view_mode_toggle')));
      await tester.pumpAndSettle();

      // Assert badge visibility
      expect(find.text('1x'), findsNothing, reason: 'qty == 1 must NOT display a quantity badge');
      expect(find.text('2x'), findsOneWidget, reason: 'qty == 2 must display 2x badge');
      expect(find.text('4x'), findsOneWidget, reason: 'qty == 4 must display 4x badge');
      expect(find.text('99x'), findsOneWidget, reason: 'qty == 99 must display 99x badge');
      expect(find.text('3x'), findsOneWidget, reason: 'quantity fallback should display 3x badge');

      expect(tester.takeException(), isNull);
    });

    testWidgets('6. Card cell tap gesture hit-testing and CardDetailSheet interaction', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final items = [
        {
          'id': 'tap-test-card',
          'name': 'Lightning Bolt',
          'board_zone': 'Mainboard',
          'deck_quantity': 4,
          'dynamic_data': jsonEncode({'type_line': 'Instant'}),
        },
      ];

      await tester.pumpWidget(createSubject(deck: testDeck, items: items));
      await tester.pumpAndSettle();

      // Switch to Grid View
      await tester.tap(find.byKey(const Key('deck_builder_view_mode_toggle')));
      await tester.pumpAndSettle();

      final cellFinder = find.byKey(const Key('deck_grid_card_tap-test-card'));
      expect(cellFinder, findsOneWidget);

      // Tap the card cell directly
      await tester.tap(cellFinder);
      await tester.pumpAndSettle();

      // CardDetailSheet should open successfully
      expect(find.byType(CardDetailSheet), findsOneWidget);

      // Close the CardDetailSheet using Navigator pop
      Navigator.of(tester.element(find.byType(CardDetailSheet))).pop();
      await tester.pumpAndSettle();

      // Back in DeckBuilderScreen, still in Grid View
      expect(find.byType(CardDetailSheet), findsNothing);
      expect(find.byType(SliverGrid), findsOneWidget);
      expect(find.byIcon(Icons.view_list_rounded), findsOneWidget);
    });

    testWidgets('7. Layout stability on varied viewports (Narrow 320x568 to Tablet 800x1200)', (tester) async {
      final viewports = [
        const Size(320, 568),  // iPhone SE 1st gen / narrow screen
        const Size(375, 667),  // Standard phone
        const Size(412, 915),  // Large Android phone
        const Size(800, 1200), // Tablet
      ];

      final items = [
        {
          'id': 'c-1',
          'name': 'Gaea\'s Cradle',
          'board_zone': 'Mainboard',
          'deck_quantity': 1,
          'dynamic_data': jsonEncode({'type_line': 'Legendary Land'}),
        },
        {
          'id': 'c-2',
          'name': 'Serra\'s Sanctum',
          'board_zone': 'Mainboard',
          'deck_quantity': 1,
          'dynamic_data': jsonEncode({'type_line': 'Legendary Land'}),
        },
        {
          'id': 'c-3',
          'name': 'Tolarian Academy',
          'board_zone': 'Mainboard',
          'deck_quantity': 1,
          'dynamic_data': jsonEncode({'type_line': 'Legendary Land'}),
        },
      ];

      for (int i = 0; i < viewports.length; i++) {
        final viewport = viewports[i];
        tester.view.physicalSize = viewport;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(createSubject(
          deck: testDeck,
          items: items,
          screenKey: ValueKey('screen-$i'),
        ));
        await tester.pumpAndSettle();

        // Switch to Grid View
        final toggleFinder = find.byKey(const Key('deck_builder_view_mode_toggle'));
        await tester.tap(toggleFinder);
        await tester.pumpAndSettle();

        expect(find.byType(SliverGrid), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'No RenderFlex overflow on viewport $viewport');
      }
      tester.view.resetPhysicalSize();
    });

    testWidgets('8. Handling empty deck in grid mode', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createSubject(deck: testDeck, items: []));
      await tester.pumpAndSettle();

      // Empty placeholder is displayed
      expect(find.textContaining('No cards in this deck yet'), findsOneWidget);

      // View mode toggle button is still available
      final toggleFinder = find.byKey(const Key('deck_builder_view_mode_toggle'));
      expect(toggleFinder, findsOneWidget);

      // Tapping view mode toggle on empty deck does not crash or break
      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();

      expect(find.textContaining('No cards in this deck yet'), findsOneWidget);
      expect(find.byType(SliverGrid), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('9. Robust classification with corrupted/malformed dynamic_data', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final items = [
        {
          'id': 'bad-1',
          'name': 'Malformed JSON Card',
          'board_zone': 'Mainboard',
          'deck_quantity': 1,
          'dynamic_data': '{invalid-json',
        },
        {
          'id': 'bad-2',
          'name': 'Null Dynamic Data Card',
          'board_zone': 'Sideboard',
          'deck_quantity': 1,
          'dynamic_data': null,
        },
        {
          'id': 'bad-3',
          'name': 'Empty String Dynamic Data',
          'board_zone': 'Maybeboard',
          'deck_quantity': 1,
          'dynamic_data': '',
        },
        {
          'id': 'bad-4',
          'name': 'No Zone Card',
          'deck_quantity': 1,
          'dynamic_data': jsonEncode({'type_line': ''}),
        },
      ];

      await tester.pumpWidget(createSubject(deck: testDeck, items: items));
      await tester.pumpAndSettle();

      // Toggle to grid mode
      final toggleFinder = find.byKey(const Key('deck_builder_view_mode_toggle'));
      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();

      // Should gracefully fall back without throwing FormatException
      expect(find.byType(SliverGrid), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('10. Details and Values tab navigation while in grid mode', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final items = [
        {
          'id': 'sol-ring',
          'name': 'Sol Ring',
          'board_zone': 'Mainboard',
          'deck_quantity': 1,
          'current_market_price': 1.50,
          'dynamic_data': jsonEncode({'type_line': 'Artifact'}),
        },
      ];

      await tester.pumpWidget(createSubject(deck: testDeck, items: items));
      await tester.pumpAndSettle();

      // Switch to Grid View
      final toggleFinder = find.byKey(const Key('deck_builder_view_mode_toggle'));
      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();

      expect(find.byType(SliverGrid), findsOneWidget);

      // Switch to Values tab
      final valuesTabFinder = find.text('Values');
      if (valuesTabFinder.evaluate().isNotEmpty) {
        await tester.tap(valuesTabFinder);
        await tester.pumpAndSettle();

        // Values tab displays market value slivers, not the details grid
        expect(find.byType(SliverGrid), findsNothing);

        // Switch back to Details tab
        final detailsTabFinder = find.text('Details');
        await tester.tap(detailsTabFinder);
        await tester.pumpAndSettle();

        // Grid View is restored cleanly
        expect(find.byType(SliverGrid), findsOneWidget);
        expect(find.byIcon(Icons.view_list_rounded), findsOneWidget);
      }
    });
  });
}
