import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/hydration/data/services/scryfall_service.dart';
import 'package:countr/features/hydration/presentation/providers/hydration_providers.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  VaultItem createTestCard({
    String id = 'card-r3-adv',
    String name = 'Nicol Bolas, the Ravager',
    int quantity = 1,
    double price = 45.00,
    String? oracleText,
    List<Map<String, String>>? rulings,
    Map<String, dynamic>? extraDynamic,
  }) {
    final dynamicMap = <String, dynamic>{
      'collector_number': '218',
      'set': 'm19',
      'mana_cost': '{1}{U}{B}{R}',
      'type_line': 'Legendary Creature — Elder Dragon',
      'keywords': ['Flying'],
      'oracle_text': oracleText ??
          'Flying\nWhen Nicol Bolas, the Ravager enters the battlefield, each opponent discards a card.\n{4}{U}{B}{R}: Exile Nicol Bolas, the Ravager, then return him to the battlefield transformed under his owner\'s control. Activate only as a sorcery.',
      'cached_rulings': rulings ?? [
        {'published_at': '2018-07-13', 'comment': 'In a multiplayer game, each opponent chooses which card to discard.'},
        {'published_at': '2018-07-13', 'comment': 'Once Nicol Bolas is exiled, he returns as a planeswalker.'},
      ],
      ...?extraDynamic,
    };

    return VaultItem(
      id: id,
      collectionType: 'mtg',
      name: name,
      setOrSeries: 'M19',
      imageUrl: 'https://cards.scryfall.io/normal/front/m19/218.jpg',
      acquiredPrice: 35.00,
      acquiredDate: DateTime(2026, 1, 1),
      quantity: quantity,
      condition: 'NM',
      isGraded: false,
      isAltered: false,
      isMisprint: false,
      isSigned: false,
      isDeleted: false,
      currentMarketPrice: price,
      lastPriceUpdate: DateTime(2026, 1, 1),
      personalNotes: 'Test note for Nicol Bolas',
      dynamicData: jsonEncode(dynamicMap),
    );
  }

  Widget createHarness(
    Widget child, {
    Size viewportSize = const Size(800, 1600),
  }) {
    final mockScryfall = ScryfallService(
      client: MockClient((request) async {
        return http.Response(jsonEncode({'object': 'list', 'data': []}), 200);
      }),
    );

    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        vaultDaoProvider.overrideWithValue(db.vaultDao),
        scryfallServiceProvider.overrideWithValue(mockScryfall),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: viewportSize),
          child: Scaffold(
            body: child,
          ),
        ),
      ),
    );
  }

  group('R3 — Adversarial Stress Test: Collapsible Art Header', () {
    // -------------------------------------------------------------------------
    // 1. Extreme Drag Flings & Snaps
    // -------------------------------------------------------------------------
    testWidgets('R3-ADV-1: High-velocity fling (-10,000px/s) collapses header without overflow', (tester) async {
      final card = createTestCard();
      await db.into(db.vaultItems).insert(card);

      await tester.pumpWidget(createHarness(CardDetailSheet(item: card, fetchOnlinePrintings: false)));
      await tester.pumpAndSettle();

      final scrollableFinder = find.byType(Scrollable).first;

      // Fling down aggressively with massive velocity
      await tester.fling(scrollableFinder, const Offset(0, -3000), 10000);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Pinned segmented tab bar must remain intact
      expect(find.text('Details'), findsOneWidget);
      expect(find.text('Values'), findsOneWidget);

      // Fling back up with massive velocity to uncollapse
      await tester.fling(scrollableFinder, const Offset(0, 3000), 10000);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(Key('card_artwork_${card.id}')), findsOneWidget);
    });

    testWidgets('R3-ADV-2: Rapid alternating drag/flings without settling maintains physics stability', (tester) async {
      final card = createTestCard();
      await db.into(db.vaultItems).insert(card);

      await tester.pumpWidget(createHarness(CardDetailSheet(item: card, fetchOnlinePrintings: false)));
      await tester.pumpAndSettle();

      final scrollableFinder = find.byType(Scrollable).first;

      // 5 rapid alternating drag motions advancing by single frames (16ms)
      for (int i = 0; i < 5; i++) {
        final direction = i.isEven ? -400.0 : 400.0;
        await tester.drag(scrollableFinder, Offset(0, direction));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Details'), findsOneWidget);
      expect(find.text('Values'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // 2. Tab Swaps Mid-Scroll & Animation
    // -------------------------------------------------------------------------
    testWidgets('R3-ADV-3: Tab swap mid-scroll retains valid scroll state across Details and Values', (tester) async {
      final card = createTestCard();
      await db.into(db.vaultItems).insert(card);

      await tester.pumpWidget(createHarness(CardDetailSheet(item: card, fetchOnlinePrintings: false)));
      await tester.pumpAndSettle();

      final scrollableFinder = find.byType(Scrollable).first;

      // Scroll halfway on Details tab
      await tester.drag(scrollableFinder, const Offset(0, -250));
      await tester.pumpAndSettle();

      // Tap Values tab while scrolled
      await tester.tap(find.text('Values'));
      await tester.pumpAndSettle();

      // Scroll further down on Values tab
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
      await tester.pumpAndSettle();

      // Tap Details tab back
      await tester.tap(find.text('Details'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Oracle Rules Text'), findsOneWidget);
    });

    testWidgets('R3-ADV-4: Rapid 20x tab toggling under simultaneous scroll load produces zero errors', (tester) async {
      final card = createTestCard();
      await db.into(db.vaultItems).insert(card);

      await tester.pumpWidget(createHarness(CardDetailSheet(item: card, fetchOnlinePrintings: false)));
      await tester.pumpAndSettle();

      for (int i = 0; i < 10; i++) {
        await tester.tap(find.text('Values'));
        await tester.pump(const Duration(milliseconds: 20));
        await tester.tap(find.text('Details'));
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Details'), findsOneWidget);
      expect(find.text('Values'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // 3. Viewport Boundary & Extreme Geometry
    // -------------------------------------------------------------------------
    testWidgets('R3-ADV-5: Ultra-compact viewport (200x240) activates ultra-compact hero sizing safely', (tester) async {
      final card = createTestCard();
      await db.into(db.vaultItems).insert(card);

      // Extreme small viewport: height < 240 triggers isUltraCompact
      await tester.pumpWidget(createHarness(
        CardDetailSheet(item: card, fetchOnlinePrintings: false),
        viewportSize: const Size(200, 230),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(CardDetailSheet), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Verify scrolling still functions
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -50));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('R3-ADV-6: Extreme wide-aspect banner viewport (1000x220) adapts without RenderFlex overflow', (tester) async {
      final card = createTestCard();
      await db.into(db.vaultItems).insert(card);

      await tester.pumpWidget(createHarness(
        CardDetailSheet(item: card, fetchOnlinePrintings: false),
        viewportSize: const Size(1000, 220),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(CardDetailSheet), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Tap Values and Details tabs in banner mode
      await tester.tap(find.text('Values'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Details'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    // -------------------------------------------------------------------------
    // 4. Cards with Varying Text Lengths & Extremes
    // -------------------------------------------------------------------------
    testWidgets('R3-ADV-7: Mega-card with 10,000 characters oracle text & 30 rulings scrolls smoothly', (tester) async {
      final hugeOracleText = List.generate(
        100,
        (i) => 'Clause $i: When this card enters the battlefield, you may choose one or both of mode A and mode B.',
      ).join('\n');

      final hugeRulings = List.generate(
        30,
        (i) => {
          'published_at': '2026-0${(i % 9) + 1}-01',
          'comment': 'Comprehensive ruling $i explains how interaction with replacement effects behaves in layer 6.',
        },
      );

      final megaCard = createTestCard(
        id: 'c-mega-text',
        name: 'The Ultimate Rules Complexity Nightmare Dragon of the Multiverse',
        oracleText: hugeOracleText,
        rulings: hugeRulings,
      );
      await db.into(db.vaultItems).insert(megaCard);

      await tester.pumpWidget(createHarness(CardDetailSheet(item: megaCard, fetchOnlinePrintings: false)));
      await tester.pumpAndSettle();

      // Deep scroll across huge content
      final scrollableFinder = find.byType(Scrollable).first;
      for (int i = 0; i < 5; i++) {
        await tester.drag(scrollableFinder, const Offset(0, -600));
        await tester.pump(const Duration(milliseconds: 30));
      }
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Switch to Values tab while deeply scrolled
      await tester.tap(find.text('Values'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('R3-ADV-8: Blank/minimal card (empty oracle text, no rulings) renders without zero-extent crashes', (tester) async {
      final emptyCard = VaultItem(
        id: 'c-blank-card',
        collectionType: 'mtg',
        name: 'Wastes',
        setOrSeries: 'OGW',
        imageUrl: '',
        acquiredPrice: 0.10,
        acquiredDate: DateTime(2026, 1, 1),
        quantity: 1,
        condition: 'NM',
        isGraded: false,
        isAltered: false,
        isMisprint: false,
        isSigned: false,
        isDeleted: false,
        currentMarketPrice: 0.10,
        lastPriceUpdate: DateTime(2026, 1, 1),
        personalNotes: null,
        dynamicData: jsonEncode({
          'type_line': 'Basic Land',
          'oracle_text': '',
          'keywords': [],
          'cached_rulings': [],
        }),
      );
      await db.into(db.vaultItems).insert(emptyCard);

      await tester.pumpWidget(createHarness(CardDetailSheet(item: emptyCard, fetchOnlinePrintings: false)));
      await tester.pumpAndSettle();

      expect(find.byType(CardDetailSheet), findsOneWidget);
      expect(find.text('Wastes'), findsWidgets);

      // Verify dragging does not throw zero-division error in delegate
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -100));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('R3-ADV-9: Multi-face card transforms cleanly during active scroll state', (tester) async {
      final flipCard = VaultItem(
        id: 'c-flip-bolas',
        collectionType: 'mtg',
        name: 'Nicol Bolas, the Ravager // Nicol Bolas, the Arisen',
        setOrSeries: 'M19',
        imageUrl: 'https://cards.scryfall.io/front/m19/218.jpg',
        acquiredPrice: 45.0,
        acquiredDate: DateTime(2026, 1, 1),
        quantity: 1,
        condition: 'NM',
        isGraded: false,
        isAltered: false,
        isMisprint: false,
        isSigned: false,
        isDeleted: false,
        currentMarketPrice: 45.0,
        lastPriceUpdate: DateTime(2026, 1, 1),
        dynamicData: jsonEncode({
          'card_faces': [
            {
              'name': 'Nicol Bolas, the Ravager',
              'mana_cost': '{1}{U}{B}{R}',
              'type_line': 'Legendary Creature — Elder Dragon',
              'oracle_text': 'Flying\nWhen Nicol Bolas enters...',
              'power': '4',
              'toughness': '4',
            },
            {
              'name': 'Nicol Bolas, the Arisen',
              'type_line': 'Legendary Planeswalker — Bolas',
              'oracle_text': '+2: Draw two cards.\n−3: Exile target creature...',
              'loyalty': '7',
            },
          ],
        }),
      );
      await db.into(db.vaultItems).insert(flipCard);

      await tester.pumpWidget(createHarness(CardDetailSheet(item: flipCard, fetchOnlinePrintings: false)));
      await tester.pumpAndSettle();

      expect(find.textContaining('Face 1/2'), findsOneWidget);

      // Scroll slightly
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -100));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
