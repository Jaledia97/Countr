// Copyright (c) 2026 Countr. All rights reserved.
// Adversarial Challenger Test Suite: Delta Inbox & Queue
// Covers:
// 1. getSmartInboxInitialIndex timestamp comparison boundary conditions (+1ms, -1ms, equal, empty, soft-deleted).
// 2. Notifications tab Friend Request inline actions (Approve -> "Accepted" & SQLite status='accepted', Deny -> "Declined" & SQLite status='declined').
// 3. Profile relationship state machine:
//    none -> add friend -> pending_sent -> cancel -> none -> incoming request -> approve -> friends -> dropdown unfriend -> none -> block user -> status='blocked' -> unblock user -> none.
// 4. Groups & Life Tracker queue reservation and rotateQueueIntoSeats mounting into PodScaffoldWidget.

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/feed/domain/models/group_game_models.dart';
import 'package:countr/features/feed/presentation/providers/group_game_providers.dart';
import 'package:countr/features/feed/presentation/screens/inbox_hub_screen.dart';
import 'package:countr/features/life_counter/presentation/widgets/commander_art_backdrop.dart';
import 'package:countr/features/life_counter/presentation/widgets/pod_scaffold_widget.dart';
import 'package:countr/features/profile/presentation/providers/profile_providers.dart';
import 'package:countr/features/profile/presentation/screens/user_profile_screen.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  const currentUserId = 'user-current-me';
  const targetUserId = 'user-spicy-brew-master';

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.userProfileDao.seedDefaultProfiles();
    await db.vaultDao.seedDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildTestApp({required Widget child}) {
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

  // ===========================================================================
  // GROUP 1: getSmartInboxInitialIndex Timestamp Boundary Conditions
  // ===========================================================================
  group('Adversarial Stress Test: getSmartInboxInitialIndex Boundary Conditions', () {
    final baseTime = DateTime(2026, 10, 31, 14, 0, 0, 0);

    test('Boundary 1: Message timestamp newer by exactly 1 millisecond (second boundary) -> returns 1 (Messages tab)', () async {
      final notifTime = DateTime(2026, 10, 31, 14, 0, 0, 999);
      final msgTime = notifTime.add(const Duration(milliseconds: 1)); // 14:00:01.000

      // Insert notification
      await db.into(db.notifications).insert(
        NotificationsCompanion.insert(
          id: 'notif_boundary_1',
          userId: currentUserId,
          actorId: targetUserId,
          actorUsername: '@SpicyBrewMaster',
          type: 'milestone',
          title: 'Post Trending',
          body: 'Your deck reached top ranking',
          createdAt: drift.Value(notifTime),
        ),
      );

      // Insert message 1ms newer
      await db.into(db.messages).insert(
        MessagesCompanion.insert(
          id: 'msg_boundary_1',
          conversationId: '${targetUserId}_$currentUserId',
          senderId: targetUserId,
          recipientId: currentUserId,
          messageText: 'Hey, are you down for an EDH pod today?',
          createdAt: drift.Value(msgTime),
        ),
      );

      final initialIndex = await db.inboxDao.getSmartInboxInitialIndex(currentUserId);
      expect(initialIndex, equals(1), reason: 'Message newer by 1ms must route to Messages tab (index 1)');
    });

    test('Boundary 2: Notification timestamp newer by exactly 1 millisecond (second boundary) -> returns 0 (Notifications tab)', () async {
      final msgTime = DateTime(2026, 10, 31, 14, 0, 0, 999);
      final notifTime = msgTime.add(const Duration(milliseconds: 1)); // 14:00:01.000

      // Insert message
      await db.into(db.messages).insert(
        MessagesCompanion.insert(
          id: 'msg_boundary_2',
          conversationId: '${targetUserId}_$currentUserId',
          senderId: targetUserId,
          recipientId: currentUserId,
          messageText: 'Message at base timestamp',
          createdAt: drift.Value(msgTime),
        ),
      );

      // Insert notification 1ms newer
      await db.into(db.notifications).insert(
        NotificationsCompanion.insert(
          id: 'notif_boundary_2',
          userId: currentUserId,
          actorId: targetUserId,
          actorUsername: '@SpicyBrewMaster',
          type: 'mention',
          title: 'Mention Alert',
          body: 'mentioned you in a deck comment',
          createdAt: drift.Value(notifTime),
        ),
      );

      final initialIndex = await db.inboxDao.getSmartInboxInitialIndex(currentUserId);
      expect(initialIndex, equals(0), reason: 'Notification newer by 1ms must route to Notifications tab (index 0)');
    });

    test('Boundary 2b: Intra-second sub-millisecond precision limitation in SQLite (same second timestamps collapse to equal)', () async {
      // Stress testing what happens when two events occur within the same second:
      // In SQLite / Drift, DateTime columns store Unix timestamps in seconds.
      // Therefore, two timestamps within the same second (e.g. 14:00:00.100 and 14:00:00.200)
      // collapse to identical timestamps (14:00:00.000) when stored in SQLite.
      final notifTime = DateTime(2026, 10, 31, 15, 0, 0, 100);
      final msgTime = DateTime(2026, 10, 31, 15, 0, 0, 200);

      await db.into(db.notifications).insert(
        NotificationsCompanion.insert(
          id: 'notif_intrasecond',
          userId: currentUserId,
          actorId: targetUserId,
          actorUsername: '@SpicyBrewMaster',
          type: 'milestone',
          title: 'Post Trending',
          body: 'Your deck reached top ranking',
          createdAt: drift.Value(notifTime),
        ),
      );

      await db.into(db.messages).insert(
        MessagesCompanion.insert(
          id: 'msg_intrasecond',
          conversationId: '${targetUserId}_$currentUserId',
          senderId: targetUserId,
          recipientId: currentUserId,
          messageText: 'Intra-second message',
          createdAt: drift.Value(msgTime),
        ),
      );

      // Because SQLite stores seconds, both retrieve as 15:00:00.000 and behave as equal timestamps,
      // which gracefully falls back to Notifications tab (0).
      final initialIndex = await db.inboxDao.getSmartInboxInitialIndex(currentUserId);
      expect(initialIndex, equals(0), reason: 'Intra-second timestamps collapse to equal in SQLite and return 0 gracefully');
    });

    test('Boundary 3: Equal timestamps -> returns 0 gracefully', () async {
      final sameTime = baseTime;

      await db.into(db.notifications).insert(
        NotificationsCompanion.insert(
          id: 'notif_boundary_3',
          userId: currentUserId,
          actorId: targetUserId,
          actorUsername: '@SpicyBrewMaster',
          type: 'trade_proposal',
          title: 'New Trade Offer',
          body: 'Offered 2 cards for your Sheoldred',
          createdAt: drift.Value(sameTime),
        ),
      );

      await db.into(db.messages).insert(
        MessagesCompanion.insert(
          id: 'msg_boundary_3',
          conversationId: '${targetUserId}_$currentUserId',
          senderId: targetUserId,
          recipientId: currentUserId,
          messageText: 'Trade offer message at identical timestamp',
          createdAt: drift.Value(sameTime),
        ),
      );

      final initialIndex = await db.inboxDao.getSmartInboxInitialIndex(currentUserId);
      expect(initialIndex, equals(0), reason: 'Equal timestamps must default gracefully to Notifications tab (0)');
    });

    test('Boundary 4: Empty records -> returns 0 gracefully without exceptions', () async {
      // Empty notifications and messages for user
      final initialIndex = await db.inboxDao.getSmartInboxInitialIndex('user-completely-empty-newbie');
      expect(initialIndex, equals(0), reason: 'Empty inbox must gracefully default to Notifications tab (0)');
    });

    test('Boundary 5: Soft-deleted newest message -> correctly ignored, falls back to valid notification', () async {
      final notifTime = baseTime;
      final deletedMsgTime = baseTime.add(const Duration(minutes: 5));

      // Active notification
      await db.into(db.notifications).insert(
        NotificationsCompanion.insert(
          id: 'notif_boundary_5',
          userId: currentUserId,
          actorId: targetUserId,
          actorUsername: '@SpicyBrewMaster',
          type: 'post_like',
          title: 'Post Liked',
          body: 'liked your brew',
          createdAt: drift.Value(notifTime),
          isDeleted: const drift.Value(false),
        ),
      );

      // Newer message but soft-deleted
      await db.into(db.messages).insert(
        MessagesCompanion.insert(
          id: 'msg_boundary_5_deleted',
          conversationId: '${targetUserId}_$currentUserId',
          senderId: targetUserId,
          recipientId: currentUserId,
          messageText: 'This message was deleted by user',
          createdAt: drift.Value(deletedMsgTime),
          isDeleted: const drift.Value(true),
        ),
      );

      final initialIndex = await db.inboxDao.getSmartInboxInitialIndex(currentUserId);
      expect(initialIndex, equals(0), reason: 'Soft-deleted newer message must be ignored, returning 0');
    });

    test('Boundary 6: Only message present (no notifications) -> returns 1', () async {
      await db.into(db.messages).insert(
        MessagesCompanion.insert(
          id: 'msg_only',
          conversationId: '${targetUserId}_$currentUserId',
          senderId: targetUserId,
          recipientId: currentUserId,
          messageText: 'Only message exists',
          createdAt: drift.Value(baseTime),
        ),
      );

      final initialIndex = await db.inboxDao.getSmartInboxInitialIndex(currentUserId);
      expect(initialIndex, equals(1));
    });

    test('Boundary 7: Only notification present (no messages) -> returns 0', () async {
      await db.into(db.notifications).insert(
        NotificationsCompanion.insert(
          id: 'notif_only',
          userId: currentUserId,
          actorId: targetUserId,
          actorUsername: '@SpicyBrewMaster',
          type: 'friend_request',
          title: 'Friend Request',
          body: 'wants to be friends',
          createdAt: drift.Value(baseTime),
        ),
      );

      final initialIndex = await db.inboxDao.getSmartInboxInitialIndex(currentUserId);
      expect(initialIndex, equals(0));
    });
  });

  // ===========================================================================
  // GROUP 2: Friend Request Inline Actions & SQLite Persistence
  // ===========================================================================
  group('Adversarial Stress Test: Friend Request Inline Actions & SQLite Persistence', () {
    testWidgets('Tapping inline Approve updates state to "Accepted" and updates SQLite Friendships to status="accepted"', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));

      const frNotifId = 'notif_fr_adv_approve';
      const requesterId = 'user-foil-collector-99';

      // Insert pending friend request notification
      await db.into(db.notifications).insert(
        NotificationsCompanion.insert(
          id: frNotifId,
          userId: currentUserId,
          actorId: requesterId,
          actorUsername: '@FoilCollector99',
          actorDisplayName: const drift.Value('Foil Collector 99'),
          type: 'friend_request',
          title: 'Friend Request',
          body: 'sent you a friend request',
          status: const drift.Value('unread'),
          isActioned: const drift.Value(false),
          isRead: const drift.Value(false),
          createdAt: drift.Value(DateTime.now()),
        ),
      );

      await tester.pumpWidget(buildTestApp(child: const InboxHubScreen(initialIndex: 0)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Inline action buttons must be present
      final approveBtnFinder = find.byKey(const Key('notif_approve_fr_$frNotifId'));
      final denyBtnFinder = find.byKey(const Key('notif_deny_fr_$frNotifId'));
      expect(approveBtnFinder, findsOneWidget);
      expect(denyBtnFinder, findsOneWidget);

      // Verify DB before action
      var preFriendship = await (db.select(db.friendships)
            ..where((t) =>
                (t.userId.equals(requesterId) & t.friendId.equals(currentUserId)) |
                (t.userId.equals(currentUserId) & t.friendId.equals(requesterId))))
          .getSingleOrNull();
      expect(preFriendship == null || preFriendship.status != 'accepted', isTrue);

      // Tap inline Approve without page reload
      await tester.tap(approveBtnFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // UI state updates to "Accepted"
      expect(find.byKey(const Key('notif_status_accepted_$frNotifId')), findsOneWidget);
      expect(find.text('Accepted'), findsOneWidget);
      expect(find.byKey(const Key('notif_approve_fr_$frNotifId')), findsNothing);

      // Directly verify SQLite Friendships table
      final postFriendship = await (db.select(db.friendships)
            ..where((t) =>
                (t.userId.equals(requesterId) & t.friendId.equals(currentUserId)) |
                (t.userId.equals(currentUserId) & t.friendId.equals(requesterId))))
          .getSingleOrNull();

      expect(postFriendship, isNotNull);
      expect(postFriendship!.status, equals('accepted'), reason: 'SQLite Friendships status must be updated to accepted');
      expect(postFriendship.isDeleted, isFalse);

      // Directly verify SQLite Notifications table
      final postNotif = await (db.select(db.notifications)..where((t) => t.id.equals(frNotifId))).getSingle();
      expect(postNotif.status, equals('accepted'));
      expect(postNotif.isActioned, isTrue);
      expect(postNotif.isRead, isTrue);
    });

    testWidgets('Tapping inline Deny updates state to "Declined" and updates SQLite Friendships to status="declined"', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));

      const frNotifId = 'notif_fr_adv_deny';
      const requesterId = 'user-spicy-brew-master';

      // Insert pending friend request notification
      await db.into(db.notifications).insert(
        NotificationsCompanion.insert(
          id: frNotifId,
          userId: currentUserId,
          actorId: requesterId,
          actorUsername: '@SpicyBrewMaster',
          actorDisplayName: const drift.Value('Spicy Brew Master'),
          type: 'friend_request',
          title: 'Friend Request',
          body: 'sent you a friend request',
          status: const drift.Value('unread'),
          isActioned: const drift.Value(false),
          isRead: const drift.Value(false),
          createdAt: drift.Value(DateTime.now()),
        ),
      );

      await tester.pumpWidget(buildTestApp(child: const InboxHubScreen(initialIndex: 0)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final denyBtnFinder = find.byKey(const Key('notif_deny_fr_$frNotifId'));
      expect(denyBtnFinder, findsOneWidget);

      // Tap inline Deny without page reload
      await tester.tap(denyBtnFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // UI state updates to "Declined"
      expect(find.byKey(const Key('notif_status_declined_$frNotifId')), findsOneWidget);
      expect(find.text('Declined'), findsOneWidget);
      expect(find.byKey(const Key('notif_deny_fr_$frNotifId')), findsNothing);

      // Directly verify SQLite Friendships table
      final postFriendship = await (db.select(db.friendships)
            ..where((t) =>
                (t.userId.equals(requesterId) & t.friendId.equals(currentUserId)) |
                (t.userId.equals(currentUserId) & t.friendId.equals(requesterId))))
          .getSingleOrNull();

      expect(postFriendship, isNotNull);
      expect(postFriendship!.status, equals('declined'), reason: 'SQLite Friendships status must be updated to declined');

      // Directly verify SQLite Notifications table
      final postNotif = await (db.select(db.notifications)..where((t) => t.id.equals(frNotifId))).getSingle();
      expect(postNotif.status, equals('declined'));
      expect(postNotif.isActioned, isTrue);
      expect(postNotif.isRead, isTrue);
    });
  });

  // ===========================================================================
  // GROUP 3: Profile Relationship State Machine Full Transition Walkthrough
  // ===========================================================================
  group('Adversarial Stress Test: Profile Relationship State Machine', () {
    testWidgets('Step through: none -> add friend -> pending_sent -> cancel -> none -> incoming request -> approve -> friends -> dropdown unfriend -> none -> block user -> status=blocked -> unblock user -> none', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));

      await tester.pumpWidget(buildTestApp(child: const UserProfileScreen(profileId: targetUserId)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // STEP 1: Initial state is 'none'
      final addFriendBtn = find.byKey(const Key('profile_btn_add_friend'));
      expect(addFriendBtn, findsOneWidget, reason: 'Initial state must render [Add Friend] button');

      // STEP 2: Tap [Add Friend] -> transitions to 'pending_sent'
      await tester.tap(addFriendBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final requestSentBtn = find.byKey(const Key('profile_btn_request_sent'));
      expect(requestSentBtn, findsOneWidget, reason: 'Tapping Add Friend must transition to [Request Sent]');

      // SQLite verification: pending friendship record
      var frRecord = await (db.select(db.friendships)
            ..where((t) => t.userId.equals(currentUserId) & t.friendId.equals(targetUserId)))
          .getSingleOrNull();
      expect(frRecord, isNotNull);
      expect(frRecord!.status, equals('pending'));

      // STEP 3: Tap [Request Sent] (cancel friend request) -> reverts to 'none'
      await tester.tap(requestSentBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byKey(const Key('profile_btn_add_friend')), findsOneWidget, reason: 'Cancelling request must revert to [Add Friend]');

      // STEP 4: Incoming request from target user to current user -> 'pending_received'
      await db.friendsDao.sendFriendRequest(targetUserId, currentUserId);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final approveBtn = find.byKey(const Key('profile_btn_approve_friend'));
      final denyBtn = find.byKey(const Key('profile_btn_deny_friend'));
      expect(approveBtn, findsOneWidget, reason: 'Incoming request must display [Approve] button');
      expect(denyBtn, findsOneWidget, reason: 'Incoming request must display [Deny] button');

      // STEP 5: Tap [Approve] -> transitions to 'friends'
      await tester.tap(approveBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final friendsDropdown = find.byKey(const Key('profile_btn_friends_dropdown'));
      expect(friendsDropdown, findsOneWidget, reason: 'Approving request must transition to [Friends ▽] button');

      // SQLite verification: accepted friendship
      frRecord = await (db.select(db.friendships)
            ..where((t) =>
                (t.userId.equals(targetUserId) & t.friendId.equals(currentUserId)) |
                (t.userId.equals(currentUserId) & t.friendId.equals(targetUserId))))
          .getSingleOrNull();
      expect(frRecord!.status, equals('accepted'));

      // STEP 6: Tap [Friends ▽] dropdown -> select [Unfriend] -> transitions to 'none'
      await tester.tap(friendsDropdown);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final unfriendMenuOption = find.byKey(const Key('profile_menu_unfriend'));
      expect(unfriendMenuOption, findsOneWidget);

      await tester.tap(unfriendMenuOption);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byKey(const Key('profile_btn_add_friend')), findsOneWidget, reason: 'Unfriending must revert back to [Add Friend]');

      // STEP 7: Block user from secondary AppBar menu -> transitions to 'blocked'
      final secondaryMenuBtn = find.byKey(const Key('profile_btn_secondary_menu'));
      expect(secondaryMenuBtn, findsOneWidget);

      await tester.tap(secondaryMenuBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final blockMenuOption = find.byKey(const Key('profile_menu_block_user'));
      expect(blockMenuOption, findsOneWidget);

      await tester.tap(blockMenuOption);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final unblockBtn = find.byKey(const Key('profile_btn_unblock'));
      expect(unblockBtn, findsOneWidget, reason: 'Blocking user must display [Unblock] button');

      // SQLite verification: status = 'blocked'
      frRecord = await (db.select(db.friendships)
            ..where((t) =>
                (t.userId.equals(targetUserId) & t.friendId.equals(currentUserId)) |
                (t.userId.equals(currentUserId) & t.friendId.equals(targetUserId))))
          .getSingleOrNull();
      expect(frRecord!.status, equals('blocked'));

      // STEP 8: Tap [Unblock] -> transitions back to 'none'
      await tester.tap(unblockBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byKey(const Key('profile_btn_add_friend')), findsOneWidget, reason: 'Unblocking must return to clean [Add Friend] state');

      // SQLite verification: record is soft-deleted / status='declined'
      frRecord = await (db.select(db.friendships)
            ..where((t) =>
                (t.userId.equals(targetUserId) & t.friendId.equals(currentUserId)) |
                (t.userId.equals(currentUserId) & t.friendId.equals(targetUserId))))
          .getSingleOrNull();
      expect(frRecord!.isDeleted, isTrue);
    });
  });

  // ===========================================================================
  // GROUP 4: Groups & Life Tracker Queue Reservation & Rotation
  // ===========================================================================
  group('Adversarial Stress Test: Groups & Life Tracker Queue Rotation', () {
    test('Full pod queue reservation with pre-selected decks & multi-user waitlist FIFO', () {
      final container = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWith((ref) => currentUserId),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(groupGamesProvider.notifier);

      // Verify initial pod table 1 state (4 seated players, 0 waitlist)
      var games = container.read(groupGamesProvider);
      var table1 = games.firstWhere((g) => g.id == 'game_tbs_table_1');
      expect(table1.waitlistCount, equals(0));
      expect(table1.seatedPlayers.length, equals(4));

      // Queue 3 users with pre-selected decks
      final entry1 = WaitlistQueueEntry(
        userId: 'waitlist_user_1',
        username: '@dragon_lord',
        displayName: 'Dragon Lord',
        deckId: 'deck_the_ur_dragon',
        deckName: 'The Ur-Dragon Aggro',
        commanderCardId: 'scryfall_card_ur_dragon',
        commanderName: 'The Ur-Dragon',
        commanderArtCropUrl: 'https://cards.scryfall.io/art_crop/front/7/e/7e78b70b-0c67-4f14-8ad7-c9f8e3f59743.jpg',
        joinedAt: DateTime(2026, 10, 31, 14, 0, 0),
      );

      final entry2 = WaitlistQueueEntry(
        userId: 'waitlist_user_2',
        username: '@atraxa_phyrexian',
        displayName: 'Atraxa Player',
        deckId: 'deck_atraxa_superfriends',
        deckName: 'Atraxa Superfriends',
        commanderCardId: 'scryfall_card_atraxa',
        commanderName: 'Atraxa, Praetors\' Voice',
        commanderArtCropUrl: 'https://cards.scryfall.io/art_crop/front/d/0/d0d33d52-3d28-4635-b985-51e126289259.jpg',
        joinedAt: DateTime(2026, 10, 31, 14, 1, 0),
      );

      final entry3 = WaitlistQueueEntry(
        userId: 'waitlist_user_3',
        username: '@prosper_treasures',
        displayName: 'Prosper Banker',
        deckId: 'deck_prosper_exile',
        deckName: 'Prosper Tome-Bound Exile',
        commanderCardId: 'scryfall_card_prosper',
        commanderName: 'Prosper, Tome-Bound',
        commanderArtCropUrl: 'https://cards.scryfall.io/art_crop/front/d/7/d743336e-d5c7-4053-a23d-92ec7581f74e.jpg',
        joinedAt: DateTime(2026, 10, 31, 14, 2, 0),
      );

      notifier.reserveSpotInGame(gameId: 'game_tbs_table_1', entry: entry1);
      notifier.reserveSpotInGame(gameId: 'game_tbs_table_1', entry: entry2);
      notifier.reserveSpotInGame(gameId: 'game_tbs_table_1', entry: entry3);

      games = container.read(groupGamesProvider);
      table1 = games.firstWhere((g) => g.id == 'game_tbs_table_1');

      expect(table1.waitlistCount, equals(3));
      expect(table1.isUserQueued('waitlist_user_1'), isTrue);
      expect(table1.isUserQueued('waitlist_user_2'), isTrue);
      expect(table1.isUserQueued('waitlist_user_3'), isTrue);
      expect(table1.queuePosition('waitlist_user_1'), equals(1));
      expect(table1.queuePosition('waitlist_user_2'), equals(2));
      expect(table1.queuePosition('waitlist_user_3'), equals(3));

      // Leave queue test
      notifier.leaveQueue(gameId: 'game_tbs_table_1', userId: 'waitlist_user_3');
      games = container.read(groupGamesProvider);
      table1 = games.firstWhere((g) => g.id == 'game_tbs_table_1');
      expect(table1.waitlistCount, equals(2));
      expect(table1.isUserQueued('waitlist_user_3'), isFalse);
    });

    testWidgets('rotateQueueIntoSeats rotates waitlist users into PodScaffoldWidget player seats with correct commander art, starting life, and deck IDs', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));

      final container = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWith((ref) => currentUserId),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(groupGamesProvider.notifier);

      const dragonArtUrl = 'https://cards.scryfall.io/art_crop/front/7/e/7e78b70b-0c67-4f14-8ad7-c9f8e3f59743.jpg';

      final queueEntry = WaitlistQueueEntry(
        userId: 'waitlist_dragon_player',
        username: '@dragon_commander',
        displayName: 'Dragon Master',
        deckId: 'deck_ur_dragon_championship',
        deckName: 'Ur Dragon Championship 2026',
        commanderCardId: 'card_ur_dragon_mythic',
        commanderName: 'The Ur-Dragon',
        commanderArtCropUrl: dragonArtUrl,
        joinedAt: DateTime.now(),
      );

      notifier.reserveSpotInGame(
        gameId: 'game_tbs_table_1',
        entry: queueEntry,
      );

      // Rotate queue into seats
      final rotatedPodState = notifier.rotateQueueIntoSeats('game_tbs_table_1');
      expect(rotatedPodState, isNotNull);

      // Verify model state post-rotation
      final seatedDragonPlayer = rotatedPodState!.players.firstWhere(
        (p) => p.id == 'waitlist_dragon_player',
      );

      expect(seatedDragonPlayer.name, equals('Dragon Master'));
      expect(seatedDragonPlayer.deckId, equals('deck_ur_dragon_championship'));
      expect(seatedDragonPlayer.commanderName, equals('The Ur-Dragon'));
      expect(seatedDragonPlayer.commanderArtCropUrl, equals(dragonArtUrl));
      expect(seatedDragonPlayer.life, equals(40));

      // All 4 players in the pod have their starting life set to 40
      expect(rotatedPodState.players.length, equals(4));
      for (final p in rotatedPodState.players) {
        expect(p.life, equals(40), reason: 'All seated players must reset to 40 starting life');
        expect(p.isEliminated, isFalse);
      }

      // Mount rotated PodState into PodScaffoldWidget
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: PodScaffoldWidget(
              podState: rotatedPodState,
              isOledMode: false,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // PodScaffoldWidget renders properly
      expect(find.byType(PodScaffoldWidget), findsOneWidget);

      // Name displays 'The Ur-Dragon'
      expect(find.byKey(const Key('player_name_waitlist_dragon_player')), findsOneWidget);
      expect(find.text('The Ur-Dragon'), findsOneWidget);

      // Life display shows 40
      expect(find.byKey(const Key('life_display_waitlist_dragon_player')), findsOneWidget);

      // CommanderArtBackdrop is mounted with Scryfall art_crop URL
      final backdropFinder = find.byType(CommanderArtBackdrop);
      expect(backdropFinder, findsOneWidget);
      final backdropWidget = tester.widget<CommanderArtBackdrop>(backdropFinder);
      expect(backdropWidget.imageUrl, equals(dragonArtUrl));
    });

    test('Calling rotateQueueIntoSeats on empty waitlist gracefully returns existing pod state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(groupGamesProvider.notifier);

      // Empty waitlist table
      final podState = notifier.rotateQueueIntoSeats('game_emerald_coast_table_2');
      expect(podState, isNotNull);
      expect(podState!.players.length, equals(4));
    });
  });
}
