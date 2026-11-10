import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/domain/models/vault_set_collection.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/screens/master_set_screen.dart';
import 'package:countr/features/vault/presentation/screens/vault_screen.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';
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

  group('M1 Edge Cases & Failure Modes Challenge', () {
    testWidgets('E1: Subtab view mode toggling and All Cards mode collapse/restore transitions cleanly', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(dao),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
          vaultShowCatalogProvider.overrideWith((ref) => false),
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

      // Start in Singles mode
      expect(container.read(vaultViewModeProvider), equals(VaultViewMode.allVault));

      // Switch to Binders via subtab toggle
      await tester.tap(find.byKey(const Key('vault_view_binders_toggle')));
      await tester.pumpAndSettle();
      expect(container.read(vaultViewModeProvider), equals(VaultViewMode.binders));

      // Switch back to Singles
      await tester.tap(find.byKey(const Key('vault_view_singles_toggle')));
      await tester.pumpAndSettle();
      expect(container.read(vaultViewModeProvider), equals(VaultViewMode.allVault));

      // Toggle to All Cards
      final allCardsChip = find.byKey(const Key('vault_filter_chip_catalog_(ref)'));
      await tester.tap(allCardsChip);
      await tester.pumpAndSettle();

      expect(container.read(vaultShowCatalogProvider), isTrue);

      // Verify subtab opacity is 0.0 in All Cards mode
      final animatedOpacityFinder = find.byWidgetPredicate(
        (w) => w is AnimatedOpacity && w.opacity == 0.0 && w.duration == const Duration(milliseconds: 200),
      );
      expect(animatedOpacityFinder, findsOneWidget);

      // Toggle back to Owned
      final ownedChip = find.byKey(const Key('vault_filter_chip_owned'));
      await tester.tap(ownedChip);
      await tester.pumpAndSettle();

      expect(container.read(vaultShowCatalogProvider), isFalse);

      // Verify subtab opacity restored to 1.0
      final restoredOpacityFinder = find.byWidgetPredicate(
        (w) => w is AnimatedOpacity && w.opacity == 1.0 && w.duration == const Duration(milliseconds: 200),
      );
      expect(restoredOpacityFinder, findsOneWidget);
    });

    testWidgets('E2: CardDetailSheet handles nonexistent card ID without unhandled crash', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

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
            home: Scaffold(
              body: CardDetailSheet(cardId: 'nonexistent-uuid-999'),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      // No unhandled Flutter exception occurred
      expect(tester.takeException(), isNull);
    });

    testWidgets('E3: CardDetailSheet gracefully handles card with malformed JSON dynamicData', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final brokenJsonCard = VaultItem(
        id: 'c-broken-syntax',
        collectionType: 'mtg',
        name: 'Glitched Entity',
        setOrSeries: 'Corrupted Set',
        imageUrl: '',
        acquiredPrice: 10.0,
        acquiredDate: DateTime.now(),
        quantity: 1,
        condition: 'NM',
        isGraded: false,
        isAltered: false,
        isMisprint: false,
        isSigned: false,
        currentMarketPrice: 10.0,
        lastPriceUpdate: DateTime.now(),
        dynamicData: '{{{{malformed json content:::',
        isDeleted: false,
      );
      await insertTestCards(dao, [brokenJsonCard]);

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
          child: MaterialApp(
            home: Scaffold(
              body: CardDetailSheet(item: brokenJsonCard),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Ensure no crash occurred and card name is safely displayed
      expect(tester.takeException(), isNull);
      expect(find.text('Glitched Entity'), findsWidgets);
    });

    testWidgets('E4: MasterSetScreen with empty set (0 cards) renders cleanly with 0% progress and empty message', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const emptyCollection = VaultSetCollection(
        setName: 'Empty Set',
        setCode: 'emp',
        collectionType: 'mtg',
        totalCount: 0,
        ownedCount: 0,
        completionPercentage: 0.0,
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
            home: MasterSetScreen(
              collection: emptyCollection,
              activeGame: 'mtg',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('0 / 0'), findsOneWidget);
      expect(find.text('0.0% complete'), findsOneWidget);
      expect(find.text('No cards match your filter criteria'), findsOneWidget);
    });

    testWidgets('E5: MasterSetScreen with 60 cards renders 3-column grid without lag or overflow', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Generate 60 cards in "Large Set"
      final largeSetCards = List.generate(60, (i) {
        return createE2ETestCard(
          id: 'large-card-$i',
          name: 'Card Number $i',
          setOrSeries: 'Large Set',
          setCode: 'lgs',
          collectorNumber: '${i + 1}',
          quantity: i < 30 ? 1 : 0, // 30 owned, 30 unowned
          currentMarketPrice: 5.0,
        );
      });
      await insertTestCards(dao, largeSetCards);

      const largeCollection = VaultSetCollection(
        setName: 'Large Set',
        setCode: 'lgs',
        collectionType: 'mtg',
        totalCount: 60,
        ownedCount: 30,
        completionPercentage: 0.5,
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
            home: MasterSetScreen(
              collection: largeCollection,
              activeGame: 'mtg',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('30 / 60'), findsOneWidget);
      expect(find.text('50.0% complete'), findsOneWidget);

      // Verify grid items
      expect(find.byType(SliverGrid), findsOneWidget);
    });

    test('E6: Concurrent assignItemsToBinder calls serialize properly without deadlocks', () async {
      // Create 4 distinct cards
      final cards = List.generate(4, (i) {
        return createE2ETestCard(
          id: 'c-concurrent-$i',
          name: 'Concurrent Card $i',
          quantity: 0,
        );
      });
      await insertTestCards(dao, cards);

      // Run 2 concurrent assignments
      final future1 = dao.assignItemsToBinder(['c-concurrent-0', 'c-concurrent-1'], 'power-nine');
      final future2 = dao.assignItemsToBinder(['c-concurrent-2', 'c-concurrent-3'], 'edh-staples');

      final results = await Future.wait([future1, future2]);

      expect(results[0], equals(2));
      expect(results[1], equals(2));

      final c0 = (await dao.getItemById('c-concurrent-0'))!;
      final c2 = (await dao.getItemById('c-concurrent-2'))!;

      expect(c0.quantity, equals(1));
      expect(c0.primaryBinderId, equals('power-nine'));

      expect(c2.quantity, equals(1));
      expect(c2.primaryBinderId, equals('edh-staples'));
    });
  });
}
