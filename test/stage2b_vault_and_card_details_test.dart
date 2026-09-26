import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';
import 'package:countr/features/vault/presentation/widgets/edit_card_modal.dart';
import 'package:countr/features/vault/presentation/widgets/full_screen_card_viewer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late VaultDao dao;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dao = VaultDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  VaultItem createTestCard({
    String id = 'test-card-1',
    String name = 'Edgar Markov',
    String setOrSeries = 'C17',
    String imageUrl = 'https://cards.scryfall.io/normal/front/e/d/edgar.jpg',
    double purchasePrice = 45.00,
    double acquiredPrice = 40.00,
    DateTime? dateObtained,
    int quantity = 1,
    String condition = 'NM',
    String? protectionStatus = 'Double Sleeved',
    int? binderPage = 2,
    String? binderSlot = 'A3',
    String? notes = 'Commander deck core vampire piece',
    String dynamicData = '{}',
  }) {
    return VaultItem(
      id: id,
      collectionType: 'mtg',
      name: name,
      setOrSeries: setOrSeries,
      imageUrl: imageUrl,
      purchasePrice: purchasePrice,
      acquiredPrice: acquiredPrice,
      dateObtained: dateObtained ?? DateTime(2024, 12, 23),
      acquiredDate: dateObtained ?? DateTime(2024, 12, 23),
      quantity: quantity,
      condition: condition,
      protectionStatus: protectionStatus,
      binderPage: binderPage,
      binderSlot: binderSlot,
      notes: notes,
      personalNotes: notes,
      isGraded: false,
      isAltered: false,
      isMisprint: false,
      isSigned: false,
      isDeleted: false,
      currentMarketPrice: 45.0,
      lastPriceUpdate: DateTime(2024, 12, 23),
      dynamicData: dynamicData,
    );
  }

  Widget createHarness({
    required Widget child,
    List<Override> overrides = const [],
    Size size = const Size(1080, 2400),
  }) {
    return ProviderScope(
      overrides: [
        vaultDaoProvider.overrideWithValue(dao),
        ...overrides,
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: size),
          child: Scaffold(body: child),
        ),
      ),
    );
  }

  group('Stage 2B: FullScreenCardViewer Polish', () {
    testWidgets('1.1: Enforces 5:7 aspect ratio container and BoxFit.contain image fit', (tester) async {
      final card = createTestCard();

      await tester.pumpWidget(
        createHarness(
          child: FullScreenCardViewer(item: card),
        ),
      );
      await tester.pumpAndSettle();

      // Verify AspectRatio widget with 5 / 7 aspect ratio
      final aspectRatioFinder = find.byWidgetPredicate(
        (widget) => widget is AspectRatio && (widget.aspectRatio - (5.0 / 7.0)).abs() < 0.001,
      );
      expect(aspectRatioFinder, findsWidgets);

      // Verify BoxFit.contain image fit
      final imageFinder = find.byType(Image);
      expect(imageFinder, findsWidgets);
      final imageWidget = tester.widget<Image>(imageFinder.first);
      expect(imageWidget.fit, equals(BoxFit.contain));
    });

    testWidgets('1.2: Automatically activates foil shimmer for foil/etched finish and treatment', (tester) async {
      final foilCard = createTestCard(
        dynamicData: jsonEncode({
          'finish': 'foil',
          'treatment': 'halo foil',
        }),
      );

      await tester.pumpWidget(
        createHarness(
          child: FullScreenCardViewer(item: foilCard),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Auto-activated foil renders ShaderMask for shimmer sweep
      final shaderMaskFinder = find.byType(ShaderMask);
      expect(shaderMaskFinder, findsWidgets);

      // Foil toggle chip should be selected
      final foilToggleFinder = find.byKey(const Key('fullscreen_foil_toggle'));
      expect(foilToggleFinder, findsOneWidget);
      final actionChip = tester.widget<ActionChip>(foilToggleFinder);
      expect(actionChip.avatar, isNotNull);
    });

    testWidgets('1.3: Non-foil card does not auto-activate foil shimmer', (tester) async {
      final normalCard = createTestCard(
        dynamicData: jsonEncode({
          'finish': 'nonfoil',
          'finishes': ['nonfoil'],
        }),
      );

      await tester.pumpWidget(
        createHarness(
          child: FullScreenCardViewer(item: normalCard),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // ShaderMask is not rendered for non-foil
      expect(find.byType(ShaderMask), findsNothing);
    });

    testWidgets('1.4: DFC Flip binds directly to card_faces[1] backside image from printing data', (tester) async {
      final dfcCard = createTestCard(
        name: 'Nicol Bolas, the Ravager // Nicol Bolas, the Arisen',
        imageUrl: 'https://cards.scryfall.io/front/m19/218.jpg',
        dynamicData: jsonEncode({
          'card_faces': [
            {
              'name': 'Nicol Bolas, the Ravager',
              'image_uris': {'normal': 'https://cards.scryfall.io/front/m19/218.jpg'},
            },
            {
              'name': 'Nicol Bolas, the Arisen',
              'image_uris': {'normal': 'https://cards.scryfall.io/back/m19/218_back.jpg'},
            },
          ],
        }),
      );

      await tester.pumpWidget(
        createHarness(
          child: FullScreenCardViewer(item: dfcCard),
        ),
      );
      await tester.pumpAndSettle();

      // Flip button should exist for DFC
      final flipButton = find.byKey(const Key('fullscreen_flip_button'));
      expect(flipButton, findsOneWidget);

      // Tap flip button
      await tester.tap(flipButton);
      await tester.pumpAndSettle();

      // Verify second face image is rendered
      final imageWidgets = tester.widgetList<Image>(find.byType(Image));
      final hasBackImage = imageWidgets.any((img) {
        if (img.image is NetworkImage) {
          return (img.image as NetworkImage).url.contains('218_back.jpg');
        }
        return false;
      });
      expect(hasBackImage, isTrue);
    });
  });

  group('Stage 2B: CardDetailSheet Contextual Actions & Polish', () {
    testWidgets('2.1: Quick action bar does not contain fullscreen button; Art Stack has expand overlay', (tester) async {
      final card = createTestCard();

      await tester.pumpWidget(
        createHarness(
          child: CardDetailSheet(item: card),
        ),
      );
      await tester.pumpAndSettle();

      // quick_action_fullscreen removed from action bar
      expect(find.byKey(const Key('quick_action_fullscreen')), findsNothing);

      // card_art_expand_overlay present on card art Stack
      expect(find.byKey(const Key('card_art_expand_overlay')), findsOneWidget);
    });

    testWidgets('2.2: Contextual Action Bar in Binder context displays Move action', (tester) async {
      final card = createTestCard();

      await tester.pumpWidget(
        createHarness(
          child: CardDetailSheet(
            item: card,
            binderId: 'binder-alpha-1',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Move action present in Binder context
      expect(find.byKey(const Key('quick_action_move_binder')), findsOneWidget);
      expect(find.text('Move'), findsOneWidget);

      // Standard delete still available in binder
      expect(find.byKey(const Key('quick_action_delete')), findsOneWidget);
    });

    testWidgets('2.3: Contextual Action Bar in Deck context hides Delete/Move and shows Remove from Deck', (tester) async {
      final card = createTestCard();

      await tester.pumpWidget(
        createHarness(
          child: CardDetailSheet(
            item: card,
            deckId: 'deck-edgar-vampires',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // In Deck context: Delete and Move are hidden
      expect(find.byKey(const Key('quick_action_delete')), findsNothing);
      expect(find.byKey(const Key('quick_action_move_binder')), findsNothing);

      // Remove from Deck is shown
      expect(find.byKey(const Key('quick_action_remove_from_deck')), findsOneWidget);
      expect(find.text('Remove from Deck'), findsOneWidget);
    });

    testWidgets('2.4: Details tab shows [ Edit Card ] button and clean read-only summary sections', (tester) async {
      tester.view.physicalSize = const Size(1080, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final card = createTestCard(
        protectionStatus: 'Magnetic One-Touch',
        binderPage: 4,
        binderSlot: 'C1',
        notes: 'Signed by artist Mark Tedin',
        dateObtained: DateTime(2024, 10, 15),
        purchasePrice: 55.0,
      );

      await tester.pumpWidget(
        createHarness(
          child: CardDetailSheet(item: card, fetchOnlinePrintings: false),
        ),
      );
      await tester.pumpAndSettle();

      // Edit Card action button
      expect(find.byKey(const Key('card_detail_edit_card_button')), findsOneWidget);
      expect(find.text('Edit Card'), findsOneWidget);

      // Physical Provenance summary
      expect(find.byKey(const Key('section_physical_provenance')), findsOneWidget);
      expect(find.text('Magnetic One-Touch'), findsOneWidget);
      expect(find.text('Page 4, Slot C1'), findsOneWidget);
      expect(find.text('Signed by artist Mark Tedin'), findsOneWidget);

      // Acquisition Tracking summary
      expect(find.byKey(const Key('section_acquisition_tracking')), findsOneWidget);
      expect(find.textContaining('Date Obtained:'), findsOneWidget);
      expect(find.text('Acquired Price'), findsOneWidget);

      // Redundant button removed
      expect(find.byKey(const Key('button_add_edit_in_decks')), findsNothing);
    });

    testWidgets('2.5: Chronological Deck Assignment Ledger renders formatted history', (tester) async {
      tester.view.physicalSize = const Size(1080, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final card = createTestCard(
        dynamicData: jsonEncode({
          'assignment_history': [
            '+ Edgar Markov Aristocrats - 12/23/2024',
            '<-> Blood Artist - 12/24/2025',
          ],
        }),
      );

      await tester.pumpWidget(
        createHarness(
          child: CardDetailSheet(item: card, fetchOnlinePrintings: false),
        ),
      );
      await tester.pumpAndSettle();

      // Ledger container
      expect(find.byKey(const Key('card_history_ledger')), findsOneWidget);

      // Formatted ledger entries
      expect(find.text('+ Edgar Markov Aristocrats - 12/23/2024'), findsOneWidget);
      expect(find.text('<-> Blood Artist - 12/24/2025'), findsOneWidget);
    });
  });

  group('Stage 2B: EditCardModal Provenance & Acquisition Form', () {
    testWidgets('3.1: EditCardModal renders all provenance and acquisition inputs and updates DB', (tester) async {
      tester.view.physicalSize = const Size(1080, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final card = createTestCard(
        id: 'card-edit-test-1',
        protectionStatus: 'Sleeved',
        binderPage: 1,
        binderSlot: 'A1',
        notes: 'Old note',
        purchasePrice: 10.0,
      );

      // Seed the card in database
      await db.into(db.vaultItems).insert(card);

      await tester.pumpWidget(
        createHarness(
          child: EditCardModal(item: card),
        ),
      );
      await tester.pumpAndSettle();

      // Check form fields exist
      expect(find.byKey(const Key('edit_card_protection_status_dropdown')), findsOneWidget);
      expect(find.byKey(const Key('edit_card_binder_page_input')), findsOneWidget);
      expect(find.byKey(const Key('edit_card_binder_slot_input')), findsOneWidget);
      expect(find.byKey(const Key('edit_card_notes_input')), findsOneWidget);
      expect(find.byKey(const Key('edit_card_date_obtained_button')), findsOneWidget);
      expect(find.byKey(const Key('edit_card_purchase_price_input')), findsOneWidget);
      expect(find.byKey(const Key('edit_card_save_button')), findsOneWidget);

      // Change notes input
      await tester.enterText(find.byKey(const Key('edit_card_notes_input')), 'Updated combo piece note');
      // Change binder page
      await tester.enterText(find.byKey(const Key('edit_card_binder_page_input')), '5');
      // Change binder slot
      await tester.enterText(find.byKey(const Key('edit_card_binder_slot_input')), 'D3');
      // Change purchase price
      await tester.enterText(find.byKey(const Key('edit_card_purchase_price_input')), '24.99');

      // Tap Save
      await tester.tap(find.byKey(const Key('edit_card_save_button')));
      await tester.pumpAndSettle();

      // Verify persistence in DB
      final updatedFromDb = await dao.getItemById('card-edit-test-1');
      expect(updatedFromDb, isNotNull);
      expect(updatedFromDb!.notes, equals('Updated combo piece note'));
      expect(updatedFromDb.binderPage, equals(5));
      expect(updatedFromDb.binderSlot, equals('D3'));
      expect(updatedFromDb.purchasePrice, equals(24.99));
    });
  });
}
