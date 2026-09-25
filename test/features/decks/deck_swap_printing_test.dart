import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/presentation/widgets/deck_swap_printing_sheet.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';

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

  group('Global Swap Printing in Deck Builder Tests', () {
    test('VaultDao queries alternative owned printings and swaps deck version item', () async {
      // 1. Create Binder
      await db.into(db.vaultBinders).insert(VaultBindersCompanion.insert(
        id: 'binder-commander',
        name: 'Commander Binder',
        collectionType: 'mtg',
        createdAt: DateTime.now(),
      ));

      // 2. Create Deck and Deck Version
      await db.into(db.decks).insert(DecksCompanion.insert(
        id: 'deck-urza',
        name: 'Urza Deck',
        format: 'Commander',
        createdAt: DateTime.now(),
      ));

      await db.into(db.deckVersions).insert(DeckVersionsCompanion.insert(
        id: 'v-urza-1',
        deckId: 'deck-urza',
        versionNumber: 1,
        createdAt: DateTime.now(),
      ));

      // 3. Create Vault Items:
      // Item A: Sol Ring (C21, $2.00)
      await db.into(db.vaultItems).insert(VaultItemsCompanion.insert(
        id: 'item-sol-c21',
        collectionType: 'mtg',
        name: 'Sol Ring',
        setOrSeries: 'Commander 2021',
        imageUrl: 'https://example.com/c21.jpg',
        acquiredPrice: 2.0,
        acquiredDate: DateTime.now(),
        quantity: const drift.Value(1),
        condition: 'NM',
        currentMarketPrice: 2.00,
        lastPriceUpdate: DateTime.now(),
        dynamicData: '{"oracle_id": "oracle-sol-ring"}',
      ));

      // Item B: Sol Ring (M21 Foil, $5.00, in binder)
      await db.into(db.vaultItems).insert(VaultItemsCompanion.insert(
        id: 'item-sol-m21',
        collectionType: 'mtg',
        name: 'Sol Ring',
        setOrSeries: 'Core 2021',
        imageUrl: 'https://example.com/m21.jpg',
        acquiredPrice: 4.5,
        acquiredDate: DateTime.now(),
        quantity: const drift.Value(1),
        primaryBinderId: const drift.Value('binder-commander'),
        condition: 'NM',
        currentMarketPrice: 5.00,
        lastPriceUpdate: DateTime.now(),
        dynamicData: '{"oracle_id": "oracle-sol-ring"}',
      ));

      // 4. Create Deck Version Item referencing Item A
      await db.into(db.deckVersionItems).insert(DeckVersionItemsCompanion.insert(
        id: 'dvi-sol-1',
        versionId: 'v-urza-1',
        vaultItemId: 'item-sol-c21',
        boardZone: 'mainboard',
        quantity: const drift.Value(1),
      ));

      // 5. Query alternative printings excluding Item A
      final alternatives = await db.vaultDao.getAlternativePrintings(
        'Sol Ring',
        oracleId: 'oracle-sol-ring',
        excludeVaultItemId: 'item-sol-c21',
      );

      expect(alternatives.length, 1);
      expect(alternatives.first.id, 'item-sol-m21');
      expect(alternatives.first.setOrSeries, 'Core 2021');

      // 6. Swap printing to Item B
      await db.vaultDao.swapDeckItemPrinting('dvi-sol-1', 'item-sol-m21');

      // 7. Verify deck version item was updated
      final updatedDvi = await (db.select(db.deckVersionItems)
            ..where((tbl) => tbl.id.equals('dvi-sol-1')))
          .getSingle();

      expect(updatedDvi.vaultItemId, 'item-sol-m21');
    });

    testWidgets('DeckSwapPrintingSheet renders alternatives and executes swap', (tester) async {
      // 1. Seed data in DB
      await db.into(db.vaultBinders).insert(VaultBindersCompanion.insert(
        id: 'binder-commander',
        name: 'Commander Binder',
        collectionType: 'mtg',
        createdAt: DateTime.now(),
      ));

      await db.into(db.vaultItems).insert(VaultItemsCompanion.insert(
        id: 'item-sol-c21',
        collectionType: 'mtg',
        name: 'Sol Ring',
        setOrSeries: 'Commander 2021',
        imageUrl: 'https://example.com/c21.jpg',
        acquiredPrice: 2.0,
        acquiredDate: DateTime.now(),
        quantity: const drift.Value(1),
        condition: 'NM',
        currentMarketPrice: 2.00,
        lastPriceUpdate: DateTime.now(),
        dynamicData: '{"oracle_id": "oracle-sol-ring"}',
      ));

      await db.into(db.vaultItems).insert(VaultItemsCompanion.insert(
        id: 'item-sol-m21',
        collectionType: 'mtg',
        name: 'Sol Ring',
        setOrSeries: 'Core 2021',
        imageUrl: 'https://example.com/m21.jpg',
        acquiredPrice: 4.5,
        acquiredDate: DateTime.now(),
        quantity: const drift.Value(1),
        primaryBinderId: const drift.Value('binder-commander'),
        condition: 'NM',
        currentMarketPrice: 5.00,
        lastPriceUpdate: DateTime.now(),
        dynamicData: '{"oracle_id": "oracle-sol-ring"}',
      ));

      await db.into(db.decks).insert(DecksCompanion.insert(
        id: 'deck-urza',
        name: 'Urza Deck',
        format: 'Commander',
        createdAt: DateTime.now(),
      ));

      await db.into(db.deckVersions).insert(DeckVersionsCompanion.insert(
        id: 'v-urza-1',
        deckId: 'deck-urza',
        versionNumber: 1,
        createdAt: DateTime.now(),
      ));

      await db.into(db.deckVersionItems).insert(DeckVersionItemsCompanion.insert(
        id: 'dvi-sol-1',
        versionId: 'v-urza-1',
        vaultItemId: 'item-sol-c21',
        boardZone: 'mainboard',
        quantity: const drift.Value(1),
      ));

      bool swapped = false;

      final deckItemMap = {
        'dvi_id': 'dvi-sol-1',
        'vault_item_id': 'item-sol-c21',
        'name': 'Sol Ring',
        'set_or_series': 'Commander 2021',
        'image_url': 'https://example.com/c21.jpg',
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
                    deckId: 'deck-urza',
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

      // Verify header and current assigned copy
      expect(find.text('Swap Physical Printing'), findsOneWidget);
      expect(find.text('CURRENTLY ASSIGNED'), findsOneWidget);
      expect(find.text('Commander 2021'), findsOneWidget);

      // Verify alternative is loaded
      expect(find.text('Core 2021'), findsOneWidget);
      expect(find.textContaining('Commander Binder'), findsOneWidget);
      expect(find.text('\$5.00'), findsOneWidget);

      // Select alternative
      await tester.tap(find.text('Core 2021'));
      await tester.pumpAndSettle();

      // Confirm swap button should be enabled
      final confirmBtn = find.byKey(const Key('confirm_swap_printing_button'));
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      expect(swapped, isTrue);

      // Verify DB change
      final updatedDvi = await (db.select(db.deckVersionItems)
            ..where((tbl) => tbl.id.equals('dvi-sol-1')))
          .getSingle();
      expect(updatedDvi.vaultItemId, 'item-sol-m21');
    });
  });
}
