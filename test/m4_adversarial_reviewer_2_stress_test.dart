import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'features/decks/deck_test_helpers.dart';
import 'package:countr/features/decks/data/mock_deck_data.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/decks/presentation/screens/deck_builder_screen.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/screens/vault_screen.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late VaultDao dao;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dao = db.vaultDao;
  });

  tearDown(() async {
    await db.close();
  });

  VaultItem createCard({
    required String id,
    required String name,
    String setCode = 'cmd',
    double price = 10.0,
    List<Map<String, String>>? rulings,
    bool hasDoubleFace = false,
  }) {
    return VaultItem(
      id: id,
      collectionType: 'mtg',
      name: name,
      setOrSeries: setCode.toUpperCase(),
      imageUrl: 'https://cards.scryfall.io/large/front/$id.jpg',
      acquiredPrice: price,
      acquiredDate: DateTime(2026, 9, 1),
      quantity: 1,
      condition: 'NM',
      isGraded: false,
      isAltered: false,
      isMisprint: false,
      isSigned: false,
      isDeleted: false,
      personalNotes: 'Test card note for $name',
      primaryBinderId: null,
      currentMarketPrice: price * 1.5,
      lastPriceUpdate: DateTime(2026, 9, 1),
      dynamicData: jsonEncode({
        'collector_number': '100',
        'set': setCode.toLowerCase(),
        'mana_cost': '{2}{U}{B}',
        'cmc': 4.0,
        'type_line': 'Legendary Creature — Wizard',
        'oracle_text': 'Flying, deathtouch.\nWhenever this creature deals combat damage, draw a card.',
        'cached_rulings': rulings ?? [
          {'published_at': '2023-01-01', 'comment': 'Ruling 1 for $name with {T}.'},
          {'published_at': '2023-06-01', 'comment': 'Ruling 2 for $name with {U/B}.'},
        ],
        if (hasDoubleFace)
          'card_faces': [
            {
              'name': '$name (Front)',
              'mana_cost': '{2}{U}',
              'type_line': 'Creature',
              'oracle_text': 'Transform at beginning of upkeep.',
              'image_uris': {'normal': 'https://cards.scryfall.io/front/$id.jpg'},
            },
            {
              'name': '$name (Back)',
              'mana_cost': '',
              'type_line': 'Demon',
              'oracle_text': 'Flying, trample.',
              'image_uris': {'normal': 'https://cards.scryfall.io/back/$id.jpg'},
            },
          ],
      }),
    );
  }

  Widget wrapWithHarness(
    Widget child, {
    Size size = const Size(360, 640),
    TextScaler textScaler = TextScaler.noScaling,
    String activeGame = 'Magic: The Gathering',
  }) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        vaultDaoProvider.overrideWithValue(dao),
        activeGameContextProvider.overrideWith((ref) => activeGame),
        vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: size, textScaler: textScaler),
          child: Scaffold(body: child),
        ),
      ),
    );
  }

  group('Adversarial Review 1: Rapid Swiping Across Multi-Card Lists', () {
    testWidgets('20 rapid flings across 10 cards cause ZERO exceptions and maintain state', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final cards = List.generate(
        10,
        (i) => createCard(id: 'swipe-card-$i', name: 'Card #$i Extreme Multi-Card', hasDoubleFace: i % 2 == 0),
      );

      int lastChangedIndex = 0;
      await tester.pumpWidget(wrapWithHarness(
        CardDetailSheet(
          items: cards,
          initialIndex: 0,
          fetchOnlinePrintings: false,
          onPageChanged: (idx) => lastChangedIndex = idx,
        ),
      ));
      await tester.pumpAndSettle();

      final pageViewFinder = find.byKey(const Key('card_detail_page_view'));
      expect(pageViewFinder, findsOneWidget);

      // Perform 10 rapid flings to the left
      for (int i = 0; i < 9; i++) {
        await tester.fling(pageViewFinder, const Offset(-350, 0), 1200);
        await tester.pump(const Duration(milliseconds: 30));
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(lastChangedIndex, greaterThan(0));

      // Perform 10 rapid flings to the right
      for (int i = 0; i < 9; i++) {
        await tester.fling(pageViewFinder, const Offset(350, 0), 1200);
        await tester.pump(const Duration(milliseconds: 30));
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Rapid swiping while scroll offset > 0 resets inner scroll to 0 cleanly without offset throw', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final cards = [
        createCard(id: 'scroll-reset-0', name: 'Card Zero'),
        createCard(id: 'scroll-reset-1', name: 'Card One'),
        createCard(id: 'scroll-reset-2', name: 'Card Two'),
      ];

      await tester.pumpWidget(wrapWithHarness(
        CardDetailSheet(
          items: cards,
          initialIndex: 0,
          fetchOnlinePrintings: false,
        ),
      ));
      await tester.pumpAndSettle();

      final listFinder = find.byKey(PageStorageKey('card_detail_list_${cards[0].id}'));
      expect(listFinder, findsOneWidget);

      // Scroll card 0 down by 300px
      await tester.drag(listFinder, const Offset(0, -300));
      await tester.pumpAndSettle();

      // Swipe to card 1
      final pageViewFinder = find.byKey(const Key('card_detail_page_view'));
      await tester.fling(pageViewFinder, const Offset(-350, 0), 1000);
      await tester.pumpAndSettle();

      expect(find.text('Card One'), findsWidgets);
      expect(tester.takeException(), isNull);

      // Swipe to card 2
      await tester.fling(pageViewFinder, const Offset(-350, 0), 1000);
      await tester.pumpAndSettle();

      expect(find.text('Card Two'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('Adversarial Review 2: ExpansionTile Accordion and PageStorage Isolation', () {
    testWidgets('Repeatedly toggling ExpansionTile and scrolling produces ZERO _TypeError exceptions', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final card = createCard(
        id: 'accordion-stress-card',
        name: 'Accordion Stress Card',
        rulings: List.generate(
          5,
          (i) => {'published_at': '2023-0$i-01', 'comment': 'Detailed ruling $i with rule context.'},
        ),
      );

      await tester.pumpWidget(wrapWithHarness(
        CardDetailSheet(
          item: card,
          fetchOnlinePrintings: false,
        ),
      ));
      await tester.pumpAndSettle();

      final listFinder = find.byKey(PageStorageKey('card_detail_list_${card.id}'));
      expect(listFinder, findsOneWidget);

      // Scroll down until rulings accordion is visible
      await tester.drag(listFinder, const Offset(0, -600));
      await tester.pumpAndSettle();

      final accordionFinder = find.byKey(const Key('card_detail_rulings_accordion'));
      expect(accordionFinder, findsOneWidget);
      await tester.ensureVisible(accordionFinder);
      await tester.pumpAndSettle();

      // Repeatedly toggle accordion (collapse and expand)
      for (int i = 0; i < 4; i++) {
        await tester.tap(accordionFinder);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      // Scroll all the way back to the top
      await tester.drag(listFinder, const Offset(0, 800));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('Adversarial Review 3: DeckBuilderScreen Collapse Title Collision', () {
    final widths = [320.0, 360.0, 400.0, 414.0];

    for (final width in widths) {
      testWidgets('Collapsed title bounds never overlap back button (56px) or actions (144px) at w=${width.toInt()}', (tester) async {
        tester.view.physicalSize = Size(width, 700);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final deck = createTestDeck(
          id: 'deck-collision-test',
          name: 'Edgar Markov Aristocrats Long Name That Could Overflow',
          format: 'Commander',
          isRegistered: width > 320,
          wins: 10,
          losses: 2,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              deckItemsProvider(deck.id).overrideWith(
                (ref) => Stream.value(MockDeckData.getDeckItems(deck.id)),
              ),
            ],
            child: MaterialApp(
              home: Navigator(
                onGenerateRoute: (settings) => MaterialPageRoute(
                  builder: (_) => DeckBuilderScreen(deck: deck),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        final scrollableFinder = find.byType(CustomScrollView);
        expect(scrollableFinder, findsOneWidget);

        // Fully collapse the SliverAppBar
        await tester.drag(scrollableFinder, const Offset(0, -300));
        await tester.pumpAndSettle();

        final titleFinder = find.text(deck.name);
        expect(titleFinder, findsOneWidget);

        final Rect titleRect = tester.getRect(titleFinder);

        // Verify left edge clearance: must be >= 56.0 (back button width)
        expect(
          titleRect.left,
          greaterThanOrEqualTo(56.0 - 0.05),
          reason: 'Collapsed title left edge (${titleRect.left}) collided with back button (< 56.0) on w=$width',
        );

        // Verify right edge clearance: must be <= width - 144.0 (trailing actions width)
        expect(
          titleRect.right,
          lessThanOrEqualTo(width - 144.0 + 0.05),
          reason: 'Collapsed title right edge (${titleRect.right}) collided with actions (> ${width - 144.0}) on w=$width',
        );

        expect(tester.takeException(), isNull);
      });
      }
    });

  group('Adversarial Review 4: VaultScreen Context-Aware Category Filter Pills', () {
    testWidgets('MTG mode strictly suppresses non-TCG category chips and renders all 7 MTG pills', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(wrapWithHarness(
        const VaultScreen(),
        size: const Size(390, 844),
        activeGame: 'Magic: The Gathering',
      ));
      await tester.pumpAndSettle();

      // Universal base pills
      expect(find.byKey(const Key('vault_filter_chip_owned')), findsOneWidget);
      expect(find.byKey(const Key('vault_filter_chip_catalog_(ref)')), findsOneWidget);

      // MTG specific pills
      expect(find.byKey(const Key('vault_filter_chip_colors')), findsOneWidget);
      expect(find.byKey(const Key('vault_filter_chip_mana_value')), findsOneWidget);
      expect(find.byKey(const Key('vault_filter_chip_card_types')), findsOneWidget);
      expect(find.byKey(const Key('vault_filter_chip_formats')), findsOneWidget);
      expect(find.byKey(const Key('vault_filter_chip_rarity')), findsOneWidget);
      expect(find.byKey(const Key('vault_filter_chip_sets')), findsOneWidget);
      expect(find.byKey(const Key('vault_filter_chip_foils')), findsOneWidget);

      // Strictly suppressed chips
      expect(find.byKey(const Key('vault_filter_chip_comics')), findsNothing);
      expect(find.byKey(const Key('vault_filter_chip_sports_cards')), findsNothing);
      expect(find.byKey(const Key('vault_filter_chip_graded_slabs')), findsNothing);
      expect(find.byKey(const Key('vault_filter_chip_raw_singles')), findsNothing);
      expect(find.byKey(const Key('vault_filter_chip_high_p/l')), findsNothing);
    });

    testWidgets('All Collections mode renders polymorphic category chips and suppresses MTG pills', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(wrapWithHarness(
        const VaultScreen(),
        size: const Size(390, 844),
        activeGame: 'All Collections',
      ));
      await tester.pumpAndSettle();

      // Universal base pills
      expect(find.byKey(const Key('vault_filter_chip_owned')), findsOneWidget);
      expect(find.byKey(const Key('vault_filter_chip_catalog_(ref)')), findsOneWidget);

      // Polymorphic category pills
      expect(find.byKey(const Key('vault_filter_chip_graded_slabs')), findsOneWidget);
      expect(find.byKey(const Key('vault_filter_chip_raw_singles')), findsOneWidget);
      expect(find.byKey(const Key('vault_filter_chip_comics')), findsOneWidget);
      expect(find.byKey(const Key('vault_filter_chip_sports_cards')), findsOneWidget);
      expect(find.byKey(const Key('vault_filter_chip_high_p/l')), findsOneWidget);

      // Suppressed MTG pills
      expect(find.byKey(const Key('vault_filter_chip_colors')), findsNothing);
      expect(find.byKey(const Key('vault_filter_chip_mana_value')), findsNothing);
      expect(find.byKey(const Key('vault_filter_chip_formats')), findsNothing);
    });

    testWidgets('VaultScreen on 320x568 viewport at 2.0x font scaling renders controls and pills with ZERO RenderFlex overflows', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final List<FlutterErrorDetails> errors = [];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        errors.add(details);
        originalOnError?.call(details);
      };

      try {
        await tester.pumpWidget(wrapWithHarness(
          const VaultScreen(),
          size: const Size(320, 568),
          textScaler: const TextScaler.linear(2.0),
          activeGame: 'Magic: The Gathering',
        ));
        await tester.pumpAndSettle();

        // Horizontal scroll the filter pills row
        final pillsFinder = find.byType(SingleChildScrollView).first;
        await tester.drag(pillsFinder, const Offset(-200, 0));
        await tester.pumpAndSettle();

        final overflowErrors = errors.where((e) => e.exceptionAsString().contains('overflowed')).toList();
        expect(
          overflowErrors,
          isEmpty,
          reason: 'VaultScreen must not overflow on 320px viewport at 2.0x text scale. Detected: ${overflowErrors.map((e) => e.exceptionAsString()).join("; ")}',
        );
        expect(tester.takeException(), isNull);
      } finally {
        FlutterError.onError = originalOnError;
      }
    });
  });
}
