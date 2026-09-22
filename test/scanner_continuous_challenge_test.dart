import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/scanner/presentation/screens/inbox_screen.dart';
import 'package:countr/features/scanner/presentation/screens/scanner_modal.dart';
import 'package:countr/features/scanner/presentation/widgets/scanner_success_toast.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';

/// Custom NavigatorObserver to catch any unexpected route transitions during continuous scanning.
class AdversarialRouteObserver extends NavigatorObserver {
  final List<Route<dynamic>> pushedRoutes = [];
  final List<Route<dynamic>> poppedRoutes = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushedRoutes.add(route);
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    poppedRoutes.add(route);
    super.didPop(route, previousRoute);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late AdversarialRouteObserver routeObserver;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.vaultDao.clearAllItems();
    routeObserver = AdversarialRouteObserver();
  });

  tearDown(() async {
    await db.close();
  });

  Widget createChallengeApp({
    required Widget child,
    List<NavigatorObserver>? observers,
  }) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        vaultDaoProvider.overrideWithValue(db.vaultDao),
      ],
      child: MaterialApp(
        navigatorObservers: observers ?? [],
        home: child,
      ),
    );
  }

  VaultItem createTestCard({
    required String id,
    required String name,
    String setOrSeries = 'Dominaria',
    String setCode = 'DOM',
    double price = 9.99,
    String? dynamicData,
    bool isFoil = false,
  }) {
    return VaultItem(
      id: id,
      collectionType: 'mtg',
      name: name,
      setOrSeries: setOrSeries,
      imageUrl: '',
      acquiredPrice: price,
      acquiredDate: DateTime.now(),
      quantity: 1,
      condition: isFoil ? 'NM (Foil)' : 'NM',
      isGraded: false, isAltered: false, isMisprint: false, isSigned: false,
      personalNotes: null,
      currentMarketPrice: price,
      lastPriceUpdate: DateTime.now(),
      dynamicData: dynamicData ?? jsonEncode({'set_code': setCode, 'collector_number': '100'}),
      primaryBinderId: null,
    );
  }

  group('Adversarial Challenge 1: Camera Preview & Stream Continuity on Card Match', () {
    testWidgets(
        'Zero modal navigation occurs on single and consecutive card matches',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        createChallengeApp(
          child: const ScannerModal(),
          observers: [routeObserver],
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      final state = tester.state(find.byType(ScannerModal)) as dynamic;
      final initialPushedCount = routeObserver.pushedRoutes.length;

      // Card 1 matches
      final card1 = createTestCard(id: 'c1', name: 'Black Lotus', price: 50000.0);
      await state.simulateCardDetection(card1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Assert NO new routes were pushed (InboxScreen was not auto-opened)
      expect(routeObserver.pushedRoutes.length, equals(initialPushedCount),
          reason: 'No routes should be pushed automatically upon card match');
      expect(find.byType(InboxScreen), findsNothing);
      expect(find.byType(ScannerModal), findsOneWidget);

      // Card 2 matches immediately after
      final card2 = createTestCard(id: 'c2', name: 'Mox Sapphire', price: 8000.0);
      await state.simulateCardDetection(card2);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Assert still NO new routes pushed
      expect(routeObserver.pushedRoutes.length, equals(initialPushedCount));
      expect(find.byType(InboxScreen), findsNothing);

      // Verify Inbox database in background received both cards
      final inboxCards = await (db.select(db.vaultItems)
            ..where((t) => t.primaryBinderId.equals('INBOX')))
          .get();
      expect(inboxCards.length, equals(2));
      expect(inboxCards.map((c) => c.name), containsAll(['Black Lotus', 'Mox Sapphire']));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets(
        'Camera stream remains completely active during rapid-fire detection burst',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createChallengeApp(child: const ScannerModal()));
      await tester.pump(const Duration(milliseconds: 300));

      final state = tester.state(find.byType(ScannerModal)) as dynamic;

      // Burst of 5 cards detected in rapid succession
      for (int i = 1; i <= 5; i++) {
        final card = createTestCard(
          id: 'burst-$i',
          name: 'Card $i',
          price: i * 5.0,
        );
        await state.simulateCardDetection(card);
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Verify session scan badge reflects all 5 detected cards
      expect(find.text('5'), findsOneWidget);

      // Verify ScannerModal is still the active frontmost widget
      expect(find.byType(ScannerModal), findsOneWidget);
      expect(find.byType(InboxScreen), findsNothing);

      // Verify all 5 cards were staged to Inbox without loss
      final inboxCards = await (db.select(db.vaultItems)
            ..where((t) => t.primaryBinderId.equals('INBOX')))
          .get();
      expect(inboxCards.length, equals(5));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });
  });

  group('Adversarial Challenge 2: Total Absence of "Scanner Camera Active" Debug Text', () {
    testWidgets('Debug text is absent across all scanner states and lifecycle phases',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createChallengeApp(child: const ScannerModal()));
      await tester.pump(const Duration(milliseconds: 300));

      // Phase 1: Idle scanning
      expect(find.text('Scanner Camera Active'), findsNothing,
          reason: 'Debug text must not exist during idle scanning');

      // Phase 2: Card bounds detected
      final state = tester.state(find.byType(ScannerModal)) as dynamic;
      state.simulateDetectedBounds(const Rect.fromLTWH(50, 100, 300, 420));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Scanner Camera Active'), findsNothing,
          reason: 'Debug text must not exist when card bounds are detected');

      // Phase 3: Green flash active upon match
      final card = createTestCard(id: 'flash-card', name: 'Lightning Bolt');
      await state.simulateCardDetection(card);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Scanner Camera Active'), findsNothing,
          reason: 'Debug text must not exist during green flash');

      // Phase 4: Active toast displayed
      expect(find.byType(ScannerSuccessToast), findsOneWidget);
      expect(find.text('Scanner Camera Active'), findsNothing,
          reason: 'Debug text must not exist while success toast is shown');

      // Wait for toast to auto-dismiss before testing paused state
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ScannerSuccessToast), findsNothing);

      // Phase 5: Paused state
      await tester.tap(find.byKey(const Key('scanner_pause_toggle')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('SCANNING PAUSED'), findsOneWidget);
      expect(find.text('Scanner Camera Active'), findsNothing,
          reason: 'Debug text must not exist while paused');

      // Phase 6: Resumed state
      await tester.tap(find.text('Resume Scanner'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('SCANNING PAUSED'), findsNothing);
      expect(find.text('Scanner Camera Active'), findsNothing,
          reason: 'Debug text must not exist after resuming');

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });
  });

  group('Adversarial Challenge 3: Manual Pause Button Robustness', () {
    testWidgets(
        'Manual pause toggle transitions states cleanly and ignores frames while paused',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createChallengeApp(child: const ScannerModal()));
      await tester.pump(const Duration(milliseconds: 300));

      final pauseButton = find.byKey(const Key('scanner_pause_toggle'));
      expect(pauseButton, findsOneWidget);

      // 1. Initial state: Not paused
      expect(find.text('SCANNING PAUSED'), findsNothing);

      // 2. Tap pause toggle: Pauses
      await tester.tap(pauseButton);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('SCANNING PAUSED'), findsOneWidget);
      expect(find.text('Battery Saver Active • Camera Idle'), findsOneWidget);
      expect(find.text('Resume Scanner'), findsOneWidget);

      // 3. Tap pause toggle again: Resumes
      await tester.tap(pauseButton);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('SCANNING PAUSED'), findsNothing);

      // 4. Tap pause toggle: Pauses again
      await tester.tap(pauseButton);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('SCANNING PAUSED'), findsOneWidget);

      // 5. Tap 'Resume Scanner' button: Resumes
      await tester.tap(find.text('Resume Scanner'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('SCANNING PAUSED'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('Rapid multiple clicks on pause toggle do not deadlock or throw',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createChallengeApp(child: const ScannerModal()));
      await tester.pump(const Duration(milliseconds: 300));

      final pauseButton = find.byKey(const Key('scanner_pause_toggle'));

      // Rapidly tap pause button 6 times
      for (int i = 0; i < 6; i++) {
        await tester.tap(pauseButton);
        await tester.pump(const Duration(milliseconds: 50));
      }

      await tester.pump(const Duration(milliseconds: 300));
      // Modal should remain mounted and operational with no unhandled exceptions
      expect(find.byType(ScannerModal), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });
  });

  group('Adversarial Challenge 4: Edge Cases and Defect Reproductions', () {
    testWidgets('Handles corrupt and non-standard dynamicData gracefully without crashing',
        (tester) async {
      final badDataCard = createTestCard(
        id: 'bad-json-card',
        name: 'Corrupt Data Card',
        dynamicData: '{this is not valid json: true',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScannerSuccessToast(
              card: badDataCard,
              autoDismiss: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // No crash
      expect(tester.takeException(), isNull);
      expect(find.text('Corrupt Data Card'), findsOneWidget);
    });

    testWidgets(
        'BUG DEMONSTRATION 1: Stack layering in ScannerModal places Floating Controls Bar over ScannerSuccessToast, intercepting taps and obscuring toast',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createChallengeApp(child: const ScannerModal()));
      await tester.pump(const Duration(milliseconds: 300));

      final state = tester.state(find.byType(ScannerModal)) as dynamic;
      final card = createTestCard(id: 'toast-tap-card', name: 'Mana Vault');

      await state.simulateCardDetection(card);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(ScannerSuccessToast), findsOneWidget);

      // Attempt to tap the toast at its center.
      // FAIL: The Floating Controls Bar (at top: 70) is rendered AFTER the toast (at top: 64) in the Stack,
      // obscuring the toast and intercepting the hit test, preventing InboxScreen from opening.
      await tester.tap(find.byType(ScannerSuccessToast), warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.byType(InboxScreen),
        findsOneWidget,
        reason: 'FAIL: ScannerSuccessToast is rendered beneath Floating Controls Bar in Stack, blocking taps from opening Inbox',
      );

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets(
        'BUG DEMONSTRATION 2: Long set codes and prices on compact screens cause RenderFlex overflow in ScannerSuccessToast',
        (tester) async {
      // Small screen viewport (iPhone SE 1st gen width: 320px)
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final extremeCard = createTestCard(
        id: 'extreme-1',
        name: 'Our Market Research Shows That Players Like Long Names',
        setOrSeries: 'Secret Lair Drop',
        setCode: 'SLD-EXTRA-LONG',
        price: 999999.99,
        isFoil: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScannerSuccessToast(
              card: extremeCard,
              autoDismiss: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // FAIL: Causes "A RenderFlex overflowed by 19 pixels on the right" in the set details Row
      // because setCode is not wrapped in Flexible or ellipsis-protected.
      expect(
        tester.takeException(),
        isNull,
        reason: 'FAIL: ScannerSuccessToast subtitle Row overflows on compact screens with long set codes',
      );
    });
  });
}
