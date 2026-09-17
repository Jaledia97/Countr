import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';
import 'package:countr/features/vault/presentation/widgets/edit_card_modal.dart';

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
    String id = 'card-black-lotus',
    String name = 'Black Lotus',
    String setOrSeries = 'Alpha',
    double acquiredPrice = 1000.0,
    double currentMarketPrice = 50000.0,
    int quantity = 1,
    String condition = 'NM',
    bool isGraded = false,
    bool isAltered = false,
    bool isMisprint = false,
    bool isSigned = false,
    String dynamicData = '{"tags":["Vintage"],"deck_history":["Vintage"]}',
  }) {
    return VaultItem(
      id: id,
      collectionType: 'mtg',
      name: name,
      setOrSeries: setOrSeries,
      imageUrl: 'https://example.com/lotus.jpg',
      acquiredPrice: acquiredPrice,
      acquiredDate: DateTime(2023, 1, 1),
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

  Widget createTestWidget({required Widget child}) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        vaultDaoProvider.overrideWithValue(db.vaultDao),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: child,
        ),
      ),
    );
  }

  group('Card Detail Edit Modal (R5)', () {
    testWidgets('Condition checkboxes toggle and persist directly to schema v4 columns in SQLite', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final card = createTestCard(
        isGraded: false,
        isAltered: false,
        isMisprint: false,
        isSigned: false,
      );
      await seedCard(card);

      await tester.pumpWidget(
        createTestWidget(
          child: Builder(
            builder: (context) => ElevatedButton(
              key: const Key('open_edit_button'),
              onPressed: () => EditCardModal.show(context, card),
              child: const Text('Edit Card'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_edit_button')));
      await tester.pumpAndSettle();

      // Verify checkboxes are present
      expect(find.byKey(const Key('condition_checkbox_graded')), findsOneWidget);
      expect(find.byKey(const Key('condition_checkbox_altered')), findsOneWidget);
      expect(find.byKey(const Key('condition_checkbox_misprint')), findsOneWidget);
      expect(find.byKey(const Key('condition_checkbox_signed')), findsOneWidget);

      // Toggle all four checkboxes
      await tester.tap(find.byKey(const Key('condition_checkbox_graded')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('condition_checkbox_altered')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('condition_checkbox_misprint')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('condition_checkbox_signed')));
      await tester.pumpAndSettle();

      // Save changes
      await tester.tap(find.byKey(const Key('save_card_edits_button')));
      await tester.pumpAndSettle();

      // Verify in SQLite database
      final updated = await db.vaultDao.getItemById(card.id);
      expect(updated, isNotNull);
      expect(updated!.isGraded, isTrue);
      expect(updated.isAltered, isTrue);
      expect(updated.isMisprint, isTrue);
      expect(updated.isSigned, isTrue);
    });

    testWidgets('Acquired price override text field updates price in SQLite', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final card = createTestCard(acquiredPrice: 25.0);
      await seedCard(card);

      await tester.pumpWidget(
        createTestWidget(
          child: Builder(
            builder: (context) => ElevatedButton(
              key: const Key('open_edit_button'),
              onPressed: () => EditCardModal.show(context, card),
              child: const Text('Edit Card'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_edit_button')));
      await tester.pumpAndSettle();

      // Enter new acquired price
      final priceField = find.byKey(const Key('edit_card_acquired_price_field'));
      expect(priceField, findsOneWidget);

      await tester.enterText(priceField, '88.50');
      await tester.pumpAndSettle();

      // Save
      await tester.tap(find.byKey(const Key('save_card_edits_button')));
      await tester.pumpAndSettle();

      // Verify in SQLite
      final updated = await db.vaultDao.getItemById(card.id);
      expect(updated, isNotNull);
      expect(updated!.acquiredPrice, 88.50);
    });

    testWidgets('Custom tag editor adds new tags and removes existing tags', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final card = createTestCard(dynamicData: '{"tags":["Vintage"],"deck_history":["Vintage"]}');
      await seedCard(card);

      await tester.pumpWidget(
        createTestWidget(
          child: Builder(
            builder: (context) => ElevatedButton(
              key: const Key('open_edit_button'),
              onPressed: () => EditCardModal.show(context, card),
              child: const Text('Edit Card'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('open_edit_button')));
      await tester.pumpAndSettle();

      // Verify existing tag chip
      expect(find.byKey(const Key('tag_chip_Vintage')), findsOneWidget);

      // Add a new tag
      await tester.enterText(find.byKey(const Key('edit_card_tag_input')), 'Commander Staple');
      await tester.tap(find.byKey(const Key('edit_card_add_tag_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('tag_chip_Commander Staple')), findsOneWidget);

      // Delete the old "Vintage" tag
      final deleteVintageIcon = find.descendant(
        of: find.byKey(const Key('tag_chip_Vintage')),
        matching: find.byIcon(Icons.close),
      );
      await tester.tap(deleteVintageIcon);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('tag_chip_Vintage')), findsNothing);

      // Save
      await tester.tap(find.byKey(const Key('save_card_edits_button')));
      await tester.pumpAndSettle();

      // Verify in SQLite
      final updated = await db.vaultDao.getItemById(card.id);
      expect(updated, isNotNull);
      final data = jsonDecode(updated!.dynamicData) as Map<String, dynamic>;
      final tags = List<String>.from(data['tags']);
      expect(tags, contains('Commander Staple'));
      expect(tags, isNot(contains('Vintage')));
    });

    testWidgets('Editing card updates CardDetailSheet and triggers watchVaultTotals recalculation', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final card = createTestCard(
        acquiredPrice: 10.0,
        currentMarketPrice: 20.0,
        quantity: 2,
      );
      await seedCard(card);

      // Listen to watchVaultTotals
      final totalsHistory = <double>[];
      final subscription = db.vaultDao
          .watchVaultTotals(collectionType: 'mtg')
          .listen((totals) {
        totalsHistory.add(totals.totalCostBasis);
      });
      addTearDown(() => subscription.cancel());

      await tester.pumpWidget(
        createTestWidget(
          child: Builder(
            builder: (context) => ElevatedButton(
              key: const Key('open_sheet_button'),
              onPressed: () => CardDetailSheet.show(context, card),
              child: const Text('Open Sheet'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open CardDetailSheet
      await tester.tap(find.byKey(const Key('open_sheet_button')));
      await tester.pumpAndSettle();

      // Tap Edit in Quick Action Bar
      await tester.tap(find.byKey(const Key('quick_action_edit')));
      await tester.pumpAndSettle();

      // Change price from 10.0 to 30.0 (total cost basis becomes 2 * 30 = 60.0)
      await tester.enterText(find.byKey(const Key('edit_card_acquired_price_field')), '30.00');
      await tester.pumpAndSettle();

      // Save changes
      await tester.tap(find.byKey(const Key('save_card_edits_button')));
      await tester.pumpAndSettle();

      // Verify SQLite is updated
      final updated = await db.vaultDao.getItemById(card.id);
      expect(updated, isNotNull);
      expect(updated!.acquiredPrice, 30.00);

      // Verify watchVaultTotals recalculated
      await tester.pump(const Duration(milliseconds: 100));
      expect(totalsHistory, contains(60.0));

      // Verify CardDetailSheet reflects new price in portfolio metrics
      expect(find.textContaining('30.00'), findsWidgets);
    });

    testWidgets('EditCardModal renders without RenderFlex overflow on narrow 320px and 360px viewports', (tester) async {
      for (final size in [const Size(320, 568), const Size(360, 640)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final card = createTestCard(id: 'narrow-test-card-${size.width.toInt()}');
        await seedCard(card);

        await tester.pumpWidget(
          createTestWidget(
            child: Builder(
              builder: (context) => ElevatedButton(
                key: Key('open_edit_${size.width.toInt()}'),
                onPressed: () => EditCardModal.show(context, card),
                child: const Text('Edit Card'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(Key('open_edit_${size.width.toInt()}')));
        await tester.pumpAndSettle();

        // Verify zero RenderFlex overflows occurred
        expect(tester.takeException(), isNull);

        // Verify dropdowns exist and are expanded
        final variantFinder = find.byKey(const Key('edit_card_variant_selector'));
        final conditionFinder = find.byKey(const Key('condition_grade_dropdown'));
        expect(variantFinder, findsOneWidget);
        expect(conditionFinder, findsOneWidget);

        final DropdownButton<String> variantDropdown = tester.widget(
          find.descendant(
            of: variantFinder,
            matching: find.byType(DropdownButton<String>),
          ),
        );
        final DropdownButton<String> conditionDropdown = tester.widget(
          find.descendant(
            of: conditionFinder,
            matching: find.byType(DropdownButton<String>),
          ),
        );
        expect(variantDropdown.isExpanded, isTrue);
        expect(conditionDropdown.isExpanded, isTrue);

        await tester.tap(find.byKey(const Key('save_card_edits_button')));
        await tester.pumpAndSettle();
      }
    });
  });
}

