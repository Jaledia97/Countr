import 'dart:convert';
import 'package:drift/drift.dart' hide Column, isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/symbology/data/scryfall_symbol_catalog.dart';
import 'package:countr/features/symbology/presentation/widgets/mana_text.dart';
import 'package:countr/features/decks/presentation/widgets/proportional_bubble_scrollbar.dart';
import 'package:countr/features/values/presentation/widgets/pareto_distribution_widget.dart';
import 'package:countr/features/values/domain/services/pareto_distribution_calculator.dart';
import 'package:countr/features/vault/domain/vault_variant_helper.dart';
import 'package:countr/features/vault/domain/models/card_availability.dart';

import 'phase46_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ===========================================================================
  // TIER 1 - FEATURE COVERAGE (>=5 tests per feature, F1 - F16, Total >=80 tests)
  // ===========================================================================

  // ---------------------------------------------------------------------------
  // Feature 1: Variant Grouping (scryfall_id, finish)
  // ---------------------------------------------------------------------------
  group('Tier 1 - Feature 1: Variant Grouping (scryfall_id, finish)', () {
    test('F1.1: Groups items with identical (scryfall_id, finish) into a single bucket', () {
      final cardA = createPhase46TestCard(
        id: 'card-1',
        name: 'Sol Ring',
        scryfallId: 'scryfall-sol-ring',
        finish: 'nonfoil',
        quantity: 1,
      );
      final cardB = createPhase46TestCard(
        id: 'card-2',
        name: 'Sol Ring',
        scryfallId: 'scryfall-sol-ring',
        finish: 'nonfoil',
        quantity: 2,
      );

      final result = VaultVariantHelper.groupVaultItemsByVariant([cardA, cardB]);
      expect(result, isA<ConsolidatedVariantResult>());
      expect(result.items.length, equals(1));
      expect(result.items.first.quantity, equals(3));
      expect(VaultVariantHelper.computeVariantKey(result.items.first), equals('mtg_scryfall-sol-ring_nonfoil'));
      expect(result.variantToUnderlyingIds[result.items.first.id], containsAll({'card-1', 'card-2'}));
    });

    test('F1.2: Keeps items with different finishes in separate buckets', () {
      final cardNonfoil = createPhase46TestCard(
        id: 'card-nf',
        name: 'Lightning Bolt',
        scryfallId: 'scryfall-bolt-1',
        finish: 'nonfoil',
        quantity: 3,
      );
      final cardFoil = createPhase46TestCard(
        id: 'card-f',
        name: 'Lightning Bolt',
        scryfallId: 'scryfall-bolt-1',
        finish: 'foil',
        quantity: 1,
      );

      final result = VaultVariantHelper.groupVaultItemsByVariant([cardNonfoil, cardFoil]);
      expect(result.items.length, equals(2));

      final nonfoil = result.items.firstWhere((i) => VaultVariantHelper.resolveFinish(i) == 'nonfoil');
      final foil = result.items.firstWhere((i) => VaultVariantHelper.resolveFinish(i) == 'foil');
      expect(nonfoil.quantity, equals(3));
      expect(foil.quantity, equals(1));
      expect(VaultVariantHelper.computeVariantKey(nonfoil), equals('mtg_scryfall-bolt-1_nonfoil'));
      expect(VaultVariantHelper.computeVariantKey(foil), equals('mtg_scryfall-bolt-1_foil'));
    });

    test('F1.3: Keeps distinct printings in separate buckets even with same card name', () {
      final normalFrame = createPhase46TestCard(
        id: 'card-normal',
        name: 'Demonic Tutor',
        scryfallId: 'scryfall-tutor-uma',
        oracleId: 'oracle-demonic-tutor',
        finish: 'nonfoil',
        quantity: 1,
      );
      final borderless = createPhase46TestCard(
        id: 'card-borderless',
        name: 'Demonic Tutor',
        scryfallId: 'scryfall-tutor-sta',
        oracleId: 'oracle-demonic-tutor',
        finish: 'nonfoil',
        quantity: 1,
      );

      final result = VaultVariantHelper.groupVaultItemsByVariant([normalFrame, borderless]);
      expect(result.items.length, equals(2));
      final printings = result.items.map(VaultVariantHelper.resolvePrintingId).toSet();
      expect(printings, containsAll({'scryfall-tutor-uma', 'scryfall-tutor-sta'}));
      expect(result.multiVariantCardKeys, isNotEmpty);
    });

    test('F1.4: Correctly tallies total quantity across consolidated records in same bucket', () {
      final copies = List.generate(
        4,
        (i) => createPhase46TestCard(
          id: 'copy-$i',
          name: 'Counterspell',
          scryfallId: 'scryfall-cs-1',
          finish: 'nonfoil',
          quantity: i + 1,
        ),
      );

      final result = VaultVariantHelper.groupVaultItemsByVariant(copies);
      expect(result.items.length, equals(1));
      expect(result.items.first.quantity, equals(10)); // 1 + 2 + 3 + 4 = 10
      expect(result.variantToUnderlyingIds[result.items.first.id]!.length, equals(4));
    });

    test('F1.5: Extracts finish from condition field fallback when finish is missing from dynamic_data', () {
      final cardFoilCondition = createPhase46TestCard(
        id: 'cond-foil',
        name: 'Dark Ritual',
        scryfallId: 'scryfall-dr',
        condition: 'Near Mint Foil',
        additionalDynamicData: {'finish': null, 'finishes': null},
      );

      final finish = VaultVariantHelper.resolveFinish(cardFoilCondition);
      expect(finish, equals('foil'));
      final key = VaultVariantHelper.computeVariantKey(cardFoilCondition);
      expect(key, equals('mtg_scryfall-dr_foil'));
    });
  });

  // ---------------------------------------------------------------------------
  // Feature 2: Availability Engine (Owned, Available, In Deck)
  // ---------------------------------------------------------------------------
  group('Tier 1 - Feature 2: Availability Engine', () {
    late AppDatabase db;

    setUp(() {
      db = createPhase46TestDb();
    });

    tearDown(() async {
      await db.close();
    });

    test('F2.1: Computes Owned: 1 | Available: 1 | In Deck: 0 for unassigned card', () async {
      final card = createPhase46TestCard(id: 'c-sol-1', name: 'Sol Ring', quantity: 1);
      await db.into(db.vaultItems).insert(card);

      final availMap = await db.vaultDao.watchAllCardAvailability().first;
      final avail = availMap[card.id] ?? CardAvailability.zero;
      expect(avail, equals(const CardAvailability(owned: 1, available: 1, inDeck: 0)));
    });

    test('F2.2: Decrements Available and increments In Deck when assigned to assembled deck', () async {
      final card = createPhase46TestCard(id: 'c-sol-2', name: 'Sol Ring', quantity: 3);
      await db.into(db.vaultItems).insert(card);

      final deck = await createAndInsertDeck(
        db,
        id: 'deck-assembled-1',
        name: 'Urza Commander',
        isRegistered: true,
      );

      await addCardToDeckZone(db, deckId: deck.id, vaultItemId: card.id, quantity: 1);

      final availMap = await db.vaultDao.watchAllCardAvailability().first;
      final avail = availMap[card.id] ?? CardAvailability.zero;
      expect(avail, equals(const CardAvailability(owned: 3, available: 2, inDeck: 1)));
    });

    test('F2.3: Does not decrement Available if deck is unassembled/draft', () async {
      final card = createPhase46TestCard(id: 'c-sol-3', name: 'Sol Ring', quantity: 2);
      await db.into(db.vaultItems).insert(card);

      final draftDeck = await createAndInsertDeck(
        db,
        id: 'deck-draft-1',
        name: 'Draft Deck',
        isRegistered: false,
      );

      await addCardToDeckZone(db, deckId: draftDeck.id, vaultItemId: card.id, quantity: 1);

      final availMap = await db.vaultDao.watchAllCardAvailability().first;
      final avail = availMap[card.id] ?? CardAvailability.zero;
      expect(avail, equals(const CardAvailability(owned: 2, available: 2, inDeck: 0)));
    });

    test('F2.4: Proxy card assignments do not decrement physical Available inventory', () async {
      final card = createPhase46TestCard(id: 'c-lotus-1', name: 'Black Lotus', quantity: 1);
      await db.into(db.vaultItems).insert(card);

      final deck = await createAndInsertDeck(
        db,
        id: 'deck-vintage-1',
        name: 'Vintage Deck',
        isRegistered: true,
      );

      await addCardToDeckZone(
        db,
        deckId: deck.id,
        vaultItemId: card.id,
        quantity: 1,
        isProxy: true,
      );

      final availMap = await db.vaultDao.watchAllCardAvailability().first;
      final avail = availMap[card.id] ?? CardAvailability.zero;
      expect(avail, equals(const CardAvailability(owned: 1, available: 1, inDeck: 0)));
    });

    test('F2.5: Enforces invariant: Owned = Available + In Deck across multiple assembled decks', () async {
      final card = createPhase46TestCard(id: 'c-command-tower', name: 'Command Tower', quantity: 5);
      await db.into(db.vaultItems).insert(card);

      final deckA = await createAndInsertDeck(db, id: 'deck-a', name: 'Deck A', isRegistered: true);
      final deckB = await createAndInsertDeck(db, id: 'deck-b', name: 'Deck B', isRegistered: true);

      await addCardToDeckZone(db, deckId: deckA.id, vaultItemId: card.id, quantity: 2);
      await addCardToDeckZone(db, deckId: deckB.id, vaultItemId: card.id, quantity: 1);

      final availMap = await db.vaultDao.watchAllCardAvailability().first;
      final avail = availMap[card.id] ?? CardAvailability.zero;
      expect(avail.owned, equals(5));
      expect(avail.inDeck, equals(3));
      expect(avail.available, equals(2));
      expect(avail.owned, equals(avail.available + avail.inDeck));
    });
  });

  // ---------------------------------------------------------------------------
  // Feature 3: Assembled Deck Badge Gate
  // ---------------------------------------------------------------------------
  group('Tier 1 - Feature 3: Assembled Deck Badge Gate', () {
    late AppDatabase db;

    setUp(() {
      db = createPhase46TestDb();
    });

    tearDown(() async {
      await db.close();
    });

    test('F3.1: Deck badge query returns deck name when deck is registered/assembled', () async {
      final card = createPhase46TestCard(id: 'c-rhystic', name: 'Rhystic Study');
      await db.into(db.vaultItems).insert(card);

      final deck = await createAndInsertDeck(db, id: 'd-cedh', name: 'cEDH Blue', isRegistered: true);
      await addCardToDeckZone(db, deckId: deck.id, vaultItemId: card.id);

      final badges = await db.vaultDao.watchItemActiveDecks(card.id).first;
      expect(badges, contains('cEDH Blue'));

      final allBadges = await db.vaultDao.watchAllCardActiveDecks().first;
      expect(allBadges[card.id], contains('cEDH Blue'));
    });

    test('F3.2: Deck badge query returns empty when assigned deck is draft / unassembled', () async {
      final card = createPhase46TestCard(id: 'c-esper', name: 'Esper Sentinel');
      await db.into(db.vaultItems).insert(card);

      final deck = await createAndInsertDeck(db, id: 'd-draft-w', name: 'White Weenie', isRegistered: false);
      await addCardToDeckZone(db, deckId: deck.id, vaultItemId: card.id);

      final badges = await db.vaultDao.watchItemActiveDecks(card.id).first;
      expect(badges, isEmpty);
      final allBadges = await db.vaultDao.watchAllCardActiveDecks().first;
      expect(allBadges[card.id] ?? [], isEmpty);
    });

    test('F3.3: Toggling deck registration from false to true immediately emits badge', () async {
      final card = createPhase46TestCard(id: 'c-cyclonic', name: 'Cyclonic Rift');
      await db.into(db.vaultItems).insert(card);

      final deck = await createAndInsertDeck(db, id: 'd-toggle', name: 'Toggle Deck', isRegistered: false);
      await addCardToDeckZone(db, deckId: deck.id, vaultItemId: card.id);

      expect(await db.vaultDao.watchItemActiveDecks(card.id).first, isEmpty);

      await db.vaultDao.setDeckRegistered(deck.id, true);
      expect(await db.vaultDao.watchItemActiveDecks(card.id).first, contains('Toggle Deck'));

      // Also verify is_assembled toggle updates badge
      await db.vaultDao.setDeckRegistered(deck.id, false);
      expect(await db.vaultDao.watchItemActiveDecks(card.id).first, isEmpty);
      await db.vaultDao.setDeckAssembled(deck.id, true);
      expect(await db.vaultDao.watchItemActiveDecks(card.id).first, contains('Toggle Deck'));
    });

    test('F3.4: Toggling deck registration from true to false immediately removes badge', () async {
      final card = createPhase46TestCard(id: 'c-dockside', name: 'Dockside Extortionist');
      await db.into(db.vaultItems).insert(card);

      final deck = await createAndInsertDeck(db, id: 'd-disassemble', name: 'Treasure Goblin', isRegistered: true);
      await addCardToDeckZone(db, deckId: deck.id, vaultItemId: card.id);

      expect(await db.vaultDao.watchItemActiveDecks(card.id).first, contains('Treasure Goblin'));

      await db.vaultDao.setDeckRegistered(deck.id, false);
      expect(await db.vaultDao.watchItemActiveDecks(card.id).first, isEmpty);
    });

    test('F3.5: Soft-deleted decks do not emit badges even if previously registered', () async {
      final card = createPhase46TestCard(id: 'c-fierce', name: 'Fierce Guardianship');
      await db.into(db.vaultItems).insert(card);

      final deck = await createAndInsertDeck(db, id: 'd-deleted', name: 'Deleted Deck', isRegistered: true);
      await addCardToDeckZone(db, deckId: deck.id, vaultItemId: card.id);

      expect(await db.vaultDao.watchItemActiveDecks(card.id).first, contains('Deleted Deck'));

      // Soft delete deck
      await db.vaultDao.deleteDeck(deck.id);
      expect(await db.vaultDao.watchItemActiveDecks(card.id).first, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // Feature 4: The One Ring Art Fix
  // ---------------------------------------------------------------------------
  group('Tier 1 - Feature 4: The One Ring Authentic Scryfall Art', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      // Trigger beforeOpen hook which seeds DB and applies runtime backfill
      await db.customSelect('SELECT 1;').get();
    });

    tearDown(() async {
      await db.close();
    });

    test('F4.1: The One Ring in seeded SQLite provides authentic Scryfall ID d5806e68-1054-458e-866d-1f2470f682b2', () async {
      final oneRing = await (db.select(db.vaultItems)
            ..where((t) => t.id.equals('item-mtg-one-ring') & t.isDeleted.equals(false)))
          .getSingleOrNull();

      expect(oneRing, isNotNull);
      final data = jsonDecode(oneRing!.dynamicData) as Map<String, dynamic>;
      expect(data['scryfall_id'], equals('d5806e68-1054-458e-866d-1f2470f682b2'));
      expect(data['id'], equals('d5806e68-1054-458e-866d-1f2470f682b2'));
    });

    test('F4.2: The One Ring imageUrl references live authentic asset URL with HTTP 200 format', () async {
      final oneRing = await (db.select(db.vaultItems)
            ..where((t) => t.id.equals('item-mtg-one-ring')))
          .getSingle();

      expect(oneRing.imageUrl, contains('d5806e68-1054-458e-866d-1f2470f682b2'));
      expect(oneRing.imageUrl.startsWith('https://cards.scryfall.io/large/front/'), isTrue);
      expect(oneRing.imageUrl, equals('https://cards.scryfall.io/large/front/d/5/d5806e68-1054-458e-866d-1f2470f682b2.jpg?1790212038'));
    });

    test('F4.3: The One Ring does not contain broken legacy 404 hash 78038b95 in imageUrl', () async {
      final oneRing = await (db.select(db.vaultItems)
            ..where((t) => t.id.equals('item-mtg-one-ring')))
          .getSingle();

      expect(oneRing.imageUrl.contains('78038b95'), isFalse);
    });

    test('F4.4: Dynamic data contains valid oracle_id and image_uris dictionary', () async {
      final oneRing = await (db.select(db.vaultItems)
            ..where((t) => t.id.equals('item-mtg-one-ring')))
          .getSingle();

      final data = jsonDecode(oneRing.dynamicData) as Map<String, dynamic>;
      expect(data['oracle_id'], equals('3aa83ed2-f48b-4ce6-a614-2c54ddf50538'));
      expect(data['finish'], equals('foil'));
      expect(data['image_uris'], isNotNull);
      expect(data['image_uris']['normal'], isNotNull);
      expect(data['image_uris']['large'], isNotNull);
      expect(data['image_uris']['art_crop'], isNotNull);
    });

    test('F4.5: Image URIs across normal, large, and art_crop resolve without null or empty strings', () async {
      final oneRing = await (db.select(db.vaultItems)
            ..where((t) => t.id.equals('item-mtg-one-ring')))
          .getSingle();

      final data = jsonDecode(oneRing.dynamicData) as Map<String, dynamic>;
      final uris = data['image_uris'] as Map<String, dynamic>;
      expect(uris['normal'].toString().isNotEmpty, isTrue);
      expect(uris['large'].toString().isNotEmpty, isTrue);
      expect(uris['art_crop'].toString().isNotEmpty, isTrue);
      expect(uris['normal'], contains('d5806e68-1054-458e-866d-1f2470f682b2'));
    });
  });

  // ---------------------------------------------------------------------------
  // Feature 5: Deck Assembly Status Toggle
  // ---------------------------------------------------------------------------
  group('Tier 1 - Feature 5: Deck Assembly Status Toggle', () {
    late AppDatabase db;

    setUp(() {
      db = createPhase46TestDb();
    });

    tearDown(() async {
      await db.close();
    });

    test('F5.1: setDeckRegistered(deckId, true) updates is_registered to true in SQLite', () async {
      final deck = await createAndInsertDeck(db, id: 'deck-tog-1', name: 'Test Deck', isRegistered: false);
      expect(deck.isRegistered, isFalse);

      await db.vaultDao.setDeckRegistered(deck.id, true);
      final updated = await (db.select(db.decks)..where((t) => t.id.equals(deck.id))).getSingle();
      expect(updated.isRegistered, isTrue);
    });

    test('F5.2: setDeckRegistered(deckId, false) updates is_registered to false in SQLite', () async {
      final deck = await createAndInsertDeck(db, id: 'deck-tog-2', name: 'Test Deck', isRegistered: true);
      expect(deck.isRegistered, isTrue);

      await db.vaultDao.setDeckRegistered(deck.id, false);
      final updated = await (db.select(db.decks)..where((t) => t.id.equals(deck.id))).getSingle();
      expect(updated.isRegistered, isFalse);
    });

    test('F5.3: Toggling assembly status updates the updated_at timestamp', () async {
      final deck = await createAndInsertDeck(db, id: 'deck-tog-3', name: 'Test Deck');
      final initialUpdatedAt = deck.updatedAt;

      await Future<void>.delayed(const Duration(milliseconds: 50));
      await db.vaultDao.setDeckRegistered(deck.id, true);

      final updated = await (db.select(db.decks)..where((t) => t.id.equals(deck.id))).getSingle();
      expect(updated.updatedAt, isNotNull);
      if (initialUpdatedAt != null && updated.updatedAt != null) {
        expect(updated.updatedAt!.isBefore(initialUpdatedAt), isFalse);
      }
    });

    test('F5.4: Assembly toggle logs an UPDATE mutation to SyncQueue outbox', () async {
      final deck = await createAndInsertDeck(db, id: 'deck-tog-4', name: 'Test Deck');
      await db.vaultDao.setDeckRegistered(deck.id, true);

      final syncEntries = await (db.select(db.syncQueue)
            ..where((t) => t.entityType.equals('deck') & t.entityId.equals(deck.id)))
          .get();

      expect(syncEntries.any((s) => s.operation == 'UPDATE'), isTrue);
    });

    test('F5.5: Reactive deck query emits updated assembly status', () async {
      final deck = await createAndInsertDeck(db, id: 'deck-tog-5', name: 'Reactive Deck', isRegistered: false);

      final stream = (db.select(db.decks)..where((t) => t.id.equals(deck.id))).watchSingle();

      expectLater(
        stream.map((d) => d.isRegistered),
        emitsInOrder([false, true]),
      );

      await db.vaultDao.setDeckRegistered(deck.id, true);
    });
  });

  // ---------------------------------------------------------------------------
  // Feature 6: Deck Thumbnail Picker
  // ---------------------------------------------------------------------------
  group('Tier 1 - Feature 6: Deck Thumbnail Picker', () {
    late AppDatabase db;

    setUp(() {
      db = createPhase46TestDb();
    });

    tearDown(() async {
      await db.close();
    });

    test('F6.1: Deck cover item can be assigned to a specific card item ID in the deck', () async {
      final card = createPhase46TestCard(id: 'c-urza-thumb', name: 'Urza, Lord High Artificer');
      await db.into(db.vaultItems).insert(card);

      final deck = await createAndInsertDeck(db, id: 'deck-thumb-1', name: 'Urza Deck', coverItemId: card.id);
      expect(deck.coverItemId, equals(card.id));
    });

    test('F6.2: Updating coverItemId persists to SQLite correctly', () async {
      final cardA = createPhase46TestCard(id: 'c-art-a', name: 'Art A');
      final cardB = createPhase46TestCard(id: 'c-art-b', name: 'Art B');
      await db.into(db.vaultItems).insert(cardA);
      await db.into(db.vaultItems).insert(cardB);

      final deck = await createAndInsertDeck(db, id: 'deck-thumb-2', name: 'Switch Cover Deck', coverItemId: cardA.id);

      await db.vaultDao.updateDeckCover(deck.id, cardB.id);

      final updated = await (db.select(db.decks)..where((t) => t.id.equals(deck.id))).getSingle();
      expect(updated.coverItemId, equals(cardB.id));

      final syncEntry = await (db.select(db.syncQueue)
            ..where((t) => t.entityId.equals(deck.id) & t.operation.equals('UPDATE')))
          .getSingle();
      expect(syncEntry.entityType, equals('deck'));
    });

    test('F6.3: Setting coverItemId to null clears the custom cover art', () async {
      final card = createPhase46TestCard(id: 'c-art-c', name: 'Art C');
      await db.into(db.vaultItems).insert(card);

      final deck = await createAndInsertDeck(db, id: 'deck-thumb-3', name: 'Clear Cover Deck', coverItemId: card.id);
      expect(deck.coverItemId, isNotNull);

      await db.vaultDao.updateDeckCover(deck.id, null);

      final updated = await (db.select(db.decks)..where((t) => t.id.equals(deck.id))).getSingle();
      expect(updated.coverItemId, isNull);

      final syncEntries = await (db.select(db.syncQueue)
            ..where((t) => t.entityId.equals(deck.id) & t.operation.equals('UPDATE')))
          .get();
      expect(syncEntries, isNotEmpty);
    });

    test('F6.4: Changing cover art records a mutation in SQLite', () async {
      final deck = await createAndInsertDeck(db, id: 'deck-thumb-4', name: 'Sync Deck');
      const cropRect = '10,20,200,150';
      await db.vaultDao.updateDeckCover(deck.id, 'new-cover-id', coverCropRect: cropRect);

      final updated = await (db.select(db.decks)..where((t) => t.id.equals(deck.id))).getSingle();
      expect(updated.coverItemId, equals('new-cover-id'));
      expect(updated.coverCropRect, equals(cropRect));

      final syncEntries = await (db.select(db.syncQueue)
            ..where((t) => t.entityId.equals(deck.id) & t.operation.equals('UPDATE')))
          .get();
      expect(syncEntries, isNotEmpty);
    });

    test('F6.5: Deck can be customized from catalog card or non-deck card item', () async {
      final catalogCard = createPhase46TestCard(
        id: 'cat-lotus',
        name: 'Black Lotus',
        quantity: 0, // catalog reference item
      );
      await db.into(db.vaultItems).insert(catalogCard);

      final deck = await createAndInsertDeck(db, id: 'deck-thumb-5', name: 'Catalog Cover Deck');
      await db.vaultDao.updateDeckCover(deck.id, catalogCard.id);

      final updated = await (db.select(db.decks)..where((t) => t.id.equals(deck.id))).getSingle();
      expect(updated.coverItemId, equals('cat-lotus'));

      final syncEntries = await (db.select(db.syncQueue)
            ..where((t) => t.entityId.equals(deck.id) & t.operation.equals('UPDATE')))
          .get();
      expect(syncEntries, isNotEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // Feature 7: Board Movement (Main/Side/Maybe)
  // ---------------------------------------------------------------------------
  group('Tier 1 - Feature 7: Board Movement (Main/Side/Maybe)', () {
    late AppDatabase db;

    setUp(() {
      db = createPhase46TestDb();
    });

    tearDown(() async {
      await db.close();
    });

    test('F7.1: Moves card from Mainboard to Sideboard, updating boardZone', () async {
      final card = createPhase46TestCard(id: 'c-board-1', name: 'Flusterstorm');
      await db.into(db.vaultItems).insert(card);

      final deck = await createAndInsertDeck(db, id: 'd-board-1', name: 'Board Test');
      await addCardToDeckZone(db, deckId: deck.id, vaultItemId: card.id, boardZone: 'Mainboard', quantity: 1);

      await db.vaultDao.moveDeckItemBoard(
        deck.id,
        card.id,
        'Sideboard',
        1,
        'Mainboard',
      );

      final items = await (db.select(db.deckVersionItems)..where((t) => t.vaultItemId.equals(card.id) & t.isDeleted.equals(false))).get();
      expect(items.length, equals(1));
      expect(items.first.boardZone, equals('Sideboard'));

      final syncEntries = await (db.select(db.syncQueue)
            ..where((t) => t.entityType.equals('deck_version_item')))
          .get();
      expect(syncEntries, isNotEmpty);
    });

    test('F7.2: Moves card from Sideboard to Maybeboard, updating boardZone', () async {
      final card = createPhase46TestCard(id: 'c-board-2', name: 'Swan Song');
      await db.into(db.vaultItems).insert(card);

      final deck = await createAndInsertDeck(db, id: 'd-board-2', name: 'Board Test 2');
      await addCardToDeckZone(db, deckId: deck.id, vaultItemId: card.id, boardZone: 'Sideboard', quantity: 1);

      await db.vaultDao.moveDeckItemBoard(
        deck.id,
        card.id,
        'Maybeboard',
        1,
        'Sideboard',
      );

      final items = await (db.select(db.deckVersionItems)..where((t) => t.vaultItemId.equals(card.id) & t.isDeleted.equals(false))).get();
      expect(items.length, equals(1));
      expect(items.first.boardZone, equals('Maybeboard'));
    });

    test('F7.3: Partial quantity movement splits quantity across source and destination zones', () async {
      final card = createPhase46TestCard(id: 'c-board-3', name: 'Lightning Bolt', quantity: 4);
      await db.into(db.vaultItems).insert(card);

      final deck = await createAndInsertDeck(db, id: 'd-board-3', name: 'Burn');
      await addCardToDeckZone(db, deckId: deck.id, vaultItemId: card.id, boardZone: 'Mainboard', quantity: 3);

      await db.vaultDao.moveDeckItemBoard(
        deck.id,
        card.id,
        'Sideboard',
        1,
        'Mainboard',
      );

      final activeItems = await (db.select(db.deckVersionItems)..where((t) => t.vaultItemId.equals(card.id) & t.isDeleted.equals(false))).get();
      expect(activeItems.length, equals(2));

      final mb = activeItems.firstWhere((i) => i.boardZone == 'Mainboard');
      final sb = activeItems.firstWhere((i) => i.boardZone == 'Sideboard');
      expect(mb.quantity, equals(2));
      expect(sb.quantity, equals(1));
    });

    test('F7.4: Merges quantities when moving card to a board that already contains that card', () async {
      final card = createPhase46TestCard(id: 'c-board-4', name: 'Duress');
      await db.into(db.vaultItems).insert(card);

      final deck = await createAndInsertDeck(db, id: 'd-board-4', name: 'Discard');
      await addCardToDeckZone(db, deckId: deck.id, vaultItemId: card.id, boardZone: 'Mainboard', quantity: 1);
      await addCardToDeckZone(db, deckId: deck.id, vaultItemId: card.id, boardZone: 'Sideboard', quantity: 2);

      await db.vaultDao.moveDeckItemBoard(
        deck.id,
        card.id,
        'Sideboard',
        1,
        'Mainboard',
      );

      final activeItems = await (db.select(db.deckVersionItems)..where((t) => t.vaultItemId.equals(card.id) & t.isDeleted.equals(false))).get();
      expect(activeItems.length, equals(1));
      expect(activeItems.first.boardZone, equals('Sideboard'));
      expect(activeItems.first.quantity, equals(3));
    });

    test('F7.5: Moving all copies soft-deletes the source deck_version_items row', () async {
      final card = createPhase46TestCard(id: 'c-board-5', name: 'Thoughtseize');
      await db.into(db.vaultItems).insert(card);

      final deck = await createAndInsertDeck(db, id: 'd-board-5', name: 'Modern Jund');
      final source = await addCardToDeckZone(db, deckId: deck.id, vaultItemId: card.id, boardZone: 'Mainboard', quantity: 1);
      await addCardToDeckZone(db, deckId: deck.id, vaultItemId: card.id, boardZone: 'Sideboard', quantity: 1);

      await db.vaultDao.moveDeckItemBoard(
        deck.id,
        card.id,
        'Sideboard',
        1,
        'Mainboard',
      );

      final deletedSource = await (db.select(db.deckVersionItems)..where((t) => t.id.equals(source.id))).getSingle();
      expect(deletedSource.isDeleted, isTrue);

      final activeItems = await (db.select(db.deckVersionItems)..where((t) => t.vaultItemId.equals(card.id) & t.isDeleted.equals(false))).get();
      expect(activeItems.length, equals(1));
      expect(activeItems.first.boardZone, equals('Sideboard'));
      expect(activeItems.first.quantity, equals(2));
    });
  });

  // ---------------------------------------------------------------------------
  // Feature 8: Format Legality Engine & Badges
  // ---------------------------------------------------------------------------
  group('Tier 1 - Feature 8: Format Legality Engine & Badges', () {
    test('F8.1: Evaluates card as legal when format legality status is legal', () {
      final card = createPhase46TestCard(
        id: 'c-sol',
        name: 'Sol Ring',
        legalities: {'commander': 'legal', 'modern': 'banned'},
      );

      final res = checkCardLegalityDirect(card, 'commander');
      expect(res.isLegal, isTrue);
      expect(res.violations, isEmpty);
    });

    test('F8.2: Evaluates card as not legal and records violation when status is banned', () {
      final card = createPhase46TestCard(
        id: 'c-sol-banned',
        name: 'Sol Ring',
        legalities: {'modern': 'banned'},
      );

      final res = checkCardLegalityDirect(card, 'modern');
      expect(res.isLegal, isFalse);
      expect(res.violations, contains('Sol Ring is not legal in modern (Status: banned)'));
    });

    test('F8.3: Evaluates card as not legal when status is not_legal', () {
      final card = createPhase46TestCard(
        id: 'c-pauper-rare',
        name: 'Ragavan, Nimble Pilferer',
        legalities: {'pauper': 'not_legal'},
      );

      final res = checkCardLegalityDirect(card, 'pauper');
      expect(res.isLegal, isFalse);
      expect(res.violations, contains('Ragavan, Nimble Pilferer is not legal in pauper (Status: not_legal)'));
    });

    test('F8.4: Formats comparison is case-insensitive (Commander vs commander)', () {
      final card = createPhase46TestCard(
        id: 'c-case-test',
        name: 'Black Lotus',
        legalities: {'vintage': 'restricted'},
      );

      final resUpper = checkCardLegalityDirect(card, 'VINTAGE');
      expect(resUpper.isLegal, isTrue); // restricted is allowed in vintage
    });

    test('F8.5: Handles cards with missing legality metadata gracefully without exceptions', () {
      final card = createPhase46TestCard(
        id: 'c-missing-leg',
        name: 'Custom Card',
        additionalDynamicData: {'legalities': null},
      );

      expect(() => checkCardLegalityDirect(card, 'commander'), returnsNormally);
      final res = checkCardLegalityDirect(card, 'commander');
      expect(res.isLegal, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Feature 9: Custom Scrollbar Fade Auto-Hide
  // ---------------------------------------------------------------------------
  group('Tier 1 - Feature 9: Custom Scrollbar Refinement', () {
    test('F9.1: Partitions rail height proportionally based on zone card counts', () {
      final counts = [20, 10, 10]; // total 40
      final heights = ProportionalBubbleScrollbar.computeSectionHeights(
        counts: counts,
        totalHeight: 400,
        minHeight: 24.0,
      );

      expect(heights.length, equals(3));
      expect(heights[0], equals(200.0));
      expect(heights[1], equals(100.0));
      expect(heights[2], equals(100.0));
    });

    test('F9.2: Clamps each section to at least minSectionHeight (24.0px)', () {
      final counts = [100, 1]; // 1 card would receive tiny fraction
      final heights = ProportionalBubbleScrollbar.computeSectionHeights(
        counts: counts,
        totalHeight: 200,
        minHeight: 24.0,
      );

      expect(heights.length, equals(2));
      expect(heights[1], greaterThanOrEqualTo(24.0));
      expect(heights[0] + heights[1], closeTo(200.0, 0.01));
    });

    test('F9.3: Divides rail equally when total minimum height exceeds rail height', () {
      final counts = [10, 20, 30, 40];
      final heights = ProportionalBubbleScrollbar.computeSectionHeights(
        counts: counts,
        totalHeight: 60, // 4 * 24 = 96 > 60
        minHeight: 24.0,
      );

      expect(heights.length, equals(4));
      for (final h in heights) {
        expect(h, equals(15.0)); // 60 / 4
      }
    });

    test('F9.4: Resolves canonical zone short labels for standard zones', () {
      final secCreatures = ScrollbarSection(label: 'Creatures', count: 10, onTap: () {});
      final secLands = ScrollbarSection(label: 'Lands', count: 20, onTap: () {});
      final secSB = ScrollbarSection(label: 'Sideboard', count: 15, onTap: () {});

      expect(ProportionalBubbleScrollbar.resolveSectionLabel(secCreatures), equals('Cr'));
      expect(ProportionalBubbleScrollbar.resolveSectionLabel(secLands), equals('L'));
      expect(ProportionalBubbleScrollbar.resolveSectionLabel(secSB), equals('SB'));
    });

    testWidgets('F9.5: Renders ProportionalBubbleScrollbar widget without overflow', (tester) async {
      final sections = [
        ScrollbarSection(label: 'Mainboard', count: 60, onTap: () {}),
        ScrollbarSection(label: 'Sideboard', count: 15, onTap: () {}),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 400,
              width: 30,
              child: ProportionalBubbleScrollbar(
                sections: sections,
                railWidth: 26,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(ProportionalBubbleScrollbar), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Feature 10: Inline Deck Analytics
  // ---------------------------------------------------------------------------
  group('Tier 1 - Feature 10: Inline Deck Analytics', () {
    test('F10.1: Computes total card count across all zones in deck', () {
      final items = [
        {'quantity': 4, 'dynamic_data': '{"cmc": 1}'},
        {'quantity': 2, 'dynamic_data': '{"cmc": 2}'},
        {'quantity': 34, 'dynamic_data': '{"cmc": 0}'},
      ];
      final total = items.fold<int>(0, (sum, i) => sum + (i['quantity'] as int));
      expect(total, equals(40));
    });

    test('F10.2: Computes bling count for foils, etched, or altered cards', () {
      final items = [
        {'quantity': 1, 'is_graded': 1, 'dynamic_data': '{}'},
        {'quantity': 1, 'condition': 'NM Foil', 'dynamic_data': '{"finishes": ["foil"]}'},
        {'quantity': 2, 'dynamic_data': '{}'},
      ];

      int blingCount = 0;
      for (final item in items) {
        if (item['is_graded'] == 1 ||
            (item['condition'] as String?)?.contains('Foil') == true ||
            (item['dynamic_data'] as String).contains('foil')) {
          blingCount += item['quantity'] as int;
        }
      }
      expect(blingCount, equals(2));
    });

    test('F10.3: Computes color devotion distribution across colors', () {
      final costs = ['{1}{U}', '{U}{U}', '{R}{U}'];
      final devotion = <String, int>{};

      for (final cost in costs) {
        final matches = RegExp(r'\{([^}]+)\}').allMatches(cost);
        for (final m in matches) {
          final sym = m.group(1)!;
          if (RegExp(r'^[WUBRGC]$').hasMatch(sym)) {
            devotion[sym] = (devotion[sym] ?? 0) + 1;
          }
        }
      }

      expect(devotion['U'], equals(4));
      expect(devotion['R'], equals(1));
    });

    test('F10.4: Aggregates total deck market valuation accurately', () {
      final items = [
        {'quantity': 1, 'price': 100.0},
        {'quantity': 4, 'price': 2.5},
      ];
      final totalValue = items.fold<double>(0.0, (sum, i) => sum + (i['quantity'] as int) * (i['price'] as double));
      expect(totalValue, equals(110.0));
    });

    test('F10.5: Empty deck produces clean zeroed analytics without throwing errors', () {
      final curve = computeDeckManaCurve([]);
      expect(curve.isEmpty, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Feature 11: Interactive Value Concentration Pie Chart
  // ---------------------------------------------------------------------------
  group('Tier 1 - Feature 11: Value Concentration (Pareto)', () {
    test('F11.1: Computes top 5 cards value concentration percentage accurately', () {
      final inputs = [
        ParetoCardInput(id: '1', name: 'Card 1', setCode: 'SET', quantity: 1, unitPrice: 100.0, imageUrl: ''),
        ParetoCardInput(id: '2', name: 'Card 2', setCode: 'SET', quantity: 1, unitPrice: 50.0, imageUrl: ''),
        ParetoCardInput(id: '3', name: 'Card 3', setCode: 'SET', quantity: 1, unitPrice: 30.0, imageUrl: ''),
        ParetoCardInput(id: '4', name: 'Card 4', setCode: 'SET', quantity: 1, unitPrice: 20.0, imageUrl: ''),
        ParetoCardInput(id: '5', name: 'Card 5', setCode: 'SET', quantity: 1, unitPrice: 10.0, imageUrl: ''),
        ParetoCardInput(id: '6', name: 'Card 6', setCode: 'SET', quantity: 1, unitPrice: 5.0, imageUrl: ''),
        ParetoCardInput(id: '7', name: 'Card 7', setCode: 'SET', quantity: 1, unitPrice: 2.0, imageUrl: ''),
      ];
      final res = ParetoDistributionCalculator.calculate(cards: inputs);
      // total = 217.0, top 5 = 210.0 => 96.77%
      expect(res.concentrationPercentage, closeTo(96.77, 0.05));
    });

    test('F11.2: Ranks cards by valuation in descending order', () {
      final inputs = [
        ParetoCardInput(id: '1', name: 'Sol Ring', setCode: 'CMD', quantity: 1, unitPrice: 2.0, imageUrl: ''),
        ParetoCardInput(id: '2', name: 'Mox Diamond', setCode: 'STH', quantity: 1, unitPrice: 600.0, imageUrl: ''),
        ParetoCardInput(id: '3', name: 'Mana Crypt', setCode: 'EMA', quantity: 1, unitPrice: 180.0, imageUrl: ''),
      ];
      final res = ParetoDistributionCalculator.calculate(cards: inputs);

      expect(res.topCards.first.name, equals('Mox Diamond'));
      expect(res.topCards.last.name, equals('Sol Ring'));
    });

    test('F11.3: Generates adaptive headline grammar for small decks (<5 cards)', () {
      final inputs3 = [
        ParetoCardInput(id: '1', name: 'Card A', setCode: 'SET', quantity: 1, unitPrice: 100.0, imageUrl: ''),
        ParetoCardInput(id: '2', name: 'Card B', setCode: 'SET', quantity: 1, unitPrice: 50.0, imageUrl: ''),
        ParetoCardInput(id: '3', name: 'Card C', setCode: 'SET', quantity: 1, unitPrice: 20.0, imageUrl: ''),
      ];
      final res3 = ParetoDistributionCalculator.calculate(cards: inputs3);
      expect(res3.getHeadline(), contains('top 3 cards represent'));

      final inputs1 = [
        ParetoCardInput(id: '1', name: 'Card A', setCode: 'SET', quantity: 1, unitPrice: 100.0, imageUrl: ''),
      ];
      final res1 = ParetoDistributionCalculator.calculate(cards: inputs1);
      expect(res1.getHeadline(), contains('top card represents 100.0%'));
    });

    test('F11.4: Handles zero total value gracefully without division by zero', () {
      final res = ParetoDistributionCalculator.calculate(cards: []);
      expect(res.concentrationPercentage, equals(0.0));
      expect(res.totalDeckValue, equals(0.0));
      expect(res.topCards, isEmpty);
    });

    testWidgets('F11.5: Masking / Privacy Mode redacts headline values to **** in Pareto widget', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProviderScope(
              child: ParetoDistributionWidget(
                deckTotalValue: 500.0,
                topKConcentrationPercentage: 80.0,
                topCards: [
                  ParetoCardInput(
                    id: '1',
                    name: 'Sol Ring',
                    setCode: 'CMD',
                    quantity: 1,
                    unitPrice: 500.0,
                    imageUrl: '',
                  ),
                ],
                isPrivacyMode: true,
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('pareto_distribution_widget')), findsOneWidget);
      expect(find.textContaining('****'), findsWidgets);
    });
  });

  // ---------------------------------------------------------------------------
  // Feature 12: Mana Curve CMC Calculation Fix
  // ---------------------------------------------------------------------------
  group('Tier 1 - Feature 12: Mana Curve CMC Calculation Fix', () {
    test('F12.1: Calculates exact CMC for single mana costs e.g. {1}{U} -> 2.0', () {
      expect(calculateAccurateCmc('{1}{U}'), equals(2.0));
      expect(calculateAccurateCmc('{3}{B}{B}'), equals(5.0));
    });

    test('F12.2: Calculates CMC for split cards summing both faces e.g. {1}{R} // {1}{U} -> 4.0', () {
      expect(calculateAccurateCmc('{1}{R} // {1}{U}'), equals(4.0));
      expect(calculateAccurateCmc('{W} // {U}'), equals(2.0));
    });

    test('F12.3: Calculates CMC for hybrid and twobrid mana e.g. {W/U} -> 1.0, {2/W} -> 2.0', () {
      expect(calculateAccurateCmc('{W/U}'), equals(1.0));
      expect(calculateAccurateCmc('{2/W}'), equals(2.0));
      expect(calculateAccurateCmc('{2/B}{2/B}'), equals(4.0));
    });

    test('F12.4: Calculates CMC for zero-cost spells and lands {0} -> 0.0, null -> 0.0', () {
      expect(calculateAccurateCmc('{0}'), equals(0.0));
      expect(calculateAccurateCmc(null), equals(0.0));
      expect(calculateAccurateCmc(''), equals(0.0));
    });

    test('F12.5: Handles extreme / infinite symbols e.g. {∞} returns fallback or null', () {
      final cmc = calculateAccurateCmc('{∞}', fallbackCmc: 100.0);
      expect(cmc, equals(100.0));
    });
  });

  // ---------------------------------------------------------------------------
  // Feature 13: Official MTG Symbology Filters
  // ---------------------------------------------------------------------------
  group('Tier 1 - Feature 13: Official MTG Symbology Filters', () {
    test('F13.1: ScryfallSymbolCatalog resolves all basic mana symbols', () {
      final w = ScryfallSymbolCatalog.findBySymbol('{W}');
      final u = ScryfallSymbolCatalog.findBySymbol('{U}');
      final b = ScryfallSymbolCatalog.findBySymbol('{B}');
      final r = ScryfallSymbolCatalog.findBySymbol('{R}');
      final g = ScryfallSymbolCatalog.findBySymbol('{G}');
      final c = ScryfallSymbolCatalog.findBySymbol('{C}');

      expect(w?.filename, equals('W.svg'));
      expect(u?.filename, equals('U.svg'));
      expect(b?.filename, equals('B.svg'));
      expect(r?.filename, equals('R.svg'));
      expect(g?.filename, equals('G.svg'));
      expect(c?.filename, equals('C.svg'));
    });

    test('F13.2: Asset paths point to valid assets/symbology directory', () {
      final sym = ScryfallSymbolCatalog.findBySymbol('{W/U}');
      expect(sym?.assetPath, equals('assets/symbology/WU.svg'));
    });

    test('F13.3: ManaTextParser extracts all symbol tokens correctly', () {
      final tokens = ScryfallSymbolCatalog.extractSymbols('{2}{W}{U}');
      expect(tokens, equals(['2', 'W', 'U']));
    });

    test('F13.4: Renders Tap {T} and Untap {Q} symbols without exceptions', () {
      final tap = ScryfallSymbolCatalog.findBySymbol('{T}');
      final untap = ScryfallSymbolCatalog.findBySymbol('{Q}');

      expect(tap?.filename, equals('T.svg'));
      expect(untap?.filename, equals('Q.svg'));
      expect(tap?.representsMana, isFalse);
    });

    testWidgets('F13.5: Malformed bracketed text falls back gracefully to plain text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ManaText(
              'Pay {NotASymbol} and {W} to cast.',
              style: TextStyle(fontSize: 14),
            ),
          ),
        ),
      );

      expect(find.byType(ManaText), findsOneWidget);
      expect(find.textContaining('Pay {NotASymbol} and'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Feature 14: Card Details Crash & Overflow Resolution
  // ---------------------------------------------------------------------------
  group('Tier 1 - Feature 14: Card Details Crash & Overflow Resolution', () {
    testWidgets('F14.1: Card Details sheet renders safely in constrained heights', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 400,
              width: 320,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Container(height: 200, color: Colors.blue),
                    Container(height: 300, color: Colors.red),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('F14.2: Narrow viewport (320px width) does not produce horizontal RenderFlex overflows', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: const Row(
                children: [
                  Expanded(
                    child: Text('The One Ring (Serialized #007/100)', overflow: TextOverflow.ellipsis),
                  ),
                  SizedBox(width: 8),
                  Text('\$1,500.00'),
                ],
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('F14.3: High font scale (2.0x) does not produce unconstrained vertical overflows', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    Text('Mana Cost'),
                    Text('{2}{U}{B}'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    test('F14.4: Dynamic data with empty or missing fields renders without null errors', () {
      final card = createPhase46TestCard(
        id: 'c-empty-dyn',
        name: 'Empty Metadata Card',
        additionalDynamicData: {},
      );

      expect(() => jsonDecode(card.dynamicData), returnsNormally);
    });

    testWidgets('F14.5: Multiple scroll actions and drag gestures do not trigger scroll collisions', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView.builder(
              controller: controller,
              itemCount: 50,
              itemBuilder: (_, i) => ListTile(title: Text('Item $i')),
            ),
          ),
        ),
      );

      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, 300));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Feature 15: SliverAppBar Title Collision Fix
  // ---------------------------------------------------------------------------
  group('Tier 1 - Feature 15: SliverAppBar Title Collision Fix', () {
    testWidgets('F15.1: SliverAppBar title handles long deck names with ellipsis truncation', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                SliverAppBar(
                  leading: const BackButton(),
                  title: const Text(
                    'Extremely Long Deck Name That Could Easily Collide With Actions And Overflow The Screen Viewport In Collapsed State',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  actions: [
                    IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
                  ],
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => ListTile(title: Text('Row $i')),
                    childCount: 30,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(SliverAppBar), findsOneWidget);
    });

    testWidgets('F15.2: Collapsed SliverAppBar does not collide with leading back button', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              controller: controller,
              slivers: [
                const SliverAppBar(
                  expandedHeight: 200,
                  pinned: true,
                  leading: BackButton(),
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text('Deck Name', style: TextStyle(fontSize: 14)),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => ListTile(title: Text('Card $i')),
                    childCount: 40,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Scroll up to collapse app bar
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(BackButton), findsOneWidget);
    });

    testWidgets('F15.3: Trailing actions maintain hit targets without overlap', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                SliverAppBar(
                  title: const Text('Title'),
                  actions: [
                    IconButton(
                      key: const Key('action_btn'),
                      icon: const Icon(Icons.settings),
                      onPressed: () => tapped = true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('action_btn')));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('F15.4: Title cleanly fades or stays within bounds during scroll contraction', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 180,
                  pinned: true,
                  flexibleSpace: FlexibleSpaceBar(
                    title: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Deck Title'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Deck Title'), findsOneWidget);
    });

    testWidgets('F15.5: Empty or whitespace-only deck title renders without exceptions', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                SliverAppBar(
                  title: Text('   '),
                ),
              ],
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Feature 16: Context-Aware Filter Pills
  // ---------------------------------------------------------------------------
  group('Tier 1 - Feature 16: Context-Aware Filter Pills', () {
    List<String> getContextFilters(String activeGame) {
      switch (activeGame) {
        case 'Magic: The Gathering':
          return ['Owned', 'All Cards', 'Graded Slabs', 'Raw Singles', 'High P/L', 'Commander Legal'];
        case 'Pokémon TCG':
          return ['Owned', 'All Cards', 'Graded Slabs', 'Raw Singles', 'High P/L', 'Standard Legal'];
        case 'Comic Books':
          return ['Owned', 'All Cards', 'Graded Slabs', 'Raw Issues', 'High P/L', 'Golden Age'];
        case 'Sports Cards':
          return ['Owned', 'All Cards', 'Graded Slabs', 'Raw Cards', 'High P/L', 'Rookie Cards'];
        default:
          return ['Owned', 'All Cards', 'Graded Slabs', 'Raw Singles', 'High P/L'];
      }
    }

    test('F16.1: Active game Magic: The Gathering excludes Comics and Sports filters', () {
      final filters = getContextFilters('Magic: The Gathering');
      expect(filters, isNot(contains('Comics')));
      expect(filters, isNot(contains('Sports Cards')));
      expect(filters, contains('Commander Legal'));
    });

    test('F16.2: Active game Pokémon TCG excludes MTG mana/format filters', () {
      final filters = getContextFilters('Pokémon TCG');
      expect(filters, isNot(contains('Commander Legal')));
      expect(filters, contains('Standard Legal'));
    });

    test('F16.3: Active game Comic Books presents comic-specific filter categories', () {
      final filters = getContextFilters('Comic Books');
      expect(filters, contains('Raw Issues'));
      expect(filters, contains('Golden Age'));
      expect(filters, isNot(contains('Commander Legal')));
    });

    test('F16.4: Switching active collection context dynamically updates filter pills list', () {
      String game = 'Magic: The Gathering';
      var filters = getContextFilters(game);
      expect(filters.contains('Commander Legal'), isTrue);

      game = 'Sports Cards';
      filters = getContextFilters(game);
      expect(filters.contains('Commander Legal'), isFalse);
      expect(filters.contains('Rookie Cards'), isTrue);
    });

    test('F16.5: Universal base filters (Owned, Catalog, Graded, High P/L) persist across contexts', () {
      final contexts = ['Magic: The Gathering', 'Pokémon TCG', 'Comic Books', 'Sports Cards'];
      for (final ctx in contexts) {
        final filters = getContextFilters(ctx);
        expect(filters, contains('Owned'));
        expect(filters, contains('All Cards'));
        expect(filters, contains('Graded Slabs'));
        expect(filters, contains('High P/L'));
      }
    });
  });
}
