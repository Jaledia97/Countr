import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/screens/vault_screen.dart';
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

  group('Tier 1 - Feature 4: Subtab Hiding in All Cards Mode & View Switching', () {
    testWidgets('F4.1: Subtab toggle bar renders Singles, Binders, and Collections in personal Vault', (tester) async {
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

      // Primary view switcher buttons must be present in personal vault
      expect(find.byKey(const Key('vault_view_singles_toggle')), findsOneWidget);
      expect(find.byKey(const Key('vault_view_binders_toggle')), findsOneWidget);
      expect(find.byKey(const Key('vault_view_collections_toggle')), findsOneWidget);
    });

    testWidgets('F4.2: Tapping Binders and Collections subtabs updates vaultViewModeProvider', (tester) async {
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

      // Tap Binders toggle
      await tester.tap(find.byKey(const Key('vault_view_binders_toggle')));
      await tester.pumpAndSettle();
      expect(container.read(vaultViewModeProvider), equals(VaultViewMode.binders));

      // Tap Collections toggle
      await tester.tap(find.byKey(const Key('vault_view_collections_toggle')));
      await tester.pumpAndSettle();
      expect(container.read(vaultViewModeProvider), equals(VaultViewMode.collections));
    });

    testWidgets('F4.3: Switching to All Cards mode activates vaultShowCatalogProvider', (tester) async {
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

      // Find and tap "All Cards" filter chip
      final allCardsChip = find.byKey(const Key('vault_filter_chip_catalog_(ref)'));
      expect(allCardsChip, findsOneWidget);

      await tester.tap(allCardsChip);
      await tester.pumpAndSettle();

      expect(container.read(vaultShowCatalogProvider), isTrue);
    });

    testWidgets('F4.4: Tapping Owned chip returns state from All Cards back to personal Vault', (tester) async {
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
          vaultShowCatalogProvider.overrideWith((ref) => true),
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

      expect(container.read(vaultShowCatalogProvider), isTrue);

      // Tap "Owned" filter chip
      final ownedChip = find.byKey(const Key('vault_filter_chip_owned'));
      expect(ownedChip, findsOneWidget);

      await tester.tap(ownedChip);
      await tester.pumpAndSettle();

      expect(container.read(vaultShowCatalogProvider), isFalse);
    });

    test('F4.5: Catalog query in All Cards mode includes both owned and unowned reference cards', () async {
      // In All Cards mode (onlyOwned = false)
      final allCards = await dao.getItemsByCollection('mtg', onlyOwned: false);
      final ownedCards = allCards.where((c) => c.quantity > 0).toList();
      final unownedCards = allCards.where((c) => c.quantity == 0).toList();

      expect(ownedCards, isNotEmpty, reason: 'Owned cards must appear in All Cards view');
      expect(unownedCards, isNotEmpty, reason: 'Unowned reference catalog cards must appear in All Cards view');

      // Specifically check key cards
      expect(ownedCards.any((c) => c.name == 'Sol Ring'), isTrue);
      expect(unownedCards.any((c) => c.name == 'Black Lotus'), isTrue);
      expect(unownedCards.any((c) => c.name == 'Counterspell'), isTrue);
    });
  });
}
