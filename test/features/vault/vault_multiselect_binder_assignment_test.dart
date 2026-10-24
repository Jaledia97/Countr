import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/hydration/data/services/scryfall_service.dart';
import 'package:countr/features/hydration/presentation/providers/hydration_providers.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/screens/vault_screen.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_card.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_tile.dart';

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

  VaultItem createCard({
    required String id,
    required String name,
    required int quantity,
    double marketPrice = 10.0,
    double acquiredPrice = 0.0,
    String? primaryBinderId,
    String condition = 'NM',
    String collectionType = 'mtg',
  }) {
    return VaultItem(
      id: id,
      collectionType: collectionType,
      name: name,
      setOrSeries: 'MH3',
      imageUrl: 'https://example.com/$id.jpg',
      acquiredPrice: acquiredPrice,
      acquiredDate: DateTime(2026, 1, 1),
      quantity: quantity,
      condition: condition,
      isGraded: false,
      isAltered: false,
      isMisprint: false,
      isSigned: false,
      isDeleted: false,
      currentMarketPrice: marketPrice,
      lastPriceUpdate: DateTime.now(),
      dynamicData: jsonEncode({
        'collector_number': '100',
        'set': 'mh3',
        'oracle_text': 'Card description',
      }),
      personalNotes: null,
      primaryBinderId: primaryBinderId,
    );
  }

  Widget createHarness({
    required Widget child,
    List<Override> overrides = const [],
  }) {
    final mockScryfall = ScryfallService(
      client: MockClient((request) async {
        return http.Response(jsonEncode({'object': 'list', 'data': []}), 200);
      }),
    );

    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        vaultDaoProvider.overrideWithValue(db.vaultDao),
        scryfallServiceProvider.overrideWithValue(mockScryfall),
        activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
        vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
        cardDisplayLayoutProvider.overrideWith((ref) => CardDisplayLayout.grid),
        ...overrides,
      ],
      child: MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(size: Size(1080, 2400)),
            child: child,
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 1. VaultDao.assignItemsToBinder Promotion & Transaction Tests
  // ===========================================================================
  group('VaultDao.assignItemsToBinder Unit Tests', () {
    test('Promotes unowned card (quantity == 0) to quantity 1 with acquired details', () async {
      final binder = await db.vaultDao.createBinder(
        name: 'Modern Staples',
        collectionType: 'mtg',
      );

      final unowned = createCard(
        id: 'unowned-card-1',
        name: 'Mox Diamond',
        quantity: 0,
        marketPrice: 650.0,
      );
      await db.vaultDao.into(db.vaultItems).insert(unowned);

      final count = await db.vaultDao.assignItemsToBinder(['unowned-card-1'], binder.id);
      expect(count, equals(1));

      final itemInDb = await db.vaultDao.getItemById('unowned-card-1');
      expect(itemInDb, isNotNull);
      expect(itemInDb!.quantity, equals(1));
      expect(itemInDb.primaryBinderId, equals(binder.id));
      expect(itemInDb.acquiredPrice, equals(650.0));
      expect(itemInDb.isDeleted, isFalse);

      final syncEntries = await (db.vaultDao.select(db.vaultDao.syncQueue)
            ..where((t) => t.entityId.equals('unowned-card-1')))
          .get();
      expect(syncEntries.isNotEmpty, isTrue);
      expect(syncEntries.first.operation, equals('UPDATE'));
    });

    test('Preserves owned card attributes while updating primaryBinderId', () async {
      final binder = await db.vaultDao.createBinder(
        name: 'Foil Binder',
        collectionType: 'mtg',
      );

      final owned = createCard(
        id: 'owned-card-1',
        name: 'Force of Will',
        quantity: 2,
        marketPrice: 80.0,
        acquiredPrice: 45.0,
        condition: 'LP',
        primaryBinderId: 'INBOX',
      );
      await db.vaultDao.into(db.vaultItems).insert(owned);

      final count = await db.vaultDao.assignItemsToBinder(['owned-card-1'], binder.id);
      expect(count, equals(1));

      final itemInDb = await db.vaultDao.getItemById('owned-card-1');
      expect(itemInDb, isNotNull);
      expect(itemInDb!.quantity, equals(2));
      expect(itemInDb.acquiredPrice, equals(45.0));
      expect(itemInDb.condition, equals('LP'));
      expect(itemInDb.primaryBinderId, equals(binder.id));
    });

    test('Atomically handles mixed list of unowned and owned cards in transaction', () async {
      final binder = await db.vaultDao.createBinder(
        name: 'Commander Binder',
        collectionType: 'mtg',
      );

      final unowned = createCard(
        id: 'unowned-mix',
        name: 'Mana Vault',
        quantity: 0,
        marketPrice: 75.0,
      );
      final owned = createCard(
        id: 'owned-mix',
        name: 'Sol Ring',
        quantity: 4,
        marketPrice: 2.5,
        acquiredPrice: 1.5,
      );

      await db.vaultDao.into(db.vaultItems).insert(unowned);
      await db.vaultDao.into(db.vaultItems).insert(owned);

      final count = await db.vaultDao.assignItemsToBinder(
        ['unowned-mix', 'owned-mix'],
        binder.id,
      );
      expect(count, equals(2));

      final unownedAfter = await db.vaultDao.getItemById('unowned-mix');
      expect(unownedAfter!.quantity, equals(1));
      expect(unownedAfter.primaryBinderId, equals(binder.id));

      final ownedAfter = await db.vaultDao.getItemById('owned-mix');
      expect(ownedAfter!.quantity, equals(4));
      expect(ownedAfter.acquiredPrice, equals(1.5));
      expect(ownedAfter.primaryBinderId, equals(binder.id));
    });
  });

  // ===========================================================================
  // 2. CardDetailSheet Move & Binder Assignment Tests
  // ===========================================================================
  group('CardDetailSheet Binder Assignment Widget Tests', () {
    testWidgets('Unowned card shows "Add to Binder" / Move and stays mounted on assignment', (tester) async {
      final binder = await db.vaultDao.createBinder(
        name: 'Wishlist Binder',
        collectionType: 'mtg',
      );

      final unowned = createCard(
        id: 'c-unowned-sheet',
        name: 'Black Lotus',
        quantity: 0,
        marketPrice: 10000.0,
      );
      await db.vaultDao.into(db.vaultItems).insert(unowned);

      await tester.pumpWidget(createHarness(
        child: Builder(
          builder: (context) => ElevatedButton(
            key: const Key('open_sheet'),
            onPressed: () => CardDetailSheet.show(
              context,
              unowned,
              fetchOnlinePrintings: false,
            ),
            child: const Text('Open'),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_sheet')));
      await tester.pumpAndSettle();

      // CardDetailSheet should be visible
      expect(find.byType(CardDetailSheet), findsOneWidget);

      // In unowned state, "Add to +" action is rendered
      final addPlusButton = find.byKey(const Key('quick_action_add_to_plus'));
      expect(addPlusButton, findsOneWidget);

      // Tap "Add to +"
      await tester.tap(addPlusButton);
      await tester.pumpAndSettle();

      // Tap "Binders" option in selector modal
      final bindersOption = find.byKey(const Key('add_to_binders_option'));
      expect(bindersOption, findsOneWidget);
      await tester.tap(bindersOption);
      await tester.pumpAndSettle();

      // Destination binder should appear in the modal
      final binderOption = find.byKey(Key('move_to_binder_${binder.id}'));
      expect(binderOption, findsOneWidget);

      // Select binder
      await tester.tap(binderOption);
      await tester.pumpAndSettle();

      // Sheet must remain mounted!
      expect(find.byType(CardDetailSheet), findsOneWidget);

      // SnackBar confirmation is displayed
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('Moved Black Lotus to ${binder.name}'), findsOneWidget);

      // Verify card promoted in SQLite
      final inDb = await db.vaultDao.getItemById('c-unowned-sheet');
      expect(inDb, isNotNull);
      expect(inDb!.quantity, equals(1));
      expect(inDb.primaryBinderId, equals(binder.id));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('Owned card opened from Singles view renders "Move" action', (tester) async {
      final binderA = await db.vaultDao.createBinder(
        name: 'Binder Alpha',
        collectionType: 'mtg',
      );
      final binderB = await db.vaultDao.createBinder(
        name: 'Binder Beta',
        collectionType: 'mtg',
      );

      final owned = createCard(
        id: 'c-owned-singles',
        name: 'Tarmogoyf',
        quantity: 1,
        marketPrice: 20.0,
        acquiredPrice: 15.0,
        primaryBinderId: binderA.id,
      );
      await db.vaultDao.into(db.vaultItems).insert(owned);

      await tester.pumpWidget(createHarness(
        child: Builder(
          builder: (context) => ElevatedButton(
            key: const Key('open_sheet_owned'),
            onPressed: () => CardDetailSheet.show(
              context,
              owned,
              // Opened from Singles view (binderId is null)
              binderId: null,
              fetchOnlinePrintings: false,
            ),
            child: const Text('Open'),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_sheet_owned')));
      await tester.pumpAndSettle();

      // "Move" button must be rendered for owned cards even without binderId
      final moveButton = find.byKey(const Key('quick_action_move_binder'));
      expect(moveButton, findsOneWidget);

      // Tap Move
      await tester.tap(moveButton);
      await tester.pumpAndSettle();

      // Current binder option is marked disabled / current
      expect(find.text('Current'), findsOneWidget);

      // Destination binder B is available
      final binderBOption = find.byKey(Key('move_to_binder_${binderB.id}'));
      expect(binderBOption, findsOneWidget);

      // Select binder B
      await tester.tap(binderBOption);
      await tester.pumpAndSettle();

      // Sheet stays mounted
      expect(find.byType(CardDetailSheet), findsOneWidget);
      expect(find.textContaining('Moved Tarmogoyf to ${binderB.name}'), findsOneWidget);

      // Card is updated in DB
      final inDb = await db.vaultDao.getItemById('c-owned-singles');
      expect(inDb!.primaryBinderId, equals(binderB.id));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });
  });

  // ===========================================================================
  // 3. VaultScreen Multi-Select Mode Widget Tests
  // ===========================================================================
  group('VaultScreen Multi-Select Mode Tests', () {
    testWidgets('Long press activates multi-select mode, tap toggles, and cancel dismisses', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final card1 = createCard(id: 'multi-c1', name: 'Card One', quantity: 1);
      final card2 = createCard(id: 'multi-c2', name: 'Card Two', quantity: 1);
      await db.vaultDao.into(db.vaultItems).insert(card1);
      await db.vaultDao.into(db.vaultItems).insert(card2);

      await tester.pumpWidget(createHarness(
        child: const VaultScreen(),
        overrides: [
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
          cardDisplayLayoutProvider.overrideWith((ref) => CardDisplayLayout.grid),
        ],
      ));
      await tester.pumpAndSettle();

      // Floating action bar is not visible initially
      expect(find.byKey(const Key('vault_selection_move_binder_button')), findsNothing);
      expect(find.byKey(const Key('vault_selection_cancel_button')), findsNothing);

      // Long press first tile to activate multi-select
      final tileFinder1 = find.widgetWithText(VaultItemTile, 'Card One');
      expect(tileFinder1, findsOneWidget);
      await tester.longPress(tileFinder1);
      await tester.pumpAndSettle();

      // Floating action bar appears with count 1
      expect(find.byKey(const Key('vault_selection_move_binder_button')), findsOneWidget);
      expect(find.text('Move to Binder (1)'), findsOneWidget);
      expect(find.byKey(const Key('vault_selection_cancel_button')), findsOneWidget);

      // Regular tap on second tile adds it to selection
      final tileFinder2 = find.widgetWithText(VaultItemTile, 'Card Two');
      await tester.tap(tileFinder2);
      await tester.pumpAndSettle();

      // Count updates to 2
      expect(find.text('Move to Binder (2)'), findsOneWidget);

      // Tap Cancel button dismisses selection mode
      await tester.tap(find.byKey(const Key('vault_selection_cancel_button')));
      await tester.pumpAndSettle();

      // Floating bar is removed
      expect(find.byKey(const Key('vault_selection_move_binder_button')), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('Back button via PopScope clears multi-selection mode', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final card1 = createCard(id: 'pop-c1', name: 'Card Alpha', quantity: 1);
      await db.vaultDao.into(db.vaultItems).insert(card1);

      await tester.pumpWidget(createHarness(
        child: const VaultScreen(),
        overrides: [
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
          cardDisplayLayoutProvider.overrideWith((ref) => CardDisplayLayout.grid),
        ],
      ));
      await tester.pumpAndSettle();

      // Long press to enter selection mode
      await tester.longPress(find.widgetWithText(VaultItemTile, 'Card Alpha'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('vault_selection_move_binder_button')), findsOneWidget);

      // Simulate physical back button via handlePopRoute
      final handled = await tester.binding.handlePopRoute();
      expect(handled, isTrue); // Pop was intercepted by PopScope
      await tester.pumpAndSettle();

      // Multi-selection is dismissed, floating bar gone
      expect(find.byKey(const Key('vault_selection_move_binder_button')), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('Multi-select "Move to Binder" assigns multiple cards and clears selection', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final binder = await db.vaultDao.createBinder(
        name: 'Multi Destination',
        collectionType: 'mtg',
      );

      final card1 = createCard(id: 'assign-c1', name: 'Card X', quantity: 1);
      final card2 = createCard(id: 'assign-c2', name: 'Card Y', quantity: 1);
      await db.vaultDao.into(db.vaultItems).insert(card1);
      await db.vaultDao.into(db.vaultItems).insert(card2);

      await tester.pumpWidget(createHarness(
        child: const VaultScreen(),
        overrides: [
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
          cardDisplayLayoutProvider.overrideWith((ref) => CardDisplayLayout.grid),
        ],
      ));
      await tester.pumpAndSettle();

      // Select both cards
      await tester.longPress(find.widgetWithText(VaultItemTile, 'Card X'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(VaultItemTile, 'Card Y'));
      await tester.pumpAndSettle();

      // Tap "Move to Binder (2)"
      await tester.tap(find.byKey(const Key('vault_selection_move_binder_button')));
      await tester.pumpAndSettle();

      // Modal appears with binder option
      final binderOption = find.byKey(Key('vault_binder_option_${binder.id}'));
      expect(binderOption, findsOneWidget);

      // Tap binder option
      await tester.tap(binderOption);
      await tester.pumpAndSettle();

      // SnackBar appears
      expect(find.textContaining('Assigned 2 cards to "Multi Destination"'), findsOneWidget);

      // Selection mode is cleared
      expect(find.byKey(const Key('vault_selection_move_binder_button')), findsNothing);

      // DB is updated
      final updated1 = await db.vaultDao.getItemById('assign-c1');
      final updated2 = await db.vaultDao.getItemById('assign-c2');
      expect(updated1!.primaryBinderId, equals(binder.id));
      expect(updated2!.primaryBinderId, equals(binder.id));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('List view layout (VaultItemCard) supports multi-select long press and toggle', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final card1 = createCard(id: 'list-c1', name: 'Card Alpha', quantity: 1);
      final card2 = createCard(id: 'list-c2', name: 'Card Beta', quantity: 1);
      await db.vaultDao.into(db.vaultItems).insert(card1);
      await db.vaultDao.into(db.vaultItems).insert(card2);

      await tester.pumpWidget(createHarness(
        child: const VaultScreen(),
        overrides: [
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
          cardDisplayLayoutProvider.overrideWith((ref) => CardDisplayLayout.list),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.byType(VaultItemCard), findsNWidgets(2));
      expect(find.byKey(const Key('vault_selection_move_binder_button')), findsNothing);

      // Long press card 1
      await tester.longPress(find.widgetWithText(VaultItemCard, 'Card Alpha'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('vault_selection_move_binder_button')), findsOneWidget);
      expect(find.text('Move to Binder (1)'), findsOneWidget);

      // Tap card 2
      await tester.tap(find.widgetWithText(VaultItemCard, 'Card Beta'));
      await tester.pumpAndSettle();

      expect(find.text('Move to Binder (2)'), findsOneWidget);

      // Tap Cancel
      await tester.tap(find.byKey(const Key('vault_selection_cancel_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('vault_selection_move_binder_button')), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('Filter chip selection automatically clears active card selection', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final card = createCard(id: 'chip-c1', name: 'Chip Card', quantity: 1);
      await db.vaultDao.into(db.vaultItems).insert(card);

      await tester.pumpWidget(createHarness(
        child: const VaultScreen(),
        overrides: [
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
          cardDisplayLayoutProvider.overrideWith((ref) => CardDisplayLayout.grid),
        ],
      ));
      await tester.pumpAndSettle();

      // Long press to select
      await tester.longPress(find.widgetWithText(VaultItemTile, 'Chip Card'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('vault_selection_move_binder_button')), findsOneWidget);

      // Tap "All Cards" filter chip
      final allCardsChip = find.byKey(const Key('vault_filter_chip_catalog_(ref)'));
      if (allCardsChip.evaluate().isNotEmpty) {
        await tester.tap(allCardsChip);
        await tester.pumpAndSettle();

        // Selection should be cleared
        expect(find.byKey(const Key('vault_selection_move_binder_button')), findsNothing);
      }

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });
  });

  // ===========================================================================
  // 4. VaultItemTile & VaultItemCard Visual Selection Parameter Tests
  // ===========================================================================
  group('Tile & Card Selection Visuals Unit/Widget Tests', () {
    testWidgets('VaultItemTile renders cyan border and checkmark when selected', (tester) async {
      final item = createCard(id: 'tile-vis', name: 'Visual Tile', quantity: 1);

      await tester.pumpWidget(createHarness(
        child: VaultItemTile(
          item: item,
          isSelected: true,
          isSelectionMode: true,
        ),
      ));
      await tester.pumpAndSettle();

      // In selection mode and selected, checkmark icon is rendered
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    testWidgets('VaultItemTile renders unchecked circle when selection mode is active but not selected', (tester) async {
      final item = createCard(id: 'tile-unsel', name: 'Unselected Tile', quantity: 1);

      await tester.pumpWidget(createHarness(
        child: VaultItemTile(
          item: item,
          isSelected: false,
          isSelectionMode: true,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.radio_button_unchecked_rounded), findsOneWidget);
    });

    testWidgets('VaultItemCard renders cyan border and checkmark when selected', (tester) async {
      final item = createCard(id: 'card-vis', name: 'Visual Card', quantity: 1);

      await tester.pumpWidget(createHarness(
        child: VaultItemCard(
          item: item,
          isSelected: true,
          isSelectionMode: true,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });
  });
}
