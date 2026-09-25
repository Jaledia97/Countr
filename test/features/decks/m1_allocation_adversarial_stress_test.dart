import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';

void main() {
  group('Milestone 1 Empirical Adversarial Stress Suite', () {
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
    // CHALLENGE 1: Heavy Concurrent Deck Creation with 50+ Draft & Registered Decks
    // =========================================================================
    group('1. Heavy Concurrent Deck Creation (50+ Draft & Registered Decks)', () {
      test('60 concurrent deck creations (30 draft, 30 registered) sharing identical card ID', () async {
        final card = await seedVaultCard(
          id: 'card-shared-sol-ring',
          name: 'Sol Ring',
          quantity: 100,
        );

        const totalDecks = 60;
        const registeredCount = 30;
        const copiesPerDeck = 2;

        // Concurrently create all 60 decks
        final deckFutures = List.generate(totalDecks, (i) {
          final isReg = i < registeredCount;
          return db.vaultDao.createDeck(
            'Deck #$i (${isReg ? "Registered" : "Draft"})',
            tcgDomain: 'mtg',
            isRegistered: isReg,
            isCompetitive: isReg,
          );
        });

        final decks = await Future.wait(deckFutures);
        expect(decks.length, equals(totalDecks));

        // Concurrently add card copies to all 60 decks
        final addFutures = decks.map((d) {
          return db.vaultDao.addCardToDeck(
            d.id,
            card.id,
            isProxy: false,
            boardZone: 'Mainboard',
            quantity: copiesPerDeck,
          );
        }).toList();

        await Future.wait(addFutures);

        // Registered decks allocate: 30 decks * 2 copies = 60 copies.
        // Draft decks allocate: 30 decks * 2 copies = 60 unallocated draft copies.
        // Total owned in vault = 100.
        // Expected available = 100 - 60 = 40.
        final available = await db.vaultDao.getAvailableQuantity(card.id);
        expect(
          available,
          equals(40),
          reason: 'Only the 30 registered decks (60 copies) should decrement the 100 owned copies. Available must be 40.',
        );

        // Verify getDecksUsingItem filtering
        final regDeckNames = await db.vaultDao.getDecksUsingItem(card.id, onlyRegistered: true);
        expect(regDeckNames.length, equals(registeredCount));

        final allDeckNames = await db.vaultDao.getDecksUsingItem(card.id, onlyRegistered: false);
        expect(allDeckNames.length, equals(totalDecks));
      });

      test('100 concurrent draft decks sharing multiple cards never locks any physical inventory', () async {
        final cardA = await seedVaultCard(id: 'card-a', name: 'Card A', quantity: 5);
        final cardB = await seedVaultCard(id: 'card-b', name: 'Card B', quantity: 2);
        final cardC = await seedVaultCard(id: 'card-c', name: 'Card C', quantity: 10);

        // Concurrently create 100 draft decks
        final deckFutures = List.generate(100, (i) {
          return db.vaultDao.createDeck(
            'Theorycraft Draft Deck #$i',
            isRegistered: false,
          );
        });
        final decks = await Future.wait(deckFutures);

        // Concurrently add 4 copies of all 3 cards to every draft deck (400 copies each!)
        final addFutures = <Future<void>>[];
        for (final deck in decks) {
          addFutures.add(db.vaultDao.addCardToDeck(deck.id, cardA.id, quantity: 4));
          addFutures.add(db.vaultDao.addCardToDeck(deck.id, cardB.id, quantity: 4));
          addFutures.add(db.vaultDao.addCardToDeck(deck.id, cardC.id, quantity: 4));
        }
        await Future.wait(addFutures);

        // Available quantity for all cards MUST remain completely untouched
        expect(await db.vaultDao.getAvailableQuantity(cardA.id), equals(5));
        expect(await db.vaultDao.getAvailableQuantity(cardB.id), equals(2));
        expect(await db.vaultDao.getAvailableQuantity(cardC.id), equals(10));
      });

      test('Interleaved concurrent creation, card additions, and registration state toggling', () async {
        final card = await seedVaultCard(id: 'card-interleaved', name: 'Command Tower', quantity: 50);

        // Create 20 decks initially as draft
        final decks = await Future.wait(
          List.generate(20, (i) => db.vaultDao.createDeck('Interleaved Deck #$i', isRegistered: false)),
        );

        // Add 2 copies to each deck
        await Future.wait(decks.map((d) => db.vaultDao.addCardToDeck(d.id, card.id, quantity: 2)));

        // Concurrently register odd-indexed decks (10 decks)
        final toggleFutures = <Future<void>>[];
        for (var i = 0; i < decks.length; i++) {
          if (i.isOdd) {
            toggleFutures.add(db.vaultDao.setDeckRegistered(decks[i].id, true));
          }
        }
        await Future.wait(toggleFutures);

        // 10 registered decks * 2 copies = 20 copies allocated. Available = 50 - 20 = 30.
        expect(await db.vaultDao.getAvailableQuantity(card.id), equals(30));
      });
    });

    // =========================================================================
    // CHALLENGE 2: Rapid Toggling of is_registered & Reactive Stream Consistency
    // =========================================================================
    group('2. Rapid Toggling of is_registered & Reactive Stream Consistency', () {
      test('50 rapid sequential toggles maintain strict stream and one-shot query consistency', () async {
        final card = await seedVaultCard(id: 'card-rapid-toggle', name: 'Mox Diamond', quantity: 4);
        final deck = await db.vaultDao.createDeck('Rapid Deck', isRegistered: false);
        await db.vaultDao.addCardToDeck(deck.id, card.id, quantity: 3);

        final streamValues = <int>[];
        final sub = db.vaultDao.watchAvailableQuantity(card.id).listen((val) {
          streamValues.add(val);
        });

        // Initial state is draft -> available = 4
        await pumpEventQueue();
        expect(await db.vaultDao.getAvailableQuantity(card.id), equals(4));

        // Rapidly toggle 50 times
        var expectedRegistered = false;
        for (var i = 0; i < 50; i++) {
          expectedRegistered = !expectedRegistered;
          await db.vaultDao.setDeckRegistered(deck.id, expectedRegistered);

          final currentAvailable = await db.vaultDao.getAvailableQuantity(card.id);
          final expectedAvailable = expectedRegistered ? 1 : 4;
          expect(
            currentAvailable,
            equals(expectedAvailable),
            reason: 'At toggle step $i (registered=$expectedRegistered), available must be $expectedAvailable',
          );
        }

        await pumpEventQueue();
        await sub.cancel();

        // Final stream value must match final one-shot query
        final finalAvailable = await db.vaultDao.getAvailableQuantity(card.id);
        expect(streamValues.last, equals(finalAvailable));

        // All intermediate stream values must strictly be either 1 or 4
        expect(streamValues.every((val) => val == 1 || val == 4), isTrue);
      });

      test('Concurrent racing registration toggles resolve without corruption or deadlock', () async {
        final card = await seedVaultCard(id: 'card-race-toggle', name: 'Black Lotus', quantity: 2);
        final deck = await db.vaultDao.createDeck('Racing Deck', isRegistered: false);
        await db.vaultDao.addCardToDeck(deck.id, card.id, quantity: 2);

        // Fire 20 unawaited/concurrent registration toggles
        final toggles = List.generate(20, (i) {
          return db.vaultDao.setDeckRegistered(deck.id, i.isEven);
        });
        await Future.wait(toggles);

        // Query the final state of the deck in SQLite
        final latestDeck = await (db.select(db.decks)..where((t) => t.id.equals(deck.id))).getSingle();
        final finalAvailable = await db.vaultDao.getAvailableQuantity(card.id);

        if (latestDeck.isRegistered) {
          expect(finalAvailable, equals(0));
        } else {
          expect(finalAvailable, equals(2));
        }
      });

      test('Multi-deck concurrent registration toggling on shared card converges accurately', () async {
        final card = await seedVaultCard(id: 'card-multi-toggle', name: 'Rhystic Study', quantity: 10);

        // Create 5 decks, each with 2 copies
        final decks = await Future.wait(
          List.generate(5, (i) => db.vaultDao.createDeck('Multi Deck #$i', isRegistered: false)),
        );
        for (final deck in decks) {
          await db.vaultDao.addCardToDeck(deck.id, card.id, quantity: 2);
        }

        // Available initially is 10
        expect(await db.vaultDao.getAvailableQuantity(card.id), equals(10));

        // Random/patterned concurrent toggling across all 5 decks
        await Future.wait([
          db.vaultDao.setDeckRegistered(decks[0].id, true),  // allocates 2
          db.vaultDao.setDeckRegistered(decks[1].id, true),  // allocates 2
          db.vaultDao.setDeckRegistered(decks[2].id, false), // 0
          db.vaultDao.setDeckRegistered(decks[3].id, true),  // allocates 2
          db.vaultDao.setDeckRegistered(decks[4].id, false), // 0
        ]);

        // 3 registered decks * 2 copies = 6 copies. Available = 10 - 6 = 4.
        expect(await db.vaultDao.getAvailableQuantity(card.id), equals(4));

        // Toggle remaining 2 to true as well
        await Future.wait([
          db.vaultDao.setDeckRegistered(decks[2].id, true),
          db.vaultDao.setDeckRegistered(decks[4].id, true),
        ]);

        // All 5 registered -> 10 allocated -> 0 available
        expect(await db.vaultDao.getAvailableQuantity(card.id), equals(0));
      });

      test('Stream reactively reflects VaultItem quantity changes when decks are registered', () async {
        final card = await seedVaultCard(id: 'card-stream-react', name: 'Demonic Tutor', quantity: 5);
        final deck = await db.vaultDao.createDeck('Tutor Deck', isRegistered: true);
        await db.vaultDao.addCardToDeck(deck.id, card.id, quantity: 3);

        final emissions = <int>[];
        final sub = db.vaultDao.watchAvailableQuantity(card.id).listen((val) {
          emissions.add(val);
        });

        await pumpEventQueue();
        expect(await db.vaultDao.getAvailableQuantity(card.id), equals(2)); // 5 - 3 = 2

        // User acquires 5 more copies (vault quantity becomes 10)
        await (db.update(db.vaultItems)..where((t) => t.id.equals(card.id)))
            .write(const VaultItemsCompanion(quantity: drift.Value(10)));

        await pumpEventQueue();
        expect(await db.vaultDao.getAvailableQuantity(card.id), equals(7)); // 10 - 3 = 7

        // User sells down to 2 copies in vault (allocated 3 exceeds 2 -> clamps to 0)
        await (db.update(db.vaultItems)..where((t) => t.id.equals(card.id)))
            .write(const VaultItemsCompanion(quantity: drift.Value(2)));

        await pumpEventQueue();
        expect(await db.vaultDao.getAvailableQuantity(card.id), equals(0)); // clamped

        await sub.cancel();
      });
    });

    // =========================================================================
    // CHALLENGE 3: Multi-Commander Zones & Invalid Partner / Background Counts
    // =========================================================================
    group('3. Multi-Commander Zones & Invalid Combinations', () {
      test('Adding 5 distinct commanders to the same deck does not crash SQLite or corrupt quantities', () async {
        final commanders = await Future.wait(List.generate(5, (i) {
          return seedVaultCard(
            id: 'commander-$i',
            name: 'Legendary Commander #$i',
            quantity: 1,
          );
        }));

        final deck = await db.vaultDao.createDeck('5-Commander Chaos EDH', isRegistered: true);

        // Add all 5 commanders to the Commander zone
        for (final cmd in commanders) {
          await db.vaultDao.addCardToDeck(
            deck.id,
            cmd.id,
            boardZone: 'Commander',
            quantity: 1,
          );
        }

        // Verify active deck version items in Commander zone
        final version = await (db.select(db.deckVersions)
              ..where((t) => t.deckId.equals(deck.id) & t.isActive.equals(true)))
            .getSingle();

        final cmdItems = await (db.select(db.deckVersionItems)
              ..where((t) =>
                  t.versionId.equals(version.id) &
                  t.boardZone.equals('Commander')))
            .get();

        expect(cmdItems.length, equals(5));

        // Verify each commander card had its inventory decremented by 1 (1 - 1 = 0 available)
        for (final cmd in commanders) {
          final available = await db.vaultDao.getAvailableQuantity(cmd.id);
          expect(available, equals(0));
        }

        // Toggling deck to draft frees all 5 commanders simultaneously
        await db.vaultDao.setDeckRegistered(deck.id, false);
        for (final cmd in commanders) {
          final available = await db.vaultDao.getAvailableQuantity(cmd.id);
          expect(available, equals(1));
        }
      });

      test('Stress test: 10 commanders and 5 companions in the same deck version', () async {
        final commanders = await Future.wait(List.generate(10, (i) => seedVaultCard(id: 'stress-cmd-$i', name: 'Cmd $i', quantity: 2)));
        final companions = await Future.wait(List.generate(5, (i) => seedVaultCard(id: 'stress-comp-$i', name: 'Comp $i', quantity: 2)));

        final deck = await db.vaultDao.createDeck('Mega Zone Stress', isRegistered: true);

        // Add 10 commanders
        for (final c in commanders) {
          await db.vaultDao.addCardToDeck(deck.id, c.id, boardZone: 'Commander', quantity: 1);
        }
        // Add 5 companions
        for (final c in companions) {
          await db.vaultDao.addCardToDeck(deck.id, c.id, boardZone: 'Companion', quantity: 1);
        }

        final version = await (db.select(db.deckVersions)
              ..where((t) => t.deckId.equals(deck.id) & t.isActive.equals(true)))
            .getSingle();

        final items = await (db.select(db.deckVersionItems)..where((t) => t.versionId.equals(version.id))).get();
        expect(items.length, equals(15));
        expect(items.where((i) => i.boardZone == 'Commander').length, equals(10));
        expect(items.where((i) => i.boardZone == 'Companion').length, equals(5));

        // Available quantity for each commander and companion should be 2 - 1 = 1
        for (final c in commanders) {
          expect(await db.vaultDao.getAvailableQuantity(c.id), equals(1));
        }
        for (final c in companions) {
          expect(await db.vaultDao.getAvailableQuantity(c.id), equals(1));
        }
      });

      test('Adding the exact same commander twice increments quantity without duplicating row', () async {
        final cmd = await seedVaultCard(id: 'card-urza', name: 'Urza, Lord High Artificer', quantity: 3);
        final deck = await db.vaultDao.createDeck('Urza High Tech', isRegistered: true);

        // Add 1 copy to Commander
        await db.vaultDao.addCardToDeck(deck.id, cmd.id, boardZone: 'Commander', quantity: 1);
        // Add another copy to Commander
        await db.vaultDao.addCardToDeck(deck.id, cmd.id, boardZone: 'Commander', quantity: 1);

        final version = await (db.select(db.deckVersions)
              ..where((t) => t.deckId.equals(deck.id) & t.isActive.equals(true)))
            .getSingle();

        final cmdItems = await (db.select(db.deckVersionItems)
              ..where((t) =>
                  t.versionId.equals(version.id) &
                  t.boardZone.equals('Commander')))
            .get();

        // Must coalesce into a single row with quantity = 2
        expect(cmdItems.length, equals(1));
        expect(cmdItems.first.quantity, equals(2));

        // Available quantity decrements by 2 (3 - 2 = 1)
        expect(await db.vaultDao.getAvailableQuantity(cmd.id), equals(1));
      });

      test('Case-insensitivity and whitespace padding normalization in boardZone string', () async {
        final card1 = await seedVaultCard(id: 'c-zone-1', name: 'Card 1');
        final card2 = await seedVaultCard(id: 'c-zone-2', name: 'Card 2');
        final card3 = await seedVaultCard(id: 'c-zone-3', name: 'Card 3');
        final card4 = await seedVaultCard(id: 'c-zone-4', name: 'Card 4');
        final card5 = await seedVaultCard(id: 'c-zone-5', name: 'Card 5');

        final deck = await db.vaultDao.createDeck('Zone Normalization Deck');

        await db.vaultDao.addCardToDeck(deck.id, card1.id, boardZone: '  commander  ');
        await db.vaultDao.addCardToDeck(deck.id, card2.id, boardZone: 'SIDEBOARD\n');
        await db.vaultDao.addCardToDeck(deck.id, card3.id, boardZone: 'MaybeBoard');
        await db.vaultDao.addCardToDeck(deck.id, card4.id, boardZone: 'COMPANION');
        await db.vaultDao.addCardToDeck(deck.id, card5.id, boardZone: 'non-existent-zone'); // fallback to Mainboard

        final version = await (db.select(db.deckVersions)
              ..where((t) => t.deckId.equals(deck.id) & t.isActive.equals(true)))
            .getSingle();

        final items = await (db.select(db.deckVersionItems)..where((t) => t.versionId.equals(version.id))).get();

        expect(items.firstWhere((i) => i.vaultItemId == card1.id).boardZone, equals('Commander'));
        expect(items.firstWhere((i) => i.vaultItemId == card2.id).boardZone, equals('Sideboard'));
        expect(items.firstWhere((i) => i.vaultItemId == card3.id).boardZone, equals('Maybeboard'));
        expect(items.firstWhere((i) => i.vaultItemId == card4.id).boardZone, equals('Companion'));
        expect(items.firstWhere((i) => i.vaultItemId == card5.id).boardZone, equals('Mainboard'));
      });
    });

    // =========================================================================
    // CHALLENGE 4: Extreme Quantities (0, Negative, 1,000,000) & Over-Allocation Limits
    // =========================================================================
    group('4. Extreme Quantities & Boundary Conditions', () {
      test('1,000,000 copies in Vault and massive allocations survive without integer overflow', () async {
        final bulkCard = await seedVaultCard(
          id: 'card-bulk-land',
          name: 'Mountain',
          quantity: 1000000,
        );

        final deck1 = await db.vaultDao.createDeck('Mega Red 1', isRegistered: true);
        final deck2 = await db.vaultDao.createDeck('Mega Red 2', isRegistered: true);

        // Allocate 500,000 in deck1
        await db.vaultDao.addCardToDeck(deck1.id, bulkCard.id, quantity: 500000);
        expect(await db.vaultDao.getAvailableQuantity(bulkCard.id), equals(500000));

        // Allocate 499,999 in deck2
        await db.vaultDao.addCardToDeck(deck2.id, bulkCard.id, quantity: 499999);
        expect(await db.vaultDao.getAvailableQuantity(bulkCard.id), equals(1));

        // Over-allocate by 5 more copies (total allocated = 1,000,004 vs 1,000,000 owned)
        await db.vaultDao.addCardToDeck(deck2.id, bulkCard.id, quantity: 5);
        expect(
          await db.vaultDao.getAvailableQuantity(bulkCard.id),
          equals(0),
          reason: 'Over-allocation must clamp at 0 and never return negative numbers or overflow 32-bit int',
        );
      });

      test('Zero quantity VaultItem: Wishlist / Unowned card allocation', () async {
        final unownedCard = await seedVaultCard(
          id: 'card-unowned-tabernacle',
          name: 'The Tabernacle at Pendrell Vale',
          quantity: 0,
        );

        final draftDeck = await db.vaultDao.createDeck('Draft Deck', isRegistered: false);
        final regDeck = await db.vaultDao.createDeck('Registered Deck', isRegistered: true);

        // Add to draft deck
        await db.vaultDao.addCardToDeck(draftDeck.id, unownedCard.id, quantity: 1);
        expect(await db.vaultDao.getAvailableQuantity(unownedCard.id), equals(0));

        // Add to registered deck
        await db.vaultDao.addCardToDeck(regDeck.id, unownedCard.id, quantity: 1);
        expect(await db.vaultDao.getAvailableQuantity(unownedCard.id), equals(0), reason: '0 owned - 1 allocated clamps to 0');
      });

      test('Severe over-allocation across 20 registered decks clamps to 0', () async {
        final card = await seedVaultCard(id: 'card-single-copy', name: 'Rare Foil', quantity: 1);

        // 20 registered decks each take 1 copy
        final decks = await Future.wait(
          List.generate(20, (i) => db.vaultDao.createDeck('Registered Deck #$i', isRegistered: true)),
        );
        for (final deck in decks) {
          await db.vaultDao.addCardToDeck(deck.id, card.id, quantity: 1);
        }

        // Total allocated = 20. Owned = 1. Clamps to 0.
        expect(await db.vaultDao.getAvailableQuantity(card.id), equals(0));

        // Unregister 19 decks
        for (var i = 0; i < 19; i++) {
          await db.vaultDao.setDeckRegistered(decks[i].id, false);
        }

        // Only 1 registered deck remains (allocated = 1). Owned = 1. Available = 0.
        expect(await db.vaultDao.getAvailableQuantity(card.id), equals(0));

        // Unregister the final deck -> Available recovers to 1!
        await db.vaultDao.setDeckRegistered(decks[19].id, false);
        expect(await db.vaultDao.getAvailableQuantity(card.id), equals(1));
      });

      test('Swap printing with large quantity cleanly transfers allocation between items', () async {
        final printOld = await seedVaultCard(id: 'print-old', name: 'Forest', quantity: 50000);
        final printNew = await seedVaultCard(id: 'print-new', name: 'Forest', quantity: 60000);

        final deck = await db.vaultDao.createDeck('Bulk Green', isRegistered: true);
        await db.vaultDao.addCardToDeck(deck.id, printOld.id, quantity: 20000);

        expect(await db.vaultDao.getAvailableQuantity(printOld.id), equals(30000));
        expect(await db.vaultDao.getAvailableQuantity(printNew.id), equals(60000));

        final version = await (db.select(db.deckVersions)
              ..where((t) => t.deckId.equals(deck.id) & t.isActive.equals(true)))
            .getSingle();

        final item = await (db.select(db.deckVersionItems)
              ..where((t) => t.versionId.equals(version.id)))
            .getSingle();

        // Swap printing to printNew
        await db.vaultDao.swapDeckItemPrinting(item.id, printNew.id);

        // printOld available must recover to 50,000
        expect(await db.vaultDao.getAvailableQuantity(printOld.id), equals(50000));
        // printNew available must decrease by 20,000 (60,000 - 20,000 = 40,000)
        expect(await db.vaultDao.getAvailableQuantity(printNew.id), equals(40000));
      });

      test('moveCardToDeck priority: draws from registered decks before draft decks', () async {
        final card = await seedVaultCard(id: 'card-move-test', name: 'Mana Drain', quantity: 2);

        final draftDeck = await db.vaultDao.createDeck('Draft Deck', isRegistered: false);
        final regDeck = await db.vaultDao.createDeck('Registered Deck', isRegistered: true);
        final targetDeck = await db.vaultDao.createDeck('Target Deck', isRegistered: true);

        await db.vaultDao.addCardToDeck(draftDeck.id, card.id, quantity: 1);
        await db.vaultDao.addCardToDeck(regDeck.id, card.id, quantity: 1);

        // Prior to move: regDeck has 1, targetDeck has 0. Available = 2 - 1 = 1.
        expect(await db.vaultDao.getAvailableQuantity(card.id), equals(1));

        // Move card to targetDeck (should pick the registered deck item to move)
        await db.vaultDao.moveCardToDeck(card.id, targetDeck.id);

        // regDeck had its copy removed, targetDeck gained 1 copy.
        // Both are registered decks, so available remains 2 - 1 = 1.
        expect(await db.vaultDao.getAvailableQuantity(card.id), equals(1));

        final regDecksWithCard = await db.vaultDao.getDecksUsingItem(card.id, onlyRegistered: true);
        expect(regDecksWithCard, contains('Target Deck'));
        expect(regDecksWithCard, isNot(contains('Registered Deck')));
      });
    });
  });
}
