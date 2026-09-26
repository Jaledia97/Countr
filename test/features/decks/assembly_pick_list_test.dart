import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';

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

  group('Deck Assembly Pick-List & Deficit/Proxy Fallback Unit Tests', () {
    test('Calculates deck assembly pick-list with location grouping and deficit detection', () async {
      // 1. Create Binders
      await db.into(db.vaultBinders).insert(VaultBindersCompanion.insert(
        id: 'binder-a',
        name: 'Rare Binder Alpha',
        collectionType: 'mtg',
        createdAt: DateTime.now(),
      ));
      await db.into(db.vaultBinders).insert(VaultBindersCompanion.insert(
        id: 'box-bulk',
        name: 'Commander Bulk Box',
        collectionType: 'mtg',
        createdAt: DateTime.now(),
      ));

      // 2. Create Vault Items:
      // Item 1: Sol Ring (2 in vault, Binder A)
      await db.into(db.vaultItems).insert(VaultItemsCompanion.insert(
        id: 'item-sol-ring',
        collectionType: 'mtg',
        name: 'Sol Ring',
        setOrSeries: 'Commander 2021',
        imageUrl: 'https://example.com/solring.jpg',
        acquiredPrice: 2.0,
        acquiredDate: DateTime.now(),
        quantity: const drift.Value(2),
        primaryBinderId: const drift.Value('binder-a'),
        condition: 'NM',
        currentMarketPrice: 2.50,
        lastPriceUpdate: DateTime.now(),
        dynamicData: '{}',
      ));

      // Item 2: Demonic Tutor (1 in vault, Binder A)
      await db.into(db.vaultItems).insert(VaultItemsCompanion.insert(
        id: 'item-demonic-tutor',
        collectionType: 'mtg',
        name: 'Demonic Tutor',
        setOrSeries: 'Mystery Booster',
        imageUrl: 'https://example.com/tutor.jpg',
        acquiredPrice: 35.0,
        acquiredDate: DateTime.now(),
        quantity: const drift.Value(1),
        primaryBinderId: const drift.Value('binder-a'),
        condition: 'NM',
        currentMarketPrice: 40.0,
        lastPriceUpdate: DateTime.now(),
        dynamicData: '{}',
      ));

      // Item 3: Command Tower (1 in vault, Bulk Box)
      await db.into(db.vaultItems).insert(VaultItemsCompanion.insert(
        id: 'item-command-tower',
        collectionType: 'mtg',
        name: 'Command Tower',
        setOrSeries: 'Commander Legends',
        imageUrl: 'https://example.com/tower.jpg',
        acquiredPrice: 0.50,
        acquiredDate: DateTime.now(),
        quantity: const drift.Value(1),
        primaryBinderId: const drift.Value('box-bulk'),
        condition: 'LP',
        currentMarketPrice: 0.75,
        lastPriceUpdate: DateTime.now(),
        dynamicData: '{}',
      ));

      // Item 4: Mana Crypt (0 in vault, Unassigned / Deficit)
      await db.into(db.vaultItems).insert(VaultItemsCompanion.insert(
        id: 'item-mana-crypt',
        collectionType: 'mtg',
        name: 'Mana Crypt',
        setOrSeries: 'Double Masters',
        imageUrl: 'https://example.com/crypt.jpg',
        acquiredPrice: 0.0,
        acquiredDate: DateTime.now(),
        quantity: const drift.Value(0),
        condition: 'NM',
        currentMarketPrice: 180.0,
        lastPriceUpdate: DateTime.now(),
        dynamicData: '{}',
      ));

      // 3. Create Draft Deck
      const deckId = 'test-deck-assembly';
      await db.into(db.decks).insert(DecksCompanion.insert(
        id: deckId,
        name: 'Urza High Power Assembly',
        format: 'Commander',
        tcgDomain: const drift.Value('mtg'),
        isRegistered: const drift.Value(false),
        createdAt: DateTime.now(),
      ));

      // Create Active Version
      const versionId = 'ver-assembly-1';
      await db.into(db.deckVersions).insert(DeckVersionsCompanion.insert(
        id: versionId,
        deckId: deckId,
        versionNumber: 1,
        isActive: const drift.Value(true),
        createdAt: DateTime.now(),
      ));

      // Assign deck items:
      // Sol Ring: 1 copy, Mainboard
      await db.into(db.deckVersionItems).insert(DeckVersionItemsCompanion.insert(
        id: 'dvi-1',
        versionId: versionId,
        vaultItemId: 'item-sol-ring',
        quantity: const drift.Value(1),
        boardZone: 'Mainboard',
      ));
      // Demonic Tutor: 1 copy, Mainboard
      await db.into(db.deckVersionItems).insert(DeckVersionItemsCompanion.insert(
        id: 'dvi-2',
        versionId: versionId,
        vaultItemId: 'item-demonic-tutor',
        quantity: const drift.Value(1),
        boardZone: 'Mainboard',
      ));
      // Command Tower: 1 copy, Mainboard
      await db.into(db.deckVersionItems).insert(DeckVersionItemsCompanion.insert(
        id: 'dvi-3',
        versionId: versionId,
        vaultItemId: 'item-command-tower',
        quantity: const drift.Value(1),
        boardZone: 'Mainboard',
      ));
      // Mana Crypt: 1 copy, Mainboard (Deficit since vault quantity is 0)
      await db.into(db.deckVersionItems).insert(DeckVersionItemsCompanion.insert(
        id: 'dvi-4',
        versionId: versionId,
        vaultItemId: 'item-mana-crypt',
        quantity: const drift.Value(1),
        boardZone: 'Mainboard',
      ));
      // Sol Ring: 1 copy in Maybeboard (Wishlist - should NOT be included in pick plan)
      await db.into(db.deckVersionItems).insert(DeckVersionItemsCompanion.insert(
        id: 'dvi-5',
        versionId: versionId,
        vaultItemId: 'item-sol-ring',
        quantity: const drift.Value(1),
        boardZone: 'Maybeboard',
      ));

      // 4. Calculate Deck Assembly Plan
      final plan = await db.vaultDao.getDeckAssemblyPlan(deckId);

      // Total required = 1 Sol Ring + 1 Demonic Tutor + 1 Command Tower + 1 Mana Crypt = 4 (Maybeboard excluded)
      expect(plan.totalRequired, equals(4));
      // Available = 2 Sol Ring (capped at required 1) + 1 Demonic Tutor + 1 Command Tower + 0 Mana Crypt = 3
      expect(plan.totalAvailable, equals(3));
      // Deficit = 1 (Mana Crypt)
      expect(plan.totalDeficit, equals(1));
      expect(plan.hasDeficit, isTrue);

      // Verify location grouping
      final locations = plan.itemsByLocation;
      expect(locations.containsKey('Rare Binder Alpha'), isTrue);
      expect(locations['Rare Binder Alpha']!.length, equals(2)); // Sol Ring & Demonic Tutor

      expect(locations.containsKey('Commander Bulk Box'), isTrue);
      expect(locations['Commander Bulk Box']!.length, equals(1)); // Command Tower

      expect(plan.deficitItems.length, equals(1));
      expect(plan.deficitItems.first.cardName, equals('Mana Crypt'));
      expect(plan.deficitItems.first.deficitQuantity, equals(1));
    });

    test('registerDeckWithProxyResolution splits deficit cards into proxy rows and locks inventory', () async {
      // 1. Setup Deck with 1 available and 1 deficit item
      await db.into(db.vaultItems).insert(VaultItemsCompanion.insert(
        id: 'item-force-of-will',
        collectionType: 'mtg',
        name: 'Force of Will',
        setOrSeries: 'Alliances',
        imageUrl: '',
        acquiredPrice: 60.0,
        acquiredDate: DateTime.now(),
        quantity: const drift.Value(1),
        condition: 'MP',
        currentMarketPrice: 70.0,
        lastPriceUpdate: DateTime.now(),
        dynamicData: '{}',
      ));

      await db.into(db.vaultItems).insert(VaultItemsCompanion.insert(
        id: 'item-timetwister',
        collectionType: 'mtg',
        name: 'Timetwister',
        setOrSeries: 'Unlimited',
        imageUrl: '',
        acquiredPrice: 0.0,
        acquiredDate: DateTime.now(),
        quantity: const drift.Value(0), // 0 in inventory
        condition: 'NM',
        currentMarketPrice: 5000.0,
        lastPriceUpdate: DateTime.now(),
        dynamicData: '{}',
      ));

      const deckId = 'deck-cedh-timetwister';
      await db.into(db.decks).insert(DecksCompanion.insert(
        id: deckId,
        name: 'cEDH Timetwister Loop',
        format: 'Commander',
        tcgDomain: const drift.Value('mtg'),
        isRegistered: const drift.Value(false),
        createdAt: DateTime.now(),
      ));

      const versionId = 'ver-twister-1';
      await db.into(db.deckVersions).insert(DeckVersionsCompanion.insert(
        id: versionId,
        deckId: deckId,
        versionNumber: 1,
        isActive: const drift.Value(true),
        createdAt: DateTime.now(),
      ));

      await db.into(db.deckVersionItems).insert(DeckVersionItemsCompanion.insert(
        id: 'dvi-force',
        versionId: versionId,
        vaultItemId: 'item-force-of-will',
        quantity: const drift.Value(1),
        boardZone: 'Mainboard',
      ));

      await db.into(db.deckVersionItems).insert(DeckVersionItemsCompanion.insert(
        id: 'dvi-twist',
        versionId: versionId,
        vaultItemId: 'item-timetwister',
        quantity: const drift.Value(1),
        boardZone: 'Mainboard',
      ));

      // Prior to registration: Force of Will is not locked because deck is draft
      final availableBefore = await db.vaultDao.getAvailableQuantity('item-force-of-will');
      expect(availableBefore, equals(1));

      // Compute plan
      final plan = await db.vaultDao.getDeckAssemblyPlan(deckId);
      expect(plan.hasDeficit, isTrue);
      expect(plan.totalDeficit, equals(1)); // Timetwister

      // Execute registration with proxy resolution
      await db.vaultDao.registerDeckWithProxyResolution(
        deckId: deckId,
        items: plan.items,
      );

      // Verify Deck status is now Registered
      final updatedDeck = await (db.select(db.decks)..where((t) => t.id.equals(deckId))).getSingleOrNull();
      expect(updatedDeck, isNotNull);
      expect(updatedDeck!.isRegistered, isTrue);

      // Verify physical Force of Will is locked: availableQuantity drops to 0
      final availableAfter = await db.vaultDao.getAvailableQuantity('item-force-of-will');
      expect(availableAfter, equals(0));

      // Verify Timetwister is flagged as proxy in DeckVersionItems
      final twisterDvi = await (db.select(db.deckVersionItems)
        ..where((t) => t.versionId.equals(versionId) & t.vaultItemId.equals('item-timetwister')))
        .getSingle();
      expect(twisterDvi.isProxy, isTrue);

      // 4. Test Unregistering Deck: sets isRegistered to false, releasing physical lock
      await (db.update(db.decks)..where((t) => t.id.equals(deckId))).write(
        const DecksCompanion(
          isRegistered: drift.Value(false),
          isAssembled: drift.Value(false),
        ),
      );
      final unlockedForce = await db.vaultDao.getAvailableQuantity('item-force-of-will');
      expect(unlockedForce, equals(1));
    });
  });
}
