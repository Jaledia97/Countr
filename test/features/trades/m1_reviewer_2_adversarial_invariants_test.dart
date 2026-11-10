import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/profile/presentation/providers/profile_providers.dart';
import 'package:countr/features/trades/domain/models/trade_card_source_filter.dart';
import 'package:countr/features/trades/domain/services/trade_match_service.dart';
import 'package:countr/features/trades/presentation/controllers/trade_proposal_controller.dart';
import 'package:countr/features/trades/presentation/screens/trade_screen.dart';
import 'package:countr/features/trades/presentation/widgets/trade_card_selection_sheet.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  final now = DateTime.now();

  final meUser = UserProfile(
    id: 'user-adversary-me',
    username: '@adversary_me',
    displayName: 'Adversary Me',
    accountType: 'individual',
    isVerifiedBusiness: false,
    friendCount: 5,
    repCount: 10,
    tier: 'free',
    syncStatus: 'synced',
    createdAt: now,
    isDeleted: false,
    collectionVisibility: 'private',
  );

  final partnerPublic = UserProfile(
    id: 'user-partner-public',
    username: '@partner_public',
    displayName: 'Public Partner',
    accountType: 'individual',
    isVerifiedBusiness: false,
    friendCount: 12,
    repCount: 20,
    tier: 'free',
    syncStatus: 'synced',
    createdAt: now,
    isDeleted: false,
    collectionVisibility: 'public',
  );

  final partnerPrivate = UserProfile(
    id: 'user-partner-private',
    username: '@partner_private',
    displayName: 'Private Partner',
    accountType: 'individual',
    isVerifiedBusiness: false,
    friendCount: 8,
    repCount: 15,
    tier: 'free',
    syncStatus: 'synced',
    createdAt: now,
    isDeleted: false,
    collectionVisibility: 'private',
  );

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());

    // Insert user profiles
    await db.userProfileDao.upsertProfile(
      UserProfilesCompanion.insert(
        id: meUser.id,
        username: meUser.username,
        displayName: meUser.displayName,
        collectionVisibility: const Value('private'),
        createdAt: now,
      ),
    );
    await db.userProfileDao.upsertProfile(
      UserProfilesCompanion.insert(
        id: partnerPublic.id,
        username: partnerPublic.username,
        displayName: partnerPublic.displayName,
        collectionVisibility: const Value('public'),
        createdAt: now,
      ),
    );
    await db.userProfileDao.upsertProfile(
      UserProfilesCompanion.insert(
        id: partnerPrivate.id,
        username: partnerPrivate.username,
        displayName: partnerPrivate.displayName,
        collectionVisibility: const Value('private'),
        createdAt: now,
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  // =========================================================================
  // INVARIANT 1: SELF-NOTIFICATION LEAK ELIMINATION
  // =========================================================================
  group('Invariant 1: Self-Notification Leak Elimination', () {
    test('InboxDao strictly excludes rogue or legacy notifications where userId == actorId', () async {
      // 1. Rogue self-notification
      await db.into(db.notifications).insert(
        NotificationsCompanion.insert(
          id: 'rogue-self-notif',
          userId: meUser.id,
          actorId: meUser.id,
          actorUsername: meUser.username,
          type: 'trade_proposal',
          title: 'Self Action',
          body: 'You proposed something',
          isRead: const Value(false),
          createdAt: Value(now),
        ),
      );

      // Verify watchNotifications excludes it
      final notifs = await db.inboxDao.watchNotifications(meUser.id).first;
      expect(notifs, isEmpty);

      // Verify watchUnreadNotificationCount is 0
      final unreadCount = await db.inboxDao.watchUnreadNotificationCount(meUser.id).first;
      expect(unreadCount, equals(0));

      // Verify getSmartInboxInitialIndex ignores self-notification timestamp
      final initialIndex = await db.inboxDao.getSmartInboxInitialIndex(meUser.id);
      expect(initialIndex, equals(0)); // Defaults cleanly to 0 without being skewed
    });

    test('createTradeProposal defense-in-depth: receiverId == proposerId creates NO notification', () async {
      // Propose trade to self (abnormal/adversarial edge case)
      final proposal = await db.inboxDao.createTradeProposal(
        proposerId: meUser.id,
        receiverId: meUser.id,
        offeredCardIds: ['c1'],
        requestedCardIds: ['c2'],
        offeredTotalValue: 50.0,
        requestedTotalValue: 50.0,
      );

      expect(proposal.id, isNotEmpty);

      // Proposer/receiver should have ZERO notifications
      final userNotifs = await (db.select(db.notifications)..where((t) => t.userId.equals(meUser.id))).get();
      expect(userNotifs, isEmpty);
    });

    test('3-way trade defense-in-depth: thirdParticipantId == proposerId creates NO notification for proposer', () async {
      final proposal = await db.inboxDao.createTradeProposal(
        proposerId: meUser.id,
        receiverId: partnerPublic.id,
        thirdParticipantId: meUser.id, // Proposer erroneously passed as 3rd partner
        offeredCardIds: ['c1'],
        requestedCardIds: ['c2'],
        offeredTotalValue: 50.0,
        requestedTotalValue: 50.0,
      );

      expect(proposal.id, isNotEmpty);

      // Receiver partner gets 1 notification
      final partnerNotifs = await (db.select(db.notifications)..where((t) => t.userId.equals(partnerPublic.id))).get();
      expect(partnerNotifs.length, equals(1));
      expect(partnerNotifs.first.actorId, equals(meUser.id));

      // Proposer gets ZERO notifications
      final proposerNotifs = await (db.select(db.notifications)..where((t) => t.userId.equals(meUser.id))).get();
      expect(proposerNotifs, isEmpty);
    });

    test('sendFriendRequest defense-in-depth: sending to self creates NO friendship and NO notification', () async {
      await db.friendsDao.sendFriendRequest(meUser.id, meUser.id);

      final friendships = await (db.select(db.friendships)..where((t) => t.userId.equals(meUser.id))).get();
      expect(friendships, isEmpty);

      final notifs = await (db.select(db.notifications)..where((t) => t.userId.equals(meUser.id))).get();
      expect(notifs, isEmpty);
    });
  });

  // =========================================================================
  // INVARIANT 2: PARTNER COLLECTION PRIVACY BYPASS RESISTANCE
  // =========================================================================
  group('Invariant 2: Partner Collection Privacy Bypass Resistance', () {
    testWidgets('TradeCardSelectionSheet strictly blocks non-binder cards when partner is private', (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 1000));

      // Seed trade binder card for private partner
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-private-binder',
          name: 'Public Trade Card in Binder',
          setOrSeries: 'M20',
          collectionType: 'mtg',
          imageUrl: '',
          acquiredPrice: 10.0,
          acquiredDate: now,
          quantity: const Value(1),
          condition: 'NM',
          currentMarketPrice: 12.0,
          lastPriceUpdate: now,
          dynamicData: '{}',
          primaryBinderId: Value('system_trade_block_${partnerPrivate.id}'),
          userId: Value(partnerPrivate.id),
        ),
      );

      // Seed secret personal collection card for private partner
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-private-secret-coll',
          name: 'Super Confidential Collection Foil',
          setOrSeries: 'MH2',
          collectionType: 'mtg',
          imageUrl: '',
          acquiredPrice: 500.0,
          acquiredDate: now,
          quantity: const Value(1),
          condition: 'NM',
          currentMarketPrice: 600.0,
          lastPriceUpdate: now,
          dynamicData: '{}',
          userId: Value(partnerPrivate.id),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            currentUserIdProvider.overrideWith((ref) => meUser.id),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: TradeCardSelectionSheet(
                user: partnerPrivate,
                isProposer: false,
                currentlySelectedCardIds: const {},
                onCardToggled: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Invariant: 3-way toggle MUST be completely absent
      expect(find.byKey(const Key('trade_card_source_filter_segmented')), findsNothing);

      // Invariant: Privacy locked banner MUST be rendered
      expect(find.byKey(const Key('partner_collection_private_banner')), findsOneWidget);
      expect(find.text("Partner's collection is Private (Trade Binder only)"), findsOneWidget);

      // Invariant: Trade Binder card is visible, but collection-only card is strictly unrendered
      expect(find.text('Public Trade Card in Binder'), findsOneWidget);
      expect(find.text('Super Confidential Collection Foil'), findsNothing);
    });

    testWidgets('Proposer side can always select from entire collection even if own privacy is private', (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 1000));

      // Me user's collectionVisibility is 'private'
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            currentUserIdProvider.overrideWith((ref) => meUser.id),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: TradeCardSelectionSheet(
                user: meUser,
                isProposer: true,
                currentlySelectedCardIds: const {},
                onCardToggled: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Proposer MUST see 3-way toggle, not the private banner
      expect(find.byKey(const Key('trade_card_source_filter_segmented')), findsOneWidget);
      expect(find.byKey(const Key('partner_collection_private_banner')), findsNothing);
    });
  });

  // =========================================================================
  // INVARIANT 3: UNOWNED & WISHLIST CARDS NEVER LEAK INTO TRADE CARDS
  // =========================================================================
  group('Invariant 3: Unowned & Wishlist Card Exclusion', () {
    test('watchUserTradeCards strictly excludes quantity <= 0, is_traded = 1, and looking_for cards across all filters', () async {
      // 1. Valid owned card in Trade Binder
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-valid-trade',
          name: 'Valid Trade Card',
          setOrSeries: 'NEO',
          collectionType: 'mtg',
          imageUrl: '',
          acquiredPrice: 20.0,
          acquiredDate: now,
          quantity: const Value(2),
          condition: 'NM',
          currentMarketPrice: 25.0,
          lastPriceUpdate: now,
          dynamicData: '{}',
          primaryBinderId: Value('system_trade_block_${meUser.id}'),
          userId: Value(meUser.id),
        ),
      );

      // 2. Card with quantity = 0 (unowned / catalog stub)
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-zero-qty',
          name: 'Ghost Unowned Card',
          setOrSeries: 'NEO',
          collectionType: 'mtg',
          imageUrl: '',
          acquiredPrice: 0.0,
          acquiredDate: now,
          quantity: const Value(0),
          condition: 'NM',
          currentMarketPrice: 50.0,
          lastPriceUpdate: now,
          dynamicData: '{}',
          primaryBinderId: Value('system_trade_block_${meUser.id}'),
          userId: Value(meUser.id),
        ),
      );

      // 3. Card marked as already traded (is_traded = true)
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-traded-away',
          name: 'Traded Away Card',
          setOrSeries: 'NEO',
          collectionType: 'mtg',
          imageUrl: '',
          acquiredPrice: 15.0,
          acquiredDate: now,
          quantity: const Value(1),
          condition: 'NM',
          isTraded: const Value(true),
          currentMarketPrice: 20.0,
          lastPriceUpdate: now,
          dynamicData: '{}',
          primaryBinderId: Value('system_trade_block_${meUser.id}'),
          userId: Value(meUser.id),
        ),
      );

      // 4. Card in Looking For binder (wishlist card)
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'card-wishlist',
          name: 'Wishlist Target Card',
          setOrSeries: 'NEO',
          collectionType: 'mtg',
          imageUrl: '',
          acquiredPrice: 0.0,
          acquiredDate: now,
          quantity: const Value(1),
          condition: 'NM',
          currentMarketPrice: 100.0,
          lastPriceUpdate: now,
          dynamicData: '{}',
          primaryBinderId: Value('system_looking_for_${meUser.id}'),
          userId: Value(meUser.id),
        ),
      );

      // Verify under tradeBinder filter
      final binderCards = await db.vaultDao
          .watchUserTradeCards(meUser.id, filter: TradeCardSourceFilter.tradeBinder)
          .first;
      expect(binderCards.map((c) => c.id).toList(), equals(['card-valid-trade']));

      // Verify under collection filter (neither trade binder nor wishlist)
      final collCards = await db.vaultDao
          .watchUserTradeCards(meUser.id, filter: TradeCardSourceFilter.collection)
          .first;
      expect(collCards, isEmpty);

      // Verify under both filter: strictly ONLY valid owned card
      final bothCards = await db.vaultDao
          .watchUserTradeCards(meUser.id, filter: TradeCardSourceFilter.both)
          .first;
      expect(bothCards.map((c) => c.id).toList(), equals(['card-valid-trade']));
      expect(bothCards.any((c) => c.id == 'card-zero-qty'), isFalse);
      expect(bothCards.any((c) => c.id == 'card-traded-away'), isFalse);
      expect(bothCards.any((c) => c.id == 'card-wishlist'), isFalse);
    });
  });

  // =========================================================================
  // INVARIANT 4: CROSS-SET MATCHING BY ORACLE_ID
  // =========================================================================
  group('Invariant 4: Cross-Set Matching by oracle_id in TradeMatchService', () {
    test('accurately matches looking_for card with trade_binder card having DIFFERENT scryfall_id but SAME oracle_id', () async {
      const sharedOracleId = 'oracle-rhystic-study-12345';

      // Current user looking for Rhystic Study (Prophecy printing)
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'my-looking-for-rhystic',
          name: 'Rhystic Study',
          setOrSeries: 'Prophecy',
          collectionType: 'mtg',
          imageUrl: 'https://example.com/prophecy.jpg',
          acquiredPrice: 0.0,
          acquiredDate: now,
          quantity: const Value(1),
          condition: 'NM',
          currentMarketPrice: 35.0,
          lastPriceUpdate: now,
          dynamicData: '{"oracle_id": "$sharedOracleId", "scryfall_id": "scryfall-prophecy-001"}',
          primaryBinderId: Value('system_looking_for_${meUser.id}'),
          userId: Value(meUser.id),
        ),
      );

      // Partner user owns Rhystic Study (Double Masters Anime Borderless printing)
      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'partner-trade-rhystic',
          name: 'Rhystic Study (Anime Borderless)',
          setOrSeries: 'Double Masters',
          collectionType: 'mtg',
          imageUrl: 'https://example.com/2xm-anime.jpg',
          acquiredPrice: 60.0,
          acquiredDate: now,
          quantity: const Value(1),
          condition: 'NM',
          currentMarketPrice: 75.0,
          lastPriceUpdate: now,
          dynamicData: '{"oracle_id": "$sharedOracleId", "scryfall_id": "scryfall-2xm-anime-999"}',
          primaryBinderId: Value('system_trade_block_${partnerPublic.id}'),
          userId: Value(partnerPublic.id),
        ),
      );

      final service = TradeMatchService(db);
      final matches = await service.watchMatchesForUser(meUser.id).first;

      expect(matches.length, equals(1));
      final match = matches.first;
      expect(match.partnerUser.id, equals(partnerPublic.id));
      expect(match.matchingTradeCard.id, equals('partner-trade-rhystic'));
      expect(match.lookingForCard.id, equals('my-looking-for-rhystic'));
      // Invariant: matchType MUST be resolved as 'oracle_id'
      expect(match.matchType, equals('oracle_id'));
    });

    test('generateMatchNotification generates idempotent notification with foreign actorId', () async {
      const sharedOracleId = 'oracle-sol-ring-999';

      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'my-lf-sol-ring',
          name: 'Sol Ring',
          setOrSeries: 'LEA',
          collectionType: 'mtg',
          imageUrl: '',
          acquiredPrice: 0.0,
          acquiredDate: now,
          quantity: const Value(1),
          condition: 'NM',
          currentMarketPrice: 1.5,
          lastPriceUpdate: now,
          dynamicData: '{"oracle_id": "$sharedOracleId"}',
          primaryBinderId: Value('system_looking_for_${meUser.id}'),
          userId: Value(meUser.id),
        ),
      );

      await db.into(db.vaultItems).insert(
        VaultItemsCompanion.insert(
          id: 'partner-trade-sol-ring',
          name: 'Sol Ring',
          setOrSeries: 'Commander 2021',
          collectionType: 'mtg',
          imageUrl: '',
          acquiredPrice: 1.0,
          acquiredDate: now,
          quantity: const Value(1),
          condition: 'NM',
          currentMarketPrice: 1.75,
          lastPriceUpdate: now,
          dynamicData: '{"oracle_id": "$sharedOracleId"}',
          primaryBinderId: Value('system_trade_block_${partnerPublic.id}'),
          userId: Value(partnerPublic.id),
        ),
      );

      final service = TradeMatchService(db);
      final matches = await service.watchMatchesForUser(meUser.id).first;
      expect(matches, isNotEmpty);

      // Generate notification for current user
      final notif = await service.generateMatchNotification(matches.first, recipientUserId: meUser.id);
      expect(notif, isNotNull);
      expect(notif!.userId, equals(meUser.id));
      expect(notif.actorId, equals(partnerPublic.id));
      expect(notif.type, equals('trade_match'));
      expect(notif.body, contains('has Sol Ring in their Trade Binder that you have been looking for!'));

      // Invariant: Idempotent - second call does not duplicate or throw
      final notif2 = await service.generateMatchNotification(matches.first, recipientUserId: meUser.id);
      expect(notif2!.id, equals(notif.id));
    });
  });

  // =========================================================================
  // INVARIANT 5: PRE-SELECTED CARD VALUE METER COMPUTATION & STABILITY
  // =========================================================================
  group('Invariant 5: Pre-selected Card Value Meter & Stability', () {
    test('initialPartnerCard with zero/null price does NOT cause division by zero or NaN', () {
      final unpricedCard = VaultItem(
        id: 'unpriced-card',
        collectionType: 'mtg',
        name: 'Obscure Token Card',
        setOrSeries: 'Custom',
        imageUrl: '',
        acquiredPrice: 0.0,
        acquiredDate: now,
        quantity: 1,
        condition: 'NM',
        isGraded: false,
        isAltered: false,
        isMisprint: false,
        isSigned: false,
        currentMarketPrice: 0.0, // Zero market price
        lastPriceUpdate: now,
        dynamicData: '{}', // Empty dynamic data, no price JSON
        isDeleted: false,
      );

      final params = TradeProposalParams(
        currentUser: meUser,
        partnerProfile: partnerPublic,
        initialPartnerCard: unpricedCard,
      );

      final controller = TradeProposalController(params);
      final state = controller.state;

      expect(state.participants.length, equals(2));
      final partner = state.getParticipant(partnerPublic.id);
      expect(partner, isNotNull);
      expect(partner!.sendingCards.length, equals(1));
      expect(partner.sendingTotalValue, equals(0.0));

      // Invariant: No NaN or Infinity in fairness calculations
      expect(state.fairness.maxGapPercent.isNaN, isFalse);
      expect(state.fairness.maxGapPercent.isInfinite, isFalse);
      expect(state.fairness.maxGapPercent, equals(0.0));
      expect(state.fairness.isLargeGap, isFalse);
    });

    test('initialPartnerCard with real value stages immediately, routes to proposer, and evaluates fairness', () {
      final valuableCard = VaultItem(
        id: 'valuable-cyclonic-rift',
        collectionType: 'mtg',
        name: 'Cyclonic Rift',
        setOrSeries: 'RTR',
        imageUrl: 'https://example.com/rift.jpg',
        acquiredPrice: 30.0,
        acquiredDate: now,
        quantity: 1,
        condition: 'NM',
        isGraded: false,
        isAltered: false,
        isMisprint: false,
        isSigned: false,
        currentMarketPrice: 38.0,
        lastPriceUpdate: now,
        dynamicData: '{"prices": {"usd": "38.00"}}',
        isDeleted: false,
      );

      final params = TradeProposalParams(
        currentUser: meUser,
        partnerProfile: partnerPublic,
        initialPartnerCard: valuableCard,
      );

      final controller = TradeProposalController(params);
      final state = controller.state;

      final me = state.getParticipant(meUser.id)!;
      final partner = state.getParticipant(partnerPublic.id)!;

      // Partner is sending the card
      expect(partner.sendingCards.length, equals(1));
      expect(partner.sendingTotalValue, equals(38.0));
      expect(partner.receivingTotalValue, equals(0.0));

      // Me is receiving the card
      expect(me.receivingTransfers.length, equals(1));
      expect(me.receivingTransfers.first.cardName, equals('Cyclonic Rift'));
      expect(me.receivingTotalValue, equals(38.0));
      expect(me.sendingTotalValue, equals(0.0));

      // Fairness tier is lopsided (100% gap) and flags large value difference
      expect(state.fairness.maxGapPercent, equals(100.0));
      expect(state.fairness.maxDollarGap, equals(38.0));
      expect(state.fairness.isLargeGap, isTrue);
    });

    testWidgets('TradeScreen renders with pre-selected card, StickyTradeValueMeter, and no overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(550, 950));

      final preselectedCard = VaultItem(
        id: 'preselected-card',
        collectionType: 'mtg',
        name: 'Mox Opal',
        setOrSeries: 'SOM',
        imageUrl: '',
        acquiredPrice: 90.0,
        acquiredDate: now,
        quantity: 1,
        condition: 'NM',
        isGraded: false,
        isAltered: false,
        isMisprint: false,
        isSigned: false,
        currentMarketPrice: 110.0,
        lastPriceUpdate: now,
        dynamicData: '{"prices": {"usd": "110.00"}}',
        isDeleted: false,
      );

      final params = TradeProposalParams(
        currentUser: meUser,
        partnerProfile: partnerPublic,
        initialPartnerCard: preselectedCard,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            currentUserIdProvider.overrideWith((ref) => meUser.id),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: TradeScreen(params: params),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify TradeScreen, Value Meter, and pre-selected card appear cleanly
      expect(find.byKey(const Key('trade_screen')), findsOneWidget);
      expect(find.byKey(const Key('sticky_trade_value_meter')), findsOneWidget);
      expect(find.text('Mox Opal'), findsNWidgets(2)); // Partner sending + Proposer receiving
      expect(find.text('Net: +\$110.00'), findsOneWidget); // Net delta for proposer
      expect(find.text('Net: -\$110.00'), findsOneWidget); // Net delta for partner
    });
  });
}
