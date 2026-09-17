import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/scanner/presentation/screens/inbox_screen.dart';
import 'package:countr/features/scanner/presentation/screens/scanner_modal.dart';
import 'package:countr/features/scanner/presentation/widgets/scanner_success_toast.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/screens/binder_detail_screen.dart';
import 'package:countr/features/vault/presentation/screens/vault_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.vaultDao.clearAllItems();
  });

  tearDown(() async {
    await db.close();
  });

  Widget createTestWidget(Widget child) {
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

  group('InboxScreen Tests', () {
    testWidgets('shows empty state when inbox has no items', (tester) async {
      await tester.pumpWidget(createTestWidget(const InboxScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Inbox is Empty'), findsOneWidget);
      expect(find.text('Back to Scanner'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('enforces cross-game restriction on bulk move', (tester) async {
      // Seed 1 MTG card and 1 Pokemon card into Inbox
      final mtgCard = VaultItem(
        id: 'mtg-1',
        collectionType: 'mtg',
        name: 'Mox Diamond',
        setOrSeries: 'Stronghold',
        imageUrl: '',
        acquiredPrice: 600.0,
        acquiredDate: DateTime.now(),
        quantity: 1,
        condition: 'NM',
        isGraded: false,
        personalNotes: null,
        currentMarketPrice: 650.0,
        lastPriceUpdate: DateTime.now(),
        dynamicData: '{}',
        primaryBinderId: null,
      );

      final pkmCard = VaultItem(
        id: 'pkm-1',
        collectionType: 'pokemon',
        name: 'Charizard Base Set',
        setOrSeries: 'Base Set',
        imageUrl: '',
        acquiredPrice: 300.0,
        acquiredDate: DateTime.now(),
        quantity: 1,
        condition: 'LP',
        isGraded: false,
        personalNotes: null,
        currentMarketPrice: 350.0,
        lastPriceUpdate: DateTime.now(),
        dynamicData: '{}',
        primaryBinderId: null,
      );

      await db.vaultDao.upsertScannedCardToInbox(mtgCard);
      await db.vaultDao.upsertScannedCardToInbox(pkmCard);

      await tester.pumpWidget(createTestWidget(const InboxScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Mox Diamond'), findsOneWidget);
      expect(find.text('Charizard Base Set'), findsOneWidget);

      // Enter select mode
      await tester.tap(find.text('Select'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Tap Select All
      await tester.tap(find.text('Select All'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('2 Selected'), findsOneWidget);
      expect(find.text('Move to Binder (2)'), findsOneWidget);

      // Attempt to move mixed cross-game selection
      await tester.tap(find.text('Move to Binder (2)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify restriction SnackBar is displayed
      expect(
        find.text('Cross-game mixing is not allowed. Please select only one game\'s cards for transfer.'),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('allows single-game transfer to binder and anchors physical home', (tester) async {
      final mtgCard1 = VaultItem(
        id: 'mtg-10',
        collectionType: 'mtg',
        name: 'Force of Will',
        setOrSeries: 'Alliances',
        imageUrl: '',
        acquiredPrice: 90.0,
        acquiredDate: DateTime.now(),
        quantity: 1,
        condition: 'NM',
        isGraded: false,
        personalNotes: null,
        currentMarketPrice: 95.0,
        lastPriceUpdate: DateTime.now(),
        dynamicData: '{}',
        primaryBinderId: null,
      );

      final mtgCard2 = VaultItem(
        id: 'mtg-11',
        collectionType: 'mtg',
        name: 'Mana Crypt',
        setOrSeries: 'Book Promo',
        imageUrl: '',
        acquiredPrice: 180.0,
        acquiredDate: DateTime.now(),
        quantity: 1,
        condition: 'NM',
        isGraded: false,
        personalNotes: null,
        currentMarketPrice: 200.0,
        lastPriceUpdate: DateTime.now(),
        dynamicData: '{}',
        primaryBinderId: null,
      );

      await db.vaultDao.upsertScannedCardToInbox(mtgCard1);
      await db.vaultDao.upsertScannedCardToInbox(mtgCard2);

      // Create destination binder
      final binder = await db.vaultDao.createBinder(
        name: 'Blue Vintage',
        collectionType: 'mtg',
      );

      await tester.pumpWidget(createTestWidget(const InboxScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Enter selection mode and select all
      await tester.tap(find.text('Select'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.text('Select All'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Tap Move to Binder (2)
      await tester.tap(find.text('Move to Binder (2)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Bottom sheet appears showing destination binder
      expect(find.text('Move to Binder (2)'), findsNWidgets(2));
      expect(find.text('Blue Vintage'), findsOneWidget);

      // Tap the binder to complete transfer
      await tester.tap(find.text('Blue Vintage'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify cards in database are now anchored to binder
      final anchoredCards = await (db.select(db.vaultItems)
            ..where((tbl) => tbl.primaryBinderId.equals(binder.id)))
          .get();
      expect(anchoredCards.length, equals(2));
      expect(anchoredCards.every((c) => c.primaryBinderId == binder.id), isTrue);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });
  });

  group('VaultScreen Binders Grid Tests', () {
    testWidgets('toggles between Singles and Binders view', (tester) async {
      await tester.pumpWidget(createTestWidget(const VaultScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Singles'), findsOneWidget);
      expect(find.text('Binders'), findsOneWidget);
      expect(find.text('New Binder'), findsOneWidget);

      // Verify Scanner Inbox button is NOT displayed on VaultScreen (decluttered)
      expect(find.byTooltip('Scanner Inbox'), findsNothing);
      expect(find.byIcon(Icons.inbox_rounded), findsNothing);

      // Default view is Binders
      expect(find.text('No Binders in Magic: The Gathering'), findsOneWidget);

      // Switch to Singles view
      await tester.tap(find.text('Singles'));
      await tester.pumpAndSettle();

      // In Singles view, 'Owned' filter chip is displayed and 'New Binder' FAB is hidden
      expect(find.text('Owned'), findsOneWidget);
      expect(find.text('New Binder'), findsNothing);

      // Switch back to Binders view
      await tester.tap(find.text('Binders'));
      await tester.pumpAndSettle();
      expect(find.text('New Binder'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('creates new binder via New Binder dialog and opens detail view', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestWidget(const VaultScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap New Binder button
      await tester.tap(find.text('New Binder'));
      await tester.pumpAndSettle();

      expect(find.text('New Binder for Magic: The Gathering'), findsOneWidget);

      // Enter binder name
      await tester.enterText(find.byType(TextField).last, 'Modern Decks Binder');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Tap Create Binder
      await tester.tap(find.text('Create Binder'));
      await tester.pumpAndSettle();

      // Verify binder in Binders view
      expect(find.text('Modern Decks Binder'), findsOneWidget);
      expect(find.text('0 Cards'), findsOneWidget);

      // Tap the binder to open BinderDetailScreen
      await tester.tap(find.text('Modern Decks Binder'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(BinderDetailScreen), findsOneWidget);
      expect(find.text('MTG Physical Anchor'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });
  });

  group('ScannerModal Tests', () {
    testWidgets('renders camera scanner controls and session badge', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestWidget(const ScannerModal()));
      await tester.pump(const Duration(milliseconds: 300));

      // Verification of scanning reticle and UI elements
      expect(find.byType(ScannerModal), findsOneWidget);
      expect(find.text('Scanner Camera Active'), findsNothing);
      expect(find.text('Foil/Variant'), findsOneWidget);
      expect(find.byIcon(Icons.inbox_rounded), findsOneWidget);
      expect(find.text('CONTINUOUS STREAM ACTIVE • AUTO-DETECTING'), findsOneWidget);
      expect(find.text('ALIGN CARD WITHIN FRAME TO AUTO-CAPTURE & STAGE'), findsOneWidget);

      // Toggle Foil/Variant chip
      await tester.tap(find.text('Foil/Variant'));
      await tester.pump(const Duration(milliseconds: 200));

      // Simulate real-time card auto-detection from continuous stream
      final state = tester.state(find.byType(ScannerModal)) as dynamic;
      final mockCard = VaultItem(
        id: 'auto-scan-1',
        collectionType: 'mtg',
        name: 'Sol Ring',
        setOrSeries: 'Commander',
        imageUrl: '',
        acquiredPrice: 1.5,
        acquiredDate: DateTime.now(),
        quantity: 1,
        condition: 'NM',
        isGraded: false,
        personalNotes: null,
        currentMarketPrice: 2.0,
        lastPriceUpdate: DateTime.now(),
        dynamicData: '{}',
        primaryBinderId: null,
      );

      // Trigger detection
      await state.simulateCardDetection(mockCard);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verifies top toast prompt appears while continuous scanner remains active
      expect(find.byType(ScannerSuccessToast), findsOneWidget);
      expect(find.text('Sol Ring'), findsOneWidget);
      expect(find.byType(ScannerModal), findsOneWidget);
      expect(find.text('1'), findsOneWidget);

      // Toast auto-dismisses after 1.5s
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ScannerSuccessToast), findsNothing);

      // Tapping inbox button opens InboxScreen
      await tester.tap(find.byIcon(Icons.inbox_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(InboxScreen), findsOneWidget);
      expect(find.text('Sol Ring'), findsOneWidget);

      // Return to Scanner via back button in AppBar
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Restores ScannerModal and displays session counter badge '1'
      expect(find.byType(ScannerModal), findsOneWidget);
      expect(find.text('1'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('pauses and resumes scanning via battery-saver toggle and reticle button', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestWidget(const ScannerModal()));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Scanner Camera Active'), findsNothing);
      expect(find.text('SIMULATOR ACTIVE'), findsOneWidget);

      // Tap battery-saver pause button
      await tester.tap(find.byKey(const Key('scanner_pause_toggle')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify paused UI state
      expect(find.text('SCANNING PAUSED'), findsOneWidget);
      expect(find.text('PAUSED (BATTERY SAVER)'), findsOneWidget);
      expect(find.text('Battery Saver Active • Camera Idle'), findsOneWidget);
      expect(find.text('Resume Scanner'), findsOneWidget);

      // Tap Resume Scanner button in reticle
      await tester.tap(find.text('Resume Scanner'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify resumed UI state
      expect(find.text('Scanner Camera Active'), findsNothing);
      expect(find.text('SIMULATOR ACTIVE'), findsOneWidget);

      // Tap pause toggle again
      await tester.tap(find.byKey(const Key('scanner_pause_toggle')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('SCANNING PAUSED'), findsOneWidget);

      // Tap pause toggle again to unpause
      await tester.tap(find.byKey(const Key('scanner_pause_toggle')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Scanner Camera Active'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('tapping inbox button opens InboxScreen and popping returns cleanly to scanner', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestWidget(const ScannerModal()));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(ScannerModal), findsOneWidget);
      expect(find.text('Scanner Camera Active'), findsNothing);

      // Tap the Inbox button on the scanner screen
      await tester.tap(find.byIcon(Icons.inbox_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // InboxScreen is now open
      expect(find.byType(InboxScreen), findsOneWidget);
      expect(find.text('Back to Scanner'), findsOneWidget);

      // Tap Back to Scanner to return
      await tester.tap(find.text('Back to Scanner'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify ScannerModal is restored and active
      expect(find.byType(ScannerModal), findsOneWidget);
      expect(find.text('Scanner Camera Active'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('renders cleanly without clipping or overflows across compact phone screens', (tester) async {
      final screenSizes = [
        const Size(360, 800), // Narrow Android
        const Size(375, 667), // iPhone SE
        const Size(390, 844), // Standard iPhone
      ];

      for (final size in screenSizes) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(createTestWidget(const ScannerModal()));
        await tester.pump(const Duration(milliseconds: 300));

        // Verify key controls exist and are visible
        expect(find.text('Scanner Camera Active'), findsNothing);
        expect(find.text('Foil/Variant'), findsOneWidget);
        expect(find.byIcon(Icons.inbox_rounded), findsOneWidget);
        expect(find.text('CONTINUOUS STREAM ACTIVE • AUTO-DETECTING'), findsOneWidget);

        // Tap battery-saver pause button
        await tester.tap(find.byKey(const Key('scanner_pause_toggle')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('PAUSED (BATTERY SAVER)'), findsOneWidget);
        expect(find.text('SCANNER PAUSED (BATTERY SAVER)'), findsOneWidget);

        // Resume scanner
        await tester.tap(find.byKey(const Key('scanner_pause_toggle')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 4));
      }

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });
}
