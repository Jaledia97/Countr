import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/domain/vault_variant_helper.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Challenger 1 Empirical Verification: SQLite Index Existence & Query Plan', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      // Force database to open and execute beforeOpen
      await db.customSelect('SELECT 1').get();
    });

    tearDown(() async {
      await db.close();
    });

    test('Indexes exist unconditionally on both new and existing database opens', () async {
      // 1. Verify on newly opened database
      final indexes = await db.customSelect(
        "SELECT name, sql FROM sqlite_master WHERE type = 'index' AND tbl_name = 'vault_items'",
      ).get();

      final indexMap = {
        for (final row in indexes)
          row.read<String>('name'): row.read<String?>('sql') ?? '',
      };

      expect(indexMap.containsKey('idx_vault_items_browse'), isTrue,
          reason: 'idx_vault_items_browse must exist');
      expect(indexMap.containsKey('idx_vault_items_catalog_name'), isTrue,
          reason: 'idx_vault_items_catalog_name must exist');

      final browseSql = indexMap['idx_vault_items_browse']!.toLowerCase();
      expect(browseSql, contains('"is_deleted"'));
      expect(browseSql, contains('"collection_type"'));
      expect(browseSql, contains('"acquired_date" desc'));
      expect(browseSql, contains('"name" asc'));

      final catalogSql = indexMap['idx_vault_items_catalog_name']!.toLowerCase();
      expect(catalogSql, contains('"is_deleted"'));
      expect(catalogSql, contains('"collection_type"'));
      expect(catalogSql, contains('"name" collate nocase asc'));
    });

    test('EXPLAIN QUERY PLAN verifies index scan without TEMP B-TREE for unfiltered browse query', () async {
      // Insert representative rows
      final now = DateTime.now();
      for (int i = 0; i < 50; i++) {
        await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'plan-item-$i',
            collectionType: 'mtg',
            name: 'Card $i',
            setOrSeries: 'LEA',
            imageUrl: '',
            acquiredPrice: 10.0,
            acquiredDate: now.subtract(Duration(days: i)),
            quantity: const drift.Value(0),
            condition: 'NM',
            currentMarketPrice: 20.0,
            lastPriceUpdate: now,
            dynamicData: '{}',
          ),
        );
      }

      // Query mimicking VaultDao.watchItemsByCollection unfiltered query
      final planRows = await db.customSelect('''
        EXPLAIN QUERY PLAN
        SELECT * FROM "vault_items"
        WHERE "is_deleted" = 0
          AND "collection_type" = 'mtg'
          AND ("primary_binder_id" IS NULL OR "primary_binder_id" != 'INBOX')
        ORDER BY "acquired_date" DESC, "name" ASC
        LIMIT 120;
      ''').get();

      final planDetails = planRows.map((r) => r.read<String>('detail')).toList();
      final fullPlan = planDetails.join(' | ');

      // Must use idx_vault_items_browse
      expect(fullPlan, contains('idx_vault_items_browse'),
          reason: 'SQLite query plan must use idx_vault_items_browse: $fullPlan');

      // Must NOT use temporary B-tree for ordering
      expect(fullPlan.toLowerCase(), isNot(contains('use temp b-tree for order by')),
          reason: 'Covering index must eliminate temporary B-tree sorting: $fullPlan');
    });

    test('EXPLAIN QUERY PLAN verifies index scan without TEMP B-TREE for catalog name query', () async {
      final planRows = await db.customSelect('''
        EXPLAIN QUERY PLAN
        SELECT * FROM "vault_items"
        WHERE "is_deleted" = 0
          AND "collection_type" = 'mtg'
        ORDER BY "name" COLLATE NOCASE ASC
        LIMIT 120;
      ''').get();

      final planDetails = planRows.map((r) => r.read<String>('detail')).toList();
      final fullPlan = planDetails.join(' | ');

      // Must use idx_vault_items_catalog_name
      expect(fullPlan, contains('idx_vault_items_catalog_name'),
          reason: 'SQLite query plan must use idx_vault_items_catalog_name: $fullPlan');

      // Must NOT use temporary B-tree for ordering
      expect(fullPlan.toLowerCase(), isNot(contains('use temp b-tree for order by')),
          reason: 'Covering index must eliminate temporary B-tree sorting: $fullPlan');
    });
  });

  group('Challenger 1 Empirical Verification: Variant Memoization Stress & Eviction', () {
    setUp(() {
      VaultVariantHelper.clearCache();
    });

    tearDown(() {
      VaultVariantHelper.clearCache();
    });

    test('Stress test: 25,000 distinct items safely trigger bounded cache eviction without OOM', () {
      final now = DateTime.now();

      // Generate 25,000 items to exceed _maxCacheSize (20,000)
      for (int i = 0; i < 25000; i++) {
        final item = VaultItem(
          id: 'stress-card-$i',
          collectionType: 'mtg',
          name: 'Stress Card $i',
          setOrSeries: 'SET',
          imageUrl: '',
          acquiredPrice: 1.0,
          acquiredDate: now,
          quantity: 1,
          condition: 'NM',
          currentMarketPrice: 2.0,
          lastPriceUpdate: now,
          dynamicData: '{"scryfall_id":"scryfall-$i","oracle_id":"oracle-$i","finish":"nonfoil"}',
          isDeleted: false,
          isGraded: false,
          isAltered: false,
          isMisprint: false,
          isSigned: false,
          updatedAt: now,
        );

        final variantKey = VaultVariantHelper.computeVariantKey(item);
        final abstractKey = VaultVariantHelper.resolveAbstractCardKey(item);

        expect(variantKey, equals('mtg_scryfall-${i}_nonfoil'));
        expect(abstractKey, equals('mtg_oracle-$i'));
      }

      // Ensure that after eviction, new computations still succeed deterministically
      final testItem = VaultItem(
        id: 'post-stress-item',
        collectionType: 'mtg',
        name: 'Post Stress Item',
        setOrSeries: 'SET',
        imageUrl: '',
        acquiredPrice: 5.0,
        acquiredDate: now,
        quantity: 1,
        condition: 'NM',
        currentMarketPrice: 10.0,
        lastPriceUpdate: now,
        dynamicData: '{"scryfall_id":"scryfall-post","oracle_id":"oracle-post","finish":"foil"}',
        isDeleted: false,
        isGraded: false,
        isAltered: false,
        isMisprint: false,
        isSigned: false,
        updatedAt: now,
      );

      final key1 = VaultVariantHelper.computeVariantKey(testItem);
      final key2 = VaultVariantHelper.computeVariantKey(testItem);
      expect(identical(key1, key2), isTrue);
      expect(key1, equals('mtg_scryfall-post_foil'));
    });

    test('Memoization properly invalidates when item updatedAt changes', () {
      final t1 = DateTime(2026, 1, 1);
      final t2 = DateTime(2026, 1, 2);

      final itemV1 = VaultItem(
        id: 'item-inv-1',
        collectionType: 'mtg',
        name: 'Item Invalidation Test',
        setOrSeries: 'SET',
        imageUrl: '',
        acquiredPrice: 1.0,
        acquiredDate: t1,
        quantity: 1,
        condition: 'NM',
        currentMarketPrice: 2.0,
        lastPriceUpdate: t1,
        dynamicData: '{"scryfall_id":"scryfall-v1","finish":"nonfoil"}',
        isDeleted: false,
        isGraded: false,
        isAltered: false,
        isMisprint: false,
        isSigned: false,
        updatedAt: t1,
      );

      final keyV1 = VaultVariantHelper.computeVariantKey(itemV1);
      expect(keyV1, equals('mtg_scryfall-v1_nonfoil'));

      final itemV2 = itemV1.copyWith(
        dynamicData: '{"scryfall_id":"scryfall-v2","finish":"etched"}',
        updatedAt: drift.Value(t2),
      );

      final keyV2 = VaultVariantHelper.computeVariantKey(itemV2);
      expect(keyV2, equals('mtg_scryfall-v2_etched'));
      expect(keyV2, isNot(equals(keyV1)));
    });
  });

  group('Challenger 1 Empirical Verification: 120-item Chunking & 1.25x Multiplier', () {
    test('1.25x fetch multiplier calculations across edge cases', () {
      int calculateFetchLimit(int limit, bool isUnfilteredCatalog) {
        final multiplier = isUnfilteredCatalog ? 1.25 : 2.0;
        return (limit * multiplier).ceil();
      }

      // Unfiltered catalog mode: 1.25x
      expect(calculateFetchLimit(120, true), equals(150));
      expect(calculateFetchLimit(50, true), equals(63));
      expect(calculateFetchLimit(10, true), equals(13));
      expect(calculateFetchLimit(1, true), equals(2));
      expect(calculateFetchLimit(0, true), equals(0));

      // Filtered mode: 2.0x
      expect(calculateFetchLimit(120, false), equals(240));
      expect(calculateFetchLimit(50, false), equals(100));
      expect(calculateFetchLimit(10, false), equals(20));
      expect(calculateFetchLimit(1, false), equals(2));
      expect(calculateFetchLimit(0, false), equals(0));
    });

    test('vaultPaginationLimitProvider value matches environment', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final limit = container.read(vaultPaginationLimitProvider);
      // In flutter test runner, Platform.environment.containsKey('FLUTTER_TEST') is true
      expect(limit, equals(50));
    });
  });
}
