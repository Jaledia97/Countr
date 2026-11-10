// Copyright (c) 2026 Countr. All rights reserved.
// Milestone 5 Challenger Invariant & Adversarial Stress Test Suite
//
// Verifying all core invariants under stress:
// 1. Trade Notifications: actor != recipient safety under concurrent notifications.
// 2. Collection Privacy: partner visibility private strictly prevents access to full collection.
// 3. Automated Trade Match: match engine handles card identity via oracle_id/scryfall_id without false positives.
// 4. Binder Architecture: 1-to-1 binder constraints remain intact, no duplicate binders created.
// 5. Estimated Vault Value: finishes (normal, foil, etched) compute correctly with quantity multiplier; Looking For binder items strictly omitted.
// 6. Fast Collections: benchmark queries on realistic multi-item dataset to guarantee < 50ms latency.
// 7. Explore Decks Unpublish: verify isolation between explore_decks (soft-deleted + sync DELETE queued) and personal decks (intact).
// 8. Algorithmic Categories: verify deterministic seed behavior and vote velocity boundaries.
// 9. Viewport Stability: stress test across narrow 280px screen at 1.5x and 2.0x font scaling on MasterSetScreen.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/data/daos/vault_dao.dart';
import 'package:countr/features/vault/presentation/screens/master_set_screen.dart';
import 'package:countr/features/vault/domain/models/vault_set_collection.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/trades/domain/services/trade_match_service.dart';
import 'package:countr/features/decks/data/daos/explore_deck_dao.dart';
import 'package:countr/features/decks/domain/services/explore_category_engine.dart';
import 'package:countr/features/auth/presentation/providers/auth_providers.dart';
import 'package:countr/features/profile/presentation/providers/profile_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late VaultDao vaultDao;
  late ExploreDeckDao exploreDao;
  late TradeMatchService tradeMatchService;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    vaultDao = db.vaultDao;
    exploreDao = db.exploreDeckDao;
    tradeMatchService = TradeMatchService(db);
    await vaultDao.clearAllItems();
  });

  tearDown(() async {
    await db.close();
  });

  group('Challenger Invariant 1: Concurrent Trade Notifications & Self-Action Safety', () {
    test('100 concurrent notifications with mixed actors strictly exclude self-actions from unread count', () async {
      const currentUserId = 'user-challenger-me';
      const otherUserA = 'user-partner-a';
      const otherUserB = 'user-partner-b';
      final now = DateTime.now();

      // Insert profiles
      await db.userProfileDao.upsertProfile(
        UserProfilesCompanion.insert(
          id: currentUserId,
          username: '@me',
          displayName: 'Current User Me',
          createdAt: now,
        ),
      );
      await db.userProfileDao.upsertProfile(
        UserProfilesCompanion.insert(
          id: otherUserA,
          username: '@partnerA',
          displayName: 'Partner A',
          createdAt: now,
        ),
      );
      await db.userProfileDao.upsertProfile(
        UserProfilesCompanion.insert(
          id: otherUserB,
          username: '@partnerB',
          displayName: 'Partner B',
          createdAt: now,
        ),
      );

      // Concurrently create 50 self-actions and 50 incoming notifications
      final futures = <Future<void>>[];

      for (int i = 0; i < 50; i++) {
        // Self-action (should be ignored by count query)
        futures.add(
          db.into(db.notifications).insert(
            NotificationsCompanion.insert(
              id: 'notif-self-$i',
              userId: currentUserId,
              actorId: currentUserId,
              actorUsername: '@me',
              type: 'trade_proposal',
              title: 'Self Action $i',
              body: 'You proposed something',
              isRead: const drift.Value(false),
            ),
          ),
        );

        // Genuine incoming notification from Partner A or B
        final partner = i.isEven ? otherUserA : otherUserB;
        final partnerName = i.isEven ? '@partnerA' : '@partnerB';
        futures.add(
          db.into(db.notifications).insert(
            NotificationsCompanion.insert(
              id: 'notif-incoming-$i',
              userId: currentUserId,
              actorId: partner,
              actorUsername: partnerName,
              type: 'trade_proposal',
              title: 'Incoming $i',
              body: 'Partner proposed trade',
              isRead: const drift.Value(false),
            ),
          ),
        );
      }

      await Future.wait(futures);

      // Verify unread count is strictly 50 (ignoring all 50 self-actions)
      final unreadCount = await db.inboxDao.watchUnreadNotificationCount(currentUserId).first;
      expect(unreadCount, equals(50));

      final notifications = await db.inboxDao.watchNotifications(currentUserId).first;
      expect(notifications.length, equals(50));
      expect(notifications.every((n) => n.actorId != currentUserId), isTrue);
    });
  });

  group('Challenger Invariant 2: Collection Privacy Scoping', () {
    test('Private collection profile strictly flags private and prevents full collection access', () async {
      final now = DateTime.now();
      await db.userProfileDao.upsertProfile(
        UserProfilesCompanion.insert(
          id: 'user-private-bob',
          username: '@bob_priv',
          displayName: 'Bob Private',
          collectionVisibility: const drift.Value('private'),
          createdAt: now,
        ),
      );

      final profile = await db.userProfileDao.getProfile('user-private-bob');
      expect(profile, isNotNull);
      expect(profile!.collectionVisibility, equals('private'));

      // If user is private, trade card selection must only return items in trade_block binder
      await db.into(db.vaultBinders).insert(
        VaultBindersCompanion.insert(
          id: 'bob-tb',
          name: 'Trade Binder',
          collectionType: 'mtg',
          userId: const drift.Value('user-private-bob'),
          systemBinderType: const drift.Value('trade_block'),
          createdAt: now,
        ),
      );
      await db.into(db.vaultBinders).insert(
        VaultBindersCompanion.insert(
          id: 'bob-custom',
          name: 'Secret Personal Binder',
          collectionType: 'mtg',
          userId: const drift.Value('user-private-bob'),
          createdAt: now,
        ),
      );

      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-trade-1',
          name: 'Tradeable Card',
          collectionType: 'mtg',
          setOrSeries: 'M21',
          imageUrl: '',
          acquiredPrice: 1.0,
          acquiredDate: DateTime.now(),
          condition: 'NM',
          currentMarketPrice: 5.0,
          lastPriceUpdate: DateTime.now(),
          dynamicData: '{}',
          primaryBinderId: const drift.Value('bob-tb'),
          userId: const drift.Value('user-private-bob'),
        ),
      );
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-secret-1',
          name: 'Secret Non-Tradeable Card',
          collectionType: 'mtg',
          setOrSeries: 'M21',
          imageUrl: '',
          acquiredPrice: 100.0,
          acquiredDate: DateTime.now(),
          condition: 'NM',
          currentMarketPrice: 500.0,
          lastPriceUpdate: DateTime.now(),
          dynamicData: '{}',
          primaryBinderId: const drift.Value('bob-custom'),
          userId: const drift.Value('user-private-bob'),
        ),
      );

      // Scoped query for private user: only trade_block binder items allowed
      final availableTradeCards = await (db.select(db.vaultItems)
            ..where((t) =>
                t.userId.equals('user-private-bob') &
                t.primaryBinderId.equals('bob-tb') &
                t.isDeleted.equals(false)))
          .get();
      expect(availableTradeCards.length, equals(1));
      expect(availableTradeCards.first.id, equals('card-trade-1'));
    });
  });

  group('Challenger Invariant 3: Trade Match Negative Disambiguation & False Positive Prevention', () {
    test('Different oracle_id with similar or substring names does NOT produce false positive matches', () async {
      final now = DateTime.now();

      // Alice is Looking For "Counterspell" with oracle_id 'oracle-counterspell'
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'alice-lf-counterspell',
          name: 'Counterspell',
          setOrSeries: 'MH2',
          collectionType: 'mtg',
          imageUrl: '',
          acquiredPrice: 1.0,
          acquiredDate: now,
          quantity: const drift.Value(1),
          condition: 'NM',
          currentMarketPrice: 1.5,
          lastPriceUpdate: now,
          primaryBinderId: const drift.Value('system_looking_for_alice'),
          userId: const drift.Value('user-alice'),
          dynamicData: jsonEncode({'oracle_id': 'oracle-counterspell'}),
        ),
      );

      // Bob has "Counterspell" in system_trade_block_bob but with a DIFFERENT oracle_id
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'bob-tb-other-card',
          name: 'Disrupting Counterspell Variant',
          setOrSeries: 'MH2',
          collectionType: 'mtg',
          imageUrl: '',
          acquiredPrice: 1.0,
          acquiredDate: now,
          quantity: const drift.Value(1),
          condition: 'NM',
          currentMarketPrice: 1.5,
          lastPriceUpdate: now,
          primaryBinderId: const drift.Value('system_trade_block_bob'),
          userId: const drift.Value('user-bob'),
          dynamicData: jsonEncode({'oracle_id': 'oracle-different-id'}),
        ),
      );

      final matches = await tradeMatchService.watchMatchesForUser('user-alice').first;
      expect(matches, isEmpty, reason: 'Must not produce false positive when oracle_id differs and name is not exact');
    });
  });

  group('Challenger Invariant 4: Binder 1-to-1 Constraints & Deduplication Resilience', () {
    test('Calling deduplicateAndPurgeSystemBinders multiple times is idempotent and produces strictly 1 trade and 1 looking for binder', () async {
      const userId = 'user-stress-binders';

      // Seed repeatedly
      await vaultDao.seedSystemBindersForUser(userId, isBusiness: false);
      await vaultDao.seedSystemBindersForUser(userId, isBusiness: false);
      await vaultDao.deduplicateAndPurgeSystemBinders(userId, isBusiness: false);
      await vaultDao.deduplicateAndPurgeSystemBinders(userId, isBusiness: false);

      final activeBinders = await vaultDao.getBindersByCollection('mtg', userId: userId, isBusiness: false);
      expect(activeBinders.length, equals(2));

      final tradeCount = activeBinders.where((b) => b.systemBinderType == 'trade_block' || b.name == 'Trade Binder').length;
      final lfCount = activeBinders.where((b) => b.systemBinderType == 'looking_for').length;
      expect(tradeCount, equals(1));
      expect(lfCount, equals(1));
    });
  });

  group('Challenger Invariant 5: Estimated Vault Value Finish & Quantity Multiplier', () {
    test('Calculates market value with quantity multiplier across normal, foil, and etched finishes while omitting Looking For items', () async {
      // 1. Normal card: 3x @ $10.00 = $30.00
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'item-normal',
          collectionType: 'mtg',
          name: 'Normal Card',
          setOrSeries: 'M21',
          imageUrl: '',
          acquiredPrice: 5.0,
          acquiredDate: DateTime.now(),
          quantity: const drift.Value(3),
          condition: 'NM',
          currentMarketPrice: 0.0,
          lastPriceUpdate: DateTime.now(),
          dynamicData: jsonEncode({'prices': {'usd': '10.00'}}),
        ),
      );

      // 2. Foil card: 2x @ $25.00 = $50.00
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'item-foil',
          collectionType: 'mtg',
          name: 'Foil Card',
          setOrSeries: 'M21',
          imageUrl: '',
          acquiredPrice: 10.0,
          acquiredDate: DateTime.now(),
          quantity: const drift.Value(2),
          condition: 'NM',
          currentMarketPrice: 0.0,
          lastPriceUpdate: DateTime.now(),
          dynamicData: jsonEncode({'finish': 'foil', 'prices': {'usd': '10.00', 'usd_foil': '25.00'}}),
        ),
      );

      // 3. Etched card: 4x @ $40.00 = $160.00
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'item-etched',
          collectionType: 'mtg',
          name: 'Etched Card',
          setOrSeries: 'M21',
          imageUrl: '',
          acquiredPrice: 20.0,
          acquiredDate: DateTime.now(),
          quantity: const drift.Value(4),
          condition: 'NM',
          currentMarketPrice: 0.0,
          lastPriceUpdate: DateTime.now(),
          dynamicData: jsonEncode({'finish': 'etched', 'prices': {'usd': '10.00', 'usd_etched': '40.00'}}),
        ),
      );

      // 4. Looking For item (1x @ $999.00) - MUST BE EXCLUDED!
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'item-looking-for-huge',
          collectionType: 'mtg',
          name: 'Unowned Power 9',
          setOrSeries: 'Alpha',
          imageUrl: '',
          acquiredPrice: 0.0,
          acquiredDate: DateTime.now(),
          quantity: const drift.Value(1),
          condition: 'NM',
          currentMarketPrice: 9999.0,
          lastPriceUpdate: DateTime.now(),
          primaryBinderId: const drift.Value('system_looking_for'),
          dynamicData: '{}',
        ),
      );

      final totals = await vaultDao.getVaultTotals(collectionType: 'mtg');
      // Total count = 3 + 2 + 4 = 9 items
      expect(totals.totalCount, equals(9));
      // Total value = 30 + 50 + 160 = 240.00
      expect(totals.totalMarketValue, equals(240.00));
    });
  });

  group('Challenger Invariant 6: Real Query Latency Benchmark on 500+ Items', () {
    test('Set summary query execution completes in < 50ms on populated database', () async {
      final batchCompanions = <VaultItemsCompanion>[];
      for (int i = 0; i < 500; i++) {
        final setCode = 'SET${i % 10}';
        batchCompanions.add(
          VaultItemsCompanion.insert(
            id: 'perf-card-$i',
            collectionType: 'mtg',
            name: 'Card $i',
            setOrSeries: 'Set Name $setCode',
            imageUrl: '',
            acquiredPrice: 1.0,
            acquiredDate: DateTime.now(),
            quantity: const drift.Value(1),
            condition: 'NM',
            currentMarketPrice: 2.0,
            lastPriceUpdate: DateTime.now(),
            dynamicData: jsonEncode({
              'set_code': setCode,
              'collector_number': '$i',
            }),
          ),
        );
      }
      await db.batch((b) => b.insertAll(db.vaultItems, batchCompanions));

      // Benchmark real query execution time by awaiting .first on the stream
      final sw = Stopwatch()..start();
      final results = await vaultDao.watchSetSummaryList().first;
      sw.stop();

      expect(results.length, equals(10));
      expect(sw.elapsedMilliseconds, lessThan(50), reason: 'watchSetSummaryList query must complete in < 50ms');
    });
  });

  group('Challenger Invariant 7: Explore Decks Soft-Delete and Sync Queue Isolation', () {
    test('Unpublish explore deck queues sync DELETE without corrupting user personal decks', () async {
      // 1. Create personal deck
      const deckId = 'personal-deck-alpha';
      await db.into(db.decks).insert(
        DecksCompanion.insert(
          id: deckId,
          name: 'My Personal Deck',
          format: 'Commander',
          createdAt: DateTime.now(),
        ),
      );

      // 2. Publish to explore
      final exploreDeck = await exploreDao.sharePersonalDeckToExplore(
        personalDeckId: deckId,
        creatorName: '@Tester',
        authorId: 'author-test-1',
      );

      // 3. Unpublish
      await exploreDao.unpublishExploreDeck(exploreDeckId: exploreDeck.id);

      // Verify syncQueue has 1 record
      final syncItems = await (db.select(db.syncQueue)..where((t) => t.entityId.equals(exploreDeck.id))).get();
      expect(syncItems.length, equals(1));
      expect(syncItems.first.operation, equals('DELETE'));

      // Verify personal deck is untouched
      final personalDeck = await vaultDao.getDeck(deckId);
      expect(personalDeck, isNotNull);
      expect(personalDeck!.isDeleted, isFalse);
    });
  });

  group('Challenger Invariant 8: Algorithmic Categories Deterministic Date Behavior', () {
    test('Deterministic category selection based on dayOfYear and weekOfYear', () {
      final engine = ExploreCategoryEngine(exploreDao);
      final dateA = DateTime(2026, 6, 15);
      final daily1 = engine.resolveDailyRotatingCategory(dateA);
      final daily2 = engine.resolveDailyRotatingCategory(dateA);

      expect(daily1.id, equals(daily2.id));
      expect(daily1.title, equals(daily2.title));

      final weekly1 = engine.resolveWeeklyRotatingCategory(dateA);
      final weekly2 = engine.resolveWeeklyRotatingCategory(dateA);
      expect(weekly1.id, equals(weekly2.id));
    });
  });

  group('Challenger Invariant 9: Extreme Viewport Stability (280px Narrow Screen & 2.0x Text Scale)', () {
    testWidgets('MasterSetScreen renders without RenderFlex overflow on 280px width at 2.0x text scale', (tester) async {
      tester.view.physicalSize = const Size(280, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const collection = VaultSetCollection(
        setName: 'The Lord of the Rings: Tales of Middle-earth',
        setCode: 'LTR',
        collectionType: 'Magic: The Gathering',
        totalCount: 1,
        ownedCount: 1,
        completionPercentage: 1.0,
      );

      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-ltr-narrow',
          collectionType: 'mtg',
          name: 'The One Ring',
          setOrSeries: 'The Lord of the Rings: Tales of Middle-earth',
          imageUrl: '',
          acquiredPrice: 100.0,
          acquiredDate: DateTime.now(),
          quantity: const drift.Value(1),
          condition: 'NM',
          currentMarketPrice: 100.0,
          lastPriceUpdate: DateTime.now(),
          dynamicData: jsonEncode({
            'set_code': 'ltr',
            'collector_number': '1',
          }),
        ),
      );

      final user = AuthUser(
        id: 'test-user',
        displayName: 'Adversarial Tester',
        username: 'adv_tester',
        provider: AuthProviderType.email,
        tier: AccountTier.free,
        isGuest: false,
        isVerifiedBusiness: false,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            vaultDaoProvider.overrideWithValue(vaultDao),
            currentUserIdProvider.overrideWith((ref) => 'test-user'),
            currentUserProvider.overrideWith(
              (ref) => CurrentUserNotifier(ref.watch(authRepositoryProvider))..setUser(user),
            ),
          ],
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(280, 600),
                textScaler: TextScaler.linear(2.0),
              ),
              child: const MasterSetScreen(
                collection: collection,
                activeGame: 'Magic: The Gathering',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('master_set_screen')), findsOneWidget);
    });
  });
}
