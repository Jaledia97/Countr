import 'dart:convert';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/domain/vault_variant_helper.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_tile.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VaultVariantHelper Unit Tests', () {
    VaultItem createItem({
      required String id,
      required String name,
      required String setCode,
      required int quantity,
      String? scryfallId,
      String? oracleId,
      String? finish,
      String condition = 'Near Mint',
    }) {
      final dynamicData = <String, dynamic>{};
      if (scryfallId != null) dynamicData['scryfall_id'] = scryfallId;
      if (oracleId != null) dynamicData['oracle_id'] = oracleId;
      if (finish != null) dynamicData['finish'] = finish;

      final now = DateTime.now();
      return VaultItem(
        id: id,
        collectionType: 'mtg',
        name: name,
        setOrSeries: setCode,
        imageUrl: '',
        acquiredPrice: 0.0,
        acquiredDate: now,
        quantity: quantity,
        condition: condition,
        isGraded: false,
        isAltered: false,
        isMisprint: false,
        isSigned: false,
        currentMarketPrice: 0.0,
        lastPriceUpdate: now,
        dynamicData: jsonEncode(dynamicData),
        isDeleted: false,
      );
    }

    test('computeVariantKey correctly combines scryfall_id and finish', () {
      final item = createItem(
        id: 'item-1',
        name: 'Sol Ring',
        setCode: 'C21',
        quantity: 1,
        scryfallId: 'scryfall-sol-ring-1',
        finish: 'foil',
      );

      final key = VaultVariantHelper.computeVariantKey(item);
      expect(key, equals('mtg_scryfall-sol-ring-1_foil'));
    });

    test('computeVariantKey falls back to item.id and nonfoil when fields are absent', () {
      final item = createItem(
        id: 'item-fallback',
        name: 'Sol Ring',
        setCode: 'C21',
        quantity: 1,
      );

      final key = VaultVariantHelper.computeVariantKey(item);
      expect(key, equals('mtg_item-fallback_nonfoil'));
    });

    test('computeVariantKey normalizes finish case', () {
      final item = createItem(
        id: 'item-case',
        name: 'Sol Ring',
        setCode: 'C21',
        quantity: 1,
        scryfallId: 'scry-1',
        finish: 'Etched Foil',
      );

      final key = VaultVariantHelper.computeVariantKey(item);
      expect(key, equals('mtg_scry-1_etched foil'));
    });

    test('resolveAbstractCardKey uses oracle_id when available', () {
      final item = createItem(
        id: 'item-1',
        name: 'Sol Ring',
        setCode: 'C21',
        quantity: 1,
        oracleId: 'oracle-sol-ring',
      );

      final abstractKey = VaultVariantHelper.resolveAbstractCardKey(item);
      expect(abstractKey, equals('mtg_oracle-sol-ring'));
    });

    test('groupVaultItemsByVariant consolidates identical (scryfall_id, finish) items', () {
      final item1 = createItem(
        id: 'item-1',
        name: 'Sol Ring',
        setCode: 'C21',
        quantity: 1,
        scryfallId: 'scryfall-sol-ring-1',
        oracleId: 'oracle-sol-ring',
        finish: 'foil',
      );
      final item2 = createItem(
        id: 'item-2',
        name: 'Sol Ring',
        setCode: 'C21',
        quantity: 2,
        scryfallId: 'scryfall-sol-ring-1',
        oracleId: 'oracle-sol-ring',
        finish: 'foil',
      );

      final result = VaultVariantHelper.groupVaultItemsByVariant([item1, item2]);
      expect(result.items.length, equals(1));
      expect(result.items.first.quantity, equals(3));
      expect(result.multiVariantCardKeys.isEmpty, isTrue);
    });

    test('groupVaultItemsByVariant keeps distinct printings/finishes separate and flags multi-variants', () {
      final regularFoil = createItem(
        id: 'item-1',
        name: 'The One Ring',
        setCode: 'LTR',
        quantity: 1,
        scryfallId: 'scryfall-ltr-1',
        oracleId: 'oracle-one-ring',
        finish: 'foil',
      );
      final showcaseNonfoil = createItem(
        id: 'item-2',
        name: 'The One Ring',
        setCode: 'LTR',
        quantity: 1,
        scryfallId: 'scryfall-ltr-borderless',
        oracleId: 'oracle-one-ring',
        finish: 'nonfoil',
      );

      final result = VaultVariantHelper.groupVaultItemsByVariant([regularFoil, showcaseNonfoil]);
      expect(result.items.length, equals(2));
      expect(result.multiVariantCardKeys.contains('mtg_oracle-one-ring'), isTrue);
    });
  });

  group('Database-level Consolidation Tests', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      await db.customSelect('SELECT 1;').get();
    });

    tearDown(() async {
      await db.close();
    });

    test('consolidateDuplicateVaultItems merges duplicate SQLite rows and updates sync queue', () async {
      final now = DateTime.now();
      final row1 = VaultItemsCompanion.insert(
        id: 'row-dup-1',
        collectionType: 'mtg',
        name: 'Lightning Bolt',
        setOrSeries: 'M11',
        imageUrl: '',
        quantity: const Value(2),
        condition: 'Near Mint',
        acquiredPrice: 1.50,
        acquiredDate: now,
        currentMarketPrice: 1.50,
        lastPriceUpdate: now,
        dynamicData: jsonEncode({
          'scryfall_id': 'scry-bolt-1',
          'oracle_id': 'oracle-bolt',
          'finish': 'nonfoil',
        }),
      );
      final row2 = VaultItemsCompanion.insert(
        id: 'row-dup-2',
        collectionType: 'mtg',
        name: 'Lightning Bolt',
        setOrSeries: 'M11',
        imageUrl: '',
        quantity: const Value(3),
        condition: 'Near Mint',
        acquiredPrice: 1.50,
        acquiredDate: now,
        currentMarketPrice: 1.50,
        lastPriceUpdate: now,
        dynamicData: jsonEncode({
          'scryfall_id': 'scry-bolt-1',
          'oracle_id': 'oracle-bolt',
          'finish': 'nonfoil',
        }),
      );

      await db.into(db.vaultItems).insert(row1);
      await db.into(db.vaultItems).insert(row2);

      final mergedCount = await db.vaultDao.consolidateDuplicateVaultItems();
      expect(mergedCount, equals(1));

      // Primary row must now have quantity 5
      final survivor = await (db.select(db.vaultItems)
            ..where((t) => t.id.equals('row-dup-1')))
          .getSingle();
      expect(survivor.quantity, equals(5));
      expect(survivor.isDeleted, isFalse);

      // Duplicate row must be soft-deleted
      final softDeleted = await (db.select(db.vaultItems)
            ..where((t) => t.id.equals('row-dup-2')))
          .getSingle();
      expect(softDeleted.isDeleted, isTrue);

      // Sync queue must contain entries
      final syncEntries = await db.select(db.syncQueue).get();
      expect(syncEntries.any((s) => s.entityId == 'row-dup-2' && s.operation == 'DELETE'), isTrue);
      expect(syncEntries.any((s) => s.entityId == 'row-dup-1' && s.operation == 'UPDATE'), isTrue);
    });
  });

  group('VaultItemTile & VaultItemCard Variant Badge Logic', () {
    VaultItem createItem({
      required String id,
      required String name,
      required int quantity,
      String? scryfallId,
      String? finish,
    }) {
      final now = DateTime.now();
      return VaultItem(
        id: id,
        collectionType: 'mtg',
        name: name,
        setOrSeries: 'LTR',
        imageUrl: '',
        acquiredPrice: 10.0,
        acquiredDate: now,
        quantity: quantity,
        condition: 'Near Mint',
        isGraded: false,
        isAltered: false,
        isMisprint: false,
        isSigned: false,
        currentMarketPrice: 10.0,
        lastPriceUpdate: now,
        dynamicData: jsonEncode({
          'scryfall_id': scryfallId ?? id,
          'finish': finish ?? 'nonfoil',
        }),
        isDeleted: false,
      );
    }

    testWidgets('VaultItemTile: Solitary single copy card omits badge', (tester) async {
      final solitaryItem = createItem(id: 'solitary-1', name: 'Solitary Card', quantity: 1);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VaultItemTile(
              item: solitaryItem,
              hasMultipleVariants: false,
            ),
          ),
        ),
      );

      // No 1x badge rendered
      expect(find.byKey(Key('vault_tile_variant_badge_${solitaryItem.id}')), findsNothing);
      expect(find.byKey(Key('vault_tile_duplicate_badge_${solitaryItem.id}')), findsNothing);
      expect(find.text('1x'), findsNothing);
    });

    testWidgets('VaultItemTile: Duplicate quantity displays duplicate badge (e.g. 3x)', (tester) async {
      final dupItem = createItem(id: 'dup-1', name: 'Duplicate Card', quantity: 3);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VaultItemTile(
              item: dupItem,
              hasMultipleVariants: false,
            ),
          ),
        ),
      );

      expect(find.byKey(Key('vault_tile_duplicate_badge_${dupItem.id}')), findsOneWidget);
      expect(find.text('3x'), findsOneWidget);
    });

    testWidgets('VaultItemTile: Single copy with multiple variants displays 1x variant badge', (tester) async {
      final variantItem = createItem(id: 'variant-1', name: 'Variant Card', quantity: 1);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VaultItemTile(
              item: variantItem,
              hasMultipleVariants: true,
            ),
          ),
        ),
      );

      expect(find.byKey(Key('vault_tile_variant_badge_${variantItem.id}')), findsOneWidget);
      expect(find.text('1x'), findsOneWidget);
    });

    testWidgets('VaultItemCard: Solitary single copy card omits badge', (tester) async {
      final solitaryItem = createItem(id: 'solitary-card-1', name: 'Solitary Card', quantity: 1);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 320,
              child: VaultItemCard(
                item: solitaryItem,
                hasMultipleVariants: false,
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(Key('vault_item_variant_badge_${solitaryItem.id}')), findsNothing);
      expect(find.byKey(Key('vault_item_duplicate_badge_${solitaryItem.id}')), findsNothing);
      expect(find.text('1x'), findsNothing);
    });

    testWidgets('VaultItemCard: Duplicate quantity displays duplicate badge (e.g. 4x)', (tester) async {
      final dupItem = createItem(id: 'dup-card-1', name: 'Duplicate Card', quantity: 4);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 320,
              child: VaultItemCard(
                item: dupItem,
                hasMultipleVariants: false,
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(Key('vault_item_duplicate_badge_${dupItem.id}')), findsOneWidget);
      expect(find.text('4x'), findsOneWidget);
    });

    testWidgets('VaultItemCard: Single copy with multiple variants displays 1x variant badge', (tester) async {
      final variantItem = createItem(id: 'variant-card-1', name: 'Variant Card', quantity: 1);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 320,
              child: VaultItemCard(
                item: variantItem,
                hasMultipleVariants: true,
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(Key('vault_item_variant_badge_${variantItem.id}')), findsOneWidget);
      expect(find.text('1x'), findsOneWidget);
    });
  });
}
