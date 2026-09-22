import 'dart:convert';
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
  TestWidgetsFlutterBinding.ensureInitialized();

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
    String id = 'mtg-black-lotus',
    String name = 'Black Lotus',
    String setOrSeries = 'Vintage Masters',
    String setCode = 'VMA',
    double currentMarketPrice = 5500.0,
    bool isFoil = false,
    String imageUrl =
        'https://cards.scryfall.io/large/front/b/d/bd8fa327-dd41-4737-8f19-2cf5eb1f7cdd.jpg',
    String? dynamicData,
  }) {
    return VaultItem(
      id: id,
      collectionType: 'mtg',
      name: name,
      setOrSeries: setOrSeries,
      imageUrl: imageUrl,
      acquiredPrice: 5000.0,
      acquiredDate: DateTime.now(),
      quantity: 1,
      condition: isFoil ? 'NM (Foil)' : 'NM',
      isGraded: false, isAltered: false, isMisprint: false, isSigned: false,
      personalNotes: null,
      currentMarketPrice: currentMarketPrice,
      lastPriceUpdate: DateTime.now(),
      dynamicData: dynamicData ??
          jsonEncode({
            'set_code': setCode,
            'collector_number': '232',
            'mana_cost': '{0}',
            'type_line': 'Artifact',
          }),
      primaryBinderId: 'INBOX',
    );
  }

  group('Empirical Challenge: Rapid Card Detections & Timer Resets', () {
    testWidgets(
        '5 rapid consecutive card scans in ScannerModal update toast content immediately and reset 1.5s timer',
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

      final cards = [
        createMockCard(id: 'c-1', name: 'Black Lotus', currentMarketPrice: 5500.0),
        createMockCard(id: 'c-2', name: 'Mox Sapphire', currentMarketPrice: 3000.0),
        createMockCard(id: 'c-3', name: 'Mox Jet', currentMarketPrice: 2800.0),
        createMockCard(id: 'c-4', name: 'Mox Ruby', currentMarketPrice: 2700.0),
        createMockCard(id: 'c-5', name: 'Mox Emerald', currentMarketPrice: 2600.0),
      ];

      // Send 5 rapid card detections at 250ms intervals
      for (int i = 0; i < cards.length; i++) {
        await state.simulateCardDetection(cards[i]);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        // Content must immediately reflect the latest detected card
        expect(find.text(cards[i].name), findsOneWidget);
        expect(find.text('\$${cards[i].currentMarketPrice.toStringAsFixed(2)}'),
            findsOneWidget);
        // Session counter must match detection count
        expect(find.text('${i + 1}'), findsOneWidget);
      }

      // Total time elapsed since card 1 is 1250ms.
      // Now wait 1200ms: Card 5 has only been active for 1200ms (< 1500ms),
      // even though 2450ms have elapsed since card 1. Card 5 must still be visible.
      await tester.pump(const Duration(milliseconds: 1200));
      expect(find.text('Mox Emerald'), findsOneWidget);
      expect(find.text('\$2600.00'), findsOneWidget);

      // Advance past the 1500ms auto-dismiss duration for card 5 (timer fires at 1500ms, reverse takes 200ms)
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ScannerSuccessToast), findsNothing);

      // Verify all 5 cards were staged to SQLite Inbox
      final inboxItems = await (db.select(db.vaultItems)
            ..where((t) => t.primaryBinderId.equals('INBOX')))
          .get();
      expect(inboxItems.length, equals(5));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets(
        'back-to-back scan of identical card refreshes toast and resets dismiss timer',
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
      final card = createMockCard(id: 'c-repeat', name: 'Lightning Bolt');

      // First detection
      await state.simulateCardDetection(card);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1000));
      expect(find.text('Lightning Bolt'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);

      // Second detection of the exact same card at t=1000ms
      await state.simulateCardDetection(card);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Lightning Bolt'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);

      // 1000ms later (t=2000ms total from start, but 1000ms from 2nd detection)
      // If timer did not reset, it would have dismissed at 1500ms. Must still be visible!
      await tester.pump(const Duration(milliseconds: 1000));
      expect(find.text('Lightning Bolt'), findsOneWidget);

      // Wait remaining time for 2nd detection (600ms for timer + 300ms for reverse and rebuild)
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ScannerSuccessToast), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets(
        'didUpdateWidget resets internal animation and timer when card changes with same key',
        (tester) async {
      final cardA = createMockCard(id: 'c-a', name: 'Black Lotus');
      final cardB = createMockCard(id: 'c-b', name: 'Mox Sapphire');
      bool dismissed = false;

      // Stateful wrapper that changes the card on rebuild without changing the toast Key
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: Column(
                  children: [
                    ScannerSuccessToast(
                      card: cardA,
                      autoDismissDuration: const Duration(milliseconds: 1500),
                      autoDismiss: true,
                      onDismissed: () => dismissed = true,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1000));
      expect(find.text('Black Lotus'), findsOneWidget);
      expect(dismissed, isFalse);

      // Rebuild with Card B at t=1000ms
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: Column(
                  children: [
                    ScannerSuccessToast(
                      card: cardB,
                      autoDismissDuration: const Duration(milliseconds: 1500),
                      autoDismiss: true,
                      onDismissed: () => dismissed = true,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Mox Sapphire'), findsOneWidget);

      // Wait 1000ms (t=2000ms total): Card B should still be alive because timer restarted
      await tester.pump(const Duration(milliseconds: 1000));
      expect(find.text('Mox Sapphire'), findsOneWidget);
      expect(dismissed, isFalse);

      // Wait until 1500ms + reverse animation completes
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 250));
      expect(dismissed, isTrue);
    });

    testWidgets('Stress: 20 rapid successive card updates do not throw and preserve latest card',
        (tester) async {
      for (int i = 0; i < 20; i++) {
        final card = createMockCard(
          id: 'card-$i',
          name: 'Card #$i',
          currentMarketPrice: (i * 1.5),
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
        await tester.pump(const Duration(milliseconds: 16));
      }

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Card #19'), findsOneWidget);
      expect(find.text('\$28.50'), findsOneWidget);
    });
  });

  group('Empirical Challenge: Tap-to-Open & Z-Order Vulnerability', () {
    testWidgets('standalone ScannerSuccessToast onTap fires when tapped directly',
        (tester) async {
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
      await tester.pumpAndSettle();

      await tester.tap(find.byType(InkWell));
      expect(tapped, isTrue);
    });

    testWidgets(
        'RESOLVED: In ScannerModal, toast placed at end of Stack receives tap gestures cleanly and opens InboxScreen',
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
      final card = createMockCard(name: 'Demonic Tutor', currentMarketPrice: 42.0);

      await state.simulateCardDetection(card);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(ScannerSuccessToast), findsOneWidget);

      // Attempting to tap the card toast succeeds because ScannerSuccessToast is rendered
      // at the end of the Stack, painting on top of controls and receiving pointer events.
      await tester.tap(find.text('Demonic Tutor'), warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // InboxScreen is opened because toast is on top and received tap!
      expect(find.byType(InboxScreen), findsOneWidget,
          reason:
              'Toast on top of Stack routes taps cleanly to InboxScreen');

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });
  });

  group('Empirical Challenge: 1.5s Auto-Dismiss Precision & Lifecycle', () {
    testWidgets('autoDismiss: false holds indefinitely without dismissing',
        (tester) async {
      final card = createMockCard();
      bool dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScannerSuccessToast(
              card: card,
              autoDismiss: false,
              onDismissed: () => dismissed = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Advance clock by 10 seconds
      await tester.pump(const Duration(seconds: 10));
      expect(dismissed, isFalse);
      expect(find.byType(ScannerSuccessToast), findsOneWidget);
    });

    testWidgets('unmounting toast mid-lifetime cancels dismiss timer cleanly',
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
      await tester.pump(const Duration(milliseconds: 500));

      // Unmount before 1500ms
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));

      // Fast forward past 1500ms
      await tester.pump(const Duration(seconds: 3));

      // Verify no exceptions thrown and callback not triggered after unmount
      expect(dismissed, isFalse);
    });
  });

  group('Empirical Challenge: Layout Robustness & Visual Stress Testing', () {
    testWidgets(
        'handles extremely long card title without horizontal RenderFlex overflow on standard screen',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844); // Standard iPhone
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const superLongName =
          'Our Market Research Shows That Players Like Really Long Card Names So We Made This Card to Have the Absolute Longest Name Ever Conceived in Magic History';
      const superLongSet =
          'Unhinged Extended Alternate Collector Edition Double Master Prerelease Promo Series';

      final card = createMockCard(
        name: superLongName,
        setOrSeries: superLongSet,
        setCode: 'UNH-EXT',
        currentMarketPrice: 9999.99,
        isFoil: true,
      );

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

      expect(tester.takeException(), isNull);
      expect(find.text(superLongName), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
      expect(find.text('\$9999.99'), findsOneWidget);
    });

    testWidgets('market price edge cases: zero, penny, and millionaire values',
        (tester) async {
      final prices = [0.0, 0.05, 5500.0, 1250000.50];
      final expectedStrings = ['\$0.00', '\$0.05', '\$5500.00', '\$1250000.50'];

      for (int i = 0; i < prices.length; i++) {
        final card = createMockCard(
          name: 'Price Test ${prices[i]}',
          currentMarketPrice: prices[i],
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

        expect(find.text(expectedStrings[i]), findsOneWidget);
        final priceText = tester.widget<Text>(find.text(expectedStrings[i]));
        expect(priceText.style?.color, equals(AppColors.accentEmerald));
        expect(priceText.style?.fontWeight, equals(FontWeight.w800));
      }
    });

    testWidgets('dynamicData edge cases: empty, corrupted, and missing set_code',
        (tester) async {
      final edgeCases = [
        '', // completely empty string
        '{corrupted json', // syntax error
        '{}', // empty JSON object
        '{"other_key": 123}', // missing set_code
        '{"set_code": null}', // null value
        '{"set_code": "   "}', // whitespace only
      ];

      for (final dynamicData in edgeCases) {
        final card = createMockCard(
          name: 'Dynamic Data Test',
          setOrSeries: 'Alpha',
          dynamicData: dynamicData,
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

        expect(tester.takeException(), isNull);
        expect(find.text('Dynamic Data Test'), findsOneWidget);
        expect(find.text('Alpha'), findsOneWidget);
      }
    });

    testWidgets('thumbnail placeholder renders consistently with empty imageUrl',
        (tester) async {
      final card = createMockCard(imageUrl: '');

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

      final thumbnailFinder = find.byKey(const Key('scanner_toast_thumbnail'));
      expect(thumbnailFinder, findsOneWidget);
      expect(find.byIcon(Icons.style_rounded), findsOneWidget);

      final size = tester.getSize(thumbnailFinder);
      expect(size.width, equals(36.0));
      expect(size.height, equals(50.0));
    });

    testWidgets('SetCode priority: explicit setCode parameter overrides dynamicData',
        (tester) async {
      final card = createMockCard(
        setOrSeries: 'Double Masters',
        dynamicData: '{"set_code": "2XM"}',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScannerSuccessToast(
              card: card,
              setCode: 'OVERRIDE',
              autoDismiss: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('OVERRIDE'), findsOneWidget);
      expect(find.textContaining('2XM'), findsNothing);
    });
  });

  group('Empirical Challenge: RenderFlex Overflow Resolution (Verified Resolved)', () {
    testWidgets(
        'RESOLVED: 1.5x accessibility text scaling does not trigger RenderFlex overflow in subtitle Text.rich',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final card = createMockCard(
        name: 'Urza, Lord High Artificer',
        setOrSeries: 'Modern Horizons',
        setCode: 'MH1',
        isFoil: true,
      );

      FlutterErrorDetails? capturedError;
      final prevOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        capturedError = details;
      };

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(1.5),
            ),
            child: Scaffold(
              body: ScannerSuccessToast(
                card: card,
                isFoil: true,
                autoDismiss: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      FlutterError.onError = prevOnError;

      expect(capturedError, isNull,
          reason:
              'Subtitle uses Text.rich with ellipsis, avoiding RenderFlex overflow under 1.5x scaling');
    });

    testWidgets(
        'RESOLVED: 320px viewport with long set code and large price does not overflow subtitle',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final card = createMockCard(
        name: 'Omnath, Locus of All and Everything Everywhere',
        setOrSeries: 'March of the Machine: The Aftermath',
        setCode: 'MAT-EXTENDED',
        currentMarketPrice: 1250000.50,
        isFoil: true,
      );

      FlutterErrorDetails? capturedError;
      final prevOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        capturedError = details;
      };

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
      FlutterError.onError = prevOnError;

      expect(capturedError, isNull,
          reason:
              'Subtitle uses Text.rich with ellipsis, avoiding RenderFlex overflow on compact viewports');
    });
  });
}
