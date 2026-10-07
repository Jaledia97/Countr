import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/cache/countr_cached_image.dart';
import 'package:countr/core/state/settings_state.dart';
import 'package:countr/features/decks/data/mock_deck_data.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/decks/presentation/screens/deck_builder_screen.dart';
import 'package:countr/features/decks/presentation/widgets/inline_deck_analytics_card.dart';
import 'package:countr/features/values/domain/services/deck_values_calculator.dart';
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

  group('Milestone 6 Challenger 2: Adversarial Multi-Feature Concert Tests', () {
    testWidgets('1. Concert: Root navigation -> Cover update -> Grid toggle -> Live analytics -> Finish pricing -> System back', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final initialDeck = createTestDeck(
        id: 'deck-concert-1',
        name: 'Omnath Locus of Mana Deck',
        format: 'Commander',
        createdAt: DateTime(2023, 1, 1),
        wins: 12,
        losses: 4,
        draws: 1,
        description: 'Concert test primer notes',
      );

      final deckStateController = StreamController<Deck>.broadcast();
      final itemsStateController = StreamController<List<Map<String, dynamic>>>.broadcast();

      final initialItems = [
        {
          'id': 'omnath-cmd',
          'name': 'Omnath, Locus of Mana',
          'board_zone': 'Commander',
          'deck_quantity': 1,
          'finish': 'foil',
          'is_foil': 1,
          'image_url': 'https://cards.scryfall.io/large/front/o/m/omnath.jpg',
          'dynamic_data': jsonEncode({
            'type_line': 'Legendary Creature — Elemental',
            'mana_cost': '{2}{G}',
            'cmc': 3,
            'image_uris': {
              'art_crop': 'https://cards.scryfall.io/art_crop/front/o/m/omnath_art.jpg',
              'normal': 'https://cards.scryfall.io/normal/front/o/m/omnath.jpg',
            },
            'prices': {
              'usd': '15.00',
              'usd_foil': '35.00',
            },
          }),
        },
        {
          'id': 'sol-ring-art',
          'name': 'Sol Ring',
          'board_zone': 'Mainboard',
          'deck_quantity': 1,
          'finish': 'nonfoil',
          'is_foil': 0,
          'image_url': 'https://cards.scryfall.io/large/front/s/o/sol_ring.jpg',
          'dynamic_data': jsonEncode({
            'type_line': 'Artifact',
            'mana_cost': '{1}',
            'cmc': 1,
            'image_uris': {
              'art_crop': 'https://cards.scryfall.io/art_crop/front/s/o/sol_ring_art.jpg',
              'normal': 'https://cards.scryfall.io/normal/front/s/o/sol_ring.jpg',
            },
            'prices': {
              'usd': '2.00',
              'usd_foil': '8.00',
            },
          }),
        },
        {
          'id': 'doubling-season-enc',
          'name': 'Doubling Season',
          'board_zone': 'Mainboard',
          'deck_quantity': 2,
          'finish': 'foil',
          'is_foil': 1,
          'image_url': 'https://cards.scryfall.io/large/front/d/o/doubling.jpg',
          'dynamic_data': jsonEncode({
            'type_line': 'Enchantment',
            'mana_cost': '{4}{G}',
            'cmc': 5,
            'image_uris': {
              'art_crop': 'https://cards.scryfall.io/art_crop/front/d/o/doubling_art.jpg',
              'normal': 'https://cards.scryfall.io/normal/front/d/o/doubling.jpg',
            },
            'prices': {
              'usd': '40.00',
              'usd_foil': '75.00',
            },
          }),
        },
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(db.vaultDao),
            deckProvider(initialDeck.id).overrideWith((ref) => deckStateController.stream),
            deckItemsProvider(initialDeck.id).overrideWith((ref) => itemsStateController.stream),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  key: const Key('launch_deck_builder'),
                  onPressed: () {
                    Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute(
                        builder: (_) => DeckBuilderScreen(deck: initialDeck),
                      ),
                    );
                  },
                  child: const Text('Launch Deck'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Launch screen via rootNavigator
      await tester.tap(find.byKey(const Key('launch_deck_builder')));
      await tester.pump();

      deckStateController.add(initialDeck);
      itemsStateController.add(initialItems);
      await tester.pumpAndSettle();

      expect(find.byType(DeckBuilderScreen), findsOneWidget);

      // Verify Initial Cover Art Resolution (Commander is Omnath)
      final initialCoverImage = tester.widget<CountrCachedImage>(
        find.descendant(
          of: find.byType(SliverAppBar),
          matching: find.byType(CountrCachedImage),
        ).first,
      );
      expect(initialCoverImage.cacheKey, equals('deck_cover_deck-concert-1'));
      expect(initialCoverImage.imageUrl, contains('omnath_art.jpg'));

      // Verify Inline Analytics Card is present
      expect(find.byType(InlineDeckAnalyticsCard), findsOneWidget);
      // Expand Analytics Card to reveal user notes and charts
      final expandToggle = find.byKey(const Key('inline_analytics_collapse_toggle'));
      expect(expandToggle, findsOneWidget);
      await tester.tap(expandToggle);
      await tester.pumpAndSettle();

      // Notes are now visible
      expect(find.text('Concert test primer notes'), findsOneWidget);

      // Verify Monetary Valuation (Omnath foil 35 + Sol Ring nonfoil 2 + 2x Doubling Season foil 75 = 35 + 2 + 150 = 187)
      final calcResult = DeckValuesCalculator.calculate(
        deckId: initialDeck.id,
        items: initialItems,
        currency: AppCurrency.usd,
      );
      expect(calcResult.totalMarketValue, equals(187.0));
      expect(calcResult.totalCardCount, equals(4)); // 1 + 1 + 2

      // Now Switch from List View to Grid View
      final toggleFinder = find.byKey(const Key('deck_builder_view_mode_toggle'));
      expect(toggleFinder, findsOneWidget);
      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();

      // In Grid View: verify SliverGrid exists with 3 columns and childAspectRatio 0.714
      final sliverGrids = tester.widgetList<SliverGrid>(find.byType(SliverGrid)).toList();
      expect(sliverGrids, isNotEmpty);
      for (final grid in sliverGrids) {
        final delegate = grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
        expect(delegate.crossAxisCount, equals(3));
        expect(delegate.childAspectRatio, equals(0.714));
      }

      // Verify Section Headers for partitioned types: Commander, Artifacts, Enchantments (displayed in uppercase)
      expect(find.text('COMMANDER'), findsOneWidget);
      expect(find.text('ARTIFACTS'), findsOneWidget);
      expect(find.text('ENCHANTMENTS'), findsOneWidget);

      // Now update Cover Art to Sol Ring (custom cover art)
      final updatedDeck = initialDeck.copyWith(coverItemId: const drift.Value('sol-ring-art'));
      deckStateController.add(updatedDeck);
      await tester.pumpAndSettle();

      // Verify Cover Art dynamic key and URL immediately switched to Sol Ring
      final updatedCoverImage = tester.widget<CountrCachedImage>(
        find.descendant(
          of: find.byType(SliverAppBar),
          matching: find.byType(CountrCachedImage),
        ).first,
      );
      expect(updatedCoverImage.cacheKey, equals('deck_cover_deck-concert-1_sol-ring-art'));
      expect(updatedCoverImage.imageUrl, contains('sol_ring_art.jpg'));

      // Now perform physical/system back navigation via handlePopRoute
      final popHandled = await tester.binding.handlePopRoute();
      expect(popHandled, isTrue, reason: 'Physical back navigation must be intercepted by PopScope and popped cleanly');
      await tester.pumpAndSettle();

      // Verify DeckBuilderScreen is gone and parent screen is visible
      expect(find.byType(DeckBuilderScreen), findsNothing);
      expect(find.byKey(const Key('launch_deck_builder')), findsOneWidget);

      await deckStateController.close();
      await itemsStateController.close();
    });

    testWidgets('2. Concert: DFC, split mana, and edge cases in multi-section grid with live analytics', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final deck = createTestDeck(
        id: 'deck-concert-dfc',
        name: 'DFC Complex Archetype',
        format: 'Modern',
        createdAt: DateTime(2023, 1, 1),
      );

      final dfcItems = [
        {
          'id': 'delver-1',
          'name': 'Delver of Secrets // Insectile Aberration',
          'board_zone': 'Mainboard',
          'deck_quantity': 4,
          'finish': 'etched',
          'is_foil': 1,
          'dynamic_data': jsonEncode({
            'card_faces': [
              {
                'name': 'Delver of Secrets',
                'type_line': 'Creature — Human Wizard',
                'mana_cost': '{U}',
                'image_uris': {
                  'normal': 'https://cards.scryfall.io/normal/front/d/e/delver.jpg',
                },
              },
              {
                'name': 'Insectile Aberration',
                'type_line': 'Creature — Human Insect',
                'image_uris': {
                  'normal': 'https://cards.scryfall.io/normal/back/d/e/delver_back.jpg',
                },
              },
            ],
            'prices': {
              'usd': '1.50',
              'usd_etched': '6.00',
            },
          }),
        },
        {
          'id': 'fire-ice-1',
          'name': 'Fire // Ice',
          'board_zone': 'Mainboard',
          'deck_quantity': 3,
          'finish': 'nonfoil',
          'is_foil': 0,
          'dynamic_data': jsonEncode({
            'type_line': 'Instant // Instant',
            'mana_cost': '{1}{R} // {1}{U}',
            'cmc': 4,
            'image_uris': {
              'normal': 'https://cards.scryfall.io/normal/front/f/i/fire_ice.jpg',
            },
            'prices': {
              'usd': '0.75',
              'usd_foil': '3.00',
            },
          }),
        },
        {
          'id': 'mox-amber-1',
          'name': 'Mox Amber',
          'board_zone': 'Mainboard',
          'deck_quantity': 2,
          'finish': 'foil',
          'is_foil': 1,
          'dynamic_data': jsonEncode({
            'type_line': 'Legendary Artifact',
            'mana_cost': '{0}',
            'cmc': 0,
            'image_uris': {
              'normal': 'https://cards.scryfall.io/normal/front/m/o/mox_amber.jpg',
            },
            'prices': {
              'usd': '45.00',
              'usd_foil': '85.00',
            },
          }),
        },
        {
          'id': 'steam-vents-land',
          'name': 'Steam Vents',
          'board_zone': 'Mainboard',
          'deck_quantity': 4,
          'finish': 'nonfoil',
          'is_foil': 0,
          'dynamic_data': jsonEncode({
            'type_line': 'Land — Island Mountain',
            'mana_cost': '',
            'cmc': 0,
            'image_uris': {
              'normal': 'https://cards.scryfall.io/normal/front/s/t/steam_vents.jpg',
            },
            'prices': {
              'usd': '18.00',
            },
          }),
        },
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(db.vaultDao),
            deckProvider(deck.id).overrideWith((ref) => Stream.value(deck)),
            deckItemsProvider(deck.id).overrideWith((ref) => Stream.value(dfcItems)),
          ],
          child: MaterialApp(
            home: DeckBuilderScreen(deck: deck),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Grid View
      await tester.tap(find.byKey(const Key('deck_builder_view_mode_toggle')));
      await tester.pumpAndSettle();

      // Verify DFC card classified as 'Creatures' from card_faces (displayed as CREATURES)
      expect(find.text('CREATURES'), findsOneWidget);
      // Verify Split Instant classified as 'Instants' (displayed as INSTANTS)
      expect(find.text('INSTANTS'), findsOneWidget);
      // Verify 0-mana artifact classified as 'Artifacts' (displayed as ARTIFACTS)
      expect(find.text('ARTIFACTS'), findsOneWidget);
      // Verify Land classified as 'Lands' (displayed as LANDS)
      expect(find.text('LANDS'), findsOneWidget);

      // Verify Live Analytics computation on complex deck:
      // Total cards = 4 + 3 + 2 + 4 = 13
      final analytics = MockDeckData.computeAnalyticsFromItems(dfcItems);
      // Mox Amber is CMC 0 non-land: must be in mana curve bucket 0!
      expect(analytics.manaCurve[0], equals(2));
      // Lands (Steam Vents) must be excluded from spell mana curve!
      expect(analytics.manaCurve.values.reduce((a, b) => a + b), equals(9)); // 4 Delver + 3 Fire/Ice + 2 Mox Amber = 9 spells

      // Monetary valuation:
      // Delver etched foil: 6.00 * 4 = 24.00
      // Fire/Ice nonfoil: 0.75 * 3 = 2.25
      // Mox Amber foil: 85.00 * 2 = 170.00
      // Steam Vents nonfoil: 18.00 * 4 = 72.00
      // Total = 24 + 2.25 + 170 + 72 = 268.25
      final valuation = DeckValuesCalculator.calculate(
        deckId: deck.id,
        items: dfcItems,
        currency: AppCurrency.usd,
      );
      expect(valuation.totalMarketValue, equals(268.25));
      expect(valuation.totalCardCount, equals(13));
    });

    testWidgets('3. Concert: Empty deck edge case survives all interactions with zero exceptions', (tester) async {
      final emptyDeck = createTestDeck(
        id: 'deck-empty-concert',
        name: 'Empty Deck Concert',
        format: 'Standard',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(db.vaultDao),
            deckProvider(emptyDeck.id).overrideWith((ref) => Stream.value(emptyDeck)),
            deckItemsProvider(emptyDeck.id).overrideWith((ref) => Stream.value([])),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  key: const Key('open_empty_deck'),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => DeckBuilderScreen(deck: emptyDeck),
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_empty_deck')));
      await tester.pumpAndSettle();

      // Verify Empty message appears
      expect(find.textContaining('No cards in this deck yet'), findsOneWidget);

      // Verify toggle button does not crash when deck is empty
      final toggleFinder = find.byKey(const Key('deck_builder_view_mode_toggle'));
      if (toggleFinder.evaluate().isNotEmpty) {
        await tester.tap(toggleFinder);
        await tester.pumpAndSettle();
      }

      // Verify physical back pops empty deck cleanly
      final handled = await tester.binding.handlePopRoute();
      expect(handled, isTrue);
      await tester.pumpAndSettle();

      expect(find.byType(DeckBuilderScreen), findsNothing);
      expect(find.byKey(const Key('open_empty_deck')), findsOneWidget);
    });

    testWidgets('4. Concert: Physical back navigation during active modal bottom sheet', (tester) async {
      final deck = createTestDeck(
        id: 'deck-modal-pop',
        name: 'Modal Pop Test Deck',
        format: 'Commander',
        createdAt: DateTime.now(),
      );

      final items = MockDeckData.getDeckItems(MockDeckData.edgarMarkovDeckId);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(db.vaultDao),
            deckProvider(deck.id).overrideWith((ref) => Stream.value(deck)),
            deckItemsProvider(deck.id).overrideWith((ref) => Stream.value(items)),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  key: const Key('open_builder_modal_test'),
                  onPressed: () {
                    Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute(
                        builder: (_) => DeckBuilderScreen(deck: deck),
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_builder_modal_test')));
      await tester.pumpAndSettle();

      expect(find.byType(DeckBuilderScreen), findsOneWidget);

      // Open Fast-Draw sheet via top action button (icon Icons.style_rounded)
      final fastDrawFinder = find.byIcon(Icons.style_rounded);
      expect(fastDrawFinder, findsOneWidget);
      await tester.tap(fastDrawFinder);
      await tester.pumpAndSettle();

      // Fast-draw sheet is open
      expect(find.textContaining('Opening 7 Playtester'), findsOneWidget);

      // Press physical back: must pop ONLY the Fast-Draw sheet!
      final pop1Handled = await tester.binding.handlePopRoute();
      expect(pop1Handled, isTrue);
      await tester.pumpAndSettle();

      // Fast-draw sheet is closed, but DeckBuilderScreen is STILL mounted!
      expect(find.textContaining('Opening 7 Playtester'), findsNothing);
      expect(find.byType(DeckBuilderScreen), findsOneWidget);

      // Second physical back: must pop DeckBuilderScreen back to root!
      final pop2Handled = await tester.binding.handlePopRoute();
      expect(pop2Handled, isTrue);
      await tester.pumpAndSettle();

      expect(find.byType(DeckBuilderScreen), findsNothing);
      expect(find.byKey(const Key('open_builder_modal_test')), findsOneWidget);
    });

    test('5. Concert: Live Analytics Devotion parsing of hybrid mana and devotion pips', () {
      final items = [
        {
          'id': 'hybrid-1',
          'name': 'Dovin, Grand Arbiter',
          'board_zone': 'Mainboard',
          'deck_quantity': 1,
          'dynamic_data': jsonEncode({
            'type_line': 'Legendary Planeswalker — Dovin',
            'mana_cost': '{1}{W/U}{U}',
            'cmc': 3,
          }),
        },
        {
          'id': 'hybrid-2',
          'name': 'Rakdos Cackler',
          'board_zone': 'Mainboard',
          'deck_quantity': 2,
          'dynamic_data': jsonEncode({
            'type_line': 'Creature — Devil',
            'mana_cost': '{B/R}',
            'cmc': 1,
          }),
        },
        {
          'id': 'colorless-1',
          'name': 'Kozilek, the Great Distortion',
          'board_zone': 'Mainboard',
          'deck_quantity': 1,
          'dynamic_data': jsonEncode({
            'type_line': 'Legendary Creature — Eldrazi',
            'mana_cost': '{8}{C}{C}',
            'cmc': 10,
          }),
        },
      ];

      final analytics = MockDeckData.computeAnalyticsFromItems(items);

      // Dovin: {W/U} gives 1 W and 1 U; plus {U} gives another 1 U. Total W=1, U=2
      expect(analytics.colorDevotion['W'], equals(1));
      expect(analytics.colorDevotion['U'], equals(2));

      // Rakdos Cackler: 2 copies of {B/R} gives 2 B and 2 R
      expect(analytics.colorDevotion['B'], equals(2));
      expect(analytics.colorDevotion['R'], equals(2));

      // Kozilek: {C}{C} gives 2 colorless devotion
      expect(analytics.colorDevotion['C'], equals(2));
    });

    testWidgets('6. Concert: Narrow 320px viewport with 2.0x text scale factor renders zero overflows', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final deck = createTestDeck(
        id: 'deck-compact-scale',
        name: 'Compact Viewport Deck',
        format: 'Commander',
        createdAt: DateTime.now(),
      );

      final items = [
        {
          'id': 'cmd-item',
          'name': 'Atraxa, Praetors\' Voice',
          'board_zone': 'Commander',
          'deck_quantity': 1,
          'dynamic_data': jsonEncode({
            'type_line': 'Legendary Creature — Phyrexian Angel',
            'mana_cost': '{G}{W}{U}{B}',
            'cmc': 4,
          }),
        },
        {
          'id': 'card-item-1',
          'name': 'Demonic Tutor',
          'board_zone': 'Mainboard',
          'deck_quantity': 1,
          'dynamic_data': jsonEncode({
            'type_line': 'Sorcery',
            'mana_cost': '{1}{B}',
            'cmc': 2,
          }),
        },
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(db.vaultDao),
            deckProvider(deck.id).overrideWith((ref) => Stream.value(deck)),
            deckItemsProvider(deck.id).overrideWith((ref) => Stream.value(items)),
          ],
          child: MaterialApp(
            theme: ThemeData(
              textTheme: const TextTheme(
                bodyMedium: TextStyle(fontSize: 14),
              ),
            ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2.0)),
              child: child!,
            ),
            home: DeckBuilderScreen(deck: deck),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Grid View under high text scale
      await tester.tap(find.byKey(const Key('deck_builder_view_mode_toggle')));
      await tester.pumpAndSettle();

      // Verify zero RenderFlex overflows
      expect(tester.takeException(), isNull);
    });
  });
}
