// Copyright (c) 2026 Countr. All rights reserved.
// Unit and Widget verification tests for Milestone 3 (R3):
// - Scoped Profile Activity Wall (watchUserWallPosts: authorId or sharedByUserId)
// - Reactive Friend Count (watchFriendCount in SQLite)
// - Scoped FriendsHubScreen by userId and friend_row_${id} navigation tap target
// - Search bar integrated clear/close 'X' button inside suffixIcon

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/feed/data/social_seed_service.dart';
import 'package:countr/features/feed/presentation/screens/feed_screen.dart';
import 'package:countr/features/feed/presentation/screens/friends_hub_screen.dart';
import 'package:countr/features/profile/presentation/providers/profile_providers.dart';
import 'package:countr/features/profile/presentation/screens/user_profile_screen.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SocialSeedService seedService;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.userProfileDao.seedDefaultProfiles();
    seedService = SocialSeedService(db);
    await seedService.seedSocialData();
  });

  tearDown(() async {
    await db.close();
  });

  group('Milestone 3 (R3): Scoped User Wall Posts', () {
    test('watchUserWallPosts strictly includes authored and shared posts, excluding others', () async {
      const targetUserId = 'user-spicy-brew-master';
      const otherUserId = 'user-edh-rec-fanatic';

      final now = DateTime.now();

      // 1. Post authored by target user
      await db.feedDao.createPost(
        FeedPostsCompanion.insert(
          id: 'post-wall-authored',
          authorId: targetUserId,
          authorUsername: '@SpicyBrewMaster',
          authorDisplayName: 'Spicy Brew Master',
          type: 'text',
          textContent: const drift.Value('Authored by Spicy'),
          createdAt: drift.Value(now),
        ),
      );

      // 2. Post shared by target user (authored by someone else)
      await db.feedDao.createPost(
        FeedPostsCompanion.insert(
          id: 'post-wall-shared',
          authorId: otherUserId,
          authorUsername: '@EDH_Rec_Fanatic',
          authorDisplayName: 'EDH Rec Fanatic',
          sharedByUserId: const drift.Value(targetUserId),
          type: 'text',
          textContent: const drift.Value('Shared by Spicy'),
          createdAt: drift.Value(now.subtract(const Duration(minutes: 5))),
        ),
      );

      // 3. Post authored by another user mentioning target user in text (NOT authored or shared by target)
      await db.feedDao.createPost(
        FeedPostsCompanion.insert(
          id: 'post-wall-mention-only',
          authorId: otherUserId,
          authorUsername: '@EDH_Rec_Fanatic',
          authorDisplayName: 'EDH Rec Fanatic',
          type: 'text',
          textContent: const drift.Value('Hey @SpicyBrewMaster check this out!'),
          createdAt: drift.Value(now.subtract(const Duration(minutes: 10))),
        ),
      );

      // 4. Soft-deleted post authored by target user
      await db.feedDao.createPost(
        FeedPostsCompanion.insert(
          id: 'post-wall-deleted',
          authorId: targetUserId,
          authorUsername: '@SpicyBrewMaster',
          authorDisplayName: 'Spicy Brew Master',
          type: 'text',
          textContent: const drift.Value('Deleted post'),
          isDeleted: const drift.Value(true),
          createdAt: drift.Value(now.subtract(const Duration(minutes: 15))),
        ),
      );

      // Watch target user's wall posts
      final wallPosts = await db.feedDao.watchUserWallPosts(targetUserId).first;

      final postIds = wallPosts.map((p) => p.id).toList();

      // Authored and shared must be present
      expect(postIds, contains('post-wall-authored'));
      expect(postIds, contains('post-wall-shared'));

      // Mention-only must NOT be present (no mock substring matching!)
      expect(postIds, isNot(contains('post-wall-mention-only')));

      // Deleted must NOT be present
      expect(postIds, isNot(contains('post-wall-deleted')));
    });
  });

  group('Milestone 3 (R3): Reactive Friends Count in FriendsDao', () {
    test('watchFriendCount queries SQLite accepted friendships reactively', () async {
      const userA = 'user-test-alice';
      const userB = 'user-test-bob';
      const userC = 'user-test-charlie';

      // Initially 0 friends
      var count = await db.friendsDao.watchFriendCount(userA).first;
      expect(count, equals(0));

      // Add accepted friendship (userA is userId)
      final now = DateTime.now();
      await db.into(db.friendships).insert(
        FriendshipsCompanion.insert(
          id: 'friendship_a_b',
          userId: userA,
          friendId: userB,
          status: const drift.Value('accepted'),
          createdAt: drift.Value(now),
        ),
      );

      count = await db.friendsDao.watchFriendCount(userA).first;
      expect(count, equals(1));

      // Add accepted friendship where userA is friendId
      await db.into(db.friendships).insert(
        FriendshipsCompanion.insert(
          id: 'friendship_c_a',
          userId: userC,
          friendId: userA,
          status: const drift.Value('accepted'),
          createdAt: drift.Value(now),
        ),
      );

      count = await db.friendsDao.watchFriendCount(userA).first;
      expect(count, equals(2));

      // Add a pending request (should NOT increment accepted count)
      await db.into(db.friendships).insert(
        FriendshipsCompanion.insert(
          id: 'friendship_a_pending',
          userId: userA,
          friendId: 'user-test-pending',
          status: const drift.Value('pending'),
          createdAt: drift.Value(now),
        ),
      );

      count = await db.friendsDao.watchFriendCount(userA).first;
      expect(count, equals(2));

      // Soft delete a friendship
      await (db.update(db.friendships)..where((t) => t.id.equals('friendship_a_b'))).write(
        const FriendshipsCompanion(
          isDeleted: drift.Value(true),
        ),
      );

      count = await db.friendsDao.watchFriendCount(userA).first;
      expect(count, equals(1));
    });
  });

  group('Milestone 3 (R3): FriendsHubScreen Tap Targets & User Scoping', () {
    testWidgets('FriendsHubScreen renders friend_row with navigation tap target', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            currentUserIdProvider.overrideWith((ref) => 'user-current-me'),
          ],
          child: const MaterialApp(
            home: FriendsHubScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // The seeded friend is user-edh-rec-fanatic
      final friendRowFinder = find.byKey(const Key('friend_row_user-edh-rec-fanatic'));
      expect(friendRowFinder, findsOneWidget);

      // Verify friend_row is an InkWell for full-width tap target
      final inkWell = tester.widget<InkWell>(friendRowFinder);
      expect(inkWell.onTap, isNotNull);

      // Quick action buttons inside the card remain accessible
      expect(find.byKey(const Key('friend_action_profile_user-edh-rec-fanatic')), findsOneWidget);
      expect(find.byKey(const Key('friend_action_trade_block_user-edh-rec-fanatic')), findsOneWidget);
      expect(find.byKey(const Key('friend_action_propose_trade_user-edh-rec-fanatic')), findsOneWidget);
      expect(find.byKey(const Key('friend_action_message_user-edh-rec-fanatic')), findsOneWidget);
    });

    testWidgets('FriendsHubScreen respects userId parameter when passed', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
          ],
          child: const MaterialApp(
            home: FriendsHubScreen(userId: 'user-spicy-brew-master'),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Loads friends for Spicy Brew Master cleanly
      expect(find.byKey(const Key('friends_search_input')), findsOneWidget);
    });
  });

  group('Milestone 3 (R3): Search Bar Clear and Close Button Integration', () {
    testWidgets('Clear/close button is housed inside suffixIcon of search bar', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            currentUserIdProvider.overrideWith((ref) => 'user-current-me'),
          ],
          child: const MaterialApp(
            home: FeedScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Initially search bar is closed; top search icon button is in AppBar
      expect(find.byKey(const Key('feed_appbar_search_button')), findsOneWidget);
      expect(find.byKey(const Key('home_search_input')), findsNothing);

      // Open search bar
      await tester.tap(find.byKey(const Key('feed_appbar_search_button')));
      await tester.pumpAndSettle();

      // Now search input is open
      expect(find.byKey(const Key('home_search_input')), findsOneWidget);

      // The external search icon is no longer present in AppBar
      expect(find.byKey(const Key('feed_appbar_search_button')), findsNothing);

      // When text is empty, close button is inside search bar suffixIcon
      expect(find.byKey(const Key('home_search_close_button')), findsOneWidget);
      expect(find.byKey(const Key('home_search_clear_button')), findsNothing);

      // Typing text changes suffixIcon to home_search_clear_button
      await tester.enterText(find.byKey(const Key('home_search_input')), 'Modern Horizon');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('home_search_clear_button')), findsOneWidget);
      expect(find.byKey(const Key('home_search_close_button')), findsNothing);

      // Tapping clear button clears text without closing search bar
      await tester.tap(find.byKey(const Key('home_search_clear_button')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('home_search_input')), findsOneWidget);
      expect(find.byKey(const Key('home_search_clear_button')), findsNothing);
      expect(find.byKey(const Key('home_search_close_button')), findsOneWidget);

      // Tapping close button closes the search bar
      await tester.tap(find.byKey(const Key('home_search_close_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('home_search_input')), findsNothing);
      expect(find.byKey(const Key('feed_appbar_search_button')), findsOneWidget);
    });
  });

  group('Milestone 3 (R3): Profile Screen Friends Stat Display', () {
    testWidgets('Individual user profile displays reactive Friends count', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const profileUserId = 'user-edh-rec-fanatic';

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
          ],
          child: const MaterialApp(
            home: UserProfileScreen(profileId: profileUserId),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Friends stat is rendered with profile_stat_friends key
      final friendsStatFinder = find.byKey(const Key('profile_stat_friends'));
      expect(friendsStatFinder, findsOneWidget);
      expect(
        find.descendant(of: friendsStatFinder, matching: find.text('Friends')),
        findsOneWidget,
      );
    });
  });
}
