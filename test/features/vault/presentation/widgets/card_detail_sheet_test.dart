import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';

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
    String id = 'card-test-1',
    String name = 'Black Lotus',
    String setOrSeries = 'Alpha',
    int quantity = 2,
    double price = 25000.0,
  }) {
    return VaultItem(
      id: id,
      collectionType: 'mtg',
      name: name,
      setOrSeries: setOrSeries,
      imageUrl: 'https://example.com/card.jpg',
      acquiredPrice: price,
      acquiredDate: DateTime(2023, 1, 1),
      quantity: quantity,
      condition: 'NM',
      isGraded: false,
      isAltered: false,
      isMisprint: false,
      isSigned: false, isDeleted: false,
      currentMarketPrice: price,
      lastPriceUpdate: DateTime.now(),
      dynamicData: jsonEncode({
        'deck_history': <String>[],
        'oracle_text': '{T}, Sacrifice Black Lotus: Add three mana of any one color.',
      }),
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

  Widget buildTestApp(VaultItem card) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        vaultDaoProvider.overrideWithValue(db.vaultDao),
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

  group('CardDetailSheet & AddToDeckDialog Lifecycle Safety', () {
    testWidgets(
        'selecting an existing deck dismisses smoothly without TextEditingController disposed error during exit animation',
        (tester) async {
      final card = createTestCard();
      await seedCard(card);

      // Create a deck in SQLite
      await db.vaultDao.createDeck('Vintage Deck Beta', format: 'Vintage');

      await tester.pumpWidget(buildTestApp(card));
      await tester.pumpAndSettle();

      // Open CardDetailSheet
      await tester.tap(find.byKey(const Key('open_sheet_button')));
      await tester.pumpAndSettle();

      // Tap Quick Action Bar "Add to Deck" button
      await tester.tap(find.byKey(const Key('quick_action_add_to_deck')));
      await tester.pumpAndSettle();

      // Confirm dialog opened
      expect(find.text('Add Card to Deck'), findsOneWidget);
      expect(find.text('Vintage Deck Beta'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      // Tap on the deck to add card and trigger Navigator.pop()
      await tester.tap(find.text('Vintage Deck Beta'));

      // Crucial test step: Advance frames step-by-step during the exit animation.
      // Prior to fixing, the controller was disposed as soon as showModalBottomSheet returned,
      // and Flutter rebuilt the exiting dialog frame, crashing with "used after being disposed".
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // No exception should be thrown by Flutter framework
      expect(tester.takeException(), isNull);

      // Bottom sheet dismissed
      expect(find.text('Add Card to Deck'), findsNothing);
    });

    testWidgets('creating a new deck via custom deck TextField operates safely and updates DB',
        (tester) async {
      final card = createTestCard();
      await seedCard(card);

      await tester.pumpWidget(buildTestApp(card));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_sheet_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('quick_action_add_to_deck')));
      await tester.pumpAndSettle();

      // Enter new deck name
      await tester.enterText(find.byType(TextField), 'Custom Test Deck 99');
      await tester.pumpAndSettle();

      // Tap create and add button
      await tester.tap(find.byIcon(Icons.add_circle));

      // Advance through animation
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Verify the deck was created in SQLite
      final decks = await db.select(db.decks).get();
      expect(decks.any((d) => d.name == 'Custom Test Deck 99'), isTrue);
    });

    testWidgets('dialog content with multiple decks renders inside SingleChildScrollView without vertical overflow',
        (tester) async {

      final card = createTestCard();
      await seedCard(card);

      // Create 5 decks to verify scrolling
      for (int i = 1; i <= 5; i++) {
        await db.vaultDao.createDeck('Deck #$i', format: 'Commander');
      }

      await tester.pumpWidget(buildTestApp(card));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_sheet_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('quick_action_add_to_deck')));
      await tester.pumpAndSettle();

      expect(find.text('Add Card to Deck'), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsWidgets);
      expect(tester.takeException(), isNull);

      // Close dialog
      await tester.tap(find.byIcon(Icons.close).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Add Card to Deck header renders cleanly without RenderFlex overflow on 320px viewport at 2.0x text scale',
        (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final card = createTestCard();
      await seedCard(card);

      await db.vaultDao.createDeck('Test Deck', format: 'Commander');

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 600),
            textScaler: TextScaler.linear(2.0),
          ),
          child: buildTestApp(card),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_sheet_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('quick_action_add_to_deck')));
      await tester.pumpAndSettle();

      expect(find.text('Add Card to Deck'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byIcon(Icons.close).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}

