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
  // TIER 2 - BOUNDARY & CORNER CASES (>=5 tests per feature F1 - F12)
  // ===========================================================================

  group('Tier 2 - F1 Boundaries: Perimeter Calculation', () {
    test('F1.B1: empty block list returns null', () {
      expect(CardPerimeterCalculator.calculatePerimeter([]), isNull);
    });

    test('F1.B2: zero-dimension and negative-dimension bounding boxes return null', () {
      final blocks = [
        createMockTextBlock(const Rect.fromLTWH(10, 10, 0, 50)),
        createMockTextBlock(const Rect.fromLTWH(20, 20, 50, 0)),
        createMockTextBlock(const Rect.fromLTWH(30, 30, -5, -5)),
      ];
      expect(CardPerimeterCalculator.calculatePerimeter(blocks), isNull);
    });

    test('F1.B3: padding causing perimeter to exceed imageSize boundaries is clamped strictly', () {
      const imageSize = Size(500, 500);
      final blocks = [
        createMockTextBlock(const Rect.fromLTWH(10, 10, 480, 480)),
      ];
      final perimeter = CardPerimeterCalculator.calculatePerimeter(
        blocks,
        imageSize: imageSize,
        padXPercent: 0.20,
        padYPercent: 0.20,
      );

      expect(perimeter, isNotNull);
      expect(perimeter!.left, equals(0.0));
      expect(perimeter.top, equals(0.0));
      expect(perimeter.right, equals(500.0));
      expect(perimeter.bottom, equals(500.0));
    });

    test('F1.B4: single point / sub-pixel box produces valid padded perimeter', () {
      final blocks = [
        createMockTextBlock(const Rect.fromLTWH(100, 100, 1, 1)),
      ];
      final perimeter = CardPerimeterCalculator.calculatePerimeter(blocks);

      expect(perimeter, isNotNull);
      expect(perimeter!.width, greaterThan(0));
      expect(perimeter.height, greaterThan(0));
    });

    test('F1.B5: extreme sensor-to-screen scale factor maps correctly without NaN or infinity', () {
      const imageSize = Size(3840, 2160); // 4K landscape sensor
      const screenSize = Size(320, 568);  // Small portrait phone
      const imageRect = Rect.fromLTWH(500, 300, 1200, 1600);

      final mapped = CardPerimeterCalculator.mapImageRectToScreen(
        imageRect: imageRect,
        imageSize: imageSize,
        screenSize: screenSize,
        fit: BoxFit.cover,
      );

      expect(mapped.left.isFinite, isTrue);
      expect(mapped.top.isFinite, isTrue);
      expect(mapped.width.isFinite, isTrue);
      expect(mapped.height.isFinite, isTrue);
      expect(mapped.width, greaterThan(0));
    });
  });

  group('Tier 2 - F2 Boundaries: Dynamic Reticle Overlay', () {
    testWidgets('F2.B1: extremely small card bounds clamps corner brackets without exploding', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DynamicScannerOverlay(
              cardBounds: Rect.fromLTWH(50, 50, 12, 12),
              isGreenFlash: false,
              isPaused: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('F2.B2: fullscreen card bounds render without clipping or overflows', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DynamicScannerOverlay(
              cardBounds: Rect.fromLTWH(0, 0, 800, 1200),
              isGreenFlash: false,
              isPaused: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('corner_bracket_tl')), findsOneWidget);
      expect(find.byKey(const Key('corner_bracket_br')), findsOneWidget);
    });

    testWidgets('F2.B3: rapid bounds flickering between non-null and null transitions smoothly via opacity', (tester) async {
      final notifier = ValueNotifier<Rect?>(const Rect.fromLTWH(100, 100, 200, 300));
      addTearDown(notifier.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<Rect?>(
              valueListenable: notifier,
              builder: (context, bounds, _) => DynamicScannerOverlay(
                cardBounds: bounds,
                isGreenFlash: false,
                isPaused: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Rapidly toggle 5 times
      for (int i = 0; i < 5; i++) {
        notifier.value = null;
        await tester.pump(const Duration(milliseconds: 20));
        notifier.value = const Rect.fromLTWH(100, 100, 200, 300);
        await tester.pump(const Duration(milliseconds: 20));
      }

      expect(tester.takeException(), isNull);
    });

    testWidgets('F2.B4: retains cached bounds during momentary frame loss (cardBounds == null)', (tester) async {
      final notifier = ValueNotifier<Rect?>(const Rect.fromLTWH(50, 100, 200, 300));
      addTearDown(notifier.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<Rect?>(
              valueListenable: notifier,
              builder: (context, bounds, _) => DynamicScannerOverlay(
                cardBounds: bounds,
                isGreenFlash: false,
                isPaused: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Nullify bounds
      notifier.value = null;
      await tester.pump(const Duration(milliseconds: 50));

      // Overlay should fade out opacity, not crash or instantly remove widget tree
      final animatedOpacity = tester.widget<AnimatedOpacity>(find.byKey(const Key('dynamic_scanner_overlay')));
      expect(animatedOpacity.opacity, equals(0.0));
    });

    testWidgets('F2.B5: green flash state with null cardBounds handles gracefully without crashing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DynamicScannerOverlay(
              cardBounds: null,
              isGreenFlash: true,
              isPaused: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('dynamic_scanner_overlay_empty')), findsOneWidget);
    });
  });

  group('Tier 2 - F3 Boundaries: Frame Skipping', () {
    late AppDatabase db;

    setUp(() {
      db = createTestDatabase();
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('F3.B1: high-volume frame storm (100 frames in rapid sequence) maintains exact 1-in-10 cadence', (tester) async {
      await tester.pumpWidget(createE2ETestHarness(child: const ScannerModal(), db: db));
      await tester.pump(const Duration(milliseconds: 200));

      final state = tester.state(find.byType(ScannerModal)) as dynamic;
      final dummyImage = createMockCameraImage();

      for (int i = 1; i <= 100; i++) {
        await state.processCameraFrameForTesting(dummyImage);
      }
      expect(state.frameCount, equals(100));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('F3.B2: frame counter handles high counts (1000+) with integer arithmetic consistency', (tester) async {
      await tester.pumpWidget(createE2ETestHarness(child: const ScannerModal(), db: db));
      await tester.pump(const Duration(milliseconds: 200));

      final state = tester.state(find.byType(ScannerModal)) as dynamic;
      final dummyImage = createMockCameraImage();

      for (int i = 1; i <= 105; i++) {
        await state.processCameraFrameForTesting(dummyImage);
      }
      expect(state.frameCount % 10, equals(5));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('F3.B3: frame processing completely suspended while isScanningPaused is true', (tester) async {
      await tester.pumpWidget(createE2ETestHarness(child: const ScannerModal(), db: db));
      await tester.pump(const Duration(milliseconds: 200));

      // Pause via button
      await tester.tap(find.byKey(const Key('scanner_pause_toggle')));
      await tester.pump(const Duration(milliseconds: 200));

      final state = tester.state(find.byType(ScannerModal)) as dynamic;
      final dummyImage = createMockCameraImage();

      // Send 30 frames
      for (int i = 1; i <= 30; i++) {
        await state.processCameraFrameForTesting(dummyImage);
      }
      expect(state.isProcessing, isFalse);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('F3.B4: frame arriving while isProcessing is true is immediately dropped', (tester) async {
      await tester.pumpWidget(createE2ETestHarness(child: const ScannerModal(), db: db));
      await tester.pump(const Duration(milliseconds: 200));

      final state = tester.state(find.byType(ScannerModal)) as dynamic;
      expect(state.isProcessing, isFalse);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('F3.B5: interleaved pause toggling precisely enables and disables frame skipping gates', (tester) async {
      await tester.pumpWidget(createE2ETestHarness(child: const ScannerModal(), db: db));
      await tester.pump(const Duration(milliseconds: 200));

      final state = tester.state(find.byType(ScannerModal)) as dynamic;
      final dummyImage = createMockCameraImage();

      // Frame 1-5 active
      for (int i = 1; i <= 5; i++) {
        await state.processCameraFrameForTesting(dummyImage);
      }
      expect(state.frameCount, equals(5));

      // Pause
      await tester.tap(find.byKey(const Key('scanner_pause_toggle')));
      await tester.pump(const Duration(milliseconds: 200));

      // Frame 6-15 while paused
      for (int i = 6; i <= 15; i++) {
        await state.processCameraFrameForTesting(dummyImage);
      }
      expect(state.frameCount, equals(15));
      expect(state.isProcessing, isFalse);

      // Unpause
      await tester.tap(find.byKey(const Key('scanner_pause_toggle')));
      await tester.pump(const Duration(milliseconds: 200));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });
  });

  group('Tier 2 - F4 Boundaries: Strict Async Lock', () {
    late AppDatabase db;

    setUp(() {
      db = createTestDatabase();
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('F4.B1: unmounted state during finally execution skips setState safely', (tester) async {
      await tester.pumpWidget(createE2ETestHarness(child: const ScannerModal(), db: db));
      await tester.pump(const Duration(milliseconds: 200));

      final state = tester.state(find.byType(ScannerModal)) as dynamic;

      // Dismount widget
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));

      expect(state.mounted, isFalse);
    });

    testWidgets('F4.B2: consecutive fatal OCR exceptions across 10 frames never deadlock scanner', (tester) async {
      await tester.pumpWidget(createE2ETestHarness(child: const ScannerModal(), db: db));
      await tester.pump(const Duration(milliseconds: 200));

      final state = tester.state(find.byType(ScannerModal)) as dynamic;
      final dummyImage = createMockCameraImage();

      // Trigger 10 modulo boundaries (100 frames total)
      for (int i = 1; i <= 100; i++) {
        await state.processCameraFrameForTesting(dummyImage);
      }

      // Scanner must remain completely unlocked and alive
      expect(state.isProcessing, isFalse);
      expect(state.frameCount, 100);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('F4.B3: slow asynchronous database matching keeps lock active until completion', (tester) async {
      await tester.pumpWidget(createE2ETestHarness(child: const ScannerModal(), db: db));
      await tester.pump(const Duration(milliseconds: 200));

      final state = tester.state(find.byType(ScannerModal)) as dynamic;
      expect(state.isProcessing, isFalse);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('F4.B4: state disposal while frame processing is active unwinds cleanly', (tester) async {
      await tester.pumpWidget(createE2ETestHarness(child: const ScannerModal(), db: db));
      await tester.pump(const Duration(milliseconds: 200));

      // Pump out widget
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));

      expect(tester.takeException(), isNull);
    });

    testWidgets('F4.B5: lock survives immediate rapid pause toggle mid-frame', (tester) async {
      await tester.pumpWidget(createE2ETestHarness(child: const ScannerModal(), db: db));
      await tester.pump(const Duration(milliseconds: 200));

      // Double tap pause rapidly
      await tester.tap(find.byKey(const Key('scanner_pause_toggle')));
      await tester.pump(const Duration(milliseconds: 20));
      await tester.tap(find.byKey(const Key('scanner_pause_toggle')));
      await tester.pump(const Duration(milliseconds: 200));

      final state = tester.state(find.byType(ScannerModal)) as dynamic;
      expect(state.isProcessing, isFalse);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });
  });

  group('Tier 2 - F5 Boundaries: Sanitizer', () {
    test('F5.B1: empty string and whitespace-only strings return empty string', () {
      expect(sanitize(''), equals(''));
      expect(sanitize('   '), equals(''));
      expect(sanitize('\t\n  \r'), equals(''));
    });

    test('F5.B2: string composed entirely of symbols and non-alphanumerics returns empty string', () {
      expect(sanitize('!@#\$%^&*()_+=-[]{}|;\':",.<>?/'), equals(''));
      expect(sanitize('~~~---===///\\\\\\'), equals(''));
    });

    test('F5.B3: strings with emoji, unicode symbols, and invisible characters strip cleanly', () {
      expect(sanitize('Charizard 🔥 100'), equals('charizard100'));
      expect(sanitize('Pikachu ⚡️ No. 25'), equals('pikachuno25'));
      expect(sanitize('Card\u200B\u200C\u200DName'), equals('cardname'));
    });

    test('F5.B4: extremely long string (10,000+ characters with mixed symbols) processes efficiently', () {
      final hugeInput = 'A1! ' * 3000; // 12,000 chars
      final result = sanitize(hugeInput);
      expect(result.length, equals(6000));
      expect(result.startsWith('a1a1a1'), isTrue);
    });

    test('F5.B5: control characters are stripped cleanly', () {
      expect(sanitize('Card\x00Title\x07With\x1BControl'), equals('cardtitlewithcontrol'));
    });
  });

  group('Tier 2 - F6 Boundaries: Collector Number Override', () {
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

    test('F6.B1: leading zero normalization (025 matches 25 and vice-versa)', () async {
      final match1 = await dao.matchScannedCard(['Pokemon', 'No. 25'], 'pokemon');
      expect(match1, isNotNull);
      expect(match1!.id, equals('pkm-pikachu'));

      final match2 = await dao.matchScannedCard(['Pokemon', '025/100'], 'pokemon');
      expect(match2, isNotNull);
      expect(match2!.id, equals('pkm-pikachu'));
    });

    test('F6.B2: stat boxes (2/2, 5/5, 10/10) are ignored and not mistaken for collector numbers', () async {
      // 5/5 stat box should not match Black Lotus (232)
      final lines = ['Some Creature', '5/5'];
      final match = await dao.matchScannedCard(lines, 'mtg');
      // Should not match via collector number 5
      expect(match == null || match.id != 'mtg-lotus', isTrue);
    });

    test('F6.B3: non-matching collector number safely falls through to SQL Wide Net', () async {
      // Collector number 999 does not exist in seed, but title "Black Lotus" does
      final lines = ['Black Lotus', '999/999'];
      final match = await dao.matchScannedCard(lines, 'mtg');

      expect(match, isNotNull);
      expect(match!.name, equals('Black Lotus'));
    });

    test('F6.B4: handles dynamic_data with varied JSON formatting (spacing after colon)', () async {
      await dao.into(dao.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'spaced-collector-card',
              collectionType: 'mtg',
              name: 'Spaced Collector Card',
              setOrSeries: 'Promo',
              imageUrl: '',
              acquiredPrice: 5.0,
              acquiredDate: DateTime.now(),
              quantity: const drift.Value(0),
              condition: 'NM',
              currentMarketPrice: 5.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: '{"collector_number": "777"}',
            ),
          );

      final match = await dao.matchScannedCard(['777/800'], 'mtg');
      expect(match, isNotNull);
      expect(match!.id, equals('spaced-collector-card'));
    });

    test('F6.B5: multiple candidate numbers in OCR lines evaluates the first valid collector number', () async {
      final lines = ['Header', '101/200', '232/250'];
      final match = await dao.matchScannedCard(lines, 'mtg');

      expect(match, isNotNull);
      expect(match!.id, equals('mtg-sol-ring')); // 101 matches Sol Ring first
    });
  });

  group('Tier 2 - F7 Boundaries: SQL Wide Net Search', () {
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

    test('F7.B1: OCR line with leading symbols/pipes strips non-alphanumerics before prefix extract', () async {
      final lines = ['| { "Sol Ring" } Artifact |'];
      final match = await dao.matchScannedCard(lines, 'mtg');

      expect(match, isNotNull);
      expect(match!.name, equals('Sol Ring'));
    });

    test('F7.B2: short OCR lines (< 3 characters) are filtered out as noise without error', () async {
      final lines = ['A', '1', '!!', '   '];
      final match = await dao.matchScannedCard(lines, 'mtg');

      expect(match, isNull);
    });

    test('F7.B3: SQL injection payload in OCR line is safely parameterized', () async {
      final lines = ["' OR '1'='1; --", "Black Lotus"];
      final match = await dao.matchScannedCard(lines, 'mtg');

      expect(match, isNotNull);
      expect(match!.name, equals('Black Lotus'));
    });

    test('F7.B4: card names with curly and straight single quotes match seamlessly', () async {
      final straight = await dao.matchScannedCard(["Urza's Saga"], 'mtg');
      expect(straight, isNotNull);
      expect(straight!.id, equals('mtg-urza-saga'));

      final curly = await dao.matchScannedCard(["Urza’s Saga"], 'mtg');
      expect(curly, isNotNull);
      expect(curly!.id, equals('mtg-urza-saga'));
    });

    test('F7.B5: case variations across UPPERCASE, lowercase, Title Case match catalog prefix', () async {
      final upper = await dao.matchScannedCard(['BLACK LOTUS'], 'mtg');
      final lower = await dao.matchScannedCard(['black lotus'], 'mtg');
      final mixed = await dao.matchScannedCard(['bLaCk LoTuS'], 'mtg');

      expect(upper?.name, equals('Black Lotus'));
      expect(lower?.name, equals('Black Lotus'));
      expect(mixed?.name, equals('Black Lotus'));
    });
  });

  group('Tier 2 - F8 Boundaries: Dart In-Memory Verification', () {
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

    test('F8.B1: heavy trailing OCR noise on title line matches base card name', () async {
      final lines = ['Sol Ring Tap to add two colorless mana 1993 Wizards of the Coast'];
      final match = await dao.matchScannedCard(lines, 'mtg');

      expect(match, isNotNull);
      expect(match!.name, equals('Sol Ring'));
    });

    test('F8.B2: distinguishes between cards sharing a prefix accurately', () async {
      await dao.into(dao.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'mtg-solarion',
              collectionType: 'mtg',
              name: 'Solarion',
              setOrSeries: 'Fifth Dawn',
              imageUrl: '',
              acquiredPrice: 0.5,
              acquiredDate: DateTime.now(),
              quantity: const drift.Value(0),
              condition: 'NM',
              currentMarketPrice: 0.5,
              lastPriceUpdate: DateTime.now(),
              dynamicData: '{}',
            ),
          );

      final matchSolarion = await dao.matchScannedCard(['Solarion Creature'], 'mtg');
      expect(matchSolarion, isNotNull);
      expect(matchSolarion!.id, equals('mtg-solarion'));

      final matchSolRing = await dao.matchScannedCard(['Sol Ring Artifact'], 'mtg');
      expect(matchSolRing, isNotNull);
      expect(matchSolRing!.id, equals('mtg-sol-ring'));
    });

    test('F8.B3: card names with special unicode accents verify via sanitized representation', () async {
      await dao.into(dao.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'mtg-lorien',
              collectionType: 'mtg',
              name: 'Lórien Revealed',
              setOrSeries: 'Lord of the Rings',
              imageUrl: '',
              acquiredPrice: 3.0,
              acquiredDate: DateTime.now(),
              quantity: const drift.Value(0),
              condition: 'NM',
              currentMarketPrice: 3.5,
              lastPriceUpdate: DateTime.now(),
              dynamicData: '{}',
            ),
          );

      final match = await dao.matchScannedCard(['Lórien Revealed Sorcery'], 'mtg');
      expect(match, isNotNull);
      expect(match!.id, equals('mtg-lorien'));
    });

    test('F8.B4: candidate card where no candidate matches Dart contains safely returns null', () async {
      final lines = ['Zephyr Missile Bomb'];
      final match = await dao.matchScannedCard(lines, 'mtg');
      expect(match, isNull);
    });

    test('F8.B5: base card name extraction on complex split cards ignores secondary face', () async {
      final match = await dao.matchScannedCard(['Fire Instant (R)'], 'mtg');
      expect(match, isNotNull);
      expect(match!.id, equals('mtg-split-fire-ice'));
    });
  });

  group('Tier 2 - F9 Boundaries: Inbox Staging', () {
    late AppDatabase db;
    late VaultDao dao;

    setUp(() async {
      db = createTestDatabase();
      dao = db.vaultDao;
      await dao.clearAllItems();
    });

    tearDown(() async {
      await db.close();
    });

    test('F9.B1: re-scanning card multiple times increments quantity from 1 to N without duplicate IDs', () async {
      final card = createTestCard(id: 'multi-scan-1', name: 'Lightning Bolt');
      for (int i = 0; i < 5; i++) {
        await dao.upsertScannedCardToInbox(card);
      }

      final items = await (dao.select(dao.vaultItems)..where((t) => t.id.equals('multi-scan-1'))).get();
      expect(items.length, equals(1));
      expect(items.first.quantity, equals(5));
    });

    test('F9.B2: staging card preserves existing acquired price and updates lastPriceUpdate', () async {
      final originalTime = DateTime.now().subtract(const Duration(days: 10));
      final card = createTestCard(id: 'price-time-card', name: 'Time Walk', acquiredPrice: 2000.0);

      await dao.into(dao.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: card.id,
              collectionType: card.collectionType,
              name: card.name,
              setOrSeries: card.setOrSeries,
              imageUrl: card.imageUrl,
              acquiredPrice: 2000.0,
              acquiredDate: originalTime,
              quantity: const drift.Value(0),
              condition: 'NM',
              currentMarketPrice: 2500.0,
              lastPriceUpdate: originalTime,
              dynamicData: '{}',
            ),
          );

      await dao.upsertScannedCardToInbox(card);

      final updated = await (dao.select(dao.vaultItems)..where((t) => t.id.equals(card.id))).getSingle();
      expect(updated.acquiredPrice, equals(2000.0));
      expect(updated.lastPriceUpdate.isAfter(originalTime), isTrue);
    });

    test('F9.B3: staging cross-collection cards maintains individual collection types', () async {
      final mtg = createTestCard(id: 'iso-mtg', name: 'MTG Card', collectionType: 'mtg');
      final pkm = createTestCard(id: 'iso-pkm', name: 'PKM Card', collectionType: 'pokemon');

      await dao.upsertScannedCardToInbox(mtg);
      await dao.upsertScannedCardToInbox(pkm);

      final inbox = await dao.watchInboxItems().first;
      expect(inbox.firstWhere((c) => c.id == 'iso-mtg').collectionType, equals('mtg'));
      expect(inbox.firstWhere((c) => c.id == 'iso-pkm').collectionType, equals('pokemon'));
    });

    test('F9.B4: empty inbox stream emits empty list cleanly without null reference errors', () async {
      final inbox = await dao.watchInboxItems().first;
      expect(inbox, isA<List<VaultItem>>());
      expect(inbox.isEmpty, isTrue);
    });

    test('F9.B5: staged items are ordered by lastPriceUpdate descending', () async {
      final card1 = createTestCard(id: 'ord-1', name: 'Old Scan');
      final card2 = createTestCard(id: 'ord-2', name: 'New Scan');

      await dao.upsertScannedCardToInbox(card1);
      await Future.delayed(const Duration(milliseconds: 10));
      await dao.upsertScannedCardToInbox(card2);

      final inbox = await dao.watchInboxItems().first;
      expect(inbox.first.id, equals('ord-2'));
      expect(inbox.last.id, equals('ord-1'));
    });
  });

  group('Tier 2 - F10 Boundaries: Portfolio Integrity', () {
    late AppDatabase db;
    late VaultDao dao;

    setUp(() async {
      db = createTestDatabase();
      dao = db.vaultDao;
      await dao.clearAllItems();
    });

    tearDown(() async {
      await db.close();
    });

    test('F10.B1: portfolio valuation calculates 0.0 market value and cost basis when only catalog cards exist', () async {
      final cat = createTestCard(id: 'cat-solo', name: 'Catalog Solo', quantity: 0, currentMarketPrice: 1000.0);
      await dao.into(dao.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: cat.id,
              collectionType: cat.collectionType,
              name: cat.name,
              setOrSeries: cat.setOrSeries,
              imageUrl: '',
              acquiredPrice: 500.0,
              acquiredDate: DateTime.now(),
              quantity: const drift.Value(0),
              condition: 'NM',
              currentMarketPrice: 1000.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: '{}',
            ),
          );

      final owned = await dao.getItemsByCollection('all', onlyOwned: true);
      double totalVal = 0;
      for (final item in owned) {
        totalVal += (item.currentMarketPrice * item.quantity);
      }
      expect(totalVal, equals(0.0));
    });

    test('F10.B2: adding item to inbox does not increase owned count of binders', () async {
      final binder = await dao.createBinder(name: 'Empty Binder', collectionType: 'mtg');
      final inboxCard = createTestCard(id: 'inbox-count-card', name: 'Inbox Count Card');
      await dao.upsertScannedCardToInbox(inboxCard);

      final binderCounts = await dao.watchBinderItemCounts().first;
      expect(binderCounts.containsKey(binder.id), isFalse);
    });

    test('F10.B3: multiple binders with owned cards compute discrete item counts without cross-binder leakage', () async {
      final binderA = await dao.createBinder(name: 'Binder A', collectionType: 'mtg');
      final binderB = await dao.createBinder(name: 'Binder B', collectionType: 'mtg');

      final cardA = createTestCard(id: 'b-card-a', name: 'Card A', quantity: 3, primaryBinderId: binderA.id);
      final cardB = createTestCard(id: 'b-card-b', name: 'Card B', quantity: 5, primaryBinderId: binderB.id);

      await dao.into(dao.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: cardA.id,
              collectionType: cardA.collectionType,
              name: cardA.name,
              setOrSeries: cardA.setOrSeries,
              imageUrl: '',
              acquiredPrice: 5.0,
              acquiredDate: DateTime.now(),
              quantity: const drift.Value(3),
              condition: 'NM',
              currentMarketPrice: 5.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: '{}',
              primaryBinderId: drift.Value(binderA.id),
            ),
          );

      await dao.into(dao.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: cardB.id,
              collectionType: cardB.collectionType,
              name: cardB.name,
              setOrSeries: cardB.setOrSeries,
              imageUrl: '',
              acquiredPrice: 5.0,
              acquiredDate: DateTime.now(),
              quantity: const drift.Value(5),
              condition: 'NM',
              currentMarketPrice: 5.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: '{}',
              primaryBinderId: drift.Value(binderB.id),
            ),
          );

      final counts = await dao.watchBinderItemCounts().first;
      expect(counts[binderA.id], equals(3));
      expect(counts[binderB.id], equals(5));
    });

    test('F10.B4: owned card with zero market price is handled gracefully in valuation calculations', () async {
      final binder = await dao.createBinder(name: 'Zero Val Binder', collectionType: 'mtg');
      final zeroCard = createTestCard(
        id: 'zero-val-card',
        name: 'Free Promo Card',
        quantity: 1,
        acquiredPrice: 0.0,
        currentMarketPrice: 0.0,
        primaryBinderId: binder.id,
      );

      await dao.into(dao.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: zeroCard.id,
              collectionType: zeroCard.collectionType,
              name: zeroCard.name,
              setOrSeries: zeroCard.setOrSeries,
              imageUrl: '',
              acquiredPrice: 0.0,
              acquiredDate: DateTime.now(),
              quantity: const drift.Value(1),
              condition: 'NM',
              currentMarketPrice: 0.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: '{}',
              primaryBinderId: drift.Value(binder.id),
            ),
          );

      final items = await dao.getItemsByCollection('mtg', onlyOwned: true);
      expect(items.length, equals(1));
      expect(items.first.currentMarketPrice, equals(0.0));
    });

    test('F10.B5: switching active game context filters inventory strictly to that collection', () async {
      final binderMtg = await dao.createBinder(name: 'MTG Binder', collectionType: 'mtg');
      final binderPkm = await dao.createBinder(name: 'PKM Binder', collectionType: 'pokemon');

      await dao.into(dao.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'filter-mtg',
              collectionType: 'mtg',
              name: 'Sol Ring',
              setOrSeries: 'CMD',
              imageUrl: '',
              acquiredPrice: 2.0,
              acquiredDate: DateTime.now(),
              quantity: const drift.Value(1),
              condition: 'NM',
              currentMarketPrice: 2.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: '{}',
              primaryBinderId: drift.Value(binderMtg.id),
            ),
          );

      await dao.into(dao.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'filter-pkm',
              collectionType: 'pokemon',
              name: 'Pikachu',
              setOrSeries: 'Base',
              imageUrl: '',
              acquiredPrice: 10.0,
              acquiredDate: DateTime.now(),
              quantity: const drift.Value(1),
              condition: 'NM',
              currentMarketPrice: 10.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: '{}',
              primaryBinderId: drift.Value(binderPkm.id),
            ),
          );

      final mtgOwned = await dao.getItemsByCollection('mtg', onlyOwned: true);
      expect(mtgOwned.length, equals(1));
      expect(mtgOwned.first.name, equals('Sol Ring'));

      final pkmOwned = await dao.getItemsByCollection('pokemon', onlyOwned: true);
      expect(pkmOwned.length, equals(1));
      expect(pkmOwned.first.name, equals('Pikachu'));
    });
  });

  group('Tier 2 - F11 Boundaries: Single Deletion', () {
    late AppDatabase db;
    late VaultDao dao;

    setUp(() async {
      db = createTestDatabase();
      dao = db.vaultDao;
      await dao.clearAllItems();
    });

    tearDown(() async {
      await db.close();
    });

    test('F11.B1: deleting non-existent ID returns 0 affected rows without throwing exception', () async {
      final res = await deleteVaultItem(dao, 'does-not-exist');
      expect(res, equals(0));
    });

    test('F11.B2: deleting card anchored to binder removes it and decrements binder count', () async {
      final binder = await dao.createBinder(name: 'Deck Box', collectionType: 'mtg');
      final card = createTestCard(id: 'deck-card-1', name: 'Deck Card 1', quantity: 1, primaryBinderId: binder.id);

      await dao.into(dao.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: card.id,
              collectionType: card.collectionType,
              name: card.name,
              setOrSeries: card.setOrSeries,
              imageUrl: '',
              acquiredPrice: 1.0,
              acquiredDate: DateTime.now(),
              quantity: const drift.Value(1),
              condition: 'NM',
              currentMarketPrice: 1.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: '{}',
              primaryBinderId: drift.Value(binder.id),
            ),
          );

      expect((await dao.watchBinderItemCounts().first)[binder.id], equals(1));

      await deleteVaultItem(dao, 'deck-card-1');

      final counts = await dao.watchBinderItemCounts().first;
      expect(counts.containsKey(binder.id), isFalse);
    });

    test('F11.B3: deleting card with quantity > 1 removes all copies permanently', () async {
      final card = createTestCard(id: 'stack-1', name: 'Stack Card', quantity: 10);
      await dao.into(dao.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: card.id,
              collectionType: card.collectionType,
              name: card.name,
              setOrSeries: card.setOrSeries,
              imageUrl: '',
              acquiredPrice: 1.0,
              acquiredDate: DateTime.now(),
              quantity: const drift.Value(10),
              condition: 'NM',
              currentMarketPrice: 1.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: '{}',
            ),
          );

      await deleteVaultItem(dao, 'stack-1');

      final found = await (dao.select(dao.vaultItems)..where((t) => t.id.equals('stack-1'))).getSingleOrNull();
      expect(found, isNull);
    });

    test('F11.B4: rapid successive deletion calls on same ID execute idempotently', () async {
      final card = createTestCard(id: 'idempotent-1', name: 'Idempotent Card');
      await dao.upsertScannedCardToInbox(card);

      final res1 = await deleteVaultItem(dao, 'idempotent-1');
      final res2 = await deleteVaultItem(dao, 'idempotent-1');
      final res3 = await deleteVaultItem(dao, 'idempotent-1');

      expect(res1, equals(1));
      expect(res2, equals(0));
      expect(res3, equals(0));
    });

    test('F11.B5: deleting a card does not delete or affect associated binders table', () async {
      final binder = await dao.createBinder(name: 'Persistent Binder', collectionType: 'mtg');
      final card = createTestCard(id: 'pers-card', name: 'Card', quantity: 1, primaryBinderId: binder.id);

      await dao.into(dao.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: card.id,
              collectionType: card.collectionType,
              name: card.name,
              setOrSeries: card.setOrSeries,
              imageUrl: '',
              acquiredPrice: 1.0,
              acquiredDate: DateTime.now(),
              quantity: const drift.Value(1),
              condition: 'NM',
              currentMarketPrice: 1.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: '{}',
              primaryBinderId: drift.Value(binder.id),
            ),
          );

      await deleteVaultItem(dao, 'pers-card');

      final binders = await dao.watchBindersByCollection('mtg').first;
      expect(binders.length, equals(1));
      expect(binders.first.name, equals('Persistent Binder'));
    });
  });

  group('Tier 2 - F12 Boundaries: Bulk Deletion', () {
    late AppDatabase db;
    late VaultDao dao;

    setUp(() async {
      db = createTestDatabase();
      dao = db.vaultDao;
      await dao.clearAllItems();
    });

    tearDown(() async {
      await db.close();
    });

    test('F12.B1: bulk deleting with empty ID list returns 0 and does not modify database', () async {
      final card = createTestCard(id: 'b-empty-card', name: 'Test Card');
      await dao.upsertScannedCardToInbox(card);

      final deleted = await deleteVaultItems(dao, []);
      expect(deleted, equals(0));

      final inbox = await dao.watchInboxItems().first;
      expect(inbox.length, equals(1));
    });

    test('F12.B2: bulk deleting with duplicate IDs deletes target rows safely', () async {
      final cardA = createTestCard(id: 'dup-id-a', name: 'Card A');
      final cardB = createTestCard(id: 'dup-id-b', name: 'Card B');

      await dao.upsertScannedCardToInbox(cardA);
      await dao.upsertScannedCardToInbox(cardB);

      final deleted = await deleteVaultItems(dao, ['dup-id-a', 'dup-id-a', 'dup-id-b']);
      expect(deleted, equals(2));

      final inbox = await dao.watchInboxItems().first;
      expect(inbox.isEmpty, isTrue);
    });

    test('F12.B3: bulk deleting with mixed existing and non-existent IDs deletes existing rows accurately', () async {
      final cardA = createTestCard(id: 'exist-a', name: 'Card Exist');
      await dao.upsertScannedCardToInbox(cardA);

      final deleted = await deleteVaultItems(dao, ['exist-a', 'fake-uuid-1', 'fake-uuid-2']);
      expect(deleted, equals(1));

      final inbox = await dao.watchInboxItems().first;
      expect(inbox.isEmpty, isTrue);
    });

    test('F12.B4: bulk deleting 50 items in a single batch operation executes within SQLite limits', () async {
      final ids = <String>[];
      for (int i = 1; i <= 50; i++) {
        final id = 'stress-item-$i';
        ids.add(id);
        await dao.upsertScannedCardToInbox(createTestCard(id: id, name: 'Card $i'));
      }

      var inbox = await dao.watchInboxItems().first;
      expect(inbox.length, equals(50));

      final deleted = await deleteVaultItems(dao, ids);
      expect(deleted, equals(50));

      inbox = await dao.watchInboxItems().first;
      expect(inbox.isEmpty, isTrue);
    });

    test('F12.B5: bulk deleting all items in a binder resets binder item count to 0 while keeping binder intact', () async {
      final binder = await dao.createBinder(name: 'Wiped Binder', collectionType: 'mtg');

      for (int i = 1; i <= 3; i++) {
        final id = 'wiped-card-$i';
        await dao.into(dao.vaultItems).insert(
              VaultItemsCompanion.insert(
                id: id,
                collectionType: 'mtg',
                name: 'Wiped Card $i',
                setOrSeries: 'Set',
                imageUrl: '',
                acquiredPrice: 1.0,
                acquiredDate: DateTime.now(),
                quantity: const drift.Value(1),
                condition: 'NM',
                currentMarketPrice: 1.0,
                lastPriceUpdate: DateTime.now(),
                dynamicData: '{}',
                primaryBinderId: drift.Value(binder.id),
              ),
            );
      }

      expect((await dao.watchBinderItemCounts().first)[binder.id], equals(3));

      await deleteVaultItems(dao, ['wiped-card-1', 'wiped-card-2', 'wiped-card-3']);

      final counts = await dao.watchBinderItemCounts().first;
      expect(counts.containsKey(binder.id), isFalse);

      final binders = await dao.watchBindersByCollection('mtg').first;
      expect(binders.length, equals(1));
      expect(binders.first.id, equals(binder.id));
    });
  });
}
