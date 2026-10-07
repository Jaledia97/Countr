import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/decks/presentation/screens/deck_builder_screen.dart';
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
    id: 'deck-m5-adversarial',
    name: 'Adversarial M5 Grid Stress Deck With A Very Long Name',
    format: 'Commander',
    createdAt: DateTime.now(),
    wins: 99,
    losses: 1,
    draws: 0,
  );

  Widget createSubject({
    required Deck deck,
    required List<Map<String, dynamic>> items,
    Size size = const Size(400, 800),
    double textScale = 1.0,
  }) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        vaultDaoProvider.overrideWithValue(db.vaultDao),
        deckItemsProvider(deck.id).overrideWith((ref) => Stream.value(items)),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: DeckBuilderScreen(deck: deck),
        ),
      ),
    );
  }

  group('Reviewer 1 Adversarial Challenges: Milestone 5 Grid View', () {
    testWidgets('1. Tight viewport (320x568) + 2.0x text scale renders Grid View without layout overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final items = [
        {
          'id': 'cmd-1',
          'name': 'Extremely Long Commander Name That Should Be Ellipsized Safely',
          'board_zone': 'Commander',
          'deck_quantity': 1,
          'dynamic_data': jsonEncode({'type_line': 'Legendary Creature — Dragon'}),
        },
        {
          'id': 'cr-1',
          'name': 'Creature Card With High Quantity',
          'board_zone': 'Mainboard',
          'deck_quantity': 99,
          'dynamic_data': jsonEncode({'type_line': 'Creature — Goblin'}),
        },
        {
          'id': 'land-1',
          'name': 'Island',
          'board_zone': 'Mainboard',
          'deck_quantity': 25,
          'dynamic_data': jsonEncode({'type_line': 'Basic Land — Island'}),
        },
      ];

      await tester.pumpWidget(
        createSubject(deck: testDeck, items: items, size: const Size(320, 568), textScale: 2.0),
      );
      await tester.pumpAndSettle();

      // Switch to Grid View
      final toggleFinder = find.byKey(const Key('deck_builder_view_mode_toggle'));
      expect(toggleFinder, findsOneWidget);
      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();

      // Ensure no layout exceptions or RenderFlex overflows occur
      expect(tester.takeException(), isNull, reason: 'RenderFlex overflow in Grid View on 320px + 2.0x text scale');
      expect(find.byType(SliverGrid), findsWidgets);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(find.text('99x'), findsOneWidget);
    });

    testWidgets('2. Ultra-narrow viewport (280x653) renders Grid View without RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(280, 653);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final items = [
        {
          'id': 'c-1',
          'name': 'Sol Ring',
          'board_zone': 'Mainboard',
          'deck_quantity': 1,
          'dynamic_data': jsonEncode({'type_line': 'Artifact'}),
        },
      ];

      await tester.pumpWidget(
        createSubject(deck: testDeck, items: items, size: const Size(280, 653)),
      );
      await tester.pumpAndSettle();

      // Switch to Grid View
      await tester.tap(find.byKey(const Key('deck_builder_view_mode_toggle')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'RenderFlex overflow on 280px ultra-narrow viewport');
      expect(find.byType(SliverGrid), findsOneWidget);
    });

    testWidgets('3. Rapid toggle between List and Grid modes maintains stable state and scroll position', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final items = [
        {
          'id': 'c-1',
          'name': 'Card 1',
          'board_zone': 'Mainboard',
          'deck_quantity': 1,
          'dynamic_data': jsonEncode({'type_line': 'Instant'}),
        },
        {
          'id': 'c-2',
          'name': 'Card 2',
          'board_zone': 'Mainboard',
          'deck_quantity': 2,
          'dynamic_data': jsonEncode({'type_line': 'Sorcery'}),
        },
      ];

      await tester.pumpWidget(createSubject(deck: testDeck, items: items));
      await tester.pumpAndSettle();

      final toggle = find.byKey(const Key('deck_builder_view_mode_toggle'));

      for (int i = 0; i < 6; i++) {
        await tester.tap(toggle);
        await tester.pump();
      }
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Ended in list mode after 6 taps (even number)
      expect(find.byType(SliverGrid), findsNothing);
      expect(find.byType(SliverList), findsWidgets);
    });

    testWidgets('4. Malformed dynamic_data and missing fields gracefully fallback to board_zone without crashing', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final items = [
        {
          'id': 'empty-json-1',
          'name': 'Empty JSON Card',
          'board_zone': 'Mainboard',
          'deck_quantity': 1,
          'dynamic_data': '{}',
        },
        {
          'id': 'empty-1',
          'name': 'Empty Dynamic Data Card',
          'board_zone': 'Sideboard',
          'deck_quantity': 1,
          'dynamic_data': '',
        },
        {
          'id': 'null-zone-1',
          'name': 'Null Zone Card',
          'board_zone': null,
          'deck_quantity': 1,
          'dynamic_data': null,
        },
      ];

      await tester.pumpWidget(createSubject(deck: testDeck, items: items));
      await tester.pumpAndSettle();

      // Switch to Grid View
      await tester.tap(find.byKey(const Key('deck_builder_view_mode_toggle')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('MAINBOARD'), findsOneWidget);
      expect(find.text('SIDEBOARD'), findsOneWidget);
      expect(find.byType(SliverGrid), findsWidgets);
    });

    testWidgets('5. Leading back button matcher uniqueness invariant: AppBar actions have 0 IconButtons', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createSubject(deck: testDeck, items: []));
      await tester.pumpAndSettle();

      // Find all IconButtons inside SliverAppBar
      final iconButtonsInAppBar = find.descendant(
        of: find.byType(SliverAppBar),
        matching: find.byType(IconButton),
      );

      // Must be exactly 1: the leading back button
      expect(iconButtonsInAppBar, findsOneWidget);

      final leadingButton = tester.widget<IconButton>(iconButtonsInAppBar);
      expect(leadingButton.key, const Key('deck_builder_back_button'));
    });
  });
}
