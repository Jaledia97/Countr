import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/domain/models/assembly_models.dart';
import 'package:countr/features/decks/domain/models/board_zone.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.vaultDao.clearAllItems();
  });

  tearDown(() async {
    await db.close();
  });

  group('Empirical Challenge: VaultDao Swap Printing Collision & Downstream Operations', () {
    test('Collision merge preserves exact quantities and eliminates duplicate/orphaned rows', () async {
      await db.into(db.decks).insert(DecksCompanion.insert(
        id: 'deck-col-1',
        name: 'Collision Deck Alpha',
        format: 'Modern',
        isRegistered: const drift.Value(true),
        createdAt: DateTime.now(),
      ));

      await db.into(db.deckVersions).insert(DeckVersionsCompanion.insert(
        id: 'v-col-1',
        deckId: 'deck-col-1',
        versionNumber: 1,
        isActive: const drift.Value(true),
        createdAt: DateTime.now(),
      ));

      // Two printings of Fatal Push
      await db.into(db.vaultItems).insert(VaultItemsCompanion.insert(
        id: 'item-push-aer',
        collectionType: 'mtg',
        name: 'Fatal Push',
        setOrSeries: 'AER',
        imageUrl: 'https://example.com/aer.jpg',
        acquiredPrice: 3.0,
        acquiredDate: DateTime.now(),
        quantity: const drift.Value(4),
        condition: 'NM',
        currentMarketPrice: 3.00,
        lastPriceUpdate: DateTime.now(),
        dynamicData: '{"oracle_id": "push-oracle", "tag": "staple"}',
      ));

      await db.into(db.vaultItems).insert(VaultItemsCompanion.insert(
        id: 'item-push-2xm',
        collectionType: 'mtg',
        name: 'Fatal Push',
        setOrSeries: '2XM',
        imageUrl: 'https://example.com/2xm.jpg',
        acquiredPrice: 4.0,
        acquiredDate: DateTime.now(),
        quantity: const drift.Value(4),
        condition: 'NM',
        currentMarketPrice: 4.00,
        lastPriceUpdate: DateTime.now(),
        dynamicData: '{"oracle_id": "push-oracle", "tag": "borderless"}',
      ));

      // Add 3 copies of AER and 1 copy of 2XM in Mainboard
      await db.vaultDao.addCardToDeck('deck-col-1', 'item-push-aer', quantity: 3);
      await db.vaultDao.addCardToDeck('deck-col-1', 'item-push-2xm', quantity: 1);

      // Verify initial setup: 2 rows in deckVersionItems
      var allRows = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals('v-col-1')))
          .get();
      expect(allRows.length, 2);

      final aerDvi = allRows.firstWhere((r) => r.vaultItemId == 'item-push-aer');
      final xmDvi = allRows.firstWhere((r) => r.vaultItemId == 'item-push-2xm');
      expect(aerDvi.quantity, 3);
      expect(xmDvi.quantity, 1);

      // SWAP AER to 2XM -> Collision!
      await db.vaultDao.swapDeckItemPrinting(aerDvi.id, 'item-push-2xm');

      // 1. Verify exact row count is now 1
      allRows = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals('v-col-1')))
          .get();
      expect(allRows.length, 1, reason: 'Duplicate rows must be merged into single target row');

      // 2. Verify merged quantity is 3 + 1 = 4
      final mergedDvi = allRows.first;
      expect(mergedDvi.id, xmDvi.id, reason: 'Target existing row is kept and updated');
      expect(mergedDvi.vaultItemId, 'item-push-2xm');
      expect(mergedDvi.quantity, 4, reason: 'Quantities must sum together cleanly');

      // 3. Verify old DVI is completely deleted (no orphaned row)
      final orphanedDvi = await (db.select(db.deckVersionItems)
            ..where((t) => t.id.equals(aerDvi.id)))
          .getSingleOrNull();
      expect(orphanedDvi, isNull, reason: 'Old DVI row must be removed completely');

      // 4. Downstream Test A: setCardQuantityInDeck executes cleanly without 'Too many elements'
      await db.vaultDao.setCardQuantityInDeck('deck-col-1', 'item-push-2xm', 2);
      var afterSet = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals('v-col-1') & t.vaultItemId.equals('item-push-2xm')))
          .get();
      expect(afterSet.length, 1);
      expect(afterSet.first.quantity, 2);

      // 5. Downstream Test B: addCardToDeck executes cleanly without 'Too many elements'
      await db.vaultDao.addCardToDeck('deck-col-1', 'item-push-2xm', quantity: 2);
      var afterAdd = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals('v-col-1') & t.vaultItemId.equals('item-push-2xm')))
          .get();
      expect(afterAdd.length, 1);
      expect(afterAdd.first.quantity, 4);

      // 6. Downstream Test C: registerDeckWithProxyResolution executes cleanly without 'Too many elements'
      final pickItem = AssemblyPickItem(
        dviId: afterAdd.first.id,
        vaultItemId: 'item-push-2xm',
        cardName: 'Fatal Push',
        setCode: '2XM',
        boardZone: BoardZone.mainboard,
        requiredQuantity: 4,
        availableQuantity: 2,
        pullQuantity: 2,
        deficitQuantity: 2,
        locationName: 'Binder 1',
      );
      await db.vaultDao.registerDeckWithProxyResolution(
        deckId: 'deck-col-1',
        items: [pickItem],
      );

      // Verify proxy resolution produced 1 physical row (qty 2) and 1 proxy row (qty 2)
      final splitRows = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals('v-col-1') & t.vaultItemId.equals('item-push-2xm')))
          .get();
      expect(splitRows.length, 2);
      expect(splitRows.where((r) => !r.isProxy).single.quantity, 2);
      expect(splitRows.where((r) => r.isProxy).single.quantity, 2);
    });

    test('Zone isolation: Swapping does NOT merge rows across different board zones', () async {
      await db.into(db.decks).insert(DecksCompanion.insert(
        id: 'deck-zone-iso',
        name: 'Zone Isolation Deck',
        format: 'Modern',
        createdAt: DateTime.now(),
      ));

      await db.into(db.deckVersions).insert(DeckVersionsCompanion.insert(
        id: 'v-zone-iso',
        deckId: 'deck-zone-iso',
        versionNumber: 1,
        isActive: const drift.Value(true),
        createdAt: DateTime.now(),
      ));

      await db.into(db.vaultItems).insert(VaultItemsCompanion.insert(
        id: 'item-thoughtseize-ths',
        collectionType: 'mtg',
        name: 'Thoughtseize',
        setOrSeries: 'THS',
        imageUrl: 'https://example.com/ths.jpg',
        acquiredPrice: 15.0,
        acquiredDate: DateTime.now(),
        quantity: const drift.Value(4),
        condition: 'NM',
        currentMarketPrice: 15.00,
        lastPriceUpdate: DateTime.now(),
        dynamicData: '{}',
      ));

      await db.into(db.vaultItems).insert(VaultItemsCompanion.insert(
        id: 'item-thoughtseize-lrw',
        collectionType: 'mtg',
        name: 'Thoughtseize',
        setOrSeries: 'LRW',
        imageUrl: 'https://example.com/lrw.jpg',
        acquiredPrice: 30.0,
        acquiredDate: DateTime.now(),
        quantity: const drift.Value(4),
        condition: 'NM',
        currentMarketPrice: 30.00,
        lastPriceUpdate: DateTime.now(),
        dynamicData: '{}',
      ));

      // Add THS to Sideboard (qty 2) and LRW to Mainboard (qty 3)
      await db.vaultDao.addCardToDeck('deck-zone-iso', 'item-thoughtseize-ths', quantity: 2, boardZone: 'Sideboard');
      await db.vaultDao.addCardToDeck('deck-zone-iso', 'item-thoughtseize-lrw', quantity: 3, boardZone: 'Mainboard');

      final sideDvi = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals('v-zone-iso') & t.boardZone.equals('Sideboard')))
          .getSingle();

      // Swap THS in Sideboard to LRW
      await db.vaultDao.swapDeckItemPrinting(sideDvi.id, 'item-thoughtseize-lrw');

      // Verify that Sideboard and Mainboard stay separate rows
      final allLrwRows = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals('v-zone-iso') & t.vaultItemId.equals('item-thoughtseize-lrw')))
          .get();
      expect(allLrwRows.length, 2, reason: 'Mainboard and Sideboard must not be merged together');

      final mbRow = allLrwRows.singleWhere((r) => r.boardZone == 'Mainboard');
      final sbRow = allLrwRows.singleWhere((r) => r.boardZone == 'Sideboard');
      expect(mbRow.quantity, 3);
      expect(sbRow.quantity, 2);

      // Verify subsequent zone-specific mutations
      await db.vaultDao.setCardQuantityInDeck('deck-zone-iso', 'item-thoughtseize-lrw', 4, boardZone: 'Sideboard');
      final updatedSb = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals('v-zone-iso') & t.boardZone.equals('Sideboard')))
          .getSingle();
      expect(updatedSb.quantity, 4);

      final untouchedMb = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals('v-zone-iso') & t.boardZone.equals('Mainboard')))
          .getSingle();
      expect(untouchedMb.quantity, 3);
    });

    test('Proxy status isolation and proxy-to-proxy collision merging', () async {
      await db.into(db.decks).insert(DecksCompanion.insert(
        id: 'deck-proxy-test',
        name: 'Proxy Isolation Deck',
        format: 'Commander',
        createdAt: DateTime.now(),
      ));

      await db.into(db.deckVersions).insert(DeckVersionsCompanion.insert(
        id: 'v-proxy-test',
        deckId: 'deck-proxy-test',
        versionNumber: 1,
        isActive: const drift.Value(true),
        createdAt: DateTime.now(),
      ));

      await db.into(db.vaultItems).insert(VaultItemsCompanion.insert(
        id: 'item-sol-a',
        collectionType: 'mtg',
        name: 'Sol Ring',
        setOrSeries: 'SET A',
        imageUrl: 'https://example.com/a.jpg',
        acquiredPrice: 2.0,
        acquiredDate: DateTime.now(),
        quantity: const drift.Value(1),
        condition: 'NM',
        currentMarketPrice: 2.00,
        lastPriceUpdate: DateTime.now(),
        dynamicData: '{}',
      ));

      await db.into(db.vaultItems).insert(VaultItemsCompanion.insert(
        id: 'item-sol-b',
        collectionType: 'mtg',
        name: 'Sol Ring',
        setOrSeries: 'SET B',
        imageUrl: 'https://example.com/b.jpg',
        acquiredPrice: 5.0,
        acquiredDate: DateTime.now(),
        quantity: const drift.Value(1),
        condition: 'NM',
        currentMarketPrice: 5.00,
        lastPriceUpdate: DateTime.now(),
        dynamicData: '{}',
      ));

      // Row 1: Physical item A
      await db.vaultDao.addCardToDeck('deck-proxy-test', 'item-sol-a', quantity: 1, isProxy: false);
      // Row 2: Proxy item B
      await db.vaultDao.addCardToDeck('deck-proxy-test', 'item-sol-b', quantity: 1, isProxy: true);

      final physicalA = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals('v-proxy-test') & t.vaultItemId.equals('item-sol-a')))
          .getSingle();

      // Swap physical item A to item B
      // Should NOT merge with existing proxy item B because isProxy differs
      await db.vaultDao.swapDeckItemPrinting(physicalA.id, 'item-sol-b');

      final itemsB = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals('v-proxy-test') & t.vaultItemId.equals('item-sol-b')))
          .get();
      expect(itemsB.length, 2, reason: 'Physical and Proxy rows for same item must coexist without collision');
      expect(itemsB.where((r) => !r.isProxy).length, 1);
      expect(itemsB.where((r) => r.isProxy).length, 1);

      // Now add a 3rd item C as a proxy
      await db.into(db.vaultItems).insert(VaultItemsCompanion.insert(
        id: 'item-sol-c',
        collectionType: 'mtg',
        name: 'Sol Ring',
        setOrSeries: 'SET C',
        imageUrl: 'https://example.com/c.jpg',
        acquiredPrice: 10.0,
        acquiredDate: DateTime.now(),
        quantity: const drift.Value(1),
        condition: 'NM',
        currentMarketPrice: 10.00,
        lastPriceUpdate: DateTime.now(),
        dynamicData: '{}',
      ));

      await db.vaultDao.addCardToDeck('deck-proxy-test', 'item-sol-c', quantity: 2, isProxy: true);
      final proxyC = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals('v-proxy-test') & t.vaultItemId.equals('item-sol-c')))
          .getSingle();

      // Swap proxy item C to item B -> Collision with existing PROXY item B!
      await db.vaultDao.swapDeckItemPrinting(proxyC.id, 'item-sol-b');

      final updatedItemsB = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals('v-proxy-test') & t.vaultItemId.equals('item-sol-b')))
          .get();
      expect(updatedItemsB.length, 2, reason: '1 physical row + 1 merged proxy row');
      final mergedProxyB = updatedItemsB.singleWhere((r) => r.isProxy);
      expect(mergedProxyB.quantity, 3, reason: 'Initial proxy qty 1 + swapped proxy qty 2 = 3');
    });

    test('Deck history dynamicData sync across multi-deck lifecycle and metadata preservation', () async {
      await db.into(db.decks).insert(DecksCompanion.insert(
        id: 'deck-one',
        name: 'Pioneer Spirits',
        format: 'Pioneer',
        createdAt: DateTime.now(),
      ));

      await db.into(db.decks).insert(DecksCompanion.insert(
        id: 'deck-two',
        name: 'Modern Humans',
        format: 'Modern',
        createdAt: DateTime.now(),
      ));

      await db.into(db.deckVersions).insert(DeckVersionsCompanion.insert(
        id: 'v-one',
        deckId: 'deck-one',
        versionNumber: 1,
        isActive: const drift.Value(true),
        createdAt: DateTime.now(),
      ));

      await db.into(db.deckVersions).insert(DeckVersionsCompanion.insert(
        id: 'v-two',
        deckId: 'deck-two',
        versionNumber: 1,
        isActive: const drift.Value(true),
        createdAt: DateTime.now(),
      ));

      // Item Alpha (in both decks initially)
      await db.into(db.vaultItems).insert(VaultItemsCompanion.insert(
        id: 'item-cavern-a',
        collectionType: 'mtg',
        name: 'Cavern of Souls',
        setOrSeries: 'AVR',
        imageUrl: 'https://example.com/avr.jpg',
        acquiredPrice: 60.0,
        acquiredDate: DateTime.now(),
        quantity: const drift.Value(4),
        condition: 'NM',
        currentMarketPrice: 60.00,
        lastPriceUpdate: DateTime.now(),
        dynamicData: '{"oracle_id": "cavern-oracle", "custom_note": "original print"}',
      ));

      // Item Beta (in no decks initially)
      await db.into(db.vaultItems).insert(VaultItemsCompanion.insert(
        id: 'item-cavern-b',
        collectionType: 'mtg',
        name: 'Cavern of Souls',
        setOrSeries: 'UMA',
        imageUrl: 'https://example.com/uma.jpg',
        acquiredPrice: 50.0,
        acquiredDate: DateTime.now(),
        quantity: const drift.Value(4),
        condition: 'NM',
        currentMarketPrice: 50.00,
        lastPriceUpdate: DateTime.now(),
        dynamicData: '{"oracle_id": "cavern-oracle", "custom_note": "box topper"}',
      ));

      // Add Cavern A to Deck One and Deck Two
      await db.vaultDao.addCardToDeck('deck-one', 'item-cavern-a', quantity: 2);
      await db.vaultDao.addCardToDeck('deck-two', 'item-cavern-a', quantity: 4);

      var a = await db.vaultDao.getItemById('item-cavern-a');
      var dynA = jsonDecode(a!.dynamicData) as Map<String, dynamic>;
      var histA = (dynA['deck_history'] as List).cast<String>();
      expect(histA, containsAll(['Pioneer Spirits', 'Modern Humans']));
      expect(dynA['custom_note'], 'original print');

      // Swap Cavern A in Deck One to Cavern B
      final dviOne = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals('v-one') & t.vaultItemId.equals('item-cavern-a')))
          .getSingle();

      await db.vaultDao.swapDeckItemPrinting(dviOne.id, 'item-cavern-b');

      // Check Item A: must still have Modern Humans, but NOT Pioneer Spirits
      a = await db.vaultDao.getItemById('item-cavern-a');
      dynA = jsonDecode(a!.dynamicData) as Map<String, dynamic>;
      histA = (dynA['deck_history'] as List).cast<String>();
      expect(histA, contains('Modern Humans'));
      expect(histA.contains('Pioneer Spirits'), isFalse);
      expect(dynA['custom_note'], 'original print', reason: 'dynamicData metadata must not be wiped');

      // Check Item B: must now have Pioneer Spirits
      var b = await db.vaultDao.getItemById('item-cavern-b');
      var dynB = jsonDecode(b!.dynamicData) as Map<String, dynamic>;
      var histB = (dynB['deck_history'] as List).cast<String>();
      expect(histB, contains('Pioneer Spirits'));
      expect(histB.contains('Modern Humans'), isFalse);
      expect(dynB['custom_note'], 'box topper', reason: 'dynamicData metadata must not be wiped');

      // Now swap Cavern A in Deck Two to Cavern B as well
      final dviTwo = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals('v-two') & t.vaultItemId.equals('item-cavern-a')))
          .getSingle();

      await db.vaultDao.swapDeckItemPrinting(dviTwo.id, 'item-cavern-b');

      // Item A is now in 0 decks -> deck_history must be empty
      a = await db.vaultDao.getItemById('item-cavern-a');
      dynA = jsonDecode(a!.dynamicData) as Map<String, dynamic>;
      histA = (dynA['deck_history'] as List).cast<String>();
      expect(histA.isEmpty, isTrue);

      // Item B is now in both decks -> deck_history must contain both
      b = await db.vaultDao.getItemById('item-cavern-b');
      dynB = jsonDecode(b!.dynamicData) as Map<String, dynamic>;
      histB = (dynB['deck_history'] as List).cast<String>();
      expect(histB, containsAll(['Pioneer Spirits', 'Modern Humans']));
    });

    test('Self-swap and missing DVI edge cases execute idempotently without side-effects', () async {
      await db.into(db.decks).insert(DecksCompanion.insert(
        id: 'deck-noop',
        name: 'Noop Deck',
        format: 'Standard',
        createdAt: DateTime.now(),
      ));

      await db.into(db.deckVersions).insert(DeckVersionsCompanion.insert(
        id: 'v-noop',
        deckId: 'deck-noop',
        versionNumber: 1,
        isActive: const drift.Value(true),
        createdAt: DateTime.now(),
      ));

      await db.into(db.vaultItems).insert(VaultItemsCompanion.insert(
        id: 'item-noop-1',
        collectionType: 'mtg',
        name: 'Island',
        setOrSeries: 'UNF',
        imageUrl: 'https://example.com/unf.jpg',
        acquiredPrice: 1.0,
        acquiredDate: DateTime.now(),
        quantity: const drift.Value(10),
        condition: 'NM',
        currentMarketPrice: 1.00,
        lastPriceUpdate: DateTime.now(),
        dynamicData: '{}',
      ));

      await db.vaultDao.addCardToDeck('deck-noop', 'item-noop-1', quantity: 5);
      final dvi = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals('v-noop')))
          .getSingle();

      // 1. Missing DVI id call: does not throw
      await db.vaultDao.swapDeckItemPrinting('non-existent-dvi', 'item-noop-1');

      // 2. Self swap: oldVaultItemId == newVaultItemId
      await db.vaultDao.swapDeckItemPrinting(dvi.id, 'item-noop-1');

      final dviAfter = await (db.select(db.deckVersionItems)
            ..where((t) => t.id.equals(dvi.id)))
          .getSingle();
      expect(dviAfter.quantity, 5);
      expect(dviAfter.vaultItemId, 'item-noop-1');
    });
  });
}
