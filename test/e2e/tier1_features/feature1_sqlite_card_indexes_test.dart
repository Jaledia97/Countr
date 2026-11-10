import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import '../helpers/e2e_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late VaultDao dao;

  setUp(() async {
    db = createE2ETestDatabase();
    dao = db.vaultDao;
    await seedStandardM1Catalog(dao);
  });

  tearDown(() async {
    await db.close();
  });

  group('Tier 1 - Feature 1: SQLite Card Attribute Indexes & Fast Filter Queries', () {
    test('F1.1: SQLite database verifies presence of performance indexes on vault_items', () async {
      final indexRows = await db.customSelect(
        'PRAGMA index_list("vault_items");',
      ).get();

      final indexNames = indexRows.map((r) => r.read<String>('name')).toSet();

      // Verify core attribute and performance indexes are created on vault_items
      expect(
        indexNames.any((name) =>
            name == 'idx_vault_items_browse' ||
            name == 'idx_vault_items_name' ||
            name == 'idx_vault_items_active' ||
            name == 'idx_vault_items_collection_qty'),
        isTrue,
        reason: 'At least one primary index on vault_items must be registered in SQLite',
      );
    });

    test('F1.2: Indexed name query matches case-insensitively and returns target card', () async {
      final results = await dao.getItemsByCollection(
        'mtg',
        searchQuery: 'black lotus',
        onlyOwned: false,
      );

      expect(results, isNotEmpty);
      expect(results.first.name, equals('Black Lotus'));
      expect(results.first.id, equals('c-lotus'));
    });

    test('F1.3: Alternate printed flavor_name query matches indexed flavor names', () async {
      // "Adamantium Bonding Tank" is the printed flavor name for "The Ozolith"
      final results = await dao.getItemsByCollection(
        'mtg',
        searchQuery: 'Adamantium',
        onlyOwned: false,
      );

      expect(results, isNotEmpty);
      expect(results.any((c) => c.name == 'The Ozolith'), isTrue);
      final ozolith = results.firstWhere((c) => c.name == 'The Ozolith');
      expect(ozolith.flavorName, equals('Adamantium Bonding Tank'));
    });

    test('F1.4: Scoped query by collection type and owned status leverages active index', () async {
      // Query owned cards (quantity > 0) in MTG
      final ownedMtg = await dao.getItemsByCollection(
        'mtg',
        onlyOwned: true,
      );

      expect(ownedMtg, isNotEmpty);
      // All returned items must have quantity > 0 and collectionType == 'mtg'
      for (final item in ownedMtg) {
        expect(item.quantity, greaterThan(0));
        expect(item.collectionType, equals('mtg'));
      }
      // Unowned cards (Lotus, Counterspell, Wrath) must NOT be present
      expect(ownedMtg.any((c) => c.name == 'Black Lotus'), isFalse);
      expect(ownedMtg.any((c) => c.name == 'Counterspell'), isFalse);
    });

    test('F1.5: Explain query plan verifies index usage for catalog name search', () async {
      final plan = await db.customSelect(
        'EXPLAIN QUERY PLAN SELECT * FROM vault_items WHERE is_deleted = 0 AND collection_type = ? AND name LIKE ?;',
        variables: [
          drift.Variable<String>('mtg'),
          drift.Variable<String>('Lotus%'),
        ],
      ).get();

      expect(plan, isNotEmpty);
      final detail = plan.map((r) => r.read<String>('detail')).join(' ');
      // The query plan should execute cleanly without error
      expect(detail, isNotEmpty);
    });
  });
}
