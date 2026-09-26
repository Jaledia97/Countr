import 'dart:async';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/domain/models/deck_summary.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/decks/presentation/widgets/deck_thumbnail_picker_modal.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/domain/models/card_availability.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  // Helper to insert a basic MTG card into vault_items
  Future<void> insertTestCard({
    required String id,
    required String name,
    int quantity = 1,
    String? imageUrl,
    String? dynamicData,
    bool isDeleted = false,
  }) async {
    final now = DateTime.now();
    await db.into(db.vaultItems).insert(
      VaultItemsCompanion(
        id: drift.Value(id),
        collectionType: const drift.Value('mtg'),
        name: drift.Value(name),
        setOrSeries: const drift.Value('LTR'),
        imageUrl: drift.Value(imageUrl ?? 'https://cards.scryfall.io/art_crop/card_$id.jpg'),
        currentMarketPrice: const drift.Value(10.0),
        acquiredPrice: const drift.Value(8.0),
        acquiredDate: drift.Value(now),
        lastPriceUpdate: drift.Value(now),
        condition: const drift.Value('NM'),
        quantity: drift.Value(quantity),
        isDeleted: drift.Value(isDeleted),
        dynamicData: drift.Value(dynamicData ?? '{"color_identity":["U"]}'),
      ),
    );
  }

  // Helper to insert a deck with active version
  Future<void> insertTestDeck({
    required String id,
    required String name,
    String format = 'Commander',
    bool isRegistered = false,
    bool isAssembled = false,
    String? coverItemId,
    String? coverCropRect,
    bool isDeleted = false,
  }) async {
    final now = DateTime.now();
    await db.into(db.decks).insert(
      DecksCompanion(
        id: drift.Value(id),
        name: drift.Value(name),
        format: drift.Value(format),
        tcgDomain: const drift.Value('mtg'),
        isRegistered: drift.Value(isRegistered),
        isAssembled: drift.Value(isAssembled),
        coverItemId: drift.Value(coverItemId),
        coverCropRect: drift.Value(coverCropRect),
        isCompetitive: const drift.Value(false),
        isDeleted: drift.Value(isDeleted),
        createdAt: drift.Value(now),
      ),
    );
    await db.into(db.deckVersions).insert(
      DeckVersionsCompanion(
        id: drift.Value('ver_$id'),
        deckId: drift.Value(id),
        versionNumber: const drift.Value(1),
        isActive: const drift.Value(true),
        createdAt: drift.Value(now),
        isDeleted: drift.Value(isDeleted),
      ),
    );
  }

  // Helper to add card to deck version
  Future<void> addCardToVersion({
    required String dviId,
    required String versionId,
    required String cardId,
    int quantity = 1,
    String boardZone = 'Mainboard',
    bool isProxy = false,
    bool isDeleted = false,
  }) async {
    await db.into(db.deckVersionItems).insert(
      DeckVersionItemsCompanion(
        id: drift.Value(dviId),
        versionId: drift.Value(versionId),
        vaultItemId: drift.Value(cardId),
        quantity: drift.Value(quantity),
        boardZone: drift.Value(boardZone),
        isProxy: drift.Value(isProxy),
        isDeleted: drift.Value(isDeleted),
      ),
    );
  }

  // ===========================================================================
  // GROUP 1: setDeckRegistered / setDeckAssembled Flapping & Invariants
  // ===========================================================================
  group('Empirical Challenge Group 1: Assembly Toggling & Availability Invariants', () {
    test('1.1: Rapid flapping of setDeckRegistered / setDeckAssembled (50 iterations) preserves Owned = Available + InDeck without leakage', () async {
      await insertTestCard(id: 'sol-ring', name: 'Sol Ring', quantity: 3);
      await insertTestDeck(id: 'deck-1', name: 'Deck 1', isRegistered: false, isAssembled: false);
      await addCardToVersion(dviId: 'dvi-1', versionId: 'ver_deck-1', cardId: 'sol-ring', quantity: 2);

      // Listen to availability stream
      final availabilityList = <Map<String, CardAvailability>>[];
      final sub = dao.watchAllCardAvailability().listen(availabilityList.add);

      // Flap 50 times sequentially
      for (int i = 0; i < 50; i++) {
        final toggle = (i % 2 == 0); // true then false then true...
        if (i % 4 == 0) {
          await dao.setDeckAssembled('deck-1', toggle);
        } else {
          await dao.setDeckRegistered('deck-1', toggle);
        }

        // Verify deck status in SQLite
        final deck = await (db.select(db.decks)..where((t) => t.id.equals('deck-1'))).getSingle();
        expect(deck.isRegistered, equals(toggle));
        expect(deck.isAssembled, equals(toggle));
      }

      await Future.delayed(const Duration(milliseconds: 50));
      await sub.cancel();

      // Final check: since 49 is odd, toggle was false!
      final finalDeck = await (db.select(db.decks)..where((t) => t.id.equals('deck-1'))).getSingle();
      expect(finalDeck.isRegistered, isFalse);

      // Check final availability
      final streamMap = await dao.watchAllCardAvailability().first;
      final solAvail = streamMap['sol-ring']!;
      expect(solAvail.owned, equals(3));
      expect(solAvail.available, equals(3));
      expect(solAvail.inDeck, equals(0));
      expect(solAvail.owned, equals(solAvail.available + solAvail.inDeck));

      // Now toggle to true
      await dao.setDeckAssembled('deck-1', true);
      final assembledMap = await dao.watchAllCardAvailability().first;
      final solAvail2 = assembledMap['sol-ring']!;
      expect(solAvail2.owned, equals(3));
      expect(solAvail2.available, equals(1));
      expect(solAvail2.inDeck, equals(2));
      expect(solAvail2.owned, equals(solAvail2.available + solAvail2.inDeck));
    });

    test('1.2: Multi-deck flapping cross-allocation between 2 decks retains strict partitioning', () async {
      await insertTestCard(id: 'mana-crypt', name: 'Mana Crypt', quantity: 2);
      await insertTestDeck(id: 'deck-a', name: 'Deck A');
      await insertTestDeck(id: 'deck-b', name: 'Deck B');
      await addCardToVersion(dviId: 'dvi-a', versionId: 'ver_deck-a', cardId: 'mana-crypt', quantity: 1);
      await addCardToVersion(dviId: 'dvi-b', versionId: 'ver_deck-b', cardId: 'mana-crypt', quantity: 1);

      // Both assembled
      await dao.setDeckAssembled('deck-a', true);
      await dao.setDeckAssembled('deck-b', true);

      var avail = (await dao.watchAllCardAvailability().first)['mana-crypt']!;
      expect(avail.owned, equals(2));
      expect(avail.inDeck, equals(2));
      expect(avail.available, equals(0));

      var badges = (await dao.watchAllCardActiveDecks().first)['mana-crypt']!;
      expect(badges, containsAll(['Deck A', 'Deck B']));

      // Disassemble Deck A
      await dao.setDeckRegistered('deck-a', false);
      avail = (await dao.watchAllCardAvailability().first)['mana-crypt']!;
      expect(avail.owned, equals(2));
      expect(avail.inDeck, equals(1));
      expect(avail.available, equals(1));

      badges = (await dao.watchAllCardActiveDecks().first)['mana-crypt']!;
      expect(badges, equals(['Deck B']));

      // Disassemble Deck B
      await dao.setDeckAssembled('deck-b', false);
      avail = (await dao.watchAllCardAvailability().first)['mana-crypt']!;
      expect(avail.owned, equals(2));
      expect(avail.inDeck, equals(0));
      expect(avail.available, equals(2));

      badges = (await dao.watchAllCardActiveDecks().first)['mana-crypt'] ?? [];
      expect(badges, isEmpty);
    });

    test('1.3: Soft-deleted deck with is_assembled=true releases allocations immediately', () async {
      await insertTestCard(id: 'rhystic-study', name: 'Rhystic Study', quantity: 1);
      await insertTestDeck(id: 'deck-del', name: 'Deleted Deck', isRegistered: true, isAssembled: true);
      await addCardToVersion(dviId: 'dvi-rs', versionId: 'ver_deck-del', cardId: 'rhystic-study', quantity: 1);

      var avail = (await dao.watchAllCardAvailability().first)['rhystic-study']!;
      expect(avail.inDeck, equals(1));
      expect(avail.available, equals(0));

      // Soft delete deck
      final now = DateTime.now();
      await (db.update(db.decks)..where((t) => t.id.equals('deck-del'))).write(
        DecksCompanion(isDeleted: const drift.Value(true), updatedAt: drift.Value(now)),
      );

      avail = (await dao.watchAllCardAvailability().first)['rhystic-study']!;
      expect(avail.inDeck, equals(0));
      expect(avail.available, equals(1));

      final badges = (await dao.watchAllCardActiveDecks().first)['rhystic-study'] ?? [];
      expect(badges, isEmpty);
    });

    test('1.4: Proxy card allocations in assembled deck are strictly ignored by availability and badges', () async {
      await insertTestCard(id: 'black-lotus', name: 'Black Lotus', quantity: 1);
      await insertTestDeck(id: 'deck-proxy', name: 'Proxy Deck', isRegistered: true, isAssembled: true);
      await addCardToVersion(dviId: 'dvi-bl-proxy', versionId: 'ver_deck-proxy', cardId: 'black-lotus', quantity: 1, isProxy: true);

      final avail = (await dao.watchAllCardAvailability().first)['black-lotus']!;
      expect(avail.owned, equals(1));
      expect(avail.inDeck, equals(0));
      expect(avail.available, equals(1));

      final badges = (await dao.watchAllCardActiveDecks().first)['black-lotus'] ?? [];
      expect(badges, isEmpty);
    });

    test('1.5: Inactive versions in assembled deck do not lock physical inventory', () async {
      await insertTestCard(id: 'mox-opal', name: 'Mox Opal', quantity: 2);
      await insertTestDeck(id: 'deck-ver', name: 'Version Deck', isRegistered: true, isAssembled: true);

      // Create inactive version
      final now = DateTime.now();
      await db.into(db.deckVersions).insert(
        DeckVersionsCompanion(
          id: const drift.Value('ver-inactive'),
          deckId: const drift.Value('deck-ver'),
          versionNumber: const drift.Value(2),
          isActive: const drift.Value(false),
          createdAt: drift.Value(now),
        ),
      );
      await addCardToVersion(dviId: 'dvi-inactive', versionId: 'ver-inactive', cardId: 'mox-opal', quantity: 2);

      final avail = (await dao.watchAllCardAvailability().first)['mox-opal']!;
      expect(avail.inDeck, equals(0));
      expect(avail.available, equals(2));
    });

    test('1.6: Over-allocated physical card clamps available_quantity strictly to 0 without underflow', () async {
      await insertTestCard(id: 'over-card', name: 'Overallocated Card', quantity: 1);
      await insertTestDeck(id: 'deck-over', name: 'Overallocated Deck', isRegistered: true, isAssembled: true);
      await addCardToVersion(dviId: 'dvi-over', versionId: 'ver_deck-over', cardId: 'over-card', quantity: 5);

      final avail = (await dao.watchAllCardAvailability().first)['over-card']!;
      expect(avail.owned, equals(1));
      expect(avail.inDeck, equals(5));
      expect(avail.available, equals(0)); // Clamped by MAX(0, vi.quantity - alloc)
    });

    test('1.7: SyncQueue emits UPDATE record on every setDeckRegistered and setDeckAssembled', () async {
      await insertTestDeck(id: 'deck-sync', name: 'Sync Deck');
      await dao.setDeckRegistered('deck-sync', true);
      await dao.setDeckAssembled('deck-sync', false);

      final queue = await db.select(db.syncQueue).get();
      final deckEntries = queue.where((e) => e.entityId == 'deck-sync' && e.entityType == 'deck').toList();
      expect(deckEntries.length, equals(2));
      expect(deckEntries[0].operation, equals('UPDATE'));
      expect(deckEntries[1].operation, equals('UPDATE'));
    });
  });

  // ===========================================================================
  // GROUP 2: updateDeckCover Stress Testing & Edge Cases
  // ===========================================================================
  group('Empirical Challenge Group 2: updateDeckCover Robustness & Fallback', () {
    test('2.1: Non-existent card ID falls back safely to commander art without NPE', () async {
      await insertTestCard(id: 'cmd-card', name: 'Atraxa', imageUrl: 'https://scryfall.io/atraxa.jpg');
      await insertTestDeck(id: 'deck-cover-1', name: 'Cover Deck 1');
      await addCardToVersion(dviId: 'dvi-cmd', versionId: 'ver_deck-cover-1', cardId: 'cmd-card', boardZone: 'Commander');

      // Set cover to non-existent UUID
      await dao.updateDeckCover('deck-cover-1', 'completely-non-existent-uuid-999');

      final summaries = await dao.getDeckSummaries();
      expect(summaries.length, equals(1));
      final s = summaries.first;
      expect(s.id, equals('deck-cover-1'));
      expect(s.coverItemId, equals('completely-non-existent-uuid-999'));
      // Gracefully falls back to Commander card!
      expect(s.commanderCardId, equals('cmd-card'));
      expect(s.commanderName, equals('Atraxa'));
      expect(s.commanderImageUrl, equals('https://scryfall.io/atraxa.jpg'));
    });

    test('2.2: Soft-deleted cover card falls back cleanly to Commander art', () async {
      await insertTestCard(id: 'cmd-card-2', name: 'Urza', imageUrl: 'https://scryfall.io/urza.jpg');
      await insertTestCard(id: 'cover-card-del', name: 'Temporary Cover', imageUrl: 'https://scryfall.io/cover.jpg');
      await insertTestDeck(id: 'deck-cover-2', name: 'Cover Deck 2');
      await addCardToVersion(dviId: 'dvi-cmd-2', versionId: 'ver_deck-cover-2', cardId: 'cmd-card-2', boardZone: 'Commander');

      // Set cover to cover-card-del
      await dao.updateDeckCover('deck-cover-2', 'cover-card-del');

      // Verify custom cover is active
      var s = (await dao.getDeckSummaries()).first;
      expect(s.commanderCardId, equals('cover-card-del'));
      expect(s.commanderName, equals('Temporary Cover'));
      expect(s.commanderImageUrl, equals('https://scryfall.io/cover.jpg'));

      // Soft delete cover-card-del
      final now = DateTime.now();
      await (db.update(db.vaultItems)..where((t) => t.id.equals('cover-card-del'))).write(
        VaultItemsCompanion(isDeleted: const drift.Value(true), updatedAt: drift.Value(now)),
      );

      // Now query again: LEFT JOIN filter (cover_vi.is_deleted = 0) excludes it!
      s = (await dao.getDeckSummaries()).first;
      expect(s.commanderCardId, equals('cmd-card-2'));
      expect(s.commanderName, equals('Urza'));
      expect(s.commanderImageUrl, equals('https://scryfall.io/urza.jpg'));
    });

    test('2.3: Resetting cover to null reverts to Commander card and clears crop rect', () async {
      await insertTestCard(id: 'cmd-card-3', name: 'Krenko', imageUrl: 'https://scryfall.io/krenko.jpg');
      await insertTestCard(id: 'cover-card-3', name: 'Goblin Guide', imageUrl: 'https://scryfall.io/guide.jpg');
      await insertTestDeck(id: 'deck-cover-3', name: 'Cover Deck 3');
      await addCardToVersion(dviId: 'dvi-cmd-3', versionId: 'ver_deck-cover-3', cardId: 'cmd-card-3', boardZone: 'Commander');

      await dao.updateDeckCover('deck-cover-3', 'cover-card-3', coverCropRect: '{"x":0,"y":0,"w":100,"h":100}');
      var s = (await dao.getDeckSummaries()).first;
      expect(s.coverItemId, equals('cover-card-3'));
      expect(s.coverCropRect, equals('{"x":0,"y":0,"w":100,"h":100}'));

      // Reset to null
      await dao.updateDeckCover('deck-cover-3', null, coverCropRect: null);
      s = (await dao.getDeckSummaries()).first;
      expect(s.coverItemId, isNull);
      expect(s.coverCropRect, isNull);
      expect(s.commanderCardId, equals('cmd-card-3'));
      expect(s.commanderName, equals('Krenko'));
    });

    test('2.4: Catalog reference card (quantity = 0) functions properly as custom cover', () async {
      // Catalog card in vault_items has quantity = 0
      await insertTestCard(
        id: 'cat-card-1',
        name: 'Black Lotus Catalog',
        quantity: 0,
        imageUrl: 'https://scryfall.io/lotus.jpg',
        dynamicData: '{"image_uris":{"art_crop":"https://scryfall.io/lotus_crop.jpg"},"color_identity":[]}',
      );
      await insertTestDeck(id: 'deck-cat', name: 'Catalog Cover Deck');

      await dao.updateDeckCover('deck-cat', 'cat-card-1');
      final s = (await dao.getDeckSummaries()).first;
      expect(s.coverItemId, equals('cat-card-1'));
      expect(s.commanderCardId, equals('cat-card-1'));
      expect(s.commanderName, equals('Black Lotus Catalog'));
      expect(s.commanderArtCrop, equals('https://scryfall.io/lotus_crop.jpg'));
    });

    test('2.5: Hostile crop rect strings (malformed JSON, SQL injection, extreme coordinates) are safely handled', () async {
      await insertTestDeck(id: 'deck-crop', name: 'Crop Deck');

      final hostileStrings = [
        '{"x":-999999999,"y":999999999,"w":0,"h":0}',
        '{"x":"DROP TABLE decks;--"}',
        "' OR '1'='1' --",
        'NaN, Infinity, -Infinity',
        '{"deeply":{"nested":{"malformed":true',
        'a' * 5000, // Very long string
      ];

      for (final hostile in hostileStrings) {
        await dao.updateDeckCover('deck-crop', 'cover-id', coverCropRect: hostile);

        final summaries = await dao.getDeckSummaries();
        expect(summaries.length, equals(1));
        final s = summaries.first;
        expect(s.coverCropRect, equals(hostile));
      }

      // Verify decks table was not dropped!
      final allDecks = await dao.getAllDecks();
      expect(allDecks.any((d) => d.id == 'deck-crop'), isTrue);
    });

    test('2.6: Every updateDeckCover writes an outbox SyncQueue UPDATE record', () async {
      await insertTestDeck(id: 'deck-sync-cov', name: 'Cover Sync Deck');
      await dao.updateDeckCover('deck-sync-cov', 'item-1');
      await dao.updateDeckCover('deck-sync-cov', null);

      final queue = await db.select(db.syncQueue).get();
      final updates = queue.where((e) => e.entityId == 'deck-sync-cov' && e.entityType == 'deck').toList();
      expect(updates.length, equals(2));
      expect(updates[0].operation, equals('UPDATE'));
      expect(updates[1].operation, equals('UPDATE'));
    });
  });

  // ===========================================================================
  // GROUP 3: watchDeckSummaries and getDeckSummaries Query Invariants
  // ===========================================================================
  group('Empirical Challenge Group 3: watchDeckSummaries Query Invariants', () {
    test('3.1: Partner commanders (2 cards in Commander zone) NEVER produce duplicate DeckSummary rows', () async {
      await insertTestCard(id: 'partner-1', name: 'Thrasios, Triton Hero');
      await insertTestCard(id: 'partner-2', name: 'Tymna the Weaver');
      await insertTestDeck(id: 'deck-partner', name: 'Partner Deck');
      await addCardToVersion(dviId: 'dvi-p1', versionId: 'ver_deck-partner', cardId: 'partner-1', boardZone: 'Commander');
      await addCardToVersion(dviId: 'dvi-p2', versionId: 'ver_deck-partner', cardId: 'partner-2', boardZone: 'Commander');

      // Both one-shot and stream queries
      final summaries = await dao.getDeckSummaries();
      expect(summaries.length, equals(1), reason: 'GROUP BY d.id must prevent duplicate rows for partner commanders');

      final streamSummaries = await dao.watchDeckSummaries().first;
      expect(streamSummaries.length, equals(1));
      expect(streamSummaries.first.cardCount, equals(2));
    });

    test('3.2: Multi-version deck (1 active, 2 inactive) produces exactly 1 row', () async {
      await insertTestCard(id: 'c-card', name: 'Forest', quantity: 10);
      await insertTestDeck(id: 'deck-multi-ver', name: 'Multi Version Deck');

      // Active version already added by insertTestDeck
      await addCardToVersion(dviId: 'dvi-act', versionId: 'ver_deck-multi-ver', cardId: 'c-card', quantity: 4);

      // Inactive versions
      final now = DateTime.now();
      await db.into(db.deckVersions).insert(
        DeckVersionsCompanion(
          id: const drift.Value('ver-inact-1'),
          deckId: const drift.Value('deck-multi-ver'),
          versionNumber: const drift.Value(2),
          isActive: const drift.Value(false),
          createdAt: drift.Value(now),
        ),
      );
      await addCardToVersion(dviId: 'dvi-inact-1', versionId: 'ver-inact-1', cardId: 'c-card', quantity: 20);

      final summaries = await dao.getDeckSummaries();
      expect(summaries.length, equals(1));
      // Total card count only includes active version (quantity 4)
      expect(summaries.first.cardCount, equals(4));
    });

    test('3.3: Total card count strictly tallies active deck items, unaffected by external cover_item_id', () async {
      await insertTestCard(id: 'cmd-main', name: 'Commander Card', quantity: 1);
      await insertTestCard(id: 'external-cover', name: 'External Art Card', quantity: 1);
      await insertTestDeck(id: 'deck-count', name: 'Count Deck');
      await addCardToVersion(dviId: 'dvi-m', versionId: 'ver_deck-count', cardId: 'cmd-main', quantity: 1, boardZone: 'Commander');

      // Set cover to external card
      await dao.updateDeckCover('deck-count', 'external-cover');

      final s = (await dao.getDeckSummaries()).first;
      expect(s.commanderCardId, equals('external-cover'));
      // Total cards in deck is 1, not 2
      expect(s.cardCount, equals(1));
    });

    test('3.4: Reactive stream emits immediately when updateDeckCover is called', () async {
      await insertTestCard(id: 'cover-a', name: 'Art A');
      await insertTestCard(id: 'cover-b', name: 'Art B');
      await insertTestDeck(id: 'deck-stream', name: 'Stream Deck');

      final streamEmissions = <List<DeckSummary>>[];
      final sub = dao.watchDeckSummaries().listen(streamEmissions.add);

      await Future.delayed(const Duration(milliseconds: 20));
      await dao.updateDeckCover('deck-stream', 'cover-a');
      await Future.delayed(const Duration(milliseconds: 20));
      await dao.updateDeckCover('deck-stream', 'cover-b');
      await Future.delayed(const Duration(milliseconds: 20));

      await sub.cancel();

      expect(streamEmissions.length, greaterThanOrEqualTo(2));
      expect(streamEmissions.last.first.commanderName, equals('Art B'));
    });

    test('3.5: Empty database returns empty list without throwing errors', () async {
      final summaries = await dao.getDeckSummaries();
      expect(summaries, isEmpty);

      final streamSummaries = await dao.watchDeckSummaries().first;
      expect(streamSummaries, isEmpty);
    });

    test('3.6: Deck with null optional fields constructs DeckSummary cleanly without NPE', () {
      final summary = DeckSummary.fromRow(
        id: 'bare-deck',
        name: 'Bare Deck',
        format: 'Commander',
        tcgDomain: 'mtg',
        isRegistered: false,
        isCompetitive: false,
        createdAt: DateTime.now(),
        coverItemId: null,
        coverCropRect: null,
        activeVersionId: null,
        commanderCardId: null,
        commanderName: null,
        commanderImageUrl: null,
        commanderDynamicData: null,
        cardCount: 0,
      );

      expect(summary.coverItemId, isNull);
      expect(summary.coverCropRect, isNull);
      expect(summary.commanderCardId, isNull);
      expect(summary.commanderArtCrop, isNull);
      expect(summary.completeness, equals(0.0));
      expect(summary.assemblyStatus, equals('Draft'));
      expect(summary.colorIdentity, isEmpty);
    });
  });

  // ===========================================================================
  // GROUP 4: UI Modal & Assembly Toggle Component Tests
  // ===========================================================================
  group('Empirical Challenge Group 4: UI Thumbnail Picker Modal & Assembly Interactions', () {
    testWidgets('4.1: DeckThumbnailPickerModal renders tabs and selects cover card', (tester) async {
      final now = DateTime.now();
      final mockDeck = Deck(
        id: 'test-deck-modal',
        name: 'Modal Test Deck',
        format: 'Commander',
        tcgDomain: 'mtg',
        isRegistered: false,
        isAssembled: false,
        isCompetitive: false,
        wins: 0,
        losses: 0,
        draws: 0,
        isDeleted: false,
        createdAt: now,
      );

      await insertTestCard(id: 'deck-card-1', name: 'Lightning Bolt');
      await insertTestDeck(id: 'test-deck-modal', name: 'Modal Test Deck');
      await addCardToVersion(dviId: 'dvi-modal-1', versionId: 'ver_test-deck-modal', cardId: 'deck-card-1');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vaultDaoProvider.overrideWithValue(dao),
            deckProvider('test-deck-modal').overrideWith((ref) => Stream.value(mockDeck)),
            deckItemsProvider('test-deck-modal').overrideWith(
              (ref) => Stream.value([
                {
                  'id': 'dvi-modal-1',
                  'vault_item_id': 'deck-card-1',
                  'name': 'Lightning Bolt',
                  'image_url': 'https://scryfall.io/bolt.jpg',
                  'dynamic_data': '{}',
                }
              ]),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: DeckThumbnailPickerModal(deck: mockDeck),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('deck_thumbnail_picker_modal')), findsOneWidget);
      expect(find.byKey(const Key('tab_cards_in_deck')), findsOneWidget);
      expect(find.byKey(const Key('tab_search_catalog')), findsOneWidget);
      expect(find.byKey(const Key('cover_card_tile_deck-card-1')), findsOneWidget);

      // Tap on card to select as cover
      await tester.tap(find.byKey(const Key('cover_card_tile_deck-card-1')));
      await tester.pumpAndSettle();

      // Verify in SQLite
      final updated = await (db.select(db.decks)..where((t) => t.id.equals('test-deck-modal'))).getSingle();
      expect(updated.coverItemId, equals('deck-card-1'));
    });

    testWidgets('4.2: DeckThumbnailPickerModal Reset button invokes updateDeckCover with null', (tester) async {
      final now = DateTime.now();
      final mockDeck = Deck(
        id: 'test-deck-reset',
        name: 'Reset Test Deck',
        format: 'Commander',
        tcgDomain: 'mtg',
        isRegistered: false,
        isAssembled: false,
        isCompetitive: false,
        coverItemId: 'existing-cover-id',
        wins: 0,
        losses: 0,
        draws: 0,
        isDeleted: false,
        createdAt: now,
      );

      await insertTestDeck(id: 'test-deck-reset', name: 'Reset Test Deck', coverItemId: 'existing-cover-id');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vaultDaoProvider.overrideWithValue(dao),
            deckProvider('test-deck-reset').overrideWith((ref) => Stream.value(mockDeck)),
            deckItemsProvider('test-deck-reset').overrideWith((ref) => Stream.value([])),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: DeckThumbnailPickerModal(deck: mockDeck),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('reset_deck_cover_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('reset_deck_cover_button')));
      await tester.pumpAndSettle();

      final updated = await (db.select(db.decks)..where((t) => t.id.equals('test-deck-reset'))).getSingle();
      expect(updated.coverItemId, isNull);
    });
  });
}
