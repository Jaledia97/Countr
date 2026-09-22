import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/scanner/presentation/screens/inbox_screen.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.vaultDao.clearAllItems();
  });

  tearDown(() async {
    await db.close();
  });

  Widget createTestWidget(Widget child, {ProviderContainer? container}) {
    if (container != null) {
      return UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: child),
      );
    }
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        vaultDaoProvider.overrideWithValue(db.vaultDao),
      ],
      child: MaterialApp(home: child),
    );
  }

  VaultItem createCard({
    required String id,
    required String name,
    String collectionType = 'mtg',
    String setOrSeries = 'Alpha',
    double price = 100.0,
    double acquiredPrice = 80.0,
    int quantity = 1,
    String? primaryBinderId,
  }) {
    return VaultItem(
      id: id,
      collectionType: collectionType,
      name: name,
      setOrSeries: setOrSeries,
      imageUrl: '',
      acquiredPrice: acquiredPrice,
      acquiredDate: DateTime.now(),
      quantity: quantity,
      condition: 'NM',
      isGraded: false, isAltered: false, isMisprint: false, isSigned: false,
      personalNotes: null,
      currentMarketPrice: price,
      lastPriceUpdate: DateTime.now(),
      dynamicData: '{}',
      primaryBinderId: primaryBinderId,
    );
  }

  group('Requirement R4: Inbox Data Isolation & Portfolio Integrity', () {
    test('upsertScannedCardToInbox explicitly sets primary_binder_id = INBOX on insert and update', () async {
      final card = createCard(id: 'card-staging-1', name: 'Black Lotus', price: 5000.0);

      // Insert branch (existing == null)
      await db.vaultDao.upsertScannedCardToInbox(card);
      var item = await (db.select(db.vaultItems)..where((t) => t.id.equals('card-staging-1'))).getSingle();
      expect(item.primaryBinderId, equals('INBOX'));
      expect(item.quantity, equals(1));

      // Update branch (existing != null)
      await db.vaultDao.upsertScannedCardToInbox(card);
      item = await (db.select(db.vaultItems)..where((t) => t.id.equals('card-staging-1'))).getSingle();
      expect(item.primaryBinderId, equals('INBOX'));
      expect(item.quantity, equals(2));
    });

    test('watchInboxItems returns strictly items where primaryBinderId == INBOX and quantity > 0', () async {
      final inboxCard = createCard(id: 'inbox-1', name: 'Mox Sapphire');
      final binder = await db.vaultDao.createBinder(name: 'Power 9', collectionType: 'mtg');
      final binderCard = createCard(id: 'binder-card-1', name: 'Mox Jet', primaryBinderId: binder.id);
      final catalogCard = createCard(id: 'catalog-card-1', name: 'Mox Ruby', quantity: 0);

      await db.vaultDao.upsertScannedCardToInbox(inboxCard);

      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: binderCard.id,
          collectionType: binderCard.collectionType,
          name: binderCard.name,
          setOrSeries: binderCard.setOrSeries,
          imageUrl: binderCard.imageUrl,
          acquiredPrice: binderCard.acquiredPrice,
          acquiredDate: binderCard.acquiredDate,
          quantity: drift.Value(binderCard.quantity),
          condition: binderCard.condition,
          currentMarketPrice: binderCard.currentMarketPrice,
          lastPriceUpdate: DateTime.now(),
          dynamicData: binderCard.dynamicData,
          primaryBinderId: drift.Value(binder.id),
        ),
      );

      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: catalogCard.id,
          collectionType: catalogCard.collectionType,
          name: catalogCard.name,
          setOrSeries: catalogCard.setOrSeries,
          imageUrl: catalogCard.imageUrl,
          acquiredPrice: catalogCard.acquiredPrice,
          acquiredDate: catalogCard.acquiredDate,
          quantity: const drift.Value(0),
          condition: catalogCard.condition,
          currentMarketPrice: catalogCard.currentMarketPrice,
          lastPriceUpdate: DateTime.now(),
          dynamicData: catalogCard.dynamicData,
          primaryBinderId: const drift.Value('INBOX'),
        ),
      );

      final inboxItems = await db.vaultDao.watchInboxItems().first;
      expect(inboxItems.length, equals(1));
      expect(inboxItems.first.id, equals('inbox-1'));
    });

    test('Vault feed excludes INBOX cards while keeping seeded/unassigned cards and cards in binders', () async {
      // 1. Unassigned card (primaryBinderId == null)
      final seededCard = createCard(id: 'seeded-1', name: 'Seeded Mox Pearl', primaryBinderId: null);
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: seededCard.id,
          collectionType: seededCard.collectionType,
          name: seededCard.name,
          setOrSeries: seededCard.setOrSeries,
          imageUrl: seededCard.imageUrl,
          acquiredPrice: seededCard.acquiredPrice,
          acquiredDate: seededCard.acquiredDate,
          quantity: const drift.Value(1),
          condition: 'NM',
          currentMarketPrice: 1000.0,
          lastPriceUpdate: DateTime.now(),
          dynamicData: '{}',
          primaryBinderId: const drift.Value(null),
        ),
      );

      // 2. Card assigned to binder
      final binder = await db.vaultDao.createBinder(name: 'MTG Vault', collectionType: 'mtg');
      final binderCard = createCard(id: 'binder-item-1', name: 'Time Walk', primaryBinderId: binder.id);
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: binderCard.id,
          collectionType: binderCard.collectionType,
          name: binderCard.name,
          setOrSeries: binderCard.setOrSeries,
          imageUrl: binderCard.imageUrl,
          acquiredPrice: binderCard.acquiredPrice,
          acquiredDate: binderCard.acquiredDate,
          quantity: const drift.Value(1),
          condition: 'NM',
          currentMarketPrice: 2000.0,
          lastPriceUpdate: DateTime.now(),
          dynamicData: '{}',
          primaryBinderId: drift.Value(binder.id),
        ),
      );

      // 3. Staged card in INBOX
      final inboxCard = createCard(id: 'staged-inbox-1', name: 'Ancestral Recall');
      await db.vaultDao.upsertScannedCardToInbox(inboxCard);

      // Verify watchItemsByCollection
      final watchedItems = await db.vaultDao.watchItemsByCollection('mtg', onlyOwned: true).first;
      expect(watchedItems.map((i) => i.id).toSet(), equals({'seeded-1', 'binder-item-1'}));
      expect(watchedItems.any((i) => i.id == 'staged-inbox-1'), isFalse);

      // Verify getItemsByCollection
      final fetchedItems = await db.vaultDao.getItemsByCollection('mtg', onlyOwned: true);
      expect(fetchedItems.map((i) => i.id).toSet(), equals({'seeded-1', 'binder-item-1'}));
      expect(fetchedItems.any((i) => i.id == 'staged-inbox-1'), isFalse);
    });

    test('watchBinderItemCounts excludes INBOX items', () async {
      final binder = await db.vaultDao.createBinder(name: 'Binder Alpha', collectionType: 'mtg');
      final binderCard = createCard(id: 'bc-1', name: 'Sol Ring', primaryBinderId: binder.id, quantity: 2);
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: binderCard.id,
          collectionType: binderCard.collectionType,
          name: binderCard.name,
          setOrSeries: binderCard.setOrSeries,
          imageUrl: binderCard.imageUrl,
          acquiredPrice: 10.0,
          acquiredDate: DateTime.now(),
          quantity: const drift.Value(2),
          condition: 'NM',
          currentMarketPrice: 12.0,
          lastPriceUpdate: DateTime.now(),
          dynamicData: '{}',
          primaryBinderId: drift.Value(binder.id),
        ),
      );

      final inboxCard = createCard(id: 'inbox-bc-1', name: 'Demonic Tutor', quantity: 3);
      await db.vaultDao.upsertScannedCardToInbox(inboxCard);

      final counts = await db.vaultDao.watchBinderItemCounts().first;
      expect(counts[binder.id], equals(2));
      expect(counts.containsKey('INBOX'), isFalse);
    });

    test('vaultPortfolioSummaryProvider ignores INBOX items and incorporates them when moved to binder', () async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(vaultPortfolioSummaryProvider, (previous, next) {});
      addTearDown(sub.close);

      // Seed 1 owned card in Vault ($500 market value, $400 cost)
      final vaultCard = createCard(
        id: 'vault-1',
        name: 'Underground Sea',
        price: 500.0,
        acquiredPrice: 400.0,
        quantity: 1,
      );
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: vaultCard.id,
          collectionType: vaultCard.collectionType,
          name: vaultCard.name,
          setOrSeries: vaultCard.setOrSeries,
          imageUrl: '',
          acquiredPrice: 400.0,
          acquiredDate: DateTime.now(),
          quantity: const drift.Value(1),
          condition: 'NM',
          currentMarketPrice: 500.0,
          lastPriceUpdate: DateTime.now(),
          dynamicData: '{}',
          primaryBinderId: const drift.Value(null),
        ),
      );

      // Initial portfolio summary
      await Future<void>.delayed(const Duration(milliseconds: 50));
      var summary = container.read(vaultPortfolioSummaryProvider);
      expect(summary.totalMarketValue, equals(500.0));
      expect(summary.totalCostBasis, equals(400.0));
      expect(summary.totalItemCount, equals(1));

      // Scan card into Inbox ($1000 market value, $1000 cost)
      final inboxCard = createCard(
        id: 'inbox-card-val',
        name: 'Timetwister',
        price: 1000.0,
        acquiredPrice: 1000.0,
        quantity: 1,
      );
      await db.vaultDao.upsertScannedCardToInbox(inboxCard);

      // Verify staged card does NOT increase portfolio valuation or cost basis
      await Future<void>.delayed(const Duration(milliseconds: 50));
      summary = container.read(vaultPortfolioSummaryProvider);
      expect(summary.totalMarketValue, equals(500.0));
      expect(summary.totalCostBasis, equals(400.0));
      expect(summary.totalItemCount, equals(1));

      // Move staged card to a binder
      final binder = await db.vaultDao.createBinder(name: 'Vintage', collectionType: 'mtg');
      await db.vaultDao.assignItemsToBinder([inboxCard.id], binder.id);

      // Now portfolio must include the moved card: 500 + 1000 = 1500
      await Future<void>.delayed(const Duration(milliseconds: 100));
      summary = container.read(vaultPortfolioSummaryProvider);
      expect(summary.totalMarketValue, equals(1500.0));
      expect(summary.totalCostBasis, equals(1400.0));
      expect(summary.totalItemCount, equals(2));
    });
  });

  group('Requirement R5: Inbox Item Deletion (Single & Bulk)', () {
    test('deleteItem permanently removes row from SQLite', () async {
      final card = createCard(id: 'item-to-delete', name: 'Junk Rare');
      await db.vaultDao.upsertScannedCardToInbox(card);

      var item = await (db.select(db.vaultItems)..where((t) => t.id.equals('item-to-delete'))).getSingleOrNull();
      expect(item, isNotNull);

      final deleted = await db.vaultDao.deleteItem('item-to-delete');
      expect(deleted, equals(1));

      item = await (db.select(db.vaultItems)..where((t) => t.id.equals('item-to-delete'))).getSingleOrNull();
      expect(item, isNull);

      final notFound = await db.vaultDao.deleteItem('non-existent-id');
      expect(notFound, equals(0));
    });

    test('deleteItems bulk removes rows permanently from SQLite', () async {
      final c1 = createCard(id: 'del-1', name: 'Common 1');
      final c2 = createCard(id: 'del-2', name: 'Common 2');
      final c3 = createCard(id: 'keep-1', name: 'Rare Keeper');

      await db.vaultDao.upsertScannedCardToInbox(c1);
      await db.vaultDao.upsertScannedCardToInbox(c2);
      await db.vaultDao.upsertScannedCardToInbox(c3);

      final deleted = await db.vaultDao.deleteItems(['del-1', 'del-2']);
      expect(deleted, equals(2));

      final remaining = await (db.select(db.vaultItems)..where((t) => t.primaryBinderId.equals('INBOX'))).get();
      expect(remaining.length, equals(1));
      expect(remaining.first.id, equals('keep-1'));

      final emptyDelete = await db.vaultDao.deleteItems([]);
      expect(emptyDelete, equals(0));
    });

    testWidgets('Dismissible swipe-to-delete deletes card from SQLite and updates InboxScreen UI', (tester) async {
      final card1 = createCard(id: 'swipe-card-1', name: 'Card to Swipe');
      final card2 = createCard(id: 'swipe-card-2', name: 'Card to Keep');

      await db.vaultDao.upsertScannedCardToInbox(card1);
      await db.vaultDao.upsertScannedCardToInbox(card2);

      await tester.pumpWidget(createTestWidget(const InboxScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Card to Swipe'), findsOneWidget);
      expect(find.text('Card to Keep'), findsOneWidget);

      // Verify Dismissible exists with expected key
      final dismissibleFinder = find.byKey(Key('inbox_item_${card1.id}'));
      expect(dismissibleFinder, findsOneWidget);

      // Swipe endToStart (right-to-left) to dismiss
      await tester.drag(dismissibleFinder, const Offset(-500, 0));
      await tester.pumpAndSettle();

      // Card 1 must be gone from UI and SQLite
      expect(find.text('Card to Swipe'), findsNothing);
      expect(find.text('Card to Keep'), findsOneWidget);

      final row = await (db.select(db.vaultItems)..where((t) => t.id.equals('swipe-card-1'))).getSingleOrNull();
      expect(row, isNull);

      // SnackBar feedback displayed
      expect(find.text('Deleted "Card to Swipe" from Inbox'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('Dismissible swipe is disabled when selection mode is active', (tester) async {
      final card = createCard(id: 'sel-card-1', name: 'Selected Card');
      await db.vaultDao.upsertScannedCardToInbox(card);

      await tester.pumpWidget(createTestWidget(const InboxScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Enter selection mode via long press
      await tester.longPress(find.text('Selected Card'));
      await tester.pumpAndSettle();

      // Verify selection mode is active (bottom action bar shown)
      expect(find.byKey(const Key('inbox_trash_button')), findsOneWidget);

      // Attempt to drag Dismissible
      final dismissibleFinder = find.byKey(Key('inbox_item_${card.id}'));
      await tester.drag(dismissibleFinder, const Offset(-500, 0));
      await tester.pumpAndSettle();

      // Card must NOT be dismissed
      expect(find.text('Selected Card'), findsOneWidget);
      final row = await (db.select(db.vaultItems)..where((t) => t.id.equals('sel-card-1'))).getSingleOrNull();
      expect(row, isNotNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('Tapping [ Trash ] in selection mode bulk deletes selected cards from SQLite and updates UI', (tester) async {
      final card1 = createCard(id: 'bulk-del-1', name: 'Bulk Card Alpha');
      final card2 = createCard(id: 'bulk-del-2', name: 'Bulk Card Beta');

      await db.vaultDao.upsertScannedCardToInbox(card1);
      await db.vaultDao.upsertScannedCardToInbox(card2);

      await tester.pumpWidget(createTestWidget(const InboxScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Bulk Card Alpha'), findsOneWidget);
      expect(find.text('Bulk Card Beta'), findsOneWidget);

      // Long press card 1 to enter selection mode
      await tester.longPress(find.text('Bulk Card Alpha'));
      await tester.pumpAndSettle();

      // Tap card 2 to add to selection
      await tester.tap(find.text('Bulk Card Beta'));
      await tester.pumpAndSettle();

      // Verify Trash button is visible with proper key
      final trashButton = find.byKey(const Key('inbox_trash_button'));
      expect(trashButton, findsOneWidget);
      expect(find.text('Trash'), findsOneWidget);

      // Tap Trash
      await tester.tap(trashButton);
      await tester.pumpAndSettle();

      // Verify both cards are removed from SQLite
      final rows = await (db.select(db.vaultItems)..where((t) => t.primaryBinderId.equals('INBOX'))).get();
      expect(rows, isEmpty);

      // Verify empty state is displayed
      expect(find.text('Inbox is Empty'), findsOneWidget);

      // Verify SnackBar feedback
      expect(find.text('Deleted 2 items from Inbox'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });
  });
}
