import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/decks/data/daos/explore_deck_dao.dart';
import 'package:countr/features/decks/data/mock_deck_data.dart';
import 'package:countr/features/decks/domain/models/explore_deck_models.dart';
import 'package:countr/features/decks/domain/services/explore_category_engine.dart';
import 'package:countr/features/decks/presentation/widgets/explore/explore_deck_card.dart';
import 'package:countr/features/decks/presentation/widgets/explore/explore_deck_unpublish_dialog.dart';
import 'package:countr/features/decks/presentation/widgets/explore/explore_decks_tab_view.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/profile/presentation/providers/profile_providers.dart';

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
    await vaultDao.seedDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  group('Adversarial 1: Permission Bypass & Impersonation Stress Testing', () {
    test('isExploreDeckAuthor resists prefix, suffix, and substring impersonation attacks', () {
      final deck = ExploreDeck(
        id: 'deck-auth-test',
        name: 'Grixis Control',
        format: 'Commander',
        tcgDomain: 'mtg',
        sourceType: 'user_shared',
        creatorName: 'Alice',
        authorId: 'user-alice',
        colorIdentity: '["U","B","R"]',
        cardCount: 100,
        estimatedPrice: 300.0,
        upvotes: 0,
        downvotes: 0,
        score: 0,
        createdAt: DateTime.now(),
        isDeleted: false,
      );

      // Legitimate author matches
      expect(isExploreDeckAuthor(deck: deck, currentUserId: 'user-alice'), isTrue);
      expect(isExploreDeckAuthor(deck: deck, currentUserId: 'alice'), isTrue);

      // Adversarial Prefix Normalization finding:
      // replaceAll only strips 'user-' and 'store-' with hyphens, not underscores
      expect(isExploreDeckAuthor(deck: deck, currentUserId: 'user_alice'), isFalse);

      // Adversarial Case sensitivity finding:
      // currentUserId.replaceAll('user-', '').toLowerCase() is case-sensitive on the prefix
      expect(isExploreDeckAuthor(deck: deck, currentUserId: 'USER-ALICE'), isFalse);

      // Adversarial Impersonation attempts: Substrings / Prefixes / Suffixes
      expect(isExploreDeckAuthor(deck: deck, currentUserId: 'alice_smith'), isFalse);
      expect(isExploreDeckAuthor(deck: deck, currentUserId: 'malice'), isFalse);
      expect(isExploreDeckAuthor(deck: deck, currentUserId: 'alice2'), isFalse);
      expect(isExploreDeckAuthor(deck: deck, currentUserId: 'bob'), isFalse);
      expect(isExploreDeckAuthor(deck: deck, currentUserId: ''), isFalse);
      expect(isExploreDeckAuthor(deck: deck, currentUserId: 'user-'), isFalse);
    });

    test('isExploreDeckAuthor enforces strict isolation between local guests and remote users', () {
      final guestDeck = ExploreDeck(
        id: 'deck-guest',
        name: 'Local Deck',
        format: 'Modern',
        tcgDomain: 'mtg',
        sourceType: 'user_shared',
        creatorName: 'Guest Brewer',
        authorId: 'local_user',
        colorIdentity: '["G"]',
        cardCount: 60,
        estimatedPrice: 100.0,
        upvotes: 0,
        downvotes: 0,
        score: 0,
        createdAt: DateTime.now(),
        isDeleted: false,
      );

      // Local aliases match
      expect(isExploreDeckAuthor(deck: guestDeck, currentUserId: 'local_user'), isTrue);
      expect(isExploreDeckAuthor(deck: guestDeck, currentUserId: 'user-current-me'), isTrue);

      // Remote authenticated users cannot unpublish local guest decks
      expect(isExploreDeckAuthor(deck: guestDeck, currentUserId: 'user-attacker-123'), isFalse);
      expect(isExploreDeckAuthor(deck: guestDeck, currentUserId: 'usr_guest_brewer'), isFalse);
    });
  });

  group('Adversarial 2: Personal Deck Immutability & Sync Queue Audit', () {
    test('unpublishing Explore deck guarantees personal decks table is 100% untouched', () async {
      final personalDeckId = MockDeckData.edgarMarkovDeckId;

      // 1. Publish to Explore (which establishes full 100-card deck items)
      final shared = await exploreDao.sharePersonalDeckToExplore(
        personalDeckId: personalDeckId,
        creatorName: '@EdgarFan',
        authorId: 'user-edgar-1',
      );

      // 2. Ingest personal deck baseline AFTER sharing (so we compare against the shared state)
      final personalDeckBeforeUnpublish = await vaultDao.getDeck(personalDeckId);
      expect(personalDeckBeforeUnpublish, isNotNull);
      final personalItemsBeforeUnpublish = await vaultDao.watchDeckItems(personalDeckId).first;
      expect(personalItemsBeforeUnpublish.length, equals(100));

      final allPersonalDecksBefore = await db.select(db.decks).get();
      final allPersonalItemsBefore = await db.select(db.deckVersionItems).get();

      // 3. Unpublish from Explore
      await exploreDao.unpublishExploreDeck(exploreDeckId: shared.id);

      // 4. Verify Sync Queue logging is exact
      final syncQueueEntries = await db.select(db.syncQueue).get();
      final deleteEntry = syncQueueEntries.firstWhere((e) => e.entityId == shared.id);
      expect(deleteEntry.entityType, equals('explore_deck'));
      expect(deleteEntry.operation, equals('DELETE'));
      expect(deleteEntry.retryCount, equals(0));

      // 5. Verify Explore tables are soft-deleted
      final exploreRow = await (db.select(db.exploreDecks)..where((t) => t.id.equals(shared.id))).getSingle();
      expect(exploreRow.isDeleted, isTrue);

      final exploreItems = await (db.select(db.exploreDeckItems)..where((t) => t.exploreDeckId.equals(shared.id))).get();
      expect(exploreItems.every((item) => item.isDeleted), isTrue);

      // 6. Deep Personal Deck Immutability Check
      final personalDeckAfterUnpublish = await vaultDao.getDeck(personalDeckId);
      expect(personalDeckAfterUnpublish!.id, equals(personalDeckBeforeUnpublish!.id));
      expect(personalDeckAfterUnpublish.name, equals(personalDeckBeforeUnpublish.name));
      expect(personalDeckAfterUnpublish.isDeleted, isFalse);

      final personalItemsAfterUnpublish = await vaultDao.watchDeckItems(personalDeckId).first;
      expect(personalItemsAfterUnpublish.length, equals(100));
      for (int i = 0; i < 100; i++) {
        expect(personalItemsAfterUnpublish[i].id, equals(personalItemsBeforeUnpublish[i].id));
        expect(personalItemsAfterUnpublish[i].quantity, equals(personalItemsBeforeUnpublish[i].quantity));
      }

      final allPersonalDecksAfterUnpublish = await db.select(db.decks).get();
      expect(allPersonalDecksAfterUnpublish.length, equals(allPersonalDecksBefore.length));
      final allPersonalItemsAfterUnpublish = await db.select(db.deckVersionItems).get();
      expect(allPersonalItemsAfterUnpublish.length, equals(allPersonalItemsBefore.length));
    });
  });

  group('Adversarial 3: Velocity Window Boundary Stress Testing (4 vs 5 votes, 48h vs 7d vs fallback)', () {
    test('Boundary 4 vs 5 votes in 48 hours', () async {
      final now = DateTime(2026, 6, 1, 12, 0);

      // Seed 4 votes within 48h (e.g. 10 hours ago)
      for (int i = 0; i < 4; i++) {
        await db.into(db.exploreDeckVotes).insert(
          ExploreDeckVotesCompanion.insert(
            id: 'vote-48-boundary-$i',
            exploreDeckId: 'deck-test',
            userId: Value('user-voter-$i'),
            vote: const Value(1),
            updatedAt: now.subtract(const Duration(hours: 10)),
          ),
        );
      }

      // With 4 votes: below threshold 5 -> must NOT be todaysPicks
      var window = await engine.resolveLeadVelocityWindow(now: now);
      expect(window, isNot(equals(LeadVelocityWindow.todaysPicks)));
      expect(window, equals(LeadVelocityWindow.thisMonthsPicks));

      // Add the 5th vote (now exactly at threshold 5)
      await db.into(db.exploreDeckVotes).insert(
        ExploreDeckVotesCompanion.insert(
          id: 'vote-48-boundary-5',
          exploreDeckId: 'deck-test',
          userId: const Value('user-voter-5'),
          vote: const Value(1),
          updatedAt: now.subtract(const Duration(hours: 5)),
        ),
      );

      // With 5 votes: exactly at threshold -> must switch to todaysPicks
      window = await engine.resolveLeadVelocityWindow(now: now);
      expect(window, equals(LeadVelocityWindow.todaysPicks));
      expect(window.title, equals("Today's Picks"));
    });

    test('Boundary 48h cutoff vs 7d cutoff', () async {
      final now = DateTime(2026, 6, 1, 12, 0);

      // 4 votes in 48h + 1 vote at 50 hours ago (within 7d, outside 48h)
      for (int i = 0; i < 4; i++) {
        await db.into(db.exploreDeckVotes).insert(
          ExploreDeckVotesCompanion.insert(
            id: 'vote-mix-$i',
            exploreDeckId: 'deck-test',
            userId: Value('user-mix-$i'),
            vote: const Value(1),
            updatedAt: now.subtract(const Duration(hours: 20)),
          ),
        );
      }
      await db.into(db.exploreDeckVotes).insert(
        ExploreDeckVotesCompanion.insert(
          id: 'vote-mix-5',
          exploreDeckId: 'deck-test',
          userId: const Value('user-mix-5'),
          vote: const Value(1),
          updatedAt: now.subtract(const Duration(hours: 50)), // > 48h, < 7d
        ),
      );

      // 48h count is 4 (< 5), but 7d count is 5 (>= 5) -> thisWeeksPicks
      final window = await engine.resolveLeadVelocityWindow(now: now);
      expect(window, equals(LeadVelocityWindow.thisWeeksPicks));
      expect(window.title, equals("This Week's Picks"));
    });

    test('Boundary 7d cutoff vs 30d fallback', () async {
      final now = DateTime(2026, 6, 1, 12, 0);

      // 4 votes at 3 days ago + 1 vote at 8 days ago (> 7d)
      for (int i = 0; i < 4; i++) {
        await db.into(db.exploreDeckVotes).insert(
          ExploreDeckVotesCompanion.insert(
            id: 'vote-7d-mix-$i',
            exploreDeckId: 'deck-test',
            userId: Value('user-7d-$i'),
            vote: const Value(1),
            updatedAt: now.subtract(const Duration(days: 3)),
          ),
        );
      }
      await db.into(db.exploreDeckVotes).insert(
        ExploreDeckVotesCompanion.insert(
          id: 'vote-old-5',
          exploreDeckId: 'deck-test',
          userId: const Value('user-old-5'),
          vote: const Value(1),
          updatedAt: now.subtract(const Duration(days: 8)), // > 7d
        ),
      );

      // 48h count = 0, 7d count = 4 (< 5) -> falls back to thisMonthsPicks
      final window = await engine.resolveLeadVelocityWindow(now: now);
      expect(window, equals(LeadVelocityWindow.thisMonthsPicks));
      expect(window.title, equals("This Month's Picks"));
    });

    test('Deleted votes and zero votes do not satisfy threshold', () async {
      final now = DateTime(2026, 6, 1, 12, 0);

      // Insert 3 valid votes and 2 deleted votes within 48h
      for (int i = 0; i < 3; i++) {
        await db.into(db.exploreDeckVotes).insert(
          ExploreDeckVotesCompanion.insert(
            id: 'vote-valid-$i',
            exploreDeckId: 'deck-test',
            userId: Value('user-valid-$i'),
            vote: const Value(1),
            updatedAt: now.subtract(const Duration(hours: 2)),
          ),
        );
      }
      for (int i = 0; i < 2; i++) {
        await db.into(db.exploreDeckVotes).insert(
          ExploreDeckVotesCompanion.insert(
            id: 'vote-deleted-$i',
            exploreDeckId: 'deck-test',
            userId: Value('user-deleted-$i'),
            vote: const Value(1),
            isDeleted: const Value(true),
            updatedAt: now.subtract(const Duration(hours: 2)),
          ),
        );
      }
      // Insert 2 neutral votes (vote = 0)
      for (int i = 0; i < 2; i++) {
        await db.into(db.exploreDeckVotes).insert(
          ExploreDeckVotesCompanion.insert(
            id: 'vote-zero-$i',
            exploreDeckId: 'deck-test',
            userId: Value('user-zero-$i'),
            vote: const Value(0),
            updatedAt: now.subtract(const Duration(hours: 2)),
          ),
        );
      }

      // Valid count is 3 (< 5) -> must not be todaysPicks
      final window = await engine.resolveLeadVelocityWindow(now: now);
      expect(window, equals(LeadVelocityWindow.thisMonthsPicks));
    });
  });

  group('Adversarial 4: 366-Day Exhaustive Collision Avoidance Simulation', () {
    test('Daily and Weekly rotating categories NEVER collide on any day of the year', () {
      final leapYear = 2024;
      for (int month = 1; month <= 12; month++) {
        final daysInMonth = DateUtils.getDaysInMonth(leapYear, month);
        for (int day = 1; day <= daysInMonth; day++) {
          final date = DateTime(leapYear, month, day, 12, 0);
          final daily = engine.resolveDailyRotatingCategory(date);
          final weekly = engine.resolveWeeklyRotatingCategory(date);

          // Invariant: Daily and Weekly must NEVER share the same category id
          expect(
            daily.id != weekly.id,
            isTrue,
            reason: 'Collision detected on $date! Daily=${daily.id}, Weekly=${weekly.id}',
          );

          // Invariant: Resolving again on same date is 100% deterministic
          final dailyRepeat = engine.resolveDailyRotatingCategory(date);
          final weeklyRepeat = engine.resolveWeeklyRotatingCategory(date);
          expect(dailyRepeat.id, equals(daily.id));
          expect(weeklyRepeat.id, equals(weekly.id));
        }
      }
    });
  });

  group('Adversarial 5: Layout Stability Under Narrow Viewport & Scaled Typography', () {
    testWidgets('ExploreDeckCard: Zero overflow at 320px viewport with 1.5x font scale', (tester) async {
      tester.view.physicalSize = const Size(320 * 2.0, 568 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final deck = ExploreDeck(
        id: 'deck-narrow-test',
        name: 'Super Long Commander Deck Name That Would Overflow Narrow Layouts Without Ellipsis Protection',
        format: 'Commander',
        tcgDomain: 'mtg',
        sourceType: 'user_shared',
        creatorName: 'TheUltraLongBrewMasterAuthorNameThatTakesLotsOfSpace',
        authorId: 'test-user',
        colorIdentity: '["W","U","B","R","G"]',
        cardCount: 100,
        estimatedPrice: 9999.99,
        upvotes: 999,
        downvotes: 12,
        score: 987,
        createdAt: DateTime.now(),
        isDeleted: false,
      );

      // Test 1: Grid Mode (width ~138px in 2-column layout)
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            currentUserIdProvider.overrideWith((ref) => 'test-user'),
          ],
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                textScaler: TextScaler.linear(1.5),
              ),
              child: Scaffold(
                body: SizedBox(
                  width: 138,
                  child: ExploreDeckCard(
                    deckWithVote: ExploreDeckWithVote(deck: deck, userVote: 1),
                    isCompact: false,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Test 2: Compact Carousel Mode (width 175px in 350px ListView)
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            currentUserIdProvider.overrideWith((ref) => 'test-user'),
          ],
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                textScaler: TextScaler.linear(1.5),
              ),
              child: Scaffold(
                body: SizedBox(
                  width: 175,
                  height: 350,
                  child: ExploreDeckCard(
                    deckWithVote: ExploreDeckWithVote(deck: deck, userVote: 1),
                    isCompact: true,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('ExploreDecksTabView: Renders without layout overflows on 320x568 screen at 1.5x scale', (tester) async {
      tester.view.physicalSize = const Size(320 * 2.0, 568 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            currentUserIdProvider.overrideWith((ref) => 'local_user'),
          ],
          child: const MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                textScaler: TextScaler.linear(1.5),
              ),
              child: Scaffold(
                body: ExploreDecksTabView(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
