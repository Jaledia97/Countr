import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/providers/mtg_filter_state.dart';
import 'package:countr/features/vault/presentation/screens/vault_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Adversarial Challenge 1: Query Latency Under Heavy MTG Filters (<100ms)', () {
    late AppDatabase db;
    late VaultDao dao;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      dao = db.vaultDao;
      await dao.clearAllItems();

      // Seed 1,500 cards with diverse MTG attributes and valid dynamicData JSON
      final colorsPool = [
        ['W'],
        ['U'],
        ['B'],
        ['R'],
        ['G'],
        ['U', 'R'],
        ['W', 'U'],
        ['B', 'G'],
        ['W', 'U', 'B', 'R', 'G'],
        <String>[],
      ];
      final raritiesPool = ['common', 'uncommon', 'rare', 'mythic'];
      final typePool = ['Creature', 'Instant', 'Sorcery', 'Artifact', 'Enchantment', 'Planeswalker', 'Land'];

      final baseDate = DateTime(2026, 1, 1);

      await db.batch((batch) {
        for (int i = 0; i < 1500; i++) {
          final colors = colorsPool[i % colorsPool.length];
          final rarity = raritiesPool[i % raritiesPool.length];
          final type = typePool[i % typePool.length];
          final cmc = (i % 8).toDouble();

          final dynamicDataJson = jsonEncode({
            'colors': colors,
            'color_identity': colors,
            'rarity': rarity,
            'cmc': cmc,
            'type_line': '$type — Spec $i',
            'layout': 'normal',
            'mana_cost': '{${cmc.toInt()}}',
          });

          batch.insert(
            db.vaultItems,
            VaultItemsCompanion.insert(
              id: 'card-$i',
              collectionType: 'mtg',
              name: 'Card ${i.toString().padLeft(4, '0')}',
              setOrSeries: 'SET${i % 10}',
              imageUrl: 'https://example.com/card-$i.jpg',
              acquiredPrice: 1.0 + (i % 20),
              acquiredDate: baseDate.add(Duration(minutes: i)),
              quantity: const drift.Value(1),
              condition: 'NM',
              currentMarketPrice: 2.0 + (i % 20),
              lastPriceUpdate: baseDate,
              dynamicData: dynamicDataJson,
            ),
          );
        }
      });
    });

    tearDown(() async {
      await db.close();
    });

    test('Heavy combined MTG filter returns first 60 rows in <100ms and true count in <100ms', () async {
      final heavyFilter = const MtgFilterState(
        colors: {'U', 'R'},
        colorTarget: ColorTarget.colorIdentity,
        colorMatchMode: ColorMatchMode.including,
        cmcRange: RangeValues(2.0, 5.0),
        rarities: {'rare', 'mythic'},
        typeLine: 'Creature',
      );

      // Measure 1: Paginated fetch (first 60 rows)
      final swQuery = Stopwatch()..start();
      final page1 = await dao.getItemsByCollection(
        'mtg',
        mtgFilter: heavyFilter,
        limit: 60,
        offset: 0,
      );
      swQuery.stop();

      // Measure 2: Symmetrical count query
      final swCount = Stopwatch()..start();
      final count = await dao.getFilteredItemCount(
        'mtg',
        mtgFilter: heavyFilter,
      );
      swCount.stop();

      debugPrint('[Benchmark] Heavy filter first 60 rows: ${swQuery.elapsedMilliseconds}ms (returned: ${page1.length})');
      debugPrint('[Benchmark] Heavy filter count query: ${swCount.elapsedMilliseconds}ms (total matching: $count)');

      // Empirical invariants
      expect(swQuery.elapsedMilliseconds, lessThan(100),
          reason: 'Paginated SQL query under heavy MTG filters must execute in <100ms');
      expect(swCount.elapsedMilliseconds, lessThan(100),
          reason: 'Indexed SQL count query under heavy MTG filters must execute in <100ms');

      expect(page1.length, greaterThan(0));
      expect(page1.length, lessThanOrEqualTo(60));
      expect(count, greaterThanOrEqualTo(page1.length));

      // Check criteria correctness on returned rows
      for (final card in page1) {
        final decoded = jsonDecode(card.dynamicData) as Map<String, dynamic>;
        expect(decoded['type_line'].toString().toLowerCase(), contains('creature'));
        expect(['rare', 'mythic'], contains(decoded['rarity']));
        final cmcVal = (decoded['cmc'] as num).toDouble();
        expect(cmcVal, greaterThanOrEqualTo(2.0));
        expect(cmcVal, lessThanOrEqualTo(5.0));
      }
    });
  });

  group('Adversarial Challenge 2: Search Debounce, Rapid Key Typing, Backspacing & Cancellation', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await db.vaultDao.clearAllItems();

      // Seed cards for search testing
      final now = DateTime.now();
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-lotus-1',
          collectionType: 'mtg',
          name: 'Black Lotus',
          setOrSeries: 'LEA',
          imageUrl: '',
          acquiredPrice: 10000.0,
          acquiredDate: now,
          quantity: const drift.Value(1),
          condition: 'NM',
          currentMarketPrice: 25000.0,
          lastPriceUpdate: now,
          dynamicData: '{}',
        ),
      );
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-lotus-2',
          collectionType: 'mtg',
          name: 'Lotus Petal',
          setOrSeries: 'TMP',
          imageUrl: '',
          acquiredPrice: 20.0,
          acquiredDate: now,
          quantity: const drift.Value(1),
          condition: 'NM',
          currentMarketPrice: 25.0,
          lastPriceUpdate: now,
          dynamicData: '{}',
        ),
      );
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-mox',
          collectionType: 'mtg',
          name: 'Mox Sapphire',
          setOrSeries: 'LEA',
          imageUrl: '',
          acquiredPrice: 5000.0,
          acquiredDate: now,
          quantity: const drift.Value(1),
          condition: 'NM',
          currentMarketPrice: 8000.0,
          lastPriceUpdate: now,
          dynamicData: '{}',
        ),
      );
    });

    tearDown(() async {
      await db.close();
    });

    Widget createTestApp(ProviderContainer container) {
      return UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: VaultScreen(),
        ),
      );
    }

    testWidgets('Rapid typing, backspacing, clearing, and timer cancellation preserves query order and prevents race conditions', (tester) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(createTestApp(container));
      await tester.pumpAndSettle();

      // Initial state
      expect(container.read(vaultSearchQueryProvider), equals(''));

      // Expand search
      await tester.tap(find.byKey(const Key('vault_search_expand_button')));
      await tester.pumpAndSettle();

      final searchField = find.byKey(const Key('vault_search_text_field'));

      // 1. Rapid key typing: "M", "Mo", "Mox" with 80ms delay between keystrokes (< debounce)
      await tester.enterText(searchField, 'M');
      await tester.pump(const Duration(milliseconds: 80));
      expect(container.read(vaultSearchQueryProvider), equals(''), reason: 'Timer not expired');

      await tester.enterText(searchField, 'Mo');
      await tester.pump(const Duration(milliseconds: 80));
      expect(container.read(vaultSearchQueryProvider), equals(''), reason: 'Timer reset by new keystroke');

      await tester.enterText(searchField, 'Mox');
      await tester.pump(const Duration(milliseconds: 80));
      expect(container.read(vaultSearchQueryProvider), equals(''), reason: 'Timer reset again');

      // 2. Backspacing: "Mo", then "M"
      await tester.enterText(searchField, 'Mo');
      await tester.pump(const Duration(milliseconds: 80));
      expect(container.read(vaultSearchQueryProvider), equals(''));

      await tester.enterText(searchField, 'M');
      await tester.pump(const Duration(milliseconds: 80));
      expect(container.read(vaultSearchQueryProvider), equals(''));

      // 3. Type new query "Lotus"
      await tester.enterText(searchField, 'Lotus');
      await tester.pump(const Duration(milliseconds: 100)); // still pending
      expect(container.read(vaultSearchQueryProvider), equals(''));

      // 4. Let debounce expire (200ms in prod, 250ms in test -> pump 300ms)
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Query MUST be "Lotus" and only "Lotus"
      expect(container.read(vaultSearchQueryProvider), equals('Lotus'));

      // 5. Clear immediately
      final clearButton = find.byKey(const Key('vault_search_clear_button'));
      expect(clearButton, findsOneWidget);
      await tester.tap(clearButton);
      await tester.pump();

      // Provider search query cleared immediately
      expect(container.read(vaultSearchQueryProvider), equals(''));

      // Advance 300ms to guarantee no delayed timer fires
      await tester.pump(const Duration(milliseconds: 300));
      expect(container.read(vaultSearchQueryProvider), equals(''));
    });
  });

  group('Adversarial Challenge 3: Unbounded Pagination Past 150 Items', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await db.vaultDao.clearAllItems();

      // Seed 280 cards
      final now = DateTime.now();
      await db.batch((batch) {
        for (int i = 0; i < 280; i++) {
          batch.insert(
            db.vaultItems,
            VaultItemsCompanion.insert(
              id: 'unbounded-card-$i',
              collectionType: 'mtg',
              name: 'Unbounded Card ${i.toString().padLeft(4, '0')}',
              setOrSeries: 'UNB',
              imageUrl: '',
              acquiredPrice: 5.0,
              acquiredDate: now.add(Duration(minutes: i)),
              quantity: const drift.Value(1),
              condition: 'NM',
              currentMarketPrice: 10.0,
              lastPriceUpdate: now,
              dynamicData: '{"colors":["U"],"cmc":2,"type_line":"Instant","rarity":"uncommon"}',
            ),
          );
        }
      });
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('Pagination scrolls seamlessly past 150 items to 200, 250, and terminates cleanly at 280', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
          vaultPaginationLimitProvider.overrideWith((ref) => 50),
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
          cardDisplayLayoutProvider.overrideWith((ref) => CardDisplayLayout.list),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: VaultScreen()),
        ),
      );
      await tester.pumpAndSettle();

      final scrollable = tester.state<ScrollableState>(
        find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down),
      );

      Future<void> scrollAndAdvance() async {
        final maxScroll = scrollable.position.maxScrollExtent;
        scrollable.position.jumpTo(maxScroll - 50);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();
      }

      // Initial: 50
      expect(container.read(vaultPaginationLimitProvider), equals(50));
      expect(container.read(vaultItemsStreamProvider).valueOrNull?.length, equals(50));

      // Advance: 100
      await scrollAndAdvance();
      expect(container.read(vaultPaginationLimitProvider), equals(100));
      expect(container.read(vaultItemsStreamProvider).valueOrNull?.length, equals(100));

      // Advance: 150 (Former Cap)
      await scrollAndAdvance();
      expect(container.read(vaultPaginationLimitProvider), equals(150));
      expect(container.read(vaultItemsStreamProvider).valueOrNull?.length, equals(150));

      // Advance: 200 (Past 150 Former Cap!)
      await scrollAndAdvance();
      expect(container.read(vaultPaginationLimitProvider), equals(200));
      expect(container.read(vaultItemsStreamProvider).valueOrNull?.length, equals(200));

      // Advance: 250
      await scrollAndAdvance();
      expect(container.read(vaultPaginationLimitProvider), equals(250));
      expect(container.read(vaultItemsStreamProvider).valueOrNull?.length, equals(250));

      // Advance: 300 (total dataset has 280 items)
      await scrollAndAdvance();
      expect(container.read(vaultPaginationLimitProvider), equals(300));
      final items = container.read(vaultItemsStreamProvider).valueOrNull ?? [];
      expect(items.length, equals(280), reason: 'Dataset total is 280 cards');

      // Verify clean termination: no infinite spinner, no further increments
      expect(container.read(vaultIsFetchingMoreProvider), isFalse);
      expect(find.byKey(const Key('vault_fetching_more_indicator')), findsNothing);

      // Scroll again to max extent
      final maxScroll = scrollable.position.maxScrollExtent;
      scrollable.position.jumpTo(maxScroll);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      // Limit stays capped at 300, does not increment infinitely
      expect(container.read(vaultPaginationLimitProvider), equals(300));
      expect(container.read(vaultIsFetchingMoreProvider), isFalse);
    });
  });
}
