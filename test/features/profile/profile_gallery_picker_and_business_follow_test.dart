// Copyright (c) 2026 Countr. All rights reserved.
// Unit and Widget verification tests for Milestone 3 (R3):
// - Avatar local saving and cascade to feed posts
// - Business profile followable (UserFollows table, [Follow]/[Following ✓] button, Followers stat)
// - Business follow encounter priority on Home Feed

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/feed/data/social_seed_service.dart';
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

  group('Milestone 3 (R3): Business Follows & Feed Priority', () {
    test('toggleFollow adds and removes follow record in SQLite reactively', () async {
      const followerId = 'user-edh-rec-fanatic';
      const targetUserId = 'store-tbs-comics';

      // Initially not following
      var isFollowing = await db.feedDao.watchIsFollowing(
        followerId,
        targetUserId,
      ).first;
      expect(isFollowing, isFalse);

      var followersCount = await db.feedDao.getFollowersCount(targetUserId);
      expect(followersCount, equals(0));

      // Toggle follow -> should follow
      final followed = await db.feedDao.toggleFollow(
        followerId,
        targetUserId,
      );
      expect(followed, isTrue);

      isFollowing = await db.feedDao.watchIsFollowing(
        followerId,
        targetUserId,
      ).first;
      expect(isFollowing, isTrue);

      followersCount = await db.feedDao.getFollowersCount(targetUserId);
      expect(followersCount, equals(1));

      // Toggle follow again -> should unfollow (soft delete)
      final unfollowed = await db.feedDao.toggleFollow(
        followerId,
        targetUserId,
      );
      expect(unfollowed, isFalse);

      isFollowing = await db.feedDao.watchIsFollowing(
        followerId,
        targetUserId,
      ).first;
      expect(isFollowing, isFalse);

      followersCount = await db.feedDao.getFollowersCount(targetUserId);
      expect(followersCount, equals(0));
    });

    test('Following a business gives that business encounter priority in watchFeedPosts', () async {
      const followerId = 'user-current-me';
      const businessId = 'store-tbs-comics';

      // Insert an older post by business and a newer post by another user
      final now = DateTime.now();
      await db.feedDao.createPost(
        FeedPostsCompanion.insert(
          id: 'post-regular-new',
          authorId: 'user-spicy-brew-master',
          authorUsername: '@SpicyBrewMaster',
          authorDisplayName: 'Spicy Brew Master',
          type: 'text',
          textContent: const drift.Value('Regular post newer'),
          createdAt: drift.Value(now),
        ),
      );

      await db.feedDao.createPost(
        FeedPostsCompanion.insert(
          id: 'post-business-old',
          authorId: businessId,
          authorUsername: '@TBSComics',
          authorDisplayName: 'TBS Comics',
          type: 'text',
          textContent: const drift.Value('Business post older'),
          createdAt: drift.Value(now.subtract(const Duration(hours: 2))),
        ),
      );

      // Without follow: newer post comes first
      var posts = await db.feedDao.watchFeedPosts(currentUserId: followerId).first;
      final regularIndexBefore = posts.indexWhere((p) => p.id == 'post-regular-new');
      final businessIndexBefore = posts.indexWhere((p) => p.id == 'post-business-old');
      expect(regularIndexBefore, lessThan(businessIndexBefore));

      // Now follow the business
      await db.feedDao.toggleFollow(followerId, businessId);

      // With follow: business post is boosted to top priority!
      posts = await db.feedDao.watchFeedPosts(currentUserId: followerId).first;
      final regularIndexAfter = posts.indexWhere((p) => p.id == 'post-regular-new');
      final businessIndexAfter = posts.indexWhere((p) => p.id == 'post-business-old');
      expect(businessIndexAfter, lessThan(regularIndexAfter));
      expect(businessIndexAfter, equals(0)); // Business post is now first!
    });
  });

  group('Milestone 3 (R3): Avatar Update & Cascade to Feed Posts', () {
    test('updateAvatar in UserProfileDao cascades to feed posts author avatar', () async {
      const userId = 'user-edh-rec-fanatic';
      const newAvatarUrl = '/data/user/0/app/avatars/user-edh-rec-fanatic_12345.jpg';

      // Insert a post authored by userId
      await db.feedDao.createPost(
        FeedPostsCompanion.insert(
          id: 'post-edh-1',
          authorId: userId,
          authorUsername: '@EDH_Rec_Fanatic',
          authorDisplayName: 'EDH Rec Fanatic',
          type: 'text',
          authorAvatarUrl: const drift.Value('https://images.unsplash.com/old-avatar.jpg'),
          textContent: const drift.Value('Check out my Commander deck!'),
        ),
      );

      // Verify initial state
      var profile = await db.userProfileDao.getProfile(userId);
      expect(profile!.avatarUrl, isNot(equals(newAvatarUrl)));

      var post = await db.feedDao.getPostById('post-edh-1');
      expect(post!.authorAvatarUrl, isNot(equals(newAvatarUrl)));

      // Perform update and cascade
      await db.userProfileDao.updateAvatar(userId, newAvatarUrl);
      await db.feedDao.updateAuthorAvatar(userId, newAvatarUrl);

      // Verify profile is updated
      profile = await db.userProfileDao.getProfile(userId);
      expect(profile!.avatarUrl, equals(newAvatarUrl));

      // Verify post authorAvatarUrl cascaded
      post = await db.feedDao.getPostById('post-edh-1');
      expect(post!.authorAvatarUrl, equals(newAvatarUrl));
    });
  });

  group('Milestone 3 (R3): Profile Screen UI & Business Follow Button', () {
    testWidgets('Business profile displays Followers count and [Follow]/[Following ✓] button', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const businessId = 'store-tbs-comics';

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
          ],
          child: const MaterialApp(
            home: UserProfileScreen(profileId: businessId),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check Followers stat is present and Friends stat is NOT present
      expect(find.byKey(const Key('profile_stat_followers')), findsOneWidget);
      expect(find.text('Followers'), findsOneWidget);
      expect(find.byKey(const Key('profile_stat_friends')), findsNothing);

      // Check Add Friend button is NOT present
      expect(find.text('Add Friend'), findsNothing);
      expect(find.byKey(const Key('profile_btn_add_friend')), findsNothing);

      // Check Follow button is present with [Follow] label
      final followBtnFinder = find.byKey(const Key('profile_btn_follow'));
      expect(followBtnFinder, findsOneWidget);
      expect(find.text('Follow'), findsOneWidget);

      // Tap [Follow] button
      await tester.ensureVisible(followBtnFinder);
      await tester.tap(followBtnFinder);
      await tester.pumpAndSettle();

      // State toggles to [Following ✓]
      expect(find.text('Following ✓'), findsOneWidget);

      // Followers count updates in SQLite
      final count = await db.feedDao.getFollowersCount(businessId);
      expect(count, equals(1));

      // Tap [Following ✓] button to unfollow
      await tester.ensureVisible(followBtnFinder);
      await tester.tap(followBtnFinder);
      await tester.pumpAndSettle();

      expect(find.text('Follow'), findsOneWidget);
      final countAfter = await db.feedDao.getFollowersCount(businessId);
      expect(countAfter, equals(0));
    });
  });
}
