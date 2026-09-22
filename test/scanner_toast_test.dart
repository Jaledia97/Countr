import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/constants/app_colors.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/scanner/presentation/screens/inbox_screen.dart';
import 'package:countr/features/scanner/presentation/screens/scanner_modal.dart';
import 'package:countr/features/scanner/presentation/widgets/scanner_success_toast.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.vaultDao.clearAllItems();
  });

  tearDown(() async {
    await db.close();
  });

  Widget createTestApp({required Widget child}) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        vaultDaoProvider.overrideWithValue(db.vaultDao),
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  VaultItem createMockCard({
    String id = 'test-card-1',
    String name = 'Black Lotus',
    String setOrSeries = 'Alpha',
    String setCode = 'LEA',
    double currentMarketPrice = 5500.0,
    bool isFoil = false,
  }) {
    return VaultItem(
      id: id,
      collectionType: 'mtg',
      name: name,
      setOrSeries: setOrSeries,
      imageUrl: '',
      acquiredPrice: 5000.0,
      acquiredDate: DateTime.now(),
      quantity: 1,
      condition: isFoil ? 'NM (Foil)' : 'NM',
      isGraded: false, isAltered: false, isMisprint: false, isSigned: false,
      personalNotes: null,
      currentMarketPrice: currentMarketPrice,
      lastPriceUpdate: DateTime.now(),
      dynamicData: '{"set_code": "$setCode", "collector_number": "232"}',
      primaryBinderId: null,
    );
  }

  group('ScannerSuccessToast Widget Tests', () {
    testWidgets(
        'renders thumbnail, bold card name, set code, and emerald market price',
        (tester) async {
      final card = createMockCard(
        name: 'Black Lotus',
        setOrSeries: 'Alpha',
        setCode: 'LEA',
        currentMarketPrice: 5500.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScannerSuccessToast(
              card: card,
              autoDismiss: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Miniaturized card thumbnail placeholder (left, 36x50)
      final thumbnailFinder = find.byKey(const Key('scanner_toast_thumbnail'));
      expect(thumbnailFinder, findsOneWidget);
      final thumbnailSize = tester.getSize(thumbnailFinder);
      expect(thumbnailSize.width, equals(36.0));
      expect(thumbnailSize.height, equals(50.0));

      // 2. Bold Card Name (top right)
      final nameFinder = find.text('Black Lotus');
      expect(nameFinder, findsOneWidget);
      final nameText = tester.widget<Text>(nameFinder);
      expect(nameText.style?.fontWeight, equals(FontWeight.w800));
      expect(nameText.style?.color, equals(Colors.white));

      // 3. Set Name / Code (bottom right)
      expect(find.textContaining('Alpha'), findsOneWidget);
      expect(find.textContaining('LEA'), findsOneWidget);

      // 4. Current Market Price formatted in emerald green (far right)
      final priceFinder = find.byKey(const Key('scanner_toast_price'));
      expect(priceFinder, findsOneWidget);
      expect(find.text('\$5500.00'), findsOneWidget);

      final priceText = tester.widget<Text>(find.text('\$5500.00'));
      expect(priceText.style?.color, equals(AppColors.accentEmerald));
      expect(priceText.style?.fontWeight, equals(FontWeight.w800));
    });

    testWidgets('renders foil indicator badge when isFoil is true',
        (tester) async {
      final card = createMockCard(name: 'Sol Ring', isFoil: true);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScannerSuccessToast(
              card: card,
              isFoil: true,
              autoDismiss: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
    });

    testWidgets('triggers onTap callback when toast is tapped', (tester) async {
      final card = createMockCard();
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScannerSuccessToast(
              card: card,
              autoDismiss: false,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byType(InkWell));
      expect(tapped, isTrue);
    });

    testWidgets('slides in from top and auto-dismisses after 1.5 seconds',
        (tester) async {
      final card = createMockCard();
      bool dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScannerSuccessToast(
              card: card,
              autoDismissDuration: const Duration(milliseconds: 1500),
              autoDismiss: true,
              onDismissed: () => dismissed = true,
            ),
          ),
        ),
      );

      // Verify slide animation starts
      await tester.pump();
      expect(find.byType(ScannerSuccessToast), findsOneWidget);
      expect(dismissed, isFalse);

      // Wait 1000ms: still active
      await tester.pump(const Duration(milliseconds: 1000));
      expect(dismissed, isFalse);

      // At 1500ms, timer expires and reverse animation starts
      await tester.pump(const Duration(milliseconds: 500));
      // Allow reverse animation to complete (200ms)
      await tester.pump(const Duration(milliseconds: 250));

      // Verify onDismissed callback was triggered
      expect(dismissed, isTrue);
    });
  });

  group('ScannerModal Continuous Scanning & UI Polish Tests', () {
    testWidgets(
        'Scanner Camera Active debug textbox is completely removed from viewfinder',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestApp(child: const ScannerModal()));
      await tester.pump(const Duration(milliseconds: 300));

      // Verify "Scanner Camera Active" debug text is 100% gone
      expect(find.text('Scanner Camera Active'), findsNothing);

      // Verify centered pause overlay is NOT shown during active scanning
      expect(find.text('SCANNING PAUSED'), findsNothing);

      // Verify clean continuous scanner stream indicators
      expect(find.text('CONTINUOUS STREAM ACTIVE • AUTO-DETECTING'),
          findsOneWidget);
      expect(
          find.text('ALIGN CARD WITHIN FRAME TO AUTO-CAPTURE & STAGE'),
          findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets(
        'pause overlay only renders when scanner is explicitly paused',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestApp(child: const ScannerModal()));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('SCANNING PAUSED'), findsNothing);

      // Tap pause button
      await tester.tap(find.byKey(const Key('scanner_pause_toggle')));
      await tester.pump(const Duration(milliseconds: 300));

      // Paused overlay is now visible
      expect(find.text('SCANNING PAUSED'), findsOneWidget);
      expect(find.text('Battery Saver Active • Camera Idle'), findsOneWidget);
      expect(find.text('Resume Scanner'), findsOneWidget);

      // Resume scanning
      await tester.tap(find.text('Resume Scanner'));
      await tester.pump(const Duration(milliseconds: 300));

      // Viewfinder is clear again
      expect(find.text('SCANNING PAUSED'), findsNothing);
      expect(find.text('Scanner Camera Active'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets(
        'continuous scanning: card match triggers top toast and does not pause camera or route to inbox',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestApp(child: const ScannerModal()));
      await tester.pump(const Duration(milliseconds: 300));

      final state = tester.state(find.byType(ScannerModal)) as dynamic;
      final card = createMockCard(
        id: 'c-sol-1',
        name: 'Sol Ring',
        setOrSeries: 'Commander',
        setCode: 'CMD',
        currentMarketPrice: 2.5,
      );

      // Simulate real-time card auto-detection
      await state.simulateCardDetection(card);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // 1. Toast appears smoothly
      expect(find.byType(ScannerSuccessToast), findsOneWidget);
      expect(find.text('Sol Ring'), findsOneWidget);
      expect(find.text('\$2.50'), findsOneWidget);

      // 2. ScannerModal remains in foreground; InboxScreen is NOT auto-pushed!
      expect(find.byType(ScannerModal), findsOneWidget);
      expect(find.byType(InboxScreen), findsNothing);

      // 3. Session scan counter incremented
      expect(find.text('1'), findsOneWidget);

      // 4. Toast auto-dismisses after 1.5 seconds without closing ScannerModal
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(ScannerSuccessToast), findsNothing);
      expect(find.byType(ScannerModal), findsOneWidget);

      // 5. Tapping inbox button manually opens InboxScreen and reveals staged card
      await tester.tap(find.byIcon(Icons.inbox_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(InboxScreen), findsOneWidget);
      expect(find.text('Sol Ring'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets(
        'rapid consecutive card detections update the toast and reset the 1.5s dismiss timer',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestApp(child: const ScannerModal()));
      await tester.pump(const Duration(milliseconds: 300));

      final state = tester.state(find.byType(ScannerModal)) as dynamic;
      final card1 = createMockCard(id: 'c-1', name: 'Sol Ring');
      final card2 = createMockCard(id: 'c-2', name: 'Mana Vault');

      // Scan card 1
      await state.simulateCardDetection(card1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Sol Ring'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);

      // Scan card 2 after 500ms
      await state.simulateCardDetection(card2);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Toast now shows card 2 and session badge is 2
      expect(find.text('Mana Vault'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);

      // 1000ms later (total 1200ms for card 2, but 1700ms since card 1): card 2 is STILL visible
      await tester.pump(const Duration(milliseconds: 1000));
      expect(find.text('Mana Vault'), findsOneWidget);

      // Further 600ms later (total 1800ms for card 2): toast dismisses
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(ScannerSuccessToast), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });
  });
}
