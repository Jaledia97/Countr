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
    double marketPrice = 15.0,
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
        'collector_number': '101',
        'set': 'mh3',
        'oracle_text': 'Adversarial test card',
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
  // SUITE 1: CardDetailSheet Invariants & State Reactivity
  // ===========================================================================
  group('CardDetailSheet Invariants & State Reactivity', () {
    testWidgets('Assigning unowned card to binder updates quick actions to Move, increases quantity to 1, and stays mounted', (tester) async {
      final binder = await db.vaultDao.createBinder(
        name: 'Mythic Rare Binder',
        collectionType: 'mtg',
      );

      final unowned = createCard(
        id: 'adv-unowned-1',
        name: 'The One Ring',
        quantity: 0,
        marketPrice: 95.0,
      );
      await db.vaultDao.into(db.vaultItems).insert(unowned);

      await tester.pumpWidget(createHarness(
        child: Builder(
          builder: (context) => ElevatedButton(
            key: const Key('open_sheet_btn'),
            onPressed: () => CardDetailSheet.show(
              context,
              unowned,
              fetchOnlinePrintings: false,
            ),
            child: const Text('Open Detail'),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_sheet_btn')));
      await tester.pumpAndSettle();

      // Initial state: unowned card
      expect(find.byType(CardDetailSheet), findsOneWidget);
      expect(find.text('unowned'), findsOneWidget);
      expect(find.byKey(const Key('quick_action_add_to_plus')), findsOneWidget);
      expect(find.byKey(const Key('quick_action_move_binder')), findsNothing);
      expect(find.byKey(const Key('quick_action_add_to_deck')), findsNothing);
      expect(find.byKey(const Key('quick_action_delete')), findsNothing);

      // Open Add to + -> Binders
      await tester.tap(find.byKey(const Key('quick_action_add_to_plus')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('add_to_binders_option')));
      await tester.pumpAndSettle();

      // Select destination binder
      final binderTile = find.byKey(Key('move_to_binder_${binder.id}'));
      expect(binderTile, findsOneWidget);
      await tester.tap(binderTile);
      await tester.pumpAndSettle();

      // Invariant 1: Sheet stays mounted!
      expect(find.byType(CardDetailSheet), findsOneWidget);

      // Invariant 2: Quick actions transition from unowned to owned actions
      expect(find.byKey(const Key('quick_action_add_to_plus')), findsNothing);
      expect(find.byKey(const Key('quick_action_move_binder')), findsOneWidget);
      expect(find.byKey(const Key('quick_action_add_to_deck')), findsOneWidget);
      expect(find.byKey(const Key('quick_action_delete')), findsOneWidget);

      // Invariant 3: Owned Copies metric box reflects 1x
      expect(find.text('1x'), findsWidgets);
      expect(find.text('Switch Printing'), findsOneWidget);

      // Invariant 4: SnackBar confirmation displayed
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('Moved The One Ring to ${binder.name}'), findsOneWidget);

      // Invariant 5: Database reflects promotion (quantity = 1, primaryBinderId set, sleeved)
      final inDb = await db.vaultDao.getItemById('adv-unowned-1');
      expect(inDb, isNotNull);
      expect(inDb!.quantity, equals(1));
      expect(inDb.primaryBinderId, equals(binder.id));
      expect(inDb.acquiredPrice, equals(95.0));
      expect(inDb.protectionStatus, equals('Sleeved'));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('Moving owned card between binders and to Inbox correctly updates current indicators and database', (tester) async {
      final binderA = await db.vaultDao.createBinder(
        name: 'Vintage Binder',
        collectionType: 'mtg',
      );
      final binderB = await db.vaultDao.createBinder(
        name: 'Modern Binder',
        collectionType: 'mtg',
      );

      final card = createCard(
        id: 'adv-owned-move',
        name: 'Ragavan, Nimble Pilferer',
        quantity: 1,
        marketPrice: 50.0,
        acquiredPrice: 40.0,
        primaryBinderId: binderA.id,
      );
      await db.vaultDao.into(db.vaultItems).insert(card);

      await tester.pumpWidget(createHarness(
        child: Builder(
          builder: (context) => ElevatedButton(
            key: const Key('open_sheet_move'),
            onPressed: () => CardDetailSheet.show(
              context,
              card,
              binderId: null, // Global singles view
              fetchOnlinePrintings: false,
            ),
            child: const Text('Open'),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_sheet_move')));
      await tester.pumpAndSettle();

      // Step 1: Tap Move button
      final moveBtn = find.byKey(const Key('quick_action_move_binder'));
      expect(moveBtn, findsOneWidget);
      await tester.tap(moveBtn);
      await tester.pumpAndSettle();

      // Binder A is marked Current (disabled)
      final binderATile = find.byKey(Key('move_to_binder_${binderA.id}'));
      expect(binderATile, findsOneWidget);
      expect(find.descendant(of: binderATile, matching: find.text('Current')), findsOneWidget);

      // Binder B and Inbox are available
      final binderBTile = find.byKey(Key('move_to_binder_${binderB.id}'));
      final inboxTile = find.byKey(const Key('move_to_inbox_tile'));
      expect(binderBTile, findsOneWidget);
      expect(inboxTile, findsOneWidget);

      // Step 2: Move to Binder B
      await tester.tap(binderBTile);
      await tester.pumpAndSettle();

      expect(find.byType(CardDetailSheet), findsOneWidget);
      expect(find.textContaining('Moved Ragavan, Nimble Pilferer to ${binderB.name}'), findsOneWidget);

      var dbCard = await db.vaultDao.getItemById('adv-owned-move');
      expect(dbCard!.primaryBinderId, equals(binderB.id));

      // Dismiss snackbar
      await tester.pump(const Duration(seconds: 4));

      // Step 3: Tap Move again -> verify Binder B is now Current, Binder A is available
      await tester.tap(moveBtn);
      await tester.pumpAndSettle();

      expect(find.descendant(of: find.byKey(Key('move_to_binder_${binderB.id}')), matching: find.text('Current')), findsOneWidget);
      expect(find.descendant(of: find.byKey(Key('move_to_binder_${binderA.id}')), matching: find.text('Current')), findsNothing);

      // Step 4: Move to Inbox
      await tester.tap(find.byKey(const Key('move_to_inbox_tile')));
      await tester.pumpAndSettle();

      expect(find.byType(CardDetailSheet), findsOneWidget);
      expect(find.textContaining('Moved Ragavan, Nimble Pilferer to Inbox'), findsOneWidget);

      dbCard = await db.vaultDao.getItemById('adv-owned-move');
      expect(dbCard!.primaryBinderId, equals('INBOX'));

      // Dismiss snackbar
      await tester.pump(const Duration(seconds: 4));

      // Step 5: Tap Move again -> verify Inbox is now Current!
      await tester.tap(moveBtn);
      await tester.pumpAndSettle();

      expect(find.descendant(of: find.byKey(const Key('move_to_inbox_tile')), matching: find.text('Current')), findsOneWidget);
      expect(find.descendant(of: find.byKey(Key('move_to_binder_${binderA.id}')), matching: find.text('Current')), findsNothing);

      // Close modal using top-most close button
      await tester.tap(find.byIcon(Icons.close).last);
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('Assigning card in multi-card sheet preserves promoted state when swiping back and forth', (tester) async {
      final binder = await db.vaultDao.createBinder(
        name: 'Swiping Test Binder',
        collectionType: 'mtg',
      );

      final card1 = createCard(id: 'swipe-c1', name: 'Mox Ruby', quantity: 0, marketPrice: 5000.0);
      final card2 = createCard(id: 'swipe-c2', name: 'Black Lotus', quantity: 0, marketPrice: 10000.0);
      await db.vaultDao.into(db.vaultItems).insert(card1);
      await db.vaultDao.into(db.vaultItems).insert(card2);

      await tester.pumpWidget(createHarness(
        child: Builder(
          builder: (context) => ElevatedButton(
            key: const Key('open_multi_sheet'),
            onPressed: () => CardDetailSheet.show(
              context,
              card1,
              items: [card1, card2],
              initialIndex: 0,
              fetchOnlinePrintings: false,
            ),
            child: const Text('Open Multi'),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_multi_sheet')));
      await tester.pumpAndSettle();

      // Card 1 is unowned: has "Add to +"
      expect(find.byKey(const Key('quick_action_add_to_plus')), findsOneWidget);

      // Add Card 1 to binder
      await tester.tap(find.byKey(const Key('quick_action_add_to_plus')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('add_to_binders_option')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('move_to_binder_${binder.id}')));
      await tester.pumpAndSettle();

      // Card 1 is now promoted: has "Move"
      expect(find.byKey(const Key('quick_action_move_binder')), findsOneWidget);
      expect(find.byKey(const Key('quick_action_add_to_plus')), findsNothing);

      // Dismiss snackbar
      await tester.pump(const Duration(seconds: 4));

      // Swipe to Card 2 (horizontal drag from right to left)
      await tester.drag(find.byType(PageView), const Offset(-500, 0));
      await tester.pumpAndSettle();

      // Card 2 is unowned: must have "Add to +", NOT "Move"
      expect(find.text('Black Lotus'), findsWidgets);
      expect(find.byKey(const Key('quick_action_add_to_plus')), findsOneWidget);
      expect(find.byKey(const Key('quick_action_move_binder')), findsNothing);

      // Swipe back to Card 1 (horizontal drag from left to right)
      await tester.drag(find.byType(PageView), const Offset(500, 0));
      await tester.pumpAndSettle();

      // Card 1 must retain its promoted state: "Move" present, "Add to +" absent!
      expect(find.text('Mox Ruby'), findsWidgets);
      expect(find.byKey(const Key('quick_action_move_binder')), findsOneWidget);
      expect(find.byKey(const Key('quick_action_add_to_plus')), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });
  });

  // ===========================================================================
  // SUITE 2: Adversarial Challenge: Rapid Tapping Re-entrancy Defect Checks
  // ===========================================================================
  group('Adversarial Challenge: Re-entrancy & Rapid Tapping', () {
    testWidgets('BUG CHECK: Rapidly tapping binder option must not pop CardDetailSheet', (tester) async {
      final binder = await db.vaultDao.createBinder(
        name: 'Rapid Tap Binder',
        collectionType: 'mtg',
      );

      final card = createCard(
        id: 'adv-rapid-tap',
        name: 'Lightning Bolt',
        quantity: 1,
        primaryBinderId: 'INBOX',
      );
      await db.vaultDao.into(db.vaultItems).insert(card);

      await tester.pumpWidget(createHarness(
        child: Builder(
          builder: (context) => ElevatedButton(
            key: const Key('open_rapid'),
            onPressed: () => CardDetailSheet.show(
              context,
              card,
              fetchOnlinePrintings: false,
            ),
            child: const Text('Open'),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_rapid')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('quick_action_move_binder')));
      await tester.pumpAndSettle();

      final destinationTile = find.byKey(Key('move_to_binder_${binder.id}'));
      expect(destinationTile, findsOneWidget);

      // Simulate a user double-tapping the binder option quickly
      await tester.tap(destinationTile);
      await tester.tap(destinationTile);
      await tester.pumpAndSettle();

      // EMPIRICAL ASSERTION: CardDetailSheet should stay mounted!
      final sheetExists = find.byType(CardDetailSheet).evaluate().isNotEmpty;
      expect(sheetExists, isTrue, reason: 'Rapidly double tapping a binder option caused CardDetailSheet to pop!');

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('BUG CHECK: Rapidly tapping Inbox tile must not pop CardDetailSheet', (tester) async {
      final binder = await db.vaultDao.createBinder(
        name: 'Origin Binder',
        collectionType: 'mtg',
      );

      final card = createCard(
        id: 'adv-rapid-inbox',
        name: 'Counterspell',
        quantity: 1,
        primaryBinderId: binder.id,
      );
      await db.vaultDao.into(db.vaultItems).insert(card);

      await tester.pumpWidget(createHarness(
        child: Builder(
          builder: (context) => ElevatedButton(
            key: const Key('open_rapid_inbox'),
            onPressed: () => CardDetailSheet.show(
              context,
              card,
              binderId: binder.id,
              fetchOnlinePrintings: false,
            ),
            child: const Text('Open'),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_rapid_inbox')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('quick_action_move_binder')));
      await tester.pumpAndSettle();

      final inboxTile = find.byKey(const Key('move_to_inbox_tile'));
      expect(inboxTile, findsOneWidget);

      // Rapidly double tap Inbox tile
      await tester.tap(inboxTile);
      await tester.tap(inboxTile);
      await tester.pumpAndSettle();

      final sheetExists = find.byType(CardDetailSheet).evaluate().isNotEmpty;
      expect(sheetExists, isTrue, reason: 'Rapidly double tapping Inbox tile caused CardDetailSheet to pop!');

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('BUG CHECK: Rapidly tapping binder option in VaultScreen multi-select must not pop VaultScreen', (tester) async {
      final binder = await db.vaultDao.createBinder(
        name: 'Bulk Target Binder',
        collectionType: 'mtg',
      );

      final card = createCard(
        id: 'adv-multiselect-rapid',
        name: 'Birds of Paradise',
        quantity: 1,
      );
      await db.vaultDao.into(db.vaultItems).insert(card);

      await tester.pumpWidget(createHarness(
        child: Builder(
          builder: (context) => ElevatedButton(
            key: const Key('push_vault_screen'),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const VaultScreen()),
              );
            },
            child: const Text('Go Vault'),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('push_vault_screen')));
      await tester.pumpAndSettle();

      expect(find.byType(VaultScreen), findsOneWidget);

      // Select card
      await tester.longPress(find.widgetWithText(VaultItemTile, 'Birds of Paradise'));
      await tester.pumpAndSettle();

      // Open multi-select modal
      await tester.tap(find.byKey(const Key('vault_selection_move_binder_button')));
      await tester.pumpAndSettle();

      final binderOption = find.byKey(Key('vault_binder_option_${binder.id}'));
      expect(binderOption, findsOneWidget);

      // Rapidly double tap binder option
      await tester.tap(binderOption);
      await tester.tap(binderOption);
      await tester.pumpAndSettle();

      // EMPIRICAL ASSERTION: VaultScreen must remain on screen, NOT popped!
      final vaultExists = find.byType(VaultScreen).evaluate().isNotEmpty;
      expect(vaultExists, isTrue, reason: 'Rapidly double tapping binder option in multi-select popped VaultScreen!');

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });
  });

  // ===========================================================================
  // SUITE 3: VaultScreen Multi-Select Lifecycle & Edge Cases
  // ===========================================================================
  group('VaultScreen Multi-Select Lifecycle & Stress Tests', () {
    testWidgets('Toggling item on and off returns cleanly to 0 selected without leaving stale bottom bar', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final card1 = createCard(id: 'toggle-c1', name: 'Snapcaster Mage', quantity: 1);
      final card2 = createCard(id: 'toggle-c2', name: 'Dark Confidant', quantity: 1);
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

      // Initially 0 selected, no bottom bar
      expect(find.byKey(const Key('vault_selection_move_binder_button')), findsNothing);

      // Long press card 1 -> 1 selected
      final tile1 = find.widgetWithText(VaultItemTile, 'Snapcaster Mage');
      await tester.longPress(tile1);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('vault_selection_move_binder_button')), findsOneWidget);
      expect(find.text('Move to Binder (1)'), findsOneWidget);

      // Tap card 1 again -> toggles off!
      await tester.tap(tile1);
      await tester.pumpAndSettle();

      // Invariant: Selection mode should cleanly exit, 0 selected, bottom bar dismissed!
      expect(find.byKey(const Key('vault_selection_move_binder_button')), findsNothing);
      expect(find.byKey(const Key('vault_selection_cancel_button')), findsNothing);
      expect(find.byIcon(Icons.radio_button_unchecked_rounded), findsNothing);

      // Subsequent tap on tile1 should open CardDetailSheet, not toggle selection!
      await tester.tap(tile1);
      await tester.pumpAndSettle();

      expect(find.byType(CardDetailSheet), findsOneWidget);

      // Close sheet using the header close button in CardDetailSheet
      final closeButtonFinder = find.descendant(
        of: find.byType(CardDetailSheet),
        matching: find.byIcon(Icons.close),
      );
      if (closeButtonFinder.evaluate().isNotEmpty) {
        await tester.tap(closeButtonFinder.first);
        await tester.pumpAndSettle();
      }

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('PopScope back button intercepts pop when selection active, then allows screen pop on second back', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final card1 = createCard(id: 'pop-c1', name: 'Cryptic Command', quantity: 1);
      await db.vaultDao.into(db.vaultItems).insert(card1);

      await tester.pumpWidget(createHarness(
        child: Builder(
          builder: (context) => ElevatedButton(
            key: const Key('push_vault'),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const VaultScreen()),
              );
            },
            child: const Text('Push Vault'),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Push VaultScreen on top of the root page
      await tester.tap(find.byKey(const Key('push_vault')));
      await tester.pumpAndSettle();

      expect(find.byType(VaultScreen), findsOneWidget);

      // Enter selection mode
      await tester.longPress(find.widgetWithText(VaultItemTile, 'Cryptic Command'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('vault_selection_move_binder_button')), findsOneWidget);

      // 1st back button press -> PopScope intercepts, screen does NOT pop!
      final firstPopHandled = await tester.binding.handlePopRoute();
      expect(firstPopHandled, isTrue, reason: 'Pop should be intercepted by PopScope when selection is active');
      await tester.pumpAndSettle();

      // VaultScreen is still mounted! Selection mode dismissed.
      expect(find.byType(VaultScreen), findsOneWidget);
      expect(find.byKey(const Key('vault_selection_move_binder_button')), findsNothing);

      // 2nd back button press -> now that selection is cleared, VaultScreen pops!
      final secondPopHandled = await tester.binding.handlePopRoute();
      expect(secondPopHandled, isTrue);
      await tester.pumpAndSettle();

      // VaultScreen is now popped, returning to root page!
      expect(find.byType(VaultScreen), findsNothing);
      expect(find.byKey(const Key('push_vault')), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('Switching view modes, game context, and catalog chips resets selection cleanly', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final card1 = createCard(id: 'ctx-c1', name: 'Brainstorm', quantity: 1);
      final card2 = createCard(id: 'ctx-c2', name: 'Ponder', quantity: 1);
      await db.vaultDao.into(db.vaultItems).insert(card1);
      await db.vaultDao.into(db.vaultItems).insert(card2);

      late WidgetRef capturedRef;

      await tester.pumpWidget(createHarness(
        child: Consumer(
          builder: (context, ref, child) {
            capturedRef = ref;
            return const VaultScreen();
          },
        ),
        overrides: [
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
          cardDisplayLayoutProvider.overrideWith((ref) => CardDisplayLayout.grid),
        ],
      ));
      await tester.pumpAndSettle();

      // Select card 1
      await tester.longPress(find.widgetWithText(VaultItemTile, 'Brainstorm'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('vault_selection_move_binder_button')), findsOneWidget);

      // 1. Switch View Mode to Binders -> selection resets
      capturedRef.read(vaultViewModeProvider.notifier).state = VaultViewMode.binders;
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('vault_selection_move_binder_button')), findsNothing);

      // Return to All Vault
      capturedRef.read(vaultViewModeProvider.notifier).state = VaultViewMode.allVault;
      await tester.pumpAndSettle();

      // Select card 2
      await tester.longPress(find.widgetWithText(VaultItemTile, 'Ponder'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('vault_selection_move_binder_button')), findsOneWidget);

      // 2. Switch Game Context -> selection resets
      capturedRef.read(activeGameContextProvider.notifier).state = 'Pokemon';
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('vault_selection_move_binder_button')), findsNothing);

      // Return to MTG
      capturedRef.read(activeGameContextProvider.notifier).state = 'Magic: The Gathering';
      await tester.pumpAndSettle();

      // Select card 1 again
      await tester.longPress(find.widgetWithText(VaultItemTile, 'Brainstorm'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('vault_selection_move_binder_button')), findsOneWidget);

      // 3. Switch Catalog Toggle -> selection resets
      capturedRef.read(vaultShowCatalogProvider.notifier).state = true;
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('vault_selection_move_binder_button')), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('Multi-selecting unowned catalog cards promotes all to quantity 1 and assigns to binder', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final binder = await db.vaultDao.createBinder(
        name: 'Bulk Catalog Ingestion',
        collectionType: 'mtg',
      );

      final c1 = createCard(id: 'cat-c1', name: 'Solitude', quantity: 0, marketPrice: 40.0);
      final c2 = createCard(id: 'cat-c2', name: 'Grief', quantity: 0, marketPrice: 20.0);
      await db.vaultDao.into(db.vaultItems).insert(c1);
      await db.vaultDao.into(db.vaultItems).insert(c2);

      await tester.pumpWidget(createHarness(
        child: const VaultScreen(),
        overrides: [
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
          vaultShowCatalogProvider.overrideWith((ref) => true),
          cardDisplayLayoutProvider.overrideWith((ref) => CardDisplayLayout.grid),
        ],
      ));
      await tester.pumpAndSettle();

      // Select both unowned cards
      await tester.longPress(find.widgetWithText(VaultItemTile, 'Solitude'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(VaultItemTile, 'Grief'));
      await tester.pumpAndSettle();

      expect(find.text('Move to Binder (2)'), findsOneWidget);

      // Tap Move to Binder (2)
      await tester.tap(find.byKey(const Key('vault_selection_move_binder_button')));
      await tester.pumpAndSettle();

      // Select destination binder
      final optionFinder = find.byKey(Key('vault_binder_option_${binder.id}'));
      expect(optionFinder, findsOneWidget);
      await tester.tap(optionFinder);
      await tester.pumpAndSettle();

      // Selection cleared, SnackBar shown
      expect(find.byKey(const Key('vault_selection_move_binder_button')), findsNothing);
      expect(find.textContaining('Assigned 2 cards to "Bulk Catalog Ingestion"'), findsOneWidget);

      // Verify both unowned cards in SQLite promoted to quantity 1 and assigned
      final dbC1 = await db.vaultDao.getItemById('cat-c1');
      final dbC2 = await db.vaultDao.getItemById('cat-c2');
      expect(dbC1!.quantity, equals(1));
      expect(dbC1.primaryBinderId, equals(binder.id));
      expect(dbC1.acquiredPrice, equals(40.0));
      expect(dbC1.protectionStatus, equals('Sleeved'));

      expect(dbC2!.quantity, equals(1));
      expect(dbC2.primaryBinderId, equals(binder.id));
      expect(dbC2.acquiredPrice, equals(20.0));
      expect(dbC2.protectionStatus, equals('Sleeved'));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });
  });
}
