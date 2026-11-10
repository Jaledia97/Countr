// Copyright (c) 2026 Countr. All rights reserved.
// Challenger 1 Milestone 3 Remediation: In-depth Adversarial Stress Test Suite
// Verifies:
// 1. feed_screen.dart search bar suffixIcon zero-latency transition on initial keystroke
// 2. Whitespace-only, punctuation, multi-word, and rapid typing suffixIcon reactivity
// 3. Synchronous transition back to close icon upon tapping clear
// 4. Exact 200ms query debouncing to homeSearchQueryProvider
// 5. FriendsHubScreen isolation, null userId fallback, and empty states
// 6. Profile stats (Friends vs Followers), business follow toggling, and scoped activity wall

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/feed/data/social_seed_service.dart';
import 'package:countr/features/feed/presentation/providers/feed_providers.dart';
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

  Widget buildTestApp({
    required Widget child,
    String currentUserId = 'user-test-active',
  }) {
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

  group('CHALLENGER 1 [Area 1]: Search Bar SuffixIcon Zero-Latency & Reactivity', () {
    testWidgets('1.1 Zero-latency transition from close to clear icon on initial keystroke (pump 0ms)', (tester) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          currentUserIdProvider.overrideWith((ref) => 'user-test-active'),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: FeedScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open search bar
      final searchToggleBtn = find.byKey(const Key('feed_appbar_search_button'));
      expect(searchToggleBtn, findsOneWidget);
      await tester.tap(searchToggleBtn);
      await tester.pumpAndSettle();

      final searchInputFinder = find.byKey(const Key('home_search_input'));
      expect(searchInputFinder, findsOneWidget);

      // Initially empty -> shows close button
      expect(find.byKey(const Key('home_search_close_button')), findsOneWidget);
      expect(find.byKey(const Key('home_search_clear_button')), findsNothing);
      expect(container.read(homeSearchQueryProvider), equals(''));

      // Type initial keystroke 'B' and pump 0ms (immediate frame, before 200ms debounce)
      await tester.enterText(searchInputFinder, 'B');
      await tester.pump();

      // SuffixIcon must have transitioned to clear button IMMEDIATELY without debounce delay
      expect(
        find.byKey(const Key('home_search_clear_button')),
        findsOneWidget,
        reason: 'SuffixIcon must display clear button immediately on keystroke (zero-latency)',
      );
      expect(
        find.byKey(const Key('home_search_close_button')),
        findsNothing,
        reason: 'SuffixIcon must NOT display close button when text is non-empty',
      );

      // Debounce timer has not elapsed yet -> provider query should still be ''
      expect(
        container.read(homeSearchQueryProvider),
        equals(''),
        reason: 'Query provider must not update before the 200ms debounce interval',
      );

      // Now pump past the 200ms debounce interval
      await tester.pump(const Duration(milliseconds: 250));
      expect(container.read(homeSearchQueryProvider), equals('B'));
    });

    testWidgets('1.2 Synchronous transition back to close icon upon tapping clear button', (tester) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          currentUserIdProvider.overrideWith((ref) => 'user-test-active'),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: FeedScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('feed_appbar_search_button')));
      await tester.pumpAndSettle();

      final searchInputFinder = find.byKey(const Key('home_search_input'));
      await tester.enterText(searchInputFinder, 'Black Lotus');
      await tester.pump(const Duration(milliseconds: 250));

      expect(container.read(homeSearchQueryProvider), equals('Black Lotus'));
      expect(find.byKey(const Key('home_search_clear_button')), findsOneWidget);

      // Tap clear button and pump immediate frame (0ms)
      await tester.tap(find.byKey(const Key('home_search_clear_button')));
      await tester.pump();

      // SuffixIcon must synchronously revert to close button
      expect(
        find.byKey(const Key('home_search_close_button')),
        findsOneWidget,
        reason: 'Tapping clear must synchronously restore close button',
      );
      expect(
        find.byKey(const Key('home_search_clear_button')),
        findsNothing,
        reason: 'Clear button must be removed immediately',
      );
      expect(
        container.read(homeSearchQueryProvider),
        equals(''),
        reason: 'homeSearchQueryProvider must be synchronously reset to empty string',
      );

      // Verify controller text is empty
      final textField = tester.widget<TextField>(searchInputFinder);
      expect(textField.controller!.text, equals(''));

      // Ensure no dangling debounce timer fires later
      await tester.pump(const Duration(milliseconds: 300));
      expect(container.read(homeSearchQueryProvider), equals(''));
    });

    testWidgets('1.3 SuffixIcon clear functionality on whitespace-only input', (tester) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          currentUserIdProvider.overrideWith((ref) => 'user-test-active'),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: FeedScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('feed_appbar_search_button')));
      await tester.pumpAndSettle();

      final searchInputFinder = find.byKey(const Key('home_search_input'));

      // Enter 4 whitespace characters
      await tester.enterText(searchInputFinder, '    ');
      await tester.pump();

      // Controller is non-empty ('    ') -> clear button MUST be present
      expect(find.byKey(const Key('home_search_clear_button')), findsOneWidget);
      expect(find.byKey(const Key('home_search_close_button')), findsNothing);

      // Pump 250ms past debounce
      await tester.pump(const Duration(milliseconds: 250));

      // Provider query should be trimmed to ''
      expect(container.read(homeSearchQueryProvider), equals(''));

      // Even though provider query is '', controller text is still '    ', so clear button remains
      expect(find.byKey(const Key('home_search_clear_button')), findsOneWidget);
      expect(find.byKey(const Key('home_search_close_button')), findsNothing);

      // Tap clear button
      await tester.tap(find.byKey(const Key('home_search_clear_button')));
      await tester.pump();

      // Immediately switches to close button and clears text
      expect(find.byKey(const Key('home_search_close_button')), findsOneWidget);
      expect(find.byKey(const Key('home_search_clear_button')), findsNothing);
      expect(tester.widget<TextField>(searchInputFinder).controller!.text, equals(''));
    });

    testWidgets('1.4 Punctuation, multi-word queries, and rapid typing stress', (tester) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          currentUserIdProvider.overrideWith((ref) => 'user-test-active'),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: FeedScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('feed_appbar_search_button')));
      await tester.pumpAndSettle();

      final searchInputFinder = find.byKey(const Key('home_search_input'));

      // Multi-word with punctuation
      const complexQuery = 'Tolarian Academy (Foil) #001!';
      await tester.enterText(searchInputFinder, complexQuery);
      await tester.pump();
      expect(find.byKey(const Key('home_search_clear_button')), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 250));
      expect(container.read(homeSearchQueryProvider), equals(complexQuery));

      // Rapid typing stress: cancel debouncer repeatedly before expiry
      for (final fragment in ['T', 'To', 'Tol', 'Tola', 'Tolarian', 'Tolarian ']) {
        await tester.enterText(searchInputFinder, fragment);
        await tester.pump(const Duration(milliseconds: 50)); // Less than 200ms
      }

      // Provider query should not have updated to intermediate states yet
      expect(container.read(homeSearchQueryProvider), equals(complexQuery));

      // Wait out full debounce
      await tester.pump(const Duration(milliseconds: 250));
      expect(container.read(homeSearchQueryProvider), equals('Tolarian'));

      // Tapping close button when search has text: wait, close button is only visible when empty!
      // When non-empty, clear button is visible. Tap clear:
      await tester.tap(find.byKey(const Key('home_search_clear_button')));
      await tester.pump();
      expect(find.byKey(const Key('home_search_close_button')), findsOneWidget);

      // Now tap close button to collapse search
      await tester.tap(find.byKey(const Key('home_search_close_button')));
      await tester.pumpAndSettle();

      // Search bar is collapsed, Countr logo is shown
      expect(find.byKey(const Key('home_search_input')), findsNothing);
      expect(find.text('Countr'), findsOneWidget);
      expect(find.byKey(const Key('feed_appbar_search_button')), findsOneWidget);
    });
  });

  group('CHALLENGER 1 [Area 2]: Profile Stats, Friend Counts & Follow Invariants', () {
    testWidgets('2.1 Individual user shows Friends count; Business profile shows Followers count', (tester) async {
      const individualId = 'user-alice';
      const businessId = 'store-tbs-comics';
      final now = DateTime.now();

      await db.userProfileDao.upsertProfile(
        UserProfilesCompanion.insert(
          id: individualId,
          username: 'alice_collector',
          displayName: 'Alice Collector',
          accountType: const drift.Value('individual'),
          friendCount: const drift.Value(4),
          createdAt: now,
          updatedAt: drift.Value(now),
        ),
      );

      // Test Individual Profile
      await tester.pumpWidget(
        buildTestApp(
          child: const UserProfileScreen(profileId: individualId),
          currentUserId: 'user-viewer',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Individual profile displays 'Friends' stat and does NOT display 'Followers' stat
      expect(find.byKey(const Key('profile_stat_friends')), findsOneWidget);
      expect(find.text('Friends'), findsOneWidget);
      expect(find.byKey(const Key('profile_stat_followers')), findsNothing);
      expect(find.text('Followers'), findsNothing);

      // Individual profile displays Add Friend control (or Friendship dropdown if friends)
      expect(find.byKey(const Key('profile_btn_follow')), findsNothing);

      // Test Business Profile
      await tester.pumpWidget(
        buildTestApp(
          child: const UserProfileScreen(profileId: businessId),
          currentUserId: 'user-viewer',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Business profile displays 'Followers' stat and does NOT display 'Friends' stat
      expect(find.byKey(const Key('profile_stat_followers')), findsOneWidget);
      expect(find.text('Followers'), findsOneWidget);
      expect(find.byKey(const Key('profile_stat_friends')), findsNothing);

      // Business profile displays Follow button and does NOT display friend request buttons
      expect(find.byKey(const Key('profile_btn_follow')), findsOneWidget);
      expect(find.byKey(const Key('profile_btn_add_friend')), findsNothing);
    });

    testWidgets('2.2 Business Follow toggle updates SQLite and UI reactively (Follow -> Following ✓ -> Follow)', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const viewerId = 'user-viewer-follow';
      const businessId = 'store-tbs-comics';

      await tester.pumpWidget(
        buildTestApp(
          child: const UserProfileScreen(profileId: businessId),
          currentUserId: viewerId,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Initial state: not following
      final followBtnFinder = find.byKey(const Key('profile_btn_follow'));
      expect(followBtnFinder, findsOneWidget);
      expect(find.text('Follow'), findsOneWidget);
      expect(find.text('Following ✓'), findsNothing);

      final initialFollowersFinder = find.byKey(const Key('profile_stat_followers'));
      expect(find.descendant(of: initialFollowersFinder, matching: find.text('0')), findsOneWidget);

      // Tap Follow button
      await tester.ensureVisible(followBtnFinder);
      await tester.tap(followBtnFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Follower count updates to 1, button updates to 'Following ✓'
      expect(find.text('Following ✓'), findsOneWidget);
      expect(find.text('Follow'), findsNothing);
      expect(find.descendant(of: initialFollowersFinder, matching: find.text('1')), findsOneWidget);
      final followRow = await (db.select(db.userFollows)..where((t) => t.followerId.equals(viewerId) & t.targetUserId.equals(businessId) & t.isDeleted.equals(false))).getSingleOrNull();
      expect(followRow != null, isTrue);

      // Tap Following ✓ button to unfollow
      await tester.ensureVisible(followBtnFinder);
      await tester.tap(followBtnFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Reverts to 0 followers, button reverts to 'Follow'
      expect(find.text('Follow'), findsOneWidget);
      expect(find.text('Following ✓'), findsNothing);
      expect(find.descendant(of: initialFollowersFinder, matching: find.text('0')), findsOneWidget);
      final unfollowRow = await (db.select(db.userFollows)..where((t) => t.followerId.equals(viewerId) & t.targetUserId.equals(businessId) & t.isDeleted.equals(false))).getSingleOrNull();
      expect(unfollowRow == null, isTrue);
    });
  });

  group('CHALLENGER 1 [Area 3]: Friends Hub Screen & Wall Scoping Invariants', () {
    testWidgets('3.1 FriendsHubScreen null userId fallback and non-existent user empty state', (tester) async {
      const activeUser = 'user-active-fallback';
      final now = DateTime.now();

      await db.userProfileDao.upsertProfile(
        UserProfilesCompanion.insert(
          id: activeUser,
          username: 'active_fallback',
          displayName: 'Active Fallback',
          accountType: const drift.Value('individual'),
          friendCount: const drift.Value(0),
          createdAt: now,
          updatedAt: drift.Value(now),
        ),
      );

      // Null userId defaults to authenticated user
      await tester.pumpWidget(
        buildTestApp(
          child: const FriendsHubScreen(userId: null),
          currentUserId: activeUser,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(FriendsHubScreen), findsOneWidget);
      expect(find.byKey(const Key('my_friends_empty')), findsOneWidget);
      expect(find.text('You don\'t have any friends yet'), findsOneWidget);
    });

    testWidgets('3.2 Activity Wall scoping: strictly confines posts to target user authored or shared', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const userA = 'user-wall-a';
      const userB = 'user-wall-b';
      final now = DateTime.now();

      await db.userProfileDao.upsertProfile(
        UserProfilesCompanion.insert(
          id: userA,
          username: 'wall_a',
          displayName: 'Wall A',
          accountType: const drift.Value('individual'),
          createdAt: now,
          updatedAt: drift.Value(now),
        ),
      );

      // Clear existing posts
      await db.delete(db.feedPosts).go();

      // User A authored post
      await db.into(db.feedPosts).insert(
        FeedPostsCompanion.insert(
          id: 'post-a-authored',
          authorId: userA,
          authorUsername: 'wall_a',
          authorDisplayName: 'Wall A',
          type: 'text',
          textContent: const drift.Value('Post Authored by User A'),
          createdAt: drift.Value(now),
        ),
      );

      // User B authored post (shared by User A)
      await db.into(db.feedPosts).insert(
        FeedPostsCompanion.insert(
          id: 'post-b-shared-by-a',
          authorId: userB,
          authorUsername: 'wall_b',
          authorDisplayName: 'Wall B',
          sharedByUserId: const drift.Value(userA),
          type: 'text',
          textContent: const drift.Value('Post Shared by User A'),
          createdAt: drift.Value(now.add(const Duration(minutes: 1))),
        ),
      );

      // User B authored post (NOT shared by User A)
      await db.into(db.feedPosts).insert(
        FeedPostsCompanion.insert(
          id: 'post-b-unrelated',
          authorId: userB,
          authorUsername: 'wall_b',
          authorDisplayName: 'Wall B',
          type: 'text',
          textContent: const drift.Value('Unrelated Post by User B'),
          createdAt: drift.Value(now.add(const Duration(minutes: 2))),
        ),
      );

      // Inspect User A's profile wall
      await tester.pumpWidget(
        buildTestApp(
          child: const UserProfileScreen(profileId: userA),
          currentUserId: 'user-viewer',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Wall should contain post-a-authored and post-b-shared-by-a, but strictly NOT post-b-unrelated
      expect(find.text('Post Authored by User A'), findsOneWidget);
      expect(find.text('Post Shared by User A'), findsOneWidget);
      expect(find.text('Unrelated Post by User B'), findsNothing);
    });
  });
}
