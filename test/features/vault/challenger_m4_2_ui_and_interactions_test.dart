import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/screens/vault_screen.dart';
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

  /// Bounded frame pumping helper strictly avoiding unbounded pumpAndSettle().
  Future<void> pumpBounded(
    WidgetTester tester, {
    int steps = 5,
    Duration stepDuration = const Duration(milliseconds: 50),
  }) async {
    for (int i = 0; i < steps; i++) {
      await tester.pump(stepDuration);
    }
  }

  /// Locates the widget matching [baseFinder] that is currently visible in the active viewport (0 <= dx < screenWidth).
  Finder findVisibleOnScreen(WidgetTester tester, Finder baseFinder) {
    final screenWidth = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    final List<Element> matchingElements = [];
    for (final element in baseFinder.evaluate()) {
      final renderBox = element.renderObject as RenderBox?;
      if (renderBox != null && renderBox.hasSize) {
        final pos = renderBox.localToGlobal(Offset.zero);
        if (pos.dx >= 0.0 && pos.dx < screenWidth) {
          matchingElements.add(element);
        }
      }
    }
    return find.byElementPredicate((element) => matchingElements.contains(element));
  }

  VaultItem createTestCard({
    required String id,
    String name = 'Rhystic Study',
    String? flavorName,
    int reputationScore = 0,
    int upvotes = 0,
    int downvotes = 0,
    int? userVote,
    List<Map<String, dynamic>>? cardFaces,
  }) {
    final Map<String, dynamic> dyn = {
      'collector_number': '25',
      'set': 'wot',
      'cmc': 3.0,
      'reputation_score': reputationScore,
      'score': reputationScore,
      'upvotes': upvotes,
      'downvotes': downvotes,
      'user_vote': userVote ?? 0,
      'oracle_text': 'Whenever an opponent casts a spell, you may draw a card unless that player pays {1}.',
    };
    if (cardFaces != null) {
      dyn['card_faces'] = cardFaces;
    }
    return VaultItem(
      id: id,
      collectionType: 'mtg',
      name: name,
      flavorName: flavorName,
      setOrSeries: 'WOT',
      imageUrl: 'https://cards.scryfall.io/normal/front/card.jpg',
      acquiredPrice: 30.0,
      acquiredDate: DateTime(2023, 1, 1),
      quantity: 1,
      condition: 'NM',
      isGraded: false,
      isAltered: false,
      isMisprint: false,
      isSigned: false,
      isDeleted: false,
      currentMarketPrice: 35.0,
      lastPriceUpdate: DateTime(2023, 1, 1),
      reputationScore: reputationScore,
      upvotes: upvotes,
      downvotes: downvotes,
      dynamicData: jsonEncode(dyn),
    );
  }

  Widget wrapSheetWithHarness({
    required Widget child,
    ProviderContainer? container,
    Size viewportSize = const Size(390, 844),
    double textScale = 1.0,
  }) {
    final providerChild = container != null
        ? UncontrolledProviderScope(container: container, child: child)
        : ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(db),
              vaultDaoProvider.overrideWithValue(db.vaultDao),
              cardReputationDaoProvider.overrideWithValue(db.cardReputationDao),
            ],
            child: child,
          );

    return MaterialApp(
      builder: (context, c) => MediaQuery(
        data: MediaQueryData(
          size: viewportSize,
          textScaler: TextScaler.linear(textScale),
        ),
        child: c!,
      ),
      home: Scaffold(body: providerChild),
    );
  }

  Widget buildVaultHarness({
    required ProviderContainer container,
    Size viewportSize = const Size(390, 844),
  }) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(size: viewportSize),
          child: child!,
        ),
        home: const VaultScreen(),
      ),
    );
  }

  group('Adversarial Dimension 1: CardDetailSheet voting cluster under extreme conditions', () {
    testWidgets('1.1: 320px viewport with 2.0x font scaling renders cluster with zero RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(320 * 2.0, 640 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final card = createTestCard(id: 'stress-card-1', name: 'Lightning Bolt');
      await db.into(db.vaultItems).insert(card);

      await tester.pumpWidget(
        wrapSheetWithHarness(
          child: CardDetailSheet(item: card, fetchOnlinePrintings: false),
          viewportSize: const Size(320, 640),
          textScale: 2.0,
        ),
      );
      await pumpBounded(tester, steps: 6);

      expect(tester.takeException(), isNull, reason: 'Must render with 0 RenderFlex overflow');

      final upvoteFinder = find.byKey(const Key('card_detail_upvote_button'));
      final scoreFinder = find.byKey(const Key('card_detail_reputation_score'));
      final downvoteFinder = find.byKey(const Key('card_detail_downvote_button'));
      final closeFinder = find.byKey(const Key('card_detail_close_button'));

      expect(upvoteFinder, findsOneWidget);
      expect(scoreFinder, findsOneWidget);
      expect(downvoteFinder, findsOneWidget);
      expect(closeFinder, findsOneWidget);

      // Verify buttons are hittable and interactive at 320px 2.0x
      await tester.tap(upvoteFinder);
      await tester.pump();
      await pumpBounded(tester, steps: 4);

      expect(tester.widget<Text>(scoreFinder).data, equals('1'));
      expect(tester.widget<Text>(scoreFinder).style?.color, equals(AppColors.accentEmerald));
      expect(tester.takeException(), isNull, reason: 'Zero overflow after upvote interaction');
    });

    testWidgets('1.2: 320px viewport with 2.0x font scaling on multi-face card with huge score (+99999)', (tester) async {
      tester.view.physicalSize = const Size(320 * 2.0, 640 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final multiFaceCard = createTestCard(
        id: 'dfc-stress-card-2',
        name: 'Delver of Secrets // Insectile Aberration',
        flavorName: 'Delver of Secrets',
        reputationScore: 99999,
        cardFaces: [
          {
            'name': 'Delver of Secrets Front Face Long Title',
            'mana_cost': '{U}',
            'type_line': 'Creature — Human Wizard',
            'oracle_text': 'At the beginning of your upkeep, look at the top card of your library.',
          },
          {
            'name': 'Insectile Aberration Back Face Long Title',
            'mana_cost': '',
            'type_line': 'Creature — Human Insect',
            'oracle_text': 'Flying',
          },
        ],
      );
      await db.into(db.vaultItems).insert(multiFaceCard);

      await tester.pumpWidget(
        wrapSheetWithHarness(
          child: CardDetailSheet(item: multiFaceCard, fetchOnlinePrintings: false),
          viewportSize: const Size(320, 640),
          textScale: 2.0,
        ),
      );
      await pumpBounded(tester, steps: 6);

      expect(tester.takeException(), isNull, reason: 'Must not overflow with DFC and 5-digit score at 320px 2.0x');

      final scoreFinder = find.byKey(const Key('card_detail_reputation_score'));
      expect(tester.widget<Text>(scoreFinder).data, equals('99999'));

      // Downvote huge score
      await tester.tap(find.byKey(const Key('card_detail_downvote_button')));
      await tester.pump();
      await pumpBounded(tester, steps: 4);

      expect(tester.widget<Text>(scoreFinder).data, equals('99998'));
      expect(tester.widget<Text>(scoreFinder).style?.color, equals(AppColors.accentAmber));
      expect(tester.takeException(), isNull);
    });

    testWidgets('1.3: Compact (320x380) and Ultra-Compact (320x220) viewports with 2.0x font scaling', (tester) async {
      final card = createTestCard(id: 'compact-stress-card-3', reputationScore: -999);
      await db.into(db.vaultItems).insert(card);

      // Compact height
      tester.view.physicalSize = const Size(320 * 2.0, 380 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      await tester.pumpWidget(
        wrapSheetWithHarness(
          child: CardDetailSheet(item: card, fetchOnlinePrintings: false),
          viewportSize: const Size(320, 380),
          textScale: 2.0,
        ),
      );
      await pumpBounded(tester, steps: 4);
      expect(tester.takeException(), isNull, reason: 'Zero overflow on compact height');
      expect(find.byKey(const Key('card_detail_reputation_score')), findsOneWidget);

      // Ultra-compact height
      tester.view.physicalSize = const Size(320 * 2.0, 220 * 2.0);
      await tester.pumpWidget(
        wrapSheetWithHarness(
          child: CardDetailSheet(item: card, fetchOnlinePrintings: false),
          viewportSize: const Size(320, 220),
          textScale: 2.0,
        ),
      );
      await pumpBounded(tester, steps: 4);
      expect(tester.takeException(), isNull, reason: 'Zero overflow on ultra-compact height');
      expect(find.byKey(const Key('card_detail_reputation_score')), findsOneWidget);

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });

  group('Adversarial Dimension 2: Rapid multi-tap gestures on upvote and downvote (Optimistic State Stress)', () {
    testWidgets('2.1: 12 rapid successive taps on upvote cleanly toggle between 1 and 0 without jitter or desync', (tester) async {
      final card = createTestCard(id: 'rapid-upvote-card', reputationScore: 0);
      await db.into(db.vaultItems).insert(card);

      await tester.pumpWidget(
        wrapSheetWithHarness(
          child: CardDetailSheet(item: card, fetchOnlinePrintings: false),
        ),
      );
      await pumpBounded(tester, steps: 5);

      final upvoteFinder = find.byKey(const Key('card_detail_upvote_button'));
      final scoreFinder = find.byKey(const Key('card_detail_reputation_score'));

      for (int i = 1; i <= 12; i++) {
        await tester.tap(upvoteFinder);
        await tester.pump(); // immediate 0ms frame

        final isToggledOn = (i % 2 == 1);
        final expectedScore = isToggledOn ? '1' : '0';
        final expectedColor = isToggledOn ? AppColors.accentEmerald : AppColors.textPrimary;

        final textWidget = tester.widget<Text>(scoreFinder);
        expect(
          textWidget.data,
          equals(expectedScore),
          reason: 'Tap $i must immediately yield score $expectedScore',
        );
        expect(
          textWidget.style?.color,
          equals(expectedColor),
          reason: 'Tap $i must immediately yield color $expectedColor',
        );
      }

      // Flush async DB calls with bounded pumping
      await pumpBounded(tester, steps: 10, stepDuration: const Duration(milliseconds: 50));

      // Verify SQLite row consistency
      final itemInDb = await (db.select(db.vaultItems)..where((t) => t.id.equals('rapid-upvote-card'))).getSingle();
      expect(itemInDb.reputationScore, equals(0), reason: 'Even number of taps toggles to 0 in database');
    });

    testWidgets('2.2: Rapid alternating sequence between upvote and downvote produces strictly valid states', (tester) async {
      final card = createTestCard(id: 'rapid-alternating-card', reputationScore: 10);
      await db.into(db.vaultItems).insert(card);

      await tester.pumpWidget(
        wrapSheetWithHarness(
          child: CardDetailSheet(item: card, fetchOnlinePrintings: false),
        ),
      );
      await pumpBounded(tester, steps: 5);

      final upvoteFinder = find.byKey(const Key('card_detail_upvote_button'));
      final downvoteFinder = find.byKey(const Key('card_detail_downvote_button'));
      final scoreFinder = find.byKey(const Key('card_detail_reputation_score'));

      // Sequence of rapid taps:
      // Initial: score 10, vote 0
      // 1. Upvote -> vote 1, score 11 (emerald)
      await tester.tap(upvoteFinder);
      await tester.pump();
      expect(tester.widget<Text>(scoreFinder).data, equals('11'));
      expect(tester.widget<Text>(scoreFinder).style?.color, equals(AppColors.accentEmerald));

      // 2. Downvote -> vote -1, score 9 (amber, delta -2)
      await tester.tap(downvoteFinder);
      await tester.pump();
      expect(tester.widget<Text>(scoreFinder).data, equals('9'));
      expect(tester.widget<Text>(scoreFinder).style?.color, equals(AppColors.accentAmber));

      // 3. Upvote -> vote 1, score 11 (emerald, delta +2)
      await tester.tap(upvoteFinder);
      await tester.pump();
      expect(tester.widget<Text>(scoreFinder).data, equals('11'));
      expect(tester.widget<Text>(scoreFinder).style?.color, equals(AppColors.accentEmerald));

      // 4. Upvote again -> vote 0, score 10 (neutral, toggle off)
      await tester.tap(upvoteFinder);
      await tester.pump();
      expect(tester.widget<Text>(scoreFinder).data, equals('10'));
      expect(tester.widget<Text>(scoreFinder).style?.color, equals(AppColors.textPrimary));

      // 5. Downvote -> vote -1, score 9 (amber)
      await tester.tap(downvoteFinder);
      await tester.pump();
      expect(tester.widget<Text>(scoreFinder).data, equals('9'));
      expect(tester.widget<Text>(scoreFinder).style?.color, equals(AppColors.accentAmber));

      // 6. Downvote again -> vote 0, score 10 (neutral, toggle off)
      await tester.tap(downvoteFinder);
      await tester.pump();
      expect(tester.widget<Text>(scoreFinder).data, equals('10'));
      expect(tester.widget<Text>(scoreFinder).style?.color, equals(AppColors.textPrimary));

      // Flush async DB calls with bounded pumping
      await pumpBounded(tester, steps: 10, stepDuration: const Duration(milliseconds: 50));

      final finalItem = await (db.select(db.vaultItems)..where((t) => t.id.equals('rapid-alternating-card'))).getSingle();
      expect(finalItem.reputationScore, equals(10), reason: 'Final toggled-off vote returns score to baseline 10');
    });
  });

  group('Adversarial Dimension 3: PageView swiping between multiple cards (Vote Isolation Stress)', () {
    testWidgets('3.1: Optimistic votes for Card A do not bleed into Card B or Card C during horizontal swiping', (tester) async {
      tester.view.physicalSize = const Size(390 * 2.0, 844 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final cardA = createTestCard(id: 'swipe-card-a', name: 'Card Alpha', reputationScore: 5);
      final cardB = createTestCard(id: 'swipe-card-b', name: 'Card Beta', reputationScore: 20);
      final cardC = createTestCard(id: 'swipe-card-c', name: 'Card Gamma', reputationScore: -2);

      await db.into(db.vaultItems).insert(cardA);
      await db.into(db.vaultItems).insert(cardB);
      await db.into(db.vaultItems).insert(cardC);

      await tester.pumpWidget(
        wrapSheetWithHarness(
          child: CardDetailSheet(
            items: [cardA, cardB, cardC],
            initialIndex: 0,
            fetchOnlinePrintings: false,
          ),
          viewportSize: const Size(390, 844),
        ),
      );
      await pumpBounded(tester, steps: 6);

      // Verify initially on Card Alpha
      expect(find.text('Card Alpha'), findsWidgets);
      final initialScoreFinder = findVisibleOnScreen(tester, find.byKey(const Key('card_detail_reputation_score')));
      expect(tester.widget<Text>(initialScoreFinder).data, equals('5'));

      // 1. Upvote Card Alpha -> score becomes 6
      await tester.tap(findVisibleOnScreen(tester, find.byKey(const Key('card_detail_upvote_button'))));
      await tester.pump();
      expect(tester.widget<Text>(findVisibleOnScreen(tester, find.byKey(const Key('card_detail_reputation_score')))).data, equals('6'));
      expect(
        tester.widget<Text>(findVisibleOnScreen(tester, find.byKey(const Key('card_detail_reputation_score')))).style?.color,
        equals(AppColors.accentEmerald),
      );

      // 2. Fling swipe horizontally to Card Beta
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await pumpBounded(tester, steps: 15, stepDuration: const Duration(milliseconds: 50));

      expect(find.text('Card Beta'), findsWidgets);
      // Card Beta MUST have its own score 20, NOT 6!
      final cardBScoreFinder = findVisibleOnScreen(tester, find.byKey(const Key('card_detail_reputation_score')));
      expect(
        tester.widget<Text>(cardBScoreFinder).data,
        equals('20'),
        reason: 'Card Beta must retain its own baseline reputation score of 20 without bleeding Card Alpha',
      );
      expect(
        tester.widget<Text>(cardBScoreFinder).style?.color,
        equals(AppColors.textPrimary),
      );

      // 3. Downvote Card Beta -> score becomes 19
      await tester.tap(findVisibleOnScreen(tester, find.byKey(const Key('card_detail_downvote_button'))));
      await tester.pump();
      expect(tester.widget<Text>(findVisibleOnScreen(tester, find.byKey(const Key('card_detail_reputation_score')))).data, equals('19'));
      expect(
        tester.widget<Text>(findVisibleOnScreen(tester, find.byKey(const Key('card_detail_reputation_score')))).style?.color,
        equals(AppColors.accentAmber),
      );

      // 4. Fling swipe horizontally to Card Gamma
      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await pumpBounded(tester, steps: 15, stepDuration: const Duration(milliseconds: 50));

      expect(find.text('Card Gamma'), findsWidgets);
      expect(
        tester.widget<Text>(findVisibleOnScreen(tester, find.byKey(const Key('card_detail_reputation_score')))).data,
        equals('-2'),
        reason: 'Card Gamma must display its own score of -2',
      );

      // 5. Swipe back to Card Beta
      await tester.fling(find.byType(PageView), const Offset(400, 0), 1000);
      await pumpBounded(tester, steps: 15, stepDuration: const Duration(milliseconds: 50));

      expect(find.text('Card Beta'), findsWidgets);
      expect(
        tester.widget<Text>(findVisibleOnScreen(tester, find.byKey(const Key('card_detail_reputation_score')))).data,
        equals('19'),
        reason: 'Card Beta must retain optimistic downvote score 19 when swiped back',
      );
      expect(
        tester.widget<Text>(findVisibleOnScreen(tester, find.byKey(const Key('card_detail_reputation_score')))).style?.color,
        equals(AppColors.accentAmber),
      );

      // 6. Swipe back to Card Alpha
      await tester.fling(find.byType(PageView), const Offset(400, 0), 1000);
      await pumpBounded(tester, steps: 15, stepDuration: const Duration(milliseconds: 50));

      expect(find.text('Card Alpha'), findsWidgets);
      expect(
        tester.widget<Text>(findVisibleOnScreen(tester, find.byKey(const Key('card_detail_reputation_score')))).data,
        equals('6'),
        reason: 'Card Alpha must retain optimistic upvote score 6 when swiped back',
      );
      expect(
        tester.widget<Text>(findVisibleOnScreen(tester, find.byKey(const Key('card_detail_reputation_score')))).style?.color,
        equals(AppColors.accentEmerald),
      );
    });
  });

  group('Adversarial Dimension 4: Vault AppBar relocation & unique instance count', () {
    testWidgets('4.1: In "All Cards" mode, exactly 1 instance of search and filter exists, both in AppBar', (tester) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
          vaultShowCatalogProvider.overrideWith((ref) => true), // All Cards mode
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(buildVaultHarness(container: container));
      await pumpBounded(tester, steps: 5);

      final searchFinder = find.byKey(const Key('vault_search_expand_button'));
      final filterFinder = find.byKey(const Key('vault_mtg_filter_button'));
      final importFinder = find.byKey(const Key('vault_import_button'));
      final appBarFinder = find.byType(AppBar);

      // Invariant: Exactly 1 instance in tree
      expect(searchFinder, findsOneWidget, reason: 'Exactly 1 search button instance must exist in tree');
      expect(filterFinder, findsOneWidget, reason: 'Exactly 1 filter button instance must exist in tree');
      expect(importFinder, findsOneWidget);

      // Invariant: Both must be direct descendants of AppBar
      expect(find.descendant(of: appBarFinder, matching: searchFinder), findsOneWidget);
      expect(find.descendant(of: appBarFinder, matching: filterFinder), findsOneWidget);
      expect(find.descendant(of: appBarFinder, matching: importFinder), findsOneWidget);

      // Horizontal ordering: search < filter < import
      final searchX = tester.getTopLeft(searchFinder).dx;
      final filterX = tester.getTopLeft(filterFinder).dx;
      final importX = tester.getTopLeft(importFinder).dx;
      expect(searchX < filterX, isTrue, reason: 'Search must be left of filter');
      expect(filterX < importX, isTrue, reason: 'Filter must be left of import');
    });

    testWidgets('4.2: Toggling repeatedly between "All Cards" and "Owned" maintains exactly 1 instance at all times', (tester) async {
      final showCatalogState = StateProvider<bool>((ref) => true);
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
          vaultShowCatalogProvider.overrideWith((ref) => ref.watch(showCatalogState)),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(buildVaultHarness(container: container));
      await pumpBounded(tester, steps: 5);

      final searchFinder = find.byKey(const Key('vault_search_expand_button'));
      final filterFinder = find.byKey(const Key('vault_mtg_filter_button'));
      final appBarFinder = find.byType(AppBar);

      for (int cycle = 0; cycle < 6; cycle++) {
        final isCatalog = (cycle % 2 == 0);
        container.read(showCatalogState.notifier).state = isCatalog;
        await tester.pump();
        await pumpBounded(tester, steps: 4);

        expect(searchFinder, findsOneWidget, reason: 'Cycle $cycle ($isCatalog): exactly 1 search button');
        expect(filterFinder, findsOneWidget, reason: 'Cycle $cycle ($isCatalog): exactly 1 filter button');

        if (isCatalog) {
          expect(find.descendant(of: appBarFinder, matching: searchFinder), findsOneWidget);
          expect(find.descendant(of: appBarFinder, matching: filterFinder), findsOneWidget);
        } else {
          expect(find.descendant(of: appBarFinder, matching: searchFinder), findsNothing);
          expect(find.descendant(of: appBarFinder, matching: filterFinder), findsNothing);
        }
      }
    });
  });

  group('Adversarial Dimension 5: Vault Sort button & modal exhaustive selection', () {
    testWidgets('5.1: Sort button renders on pill bar with swap icon and ↑↓ text', (tester) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(buildVaultHarness(container: container));
      await pumpBounded(tester, steps: 5);

      final sortButtonFinder = find.byKey(const Key('vault_sort_button'));
      expect(sortButtonFinder, findsOneWidget);
      expect(find.descendant(of: sortButtonFinder, matching: find.text('↑↓')), findsOneWidget);
      expect(find.descendant(of: sortButtonFinder, matching: find.byIcon(Icons.swap_vert_rounded)), findsOneWidget);
    });

    testWidgets('5.2: Tapping vault_sort_button opens modal, and selecting EACH sort option updates provider & closes cleanly', (tester) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(buildVaultHarness(container: container));
      await pumpBounded(tester, steps: 5);

      final sortOptionsToTest = [
        (option: VaultSortOption.reputationHighest, key: const Key('vault_sort_reputation_highest')),
        (option: VaultSortOption.reputationLowest, key: const Key('vault_sort_reputation_lowest')),
        (option: VaultSortOption.priceHighToLow, key: const Key('vault_sort_price_high_low')),
        (option: VaultSortOption.priceLowToHigh, key: const Key('vault_sort_price_low_high')),
        (option: VaultSortOption.nameAZ, key: const Key('vault_sort_name_a_z')),
        (option: VaultSortOption.manaValueCmc, key: const Key('vault_sort_mana_value_cmc')),
        (option: VaultSortOption.releaseDate, key: const Key('vault_sort_release_date')),
      ];

      for (final target in sortOptionsToTest) {
        // 1. Tap sort button
        await tester.tap(find.byKey(const Key('vault_sort_button')));
        await tester.pump();
        await pumpBounded(tester, steps: 6, stepDuration: const Duration(milliseconds: 50));

        // 2. Verify modal opened and option key is in tree
        expect(find.byKey(target.key), findsOneWidget, reason: 'Modal must display ${target.key}');

        // Ensure visible in SingleChildScrollView before tapping
        await tester.ensureVisible(find.byKey(target.key));
        await tester.pump();

        // 3. Tap sort option
        await tester.tap(find.byKey(target.key));
        await tester.pump();
        await pumpBounded(tester, steps: 6, stepDuration: const Duration(milliseconds: 50));

        // 4. Verify modal is cleanly dismissed
        expect(find.byKey(target.key), findsNothing, reason: 'Modal must close after selecting ${target.key}');

        // 5. Verify provider was updated
        expect(
          container.read(vaultSortOptionProvider),
          equals(target.option),
          reason: 'vaultSortOptionProvider must update to ${target.option}',
        );
      }
    });

    testWidgets('5.3: Dismissing sort modal via close button preserves existing sort option', (tester) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(buildVaultHarness(container: container));
      await pumpBounded(tester, steps: 5);

      // Select Reputation (Highest) first
      container.read(vaultSortOptionProvider.notifier).state = VaultSortOption.reputationHighest;

      // Open modal
      await tester.tap(find.byKey(const Key('vault_sort_button')));
      await tester.pump();
      await pumpBounded(tester, steps: 6);

      // Tap close icon in modal header
      final modalCloseButton = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byIcon(Icons.close),
      );
      expect(modalCloseButton, findsOneWidget);
      await tester.tap(modalCloseButton);
      await tester.pump();
      await pumpBounded(tester, steps: 6);

      // Verify modal dismissed and state preserved
      expect(find.byType(BottomSheet), findsNothing);
      expect(container.read(vaultSortOptionProvider), equals(VaultSortOption.reputationHighest));
    });
  });
}
