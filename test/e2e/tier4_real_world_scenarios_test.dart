import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/scanner/presentation/screens/inbox_screen.dart';
import 'package:countr/features/scanner/presentation/screens/scanner_modal.dart';
import 'package:countr/features/scanner/presentation/widgets/dynamic_scanner_overlay.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ===========================================================================
  // TIER 4 - REAL-WORLD APPLICATION SCENARIOS
  // ===========================================================================

  group('Tier 4: Real-World Scenarios', () {
    late AppDatabase db;
    late VaultDao dao;

    setUp(() async {
      db = createTestDatabase();
      dao = db.vaultDao;
      await seedComprehensiveTestCatalog(dao);
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('Scenario 1: full card scanning & auto-capture journey', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // 1. Launch ScannerModal
      await tester.pumpWidget(createE2ETestHarness(child: const ScannerModal(), db: db));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(ScannerModal), findsOneWidget);
      expect(find.byType(DynamicScannerOverlay), findsOneWidget);
      expect(find.text('Scanner Camera Active'), findsOneWidget);
      expect(find.text('Foil/Variant'), findsOneWidget);

      // 2. Toggle Foil/Variant mode
      await tester.tap(find.text('Foil/Variant'));
      await tester.pump(const Duration(milliseconds: 200));

      // 3. Simulate text detection snapping dynamic reticle corner brackets
      final state = tester.state(find.byType(ScannerModal)) as dynamic;
      const detectedRect = Rect.fromLTWH(80, 180, 280, 400);
      state.simulateDetectedBounds(detectedRect);
      await tester.pump(const Duration(milliseconds: 200));

      expect(state.detectedCardBounds, equals(detectedRect));
      expect(find.byKey(const Key('corner_bracket_tl')), findsOneWidget);

      // 4. Simulate card match and auto-routing to Inbox
      final matchCard = createTestCard(
        id: 'auto-card-1',
        name: 'Sol Ring',
        setOrSeries: 'Commander',
        currentMarketPrice: 2.5,
      );
      final detectionFuture = state.simulateCardDetection(matchCard);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 5. Verify auto-routing directly into InboxScreen
      expect(find.byType(InboxScreen), findsOneWidget);
      expect(find.text('Sol Ring'), findsOneWidget);

      // 6. Return to Scanner via back navigation
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await detectionFuture;

      // 7. Verify session counter badge increments to 1 and scanner restores
      expect(find.byType(ScannerModal), findsOneWidget);
      expect(find.text('1'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('Scenario 2: complete card lifecycle (scan -> review -> delete junk -> create binder -> anchor keeper)', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // 1. Stage cards: 1 keeper scanned twice (increments qty), 1 junk scan
      final keeper = createTestCard(id: 'c-keeper', name: 'Mox Diamond', currentMarketPrice: 600.0);
      final junk = createTestCard(id: 'c-junk', name: 'Accidental Blurry Scan', currentMarketPrice: 0.1);

      await dao.upsertScannedCardToInbox(keeper);
      await dao.upsertScannedCardToInbox(keeper, isFoil: true); // increments quantity to 2
      await dao.upsertScannedCardToInbox(junk);

      // 2. Open InboxScreen
      await tester.pumpWidget(createE2ETestHarness(child: const InboxScreen(), db: db));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Mox Diamond'), findsOneWidget);
      expect(find.text('Accidental Blurry Scan'), findsOneWidget);

      // 3. Delete the junk card from SQLite
      await deleteVaultItem(dao, 'c-junk');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final inboxAfterDelete = await (dao.select(dao.vaultItems)
            ..where((t) =>
                t.primaryBinderId.equals('INBOX') &
                t.quantity.isBiggerThanValue(0)))
          .get();
      expect(inboxAfterDelete.any((c) => c.id == 'c-junk'), isFalse);

      // 4. Create new binder on the fly
      final binder = await dao.createBinder(name: 'Vintage Power Nine', collectionType: 'mtg');

      // 5. Transfer keeper card to binder
      await dao.assignItemsToBinder(['c-keeper'], binder.id);

      final anchored = await (dao.select(dao.vaultItems)..where((t) => t.primaryBinderId.equals(binder.id))).get();
      expect(anchored.length, equals(1));
      expect(anchored.first.id, equals('c-keeper'));
      expect(anchored.first.primaryBinderId, equals(binder.id));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });

    test('Scenario 3: strict portfolio valuation firewall during active card scanning session', () async {
      // 1. Establish baseline vault portfolio with 2 vaulted cards
      final binder = await dao.createBinder(name: 'Commander Decks', collectionType: 'mtg');
      final vaulted1 = createTestCard(
        id: 'v-sol',
        name: 'Sol Ring',
        quantity: 1,
        acquiredPrice: 2.0,
        currentMarketPrice: 2.5,
        primaryBinderId: binder.id,
      );
      final vaulted2 = createTestCard(
        id: 'v-mana',
        name: 'Mana Crypt',
        quantity: 1,
        acquiredPrice: 180.0,
        currentMarketPrice: 200.0,
        primaryBinderId: binder.id,
      );

      await dao.into(dao.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: vaulted1.id,
              collectionType: vaulted1.collectionType,
              name: vaulted1.name,
              setOrSeries: vaulted1.setOrSeries,
              imageUrl: '',
              acquiredPrice: 2.0,
              acquiredDate: DateTime.now(),
              quantity: const drift.Value(1),
              condition: 'NM',
              currentMarketPrice: 2.5,
              lastPriceUpdate: DateTime.now(),
              dynamicData: '{}',
              primaryBinderId: drift.Value(binder.id),
            ),
          );

      await dao.into(dao.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: vaulted2.id,
              collectionType: vaulted2.collectionType,
              name: vaulted2.name,
              setOrSeries: vaulted2.setOrSeries,
              imageUrl: '',
              acquiredPrice: 180.0,
              acquiredDate: DateTime.now(),
              quantity: const drift.Value(1),
              condition: 'NM',
              currentMarketPrice: 200.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: '{}',
              primaryBinderId: drift.Value(binder.id),
            ),
          );

      // Baseline portfolio: 2 cards, Market Val = 202.5, Cost = 182.0
      final baselineItems = await dao.getItemsByCollection('mtg', onlyOwned: true);
      final baselineVaulted = baselineItems.where((c) => c.primaryBinderId == binder.id).toList();
      double baseMarketVal = 0;
      double baseCost = 0;
      for (final i in baselineVaulted) {
        baseMarketVal += (i.currentMarketPrice * i.quantity);
        baseCost += (i.acquiredPrice * i.quantity);
      }
      expect(baseMarketVal, equals(202.5));
      expect(baseCost, equals(182.0));

      // 2. Scan 5 massive-value cards into Inbox ($5,000+ each)
      final scannedCards = [
        createTestCard(id: 's-lotus', name: 'Black Lotus', currentMarketPrice: 5500.0, acquiredPrice: 5000.0),
        createTestCard(id: 's-mox-1', name: 'Mox Sapphire', currentMarketPrice: 3000.0, acquiredPrice: 2800.0),
        createTestCard(id: 's-mox-2', name: 'Mox Jet', currentMarketPrice: 2800.0, acquiredPrice: 2600.0),
        createTestCard(id: 's-mox-3', name: 'Mox Ruby', currentMarketPrice: 2700.0, acquiredPrice: 2500.0),
        createTestCard(id: 's-mox-4', name: 'Mox Emerald', currentMarketPrice: 2600.0, acquiredPrice: 2400.0),
      ];

      for (final c in scannedCards) {
        await stageCardToInbox(dao, c);
      }

      // Verify Inbox holding area has all 5 cards
      final inbox = await dao.watchInboxItems().first;
      expect(inbox.length, equals(5));

      // 3. Firewall verification: Owned binder portfolio remains strictly untouched
      final afterScanItems = await dao.getItemsByCollection('mtg', onlyOwned: true);
      final vaultedOnly = afterScanItems.where((c) => c.primaryBinderId == binder.id).toList();
      double currentMarketVal = 0;
      double currentCost = 0;
      for (final i in vaultedOnly) {
        currentMarketVal += (i.currentMarketPrice * i.quantity);
        currentCost += (i.acquiredPrice * i.quantity);
      }
      expect(currentMarketVal, equals(202.5), reason: 'Staged inbox cards must not inflate portfolio market value');
      expect(currentCost, equals(182.0), reason: 'Staged inbox cards must not inflate portfolio cost basis');

      // 4. Delete 2 unneeded cards from inbox
      await deleteVaultItems(dao, ['s-mox-3', 's-mox-4']);
      expect((await dao.watchInboxItems().first).length, equals(3));

      // 5. Transfer remaining 3 cards to binder
      await dao.assignItemsToBinder(['s-lotus', 's-mox-1', 's-mox-2'], binder.id);

      // 6. Portfolio now accurately integrates transferred cards
      final finalItems = await dao.getItemsByCollection('mtg', onlyOwned: true);
      final finalVaulted = finalItems.where((c) => c.primaryBinderId == binder.id).toList();
      expect(finalVaulted.length, equals(5)); // 2 original + 3 transferred
      double finalMarketVal = 0;
      for (final i in finalVaulted) {
        finalMarketVal += (i.currentMarketPrice * i.quantity);
      }
      // 202.5 + 5500 + 3000 + 2800 = 11502.5
      expect(finalMarketVal, equals(11502.5));
    });

    testWidgets('Scenario 4: erratic camera motion & OCR stream resilience stress test', (tester) async {
      await tester.pumpWidget(createE2ETestHarness(child: const ScannerModal(), db: db));
      await tester.pump(const Duration(milliseconds: 200));

      final state = tester.state(find.byType(ScannerModal)) as dynamic;
      final dummyImage = createMockCameraImage();

      // Send 50 frames with variable bounds and rotation
      for (int i = 1; i <= 50; i++) {
        if (i % 10 == 0) {
          state.simulateDetectedBounds(Rect.fromLTWH(50.0 + i, 100.0 + i, 200.0, 300.0));
        }
        await state.processCameraFrameForTesting(dummyImage);
      }

      expect(state.frameCount, equals(50));
      expect(state.isProcessing, isFalse);

      // Pause and send frames
      await tester.tap(find.byKey(const Key('scanner_pause_toggle')));
      await tester.pump(const Duration(milliseconds: 200));

      for (int i = 51; i <= 70; i++) {
        await state.processCameraFrameForTesting(dummyImage);
      }
      expect(state.frameCount, equals(70));
      expect(state.isProcessing, isFalse);

      // Unpause and verify state
      await tester.tap(find.byKey(const Key('scanner_pause_toggle')));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Scanner Camera Active'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('Scenario 5: multi-game inbox bulk operations & safety boundaries', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Stage multi-game cards into Inbox
      final mtg1 = createTestCard(id: 'sg-mtg-1', name: 'Force of Will', collectionType: 'mtg');
      final mtg2 = createTestCard(id: 'sg-mtg-2', name: 'Mana Crypt', collectionType: 'mtg');
      final pkm1 = createTestCard(id: 'sg-pkm-1', name: 'Charizard ex', collectionType: 'pokemon');

      await dao.upsertScannedCardToInbox(mtg1);
      await dao.upsertScannedCardToInbox(mtg2);
      await dao.upsertScannedCardToInbox(pkm1);

      await tester.pumpWidget(createE2ETestHarness(child: const InboxScreen(), db: db));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Enter selection mode
      await tester.tap(find.text('Select'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Select All
      await tester.tap(find.text('Select All'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('3 Selected'), findsOneWidget);

      // Attempt to move mixed selection (MTG + Pokémon)
      await tester.tap(find.text('Move to Binder (3)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify cross-game warning blocks transfer
      expect(find.text('Cross-game mixing is not allowed. Please select only one game\'s cards for transfer.'), findsOneWidget);

      // Deselect all
      await tester.tap(find.text('Deselect All'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Bulk delete unwanted Pokemon card via database
      await deleteVaultItem(dao, 'sg-pkm-1');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final remaining = await (dao.select(dao.vaultItems)
            ..where((t) =>
                t.primaryBinderId.equals('INBOX') &
                t.quantity.isBiggerThanValue(0)))
          .get();
      expect(remaining.length, equals(2));
      expect(remaining.every((c) => c.collectionType == 'mtg'), isTrue);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });
  });
}
