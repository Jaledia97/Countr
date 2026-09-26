import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/domain/models/assembly_models.dart';
import 'package:countr/features/decks/domain/models/board_zone.dart';
import 'package:countr/features/decks/presentation/widgets/assembly_pick_list_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Milestone 3 Features 9 & 10 Adversarial Stress Tests', () {
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

    Future<VaultItem> seedCard({
      required String id,
      required String name,
      int quantity = 4,
      String? binderId,
      String collectionType = 'mtg',
    }) async {
      final companion = VaultItemsCompanion.insert(
        id: id,
        collectionType: collectionType,
        name: name,
        setOrSeries: 'TEST',
        imageUrl: 'https://example.com/$id.jpg',
        acquiredPrice: 1.0,
        acquiredDate: DateTime.now(),
        quantity: drift.Value(quantity),
        primaryBinderId: drift.Value(binderId),
        condition: 'NM',
        currentMarketPrice: 2.0,
        lastPriceUpdate: DateTime.now(),
        dynamicData: jsonEncode({'name': name}),
      );
      await db.vaultDao.into(db.vaultItems).insert(companion);
      return (await (db.select(db.vaultItems)..where((t) => t.id.equals(id))).getSingle());
    }

    // =========================================================================
    // CHALLENGE 1: Complex Partial Deficit Row Splitting with Existing Proxy Row
    // =========================================================================
    test('Stress 1: Row splitting merges into existing proxy row and locks only physical inventory', () async {
      await seedCard(id: 'item-bolt', name: 'Lightning Bolt', quantity: 2);

      const deckId = 'deck-burn-adversarial';
      await db.into(db.decks).insert(DecksCompanion.insert(
        id: deckId,
        name: 'Burn Deck',
        format: 'Custom',
        tcgDomain: const drift.Value('mtg'),
        isRegistered: const drift.Value(false),
        createdAt: DateTime.now(),
      ));

      const versionId = 'ver-burn-1';
      await db.into(db.deckVersions).insert(DeckVersionsCompanion.insert(
        id: versionId,
        deckId: deckId,
        versionNumber: 1,
        isActive: const drift.Value(true),
        createdAt: DateTime.now(),
      ));

      // Physical row: 5 copies
      await db.into(db.deckVersionItems).insert(DeckVersionItemsCompanion.insert(
        id: 'dvi-bolt-phys',
        versionId: versionId,
        vaultItemId: 'item-bolt',
        quantity: const drift.Value(5),
        boardZone: 'Mainboard',
        isProxy: const drift.Value(false),
      ));

      // Existing proxy row: 1 copy
      await db.into(db.deckVersionItems).insert(DeckVersionItemsCompanion.insert(
        id: 'dvi-bolt-proxy',
        versionId: versionId,
        vaultItemId: 'item-bolt',
        quantity: const drift.Value(1),
        boardZone: 'Mainboard',
        isProxy: const drift.Value(true),
      ));

      // Before registration: available physical count is 2 (draft deck doesn't lock)
      expect(await db.vaultDao.getAvailableQuantity('item-bolt'), equals(2));

      // Calculate pick plan:
      // Required for physical row is 5 (avail = 2, pull = 2, deficit = 3)
      // Existing proxy row has isProxy=true (pull = 0, deficit = 0)
      final plan = await db.vaultDao.getDeckAssemblyPlan(deckId);
      expect(plan.totalRequired, equals(6)); // 5 + 1
      expect(plan.totalAvailable, equals(2));
      expect(plan.totalDeficit, equals(3));
      expect(plan.hasDeficit, isTrue);

      // Execute proxy resolution registration
      await db.vaultDao.registerDeckWithProxyResolution(
        deckId: deckId,
        items: plan.items,
      );

      // Verify deck is now registered
      final registeredDeck = await (db.select(db.decks)..where((t) => t.id.equals(deckId))).getSingle();
      expect(registeredDeck.isRegistered, isTrue);

      // Verify physical row is reduced to 2 (5 - 3)
      final physDvi = await (db.select(db.deckVersionItems)
        ..where((t) => t.id.equals('dvi-bolt-phys'))).getSingle();
      expect(physDvi.quantity, equals(2));
      expect(physDvi.isProxy, isFalse);

      // Verify proxy row merged: 1 + 3 = 4 proxies
      final proxyDvi = await (db.select(db.deckVersionItems)
        ..where((t) => t.id.equals('dvi-bolt-proxy'))).getSingle();
      expect(proxyDvi.quantity, equals(4));
      expect(proxyDvi.isProxy, isTrue);

      // Verify total copies in deck = 2 + 4 = 6
      final allDvis = await (db.select(db.deckVersionItems)
        ..where((t) => t.versionId.equals(versionId))).get();
      final totalInDeck = allDvis.fold<int>(0, (sum, d) => sum + d.quantity);
      expect(totalInDeck, equals(6));

      // Verify available physical inventory is now 0 (2 vault copies - 2 allocated)
      expect(await db.vaultDao.getAvailableQuantity('item-bolt'), equals(0));

      // Unregister deck -> physical inventory unlocked to 2
      await db.vaultDao.setDeckRegistered(deckId, false);
      expect(await db.vaultDao.getAvailableQuantity('item-bolt'), equals(2));
    });

    // =========================================================================
    // CHALLENGE 2: Multi-Deck Competition for Scarce Vault Copies
    // =========================================================================
    test('Stress 2: Multi-deck competition properly updates available counts during assembly planning', () async {
      await seedCard(id: 'item-cyclonic', name: 'Cyclonic Rift', quantity: 3);

      // Create Deck C (Registered, holds 1 physical copy)
      await db.into(db.decks).insert(DecksCompanion.insert(
        id: 'deck-c',
        name: 'Deck C',
        format: 'Commander',
        tcgDomain: const drift.Value('mtg'),
        isRegistered: const drift.Value(true),
        createdAt: DateTime.now(),
      ));
      await db.into(db.deckVersions).insert(DeckVersionsCompanion.insert(
        id: 'ver-c',
        deckId: 'deck-c',
        versionNumber: 1,
        isActive: const drift.Value(true),
        createdAt: DateTime.now(),
      ));
      await db.into(db.deckVersionItems).insert(DeckVersionItemsCompanion.insert(
        id: 'dvi-c',
        versionId: 'ver-c',
        vaultItemId: 'item-cyclonic',
        quantity: const drift.Value(1),
        boardZone: 'Mainboard',
      ));

      // Deck A (Draft, wants 2 copies)
      await db.into(db.decks).insert(DecksCompanion.insert(
        id: 'deck-a',
        name: 'Deck A',
        format: 'Commander',
        tcgDomain: const drift.Value('mtg'),
        isRegistered: const drift.Value(false),
        createdAt: DateTime.now(),
      ));
      await db.into(db.deckVersions).insert(DeckVersionsCompanion.insert(
        id: 'ver-a',
        deckId: 'deck-a',
        versionNumber: 1,
        isActive: const drift.Value(true),
        createdAt: DateTime.now(),
      ));
      await db.into(db.deckVersionItems).insert(DeckVersionItemsCompanion.insert(
        id: 'dvi-a',
        versionId: 'ver-a',
        vaultItemId: 'item-cyclonic',
        quantity: const drift.Value(2),
        boardZone: 'Mainboard',
      ));

      // Deck B (Draft, wants 2 copies)
      await db.into(db.decks).insert(DecksCompanion.insert(
        id: 'deck-b',
        name: 'Deck B',
        format: 'Commander',
        tcgDomain: const drift.Value('mtg'),
        isRegistered: const drift.Value(false),
        createdAt: DateTime.now(),
      ));
      await db.into(db.deckVersions).insert(DeckVersionsCompanion.insert(
        id: 'ver-b',
        deckId: 'deck-b',
        versionNumber: 1,
        isActive: const drift.Value(true),
        createdAt: DateTime.now(),
      ));
      await db.into(db.deckVersionItems).insert(DeckVersionItemsCompanion.insert(
        id: 'dvi-b',
        versionId: 'ver-b',
        vaultItemId: 'item-cyclonic',
        quantity: const drift.Value(2),
        boardZone: 'Mainboard',
      ));

      // Deck A plan: available is 3 - 1 (Deck C) = 2. Deficit = 0.
      final planA = await db.vaultDao.getDeckAssemblyPlan('deck-a');
      expect(planA.totalAvailable, equals(2));
      expect(planA.totalDeficit, equals(0));
      expect(planA.hasDeficit, isFalse);

      // Deck B plan before A registers: also sees 2 available
      final planBBefore = await db.vaultDao.getDeckAssemblyPlan('deck-b');
      expect(planBBefore.totalAvailable, equals(2));
      expect(planBBefore.totalDeficit, equals(0));

      // Now Deck A registers: locks 2 copies
      await db.vaultDao.setDeckRegistered('deck-a', true);
      expect(await db.vaultDao.getAvailableQuantity('item-cyclonic'), equals(0)); // 3 - 1(C) - 2(A) = 0

      // Now Deck B plan: available drops to 0! Deficit is 2!
      final planBAfter = await db.vaultDao.getDeckAssemblyPlan('deck-b');
      expect(planBAfter.totalAvailable, equals(0));
      expect(planBAfter.totalDeficit, equals(2));
      expect(planBAfter.hasDeficit, isTrue);

      // Deck B registers with proxy fallback
      await db.vaultDao.registerDeckWithProxyResolution(
        deckId: 'deck-b',
        items: planBAfter.items,
      );

      // Deck B is registered
      final bDeck = await (db.select(db.decks)..where((t) => t.id.equals('deck-b'))).getSingle();
      expect(bDeck.isRegistered, isTrue);

      // Deck B item is completely converted to proxy (0 available -> full deficit)
      final bDvi = await (db.select(db.deckVersionItems)
        ..where((t) => t.id.equals('dvi-b'))).getSingle();
      expect(bDvi.isProxy, isTrue);
      expect(bDvi.quantity, equals(2));

      // Available physical quantity is still 0 (only C and A locked copies)
      expect(await db.vaultDao.getAvailableQuantity('item-cyclonic'), equals(0));
    });

    // =========================================================================
    // CHALLENGE 3: Multi-Binder Pick-List Grouping & Unsorted Fallback
    // =========================================================================
    test('Stress 3: Multi-binder pick-list grouping and null/empty binder fallback', () async {
      await db.into(db.vaultBinders).insert(VaultBindersCompanion.insert(
        id: 'binder-alpha',
        name: 'Alpha Binder',
        collectionType: 'mtg',
        createdAt: DateTime.now(),
      ));
      await db.into(db.vaultBinders).insert(VaultBindersCompanion.insert(
        id: 'binder-beta',
        name: 'Beta Box',
        collectionType: 'mtg',
        createdAt: DateTime.now(),
      ));

      await seedCard(id: 'c1', name: 'Alpha Card', binderId: 'binder-alpha', quantity: 1);
      await seedCard(id: 'c2', name: 'Beta Card', binderId: 'binder-beta', quantity: 1);
      await seedCard(id: 'c3', name: 'Unsorted Card', binderId: null, quantity: 1);

      const deckId = 'deck-locations';
      await db.into(db.decks).insert(DecksCompanion.insert(
        id: deckId,
        name: 'Location Deck',
        format: 'Modern',
        tcgDomain: const drift.Value('mtg'),
        isRegistered: const drift.Value(false),
        createdAt: DateTime.now(),
      ));
      const versionId = 'ver-loc-1';
      await db.into(db.deckVersions).insert(DeckVersionsCompanion.insert(
        id: versionId,
        deckId: deckId,
        versionNumber: 1,
        isActive: const drift.Value(true),
        createdAt: DateTime.now(),
      ));

      await db.into(db.deckVersionItems).insert(DeckVersionItemsCompanion.insert(
        id: 'dvi-c1',
        versionId: versionId,
        vaultItemId: 'c1',
        quantity: const drift.Value(1),
        boardZone: 'Mainboard',
      ));
      await db.into(db.deckVersionItems).insert(DeckVersionItemsCompanion.insert(
        id: 'dvi-c2',
        versionId: versionId,
        vaultItemId: 'c2',
        quantity: const drift.Value(1),
        boardZone: 'Mainboard',
      ));
      await db.into(db.deckVersionItems).insert(DeckVersionItemsCompanion.insert(
        id: 'dvi-c3',
        versionId: versionId,
        vaultItemId: 'c3',
        quantity: const drift.Value(1),
        boardZone: 'Mainboard',
      ));

      final plan = await db.vaultDao.getDeckAssemblyPlan(deckId);
      expect(plan.itemsByLocation.keys, containsAll(['Alpha Binder', 'Beta Box', 'Unsorted Vault']));
      expect(plan.itemsByLocation['Alpha Binder']!.length, equals(1));
      expect(plan.itemsByLocation['Beta Box']!.length, equals(1));
      expect(plan.itemsByLocation['Unsorted Vault']!.length, equals(1));
    });

    // =========================================================================
    // CHALLENGE 4: 280px & 320px Narrow Viewport + 2.0x Text Scaling
    // =========================================================================
    testWidgets('Stress 4: AssemblyPickListDialog under 280px & 320px viewport + 2.0x font scaling', (tester) async {
      tester.view.physicalSize = const Size(280, 500);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final longNameItem = AssemblyPickItem(
        dviId: 'dvi-long',
        vaultItemId: 'vi-long',
        cardName: 'Our Market Research Shows That Players Like Really Long Card Names',
        setCode: 'UNH-EXTRA-LONG-SET',
        boardZone: BoardZone.commander,
        requiredQuantity: 99,
        availableQuantity: 42,
        pullQuantity: 42,
        deficitQuantity: 57,
        locationName: 'Extremely Long Binder Name For Oversized Cards',
      );

      final plan = DeckAssemblyPlan(
        deckId: 'deck-adversarial-ui',
        deckName: 'Super Extremely Verbose Deck Title With Excessive Characters',
        items: [longNameItem],
        itemsByLocation: {
          'Extremely Long Binder Name For Oversized Cards': [longNameItem],
        },
        deficitItems: [longNameItem],
      );

      final deck = Deck(
        id: 'deck-adversarial-ui',
        name: 'Super Extremely Verbose Deck Title With Excessive Characters',
        format: 'Commander',
        wins: 0,
        losses: 0,
        draws: 0,
        createdAt: DateTime.now(),
        tcgDomain: 'mtg',
        isRegistered: false,
        isAssembled: false,
        isCompetitive: false, isDeleted: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(280, 500),
                textScaler: TextScaler.linear(2.0),
              ),
              child: Scaffold(
                body: Builder(
                  builder: (ctx) => ElevatedButton(
                    onPressed: () => AssemblyPickListDialog.show(
                      ctx,
                      deck,
                      precomputedPlan: plan,
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final exception = tester.takeException();
      expect(exception, isNull, reason: 'Must not trigger RenderFlex overflow even at 280px + 2.0x font');

      // Also verify at 320px
      tester.view.physicalSize = const Size(320, 568);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    // =========================================================================
    // CHALLENGE 5: Edge Case - 0 Total Required / 0 Available (Empty/Wishlist Deck)
    // =========================================================================
    test('Stress 5: DeckAssemblyPlan zero division safety and wishlist exclusion', () async {
      // Empty items
      final emptyPlan = DeckAssemblyPlan(
        deckId: 'empty-deck',
        deckName: 'Empty Deck',
        items: [],
        itemsByLocation: {},
        deficitItems: [],
      );

      expect(emptyPlan.totalRequired, equals(0));
      expect(emptyPlan.totalAvailable, equals(0));
      expect(emptyPlan.totalDeficit, equals(0));
      expect(emptyPlan.totalPulled, equals(0));
      expect(emptyPlan.hasDeficit, isFalse);
      expect(emptyPlan.progress, equals(1.0)); // Must not be NaN or Infinity!
    });
  });
}
