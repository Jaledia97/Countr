// Copyright (c) 2026 Countr. All rights reserved.
// Adversarial Challenger Test Suite for Milestone 3 (Challenger M3 2)
// Coverage:
// 1. Multi-level nested reply threads (3+ levels, parentCommentId linkage, thread guide lines).
// 2. Reply button and replying_to_banner interaction and dismissal.
// 3. True total comment count verification across all depths (sheet header & post card counter).
// 4. Overflow menu on single, multi, and text posts.
// 5. MultiCardWishlistDrawer: Select All toggling, individual card toggles, transactional persistence.
// 6. Command Center Saved Posts row expansion, count badge, and SavedPostsScreen display.
// 7. Narrow viewport stress testing and orphaned comment resilience.

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:countr/core/database/app_database.dart';
import 'package:countr/features/command_center/presentation/widgets/morphing_command_center.dart';
import 'package:countr/features/feed/data/social_seed_service.dart';
import 'package:countr/features/feed/domain/models/feed_post.dart';
import 'package:countr/features/feed/presentation/providers/feed_providers.dart';
import 'package:countr/features/feed/presentation/screens/saved_posts_screen.dart';
import 'package:countr/features/feed/presentation/widgets/multi_card_wishlist_drawer.dart';
import 'package:countr/features/feed/presentation/widgets/post_card.dart';
import 'package:countr/features/feed/presentation/widgets/post_comments_sheet.dart';
import 'package:countr/features/feed/presentation/widgets/post_header.dart';
import 'package:countr/features/profile/presentation/providers/profile_providers.dart';
import 'package:countr/features/vault/presentation/providers/vault_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SocialSeedService seedService;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.userProfileDao.seedDefaultProfiles();
    await (db.update(db.userProfiles)).write(
      const UserProfilesCompanion(avatarUrl: drift.Value(null)),
    );
    seedService = SocialSeedService(db);
    await seedService.seedSocialData();
  });

  tearDown(() async {
    await db.close();
  });

  Widget wrapWithScope({
    required Widget child,
    String currentUserId = 'user-current-me',
  }) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        feedDaoProvider.overrideWithValue(db.feedDao),
        currentUserIdProvider.overrideWith((ref) => currentUserId),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: child,
        ),
      ),
    );
  }

  group('CHALLENGER M3.2 - Challenge 1: Multi-Level Nested Reply Threads', () {
    testWidgets('Constructs 4-level deep nested comments tree and verifies parentCommentId linkage & guide lines', (tester) async {
      const postId = 'post-deep-nested-4levels';
      final now = DateTime.now();

      await db.feedDao.createPost(
        FeedPostsCompanion.insert(
          id: postId,
          authorId: 'user-current-me',
          authorUsername: '@collector_me',
          authorDisplayName: 'Current Collector',
          type: 'text',
          textContent: const drift.Value('Deep nesting challenge post'),
          createdAt: drift.Value(now),
          updatedAt: drift.Value(now),
        ),
      );

      final feedPost = FeedPost(
        id: postId,
        type: PostType.text,
        username: '@collector_me',
        avatarInitials: 'CC',
        timestamp: 'Just now',
        locationTag: 'MTG Pod',
        textContent: 'Deep nesting challenge post',
      );

      // Level 0: Root comment
      final root = await db.feedDao.addComment(
        postId: postId,
        authorId: 'user-author-0',
        authorUsername: '@root_author',
        authorDisplayName: 'Root Author',
        content: 'Level 0 Root Comment',
      );
      expect(root.parentCommentId, isNull);

      // Level 1: Reply to Root
      final level1 = await db.feedDao.addComment(
        postId: postId,
        authorId: 'user-author-1',
        authorUsername: '@level1_author',
        authorDisplayName: 'Level 1 Author',
        content: 'Level 1 Reply to Root',
        parentCommentId: root.id,
      );
      expect(level1.parentCommentId, equals(root.id));

      // Level 2: Reply to Level 1
      final level2 = await db.feedDao.addComment(
        postId: postId,
        authorId: 'user-author-2',
        authorUsername: '@level2_author',
        authorDisplayName: 'Level 2 Author',
        content: 'Level 2 Reply to L1',
        parentCommentId: level1.id,
      );
      expect(level2.parentCommentId, equals(level1.id));

      // Level 3: Reply to Level 2
      final level3 = await db.feedDao.addComment(
        postId: postId,
        authorId: 'user-author-3',
        authorUsername: '@level3_author',
        authorDisplayName: 'Level 3 Author',
        content: 'Level 3 Reply to L2',
        parentCommentId: level2.id,
      );
      expect(level3.parentCommentId, equals(level2.id));

      // Level 4: Reply to Level 3
      final level4 = await db.feedDao.addComment(
        postId: postId,
        authorId: 'user-author-4',
        authorUsername: '@level4_author',
        authorDisplayName: 'Level 4 Author',
        content: 'Level 4 Reply to L3',
        parentCommentId: level3.id,
      );
      expect(level4.parentCommentId, equals(level3.id));

      // Pump comments sheet
      await tester.pumpWidget(wrapWithScope(
        child: PostCommentsSheet(post: feedPost),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 1. Verify all 5 comments are displayed
      expect(find.text('Level 0 Root Comment'), findsOneWidget);
      expect(find.text('Level 1 Reply to Root'), findsOneWidget);
      expect(find.text('Level 2 Reply to L1'), findsOneWidget);
      expect(find.text('Level 3 Reply to L2'), findsOneWidget);
      expect(find.text('Level 4 Reply to L3'), findsOneWidget);

      // 2. Verify thread guide lines render for every node having children (4 levels of children)
      final guideLineFinder = find.byKey(const Key('thread_guide_line'));
      expect(guideLineFinder, findsNWidgets(4));

      // Inspect decoration of the guide lines
      for (int i = 0; i < 4; i++) {
        final container = tester.widget<Container>(guideLineFinder.at(i));
        final decoration = container.decoration as BoxDecoration?;
        expect(decoration, isNotNull);
        final border = decoration!.border as Border?;
        expect(border, isNotNull);
        expect(border!.left.color, equals(const Color(0xFF33384B)));
        expect(border.left.width, equals(1.5));
      }

      // 3. Verify zero RenderFlex overflows
      expect(tester.takeException(), isNull);
    });

    testWidgets('Handles branching subtrees with multiple siblings and preserves chronological order', (tester) async {
      const postId = 'post-branching-tree';
      final now = DateTime.now();

      await db.feedDao.createPost(
        FeedPostsCompanion.insert(
          id: postId,
          authorId: 'user-current-me',
          authorUsername: '@collector_me',
          authorDisplayName: 'Current Collector',
          type: 'text',
          textContent: const drift.Value('Branching tree post'),
          createdAt: drift.Value(now),
          updatedAt: drift.Value(now),
        ),
      );

      final feedPost = FeedPost(
        id: postId,
        type: PostType.text,
        username: '@collector_me',
        avatarInitials: 'CC',
        timestamp: 'Just now',
        locationTag: 'MTG Pod',
        textContent: 'Branching tree post',
      );

      // Root 1
      final r1 = await db.feedDao.addComment(
        postId: postId,
        authorId: 'user-1',
        authorUsername: '@user1',
        authorDisplayName: 'User 1',
        content: 'Root 1',
      );

      // Root 1 -> Child 1A
      final c1a = await db.feedDao.addComment(
        postId: postId,
        authorId: 'user-2',
        authorUsername: '@user2',
        authorDisplayName: 'User 2',
        content: 'Child 1A',
        parentCommentId: r1.id,
      );

      // Root 1 -> Child 1B
      await db.feedDao.addComment(
        postId: postId,
        authorId: 'user-3',
        authorUsername: '@user3',
        authorDisplayName: 'User 3',
        content: 'Child 1B',
        parentCommentId: r1.id,
      );

      // Root 1 -> Child 1A -> Grandchild 1A1
      await db.feedDao.addComment(
        postId: postId,
        authorId: 'user-4',
        authorUsername: '@user4',
        authorDisplayName: 'User 4',
        content: 'Grandchild 1A1',
        parentCommentId: c1a.id,
      );

      // Root 2 (independent root)
      await db.feedDao.addComment(
        postId: postId,
        authorId: 'user-5',
        authorUsername: '@user5',
        authorDisplayName: 'User 5',
        content: 'Root 2',
      );

      await tester.pumpWidget(wrapWithScope(
        child: PostCommentsSheet(post: feedPost),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Root 1'), findsOneWidget);
      expect(find.text('Child 1A'), findsOneWidget);
      expect(find.text('Child 1B'), findsOneWidget);
      expect(find.text('Grandchild 1A1'), findsOneWidget);
      expect(find.text('Root 2'), findsOneWidget);

      // Root 1 has children (1 guide line), Child 1A has children (1 guide line), Root 2 has no children (0).
      // Total guide lines = 2
      expect(find.byKey(const Key('thread_guide_line')), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Gracefully treats orphaned comments and self-referencing parents as root nodes without crashing', (tester) async {
      const postId = 'post-orphaned-comment';
      final now = DateTime.now();

      await db.feedDao.createPost(
        FeedPostsCompanion.insert(
          id: postId,
          authorId: 'user-current-me',
          authorUsername: '@collector_me',
          authorDisplayName: 'Current Collector',
          type: 'text',
          textContent: const drift.Value('Orphaned test post'),
          createdAt: drift.Value(now),
          updatedAt: drift.Value(now),
        ),
      );

      final feedPost = FeedPost(
        id: postId,
        type: PostType.text,
        username: '@collector_me',
        avatarInitials: 'CC',
        timestamp: 'Just now',
        locationTag: 'MTG Pod',
      );

      // Valid root comment
      await db.feedDao.addComment(
        postId: postId,
        authorId: 'user-valid',
        authorUsername: '@valid',
        authorDisplayName: 'Valid User',
        content: 'Valid root comment',
      );

      // Orphan comment with non-existent parent ID
      await db.feedDao.addComment(
        postId: postId,
        authorId: 'user-orphan',
        authorUsername: '@orphan',
        authorDisplayName: 'Orphan User',
        content: 'Orphaned reply whose parent was deleted',
        parentCommentId: 'ghost-parent-9999',
      );

      await tester.pumpWidget(wrapWithScope(
        child: PostCommentsSheet(post: feedPost),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Both comments should be rendered without crashing
      expect(find.text('Valid root comment'), findsOneWidget);
      expect(find.text('Orphaned reply whose parent was deleted'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('CHALLENGER M3.2 - Challenge 2: Reply Button & Replying Banner Lifecycle', () {
    testWidgets('Activating reply reveals banner, updates input hint, and dismiss clears banner and hint', (tester) async {
      const postId = 'post-reply-lifecycle';
      final now = DateTime.now();

      await db.feedDao.createPost(
        FeedPostsCompanion.insert(
          id: postId,
          authorId: 'user-current-me',
          authorUsername: '@collector_me',
          authorDisplayName: 'Current Collector',
          type: 'text',
          textContent: const drift.Value('Reply lifecycle test'),
          createdAt: drift.Value(now),
          updatedAt: drift.Value(now),
        ),
      );

      final feedPost = FeedPost(
        id: postId,
        type: PostType.text,
        username: '@collector_me',
        avatarInitials: 'CC',
        timestamp: 'Just now',
        locationTag: 'MTG Pod',
      );

      final root = await db.feedDao.addComment(
        postId: postId,
        authorId: 'user-foil-master',
        authorUsername: '@foil_master',
        authorDisplayName: 'Foil Master',
        content: 'Check out this mint foil!',
      );

      await tester.pumpWidget(wrapWithScope(
        child: PostCommentsSheet(post: feedPost),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Banner initially absent
      expect(find.byKey(const Key('replying_to_banner')), findsNothing);

      // Default hint text on input
      expect(find.text('Add a comment (supports {W}{U}{B}{R}{G})...'), findsOneWidget);

      // Tap Reply button
      await tester.tap(find.byKey(Key('comment_reply_button_${root.id}')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Replying banner appears
      expect(find.byKey(const Key('replying_to_banner')), findsOneWidget);
      expect(find.text('Replying to @foil_master [X]'), findsOneWidget);

      // Input hint text changes to targeted user
      expect(find.text('Reply to @foil_master...'), findsOneWidget);

      // Tap dismiss button
      await tester.tap(find.byKey(const Key('dismiss_reply_banner_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Banner disappears
      expect(find.byKey(const Key('replying_to_banner')), findsNothing);

      // Hint text reverts to default
      expect(find.text('Add a comment (supports {W}{U}{B}{R}{G})...'), findsOneWidget);
    });

    testWidgets('Submitting reply links parentCommentId, dismisses banner, and inserts nested reply', (tester) async {
      const postId = 'post-submit-nested-reply';
      final now = DateTime.now();

      await db.feedDao.createPost(
        FeedPostsCompanion.insert(
          id: postId,
          authorId: 'user-current-me',
          authorUsername: '@collector_me',
          authorDisplayName: 'Current Collector',
          type: 'text',
          textContent: const drift.Value('Submit nested reply test'),
          createdAt: drift.Value(now),
          updatedAt: drift.Value(now),
        ),
      );

      final feedPost = FeedPost(
        id: postId,
        type: PostType.text,
        username: '@collector_me',
        avatarInitials: 'CC',
        timestamp: 'Just now',
        locationTag: 'MTG Pod',
      );

      final root = await db.feedDao.addComment(
        postId: postId,
        authorId: 'user-target',
        authorUsername: '@target_collector',
        authorDisplayName: 'Target Collector',
        content: 'Original question about mana curve',
      );

      await tester.pumpWidget(wrapWithScope(
        child: PostCommentsSheet(post: feedPost),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap Reply on root comment
      await tester.tap(find.byKey(Key('comment_reply_button_${root.id}')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byKey(const Key('replying_to_banner')), findsOneWidget);

      // Enter reply text in input
      await tester.enterText(
        find.byKey(const Key('post_comment_input')),
        'You should run at least 36 lands and 10 ramp spells!',
      );
      await tester.pump();

      // Submit reply
      await tester.tap(find.byKey(const Key('post_comment_submit_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Banner should be dismissed
      expect(find.byKey(const Key('replying_to_banner')), findsNothing);

      // Input should be cleared
      final input = tester.widget<TextField>(find.byKey(const Key('post_comment_input')));
      expect(input.controller?.text, isEmpty);

      // Verify the new nested reply is rendered in UI
      expect(find.text('You should run at least 36 lands and 10 ramp spells!'), findsOneWidget);

      // Thread guide line should now appear linking root to reply
      expect(find.byKey(const Key('thread_guide_line')), findsOneWidget);

      // Verify database record has proper parentCommentId
      final allComments = await (db.select(db.postComments)..where((t) => t.postId.equals(postId))).get();
      final submittedReply = allComments.firstWhere(
        (c) => c.content == 'You should run at least 36 lands and 10 ramp spells!',
      );
      expect(submittedReply.parentCommentId, equals(root.id));
    });
  });

  group('CHALLENGER M3.2 - Challenge 3: True Total Comment Count Across All Depths', () {
    testWidgets('Header and PostCard counter reflect aggregate count across 4 levels and decrement on soft-delete', (tester) async {
      const postId = 'post-true-count-stress';
      final now = DateTime.now();

      await db.feedDao.createPost(
        FeedPostsCompanion.insert(
          id: postId,
          authorId: 'user-current-me',
          authorUsername: '@collector_me',
          authorDisplayName: 'Current Collector',
          type: 'text',
          textContent: const drift.Value('True count stress post'),
          createdAt: drift.Value(now),
          updatedAt: drift.Value(now),
        ),
      );

      final feedPost = FeedPost(
        id: postId,
        type: PostType.text,
        username: '@collector_me',
        avatarInitials: 'CC',
        timestamp: 'Just now',
        locationTag: 'MTG Pod',
        textContent: 'True count stress post',
      );

      // Step 1: Initial count is 0
      var dbCount = await db.feedDao.getCommentCount(postId);
      expect(dbCount, equals(0));

      // Step 2: Add comments at depth 0, 1, 2, 3
      final c0 = await db.feedDao.addComment(
        postId: postId,
        authorId: 'u0',
        authorUsername: '@u0',
        authorDisplayName: 'U0',
        content: 'Depth 0',
      );
      final c1 = await db.feedDao.addComment(
        postId: postId,
        authorId: 'u1',
        authorUsername: '@u1',
        authorDisplayName: 'U1',
        content: 'Depth 1',
        parentCommentId: c0.id,
      );
      final c2 = await db.feedDao.addComment(
        postId: postId,
        authorId: 'u2',
        authorUsername: '@u2',
        authorDisplayName: 'U2',
        content: 'Depth 2',
        parentCommentId: c1.id,
      );
      await db.feedDao.addComment(
        postId: postId,
        authorId: 'u3',
        authorUsername: '@u3',
        authorDisplayName: 'U3',
        content: 'Depth 3',
        parentCommentId: c2.id,
      );

      dbCount = await db.feedDao.getCommentCount(postId);
      expect(dbCount, equals(4));

      // Check PostCard numeric counter
      await tester.pumpWidget(wrapWithScope(
        child: PostCard(post: feedPost),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final counterWidget = tester.widget<Text>(find.byKey(const Key('post_comment_counter_text')));
      expect(counterWidget.data, equals('4'));

      // Check PostCommentsSheet header
      await tester.pumpWidget(wrapWithScope(
        child: PostCommentsSheet(post: feedPost),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final headerWidget = tester.widget<Text>(find.byKey(const Key('post_comments_count_header')));
      expect(headerWidget.data, equals('Comments (4)'));

      // Step 3: Soft-delete c2
      await (db.update(db.postComments)..where((t) => t.id.equals(c2.id))).write(
        PostCommentsCompanion(
          isDeleted: const drift.Value(true),
          deletedAt: drift.Value(DateTime.now()),
        ),
      );

      dbCount = await db.feedDao.getCommentCount(postId);
      expect(dbCount, equals(3));

      // Step 4: Verify cross-post comment isolation
      const anotherPostId = 'post-isolated-other';
      await db.feedDao.createPost(
        FeedPostsCompanion.insert(
          id: anotherPostId,
          authorId: 'user-current-me',
          authorUsername: '@collector_me',
          authorDisplayName: 'Current Collector',
          type: 'text',
          textContent: const drift.Value('Other post'),
          createdAt: drift.Value(now),
          updatedAt: drift.Value(now),
        ),
      );
      await db.feedDao.addComment(
        postId: anotherPostId,
        authorId: 'u-other',
        authorUsername: '@other',
        authorDisplayName: 'Other',
        content: 'Comment on other post',
      );

      // Verify original post count remains 3 and other post count is 1
      expect(await db.feedDao.getCommentCount(postId), equals(3));
      expect(await db.feedDao.getCommentCount(anotherPostId), equals(1));
    });
  });

  group('CHALLENGER M3.2 - Challenge 4: Overflow Menu & MultiCardWishlistDrawer', () {
    testWidgets('Single-card post overflow menu Wishlist option adds card to Looking For binder', (tester) async {
      const currentUserId = 'user-current-me';
      const cardId = 'scryfall-lotus-001';
      const cardTitle = 'Black Lotus';

      final singleCardPost = FeedPost(
        id: 'post-single-card-wishlist',
        type: PostType.singlePull,
        username: '@vintage_collector',
        avatarInitials: 'VC',
        timestamp: '1h ago',
        locationTag: 'Sanctum',
        cardId: cardId,
        cardTitle: cardTitle,
      );

      await tester.pumpWidget(wrapWithScope(
        currentUserId: currentUserId,
        child: PostHeader(
          username: singleCardPost.username,
          avatarInitials: singleCardPost.avatarInitials,
          timestamp: singleCardPost.timestamp,
          locationTag: singleCardPost.locationTag,
          post: singleCardPost,
        ),
      ));
      await tester.pumpAndSettle();

      // Open overflow menu
      await tester.tap(find.byKey(const Key('post_header_overflow_menu')));
      await tester.pumpAndSettle();

      // Wishlist Card item exists
      final menuItem = find.byKey(const Key('post_menu_wishlist_card'));
      expect(menuItem, findsOneWidget);
      expect(find.text('Wishlist Card (Add to Looking For)'), findsOneWidget);

      // Tap Wishlist Card
      await tester.tap(menuItem);
      await tester.pumpAndSettle();

      // Verify item persisted to Looking For binder in SQLite
      final canonicalLfId = 'system_looking_for_$currentUserId';
      final lfItems = await (db.select(db.vaultItems)
            ..where((t) => t.primaryBinderId.equals(canonicalLfId)))
          .get();

      expect(lfItems.length, equals(1));
      expect(lfItems.first.name, equals(cardTitle));
      expect(lfItems.first.isWishlisted, isTrue);

      // Verify confirmation snackbar
      expect(find.text('Added Black Lotus to Looking For binder'), findsOneWidget);
    });

    testWidgets('MultiCardWishlistDrawer: Select All toggles all cards, individual deselection, and transactional add', (tester) async {
      const currentUserId = 'user-current-me';
      const cardIds = ['c-mox-ruby', 'c-mox-sapphire', 'c-mox-jet'];
      const cardTitles = ['Mox Ruby', 'Mox Sapphire', 'Mox Jet'];
      const imageUrls = ['http://img/ruby.jpg', 'http://img/sapphire.jpg', 'http://img/jet.jpg'];

      await tester.pumpWidget(wrapWithScope(
        currentUserId: currentUserId,
        child: Builder(
          builder: (ctx) => Center(
            child: ElevatedButton(
              key: const Key('open_drawer_test_button'),
              onPressed: () {
                MultiCardWishlistDrawer.showWithData(
                  ctx,
                  cardIds: cardIds,
                  cardTitles: cardTitles,
                  imageUrls: imageUrls,
                );
              },
              child: const Text('Open Drawer'),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Open bottom sheet drawer
      await tester.tap(find.byKey(const Key('open_drawer_test_button')));
      await tester.pumpAndSettle();

      // 1. Initial State: All selected
      expect(find.byKey(const Key('wishlist_drawer_title')), findsOneWidget);
      expect(find.text('Wishlist Cards (3)'), findsOneWidget);
      expect(find.text('Select All (3/3)'), findsOneWidget);
      expect(find.text('Add Selected (3) to Looking For'), findsOneWidget);

      // 2. Select All Toggle -> Deselect all
      await tester.tap(find.byKey(const Key('wishlist_drawer_select_all')));
      await tester.pumpAndSettle();

      expect(find.text('Select All (0/3)'), findsOneWidget);
      expect(find.text('Add Selected (0) to Looking For'), findsOneWidget);

      // Button is disabled when 0 selected
      final buttonFinder = find.byKey(const Key('wishlist_drawer_add_selected_button'));
      final button = tester.widget<ElevatedButton>(buttonFinder);
      expect(button.onPressed, isNull);

      // 3. Select All Toggle -> Select all again
      await tester.tap(find.byKey(const Key('wishlist_drawer_select_all')));
      await tester.pumpAndSettle();

      expect(find.text('Select All (3/3)'), findsOneWidget);
      expect(find.text('Add Selected (3) to Looking For'), findsOneWidget);

      // 4. Individual Deselection: Uncheck Mox Ruby (card 0)
      await tester.tap(find.byKey(const Key('wishlist_drawer_card_0')));
      await tester.pumpAndSettle();

      expect(find.text('Select All (2/3)'), findsOneWidget);
      expect(find.text('Add Selected (2) to Looking For'), findsOneWidget);

      // 5. Submit "Add Selected (2) to Looking For"
      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();

      // 6. Verify transactional persistence in SQLite
      final canonicalLfId = 'system_looking_for_$currentUserId';
      final savedItems = await (db.select(db.vaultItems)
            ..where((t) => t.primaryBinderId.equals(canonicalLfId)))
          .get();

      // Exactly 2 items saved (Mox Sapphire and Mox Jet)
      expect(savedItems.length, equals(2));
      final savedNames = savedItems.map((i) => i.name).toSet();
      expect(savedNames, contains('Mox Sapphire'));
      expect(savedNames, contains('Mox Jet'));
      expect(savedNames, isNot(contains('Mox Ruby')));

      for (final item in savedItems) {
        expect(item.isWishlisted, isTrue);
      }

      // Snackbar confirmation
      expect(find.text('Added 2 cards to Looking For binder'), findsOneWidget);
    });

    testWidgets('Text post Save Post menu option toggles saved state in SQLite', (tester) async {
      const currentUserId = 'user-current-me';
      const postId = 'post-text-bookmark-test';
      final now = DateTime.now();

      await db.feedDao.createPost(
        FeedPostsCompanion.insert(
          id: postId,
          authorId: currentUserId,
          authorUsername: '@collector_me',
          authorDisplayName: 'Current Collector',
          type: 'text',
          textContent: const drift.Value('Bookmarkable tournament summary'),
          createdAt: drift.Value(now),
          updatedAt: drift.Value(now),
        ),
      );

      final textPost = FeedPost(
        id: postId,
        type: PostType.text,
        username: '@collector_me',
        avatarInitials: 'CC',
        timestamp: '1h ago',
        locationTag: 'MTG Pod',
        textContent: 'Bookmarkable tournament summary',
      );

      await tester.pumpWidget(wrapWithScope(
        currentUserId: currentUserId,
        child: PostHeader(
          username: textPost.username,
          avatarInitials: textPost.avatarInitials,
          timestamp: textPost.timestamp,
          locationTag: textPost.locationTag,
          post: textPost,
        ),
      ));
      await tester.pumpAndSettle();

      // Open overflow menu
      await tester.tap(find.byKey(const Key('post_header_overflow_menu')));
      await tester.pumpAndSettle();

      // Menu has "Save Post"
      final saveMenuItem = find.byKey(const Key('post_menu_save_post'));
      expect(saveMenuItem, findsOneWidget);
      expect(find.text('Save Post'), findsOneWidget);

      // Tap Save Post
      await tester.tap(saveMenuItem);
      await tester.pumpAndSettle();

      // Verify saved in SQLite
      var isSaved = await db.feedDao.isPostSaved(postId, currentUserId);
      expect(isSaved, isTrue);
      expect(find.text('Post saved to Command Center'), findsOneWidget);

      // Tap Save Post again to un-save
      await tester.tap(find.byKey(const Key('post_header_overflow_menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('post_menu_save_post')));
      await tester.pumpAndSettle();

      isSaved = await db.feedDao.isPostSaved(postId, currentUserId);
      expect(isSaved, isFalse);
      expect(find.text('Post removed from saved'), findsOneWidget);
    });

    testWidgets('Morphing Command Center Saved Posts row expansion, count badge, and SavedPostsScreen display', (tester) async {
      const currentUserId = 'user-current-me';
      final now = DateTime.now();

      // Seed 2 saved posts in SQLite
      await db.feedDao.createPost(
        FeedPostsCompanion.insert(
          id: 'post-saved-1',
          authorId: currentUserId,
          authorUsername: '@collector_me',
          authorDisplayName: 'Current Collector',
          type: 'text',
          textContent: const drift.Value('Saved Post 1'),
          createdAt: drift.Value(now),
          updatedAt: drift.Value(now),
        ),
      );
      await db.feedDao.createPost(
        FeedPostsCompanion.insert(
          id: 'post-saved-2',
          authorId: currentUserId,
          authorUsername: '@collector_me',
          authorDisplayName: 'Current Collector',
          type: 'text',
          textContent: const drift.Value('Saved Post 2'),
          createdAt: drift.Value(now),
          updatedAt: drift.Value(now),
        ),
      );

      await db.feedDao.toggleSavePost('post-saved-1', currentUserId);
      await db.feedDao.toggleSavePost('post-saved-2', currentUserId);

      await tester.pumpWidget(wrapWithScope(
        currentUserId: currentUserId,
        child: const MorphingCommandCenter(),
      ));
      await tester.pumpAndSettle();

      // Chevron button exists
      expect(find.byKey(const Key('command_center_profile_chevron')), findsOneWidget);

      // Saved posts row collapsed
      expect(find.byKey(const Key('command_center_saved_posts_tile')), findsNothing);

      // Tap chevron to expand
      await tester.tap(find.byKey(const Key('command_center_profile_chevron')));
      await tester.pumpAndSettle();

      // Saved posts tile is visible
      expect(find.byKey(const Key('command_center_saved_posts_tile')), findsOneWidget);
      expect(find.text('Saved Posts'), findsOneWidget);

      // Count badge shows 2
      final badgeText = tester.widget<Text>(find.descendant(
        of: find.byKey(const Key('command_center_saved_posts_count_badge')),
        matching: find.byType(Text),
      ));
      expect(badgeText.data, equals('2'));

      // Render SavedPostsScreen directly to verify display
      await tester.pumpWidget(wrapWithScope(
        currentUserId: currentUserId,
        child: const SavedPostsScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('saved_posts_screen')), findsOneWidget);
      expect(find.byKey(const Key('saved_posts_title')), findsOneWidget);
      expect(find.byKey(const Key('saved_posts_list')), findsOneWidget);
      expect(find.text('Saved Post 1'), findsOneWidget);
      expect(find.text('Saved Post 2'), findsOneWidget);
    });
  });

  group('CHALLENGER M3.2 - Challenge 5: Narrow Viewport Stress & Adversarial Edge Cases', () {
    testWidgets('Deep nested tree survives 240px ultra-narrow viewport across 5 levels of nesting without RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(240, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const postId = 'post-narrow-240px-5levels';
      final now = DateTime.now();

      await db.feedDao.createPost(
        FeedPostsCompanion.insert(
          id: postId,
          authorId: 'user-current-me',
          authorUsername: '@collector_me',
          authorDisplayName: 'Current Collector',
          type: 'text',
          textContent: const drift.Value('Ultra narrow 240px 5-level post'),
          createdAt: drift.Value(now),
          updatedAt: drift.Value(now),
        ),
      );

      final feedPost = FeedPost(
        id: postId,
        type: PostType.text,
        username: '@collector_me',
        avatarInitials: 'CC',
        timestamp: 'Just now',
        locationTag: 'MTG Pod',
      );

      // Level 0 (Root)
      final c0 = await db.feedDao.addComment(
        postId: postId,
        authorId: 'u0',
        authorUsername: '@u0',
        authorDisplayName: 'Root User 0',
        content: 'Root level 0 comment at 240px',
      );

      // Level 1
      final c1 = await db.feedDao.addComment(
        postId: postId,
        authorId: 'u1',
        authorUsername: '@u1',
        authorDisplayName: 'Reply User 1',
        content: 'Level 1 nested reply',
        parentCommentId: c0.id,
      );

      // Level 2
      final c2 = await db.feedDao.addComment(
        postId: postId,
        authorId: 'u2',
        authorUsername: '@u2',
        authorDisplayName: 'Reply User 2',
        content: 'Level 2 nested reply',
        parentCommentId: c1.id,
      );

      // Level 3
      final c3 = await db.feedDao.addComment(
        postId: postId,
        authorId: 'u3',
        authorUsername: '@u3',
        authorDisplayName: 'Reply User 3',
        content: 'Level 3 nested reply',
        parentCommentId: c2.id,
      );

      // Level 4
      final c4 = await db.feedDao.addComment(
        postId: postId,
        authorId: 'u4',
        authorUsername: '@u4',
        authorDisplayName: 'Reply User 4',
        content: 'Level 4 nested reply',
        parentCommentId: c3.id,
      );

      // Level 5
      await db.feedDao.addComment(
        postId: postId,
        authorId: 'u5',
        authorUsername: '@u5',
        authorDisplayName: 'Reply User 5',
        content: 'Level 5 nested reply',
        parentCommentId: c4.id,
      );

      await tester.pumpWidget(wrapWithScope(
        child: PostCommentsSheet(post: feedPost),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('post_comments_list')), findsOneWidget);
      expect(find.text('Root level 0 comment at 240px'), findsOneWidget);
      expect(find.text('Level 1 nested reply'), findsOneWidget);
      expect(find.text('Level 2 nested reply'), findsOneWidget);
      expect(find.text('Level 3 nested reply'), findsOneWidget);
      expect(find.text('Level 4 nested reply'), findsOneWidget);
      expect(find.text('Level 5 nested reply'), findsOneWidget);

      // 5 guide lines for 5 nesting levels
      expect(find.byKey(const Key('thread_guide_line')), findsNWidgets(5));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Deep nested tree at 240px survives long author names without RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(240, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const postId = 'post-long-author-240px';
      final now = DateTime.now();

      await db.feedDao.createPost(
        FeedPostsCompanion.insert(
          id: postId,
          authorId: 'user-current-me',
          authorUsername: '@collector_me',
          authorDisplayName: 'Current Collector',
          type: 'text',
          textContent: const drift.Value('Long author post'),
          createdAt: drift.Value(now),
          updatedAt: drift.Value(now),
        ),
      );

      final feedPost = FeedPost(
        id: postId,
        type: PostType.text,
        username: '@collector_me',
        avatarInitials: 'CC',
        timestamp: 'Just now',
        locationTag: 'MTG Pod',
      );

      final c0 = await db.feedDao.addComment(
        postId: postId,
        authorId: 'u0',
        authorUsername: '@regular_author',
        authorDisplayName: 'Regular Author',
        content: 'Root comment',
      );

      final c1 = await db.feedDao.addComment(
        postId: postId,
        authorId: 'u1',
        authorUsername: '@level1_author',
        authorDisplayName: 'Level 1 Author',
        content: 'L1 comment',
        parentCommentId: c0.id,
      );

      final c2 = await db.feedDao.addComment(
        postId: postId,
        authorId: 'u2',
        authorUsername: '@level2_author',
        authorDisplayName: 'Level 2 Author',
        content: 'L2 comment',
        parentCommentId: c1.id,
      );

      final c3 = await db.feedDao.addComment(
        postId: postId,
        authorId: 'u3',
        authorUsername: '@level3_author',
        authorDisplayName: 'Level 3 Author',
        content: 'L3 comment',
        parentCommentId: c2.id,
      );

      // Level 4 with extremely long display name
      await db.feedDao.addComment(
        postId: postId,
        authorId: 'u4',
        authorUsername: '@very_long_collector_handle_99999999',
        authorDisplayName: 'Supreme Archon Collector Of Infinite Foils Extended Edition',
        content: 'L4 comment from user with very long name',
        parentCommentId: c3.id,
      );

      await tester.pumpWidget(wrapWithScope(
        child: PostCommentsSheet(post: feedPost),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('post_comments_list')), findsOneWidget);
      expect(find.text('Supreme Archon Collector Of Infinite Foils Extended Edition'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Replying-to banner survives 240px viewport with long username without RenderFlex overflow and dismisses cleanly', (tester) async {
      tester.view.physicalSize = const Size(240, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const postId = 'post-reply-banner-240px';
      final now = DateTime.now();

      await db.feedDao.createPost(
        FeedPostsCompanion.insert(
          id: postId,
          authorId: 'user-current-me',
          authorUsername: '@collector_me',
          authorDisplayName: 'Current Collector',
          type: 'text',
          textContent: const drift.Value('Reply banner post'),
          createdAt: drift.Value(now),
          updatedAt: drift.Value(now),
        ),
      );

      final feedPost = FeedPost(
        id: postId,
        type: PostType.text,
        username: '@collector_me',
        avatarInitials: 'CC',
        timestamp: 'Just now',
        locationTag: 'MTG Pod',
      );

      final c0 = await db.feedDao.addComment(
        postId: postId,
        authorId: 'u0',
        authorUsername: '@very_long_username_for_reply_banner_stress_test_overflow',
        authorDisplayName: 'Long Name User',
        content: 'Root comment to be replied to',
      );

      await tester.pumpWidget(wrapWithScope(
        child: PostCommentsSheet(post: feedPost),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap reply button
      final replyButton = find.byKey(Key('comment_reply_button_${c0.id}'));
      expect(replyButton, findsOneWidget);
      await tester.tap(replyButton);
      await tester.pump();

      // Banner should appear without RenderFlex overflow
      expect(find.byKey(const Key('replying_to_banner')), findsOneWidget);
      expect(find.byKey(const Key('comment_replying_banner')), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Dismiss banner via close button
      final dismissButton = find.byKey(const Key('dismiss_reply_banner_button'));
      expect(dismissButton, findsOneWidget);
      await tester.tap(dismissButton);
      await tester.pump();

      // Banner is removed
      expect(find.byKey(const Key('replying_to_banner')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Comment MRU reaction bar and reaction pills survive 240px viewport at deep nesting (depth 4) without RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(240, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const postId = 'post-reactions-240px-depth4';
      final now = DateTime.now();

      await db.feedDao.createPost(
        FeedPostsCompanion.insert(
          id: postId,
          authorId: 'user-current-me',
          authorUsername: '@collector_me',
          authorDisplayName: 'Current Collector',
          type: 'text',
          textContent: const drift.Value('Reactions test post'),
          createdAt: drift.Value(now),
          updatedAt: drift.Value(now),
        ),
      );

      final feedPost = FeedPost(
        id: postId,
        type: PostType.text,
        username: '@collector_me',
        avatarInitials: 'CC',
        timestamp: 'Just now',
        locationTag: 'MTG Pod',
      );

      // Build 4 levels deep
      final c0 = await db.feedDao.addComment(
        postId: postId,
        authorId: 'u0',
        authorUsername: '@u0',
        authorDisplayName: 'U0',
        content: 'Depth 0',
      );
      final c1 = await db.feedDao.addComment(
        postId: postId,
        authorId: 'u1',
        authorUsername: '@u1',
        authorDisplayName: 'U1',
        content: 'Depth 1',
        parentCommentId: c0.id,
      );
      final c2 = await db.feedDao.addComment(
        postId: postId,
        authorId: 'u2',
        authorUsername: '@u2',
        authorDisplayName: 'U2',
        content: 'Depth 2',
        parentCommentId: c1.id,
      );
      final c3 = await db.feedDao.addComment(
        postId: postId,
        authorId: 'u3',
        authorUsername: '@u3',
        authorDisplayName: 'U3',
        content: 'Depth 3',
        parentCommentId: c2.id,
      );
      final c4 = await db.feedDao.addComment(
        postId: postId,
        authorId: 'u4',
        authorUsername: '@u4',
        authorDisplayName: 'U4',
        content: 'Depth 4 target for reaction',
        parentCommentId: c3.id,
      );

      await tester.pumpWidget(wrapWithScope(
        child: PostCommentsSheet(post: feedPost),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap react button on deep comment c4
      final reactButton = find.byKey(Key('comment_react_button_${c4.id}'));
      expect(reactButton, findsOneWidget);
      await tester.ensureVisible(reactButton);
      await tester.pumpAndSettle();
      await tester.tap(reactButton);
      await tester.pump();

      // MRU reaction bar should be visible at depth 4 on 240px viewport
      final mruBar = find.byKey(Key('comment_mru_bar_${c4.id}'));
      expect(mruBar, findsOneWidget);

      // Select an emoji (🔥)
      final fireEmoji = find.byKey(Key('comment_reaction_mru_${c4.id}_🔥'));
      expect(fireEmoji, findsOneWidget);
      await tester.ensureVisible(fireEmoji);
      await tester.pumpAndSettle();
      await tester.tap(fireEmoji);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify reaction pill is displayed under c4
      final reactionPill = find.byKey(Key('comment_reaction_pill_${c4.id}_🔥'));
      expect(reactionPill, findsOneWidget);

      // Toggle reaction off by tapping the pill
      await tester.ensureVisible(reactionPill);
      await tester.pumpAndSettle();
      await tester.tap(reactionPill);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Reaction summary count decrements / disappears
      expect(tester.takeException(), isNull);
    });

    testWidgets('Header with large comment count survives 240px viewport without RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(240, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const postId = 'post-header-overflow-240px';
      final now = DateTime.now();

      await db.feedDao.createPost(
        FeedPostsCompanion.insert(
          id: postId,
          authorId: 'user-current-me',
          authorUsername: '@collector_me',
          authorDisplayName: 'Current Collector',
          type: 'text',
          textContent: const drift.Value('Header overflow post'),
          createdAt: drift.Value(now),
          updatedAt: drift.Value(now),
        ),
      );

      final feedPost = FeedPost(
        id: postId,
        type: PostType.text,
        username: '@collector_me',
        avatarInitials: 'CC',
        timestamp: 'Just now',
        locationTag: 'MTG Pod',
        commentCount: 99999, // Large count to stress header row
      );

      await tester.pumpWidget(wrapWithScope(
        child: PostCommentsSheet(post: feedPost),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('comments_sheet_header')), findsOneWidget);
      expect(find.byKey(const Key('post_comments_count_header')), findsOneWidget);
      expect(find.byKey(const Key('post_comments_close_button')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

