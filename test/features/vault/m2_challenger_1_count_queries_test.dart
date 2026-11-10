import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/core/state/app_state.dart';
import 'package:countr/features/decks/data/daos/explore_deck_dao.dart';
import 'package:countr/features/decks/domain/models/explore_deck_models.dart';
import 'package:countr/features/decks/presentation/providers/explore_deck_providers.dart';
import 'package:countr/features/vault/presentation/providers/mtg_filter_state.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('Milestone 2 Challenger 1: VaultDao & ExploreDeckDao Count Invariants Stress Suite', () {
    late AppDatabase db;
    late ExploreDeckDao exploreDao;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      exploreDao = ExploreDeckDao(db);

      // Clean all tables so test starts with a completely controlled dataset
      await db.delete(db.vaultItems).go();
      await db.delete(db.exploreDeckItems).go();
      await db.delete(db.exploreDecks).go();
    });

    tearDown(() async {
      await db.close();
    });

    // =========================================================================
    // HELPER: Seed 250 diverse Vault cards
    // =========================================================================
    Future<void> seed250VaultCards() async {
      final now = DateTime.now();
      final items = <VaultItemsCompanion>[];

      // 1. 180 Mono-Red Cards
      // - 10 Secret Lair cards with setOrSeries 'SLD' and set 'sld'
      // - 170 Goblin Guide cards with setOrSeries 'ZEN'
      for (int i = 0; i < 180; i++) {
        final isSld = i < 10;
        final name = isSld ? 'Secret Lair Dragon $i' : 'Goblin Guide $i';
        final set = isSld ? 'SLD' : 'ZEN';
        final cmc = (i % 5) + 1; // 1..5
        final rarity = (i % 3 == 0)
            ? 'rare'
            : (i % 3 == 1 ? 'uncommon' : 'common');
        final isModernLegal = (i % 2 == 0);

        items.add(
          VaultItemsCompanion.insert(
            id: 'red_$i',
            collectionType: 'mtg',
            name: name,
            setOrSeries: set,
            imageUrl: 'https://cards.scryfall.io/red_$i.jpg',
            acquiredPrice: 2.5,
            acquiredDate: now.subtract(Duration(minutes: i)),
            lastPriceUpdate: now,
            currentMarketPrice: 4.0,
            quantity: const Value(1),
            condition: 'NM',
            dynamicData:
                '{"colors":["R"],"color_identity":["R"],"cmc":$cmc,"rarity":"$rarity","set":"${set.toLowerCase()}","legalities":{"commander":"legal","modern":"${isModernLegal ? 'legal' : 'not_legal'}"}}',
          ),
        );
      }

      // 2. 40 Boros (Red-White) Cards
      for (int i = 0; i < 40; i++) {
        final cmc = (i % 4) + 2; // 2..5
        final rarity = i % 2 == 0 ? 'rare' : 'mythic';
        items.add(
          VaultItemsCompanion.insert(
            id: 'boros_$i',
            collectionType: 'mtg',
            name: 'Boros Legionnaire $i',
            setOrSeries: 'GRN',
            imageUrl: 'https://cards.scryfall.io/boros_$i.jpg',
            acquiredPrice: 3.0,
            acquiredDate: now.subtract(Duration(minutes: 200 + i)),
            lastPriceUpdate: now,
            currentMarketPrice: 5.5,
            quantity: const Value(1),
            condition: 'NM',
            dynamicData:
                '{"colors":["R","W"],"color_identity":["R","W"],"cmc":$cmc,"rarity":"$rarity","set":"grn","legalities":{"commander":"legal","modern":"legal"}}',
          ),
        );
      }

      // 3. 20 Mono-White Cards
      for (int i = 0; i < 20; i++) {
        final cmc = (i % 3) + 1; // 1..3
        items.add(
          VaultItemsCompanion.insert(
            id: 'white_$i',
            collectionType: 'mtg',
            name: 'Knight of Dawn $i',
            setOrSeries: 'DOM',
            imageUrl: 'https://cards.scryfall.io/white_$i.jpg',
            acquiredPrice: 1.0,
            acquiredDate: now.subtract(Duration(minutes: 300 + i)),
            lastPriceUpdate: now,
            currentMarketPrice: 2.0,
            quantity: const Value(1),
            condition: 'NM',
            dynamicData:
                '{"colors":["W"],"color_identity":["W"],"cmc":$cmc,"rarity":"uncommon","set":"dom","legalities":{"commander":"legal","modern":"legal"}}',
          ),
        );
      }

      // 4. 10 Colorless Cards
      for (int i = 0; i < 10; i++) {
        items.add(
          VaultItemsCompanion.insert(
            id: 'colorless_$i',
            collectionType: 'mtg',
            name: 'Ornithopter $i',
            setOrSeries: 'AER',
            imageUrl: 'https://cards.scryfall.io/colorless_$i.jpg',
            acquiredPrice: 0.5,
            acquiredDate: now.subtract(Duration(minutes: 400 + i)),
            lastPriceUpdate: now,
            currentMarketPrice: 1.0,
            quantity: const Value(1),
            condition: 'NM',
            dynamicData:
                '{"colors":[],"color_identity":[],"cmc":0,"rarity":"uncommon","set":"aer","legalities":{"commander":"legal","modern":"legal"}}',
          ),
        );
      }

      // Total items = 180 + 40 + 20 + 10 = 250 cards!
      await db.batch((b) {
        b.insertAll(db.vaultItems, items);
      });
    }

    // =========================================================================
    // HELPER: Seed 60 diverse Explore Decks (50+ decks requirement)
    // =========================================================================
    Future<void> seed60ExploreDecks() async {
      final now = DateTime.now();
      final decks = <ExploreDecksCompanion>[];

      // 30 Official Decks
      for (int i = 0; i < 30; i++) {
        final isCommander = i < 15;
        final format = isCommander ? 'Commander' : 'Standard';
        final priceTier = i % 3;
        final price = priceTier == 0 ? 35.0 : (priceTier == 1 ? 120.0 : 250.0);
        final colorId = isCommander
            ? (priceTier == 0
                ? '["R"]'
                : (priceTier == 1 ? '["R","W"]' : '["W","U","B","R","G"]'))
            : (priceTier == 0
                ? '["U"]'
                : (priceTier == 1 ? '["U","B"]' : '["B","G"]'));

        decks.add(
          ExploreDecksCompanion.insert(
            id: 'official_deck_$i',
            name: 'Official $format Deck $i',
            format: format,
            sourceType: const Value('official'),
            creatorName: const Value('Wizards of the Coast'),
            estimatedPrice: Value(price),
            colorIdentity: Value(colorId),
            cardCount: Value(isCommander ? 100 : 60),
            createdAt: now.subtract(Duration(hours: i)),
          ),
        );
      }

      // 30 Community Decks
      for (int i = 0; i < 30; i++) {
        final isCommander = i < 15;
        final format = isCommander ? 'Commander' : 'Modern';
        final priceTier = i % 3;
        final price = priceTier == 0 ? 45.0 : (priceTier == 1 ? 110.0 : 350.0);
        final creator = (i % 2 == 0) ? '@SpicyBrewMaster' : '@ModernSpike';
        final colorId = isCommander
            ? (priceTier == 0
                ? '["R"]'
                : (priceTier == 1 ? '["R","G"]' : '["W","U","B"]'))
            : (priceTier == 0
                ? '["R"]'
                : (priceTier == 1 ? '["U","R"]' : '["B"]'));

        decks.add(
          ExploreDecksCompanion.insert(
            id: 'community_deck_$i',
            name: 'Community $format Deck $i',
            format: format,
            sourceType: const Value('community'),
            creatorName: Value(creator),
            estimatedPrice: Value(price),
            colorIdentity: Value(colorId),
            cardCount: Value(isCommander ? 100 : 60),
            createdAt: now.subtract(Duration(hours: 30 + i)),
          ),
        );
      }

      await db.batch((b) {
        b.insertAll(db.exploreDecks, decks);
      });

      // Insert deck items for specific search test cases
      await db.batch((b) {
        b.insertAll(db.exploreDeckItems, [
          ExploreDeckItemsCompanion.insert(
            id: 'item_dockside_1',
            exploreDeckId: 'official_deck_0',
            cardName: 'Dockside Extortionist',
          ),
          ExploreDeckItemsCompanion.insert(
            id: 'item_dockside_2',
            exploreDeckId: 'community_deck_0',
            cardName: 'Dockside Extortionist',
          ),
          ExploreDeckItemsCompanion.insert(
            id: 'item_ragavan_1',
            exploreDeckId: 'community_deck_15',
            cardName: 'Ragavan, Nimble Pilferer',
          ),
        ]);
      });
    }

    // =========================================================================
    // 1. PAGINATION DECOUPLING INVARIANT (250 cards seeded)
    // =========================================================================
    test('1.1: Pagination Decoupling Invariant: watchFilteredItemCount reports 180 while limit=50 emits 50', () async {
      await seed250VaultCards();

      const redFilter = MtgFilterState(
        colors: {'R'},
        colorMatchMode: ColorMatchMode.exactly,
      );

      // Verify watchFilteredItemCount reports exact total (180 Mono-Red cards)
      final countFuture = db.vaultDao.watchFilteredItemCount(
        'mtg',
        onlyOwned: true,
        mtgFilter: redFilter,
      ).first;

      // Verify paginated slice emits only 50 rows
      final sliceFuture = db.vaultDao.watchItemsByCollection(
        'mtg',
        onlyOwned: true,
        mtgFilter: redFilter,
        limit: 50,
      ).first;

      final count = await countFuture;
      final slice = await sliceFuture;

      expect(count, equals(180), reason: 'watchFilteredItemCount must report true total 180');
      expect(slice.length, equals(50), reason: 'watchItemsByCollection must respect limit 50');

      // Test with one-shot queries as well
      final oneShotCount = await db.vaultDao.getFilteredItemCount(
        'mtg',
        onlyOwned: true,
        mtgFilter: redFilter,
      );
      final oneShotSlice = await db.vaultDao.getItemsByCollection(
        'mtg',
        onlyOwned: true,
        mtgFilter: redFilter,
        limit: 50,
      );

      expect(oneShotCount, equals(180));
      expect(oneShotSlice.length, equals(50));

      // Test with alternative limit (20) and offset (50)
      final offsetSlice = await db.vaultDao.getItemsByCollection(
        'mtg',
        onlyOwned: true,
        mtgFilter: redFilter,
        limit: 20,
        offset: 50,
      );
      expect(offsetSlice.length, equals(20));
      expect(oneShotCount, equals(180), reason: 'Database total must remain completely decoupled from pagination');
    });

    // =========================================================================
    // 2. COLOR MATCH MODES: exactly VS including VS atMost
    // =========================================================================
    test('2.1: ColorMatchMode.exactly vs including vs atMost invariants with 250 cards', () async {
      await seed250VaultCards();

      // Population reference:
      // - 180 Mono-Red (colors: ["R"])
      // - 40 Boros (colors: ["R", "W"])
      // - 20 Mono-White (colors: ["W"])
      // - 10 Colorless (colors: [])

      // A. exactly Red {'R'} -> exactly 180 cards
      const exactRed = MtgFilterState(
        colors: {'R'},
        colorMatchMode: ColorMatchMode.exactly,
      );
      final exactRedCount = await db.vaultDao.getFilteredItemCount('mtg', onlyOwned: true, mtgFilter: exactRed);
      final exactRedItems = await db.vaultDao.getItemsByCollection('mtg', onlyOwned: true, mtgFilter: exactRed, limit: 300);
      expect(exactRedCount, equals(180), reason: 'exactly R must match only Mono-Red cards');
      expect(exactRedItems.length, equals(180));
      for (final item in exactRedItems) {
        expect(item.dynamicData.contains('"R"'), isTrue);
        expect(item.dynamicData.contains('"W"'), isFalse);
      }

      // B. including Red {'R'} -> Mono-Red (180) + Boros (40) = 220 cards
      const includingRed = MtgFilterState(
        colors: {'R'},
        colorMatchMode: ColorMatchMode.including,
      );
      final includingRedCount = await db.vaultDao.getFilteredItemCount('mtg', onlyOwned: true, mtgFilter: includingRed);
      final includingRedItems = await db.vaultDao.getItemsByCollection('mtg', onlyOwned: true, mtgFilter: includingRed, limit: 300);
      expect(includingRedCount, equals(220), reason: 'including R must match Mono-Red (180) + Boros (40) = 220');
      expect(includingRedItems.length, equals(220));

      // C. atMost Red {'R'} -> Mono-Red (180) + Colorless (10) = 190 cards
      const atMostRed = MtgFilterState(
        colors: {'R'},
        colorMatchMode: ColorMatchMode.atMost,
      );
      final atMostRedCount = await db.vaultDao.getFilteredItemCount('mtg', onlyOwned: true, mtgFilter: atMostRed);
      final atMostRedItems = await db.vaultDao.getItemsByCollection('mtg', onlyOwned: true, mtgFilter: atMostRed, limit: 300);
      expect(atMostRedCount, equals(190), reason: 'atMost R must match Mono-Red (180) + Colorless (10) = 190');
      expect(atMostRedItems.length, equals(190));

      // D. atMost Red + White {'R', 'W'} -> Mono-Red (180) + Boros (40) + Mono-White (20) + Colorless (10) = 250 cards
      const atMostBoros = MtgFilterState(
        colors: {'R', 'W'},
        colorMatchMode: ColorMatchMode.atMost,
      );
      final atMostBorosCount = await db.vaultDao.getFilteredItemCount('mtg', onlyOwned: true, mtgFilter: atMostBoros);
      expect(atMostBorosCount, equals(250), reason: 'atMost {R, W} must include all R, W, RW, and Colorless cards (250 total)');

      // E. exactly Red + White {'R', 'W'} -> Boros only (40 cards)
      const exactBoros = MtgFilterState(
        colors: {'R', 'W'},
        colorMatchMode: ColorMatchMode.exactly,
      );
      final exactBorosCount = await db.vaultDao.getFilteredItemCount('mtg', onlyOwned: true, mtgFilter: exactBoros);
      final exactBorosItems = await db.vaultDao.getItemsByCollection('mtg', onlyOwned: true, mtgFilter: exactBoros, limit: 300);
      expect(exactBorosCount, equals(40), reason: 'exactly {R, W} must match only the 40 Boros cards');
      expect(exactBorosItems.length, equals(40));

      // F. exactly Colorless {'C'} -> 10 Colorless cards
      const exactColorless = MtgFilterState(
        colors: {'C'},
        colorMatchMode: ColorMatchMode.exactly,
      );
      final exactColorlessCount = await db.vaultDao.getFilteredItemCount('mtg', onlyOwned: true, mtgFilter: exactColorless);
      expect(exactColorlessCount, equals(10), reason: 'exactly C must match the 10 Colorless cards');
    });

    // =========================================================================
    // 3. SEARCH QUERIES, SLD PREFIX MATCHING & PRIMARY BINDER EXCLUSIONS
    // =========================================================================
    test('3.1: Search query case-insensitivity matches identical count across cases', () async {
      await seed250VaultCards();

      // 170 cards named 'Goblin Guide $i'
      final lowerCount = await db.vaultDao.getFilteredItemCount('mtg', onlyOwned: true, searchQuery: 'goblin');
      final upperCount = await db.vaultDao.getFilteredItemCount('mtg', onlyOwned: true, searchQuery: 'GOBLIN');
      final mixedCount = await db.vaultDao.getFilteredItemCount('mtg', onlyOwned: true, searchQuery: 'GoBlIn GuIdE');

      expect(lowerCount, equals(170));
      expect(upperCount, equals(170));
      expect(mixedCount, equals(170));
    });

    test('3.2: Secret Lair Drop (SLD) prefix matching across aliases', () async {
      await seed250VaultCards();

      // 10 cards seeded with setOrSeries 'SLD', name 'Secret Lair Dragon $i', set 'sld'
      final sldLowerCount = await db.vaultDao.getFilteredItemCount('mtg', onlyOwned: true, searchQuery: 'sld');
      final sldUpperCount = await db.vaultDao.getFilteredItemCount('mtg', onlyOwned: true, searchQuery: 'SLD');
      final secretLairCount = await db.vaultDao.getFilteredItemCount('mtg', onlyOwned: true, searchQuery: 'Secret Lair');

      expect(sldLowerCount, equals(10));
      expect(sldUpperCount, equals(10));
      expect(secretLairCount, equals(10));

      // Verify SLD set code in MtgFilterState as well
      const sldFilter = MtgFilterState(setCode: 'sld', setOperator: '=');
      final sldFilterCount = await db.vaultDao.getFilteredItemCount('mtg', onlyOwned: true, mtgFilter: sldFilter);
      expect(sldFilterCount, equals(10));
    });

    test('3.3: Primary binder exclusion (Staging INBOX guard) and reactivity', () async {
      await seed250VaultCards();

      const exactRed = MtgFilterState(
        colors: {'R'},
        colorMatchMode: ColorMatchMode.exactly,
      );

      // Initially 180 Mono-Red cards
      expect(await db.vaultDao.getFilteredItemCount('mtg', onlyOwned: true, mtgFilter: exactRed), equals(180));

      // Stash stream emissions to verify reactive updates
      final emissions = <int>[];
      final subscription = db.vaultDao.watchFilteredItemCount('mtg', onlyOwned: true, mtgFilter: exactRed).listen(emissions.add);

      // Allow initial stream emission
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(emissions.last, equals(180));

      // 1. Move card 'red_0' to INBOX -> must be excluded from collection count
      await (db.update(db.vaultItems)..where((t) => t.id.equals('red_0'))).write(
        const VaultItemsCompanion(primaryBinderId: Value('INBOX')),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(emissions.last, equals(179), reason: 'Card in INBOX must be excluded from count');
      expect(await db.vaultDao.getFilteredItemCount('mtg', onlyOwned: true, mtgFilter: exactRed), equals(179));

      // 2. Move card 'red_0' out of INBOX into a regular binder -> must be counted again
      await (db.update(db.vaultItems)..where((t) => t.id.equals('red_0'))).write(
        const VaultItemsCompanion(primaryBinderId: Value('binder_trade_1')),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(emissions.last, equals(180), reason: 'Card in regular binder must be included in count');
      expect(await db.vaultDao.getFilteredItemCount('mtg', onlyOwned: true, mtgFilter: exactRed), equals(180));

      // 3. Soft-delete card 'red_1' -> count drops to 179
      await (db.update(db.vaultItems)..where((t) => t.id.equals('red_1'))).write(
        const VaultItemsCompanion(isDeleted: Value(true)),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(emissions.last, equals(179), reason: 'Soft-deleted card must be excluded from count');
      expect(await db.vaultDao.getFilteredItemCount('mtg', onlyOwned: true, mtgFilter: exactRed), equals(179));

      await subscription.cancel();
    });

    // =========================================================================
    // 4. EXPLORE DECK DAO COUNT STRESS TESTING (60 decks seeded)
    // =========================================================================
    test('4.1: ExploreDeckDao total counts and category breakdown across 60 decks', () async {
      await seed60ExploreDecks();

      // Total count
      final totalCount = await exploreDao.getFilteredExploreDeckCount();
      final totalStreamCount = await exploreDao.watchFilteredExploreDeckCount().first;
      expect(totalCount, equals(60));
      expect(totalStreamCount, equals(60));

      // Official category
      final officialCount = await exploreDao.getFilteredExploreDeckCount(category: ExploreCategory.official);
      final officialStreamCount = await exploreDao.watchFilteredExploreDeckCount(category: ExploreCategory.official).first;
      expect(officialCount, equals(30));
      expect(officialStreamCount, equals(30));

      // Community category
      final communityCount = await exploreDao.getFilteredExploreDeckCount(category: ExploreCategory.community);
      final communityStreamCount = await exploreDao.watchFilteredExploreDeckCount(category: ExploreCategory.community).first;
      expect(communityCount, equals(30));
      expect(communityStreamCount, equals(30));
    });

    test('4.2: ExploreDeckDao Format & Price Tier cross-filtering invariant', () async {
      await seed60ExploreDecks();

      // Format: Commander (30 decks total: 15 official, 15 community)
      final commanderTotal = await exploreDao.getFilteredExploreDeckCount(
        filter: const ExploreFilterState(format: 'Commander'),
      );
      expect(commanderTotal, equals(30));

      // Format: Commander split across price ranges (10 in each tier)
      final budgetCommander = await exploreDao.getFilteredExploreDeckCount(
        filter: const ExploreFilterState(format: 'Commander', priceRange: 'budget_0_50'),
      );
      final midCommander = await exploreDao.getFilteredExploreDeckCount(
        filter: const ExploreFilterState(format: 'Commander', priceRange: 'mid_50_200'),
      );
      final highCommander = await exploreDao.getFilteredExploreDeckCount(
        filter: const ExploreFilterState(format: 'Commander', priceRange: 'high_200_plus'),
      );

      expect(budgetCommander, equals(10));
      expect(midCommander, equals(10));
      expect(highCommander, equals(10));
      expect(budgetCommander + midCommander + highCommander, equals(commanderTotal),
          reason: 'Sum of price ranges must equal format total');

      // Format: Standard (15 decks total)
      final standardTotal = await exploreDao.getFilteredExploreDeckCount(
        filter: const ExploreFilterState(format: 'Standard'),
      );
      expect(standardTotal, equals(15));

      // Format: Modern (15 decks total)
      final modernTotal = await exploreDao.getFilteredExploreDeckCount(
        filter: const ExploreFilterState(format: 'Modern'),
      );
      expect(modernTotal, equals(15));
    });

    test('4.3: ExploreDeckDao Color Identity and Match Modes', () async {
      await seed60ExploreDecks();

      // ColorMatchMode: including Red ('R')
      // - Official Commander: 5 (R) + 5 (R,W) + 5 (W,U,B,R,G) = 15
      // - Community Commander: 5 (R) + 5 (R,G) = 10
      // - Community Modern: 5 (R) + 5 (U,R) = 10
      // Total = 35 decks
      final includingRedCount = await exploreDao.getFilteredExploreDeckCount(
        filter: const ExploreFilterState(colors: ['R'], colorMatchMode: 'including'),
      );
      expect(includingRedCount, equals(35));

      // ColorMatchMode: exactly Red ('R')
      // - Official Commander: 5 (R)
      // - Community Commander: 5 (R)
      // - Community Modern: 5 (R)
      // Total = 15 decks
      final exactlyRedCount = await exploreDao.getFilteredExploreDeckCount(
        filter: const ExploreFilterState(colors: ['R'], colorMatchMode: 'exactly'),
      );
      expect(exactlyRedCount, equals(15));
    });

    test('4.4: ExploreDeckDao Contextual Search Pushdown (Deck Name, Creator Name, Card Name in Items)', () async {
      await seed60ExploreDecks();

      // 1. Search by Creator Name
      final creatorCount = await exploreDao.getFilteredExploreDeckCount(
        searchQuery: '@SpicyBrewMaster',
      );
      // 15 community decks have creator '@SpicyBrewMaster'
      expect(creatorCount, equals(15));

      // 2. Search by Card Name in Deck Items (Dockside Extortionist in 2 decks)
      final docksideCount = await exploreDao.getFilteredExploreDeckCount(
        searchQuery: 'Dockside Extortionist',
      );
      expect(docksideCount, equals(2));

      // 3. Search by Card Name in Deck Items (Ragavan in 1 deck)
      final ragavanCount = await exploreDao.getFilteredExploreDeckCount(
        searchQuery: 'Ragavan',
      );
      expect(ragavanCount, equals(1));

      // 4. Card inclusion filter field
      final cardInclusionCount = await exploreDao.getFilteredExploreDeckCount(
        filter: const ExploreFilterState(cardInclusion: 'Dockside'),
      );
      expect(cardInclusionCount, equals(2));
    });

    test('4.5: ExploreDeckDao Stream Reactivity upon mutations and soft deletions', () async {
      await seed60ExploreDecks();

      final emissions = <int>[];
      final subscription = exploreDao.watchFilteredExploreDeckCount().listen(emissions.add);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(emissions.last, equals(60));

      // Soft delete a deck
      await (db.update(db.exploreDecks)..where((t) => t.id.equals('official_deck_0'))).write(
        const ExploreDecksCompanion(isDeleted: Value(true)),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(emissions.last, equals(59), reason: 'Stream must reactively decrement on soft deletion');

      // Insert a new deck
      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: 'new_deck_999',
          name: 'Extra Deck',
          format: 'Commander',
          createdAt: DateTime.now(),
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(emissions.last, equals(60), reason: 'Stream must reactively increment on insertion');

      await subscription.cancel();
    });

    // =========================================================================
    // 5. RIVERPOD PROVIDERS INTEGRATION & INVARIANTS
    // =========================================================================
    test('5.1: vaultFilteredItemCountProvider reactively streams database count to UI layer', () async {
      await seed250VaultCards();

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          vaultDaoProvider.overrideWithValue(db.vaultDao),
          activeGameContextProvider.overrideWith((ref) => 'mtg'),
          vaultShowCatalogProvider.overrideWith((ref) => false), // onlyOwned = true
        ],
      );
      addTearDown(container.dispose);

      // Initially no filter: 250 cards
      var count = await container.read(vaultFilteredItemCountProvider.future);
      expect(count, equals(250));

      // Mutate MTG filter to Red Exactly
      container.read(mtgFilterProvider.notifier).state = const MtgFilterState(
        colors: {'R'},
        colorMatchMode: ColorMatchMode.exactly,
      );

      count = await container.read(vaultFilteredItemCountProvider.future);
      expect(count, equals(180), reason: 'Provider must update reactively to 180 Mono-Red cards');

      // Mutate Search Query to 'Secret Lair'
      container.read(vaultSearchQueryProvider.notifier).state = 'Secret Lair';
      count = await container.read(vaultFilteredItemCountProvider.future);
      expect(count, equals(10), reason: 'Provider must update reactively to 10 SLD cards');
    });

    test('5.2: exploreFilteredDeckCountProvider reactively streams database count to UI layer', () async {
      await seed60ExploreDecks();

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          exploreDeckDaoProvider.overrideWithValue(exploreDao),
          activeExploreCategoryProvider.overrideWith((ref) => ExploreCategory.all),
        ],
      );
      addTearDown(container.dispose);

      // Initially all decks: 60
      var count = await container.read(exploreFilteredDeckCountProvider.future);
      expect(count, equals(60));

      // Switch category to Official
      container.read(activeExploreCategoryProvider.notifier).state = ExploreCategory.official;
      count = await container.read(exploreFilteredDeckCountProvider.future);
      expect(count, equals(30));

      // Switch category to Community
      container.read(activeExploreCategoryProvider.notifier).state = ExploreCategory.community;
      count = await container.read(exploreFilteredDeckCountProvider.future);
      expect(count, equals(30));

      // Apply format filter Commander
      container.read(exploreFilterStateProvider.notifier).state = const ExploreFilterState(format: 'Commander');
      count = await container.read(exploreFilteredDeckCountProvider.future);
      expect(count, equals(15), reason: '15 Community Commander decks');
    });
  });
}
