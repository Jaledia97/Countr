import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import '../helpers/e2e_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late VaultDao dao;

  setUp(() async {
    db = createE2ETestDatabase();
    dao = db.vaultDao;
    await seedStandardM1Catalog(dao);
  });

  tearDown(() async {
    await db.close();
  });

  group('Tier 2 - Boundary Value Analysis: Milestone 1', () {
    test('B1: Empty catalog boundary returns count 0 and empty list without throwing', () async {
      await dao.clearAllItems();

      final count = await dao.getFilteredItemCount('mtg', onlyOwned: false);
      final items = await dao.getItemsByCollection('mtg', onlyOwned: false);

      expect(count, equals(0));
      expect(items, isEmpty);

      final ownedCount = await dao.getFilteredItemCount('mtg', onlyOwned: true);
      final ownedItems = await dao.getItemsByCollection('mtg', onlyOwned: true);

      expect(ownedCount, equals(0));
      expect(ownedItems, isEmpty);
    });

    test('B2: Single card boundary yields count 1 and single item list with hasMore false', () async {
      await dao.clearAllItems();
      final singleCard = createE2ETestCard(
        id: 'solo-card',
        name: 'Solitary Confinement',
        quantity: 1,
      );
      await insertTestCards(dao, [singleCard]);

      final count = await dao.getFilteredItemCount('mtg', onlyOwned: false);
      final items = await dao.getItemsByCollection('mtg', onlyOwned: false, limit: 60);

      expect(count, equals(1));
      expect(items.length, equals(1));
      expect(items.first.id, equals('solo-card'));

      // If page limit is 60 and count is 1, hasMore is strictly false
      final hasMore = items.length < count;
      expect(hasMore, isFalse);
    });

    test('B3: Extreme pagination offset exceeding candidate count returns empty list cleanly', () async {
      final items = await dao.getItemsByCollection(
        'mtg',
        onlyOwned: false,
        limit: 60,
        offset: 50000, // Offset far beyond total 10 cards
      );

      expect(items, isEmpty);
    });

    test('B4.1: Search query with SQL wildcards and metacharacters is safely parameterized', () async {
      // Query containing SQL wildcards, quotes, and injection payload
      const maliciousPayload = "' OR '1'='1'; DROP TABLE vault_items; -- %_";
      final count = await dao.getFilteredItemCount(
        'mtg',
        onlyOwned: false,
        searchQuery: maliciousPayload,
      );
      final results = await dao.getItemsByCollection(
        'mtg',
        onlyOwned: false,
        searchQuery: maliciousPayload,
      );

      expect(count, equals(0), reason: 'SQL injection must be safely escaped and find 0 matches');
      expect(results, isEmpty);

      // Verify vault_items table was NOT dropped
      final stillExists = await dao.getFilteredItemCount('mtg', onlyOwned: false);
      expect(stillExists, equals(10));
    });

    test('B4.2: Split-card delimiters (//) and quoted search queries match successfully', () async {
      // Query split card using "//" delimiter
      final splitMatch = await dao.getItemsByCollection(
        'mtg',
        searchQuery: 'Ravager //',
        onlyOwned: false,
      );
      expect(splitMatch, isNotEmpty);
      expect(splitMatch.first.name, contains('Nicol Bolas'));

      // Query with punctuation and comma
      final commaMatch = await dao.getItemsByCollection(
        'mtg',
        searchQuery: 'Nicol Bolas,',
        onlyOwned: false,
      );
      expect(commaMatch, isNotEmpty);
      expect(commaMatch.first.name, contains('Nicol Bolas'));
    });

    test('B5: Extreme numeric boundaries (zero price, large price, extreme quantity)', () async {
      final extremeCards = [
        createE2ETestCard(
          id: 'c-penny',
          name: 'Penny Card',
          acquiredPrice: 0.0,
          currentMarketPrice: 0.0,
          quantity: 1,
        ),
        createE2ETestCard(
          id: 'c-million',
          name: 'Million Dollar Card',
          acquiredPrice: 999999.99,
          currentMarketPrice: 1000000.0,
          quantity: 9999,
        ),
      ];
      await insertTestCards(dao, extremeCards);

      final penny = await dao.getItemById('c-penny');
      expect(penny, isNotNull);
      expect(penny!.acquiredPrice, equals(0.0));
      expect(penny.currentMarketPrice, equals(0.0));

      final million = await dao.getItemById('c-million');
      expect(million, isNotNull);
      expect(million!.acquiredPrice, equals(999999.99));
      expect(million.currentMarketPrice, equals(1000000.0));
      expect(million.quantity, equals(9999));
    });

    test('B6: Assigning empty ID list or non-existent card ID to binder handles safely', () async {
      // Empty list
      final zeroCount = await dao.assignItemsToBinder([], 'power-nine');
      expect(zeroCount, equals(0));

      // Non-existent ID
      final notFoundCount = await dao.assignItemsToBinder(['does-not-exist'], 'power-nine');
      expect(notFoundCount, equals(0));
    });

    test('B7: Card with malformed or empty dynamic_data JSON does not crash queries', () async {
      final brokenJsonCard = VaultItem(
        id: 'c-broken-json',
        collectionType: 'mtg',
        name: 'Broken Data Card',
        setOrSeries: 'Glitch Set',
        imageUrl: '',
        acquiredPrice: 1.0,
        acquiredDate: DateTime.now(),
        quantity: 1,
        condition: 'NM',
        isGraded: false,
        isAltered: false,
        isMisprint: false,
        isSigned: false,
        currentMarketPrice: 1.0,
        lastPriceUpdate: DateTime.now(),
        dynamicData: '{this is not valid json!}',
        isDeleted: false,
      );
      await insertTestCards(dao, [brokenJsonCard]);

      // Queries should execute safely without crashing JSON parser
      final item = await dao.getItemById('c-broken-json');
      expect(item, isNotNull);
      expect(item!.id, equals('c-broken-json'));

      final totalCount = await dao.getFilteredItemCount('mtg', onlyOwned: false);
      expect(totalCount, equals(11));
    });

    test('B8: Whitespace-only search query behaves as empty query without filtering out cards', () async {
      final whitespaceCount = await dao.getFilteredItemCount(
        'mtg',
        onlyOwned: false,
        searchQuery: '     ',
      );
      final normalCount = await dao.getFilteredItemCount(
        'mtg',
        onlyOwned: false,
        searchQuery: null,
      );

      expect(whitespaceCount, equals(normalCount));
    });

    test('B9: Case insensitivity boundary across UPPERCASE, lowercase, and MixedCase', () async {
      final upperResults = await dao.getItemsByCollection(
        'mtg',
        searchQuery: 'BLACK LOTUS',
        onlyOwned: false,
      );
      final lowerResults = await dao.getItemsByCollection(
        'mtg',
        searchQuery: 'black lotus',
        onlyOwned: false,
      );
      final mixedResults = await dao.getItemsByCollection(
        'mtg',
        searchQuery: 'BlAcK lOtUs',
        onlyOwned: false,
      );

      expect(upperResults.length, equals(1));
      expect(lowerResults.length, equals(1));
      expect(mixedResults.length, equals(1));
      expect(upperResults.first.id, equals(lowerResults.first.id));
      expect(lowerResults.first.id, equals(mixedResults.first.id));
    });

    test('B10: Unassigned binder cards have primary_binder_id as NULL or empty', () async {
      final bolt = (await dao.getItemById('c-bolt'))!;
      expect(bolt.primaryBinderId, isNull);

      final unassignedCards = await (dao.select(dao.vaultItems)
            ..where((t) => t.primaryBinderId.isNull() & t.quantity.isBiggerThanValue(0)))
          .get();

      expect(unassignedCards, isNotEmpty);
      expect(unassignedCards.any((c) => c.id == 'c-bolt'), isTrue);
    });
  });
}
