import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.vaultDao.clearAllItems();

    // Insert test owned items
    await db.vaultDao.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'owned-1',
            collectionType: 'mtg',
            name: 'Sol Ring',
            setOrSeries: 'Commander 2021',
            imageUrl: 'https://example.com/solring.jpg',
            acquiredPrice: 2.50,
            acquiredDate: DateTime(2023, 1, 1),
            quantity: const drift.Value(2),
            condition: 'NM',
            isGraded: const drift.Value(false),
            currentMarketPrice: 3.50,
            lastPriceUpdate: DateTime.now(),
            dynamicData: '{"oracle_text":"Add {C}{C}.","rarity":"uncommon"}',
          ),
        );

    await db.vaultDao.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'owned-2',
            collectionType: 'mtg',
            name: 'Black Lotus',
            setOrSeries: 'Vintage Masters',
            imageUrl: 'https://example.com/lotus.jpg',
            acquiredPrice: 5000.0,
            acquiredDate: DateTime(2023, 2, 1),
            quantity: const drift.Value(1),
            condition: 'LP',
            isGraded: const drift.Value(true),
            currentMarketPrice: 7500.0,
            lastPriceUpdate: DateTime.now(),
            dynamicData: '{"oracle_text":"Sacrifice Black Lotus: Add three mana of any one color."}',
          ),
        );

    // Insert test catalog unowned items (quantity = 0)
    await db.vaultDao.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'catalog-1',
            collectionType: 'mtg',
            name: 'Mox Diamond',
            setOrSeries: 'Stronghold',
            imageUrl: 'https://example.com/mox.jpg',
            acquiredPrice: 0.0,
            acquiredDate: DateTime(2023, 3, 1),
            quantity: const drift.Value(0),
            condition: 'NM',
            isGraded: const drift.Value(false),
            currentMarketPrice: 650.0,
            lastPriceUpdate: DateTime.now(),
            dynamicData: '{"oracle_text":"Discard a land card: Add one mana of any color."}',
          ),
        );

    await db.vaultDao.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'catalog-2',
            collectionType: 'mtg',
            name: 'Mox Opal',
            setOrSeries: 'Scars of Mirrodin',
            imageUrl: 'https://example.com/opal.jpg',
            acquiredPrice: 0.0,
            acquiredDate: DateTime(2023, 3, 1),
            quantity: const drift.Value(0),
            condition: 'NM',
            isGraded: const drift.Value(false),
            currentMarketPrice: 95.0,
            lastPriceUpdate: DateTime.now(),
            dynamicData: '{"oracle_text":"Metalcraft — {T}: Add one mana of any color."}',
          ),
        );

    await db.vaultDao.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'catalog-3',
            collectionType: 'mtg',
            name: 'Sol Talisman',
            setOrSeries: 'Modern Horizons 2',
            imageUrl: 'https://example.com/soltalisman.jpg',
            acquiredPrice: 0.0,
            acquiredDate: DateTime(2023, 3, 1),
            quantity: const drift.Value(0),
            condition: 'NM',
            isGraded: const drift.Value(false),
            currentMarketPrice: 1.50,
            lastPriceUpdate: DateTime.now(),
            dynamicData: '{"oracle_text":"Suspend 3 — {0}. {T}: Add {C}{C}."}',
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  group('VaultDao SQLite Search & Pagination', () {
    test('searchQuery filters items across name with SQL LIKE %query%', () async {
      final results = await db.vaultDao.getItemsByCollection(
        'mtg',
        onlyOwned: false,
        searchQuery: 'Mox',
      );

      expect(results.length, equals(2));
      final names = results.map((r) => r.name).toList();
      expect(names, containsAll(['Mox Diamond', 'Mox Opal']));
      expect(names, isNot(contains('Sol Ring')));
    });

    test('searchQuery filters items across setOrSeries', () async {
      final results = await db.vaultDao.getItemsByCollection(
        'mtg',
        onlyOwned: false,
        searchQuery: 'Mirrodin',
      );

      expect(results.length, equals(1));
      expect(results.first.name, equals('Mox Opal'));
    });

    test('searchQuery combined with onlyOwned filters exclusively owned inventory', () async {
      final results = await db.vaultDao.getItemsByCollection(
        'mtg',
        onlyOwned: true,
        searchQuery: 'Sol',
      );

      // Only 'Sol Ring' is owned (quantity: 2); 'Sol Talisman' has quantity: 0
      expect(results.length, equals(1));
      expect(results.first.name, equals('Sol Ring'));
    });

    test('pagination limit and offset constrain returned items', () async {
      final page1 = await db.vaultDao.getItemsByCollection(
        'mtg',
        onlyOwned: false,
        limit: 2,
        offset: 0,
      );
      expect(page1.length, equals(2));

      final page2 = await db.vaultDao.getItemsByCollection(
        'mtg',
        onlyOwned: false,
        limit: 2,
        offset: 2,
      );
      expect(page2.length, equals(2));

      // Disjoint pages
      final ids1 = page1.map((e) => e.id).toSet();
      final ids2 = page2.map((e) => e.id).toSet();
      expect(ids1.intersection(ids2), isEmpty);
    });

    test('updateItemNotesAndDecks updates personal notes and deck history while preserving dynamicData', () async {
      final updatedRows = await db.vaultDao.updateItemNotesAndDecks(
        'owned-1',
        personalNotes: 'Gift from my tournament partner.',
        deckTags: ['Commander: Urza', 'Legacy Workshop'],
        communityNotes: 'Essential rock in every EDH deck.',
      );

      expect(updatedRows, equals(1));

      final item = await (db.select(db.vaultItems)..where((t) => t.id.equals('owned-1'))).getSingle();
      expect(item.personalNotes, equals('Gift from my tournament partner.'));

      final json = jsonDecode(item.dynamicData) as Map<String, dynamic>;
      // Preserved original fields
      expect(json['oracle_text'], equals('Add {C}{C}.'));
      expect(json['rarity'], equals('uncommon'));
      // Added new fields
      expect(json['deck_history'], equals(['Commander: Urza', 'Legacy Workshop']));
      expect(json['use_cases'], equals('Essential rock in every EDH deck.'));
    });

    test('searchQuery matches cards by flavorName case-insensitively in getItemsByCollection and watchItemsByCollection', () async {
      await db.vaultDao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'card-flavor-ozolith',
              collectionType: 'mtg',
              name: 'The Ozolith',
              flavorName: const drift.Value('Adamantium Bonding Tank'),
              setOrSeries: 'Secret Lair Drop',
              imageUrl: 'https://example.com/ozolith.jpg',
              acquiredPrice: 0.0,
              acquiredDate: DateTime(2023, 4, 1),
              quantity: const drift.Value(0),
              condition: 'NM',
              isGraded: const drift.Value(false),
              currentMarketPrice: 42.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: '{"flavor_name":"Adamantium Bonding Tank"}',
            ),
          );

      // Search by lowercase substring of flavorName
      final results1 = await db.vaultDao.getItemsByCollection(
        'mtg',
        onlyOwned: false,
        searchQuery: 'adamantium',
      );
      expect(results1.length, equals(1));
      expect(results1.first.name, equals('The Ozolith'));
      expect(results1.first.flavorName, equals('Adamantium Bonding Tank'));

      // Search by uppercase substring of flavorName
      final results2 = await db.vaultDao.getItemsByCollection(
        'mtg',
        onlyOwned: false,
        searchQuery: 'BONDING',
      );
      expect(results2.length, equals(1));
      expect(results2.first.name, equals('The Ozolith'));

      // Search by oracle name also finds it
      final results3 = await db.vaultDao.getItemsByCollection(
        'mtg',
        onlyOwned: false,
        searchQuery: 'Ozolith',
      );
      expect(results3.length, equals(1));
      expect(results3.first.name, equals('The Ozolith'));

      // Reactive stream query
      final streamResult = await db.vaultDao.watchItemsByCollection(
        'mtg',
        onlyOwned: false,
        searchQuery: 'Tank',
      ).first;
      expect(streamResult.length, equals(1));
      expect(streamResult.first.name, equals('The Ozolith'));
    });

    test('searchCatalogCards matches cards by flavorName', () async {
      await db.vaultDao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'catalog-flavor-1',
              collectionType: 'mtg',
              name: 'Lurrus of the Dream-Den',
              flavorName: const drift.Value('Mothra, Supersonic Queen'),
              setOrSeries: 'Ikoria: Lair of Behemoths',
              imageUrl: 'https://example.com/lurrus.jpg',
              acquiredPrice: 0.0,
              acquiredDate: DateTime(2023, 4, 1),
              quantity: const drift.Value(0),
              condition: 'NM',
              isGraded: const drift.Value(false),
              currentMarketPrice: 15.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: '{}',
            ),
          );

      final searchResults = await db.vaultDao.searchCatalogCards('Mothra', collectionType: 'mtg');
      expect(searchResults.length, equals(1));
      expect(searchResults.first.name, equals('Lurrus of the Dream-Den'));
      expect(searchResults.first.flavorName, equals('Mothra, Supersonic Queen'));
    });

    test('insertDictionaryBatch updates flavorName on ID conflict', () async {
      final initialItem = VaultItemsCompanion.insert(
        id: 'upsert-item-1',
        collectionType: 'mtg',
        name: 'The Ozolith',
        setOrSeries: 'Ikoria',
        imageUrl: 'https://example.com/oz1.jpg',
        acquiredPrice: 0.0,
        acquiredDate: DateTime(2023, 1, 1),
        quantity: const drift.Value(0),
        condition: 'NM',
        currentMarketPrice: 20.0,
        lastPriceUpdate: DateTime(2023, 1, 1),
        dynamicData: '{}',
      );
      await db.vaultDao.insertDictionaryBatch([initialItem]);

      var item = await (db.select(db.vaultItems)..where((t) => t.id.equals('upsert-item-1'))).getSingle();
      expect(item.flavorName, isNull);

      final updatedCatalogItem = VaultItemsCompanion.insert(
        id: 'upsert-item-1',
        collectionType: 'mtg',
        name: 'The Ozolith',
        flavorName: const drift.Value('Adamantium Bonding Tank'),
        setOrSeries: 'Secret Lair',
        imageUrl: 'https://example.com/oz2.jpg',
        acquiredPrice: 0.0,
        acquiredDate: DateTime(2023, 2, 1),
        quantity: const drift.Value(0),
        condition: 'NM',
        currentMarketPrice: 45.0,
        lastPriceUpdate: DateTime(2023, 2, 1),
        dynamicData: '{"flavor_name":"Adamantium Bonding Tank"}',
      );
      await db.vaultDao.insertDictionaryBatch([updatedCatalogItem]);

      item = await (db.select(db.vaultItems)..where((t) => t.id.equals('upsert-item-1'))).getSingle();
      expect(item.flavorName, equals('Adamantium Bonding Tank'));
      expect(item.currentMarketPrice, equals(45.0));
      expect(item.setOrSeries, equals('Secret Lair'));
    });
  });

  group('Riverpod Catalog Search Provider Integration', () {
    test('vaultItemsStreamProvider passes searchQuery and paginationLimit in catalog mode', () async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
          vaultShowCatalogProvider.overrideWith((ref) => true),
          vaultSearchQueryProvider.overrideWith((ref) => 'Mox'),
          vaultPaginationLimitProvider.overrideWith((ref) => 50),
        ],
      );

      final items = await container.read(vaultItemsStreamProvider.future);
      expect(items.length, equals(2));
      expect(items.map((i) => i.name), containsAll(['Mox Diamond', 'Mox Opal']));

      container.dispose();
    });
  });
}
