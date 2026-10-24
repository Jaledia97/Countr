import 'dart:async';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/vault/domain/models/card_availability.dart';
import 'package:countr/features/vault/presentation/providers/mtg_filter_state.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/screens/vault_screen.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_card.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_tile.dart';

VaultItem _createDummyVaultItem({
  required String id,
  required String name,
  String setCode = 'LEA',
  int quantity = 1,
  double price = 10.0,
  String collectionType = 'mtg',
}) {
  final now = DateTime.now();
  return VaultItem(
    id: id,
    collectionType: collectionType,
    name: name,
    setOrSeries: setCode,
    imageUrl: '',
    flavorName: null,
    acquiredPrice: price,
    acquiredDate: now,
    quantity: quantity,
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
    currentMarketPrice: price,
    lastPriceUpdate: now,
    dynamicData: '{"colors":["U"],"cmc":2}',
    isDeleted: false,
    updatedAt: now,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Adversarial Challenge 1: Spinner Resilience & Lifecycle Invariants', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await db.vaultDao.clearAllItems();
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('Rapid consecutive scrolls do not deadlock or permanently freeze isFetchingMore',
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

      final initialCards = List.generate(50, (i) => _createDummyVaultItem(id: 'c-$i', name: 'Card $i'));
      streamController.add(initialCards);
      await tester.pump();

      expect(container.read(vaultIsFetchingMoreProvider), isFalse);
      expect(container.read(vaultPaginationLimitProvider), equals(50));

      final scrollable = tester.state<ScrollableState>(
        find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down),
      );

      // Trigger scroll 1
      scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
      await tester.pump();
      expect(container.read(vaultIsFetchingMoreProvider), isTrue);
      expect(container.read(vaultPaginationLimitProvider), equals(100));

      // Repeated rapid scroll while already fetching more should be ignored
      scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
      await tester.pump();
      expect(container.read(vaultPaginationLimitProvider), equals(100));

      // Emit new page of 100 items
      final secondPageCards = List.generate(100, (i) => _createDummyVaultItem(id: 'c-$i', name: 'Card $i'));
      streamController.add(secondPageCards);
      await tester.pump();

      // Verified: isFetchingMore resets cleanly to false
      expect(container.read(vaultIsFetchingMoreProvider), isFalse);
      expect(find.byKey(const Key('vault_fetching_more_indicator')), findsNothing);
    });

    testWidgets('Rapid filter switching (colors, rarity, search) resets spinner to false immediately',
        (tester) async {
      final streamController = StreamController<List<VaultItem>>.broadcast();
      addTearDown(() => streamController.close());

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          vaultItemsStreamProvider.overrideWith((ref) => streamController.stream),
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
      await tester.pump();

      // Simulate fetch in progress
      container.read(vaultIsFetchingMoreProvider.notifier).state = true;
      container.read(vaultPaginationLimitProvider.notifier).state = 150;
      expect(container.read(vaultIsFetchingMoreProvider), isTrue);

      // Switch 1: Filter to Red
      container.read(mtgFilterProvider.notifier).state = const MtgFilterState(colors: {'R'});
      await tester.pump();
      expect(container.read(vaultIsFetchingMoreProvider), isFalse);
      expect(container.read(vaultPaginationLimitProvider), equals(50));

      // Again simulate fetch
      container.read(vaultIsFetchingMoreProvider.notifier).state = true;
      container.read(vaultPaginationLimitProvider.notifier).state = 100;
      expect(container.read(vaultIsFetchingMoreProvider), isTrue);

      // Switch 2: Rapid Search Query
      container.read(vaultSearchQueryProvider.notifier).state = 'Mox';
      await tester.pump();
      expect(container.read(vaultIsFetchingMoreProvider), isFalse);
      expect(container.read(vaultPaginationLimitProvider), equals(50));

      // Switch 3: Catalog View Toggle
      container.read(vaultIsFetchingMoreProvider.notifier).state = true;
      container.read(vaultShowCatalogProvider.notifier).state = true;
      await tester.pump();
      expect(container.read(vaultIsFetchingMoreProvider), isFalse);
      expect(container.read(vaultPaginationLimitProvider), equals(50));
    });

    testWidgets('Reaching the end of collection does NOT leave spinner stuck and ignores further scrolls',
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

      // 50 items initially
      final initialCards = List.generate(50, (i) => _createDummyVaultItem(id: 'c-$i', name: 'Card $i'));
      streamController.add(initialCards);
      await tester.pump();

      final scrollable = tester.state<ScrollableState>(
        find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down),
      );

      // Scroll to trigger fetch more
      scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
      await tester.pump();
      expect(container.read(vaultIsFetchingMoreProvider), isTrue);
      expect(container.read(vaultPaginationLimitProvider), equals(100));

      // Only 60 items exist total in collection (end reached!)
      final finalCards = List.generate(60, (i) => _createDummyVaultItem(id: 'c-$i', name: 'Card $i'));
      streamController.add(finalCards);
      await tester.pump();

      // Spinner should reset to false
      expect(container.read(vaultIsFetchingMoreProvider), isFalse);
      expect(find.byKey(const Key('vault_fetching_more_indicator')), findsNothing);

      // Scroll again when at end of collection (60 items < 100 * 0.7 = 70)
      scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
      await tester.pump();

      // Verified: isFetchingMore remains false, limit remains 100
      expect(container.read(vaultIsFetchingMoreProvider), isFalse);
      expect(container.read(vaultPaginationLimitProvider), equals(100));
      expect(find.byKey(const Key('vault_fetching_more_indicator')), findsNothing);
    });

    testWidgets('Stream error immediately clears isFetchingMore and cancels safety timer', (tester) async {
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

      final initialCards = List.generate(50, (i) => _createDummyVaultItem(id: 'c-$i', name: 'Card $i'));
      streamController.add(initialCards);
      await tester.pump();

      final scrollable = tester.state<ScrollableState>(
        find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down),
      );
      scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
      await tester.pump();

      expect(container.read(vaultIsFetchingMoreProvider), isTrue);

      // Emit error on stream
      streamController.addError(Exception('Database disk I/O error'));
      await tester.pump();

      // Verified: error resets isFetchingMore immediately
      expect(container.read(vaultIsFetchingMoreProvider), isFalse);
      expect(find.byKey(const Key('vault_fetching_more_indicator')), findsNothing);
    });
  });

  group('Adversarial Challenge 2: Tile Rebuild Isolation & Scoped Provider Watches', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await db.vaultDao.clearAllItems();
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('Tile Rebuild Isolation: Adjacent tile does NOT rebuild when neighbor card availability changes',
        (tester) async {
      final cardA = _createDummyVaultItem(id: 'card-a', name: 'Alpha Lotus', quantity: 2);
      final cardB = _createDummyVaultItem(id: 'card-b', name: 'Beta Mox', quantity: 4);

      final availabilityController = StreamController<Map<String, CardAvailability>>.broadcast();
      addTearDown(() => availabilityController.close());

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          allCardAvailabilityProvider.overrideWith((ref) => availabilityController.stream),
          allCardActiveDecksProvider.overrideWith((ref) => Stream.value(<String, List<String>>{})),
        ],
      );

      availabilityController.add({
        'card-a': const CardAvailability(owned: 2, available: 2, inDeck: 0),
        'card-b': const CardAvailability(owned: 4, available: 4, inDeck: 0),
      });

      int tileABuildCount = 0;
      int tileBBuildCount = 0;

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
                        tileABuildCount++;
                        return VaultItemTile(item: cardA);
                      },
                    ),
                  ),
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        tileBBuildCount++;
                        return VaultItemTile(item: cardB);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final initialCountA = tileABuildCount;
      final initialCountB = tileBBuildCount;

      // Verify initial UI text
      expect(find.text('Available: 2'), findsOneWidget); // Card A
      expect(find.text('Available: 4'), findsOneWidget); // Card B

      // Adversarial mutation: Card B is allocated to a deck (available drops to 1, inDeck rises to 3)
      availabilityController.add({
        'card-a': const CardAvailability(owned: 2, available: 2, inDeck: 0), // Unchanged
        'card-b': const CardAvailability(owned: 4, available: 1, inDeck: 3), // Mutated
      });
      await tester.pump();
      await tester.pump();

      // Card B's breakdown rebuilt and reflects new numbers
      expect(find.text('Available: 1'), findsOneWidget);
      expect(find.text('In Deck: 3'), findsOneWidget);

      // Card A's breakdown still displays its original numbers
      expect(find.text('Available: 2'), findsOneWidget);

      // Verified: Card A parent tile did NOT rebuild!
      expect(tileABuildCount, equals(initialCountA));
      expect(tileBBuildCount, equals(initialCountB));
    });

    testWidgets('Active Decks Isolation: Neighbor tile does not rebuild when card deck tags mutate', (tester) async {
      final cardA = _createDummyVaultItem(id: 'card-a', name: 'Card A', quantity: 1);
      final cardB = _createDummyVaultItem(id: 'card-b', name: 'Card B', quantity: 1);

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

      decksController.add({
        'card-a': const <String>[],
        'card-b': const <String>[],
      });

      int tileABuildCount = 0;
      int tileBBuildCount = 0;

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
                        tileABuildCount++;
                        return VaultItemTile(item: cardA);
                      },
                    ),
                  ),
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        tileBBuildCount++;
                        return VaultItemTile(item: cardB);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final initialCountA = tileABuildCount;
      final initialCountB = tileBBuildCount;

      // Card B assigned to Commander deck
      decksController.add({
        'card-a': const <String>[],
        'card-b': const <String>['Atraxa Proliferate'],
      });
      await tester.pump();
      await tester.pump();

      // Card B displays the deck badge
      expect(find.text('⚔️ Atraxa Proliferate'), findsOneWidget);

      // Verified: Card A tile build count did NOT increment, Card B parent did NOT rebuild
      expect(tileABuildCount, equals(initialCountA));
      expect(tileBBuildCount, equals(initialCountB));
    });

    testWidgets('VaultItemCard (List View) rebuild isolation on availability mutation', (tester) async {
      final cardA = _createDummyVaultItem(id: 'card-a', name: 'Card A', quantity: 3);
      final cardB = _createDummyVaultItem(id: 'card-b', name: 'Card B', quantity: 5);

      final availabilityController = StreamController<Map<String, CardAvailability>>.broadcast();
      addTearDown(() => availabilityController.close());

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          allCardAvailabilityProvider.overrideWith((ref) => availabilityController.stream),
          allCardActiveDecksProvider.overrideWith((ref) => Stream.value(<String, List<String>>{})),
        ],
      );

      availabilityController.add({
        'card-a': const CardAvailability(owned: 3, available: 3, inDeck: 0),
        'card-b': const CardAvailability(owned: 5, available: 5, inDeck: 0),
      });

      int cardABuildCount = 0;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  Builder(
                    builder: (context) {
                      cardABuildCount++;
                      return VaultItemCard(item: cardA);
                    },
                  ),
                  VaultItemCard(item: cardB),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final initialCountA = cardABuildCount;

      // Card B changes
      availabilityController.add({
        'card-a': const CardAvailability(owned: 3, available: 3, inDeck: 0),
        'card-b': const CardAvailability(owned: 5, available: 2, inDeck: 3),
      });
      await tester.pump();
      await tester.pump();

      // Card B shows updated availability
      expect(find.text('Available: 2'), findsOneWidget);

      // Card A parent did NOT rebuild
      expect(cardABuildCount, equals(initialCountA));
    });
  });

  group('Adversarial Challenge 3: Full-Screen Loading Flash Elimination via _retainedItems', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await db.vaultDao.clearAllItems();
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('Pagination increment does NOT flash full-screen loading spinner while waiting for next page',
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

      final page1Cards = List.generate(50, (i) => _createDummyVaultItem(id: 'c-$i', name: 'Card $i'));
      streamController.add(page1Cards);
      await tester.pump();

      // Verify list has rendered items
      expect(find.byType(VaultItemCard), findsWidgets);
      expect(find.text('Card 0'), findsOneWidget);

      // Trigger pagination fetch by scrolling to bottom
      final scrollable = tester.state<ScrollableState>(
        find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down),
      );
      scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
      await tester.pump();

      expect(container.read(vaultIsFetchingMoreProvider), isTrue);

      // Verify bottom subtle spinner is rendered
      expect(find.byKey(const Key('vault_fetching_more_indicator')), findsOneWidget);

      // Crucial assertion: The existing items are STILL visible and NOT replaced with a full-screen loading spinner!
      expect(find.byType(VaultItemCard), findsWidgets);
      expect(find.byType(SliverFillRemaining), findsNothing);

      // Next page arrives
      final page2Cards = List.generate(100, (i) => _createDummyVaultItem(id: 'c-$i', name: 'Card $i'));
      streamController.add(page2Cards);
      await tester.pump();

      // Bottom spinner disappears
      expect(find.byKey(const Key('vault_fetching_more_indicator')), findsNothing);
      expect(container.read(vaultIsFetchingMoreProvider), isFalse);
    });

    testWidgets('Switching active game context clears retained items to prevent cross-game leakage',
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

      final mtgCards = [_createDummyVaultItem(id: 'mtg-1', name: 'Black Lotus')];
      streamController.add(mtgCards);
      await tester.pump();

      expect(find.text('Black Lotus'), findsOneWidget);

      // Switch game to Pokémon
      container.read(activeGameContextProvider.notifier).state = 'Pokémon TCG';
      streamController.add(<VaultItem>[]);
      await tester.pump();
      await tester.pump();

      // Verify Black Lotus is no longer rendered
      expect(find.text('Black Lotus'), findsNothing);
    });
  });

  group('Adversarial Challenge 4: High-Stress Concurrency & Multi-Tile Scale Harness', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await db.vaultDao.clearAllItems();
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('12-Tile Grid Scale: Mutating 1 card availability triggers 0 rebuilds across 11 neighbor tiles',
        (tester) async {
      final cards = List.generate(
        12,
        (i) => _createDummyVaultItem(id: 'grid-card-$i', name: 'Card $i', quantity: 2),
      );

      final availabilityController = StreamController<Map<String, CardAvailability>>.broadcast();
      addTearDown(() => availabilityController.close());

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          allCardAvailabilityProvider.overrideWith((ref) => availabilityController.stream),
          allCardActiveDecksProvider.overrideWith((ref) => Stream.value(<String, List<String>>{})),
        ],
      );

      final initialMap = {
        for (int i = 0; i < 12; i++)
          'grid-card-$i': const CardAvailability(owned: 2, available: 2, inDeck: 0),
      };
      availabilityController.add(initialMap);

      final buildCounts = List<int>.filled(12, 0);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.7,
                ),
                itemCount: 12,
                itemBuilder: (context, index) {
                  return Builder(
                    builder: (context) {
                      buildCounts[index]++;
                      return VaultItemTile(item: cards[index]);
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final baselineCounts = List<int>.from(buildCounts);

      // Mutate availability of card 5 ONLY
      final updatedMap = Map<String, CardAvailability>.from(initialMap);
      updatedMap['grid-card-5'] = const CardAvailability(owned: 2, available: 0, inDeck: 2);
      availabilityController.add(updatedMap);
      await tester.pump();
      await tester.pump();

      // Card 5 UI reflects inDeck: 2
      expect(find.text('In Deck: 2'), findsOneWidget);

      // Verifies: All 11 neighbor tile parent builders did NOT increment their build count
      for (int i = 0; i < 12; i++) {
        expect(buildCounts[i], equals(baselineCounts[i]),
            reason: 'Tile $i build count should not increase on targeted card-5 availability change');
      }
    });

    testWidgets('Rapid concurrent filter mutations and scroll events never leave spinner stuck',
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

      final cards = List.generate(50, (i) => _createDummyVaultItem(id: 'c-$i', name: 'Card $i'));
      streamController.add(cards);
      await tester.pump();

      final scrollable = tester.state<ScrollableState>(
        find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down),
      );

      // Interleave scrolls and rapid filter changes in a rapid loop
      for (int i = 0; i < 10; i++) {
        scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
        await tester.pump();

        if (i % 3 == 0) {
          container.read(mtgFilterProvider.notifier).state = MtgFilterState(colors: {i.isEven ? 'U' : 'B'});
        } else if (i % 3 == 1) {
          container.read(vaultSearchQueryProvider.notifier).state = 'Search $i';
        } else {
          container.read(vaultShowCatalogProvider.notifier).state = (i % 2 == 0);
        }
        await tester.pump();
      }

      // Final settling
      await tester.pumpAndSettle();

      // Invariants strictly held: fetching more is false, limit is reset to 50, no stuck indicator
      expect(container.read(vaultIsFetchingMoreProvider), isFalse);
      expect(container.read(vaultPaginationLimitProvider), equals(50));
      expect(find.byKey(const Key('vault_fetching_more_indicator')), findsNothing);
    });

    testWidgets('Rapid stream reload oscillations (data -> loading -> data) never flash full-screen loading spinner',
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

      // Initial data
      final initialCards = List.generate(50, (i) => _createDummyVaultItem(id: 'c-$i', name: 'Card $i'));
      streamController.add(initialCards);
      await tester.pump();

      expect(find.byType(VaultItemCard), findsWidgets);
      expect(find.byType(SliverFillRemaining), findsNothing);

      // Oscillate between loading and new data 5 times
      for (int i = 0; i < 5; i++) {
        // Scroll triggers isFetchingMore
        container.read(vaultIsFetchingMoreProvider.notifier).state = true;
        await tester.pump();

        // Cards remain visible, NO full-screen loading spinner
        expect(find.byType(VaultItemCard), findsWidgets);
        expect(find.byType(SliverFillRemaining), findsNothing);

        // New data arrives
        final updatedCards = List.generate(50 + (i + 1) * 10, (idx) => _createDummyVaultItem(id: 'c-$idx', name: 'Card $idx'));
        streamController.add(updatedCards);
        await tester.pump();

        // Cards still visible, full screen loading spinner never shown
        expect(find.byType(VaultItemCard), findsWidgets);
        expect(find.byType(SliverFillRemaining), findsNothing);
      }
    });
  });
}
