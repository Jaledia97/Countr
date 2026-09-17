import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/command_center/presentation/widgets/collections_accordion.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/screens/vault_screen.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_card.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_tile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  VaultItem createTestCard({
    required String id,
    required String name,
    required int quantity,
    String collectionType = 'mtg',
    double currentMarketPrice = 10.0,
    double acquiredPrice = 5.0,
  }) {
    return VaultItem(
      id: id,
      collectionType: collectionType,
      name: name,
      setOrSeries: 'Test Set',
      imageUrl: '',
      acquiredPrice: acquiredPrice,
      acquiredDate: DateTime.now(),
      quantity: quantity,
      condition: 'NM',
      isGraded: false,
      personalNotes: '',
      currentMarketPrice: currentMarketPrice,
      lastPriceUpdate: DateTime.now(),
      dynamicData: '{}',
      primaryBinderId: null,
      isAltered: false,
      isMisprint: false,
      isSigned: false,
    );
  }

  group('Duplicate Counter Badge Tests', () {
    testWidgets('VaultItemCard displays duplicate badge when quantity > 1',
        (WidgetTester tester) async {
      final cardWithDuplicates = createTestCard(
        id: 'dup-card-1',
        name: 'Sol Ring',
        quantity: 3,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VaultItemCard(item: cardWithDuplicates),
          ),
        ),
      );

      // Verify the 3x duplicate badge is displayed
      expect(find.byKey(const Key('vault_item_duplicate_badge_dup-card-1')),
          findsOneWidget);
      expect(find.text('3x'), findsOneWidget);
    });

    testWidgets('VaultItemCard does NOT display duplicate badge when quantity == 1',
        (WidgetTester tester) async {
      final singleCard = createTestCard(
        id: 'single-card-1',
        name: 'The One Ring',
        quantity: 1,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VaultItemCard(item: singleCard),
          ),
        ),
      );

      // Verify no duplicate badge
      expect(find.byKey(const Key('vault_item_duplicate_badge_single-card-1')),
          findsNothing);
      expect(find.text('1x'), findsNothing);
    });

    testWidgets('VaultItemTile displays duplicate badge when quantity > 1',
        (WidgetTester tester) async {
      final cardWithDuplicates = createTestCard(
        id: 'dup-tile-1',
        name: 'Black Lotus',
        quantity: 4,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 300,
              child: VaultItemTile(item: cardWithDuplicates),
            ),
          ),
        ),
      );

      // Verify the 4x duplicate badge is displayed
      expect(find.byKey(const Key('vault_tile_duplicate_badge_dup-tile-1')),
          findsOneWidget);
      expect(find.text('4x'), findsOneWidget);
    });

    testWidgets('VaultItemTile does NOT display duplicate badge when quantity == 1',
        (WidgetTester tester) async {
      final singleCard = createTestCard(
        id: 'single-tile-1',
        name: 'Mox Pearl',
        quantity: 1,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 300,
              child: VaultItemTile(item: singleCard),
            ),
          ),
        ),
      );

      // Verify no duplicate badge for single copy
      expect(find.byKey(const Key('vault_tile_duplicate_badge_single-tile-1')),
          findsNothing);
      expect(find.text('1x'), findsNothing);
    });
  });

  group('VaultScreen and Drawer Alignment Tests', () {
    late AppDatabase db;
    late VaultDao dao;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      dao = db.vaultDao;
      await dao.clearAllItems();
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets(
        'VaultScreen clearly aligns total item count with visible duplicate badges',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Insert:
      // 1x The One Ring (quantity: 1)
      // 2x Sol Ring (quantity: 2)
      // Total cards displayed: 2. Total items tracked: 3.
      await db.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'card-one-ring',
              collectionType: 'mtg',
              name: 'The One Ring',
              setOrSeries: 'Tales of Middle-earth',
              imageUrl: '',
              acquiredPrice: 15.0,
              acquiredDate: DateTime.now(),
              quantity: const drift.Value(1),
              condition: 'NM',
              currentMarketPrice: 45.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: '{}',
            ),
          );

      await db.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'card-sol-ring',
              collectionType: 'mtg',
              name: 'Sol Ring',
              setOrSeries: 'Commander',
              imageUrl: '',
              acquiredPrice: 2.0,
              acquiredDate: DateTime.now(),
              quantity: const drift.Value(2),
              condition: 'NM',
              currentMarketPrice: 2.5,
              lastPriceUpdate: DateTime.now(),
              dynamicData: '{}',
            ),
          );

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(dao),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: VaultScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Total Tracked Items must accurately reflect the sum of copies (1 + 2 = 3)
      expect(find.text('Total Tracked Items: 3'), findsOneWidget);

      // Two cards rendered
      expect(find.byType(VaultItemCard), findsNWidgets(2));

      // Duplicate badge on Sol Ring (2x)
      expect(find.byKey(const Key('vault_item_duplicate_badge_card-sol-ring')),
          findsOneWidget);
      expect(find.text('2x'), findsOneWidget);

      // No duplicate badge on The One Ring
      expect(find.byKey(const Key('vault_item_duplicate_badge_card-one-ring')),
          findsNothing);
    });

    testWidgets('CollectionsAccordion renders real reactive SQLite collection counts',
        (WidgetTester tester) async {
      // Seed 1 MTG card, 1 Pokemon card, 1 Comic, 1 Sports
      await dao.seedDatabase();

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(dao),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: CollectionsAccordion(
                onGameSelected: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify real counts from seed database:
      // Seed contains 4 cards total (1 MTG, 1 Pokemon, 1 Comic, 1 Sports Card)
      expect(find.text('1 Card'), findsNWidgets(3)); // MTG, Pokemon, Sports
      expect(find.text('1 Issue'), findsOneWidget); // Comic
      expect(find.text('4 Items'), findsOneWidget); // All Collections

      // Legacy hardcoded dummy counts must NOT exist anywhere!
      expect(find.text('524 Items'), findsNothing);
      expect(find.text('210 Cards'), findsNothing);
      expect(find.text('185 Cards'), findsNothing);
      expect(find.text('129 Issues'), findsNothing);
      expect(find.text('98 Cards'), findsNothing);
    });
  });
}
