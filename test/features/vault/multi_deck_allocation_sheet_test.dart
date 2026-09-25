import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/presentation/providers/deck_providers.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/multi_deck_allocation_sheet.dart';

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

  group('Multi-Deck Allocation & Quantity Stepper Tests', () {
    test('VaultDao manages card quantities in decks and syncs deck history', () async {
      // 1. Create Decks
      await db.into(db.decks).insert(DecksCompanion.insert(
        id: 'deck-urza',
        name: 'Urza Commander Deck',
        format: 'Commander',
        createdAt: DateTime.now(),
      ));

      await db.into(db.decks).insert(DecksCompanion.insert(
        id: 'deck-pika',
        name: 'Pikachu VMAX',
        format: 'Standard',
        tcgDomain: const drift.Value('pokemon'),
        createdAt: DateTime.now(),
      ));

      // 2. Insert VaultItem
      await db.into(db.vaultItems).insert(VaultItemsCompanion.insert(
        id: 'item-sol-ring',
        collectionType: 'mtg',
        name: 'Sol Ring',
        setOrSeries: 'Commander 2021',
        imageUrl: 'https://example.com/sol.jpg',
        acquiredPrice: 2.0,
        acquiredDate: DateTime.now(),
        quantity: const drift.Value(4),
        condition: 'NM',
        currentMarketPrice: 2.50,
        lastPriceUpdate: DateTime.now(),
        dynamicData: '{}',
      ));

      // 3. Set quantity in Urza deck to 2
      await db.vaultDao.setCardQuantityInDeck('deck-urza', 'item-sol-ring', 2);

      // Verify watchCardDeckAllocations
      final allocations = await db.vaultDao.watchCardDeckAllocations('item-sol-ring').first;
      expect(allocations['deck-urza'], 2);

      // Verify dynamicData['deck_history'] synced
      final itemAfterAdd = await (db.select(db.vaultItems)
            ..where((tbl) => tbl.id.equals('item-sol-ring')))
          .getSingle();
      final dyn1 = jsonDecode(itemAfterAdd.dynamicData) as Map<String, dynamic>;
      final history1 = (dyn1['deck_history'] as List).cast<String>();
      expect(history1.contains('Urza Commander Deck'), isTrue);

      // 4. Remove card from Urza deck
      await db.vaultDao.removeCardFromDeck('deck-urza', 'item-sol-ring', quantity: 2);

      final allocationsAfterRemove = await db.vaultDao.watchCardDeckAllocations('item-sol-ring').first;
      expect(allocationsAfterRemove['deck-urza'], isNull);

      final itemAfterRemove = await (db.select(db.vaultItems)
            ..where((tbl) => tbl.id.equals('item-sol-ring')))
          .getSingle();
      final dyn2 = jsonDecode(itemAfterRemove.dynamicData) as Map<String, dynamic>;
      final history2 = (dyn2['deck_history'] as List).cast<String>();
      expect(history2.contains('Urza Commander Deck'), isFalse);
    });

    testWidgets('MultiDeckAllocationSheet displays inventory, steppers, filters and inline deck creation', (tester) async {
      // 1. Seed Decks
      await db.into(db.decks).insert(DecksCompanion.insert(
        id: 'deck-urza',
        name: 'Urza Commander Deck',
        format: 'Commander',
        tcgDomain: const drift.Value('mtg'),
        createdAt: DateTime.now(),
      ));

      await db.into(db.decks).insert(DecksCompanion.insert(
        id: 'deck-pika',
        name: 'Pikachu Electro',
        format: 'Standard',
        tcgDomain: const drift.Value('pokemon'),
        createdAt: DateTime.now(),
      ));

      // 2. Seed VaultItem
      await db.into(db.vaultItems).insert(VaultItemsCompanion.insert(
        id: 'item-sol-ring',
        collectionType: 'mtg',
        name: 'Sol Ring',
        setOrSeries: 'Commander 2021',
        imageUrl: 'https://example.com/sol.jpg',
        acquiredPrice: 2.0,
        acquiredDate: DateTime.now(),
        quantity: const drift.Value(4),
        condition: 'NM',
        currentMarketPrice: 2.50,
        lastPriceUpdate: DateTime.now(),
        dynamicData: '{}',
      ));

      final testItem = await (db.select(db.vaultItems)
            ..where((tbl) => tbl.id.equals('item-sol-ring')))
          .getSingle();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vaultDaoProvider.overrideWithValue(db.vaultDao),
            deckListProvider.overrideWith((ref) => db.select(db.decks).watch()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => MultiDeckAllocationSheet.show(context, testItem),
                  child: const Text('Open Allocation Sheet'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Allocation Sheet'));
      await tester.pumpAndSettle();

      // Verify Header & backward compatibility text
      expect(find.byKey(const Key('multi_deck_sheet_title')), findsOneWidget);
      expect(find.text('Add Card to Deck'), findsOneWidget);
      expect(find.textContaining('Sol Ring'), findsWidgets);

      // Verify Inventory metrics
      expect(find.text('4'), findsWidgets);
      expect(find.text('Available'), findsOneWidget);
      expect(find.text('In Decks'), findsOneWidget);

      // Verify both decks are listed initially
      expect(find.text('Urza Commander Deck'), findsOneWidget);
      expect(find.text('Pikachu Electro'), findsOneWidget);

      // Test Stepper [+] on Urza deck
      final incButton = find.byKey(const Key('stepper_increment_deck-urza'));
      expect(incButton, findsOneWidget);
      await tester.tap(incButton);
      await tester.pumpAndSettle();

      // Verify stepper quantity updated to 1
      final qtyFinder = find.byKey(const Key('stepper_quantity_deck-urza'));
      expect(qtyFinder, findsOneWidget);
      expect(find.descendant(of: qtyFinder, matching: find.text('1')), findsOneWidget);

      // Test Stepper [-] on Urza deck
      final decButton = find.byKey(const Key('stepper_decrement_deck-urza'));
      expect(decButton, findsOneWidget);
      await tester.tap(decButton);
      await tester.pumpAndSettle();

      expect(find.descendant(of: qtyFinder, matching: find.text('0')), findsOneWidget);

      // Test Domain Filter: Filter to Pokémon
      await tester.tap(find.text('Pokémon'));
      await tester.pumpAndSettle();

      expect(find.text('Pikachu Electro'), findsOneWidget);
      expect(find.text('Urza Commander Deck'), findsNothing);

      // Filter back to All
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();
      expect(find.text('Urza Commander Deck'), findsOneWidget);

      // Test Inline New Deck Creation
      final newDeckInput = find.byType(TextField).last;
      await tester.enterText(newDeckInput, 'Mishra Artifacts');
      await tester.pumpAndSettle();

      final createButton = find.byKey(const Key('button_create_and_add_deck'));
      expect(createButton, findsOneWidget);
      await tester.tap(createButton);
      await tester.pumpAndSettle();

      // Verify new deck appears in the list
      expect(find.text('Mishra Artifacts'), findsOneWidget);

      // Tear down widget tree cleanly and flush any internal Drift timers
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
