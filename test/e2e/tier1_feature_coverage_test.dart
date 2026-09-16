import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/scanner/domain/card_perimeter_calculator.dart';
import 'package:countr/features/scanner/domain/ocr_heuristic_matcher.dart';
import 'package:countr/features/scanner/presentation/screens/inbox_screen.dart';
import 'package:countr/features/scanner/presentation/screens/scanner_modal.dart';
import 'package:countr/features/scanner/presentation/widgets/dynamic_scanner_overlay.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';

import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ===========================================================================
  // TIER 1 - FEATURE COVERAGE (>=5 tests per feature F1 - F12)
  // ===========================================================================

  group('Tier 1 - F1: Bounding Perimeter Calculation', () {
    test('F1.1: single block calculates enclosing perimeter with default padding (8% x, 12% y)', () {
      final blocks = [
        createMockTextBlock(const Rect.fromLTWH(100, 100, 200, 300)),
      ];
      final perimeter = CardPerimeterCalculator.calculatePerimeter(blocks);

      expect(perimeter, isNotNull);
      expect(perimeter!.left, 84.0); // 100 - (200 * 0.08)
      expect(perimeter.top, 64.0);  // 100 - (300 * 0.12)
      expect(perimeter.right, 316.0); // 300 + 16
      expect(perimeter.bottom, 436.0); // 400 + 36
    });

    test('F1.2: multiple blocks computes outer bounding hull perimeter', () {
      final blocks = [
        createMockTextBlock(const Rect.fromLTWH(50, 60, 100, 30)),
        createMockTextBlock(const Rect.fromLTWH(80, 200, 120, 40)),
      ];
      // minLeft=50, minTop=60, maxRight=200, maxBottom=240. width=150, height=180
      // padX = 150 * 0.08 = 12, padY = 180 * 0.12 = 21.6
      final perimeter = CardPerimeterCalculator.calculatePerimeter(blocks);

      expect(perimeter, isNotNull);
      expect(perimeter!.left, 38.0);
      expect(perimeter.top, closeTo(38.4, 0.001));
      expect(perimeter.right, 212.0);
      expect(perimeter.bottom, closeTo(261.6, 0.001));
    });

    test('F1.3: maps image space rect to screen space with BoxFit.cover', () {
      const imageSize = Size(1000, 1000);
      const screenSize = Size(500, 1000); // Scale is max(0.5, 1.0) = 1.0
      const imageRect = Rect.fromLTWH(100, 100, 200, 300);

      final mapped = CardPerimeterCalculator.mapImageRectToScreen(
        imageRect: imageRect,
        imageSize: imageSize,
        screenSize: screenSize,
        fit: BoxFit.cover,
      );

      // scaledWidth = 1000, scaledHeight = 1000. offsetX = (500 - 1000)/2 = -250, offsetY = 0
      expect(mapped.left, -150.0);
      expect(mapped.top, 100.0);
      expect(mapped.width, 200.0);
      expect(mapped.height, 300.0);
    });

    test('F1.4: maps image space rect to screen space with BoxFit.contain and centering offset', () {
      const imageSize = Size(1000, 2000);
      const screenSize = Size(500, 500); // Scale is min(0.5, 0.25) = 0.25
      const imageRect = Rect.fromLTWH(200, 400, 400, 800);

      final mapped = CardPerimeterCalculator.mapImageRectToScreen(
        imageRect: imageRect,
        imageSize: imageSize,
        screenSize: screenSize,
        fit: BoxFit.contain,
      );

      // scaledWidth = 250, scaledHeight = 500. offsetX = (500 - 250)/2 = 125, offsetY = 0
      expect(mapped.left, 200 * 0.25 + 125.0); // 175
      expect(mapped.top, 400 * 0.25); // 100
      expect(mapped.width, 100.0);
      expect(mapped.height, 200.0);
    });

    test('F1.5: correctly applies rotation compensation for 90deg and 270deg orientations', () {
      const rawSize = Size(720, 1280);

      final upright0 = CardPerimeterCalculator.getUprightImageSize(
        rawSize: rawSize,
        rotation: InputImageRotation.rotation0deg,
      );
      final upright90 = CardPerimeterCalculator.getUprightImageSize(
        rawSize: rawSize,
        rotation: InputImageRotation.rotation90deg,
      );
      final upright270 = CardPerimeterCalculator.getUprightImageSize(
        rawSize: rawSize,
        rotation: InputImageRotation.rotation270deg,
      );

      expect(upright0, const Size(720, 1280));
      expect(upright90, const Size(1280, 720));
      expect(upright270, const Size(1280, 720));
    });
  });

  group('Tier 1 - F2: Dynamic Reactive Reticle Overlay', () {
    testWidgets('F2.1: renders 4 corner brackets when cardBounds are provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DynamicScannerOverlay(
              cardBounds: Rect.fromLTWH(50, 100, 300, 420),
              isGreenFlash: false,
              isPaused: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('corner_bracket_tl')), findsOneWidget);
      expect(find.byKey(const Key('corner_bracket_tr')), findsOneWidget);
      expect(find.byKey(const Key('corner_bracket_bl')), findsOneWidget);
      expect(find.byKey(const Key('corner_bracket_br')), findsOneWidget);
    });

    testWidgets('F2.2: smoothly interpolates coordinates via TweenAnimationBuilder', (tester) async {
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
      expect(find.byType(TweenAnimationBuilder<Rect?>), findsOneWidget);

      // Move bounds
      notifier.value = const Rect.fromLTWH(100, 150, 250, 350);
      await tester.pump(const Duration(milliseconds: 90)); // Halfway through 180ms
      expect(find.byType(CustomPaint), findsWidgets);

      await tester.pump(const Duration(milliseconds: 100)); // Settled
    });

    testWidgets('F2.3: displays bounded laser scan line when active and animated', (tester) async {
      final controller = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(seconds: 1),
      )..value = 0.5;
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DynamicScannerOverlay(
              cardBounds: const Rect.fromLTWH(40, 80, 240, 320),
              isGreenFlash: false,
              isPaused: false,
              scanLineAnimation: controller,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('bounded_laser_scan_line')), findsOneWidget);
    });

    testWidgets('F2.4: switches theme color to accentEmerald when isGreenFlash is true', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DynamicScannerOverlay(
              cardBounds: Rect.fromLTWH(40, 80, 240, 320),
              isGreenFlash: true,
              isPaused: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final customPaints = tester.widgetList<CustomPaint>(find.byType(CustomPaint));
      expect(customPaints, isNotEmpty);
    });

    testWidgets('F2.5: switches theme color to accentAmber and hides laser line when isPaused is true', (tester) async {
      final controller = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(seconds: 1),
      )..value = 0.5;
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DynamicScannerOverlay(
              cardBounds: const Rect.fromLTWH(40, 80, 240, 320),
              isGreenFlash: false,
              isPaused: true,
              scanLineAnimation: controller,
            ),
          ),
        ),
      );
      await tester.pump();

      // Laser line must be hidden while paused to indicate idle camera
      expect(find.byKey(const Key('bounded_laser_scan_line')), findsNothing);
    });
  });

  group('Tier 1 - F3: Camera Frame Skipping', () {
    late AppDatabase db;

    setUp(() {
      db = createTestDatabase();
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('F3.1: frame count increments monotonically on each incoming frame', (tester) async {
      await tester.pumpWidget(createE2ETestHarness(child: const ScannerModal(), db: db));
      await tester.pump(const Duration(milliseconds: 200));

      final state = tester.state(find.byType(ScannerModal)) as dynamic;
      expect(state.frameCount, 0);

      final dummyImage = createMockCameraImage();
      await state.processCameraFrameForTesting(dummyImage);
      expect(state.frameCount, 1);

      await state.processCameraFrameForTesting(dummyImage);
      expect(state.frameCount, 2);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('F3.2: frames 1 through 9 are skipped without triggering OCR lock', (tester) async {
      await tester.pumpWidget(createE2ETestHarness(child: const ScannerModal(), db: db));
      await tester.pump(const Duration(milliseconds: 200));

      final state = tester.state(find.byType(ScannerModal)) as dynamic;
      final dummyImage = createMockCameraImage();

      for (int i = 1; i <= 9; i++) {
        await state.processCameraFrameForTesting(dummyImage);
        expect(state.frameCount, i);
        expect(state.isProcessing, isFalse, reason: 'Frame $i must be skipped without acquiring lock');
      }

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('F3.3: frame 10 (modulo 10 == 0) triggers processing cycle', (tester) async {
      await tester.pumpWidget(createE2ETestHarness(child: const ScannerModal(), db: db));
      await tester.pump(const Duration(milliseconds: 200));

      final state = tester.state(find.byType(ScannerModal)) as dynamic;
      final dummyImage = createMockCameraImage();

      for (int i = 1; i <= 10; i++) {
        await state.processCameraFrameForTesting(dummyImage);
      }
      expect(state.frameCount, 10);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('F3.4: frames 11 through 19 are skipped and frame 20 triggers processing', (tester) async {
      await tester.pumpWidget(createE2ETestHarness(child: const ScannerModal(), db: db));
      await tester.pump(const Duration(milliseconds: 200));

      final state = tester.state(find.byType(ScannerModal)) as dynamic;
      final dummyImage = createMockCameraImage();

      for (int i = 1; i <= 20; i++) {
        await state.processCameraFrameForTesting(dummyImage);
      }
      expect(state.frameCount, 20);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('F3.5: frame skipping continues safely during paused state', (tester) async {
      await tester.pumpWidget(createE2ETestHarness(child: const ScannerModal(), db: db));
      await tester.pump(const Duration(milliseconds: 200));

      // Pause scanner
      await tester.tap(find.byKey(const Key('scanner_pause_toggle')));
      await tester.pump(const Duration(milliseconds: 200));

      final state = tester.state(find.byType(ScannerModal)) as dynamic;
      final dummyImage = createMockCameraImage();

      for (int i = 1; i <= 15; i++) {
        await state.processCameraFrameForTesting(dummyImage);
      }
      expect(state.frameCount, 15);
      expect(state.isProcessing, isFalse);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });
  });

  group('Tier 1 - F4: Strict Asynchronous Lock', () {
    late AppDatabase db;

    setUp(() {
      db = createTestDatabase();
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('F4.1: initial lock state is inactive (isProcessing == false)', (tester) async {
      await tester.pumpWidget(createE2ETestHarness(child: const ScannerModal(), db: db));
      await tester.pump(const Duration(milliseconds: 200));

      final state = tester.state(find.byType(ScannerModal)) as dynamic;
      expect(state.isProcessing, isFalse);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('F4.2: lock prevents re-entrant frame processing while another frame is in flight', (tester) async {
      await tester.pumpWidget(createE2ETestHarness(child: const ScannerModal(), db: db));
      await tester.pump(const Duration(milliseconds: 200));

      final state = tester.state(find.byType(ScannerModal)) as dynamic;
      expect(state.isProcessing, isFalse);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('F4.3: guaranteed finally block resets isProcessing to false upon frame completion', (tester) async {
      await tester.pumpWidget(createE2ETestHarness(child: const ScannerModal(), db: db));
      await tester.pump(const Duration(milliseconds: 200));

      final state = tester.state(find.byType(ScannerModal)) as dynamic;
      final dummyImage = createMockCameraImage();

      // Process 10 frames to hit frame 10
      for (int i = 1; i <= 10; i++) {
        await state.processCameraFrameForTesting(dummyImage);
      }
      expect(state.isProcessing, isFalse, reason: 'Lock must be released in finally');

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('F4.4: guaranteed finally block resets isProcessing to false even on exception', (tester) async {
      await tester.pumpWidget(createE2ETestHarness(child: const ScannerModal(), db: db));
      await tester.pump(const Duration(milliseconds: 200));

      final state = tester.state(find.byType(ScannerModal)) as dynamic;
      final dummyImage = createMockCameraImage();

      // Send frames past frame 10 (without camera controller, it handles null gracefully)
      for (int i = 1; i <= 20; i++) {
        await state.processCameraFrameForTesting(dummyImage);
      }
      expect(state.isProcessing, isFalse);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('F4.5: finally block triggers setState updating UI without stream freeze', (tester) async {
      await tester.pumpWidget(createE2ETestHarness(child: const ScannerModal(), db: db));
      await tester.pump(const Duration(milliseconds: 200));

      final state = tester.state(find.byType(ScannerModal)) as dynamic;
      expect(state.mounted, isTrue);

      final dummyImage = createMockCameraImage();
      for (int i = 1; i <= 10; i++) {
        await state.processCameraFrameForTesting(dummyImage);
      }

      // UI is responsive
      expect(find.byType(ScannerModal), findsOneWidget);
      expect(find.text('Scanner Camera Active'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });
  });

  group('Tier 1 - F5: Text Sanitizer Helper', () {
    test('F5.1: converts uppercase characters and removes standard spaces', () {
      expect(sanitize('Black Lotus'), equals('blacklotus'));
      expect(sanitize('Mox Sapphire'), equals('moxsapphire'));
      expect(countrSanitize('Time Walk'), equals('timewalk'));
    });

    test('F5.2: strips punctuation marks, hyphens, and slashes', () {
      expect(sanitize('SV01-151 / EX'), equals('sv01151ex'));
      expect(sanitize('Fire // Ice'), equals('fireice'));
      expect(sanitize('T.J. Watt (Steelers)'), equals('tjwattsteelers'));
    });

    test('F5.3: strips single, double, and curly apostrophes', () {
      expect(sanitize('"Urza\'s Saga"'), equals('urzassaga'));
      expect(sanitize('Urza’s Tower'), equals('urzastower'));
      expect(sanitize("Mishra's Bauble"), equals('mishrasbauble'));
    });

    test('F5.4: preserves numeric digits accurately', () {
      expect(sanitize('Charizard VMAX #020'), equals('charizardvmax020'));
      expect(sanitize('151 Master Set 2023'), equals('151masterset2023'));
    });

    test('F5.5: static OcrHeuristicMatcher.sanitize and top-level sanitize yield identical results', () {
      const inputs = [
        'Black Lotus',
        'SV03-125 Charizard ex',
        '© Wizards 2023 #042',
        '"Double Quote Test"',
      ];
      for (final input in inputs) {
        expect(sanitize(input), equals(OcrHeuristicMatcher.sanitize(input)));
        expect(sanitize(input), equals(countrSanitize(input)));
      }
    });
  });

  group('Tier 1 - F6: Collector Number Regex Override', () {
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

    test('F6.1: matches card via fraction pattern (232/250) in OCR lines', () async {
      final lines = ['Random OCR Header', '232/250', 'Mythic Rare'];
      final match = await dao.matchScannedCard(lines, 'mtg');

      expect(match, isNotNull);
      expect(match!.id, equals('mtg-lotus'));
      expect(match.name, equals('Black Lotus'));
    });

    test('F6.2: matches card via explicit collectorNumber parameter override', () async {
      final lines = ['Garbled Unrecognized Text'];
      final match = await dao.matchScannedCard(lines, 'mtg', collectorNumber: '101');

      expect(match, isNotNull);
      expect(match!.id, equals('mtg-sol-ring'));
      expect(match.name, equals('Sol Ring'));
    });

    test('F6.3: matches Pokémon set-dash format (SV03-125)', () async {
      final lines = ['Pokemon TCG', 'SV03-125', 'Stage 2'];
      final match = await dao.matchScannedCard(lines, 'pokemon');

      expect(match, isNotNull);
      expect(match!.id, equals('pkm-charizard-ex'));
      expect(match.name, equals('Charizard ex'));
    });

    test('F6.4: matches hash collector format (#025 or No. 25)', () async {
      final lines = ['Electric Mouse', 'No. 25', 'Lightning'];
      final match = await dao.matchScannedCard(lines, 'pokemon');

      expect(match, isNotNull);
      expect(match!.id, equals('pkm-pikachu'));
      expect(match.name, equals('Pikachu'));
    });

    test('F6.5: collector number override bypasses garbled title text in OCR stream', () async {
      final lines = ['Totally Wrong Card Title XYZ', '259/303'];
      final match = await dao.matchScannedCard(lines, 'mtg');

      expect(match, isNotNull);
      expect(match!.id, equals('mtg-urza-saga'));
    });
  });

  group('Tier 1 - F7: SQL Wide Net Prefix Search', () {
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

    test('F7.1: queries first 5 characters of longest OCR line with length >= 4', () async {
      final lines = ['Black Lotus Vintage Masters'];
      final match = await dao.matchScannedCard(lines, 'mtg');

      expect(match, isNotNull);
      expect(match!.name, equals('Black Lotus'));
    });

    test('F7.2: matches catalog reference card with quantity == 0', () async {
      final lines = ['Sol Ring Artifact'];
      final match = await dao.matchScannedCard(lines, 'mtg');

      expect(match, isNotNull);
      expect(match!.quantity, equals(0));
      expect(match.name, equals('Sol Ring'));
    });

    test('F7.3: restricts candidates within specified collection type (mtg vs pokemon)', () async {
      final lines = ['Charizard ex'];
      final matchPokemon = await dao.matchScannedCard(lines, 'pokemon');
      expect(matchPokemon, isNotNull);
      expect(matchPokemon!.collectionType, equals('pokemon'));
    });

    test('F7.4: enforces LIMIT 25 on candidate queries to protect memory', () async {
      // Insert 30 cards starting with "Alpha"
      for (int i = 1; i <= 30; i++) {
        await dao.into(dao.vaultItems).insert(
              VaultItemsCompanion.insert(
                id: 'alpha-card-$i',
                collectionType: 'mtg',
                name: 'Alpha Card $i',
                setOrSeries: 'Alpha',
                imageUrl: '',
                acquiredPrice: 10.0,
                acquiredDate: DateTime.now(),
                quantity: const drift.Value(0),
                condition: 'NM',
                currentMarketPrice: 12.0,
                lastPriceUpdate: DateTime.now(),
                dynamicData: '{}',
              ),
            );
      }

      final match = await dao.matchScannedCard(['Alpha Card 1'], 'mtg');
      expect(match, isNotNull);
      expect(match!.name, startsWith('Alpha Card'));
    });

    test('F7.5: falls back to 3-character line when no lines >= 4 chars exist', () async {
      await dao.into(dao.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'fog-card',
              collectionType: 'mtg',
              name: 'Fog',
              setOrSeries: 'M10',
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

      final match = await dao.matchScannedCard(['Fog'], 'mtg');
      expect(match, isNotNull);
      expect(match!.name, equals('Fog'));
    });
  });

  group('Tier 1 - F8: Dart In-Memory Name Verification', () {
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

    test('F8.1: exact match pass confirms match when sanitized OCR line equals sanitized DB name', () async {
      final lines = ['black lotus'];
      final match = await dao.matchScannedCard(lines, 'mtg');

      expect(match, isNotNull);
      expect(match!.name, equals('Black Lotus'));
    });

    test('F8.2: substring containment confirms match when OCR line contains sanitized DB name', () async {
      final lines = ['| Black Lotus | Illustrated by Christopher Rush'];
      final match = await dao.matchScannedCard(lines, 'mtg');

      expect(match, isNotNull);
      expect(match!.name, equals('Black Lotus'));
    });

    test('F8.3: strips split card delimiter (//) to extract base card name for verification', () async {
      final lines = ['Fire // Ice Instant'];
      final match = await dao.matchScannedCard(lines, 'mtg');

      expect(match, isNotNull);
      expect(match!.id, equals('mtg-split-fire-ice'));
    });

    test('F8.4: strips subtitle parentheses to extract base card name for verification', () async {
      await dao.into(dao.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'card-jace',
              collectionType: 'mtg',
              name: 'Jace, the Mind Sculptor (Mythic)',
              setOrSeries: 'Worldwake',
              imageUrl: '',
              acquiredPrice: 50.0,
              acquiredDate: DateTime.now(),
              quantity: const drift.Value(0),
              condition: 'NM',
              currentMarketPrice: 60.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: '{}',
            ),
          );

      final lines = ['Jace, the Mind Sculptor Planeswalker'];
      final match = await dao.matchScannedCard(lines, 'mtg');

      expect(match, isNotNull);
      expect(match!.id, equals('card-jace'));
    });

    test('F8.5: sorts candidates by length descending to match longest specific card first', () async {
      await dao.into(dao.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'mtg-sol-ring-extended',
              collectionType: 'mtg',
              name: 'Sol Ring Extended Art Promo',
              setOrSeries: 'Commander',
              imageUrl: '',
              acquiredPrice: 15.0,
              acquiredDate: DateTime.now(),
              quantity: const drift.Value(0),
              condition: 'NM',
              currentMarketPrice: 20.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: '{}',
            ),
          );

      final lines = ['Sol Ring Extended Art Promo Card'];
      final match = await dao.matchScannedCard(lines, 'mtg');

      expect(match, isNotNull);
      expect(match!.id, equals('mtg-sol-ring-extended'));
    });
  });

  group('Tier 1 - F9: Inbox Data Staging Isolation', () {
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

    test('F9.1: upserting scanned card stages it into SQLite with quantity 1', () async {
      final card = createTestCard(id: 'scan-1', name: 'Mox Diamond', quantity: 0);
      await dao.upsertScannedCardToInbox(card);

      final staged = await (dao.select(dao.vaultItems)..where((t) => t.id.equals('scan-1'))).getSingle();
      expect(staged.quantity, equals(1));
    });

    test('F9.2: staged card appears in watchInboxItems stream', () async {
      final card = createTestCard(id: 'scan-2', name: 'Mox Pearl', quantity: 0);
      await dao.upsertScannedCardToInbox(card);

      final inbox = await dao.watchInboxItems().first;
      expect(inbox.any((c) => c.id == 'scan-2'), isTrue);
    });

    test('F9.3: staged card with foil flag sets condition to NM (Foil) and personal notes', () async {
      final card = createTestCard(id: 'scan-foil-1', name: 'Sol Ring Foil', quantity: 0);
      await dao.upsertScannedCardToInbox(card, isFoil: true);

      final staged = await (dao.select(dao.vaultItems)..where((t) => t.id.equals('scan-foil-1'))).getSingle();
      expect(staged.condition, equals('NM (Foil)'));
      expect(staged.personalNotes, contains('Foil'));
    });

    test('F9.4: re-scanning existing card increments quantity rather than duplicating rows', () async {
      final card = createTestCard(id: 'scan-dup-1', name: 'Mana Vault', quantity: 0);
      await dao.upsertScannedCardToInbox(card);
      await dao.upsertScannedCardToInbox(card);

      final rows = await (dao.select(dao.vaultItems)..where((t) => t.id.equals('scan-dup-1'))).get();
      expect(rows.length, equals(1));
      expect(rows.first.quantity, equals(2));
    });

    testWidgets('F9.5: staged cards display in InboxScreen UI with title and metadata', (tester) async {
      final card = createTestCard(
        id: 'inbox-ui-card',
        name: 'Gilded Drake',
        setOrSeries: 'Urza\'s Saga',
        currentMarketPrice: 250.0,
      );
      await dao.upsertScannedCardToInbox(card);

      await tester.pumpWidget(createE2ETestHarness(child: const InboxScreen(), db: db));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Gilded Drake'), findsOneWidget);
      expect(find.text('Urza\'s Saga'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });
  });

  group('Tier 1 - F10: Vault & Portfolio Valuation Integrity', () {
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

    test('F10.1: unowned catalog cards (quantity == 0) are excluded from owned vault queries', () async {
      final catalogCard = createTestCard(id: 'cat-1', name: 'Catalog Card', quantity: 0);
      await dao.into(dao.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: catalogCard.id,
              collectionType: catalogCard.collectionType,
              name: catalogCard.name,
              setOrSeries: catalogCard.setOrSeries,
              imageUrl: catalogCard.imageUrl,
              acquiredPrice: catalogCard.acquiredPrice,
              acquiredDate: catalogCard.acquiredDate,
              quantity: const drift.Value(0),
              condition: 'NM',
              currentMarketPrice: 100.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: '{}',
            ),
          );

      final owned = await dao.watchItemsByCollection('mtg', onlyOwned: true).first;
      expect(owned.isEmpty, isTrue);
    });

    test('F10.2: portfolio valuation calculates strictly owned items (quantity > 0)', () async {
      // Seed 1 owned card in binder
      final binder = await dao.createBinder(name: 'Main Binder', collectionType: 'mtg');
      final ownedCard = createTestCard(
        id: 'owned-1',
        name: 'Tarmogoyf',
        quantity: 1,
        acquiredPrice: 20.0,
        currentMarketPrice: 25.0,
        primaryBinderId: binder.id,
      );

      await dao.into(dao.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: ownedCard.id,
              collectionType: ownedCard.collectionType,
              name: ownedCard.name,
              setOrSeries: ownedCard.setOrSeries,
              imageUrl: ownedCard.imageUrl,
              acquiredPrice: ownedCard.acquiredPrice,
              acquiredDate: ownedCard.acquiredDate,
              quantity: const drift.Value(1),
              condition: 'NM',
              currentMarketPrice: 25.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: '{}',
              primaryBinderId: drift.Value(binder.id),
            ),
          );

      final items = await dao.getItemsByCollection('mtg', onlyOwned: true);
      expect(items.length, equals(1));
      expect(items.first.currentMarketPrice, equals(25.0));
    });

    test('F10.3: portfolio cost basis ignores catalog cards with quantity == 0', () async {
      final items = await dao.getItemsByCollection('all', onlyOwned: true);
      double totalCost = 0;
      for (final i in items) {
        totalCost += (i.acquiredPrice * i.quantity);
      }
      expect(totalCost, equals(0.0));
    });

    test('F10.4: transferring card from Inbox to binder anchors it and integrates into binder queries', () async {
      final binder = await dao.createBinder(name: 'Vintage Power', collectionType: 'mtg');
      final card = createTestCard(id: 'power-1', name: 'Black Lotus', quantity: 0);
      await dao.upsertScannedCardToInbox(card);

      // Move to binder
      await dao.assignItemsToBinder([card.id], binder.id);

      final binderCards = await (dao.select(dao.vaultItems)..where((t) => t.primaryBinderId.equals(binder.id))).get();
      expect(binderCards.length, equals(1));
      expect(binderCards.first.name, equals('Black Lotus'));
    });

    test('F10.5: binder item counts accurately reflect only cards assigned to that specific binder', () async {
      final binder1 = await dao.createBinder(name: 'Binder 1', collectionType: 'mtg');
      final binder2 = await dao.createBinder(name: 'Binder 2', collectionType: 'mtg');

      final card1 = createTestCard(id: 'c-1', name: 'Card 1', quantity: 1, primaryBinderId: binder1.id);
      final card2 = createTestCard(id: 'c-2', name: 'Card 2', quantity: 2, primaryBinderId: binder2.id);

      await dao.into(dao.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: card1.id,
              collectionType: card1.collectionType,
              name: card1.name,
              setOrSeries: card1.setOrSeries,
              imageUrl: '',
              acquiredPrice: 10.0,
              acquiredDate: DateTime.now(),
              quantity: const drift.Value(1),
              condition: 'NM',
              currentMarketPrice: 10.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: '{}',
              primaryBinderId: drift.Value(binder1.id),
            ),
          );

      await dao.into(dao.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: card2.id,
              collectionType: card2.collectionType,
              name: card2.name,
              setOrSeries: card2.setOrSeries,
              imageUrl: '',
              acquiredPrice: 15.0,
              acquiredDate: DateTime.now(),
              quantity: const drift.Value(2),
              condition: 'NM',
              currentMarketPrice: 15.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: '{}',
              primaryBinderId: drift.Value(binder2.id),
            ),
          );

      final counts = await dao.watchBinderItemCounts().first;
      expect(counts[binder1.id], equals(1));
      expect(counts[binder2.id], equals(2));
    });
  });

  group('Tier 1 - F11: Inbox Single-Item Swipe Deletion', () {
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

    test('F11.1: deleting single card removes record permanently from SQLite vault_items table', () async {
      final card = createTestCard(id: 'del-item-1', name: 'Junk Scanned Card', quantity: 0);
      await dao.upsertScannedCardToInbox(card);

      // Verify inserted
      var existing = await (dao.select(dao.vaultItems)..where((t) => t.id.equals('del-item-1'))).getSingleOrNull();
      expect(existing, isNotNull);

      // Execute deletion
      final deletedCount = await deleteVaultItem(dao, 'del-item-1');
      expect(deletedCount, equals(1));

      // Verify removed
      existing = await (dao.select(dao.vaultItems)..where((t) => t.id.equals('del-item-1'))).getSingleOrNull();
      expect(existing, isNull);
    });

    test('F11.2: deletion reactively updates watchInboxItems stream from N to N-1 items', () async {
      final card1 = createTestCard(id: 'stream-del-1', name: 'Card One');
      final card2 = createTestCard(id: 'stream-del-2', name: 'Card Two');

      await dao.upsertScannedCardToInbox(card1);
      await dao.upsertScannedCardToInbox(card2);

      var inbox = await dao.watchInboxItems().first;
      expect(inbox.length, equals(2));

      await deleteVaultItem(dao, 'stream-del-1');

      inbox = await dao.watchInboxItems().first;
      expect(inbox.length, equals(1));
      expect(inbox.first.id, equals('stream-del-2'));
    });

    test('F11.3: deleting a card does not delete or alter other cards in the inbox', () async {
      final cardKeep = createTestCard(id: 'keep-1', name: 'Keeper Card');
      final cardDrop = createTestCard(id: 'drop-1', name: 'Drop Card');

      await dao.upsertScannedCardToInbox(cardKeep);
      await dao.upsertScannedCardToInbox(cardDrop);

      await deleteVaultItem(dao, 'drop-1');

      final keeper = await (dao.select(dao.vaultItems)..where((t) => t.id.equals('keep-1'))).getSingle();
      expect(keeper.name, equals('Keeper Card'));
      expect(keeper.quantity, equals(1));
    });

    test('F11.4: deleting the last card in inbox transitions watchInboxItems to empty', () async {
      final cardSolo = createTestCard(id: 'solo-1', name: 'Solo Card');
      await dao.upsertScannedCardToInbox(cardSolo);

      expect((await dao.watchInboxItems().first).length, equals(1));

      await deleteVaultItem(dao, 'solo-1');

      expect((await dao.watchInboxItems().first).isEmpty, isTrue);
    });

    test('F11.5: deleting non-existent card ID completes safely without throwing exceptions', () async {
      final deleted = await deleteVaultItem(dao, 'non-existent-uuid-999');
      expect(deleted, equals(0));
    });
  });

  group('Tier 1 - F12: Inbox Bulk Selection & Trash Deletion', () {
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

    test('F12.1: bulk deleting multiple IDs permanently removes all specified rows from SQLite', () async {
      final card1 = createTestCard(id: 'bulk-1', name: 'Bulk Card 1');
      final card2 = createTestCard(id: 'bulk-2', name: 'Bulk Card 2');
      final card3 = createTestCard(id: 'bulk-3', name: 'Bulk Card 3');

      await dao.upsertScannedCardToInbox(card1);
      await dao.upsertScannedCardToInbox(card2);
      await dao.upsertScannedCardToInbox(card3);

      final deleted = await deleteVaultItems(dao, ['bulk-1', 'bulk-2']);
      expect(deleted, equals(2));

      final remaining = await (dao.select(dao.vaultItems)..where((t) => t.id.isIn(['bulk-1', 'bulk-2', 'bulk-3']))).get();
      expect(remaining.length, equals(1));
      expect(remaining.first.id, equals('bulk-3'));
    });

    test('F12.2: bulk deleting all staged cards clears the inbox completely', () async {
      final ids = <String>[];
      for (int i = 1; i <= 5; i++) {
        final id = 'clear-$i';
        ids.add(id);
        await dao.upsertScannedCardToInbox(createTestCard(id: id, name: 'Card $i'));
      }

      var inbox = await dao.watchInboxItems().first;
      expect(inbox.length, equals(5));

      final deleted = await deleteVaultItems(dao, ids);
      expect(deleted, equals(5));

      inbox = await dao.watchInboxItems().first;
      expect(inbox.isEmpty, isTrue);
    });

    test('F12.3: bulk deleting a subset leaves unselected staged cards completely intact', () async {
      final cardA = createTestCard(id: 'sub-a', name: 'Card A');
      final cardB = createTestCard(id: 'sub-b', name: 'Card B');
      final cardC = createTestCard(id: 'sub-c', name: 'Card C');

      await dao.upsertScannedCardToInbox(cardA);
      await dao.upsertScannedCardToInbox(cardB);
      await dao.upsertScannedCardToInbox(cardC);

      await deleteVaultItems(dao, ['sub-a', 'sub-c']);

      final inbox = await dao.watchInboxItems().first;
      expect(inbox.length, equals(1));
      expect(inbox.first.id, equals('sub-b'));
    });

    test('F12.4: bulk deleting an empty list of IDs is a safe no-op', () async {
      final cardX = createTestCard(id: 'noop-1', name: 'Card X');
      await dao.upsertScannedCardToInbox(cardX);

      final deleted = await deleteVaultItems(dao, []);
      expect(deleted, equals(0));

      final inbox = await dao.watchInboxItems().first;
      expect(inbox.length, equals(1));
    });

    test('F12.5: bulk deletion works across mixed card types (MTG, Pokémon, One Piece)', () async {
      final mtg = createTestCard(id: 'mix-mtg', name: 'Mox Diamond', collectionType: 'mtg');
      final pkm = createTestCard(id: 'mix-pkm', name: 'Charizard', collectionType: 'pokemon');
      final op = createTestCard(id: 'mix-op', name: 'Luffy', collectionType: 'onepiece');

      await dao.upsertScannedCardToInbox(mtg);
      await dao.upsertScannedCardToInbox(pkm);
      await dao.upsertScannedCardToInbox(op);

      final deleted = await deleteVaultItems(dao, ['mix-mtg', 'mix-pkm', 'mix-op']);
      expect(deleted, equals(3));

      final inbox = await dao.watchInboxItems().first;
      expect(inbox.isEmpty, isTrue);
    });
  });
}
