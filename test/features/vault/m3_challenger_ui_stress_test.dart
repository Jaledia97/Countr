// Copyright (c) 2026 Countr. All rights reserved.
// Milestone 3 Empirical UI Stress Test Suite
// Features 11–15: Vault Estimated Value & Fast 3x3 Collections

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
import 'package:countr/features/vault/presentation/screens/master_set_screen.dart';
import 'package:countr/features/vault/presentation/screens/vault_screen.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';

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

  Widget buildTestApp({
    required Widget home,
    String userId = 'user-current-me',
    double textScale = 1.0,
    Size viewport = const Size(390, 844),
    VaultViewMode viewMode = VaultViewMode.allVault,
    String activeGame = 'Magic: The Gathering',
  }) {
    final user = AuthUser(
      id: userId,
      displayName: 'Empirical Challenger M3',
      username: 'challenger_m3_2',
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
        currentUserIdProvider.overrideWith((ref) => userId),
        currentUserProvider.overrideWith(
          (ref) => CurrentUserNotifier(ref.watch(authRepositoryProvider))
            ..setUser(user),
        ),
        vaultViewModeProvider.overrideWith((ref) => viewMode),
        activeGameContextProvider.overrideWith((ref) => activeGame),
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: viewport,
            textScaler: TextScaler.linear(textScale),
          ),
          child: home,
        ),
      ),
    );
  }

  group('Group 1: UI Reactivity in _CollapsibleVaultValueHeaderDelegate', () {
    testWidgets(
      '1.1 Displays \$0.00 and 0 items on empty database',
      (tester) async {
        await tester.pumpWidget(
          buildTestApp(home: const VaultScreen()),
        );
        await tester.pumpAndSettle();

        final summaryCard = find.byKey(const Key('vault_portfolio_summary_card'));
        expect(summaryCard, findsOneWidget);
        expect(find.descendant(of: summaryCard, matching: find.text(r'$0.00')), findsOneWidget);
        expect(find.descendant(of: summaryCard, matching: find.text('Total Tracked Items: 0')), findsOneWidget);
      },
    );

    testWidgets(
      '1.2 Inserting nonfoil card with dynamic pricing immediately updates dollar total and item count',
      (tester) async {
        await tester.pumpWidget(
          buildTestApp(home: const VaultScreen()),
        );
        await tester.pumpAndSettle();

        expect(find.text(r'$0.00'), findsOneWidget);

        // Insert nonfoil Sol Ring (qty 1, nonfoil USD $15.00, foil USD $60.00, currentMarketPrice 0.0)
        await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'card-sol-ring',
            collectionType: 'mtg',
            name: 'Sol Ring',
            setOrSeries: 'Commander',
            imageUrl: '',
            acquiredPrice: 5.0,
            acquiredDate: DateTime.now(),
            quantity: const drift.Value(1),
            condition: 'NM',
            currentMarketPrice: 0.0,
            lastPriceUpdate: DateTime.now(),
            dynamicData: jsonEncode({
              'finish': 'nonfoil',
              'prices': {'usd': '15.00', 'usd_foil': '60.00'},
            }),
          ),
        );

        await tester.pumpAndSettle();

        final summaryCard = find.byKey(const Key('vault_portfolio_summary_card'));
        expect(find.descendant(of: summaryCard, matching: find.text(r'$15.00')), findsOneWidget);
        expect(find.descendant(of: summaryCard, matching: find.text('Total Tracked Items: 1')), findsOneWidget);
      },
    );

    testWidgets(
      '1.3 Updating finish from nonfoil to foil immediately recalculates and updates header dollar total',
      (tester) async {
        await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'card-sol-ring',
            collectionType: 'mtg',
            name: 'Sol Ring',
            setOrSeries: 'Commander',
            imageUrl: '',
            acquiredPrice: 5.0,
            acquiredDate: DateTime.now(),
            quantity: const drift.Value(1),
            condition: 'NM',
            currentMarketPrice: 0.0,
            lastPriceUpdate: DateTime.now(),
            dynamicData: jsonEncode({
              'finish': 'nonfoil',
              'prices': {'usd': '15.00', 'usd_foil': '60.00'},
            }),
          ),
        );

        await tester.pumpWidget(
          buildTestApp(home: const VaultScreen()),
        );
        await tester.pumpAndSettle();

        final summaryCard = find.byKey(const Key('vault_portfolio_summary_card'));
        expect(find.descendant(of: summaryCard, matching: find.text(r'$15.00')), findsOneWidget);

        // Switch finish to 'foil'
        await (db.update(db.vaultItems)..where((t) => t.id.equals('card-sol-ring'))).write(
          VaultItemsCompanion(
            dynamicData: drift.Value(jsonEncode({
              'finish': 'foil',
              'prices': {'usd': '15.00', 'usd_foil': '60.00'},
            })),
          ),
        );

        await tester.pumpAndSettle();

        // Should now reflect usd_foil: $60.00
        expect(find.descendant(of: summaryCard, matching: find.text(r'$60.00')), findsOneWidget);
        expect(find.descendant(of: summaryCard, matching: find.text('Total Tracked Items: 1')), findsOneWidget);
      },
    );

    testWidgets(
      '1.4 Changing quantity immediately scales market value by quantity in UI',
      (tester) async {
        await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'card-sol-ring',
            collectionType: 'mtg',
            name: 'Sol Ring',
            setOrSeries: 'Commander',
            imageUrl: '',
            acquiredPrice: 5.0,
            acquiredDate: DateTime.now(),
            quantity: const drift.Value(1),
            condition: 'NM',
            currentMarketPrice: 0.0,
            lastPriceUpdate: DateTime.now(),
            dynamicData: jsonEncode({
              'finish': 'foil',
              'prices': {'usd': '15.00', 'usd_foil': '60.00'},
            }),
          ),
        );

        await tester.pumpWidget(
          buildTestApp(home: const VaultScreen()),
        );
        await tester.pumpAndSettle();

        final summaryCard = find.byKey(const Key('vault_portfolio_summary_card'));
        expect(find.descendant(of: summaryCard, matching: find.text(r'$60.00')), findsOneWidget);

        // Scale quantity to 4 copies
        await (db.update(db.vaultItems)..where((t) => t.id.equals('card-sol-ring'))).write(
          const VaultItemsCompanion(
            quantity: drift.Value(4),
          ),
        );

        await tester.pumpAndSettle();

        // 4 x $60.00 = $240.00
        expect(find.descendant(of: summaryCard, matching: find.text(r'$240.00')), findsOneWidget);
        expect(find.descendant(of: summaryCard, matching: find.text('Total Tracked Items: 4')), findsOneWidget);
      },
    );

    testWidgets(
      '1.5 Inserting second item with direct currentMarketPrice sums correctly',
      (tester) async {
        await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'card-sol-ring',
            collectionType: 'mtg',
            name: 'Sol Ring',
            setOrSeries: 'Commander',
            imageUrl: '',
            acquiredPrice: 5.0,
            acquiredDate: DateTime.now(),
            quantity: const drift.Value(4),
            condition: 'NM',
            currentMarketPrice: 0.0,
            lastPriceUpdate: DateTime.now(),
            dynamicData: jsonEncode({
              'finish': 'foil',
              'prices': {'usd': '15.00', 'usd_foil': '60.00'},
            }),
          ),
        );

        await tester.pumpWidget(
          buildTestApp(home: const VaultScreen()),
        );
        await tester.pumpAndSettle();

        final summaryCard = find.byKey(const Key('vault_portfolio_summary_card'));
        expect(find.descendant(of: summaryCard, matching: find.text(r'$240.00')), findsOneWidget);

        // Insert Black Lotus: currentMarketPrice $25,000.00, qty 1
        await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'card-black-lotus',
            collectionType: 'mtg',
            name: 'Black Lotus',
            setOrSeries: 'Alpha',
            imageUrl: '',
            acquiredPrice: 12000.0,
            acquiredDate: DateTime.now(),
            quantity: const drift.Value(1),
            condition: 'NM',
            currentMarketPrice: 25000.0,
            lastPriceUpdate: DateTime.now(),
            dynamicData: '{}',
          ),
        );

        await tester.pumpAndSettle();

        // $240.00 + $25,000.00 = $25240.00, items: 5
        expect(find.descendant(of: summaryCard, matching: find.text(r'$25240.00')), findsOneWidget);
        expect(find.descendant(of: summaryCard, matching: find.text('Total Tracked Items: 5')), findsOneWidget);
      },
    );

    testWidgets(
      '1.6 Items in Looking For binders or traded are strictly excluded from UI header dollar total',
      (tester) async {
        await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'card-black-lotus',
            collectionType: 'mtg',
            name: 'Black Lotus',
            setOrSeries: 'Alpha',
            imageUrl: '',
            acquiredPrice: 12000.0,
            acquiredDate: DateTime.now(),
            quantity: const drift.Value(1),
            condition: 'NM',
            currentMarketPrice: 25000.0,
            lastPriceUpdate: DateTime.now(),
            dynamicData: '{}',
          ),
        );

        await tester.pumpWidget(
          buildTestApp(home: const VaultScreen()),
        );
        await tester.pumpAndSettle();

        final summaryCard = find.byKey(const Key('vault_portfolio_summary_card'));
        expect(find.descendant(of: summaryCard, matching: find.text(r'$25000.00')), findsOneWidget);

        // Insert item into system Looking For binder ($10,000.00)
        await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'card-wishlist-mox',
            collectionType: 'mtg',
            name: 'Mox Sapphire',
            setOrSeries: 'Beta',
            imageUrl: '',
            acquiredPrice: 0.0,
            acquiredDate: DateTime.now(),
            quantity: const drift.Value(1),
            condition: 'NM',
            currentMarketPrice: 10000.0,
            lastPriceUpdate: DateTime.now(),
            dynamicData: '{}',
            primaryBinderId: const drift.Value('system_looking_for'),
          ),
        );

        await tester.pumpAndSettle();

        // Must still show $25000.00 and 1 item!
        expect(find.descendant(of: summaryCard, matching: find.text(r'$25000.00')), findsOneWidget);
        expect(find.descendant(of: summaryCard, matching: find.text('Total Tracked Items: 1')), findsOneWidget);

        // Mark Black Lotus as traded: is_traded = true
        await (db.update(db.vaultItems)..where((t) => t.id.equals('card-black-lotus'))).write(
          const VaultItemsCompanion(
            isTraded: drift.Value(true),
          ),
        );

        await tester.pumpAndSettle();

        // Must drop to $0.00 and 0 items!
        expect(find.descendant(of: summaryCard, matching: find.text(r'$0.00')), findsOneWidget);
        expect(find.descendant(of: summaryCard, matching: find.text('Total Tracked Items: 0')), findsOneWidget);
      },
    );
  });

  group('Group 2: MasterSetScreen & VaultCollectionViewSliver 3x3 Grid & Isolation', () {
    Future<void> seedMultiSetCatalog() async {
      // Set 1: LTR (The Lord of the Rings) - 3 cards: Frodo (owned 1), Samwise (unowned 0), Aragorn (owned 2)
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-ltr-1',
          collectionType: 'mtg',
          name: 'Frodo, Sauron\'s Bane',
          setOrSeries: 'The Lord of the Rings: Tales of Middle-earth',
          imageUrl: '',
          acquiredPrice: 2.0,
          acquiredDate: DateTime.now(),
          quantity: const drift.Value(1),
          condition: 'NM',
          currentMarketPrice: 3.50,
          lastPriceUpdate: DateTime.now(),
          dynamicData: jsonEncode({
            'set': 'ltr',
            'set_code': 'ltr',
            'collector_number': '1',
            'rarity': 'rare',
          }),
        ),
      );

      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-ltr-2',
          collectionType: 'mtg',
          name: 'Samwise Gamgee',
          setOrSeries: 'The Lord of the Rings: Tales of Middle-earth',
          imageUrl: '',
          acquiredPrice: 0.0,
          acquiredDate: DateTime.now(),
          quantity: const drift.Value(0), // unowned catalog reference
          condition: 'NM',
          currentMarketPrice: 4.00,
          lastPriceUpdate: DateTime.now(),
          dynamicData: jsonEncode({
            'set': 'ltr',
            'set_code': 'ltr',
            'collector_number': '2',
            'rarity': 'rare',
          }),
        ),
      );

      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-ltr-3',
          collectionType: 'mtg',
          name: 'Aragorn, the Uniter',
          setOrSeries: 'The Lord of the Rings: Tales of Middle-earth',
          imageUrl: '',
          acquiredPrice: 8.0,
          acquiredDate: DateTime.now(),
          quantity: const drift.Value(2), // 2 copies owned
          condition: 'NM',
          currentMarketPrice: 12.00,
          lastPriceUpdate: DateTime.now(),
          dynamicData: jsonEncode({
            'set': 'ltr',
            'set_code': 'ltr',
            'collector_number': '3',
            'rarity': 'mythic',
          }),
        ),
      );

      // Set 2: LTC (Commander) - 2 cards: Gandalf (owned 1), Sauron (unowned 0)
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-ltc-1',
          collectionType: 'mtg',
          name: 'Gandalf, White Rider',
          setOrSeries: 'The Lord of the Rings: Tales of Middle-earth Commander',
          imageUrl: '',
          acquiredPrice: 6.0,
          acquiredDate: DateTime.now(),
          quantity: const drift.Value(1),
          condition: 'NM',
          currentMarketPrice: 8.00,
          lastPriceUpdate: DateTime.now(),
          dynamicData: jsonEncode({
            'set': 'ltc',
            'set_code': 'ltc',
            'collector_number': '1',
            'rarity': 'rare',
          }),
        ),
      );

      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-ltc-2',
          collectionType: 'mtg',
          name: 'Sauron, Lord of the Rings',
          setOrSeries: 'The Lord of the Rings: Tales of Middle-earth Commander',
          imageUrl: '',
          acquiredPrice: 0.0,
          acquiredDate: DateTime.now(),
          quantity: const drift.Value(0),
          condition: 'NM',
          currentMarketPrice: 15.00,
          lastPriceUpdate: DateTime.now(),
          dynamicData: jsonEncode({
            'set': 'ltc',
            'set_code': 'ltc',
            'collector_number': '2',
            'rarity': 'mythic',
          }),
        ),
      );

      // Set 3: NEO (Kamigawa: Neon Dynasty) - 1 card: Boseiju (owned 1)
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-neo-266',
          collectionType: 'mtg',
          name: 'Boseiju, Who Endures',
          setOrSeries: 'Kamigawa: Neon Dynasty',
          imageUrl: '',
          acquiredPrice: 30.0,
          acquiredDate: DateTime.now(),
          quantity: const drift.Value(1),
          condition: 'NM',
          currentMarketPrice: 35.00,
          lastPriceUpdate: DateTime.now(),
          dynamicData: jsonEncode({
            'set': 'neo',
            'set_code': 'neo',
            'collector_number': '266',
            'rarity': 'rare',
          }),
        ),
      );
    }

    testWidgets(
      '2.1 VaultCollectionViewSliver renders collection tiles with accurate completion statistics',
      (tester) async {
        await seedMultiSetCatalog();

        await tester.pumpWidget(
          buildTestApp(
            home: const VaultScreen(),
            viewMode: VaultViewMode.collections,
          ),
        );
        await tester.pumpAndSettle();

        // 3 collection tiles should render
        expect(find.byKey(const Key('vault_collection_tile_LTR')), findsOneWidget);
        expect(find.byKey(const Key('vault_collection_tile_LTC')), findsOneWidget);
        expect(find.byKey(const Key('vault_collection_tile_NEO')), findsOneWidget);

        // LTR has 2 owned / 3 total (66.7%)
        expect(find.textContaining('2/3 owned'), findsOneWidget);
        // LTC has 1 owned / 2 total (50%)
        expect(find.textContaining('1/2 owned'), findsOneWidget);
        // NEO has 1 owned / 1 total (100%)
        expect(find.textContaining('1/1 owned'), findsOneWidget);
      },
    );

    testWidgets(
      '2.2 Tapping collection card expands inline 3x3 grid and strictly isolates set code',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await seedMultiSetCatalog();

        await tester.pumpWidget(
          buildTestApp(
            home: const VaultScreen(),
            viewMode: VaultViewMode.collections,
          ),
        );
        await tester.pumpAndSettle();

        // Tap the LTR collection tile to expand
        final ltrTile = find.byKey(const Key('vault_collection_tile_LTR'));
        await tester.ensureVisible(ltrTile);
        await tester.tap(ltrTile);
        await tester.pumpAndSettle();

        // The expanded section renders with key vault_collection_grid_LTR
        final gridFinder = find.byKey(const Key('vault_collection_grid_LTR'));
        expect(gridFinder, findsOneWidget);

        final gridView = tester.widget<GridView>(gridFinder);
        final gridDelegate = gridView.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
        expect(gridDelegate.crossAxisCount, 3, reason: 'Inline collection grid must be 3x3 (crossAxisCount = 3)');

        // Strictly isolated: LTR cards exist in the expanded grid
        expect(find.byKey(const Key('vault_collection_item_card-ltr-1')), findsOneWidget);
        expect(find.byKey(const Key('vault_collection_item_card-ltr-2')), findsOneWidget);
        expect(find.byKey(const Key('vault_collection_item_card-ltr-3')), findsOneWidget);

        // Unowned card (Samwise) has grayscale filter
        expect(find.byKey(const Key('vault_collection_grayscale_card-ltr-2')), findsOneWidget);

        // Cards from other sets must NEVER leak into LTR grid
        expect(find.byKey(const Key('vault_collection_item_card-ltc-1')), findsNothing);
        expect(find.byKey(const Key('vault_collection_item_card-ltc-2')), findsNothing);
        expect(find.byKey(const Key('vault_collection_item_card-neo-266')), findsNothing);
      },
    );

    testWidgets(
      '2.3 Tapping card in inline 3x3 grid opens CardDetailSheet',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await seedMultiSetCatalog();

        await tester.pumpWidget(
          buildTestApp(
            home: const VaultScreen(),
            viewMode: VaultViewMode.collections,
          ),
        );
        await tester.pumpAndSettle();

        // Expand LTR
        final ltrTile = find.byKey(const Key('vault_collection_tile_LTR'));
        await tester.ensureVisible(ltrTile);
        await tester.tap(ltrTile);
        await tester.pumpAndSettle();

        // Tap Frodo card item
        final frodoItem = find.byKey(const Key('vault_collection_item_card-ltr-1'));
        await tester.ensureVisible(frodoItem);
        await tester.tap(frodoItem);
        await tester.pumpAndSettle();

        // CardDetailSheet is opened
        expect(find.byType(CardDetailSheet), findsOneWidget);
        expect(find.text('Frodo, Sauron\'s Bane'), findsWidgets);
      },
    );

    testWidgets(
      '2.4 MasterSetScreen renders full-screen 3x3 grid strictly scoped by set code',
      (tester) async {
        await seedMultiSetCatalog();

        const ltrCollection = VaultSetCollection(
          setName: 'The Lord of the Rings: Tales of Middle-earth',
          setCode: 'LTR',
          collectionType: 'Magic: The Gathering',
          totalCount: 3,
          ownedCount: 2,
          completionPercentage: 0.667,
        );

        await tester.pumpWidget(
          buildTestApp(
            home: const MasterSetScreen(
              collection: ltrCollection,
              activeGame: 'Magic: The Gathering',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('master_set_screen')), findsOneWidget);
        expect(find.text('The Lord of the Rings: Tales of Middle-earth'), findsOneWidget);
        expect(find.text('Set: LTR'), findsOneWidget);
        expect(find.text('66.7% complete'), findsOneWidget);

        // Verify 3-column SliverGrid
        final sliverGridFinder = find.byType(SliverGrid);
        expect(sliverGridFinder, findsOneWidget);
        final sliverGrid = tester.widget<SliverGrid>(sliverGridFinder);
        final gridDelegate = sliverGrid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
        expect(gridDelegate.crossAxisCount, 3, reason: 'MasterSetScreen must use crossAxisCount: 3');

        // All 3 LTR cards present
        expect(find.byKey(const Key('master_set_card_card-ltr-1')), findsOneWidget);
        expect(find.byKey(const Key('master_set_card_card-ltr-2')), findsOneWidget);
        expect(find.byKey(const Key('master_set_card_card-ltr-3')), findsOneWidget);

        // Samwise is unowned -> Missing badge & grayscale
        expect(find.byKey(const Key('master_set_grayscale_card-ltr-2')), findsOneWidget);
        expect(find.text('Missing'), findsOneWidget);

        // Aragorn is owned x2 -> x2 badge
        expect(find.text('x2'), findsOneWidget);
        // Frodo is owned x1 -> x1 badge
        expect(find.text('x1'), findsOneWidget);

        // Collector numbers rendered: #1, #2, #3
        expect(find.text('#1'), findsOneWidget);
        expect(find.text('#2'), findsOneWidget);
        expect(find.text('#3'), findsOneWidget);

        // Strict isolation: LTC and NEO cards are completely absent!
        expect(find.byKey(const Key('master_set_card_card-ltc-1')), findsNothing);
        expect(find.byKey(const Key('master_set_card_card-ltc-2')), findsNothing);
        expect(find.byKey(const Key('master_set_card_card-neo-266')), findsNothing);
      },
    );

    testWidgets(
      '2.5 MasterSetScreen filter chips and search bar filter grid reactively',
      (tester) async {
        await seedMultiSetCatalog();

        const ltrCollection = VaultSetCollection(
          setName: 'The Lord of the Rings: Tales of Middle-earth',
          setCode: 'LTR',
          collectionType: 'Magic: The Gathering',
          totalCount: 3,
          ownedCount: 2,
          completionPercentage: 0.667,
        );

        await tester.pumpWidget(
          buildTestApp(
            home: const MasterSetScreen(
              collection: ltrCollection,
              activeGame: 'Magic: The Gathering',
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Filter by "Missing (1)"
        await tester.tap(find.text('Missing (1)'));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('master_set_card_card-ltr-2')), findsOneWidget);
        expect(find.byKey(const Key('master_set_card_card-ltr-1')), findsNothing);
        expect(find.byKey(const Key('master_set_card_card-ltr-3')), findsNothing);

        // 2. Filter by "Owned (2)"
        await tester.tap(find.text('Owned (2)'));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('master_set_card_card-ltr-1')), findsOneWidget);
        expect(find.byKey(const Key('master_set_card_card-ltr-3')), findsOneWidget);
        expect(find.byKey(const Key('master_set_card_card-ltr-2')), findsNothing);

        // 3. Reset to "All (3)"
        await tester.tap(find.text('All (3)'));
        await tester.pumpAndSettle();

        // 4. Search by card name "Frodo"
        await tester.enterText(find.byKey(const Key('master_set_search_field')), 'Frodo');
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('master_set_card_card-ltr-1')), findsOneWidget);
        expect(find.byKey(const Key('master_set_card_card-ltr-2')), findsNothing);
        expect(find.byKey(const Key('master_set_card_card-ltr-3')), findsNothing);

        // 5. Search by collector number "3" (Aragorn)
        await tester.enterText(find.byKey(const Key('master_set_search_field')), '3');
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('master_set_card_card-ltr-3')), findsOneWidget);
        expect(find.byKey(const Key('master_set_card_card-ltr-1')), findsNothing);
      },
    );

    testWidgets(
      '2.6 Tapping card in MasterSetScreen opens CardDetailSheet and back button pops cleanly',
      (tester) async {
        await seedMultiSetCatalog();

        const ltrCollection = VaultSetCollection(
          setName: 'The Lord of the Rings: Tales of Middle-earth',
          setCode: 'LTR',
          collectionType: 'Magic: The Gathering',
          totalCount: 3,
          ownedCount: 2,
          completionPercentage: 0.667,
        );

        await tester.pumpWidget(
          buildTestApp(
            home: Navigator(
              onGenerateRoute: (settings) => MaterialPageRoute(
                builder: (_) => const MasterSetScreen(
                  collection: ltrCollection,
                  activeGame: 'Magic: The Gathering',
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Tap Aragorn card
        await tester.tap(find.byKey(const Key('master_set_card_card-ltr-3')));
        await tester.pumpAndSettle();

        expect(find.byType(CardDetailSheet), findsOneWidget);
        expect(find.text('Aragorn, the Uniter'), findsWidgets);

        // Dismiss sheet
        await tester.tap(find.byKey(const Key('card_detail_close_button')));
        await tester.pumpAndSettle();

        expect(find.byType(CardDetailSheet), findsNothing);

        // Tap Back button in AppBar
        await tester.tap(find.byKey(const Key('master_set_back_button')));
        await tester.pumpAndSettle();
      },
    );
  });

  group('Group 3: Extreme Viewport Stress (320px Width at 1.5x Text Scale)', () {
    testWidgets(
      '3.1 VaultScreen with _CollapsibleVaultValueHeaderDelegate has ZERO RenderFlex overflows on 320px viewport at 1.5x text scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Insert large portfolio items to stress numeric width
        await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'card-stress-large',
            collectionType: 'mtg',
            name: 'Black Lotus Alpha Edition Pristine Mint Condition',
            setOrSeries: 'Limited Edition Alpha',
            imageUrl: '',
            acquiredPrice: 50000.0,
            acquiredDate: DateTime.now(),
            quantity: const drift.Value(4),
            condition: 'Mint',
            currentMarketPrice: 249999.99,
            lastPriceUpdate: DateTime.now(),
            dynamicData: '{}',
          ),
        );

        await tester.pumpWidget(
          buildTestApp(
            home: const VaultScreen(),
            textScale: 1.5,
            viewport: const Size(320, 640),
            viewMode: VaultViewMode.allVault,
          ),
        );
        await tester.pumpAndSettle();

        final exception = tester.takeException();
        expect(
          exception,
          isNull,
          reason: 'VaultScreen must not produce RenderFlex overflows on 320px width at 1.5x text scale',
        );

        final summaryCard = find.byKey(const Key('vault_portfolio_summary_card'));
        expect(summaryCard, findsOneWidget);
        // Header text and values scale down cleanly via FittedBox
        expect(find.descendant(of: summaryCard, matching: find.text('ESTIMATED VAULT VALUE')), findsOneWidget);
      },
    );

    testWidgets(
      '3.2 MasterSetScreen has ZERO RenderFlex overflows on 320px viewport at 1.5x text scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Seed cards with long names and multi-digit numbers
        await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'card-stress-set-1',
            collectionType: 'mtg',
            name: 'Extremely Long Extended Card Name For Stress Testing Overflow',
            setOrSeries: 'The Lord of the Rings: Tales of Middle-earth Special Collector Edition',
            imageUrl: '',
            acquiredPrice: 10.0,
            acquiredDate: DateTime.now(),
            quantity: const drift.Value(12),
            condition: 'NM',
            currentMarketPrice: 15.0,
            lastPriceUpdate: DateTime.now(),
            dynamicData: jsonEncode({
              'set': 'ltr',
              'set_code': 'ltr',
              'collector_number': '999',
            }),
          ),
        );

        const collection = VaultSetCollection(
          setName: 'The Lord of the Rings: Tales of Middle-earth Special Collector Edition',
          setCode: 'LTR',
          collectionType: 'Magic: The Gathering',
          totalCount: 350,
          ownedCount: 120,
          completionPercentage: 0.343,
        );

        await tester.pumpWidget(
          buildTestApp(
            home: const MasterSetScreen(
              collection: collection,
              activeGame: 'Magic: The Gathering',
            ),
            textScale: 1.5,
            viewport: const Size(320, 640),
          ),
        );
        await tester.pumpAndSettle();

        final exception = tester.takeException();
        expect(
          exception,
          isNull,
          reason: 'MasterSetScreen must not produce RenderFlex overflows on 320px width at 1.5x text scale',
        );

        expect(find.byKey(const Key('master_set_screen')), findsOneWidget);
      },
    );

    testWidgets(
      '3.3 VaultCollectionViewSliver in Collections view has ZERO RenderFlex overflows on 320px viewport at 1.5x text scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Insert sets with long titles
        await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'card-coll-stress',
            collectionType: 'mtg',
            name: 'Nazgûl (Special Art #332)',
            setOrSeries: 'The Lord of the Rings: Tales of Middle-earth',
            imageUrl: '',
            acquiredPrice: 5.0,
            acquiredDate: DateTime.now(),
            quantity: const drift.Value(9),
            condition: 'NM',
            currentMarketPrice: 12.0,
            lastPriceUpdate: DateTime.now(),
            dynamicData: jsonEncode({
              'set': 'ltr',
              'set_code': 'ltr',
              'collector_number': '332',
            }),
          ),
        );

        await tester.pumpWidget(
          buildTestApp(
            home: const VaultScreen(),
            textScale: 1.5,
            viewport: const Size(320, 640),
            viewMode: VaultViewMode.collections,
          ),
        );
        await tester.pumpAndSettle();

        var exception = tester.takeException();
        expect(
          exception,
          isNull,
          reason: 'VaultCollectionViewSliver collapsed tiles must not overflow on 320px at 1.5x text scale',
        );

        // Expand the collection inline under 320px at 1.5x scale
        final tile = find.byKey(const Key('vault_collection_tile_LTR'));
        expect(tile, findsOneWidget);
        await tester.tap(tile);
        await tester.pumpAndSettle();

        exception = tester.takeException();
        expect(
          exception,
          isNull,
          reason: 'VaultCollectionViewSliver expanded section must not overflow on 320px at 1.5x text scale',
        );
      },
    );
  });
}
