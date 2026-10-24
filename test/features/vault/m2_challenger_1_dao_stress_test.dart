import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/domain/models/card_availability.dart';
import 'package:countr/features/vault/presentation/providers/mtg_filter_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Challenger 1 Adversarial Suite: watchAllCardAvailability Isolation & Performance', () {
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

    test('watchAllCardAvailability strictly isolates owned cards (quantity > 0) from 500 catalog items', () async {
      final now = DateTime.now();

      // 1. Seed 500 unowned catalog cards (quantity = 0)
      for (int i = 0; i < 500; i++) {
        await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'catalog-unowned-$i',
            collectionType: 'mtg',
            name: 'Catalog Card $i',
            setOrSeries: 'TEST',
            imageUrl: '',
            acquiredPrice: 0.0,
            acquiredDate: now.subtract(Duration(minutes: i)),
            quantity: const drift.Value(0),
            condition: 'NM',
            currentMarketPrice: 1.0,
            lastPriceUpdate: now,
            dynamicData: '{"colors":["U"],"cmc":2}',
          ),
        );
      }

      // 2. Seed 10 soft-deleted cards (quantity > 0 but isDeleted = true)
      for (int i = 0; i < 10; i++) {
        await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'deleted-card-$i',
            collectionType: 'mtg',
            name: 'Deleted Card $i',
            setOrSeries: 'TEST',
            imageUrl: '',
            acquiredPrice: 5.0,
            acquiredDate: now.subtract(Duration(minutes: 500 + i)),
            quantity: const drift.Value(2),
            condition: 'NM',
            isDeleted: const drift.Value(true),
            currentMarketPrice: 5.0,
            lastPriceUpdate: now,
            dynamicData: '{"colors":["B"],"cmc":3}',
          ),
        );
      }

      // 3. Seed 5 owned cards (quantity > 0)
      // Card 1: 3 copies owned
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'owned-card-1',
          collectionType: 'mtg',
          name: 'Force of Will',
          setOrSeries: 'ALL',
          imageUrl: '',
          acquiredPrice: 50.0,
          acquiredDate: now,
          quantity: const drift.Value(3),
          condition: 'NM',
          currentMarketPrice: 60.0,
          lastPriceUpdate: now,
          dynamicData: '{"colors":["U"],"cmc":5}',
        ),
      );

      // Card 2: 1 copy owned
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'owned-card-2',
          collectionType: 'mtg',
          name: 'Lightning Bolt',
          setOrSeries: 'LEA',
          imageUrl: '',
          acquiredPrice: 2.0,
          acquiredDate: now.subtract(const Duration(minutes: 1)),
          quantity: const drift.Value(1),
          condition: 'NM',
          currentMarketPrice: 3.0,
          lastPriceUpdate: now,
          dynamicData: '{"colors":["R"],"cmc":1}',
        ),
      );

      // Card 3: 4 copies owned
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'owned-card-3',
          collectionType: 'mtg',
          name: 'Birds of Paradise',
          setOrSeries: 'RAV',
          imageUrl: '',
          acquiredPrice: 7.0,
          acquiredDate: now.subtract(const Duration(minutes: 2)),
          quantity: const drift.Value(4),
          condition: 'NM',
          currentMarketPrice: 8.0,
          lastPriceUpdate: now,
          dynamicData: '{"colors":["G"],"cmc":1}',
        ),
      );

      // Card 4: 1 copy owned
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'owned-card-4',
          collectionType: 'mtg',
          name: 'Swords to Plowshares',
          setOrSeries: 'ICE',
          imageUrl: '',
          acquiredPrice: 2.5,
          acquiredDate: now.subtract(const Duration(minutes: 3)),
          quantity: const drift.Value(1),
          condition: 'NM',
          currentMarketPrice: 3.0,
          lastPriceUpdate: now,
          dynamicData: '{"colors":["W"],"cmc":1}',
        ),
      );

      // Card 5: 2 copies owned
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'owned-card-5',
          collectionType: 'mtg',
          name: 'Dark Ritual',
          setOrSeries: 'TMP',
          imageUrl: '',
          acquiredPrice: 1.5,
          acquiredDate: now.subtract(const Duration(minutes: 4)),
          quantity: const drift.Value(2),
          condition: 'NM',
          currentMarketPrice: 2.0,
          lastPriceUpdate: now,
          dynamicData: '{"colors":["B"],"cmc":1}',
        ),
      );

      // 4. Setup Decks & Allocations
      // Deck A: Assembled & Registered deck
      await db.into(db.decks).insert(
        DecksCompanion.insert(
          id: 'deck-assembled',
          name: 'Legacy Delver',
          format: 'Legacy',
          isAssembled: const drift.Value(true),
          isRegistered: const drift.Value(true),
          createdAt: now,
          updatedAt: drift.Value(now),
        ),
      );
      await db.into(db.deckVersions).insert(
        DeckVersionsCompanion.insert(
          id: 'ver-assembled',
          deckId: 'deck-assembled',
          versionNumber: 1,
          isActive: const drift.Value(true),
          createdAt: now,
        ),
      );

      // Deck B: Draft (Unassembled & Unregistered) deck
      await db.into(db.decks).insert(
        DecksCompanion.insert(
          id: 'deck-draft',
          name: 'Cube Draft',
          format: 'Cube',
          isAssembled: const drift.Value(false),
          isRegistered: const drift.Value(false),
          createdAt: now,
          updatedAt: drift.Value(now),
        ),
      );
      await db.into(db.deckVersions).insert(
        DeckVersionsCompanion.insert(
          id: 'ver-draft',
          deckId: 'deck-draft',
          versionNumber: 1,
          isActive: const drift.Value(true),
          createdAt: now,
        ),
      );

      // Allocate Card 1: 2 copies in Deck A (non-proxy)
      await db.into(db.deckVersionItems).insert(
        DeckVersionItemsCompanion.insert(
          id: 'dvi-1',
          versionId: 'ver-assembled',
          vaultItemId: 'owned-card-1',
          boardZone: 'Mainboard',
          quantity: const drift.Value(2),
          isProxy: const drift.Value(false),
        ),
      );

      // Allocate Card 2: 1 copy in Deck B (Draft deck - should NOT reduce availability)
      await db.into(db.deckVersionItems).insert(
        DeckVersionItemsCompanion.insert(
          id: 'dvi-2',
          versionId: 'ver-draft',
          vaultItemId: 'owned-card-2',
          boardZone: 'Mainboard',
          quantity: const drift.Value(1),
          isProxy: const drift.Value(false),
        ),
      );

      // Allocate Card 3: 2 copies in Deck A as PROXIES (is_proxy = true - should NOT reduce availability)
      await db.into(db.deckVersionItems).insert(
        DeckVersionItemsCompanion.insert(
          id: 'dvi-3',
          versionId: 'ver-assembled',
          vaultItemId: 'owned-card-3',
          boardZone: 'Mainboard',
          quantity: const drift.Value(2),
          isProxy: const drift.Value(true),
        ),
      );

      // Allocate Card 5: 2 copies in Deck A (fully allocating all owned copies)
      await db.into(db.deckVersionItems).insert(
        DeckVersionItemsCompanion.insert(
          id: 'dvi-5',
          versionId: 'ver-assembled',
          vaultItemId: 'owned-card-5',
          boardZone: 'Mainboard',
          quantity: const drift.Value(2),
          isProxy: const drift.Value(false),
        ),
      );

      // Also allocate an unowned catalog card into Deck A as a proxy
      await db.into(db.deckVersionItems).insert(
        DeckVersionItemsCompanion.insert(
          id: 'dvi-catalog-proxy',
          versionId: 'ver-assembled',
          vaultItemId: 'catalog-unowned-0',
          boardZone: 'Mainboard',
          quantity: const drift.Value(1),
          isProxy: const drift.Value(true),
        ),
      );

      // 5. Measure watchAllCardAvailability initial emission
      final stopwatch = Stopwatch()..start();
      final map = await dao.watchAllCardAvailability().first;
      stopwatch.stop();

      // Stress test: Must emit rapidly (under 300ms) even with 500 catalog items in DB
      expect(stopwatch.elapsedMilliseconds, lessThan(300));

      // Assert isolation: EXACTLY 5 owned cards in the map
      expect(map.length, equals(5));

      // Assert that none of the 500 catalog cards leaked into the map
      for (int i = 0; i < 500; i++) {
        expect(map.containsKey('catalog-unowned-$i'), isFalse,
            reason: 'Catalog card $i with quantity == 0 must never leak into availability map');
      }

      // Assert that soft-deleted cards do not leak into the map
      for (int i = 0; i < 10; i++) {
        expect(map.containsKey('deleted-card-$i'), isFalse,
            reason: 'Soft-deleted card $i must never appear in availability map');
      }

      // Assert exact card math
      // Card 1: 3 owned, 2 in assembled deck (non-proxy) -> 1 available
      expect(map['owned-card-1']!.owned, equals(3));
      expect(map['owned-card-1']!.inDeck, equals(2));
      expect(map['owned-card-1']!.available, equals(1));

      // Card 2: 1 owned, 1 in draft deck -> inDeck is 0, 1 available
      expect(map['owned-card-2']!.owned, equals(1));
      expect(map['owned-card-2']!.inDeck, equals(0));
      expect(map['owned-card-2']!.available, equals(1));

      // Card 3: 4 owned, 2 in assembled deck as proxy -> inDeck is 0, 4 available
      expect(map['owned-card-3']!.owned, equals(4));
      expect(map['owned-card-3']!.inDeck, equals(0));
      expect(map['owned-card-3']!.available, equals(4));

      // Card 4: 1 owned, 0 in decks -> inDeck is 0, 1 available
      expect(map['owned-card-4']!.owned, equals(1));
      expect(map['owned-card-4']!.inDeck, equals(0));
      expect(map['owned-card-4']!.available, equals(1));

      // Card 5: 2 owned, 2 in assembled deck -> inDeck is 2, 0 available
      expect(map['owned-card-5']!.owned, equals(2));
      expect(map['owned-card-5']!.inDeck, equals(2));
      expect(map['owned-card-5']!.available, equals(0));
    });

    test('watchAllCardAvailability reactively emits when quantity changes between 0 and >0', () async {
      final now = DateTime.now();

      // Seed 1 unowned catalog card
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'toggle-card',
          collectionType: 'mtg',
          name: 'Toggle Card',
          setOrSeries: 'TEST',
          imageUrl: '',
          acquiredPrice: 0.0,
          acquiredDate: now,
          quantity: const drift.Value(0),
          condition: 'NM',
          currentMarketPrice: 1.0,
          lastPriceUpdate: now,
          dynamicData: '{}',
        ),
      );

      final stream = dao.watchAllCardAvailability();
      final emissions = <Map<String, CardAvailability>>[];
      final sub = stream.listen(emissions.add);
      addTearDown(() => sub.cancel());

      // Give stream time for initial emission
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(emissions.last.isEmpty, isTrue);

      // Promote to quantity = 1 (simulating binder addition or acquisition)
      await (db.update(db.vaultItems)..where((t) => t.id.equals('toggle-card'))).write(
        const VaultItemsCompanion(quantity: drift.Value(1)),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(emissions.last.containsKey('toggle-card'), isTrue);
      expect(emissions.last['toggle-card']!.owned, equals(1));

      // Demote back to quantity = 0
      await (db.update(db.vaultItems)..where((t) => t.id.equals('toggle-card'))).write(
        const VaultItemsCompanion(quantity: drift.Value(0)),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(emissions.last.containsKey('toggle-card'), isFalse);
    });
  });

  group('Challenger 1 Adversarial Suite: Bounded SQL Windows with Active MTG Filters', () {
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

    test('getItemsByCollection bounded SQL window respects small and large limits and offsets', () async {
      final now = DateTime.now();

      // Seed 300 non-matching Green cards
      for (int i = 0; i < 300; i++) {
        await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'green-$i',
            collectionType: 'mtg',
            name: 'Green Card $i',
            setOrSeries: 'TEST',
            imageUrl: '',
            acquiredPrice: 1.0,
            acquiredDate: now.subtract(Duration(minutes: i + 200)),
            quantity: const drift.Value(1),
            condition: 'NM',
            currentMarketPrice: 1.0,
            lastPriceUpdate: now,
            dynamicData: '{"colors":["G"],"cmc":2}',
          ),
        );
      }

      // Seed 100 matching Red cards with deterministic timestamps
      for (int i = 0; i < 100; i++) {
        await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'red-$i',
            collectionType: 'mtg',
            name: 'Red Card ${i.toString().padLeft(3, '0')}',
            setOrSeries: 'TEST',
            imageUrl: '',
            acquiredPrice: 2.0,
            acquiredDate: now.subtract(Duration(minutes: i)),
            quantity: const drift.Value(1),
            condition: 'NM',
            currentMarketPrice: 2.0,
            lastPriceUpdate: now,
            dynamicData: '{"colors":["R"],"cmc":3}',
          ),
        );
      }

      const redFilter = MtgFilterState(colors: {'R'});

      // 1. Small Limit (10 items, offset 0)
      final smallLimitResults = await dao.getItemsByCollection(
        'mtg',
        onlyOwned: true,
        mtgFilter: redFilter,
        limit: 10,
        offset: 0,
      );
      expect(smallLimitResults.length, equals(10));
      for (final card in smallLimitResults) {
        expect(card.id.startsWith('red-'), isTrue);
      }
      expect(smallLimitResults.first.id, equals('red-0'));
      expect(smallLimitResults.last.id, equals('red-9'));

      // 2. Small Limit with Offset (10 items, offset 15)
      final offsetResults = await dao.getItemsByCollection(
        'mtg',
        onlyOwned: true,
        mtgFilter: redFilter,
        limit: 10,
        offset: 15,
      );
      expect(offsetResults.length, equals(10));
      expect(offsetResults.first.id, equals('red-15'));
      expect(offsetResults.last.id, equals('red-24'));

      // 3. Large Limit (500 items, offset 0) - Should retrieve all 100 red cards without truncation
      final largeLimitResults = await dao.getItemsByCollection(
        'mtg',
        onlyOwned: true,
        mtgFilter: redFilter,
        limit: 500,
        offset: 0,
      );
      expect(largeLimitResults.length, equals(100));
      for (final card in largeLimitResults) {
        expect(card.id.startsWith('red-'), isTrue);
      }

      // 4. Large Limit with Offset (500 items, offset 80)
      final offsetLargeResults = await dao.getItemsByCollection(
        'mtg',
        onlyOwned: true,
        mtgFilter: redFilter,
        limit: 500,
        offset: 80,
      );
      expect(offsetLargeResults.length, equals(20));
      expect(offsetLargeResults.first.id, equals('red-80'));
      expect(offsetLargeResults.last.id, equals('red-99'));

      // 5. Offset beyond boundary (offset 100, limit 10)
      final emptyResults = await dao.getItemsByCollection(
        'mtg',
        onlyOwned: true,
        mtgFilter: redFilter,
        limit: 10,
        offset: 100,
      );
      expect(emptyResults.isEmpty, isTrue);
    });

    test('watchItemsByCollection stream reactively updates with bounded window and MTG filter', () async {
      final now = DateTime.now();

      for (int i = 0; i < 20; i++) {
        await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'blue-$i',
            collectionType: 'mtg',
            name: 'Blue Card ${i.toString().padLeft(2, '0')}',
            setOrSeries: 'TEST',
            imageUrl: '',
            acquiredPrice: 1.0,
            acquiredDate: now.subtract(Duration(minutes: i + 10)),
            quantity: const drift.Value(1),
            condition: 'NM',
            currentMarketPrice: 1.0,
            lastPriceUpdate: now,
            dynamicData: '{"colors":["U"],"cmc":1}',
          ),
        );
      }

      const blueFilter = MtgFilterState(colors: {'U'});
      final stream = dao.watchItemsByCollection(
        'mtg',
        onlyOwned: true,
        mtgFilter: blueFilter,
        limit: 5,
        offset: 0,
      );

      final emissionQueue = <List<VaultItem>>[];
      final sub = stream.listen(emissionQueue.add);
      addTearDown(() => sub.cancel());

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(emissionQueue.isNotEmpty, isTrue);
      expect(emissionQueue.last.length, equals(5));
      expect(emissionQueue.last.first.id, equals('blue-0'));

      // Insert a brand new blue card that is newest
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'blue-newest',
          collectionType: 'mtg',
          name: 'Blue Card Newest',
          setOrSeries: 'TEST',
          imageUrl: '',
          acquiredPrice: 10.0,
          acquiredDate: now.add(const Duration(minutes: 5)),
          quantity: const drift.Value(1),
          condition: 'NM',
          currentMarketPrice: 10.0,
          lastPriceUpdate: now,
          dynamicData: '{"colors":["U"],"cmc":1}',
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(emissionQueue.last.length, equals(5));
      expect(emissionQueue.last.first.id, equals('blue-newest'));
    });

    test('Complex composite filters (Color, CMC, Type, Rarity) work flawlessly with bounded SQL window', () async {
      final now = DateTime.now();

      // Seed 50 cards that match only some criteria
      for (int i = 0; i < 50; i++) {
        await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'partial-$i',
            collectionType: 'mtg',
            name: 'Partial Match $i',
            setOrSeries: 'TEST',
            imageUrl: '',
            acquiredPrice: 1.0,
            acquiredDate: now.subtract(Duration(minutes: i + 100)),
            quantity: const drift.Value(1),
            condition: 'NM',
            currentMarketPrice: 1.0,
            lastPriceUpdate: now,
            // Blue, but cmc=2, rare, Instant
            dynamicData: '{"colors":["U"],"cmc":2,"type_line":"Instant","rarity":"rare"}',
          ),
        );
      }

      // Seed 15 cards that match ALL criteria:
      // colors: {'U'}, typeLine: 'Creature', rarities: {'rare'}, cmc: 3
      for (int i = 0; i < 15; i++) {
        await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'exact-$i',
            collectionType: 'mtg',
            name: 'Exact Match Creature ${i.toString().padLeft(2, '0')}',
            setOrSeries: 'TEST',
            imageUrl: '',
            acquiredPrice: 5.0,
            acquiredDate: now.subtract(Duration(minutes: i)),
            quantity: const drift.Value(1),
            condition: 'NM',
            currentMarketPrice: 5.0,
            lastPriceUpdate: now,
            dynamicData: '{"colors":["U"],"cmc":3,"type_line":"Creature — Wizard","rarity":"rare"}',
          ),
        );
      }

      const compositeFilter = MtgFilterState(
        colors: {'U'},
        typeLine: 'Creature',
        rarities: {'rare'},
        cmcRange: RangeValues(3, 3),
      );

      final results = await dao.getItemsByCollection(
        'mtg',
        onlyOwned: true,
        mtgFilter: compositeFilter,
        limit: 10,
        offset: 0,
      );

      expect(results.length, equals(10));
      for (final card in results) {
        expect(card.id.startsWith('exact-'), isTrue);
      }

      // Check offset
      final nextResults = await dao.getItemsByCollection(
        'mtg',
        onlyOwned: true,
        mtgFilter: compositeFilter,
        limit: 10,
        offset: 10,
      );
      expect(nextResults.length, equals(5));
      for (final card in nextResults) {
        expect(card.id.startsWith('exact-'), isTrue);
      }
    });

    test('Over-allocated card availability is strictly clamped to 0 without negative leak', () async {
      final now = DateTime.now();

      // User owns 2 copies
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'over-allocated-card',
          collectionType: 'mtg',
          name: 'Cyclonic Rift',
          setOrSeries: 'RTR',
          imageUrl: '',
          acquiredPrice: 20.0,
          acquiredDate: now,
          quantity: const drift.Value(2),
          condition: 'NM',
          currentMarketPrice: 25.0,
          lastPriceUpdate: now,
          dynamicData: '{"colors":["U"],"cmc":2}',
        ),
      );

      // Deck 1: Assembled
      await db.into(db.decks).insert(
        DecksCompanion.insert(
          id: 'deck-1',
          name: 'Commander 1',
          format: 'Commander',
          isAssembled: const drift.Value(true),
          isRegistered: const drift.Value(false),
          createdAt: now,
          updatedAt: drift.Value(now),
        ),
      );
      await db.into(db.deckVersions).insert(
        DeckVersionsCompanion.insert(
          id: 'ver-1',
          deckId: 'deck-1',
          versionNumber: 1,
          isActive: const drift.Value(true),
          createdAt: now,
        ),
      );
      // Allocate 2 copies in Deck 1
      await db.into(db.deckVersionItems).insert(
        DeckVersionItemsCompanion.insert(
          id: 'dvi-c1',
          versionId: 'ver-1',
          vaultItemId: 'over-allocated-card',
          boardZone: 'Mainboard',
          quantity: const drift.Value(2),
          isProxy: const drift.Value(false),
        ),
      );

      // Deck 2: Also Assembled
      await db.into(db.decks).insert(
        DecksCompanion.insert(
          id: 'deck-2',
          name: 'Commander 2',
          format: 'Commander',
          isAssembled: const drift.Value(true),
          isRegistered: const drift.Value(false),
          createdAt: now,
          updatedAt: drift.Value(now),
        ),
      );
      await db.into(db.deckVersions).insert(
        DeckVersionsCompanion.insert(
          id: 'ver-2',
          deckId: 'deck-2',
          versionNumber: 1,
          isActive: const drift.Value(true),
          createdAt: now,
        ),
      );
      // Allocate 2 more copies in Deck 2 (total allocated = 4, owned = 2)
      await db.into(db.deckVersionItems).insert(
        DeckVersionItemsCompanion.insert(
          id: 'dvi-c2',
          versionId: 'ver-2',
          vaultItemId: 'over-allocated-card',
          boardZone: 'Mainboard',
          quantity: const drift.Value(2),
          isProxy: const drift.Value(false),
        ),
      );

      final map = await dao.watchAllCardAvailability().first;
      expect(map.containsKey('over-allocated-card'), isTrue);
      final avail = map['over-allocated-card']!;
      expect(avail.owned, equals(2));
      expect(avail.inDeck, equals(4));
      // Invariant: available MUST NEVER be negative!
      expect(avail.available, equals(0));
    });

    test('watchAllCardAvailability scale stress test with 1000 catalog cards and 50 owned cards', () async {
      final now = DateTime.now();

      // Seed 1000 catalog cards
      for (int i = 0; i < 1000; i++) {
        await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'scale-cat-$i',
            collectionType: 'mtg',
            name: 'Scale Catalog Card $i',
            setOrSeries: 'TEST',
            imageUrl: '',
            acquiredPrice: 0.0,
            acquiredDate: now.subtract(Duration(minutes: i + 100)),
            quantity: const drift.Value(0),
            condition: 'NM',
            currentMarketPrice: 1.0,
            lastPriceUpdate: now,
            dynamicData: '{}',
          ),
        );
      }

      // Seed 50 owned cards
      for (int i = 0; i < 50; i++) {
        await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'scale-owned-$i',
            collectionType: 'mtg',
            name: 'Scale Owned Card $i',
            setOrSeries: 'TEST',
            imageUrl: '',
            acquiredPrice: 5.0,
            acquiredDate: now.subtract(Duration(minutes: i)),
            quantity: drift.Value((i % 4) + 1),
            condition: 'NM',
            currentMarketPrice: 5.0,
            lastPriceUpdate: now,
            dynamicData: '{}',
          ),
        );
      }

      final stopwatch = Stopwatch()..start();
      final map = await dao.watchAllCardAvailability().first;
      stopwatch.stop();

      // Verify fast execution
      expect(stopwatch.elapsedMilliseconds, lessThan(400));
      // Verify map contains exactly the 50 owned cards and 0 catalog cards
      expect(map.length, equals(50));
      for (int i = 0; i < 50; i++) {
        expect(map.containsKey('scale-owned-$i'), isTrue);
      }
      for (int i = 0; i < 1000; i++) {
        expect(map.containsKey('scale-cat-$i'), isFalse);
      }
    });
  });
}
