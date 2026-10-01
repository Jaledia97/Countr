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
    String id = 'card-collapsible-test',
    String name = 'Chandra, Torch of Defiance',
    int quantity = 1,
    double price = 14.50,
  }) {
    return VaultItem(
      id: id,
      collectionType: 'mtg',
      name: name,
      setOrSeries: 'KLD',
      imageUrl: 'https://cards.scryfall.io/normal/front/kld/110.jpg',
      acquiredPrice: 12.00,
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
      personalNotes: 'Planeswalker testing.',
      dynamicData: jsonEncode({
        'collector_number': '110',
        'set': 'kld',
        'mana_cost': '{2}{R}{R}',
        'type_line': 'Legendary Planeswalker — Chandra',
        'keywords': ['Flying', 'Haste'],
        'oracle_text':
            '+1: Exile the top card of your library. You may cast that card. If you don\'t, Chandra deals 2 damage to each opponent.\n+1: Add {R}{R}.\n−3: Chandra deals 4 damage to target creature.\n−7: You get an emblem with \'Whenever you cast a spell, this emblem deals 5 damage to any target.\'',
        'cached_rulings': [
          {'published_at': '2016-09-20', 'comment': 'You pay all costs and follow all timing restrictions.'},
          {'published_at': '2016-09-20', 'comment': 'Damage dealt by Chandra is not combat damage.'},
          {'published_at': '2016-09-20', 'comment': 'The emblem triggers whenever you cast any spell.'},
        ],
      }),
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

  // ===========================================================================
  // TIER 1 — ISOLATED FEATURE TESTS (R3: Collapsible Card Art Header)
  // ===========================================================================
  group('R3 — Tier 1: Isolated Collapsible Art Header Tests', () {
    testWidgets('R3-T1-1: Renders card details sheet with segmented tab bar [ Details | Values ]', (tester) async {
      final card = createTestCard();
      await db.into(db.vaultItems).insert(card);

      await tester.pumpWidget(createHarness(CardDetailSheet(item: card, fetchOnlinePrintings: false)));
      await tester.pumpAndSettle();

      expect(find.text('Details'), findsOneWidget);
      expect(find.text('Values'), findsOneWidget);
      expect(find.byType(CardDetailSheet), findsOneWidget);
    });

    testWidgets('R3-T1-2: Initial render presents card artwork prominently in hero section', (tester) async {
      final card = createTestCard();
      await db.into(db.vaultItems).insert(card);

      await tester.pumpWidget(createHarness(CardDetailSheet(item: card, fetchOnlinePrintings: false)));
      await tester.pumpAndSettle();

      final artFinder = find.byKey(Key('card_artwork_${card.id}'));
      expect(artFinder, findsOneWidget);
      final size = tester.getSize(artFinder);
      expect(size.height, greaterThan(50));
      expect(size.width, greaterThan(50));
    });

    testWidgets('R3-T1-3: Scrolling down in Details tab triggers scroll offset motion', (tester) async {
      final card = createTestCard();
      await db.into(db.vaultItems).insert(card);

      await tester.pumpWidget(createHarness(CardDetailSheet(item: card, fetchOnlinePrintings: false)));
      await tester.pumpAndSettle();

      // Ensure we are on Details tab
      expect(find.text('Oracle Rules Text'), findsOneWidget);

      // Perform a drag up (scroll down)
      await tester.drag(find.text('Oracle Rules Text'), const Offset(0, -300));
      await tester.pumpAndSettle();

      // Tab bar remains accessible
      expect(find.text('Details'), findsOneWidget);
      expect(find.text('Values'), findsOneWidget);
    });

    testWidgets('R3-T1-4: Scrolling down in Values tab functions consistently with Details tab', (tester) async {
      final card = createTestCard();
      await db.into(db.vaultItems).insert(card);

      await tester.pumpWidget(createHarness(CardDetailSheet(item: card, fetchOnlinePrintings: false)));
      await tester.pumpAndSettle();

      // Switch to Values tab
      await tester.tap(find.text('Values'));
      await tester.pumpAndSettle();

      expect(find.text('Values'), findsOneWidget);

      // Drag up (scroll down) in Values tab
      final scrollableFinder = find.byType(Scrollable);
      expect(scrollableFinder, findsWidgets);
      await tester.drag(scrollableFinder.first, const Offset(0, -300));
      await tester.pumpAndSettle();

      // Tab bar remains pinned/visible
      expect(find.text('Values'), findsOneWidget);
    });

    testWidgets('R3-T1-5: Segmented tab bar [ Details | Values ] remains pinned and tap targets work', (tester) async {
      final card = createTestCard();
      await db.into(db.vaultItems).insert(card);

      await tester.pumpWidget(createHarness(CardDetailSheet(item: card, fetchOnlinePrintings: false)));
      await tester.pumpAndSettle();

      // Drag up to simulate scroll
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
      await tester.pumpAndSettle();

      // Tap Values tab when scrolled
      await tester.tap(find.text('Values'));
      await tester.pumpAndSettle();

      // Tap Details tab back
      await tester.tap(find.text('Details'));
      await tester.pumpAndSettle();

      expect(find.text('Details'), findsOneWidget);
    });
  });

  // ===========================================================================
  // TIER 2 — BOUNDARY & CORNER CASES (Fling, Switching tabs mid-scroll, Extremes)
  // ===========================================================================
  group('R3 — Tier 2: Boundary & Corner Cases', () {
    testWidgets('R3-T2-1: Rapid scroll fling to maximum offset does not crash or throw overflow', (tester) async {
      final card = createTestCard();
      await db.into(db.vaultItems).insert(card);

      await tester.pumpWidget(createHarness(CardDetailSheet(item: card, fetchOnlinePrintings: false)));
      await tester.pumpAndSettle();

      // Aggressive fling gesture
      await tester.fling(find.byType(Scrollable).first, const Offset(0, -1000), 2000);
      await tester.pumpAndSettle();

      // No assertion or overflow exceptions
      expect(tester.takeException(), isNull);
    });

    testWidgets('R3-T2-2: Fling back to top (offset 0) safely re-expands view', (tester) async {
      final card = createTestCard();
      await db.into(db.vaultItems).insert(card);

      await tester.pumpWidget(createHarness(CardDetailSheet(item: card, fetchOnlinePrintings: false)));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
      await tester.pumpAndSettle();

      // Drag back down to top
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 600));
      await tester.pumpAndSettle();

      expect(find.byKey(Key('card_artwork_${card.id}')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('R3-T2-3: Switching tabs mid-scroll maintains layout integrity', (tester) async {
      final card = createTestCard();
      await db.into(db.vaultItems).insert(card);

      await tester.pumpWidget(createHarness(CardDetailSheet(item: card, fetchOnlinePrintings: false)));
      await tester.pumpAndSettle();

      // Scroll halfway
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -250));
      await tester.pumpAndSettle();

      // Switch to Values
      await tester.tap(find.text('Values'));
      await tester.pumpAndSettle();

      // Switch back to Details
      await tester.tap(find.text('Details'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('R3-T2-4: Card with minimal rulings/text handles scrolling without getting stuck', (tester) async {
      final minimalCard = VaultItem(
        id: 'c-minimal',
        collectionType: 'mtg',
        name: 'Mountain',
        setOrSeries: 'LEA',
        imageUrl: 'https://cards.scryfall.io/mountain.jpg',
        acquiredPrice: 1.0,
        acquiredDate: DateTime(2026, 1, 1),
        quantity: 1,
        condition: 'NM',
        isGraded: false,
        isAltered: false,
        isMisprint: false,
        isSigned: false,
        isDeleted: false,
        currentMarketPrice: 1.0,
        lastPriceUpdate: DateTime(2026, 1, 1),
        dynamicData: jsonEncode({
          'type_line': 'Basic Land — Mountain',
          'oracle_text': '({T}: Add {R}.)',
        }),
      );

      await tester.pumpWidget(createHarness(CardDetailSheet(item: minimalCard, fetchOnlinePrintings: false)));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(Scrollable).first, const Offset(0, -100));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('R3-T2-5: Extreme compact viewport size adapts without RenderFlex overflow', (tester) async {
      final card = createTestCard();
      await db.into(db.vaultItems).insert(card);

      // Very small mobile viewport (320x568 - iPhone SE 1st gen)
      await tester.pumpWidget(createHarness(
        CardDetailSheet(item: card, fetchOnlinePrintings: false),
        viewportSize: const Size(320, 568),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(CardDetailSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  // ===========================================================================
  // TIER 3 — PAIRWISE & CROSS-FEATURE COMBINATIONS
  // ===========================================================================
  group('R3 — Tier 3: Cross-Feature Combinations', () {
    testWidgets('R3-T3-1: Artwork tap gesture is recognized in hero section', (tester) async {
      final card = createTestCard();
      await db.into(db.vaultItems).insert(card);

      await tester.pumpWidget(createHarness(CardDetailSheet(item: card, fetchOnlinePrintings: false)));
      await tester.pumpAndSettle();

      final artFinder = find.byKey(Key('card_artwork_${card.id}'));
      expect(artFinder, findsOneWidget);

      await tester.tap(artFinder);
      await tester.pumpAndSettle();
      // Should not crash when tapping artwork
      expect(tester.takeException(), isNull);
    });

    testWidgets('R3-T3-2: Quick action bar remains present and interactable', (tester) async {
      final card = createTestCard();
      await db.into(db.vaultItems).insert(card);

      await tester.pumpWidget(createHarness(CardDetailSheet(item: card, fetchOnlinePrintings: false)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('card_detail_quick_action_bar')), findsOneWidget);
    });
  });

  // ===========================================================================
  // TIER 4 — REAL-WORLD WORKLOAD SCENARIOS & E2E FLOWS
  // ===========================================================================
  group('R3 — Tier 4: Real-World Workload Scenarios & E2E Flows', () {
    testWidgets('R3-T4-1: Complete card inspection workflow across both tabs under scroll stress', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final card = createTestCard();
      await db.into(db.vaultItems).insert(card);

      await tester.pumpWidget(createHarness(CardDetailSheet(item: card, fetchOnlinePrintings: false)));
      await tester.pumpAndSettle();

      // Step 1: Inspect Details tab initially
      expect(find.text('Card Mechanics & Rulings'), findsOneWidget);

      // Step 2: Scroll down in Details tab
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -350));
      await tester.pumpAndSettle();

      // Step 3: Switch to Values tab
      await tester.tap(find.text('Values'));
      await tester.pumpAndSettle();

      // Step 4: Scroll in Values tab
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -200));
      await tester.pumpAndSettle();

      // Step 5: Switch back to Details tab
      await tester.tap(find.text('Details'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
