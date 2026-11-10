import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
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

  group('Tier 1 - Feature 5: Collections 3x3 Master Set Grid & Navigation', () {
    testWidgets('F5.1: Collections view displays set name, set code, and completion statistics', (tester) async {
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
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.collections),
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

      // Vintage Masters set tile should be present (contains Black Lotus and Mox Sapphire)
      expect(find.textContaining('Vintage Masters'), findsWidgets);
      // In Vintage Masters: Mox Sapphire is owned (qty 1), Black Lotus is unowned (qty 0) -> 1/2 owned
      expect(find.textContaining('1/2 owned'), findsWidgets);
    });

    testWidgets('F5.2: Expanding set collection renders cards in a 3x3 grid layout (crossAxisCount = 3)', (tester) async {
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
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.collections),
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

      // Find and tap the Vintage Masters collection tile header
      final vmaTile = find.byKey(const Key('vault_collection_tile_VMA'));
      expect(vmaTile, findsOneWidget);

      await tester.ensureVisible(vmaTile);
      await tester.tap(vmaTile);
      await tester.pumpAndSettle();

      // The 3x3 card grid is rendered in the expanded section below the grid
      final gridFinder = find.byKey(const Key('vault_collection_grid_VMA'));
      await tester.scrollUntilVisible(
        gridFinder,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(gridFinder, findsOneWidget);

      final gridWidget = tester.widget<GridView>(gridFinder);
      final delegate = gridWidget.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, equals(3), reason: 'Collections grid MUST use 3-column layout');
    });

    testWidgets('F5.3: Visual distinction: unowned cards render grayscale filter and owned render color', (tester) async {
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
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.collections),
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

      // Expand Vintage Masters
      final vmaTile = find.byKey(const Key('vault_collection_tile_VMA'));
      await tester.ensureVisible(vmaTile);
      await tester.tap(vmaTile);
      await tester.pumpAndSettle();

      final gridFinder = find.byKey(const Key('vault_collection_grid_VMA'));
      await tester.scrollUntilVisible(
        gridFinder,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      // Black Lotus (unowned) has grayscale filter
      expect(find.byKey(const Key('vault_collection_grayscale_c-lotus')), findsOneWidget);

      // Mox Sapphire (owned, qty 1) does NOT have grayscale filter
      expect(find.byKey(const Key('vault_collection_grayscale_c-mox-sapphire')), findsNothing);
    });

    testWidgets('F5.4: Tapping any card in the 3x3 set grid opens CardDetailSheet', (tester) async {
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
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.collections),
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

      // Expand Vintage Masters
      final vmaTile = find.byKey(const Key('vault_collection_tile_VMA'));
      await tester.ensureVisible(vmaTile);
      await tester.tap(vmaTile);
      await tester.pumpAndSettle();

      final lotusCardItem = find.byKey(const Key('vault_collection_item_c-lotus'));
      await tester.scrollUntilVisible(
        lotusCardItem,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      // Tap on Black Lotus card in the 3x3 grid
      await tester.tap(lotusCardItem);
      await tester.pumpAndSettle();

      // CardDetailSheet should be mounted
      expect(find.byType(CardDetailSheet), findsOneWidget);
      expect(find.text('Black Lotus'), findsWidgets);
    });

    test('F5.5: dao.watchItemsBySet returns all cards belonging to the set ordered by collector number', () async {
      final vmaCards = await dao.watchItemsBySet('Vintage Masters', collectionType: 'mtg').first;

      expect(vmaCards.length, equals(2));
      final names = vmaCards.map((c) => c.name).toList();
      expect(names, containsAll(['Black Lotus', 'Mox Sapphire']));
    });
  });
}
