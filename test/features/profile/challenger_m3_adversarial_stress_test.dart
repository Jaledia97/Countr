// Copyright (c) 2026 Countr. All rights reserved.
// Adversarial Stress Test Suite for Milestone 3 (R3):
// - Profile avatar gallery picker with nulls, format variations, local path rendering, and multi-post cascading
// - Reactive friend count edge cases: 0 friends, unaccepted requests, bidirectional friendship checks (user_id vs friend_id)
// - Scoped Friends Hub screen isolation when inspecting different user profiles via query parameter
// - Full-width row tap target (Key('friend_row_${friend.id}')) vs action button tap isolation
// - Business follow vs friend invariants and activity wall scoping
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:countr/core/cache/countr_cached_image.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/feed/data/social_seed_service.dart';
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

  // ---------------------------------------------------------------------------
  // GROUP 1: AVATAR PICKER, LOCAL PATH RENDERING & MULTI-POST CASCADING
  // ---------------------------------------------------------------------------
  group('Adversarial Challenge: Avatar Picker, Local Paths & Cascading', () {
    testWidgets('Initial profile with null/empty avatar renders initial letter avatar gracefully', (tester) async {
      const testUserId = 'user-null-avatar';
      final now = DateTime.now();
      await db.into(db.userProfiles).insert(
        UserProfilesCompanion.insert(
          id: testUserId,
          username: 'null_avatar_user',
          displayName: 'Null Avatar User',
          accountType: const drift.Value('individual'),
          avatarUrl: const drift.Value(null),
          tier: const drift.Value('free'),
          createdAt: now,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            currentUserIdProvider.overrideWith((ref) => testUserId),
          ],
          child: const MaterialApp(
            home: UserProfileScreen(profileId: testUserId),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Avatar container renders letter 'N'
      expect(find.byKey(const Key('profile_avatar')), findsOneWidget);
      expect(find.text('N'), findsOneWidget);
      expect(find.byType(CountrCachedImage), findsNothing);
    });

    testWidgets('CountrCachedImage handles whitespace and empty URL', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CountrCachedImage(
              imageUrl: '   ',
              width: 80,
              height: 80,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CountrCachedImage), findsOneWidget);
    });

    test('Multi-post avatar cascade updates 100% of authored posts across types and isolates other authors', () async {
      const targetUserId = 'user-alice-cascade';
      const otherUserId = 'user-bob-isolate';
      final now = DateTime.now();

      // Insert target user and other user
      await db.into(db.userProfiles).insert(
        UserProfilesCompanion.insert(
          id: targetUserId,
          username: 'alice_cascade',
          displayName: 'Alice Cascade',
          avatarUrl: const drift.Value('/old/path/alice.jpg'),
          createdAt: now,
        ),
      );
      await db.into(db.userProfiles).insert(
        UserProfilesCompanion.insert(
          id: otherUserId,
          username: 'bob_isolate',
          displayName: 'Bob Isolate',
          avatarUrl: const drift.Value('/old/path/bob.jpg'),
          createdAt: now,
        ),
      );

      // Create 4 diverse posts authored by target user:
      // Post 1: Text post
      await db.feedDao.createPost(
        FeedPostsCompanion.insert(
          id: 'post-alice-text',
          authorId: targetUserId,
          authorUsername: '@alice_cascade',
          authorDisplayName: 'Alice Cascade',
          authorAvatarUrl: const drift.Value('/old/path/alice.jpg'),
          type: 'text',
          textContent: const drift.Value('Text post by Alice'),
          createdAt: drift.Value(now),
        ),
      );

      // Post 2: Single pull post
      await db.feedDao.createPost(
        FeedPostsCompanion.insert(
          id: 'post-alice-single',
          authorId: targetUserId,
          authorUsername: '@alice_cascade',
          authorDisplayName: 'Alice Cascade',
          authorAvatarUrl: const drift.Value('/old/path/alice.jpg'),
          type: 'singlePull',
          cardTitle: const drift.Value('Black Lotus'),
          cardImageUrl: const drift.Value('https://example.com/lotus.jpg'),
          createdAt: drift.Value(now.subtract(const Duration(minutes: 5))),
        ),
      );

      // Post 3: Multi pull post
      await db.feedDao.createPost(
        FeedPostsCompanion.insert(
          id: 'post-alice-multi',
          authorId: targetUserId,
          authorUsername: '@alice_cascade',
          authorDisplayName: 'Alice Cascade',
          authorAvatarUrl: const drift.Value('/old/path/alice.jpg'),
          type: 'multiPull',
          pullImagesJson: const drift.Value('["https://example.com/p1.jpg"]'),
          createdAt: drift.Value(now.subtract(const Duration(minutes: 10))),
        ),
      );

      // Post 4: Soft-deleted post
      await db.feedDao.createPost(
        FeedPostsCompanion.insert(
          id: 'post-alice-deleted',
          authorId: targetUserId,
          authorUsername: '@alice_cascade',
          authorDisplayName: 'Alice Cascade',
          authorAvatarUrl: const drift.Value('/old/path/alice.jpg'),
          type: 'text',
          textContent: const drift.Value('Deleted text post'),
          isDeleted: const drift.Value(true),
          createdAt: drift.Value(now.subtract(const Duration(minutes: 15))),
        ),
      );

      // Post 5: Post authored by Bob
      await db.feedDao.createPost(
        FeedPostsCompanion.insert(
          id: 'post-bob-untouched',
          authorId: otherUserId,
          authorUsername: '@bob_isolate',
          authorDisplayName: 'Bob Isolate',
          authorAvatarUrl: const drift.Value('/old/path/bob.jpg'),
          type: 'text',
          textContent: const drift.Value('Bob post should NOT change'),
          createdAt: drift.Value(now),
        ),
      );

      // Post 6: Post authored by Bob, shared by Alice (authorAvatarUrl belongs to Bob!)
      await db.feedDao.createPost(
        FeedPostsCompanion.insert(
          id: 'post-bob-shared-by-alice',
          authorId: otherUserId,
          authorUsername: '@bob_isolate',
          authorDisplayName: 'Bob Isolate',
          authorAvatarUrl: const drift.Value('/old/path/bob.jpg'),
          sharedByUserId: const drift.Value(targetUserId),
          type: 'text',
          textContent: const drift.Value('Alice shared this, but Bob authored it'),
          createdAt: drift.Value(now),
        ),
      );

      // Execute avatar update & cascade
      const newAvatarPath = '/data/user/0/app/avatars/user-alice-cascade_9999.jpg';
      await db.userProfileDao.updateAvatar(targetUserId, newAvatarPath);
      await db.feedDao.updateAuthorAvatar(targetUserId, newAvatarPath);

      // Verify Profile in SQLite
      final profile = await db.userProfileDao.getProfile(targetUserId);
      expect(profile!.avatarUrl, equals(newAvatarPath));

      // Verify ALL of Alice's authored posts received the new avatar
      final alicePost1 = await db.feedDao.getPostById('post-alice-text');
      expect(alicePost1!.authorAvatarUrl, equals(newAvatarPath));

      final alicePost2 = await db.feedDao.getPostById('post-alice-single');
      expect(alicePost2!.authorAvatarUrl, equals(newAvatarPath));

      final alicePost3 = await db.feedDao.getPostById('post-alice-multi');
      expect(alicePost3!.authorAvatarUrl, equals(newAvatarPath));

      final alicePost4 = await db.feedDao.getPostById('post-alice-deleted');
      expect(alicePost4!.authorAvatarUrl, equals(newAvatarPath));

      // Verify Bob's posts were completely untouched
      final bobPost = await db.feedDao.getPostById('post-bob-untouched');
      expect(bobPost!.authorAvatarUrl, equals('/old/path/bob.jpg'));

      final bobSharedPost = await db.feedDao.getPostById('post-bob-shared-by-alice');
      expect(bobSharedPost!.authorAvatarUrl, equals('/old/path/bob.jpg'));
    });

    test('Avatar cascade executes cleanly without errors for account with 0 posts', () async {
      const zeroPostUserId = 'user-zero-posts';
      final now = DateTime.now();
      await db.into(db.userProfiles).insert(
        UserProfilesCompanion.insert(
          id: zeroPostUserId,
          username: 'zero_posts',
          displayName: 'Zero Posts',
          createdAt: now,
        ),
      );

      const newAvatar = '/path/to/avatar_zero.jpg';
      await expectLater(
        db.userProfileDao.updateAvatar(zeroPostUserId, newAvatar),
        completes,
      );
      await expectLater(
        db.feedDao.updateAuthorAvatar(zeroPostUserId, newAvatar),
        completes,
      );

      final profile = await db.userProfileDao.getProfile(zeroPostUserId);
      expect(profile!.avatarUrl, equals(newAvatar));
    });
  });

  // ---------------------------------------------------------------------------
  // GROUP 2: REACTIVE FRIEND COUNT EDGE CASES
  // ---------------------------------------------------------------------------
  group('Adversarial Challenge: Reactive Friend Count Edge Cases', () {
    testWidgets('0 friends user renders 0 on Profile Screen', (tester) async {
      const solitaryUserId = 'user-solitary';
      final now = DateTime.now();
      await db.into(db.userProfiles).insert(
        UserProfilesCompanion.insert(
          id: solitaryUserId,
          username: 'solitary_user',
          displayName: 'Solitary User',
          tier: const drift.Value('free'),
          createdAt: now,
        ),
      );

      // Verify DAO count is 0
      final count = await db.friendsDao.getFriendCount(solitaryUserId);
      expect(count, equals(0));

      // Test Profile Screen renders '0'
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            currentUserIdProvider.overrideWith((ref) => solitaryUserId),
          ],
          child: const MaterialApp(
            home: UserProfileScreen(profileId: solitaryUserId),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final friendsStatFinder = find.byKey(const Key('profile_stat_friends'));
      expect(friendsStatFinder, findsOneWidget);
      expect(find.descendant(of: friendsStatFinder, matching: find.text('0')), findsOneWidget);
    });

    testWidgets('0 friends user renders empty state on FriendsHubScreen', (tester) async {
      const solitaryUserId = 'user-solitary-hub';
      final now = DateTime.now();
      await db.into(db.userProfiles).insert(
        UserProfilesCompanion.insert(
          id: solitaryUserId,
          username: 'solitary_user_hub',
          displayName: 'Solitary User Hub',
          tier: const drift.Value('free'),
          createdAt: now,
        ),
      );

      // Test Friends Hub renders empty state
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            currentUserIdProvider.overrideWith((ref) => solitaryUserId),
          ],
          child: const MaterialApp(
            home: FriendsHubScreen(userId: solitaryUserId),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('my_friends_empty')), findsOneWidget);
      expect(find.text('You don\'t have any friends yet'), findsOneWidget);
    });

    test('Unaccepted statuses (pending, declined, blocked, cancelled) strictly excluded from friend count', () async {
      const subjectUser = 'user-subject';
      final now = DateTime.now();

      // Insert subject user
      await db.into(db.userProfiles).insert(
        UserProfilesCompanion.insert(
          id: subjectUser,
          username: 'subject_user',
          displayName: 'Subject User',
          createdAt: now,
        ),
      );

      // 1. Pending outgoing request
      await db.into(db.friendships).insert(
        FriendshipsCompanion.insert(
          id: 'f_pending_out',
          userId: subjectUser,
          friendId: 'user-pending-target',
          status: const drift.Value('pending'),
          createdAt: drift.Value(now),
        ),
      );

      // 2. Pending incoming request
      await db.into(db.friendships).insert(
        FriendshipsCompanion.insert(
          id: 'f_pending_in',
          userId: 'user-pending-sender',
          friendId: subjectUser,
          status: const drift.Value('pending'),
          createdAt: drift.Value(now),
        ),
      );

      // 3. Declined request
      await db.into(db.friendships).insert(
        FriendshipsCompanion.insert(
          id: 'f_declined',
          userId: subjectUser,
          friendId: 'user-declined',
          status: const drift.Value('declined'),
          createdAt: drift.Value(now),
        ),
      );

      // 4. Blocked relationship
      await db.into(db.friendships).insert(
        FriendshipsCompanion.insert(
          id: 'f_blocked',
          userId: subjectUser,
          friendId: 'user-blocked',
          status: const drift.Value('blocked'),
          createdAt: drift.Value(now),
        ),
      );

      // 5. Cancelled relationship
      await db.into(db.friendships).insert(
        FriendshipsCompanion.insert(
          id: 'f_cancelled',
          userId: subjectUser,
          friendId: 'user-cancelled',
          status: const drift.Value('cancelled'),
          createdAt: drift.Value(now),
        ),
      );

      // Count MUST be 0!
      final count = await db.friendsDao.watchFriendCount(subjectUser).first;
      expect(count, equals(0));

      final friendsList = await db.friendsDao.watchFriends(subjectUser).first;
      expect(friendsList, isEmpty);
    });

    test('Bidirectional friendship checks: user as userId and friendId counted accurately with reactive transitions', () async {
      const userMain = 'user-main-hub';
      const friendA = 'user-friend-alpha';
      const friendB = 'user-friend-beta';
      const friendC = 'user-friend-gamma';
      final now = DateTime.now();

      await db.into(db.userProfiles).insert(
        UserProfilesCompanion.insert(
          id: userMain,
          username: 'main_user',
          displayName: 'Main User',
          createdAt: now,
        ),
      );
      await db.into(db.userProfiles).insert(
        UserProfilesCompanion.insert(
          id: friendA,
          username: 'friend_alpha',
          displayName: 'Friend Alpha',
          createdAt: now,
        ),
      );
      await db.into(db.userProfiles).insert(
        UserProfilesCompanion.insert(
          id: friendB,
          username: 'friend_beta',
          displayName: 'Friend Beta',
          createdAt: now,
        ),
      );
      await db.into(db.userProfiles).insert(
        UserProfilesCompanion.insert(
          id: friendC,
          username: 'friend_gamma',
          displayName: 'Friend Gamma',
          createdAt: now,
        ),
      );

      // Direction 1: userMain is userId
      await db.into(db.friendships).insert(
        FriendshipsCompanion.insert(
          id: 'f_main_a',
          userId: userMain,
          friendId: friendA,
          status: const drift.Value('accepted'),
          createdAt: drift.Value(now),
        ),
      );

      // Direction 2: userMain is friendId
      await db.into(db.friendships).insert(
        FriendshipsCompanion.insert(
          id: 'f_b_main',
          userId: friendB,
          friendId: userMain,
          status: const drift.Value('accepted'),
          createdAt: drift.Value(now),
        ),
      );

      // Direction 3: pending relationship with friendC
      await db.into(db.friendships).insert(
        FriendshipsCompanion.insert(
          id: 'f_main_c_pending',
          userId: userMain,
          friendId: friendC,
          status: const drift.Value('pending'),
          createdAt: drift.Value(now),
        ),
      );

      // Initial count must be 2
      var count = await db.friendsDao.watchFriendCount(userMain).first;
      expect(count, equals(2));

      var friends = await db.friendsDao.watchFriends(userMain).first;
      expect(friends.map((p) => p.id).toSet(), equals({friendA, friendB}));

      // Reactive transition: friendC accepts request!
      await (db.update(db.friendships)..where((t) => t.id.equals('f_main_c_pending'))).write(
        const FriendshipsCompanion(
          status: drift.Value('accepted'),
        ),
      );

      // Count reactively increments to 3
      count = await db.friendsDao.watchFriendCount(userMain).first;
      expect(count, equals(3));

      friends = await db.friendsDao.watchFriends(userMain).first;
      expect(friends.map((p) => p.id).toSet(), equals({friendA, friendB, friendC}));

      // Soft delete friendship with friendA
      await (db.update(db.friendships)..where((t) => t.id.equals('f_main_a'))).write(
        const FriendshipsCompanion(
          isDeleted: drift.Value(true),
        ),
      );

      // Count reactively decrements back to 2
      count = await db.friendsDao.watchFriendCount(userMain).first;
      expect(count, equals(2));

      friends = await db.friendsDao.watchFriends(userMain).first;
      expect(friends.map((p) => p.id).toSet(), equals({friendB, friendC}));
    });
  });

  // ---------------------------------------------------------------------------
  // GROUP 3: SCOPED FRIENDS HUB SCREEN ISOLATION & QUERY PARAMETER
  // ---------------------------------------------------------------------------
  group('Adversarial Challenge: Scoped Friends Hub Isolation', () {
    testWidgets('FriendsHubScreen strictly isolates friend lists by userId query parameter', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const userOne = 'user-scoped-one';
      const userTwo = 'user-scoped-two';
      const friendOfOne = 'user-friend-of-one';
      const friendOfTwo = 'user-friend-of-two';
      final now = DateTime.now();

      await db.into(db.userProfiles).insert(
        UserProfilesCompanion.insert(
          id: userOne,
          username: 'user_one',
          displayName: 'User One',
          createdAt: now,
        ),
      );
      await db.into(db.userProfiles).insert(
        UserProfilesCompanion.insert(
          id: userTwo,
          username: 'user_two',
          displayName: 'User Two',
          createdAt: now,
        ),
      );
      await db.into(db.userProfiles).insert(
        UserProfilesCompanion.insert(
          id: friendOfOne,
          username: 'friend_of_one',
          displayName: 'Friend Of One',
          createdAt: now,
        ),
      );
      await db.into(db.userProfiles).insert(
        UserProfilesCompanion.insert(
          id: friendOfTwo,
          username: 'friend_of_two',
          displayName: 'Friend Of Two',
          createdAt: now,
        ),
      );

      // Link User One to Friend Of One
      await db.into(db.friendships).insert(
        FriendshipsCompanion.insert(
          id: 'f_one',
          userId: userOne,
          friendId: friendOfOne,
          status: const drift.Value('accepted'),
          createdAt: drift.Value(now),
        ),
      );

      // Link User Two to Friend Of Two
      await db.into(db.friendships).insert(
        FriendshipsCompanion.insert(
          id: 'f_two',
          userId: userTwo,
          friendId: friendOfTwo,
          status: const drift.Value('accepted'),
          createdAt: drift.Value(now),
        ),
      );

      // 1. Inspect FriendsHubScreen for User One
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            currentUserIdProvider.overrideWith((ref) => userOne),
          ],
          child: const MaterialApp(
            home: FriendsHubScreen(userId: userOne),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Must see Friend Of One
      expect(find.byKey(const Key('friend_card_user-friend-of-one')), findsOneWidget);
      // Must NOT see Friend Of Two
      expect(find.byKey(const Key('friend_card_user-friend-of-two')), findsNothing);

      // 2. Inspect FriendsHubScreen for User Two
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            currentUserIdProvider.overrideWith((ref) => userOne), // Current user is still User One
          ],
          child: const MaterialApp(
            home: FriendsHubScreen(userId: userTwo),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Must see Friend Of Two
      expect(find.byKey(const Key('friend_card_user-friend-of-two')), findsOneWidget);
      // Must NOT see Friend Of One
      expect(find.byKey(const Key('friend_card_user-friend-of-one')), findsNothing);
    });

    testWidgets('FriendsHubScreen with null userId defaults to authenticated currentUserId', (tester) async {
      const activeUser = 'user-active-auth';
      const activeFriend = 'user-friend-active';
      final now = DateTime.now();

      await db.into(db.userProfiles).insert(
        UserProfilesCompanion.insert(
          id: activeUser,
          username: 'active_auth',
          displayName: 'Active Auth',
          createdAt: now,
        ),
      );
      await db.into(db.userProfiles).insert(
        UserProfilesCompanion.insert(
          id: activeFriend,
          username: 'active_friend',
          displayName: 'Active Friend',
          createdAt: now,
        ),
      );

      await db.into(db.friendships).insert(
        FriendshipsCompanion.insert(
          id: 'f_active',
          userId: activeUser,
          friendId: activeFriend,
          status: const drift.Value('accepted'),
          createdAt: drift.Value(now),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            currentUserIdProvider.overrideWith((ref) => activeUser),
          ],
          child: const MaterialApp(
            home: FriendsHubScreen(), // No userId passed!
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('friend_card_user-friend-active')), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // GROUP 4: FULL-WIDTH ROW TAP TARGET VS ACTION BUTTON ISOLATION
  // ---------------------------------------------------------------------------
  group('Adversarial Challenge: Row Tap Target vs Action Button Isolation', () {
    testWidgets('Tapping friend_row navigates to profile, while action buttons are strictly isolated', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const activeUser = 'user-nav-test';
      const targetFriend = 'user-target-friend';
      final now = DateTime.now();

      await db.into(db.userProfiles).insert(
        UserProfilesCompanion.insert(
          id: activeUser,
          username: 'nav_user',
          displayName: 'Nav User',
          createdAt: now,
        ),
      );
      await db.into(db.userProfiles).insert(
        UserProfilesCompanion.insert(
          id: targetFriend,
          username: 'target_friend',
          displayName: 'Target Friend',
          createdAt: now,
        ),
      );

      await db.into(db.friendships).insert(
        FriendshipsCompanion.insert(
          id: 'f_nav_test',
          userId: activeUser,
          friendId: targetFriend,
          status: const drift.Value('accepted'),
          createdAt: drift.Value(now),
        ),
      );

      // Track router navigation destinations
      final visitedRoutes = <String>[];

      final testRouter = GoRouter(
        initialLocation: '/friends',
        routes: [
          GoRoute(
            path: '/friends',
            builder: (context, state) => const FriendsHubScreen(),
          ),
          GoRoute(
            path: '/profile/:id',
            builder: (context, state) {
              final id = state.pathParameters['id'] ?? '';
              visitedRoutes.add('/profile/$id');
              return Scaffold(
                key: Key('profile_screen_$id'),
                body: Text('Profile $id'),
              );
            },
          ),
          GoRoute(
            path: '/inbox/chat/:convId',
            builder: (context, state) {
              final convId = state.pathParameters['convId'] ?? '';
              visitedRoutes.add('/inbox/chat/$convId');
              return Scaffold(
                key: Key('chat_screen_$convId'),
                body: Text('Chat $convId'),
              );
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            currentUserIdProvider.overrideWith((ref) => activeUser),
          ],
          child: MaterialApp.router(
            routerConfig: testRouter,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final friendRowFinder = find.byKey(const Key('friend_row_user-target-friend'));
      expect(friendRowFinder, findsOneWidget);

      // 1. Verify friend_row is an InkWell that wraps the user info row
      final inkWell = tester.widget<InkWell>(friendRowFinder);
      expect(inkWell.onTap, isNotNull);

      // 2. Tap the friend row -> verifies navigation to /profile/user-target-friend
      await tester.tap(friendRowFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(visitedRoutes, contains('/profile/user-target-friend'));
      expect(find.byKey(const Key('profile_screen_user-target-friend')), findsOneWidget);

      // Return back to /friends
      testRouter.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(friendRowFinder, findsOneWidget);

      // 3. Tap the Message action button -> verifies navigation to /inbox/chat/... without triggering friend_row
      final messageActionFinder = find.byKey(const Key('friend_action_message_user-target-friend'));
      expect(messageActionFinder, findsOneWidget);

      visitedRoutes.clear();
      await tester.tap(messageActionFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Must have navigated to chat, NOT profile
      expect(visitedRoutes.any((r) => r.startsWith('/inbox/chat/')), isTrue);
      expect(visitedRoutes.any((r) => r.startsWith('/profile/')), isFalse);

      // Return back to /friends
      testRouter.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // 4. Tap the Trade Block action button -> opens Trade Block modal sheet
      final tradeBlockActionFinder = find.byKey(const Key('friend_action_trade_block_user-target-friend'));
      expect(tradeBlockActionFinder, findsOneWidget);

      visitedRoutes.clear();
      await tester.tap(tradeBlockActionFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Trade block modal appears; did not trigger router push
      expect(find.text('Target Friend\'s Trade Block'), findsOneWidget);
      expect(visitedRoutes, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // GROUP 5: BUSINESS FOLLOW VS FRIEND INVARIANTS & ACTIVITY WALL SCOPING
  // ---------------------------------------------------------------------------
  group('Adversarial Challenge: Business Follows & Scoped Activity Wall', () {
    testWidgets('Business profile completely excludes Friend controls and uses Follow system', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const storeId = 'store-tbs-comics';

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
          ],
          child: const MaterialApp(
            home: UserProfileScreen(profileId: storeId),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 1. Followers stat is rendered; Friends stat is completely absent
      expect(find.byKey(const Key('profile_stat_followers')), findsOneWidget);
      expect(find.byKey(const Key('profile_stat_friends')), findsNothing);

      // 2. Add Friend button is completely absent
      expect(find.byKey(const Key('profile_btn_add_friend')), findsNothing);

      // 3. Follow button is present
      final followBtn = find.byKey(const Key('profile_btn_follow'));
      expect(followBtn, findsOneWidget);
      expect(find.text('Follow'), findsOneWidget);
    });

    test('Activity Wall strictly excludes third-party posts and includes only authored or shared posts', () async {
      const wallUser = 'user-wall-subject';
      const thirdParty = 'user-third-party';
      final now = DateTime.now();

      await db.into(db.userProfiles).insert(
        UserProfilesCompanion.insert(
          id: wallUser,
          username: 'wall_user',
          displayName: 'Wall User',
          createdAt: now,
        ),
      );
      await db.into(db.userProfiles).insert(
        UserProfilesCompanion.insert(
          id: thirdParty,
          username: 'third_party',
          displayName: 'Third Party',
          createdAt: now,
        ),
      );

      // Post 1: Authored by wallUser
      await db.feedDao.createPost(
        FeedPostsCompanion.insert(
          id: 'post-wall-1',
          authorId: wallUser,
          authorUsername: '@wall_user',
          authorDisplayName: 'Wall User',
          type: 'text',
          textContent: const drift.Value('Authored by wall user'),
          createdAt: drift.Value(now),
        ),
      );

      // Post 2: Authored by thirdParty, shared by wallUser
      await db.feedDao.createPost(
        FeedPostsCompanion.insert(
          id: 'post-wall-2',
          authorId: thirdParty,
          authorUsername: '@third_party',
          authorDisplayName: 'Third Party',
          sharedByUserId: const drift.Value(wallUser),
          type: 'text',
          textContent: const drift.Value('Shared by wall user'),
          createdAt: drift.Value(now.subtract(const Duration(minutes: 5))),
        ),
      );

      // Post 3: Authored by thirdParty, mentioning wallUser in text (MUST be excluded)
      await db.feedDao.createPost(
        FeedPostsCompanion.insert(
          id: 'post-wall-3-mention',
          authorId: thirdParty,
          authorUsername: '@third_party',
          authorDisplayName: 'Third Party',
          type: 'text',
          textContent: const drift.Value('Hey @wall_user! Great game!'),
          createdAt: drift.Value(now.subtract(const Duration(minutes: 10))),
        ),
      );

      // Post 4: Third party general post (MUST be excluded)
      await db.feedDao.createPost(
        FeedPostsCompanion.insert(
          id: 'post-wall-4-general',
          authorId: thirdParty,
          authorUsername: '@third_party',
          authorDisplayName: 'Third Party',
          type: 'text',
          textContent: const drift.Value('Unrelated general post'),
          createdAt: drift.Value(now.subtract(const Duration(minutes: 15))),
        ),
      );

      final wallPosts = await db.feedDao.watchUserWallPosts(wallUser).first;
      final postIds = wallPosts.map((p) => p.id).toList();

      expect(postIds, contains('post-wall-1'));
      expect(postIds, contains('post-wall-2'));
      expect(postIds, isNot(contains('post-wall-3-mention')));
      expect(postIds, isNot(contains('post-wall-4-general')));
      expect(postIds.length, equals(2));
    });
  });
}
