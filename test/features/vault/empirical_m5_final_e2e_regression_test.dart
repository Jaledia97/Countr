import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/vault/presentation/providers/mtg_filter_state.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/screens/vault_screen.dart';
import 'package:countr/features/vault/presentation/widgets/card_detail_sheet.dart';
import 'package:countr/features/vault/presentation/widgets/vault_collection_view_sliver.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.vaultDao.clearAllItems();

    // 1. Insert an owned card (quantity = 1)
    await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'card-owned-1',
            collectionType: 'mtg',
            name: 'The One Ring (Owned)',
            setOrSeries: 'Tales of Middle-earth',
            imageUrl: 'https://cards.scryfall.io/large/front/ring.jpg',
            acquiredPrice: 50.0,
            acquiredDate: DateTime(2023, 6, 23),
            quantity: const drift.Value(1),
            condition: 'NM',
            isGraded: const drift.Value(false),
            currentMarketPrice: 65.0,
            lastPriceUpdate: DateTime.now(),
            dynamicData: jsonEncode({
              'set_code': 'ltr',
              'set': 'ltr',
              'collector_number': '1',
              'rarity': 'mythic',
              'colors': ['C'],
              'type_line': 'Legendary Artifact',
              'mana_cost': '{4}',
            }),
          ),
        );

    // 2. Insert an unowned catalog card (quantity = 0) in the same set
    await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'card-unowned-1',
            collectionType: 'mtg',
            name: 'Nazgûl (Catalog Unowned)',
            setOrSeries: 'Tales of Middle-earth',
            imageUrl: 'https://cards.scryfall.io/large/front/nazgul.jpg',
            acquiredPrice: 0.0,
            acquiredDate: DateTime(2023, 6, 23),
            quantity: const drift.Value(0), // UNOWNED
            condition: 'NM',
            isGraded: const drift.Value(false),
            currentMarketPrice: 12.0,
            lastPriceUpdate: DateTime.now(),
            dynamicData: jsonEncode({
              'set_code': 'ltr',
              'set': 'ltr',
              'collector_number': '2',
              'rarity': 'uncommon',
              'colors': ['B'],
              'type_line': 'Creature — Wraith Knight',
              'mana_cost': '{2}{B}',
            }),
          ),
        );

    // 3. Insert an unowned card in a second set for collection view testing
    await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'card-unowned-mh2',
            collectionType: 'mtg',
            name: 'Ragavan, Nimble Pilferer',
            setOrSeries: 'Modern Horizons 2',
            imageUrl: 'https://cards.scryfall.io/large/front/ragavan.jpg',
            acquiredPrice: 0.0,
            acquiredDate: DateTime(2023, 6, 23),
            quantity: const drift.Value(0), // UNOWNED
            condition: 'NM',
            isGraded: const drift.Value(false),
            currentMarketPrice: 45.0,
            lastPriceUpdate: DateTime.now(),
            dynamicData: jsonEncode({
              'set_code': 'mh2',
              'set': 'mh2',
              'collector_number': '138',
              'rarity': 'mythic',
              'colors': ['R'],
              'type_line': 'Legendary Creature — Monkey Pirate',
              'mana_cost': '{R}',
            }),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildVaultHarness({
    required ProviderContainer container,
    Size viewport = const Size(1080, 2400),
  }) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: viewport),
          child: const VaultScreen(),
        ),
      ),
    );
  }

  group('Milestone 5 Final E2E Cross-Feature Empirical Challenge', () {
    testWidgets('1. Cross-Feature: Singles View -> Tap Unowned Card -> Restructured CardDetailSheet -> Add to Vault updates DB & UI Count', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'mtg'),
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
          vaultShowCatalogProvider.overrideWith((ref) => true), // show unowned catalog cards
          cardDisplayLayoutProvider.overrideWith((ref) => CardDisplayLayout.grid),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(buildVaultHarness(container: container));
      await tester.pumpAndSettle();

      // Step 1.1: Verify initial Vault count shows 1 tracked item
      expect(find.text('Total Tracked Items: 1'), findsOneWidget);

      // Step 1.2: Verify unowned card is visible with UNOWNED badge
      expect(find.text('Nazgûl (Catalog Unowned)'), findsWidgets);
      expect(find.text('UNOWNED'), findsWidgets);

      // Step 1.3: Tap the unowned card to open restructured CardDetailSheet
      await tester.tap(find.text('Nazgûl (Catalog Unowned)').first);
      await tester.pumpAndSettle();

      // Step 1.4: Verify CardDetailSheet opened and restructured hierarchy is present
      expect(find.byType(CardDetailSheet), findsOneWidget);
      expect(find.text('Nazgûl (Catalog Unowned)'), findsWidgets);
      expect(find.byKey(const Key('card_detail_segmented_control')), findsOneWidget);

      final addToVaultFinder = find.byKey(const Key('card_detail_add_to_vault'));
      expect(addToVaultFinder, findsOneWidget);
      expect(find.text('Add to Vault'), findsOneWidget);

      // Step 1.5: Tap 'Add to Vault'
      await tester.tap(addToVaultFinder);
      await tester.pump();
      await tester.pumpAndSettle();

      // Verify sheet closed
      expect(find.byType(CardDetailSheet), findsNothing);

      // Step 1.6: Verify SQLite DB was updated (quantity = 1, primaryBinderId = 'INBOX')
      final updatedCard = await (db.select(db.vaultItems)
            ..where((t) => t.id.equals('card-unowned-1')))
          .getSingle();
      expect(updatedCard.quantity, equals(1));
      expect(updatedCard.primaryBinderId, equals('INBOX'));

      // Step 1.7: Verify card is in Inbox holdings
      final inboxCards = await (db.select(db.vaultItems)
            ..where((t) => t.primaryBinderId.equals('INBOX') & t.quantity.isBiggerThanValue(0)))
          .get();
      expect(inboxCards.any((c) => c.id == 'card-unowned-1'), isTrue);

      // Verify that assigning or committing from Inbox updates Vault macro count to 2
      await (db.update(db.vaultItems)..where((t) => t.id.equals('card-unowned-1'))).write(
        const VaultItemsCompanion(primaryBinderId: drift.Value(null)),
      );
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('Total Tracked Items: 2'), findsOneWidget);

      // Step 1.8: Verify SnackBar feedback appeared
      expect(find.text('Added "Nazgûl (Catalog Unowned)" to Inbox'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('2. Cross-Feature: Collections View -> Tap Unowned Card -> Add to Vault updates DB, Set Progress & Grayscale Removal', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'mtg'),
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.collections),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(buildVaultHarness(container: container));
      await tester.pumpAndSettle();

      // Step 2.1: Verify Modern Horizons 2 collection set tile is present with 0/1 owned (0%)
      expect(find.text('Modern Horizons 2'), findsOneWidget);
      expect(find.text('0% • 0/1 owned'), findsOneWidget);

      // Step 2.2: Expand Modern Horizons 2 collection
      await tester.tap(find.byKey(const Key('vault_collection_tile_MH2')));
      await tester.pumpAndSettle();

      // Step 2.3: Verify card rendered with grayscale filter
      final grayscaleFinder = find.byKey(const Key('vault_collection_grayscale_card-unowned-mh2'));
      expect(grayscaleFinder, findsOneWidget);
      final colorFiltered = tester.widget<ColorFiltered>(grayscaleFinder);
      expect(colorFiltered.colorFilter, equals(vaultGrayscaleColorFilter));

      // Step 2.4: Tap the unowned card in Collections view
      await tester.tap(find.byKey(const Key('vault_collection_item_card-unowned-mh2')));
      await tester.pumpAndSettle();

      // Verify CardDetailSheet opened
      expect(find.byType(CardDetailSheet), findsOneWidget);
      expect(find.text('Ragavan, Nimble Pilferer'), findsWidgets);

      final addToVaultBtn = find.byKey(const Key('card_detail_add_to_vault'));
      expect(addToVaultBtn, findsOneWidget);

      // Step 2.5: Tap 'Add to Vault'
      await tester.tap(addToVaultBtn);
      await tester.pump();
      await tester.pumpAndSettle();

      // Verify sheet popped
      expect(find.byType(CardDetailSheet), findsNothing);

      // Step 2.6: Empirically verify DB update
      final ragavan = await (db.select(db.vaultItems)
            ..where((t) => t.id.equals('card-unowned-mh2')))
          .getSingle();
      expect(ragavan.quantity, equals(1));

      // Step 2.7: Empirically verify Collections UI updated: 100% owned & grayscale filter REMOVED!
      expect(find.text('100% • 1/1 owned'), findsOneWidget);
      expect(find.byKey(const Key('vault_collection_grayscale_card-unowned-mh2')), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('3. Filter Isolation & Search Bar 2-Step Clear: Active MTG filters -> 2-step clear -> toggle to Collections with 0 cross-pollution', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'mtg'),
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
          vaultShowCatalogProvider.overrideWith((ref) => true),
          cardDisplayLayoutProvider.overrideWith((ref) => CardDisplayLayout.grid),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(buildVaultHarness(container: container));
      await tester.pumpAndSettle();

      // Step 3.1: Apply an active MTG filter (e.g. only Red cards)
      container.read(mtgFilterProvider.notifier).toggleColor('R');
      await tester.pump();
      await tester.pumpAndSettle();

      // In Singles view: ONLY the red card (Ragavan) should match!
      expect(find.text('Ragavan, Nimble Pilferer'), findsWidgets);
      expect(find.text('The One Ring (Owned)'), findsNothing);

      // Step 3.2: Expand search bar and enter "Ragavan"
      final searchExpandBtn = find.byKey(const Key('vault_search_expand_button'));
      await tester.tap(searchExpandBtn);
      await tester.pumpAndSettle();

      final searchTextField = find.byKey(const Key('vault_search_text_field'));
      expect(searchTextField, findsOneWidget);
      await tester.enterText(searchTextField, 'Ragavan');
      await tester.pumpAndSettle();

      expect(container.read(vaultSearchQueryProvider), equals('Ragavan'));

      // Step 3.3: 2-Step Clear:
      // Tap 1: Clear button clears text
      final clearBtn = find.byKey(const Key('vault_search_clear_button'));
      expect(clearBtn, findsOneWidget);
      await tester.tap(clearBtn);
      await tester.pumpAndSettle();

      expect(container.read(vaultSearchQueryProvider), equals(''));
      expect(find.byKey(const Key('vault_search_text_field')), findsOneWidget); // still expanded

      // Tap 2: Collapse button closes search bar
      final collapseBtn = find.byKey(const Key('vault_search_collapse_button'));
      expect(collapseBtn, findsOneWidget);
      await tester.tap(collapseBtn);
      await tester.pumpAndSettle();

      // Search bar is now collapsed back to expand button
      final crossFade = tester.widget<AnimatedCrossFade>(find.byType(AnimatedCrossFade));
      expect(crossFade.crossFadeState, equals(CrossFadeState.showFirst));
      expect(find.byKey(const Key('vault_search_expand_button')), findsOneWidget);

      // Step 3.4: Toggle 3-way view to Collections
      final collectionsToggle = find.byKey(const Key('vault_view_collections_toggle'));
      expect(collectionsToggle, findsOneWidget);
      await tester.tap(collectionsToggle);
      await tester.pumpAndSettle();

      // Step 3.5: Verify Collections View is NOT cross-polluted by the Singles MTG filter
      // Both "Tales of Middle-earth" and "Modern Horizons 2" must be displayed!
      expect(container.read(vaultViewModeProvider), equals(VaultViewMode.collections));
      expect(find.text('Tales of Middle-earth'), findsOneWidget);
      expect(find.text('Modern Horizons 2'), findsOneWidget);

      // Step 3.6: Toggle back to Singles View
      final singlesToggle = find.byKey(const Key('vault_view_singles_toggle'));
      await tester.tap(singlesToggle);
      await tester.pumpAndSettle();

      // Step 3.7: Verify MTG filter was preserved without leakage or reset
      expect(container.read(vaultViewModeProvider), equals(VaultViewMode.allVault));
      expect(container.read(mtgFilterProvider).colors, equals({'R'}));
      expect(find.text('Ragavan, Nimble Pilferer'), findsWidgets);
      expect(find.text('The One Ring (Owned)'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });
  });
}
