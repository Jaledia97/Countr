import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/hydration/domain/isolate/scryfall_parser.dart';

void main() {
  group('Adversarial Parser Edge Cases Verification', () {
    test('Edge Case 1: Cards with NO card_faces', () {
      final cardNoFaces = {
        'id': 'card-single-face',
        'name': 'Lightning Bolt',
        'set_name': 'Masters 25',
        'oracle_text': 'Lightning Bolt deals 3 damage to any target.',
        'image_uris': {
          'normal': 'https://cards.scryfall.io/bolt.jpg',
        },
        'prices': {'usd': '3.00'},
      };

      final companion = mapScryfallCardToCompanion(cardNoFaces);
      expect(companion.name.value, 'Lightning Bolt');
      expect(companion.imageUrl.value, 'https://cards.scryfall.io/bolt.jpg');
      expect(companion.flavorName.present, isFalse);

      final dynamicData = jsonDecode(companion.dynamicData.value) as Map<String, dynamic>;
      expect(dynamicData['oracle_text'], 'Lightning Bolt deals 3 damage to any target.');
      expect(dynamicData.containsKey('card_faces'), isFalse);
      expect(dynamicData['back_image_url'], isNull);
      expect(dynamicData['flavor_name'], '');
    });

    test('Edge Case 2: Cards with empty oracle text on one face or both faces', () {
      // Subcase A: Face 0 has oracle text, Face 1 has empty string
      final cardEmptyBack = {
        'id': 'dfc-empty-back',
        'name': 'Front // Back',
        'set_name': 'ZNR',
        'card_faces': [
          {
            'name': 'Front',
            'oracle_text': 'Flying\nWhen this enters, draw a card.',
            'image_uris': {'normal': 'https://example.com/front.jpg'},
          },
          {
            'name': 'Back',
            'oracle_text': '',
            'image_uris': {'normal': 'https://example.com/back.jpg'},
          },
        ],
        'prices': {'usd': '1.00'},
      };

      final compA = mapScryfallCardToCompanion(cardEmptyBack);
      final dynA = jsonDecode(compA.dynamicData.value) as Map<String, dynamic>;
      expect(dynA['oracle_text'], 'Flying\nWhen this enters, draw a card.');
      expect(dynA['back_image_url'], 'https://example.com/back.jpg');

      // Subcase B: Face 0 has whitespace only, Face 1 has oracle text
      final cardEmptyFront = {
        'id': 'dfc-empty-front',
        'name': 'Front // Back',
        'set_name': 'ZNR',
        'card_faces': [
          {
            'name': 'Front',
            'oracle_text': '   \n  ',
            'image_uris': {'normal': 'https://example.com/front.jpg'},
          },
          {
            'name': 'Back',
            'oracle_text': 'Vigilance, trample',
            'image_uris': {'normal': 'https://example.com/back.jpg'},
          },
        ],
        'prices': {'usd': '2.00'},
      };

      final compB = mapScryfallCardToCompanion(cardEmptyFront);
      final dynB = jsonDecode(compB.dynamicData.value) as Map<String, dynamic>;
      expect(dynB['oracle_text'], 'Vigilance, trample');

      // Subcase C: Both faces have empty or whitespace oracle text
      final cardBothEmpty = {
        'id': 'dfc-both-empty',
        'name': 'Front Vanilla // Back Vanilla',
        'set_name': 'ZNR',
        'card_faces': [
          {
            'name': 'Front Vanilla',
            'oracle_text': '',
            'image_uris': {'normal': 'https://example.com/front.jpg'},
          },
          {
            'name': 'Back Vanilla',
            'oracle_text': '  ',
            'image_uris': {'normal': 'https://example.com/back.jpg'},
          },
        ],
        'prices': {'usd': '0.25'},
      };

      final compC = mapScryfallCardToCompanion(cardBothEmpty);
      final dynC = jsonDecode(compC.dynamicData.value) as Map<String, dynamic>;
      expect(dynC['oracle_text'], '');
    });

    test('Edge Case 3: flavor_name precedence (top-level vs in card_faces)', () {
      // Subcase A: Top-level flavor_name present AND card_faces also have flavor_name
      // Top-level must take precedence
      final cardWithBothFlavors = {
        'id': 'top-vs-faces',
        'name': 'Top Name',
        'flavor_name': 'Top Level Flavor Name',
        'card_faces': [
          {
            'name': 'Face 1',
            'flavor_name': 'Face 1 Flavor',
            'oracle_text': 'Text 1',
            'image_uris': {'normal': 'https://example.com/f1.jpg'},
          },
          {
            'name': 'Face 2',
            'flavor_name': 'Face 2 Flavor',
            'oracle_text': 'Text 2',
            'image_uris': {'normal': 'https://example.com/f2.jpg'},
          },
        ],
      };

      final compA = mapScryfallCardToCompanion(cardWithBothFlavors);
      expect(compA.flavorName.value, 'Top Level Flavor Name');
      final dynA = jsonDecode(compA.dynamicData.value) as Map<String, dynamic>;
      expect(dynA['flavor_name'], 'Top Level Flavor Name');

      // Subcase B: Top-level flavor_name is whitespace or empty, faces have flavor_name
      final cardEmptyTopFlavor = {
        'id': 'empty-top-vs-faces',
        'name': 'Top Name',
        'flavor_name': '   ',
        'card_faces': [
          {
            'name': 'Face 1',
            'flavor_name': 'Godzilla, King of the Monsters',
            'oracle_text': 'Text 1',
            'image_uris': {'normal': 'https://example.com/f1.jpg'},
          },
          {
            'name': 'Face 2',
            'flavor_name': '   ',
            'oracle_text': 'Text 2',
            'image_uris': {'normal': 'https://example.com/f2.jpg'},
          },
        ],
      };

      final compB = mapScryfallCardToCompanion(cardEmptyTopFlavor);
      expect(compB.flavorName.value, 'Godzilla, King of the Monsters');
      final dynB = jsonDecode(compB.dynamicData.value) as Map<String, dynamic>;
      expect(dynB['flavor_name'], 'Godzilla, King of the Monsters');

      // Subcase C: No flavor_name anywhere
      final cardNoFlavor = {
        'id': 'no-flavor-anywhere',
        'name': 'Regular Card',
        'card_faces': [
          {
            'name': 'Face 1',
            'oracle_text': 'Text 1',
            'image_uris': {'normal': 'https://example.com/f1.jpg'},
          },
        ],
      };

      final compC = mapScryfallCardToCompanion(cardNoFlavor);
      expect(compC.flavorName.present, isFalse);
      final dynC = jsonDecode(compC.dynamicData.value) as Map<String, dynamic>;
      expect(dynC['flavor_name'], '');
    });
  });

  group('SQLite Migration & Collation / Case-Insensitivity Verification', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('Case-insensitivity across searchCatalogCards, getItemsByCollection, and watchItemsByCollection', () async {
      // Insert cards with various casings in name and flavorName
      await db.vaultDao.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-case-1',
          collectionType: 'mtg',
          name: 'The Ozolith',
          flavorName: const drift.Value('Adamantium Bonding Tank'),
          setOrSeries: 'Secret Lair Drop',
          imageUrl: 'https://example.com/ozolith.jpg',
          acquiredPrice: 20.0,
          acquiredDate: DateTime(2023, 1, 1),
          quantity: const drift.Value(1),
          condition: 'NM',
          currentMarketPrice: 40.0,
          lastPriceUpdate: DateTime.now(),
          dynamicData: '{}',
        ),
      );

      await db.vaultDao.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-case-2',
          collectionType: 'mtg',
          name: 'Zilortha, Strength Incarnate',
          flavorName: const drift.Value('GODZILLA, KING OF THE MONSTERS'),
          setOrSeries: 'Ikoria: Lair of Behemoths',
          imageUrl: 'https://example.com/zilortha.jpg',
          acquiredPrice: 10.0,
          acquiredDate: DateTime(2023, 2, 1),
          quantity: const drift.Value(0), // catalog
          condition: 'NM',
          currentMarketPrice: 15.0,
          lastPriceUpdate: DateTime.now(),
          dynamicData: '{}',
        ),
      );

      // 1. searchCatalogCards: lowercase against UPPERCASE DB value
      final catResults1 = await db.vaultDao.searchCatalogCards('godzilla');
      expect(catResults1.length, 1);
      expect(catResults1.first.name, 'Zilortha, Strength Incarnate');

      // 2. searchCatalogCards: UPPERCASE against Mixed Case DB value
      final catResults2 = await db.vaultDao.searchCatalogCards('ADAMANTIUM');
      expect(catResults2.length, 1);
      expect(catResults2.first.name, 'The Ozolith');

      // 3. searchCatalogCards: partial match in middle of flavorName
      final catResults3 = await db.vaultDao.searchCatalogCards('bonding');
      expect(catResults3.length, 1);
      expect(catResults3.first.name, 'The Ozolith');

      // 4. getItemsByCollection (onlyOwned = true): finds owned card by lower/upper flavorName
      final ownedResults1 = await db.vaultDao.getItemsByCollection('mtg', onlyOwned: true, searchQuery: 'tank');
      expect(ownedResults1.length, 1);
      expect(ownedResults1.first.name, 'The Ozolith');

      // 5. getItemsByCollection (onlyOwned = true): does not return unowned card even if flavor matches
      final ownedResults2 = await db.vaultDao.getItemsByCollection('mtg', onlyOwned: true, searchQuery: 'godzilla');
      expect(ownedResults2.isEmpty, isTrue);

      // 6. getItemsByCollection (onlyOwned = false): returns unowned card matching flavor
      final allResults = await db.vaultDao.getItemsByCollection('mtg', onlyOwned: false, searchQuery: 'godzilla');
      expect(allResults.length, 1);
      expect(allResults.first.name, 'Zilortha, Strength Incarnate');

      // 7. watchItemsByCollection stream
      final streamResult = await db.vaultDao.watchItemsByCollection('mtg', onlyOwned: false, searchQuery: 'KING').first;
      expect(streamResult.length, 1);
      expect(streamResult.first.name, 'Zilortha, Strength Incarnate');
    });

    test('Migration idempotence: calling beforeOpen repeatedly does not throw', () async {
      // Opening database executes beforeOpen
      final testDb = AppDatabase(NativeDatabase.memory());
      final count1 = await (testDb.select(testDb.vaultItems)).get();
      expect(count1, isNotEmpty); // Seeded

      // Trigger custom PRAGMA or index statements again to verify IF NOT EXISTS safety
      await testDb.customStatement('''
        CREATE INDEX IF NOT EXISTS "idx_vault_items_flavor_name"
        ON "vault_items" ("flavor_name" COLLATE NOCASE);
      ''');

      await testDb.close();
    });
  });
}
