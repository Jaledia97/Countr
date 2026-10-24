import 'dart:async';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/domain/models/card_availability.dart';
import 'package:countr/features/vault/presentation/providers/mtg_filter_state.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/screens/vault_screen.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_tile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Milestone 2 Component 1: VaultDao.watchAllCardAvailability Owned Filter', () {
    late AppDatabase db;
    late VaultDao dao;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      dao = db.vaultDao;
      await dao.clearAllItems();
    });

    tearDown(() async {
      await db.close();
    });

    test('watchAllCardAvailability excludes quantity == 0 unowned catalog items', () async {
      final now = DateTime.now();

      // Insert owned card
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'owned-card-1',
          collectionType: 'mtg',
          name: 'Black Lotus',
          setOrSeries: 'LEA',
          imageUrl: '',
          acquiredPrice: 1000.0,
          acquiredDate: now,
          quantity: const drift.Value(1),
          condition: 'NM',
          currentMarketPrice: 2000.0,
          lastPriceUpdate: now,
          dynamicData: '{}',
        ),
      );

      // Insert unowned catalog card (quantity = 0)
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'catalog-card-zero',
          collectionType: 'mtg',
          name: 'Mox Sapphire',
          setOrSeries: 'LEA',
          imageUrl: '',
          acquiredPrice: 0.0,
          acquiredDate: now,
          quantity: const drift.Value(0),
          condition: 'NM',
          currentMarketPrice: 500.0,
          lastPriceUpdate: now,
          dynamicData: '{}',
        ),
      );

      // Insert soft-deleted card (quantity = 2, is_deleted = 1)
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'deleted-card',
          collectionType: 'mtg',
          name: 'Ancestral Recall',
          setOrSeries: 'LEA',
          imageUrl: '',
          acquiredPrice: 500.0,
          acquiredDate: now,
          quantity: const drift.Value(2),
          condition: 'NM',
          isDeleted: const drift.Value(true),
          currentMarketPrice: 1500.0,
          lastPriceUpdate: now,
          dynamicData: '{}',
        ),
      );

      final map = await dao.watchAllCardAvailability().first;

      // Owned card is present
      expect(map.containsKey('owned-card-1'), isTrue);
      expect(map['owned-card-1']!.owned, equals(1));
      expect(map['owned-card-1']!.available, equals(1));
      expect(map['owned-card-1']!.inDeck, equals(0));

      // Catalog card (quantity == 0) is excluded from query
      expect(map.containsKey('catalog-card-zero'), isFalse);

      // Soft-deleted card is excluded from query
      expect(map.containsKey('deleted-card'), isFalse);
    });
  });

  group('Milestone 2 Component 2: Provider Scoping (.select) for Tile & Card', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await db.vaultDao.clearAllItems();
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('VaultItemTile rebuild count is isolated to targeted card availability changes', (tester) async {
      final now = DateTime.now();

      final cardA = VaultItem(
        id: 'card-a',
        collectionType: 'mtg',
        name: 'Sol Ring',
        setOrSeries: 'LEA',
        imageUrl: '',
        flavorName: null,
        acquiredPrice: 5.0,
        acquiredDate: now,
        quantity: 2,
        condition: 'NM',
        isGraded: false,
        isAltered: false,
        isMisprint: false,
        isSigned: false,
        personalNotes: null,
        dateObtained: null,
        purchasePrice: null,
        binderPage: null,
        binderSlot: null,
        notes: null,
        protectionStatus: null,
        primaryBinderId: null,
        currentMarketPrice: 10.0,
        lastPriceUpdate: now,
        dynamicData: '{}',
        isDeleted: false,
        updatedAt: now,
      );

      final streamController = StreamController<Map<String, CardAvailability>>.broadcast();
      addTearDown(() => streamController.close());

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          allCardAvailabilityProvider.overrideWith((ref) => streamController.stream),
          allCardActiveDecksProvider.overrideWith((ref) => Stream.value(<String, List<String>>{})),
        ],
      );

      final cardB = cardA.copyWith(
        id: 'card-b',
        name: 'Mana Crypt',
        quantity: 4,
      );

      int buildCountA = 0;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Row(
                children: [
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        buildCountA++;
                        return VaultItemTile(item: cardA);
                      },
                    ),
                  ),
                  Expanded(
                    child: VaultItemTile(item: cardB),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      streamController.add({
        'card-a': const CardAvailability(owned: 2, available: 2, inDeck: 0),
        'card-b': const CardAvailability(owned: 4, available: 4, inDeck: 0),
      });
      await tester.pump();
      await tester.pump();

      final initialBuildCount = buildCountA;
      expect(find.text('Available: 2'), findsOneWidget); // card A has 2
      expect(find.text('Available: 4'), findsOneWidget); // card B has 4

      // Mutate availability for card B ONLY (card A availability is unchanged)
      streamController.add({
        'card-a': const CardAvailability(owned: 2, available: 2, inDeck: 0),
        'card-b': const CardAvailability(owned: 4, available: 1, inDeck: 3), // Changed!
      });

      await tester.pump();
      await tester.pump();

      // Card B's breakdown rebuilt and reflects mutated values
      expect(find.text('Available: 1'), findsOneWidget);
      expect(find.text('In Deck: 3'), findsOneWidget);

      // Card A still displays original availability
      expect(find.text('Available: 2'), findsOneWidget);

      // Card A parent should not have rebuilt
      expect(buildCountA, equals(initialBuildCount));
      expect(find.byType(VaultItemTile), findsNWidgets(2));
    });

    testWidgets('Active decks value-equated selector isolates rebuilds when unrelated card deck mutates', (tester) async {
      final now = DateTime.now();
      final cardA = VaultItem(
        id: 'card-a',
        collectionType: 'mtg',
        name: 'Card A',
        setOrSeries: 'TEST',
        imageUrl: '',
        flavorName: null,
        acquiredPrice: 5.0,
        acquiredDate: now,
        quantity: 2,
        condition: 'NM',
        isGraded: false,
        isAltered: false,
        isMisprint: false,
        isSigned: false,
        personalNotes: null,
        dateObtained: null,
        purchasePrice: null,
        binderPage: null,
        binderSlot: null,
        notes: null,
        protectionStatus: null,
        primaryBinderId: null,
        currentMarketPrice: 10.0,
        lastPriceUpdate: now,
        dynamicData: '{}',
        isDeleted: false,
        updatedAt: now,
      );
      final cardB = cardA.copyWith(
        id: 'card-b',
        name: 'Card B',
        quantity: 4,
      );

      final decksController = StreamController<Map<String, List<String>>>.broadcast();
      addTearDown(() => decksController.close());

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          allCardAvailabilityProvider.overrideWith((ref) => Stream.value(<String, CardAvailability>{})),
          allCardActiveDecksProvider.overrideWith((ref) => decksController.stream),
        ],
      );

      // Both cards start with existing deck assignments
      int buildCountA = 0;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Row(
                children: [
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        buildCountA++;
                        return VaultItemTile(item: cardA);
                      },
                    ),
                  ),
                  Expanded(
                    child: VaultItemTile(item: cardB),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      decksController.add({
        'card-a': ['Modern Affinity'],
        'card-b': ['Commander Urza'],
      });
      await tester.pump();
      await tester.pump();

      final initialBuildCountA = buildCountA;
      expect(find.text('⚔️ Modern Affinity'), findsOneWidget);
      expect(find.text('⚔️ Commander Urza'), findsOneWidget);

      // Mutate Card B's deck list (new list instances allocated, but Card A's list contents identical)
      decksController.add({
        'card-a': ['Modern Affinity'], // newly allocated list, same content
        'card-b': ['Commander Urza', 'Legacy Lands'], // mutated
      });

      await tester.pump();
      await tester.pump();

      expect(find.text('⚔️ Legacy Lands'), findsOneWidget);
      expect(buildCountA, equals(initialBuildCountA));
    });
  });

  group('Milestone 2 Component 3: Bounded SQL Window on Filtered Collection Queries', () {
    late AppDatabase db;
    late VaultDao dao;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      dao = db.vaultDao;
      await dao.clearAllItems();
    });

    tearDown(() async {
      await db.close();
    });

    test('Bounded SQL window retrieves matching cards without starvation when limit is provided', () async {
      final now = DateTime.now();

      // Seed 30 Green cards (non-matching) followed by 5 Red cards (matching)
      for (int i = 0; i < 30; i++) {
        await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'green-$i',
            collectionType: 'mtg',
            name: 'Green Elf $i',
            setOrSeries: 'TEST',
            imageUrl: '',
            acquiredPrice: 1.0,
            acquiredDate: now.subtract(Duration(minutes: i)),
            quantity: const drift.Value(1),
            condition: 'NM',
            currentMarketPrice: 1.0,
            lastPriceUpdate: now,
            dynamicData: '{"colors":["G"],"cmc":1}',
          ),
        );
      }

      for (int i = 0; i < 5; i++) {
        await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'red-$i',
            collectionType: 'mtg',
            name: 'Red Dragon $i',
            setOrSeries: 'TEST',
            imageUrl: '',
            acquiredPrice: 10.0,
            acquiredDate: now.subtract(Duration(minutes: 50 + i)),
            quantity: const drift.Value(1),
            condition: 'NM',
            currentMarketPrice: 10.0,
            lastPriceUpdate: now,
            dynamicData: '{"colors":["R"],"cmc":5}',
          ),
        );
      }

      const redFilter = MtgFilterState(colors: {'R'});

      // Query with limit: 10 (bounded window with floor 200 comfortably spans all 35 cards)
      final results = await dao.getItemsByCollection(
        'mtg',
        onlyOwned: true,
        mtgFilter: redFilter,
        limit: 10,
      );

      expect(results.length, equals(5));
      for (final card in results) {
        expect(card.id.startsWith('red-'), isTrue);
      }
    });
  });

  group('Milestone 2 Component 4: VaultScreen Spinner Resolution & Retained Items', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await db.vaultDao.clearAllItems();
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('Filter changes immediately reset vaultIsFetchingMoreProvider and vaultPaginationLimitProvider',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
          cardDisplayLayoutProvider.overrideWith((ref) => CardDisplayLayout.list),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: VaultScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Simulate active fetching more state and modified pagination limit
      container.read(vaultIsFetchingMoreProvider.notifier).state = true;
      container.read(vaultPaginationLimitProvider.notifier).state = 150;
      expect(container.read(vaultIsFetchingMoreProvider), isTrue);
      expect(container.read(vaultPaginationLimitProvider), equals(150));

      // Mutate MTG filter
      container.read(mtgFilterProvider.notifier).state = const MtgFilterState(colors: {'U'});
      await tester.pump();

      // Verifies listener immediately resets fetching more and pagination limit
      expect(container.read(vaultIsFetchingMoreProvider), isFalse);
      expect(container.read(vaultPaginationLimitProvider), equals(50));
    });

    testWidgets('Search query changes immediately reset vaultIsFetchingMoreProvider and vaultPaginationLimitProvider',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
          cardDisplayLayoutProvider.overrideWith((ref) => CardDisplayLayout.list),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: VaultScreen()),
        ),
      );
      await tester.pumpAndSettle();

      container.read(vaultIsFetchingMoreProvider.notifier).state = true;
      container.read(vaultPaginationLimitProvider.notifier).state = 200;

      // Update search query
      container.read(vaultSearchQueryProvider.notifier).state = 'Lotus';
      await tester.pump();

      expect(container.read(vaultIsFetchingMoreProvider), isFalse);
      expect(container.read(vaultPaginationLimitProvider), equals(50));
    });

    testWidgets('Catalog toggle changes immediately reset vaultIsFetchingMoreProvider and vaultPaginationLimitProvider',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
          cardDisplayLayoutProvider.overrideWith((ref) => CardDisplayLayout.list),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: VaultScreen()),
        ),
      );
      await tester.pumpAndSettle();

      container.read(vaultIsFetchingMoreProvider.notifier).state = true;
      container.read(vaultPaginationLimitProvider.notifier).state = 100;

      container.read(vaultShowCatalogProvider.notifier).state = true;
      await tester.pump();

      expect(container.read(vaultIsFetchingMoreProvider), isFalse);
      expect(container.read(vaultPaginationLimitProvider), equals(50));
    });

    testWidgets('Safety timeout resets vaultIsFetchingMoreProvider after 3 seconds if stream is silent',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final streamController = StreamController<List<VaultItem>>.broadcast();
      addTearDown(() => streamController.close());

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          vaultItemsStreamProvider.overrideWith((ref) => streamController.stream),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
          vaultPaginationLimitProvider.overrideWith((ref) => 50),
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
          cardDisplayLayoutProvider.overrideWith((ref) => CardDisplayLayout.list),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: VaultScreen()),
        ),
      );

      final now = DateTime.now();
      final dummyCards = List.generate(
        50,
        (i) => VaultItem(
          id: 'card-$i',
          collectionType: 'mtg',
          name: 'Card $i',
          setOrSeries: 'TEST',
          imageUrl: '',
          flavorName: null,
          acquiredPrice: 1.0,
          acquiredDate: now,
          quantity: 1,
          condition: 'NM',
          isGraded: false,
          isAltered: false,
          isMisprint: false,
          isSigned: false,
          personalNotes: null,
          dateObtained: null,
          purchasePrice: null,
          binderPage: null,
          binderSlot: null,
          notes: null,
          protectionStatus: null,
          primaryBinderId: null,
          currentMarketPrice: 2.0,
          lastPriceUpdate: now,
          dynamicData: '{}',
          isDeleted: false,
          updatedAt: now,
        ),
      );
      streamController.add(dummyCards);
      await tester.pump();

      expect(container.read(vaultPaginationLimitProvider), equals(50));
      expect(container.read(vaultIsFetchingMoreProvider), isFalse);

      final scrollable = tester.state<ScrollableState>(
        find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down),
      );
      scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
      await tester.pump();

      // _onScroll triggers fetch more and starts 3-second safety timeout
      expect(container.read(vaultIsFetchingMoreProvider), isTrue);
      expect(container.read(vaultPaginationLimitProvider), equals(100));

      // Advance clock past 3 seconds (without any new emissions from streamController)
      await tester.pump(const Duration(seconds: 4));

      // Verifies timeout automatically reset fetching more state to false
      expect(container.read(vaultIsFetchingMoreProvider), isFalse);
    });
  });
}
