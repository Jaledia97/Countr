// Copyright (c) 2026 Countr. All rights reserved.
// Challenger 2: Adversarial Stress Test Harness for Milestone 3 (R3)
// Scope:
// 1. Business profile follow button toggle ([Follow] <-> [Following ✓]), followers count,
//    and home feed ranking boost across mixed business and personal posts.
// 2. Scoped Profile Activity Wall: zero unrelated posts leak onto walls
//    (strict authorId == profileUserId || sharedByUserId == profileUserId filtering).
// 3. Home search bar internal suffixIcon clear/close button behaviors when text is empty vs populated.

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/feed/data/social_seed_service.dart';
import 'package:countr/features/feed/presentation/screens/feed_screen.dart';
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

  group('CHALLENGER 2 [Area 1]: Business Follow & Home Feed Ranking Boost', () {
    test('Multi-user follow concurrency and rapid toggle stress on SQLite follow state', () async {
      const businessA = 'store-tbs-comics';
      const businessB = 'store-other-lgs';

      final now = DateTime.now();
      // Insert another business profile for cross-entity isolation testing
      await db.userProfileDao.upsertProfile(
        UserProfilesCompanion.insert(
          id: businessB,
          username: 'OtherLGS',
          displayName: 'Other LGS Store',
          accountType: const drift.Value('business'),
          isVerifiedBusiness: const drift.Value(true),
          createdAt: now,
          updatedAt: drift.Value(now),
        ),
      );

      // Verify initial followers counts
      expect(await db.feedDao.getFollowersCount(businessA), equals(0));
      expect(await db.feedDao.getFollowersCount(businessB), equals(0));

      final followers = [
        'user-follower-1',
        'user-follower-2',
        'user-follower-3',
        'user-follower-4',
        'user-follower-5',
      ];

      // 1. All 5 followers follow businessA
      for (final f in followers) {
        final followed = await db.feedDao.toggleFollow(f, businessA);
        expect(followed, isTrue);
      }
      expect(await db.feedDao.getFollowersCount(businessA), equals(5));
      expect(await db.feedDao.getFollowersCount(businessB), equals(0)); // Cross-entity isolation

      // 2. 2 followers also follow businessB
      await db.feedDao.toggleFollow(followers[0], businessB);
      await db.feedDao.toggleFollow(followers[1], businessB);
      expect(await db.feedDao.getFollowersCount(businessA), equals(5));
      expect(await db.feedDao.getFollowersCount(businessB), equals(2));

      // 3. Rapid toggle stress: follower 1 toggles businessA 10 times (even count -> ends in initial state)
      // follower 1 is currently following businessA
      for (int i = 0; i < 10; i++) {
        await db.feedDao.toggleFollow(followers[0], businessA);
      }
      // Since it was true, after 10 toggles it must still be true!
      expect(await db.feedDao.watchIsFollowing(followers[0], businessA).first, isTrue);
      expect(await db.feedDao.getFollowersCount(businessA), equals(5));

      // 4. Followers 2 and 4 unfollow businessA
      final unfollow2 = await db.feedDao.toggleFollow(followers[1], businessA);
      final unfollow4 = await db.feedDao.toggleFollow(followers[3], businessA);
      expect(unfollow2, isFalse);
      expect(unfollow4, isFalse);
      expect(await db.feedDao.getFollowersCount(businessA), equals(3));

      // Verify specific follower states
      expect(await db.feedDao.watchIsFollowing(followers[0], businessA).first, isTrue);
      expect(await db.feedDao.watchIsFollowing(followers[1], businessA).first, isFalse);
      expect(await db.feedDao.watchIsFollowing(followers[2], businessA).first, isTrue);
      expect(await db.feedDao.watchIsFollowing(followers[3], businessA).first, isFalse);
      expect(await db.feedDao.watchIsFollowing(followers[4], businessA).first, isTrue);

      // businessB followers count unchanged
      expect(await db.feedDao.getFollowersCount(businessB), equals(2));
    });

    test('Complex Home Feed ranking boost across interleaved business, followed, and personal posts', () async {
      const viewerId = 'user-viewer-adversarial';
      const bizAlpha = 'biz-alpha';
      const bizBeta = 'biz-beta';
      const bizGamma = 'biz-gamma-unfollowed';
      const userPersonal1 = 'user-personal-1';
      const userPersonal2 = 'user-personal-2';

      final t0 = DateTime.now();

      // Clear existing feed posts from seed for clean deterministic ordering verification
      await db.delete(db.feedPosts).go();

      // Post 1: Personal (newest)
      await db.feedDao.createPost(
        FeedPostsCompanion.insert(
          id: 'post-personal-newest',
          authorId: userPersonal1,
          authorUsername: '@personal1',
          authorDisplayName: 'Personal One',
          type: 'text',
          textContent: const drift.Value('Newest personal post'),
          createdAt: drift.Value(t0),
        ),
      );

      // Post 2: Biz Gamma (unfollowed business, recent)
      await db.feedDao.createPost(
        FeedPostsCompanion.insert(
          id: 'post-biz-gamma',
          authorId: bizGamma,
          authorUsername: '@bizGamma',
          authorDisplayName: 'Biz Gamma',
          type: 'text',
          textContent: const drift.Value('Biz Gamma post'),
          createdAt: drift.Value(t0.subtract(const Duration(minutes: 15))),
        ),
      );

      // Post 3: Biz Alpha (will be followed, older)
      await db.feedDao.createPost(
        FeedPostsCompanion.insert(
          id: 'post-biz-alpha-recent',
          authorId: bizAlpha,
          authorUsername: '@bizAlpha',
          authorDisplayName: 'Biz Alpha',
          type: 'text',
          textContent: const drift.Value('Biz Alpha recent post'),
          createdAt: drift.Value(t0.subtract(const Duration(minutes: 30))),
        ),
      );

      // Post 4: Personal 2 (older)
      await db.feedDao.createPost(
        FeedPostsCompanion.insert(
          id: 'post-personal-mid',
          authorId: userPersonal2,
          authorUsername: '@personal2',
          authorDisplayName: 'Personal Two',
          type: 'text',
          textContent: const drift.Value('Mid personal post'),
          createdAt: drift.Value(t0.subtract(const Duration(hours: 1))),
        ),
      );

      // Post 5: Biz Beta (will be followed, even older)
      await db.feedDao.createPost(
        FeedPostsCompanion.insert(
          id: 'post-biz-beta',
          authorId: bizBeta,
          authorUsername: '@bizBeta',
          authorDisplayName: 'Biz Beta',
          type: 'text',
          textContent: const drift.Value('Biz Beta post'),
          createdAt: drift.Value(t0.subtract(const Duration(hours: 2))),
        ),
      );

      // Post 6: Biz Alpha (ancient post)
      await db.feedDao.createPost(
        FeedPostsCompanion.insert(
          id: 'post-biz-alpha-ancient',
          authorId: bizAlpha,
          authorUsername: '@bizAlpha',
          authorDisplayName: 'Biz Alpha',
          type: 'text',
          textContent: const drift.Value('Biz Alpha ancient post'),
          createdAt: drift.Value(t0.subtract(const Duration(hours: 5))),
        ),
      );

      // Post 7: Soft-deleted post from bizAlpha (must NEVER appear anywhere)
      await db.feedDao.createPost(
        FeedPostsCompanion.insert(
          id: 'post-biz-alpha-deleted',
          authorId: bizAlpha,
          authorUsername: '@bizAlpha',
          authorDisplayName: 'Biz Alpha',
          type: 'text',
          textContent: const drift.Value('Deleted biz post'),
          isDeleted: const drift.Value(true),
          createdAt: drift.Value(t0.add(const Duration(hours: 1))), // even with future timestamp
        ),
      );

      // --- PHASE A: Zero follows active ---
      var feed = await db.feedDao.watchFeedPosts(currentUserId: viewerId).first;
      var feedIds = feed.map((p) => p.id).toList();

      expect(feedIds, equals([
        'post-personal-newest',
        'post-biz-gamma',
        'post-biz-alpha-recent',
        'post-personal-mid',
        'post-biz-beta',
        'post-biz-alpha-ancient',
      ]));
      expect(feedIds, isNot(contains('post-biz-alpha-deleted')));

      // --- PHASE B: Follow bizAlpha only ---
      await db.feedDao.toggleFollow(viewerId, bizAlpha);

      feed = await db.feedDao.watchFeedPosts(currentUserId: viewerId).first;
      feedIds = feed.map((p) => p.id).toList();

      // Biz Alpha's 2 active posts must be boosted to the very top in chronological order!
      expect(feedIds.sublist(0, 2), equals([
        'post-biz-alpha-recent',
        'post-biz-alpha-ancient',
      ]));
      // The remaining posts follow in chronological order:
      expect(feedIds.sublist(2), equals([
        'post-personal-newest',
        'post-biz-gamma',
        'post-personal-mid',
        'post-biz-beta',
      ]));

      // --- PHASE C: Follow bizBeta as well (multiple businesses followed) ---
      await db.feedDao.toggleFollow(viewerId, bizBeta);

      feed = await db.feedDao.watchFeedPosts(currentUserId: viewerId).first;
      feedIds = feed.map((p) => p.id).toList();

      // Both bizAlpha and bizBeta posts boosted to top 3, sorted chronologically among themselves:
      // bizAlpha recent (-30m) -> bizBeta (-2h) -> bizAlpha ancient (-5h)
      expect(feedIds.sublist(0, 3), equals([
        'post-biz-alpha-recent',
        'post-biz-beta',
        'post-biz-alpha-ancient',
      ]));
      // Unfollowed posts remain:
      expect(feedIds.sublist(3), equals([
        'post-personal-newest',
        'post-biz-gamma',
        'post-personal-mid',
      ]));

      // --- PHASE D: Unfollow bizAlpha (soft-deleted follow must NOT give boost) ---
      final unfollowed = await db.feedDao.toggleFollow(viewerId, bizAlpha);
      expect(unfollowed, isFalse);

      feed = await db.feedDao.watchFeedPosts(currentUserId: viewerId).first;
      feedIds = feed.map((p) => p.id).toList();

      // Only bizBeta is followed now!
      expect(feedIds.first, equals('post-biz-beta'));
      // All other posts follow in chronological order (including bizAlpha's unboosted posts):
      expect(feedIds.sublist(1), equals([
        'post-personal-newest',
        'post-biz-gamma',
        'post-biz-alpha-recent',
        'post-personal-mid',
        'post-biz-alpha-ancient',
      ]));
    });

    testWidgets('UI Follow button toggle updates state, label, icon, and followers count reactively', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const targetBizId = 'store-tbs-comics';
      const currentUserId = 'user-current-me';

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            currentUserIdProvider.overrideWith((ref) => currentUserId),
          ],
          child: const MaterialApp(
            home: UserProfileScreen(profileId: targetBizId),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Initial State: Unfollowed
      final followBtnFinder = find.byKey(const Key('profile_btn_follow'));
      expect(followBtnFinder, findsOneWidget);
      expect(find.text('Follow'), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);

      final followersStatFinder = find.byKey(const Key('profile_stat_followers'));
      expect(followersStatFinder, findsOneWidget);
      expect(find.descendant(of: followersStatFinder, matching: find.text('0')), findsOneWidget);
      expect(find.text('Followers'), findsOneWidget);

      // Friends stat and Add Friend button must be absent for business profile
      expect(find.byKey(const Key('profile_stat_friends')), findsNothing);
      expect(find.byKey(const Key('profile_btn_add_friend')), findsNothing);

      // 2. Tap [Follow] -> transitions to [Following ✓]
      await tester.ensureVisible(followBtnFinder);
      await tester.tap(followBtnFinder);
      await tester.pumpAndSettle();

      expect(find.text('Following ✓'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.descendant(of: followersStatFinder, matching: find.text('1')), findsOneWidget);

      // 3. Tap [Following ✓] -> transitions back to [Follow]
      await tester.ensureVisible(followBtnFinder);
      await tester.tap(followBtnFinder);
      await tester.pumpAndSettle();

      expect(find.text('Follow'), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
      expect(find.descendant(of: followersStatFinder, matching: find.text('0')), findsOneWidget);
    });
  });

  group('CHALLENGER 2 [Area 2]: Scoped Profile Activity Wall Zero Leakage', () {
    test('Adversarial isolation: Zero unrelated posts leak onto profile wall', () async {
      const profileUser = 'user-target-profile';
      const otherUserA = 'user-other-a';
      const otherUserB = 'user-other-b';

      final now = DateTime.now();

      // Clear posts table
      await db.delete(db.feedPosts).go();

      // Distractor 1: Unrelated post by other user
      await db.feedDao.createPost(
        FeedPostsCompanion.insert(
          id: 'leak-unrelated-post',
          authorId: otherUserA,
          authorUsername: '@otherA',
          authorDisplayName: 'Other User A',
          type: 'text',
          textContent: const drift.Value('Completely unrelated discussion'),
          createdAt: drift.Value(now),
        ),
      );

      // Distractor 2: Text mention of @user-target-profile by other user
      await db.feedDao.createPost(
        FeedPostsCompanion.insert(
          id: 'leak-username-mention',
          authorId: otherUserA,
          authorUsername: '@otherA',
          authorDisplayName: 'Other User A',
          type: 'text',
          textContent: const drift.Value('Hey @user-target-profile what do you think?'),
          createdAt: drift.Value(now.subtract(const Duration(minutes: 5))),
        ),
      );

      // Distractor 3: Text mention of display name
      await db.feedDao.createPost(
        FeedPostsCompanion.insert(
          id: 'leak-displayname-mention',
          authorId: otherUserB,
          authorUsername: '@otherB',
          authorDisplayName: 'Other User B',
          type: 'text',
          textContent: const drift.Value('Great trading with Target Profile User today'),
          createdAt: drift.Value(now.subtract(const Duration(minutes: 10))),
        ),
      );

      // Distractor 4: Post by other user with same location tag
      await db.feedDao.createPost(
        FeedPostsCompanion.insert(
          id: 'leak-location-tag-match',
          authorId: otherUserB,
          authorUsername: '@otherB',
          authorDisplayName: 'Other User B',
          type: 'text',
          locationTag: const drift.Value('Local Game Store'),
          textContent: const drift.Value('At Local Game Store playing commander'),
          createdAt: drift.Value(now.subtract(const Duration(minutes: 15))),
        ),
      );

      // Distractor 5: Post shared by another user (NOT target)
      await db.feedDao.createPost(
        FeedPostsCompanion.insert(
          id: 'leak-shared-by-other',
          authorId: otherUserA,
          authorUsername: '@otherA',
          authorDisplayName: 'Other User A',
          sharedByUserId: const drift.Value(otherUserB),
          type: 'text',
          textContent: const drift.Value('Post shared by user B'),
          createdAt: drift.Value(now.subtract(const Duration(minutes: 20))),
        ),
      );

      // Distractor 6: Soft-deleted post authored by target user
      await db.feedDao.createPost(
        FeedPostsCompanion.insert(
          id: 'leak-deleted-authored-post',
          authorId: profileUser,
          authorUsername: '@targetProfile',
          authorDisplayName: 'Target Profile',
          isDeleted: const drift.Value(true),
          type: 'text',
          textContent: const drift.Value('Deleted post by target'),
          createdAt: drift.Value(now.subtract(const Duration(minutes: 25))),
        ),
      );

      // Distractor 7: Soft-deleted post shared by target user
      await db.feedDao.createPost(
        FeedPostsCompanion.insert(
          id: 'leak-deleted-shared-post',
          authorId: otherUserA,
          authorUsername: '@otherA',
          authorDisplayName: 'Other User A',
          sharedByUserId: const drift.Value(profileUser),
          isDeleted: const drift.Value(true),
          type: 'text',
          textContent: const drift.Value('Deleted shared post by target'),
          createdAt: drift.Value(now.subtract(const Duration(minutes: 30))),
        ),
      );

      // --- Legitimate Posts for Target User ---

      // Valid 1: Authored by target user
      await db.feedDao.createPost(
        FeedPostsCompanion.insert(
          id: 'valid-authored-1',
          authorId: profileUser,
          authorUsername: '@targetProfile',
          authorDisplayName: 'Target Profile',
          type: 'text',
          textContent: const drift.Value('My personal pull!'),
          createdAt: drift.Value(now.subtract(const Duration(hours: 1))),
        ),
      );

      // Valid 2: Shared by target user (repost of otherUserA's post)
      await db.feedDao.createPost(
        FeedPostsCompanion.insert(
          id: 'valid-shared-1',
          authorId: otherUserA,
          authorUsername: '@otherA',
          authorDisplayName: 'Other User A',
          sharedByUserId: const drift.Value(profileUser),
          type: 'text',
          textContent: const drift.Value('Shared from User A'),
          createdAt: drift.Value(now.subtract(const Duration(hours: 2))),
        ),
      );

      // Valid 3: Another authored post
      await db.feedDao.createPost(
        FeedPostsCompanion.insert(
          id: 'valid-authored-2',
          authorId: profileUser,
          authorUsername: '@targetProfile',
          authorDisplayName: 'Target Profile',
          type: 'text',
          textContent: const drift.Value('Second personal update'),
          createdAt: drift.Value(now.subtract(const Duration(hours: 3))),
        ),
      );

      // Query target profile's activity wall
      final wallPosts = await db.feedDao.watchUserWallPosts(profileUser).first;
      final wallPostIds = wallPosts.map((p) => p.id).toList();

      // VERIFICATION:
      // Exactly 3 legitimate posts must be returned
      expect(wallPostIds.length, equals(3));
      expect(wallPostIds, equals(['valid-authored-1', 'valid-shared-1', 'valid-authored-2']));

      // Assert zero leak of any distractor
      expect(wallPostIds, isNot(contains('leak-unrelated-post')));
      expect(wallPostIds, isNot(contains('leak-username-mention')));
      expect(wallPostIds, isNot(contains('leak-displayname-mention')));
      expect(wallPostIds, isNot(contains('leak-location-tag-match')));
      expect(wallPostIds, isNot(contains('leak-shared-by-other')));
      expect(wallPostIds, isNot(contains('leak-deleted-authored-post')));
      expect(wallPostIds, isNot(contains('leak-deleted-shared-post')));

      // Mutual Wall Isolation: Query otherUserA's wall
      final otherAWall = await db.feedDao.watchUserWallPosts(otherUserA).first;
      final otherAIds = otherAWall.map((p) => p.id).toList();

      // otherUserA authored 'leak-unrelated-post', 'leak-username-mention', 'leak-shared-by-other', 'valid-shared-1'
      expect(otherAIds, contains('leak-unrelated-post'));
      expect(otherAIds, contains('valid-shared-1')); // since otherUserA is authorId
      expect(otherAIds, isNot(contains('valid-authored-1'))); // target's post must NOT leak to otherUserA
      expect(otherAIds, isNot(contains('valid-authored-2')));
    });

    testWidgets('UI Activity Wall renders empty state placeholder when user has no wall posts', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Clear all feed posts
      await db.delete(db.feedPosts).go();

      const profileId = 'user-spicy-brew-master';

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
          ],
          child: const MaterialApp(
            home: UserProfileScreen(profileId: profileId),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Activity Wall empty state container must be present
      expect(find.byKey(const Key('profile_activity_wall')), findsOneWidget);
      expect(
        find.text('No posts yet. Recent card pulls, deck shares, and trades will appear here.'),
        findsOneWidget,
      );

      // Now insert a post authored by this user
      await db.feedDao.createPost(
        FeedPostsCompanion.insert(
          id: 'spicy-new-post-1',
          authorId: profileId,
          authorUsername: '@SpicyBrewMaster',
          authorDisplayName: 'Spicy Brew Master',
          type: 'text',
          textContent: const drift.Value('Brewing a new deck today!'),
          createdAt: drift.Value(DateTime.now()),
        ),
      );

      // Invalidate stream provider to refresh UI
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Empty state placeholder should disappear and post text should appear
      expect(find.byKey(const Key('profile_activity_wall')), findsNothing);
      expect(find.text('Brewing a new deck today!'), findsOneWidget);
    });
  });

  group('CHALLENGER 2 [Area 3]: Home Search Bar suffixIcon Clear/Close Behaviors', () {
    testWidgets('Search bar suffixIcon transitions between close and clear when populated vs empty', (tester) async {
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
            home: FeedScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Initial state: Search is closed
      final openBtnFinder = find.byKey(const Key('feed_appbar_search_button'));
      expect(openBtnFinder, findsOneWidget);
      expect(find.byKey(const Key('home_search_input')), findsNothing);

      // Tap open button -> Search bar opens
      await tester.tap(openBtnFinder);
      await tester.pumpAndSettle();

      final searchInputFinder = find.byKey(const Key('home_search_input'));
      expect(searchInputFinder, findsOneWidget);
      expect(find.byKey(const Key('feed_appbar_search_button')), findsNothing);

      // 1. Text is empty: suffixIcon is home_search_close_button
      expect(find.byKey(const Key('home_search_close_button')), findsOneWidget);
      expect(find.byKey(const Key('home_search_clear_button')), findsNothing);

      // 2. Type text -> suffixIcon switches to home_search_clear_button
      await tester.enterText(searchInputFinder, 'Sol Ring');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('home_search_clear_button')), findsOneWidget);
      expect(find.byKey(const Key('home_search_close_button')), findsNothing);

      // 3. Tap clear button -> text clears to empty, search remains open, suffixIcon switches to close
      await tester.tap(find.byKey(const Key('home_search_clear_button')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // TextField is still open and empty
      expect(find.byKey(const Key('home_search_input')), findsOneWidget);
      final textWidget = tester.widget<TextField>(searchInputFinder);
      expect(textWidget.controller?.text ?? '', isEmpty);
      expect(find.byKey(const Key('home_search_close_button')), findsOneWidget);
      expect(find.byKey(const Key('home_search_clear_button')), findsNothing);

      // 4. Type text again, then erase it completely via enterText('') (simulating keyboard backspace)
      await tester.enterText(searchInputFinder, 'Rhystic');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('home_search_clear_button')), findsOneWidget);

      await tester.enterText(searchInputFinder, '');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('home_search_close_button')), findsOneWidget);
      expect(find.byKey(const Key('home_search_clear_button')), findsNothing);

      // 5. Tap close button -> Search bar closes cleanly and external AppBar search button returns
      await tester.tap(find.byKey(const Key('home_search_close_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('home_search_input')), findsNothing);
      expect(find.byKey(const Key('feed_appbar_search_button')), findsOneWidget);
    });

    testWidgets('Adversarial Stress: SuffixIcon desynchronization on whitespace-only input and debounce latency', (tester) async {
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
            home: FeedScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open search bar
      await tester.tap(find.byKey(const Key('feed_appbar_search_button')));
      await tester.pumpAndSettle();

      final searchInputFinder = find.byKey(const Key('home_search_input'));

      // 1. Latency test: Type 'Mox' and pump 0ms (immediate frame before 200ms debounce)
      await tester.enterText(searchInputFinder, 'Mox');
      await tester.pump();

      // SuffixIcon reacts immediately on keystroke without waiting for 200ms debounce
      final hasImmediateClear = find.byKey(const Key('home_search_clear_button')).evaluate().isNotEmpty;
      expect(hasImmediateClear, isTrue, reason: 'SuffixIcon update must react immediately on keystroke without waiting for debounce timer');

      // 2. Clear out
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('home_search_clear_button')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // 3. Whitespace test: Enter whitespace '   '
      await tester.enterText(searchInputFinder, '   ');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // In controller, text is '   ' (length 3, isNotEmpty == true)
      final controllerText = tester.widget<TextField>(searchInputFinder).controller!.text;
      expect(controllerText, equals('   '));
      expect(controllerText.isNotEmpty, isTrue);

      final hasClearOnWhitespace = find.byKey(const Key('home_search_clear_button')).evaluate().isNotEmpty;
      final hasCloseOnWhitespace = find.byKey(const Key('home_search_close_button')).evaluate().isNotEmpty;

      // When trim() is used in provider without setState on controller listener,
      // suffixIcon fails to show clear button and instead shows close button.
      expect(
        hasCloseOnWhitespace,
        isFalse,
        reason: 'Close button must not be displayed when controller text is non-empty',
      );
      expect(
        hasClearOnWhitespace,
        isTrue,
        reason: 'DEFECT: When controller has whitespace, suffixIcon is expected to show clear button, but showed close button due to lack of setState on controller listener',
      );
    });
  });
}
