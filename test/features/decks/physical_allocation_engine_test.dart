import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/domain/models/board_zone.dart';

void main() {
  group('Milestone 1: Physical Allocation Engine & Deck Architecture Tests', () {
    late AppDatabase db;

    setUpAll(() {
      drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    });

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await db.vaultDao.clearAllItems();
    });

    tearDown(() async {
      await db.close();
    });

    /// Helper to insert a physical card in the vault
    Future<VaultItem> seedVaultCard({
      required String id,
      required String name,
      int quantity = 4,
      String collectionType = 'mtg',
      double price = 10.0,
    }) async {
      final companion = VaultItemsCompanion.insert(
        id: id,
        collectionType: collectionType,
        name: name,
        setOrSeries: 'Test Set',
        imageUrl: 'https://example.com/$id.jpg',
        acquiredPrice: price,
        acquiredDate: DateTime.now(),
        quantity: drift.Value(quantity),
        condition: 'NM',
        currentMarketPrice: price,
        lastPriceUpdate: DateTime.now(),
        dynamicData: jsonEncode({'name': name}),
      );
      await db.vaultDao.into(db.vaultItems).insert(companion);
      return (await (db.select(db.vaultItems)..where((t) => t.id.equals(id))).getSingle());
    }

    // =========================================================================
    // REQUIREMENT 1 & 4: Physical Allocation Engine (Draft vs Registered)
    // =========================================================================
    group('Physical Allocation Engine (getAvailableQuantity)', () {
      test('Initial state: Available quantity equals total vault quantity when unassigned', () async {
        final card = await seedVaultCard(id: 'card-sol-ring', name: 'Sol Ring', quantity: 3);
        final available = await db.vaultDao.getAvailableQuantity(card.id);
        expect(available, equals(3));
      });

      test('Requirement 1.a: Draft decks (is_registered == false) do NOT decrement available count', () async {
        final card = await seedVaultCard(id: 'card-sol-ring', name: 'Sol Ring', quantity: 2);

        // Create a draft deck (is_registered = false)
        final draftDeck = await db.vaultDao.createDeck(
          'Commander Draft 1',
          tcgDomain: 'mtg',
          isRegistered: false,
          isCompetitive: false,
        );

        // Add 1 physical copy to draft deck
        await db.vaultDao.addCardToDeck(
          draftDeck.id,
          card.id,
          isProxy: false,
          boardZone: 'Mainboard',
          quantity: 1,
        );

        // Verify available quantity is STILL 2 (draft does not lock physical stock)
        final available = await db.vaultDao.getAvailableQuantity(card.id);
        expect(available, equals(2), reason: 'Draft decks must not deduct physical inventory');
      });

      test('Requirement 1.b: Registered decks (is_registered == true) DO decrement available count', () async {
        final card = await seedVaultCard(id: 'card-sol-ring', name: 'Sol Ring', quantity: 2);

        // Create a registered deck (is_registered = true)
        final registeredDeck = await db.vaultDao.createDeck(
          'Tournament Deck',
          tcgDomain: 'mtg',
          isRegistered: true,
          isCompetitive: true,
        );

        // Add 1 physical copy to registered deck
        await db.vaultDao.addCardToDeck(
          registeredDeck.id,
          card.id,
          isProxy: false,
          boardZone: 'Mainboard',
          quantity: 1,
        );

        // Verify available quantity decrements to 1
        final available = await db.vaultDao.getAvailableQuantity(card.id);
        expect(available, equals(1), reason: 'Registered deck must decrement physical inventory');
      });

      test('Dynamic Toggle: Toggling is_registered reactively shifts available inventory', () async {
        final card = await seedVaultCard(id: 'card-mana-crypt', name: 'Mana Crypt', quantity: 1);

        final deck = await db.vaultDao.createDeck(
          'Flex Deck',
          tcgDomain: 'mtg',
          isRegistered: false,
        );

        await db.vaultDao.addCardToDeck(deck.id, card.id, quantity: 1);

        // While draft, available is 1
        expect(await db.vaultDao.getAvailableQuantity(card.id), equals(1));

        // Toggle to registered
        await db.vaultDao.setDeckRegistered(deck.id, true);
        expect(await db.vaultDao.getAvailableQuantity(card.id), equals(0));

        // Toggle back to draft
        await db.vaultDao.setDeckRegistered(deck.id, false);
        expect(await db.vaultDao.getAvailableQuantity(card.id), equals(1));
      });

      test('Proxy cards in registered decks do NOT decrement physical count', () async {
        final card = await seedVaultCard(id: 'card-lotus', name: 'Black Lotus', quantity: 1);

        final deck = await db.vaultDao.createDeck(
          'Vintage Deck With Proxy',
          tcgDomain: 'mtg',
          isRegistered: true,
        );

        // Add as proxy
        await db.vaultDao.addCardToDeck(
          deck.id,
          card.id,
          isProxy: true,
          quantity: 1,
        );

        final available = await db.vaultDao.getAvailableQuantity(card.id);
        expect(available, equals(1), reason: 'Proxies must never lock physical inventory');
      });

      test('Inactive deck versions do NOT decrement physical count even in registered deck', () async {
        final card = await seedVaultCard(id: 'card-bolt', name: 'Lightning Bolt', quantity: 4);

        final deck = await db.vaultDao.createDeck('Burn', isRegistered: true);

        // Manually insert an archived (inactive) version
        final v2Id = 'ver-burn-inactive';
        await db.into(db.deckVersions).insert(DeckVersionsCompanion.insert(
          id: v2Id,
          deckId: deck.id,
          versionNumber: 2,
          isActive: const drift.Value(false),
          createdAt: DateTime.now(),
        ));

        // Assign card to inactive version
        await db.into(db.deckVersionItems).insert(DeckVersionItemsCompanion.insert(
          id: 'dvi-inactive-1',
          versionId: v2Id,
          vaultItemId: card.id,
          quantity: const drift.Value(4),
          boardZone: 'Mainboard',
          isProxy: const drift.Value(false),
        ));

        // Should still have all 4 available
        final available = await db.vaultDao.getAvailableQuantity(card.id);
        expect(available, equals(4));
      });

      test('Multi-Deck Scenario: Registered deck locks copies, draft deck does not', () async {
        final card = await seedVaultCard(id: 'card-staple', name: 'Cyclonic Rift', quantity: 3);

        final regDeck = await db.vaultDao.createDeck('Active EDH', isRegistered: true);
        final draftDeck = await db.vaultDao.createDeck('Theorycraft EDH', isRegistered: false);

        await db.vaultDao.addCardToDeck(regDeck.id, card.id, quantity: 2);
        await db.vaultDao.addCardToDeck(draftDeck.id, card.id, quantity: 3);

        // Total owned: 3. Reg uses 2. Draft uses 3. Available = 3 - 2 = 1.
        final available = await db.vaultDao.getAvailableQuantity(card.id);
        expect(available, equals(1));
      });

      test('Over-allocation clamp: Never returns negative available quantity', () async {
        final card = await seedVaultCard(id: 'card-over', name: 'Overallocated Card', quantity: 1);
        final regDeck = await db.vaultDao.createDeck('Registered Deck', isRegistered: true);

        await db.vaultDao.addCardToDeck(regDeck.id, card.id, quantity: 3);

        final available = await db.vaultDao.getAvailableQuantity(card.id);
        expect(available, equals(0), reason: 'Available quantity must clamp at 0');
      });

      test('Non-existent vault item ID returns 0 available quantity', () async {
        final available = await db.vaultDao.getAvailableQuantity('non-existent-id');
        expect(available, equals(0));
      });
    });

    // =========================================================================
    // REQUIREMENT 2 & 3: Multi-Card Commander Zone Support
    // =========================================================================
    group('Multi-Card Commander Zone Support', () {
      test('Requirement 1.c: Multiple cards can be saved and retrieved in Commander zone without collision', () async {
        final commander1 = await seedVaultCard(id: 'c1', name: 'Thrasios, Triton Hero');
        final commander2 = await seedVaultCard(id: 'c2', name: 'Tymna the Weaver');

        final deck = await db.vaultDao.createDeck('Partner EDH', format: 'Commander');

        // Add both to Commander zone
        await db.vaultDao.addCardToDeck(
          deck.id,
          commander1.id,
          boardZone: 'Commander',
          quantity: 1,
        );
        await db.vaultDao.addCardToDeck(
          deck.id,
          commander2.id,
          boardZone: 'Commander',
          quantity: 1,
        );

        // Query active version items in Commander zone
        final version = await (db.select(db.deckVersions)
              ..where((t) => t.deckId.equals(deck.id) & t.isActive.equals(true)))
            .getSingle();

        final commanders = await (db.select(db.deckVersionItems)
              ..where((t) =>
                  t.versionId.equals(version.id) &
                  t.boardZone.equals('Commander')))
            .get();

        expect(commanders.length, equals(2));
        final ids = commanders.map((c) => c.vaultItemId).toSet();
        expect(ids, containsAll(['c1', 'c2']));
      });

      test('Same card can exist independently in Commander and Mainboard zones', () async {
        final card = await seedVaultCard(id: 'card-omnath', name: 'Omnath, Locus of Creation', quantity: 2);
        final deck = await db.vaultDao.createDeck('Omnath Deck');

        // Add to Commander
        await db.vaultDao.addCardToDeck(deck.id, card.id, boardZone: 'Commander', quantity: 1);
        // Add to Mainboard
        await db.vaultDao.addCardToDeck(deck.id, card.id, boardZone: 'Mainboard', quantity: 1);

        final version = await (db.select(db.deckVersions)
              ..where((t) => t.deckId.equals(deck.id) & t.isActive.equals(true)))
            .getSingle();

        final allItems = await (db.select(db.deckVersionItems)
              ..where((t) => t.versionId.equals(version.id)))
            .get();

        expect(allItems.length, equals(2));
        expect(allItems.any((i) => i.boardZone == 'Commander' && i.quantity == 1), isTrue);
        expect(allItems.any((i) => i.boardZone == 'Mainboard' && i.quantity == 1), isTrue);
      });

      test('Adding existing card to same zone increments quantity instead of creating duplicate', () async {
        final card = await seedVaultCard(id: 'card-swamp', name: 'Swamp', quantity: 20);
        final deck = await db.vaultDao.createDeck('Mono Black');

        await db.vaultDao.addCardToDeck(deck.id, card.id, boardZone: 'Mainboard', quantity: 2);
        await db.vaultDao.addCardToDeck(deck.id, card.id, boardZone: 'Mainboard', quantity: 3);

        final version = await (db.select(db.deckVersions)
              ..where((t) => t.deckId.equals(deck.id) & t.isActive.equals(true)))
            .getSingle();

        final items = await (db.select(db.deckVersionItems)
              ..where((t) => t.versionId.equals(version.id)))
            .get();

        expect(items.length, equals(1));
        expect(items.first.quantity, equals(5));
      });
    });

    // =========================================================================
    // REQUIREMENT 2.d: Companion Zone Storage & Retrieval
    // =========================================================================
    group('Companion Zone Storage & Retrieval', () {
      test('Requirement 1.d: Companion zone card storage and retrieval', () async {
        final companionCard = await seedVaultCard(
          id: 'card-lurrus',
          name: 'Lurrus of the Dream-Den',
          quantity: 1,
        );

        final deck = await db.vaultDao.createDeck('Lurrus Modern', format: 'Modern');

        await db.vaultDao.addCardToDeck(
          deck.id,
          companionCard.id,
          boardZone: 'Companion',
          quantity: 1,
        );

        final version = await (db.select(db.deckVersions)
              ..where((t) => t.deckId.equals(deck.id) & t.isActive.equals(true)))
            .getSingle();

        final companionItems = await (db.select(db.deckVersionItems)
              ..where((t) =>
                  t.versionId.equals(version.id) &
                  t.boardZone.equals('Companion')))
            .get();

        expect(companionItems.length, equals(1));
        expect(companionItems.first.vaultItemId, equals('card-lurrus'));
        expect(companionItems.first.boardZone, equals('Companion'));
      });

      test('Companion zone items decrement inventory when deck is registered', () async {
        final companionCard = await seedVaultCard(id: 'card-yorion', name: 'Yorion, Sky Nomad', quantity: 1);
        final deck = await db.vaultDao.createDeck('Yorion Blink', isRegistered: true);

        await db.vaultDao.addCardToDeck(deck.id, companionCard.id, boardZone: 'Companion', quantity: 1);

        final available = await db.vaultDao.getAvailableQuantity(companionCard.id);
        expect(available, equals(0));
      });

      test('BoardZone enum parses and serializes all 5 zones cleanly', () {
        expect(BoardZone.fromString('mainboard'), equals(BoardZone.mainboard));
        expect(BoardZone.fromString('Sideboard'), equals(BoardZone.sideboard));
        expect(BoardZone.fromString('MAYBEBOARD'), equals(BoardZone.maybeboard));
        expect(BoardZone.fromString('Commander'), equals(BoardZone.commander));
        expect(BoardZone.fromString('companion'), equals(BoardZone.companion));
        expect(BoardZone.fromString('Unknown'), equals(BoardZone.mainboard)); // fallback
      });
    });

    // =========================================================================
    // REQUIREMENT 5: Registration & Swap DAO Helpers
    // =========================================================================
    group('Deck Registration & Swap Helpers', () {
      test('createDeck initializes domain, registration, and competitive flags', () async {
        final deck = await db.vaultDao.createDeck(
          'Charizard Meta',
          tcgDomain: 'pokemon',
          isRegistered: true,
          isCompetitive: true,
          format: 'Standard',
        );

        expect(deck.name, equals('Charizard Meta'));
        expect(deck.tcgDomain, equals('pokemon'));
        expect(deck.isRegistered, isTrue);
        expect(deck.isCompetitive, isTrue);
        expect(deck.format, equals('Standard'));
      });

      test('setDeckCompetitive updates is_competitive flag', () async {
        final deck = await db.vaultDao.createDeck('Casual Deck', isCompetitive: false);
        expect(deck.isCompetitive, isFalse);

        await db.vaultDao.setDeckCompetitive(deck.id, true);
        final updated = await (db.select(db.decks)..where((t) => t.id.equals(deck.id))).getSingle();
        expect(updated.isCompetitive, isTrue);
      });

      test('swapDeckItemPrinting reassigns vault_item_id on deck item', () async {
        final printing1 = await seedVaultCard(id: 'p1', name: 'Sol Ring', collectionType: 'mtg');
        final printing2 = await seedVaultCard(id: 'p2', name: 'Sol Ring', collectionType: 'mtg');

        final deck = await db.vaultDao.createDeck('Swap Test');
        await db.vaultDao.addCardToDeck(deck.id, printing1.id);

        final version = await (db.select(db.deckVersions)
              ..where((t) => t.deckId.equals(deck.id) & t.isActive.equals(true)))
            .getSingle();

        final item = await (db.select(db.deckVersionItems)
              ..where((t) => t.versionId.equals(version.id)))
            .getSingle();

        expect(item.vaultItemId, equals('p1'));

        // Swap printing to p2
        await db.vaultDao.swapDeckItemPrinting(item.id, printing2.id);

        final updatedItem = await (db.select(db.deckVersionItems)
              ..where((t) => t.id.equals(item.id)))
            .getSingle();

        expect(updatedItem.vaultItemId, equals('p2'));
      });

      test('getAlternativePrintings retrieves all owned printings of the card name', () async {
        await seedVaultCard(id: 'bolt-m10', name: 'Lightning Bolt', quantity: 2);
        await seedVaultCard(id: 'bolt-clb', name: 'Lightning Bolt', quantity: 1);
        await seedVaultCard(id: 'bolt-unowned', name: 'Lightning Bolt', quantity: 0);
        await seedVaultCard(id: 'counterspell', name: 'Counterspell', quantity: 4);

        final alts = await db.vaultDao.getAlternativePrintings('Lightning Bolt');
        expect(alts.length, equals(2));
        final altIds = alts.map((a) => a.id).toSet();
        expect(altIds, containsAll(['bolt-m10', 'bolt-clb']));
        expect(altIds, isNot(contains('bolt-unowned')));
        expect(altIds, isNot(contains('counterspell')));
      });
    });

    // =========================================================================
    // REQUIREMENT 1.e: Schema Migration v6 -> v7 and beforeOpen Verification
    // =========================================================================
    group('Schema Migration (v6 -> v7) & beforeOpen Verification', () {
      test('Requirement 1.e: auto-patches legacy database missing tcg_domain, is_registered, is_competitive', () async {
        // 1. Initialize raw SQLite database with Schema v6 (without tcg_domain, is_registered, is_competitive)
        final rawDb = NativeDatabase.memory(setup: (raw) {
          raw.execute('''
            CREATE TABLE decks (
              id TEXT NOT NULL PRIMARY KEY,
              name TEXT NOT NULL,
              format TEXT NOT NULL,
              description TEXT,
              wins INTEGER NOT NULL DEFAULT 0,
              losses INTEGER NOT NULL DEFAULT 0,
              draws INTEGER NOT NULL DEFAULT 0,
              cover_item_id TEXT,
              cover_crop_rect TEXT,
              created_at INTEGER NOT NULL
            );
            CREATE TABLE deck_versions (
              id TEXT NOT NULL PRIMARY KEY,
              deck_id TEXT NOT NULL,
              version_number INTEGER NOT NULL,
              version_note TEXT,
              is_active INTEGER NOT NULL DEFAULT 1,
              created_at INTEGER NOT NULL
            );
            CREATE TABLE deck_version_items (
              id TEXT NOT NULL PRIMARY KEY,
              version_id TEXT NOT NULL,
              vault_item_id TEXT NOT NULL,
              quantity INTEGER NOT NULL DEFAULT 1,
              board_zone TEXT NOT NULL,
              is_proxy INTEGER NOT NULL DEFAULT 0
            );
            INSERT INTO decks VALUES (
              'legacy-deck-1', 'Legacy EDH Deck', 'Commander', 'Old deck notes',
              10, 4, 1, NULL, NULL, 1600000000
            );
          ''');
        });

        // 2. Open via AppDatabase (triggers onUpgrade from v6 to v7 and beforeOpen defensive PRAGMA checks)
        final migratedDb = AppDatabase(rawDb);

        // 3. Verify PRAGMA table_info("decks") contains new columns
        final tableInfo = await migratedDb.customSelect('PRAGMA table_info("decks");').get();
        final columns = tableInfo.map((r) => r.read<String>('name')).toSet();
        expect(columns, contains('tcg_domain'));
        expect(columns, contains('is_registered'));
        expect(columns, contains('is_competitive'));

        // 4. Verify existing record survived and received default values
        final legacyDeck = await (migratedDb.select(migratedDb.decks)
              ..where((t) => t.id.equals('legacy-deck-1')))
            .getSingle();

        expect(legacyDeck.name, equals('Legacy EDH Deck'));
        expect(legacyDeck.format, equals('Commander'));
        expect(legacyDeck.tcgDomain, equals('mtg'));
        expect(legacyDeck.isRegistered, isFalse);
        expect(legacyDeck.isCompetitive, isFalse);

        // 5. Verify writing updates to migrated columns works cleanly
        await migratedDb.vaultDao.setDeckRegistered(legacyDeck.id, true);
        await migratedDb.vaultDao.setDeckCompetitive(legacyDeck.id, true);

        final updated = await (migratedDb.select(migratedDb.decks)
              ..where((t) => t.id.equals('legacy-deck-1')))
            .getSingle();

        expect(updated.isRegistered, isTrue);
        expect(updated.isCompetitive, isTrue);

        await migratedDb.close();
      });
    });
  });
}
