import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late VaultDao dao;
  const uuid = Uuid();

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dao = db.vaultDao;
    await dao.clearAllItems();
  });

  tearDown(() async {
    await db.close();
  });

  Future<String> createVaultCard({
    required String id,
    required String name,
    int quantity = 4,
  }) async {
    final now = DateTime.now();
    await db.into(db.vaultItems).insert(
      VaultItemsCompanion(
        id: drift.Value(id),
        collectionType: const drift.Value('mtg'),
        name: drift.Value(name),
        setOrSeries: const drift.Value('LTR'),
        imageUrl: drift.Value('https://cards.scryfall.io/art_crop/$id.jpg'),
        currentMarketPrice: const drift.Value(5.0),
        acquiredPrice: const drift.Value(4.0),
        acquiredDate: drift.Value(now),
        lastPriceUpdate: drift.Value(now),
        condition: const drift.Value('NM'),
        quantity: drift.Value(quantity),
        isDeleted: const drift.Value(false),
        dynamicData: const drift.Value('{"color_identity":["U"]}'),
      ),
    );
    return id;
  }

  Future<({String deckId, String versionId})> createDeckWithVersion({
    required String deckId,
    required String name,
  }) async {
    final now = DateTime.now();
    await db.into(db.decks).insert(
      DecksCompanion(
        id: drift.Value(deckId),
        name: drift.Value(name),
        format: const drift.Value('Commander'),
        tcgDomain: const drift.Value('mtg'),
        isRegistered: const drift.Value(true),
        isAssembled: const drift.Value(true),
        isCompetitive: const drift.Value(false),
        isDeleted: const drift.Value(false),
        createdAt: drift.Value(now),
      ),
    );
    final versionId = 'ver_$deckId';
    await db.into(db.deckVersions).insert(
      DeckVersionsCompanion(
        id: drift.Value(versionId),
        deckId: drift.Value(deckId),
        versionNumber: const drift.Value(1),
        isActive: const drift.Value(true),
        createdAt: drift.Value(now),
        isDeleted: const drift.Value(false),
      ),
    );
    return (deckId: deckId, versionId: versionId);
  }

  Future<String> addCardToDeckVersion({
    required String versionId,
    required String vaultItemId,
    required String boardZone,
    int quantity = 1,
    bool isProxy = false,
  }) async {
    final dviId = uuid.v4();
    final now = DateTime.now();
    await db.into(db.deckVersionItems).insert(
      DeckVersionItemsCompanion(
        id: drift.Value(dviId),
        versionId: drift.Value(versionId),
        vaultItemId: drift.Value(vaultItemId),
        quantity: drift.Value(quantity),
        boardZone: drift.Value(boardZone),
        isProxy: drift.Value(isProxy),
        isDeleted: const drift.Value(false),
        updatedAt: drift.Value(now),
      ),
    );
    return dviId;
  }

  group('Milestone 2 Reviewer Adversarial Edge Case Verification', () {
    test('Edge Case 1: null, empty, and whitespace sourceBoard resolve candidate properly', () async {
      final deck = await createDeckWithVersion(deckId: 'deck-ec1', name: 'EC1 Deck');
      final cardId = await createVaultCard(id: 'card-ec1', name: 'Sol Ring', quantity: 4);

      // Card is in Sideboard
      final dviId = await addCardToDeckVersion(
        versionId: deck.versionId,
        vaultItemId: cardId,
        boardZone: 'Sideboard',
        quantity: 3,
      );

      // 1. null sourceBoard with row ID -> moves from Sideboard to Mainboard
      await dao.moveDeckItemBoard(deck.deckId, dviId, 'Mainboard', 1, null);
      var items = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals(deck.versionId) & t.isDeleted.equals(false)))
          .get();
      expect(items.firstWhere((i) => i.boardZone == 'Sideboard').quantity, equals(2));
      expect(items.firstWhere((i) => i.boardZone == 'Mainboard').quantity, equals(1));

      // 2. empty string sourceBoard with cardId -> moves from Sideboard to Mainboard
      await dao.moveDeckItemBoard(deck.deckId, cardId, 'Mainboard', 1, '');
      items = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals(deck.versionId) & t.isDeleted.equals(false)))
          .get();
      expect(items.firstWhere((i) => i.boardZone == 'Sideboard').quantity, equals(1));
      expect(items.firstWhere((i) => i.boardZone == 'Mainboard').quantity, equals(2));

      // 3. whitespace string sourceBoard with cardId -> moves from Sideboard to Mainboard
      await dao.moveDeckItemBoard(deck.deckId, cardId, 'Mainboard', 1, '   \t \n  ');
      items = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals(deck.versionId) & t.isDeleted.equals(false)))
          .get();
      expect(items.any((i) => i.boardZone == 'Sideboard' && !i.isDeleted), isFalse);
      expect(items.firstWhere((i) => i.boardZone == 'Mainboard').quantity, equals(3));
    });

    test('Edge Case 2: non-existent deckId, itemId, or versionId executes safely without throwing', () async {
      final deck = await createDeckWithVersion(deckId: 'deck-ec2', name: 'EC2 Deck');
      final cardId = await createVaultCard(id: 'card-ec2', name: 'Arcane Signet', quantity: 2);
      final dviId = await addCardToDeckVersion(
        versionId: deck.versionId,
        vaultItemId: cardId,
        boardZone: 'Mainboard',
        quantity: 2,
      );

      // 1. Non-existent deckId
      await expectLater(
        dao.moveDeckItemBoard('non-existent-deck', dviId, 'Sideboard', 1),
        completes,
      );

      // 2. Non-existent itemId
      await expectLater(
        dao.moveDeckItemBoard(deck.deckId, 'non-existent-item', 'Sideboard', 1),
        completes,
      );

      // Verify no changes occurred
      final items = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals(deck.versionId) & t.isDeleted.equals(false)))
          .get();
      expect(items.length, equals(1));
      expect(items.first.quantity, equals(2));
      expect(items.first.boardZone, equals('Mainboard'));
    });

    test('Edge Case 3: already-matching target board is a strict no-op with zero sync rows added', () async {
      final deck = await createDeckWithVersion(deckId: 'deck-ec3', name: 'EC3 Deck');
      final cardId = await createVaultCard(id: 'card-ec3', name: 'Demonic Tutor', quantity: 1);
      final dviId = await addCardToDeckVersion(
        versionId: deck.versionId,
        vaultItemId: cardId,
        boardZone: 'Sideboard',
        quantity: 1,
      );

      final initialSyncCount = (await db.select(db.syncQueue).get()).length;

      // Target board is 'sideboard', card is already in 'Sideboard'
      await dao.moveDeckItemBoard(deck.deckId, dviId, 'sideboard', 1, 'Sideboard');
      await dao.moveDeckItemBoard(deck.deckId, dviId, 'Side', 1);
      await dao.moveDeckItemBoard(deck.deckId, dviId, 'sb', 1);

      final finalSyncCount = (await db.select(db.syncQueue).get()).length;
      expect(finalSyncCount, equals(initialSyncCount), reason: 'No sync queue entries on no-op');

      final items = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals(deck.versionId) & t.isDeleted.equals(false)))
          .get();
      expect(items.length, equals(1));
      expect(items.first.quantity, equals(1));
      expect(items.first.boardZone, equals('Sideboard'));
    });

    test('Edge Case 4: partial quantity moves and multi-step moves preserve conservation of quantity', () async {
      final deck = await createDeckWithVersion(deckId: 'deck-ec4', name: 'EC4 Deck');
      final cardId = await createVaultCard(id: 'card-ec4', name: 'Island', quantity: 10);
      final dviId = await addCardToDeckVersion(
        versionId: deck.versionId,
        vaultItemId: cardId,
        boardZone: 'Mainboard',
        quantity: 10,
      );

      // Move 3 of 10 to Sideboard
      await dao.moveDeckItemBoard(deck.deckId, dviId, 'Sideboard', 3);
      var items = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals(deck.versionId) & t.isDeleted.equals(false)))
          .get();
      expect(items.firstWhere((i) => i.boardZone == 'Mainboard').quantity, equals(7));
      expect(items.firstWhere((i) => i.boardZone == 'Sideboard').quantity, equals(3));

      // Move 4 of 7 to Maybeboard
      await dao.moveDeckItemBoard(deck.deckId, dviId, 'Maybeboard', 4);
      items = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals(deck.versionId) & t.isDeleted.equals(false)))
          .get();
      expect(items.firstWhere((i) => i.boardZone == 'Mainboard').quantity, equals(3));
      expect(items.firstWhere((i) => i.boardZone == 'Sideboard').quantity, equals(3));
      expect(items.firstWhere((i) => i.boardZone == 'Maybeboard').quantity, equals(4));

      // Move 2 of 3 from Sideboard to Maybeboard (consolidation)
      final sideItem = items.firstWhere((i) => i.boardZone == 'Sideboard');
      await dao.moveDeckItemBoard(deck.deckId, sideItem.id, 'Maybeboard', 2);
      items = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals(deck.versionId) & t.isDeleted.equals(false)))
          .get();
      expect(items.firstWhere((i) => i.boardZone == 'Mainboard').quantity, equals(3));
      expect(items.firstWhere((i) => i.boardZone == 'Sideboard').quantity, equals(1));
      expect(items.firstWhere((i) => i.boardZone == 'Maybeboard').quantity, equals(6));

      // Total must still strictly be 10
      final totalQty = items.fold<int>(0, (sum, i) => sum + i.quantity);
      expect(totalQty, equals(10));
    });

    test('Edge Case 5: soft-deletes and SyncQueue DELETE records when all copies are moved into existing target', () async {
      final deck = await createDeckWithVersion(deckId: 'deck-ec5', name: 'EC5 Deck');
      final cardId = await createVaultCard(id: 'card-ec5', name: 'Counterspell', quantity: 2);
      await addCardToDeckVersion(
        versionId: deck.versionId,
        vaultItemId: cardId,
        boardZone: 'Mainboard',
        quantity: 1,
      );
      final sideDviId = await addCardToDeckVersion(
        versionId: deck.versionId,
        vaultItemId: cardId,
        boardZone: 'Sideboard',
        quantity: 1,
      );

      // Move the 1 copy from Sideboard into Mainboard (where Mainboard already exists)
      await dao.moveDeckItemBoard(deck.deckId, sideDviId, 'Mainboard', 1);

      // Active items in deck should now have only 1 row (Mainboard with quantity 2)
      final activeItems = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals(deck.versionId) & t.isDeleted.equals(false)))
          .get();
      expect(activeItems.length, equals(1));
      expect(activeItems.first.boardZone, equals('Mainboard'));
      expect(activeItems.first.quantity, equals(2));

      // Sideboard row must be soft-deleted in SQLite
      final allItems = await (db.select(db.deckVersionItems)
            ..where((t) => t.id.equals(sideDviId)))
          .getSingle();
      expect(allItems.isDeleted, isTrue);

      // SyncQueue must contain a DELETE record for sideDviId
      final syncEntries = await (db.select(db.syncQueue)
            ..where((t) => t.entityId.equals(sideDviId)))
          .get();
      expect(syncEntries.any((s) => s.operation == 'DELETE'), isTrue);
    });

    test('Edge Case 6: proxy card and physical card isolation is strictly maintained across board moves', () async {
      final deck = await createDeckWithVersion(deckId: 'deck-ec6', name: 'EC6 Deck');
      final cardId = await createVaultCard(id: 'card-ec6', name: 'Mana Crypt', quantity: 2);
      final physDvi = await addCardToDeckVersion(
        versionId: deck.versionId,
        vaultItemId: cardId,
        boardZone: 'Mainboard',
        quantity: 1,
        isProxy: false,
      );
      await addCardToDeckVersion(
        versionId: deck.versionId,
        vaultItemId: cardId,
        boardZone: 'Sideboard',
        quantity: 1,
        isProxy: true,
      );

      // Move physical card to Sideboard
      await dao.moveDeckItemBoard(deck.deckId, physDvi, 'Sideboard', 1);

      // Sideboard should now contain 2 separate rows: 1 physical, 1 proxy
      final activeItems = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals(deck.versionId) & t.isDeleted.equals(false)))
          .get();
      expect(activeItems.length, equals(2));
      final physItem = activeItems.firstWhere((i) => !i.isProxy);
      final proxyItem = activeItems.firstWhere((i) => i.isProxy);

      expect(physItem.boardZone, equals('Sideboard'));
      expect(physItem.quantity, equals(1));
      expect(proxyItem.boardZone, equals('Sideboard'));
      expect(proxyItem.quantity, equals(1));
    });

    test('Edge Case 7: hostile and malicious board inputs do not cause SQL injection or invalid state', () async {
      final deck = await createDeckWithVersion(deckId: 'deck-ec7', name: 'EC7 Deck');
      final cardId = await createVaultCard(id: 'card-ec7', name: 'Force of Will', quantity: 2);
      final dviId = await addCardToDeckVersion(
        versionId: deck.versionId,
        vaultItemId: cardId,
        boardZone: 'Sideboard',
        quantity: 2,
      );

      final hostileStrings = [
        "'; DROP TABLE deck_version_items; --",
        "' OR '1'='1",
        '<script>alert(1)</script>',
        '🤖💀🔥✨',
        'cOmMaNdEr',
        'sIdEbOaRd',
        'mAyBeBoArD',
        'UNKNOWN_ZONE_XYZ_123',
      ];

      for (final hostile in hostileStrings) {
        // Should complete safely without exception or table corruption
        await expectLater(
          dao.moveDeckItemBoard(deck.deckId, dviId, hostile, 1),
          completes,
        );
      }

      // Verify table still exists and data is intact
      final allItems = await db.select(db.deckVersionItems).get();
      expect(allItems.isNotEmpty, isTrue);
    });
  });
}
