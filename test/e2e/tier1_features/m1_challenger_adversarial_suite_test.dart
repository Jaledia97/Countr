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

  group('M1 Adversarial Challenge: Subtab Hiding Stress & Invariants', () {
    testWidgets('C1.1: Rapid toggling between Owned and All Cards does not crash, throw key collisions, or leak state', (tester) async {
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

      final allCardsChip = find.byKey(const Key('vault_filter_chip_catalog_(ref)'));
      final ownedChip = find.byKey(const Key('vault_filter_chip_owned'));

      expect(allCardsChip, findsOneWidget);
      expect(ownedChip, findsOneWidget);

      // Rapidly toggle 20 times with partial frame pumps
      for (int i = 0; i < 20; i++) {
        if (i % 2 == 0) {
          await tester.tap(allCardsChip);
        } else {
          await tester.tap(ownedChip);
        }
        await tester.pump(const Duration(milliseconds: 30));
      }

      await tester.pumpAndSettle();

      // Ensure stable state after oscillation
      expect(container.read(vaultShowCatalogProvider), isFalse);
      expect(find.byKey(const Key('vault_view_singles_toggle')), findsOneWidget);
      expect(find.byKey(const Key('vault_view_binders_toggle')), findsOneWidget);
      expect(find.byKey(const Key('vault_view_collections_toggle')), findsOneWidget);
    });

    testWidgets('C1.2: Narrow viewport (320x568) does not suffer RenderFlex overflows during subtab collapse/restore', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
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

      expect(tester.takeException(), isNull);

      // Switch to All Cards
      final allCardsChip = find.byKey(const Key('vault_filter_chip_catalog_(ref)'));
      await tester.tap(allCardsChip);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Switch back to Owned
      final ownedChip = find.byKey(const Key('vault_filter_chip_owned'));
      await tester.tap(ownedChip);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('M1 Adversarial Challenge: MasterSetScreen 3x3 Grid & In-Set Search', () {
    testWidgets('C2.1: MasterSetScreen renders 3-column grid with completion metrics and unowned grayscale filter', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Vintage Masters collection has 2 cards:
      // c-lotus (unowned, qty 0)
      // c-mox-sapphire (owned, qty 1)
      const collection = VaultSetCollection(
        setName: 'Vintage Masters',
        setCode: 'vma',
        collectionType: 'mtg',
        totalCount: 2,
        ownedCount: 1,
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
              collection: collection,
              activeGame: 'mtg',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check header summary metrics
      expect(find.text('1 / 2'), findsOneWidget);
      expect(find.text('50.0% complete'), findsOneWidget);

      // Verify 3-column grid structure
      final sliverGridFinder = find.byType(SliverGrid);
      expect(sliverGridFinder, findsOneWidget);

      final sliverGrid = tester.widget<SliverGrid>(sliverGridFinder);
      final delegate = sliverGrid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, equals(3));
      expect(delegate.childAspectRatio, equals(0.68));

      // Black Lotus is unowned: must have grayscale filter and 'Missing' badge
      expect(find.byKey(const Key('master_set_grayscale_c-lotus')), findsOneWidget);
      expect(find.text('Missing'), findsOneWidget);

      // Mox Sapphire is owned: must have 'x1' badge and no grayscale
      expect(find.byKey(const Key('master_set_grayscale_c-mox-sapphire')), findsNothing);
      expect(find.text('x1'), findsOneWidget);
    });

    testWidgets('C2.2: MasterSetScreen in-set filter chips (Owned vs Missing vs All) filter cleanly', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const collection = VaultSetCollection(
        setName: 'Vintage Masters',
        setCode: 'vma',
        collectionType: 'mtg',
        totalCount: 2,
        ownedCount: 1,
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
              collection: collection,
              activeGame: 'mtg',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Filter by "Owned"
      final ownedChip = find.textContaining('Owned (1)');
      await tester.tap(ownedChip);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('master_set_card_c-mox-sapphire')), findsOneWidget);
      expect(find.byKey(const Key('master_set_card_c-lotus')), findsNothing);

      // Filter by "Missing"
      final missingChip = find.textContaining('Missing (1)');
      await tester.tap(missingChip);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('master_set_card_c-lotus')), findsOneWidget);
      expect(find.byKey(const Key('master_set_card_c-mox-sapphire')), findsNothing);

      // Filter by "All"
      final allChip = find.textContaining('All (2)');
      await tester.tap(allChip);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('master_set_card_c-lotus')), findsOneWidget);
      expect(find.byKey(const Key('master_set_card_c-mox-sapphire')), findsOneWidget);
    });

    testWidgets('C2.3: In-set search matches by collector number (#232) and card name', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const collection = VaultSetCollection(
        setName: 'Vintage Masters',
        setCode: 'vma',
        collectionType: 'mtg',
        totalCount: 2,
        ownedCount: 1,
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
              collection: collection,
              activeGame: 'mtg',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);

      // Search by collector number 232 (Black Lotus)
      await tester.enterText(searchField, '232');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('master_set_card_c-lotus')), findsOneWidget);
      expect(find.byKey(const Key('master_set_card_c-mox-sapphire')), findsNothing);

      // Search by name "Sapphire"
      await tester.enterText(searchField, 'sapphire');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('master_set_card_c-mox-sapphire')), findsOneWidget);
      expect(find.byKey(const Key('master_set_card_c-lotus')), findsNothing);

      // Search non-existent query
      await tester.enterText(searchField, 'xyzNonExistent');
      await tester.pumpAndSettle();

      expect(find.text('No cards match your filter criteria'), findsOneWidget);
    });
  });

  group('M1 Adversarial Challenge: Card Details Deep Hydration & Multi-Face Flip', () {
    testWidgets('C3.1: CardDetailSheet hydrates dynamically from SQLite when instantiated with cardId alone', (tester) async {
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

      // Mount CardDetailSheet with only cardId: 'c-lotus'
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: CardDetailSheet(cardId: 'c-lotus'),
            ),
          ),
        ),
      );

      // Post-frame hydration executes
      await tester.pump();
      await tester.pumpAndSettle();

      // Card Details should have hydrated Black Lotus
      expect(find.text('Black Lotus'), findsWidgets);
      expect(find.text('Vintage Masters'), findsWidgets);
      expect(find.textContaining('Sacrifice Black Lotus'), findsWidgets);
    });

    testWidgets('C3.2: CardDetailSheet hydrates dynamically when given a stub VaultItem with empty dynamicData', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final stubBolt = VaultItem(
        id: 'c-bolt',
        collectionType: 'mtg',
        name: 'Lightning Bolt',
        setOrSeries: '',
        imageUrl: '',
        acquiredPrice: 0.0,
        acquiredDate: DateTime.now(),
        quantity: 1,
        condition: 'NM',
        isGraded: false,
        isAltered: false,
        isMisprint: false,
        isSigned: false,
        currentMarketPrice: 0.0,
        lastPriceUpdate: DateTime.now(),
        dynamicData: '{}',
        isDeleted: false,
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
          child: MaterialApp(
            home: Scaffold(
              body: CardDetailSheet(item: stubBolt),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      // SQLite hydration should populate Magic 2010 set name and oracle text
      expect(find.text('Magic 2010'), findsWidgets);
      expect(find.textContaining('deals 3 damage'), findsWidgets);
    });

    testWidgets('C3.3: DFC card allows 2-way face flipping, single-faced card omits flip button', (tester) async {
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

      // 1. DFC: Nicol Bolas
      final nicol = (await dao.getItemById('c-nicol-bolas'))!;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: CardDetailSheet(item: nicol),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final flipButton = find.byTooltip('Flip card');
      expect(flipButton, findsOneWidget);

      // Flip to back face
      await tester.tap(flipButton);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.textContaining('Nicol Bolas, the Arisen'), findsWidgets);

      // Flip back to front face
      await tester.tap(flipButton);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.textContaining('Nicol Bolas, the Ravager'), findsWidgets);

      // 2. Single-faced card: Sol Ring
      final solRing = (await dao.getItemById('c-sol-ring'))!;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: CardDetailSheet(item: solRing),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Flip card'), findsNothing);
    });
  });

  group('M1 Adversarial Challenge: Atomic Binder Upsert & Transaction Integrity', () {
    test('C4.1: Assigning catalog cards to binder promotes unowned to qty 1 and preserves owned quantities', () async {
      // Setup:
      // c-lotus: quantity = 0 (unowned)
      // c-bolt: quantity = 4 (owned)
      final lotusBefore = (await dao.getItemById('c-lotus'))!;
      final boltBefore = (await dao.getItemById('c-bolt'))!;
      expect(lotusBefore.quantity, equals(0));
      expect(boltBefore.quantity, equals(4));

      // Atomically assign both to 'trade-binder'
      final count = await dao.assignItemsToBinder(['c-lotus', 'c-bolt'], 'trade-binder');
      expect(count, equals(2));

      final lotusAfter = (await dao.getItemById('c-lotus'))!;
      final boltAfter = (await dao.getItemById('c-bolt'))!;

      expect(lotusAfter.quantity, equals(1), reason: 'Unowned card must be promoted to quantity 1');
      expect(lotusAfter.primaryBinderId, equals('trade-binder'));
      expect(lotusAfter.acquiredPrice, equals(5000.0));

      expect(boltAfter.quantity, equals(4), reason: 'Owned card quantity must be preserved');
      expect(boltAfter.primaryBinderId, equals('trade-binder'));
    });

    test('C4.2: Missing item in SQLite with fallbackCatalogItems is inserted atomically with quantity 1', () async {
      const fallbackId = 'c-missing-catalog-item';
      final fallbackCard = createE2ETestCard(
        id: fallbackId,
        name: 'Mox Diamond',
        setOrSeries: 'Stronghold',
        setCode: 'sth',
        currentMarketPrice: 650.0,
        quantity: 0,
      );

      // Confirm card does not exist in SQLite yet
      final checkBefore = await dao.getItemById(fallbackId);
      expect(checkBefore, isNull);

      // Assign to binder with fallback map
      final count = await dao.assignItemsToBinder(
        [fallbackId],
        'power-nine',
        fallbackCatalogItems: {fallbackId: fallbackCard},
      );
      expect(count, equals(1));

      // Verify card was inserted atomically with quantity 1 and binder power-nine
      final checkAfter = await dao.getItemById(fallbackId);
      expect(checkAfter, isNotNull);
      expect(checkAfter!.name, equals('Mox Diamond'));
      expect(checkAfter.quantity, equals(1));
      expect(checkAfter.primaryBinderId, equals('power-nine'));
      expect(checkAfter.acquiredPrice, equals(650.0));
      expect(checkAfter.protectionStatus, equals('Sleeved'));
    });

    test('C4.3: watchItemsByBinder stream immediately reflects atomically upserted cards', () async {
      final binderStream = dao.watchItemsByBinder('edh-staples');
      final initial = await binderStream.first;
      expect(initial.map((c) => c.id), contains('c-sol-ring'));

      // Add unowned Counterspell (quantity 0) to edh-staples
      await dao.assignItemsToBinder(['c-counterspell'], 'edh-staples');

      final updated = await binderStream.first;
      expect(updated.map((c) => c.id), containsAll(['c-sol-ring', 'c-counterspell']));

      final counterspell = updated.firstWhere((c) => c.id == 'c-counterspell');
      expect(counterspell.quantity, equals(1));
      expect(counterspell.primaryBinderId, equals('edh-staples'));
    });
  });
}
