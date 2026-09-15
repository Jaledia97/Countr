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
