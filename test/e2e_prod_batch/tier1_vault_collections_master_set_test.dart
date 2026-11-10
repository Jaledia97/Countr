import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' as drift;
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/domain/models/vault_set_collection.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/screens/master_set_screen.dart';

import 'e2e_prod_batch_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Tier 1 - Feature 12: Vault Collections 3x3 Card Grid & Master Set Routing (F12.1 to F12.5)', () {
    late AppDatabase db;
    late VaultDao vaultDao;

    final testCollection = const VaultSetCollection(
      setName: 'The Lord of the Rings: Tales of Middle-earth',
      setCode: 'LTR',
      collectionType: 'mtg',
      totalCount: 3,
      ownedCount: 1,
      completionPercentage: 0.33,
      releaseDate: '2023',
    );

    setUp(() async {
      db = createE2eProdBatchTestDb();
      vaultDao = VaultDao(db);
      await (db.delete(db.vaultItems)).go();

      // Card 1: Owned (quantity 1)
      await db.into(db.vaultItems).insert(
        createTestVaultCard(
          id: 'card-ltr-one-ring',
          name: 'The One Ring',
          setOrSeries: 'LTR',
          quantity: 1,
          currentMarketPrice: 120.0,
        ),
        mode: drift.InsertMode.insertOrReplace,
      );

      // Card 2: Unowned catalog reference (quantity 0)
      await db.into(db.vaultItems).insert(
        createTestVaultCard(
          id: 'card-ltr-bowmasters',
          name: 'Orcish Bowmasters',
          setOrSeries: 'LTR',
          quantity: 0,
          currentMarketPrice: 45.0,
        ),
        mode: drift.InsertMode.insertOrReplace,
      );

      // Card 3: Another set card (should be excluded from LTR)
      await db.into(db.vaultItems).insert(
        createTestVaultCard(
          id: 'card-mh2-ragavan',
          name: 'Ragavan, Nimble Pilferer',
          setOrSeries: 'MH2',
          setCode: 'mh2',
          quantity: 2,
          currentMarketPrice: 55.0,
        ),
        mode: drift.InsertMode.insertOrReplace,
      );
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('F12.1: MasterSetScreen displays set header, set code, and owned card count ratio', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        wrapWithMaterialAndScope(
          MasterSetScreen(
            collection: testCollection,
            activeGame: 'mtg',
          ),
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(vaultDao),
          ],
        ),
      );

      // Wait for stream builder
      await tester.pumpAndSettle();

      expect(find.text('The Lord of the Rings: Tales of Middle-earth'), findsOneWidget);
      expect(find.text('Set: LTR'), findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget); // 1 owned out of 2 in LTR
      expect(find.text('cards owned'), findsOneWidget);
    });

    testWidgets('F12.2: MasterSetScreen renders cards in 3-column grid scoped strictly to set', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        wrapWithMaterialAndScope(
          MasterSetScreen(
            collection: testCollection,
            activeGame: 'mtg',
          ),
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(vaultDao),
          ],
        ),
      );

      await tester.pumpAndSettle();

      final gridFinder = find.byType(SliverGrid);
      expect(gridFinder, findsOneWidget);

      final sliverGrid = tester.widget<SliverGrid>(gridFinder);
      final delegate = sliverGrid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, equals(3));

      // LTR cards are present
      expect(find.byKey(const Key('master_set_card_card-ltr-one-ring')), findsOneWidget);
      expect(find.byKey(const Key('master_set_card_card-ltr-bowmasters')), findsOneWidget);

      // MH2 card is strictly excluded
      expect(find.byKey(const Key('master_set_card_card-mh2-ragavan')), findsNothing);
    });

    testWidgets('F12.3: MasterSetScreen renders unowned cards with grayscale and owned cards with quantity badge', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        wrapWithMaterialAndScope(
          MasterSetScreen(
            collection: testCollection,
            activeGame: 'mtg',
          ),
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(vaultDao),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Unowned card has grayscale filter and 'Missing' badge
      expect(find.byKey(const Key('master_set_grayscale_card-ltr-bowmasters')), findsOneWidget);
      expect(find.text('Missing'), findsOneWidget);

      // Owned card does not have grayscale and shows quantity
      expect(find.byKey(const Key('master_set_grayscale_card-ltr-one-ring')), findsNothing);
      expect(find.text('x1'), findsOneWidget);
    });

    testWidgets('F12.4: Tapping any card in MasterSetScreen opens CardDetailSheet without error', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        wrapWithMaterialAndScope(
          MasterSetScreen(
            collection: testCollection,
            activeGame: 'mtg',
          ),
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(vaultDao),
          ],
        ),
      );

      await tester.pumpAndSettle();

      final ringFinder = find.byKey(const Key('master_set_card_card-ltr-one-ring'));
      expect(ringFinder, findsOneWidget);

      await tester.tap(ringFinder);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('F12.5: Search field in MasterSetScreen dynamically filters cards in 3x3 grid by name', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        wrapWithMaterialAndScope(
          MasterSetScreen(
            collection: testCollection,
            activeGame: 'mtg',
          ),
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(vaultDao),
          ],
        ),
      );

      await tester.pumpAndSettle();

      final searchFieldFinder = find.byKey(const Key('master_set_search_field'));
      expect(searchFieldFinder, findsOneWidget);

      // Search for 'Bowmasters'
      await tester.enterText(searchFieldFinder, 'Bowmasters');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('master_set_card_card-ltr-bowmasters')), findsOneWidget);
      expect(find.byKey(const Key('master_set_card_card-ltr-one-ring')), findsNothing);

      // Clear search
      await tester.enterText(searchFieldFinder, '');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('master_set_card_card-ltr-bowmasters')), findsOneWidget);
      expect(find.byKey(const Key('master_set_card_card-ltr-one-ring')), findsOneWidget);
    });
  });
}
