import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/decks/data/daos/explore_deck_dao.dart';
import 'package:countr/features/decks/domain/models/explore_deck_models.dart';
import 'package:countr/features/vault/presentation/providers/mtg_filter_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('Milestone 2 Challenger 1: Adversarial Edge Cases & Boundary Stress Test', () {
    late AppDatabase db;
    late ExploreDeckDao exploreDao;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      exploreDao = ExploreDeckDao(db);

      await db.delete(db.vaultItems).go();
      await db.delete(db.exploreDeckItems).go();
      await db.delete(db.exploreDecks).go();
    });

    tearDown(() async {
      await db.close();
    });

    // =========================================================================
    // 1. EMPTY DATABASE INVARIANTS (ZERO ITEMS)
    // =========================================================================
    group('1. Empty Database Boundary', () {
      test('VaultDao returns exactly 0 on empty database for getFilteredItemCount and watchFilteredItemCount', () async {
        // Unfiltered
        final countOneShot = await db.vaultDao.getFilteredItemCount('mtg');
        final countStream = await db.vaultDao.watchFilteredItemCount('mtg').first;
        expect(countOneShot, equals(0), reason: 'getFilteredItemCount must return 0 on empty table');
        expect(countStream, equals(0), reason: 'watchFilteredItemCount must return 0 on empty table');

        // With various filters on empty database
        final withFilters = await db.vaultDao.getFilteredItemCount(
          'mtg',
          onlyOwned: true,
          searchQuery: 'Lotus',
          mtgFilter: const MtgFilterState(colors: {'R'}, colorMatchMode: ColorMatchMode.exactly),
        );
        expect(withFilters, equals(0));

        final allCollection = await db.vaultDao.getFilteredItemCount('all');
        expect(allCollection, equals(0));
      });

      test('ExploreDeckDao returns exactly 0 on empty database for getFilteredExploreDeckCount and watchFilteredExploreDeckCount', () async {
        // Unfiltered
        final totalOneShot = await exploreDao.getFilteredExploreDeckCount();
        final totalStream = await exploreDao.watchFilteredExploreDeckCount().first;
        expect(totalOneShot, equals(0));
        expect(totalStream, equals(0));

        // Official category on empty table
        final officialCount = await exploreDao.getFilteredExploreDeckCount(category: ExploreCategory.official);
        expect(officialCount, equals(0));

        // Community category on empty table
        final communityCount = await exploreDao.getFilteredExploreDeckCount(category: ExploreCategory.community);
        expect(communityCount, equals(0));

        // With complex filters on empty table
        final withFilters = await exploreDao.getFilteredExploreDeckCount(
          category: ExploreCategory.all,
          searchQuery: 'Dragon',
          filter: const ExploreFilterState(format: 'Commander', priceRange: 'budget_0_50', colors: ['R']),
        );
        expect(withFilters, equals(0));
      });
    });

    // =========================================================================
    // 2. NON-MATCHING CRITERIA INVARIANTS (POPULATED DB -> EXPECT 0)
    // =========================================================================
    group('2. Non-Matching Filter Criteria', () {
      setUp(() async {
        final now = DateTime.now();
        // Seed 10 Red MTG items
        final items = List.generate(
          10,
          (i) => VaultItemsCompanion.insert(
            id: 'item_red_$i',
            collectionType: 'mtg',
            name: "Goblin Raider $i",
            setOrSeries: 'ZEN',
            imageUrl: '',
            acquiredPrice: 1.0,
            acquiredDate: now,
            lastPriceUpdate: now,
            currentMarketPrice: 2.0,
            quantity: const Value(1),
            condition: 'NM',
            dynamicData: '{"colors":["R"],"color_identity":["R"],"cmc":2,"rarity":"common"}',
          ),
        );
        await db.batch((b) => b.insertAll(db.vaultItems, items));

        // Seed 5 Official Commander Decks (Mono Red)
        final decks = List.generate(
          5,
          (i) => ExploreDecksCompanion.insert(
            id: 'deck_red_$i',
            name: "Red Aggro $i",
            format: 'Commander',
            sourceType: const Value('official'),
            creatorName: const Value('Wizards of the Coast'),
            estimatedPrice: const Value(40.0), // budget tier
            colorIdentity: const Value('["R"]'),
            cardCount: const Value(100),
            createdAt: now,
          ),
        );
        await db.batch((b) => b.insertAll(db.exploreDecks, decks));
      });

      test('VaultDao: Non-matching color returns 0', () async {
        final count = await db.vaultDao.getFilteredItemCount(
          'mtg',
          mtgFilter: const MtgFilterState(colors: {'U'}, colorMatchMode: ColorMatchMode.including),
        );
        expect(count, equals(0));
      });

      test('VaultDao: Non-matching collectionType returns 0', () async {
        final count = await db.vaultDao.getFilteredItemCount('pokemon');
        expect(count, equals(0));
      });

      test('VaultDao: Non-matching search query returns 0', () async {
        final count = await db.vaultDao.getFilteredItemCount(
          'mtg',
          searchQuery: 'NonExistentCardXYZ',
        );
        expect(count, equals(0));
      });

      test('VaultDao: onlyOwned=true returns 0 when all matching items have quantity=0', () async {
        // Update all items to quantity = 0 (unowned catalog)
        await (db.update(db.vaultItems)).write(const VaultItemsCompanion(quantity: Value(0)));

        final count = await db.vaultDao.getFilteredItemCount('mtg', onlyOwned: true);
        expect(count, equals(0));

        // When onlyOwned=false (catalog mode), count must still be 10
        final catalogCount = await db.vaultDao.getFilteredItemCount('mtg', onlyOwned: false);
        expect(catalogCount, equals(10));
      });

      test('ExploreDeckDao: Non-matching category returns 0', () async {
        // All seeded decks are official -> community must return 0
        final count = await exploreDao.getFilteredExploreDeckCount(category: ExploreCategory.community);
        expect(count, equals(0));
      });

      test('ExploreDeckDao: Non-matching format returns 0', () async {
        final count = await exploreDao.getFilteredExploreDeckCount(
          filter: const ExploreFilterState(format: 'Modern'),
        );
        expect(count, equals(0));
      });

      test('ExploreDeckDao: Non-matching price range returns 0', () async {
        // All decks are $40 (budget) -> high_200_plus must return 0
        final count = await exploreDao.getFilteredExploreDeckCount(
          filter: const ExploreFilterState(priceRange: 'high_200_plus'),
        );
        expect(count, equals(0));
      });

      test('ExploreDeckDao: Non-matching card inclusion returns 0', () async {
        final count = await exploreDao.getFilteredExploreDeckCount(
          filter: const ExploreFilterState(cardInclusion: 'Black Lotus'),
        );
        expect(count, equals(0));
      });

      test('ExploreDeckDao: Non-matching search query returns 0', () async {
        final count = await exploreDao.getFilteredExploreDeckCount(
          searchQuery: 'TotallyUnknownDeckName12345',
        );
        expect(count, equals(0));
      });
    });

    // =========================================================================
    // 3. PAGINATION & SLICE INDEPENDENCE INVARIANT
    // =========================================================================
    group('3. Pagination & Slice Independence', () {
      test('Count query is never constrained or altered by limit/offset slicing in data queries', () async {
        final now = DateTime.now();
        // Seed 100 items
        final items = List.generate(
          100,
          (i) => VaultItemsCompanion.insert(
            id: 'item_page_$i',
            collectionType: 'mtg',
            name: "Card $i",
            setOrSeries: 'SET',
            imageUrl: '',
            acquiredPrice: 1.0,
            acquiredDate: now.subtract(Duration(minutes: i)),
            lastPriceUpdate: now,
            currentMarketPrice: 2.0,
            quantity: const Value(1),
            condition: 'NM',
            dynamicData: '{"colors":["G"]}',
          ),
        );
        await db.batch((b) => b.insertAll(db.vaultItems, items));

        // Check count query before, during, and after slices with different limits and offsets
        final trueCount = await db.vaultDao.getFilteredItemCount('mtg');
        expect(trueCount, equals(100));

        // Slice with limit: 1
        final slice1 = await db.vaultDao.getItemsByCollection('mtg', limit: 1);
        expect(slice1.length, equals(1));
        expect(await db.vaultDao.getFilteredItemCount('mtg'), equals(100));

        // Slice with limit: 10, offset: 20
        final slice10 = await db.vaultDao.getItemsByCollection('mtg', limit: 10, offset: 20);
        expect(slice10.length, equals(10));
        expect(await db.vaultDao.getFilteredItemCount('mtg'), equals(100));

        // Slice with offset beyond total: offset 150 -> returns empty list, but count is still 100
        final sliceEmpty = await db.vaultDao.getItemsByCollection('mtg', limit: 50, offset: 150);
        expect(sliceEmpty.isEmpty, isTrue);
        expect(await db.vaultDao.getFilteredItemCount('mtg'), equals(100));
      });
    });

    // =========================================================================
    // 4. ADVERSARIAL INPUTS & SPECIAL CHARACTERS
    // =========================================================================
    group('4. Adversarial Inputs & Special Characters', () {
      test('Handles apostrophes, percent signs, quotes, and punctuation in search queries without SQL error', () async {
        final now = DateTime.now();
        await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: 'apostrophe_card',
            collectionType: 'mtg',
            name: "Gaea's Cradle",
            setOrSeries: 'USG',
            imageUrl: '',
            acquiredPrice: 500.0,
            acquiredDate: now,
            lastPriceUpdate: now,
            currentMarketPrice: 800.0,
            quantity: const Value(1),
            condition: 'LP',
            dynamicData: '{"colors":["G"]}',
          ),
        );

        // Search with single quote
        final countApostrophe = await db.vaultDao.getFilteredItemCount(
          'mtg',
          searchQuery: "Gaea's",
        );
        expect(countApostrophe, equals(1));

        // Search with wildcard characters (should be treated as string or safe query, not crash)
        final countWildcard = await db.vaultDao.getFilteredItemCount(
          'mtg',
          searchQuery: "%_[]'",
        );
        expect(countWildcard, equals(0));

        // Search with whitespace padding
        final countWhitespace = await db.vaultDao.getFilteredItemCount(
          'mtg',
          searchQuery: "   Gaea's Cradle   ",
        );
        expect(countWhitespace, equals(1));
      });

      test('ExploreDeckDao handles creator names with @, underscores, and quotes safely', () async {
        final now = DateTime.now();
        await db.into(db.exploreDecks).insert(
          ExploreDecksCompanion.insert(
            id: 'weird_creator_deck',
            name: "Deck With Special's Name",
            format: 'Commander',
            sourceType: const Value('community'),
            creatorName: const Value('@Crazy_Brewer"100%'),
            estimatedPrice: const Value(75.0),
            createdAt: now,
          ),
        );

        final count = await exploreDao.getFilteredExploreDeckCount(
          searchQuery: '@Crazy_Brewer"100%',
        );
        expect(count, equals(1));

        final countQuotes = await exploreDao.getFilteredExploreDeckCount(
          searchQuery: "Special's",
        );
        expect(countQuotes, equals(1));
      });
    });

    // =========================================================================
    // 5. RAPID BATCH MUTATION STRESS & STREAM CONSISTENCY
    // =========================================================================
    group('5. Rapid Mutation Stress & Stream Invariants', () {
      test('watchFilteredItemCount maintains exact count throughout 50 rapid incremental insertions', () async {
        final now = DateTime.now();
        final emissions = <int>[];
        final sub = db.vaultDao.watchFilteredItemCount('mtg').listen(emissions.add);

        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(emissions.last, equals(0));

        for (int i = 1; i <= 50; i++) {
          await db.into(db.vaultItems).insert(
            VaultItemsCompanion.insert(
              id: 'stress_item_$i',
              collectionType: 'mtg',
              name: 'Stress Card $i',
              setOrSeries: 'STR',
              imageUrl: '',
              acquiredPrice: 1.0,
              acquiredDate: now,
              lastPriceUpdate: now,
              currentMarketPrice: 1.0,
              quantity: const Value(1),
              condition: 'NM',
              dynamicData: '{}',
            ),
          );
        }

        // Allow stream events to process
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(emissions.last, equals(50));
        expect(await db.vaultDao.getFilteredItemCount('mtg'), equals(50));

        await sub.cancel();
      });
    });
  });
}
