import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/vault/domain/models/vault_set_collection.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/screens/vault_screen.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';
import 'package:countr/features/vault/presentation/widgets/vault_collection_view_sliver.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.vaultDao.clearAllItems();

    // 1. Insert cards for set: "Tales of Middle-earth" (code: 'LTR')
    // Card 1: Owned (quantity = 1, collector_number = 1)
    await db.vaultDao.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'ltr-card-1',
            collectionType: 'mtg',
            name: 'Frodo, Sauron\'s Bane',
            setOrSeries: 'Tales of Middle-earth',
            imageUrl: 'https://cards.scryfall.io/large/front/f/r/frodo.jpg',
            acquiredPrice: 5.0,
            acquiredDate: DateTime(2023, 6, 23),
            quantity: const drift.Value(1),
            condition: 'NM',
            isGraded: const drift.Value(false),
            currentMarketPrice: 8.50,
            lastPriceUpdate: DateTime.now(),
            dynamicData: jsonEncode({
              'set': 'ltr',
              'set_code': 'ltr',
              'collector_number': '1',
              'rarity': 'rare',
            }),
          ),
        );

    // Card 2: Unowned catalog reference (quantity = 0, collector_number = 2)
    await db.vaultDao.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'ltr-card-2',
            collectionType: 'mtg',
            name: 'The One Ring',
            setOrSeries: 'Tales of Middle-earth',
            imageUrl: 'https://cards.scryfall.io/large/front/t/h/the_one_ring.jpg',
            acquiredPrice: 0.0,
            acquiredDate: DateTime(2023, 6, 23),
            quantity: const drift.Value(0),
            condition: 'NM',
            isGraded: const drift.Value(false),
            currentMarketPrice: 110.0,
            lastPriceUpdate: DateTime.now(),
            dynamicData: jsonEncode({
              'set': 'ltr',
              'set_code': 'ltr',
              'collector_number': '2',
              'rarity': 'mythic',
            }),
          ),
        );

    // Card 3: Owned duplicate of card 1 (quantity = 2) to test deduplication in stats
    await db.vaultDao.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'ltr-card-1-foil',
            collectionType: 'mtg',
            name: 'Frodo, Sauron\'s Bane',
            setOrSeries: 'Tales of Middle-earth',
            imageUrl: 'https://cards.scryfall.io/large/front/f/r/frodo_foil.jpg',
            acquiredPrice: 12.0,
            acquiredDate: DateTime(2023, 6, 23),
            quantity: const drift.Value(2),
            condition: 'NM',
            isGraded: const drift.Value(false),
            currentMarketPrice: 15.00,
            lastPriceUpdate: DateTime.now(),
            dynamicData: jsonEncode({
              'set': 'ltr',
              'set_code': 'ltr',
              'collector_number': '1',
              'rarity': 'rare',
            }),
          ),
        );

    // 2. Insert cards for set: "Avatar: The Last Airbender" (code: 'ATLA')
    // Card 4: Owned (quantity = 1, collector_number = 10)
    await db.vaultDao.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'atla-card-1',
            collectionType: 'mtg',
            name: 'Aang, the Last Airbender',
            setOrSeries: 'Avatar: The Last Airbender',
            imageUrl: 'https://cards.scryfall.io/large/front/a/a/aang.jpg',
            acquiredPrice: 10.0,
            acquiredDate: DateTime(2024, 1, 15),
            quantity: const drift.Value(1),
            condition: 'NM',
            isGraded: const drift.Value(false),
            currentMarketPrice: 25.00,
            lastPriceUpdate: DateTime.now(),
            dynamicData: jsonEncode({
              'set': 'atla',
              'set_code': 'atla',
              'collector_number': '10',
              'rarity': 'mythic',
            }),
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

  group('VaultSetCollection Domain Model', () {
    test('Constructs and computes isComplete correctly', () {
      const incomplete = VaultSetCollection(
        setName: 'Tales of Middle-earth',
        setCode: 'LTR',
        collectionType: 'mtg',
        totalCount: 10,
        ownedCount: 5,
        completionPercentage: 0.5,
      );
      expect(incomplete.isComplete, isFalse);
      expect(incomplete.completionPercentage, equals(0.5));

      const complete = VaultSetCollection(
        setName: 'Tales of Middle-earth',
        setCode: 'LTR',
        collectionType: 'mtg',
        totalCount: 10,
        ownedCount: 10,
        completionPercentage: 1.0,
      );
      expect(complete.isComplete, isTrue);

      final updated = incomplete.copyWith(ownedCount: 10, completionPercentage: 1.0);
      expect(updated.isComplete, isTrue);
      expect(updated == complete, isTrue);
    });
  });

  group('VaultDao Collection & Set Queries', () {
    test('watchSetCollections calculates unique counts and completion percentage', () async {
      final collections = await db.vaultDao.watchSetCollections(collectionType: 'mtg').first;
      expect(collections.length, equals(2));

      // Sorted alphabetically: "Avatar: The Last Airbender", then "Tales of Middle-earth"
      final atla = collections.firstWhere((c) => c.setName == 'Avatar: The Last Airbender');
      expect(atla.setCode, equals('ATLA'));
      expect(atla.totalCount, equals(1));
      expect(atla.ownedCount, equals(1));
      expect(atla.completionPercentage, equals(1.0));
      expect(atla.isComplete, isTrue);

      final ltr = collections.firstWhere((c) => c.setName == 'Tales of Middle-earth');
      expect(ltr.setCode, equals('LTR'));
      // 2 unique card names: "Frodo, Sauron's Bane" and "The One Ring"
      expect(ltr.totalCount, equals(2));
      // 1 unique owned card name ("Frodo, Sauron's Bane") despite duplicate copies
      expect(ltr.ownedCount, equals(1));
      expect(ltr.completionPercentage, equals(0.5));
      expect(ltr.isComplete, isFalse);
    });

    test('watchItemsBySet returns member cards sorted by collector number', () async {
      final ltrCards = await db.vaultDao.watchItemsBySet('Tales of Middle-earth', collectionType: 'mtg').first;
      // 3 items in database for LTR
      expect(ltrCards.length, equals(3));
      // First should be collector_number 1
      expect(ltrCards.first.name, equals('Frodo, Sauron\'s Bane'));
      // Last should be collector_number 2
      expect(ltrCards.last.name, equals('The One Ring'));
    });
  });

  group('VaultScreen 3-Way Toggle & Collections View', () {
    testWidgets('3-way toggle switches between Singles, Binders, and Collections', (tester) async {
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
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
        ],
      );

      await tester.pumpWidget(createTestWidget(container: container));
      await tester.pumpAndSettle();

      // Initially in Singles mode
      expect(container.read(vaultViewModeProvider), equals(VaultViewMode.allVault));
      expect(find.byKey(const Key('vault_view_singles_toggle')), findsOneWidget);
      expect(find.byKey(const Key('vault_view_binders_toggle')), findsOneWidget);
      expect(find.byKey(const Key('vault_view_collections_toggle')), findsOneWidget);

      // Switch to Binders mode
      await tester.tap(find.byKey(const Key('vault_view_binders_toggle')));
      await tester.pumpAndSettle();
      expect(container.read(vaultViewModeProvider), equals(VaultViewMode.binders));

      // Switch to Collections mode
      await tester.tap(find.byKey(const Key('vault_view_collections_toggle')));
      await tester.pumpAndSettle();
      expect(container.read(vaultViewModeProvider), equals(VaultViewMode.collections));

      // Switch back to Singles mode
      await tester.tap(find.byKey(const Key('vault_view_singles_toggle')));
      await tester.pumpAndSettle();
      expect(container.read(vaultViewModeProvider), equals(VaultViewMode.allVault));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('Collections view displays sets with progress bar and percentage text', (tester) async {
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
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.collections),
        ],
      );

      await tester.pumpWidget(createTestWidget(container: container));
      await tester.pumpAndSettle();

      // Collections sliver should be visible
      expect(find.byType(VaultCollectionViewSliver), findsOneWidget);

      // Set names displayed
      expect(find.text('Avatar: The Last Airbender'), findsOneWidget);
      expect(find.text('Tales of Middle-earth'), findsOneWidget);

      // Set codes displayed
      expect(find.text('ATLA'), findsOneWidget);
      expect(find.text('LTR'), findsOneWidget);

      // Progress bars displayed
      expect(find.byKey(const Key('vault_collection_progress_ATLA')), findsOneWidget);
      expect(find.byKey(const Key('vault_collection_progress_LTR')), findsOneWidget);

      // Stats and percentage text
      expect(find.text('100% • 1/1 owned'), findsOneWidget);
      expect(find.text('50% • 1/2 owned'), findsOneWidget);

      // Visual progress indicator check
      final ltrProgress = tester.widget<LinearProgressIndicator>(
        find.byKey(const Key('vault_collection_progress_LTR')),
      );
      expect(ltrProgress.value, closeTo(0.5, 0.01));

      final atlaProgress = tester.widget<LinearProgressIndicator>(
        find.byKey(const Key('vault_collection_progress_ATLA')),
      );
      expect(atlaProgress.value, closeTo(1.0, 0.01));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('Tapping collection card expands and displays member cards', (tester) async {
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
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.collections),
        ],
      );

      await tester.pumpWidget(createTestWidget(container: container));
      await tester.pumpAndSettle();

      // Cards inside LTR are not visible yet before expansion
      expect(find.byKey(const Key('vault_collection_grid_LTR')), findsNothing);

      // Tap on LTR collection tile header to expand
      await tester.tap(find.byKey(const Key('vault_collection_tile_LTR')));
      await tester.pumpAndSettle();

      // Grid is now visible
      expect(find.byKey(const Key('vault_collection_grid_LTR')), findsOneWidget);

      // Member cards are displayed
      expect(find.text('Frodo, Sauron\'s Bane'), findsWidgets);
      expect(find.text('The One Ring'), findsOneWidget);

      // Tap again collapses the collection
      await tester.tap(find.byKey(const Key('vault_collection_header_LTR')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('vault_collection_grid_LTR')), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('Grayscale ColorFiltered renders for unowned cards and full color for owned cards', (tester) async {
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
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.collections),
        ],
      );

      await tester.pumpWidget(createTestWidget(container: container));
      await tester.pumpAndSettle();

      // Expand LTR
      await tester.tap(find.byKey(const Key('vault_collection_tile_LTR')));
      await tester.pumpAndSettle();

      // Unowned card (ltr-card-2: "The One Ring") has ColorFiltered with vaultGrayscaleColorFilter
      expect(find.byKey(const Key('vault_collection_grayscale_ltr-card-2')), findsOneWidget);
      final colorFilteredWidget = tester.widget<ColorFiltered>(
        find.byKey(const Key('vault_collection_grayscale_ltr-card-2')),
      );
      expect(colorFilteredWidget.colorFilter, equals(vaultGrayscaleColorFilter));

      // Owned card (ltr-card-1) does NOT have grayscale ColorFiltered
      expect(find.byKey(const Key('vault_collection_grayscale_ltr-card-1')), findsNothing);

      // Unowned card displays "UNOWNED" badge
      expect(find.text('UNOWNED'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('Tapping a card in expanded collection opens CardDetailSheet', (tester) async {
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
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.collections),
        ],
      );

      await tester.pumpWidget(createTestWidget(container: container));
      await tester.pumpAndSettle();

      // Expand LTR
      await tester.tap(find.byKey(const Key('vault_collection_tile_LTR')));
      await tester.pumpAndSettle();

      // Tap on card
      await tester.tap(find.byKey(const Key('vault_collection_item_ltr-card-2')));
      await tester.pumpAndSettle();

      // CardDetailSheet should be opened
      expect(find.byType(CardDetailSheet), findsOneWidget);
      expect(find.text('The One Ring'), findsWidgets);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });
  });
}
