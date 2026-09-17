import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';
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
    String id = 'card-lotr-one-ring',
    String name = 'The One Ring',
    String setOrSeries = 'Tales of Middle-earth',
    double acquiredPrice = 40.0,
    double currentMarketPrice = 95.0,
    int quantity = 1,
    String condition = 'NM',
    bool isGraded = false,
    bool isAltered = false,
    bool isMisprint = false,
    bool isSigned = false,
    String dynamicData = '{"deck_history":[]}',
  }) {
    return VaultItem(
      id: id,
      collectionType: 'mtg',
      name: name,
      setOrSeries: setOrSeries,
      imageUrl: 'https://example.com/card.jpg',
      acquiredPrice: acquiredPrice,
      acquiredDate: DateTime(2023, 6, 23),
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

  Widget createTestWidget({
    required VaultItem card,
    List<Override> extraOverrides = const [],
  }) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        vaultDaoProvider.overrideWithValue(db.vaultDao),
        ...extraOverrides,
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                key: const Key('open_sheet_button'),
                onPressed: () => CardDetailSheet.show(context, card),
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('Card Detail Quick Action Bar & Actions (R4)', () {
    testWidgets('Pinned Quick Action Bar renders all 5 actions without overflow even on narrow screen', (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final card = createTestCard();
      await seedCard(card);

      await tester.pumpWidget(createTestWidget(card: card));
      await tester.pumpAndSettle();

      // Open CardDetailSheet
      await tester.tap(find.byKey(const Key('open_sheet_button')));
      await tester.pumpAndSettle();

      // Verify Quick Action Bar exists
      expect(find.byKey(const Key('card_detail_quick_action_bar')), findsOneWidget);

      // Verify all 5 action buttons render
      expect(find.byKey(const Key('quick_action_delete')), findsOneWidget);
      expect(find.byKey(const Key('quick_action_fullscreen')), findsOneWidget);
      expect(find.byKey(const Key('quick_action_add_to_deck')), findsOneWidget);
      expect(find.byKey(const Key('quick_action_share')), findsOneWidget);
      expect(find.byKey(const Key('quick_action_edit')), findsOneWidget);

      // Verify Hero tag on thumbnail
      expect(
        find.byWidgetPredicate(
          (w) => w is Hero && w.tag == 'card_artwork_${card.id}',
        ),
        findsOneWidget,
      );
    });

    testWidgets('Delete confirmation dialog: cancel keeps card, confirm deletes from SQLite and pops sheet', (tester) async {
      final card = createTestCard();
      await seedCard(card);

      await tester.pumpWidget(createTestWidget(card: card));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_sheet_button')));
      await tester.pumpAndSettle();

      // Tap Delete action
      await tester.tap(find.byKey(const Key('quick_action_delete')));
      await tester.pumpAndSettle();

      // Dialog opens
      expect(find.byKey(const Key('card_detail_delete_dialog')), findsOneWidget);
      expect(find.text('Delete Card?'), findsOneWidget);

      // Cancel deletion
      await tester.tap(find.byKey(const Key('delete_cancel_button')));
      await tester.pumpAndSettle();

      // Confirm card still in SQLite
      var inDb = await db.vaultDao.getItemById(card.id);
      expect(inDb, isNotNull);
      expect(find.byKey(const Key('card_detail_quick_action_bar')), findsOneWidget);

      // Tap Delete again and confirm
      await tester.tap(find.byKey(const Key('quick_action_delete')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('delete_confirm_button')));
      await tester.pumpAndSettle();

      // Verify deleted from SQLite
      inDb = await db.vaultDao.getItemById(card.id);
      expect(inDb, isNull);

      // Verify bottom sheet dismissed
      expect(find.byKey(const Key('card_detail_quick_action_bar')), findsNothing);
    });

    testWidgets('Full Screen opens FullScreenCardViewer with InteractiveViewer, Hero, and foil toggle', (tester) async {
      final card = createTestCard();
      await seedCard(card);

      await tester.pumpWidget(createTestWidget(card: card));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_sheet_button')));
      await tester.pumpAndSettle();

      // Tap Full Screen action
      await tester.tap(find.byKey(const Key('quick_action_fullscreen')));
      await tester.pumpAndSettle();

      // Verify FullScreenCardViewer is mounted
      expect(find.byType(FullScreenCardViewer), findsOneWidget);
      expect(find.byKey(const Key('fullscreen_interactive_viewer')), findsOneWidget);
      expect(find.byKey(const Key('fullscreen_foil_toggle')), findsOneWidget);

      // Toggle foil on
      await tester.tap(find.byKey(const Key('fullscreen_foil_toggle')));
      await tester.pump(const Duration(milliseconds: 100));

      // Verify ShaderMask is rendered for foil finish
      expect(find.byType(ShaderMask), findsOneWidget);

      // Toggle foil off before settling
      await tester.tap(find.byKey(const Key('fullscreen_foil_toggle')));
      await tester.pump(const Duration(milliseconds: 100));

      // Close fullscreen
      await tester.tap(find.byKey(const Key('fullscreen_close_button')));
      await tester.pumpAndSettle();

      expect(find.byType(FullScreenCardViewer), findsNothing);
    });

    testWidgets('Add to Deck appends selected deck to history and persists to SQLite', (tester) async {
      final card = createTestCard();
      await seedCard(card);

      await tester.pumpWidget(createTestWidget(card: card));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_sheet_button')));
      await tester.pumpAndSettle();

      // Tap Add to Deck
      await tester.tap(find.byKey(const Key('quick_action_add_to_deck')));
      await tester.pumpAndSettle();

      expect(find.text('Add Card to Deck'), findsOneWidget);
      expect(find.text('Edgar Markov Aristocrats'), findsOneWidget);

      // Tap on deck
      await tester.tap(find.text('Edgar Markov Aristocrats'));
      await tester.pumpAndSettle();

      // Verify persisted in SQLite
      final inDb = await db.vaultDao.getItemById(card.id);
      expect(inDb, isNotNull);
      final dynamicData = jsonDecode(inDb!.dynamicData) as Map<String, dynamic>;
      expect(dynamicData['deck_history'], contains('Edgar Markov Aristocrats'));
    });

    testWidgets('Share shows login prompt when unauthenticated, and share dialog when authenticated', (tester) async {
      final card = createTestCard();
      await seedCard(card);

      await tester.pumpWidget(createTestWidget(card: card));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_sheet_button')));
      await tester.pumpAndSettle();

      // Unauthenticated: tap Share
      await tester.tap(find.byKey(const Key('quick_action_share')));
      await tester.pumpAndSettle();

      // Login prompt dialog is shown
      expect(find.byKey(const Key('share_login_dialog')), findsOneWidget);
      expect(find.text('Sign in to Share'), findsOneWidget);

      // Tap Sign In
      await tester.tap(find.byKey(const Key('share_login_button')));
      await tester.pumpAndSettle();

      // Now authenticated: tap Share again
      await tester.tap(find.byKey(const Key('quick_action_share')));
      await tester.pumpAndSettle();

      // Share dialog is shown
      expect(find.byKey(const Key('card_share_dialog')), findsOneWidget);

      // Close share dialog
      await tester.tap(find.byKey(const Key('share_dialog_close')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('card_share_dialog')), findsNothing);
    });
  });
}
