import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
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

  group('Switch Printing in Vault Collection Tests', () {
    test('VaultDao.switchCardPrinting performs in-place mutation without altering ID or quantity', () async {
      // 1. Create a binder
      await db.into(db.vaultBinders).insert(VaultBindersCompanion.insert(
        id: 'binder-rares',
        name: 'Rare Binder',
        collectionType: 'mtg',
        createdAt: DateTime.now(),
      ));

      // 2. Insert initial VaultItem
      final initialDate = DateTime.now();
      await db.into(db.vaultItems).insert(VaultItemsCompanion.insert(
        id: 'item-crypt-1',
        collectionType: 'mtg',
        name: 'Mana Crypt',
        setOrSeries: 'Mystery Booster',
        imageUrl: 'https://example.com/mb1.jpg',
        acquiredPrice: 80.0,
        acquiredDate: initialDate,
        quantity: const drift.Value(2),
        primaryBinderId: const drift.Value('binder-rares'),
        condition: 'NM',
        currentMarketPrice: 90.0,
        lastPriceUpdate: initialDate,
        dynamicData: '{"collector_number": "100", "set_code": "mb1"}',
      ));

      // 3. Perform printing switch to Double Masters (2XM)
      final updated = await db.vaultDao.switchCardPrinting(
        id: 'item-crypt-1',
        setCode: '2xm',
        setName: 'Double Masters',
        collectorNumber: '383',
        imageUrl: 'https://example.com/2xm-383.jpg',
        artCropUrl: 'https://example.com/2xm-art.jpg',
        marketPrice: 150.0,
        treatment: 'Foil',
        extraDynamicData: {'rarity': 'mythic'},
      );

      // 4. Verify in-memory return value
      expect(updated.id, 'item-crypt-1');
      expect(updated.setOrSeries, 'Double Masters (Foil)');
      expect(updated.imageUrl, 'https://example.com/2xm-383.jpg');
      expect(updated.currentMarketPrice, 150.0);
      expect(updated.quantity, 2);
      expect(updated.primaryBinderId, 'binder-rares');

      final dyn = jsonDecode(updated.dynamicData) as Map<String, dynamic>;
      expect(dyn['treatment'], 'Foil');
      expect(dyn['collector_number'], '383');
      expect(dyn['set_code'], '2xm');
      expect(dyn['rarity'], 'mythic');

      // 5. Verify database persistent state
      final dbItem = await (db.select(db.vaultItems)
            ..where((tbl) => tbl.id.equals('item-crypt-1')))
          .getSingle();

      expect(dbItem.setOrSeries, 'Double Masters (Foil)');
      expect(dbItem.currentMarketPrice, 150.0);
      expect(dbItem.quantity, 2);
      expect(dbItem.primaryBinderId, 'binder-rares');
    });

    testWidgets('SwitchPrintingModal opens, displays card, allows treatment change and applies switch', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // 1. Insert item in DB
      await db.into(db.vaultItems).insert(VaultItemsCompanion.insert(
        id: 'item-crypt-1',
        collectionType: 'mtg',
        name: 'Mana Crypt',
        setOrSeries: 'Mystery Booster',
        imageUrl: 'https://example.com/mb1.jpg',
        acquiredPrice: 80.0,
        acquiredDate: DateTime.now(),
        quantity: const drift.Value(1),
        condition: 'NM',
        currentMarketPrice: 90.0,
        lastPriceUpdate: DateTime.now(),
        dynamicData: '{"collector_number": "100", "set_code": "mb1"}',
      ));

      final testItem = await (db.select(db.vaultItems)
            ..where((tbl) => tbl.id.equals('item-crypt-1')))
          .getSingle();

      VaultItem? resultItem;

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
                    testItem,
                    onUpdated: (item) => resultItem = item,
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

      // Verify modal headers and card name
      expect(find.text('Switch Printing / Edition'), findsOneWidget);
      expect(find.text('Mana Crypt'), findsOneWidget);

      // Verify treatment chips are present
      expect(find.text('Finish & Treatment'), findsOneWidget);
      expect(find.text('Foil'), findsOneWidget);

      // Select 'Foil' treatment
      await tester.ensureVisible(find.text('Foil'));
      await tester.tap(find.text('Foil'));
      await tester.pumpAndSettle();

      // Submit switch printing
      final applyButton = find.byKey(const Key('apply_switch_printing_button'));
      expect(applyButton, findsOneWidget);
      await tester.tap(applyButton);
      await tester.pumpAndSettle();

      expect(resultItem, isNotNull);
      final dyn = jsonDecode(resultItem!.dynamicData) as Map<String, dynamic>;
      expect(dyn['treatment'], 'Foil');
    });
  });
}
