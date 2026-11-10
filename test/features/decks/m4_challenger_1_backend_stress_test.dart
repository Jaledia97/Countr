import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:uuid/uuid.dart';

import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/decks/data/daos/explore_deck_dao.dart';
import 'package:countr/features/decks/data/mock_deck_data.dart';
import 'package:countr/features/decks/domain/services/explore_category_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late VaultDao vaultDao;
  late ExploreDeckDao exploreDao;
  late ExploreCategoryEngine engine;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    vaultDao = VaultDao(db);
    exploreDao = ExploreDeckDao(db);
    engine = ExploreCategoryEngine(exploreDao, velocityThreshold: 5);

    // Seed starter data (includes 100-card Edgar Markov commander deck)
    await vaultDao.seedDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  // ===========================================================================
  // 1. REPEATED UNPUBLISH CALLS (IDEMPOTENCE) & SYNC QUEUE RECORDING
  // ===========================================================================
  group('Challenger Stress 1: Repeated Unpublish Idempotence & Sync Queue', () {
    test('Single unpublish records exactly 1 DELETE mutation in sync_queue for explore_deck', () async {
      final personalDeckId = MockDeckData.edgarMarkovDeckId;
      final shared = await exploreDao.sharePersonalDeckToExplore(
        personalDeckId: personalDeckId,
        creatorName: '@EdgarChallenger',
        authorId: 'user-edgar-stress',
      );

      // Verify sync_queue before unpublish
      final syncBefore = await (db.select(db.syncQueue)
            ..where((t) => t.entityId.equals(shared.id)))
          .get();
      expect(syncBefore, isEmpty);

      // Execute single unpublish
      await exploreDao.unpublishExploreDeck(exploreDeckId: shared.id);

      // Assert sync_queue contains EXACTLY 1 DELETE mutation
      final syncAfter = await (db.select(db.syncQueue)
            ..where((t) => t.entityId.equals(shared.id)))
          .get();
      expect(syncAfter.length, equals(1));
      expect(syncAfter.first.entityType, equals('explore_deck'));
      expect(syncAfter.first.operation, equals('DELETE'));
      expect(syncAfter.first.retryCount, equals(0));
    });

    test('Repeated sequential unpublish calls (5x) are completely safe, non-corrupting, and maintain soft-delete state', () async {
      final personalDeckId = MockDeckData.edgarMarkovDeckId;
      final shared = await exploreDao.sharePersonalDeckToExplore(
        personalDeckId: personalDeckId,
        creatorName: '@EdgarChallenger',
        authorId: 'user-edgar-stress',
      );

      // First unpublish call
      await exploreDao.unpublishExploreDeck(exploreDeckId: shared.id);

      final deckAfter1 = await (db.select(db.exploreDecks)
            ..where((t) => t.id.equals(shared.id)))
          .getSingle();
      expect(deckAfter1.isDeleted, isTrue);

      final itemsAfter1 = await (db.select(db.exploreDeckItems)
            ..where((t) => t.exploreDeckId.equals(shared.id)))
          .get();
      expect(itemsAfter1.every((item) => item.isDeleted == true), isTrue);

      // Perform 4 subsequent unpublish calls on the already-unpublished deck
      for (int i = 2; i <= 5; i++) {
        await expectLater(
          exploreDao.unpublishExploreDeck(exploreDeckId: shared.id),
          completes,
          reason: 'Unpublish call #$i must complete safely without error',
        );
      }

      // Assert database integrity after 5 repeated calls
      final rawDeck = await (db.select(db.exploreDecks)
            ..where((t) => t.id.equals(shared.id)))
          .getSingle();
      expect(rawDeck.isDeleted, isTrue);

      final rawItems = await (db.select(db.exploreDeckItems)
            ..where((t) => t.exploreDeckId.equals(shared.id)))
          .get();
      expect(rawItems.length, equals(100));
      expect(rawItems.every((item) => item.isDeleted == true), isTrue);

      // Feed queries must return null / empty
      final feed = await exploreDao.watchExploreDecks().first;
      expect(feed.any((d) => d.id == shared.id), isFalse);

      final deckCheck = await exploreDao.getExploreDeck(shared.id);
      expect(deckCheck, isNull);

      // Personal deck must remain completely intact throughout repeated calls
      final personal = await vaultDao.getDeck(personalDeckId);
      expect(personal, isNotNull);
      expect(personal!.isDeleted, isFalse);
    });

    test('Unpublishing non-existent explore deck ID completes safely without throwing', () async {
      const nonExistentId = 'deck-uuid-does-not-exist-999';
      await expectLater(
        exploreDao.unpublishExploreDeck(exploreDeckId: nonExistentId),
        completes,
      );
    });
  });

  // ===========================================================================
  // 2. 100+ CARD UNPUBLISH SOFT-DELETION STRESS
  // ===========================================================================
  group('Challenger Stress 2: 100+ Card Deck Unpublish Soft-Deletion', () {
    test('100-card Commander deck unpublish marks 100% of items as is_deleted = true with 0 survivors', () async {
      final personalDeckId = MockDeckData.edgarMarkovDeckId;
      final shared = await exploreDao.sharePersonalDeckToExplore(
        personalDeckId: personalDeckId,
        creatorName: '@Edgar100',
        authorId: 'user-100-cards',
      );

      // Verify 100 items exist in explore_deck_items
      final initialItems = await (db.select(db.exploreDeckItems)
            ..where((t) => t.exploreDeckId.equals(shared.id)))
          .get();
      expect(initialItems.length, equals(100));
      expect(initialItems.every((item) => item.isDeleted == false), isTrue);

      // Execute unpublish
      await exploreDao.unpublishExploreDeck(exploreDeckId: shared.id);

      // Assert all 100 items are soft-deleted
      final softDeletedItems = await (db.select(db.exploreDeckItems)
            ..where((t) => t.exploreDeckId.equals(shared.id)))
          .get();
      expect(softDeletedItems.length, equals(100));

      final deletedCount = softDeletedItems.where((i) => i.isDeleted == true).length;
      final survivorCount = softDeletedItems.where((i) => i.isDeleted == false).length;

      expect(deletedCount, equals(100), reason: 'All 100 items must be marked isDeleted = true');
      expect(survivorCount, equals(0), reason: 'Zero items may survive with isDeleted = false');

      // Assert parent explore_decks row is soft-deleted
      final parentDeck = await (db.select(db.exploreDecks)
            ..where((t) => t.id.equals(shared.id)))
          .getSingle();
      expect(parentDeck.isDeleted, isTrue);

      // Assert sync_queue records exactly 1 DELETE mutation (not 101 mutations)
      final syncQueueItems = await (db.select(db.syncQueue)
            ..where((t) => t.entityId.equals(shared.id)))
          .get();
      expect(syncQueueItems.length, equals(1));
    });

    test('125-card stress deck (100 mainboard + 15 sideboard + 10 maybeboard) soft-deletes all 125 items', () async {
      final now = DateTime.now();
      final customDeckId = const Uuid().v4();
      final customVersionId = const Uuid().v4();

      // 1. Create personal deck with 125 distinct card items
      await db.into(db.decks).insert(
        DecksCompanion.insert(
          id: customDeckId,
          name: 'Stress Test Massive Deck 125',
          format: 'Commander',
          createdAt: now,
          updatedAt: Value(now),
          isDeleted: const Value(false),
        ),
      );

      await db.into(db.deckVersions).insert(
        DeckVersionsCompanion.insert(
          id: customVersionId,
          deckId: customDeckId,
          versionNumber: 1,
          createdAt: now,
          updatedAt: Value(now),
        ),
      );

      // Insert 125 vault items and 125 card version items
      for (int i = 0; i < 125; i++) {
        final vId = 'vault-stress-$i';
        await db.into(db.vaultItems).insert(
          VaultItemsCompanion.insert(
            id: vId,
            collectionType: 'mtg',
            name: 'Stress Test Card #$i',
            setOrSeries: 'STR',
            imageUrl: 'https://example.com/card_$i.jpg',
            acquiredPrice: 1.0,
            acquiredDate: now,
            condition: 'NM',
            currentMarketPrice: 1.0,
            lastPriceUpdate: now,
            dynamicData: '{"name": "Stress Test Card #$i", "mana_cost": "{1}", "cmc": 1.0, "type_line": "Creature", "prices": {"usd": "1.00"}}',
          ),
        );

        final zone = i < 100 ? 'Mainboard' : (i < 115 ? 'Sideboard' : 'Maybeboard');
        await db.into(db.deckVersionItems).insert(
          DeckVersionItemsCompanion.insert(
            id: 'dvi-stress-$i',
            versionId: customVersionId,
            vaultItemId: vId,
            quantity: const Value(1),
            boardZone: zone,
            isProxy: const Value(false),
            isDeleted: const Value(false),
            updatedAt: Value(now),
          ),
        );
      }

      // 2. Share to Explore
      final shared = await exploreDao.sharePersonalDeckToExplore(
        personalDeckId: customDeckId,
        creatorName: '@StressTester',
        authorId: 'stress-user-125',
      );

      // Verify 125 items inserted into explore_deck_items
      final exploreItemsBefore = await (db.select(db.exploreDeckItems)
            ..where((t) => t.exploreDeckId.equals(shared.id)))
          .get();
      expect(exploreItemsBefore.length, equals(125));

      // 3. Unpublish from Explore
      await exploreDao.unpublishExploreDeck(exploreDeckId: shared.id);

      // 4. Verify all 125 items marked is_deleted = true
      final exploreItemsAfter = await (db.select(db.exploreDeckItems)
            ..where((t) => t.exploreDeckId.equals(shared.id)))
          .get();
      expect(exploreItemsAfter.length, equals(125));
      expect(exploreItemsAfter.every((item) => item.isDeleted == true), isTrue);

      // 5. Verify personal deck still has all 125 items active (is_deleted = false)
      final personalItemsAfter = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals(customVersionId)))
          .get();
      expect(personalItemsAfter.length, equals(125));
      expect(personalItemsAfter.every((item) => item.isDeleted == false), isTrue);
    });
  });

  // ===========================================================================
  // 3. PERSONAL DECK PRESERVATION INVARIANT (DECKS & DECK_VERSION_ITEMS)
  // ===========================================================================
  group('Challenger Stress 3: Personal Deck Preservation Invariant', () {
    test('Personal deck in decks and deck_version_items remains 100% byte-for-byte and item-for-item intact', () async {
      final personalDeckId = MockDeckData.edgarMarkovDeckId;

      // 1. Share Edgar Markov deck to Explore (populates 100 items if needed)
      final shared = await exploreDao.sharePersonalDeckToExplore(
        personalDeckId: personalDeckId,
        creatorName: '@EdgarPreserve',
        authorId: 'user-preserve-test',
      );

      // 2. Snapshot personal deck in `decks` and all 100 cards in `deck_version_items`
      final deckBefore = await (db.select(db.decks)
            ..where((t) => t.id.equals(personalDeckId)))
          .getSingle();

      final activeVersion = await (db.select(db.deckVersions)
            ..where((t) => t.deckId.equals(personalDeckId) & t.isActive.equals(true)))
          .getSingle();

      final personalItemsBefore = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals(activeVersion.id)))
          .get();
      expect(personalItemsBefore.length, equals(100));

      // Map personal card quantities and zones by id
      final itemMapBefore = {
        for (final item in personalItemsBefore)
          item.id: {
            'vaultItemId': item.vaultItemId,
            'quantity': item.quantity,
            'boardZone': item.boardZone,
            'isProxy': item.isProxy,
            'isDeleted': item.isDeleted,
          }
      };

      // 3. Unpublish from Explore
      await exploreDao.unpublishExploreDeck(exploreDeckId: shared.id);

      // 4. Assert personal deck row in `decks` has zero mutations
      final deckAfter = await (db.select(db.decks)
            ..where((t) => t.id.equals(personalDeckId)))
          .getSingle();

      expect(deckAfter.id, equals(deckBefore.id));
      expect(deckAfter.name, equals(deckBefore.name));
      expect(deckAfter.format, equals(deckBefore.format));
      expect(deckAfter.coverItemId, equals(deckBefore.coverItemId));
      expect(deckAfter.isDeleted, isFalse);
      expect(deckAfter.isDeleted, equals(deckBefore.isDeleted));
      expect(deckAfter.description, equals(deckBefore.description));
      expect(deckAfter.tcgDomain, equals(deckBefore.tcgDomain));

      // 5. Assert all rows in `deck_version_items` remain identical
      final personalItemsAfter = await (db.select(db.deckVersionItems)
            ..where((t) => t.versionId.equals(activeVersion.id)))
          .get();

      expect(personalItemsAfter.length, equals(100));
      for (final item in personalItemsAfter) {
        final expected = itemMapBefore[item.id]!;
        expect(item.vaultItemId, equals(expected['vaultItemId']));
        expect(item.quantity, equals(expected['quantity']));
        expect(item.boardZone, equals(expected['boardZone']));
        expect(item.isProxy, equals(expected['isProxy']));
        expect(item.isDeleted, isFalse);
      }
    });
  });

  // ===========================================================================
  // 4. 100+ VOTE VELOCITY TIMESTAMP STRESS ACROSS 48H AND 7D CUTOFF BOUNDARIES
  // ===========================================================================
  group('Challenger Stress 4: 100+ Vote Velocity Timestamp Boundaries', () {
    test('120 votes distributed across 48h boundary: switches from Todays Picks to This Weeks Picks upon clock advance', () async {
      final now = DateTime(2026, 6, 15, 12, 0, 0);
      const deckId = 'velocity_test_deck_1';

      // Insert test explore deck
      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: deckId,
          name: 'Velocity Test Deck',
          format: 'Commander',
          createdAt: now.subtract(const Duration(days: 30)),
          isDeleted: const Value(false),
        ),
      );

      // Simulate 120 total votes:
      // - 60 votes inside the 48h window (at now - 47h 59m)
      // - 60 votes outside the 48h window but inside 7d (at now - 48h 01m)
      for (int i = 0; i < 60; i++) {
        await db.into(db.exploreDeckVotes).insert(
          ExploreDeckVotesCompanion.insert(
            id: 'vote-fresh-$i',
            exploreDeckId: deckId,
            userId: Value('user-fresh-$i'),
            vote: const Value(1),
            updatedAt: now.subtract(const Duration(hours: 47, minutes: 59)),
          ),
        );
      }

      for (int i = 0; i < 60; i++) {
        await db.into(db.exploreDeckVotes).insert(
          ExploreDeckVotesCompanion.insert(
            id: 'vote-older-$i',
            exploreDeckId: deckId,
            userId: Value('user-older-$i'),
            vote: const Value(1),
            updatedAt: now.subtract(const Duration(hours: 48, minutes: 1)),
          ),
        );
      }

      // Total votes in 48h is 60. Total votes in 7d is 120.
      // With threshold = 50:
      // At `now`: 48h count (60) >= 50 -> "Today's Picks"
      final windowAtNow = await engine.resolveLeadVelocityWindow(
        now: now,
        customThreshold: 50,
      );
      expect(windowAtNow, equals(LeadVelocityWindow.todaysPicks));
      expect(windowAtNow.title, equals("Today's Picks"));

      // Advance clock by 2 minutes:
      // The 60 fresh votes are now at `now + 2m - 47h 59m` = `48h 01m` ago (outside 48h!).
      // 48h count drops to 0 (< 50).
      // 7d count is still 120 (>= 50).
      // Must dynamically switch to "This Week's Picks"!
      final advancedClock = now.add(const Duration(minutes: 2));
      final windowAfterAdvance = await engine.resolveLeadVelocityWindow(
        now: advancedClock,
        customThreshold: 50,
      );
      expect(windowAfterAdvance, equals(LeadVelocityWindow.thisWeeksPicks));
      expect(windowAfterAdvance.title, equals("This Week's Picks"));
    });

    test('100 votes distributed across 7d boundary: switches from This Weeks Picks to This Months Picks upon clock advance', () async {
      final now = DateTime(2026, 6, 15, 12, 0, 0);
      const deckId = 'velocity_test_deck_2';

      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: deckId,
          name: 'Velocity 7D Test Deck',
          format: 'Commander',
          createdAt: now.subtract(const Duration(days: 30)),
          isDeleted: const Value(false),
        ),
      );

      // Simulate 100 votes:
      // - 50 votes at now - 6d 23h 59m (inside 7d window, outside 48h)
      // - 50 votes at now - 7d 00h 02m (outside 7d window)
      for (int i = 0; i < 50; i++) {
        await db.into(db.exploreDeckVotes).insert(
          ExploreDeckVotesCompanion.insert(
            id: 'vote-7d-in-$i',
            exploreDeckId: deckId,
            userId: Value('user-7d-in-$i'),
            vote: const Value(1),
            updatedAt: now.subtract(const Duration(days: 6, hours: 23, minutes: 59)),
          ),
        );
      }

      for (int i = 0; i < 50; i++) {
        await db.into(db.exploreDeckVotes).insert(
          ExploreDeckVotesCompanion.insert(
            id: 'vote-7d-out-$i',
            exploreDeckId: deckId,
            userId: Value('user-7d-out-$i'),
            vote: const Value(1),
            updatedAt: now.subtract(const Duration(days: 7, minutes: 2)),
          ),
        );
      }

      // At `now`:
      // 48h count = 0 (< 50)
      // 7d count = 50 (>= 50) -> "This Week's Picks"
      final windowAtNow = await engine.resolveLeadVelocityWindow(
        now: now,
        customThreshold: 50,
      );
      expect(windowAtNow, equals(LeadVelocityWindow.thisWeeksPicks));
      expect(windowAtNow.title, equals("This Week's Picks"));

      // Advance clock by 2 minutes:
      // The 50 votes shift to 7d 00h 01m ago (outside 7d!).
      // 7d count drops to 0 (< 50).
      // Must dynamically fall back to "This Month's Picks"!
      final advancedClock = now.add(const Duration(minutes: 2));
      final windowAfterAdvance = await engine.resolveLeadVelocityWindow(
        now: advancedClock,
        customThreshold: 50,
      );
      expect(windowAfterAdvance, equals(LeadVelocityWindow.thisMonthsPicks));
      expect(windowAfterAdvance.title, equals("This Month's Picks"));
    });

    test('150+ high-volume vote velocity ranking across 3 distinct decks with different velocity profiles', () async {
      final now = DateTime(2026, 6, 15, 12, 0, 0);

      // Create 3 explore decks
      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: 'deck-high-velocity',
          name: 'Viral Deck Alpha',
          format: 'Commander',
          createdAt: now.subtract(const Duration(days: 2)),
          score: const Value(10),
          isDeleted: const Value(false),
        ),
      );
      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: 'deck-medium-velocity',
          name: 'Steady Deck Beta',
          format: 'Commander',
          createdAt: now.subtract(const Duration(days: 5)),
          score: const Value(20),
          isDeleted: const Value(false),
        ),
      );
      await db.into(db.exploreDecks).insert(
        ExploreDecksCompanion.insert(
          id: 'deck-old-historical',
          name: 'Historical Deck Gamma',
          format: 'Commander',
          createdAt: now.subtract(const Duration(days: 60)),
          score: const Value(500), // Huge historical score, but 0 recent votes
          isDeleted: const Value(false),
        ),
      );

      // Insert 100 votes into Viral Deck Alpha in the last 12h
      for (int i = 0; i < 100; i++) {
        await db.into(db.exploreDeckVotes).insert(
          ExploreDeckVotesCompanion.insert(
            id: 'alpha-v-$i',
            exploreDeckId: 'deck-high-velocity',
            userId: Value('alpha-user-$i'),
            vote: const Value(1),
            updatedAt: now.subtract(Duration(minutes: i * 5)), // within last 8 hours
          ),
        );
      }

      // Insert 30 votes into Steady Deck Beta in the last 24h
      for (int i = 0; i < 30; i++) {
        await db.into(db.exploreDeckVotes).insert(
          ExploreDeckVotesCompanion.insert(
            id: 'beta-v-$i',
            exploreDeckId: 'deck-medium-velocity',
            userId: Value('beta-user-$i'),
            vote: const Value(1),
            updatedAt: now.subtract(Duration(hours: 12 + i % 10)),
          ),
        );
      }

      // Insert 50 historical votes into Historical Deck Gamma (30 days old)
      for (int i = 0; i < 50; i++) {
        await db.into(db.exploreDeckVotes).insert(
          ExploreDeckVotesCompanion.insert(
            id: 'gamma-v-$i',
            exploreDeckId: 'deck-old-historical',
            userId: Value('gamma-user-$i'),
            vote: const Value(1),
            updatedAt: now.subtract(Duration(days: 25 + i % 5)),
          ),
        );
      }

      // Query vote velocity within 48h
      final cutoff48h = now.subtract(const Duration(hours: 48));
      final rankedDecks = await exploreDao.watchDecksByVoteVelocity(cutoff: cutoff48h).first;

      expect(rankedDecks.isNotEmpty, isTrue);
      // Viral Alpha (100 recent votes) must be ranked #1
      expect(rankedDecks[0].deck.id, equals('deck-high-velocity'));
      // Steady Beta (30 recent votes) must be ranked #2
      expect(rankedDecks[1].deck.id, equals('deck-medium-velocity'));
      // Historical Gamma (0 recent votes) must be ranked below recent velocity decks despite higher base score
      final gammaIndex = rankedDecks.indexWhere((d) => d.deck.id == 'deck-old-historical');
      expect(gammaIndex > 1, isTrue);
    });
  });

  // ===========================================================================
  // 5. 365 DAYS OF DATE-SEEDED DETERMINISTIC ROTATION WITH ZERO COLLISION
  // ===========================================================================
  group('Challenger Stress 5: 365 Days Date Rotation & Zero Collision', () {
    test('All 365 days of 2026 produce non-null valid categories with ZERO collisions between daily and weekly categories', () {
      final startDate = DateTime(2026, 1, 1);
      final validDailyIds = ExploreCategoryEngine.dailyPool.map((c) => c.id).toSet();
      final validWeeklyIds = ExploreCategoryEngine.weeklyPool.map((c) => c.id).toSet();

      int collisionCount = 0;
      int errorCount = 0;

      for (int day = 0; day < 365; day++) {
        final date = startDate.add(Duration(days: day));

        try {
          final daily = engine.resolveDailyRotatingCategory(date);
          final weekly = engine.resolveWeeklyRotatingCategory(date);

          // Verify non-null and valid IDs
          expect(daily, isNotNull, reason: 'Day $day ($date) daily category is null');
          expect(weekly, isNotNull, reason: 'Day $day ($date) weekly category is null');
          expect(validDailyIds.contains(daily.id), isTrue, reason: 'Day $day daily ID ${daily.id} not in pool');
          expect(validWeeklyIds.contains(weekly.id), isTrue, reason: 'Day $day weekly ID ${weekly.id} not in pool');

          // STRESS ASSERTION: Zero collision between daily and weekly category
          if (daily.id == weekly.id) {
            collisionCount++;
          }

          // Assert idempotence: same date always resolves same result
          final dailyRetry = engine.resolveDailyRotatingCategory(date);
          final weeklyRetry = engine.resolveWeeklyRotatingCategory(date);
          expect(dailyRetry.id, equals(daily.id));
          expect(weeklyRetry.id, equals(weekly.id));
        } catch (e) {
          errorCount++;
        }
      }

      expect(errorCount, equals(0), reason: 'Zero errors allowed across all 365 days');
      expect(collisionCount, equals(0), reason: 'Zero collisions allowed between daily and weekly categories across all 365 days');
    });

    test('Leap Year (2028: 366 days) handles Day 366 without out-of-bounds error or collision', () {
      final leapYearDate = DateTime(2028, 12, 31);
      expect(leapYearDate.dayOfYear, equals(366));

      final daily = engine.resolveDailyRotatingCategory(leapYearDate);
      final weekly = engine.resolveWeeklyRotatingCategory(leapYearDate);

      expect(daily, isNotNull);
      expect(weekly, isNotNull);
      expect(daily.id != weekly.id, isTrue, reason: 'Day 366 daily and weekly categories must not collide');
    });

    test('All pool categories are reached across the 365-day calendar cycle (coverage check)', () {
      final hitDaily = <String>{};
      final hitWeekly = <String>{};

      for (int day = 0; day < 365; day++) {
        final date = DateTime(2026, 1, 1).add(Duration(days: day));
        hitDaily.add(engine.resolveDailyRotatingCategory(date).id);
        hitWeekly.add(engine.resolveWeeklyRotatingCategory(date).id);
      }

      // Assert full coverage of every defined category in both pools
      expect(hitDaily.length, equals(ExploreCategoryEngine.dailyPool.length));
      expect(hitWeekly.length, equals(ExploreCategoryEngine.weeklyPool.length));
    });
  });
}
