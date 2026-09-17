import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';
import 'package:countr/features/vault/presentation/widgets/edit_card_modal.dart';
import 'package:countr/features/vault/presentation/widgets/full_screen_card_viewer.dart';

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

  VaultItem createTestCard({
    String id = 'adv-card-1',
    String name = 'Mox Diamond',
    String setOrSeries = 'Stronghold',
    double acquiredPrice = 450.0,
    double currentMarketPrice = 650.0,
    int quantity = 2,
    String condition = 'NM',
    bool isGraded = false,
    bool isAltered = false,
    bool isMisprint = false,
    bool isSigned = false,
    String dynamicData = '{"tags":["Reserved List"],"deck_history":["Commander - Urza"]}',
  }) {
    return VaultItem(
      id: id,
      collectionType: 'mtg',
      name: name,
      setOrSeries: setOrSeries,
      imageUrl: 'https://example.com/mox_diamond.jpg',
      acquiredPrice: acquiredPrice,
      acquiredDate: DateTime(2023, 5, 15),
      quantity: quantity,
      condition: condition,
      isGraded: isGraded,
      isAltered: isAltered,
      isMisprint: isMisprint,
      isSigned: isSigned,
      currentMarketPrice: currentMarketPrice,
      lastPriceUpdate: DateTime.now(),
      dynamicData: dynamicData,
    );
  }

  Future<void> seedCard(VaultItem item) async {
    await db.vaultDao.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: item.id,
            collectionType: item.collectionType,
            name: item.name,
            setOrSeries: item.setOrSeries,
            imageUrl: item.imageUrl,
            acquiredPrice: item.acquiredPrice,
            acquiredDate: item.acquiredDate,
            quantity: drift.Value(item.quantity),
            condition: item.condition,
            isGraded: drift.Value(item.isGraded),
            isAltered: drift.Value(item.isAltered),
            isMisprint: drift.Value(item.isMisprint),
            isSigned: drift.Value(item.isSigned),
            currentMarketPrice: item.currentMarketPrice,
            lastPriceUpdate: item.lastPriceUpdate,
            dynamicData: item.dynamicData,
          ),
        );
  }

  Widget createTestApp({
    required Widget child,
    List<Override> overrides = const [],
  }) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        vaultDaoProvider.overrideWithValue(db.vaultDao),
        ...overrides,
      ],
      child: MaterialApp(
        home: Scaffold(
          body: child,
        ),
      ),
    );
  }

  // ===========================================================================
  // CHALLENGE 1: Foil Animation Controller Lifecycle & Ticker Stress Harness
  // ===========================================================================
  group('Empirical Challenge 1: Foil Animation Lifecycle & Ticker Stress Harness', () {
    testWidgets('Rapidly toggle foil finish 20 times mid-frame without ticker crash or exception',
        (tester) async {
      final card = createTestCard();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FullScreenCardViewer(item: card),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final toggleFinder = find.byKey(const Key('fullscreen_foil_toggle'));
      expect(toggleFinder, findsOneWidget);
      expect(find.byType(ShaderMask), findsNothing);

      // Rapidly toggle foil on and off 20 times with variable micro-pumps (5ms to 50ms)
      for (int i = 0; i < 20; i++) {
        await tester.tap(toggleFinder);
        await tester.pump(Duration(milliseconds: 5 + (i * 2)));

        if (i % 2 == 0) {
          // Odd iteration count -> foil should be active (ShaderMask mounted)
          expect(find.byType(ShaderMask), findsOneWidget,
              reason: 'ShaderMask should be active after toggle $i (ON)');
        } else {
          // Even iteration count -> foil should be deactivated (ShaderMask unmounted)
          expect(find.byType(ShaderMask), findsNothing,
              reason: 'ShaderMask should be unmounted after toggle $i (OFF)');
        }

        expect(tester.takeException(), isNull,
            reason: 'Zero exceptions during rapid foil toggle iteration $i');
      }

      // Ensure foil is off and settled
      if (find.byType(ShaderMask).evaluate().isNotEmpty) {
        await tester.tap(toggleFinder);
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(ShaderMask), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Unmount FullScreenCardViewer while foil animation is actively repeating without ticker leaks',
        (tester) async {
      final card = createTestCard();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                key: const Key('open_fullscreen_button'),
                onPressed: () => FullScreenCardViewer.show(context, card),
                child: const Text('Open Fullscreen'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open fullscreen
      await tester.tap(find.byKey(const Key('open_fullscreen_button')));
      await tester.pumpAndSettle();

      expect(find.byType(FullScreenCardViewer), findsOneWidget);

      // Turn foil finish ON so the animation controller is actively repeating
      await tester.tap(find.byKey(const Key('fullscreen_foil_toggle')));
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.byType(ShaderMask), findsOneWidget);

      // Close the viewer while foil animation is actively looping
      await tester.tap(find.byKey(const Key('fullscreen_close_button')));
      // pumpAndSettle will verify that dispose() properly stopped/disposed the controller
      // without leaving active tickers hanging or throwing ticker assertion leaks.
      await tester.pumpAndSettle();

      expect(find.byType(FullScreenCardViewer), findsNothing);
      expect(tester.takeException(), isNull,
          reason: 'No ticker leak or uncaught exception after popping active foil viewer');
    });

    testWidgets('Repeatedly mount and unmount FullScreenCardViewer across 5 consecutive cycles',
        (tester) async {
      final card = createTestCard();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                key: const Key('open_fullscreen_button'),
                onPressed: () => FullScreenCardViewer.show(context, card),
                child: const Text('Open Fullscreen'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (int cycle = 0; cycle < 5; cycle++) {
        await tester.tap(find.byKey(const Key('open_fullscreen_button')));
        await tester.pumpAndSettle();

        expect(find.byType(FullScreenCardViewer), findsOneWidget);

        // Toggle foil on, advance frames
        await tester.tap(find.byKey(const Key('fullscreen_foil_toggle')));
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(ShaderMask), findsOneWidget);

        // Close while active
        await tester.tap(find.byKey(const Key('fullscreen_close_button')));
        await tester.pumpAndSettle();

        expect(find.byType(FullScreenCardViewer), findsNothing);
        expect(tester.takeException(), isNull,
            reason: 'Zero exceptions on mount/unmount cycle $cycle');
      }
    });
  });

  // ===========================================================================
  // CHALLENGE 2: Delete Confirmation Dialog Flow & Database Synchronization
  // ===========================================================================
  group('Empirical Challenge 2: Delete Confirmation Dialog & Database Synchronization', () {
    testWidgets('Cancelling delete dialog leaves SQLite record intact; confirming deletes item and dismisses sheet',
        (tester) async {
      final targetCard = createTestCard(id: 'target-card-to-delete', name: 'Target Mox');
      final neighborCard = createTestCard(id: 'neighbor-card-keep', name: 'Neighbor Mox');
      await seedCard(targetCard);
      await seedCard(neighborCard);

      // Verify both exist initially (target qty 2 + neighbor qty 2 = 4 items)
      var allItems = await db.vaultDao.select(db.vaultItems).get();
      expect(allItems.length, 2);

      // Track watchVaultTotals stream
      final totalsHistory = <int>[];
      final sub = db.vaultDao.watchVaultTotals(collectionType: 'mtg').listen((totals) {
        totalsHistory.add(totals.totalCount);
      });
      addTearDown(() => sub.cancel());

      await tester.pumpWidget(
        createTestApp(
          child: Builder(
            builder: (context) => ElevatedButton(
              key: const Key('open_sheet_btn'),
              onPressed: () => CardDetailSheet.show(context, targetCard),
              child: const Text('Open Sheet'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open sheet
      await tester.tap(find.byKey(const Key('open_sheet_btn')));
      await tester.pumpAndSettle();

      // Tap Delete in Quick Action Bar
      await tester.tap(find.byKey(const Key('quick_action_delete')));
      await tester.pumpAndSettle();

      // Verify dialog is presented
      expect(find.byKey(const Key('card_detail_delete_dialog')), findsOneWidget);
      expect(find.text('Delete Card?'), findsOneWidget);

      // CANCEL DELETION
      await tester.tap(find.byKey(const Key('delete_cancel_button')));
      await tester.pumpAndSettle();

      // Verify dialog dismissed, sheet remains open
      expect(find.byKey(const Key('card_detail_delete_dialog')), findsNothing);
      expect(find.byKey(const Key('card_detail_quick_action_bar')), findsOneWidget);

      // Verify target card still in SQLite
      var inDbTarget = await db.vaultDao.getItemById(targetCard.id);
      expect(inDbTarget, isNotNull, reason: 'Cancelling delete must keep card in SQLite');
      expect(inDbTarget!.id, targetCard.id);

      // CONFIRM DELETION
      await tester.tap(find.byKey(const Key('quick_action_delete')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('card_detail_delete_dialog')), findsOneWidget);
      await tester.tap(find.byKey(const Key('delete_confirm_button')));
      await tester.pumpAndSettle();

      // Verify target card is permanently deleted from SQLite
      inDbTarget = await db.vaultDao.getItemById(targetCard.id);
      expect(inDbTarget, isNull, reason: 'Confirming delete must remove card from SQLite');

      // Verify neighbor card remains intact
      final inDbNeighbor = await db.vaultDao.getItemById(neighborCard.id);
      expect(inDbNeighbor, isNotNull, reason: 'Other vault cards must not be deleted');

      // Verify bottom sheet dismissed
      expect(find.byKey(const Key('card_detail_quick_action_bar')), findsNothing);

      // Verify SnackBar was shown
      expect(find.textContaining('Removed "Target Mox" from Vault'), findsOneWidget);

      // Verify watchVaultTotals reactively reflected count reduction (from 4 to 2)
      await tester.pump(const Duration(milliseconds: 50));
      expect(totalsHistory, contains(2), reason: 'Total count must drop from 4 to 2');
      expect(tester.takeException(), isNull);
    });
  });

  // ===========================================================================
  // CHALLENGE 3: EditCardModal Extreme Overrides, Condition Matrix & Tag Stress
  // ===========================================================================
  group('Empirical Challenge 3: EditCardModal Extreme Overrides, Matrix & Tag Stress', () {
    testWidgets('Extreme price overrides (\$0.00, \$99,999.99, invalid, negative) persist and reflect reactively',
        (tester) async {
      tester.view.physicalSize = const Size(500, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final card = createTestCard(
        acquiredPrice: 100.0,
        currentMarketPrice: 200.0,
        quantity: 1,
      );
      await seedCard(card);

      final costBasisHistory = <double>[];
      final sub = db.vaultDao.watchVaultTotals(collectionType: 'mtg').listen((totals) {
        costBasisHistory.add(totals.totalCostBasis);
      });
      addTearDown(() => sub.cancel());

      await tester.pumpWidget(
        createTestApp(
          child: Builder(
            builder: (context) => ElevatedButton(
              key: const Key('open_sheet_btn'),
              onPressed: () => CardDetailSheet.show(context, card),
              child: const Text('Open Sheet'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_sheet_btn')));
      await tester.pumpAndSettle();

      // Sub-case A: $0.00 price override
      await tester.tap(find.byKey(const Key('quick_action_edit')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('edit_card_acquired_price_field')), '0.00');
      await tester.tap(find.byKey(const Key('save_card_edits_button')));
      await tester.pumpAndSettle();

      var inDb = await db.vaultDao.getItemById(card.id);
      expect(inDb!.acquiredPrice, 0.0, reason: '0.00 must persist exactly as 0.0');
      // Verify CardDetailSheet immediately displays $0.00 acquired price
      expect(find.text('\$0.00'), findsWidgets);

      // Sub-case B: $99,999.99 price override
      await tester.tap(find.byKey(const Key('quick_action_edit')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('edit_card_acquired_price_field')), '99999.99');
      await tester.tap(find.byKey(const Key('save_card_edits_button')));
      await tester.pumpAndSettle();

      inDb = await db.vaultDao.getItemById(card.id);
      expect(inDb!.acquiredPrice, 99999.99);
      expect(find.text('\$99999.99'), findsWidgets);

      // Sub-case C: Invalid / empty parsing fallback (e.g. non-numeric "abc")
      await tester.tap(find.byKey(const Key('quick_action_edit')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('edit_card_acquired_price_field')), 'not_a_number');
      await tester.tap(find.byKey(const Key('save_card_edits_button')));
      await tester.pumpAndSettle();

      inDb = await db.vaultDao.getItemById(card.id);
      expect(inDb!.acquiredPrice, 99999.99,
          reason: 'Invalid non-numeric input must gracefully fall back without crash');
      expect(tester.takeException(), isNull);

      // Sub-case D: Negative price override (-25.50)
      await tester.tap(find.byKey(const Key('quick_action_edit')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('edit_card_acquired_price_field')), '-25.50');
      await tester.tap(find.byKey(const Key('save_card_edits_button')));
      await tester.pumpAndSettle();

      inDb = await db.vaultDao.getItemById(card.id);
      expect(inDb!.acquiredPrice, -25.50);
      expect(tester.takeException(), isNull);

      // Verify watchVaultTotals captured updates
      await tester.pump(const Duration(milliseconds: 50));
      expect(costBasisHistory, contains(0.0));
      expect(costBasisHistory, contains(99999.99));
      expect(costBasisHistory, contains(-25.50));
    });

    testWidgets('Toggle all 4 condition checkboxes across multiple permutations without state collision',
        (tester) async {
      tester.view.physicalSize = const Size(500, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final card = createTestCard(
        isGraded: false,
        isAltered: false,
        isMisprint: false,
        isSigned: false,
      );
      await seedCard(card);

      await tester.pumpWidget(
        createTestApp(
          child: Builder(
            builder: (context) => ElevatedButton(
              key: const Key('open_sheet_btn'),
              onPressed: () => CardDetailSheet.show(context, card),
              child: const Text('Open Sheet'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_sheet_btn')));
      await tester.pumpAndSettle();

      // Permutation 1: Set all to TRUE
      await tester.tap(find.byKey(const Key('quick_action_edit')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('condition_checkbox_graded')));
      await tester.tap(find.byKey(const Key('condition_checkbox_graded')));
      await tester.tap(find.byKey(const Key('condition_checkbox_altered')));
      await tester.ensureVisible(find.byKey(const Key('condition_checkbox_misprint')));
      await tester.tap(find.byKey(const Key('condition_checkbox_misprint')));
      await tester.tap(find.byKey(const Key('condition_checkbox_signed')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('save_card_edits_button')));
      await tester.pumpAndSettle();

      var updated = await db.vaultDao.getItemById(card.id);
      expect(updated!.isGraded, isTrue);
      expect(updated.isAltered, isTrue);
      expect(updated.isMisprint, isTrue);
      expect(updated.isSigned, isTrue);

      // Permutation 2: Toggle Graded and Misprint back to FALSE, keep Altered and Signed TRUE
      await tester.tap(find.byKey(const Key('quick_action_edit')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('condition_checkbox_graded')));
      await tester.tap(find.byKey(const Key('condition_checkbox_graded')));
      await tester.ensureVisible(find.byKey(const Key('condition_checkbox_misprint')));
      await tester.tap(find.byKey(const Key('condition_checkbox_misprint')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('save_card_edits_button')));
      await tester.pumpAndSettle();

      updated = await db.vaultDao.getItemById(card.id);
      expect(updated!.isGraded, isFalse);
      expect(updated.isAltered, isTrue);
      expect(updated.isMisprint, isFalse);
      expect(updated.isSigned, isTrue);

      // Permutation 3: Toggle Altered and Signed to FALSE -> all false
      await tester.tap(find.byKey(const Key('quick_action_edit')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const Key('condition_checkbox_altered')));
      await tester.tap(find.byKey(const Key('condition_checkbox_altered')));
      await tester.ensureVisible(find.byKey(const Key('condition_checkbox_signed')));
      await tester.tap(find.byKey(const Key('condition_checkbox_signed')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('save_card_edits_button')));
      await tester.pumpAndSettle();

      updated = await db.vaultDao.getItemById(card.id);
      expect(updated!.isGraded, isFalse);
      expect(updated.isAltered, isFalse);
      expect(updated.isMisprint, isFalse);
      expect(updated.isSigned, isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Stress test: Add 25 custom tags, verify Wrap layout, persistence, and individual deletion',
        (tester) async {
      tester.view.physicalSize = const Size(500, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final card = createTestCard(dynamicData: '{"tags":[],"deck_history":[]}');
      await seedCard(card);

      await tester.pumpWidget(
        createTestApp(
          child: Builder(
            builder: (context) => ElevatedButton(
              key: const Key('open_edit_btn'),
              onPressed: () => EditCardModal.show(context, card),
              child: const Text('Open Edit'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_edit_btn')));
      await tester.pumpAndSettle();

      final inputFinder = find.byKey(const Key('edit_card_tag_input'));
      final addBtnFinder = find.byKey(const Key('edit_card_add_tag_button'));

      // Add 25 distinct tags
      for (int i = 1; i <= 25; i++) {
        final tag = 'Tag-${i.toString().padLeft(2, '0')}';
        await tester.ensureVisible(inputFinder);
        await tester.enterText(inputFinder, tag);
        await tester.ensureVisible(addBtnFinder);
        await tester.tap(addBtnFinder);
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pumpAndSettle();

      // Verify all 25 chips are in tree
      for (int i = 1; i <= 25; i++) {
        final tag = 'Tag-${i.toString().padLeft(2, '0')}';
        expect(find.byKey(Key('tag_chip_$tag')), findsOneWidget);
      }

      // Verify Save button remains visible, pinned, and clickable
      final saveBtn = find.byKey(const Key('save_card_edits_button'));
      expect(saveBtn, findsOneWidget);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Verify in SQLite
      var inDb = await db.vaultDao.getItemById(card.id);
      expect(inDb, isNotNull);
      var data = jsonDecode(inDb!.dynamicData) as Map<String, dynamic>;
      var tags = List<String>.from(data['tags']);
      expect(tags.length, 25);
      expect(tags.first, 'Tag-01');
      expect(tags.last, 'Tag-25');

      // Re-open with updated card from DB and delete 5 tags
      final updatedCard = inDb;
      await tester.pumpWidget(
        createTestApp(
          child: Builder(
            builder: (context) => ElevatedButton(
              key: const Key('open_edit_btn_2'),
              onPressed: () => EditCardModal.show(context, updatedCard),
              child: const Text('Open Edit 2'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_edit_btn_2')));
      await tester.pumpAndSettle();

      for (int i = 1; i <= 5; i++) {
        final tag = 'Tag-${i.toString().padLeft(2, '0')}';
        final chipFinder = find.byKey(Key('tag_chip_$tag'));
        await tester.ensureVisible(chipFinder);
        final deleteIcon = find.descendant(
          of: chipFinder,
          matching: find.byIcon(Icons.close),
        );
        await tester.tap(deleteIcon);
        await tester.pump(const Duration(milliseconds: 20));
      }
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('save_card_edits_button')));
      await tester.pumpAndSettle();

      inDb = await db.vaultDao.getItemById(card.id);
      data = jsonDecode(inDb!.dynamicData) as Map<String, dynamic>;
      tags = List<String>.from(data['tags']);
      expect(tags.length, 20);
      expect(tags.contains('Tag-01'), isFalse);
      expect(tags.contains('Tag-06'), isTrue);
      expect(tester.takeException(), isNull);
    });
  });

  // ===========================================================================
  // CHALLENGE 4: Authentication Gate on Share Action
  // ===========================================================================
  group('Empirical Challenge 4: Authentication Gate on Share Action', () {
    testWidgets('Unauthenticated user is prompted to sign in; login opens share dialog',
        (tester) async {
      final card = createTestCard();
      await seedCard(card);

      await tester.pumpWidget(
        createTestApp(
          overrides: [
            isUserLoggedInProvider.overrideWith((ref) => false),
          ],
          child: Builder(
            builder: (context) => ElevatedButton(
              key: const Key('open_sheet_btn'),
              onPressed: () => CardDetailSheet.show(context, card),
              child: const Text('Open Sheet'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_sheet_btn')));
      await tester.pumpAndSettle();

      // Step 1: Tap Share while unauthenticated
      await tester.tap(find.byKey(const Key('quick_action_share')));
      await tester.pumpAndSettle();

      // Verify login prompt dialog is shown and share dialog is NOT shown
      expect(find.byKey(const Key('share_login_dialog')), findsOneWidget);
      expect(find.text('Sign in to Share'), findsOneWidget);
      expect(find.byKey(const Key('card_share_dialog')), findsNothing);

      // Step 2: Cancel login dialog
      await tester.tap(find.byKey(const Key('share_login_cancel')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('share_login_dialog')), findsNothing);
      expect(find.byKey(const Key('card_share_dialog')), findsNothing);

      // Step 3: Tap Share again and click Sign In
      await tester.tap(find.byKey(const Key('quick_action_share')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('share_login_dialog')), findsOneWidget);
      await tester.tap(find.byKey(const Key('share_login_button')));
      await tester.pumpAndSettle();

      // Verify sign in toast
      expect(find.text('Signed in successfully!'), findsOneWidget);

      // Advance past the 2-second floating SnackBar duration so subsequent SnackBars don't queue
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      // Step 4: Now authenticated, tap Share again
      await tester.tap(find.byKey(const Key('quick_action_share')));
      await tester.pumpAndSettle();

      // Verify card share dialog opens immediately without login prompt
      expect(find.byKey(const Key('card_share_dialog')), findsOneWidget);
      expect(find.byKey(const Key('share_login_dialog')), findsNothing);
      expect(find.textContaining(card.name), findsWidgets);

      // Step 5: Test Copy Card Info action
      await tester.tap(find.byKey(const Key('share_copy_link_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('card_share_dialog')), findsNothing);
      expect(find.textContaining('Copied "${card.name}" link to clipboard'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Pre-authenticated user directly accesses share sheet without prompt',
        (tester) async {
      final card = createTestCard();
      await seedCard(card);

      await tester.pumpWidget(
        createTestApp(
          overrides: [
            isUserLoggedInProvider.overrideWith((ref) => true),
          ],
          child: Builder(
            builder: (context) => ElevatedButton(
              key: const Key('open_sheet_btn'),
              onPressed: () => CardDetailSheet.show(context, card),
              child: const Text('Open Sheet'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_sheet_btn')));
      await tester.pumpAndSettle();

      // Tap Share
      await tester.tap(find.byKey(const Key('quick_action_share')));
      await tester.pumpAndSettle();

      // Verify share dialog is immediately present, 0 login dialogs
      expect(find.byKey(const Key('card_share_dialog')), findsOneWidget);
      expect(find.byKey(const Key('share_login_dialog')), findsNothing);

      await tester.tap(find.byKey(const Key('share_dialog_close')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('card_share_dialog')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  // ===========================================================================
  // CHALLENGE 5: Narrow Viewport Stress & Zero RenderFlex Overflow Verification
  // ===========================================================================
  group('Empirical Challenge 5: Narrow Viewports (320px–360px) Zero RenderFlex Overflows', () {
    testWidgets('CardDetailSheet & Quick Action Bar at 320x568 (iPhone SE 1st gen): all 5 actions hit-testable with zero overflows',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final card = createTestCard(name: 'Extremely Long Card Title That Might Push Row Constraints');
      await seedCard(card);

      await tester.pumpWidget(
        createTestApp(
          child: Builder(
            builder: (context) => ElevatedButton(
              key: const Key('open_sheet_btn'),
              onPressed: () => CardDetailSheet.show(context, card),
              child: const Text('Open Sheet'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_sheet_btn')));
      await tester.pumpAndSettle();

      // Verify all 5 action buttons render and have non-zero geometry
      final deleteAction = find.byKey(const Key('quick_action_delete'));
      final fullscreenAction = find.byKey(const Key('quick_action_fullscreen'));
      final deckAction = find.byKey(const Key('quick_action_add_to_deck'));
      final shareAction = find.byKey(const Key('quick_action_share'));
      final editAction = find.byKey(const Key('quick_action_edit'));

      expect(deleteAction, findsOneWidget);
      expect(fullscreenAction, findsOneWidget);
      expect(deckAction, findsOneWidget);
      expect(shareAction, findsOneWidget);
      expect(editAction, findsOneWidget);

      final deleteSize = tester.getSize(deleteAction);
      final fullscreenSize = tester.getSize(fullscreenAction);
      final deckSize = tester.getSize(deckAction);
      final shareSize = tester.getSize(shareAction);
      final editSize = tester.getSize(editAction);

      expect(deleteSize.width, greaterThan(30.0));
      expect(fullscreenSize.width, greaterThan(30.0));
      expect(deckSize.width, greaterThan(30.0));
      expect(shareSize.width, greaterThan(30.0));
      expect(editSize.width, greaterThan(30.0));

      // Tap actions on narrow screen to verify hit testing
      await tester.tap(deleteAction);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('card_detail_delete_dialog')), findsOneWidget);
      await tester.tap(find.byKey(const Key('delete_cancel_button')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull,
          reason: 'Zero RenderFlex overflows at 320px screen width');
    });

    testWidgets('EditCardModal at 320x568 and 360x640 with 20 tags and keyboard insets has zero overflows',
        (tester) async {
      for (final size in [const Size(320, 568), const Size(360, 640)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        // Simulate soft keyboard taking bottom 220px
        tester.view.viewInsets = const FakeViewPadding(bottom: 220);

        await db.vaultDao.clearAllItems();

        final initialTags = List.generate(20, (i) => 'Tag-${i + 1}');
        final card = createTestCard(
          id: 'adv-card-narrow-${size.width.toInt()}',
          dynamicData: jsonEncode({'tags': initialTags, 'deck_history': initialTags}),
        );
        await seedCard(card);

        await tester.pumpWidget(
          createTestApp(
            child: Builder(
              builder: (context) => ElevatedButton(
                key: const Key('open_edit_btn'),
                onPressed: () => EditCardModal.show(context, card),
                child: const Text('Open Edit'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('open_edit_btn')));
        await tester.pumpAndSettle();

        // Check if RenderFlex overflow occurred on build
        final exception = tester.takeException();
        expect(exception, isNull,
            reason: 'Zero RenderFlex overflows at viewport ${size.width}x${size.height} on mount');

        // Verify elements mounted
        expect(find.byKey(const Key('edit_card_variant_selector')), findsOneWidget);
        expect(find.byKey(const Key('save_card_edits_button')), findsOneWidget);

        // Tap Save
        await tester.tap(find.byKey(const Key('save_card_edits_button')));
        await tester.pumpAndSettle();
      }

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewInsets();
    });

    testWidgets('FullScreenCardViewer renders without overflow at 320x568 and 360x640',
        (tester) async {
      for (final size in [const Size(320, 568), const Size(360, 640)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;

        final card = createTestCard(name: 'Super Long Card Name That Tests App Bar Constraints In Fullscreen');

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FullScreenCardViewer(item: card),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('fullscreen_close_button')), findsOneWidget);
        expect(find.byKey(const Key('fullscreen_foil_toggle')), findsOneWidget);
        expect(find.byKey(const Key('fullscreen_interactive_viewer')), findsOneWidget);

        // Verify zero exceptions
        expect(tester.takeException(), isNull,
            reason: 'Zero RenderFlex overflows on FullScreenCardViewer at ${size.width}x${size.height}');
      }

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });
}
