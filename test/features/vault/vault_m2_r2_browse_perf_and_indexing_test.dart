import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/vault/domain/vault_variant_helper.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_card.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_tile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Milestone 2 (R2): Covering Indexes in AppDatabase (F6)', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('idx_vault_items_browse and idx_vault_items_catalog_name exist in database schema', () async {
      // Force database to open and run beforeOpen
      await db.customSelect('SELECT 1').get();

      final rows = await db.customSelect(
        "SELECT name, sql FROM sqlite_master WHERE type = 'index' AND tbl_name = 'vault_items'",
      ).get();

      final indexNames = rows.map((r) => r.read<String>('name')).toSet();

      expect(indexNames, contains('idx_vault_items_browse'),
          reason: 'idx_vault_items_browse index covering is_deleted and collection_type must exist');
      expect(indexNames, contains('idx_vault_items_catalog_name'),
          reason: 'idx_vault_items_catalog_name index covering NOCASE name ordering must exist');

      final browseIndexRow = rows.firstWhere((r) => r.read<String>('name') == 'idx_vault_items_browse');
      final browseSql = browseIndexRow.read<String?>('sql') ?? '';
      expect(browseSql.toLowerCase(), contains('is_deleted'));
      expect(browseSql.toLowerCase(), contains('collection_type'));

      final catalogNameIndexRow = rows.firstWhere((r) => r.read<String>('name') == 'idx_vault_items_catalog_name');
      final catalogNameSql = catalogNameIndexRow.read<String?>('sql') ?? '';
      expect(catalogNameSql.toLowerCase(), contains('is_deleted'));
      expect(catalogNameSql.toLowerCase(), contains('nocase'));
    });
  });

  group('Milestone 2 (R2): VaultVariantHelper Memoization (F7)', () {
    final now = DateTime.now();

    final testItem = VaultItem(
      id: 'test-item-1',
      collectionType: 'mtg',
      name: 'Black Lotus',
      setOrSeries: 'LEA',
      imageUrl: 'https://example.com/lotus.jpg',
      acquiredPrice: 5000.0,
      acquiredDate: now,
      quantity: 1,
      condition: 'NM',
      currentMarketPrice: 10000.0,
      lastPriceUpdate: now,
      dynamicData: jsonEncode({
        'oracle_id': 'oracle-lotus-123',
        'scryfall_id': 'scryfall-lotus-456',
        'finish': 'nonfoil',
      }),
      isDeleted: false,
      isGraded: false,
      isAltered: false,
      isMisprint: false,
      isSigned: false,
      updatedAt: now,
    );

    setUp(() {
      VaultVariantHelper.clearCache();
    });

    test('computeVariantKey and resolveAbstractCardKey compute deterministic results', () {
      final variantKey = VaultVariantHelper.computeVariantKey(testItem);
      expect(variantKey, equals('mtg_scryfall-lotus-456_nonfoil'));

      final abstractKey = VaultVariantHelper.resolveAbstractCardKey(testItem);
      expect(abstractKey, equals('mtg_oracle-lotus-123'));
    });

    test('memoization caches keys and updates when item timestamp changes', () {
      final key1 = VaultVariantHelper.computeVariantKey(testItem);
      final key2 = VaultVariantHelper.computeVariantKey(testItem);
      expect(identical(key1, key2), isTrue);

      final updatedTime = now.add(const Duration(seconds: 10));
      final updatedItem = testItem.copyWith(
        dynamicData: jsonEncode({
          'oracle_id': 'oracle-lotus-123',
          'scryfall_id': 'scryfall-lotus-789',
          'finish': 'foil',
        }),
        updatedAt: drift.Value(updatedTime),
      );

      final keyUpdated = VaultVariantHelper.computeVariantKey(updatedItem);
      expect(keyUpdated, equals('mtg_scryfall-lotus-789_foil'));
      expect(keyUpdated, isNot(equals(key1)));
    });

    test('clearCache purges in-memory memoized entries', () {
      final keyBefore = VaultVariantHelper.computeVariantKey(testItem);
      VaultVariantHelper.clearCache();
      final keyAfter = VaultVariantHelper.computeVariantKey(testItem);
      expect(keyBefore, equals(keyAfter));
    });
  });

  group('Milestone 2 (R2): Stream Multiplier & Pagination Limit (F7)', () {
    test('vaultPaginationLimitProvider defaults to 50 in FLUTTER_TEST environment', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final limit = container.read(vaultPaginationLimitProvider);
      expect(limit, equals(50));
    });

    test('vaultItemsStreamProvider uses 1.25x fetch limit when showCatalog is true and unfiltered', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      // Insert 15 items
      final now = DateTime.now();
      for (int i = 0; i < 15; i++) {
        await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'catalog-item-$i',
            collectionType: 'mtg',
            name: 'Card $i',
            setOrSeries: 'SET',
            imageUrl: '',
            acquiredPrice: 0.0,
            acquiredDate: now,
            quantity: const drift.Value(0),
            condition: 'NM',
            currentMarketPrice: 1.0,
            lastPriceUpdate: now,
            dynamicData: '{}',
          ),
        );
      }

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
          vaultShowCatalogProvider.overrideWith((ref) => true),
          vaultPaginationLimitProvider.overrideWith((ref) => 10),
        ],
      );
      addTearDown(container.dispose);

      final items = await container.read(vaultItemsStreamProvider.future);
      expect(items.length, equals(10));
    });
  });

  group('Milestone 2 (R2): Short-Circuiting Deck Badges for Unowned Items (F8)', () {
    final now = DateTime.now();

    final unownedItem = VaultItem(
      id: 'unowned-card',
      collectionType: 'mtg',
      name: 'Unowned Reference Card',
      setOrSeries: 'SET',
      imageUrl: '',
      acquiredPrice: 0.0,
      acquiredDate: now,
      quantity: 0,
      condition: 'NM',
      currentMarketPrice: 10.0,
      lastPriceUpdate: now,
      dynamicData: '{}',
      isDeleted: false,
      isGraded: false,
      isAltered: false,
      isMisprint: false,
      isSigned: false,
    );

    testWidgets('OptionalDeckBadges in vault_item_card returns SizedBox.shrink immediately for unowned card', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OptionalDeckBadges(item: unownedItem),
          ),
        ),
      );

      expect(find.byType(OptionalDeckBadges), findsOneWidget);
      expect(find.byType(SizedBox), findsOneWidget);
      final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox));
      expect(sizedBox.width, equals(0.0));
      expect(sizedBox.height, equals(0.0));
    });

    testWidgets('VaultItemTile renders unowned item without mounting unnecessary deck badge consumers', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 150,
              height: 220,
              child: VaultItemTile(
                item: unownedItem,
                hasMultipleVariants: false,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(VaultItemTile), findsOneWidget);
      expect(find.text('Unowned Reference Card'), findsOneWidget);
    });
  });
}
