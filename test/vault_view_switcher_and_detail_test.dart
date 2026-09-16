import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/screens/vault_screen.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_card.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_tile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.vaultDao.clearAllItems();

    // Insert 1 owned item
    await db.vaultDao.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'owned-card-1',
            collectionType: 'mtg',
            name: 'The One Ring',
            setOrSeries: 'Tales of Middle-earth',
            imageUrl:
                'https://cards.scryfall.io/large/front/7/8/78038b95-30f2-4e4b-972f-04cfa65c275a.jpg',
            acquiredPrice: 45.0,
            acquiredDate: DateTime(2023, 6, 23),
            quantity: const drift.Value(1),
            condition: 'NM',
            isGraded: const drift.Value(false),
            currentMarketPrice: 110.0,
            lastPriceUpdate: DateTime.now(),
            dynamicData:
                '{"oracle_text":"Indestructible\\nWhen The One Ring enters the battlefield, if you cast it, you gain protection from everything until your next turn.","rarity":"mythic","legalities":{"standard":"not_legal","modern":"legal","commander":"legal","legacy":"legal"}}',
            personalNotes: const drift.Value('Pulled from gift bundle.'),
          ),
        );

    // Insert 1 unowned catalog item
    await db.vaultDao.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'catalog-card-1',
            collectionType: 'mtg',
            name: 'Sol Ring',
            setOrSeries: 'Commander Masters',
            imageUrl:
                'https://cards.scryfall.io/large/front/4/c/4cbc362e-6a52-4753-9619-75f850d97960.jpg',
            acquiredPrice: 0.0,
            acquiredDate: DateTime(2023, 8, 4),
            quantity: const drift.Value(0),
            condition: 'NM',
            isGraded: const drift.Value(false),
            currentMarketPrice: 2.25,
            lastPriceUpdate: DateTime.now(),
            dynamicData:
                '{"oracle_text":"{T}: Add {C}{C}.","rarity":"uncommon","legalities":{"commander":"legal","vintage":"restricted"}}',
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  Widget createTestWidget({required ProviderContainer container}) {
    return UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: VaultScreen(),
      ),
    );
  }

  group('Vault View Switcher (List vs Grid)', () {
    testWidgets('Toggles between List and Tile Grid views in VaultScreen', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
        ],
      );

      await tester.pumpWidget(createTestWidget(container: container));
      await tester.pumpAndSettle();

      // Initially in List view
      expect(find.byType(VaultItemCard), findsOneWidget);
      expect(find.byType(VaultItemTile), findsNothing);

      // Tap 'Tiles' button
      await tester.ensureVisible(find.byKey(const Key('vault_layout_grid_button')));
      await tester.tap(find.byKey(const Key('vault_layout_grid_button')));
      await tester.pumpAndSettle();

      // Now in Grid/Tile view
      expect(container.read(cardDisplayLayoutProvider), equals(CardDisplayLayout.grid));
      expect(find.byType(VaultItemTile), findsOneWidget);
      expect(find.byType(VaultItemCard), findsNothing);

      // Tap 'List' button
      await tester.ensureVisible(find.byKey(const Key('vault_layout_list_button')));
      await tester.tap(find.byKey(const Key('vault_layout_list_button')));
      await tester.pumpAndSettle();

      // Switches back to List view
      expect(container.read(cardDisplayLayoutProvider), equals(CardDisplayLayout.list));
      expect(find.byType(VaultItemCard), findsOneWidget);
      expect(find.byType(VaultItemTile), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });
  });

  group('CardDetailSheet Modal Tests', () {
    testWidgets('Tapping card tile in grid view opens CardDetailSheet with full data', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
          cardDisplayLayoutProvider.overrideWith((ref) => CardDisplayLayout.grid),
        ],
      );

      await tester.pumpWidget(createTestWidget(container: container));
      await tester.pumpAndSettle();

      // Find the card tile
      expect(find.byType(VaultItemTile), findsOneWidget);

      // Tap card tile to open modal sheet
      await tester.tap(find.byType(VaultItemTile));
      await tester.pumpAndSettle();

      // CardDetailSheet is rendered
      expect(find.byType(CardDetailSheet), findsOneWidget);
      expect(find.text('The One Ring'), findsWidgets);
      expect(find.text('Tales of Middle-earth'), findsWidgets);

      // Oracle text is displayed
      expect(find.textContaining('protection from everything'), findsOneWidget);

      // Format legalities chip
      expect(find.textContaining('Modern: Legal'), findsOneWidget);
      expect(find.textContaining('Commander: Legal'), findsOneWidget);

      // Deck tags and notes
      expect(find.text('No deck history recorded yet.'), findsOneWidget);
      expect(find.text('Pulled from gift bundle.'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('CardDetailSheet displays Add to Vault action for unowned catalog card', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final catalogItem = await (db.select(db.vaultItems)..where((t) => t.id.equals('catalog-card-1'))).getSingle();

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Builder(
              builder: (ctx) {
                return Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () => CardDetailSheet.show(ctx, catalogItem),
                      child: const Text('Open Sheet'),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Verify unowned card action button
      expect(find.text('Add to Vault / Inbox'), findsOneWidget);

      // Tap Add to Vault / Inbox
      await tester.tap(find.text('Add to Vault / Inbox'));
      await tester.pumpAndSettle();

      // Database should now have quantity = 1
      final updated = await (db.select(db.vaultItems)..where((t) => t.id.equals('catalog-card-1'))).getSingle();
      expect(updated.quantity, equals(1));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });
  });
}
