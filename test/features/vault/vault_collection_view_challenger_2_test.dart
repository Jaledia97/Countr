import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
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
  });

  tearDown(() async {
    await db.close();
  });

  Widget createTestWidget({required ProviderContainer container}) {
    return UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: VaultScreen(),
      ),
    );
  }

  group('CHALLENGER 2: Set Code and Collector Number Sorting', () {
    test('Empirical sorting across set codes, alphanumeric suffixes, and missing numbers', () async {
      final setName = 'The Lord of the Rings';

      // Insert cards with various collector numbers and set codes
      final testCards = [
        {
          'id': 'c-100',
          'name': 'Gondor Soldier',
          'set_code': 'ltr',
          'collector_number': '100',
        },
        {
          'id': 'c-10',
          'name': 'Rohan Rider',
          'set_code': 'ltr',
          'collector_number': '10',
        },
        {
          'id': 'c-2b',
          'name': 'Aragorn Alt Art',
          'set_code': 'ltr',
          'collector_number': '2b',
        },
        {
          'id': 'c-2a',
          'name': 'Aragorn Standard',
          'set_code': 'ltr',
          'collector_number': '2a',
        },
        {
          'id': 'c-2',
          'name': 'Aragorn Base',
          'set_code': 'ltr',
          'collector_number': '2',
        },
        {
          'id': 'c-1',
          'name': 'Frodo',
          'set_code': 'ltr',
          'collector_number': '1',
        },
        {
          'id': 'c-ltc-1',
          'name': 'Gandalf Commander',
          'set_code': 'ltc', // LTC comes before LTR alphabetically
          'collector_number': '1',
        },
        {
          'id': 'c-no-num',
          'name': 'Token Card',
          'set_code': 'ltr',
          'collector_number': null, // Missing collector number
        },
      ];

      for (final card in testCards) {
        final dynamicMap = <String, dynamic>{
          'set': card['set_code'],
          'set_code': card['set_code'],
          'rarity': 'common',
        };
        if (card['collector_number'] != null) {
          dynamicMap['collector_number'] = card['collector_number'];
        }

        await db.vaultDao.into(db.vaultItems).insert(
              VaultItemsCompanion.insert(
                id: card['id'] as String,
                collectionType: 'mtg',
                name: card['name'] as String,
                setOrSeries: setName,
                imageUrl: 'https://cards.scryfall.io/large/${card['id']}.jpg',
                acquiredPrice: 1.0,
                acquiredDate: DateTime(2023, 6, 23),
                quantity: const drift.Value(1),
                condition: 'NM',
                isGraded: const drift.Value(false),
                currentMarketPrice: 2.0,
                lastPriceUpdate: DateTime.now(),
                dynamicData: jsonEncode(dynamicMap),
              ),
            );
      }

      final items = await db.vaultDao.watchItemsBySet(setName, collectionType: 'mtg').first;
      expect(items.length, equals(8));

      // 1. LTC card 1 comes first because set_code 'ltc' < 'ltr'
      expect(items[0].id, equals('c-ltc-1'));

      // 2. Among LTR cards:
      // 'c-no-num' has null collector number -> CAST('0' AS INTEGER) = 0
      expect(items[1].id, equals('c-no-num'));

      // 'c-1' has collector_number '1' -> CAST = 1
      expect(items[2].id, equals('c-1'));

      // 'c-2', 'c-2a', 'c-2b' all CAST to 2, then tiebreak by raw collector_number ('2' < '2a' < '2b')
      expect(items[3].id, equals('c-2'));
      expect(items[4].id, equals('c-2a'));
      expect(items[5].id, equals('c-2b'));

      // 'c-10' has CAST = 10 (comes before 100 numerically)
      expect(items[6].id, equals('c-10'));

      // 'c-100' has CAST = 100
      expect(items[7].id, equals('c-100'));
    });

    testWidgets('Collection expansion in UI displays cards in sorted order', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const setName = 'Sorting Test Set';
      // Insert card 10 and card 2
      await db.vaultDao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'sort-10',
              collectionType: 'mtg',
              name: 'Ten Card',
              setOrSeries: setName,
              imageUrl: '',
              acquiredPrice: 1.0,
              acquiredDate: DateTime.now(),
              quantity: const drift.Value(1),
              condition: 'NM',
              isGraded: const drift.Value(false),
              currentMarketPrice: 1.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: jsonEncode({
                'set_code': 'sts',
                'collector_number': '10',
              }),
            ),
          );

      await db.vaultDao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'sort-2',
              collectionType: 'mtg',
              name: 'Two Card',
              setOrSeries: setName,
              imageUrl: '',
              acquiredPrice: 1.0,
              acquiredDate: DateTime.now(),
              quantity: const drift.Value(1),
              condition: 'NM',
              isGraded: const drift.Value(false),
              currentMarketPrice: 1.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: jsonEncode({
                'set_code': 'sts',
                'collector_number': '2',
              }),
            ),
          );

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'mtg'),
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.collections),
        ],
      );

      await tester.pumpWidget(createTestWidget(container: container));
      await tester.pumpAndSettle();

      // Expand the collection
      await tester.tap(find.byKey(const Key('vault_collection_tile_STS')));
      await tester.pumpAndSettle();

      // Verify both items rendered
      expect(find.byKey(const Key('vault_collection_item_sort-2')), findsOneWidget);
      expect(find.byKey(const Key('vault_collection_item_sort-10')), findsOneWidget);

      // Verify sort-2 appears above/before sort-10 in layout
      final sort2Pos = tester.getTopLeft(find.byKey(const Key('vault_collection_item_sort-2')));
      final sort10Pos = tester.getTopLeft(find.byKey(const Key('vault_collection_item_sort-10')));

      // In a 3-column grid, item 0 is to the left of item 1 on same row
      expect(sort2Pos.dx, lessThan(sort10Pos.dx));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });
  });

  group('CHALLENGER 2: Visual Grayscale & Rec. 709 ColorFilter Precision', () {
    test('Verify Rec. 709 matrix coefficients in vaultGrayscaleColorFilter', () {
      // Expected Rec. 709 luminance values:
      // Red: 0.2126, Green: 0.7152, Blue: 0.0722
      const expectedFilter = ColorFilter.matrix(<double>[
        0.2126, 0.7152, 0.0722, 0, 0,
        0.2126, 0.7152, 0.0722, 0, 0,
        0.2126, 0.7152, 0.0722, 0, 0,
        0,      0,      0,      1, 0,
      ]);

      expect(vaultGrayscaleColorFilter, equals(expectedFilter));
    });

    testWidgets('Unowned cards render with vaultGrayscaleColorFilter; owned cards do not', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const setName = 'Color Test Set';
      // Insert unowned card (quantity = 0)
      await db.vaultDao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'card-unowned',
              collectionType: 'mtg',
              name: 'Unowned Black & White',
              setOrSeries: setName,
              imageUrl: 'https://cards.scryfall.io/large/unowned.jpg',
              acquiredPrice: 0.0,
              acquiredDate: DateTime.now(),
              quantity: const drift.Value(0),
              condition: 'NM',
              isGraded: const drift.Value(false),
              currentMarketPrice: 10.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: jsonEncode({'set_code': 'cts', 'collector_number': '1'}),
            ),
          );

      // Insert owned card (quantity = 1)
      await db.vaultDao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'card-owned-1',
              collectionType: 'mtg',
              name: 'Owned Full Color',
              setOrSeries: setName,
              imageUrl: 'https://cards.scryfall.io/large/owned1.jpg',
              acquiredPrice: 5.0,
              acquiredDate: DateTime.now(),
              quantity: const drift.Value(1),
              condition: 'NM',
              isGraded: const drift.Value(false),
              currentMarketPrice: 12.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: jsonEncode({'set_code': 'cts', 'collector_number': '2'}),
            ),
          );

      // Insert owned card with multiples (quantity = 3)
      await db.vaultDao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'card-owned-3',
              collectionType: 'mtg',
              name: 'Owned Multiple Full Color',
              setOrSeries: setName,
              imageUrl: 'https://cards.scryfall.io/large/owned3.jpg',
              acquiredPrice: 5.0,
              acquiredDate: DateTime.now(),
              quantity: const drift.Value(3),
              condition: 'NM',
              isGraded: const drift.Value(false),
              currentMarketPrice: 15.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: jsonEncode({'set_code': 'cts', 'collector_number': '3'}),
            ),
          );

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'mtg'),
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.collections),
        ],
      );

      await tester.pumpWidget(createTestWidget(container: container));
      await tester.pumpAndSettle();

      // Expand collection
      await tester.tap(find.byKey(const Key('vault_collection_tile_CTS')));
      await tester.pumpAndSettle();

      // 1. Unowned card MUST have ColorFiltered with vaultGrayscaleColorFilter
      final unownedGrayscaleFinder = find.byKey(const Key('vault_collection_grayscale_card-unowned'));
      expect(unownedGrayscaleFinder, findsOneWidget);
      final unownedColorFiltered = tester.widget<ColorFiltered>(unownedGrayscaleFinder);
      expect(unownedColorFiltered.colorFilter, equals(vaultGrayscaleColorFilter));

      // 2. Owned cards MUST NOT have grayscale ColorFiltered
      expect(find.byKey(const Key('vault_collection_grayscale_card-owned-1')), findsNothing);
      expect(find.byKey(const Key('vault_collection_grayscale_card-owned-3')), findsNothing);

      // 3. Badges check:
      // Unowned card has "UNOWNED" badge
      expect(find.text('UNOWNED'), findsOneWidget);
      // Multi-quantity card has "3x" badge
      expect(find.text('3x'), findsOneWidget);
      // Single quantity card has no "1x" badge
      expect(find.text('1x'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });
  });

  group('CHALLENGER 2: Card Tap opens CardDetailSheet Interaction', () {
    testWidgets('Tapping unowned and owned cards correctly opens CardDetailSheet with accurate item', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const setName = 'Tap Test Set';
      await db.vaultDao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'tap-unowned',
              collectionType: 'mtg',
              name: 'Sol Ring',
              setOrSeries: setName,
              imageUrl: '',
              acquiredPrice: 0.0,
              acquiredDate: DateTime.now(),
              quantity: const drift.Value(0),
              condition: 'NM',
              isGraded: const drift.Value(false),
              currentMarketPrice: 2.5,
              lastPriceUpdate: DateTime.now(),
              dynamicData: jsonEncode({'set_code': 'tts', 'collector_number': '1'}),
            ),
          );

      await db.vaultDao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'tap-owned',
              collectionType: 'mtg',
              name: 'Black Lotus',
              setOrSeries: setName,
              imageUrl: '',
              acquiredPrice: 10000.0,
              acquiredDate: DateTime.now(),
              quantity: const drift.Value(1),
              condition: 'NM',
              isGraded: const drift.Value(false),
              currentMarketPrice: 20000.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: jsonEncode({'set_code': 'tts', 'collector_number': '2'}),
            ),
          );

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'mtg'),
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.collections),
        ],
      );

      await tester.pumpWidget(createTestWidget(container: container));
      await tester.pumpAndSettle();

      // Expand set
      await tester.tap(find.byKey(const Key('vault_collection_tile_TTS')));
      await tester.pumpAndSettle();

      // Tap unowned card
      await tester.tap(find.byKey(const Key('vault_collection_item_tap-unowned')));
      await tester.pumpAndSettle();

      // Verify CardDetailSheet opened for Sol Ring
      expect(find.byType(CardDetailSheet), findsOneWidget);
      expect(find.text('Sol Ring'), findsWidgets);

      // Dismiss CardDetailSheet
      await tester.tapAt(const Offset(20, 20)); // Tap barrier outside modal
      await tester.pumpAndSettle();
      expect(find.byType(CardDetailSheet), findsNothing);

      // Tap owned card
      await tester.tap(find.byKey(const Key('vault_collection_item_tap-owned')));
      await tester.pumpAndSettle();

      // Verify CardDetailSheet opened for Black Lotus
      expect(find.byType(CardDetailSheet), findsOneWidget);
      expect(find.text('Black Lotus'), findsWidgets);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });
  });

  group('CHALLENGER 2: Dynamic Reactivity & Edge Cases', () {
    testWidgets('Live DB update from unowned (qty 0) to owned (qty 1) removes grayscale and updates progress', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const setName = 'Reactivity Set';
      await db.vaultDao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'react-card',
              collectionType: 'mtg',
              name: 'Reactive Mox',
              setOrSeries: setName,
              imageUrl: '',
              acquiredPrice: 0.0,
              acquiredDate: DateTime.now(),
              quantity: const drift.Value(0),
              condition: 'NM',
              isGraded: const drift.Value(false),
              currentMarketPrice: 50.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: jsonEncode({'set_code': 'rs', 'collector_number': '1'}),
            ),
          );

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'mtg'),
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.collections),
        ],
      );

      await tester.pumpWidget(createTestWidget(container: container));
      await tester.pumpAndSettle();

      // Expand
      await tester.tap(find.byKey(const Key('vault_collection_tile_RS')));
      await tester.pumpAndSettle();

      // Initially unowned: 0% and grayscale filter active
      expect(find.text('0% • 0/1 owned'), findsOneWidget);
      expect(find.byKey(const Key('vault_collection_grayscale_react-card')), findsOneWidget);

      // Now simulate user adding/buying card in DB: update quantity to 1
      await (db.update(db.vaultItems)..where((t) => t.id.equals('react-card'))).write(
        const VaultItemsCompanion(quantity: drift.Value(1)),
      );

      // Pump to trigger stream emission and rebuild
      await tester.pump();
      await tester.pumpAndSettle();

      // Verify UI automatically updated: 100% owned, grayscale removed
      expect(find.text('100% • 1/1 owned'), findsOneWidget);
      expect(find.byKey(const Key('vault_collection_grayscale_react-card')), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('Malformed dynamic_data JSON does not crash collection view or member cards', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const setName = 'Empty Dynamic Data Set';
      await db.vaultDao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'empty-json-card',
              collectionType: 'mtg',
              name: 'Empty JSON Item',
              setOrSeries: setName,
              imageUrl: '',
              acquiredPrice: 0.0,
              acquiredDate: DateTime.now(),
              quantity: const drift.Value(1),
              condition: 'NM',
              isGraded: const drift.Value(false),
              currentMarketPrice: 1.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: '{}',
            ),
          );

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'mtg'),
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.collections),
        ],
      );

      await tester.pumpWidget(createTestWidget(container: container));
      await tester.pumpAndSettle();

      // Header should render with empty setCode fallback
      expect(find.text('Empty Dynamic Data Set'), findsOneWidget);

      // Expand collection
      await tester.tap(find.byKey(const Key('vault_collection_tile_Empty Dynamic Data Set')));
      await tester.pumpAndSettle();

      // Card item renders safely despite missing keys in dynamicData
      expect(find.text('Empty JSON Item'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('Search query filters collections reactive stream', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Insert Set A
      await db.vaultDao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'set-a-card',
              collectionType: 'mtg',
              name: 'Alpha Dog',
              setOrSeries: 'Alpha Set',
              imageUrl: '',
              acquiredPrice: 1.0,
              acquiredDate: DateTime.now(),
              quantity: const drift.Value(1),
              condition: 'NM',
              isGraded: const drift.Value(false),
              currentMarketPrice: 1.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: jsonEncode({'set_code': 'alp'}),
            ),
          );

      // Insert Set B
      await db.vaultDao.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'set-b-card',
              collectionType: 'mtg',
              name: 'Beta Fish',
              setOrSeries: 'Beta Set',
              imageUrl: '',
              acquiredPrice: 1.0,
              acquiredDate: DateTime.now(),
              quantity: const drift.Value(1),
              condition: 'NM',
              isGraded: const drift.Value(false),
              currentMarketPrice: 1.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: jsonEncode({'set_code': 'bet'}),
            ),
          );

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'mtg'),
          vaultViewModeProvider.overrideWith((ref) => VaultViewMode.collections),
        ],
      );

      await tester.pumpWidget(createTestWidget(container: container));
      await tester.pumpAndSettle();

      // Initially both sets are visible
      expect(find.text('Alpha Set'), findsOneWidget);
      expect(find.text('Beta Set'), findsOneWidget);

      // Filter by "Beta"
      container.read(vaultSearchQueryProvider.notifier).state = 'Beta';
      await tester.pump();
      await tester.pumpAndSettle();

      // Only Beta Set is displayed
      expect(find.text('Alpha Set'), findsNothing);
      expect(find.text('Beta Set'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });
  });
}
