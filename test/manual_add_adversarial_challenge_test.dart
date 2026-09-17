import 'dart:math';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/domain/models/vault_totals.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late VaultDao dao;

  setUpAll(() {
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dao = db.vaultDao;
    await dao.seedDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  // ===========================================================================
  // GROUP 1: SEARCH ENGINE ADVERSARIAL STRESS TESTS (searchCatalogCards)
  // ===========================================================================
  group('Adversarial Search: SQL Wildcards, Injections, Unicode & Boundaries', () {
    test('SQL Wildcard Characters (% and _) execute cleanly without SQL syntax error', () async {
      // 1. Single wildcard '%'
      final percentResults = await dao.searchCatalogCards('%');
      expect(percentResults, isNotEmpty);
      expect(percentResults.length, lessThanOrEqualTo(50));

      // 2. Multiple wildcards '%%%' and '%_%'
      final multiWildcards = await dao.searchCatalogCards('%%%%%');
      expect(multiWildcards, isNotEmpty);

      final singleCharWildcards = await dao.searchCatalogCards('___');
      expect(singleCharWildcards, isNotEmpty);

      // 3. Search for card with literal wildcard in name/set
      await db.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'item-wildcard-percent',
              collectionType: 'mtg',
              name: 'Card with 100% Foil',
              setOrSeries: 'Promo_Set_2026',
              imageUrl: '',
              acquiredPrice: 5.0,
              acquiredDate: DateTime.now(),
              quantity: const drift.Value(0),
              condition: 'NM',
              currentMarketPrice: 10.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: '{}',
            ),
          );

      final literalPercentResults = await dao.searchCatalogCards('100%');
      expect(literalPercentResults.any((c) => c.id == 'item-wildcard-percent'), isTrue);

      final literalUnderscoreResults = await dao.searchCatalogCards('Promo_Set');
      expect(literalUnderscoreResults.any((c) => c.id == 'item-wildcard-percent'), isTrue);
    });

    test('Quote and Escape Character Injections do not compromise SQL or throw errors', () async {
      final initialCount = (await (db.select(db.vaultItems)).get()).length;

      // Classic SQL Injections
      final injectionQueries = [
        "'",
        "''",
        "'''",
        '"',
        '""',
        '`',
        '\\',
        r'\"',
        r"\'",
        "' OR '1'='1",
        "'; DROP TABLE vault_items; --",
        '" OR ""="',
        "' UNION SELECT * FROM vault_binders --",
        "Robert'); DROP TABLE vault_items;--",
        "' OR 1=1 /*",
      ];

      for (final query in injectionQueries) {
        // Must never throw an exception
        final results = await dao.searchCatalogCards(query);
        expect(results, isNotNull);

        // Boolean-based injection must not return all rows unless the row actually contains that string
        if (query == "' OR '1'='1" || query == '" OR ""="') {
          expect(results, isEmpty);
        }
      }

      // Verify the table still exists and row count is intact
      final countAfterInjections = (await (db.select(db.vaultItems)).get()).length;
      expect(countAfterInjections, initialCount);
    });

    test('Unicode Diacritics, Accents, and International Scripts match correctly and do not crash', () async {
      // Seed cards with various unicode diacritics and scripts
      await db.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'item-unicode-french',
              collectionType: 'mtg',
              name: 'Éowyn, Fearless Knight',
              setOrSeries: 'Tales of Middle-earth',
              imageUrl: '',
              acquiredPrice: 3.0,
              acquiredDate: DateTime.now(),
              quantity: const drift.Value(0),
              condition: 'NM',
              currentMarketPrice: 6.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: '{}',
            ),
          );

      await db.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'item-unicode-german',
              collectionType: 'mtg',
              name: 'Jäger of the Deep Woods',
              setOrSeries: 'Smörgåsbord Expansion',
              imageUrl: '',
              acquiredPrice: 1.0,
              acquiredDate: DateTime.now(),
              quantity: const drift.Value(0),
              condition: 'NM',
              currentMarketPrice: 2.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: '{}',
            ),
          );

      await db.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'item-unicode-cjk',
              collectionType: 'pokemon',
              name: 'ピカチュウ (Pikachu VMAX)',
              setOrSeries: 'VMAXクライマックス',
              imageUrl: '',
              acquiredPrice: 20.0,
              acquiredDate: DateTime.now(),
              quantity: const drift.Value(0),
              condition: 'NM',
              currentMarketPrice: 35.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: '{}',
            ),
          );

      await db.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'item-unicode-emoji',
              collectionType: 'comic',
              name: 'Cosmic Quest #1 🔥🃏',
              setOrSeries: 'Indie Comics ✨',
              imageUrl: '',
              acquiredPrice: 4.0,
              acquiredDate: DateTime.now(),
              quantity: const drift.Value(0),
              condition: 'NM',
              currentMarketPrice: 8.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: '{}',
            ),
          );

      // Search matching exact diacritics
      final eowynMatch = await dao.searchCatalogCards('Éowyn');
      expect(eowynMatch.length, 1);
      expect(eowynMatch.first.id, 'item-unicode-french');

      // Search German umlauts
      final jagerMatch = await dao.searchCatalogCards('Jäger');
      expect(jagerMatch.length, 1);
      expect(jagerMatch.first.id, 'item-unicode-german');

      final smorgasbordMatch = await dao.searchCatalogCards('Smörgåsbord');
      expect(smorgasbordMatch.length, 1);
      expect(smorgasbordMatch.first.id, 'item-unicode-german');

      // Search Japanese Katakana
      final pikachuMatch = await dao.searchCatalogCards('ピカチュウ');
      expect(pikachuMatch.length, 1);
      expect(pikachuMatch.first.id, 'item-unicode-cjk');

      // Search Emojis
      final emojiMatch = await dao.searchCatalogCards('🔥🃏');
      expect(emojiMatch.length, 1);
      expect(emojiMatch.first.id, 'item-unicode-emoji');
    });

    test('Extreme Boundary Inputs: Huge strings, whitespaces, null characters, and limit edges', () async {
      // 1. 10,000 character string executes with zero exceptions
      final hugeQuery = 'A' * 10000;
      final hugeResults = await dao.searchCatalogCards(hugeQuery);
      expect(hugeResults, isEmpty);

      // 2. 5,000 character random alphanumeric string executes with zero exceptions
      final rng = Random(42);
      final randomLong = String.fromCharCodes(
        Iterable.generate(5000, (_) => rng.nextInt(26) + 65),
      );
      final randomResults = await dao.searchCatalogCards(randomLong);
      expect(randomResults, isEmpty);

      // 3. SQLite engine boundary: queries exceeding SQLITE_MAX_LIKE_PATTERN_LENGTH (50,000 bytes)
      // safely raise SqliteException rather than corrupting memory or crashing
      final boundary50k = 'B' * 50000;
      expect(
        () => dao.searchCatalogCards(boundary50k),
        throwsA(isA<SqliteException>()),
      );

      // 3. Whitespaces and tabs
      final whitespaceResults = await dao.searchCatalogCards('   \t\r\n   ');
      expect(whitespaceResults, isNotEmpty); // Treats as empty query, returns top results

      // 4. Null byte in query
      final nullByteResults = await dao.searchCatalogCards('Sol\u0000Ring');
      expect(nullByteResults, isA<List<VaultItem>>());

      // 5. Limits: limit = 0, limit = 1, limit = 1000
      final limitZero = await dao.searchCatalogCards('', limit: 0);
      expect(limitZero, isEmpty);

      final limitOne = await dao.searchCatalogCards('', limit: 1);
      expect(limitOne.length, 1);

      final limitLarge = await dao.searchCatalogCards('', limit: 1000);
      expect(limitLarge.length, greaterThanOrEqualTo(4));

      // 6. Injection in collectionType
      final injectionCollection = await dao.searchCatalogCards(
        'The One Ring',
        collectionType: "mtg' OR '1'='1",
      );
      // Normalized should not crash and should return empty or filtered results
      expect(injectionCollection, isA<List<VaultItem>>());
    });
  });

  // ===========================================================================
  // GROUP 2: BULK ADD EDGE CASES & TRANSACTION INTEGRITY (bulkAddCatalogItems)
  // ===========================================================================
  group('Adversarial Bulk Add: Missing IDs, Zero/Negative Quantities & 50-Item Stress', () {
    test('Non-existent card IDs are skipped cleanly without throwing exceptions or partial corruption', () async {
      // Pure non-existent map
      await dao.bulkAddCatalogItems(
        stagedItems: {
          'non-existent-uuid-1': 5,
          'phantom-card-999': 10,
        },
      );

      // Mixed non-existent and valid IDs
      final initialSolRing = await (db.select(db.vaultItems)
            ..where((t) => t.id.equals('item-mtg-one-ring')))
          .getSingle();
      final originalQuantity = initialSolRing.quantity;

      await dao.bulkAddCatalogItems(
        stagedItems: {
          'ghost-card-1': 100,
          'item-mtg-one-ring': 3,
          'ghost-card-2': 50,
        },
      );

      final updatedSolRing = await (db.select(db.vaultItems)
            ..where((t) => t.id.equals('item-mtg-one-ring')))
          .getSingle();

      expect(updatedSolRing.quantity, originalQuantity + 3);
    });

    test('Zero and Negative Quantities never modify or decrement inventory', () async {
      final initialItem = await (db.select(db.vaultItems)
            ..where((t) => t.id.equals('item-mtg-one-ring')))
          .getSingle();
      final originalQuantity = initialItem.quantity;

      // Try adding zero
      await dao.bulkAddCatalogItems(
        stagedItems: {'item-mtg-one-ring': 0},
      );
      var check = await (db.select(db.vaultItems)
            ..where((t) => t.id.equals('item-mtg-one-ring')))
          .getSingle();
      expect(check.quantity, originalQuantity);

      // Try adding negative quantities
      await dao.bulkAddCatalogItems(
        stagedItems: {
          'item-mtg-one-ring': -1,
          'item-pokemon-charizard': -10,
          'ghost-card': -5,
        },
      );

      check = await (db.select(db.vaultItems)
            ..where((t) => t.id.equals('item-mtg-one-ring')))
          .getSingle();
      expect(check.quantity, originalQuantity);

      final charizard = await (db.select(db.vaultItems)
            ..where((t) => t.id.equals('item-pokemon-charizard')))
          .getSingle();
      expect(charizard.quantity, 1);
    });

    test('Bulk adding 50 distinct items simultaneously in one atomic transaction executes in <500ms', () async {
      // 1. Seed 60 distinct unowned catalog items (quantity = 0)
      final catalogItems = <VaultItemsCompanion>[];
      final stagedMap = <String, int>{};
      var expectedTotalAddedQty = 0;
      var expectedAddedMarketValue = 0.0;

      for (var i = 0; i < 60; i++) {
        final id = 'catalog-stress-item-${i.toString().padLeft(3, '0')}';
        final price = 1.0 + (i * 0.5); // $1.00, $1.50, ...
        catalogItems.add(
          VaultItemsCompanion.insert(
            id: id,
            collectionType: (i % 2 == 0) ? 'mtg' : 'pokemon',
            name: 'Stress Test Card #$i',
            setOrSeries: 'Stress Testing Edition',
            imageUrl: 'https://example.com/cards/$i.png',
            acquiredPrice: 0.0,
            acquiredDate: DateTime(2026, 1, 1),
            quantity: const drift.Value(0),
            condition: 'NM',
            currentMarketPrice: price,
            lastPriceUpdate: DateTime(2026, 1, 1),
            dynamicData: '{}',
          ),
        );
      }

      await db.batch((b) => b.insertAll(db.vaultItems, catalogItems));

      // 2. Stage exactly 50 distinct items with varied quantities (1..5)
      for (var i = 0; i < 50; i++) {
        final id = 'catalog-stress-item-${i.toString().padLeft(3, '0')}';
        final qty = (i % 5) + 1; // 1 to 5
        final price = 1.0 + (i * 0.5);
        stagedMap[id] = qty;
        expectedTotalAddedQty += qty;
        expectedAddedMarketValue += (price * qty);
      }

      final initialTotals = await dao.getVaultTotals();
      final stopwatch = Stopwatch()..start();

      // 3. Execute bulkAddCatalogItems for 50 distinct items in one transaction
      await dao.bulkAddCatalogItems(
        stagedItems: stagedMap,
        targetBinderId: 'binder-stress-bulk',
      );
      stopwatch.stop();

      // Assert high performance (< 500ms for 50 items inside transaction)
      expect(stopwatch.elapsedMilliseconds, lessThan(500),
          reason: 'Bulk adding 50 items took ${stopwatch.elapsedMilliseconds}ms, expected < 500ms');

      // 4. Verify all 50 items transitioned to owned with correct quantities and binder
      final addedItems = await (db.select(db.vaultItems)
            ..where((t) => t.id.isIn(stagedMap.keys)))
          .get();

      expect(addedItems.length, 50);
      for (final item in addedItems) {
        final expectedQty = stagedMap[item.id]!;
        expect(item.quantity, expectedQty);
        expect(item.primaryBinderId, 'binder-stress-bulk');
        // Acquired price was initialized to market price
        expect(item.acquiredPrice, item.currentMarketPrice);
        expect(item.acquiredDate.isAfter(DateTime(2026, 1, 1)), isTrue);
      }

      // 5. Verify the remaining 10 items are untouched (quantity still 0)
      final untouchedItems = await (db.select(db.vaultItems)
            ..where((t) => t.id.like('catalog-stress-item%') & t.quantity.equals(0)))
          .get();
      expect(untouchedItems.length, 10);

      // 6. Verify total database counts match mathematically
      final afterTotals = await dao.getVaultTotals();
      expect(afterTotals.totalCount, initialTotals.totalCount + expectedTotalAddedQty);
      expect(
        afterTotals.totalMarketValue,
        closeTo(initialTotals.totalMarketValue + expectedAddedMarketValue, 0.01),
      );
    });

    test('Successive repeated bulk additions cleanly increment owned items without overwriting initial acquiredPrice', () async {
      // 1. Initial bulk add for unowned card
      await db.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'catalog-repeat-test',
              collectionType: 'mtg',
              name: 'Repeat Increment Card',
              setOrSeries: 'Core Set',
              imageUrl: '',
              acquiredPrice: 0.0,
              acquiredDate: DateTime(2026, 1, 1),
              quantity: const drift.Value(0),
              condition: 'NM',
              currentMarketPrice: 20.0,
              lastPriceUpdate: DateTime(2026, 1, 1),
              dynamicData: '{}',
            ),
          );

      // First addition: stages 2 items
      await dao.bulkAddCatalogItems(
        stagedItems: {'catalog-repeat-test': 2},
        targetBinderId: 'binder-repeat',
      );

      var card = await (db.select(db.vaultItems)
            ..where((t) => t.id.equals('catalog-repeat-test')))
          .getSingle();
      expect(card.quantity, 2);
      expect(card.acquiredPrice, 20.0);
      expect(card.primaryBinderId, 'binder-repeat');

      // Now change market price to $30.00
      await (db.update(db.vaultItems)
            ..where((t) => t.id.equals('catalog-repeat-test')))
          .write(
        const VaultItemsCompanion(
          currentMarketPrice: drift.Value(30.0),
        ),
      );

      // Second addition: stages 3 more items (targetBinderId = null, should keep existing binder)
      await dao.bulkAddCatalogItems(
        stagedItems: {'catalog-repeat-test': 3},
        targetBinderId: null,
      );

      card = await (db.select(db.vaultItems)
            ..where((t) => t.id.equals('catalog-repeat-test')))
          .getSingle();
      expect(card.quantity, 5); // 2 + 3
      expect(card.primaryBinderId, 'binder-repeat'); // Preserved
      expect(card.acquiredPrice, 20.0); // Preserved original acquisition price!
    });
  });

  // ===========================================================================
  // GROUP 3: REACTIVE STREAM VERIFICATION (watchVaultTotals)
  // ===========================================================================
  group('Reactive Stream Verification: watchVaultTotals immediate reaction & accuracy', () {
    test('watchVaultTotals reacts immediately and accurately to bulk additions', () async {
      final emittedTotals = <VaultTotals>[];
      final subscription = dao.watchVaultTotals().listen(emittedTotals.add);

      // Wait for initial emission
      await pumpEventQueue();
      expect(emittedTotals.length, 1);
      final initial = emittedTotals.first;

      // Seed 10 new catalog cards
      for (var i = 0; i < 10; i++) {
        await db.into(db.vaultItems).insert(
              VaultItemsCompanion.insert(
                id: 'stream-test-$i',
                collectionType: 'mtg',
                name: 'Stream Card $i',
                setOrSeries: 'Stream Edition',
                imageUrl: '',
                acquiredPrice: 0.0,
                acquiredDate: DateTime.now(),
                quantity: const drift.Value(0),
                condition: 'NM',
                currentMarketPrice: 10.0,
                lastPriceUpdate: DateTime.now(),
                dynamicData: '{}',
              ),
            );
      }

      // Bulk add 5 cards with 2 quantity each (+10 count, +$100 market value)
      await dao.bulkAddCatalogItems(
        stagedItems: {
          'stream-test-0': 2,
          'stream-test-1': 2,
          'stream-test-2': 2,
          'stream-test-3': 2,
          'stream-test-4': 2,
        },
      );

      await pumpEventQueue();

      // Stream must have emitted an updated total
      expect(emittedTotals.length, greaterThanOrEqualTo(2));
      final latest = emittedTotals.last;

      expect(latest.totalCount, initial.totalCount + 10);
      expect(latest.totalMarketValue, closeTo(initial.totalMarketValue + 100.0, 0.01));
      expect(latest.totalCostBasis, closeTo(initial.totalCostBasis + 100.0, 0.01));

      await subscription.cancel();
    });

    test('watchVaultTotals respects binder scoping and isolates INBOX additions', () async {
      final binderAlphaTotals = <VaultTotals>[];
      final macroTotals = <VaultTotals>[];

      final subAlpha = dao
          .watchVaultTotals(binderId: 'binder-alpha')
          .listen(binderAlphaTotals.add);
      final subMacro = dao.watchVaultTotals().listen(macroTotals.add);

      await pumpEventQueue();

      final initialMacro = macroTotals.last;
      final initialAlpha = binderAlphaTotals.last;
      expect(initialAlpha.totalCount, 0);

      // 1. Insert unowned cards
      await db.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'card-alpha-1',
              collectionType: 'mtg',
              name: 'Alpha Bound Card',
              setOrSeries: 'Set A',
              imageUrl: '',
              acquiredPrice: 0.0,
              acquiredDate: DateTime.now(),
              quantity: const drift.Value(0),
              condition: 'NM',
              currentMarketPrice: 50.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: '{}',
            ),
          );

      await db.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'card-inbox-1',
              collectionType: 'mtg',
              name: 'Inbox Bound Card',
              setOrSeries: 'Set Inbox',
              imageUrl: '',
              acquiredPrice: 0.0,
              acquiredDate: DateTime.now(),
              quantity: const drift.Value(0),
              condition: 'NM',
              currentMarketPrice: 75.0,
              lastPriceUpdate: DateTime.now(),
              dynamicData: '{}',
            ),
          );

      // 2. Bulk add to 'binder-alpha'
      await dao.bulkAddCatalogItems(
        stagedItems: {'card-alpha-1': 2},
        targetBinderId: 'binder-alpha',
      );
      await pumpEventQueue();

      expect(binderAlphaTotals.last.totalCount, 2);
      expect(binderAlphaTotals.last.totalMarketValue, 100.0);
      expect(macroTotals.last.totalCount, initialMacro.totalCount + 2);

      // 3. Bulk add to 'INBOX'
      await dao.bulkAddCatalogItems(
        stagedItems: {'card-inbox-1': 3},
        targetBinderId: 'INBOX',
      );
      await pumpEventQueue();

      // INBOX items MUST NOT inflate macro totals (IS NULL OR != 'INBOX')
      expect(macroTotals.last.totalCount, initialMacro.totalCount + 2);
      expect(binderAlphaTotals.last.totalCount, 2);

      // Check that inbox items query sees it
      final inboxCards = await dao.watchInboxItems().first;
      expect(inboxCards.any((c) => c.id == 'card-inbox-1' && c.quantity == 3), isTrue);

      await subAlpha.cancel();
      await subMacro.cancel();
    });
  });
}
