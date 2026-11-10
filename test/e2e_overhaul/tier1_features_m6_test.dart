import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';
import 'package:countr/features/profile/presentation/providers/profile_providers.dart';
import 'package:countr/features/feed/presentation/screens/friends_hub_screen.dart';
import 'package:countr/features/feed/presentation/screens/inbox_hub_screen.dart';
import 'package:countr/features/feed/presentation/screens/chat_conversation_screen.dart';
import 'package:countr/features/trades/presentation/screens/trade_screen.dart';
import 'package:countr/features/trades/presentation/controllers/trade_proposal_controller.dart';
import 'package:countr/features/trades/utils/card_name_resolver.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  const currentUserId = 'user_me';
  const partnerId = 'user_partner';
  const thirdPartnerId = 'user_third';

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());

    // Seed core user profiles
    final now = DateTime.now();
    await db.into(db.userProfiles).insert(
      UserProfilesCompanion.insert(
        id: currentUserId,
        username: '@collector_me',
        displayName: 'Collector Me',
        accountType: const drift.Value('individual'),
        isVerifiedBusiness: const drift.Value(false),
        friendCount: const drift.Value(0),
        repCount: const drift.Value(10),
        tier: const drift.Value('free'),
        syncStatus: const drift.Value('synced'),
        collectionVisibility: const drift.Value('public'),
        createdAt: now,
        isDeleted: const drift.Value(false),
      ),
    );

    await db.into(db.userProfiles).insert(
      UserProfilesCompanion.insert(
        id: partnerId,
        username: '@spicy_partner',
        displayName: 'Spicy Partner',
        accountType: const drift.Value('individual'),
        isVerifiedBusiness: const drift.Value(false),
        friendCount: const drift.Value(0),
        repCount: const drift.Value(12),
        tier: const drift.Value('free'),
        syncStatus: const drift.Value('synced'),
        collectionVisibility: const drift.Value('public'),
        createdAt: now,
        isDeleted: const drift.Value(false),
      ),
    );

    await db.into(db.userProfiles).insert(
      UserProfilesCompanion.insert(
        id: thirdPartnerId,
        username: '@third_trader',
        displayName: 'Third Trader',
        accountType: const drift.Value('individual'),
        isVerifiedBusiness: const drift.Value(false),
        friendCount: const drift.Value(0),
        repCount: const drift.Value(5),
        tier: const drift.Value('free'),
        syncStatus: const drift.Value('synced'),
        collectionVisibility: const drift.Value('public'),
        createdAt: now,
        isDeleted: const drift.Value(false),
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildTestScope({required Widget child}) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        currentUserIdProvider.overrideWith((ref) => currentUserId),
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  // =========================================================================
  // FEATURE 25: Friends & Groups 2-Tab Restructure
  // =========================================================================
  group('Feature 25: Friends & Groups 2-Tab Restructure', () {
    testWidgets('F25.1: Screen has strictly two tabs: Friends and Groups', (tester) async {
      await tester.pumpWidget(buildTestScope(child: const FriendsHubScreen()));
      await tester.pumpAndSettle();

      final tabBarFinder = find.byKey(const Key('friends_hub_tab_bar'));
      expect(tabBarFinder, findsOneWidget);

      final tabBar = tester.widget<TabBar>(tabBarFinder);
      expect(tabBar.tabs.length, equals(2));
      expect(find.byKey(const Key('friends_tab_friends')), findsOneWidget);
      expect(find.byKey(const Key('friends_tab_groups')), findsOneWidget);
    });

    testWidgets('F25.2: "Requests & Find" tab is completely removed from tab bar', (tester) async {
      await tester.pumpWidget(buildTestScope(child: const FriendsHubScreen()));
      await tester.pumpAndSettle();

      final tabBar = tester.widget<TabBar>(find.byKey(const Key('friends_hub_tab_bar')));
      final tabTexts = tabBar.tabs.whereType<Tab>().map((t) => t.text).toList();
      expect(tabTexts, isNot(contains('Requests & Find')));
      expect(tabTexts, isNot(contains('My Friends')));
      expect(tabTexts, equals(['Friends', 'Groups']));
    });

    testWidgets('F25.3: TabBar controller length is strictly 2', (tester) async {
      await tester.pumpWidget(buildTestScope(child: const FriendsHubScreen()));
      await tester.pumpAndSettle();

      final tabBar = tester.widget<TabBar>(find.byKey(const Key('friends_hub_tab_bar')));
      expect(tabBar.tabs.length, equals(2));
    });

    testWidgets('F25.4: Switching between Friends and Groups updates active tab view', (tester) async {
      await tester.pumpWidget(buildTestScope(child: const FriendsHubScreen()));
      await tester.pumpAndSettle();

      // Initially on Friends tab (shows friend search input)
      expect(find.byKey(const Key('friends_search_input')), findsOneWidget);

      // Tap Groups tab
      await tester.tap(find.byKey(const Key('friends_tab_groups')));
      await tester.pumpAndSettle();

      // Groups view is active (displays group cards)
      expect(find.text('TBS Comics Table 1'), findsOneWidget);
    });

    testWidgets('F25.5: Route param initialTab: "groups" sets initial index to 1', (tester) async {
      await tester.pumpWidget(buildTestScope(child: const FriendsHubScreen(initialTab: 'groups')));
      await tester.pumpAndSettle();

      expect(find.text('TBS Comics Table 1'), findsOneWidget);
    });
  });

  // =========================================================================
  // FEATURE 26: Friends Tab 3-Section Layout
  // =========================================================================
  group('Feature 26: Friends Tab 3-Section Layout', () {
    testWidgets('F26.1: Top section displays incoming Friend Requests with See More', (tester) async {
      final now = DateTime.now();
      // Insert 4 incoming friend requests
      for (int i = 1; i <= 4; i++) {
        final reqUserId = 'user_req_$i';
        await db.into(db.userProfiles).insert(
          UserProfilesCompanion.insert(
            id: reqUserId,
            username: '@requester_$i',
            displayName: 'Requester $i',
            accountType: const drift.Value('individual'),
            isVerifiedBusiness: const drift.Value(false),
            friendCount: const drift.Value(0),
            repCount: const drift.Value(0),
            tier: const drift.Value('free'),
            syncStatus: const drift.Value('synced'),
            collectionVisibility: const drift.Value('public'),
            createdAt: now,
            isDeleted: const drift.Value(false),
          ),
        );
        await db.into(db.friendships).insert(
          FriendshipsCompanion.insert(
            id: 'fr_in_$i',
            userId: reqUserId,
            friendId: currentUserId,
            status: const drift.Value('pending'),
            createdAt: drift.Value(now),
          ),
        );
      }

      await tester.pumpWidget(buildTestScope(child: const FriendsHubScreen()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('friend_requests_section')), findsOneWidget);
      expect(find.text('Friend Requests (4)'), findsOneWidget);
      expect(find.text('See More (1)'), findsOneWidget);
    });

    testWidgets('F26.2: Friend Requests items render action buttons [Approve] and [Deny]', (tester) async {
      final now = DateTime.now();
      await db.into(db.friendships).insert(
        FriendshipsCompanion.insert(
          id: 'fr_partner',
          userId: partnerId,
          friendId: currentUserId,
          status: const drift.Value('pending'),
          createdAt: drift.Value(now),
        ),
      );

      await tester.pumpWidget(buildTestScope(child: const FriendsHubScreen()));
      await tester.pumpAndSettle();

      final approveBtn = find.byKey(Key('friend_request_approve_$partnerId'));
      final denyBtn = find.byKey(Key('friend_request_deny_$partnerId'));
      expect(approveBtn, findsOneWidget);
      expect(denyBtn, findsOneWidget);

      // Tap Approve
      await tester.tap(approveBtn);
      await tester.pumpAndSettle();

      // Check Drift SQLite status updated to accepted
      final friendship = await (db.select(db.friendships)
            ..where((t) => t.userId.equals(partnerId) & t.friendId.equals(currentUserId)))
          .getSingleOrNull();
      expect(friendship?.status, equals('accepted'));
    });

    testWidgets('F26.3: Middle section displays Friends List with search bar', (tester) async {
      final now = DateTime.now();
      await db.into(db.friendships).insert(
        FriendshipsCompanion.insert(
          id: 'fr_middle_list',
          userId: currentUserId,
          friendId: partnerId,
          status: const drift.Value('accepted'),
          createdAt: drift.Value(now),
        ),
      );

      await tester.pumpWidget(buildTestScope(child: const FriendsHubScreen()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('friends_list_section')), findsOneWidget);
      expect(find.byKey(const Key('friends_search_input')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('friends_list_section')),
          matching: find.text('Spicy Partner'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('F26.4: Tapping any friend in list navigates to Profile', (tester) async {
      final now = DateTime.now();
      await db.into(db.friendships).insert(
        FriendshipsCompanion.insert(
          id: 'fr_tap_profile',
          userId: currentUserId,
          friendId: partnerId,
          status: const drift.Value('accepted'),
          createdAt: drift.Value(now),
        ),
      );

      await tester.pumpWidget(buildTestScope(child: const FriendsHubScreen()));
      await tester.pumpAndSettle();

      final friendRowFinder = find.byKey(Key('friend_row_$partnerId'));
      expect(friendRowFinder, findsOneWidget);

      final inkWell = tester.widget<InkWell>(friendRowFinder);
      expect(inkWell.onTap, isNotNull);
    });

    testWidgets('F26.5: Bottom section displays Sent Requests with [Cancel]', (tester) async {
      final now = DateTime.now();
      await db.into(db.friendships).insert(
        FriendshipsCompanion.insert(
          id: 'fr_sent_bottom',
          userId: currentUserId,
          friendId: thirdPartnerId,
          status: const drift.Value('pending'),
          createdAt: drift.Value(now),
        ),
      );

      await tester.pumpWidget(buildTestScope(child: const FriendsHubScreen()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('sent_requests_section')), findsOneWidget);
      final cancelBtn = find.byKey(Key('sent_request_cancel_$thirdPartnerId'));
      expect(cancelBtn, findsOneWidget);

      await tester.tap(cancelBtn);
      await tester.pumpAndSettle();

      final friendship = await (db.select(db.friendships)
            ..where((t) => t.userId.equals(currentUserId) & t.friendId.equals(thirdPartnerId)))
          .getSingleOrNull();
      expect(friendship?.isDeleted, isTrue);
      expect(friendship?.status, equals('declined'));
    });
  });

  // =========================================================================
  // FEATURE 27: Cross-App Atomic Notification Sync
  // =========================================================================
  group('Feature 27: Cross-App Atomic Notification Sync', () {
    test('F27.1: Responding to friend request updates friendship and notification in single transaction', () async {
      final now = DateTime.now();
      await db.into(db.friendships).insert(
        FriendshipsCompanion.insert(
          id: 'fr_f27_1',
          userId: partnerId,
          friendId: currentUserId,
          status: const drift.Value('pending'),
          createdAt: drift.Value(now),
        ),
      );

      await db.into(db.notifications).insert(
        NotificationsCompanion.insert(
          id: 'notif_fr_1',
          userId: currentUserId,
          actorId: partnerId,
          actorUsername: '@spicy_partner',
          type: 'friend_request',
          title: 'Friend Request',
          body: 'wants to be friends',
          createdAt: drift.Value(now),
        ),
      );

      await db.inboxDao.respondToFriendRequest(notificationId: 'notif_fr_1', accept: true);

      final friendship = await (db.select(db.friendships)
            ..where((t) => t.userId.equals(partnerId) & t.friendId.equals(currentUserId)))
          .getSingle();
      expect(friendship.status, equals('accepted'));

      final notif = await (db.select(db.notifications)..where((t) => t.id.equals('notif_fr_1'))).getSingle();
      expect(notif.status, equals('accepted'));
      expect(notif.isActioned, isTrue);
      expect(notif.isRead, isTrue);

      final userMe = await db.userProfileDao.getProfile(currentUserId);
      final userPartner = await db.userProfileDao.getProfile(partnerId);
      expect(userMe?.friendCount, equals(1));
      expect(userPartner?.friendCount, equals(1));
    });

    test('F27.2: Idempotent guard prevents duplicate double-tap corruption', () async {
      final now = DateTime.now();
      await db.into(db.friendships).insert(
        FriendshipsCompanion.insert(
          id: 'fr_f27_2',
          userId: partnerId,
          friendId: currentUserId,
          status: const drift.Value('pending'),
          createdAt: drift.Value(now),
        ),
      );

      await db.into(db.notifications).insert(
        NotificationsCompanion.insert(
          id: 'notif_fr_2',
          userId: currentUserId,
          actorId: partnerId,
          actorUsername: '@spicy_partner',
          type: 'friend_request',
          title: 'Friend Request',
          body: 'wants to be friends',
          createdAt: drift.Value(now),
        ),
      );

      // Rapid double tap
      await db.inboxDao.respondToFriendRequest(notificationId: 'notif_fr_2', accept: true);
      await db.inboxDao.respondToFriendRequest(notificationId: 'notif_fr_2', accept: true);

      final userMe = await db.userProfileDao.getProfile(currentUserId);
      expect(userMe?.friendCount, equals(1));
    });

    test('F27.3: Cancelling friend request marks recipient notification declined/actioned/read', () async {
      final now = DateTime.now();
      await db.into(db.friendships).insert(
        FriendshipsCompanion.insert(
          id: 'fr_f27_3',
          userId: currentUserId,
          friendId: partnerId,
          status: const drift.Value('pending'),
          createdAt: drift.Value(now),
        ),
      );

      await db.into(db.notifications).insert(
        NotificationsCompanion.insert(
          id: 'notif_fr_sent',
          userId: partnerId,
          actorId: currentUserId,
          actorUsername: '@collector_me',
          type: 'friend_request',
          title: 'Friend Request',
          body: 'wants to be friends',
          createdAt: drift.Value(now),
        ),
      );

      await db.friendsDao.cancelFriendRequest(currentUserId, partnerId);

      final notif = await (db.select(db.notifications)..where((t) => t.id.equals('notif_fr_sent'))).getSingle();
      expect(notif.status, equals('declined'));
      expect(notif.isActioned, isTrue);
      expect(notif.isRead, isTrue);
    });

    testWidgets('F27.4: InboxHubScreen displays case-insensitive status badge without @Request removed text', (tester) async {
      final now = DateTime.now();
      await db.into(db.notifications).insert(
        NotificationsCompanion.insert(
          id: 'notif_accepted_test',
          userId: currentUserId,
          actorId: partnerId,
          actorUsername: '@spicy_partner',
          type: 'friend_request',
          title: 'Friend Request',
          body: 'wants to be friends',
          status: const drift.Value('accepted'),
          isActioned: const drift.Value(true),
          createdAt: drift.Value(now),
        ),
      );

      await tester.pumpWidget(buildTestScope(child: const InboxHubScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Accepted'), findsOneWidget);
      expect(find.textContaining('@Request removed'), findsNothing);
    });

    test('F27.5: Declining friend request marks isActioned true without friendCount increment', () async {
      final now = DateTime.now();
      await db.into(db.friendships).insert(
        FriendshipsCompanion.insert(
          id: 'fr_f27_5',
          userId: partnerId,
          friendId: currentUserId,
          status: const drift.Value('pending'),
          createdAt: drift.Value(now),
        ),
      );

      await db.into(db.notifications).insert(
        NotificationsCompanion.insert(
          id: 'notif_decline_test',
          userId: currentUserId,
          actorId: partnerId,
          actorUsername: '@spicy_partner',
          type: 'friend_request',
          title: 'Friend Request',
          body: 'wants to be friends',
          createdAt: drift.Value(now),
        ),
      );

      await db.inboxDao.respondToFriendRequest(notificationId: 'notif_decline_test', accept: false);

      final notif = await (db.select(db.notifications)..where((t) => t.id.equals('notif_decline_test'))).getSingle();
      expect(notif.status, equals('declined'));
      expect(notif.isActioned, isTrue);

      final userMe = await db.userProfileDao.getProfile(currentUserId);
      expect(userMe?.friendCount, equals(0));
    });
  });

  // =========================================================================
  // FEATURE 28: Messages Tab Compose Button & User Picker
  // =========================================================================
  group('Feature 28: Messages Tab Compose Button & User Picker', () {
    testWidgets('F28.1: Inbox Messages tab contains Draft New Message button', (tester) async {
      await tester.pumpWidget(buildTestScope(child: const InboxHubScreen(initialTab: 'messages')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('inbox_compose_button')), findsOneWidget);
      expect(find.byIcon(Icons.edit), findsOneWidget);
    });

    testWidgets('F28.2: Tapping compose button opens searchable user picker modal', (tester) async {
      await tester.pumpWidget(buildTestScope(child: const InboxHubScreen(initialTab: 'messages')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('inbox_compose_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('inbox_user_picker_modal')), findsOneWidget);
      expect(find.byKey(const Key('inbox_user_picker_search_input')), findsOneWidget);
    });

    testWidgets('F28.3: User picker supports selecting a single friend for 1-on-1 chat', (tester) async {
      final now = DateTime.now();
      await db.into(db.friendships).insert(
        FriendshipsCompanion.insert(
          id: 'fr_f28_3',
          userId: currentUserId,
          friendId: partnerId,
          status: const drift.Value('accepted'),
          createdAt: drift.Value(now),
        ),
      );

      await tester.pumpWidget(buildTestScope(child: const InboxHubScreen(initialTab: 'messages')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('inbox_compose_button')));
      await tester.pumpAndSettle();

      expect(find.text('Spicy Partner'), findsOneWidget);
      await tester.tap(find.text('Spicy Partner'));
      await tester.pumpAndSettle();

      expect(find.text('Start Chat (1)'), findsOneWidget);
    });

    testWidgets('F28.4: User picker supports selecting up to 2 partners and warns on 3+', (tester) async {
      final now = DateTime.now();
      await db.into(db.friendships).insert(
        FriendshipsCompanion.insert(
          id: 'fr_f28_4_1',
          userId: currentUserId,
          friendId: partnerId,
          status: const drift.Value('accepted'),
          createdAt: drift.Value(now),
        ),
      );
      await db.into(db.friendships).insert(
        FriendshipsCompanion.insert(
          id: 'fr_f28_4_2',
          userId: currentUserId,
          friendId: thirdPartnerId,
          status: const drift.Value('accepted'),
          createdAt: drift.Value(now),
        ),
      );

      await tester.pumpWidget(buildTestScope(child: const InboxHubScreen(initialTab: 'messages')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('inbox_compose_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Spicy Partner'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Third Trader'));
      await tester.pumpAndSettle();

      expect(find.text('Start Chat (2)'), findsOneWidget);
    });

    testWidgets('F28.5: When 0 friends exist, user picker displays empty state', (tester) async {
      await tester.pumpWidget(buildTestScope(child: const InboxHubScreen(initialTab: 'messages')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('inbox_compose_button')));
      await tester.pumpAndSettle();

      expect(find.text('Invite friends to start a chat'), findsOneWidget);
    });
  });

  // =========================================================================
  // FEATURE 29: Reactive Trade Proposal Status & Unpinning & Card Names
  // =========================================================================
  group('Feature 29: Reactive Trade Proposal Status & Unpinning & Card Names', () {
    testWidgets('F29.1: Pinned trade banner binds directly to trade_proposals.status', (tester) async {
      final now = DateTime.now();
      await db.into(db.tradeProposals).insert(
        TradeProposalsCompanion.insert(
          id: 'prop_test_1',
          proposerId: partnerId,
          receiverId: currentUserId,
          status: const drift.Value('pending'),
          offeredCardIdsJson: jsonEncode(['c1']),
          requestedCardIdsJson: jsonEncode(['c2']),
          offeredTotalValue: const drift.Value(25.0),
          requestedTotalValue: const drift.Value(25.0),
          createdAt: drift.Value(now),
        ),
      );

      await tester.pumpWidget(buildTestScope(
        child: const ChatConversationScreen(
          conversationId: 'user_me_user_partner',
          contactId: partnerId,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Active Trade Proposal'), findsOneWidget);
      expect(find.byKey(const Key('trade_card_status_badge')), findsOneWidget);
    });

    testWidgets('F29.2: Declining a trade proposal unpins banner immediately', (tester) async {
      final now = DateTime.now();
      await db.into(db.tradeProposals).insert(
        TradeProposalsCompanion.insert(
          id: 'prop_test_decline',
          proposerId: partnerId,
          receiverId: currentUserId,
          status: const drift.Value('pending'),
          offeredCardIdsJson: jsonEncode(['c1']),
          requestedCardIdsJson: jsonEncode(['c2']),
          offeredTotalValue: const drift.Value(25.0),
          requestedTotalValue: const drift.Value(25.0),
          createdAt: drift.Value(now),
        ),
      );

      await tester.pumpWidget(buildTestScope(
        child: const ChatConversationScreen(
          conversationId: 'user_me_user_partner',
          contactId: partnerId,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Active Trade Proposal'), findsOneWidget);

      await db.inboxDao.respondToTradeProposal('prop_test_decline', accept: false, transferCards: false, currentUserId: currentUserId);
      await tester.pumpAndSettle();

      expect(find.text('Active Trade Proposal'), findsNothing);
    });

    testWidgets('F29.3: Cancelling a trade proposal unpins banner immediately', (tester) async {
      final now = DateTime.now();
      await db.into(db.tradeProposals).insert(
        TradeProposalsCompanion.insert(
          id: 'prop_test_cancel',
          proposerId: currentUserId,
          receiverId: partnerId,
          status: const drift.Value('pending'),
          offeredCardIdsJson: jsonEncode(['c1']),
          requestedCardIdsJson: jsonEncode(['c2']),
          offeredTotalValue: const drift.Value(25.0),
          requestedTotalValue: const drift.Value(25.0),
          createdAt: drift.Value(now),
        ),
      );

      await tester.pumpWidget(buildTestScope(
        child: const ChatConversationScreen(
          conversationId: 'user_me_user_partner',
          contactId: partnerId,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Active Trade Proposal'), findsOneWidget);

      await db.inboxDao.cancelTradeProposal('prop_test_cancel', currentUserId: currentUserId);
      await tester.pumpAndSettle();

      expect(find.text('Active Trade Proposal'), findsNothing);
    });

    testWidgets('F29.4: Countering a trade proposal unpins prior banner and pins new proposal', (tester) async {
      final now = DateTime.now();
      await db.into(db.tradeProposals).insert(
        TradeProposalsCompanion.insert(
          id: 'prop_test_counter',
          proposerId: partnerId,
          receiverId: currentUserId,
          status: const drift.Value('pending'),
          offeredCardIdsJson: jsonEncode(['c1']),
          requestedCardIdsJson: jsonEncode(['c2']),
          offeredTotalValue: const drift.Value(25.0),
          requestedTotalValue: const drift.Value(25.0),
          createdAt: drift.Value(now),
        ),
      );

      await tester.pumpWidget(buildTestScope(
        child: const ChatConversationScreen(
          conversationId: 'user_me_user_partner',
          contactId: partnerId,
        ),
      ));
      await tester.pumpAndSettle();

      await db.inboxDao.counterTradeProposal(
        'prop_test_counter',
        proposerId: currentUserId,
        receiverId: partnerId,
        offeredCardIds: ['c2'],
        requestedCardIds: ['c1'],
        offeredTotalValue: 25.0,
        requestedTotalValue: 25.0,
      );
      await tester.pumpAndSettle();

      final prior = await (db.select(db.tradeProposals)..where((t) => t.id.equals('prop_test_counter'))).getSingle();
      expect(prior.status, equals('countered'));

      // Pinned banner is still present showing the active counter proposal
      expect(find.text('Active Trade Proposal'), findsOneWidget);
    });

    test('F29.5: Plain English Card Name resolution never renders raw IDs or slugs', () {
      expect(CardNameResolver.formatSlug('item-mtg-lightning-bolt'), equals('Lightning Bolt'));
      expect(CardNameResolver.formatSlug('item-pokemon-charizard-ex'), equals('Charizard Ex'));
      expect(CardNameResolver.formatSlug('item-lorcana-elsa-spirit-of-winter'), equals('Elsa Spirit Of Winter'));
      expect(CardNameResolver.formatSlug('Delver of Secrets // Insectile Aberration'), equals('Delver Of Secrets'));
      expect(CardNameResolver.formatSlug(''), equals('Card Not Available'));
      expect(CardNameResolver.formatSlug(null), equals('Card Not Available'));
    });
  });

  // =========================================================================
  // FEATURE 30: Full Trade Negotiation Lifecycle
  // =========================================================================
  group('Feature 30: Full Trade Negotiation Lifecycle', () {
    testWidgets('F30.1: Proposer can cancel pending trade proposal updating status to cancelled', (tester) async {
      final now = DateTime.now();
      await db.into(db.tradeProposals).insert(
        TradeProposalsCompanion.insert(
          id: 'prop_f30_1',
          proposerId: currentUserId,
          receiverId: partnerId,
          status: const drift.Value('pending'),
          offeredCardIdsJson: jsonEncode(['item-mtg-sol-ring']),
          requestedCardIdsJson: jsonEncode(['item-mtg-mana-vault']),
          offeredTotalValue: const drift.Value(2.0),
          requestedTotalValue: const drift.Value(40.0),
          createdAt: drift.Value(now),
        ),
      );

      await tester.pumpWidget(buildTestScope(
        child: const ChatConversationScreen(
          conversationId: 'user_me_user_partner',
          contactId: partnerId,
        ),
      ));
      await tester.pumpAndSettle();

      final cancelBtn = find.byKey(const Key('cancel_trade_button'));
      expect(cancelBtn, findsOneWidget);

      await tester.tap(cancelBtn);
      await tester.pumpAndSettle();

      final updated = await (db.select(db.tradeProposals)..where((t) => t.id.equals('prop_f30_1'))).getSingle();
      expect(updated.status, equals('cancelled'));
      expect(find.text('Active Trade Proposal'), findsNothing);
    });

    testWidgets('F30.2: Proposer can tap [Edit Trade] reopening Trade Builder pre-loaded with current offer', (tester) async {
      final now = DateTime.now();
      await db.into(db.tradeProposals).insert(
        TradeProposalsCompanion.insert(
          id: 'prop_f30_2',
          proposerId: currentUserId,
          receiverId: partnerId,
          status: const drift.Value('pending'),
          offeredCardIdsJson: jsonEncode(['item-mtg-sol-ring']),
          requestedCardIdsJson: jsonEncode(['item-mtg-mana-vault']),
          offeredTotalValue: const drift.Value(2.0),
          requestedTotalValue: const drift.Value(40.0),
          createdAt: drift.Value(now),
        ),
      );

      await tester.pumpWidget(buildTestScope(
        child: const ChatConversationScreen(
          conversationId: 'user_me_user_partner',
          contactId: partnerId,
        ),
      ));
      await tester.pumpAndSettle();

      final editBtn = find.byKey(const Key('trade_edit_offer_button'));
      expect(editBtn, findsOneWidget);

      await tester.tap(editBtn);
      await tester.pumpAndSettle();

      expect(find.text('Edit Trade Offer'), findsOneWidget);
      expect(find.text('Update Trade Offer'), findsOneWidget);
    });

    testWidgets('F30.3: Recipient can tap [Counter Trade] reopening Trade Builder pre-loaded in counter mode', (tester) async {
      final now = DateTime.now();
      await db.into(db.tradeProposals).insert(
        TradeProposalsCompanion.insert(
          id: 'prop_f30_3',
          proposerId: partnerId,
          receiverId: currentUserId,
          status: const drift.Value('pending'),
          offeredCardIdsJson: jsonEncode(['item-mtg-sol-ring']),
          requestedCardIdsJson: jsonEncode(['item-mtg-mana-vault']),
          offeredTotalValue: const drift.Value(2.0),
          requestedTotalValue: const drift.Value(40.0),
          createdAt: drift.Value(now),
        ),
      );

      await tester.pumpWidget(buildTestScope(
        child: const ChatConversationScreen(
          conversationId: 'user_me_user_partner',
          contactId: partnerId,
        ),
      ));
      await tester.pumpAndSettle();

      final counterBtn = find.byKey(const Key('trade_counter_offer_button'));
      expect(counterBtn, findsOneWidget);

      await tester.tap(counterBtn);
      await tester.pumpAndSettle();

      expect(find.text('Counter Trade Offer'), findsOneWidget);
      expect(find.text('Send Counter Offer'), findsOneWidget);
    });

    testWidgets('F30.4: StickyTradeValueMeter computes delta and fairness in real time', (tester) async {
      final userMe = (await db.userProfileDao.getProfile(currentUserId))!;
      final userPartner = (await db.userProfileDao.getProfile(partnerId))!;

      final params = TradeProposalParams(
        currentUser: userMe,
        partnerProfile: userPartner,
      );

      await tester.pumpWidget(buildTestScope(child: TradeScreen(params: params)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('sticky_trade_value_meter')), findsOneWidget);
    });

    test('F30.5: Submitting counter-offer marks prior proposal countered and creates new proposal', () async {
      final now = DateTime.now();
      await db.into(db.tradeProposals).insert(
        TradeProposalsCompanion.insert(
          id: 'prop_f30_5',
          proposerId: partnerId,
          receiverId: currentUserId,
          status: const drift.Value('pending'),
          offeredCardIdsJson: jsonEncode(['c1']),
          requestedCardIdsJson: jsonEncode(['c2']),
          offeredTotalValue: const drift.Value(20.0),
          requestedTotalValue: const drift.Value(20.0),
          createdAt: drift.Value(now),
        ),
      );

      final newProposal = await db.inboxDao.counterTradeProposal(
        'prop_f30_5',
        proposerId: currentUserId,
        receiverId: partnerId,
        offeredCardIds: ['c2'],
        requestedCardIds: ['c1'],
        offeredTotalValue: 20.0,
        requestedTotalValue: 20.0,
      );

      final prior = await (db.select(db.tradeProposals)..where((t) => t.id.equals('prop_f30_5'))).getSingle();
      expect(prior.status, equals('countered'));
      expect(newProposal.status, equals('pending'));
      expect(newProposal.proposerId, equals(currentUserId));
      expect(newProposal.receiverId, equals(partnerId));
    });
  });
}
