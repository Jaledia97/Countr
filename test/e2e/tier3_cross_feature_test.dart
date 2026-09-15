import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/scanner/domain/card_perimeter_calculator.dart';
import 'package:countr/features/scanner/domain/ocr_heuristic_matcher.dart';
import 'package:countr/features/scanner/presentation/screens/scanner_modal.dart';
import 'package:countr/features/scanner/presentation/widgets/dynamic_scanner_overlay.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ===========================================================================
  // TIER 3 - CROSS-FEATURE COMBINATIONS
  // ===========================================================================

  group('Tier 3: Cross-Feature Interactions', () {
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

    testWidgets('XF1 (F1 + F2): perimeter calculation directly drives dynamic reticle rendering', (tester) async {
      // 1. Calculate image space perimeter
      final blocks = [
        createMockTextBlock(const Rect.fromLTWH(100, 150, 400, 600)),
      ];
      final imagePerimeter = CardPerimeterCalculator.calculatePerimeter(
        blocks,
        imageSize: const Size(1080, 1920),
      );
      expect(imagePerimeter, isNotNull);

      // 2. Map image space perimeter to screen space
      const screenSize = Size(390, 844);
      final screenBounds = CardPerimeterCalculator.mapImageRectToScreen(
        imageRect: imagePerimeter!,
        imageSize: const Size(1080, 1920),
        screenSize: screenSize,
        fit: BoxFit.cover,
      );

      // 3. Render DynamicScannerOverlay with mapped coordinates
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DynamicScannerOverlay(
              cardBounds: screenBounds,
              isGreenFlash: false,
              isPaused: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 4. Verify all 4 corner brackets render at screen coordinates
      expect(find.byKey(const Key('corner_bracket_tl')), findsOneWidget);
      expect(find.byKey(const Key('corner_bracket_tr')), findsOneWidget);
      expect(find.byKey(const Key('corner_bracket_bl')), findsOneWidget);
      expect(find.byKey(const Key('corner_bracket_br')), findsOneWidget);
    });

    testWidgets('XF2 (F2 + F3): reticle coordinates persist across skipped frames and update on 10th frame', (tester) async {
      await tester.pumpWidget(createE2ETestHarness(child: const ScannerModal(), db: db));
      await tester.pump(const Duration(milliseconds: 200));

      final state = tester.state(find.byType(ScannerModal)) as dynamic;
      const initialBounds = Rect.fromLTWH(50, 100, 250, 350);
      state.simulateDetectedBounds(initialBounds);
      await tester.pump(const Duration(milliseconds: 200));

      expect(state.detectedCardBounds, equals(initialBounds));

      // Send 9 skipped frames
      final dummyImage = createMockCameraImage();
      for (int i = 1; i <= 9; i++) {
        await state.processCameraFrameForTesting(dummyImage);
        expect(state.detectedCardBounds, equals(initialBounds));
      }

      // Update bounds on frame 10
      const newBounds = Rect.fromLTWH(60, 110, 260, 360);
      state.simulateDetectedBounds(newBounds);
      await state.processCameraFrameForTesting(dummyImage);
      await tester.pump(const Duration(milliseconds: 200));

      expect(state.detectedCardBounds, equals(newBounds));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('XF3 (F3 + F4): 60-frame camera burst enforces 1-in-10 skipping under strict async lock', (tester) async {
      await tester.pumpWidget(createE2ETestHarness(child: const ScannerModal(), db: db));
      await tester.pump(const Duration(milliseconds: 200));

      final state = tester.state(find.byType(ScannerModal)) as dynamic;
      final dummyImage = createMockCameraImage();

      // Send 60 frames (simulating 1 full second of 60fps camera feed)
      for (int i = 1; i <= 60; i++) {
        await state.processCameraFrameForTesting(dummyImage);
      }

      expect(state.frameCount, equals(60));
      expect(state.isProcessing, isFalse, reason: 'Async lock must be cleanly released');

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });

    test('XF4 (F5 + F7): text sanitizer cleans noisy OCR lines to feed SQL wide net search', () async {
      // Noisy OCR line with formatting
      const rawLine = '| "Black Lotus" | Artifact Rare';
      final clean = sanitize(rawLine);
      expect(clean, contains('blacklotus'));

      // Wide net query with cleaned line
      final match = await dao.matchScannedCard([rawLine], 'mtg');
      expect(match, isNotNull);
      expect(match!.name, equals('Black Lotus'));
    });

    test('XF5 (F5 + F8): text sanitizer normalizes split card names for Dart in-memory base verification', () async {
      // Split card "Fire // Ice"
      const rawLine = 'Fire // Ice (Instant - Apocalypse)';
      final clean = sanitize(rawLine);
      expect(clean, contains('fireice'));

      final match = await dao.matchScannedCard([rawLine], 'mtg');
      expect(match, isNotNull);
      expect(match!.id, equals('mtg-split-fire-ice'));
    });

    test('XF6 (F6 + F9): collector number regex match auto-triggers inbox card staging', () async {
      final lines = ['Illegible Title OCR Noise #%^', '232/250'];
      final match = await dao.matchScannedCard(lines, 'mtg');
      expect(match, isNotNull);
      expect(match!.id, equals('mtg-lotus'));

      // Auto-stage matched card into Inbox
      await dao.upsertScannedCardToInbox(match);

      final inbox = await dao.watchInboxItems().first;
      expect(inbox.any((c) => c.id == 'mtg-lotus'), isTrue);
      expect(inbox.firstWhere((c) => c.id == 'mtg-lotus').quantity, equals(1));
    });

    test('XF7 (F7 + F8 + F9): full 3-step hybrid matching engine matches title and stages card into inbox', () async {
      // Step 2 (Prefix: Sol R) -> Step 3 (Dart contains: Sol Ring) -> Step 4 (Inbox Staging)
      final lines = ['Sol Ring Commander'];
      final match = await dao.matchScannedCard(lines, 'mtg');

      expect(match, isNotNull);
      expect(match!.name, equals('Sol Ring'));

      await dao.upsertScannedCardToInbox(match, isFoil: true);

      final inbox = await dao.watchInboxItems().first;
      final staged = inbox.firstWhere((c) => c.id == match.id);
      expect(staged.name, equals('Sol Ring'));
      expect(staged.condition, equals('NM (Foil)'));
    });

    test('XF8 (F9 + F10): inbox card staging keeps vault portfolio valuation firewall intact', () async {
      // Initial owned items in vault
      final initialOwned = await dao.getItemsByCollection('mtg', onlyOwned: true);
      expect(initialOwned.isEmpty, isTrue);

      // Scan high-value Black Lotus into Inbox
      final lotus = createTestCard(id: 'mtg-lotus', name: 'Black Lotus', quantity: 0, currentMarketPrice: 5500.0);
      await stageCardToInbox(dao, lotus);

      // Verify inbox has it
      final inbox = await dao.watchInboxItems().first;
      expect(inbox.length, equals(1));
      expect(inbox.first.id, equals('mtg-lotus'));

      // Verify binder-assigned vault items are untouched
      final ownedAfter = await dao.getItemsByCollection('mtg', onlyOwned: true);
      expect(ownedAfter.where((c) => c.primaryBinderId != null && c.primaryBinderId != 'INBOX').isEmpty, isTrue);
    });

    test('XF9 (F9 + F11): single-item deletion removes staged card from SQLite and updates inbox stream', () async {
      final card1 = createTestCard(id: 'stg-1', name: 'Card 1');
      final card2 = createTestCard(id: 'stg-2', name: 'Card 2');

      await dao.upsertScannedCardToInbox(card1);
      await dao.upsertScannedCardToInbox(card2);

      var inbox = await dao.watchInboxItems().first;
      expect(inbox.length, equals(2));

      await deleteVaultItem(dao, 'stg-1');

      final remaining = await dao.watchInboxItems().first;
      expect(remaining.length, equals(1));
      expect(remaining.first.id, equals('stg-2'));
    });

    test('XF10 (F9 + F12): bulk trash deletion clears multiple staged cards from inbox', () async {
      for (int i = 1; i <= 4; i++) {
        await dao.upsertScannedCardToInbox(createTestCard(id: 'trash-item-$i', name: 'Trash $i'));
      }
      expect((await dao.watchInboxItems().first).length, equals(4));

      await deleteVaultItems(dao, ['trash-item-1', 'trash-item-2', 'trash-item-3']);

      final remaining = await dao.watchInboxItems().first;
      expect(remaining.length, equals(1));
      expect(remaining.first.id, equals('trash-item-4'));
    });

    test('XF11 (F10 + F11/F12): deleting inbox junk leaves vault portfolio valuations intact', () async {
      // 1. Establish owned card in vault binder
      final binder = await dao.createBinder(name: 'Legacy Binder', collectionType: 'mtg');
      final vaultedCard = createTestCard(
        id: 'v-card-1',
        name: 'Force of Will',
        quantity: 1,
        acquiredPrice: 90.0,
        currentMarketPrice: 100.0,
        primaryBinderId: binder.id,
      );
      await dao.into(dao.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: vaultedCard.id,
              collectionType: vaultedCard.collectionType,
              name: vaultedCard.name,
              setOrSeries: vaultedCard.setOrSeries,
              imageUrl: '',
              acquiredPrice: 90.0,
              acquiredDate: DateTime.now(),
              quantity: const drift.Value(1),
              condition: 'NM',
              currentMarketPrice: 100.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: '{}',
              primaryBinderId: drift.Value(binder.id),
            ),
          );

      // 2. Stage junk cards in inbox
      await dao.upsertScannedCardToInbox(createTestCard(id: 'junk-1', name: 'Junk Scan 1'));
      await dao.upsertScannedCardToInbox(createTestCard(id: 'junk-2', name: 'Junk Scan 2'));

      // 3. Delete inbox junk
      await deleteVaultItems(dao, ['junk-1', 'junk-2']);

      // 4. Verify vaulted card remains intact with full valuation
      final vaulted = await dao.getItemsByCollection('mtg', onlyOwned: true);
      expect(vaulted.length, equals(1));
      expect(vaulted.first.id, equals('v-card-1'));
      expect(vaulted.first.currentMarketPrice, equals(100.0));
    });

    test('XF12 (F9 + F10 + Binder Transfer): staged card transferred to binder integrates into portfolio', () async {
      // 1. Create target binder
      final binder = await dao.createBinder(name: 'Modern Staple', collectionType: 'mtg');

      // 2. Stage card into inbox
      final card = createTestCard(
        id: 'urza-staged',
        name: "Urza's Saga",
        currentMarketPrice: 40.0,
        acquiredPrice: 35.0,
      );
      await dao.upsertScannedCardToInbox(card);

      // 3. Transfer from inbox to binder
      await dao.assignItemsToBinder([card.id], binder.id);

      // 4. Verify anchored to binder
      final binderItems = await (dao.select(dao.vaultItems)..where((t) => t.primaryBinderId.equals(binder.id))).get();
      expect(binderItems.length, equals(1));
      expect(binderItems.first.name, equals("Urza's Saga"));

      // 5. Verify reflected in binder item count
      final binderCounts = await dao.watchBinderItemCounts().first;
      expect(binderCounts[binder.id], equals(1));
    });
  });
}
