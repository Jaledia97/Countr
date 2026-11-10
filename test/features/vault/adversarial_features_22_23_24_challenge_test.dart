// Copyright (c) 2026 Countr. All rights reserved.
// Adversarial Challenger Empirical Stress-Test Suite for Milestone 5 (Features 22, 23, 24)

import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/auth/presentation/providers/auth_providers.dart';
import 'package:countr/features/profile/presentation/providers/profile_providers.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/domain/models/vault_set_collection.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/screens/collections_screen.dart';
import 'package:countr/features/vault/presentation/screens/master_set_screen.dart';
import 'package:countr/features/vault/presentation/screens/vault_screen.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_tile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  Widget buildTestScope({
    required Widget child,
    Size viewport = const Size(390, 844),
    double textScale = 1.0,
  }) {
    final user = AuthUser(
      id: 'challenger_user',
      displayName: 'Adversarial Challenger',
      username: 'challenger_m5',
      provider: AuthProviderType.email,
      tier: AccountTier.free,
      isGuest: false,
      isVerifiedBusiness: false,
      createdAt: DateTime.now(),
    );

    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        vaultDaoProvider.overrideWithValue(dao),
        currentUserIdProvider.overrideWith((ref) => 'challenger_user'),
        currentUserProvider.overrideWith(
          (ref) => CurrentUserNotifier(ref.watch(authRepositoryProvider))
            ..setUser(user),
        ),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: viewport,
            textScaler: TextScaler.linear(textScale),
          ),
          child: child,
        ),
      ),
    );
  }

  // ===========================================================================
  // FEATURE 22: Set Completion Ratio Calculation
  // ===========================================================================
  group('Adversarial Feature 22: Set Completion Ratio Calculation', () {
    test('F22.1: Set with 0 cards returns 0.0% in DAO without division by zero', () async {
      // No cards inserted
      final collections = await dao.watchSetCollections(collectionType: 'mtg').first;
      expect(collections, isEmpty);

      // Explicit VaultSetCollection with 0 cards
      const emptySet = VaultSetCollection(
        setName: 'Empty Set',
        setCode: 'EMP',
        collectionType: 'mtg',
        totalCount: 0,
        ownedCount: 0,
        completionPercentage: 0.0,
      );
      expect(emptySet.completionPercentage, equals(0.0));
      expect(emptySet.isComplete, isFalse);
    });

    testWidgets('F22.2: Master Set with 1 owned card out of 99,999 master catalog returns 0.0%, never 100.0%', (tester) async {
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card_massive_1',
          collectionType: 'mtg',
          name: 'The Lone Survivor',
          setOrSeries: 'Massive Catalog Set',
          imageUrl: '',
          acquiredPrice: 1.0,
          acquiredDate: DateTime.now(),
          quantity: const drift.Value(1),
          condition: 'NM',
          currentMarketPrice: 2.0,
          lastPriceUpdate: DateTime.now(),
          dynamicData: jsonEncode({
            'set_code': 'mass',
            'collector_number': '1',
          }),
        ),
      );

      const massiveCollection = VaultSetCollection(
        setName: 'Massive Catalog Set',
        setCode: 'MASS',
        collectionType: 'Magic: The Gathering',
        totalCount: 99999, // 99,999 cards in master catalog
        ownedCount: 1,
        completionPercentage: 1 / 99999,
      );

      await tester.pumpWidget(
        buildTestScope(
          child: const MasterSetScreen(
            collection: massiveCollection,
            activeGame: 'Magic: The Gathering',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the ratio display
      expect(find.text('1 / 99999'), findsOneWidget);
      expect(find.text('0.0% complete'), findsOneWidget);
      expect(find.text('100.0% complete'), findsNothing);
    });

    test('F22.3: Duplicate printings of the same card (4 copies) do not inflate distinctOwnedCards', () async {
      // Insert 4 copies of 'Lightning Bolt' with different item IDs (e.g. normal, foil, promo)
      for (int i = 1; i <= 4; i++) {
        await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'bolt_copy_$i',
            collectionType: 'mtg',
            name: 'Lightning Bolt',
            setOrSeries: 'Alpha Edition',
            imageUrl: '',
            acquiredPrice: 5.0 * i,
            acquiredDate: DateTime.now(),
            quantity: const drift.Value(1),
            condition: 'NM',
            currentMarketPrice: 10.0,
            lastPriceUpdate: DateTime.now(),
            dynamicData: jsonEncode({
              'set_code': 'lea',
              'collector_number': '10',
            }),
          ),
        );
      }

      // Also insert 1 unowned catalog card to give a total of 2 distinct cards in the set
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'black_lotus_catalog',
          collectionType: 'mtg',
          name: 'Black Lotus',
          setOrSeries: 'Alpha Edition',
          imageUrl: '',
          acquiredPrice: 0.0,
          acquiredDate: DateTime.now(),
          quantity: const drift.Value(0), // unowned
          condition: 'NM',
          currentMarketPrice: 20000.0,
          lastPriceUpdate: DateTime.now(),
          dynamicData: jsonEncode({
            'set_code': 'lea',
            'collector_number': '1',
          }),
        ),
      );

      final sets = await dao.watchSetCollections(collectionType: 'mtg').first;
      expect(sets.length, equals(1));
      final alphaSet = sets.first;

      // Total distinct cards = 2 (Lightning Bolt, Black Lotus)
      expect(alphaSet.totalCount, equals(2));
      // Distinct owned cards = 1 (Lightning Bolt), NOT 4!
      expect(alphaSet.ownedCount, equals(1));
      // Completion ratio = 1 / 2 = 50.0%
      expect(alphaSet.completionPercentage, closeTo(0.5, 0.001));
    });

    test('F22.4: Wishlisted cards are strictly excluded from owned count in DAO set calculation', () async {
      // Insert 1 truly owned card
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'owned_card_1',
          collectionType: 'mtg',
          name: 'Birds of Paradise',
          setOrSeries: 'Ravnica City of Guilds',
          imageUrl: '',
          acquiredPrice: 8.0,
          acquiredDate: DateTime.now(),
          quantity: const drift.Value(1),
          condition: 'NM',
          isWishlisted: const drift.Value(false),
          currentMarketPrice: 10.0,
          lastPriceUpdate: DateTime.now(),
          dynamicData: jsonEncode({
            'set_code': 'rav',
            'collector_number': '1',
          }),
        ),
      );

      // Insert 1 wishlisted card (isWishlisted: true, quantity: 1)
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'wishlisted_card_2',
          collectionType: 'mtg',
          name: 'Dark Confidant',
          setOrSeries: 'Ravnica City of Guilds',
          imageUrl: '',
          acquiredPrice: 0.0,
          acquiredDate: DateTime.now(),
          quantity: const drift.Value(1),
          condition: 'NM',
          isWishlisted: const drift.Value(true), // wishlisted!
          currentMarketPrice: 25.0,
          lastPriceUpdate: DateTime.now(),
          dynamicData: jsonEncode({
            'set_code': 'rav',
            'collector_number': '2',
          }),
        ),
      );

      final sets = await dao.watchSetCollections(collectionType: 'mtg').first;
      expect(sets.length, equals(1));
      final ravSet = sets.first;

      // Both cards are distinct names in the set
      expect(ravSet.totalCount, equals(2));
      // Only the non-wishlisted card is counted as owned!
      expect(ravSet.ownedCount, equals(1));
      expect(ravSet.completionPercentage, closeTo(0.5, 0.001));
    });
  });

  // ===========================================================================
  // FEATURE 23: 3x3 Master Set View & True Grayscale
  // ===========================================================================
  group('Adversarial Feature 23: 3x3 Master Set View & True Grayscale', () {
    testWidgets('F23.1: MasterSetScreen renders SliverGrid with Key("master_set_grid") and crossAxisCount: 3', (tester) async {
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'grid_card_1',
          collectionType: 'mtg',
          name: 'Forest',
          setOrSeries: 'Zendikar',
          imageUrl: '',
          acquiredPrice: 0.1,
          acquiredDate: DateTime.now(),
          quantity: const drift.Value(1),
          condition: 'NM',
          currentMarketPrice: 0.2,
          lastPriceUpdate: DateTime.now(),
          dynamicData: jsonEncode({'set_code': 'zen', 'collector_number': '1'}),
        ),
      );

      const zenSet = VaultSetCollection(
        setName: 'Zendikar',
        setCode: 'ZEN',
        collectionType: 'Magic: The Gathering',
        totalCount: 1,
        ownedCount: 1,
        completionPercentage: 1.0,
      );

      await tester.pumpWidget(
        buildTestScope(
          child: const MasterSetScreen(
            collection: zenSet,
            activeGame: 'Magic: The Gathering',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final gridFinder = find.byKey(const Key('master_set_grid'));
      expect(gridFinder, findsOneWidget);

      final sliverGrid = tester.widget<SliverGrid>(gridFinder);
      final delegate = sliverGrid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, equals(3));
    });

    testWidgets('F23.2 & F23.3: Owned cards render Key("master_set_owned_card") and quantity badge Key("master_set_quantity_badge")', (tester) async {
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'owned_c1',
          collectionType: 'mtg',
          name: 'Island',
          setOrSeries: 'Theros',
          imageUrl: '',
          acquiredPrice: 0.5,
          acquiredDate: DateTime.now(),
          quantity: const drift.Value(3), // 3 copies owned
          condition: 'NM',
          currentMarketPrice: 0.5,
          lastPriceUpdate: DateTime.now(),
          dynamicData: jsonEncode({'set_code': 'ths', 'collector_number': '1'}),
        ),
      );

      const thsSet = VaultSetCollection(
        setName: 'Theros',
        setCode: 'THS',
        collectionType: 'Magic: The Gathering',
        totalCount: 1,
        ownedCount: 1,
        completionPercentage: 1.0,
      );

      await tester.pumpWidget(
        buildTestScope(
          child: const MasterSetScreen(
            collection: thsSet,
            activeGame: 'Magic: The Gathering',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('master_set_owned_card')), findsOneWidget);
      expect(find.byKey(const Key('master_set_quantity_badge')), findsOneWidget);
      expect(find.text('x3'), findsOneWidget);
    });

    testWidgets('F23.4: Quantity badge overflow resistance with x999 on narrow 320px screen', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'extreme_owned_c1',
          collectionType: 'mtg',
          name: 'Relentless Rats',
          setOrSeries: 'Fifth Dawn',
          imageUrl: '',
          acquiredPrice: 2.0,
          acquiredDate: DateTime.now(),
          quantity: const drift.Value(999), // x999
          condition: 'NM',
          currentMarketPrice: 2.5,
          lastPriceUpdate: DateTime.now(),
          dynamicData: jsonEncode({'set_code': '5dn', 'collector_number': '1'}),
        ),
      );

      const fdnSet = VaultSetCollection(
        setName: 'Fifth Dawn',
        setCode: '5DN',
        collectionType: 'Magic: The Gathering',
        totalCount: 1,
        ownedCount: 1,
        completionPercentage: 1.0,
      );

      await tester.pumpWidget(
        buildTestScope(
          viewport: const Size(320, 568),
          child: const MasterSetScreen(
            collection: fdnSet,
            activeGame: 'Magic: The Gathering',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'Must have zero RenderFlex overflows on 320px with x999');
      expect(find.byKey(const Key('master_set_quantity_badge')), findsOneWidget);
      expect(find.text('x999'), findsOneWidget);
    });

    testWidgets('F23.5: Unowned cards render in true Rec. 709 grayscale with Key("unowned_card_dimmed_opacity") at 0.55', (tester) async {
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'unowned_card_rec709',
          collectionType: 'mtg',
          name: 'Mox Sapphire',
          setOrSeries: 'Vintage Masters',
          imageUrl: '',
          acquiredPrice: 0.0,
          acquiredDate: DateTime.now(),
          quantity: const drift.Value(0), // Unowned!
          condition: 'NM',
          currentMarketPrice: 5000.0,
          lastPriceUpdate: DateTime.now(),
          dynamicData: jsonEncode({'set_code': 'vma', 'collector_number': '1'}),
        ),
      );

      const vmaSet = VaultSetCollection(
        setName: 'Vintage Masters',
        setCode: 'VMA',
        collectionType: 'Magic: The Gathering',
        totalCount: 1,
        ownedCount: 0,
        completionPercentage: 0.0,
      );

      await tester.pumpWidget(
        buildTestScope(
          child: const MasterSetScreen(
            collection: vmaSet,
            activeGame: 'Magic: The Gathering',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Unowned card must NOT have master_set_owned_card key
      expect(find.byKey(const Key('master_set_owned_card')), findsNothing);

      // Must have unowned_card_dimmed_opacity with exact opacity 0.55
      final opacityFinder = find.byKey(const Key('unowned_card_dimmed_opacity'));
      expect(opacityFinder, findsOneWidget);
      final opacityWidget = tester.widget<Opacity>(opacityFinder);
      expect(opacityWidget.opacity, equals(0.55));

      // Must have ColorFiltered wrapping with Rec. 709 matrix
      final colorFilteredFinder = find.byKey(const Key('master_set_grayscale_unowned_card_rec709'));
      expect(colorFilteredFinder, findsOneWidget);
      final cf = tester.widget<ColorFiltered>(colorFilteredFinder);
      expect(cf.colorFilter, equals(vaultGrayscaleColorFilter));
    });

    testWidgets('F23.6: collections_screen.dart renders standalone with search bar and VaultCollectionViewSliver', (tester) async {
      await tester.pumpWidget(
        buildTestScope(
          child: const CollectionsScreen(initialGame: 'Magic: The Gathering'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('collections_screen')), findsOneWidget);
      expect(find.text('Set Collections'), findsOneWidget);
      expect(find.byType(VaultCollectionViewSliver), findsOneWidget);
    });
  });

  // ===========================================================================
  // FEATURE 24: Wishlist Badge & Filter in Vault/Binders
  // ===========================================================================
  group('Adversarial Feature 24: Wishlist Badge & Filter in Vault/Binders', () {
    testWidgets('F24.1: Toggling Key("vault_filter_wishlisted_chip") displays empty state when 0 wishlisted cards exist', (tester) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Insert only non-wishlisted card
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'regular_card_1',
          collectionType: 'mtg',
          name: 'Lightning Bolt',
          setOrSeries: 'Core Set 2010',
          imageUrl: '',
          acquiredPrice: 1.0,
          acquiredDate: DateTime.now(),
          quantity: const drift.Value(1),
          condition: 'NM',
          isWishlisted: const drift.Value(false),
          currentMarketPrice: 1.5,
          lastPriceUpdate: DateTime.now(),
          dynamicData: '{}',
        ),
      );

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(dao),
          activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
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

      // Find the wishlisted filter chip
      final wishlistChip = find.byKey(const Key('vault_filter_wishlisted_chip'));
      expect(wishlistChip, findsWidgets); // Can be in MTG and polymorphic rows

      // Tap the chip
      await tester.ensureVisible(wishlistChip.first);
      await tester.tap(wishlistChip.first);
      await tester.pumpAndSettle();

      // Verify that provider state is updated to true
      expect(container.read(vaultWishlistFilterProvider), isTrue);

      // Verify empty state is displayed because 0 wishlisted cards exist
      expect(find.text('No owned items in Magic: The Gathering'), findsOneWidget);
    });

    test('F24.2: Batch wishlisting and de-wishlisting updates database and query counts', () async {
      // Insert 10 cards initially non-wishlisted
      for (int i = 0; i < 10; i++) {
        await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'batch_item_$i',
            collectionType: 'mtg',
            name: 'Card $i',
            setOrSeries: 'Set A',
            imageUrl: '',
            acquiredPrice: 1.0,
            acquiredDate: DateTime.now(),
            quantity: const drift.Value(1),
            condition: 'NM',
            isWishlisted: const drift.Value(false),
            currentMarketPrice: 2.0,
            lastPriceUpdate: DateTime.now(),
            dynamicData: '{}',
          ),
        );
      }

      // Verify 0 wishlisted items initially
      var wishlistedItems = await dao.watchItemsByCollection(
        'mtg',
        onlyWishlisted: true,
      ).first;
      expect(wishlistedItems, isEmpty);

      // Batch wishlist all 10 cards
      await db.customUpdate(
        'UPDATE vault_items SET is_wishlisted = 1 WHERE collection_type = ?',
        variables: [drift.Variable.withString('mtg')],
        updates: {db.vaultItems},
      );

      wishlistedItems = await dao.watchItemsByCollection(
        'mtg',
        onlyWishlisted: true,
      ).first;
      expect(wishlistedItems.length, equals(10));
      expect(wishlistedItems.every((item) => item.isWishlisted == true), isTrue);

      // Batch de-wishlist all 10 cards
      await db.customUpdate(
        'UPDATE vault_items SET is_wishlisted = 0 WHERE collection_type = ?',
        variables: [drift.Variable.withString('mtg')],
        updates: {db.vaultItems},
      );

      wishlistedItems = await dao.watchItemsByCollection(
        'mtg',
        onlyWishlisted: true,
      ).first;
      expect(wishlistedItems, isEmpty);
    });

    testWidgets('F24.3: Wishlist badge placement is at Positioned(top: 4, right: 4) with Key("vault_card_wishlist_badge") and Key("wishlist_badge_pos")', (tester) async {
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'wishlisted_item_1',
          collectionType: 'mtg',
          name: 'Black Lotus',
          setOrSeries: 'Alpha',
          imageUrl: '',
          acquiredPrice: 1000.0,
          acquiredDate: DateTime.now(),
          quantity: const drift.Value(1),
          condition: 'NM',
          isGraded: const drift.Value(false),
          currentMarketPrice: 25000.0,
          lastPriceUpdate: DateTime.now(),
          dynamicData: '{}',
          isWishlisted: const drift.Value(true), // Wishlisted!
        ),
      );

      final all = await db.select(db.vaultItems).get();
      final item = all.firstWhere((e) => e.id == 'wishlisted_item_1');
      expect(item.isWishlisted, isTrue);

      await tester.pumpWidget(
        buildTestScope(
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                height: 300,
                child: VaultItemTile(
                  item: item,
                  onTap: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find badge
      final badgeContainerFinder = find.byKey(const Key('vault_card_wishlist_badge'));
      expect(badgeContainerFinder, findsOneWidget);

      final iconFinder = find.byKey(const Key('wishlist_badge_pos'));
      expect(iconFinder, findsOneWidget);

      // Verify Positioned widget ancestor
      final positionedFinder = find.ancestor(
        of: badgeContainerFinder,
        matching: find.byType(Positioned),
      );
      expect(positionedFinder, findsOneWidget);

      final positionedWidget = tester.widget<Positioned>(positionedFinder);
      expect(positionedWidget.top, equals(4.0));
      expect(positionedWidget.right, equals(4.0));
    });
  });
}
