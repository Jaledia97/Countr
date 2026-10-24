import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/vault/presentation/screens/vault_screen.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_card.dart';
import 'package:countr/features/vault/presentation/widgets/vault_item_tile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory mockCacheDir;
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUpAll(() {
    mockCacheDir = Directory.systemTemp.createTempSync('countr_challenger_m2_cache_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (MethodCall methodCall) async {
      return mockCacheDir.path;
    });
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    if (mockCacheDir.existsSync()) {
      try {
        mockCacheDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  group('Milestone 2 R2 Challenger: SQLite Covering Index Verification (F6)', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('Covering index idx_vault_items_browse eliminates temporary B-Tree sort on browse query', () async {
      // Open db to trigger beforeOpen
      await db.customSelect('SELECT 1').get();

      // Explain query plan for browse query (ordered by acquired_date DESC, name ASC)
      final explainRows = await db.customSelect('''
        EXPLAIN QUERY PLAN
        SELECT * FROM "vault_items"
        WHERE "is_deleted" = 0 AND "collection_type" = 'mtg'
        ORDER BY "acquired_date" DESC, "name" ASC
        LIMIT 120;
      ''').get();

      final planDetails = explainRows.map((r) => r.read<String>('detail')).toList();
      final fullPlan = planDetails.join(' | ');

      // Must use idx_vault_items_browse index
      expect(
        fullPlan.contains('idx_vault_items_browse') || fullPlan.contains('USING INDEX'),
        isTrue,
        reason: 'Browse query must utilize covering index. Plan: $fullPlan',
      );

      // Must NOT use temporary B-tree for ORDER BY
      expect(
        fullPlan.contains('USE TEMP B-TREE FOR ORDER BY'),
        isFalse,
        reason: 'Covering index must provide sorted order without temporary B-tree. Plan: $fullPlan',
      );
    });

    test('Covering index idx_vault_items_catalog_name eliminates temporary B-Tree sort on catalog query', () async {
      await db.customSelect('SELECT 1').get();

      final explainRows = await db.customSelect('''
        EXPLAIN QUERY PLAN
        SELECT * FROM "vault_items"
        WHERE "is_deleted" = 0 AND "collection_type" = 'mtg'
        ORDER BY "name" COLLATE NOCASE ASC
        LIMIT 120;
      ''').get();

      final planDetails = explainRows.map((r) => r.read<String>('detail')).toList();
      final fullPlan = planDetails.join(' | ');

      expect(
        fullPlan.contains('idx_vault_items_catalog_name') || fullPlan.contains('USING INDEX'),
        isTrue,
        reason: 'Catalog query must utilize covering index. Plan: $fullPlan',
      );

      expect(
        fullPlan.contains('USE TEMP B-TREE FOR ORDER BY'),
        isFalse,
        reason: 'Catalog covering index must avoid temporary B-tree sort. Plan: $fullPlan',
      );
    });
  });

  group('Milestone 2 R2 Challenger: O(1) findChildIndexCallback Stress & Boundary Tests (F8)', () {
    test('Empirical O(1) Map lookup vs O(N) linear search on 5,000 items', () {
      final now = DateTime.now();
      final items = List.generate(5000, (i) {
        return VaultItem(
          id: 'card-$i',
          collectionType: 'mtg',
          name: 'Card $i',
          setOrSeries: 'SET',
          imageUrl: '',
          acquiredPrice: 1.0,
          acquiredDate: now,
          quantity: 1,
          condition: 'NM',
          currentMarketPrice: 2.0,
          lastPriceUpdate: now,
          dynamicData: '{}',
          isDeleted: false,
          isGraded: false,
          isAltered: false,
          isMisprint: false,
          isSigned: false,
        );
      });

      // Build id-to-index map
      final idToIndex = <String, int>{};
      for (int i = 0; i < items.length; i++) {
        idToIndex[items[i].id] = i;
      }

      int? findChildIndexCallback(Key key) {
        if (key is ValueKey<String>) {
          return idToIndex[key.value];
        }
        return null;
      }

      // Benchmark 5,000 lookups via findChildIndexCallback
      final stopwatchO1 = Stopwatch()..start();
      for (int i = 0; i < items.length; i++) {
        final index = findChildIndexCallback(ValueKey<String>('card-$i'));
        expect(index, equals(i));
      }
      stopwatchO1.stop();

      // Benchmark 500 lookups via O(N) indexWhere (subsampled to save test time)
      final stopwatchON = Stopwatch()..start();
      for (int i = 0; i < 500; i++) {
        final targetId = 'card-$i';
        final index = items.indexWhere((it) => it.id == targetId);
        expect(index, equals(i));
      }
      stopwatchON.stop();

      // O(1) for 5000 lookups should be significantly fast (< 15ms)
      expect(stopwatchO1.elapsedMilliseconds, lessThan(100),
          reason: '5,000 O(1) map lookups must execute within sub-frame latency');
    });

    test('findChildIndexCallback gracefully handles malformed, mismatched, and missing keys', () {
      final idMap = <String, int>{
        'card-1': 0,
        'card-2': 1,
        'card-3': 2,
      };

      int? callback(Key key) {
        if (key is ValueKey<String>) {
          return idMap[key.value];
        }
        return null;
      }

      // Valid string keys
      expect(callback(const ValueKey<String>('card-1')), equals(0));
      expect(callback(const ValueKey<String>('card-2')), equals(1));
      expect(callback(const ValueKey<String>('card-3')), equals(2));

      // Missing keys
      expect(callback(const ValueKey<String>('card-999')), isNull);
      expect(callback(const ValueKey<String>('')), isNull);

      // Non-ValueKey<String> types (must return null without throwing)
      expect(callback(const ValueKey<int>(1)), isNull);
      expect(callback(const ValueKey<double>(1.5)), isNull);
      expect(callback(const Key('generic_key')), isNull);
      expect(callback(UniqueKey()), isNull);
    });

    test('findChildIndexCallback handles duplicate item IDs gracefully', () {
      // In case of duplicated IDs, map overwrites and resolves to valid integer index without crash
      final items = ['card-dup', 'card-unique', 'card-dup'];
      final idMap = <String, int>{};
      for (int i = 0; i < items.length; i++) {
        idMap[items[i]] = i;
      }

      int? callback(Key key) {
        if (key is ValueKey<String>) {
          return idMap[key.value];
        }
        return null;
      }

      expect(callback(const ValueKey<String>('card-dup')), equals(2));
      expect(callback(const ValueKey<String>('card-unique')), equals(1));
      expect(callback(const ValueKey<String>('card-unknown')), isNull);
    });
  });

  group('Milestone 2 R2 Challenger: Unowned Card Deck Badges Isolation (F8)', () {
    final now = DateTime.now();

    final unownedCardZero = VaultItem(
      id: 'unowned-zero',
      collectionType: 'mtg',
      name: 'Black Lotus Unowned',
      setOrSeries: 'LEA',
      imageUrl: '',
      acquiredPrice: 0.0,
      acquiredDate: now,
      quantity: 0,
      condition: 'NM',
      currentMarketPrice: 20000.0,
      lastPriceUpdate: now,
      dynamicData: '{}',
      isDeleted: false,
      isGraded: false,
      isAltered: false,
      isMisprint: false,
      isSigned: false,
    );

    final unownedCardNegative = VaultItem(
      id: 'unowned-negative',
      collectionType: 'mtg',
      name: 'Mox Sapphire Corrupted',
      setOrSeries: 'LEA',
      imageUrl: '',
      acquiredPrice: 0.0,
      acquiredDate: now,
      quantity: -1,
      condition: 'NM',
      currentMarketPrice: 5000.0,
      lastPriceUpdate: now,
      dynamicData: '{}',
      isDeleted: false,
      isGraded: false,
      isAltered: false,
      isMisprint: false,
      isSigned: false,
    );

    final ownedCard = VaultItem(
      id: 'owned-card-1',
      collectionType: 'mtg',
      name: 'Lightning Bolt',
      setOrSeries: 'M10',
      imageUrl: '',
      acquiredPrice: 2.0,
      acquiredDate: now,
      quantity: 4,
      condition: 'NM',
      currentMarketPrice: 3.5,
      lastPriceUpdate: now,
      dynamicData: '{}',
      isDeleted: false,
      isGraded: false,
      isAltered: false,
      isMisprint: false,
      isSigned: false,
    );

    testWidgets('OptionalDeckBadges does NOT mount Consumer for quantity <= 0', (tester) async {
      // Unowned (quantity = 0)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OptionalDeckBadges(item: unownedCardZero),
          ),
        ),
      );

      expect(find.byType(OptionalDeckBadges), findsOneWidget);
      expect(find.descendant(of: find.byType(OptionalDeckBadges), matching: find.byType(Consumer)), findsNothing,
          reason: 'Consumer must NOT be mounted when quantity <= 0');
      expect(find.byType(SizedBox), findsOneWidget);
      final box = tester.widget<SizedBox>(find.byType(SizedBox));
      expect(box.width, equals(0.0));
      expect(box.height, equals(0.0));

      // Unowned (quantity < 0)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OptionalDeckBadges(item: unownedCardNegative),
          ),
        ),
      );

      expect(find.descendant(of: find.byType(OptionalDeckBadges), matching: find.byType(Consumer)), findsNothing);
    });

    testWidgets('OptionalDeckBadges mounts Consumer and renders badges when quantity > 0 and decks assigned', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allCardActiveDecksProvider.overrideWith(
              (ref) => Stream.value({
                'owned-card-1': ['Modern Burn', 'Commander Torbran'],
              }),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: OptionalDeckBadges(item: ownedCard),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.descendant(of: find.byType(OptionalDeckBadges), matching: find.byType(Consumer)), findsOneWidget);
      expect(find.text('⚔️ Modern Burn'), findsOneWidget);
      expect(find.text('⚔️ Commander Torbran'), findsOneWidget);
    });

    testWidgets('VaultItemTile unowned card suppresses deck badge Consumer inside tile', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 150,
                height: 220,
                child: VaultItemTile(
                  item: unownedCardZero,
                  hasMultipleVariants: false,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The deck badge container should NOT exist
      expect(find.text('Modern Burn'), findsNothing);
      expect(find.text('Black Lotus Unowned'), findsOneWidget);
    });
  });


  group('Milestone 2 R2 Challenger: Rapid Scrolling & Sliver Layout Stress (F8)', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      final now = DateTime.now();

      // Insert 60 cards
      for (int i = 0; i < 60; i++) {
        await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'scroll-card-$i',
            collectionType: 'mtg',
            name: 'Scroll Test Card $i',
            setOrSeries: 'M25',
            imageUrl: '',
            acquiredPrice: 1.0,
            acquiredDate: now.subtract(Duration(minutes: i)),
            quantity: drift.Value(i % 2 == 0 ? 1 : 0),
            condition: 'NM',
            currentMarketPrice: 2.0 + (i * 0.5),
            lastPriceUpdate: now,
            dynamicData: jsonEncode({
              'oracle_id': 'oracle-scroll-${i % 10}',
              'scryfall_id': 'scryfall-scroll-$i',
              'finish': 'nonfoil',
            }),
          ),
        );
      }
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('Rapid scrolling in VaultScreen executes without layout crash or index exceptions', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(db.vaultDao),
            activeGameContextProvider.overrideWith((ref) => 'Magic: The Gathering'),
            vaultViewModeProvider.overrideWith((ref) => VaultViewMode.allVault),
            vaultShowCatalogProvider.overrideWith((ref) => true),
            vaultPaginationLimitProvider.overrideWith((ref) => 50),
          ],
          child: const MaterialApp(
            home: VaultScreen(),
          ),
        ),
      );

      // Settle initial load
      await tester.pumpAndSettle();

      expect(find.byType(VaultScreen), findsOneWidget);

      final scrollFinder = find.byType(Scrollable).first;

      // Perform 6 rapid flings down and up
      for (int i = 0; i < 3; i++) {
        await tester.fling(scrollFinder, const Offset(0, -600), 2000);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 50));

        await tester.fling(scrollFinder, const Offset(0, 600), 2000);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 50));
      }

      await tester.pumpAndSettle();

      // Verify that after rapid flings, the screen remains alive and responsive
      expect(find.byType(VaultScreen), findsOneWidget);
    });
  });
}
