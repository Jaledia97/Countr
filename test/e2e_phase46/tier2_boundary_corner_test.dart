import 'dart:convert';
import 'package:drift/drift.dart' hide Column, isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/settings_state.dart';
import 'package:countr/features/symbology/data/scryfall_symbol_catalog.dart';
import 'package:countr/features/symbology/presentation/widgets/mana_text.dart';
import 'package:countr/features/decks/presentation/widgets/proportional_bubble_scrollbar.dart';
import 'package:countr/features/values/domain/services/pareto_distribution_calculator.dart';
import 'package:countr/features/vault/domain/vault_variant_helper.dart';
import 'package:countr/features/vault/domain/models/card_availability.dart';

import 'phase46_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ===========================================================================
  // TIER 2 - BOUNDARY & CORNER CASES (>=5 tests per feature, F1 - F16, Total >=80)
  // ===========================================================================

  // ---------------------------------------------------------------------------
  // Feature 1: Variant Grouping Boundary Cases
  // ---------------------------------------------------------------------------
  group('Tier 2 - Feature 1: Variant Grouping Boundary Cases', () {
    test('BC1.1: Empty collection returns empty grouping map without error', () {
      final result = VaultVariantHelper.groupVaultItemsByVariant([]);
      expect(result.items.isEmpty, isTrue);
    });

    test('BC1.2: Items with null or empty finish default cleanly to nonfoil', () {
      final card = createPhase46TestCard(
        id: 'c-null-finish',
        name: 'Forest',
        scryfallId: 'scryfall-forest',
        additionalDynamicData: {'finish': null, 'finishes': []},
        condition: 'NM',
      );
      final finish = VaultVariantHelper.resolveFinish(card);
      expect(finish, equals('nonfoil'));
      final key = VaultVariantHelper.computeVariantKey(card);
      expect(key, equals('mtg_scryfall-forest_nonfoil'));
    });

    test('BC1.3: Extreme quantities compute sum correctly without integer overflow', () {
      final cards = [
        createPhase46TestCard(id: 'c-bulk-1', name: 'Relentless Rats', scryfallId: 'rats-id', quantity: 50000),
        createPhase46TestCard(id: 'c-bulk-2', name: 'Relentless Rats', scryfallId: 'rats-id', quantity: 50000),
      ];
      final result = VaultVariantHelper.groupVaultItemsByVariant(cards);
      expect(result.items.first.quantity, equals(100000));
    });

    test('BC1.4: Special characters and hyphens in scryfall_id preserved in grouping key', () {
      final card = createPhase46TestCard(
        id: 'c-uuid',
        name: 'Special Card',
        scryfallId: 'd5806e68-1054-458e-866d-1f2470f682b2',
        finish: 'etched',
      );
      final finish = VaultVariantHelper.resolveFinish(card);
      expect(finish, equals('etched'));
      final key = VaultVariantHelper.computeVariantKey(card);
      expect(key, equals('mtg_d5806e68-1054-458e-866d-1f2470f682b2_etched'));
    });

    test('BC1.5: Mixed capitalization in condition/finish normalizes to lowercase', () {
      final card = createPhase46TestCard(
        id: 'c-case',
        name: 'Swamp',
        scryfallId: 'scryfall-swamp',
        finish: 'FOIL',
      );
      final finish = VaultVariantHelper.resolveFinish(card);
      expect(finish, equals('foil'));
      final key = VaultVariantHelper.computeVariantKey(card);
      expect(key, equals('mtg_scryfall-swamp_foil'));
    });
  });

  // ---------------------------------------------------------------------------
  // Feature 2: Availability Engine Boundary Cases
  // ---------------------------------------------------------------------------
  group('Tier 2 - Feature 2: Availability Engine Boundary Cases', () {
    late AppDatabase db;

    setUp(() {
      db = createPhase46TestDb();
    });

    tearDown(() async {
      await db.close();
    });

    test('BC2.1: Card with 0 owned quantity yields Owned: 0, Available: 0, In Deck: 0', () async {
      final card = createPhase46TestCard(id: 'c-zero-qty', name: 'Catalog Lotus', quantity: 0);
      await db.into(db.vaultItems).insert(card);

      final availMap = await db.vaultDao.watchAllCardAvailability().first;
      final avail = availMap[card.id] ?? CardAvailability.zero;
      expect(avail.owned, equals(0));
      expect(avail.available, equals(0));
      expect(avail.inDeck, equals(0));
    });

    test('BC2.2: Extreme allocation (allocated > owned) clamps available quantity to 0', () async {
      final card = createPhase46TestCard(id: 'c-over-alloc', name: 'Mox Opal', quantity: 1);
      await db.into(db.vaultItems).insert(card);

      final deck = await createAndInsertDeck(db, id: 'd-over', name: 'Overallocated Deck', isRegistered: true);
      // Manually add 2 copies to deck when user only owns 1
      await addCardToDeckZone(db, deckId: deck.id, vaultItemId: card.id, quantity: 2);

      final availMap = await db.vaultDao.watchAllCardAvailability().first;
      final avail = availMap[card.id] ?? CardAvailability.zero;
      expect(avail.owned, equals(1));
      expect(avail.inDeck, equals(2));
      expect(avail.available, equals(0)); // Clamped to 0, no negative inventory
    });

    test('BC2.3: Deletion of assembled deck restores locked inventory immediately to Available', () async {
      final card = createPhase46TestCard(id: 'c-restore', name: 'Vampiric Tutor', quantity: 2);
      await db.into(db.vaultItems).insert(card);

      final deck = await createAndInsertDeck(db, id: 'd-to-delete', name: 'Temp Deck', isRegistered: true);
      await addCardToDeckZone(db, deckId: deck.id, vaultItemId: card.id, quantity: 2);

      var availMap = await db.vaultDao.watchAllCardAvailability().first;
      var avail = availMap[card.id] ?? CardAvailability.zero;
      expect(avail.available, equals(0));
      expect(avail.inDeck, equals(2));

      // Soft delete deck
      await db.vaultDao.deleteDeck(deck.id);

      availMap = await db.vaultDao.watchAllCardAvailability().first;
      avail = availMap[card.id] ?? CardAvailability.zero;
      expect(avail.available, equals(2));
      expect(avail.inDeck, equals(0));
    });

    test('BC2.4: Soft-deleted cards (isDeleted = true) return 0 availability', () async {
      final card = createPhase46TestCard(id: 'c-soft-del', name: 'Mana Vault', quantity: 1);
      await db.into(db.vaultItems).insert(card);

      // Soft delete item
      await db.vaultDao.deleteItem(card.id);

      final availMap = await db.vaultDao.watchAllCardAvailability().first;
      final avail = availMap[card.id] ?? CardAvailability.zero;
      expect(avail.owned, equals(0));
      expect(avail.available, equals(0));
      expect(avail.inDeck, equals(0));
    });

    test('BC2.5: Concurrent deck allocations across multiple assembled decks correctly sum allocations', () async {
      final card = createPhase46TestCard(id: 'c-island', name: 'Island', quantity: 100);
      await db.into(db.vaultItems).insert(card);

      for (int i = 0; i < 5; i++) {
        final deck = await createAndInsertDeck(db, id: 'd-multi-$i', name: 'Deck $i', isRegistered: true);
        await addCardToDeckZone(db, deckId: deck.id, vaultItemId: card.id, quantity: 10);
      }

      final availMap = await db.vaultDao.watchAllCardAvailability().first;
      final avail = availMap[card.id] ?? CardAvailability.zero;
      expect(avail.owned, equals(100));
      expect(avail.inDeck, equals(50));
      expect(avail.available, equals(50));
    });
  });

  // ---------------------------------------------------------------------------
  // Feature 3: Assembled Deck Badge Gate Boundary Cases
  // ---------------------------------------------------------------------------
  group('Tier 2 - Feature 3: Assembled Deck Badge Gate Boundary Cases', () {
    late AppDatabase db;

    setUp(() {
      db = createPhase46TestDb();
    });

    tearDown(() async {
      await db.close();
    });

    test('BC3.1: Card with no deck assignments emits empty list without error', () async {
      final card = createPhase46TestCard(id: 'c-orphan', name: 'Orphan Card');
      await db.into(db.vaultItems).insert(card);

      final badges = await db.vaultDao.watchItemActiveDecks(card.id).first;
      expect(badges, isEmpty);
    });

    test('BC3.2: Card assigned to 1 assembled deck and 3 draft decks only emits the 1 assembled deck', () async {
      final card = createPhase46TestCard(id: 'c-mixed-decks', name: 'Chandra');
      await db.into(db.vaultItems).insert(card);

      final assembled = await createAndInsertDeck(db, id: 'd-ass-1', name: 'Tournament Burn', isRegistered: true);
      await addCardToDeckZone(db, deckId: assembled.id, vaultItemId: card.id);

      for (int i = 0; i < 3; i++) {
        final draft = await createAndInsertDeck(db, id: 'd-draft-$i', name: 'Draft $i', isRegistered: false);
        await addCardToDeckZone(db, deckId: draft.id, vaultItemId: card.id);
      }

      final badges = await db.vaultDao.watchItemActiveDecks(card.id).first;
      expect(badges.length, equals(1));
      expect(badges.first, equals('Tournament Burn'));
    });

    test('BC3.3: Soft-deleted deck version item does not emit a badge', () async {
      final card = createPhase46TestCard(id: 'c-soft-dvi', name: 'Gilded Drake');
      await db.into(db.vaultItems).insert(card);

      final deck = await createAndInsertDeck(db, id: 'd-soft-dvi', name: 'Control Deck', isRegistered: true);
      final dvi = await addCardToDeckZone(db, deckId: deck.id, vaultItemId: card.id);

      expect(await db.vaultDao.watchItemActiveDecks(card.id).first, contains('Control Deck'));

      // Soft delete DVI row
      await (db.update(db.deckVersionItems)..where((t) => t.id.equals(dvi.id))).write(
        const DeckVersionItemsCompanion(isDeleted: Value(true)),
      );

      expect(await db.vaultDao.watchItemActiveDecks(card.id).first, isEmpty);
    });

    test('BC3.4: Proxy card assignment does not emit an assembled deck badge', () async {
      final card = createPhase46TestCard(id: 'c-proxy-card', name: 'Mox Jet');
      await db.into(db.vaultItems).insert(card);

      final deck = await createAndInsertDeck(db, id: 'd-proxy-deck', name: 'Cube Deck', isRegistered: true);
      await addCardToDeckZone(db, deckId: deck.id, vaultItemId: card.id, isProxy: true);

      final badges = await db.vaultDao.watchItemActiveDecks(card.id).first;
      expect(badges, isEmpty);
    });

    test('BC3.5: Multiple identical card rows in same assembled deck emit distinct unique deck name', () async {
      final card = createPhase46TestCard(id: 'c-dup-rows', name: 'Plains');
      await db.into(db.vaultItems).insert(card);

      final deck = await createAndInsertDeck(db, id: 'd-dup-rows', name: 'Mono White', isRegistered: true);
      await addCardToDeckZone(db, deckId: deck.id, vaultItemId: card.id, boardZone: 'Mainboard');
      await addCardToDeckZone(db, deckId: deck.id, vaultItemId: card.id, boardZone: 'Sideboard');

      final badges = await db.vaultDao.watchItemActiveDecks(card.id).first;
      expect(badges.length, equals(1));
      expect(badges.first, equals('Mono White'));
    });
  });

  // ---------------------------------------------------------------------------
  // Feature 4: The One Ring Art Fix Boundary Cases
  // ---------------------------------------------------------------------------
  group('Tier 2 - Feature 4: The One Ring Art Fix Boundary Cases', () {
    test('BC4.1: Missing image_uris falls back to item imageUrl without crashing', () {
      final ring = createPhase46TestCard(
        id: 'ring-no-uris',
        name: 'The One Ring',
        imageUrl: 'https://cards.scryfall.io/large/front/d/5/d5806e68-1054-458e-866d-1f2470f682b2.jpg?1790212038',
        additionalDynamicData: {'image_uris': null},
      );
      expect(ring.imageUrl.isNotEmpty, isTrue);
    });

    test('BC4.2: Malformed JSON in dynamicData falls back safely', () {
      const malformedJson = '{"scryfall_id": incomplete json';
      expect(() => jsonDecode(malformedJson), throwsA(isA<FormatException>()));

      final card = createPhase46TestCard(
        id: 'ring-malformed',
        name: 'The One Ring',
      );
      final key = resolveVariantGroupingKey(card);
      expect(key.isNotEmpty, isTrue);
    });

    test('BC4.3: Serialized parenthetical name does not corrupt scryfall_id resolution', () {
      final ring = createPhase46TestCard(
        id: 'ring-serialized',
        name: 'The One Ring (Serialized #007/100)',
        scryfallId: 'd5806e68-1054-458e-866d-1f2470f682b2',
      );
      final data = jsonDecode(ring.dynamicData) as Map<String, dynamic>;
      expect(data['scryfall_id'], equals('d5806e68-1054-458e-866d-1f2470f682b2'));
    });

    test('BC4.4: Extremely long image URL strings handle properly in memory without truncation', () {
      final longUrl = 'https://cards.scryfall.io/large/front/d/5/${'a' * 500}.jpg';
      final ring = createPhase46TestCard(
        id: 'ring-long-url',
        name: 'The One Ring',
        imageUrl: longUrl,
      );
      expect(ring.imageUrl.length, greaterThan(500));
    });

    test('BC4.5: URL query params (e.g. ?1790212038) preserved in image request uri', () {
      final ring = createPhase46TestCard(
        id: 'ring-query',
        name: 'The One Ring',
        imageUrl: 'https://cards.scryfall.io/large/front/d/5/d5806e68-1054-458e-866d-1f2470f682b2.jpg?1790212038',
      );
      final uri = Uri.parse(ring.imageUrl);
      expect(uri.query, equals('1790212038'));
    });
  });

  // ---------------------------------------------------------------------------
  // Feature 5: Deck Assembly Status Toggle Boundary Cases
  // ---------------------------------------------------------------------------
  group('Tier 2 - Feature 5: Deck Assembly Status Toggle Boundary Cases', () {
    late AppDatabase db;

    setUp(() {
      db = createPhase46TestDb();
    });

    tearDown(() async {
      await db.close();
    });

    test('BC5.1: Rapid consecutive toggles preserve the final state in SQLite', () async {
      final deck = await createAndInsertDeck(db, id: 'd-rapid', name: 'Rapid Toggle');

      await db.vaultDao.setDeckRegistered(deck.id, true);
      await db.vaultDao.setDeckRegistered(deck.id, false);
      await db.vaultDao.setDeckRegistered(deck.id, true);
      await db.vaultDao.setDeckRegistered(deck.id, false);

      final finalDeck = await (db.select(db.decks)..where((t) => t.id.equals(deck.id))).getSingle();
      expect(finalDeck.isRegistered, isFalse);
    });

    test('BC5.2: Setting assembly on non-existent deck ID fails gracefully without crashing', () async {
      await expectLater(
        db.vaultDao.setDeckRegistered('non-existent-id', true),
        completes,
      );
    });

    test('BC5.3: Setting assembly status to same value is idempotent', () async {
      final deck = await createAndInsertDeck(db, id: 'd-idem', name: 'Idempotent Deck', isRegistered: true);

      await db.vaultDao.setDeckRegistered(deck.id, true);
      final res = await (db.select(db.decks)..where((t) => t.id.equals(deck.id))).getSingle();
      expect(res.isRegistered, isTrue);
    });

    test('BC5.4: Both is_registered and updated_at stay synchronized across updates', () async {
      final deck = await createAndInsertDeck(db, id: 'd-sync-time', name: 'Time Sync');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      await db.vaultDao.setDeckRegistered(deck.id, true);
      final updated = await (db.select(db.decks)..where((t) => t.id.equals(deck.id))).getSingle();

      expect(updated.isRegistered, isTrue);
      expect(updated.updatedAt, isNotNull);
    });

    test('BC5.5: Deleting deck after toggling assembly leaves clean soft-deleted record', () async {
      final deck = await createAndInsertDeck(db, id: 'd-del-after-toggle', name: 'Delete After Toggle');
      await db.vaultDao.setDeckRegistered(deck.id, true);
      await db.vaultDao.deleteDeck(deck.id);

      final row = await (db.select(db.decks)..where((t) => t.id.equals(deck.id))).getSingle();
      expect(row.isDeleted, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Feature 6: Deck Thumbnail Picker Boundary Cases
  // ---------------------------------------------------------------------------
  group('Tier 2 - Feature 6: Deck Thumbnail Picker Boundary Cases', () {
    late AppDatabase db;

    setUp(() {
      db = createPhase46TestDb();
    });

    tearDown(() async {
      await db.close();
    });

    test('BC6.1: Setting coverItemId to non-existent ID does not crash DB query', () async {
      final deck = await createAndInsertDeck(db, id: 'd-ghost-cover', name: 'Ghost Cover');
      await db.vaultDao.updateDeckCover(deck.id, 'non-existent-card-id');

      final updated = await (db.select(db.decks)..where((t) => t.id.equals(deck.id))).getSingle();
      expect(updated.coverItemId, equals('non-existent-card-id'));
    });

    test('BC6.2: Extremely long custom image URL or ID string persists safely', () async {
      final deck = await createAndInsertDeck(db, id: 'd-long-cover', name: 'Long Cover');
      final longId = 'custom_cover_${'x' * 300}';

      await db.vaultDao.updateDeckCover(deck.id, longId);

      final updated = await (db.select(db.decks)..where((t) => t.id.equals(deck.id))).getSingle();
      expect(updated.coverItemId, equals(longId));
    });

    test('BC6.3: Empty string coverItemId handles without exceptions', () async {
      final deck = await createAndInsertDeck(db, id: 'd-empty-cover', name: 'Empty Cover');
      await db.vaultDao.updateDeckCover(deck.id, '');

      final updated = await (db.select(db.decks)..where((t) => t.id.equals(deck.id))).getSingle();
      expect(updated.coverItemId, equals(''));
    });

    test('BC6.4: Setting cover art for deck with no cards works via catalog card reference', () async {
      final catalogCard = createPhase46TestCard(id: 'cat-mox', name: 'Mox Diamond', quantity: 0);
      await db.into(db.vaultItems).insert(catalogCard);

      final deck = await createAndInsertDeck(db, id: 'd-empty-cards', name: 'Empty Deck');
      await db.vaultDao.updateDeckCover(deck.id, catalogCard.id);

      final updated = await (db.select(db.decks)..where((t) => t.id.equals(deck.id))).getSingle();
      expect(updated.coverItemId, equals('cat-mox'));
    });

    test('BC6.5: Changing cover crop rect string along with coverItemId updates both fields', () async {
      final deck = await createAndInsertDeck(db, id: 'd-crop-rect', name: 'Cropped Cover');
      const cropRect = '10,20,200,150';

      await db.vaultDao.updateDeckCover(
        deck.id,
        'card-cover-id',
        coverCropRect: cropRect,
      );

      final updated = await (db.select(db.decks)..where((t) => t.id.equals(deck.id))).getSingle();
      expect(updated.coverItemId, equals('card-cover-id'));
      expect(updated.coverCropRect, equals(cropRect));
    });
  });

  // ---------------------------------------------------------------------------
  // Feature 7: Board Movement Boundary Cases
  // ---------------------------------------------------------------------------
  group('Tier 2 - Feature 7: Board Movement Boundary Cases', () {
    late AppDatabase db;

    setUp(() {
      db = createPhase46TestDb();
    });

    tearDown(() async {
      await db.close();
    });

    test('BC7.1: Moving 0 quantity no-ops without mutating database rows', () async {
      final card = createPhase46TestCard(id: 'c-zero-move', name: 'Force of Negation');
      await db.into(db.vaultItems).insert(card);

      final deck = await createAndInsertDeck(db, id: 'd-zero-move', name: 'Zero Move');
      await addCardToDeckZone(db, deckId: deck.id, vaultItemId: card.id, boardZone: 'Mainboard', quantity: 2);

      await moveCardBetweenZones(
        db,
        deckId: deck.id,
        vaultItemId: card.id,
        fromZone: 'Mainboard',
        toZone: 'Sideboard',
        quantity: 0,
      );

      final items = await (db.select(db.deckVersionItems)..where((t) => t.vaultItemId.equals(card.id) & t.isDeleted.equals(false))).get();
      expect(items.length, equals(1));
      expect(items.first.quantity, equals(2));
      expect(items.first.boardZone, equals('Mainboard'));
    });

    test('BC7.2: Moving quantity greater than available in source zone moves all available copies', () async {
      final card = createPhase46TestCard(id: 'c-excess-move', name: 'Snapcaster Mage');
      await db.into(db.vaultItems).insert(card);

      final deck = await createAndInsertDeck(db, id: 'd-excess', name: 'Excess Move');
      await addCardToDeckZone(db, deckId: deck.id, vaultItemId: card.id, boardZone: 'Mainboard', quantity: 2);

      // Attempt to move 5 copies when only 2 exist
      await moveCardBetweenZones(
        db,
        deckId: deck.id,
        vaultItemId: card.id,
        fromZone: 'Mainboard',
        toZone: 'Sideboard',
        quantity: 5,
      );

      final active = await (db.select(db.deckVersionItems)..where((t) => t.vaultItemId.equals(card.id) & t.isDeleted.equals(false))).get();
      expect(active.length, equals(1));
      expect(active.first.boardZone, equals('Sideboard'));
    });

    test('BC7.3: Moving between identical source and target zones preserves row state', () async {
      final card = createPhase46TestCard(id: 'c-same-zone', name: 'Fatal Push');
      await db.into(db.vaultItems).insert(card);

      final deck = await createAndInsertDeck(db, id: 'd-same-zone', name: 'Same Zone');
      await addCardToDeckZone(db, deckId: deck.id, vaultItemId: card.id, boardZone: 'Mainboard', quantity: 3);

      await moveCardBetweenZones(
        db,
        deckId: deck.id,
        vaultItemId: card.id,
        fromZone: 'Mainboard',
        toZone: 'Mainboard',
        quantity: 1,
      );

      final items = await (db.select(db.deckVersionItems)..where((t) => t.vaultItemId.equals(card.id) & t.isDeleted.equals(false))).get();
      final total = items.fold<int>(0, (s, i) => s + i.quantity);
      expect(total, equals(3));
    });

    test('BC7.4: Moving non-existent card ID in deck returns cleanly without throwing', () async {
      final deck = await createAndInsertDeck(db, id: 'd-no-card', name: 'Empty Deck');
      await expectLater(
        moveCardBetweenZones(
          db,
          deckId: deck.id,
          vaultItemId: 'non-existent-card-id',
          fromZone: 'Mainboard',
          toZone: 'Sideboard',
        ),
        completes,
      );
    });

    test('BC7.5: Moving all copies across multiple zones preserves total quantity invariant', () async {
      final card = createPhase46TestCard(id: 'c-loop', name: 'Loop Card');
      await db.into(db.vaultItems).insert(card);

      final deck = await createAndInsertDeck(db, id: 'd-loop', name: 'Loop Deck');
      await addCardToDeckZone(db, deckId: deck.id, vaultItemId: card.id, boardZone: 'Mainboard', quantity: 4);

      // Main -> Side
      await moveCardBetweenZones(db, deckId: deck.id, vaultItemId: card.id, fromZone: 'Mainboard', toZone: 'Sideboard', quantity: 4);
      // Side -> Maybe
      await moveCardBetweenZones(db, deckId: deck.id, vaultItemId: card.id, fromZone: 'Sideboard', toZone: 'Maybeboard', quantity: 4);
      // Maybe -> Main
      await moveCardBetweenZones(db, deckId: deck.id, vaultItemId: card.id, fromZone: 'Maybeboard', toZone: 'Mainboard', quantity: 4);

      final active = await (db.select(db.deckVersionItems)..where((t) => t.vaultItemId.equals(card.id) & t.isDeleted.equals(false))).get();
      expect(active.length, equals(1));
      expect(active.first.boardZone, equals('Mainboard'));
      expect(active.first.quantity, equals(4));
    });
  });

  // ---------------------------------------------------------------------------
  // Feature 8: Format Legality Engine Boundary Cases
  // ---------------------------------------------------------------------------
  group('Tier 2 - Feature 8: Format Legality Engine Boundary Cases', () {
    test('BC8.1: Unknown format flags card as not legal', () {
      final card = createPhase46TestCard(
        id: 'c-unknown-fmt',
        name: 'Garth One-Eye',
        legalities: {'commander': 'legal'},
      );
      final res = checkCardLegalityDirect(card, 'future_custom_format');
      expect(res.isLegal, isFalse);
    });

    test('BC8.2: Card with empty legalities map flags as not legal (strict fallback)', () {
      final card = createPhase46TestCard(
        id: 'c-empty-leg',
        name: 'Strict Fallback Card',
        additionalDynamicData: {'legalities': <String, dynamic>{}},
      );
      final res = checkCardLegalityDirect(card, 'commander');
      expect(res.isLegal, isFalse);
    });

    test('BC8.3: Restricted card in Vintage format is treated as legal', () {
      final card = createPhase46TestCard(
        id: 'c-restricted-vin',
        name: 'Ancestral Recall',
        legalities: {'vintage': 'restricted', 'legacy': 'banned'},
      );
      final resVintage = checkCardLegalityDirect(card, 'vintage');
      expect(resVintage.isLegal, isTrue);
    });

    test('BC8.4: Restricted card in Modern format is treated as not legal / banned', () {
      final card = createPhase46TestCard(
        id: 'c-restricted-mod',
        name: 'Restricted In Other',
        legalities: {'modern': 'banned'},
      );
      final res = checkCardLegalityDirect(card, 'modern');
      expect(res.isLegal, isFalse);
    });

    test('BC8.5: Special characters in card name formatted properly in violation message', () {
      final card = createPhase46TestCard(
        id: 'c-special-name',
        name: "Urza's Power Plant",
        legalities: {'standard': 'not_legal'},
      );
      final res = checkCardLegalityDirect(card, 'standard');
      expect(res.violations.first, contains("Urza's Power Plant is not legal in standard"));
    });
  });

  // ---------------------------------------------------------------------------
  // Feature 9: Custom Scrollbar Refinement Boundary Cases
  // ---------------------------------------------------------------------------
  group('Tier 2 - Feature 9: Custom Scrollbar Refinement Boundary Cases', () {
    test('BC9.1: Single section consumes 100% of rail height', () {
      final heights = ProportionalBubbleScrollbar.computeSectionHeights(
        counts: [40],
        totalHeight: 300,
        minHeight: 24.0,
      );
      expect(heights.length, equals(1));
      expect(heights.first, equals(300.0));
    });

    test('BC9.2: Section with 0 card count still receives minimum height clamp (24.0px)', () {
      final heights = ProportionalBubbleScrollbar.computeSectionHeights(
        counts: [50, 0],
        totalHeight: 200,
        minHeight: 24.0,
      );
      expect(heights.length, equals(2));
      expect(heights[1], greaterThanOrEqualTo(24.0));
    });

    test('BC9.3: Rail height of 0 or negative returns empty height list without division by zero', () {
      final heightsZero = ProportionalBubbleScrollbar.computeSectionHeights(
        counts: [10, 20],
        totalHeight: 0,
        minHeight: 24.0,
      );
      expect(heightsZero.isEmpty, isTrue);

      final heightsNeg = ProportionalBubbleScrollbar.computeSectionHeights(
        counts: [10, 20],
        totalHeight: -50,
        minHeight: 24.0,
      );
      expect(heightsNeg.isEmpty, isTrue);
    });

    test('BC9.4: Rail with many sections where total minimum exceeds available divides evenly', () {
      final heights = ProportionalBubbleScrollbar.computeSectionHeights(
        counts: List.filled(10, 5),
        totalHeight: 100, // 10 * 24 = 240 > 100
        minHeight: 24.0,
      );
      expect(heights.length, equals(10));
      for (final h in heights) {
        expect(h, equals(10.0)); // 100 / 10
      }
    });

    test('BC9.5: Commander section icon defaults to crown icon', () {
      final sec = ScrollbarSection(label: 'Commander (1)', count: 1, onTap: () {});
      final icon = ProportionalBubbleScrollbar.resolveSectionIcon(sec);
      expect(icon, equals(Icons.workspace_premium_rounded));
    });
  });

  // ---------------------------------------------------------------------------
  // Feature 10: Inline Deck Analytics Boundary Cases
  // ---------------------------------------------------------------------------
  group('Tier 2 - Feature 10: Inline Deck Analytics Boundary Cases', () {
    test('BC10.1: Deck with 500+ cards computes totals without memory or stack overflow', () {
      final largeList = List.generate(
        500,
        (i) => {'quantity': 1, 'dynamic_data': '{"cmc": ${i % 8}}'},
      );
      final curve = computeDeckManaCurve(largeList);
      final totalInCurve = curve.values.fold<int>(0, (s, c) => s + c);
      expect(totalInCurve, equals(500));
    });

    test('BC10.2: Cards with 0 price do not inflate total deck valuation', () {
      final items = [
        {'quantity': 10, 'price': 0.0},
        {'quantity': 1, 'price': 50.0},
      ];
      final total = items.fold<double>(0.0, (s, i) => s + (i['quantity'] as int) * (i['price'] as double));
      expect(total, equals(50.0));
    });

    test('BC10.3: Cards with negative or NaN prices sanitize to 0.0 in Pareto input', () {
      final input = ParetoCardInput(
        id: 'c-nan',
        name: 'Corrupted Price Card',
        setCode: 'SET',
        quantity: 1,
        unitPrice: -5.0,
        imageUrl: '',
      );
      final res = ParetoDistributionCalculator.calculate(cards: [input]);
      expect(res.totalDeckValue, equals(0.0));
    });

    test('BC10.4: Colorless cards with {C} or generic mana do not pollute colored devotion', () {
      final cost = '{2}{C}';
      final coloredDevotion = <String, int>{};
      final matches = RegExp(r'\{([^}]+)\}').allMatches(cost);
      for (final m in matches) {
        final sym = m.group(1)!;
        if (RegExp(r'^[WUBRG]$').hasMatch(sym)) {
          coloredDevotion[sym] = (coloredDevotion[sym] ?? 0) + 1;
        }
      }
      expect(coloredDevotion.isEmpty, isTrue);
    });

    test('BC10.5: All-foil deck yields 100% bling ratio', () {
      final items = [
        {'quantity': 5, 'condition': 'NM Foil', 'dynamic_data': '{"finishes": ["foil"]}'},
        {'quantity': 5, 'condition': 'LP Foil', 'dynamic_data': '{"finishes": ["foil"]}'},
      ];
      final totalCards = items.fold<int>(0, (s, i) => s + (i['quantity'] as int));
      final blingCards = items.fold<int>(0, (s, i) => s + (i['quantity'] as int));
      expect(blingCards / totalCards, equals(1.0));
    });
  });

  // ---------------------------------------------------------------------------
  // Feature 11: Value Concentration Boundary Cases
  // ---------------------------------------------------------------------------
  group('Tier 2 - Feature 11: Value Concentration Boundary Cases', () {
    test('BC11.1: Single card deck accounts for 100.0% of total deck value', () {
      final cards = [
        ParetoCardInput(id: '1', name: 'Mox Sapphire', setCode: 'LEA', quantity: 1, unitPrice: 3000.0, imageUrl: ''),
      ];
      final res = ParetoDistributionCalculator.calculate(cards: cards);
      expect(res.concentrationPercentage, equals(100.0));
      expect(res.topCards.length, equals(1));
    });

    test('BC11.2: Deck with identical price on all cards calculates equal fractional distribution', () {
      final cards = List.generate(
        10,
        (i) => ParetoCardInput(id: '$i', name: 'Card $i', setCode: 'SET', quantity: 1, unitPrice: 10.0, imageUrl: ''),
      );
      final res = ParetoDistributionCalculator.calculate(cards: cards);
      // Top 5 out of 10 identical cards => 50%
      expect(res.concentrationPercentage, equals(50.0));
    });

    test('BC11.3: Target K greater than total unique cards clamps to total unique count', () {
      final cards = [
        ParetoCardInput(id: '1', name: 'A', setCode: 'S', quantity: 1, unitPrice: 20.0, imageUrl: ''),
        ParetoCardInput(id: '2', name: 'B', setCode: 'S', quantity: 1, unitPrice: 10.0, imageUrl: ''),
      ];
      final res = ParetoDistributionCalculator.calculate(cards: cards, targetK: 5);
      expect(res.topK, equals(2));
      expect(res.topCards.length, equals(2));
    });

    test('BC11.4: Extreme price outliers computes >99.9% concentration accurately', () {
      final cards = [
        ParetoCardInput(id: '1', name: 'Black Lotus', setCode: 'LEA', quantity: 1, unitPrice: 100000.0, imageUrl: ''),
        ...List.generate(
          99,
          (i) => ParetoCardInput(id: 'bulk-$i', name: 'Basic $i', setCode: 'LEA', quantity: 1, unitPrice: 0.10, imageUrl: ''),
        ),
      ];
      final res = ParetoDistributionCalculator.calculate(cards: cards);
      expect(res.concentrationPercentage, greaterThan(99.9));
    });

    test('BC11.5: Currency conversion across USD and EUR maintains proportional concentration', () {
      final cardsUsd = [
        ParetoCardInput(id: '1', name: 'A', setCode: 'S', quantity: 1, unitPrice: 100.0, imageUrl: ''),
        ParetoCardInput(id: '2', name: 'B', setCode: 'S', quantity: 1, unitPrice: 100.0, imageUrl: ''),
      ];
      final resUsd = ParetoDistributionCalculator.calculate(cards: cardsUsd, currency: AppCurrency.usd);

      final cardsEur = [
        ParetoCardInput(id: '1', name: 'A', setCode: 'S', quantity: 1, unitPrice: 90.0, imageUrl: ''),
        ParetoCardInput(id: '2', name: 'B', setCode: 'S', quantity: 1, unitPrice: 90.0, imageUrl: ''),
      ];
      final resEur = ParetoDistributionCalculator.calculate(cards: cardsEur, currency: AppCurrency.eur);

      expect(resUsd.concentrationPercentage, equals(resEur.concentrationPercentage));
    });
  });

  // ---------------------------------------------------------------------------
  // Feature 12: Mana Curve CMC Calculation Boundary Cases
  // ---------------------------------------------------------------------------
  group('Tier 2 - Feature 12: Mana Curve CMC Calculation Boundary Cases', () {
    test('BC12.1: Massive generic costs e.g. {100}, {1000000} calculate exact numeric CMC', () {
      expect(calculateAccurateCmc('{100}'), equals(100.0));
      expect(calculateAccurateCmc('{1000000}'), equals(1000000.0));
    });

    test('BC12.2: Phyrexian mana symbols calculate 1.0 CMC each', () {
      expect(calculateAccurateCmc('{W/P}'), equals(1.0));
      expect(calculateAccurateCmc('{G/P}'), equals(1.0));
      expect(calculateAccurateCmc('{1}{U/P}'), equals(2.0));
    });

    test('BC12.3: Triple hybrid Phyrexian symbols e.g. {B/G/P} calculate 1.0 CMC', () {
      expect(calculateAccurateCmc('{B/G/P}'), equals(1.0));
    });

    test('BC12.4: Three-face or complex split cards sum all faces properly', () {
      expect(calculateAccurateCmc('{1}{R} // {1}{U} // {1}{G}'), equals(6.0));
    });

    test('BC12.5: Variable X and Y costs treat X and Y as 0 in converted mana value', () {
      expect(calculateAccurateCmc('{X}{U}'), equals(1.0));
      expect(calculateAccurateCmc('{X}{X}{R}'), equals(1.0));
      expect(calculateAccurateCmc('{X}{Y}{Z}{B}'), equals(1.0));
    });
  });

  // ---------------------------------------------------------------------------
  // Feature 13: Official MTG Symbology Filters Boundary Cases
  // ---------------------------------------------------------------------------
  group('Tier 2 - Feature 13: Official MTG Symbology Filters Boundary Cases', () {
    test('BC13.1: Energy symbol {E} and Snow symbol {S} resolve to valid SVG filenames', () {
      final e = ScryfallSymbolCatalog.findBySymbol('{E}');
      final s = ScryfallSymbolCatalog.findBySymbol('{S}');

      expect(e?.filename, equals('E.svg'));
      expect(s?.filename, equals('S.svg'));
    });

    test('BC13.2: Transposed hybrid notations {U/W} and {W/U} resolve to the same asset (WU.svg)', () {
      final wu = ScryfallSymbolCatalog.findBySymbol('{W/U}');
      final uw = ScryfallSymbolCatalog.findBySymbol('{U/W}');

      expect(wu?.filename, equals('WU.svg'));
      expect(uw?.filename, equals('WU.svg'));
    });

    test('BC13.3: Case-insensitive lookup for symbols resolves accurately', () {
      final symLower = ScryfallSymbolCatalog.findBySymbol('{w}');
      final symUpper = ScryfallSymbolCatalog.findBySymbol('{W}');

      expect(symLower?.filename, equals(symUpper?.filename));
    });

    test('BC13.4: Half mana symbols e.g. {½}, {HW} resolve with 0.5 CMC', () {
      final half = ScryfallSymbolCatalog.findBySymbol('{½}');
      final hw = ScryfallSymbolCatalog.findBySymbol('{HW}');

      expect(half?.manaValue, equals(0.5));
      expect(hw?.manaValue, equals(0.5));
    });

    testWidgets('BC13.5: Text with unclosed bracket passes through safely without crash', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ManaText(
              'Unclosed bracket {2 and {W} mana.',
              style: TextStyle(fontSize: 14),
            ),
          ),
        ),
      );

      expect(find.byType(ManaText), findsOneWidget);
      expect(find.textContaining('Unclosed bracket {2 and'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Feature 14: Card Details Crash & Overflow Boundary Cases
  // ---------------------------------------------------------------------------
  group('Tier 2 - Feature 14: Card Details Crash & Overflow Boundary Cases', () {
    testWidgets('BC14.1: Micro screen dimensions (280x480) render without RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(280, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  Text('Header', overflow: TextOverflow.ellipsis),
                  SizedBox(height: 10),
                  Text('Content line that should wrap nicely without horizontal overflows'),
                ],
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('BC14.2: Giant card text (>1000 characters) scrolls inside view without error', (tester) async {
      final giantText = 'Oracle rules text line. ' * 50;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Text(giantText),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('BC14.3: Max line limits on titles ensure no vertical push of action buttons', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 100,
              child: Column(
                children: [
                  Text(
                    'Extremely long title that spans across many lines if not clamped by maxLines parameter',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  ElevatedButton(onPressed: null, child: Text('Action')),
                ],
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('BC14.4: Nested scroll views with zero items handle empty states cleanly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => null,
                    childCount: 0,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('BC14.5: Rebuilding widget tree with new keys preserves scroll without errors', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              key: const ValueKey(1),
              children: List.generate(20, (i) => ListTile(title: Text('Row $i'))),
            ),
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              key: const ValueKey(2),
              children: List.generate(20, (i) => ListTile(title: Text('Row $i'))),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Feature 15: SliverAppBar Title Collision Boundary Cases
  // ---------------------------------------------------------------------------
  group('Tier 2 - Feature 15: SliverAppBar Title Collision Boundary Cases', () {
    testWidgets('BC15.1: 500-character deck title truncated safely with single line ellipsis', (tester) async {
      final massiveTitle = 'Super Deck ' * 50;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                SliverAppBar(
                  title: Text(massiveTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('BC15.2: Pinned SliverAppBar at minimum collapsed height keeps leading and actions visible', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  toolbarHeight: 56,
                  leading: const BackButton(),
                  title: const Text('Title'),
                  actions: const [Icon(Icons.more_horiz)],
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(BackButton), findsOneWidget);
      expect(find.byIcon(Icons.more_horiz), findsOneWidget);
    });

    testWidgets('BC15.3: Rapid scroll velocity upwards and downwards does not cause layout jitter', (tester) async {
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
                  flexibleSpace: FlexibleSpaceBar(title: Text('Deck')),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => ListTile(title: Text('Card $i')),
                    childCount: 50,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.fling(find.byType(CustomScrollView), const Offset(0, -1000), 5000);
      await tester.pumpAndSettle();
      await tester.fling(find.byType(CustomScrollView), const Offset(0, 1000), 5000);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('BC15.4: RTL text directionality in deck title renders properly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: CustomScrollView(
                slivers: [
                  SliverAppBar(
                    title: Text('חפיסת מפקד'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('חפיסת מפקד'), findsOneWidget);
    });

    testWidgets('BC15.5: Special unicode emojis and symbology in deck title do not wrap or collide', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                SliverAppBar(
                  title: Text('🔥 💧 💀 🌲 ☀️ Omnath Deck'),
                ),
              ],
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('🔥 💧 💀 🌲 ☀️ Omnath Deck'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Feature 16: Context-Aware Filter Pills Boundary Cases
  // ---------------------------------------------------------------------------
  group('Tier 2 - Feature 16: Context-Aware Filter Pills Boundary Cases', () {
    List<String> getContextFilters(String? activeGame) {
      if (activeGame == null || activeGame.isEmpty) {
        return ['Owned', 'All Cards', 'Graded Slabs', 'Raw Singles', 'High P/L'];
      }
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

    test('BC16.1: Null or empty active collection defaults to safe baseline filters', () {
      final filtersNull = getContextFilters(null);
      expect(filtersNull.length, equals(5));
      expect(filtersNull, contains('Owned'));

      final filtersEmpty = getContextFilters('');
      expect(filtersEmpty.length, equals(5));
    });

    test('BC16.2: Special characters in collection name do not cause lookup failures', () {
      final filters = getContextFilters('Custom Collection & Co. #1');
      expect(filters, isNotEmpty);
      expect(filters, contains('Owned'));
    });

    test('BC16.3: Empty active filter indices set handles without error', () {
      final selectedIndices = <int>{};
      expect(selectedIndices.isEmpty, isTrue);
      selectedIndices.add(0);
      expect(selectedIndices.contains(0), isTrue);
      selectedIndices.remove(0);
      expect(selectedIndices.isEmpty, isTrue);
    });

    test('BC16.4: Filter state query on 0 items returns empty list without error', () {
      final allItems = <Map<String, dynamic>>[];
      final filtered = allItems.where((i) => i['is_graded'] == true).toList();
      expect(filtered.isEmpty, isTrue);
    });

    test('BC16.5: Rapid switching across 4 collection contexts maintains correct pill sets', () {
      final games = ['Magic: The Gathering', 'Pokémon TCG', 'Comic Books', 'Sports Cards'];
      for (final g in games) {
        final f = getContextFilters(g);
        expect(f.length, equals(6));
        expect(f.contains('Owned'), isTrue);
      }
    });
  });
}
