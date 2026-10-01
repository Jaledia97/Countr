import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/vault/domain/models/vault_set_collection.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/screens/vault_screen.dart';
import 'package:countr/features/vault/presentation/widgets/vault_collection_view_sliver.dart';

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

  Widget createTestApp({required ProviderContainer container}) {
    return UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: VaultScreen(),
      ),
    );
  }

  group('Adversarial Stress Test: Set Completion Math & Deduplication', () {
    test('Duplicate card printings with massive quantities never exceed 100% completion', () async {
      // Set: "Limited Edition Alpha" (code: 'LEA')
      // Card 1: 50 physical copies across multiple entries
      await db.vaultDao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'lea-bolt-1',
              collectionType: 'mtg',
              name: 'Lightning Bolt',
              setOrSeries: 'Limited Edition Alpha',
              imageUrl: 'https://cards.scryfall.io/large/bolt1.jpg',
              acquiredPrice: 100.0,
              acquiredDate: DateTime(2023, 1, 1),
              quantity: const drift.Value(40),
              condition: 'NM',
              isGraded: const drift.Value(false),
              currentMarketPrice: 250.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: jsonEncode({
                'set': 'lea',
                'set_code': 'lea',
                'collector_number': '161',
                'rarity': 'common',
              }),
            ),
          );

      await db.vaultDao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'lea-bolt-2',
              collectionType: 'mtg',
              name: 'Lightning Bolt',
              setOrSeries: 'Limited Edition Alpha',
              imageUrl: 'https://cards.scryfall.io/large/bolt2.jpg',
              acquiredPrice: 150.0,
              acquiredDate: DateTime(2023, 1, 1),
              quantity: const drift.Value(10),
              condition: 'LP',
              isGraded: const drift.Value(false),
              currentMarketPrice: 200.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: jsonEncode({
                'set': 'lea',
                'set_code': 'lea',
                'collector_number': '161',
                'rarity': 'common',
              }),
            ),
          );

      // Card 2: Unowned catalog reference (quantity = 0)
      await db.vaultDao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'lea-lotus-ref',
              collectionType: 'mtg',
              name: 'Black Lotus',
              setOrSeries: 'Limited Edition Alpha',
              imageUrl: 'https://cards.scryfall.io/large/lotus.jpg',
              acquiredPrice: 0.0,
              acquiredDate: DateTime(2023, 1, 1),
              quantity: const drift.Value(0),
              condition: 'NM',
              isGraded: const drift.Value(false),
              currentMarketPrice: 50000.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: jsonEncode({
                'set': 'lea',
                'set_code': 'lea',
                'collector_number': '232',
                'rarity': 'rare',
              }),
            ),
          );

      // Card 3: Another unowned catalog reference (quantity = 0)
      await db.vaultDao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'lea-mox-ref',
              collectionType: 'mtg',
              name: 'Mox Sapphire',
              setOrSeries: 'Limited Edition Alpha',
              imageUrl: 'https://cards.scryfall.io/large/mox.jpg',
              acquiredPrice: 0.0,
              acquiredDate: DateTime(2023, 1, 1),
              quantity: const drift.Value(0),
              condition: 'NM',
              isGraded: const drift.Value(false),
              currentMarketPrice: 8000.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: jsonEncode({
                'set': 'lea',
                'set_code': 'lea',
                'collector_number': '265',
                'rarity': 'rare',
              }),
            ),
          );

      var collections = await db.vaultDao.watchSetCollections(collectionType: 'mtg').first;
      expect(collections.length, equals(1));
      var lea = collections.first;

      // Invariant checks:
      // Total unique card names: 3 ('Lightning Bolt', 'Black Lotus', 'Mox Sapphire')
      expect(lea.totalCount, equals(3));
      // Owned unique card names: 1 ('Lightning Bolt' with 50 physical copies)
      expect(lea.ownedCount, equals(1));
      // Completion ratio: 1/3 = ~0.3333
      expect(lea.completionPercentage, closeTo(1 / 3, 0.0001));
      expect(lea.isComplete, isFalse);

      // Now add 1 owned copy of Black Lotus
      await db.vaultDao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'lea-lotus-owned',
              collectionType: 'mtg',
              name: 'Black Lotus',
              setOrSeries: 'Limited Edition Alpha',
              imageUrl: 'https://cards.scryfall.io/large/lotus.jpg',
              acquiredPrice: 20000.0,
              acquiredDate: DateTime(2023, 1, 1),
              quantity: const drift.Value(1),
              condition: 'EX',
              isGraded: const drift.Value(false),
              currentMarketPrice: 50000.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: jsonEncode({
                'set': 'lea',
                'set_code': 'lea',
                'collector_number': '232',
                'rarity': 'rare',
              }),
            ),
          );

      collections = await db.vaultDao.watchSetCollections(collectionType: 'mtg').first;
      lea = collections.first;
      expect(lea.totalCount, equals(3));
      expect(lea.ownedCount, equals(2));
      expect(lea.completionPercentage, closeTo(2 / 3, 0.0001));
      expect(lea.isComplete, isFalse);

      // Now add 99 owned copies of Mox Sapphire
      await db.vaultDao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'lea-mox-owned',
              collectionType: 'mtg',
              name: 'Mox Sapphire',
              setOrSeries: 'Limited Edition Alpha',
              imageUrl: 'https://cards.scryfall.io/large/mox.jpg',
              acquiredPrice: 6000.0,
              acquiredDate: DateTime(2023, 1, 1),
              quantity: const drift.Value(99),
              condition: 'NM',
              isGraded: const drift.Value(false),
              currentMarketPrice: 8000.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: jsonEncode({
                'set': 'lea',
                'set_code': 'lea',
                'collector_number': '265',
                'rarity': 'rare',
              }),
            ),
          );

      collections = await db.vaultDao.watchSetCollections(collectionType: 'mtg').first;
      lea = collections.first;
      expect(lea.totalCount, equals(3));
      expect(lea.ownedCount, equals(3));
      expect(lea.completionPercentage, equals(1.0));
      expect(lea.isComplete, isTrue);

      // Even with 50 Bolts, 1 Lotus, 99 Moxes, ownedCount == totalCount and completion == 1.0 (never > 1.0)
      expect(lea.completionPercentage <= 1.0, isTrue);
    });

    test('Deleted cards and invalid quantities are excluded from completion metrics', () async {
      // Insert soft-deleted card (is_deleted = 1)
      await db.vaultDao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'deleted-card',
              collectionType: 'mtg',
              name: 'Ghostly Card',
              setOrSeries: 'Ghost Set',
              imageUrl: '',
              acquiredPrice: 0.0,
              acquiredDate: DateTime.now(),
              quantity: const drift.Value(1),
              condition: 'NM',
              isGraded: const drift.Value(false),
              currentMarketPrice: 1.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: '{}',
              isDeleted: const drift.Value(true),
            ),
          );

      // Insert card with empty setOrSeries
      await db.vaultDao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'no-set-card',
              collectionType: 'mtg',
              name: 'Homeless Card',
              setOrSeries: '   ',
              imageUrl: '',
              acquiredPrice: 0.0,
              acquiredDate: DateTime.now(),
              quantity: const drift.Value(1),
              condition: 'NM',
              isGraded: const drift.Value(false),
              currentMarketPrice: 1.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: '{}',
            ),
          );

      // Insert card with negative quantity (corrupt)
      await db.vaultDao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'negative-qty-card',
              collectionType: 'mtg',
              name: 'Cursed Card',
              setOrSeries: 'Curse Set',
              imageUrl: '',
              acquiredPrice: 0.0,
              acquiredDate: DateTime.now(),
              quantity: const drift.Value(-2),
              condition: 'NM',
              isGraded: const drift.Value(false),
              currentMarketPrice: 1.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: '{}',
            ),
          );

      final collections = await db.vaultDao.watchSetCollections(collectionType: 'mtg').first;
      // Ghost Set and empty set should NOT be in collections
      expect(collections.any((c) => c.setName == 'Ghost Set'), isFalse);
      expect(collections.any((c) => c.setName.trim().isEmpty), isFalse);

      // Curse Set has 1 total card, but owned_cards must be 0 because quantity is not > 0
      final curseSet = collections.firstWhere((c) => c.setName == 'Curse Set');
      expect(curseSet.totalCount, equals(1));
      expect(curseSet.ownedCount, equals(0));
      expect(curseSet.completionPercentage, equals(0.0));
      expect(curseSet.isComplete, isFalse);
    });

    test('Zero total cards returns 0.0 completion without division by zero', () {
      const zeroCollection = VaultSetCollection(
        setName: 'Empty Set',
        setCode: 'EMP',
        collectionType: 'mtg',
        totalCount: 0,
        ownedCount: 0,
        completionPercentage: 0.0,
      );
      expect(zeroCollection.isComplete, isFalse);
      expect(zeroCollection.completionPercentage, equals(0.0));
    });
  });

  group('Adversarial Stress Test: 3-Way Toggle State Switching & Stress Cycling', () {
    testWidgets('Rapid cyclic switching across Singles -> Binders -> Collections preserves state and settles cleanly', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Insert 1 set card
      await db.vaultDao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'test-card-1',
              collectionType: 'mtg',
              name: 'Sol Ring',
              setOrSeries: 'Commander',
              imageUrl: 'https://cards.scryfall.io/large/sol_ring.jpg',
              acquiredPrice: 2.0,
              acquiredDate: DateTime.now(),
              quantity: const drift.Value(2),
              condition: 'NM',
              isGraded: const drift.Value(false),
              currentMarketPrice: 2.50,
              lastPriceUpdate: DateTime.now(),
              dynamicData: jsonEncode({
                'set_code': 'cmd',
                'collector_number': '100',
              }),
            ),
          );

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
        ],
      );

      await tester.pumpWidget(createTestApp(container: container));
      await tester.pumpAndSettle();

      // Check initial active segment: Singles
      expect(container.read(vaultViewModeProvider), equals(VaultViewMode.allVault));

      // Check toggle keys exist
      final singlesFinder = find.byKey(const Key('vault_view_singles_toggle'));
      final bindersFinder = find.byKey(const Key('vault_view_binders_toggle'));
      final collectionsFinder = find.byKey(const Key('vault_view_collections_toggle'));

      expect(singlesFinder, findsOneWidget);
      expect(bindersFinder, findsOneWidget);
      expect(collectionsFinder, findsOneWidget);

      // Perform a stress loop switching back and forth multiple times
      for (int i = 0; i < 3; i++) {
        // Tap Binders
        await tester.tap(bindersFinder);
        await tester.pump();
        expect(container.read(vaultViewModeProvider), equals(VaultViewMode.binders));

        // Tap Collections
        await tester.tap(collectionsFinder);
        await tester.pump();
        expect(container.read(vaultViewModeProvider), equals(VaultViewMode.collections));

        // Tap Singles
        await tester.tap(singlesFinder);
        await tester.pump();
        expect(container.read(vaultViewModeProvider), equals(VaultViewMode.allVault));
      }

      await tester.pumpAndSettle();

      // Switch to Collections mode and verify sliver rendering
      await tester.tap(collectionsFinder);
      await tester.pumpAndSettle();
      expect(container.read(vaultViewModeProvider), equals(VaultViewMode.collections));
      expect(find.byType(VaultCollectionViewSliver), findsOneWidget);

      // Verify segment styling: Collections has bold weight and accentCyan color
      final collectionsText = tester.widget<Text>(find.descendant(
        of: collectionsFinder,
        matching: find.byType(Text),
      ));
      expect(collectionsText.style?.fontWeight, equals(FontWeight.w700));
      expect(collectionsText.style?.color, equals(AppColors.accentCyan));

      // Singles text should be secondary and medium weight
      final singlesText = tester.widget<Text>(find.descendant(
        of: singlesFinder,
        matching: find.byType(Text),
      ));
      expect(singlesText.style?.fontWeight, equals(FontWeight.w500));
      expect(singlesText.style?.color, equals(AppColors.textSecondary));

      // Clean up timer
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('Empty collections state displays cleanly when active game has no cards', (tester) async {
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
          activeGameContextProvider.overrideWith((ref) => 'Pokémon TCG'),
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.collections),
        ],
      );

      await tester.pumpWidget(createTestApp(container: container));
      await tester.pumpAndSettle();

      expect(find.byType(VaultCollectionViewSliver), findsOneWidget);
      expect(find.text('No Collections in Pokémon TCG'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('Expanded collection displays collector number #100 and quantity badge 2x', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await db.vaultDao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'cmd-sol-ring',
              collectionType: 'mtg',
              name: 'Sol Ring',
              setOrSeries: 'Commander',
              imageUrl: 'https://cards.scryfall.io/large/sol_ring.jpg',
              acquiredPrice: 2.0,
              acquiredDate: DateTime.now(),
              quantity: const drift.Value(2),
              condition: 'NM',
              isGraded: const drift.Value(false),
              currentMarketPrice: 2.50,
              lastPriceUpdate: DateTime.now(),
              dynamicData: jsonEncode({
                'set_code': 'cmd',
                'collector_number': '100',
              }),
            ),
          );

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.collections),
        ],
      );

      await tester.pumpWidget(createTestApp(container: container));
      await tester.pumpAndSettle();

      // Tap collection header to expand
      await tester.tap(find.byKey(const Key('vault_collection_tile_CMD')));
      await tester.pumpAndSettle();

      // Verify collector number badge '#100'
      expect(find.text('#100'), findsOneWidget);

      // Verify quantity badge '2x'
      expect(find.text('2x'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });

    test('watchSetCollections correctly handles search query against setName, card name, and dynamicData', () async {
      await db.vaultDao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'search-card-1',
              collectionType: 'mtg',
              name: 'Urza, Lord High Artificer',
              setOrSeries: 'Modern Horizons',
              imageUrl: '',
              acquiredPrice: 40.0,
              acquiredDate: DateTime.now(),
              quantity: const drift.Value(1),
              condition: 'NM',
              isGraded: const drift.Value(false),
              currentMarketPrice: 45.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: jsonEncode({
                'set_code': 'mh1',
                'collector_number': '75',
              }),
            ),
          );

      // Search by set name
      final bySetName = await db.vaultDao.watchSetCollections(
        collectionType: 'mtg',
        searchQuery: 'Modern',
      ).first;
      expect(bySetName.length, equals(1));
      expect(bySetName.first.setName, equals('Modern Horizons'));

      // Search by card name
      final byCardName = await db.vaultDao.watchSetCollections(
        collectionType: 'mtg',
        searchQuery: 'Urza',
      ).first;
      expect(byCardName.length, equals(1));
      expect(byCardName.first.setName, equals('Modern Horizons'));

      // Search by set_code in dynamicData
      final byCode = await db.vaultDao.watchSetCollections(
        collectionType: 'mtg',
        searchQuery: 'mh1',
      ).first;
      expect(byCode.length, equals(1));
      expect(byCode.first.setName, equals('Modern Horizons'));

      // Search non-existent
      final empty = await db.vaultDao.watchSetCollections(
        collectionType: 'mtg',
        searchQuery: 'NonExistentXYZ999',
      ).first;
      expect(empty, isEmpty);
    });

    test('watchItemsBySet orders cards numerically by collector number', () async {
      final numbers = ['10', '2', '1', '20', '3'];
      for (final num in numbers) {
        await db.vaultDao.into(db.vaultItems).insert(
              VaultItemsCompanion.insert(
                id: 'order-card-$num',
                collectionType: 'mtg',
                name: 'Card #$num',
                setOrSeries: 'Ordered Set',
                imageUrl: '',
                acquiredPrice: 1.0,
                acquiredDate: DateTime.now(),
                quantity: const drift.Value(1),
                condition: 'NM',
                isGraded: const drift.Value(false),
                currentMarketPrice: 1.0,
                lastPriceUpdate: DateTime.now(),
                dynamicData: jsonEncode({
                  'set_code': 'ord',
                  'collector_number': num,
                }),
              ),
            );
      }

      final items = await db.vaultDao.watchItemsBySet('Ordered Set', collectionType: 'mtg').first;
      final sortedNumbers = items.map((i) {
        final data = jsonDecode(i.dynamicData) as Map<String, dynamic>;
        return data['collector_number']?.toString();
      }).toList();

      // Numerical order: 1, 2, 3, 10, 20 (not alphabetical 1, 10, 2, 20, 3)
      expect(sortedNumbers, equals(['1', '2', '3', '10', '20']));
    });

    test('Generative Oracle Test: 50 randomized cards with duplicate printings strictly matches oracle math', () async {
      final cardNames = List.generate(30, (i) => 'Unique Card $i');
      final oracleTotalSet = <String>{};
      final oracleOwnedSet = <String>{};

      // Generate 50 items with duplicates across the 30 unique names
      for (int i = 0; i < 50; i++) {
        final cardName = cardNames[i % 30];
        // Some cards have qty = 0 (unowned), some qty > 0 (owned)
        final qty = (i % 3 == 0) ? 0 : ((i * 7) % 5 + 1);
        oracleTotalSet.add(cardName);
        if (qty > 0) {
          oracleOwnedSet.add(cardName);
        }

        await db.vaultDao.into(db.vaultItems).insert(
              VaultItemsCompanion.insert(
                id: 'gen-card-$i',
                collectionType: 'mtg',
                name: cardName,
                setOrSeries: 'Generative Set',
                imageUrl: '',
                acquiredPrice: 1.0,
                acquiredDate: DateTime.now(),
                quantity: drift.Value(qty),
                condition: 'NM',
                isGraded: const drift.Value(false),
                currentMarketPrice: 2.0,
                lastPriceUpdate: DateTime.now(),
                dynamicData: jsonEncode({
                  'set_code': 'gen',
                  'collector_number': '${i + 1}',
                }),
              ),
            );
      }

      final collections = await db.vaultDao.watchSetCollections(collectionType: 'mtg').first;
      final genSet = collections.firstWhere((c) => c.setName == 'Generative Set');

      // Compare DAO result directly with our independent mathematical oracle
      expect(genSet.totalCount, equals(oracleTotalSet.length));
      expect(genSet.ownedCount, equals(oracleOwnedSet.length));
      final expectedPct = (oracleOwnedSet.length / oracleTotalSet.length).clamp(0.0, 1.0);
      expect(genSet.completionPercentage, closeTo(expectedPct, 0.0001));
      expect(genSet.isComplete, equals(oracleOwnedSet.length >= oracleTotalSet.length));
    });
  });
}
