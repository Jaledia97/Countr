import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/domain/models/assembly_models.dart';
import 'package:countr/features/decks/domain/models/board_zone.dart';
import 'package:countr/features/decks/presentation/widgets/assembly_pick_list_dialog.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';

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

  // Helper to create binders
  Future<void> createBinder(String id, String name) async {
    await db.into(db.vaultBinders).insert(VaultBindersCompanion.insert(
      id: id,
      name: name,
      collectionType: 'mtg',
      createdAt: DateTime.now(),
    ));
  }

  // Helper to create vault item
  Future<void> createVaultItem({
    required String id,
    required String name,
    required int quantity,
    String? binderId,
    String setOrSeries = 'MH2',
    double price = 10.0,
  }) async {
    await db.into(db.vaultItems).insert(VaultItemsCompanion.insert(
      id: id,
      collectionType: 'mtg',
      name: name,
      setOrSeries: setOrSeries,
      imageUrl: '',
      acquiredPrice: price,
      acquiredDate: DateTime.now(),
      quantity: drift.Value(quantity),
      primaryBinderId: drift.Value(binderId),
      condition: 'NM',
      currentMarketPrice: price,
      lastPriceUpdate: DateTime.now(),
      dynamicData: '{}',
    ));
  }

  // Helper to create a deck with an active version
  Future<void> createDeckWithVersion({
    required String deckId,
    required String name,
    bool isRegistered = false,
    String versionId = 'v-default',
  }) async {
    await db.into(db.decks).insert(DecksCompanion.insert(
      id: deckId,
      name: name,
      format: 'Commander',
      tcgDomain: const drift.Value('mtg'),
      isRegistered: drift.Value(isRegistered),
      createdAt: DateTime.now(),
    ));

    await db.into(db.deckVersions).insert(DeckVersionsCompanion.insert(
      id: versionId,
      deckId: deckId,
      versionNumber: 1,
      isActive: const drift.Value(true),
      createdAt: DateTime.now(),
    ));
  }

  // Helper to add card to deck version
  Future<void> addDviItem({
    required String dviId,
    required String versionId,
    required String vaultItemId,
    required int quantity,
    String boardZone = 'Mainboard',
    bool isProxy = false,
  }) async {
    await db.into(db.deckVersionItems).insert(DeckVersionItemsCompanion.insert(
      id: dviId,
      versionId: versionId,
      vaultItemId: vaultItemId,
      quantity: drift.Value(quantity),
      boardZone: boardZone,
      isProxy: drift.Value(isProxy),
    ));
  }

  // Helper to wrap dialog for widget testing
  Widget createTestWidget({
    required Deck deck,
    DeckAssemblyPlan? precomputedPlan,
    double textScale = 1.0,
    AppDatabase? customDb,
    ValueChanged<bool>? onRegistrationChanged,
  }) {
    final activeDb = customDb ?? db;
    return ProviderScope(
      overrides: [
        vaultDaoProvider.overrideWithValue(activeDb.vaultDao),
      ],
      child: MaterialApp(
        theme: ThemeData.dark(),
        home: MediaQuery(
          data: MediaQueryData(
            textScaler: TextScaler.linear(textScale),
          ),
          child: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                key: const Key('open_assembly_dialog_btn'),
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => AssemblyPickListDialog(
                    deck: deck,
                    precomputedPlan: precomputedPlan,
                    onRegistrationChanged: onRegistrationChanged,
                  ),
                ),
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // GROUP 1: BOUNDARY DEFICIT SCENARIOS
  // =========================================================================
  group('Adversarial Deficit Boundaries (0 Deficit, 100% Proxy, Partial Splits)', () {
    test('Boundary 1: 100% owned (0 deficit) requires 0 proxies and direct registers', () async {
      await createBinder('binder-1', 'Rare Binder');
      await createVaultItem(id: 'sol-ring', name: 'Sol Ring', quantity: 4, binderId: 'binder-1');
      await createVaultItem(id: 'mana-drain', name: 'Mana Drain', quantity: 2, binderId: 'binder-1');

      const deckId = 'deck-100-owned';
      const verId = 'v-100-owned';
      await createDeckWithVersion(deckId: deckId, name: '100% Owned Deck', isRegistered: false, versionId: verId);

      await addDviItem(dviId: 'dvi-1', versionId: verId, vaultItemId: 'sol-ring', quantity: 2);
      await addDviItem(dviId: 'dvi-2', versionId: verId, vaultItemId: 'mana-drain', quantity: 2);

      final plan = await db.vaultDao.getDeckAssemblyPlan(deckId);

      // Verify exact boundary invariants
      expect(plan.totalRequired, equals(4));
      expect(plan.totalAvailable, equals(4));
      expect(plan.totalDeficit, equals(0));
      expect(plan.hasDeficit, isFalse);
      expect(plan.deficitItems, isEmpty);
      expect(plan.items.every((i) => i.deficitQuantity == 0), isTrue);
      expect(plan.items.every((i) => i.pullQuantity == i.requiredQuantity), isTrue);

      // Available quantity before registration (Draft deck does NOT lock)
      expect(await db.vaultDao.getAvailableQuantity('sol-ring'), equals(4));
      expect(await db.vaultDao.getAvailableQuantity('mana-drain'), equals(2));

      // Direct registration (no proxy prompt needed)
      await db.vaultDao.registerDeckWithProxyResolution(deckId: deckId, items: plan.items);

      // Verify deck is registered
      final registeredDeck = await (db.select(db.decks)..where((t) => t.id.equals(deckId))).getSingle();
      expect(registeredDeck.isRegistered, isTrue);

      // Verify physical items are locked
      expect(await db.vaultDao.getAvailableQuantity('sol-ring'), equals(2)); // 4 - 2 = 2
      expect(await db.vaultDao.getAvailableQuantity('mana-drain'), equals(0)); // 2 - 2 = 0

      // Invariants on deck version items: no proxy rows created
      final itemsInDb = await (db.select(db.deckVersionItems)..where((t) => t.versionId.equals(verId))).get();
      expect(itemsInDb.length, equals(2));
      expect(itemsInDb.every((i) => !i.isProxy), isTrue);
    });

    test('Boundary 2: 100% missing (full proxy) marks all cards as proxies without locking inventory', () async {
      // 0 inventory in vault
      await createVaultItem(id: 'black-lotus', name: 'Black Lotus', quantity: 0);
      await createVaultItem(id: 'mox-sapphire', name: 'Mox Sapphire', quantity: 0);

      const deckId = 'deck-100-missing';
      const verId = 'v-100-missing';
      await createDeckWithVersion(deckId: deckId, name: 'Vintage Proxy Deck', isRegistered: false, versionId: verId);

      await addDviItem(dviId: 'dvi-lotus', versionId: verId, vaultItemId: 'black-lotus', quantity: 1);
      await addDviItem(dviId: 'dvi-sapphire', versionId: verId, vaultItemId: 'mox-sapphire', quantity: 2);

      final plan = await db.vaultDao.getDeckAssemblyPlan(deckId);

      expect(plan.totalRequired, equals(3));
      expect(plan.totalAvailable, equals(0));
      expect(plan.totalDeficit, equals(3));
      expect(plan.hasDeficit, isTrue);
      expect(plan.itemsByLocation, isEmpty); // No physical pull locations
      expect(plan.deficitItems.length, equals(2));

      // Register with proxy resolution
      await db.vaultDao.registerDeckWithProxyResolution(deckId: deckId, items: plan.items);

      // Verify all items are marked as isProxy == true
      final itemsInDb = await (db.select(db.deckVersionItems)..where((t) => t.versionId.equals(verId))).get();
      expect(itemsInDb.length, equals(2));
      expect(itemsInDb.every((i) => i.isProxy), isTrue);

      // Verify available quantity in vault remains 0 without error or underflow
      expect(await db.vaultDao.getAvailableQuantity('black-lotus'), equals(0));
      expect(await db.vaultDao.getAvailableQuantity('mox-sapphire'), equals(0));
    });

    test('Boundary 3: Partial deficit splits a single item row into physical and proxy rows', () async {
      // Vault has only 1 Lightning Bolt, but deck requires 4
      await createVaultItem(id: 'lightning-bolt', name: 'Lightning Bolt', quantity: 1);

      const deckId = 'deck-burn';
      const verId = 'v-burn';
      await createDeckWithVersion(deckId: deckId, name: 'Modern Burn', isRegistered: false, versionId: verId);

      await addDviItem(
        dviId: 'dvi-bolt-orig',
        versionId: verId,
        vaultItemId: 'lightning-bolt',
        quantity: 4,
      );

      final plan = await db.vaultDao.getDeckAssemblyPlan(deckId);
      expect(plan.totalRequired, equals(4));
      expect(plan.totalAvailable, equals(1));
      expect(plan.totalDeficit, equals(3));
      expect(plan.hasDeficit, isTrue);

      final boltPlanItem = plan.items.firstWhere((i) => i.vaultItemId == 'lightning-bolt');
      expect(boltPlanItem.pullQuantity, equals(1));
      expect(boltPlanItem.deficitQuantity, equals(3));

      // Register with proxy resolution
      await db.vaultDao.registerDeckWithProxyResolution(deckId: deckId, items: plan.items);

      // Verify SQLite state: original row reduced to 1 physical, new proxy row created with 3
      final boltRows = await (db.select(db.deckVersionItems)
        ..where((t) => t.versionId.equals(verId) & t.vaultItemId.equals('lightning-bolt')))
        .get();

      expect(boltRows.length, equals(2));

      final physicalRow = boltRows.firstWhere((r) => !r.isProxy);
      final proxyRow = boltRows.firstWhere((r) => r.isProxy);

      expect(physicalRow.id, equals('dvi-bolt-orig'));
      expect(physicalRow.quantity, equals(1));
      expect(proxyRow.quantity, equals(3));

      // Verify available in vault dropped from 1 to 0 (locked physical copy)
      expect(await db.vaultDao.getAvailableQuantity('lightning-bolt'), equals(0));
    });

    test('Boundary 4: Existing proxy row is merged instead of creating duplicate proxy entries', () async {
      // Vault has 1 physical Counterspell.
      // Deck already has: 1 physical copy + 1 existing proxy copy (total 2 in deck).
      // Now deck is updated to require 3 copies on the physical row (deficit of 2).
      await createVaultItem(id: 'counterspell', name: 'Counterspell', quantity: 1);

      const deckId = 'deck-control';
      const verId = 'v-control';
      await createDeckWithVersion(deckId: deckId, name: 'Mono Blue Control', isRegistered: false, versionId: verId);

      await addDviItem(
        dviId: 'dvi-cs-phys',
        versionId: verId,
        vaultItemId: 'counterspell',
        quantity: 3,
        isProxy: false,
      );

      await addDviItem(
        dviId: 'dvi-cs-proxy',
        versionId: verId,
        vaultItemId: 'counterspell',
        quantity: 1,
        isProxy: true,
      );

      final plan = await db.vaultDao.getDeckAssemblyPlan(deckId);
      // Phys item requires 3, avail 1 -> pull 1, deficit 2.
      // Proxy item requires 1, isProxy true -> pull 0, deficit 0.
      expect(plan.totalDeficit, equals(2));

      await db.vaultDao.registerDeckWithProxyResolution(deckId: deckId, items: plan.items);

      // Verify SQLite: should still have exactly 2 rows (1 physical with qty 1, and 1 proxy with 1 + 2 = 3)
      final csRows = await (db.select(db.deckVersionItems)
        ..where((t) => t.versionId.equals(verId) & t.vaultItemId.equals('counterspell')))
        .get();

      expect(csRows.length, equals(2));
      final physicalRow = csRows.firstWhere((r) => !r.isProxy);
      final proxyRow = csRows.firstWhere((r) => r.isProxy);

      expect(physicalRow.quantity, equals(1));
      expect(proxyRow.quantity, equals(3)); // Merged: 1 existing + 2 resolved
    });
  });

  // =========================================================================
  // GROUP 2: SQLITE ALLOCATION INVARIANTS
  // =========================================================================
  group('SQLite Physical vs Proxy Allocation Invariants', () {
    test('Invariant 1: VaultDao.getAvailableQuantity only decrements for is_proxy = false in registered decks', () async {
      await createVaultItem(id: 'rhystic-study', name: 'Rhystic Study', quantity: 5);

      const deckRegId = 'deck-registered';
      const verRegId = 'v-reg';
      await createDeckWithVersion(deckId: deckRegId, name: 'Registered Deck', isRegistered: true, versionId: verRegId);

      // Add 2 physical copies
      await addDviItem(dviId: 'dvi-reg-phys', versionId: verRegId, vaultItemId: 'rhystic-study', quantity: 2, isProxy: false);
      // Add 2 proxy copies to the SAME registered deck
      await addDviItem(dviId: 'dvi-reg-proxy', versionId: verRegId, vaultItemId: 'rhystic-study', quantity: 2, isProxy: true);

      // Available should be 5 - 2 (physical only) = 3. Proxies do NOT lock.
      expect(await db.vaultDao.getAvailableQuantity('rhystic-study'), equals(3));
    });

    test('Invariant 2: Draft decks (is_registered = false) NEVER lock inventory', () async {
      await createVaultItem(id: 'cyclonic-rift', name: 'Cyclonic Rift', quantity: 2);

      const deckDraftId = 'deck-draft';
      const verDraftId = 'v-draft';
      await createDeckWithVersion(deckId: deckDraftId, name: 'Draft Deck', isRegistered: false, versionId: verDraftId);

      // Add 2 physical copies to draft deck
      await addDviItem(dviId: 'dvi-draft-phys', versionId: verDraftId, vaultItemId: 'cyclonic-rift', quantity: 2, isProxy: false);

      // Available must remain 2 (zero decrement)
      expect(await db.vaultDao.getAvailableQuantity('cyclonic-rift'), equals(2));
    });

    test('Invariant 3: Reverting to draft (disassemble) releases ALL inventory locks immediately', () async {
      await createVaultItem(id: 'dockside-extortionist', name: 'Dockside Extortionist', quantity: 3);

      const deckId = 'deck-dockside';
      const verId = 'v-dockside';
      await createDeckWithVersion(deckId: deckId, name: 'Treasure Storm', isRegistered: true, versionId: verId);

      await addDviItem(dviId: 'dvi-dockside', versionId: verId, vaultItemId: 'dockside-extortionist', quantity: 3, isProxy: false);

      // Fully allocated: available = 3 - 3 = 0
      expect(await db.vaultDao.getAvailableQuantity('dockside-extortionist'), equals(0));

      // Revert deck to Draft
      await db.vaultDao.setDeckRegistered(deckId, false);

      // Invariant: Available must immediately jump back to 3
      expect(await db.vaultDao.getAvailableQuantity('dockside-extortionist'), equals(3));
    });

    test('Invariant 4: Inactive deck versions (is_active = false) do not lock inventory even if deck is registered', () async {
      await createVaultItem(id: 'tarmogoyf', name: 'Tarmogoyf', quantity: 4);

      const deckId = 'deck-jund';
      await db.into(db.decks).insert(DecksCompanion.insert(
        id: deckId,
        name: 'Jund Midrange',
        format: 'Modern',
        tcgDomain: const drift.Value('mtg'),
        isRegistered: const drift.Value(true),
        createdAt: DateTime.now(),
      ));

      // Inactive version 1 holding 4 physical Goyfs
      await db.into(db.deckVersions).insert(DeckVersionsCompanion.insert(
        id: 'ver-inactive',
        deckId: deckId,
        versionNumber: 1,
        isActive: const drift.Value(false),
        createdAt: DateTime.now(),
      ));
      await addDviItem(dviId: 'dvi-goyf-old', versionId: 'ver-inactive', vaultItemId: 'tarmogoyf', quantity: 4);

      // Active version 2 holding only 1 physical Goyf
      await db.into(db.deckVersions).insert(DeckVersionsCompanion.insert(
        id: 'ver-active',
        deckId: deckId,
        versionNumber: 2,
        isActive: const drift.Value(true),
        createdAt: DateTime.now(),
      ));
      await addDviItem(dviId: 'dvi-goyf-new', versionId: 'ver-active', vaultItemId: 'tarmogoyf', quantity: 1);

      // Invariant: Only active version locks inventory -> 4 - 1 = 3 available
      expect(await db.vaultDao.getAvailableQuantity('tarmogoyf'), equals(3));
    });

    test('Invariant 5: Multi-deck concurrent allocation and release across 4 decks', () async {
      // 10 copies of Lightning Greaves
      await createVaultItem(id: 'greaves', name: 'Lightning Greaves', quantity: 10);

      // Deck 1: Registered, 3 physical copies
      await createDeckWithVersion(deckId: 'deck-1', name: 'Deck 1', isRegistered: true, versionId: 'v-1');
      await addDviItem(dviId: 'dvi-d1', versionId: 'v-1', vaultItemId: 'greaves', quantity: 3, isProxy: false);

      // Deck 2: Registered, 2 physical copies + 4 proxy copies
      await createDeckWithVersion(deckId: 'deck-2', name: 'Deck 2', isRegistered: true, versionId: 'v-2');
      await addDviItem(dviId: 'dvi-d2-phys', versionId: 'v-2', vaultItemId: 'greaves', quantity: 2, isProxy: false);
      await addDviItem(dviId: 'dvi-d2-prx', versionId: 'v-2', vaultItemId: 'greaves', quantity: 4, isProxy: true);

      // Deck 3: Draft, 5 physical copies (should NOT lock)
      await createDeckWithVersion(deckId: 'deck-3', name: 'Deck 3', isRegistered: false, versionId: 'v-3');
      await addDviItem(dviId: 'dvi-d3', versionId: 'v-3', vaultItemId: 'greaves', quantity: 5, isProxy: false);

      // Total locked = 3 (Deck 1) + 2 (Deck 2) = 5.
      // Available = 10 - 5 = 5.
      expect(await db.vaultDao.getAvailableQuantity('greaves'), equals(5));

      // Unregister Deck 1 -> locks release by 3 -> Available becomes 8
      await db.vaultDao.setDeckRegistered('deck-1', false);
      expect(await db.vaultDao.getAvailableQuantity('greaves'), equals(8));

      // Register Deck 3 -> locks increase by 5 -> Available becomes 8 - 5 = 3
      await db.vaultDao.setDeckRegistered('deck-3', true);
      expect(await db.vaultDao.getAvailableQuantity('greaves'), equals(3));

      // Unregister Deck 2 and Deck 3 -> all locks released -> Available = 10
      await db.vaultDao.setDeckRegistered('deck-2', false);
      await db.vaultDao.setDeckRegistered('deck-3', false);
      expect(await db.vaultDao.getAvailableQuantity('greaves'), equals(10));
    });

    test('Invariant 6: Maybeboard items are strictly excluded from assembly plan and inventory locks', () async {
      await createVaultItem(id: 'black-market', name: 'Black Market', quantity: 1);

      const deckId = 'deck-maybe';
      const verId = 'v-maybe';
      await createDeckWithVersion(deckId: deckId, name: 'Maybeboard Test Deck', isRegistered: true, versionId: verId);

      // Add to Maybeboard
      await addDviItem(
        dviId: 'dvi-mb',
        versionId: verId,
        vaultItemId: 'black-market',
        quantity: 1,
        boardZone: 'Maybeboard',
        isProxy: false,
      );

      final plan = await db.vaultDao.getDeckAssemblyPlan(deckId);
      // Assembly pick-list must ignore Maybeboard cards
      expect(plan.items, isEmpty);
      expect(plan.totalRequired, equals(0));
      expect(plan.totalAvailable, equals(0));
      expect(plan.totalDeficit, equals(0));
    });
  });

  // =========================================================================
  // GROUP 3: RAPID CHECKLIST TOGGLING & MULTI-LOCATION CHECK ALL
  // =========================================================================
  group('Rapid Checklist Toggling and Multi-Location Check All', () {
    DeckAssemblyPlan createMultiLocationPlan() {
      final b1Card1 = AssemblyPickItem(
        dviId: 'd1', vaultItemId: 'v1', cardName: 'Card Alpha 1', setCode: 'SET',
        boardZone: BoardZone.mainboard, requiredQuantity: 1, availableQuantity: 1,
        pullQuantity: 1, deficitQuantity: 0, locationName: 'Binder 1 - Mythics',
      );
      final b1Card2 = AssemblyPickItem(
        dviId: 'd2', vaultItemId: 'v2', cardName: 'Card Alpha 2', setCode: 'SET',
        boardZone: BoardZone.mainboard, requiredQuantity: 1, availableQuantity: 1,
        pullQuantity: 1, deficitQuantity: 0, locationName: 'Binder 1 - Mythics',
      );
      final b2Card1 = AssemblyPickItem(
        dviId: 'd3', vaultItemId: 'v3', cardName: 'Card Beta 1', setCode: 'SET',
        boardZone: BoardZone.mainboard, requiredQuantity: 2, availableQuantity: 2,
        pullQuantity: 2, deficitQuantity: 0, locationName: 'Binder 2 - Foils',
      );
      final b3Card1 = AssemblyPickItem(
        dviId: 'd4', vaultItemId: 'v4', cardName: 'Card Gamma 1', setCode: 'SET',
        boardZone: BoardZone.mainboard, requiredQuantity: 1, availableQuantity: 1,
        pullQuantity: 1, deficitQuantity: 0, locationName: 'Bulk Box Omega',
      );

      final items = [b1Card1, b1Card2, b2Card1, b3Card1];
      final itemsByLocation = {
        'Binder 1 - Mythics': [b1Card1, b1Card2],
        'Binder 2 - Foils': [b2Card1],
        'Bulk Box Omega': [b3Card1],
      };

      return DeckAssemblyPlan(
        deckId: 'deck-multi-loc',
        deckName: 'Multi Location Deck',
        items: items,
        itemsByLocation: itemsByLocation,
        deficitItems: [],
      );
    }

    testWidgets('Check All operates in strict isolation per location section', (tester) async {
      final plan = createMultiLocationPlan();
      final mockDeck = Deck(
        id: plan.deckId, name: plan.deckName, format: 'Commander',
        wins: 0, losses: 0, draws: 0, createdAt: DateTime.now(),
        tcgDomain: 'mtg', isRegistered: false, isCompetitive: false, isDeleted: false,
      );

      await tester.pumpWidget(createTestWidget(deck: mockDeck, precomputedPlan: plan));
      await tester.tap(find.byKey(const Key('open_assembly_dialog_btn')));
      await tester.pumpAndSettle();

      // Initial state: 0 / 5 Pulled
      expect(find.text('0 / 5 Pulled'), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);

      // Tap Check All on Binder 1 only
      final checkAllB1 = find.byKey(const Key('check_all_Binder 1 - Mythics'));
      expect(checkAllB1, findsOneWidget);
      await tester.tap(checkAllB1);
      await tester.pumpAndSettle();

      // Verify Binder 1 items pulled, others NOT pulled
      expect(plan.itemsByLocation['Binder 1 - Mythics']!.every((i) => i.isPulled), isTrue);
      expect(plan.itemsByLocation['Binder 2 - Foils']!.every((i) => !i.isPulled), isTrue);
      expect(plan.itemsByLocation['Bulk Box Omega']!.every((i) => !i.isPulled), isTrue);

      // Pulled count = 2 / 5 (40%)
      expect(find.text('2 / 5 Pulled'), findsOneWidget);
      expect(find.text('40%'), findsOneWidget);

      // Now tap Check All on Binder 2 (which has pullQuantity = 2)
      final checkAllB2 = find.byKey(const Key('check_all_Binder 2 - Foils'));
      await tester.tap(checkAllB2);
      await tester.pumpAndSettle();

      // Pulled count = 2 + 2 = 4 / 5 (80%)
      expect(find.text('4 / 5 Pulled'), findsOneWidget);
      expect(find.text('80%'), findsOneWidget);

      // Tap Check All on Bulk Box Omega (pullQuantity = 1) -> Reaches 100%
      await tester.drag(find.byType(ListView), const Offset(0, -200));
      await tester.pumpAndSettle();

      final checkAllB3 = find.byKey(const Key('check_all_Bulk Box Omega'));
      await tester.ensureVisible(checkAllB3);
      await tester.tap(checkAllB3);
      await tester.pumpAndSettle();

      // Scroll back up to view progress metrics
      await tester.drag(find.byType(ListView), const Offset(0, 200));
      await tester.pumpAndSettle();

      expect(find.text('5 / 5 Pulled'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
    });

    testWidgets('Rapid toggling and unchecking updates progress accurately without desync', (tester) async {
      final plan = createMultiLocationPlan();
      final mockDeck = Deck(
        id: plan.deckId, name: plan.deckName, format: 'Commander',
        wins: 0, losses: 0, draws: 0, createdAt: DateTime.now(),
        tcgDomain: 'mtg', isRegistered: false, isCompetitive: false, isDeleted: false,
      );

      await tester.pumpWidget(createTestWidget(deck: mockDeck, precomputedPlan: plan));
      await tester.tap(find.byKey(const Key('open_assembly_dialog_btn')));
      await tester.pumpAndSettle();

      // Check all on Binder 1 first
      await tester.tap(find.byKey(const Key('check_all_Binder 1 - Mythics')));
      await tester.pumpAndSettle();
      expect(find.text('2 / 5 Pulled'), findsOneWidget);

      // Find individual checkbox for Card Alpha 1
      final cardTile = find.text('Card Alpha 1');
      expect(cardTile, findsOneWidget);

      // Rapidly uncheck and re-check 6 times
      for (int i = 0; i < 6; i++) {
        await tester.tap(cardTile);
        await tester.pump();
      }
      await tester.pumpAndSettle();

      // Even number of taps -> Card Alpha 1 should be back to original checked state
      expect(plan.itemsByLocation['Binder 1 - Mythics']![0].isPulled, isTrue);
      expect(find.text('2 / 5 Pulled'), findsOneWidget);

      // Single tap to uncheck
      await tester.tap(cardTile);
      await tester.pumpAndSettle();

      expect(plan.itemsByLocation['Binder 1 - Mythics']![0].isPulled, isFalse);
      expect(find.text('1 / 5 Pulled'), findsOneWidget);
      expect(find.text('20%'), findsOneWidget);
    });
  });

  // =========================================================================
  // GROUP 4: LAYOUT RESILIENCE UNDER 300px/320px & 2.0x FONT SCALING
  // =========================================================================
  group('Layout Resilience & Overflow Stress (300px/320px + 2.0x Text Scale)', () {
    DeckAssemblyPlan createStressPlan({bool hasDeficit = true}) {
      final item1 = AssemblyPickItem(
        dviId: 'stress-1',
        vaultItemId: 'v-s1',
        cardName: 'Asmoranomardicadaistinaculdacar The Infinite Cook of the Underworld',
        setCode: 'LONGSETCODE',
        boardZone: BoardZone.mainboard,
        requiredQuantity: 4,
        availableQuantity: 2,
        pullQuantity: 2,
        deficitQuantity: hasDeficit ? 2 : 0,
        locationName: 'Binder Ultra Premium Vintage Edition 2026 With Very Long Title',
      );

      final item2 = AssemblyPickItem(
        dviId: 'stress-2',
        vaultItemId: 'v-s2',
        cardName: 'Urza Lord High Artificer Extreme Foil Slab Edition',
        setCode: 'MH1',
        boardZone: BoardZone.commander,
        requiredQuantity: 1,
        availableQuantity: 1,
        pullQuantity: 1,
        deficitQuantity: 0,
        locationName: 'Commander Deckbox Gold',
      );

      final items = [item1, item2];
      final itemsByLocation = {
        'Binder Ultra Premium Vintage Edition 2026 With Very Long Title': [item1],
        'Commander Deckbox Gold': [item2],
      };
      final deficitItems = hasDeficit ? [item1] : <AssemblyPickItem>[];

      return DeckAssemblyPlan(
        deckId: 'deck-stress',
        deckName: 'Stress Test Deck With Super Long Name In The Header To Verify Ellipsis',
        items: items,
        itemsByLocation: itemsByLocation,
        deficitItems: deficitItems,
      );
    }

    testWidgets('300px viewport + 2.0x text scale renders without RenderFlex overflow (Draft mode)', (tester) async {
      tester.view.physicalSize = const Size(300, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final plan = createStressPlan(hasDeficit: true);
      final mockDeck = Deck(
        id: plan.deckId, name: plan.deckName, format: 'Commander',
        wins: 0, losses: 0, draws: 0, createdAt: DateTime.now(),
        tcgDomain: 'mtg', isRegistered: false, isCompetitive: false, isDeleted: false,
      );

      await tester.pumpWidget(createTestWidget(
        deck: mockDeck,
        precomputedPlan: plan,
        textScale: 2.0,
      ));

      await tester.tap(find.byKey(const Key('open_assembly_dialog_btn')));
      await tester.pumpAndSettle();

      // Zero exceptions / RenderFlex overflows
      expect(tester.takeException(), isNull);

      // Verify header, metrics, deficit warning banner render
      expect(find.text('Deck Assembly Pick-List'), findsOneWidget);
      expect(find.text('Total'), findsOneWidget);
      expect(find.text('Deficit'), findsOneWidget);
      expect(find.textContaining('Card Deficit'), findsOneWidget);

      // Verify Register Deck button is present and clickable
      final registerBtn = find.byKey(const Key('assembly_register_deck_button'));
      expect(registerBtn, findsOneWidget);

      // Tap Register Deck -> proxy confirmation dialog must also render without overflow on 300px + 2.0x text scale
      await tester.tap(registerBtn);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Missing Cards Fallback'), findsOneWidget);
      expect(find.byKey(const Key('confirm_register_with_proxies_button')), findsOneWidget);

      // Dismiss dialog
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('320px viewport + 2.0x text scale renders without RenderFlex overflow (Draft mode with deficit)', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final plan = createStressPlan(hasDeficit: true);
      final mockDeck = Deck(
        id: plan.deckId, name: plan.deckName, format: 'Commander',
        wins: 0, losses: 0, draws: 0, createdAt: DateTime.now(),
        tcgDomain: 'mtg', isRegistered: false, isCompetitive: false, isDeleted: false,
      );

      await tester.pumpWidget(createTestWidget(
        deck: mockDeck,
        precomputedPlan: plan,
        textScale: 2.0,
      ));

      await tester.tap(find.byKey(const Key('open_assembly_dialog_btn')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('320px viewport + 2.0x text scale with bulk quantity (100 cards)', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final item = AssemblyPickItem(
        dviId: 'bulk-1',
        vaultItemId: 'v-b1',
        cardName: 'Relentless Rats Bulk',
        setCode: 'A25',
        boardZone: BoardZone.mainboard,
        requiredQuantity: 100,
        availableQuantity: 100,
        pullQuantity: 100,
        deficitQuantity: 0,
        locationName: 'Commander Bulk Box',
      );

      final plan = DeckAssemblyPlan(
        deckId: 'deck-bulk',
        deckName: 'Bulk Rats Deck',
        items: [item],
        itemsByLocation: {'Commander Bulk Box': [item]},
        deficitItems: [],
      );

      final mockDeck = Deck(
        id: plan.deckId, name: plan.deckName, format: 'Commander',
        wins: 0, losses: 0, draws: 0, createdAt: DateTime.now(),
        tcgDomain: 'mtg', isRegistered: false, isCompetitive: false, isDeleted: false,
      );

      await tester.pumpWidget(createTestWidget(
        deck: mockDeck,
        precomputedPlan: plan,
        textScale: 2.0,
      ));

      await tester.tap(find.byKey(const Key('open_assembly_dialog_btn')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('320px viewport + 2.0x text scale renders without RenderFlex overflow (Registered / Disassemble mode)', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final plan = createStressPlan(hasDeficit: false);
      final mockDeck = Deck(
        id: plan.deckId, name: plan.deckName, format: 'Commander',
        wins: 0, losses: 0, draws: 0, createdAt: DateTime.now(),
        tcgDomain: 'mtg', isRegistered: true, isCompetitive: false, isDeleted: false,
      );

      bool unregisteredCalled = false;

      await tester.pumpWidget(createTestWidget(
        deck: mockDeck,
        precomputedPlan: plan,
        textScale: 2.0,
        onRegistrationChanged: (registered) {
          if (!registered) unregisteredCalled = true;
        },
      ));

      await tester.tap(find.byKey(const Key('open_assembly_dialog_btn')));
      await tester.pumpAndSettle();

      // Zero exceptions / RenderFlex overflows
      expect(tester.takeException(), isNull);

      // Bottom bar must display Disassemble button
      final unregisterBtn = find.byKey(const Key('button_unregister_deck'));
      expect(unregisterBtn, findsOneWidget);

      // Tap Disassemble
      await tester.tap(unregisterBtn);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(unregisteredCalled, isTrue);
    });

    testWidgets('Empty deck edge case renders cleanly on 300px viewport', (tester) async {
      tester.view.physicalSize = const Size(300, 500);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final emptyPlan = DeckAssemblyPlan(
        deckId: 'empty-deck',
        deckName: 'Empty Deck',
        items: [],
        itemsByLocation: {},
        deficitItems: [],
      );

      final mockDeck = Deck(
        id: emptyPlan.deckId, name: emptyPlan.deckName, format: 'Commander',
        wins: 0, losses: 0, draws: 0, createdAt: DateTime.now(),
        tcgDomain: 'mtg', isRegistered: false, isCompetitive: false, isDeleted: false,
      );

      await tester.pumpWidget(createTestWidget(
        deck: mockDeck,
        precomputedPlan: emptyPlan,
        textScale: 1.5,
      ));

      await tester.tap(find.byKey(const Key('open_assembly_dialog_btn')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('No cards to assemble in this deck.'), findsOneWidget);
    });
  });
}
