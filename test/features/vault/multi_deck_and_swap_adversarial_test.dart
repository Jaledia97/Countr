import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/decks/presentation/widgets/conflict_resolution_modal.dart';
import 'package:countr/features/decks/presentation/widgets/deck_swap_printing_sheet.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/multi_deck_allocation_sheet.dart';
import 'package:countr/features/vault/presentation/widgets/switch_printing_modal.dart';

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

  group('Adversarial Stress Test: Multi-Deck Stepper (Feature 13)', () {
    testWidgets('Stepper zero-decrement removal: removes row, disables decrement at 0, syncs deck_history', (tester) async {
      // 1. Create deck & item
      await db.into(db.decks).insert(DecksCompanion.insert(
        id: 'deck-alpha',
        name: 'Deck Alpha',
        format: 'Commander',
        isAssembled: const drift.Value(true),
        createdAt: DateTime.now(),
      ));

      await db.into(db.vaultItems).insert(VaultItemsCompanion.insert(
        id: 'item-bolt',
        collectionType: 'mtg',
        name: 'Lightning Bolt',
        setOrSeries: 'M11',
        imageUrl: 'https://example.com/bolt.jpg',
        acquiredPrice: 1.0,
        acquiredDate: DateTime.now(),
        quantity: const drift.Value(4),
        condition: 'NM',
        currentMarketPrice: 1.50,
        lastPriceUpdate: DateTime.now(),
        dynamicData: '{}',
      ));

      // Initially allocate 1 copy to Deck Alpha
      await db.vaultDao.addCardToDeck('deck-alpha', 'item-bolt', quantity: 1);

      // Verify initial deck history
      var item = await db.vaultDao.getItemById('item-bolt');
      var dyn = jsonDecode(item!.dynamicData) as Map<String, dynamic>;
      expect((dyn['deck_history'] as List).cast<String>(), contains('Deck Alpha'));

      final testItem = item;

      // Pump MultiDeckAllocationSheet UI
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vaultDaoProvider.overrideWithValue(db.vaultDao),
            deckListProvider.overrideWith((ref) => db.select(db.decks).watch()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => MultiDeckAllocationSheet.show(context, testItem),
                  child: const Text('Open Sheet'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Quantity should be 1
      final qtyFinder = find.byKey(const Key('stepper_quantity_deck-alpha'));
      expect(find.descendant(of: qtyFinder, matching: find.text('1')), findsOneWidget);

      // Tap decrement to reduce to 0
      final decButton = find.byKey(const Key('stepper_decrement_deck-alpha'));
      await tester.tap(decButton);
      await tester.pumpAndSettle();

      // Quantity should now be 0
      expect(find.descendant(of: qtyFinder, matching: find.text('0')), findsOneWidget);

      // Decrement button should be disabled (onPressed is null)
      final decWidget = tester.widget<IconButton>(decButton);
      expect(decWidget.onPressed, isNull);

      // Verify database row is deleted
      final activeVersion = await (db.select(db.deckVersions)
            ..where((t) => t.deckId.equals('deck-alpha') & t.isActive.equals(true)))
          .getSingle();
      final rows = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals(activeVersion.id) & t.vaultItemId.equals('item-bolt') & t.isDeleted.equals(false)))
          .get();
      expect(rows.isEmpty, isTrue, reason: 'Row must be completely deleted when quantity drops to 0');

      // Verify dynamicData['deck_history'] no longer contains 'Deck Alpha'
      item = await db.vaultDao.getItemById('item-bolt');
      dyn = jsonDecode(item!.dynamicData) as Map<String, dynamic>;
      final history = (dyn['deck_history'] as List).cast<String>();
      expect(history.contains('Deck Alpha'), isFalse);

      // Clean up widget tree
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    test('Rapid concurrent DAO tapping stress: no duplicate rows or corrupted state', () async {
      await db.into(db.decks).insert(DecksCompanion.insert(
        id: 'deck-rapid',
        name: 'Rapid Deck',
        format: 'Modern',
        createdAt: DateTime.now(),
      ));

      await db.into(db.vaultItems).insert(VaultItemsCompanion.insert(
        id: 'item-lotus',
        collectionType: 'mtg',
        name: 'Black Lotus',
        setOrSeries: 'Vintage Masters',
        imageUrl: 'https://example.com/lotus.jpg',
        acquiredPrice: 5000.0,
        acquiredDate: DateTime.now(),
        quantity: const drift.Value(4),
        condition: 'NM',
        currentMarketPrice: 8000.0,
        lastPriceUpdate: DateTime.now(),
        dynamicData: '{}',
      ));

      // Fire 5 sequential additions to simulate rapid burst taps
      for (int i = 0; i < 5; i++) {
        await db.vaultDao.addCardToDeck('deck-rapid', 'item-lotus', quantity: 1);
      }

      // Check deckVersionItems - must have EXACTLY 1 row with quantity = 5, NOT 5 duplicate rows
      final activeVersion = await (db.select(db.deckVersions)
            ..where((t) => t.deckId.equals('deck-rapid') & t.isActive.equals(true)))
          .getSingle();
      final items = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals(activeVersion.id) & t.vaultItemId.equals('item-lotus')))
          .get();

      expect(items.length, 1, reason: 'There must be strictly 1 row per card zone in deck_version_items');
      expect(items.first.quantity, 5);

      // Test extreme: setCardQuantityInDeck to 0 and negative
      await db.vaultDao.setCardQuantityInDeck('deck-rapid', 'item-lotus', 0);
      final afterZero = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals(activeVersion.id) & t.vaultItemId.equals('item-lotus') & t.isDeleted.equals(false)))
          .get();
      expect(afterZero.isEmpty, isTrue);

      await db.vaultDao.setCardQuantityInDeck('deck-rapid', 'item-lotus', -10);
      final afterNegative = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals(activeVersion.id) & t.vaultItemId.equals('item-lotus') & t.isDeleted.equals(false)))
          .get();
      expect(afterNegative.isEmpty, isTrue);
    });

    testWidgets('Incrementing past available physical count in registered decks triggers proxy prompt', (tester) async {
      // 1. Create two registered decks
      await db.into(db.decks).insert(DecksCompanion.insert(
        id: 'deck-reg-1',
        name: 'Urza Registered',
        format: 'Commander',
        isRegistered: const drift.Value(true),
        createdAt: DateTime.now(),
      ));

      await db.into(db.decks).insert(DecksCompanion.insert(
        id: 'deck-reg-2',
        name: 'Mishra Registered',
        format: 'Commander',
        isRegistered: const drift.Value(true),
        createdAt: DateTime.now(),
      ));

      // 2. Insert item with quantity = 1 (only 1 physical copy)
      await db.into(db.vaultItems).insert(VaultItemsCompanion.insert(
        id: 'item-mox-opal',
        collectionType: 'mtg',
        name: 'Mox Opal',
        setOrSeries: 'Scars of Mirrodin',
        imageUrl: 'https://example.com/mox.jpg',
        acquiredPrice: 50.0,
        acquiredDate: DateTime.now(),
        quantity: const drift.Value(1),
        condition: 'NM',
        currentMarketPrice: 70.0,
        lastPriceUpdate: DateTime.now(),
        dynamicData: '{}',
      ));

      // 3. Allocate the 1 physical copy to Urza Registered
      await db.vaultDao.addCardToDeck('deck-reg-1', 'item-mox-opal', quantity: 1, isProxy: false);

      // Available physical count should now be 0
      final avail = await db.vaultDao.getAvailableQuantity('item-mox-opal');
      expect(avail, 0);

      final testItem = await db.vaultDao.getItemById('item-mox-opal');

      // 4. Open MultiDeckAllocationSheet
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vaultDaoProvider.overrideWithValue(db.vaultDao),
            deckListProvider.overrideWith((ref) => db.select(db.decks).watch()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => MultiDeckAllocationSheet.show(context, testItem!),
                  child: const Text('Open Allocation Sheet'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Allocation Sheet'));
      await tester.pumpAndSettle();

      // Verify Available = 0
      expect(find.text('0'), findsWidgets);
      expect(find.text('Available'), findsOneWidget);

      // Tap [+] on Mishra Registered (deck-reg-2)
      final incMishra = find.byKey(const Key('stepper_increment_deck-reg-2'));
      await tester.tap(incMishra);
      await tester.pumpAndSettle();

      // ConflictResolutionModal should open because physical copies are exhausted in registered deck
      expect(find.byType(ConflictResolutionModal), findsOneWidget);
      expect(find.text('Inventory Conflict'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ConflictResolutionModal),
          matching: find.textContaining('Urza Registered'),
        ),
        findsOneWidget,
      );
      expect(find.text('Add as Proxy'), findsOneWidget);
      expect(find.text('Move Physical Here'), findsOneWidget);

      // Tap 'Add as Proxy'
      await tester.tap(find.text('Add as Proxy'));
      await tester.pumpAndSettle();

      // Verify Mishra Registered now has 1 proxy copy
      final mishraVersion = await (db.select(db.deckVersions)
            ..where((t) => t.deckId.equals('deck-reg-2') & t.isActive.equals(true)))
          .getSingle();
      final mishraItems = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals(mishraVersion.id) & t.vaultItemId.equals('item-mox-opal')))
          .get();

      expect(mishraItems.length, 1);
      expect(mishraItems.first.isProxy, isTrue, reason: 'Must be added as a proxy');
      expect(mishraItems.first.quantity, 1);

      // Available physical count should STILL be 0 (proxy does not decrement physical count)
      final availAfterProxy = await db.vaultDao.getAvailableQuantity('item-mox-opal');
      expect(availAfterProxy, 0);

      // Clean up widget tree
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('Conflict modal Move Physical Here transfers copy and preserves inventory invariants', (tester) async {
      // 1. Create two registered decks
      await db.into(db.decks).insert(DecksCompanion.insert(
        id: 'deck-donor',
        name: 'Donor Deck',
        format: 'Commander',
        isRegistered: const drift.Value(true),
        createdAt: DateTime.now(),
      ));

      await db.into(db.decks).insert(DecksCompanion.insert(
        id: 'deck-recipient',
        name: 'Recipient Deck',
        format: 'Commander',
        isRegistered: const drift.Value(true),
        createdAt: DateTime.now(),
      ));

      // 2. Insert item with quantity = 1
      await db.into(db.vaultItems).insert(VaultItemsCompanion.insert(
        id: 'item-sol-conflict',
        collectionType: 'mtg',
        name: 'Sol Ring Conflict',
        setOrSeries: 'Commander 2021',
        imageUrl: 'https://example.com/sol-c.jpg',
        acquiredPrice: 2.0,
        acquiredDate: DateTime.now(),
        quantity: const drift.Value(1),
        condition: 'NM',
        currentMarketPrice: 2.50,
        lastPriceUpdate: DateTime.now(),
        dynamicData: '{}',
      ));

      // 3. Allocate 1 copy to Donor Deck
      await db.vaultDao.addCardToDeck('deck-donor', 'item-sol-conflict', quantity: 1, isProxy: false);
      expect(await db.vaultDao.getAvailableQuantity('item-sol-conflict'), 0);

      final testItem = await db.vaultDao.getItemById('item-sol-conflict');

      // 4. Open sheet
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vaultDaoProvider.overrideWithValue(db.vaultDao),
            deckListProvider.overrideWith((ref) => db.select(db.decks).watch()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => MultiDeckAllocationSheet.show(context, testItem!),
                  child: const Text('Open Sheet'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Tap [+] on Recipient Deck (deck-recipient)
      final incRecipient = find.byKey(const Key('stepper_increment_deck-recipient'));
      await tester.tap(incRecipient);
      await tester.pumpAndSettle();

      // Tap 'Move Physical Here'
      expect(find.byType(ConflictResolutionModal), findsOneWidget);
      await tester.tap(find.text('Move Physical Here'));
      await tester.pumpAndSettle();

      // Verify physical copy moved: donor should have 0, recipient should have 1
      final donorVersion = await (db.select(db.deckVersions)
            ..where((t) => t.deckId.equals('deck-donor') & t.isActive.equals(true)))
          .getSingle();
      final donorItems = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals(donorVersion.id) & t.vaultItemId.equals('item-sol-conflict') & t.isDeleted.equals(false)))
          .get();
      expect(donorItems.isEmpty, isTrue, reason: 'Physical copy must be removed from donor deck');

      final recipientVersion = await (db.select(db.deckVersions)
            ..where((t) => t.deckId.equals('deck-recipient') & t.isActive.equals(true)))
          .getSingle();
      final recipientItems = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals(recipientVersion.id) & t.vaultItemId.equals('item-sol-conflict')))
          .get();
      expect(recipientItems.length, 1);
      expect(recipientItems.first.isProxy, isFalse, reason: 'Recipient receives the physical copy');
      expect(recipientItems.first.quantity, 1);

      // Verify dynamicData['deck_history'] updated to Donor -> Recipient
      final itemAfterMove = await db.vaultDao.getItemById('item-sol-conflict');
      final dyn = jsonDecode(itemAfterMove!.dynamicData) as Map<String, dynamic>;
      final hist = (dyn['deck_history'] as List).cast<String>();
      expect(hist.contains('Donor Deck'), isFalse, reason: 'Donor deck removed from deck_history');
      expect(hist.contains('Recipient Deck'), isTrue, reason: 'Recipient deck added to deck_history');

      // Clean up widget tree
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('Draft decks (isRegistered == false) can increment even when physical stock is 0 without conflict modal', (tester) async {
      await db.into(db.decks).insert(DecksCompanion.insert(
        id: 'deck-draft-test',
        name: 'Draft Testing Deck',
        format: 'Commander',
        isRegistered: const drift.Value(false),
        createdAt: DateTime.now(),
      ));

      await db.into(db.vaultItems).insert(VaultItemsCompanion.insert(
        id: 'item-draft-card',
        collectionType: 'mtg',
        name: 'Draft Card Test',
        setOrSeries: 'M10',
        imageUrl: 'https://example.com/draft.jpg',
        acquiredPrice: 1.0,
        acquiredDate: DateTime.now(),
        quantity: const drift.Value(0), // 0 owned in vault!
        condition: 'NM',
        currentMarketPrice: 1.00,
        lastPriceUpdate: DateTime.now(),
        dynamicData: '{}',
      ));

      final testItem = await db.vaultDao.getItemById('item-draft-card');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vaultDaoProvider.overrideWithValue(db.vaultDao),
            deckListProvider.overrideWith((ref) => db.select(db.decks).watch()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => MultiDeckAllocationSheet.show(context, testItem!),
                  child: const Text('Open Sheet'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Tap [+] on Draft Testing Deck
      final incBtn = find.byKey(const Key('stepper_increment_deck-draft-test'));
      await tester.tap(incBtn);
      await tester.pumpAndSettle();

      // Must NOT display ConflictResolutionModal since draft decks do not lock physical inventory
      expect(find.byType(ConflictResolutionModal), findsNothing);

      // Verify draft deck now has 1 copy allocated
      final qtyFinder = find.byKey(const Key('stepper_quantity_deck-draft-test'));
      expect(find.descendant(of: qtyFinder, matching: find.text('1')), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });

  group('Adversarial Stress Test: Global Swap Printing in Deck Builder (Feature 11)', () {
    test('Repeated printing swaps do not corrupt or orphan deck version items', () async {
      // 1. Create deck & version
      await db.into(db.decks).insert(DecksCompanion.insert(
        id: 'deck-counter',
        name: 'Control Deck',
        format: 'Modern',
        isRegistered: const drift.Value(true),
        createdAt: DateTime.now(),
      ));

      await db.into(db.deckVersions).insert(DeckVersionsCompanion.insert(
        id: 'v-counter-1',
        deckId: 'deck-counter',
        versionNumber: 1,
        createdAt: DateTime.now(),
      ));

      // 2. Insert 3 printings of Counterspell
      final printings = [
        ('item-cs-ema', 'Eternal Masters', 3.0),
        ('item-cs-mh2', 'Modern Horizons 2', 1.5),
        ('item-cs-lea', 'Alpha', 1000.0),
      ];

      for (final p in printings) {
        await db.into(db.vaultItems).insert(VaultItemsCompanion.insert(
          id: p.$1,
          collectionType: 'mtg',
          name: 'Counterspell',
          setOrSeries: p.$2,
          imageUrl: 'https://example.com/${p.$1}.jpg',
          acquiredPrice: p.$3,
          acquiredDate: DateTime.now(),
          quantity: const drift.Value(1),
          condition: 'NM',
          currentMarketPrice: p.$3,
          lastPriceUpdate: DateTime.now(),
          dynamicData: '{"oracle_id": "oracle-counterspell"}',
        ));
      }

      // 3. Create initial DVI pointing to Print A (EMA)
      await db.into(db.deckVersionItems).insert(DeckVersionItemsCompanion.insert(
        id: 'dvi-cs-1',
        versionId: 'v-counter-1',
        vaultItemId: 'item-cs-ema',
        boardZone: 'Mainboard',
        quantity: const drift.Value(1),
      ));

      // 4. Repeatedly cycle swaps: EMA -> MH2 -> LEA -> EMA -> MH2 -> LEA -> EMA
      final swapSequence = [
        'item-cs-mh2',
        'item-cs-lea',
        'item-cs-ema',
        'item-cs-mh2',
        'item-cs-lea',
        'item-cs-ema',
      ];

      for (final targetId in swapSequence) {
        await db.vaultDao.swapDeckItemPrinting('dvi-cs-1', targetId);

        // Verify deck version item is not corrupted or orphaned
        final allItems = await (db.select(db.deckVersionItems)
              ..where((t) => t.versionId.equals('v-counter-1')))
            .get();

        expect(allItems.length, 1, reason: 'There must be strictly 1 item in the deck version');
        expect(allItems.first.id, 'dvi-cs-1');
        expect(allItems.first.vaultItemId, targetId);

        // Verify foreign key integrity: targetId exists in vault_items
        final vaultItem = await db.vaultDao.getItemById(targetId);
        expect(vaultItem, isNotNull);

        // Verify physical allocation tracks the active printing dynamically
        for (final p in printings) {
          final avail = await db.vaultDao.getAvailableQuantity(p.$1);
          if (p.$1 == targetId) {
            expect(avail, 0, reason: 'Currently assigned printing in registered deck must have 0 available');
          } else {
            expect(avail, 1, reason: 'Unassigned printing must have 1 available');
          }
        }
      }
    });

    test('getAlternativePrintings matches double-faced cards by full name or front-face', () async {
      await db.into(db.vaultItems).insert(VaultItemsCompanion.insert(
        id: 'item-delver-1',
        collectionType: 'mtg',
        name: 'Delver of Secrets // Insectile Aberration',
        setOrSeries: 'Innistrad',
        imageUrl: 'https://example.com/isd.jpg',
        acquiredPrice: 1.0,
        acquiredDate: DateTime.now(),
        quantity: const drift.Value(1),
        condition: 'NM',
        currentMarketPrice: 1.50,
        lastPriceUpdate: DateTime.now(),
        dynamicData: '{}',
      ));

      await db.into(db.vaultItems).insert(VaultItemsCompanion.insert(
        id: 'item-delver-2',
        collectionType: 'mtg',
        name: 'Delver of Secrets // Insectile Aberration',
        setOrSeries: 'Midnight Hunt',
        imageUrl: 'https://example.com/mid.jpg',
        acquiredPrice: 0.5,
        acquiredDate: DateTime.now(),
        quantity: const drift.Value(1),
        condition: 'NM',
        currentMarketPrice: 0.75,
        lastPriceUpdate: DateTime.now(),
        dynamicData: '{}',
      ));

      // Query by front face only
      final alternativesFrontOnly = await db.vaultDao.getAlternativePrintings(
        'Delver of Secrets',
        excludeVaultItemId: 'item-delver-1',
      );
      expect(alternativesFrontOnly.length, 1);
      expect(alternativesFrontOnly.first.id, 'item-delver-2');

      // Query by full double-face name
      final alternativesFullName = await db.vaultDao.getAlternativePrintings(
        'Delver of Secrets // Insectile Aberration',
        excludeVaultItemId: 'item-delver-2',
      );
      expect(alternativesFullName.length, 1);
      expect(alternativesFullName.first.id, 'item-delver-1');
    });

    testWidgets('DeckSwapPrintingSheet UI handles rapid selections and confirms clean swap', (tester) async {
      await db.into(db.vaultBinders).insert(VaultBindersCompanion.insert(
        id: 'binder-spells',
        name: 'Spells Binder',
        collectionType: 'mtg',
        createdAt: DateTime.now(),
      ));

      await db.into(db.decks).insert(DecksCompanion.insert(
        id: 'deck-urza-swap',
        name: 'Urza Swap',
        format: 'Commander',
        createdAt: DateTime.now(),
      ));

      await db.into(db.deckVersions).insert(DeckVersionsCompanion.insert(
        id: 'v-swap-1',
        deckId: 'deck-urza-swap',
        versionNumber: 1,
        createdAt: DateTime.now(),
      ));

      await db.into(db.vaultItems).insert(VaultItemsCompanion.insert(
        id: 'item-sol-orig',
        collectionType: 'mtg',
        name: 'Sol Ring',
        setOrSeries: 'Commander 2020',
        imageUrl: 'https://example.com/c20.jpg',
        acquiredPrice: 2.0,
        acquiredDate: DateTime.now(),
        quantity: const drift.Value(1),
        condition: 'NM',
        currentMarketPrice: 2.00,
        lastPriceUpdate: DateTime.now(),
        dynamicData: '{"oracle_id": "oracle-sol-ring"}',
      ));

      await db.into(db.vaultItems).insert(VaultItemsCompanion.insert(
        id: 'item-sol-alt1',
        collectionType: 'mtg',
        name: 'Sol Ring',
        setOrSeries: 'Kaladesh Inventions',
        imageUrl: 'https://example.com/mps.jpg',
        acquiredPrice: 300.0,
        acquiredDate: DateTime.now(),
        quantity: const drift.Value(1),
        primaryBinderId: const drift.Value('binder-spells'),
        condition: 'NM',
        currentMarketPrice: 450.00,
        lastPriceUpdate: DateTime.now(),
        dynamicData: '{"oracle_id": "oracle-sol-ring"}',
      ));

      await db.into(db.deckVersionItems).insert(DeckVersionItemsCompanion.insert(
        id: 'dvi-sol-swap',
        versionId: 'v-swap-1',
        vaultItemId: 'item-sol-orig',
        boardZone: 'Mainboard',
        quantity: const drift.Value(1),
      ));

      bool swapped = false;

      final deckItemMap = {
        'dvi_id': 'dvi-sol-swap',
        'vault_item_id': 'item-sol-orig',
        'name': 'Sol Ring',
        'set_or_series': 'Commander 2020',
        'image_url': 'https://example.com/c20.jpg',
        'current_market_price': 2.00,
        'dynamic_data': '{"oracle_id": "oracle-sol-ring"}',
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vaultDaoProvider.overrideWithValue(db.vaultDao),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => DeckSwapPrintingSheet.show(
                    context,
                    deckId: 'deck-urza-swap',
                    deckItem: deckItemMap,
                    onSwapped: () => swapped = true,
                  ),
                  child: const Text('Open Swap Sheet'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Swap Sheet'));
      await tester.pumpAndSettle();

      // Verify currently assigned
      expect(find.text('Commander 2020'), findsOneWidget);

      // Verify alternative is displayed
      expect(find.text('Kaladesh Inventions'), findsOneWidget);
      expect(find.textContaining('Spells Binder'), findsOneWidget);

      // Select Kaladesh Inventions
      await tester.tap(find.text('Kaladesh Inventions'));
      await tester.pumpAndSettle();

      // Confirm swap
      final confirmBtn = find.byKey(const Key('confirm_swap_printing_button'));
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      expect(swapped, isTrue);

      // Verify DB updated
      final updatedDvi = await (db.select(db.deckVersionItems)
            ..where((t) => t.id.equals('dvi-sol-swap')))
          .getSingle();
      expect(updatedDvi.vaultItemId, 'item-sol-alt1');
    });

    test('Swapping printing in deck updates dynamicData[deck_history] consistently for both printings', () async {
      await db.into(db.decks).insert(DecksCompanion.insert(
        id: 'deck-history-swap',
        name: 'History Swap Deck',
        format: 'Commander',
        isAssembled: const drift.Value(true),
        createdAt: DateTime.now(),
      ));

      await db.into(db.deckVersions).insert(DeckVersionsCompanion.insert(
        id: 'v-history-swap',
        deckId: 'deck-history-swap',
        versionNumber: 1,
        createdAt: DateTime.now(),
      ));

      await db.into(db.vaultItems).insert(VaultItemsCompanion.insert(
        id: 'item-sol-hist-a',
        collectionType: 'mtg',
        name: 'Sol Ring',
        setOrSeries: 'Printing A',
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
        id: 'item-sol-hist-b',
        collectionType: 'mtg',
        name: 'Sol Ring',
        setOrSeries: 'Printing B',
        imageUrl: 'https://example.com/b.jpg',
        acquiredPrice: 3.0,
        acquiredDate: DateTime.now(),
        quantity: const drift.Value(1),
        condition: 'NM',
        currentMarketPrice: 3.00,
        lastPriceUpdate: DateTime.now(),
        dynamicData: '{}',
      ));

      // Add item A to deck
      await db.vaultDao.addCardToDeck('deck-history-swap', 'item-sol-hist-a', quantity: 1);

      // Verify item A has 'History Swap Deck' in history
      var itemA = await db.vaultDao.getItemById('item-sol-hist-a');
      var dynA = jsonDecode(itemA!.dynamicData) as Map<String, dynamic>;
      expect((dynA['deck_history'] as List).cast<String>(), contains('History Swap Deck'));

      // Find DVI id
      final dvi = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals('v-history-swap') & t.vaultItemId.equals('item-sol-hist-a')))
          .getSingle();

      // Swap to item B
      await db.vaultDao.swapDeckItemPrinting(dvi.id, 'item-sol-hist-b');

      // Check item B: does it have 'History Swap Deck' in deck_history?
      final itemB = await db.vaultDao.getItemById('item-sol-hist-b');
      final dynB = jsonDecode(itemB!.dynamicData) as Map<String, dynamic>;
      final histB = (dynB['deck_history'] as List?)?.cast<String>() ?? [];

      // Check item A: does it still have 'History Swap Deck' in deck_history?
      itemA = await db.vaultDao.getItemById('item-sol-hist-a');
      dynA = jsonDecode(itemA!.dynamicData) as Map<String, dynamic>;
      final histA = (dynA['deck_history'] as List?)?.cast<String>() ?? [];

      expect(histB, contains('History Swap Deck'), reason: 'Swapped-in item must record deck in deck_history');
      expect(histA.contains('History Swap Deck'), isFalse, reason: 'Swapped-out item must have deck removed from deck_history');
    });

    test('Swapping printing when target printing is already present in same board zone does not corrupt deckVersionItems', () async {
      await db.into(db.decks).insert(DecksCompanion.insert(
        id: 'deck-dup-check',
        name: 'Duplicate Check Deck',
        format: 'Modern',
        createdAt: DateTime.now(),
      ));

      await db.into(db.deckVersions).insert(DeckVersionsCompanion.insert(
        id: 'v-dup-check',
        deckId: 'deck-dup-check',
        versionNumber: 1,
        createdAt: DateTime.now(),
      ));

      await db.into(db.vaultItems).insert(VaultItemsCompanion.insert(
        id: 'item-bolt-a',
        collectionType: 'mtg',
        name: 'Lightning Bolt',
        setOrSeries: 'M10',
        imageUrl: 'https://example.com/m10.jpg',
        acquiredPrice: 2.0,
        acquiredDate: DateTime.now(),
        quantity: const drift.Value(4),
        condition: 'NM',
        currentMarketPrice: 2.00,
        lastPriceUpdate: DateTime.now(),
        dynamicData: '{}',
      ));

      await db.into(db.vaultItems).insert(VaultItemsCompanion.insert(
        id: 'item-bolt-b',
        collectionType: 'mtg',
        name: 'Lightning Bolt',
        setOrSeries: 'M11',
        imageUrl: 'https://example.com/m11.jpg',
        acquiredPrice: 2.0,
        acquiredDate: DateTime.now(),
        quantity: const drift.Value(4),
        condition: 'NM',
        currentMarketPrice: 2.00,
        lastPriceUpdate: DateTime.now(),
        dynamicData: '{}',
      ));

      // Add 1 copy of Bolt A and 1 copy of Bolt B to the same deck
      await db.vaultDao.addCardToDeck('deck-dup-check', 'item-bolt-a', quantity: 1);
      await db.vaultDao.addCardToDeck('deck-dup-check', 'item-bolt-b', quantity: 1);

      // Find DVI for Bolt A
      final dviA = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals('v-dup-check') & t.vaultItemId.equals('item-bolt-a')))
          .getSingle();

      // Swap Bolt A to Bolt B
      await db.vaultDao.swapDeckItemPrinting(dviA.id, 'item-bolt-b');

      // Now verify that subsequent operations like setCardQuantityInDeck or addCardToDeck do not crash
      // If there are duplicate rows for (versionId, vaultItemId, boardZone, isProxy), getSingleOrNull() will crash!
      try {
        await db.vaultDao.setCardQuantityInDeck('deck-dup-check', 'item-bolt-b', 3);
      } catch (e) {
        fail('setCardQuantityInDeck crashed after swapping printing to an already present printing: $e');
      }

      final items = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals('v-dup-check') & t.vaultItemId.equals('item-bolt-b')))
          .get();
      expect(items.length, 1, reason: 'Duplicate rows for same card in same zone must not exist');
      expect(items.first.quantity, 3);
    });
  });

  group('Adversarial Stress Test: Collection Switch Printing (Feature 12)', () {
    test('In-place mutation across diverse treatments preserves ID, quantity, notes, binder and deck history', () async {
      await db.into(db.vaultBinders).insert(VaultBindersCompanion.insert(
        id: 'binder-legacy',
        name: 'Legacy Binder',
        collectionType: 'mtg',
        createdAt: DateTime.now(),
      ));

      final initialDate = DateTime.now().subtract(const Duration(days: 30));
      await db.into(db.vaultItems).insert(VaultItemsCompanion.insert(
        id: 'item-rhystic',
        collectionType: 'mtg',
        name: 'Rhystic Study',
        setOrSeries: 'Prophecy',
        imageUrl: 'https://example.com/pcy.jpg',
        acquiredPrice: 25.0,
        acquiredDate: initialDate,
        quantity: const drift.Value(3),
        primaryBinderId: const drift.Value('binder-legacy'),
        condition: 'NM',
        currentMarketPrice: 30.0,
        lastPriceUpdate: initialDate,
        personalNotes: const drift.Value('Reserved for Commander'),
        dynamicData: '{"deck_history": ["Merfolk Deck"], "custom_tag": "blue_staple"}',
      ));

      // Array of treatments to test in sequence
      final treatments = [
        ('jmp', 'Jumpstart', '101', 'Foil', 45.0),
        ('woe', 'Wilds of Eldraine', '202', 'Etched Foil', 55.0),
        ('cmm', 'Commander Masters', '303', 'Borderless', 70.0),
        ('prtr', 'Retro Sheet', '404', 'Retro Frame', 85.0),
        ('woe', 'Wilds of Eldraine', '202', 'Standard', 35.0),
      ];

      for (final t in treatments) {
        final updated = await db.vaultDao.switchCardPrinting(
          id: 'item-rhystic',
          setCode: t.$1,
          setName: t.$2,
          collectorNumber: t.$3,
          imageUrl: 'https://example.com/${t.$1}-${t.$3}.jpg',
          artCropUrl: 'https://example.com/${t.$1}-${t.$3}-art.jpg',
          marketPrice: t.$5,
          treatment: t.$4,
          extraDynamicData: {'rarity': 'rare', 'artist': 'Test Artist'},
        );

        // Core assertions: ID, quantity, binder, notes, condition MUST NOT mutate
        expect(updated.id, 'item-rhystic', reason: 'VaultItem ID must be invariant');
        expect(updated.quantity, 3, reason: 'Quantity must never mutate during printing switch');
        expect(updated.primaryBinderId, 'binder-legacy', reason: 'Binder placement must be preserved');
        expect(updated.acquiredPrice, 25.0, reason: 'Acquired price must be preserved');
        expect(updated.condition, 'NM', reason: 'Condition must be preserved');
        expect(updated.personalNotes, 'Reserved for Commander', reason: 'Personal notes must be preserved');

        // Verify setOrSeries naming convention
        if (t.$4 != 'Standard') {
          expect(updated.setOrSeries, '${t.$2} (${t.$4})');
        } else {
          expect(updated.setOrSeries, t.$2);
        }

        // Verify dynamicData preserved existing keys while updating printing metadata
        final dyn = jsonDecode(updated.dynamicData) as Map<String, dynamic>;
        expect(dyn['custom_tag'], 'blue_staple', reason: 'Existing custom tags in dynamicData must survive');
        expect(dyn['deck_history'], contains('Merfolk Deck'), reason: 'Existing deck history must survive');
        expect(dyn['set_code'], t.$1);
        expect(dyn['treatment'], t.$4);
        expect(dyn['collector_number'], t.$3);
        expect(dyn['artist'], 'Test Artist');

        // Check persistent SQLite row
        final dbItem = await db.vaultDao.getItemById('item-rhystic');
        expect(dbItem, isNotNull);
        expect(dbItem!.quantity, 3);
        expect(dbItem.id, 'item-rhystic');
      }

      // Check total items count in vault_items table - must remain strictly 1!
      final allItems = await (db.select(db.vaultItems)..where((t) => t.isDeleted.equals(false))).get();
      expect(allItems.length, 1, reason: 'In-place switch must not create duplicate vault items');
    });

    testWidgets('SwitchPrintingModal UI respects and persists treatment changes', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await db.into(db.vaultItems).insert(VaultItemsCompanion.insert(
        id: 'item-demonic',
        collectionType: 'mtg',
        name: 'Demonic Tutor',
        setOrSeries: 'Revised Edition',
        imageUrl: 'https://example.com/revised.jpg',
        acquiredPrice: 35.0,
        acquiredDate: DateTime.now(),
        quantity: const drift.Value(1),
        condition: 'LP',
        currentMarketPrice: 40.0,
        lastPriceUpdate: DateTime.now(),
        dynamicData: '{"collector_number": "105", "set_code": "3ed"}',
      ));

      final testItem = await db.vaultDao.getItemById('item-demonic');
      VaultItem? updatedResult;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vaultDaoProvider.overrideWithValue(db.vaultDao),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => SwitchPrintingModal.show(
                    context,
                    testItem!,
                    onUpdated: (res) => updatedResult = res,
                  ),
                  child: const Text('Open Switch Modal'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Switch Modal'));
      await tester.pumpAndSettle();

      expect(find.text('Switch Printing / Edition'), findsOneWidget);
      expect(find.text('Demonic Tutor'), findsOneWidget);

      // Select 'Etched Foil' treatment
      await tester.tap(find.text('Etched Foil'));
      await tester.pumpAndSettle();

      // Submit
      final applyBtn = find.byKey(const Key('apply_switch_printing_button'));
      await tester.tap(applyBtn);
      await tester.pumpAndSettle();

      expect(updatedResult, isNotNull);
      final dyn = jsonDecode(updatedResult!.dynamicData) as Map<String, dynamic>;
      expect(dyn['treatment'], 'Etched Foil');
      expect(updatedResult!.id, 'item-demonic');
    });
  });

  group('Adversarial Stress Test: dynamicData[deck_history] Lifecycle & Integrity', () {
    test('Deck history remains strictly synchronized through multi-deck lifecycle', () async {
      // 1. Create 3 decks
      final deckNames = ['Dimir Rogues', 'Grixis Control', 'Mono Black'];
      for (int i = 0; i < deckNames.length; i++) {
        await db.into(db.decks).insert(DecksCompanion.insert(
          id: 'deck-hist-$i',
          name: deckNames[i],
          format: 'Modern',
          isAssembled: const drift.Value(true),
          createdAt: DateTime.now(),
        ));
      }

      // 2. Insert item with empty dynamicData
      await db.into(db.vaultItems).insert(VaultItemsCompanion.insert(
        id: 'item-thoughtseize',
        collectionType: 'mtg',
        name: 'Thoughtseize',
        setOrSeries: 'Theros',
        imageUrl: 'https://example.com/ts.jpg',
        acquiredPrice: 15.0,
        acquiredDate: DateTime.now(),
        quantity: const drift.Value(4),
        condition: 'NM',
        currentMarketPrice: 20.0,
        lastPriceUpdate: DateTime.now(),
        dynamicData: '{}',
      ));

      // Helper to inspect deck_history
      Future<List<String>> getHistory() async {
        final it = await db.vaultDao.getItemById('item-thoughtseize');
        if (it == null || it.dynamicData.isEmpty) return [];
        final data = jsonDecode(it.dynamicData) as Map<String, dynamic>;
        return (data['deck_history'] as List?)?.cast<String>() ?? [];
      }

      // Step 1: Add to Dimir Rogues
      await db.vaultDao.setCardQuantityInDeck('deck-hist-0', 'item-thoughtseize', 1);
      expect(await getHistory(), ['Dimir Rogues']);

      // Step 2: Add to Grixis Control
      await db.vaultDao.setCardQuantityInDeck('deck-hist-1', 'item-thoughtseize', 2);
      var hist = await getHistory();
      expect(hist.contains('Dimir Rogues'), isTrue);
      expect(hist.contains('Grixis Control'), isTrue);
      expect(hist.length, 2);

      // Step 3: Increment quantity in Dimir Rogues (1 -> 3) - MUST NOT duplicate history entry
      await db.vaultDao.setCardQuantityInDeck('deck-hist-0', 'item-thoughtseize', 3);
      hist = await getHistory();
      expect(hist.where((d) => d == 'Dimir Rogues').length, 1, reason: 'Duplicate deck names must be deduplicated');
      expect(hist.length, 2);

      // Step 4: Add to Mono Black
      await db.vaultDao.setCardQuantityInDeck('deck-hist-2', 'item-thoughtseize', 1);
      hist = await getHistory();
      expect(hist.length, 3);
      expect(hist.toSet(), deckNames.toSet());

      // Step 5: Decrement Grixis Control to 0 (removal)
      await db.vaultDao.removeCardFromDeck('deck-hist-1', 'item-thoughtseize', quantity: 2);
      hist = await getHistory();
      expect(hist.contains('Grixis Control'), isFalse);
      expect(hist.contains('Dimir Rogues'), isTrue);
      expect(hist.contains('Mono Black'), isTrue);
      expect(hist.length, 2);

      // Step 6: In-place switch printing of Thoughtseize
      await db.vaultDao.switchCardPrinting(
        id: 'item-thoughtseize',
        setCode: '2xm',
        setName: 'Double Masters',
        collectorNumber: '102',
        imageUrl: 'https://example.com/2xm-ts.jpg',
        marketPrice: 22.0,
        treatment: 'Foil',
      );
      hist = await getHistory();
      expect(hist.length, 2, reason: 'Switch printing must not wipe deck history');
      expect(hist.contains('Dimir Rogues'), isTrue);
      expect(hist.contains('Mono Black'), isTrue);

      // Step 7: Remove from remaining decks
      await db.vaultDao.removeCardFromDeck('deck-hist-0', 'item-thoughtseize', quantity: 3);
      await db.vaultDao.removeCardFromDeck('deck-hist-2', 'item-thoughtseize', quantity: 1);
      hist = await getHistory();
      expect(hist.isEmpty, isTrue, reason: 'When removed from all decks, deck_history must be empty');
    });
  });
}
