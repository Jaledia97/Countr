import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
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

  VaultItem createCardWithRulings({
    required String id,
    required String name,
    required List<Map<String, dynamic>> rulings,
    bool useCachedRulingsKey = false,
    List<String>? keywords,
  }) {
    final Map<String, dynamic> dyn = {
      'set': 'tst',
      'set_code': 'tst',
      'set_name': 'Testing Set',
      'oracle_text': 'Card rules text here.',
    };

    if (keywords != null) {
      dyn['keywords'] = keywords;
    }

    if (useCachedRulingsKey) {
      dyn['cached_rulings'] = rulings;
    } else {
      dyn['rulings'] = rulings;
    }

    return VaultItem(
      id: id,
      collectionType: 'mtg',
      name: name,
      setOrSeries: 'Testing Set',
      imageUrl: 'https://cards.scryfall.io/test.jpg',
      acquiredPrice: 5.0,
      acquiredDate: DateTime(2023, 1, 1),
      quantity: 1,
      condition: 'NM',
      isGraded: false,
      isAltered: false,
      isMisprint: false,
      isSigned: false,
      isDeleted: false,
      currentMarketPrice: 10.0,
      lastPriceUpdate: DateTime(2023, 1, 1),
      dynamicData: jsonEncode(dyn),
    );
  }

  Widget createHarness(
    Widget child, {
    required WidgetTester tester,
    Size viewportSize = const Size(800, 2400),
  }) {
    tester.view.physicalSize = viewportSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        vaultDaoProvider.overrideWithValue(db.vaultDao),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: child,
        ),
      ),
    );
  }

  group('Empirical Challenge: Progressive Rulings Disclosure', () {
    testWidgets('Multi-ruling card (3 rulings): 1 visible initially, expands on See All tap, collapses on Hide tap', (tester) async {
      final card = createCardWithRulings(
        id: 'multi-3',
        name: 'The One Ring',
        keywords: ['Indestructible'],
        rulings: [
          {
            'oracle_id': 'ring-oracle',
            'published_at': '2023-06-23',
            'comment': 'Alpha Ruling: Protection from everything.',
          },
          {
            'oracle_id': 'ring-oracle',
            'published_at': '2023-06-24',
            'comment': 'Beta Ruling: Burden counters increase life loss.',
          },
          {
            'oracle_id': 'ring-oracle',
            'published_at': '2023-06-25',
            'comment': 'Gamma Ruling: Activated ability requires tapping {T}.',
          },
        ],
      );
      await db.into(db.vaultItems).insert(card);

      await tester.pumpWidget(createHarness(
        CardDetailSheet(item: card, fetchOnlinePrintings: false),
        tester: tester,
      ));
      await tester.pumpAndSettle();

      final ruling1Finder = find.textContaining('Alpha Ruling');
      final ruling2Finder = find.textContaining('Beta Ruling');
      final ruling3Finder = find.textContaining('Gamma Ruling');
      final seeAllButtonFinder = find.byKey(const Key('card_detail_rulings_see_all_button'));

      // 1. Initial State Check
      expect(ruling1Finder, findsOneWidget, reason: 'First ruling must be visible initially');
      expect(ruling2Finder, findsNothing, reason: 'Second ruling must NOT be visible initially');
      expect(ruling3Finder, findsNothing, reason: 'Third ruling must NOT be visible initially');
      expect(seeAllButtonFinder, findsOneWidget, reason: 'See All button must be present');
      expect(find.text('See All (3) Rulings'), findsOneWidget, reason: 'Initial button label must specify total rulings count');
      expect(find.byIcon(Icons.expand_more), findsWidgets);

      // 2. Expand: Tap "See All (3) Rulings"
      await tester.ensureVisible(seeAllButtonFinder);
      await tester.tap(seeAllButtonFinder);
      await tester.pumpAndSettle();

      // Verify all rulings are now visible
      expect(ruling1Finder, findsOneWidget, reason: 'First ruling remains visible after expansion');
      expect(ruling2Finder, findsOneWidget, reason: 'Second ruling must be visible after expansion');
      expect(ruling3Finder, findsOneWidget, reason: 'Third ruling must be visible after expansion');
      expect(find.text('Hide Additional Rulings'), findsOneWidget, reason: 'Button text must change to Hide Additional Rulings');
      expect(find.byIcon(Icons.expand_less), findsWidgets);

      // 3. Collapse: Tap "Hide Additional Rulings"
      await tester.tap(seeAllButtonFinder);
      await tester.pumpAndSettle();

      // Verify collapsed back to 1 ruling
      expect(ruling1Finder, findsOneWidget, reason: 'First ruling remains visible after collapse');
      expect(ruling2Finder, findsNothing, reason: 'Second ruling must be hidden again');
      expect(ruling3Finder, findsNothing, reason: 'Third ruling must be hidden again');
      expect(find.text('See All (3) Rulings'), findsOneWidget, reason: 'Button text must return to See All (3) Rulings');
    });

    testWidgets('Boundary case (2 rulings): 1 visible initially, toggles expand and collapse cleanly', (tester) async {
      final card = createCardWithRulings(
        id: 'multi-2',
        name: 'Urza, Lord High Artificer',
        rulings: [
          {
            'oracle_id': 'urza-oracle',
            'published_at': '2019-06-14',
            'comment': 'Ruling 1: Construct token power equals artifacts controlled.',
          },
          {
            'oracle_id': 'urza-oracle',
            'published_at': '2019-06-14',
            'comment': 'Ruling 2: You can tap untapped artifacts you control to add {U}.',
          },
        ],
      );
      await db.into(db.vaultItems).insert(card);

      await tester.pumpWidget(createHarness(
        CardDetailSheet(item: card, fetchOnlinePrintings: false),
        tester: tester,
      ));
      await tester.pumpAndSettle();

      final ruling1 = find.textContaining('Ruling 1:');
      final ruling2 = find.textContaining('Ruling 2:');
      final seeAllButton = find.byKey(const Key('card_detail_rulings_see_all_button'));

      expect(ruling1, findsOneWidget);
      expect(ruling2, findsNothing);
      expect(find.text('See All (2) Rulings'), findsOneWidget);

      await tester.ensureVisible(seeAllButton);
      await tester.tap(seeAllButton);
      await tester.pumpAndSettle();

      expect(ruling1, findsOneWidget);
      expect(ruling2, findsOneWidget);
      expect(find.text('Hide Additional Rulings'), findsOneWidget);

      await tester.tap(seeAllButton);
      await tester.pumpAndSettle();

      expect(ruling1, findsOneWidget);
      expect(ruling2, findsNothing);
      expect(find.text('See All (2) Rulings'), findsOneWidget);
    });

    testWidgets('Single ruling card (1 ruling): Displays ruling with NO See All or Hide button', (tester) async {
      final card = createCardWithRulings(
        id: 'single-ruling',
        name: 'Sol Ring',
        rulings: [
          {
            'oracle_id': 'sol-oracle',
            'published_at': '2008-10-01',
            'comment': 'Single Ruling: Sol Ring generates two colorless mana {C}{C}.',
          },
        ],
      );
      await db.into(db.vaultItems).insert(card);

      await tester.pumpWidget(createHarness(
        CardDetailSheet(item: card, fetchOnlinePrintings: false),
        tester: tester,
      ));
      await tester.pumpAndSettle();

      // Official Rulings accordion exists with (1)
      expect(find.text('Official Rulings (1)'), findsOneWidget);
      expect(find.textContaining('Single Ruling:'), findsOneWidget);

      // NO See All or Hide toggle button should exist because there are no additional rulings
      expect(find.byKey(const Key('card_detail_rulings_see_all_button')), findsNothing);
      expect(find.textContaining('See All'), findsNothing);
      expect(find.textContaining('Hide Additional Rulings'), findsNothing);
    });

    testWidgets('Zero rulings card (0 rulings): Does not display Official Rulings accordion', (tester) async {
      final card = createCardWithRulings(
        id: 'zero-rulings',
        name: 'Basic Forest',
        rulings: [],
      );
      await db.into(db.vaultItems).insert(card);

      await tester.pumpWidget(createHarness(
        CardDetailSheet(item: card, fetchOnlinePrintings: false),
        tester: tester,
      ));
      await tester.pumpAndSettle();

      // Official Rulings accordion should not render
      expect(find.byKey(const Key('card_detail_rulings_accordion')), findsNothing);
      expect(find.textContaining('Official Rulings'), findsNothing);
      expect(find.byKey(const Key('card_detail_rulings_see_all_button')), findsNothing);
    });

    testWidgets('Cached rulings key fallback: parsed correctly when key is cached_rulings', (tester) async {
      final card = createCardWithRulings(
        id: 'cached-rulings-card',
        name: 'Atraxa, Praetors Voice',
        useCachedRulingsKey: true,
        rulings: [
          {
            'oracle_id': 'atraxa-oracle',
            'published_at': '2016-11-11',
            'comment': 'Atraxa Ruling 1: Proliferate affects counters on players and permanents.',
          },
          {
            'oracle_id': 'atraxa-oracle',
            'published_at': '2016-11-11',
            'comment': 'Atraxa Ruling 2: You choose which counters to add.',
          },
        ],
      );
      await db.into(db.vaultItems).insert(card);

      await tester.pumpWidget(createHarness(
        CardDetailSheet(item: card, fetchOnlinePrintings: false),
        tester: tester,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Official Rulings (2)'), findsOneWidget);
      expect(find.textContaining('Atraxa Ruling 1'), findsOneWidget);
      expect(find.textContaining('Atraxa Ruling 2'), findsNothing);
      expect(find.text('See All (2) Rulings'), findsOneWidget);

      final seeAllButton = find.byKey(const Key('card_detail_rulings_see_all_button'));
      await tester.ensureVisible(seeAllButton);
      await tester.tap(seeAllButton);
      await tester.pumpAndSettle();

      expect(find.textContaining('Atraxa Ruling 2'), findsOneWidget);
      expect(find.text('Hide Additional Rulings'), findsOneWidget);
    });

    testWidgets('Page change / item sync resets _isRulingsExpanded back to collapsed', (tester) async {
      final cardA = createCardWithRulings(
        id: 'card-a',
        name: 'Card A',
        rulings: [
          {'oracle_id': 'a1', 'published_at': '2023-01-01', 'comment': 'Card A Ruling 1'},
          {'oracle_id': 'a2', 'published_at': '2023-01-02', 'comment': 'Card A Ruling 2'},
        ],
      );
      final cardB = createCardWithRulings(
        id: 'card-b',
        name: 'Card B',
        rulings: [
          {'oracle_id': 'b1', 'published_at': '2023-02-01', 'comment': 'Card B Ruling 1'},
          {'oracle_id': 'b2', 'published_at': '2023-02-02', 'comment': 'Card B Ruling 2'},
        ],
      );
      await db.into(db.vaultItems).insert(cardA);
      await db.into(db.vaultItems).insert(cardB);

      await tester.pumpWidget(createHarness(
        CardDetailSheet(
          item: cardA,
          items: [cardA, cardB],
          initialIndex: 0,
          fetchOnlinePrintings: false,
        ),
        tester: tester,
      ));
      await tester.pumpAndSettle();

      // Expand Card A
      final seeAllA = find.byKey(const Key('card_detail_rulings_see_all_button'));
      await tester.ensureVisible(seeAllA);
      await tester.tap(seeAllA);
      await tester.pumpAndSettle();

      expect(find.text('Hide Additional Rulings'), findsOneWidget);
      expect(find.textContaining('Card A Ruling 2'), findsOneWidget);

      // Swipe / Drag to Card B
      await tester.drag(find.byType(PageView).first, const Offset(-600, 0));
      await tester.pumpAndSettle();

      // Card B should be active now
      expect(find.text('Card B'), findsWidgets);
      // Card B should have rulings collapsed initially!
      expect(find.textContaining('Card B Ruling 1'), findsOneWidget);
      expect(find.textContaining('Card B Ruling 2'), findsNothing);
      expect(find.text('See All (2) Rulings'), findsOneWidget);
      expect(find.text('Hide Additional Rulings'), findsNothing);
    });
  });
}
