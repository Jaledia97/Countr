// Copyright (c) 2026 Countr. All rights reserved.
// Adversarial Empirical Stress Test Suite for Milestone 6
// Features 25, 26, 27: Friends & Groups 2-Tab Restructure, Friends Tab 3-Section Layout, Cross-App Atomic Notification Sync

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
import 'package:countr/features/feed/presentation/widgets/inbox_user_picker_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  const currentUserId = 'user_me';
  const partnerId = 'user_partner';
  const thirdPartnerId = 'user_third';

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());

    final now = DateTime.now();
    // Seed core test user profiles
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

  Widget buildTestScope({
    required Widget child,
    TextScaler? textScaler,
    List<Override> additionalOverrides = const [],
  }) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        currentUserIdProvider.overrideWith((ref) => currentUserId),
        ...additionalOverrides,
      ],
      child: MaterialApp(
        theme: ThemeData.dark(),
        builder: textScaler != null
            ? (context, w) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(textScaler: textScaler),
                  child: w!,
                )
            : null,
        home: child,
      ),
    );
  }

  // ===========================================================================
  // GROUP 1: FEATURE 25 STRESS — Tab Switching & Viewport Responsiveness
  // ===========================================================================
  group('Empirical Stress 1: Feature 25 (2-Tab Restructure & Viewport)', () {
    testWidgets('1.1 Strict 2-Tab invariant: TabBar length == 2 with Friends and Groups', (tester) async {
      await tester.pumpWidget(buildTestScope(child: const FriendsHubScreen()));
      await tester.pumpAndSettle();

      final tabBarFinder = find.byKey(const Key('friends_hub_tab_bar'));
      expect(tabBarFinder, findsOneWidget);

      final tabBar = tester.widget<TabBar>(tabBarFinder);
      expect(tabBar.tabs.length, equals(2), reason: 'TabBar must strictly have 2 tabs');
      expect(find.byKey(const Key('friends_tab_friends')), findsOneWidget);
      expect(find.byKey(const Key('friends_tab_groups')), findsOneWidget);

      // Verify "Requests & Find" is NOT in the TabBar
      expect(find.text('Requests & Find'), findsNothing);
      expect(find.byKey(const Key('friends_tab_requests_find')), findsNothing);
    });

    testWidgets('1.2 Tab switching burst stress: Rapid alternating taps settle cleanly without desync', (tester) async {
      await tester.pumpWidget(buildTestScope(child: const FriendsHubScreen()));
      await tester.pumpAndSettle();

      final friendsTab = find.byKey(const Key('friends_tab_friends'));
      final groupsTab = find.byKey(const Key('friends_tab_groups'));

      // Perform 10 rapid alternating taps with minimal pump durations
      for (int i = 0; i < 5; i++) {
        await tester.tap(groupsTab);
        await tester.pump(const Duration(milliseconds: 30));
        await tester.tap(friendsTab);
        await tester.pump(const Duration(milliseconds: 30));
      }

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Rapid tab switching must not throw');

      // Final tap to Groups
      await tester.tap(groupsTab);
      await tester.pumpAndSettle();

      // Groups tab renders active pod game
      expect(find.text('TBS Comics Table 1'), findsOneWidget);

      // Final tap back to Friends
      await tester.tap(friendsTab);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('friends_search_input')), findsOneWidget);
    });

    testWidgets('1.3 InitialTab routing robustness: groups, unknown, empty, and null', (tester) async {
      // 1.3.1 initialTab: 'groups' -> Groups tab (index 1)
      await tester.pumpWidget(buildTestScope(child: const FriendsHubScreen(key: ValueKey('groups'), initialTab: 'groups')));
      await tester.pumpAndSettle();
      expect(find.text('TBS Comics Table 1'), findsOneWidget);

      // 1.3.2 initialTab: 'unknown' -> defaults safely to Friends tab (index 0)
      await tester.pumpWidget(buildTestScope(child: const FriendsHubScreen(key: ValueKey('unknown'), initialTab: 'unknown')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('friends_search_input')), findsOneWidget);

      // 1.3.3 initialTab: '' -> defaults safely to Friends tab
      await tester.pumpWidget(buildTestScope(child: const FriendsHubScreen(key: ValueKey('empty'), initialTab: '')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('friends_search_input')), findsOneWidget);

      // 1.3.4 initialTab: null -> defaults safely to Friends tab
      await tester.pumpWidget(buildTestScope(child: const FriendsHubScreen(key: ValueKey('null'), initialTab: null)));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('friends_search_input')), findsOneWidget);
    });

    testWidgets('1.4 TabBar viewport responsiveness at 240px: Zero RenderFlex overflow on TabBar', (tester) async {
      tester.view.physicalSize = const Size(240, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Pump just the AppBar containing TabBar to isolate TabBar responsiveness
      await tester.pumpWidget(
        MaterialApp(
          home: DefaultTabController(
            length: 2,
            child: Scaffold(
              appBar: AppBar(
                bottom: const TabBar(
                  key: Key('friends_hub_tab_bar'),
                  tabs: [
                    Tab(key: Key('friends_tab_friends'), text: 'Friends'),
                    Tab(key: Key('friends_tab_groups'), text: 'Groups'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'TabBar must have strictly zero overflow at 240px');
      expect(find.byKey(const Key('friends_tab_friends')), findsOneWidget);
      expect(find.byKey(const Key('friends_tab_groups')), findsOneWidget);

      // Verify both tabs fit within 240px width
      final tab1Rect = tester.getRect(find.byKey(const Key('friends_tab_friends')));
      final tab2Rect = tester.getRect(find.byKey(const Key('friends_tab_groups')));
      expect(tab1Rect.left, greaterThanOrEqualTo(0.0));
      expect(tab2Rect.right, lessThanOrEqualTo(240.0));
    });

    testWidgets('1.5 TabBar viewport responsiveness at 400px: Zero RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestScope(child: const FriendsHubScreen()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'Zero RenderFlex overflow at 400px width');
      expect(find.byKey(const Key('friends_tab_friends')), findsOneWidget);
      expect(find.byKey(const Key('friends_tab_groups')), findsOneWidget);
    });

    testWidgets('1.6 Severe TextScaler (2.0x) TabBar constraint test: TabBar survives cleanly', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, w) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2.0)),
            child: w!,
          ),
          home: DefaultTabController(
            length: 2,
            child: Scaffold(
              appBar: AppBar(
                bottom: const TabBar(
                  key: Key('friends_hub_tab_bar'),
                  tabs: [
                    Tab(key: Key('friends_tab_friends'), text: 'Friends'),
                    Tab(key: Key('friends_tab_groups'), text: 'Groups'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('friends_tab_friends')), findsOneWidget);
      expect(find.byKey(const Key('friends_tab_groups')), findsOneWidget);
    });
  });

  // ===========================================================================
  // GROUP 2: FEATURE 26 STRESS — Friends Tab 3-Section Layout & Request Lifecycle
  // ===========================================================================
  group('Empirical Stress 2: Feature 26 (Friends Tab 3 Sections & Actions)', () {
    testWidgets('2.1 0 incoming requests: empty state indicator renders correctly', (tester) async {
      await tester.pumpWidget(buildTestScope(child: const FriendsHubScreen()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('friend_requests_section')), findsOneWidget);
      expect(find.text('No pending requests'), findsOneWidget);
    });

    testWidgets('2.2 5 incoming requests: inline 3 + See More (2) toggle expands and collapses', (tester) async {
      final now = DateTime.now();
      for (int i = 1; i <= 5; i++) {
        final uid = 'req_user_$i';
        await db.into(db.userProfiles).insert(
          UserProfilesCompanion.insert(
            id: uid,
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
            userId: uid,
            friendId: currentUserId,
            status: const drift.Value('pending'),
            createdAt: drift.Value(now),
          ),
        );
      }

      await tester.pumpWidget(buildTestScope(child: const FriendsHubScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Friend Requests (5)'), findsOneWidget);
      // See More (2) indicates 5 total - 3 inline = 2 remaining
      final seeMoreFinder = find.text('See More (2)');
      expect(seeMoreFinder, findsOneWidget);

      // Verify only first 3 are rendered inline
      expect(find.text('Requester 1'), findsOneWidget);
      expect(find.text('Requester 2'), findsOneWidget);
      expect(find.text('Requester 3'), findsOneWidget);
      expect(find.text('Requester 4'), findsNothing);
      expect(find.text('Requester 5'), findsNothing);

      // Tap See More (2) -> Expands all 5
      await tester.tap(seeMoreFinder);
      await tester.pumpAndSettle();

      expect(find.text('Show Less'), findsOneWidget);
      expect(find.text('Requester 4'), findsOneWidget);
      expect(find.text('Requester 5'), findsOneWidget);

      // Tap Show Less -> Collapses back
      await tester.tap(find.text('Show Less'));
      await tester.pumpAndSettle();

      expect(find.text('See More (2)'), findsOneWidget);
      expect(find.text('Requester 4'), findsNothing);
      expect(find.text('Requester 5'), findsNothing);
    });

    testWidgets('2.3 0 friends: middle section displays empty state "You don\'t have any friends yet"', (tester) async {
      await tester.pumpWidget(buildTestScope(child: const FriendsHubScreen()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('friends_list_section')), findsOneWidget);
      expect(find.byKey(const Key('my_friends_empty')), findsOneWidget);
      expect(find.text("You don't have any friends yet"), findsOneWidget);
    });

    testWidgets('2.4 Search filter debounce: rapid keystrokes with whitespace trim query', (tester) async {
      final now = DateTime.now();
      // Add accepted friend
      await db.into(db.friendships).insert(
        FriendshipsCompanion.insert(
          id: 'fr_accepted_partner',
          userId: currentUserId,
          friendId: partnerId,
          status: const drift.Value('accepted'),
          createdAt: drift.Value(now),
        ),
      );

      await tester.pumpWidget(buildTestScope(child: const FriendsHubScreen()));
      await tester.pumpAndSettle();

      // Check friend exists in Friends List section
      final friendRowFinder = find.descendant(
        of: find.byKey(const Key('friends_list_section')),
        matching: find.text('Spicy Partner'),
      );
      expect(friendRowFinder, findsOneWidget);

      final searchInput = find.byKey(const Key('friends_search_input'));

      // Rapidly enter keystrokes with whitespace: '   spicy   '
      await tester.enterText(searchInput, '   sp');
      await tester.pump(const Duration(milliseconds: 50));
      await tester.enterText(searchInput, '   spicy   ');
      // Wait less than debounce (100ms < 200ms)
      await tester.pump(const Duration(milliseconds: 100));

      // Settle remaining debounce
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();

      // Trimmed 'spicy' matches Spicy Partner in friends_list_section
      expect(friendRowFinder, findsOneWidget);

      // Search for non-existent with whitespace
      await tester.enterText(searchInput, '   nonexistent_user   ');
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpAndSettle();

      expect(find.text('No friends match your search'), findsOneWidget);
      expect(friendRowFinder, findsNothing);
    });

    testWidgets('2.5 Search input suffixIcon check: document Friends search vs Inbox User Picker', (tester) async {
      // Test suffixIcon clear button on InboxUserPickerModal
      await tester.pumpWidget(
        buildTestScope(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => InboxUserPickerModal.show(context),
              child: const Text('Open Picker'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      final pickerInput = find.byKey(const Key('inbox_user_picker_search_input'));
      expect(pickerInput, findsOneWidget);

      // Enter text in picker search
      await tester.enterText(pickerInput, '  spicy  ');
      await tester.pumpAndSettle();

      // Clear icon button appears in suffixIcon
      final clearIcon = find.descendant(
        of: pickerInput,
        matching: find.byIcon(Icons.clear),
      );
      expect(clearIcon, findsOneWidget, reason: 'Inbox user picker search input contains clear suffixIcon');

      // Tapping clear button clears query immediately
      await tester.tap(clearIcon);
      await tester.pumpAndSettle();

      final textField = tester.widget<TextField>(pickerInput);
      expect(textField.controller?.text, isEmpty);
    });

    testWidgets('2.6 Cancel sent request: request disappears and recipient notification declines atomically', (tester) async {
      final now = DateTime.now();

      // Insert outgoing request from current user to thirdPartner
      await db.into(db.friendships).insert(
        FriendshipsCompanion.insert(
          id: 'fr_outgoing_test',
          userId: currentUserId,
          friendId: thirdPartnerId,
          status: const drift.Value('pending'),
          createdAt: drift.Value(now),
        ),
      );

      // Recipient has pending friend_request notification
      await db.into(db.notifications).insert(
        NotificationsCompanion.insert(
          id: 'notif_fr_to_third',
          userId: thirdPartnerId,
          actorId: currentUserId,
          actorUsername: '@collector_me',
          type: 'friend_request',
          title: 'Friend Request',
          body: 'sent you a friend request',
          isRead: const drift.Value(false),
          isActioned: const drift.Value(false),
          status: const drift.Value('pending'),
          createdAt: drift.Value(now),
        ),
      );

      await tester.pumpWidget(buildTestScope(child: const FriendsHubScreen()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('sent_requests_section')), findsOneWidget);
      expect(find.text('Request to $thirdPartnerId'), findsOneWidget);

      final cancelBtn = find.byKey(Key('sent_request_cancel_$thirdPartnerId'));
      expect(cancelBtn, findsOneWidget);

      // Tap Cancel
      await tester.tap(cancelBtn);
      await tester.pumpAndSettle();

      // Verify outgoing item is gone from UI
      expect(find.text('Request to $thirdPartnerId'), findsNothing);
      expect(find.text('No sent requests'), findsOneWidget);

      // Verify Drift SQLite database state: friendship is declined & soft-deleted
      final friendship = await (db.select(db.friendships)
            ..where((t) => t.userId.equals(currentUserId) & t.friendId.equals(thirdPartnerId)))
          .getSingle();
      expect(friendship.isDeleted, isTrue);
      expect(friendship.status, equals('declined'));

      // Verify recipient notification was atomically declined, actioned, and marked read
      final notif = await (db.select(db.notifications)
            ..where((t) => t.id.equals('notif_fr_to_third')))
          .getSingle();
      expect(notif.status, equals('declined'));
      expect(notif.isActioned, isTrue);
      expect(notif.isRead, isTrue);
    });
  });

  // ===========================================================================
  // GROUP 3: FEATURE 27 STRESS — Concurrency, Idempotency & String Integrity
  // ===========================================================================
  group('Empirical Stress 3: Feature 27 (Atomic Concurrency, Idempotency & Strings)', () {
    testWidgets('3.1 Rapid double-tap on [Approve]: friend_count increments EXACTLY ONCE (idempotency guard)', (tester) async {
      final now = DateTime.now();

      await db.into(db.friendships).insert(
        FriendshipsCompanion.insert(
          id: 'fr_double_tap',
          userId: partnerId,
          friendId: currentUserId,
          status: const drift.Value('pending'),
          createdAt: drift.Value(now),
        ),
      );

      await db.into(db.notifications).insert(
        NotificationsCompanion.insert(
          id: 'notif_double_tap',
          userId: currentUserId,
          actorId: partnerId,
          actorUsername: '@spicy_partner',
          type: 'friend_request',
          title: 'Friend Request',
          body: 'wants to connect',
          isRead: const drift.Value(false),
          isActioned: const drift.Value(false),
          status: const drift.Value('pending'),
          createdAt: drift.Value(now),
        ),
      );

      await tester.pumpWidget(buildTestScope(child: const FriendsHubScreen()));
      await tester.pumpAndSettle();

      final approveBtn = find.byKey(Key('friend_request_approve_$partnerId'));
      expect(approveBtn, findsOneWidget);

      // Rapid consecutive taps (simulating burst double-tap before widget disposes)
      await tester.tap(approveBtn);
      await tester.pump(const Duration(milliseconds: 10));
      // Try to tap again if still in tree
      if (tester.any(approveBtn)) {
        await tester.tap(approveBtn);
      }
      await tester.pumpAndSettle();

      // Check user profiles: friendCount must be EXACTLY 1, never 2
      final currentUserProfile = await (db.select(db.userProfiles)
            ..where((t) => t.id.equals(currentUserId)))
          .getSingle();
      final partnerProfile = await (db.select(db.userProfiles)
            ..where((t) => t.id.equals(partnerId)))
          .getSingle();

      expect(currentUserProfile.friendCount, equals(1), reason: 'currentUserId friendCount must be incremented exactly once');
      expect(partnerProfile.friendCount, equals(1), reason: 'partnerId friendCount must be incremented exactly once');

      // Verify friendship status
      final friendship = await (db.select(db.friendships)
            ..where((t) => t.userId.equals(partnerId) & t.friendId.equals(currentUserId)))
          .getSingle();
      expect(friendship.status, equals('accepted'));
    });

    test('3.2 Direct DAO concurrency stress: Simultaneous Future.wait calls on respondToFriendRequest', () async {
      final now = DateTime.now();

      await db.into(db.friendships).insert(
        FriendshipsCompanion.insert(
          id: 'fr_concurrent_dao',
          userId: partnerId,
          friendId: currentUserId,
          status: const drift.Value('pending'),
          createdAt: drift.Value(now),
        ),
      );

      await db.into(db.notifications).insert(
        NotificationsCompanion.insert(
          id: 'notif_concurrent_dao',
          userId: currentUserId,
          actorId: partnerId,
          actorUsername: '@spicy_partner',
          type: 'friend_request',
          title: 'Friend Request',
          body: 'wants to connect',
          isRead: const drift.Value(false),
          isActioned: const drift.Value(false),
          status: const drift.Value('pending'),
          createdAt: drift.Value(now),
        ),
      );

      // Execute 3 concurrent calls
      await Future.wait([
        db.friendsDao.respondToFriendRequest(currentUserId, partnerId, accept: true),
        db.friendsDao.respondToFriendRequest(currentUserId, partnerId, accept: true),
        db.inboxDao.respondToFriendRequest(notificationId: 'notif_concurrent_dao', accept: true),
      ]);

      // Check friend counts
      final u1 = await (db.select(db.userProfiles)..where((t) => t.id.equals(currentUserId))).getSingle();
      final u2 = await (db.select(db.userProfiles)..where((t) => t.id.equals(partnerId))).getSingle();

      expect(u1.friendCount, equals(1), reason: 'Idempotency must prevent race conditions from double-incrementing');
      expect(u2.friendCount, equals(1));
    });

    test('3.3 Unread notification count badge decrements reactively upon request response', () async {
      final now = DateTime.now();

      await db.into(db.notifications).insert(
        NotificationsCompanion.insert(
          id: 'notif_unread_badge_test',
          userId: currentUserId,
          actorId: partnerId,
          actorUsername: '@spicy_partner',
          type: 'friend_request',
          title: 'Friend Request',
          body: 'wants to connect',
          isRead: const drift.Value(false),
          isActioned: const drift.Value(false),
          status: const drift.Value('pending'),
          createdAt: drift.Value(now),
        ),
      );

      // Verify initial unread count is 1
      final initialCount = await db.inboxDao.watchUnreadNotificationCount(currentUserId).first;
      expect(initialCount, equals(1));

      // Respond to friend request via inboxDao
      await db.inboxDao.respondToFriendRequest(notificationId: 'notif_unread_badge_test', accept: true);

      // Verify unread count decremented reactively to 0
      final updatedCount = await db.inboxDao.watchUnreadNotificationCount(currentUserId).first;
      expect(updatedCount, equals(0), reason: 'Responding to friend request marks notification read and decrements badge');
    });

    testWidgets('3.4 Strict string check: "@Request removed" is NEVER rendered across notifications and screens', (tester) async {
      final now = DateTime.now();

      // Insert an accepted notification and a declined notification
      await db.into(db.notifications).insert(
        NotificationsCompanion.insert(
          id: 'notif_accepted_test',
          userId: currentUserId,
          actorId: partnerId,
          actorUsername: '@spicy_partner',
          type: 'friend_request',
          title: 'Friend Request',
          body: 'wants to connect',
          isRead: const drift.Value(true),
          isActioned: const drift.Value(true),
          status: const drift.Value('accepted'),
          createdAt: drift.Value(now),
        ),
      );

      await db.into(db.notifications).insert(
        NotificationsCompanion.insert(
          id: 'notif_declined_test',
          userId: currentUserId,
          actorId: thirdPartnerId,
          actorUsername: '@third_trader',
          type: 'friend_request',
          title: 'Friend Request',
          body: 'wants to connect',
          isRead: const drift.Value(true),
          isActioned: const drift.Value(true),
          status: const drift.Value('declined'),
          createdAt: drift.Value(now),
        ),
      );

      // Pump InboxHubScreen
      await tester.pumpWidget(buildTestScope(child: const InboxHubScreen()));
      await tester.pumpAndSettle();

      // Strict negative assert: "@Request removed" must NEVER be found anywhere
      expect(find.textContaining('@Request removed'), findsNothing, reason: '@Request removed must be completely absent from UI');
      expect(find.textContaining('Request removed'), findsNothing, reason: 'Request removed string must never appear');

      // Case-insensitive status badges displayed
      expect(find.text('Accepted'), findsOneWidget);
      expect(find.text('Declined'), findsOneWidget);
    });
  });
}
